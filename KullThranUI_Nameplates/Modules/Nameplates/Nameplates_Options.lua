-------------------------------------------------------------------------------
--  Nameplates_Options.lua
--  Registers Nameplates options with KullThranUI.
--  All get/set calls go to KullThranUINameplatesDB and reuse the module's
--  refresh functions. This file does not touch rendering logic.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

-- Font helpers
KT.GetNPFontPath = function(_)
    local db = _G.KullThranUINameplatesDB
    local fontValue = db and db.font
    local fallback = (KT and KT.ResolveFontPath and KT:ResolveFontPath())
        or (KT and KT.FONT_PATH)
        or "Fonts\\FRIZQT__.TTF"
    if fontValue and LSM and type(fontValue) == "string" then
        local fetched = LSM:Fetch("font", fontValue, true)
        if fetched then
            return fetched
        end
        for _, name in ipairs(LSM:List("font")) do
            local registeredPath = LSM:Fetch("font", name, true)
            if registeredPath == fontValue then
                return fontValue
            end
        end
    end
    if type(fontValue) == "string" and fontValue ~= "" then
        local normalized = fontValue:gsub("/", "\\"):lower()
        if not normalized:find("interface\\addons\\", 1, true) then
            return fontValue
        end
    end
    return fallback
end
KT.GetNPFontOutline = function()
    local db = _G.KullThranUINameplatesDB
    if db and db.fontOutline ~= nil then
        return db.fontOutline
    end
    return "OUTLINE"
end
KT.GetNPFontUseShadow = function()
    local db = _G.KullThranUINameplatesDB
    if db and db.fontShadow ~= nil then
        return db.fontShadow
    end
    return true
end
KT.GetMaelstromWeapon = KT.GetMaelstromWeapon or function() return nil, 10 end

-- Color and style constants
KT.NP_GREEN        = KT.NP_GREEN        or { r = 0.0, g = 0.80, b = 0.40 }
KT.NP_BORDER_COLOR = KT.NP_BORDER_COLOR or { r = 0.3, g = 0.3,  b = 0.3  }
KT.NP_SL_INPUT_A   = KT.NP_SL_INPUT_A  or 0.55
local function NPPreviewAccentRGB()
    if KT and KT.GetStyleAccentRGB then
        return KT:GetStyleAccentRGB()
    end
    return KT.C_R or 0.902, KT.C_G or 0.118, KT.C_B or 0.314
end

local NP_PREVIEW_ACCENT = setmetatable({}, {
    __index = function(_, key)
        local r, g, b = NPPreviewAccentRGB()
        if key == "r" then return r end
        if key == "g" then return g end
        if key == "b" then return b end
        if key == "a" then return 1 end
        return nil
    end,
})

-- Pixel-perfect compatibility helper
KT.PP = KT.PP or {
    Point  = function(f, ...) f:SetPoint(...) end,
    Size   = function(f, w, h) f:SetSize(w, h) end,
    Width  = function(f, w) f:SetWidth(w) end,
    Height = function(f, h) f:SetHeight(h) end,
}

-- OnShow registration helper
local function KT_RegisterOnShow(fn)
    if KT.MenuPrincipal then
        KT.MenuPrincipal:HookScript("OnShow", fn)
    elseif not KT._npOnShowHooked then
        KT._npOnShowHooked = true
        hooksecurefunc(KT, "OpenMenu", function() fn() end)
    end
end

-- SharedMedia texture discovery
local function KT_AppendSharedMediaTextures(names, order, _, textures)
    if not LSM then return end
    for _, name in ipairs(LSM:List("statusbar")) do
        if not names[name] then
            names[name] = name
            order[#order + 1] = name
            if textures then textures[name] = LSM:Fetch("statusbar", name) end
        end
    end
end

-- Module registration shim
local function KT_RegisterNPModule(_, id, label, order, builder)
    KT:RegisterPage(id, label, order, builder)
end

-- Widget compatibility shims
local function KT_SolidTex(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    return t
end

local function KT_MakeBorder(f, r, g, b, a)
    KT:AddBorder(f, r or 0.3, g or 0.3, b or 0.3, a or 1)
end

local function KT_MakeFont(parent, size, flags, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(KT.FONT_PATH, size or 11, flags or "")
    if r then fs:SetTextColor(r, g or 1, b or 1) end
    return fs
end

local function KT_BuildSliderCore(parent, sliderWidth, a, b, inputWidth, rowHeight, fontSize, inputAlpha, minValue, maxValue, step, getter, setter)
    -- Prefer the real core implementation when available (supports both table-opts and positional args).
    if KT and KT.BuildSliderCore then
        return KT.BuildSliderCore(parent, sliderWidth, a, b, inputWidth, rowHeight, fontSize, inputAlpha, minValue, maxValue, step, getter, setter)
    end

    -- Fallback minimal implementation (positional only).
    local opts
    if type(sliderWidth) == "table" then
        opts = sliderWidth
        sliderWidth = opts.width
        inputWidth = opts.inputWidth
        rowHeight = opts.height
        fontSize = opts.fontSize
        inputAlpha = opts.inputAlpha
        minValue = opts.min
        maxValue = opts.max
        step = opts.step
        getter = opts.get
        setter = opts.set
    end

    sliderWidth = sliderWidth or 140
    inputWidth = inputWidth or 40
    rowHeight = rowHeight or 20
    fontSize = fontSize or 11
    inputAlpha = inputAlpha or 0.9
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or 100
    step = tonumber(step) or 1

    local sl = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    sl:SetOrientation("HORIZONTAL")
    sl:SetSize(sliderWidth, rowHeight)
    sl:SetMinMaxValues(minValue, maxValue)
    sl:SetValueStep(step)
    if sl.SetObeyStepOnDrag then
        sl:SetObeyStepOnDrag(true)
    end

    local thumb = sl.GetThumbTexture and sl:GetThumbTexture() or nil
    if thumb and thumb.SetColorTexture then
        thumb:SetSize(8, rowHeight + 2)
        local r, g, b = NPPreviewAccentRGB()
        thumb:SetColorTexture(r, g, b, 0.95)
    end

    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(inputWidth, rowHeight)
    edit:SetAutoFocus(false)
    if KT and KT.FONT_PATH then
        edit:SetFont(KT.FONT_PATH, fontSize, "OUTLINE")
    end
    edit:SetAlpha(inputAlpha)

    local function clamp(v)
        v = tonumber(v)
        if not v then return nil end
        if v < minValue then v = minValue end
        if v > maxValue then v = maxValue end
        if step and step > 0 then
            v = math.floor(v / step + 0.5) * step
        end
        return v
    end

    local function pushValue(v, fromSlider)
        v = clamp(v) or minValue
        edit:SetText(tostring(v))
        if not fromSlider then
            sl:SetValue(v)
        end
        if setter then
            setter(v)
        end
    end

    sl:SetScript("OnValueChanged", function(_, v)
        v = clamp(v) or minValue
        edit:SetText(tostring(v))
        if setter then setter(v) end
    end)

    edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        pushValue(self:GetText(), false)
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        pushValue(getter and getter() or sl:GetValue(), false)
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        pushValue(self:GetText(), false)
    end)

    if getter then
        pushValue(getter(), false)
    end

    return sl, edit
end

local function KT_BuildColorSwatch(parent, level, getColor, setColor, _, size)
    size = size or 20
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size, size)
    f:SetFrameLevel(level or 1)
    if KT.AddBackdrop then KT:AddBackdrop(f, 0.08, 0.08, 0.11, 1) end
    if KT.AddBorder then KT:AddBorder(f, 0.20, 0.20, 0.25, 1) end

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)

    local function UpdateSwatch()
        local ok, r, g, b = pcall(getColor)
        if ok then tex:SetColorTexture(r or 1, g or 1, b or 1, 1) end
    end

    local function OpenPicker()
        local ok, r, g, b = pcall(getColor)
        if not ok then return end
        r, g, b = r or 1, g or 1, b or 1
        local picker = ColorPickerFrame
        if not picker then return end
        if picker.SetFrameStrata then picker:SetFrameStrata("FULLSCREEN_DIALOG") end
        if picker.SetClampedToScreen then picker:SetClampedToScreen(true) end

        local function ApplyCurrent()
            local okColor, nr, ng, nb = pcall(picker.GetColorRGB, picker)
            if not okColor then return end
            if setColor then pcall(setColor, nr or 1, ng or 1, nb or 1) end
            UpdateSwatch()
        end
        local function RestoreOriginal()
            if setColor then pcall(setColor, r, g, b) end
            UpdateSwatch()
        end

        if picker.SetupColorPickerAndShow then
            picker:SetupColorPickerAndShow({
                r = r,
                g = g,
                b = b,
                hasOpacity = false,
                swatchFunc = ApplyCurrent,
                cancelFunc = RestoreOriginal,
            })
        else
            picker.func = ApplyCurrent
            picker.cancelFunc = RestoreOriginal
            picker.hasOpacity = false
            picker.opacity = nil
            picker:SetColorRGB(r, g, b)
            picker:Hide()
            picker:Show()
        end
    end

    UpdateSwatch()
    f:SetScript("OnClick", OpenPicker)
    return f, UpdateSwatch
end
local function KT_RegisterWidgetRefresh(fn)
    if KT.MenuPrincipal then
        KT.MenuPrincipal:HookScript("OnShow", fn)
    end
end

local function KT_ShowWidgetTooltip(owner, text)
    if not owner or not text then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(LText(text), 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function KT_HideWidgetTooltip()
    GameTooltip:Hide()
end

local function KT_DisabledTooltip(reason)
    return "|cffff4444" .. LText("Disabled:") .. "|r " .. LText(reason or "")
end

local function GetNPOptOutline() return KT.GetNPFontOutline and KT.GetNPFontOutline() or "OUTLINE" end
local function ApplyNPAccentToIcon(tex)
    if tex and tex.SetVertexColor then
        KT:SetAccentVertexColor(tex, 1)
    end
    if not (tex and tex.GetTexture and tex.GetParent and tex.ClearAllPoints and tex.SetPoint and tex.SetSize) then
        return
    end
    local texture = tex:GetTexture()
    if type(texture) ~= "string" then return end
    local lower = texture:lower()
    local ratio
    if lower:find("cogs.png", 1, true) or lower:find("right_arrow.png", 1, true) then
        ratio = 2 / 3
    elseif lower:find("engranaje.png", 1, true) then
        ratio = 1
    end
    if not ratio then return end
    local parent = tex:GetParent()
    local parentW = parent and parent.GetWidth and parent:GetWidth() or 26
    local parentH = parent and parent.GetHeight and parent:GetHeight() or 26
    if parentW <= 0 then parentW = 26 end
    if parentH <= 0 then parentH = 26 end
    local width = math.min(20, parentW, parentH / ratio)
    local height = width * ratio
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 0)
    tex:SetSize(width, height)
end


-------------------------------------------------------------------------------
local PAGE_GENERAL     = "General"
local PAGE_DISPLAY     = "Display"
local PAGE_COLORS      = "Colors"
local PAGE_THREAT      = "Threat"
local PAGE_SPECIAL     = "Special"
local PAGE_AUTO        = "Auto"
local PAGE_ADVANCED    = "Advanced"

local SECTION_FRIENDLY = "OTHER NAMEPLATES"
local SECTION_ENEMY_NP = "ENEMY NAMEPLATE SPACING"
local SECTION_MISC     = "EXTRAS"

local SECTION_ENEMY    = "ENEMY COLORS"
local SECTION_CASTBAR  = "CAST BAR"
local SECTION_THREAT   = "THREAT COLORS (INSTANCES ONLY)"
local SECTION_OTHER    = "OTHER COLORS"

-- Cross-tab cache of color preview widgets (for border style/color refresh).
local _ktnpColorPreviews = nil

-- Wait for KullThranUI to exist
local initFrame        = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if not KT then return end
    local PP                   = KT.PP
    -- Provide safe no-op shims for optional KT helpers.
    KT.SetContentHeader = KT.SetContentHeader or function() end
    KT.SetContentHeaderHeightSilent = KT.SetContentHeaderHeightSilent or function() end
    KT.RESIZE_ICON = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png"
    KT.DIRECTIONS_ICON = KT.DIRECTIONS_ICON or "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\right_arrow.png"
    if not KT.BuildCogPopup then
        function KT.BuildCogPopup(opts)
            opts = opts or {}
            local rows = opts.rows or {}

            local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            f:SetFrameStrata("FULLSCREEN_DIALOG")
            f:SetFrameLevel(1200)
            f:SetClampedToScreen(true)
            f:Hide()
            if KT.AddBackdrop then KT:AddBackdrop(f, 0.04, 0.04, 0.05, 0.98) end
            if KT.AddBorder then KT:AddBorder(f, 0, 0, 0, 1) end

            local title = f:CreateFontString(nil, "OVERLAY")
            title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            title:SetTextColor(1, 1, 1, 1)
            title:SetPoint("TOPLEFT", 10, -10)
            title:SetText(opts.title or "")

            local controls = {}
            local y = -32

            local function FormatValue(v, step)
                if type(v) ~= "number" then return tostring(v) end
                if type(step) == "number" and step > 0 and step < 1 then
                    local decimals = 0
                    local s = tostring(step)
                    local dot = s:find("%.")
                    if dot then
                        decimals = #s - dot
                    end
                    decimals = math.min(math.max(decimals, 1), 3)
                    return string.format("%." .. decimals .. "f", v)
                end
                return tostring(math.floor(v + 0.5))
            end

            for _, row in ipairs(rows) do
                if row.type == "slider" then
                    local label = f:CreateFontString(nil, "OVERLAY")
                    label:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
                    label:SetTextColor(1, 1, 1, 0.85)
                    label:SetPoint("TOPLEFT", 10, y)
                    label:SetText(row.label or "")

                    local valueFS = f:CreateFontString(nil, "OVERLAY")
                    valueFS:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
                    valueFS:SetTextColor(1, 1, 1, 0.5)
                    valueFS:SetPoint("TOPRIGHT", -10, y)

                    local slider = CreateFrame("Slider", nil, f, "MinimalSliderTemplate")
                    slider:SetPoint("TOPLEFT", 10, y - 16)
                    slider:SetPoint("TOPRIGHT", -10, y - 16)
                    slider:SetHeight(16)
                    slider:SetMinMaxValues(row.min or 0, row.max or 1)
                    slider:SetValueStep(row.step or 0.1)
                    if slider.SetObeyStepOnDrag then
                        slider:SetObeyStepOnDrag(true)
                    end

                    slider._updating = false
                    slider:SetScript("OnValueChanged", function(_, v)
                        if slider._updating then return end
                        if row.set then row.set(v) end
                        valueFS:SetText(FormatValue(v, row.step))
                    end)

                    controls[#controls + 1] = {
                        kind = "slider",
                        slider = slider,
                        valueFS = valueFS,
                        get = row.get,
                        step = row.step,
                    }

                    y = y - 46
                end
            end

            local totalH = math.abs(y) + 14
            f:SetSize(280, math.max(70, totalH))

            local function Refresh()
                for _, c in ipairs(controls) do
                    if c.kind == "slider" and c.get then
                        local v = c.get()
                        if type(v) == "number" then
                            c.slider._updating = true
                            c.slider:SetValue(v)
                            c.slider._updating = false
                            c.valueFS:SetText(FormatValue(v, c.step))
                        end
                    end
                end
            end

            local function Show(anchor)
                if not anchor then return end
                if f:IsShown() then
                    f:Hide()
                    return
                end
                Refresh()
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
                f:Show()
            end

            return f, Show
        end
    end

    ---------------------------------------------------------------------------
    --  Local references from the addon namespace
    ---------------------------------------------------------------------------
    local defaults             = ns.defaults or _G.KullThranUINameplatesDefaults or {}
    local SetFSFont            = ns.SetFSFont
    local GetEnemyNameTextSize = ns.GetEnemyNameTextSize
    local GetDebuffTextColor   = ns.GetDebuffTextColor
    local BAR_W                = tonumber(ns.BAR_W) or 168
    local plates               = ns.plates
    local GetNPOutline         = ns.GetNPOutline or function() return "OUTLINE" end
    local GetNPUseShadow       = ns.GetNPUseShadow or function() return false end

    local pcall                = pcall
    local pairs                = pairs

    -- Preview font setter: mirrors SetFSFont shadow logic for direct SetFont calls
    local function SetPVFont(fs, fontPath, size, flags)
        if not (fs and fs.SetFont) then return end
        local ok = pcall(fs.SetFont, fs, fontPath, size, flags)
        if not ok then
            local fallback = (KT and KT.ResolveFontPath and KT:ResolveFontPath())
                or (KT and KT.FONT_PATH)
                or "Fonts\\FRIZQT__.TTF"
            pcall(fs.SetFont, fs, fallback, size, flags)
        end
        if flags == "" then
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, 1)
        else
            fs:SetShadowOffset(0, 0)
        end
    end
    local floor = math.floor

    ---------------------------------------------------------------------------
    --  DB helper always reads live KullThranUINameplatesDB
    ---------------------------------------------------------------------------
    local function DB()
        return KullThranUINameplatesDB
    end

    local function DBVal(key)
        local db = DB()
        if db and db[key] ~= nil then return db[key] end
        return defaults[key]
    end

    local function GetTopDebuffAlignValue()
        local align = DBVal("topDebuffAlign") or defaults.topDebuffAlign or "center"
        if align == "left" or align == "right" then
            return align
        end
        return "center"
    end

    local function GetTopDebuffOffsetXValue()
        return DBVal("topDebuffOffsetX") or defaults.topDebuffOffsetX or 0
    end

    local function DBColor(key)
        local db = DB()
        local c = (db and db[key]) or defaults[key]
        if type(c) ~= "table" then return 1, 1, 1 end
        return c.r or 1, c.g or 1, c.b or 1
    end

    local _colorPreviewRefreshAll

    local function GetResolvedCastBarColor(state)
        local db = DB() or defaults
        local c

        if state == "base" or state == "interruptible" then
            c = db.castBar or defaults.castBar
        elseif state == "ready" or state == "cooldown" then
            c = db.interruptReady or defaults.interruptReady
        elseif state == "uninterruptible" then
            c = db.castBarUninterruptible or defaults.castBarUninterruptible
        end

        c = c or { r = 1, g = 1, b = 1 }
        return c.r or 1, c.g or 1, c.b or 1
    end

    local function ApplyCastBarStateColor(state, r, g, b, previewUpdater)
        local db = DB()
        if not db then return end

        if state == "base" or state == "interruptible" then
            db.castBar = { r = r, g = g, b = b }
        elseif state == "ready" or state == "cooldown" then
            db.interruptReady = { r = r, g = g, b = b }
        elseif state == "uninterruptible" then
            db.castBarUninterruptible = { r = r, g = g, b = b }
        end

        if ns.RefreshAllSettings then
            ns.RefreshAllSettings()
        else
            RefreshAllPlates()
        end

        for _, plate in pairs(plates) do
            if plate.isCasting or plate._interrupted then
                plate:UpdateCast()
            end
        end

        if type(previewUpdater) == "function" then
            previewUpdater()
        elseif type(_colorPreviewRefreshAll) == "function" then
            _colorPreviewRefreshAll()
        end
    end

    local function BuildDisplayCastBarColorSection(parent, y, W, previewUpdater)
        local _, h

        local function BuildStandaloneCastColorRow(labelText, yPos, state)
            local row = CreateFrame("Frame", nil, parent)
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yPos)
            row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yPos)
            row:SetHeight(30)

            local label = KT_MakeFont(row, 11, "", 0.92, 0.92, 0.92)
            label:SetPoint("LEFT", row, "LEFT", 12, 0)
            label:SetText(LText(labelText))

            local swatch, updateSwatch = KT_BuildColorSwatch(row, row:GetFrameLevel() + 5,
                function() return GetResolvedCastBarColor(state) end,
                function(r, g, b) ApplyCastBarStateColor(state, r, g, b, previewUpdater) end,
                nil, 20)
            swatch:ClearAllPoints()
            PP.Point(swatch, "RIGHT", row, "RIGHT", -12, 0)
            KT_RegisterWidgetRefresh(updateSwatch)
            updateSwatch()

            return 30
        end

        _, h = W:SectionHeader(parent, "CAST BAR COLORS", y); y = y - h

        y = y - BuildStandaloneCastColorRow("Interruptible Cast Color", y, "interruptible")
        y = y - BuildStandaloneCastColorRow("Interrupt On CD Color", y, "cooldown")
        y = y - BuildStandaloneCastColorRow("Color When Cast Is Uninterruptible", y, "uninterruptible")

        _, h = W:DualRow(parent, y,
            { type = "label", text = "" },
            {
                type = "toggle",
                text = LText("Show Tick at Kick Ready Spot"),
                tooltip =
                "Shows a small white tick mark on the cast bar at the point where the cast will be when your interrupt comes off cooldown.",
                getValue = function()
                    local db = DB()
                    if db and db.kickTickEnabled ~= nil then return db.kickTickEnabled end
                    return true
                end,
                setValue = function(v)
                    DB().kickTickEnabled = v
                    if ns.RefreshAllSettings then
                        ns.RefreshAllSettings()
                    else
                        RefreshAllPlates()
                    end
                    if type(previewUpdater) == "function" then
                        previewUpdater()
                    end
                end
            }); y = y - h

        return y
    end

    ---------------------------------------------------------------------------
    --  Refresh helpers  (same logic as the AceConfig version)
    ---------------------------------------------------------------------------
    local function RefreshAllPlates()
        for _, plate in pairs(plates) do
            plate:UpdateHealth()
        end
    end

    local function RefreshAllAuras()
        for _, plate in pairs(plates) do
            plate:UpdateAuras()
        end
    end

    local function RefreshAllFonts()
        for _, plate in pairs(plates) do
            plate:RefreshNamePosition()
            plate:UpdateHealthValues()
            local cns = ns.defaults.castNameSize
            local cts = ns.defaults.castTargetSize
            local db = KullThranUINameplatesDB
            if db then
                cns = db.castNameSize or cns
                cts = db.castTargetSize or cts
            end
            if plate.castName then SetFSFont(plate.castName, cns, GetNPOutline()) end
            if plate.castTarget then SetFSFont(plate.castTarget, cts, GetNPOutline()) end
            local auraStackSz = (db and db.auraStackTextSize) or ns.defaults.auraStackTextSize
            for i = 1, 4 do
                if plate.debuffs[i] and plate.debuffs[i].count then SetFSFont(plate.debuffs[i].count, auraStackSz,
                        "OUTLINE") end
                if plate.buffs[i] and plate.buffs[i].count then SetFSFont(plate.buffs[i].count, auraStackSz, "OUTLINE") end
            end
        end
    end

    ---------------------------------------------------------------------------
    --  Custom health marker helpers (shared by preview + UI)
    ---------------------------------------------------------------------------
    local function ParseHealthMarkerValues(rawValues, maxValue)
        local parsed = {}
        local seen = {}

        if type(rawValues) == "table" then
            for _, value in ipairs(rawValues) do
                local numberValue = tonumber(value)
                if numberValue then
                    parsed[#parsed + 1] = numberValue
                end
            end
        elseif type(rawValues) == "string" and rawValues ~= "" then
            for token in string.gmatch(rawValues, "[-%d%.]+") do
                local numberValue = tonumber(token)
                if numberValue then
                    parsed[#parsed + 1] = numberValue
                end
            end
        end

        table.sort(parsed)

        local result = {}
        for _, value in ipairs(parsed) do
            local clamped = value
            if type(maxValue) == "number" and maxValue > 0 then
                clamped = math.max(0, math.min(value, maxValue))
            end
            if clamped > 0 then
                local key = string.format("%.3f", clamped)
                if not seen[key] then
                    seen[key] = true
                    result[#result + 1] = clamped
                end
            end
        end

        while #result > 3 do
            table.remove(result)
        end

        return result
    end

    local function MarkerState()
        if ns and ns.GetHealthMarkerState then
            return ns.GetHealthMarkerState()
        end
        local db = DB()
        if not db then return { mode = "spec", showOn = "target", character = {}, specs = {} } end
        db.healthMarkers = db.healthMarkers or { mode = "spec", showOn = "target", character = {}, specs = {} }
        return db.healthMarkers
    end

    local function MarkerCfg()
        if ns and ns.GetActiveHealthMarkerConfig then
            return ns.GetActiveHealthMarkerConfig()
        end
        local state = MarkerState()
        state.character = state.character or {}
        return state.character
    end

    local function RebuildMarkerValues(markerCfg)
        if type(markerCfg) ~= "table" then return end
        local values = ParseHealthMarkerValues({
            markerCfg.slot1,
            markerCfg.slot2,
            markerCfg.slot3,
        }, 100)
        markerCfg.values = table.concat(values, ",")
        if ns and ns.NormalizeHealthMarkerProfile then
            ns.NormalizeHealthMarkerProfile(markerCfg)
        end
    end

    local function GetMarkerSlotValue(markerCfg, index)
        if type(markerCfg) ~= "table" then return 0 end
        local v = markerCfg["slot" .. index]
        return (type(v) == "number" and v > 0) and v or 0
    end

    local function SetMarkerSlotValue(markerCfg, index, value)
        if type(markerCfg) ~= "table" then return end
        local v = tonumber(value)
        if not v or v <= 0 then
            markerCfg["slot" .. index] = nil
        else
            markerCfg["slot" .. index] = math.max(0, math.min(v, 100))
        end
        RebuildMarkerValues(markerCfg)
    end

    ---------------------------------------------------------------------------
    --  Health bar texture dropdown values (built from ns tables)
    ---------------------------------------------------------------------------
    -- Append SharedMedia textures to the runtime ns tables first so both
    -- the dropdown AND the live nameplate rendering can resolve SM keys.
    if KT.AppendSharedMediaTextures then
        KT_AppendSharedMediaTextures(
            ns.healthBarTextureNames or {},
            ns.healthBarTextureOrder or {},
            nil,
            ns.healthBarTextures
        )
    end

    local hbtValues = {}
    local hbtOrder = {}
    do
        local texNames = ns.healthBarTextureNames or {}
        local texOrder2 = ns.healthBarTextureOrder or {}
        for _, key in ipairs(texOrder2) do
            if key ~= "---" then
                hbtValues[key] = texNames[key] or key
            end
            hbtOrder[#hbtOrder + 1] = key
        end
        local texLookup = ns.healthBarTextures or {}
        hbtValues._menuOpts = {
            itemHeight = 28,
            kind = "texture",
            sharedMedia = true,
            background = function(key)
                return texLookup[key]
            end,
        }
    end

    ---------------------------------------------------------------------------
    --  Live Preview System
    --
    --  A cosmetic-only enemy nameplate preview built from persistent frames.
    --  Created once, updated via :Update() no rebuilding, no GC pressure.
    --  Reads current DB settings for colors, sizes, font, health number, etc.
    ---------------------------------------------------------------------------
    local activePreview
    local activeFriendlyPreview
    local _displayHeaderBuilder     -- stored for page cache re-use
    local _colorPreviewRandomizeAll -- randomize all color preview fills/icons on tab switch
    local RefreshCoreEyes           -- forward-declared; defined in BuildDisplayPage
    local RefreshCoreCogStates      -- forward-declared; defined in BuildDisplayPage
    local _previewHintFS            -- the hint FontString
    local _headerBaseH = 0          -- header height WITHOUT hint (for cache restore)
    local _displayInlinePreviewHost -- inline live preview host (Display tab)
    local _displayPageMode = "enemy"
    local _openSpellIconSettings

    local function IsPreviewHintDismissed()
        return KullThranUIDB and KullThranUIDB.previewHintDismissed
    end

    -- Raid marker hidden on preview by default; toggled via eye icon.
    -- Shared scope so both BuildNameplatePreview and BuildDisplayPage can access it.
    local showRaidMarkerPreview = false
    local showClassificationPreview = false
    local showTargetGlowPreview = false
    local PREVIEW_DEBUFF_COUNT = 4
    local PREVIEW_BUFF_COUNT = 2
    local PREVIEW_CC_COUNT = 2

    -- Transient flags: force-show indicators during slider drag
    local _sliderDragShowRaidMarker = false
    local _sliderDragShowClassification = false

    -- Persistent random preview values regenerated only on tab switch, NOT on
    -- profile changes or setting tweaks (which trigger fast-path RefreshPage rebuilds).
    local _previewHpPct
    local _previewCastFill
    local _previewCastIconIdx
    local displayCastIcons = {
        136096, -- Moonfire
        135846, -- Frostbolt
        135812, -- Fireball
        136197, -- Shadow Bolt
        136048, -- Lightning Bolt
        135924, -- Smite
        132292, -- Sinister Strike
        132218, -- Arcane Shot
    }
    local PREVIEW_CLASS_SPELLS = {
        DEATHKNIGHT = {
            debuffs = { 55095, 55078, 191587, 194310 },
            buffs = { 48792, 48707, 55233, 51271 },
            ccs = { 108194, 207167, 47476, 49576 },
            casts = { 49998, 49184, 85948, 47541 },
        },
        DEMONHUNTER = {
            debuffs = { 1490, 204021, 207685, 179057 },
            buffs = { 198589, 187827, 196555, 188499 },
            ccs = { 179057, 217832, 207685, 211881 },
            casts = { 162794, 198013, 185123, 203720 },
        },
        DRUID = {
            debuffs = { 8921, 1079, 164812, 155722, 164815 },
            buffs = { 774, 8936, 1126, 102342 },
            ccs = { 339, 33786, 5211, 99 },
            casts = { 5176, 78674, 194153, 197628 },
        },
        EVOKER = {
            debuffs = { 370898, 357209, 355689, 372245 },
            buffs = { 363916, 368412, 370960, 355913 },
            ccs = { 360806, 358385, 370665, 374251 },
            casts = { 361469, 356995, 362969, 355936 },
        },
        HUNTER = {
            debuffs = { 217200, 257284, 271788, 19434 },
            buffs = { 186257, 186254, 288613, 19574 },
            ccs = { 3355, 19577, 109248, 187650 },
            casts = { 19434, 185358, 56641, 53351 },
        },
        MAGE = {
            debuffs = { 12654, 122, 157997, 44457 },
            buffs = { 1459, 11426, 12042, 45438 },
            ccs = { 118, 31661, 82691, 157981 },
            casts = { 133, 116, 30451, 44614 },
        },
        MONK = {
            debuffs = { 115804, 116095, 124273, 115078 },
            buffs = { 119611, 116849, 120954, 122783 },
            ccs = { 115078, 119381, 116705, 198898 },
            casts = { 100780, 107428, 116670, 117952 },
        },
        PALADIN = {
            debuffs = { 197277, 25771, 204242, 853 },
            buffs = { 1022, 1044, 642, 31884 },
            ccs = { 853, 20066, 115750, 105421 },
            casts = { 275779, 85256, 85673, 53595 },
        },
        PRIEST = {
            debuffs = { 589, 34914, 214621, 204213 },
            buffs = { 17, 139, 10060, 47585 },
            ccs = { 8122, 605, 64044, 9484 },
            casts = { 585, 2061, 8092, 15407 },
        },
        ROGUE = {
            debuffs = { 1943, 703, 2818, 2094 },
            buffs = { 1856, 1966, 5277, 2983 },
            ccs = { 6770, 1776, 408, 1833 },
            casts = { 196819, 53, 8676, 315341 },
        },
        SHAMAN = {
            debuffs = { 188389, 196840, 197209, 17364 },
            buffs = { 61295, 974, 108271, 79206 },
            ccs = { 51514, 51490, 118905, 192058 },
            casts = { 188196, 51505, 8004, 188443 },
        },
        WARLOCK = {
            debuffs = { 980, 146739, 172, 348 },
            buffs = { 104773, 108416, 113860, 80240 },
            ccs = { 5782, 30283, 6789, 710 },
            casts = { 686, 29722, 116858, 6353 },
        },
        WARRIOR = {
            debuffs = { 262115, 772, 115767, 6343 },
            buffs = { 6673, 18499, 871, 1719 },
            ccs = { 5246, 132168, 107570, 46968 },
            casts = { 100, 5308, 12294, 167105 },
        },
        FALLBACK = {
            debuffs = { 8921, 1079, 589, 980 },
            buffs = { 774, 1459, 17, 6673 },
            ccs = { 339, 118, 8122, 853 },
            casts = { 133, 116, 686, 188196 },
        },
    }
    local function RandomizePreviewValues()
        _previewHpPct = math.floor(60 + math.random() * 15)
        _previewCastFill = 0.40 + math.random() * 0.20
        _previewCastIconIdx = math.random(#displayCastIcons)
    end

    local function UpdatePreview()
        if activePreview and activePreview.Update then
            activePreview:Update()
        end
        if activeFriendlyPreview and activeFriendlyPreview.Update then
            activeFriendlyPreview:Update()
        end
    end

    -- Refresh the preview every time the panel is reopened
    KT_RegisterOnShow(UpdatePreview)

    --- Build the nameplate preview in the content header area.
    --- @param parent  Frame   contentHeaderFrame
    --- @param parentW number  available width
    --- @return number height consumed
    --- Build the nameplate preview in the content header area.
    --- Exact 1:1 replica of a real enemy nameplate same pixel sizes,
    --- same anchors, same fonts, same borders. No glow, no added effects.
    --- @param parent  Frame   contentHeaderFrame
    --- @param parentW number  available width
    --- @return number height consumed
    local function BuildNameplatePreview(parent, parentW)
        local FONT_PATH = (KT and KT.GetNPFontPath and KT.GetNPFontPath("nameplates")) or
        DBVal("font")

        -- Constants matching the real addon exactly
        local CAST_H = defaults.castBarHeight or 20
        local BORDER_CORNER = 6
        local BORDER_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Square_Smooth_Border2.tga"

        -- Container sized in Update()
        local pf = CreateFrame("Frame", nil, parent)
        pf:SetPoint("TOP", parent, "TOP", 0, 0)

        -- Scale the preview so it matches real nameplate size on screen.
        -- Real nameplates render at UIParent's effective scale; the preview
        -- lives inside the KT panel which has a smaller effective
        -- scale.  Applying this ratio makes every pixel value (bar width,
        -- font size, icon size, etc.) appear at the same physical size as
        -- the real nameplates.  Snap() still works correctly because it
        -- reads pf:GetEffectiveScale(), which now equals UIParent's scale.
        local previewScale = UIParent:GetEffectiveScale() / parent:GetEffectiveScale()
        pf:SetScale(previewScale)
        -- parentW in preview-local coordinates (used for centering the bar)
        local localParentW = parentW / previewScale

        -- Pixel-snap helper for the preview's own effective scale
        -- (defined early so AddBorder and CreatePreviewBorderSet can use it)
        local function IsDragging()
            return KT._sliderDragging and KT._sliderDragging > 0
        end

        local function Snap(val)
            local s = pf:GetEffectiveScale()
            return math.floor(val * s + 0.5) / s
        end

        -- 1px in preview-scale coordinates (used for borders and icon insets)
        local px = Snap(1)

        -- Icon textures whose insets (px, -px) need refreshing when scale changes
        local _insetIcons = {}

        -- 1px black border helper uses Snap() for the preview's effective scale
        -- (not PixelUtil, which snaps to screen pixels and can disagree with
        -- the preview's own pixel grid at certain panel scales)
        -- Returns a refresh function that re-snaps the 1px sizes when scale changes.
        local _borderRefreshers = {}
        local function AddBorder(f)
            local function mkB()
                local x = f:CreateTexture(nil, "OVERLAY", nil, 7)
                x:SetColorTexture(0, 0, 0, 1)
                if x.SetSnapToPixelGrid then
                    x:SetSnapToPixelGrid(false); x:SetTexelSnappingBias(0)
                end
                return x
            end
            local px = Snap(1)
            local t = mkB(); t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0); t:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0); t
                :SetHeight(px)
            local b = mkB(); b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",
                0, 0); b:SetHeight(px)
            -- Vertical edges inset between horizontal edges to avoid corner overlap
            local l = mkB(); l:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, 0); l:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 0); l
                :SetWidth(px)
            local r = mkB(); r:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT", 0, 0); r:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0,
                0); r:SetWidth(px)
            _borderRefreshers[#_borderRefreshers + 1] = function()
                local npx = Snap(1)
                t:SetHeight(npx); b:SetHeight(npx)
                l:SetWidth(npx); r:SetWidth(npx)
            end
        end

        -- Disable WoW's automatic pixel snapping on a texture (prevents sub-pixel jitter vs borders)
        local function UnsnapTex(tex)
            if tex.SetSnapToPixelGrid then
                tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0)
            end
        end

        local function SpellIcon(spellID, fallback)
            if type(spellID) ~= "number" then return fallback end
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellID)
                if info and info.iconID then return info.iconID end
            end
            if _G.GetSpellTexture then
                local t = _G.GetSpellTexture(spellID)
                if t then return t end
            end
            return fallback
        end

        local _, previewClass = UnitClass("player")
        local previewSpellPools = PREVIEW_CLASS_SPELLS[previewClass] or PREVIEW_CLASS_SPELLS.FALLBACK
        local previewUsedIcons = {}

        local function PickPreviewIcon(kind, index, fallback)
            local pool = previewSpellPools and previewSpellPools[kind] or PREVIEW_CLASS_SPELLS.FALLBACK[kind]
            if pool and #pool > 0 then
                for offset = 0, #pool - 1 do
                    local spellID = pool[((index + offset - 1) % #pool) + 1]
                    local icon = SpellIcon(spellID, fallback or displayCastIcons[((index + offset - 1) % #displayCastIcons) + 1])
                    if icon and not previewUsedIcons[icon] then
                        previewUsedIcons[icon] = true
                        return icon
                    end
                end
            end
            for offset = 0, #displayCastIcons - 1 do
                local icon = displayCastIcons[((index + offset - 1) % #displayCastIcons) + 1]
                if icon and not previewUsedIcons[icon] then
                    previewUsedIcons[icon] = true
                    return icon
                end
            end
            return fallback or displayCastIcons[1]
        end

        -- Health bar the central anchor for everything
        local health = CreateFrame("StatusBar", nil, pf)
        health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        UnsnapTex(health:GetStatusBarTexture())
        -- Preview constants packed to reduce upvalue count
        local PV_CONST = {
            FAKE_MAX_HP = 10000,
            DEBUFF_COUNT = PREVIEW_DEBUFF_COUNT,
            BUFF_COUNT = PREVIEW_BUFF_COUNT,
            CC_COUNT = PREVIEW_CC_COUNT,
        }
        if not _previewHpPct then RandomizePreviewValues() end
        local previewHpPct = _previewHpPct
        local previewHpVal = math.floor(PV_CONST.FAKE_MAX_HP * previewHpPct / 100)
        health:SetMinMaxValues(0, PV_CONST.FAKE_MAX_HP)
        health:SetValue(previewHpVal)
        health:SetFrameLevel(pf:GetFrameLevel() + 10)
        health:SetStatusBarColor(0.85, 0.20, 0.20, 1)

        local healthBG = health:CreateTexture(nil, "BACKGROUND")
        healthBG:SetAllPoints()
        healthBG:SetColorTexture(0.12, 0.12, 0.12, 1.0)
        UnsnapTex(healthBG)

        -- Custom health markers on preview health bar (up to 3 vertical lines)
        local previewMarkers = {}
        for i = 1, 3 do
            local marker = health:CreateTexture(nil, "OVERLAY", nil, 3)
            marker:SetColorTexture(1, 1, 1, 0.8)
            UnsnapTex(marker)
            marker:SetWidth(Snap(2))
            marker:SetPoint("TOP", health, "TOP", 0, 0)
            marker:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
            marker:Hide()
            previewMarkers[i] = marker
        end

        -- Bar texture: applied directly via SetStatusBarTexture (no overlay)
        -- (updated in the preview refresh below)

        local BORDER_TEX_SIMPLE = "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\square_border_1px.tga"

        -- Wrapper frame around the health bar a plain Frame (not StatusBar).
        -- The image border is parented to this wrapper so it never interacts
        -- with StatusBar internals.  Sized to match the health bar exactly.
        local healthWrapper = CreateFrame("Frame", nil, pf)
        healthWrapper:SetFrameLevel(health:GetFrameLevel() + 4)

        -- Border set builder: 9-slice image border on a plain Frame.
        -- Uses PixelUtil (like the working UnitFrames preview).
        local function CreatePreviewBorderSet(parent, tex)
            local bc = (DB() and DB().borderColor) or defaults.borderColor
            local f = CreateFrame("Frame", nil, parent)
            f:SetFrameLevel(parent:GetFrameLevel() + 1)
            f:SetAllPoints()
            f._texs = {}
            local function Mk()
                local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
                t:SetTexture(tex)
                t:SetVertexColor(bc.r, bc.g, bc.b)
                if t.SetSnapToPixelGrid then
                    t:SetSnapToPixelGrid(false)
                    t:SetTexelSnappingBias(0)
                end
                f._texs[#f._texs + 1] = t
                return t
            end
            -- Corners inset UV by half a texel (T) from texture edges (0.0 and 1.0)
            -- so the GPU fully samples the outermost solid pixel line.
            local T = 0.042
            local function UnsnapAfter(t)
                if t.SetSnapToPixelGrid then
                    t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0)
                end
            end
            local tl = Mk(); PP.Size(tl, BORDER_CORNER, BORDER_CORNER); PP.Point(tl, "TOPLEFT", f, "TOPLEFT", 0, 0); tl
                :SetTexCoord(T, 0.5, T, 0.5); UnsnapAfter(tl)
            local tr = Mk(); PP.Size(tr, BORDER_CORNER, BORDER_CORNER); PP.Point(tr, "TOPRIGHT", f, "TOPRIGHT", 0, 0); tr
                :SetTexCoord(0.5, 1 - T, T, 0.5); UnsnapAfter(tr)
            local bl = Mk(); PP.Size(bl, BORDER_CORNER, BORDER_CORNER); PP.Point(bl, "BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0); bl
                :SetTexCoord(T, 0.5, 0.5, 1 - T); UnsnapAfter(bl)
            local br = Mk(); PP.Size(br, BORDER_CORNER, BORDER_CORNER); PP.Point(br, "BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,
                0); br:SetTexCoord(0.5, 1 - T, 0.5, 1 - T); UnsnapAfter(br)
            -- Edges: sample the center column/row with half-texel width
            local H = 0.042
            local top = Mk(); PP.Height(top, BORDER_CORNER); PP.Point(top, "TOPLEFT", tl, "TOPRIGHT", 0, 0); PP.Point(
            top, "TOPRIGHT", tr, "TOPLEFT", 0, 0); top:SetTexCoord(0.5 - H, 0.5 + H, T, 0.5); UnsnapAfter(top)
            local bot = Mk(); PP.Height(bot, BORDER_CORNER); PP.Point(bot, "BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0); PP
                .Point(bot, "BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0); bot:SetTexCoord(0.5 - H, 0.5 + H, 0.5, 1 - T); UnsnapAfter(
            bot)
            local lft = Mk(); PP.Width(lft, BORDER_CORNER); PP.Point(lft, "TOPLEFT", tl, "BOTTOMLEFT", 0, 0); PP.Point(
            lft, "BOTTOMLEFT", bl, "TOPLEFT", 0, 0); lft:SetTexCoord(T, 0.5, 0.5 - H, 0.5 + H); UnsnapAfter(lft)
            local rgt = Mk(); PP.Width(rgt, BORDER_CORNER); PP.Point(rgt, "TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0); PP.Point(
            rgt, "BOTTOMRIGHT", br, "TOPRIGHT", 0, 0); rgt:SetTexCoord(0.5, 1 - T, 0.5 - H, 0.5 + H); UnsnapAfter(rgt)
            return f
        end

        local borderFrame = CreatePreviewBorderSet(healthWrapper, BORDER_TEX)
        local simpleBorderFrame = CreatePreviewBorderSet(healthWrapper, BORDER_TEX_SIMPLE)

        -- Solid 1px edge lines on all 4 sides of healthWrapper.
        -- The image border's outermost solid pixel can vanish at non-native
        -- scales due to texture filtering.  These SetColorTexture lines sit
        -- directly on healthWrapper (below the image border's frame level)
        -- as a pixel-perfect fallback for any missing edge pixels.
        local function MkSolidEdge()
            local t = healthWrapper:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetColorTexture(0, 0, 0, 1) -- placeholder; color updated in Update()
            if t.SetSnapToPixelGrid then
                t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0)
            end
            return t
        end
        local solidT = MkSolidEdge(); solidT:SetHeight(1); PP.Point(solidT, "TOPLEFT", healthWrapper, "TOPLEFT", 0, 0); PP
            .Point(solidT, "TOPRIGHT", healthWrapper, "TOPRIGHT", 0, 0)
        local solidB = MkSolidEdge(); solidB:SetHeight(1); PP.Point(solidB, "BOTTOMLEFT", healthWrapper, "BOTTOMLEFT", 0,
            0); PP.Point(solidB, "BOTTOMRIGHT", healthWrapper, "BOTTOMRIGHT", 0, 0)
        local solidL = MkSolidEdge(); solidL:SetWidth(1); PP.Point(solidL, "TOPLEFT", healthWrapper, "TOPLEFT", 0, 0); PP
            .Point(solidL, "BOTTOMLEFT", healthWrapper, "BOTTOMLEFT", 0, 0)
        local solidR = MkSolidEdge(); solidR:SetWidth(1); PP.Point(solidR, "TOPRIGHT", healthWrapper, "TOPRIGHT", 0, 0); PP
            .Point(solidR, "BOTTOMRIGHT", healthWrapper, "BOTTOMRIGHT", 0, 0)
        local _solidEdges = { solidT, solidB, solidL, solidR }

        -- Target glow preview (matches runtime)
        -- Packed into a single table to avoid exceeding Lua's 60-upvalue limit.
        local previewGlow = {}
        do
            previewGlow.extend = 4
            local gf = CreateFrame("Frame", nil, pf)
            gf:SetFrameLevel(pf:GetFrameLevel() + 1)
            previewGlow.frame = gf

            local soft = gf:CreateTexture(nil, "BACKGROUND")
            soft:SetAllPoints()
            soft:SetTexture("Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\border.png")
            soft:SetBlendMode("ADD")
            previewGlow.soft = soft

            local hard = gf:CreateTexture(nil, "BACKGROUND")
            hard:SetAllPoints()
            hard:SetTexture("Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\border-colorless.png")
            hard:SetBlendMode("BLEND")
            previewGlow.hard = hard

            gf:Hide()
        end

        -- Text overlay frame: renders above health bar fill and borders (same as real addon)
        local healthTextFrame = CreateFrame("Frame", nil, health)
        healthTextFrame:SetAllPoints(health)
        healthTextFrame:SetFrameLevel(health:GetFrameLevel() + 2)

        -- Top text overlay: renders above health bar + borders so top-slot text is never hidden
        local topTextFrame = CreateFrame("Frame", nil, pf)
        topTextFrame:SetAllPoints(health)
        topTextFrame:SetFrameLevel(health:GetFrameLevel() + 6)

        -- Name text (anchored BOTTOM to health TOP, +4px gap, width 113)
        local nameFS = pf:CreateFontString(nil, "OVERLAY")
        SetPVFont(nameFS, FONT_PATH, 11, GetNPOptOutline())
        nameFS:SetPoint("BOTTOM", health, "TOP", 0, 4)
        nameFS:SetWordWrap(false)
        nameFS:SetMaxLines(1)
        nameFS:SetText(LText("Enemy Name Text"))
        nameFS:SetTextColor(1, 1, 1, 1)

        local levelFS = topTextFrame:CreateFontString(nil, "OVERLAY")
        if ns.ApplyNameplateLevelTextStyle then ns.ApplyNameplateLevelTextStyle(levelFS) end
        levelFS:SetJustifyH("LEFT")
        levelFS:SetWordWrap(false)
        levelFS:SetMaxLines(1)
        levelFS:SetText("30")
        levelFS:SetWidth(160)
        levelFS:SetHeight(48)
        levelFS:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 24, 4)
        pf._levelFS = levelFS

        -- Health percentage text (right-aligned inside health bar)
        local hpText = healthTextFrame:CreateFontString(nil, "OVERLAY")
        SetPVFont(hpText, FONT_PATH, 10, GetNPOptOutline())
        hpText:SetPoint("RIGHT", health, -2, 0)
        hpText:SetText(previewHpPct .. "%")

        -- Health number (centered, hidden by default)
        local hpNumber = healthTextFrame:CreateFontString(nil, "OVERLAY")
        SetPVFont(hpNumber, FONT_PATH, 10, GetNPOptOutline())
        hpNumber:SetPoint("CENTER", health, "CENTER", 0, 0)
        local hpNumStr = tostring(previewHpVal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        hpNumber:SetText(hpNumStr)
        hpNumber:Hide()

        -- Raid marker: Blizzard raid target icon (same texture as live plates)
        local raidFrame = CreateFrame("Frame", nil, health)
        raidFrame:SetFrameLevel(health:GetFrameLevel() + 6)
        local raidIcon = raidFrame:CreateTexture(nil, "ARTWORK")
        raidIcon:SetAllPoints()
        if _G.SetRaidTargetIconTexture then
            _G.SetRaidTargetIconTexture(raidIcon, 8) -- skull
        else
            raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            -- 8 icons, 4x2 grid, 64px each in a 256px texture
            raidIcon:SetTexCoord(0.75, 1.0, 0.25, 0.5) -- skull
        end

        -- Target arrows packed into a table to reduce upvalue count
        local ARROW_TEX = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\arrow_right.png"
        local arrows = {}
        arrows.left = pf:CreateTexture(nil, "OVERLAY")
        arrows.left:SetSize(11, 16)
        arrows.left:SetPoint("RIGHT", health, "LEFT", -8, 0)
        arrows.left:Hide()
        arrows.right = pf:CreateTexture(nil, "OVERLAY")
        arrows.right:SetSize(11, 16)
        arrows.right:SetPoint("LEFT", health, "RIGHT", 8, 0)
        arrows.right:Hide()
        pf._arrows = arrows -- expose for Update resizing
        if ns.RefreshTargetIndicatorTextures then
            ns.RefreshTargetIndicatorTextures(pf, nil, DBVal("targetArrowScale") or defaults.targetArrowScale or 1.0)
        else
            arrows.left:SetTexture(ARROW_TEX)
            arrows.left:SetTexCoord(1, 0, 0, 1)
            arrows.right:SetTexture(ARROW_TEX)
            arrows.right:SetTexCoord(0, 1, 0, 1)
        end

        -- Classification icon shown when transient toggle is on
        local classIcon = pf:CreateTexture(nil, "OVERLAY")
        if classIcon.SetAtlas then
            classIcon:SetAtlas("nameplates-icon-elite-gold", true)
        end
        classIcon:SetSize(24, 24)
        classIcon:Hide()

        -- Cast bar (icon + bar fill health bar width)
        local cast = CreateFrame("StatusBar", nil, pf)
        cast:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        UnsnapTex(cast:GetStatusBarTexture())
        cast:SetMinMaxValues(0, 1)
        cast:SetValue(_previewCastFill)
        cast:SetFrameLevel(pf:GetFrameLevel() + 10)

        local castBG = cast:CreateTexture(nil, "BACKGROUND")
        castBG:SetAllPoints()
        castBG:SetColorTexture(0.1, 0.1, 0.1, 0.9)
        UnsnapTex(castBG)

        -- Cast bar parts packed into a table to reduce upvalue count
        local castParts = {}

        -- Cast icon (flush to the left of the cast bar)
        castParts.iconFrame = CreateFrame("Frame", nil, cast)
        castParts.iconFrame:SetSize(CAST_H, CAST_H)
        castParts.iconFrame:SetPoint("TOPRIGHT", cast, "TOPLEFT", 0, 0)
        AddBorder(castParts.iconFrame)
        castParts.icon = castParts.iconFrame:CreateTexture(nil, "ARTWORK")
        UnsnapTex(castParts.icon)
        castParts.icon:SetAllPoints()
        castParts.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        castParts.previewIcon = PickPreviewIcon("casts", _previewCastIconIdx or 1, displayCastIcons[_previewCastIconIdx or 1])
        castParts.icon:SetTexture(castParts.previewIcon)

        -- Cast spark
        castParts.spark = cast:CreateTexture(nil, "OVERLAY", nil, 1)
        castParts.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        UnsnapTex(castParts.spark)
        castParts.spark:SetSize(8, CAST_H)
        castParts.spark:SetPoint("CENTER", cast:GetStatusBarTexture(), "RIGHT", 0, 0)
        castParts.spark:SetBlendMode("ADD")

        -- Cast name (left, width 70)
        castParts.nameFS = cast:CreateFontString(nil, "OVERLAY")
        SetPVFont(castParts.nameFS, FONT_PATH, 10, GetNPOptOutline())
        castParts.nameFS:SetPoint("LEFT", cast, 5, 0)
        castParts.nameFS:SetJustifyH("LEFT")
        castParts.nameFS:SetWordWrap(false)
        castParts.nameFS:SetMaxLines(1)
        castParts.nameFS:SetText(LText("Spell Name"))

        -- Cast target (right, dynamic width)
        castParts.targetFS = cast:CreateFontString(nil, "OVERLAY")
        SetPVFont(castParts.targetFS, FONT_PATH, 10, GetNPOptOutline())
        castParts.targetFS:SetPoint("RIGHT", cast, -3, 0)
        castParts.targetFS:SetJustifyH("RIGHT")
        castParts.targetFS:SetWordWrap(false)
        castParts.targetFS:SetMaxLines(1)
        castParts.targetFS:SetText(UnitName("player") or "Spell Target")

        -- Class power pips (cosmetic preview queries live class/spec resource count)
        -- Packed into a single table to stay under Lua's 60-upvalue limit.
        local CP = {
            PIP_W = 8,
            PIP_H = 3,
            PIP_GAP = 2,
            EMPTY_R = 0.35,
            EMPTY_G = 0.35,
            EMPTY_B = 0.35,
            EMPTY_A = 0.85,
            MAX_POSSIBLE = 10,
            FILL_FRAC = 0.70,
            DEFAULT_COLOR = { 1.00, 0.84, 0.30 },
            CLASS_COLORS = {
                ROGUE       = { 1.00, 0.96, 0.41 },
                DRUID       = { 1.00, 0.49, 0.04 },
                PALADIN     = { 0.96, 0.55, 0.73 },
                MONK        = { 0.00, 1.00, 0.60 },
                WARLOCK     = { 0.58, 0.51, 0.79 },
                MAGE        = { 0.25, 0.78, 0.92 },
                EVOKER      = { 0.20, 0.58, 0.50 },
                DEMONHUNTER = { 0.34, 0.06, 0.46 },
                SHAMAN      = { 0.00, 0.44, 0.87 },
                HUNTER      = { 0.67, 0.83, 0.45 },
                WARRIOR     = { 0.78, 0.61, 0.43 },
            },
            CLASS_MAP = {
                ROGUE       = { Enum.PowerType.ComboPoints, 5 },
                DRUID       = { Enum.PowerType.ComboPoints, 5 },
                PALADIN     = { Enum.PowerType.HolyPower, 5 },
                MONK        = {
                    [268] = { "BREWMASTER_STAGGER", 1 },
                    [269] = { Enum.PowerType.Chi, 5 }
                },
                WARLOCK     = { Enum.PowerType.SoulShards, 5 },
                MAGE        = { Enum.PowerType.ArcaneCharges, 4 },
                EVOKER      = { Enum.PowerType.Essence, 5 },
                DEMONHUNTER = { [581] = { "SOUL_FRAGMENTS_VENGEANCE", 6 } },
                SHAMAN      = { [263] = { "MAELSTROM_WEAPON", 10 } },
                HUNTER      = { [255] = { "TIP_OF_THE_SPEAR", 3 } },
                WARRIOR     = { [72] = { "WHIRLWIND_STACKS", 4 } },
            },
        }
        CP.pips = {}
        for i = 1, CP.MAX_POSSIBLE do
            local bg = pf:CreateTexture(nil, "OVERLAY", nil, 2)
            bg:SetColorTexture(0.082, 0.082, 0.082, 1)
            bg:Hide()
            local pip = pf:CreateTexture(nil, "OVERLAY", nil, 3)
            pip:SetColorTexture(1, 1, 1, 1)
            pip:SetSize(CP.PIP_W, CP.PIP_H)
            pip:Hide()
            pip._bg = bg
            CP.pips[i] = pip
        end
        -- Bar-type class resource (e.g. stagger) preview
        CP.bar = CreateFrame("StatusBar", nil, pf)
        CP.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        CP.bar:SetFrameLevel(pf:GetFrameLevel() + 5)
        CP.bar:Hide()
        CP.bar._bg = CP.bar:CreateTexture(nil, "BACKGROUND")
        CP.bar._bg:SetAllPoints()
        CP.bar._bg:SetColorTexture(0.082, 0.082, 0.082, 1)

        -- Debuffs: mirrors the runtime debuff slot capacity used by the preview.
        local debuffs = {}
        local debuffData = {
            { icon = PickPreviewIcon("debuffs", 1, 136096), text = "8",  dur = 12, elapsed = 4, stacks = 0 },
            { icon = PickPreviewIcon("debuffs", 2, 132152), text = "14", dur = 18, elapsed = 4, stacks = 3 },
            { icon = PickPreviewIcon("debuffs", 3, 132123), text = "6",  dur = 10, elapsed = 4, stacks = 0 },
            { icon = PickPreviewIcon("debuffs", 4, 132122), text = "11", dur = 14, elapsed = 3, stacks = 2 },
        }
        for i = 1, PV_CONST.DEBUFF_COUNT do
            local d = CreateFrame("Frame", nil, pf)
            d:SetSize(26, 26)
            d:SetPoint("BOTTOM", nameFS, "TOP", (i - (PV_CONST.DEBUFF_COUNT + 1) / 2) * 30, 2)
            d:SetFrameLevel(health:GetFrameLevel() + 8)
            AddBorder(d)

            d.icon = d:CreateTexture(nil, "ARTWORK")
            UnsnapTex(d.icon)
            d.icon:SetPoint("TOPLEFT", d, "TOPLEFT", px, -px)
            d.icon:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -px, px)
            d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            d.icon:SetTexture(debuffData[i].icon)
            _insetIcons[#_insetIcons + 1] = { tex = d.icon, parent = d }

            -- Text child frame: sits above the icon frame so highlights can
            -- be sandwiched between icon artwork and text via frame levels.
            local textFrame = CreateFrame("Frame", nil, d)
            textFrame:SetAllPoints()
            textFrame:SetFrameLevel(d:GetFrameLevel() + 2)

            d.durationText = textFrame:CreateFontString(nil, "OVERLAY")
            d.durationText:SetFont(FONT_PATH, 11, "OUTLINE")
            d.durationText:SetPoint("TOPLEFT", d, "TOPLEFT", -3, 4)
            d.durationText:SetJustifyH("LEFT")
            d.durationText:SetText(debuffData[i].text)

            -- Stack count text (bottom-right)
            d.stackText = textFrame:CreateFontString(nil, "OVERLAY")
            d.stackText:SetFont(FONT_PATH, 11, "OUTLINE")
            d.stackText:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 1, 1)
            d.stackText:SetJustifyH("RIGHT")
            if debuffData[i].stacks > 0 then
                d.stackText:SetText(tostring(debuffData[i].stacks))
            else
                d.stackText:SetText("")
            end

            debuffs[i] = d
        end

        -- Buffs: 2 icons (left of health bar by default)
        local buffs = {}
        local buffData = {
            { icon = PickPreviewIcon("buffs", 1, 136081), text = "12", frac = 0.20 },
            { icon = PickPreviewIcon("buffs", 2, 136078), text = "7",  frac = 0.45 },
        }
        for i = 1, PV_CONST.BUFF_COUNT do
            local bf = CreateFrame("Frame", nil, pf)
            bf:SetSize(24, 24)
            bf:SetFrameLevel(health:GetFrameLevel() + 8)
            AddBorder(bf)
            bf.icon = bf:CreateTexture(nil, "ARTWORK")
            UnsnapTex(bf.icon)
            bf.icon:SetPoint("TOPLEFT", bf, "TOPLEFT", px, -px)
            bf.icon:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", -px, px)
            bf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            bf.icon:SetTexture(buffData[i].icon)
            _insetIcons[#_insetIcons + 1] = { tex = bf.icon, parent = bf }
            local bfTextFrame = CreateFrame("Frame", nil, bf)
            bfTextFrame:SetAllPoints()
            bfTextFrame:SetFrameLevel(bf:GetFrameLevel() + 2)
            bf.durationText = bfTextFrame:CreateFontString(nil, "OVERLAY")
            bf.durationText:SetFont(FONT_PATH, 12, "OUTLINE")
            bf.durationText:SetPoint("CENTER", bf, "CENTER", 0, 0)
            bf.durationText:SetText(buffData[i].text)
            buffs[i] = bf
        end

        -- CC: 2 icons (right of health bar by default)
        local ccs = {}
        local ccData = {
            { icon = PickPreviewIcon("ccs", 1, 136100), text = "5", frac = 0.55 },
            { icon = PickPreviewIcon("ccs", 2, 135848), text = "3", frac = 0.70 },
        }
        for i = 1, PV_CONST.CC_COUNT do
            local cf = CreateFrame("Frame", nil, pf)
            cf:SetSize(24, 24)
            cf:SetFrameLevel(health:GetFrameLevel() + 8)
            AddBorder(cf)
            cf.icon = cf:CreateTexture(nil, "ARTWORK")
            UnsnapTex(cf.icon)
            cf.icon:SetPoint("TOPLEFT", cf, "TOPLEFT", px, -px)
            cf.icon:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -px, px)
            cf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            cf.icon:SetTexture(ccData[i].icon)
            _insetIcons[#_insetIcons + 1] = { tex = cf.icon, parent = cf }
            local cfTextFrame = CreateFrame("Frame", nil, cf)
            cfTextFrame:SetAllPoints()
            cfTextFrame:SetFrameLevel(cf:GetFrameLevel() + 2)
            cf.durationText = cfTextFrame:CreateFontString(nil, "OVERLAY")
            cf.durationText:SetFont(FONT_PATH, 12, "OUTLINE")
            cf.durationText:SetPoint("CENTER", cf, "CENTER", 0, 0)
            cf.durationText:SetText(ccData[i].text)
            ccs[i] = cf
        end

        -- Cached position values for the health bar anchor (see health block).
        local _cachedRawBarW, _cachedXOff

        -------------------------------------------------------------------
        --  Update re-reads DB, applies to existing frames. No rebuilds.
        -------------------------------------------------------------------
        pf.Update         = function(self)
            local fontPath   = (KT and KT.GetNPFontPath and KT.GetNPFontPath("nameplates")) or
            DBVal("font")
            local npOutline  = (KT and KT.GetNPFontOutline and KT.GetNPFontOutline()) or
            "OUTLINE"
            local barH       = Snap(DBVal("healthBarHeight"))
            local rawBarW    = BAR_W + DBVal("healthBarWidth")
            local barW       = IsDragging() and rawBarW or Snap(rawBarW)
            local castH      = Snap(DBVal("castBarHeight") or defaults.castBarHeight)
            local showArrows = DBVal("showTargetArrows") == true
            local arrowScale = DBVal("targetArrowScale") or defaults.targetArrowScale or 1.0
            local indicatorStyle = DBVal("targetIndicatorStyle") or defaults.targetIndicatorStyle or "arrows"
            if pf._arrows then
                if ns.RefreshTargetIndicatorTextures then
                    ns.RefreshTargetIndicatorTextures(pf, indicatorStyle, arrowScale)
                else
                    local arrowW = math.floor(11 * arrowScale + 0.5)
                    local arrowH = math.floor(16 * arrowScale + 0.5)
                    pf._arrows.left:SetSize(arrowW, arrowH)
                    pf._arrows.right:SetSize(arrowW, arrowH)
                end
            end
            local cbColor = (DB() and DB().castBar) or defaults.castBar
            local debuffY = DBVal("debuffYOffset") or defaults.debuffYOffset

            -- Class power top push: extra offset for name/auras when pips sit above the bar
            local cpPush  = 0
            if DBVal("showClassPower") == true then
                local cpPos = DBVal("classPowerPos") or defaults.classPowerPos
                if cpPos == "top" then
                    local cpScale = DBVal("classPowerScale") or defaults.classPowerScale
                    local cpYOff  = DBVal("classPowerYOffset") or defaults.classPowerYOffset
                    cpPush        = CP.PIP_H * cpScale + cpYOff
                end
            end

            -- Apply current random preview values (regenerated on tab switch only)
            local curHpPct = _previewHpPct or 70
            local curHpVal = math.floor(PV_CONST.FAKE_MAX_HP * curHpPct / 100)
            health:SetValue(curHpVal)
            local pctStr = curHpPct .. "%"
            local pctNoSignStr = tostring(curHpPct)
            local hpNumStr = tostring(curHpVal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            -- Text on hpText/hpNumber is set later by the slot-based positioning logic
            if pf._levelFS then
                if ns.ApplyNameplateLevelTextStyle then ns.ApplyNameplateLevelTextStyle(pf._levelFS) end
                pf._levelFS:SetText("30")
                pf._levelFS:SetWidth(math.max(80, barW + 80))
                pf._levelFS:SetHeight(math.max(16, (tonumber(DBVal("levelFontSize")) or 11) + 6))
                pf._levelFS:ClearAllPoints()
                pf._levelFS:SetPoint("BOTTOMLEFT", health, "TOPLEFT", tonumber(DBVal("levelXOffset")) or 24, tonumber(DBVal("levelYOffset")) or 4)
                pf._levelFS:SetShown(DBVal("showEnemyLevel") == true)
            end
            cast:SetValue(_previewCastFill or 0.60)
            castParts.icon:SetTexture(castParts.previewIcon or displayCastIcons[_previewCastIconIdx or 1])

            -- Border style toggle
            local bStyle = DBVal("borderStyle") or defaults.borderStyle
            if bStyle == "none" then
                borderFrame:Hide(); simpleBorderFrame:Hide()
                for _, e in ipairs(_solidEdges) do e:Hide() end
            elseif bStyle == "simple" then
                borderFrame:Hide(); simpleBorderFrame:Show()
                for _, e in ipairs(_solidEdges) do e:Show() end
            else
                borderFrame:Show(); simpleBorderFrame:Hide()
                for _, e in ipairs(_solidEdges) do e:Show() end
            end

            -- Refresh all 1px AddBorder edges (cast icon, aura icons)
            for _, refreshFn in ipairs(_borderRefreshers) do refreshFn() end

            -- Refresh icon insets (1px from border) for current scale
            local curPx = Snap(1)
            for _, entry in ipairs(_insetIcons) do
                entry.tex:ClearAllPoints()
                entry.tex:SetPoint("TOPLEFT", entry.parent, "TOPLEFT", curPx, -curPx)
                entry.tex:SetPoint("BOTTOMRIGHT", entry.parent, "BOTTOMRIGHT", -curPx, curPx)
            end

            -- Border color update
            local bc = (DB() and DB().borderColor) or defaults.borderColor
            for _, tex in ipairs(borderFrame._texs) do tex:SetVertexColor(bc.r, bc.g, bc.b) end
            for _, tex in ipairs(simpleBorderFrame._texs) do tex:SetVertexColor(bc.r, bc.g, bc.b) end
            for _, e in ipairs(_solidEdges) do
                e:SetColorTexture(bc.r, bc.g, bc.b, 1); if e.SetSnapToPixelGrid then
                    e:SetSnapToPixelGrid(false); e:SetTexelSnappingBias(0)
                end
            end

            -- Icon sizes from slot-based system
            local debuffSlotVal  = DBVal("debuffSlot") or defaults.debuffSlot
            local buffSlotVal    = DBVal("buffSlot") or defaults.buffSlot
            local ccSlotVal      = DBVal("ccSlot") or defaults.ccSlot
            local debuffSz       = (debuffSlotVal ~= "none") and
            (DBVal(debuffSlotVal .. "SlotSize") or defaults[debuffSlotVal .. "SlotSize"] or 26) or 26
            local buffSz         = (buffSlotVal ~= "none") and
            (DBVal(buffSlotVal .. "SlotSize") or defaults[buffSlotVal .. "SlotSize"] or 24) or 24
            local ccSz           = (ccSlotVal ~= "none") and
            (DBVal(ccSlotVal .. "SlotSize") or defaults[ccSlotVal .. "SlotSize"] or 24) or 24

            -- Gap between icons (user setting), then compute per-type center-to-center spacing
            local gap            = DBVal("auraSpacing") or defaults.auraSpacing
            local debuffSpacing  = gap + debuffSz
            local buffSpacing    = gap + buffSz
            local ccSpacing      = gap + ccSz

            -- Arrow visibility is deferred until after auras are placed
            -- (arrows go OUTSIDE the outermost side aura)

            -- Raid marker position and size (slot-based)
            local rmPos          = DBVal("raidMarkerPos") or defaults.raidMarkerPos
            local rmSize         = (rmPos ~= "none") and
            (DBVal(rmPos .. "SlotSize") or defaults[rmPos .. "SlotSize"] or 24) or 24
            local rmXOff, rmYOff = 0, 0
            if rmPos ~= "none" then
                rmXOff = DBVal(rmPos .. "SlotXOffset") or 0
                rmYOff = DBVal(rmPos .. "SlotYOffset") or 0
            end

            -- Classification slot
            local clPos = DBVal("classificationSlot") or defaults.classificationSlot

            -- Clear drag-show flags when not dragging
            if not IsDragging() then
                _sliderDragShowRaidMarker = false
                _sliderDragShowClassification = false
            end

            local showRM = showRaidMarkerPreview or _sliderDragShowRaidMarker

            raidFrame:ClearAllPoints()
            raidFrame:SetSize(rmSize, rmSize)
            if rmPos == "none" or not showRM then
                raidFrame:Hide()
                if pf._raidOverlay then pf._raidOverlay:Hide() end
            else
                if rmPos == "top" then
                    raidFrame:SetPoint("BOTTOM", health, "TOP", rmXOff, debuffY + cpPush + rmYOff)
                elseif rmPos == "left" then
                    local sideOff = DBVal("sideAuraXOffset") or defaults.sideAuraXOffset
                    raidFrame:SetPoint("RIGHT", health, "LEFT", -sideOff + rmXOff, rmYOff)
                elseif rmPos == "right" then
                    local sideOff = DBVal("sideAuraXOffset") or defaults.sideAuraXOffset
                    raidFrame:SetPoint("LEFT", health, "RIGHT", sideOff + rmXOff, rmYOff)
                elseif rmPos == "topleft" then
                    raidFrame:SetPoint("BOTTOMLEFT", health, "TOPLEFT", -2 + rmXOff, cpPush + rmYOff)
                elseif rmPos == "topright" then
                    raidFrame:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 2 + rmXOff, cpPush + rmYOff)
                end
                raidFrame:SetAlpha(1)
                raidFrame:Show()
                if pf._raidOverlay then pf._raidOverlay:Show() end
            end

            -- Classification icon (elite dragon) slot-based
            classIcon:ClearAllPoints()
            local clXOff, clYOff = 0, 0
            if clPos ~= "none" then
                clXOff = DBVal(clPos .. "SlotXOffset") or 0
                clYOff = DBVal(clPos .. "SlotYOffset") or 0
            end
            local reIconSz = (clPos ~= "none") and (DBVal(clPos .. "SlotSize") or defaults[clPos .. "SlotSize"] or 20) or
            20
            local showCL = showClassificationPreview or _sliderDragShowClassification
            classIcon:SetSize(reIconSz, reIconSz)
            if clPos == "none" or not showCL then
                classIcon:Hide()
                if pf._classOverlay then pf._classOverlay:Hide() end
            else
                if clPos == "top" then
                    classIcon:SetPoint("BOTTOM", health, "TOP", clXOff, debuffY + cpPush + clYOff)
                elseif clPos == "left" then
                    local sideOff = DBVal("sideAuraXOffset") or defaults.sideAuraXOffset
                    classIcon:SetPoint("RIGHT", health, "LEFT", -sideOff + clXOff, clYOff)
                elseif clPos == "right" then
                    local sideOff = DBVal("sideAuraXOffset") or defaults.sideAuraXOffset
                    classIcon:SetPoint("LEFT", health, "RIGHT", sideOff + clXOff, clYOff)
                elseif clPos == "topleft" then
                    classIcon:SetPoint("BOTTOMLEFT", health, "TOPLEFT", -2 + clXOff, 2 + cpPush + clYOff)
                elseif clPos == "topright" then
                    classIcon:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 2 + clXOff, 2 + cpPush + clYOff)
                end
                classIcon:Show()
                if pf._classOverlay then pf._classOverlay:Show() end
            end

            -- Arrow push is no longer used arrows are placed OUTSIDE auras now
            -- (arrow positioning happens after all auras are placed)

            -- Cast bar: full health bar width, icon hangs outside left edge
            cast:ClearAllPoints()
            cast:SetSize(barW, castH)
            cast:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, 0)
            cast:SetStatusBarColor(cbColor.r, cbColor.g, cbColor.b, 1)
            -- Apply cast icon visibility and scale from DB
            -- Use SetSize instead of SetScale so AddBorder stays pixel-perfect
            local showIcon = true
            local db = DB()
            if db and db.showCastIcon ~= nil then showIcon = db.showCastIcon end
            if showIcon then
                local iconScale = (db and db.castIconScale) or defaults.castIconScale
                local scaledH = castH * iconScale
                castParts.iconFrame:SetScale(1)
                castParts.iconFrame:SetSize(scaledH, scaledH)
                castParts.iconFrame:ClearAllPoints()
                if (db and db.castIconSide) == "right" then
                    castParts.iconFrame:SetPoint("TOPLEFT", cast, "TOPRIGHT",
                        (db and db.castIconXOffset) or defaults.castIconXOffset,
                        (db and db.castIconYOffset) or defaults.castIconYOffset)
                else
                    castParts.iconFrame:SetPoint("TOPRIGHT", cast, "TOPLEFT",
                        (db and db.castIconXOffset) or defaults.castIconXOffset,
                        (db and db.castIconYOffset) or defaults.castIconYOffset)
                end
                castParts.iconFrame:Show()
            else
                castParts.iconFrame:SetSize(castH, castH)
                castParts.iconFrame:Hide()
            end
            castParts.spark:SetHeight(castH)

            -- Name font + color + position (font size set per-slot below)
            local nameYOff   = DBVal("nameYOffset") or defaults.nameYOffset

            -- Slot-based text positioning
            -- Read slot assignments
            local slotTop    = DBVal("textSlotTop") or defaults.textSlotTop
            local slotRight  = DBVal("textSlotRight") or defaults.textSlotRight
            local slotLeft   = DBVal("textSlotLeft") or defaults.textSlotLeft
            local slotCenter = DBVal("textSlotCenter") or defaults.textSlotCenter

            -- Hide all three text elements first
            nameFS:Hide()
            hpText:Hide()
            hpNumber:Hide()
            nameFS:ClearAllPoints()
            hpText:ClearAllPoints()
            hpNumber:ClearAllPoints()

            -- Helper: position a health-related element in a bar slot
            local function PlaceHealthInBar(element, anchor, point, xOff, yOff, fontSize, cr, cg, cb)
                yOff = yOff or 0
                if element == "healthPercent" or element == "healthPercentNoSign" then
                    SetPVFont(hpText, fontPath, fontSize, npOutline)
                    hpText:SetParent(healthTextFrame)
                    hpText:SetText(element == "healthPercentNoSign" and pctNoSignStr or pctStr)
                    hpText:SetPoint(point, health, anchor, xOff, yOff)
                    hpText:SetTextColor(cr, cg, cb, 1)
                    hpText:Show()
                elseif element == "healthNumber" then
                    SetPVFont(hpNumber, fontPath, fontSize, npOutline)
                    hpNumber:SetParent(healthTextFrame)
                    hpNumber:SetText(hpNumStr)
                    hpNumber:SetPoint(point, health, anchor, xOff, yOff)
                    hpNumber:SetTextColor(cr, cg, cb, 1)
                    hpNumber:Show()
                elseif element == "healthPctNum" then
                    SetPVFont(hpText, fontPath, fontSize, npOutline)
                    hpText:SetParent(healthTextFrame)
                    hpText:SetText(pctStr .. " | " .. hpNumStr)
                    hpText:SetPoint(point, health, anchor, xOff, yOff)
                    hpText:SetTextColor(cr, cg, cb, 1)
                    hpText:Show()
                elseif element == "healthNumPct" then
                    SetPVFont(hpText, fontPath, fontSize, npOutline)
                    hpText:SetParent(healthTextFrame)
                    hpText:SetText(hpNumStr .. " | " .. pctStr)
                    hpText:SetPoint(point, health, anchor, xOff, yOff)
                    hpText:SetTextColor(cr, cg, cb, 1)
                    hpText:Show()
                end
            end

            -- Helper: position a health-related element in the top slot
            local function PlaceHealthOnTop(element, txOff, tyOff, fontSize, cr, cg, cb)
                txOff = txOff or 0
                tyOff = tyOff or 0
                if element == "healthPercent" or element == "healthPercentNoSign" then
                    SetPVFont(hpText, fontPath, fontSize, npOutline)
                    hpText:SetText(element == "healthPercentNoSign" and pctNoSignStr or pctStr)
                    hpText:SetParent(topTextFrame)
                    hpText:SetPoint("BOTTOM", health, "TOP", txOff, 4 + nameYOff + cpPush + tyOff)
                    hpText:SetTextColor(cr, cg, cb, 1)
                    hpText:Show()
                elseif element == "healthNumber" then
                    SetPVFont(hpNumber, fontPath, fontSize, npOutline)
                    hpNumber:SetText(hpNumStr)
                    hpNumber:SetParent(topTextFrame)
                    hpNumber:SetPoint("BOTTOM", health, "TOP", txOff, 4 + nameYOff + cpPush + tyOff)
                    hpNumber:SetTextColor(cr, cg, cb, 1)
                    hpNumber:Show()
                elseif element == "healthPctNum" then
                    SetPVFont(hpText, fontPath, fontSize, npOutline)
                    hpText:SetText(pctStr .. " | " .. hpNumStr)
                    hpText:SetParent(topTextFrame)
                    hpText:SetPoint("BOTTOM", health, "TOP", txOff, 4 + nameYOff + cpPush + tyOff)
                    hpText:SetTextColor(cr, cg, cb, 1)
                    hpText:Show()
                elseif element == "healthNumPct" then
                    SetPVFont(hpText, fontPath, fontSize, npOutline)
                    hpText:SetText(hpNumStr .. " | " .. pctStr)
                    hpText:SetParent(topTextFrame)
                    hpText:SetPoint("BOTTOM", health, "TOP", txOff, 4 + nameYOff + cpPush + tyOff)
                    hpText:SetTextColor(cr, cg, cb, 1)
                    hpText:Show()
                end
            end

            -- Helper: position the name in a bar slot
            local function PlaceNameInBar(anchor, point, xOff, justify, txOff, tyOff, fontSize, cr, cg, cb, nameSlotKey)
                txOff = txOff or 0
                tyOff = tyOff or 0
                SetPVFont(nameFS, fontPath, fontSize, npOutline)
                nameFS:SetParent(healthTextFrame)
                nameFS:SetPoint(point, health, anchor, xOff + txOff, tyOff)
                nameFS:SetJustifyH(justify)
                -- Estimate health text width in opposing bar slots
                local usedWidth = 0
                local barSlotInfo = {
                    { key = "textSlotRight",  slot = slotRight },
                    { key = "textSlotLeft",   slot = slotLeft },
                    { key = "textSlotCenter", slot = slotCenter },
                }
                for _, info in ipairs(barSlotInfo) do
                    if info.key ~= nameSlotKey then
                        local el = info.slot
                        if el ~= "none" and el ~= "enemyName" then
                            usedWidth = usedWidth + ns.EstimateHealthTextWidth(el)
                        end
                    end
                end
                nameFS:SetWidth(math.max(barW - usedWidth, 20))
                nameFS:SetTextColor(cr, cg, cb, 1)
                nameFS:Show()
            end

            -- Process top slot
            local topXOff = DBVal("textSlotTopXOffset") or 0
            local topYOff = DBVal("textSlotTopYOffset") or 0
            local topFontSz = DBVal("textSlotTopSize") or defaults.textSlotTopSize
            local topC = (DB() and DB().textSlotTopColor) or defaults.textSlotTopColor
            if slotTop == "enemyName" then
                SetPVFont(nameFS, fontPath, topFontSz, npOutline)
                nameFS:SetParent(topTextFrame)
                nameFS:SetPoint("BOTTOM", health, "TOP", topXOff, 4 + nameYOff + cpPush + topYOff)
                nameFS:SetJustifyH("CENTER")
                local nameW = barW
                if rmPos ~= "none" and showRM then
                    nameW = barW - 2 * (rmSize - 2) - 7
                end
                if showCL and clPos ~= "none" then
                    nameW = nameW - (reIconSz + 4)
                end
                nameFS:SetWidth(math.max(nameW, 20))
                nameFS:SetTextColor(topC.r, topC.g, topC.b, 1)
                nameFS:Show()
            else
                PlaceHealthOnTop(slotTop, topXOff, topYOff, topFontSz, topC.r, topC.g, topC.b)
            end

            -- Process right slot
            local rightXOff = DBVal("textSlotRightXOffset") or 0
            local rightYOff = DBVal("textSlotRightYOffset") or 0
            local rightFontSz = DBVal("textSlotRightSize") or defaults.textSlotRightSize
            local rightC = (DB() and DB().textSlotRightColor) or defaults.textSlotRightColor
            if slotRight == "enemyName" then
                PlaceNameInBar("RIGHT", "RIGHT", -2, "RIGHT", rightXOff, rightYOff, rightFontSz, rightC.r, rightC.g,
                    rightC.b, "textSlotRight")
            else
                PlaceHealthInBar(slotRight, "RIGHT", "RIGHT", -2 + rightXOff, rightYOff, rightFontSz, rightC.r, rightC.g,
                    rightC.b)
            end

            -- Process left slot
            local leftXOff = DBVal("textSlotLeftXOffset") or 0
            local leftYOff = DBVal("textSlotLeftYOffset") or 0
            local leftFontSz = DBVal("textSlotLeftSize") or defaults.textSlotLeftSize
            local leftC = (DB() and DB().textSlotLeftColor) or defaults.textSlotLeftColor
            if slotLeft == "enemyName" then
                PlaceNameInBar("LEFT", "LEFT", 4, "LEFT", leftXOff, leftYOff, leftFontSz, leftC.r, leftC.g, leftC.b,
                    "textSlotLeft")
            else
                PlaceHealthInBar(slotLeft, "LEFT", "LEFT", 4 + leftXOff, leftYOff, leftFontSz, leftC.r, leftC.g, leftC.b)
            end

            -- Process center slot
            local centerXOff = DBVal("textSlotCenterXOffset") or 0
            local centerYOff = DBVal("textSlotCenterYOffset") or 0
            local centerFontSz = DBVal("textSlotCenterSize") or defaults.textSlotCenterSize
            local centerC = (DB() and DB().textSlotCenterColor) or defaults.textSlotCenterColor
            if slotCenter == "enemyName" then
                PlaceNameInBar("CENTER", "CENTER", 0, "CENTER", centerXOff, centerYOff, centerFontSz, centerC.r,
                    centerC.g, centerC.b, "textSlotCenter")
            else
                PlaceHealthInBar(slotCenter, "CENTER", "CENTER", centerXOff, centerYOff, centerFontSz, centerC.r,
                    centerC.g, centerC.b)
            end

            local previewNameSlot = ns.FindSlotForElement and ns.FindSlotForElement("enemyName")
            if ns.PositionNameplateLevelText then
                ns.PositionNameplateLevelText(levelFS, nameFS, health, previewNameSlot,
                    DBVal("levelXOffset") or defaults.levelXOffset,
                    DBVal("levelYOffset") or defaults.levelYOffset)
            end

            -- Health bar color: always uses "enemies in combat" color
            local eic = (DB() and DB().enemyInCombat) or defaults.enemyInCombat
            health:SetStatusBarColor(eic.r, eic.g, eic.b, 1)

            -- Cast text sizes and colors
            local cns = DBVal("castNameSize") or defaults.castNameSize
            local cts = DBVal("castTargetSize") or defaults.castTargetSize
            local cnc = (DB() and DB().castNameColor) or defaults.castNameColor
            local castNameX = DBVal("castNameXOffset") or defaults.castNameXOffset or 0
            local castNameY = DBVal("castNameYOffset") or defaults.castNameYOffset or 0
            local castTargetX = DBVal("castTargetXOffset") or defaults.castTargetXOffset or 0
            local castTargetY = DBVal("castTargetYOffset") or defaults.castTargetYOffset or 0
            SetPVFont(castParts.nameFS, fontPath, cns, npOutline)
            SetPVFont(castParts.targetFS, fontPath, cts, npOutline)
            castParts.nameFS:SetTextColor(cnc.r, cnc.g, cnc.b, 1)
            local useClassColor = defaults.castTargetClassColor
            local dbRef = DB()
            if dbRef and dbRef.castTargetClassColor ~= nil then useClassColor = dbRef.castTargetClassColor end
            if useClassColor then
                local _, pClass = UnitClass("player")
                local c = pClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[pClass]
                if c then
                    castParts.targetFS:SetTextColor(c.r, c.g, c.b, 1)
                else
                    castParts.targetFS:SetTextColor(1, 1, 1, 1)
                end
            else
                local ctc = (dbRef and dbRef.castTargetColor) or defaults.castTargetColor
                castParts.targetFS:SetTextColor(ctc.r, ctc.g, ctc.b, 1)
            end

            castParts.targetFS:ClearAllPoints()
            castParts.targetFS:SetPoint("RIGHT", cast, "RIGHT", -3 + castTargetX, castTargetY)

            -- Dynamic cast name width: fill space minus target text minus 5px gap
            local targetTextW = castParts.targetFS:GetUnboundedStringWidth()
            local castNameMaxW = barW - (5 + castNameX) - (3 - castTargetX) - targetTextW - 5
            if castNameMaxW < 20 then castNameMaxW = 20 end
            castParts.nameFS:ClearAllPoints()
            castParts.nameFS:SetPoint("LEFT", cast, "LEFT", 5 + castNameX, castNameY)
            castParts.nameFS:SetWidth(castNameMaxW)

            -- Helper: position a single preview frame into a slot
            local function PlaceInSlot(frame, slotName, index, count, iconW, iconH, slotSpacing, sxOff, syOff, groupKey)
                sxOff = sxOff or 0
                syOff = syOff or 0
                frame:ClearAllPoints()
                if slotName == "top" then
                    -- Anchor auras to whichever FontString is in the top slot
                    local anchor
                    if slotTop == "enemyName" then
                        anchor = nameFS
                    elseif slotTop == "healthNumber" then
                        anchor = hpNumber
                    elseif slotTop ~= "none" then
                        anchor = hpText
                    else
                        anchor = health
                    end
                    -- Only add cpPush when anchoring to health bar (top slot is "none")
                    local slotCpPush = (slotTop == "none") and cpPush or 0
                    if groupKey == "debuffs" then
                        local align = GetTopDebuffAlignValue()
                        local topOffsetX = GetTopDebuffOffsetXValue()
                        local extraTop = (slotTop ~= "none") and (4 + nameYOff + topYOff + topFontSz) or 0
                        if align == "left" then
                            frame:SetPoint("BOTTOMLEFT", health, "TOPLEFT",
                                ((index - 1) * slotSpacing) + sxOff + topOffsetX, debuffY + slotCpPush + syOff + extraTop)
                        elseif align == "right" then
                            frame:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT",
                                (-((count - index) * slotSpacing)) + sxOff + topOffsetX, debuffY + slotCpPush + syOff + extraTop)
                        else
                            frame:SetPoint("BOTTOM", health, "TOP",
                                (index - (count + 1) / 2) * slotSpacing + sxOff + topOffsetX, debuffY + slotCpPush + syOff + extraTop)
                        end
                    else
                        frame:SetPoint("BOTTOM", anchor, "TOP",
                            (index - (count + 1) / 2) * slotSpacing + sxOff, debuffY + slotCpPush + syOff)
                    end
                elseif slotName == "left" then
                    local sideOff = DBVal("sideAuraXOffset") or defaults.sideAuraXOffset
                    frame:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", -sideOff - (index - 1) * slotSpacing + sxOff,
                        syOff)
                elseif slotName == "right" then
                    local sideOff = DBVal("sideAuraXOffset") or defaults.sideAuraXOffset
                    frame:SetPoint("BOTTOMLEFT", health, "BOTTOMRIGHT", sideOff + (index - 1) * slotSpacing + sxOff,
                        syOff)
                elseif slotName == "topleft" then
                    local growth = DBVal("topleftSlotGrowth") or defaults.topleftSlotGrowth
                    local idx = index - 1 -- 0 for icon 1, never moves
                    local baseX = -2 + sxOff
                    local baseY = debuffY + cpPush + syOff
                    if growth == "up" then
                        frame:SetPoint("BOTTOMLEFT", health, "TOPLEFT", baseX, baseY + idx * slotSpacing)
                    elseif growth == "right" then
                        frame:SetPoint("BOTTOMLEFT", health, "TOPLEFT", baseX + idx * slotSpacing, baseY)
                    else
                        frame:SetPoint("BOTTOMLEFT", health, "TOPLEFT", baseX - idx * slotSpacing, baseY)
                    end
                elseif slotName == "topright" then
                    local growth = DBVal("toprightSlotGrowth") or defaults.toprightSlotGrowth
                    local idx = index - 1 -- 0 for icon 1, never moves
                    local baseX = 2 + sxOff
                    local baseY = debuffY + cpPush + syOff
                    if growth == "up" then
                        frame:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", baseX, baseY + idx * slotSpacing)
                    elseif growth == "left" then
                        frame:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", baseX - idx * slotSpacing, baseY)
                    else
                        frame:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", baseX + idx * slotSpacing, baseY)
                    end
                elseif slotName == "bottom" then
                    frame:SetPoint("TOP", cast, "BOTTOM",
                        (index - (count + 1) / 2) * slotSpacing + sxOff, -2 + syOff)
                end
            end

            -- Aura text settings (unified)
            local auraDurSz   = DBVal("auraDurationTextSize") or defaults.auraDurationTextSize
            local auraDurC    = (DB() and DB().auraDurationTextColor) or defaults.auraDurationTextColor
            local auraStackSz = DBVal("auraStackTextSize") or defaults.auraStackTextSize
            local auraStackC  = (DB() and DB().auraStackTextColor) or defaults.auraStackTextColor
            local auraDurXOff = DBVal("auraDurationXOffset") or defaults.auraDurationXOffset or 0
            local auraDurYOff = DBVal("auraDurationYOffset") or defaults.auraDurationYOffset or 0
            local auraStackXOff = DBVal("auraStackXOffset") or defaults.auraStackXOffset or 0
            local auraStackYOff = DBVal("auraStackYOffset") or defaults.auraStackYOffset or 0
            local atPos       = DBVal("auraTextPosition") or DBVal("debuffTextPosition") or defaults.auraTextPosition
            local debuffTPos  = DBVal("debuffTimerPosition") or atPos
            local buffTPos    = DBVal("buffTimerPosition") or atPos
            local ccTPos      = DBVal("ccTimerPosition") or atPos

            -- Helper: apply timer position to a duration text fontstring
            local function ApplyTimerPos(durText, auraFrame, pos)
                if pos == "none" then
                    durText:Hide()
                    return
                end
                durText:Show()
                durText:SetFont(fontPath, auraDurSz, "OUTLINE")
                durText:SetTextColor(auraDurC.r, auraDurC.g, auraDurC.b, 1)
                durText:ClearAllPoints()
                if pos == "center" then
                    durText:SetPoint("CENTER", auraFrame, "CENTER", auraDurXOff, auraDurYOff)
                    durText:SetJustifyH("CENTER")
                elseif pos == "topright" then
                    durText:SetPoint("TOPRIGHT", auraFrame, "TOPRIGHT", 3 + auraDurXOff, 4 + auraDurYOff)
                    durText:SetJustifyH("RIGHT")
                else
                    durText:SetPoint("TOPLEFT", auraFrame, "TOPLEFT", -3 + auraDurXOff, 4 + auraDurYOff)
                    durText:SetJustifyH("LEFT")
                end
            end

            -- Aura slot XY offsets (slot-based)
            local debuffXOff, debuffYOff = 0, 0
            if debuffSlotVal ~= "none" then
                debuffXOff = DBVal(debuffSlotVal .. "SlotXOffset") or 0
                debuffYOff = DBVal(debuffSlotVal .. "SlotYOffset") or 0
            end
            local buffXOff, buffYOff = 0, 0
            if buffSlotVal ~= "none" then
                buffXOff = DBVal(buffSlotVal .. "SlotXOffset") or 0
                buffYOff = DBVal(buffSlotVal .. "SlotYOffset") or 0
            end
            local ccXOff, ccYOff = 0, 0
            if ccSlotVal ~= "none" then
                ccXOff = DBVal(ccSlotVal .. "SlotXOffset") or 0
                ccYOff = DBVal(ccSlotVal .. "SlotYOffset") or 0
            end

            for i = 1, PV_CONST.DEBUFF_COUNT do
                if debuffSlotVal == "none" then
                    debuffs[i]:Hide()
                else
                    debuffs[i]:Show()
                    debuffs[i]:SetSize(Snap(debuffSz), Snap(debuffSz))
                    debuffs[i].durationText:SetFont(fontPath, auraDurSz, "OUTLINE")
                    debuffs[i].durationText:SetTextColor(auraDurC.r, auraDurC.g, auraDurC.b, 1)
                    ApplyTimerPos(debuffs[i].durationText, debuffs[i], debuffTPos)
                    debuffs[i].stackText:SetFont(fontPath, auraStackSz, "OUTLINE")
                    debuffs[i].stackText:SetTextColor(auraStackC.r, auraStackC.g, auraStackC.b, 1)
                    debuffs[i].stackText:ClearAllPoints()
                    debuffs[i].stackText:SetPoint("BOTTOMRIGHT", debuffs[i], "BOTTOMRIGHT", 1 + auraStackXOff,
                        1 + auraStackYOff)
                    debuffs[i].stackText:SetJustifyH("RIGHT")
                    PlaceInSlot(debuffs[i], debuffSlotVal, i, PV_CONST.DEBUFF_COUNT, debuffSz, debuffSz, debuffSpacing,
                        debuffXOff, debuffYOff, "debuffs")
                end
            end

            -- Buff size + duration text styling + slot position
            for i = 1, PV_CONST.BUFF_COUNT do
                if buffSlotVal == "none" then
                    buffs[i]:Hide()
                else
                    buffs[i]:Show()
                    buffs[i]:SetSize(Snap(buffSz), Snap(buffSz))
                    buffs[i].durationText:SetFont(fontPath, auraDurSz, "OUTLINE")
                    buffs[i].durationText:SetTextColor(auraDurC.r, auraDurC.g, auraDurC.b, 1)
                    ApplyTimerPos(buffs[i].durationText, buffs[i], buffTPos)
                    if buffs[i].count then
                        buffs[i].count:SetFont(fontPath, auraStackSz, "OUTLINE")
                        buffs[i].count:SetTextColor(auraStackC.r, auraStackC.g, auraStackC.b, 1)
                        buffs[i].count:ClearAllPoints()
                        buffs[i].count:SetPoint("BOTTOMRIGHT", buffs[i], "BOTTOMRIGHT", 2 + auraStackXOff,
                            -2 + auraStackYOff)
                        buffs[i].count:SetJustifyH("RIGHT")
                    end
                    PlaceInSlot(buffs[i], buffSlotVal, i, PV_CONST.BUFF_COUNT, buffSz, buffSz, buffSpacing, buffXOff,
                        buffYOff, "buffs")
                end
            end

            -- CC size + duration text styling + slot position
            for i = 1, PV_CONST.CC_COUNT do
                if ccSlotVal == "none" then
                    ccs[i]:Hide()
                else
                    ccs[i]:Show()
                    ccs[i]:SetSize(Snap(ccSz), Snap(ccSz))
                    ccs[i].durationText:SetFont(fontPath, auraDurSz, "OUTLINE")
                    ccs[i].durationText:SetTextColor(auraDurC.r, auraDurC.g, auraDurC.b, 1)
                    ApplyTimerPos(ccs[i].durationText, ccs[i], ccTPos)
                    PlaceInSlot(ccs[i], ccSlotVal, i, PV_CONST.CC_COUNT, ccSz, ccSz, ccSpacing, ccXOff, ccYOff, "ccs")
                end
            end

            -- Position target arrows OUTSIDE the outermost side auras
            if showArrows then
                arrows.left:ClearAllPoints()
                arrows.right:ClearAllPoints()
                -- Compute per-slot pixel extent on each side (accounts for X offsets)
                local sideOff = DBVal("sideAuraXOffset") or defaults.sideAuraXOffset
                local leftExtent, rightExtent = 0, 0
                -- Aura slots (debuffs, buffs, ccs)
                local function addAuraSide(slotVal, count, sz, sp, xOff)
                    if slotVal == "left" then
                        leftExtent = math.max(leftExtent, sideOff + (count - 1) * sp + sz - xOff)
                    elseif slotVal == "right" then
                        rightExtent = math.max(rightExtent, sideOff + (count - 1) * sp + sz + xOff)
                    end
                end
                addAuraSide(debuffSlotVal, PV_CONST.DEBUFF_COUNT, debuffSz, debuffSpacing, debuffXOff)
                addAuraSide(buffSlotVal, PV_CONST.BUFF_COUNT, buffSz, buffSpacing, buffXOff)
                addAuraSide(ccSlotVal, PV_CONST.CC_COUNT, ccSz, ccSpacing, ccXOff)
                -- Raid marker
                if rmPos == "left" and showRM then
                    leftExtent = math.max(leftExtent, sideOff + rmSize - rmXOff)
                elseif rmPos == "right" and showRM then
                    rightExtent = math.max(rightExtent, sideOff + rmSize + rmXOff)
                end
                -- Classification icon
                if clPos == "left" and showCL then
                    leftExtent = math.max(leftExtent, sideOff + reIconSz - clXOff)
                elseif clPos == "right" and showCL then
                    rightExtent = math.max(rightExtent, sideOff + reIconSz + clXOff)
                end

                if leftExtent > 0 then
                    arrows.left:SetPoint("RIGHT", health, "LEFT", -(leftExtent + 8), 0)
                else
                    arrows.left:SetPoint("RIGHT", health, "LEFT", -8, 0)
                end
                if rightExtent > 0 then
                    arrows.right:SetPoint("LEFT", health, "RIGHT", rightExtent + 8, 0)
                else
                    arrows.right:SetPoint("LEFT", health, "RIGHT", 8, 0)
                end
                if ns.SetTargetIndicatorShown then
                    ns.SetTargetIndicatorShown(pf, true)
                else
                    arrows.left:Show(); arrows.right:Show()
                end
                if pf._arrowOverlay then pf._arrowOverlay:Show() end
            else
                if ns.SetTargetIndicatorShown then
                    ns.SetTargetIndicatorShown(pf, false)
                else
                    arrows.left:Hide(); arrows.right:Hide()
                end
                if pf._arrowOverlay then pf._arrowOverlay:Hide() end
            end

            -- Height calculation "top" slot determines the area above the name
            -- Find which aura type is in the "top" slot for height,
            -- including per-slot Y offsets that push elements further up.
            local topExtent = 0
            local function isTopSlot(s) return s == "top" or s == "topleft" or s == "topright" end
            if isTopSlot(debuffSlotVal) then topExtent = math.max(topExtent, debuffSz + debuffYOff) end
            if isTopSlot(buffSlotVal) then topExtent = math.max(topExtent, buffSz + buffYOff) end
            if isTopSlot(ccSlotVal) then topExtent = math.max(topExtent, ccSz + ccYOff) end
            if isTopSlot(rmPos) and showRM then topExtent = math.max(topExtent, rmSize + rmYOff) end
            if isTopSlot(clPos) and showCL then topExtent = math.max(topExtent, reIconSz + clYOff) end
            -- Only include name text height when something is actually in the top slot
            local topTextH = (slotTop ~= "none") and (topFontSz + 4 + nameYOff + topYOff) or 0
            -- Only add debuffY gap when something occupies the center "top" position or top text slot
            local hasTopCenter = false
            if debuffSlotVal == "top" then hasTopCenter = true end
            if buffSlotVal == "top" then hasTopCenter = true end
            if ccSlotVal == "top" then hasTopCenter = true end
            if rmPos == "top" and showRM then hasTopCenter = true end
            if clPos == "top" and showCL then hasTopCenter = true end
            local effectiveDebuffY = (hasTopCenter or slotTop ~= "none") and debuffY or 0
            local healthFromTop = Snap(15 + 4 + topExtent + effectiveDebuffY + topTextH + cpPush)
            health:ClearAllPoints()
            health:SetSize(barW, barH)

            -- Size the plain-Frame wrapper to match the health bar exactly.
            -- The image border lives on this wrapper (not on the StatusBar).
            healthWrapper:ClearAllPoints()
            healthWrapper:SetSize(barW, barH)

            local pfW = localParentW
            local dragging = IsDragging()
            local xOff
            if dragging and _cachedRawBarW then
                local delta = (rawBarW - _cachedRawBarW) / 2
                xOff = _cachedXOff - delta
                health:SetPoint("TOPLEFT", pf, "TOPLEFT", xOff, -healthFromTop)
                healthWrapper:SetPoint("TOPLEFT", pf, "TOPLEFT", xOff, -healthFromTop)
            else
                xOff           = Snap((pfW - barW) / 2)
                _cachedRawBarW = rawBarW
                _cachedXOff    = xOff
                health:SetPoint("TOPLEFT", pf, "TOPLEFT", xOff, -healthFromTop)
                healthWrapper:SetPoint("TOPLEFT", pf, "TOPLEFT", xOff, -healthFromTop)
            end

            -- Preview custom health markers (treat preview as "target")
            do
                local markerCfg = MarkerCfg()
                if markerCfg and markerCfg.enabled == true then
                    local values = ParseHealthMarkerValues(markerCfg.values, 100)
                    local width = tonumber(markerCfg.width) or 2
                    local r = markerCfg.colorR or 1
                    local g = markerCfg.colorG or 1
                    local b = markerCfg.colorB or 1
                    local a = markerCfg.colorA or 0.80
                    for i = 1, 3 do
                        local tex = previewMarkers[i]
                        local pct = values[i]
                        if tex and pct then
                            local xPos = barW * (pct / 100)
                            tex:ClearAllPoints()
                            tex:SetPoint("TOP", health, "TOPLEFT", xPos, 0)
                            tex:SetPoint("BOTTOM", health, "BOTTOMLEFT", xPos, 0)
                            tex:SetWidth(Snap(width))
                            tex:SetColorTexture(r, g, b, a)
                            tex:Show()
                        elseif tex then
                            tex:Hide()
                        end
                    end
                else
                    for i = 1, 3 do
                        if previewMarkers[i] then previewMarkers[i]:Hide() end
                    end
                end
            end

            -- Preview bar texture: apply via SetStatusBarTexture
            do
                local texKey = DBVal("healthBarTexture") or "none"
                local texPath = ns.healthBarTextures[texKey]
                if texPath then
                    health:SetStatusBarTexture(texPath)
                else
                    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
                end
                UnsnapTex(health:GetStatusBarTexture())
            end

            -- Class power pips (preview uses live class/spec resource count, ~70% filled)
            local showCP = DBVal("showClassPower") == true
            local cpExtraH = 0
            local cpIsBarType = false
            local cpResourceName = nil
            if showCP then
                -- Determine pip count from player's class, using live UnitPowerMax when available
                local _, playerClass = UnitClass("player")
                local cpInfo = CP.CLASS_MAP[playerClass]
                local cpMax = 0
                if cpInfo then
                    -- Resolve spec-specific entries (numeric specID keys)
                    if cpInfo[1] == nil then
                        local spec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization())
                            or (GetSpecialization and GetSpecialization())
                        local specID
                        if spec then
                            if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
                                specID = C_SpecializationInfo.GetSpecializationInfo(spec)
                            elseif GetSpecializationInfo then
                                specID = GetSpecializationInfo(spec)
                            end
                        end
                        cpInfo = specID and cpInfo[specID]
                    end
                    if cpInfo then
                        cpResourceName = type(cpInfo[1]) == "string" and cpInfo[1] or nil
                        if type(cpInfo[1]) == "string" then
                            if cpInfo[1] == "BREWMASTER_STAGGER" then
                                cpIsBarType = true
                                cpMax = 1
                            elseif cpInfo[1] == "SOUL_FRAGMENTS_VENGEANCE" then
                                cpMax = 6
                            elseif cpInfo[1] == "MAELSTROM_WEAPON" and KT and KT.GetMaelstromWeapon then
                                local _, mMax = KT.GetMaelstromWeapon()
                                cpMax = (mMax and mMax > 0) and mMax or cpInfo[2]
                            elseif cpInfo[1] == "TIP_OF_THE_SPEAR" then
                                cpMax = cpInfo[2]
                            elseif cpInfo[1] == "WHIRLWIND_STACKS" then
                                cpMax = cpInfo[2]
                            else
                                cpMax = cpInfo[2]
                            end
                        else
                            local liveMax = UnitPowerMax("player", cpInfo[1])
                            cpMax = (liveMax and liveMax > 0) and liveMax or cpInfo[2]
                        end
                    end
                end
                local cpCur = math.floor(cpMax * CP.FILL_FRAC + 0.5)
                local useClassColors = DBVal("classPowerClassColors")
                if useClassColors == nil then useClassColors = defaults.classPowerClassColors end
                local cpColor = CP.DEFAULT_COLOR
                if useClassColors then
                    cpColor = CP.CLASS_COLORS[playerClass] or CP.DEFAULT_COLOR
                else
                    local cc = (DB() and DB().classPowerCustomColor) or defaults.classPowerCustomColor
                    cpColor = { cc.r, cc.g, cc.b }
                end

                local cpBgCol = (DB() and DB().classPowerBgColor) or defaults.classPowerBgColor

                if cpIsBarType then
                    -- Bar-type preview (stagger): single StatusBar
                    for i = 1, CP.MAX_POSSIBLE do
                        CP.pips[i]:Hide()
                        if CP.pips[i]._bg then CP.pips[i]._bg:Hide() end
                    end
                    local cpScale = DBVal("classPowerScale") or defaults.classPowerScale
                    local cpYOff  = DBVal("classPowerYOffset") or defaults.classPowerYOffset
                    local cpXOff  = DBVal("classPowerXOffset") or defaults.classPowerXOffset
                    local cpPos   = DBVal("classPowerPos") or defaults.classPowerPos
                    local scaledH = Snap(CP.PIP_H * cpScale)
                    local barW    = Snap(CP.PIP_W * cpScale * 6)

                    local anchorPoint, anchorRelPoint, anchorFrame, yDir
                    if cpPos == "top" then
                        anchorPoint    = "BOTTOM"
                        anchorRelPoint = "TOP"
                        anchorFrame    = health
                        yDir           = 1
                    else
                        anchorPoint    = "TOP"
                        anchorRelPoint = "BOTTOM"
                        anchorFrame    = cast
                        yDir           = -1
                    end

                    local bar = CP.bar
                    bar:ClearAllPoints()
                    bar:SetSize(barW, scaledH)
                    bar:SetPoint(anchorPoint, anchorFrame, anchorRelPoint,
                        Snap(cpXOff), Snap(yDir * cpYOff))
                    bar:SetMinMaxValues(0, 100)
                    bar:SetValue(45)                         -- preview at 45% (moderate stagger)
                    bar:SetStatusBarColor(1.0, 0.85, 0.2, 1) -- yellow for preview
                    bar._bg:SetColorTexture(cpBgCol.r, cpBgCol.g, cpBgCol.b, cpBgCol.a)
                    bar:Show()

                    if cpPos ~= "top" then
                        cpExtraH = cpYOff + scaledH
                    end
                elseif cpMax <= 0 then
                    for i = 1, CP.MAX_POSSIBLE do
                        CP.pips[i]:Hide()
                        if CP.pips[i]._bg then CP.pips[i]._bg:Hide() end
                    end
                    CP.bar:Hide()
                else
                    CP.bar:Hide()
                    local cpScale   = DBVal("classPowerScale") or defaults.classPowerScale
                    local cpYOff    = DBVal("classPowerYOffset") or defaults.classPowerYOffset
                    local cpXOff    = DBVal("classPowerXOffset") or defaults.classPowerXOffset
                    local cpPos     = DBVal("classPowerPos") or defaults.classPowerPos
                    local cpGap     = DBVal("classPowerGap") or defaults.classPowerGap
                    local scaledW   = Snap(CP.PIP_W * cpScale)
                    local scaledH   = Snap(CP.PIP_H * cpScale)
                    local scaledGap = Snap(cpGap * cpScale)
                    local totalPipW = cpMax * scaledW + (cpMax - 1) * scaledGap

                    -- Determine anchor frame and direction
                    local anchorPoint, anchorRelPoint, anchorFrame, yDir
                    if cpPos == "top" then
                        anchorPoint    = "BOTTOM"
                        anchorRelPoint = "TOP"
                        anchorFrame    = health
                        yDir           = 1
                    else
                        -- Bottom: attach below cast bar (preview always shows cast bar)
                        anchorPoint    = "TOP"
                        anchorRelPoint = "BOTTOM"
                        anchorFrame    = cast
                        yDir           = -1
                    end

                    local cpEmptyCol = (DB() and DB().classPowerEmptyColor) or defaults.classPowerEmptyColor

                    -- Pre-compute each pip's left-edge X in group-local coords.
                    -- Position by BOTTOMLEFT/TOPLEFT to avoid half-pixel center offsets.
                    local pipPositions = {}
                    for i = 1, cpMax do
                        pipPositions[i] = Snap((i - 1) * (scaledW + scaledGap))
                    end
                    local groupW = pipPositions[cpMax] + scaledW
                    local halfGroup = Snap(groupW / 2)

                    local leftAnchor = (anchorPoint == "BOTTOM") and "BOTTOMLEFT" or "TOPLEFT"

                    for i = 1, CP.MAX_POSSIBLE do
                        local pip = CP.pips[i]
                        if i <= cpMax then
                            pip:ClearAllPoints()
                            pip:SetSize(scaledW, scaledH)
                            local pipLeftX = Snap(pipPositions[i] - halfGroup + cpXOff)
                            pip:SetPoint(leftAnchor, anchorFrame, anchorRelPoint,
                                pipLeftX, Snap(yDir * cpYOff))

                            -- Background behind each pip
                            local bg = pip._bg
                            if bg then
                                bg:ClearAllPoints()
                                bg:SetAllPoints(pip)
                                bg:SetColorTexture(cpBgCol.r, cpBgCol.g, cpBgCol.b, cpBgCol.a)
                                bg:Show()
                            end

                            if i <= cpCur then
                                pip:SetColorTexture(cpColor[1], cpColor[2], cpColor[3], 1)
                            else
                                pip:SetColorTexture(cpEmptyCol.r, cpEmptyCol.g, cpEmptyCol.b, cpEmptyCol.a)
                            end
                            UnsnapTex(pip)
                            pip:Show()
                        else
                            pip:Hide()
                            if pip._bg then pip._bg:Hide() end
                        end
                    end
                    -- Extra height only when pips are below the cast bar
                    if cpPos ~= "top" then
                        cpExtraH = cpYOff + scaledH
                    end
                end
            else
                for i = 1, CP.MAX_POSSIBLE do
                    CP.pips[i]:Hide()
                    if CP.pips[i]._bg then CP.pips[i]._bg:Hide() end
                end
                CP.bar:Hide()
            end

            pf._cpTopPush = cpPush

            local totalH = Snap(healthFromTop + barH + castH + cpExtraH + 15)
            -- Add extra height for auras in the "bottom" slot (below cast bar)
            local bottomExtent = 0
            local function isBottomSlot(s) return s == "bottom" end
            if isBottomSlot(debuffSlotVal) then bottomExtent = math.max(bottomExtent, debuffSz + 2 - debuffYOff) end
            if isBottomSlot(buffSlotVal) then bottomExtent = math.max(bottomExtent, buffSz + 2 - buffYOff) end
            if isBottomSlot(ccSlotVal) then bottomExtent = math.max(bottomExtent, ccSz + 2 - ccYOff) end
            if isBottomSlot(rmPos) and showRM then bottomExtent = math.max(bottomExtent, rmSize + 2 - rmYOff) end
            if isBottomSlot(clPos) and showCL then bottomExtent = math.max(bottomExtent, reIconSz + 2 - clYOff) end
            totalH = totalH + bottomExtent
            self:SetSize(localParentW, totalH)

            -- Target glow preview (9-slice soft glow matching real nameplates)
            local pgf = previewGlow.frame
            pgf:ClearAllPoints()
            local ge = previewGlow.extend
            PP.Point(pgf, "TOPLEFT", healthWrapper, "TOPLEFT", -ge, ge)
            PP.Point(pgf, "BOTTOMRIGHT", healthWrapper, "BOTTOMRIGHT", ge, -ge)
            local glowStyle = DBVal("targetGlowStyle") or defaults.targetGlowStyle
            local showGlow = showTargetGlowPreview and (glowStyle == "kullthranui" or glowStyle == "vibrant")
            if showGlow then
                local glowColor = (DB() and DB().targetGlowColor) or defaults.targetGlowColor
                or { r = 0.00, g = 0.6157, b = 1.00 }
                local glowR = glowColor.r or glowColor[1] or 0.4117
                local glowG = glowColor.g or glowColor[2] or 0.6667
                local glowB = glowColor.b or glowColor[3] or 1.0
                if glowStyle == "vibrant" then
                    if previewGlow.soft then
                        previewGlow.soft:SetVertexColor(glowR, glowG, glowB, 1)
                        previewGlow.soft:SetAlpha(0.55)
                    end
                    if previewGlow.hard then
                        previewGlow.hard:SetVertexColor(glowR, glowG, glowB, 1)
                        previewGlow.hard:SetAlpha(0.30)
                    end
                else
                    if previewGlow.soft then
                        previewGlow.soft:SetVertexColor(glowR, glowG, glowB, 1)
                        previewGlow.soft:SetAlpha(0.75)
                    end
                    if previewGlow.hard then
                        previewGlow.hard:SetVertexColor(glowR, glowG, glowB, 1)
                        previewGlow.hard:SetAlpha(0.40)
                    end
                end
                pgf:Show()
            else
                pgf:Hide()
            end
            -- Vibrant: also override border to white on preview
            if showTargetGlowPreview and glowStyle == "vibrant" then
                local color = (DB() and DB().targetGlowColor) or defaults.targetGlowColor
                    or { r = 0.4117, g = 0.6667, b = 1.0 }
                local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
                for _, tex in ipairs(borderFrame._texs) do tex:SetVertexColor(r, g, b) end
                for _, tex in ipairs(simpleBorderFrame._texs) do tex:SetVertexColor(r, g, b) end
                for _, e in ipairs(_solidEdges) do
                    e:SetColorTexture(r, g, b, 1); UnsnapTex(e)
                end
            end

            -- Notify framework so the scroll area adjusts to the new preview height
            -- Add the preset header offset + bottom padding so the full content header
            -- height is reported (not just the preview frame height).
            -- totalH is in preview-local coordinates; convert to parent-space.
            local headerExtra = pf._headerExtra or 0
            local hintH = (_previewHintFS and _previewHintFS:IsShown()) and 29 or 0
            -- KT: no content header (no-op; was UpdateContentHeaderHeight)

            -- Refresh text overlay sizes (font/text may have changed)
            if pf._textOverlays then
                for _, ov in ipairs(pf._textOverlays) do
                    if ov._resizeToText then ov._resizeToText() end
                end
            end
        end

        -- Expose preview elements for click-navigation hit overlays
        pf._nameFS        = nameFS
        pf._hpText        = hpText
        pf._hpNumber      = hpNumber
        pf._debuffs       = debuffs
        pf._buffs         = buffs
        pf._ccs           = ccs
        pf._cast          = cast
        pf._castIconFrame = castParts.iconFrame
        pf._castNameFS    = castParts.nameFS
        pf._castTargetFS  = castParts.targetFS
        pf._raidFrame     = raidFrame
        pf._classIcon     = classIcon
        pf._health        = health
        pf._healthWrapper = healthWrapper
        pf._cpPips        = CP.pips
        pf._cpBar         = CP.bar
        pf._cpMax         = CP.MAX_POSSIBLE
        pf._arrows        = arrows

        activePreview     = pf
        pf:Update()
        -- Return visual height in parent-scale pixels (pf:GetHeight() is local, scale it)
        return pf:GetHeight() * previewScale
    end

    local function BuildFriendlyNameplatePreview(parent, parentW)
        local function ApplyPreviewFont(fs, size)
            local fontPath = (KT and KT.GetNPFontPath and KT.GetNPFontPath("nameplates")) or DBVal("font") or KT.FONT_PATH
            local outline = GetNPOptOutline()
            fs:SetFont(fontPath, size or 11, outline)
            if KT and KT.EnableTextFontFallback then
                KT:EnableTextFontFallback(fs, fontPath)
            end
            if outline == "" and KT.GetNPFontUseShadow and KT.GetNPFontUseShadow() then
                fs:SetShadowOffset(1, -1)
                fs:SetShadowColor(0, 0, 0, 1)
            else
                fs:SetShadowOffset(0, 0)
                fs:SetShadowColor(0, 0, 0, 0)
            end
        end

        local function CreateBorder(frame)
            local edges = {}
            local function edge()
                local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
                t:SetColorTexture(0, 0, 0, 1)
                edges[#edges + 1] = t
                return t
            end
            local t = edge()
            local b = edge()
            local l = edge()
            local r = edge()
            frame._borderEdges = edges
            frame._borderTop = t
            frame._borderBottom = b
            frame._borderLeft = l
            frame._borderRight = r
        end

        local function LayoutBorder(frame, px)
            if not frame._borderTop then return end
            frame._borderTop:ClearAllPoints()
            frame._borderTop:SetPoint("TOPLEFT")
            frame._borderTop:SetPoint("TOPRIGHT")
            frame._borderTop:SetHeight(px)
            frame._borderBottom:ClearAllPoints()
            frame._borderBottom:SetPoint("BOTTOMLEFT")
            frame._borderBottom:SetPoint("BOTTOMRIGHT")
            frame._borderBottom:SetHeight(px)
            frame._borderLeft:ClearAllPoints()
            frame._borderLeft:SetPoint("TOPLEFT", frame._borderTop, "BOTTOMLEFT")
            frame._borderLeft:SetPoint("BOTTOMLEFT", frame._borderBottom, "TOPLEFT")
            frame._borderLeft:SetWidth(px)
            frame._borderRight:ClearAllPoints()
            frame._borderRight:SetPoint("TOPRIGHT", frame._borderTop, "BOTTOMRIGHT")
            frame._borderRight:SetPoint("BOTTOMRIGHT", frame._borderBottom, "TOPRIGHT")
            frame._borderRight:SetWidth(px)
        end

        local function ApplyAlignment(fs, anchor, align, width, mode, yOff)
            fs:ClearAllPoints()
            fs:SetWidth(width or 0)
            fs:SetJustifyH((align == "left" and "LEFT") or (align == "right" and "RIGHT") or "CENTER")
            if mode == "bar-above" then
                if align == "left" then
                    fs:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, yOff or 4)
                elseif align == "right" then
                    fs:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, yOff or 4)
                else
                    fs:SetPoint("BOTTOM", anchor, "TOP", 0, yOff or 4)
                end
            else
                if align == "left" then
                    fs:SetPoint("LEFT", anchor, "LEFT", 0, yOff or 0)
                elseif align == "right" then
                    fs:SetPoint("RIGHT", anchor, "RIGHT", 0, yOff or 0)
                else
                    fs:SetPoint("CENTER", anchor, "CENTER", 0, yOff or 0)
                end
            end
        end

        local function ApplyTopAlignment(fs, anchor, align, width, yOff)
            fs:ClearAllPoints()
            fs:SetWidth(width or 0)
            fs:SetJustifyH((align == "left" and "LEFT") or (align == "right" and "RIGHT") or "CENTER")
            if align == "left" then
                fs:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, yOff or 0)
            elseif align == "right" then
                fs:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, yOff or 0)
            else
                fs:SetPoint("TOP", anchor, "TOP", 0, yOff or 0)
            end
        end

        local function FriendlyColor(key, defaultR, defaultG, defaultB)
            local db = DB()
            local c = db and db[key] or defaults[key]
            if c and c.r and c.g and c.b then
                return c
            end
            return { r = defaultR, g = defaultG, b = defaultB }
        end

        local pf = CreateFrame("Frame", nil, parent)
        pf:SetPoint("TOP", parent, "TOP", 0, 0)
        pf._parentW = parentW

        local function CreateEntry()
            local entry = CreateFrame("Frame", nil, pf)
            entry.health = CreateFrame("StatusBar", nil, entry)
            entry.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            entry.healthBG = entry.health:CreateTexture(nil, "BACKGROUND")
            entry.healthBG:SetAllPoints()
            entry.healthBG:SetColorTexture(0.12, 0.12, 0.12, 1)
            CreateBorder(entry.health)
            entry.name = entry:CreateFontString(nil, "OVERLAY")
            entry.name:SetWordWrap(false)
            entry.name:SetMaxLines(1)
            entry.guild = entry:CreateFontString(nil, "OVERLAY")
            entry.guild:SetWordWrap(false)
            entry.guild:SetMaxLines(1)
            entry.hpText = entry.health:CreateFontString(nil, "OVERLAY")
            return entry
        end

        local player = CreateEntry()
        local npc = CreateEntry()
        pf._player = player
        pf._npc = npc

        function pf:Update()
            local previewScale = UIParent:GetEffectiveScale() / parent:GetEffectiveScale()
            self:SetScale(previewScale)
            local localParentW = (self._parentW or parentW) / previewScale
            local width = DBVal("friendlyHealthBarWidth") or defaults.friendlyHealthBarWidth
            local barH = DBVal("friendlyHealthBarHeight") or defaults.friendlyHealthBarHeight
            local px = math.max(1 / previewScale, 1)
            local nameOnly = DBVal("friendlyNameOnly") ~= false
            local playerAlign = DBVal("friendlyPlayerNameAlignment") or defaults.friendlyPlayerNameAlignment
            local npcAlign = DBVal("friendlyNPCNameAlignment") or defaults.friendlyNPCNameAlignment
            local playerNameColor = FriendlyColor("friendlyPlayerNameColor", 1, 1, 1)
            local guildColor = FriendlyColor("friendlyGuildColor", 1, 1, 1)
            local hpColor = FriendlyColor("friendlyHealthTextColor", 1, 1, 1)
            local npcColor = FriendlyColor("friendlyNPCNameColor", 0, 1, 0)
            local guildEnabled = DBVal("friendlyShowGuild") ~= false

            local playerNameColorApplied = playerNameColor
            if DBVal("classColorFriendly") ~= false then
                playerNameColorApplied = RAID_CLASS_COLORS and RAID_CLASS_COLORS.MAGE or playerNameColor
            end

            ApplyPreviewFont(player.name, DBVal("friendlyPlayerNameTextSize") or defaults.friendlyPlayerNameTextSize)
            ApplyPreviewFont(player.guild, DBVal("friendlyGuildTextSize") or defaults.friendlyGuildTextSize)
            ApplyPreviewFont(player.hpText, DBVal("friendlyHealthTextSize") or defaults.friendlyHealthTextSize)
            ApplyPreviewFont(npc.name, DBVal("friendlyNPCNameTextSize") or defaults.friendlyNPCNameTextSize)

            player.name:SetTextColor(playerNameColorApplied.r, playerNameColorApplied.g, playerNameColorApplied.b, 1)
            player.guild:SetTextColor(guildColor.r, guildColor.g, guildColor.b, 1)
            player.hpText:SetTextColor(hpColor.r, hpColor.g, hpColor.b, 1)
            npc.name:SetTextColor(npcColor.r, npcColor.g, npcColor.b, 1)

            player.name:SetText(LText("Friendly Player"))
            player.guild:SetText("<KullThranUI>")
            player.hpText:SetText("82%")
            npc.name:SetText(LText("Friendly NPC"))

            if nameOnly then
                player.health:Hide()
                npc.health:Hide()
                player.hpText:Hide()
                player.guild:SetShown(guildEnabled)

                player:SetSize(localParentW, 28)
                player:ClearAllPoints()
                player:SetPoint("TOP", self, "TOP", 0, -10)
                ApplyAlignment(player.name, player, playerAlign, 0, "name-only", 0)
                player.guild:ClearAllPoints()
                player.guild:SetWidth(0)
                player.guild:SetJustifyH((playerAlign == "left" and "LEFT") or (playerAlign == "right" and "RIGHT") or "CENTER")
                if playerAlign == "left" then
                    player.guild:SetPoint("TOPLEFT", player.name, "BOTTOMLEFT", 0, -1)
                elseif playerAlign == "right" then
                    player.guild:SetPoint("TOPRIGHT", player.name, "BOTTOMRIGHT", 0, -1)
                else
                    player.guild:SetPoint("TOP", player.name, "BOTTOM", 0, -1)
                end

                npc:SetSize(localParentW, 18)
                npc:ClearAllPoints()
                npc:SetPoint("TOP", player.guild:IsShown() and player.guild or player.name, "BOTTOM", 0, -10)
                ApplyAlignment(npc.name, npc, npcAlign, 0, "name-only", 0)
                self:SetSize(localParentW, 90)
            else
                player.health:Show()
                npc.health:Show()
                player.hpText:Show()
                player.guild:SetShown(guildEnabled)

                local playerNameH = math.max(player.name:GetStringHeight() or 0, 14)
                local guildH = player.guild:IsShown() and math.max(player.guild:GetStringHeight() or 0, 11) or 0
                local npcNameH = math.max(npc.name:GetStringHeight() or 0, 14)
                local playerTopBlockH = playerNameH + (player.guild:IsShown() and (guildH + 2) or 0)

                player:SetSize(width, playerTopBlockH + barH + 14)
                player:ClearAllPoints()
                player:SetPoint("TOP", self, "TOP", 0, -6)
                ApplyTopAlignment(player.name, player, playerAlign, width, 0)
                player.guild:ClearAllPoints()
                player.guild:SetWidth(width)
                player.guild:SetJustifyH((playerAlign == "left" and "LEFT") or (playerAlign == "right" and "RIGHT") or "CENTER")
                if player.guild:IsShown() then
                    if playerAlign == "left" then
                        player.guild:SetPoint("TOPLEFT", player.name, "BOTTOMLEFT", 0, -2)
                    elseif playerAlign == "right" then
                        player.guild:SetPoint("TOPRIGHT", player.name, "BOTTOMRIGHT", 0, -2)
                    else
                        player.guild:SetPoint("TOP", player.name, "BOTTOM", 0, -2)
                    end
                end
                player.health:ClearAllPoints()
                player.health:SetPoint("TOP", player.guild:IsShown() and player.guild or player.name, "BOTTOM", 0, -8)
                player.health:SetSize(width, barH)
                player.health:SetMinMaxValues(0, 100)
                player.health:SetValue(82)
                player.health:SetStatusBarColor(0.41, 0.8, 0.94, 1)
                LayoutBorder(player.health, px)
                player.hpText:ClearAllPoints()
                player.hpText:SetPoint("RIGHT", player.health, "RIGHT", -3, 0)

                npc:SetSize(width, npcNameH + barH + 14)
                npc:ClearAllPoints()
                npc:SetPoint("TOP", player.health, "BOTTOM", 0, -28)
                ApplyTopAlignment(npc.name, npc, npcAlign, width, 0)
                npc.health:ClearAllPoints()
                npc.health:SetPoint("TOP", npc.name, "BOTTOM", 0, -8)
                npc.health:SetSize(width, barH)
                npc.health:SetMinMaxValues(0, 100)
                npc.health:SetValue(100)
                npc.health:SetStatusBarColor(0, 0.82, 0.62, 1)
                LayoutBorder(npc.health, px)
                self:SetSize(localParentW, playerTopBlockH + npcNameH + (barH * 2) + 70)
            end
        end

        activeFriendlyPreview = pf
        pf:Update()
        return pf:GetHeight() * (pf:GetScale() or 1)
    end

    ---------------------------------------------------------------------------
    --  General page  (Friendly settings, Spacing, Show All Debuffs)
    --  Two-column layout using DualRow where possible
    ---------------------------------------------------------------------------
    -- Pandemic preview: randomized spell icon with live glow
    -- Spell IDs mapped by class for preview icon (prioritize player's class)
    local PANDEMIC_PREVIEW_BY_CLASS = {
        DRUID       = { 1079, 8921 }, -- Rip, Moonfire
        DEATHKNIGHT = { 194310 }, -- Festering Wound
        SHAMAN      = { 188389 }, -- Flame Shock
        WARLOCK     = { 980 },    -- Agony
        ROGUE       = { 1943 },   -- Rupture
    }
    local PANDEMIC_PREVIEW_FALLBACK = { 1079, 8921, 194310, 188389, 980, 1943 }
    local _pandemicPreviewIcon  -- resolved icon fileID
    local _pandemicPreviewFrame -- the preview icon frame (persists across rebuilds)

    local function RandomizePandemicPreview()
        local _, playerClass = UnitClass("player")
        local pool = PANDEMIC_PREVIEW_BY_CLASS[playerClass] or PANDEMIC_PREVIEW_FALLBACK
        local spellID = pool[math.random(#pool)]
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            if info and info.iconID then
                _pandemicPreviewIcon = info.iconID
            else
                _pandemicPreviewIcon = 136197
            end
        else
            _pandemicPreviewIcon = 136197
        end
        -- Update the texture on the existing frame if it exists
        if _pandemicPreviewFrame and _pandemicPreviewFrame._iconTex then
            _pandemicPreviewFrame._iconTex:SetTexture(_pandemicPreviewIcon)
        end
    end

    local function RefreshPandemicPreview()
        if not _pandemicPreviewFrame then return end
        local f = _pandemicPreviewFrame

        -- Create or reuse FlipBook overlay
        if not f._flipTex then
            local flipTex = f:CreateTexture(nil, "OVERLAY", nil, 7)
            flipTex:SetPoint("CENTER")
            local animGroup = flipTex:CreateAnimationGroup()
            animGroup:SetLooping("REPEAT")
            local flipAnim = animGroup:CreateAnimation("FlipBook")
            f._flipTex = flipTex
            f._animGroup = animGroup
            f._flipAnim = flipAnim
        end

        -- Stop all current animations
        f._animGroup:Stop()
        f._flipTex:Hide()
        ns.StopProceduralAnts(f)
        ns.StopButtonGlow(f)
        ns.StopAutoCastShine(f)

        -- Gray out preview when pandemic glow is off
        local off = DBVal("pandemicGlow") ~= true
        f:SetAlpha(off and 0.3 or 1)

        -- Only show glow if pandemic glow is enabled
        if off then return end

        -- Use the core addon's migration logic (writes back to DB)
        local styleIdx = ns.GetPandemicGlowStyle and ns.GetPandemicGlowStyle() or (DBVal("pandemicGlowStyle") or 1)
        if type(styleIdx) ~= "number" then styleIdx = 1 end
        local styles = ns.PANDEMIC_GLOW_STYLES
        if styleIdx < 1 or styleIdx > #styles then styleIdx = 1 end
        local entry = styles[styleIdx]

        local c = DB().pandemicGlowColor or defaults.pandemicGlowColor
        local cr, cg, cb = c.r, c.g, c.b
        local iconSize = 36

        if entry.procedural then
            -- Pixel Glow: procedural ants preview
            local N = DBVal("pandemicGlowLines") or defaults.pandemicGlowLines
            local th = DBVal("pandemicGlowThickness") or defaults.pandemicGlowThickness
            local speed = DBVal("pandemicGlowSpeed") or defaults.pandemicGlowSpeed
            local period = speed
            local lineLen = math.floor((iconSize + iconSize) * (2 / N - 0.1))
            lineLen = math.min(lineLen, iconSize)
            if lineLen < 1 then lineLen = 1 end
            ns.StartProceduralAnts(f, N, th, period, lineLen, cr, cg, cb, iconSize)
        elseif entry.buttonGlow then
            -- Action Button Glow preview
            ns.StartButtonGlow(f, iconSize, cr, cg, cb, entry.previewScale or 1.28)
        elseif entry.autocast then
            -- Auto-Cast Shine preview
            ns.StartAutoCastShine(f, iconSize, cr, cg, cb)
        else
            -- FlipBook preview (GCD, Modern WoW, Classic WoW)
            local texSz = iconSize * (entry.previewScale or entry.scale or 1)
            f._flipTex:SetSize(texSz, texSz)
            if entry.atlas then
                f._flipTex:SetAtlas(entry.atlas)
            elseif entry.texture then
                f._flipTex:SetTexture(entry.texture)
            end
            f._flipAnim:SetFlipBookRows(entry.rows or 6)
            f._flipAnim:SetFlipBookColumns(entry.columns or 5)
            f._flipAnim:SetFlipBookFrames(entry.frames or 30)
            f._flipAnim:SetDuration(entry.duration or 1.0)
            f._flipAnim:SetFlipBookFrameWidth(entry.frameW or 0)
            f._flipAnim:SetFlipBookFrameHeight(entry.frameH or 0)

            -- Always apply color tint (fixes default FFEB96 showing as blue)
            f._flipTex:SetDesaturated(true)
            f._flipTex:SetVertexColor(cr, cg, cb)

            f._flipTex:Show()
            f._animGroup:Play()
        end
    end

    local function BuildGeneralPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local COGS_ICON = (KT and KT.RESIZE_ICON) or "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png"
        local y = yOffset
        local _, h

        -- No preview on General tab
        -- KT: no content header

        -- Randomize pandemic preview icon each time this tab is opened
        RandomizePandemicPreview()

        -- Enable per-row center divider for the dual-column layout
        parent._showRowDivider = true

        _, h = W:SectionHeader(parent, "GENERAL", y); y = y - h
        _, h = W:Toggle(parent, "Enable Module", y,
            function() return DBVal("enable") ~= false end,
            function(v)
                DB().enable = v and true or false
                ReloadUI()
            end); y = y - h

        -----------------------------------------------------------------------
        --  FRIENDLY NAMEPLATES
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_FRIENDLY, y); y = y - h

        local function friendlyPlayersOff() return DBVal("showFriendlyPlayers") == false and
            DBVal("friendlyShowDefaultNames") ~= true end
        local function friendlyPlateOff() return friendlyPlayersOff() or DBVal("friendlyNameOnly") ~= false end
        local function nameOnlyOff() return friendlyPlayersOff() or DBVal("friendlyNameOnly") == false end

        local friendlyRow
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Show Friendly Player Nameplates"),
                getValue = function() return DBVal("showFriendlyPlayers") ~= false end,
                setValue = function(v)
                    DB().showFriendlyPlayers = v
                    if v then DB().friendlyShowDefaultNames = false end
                    if SetCVar then
                        pcall(SetCVar, "nameplateShowFriendlyPlayers", v and 1 or 0)
                        pcall(SetCVar, "nameplateShowFriends", v and 1 or 0)
                    end
                    if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                    -- Re-assert stacking after friendly CVar changes, since Blizzard
                    -- can reset the stacking bitfield as a side effect.
                    ns.RefreshStackingMotion()
                    KT:RefreshPage()
                end
            },
            {
                type = "toggle",
                text = LText("Make Friendly Nameplates Name Only"),
                tooltip =
                "Hide friendly player health bars and instead only see their names.\n\nRequires 'Simplified Friendly Nameplates' to be disabled in Blizzard's Nameplate settings (Esc > Options > Nameplates).",
                getValue = function() return DBVal("friendlyNameOnly") ~= false end,
                setValue = function(v)
                    DB().friendlyNameOnly = v
                    if SetCVar then pcall(SetCVar, "nameplateShowOnlyNameForFriendlyPlayerUnits", v and 1 or 0) end
                    if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                    KT:RefreshPage()
                end,
                disabled = friendlyPlayersOff,
                disabledTooltip = "Show Friendly Player Nameplates"
            }); friendlyRow = _; y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Show Guild Under Friendly Players"),
                tooltip = "Shows the player's guild name under friendly player nameplates (white text).",
                getValue = function() return DBVal("friendlyShowGuild") ~= false end,
                setValue = function(v)
                    DB().friendlyShowGuild = v
                    if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                    if ns.friendlyPlates then
                        for _, plate in pairs(ns.friendlyPlates) do
                            if plate.UpdateName then plate:UpdateName() end
                        end
                    end
                end,
                disabled = friendlyPlayersOff,
                disabledTooltip = "Show Friendly Player Nameplates"
            },
            { type = "label", text = "" }); y = y - h

        ---------------------------------------------------------------
        --  Friendly Player cog popup (Distance, Height, Width, Show Health %)
        ---------------------------------------------------------------
        do
            local fpPopup, fpPopupOwner
            local function ShowFriendlyPlayerPopup(anchorBtn)
                if not fpPopup then
                    local SolidTex         = KT.SolidTex
                    local MakeBorder       = KT.MakeBorder
                    local MakeFont         = KT.MakeFont
                    local BuildSliderCore  = KT.BuildSliderCore
                    local BORDER_COLOR     = KT.NP_BORDER_COLOR
                    local SL_INPUT_A       = KT.NP_SL_INPUT_A

                    local SIDE_PAD         = 14; local TOP_PAD = 14
                    local TITLE_H          = 11; local TITLE_GAP = 10; local GAP = 10
                    local ROW_H            = 24; local TOGGLE_ROW_H = 28
                    local POPUP_INPUT_A    = 0.55

                    local INPUT_W          = 34; local SLIDER_INPUT_GAP = 8; local LABEL_SLIDER_GAP = 12
                    local MIN_POPUP_W      = 180

                    local totalH           = TOP_PAD + TITLE_H + TITLE_GAP + GAP
                        + ROW_H + GAP + ROW_H + GAP + ROW_H + GAP + TOGGLE_ROW_H + GAP + TOGGLE_ROW_H
                        + TOP_PAD

                    local pf               = CreateFrame("Frame", nil, UIParent)
                    pf:SetSize(260, totalH)
                    pf:SetFrameStrata("FULLSCREEN_DIALOG"); pf:SetFrameLevel(math.max(1200, (KT.MenuPrincipal and KT.MenuPrincipal:GetFrameLevel() or 0) + 80))
                    pf:EnableMouse(true); pf:Hide()

                    local bg = SolidTex(pf, "BACKGROUND", 0.06, 0.08, 0.10, 0.95)
                    bg:SetAllPoints()
                    MakeBorder(pf, BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.15)

                    local titleFS = MakeFont(pf, 11, "", 1, 1, 1)
                    titleFS:SetAlpha(0.7)
                    titleFS:SetPoint("TOP", pf, "TOP", 0, -TOP_PAD)
                    titleFS:SetText(LText("Friendly Nameplate Settings"))

                    -- Measure label widths to compute layout BEFORE creating sliders
                    local tmpFS = pf:CreateFontString(nil, "OVERLAY")
                    tmpFS:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, GetNPOptOutline())
                    local labelTexts = { "Distance", "Height", "Width" }
                    local maxLblW = 0
                    for _, txt in ipairs(labelTexts) do
                        tmpFS:SetText(txt)
                        local w = tmpFS:GetStringWidth()
                        if w > maxLblW then maxLblW = w end
                    end
                    tmpFS:Hide()
                    if maxLblW < 10 then maxLblW = 60 end

                    local SLIDER_LEFT = SIDE_PAD + maxLblW + LABEL_SLIDER_GAP
                    local SLIDER_W = math.max(80, 260 - SLIDER_LEFT - SLIDER_INPUT_GAP - INPUT_W - SIDE_PAD)
                    local POPUP_W = math.max(MIN_POPUP_W, SLIDER_LEFT + SLIDER_W + SLIDER_INPUT_GAP + INPUT_W + SIDE_PAD)
                    pf:SetWidth(POPUP_W)

                    -- Row 1: Distance from Friend
                    local r1Y = -(TOP_PAD + TITLE_H + TITLE_GAP + GAP)
                    local lbl1 = MakeFont(pf, 11, nil, 1, 1, 1); lbl1:SetAlpha(0.6)
                    lbl1:SetText(LText("Distance")); lbl1:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r1Y)
                    local t1, v1 = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, ROW_H, 11, POPUP_INPUT_A,
                        -50, 50, 1,
                        function() return DBVal("friendlyPlateYOffset") or 0 end,
                        function(v)
                            DB().friendlyPlateYOffset = v; if ns.RefreshFriendlyPlateYOffset then ns
                                    .RefreshFriendlyPlateYOffset() end
                        end, true)
                    t1:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, r1Y - 2)
                    v1:ClearAllPoints(); v1:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r1Y)

                    -- Row 2: Height
                    local r2Y = r1Y - ROW_H - GAP
                    local lbl2 = MakeFont(pf, 11, nil, 1, 1, 1); lbl2:SetAlpha(0.6)
                    lbl2:SetText(LText("Height")); lbl2:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r2Y)
                    local t2, v2 = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, ROW_H, 11, POPUP_INPUT_A,
                        6, 40, 1,
                        function() return DBVal("friendlyHealthBarHeight") or defaults.friendlyHealthBarHeight end,
                        function(v)
                            DB().friendlyHealthBarHeight = v; if ns.RefreshFriendlyPlateSize then ns
                                    .RefreshFriendlyPlateSize() end
                        end, true)
                    t2:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, r2Y - 2)
                    v2:ClearAllPoints(); v2:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r2Y)

                    -- Row 3: Width
                    local r3Y = r2Y - ROW_H - GAP
                    local lbl3 = MakeFont(pf, 11, nil, 1, 1, 1); lbl3:SetAlpha(0.6)
                    lbl3:SetText(LText("Width")); lbl3:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r3Y)
                    local t3, v3 = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, ROW_H, 11, POPUP_INPUT_A,
                        80, 250, 1,
                        function() return DBVal("friendlyHealthBarWidth") or defaults.friendlyHealthBarWidth end,
                        function(v)
                            DB().friendlyHealthBarWidth = v; if ns.RefreshFriendlyPlateSize then ns
                                    .RefreshFriendlyPlateSize() end
                        end, true)
                    t3:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, r3Y - 2)
                    v3:ClearAllPoints(); v3:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r3Y)

                    -- Row 4: Show Health Percent (toggle inverted from friendlyHideHealthText)
                    local r4Y = r3Y - ROW_H - GAP
                    local lbl4 = MakeFont(pf, 11, nil, 1, 1, 1); lbl4:SetAlpha(0.6)
                    lbl4:SetText(LText("Show Health Percent")); lbl4:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r4Y)

                    local TG_W, TG_H, KNOB_SZ, KNOB_PAD = 32, 16, 12, 2
                    local tgBtn = CreateFrame("Button", nil, pf)
                    tgBtn:SetSize(TG_W, TG_H)
                    tgBtn:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r4Y)

                    local tgBg = SolidTex(tgBtn, "BACKGROUND", 0.18, 0.18, 0.18, 0.85)
                    tgBg:SetAllPoints()
                    local tgKnob = tgBtn:CreateTexture(nil, "ARTWORK")
                    tgKnob:SetColorTexture(0.55, 0.55, 0.55, 1)
                    tgKnob:SetSize(KNOB_SZ, KNOB_SZ)

                    local function UpdateToggle4()
                        local on = not (KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyHideHealthText)
                        if on then
                            local g = KT.NP_GREEN
                            tgBg:SetColorTexture(g.r, g.g, g.b, 0.45)
                            tgKnob:SetColorTexture(1, 1, 1, 0.95)
                            tgKnob:ClearAllPoints(); tgKnob:SetPoint("RIGHT", tgBtn, "RIGHT", -KNOB_PAD, 0)
                        else
                            tgBg:SetColorTexture(0.18, 0.18, 0.18, 0.85)
                            tgKnob:SetColorTexture(0.55, 0.55, 0.55, 1)
                            tgKnob:ClearAllPoints(); tgKnob:SetPoint("LEFT", tgBtn, "LEFT", KNOB_PAD, 0)
                        end
                    end
                    UpdateToggle4()
                    tgBtn:SetScript("OnClick", function()
                        local cur = KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyHideHealthText or false
                        DB().friendlyHideHealthText = not cur
                        if ns.RefreshFriendlyHealthText then ns.RefreshFriendlyHealthText() end
                        UpdateToggle4()
                    end)
                    pf._updateToggle = UpdateToggle4

                    -- Row 5: Show Default Names
                    local r5Y = r4Y - TOGGLE_ROW_H - GAP
                    local lbl5 = MakeFont(pf, 11, nil, 1, 1, 1); lbl5:SetAlpha(0.6)
                    lbl5:SetText(LText("Show Default Names")); lbl5:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r5Y)

                    local tgBtn5 = CreateFrame("Button", nil, pf)
                    tgBtn5:SetSize(TG_W, TG_H)
                    tgBtn5:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r5Y)

                    local tgBg5 = SolidTex(tgBtn5, "BACKGROUND", 0.18, 0.18, 0.18, 0.85)
                    tgBg5:SetAllPoints()
                    local tgKnob5 = tgBtn5:CreateTexture(nil, "ARTWORK")
                    tgKnob5:SetColorTexture(0.55, 0.55, 0.55, 1)
                    tgKnob5:SetSize(KNOB_SZ, KNOB_SZ)

                    local function UpdateToggle5()
                        local on = (KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyShowDefaultNames == true)
                        if on then
                            local g = KT.NP_GREEN
                            tgBg5:SetColorTexture(g.r, g.g, g.b, 0.45)
                            tgKnob5:SetColorTexture(1, 1, 1, 0.95)
                            tgKnob5:ClearAllPoints(); tgKnob5:SetPoint("RIGHT", tgBtn5, "RIGHT", -KNOB_PAD, 0)
                        else
                            tgBg5:SetColorTexture(0.18, 0.18, 0.18, 0.85)
                            tgKnob5:SetColorTexture(0.55, 0.55, 0.55, 1)
                            tgKnob5:ClearAllPoints(); tgKnob5:SetPoint("LEFT", tgBtn5, "LEFT", KNOB_PAD, 0)
                        end
                    end
                    UpdateToggle5()
                    tgBtn5:SetScript("OnClick", function()
                        local cur = KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyShowDefaultNames or false
                        local newVal = not cur
                        DB().friendlyShowDefaultNames = newVal
                        if newVal then
                            -- Turn off friendly nameplates, keep names on
                            DB().showFriendlyPlayers = false
                            if SetCVar then
                                pcall(SetCVar, "nameplateShowFriendlyPlayers", 0)
                                pcall(SetCVar, "nameplateShowFriends", 0)
                                pcall(SetCVar, "UnitNameFriendlyPlayerName", 1)
                            end
                        else
                            if SetCVar then
                                pcall(SetCVar, "UnitNameFriendlyPlayerName", 0)
                            end
                        end
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        if KT and KT.RefreshPage then KT:RefreshPage() end
                        UpdateToggle5()
                    end)

                    pf._updateToggle = function()
                        UpdateToggle4()
                        UpdateToggle5()
                    end

                    -- Close on click outside
                    local wasDown = false
                    pf:SetScript("OnHide", function(self)
                        self:SetScript("OnUpdate", nil)
                        if fpPopupOwner then fpPopupOwner:SetAlpha(0.4) end
                        fpPopupOwner = nil
                    end)
                    pf._clickOutside = function(self, dt)
                        local down = IsMouseButtonDown("LeftButton")
                        if down and not wasDown then
                            if not self:IsMouseOver() and not (fpPopupOwner and fpPopupOwner:IsMouseOver()) then
                                self:Hide()
                            end
                        end
                        wasDown = down
                    end

                    if KT.MenuPrincipal then
                        KT.MenuPrincipal:HookScript("OnHide", function()
                            if pf:IsShown() then pf:Hide() end
                        end)
                    end

                    fpPopup = pf
                end

                -- Toggle off if same icon clicked again
                if fpPopupOwner == anchorBtn and fpPopup:IsShown() then
                    fpPopup:Hide(); return
                end
                fpPopupOwner = anchorBtn
                if fpPopup._updateToggle then fpPopup._updateToggle() end

                fpPopup:ClearAllPoints()
                fpPopup:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 6)
                fpPopup:SetAlpha(0)
                fpPopup:Show()
                local elapsed = 0
                fpPopup:SetScript("OnUpdate", function(self, dt)
                    elapsed = elapsed + dt
                    local t = math.min(elapsed / 0.15, 1)
                    self:SetAlpha(t)
                    self:ClearAllPoints()
                    self:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 6 + (-8 * (1 - t)))
                    if t >= 1 then self:SetScript("OnUpdate", self._clickOutside) end
                end)
            end

            local rgn = friendlyRow._leftRegion
            local btn = CreateFrame("Button", nil, rgn)
            btn:SetSize(26, 26)
            if rgn._control and rgn._control.SetReservedRightSpace then
                rgn._control:SetReservedRightSpace(40)
            end
            btn:SetPoint("RIGHT", rgn, "RIGHT", -12, 0)
            btn:SetFrameLevel(rgn:GetFrameLevel() + 5)
            btn:SetAlpha(friendlyPlateOff() and 0.15 or 0.4)
            local tex = btn:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(); tex:SetTexture(COGS_ICON); ApplyNPAccentToIcon(tex)
            btn:SetScript("OnEnter", function(self)
                if friendlyPlateOff() then
                    KT_ShowWidgetTooltip(self, "Requires Name Only setting to be disabled")
                else
                    self:SetAlpha(0.7)
                end
            end)
            btn:SetScript("OnLeave", function(self)
                KT_HideWidgetTooltip()
                if fpPopupOwner ~= self then self:SetAlpha(friendlyPlateOff() and 0.15 or 0.4) end
            end)
            btn:SetScript("OnClick", function(self)
                if friendlyPlateOff() then return end
                ShowFriendlyPlayerPopup(self)
            end)
            KT_RegisterWidgetRefresh(function()
                if fpPopupOwner ~= btn then btn:SetAlpha(friendlyPlateOff() and 0.15 or 0.4) end
            end)
        end

        ---------------------------------------------------------------
        --  Name Only cog popup (Class Colored, Distance from Friend)
        ---------------------------------------------------------------
        do
            local noPopup, noPopupOwner
            local function ShowNameOnlyPopup(anchorBtn)
                if not noPopup then
                    local SolidTex         = KT.SolidTex
                    local MakeBorder       = KT.MakeBorder
                    local MakeFont         = KT.MakeFont
                    local BuildSliderCore  = KT.BuildSliderCore
                    local BORDER_COLOR     = KT.NP_BORDER_COLOR
                    local SL_INPUT_A       = KT.NP_SL_INPUT_A

                    local SIDE_PAD         = 14; local TOP_PAD = 14
                    local TITLE_H          = 11; local TITLE_GAP = 10; local GAP = 10
                    local TOGGLE_ROW_H     = 28; local ROW_H = 24
                    local POPUP_INPUT_A    = 0.55

                    local INPUT_W          = 34; local SLIDER_INPUT_GAP = 8; local LABEL_SLIDER_GAP = 12
                    local MIN_POPUP_W      = 180

                    local totalH           = TOP_PAD + TITLE_H + TITLE_GAP + GAP
                        + TOGGLE_ROW_H + GAP + ROW_H
                        + TOP_PAD

                    local pf               = CreateFrame("Frame", nil, UIParent)
                    pf:SetSize(260, totalH)
                    pf:SetFrameStrata("FULLSCREEN_DIALOG"); pf:SetFrameLevel(math.max(1200, (KT.MenuPrincipal and KT.MenuPrincipal:GetFrameLevel() or 0) + 80))
                    pf:EnableMouse(true); pf:Hide()

                    local bg = SolidTex(pf, "BACKGROUND", 0.06, 0.08, 0.10, 0.95)
                    bg:SetAllPoints()
                    MakeBorder(pf, BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.15)

                    local titleFS = MakeFont(pf, 11, "", 1, 1, 1)
                    titleFS:SetAlpha(0.7)
                    titleFS:SetPoint("TOP", pf, "TOP", 0, -TOP_PAD)
                    titleFS:SetText(LText("Name Only Settings"))

                    -- Row 1: Class Colored (toggle)
                    local r1Y = -(TOP_PAD + TITLE_H + TITLE_GAP + GAP)
                    local lbl1 = MakeFont(pf, 11, nil, 1, 1, 1); lbl1:SetAlpha(0.6)
                    lbl1:SetText(LText("Class Colored")); lbl1:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r1Y)

                    local TG_W, TG_H, KNOB_SZ, KNOB_PAD = 32, 16, 12, 2
                    local tgBtn = CreateFrame("Button", nil, pf)
                    tgBtn:SetSize(TG_W, TG_H)
                    tgBtn:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r1Y)

                    local tgBg = SolidTex(tgBtn, "BACKGROUND", 0.18, 0.18, 0.18, 0.85)
                    tgBg:SetAllPoints()
                    local tgKnob = tgBtn:CreateTexture(nil, "ARTWORK")
                    tgKnob:SetColorTexture(0.55, 0.55, 0.55, 1)
                    tgKnob:SetSize(KNOB_SZ, KNOB_SZ)

                    local function UpdateToggleCC()
                        local on = DBVal("classColorFriendly") ~= false
                        if on then
                            local g = KT.NP_GREEN
                            tgBg:SetColorTexture(g.r, g.g, g.b, 0.45)
                            tgKnob:SetColorTexture(1, 1, 1, 0.95)
                            tgKnob:ClearAllPoints(); tgKnob:SetPoint("RIGHT", tgBtn, "RIGHT", -KNOB_PAD, 0)
                        else
                            tgBg:SetColorTexture(0.18, 0.18, 0.18, 0.85)
                            tgKnob:SetColorTexture(0.55, 0.55, 0.55, 1)
                            tgKnob:ClearAllPoints(); tgKnob:SetPoint("LEFT", tgBtn, "LEFT", KNOB_PAD, 0)
                        end
                    end
                    UpdateToggleCC()
                    tgBtn:SetScript("OnClick", function()
                        local cur = DBVal("classColorFriendly") ~= false
                        DB().classColorFriendly = not cur
                        if SetCVar then
                            pcall(SetCVar, "ShowClassColorInFriendlyNameplate", (not cur) and 1 or 0)
                            pcall(SetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames", (not cur) and 1 or 0)
                        end
                        UpdateToggleCC()
                    end)
                    pf._updateToggle = UpdateToggleCC

                    -- Row 2: Distance from Friend (slider)
                    local r2Y = r1Y - TOGGLE_ROW_H - GAP

                    -- Measure label widths to compute layout BEFORE creating sliders
                    local tmpFS = pf:CreateFontString(nil, "OVERLAY")
                    tmpFS:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, GetNPOptOutline())
                    local labelTexts = { "Distance" }
                    local maxLblW = 0
                    for _, txt in ipairs(labelTexts) do
                        tmpFS:SetText(txt)
                        local w = tmpFS:GetStringWidth()
                        if w > maxLblW then maxLblW = w end
                    end
                    tmpFS:Hide()
                    if maxLblW < 10 then maxLblW = 55 end

                    local SLIDER_LEFT = SIDE_PAD + maxLblW + LABEL_SLIDER_GAP
                    local SLIDER_W = math.max(80, 260 - SLIDER_LEFT - SLIDER_INPUT_GAP - INPUT_W - SIDE_PAD)
                    local POPUP_W = math.max(MIN_POPUP_W, SLIDER_LEFT + SLIDER_W + SLIDER_INPUT_GAP + INPUT_W + SIDE_PAD)
                    pf:SetWidth(POPUP_W)

                    local lbl2 = MakeFont(pf, 11, nil, 1, 1, 1); lbl2:SetAlpha(0.6)
                    lbl2:SetText(LText("Distance")); lbl2:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r2Y)
                    local t2, v2 = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, ROW_H, 11, POPUP_INPUT_A,
                        -50, 50, 1,
                        function() return DBVal("friendlyNameOnlyYOffset") or defaults.friendlyNameOnlyYOffset end,
                        function(v)
                            DB().friendlyNameOnlyYOffset = v; if ns.RefreshFriendlyNameOnlyOffset then ns
                                    .RefreshFriendlyNameOnlyOffset() end
                        end, true)
                    t2:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, r2Y - 2)
                    v2:ClearAllPoints(); v2:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r2Y)

                    -- Close on click outside
                    local wasDown = false
                    pf:SetScript("OnHide", function(self)
                        self:SetScript("OnUpdate", nil)
                        if noPopupOwner then noPopupOwner:SetAlpha(0.4) end
                        noPopupOwner = nil
                    end)
                    pf._clickOutside = function(self, dt)
                        local down = IsMouseButtonDown("LeftButton")
                        if down and not wasDown then
                            if not self:IsMouseOver() and not (noPopupOwner and noPopupOwner:IsMouseOver()) then
                                self:Hide()
                            end
                        end
                        wasDown = down
                    end

                    if KT.MenuPrincipal then
                        KT.MenuPrincipal:HookScript("OnHide", function()
                            if pf:IsShown() then pf:Hide() end
                        end)
                    end

                    noPopup = pf
                end

                -- Toggle off if same icon clicked again
                if noPopupOwner == anchorBtn and noPopup:IsShown() then
                    noPopup:Hide(); return
                end
                noPopupOwner = anchorBtn
                if noPopup._updateToggle then noPopup._updateToggle() end

                noPopup:ClearAllPoints()
                noPopup:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 6)
                noPopup:SetAlpha(0)
                noPopup:Show()
                local elapsed = 0
                noPopup:SetScript("OnUpdate", function(self, dt)
                    elapsed = elapsed + dt
                    local t = math.min(elapsed / 0.15, 1)
                    self:SetAlpha(t)
                    self:ClearAllPoints()
                    self:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 6 + (-8 * (1 - t)))
                    if t >= 1 then self:SetScript("OnUpdate", self._clickOutside) end
                end)
            end

            local rgn = friendlyRow._rightRegion
            local btn = CreateFrame("Button", nil, rgn)
            btn:SetSize(26, 26)
            if rgn._control and rgn._control.SetReservedRightSpace then
                rgn._control:SetReservedRightSpace(40)
            end
            btn:SetPoint("RIGHT", rgn, "RIGHT", -12, 0)
            btn:SetFrameLevel(rgn:GetFrameLevel() + 5)
            btn:SetAlpha(nameOnlyOff() and 0.15 or 0.4)
            local tex = btn:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(); tex:SetTexture(COGS_ICON); ApplyNPAccentToIcon(tex)
            btn:SetScript("OnEnter", function(self)
                if nameOnlyOff() then
                    KT_ShowWidgetTooltip(self, "Requires Name Only mode")
                else
                    self:SetAlpha(0.7)
                end
            end)
            btn:SetScript("OnLeave", function(self)
                KT_HideWidgetTooltip()
                if noPopupOwner ~= self then self:SetAlpha(nameOnlyOff() and 0.15 or 0.4) end
            end)
            btn:SetScript("OnClick", function(self)
                if nameOnlyOff() then return end
                ShowNameOnlyPopup(self)
            end)
            KT_RegisterWidgetRefresh(function()
                if noPopupOwner ~= btn then btn:SetAlpha(nameOnlyOff() and 0.15 or 0.4) end
            end)
        end

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Show Friendly NPC Nameplates"),
                getValue = function() return DBVal("showFriendlyNPCs") == true end,
                setValue = function(v)
                    DB().showFriendlyNPCs = v
                    if SetCVar then
                        pcall(SetCVar, "nameplateShowFriendlyNPCs", v and 1 or 0)
                        pcall(SetCVar, "nameplateShowFriendlyNpcs", v and 1 or 0)
                    end
                    if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                end
            },
            {
                type = "toggle",
                text = LText("Show Enemy Pet Nameplates"),
                getValue = function() return DBVal("showEnemyPets") == true end,
                setValue = function(v)
                    DB().showEnemyPets = v
                    if SetCVar then pcall(SetCVar, "nameplateShowEnemyPets", v and 1 or 0) end
                end,
                tooltip = "Toggle visibility of enemy pet nameplates."
            }); y = y - h

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  TEXT STYLE
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "TEXT STYLE", y); y = y - h

        local function GetNPFontValues()
            local values = {}
            if LSM then
                for _, name in ipairs(LSM:List("font")) do
                    if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
                        values[name] = name
                    end
                end
            end
            if not next(values) then
                local def = (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
                values[def] = def
            end
            values._menuOpts = {
                kind = "font",
                sharedMedia = true,
                resolve = function(name)
                    return LSM and LSM:Fetch("font", name, true)
                end,
            }
            return values
        end

        local function GetCurrentNPFontValue()
            local current = DBVal("font") or defaults.font
            if KT and KT.IsLocalizedDefaultFont and KT:IsLocalizedDefaultFont(current) then
                current = (KT.GetDefaultFontName and KT:GetDefaultFontName()) or current
            end
            if LSM and type(current) == "string" then
                for _, name in ipairs(LSM:List("font")) do
                    local fetched = LSM:Fetch("font", name, true)
                    if current == name or fetched == current then
                        return name
                    end
                end
            end
            if type(current) == "string" then
                local normalized = current:gsub("/", "\\"):lower()
                if normalized:find("interface\\addons\\kullthranui\\media\\fonts\\", 1, true) then
                    return (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
                end
            end
            return current
        end

        local function RefreshFriendlyTextStyle()
            RefreshAllFonts()
            if ns.RefreshFriendlyFontOverride then ns.RefreshFriendlyFontOverride() end
            if ns.RefreshFriendlyTextStyle then ns.RefreshFriendlyTextStyle() end
            if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
            UpdatePreview()
        end

        _, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Global Font"),
                values = GetNPFontValues,
                getValue = function() return GetCurrentNPFontValue() end,
                setValue = function(v)
                    DB().font = (LSM and LSM:Fetch("font", v, true)) or v
                    RefreshFriendlyTextStyle()
                end,
            },
            {
                type = "dropdown",
                text = LText("Outline"),
                values = {
                    [""] = "None",
                    ["OUTLINE"] = "Thin",
                    ["THICKOUTLINE"] = "Thick",
                    ["MONOCHROMEOUTLINE"] = "Monochrome",
                },
                order = { "", "OUTLINE", "THICKOUTLINE", "MONOCHROMEOUTLINE" },
                getValue = function() return DBVal("fontOutline") or defaults.fontOutline end,
                setValue = function(v)
                    DB().fontOutline = v
                    RefreshFriendlyTextStyle()
                end,
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Text Shadow"),
                getValue = function()
                    local db = DB()
                    if db and db.fontShadow ~= nil then return db.fontShadow end
                    return defaults.fontShadow
                end,
                setValue = function(v)
                    DB().fontShadow = v
                    RefreshFriendlyTextStyle()
                end,
            },
            {
                type = "toggle",
                text = LText("Friendly Class Colored Names"),
                getValue = function() return DBVal("classColorFriendly") ~= false end,
                setValue = function(v)
                    DB().classColorFriendly = v
                    if SetCVar then
                        pcall(SetCVar, "ShowClassColorInFriendlyNameplate", v and 1 or 0)
                        pcall(SetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames", v and 1 or 0)
                    end
                    RefreshFriendlyTextStyle()
                end,
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Friendly Player Alignment"),
                values = {
                    ["center"] = "Centered",
                    ["left"] = "From Left",
                    ["right"] = "From Right",
                },
                order = { "center", "left", "right" },
                getValue = function()
                    return DBVal("friendlyPlayerNameAlignment") or defaults.friendlyPlayerNameAlignment
                end,
                setValue = function(v)
                    DB().friendlyPlayerNameAlignment = v
                    RefreshFriendlyTextStyle()
                end,
            },
            {
                type = "dropdown",
                text = LText("Friendly NPC Alignment"),
                values = {
                    ["center"] = "Centered",
                    ["left"] = "From Left",
                    ["right"] = "From Right",
                },
                order = { "center", "left", "right" },
                getValue = function()
                    return DBVal("friendlyNPCNameAlignment") or defaults.friendlyNPCNameAlignment
                end,
                setValue = function(v)
                    DB().friendlyNPCNameAlignment = v
                    RefreshFriendlyTextStyle()
                end,
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Friendly Player Name Size"),
                min = 8,
                max = 22,
                step = 1,
                getValue = function() return DBVal("friendlyPlayerNameTextSize") or defaults.friendlyPlayerNameTextSize end,
                setValue = function(v)
                    DB().friendlyPlayerNameTextSize = v
                    RefreshFriendlyTextStyle()
                end,
            },
            nil); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Friendly Guild Size"),
                min = 8,
                max = 20,
                step = 1,
                getValue = function() return DBVal("friendlyGuildTextSize") or defaults.friendlyGuildTextSize end,
                setValue = function(v)
                    DB().friendlyGuildTextSize = v
                    RefreshFriendlyTextStyle()
                end,
            },
            {
                type = "slider",
                text = LText("Friendly Health Text Size"),
                min = 8,
                max = 20,
                step = 1,
                getValue = function() return DBVal("friendlyHealthTextSize") or defaults.friendlyHealthTextSize end,
                setValue = function(v)
                    DB().friendlyHealthTextSize = v
                    RefreshFriendlyTextStyle()
                end,
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "colorpicker",
                text = LText("Friendly Player Name Color"),
                getValue = function()
                    local c = (DB() and DB().friendlyPlayerNameColor) or defaults.friendlyPlayerNameColor
                    c = (c and c.r and c.g and c.b) and c or { r = 1, g = 1, b = 1 }
                    return c.r, c.g, c.b
                end,
                setValue = function(r, g, b)
                    DB().friendlyPlayerNameColor = { r = r, g = g, b = b }
                    RefreshFriendlyTextStyle()
                end,
            },
            {
                type = "colorpicker",
                text = LText("Friendly Guild Color"),
                getValue = function()
                    local c = (DB() and DB().friendlyGuildColor) or defaults.friendlyGuildColor
                    c = (c and c.r and c.g and c.b) and c or { r = 1, g = 1, b = 1 }
                    return c.r, c.g, c.b
                end,
                setValue = function(r, g, b)
                    DB().friendlyGuildColor = { r = r, g = g, b = b }
                    RefreshFriendlyTextStyle()
                end,
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Friendly NPC Name Size"),
                min = 8,
                max = 24,
                step = 1,
                getValue = function() return DBVal("friendlyNPCNameTextSize") or defaults.friendlyNPCNameTextSize end,
                setValue = function(v)
                    DB().friendlyNPCNameTextSize = v
                    RefreshFriendlyTextStyle()
                end,
            },
            {
                type = "colorpicker",
                text = LText("Friendly Health Text Color"),
                getValue = function()
                    local c = (DB() and DB().friendlyHealthTextColor) or defaults.friendlyHealthTextColor
                    c = (c and c.r and c.g and c.b) and c or { r = 1, g = 1, b = 1 }
                    return c.r, c.g, c.b
                end,
                setValue = function(r, g, b)
                    DB().friendlyHealthTextColor = { r = r, g = g, b = b }
                    RefreshFriendlyTextStyle()
                end,
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "colorpicker",
                text = LText("Friendly NPC Name Color"),
                getValue = function()
                    local c = (DB() and DB().friendlyNPCNameColor) or defaults.friendlyNPCNameColor
                    c = (c and c.r and c.g and c.b) and c or { r = 0, g = 1, b = 0 }
                    return c.r, c.g, c.b
                end,
                setValue = function(r, g, b)
                    DB().friendlyNPCNameColor = { r = r, g = g, b = b }
                    RefreshFriendlyTextStyle()
                end,
            },
            nil); y = y - h

        _, h = W:Label(parent,
            "Enemy text styling is configured in Display via Core Text and General Text, and now also uses the global font, outline and shadow options above.",
            y, 11); y = y - h

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  ENEMY NAMEPLATE SPACING
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_ENEMY_NP, y); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enable Stacking Nameplates"),
                getValue = function() return DBVal("stackingEnabled") ~= false end,
                setValue = function(v)
                    DB().stackingEnabled = v
                    ns.RefreshStackingMotion()
                end,
                tooltip = "When enabled, nameplates stack vertically instead of overlapping."
            },
            {
                type = "slider",
                text = LText("Stacked Nameplate Spacing"),
                trackWidth = 130,
                min = 50,
                max = 200,
                step = 5,
                getValue = function() return DBVal("stackSpacingScale") or defaults.stackSpacingScale end,
                setValue = function(v)
                    DB().stackSpacingScale = v
                    ns.RefreshStackingBounds()
                end,
                tooltip =
                "Adjusts the vertical spacing between stacked nameplates. 100% = default, lower = tighter, higher = more spread."
            }); y = y - h

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  EXTRAS
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_MISC, y); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Show All Your Player Debuffs"),
                getValue = function() return DBVal("showAllDebuffs") == true end,
                setValue = function(v)
                    DB().showAllDebuffs = v
                    RefreshAllAuras()
                end,
                tooltip =
                "This will display ALL of your debuffs on enemy nameplates, rather than only the important ones."
            },
            {
                type = "slider",
                text = LText("Scale Nameplate On Cast"),
                trackWidth = 110,
                min = 50,
                max = 200,
                step = 5,
                getValue = function() return DBVal("castScale") or defaults.castScale end,
                setValue = function(v)
                    DB().castScale = v
                end,
                tooltip = "Scales enemy nameplates while they are casting. 100% = no change."
            }); y = y - h

        -- Helper: pandemic glow is off when style is "None"
        local function pandemicOff()
            return DBVal("pandemicGlow") ~= true
        end

        -- Pandemic glow style dropdown + inline color swatch + cog
        -- "None" disables pandemic glow entirely (replaces the old toggle)
        local glowStyleValues = { [0] = "None" }
        local glowStyleOrder = { 0 }
        local styles = ns.PANDEMIC_GLOW_STYLES
        for i, entry in ipairs(styles) do
            glowStyleValues[i] = entry.name
            glowStyleOrder[#glowStyleOrder + 1] = i
        end

        local glowStyleRow
        glowStyleRow, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Pandemic Glow Style"),
                values = glowStyleValues,
                getValue = function()
                    if pandemicOff() then return 0 end
                    local raw = ns.GetPandemicGlowStyle and ns.GetPandemicGlowStyle() or
                    (DBVal("pandemicGlowStyle") or 1)
                    if type(raw) ~= "number" then return 1 end
                    if raw < 1 or raw > #ns.PANDEMIC_GLOW_STYLES then return 1 end
                    return raw
                end,
                setValue = function(v)
                    if v == 0 then
                        DB().pandemicGlow = false
                    else
                        DB().pandemicGlow = true
                        DB().pandemicGlowStyle = v
                    end
                    RefreshAllAuras()
                    RefreshPandemicPreview()
                    C_Timer.After(0, function() KT:RefreshPage() end)
                end,
                order = glowStyleOrder
            },
            { type = "label", text = LText("Pandemic Glow Preview") }); y = y - h

        local expiryGlowValues = {
            [1] = "1 sec",
            [2] = "2 sec",
            [3] = "3 sec",
            [4] = "4 sec",
            [5] = "5 sec",
        }
        local function expiryGlowOff()
            return DBVal("debuffExpiryGlow") ~= true
        end

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Debuff Expiry Glow"),
                tooltip = "Pulse debuff icons when they are about to expire on enemy nameplates.",
                getValue = function() return DBVal("debuffExpiryGlow") == true end,
                setValue = function(v)
                    DB().debuffExpiryGlow = v
                    RefreshAllAuras()
                    C_Timer.After(0, function() KT:RefreshPage(true) end)
                end
            },
            {
                type = "dropdown",
                text = LText("Expiry Threshold"),
                values = expiryGlowValues,
                order = { 1, 2, 3, 4, 5 },
                getValue = function()
                    return tonumber(DBVal("debuffExpiryGlowThreshold")) or defaults.debuffExpiryGlowThreshold or 3
                end,
                setValue = function(v)
                    DB().debuffExpiryGlowThreshold = v
                    RefreshAllAuras()
                end,
                disabled = expiryGlowOff,
                disabledTooltip = "Debuff Expiry Glow"
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Use Debuff Type Color"),
                getValue = function()
                    local v = DBVal("debuffExpiryGlowUseTypeColor")
                    if v == nil then return defaults.debuffExpiryGlowUseTypeColor == true end
                    return v == true
                end,
                setValue = function(v)
                    DB().debuffExpiryGlowUseTypeColor = v
                    RefreshAllAuras()
                    KT:RefreshPage()
                end,
                tooltip = "Uses the debuff type color when available, such as Magic, Curse, Disease or Poison."
            },
            nil); y = y - h

        do
            local glowColorGet = function()
                local c = DB().debuffExpiryGlowColor or defaults.debuffExpiryGlowColor
                return c.r, c.g, c.b
            end
            local glowColorSet = function(r, g, b)
                DB().debuffExpiryGlowColor = { r = r, g = g, b = b }
                RefreshAllAuras()
            end
            local row
            row, h = W:Label(parent, "Custom Expiry Glow Color", y, 11, { r = 0.75, g = 0.75, b = 0.75 }); y = y - h
            local swatch, updateSwatch = KT_BuildColorSwatch(row, row:GetFrameLevel() + 5, glowColorGet,
                glowColorSet, nil, 20)
            PP.Point(swatch, "RIGHT", row, "RIGHT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                updateSwatch()
                local off = expiryGlowOff() or (DBVal("debuffExpiryGlowUseTypeColor") == true)
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
            end)
        end

        -- Glow Preview icon: built into the right half of the glow style row
        do
            local SIDE_PAD = 20

            local iconSize = 36
            local iconFrame = CreateFrame("Frame", nil, glowStyleRow)
            PP.Size(iconFrame, iconSize, iconSize)
            PP.Point(iconFrame, "RIGHT", glowStyleRow, "RIGHT", -SIDE_PAD, 0)

            local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints()
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconTex:SetTexture(_pandemicPreviewIcon or 136197)
            iconFrame._iconTex = iconTex

            -- 1px black border
            local function AddIconBorder(p)
                local onePx = PP.Scale(1)
                local function mkB(anchor1, rel, anchor2, isH)
                    local t = p:CreateTexture(nil, "OVERLAY", nil, 7)
                    t:SetColorTexture(0, 0, 0, 1)
                    if t.SetSnapToPixelGrid then
                        t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0)
                    end
                    PP.Point(t, anchor1, p, anchor1, 0, 0)
                    PP.Point(t, anchor2, p, anchor2, 0, 0)
                    if isH then t:SetHeight(onePx) else t:SetWidth(onePx) end
                    return t
                end
                local tEdge = mkB("TOPLEFT", p, "TOPRIGHT", true)
                local bEdge = mkB("BOTTOMLEFT", p, "BOTTOMRIGHT", true)
                local lEdge = p:CreateTexture(nil, "OVERLAY", nil, 7)
                lEdge:SetColorTexture(0, 0, 0, 1)
                if lEdge.SetSnapToPixelGrid then
                    lEdge:SetSnapToPixelGrid(false); lEdge:SetTexelSnappingBias(0)
                end
                PP.Point(lEdge, "TOPLEFT", tEdge, "BOTTOMLEFT", 0, 0)
                PP.Point(lEdge, "BOTTOMLEFT", bEdge, "TOPLEFT", 0, 0)
                lEdge:SetWidth(onePx)
                local rEdge = p:CreateTexture(nil, "OVERLAY", nil, 7)
                rEdge:SetColorTexture(0, 0, 0, 1)
                if rEdge.SetSnapToPixelGrid then
                    rEdge:SetSnapToPixelGrid(false); rEdge:SetTexelSnappingBias(0)
                end
                PP.Point(rEdge, "TOPRIGHT", tEdge, "BOTTOMRIGHT", 0, 0)
                PP.Point(rEdge, "BOTTOMRIGHT", bEdge, "TOPRIGHT", 0, 0)
                rEdge:SetWidth(onePx)
            end
            AddIconBorder(iconFrame)

            _pandemicPreviewFrame = iconFrame
            RefreshPandemicPreview()

            -- Gray out preview + label when pandemic glow is off (style = None)
            local previewLabel = ({ glowStyleRow._rightRegion:GetRegions() })[1]
            local function UpdatePreviewGrayOut()
                local off = pandemicOff()
                iconFrame:SetAlpha(off and 0.3 or 1)
                if previewLabel and previewLabel.SetAlpha then
                    previewLabel:SetAlpha(off and 0.3 or 1)
                end
            end
            KT_RegisterWidgetRefresh(UpdatePreviewGrayOut)
            UpdatePreviewGrayOut()
        end

        -- Inline color swatch next to the Glow Style dropdown
        do
            local glowColorGet = function()
                local c = DB().pandemicGlowColor or defaults.pandemicGlowColor
                return c.r, c.g, c.b
            end
            local glowColorSet = function(r, g, b)
                DB().pandemicGlowColor = { r = r, g = g, b = b }
                RefreshAllAuras()
                RefreshPandemicPreview()
            end
            local leftRgn = glowStyleRow._leftRegion
            local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5, glowColorGet,
                glowColorSet, nil, 20)
            PP.Point(swatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
            leftRgn._lastInline = swatch
            -- Gray out swatch when pandemic glow is off
            KT_RegisterWidgetRefresh(function()
                local off = pandemicOff()
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            swatch:SetAlpha(pandemicOff() and 0.15 or 1)
            swatch:EnableMouse(not pandemicOff())
        end

        -- Pixel Glow sub-options: only enabled when style is "Pixel Glow" (index 1)
        local function antsOff()
            if pandemicOff() then return true end
            local raw = DBVal("pandemicGlowStyle")
            if type(raw) ~= "number" then return true end
            return raw ~= 1
        end

        -- Cog popup for Pixel Glow settings (Lines, Thickness, Speed)
        do
            local pgPopup, pgPopupOwner
            local function ShowPixelGlowPopup(anchorBtn)
                if not pgPopup then
                    local SolidTex         = KT.SolidTex
                    local MakeBorder       = KT.MakeBorder
                    local MakeFont         = KT.MakeFont
                    local BuildSliderCore  = KT.BuildSliderCore
                    local BORDER_COLOR     = KT.NP_BORDER_COLOR
                    local SL_INPUT_A       = KT.NP_SL_INPUT_A

                    local SIDE_PAD         = 14; local TOP_PAD = 14
                    local TITLE_H          = 11; local TITLE_GAP = 10; local GAP = 10
                    local ROW_H            = 24
                    local POPUP_INPUT_A    = 0.55

                    local INPUT_W          = 34; local SLIDER_INPUT_GAP = 8; local LABEL_SLIDER_GAP = 12
                    local MIN_POPUP_W      = 180

                    local totalH           = TOP_PAD + TITLE_H + TITLE_GAP + GAP
                        + ROW_H + GAP + ROW_H + GAP + ROW_H
                        + TOP_PAD

                    local pf               = CreateFrame("Frame", nil, UIParent)
                    pf:SetSize(260, totalH)
                    pf:SetFrameStrata("FULLSCREEN_DIALOG"); pf:SetFrameLevel(math.max(1200, (KT.MenuPrincipal and KT.MenuPrincipal:GetFrameLevel() or 0) + 80))
                    pf:EnableMouse(true); pf:Hide()

                    local bg = SolidTex(pf, "BACKGROUND", 0.06, 0.08, 0.10, 0.95)
                    bg:SetAllPoints()
                    MakeBorder(pf, BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.15)

                    local titleFS = MakeFont(pf, 11, "", 1, 1, 1)
                    titleFS:SetAlpha(0.7)
                    titleFS:SetPoint("TOP", pf, "TOP", 0, -TOP_PAD)
                    titleFS:SetText(LText("Pixel Glow Settings"))

                    -- Measure label widths to compute layout BEFORE creating sliders
                    local tmpFS = pf:CreateFontString(nil, "OVERLAY")
                    tmpFS:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, GetNPOptOutline())
                    local labelTexts = { "Lines", "Thickness", "Speed" }
                    local maxLblW = 0
                    for _, txt in ipairs(labelTexts) do
                        tmpFS:SetText(txt)
                        local w = tmpFS:GetStringWidth()
                        if w > maxLblW then maxLblW = w end
                    end
                    tmpFS:Hide()
                    if maxLblW < 10 then maxLblW = 60 end

                    local SLIDER_LEFT = SIDE_PAD + maxLblW + LABEL_SLIDER_GAP
                    local SLIDER_W = math.max(80, 260 - SLIDER_LEFT - SLIDER_INPUT_GAP - INPUT_W - SIDE_PAD)
                    local POPUP_W = math.max(MIN_POPUP_W, SLIDER_LEFT + SLIDER_W + SLIDER_INPUT_GAP + INPUT_W + SIDE_PAD)
                    pf:SetWidth(POPUP_W)

                    -- Row 1: Lines
                    local r1Y = -(TOP_PAD + TITLE_H + TITLE_GAP + GAP)
                    local lbl1 = MakeFont(pf, 11, nil, 1, 1, 1); lbl1:SetAlpha(0.6)
                    lbl1:SetText(LText("Lines")); lbl1:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r1Y)
                    local t1, v1 = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, ROW_H, 11, POPUP_INPUT_A,
                        2, 16, 1,
                        function() return DBVal("pandemicGlowLines") or defaults.pandemicGlowLines end,
                        function(v)
                            DB().pandemicGlowLines = v; RefreshAllAuras(); RefreshPandemicPreview()
                        end, true)
                    t1:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, r1Y - 2)
                    v1:ClearAllPoints(); v1:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r1Y)

                    -- Row 2: Thickness
                    local r2Y = r1Y - ROW_H - GAP
                    local lbl2 = MakeFont(pf, 11, nil, 1, 1, 1); lbl2:SetAlpha(0.6)
                    lbl2:SetText(LText("Thickness")); lbl2:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r2Y)
                    local t2, v2 = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, ROW_H, 11, POPUP_INPUT_A,
                        1, 4, 1,
                        function() return DBVal("pandemicGlowThickness") or defaults.pandemicGlowThickness end,
                        function(v)
                            DB().pandemicGlowThickness = v; RefreshAllAuras(); RefreshPandemicPreview()
                        end, true)
                    t2:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, r2Y - 2)
                    v2:ClearAllPoints(); v2:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r2Y)

                    -- Row 3: Speed (inverted: display = 9 - stored)
                    local r3Y = r2Y - ROW_H - GAP
                    local lbl3 = MakeFont(pf, 11, nil, 1, 1, 1); lbl3:SetAlpha(0.6)
                    lbl3:SetText(LText("Speed")); lbl3:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, r3Y)
                    local t3, v3 = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, ROW_H, 11, POPUP_INPUT_A,
                        1, 8, 1,
                        function()
                            local period = DBVal("pandemicGlowSpeed") or defaults.pandemicGlowSpeed
                            return 9 - period
                        end,
                        function(v)
                            DB().pandemicGlowSpeed = 9 - v; RefreshAllAuras(); RefreshPandemicPreview()
                        end, true)
                    t3:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, r3Y - 2)
                    v3:ClearAllPoints(); v3:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, r3Y)

                    -- Close on click outside
                    local wasDown = false
                    pf:SetScript("OnHide", function(self)
                        self:SetScript("OnUpdate", nil)
                        if pgPopupOwner then pgPopupOwner:SetAlpha(0.4) end
                        pgPopupOwner = nil
                    end)
                    pf._clickOutside = function(self, dt)
                        local down = IsMouseButtonDown("LeftButton")
                        if down and not wasDown then
                            if not self:IsMouseOver() and not (pgPopupOwner and pgPopupOwner:IsMouseOver()) then
                                self:Hide()
                            end
                        end
                        wasDown = down
                    end

                    if KT.MenuPrincipal then
                        KT.MenuPrincipal:HookScript("OnHide", function()
                            if pf:IsShown() then pf:Hide() end
                        end)
                    end

                    pgPopup = pf
                end

                if pgPopupOwner == anchorBtn and pgPopup:IsShown() then
                    pgPopup:Hide(); return
                end
                pgPopupOwner = anchorBtn

                pgPopup:ClearAllPoints()
                pgPopup:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 6)
                pgPopup:SetAlpha(0)
                pgPopup:Show()
                local elapsed = 0
                pgPopup:SetScript("OnUpdate", function(self, dt)
                    elapsed = elapsed + dt
                    local t = math.min(elapsed / 0.15, 1)
                    self:SetAlpha(t)
                    self:ClearAllPoints()
                    self:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 6 + (-8 * (1 - t)))
                    if t >= 1 then self:SetScript("OnUpdate", self._clickOutside) end
                end)
            end

            local leftRgn2 = glowStyleRow._leftRegion
            local btn = CreateFrame("Button", nil, leftRgn2)
            btn:SetSize(26, 26)
            btn:SetPoint("RIGHT", leftRgn2._lastInline or leftRgn2._control, "LEFT", -9, 0)
            btn:SetFrameLevel(leftRgn2:GetFrameLevel() + 5)
            btn:SetAlpha(0.4)
            local tex = btn:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints(); tex:SetTexture(COGS_ICON); ApplyNPAccentToIcon(tex)
            btn:SetScript("OnEnter", function(self)
                if antsOff() then
                    KT_ShowWidgetTooltip(self, "This option requires Pixel Glow to be the selected glow type")
                else
                    self:SetAlpha(0.7)
                end
            end)
            btn:SetScript("OnLeave", function(self)
                KT_HideWidgetTooltip()
                if pgPopupOwner ~= btn then self:SetAlpha(antsOff() and 0.15 or 0.4) end
            end)
            btn:SetScript("OnClick", function(self)
                if antsOff() then return end
                ShowPixelGlowPopup(self)
            end)
            KT_RegisterWidgetRefresh(function()
                if pgPopupOwner ~= btn then btn:SetAlpha(antsOff() and 0.15 or 0.4) end
            end)
        end

        local function dispelGlowOff()
            return DBVal("dispelGlow") ~= true
        end

        local dispelGlowValues = { [0] = "None" }
        local dispelGlowOrder = { 0 }
        for i, entry in ipairs(ns.PANDEMIC_GLOW_STYLES or {}) do
            dispelGlowValues[i] = entry.name
            dispelGlowOrder[#dispelGlowOrder + 1] = i
        end

        local dispelGlowRow
        dispelGlowRow, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Dispel Glow Style"),
                values = dispelGlowValues,
                getValue = function()
                    if dispelGlowOff() then return 0 end
                    local raw = ns.GetDispelGlowStyle and ns.GetDispelGlowStyle() or (DBVal("dispelGlowStyle") or 2)
                    if type(raw) ~= "number" then return 2 end
                    return raw
                end,
                setValue = function(v)
                    if v == 0 then
                        DB().dispelGlow = false
                    else
                        DB().dispelGlow = true
                        DB().dispelGlowStyle = v
                    end
                    RefreshAllAuras()
                    C_Timer.After(0, function() KT:RefreshPage() end)
                end,
                order = dispelGlowOrder,
                tooltip = "Highlights enemy buffs that your class can offensively dispel or soothe."
            },
            {
                type = "toggle",
                text = LText("Use Dispel Type Color"),
                getValue = function() return DBVal("dispelGlowUseTypeColor") == true end,
                setValue = function(v)
                    DB().dispelGlowUseTypeColor = v
                    RefreshAllAuras()
                    KT:RefreshPage()
                end,
                disabled = function() return dispelGlowOff() end,
                tooltip = "Uses the native Magic/Enrage color instead of the custom color."
            }); y = y - h

        do
            local glowColorGet = function()
                local c = DB().dispelGlowColor or defaults.dispelGlowColor
                return c.r, c.g, c.b
            end
            local glowColorSet = function(r, g, b)
                DB().dispelGlowColor = { r = r, g = g, b = b }
                RefreshAllAuras()
            end
            local leftRgn = dispelGlowRow._leftRegion
            local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5, glowColorGet,
                glowColorSet, nil, 20)
            PP.Point(swatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                local off = dispelGlowOff() or (DBVal("dispelGlowUseTypeColor") == true)
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            swatch:SetAlpha((dispelGlowOff() or DBVal("dispelGlowUseTypeColor") == true) and 0.15 or 1)
            swatch:EnableMouse(not (dispelGlowOff() or DBVal("dispelGlowUseTypeColor") == true))
        end

        local function markersOff()
            local cfg = MarkerCfg()
            return not (cfg and cfg.enabled == true)
        end

        row, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enable Custom Health Markers"),
                getValue = function()
                    local cfg = MarkerCfg()
                    return cfg and cfg.enabled == true
                end,
                setValue = function(v)
                    local cfg = MarkerCfg()
                    if cfg then
                        cfg.enabled = v
                        RebuildMarkerValues(cfg)
                    end
                    RefreshAllPlates()
                    UpdatePreview()
                    KT:RefreshPage()
                end,
                tooltip = "Shows up to 3 vertical markers on the health bar at configured health percentages."
            },
            {
                type = "toggle",
                text = LText("Show on All Nameplates"),
                getValue = function()
                    local st = MarkerState()
                    return st and st.showOn == "all"
                end,
                setValue = function(v)
                    local st = MarkerState()
                    if st then st.showOn = v and "all" or "target" end
                    RefreshAllPlates()
                    UpdatePreview()
                end,
                tooltip = "When disabled, markers only display on your current target."
            }); y = y - h

        row, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Per-Spec Marker Profile"),
                getValue = function()
                    local st = MarkerState()
                    return st and (st.mode or "spec") == "spec"
                end,
                setValue = function(v)
                    local st = MarkerState()
                    if st then st.mode = v and "spec" or "character" end
                    RefreshAllPlates()
                    UpdatePreview()
                    KT:RefreshPage()
                end,
                tooltip = "When enabled, markers can be configured separately per specialization."
            },
            {
                type = "slider",
                text = LText("Marker Width"),
                min = 1,
                max = 6,
                step = 1,
                disabled = markersOff,
                disabledTooltip = "Enable Custom Health Markers",
                getValue = function()
                    local cfg = MarkerCfg()
                    return (cfg and cfg.width) or 2
                end,
                setValue = function(v)
                    local cfg = MarkerCfg()
                    if cfg then
                        cfg.width = v
                        RebuildMarkerValues(cfg)
                    end
                    RefreshAllPlates()
                    UpdatePreview()
                end
            }); y = y - h

        row, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Marker 1"),
                min = 0,
                max = 100,
                step = 1,
                disabled = markersOff,
                disabledTooltip = "Enable Custom Health Markers",
                getValue = function() return GetMarkerSlotValue(MarkerCfg(), 1) end,
                setValue = function(v)
                    SetMarkerSlotValue(MarkerCfg(), 1, v)
                    RefreshAllPlates()
                    UpdatePreview()
                end,
                tooltip = "Health percent threshold for marker #1. Set to 0 to clear."
            },
            {
                type = "slider",
                text = LText("Marker 2"),
                min = 0,
                max = 100,
                step = 1,
                disabled = markersOff,
                disabledTooltip = "Enable Custom Health Markers",
                getValue = function() return GetMarkerSlotValue(MarkerCfg(), 2) end,
                setValue = function(v)
                    SetMarkerSlotValue(MarkerCfg(), 2, v)
                    RefreshAllPlates()
                    UpdatePreview()
                end,
                tooltip = "Health percent threshold for marker #2. Set to 0 to clear."
            }); y = y - h

        row, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Marker 3"),
                min = 0,
                max = 100,
                step = 1,
                disabled = markersOff,
                disabledTooltip = "Enable Custom Health Markers",
                getValue = function() return GetMarkerSlotValue(MarkerCfg(), 3) end,
                setValue = function(v)
                    SetMarkerSlotValue(MarkerCfg(), 3, v)
                    RefreshAllPlates()
                    UpdatePreview()
                end,
                tooltip = "Health percent threshold for marker #3. Set to 0 to clear."
            },
            { type = "label", text = LText("Markers use % health (0 = off).") }); y = y - h

        -- Inline color swatch for marker color
        do
            local markerColorGet = function()
                local cfg = MarkerCfg() or {}
                return cfg.colorR or 1, cfg.colorG or 1, cfg.colorB or 1
            end
            local markerColorSet = function(r, g, b)
                local cfg = MarkerCfg()
                if not cfg then return end
                cfg.colorR, cfg.colorG, cfg.colorB = r, g, b
                RebuildMarkerValues(cfg)
                RefreshAllPlates()
                UpdatePreview()
            end
            local leftRgn = row._leftRegion
            local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5, markerColorGet,
                markerColorSet, nil, 20)
            PP.Point(swatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                local off = markersOff()
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            swatch:SetAlpha(markersOff() and 0.15 or 1)
            swatch:EnableMouse(not markersOff())
        end

        -- Row 4: Focus Cast Height slider
        local focusCastRow
        focusCastRow, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Focus Cast Height"),
                trackWidth = 110,
                min = 100,
                max = 200,
                step = 5,
                getValue = function() return DBVal("focusCastHeight") or defaults.focusCastHeight end,
                setValue = function(v)
                    DB().focusCastHeight = v
                    ns.RefreshAllSettings()
                end,
                tooltip = "Increases the cast bar height on your focus target's nameplate. 100% = normal height."
            },
            { type = "label", text = "" }); y = y - h

        -- Add "(Percent)" suffix in smaller, dimmer text next to the slider label
        do
            local leftFrame = focusCastRow._leftRegion
            if leftFrame then
                local suffixFS = leftFrame:CreateFontString(nil, "OVERLAY")
                suffixFS:SetFont(KT.FONT_PATH, 11, GetNPOptOutline())
                suffixFS:SetTextColor(1, 1, 1, 0.35)
                local sliderLabel
                for i = 1, leftFrame:GetNumRegions() do
                    local reg = select(i, leftFrame:GetRegions())
                    if reg and reg.GetText and reg:GetText() == "Focus Cast Height" then
                        sliderLabel = reg
                        break
                    end
                end
                if sliderLabel then
                    suffixFS:SetPoint("LEFT", sliderLabel, "RIGHT", 5, -1)
                else
                    suffixFS:SetPoint("LEFT", leftFrame, "LEFT", 180, -1)
                end
                suffixFS:SetText(LText("(Percent)"))
            end
        end

        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Display page  (preview in content header + settings in scroll area)
    ---------------------------------------------------------------------------
    local _updatePreviewHooked = false

    local _refreshAllPlatesHooked = false
    local _displayStickyPreviewShell
    local BuildNPSubTabs

    local function UpdateDisplayStickyPreviewVisibility()
        local previewShell = _displayStickyPreviewShell
        if not previewShell then return end

        local shouldShow = true
        if previewShell._ktUseStickyPreview then
            shouldShow = (KT and KT._npOptionsActiveTab == PAGE_DISPLAY)
        end

        if shouldShow then
            previewShell:Show()
            previewShell:SetAlpha(1)
            previewShell:EnableMouse(true)
        else
            previewShell:Hide()
            previewShell:SetAlpha(0)
            previewShell:EnableMouse(false)
        end
    end

    local function GetNPFontValues()
        local values = {}
        if LSM then
            for _, name in ipairs(LSM:List("font")) do
                if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
                    values[name] = name
                end
            end
        end
        if not next(values) then
            local def = (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
            values[def] = def
        end
        values._menuOpts = {
            kind = "font",
            sharedMedia = true,
            resolve = function(name)
                return LSM and LSM:Fetch("font", name, true)
            end,
        }
        return values
    end

    local function GetCurrentNPFontValue()
        local current = DBVal("font") or defaults.font
        if KT and KT.IsLocalizedDefaultFont and KT:IsLocalizedDefaultFont(current) then
            current = (KT.GetDefaultFontName and KT:GetDefaultFontName()) or current
        end
        if LSM and type(current) == "string" then
            for _, name in ipairs(LSM:List("font")) do
                local fetched = LSM:Fetch("font", name, true)
                if current == name or fetched == current then
                    return name
                end
            end
        end
        if type(current) == "string" then
            local normalized = current:gsub("/", "\\"):lower()
            if normalized:find("interface\\addons\\kullthranui\\media\\fonts\\", 1, true) then
                return (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
            end
        end
        return current
    end

    local function RefreshNPTextStyle()
        RefreshAllFonts()
        if ns.RefreshFriendlyFontOverride then ns.RefreshFriendlyFontOverride() end
        if ns.RefreshFriendlyTextStyle then ns.RefreshFriendlyTextStyle() end
        UpdatePreview()
    end

    local function ClearOptionHostChildren(host)
        if not host then return end
        for _, child in ipairs({ host:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end
    end

    local function EnsureDisplayStickyPreviewFrame()
        if _displayStickyPreviewShell then return _displayStickyPreviewShell end

        local previewShell = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        _displayStickyPreviewShell = previewShell

        if KT.AddBackdrop then
            KT:AddBackdrop(previewShell, 0.025, 0.025, 0.03, 0.98)
        end
        if KT.AddBorder then
            KT:AddBorder(previewShell, 0.18, 0.18, 0.22, 1)
        end

        local previewTitle = previewShell:CreateFontString(nil, "OVERLAY")
        previewTitle:SetFont(KT.FONT_PATH, 10, "OUTLINE")
        KT:SetAccentTextColor(previewTitle, 1)
        previewTitle:SetPoint("TOPLEFT", 10, -8)
        previewTitle:SetText(LText("LIVE PREVIEW"))
        previewShell._title = previewTitle

        local tabsHost = CreateFrame("Frame", nil, previewShell)
        tabsHost:SetPoint("TOPLEFT", previewShell, "TOPLEFT", 0, -22)
        tabsHost:SetPoint("TOPRIGHT", previewShell, "TOPRIGHT", 0, -22)
        tabsHost:SetHeight(1)
        previewShell._tabsHost = tabsHost

        local styleHost = CreateFrame("Frame", nil, previewShell)
        styleHost:SetPoint("TOPLEFT", tabsHost, "BOTTOMLEFT", 12, -8)
        styleHost:SetPoint("TOPRIGHT", tabsHost, "BOTTOMRIGHT", -12, -8)
        styleHost:SetHeight(78)
        previewShell._styleHost = styleHost

        local selectorHost = CreateFrame("Frame", nil, previewShell)
        selectorHost:SetPoint("TOPLEFT", styleHost, "BOTTOMLEFT", 0, -8)
        selectorHost:SetPoint("TOPRIGHT", styleHost, "BOTTOMRIGHT", 0, -8)
        selectorHost:SetHeight(46)
        previewShell._selectorHost = selectorHost

        local previewHost = CreateFrame("Frame", nil, previewShell)
        previewHost:SetPoint("TOPLEFT", selectorHost, "BOTTOMLEFT", 0, -10)
        previewHost:SetPoint("TOPRIGHT", selectorHost, "BOTTOMRIGHT", 0, -10)
        previewHost:SetHeight(1)
        previewShell._previewHost = previewHost
        _displayInlinePreviewHost = previewHost

        if previewShell.SetClipsChildren then
            previewShell:SetClipsChildren(true)
        end
        if previewHost.SetClipsChildren then
            previewHost:SetClipsChildren(false)
        end

        return previewShell
    end

    local function BuildCompactDisplayTabs(parent)
        local tabs = { PAGE_GENERAL, PAGE_DISPLAY, PAGE_COLORS, PAGE_THREAT, PAGE_SPECIAL, PAGE_AUTO, PAGE_ADVANCED, "Restore Defaults" }
        local outerW = (parent.GetWidth and parent:GetWidth()) or 720
        if not outerW or outerW <= 0 then outerW = 720 end

        local pad, gap, btnH = 6, 6, 28
        local perRow = (outerW >= 680) and #tabs or 4
        local rows = math.ceil(#tabs / perRow)
        local btnW = math.floor((outerW - (pad * 2) - (gap * (perRow - 1))) / perRow)

        local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -4)
        bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -4)
        bar:SetHeight((rows * btnH) + ((rows - 1) * gap) + (pad * 2))
        if KT.AddBackdrop then KT:AddBackdrop(bar, 0.035, 0.035, 0.045, 0.92) end
        if KT.AddBorder then KT:AddBorder(bar, 0.16, 0.16, 0.19, 0.9) end

        local function ApplyCompactTabStyle(button, selected, danger)
            local accentR, accentG, accentB = NPPreviewAccentRGB()
            if not button._kuiMenuBg then
                button._kuiMenuBg = button:CreateTexture(nil, "BACKGROUND", nil, -2)
                button._kuiMenuBg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                button._kuiMenuBg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
                button._kuiMenuBg:SetTexture("Interface\\Buttons\\WHITE8x8")
            end
            if not button._kuiMenuBorder then
                button._kuiMenuBorder = {}
                local top = button:CreateTexture(nil, "BORDER")
                local bottom = button:CreateTexture(nil, "BORDER")
                local left = button:CreateTexture(nil, "BORDER")
                local right = button:CreateTexture(nil, "BORDER")
                top:SetTexture("Interface\\Buttons\\WHITE8x8")
                bottom:SetTexture("Interface\\Buttons\\WHITE8x8")
                left:SetTexture("Interface\\Buttons\\WHITE8x8")
                right:SetTexture("Interface\\Buttons\\WHITE8x8")
                top:SetHeight(1); bottom:SetHeight(1)
                left:SetWidth(1); right:SetWidth(1)
                top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT")
                bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT")
                left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT")
                right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT")
                button._kuiMenuBorder[1] = top
                button._kuiMenuBorder[2] = bottom
                button._kuiMenuBorder[3] = left
                button._kuiMenuBorder[4] = right
            end

            local alpha = selected and 1 or 0.42
            local r, g, b = accentR, accentG, accentB
            if danger then
                r, g, b = 0.90, 0.18, 0.22
                alpha = selected and 1 or 0.62
            end
            if selected then
                button._kuiMenuBg:SetColorTexture(r * 0.32, g * 0.18, b * 0.22, 0.82)
            else
                button._kuiMenuBg:SetColorTexture(0.025, 0.025, 0.035, 0.92)
            end
            for _, tex in ipairs(button._kuiMenuBorder or {}) do
                tex:SetVertexColor(r, g, b, alpha)
            end
        end

        local function StyleButton(btn, selected, danger)
            ApplyCompactTabStyle(btn, selected, danger)
            if btn.txt then btn.txt:SetTextColor(selected and 1 or 0.84, selected and 1 or 0.84, selected and 1 or 0.84, 1) end
        end

        for i, name in ipairs(tabs) do
            local isReset = name == "Restore Defaults"
            local btn = CreateFrame("Button", nil, bar, "BackdropTemplate")
            local row = math.floor((i - 1) / perRow)
            local col = (i - 1) % perRow
            btn:SetSize(btnW, btnH)
            btn:SetPoint("TOPLEFT", bar, "TOPLEFT", pad + col * (btnW + gap), -pad - row * (btnH + gap))
            btn:SetHighlightTexture("")
            btn.txt = btn:CreateFontString(nil, "OVERLAY")
            btn.txt:SetFont(KT.FONT_PATH, 9, "OUTLINE")
            btn.txt:SetPoint("CENTER")
            btn.txt:SetText(LText(name))
            StyleButton(btn, KT._npOptionsActiveTab == name, isReset)
            btn:SetScript("OnClick", function()
                if isReset then
                    StaticPopup_Show("KUI_NAMEPLATES_RESTORE_DEFAULTS")
                    return
                end
                if KT._npOptionsActiveTab == name then return end
                KT._npOptionsActiveTab = name
                if name == PAGE_DISPLAY then
                    RandomizePreviewValues()
                elseif name == PAGE_COLORS and _colorPreviewRandomizeAll then
                    _colorPreviewRandomizeAll()
                end
                if KT.RefreshPage then KT:RefreshPage() end
            end)
            btn:SetScript("OnEnter", function()
                if KT._npOptionsActiveTab ~= name then
                    ApplyCompactTabStyle(btn, true, isReset)
                    if btn.txt then btn.txt:SetTextColor(1, 1, 1, 1) end
                end
            end)
            btn:SetScript("OnLeave", function()
                StyleButton(btn, KT._npOptionsActiveTab == name, isReset)
            end)
        end

        return bar:GetHeight() + 6
    end

    local function BuildCompactModeSelector(parent)
        local modes = {
            { key = "enemy", label = "Enemy" },
            { key = "friendly", label = "Friendly" },
        }
        local w = (parent.GetWidth and parent:GetWidth()) or 300
        local gap, btnH = 6, 22
        local btnW = math.floor((w - gap) / 2)
        for i, mode in ipairs(modes) do
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(btnW, btnH)
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", (i - 1) * (btnW + gap), 0)
            btn.txt = btn:CreateFontString(nil, "OVERLAY")
            btn.txt:SetFont(KT.FONT_PATH, 9, "OUTLINE")
            btn.txt:SetPoint("CENTER")
            btn.txt:SetText(LText(mode.label))
            local selected = (_displayPageMode or "enemy") == mode.key
            local accentR, accentG, accentB = NPPreviewAccentRGB()
            local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
            bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
            bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetColorTexture(selected and (accentR * 0.32) or 0.025, selected and (accentG * 0.18) or 0.025, selected and (accentB * 0.22) or 0.035, selected and 0.82 or 0.92)
            btn._kuiMenuBg = bg
            local slices = {}
            for sliceIndex = 1, 9 do
                local tex = btn:CreateTexture(nil, "BACKGROUND")
                tex:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\MenuButtonTab.png")
                slices[sliceIndex] = tex
            end
            local TL, TR, BL, BR = slices[1], slices[2], slices[3], slices[4]
            local T, B, L, R, C = slices[5], slices[6], slices[7], slices[8], slices[9]
            local cornerScreen = 4
            local minX, maxX = 12 / 601, 586 / 601
            local minY, maxY = 8 / 147, 136 / 147
            local cx, cy = 8 / 601, 8 / 147
            TL:SetSize(cornerScreen, cornerScreen); TR:SetSize(cornerScreen, cornerScreen)
            BL:SetSize(cornerScreen, cornerScreen); BR:SetSize(cornerScreen, cornerScreen)
            TL:SetPoint("TOPLEFT"); TR:SetPoint("TOPRIGHT")
            BL:SetPoint("BOTTOMLEFT"); BR:SetPoint("BOTTOMRIGHT")
            T:SetPoint("TOPLEFT", TL, "TOPRIGHT"); T:SetPoint("BOTTOMRIGHT", TR, "BOTTOMLEFT")
            B:SetPoint("TOPLEFT", BL, "TOPRIGHT"); B:SetPoint("BOTTOMRIGHT", BR, "BOTTOMLEFT")
            L:SetPoint("TOPLEFT", TL, "BOTTOMLEFT"); L:SetPoint("BOTTOMRIGHT", BL, "TOPRIGHT")
            R:SetPoint("TOPLEFT", TR, "BOTTOMLEFT"); R:SetPoint("BOTTOMRIGHT", BR, "TOPRIGHT")
            C:SetPoint("TOPLEFT", TL, "BOTTOMRIGHT"); C:SetPoint("BOTTOMRIGHT", BR, "TOPLEFT")
            TL:SetTexCoord(minX, minX + cx, minY, minY + cy)
            TR:SetTexCoord(maxX - cx, maxX, minY, minY + cy)
            BL:SetTexCoord(minX, minX + cx, maxY - cy, maxY)
            BR:SetTexCoord(maxX - cx, maxX, maxY - cy, maxY)
            T:SetTexCoord(minX + cx, maxX - cx, minY, minY + cy)
            B:SetTexCoord(minX + cx, maxX - cx, maxY - cy, maxY)
            L:SetTexCoord(minX, minX + cx, minY + cy, maxY - cy)
            R:SetTexCoord(maxX - cx, maxX, minY + cy, maxY - cy)
            C:SetTexCoord(minX + cx, maxX - cx, minY + cy, maxY - cy)
            for _, tex in ipairs(slices) do
                tex:SetVertexColor(accentR, accentG, accentB, selected and 1 or 0.42)
            end
            btn._kuiMenuSlices = slices
            if selected then
                btn.txt:SetTextColor(1, 1, 1, 1)
            else
                btn.txt:SetTextColor(0.82, 0.82, 0.82, 1)
            end
            btn:SetScript("OnEnter", function(self)
                if self._kuiMenuBg then
                    self._kuiMenuBg:SetColorTexture(accentR * 0.30, accentG * 0.18, accentB * 0.22, 0.78)
                end
                for _, tex in ipairs(self._kuiMenuSlices or {}) do
                    tex:SetVertexColor(accentR, accentG, accentB, 1)
                end
                if self.txt then self.txt:SetTextColor(1, 1, 1, 1) end
            end)
            btn:SetScript("OnLeave", function(self)
                local isSelected = (_displayPageMode or "enemy") == mode.key
                if self._kuiMenuBg then
                    self._kuiMenuBg:SetColorTexture(isSelected and (accentR * 0.32) or 0.025, isSelected and (accentG * 0.18) or 0.025, isSelected and (accentB * 0.22) or 0.035, isSelected and 0.82 or 0.92)
                end
                for _, tex in ipairs(self._kuiMenuSlices or {}) do
                    tex:SetVertexColor(accentR, accentG, accentB, isSelected and 1 or 0.42)
                end
                if self.txt then self.txt:SetTextColor(isSelected and 1 or 0.82, isSelected and 1 or 0.82, isSelected and 1 or 0.82, 1) end
            end)
            btn:SetScript("OnClick", function()
                if _displayPageMode == mode.key then return end
                _displayPageMode = mode.key
                if KT and KT.RefreshPage then KT:RefreshPage() end
            end)
        end
        parent:SetHeight(btnH)
        return btnH
    end

    local function BuildDisplayStickyPreview(pageParent, yOffset, displayMode, W)
        local previewShell = EnsureDisplayStickyPreviewFrame()
        local previewMode = displayMode or _displayPageMode or "enemy"
        local pageW = (pageParent and pageParent.GetWidth and pageParent:GetWidth()) or 700
        if not pageW or pageW <= 0 then pageW = 700 end

        previewShell._ktUseStickyPreview = true
        previewShell:SetParent(UIParent)
        previewShell:ClearAllPoints()
        previewShell:SetWidth(math.max(320,
            ((KT.MenuPrincipal and KT.MenuPrincipal._stickyPreviewHost and KT.MenuPrincipal._stickyPreviewHost:GetWidth()) or
                pageW) - 4))
        previewShell:SetFrameStrata(pageParent:GetFrameStrata() or "MEDIUM")
        previewShell:SetFrameLevel((pageParent:GetFrameLevel() or 1) + 24)
        previewShell:Show()
        if previewShell._title then previewShell._title:Show() end

        local tabsHost = previewShell._tabsHost
        tabsHost:ClearAllPoints()
        tabsHost:SetPoint("TOPLEFT", previewShell, "TOPLEFT", 0, -18)
        tabsHost:SetPoint("TOPRIGHT", previewShell, "TOPRIGHT", 0, -18)
        ClearOptionHostChildren(tabsHost)
        tabsHost:SetHeight(BuildCompactDisplayTabs(tabsHost))
        tabsHost:Show()

        local styleHost = previewShell._styleHost
        styleHost:ClearAllPoints()
        styleHost:SetPoint("TOPLEFT", tabsHost, "BOTTOMLEFT", 12, -8)
        styleHost:SetPoint("TOPRIGHT", tabsHost, "BOTTOMRIGHT", -12, -8)
        styleHost:SetWidth(math.max(300, pageW - 24))
        ClearOptionHostChildren(styleHost)

        -- These global selectors are used constantly while tuning the preview.
        -- Keep all three on one compact row so the preview retains more space.
        local styleRow = CreateFrame("Frame", nil, styleHost)
        local styleRowW = math.max(300, styleHost:GetWidth())
        local styleGap = 8
        local styleColumnW = (styleRowW - (styleGap * 2)) / 3
        styleRow:SetPoint("TOPLEFT", styleHost, "TOPLEFT", 0, 0)
        styleRow:SetSize(styleRowW, 50)

        local function AddStyleDropdown(columnIndex, text, values, getValue, setValue, order, preview)
            local column = CreateFrame("Frame", nil, styleRow)
            column:SetSize(styleColumnW, 50)
            column:SetPoint("TOPLEFT", styleRow, "TOPLEFT",
                (columnIndex - 1) * (styleColumnW + styleGap), 0)
            W:Dropdown(column, text, 0, values, getValue, setValue, order, preview)
        end

        AddStyleDropdown(1, LText("Global Font"), GetNPFontValues,
            function() return GetCurrentNPFontValue() end,
            function(v)
                DB().font = (LSM and LSM:Fetch("font", v, true)) or v
                RefreshNPTextStyle()
            end)

        AddStyleDropdown(2, LText("Outline"), {
                [""] = "None",
                ["OUTLINE"] = "Thin",
                ["THICKOUTLINE"] = "Thick",
                ["MONOCHROMEOUTLINE"] = "Monochrome",
            },
            function() return DBVal("fontOutline") or defaults.fontOutline end,
            function(v)
                DB().fontOutline = v
                RefreshNPTextStyle()
            end,
            { "", "OUTLINE", "THICKOUTLINE", "MONOCHROMEOUTLINE" })

        AddStyleDropdown(3, LText("Bar Texture"), hbtValues,
            function()
                return DBVal("healthBarTexture") or defaults.healthBarTexture or "Melli Reforged"
            end,
            function(v)
                DB().healthBarTexture = v
                if ns.RefreshAllSettings then ns.RefreshAllSettings() end
                if UpdatePreview then UpdatePreview() end
            end,
            hbtOrder,
            { kind = "texture", sharedMedia = true })

        styleHost:SetHeight(50)
        styleHost:Show()

        local selectorHost = previewShell._selectorHost
        selectorHost:ClearAllPoints()
        selectorHost:SetPoint("TOPLEFT", styleHost, "BOTTOMLEFT", 0, -5)
        selectorHost:SetWidth(190)
        ClearOptionHostChildren(selectorHost)

        BuildCompactModeSelector(selectorHost)

        local previewHost = previewShell._previewHost
        previewHost:SetParent(previewShell)
        previewHost:ClearAllPoints()
        previewHost:SetPoint("TOPLEFT", selectorHost, "BOTTOMLEFT", 0, -7)
        previewHost:SetPoint("TOPRIGHT", styleHost, "BOTTOMRIGHT", 0, -7)
        selectorHost:Show()
        previewHost:Show()

        local previewW = pageW

        if not activePreview then
            BuildNameplatePreview(previewHost, previewW)
        end
        if not activeFriendlyPreview then
            BuildFriendlyNameplatePreview(previewHost, previewW)
        end

        if previewMode == "enemy" then
            activePreview:SetParent(previewHost)
            activePreview:ClearAllPoints()
            activePreview:SetPoint("TOP", previewHost, "TOP", 0, 0)
            activePreview:SetScale((UIParent:GetEffectiveScale() / previewHost:GetEffectiveScale()) * 0.78)
            activePreview:SetFrameStrata(previewShell:GetFrameStrata())
            activePreview:SetFrameLevel(previewShell:GetFrameLevel() + 10)
            activePreview:SetAlpha(1)
            if activePreview.Update then activePreview:Update() end
            activePreview:Show()
            if activeFriendlyPreview then activeFriendlyPreview:Hide() end
        else
            activeFriendlyPreview._parentW = previewW
            activeFriendlyPreview:SetParent(previewHost)
            activeFriendlyPreview:ClearAllPoints()
            activeFriendlyPreview:SetPoint("TOP", previewHost, "TOP", 0, 0)
            activeFriendlyPreview:SetFrameStrata(previewShell:GetFrameStrata())
            activeFriendlyPreview:SetFrameLevel(previewShell:GetFrameLevel() + 10)
            activeFriendlyPreview:SetAlpha(1)
            if activeFriendlyPreview.Update then activeFriendlyPreview:Update() end
            activeFriendlyPreview:Show()
            if activePreview then activePreview:Hide() end
        end

        local shownPreview = (previewMode == "enemy") and activePreview or activeFriendlyPreview
        local previewH = 0
        if shownPreview and shownPreview.GetHeight and shownPreview.GetScale then
            previewH = shownPreview:GetHeight() * (shownPreview:GetScale() or 1)
        end
        local minPreviewH = (previewMode == "enemy") and 96 or 82
        local previewBottomPad = (previewMode == "enemy") and 12 or 10
        local visiblePreviewH = math.max(minPreviewH, previewH + 4)
        local previewChromeH = 18 + tabsHost:GetHeight() + 5 + styleHost:GetHeight() + 5 + selectorHost:GetHeight() + 7
        previewHost:SetHeight(visiblePreviewH)
        previewShell:SetHeight(previewChromeH + visiblePreviewH + previewBottomPad)

        local stickyHost = KT.MenuPrincipal and KT.MenuPrincipal._stickyPreviewHost
        if stickyHost then
            if stickyHost.bgKT then stickyHost.bgKT:SetAlpha(0) end
            if stickyHost._ktBackdropTexture then stickyHost._ktBackdropTexture:SetAlpha(0) end
            if stickyHost._ktBorderFrame then stickyHost._ktBorderFrame:SetAlpha(0) end
        end

        KT:AttachStickyPreview(previewShell, {
            point = "TOP",
            relativePoint = "TOP",
            x = 0,
            y = 0,
            height = previewShell:GetHeight(),
            extraPad = 0,
        })

        local menu = KT and KT.MenuPrincipal
        local sb = menu and menu.scrollFrame and menu.scrollFrame.ScrollBar
        if sb and not sb._ktNPDisplayStickyHooked then
            sb._ktNPDisplayStickyHooked = true
            sb:HookScript("OnValueChanged", function()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, UpdateDisplayStickyPreviewVisibility)
                else
                    UpdateDisplayStickyPreviewVisibility()
                end
            end)
        end

        UpdateDisplayStickyPreviewVisibility()
        return previewShell:GetHeight() + 4
    end

    local function BuildDisplayPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local y = yOffset
        local _, h
        local displayMode = _displayPageMode or "enemy"
        local pageParent = parent

        y = y - BuildDisplayStickyPreview(pageParent, yOffset, displayMode, W)

        local function isBorderNone()
            return (DBVal("borderStyle") or defaults.borderStyle) == "none"
        end

        local topDebuffAlignValues = {
            ["left"] = "Left",
            ["center"] = "Center",
            ["right"] = "Right",
        }
        local topDebuffAlignOrder = { "left", "center", "right" }

        local enemyTextHeader
        local enemyNameTextRow

        enemyTextHeader, h = W:SectionHeader(parent, "ENEMY TEXT", y)
        y = y - h

        enemyNameTextRow, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Enemy Name Text Size"),
                min = 8,
                max = 28,
                step = 1,
                getValue = function() return DBVal("textSlotTopSize") or defaults.textSlotTopSize end,
                setValue = function(v)
                    DB().textSlotTopSize = v
                    RefreshNPTextStyle()
                end,
            },
            {
                type = "button",
                text = LText("Refresh Text"),
                onClick = function()
                    RefreshNPTextStyle()
                end,
            })
        y = y - h

        local function RefreshNameplateLevelSettings()
            if ns.RefreshNameplateLevels then
                ns.RefreshNameplateLevels()
            else
                for _, plate in pairs(plates) do
                    if plate.UpdateLevel then plate:UpdateLevel() end
                end
            end
            UpdatePreview()
        end
        local levelFontValues, levelFontOrder = {}, {}
        if LSM and LSM.List then
            for _, fontName in ipairs(LSM:List("font")) do
                levelFontValues[fontName] = fontName
                levelFontOrder[#levelFontOrder + 1] = fontName
            end
        end
        local currentLevelFont = DBVal("levelFont") or defaults.levelFont
        if currentLevelFont and not levelFontValues[currentLevelFont] then
            levelFontValues[currentLevelFont] = currentLevelFont
            levelFontOrder[#levelFontOrder + 1] = currentLevelFont
        end
        local levelOutlineValues = {
            NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline",
            MONOCHROME = "Monochrome", OUTLINEMONOCHROME = "Monochrome Outline",
        }
        local levelOutlineOrder = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "OUTLINEMONOCHROME" }
        _, h = W:SectionHeader(parent, "NAMEPLATE LEVEL", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle", text = LText("Show Enemy Level"),
                getValue = function() return DBVal("showEnemyLevel") == true end,
                setValue = function(v)
                    DB().showEnemyLevel = v and true or false
                    DB().showLevel = DB().showEnemyLevel
                    RefreshNameplateLevelSettings()
                end,
            },
            {
                type = "dropdown", text = LText("Level Font"), values = levelFontValues, order = levelFontOrder,
                getValue = function() return DBVal("levelFont") or defaults.levelFont end,
                setValue = function(v) DB().levelFont = v; RefreshNameplateLevelSettings() end,
            }); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle", text = LText("Show Friendly Level"),
                getValue = function() return DBVal("showFriendlyLevel") == true end,
                setValue = function(v)
                    DB().showFriendlyLevel = v and true or false
                    RefreshNameplateLevelSettings()
                end,
            },
            { type = "label", text = "" }); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "slider", text = LText("Level Font Size"), min = 6, max = 48, step = 1,
                getValue = function() return tonumber(DBVal("levelFontSize")) or 11 end,
                setValue = function(v) DB().levelFontSize = v; RefreshNameplateLevelSettings() end,
            },
            {
                type = "dropdown", text = LText("Level Text Outline"), values = levelOutlineValues, order = levelOutlineOrder,
                getValue = function() return DBVal("levelFontOutline") or "OUTLINE" end,
                setValue = function(v) DB().levelFontOutline = v; RefreshNameplateLevelSettings() end,
            }); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "colorpicker", text = LText("Level Text Color"),
                getValue = function() local c = DBVal("levelColor") or defaults.levelColor; return c.r or 1, c.g or 1, c.b or 1 end,
                setValue = function(r, g, b) DB().levelColor = { r = r, g = g, b = b, a = 1 }; RefreshNameplateLevelSettings() end,
            },
            { type = "toggle", text = LText("Level Text Shadow"),
                getValue = function() return DBVal("levelShadow") ~= false end,
                setValue = function(v) DB().levelShadow = v and true or false; RefreshNameplateLevelSettings() end,
            }); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "slider", text = LText("Level X Offset"), min = -200, max = 200, step = 1,
                getValue = function() return tonumber(DBVal("levelXOffset")) or 24 end,
                setValue = function(v) DB().levelXOffset = v; RefreshNameplateLevelSettings() end,
            },
            {
                type = "slider", text = LText("Level Y Offset"), min = -100, max = 200, step = 1,
                getValue = function() return tonumber(DBVal("levelYOffset")) or 4 end,
                setValue = function(v) DB().levelYOffset = v; RefreshNameplateLevelSettings() end,
            }); y = y - h

        _, h = W:Spacer(parent, y, 8)
        y = y - h

        _, h = W:Dropdown(parent, "Top Debuffs Default Position", y,
            topDebuffAlignValues,
            function() return GetTopDebuffAlignValue() end,
            function(v)
                DB().topDebuffAlign = v
                RefreshAllAuras()
                UpdatePreview()
            end,
            topDebuffAlignOrder)
        y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Top Debuffs X Offset"),
                min = -120,
                max = 120,
                step = 1,
                getValue = function() return GetTopDebuffOffsetXValue() end,
                setValue = function(v)
                    DB().topDebuffOffsetX = v
                    RefreshAllAuras()
                    UpdatePreview()
                end,
            },
            { type = "label", text = LText("Fine tune top debuffs horizontally.") }); y = y - h

        if displayMode == "friendly" then
            local function friendlyPlayersOff()
                return DBVal("showFriendlyPlayers") == false and DBVal("friendlyShowDefaultNames") ~= true
            end
            local friendlyDisplayHeader
            local friendlyPlayerModeRow
            local friendlyNPCDisplayRow
            local friendlyTextHeader
            local friendlyPlayerAlignRow
            local friendlyNPCTextRow

            friendlyDisplayHeader, h = W:SectionHeader(parent, "FRIENDLY DISPLAY", y); y = y - h

            friendlyPlayerModeRow, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Show Friendly Player Nameplates"),
                    getValue = function() return DBVal("showFriendlyPlayers") ~= false end,
                    setValue = function(v)
                        DB().showFriendlyPlayers = v
                        if v then DB().friendlyShowDefaultNames = false end
                        if SetCVar then
                            pcall(SetCVar, "nameplateShowFriendlyPlayers", v and 1 or 0)
                            pcall(SetCVar, "nameplateShowFriends", v and 1 or 0)
                        end
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        ns.RefreshStackingMotion()
                        KT:RefreshPage()
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Make Friendly Nameplates Name Only"),
                    getValue = function() return DBVal("friendlyNameOnly") ~= false end,
                    setValue = function(v)
                        DB().friendlyNameOnly = v
                        if SetCVar then
                            pcall(SetCVar, "nameplateShowOnlyNameForFriendlyPlayerUnits", v and 1 or 0)
                        end
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        KT:RefreshPage()
                    end,
                    disabled = friendlyPlayersOff,
                    disabledTooltip = "Show Friendly Player Nameplates",
                }); y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Friendly Plate Distance"),
                    min = -50,
                    max = 50,
                    step = 1,
                    getValue = function() return DBVal("friendlyPlateYOffset") or 0 end,
                    setValue = function(v)
                        DB().friendlyPlateYOffset = v
                        if ns.RefreshFriendlyPlateYOffset then ns.RefreshFriendlyPlateYOffset() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyNameOnly") ~= false end,
                    disabledTooltip = "Requires friendly health bars",
                },
                {
                    type = "slider",
                    text = LText("Name Only Distance"),
                    min = -50,
                    max = 50,
                    step = 1,
                    getValue = function() return DBVal("friendlyNameOnlyYOffset") or defaults.friendlyNameOnlyYOffset end,
                    setValue = function(v)
                        DB().friendlyNameOnlyYOffset = v
                        if ns.RefreshFriendlyNameOnlyOffset then ns.RefreshFriendlyNameOnlyOffset() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyNameOnly") == false end,
                    disabledTooltip = "Requires Name Only mode",
                }); y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Friendly Bar Height"),
                    min = 6,
                    max = 40,
                    step = 1,
                    getValue = function() return DBVal("friendlyHealthBarHeight") or defaults.friendlyHealthBarHeight end,
                    setValue = function(v)
                        DB().friendlyHealthBarHeight = v
                        if ns.RefreshFriendlyPlateSize then ns.RefreshFriendlyPlateSize() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyNameOnly") ~= false end,
                    disabledTooltip = "Requires friendly health bars",
                },
                {
                    type = "slider",
                    text = LText("Friendly Bar Width"),
                    min = 80,
                    max = 250,
                    step = 1,
                    getValue = function() return DBVal("friendlyHealthBarWidth") or defaults.friendlyHealthBarWidth end,
                    setValue = function(v)
                        DB().friendlyHealthBarWidth = v
                        if ns.RefreshFriendlyPlateSize then ns.RefreshFriendlyPlateSize() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyNameOnly") ~= false end,
                    disabledTooltip = "Requires friendly health bars",
                }); y = y - h

            friendlyNPCDisplayRow, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Show Friendly NPC Nameplates"),
                    getValue = function() return DBVal("showFriendlyNPCs") == true end,
                    setValue = function(v)
                        DB().showFriendlyNPCs = v
                        if SetCVar then
                            pcall(SetCVar, "nameplateShowFriendlyNPCs", v and 1 or 0)
                            pcall(SetCVar, "nameplateShowFriendlyNpcs", v and 1 or 0)
                        end
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Show Friendly Health Percent"),
                    getValue = function() return not DBVal("friendlyHideHealthText") end,
                    setValue = function(v)
                        DB().friendlyHideHealthText = not v
                        if ns.RefreshFriendlyHealthText then ns.RefreshFriendlyHealthText() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyNameOnly") ~= false end,
                    disabledTooltip = "Requires friendly health bars",
                }); y = y - h

            _, h = W:Spacer(parent, y, 16); y = y - h
            friendlyTextHeader, h = W:SectionHeader(parent, "FRIENDLY TEXT", y); y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Friendly Class Colored Names"),
                    getValue = function() return DBVal("classColorFriendly") ~= false end,
                    setValue = function(v)
                        DB().classColorFriendly = v
                        if SetCVar then
                            pcall(SetCVar, "ShowClassColorInFriendlyNameplate", v and 1 or 0)
                            pcall(SetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames", v and 1 or 0)
                        end
                        RefreshNPTextStyle()
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Show Guild Under Friendly Players"),
                    getValue = function() return DBVal("friendlyShowGuild") ~= false end,
                    setValue = function(v)
                        DB().friendlyShowGuild = v
                        if ns.RefreshFriendlyTextStyle then ns.RefreshFriendlyTextStyle() end
                    end,
                    disabled = friendlyPlayersOff,
                    disabledTooltip = "Show Friendly Player Nameplates",
                }); y = y - h

            friendlyPlayerAlignRow, h = W:DualRow(parent, y,
                {
                    type = "dropdown",
                    text = LText("Friendly Player Alignment"),
                    values = {
                        ["center"] = "Centered",
                        ["left"] = "From Left",
                        ["right"] = "From Right",
                    },
                    order = { "center", "left", "right" },
                    getValue = function()
                        return DBVal("friendlyPlayerNameAlignment") or defaults.friendlyPlayerNameAlignment
                    end,
                    setValue = function(v)
                        DB().friendlyPlayerNameAlignment = v
                        RefreshNPTextStyle()
                    end,
                },
                {
                    type = "dropdown",
                    text = LText("Friendly NPC Alignment"),
                    values = {
                        ["center"] = "Centered",
                        ["left"] = "From Left",
                        ["right"] = "From Right",
                    },
                    order = { "center", "left", "right" },
                    getValue = function()
                        return DBVal("friendlyNPCNameAlignment") or defaults.friendlyNPCNameAlignment
                    end,
                    setValue = function(v)
                        DB().friendlyNPCNameAlignment = v
                        RefreshNPTextStyle()
                    end,
                }); y = y - h

            friendlyNPCTextRow, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Friendly Player Name Size"),
                    min = 8,
                    max = 24,
                    step = 1,
                    getValue = function() return DBVal("friendlyPlayerNameTextSize") or defaults.friendlyPlayerNameTextSize end,
                    setValue = function(v)
                        DB().friendlyPlayerNameTextSize = v
                        RefreshNPTextStyle()
                    end,
                },
                {
                    type = "slider",
                    text = LText("Friendly NPC Name Size"),
                    min = 8,
                    max = 24,
                    step = 1,
                    getValue = function() return DBVal("friendlyNPCNameTextSize") or defaults.friendlyNPCNameTextSize end,
                    setValue = function(v)
                        DB().friendlyNPCNameTextSize = v
                        RefreshNPTextStyle()
                    end,
                }); y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Friendly Guild Size"),
                    min = 8,
                    max = 20,
                    step = 1,
                    getValue = function() return DBVal("friendlyGuildTextSize") or defaults.friendlyGuildTextSize end,
                    setValue = function(v)
                        DB().friendlyGuildTextSize = v
                        RefreshNPTextStyle()
                    end,
                },
                {
                    type = "slider",
                    text = LText("Friendly Health Text Size"),
                    min = 8,
                    max = 20,
                    step = 1,
                    getValue = function() return DBVal("friendlyHealthTextSize") or defaults.friendlyHealthTextSize end,
                    setValue = function(v)
                        DB().friendlyHealthTextSize = v
                        RefreshNPTextStyle()
                    end,
                }); y = y - h

            do
                local preview = activeFriendlyPreview
                if preview then
                    local function ScrollToTarget(section, target)
                        if not (section and target and KT and KT.SmoothScrollTo) then return end
                        local _, _, _, _, headerY = section:GetPoint(1)
                        if not headerY then return end
                        KT.SmoothScrollTo(math.max(0, math.abs(headerY) - 40))
                        C_Timer.After(0.15, function()
                            if not target then return end
                            local glow = target._friendlyPreviewGlow
                            if not glow then
                                glow = CreateFrame("Frame", nil, target)
                                glow:SetAllPoints(target)
                                glow:SetFrameLevel(target:GetFrameLevel() + 8)
                                local edges = {}
                                local function edge()
                                    local t = glow:CreateTexture(nil, "OVERLAY", nil, 7)
                                    t:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, 1)
                                    edges[#edges + 1] = t
                                    return t
                                end
                                local top = edge()
                                top:SetPoint("TOPLEFT")
                                top:SetPoint("TOPRIGHT")
                                top:SetHeight(2)
                                local bottom = edge()
                                bottom:SetPoint("BOTTOMLEFT")
                                bottom:SetPoint("BOTTOMRIGHT")
                                bottom:SetHeight(2)
                                local left = edge()
                                left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
                                left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
                                left:SetWidth(2)
                                local right = edge()
                                right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
                                right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
                                right:SetWidth(2)
                                glow._edges = edges
                                target._friendlyPreviewGlow = glow
                            end
                            glow:SetAlpha(1)
                            glow:Show()
                            glow:SetScript("OnUpdate", function(self, dt)
                                self._elapsed = (self._elapsed or 0) + dt
                                if self._elapsed >= 0.75 then
                                    self._elapsed = nil
                                    self:SetAlpha(0)
                                    self:Hide()
                                    self:SetScript("OnUpdate", nil)
                                    return
                                end
                                self:SetAlpha(1 - self._elapsed / 0.75)
                            end)
                        end)
                    end

                    local function EnsurePreviewNavButton(key, anchor, section, target, tooltip)
                        if not anchor then return end
                        local btn = preview[key]
                        if not btn then
                            btn = CreateFrame("Button", nil, preview)
                            btn:EnableMouse(true)
                            btn:RegisterForClicks("LeftButtonDown")
                            local edges = {}
                            local function edge()
                                local t = btn:CreateTexture(nil, "OVERLAY", nil, 7)
                                t:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, 1)
                                edges[#edges + 1] = t
                                return t
                            end
                            local top = edge()
                            top:SetPoint("TOPLEFT")
                            top:SetPoint("TOPRIGHT")
                            top:SetHeight(2)
                            local bottom = edge()
                            bottom:SetPoint("BOTTOMLEFT")
                            bottom:SetPoint("BOTTOMRIGHT")
                            bottom:SetHeight(2)
                            local left = edge()
                            left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
                            left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
                            left:SetWidth(2)
                            local right = edge()
                            right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
                            right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
                            right:SetWidth(2)
                            btn._edges = edges
                            for _, tex in ipairs(edges) do tex:Hide() end
                            btn:SetScript("OnEnter", function(self)
                                for _, tex in ipairs(self._edges or {}) do tex:Show() end
                                if tooltip then KT_ShowWidgetTooltip(self, tooltip, { width = 180 }) end
                            end)
                            btn:SetScript("OnLeave", function(self)
                                for _, tex in ipairs(self._edges or {}) do tex:Hide() end
                                KT_HideWidgetTooltip()
                            end)
                            preview[key] = btn
                        end
                        btn:SetScript("OnMouseDown", function()
                            ScrollToTarget(section, target)
                        end)
                        btn:ClearAllPoints()
                        btn:SetAllPoints(anchor)
                        btn:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or preview:GetFrameLevel()) + 10)
                        btn:Show()
                    end

                    EnsurePreviewNavButton("_playerNavBtn", preview._player, friendlyTextHeader, friendlyPlayerAlignRow,
                        "Open Friendly Player settings")
                    EnsurePreviewNavButton("_npcNavBtn", preview._npc, friendlyTextHeader, friendlyNPCTextRow,
                        "Open Friendly NPC settings")
                end
            end

            return math.abs(y)
        end

        _, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Right Text Size"),
                min = 8,
                max = 24,
                step = 1,
                getValue = function() return DBVal("textSlotRightSize") or defaults.textSlotRightSize end,
                setValue = function(v)
                    DB().textSlotRightSize = v
                    RefreshNPTextStyle()
                end,
            },
            {
                type = "slider",
                text = LText("Left Text Size"),
                min = 8,
                max = 24,
                step = 1,
                getValue = function() return DBVal("textSlotLeftSize") or defaults.textSlotLeftSize end,
                setValue = function(v)
                    DB().textSlotLeftSize = v
                    RefreshNPTextStyle()
                end,
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Center Text Size"),
                min = 8,
                max = 24,
                step = 1,
                getValue = function() return DBVal("textSlotCenterSize") or defaults.textSlotCenterSize end,
                setValue = function(v)
                    DB().textSlotCenterSize = v
                    RefreshNPTextStyle()
                end,
            },
            { type = "label", text = "" }); y = y - h

        _, h = W:Label(parent,
            "Secondary text sizes are for the right, left and center text slots.",
            y, 11); y = y - h

        _, h = W:Spacer(parent, y, 16); y = y - h

        -- Hook UpdatePreview so every widget setValue callback that calls it
        -- automatically triggers drift detection (auto-creates "Custom" when editing a built-in).
        -- Only hook once: the original UpdatePreview is a simple wrapper around activePreview:Update().
        -- After hooking, subsequent BuildDisplayPage calls reuse the already-hooked version.
        if not _updatePreviewHooked then
            _updatePreviewHooked = true
            local _origUpdatePreview = UpdatePreview
            UpdatePreview = function()
                _origUpdatePreview()
                if onPresetSettingChanged then onPresetSettingChanged() end
            end
        end

        -- Enable per-row center divider for the dual-column layout
        parent._showRowDivider = true

        local INLINE_PAD = 12
        local INLINE_GAP = 8
        local function LayoutInlineWidgets(rgn)
            if not (rgn and rgn._inlineWidgets) then return end
            local x = -INLINE_PAD
            local reserved = 0
            for _, widget in ipairs(rgn._inlineWidgets) do
                if widget and widget:IsShown() and widget.ClearAllPoints and widget.GetWidth then
                    widget:ClearAllPoints()
                    widget:SetPoint("RIGHT", rgn, "RIGHT", x, 0)
                    local step = (widget:GetWidth() or 0) + INLINE_GAP
                    x = x - step
                    reserved = reserved + step
                end
            end
            if rgn._control and rgn._control.SetReservedRightSpace then
                rgn._control:SetReservedRightSpace(reserved + INLINE_PAD)
            elseif rgn._control and rgn._control.SetWidth then
                local baseWidth = (rgn:GetWidth() or 0) - 20
                local targetWidth = math.max(120, baseWidth - reserved - INLINE_PAD)
                rgn._control:SetWidth(targetWidth)
            end
            rgn._lastInline = rgn._inlineWidgets[#rgn._inlineWidgets]
        end

        local function AttachInlineWidget(rgn, widget)
            if not (rgn and widget) then return end
            if widget._inlineRegion and widget._inlineRegion ~= rgn and widget._inlineRegion._inlineWidgets then
                for i = #widget._inlineRegion._inlineWidgets, 1, -1 do
                    if widget._inlineRegion._inlineWidgets[i] == widget then
                        table.remove(widget._inlineRegion._inlineWidgets, i)
                        break
                    end
                end
                LayoutInlineWidgets(widget._inlineRegion)
            end
            for _, existing in ipairs(rgn._inlineWidgets or {}) do
                if existing == widget then
                    widget._inlineRegion = rgn
                    LayoutInlineWidgets(rgn)
                    return
                end
            end
            rgn._inlineWidgets = rgn._inlineWidgets or {}
            rgn._inlineWidgets[#rgn._inlineWidgets + 1] = widget
            widget._inlineRegion = rgn
            LayoutInlineWidgets(rgn)
        end

        local function DetachInlineWidget(widget)
            local rgn = widget and widget._inlineRegion
            if not (rgn and rgn._inlineWidgets) then return end
            for i = #rgn._inlineWidgets, 1, -1 do
                if rgn._inlineWidgets[i] == widget then
                    table.remove(rgn._inlineWidgets, i)
                    break
                end
            end
            widget._inlineRegion = nil
            LayoutInlineWidgets(rgn)
        end

        -----------------------------------------------------------------------
        --  AURA POSITIONS
        -----------------------------------------------------------------------
        local slotKeys = { "debuffSlot", "buffSlot", "ccSlot", "raidMarkerPos", "classificationSlot" }

        -- Inverted mapping: position element (for CORE POSITIONS dropdowns)
        local elementToKey = {
            debuffs        = "debuffSlot",
            buffs          = "buffSlot",
            ccs            = "ccSlot",
            raidmarker     = "raidMarkerPos",
            classification = "classificationSlot",
        }
        local keyToElement = {}
        for elem, key in pairs(elementToKey) do keyToElement[key] = elem end

        local function GetElementAtPosition(pos)
            local db = DB()
            for _, key in ipairs(slotKeys) do
                if (db[key] or defaults[key]) == pos then
                    return keyToElement[key]
                end
            end
            return "none"
        end

        local function SetElementAtPosition(pos, element)
            if element == "none" then
                -- Clear: find whatever element is at this position and move it to "none"
                local db = DB()
                for _, key in ipairs(slotKeys) do
                    if (db[key] or defaults[key]) == pos then
                        db[key] = "none"
                    end
                end
                return
            end
            local key = elementToKey[element]
            if not key then return end
            local db = DB()
            -- Clear old holder of this position (set to "none"), no swapping
            for _, otherKey in ipairs(slotKeys) do
                if otherKey ~= key and (db[otherKey] or defaults[otherKey]) == pos then
                    db[otherKey] = "none"
                end
            end
            db[key] = pos
        end

        local slotValues = {
            ["top"]      = "Top",
            ["left"]     = "Left",
            ["right"]    = "Right",
            ["topleft"]  = "Top Left",
            ["topright"] = "Top Right",
            ["bottom"]   = "Bottom",
            ["none"]     = "None",
        }
        local slotOrder = { "top", "left", "right", "topleft", "topright", "bottom", "none" }
        local coreCogButtons = {}
        local function RefreshAllSlots()
            RefreshAllAuras()
            for _, plate in pairs(plates) do
                local spacing = ns.GetAuraSpacing()
                local ds, bs, cs = ns.GetAuraSlots()
                if bs ~= "none" then
                    local buffSz = ns.GetBuffIconSize()
                    local bxOff, byOff = ns.GetSlotOffsets(bs)
                    ns.PositionAuraSlot(plate.buffs, 4, bs, plate, buffSz, buffSz, spacing, bxOff, byOff)
                else
                    for i = 1, 4 do plate.buffs[i]:Hide() end
                end
                if cs ~= "none" then
                    local ccSz = ns.GetCCIconSize()
                    local cxOff, cyOff = ns.GetSlotOffsets(cs)
                    ns.PositionAuraSlot(plate.cc, 2, cs, plate, ccSz, ccSz, spacing, cxOff, cyOff)
                else
                    for i = 1, 2 do plate.cc[i]:Hide() end
                end
                if ds == "none" then
                    for i = 1, 4 do plate.debuffs[i]:Hide() end
                end
                plate:UpdateRaidIcon()
                plate:UpdateClassification()
            end
            UpdatePreview()
            if RefreshCoreEyes then RefreshCoreEyes() end
            if RefreshCoreCogStates then RefreshCoreCogStates() end
        end

        -----------------------------------------------------------------------
        --  Helpers for position-swapping dropdowns
        -----------------------------------------------------------------------

        -- Exclusive slot assignment for the new Core Text Positions system.
        local textSlotKeys = ns.textSlotKeys
        local function SetTextElementAtSlot(slotKey, element)
            local db = DB()
            if element ~= "none" then
                for _, key in ipairs(textSlotKeys) do
                    if key ~= slotKey and (db[key] or defaults[key]) == element then
                        db[key] = "none"
                    end
                end
            end
            db[slotKey] = element
        end

        local timerPosValues = {
            ["topleft"]  = "Top Left",
            ["center"]   = "Center",
            ["topright"] = "Top Right",
            ["none"]     = "None",
        }
        local timerPosOrder = { "topleft", "center", "topright", "none" }

        -- Shared helper: apply a timer position to live plates for one aura type
        local function LiveApplyTimerPos(auraFrames, count, v)
            local durC = (DB() and DB().auraDurationTextColor) or defaults.auraDurationTextColor
            local durSz = DBVal("auraDurationTextSize") or defaults.auraDurationTextSize
            for _, plate in pairs(plates) do
                for i = 1, count do
                    local af = auraFrames(plate, i)
                    if af and af.cd then
                        if v == "none" then
                            if af.cd.SetHideCountdownNumbers then
                                af.cd:SetHideCountdownNumbers(true)
                            end
                        else
                            if af.cd.SetHideCountdownNumbers then
                                af.cd:SetHideCountdownNumbers(false)
                            end
                            if af.cd.text then
                                SetFSFont(af.cd.text, durSz, "OUTLINE")
                                af.cd.text:SetTextColor(durC.r, durC.g, durC.b, 1)
                                af.cd.text:ClearAllPoints()
                                if v == "center" then
                                    af.cd.text:SetPoint("CENTER", af, "CENTER", 0, 0)
                                    af.cd.text:SetJustifyH("CENTER")
                                elseif v == "topright" then
                                    PP.Point(af.cd.text, "TOPRIGHT", af, "TOPRIGHT", 3, 4)
                                    af.cd.text:SetJustifyH("RIGHT")
                                else
                                    PP.Point(af.cd.text, "TOPLEFT", af, "TOPLEFT", -3, 4)
                                    af.cd.text:SetJustifyH("LEFT")
                                end
                            end
                        end
                    end
                end
            end
        end

        local atFallback = DBVal("auraTextPosition") or DBVal("debuffTextPosition") or defaults.auraTextPosition

        -----------------------------------------------------------------------
        --  STYLE
        -----------------------------------------------------------------------
        local styleHeader
        styleHeader, h = W:SectionHeader(parent, "STYLE", y); y = y - h

        local function RefreshTargetIndicators()
            for _, plate in pairs(plates) do
                if ns.RefreshTargetIndicatorTextures then
                    ns.RefreshTargetIndicatorTextures(plate)
                end
                plate:ApplyTarget()
                if plate.UpdateAuras then plate:UpdateAuras() end
            end
            for _, plate in pairs(ns.friendlyPlates or {}) do
                if ns.RefreshTargetIndicatorTextures then
                    ns.RefreshTargetIndicatorTextures(plate)
                end
                if plate.ApplyTarget then plate:ApplyTarget() end
            end
            UpdatePreview()
        end

        local targetIndicatorValues = {}
        local targetIndicatorOrder = ns.targetIndicatorOrder or { "arrows" }
        for _, key in ipairs(targetIndicatorOrder) do
            local info = ns.targetIndicatorStyles and ns.targetIndicatorStyles[key]
            if info and info.label then
                targetIndicatorValues[key] = info.label
            end
        end
        if not next(targetIndicatorValues) then
            targetIndicatorValues.arrows = "Arrows"
            targetIndicatorOrder = { "arrows" }
        end

        local targetGlowRow
        local targetIndicatorRow
        targetGlowRow, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Target Glow Style"),
                values = { kullthranui = "KT", vibrant = "Vibrant", none = "None" },
                getValue = function()
                    if ns.GetTargetGlowStyle then return ns.GetTargetGlowStyle() end
                    return DBVal("targetGlowStyle") or defaults.targetGlowStyle
                end,
                setValue = function(v)
                    DB().targetGlowStyle = v
                    for _, plate in pairs(plates) do plate:ApplyTarget() end
                    UpdatePreview()
                    if targetGlowRow and targetGlowRow._refreshGlowColor then
                        targetGlowRow._refreshGlowColor()
                    end
                end,
                order = { "kullthranui", "vibrant", "none" }
            },
            {
                type = "toggle",
                text = LText("Show Target Indicator"),
                getValue = function() return DBVal("showTargetArrows") == true end,
                setValue = function(v)
                    DB().showTargetArrows = v
                    RefreshTargetIndicators()
                end
            }); y = y - h

        -- Color del halo de target, compartido por KT y Vibrant.
        do
            local leftRgn = targetGlowRow._leftRegion
            local function TargetGlowColorGet()
                local color = (DB() and DB().targetGlowColor) or defaults.targetGlowColor
                    or { r = 0.4117, g = 0.6667, b = 1.0 }
                return color.r or color[1], color.g or color[2], color.b or color[3]
            end
            local function TargetGlowColorSet(r, g, b)
                DB().targetGlowColor = { r = r, g = g, b = b }
                for _, plate in pairs(plates) do plate:ApplyTarget() end
                UpdatePreview()
            end
            local swatch, updateSwatch = KT_BuildColorSwatch(
                leftRgn, leftRgn:GetFrameLevel() + 5,
                TargetGlowColorGet, TargetGlowColorSet, nil, 20
            )
            AttachInlineWidget(leftRgn, swatch)
            local function RefreshTargetGlowSwatch()
                local disabled = (DBVal("targetGlowStyle") or defaults.targetGlowStyle) == "none"
                swatch:SetAlpha(disabled and 0.2 or 1)
                swatch:EnableMouse(not disabled)
                updateSwatch()
            end
            targetGlowRow._refreshGlowColor = RefreshTargetGlowSwatch
            KT_RegisterWidgetRefresh(RefreshTargetGlowSwatch)
            RefreshTargetGlowSwatch()
        end

        targetIndicatorRow, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Target Indicator Style"),
                values = targetIndicatorValues,
                getValue = function()
                    if ns.GetTargetIndicatorStyle then return ns.GetTargetIndicatorStyle() end
                    return DBVal("targetIndicatorStyle") or defaults.targetIndicatorStyle or "arrows"
                end,
                setValue = function(v)
                    DB().targetIndicatorStyle = v
                    RefreshTargetIndicators()
                end,
                order = targetIndicatorOrder,
                preview = {
                    kind = "texture",
                    selectedWidth = 20,
                    selectedHeight = 20,
                    itemWidth = 18,
                    itemHeight = 18,
                    resolve = function(styleKey)
                        if ns.GetTargetIndicatorPreviewTexture then
                            return ns.GetTargetIndicatorPreviewTexture(styleKey)
                        end
                        local info = ns.targetIndicatorStyles and ns.targetIndicatorStyles[styleKey]
                        return info and (info.preview or info.right or info.texture or info.left) or nil
                    end,
                },
            },
            {
                type = "slider",
                text = LText("Target Indicator Scale"),
                min = 0.5,
                max = 3.0,
                step = 0.1,
                getValue = function() return DBVal("targetArrowScale") or defaults.targetArrowScale or 1.0 end,
                setValue = function(v)
                    DB().targetArrowScale = v
                    RefreshTargetIndicators()
                end
            }); y = y - h

        local targetIndicatorEffectsRow
        targetIndicatorEffectsRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Reverse Indicator Direction"),
                getValue = function()
                    local currentDB = DB()
                    if currentDB and currentDB.targetIndicatorReversed ~= nil then
                        return currentDB.targetIndicatorReversed
                    end
                    return defaults.targetIndicatorReversed == true
                end,
                setValue = function(v)
                    DB().targetIndicatorReversed = v
                    RefreshTargetIndicators()
                end
            },
            {
                type = "toggle",
                text = LText("Indicator Shadow Glow"),
                getValue = function()
                    local currentDB = DB()
                    if currentDB and currentDB.targetIndicatorGlow ~= nil then
                        return currentDB.targetIndicatorGlow
                    end
                    return defaults.targetIndicatorGlow == true
                end,
                setValue = function(v)
                    DB().targetIndicatorGlow = v
                    RefreshTargetIndicators()
                    KT:RefreshPage()
                end
            }); y = y - h

        -- Keep the glow color beside its toggle without crossing columns.
        do
            local rightRgn = targetIndicatorEffectsRow._rightRegion
            local function GlowDisabled()
                local currentDB = DB()
                if currentDB and currentDB.targetIndicatorGlow ~= nil then
                    return not currentDB.targetIndicatorGlow
                end
                return defaults.targetIndicatorGlow ~= true
            end
            local function GlowColorGet()
                local color = (DB() and DB().targetIndicatorGlowColor) or defaults.targetIndicatorGlowColor
                return color.r, color.g, color.b
            end
            local function GlowColorSet(r, g, b)
                DB().targetIndicatorGlowColor = { r = r, g = g, b = b }
                RefreshTargetIndicators()
            end
            local swatch, updateSwatch = KT_BuildColorSwatch(rightRgn, rightRgn:GetFrameLevel() + 5,
                GlowColorGet, GlowColorSet, nil, 20)
            AttachInlineWidget(rightRgn, swatch)
            local function RefreshGlowSwatch()
                local disabled = GlowDisabled()
                swatch:SetAlpha(disabled and 0.15 or 1)
                swatch:EnableMouse(not disabled)
                updateSwatch()
            end
            KT_RegisterWidgetRefresh(RefreshGlowSwatch)
            RefreshGlowSwatch()
        end

        -- Eye icon to the left of the Target Glow Style dropdown to toggle glow on preview
        do
            local ICON_ON  = "Interface\\RaidFrame\\ReadyCheck-Ready"
            local ICON_OFF = "Interface\\RaidFrame\\ReadyCheck-NotReady"
            local leftRgn       = targetGlowRow._leftRegion
            local eyeBtn        = CreateFrame("Button", nil, leftRgn)
            eyeBtn:SetSize(26, 26)
            eyeBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 5)
            eyeBtn:SetAlpha(0.4)
            local eyeTex = eyeBtn:CreateTexture(nil, "OVERLAY")
            eyeTex:SetAllPoints()
            ApplyNPAccentToIcon(eyeTex)
            AttachInlineWidget(leftRgn, eyeBtn)
            local function RefreshTargetGlowEye()
                eyeTex:SetTexture(showTargetGlowPreview and ICON_ON or ICON_OFF)
            end
            RefreshTargetGlowEye()
            eyeBtn:SetScript("OnClick", function()
                showTargetGlowPreview = not showTargetGlowPreview
                RefreshTargetGlowEye()
                UpdatePreview()
            end)
            eyeBtn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
            eyeBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
        end

        local function RefreshAllTextures()
            ns.RefreshAllSettings()
            for _, plate in pairs(ns.friendlyPlates or {}) do
                if ns.ApplyHealthBarTexture then ns.ApplyHealthBarTexture(plate) end
            end
        end

        local borderStyleRow
        borderStyleRow, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Border Style"),
                values = { kullthranui = "KT", simple = "Simple", none = "None" },
                getValue = function() return DBVal("borderStyle") or defaults.borderStyle end,
                setValue = function(v)
                    DB().borderStyle = v
                    ns.RefreshBorderStyle()
                    UpdatePreview()
                    for _, prev in ipairs(_ktnpColorPreviews or {}) do
                        if prev.RefreshBorderStyle then prev:RefreshBorderStyle() end
                    end
                    KT:RefreshPage()
                end,
                order = { "kullthranui", "simple", "none" }
            },
            nil); y = y - h

        -- Inline color swatch next to the Border Style dropdown
        do
            local leftRgn = borderStyleRow._leftRegion
            local borderColorGet = function()
                local c = (DB() and DB().borderColor) or defaults.borderColor
                return c.r, c.g, c.b
            end
            local borderColorSet = function(r, g, b)
                DB().borderColor = { r = r, g = g, b = b }
                ns.RefreshBorderColor()
                UpdatePreview()
                for _, prev in ipairs(_ktnpColorPreviews or {}) do
                    if prev.RefreshBorderColor then prev:RefreshBorderColor() end
                end
            end
            local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5,
                borderColorGet, borderColorSet, nil, 20)
            AttachInlineWidget(leftRgn, swatch)
            -- Disabled state when border style is "none"
            KT_RegisterWidgetRefresh(function()
                local off = isBorderNone()
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            local off = isBorderNone()
            swatch:SetAlpha(off and 0.15 or 1)
            swatch:EnableMouse(not off)
        end

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  CORE POSITIONS
        -----------------------------------------------------------------------
        local coreHeader
        coreHeader, h = W:SectionHeader(parent, "CORE POSITIONS", y); y = y - h

        -- Subtitle hint next to the section header
        do
            local regions = { coreHeader:GetRegions() }
            for _, rgn in ipairs(regions) do
                if rgn:IsObjectType("FontString") and rgn:GetText() == "CORE POSITIONS" then
                    local sub = coreHeader:CreateFontString(nil, "OVERLAY")
                    sub:SetFont(rgn:GetFont())
                    sub:SetTextColor(1, 1, 1, 0.25)
                    sub:SetText(LText("(dropdown = side, cog = offset/size)"))
                    sub:SetPoint("LEFT", rgn, "RIGHT", 6, 0)
                    break
                end
            end
        end

        local coreElementValues = {
            debuffs        = "Debuffs",
            buffs          = "Buffs",
            ccs            = "CCs",
            raidmarker     = "Raid Marker",
            classification = "Elite/Rare Indicator",
            none           = "None",
        }
        local coreElementOrder = { "debuffs", "buffs", "ccs", "raidmarker", "classification", "none" }

        local coreRow1, coreRow2, coreRow3
        local _refreshRaidMarkerEyePos
        local _refreshClassificationEyePos

        RefreshCoreEyes = function()
            if _refreshRaidMarkerEyePos then _refreshRaidMarkerEyePos() end
            if _refreshClassificationEyePos then _refreshClassificationEyePos() end
        end

        -- Map element name to XY offset key prefix (legacy, kept for reference)
        -- Now using slot-based offsets: pos .. "SlotXOffset" / "SlotYOffset"

        local function CorePosXGet(pos)
            return DBVal(pos .. "SlotXOffset") or 0
        end
        local function CorePosYGet(pos)
            return DBVal(pos .. "SlotYOffset") or 0
        end
        local function CorePosXSet(pos, v)
            DB()[pos .. "SlotXOffset"] = v
            RefreshAllSlots()
        end
        local function CorePosYSet(pos, v)
            DB()[pos .. "SlotYOffset"] = v
            RefreshAllSlots()
        end
        local function CorePosOffDisabled(pos)
            return GetElementAtPosition(pos) == "none"
        end

        -------------------------------------------------------------------
        --  Icon Position Slider Popup  (singleton, slide-up animation)
        -------------------------------------------------------------------
        -------------------------------------------------------------------
        --  Combined Settings Popup  (singleton, slide-up, pos + optional size)
        -------------------------------------------------------------------
        local cogPopup      -- the popup frame (created once)
        local cogPopupOwner -- which cog icon currently owns the popup

        local COGS_ICON = (KT and KT.RESIZE_ICON) or "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png"

        -- opts = { title, xGet, xSet, yGet, ySet, sizeGet, sizeSet, sizeMin, sizeMax, sizeStep, sizeLabel }
        -- sizeGet may be nil no size row shown
        local function ShowCogPopup(anchorBtn, opts)
            if not cogPopup then
                local SolidTex         = KT.SolidTex
                local MakeBorder       = KT.MakeBorder
                local MakeFont         = KT.MakeFont
                local BuildSliderCore  = KT.BuildSliderCore
                local BORDER_COLOR     = KT.NP_BORDER_COLOR
                local SL_INPUT_A       = KT.NP_SL_INPUT_A

                local SIDE_PAD         = 14
                local INPUT_W          = 34; local SLIDER_INPUT_GAP = 8; local LABEL_SLIDER_GAP = 12
                local TOP_PAD          = 14
                local TITLE_H          = 11
                local TITLE_GAP        = 10
                local GAP              = 10
                local SLIDER_H         = 24

                -- Max height: title + X + Y + Size = 4 rows
                local MAX_H            = TOP_PAD + TITLE_H + TITLE_GAP + GAP + SLIDER_H + GAP + SLIDER_H + GAP + SLIDER_H +
                TOP_PAD

                local pf               = CreateFrame("Frame", nil, KT.MenuPrincipal or UIParent)
                pf:SetSize(260, MAX_H)
                pf:SetFrameStrata("FULLSCREEN_DIALOG")
                pf:SetFrameLevel(math.max(1200, (KT.MenuPrincipal and KT.MenuPrincipal:GetFrameLevel() or 0) + 80))
                pf:SetClampedToScreen(true)
                pf:EnableMouse(true)
                pf:Hide()

                local bg = SolidTex(pf, "BACKGROUND", 0.06, 0.08, 0.10, 0.95)
                bg:SetAllPoints()
                MakeBorder(pf, BORDER_COLOR.r, BORDER_COLOR.g, BORDER_COLOR.b, 0.15)

                local titleFS = MakeFont(pf, 11, "", 1, 1, 1)
                titleFS:SetAlpha(0.7)
                titleFS:SetPoint("TOP", pf, "TOP", 0, -TOP_PAD)
                pf._titleFS = titleFS

                -- Measure label widths to compute layout BEFORE creating sliders
                local tmpFS = pf:CreateFontString(nil, "OVERLAY")
                tmpFS:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, GetNPOptOutline())
                local labelTexts = { "X", "Y", "Size" }
                local maxLblW = 0
                for _, txt in ipairs(labelTexts) do
                    tmpFS:SetText(txt)
                    local w = tmpFS:GetStringWidth()
                    if w > maxLblW then maxLblW = w end
                end
                tmpFS:Hide()
                if maxLblW < 10 then maxLblW = 28 end

                local SLIDER_LEFT = SIDE_PAD + maxLblW + LABEL_SLIDER_GAP
                local SLIDER_W = math.max(80, 260 - SLIDER_LEFT - SLIDER_INPUT_GAP - INPUT_W - SIDE_PAD)
                local POPUP_W = SLIDER_LEFT + SLIDER_W + SLIDER_INPUT_GAP + INPUT_W + SIDE_PAD
                if POPUP_W < 180 then POPUP_W = 180 end
                pf:SetSize(POPUP_W, pf:GetHeight())

                -- X slider row
                local X_ROW_Y = -(TOP_PAD + TITLE_H + TITLE_GAP + GAP)
                local xLabel = MakeFont(pf, 12, nil, 1, 1, 1)
                xLabel:SetAlpha(0.6); xLabel:SetText("X")
                xLabel:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, X_ROW_Y)
                local xTrack, xValBox = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, SLIDER_H, 11, SL_INPUT_A,
                    -80, 80, 1,
                    function() return pf._xGet and pf._xGet() or 0 end,
                    function(v) if pf._xSet then pf._xSet(v) end end, true)
                xTrack:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, X_ROW_Y - 2)
                xValBox:ClearAllPoints(); xValBox:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, X_ROW_Y)

                pf._xTrack = xTrack; pf._xValBox = xValBox

                -- Y slider row
                local Y_ROW_Y = X_ROW_Y - SLIDER_H - GAP
                local yLabel = MakeFont(pf, 12, nil, 1, 1, 1)
                yLabel:SetAlpha(0.6); yLabel:SetText("Y")
                yLabel:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, Y_ROW_Y)
                local yTrack, yValBox = BuildSliderCore(pf, SLIDER_W, 4, 12, INPUT_W, SLIDER_H, 11, SL_INPUT_A,
                    -80, 80, 1,
                    function() return pf._yGet and pf._yGet() or 0 end,
                    function(v) if pf._ySet then pf._ySet(v) end end, true)
                yTrack:SetPoint("TOPLEFT", pf, "TOPLEFT", SLIDER_LEFT, Y_ROW_Y - 2)
                yValBox:ClearAllPoints(); yValBox:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -SIDE_PAD, Y_ROW_Y)

                pf._yTrack = yTrack; pf._yValBox = yValBox

                -- Size slider row (hidden when not needed)
                local S_ROW_Y = Y_ROW_Y - SLIDER_H - GAP
                local sLabel = MakeFont(pf, 12, nil, 1, 1, 1)
                sLabel:SetAlpha(0.6); sLabel:SetText(LText("Size"))
                sLabel:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, S_ROW_Y)
                pf._sLabel = sLabel

                -- Store layout values for dynamic size slider rebuild
                pf._SLIDER_LEFT = SLIDER_LEFT
                pf._SLIDER_W = SLIDER_W
                pf._S_ROW_Y = S_ROW_Y

                -- Growth direction row (shown only for topleft/topright slots)
                local GROWTH_ROW_H = 22
                local G_ROW_Y = S_ROW_Y - SLIDER_H - GAP
                pf._G_ROW_Y = G_ROW_Y
                pf._GROWTH_ROW_H = GROWTH_ROW_H

                local gLabel = MakeFont(pf, 12, nil, 1, 1, 1)
                gLabel:SetAlpha(0.6); gLabel:SetText(LText("Grow"))
                gLabel:SetPoint("TOPLEFT", pf, "TOPLEFT", SIDE_PAD, G_ROW_Y)
                pf._gLabel = gLabel

                -- Three small radio buttons: values filled in at show time
                local gBtns = {}
                local BTN_W, BTN_H, BTN_GAP = 52, 20, 4
                for bi = 1, 3 do
                    local b = CreateFrame("Button", nil, pf)
                    b:SetSize(BTN_W, BTN_H)
                    b:SetPoint("TOPLEFT", pf, "TOPLEFT",
                        SLIDER_LEFT + (bi - 1) * (BTN_W + BTN_GAP),
                        G_ROW_Y - 1)
                    local bg = b:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
                    b._bg = bg
                    local hl = b:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(1, 1, 1, 0.06)
                    local lbl = b:CreateFontString(nil, "OVERLAY")
                    lbl:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, GetNPOptOutline())
                    lbl:SetAllPoints()
                    lbl:SetJustifyH("CENTER")
                    lbl:SetJustifyV("MIDDLE")
                    b._lbl = lbl
                    b:SetScript("OnClick", function(self)
                        if pf._growthSet then pf._growthSet(self._value) end
                        -- Refresh button states
                        local cur = pf._growthGet and pf._growthGet() or ""
                        for _, gb in ipairs(gBtns) do
                            local active = (gb._value == cur)
                            gb._bg:SetColorTexture(
                                active and 0.973 or 0.15,
                                active and 0.839 or 0.15,
                                active and 0.604 or 0.15,
                                active and 0.25 or 0.8)
                            gb._lbl:SetTextColor(active and 1 or 0.7, active and 1 or 0.7, active and 1 or 0.7)
                        end
                    end)
                    gBtns[bi] = b
                end
                pf._gBtns = gBtns

                -- Layout constants stored for height calc
                pf._TOP_PAD = TOP_PAD; pf._TITLE_H = TITLE_H; pf._TITLE_GAP = TITLE_GAP
                pf._GAP = GAP; pf._SLIDER_H = SLIDER_H; pf._SIDE_PAD = SIDE_PAD
                pf._POPUP_W = POPUP_W

                -- Close on click outside
                local wasDown = false
                pf._clickOutside = function(self, dt)
                    local down = IsMouseButtonDown("LeftButton")
                    if down and not wasDown then
                        if not self:IsMouseOver() and not (cogPopupOwner and cogPopupOwner:IsMouseOver()) then
                            self:Hide()
                        end
                    end
                    wasDown = down
                end

                pf:SetScript("OnHide", function(self)
                    self:SetScript("OnUpdate", nil)
                    local closingOwner = cogPopupOwner
                    if closingOwner then closingOwner:SetAlpha(0.4) end
                    cogPopupOwner = nil
                    if RefreshCoreCogStates then RefreshCoreCogStates() end
                    if closingOwner and closingOwner._updateCogHighlight then
                        closingOwner._updateCogHighlight()
                    end
                end)

                if KT.MenuPrincipal then
                    KT.MenuPrincipal:HookScript("OnHide", function()
                        if pf:IsShown() then pf:Hide() end
                    end)
                end

                cogPopup = pf
            end

            -- Toggle off if same icon clicked again
            if cogPopupOwner == anchorBtn and cogPopup:IsShown() then
                cogPopup:Hide()
                return
            end

            -- Wire getters/setters
            cogPopup._xGet = opts.xGet; cogPopup._xSet = opts.xSet
            cogPopup._yGet = opts.yGet; cogPopup._ySet = opts.ySet
            cogPopup._titleFS:SetText(opts.title)
            if cogPopup._xTrack and cogPopup._xTrack.SetValue then
                cogPopup._xTrack:SetValue(opts.xGet() or 0)
            end
            if cogPopup._yTrack and cogPopup._yTrack.SetValue then
                cogPopup._yTrack:SetValue(opts.yGet() or 0)
            end
            cogPopupOwner = anchorBtn
            if RefreshCoreCogStates then RefreshCoreCogStates() end
            if anchorBtn._updateCogHighlight then anchorBtn._updateCogHighlight() end

            -- Show/hide size row and adjust height
            local hasSize = opts.sizeGet ~= nil
            local hasGrowth = opts.growthGet ~= nil
            if hasSize then
                -- Rebuild size slider if range changed
                local sStep = opts.sizeStep or 1
                if cogPopup._curMin ~= opts.sizeMin or cogPopup._curMax ~= opts.sizeMax or cogPopup._curStep ~= sStep then
                    if cogPopup._sTrack then
                        cogPopup._sTrack:Hide(); cogPopup._sTrack:SetParent(nil)
                    end
                    if cogPopup._sValBox then
                        cogPopup._sValBox:Hide(); cogPopup._sValBox:SetParent(nil)
                    end
                    local sTrack, sValBox = KT_BuildSliderCore(cogPopup, cogPopup._SLIDER_W, 4, 12, 34, 24, 11,
                        KT.NP_SL_INPUT_A,
                        opts.sizeMin, opts.sizeMax, sStep,
                        function() return cogPopup._sGet and cogPopup._sGet() or 0 end,
                        function(v) if cogPopup._sSet then cogPopup._sSet(v) end end, true)
                    sTrack:ClearAllPoints(); sTrack:SetPoint("TOPLEFT", cogPopup, "TOPLEFT", cogPopup._SLIDER_LEFT,
                        cogPopup._S_ROW_Y - (cogPopup._SLIDER_H - 20) / 2)
                    sValBox:ClearAllPoints(); sValBox:SetPoint("TOPRIGHT", cogPopup, "TOPRIGHT", -cogPopup._SIDE_PAD,
                        cogPopup._S_ROW_Y)
                    cogPopup._sTrack = sTrack; cogPopup._sValBox = sValBox
                    cogPopup._curMin = opts.sizeMin; cogPopup._curMax = opts.sizeMax; cogPopup._curStep = sStep
                end
                cogPopup._sGet = opts.sizeGet; cogPopup._sSet = opts.sizeSet
                if cogPopup._sTrack and cogPopup._sTrack.SetValue then
                    cogPopup._sTrack:SetValue(opts.sizeGet() or opts.sizeMin or 0)
                end
                cogPopup._sLabel:SetText(opts.sizeLabel or "Size")
                cogPopup._sLabel:Show()
                if cogPopup._sTrack then cogPopup._sTrack:Show() end
                if cogPopup._sValBox then cogPopup._sValBox:Show() end
            else
                cogPopup._sLabel:Hide()
                if cogPopup._sTrack then cogPopup._sTrack:Hide() end
                if cogPopup._sValBox then cogPopup._sValBox:Hide() end
            end

            -- Show/hide growth row
            if hasGrowth then
                cogPopup._growthGet = opts.growthGet
                cogPopup._growthSet = opts.growthSet
                local vals = opts.growthValues -- { { value, label }, ... }
                local cur = opts.growthGet()
                for bi, btn in ipairs(cogPopup._gBtns) do
                    local entry = vals and vals[bi]
                    if entry then
                        btn._value = entry.value
                        btn._lbl:SetText(entry.label)
                        local active = (entry.value == cur)
                        btn._bg:SetColorTexture(
                            active and 0.973 or 0.15,
                            active and 0.839 or 0.15,
                            active and 0.604 or 0.15,
                            active and 0.25 or 0.8)
                        btn._lbl:SetTextColor(active and 1 or 0.7, active and 1 or 0.7, active and 1 or 0.7)
                        btn:Show()
                    else
                        btn:Hide()
                    end
                end
                cogPopup._gLabel:Show()
            else
                cogPopup._growthGet = nil
                cogPopup._growthSet = nil
                cogPopup._gLabel:Hide()
                for _, btn in ipairs(cogPopup._gBtns) do btn:Hide() end
            end

            -- Compute height based on visible rows
            do
                local p    = cogPopup
                local rowH = p._SLIDER_H
                local gap  = p._GAP
                local rows = 2 -- X + Y always present
                if hasSize then rows = rows + 1 end
                if hasGrowth then rows = rows + 1 end
                local h = p._TOP_PAD + p._TITLE_H + p._TITLE_GAP
                for r = 1, rows do
                    h = h + gap + (r < rows and rowH or p._GROWTH_ROW_H)
                end
                -- last row uses GROWTH_ROW_H only if growth is the last row
                -- recalculate cleanly
                h = p._TOP_PAD + p._TITLE_H + p._TITLE_GAP
                    + gap + rowH -- X
                    + gap + rowH -- Y
                if hasSize then h = h + gap + rowH end
                if hasGrowth then h = h + gap + p._GROWTH_ROW_H end
                h = h + p._TOP_PAD
                cogPopup:SetHeight(h)
            end

            -- Anchor above the icon
            cogPopup:ClearAllPoints()
            cogPopup:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 6)

            -- Slide-up animation
            cogPopup:SetAlpha(0)
            cogPopup:Show()
            local elapsed = 0
            local ANIM_DUR = 0.15
            cogPopup:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                local t = math.min(elapsed / ANIM_DUR, 1)
                self:SetAlpha(t)
                self:ClearAllPoints()
                self:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 6 + (-8 * (1 - t)))
                if t >= 1 then
                    self:SetScript("OnUpdate", self._clickOutside)
                end
            end)
        end

        local DISABLED_TIP = "This option requires an aura or indicator to be assigned"

        local function MakeCogIcon(row, regionKey, posKey, slotLabel)
            local rgn = row[regionKey]
            local btn = CreateFrame("Button", nil, rgn)
            btn:SetSize(26, 26)
            btn:SetFrameLevel(rgn:GetFrameLevel() + 5)
            btn:SetAlpha(0.4)
            btn._corePosKey = posKey
            local tex = btn:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetTexture(COGS_ICON)
            ApplyNPAccentToIcon(tex)

            -- A short accent underline keeps the small position cog visible
            -- without covering the dropdown or changing its hit area.
            local cogHighlight = rgn:CreateTexture(nil, "ARTWORK")
            cogHighlight:SetSize(26, 2)
            cogHighlight:SetPoint("TOP", btn, "BOTTOM", 0, -2)
            if KT.SetAccentTexture then
                KT:SetAccentTexture(cogHighlight, 0.65)
            else
                cogHighlight:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, 0.65)
            end
            btn._cogHighlight = cogHighlight

            -- Keep the search-style accent pulse confined to the cog itself.
            local cogSearchHighlight = rgn:CreateTexture(nil, 'BACKGROUND', nil, -7)
            cogSearchHighlight:SetPoint('TOPLEFT', btn, 'TOPLEFT', 0, 0)
            cogSearchHighlight:SetPoint('BOTTOMRIGHT', btn, 'BOTTOMRIGHT', 0, 0)
            cogSearchHighlight:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, 0.16)
            local cogSearchPulse = cogSearchHighlight:CreateAnimationGroup()
            cogSearchPulse:SetLooping('BOUNCE')
            local cogSearchFade = cogSearchPulse:CreateAnimation('Alpha')
            cogSearchFade:SetFromAlpha(0.45)
            cogSearchFade:SetToAlpha(1)
            cogSearchFade:SetDuration(0.7)
            cogSearchHighlight._ktPulse = cogSearchPulse
            cogHighlight:Hide()
            local function UpdateCogSearchHighlight()
                local disabled = CorePosOffDisabled(posKey)
                if disabled then
                    cogSearchHighlight:Hide()
                    if cogSearchPulse:IsPlaying() then cogSearchPulse:Stop() end
                    return
                end
                if KT.SetAccentTexture then
                    KT:SetAccentTexture(cogSearchHighlight, 0.16)
                else
                    cogSearchHighlight:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, 0.16)
                end
                cogSearchHighlight:Show()
                if not cogSearchPulse:IsPlaying() then cogSearchPulse:Play() end
            end

            local function UpdateCogHighlight()
                local off = CorePosOffDisabled(posKey)
                local alpha = off and 0.12 or (cogPopupOwner == btn and 1 or 0.65)
                if KT.SetAccentTexture then
                    KT:SetAccentTexture(cogHighlight, alpha)
                else
                    cogHighlight:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, alpha)
                end
            end
            btn._updateCogHighlight = UpdateCogHighlight
            local _updateCogHighlight = UpdateCogHighlight
            UpdateCogHighlight = function()
                _updateCogHighlight()
                UpdateCogSearchHighlight()
            end
            btn._updateCogHighlight = UpdateCogHighlight
            UpdateCogSearchHighlight()

            AttachInlineWidget(rgn, btn)
            btn:SetScript("OnEnter", function(self)
                if CorePosOffDisabled(posKey) then
                    KT_ShowWidgetTooltip(self, DISABLED_TIP)
                else
                    self:SetAlpha(0.7)
                end
                UpdateCogHighlight()
            end)
            btn:SetScript("OnLeave", function(self)
                KT_HideWidgetTooltip()
                if cogPopupOwner ~= self then self:SetAlpha(CorePosOffDisabled(posKey) and 0.15 or 0.4) end
                UpdateCogHighlight()
            end)
            btn:SetScript("OnClick", function(self)
                if CorePosOffDisabled(posKey) then return end
                local sizeKey = posKey .. "SlotSize"
                local growthKey = posKey .. "SlotGrowth"
                local growthValues
                if posKey == "topleft" then
                    growthValues = {
                        { value = "left",  label = "Left" },
                        { value = "right", label = "Right" },
                        { value = "up",    label = "Up" },
                    }
                elseif posKey == "topright" then
                    growthValues = {
                        { value = "right", label = "Right" },
                        { value = "left",  label = "Left" },
                        { value = "up",    label = "Up" },
                    }
                end
                local opts = {
                    title = slotLabel .. " Slot Settings",
                    xGet = function() return CorePosXGet(posKey) end,
                    xSet = function(v) CorePosXSet(posKey, v) end,
                    yGet = function() return CorePosYGet(posKey) end,
                    ySet = function(v) CorePosYSet(posKey, v) end,
                    sizeGet = function() return DBVal(sizeKey) or defaults[sizeKey] end,
                    sizeSet = function(v)
                        DB()[sizeKey] = v; RefreshAllSlots(); UpdatePreview()
                    end,
                    sizeMin = 10,
                    sizeMax = 50,
                }
                if growthValues then
                    opts.growthGet    = function() return DBVal(growthKey) or defaults[growthKey] end
                    opts.growthSet    = function(v)
                        DB()[growthKey] = v; RefreshAllSlots(); UpdatePreview()
                    end
                    opts.growthValues = growthValues
                end
                ShowCogPopup(self, opts)
                UpdateCogHighlight()
            end)
            coreCogButtons[#coreCogButtons + 1] = btn
            KT_RegisterWidgetRefresh(function()
                local off = CorePosOffDisabled(posKey)
                btn:SetAlpha(off and 0.15 or (cogPopupOwner == btn and 0.7 or 0.4))
                UpdateCogHighlight()
            end)
            if CorePosOffDisabled(posKey) then btn:SetAlpha(0.15) end
            UpdateCogHighlight()
            return btn
        end

        RefreshCoreCogStates = function()
            for _, btn in ipairs(coreCogButtons) do
                if btn and btn._corePosKey then
                    local off = CorePosOffDisabled(btn._corePosKey)
                    if off and cogPopupOwner == btn and cogPopup and cogPopup:IsShown() then
                        cogPopup:Hide()
                    end
                    btn:SetAlpha(off and 0.15 or (cogPopupOwner == btn and 0.7 or 0.4))
                    if btn._updateCogHighlight then btn._updateCogHighlight() end
                end
            end
        end

        parent._showRowDivider = true

        -- Row 1: Top | Right
        coreRow1, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Top"),
                values = coreElementValues,
                order = coreElementOrder,
                getValue = function() return GetElementAtPosition("top") end,
                setValue = function(v)
                    SetElementAtPosition("top", v); RefreshAllSlots(); RefreshCoreEyes()
                end
            },
            {
                type = "dropdown",
                text = LText("Right"),
                values = coreElementValues,
                order = coreElementOrder,
                getValue = function() return GetElementAtPosition("right") end,
                setValue = function(v)
                    SetElementAtPosition("right", v); RefreshAllSlots(); RefreshCoreEyes()
                end
            }); y = y - h
        MakeCogIcon(coreRow1, "_leftRegion", "top", "Top")
        MakeCogIcon(coreRow1, "_rightRegion", "right", "Right")

        -- Row 2: Left | Top Right
        coreRow2, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Left"),
                values = coreElementValues,
                order = coreElementOrder,
                getValue = function() return GetElementAtPosition("left") end,
                setValue = function(v)
                    SetElementAtPosition("left", v); RefreshAllSlots(); RefreshCoreEyes()
                end
            },
            {
                type = "dropdown",
                text = LText("Top Right"),
                values = coreElementValues,
                order = coreElementOrder,
                getValue = function() return GetElementAtPosition("topright") end,
                setValue = function(v)
                    SetElementAtPosition("topright", v); RefreshAllSlots(); RefreshCoreEyes()
                end
            }); y = y - h
        MakeCogIcon(coreRow2, "_leftRegion", "left", "Left")
        MakeCogIcon(coreRow2, "_rightRegion", "topright", "Top Right")

        -- Row 3: Top Left | Bottom
        coreRow3, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Top Left"),
                values = coreElementValues,
                order = coreElementOrder,
                getValue = function() return GetElementAtPosition("topleft") end,
                setValue = function(v)
                    SetElementAtPosition("topleft", v); RefreshAllSlots(); RefreshCoreEyes()
                end
            },
            {
                type = "dropdown",
                text = LText("Bottom"),
                values = coreElementValues,
                order = coreElementOrder,
                getValue = function() return GetElementAtPosition("bottom") end,
                setValue = function(v)
                    SetElementAtPosition("bottom", v); RefreshAllSlots(); RefreshCoreEyes()
                end
            }); y = y - h
        MakeCogIcon(coreRow3, "_leftRegion", "topleft", "Top Left")
        MakeCogIcon(coreRow3, "_rightRegion", "bottom", "Bottom")

        -- Map each position to { row, regionKey } for eye icon anchoring
        local posToRegion = {
            top      = { coreRow1, "_leftRegion" },
            right    = { coreRow1, "_rightRegion" },
            left     = { coreRow2, "_leftRegion" },
            topright = { coreRow2, "_rightRegion" },
            topleft  = { coreRow3, "_leftRegion" },
            bottom   = { coreRow3, "_rightRegion" },
        }

        -- Eye icon that follows whichever Core Positions dropdown has "Raid Marker"
        do
            local ICON_ON  = "Interface\\RaidFrame\\ReadyCheck-Ready"
            local ICON_OFF = "Interface\\RaidFrame\\ReadyCheck-NotReady"
            local eyeBtn        = CreateFrame("Button", nil, parent)
            eyeBtn:SetSize(26, 26)
            eyeBtn:SetFrameLevel(parent:GetFrameLevel() + 10)
            eyeBtn:SetAlpha(0.4)
            local eyeTex = eyeBtn:CreateTexture(nil, "OVERLAY")
            eyeTex:SetAllPoints()
            ApplyNPAccentToIcon(eyeTex)
            local function RefreshIcon()
                eyeTex:SetTexture(showRaidMarkerPreview and ICON_ON or ICON_OFF)
            end
            RefreshIcon()
            eyeBtn:SetScript("OnClick", function()
                showRaidMarkerPreview = not showRaidMarkerPreview
                RefreshIcon()
                UpdatePreview()
            end)
            eyeBtn:SetScript("OnEnter", function(self)
                self:SetAlpha(0.7)
                KT_ShowWidgetTooltip(self, "Show/Hide on Preview", { width = 155 })
            end)
            eyeBtn:SetScript("OnLeave", function(self)
                self:SetAlpha(0.4)
                KT_HideWidgetTooltip()
            end)
            _refreshRaidMarkerEyePos = function()
                local rmPos = DBVal("raidMarkerPos") or defaults.raidMarkerPos
                local info = posToRegion[rmPos]
                if not info or rmPos == "none" then
                    DetachInlineWidget(eyeBtn)
                    eyeBtn:Hide()
                    return
                end
                local rgn = info[1][info[2]]
                eyeBtn:SetParent(rgn)
                eyeBtn:SetFrameLevel(rgn:GetFrameLevel() + 5)
                AttachInlineWidget(rgn, eyeBtn)
                eyeBtn:Show()
            end
            _refreshRaidMarkerEyePos()
        end

        -- Eye icon that follows whichever Core Positions dropdown has "Elite/Rare Indicator"
        do
            local ICON_ON  = "Interface\\RaidFrame\\ReadyCheck-Ready"
            local ICON_OFF = "Interface\\RaidFrame\\ReadyCheck-NotReady"
            local eyeBtn        = CreateFrame("Button", nil, parent)
            eyeBtn:SetSize(26, 26)
            eyeBtn:SetFrameLevel(parent:GetFrameLevel() + 10)
            eyeBtn:SetAlpha(0.4)
            local eyeTex = eyeBtn:CreateTexture(nil, "OVERLAY")
            eyeTex:SetAllPoints()
            ApplyNPAccentToIcon(eyeTex)
            local function RefreshIcon()
                eyeTex:SetTexture(showClassificationPreview and ICON_ON or ICON_OFF)
            end
            RefreshIcon()
            eyeBtn:SetScript("OnClick", function()
                showClassificationPreview = not showClassificationPreview
                RefreshIcon()
                UpdatePreview()
            end)
            eyeBtn:SetScript("OnEnter", function(self)
                self:SetAlpha(0.7)
                KT_ShowWidgetTooltip(self, "Show/Hide on Preview", { width = 155 })
            end)
            eyeBtn:SetScript("OnLeave", function(self)
                self:SetAlpha(0.4)
                KT_HideWidgetTooltip()
            end)
            _refreshClassificationEyePos = function()
                local clPos = DBVal("classificationSlot") or defaults.classificationSlot
                local info = posToRegion[clPos]
                if not info or clPos == "none" then
                    DetachInlineWidget(eyeBtn)
                    eyeBtn:Hide()
                    return
                end
                local rgn = info[1][info[2]]
                eyeBtn:SetParent(rgn)
                eyeBtn:SetFrameLevel(rgn:GetFrameLevel() + 5)
                AttachInlineWidget(rgn, eyeBtn)
                eyeBtn:Show()
            end
            _refreshClassificationEyePos()
        end

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  CORE TEXT POSITIONS
        -----------------------------------------------------------------------
        local coreTextHeader
        coreTextHeader, h = W:SectionHeader(parent, "CORE TEXT POSITIONS", y); y = y - h

        -- Subtitle hint next to the section header (same style as Core Positions)
        do
            local regions = { coreTextHeader:GetRegions() }
            for _, rgn in ipairs(regions) do
                if rgn:IsObjectType("FontString") and rgn:GetText() == "CORE TEXT POSITIONS" then
                    local sub = coreTextHeader:CreateFontString(nil, "OVERLAY")
                    sub:SetFont(rgn:GetFont())
                    sub:SetTextColor(1, 1, 1, 0.25)
                    sub:SetText(LText("(one per slot)"))
                    sub:SetPoint("LEFT", rgn, "RIGHT", 6, 0)
                    break
                end
            end
        end

        local textElementValues = {
            enemyName           = "Enemy Name",
            healthPercent       = "Health %",
            healthPercentNoSign = "Health % (No Sign)",
            healthNumber        = "Health #",
            healthPctNum        = "Health % | #",
            healthNumPct        = "Health # | %",
            none                = "None",
        }
        local textElementOrder = { "none", "---", "enemyName", "healthPercent", "healthPercentNoSign", "healthNumber",
            "healthPctNum", "healthNumPct" }

        local function TextSlotSetValue(slotKey, v)
            SetTextElementAtSlot(slotKey, v)
            for _, plate in pairs(plates) do
                plate:RefreshNamePosition()
                plate:UpdateHealthValues()
            end
            UpdatePreview(); KT:RefreshPage()
        end

        local function TextOffsetRefresh()
            for _, plate in pairs(plates) do
                plate:RefreshNamePosition()
                plate:UpdateHealthValues()
            end
            UpdatePreview()
        end

        -- Text slot X/Y offset helpers (parallel to CorePosXGet etc.)
        local function TextPosXGet(slotKey)
            return DBVal(slotKey .. "XOffset") or 0
        end
        local function TextPosYGet(slotKey)
            return DBVal(slotKey .. "YOffset") or 0
        end
        local function TextPosXSet(slotKey, v)
            DB()[slotKey .. "XOffset"] = v; TextOffsetRefresh()
        end
        local function TextPosYSet(slotKey, v)
            DB()[slotKey .. "YOffset"] = v; TextOffsetRefresh()
        end
        local function TextPosDisabled(slotKey)
            return DBVal(slotKey) == "none"
        end

        local TEXT_DISABLED_TIP = "This option requires a text to be assigned"

        local function MakeTextCogIcon(row, regionKey, slotKey, slotLabel)
            local rgn = row[regionKey]
            local btn = CreateFrame("Button", nil, rgn)
            btn:SetSize(26, 26)
            btn:SetFrameLevel(rgn:GetFrameLevel() + 5)
            btn:SetAlpha(0.4)
            local tex = btn:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetTexture(COGS_ICON)
            ApplyNPAccentToIcon(tex)

            -- A short accent underline keeps the small position cog visible
            -- without covering the dropdown or changing its hit area.
            local cogHighlight = rgn:CreateTexture(nil, "ARTWORK")
            cogHighlight:SetSize(26, 2)
            cogHighlight:SetPoint("TOP", btn, "BOTTOM", 0, -2)
            if KT.SetAccentTexture then
                KT:SetAccentTexture(cogHighlight, 0.65)
            else
                cogHighlight:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, 0.65)
            end
            btn._cogHighlight = cogHighlight

            cogHighlight:ClearAllPoints()
            cogHighlight:SetDrawLayer('BACKGROUND', -7)
            cogHighlight:SetPoint('TOPLEFT', btn, 'TOPLEFT', 0, 0)
            cogHighlight:SetPoint('BOTTOMRIGHT', btn, 'BOTTOMRIGHT', 0, 0)

            local cogPulse = cogHighlight:CreateAnimationGroup()
            cogPulse:SetLooping('BOUNCE')
            local cogFade = cogPulse:CreateAnimation('Alpha')
            cogFade:SetFromAlpha(0.55)
            cogFade:SetToAlpha(1)
            cogFade:SetDuration(0.7)

            local function UpdateCogHighlight()
                local off = TextPosDisabled(slotKey)
                if off then
                    cogHighlight:Hide()
                    if cogPulse:IsPlaying() then cogPulse:Stop() end
                    return
                end
                local alpha = cogPopupOwner == btn and 0.24 or 0.14
                if KT.SetAccentTexture then
                    KT:SetAccentTexture(cogHighlight, alpha)
                else
                    cogHighlight:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, alpha)
                end
                cogHighlight:Show()
                if not cogPulse:IsPlaying() then cogPulse:Play() end
            end
            btn._updateCogHighlight = UpdateCogHighlight
            UpdateCogHighlight()

            AttachInlineWidget(rgn, btn)
            btn:SetScript("OnEnter", function(self)
                if TextPosDisabled(slotKey) then
                    KT_ShowWidgetTooltip(self, TEXT_DISABLED_TIP)
                else
                    self:SetAlpha(0.7)
                end
                UpdateCogHighlight()
            end)
            btn:SetScript("OnLeave", function(self)
                KT_HideWidgetTooltip()
                if cogPopupOwner ~= self then self:SetAlpha(TextPosDisabled(slotKey) and 0.15 or 0.4) end
                UpdateCogHighlight()
            end)
            btn:SetScript("OnClick", function(self)
                if TextPosDisabled(slotKey) then return end
                local sizeKey = slotKey .. "Size"
                ShowCogPopup(self, {
                    title = slotLabel .. " Settings",
                    xGet = function() return TextPosXGet(slotKey) end,
                    xSet = function(v) TextPosXSet(slotKey, v) end,
                    yGet = function() return TextPosYGet(slotKey) end,
                    ySet = function(v) TextPosYSet(slotKey, v) end,
                    sizeGet = function() return DBVal(sizeKey) or defaults[sizeKey] end,
                    sizeSet = function(v)
                        DB()[sizeKey] = v; TextOffsetRefresh()
                    end,
                    sizeMin = 6,
                    sizeMax = 20,
                    sizeLabel = "Size",
                })
            end)
            KT_RegisterWidgetRefresh(function()
                local off = TextPosDisabled(slotKey)
                btn:SetAlpha(off and 0.15 or (cogPopupOwner == btn and 0.7 or 0.4))
                UpdateCogHighlight()
            end)
            if TextPosDisabled(slotKey) then btn:SetAlpha(0.15) end
            return btn
        end

        parent._showRowDivider = true

        local function MakeTextColorSwatch(row, regionKey, slotKey)
            local rgn = row[regionKey]
            local colorKey = slotKey .. "Color"
            local function getColor()
                local c = (DB() and DB()[colorKey]) or defaults[colorKey]
                return c.r, c.g, c.b
            end
            local function setColor(r, g, b)
                DB()[colorKey] = { r = r, g = g, b = b }
                for _, plate in pairs(plates) do
                    plate:RefreshNamePosition()
                    plate:UpdateHealthValues()
                end
                UpdatePreview()
            end
            local swatch, updateSwatch = KT_BuildColorSwatch(rgn, rgn:GetFrameLevel() + 5, getColor, setColor,
                nil, 20)
            AttachInlineWidget(rgn, swatch)
            KT_RegisterWidgetRefresh(function()
                local off = TextPosDisabled(slotKey)
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            local off = TextPosDisabled(slotKey)
            swatch:SetAlpha(off and 0.15 or 1)
            swatch:EnableMouse(not off)
            return swatch
        end

        local textRow1, textRow2

        -- Row 1: Top Text | Right Text
        textRow1, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Top Text"),
                values = textElementValues,
                getValue = function() return DBVal("textSlotTop") end,
                setValue = function(v) TextSlotSetValue("textSlotTop", v) end,
                order = textElementOrder,
                disabled = function() return DBVal("textSlotTop") == "none" end,
                disabledTooltip = "This option requires a text to be assigned",
                labelOnlyDisabled = true
            },
            {
                type = "dropdown",
                text = LText("Right Text"),
                values = textElementValues,
                getValue = function() return DBVal("textSlotRight") end,
                setValue = function(v) TextSlotSetValue("textSlotRight", v) end,
                order = textElementOrder,
                disabled = function() return DBVal("textSlotRight") == "none" end,
                disabledTooltip = "This option requires a text to be assigned",
                labelOnlyDisabled = true,
                disabledValues = function(k) if (k == "healthPctNum" or k == "healthNumPct") and DBVal("textSlotCenter") == "enemyName" then return
                        "Disabled when Enemy Name is centered on the health bar due to overlapping text" end end
            }); y = y - h
        MakeTextCogIcon(textRow1, "_leftRegion", "textSlotTop", "Top Text")
        MakeTextColorSwatch(textRow1, "_leftRegion", "textSlotTop")
        MakeTextCogIcon(textRow1, "_rightRegion", "textSlotRight", "Right Text")
        MakeTextColorSwatch(textRow1, "_rightRegion", "textSlotRight")

        -- Row 2: Left Text | Center Text
        textRow2, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Left Text"),
                values = textElementValues,
                getValue = function() return DBVal("textSlotLeft") end,
                setValue = function(v) TextSlotSetValue("textSlotLeft", v) end,
                order = textElementOrder,
                disabled = function() return DBVal("textSlotLeft") == "none" end,
                disabledTooltip = "This option requires a text to be assigned",
                labelOnlyDisabled = true,
                disabledValues = function(k) if (k == "healthPctNum" or k == "healthNumPct") and DBVal("textSlotCenter") == "enemyName" then return
                        "Disabled when Enemy Name is centered on the health bar due to overlapping text" end end
            },
            {
                type = "dropdown",
                text = LText("Center Text"),
                values = textElementValues,
                getValue = function() return DBVal("textSlotCenter") end,
                setValue = function(v) TextSlotSetValue("textSlotCenter", v) end,
                order = textElementOrder,
                disabled = function() return DBVal("textSlotCenter") == "none" end,
                disabledTooltip = "This option requires a text to be assigned",
                labelOnlyDisabled = true
            }); y = y - h
        MakeTextCogIcon(textRow2, "_leftRegion", "textSlotLeft", "Left Text")
        MakeTextColorSwatch(textRow2, "_leftRegion", "textSlotLeft")
        MakeTextCogIcon(textRow2, "_rightRegion", "textSlotCenter", "Center Text")
        MakeTextColorSwatch(textRow2, "_rightRegion", "textSlotCenter")

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  HEALTH BAR
        -----------------------------------------------------------------------
        local healthBarHeader
        healthBarHeader, h = W:SectionHeader(parent, "BARS", y); y = y - h

        local healthBarHeightRow
        healthBarHeightRow, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Health Bar Width"),
                min = BAR_W,
                max = BAR_W + 100,
                step = 1,
                getValue = function() return BAR_W + DBVal("healthBarWidth") end,
                setValue = function(v)
                    local extra = v - BAR_W
                    DB().healthBarWidth = extra
                    for _, plate in pairs(plates) do
                        PP.Width(plate.health, v)
                        PP.Width(plate.absorb, v)
                        PP.Width(plate.cast, v)
                        plate:UpdateNameWidth()
                    end
                    if ns.ApplyNamePlateClickArea then ns.ApplyNamePlateClickArea() end
                    UpdatePreview()
                end
            },
            {
                type = "slider",
                text = LText("Health Bar Height"),
                min = 6,
                max = 45,
                step = 1,
                getValue = function() return DBVal("healthBarHeight") end,
                setValue = function(v)
                    DB().healthBarHeight = v
                    for _, plate in pairs(plates) do PP.Height(plate.health, v) end
                    if ns.ApplyNamePlateClickArea then ns.ApplyNamePlateClickArea() end
                    UpdatePreview()
                end
            }); y = y - h

        -----------------------------------------------------------------------
        --  CUSTOM HEALTH MARKERS
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "HEALTH MARKERS", y); y = y - h

        do
            local function markersOff()
                local cfg = MarkerCfg()
                return not (cfg and cfg.enabled == true)
            end

            local row
            row, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Enable Custom Health Markers"),
                    getValue = function()
                        local cfg = MarkerCfg()
                        return cfg and cfg.enabled == true
                    end,
                    setValue = function(v)
                        local cfg = MarkerCfg()
                        if cfg then
                            cfg.enabled = v
                            RebuildMarkerValues(cfg)
                        end
                        RefreshAllPlates()
                        UpdatePreview()
                        KT:RefreshPage()
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Show on All Nameplates"),
                    getValue = function()
                        local st = MarkerState()
                        return st and st.showOn == "all"
                    end,
                    setValue = function(v)
                        local st = MarkerState()
                        if st then st.showOn = v and "all" or "target" end
                        RefreshAllPlates()
                        UpdatePreview()
                    end,
                }); y = y - h

            row, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Per-Spec Marker Profile"),
                    getValue = function()
                        local st = MarkerState()
                        return st and (st.mode or "spec") == "spec"
                    end,
                    setValue = function(v)
                        local st = MarkerState()
                        if st then st.mode = v and "spec" or "character" end
                        RefreshAllPlates()
                        UpdatePreview()
                        KT:RefreshPage()
                    end,
                },
                {
                    type = "slider",
                    text = LText("Marker Width"),
                    min = 1,
                    max = 6,
                    step = 1,
                    disabled = markersOff,
                    disabledTooltip = "Enable Custom Health Markers",
                    getValue = function()
                        local cfg = MarkerCfg()
                        return (cfg and cfg.width) or 2
                    end,
                    setValue = function(v)
                        local cfg = MarkerCfg()
                        if cfg then
                            cfg.width = v
                            RebuildMarkerValues(cfg)
                        end
                        RefreshAllPlates()
                        UpdatePreview()
                    end,
                }); y = y - h

            row, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Marker 1"),
                    min = 0,
                    max = 100,
                    step = 1,
                    disabled = markersOff,
                    disabledTooltip = "Enable Custom Health Markers",
                    getValue = function() return GetMarkerSlotValue(MarkerCfg(), 1) end,
                    setValue = function(v)
                        SetMarkerSlotValue(MarkerCfg(), 1, v)
                        RefreshAllPlates()
                        UpdatePreview()
                    end,
                },
                {
                    type = "slider",
                    text = LText("Marker 2"),
                    min = 0,
                    max = 100,
                    step = 1,
                    disabled = markersOff,
                    disabledTooltip = "Enable Custom Health Markers",
                    getValue = function() return GetMarkerSlotValue(MarkerCfg(), 2) end,
                    setValue = function(v)
                        SetMarkerSlotValue(MarkerCfg(), 2, v)
                        RefreshAllPlates()
                        UpdatePreview()
                    end,
                }); y = y - h

            row, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Marker 3"),
                    min = 0,
                    max = 100,
                    step = 1,
                    disabled = markersOff,
                    disabledTooltip = "Enable Custom Health Markers",
                    getValue = function() return GetMarkerSlotValue(MarkerCfg(), 3) end,
                    setValue = function(v)
                        SetMarkerSlotValue(MarkerCfg(), 3, v)
                        RefreshAllPlates()
                        UpdatePreview()
                    end,
                },
                { type = "label", text = LText("Markers use % health (0 = off).") }); y = y - h

            -- Inline color swatch for marker color (row is the last created DualRow)
            do
                local markerColorGet = function()
                    local cfg = MarkerCfg() or {}
                    return cfg.colorR or 1, cfg.colorG or 1, cfg.colorB or 1
                end
                local markerColorSet = function(r, g, b)
                    local cfg = MarkerCfg()
                    if not cfg then return end
                    cfg.colorR, cfg.colorG, cfg.colorB = r, g, b
                    RebuildMarkerValues(cfg)
                    RefreshAllPlates()
                    UpdatePreview()
                end
                local leftRgn = row and row._leftRegion
                if leftRgn then
                    local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5, markerColorGet,
                        markerColorSet, nil, 20)
                    PP.Point(swatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
                    KT_RegisterWidgetRefresh(function()
                        local off = markersOff()
                        swatch:SetAlpha(off and 0.15 or 1)
                        swatch:EnableMouse(not off)
                        updateSwatch()
                    end)
                    swatch:SetAlpha(markersOff() and 0.15 or 1)
                    swatch:EnableMouse(not markersOff())
                end
            end
        end

        local function castIconOff() return DB() and DB().showCastIcon == false end

        local castBarHeightRow
        castBarHeightRow, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Cast Bar Height"),
                min = 10,
                max = 30,
                step = 1,
                getValue = function() return DBVal("castBarHeight") or defaults.castBarHeight end,
                setValue = function(v)
                    DB().castBarHeight = v
                    local barW = ns.GetHealthBarWidth()
                    for _, plate in pairs(plates) do
                        PP.Size(plate.cast, barW, v)
                        plate.cast:ClearAllPoints()
                        PP.Point(plate.cast, "TOPLEFT", plate.health, "BOTTOMLEFT", 0, 0)
                        PP.Size(plate.castIconFrame, v, v)
                        plate.castIconFrame:ClearAllPoints()
                        if (DBVal("castIconSide") or defaults.castIconSide) == "right" then
                            PP.Point(plate.castIconFrame, "TOPLEFT", plate.cast, "TOPRIGHT",
                                DBVal("castIconXOffset") or defaults.castIconXOffset,
                                DBVal("castIconYOffset") or defaults.castIconYOffset)
                        else
                            PP.Point(plate.castIconFrame, "TOPRIGHT", plate.cast, "TOPLEFT",
                                DBVal("castIconXOffset") or defaults.castIconXOffset,
                                DBVal("castIconYOffset") or defaults.castIconYOffset)
                        end
                        plate.castSpark:SetHeight(v)
                    end
                    UpdatePreview()
                end
            },
            {
                type = "toggle",
                text = LText("Spell Icon"),
                getValue = function()
                    local db = DB()
                    if db and db.showCastIcon ~= nil then return db.showCastIcon end
                    return defaults.showCastIcon
                end,
                setValue = function(v)
                    DB().showCastIcon = v
                    ns.RefreshAllSettings()
                    UpdatePreview()
                    KT:RefreshPage()
                end
            }); y = y - h
        local showCastIconRow = castBarHeightRow

        y = BuildDisplayCastBarColorSection(parent, y, W, UpdatePreview)

        -- Inline cog on Spell Icon (right region) for Scale
        do
            local rightRgn = castBarHeightRow._rightRegion
            local _, spellIconCogShow = KT.BuildCogPopup({
                title = "Spell Icon Settings",
                rows = {
                    {
                        type = "slider",
                        label = "Scale",
                        min = 0.5,
                        max = 2,
                        step = 0.1,
                        get = function() return DBVal("castIconScale") or defaults.castIconScale end,
                        set = function(v)
                            DB().castIconScale = v
                            if ns.RefreshAllSettings then ns.RefreshAllSettings() end
                            UpdatePreview()
                        end
                    },
                    {
                        type = "dropdown",
                        label = "Side",
                        values = {
                            { value = "left", label = "Left" },
                            { value = "right", label = "Right" },
                        },
                        get = function() return DBVal("castIconSide") or defaults.castIconSide end,
                        set = function(v)
                            DB().castIconSide = v
                            if ns.RefreshAllSettings then ns.RefreshAllSettings() end
                            UpdatePreview()
                        end
                    },
                    {
                        type = "slider",
                        label = "X Offset",
                        min = -30,
                        max = 30,
                        step = 1,
                        get = function() return DBVal("castIconXOffset") or defaults.castIconXOffset end,
                        set = function(v)
                            DB().castIconXOffset = v
                            if ns.RefreshAllSettings then ns.RefreshAllSettings() end
                            UpdatePreview()
                        end
                    },
                    {
                        type = "slider",
                        label = "Y Offset",
                        min = -20,
                        max = 20,
                        step = 1,
                        get = function() return DBVal("castIconYOffset") or defaults.castIconYOffset end,
                        set = function(v)
                            DB().castIconYOffset = v
                            if ns.RefreshAllSettings then ns.RefreshAllSettings() end
                            UpdatePreview()
                        end
                    },
                },
            })
            local spellIconCogBtn = CreateFrame("Button", nil, rightRgn)
            spellIconCogBtn:SetSize(26, 26)
            spellIconCogBtn:SetFrameLevel(rightRgn:GetFrameLevel() + 5)
            spellIconCogBtn:SetAlpha(castIconOff() and 0.15 or 0.4)
            local spellIconCogTex = spellIconCogBtn:CreateTexture(nil, "OVERLAY")
            spellIconCogTex:SetAllPoints()
            spellIconCogTex:SetTexture(KT.RESIZE_ICON)
            ApplyNPAccentToIcon(spellIconCogTex)
            AttachInlineWidget(rightRgn, spellIconCogBtn)
            spellIconCogBtn:SetScript("OnEnter", function(self)
                if castIconOff() then
                    KT_ShowWidgetTooltip(self, KT_DisabledTooltip("Spell Icon"))
                else
                    self:SetAlpha(0.7)
                end
            end)
            spellIconCogBtn:SetScript("OnLeave", function(self)
                KT_HideWidgetTooltip()
                self:SetAlpha(castIconOff() and 0.15 or 0.4)
            end)
            spellIconCogBtn:SetScript("OnClick", function(self)
                if castIconOff() then return end
                spellIconCogShow(self)
            end)
            _openSpellIconSettings = function(anchor)
                spellIconCogShow(anchor or spellIconCogBtn)
            end
            KT_RegisterWidgetRefresh(function()
                spellIconCogBtn:SetAlpha(castIconOff() and 0.15 or 0.4)
            end)
        end

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  CLASS RESOURCE
        -----------------------------------------------------------------------
        local classResourceHeader
        classResourceHeader, h = W:SectionHeader(parent, "CLASS RESOURCE", y); y = y - h

        local function classPowerDisabled() return DBVal("showClassPower") ~= true end

        local classResourceSectionTop = y -- track top of content rows

        local classResourceToggleRow
        classResourceToggleRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Show Class Resource"),
                getValue = function() return DBVal("showClassPower") == true end,
                setValue = function(v)
                    DB().showClassPower = v
                    ns.ApplyClassPowerSetting(); UpdatePreview()
                    KT:RefreshPage()
                end
            },
            {
                type = "multiSwatch",
                text = LText("Fill Color"),
                disabled = classPowerDisabled,
                disabledTooltip = "Show Class Resource",
                swatches = {
                    {
                        tooltip = "Custom Color",
                        disabled = classPowerDisabled,
                        disabledTooltip = "Show Class Resource",
                        getValue = function()
                            local c = (DB() and DB().classPowerCustomColor) or defaults.classPowerCustomColor
                            return c.r, c.g, c.b
                        end,
                        setValue = function(r, g, b)
                            DB().classPowerCustomColor = { r = r, g = g, b = b }
                            ns.RefreshClassPower(); UpdatePreview()
                        end,
                        onClick = function(self)
                            local v = DBVal("classPowerClassColors")
                            if v == nil then v = defaults.classPowerClassColors end
                            if v then
                                DB().classPowerClassColors = false
                                ns.RefreshClassPower(); UpdatePreview()
                                KT:RefreshPage()
                                return
                            end
                            if self._eabOrigClick then self._eabOrigClick(self) end
                        end,
                        refreshAlpha = function()
                            local v = DBVal("classPowerClassColors")
                            if v == nil then v = defaults.classPowerClassColors end
                            return v and 0.3 or 1
                        end
                    },
                    {
                        tooltip = "Class Colored",
                        disabled = classPowerDisabled,
                        disabledTooltip = "Show Class Resource",
                        getValue = function()
                            local _, ct = UnitClass("player")
                            if ct and RAID_CLASS_COLORS[ct] then
                                local cc = RAID_CLASS_COLORS[ct]
                                return cc.r, cc.g, cc.b, 1
                            end
                            return 1, 1, 1, 1
                        end,
                        setValue = function() end,
                        onClick = function()
                            DB().classPowerClassColors = true
                            ns.RefreshClassPower(); UpdatePreview()
                            KT:RefreshPage()
                        end,
                        refreshAlpha = function()
                            local v = DBVal("classPowerClassColors")
                            if v == nil then v = defaults.classPowerClassColors end
                            return v and 1 or 0.3
                        end
                    },
                }
            }); y = y - h

        -- Row 2: Position (with inline cog for X/Y) | Size
        local classResourceRow2
        classResourceRow2, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Position"),
                disabled = classPowerDisabled,
                disabledTooltip = "Show Class Resource",
                values = { top = "Top", bottom = "Bottom" },
                getValue = function() return DBVal("classPowerPos") or defaults.classPowerPos end,
                setValue = function(v)
                    DB().classPowerPos = v
                    ns.RefreshClassPower(); UpdatePreview()
                end,
                order = { "top", "bottom" }
            },
            {
                type = "slider",
                text = LText("Size"),
                min = 0.5,
                max = 3.0,
                step = 0.1,
                disabled = classPowerDisabled,
                disabledTooltip = "Show Class Resource",
                getValue = function() return DBVal("classPowerScale") or defaults.classPowerScale end,
                setValue = function(v)
                    DB().classPowerScale = v
                    ns.RefreshClassPower(); UpdatePreview()
                end
            }); y = y - h

        -- Inline cog on Position dropdown (X/Y offset settings)
        do
            local leftRgn = classResourceRow2._leftRegion
            local cpPosCogBtn = CreateFrame("Button", nil, leftRgn)
            cpPosCogBtn:SetSize(26, 26)
            cpPosCogBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 5)
            cpPosCogBtn:SetAlpha(classPowerDisabled() and 0.15 or 0.4)
            local cpPosCogTex = cpPosCogBtn:CreateTexture(nil, "OVERLAY")
            cpPosCogTex:SetAllPoints()
            cpPosCogTex:SetTexture(KT.DIRECTIONS_ICON)
            ApplyNPAccentToIcon(cpPosCogTex)
            AttachInlineWidget(leftRgn, cpPosCogBtn)
            cpPosCogBtn:SetScript("OnEnter", function(self)
                if classPowerDisabled() then
                    KT_ShowWidgetTooltip(self, KT_DisabledTooltip("Show Class Resource"))
                else
                    self:SetAlpha(0.7)
                end
            end)
            cpPosCogBtn:SetScript("OnLeave", function(self)
                KT_HideWidgetTooltip()
                if cogPopupOwner ~= self then self:SetAlpha(classPowerDisabled() and 0.15 or 0.4) end
            end)
            cpPosCogBtn:SetScript("OnClick", function(self)
                if classPowerDisabled() then return end
                ShowCogPopup(self, {
                    title = "Position Settings",
                    xGet = function() return DBVal("classPowerXOffset") or defaults.classPowerXOffset end,
                    xSet = function(v)
                        DB().classPowerXOffset = v; ns.RefreshClassPower(); UpdatePreview()
                    end,
                    yGet = function() return DBVal("classPowerYOffset") or defaults.classPowerYOffset end,
                    ySet = function(v)
                        DB().classPowerYOffset = v; ns.RefreshClassPower(); UpdatePreview()
                    end,
                })
            end)
            KT_RegisterWidgetRefresh(function()
                cpPosCogBtn:SetAlpha(classPowerDisabled() and 0.15 or (cogPopupOwner == cpPosCogBtn and 0.7 or 0.4))
            end)
        end

        -- Row 3: Bar Spacing + Background Color (with alpha)
        local classResourceRow3
        classResourceRow3, h = W:DualRow(parent, y,
            {
                type = "slider",
                text = LText("Bar Spacing"),
                min = 0,
                max = 10,
                step = 1,
                disabled = classPowerDisabled,
                disabledTooltip = "Show Class Resource",
                getValue = function() return DBVal("classPowerGap") or defaults.classPowerGap end,
                setValue = function(v)
                    DB().classPowerGap = v
                    ns.RefreshClassPower(); UpdatePreview()
                end
            },
            {
                type = "colorpicker",
                text = LText("Background Color"),
                hasAlpha = true,
                disabled = classPowerDisabled,
                disabledTooltip = "Show Class Resource",
                getValue = function()
                    local c = (DB() and DB().classPowerBgColor) or defaults.classPowerBgColor
                    return c.r, c.g, c.b, c.a
                end,
                setValue = function(r, g, b, a)
                    DB().classPowerBgColor = { r = r, g = g, b = b, a = a }
                    ns.RefreshClassPower(); UpdatePreview()
                end
            }); y = y - h

        -- Invisible frame spanning the entire CLASS RESOURCE section for glow targeting
        local classResourceSection = CreateFrame("Frame", nil, parent)
        local crPad = KT.CONTENT_PAD or 20
        classResourceSection:SetPoint("TOPLEFT", parent, "TOPLEFT", crPad, classResourceSectionTop)
        classResourceSection:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -crPad, classResourceSectionTop)
        classResourceSection:SetHeight(math.abs(classResourceSectionTop - y))
        classResourceSection._isSpacer = true -- hide from search layout

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  GENERAL TEXT
        -----------------------------------------------------------------------
        local generalTextHeader
        generalTextHeader, h = W:SectionHeader(parent, "GENERAL TEXT", y); y = y - h

        local function RefreshLiveAuraText()
            local db = DB()
            local auraDurSz = (db and db.auraDurationTextSize) or defaults.auraDurationTextSize
            local auraDurC = (db and db.auraDurationTextColor) or defaults.auraDurationTextColor
            local auraStackSz = (db and db.auraStackTextSize) or defaults.auraStackTextSize
            local auraStackC = (db and db.auraStackTextColor) or defaults.auraStackTextColor
            local auraDurX = (db and db.auraDurationXOffset) or defaults.auraDurationXOffset or 0
            local auraDurY = (db and db.auraDurationYOffset) or defaults.auraDurationYOffset or 0
            local auraStackX = (db and db.auraStackXOffset) or defaults.auraStackXOffset or 0
            local auraStackY = (db and db.auraStackYOffset) or defaults.auraStackYOffset or 0
            local auraPos = (db and db.auraTextPosition) or (db and db.debuffTextPosition) or defaults.auraTextPosition
            local debuffTPos = (db and db.debuffTimerPosition) or auraPos or defaults.debuffTimerPosition
            local buffTPos = (db and db.buffTimerPosition) or auraPos or defaults.buffTimerPosition
            local ccTPos = (db and db.ccTimerPosition) or auraPos or defaults.ccTimerPosition

            local function ApplyLiveTimer(fs, auraFrame, pos)
                if not (fs and auraFrame) then return end
                local cd = auraFrame.cd
                if pos == "none" then
                    if cd and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
                    return
                end
                if cd and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
                SetFSFont(fs, auraDurSz, "OUTLINE")
                fs:SetTextColor(auraDurC.r, auraDurC.g, auraDurC.b, 1)
                fs:ClearAllPoints()
                if pos == "center" then
                    fs:SetPoint("CENTER", auraFrame, "CENTER", auraDurX, auraDurY)
                    fs:SetJustifyH("CENTER")
                elseif pos == "topright" then
                    PP.Point(fs, "TOPRIGHT", auraFrame, "TOPRIGHT", 3 + auraDurX, 4 + auraDurY)
                    fs:SetJustifyH("RIGHT")
                else
                    PP.Point(fs, "TOPLEFT", auraFrame, "TOPLEFT", -3 + auraDurX, 4 + auraDurY)
                    fs:SetJustifyH("LEFT")
                end
            end

            local function ApplyLiveStack(fs, auraFrame, xBase, yBase)
                if not (fs and auraFrame) then return end
                SetFSFont(fs, auraStackSz, "OUTLINE")
                fs:SetTextColor(auraStackC.r, auraStackC.g, auraStackC.b, 1)
                fs:ClearAllPoints()
                PP.Point(fs, "BOTTOMRIGHT", auraFrame, "BOTTOMRIGHT", xBase + auraStackX, yBase + auraStackY)
                fs:SetJustifyH("RIGHT")
            end

            for _, plate in pairs(plates) do
                for i = 1, 4 do
                    if plate.debuffs[i] and plate.debuffs[i].cd and plate.debuffs[i].cd.text then
                        ApplyLiveTimer(plate.debuffs[i].cd.text, plate.debuffs[i], debuffTPos)
                    end
                    if plate.debuffs[i] and plate.debuffs[i].count then
                        ApplyLiveStack(plate.debuffs[i].count, plate.debuffs[i], 1, 1)
                    end
                    if plate.buffs[i] and plate.buffs[i].cd and plate.buffs[i].cd.text then
                        ApplyLiveTimer(plate.buffs[i].cd.text, plate.buffs[i], buffTPos)
                    end
                    if plate.buffs[i] and plate.buffs[i].count then
                        ApplyLiveStack(plate.buffs[i].count, plate.buffs[i], 2, -2)
                    end
                end
                for i = 1, 2 do
                    if plate.cc[i] and plate.cc[i].cd and plate.cc[i].cd.text then
                        ApplyLiveTimer(plate.cc[i].cd.text, plate.cc[i], ccTPos)
                    end
                end
            end
        end

        local function RefreshLiveCastText()
            local db = DB()
            local cns = (db and db.castNameSize) or defaults.castNameSize
            local cts = (db and db.castTargetSize) or defaults.castTargetSize
            local cnc = (db and db.castNameColor) or defaults.castNameColor
            local useClassColor = defaults.castTargetClassColor
            if db and db.castTargetClassColor ~= nil then useClassColor = db.castTargetClassColor end
            local ctc = (db and db.castTargetColor) or defaults.castTargetColor

            for _, plate in pairs(plates) do
                if plate.castName then
                    SetFSFont(plate.castName, cns, GetNPOutline())
                    plate.castName:SetTextColor(cnc.r, cnc.g, cnc.b, 1)
                end
                if plate.castTarget then
                    SetFSFont(plate.castTarget, cts, GetNPOutline())
                    if not useClassColor then
                        plate.castTarget:SetTextColor(ctc.r, ctc.g, ctc.b, 1)
                    end
                end
                if plate.ApplyCastTextAnchors then
                    plate:ApplyCastTextAnchors()
                end
                if plate.isCasting or plate._interrupted then
                    plate:UpdateCast()
                end
            end
        end

        -- Row 1: Aura Duration | Aura Stacks
        local auraDurPosRow
        local auraTimerStackRow
        do
            local dualRow
            dualRow, h = W:DualRow(parent, y,
                {
                    type = "dropdown",
                    text = LText("Aura Duration"),
                    values = timerPosValues,
                    getValue = function() return DBVal("debuffTimerPosition") or atFallback end,
                    setValue = function(v)
                        DB().debuffTimerPosition = v
                        DB().buffTimerPosition = v
                        DB().ccTimerPosition = v
                        DB().auraTextPosition = v
                        RefreshLiveAuraText()
                        UpdatePreview()
                    end,
                    order = timerPosOrder
                },
                {
                    type = "colorpicker",
                    text = LText("Aura Stacks"),
                    getValue = function()
                        local c = (DB() and DB().auraStackTextColor) or defaults.auraStackTextColor
                        return c.r, c.g, c.b
                    end,
                    setValue = function(r, g, b)
                        DB().auraStackTextColor = { r = r, g = g, b = b }
                        RefreshLiveAuraText()
                        UpdatePreview()
                    end
                })
            auraDurPosRow = dualRow
            auraTimerStackRow = dualRow

            -- LEFT: Aura Duration inline swatch + cog
            local leftRgn = dualRow._leftRegion
            local adColorGet = function()
                local c = (DB() and DB().auraDurationTextColor) or defaults.auraDurationTextColor
                return c.r, c.g, c.b
            end
            local adColorSet = function(r, g, b)
                DB().auraDurationTextColor = { r = r, g = g, b = b }
                DB().debuffTimerColor = { r = r, g = g, b = b }
                DB().debuffTextWhite = nil
                RefreshLiveAuraText()
                UpdatePreview()
            end
            local adSwatch, adUpdateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5,
                adColorGet, adColorSet, nil, 20)
            KT_RegisterWidgetRefresh(function() adUpdateSwatch() end)

            local auraDurCogBtn = CreateFrame("Button", nil, leftRgn)
            auraDurCogBtn:SetSize(26, 26)
            auraDurCogBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 5)
            auraDurCogBtn:SetAlpha(0.4)
            local auraDurCogTex = auraDurCogBtn:CreateTexture(nil, "OVERLAY")
            auraDurCogTex:SetAllPoints()
            auraDurCogTex:SetTexture(KT.RESIZE_ICON)
            ApplyNPAccentToIcon(auraDurCogTex)
            AttachInlineWidget(leftRgn, auraDurCogBtn)
            AttachInlineWidget(leftRgn, adSwatch)
            auraDurCogBtn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
            auraDurCogBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
            auraDurCogBtn:SetScript("OnClick", function(self)
                ShowCogPopup(self, {
                    title = "Aura Duration Settings",
                    xGet = function() return DBVal("auraDurationXOffset") or defaults.auraDurationXOffset or 0 end,
                    xSet = function(v)
                        DB().auraDurationXOffset = v
                        RefreshLiveAuraText()
                        UpdatePreview()
                    end,
                    yGet = function() return DBVal("auraDurationYOffset") or defaults.auraDurationYOffset or 0 end,
                    ySet = function(v)
                        DB().auraDurationYOffset = v
                        RefreshLiveAuraText()
                        UpdatePreview()
                    end,
                    sizeGet = function() return DBVal("auraDurationTextSize") or defaults.auraDurationTextSize end,
                    sizeSet = function(v)
                        DB().auraDurationTextSize = v
                        RefreshLiveAuraText()
                        UpdatePreview()
                    end,
                    sizeMin = 6,
                    sizeMax = 20,
                    sizeLabel = "Size",
                })
            end)

            -- RIGHT: Aura Stacks cog for offset + size
            local rightRgn = dualRow._rightRegion
            local auraStackCogBtn = CreateFrame("Button", nil, rightRgn)
            auraStackCogBtn:SetSize(26, 26)
            auraStackCogBtn:SetFrameLevel(rightRgn:GetFrameLevel() + 5)
            auraStackCogBtn:SetAlpha(0.4)
            local auraStackCogTex = auraStackCogBtn:CreateTexture(nil, "OVERLAY")
            auraStackCogTex:SetAllPoints()
            auraStackCogTex:SetTexture(KT.RESIZE_ICON)
            ApplyNPAccentToIcon(auraStackCogTex)
            AttachInlineWidget(rightRgn, auraStackCogBtn)
            auraStackCogBtn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
            auraStackCogBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
            auraStackCogBtn:SetScript("OnClick", function(self)
                ShowCogPopup(self, {
                    title = "Aura Stacks Settings",
                    xGet = function() return DBVal("auraStackXOffset") or defaults.auraStackXOffset or 0 end,
                    xSet = function(v)
                        DB().auraStackXOffset = v
                        RefreshLiveAuraText()
                        UpdatePreview()
                    end,
                    yGet = function() return DBVal("auraStackYOffset") or defaults.auraStackYOffset or 0 end,
                    ySet = function(v)
                        DB().auraStackYOffset = v
                        RefreshLiveAuraText()
                        UpdatePreview()
                    end,
                    sizeGet = function() return DBVal("auraStackTextSize") or defaults.auraStackTextSize end,
                    sizeSet = function(v)
                        DB().auraStackTextSize = v
                        RefreshLiveAuraText()
                        UpdatePreview()
                    end,
                    sizeMin = 6,
                    sizeMax = 20,
                    sizeLabel = "Size",
                })
            end)
        end
        y = y - h

        -- Row 2: Spell Name | Spell Target
        local spellNameRow
        spellNameRow, h = W:DualRow(parent, y,
            {
                type = "colorpicker",
                text = LText("Spell Name"),
                getValue = function() return DBColor("castNameColor") end,
                setValue = function(r, g, b)
                    DB().castNameColor = { r = r, g = g, b = b }
                    RefreshLiveCastText()
                    UpdatePreview()
                end
            },
            {
                type = "multiSwatch",
                text = LText("Spell Target"),
                swatches = {
                    {
                        tooltip = "Custom Color",
                        getValue = function() return DBColor("castTargetColor") end,
                        setValue = function(r, g, b)
                            DB().castTargetColor = { r = r, g = g, b = b }
                            RefreshLiveCastText()
                            UpdatePreview()
                        end,
                        onClick = function(self)
                            local db = DB()
                            if db.castTargetClassColor ~= nil and db.castTargetClassColor or defaults.castTargetClassColor then
                                DB().castTargetClassColor = false
                                RefreshLiveCastText()
                                UpdatePreview()
                                KT:RefreshPage()
                                return
                            end
                            if self._eabOrigClick then self._eabOrigClick(self) end
                        end,
                        refreshAlpha = function()
                            local db = DB()
                            local cc = db and db.castTargetClassColor
                            if cc == nil then cc = defaults.castTargetClassColor end
                            return cc and 0.3 or 1
                        end
                    },
                    {
                        tooltip = "Class Colored",
                        getValue = function()
                            local _, ct = UnitClass("player")
                            if ct and RAID_CLASS_COLORS[ct] then
                                local cc = RAID_CLASS_COLORS[ct]
                                return cc.r, cc.g, cc.b, 1
                            end
                            return 1, 1, 1, 1
                        end,
                        setValue = function() end,
                        onClick = function()
                            DB().castTargetClassColor = true
                            RefreshLiveCastText()
                            UpdatePreview()
                            KT:RefreshPage()
                        end,
                        refreshAlpha = function()
                            local db = DB()
                            local cc = db and db.castTargetClassColor
                            if cc == nil then cc = defaults.castTargetClassColor end
                            return cc and 1 or 0.3
                        end
                    },
                }
            })
        do
            -- LEFT: Spell Name cog for offset + size
            local leftRgn = spellNameRow._leftRegion
            local spellNameCogBtn = CreateFrame("Button", nil, leftRgn)
            spellNameCogBtn:SetSize(26, 26)
            spellNameCogBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 5)
            spellNameCogBtn:SetAlpha(0.4)
            local spellNameCogTex = spellNameCogBtn:CreateTexture(nil, "OVERLAY")
            spellNameCogTex:SetAllPoints()
            spellNameCogTex:SetTexture(KT.RESIZE_ICON)
            ApplyNPAccentToIcon(spellNameCogTex)
            AttachInlineWidget(leftRgn, spellNameCogBtn)
            spellNameCogBtn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
            spellNameCogBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
            spellNameCogBtn:SetScript("OnClick", function(self)
                ShowCogPopup(self, {
                    title = "Spell Name Settings",
                    xGet = function() return DBVal("castNameXOffset") or defaults.castNameXOffset or 0 end,
                    xSet = function(v)
                        DB().castNameXOffset = v
                        RefreshLiveCastText()
                        UpdatePreview()
                    end,
                    yGet = function() return DBVal("castNameYOffset") or defaults.castNameYOffset or 0 end,
                    ySet = function(v)
                        DB().castNameYOffset = v
                        RefreshLiveCastText()
                        UpdatePreview()
                    end,
                    sizeGet = function() return DBVal("castNameSize") or defaults.castNameSize end,
                    sizeSet = function(v)
                        DB().castNameSize = v
                        RefreshLiveCastText()
                        UpdatePreview()
                    end,
                    sizeMin = 6,
                    sizeMax = 16,
                    sizeLabel = "Size",
                })
            end)

            -- RIGHT: Spell Target cog for offset + size
            local rightRgn = spellNameRow._rightRegion
            local spellTargetCogBtn = CreateFrame("Button", nil, rightRgn)
            spellTargetCogBtn:SetSize(26, 26)
            spellTargetCogBtn:SetFrameLevel(rightRgn:GetFrameLevel() + 5)
            spellTargetCogBtn:SetAlpha(0.4)
            local spellTargetCogTex = spellTargetCogBtn:CreateTexture(nil, "OVERLAY")
            spellTargetCogTex:SetAllPoints()
            spellTargetCogTex:SetTexture(KT.RESIZE_ICON)
            ApplyNPAccentToIcon(spellTargetCogTex)
            AttachInlineWidget(rightRgn, spellTargetCogBtn)
            spellTargetCogBtn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
            spellTargetCogBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
            spellTargetCogBtn:SetScript("OnClick", function(self)
                ShowCogPopup(self, {
                    title = "Spell Target Settings",
                    xGet = function() return DBVal("castTargetXOffset") or defaults.castTargetXOffset or 0 end,
                    xSet = function(v)
                        DB().castTargetXOffset = v
                        RefreshLiveCastText()
                        UpdatePreview()
                    end,
                    yGet = function() return DBVal("castTargetYOffset") or defaults.castTargetYOffset or 0 end,
                    ySet = function(v)
                        DB().castTargetYOffset = v
                        RefreshLiveCastText()
                        UpdatePreview()
                    end,
                    sizeGet = function() return DBVal("castTargetSize") or defaults.castTargetSize end,
                    sizeSet = function(v)
                        DB().castTargetSize = v
                        RefreshLiveCastText()
                        UpdatePreview()
                    end,
                    sizeMin = 6,
                    sizeMax = 16,
                    sizeLabel = "Size",
                })
            end)
        end
        y = y - h

        -----------------------------------------------------------------------
        --  CLICK NAVIGATION: glow, scroll, mapping, hit overlays
        -----------------------------------------------------------------------
        local glowFrame
        local function PlaySettingGlow(targetFrame)
            if not targetFrame then return end
            if not glowFrame then
                glowFrame = CreateFrame("Frame")
                local c = NP_PREVIEW_ACCENT
                local function MkEdge()
                    local t = glowFrame:CreateTexture(nil, "OVERLAY", nil, 7)
                    t:SetColorTexture(c.r, c.g, c.b, 1)
                    if t.SetSnapToPixelGrid then
                        t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0)
                    end
                    return t
                end
                glowFrame._top = MkEdge()
                glowFrame._bot = MkEdge()
                glowFrame._lft = MkEdge()
                glowFrame._rgt = MkEdge()
                local glowPx = PP.Scale(2)
                glowFrame._top:SetHeight(glowPx)
                glowFrame._top:SetPoint("TOPLEFT"); glowFrame._top:SetPoint("TOPRIGHT")
                glowFrame._bot:SetHeight(glowPx)
                glowFrame._bot:SetPoint("BOTTOMLEFT"); glowFrame._bot:SetPoint("BOTTOMRIGHT")
                glowFrame._lft:SetWidth(glowPx)
                glowFrame._lft:SetPoint("TOPLEFT", glowFrame._top, "BOTTOMLEFT")
                glowFrame._lft:SetPoint("BOTTOMLEFT", glowFrame._bot, "TOPLEFT")
                glowFrame._rgt:SetWidth(glowPx)
                glowFrame._rgt:SetPoint("TOPRIGHT", glowFrame._top, "BOTTOMRIGHT")
                glowFrame._rgt:SetPoint("BOTTOMRIGHT", glowFrame._bot, "TOPRIGHT")
            end
            glowFrame:SetParent(targetFrame)
            glowFrame:SetAllPoints(targetFrame)
            glowFrame:SetFrameLevel(targetFrame:GetFrameLevel() + 5)
            glowFrame:SetAlpha(1)
            glowFrame:Show()
            local elapsed = 0
            glowFrame:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed >= 0.75 then
                    self:Hide(); self:SetScript("OnUpdate", nil); return
                end
                self:SetAlpha(1 - elapsed / 0.75)
            end)
        end

        -- Maps Core Position slot keys to their row/region
        local corePosToRow = {
            top      = { row = coreRow1, side = "_leftRegion" },
            right    = { row = coreRow1, side = "_rightRegion" },
            left     = { row = coreRow2, side = "_leftRegion" },
            topright = { row = coreRow2, side = "_rightRegion" },
            topleft  = { row = coreRow3, side = "_leftRegion" },
        }

        -- Maps Core Text Position slot keys to their row/region
        local textSlotToRow = {
            textSlotTop    = { row = textRow1, side = "_leftRegion" },
            textSlotRight  = { row = textRow1, side = "_rightRegion" },
            textSlotLeft   = { row = textRow2, side = "_leftRegion" },
            textSlotCenter = { row = textRow2, side = "_rightRegion" },
        }

        -- Reverse lookup: find which Core Position slot holds a given element
        local function FindCorePosForElement(element)
            local db = DB()
            local key = elementToKey[element]
            if not key then return nil end
            local pos = db[key] or defaults[key]
            if pos == "none" then return nil end
            return pos
        end

        -- Reverse lookup: find which text slot holds a given element
        local function FindTextSlotForElement(element)
            local db = DB()
            for _, key in ipairs(textSlotKeys) do
                if (db[key] or defaults[key]) == element then return key end
            end
            return nil
        end

        -- Resolve a dynamic click mapping for icon elements Core Positions row
        local function ResolveCoreMapping(element)
            local pos = FindCorePosForElement(element)
            if not pos then return { section = coreHeader, target = coreRow1 } end
            local info = corePosToRow[pos]
            if not info then return { section = coreHeader, target = coreRow1 } end
            return { section = coreHeader, target = info.row, slotSide = (info.side == "_leftRegion") and "left" or
            "right" }
        end

        -- Resolve a dynamic click mapping for text elements Core Text Positions row
        local function ResolveTextMapping(element)
            local slotKey = FindTextSlotForElement(element)
            if not slotKey then return { section = coreTextHeader, target = textRow1 } end
            local info = textSlotToRow[slotKey]
            if not info then return { section = coreTextHeader, target = textRow1 } end
            return { section = coreTextHeader, target = info.row, slotSide = (info.side == "_leftRegion") and "left" or
            "right" }
        end

        local clickMappings = {
            auraDuration  = { section = generalTextHeader, target = auraDurPosRow, slotSide = "left" },
            auraStack     = { section = generalTextHeader, target = auraTimerStackRow, slotSide = "right" },
            castBar       = { section = healthBarHeader, target = castBarHeightRow, slotSide = "left" },
            castIcon      = { section = healthBarHeader, target = showCastIconRow, slotSide = "right" },
            castName      = { section = generalTextHeader, target = spellNameRow, slotSide = "left" },
            castTarget    = { section = generalTextHeader, target = spellNameRow, slotSide = "right" },
            enemyName     = { section = enemyTextHeader, target = enemyNameTextRow, slotSide = "left" },
            healthBar     = { section = healthBarHeader, target = healthBarHeightRow, slotSide = "left" },
            classResource = { section = classResourceHeader, target = classResourceSection },
            targetArrows  = { section = styleHeader, target = targetIndicatorRow or targetGlowRow, slotSide = "left" },
        }

        -- Dynamic resolvers for elements assigned to Core Positions / Core Text Positions
        local dynamicMappings = {
            debuffIcon = function() return ResolveCoreMapping("debuffs") end,
            buffIcon   = function() return ResolveCoreMapping("buffs") end,
            ccIcon     = function() return ResolveCoreMapping("ccs") end,
            raidMarker = function() return ResolveCoreMapping("raidmarker") end,
            classIcon  = function() return ResolveCoreMapping("classification") end,
            healthText = function()
                local slot = FindTextSlotForElement("healthPercent") or FindTextSlotForElement("healthPercentNoSign") or
                FindTextSlotForElement("healthNumber") or FindTextSlotForElement("healthPctNum") or
                FindTextSlotForElement("healthNumPct")
                if not slot then return { section = coreTextHeader, target = textRow1 } end
                local info = textSlotToRow[slot]
                if not info then return { section = coreTextHeader, target = textRow1 } end
                return { section = coreTextHeader, target = info.row, slotSide = (info.side == "_leftRegion") and "left" or
                "right" }
            end,
        }

        local function NavigateToSetting(key)
            if key == "castIcon" and _openSpellIconSettings then
                local m = clickMappings[key]
                if m and m.section and m.target then
                    local _, _, _, _, headerY = m.section:GetPoint(1)
                    if headerY then
                        KT.SmoothScrollTo(math.max(0, math.abs(headerY) - 40))
                    end
                end
                C_Timer.After(0.15, function() _openSpellIconSettings() end)
                return
            end
            local m = clickMappings[key]
            -- Check dynamic mappings (icon/text elements assigned to Core Positions)
            if not m then
                local resolver = dynamicMappings[key]
                if resolver then m = resolver() end
            end
            if not m or not m.section or not m.target then return end

            -- Dismiss the hint text on first click (fade out over 0.3s using ticker)
            if not IsPreviewHintDismissed() and _previewHintFS and _previewHintFS:IsShown() then
                KullThranUIDB = KullThranUIDB or {}
                KullThranUIDB.previewHintDismissed = true
                local hint = _previewHintFS
                local _, anchorTo, _, _, startY = hint:GetPoint(1)
                startY = startY or 17
                anchorTo = anchorTo or hint:GetParent()
                local startHeaderH = _headerBaseH + 29
                local targetHeaderH = _headerBaseH
                local steps = 0
                local ticker
                ticker = C_Timer.NewTicker(0.016, function()
                    steps = steps + 1
                    local progress = steps * 0.016 / 0.3
                    if progress >= 1 then
                        hint:Hide()
                        ticker:Cancel()
                        if targetHeaderH > 0 then
                            KT:SetContentHeaderHeightSilent(targetHeaderH)
                        end
                        return
                    end
                    hint:SetAlpha(0.45 * (1 - progress))
                    hint:ClearAllPoints()
                    hint:SetPoint("BOTTOM", anchorTo, "BOTTOM", 0, startY + progress * 12)
                    local h = startHeaderH - 39 * progress
                    if h > 0 then
                        KT:SetContentHeaderHeightSilent(h)
                    end
                end)
            end

            local sf = KT._scrollFrame
            if not sf then return end
            local _, _, _, _, headerY = m.section:GetPoint(1)
            if not headerY then return end
            local scrollPos = math.max(0, math.abs(headerY) - 40)
            KT.SmoothScrollTo(scrollPos)
            local glowTarget = m.target
            if m.slotSide and m.target then
                local region = (m.slotSide == "left") and m.target._leftRegion or m.target._rightRegion
                if region then glowTarget = region end
            end
            C_Timer.After(0.15, function() PlaySettingGlow(glowTarget) end)
        end

        -- Hit overlay factory for preview elements
        -- opts (optional table):
        --   hlAnchor     = frame draw highlight around this frame instead of btn
        --   hlBehindText = true  draw highlight on a child frame at icon level + 1
        --                          (text lives on a child frame at icon level + 2)
        local function SnapPreview(val)
            local s = activePreview and activePreview:GetEffectiveScale() or 1
            if s <= 0 then s = 1 end
            return math.floor(val * s + 0.5) / s
        end
        ns._PreviewDrag = {
            MARGIN = 8,
            THRESHOLD = 3,
            TEXT_SLOTS = {
                { key = "textSlotTop", values = { enemyName = true, healthPercent = true, healthPercentNoSign = true, healthNumber = true, healthPctNum = true, healthNumPct = true } },
                { key = "textSlotRight", values = { enemyName = true, healthPercent = true, healthPercentNoSign = true, healthNumber = true, healthPctNum = true, healthNumPct = true } },
                { key = "textSlotLeft", values = { enemyName = true, healthPercent = true, healthPercentNoSign = true, healthNumber = true, healthPctNum = true, healthNumPct = true } },
                { key = "textSlotCenter", values = { enemyName = true, healthPercent = true, healthPercentNoSign = true, healthNumber = true, healthPctNum = true, healthNumPct = true } },
            },
        }

        function ns._PreviewDrag:Pixel(value, pv)
            local scale = pv and pv.GetEffectiveScale and pv:GetEffectiveScale() or 1
            if scale <= 0 then scale = 1 end
            return math.floor(value * scale + 0.5) / scale
        end

        function ns._PreviewDrag:GetCanvas(pv)
            if not (pv and pv.GetLeft and pv.GetRight and pv.GetTop and pv.GetBottom) then return end
            local left, right = pv:GetLeft(), pv:GetRight()
            local top, bottom = pv:GetTop(), pv:GetBottom()
            if not (left and right and top and bottom) then return end
            local margin = self.MARGIN
            return left + margin, right - margin, top - margin, bottom + margin
        end

        function ns._PreviewDrag:GetTextKeys(mappingKey)
            local direct = {
                castName = { "castNameXOffset", "castNameYOffset" },
                castTarget = { "castTargetXOffset", "castTargetYOffset" },
                auraDuration = { "auraDurationXOffset", "auraDurationYOffset" },
                auraStack = { "auraStackXOffset", "auraStackYOffset" },
            }
            local pair = direct[mappingKey]
            if pair then return pair[1], pair[2] end
            for _, slot in ipairs(self.TEXT_SLOTS) do
                local value = DBVal(slot.key)
                if mappingKey == "enemyName" and value == "enemyName" then
                    return slot.key .. "XOffset", slot.key .. "YOffset"
                elseif mappingKey == "healthText" and (value == "healthPercent" or value == "healthPercentNoSign" or value == "healthPctNum" or value == "healthNumPct") then
                    return slot.key .. "XOffset", slot.key .. "YOffset"
                elseif mappingKey == "healthNumber" and (value == "healthNumber" or value == "healthPctNum" or value == "healthNumPct") then
                    return slot.key .. "XOffset", slot.key .. "YOffset"
                end
            end
        end
        function ns._PreviewDrag:Begin(button, pv, mappingKey, groupKey)
            local xKey, yKey
            if groupKey then
                local meta = self.auraMeta and self.auraMeta[groupKey]
                local slot = meta and DBVal(meta.slotKey)
                if not (meta and slot and slot ~= "none") then return false end
                xKey, yKey = slot .. "SlotXOffset", slot .. "SlotYOffset"
            else
                xKey, yKey = self:GetTextKeys(mappingKey)
            end
            if not (xKey and yKey and pv) then return false end
            local left, right = button:GetLeft(), button:GetRight()
            local top, bottom = button:GetTop(), button:GetBottom()
            local canvasLeft, canvasRight, canvasTop, canvasBottom = self:GetCanvas(pv)
            if not (left and right and top and bottom and canvasLeft) then return false end
            local width, height = right - left, top - bottom
            local cx, cy = GetCursorPosition()
            local uiScale = UIParent:GetEffectiveScale()
            if uiScale <= 0 then uiScale = 1 end
            cx, cy = cx / uiScale, cy / uiScale
            button._previewDragState = {
                pv = pv,
                xKey = xKey,
                yKey = yKey,
                cursorX = cx,
                cursorY = cy,
                centerX = (left + right) / 2,
                centerY = (top + bottom) / 2,
                halfW = width / 2,
                halfH = height / 2,
                canvasLeft = canvasLeft,
                canvasRight = canvasRight,
                canvasTop = canvasTop,
                canvasBottom = canvasBottom,
                baseX = DBVal(xKey) or 0,
                baseY = DBVal(yKey) or 0,
                dragging = false,
            }
            return true
        end

        function ns._PreviewDrag:Update(button)
            local state = button._previewDragState
            if not state then return end
            local uiScale = UIParent:GetEffectiveScale()
            if uiScale <= 0 then uiScale = 1 end
            local cx, cy = GetCursorPosition()
            cx, cy = cx / uiScale, cy / uiScale
            local dx = self:Pixel(cx - state.cursorX, state.pv)
            local dy = self:Pixel(cy - state.cursorY, state.pv)
            if not state.dragging then
                if math.abs(dx) < self.THRESHOLD and math.abs(dy) < self.THRESHOLD then return end
                state.dragging = true
            end
            local targetX = self:Pixel(state.centerX + dx, state.pv)
            local targetY = self:Pixel(state.centerY + dy, state.pv)
            local minX = state.canvasLeft + state.halfW
            local maxX = state.canvasRight - state.halfW
            local minY = state.canvasBottom + state.halfH
            local maxY = state.canvasTop - state.halfH
            if maxX < minX then targetX = (state.canvasLeft + state.canvasRight) / 2 else targetX = math.max(minX, math.min(maxX, targetX)) end
            if maxY < minY then targetY = (state.canvasBottom + state.canvasTop) / 2 else targetY = math.max(minY, math.min(maxY, targetY)) end
            targetX = self:Pixel(targetX, state.pv)
            targetY = self:Pixel(targetY, state.pv)
            local newX = math.max(-500, math.min(500, state.baseX + (targetX - state.centerX)))
            local newY = math.max(-500, math.min(500, state.baseY + (targetY - state.centerY)))
            local db = DB()
            if db and (db[state.xKey] ~= newX or db[state.yKey] ~= newY) then
                db[state.xKey], db[state.yKey] = newX, newY
                UpdatePreview()
            end
        end

        function ns._PreviewDrag:Finish(button)
            local state = button._previewDragState
            if not state then return false end
            if state.dragging then
                self:Update(button)
                if ns.RefreshAllSettings then ns.RefreshAllSettings() end
                UpdatePreview()
            end
            button._previewDragState = nil
            return state.dragging
        end
        local function CreateHitOverlay(element, mappingKey, isText, frameLevelOverride, opts)
            local anchor = isText and element:GetParent() or element
            -- If the element is a Texture (not a Frame), parent to its owner frame
            if not anchor.CreateTexture then anchor = anchor:GetParent() end
            local btn = CreateFrame("Button", nil, anchor)
            if isText then
                -- For FontStrings: dynamically size to the actual rendered text
                local function ResizeToText()
                    local ok, tw, th = pcall(function()
                        local w = element:GetStringWidth() or 0
                        local h = element:GetStringHeight() or 0
                        if w < 4 then w = 4 end
                        if h < 4 then h = 4 end
                        return w, h
                    end)
                    if not ok then
                        tw = 40; th = 12
                    end
                    btn:SetSize(tw + 4, th + 4)
                end
                ResizeToText()
                -- Anchor to the FontString's justification point
                local justify = element:GetJustifyH()
                if justify == "RIGHT" then
                    btn:SetPoint("RIGHT", element, "RIGHT", 2, 0)
                elseif justify == "CENTER" then
                    btn:SetPoint("CENTER", element, "CENTER", 0, 0)
                else
                    btn:SetPoint("LEFT", element, "LEFT", -2, 0)
                end
                -- Re-measure on every show so size tracks font/text changes
                btn:SetScript("OnShow", function() ResizeToText() end)
                btn._resizeToText = ResizeToText
            else
                btn:SetAllPoints(opts and opts.hlAnchor or element)
            end
            btn:SetFrameLevel(frameLevelOverride or (anchor:GetFrameLevel() + 20))
            btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
            btn:SetScript("OnMouseDown", function(self, button)
                if button ~= "LeftButton" then return end
                local groupKey = opts and opts.dragGroup
                if ns._PreviewDrag:Begin(self, activePreview, mappingKey, groupKey) then
                    self:SetScript("OnUpdate", function(owner) ns._PreviewDrag:Update(owner) end)
                end
            end)
            btn:SetScript("OnMouseUp", function(self, button)
                if button ~= "LeftButton" then return end
                self:SetScript("OnUpdate", nil)
                local dragged = ns._PreviewDrag:Finish(self)
                if not dragged then NavigateToSetting(mappingKey) end
            end)
            btn:SetScript("OnHide", function(self)
                self:SetScript("OnUpdate", nil)
                self._previewDragState = nil
            end)
            local c = NP_PREVIEW_ACCENT
            local PP = KT.PP
            -- When hlBehindText is set, attach the border to a dedicated child frame
            -- at icon level + 1 so it sits between the icon artwork and text layers.
            -- Always use a child container so the hover border doesn't conflict
            -- with any existing PP border on the target frame.
            local behindText = opts and opts.hlBehindText
            local hlBase
            if behindText then
                local hlFrame = CreateFrame("Frame", nil, element)
                hlFrame:SetAllPoints()
                hlFrame:SetFrameLevel(element:GetFrameLevel() + 1)
                hlBase = hlFrame
            else
                hlBase = (opts and opts.hlAnchor) or btn
            end
            local hlCont = CreateFrame("Frame", nil, hlBase)
            hlCont:SetAllPoints()
            hlCont:SetFrameLevel(hlBase:GetFrameLevel() + 1)
            local brd = PP.CreateBorder(hlCont, c.r, c.g, c.b, 1, 2, "OVERLAY", 7)
            brd:Hide()
            btn:SetScript("OnEnter", function() brd:Show() end)
            btn:SetScript("OnLeave", function() brd:Hide() end)

            return btn
        end
        local auraDragMeta = {
            debuffs = {
                slotKey = "debuffSlot",
                mappingKey = "debuffIcon",
                count = PREVIEW_DEBUFF_COUNT,
                defaultSize = 26,
                label = "Debuffs",
            },
            buffs = {
                slotKey = "buffSlot",
                mappingKey = "buffIcon",
                count = PREVIEW_BUFF_COUNT,
                defaultSize = 24,
                label = "Buffs",
            },
            ccs = {
                slotKey = "ccSlot",
                mappingKey = "ccIcon",
                count = PREVIEW_CC_COUNT,
                defaultSize = 24,
                label = "CCs",
            },
        }

        ns._PreviewDrag.auraMeta = auraDragMeta
        -- Create hit overlays for all interactive preview elements
        local textOverlays = {} -- collect text overlays for size refresh
        if activePreview then
            local pv = activePreview
            -- Icon overlays need to be above the icon frames (which are at health:GetFrameLevel() + 8)
            local iconLevel = (pv._health and pv._health:GetFrameLevel() or 20) + 15
            -- Text overlays on icons need to be above the icon overlays
            local textOnIconLevel = iconLevel + 10
            -- Aura icons (all debuffs, buffs, ccs)
            if pv._ccs then
                for i = 1, #pv._ccs do
                    if pv._ccs[i] then
                        CreateHitOverlay(pv._ccs[i], "ccIcon", false, iconLevel, { hlBehindText = true, dragGroup = "ccs" })
                        if pv._ccs[i].durationText then
                            local ov = CreateHitOverlay(pv._ccs[i].durationText, "auraDuration", true, textOnIconLevel)
                            textOverlays[#textOverlays + 1] = ov
                        end
                    end
                end
            end
            if pv._buffs then
                for i = 1, #pv._buffs do
                    if pv._buffs[i] then
                        CreateHitOverlay(pv._buffs[i], "buffIcon", false, iconLevel, { hlBehindText = true, dragGroup = "buffs" })
                        if pv._buffs[i].durationText then
                            local ov = CreateHitOverlay(pv._buffs[i].durationText, "auraDuration", true, textOnIconLevel)
                            textOverlays[#textOverlays + 1] = ov
                        end
                    end
                end
            end
            if pv._debuffs then
                for i = 1, #pv._debuffs do
                    if pv._debuffs[i] then
                        CreateHitOverlay(pv._debuffs[i], "debuffIcon", false, iconLevel, { hlBehindText = true, dragGroup = "debuffs" })
                        if pv._debuffs[i].durationText then
                            local ov = CreateHitOverlay(pv._debuffs[i].durationText, "auraDuration", true,
                                textOnIconLevel)
                            textOverlays[#textOverlays + 1] = ov
                        end
                        if pv._debuffs[i].stackText then
                            local ov = CreateHitOverlay(pv._debuffs[i].stackText, "auraStack", true, textOnIconLevel)
                            textOverlays[#textOverlays + 1] = ov
                        end
                    end
                end
            end
            -- Cast icon overlay (separate from cast bar navigates to Show Spell Icon row)
            local castOverlayLevel
            if pv._cast then
                castOverlayLevel = pv._cast:GetFrameLevel() + 20
                local cc = NP_PREVIEW_ACCENT
                -- Cast icon overlay
                if pv._castIconFrame then
                    local iconOv = CreateFrame("Button", nil, pv._cast:GetParent())
                    iconOv:SetAllPoints(pv._castIconFrame)
                    iconOv:SetFrameLevel(castOverlayLevel)
                    iconOv:RegisterForClicks("LeftButtonDown")
                    local ioBrd = KT.PP.CreateBorder(iconOv, cc.r, cc.g, cc.b, 1, 2, "OVERLAY", 7)
                    ioBrd:Hide()
                    iconOv:SetScript("OnEnter", function() ioBrd:Show() end)
                    iconOv:SetScript("OnLeave", function() ioBrd:Hide() end)
                    iconOv:SetScript("OnMouseDown", function() NavigateToSetting("castIcon") end)
                end
                -- Cast bar overlay (bar only, not icon)
                local castOverlay = CreateFrame("Button", nil, pv._cast:GetParent())
                castOverlay:SetAllPoints(pv._cast)
                castOverlay:SetFrameLevel(castOverlayLevel)
                castOverlay:RegisterForClicks("LeftButtonDown")
                local coBrd = KT.PP.CreateBorder(castOverlay, cc.r, cc.g, cc.b, 1, 2, "OVERLAY", 7)
                coBrd:Hide()
                castOverlay:SetScript("OnEnter", function() coBrd:Show() end)
                castOverlay:SetScript("OnLeave", function() coBrd:Hide() end)
                castOverlay:SetScript("OnMouseDown", function() NavigateToSetting("castBar") end)
            end
            -- Cast spell name and target text (above the cast bar overlay)
            local castTextLevel = (castOverlayLevel or 30) + 5
            if pv._castNameFS then
                local ov = CreateHitOverlay(pv._castNameFS, "castName", true, castTextLevel)
                textOverlays[#textOverlays + 1] = ov
            end
            if pv._castTargetFS then
                local ov = CreateHitOverlay(pv._castTargetFS, "castTarget", true, castTextLevel)
                textOverlays[#textOverlays + 1] = ov
            end
            -- Enemy name text
            if pv._nameFS then
                local ov = CreateHitOverlay(pv._nameFS, "enemyName", true)
                textOverlays[#textOverlays + 1] = ov
            end
            -- Health text
            if pv._hpText then
                local ov = CreateHitOverlay(pv._hpText, "healthText", true)
                textOverlays[#textOverlays + 1] = ov
            end
            if pv._hpNumber then
                local ov = CreateHitOverlay(pv._hpNumber, "healthNumber", true)
                textOverlays[#textOverlays + 1] = ov
            end
            -- Health bar
            if pv._health then
                CreateHitOverlay(pv._health, "healthBar")
            end
            -- Raid marker
            local raidOverlay
            if pv._raidFrame then
                raidOverlay = CreateHitOverlay(pv._raidFrame, "raidMarker")
                if not showRaidMarkerPreview then raidOverlay:Hide() end
            end
            -- Rare/elite icon
            local classOverlay
            if pv._classIcon then
                classOverlay = CreateHitOverlay(pv._classIcon, "classIcon")
                if not showClassificationPreview then classOverlay:Hide() end
            end
            -- Class resource pips wrapper button spanning all visible pips
            local cpOverlay
            if pv._cpPips then
                local firstVis, lastVis
                for i = 1, pv._cpMax do
                    if pv._cpPips[i] and pv._cpPips[i]:IsShown() then
                        if not firstVis then firstVis = pv._cpPips[i] end
                        lastVis = pv._cpPips[i]
                    end
                end
                -- Bar-type resource: use the bar frame as anchor
                local useBar      = (not firstVis) and pv._cpBar and pv._cpBar:IsShown()
                local anchorFirst = firstVis or (useBar and pv._cpBar)
                local anchorLast  = lastVis or (useBar and pv._cpBar)
                if anchorFirst and anchorLast then
                    local cpBtn = CreateFrame("Button", nil, pv)
                    cpBtn:SetPoint("TOPLEFT", anchorFirst, "TOPLEFT", -2, 2)
                    cpBtn:SetPoint("BOTTOMRIGHT", anchorLast, "BOTTOMRIGHT", 2, -2)
                    cpBtn:SetFrameLevel((pv._health and pv._health:GetFrameLevel() or 20) + 15)
                    cpBtn:RegisterForClicks("LeftButtonDown")
                    local cc = NP_PREVIEW_ACCENT
                    local function MkCPHL()
                        local t = cpBtn:CreateTexture(nil, "OVERLAY", nil, 7)
                        t:SetColorTexture(cc.r, cc.g, cc.b, 1)
                        if t.SetSnapToPixelGrid then
                            t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0)
                        end
                        return t
                    end
                    local cpPx = SnapPreview(2)
                    local cpt = MkCPHL(); cpt:SetHeight(cpPx); cpt:SetPoint("TOPLEFT"); cpt:SetPoint("TOPRIGHT")
                    local cpb = MkCPHL(); cpb:SetHeight(cpPx); cpb:SetPoint("BOTTOMLEFT"); cpb:SetPoint("BOTTOMRIGHT")
                    local cpl = MkCPHL(); cpl:SetWidth(cpPx); cpl:SetPoint("TOPLEFT", cpt, "BOTTOMLEFT"); cpl:SetPoint(
                    "BOTTOMLEFT", cpb, "TOPLEFT")
                    local cpr = MkCPHL(); cpr:SetWidth(cpPx); cpr:SetPoint("TOPRIGHT", cpt, "BOTTOMRIGHT"); cpr:SetPoint(
                    "BOTTOMRIGHT", cpb, "TOPRIGHT")
                    cpBtn._hlTextures = { cpt, cpb, cpl, cpr }
                    local function ShowCPHL() for _, t in ipairs(cpBtn._hlTextures) do t:Show() end end
                    local function HideCPHL() for _, t in ipairs(cpBtn._hlTextures) do t:Hide() end end
                    HideCPHL()
                    cpBtn:SetScript("OnEnter", function() ShowCPHL() end)
                    cpBtn:SetScript("OnLeave", function() HideCPHL() end)
                    cpBtn:SetScript("OnMouseDown", function() NavigateToSetting("classResource") end)
                    cpOverlay = cpBtn
                    -- Disable hover/click when class resource setting is off
                    local function UpdateCPOverlay()
                        local off = DBVal("showClassPower") ~= true
                        cpBtn:EnableMouse(not off)
                        cpBtn:SetAlpha(off and 0 or 1)
                    end
                    KT_RegisterWidgetRefresh(UpdateCPOverlay)
                    UpdateCPOverlay()
                end
            end
            -- Sync overlay visibility with preview toggles
            pv._raidOverlay = raidOverlay
            pv._classOverlay = classOverlay
            -- Target arrows wrapper button spanning both arrow textures
            local arrowOverlay
            if pv._arrows then
                local arrowBtn = CreateFrame("Button", nil, pv)
                arrowBtn:SetPoint("TOPLEFT", pv._arrows.left, "TOPLEFT", -2, 2)
                arrowBtn:SetPoint("BOTTOMRIGHT", pv._arrows.right, "BOTTOMRIGHT", 2, -2)
                arrowBtn:SetFrameLevel((pv._health and pv._health:GetFrameLevel() or 20) + 15)
                arrowBtn:RegisterForClicks("LeftButtonDown")
                local cc = NP_PREVIEW_ACCENT
                local function MkAHL()
                    local t = arrowBtn:CreateTexture(nil, "OVERLAY", nil, 7)
                    t:SetColorTexture(cc.r, cc.g, cc.b, 1)
                    if t.SetSnapToPixelGrid then
                        t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0)
                    end
                    return t
                end
                -- Highlight on left arrow
                local aPx = SnapPreview(2)
                local alt = MkAHL(); alt:SetHeight(aPx); alt:SetPoint("TOPLEFT", pv._arrows.left, -2, 2); alt:SetPoint(
                "TOPRIGHT", pv._arrows.left, 2, 2)
                local alb = MkAHL(); alb:SetHeight(aPx); alb:SetPoint("BOTTOMLEFT", pv._arrows.left, -2, -2); alb
                    :SetPoint("BOTTOMRIGHT", pv._arrows.left, 2, -2)
                local all = MkAHL(); all:SetWidth(aPx); all:SetPoint("TOPLEFT", alt, "BOTTOMLEFT"); all:SetPoint(
                "BOTTOMLEFT", alb, "TOPLEFT")
                local alr = MkAHL(); alr:SetWidth(aPx); alr:SetPoint("TOPRIGHT", alt, "BOTTOMRIGHT"); alr:SetPoint(
                "BOTTOMRIGHT", alb, "TOPRIGHT")
                -- Highlight on right arrow
                local art = MkAHL(); art:SetHeight(aPx); art:SetPoint("TOPLEFT", pv._arrows.right, -2, 2); art:SetPoint(
                "TOPRIGHT", pv._arrows.right, 2, 2)
                local arb = MkAHL(); arb:SetHeight(aPx); arb:SetPoint("BOTTOMLEFT", pv._arrows.right, -2, -2); arb
                    :SetPoint("BOTTOMRIGHT", pv._arrows.right, 2, -2)
                local arl = MkAHL(); arl:SetWidth(aPx); arl:SetPoint("TOPLEFT", art, "BOTTOMLEFT"); arl:SetPoint(
                "BOTTOMLEFT", arb, "TOPLEFT")
                local arr = MkAHL(); arr:SetWidth(aPx); arr:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT"); arr:SetPoint(
                "BOTTOMRIGHT", arb, "TOPRIGHT")
                arrowBtn._hlTextures = { alt, alb, all, alr, art, arb, arl, arr }
                local function ShowAHL() for _, t in ipairs(arrowBtn._hlTextures) do t:Show() end end
                local function HideAHL() for _, t in ipairs(arrowBtn._hlTextures) do t:Hide() end end
                HideAHL()
                arrowBtn:SetScript("OnEnter", function() ShowAHL() end)
                arrowBtn:SetScript("OnLeave", function() HideAHL() end)
                arrowBtn:SetScript("OnMouseDown", function() NavigateToSetting("targetArrows") end)
                -- Only show when arrows are visible
                if not pv._arrows.left:IsShown() then arrowBtn:Hide() end
                arrowOverlay = arrowBtn
            end
            pv._arrowOverlay = arrowOverlay
            -- Store text overlays for size refresh on preview update
            pv._textOverlays = textOverlays

        end

        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Colors page
    ---------------------------------------------------------------------------

    -- Shuffled spell icon pool for cast bar previews (reset each time Colors tab opens)
    local castIconPool = { 136197, 236802, 135808, 136116, 135735, 136048, 135812, 136075 }
    local castIconIdx = 0
    local function ShuffleCastIcons()
        castIconIdx = 0
        for i = #castIconPool, 2, -1 do
            local j = math.random(i)
            castIconPool[i], castIconPool[j] = castIconPool[j], castIconPool[i]
        end
    end
    local function NextCastIcon()
        castIconIdx = castIconIdx + 1
        if castIconIdx > #castIconPool then castIconIdx = 1 end
        return castIconPool[castIconIdx]
    end

    -- Cast fill values: each at least 5% apart, range 40 90%
    local castFillUsed = {}
    local function ResetCastFills()
        for i = #castFillUsed, 1, -1 do castFillUsed[i] = nil end
    end
    local function NextCastFill()
        for _ = 1, 50 do
            local v = 0.40 + math.random() * 0.20
            local ok = true
            for _, prev in ipairs(castFillUsed) do
                if math.abs(v - prev) < 0.05 then
                    ok = false; break
                end
            end
            if ok then
                castFillUsed[#castFillUsed + 1] = v
                return v
            end
        end
        -- fallback if somehow can't find a valid value
        local v = 0.40 + math.random() * 0.20
        castFillUsed[#castFillUsed + 1] = v
        return v
    end

    -- Mini preview bar builder for color swatches
    -- type: "health" or "cast" or "castLocked"
    -- colorKey: DB key for the bar color (read live)
    -- parentRow: the frame to attach to (ColorPicker row or DualRow half-region)
    -- anchorFrame: optional override anchor (e.g. DualRow half-region for positioning)
    local function MakeColorPreviewBar(parentRow, colorType, colorKey, anchorFrame)
        local MEDIA = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\"
        local isHalf = anchorFrame and true or false
        local BAR_W = isHalf and 161 or 180
        local BAR_H = 20
        local SWATCH_SZ = 24
        local SWATCH_GAP = isHalf and 27 or 52
        local fontPath = (KT and KT.GetNPFontPath and KT.GetNPFontPath("nameplates")) or
        DBVal("font")
        local anchor = anchorFrame or parentRow

        local container = CreateFrame("Frame", nil, parentRow)
        PP.Size(container, BAR_W + 2, BAR_H + 2) -- +2 for border
        -- Position: to the left of the swatch (swatch is at RIGHT -SIDE_PAD, 24px wide)
        PP.Point(container, "RIGHT", anchor, "RIGHT", -(20 + SWATCH_SZ + SWATCH_GAP), 0)
        container:SetFrameLevel(parentRow:GetFrameLevel() + 2)

        -- Simple 1px solid border using the user's nameplate border color.
        -- Uses two-point anchoring for pixel-perfect rendering inside the scroll frame.
        local function MakePreviewBorder(parent)
            local bc = (DB() and DB().borderColor) or defaults.borderColor
            local edges = {}
            local function mkE()
                local t = parent:CreateTexture(nil, "OVERLAY", nil, 7)
                t:SetColorTexture(bc.r, bc.g, bc.b, 1)
                edges[#edges + 1] = t
                return t
            end
            local t = mkE(); t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
            local b = mkE(); b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
            local l = mkE(); l:SetPoint("TOPLEFT", t, "BOTTOMLEFT"); l:SetPoint("BOTTOMLEFT", b, "TOPLEFT"); l:SetWidth(1)
            local r = mkE(); r:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT"); r:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT"); r
                :SetWidth(1)
            return edges
        end

        if colorType == "health" then
            -- Health bar preview: random fill 60-75%, colored by the swatch color
            local FAKE_MAX_HP = 10000
            local healthPct = math.floor(60 + math.random() * 15)
            local healthVal = math.floor(FAKE_MAX_HP * healthPct / 100)

            local health = CreateFrame("StatusBar", nil, container)
            health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            health:SetMinMaxValues(0, 100)
            health:SetValue(healthPct)
            health:SetAllPoints()

            local bg = health:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.20, 0.20, 0.20, 1.0)

            -- 1px solid border on a dedicated frame ABOVE the health StatusBar
            -- so the border renders on top (child frames cover parent textures).
            -- Parented to container (not health) so it stays at full opacity
            -- when the health bar is dimmed via SetDisabled.
            local brdFrame = CreateFrame("Frame", nil, container)
            brdFrame:SetAllPoints()
            brdFrame:SetFrameLevel(health:GetFrameLevel() + 2)
            local brdEdges = MakePreviewBorder(brdFrame)
            container._brdEdges = brdEdges
            container._health = health -- exposed for proxy color override / dimming

            -- Always create both FontStrings (shown/hidden dynamically)
            -- Parent them to a text frame ABOVE the overlay clips so focus
            -- texture never covers the health numbers.
            local textFrame = CreateFrame("Frame", nil, health)
            textFrame:SetAllPoints()
            textFrame:SetFrameLevel(health:GetFrameLevel() + 3)

            local pctFS = textFrame:CreateFontString(nil, "OVERLAY")
            local initHpSz = 10
            SetPVFont(pctFS, fontPath, initHpSz, GetNPOptOutline())
            pctFS:Hide()

            local numFS = textFrame:CreateFontString(nil, "OVERLAY")
            SetPVFont(numFS, fontPath, initHpSz, GetNPOptOutline())
            numFS:Hide()

            -- Full refresh: re-reads DB settings, repositions, updates text & values
            local function RefreshHealthText()
                local hpFS = 10
                -- Use the largest text slot size (capped at 13 for mini bars)
                for _, sk in ipairs({ "textSlotRight", "textSlotLeft", "textSlotCenter" }) do
                    local el = DBVal(sk) or defaults[sk]
                    if el and el ~= "none" and el ~= "enemyName" then
                        hpFS = math.min(DBVal(sk .. "Size") or defaults[sk .. "Size"] or 10, 13)
                        break
                    end
                end
                local curFont = (KT and KT.GetNPFontPath and KT.GetNPFontPath("nameplates")) or
                DBVal("font")
                local curOutline = GetNPOptOutline()

                -- Hide both FontStrings first
                SetPVFont(pctFS, curFont, hpFS, curOutline)
                pctFS:ClearAllPoints()
                pctFS:Hide()
                SetPVFont(numFS, curFont, hpFS, curOutline)
                numFS:ClearAllPoints()
                numFS:Hide()

                -- Bar slots: show health text based on slot assignments
                local barSlots = {
                    { key = "textSlotRight",  anchor = "RIGHT",  xOff = -2 },
                    { key = "textSlotLeft",   anchor = "LEFT",   xOff = 2 },
                    { key = "textSlotCenter", anchor = "CENTER", xOff = 0 },
                }
                for _, slot in ipairs(barSlots) do
                    local element = DBVal(slot.key) or defaults[slot.key]
                    local sc = (DB() and DB()[slot.key .. "Color"]) or defaults[slot.key .. "Color"]
                    if element == "healthPercent" or element == "healthPercentNoSign" then
                        pctFS:SetTextColor(sc.r, sc.g, sc.b, 1)
                        pctFS:SetText(element == "healthPercentNoSign" and tostring(healthPct) or (healthPct .. "%"))
                        pctFS:SetPoint(slot.anchor, health, slot.anchor, slot.xOff, 0)
                        pctFS:Show()
                    elseif element == "healthNumber" then
                        numFS:SetTextColor(sc.r, sc.g, sc.b, 1)
                        local valStr = tostring(healthVal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                        numFS:SetText(valStr)
                        numFS:SetPoint(slot.anchor, health, slot.anchor, slot.xOff, 0)
                        numFS:Show()
                    elseif element == "healthPctNum" then
                        local valStr = tostring(healthVal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                        pctFS:SetTextColor(sc.r, sc.g, sc.b, 1)
                        pctFS:SetText(healthPct .. "% | " .. valStr)
                        pctFS:SetPoint(slot.anchor, health, slot.anchor, slot.xOff, 0)
                        pctFS:Show()
                    elseif element == "healthNumPct" then
                        local valStr = tostring(healthVal):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
                        pctFS:SetTextColor(sc.r, sc.g, sc.b, 1)
                        pctFS:SetText(valStr .. " | " .. healthPct .. "%")
                        pctFS:SetPoint(slot.anchor, health, slot.anchor, slot.xOff, 0)
                        pctFS:Show()
                    end
                end
            end

            -- Run initial layout
            RefreshHealthText()

            -- Color the bar from the swatch's DB value
            local c = (DB() and DB()[colorKey]) or defaults[colorKey]
            health:SetStatusBarColor(c.r, c.g, c.b, 1)

            -- Focus overlay on the focus preview bar: clip frames for non-overlapping fixed-size textures
            local overlayFillClip, overlayFillTex, overlayBgClip, overlayBgTex

            -- Helper: create a clipped overlay frame+texture pair for the focus bar
            local function MakeOverlayClip(tlAnchor, tlRelPoint, brAnchor, brRelPoint, sublayer)
                local clip = CreateFrame("Frame", nil, health)
                clip:SetClipsChildren(true)
                clip:SetPoint("TOPLEFT", tlAnchor, tlRelPoint, 0, -1)
                clip:SetPoint("BOTTOMRIGHT", brAnchor, brRelPoint, 0, 1)
                clip:SetFrameLevel(health:GetFrameLevel() + 1)
                local tex = clip:CreateTexture(nil, "ARTWORK", nil, sublayer)
                tex:SetPoint("TOPLEFT", health, "TOPLEFT", 1, -1)
                tex:SetSize(BAR_W, BAR_H)
                return clip, tex
            end

            if colorKey == "focus" then
                local tex = DBVal("focusOverlayTexture") or defaults.focusOverlayTexture
                if tex ~= "none" then
                    local fillRef = health:GetStatusBarTexture()
                    local oAlpha = DBVal("focusOverlayAlpha") or defaults.focusOverlayAlpha
                    local oc = (DB() and DB().focusOverlayColor) or defaults.focusOverlayColor
                    overlayFillClip, overlayFillTex = MakeOverlayClip(fillRef, "TOPLEFT", fillRef, "BOTTOMRIGHT", 2)
                    overlayFillTex:SetTexture(MEDIA .. tex .. ".png")
                    overlayFillTex:SetAlpha(oAlpha)
                    overlayFillTex:SetVertexColor(oc.r, oc.g, oc.b)
                    overlayBgClip, overlayBgTex = MakeOverlayClip(fillRef, "TOPRIGHT", health, "BOTTOMRIGHT", 1)
                    overlayBgTex:SetTexture(MEDIA .. tex .. ".png")
                    overlayBgTex:SetAlpha(oAlpha * 0.3)
                    overlayBgTex:SetVertexColor(oc.r, oc.g, oc.b)
                end
            end

            -- Live update hook: re-color when swatch changes
            container.UpdateColor = function()
                local cc = (DB() and DB()[colorKey]) or defaults[colorKey]
                health:SetStatusBarColor(cc.r, cc.g, cc.b, 1)
            end
            -- Live update hook: refresh overlay texture from DB
            container.UpdateOverlay = function()
                if colorKey ~= "focus" then return end
                local tex = DBVal("focusOverlayTexture") or defaults.focusOverlayTexture
                if tex == "none" then
                    if overlayFillClip then overlayFillClip:Hide() end
                    if overlayBgClip then overlayBgClip:Hide() end
                else
                    local fillRef = health:GetStatusBarTexture()
                    local oAlpha = DBVal("focusOverlayAlpha") or defaults.focusOverlayAlpha
                    local oc = (DB() and DB().focusOverlayColor) or defaults.focusOverlayColor
                    if not overlayFillClip then
                        overlayFillClip, overlayFillTex = MakeOverlayClip(fillRef, "TOPLEFT", fillRef, "BOTTOMRIGHT", 2)
                    end
                    overlayFillTex:SetTexture(MEDIA .. tex .. ".png")
                    overlayFillTex:SetAlpha(oAlpha)
                    overlayFillTex:SetVertexColor(oc.r, oc.g, oc.b)
                    overlayFillClip:Show()
                    if not overlayBgClip then
                        overlayBgClip, overlayBgTex = MakeOverlayClip(fillRef, "TOPRIGHT", health, "BOTTOMRIGHT", 1)
                    end
                    overlayBgTex:SetTexture(MEDIA .. tex .. ".png")
                    overlayBgTex:SetAlpha(oAlpha * 0.3)
                    overlayBgTex:SetVertexColor(oc.r, oc.g, oc.b)
                    overlayBgClip:Show()
                end
            end
            container.Randomize = function()
                healthPct = math.floor(60 + math.random() * 15)
                healthVal = math.floor(FAKE_MAX_HP * healthPct / 100)
                health:SetValue(healthPct)
                RefreshHealthText()
            end
            -- Exposed so cache-restore / refresh-all can update text from current DB
            container.RefreshHealthText = RefreshHealthText
            container.RefreshBorderStyle = function() end -- no style toggle needed for 1px solid
            container.RefreshBorderColor = function()
                local bc = (DB() and DB().borderColor) or defaults.borderColor
                for _, tex in ipairs(container._brdEdges) do
                    tex:SetColorTexture(bc.r, bc.g, bc.b, 1)
                end
            end
        elseif colorType == "cast" or colorType == "castLocked" then
            PP.Size(container, BAR_W + 2, BAR_H + 2)

            local cast = CreateFrame("StatusBar", nil, container)
            cast:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            cast:SetMinMaxValues(0, 1)
            cast:SetValue(NextCastFill())
            cast:SetAllPoints()

            local castBG = cast:CreateTexture(nil, "BACKGROUND")
            castBG:SetAllPoints()
            castBG:SetColorTexture(0.20, 0.20, 0.20, 0.9)


            -- Spark
            local spark = cast:CreateTexture(nil, "OVERLAY", nil, 1)
            spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            spark:SetSize(8, BAR_H)
            spark:SetPoint("CENTER", cast:GetStatusBarTexture(), "RIGHT", 0, 0)
            spark:SetBlendMode("ADD")

            -- Cast icon frame (to the left) no border for Colors tab previews
            local iconFrame = CreateFrame("Frame", nil, cast)
            iconFrame:SetSize(BAR_H + 2, BAR_H + 2)
            iconFrame:SetPoint("RIGHT", cast, "LEFT", 0, 0)
            iconFrame:SetFrameLevel(cast:GetFrameLevel() + 1)
            local icon = iconFrame:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:SetTexture(NextCastIcon())

            -- Cast text
            local cns = math.min(DBVal("castNameSize") or defaults.castNameSize, 13)
            local cts = math.min(DBVal("castTargetSize") or defaults.castTargetSize, 13)
            local cnc = (DB() and DB().castNameColor) or defaults.castNameColor

            local nameFS = cast:CreateFontString(nil, "OVERLAY")
            SetPVFont(nameFS, fontPath, cns, GetNPOptOutline())
            nameFS:SetPoint("LEFT", cast, "LEFT", 5, 0)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetWordWrap(false)
            nameFS:SetMaxLines(1)
            nameFS:SetText(LText(isHalf and "Spell Name" or "Spell Name"))
            nameFS:SetTextColor(cnc.r, cnc.g, cnc.b, 1)

            local targetFS = cast:CreateFontString(nil, "OVERLAY")
            SetPVFont(targetFS, fontPath, cts, GetNPOptOutline())
            targetFS:SetPoint("RIGHT", cast, "RIGHT", -3, 0)
            targetFS:SetJustifyH("RIGHT")
            targetFS:SetWordWrap(false)
            targetFS:SetMaxLines(1)
            targetFS:SetText(isHalf and (UnitName("player") or "Target") or (UnitName("player") or "Spell Target"))
            local useClassColor = defaults.castTargetClassColor
            local dbRef = DB()
            if dbRef and dbRef.castTargetClassColor ~= nil then useClassColor = dbRef.castTargetClassColor end
            if useClassColor then
                local _, pClass = UnitClass("player")
                local c = pClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[pClass]
                if c then
                    targetFS:SetTextColor(c.r, c.g, c.b, 1)
                else
                    targetFS:SetTextColor(1, 1, 1, 1)
                end
            else
                local ctc = (dbRef and dbRef.castTargetColor) or defaults.castTargetColor
                targetFS:SetTextColor(ctc.r, ctc.g, ctc.b, 1)
            end

            -- Dynamic name width: fill available space minus target text minus 5px gap
            local tgtW = targetFS:GetUnboundedStringWidth()
            local nameMaxW = BAR_W - 5 - 3 - tgtW - 5
            if nameMaxW < 20 then nameMaxW = 20 end
            nameFS:SetWidth(nameMaxW)

            -- Shield for uninterruptible
            if colorType == "castLocked" then
                local shieldH = BAR_H * 0.75
                local shieldW = shieldH * (29 / 35)
                local shieldFrame = CreateFrame("Frame", nil, cast)
                shieldFrame:SetSize(shieldW, shieldH)
                shieldFrame:SetPoint("CENTER", cast, "LEFT", 0, 0)
                shieldFrame:SetFrameLevel(cast:GetFrameLevel() + 10)
                local shield = shieldFrame:CreateTexture(nil, "OVERLAY")
                shield:SetAllPoints()
                shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
            end

            -- Color the bar
            local c = (DB() and DB()[colorKey]) or defaults[colorKey]
            cast:SetStatusBarColor(c.r, c.g, c.b, 1)

            -- Shift container left to account for cast icon hanging outside
            container:ClearAllPoints()
            PP.Point(container, "RIGHT", anchor, "RIGHT", -(20 + SWATCH_SZ + SWATCH_GAP), 0)

            container.UpdateColor = function()
                local cc = (DB() and DB()[colorKey]) or defaults[colorKey]
                cast:SetStatusBarColor(cc.r, cc.g, cc.b, 1)
            end
            container.Randomize = function()
                cast:SetValue(NextCastFill())
                icon:SetTexture(NextCastIcon())
            end
            container.RefreshBorderStyle = function() end
            container.RefreshBorderColor = function() end
        end

        return container
    end

    local function BuildColorsPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local y = yOffset
        local _, h

        -- No content header on Colors tab (presets are inline in scroll area)
        -- KT: no content header

        -- Clear display preset hook (only active on Display page)
        onPresetSettingChanged = nil

        -- Enable per-row center divider for the dual-column layout (same as Display tab)
        parent._showRowDivider = true

        -- Track all mini previews for border style refresh
        _ktnpColorPreviews = {}
        local function TrackPreview(prev)
            if prev then _ktnpColorPreviews[#_ktnpColorPreviews + 1] = prev end
            return prev
        end

        -- Collect all lazy preview proxies for refresh registration
        local _colorPagePreviews = {}

        -- Lazy wrapper: defers MakeColorPreviewBar until the parent row is first shown.
        -- Returns a proxy table with UpdateColor/UpdateOverlay/RefreshBorderStyle/RefreshBorderColor
        -- that forward to the real preview bar once built.
        -- anchorFrame: optional override for positioning (e.g. DualRow half-region)
        local function LazyColorPreviewBar(parentRow, colorType, colorKey, anchorFrame)
            local real = nil
            local proxy = {}
            local _disabled = false
            local _colorOverrideFn = nil
            local function EnsureBuilt()
                if real then return real end
                real = MakeColorPreviewBar(parentRow, colorType, colorKey, anchorFrame)
                if _disabled and real._health then real._health:SetAlpha(0.3) end
                return real
            end
            -- Proxy methods: build on first call
            proxy.UpdateColor = function()
                local r = EnsureBuilt()
                if r and r.UpdateColor then
                    if _colorOverrideFn then
                        local cr, cg, cb = _colorOverrideFn()
                        if cr and r._health then
                            r._health:SetStatusBarColor(cr, cg, cb, 1)
                            return
                        end
                    end
                    r.UpdateColor()
                end
            end
            proxy.UpdateOverlay = function()
                local r = EnsureBuilt()
                if r and r.UpdateOverlay then r.UpdateOverlay() end
            end
            proxy.RefreshBorderStyle = function()
                if real and real.RefreshBorderStyle then real.RefreshBorderStyle() end
            end
            proxy.RefreshBorderColor = function()
                if real and real.RefreshBorderColor then real.RefreshBorderColor() end
            end
            proxy.Randomize = function()
                if real and real.Randomize then real.Randomize() end
            end
            proxy.RefreshHealthText = function()
                if real and real.RefreshHealthText then real.RefreshHealthText() end
            end
            proxy.SetDisabled = function(off)
                _disabled = off
                if real and real._health then
                    real._health:SetAlpha(off and 0.3 or 1)
                end
            end
            proxy.SetColorOverride = function(fn)
                _colorOverrideFn = fn
            end
            -- Build when parent row becomes visible (first scroll into view)
            parentRow:HookScript("OnShow", function()
                if not real then
                    EnsureBuilt()
                    _ktnpColorPreviews[#_ktnpColorPreviews + 1] = real
                end
                -- Re-apply disabled state every time the row becomes visible,
                -- in case SetDisabled was called before the bar was built.
                if real and real._health then
                    real._health:SetAlpha(_disabled and 0.3 or 1)
                end
            end)
            -- If the row is already visible (top of page), build immediately
            if parentRow:IsVisible() then
                EnsureBuilt()
            end
            _colorPagePreviews[#_colorPagePreviews + 1] = proxy
            return proxy
        end

        -- Shuffle cast icons and fills so each preview is unique
        -- ShuffleCastIcons()  -- disabled: no cast previews on Colors page
        -- ResetCastFills()    -- disabled: no cast previews on Colors page

        --[[ COLOR PRESET SYSTEM (disabled kept for future use)
        -- Color preset keys
        local colorPresetKeys = {
            "focusColorEnabled", "focus", "focusOverlayTexture", "focusOverlayAlpha", "focusOverlayColor", "caster", "miniboss", "enemyInCombat",
            "castBar", "interruptReady",
            "tankHasAggroEnabled", "tankHasAggro", "tankLosingAggro", "tankOtherTankHasAggro", "tankNoAggro",
            "dpsHasAggro", "dpsNearAggro",
        }

        local function RandomizeColorSettings(db)
            local function rColor() return { r = math.random(), g = math.random(), b = math.random() } end
            for _, key in ipairs(colorPresetKeys) do
                if key == "focusColorEnabled" or key == "tankHasAggroEnabled" then
                    db[key] = true  -- always enable during randomize so user can see the color
                elseif key ~= "focusOverlayTexture" and key ~= "focusOverlayAlpha" and key ~= "focusOverlayColor" then
                    db[key] = rColor()
                end
            end
        end

        -- Inline preset system at top of scroll area (no content header)
        local checkDrift, presetH = KT:BuildPresetSystem({
            presetKeys  = colorPresetKeys,
            dbFunc      = DB,
            dbValFunc   = DBVal,
            defaults    = defaults,
            dbPrefix    = "_color",
            randomizeFn = RandomizeColorSettings,
            refreshFn   = function()
                RefreshAllPlates()
            end,
            inlineParent = parent,
            yOffset      = y,
        })
        onColorPresetSettingChanged = checkDrift
        _colorPresetCheckDrift = checkDrift
        y = y - presetH

        -- Hook RefreshAllPlates to auto-detect color drift (same pattern as Display's UpdatePreview hook)
        if not _refreshAllPlatesHooked then
            _refreshAllPlatesHooked = true
            local _origRefreshAllPlates = RefreshAllPlates
            RefreshAllPlates = function()
                _origRefreshAllPlates()
                if onColorPresetSettingChanged then onColorPresetSettingChanged() end
            end
        end
        --]]

        local focusPrev

        _, h = W:Label(parent,
            "Threat colors are configured further down on this page. You can also jump straight to the dedicated Threat tab.",
            y, 10, { r = 0.82, g = 0.82, b = 0.86 }); y = y - h

        _, h = W:Button(parent, "Open Threat Tab", y, function()
            KT._npOptionsActiveTab = PAGE_THREAT
            if KT.RefreshPage then KT:RefreshPage() end
        end); y = y - h

        _, h = W:Spacer(parent, y, 10); y = y - h

        -----------------------------------------------------------------------
        --  ENEMY COLORS
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_ENEMY, y); y = y - h

        local function isFocusColorDisabled()
            local db = DB()
            if db and db.focusColorEnabled ~= nil then return not db.focusColorEnabled end
            return not defaults.focusColorEnabled
        end

        local function isFocusTextureNone()
            return (DBVal("focusOverlayTexture") or defaults.focusOverlayTexture) == "none"
        end

        -- Enemy Types ---- KullThran UI
        local enemyFocusDualFrame
        enemyFocusDualFrame, h = W:DualRow(parent, y,
            {
                type = "multiSwatch",
                text = LText("Enemy Types"),
                swatches = {
                    {
                        tooltip = "Enemies",
                        getValue = function() return DBColor("enemyInCombat") end,
                        setValue = function(r, g, b)
                            DB().enemyInCombat = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "Spell Casters",
                        getValue = function() return DBColor("caster") end,
                        setValue = function(r, g, b)
                            DB().caster = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "Mini-Bosses",
                        getValue = function() return DBColor("miniboss") end,
                        setValue = function(r, g, b)
                            DB().miniboss = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                }
            },
            {
                type = "toggle",
                text = LText("Focus Color"),
                getValue = function()
                    local db = DB()
                    if db and db.focusColorEnabled ~= nil then return db.focusColorEnabled end
                    return defaults.focusColorEnabled
                end,
                setValue = function(v)
                    DB().focusColorEnabled = v
                    RefreshAllPlates()
                    if focusPrev then
                        if v then
                            focusPrev.SetColorOverride(nil)
                        else
                            focusPrev.SetColorOverride(function() return DBColor("enemyInCombat") end)
                        end
                        focusPrev.UpdateColor()
                        focusPrev.SetDisabled(not v)
                    end
                    KT:RefreshPage()
                end
            }); y = y - h

        -- Inline Focus Color swatch next to Enable Focus Color toggle
        do
            local rightRgn = enemyFocusDualFrame._rightRegion
            local focusColorGet = function() return DBColor("focus") end
            local focusColorSet = function(r, g, b)
                DB().focus = { r = r, g = g, b = b }
                RefreshAllPlates()
                if focusPrev then focusPrev.UpdateColor() end
            end
            local swatch, updateSwatch = KT_BuildColorSwatch(rightRgn, rightRgn:GetFrameLevel() + 5,
                focusColorGet, focusColorSet, nil, 20)
            -- Keep Focus controls inside their own half of the DualRow. The old
            -- anchor used the toggle's left edge and crossed into Enemy Types.
            PP.Point(swatch, "RIGHT", rightRgn, "RIGHT", -10, 0)
            if rightRgn._control and rightRgn._control.SetReservedRightSpace then
                rightRgn._control:SetReservedRightSpace(34)
            end
            KT_RegisterWidgetRefresh(function()
                local off = isFocusColorDisabled()
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            local off = isFocusColorDisabled()
            swatch:SetAlpha(off and 0.15 or 1)
            swatch:EnableMouse(not off)
        end

        -- Focus Texture ---- Focus Preview
        local focusPreviewRow
        focusPreviewRow, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Focus Texture"),
                values = { ["striped-v2"] = "Stripes", ["striped-wide-v2"] = "Wide Stripes", none = "None" },
                getValue = function() return DBVal("focusOverlayTexture") or defaults.focusOverlayTexture end,
                setValue = function(v)
                    DB().focusOverlayTexture = v
                    RefreshAllPlates()
                    if focusPrev and focusPrev.UpdateOverlay then focusPrev.UpdateOverlay() end
                    KT:RefreshPage()
                end,
                order = { "striped-v2", "striped-wide-v2", "none" }
            },
            { type = "label", text = LText("Focus Preview") }); y = y - h

        -- Inline texture color swatch next to Focus Texture dropdown
        do
            local leftRgn = focusPreviewRow._leftRegion
            local focusTexColorGet = function()
                local c = (DB() and DB().focusOverlayColor) or defaults.focusOverlayColor
                return c.r, c.g, c.b
            end
            local focusTexColorSet = function(r, g, b)
                DB().focusOverlayColor = { r = r, g = g, b = b }
                RefreshAllPlates()
                if focusPrev and focusPrev.UpdateOverlay then focusPrev.UpdateOverlay() end
            end
            local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5,
                focusTexColorGet, focusTexColorSet, nil, 20)
            PP.Point(swatch, "RIGHT", leftRgn, "RIGHT", -45, 0)
            leftRgn._lastInline = swatch
            KT_RegisterWidgetRefresh(function()
                local off = isFocusTextureNone()
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            local off = isFocusTextureNone()
            swatch:SetAlpha(off and 0.15 or 1)
            swatch:EnableMouse(not off)

            -- Cog popup for Texture Opacity next to the color swatch
            local _, cogShowFn = KT.BuildCogPopup({
                title = "Focus Texture Settings",
                rows = {
                    {
                        type = "slider",
                        label = "Opacity",
                        min = 0,
                        max = 1.0,
                        step = 0.05,
                        get = function() return DBVal("focusOverlayAlpha") or defaults.focusOverlayAlpha end,
                        set = function(v)
                            DB().focusOverlayAlpha = v
                            RefreshAllPlates()
                            if focusPrev and focusPrev.UpdateOverlay then focusPrev.UpdateOverlay() end
                        end
                    },
                },
            })
            local cogBtn = CreateFrame("Button", nil, leftRgn)
            cogBtn:SetSize(26, 26)
            PP.Point(cogBtn, "RIGHT", leftRgn, "RIGHT", -10, 0)
            cogBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 6)
            local cogIcon = cogBtn:CreateTexture(nil, "OVERLAY")
            cogIcon:SetAllPoints()
            cogIcon:SetTexture((KT and KT.RESIZE_ICON) or "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png")
            ApplyNPAccentToIcon(cogIcon)
            cogIcon:SetAlpha(0.4)
            cogBtn:SetScript("OnEnter", function() cogIcon:SetAlpha(0.7) end)
            cogBtn:SetScript("OnLeave", function() cogIcon:SetAlpha(0.4) end)
            cogBtn:SetScript("OnClick", function(self) cogShowFn(self) end)
            if leftRgn._control and leftRgn._control.SetReservedRightSpace then
                leftRgn._control:SetReservedRightSpace(76)
            end
            KT_RegisterWidgetRefresh(function()
                local off = isFocusTextureNone()
                cogBtn:SetAlpha(off and 0.15 or 1)
                cogBtn:EnableMouse(not off)
            end)
            cogBtn:SetAlpha(isFocusTextureNone() and 0.15 or 1)
            cogBtn:EnableMouse(not isFocusTextureNone())
        end

        -- Focus preview bar anchored so its right edge aligns with the
        -- Enable Focus Color toggle's right edge (SIDE_PAD = 20 from region edge).
        -- MakeColorPreviewBar positions the bar at -(20+24+27) = -71 to leave room
        -- for a swatch; we override that to -20 since there's no swatch here.
        focusPrev = LazyColorPreviewBar(focusPreviewRow, "health", "focus", focusPreviewRow._rightRegion)
        do
            local function RepositionFocusBar()
                local rgn = focusPreviewRow._rightRegion
                for _, child in ipairs({ focusPreviewRow:GetChildren() }) do
                    if child.GetNumPoints and child:GetNumPoints() > 0 then
                        local _, rel = child:GetPoint(1)
                        if rel == rgn then
                            child:ClearAllPoints()
                            PP.Point(child, "RIGHT", rgn, "RIGHT", -20, 0)
                            return
                        end
                    end
                end
            end
            -- Reposition on every show (handles scroll-in visibility)
            focusPreviewRow:HookScript("OnShow", RepositionFocusBar)
            -- Also reposition immediately if the row is already visible
            -- (the lazy builder may have already created the bar)
            C_Timer.After(0, RepositionFocusBar)
        end
        if isFocusColorDisabled() then
            focusPrev.SetColorOverride(function() return DBColor("enemyInCombat") end)
        end
        focusPrev.SetDisabled(isFocusColorDisabled())
        focusPrev.UpdateColor()

        _, h = W:Spacer(parent, y, 16); y = y - h

        -----------------------------------------------------------------------
        --  QUICK THREAT COLORS
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "QUICK THREAT COLORS", y); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "multiSwatch",
                text = LText("Tank Threat"),
                swatches = {
                    {
                        tooltip = "Has Aggro",
                        getValue = function() return DBColor("tankHasAggro") end,
                        setValue = function(r, g, b)
                            DB().tankHasAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "Losing Aggro",
                        getValue = function() return DBColor("tankLosingAggro") end,
                        setValue = function(r, g, b)
                            DB().tankLosingAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "Other Tank Has Aggro",
                        getValue = function() return DBColor("tankOtherTankHasAggro") end,
                        setValue = function(r, g, b)
                            DB().tankOtherTankHasAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "No Aggro",
                        getValue = function() return DBColor("tankNoAggro") end,
                        setValue = function(r, g, b)
                            DB().tankNoAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                }
            },
            {
                type = "multiSwatch",
                text = LText("Non-Tank Threat"),
                swatches = {
                    {
                        tooltip = "Has Aggro",
                        getValue = function() return DBColor("dpsHasAggro") end,
                        setValue = function(r, g, b)
                            DB().dpsHasAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "Near Aggro",
                        getValue = function() return DBColor("dpsNearAggro") end,
                        setValue = function(r, g, b)
                            DB().dpsNearAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                }
            }); y = y - h

        local quickThreatRow
        quickThreatRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enable Tank 'Has Aggro' Color"),
                tooltip = "Shows a special color for non caster/mini-boss enemies when you have aggro on them.",
                getValue = function()
                    local db = DB()
                    if db and db.tankHasAggroEnabled ~= nil then return db.tankHasAggroEnabled end
                    return defaults.tankHasAggroEnabled
                end,
                setValue = function(v)
                    DB().tankHasAggroEnabled = v
                    RefreshAllPlates()
                    KT:RefreshPage()
                end
            },
            {
                type = "button",
                text = LText("Open Threat Tab"),
                onClick = function()
                    KT._npOptionsActiveTab = PAGE_THREAT
                    if KT.RefreshPage then KT:RefreshPage() end
                end
            }); y = y - h

        do
            local leftRgn = quickThreatRow._leftRegion
            local quickTankAggroColorGet = function() return DBColor("tankHasAggro") end
            local quickTankAggroColorSet = function(r, g, b)
                DB().tankHasAggro = { r = r, g = g, b = b }
                RefreshAllPlates()
            end
            local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5,
                quickTankAggroColorGet, quickTankAggroColorSet, nil, 20)
            PP.Point(swatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                local db = DB()
                local off = not ((db and db.tankHasAggroEnabled ~= nil and db.tankHasAggroEnabled) or defaults.tankHasAggroEnabled)
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
        end

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  CAST BAR
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, "CAST BAR COLORS", y); y = y - h

        -- Cast Bar state colors ---- Show Tick at Kick Ready Spot
        _, h = W:DualRow(parent, y,
            {
                type = "multiSwatch",
                text = LText("Interruptible | On CD | Uninterruptible"),
                swatches = {
                    {
                        tooltip = "Interruptible Cast",
                        getValue = function() return GetResolvedCastBarColor("interruptible") end,
                        setValue = function(r, g, b) ApplyCastBarStateColor("interruptible", r, g, b) end
                    },
                    {
                        tooltip = "Interrupt On CD",
                        getValue = function() return GetResolvedCastBarColor("cooldown") end,
                        setValue = function(r, g, b) ApplyCastBarStateColor("cooldown", r, g, b) end
                    },
                    {
                        tooltip = "Uninterruptible",
                        getValue = function() return GetResolvedCastBarColor("uninterruptible") end,
                        setValue = function(r, g, b) ApplyCastBarStateColor("uninterruptible", r, g, b) end
                    },
                }
            },
            {
                type = "toggle",
                text = LText("Show Tick at Kick Ready Spot"),
                tooltip =
                "Shows a small white tick mark on the cast bar at the point where the cast will be when your interrupt comes off cooldown.",
                getValue = function()
                    local db = DB()
                    if db and db.kickTickEnabled ~= nil then return db.kickTickEnabled end
                    return true
                end,
                setValue = function(v)
                    DB().kickTickEnabled = v
                end
            }); y = y - h

        _, h = W:Spacer(parent, y, 20); y = y - h

        -----------------------------------------------------------------------
        --  THREAT COLORS (INSTANCES ONLY)
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_THREAT, y); y = y - h

        -- Row 1: Tank Threat (left) ---- Non-Tank Threat (right)
        _, h = W:DualRow(parent, y,
            {
                type = "multiSwatch",
                text = LText("Tank Threat"),
                swatches = {
                    {
                        tooltip = "Losing Aggro",
                        getValue = function() return DBColor("tankLosingAggro") end,
                        setValue = function(r, g, b)
                            DB().tankLosingAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "Other Tank Has Aggro",
                        getValue = function() return DBColor("tankOtherTankHasAggro") end,
                        setValue = function(r, g, b)
                            DB().tankOtherTankHasAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "No Aggro",
                        getValue = function() return DBColor("tankNoAggro") end,
                        setValue = function(r, g, b)
                            DB().tankNoAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                }
            },
            {
                type = "multiSwatch",
                text = LText("Non-Tank Threat"),
                swatches = {
                    {
                        tooltip = "Has Aggro",
                        getValue = function() return DBColor("dpsHasAggro") end,
                        setValue = function(r, g, b)
                            DB().dpsHasAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                    {
                        tooltip = "Near Aggro",
                        getValue = function() return DBColor("dpsNearAggro") end,
                        setValue = function(r, g, b)
                            DB().dpsNearAggro = { r = r, g = g, b = b }
                            RefreshAllPlates()
                        end
                    },
                }
            }); y = y - h

        -- Row 2: Show Special "Has Aggro" Color (left) ---- blank (right)
        local function isTankHasAggroDisabled()
            local db = DB()
            if db and db.tankHasAggroEnabled ~= nil then return not db.tankHasAggroEnabled end
            return not defaults.tankHasAggroEnabled
        end

        local tankDualFrame
        tankDualFrame, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Show Special \"Has Aggro\" Color"),
                tooltip = "Shows a special color for non caster/mini-boss enemies when you have aggro on them.",
                getValue = function()
                    local db = DB()
                    if db and db.tankHasAggroEnabled ~= nil then return db.tankHasAggroEnabled end
                    return defaults.tankHasAggroEnabled
                end,
                setValue = function(v)
                    DB().tankHasAggroEnabled = v
                    RefreshAllPlates()
                    KT:RefreshPage()
                end
            },
            { type = "label", text = "" }); y = y - h

        -- Inline Tank Has Aggro color swatch next to toggle
        do
            local leftRgn = tankDualFrame._leftRegion
            local tankAggroColorGet = function() return DBColor("tankHasAggro") end
            local tankAggroColorSet = function(r, g, b)
                DB().tankHasAggro = { r = r, g = g, b = b }
                RefreshAllPlates()
            end
            local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5,
                tankAggroColorGet, tankAggroColorSet, nil, 20)
            PP.Point(swatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                local off = isTankHasAggroDisabled()
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            local off = isTankHasAggroDisabled()
            swatch:SetAlpha(off and 0.15 or 1)
            swatch:EnableMouse(not off)
        end

        -----------------------------------------------------------------------
        --  OTHER COLORS
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, SECTION_OTHER, y); y = y - h

        -- Row 1: Quest Mob Color (left only, right empty)
        local function questMobColorOff()
            return DBVal("questMobColorEnabled") ~= true
        end

        local questMobRow
        questMobRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enable Quest Mob Color"),
                getValue = function() return DBVal("questMobColorEnabled") == true end,
                setValue = function(v)
                    DB().questMobColorEnabled = v
                    for _, plate in pairs(ns.plates) do
                        plate:UpdateHealthColor()
                    end
                    KT:RefreshPage()
                end,
                tooltip = "Colors enemy nameplates for quest mobs you still need to kill."
            },
            nil); y = y - h

        -- Inline color swatch on the quest mob toggle
        do
            local leftRgn = questMobRow._leftRegion
            local qmColorGet = function()
                local c = DB().questMobColor or defaults.questMobColor
                return c.r, c.g, c.b
            end
            local qmColorSet = function(r, g, b)
                DB().questMobColor = { r = r, g = g, b = b }
                for _, plate in pairs(ns.plates) do
                    plate:UpdateHealthColor()
                end
            end
            local qmSwatch, qmUpdateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5,
                qmColorGet, qmColorSet, nil, 20)
            PP.Point(qmSwatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
            leftRgn._lastInline = qmSwatch
            KT_RegisterWidgetRefresh(function()
                local off = questMobColorOff()
                qmSwatch:SetAlpha(off and 0.15 or 1)
                qmSwatch:EnableMouse(not off)
                qmUpdateSwatch()
            end)
            qmSwatch:SetAlpha(questMobColorOff() and 0.15 or 1)
            qmSwatch:EnableMouse(not questMobColorOff())
            qmSwatch:SetScript("OnEnter", function(self)
                if questMobColorOff() then
                    KT_ShowWidgetTooltip(self, KT_DisabledTooltip("Enable Quest Mob Color"))
                end
            end)
            qmSwatch:SetScript("OnLeave", function(self)
                KT_HideWidgetTooltip()
            end)
        end

        -- Build a refresh-all function for page cache restore
        _colorPreviewRefreshAll = function()
            for _, prev in ipairs(_ktnpColorPreviews or {}) do
                if prev.UpdateColor then prev.UpdateColor() end
                if prev.UpdateOverlay then prev.UpdateOverlay() end
                if prev.RefreshBorderColor then prev.RefreshBorderColor() end
                if prev.RefreshHealthText then prev.RefreshHealthText() end
            end
            for _, prev in ipairs(_colorPagePreviews) do
                if prev.UpdateColor then prev.UpdateColor() end
                if prev.UpdateOverlay then prev.UpdateOverlay() end
                if prev.RefreshBorderColor then prev.RefreshBorderColor() end
                if prev.RefreshHealthText then prev.RefreshHealthText() end
            end
        end
        _colorPreviewRandomizeAll = nil
        for _, prev in ipairs(_colorPagePreviews) do
            if prev.UpdateColor then
                KT_RegisterWidgetRefresh(prev.UpdateColor)
            end
            if prev.UpdateOverlay then
                KT_RegisterWidgetRefresh(prev.UpdateOverlay)
            end
        end

        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Threat page  (coloring priorities + threat/unit-type colors)
    ---------------------------------------------------------------------------
    local function BuildThreatPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local y = yOffset
        local _, h

        parent._showRowDivider = true

        local function RefreshThreatColors()
            for _, plate in pairs(plates or {}) do
                if plate.UpdateHealthColor then plate:UpdateHealthColor() end
            end
            UpdatePreview()
        end

        local function CGet(key)
            local c = (DB() and DB()[key]) or defaults[key]
            if type(c) ~= "table" then return 1, 1, 1 end
            return c.r or 1, c.g or 1, c.b or 1
        end
        local function CSet(key, r, g, b)
            DB()[key] = { r = r, g = g, b = b }
            RefreshThreatColors()
        end

        local function BoolGet(key, fallback)
            if DBVal(key) ~= nil then return DBVal(key) end
            return fallback
        end

        local function BoolSet(key, v)
            DB()[key] = v
            RefreshThreatColors()
            KT:RefreshPage()
        end

        local function MakeSwatchRow(labelText, colorKey, disabledFn)
            local row
            row, h = W:Label(parent, labelText, y, 11, { r = 0.75, g = 0.75, b = 0.75 }); y = y - h
            local swatch, updateSwatch = KT_BuildColorSwatch(row, row:GetFrameLevel() + 5,
                function() return CGet(colorKey) end,
                function(r, g, b) CSet(colorKey, r, g, b) end,
                nil,
                20)
            PP.Point(swatch, "RIGHT", row, "RIGHT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                if disabledFn then
                    local off = disabledFn()
                    swatch:SetAlpha(off and 0.15 or 1)
                    swatch:EnableMouse(not off)
                end
                updateSwatch()
            end)
            if disabledFn then
                local off = disabledFn()
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
            end
            return row
        end

        local threatHeader
        threatHeader, h = W:SectionHeader(parent, "COLORS / THREAT", y); y = y - h

        local modifiesRow
        modifiesRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Health Bar Color"),
                getValue = function() return DBVal("threatModHealth") ~= false end,
                setValue = function(v) BoolSet("threatModHealth", v) end
            },
            {
                type = "toggle",
                text = LText("Border Color"),
                getValue = function() return DBVal("threatModBorder") == true end,
                setValue = function(v) BoolSet("threatModBorder", v) end
            }); y = y - h

        local modifiesRow2
        modifiesRow2, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Name Color"),
                getValue = function() return DBVal("threatModName") == true end,
                setValue = function(v) BoolSet("threatModName", v) end
            },
            {
                type = "toggle",
                text = LText("Use 'Solo' color"),
                getValue = function() return DBVal("threatUseSoloColor") == true end,
                setValue = function(v) BoolSet("threatUseSoloColor", v) end
            }); y = y - h

        -- Solo color swatch inline on the right control
        do
            local rightRgn = modifiesRow2._rightRegion
            local swatch, updateSwatch = KT_BuildColorSwatch(rightRgn, rightRgn:GetFrameLevel() + 5,
                function() return CGet("threatSoloColor") end,
                function(r, g, b) CSet("threatSoloColor", r, g, b) end,
                nil,
                20)
            PP.Point(swatch, "RIGHT", rightRgn._control, "LEFT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                local off = DBVal("threatUseSoloColor") ~= true
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            local off = DBVal("threatUseSoloColor") ~= true
            swatch:SetAlpha(off and 0.15 or 1)
            swatch:EnableMouse(not off)
        end

        _, h = W:Spacer(parent, y, 12); y = y - h

        local tankHeader
        tankHeader, h = W:SectionHeader(parent, "COLOR WHEN PLAYING AS TANK", y); y = y - h
        MakeSwatchRow("Aggro on You", "tankHasAggro")
        MakeSwatchRow("Aggro on You But is Low", "tankLosingAggro")
        MakeSwatchRow("Other Tank Has Aggro", "tankOtherTankHasAggro")
        MakeSwatchRow("No Aggro", "tankNoAggro")

        _, h = W:Spacer(parent, y, 12); y = y - h

        local dpsHeader
        dpsHeader, h = W:SectionHeader(parent, "COLOR WHEN PLAYING AS DPS OR HEALER", y); y = y - h
        MakeSwatchRow("Aggro on You", "dpsHasAggro")
        MakeSwatchRow("High Threat", "dpsNearAggro")
        MakeSwatchRow("No Aggro", "dpsNoAggro")

        _, h = W:Spacer(parent, y, 12); y = y - h

        local overrideHeader
        overrideHeader, h = W:SectionHeader(parent, "OVERRIDE DEFAULT COLORS", y); y = y - h

        local overrideRow
        overrideRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enabled"),
                getValue = function() return DBVal("colorOverrideEnabled") == true end,
                setValue = function(v) BoolSet("colorOverrideEnabled", v) end
            },
            { type = "label", text = "" }); y = y - h

        local function OverrideOff() return DBVal("colorOverrideEnabled") ~= true end
        MakeSwatchRow("Hostile", "hostile", OverrideOff)
        MakeSwatchRow("Neutral", "neutral", OverrideOff)
        MakeSwatchRow("Friendly", "friendly", OverrideOff)
        MakeSwatchRow("Unit Not In Combat", "enemyOutOfCombat", OverrideOff)
        MakeSwatchRow("Unit Tapped", "tapped", OverrideOff)

        _, h = W:Spacer(parent, y, 12); y = y - h

        local miscHeader
        miscHeader, h = W:SectionHeader(parent, "MISC", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enable aggro flash"),
                getValue = function() return DBVal("showAggroFlash") == true end,
                setValue = function(v) BoolSet("showAggroFlash", v) end
            },
            {
                type = "toggle",
                text = LText("Enable health bar aggro glow"),
                getValue = function() return DBVal("showAggroGlow") == true end,
                setValue = function(v) BoolSet("showAggroGlow", v) end
            }); y = y - h

        _, h = W:Spacer(parent, y, 12); y = y - h

        local unitTypeHeader
        unitTypeHeader, h = W:SectionHeader(parent, "UNIT TYPE COLORING", y); y = y - h

        local typeRow
        typeRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enabled"),
                getValue = function() return DBVal("unitTypeColoringEnabled") ~= false end,
                setValue = function(v) BoolSet("unitTypeColoringEnabled", v) end
            },
            {
                type = "toggle",
                text = LText("Don't override Threat colors"),
                getValue = function() return DBVal("unitTypeColoringNoOverrideThreat") ~= false end,
                setValue = function(v) BoolSet("unitTypeColoringNoOverrideThreat", v) end
            }); y = y - h

        local function UnitTypeOff() return DBVal("unitTypeColoringEnabled") == false end
        MakeSwatchRow("Boss", "boss", UnitTypeOff)
        MakeSwatchRow("Miniboss", "miniboss", UnitTypeOff)
        MakeSwatchRow("Caster", "caster", UnitTypeOff)

        local eliteRow
        eliteRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enable elite"),
                getValue = function() return DBVal("unitTypeColoringEnableElite") == true end,
                setValue = function(v) BoolSet("unitTypeColoringEnableElite", v) end
            },
            {
                type = "toggle",
                text = LText("Enable trivial"),
                getValue = function() return DBVal("unitTypeColoringEnableTrivial") == true end,
                setValue = function(v) BoolSet("unitTypeColoringEnableTrivial", v) end
            }); y = y - h

        local function EliteOff()
            return UnitTypeOff() or (DBVal("unitTypeColoringEnableElite") ~= true)
        end
        local function TrivialOff()
            return UnitTypeOff() or (DBVal("unitTypeColoringEnableTrivial") ~= true)
        end
        MakeSwatchRow("Elite", "elite", EliteOff)
        MakeSwatchRow("Trivial", "trivial", TrivialOff)

        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Special / Auto / Advanced pages
    ---------------------------------------------------------------------------
    local function BuildSpecialPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local y = yOffset
        local _, h
        parent._showRowDivider = true
        _, h = W:SectionHeader(parent, "BUFF SPECIAL", y); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enabled"),
                getValue = function() return DBVal("specialAurasEnabled") == true end,
                setValue = function(v)
                    DB().specialAurasEnabled = v
                    UpdatePreview()
                    KT:RefreshPage()
                end
            },
            { type = "label", text = "" }); y = y - h

        _, h = W:Label(parent,
            "Paste Spell IDs (one per line). Click Apply to rebuild the Special Auras list.\n" ..
            "Example:\n339\n8921\n774",
            y, 11, { r = 0.65, g = 0.65, b = 0.65 }); y = y - h

        local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
        box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
        box:SetHeight(160)
        KT:AddBackdrop(box, 0.06, 0.06, 0.07, 1)
        KT:AddBorder(box, 0.20, 0.20, 0.24, 0.9)

        local edit = CreateFrame("EditBox", nil, box)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFont(KT.FONT_PATH, 11, "OUTLINE")
        edit:SetTextColor(1, 1, 1, 1)
        edit:SetPoint("TOPLEFT", 10, -10)
        edit:SetPoint("BOTTOMRIGHT", -10, 10)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        local function NormalizeSpecialInput(s)
            s = tostring(s or "")
            s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
            s = s:gsub("[ \t]+", " ")
            return s
        end

        local function BuildSpecialSetFromText(s)
            local set = {}
            for id in tostring(s or ""):gmatch("(%d+)") do
                local n = tonumber(id)
                if n and n > 0 then set[n] = true end
            end
            return set
        end

        local cur = DBVal("specialAurasInput") or ""
        edit:SetText(NormalizeSpecialInput(cur))
        edit:SetScript("OnTextChanged", function(self)
            DB().specialAurasInput = NormalizeSpecialInput(self:GetText())
        end)

        y = y - (box:GetHeight() + 10)

        local btnRow = CreateFrame("Frame", nil, parent)
        btnRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
        btnRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
        btnRow:SetHeight(34)

        local function StyleSpecialButton(btn, accent)
            btn:SetPushedTextOffset(0, 0)
            btn:SetMotionScriptsWhileDisabled(true)

            local label = btn:CreateFontString(nil, "OVERLAY")
            label:SetFont(KT.FONT_PATH, 11, "OUTLINE")
            label:SetPoint("CENTER")
            btn.txt = label

            local function RefreshVisual(state)
                local bg = { 0.06, 0.06, 0.07, 1 }
                local border = { 0.20, 0.20, 0.24, 0.90 }
                local text = { 0.90, 0.90, 0.90, 1 }

                if accent then
                    local r, g, b = NPPreviewAccentRGB()
                    bg = { 0.10, 0.07, 0.07, 1 }
                    border = { r, g, b, 0.85 }
                    text = { 1, 1, 1, 1 }
                end

                if state == "hover" then
                    border = { 0.60, 0.60, 0.70, 1 }
                elseif state == "down" then
                    local r, g, b = NPPreviewAccentRGB()
                    bg = { 0.12, 0.08, 0.08, 1 }
                    border = { r, g, b, 1 }
                end

                KT:AddBackdrop(btn, bg[1], bg[2], bg[3], bg[4])
                KT:AddBorder(btn, border[1], border[2], border[3], border[4])
                if btn.txt then btn.txt:SetTextColor(text[1], text[2], text[3], text[4]) end
            end

            RefreshVisual()
            btn:SetScript("OnEnter", function(self) RefreshVisual("hover") end)
            btn:SetScript("OnLeave", function(self) RefreshVisual() end)
            btn:SetScript("OnMouseDown", function(self)
                if self:IsEnabled() then
                    if self.txt then self.txt:SetPoint("CENTER", 0, -1) end
                    RefreshVisual("down")
                end
            end)
            btn:SetScript("OnMouseUp", function(self)
                if self.txt then self.txt:SetPoint("CENTER") end
                RefreshVisual(self:IsMouseOver() and "hover" or nil)
            end)
        end

        local applyBtn = CreateFrame("Button", nil, btnRow, "BackdropTemplate")
        applyBtn:SetSize(126, 26)
        applyBtn:SetPoint("LEFT", 0, 0)
        StyleSpecialButton(applyBtn, true)
            applyBtn.txt:SetText(LText("Apply"))
        applyBtn:SetScript("OnClick", function()
            local text = NormalizeSpecialInput(edit:GetText())
            DB().specialAurasInput = text
            DB().specialAuras = BuildSpecialSetFromText(text)
            UpdatePreview()
            KT:RefreshPage()
        end)

        local clearBtn = CreateFrame("Button", nil, btnRow, "BackdropTemplate")
        clearBtn:SetSize(126, 26)
        clearBtn:SetPoint("LEFT", applyBtn, "RIGHT", 10, 0)
        StyleSpecialButton(clearBtn, false)
            clearBtn.txt:SetText(LText("Clear"))
        clearBtn:SetScript("OnClick", function()
            DB().specialAurasInput = ""
            DB().specialAuras = {}
            edit:SetText("")
            UpdatePreview()
            KT:RefreshPage()
        end)

        y = y - (btnRow:GetHeight() + 10)

        local function RefreshPriorityRuleColors()
            for _, plate in pairs(ns.plates or {}) do
                if plate.UpdateAuras then plate:UpdateAuras() end
                if plate.UpdateHealthColor then plate:UpdateHealthColor() end
            end
            UpdatePreview()
            KT:RefreshPage()
        end

        local function NormalizeRuleInput(text)
            text = tostring(text or "")
            text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
            return text
        end

        local function BuildRuleSetFromText(text)
            local rules = { ids = {}, names = {} }
            for token in NormalizeRuleInput(text):gmatch("[^,\n]+") do
                token = token:gsub("^%s+", ""):gsub("%s+$", "")
                if token ~= "" then
                    local id = tonumber(token)
                    if id and id > 0 then
                        rules.ids[id] = true
                    else
                        rules.names[token:lower()] = true
                    end
                end
            end
            return rules
        end

        local function BuildRuleEditor(sectionTitle, toggleKey, inputKey, compiledKey, buildFn, colorKey, textureKey, helpText, textureText)
            local row
            _, h = W:Spacer(parent, y, 14); y = y - h
            _, h = W:SectionHeader(parent, sectionTitle, y); y = y - h

            row, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Enabled"),
                    getValue = function() return DBVal(toggleKey) == true end,
                    setValue = function(v)
                        DB()[toggleKey] = v
                        RefreshPriorityRuleColors()
                    end
                },
                {
                    type = "dropdown",
                    text = textureText,
                    values = hbtValues,
                    order = hbtOrder,
                    getValue = function() return DBVal(textureKey) or defaults[textureKey] or "Melli Reforged" end,
                    setValue = function(v)
                        DB()[textureKey] = v
                        RefreshPriorityRuleColors()
                    end
                }); y = y - h

            do
                local leftRgn = row and row._leftRegion
                if leftRgn and leftRgn._control then
                    local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5,
                        function()
                            return DBColor(colorKey)
                        end,
                        function(r, g, b)
                            DB()[colorKey] = { r = r, g = g, b = b }
                            RefreshPriorityRuleColors()
                        end,
                        nil, 20)
                    PP.Point(swatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
                    KT_RegisterWidgetRefresh(function()
                        local off = DBVal(toggleKey) ~= true
                        swatch:SetAlpha(off and 0.15 or 1)
                        swatch:EnableMouse(not off)
                        updateSwatch()
                    end)
                    local off = DBVal(toggleKey) ~= true
                    swatch:SetAlpha(off and 0.15 or 1)
                    swatch:EnableMouse(not off)
                end
            end

            _, h = W:Label(parent, helpText, y, 11, { r = 0.65, g = 0.65, b = 0.65 }); y = y - h

            local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            box:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
            box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
            box:SetHeight(110)
            KT:AddBackdrop(box, 0.06, 0.06, 0.07, 1)
            KT:AddBorder(box, 0.20, 0.20, 0.24, 0.9)

            local editBox = CreateFrame("EditBox", nil, box)
            editBox:SetMultiLine(true)
            editBox:SetAutoFocus(false)
            editBox:SetFont(KT.FONT_PATH, 11, "OUTLINE")
            editBox:SetTextColor(1, 1, 1, 1)
            editBox:SetPoint("TOPLEFT", 10, -10)
            editBox:SetPoint("BOTTOMRIGHT", -10, 10)
            editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            editBox:SetText(NormalizeRuleInput(DBVal(inputKey) or ""))
            editBox:SetScript("OnTextChanged", function(self)
                DB()[inputKey] = NormalizeRuleInput(self:GetText())
            end)

            y = y - (box:GetHeight() + 10)

            local btnFrame = CreateFrame("Frame", nil, parent)
            btnFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
            btnFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
            btnFrame:SetHeight(34)

            local apply = CreateFrame("Button", nil, btnFrame, "BackdropTemplate")
            apply:SetSize(126, 26)
            apply:SetPoint("LEFT", 0, 0)
            StyleSpecialButton(apply, true)
            apply.txt:SetText(LText("Apply"))
            apply:SetScript("OnClick", function()
                local text = NormalizeRuleInput(editBox:GetText())
                DB()[inputKey] = text
                DB()[compiledKey] = buildFn(text)
                RefreshPriorityRuleColors()
            end)

            local clear = CreateFrame("Button", nil, btnFrame, "BackdropTemplate")
            clear:SetSize(126, 26)
            clear:SetPoint("LEFT", apply, "RIGHT", 10, 0)
            StyleSpecialButton(clear, false)
            clear.txt:SetText(LText("Clear"))
            clear:SetScript("OnClick", function()
                DB()[inputKey] = ""
                DB()[compiledKey] = buildFn("")
                editBox:SetText("")
                RefreshPriorityRuleColors()
            end)

            y = y - (btnFrame:GetHeight() + 10)
            return row
        end

        BuildRuleEditor(
            "PRIORITY TARGETS",
            "priorityTargetsEnabled",
            "priorityTargetsInput",
            "priorityTargetsCompiled",
            function(text) return (ns.BuildPriorityTargetsFromText and ns.BuildPriorityTargetsFromText(text)) or BuildRuleSetFromText(text) end,
            "priorityTargetsColor",
            "priorityTargetsTexture",
            "Add mob names or NPC IDs, one per line or separated by commas.\nExample:\nDungeon Training Dummy\n229249",
            "Priority Texture"
        )

        local auraRow = BuildRuleEditor(
            "AURA HEALTH OVERRIDE",
            "auraPriorityEnabled",
            "auraPriorityInput",
            "auraPriorityCompiled",
            function(text) return (ns.BuildAuraPrioritySpellsFromText and ns.BuildAuraPrioritySpellsFromText(text)) or BuildRuleSetFromText(text) end,
            "auraPriorityColor",
            "auraPriorityTexture",
            "Add spell names or spell IDs from your debuffs, one per line or separated by commas.\nExample:\nMoonfire\nSunfire\n8921",
            "Aura Texture"
        )

        _, h = W:DualRow(parent, y,
            {
                type = "dropdown",
                text = LText("Aura Match Mode"),
                values = { all = "All Listed Spells", any = "Any Listed Spell" },
                order = { "all", "any" },
                getValue = function() return DBVal("auraPriorityMatchMode") or defaults.auraPriorityMatchMode or "all" end,
                setValue = function(v)
                    DB().auraPriorityMatchMode = v
                    RefreshPriorityRuleColors()
                end
            },
            { type = "label", text = "" }); y = y - h

        return math.abs(y)
    end

    local function BuildAutoPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local y = yOffset
        local _, h
        parent._showRowDivider = true
        _, h = W:SectionHeader(parent, "AUTO", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enabled"),
                getValue = function() return DBVal("autoEnabled") == true end,
                setValue = function(v)
                    DB().autoEnabled = v
                    KT:RefreshPage()
                end
            },
            { type = "label", text = "" }); y = y - h

        local function AutoOff() return DBVal("autoEnabled") ~= true end

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enemy Nameplates in combat"),
                getValue = function() return DBVal("autoEnemyInCombat") ~= false end,
                setValue = function(v) DB().autoEnemyInCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = "Enabled"
            },
            {
                type = "toggle",
                text = LText("Enemy Nameplates out of combat"),
                getValue = function() return DBVal("autoEnemyOutOfCombat") ~= false end,
                setValue = function(v) DB().autoEnemyOutOfCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = "Enabled"
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Friendly Nameplates in combat"),
                getValue = function() return DBVal("autoFriendlyInCombat") ~= false end,
                setValue = function(v) DB().autoFriendlyInCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = "Enabled"
            },
            {
                type = "toggle",
                text = LText("Friendly Nameplates out of combat"),
                getValue = function() return DBVal("autoFriendlyOutOfCombat") ~= false end,
                setValue = function(v) DB().autoFriendlyOutOfCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = "Enabled"
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Always Show Nameplates in combat"),
                getValue = function() return DBVal("autoAlwaysShowInCombat") ~= false end,
                setValue = function(v) DB().autoAlwaysShowInCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = "Enabled"
            },
            {
                type = "toggle",
                text = LText("Always Show Nameplates out of combat"),
                getValue = function() return DBVal("autoAlwaysShowOutOfCombat") ~= false end,
                setValue = function(v) DB().autoAlwaysShowOutOfCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = "Enabled"
            }); y = y - h

        _, h = W:Spacer(parent, y, 14); y = y - h

        _, h = W:SectionHeader(parent, "RAID AND PARTY", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Hide Enemy Pets"),
                getValue = function() return DBVal("showEnemyPets") ~= true end,
                setValue = function(v)
                    DB().showEnemyPets = not v
                    ns.RefreshAllSettings()
                    UpdatePreview()
                    KT:RefreshPage()
                end
            },
            {
                type = "toggle",
                text = LText("Hide Enemy Totems"),
                getValue = function() return DBVal("hideEnemyTotems") == true end,
                setValue = function(v)
                    DB().hideEnemyTotems = v
                    KT:RefreshPage()
                end
            }); y = y - h
        return math.abs(y)
    end

    local function BuildAdvancedPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local y = yOffset
        local _, h
        parent._showRowDivider = true
        _, h = W:SectionHeader(parent, "ADVANCED", y); y = y - h
        _, h = W:SectionHeader(parent, "UNIT TYPES", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Hide Enemy Guardians"),
                getValue = function() return DBVal("hideEnemyGuardians") == true end,
                setValue = function(v) DB().hideEnemyGuardians = v; KT:RefreshPage() end
            },
            {
                type = "toggle",
                text = LText("Hide Enemy Minions"),
                getValue = function() return DBVal("hideEnemyMinions") == true end,
                setValue = function(v) DB().hideEnemyMinions = v; KT:RefreshPage() end
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Hide Enemy Minor Units"),
                getValue = function() return DBVal("hideEnemyMinorUnits") == true end,
                setValue = function(v) DB().hideEnemyMinorUnits = v; KT:RefreshPage() end
            },
            { type = "label", text = "" }); y = y - h

        _, h = W:Spacer(parent, y, 14); y = y - h

        _, h = W:SectionHeader(parent, "MISC", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Show Shield Prediction"),
                getValue = function() return DBVal("showShieldPrediction") ~= false end,
                setValue = function(v) DB().showShieldPrediction = v; KT:RefreshPage() end,
            },
            {
                type = "toggle",
                text = LText("Animate Health Bar"),
                getValue = function() return DBVal("animateHealthBar") == true end,
                setValue = function(v) DB().animateHealthBar = v; KT:RefreshPage() end
            }); y = y - h
        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Register the module
    ---------------------------------------------------------------------------
    KT._npOptionsActiveTab = KT._npOptionsActiveTab or PAGE_DISPLAY

    BuildNPSubTabs = function(parent)
        return BuildCompactDisplayTabs(parent)
    end

    KT:RegisterPage("nameplates", "Nameplates", 16, function(sc)
        if KT._npOptionsActiveTab == PAGE_GENERAL then
            local y = -BuildNPSubTabs(sc)
            return BuildGeneralPage(PAGE_GENERAL, sc, y)
        elseif KT._npOptionsActiveTab == PAGE_COLORS then
            local y = -BuildNPSubTabs(sc)
            return BuildColorsPage(PAGE_COLORS, sc, y)
        elseif KT._npOptionsActiveTab == PAGE_THREAT then
            local y = -BuildNPSubTabs(sc)
            return BuildThreatPage(PAGE_THREAT, sc, y)
        elseif KT._npOptionsActiveTab == PAGE_SPECIAL then
            local y = -BuildNPSubTabs(sc)
            return BuildSpecialPage(PAGE_SPECIAL, sc, y)
        elseif KT._npOptionsActiveTab == PAGE_AUTO then
            local y = -BuildNPSubTabs(sc)
            return BuildAutoPage(PAGE_AUTO, sc, y)
        elseif KT._npOptionsActiveTab == PAGE_ADVANCED then
            local y = -BuildNPSubTabs(sc)
            return BuildAdvancedPage(PAGE_ADVANCED, sc, y)
        end
        return BuildDisplayPage(PAGE_DISPLAY, sc, 0)
    end)

    if not StaticPopupDialogs["KUI_NAMEPLATES_RESTORE_DEFAULTS"] then
        StaticPopupDialogs["KUI_NAMEPLATES_RESTORE_DEFAULTS"] = {
            text = LText("Restore default Nameplates settings? This will reload the UI."),
            button1 = YES,
            button2 = CANCEL,
            OnAccept = function()
                if ns.ResetNameplatesDB then
                    ns.ResetNameplatesDB()
                else
                    KullThranUINameplatesDB = nil
                end
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    ---------------------------------------------------------------------------
    --  Slash command  /knp  opens KT to the Nameplates module
    ---------------------------------------------------------------------------
    SLASH_KULLTHRANNAMEPLATES1 = "/knp"
    SlashCmdList.KULLTHRANNAMEPLATES = function(msg)
        if InCombatLockdown and InCombatLockdown() then
            print("Cannot open options in combat")
            return
        end

        if msg == "reset" then
            if ns.ResetNameplatesDB then
                ns.ResetNameplatesDB()
            else
                KullThranUINameplatesDB = nil
            end
            ReloadUI()
            return
        end

        KT:OpenMenu("nameplates")
    end
end)
