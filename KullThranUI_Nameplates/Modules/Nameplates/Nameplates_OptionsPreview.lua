-- Shared layer of the Nameplates options panel: saved value readers, swatches and small widgets, the
-- fallback cog popup, cast bar colour rows, live plate helpers, health marker helpers, and the two
-- preview replicas with their click and drag targets. One text for Retail and Forever.

local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

local floor, min, max, abs, random = math.floor, math.min, math.max, math.abs, math.random

local P = {}
ns.OptionsPreview = P

-- Resolved once by Setup.
local defaults = {}
local plates = {}
local barBase = 168
local setFSFont
local npOutline = function() return "OUTLINE" end
local isForever = false

-- The last built previews and the rolled sample values.
local activeEnemy, activeFriendly
local rollPct, rollFill, rollIndex

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local FLAT = "Interface\\Buttons\\WHITE8x8"
local MEDIA = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\"
local SHARED = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Shared\\"

---------------------------------------------------------------- Saved values

local function DB() return _G.KullThranUINameplatesDB end

-- Saved value, or the default when absent. A saved false stays false.
local function Saved(k)
    local db = _G.KullThranUINameplatesDB
    if db then
        local v = db[k]
        if v ~= nil then return v end
    end
    return defaults[k]
end

-- Saved value when truthy, otherwise the default.
local function SavedT(k)
    local db = _G.KullThranUINameplatesDB
    return (db and db[k]) or defaults[k]
end

local function DBColor(k)
    local c = SavedT(k)
    if type(c) ~= "table" then return 1, 1, 1 end
    return c.r or 1, c.g or 1, c.b or 1
end

local function WriteDB(k, v)
    local db = _G.KullThranUINameplatesDB
    if db then db[k] = v end
end

---------------------------------------------------------------- Load-time members on KT

local function FontFallback()
    local resolved = KT.ResolveFontPath and KT:ResolveFontPath()
    return resolved or KT.FONT_PATH or DEFAULT_FONT
end

function KT.GetNPFontPath()
    local db = _G.KullThranUINameplatesDB
    local value = db and db.font
    -- A saved font that cannot draw the active non-Latin language uses the localized font.
    if type(value) == "string" and value ~= "" and KT.IsNonLatinLocale and KT:IsNonLatinLocale()
        and KT.IsFontCompatibleWithLocale and not KT:IsFontCompatibleWithLocale(value) then
        return FontFallback()
    end
    if LSM and type(value) == "string" then
        local fetched = LSM:Fetch("font", value, true)
        if fetched then return fetched end
        for _, name in ipairs(LSM:List("font")) do
            if LSM:Fetch("font", name, true) == value then return value end
        end
    end
    if type(value) == "string" and value ~= "" then
        local normal = value:gsub("/", "\\"):lower()
        if not normal:find("interface\\addons\\", 1, true) then return value end
    end
    return FontFallback()
end

function KT.GetNPFontOutline()
    local db = _G.KullThranUINameplatesDB
    local v = db and db.fontOutline
    if v ~= nil then return v end
    return "OUTLINE"
end

function KT.GetNPFontUseShadow()
    local db = _G.KullThranUINameplatesDB
    local v = db and db.fontShadow
    if v ~= nil then return v end
    return true
end

if not KT.GetMaelstromWeapon then KT.GetMaelstromWeapon = function() return nil, 10 end end
if not KT.NP_GREEN then KT.NP_GREEN = { r = 0, g = 0.80, b = 0.40 } end
if not KT.NP_BORDER_COLOR then KT.NP_BORDER_COLOR = { r = 0.3, g = 0.3, b = 0.3 } end
if not KT.NP_SL_INPUT_A then KT.NP_SL_INPUT_A = 0.55 end
if not KT.PP then
    KT.PP = {
        Point = function(f, ...) f:SetPoint(...) end,
        Size = function(f, ...) f:SetSize(...) end,
        Width = function(f, ...) f:SetWidth(...) end,
        Height = function(f, ...) f:SetHeight(...) end,
    }
end

---------------------------------------------------------------- Small helpers

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

local function FormatThousands(n)
    local s = tostring(n)
    local count
    repeat
        s, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until count == 0
    return s
end

local function AccentRGB()
    if KT.GetStyleAccentRGB then return KT:GetStyleAccentRGB() end
    return KT.C_R or 0.902, KT.C_G or 0.118, KT.C_B or 0.314
end

-- No stored values: every read asks the current style.
local Accent = setmetatable({}, { __index = function(_, k)
    if k == "r" then return (AccentRGB()) end
    if k == "g" then return (select(2, AccentRGB())) end
    if k == "b" then return (select(3, AccentRGB())) end
    if k == "a" then return 1 end
end })

local function OptOutline()
    local v = KT.GetNPFontOutline and KT.GetNPFontOutline()
    return v or "OUTLINE"
end

local function PreviewFont(fs, path, size, flags)
    if not fs or not fs.SetFont then return end
    if not pcall(fs.SetFont, fs, path, size, flags) then
        pcall(fs.SetFont, fs, FontFallback(), size, flags)
    end
    if flags == "" then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local function ApplyAccentToIcon(tex)
    if tex.SetVertexColor then KT:SetAccentVertexColor(tex, 1) end
    if not (tex.GetTexture and tex.GetParent and tex.ClearAllPoints and tex.SetPoint and tex.SetSize) then return end
    local path = tex:GetTexture()
    if type(path) ~= "string" then return end
    path = path:lower()
    local ratio
    if path:find("cogs.png", 1, true) or path:find("right_arrow.png", 1, true) then
        ratio = 2 / 3
    elseif path:find("engranaje.png", 1, true) then
        ratio = 1
    else
        return
    end
    local parent = tex:GetParent()
    local pw = parent and parent.GetWidth and parent:GetWidth()
    local ph = parent and parent.GetHeight and parent:GetHeight()
    if not pw or pw <= 0 then pw = 26 end
    if not ph or ph <= 0 then ph = 26 end
    local width = min(20, pw, ph / ratio)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", parent, "CENTER", 0, 0)
    tex:SetSize(width, width * ratio)
end

local function ShowTooltip(owner, text)
    if owner == nil or text == nil then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(LText(text), 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function HideTooltip() GameTooltip:Hide() end

local function DisabledTooltip(reason)
    return "|cffff4444" .. LText("Disabled:") .. "|r " .. (LText(reason) or "")
end

local function DimSwatch(swatch, off)
    swatch:SetAlpha(off and 0.15 or 1)
    swatch:EnableMouse(not off)
end

local function FadeOnHover(btn)
    btn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
    btn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
end

local function RegisterWidgetRefresh(fn)
    if KT.MenuPrincipal then KT.MenuPrincipal:HookScript("OnShow", fn) end
end

local function UpdatePreview()
    if activeEnemy then activeEnemy:Update() end
    if activeFriendly then activeFriendly:Update() end
end

local function RandomizeValues()
    rollPct = floor(60 + random() * 15)
    rollFill = 0.40 + random() * 0.20
    rollIndex = random(8)
end

---------------------------------------------------------------- Colour swatch

local function BuildColorSwatch(parent, level, getColor, setColor, _, size)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(size or 20, size or 20)
    f:SetFrameLevel(level or 1)
    if KT.AddBackdrop then KT:AddBackdrop(f, 0.08, 0.08, 0.11, 1) end
    if KT.AddBorder then KT:AddBorder(f, 0.20, 0.20, 0.25, 1) end

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)

    local function repaint()
        local ok, r, g, b = pcall(getColor)
        if ok then tex:SetColorTexture(r or 1, g or 1, b or 1, 1) end
    end

    f:SetScript("OnClick", function()
        local ok, r, g, b = pcall(getColor)
        if not ok then return end
        local picker = ColorPickerFrame
        if not picker then return end
        if picker.SetFrameStrata then picker:SetFrameStrata("FULLSCREEN_DIALOG") end
        if picker.SetClampedToScreen then picker:SetClampedToScreen(true) end

        local function onPick()
            local got, nr, ng, nb = pcall(picker.GetColorRGB, picker)
            if not got then return end
            pcall(setColor, nr or 1, ng or 1, nb or 1)
            repaint()
        end
        local function onCancel()
            pcall(setColor, r, g, b)
            repaint()
        end

        if picker.SetupColorPickerAndShow then
            picker:SetupColorPickerAndShow({
                r = r or 1, g = g or 1, b = b or 1, hasOpacity = false,
                swatchFunc = onPick, cancelFunc = onCancel,
            })
        else
            picker.func = onPick
            picker.cancelFunc = onCancel
            picker.hasOpacity = false
            picker.opacity = nil
            picker:SetColorRGB(r, g, b)
            picker:Hide()
            picker:Show()
        end
    end)

    repaint()
    return f, repaint
end

local function DimmableSwatch(region, get, set, isOff, place)
    local swatch, repaint = BuildColorSwatch(region, region:GetFrameLevel() + 5, get, set, nil, 20)
    place(swatch)
    DimSwatch(swatch, isOff())
    RegisterWidgetRefresh(function()
        DimSwatch(swatch, isOff())
        repaint()
    end)
    return swatch
end

---------------------------------------------------------------- Slider

local function BuildSliderCore(...)
    if KT.BuildSliderCore then return KT.BuildSliderCore(...) end

    local parent, second, _, _, posInputW, posHeight, posFont, posAlpha, posMin, posMax, posStep, posGet, posSet = ...
    local width, inputW, height, fontSize, inputAlpha, lo, hi, step, getter, setter
    if type(second) == "table" then
        width, inputW, height, fontSize = second.width, second.inputWidth, second.height, second.fontSize
        inputAlpha, lo, hi, step, getter, setter = second.inputAlpha, second.min, second.max, second.step, second.get, second.set
    else
        width, inputW, height, fontSize = second, posInputW, posHeight, posFont
        inputAlpha, lo, hi, step, getter, setter = posAlpha, posMin, posMax, posStep, posGet, posSet
    end
    width, inputW, height, fontSize = width or 140, inputW or 40, height or 20, fontSize or 11
    inputAlpha, lo, hi, step = inputAlpha or 0.9, lo or 0, hi or 100, step or 1

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width, height)
    slider:SetMinMaxValues(lo, hi)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local thumb = slider:GetThumbTexture()
    if thumb and thumb.SetColorTexture then
        local r, g, b = AccentRGB()
        thumb:SetSize(8, height + 2)
        thumb:SetColorTexture(r, g, b, 0.95)
    end

    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(inputW, height)
    edit:SetAutoFocus(false)
    if KT.FONT_PATH then edit:SetFont(KT.FONT_PATH, fontSize, "OUTLINE") end
    edit:SetAlpha(inputAlpha)

    -- tonumber, clamp, then round on the step grid. Not a number means min.
    local function clean(v)
        v = tonumber(v)
        if not v then return lo end
        v = max(lo, min(hi, v))
        return max(lo, min(hi, lo + floor((v - lo) / step + 0.5) * step))
    end

    local pushing = false
    local function push(v)
        v = clean(v)
        pushing = true
        edit:SetText(tostring(v))
        slider:SetValue(v)
        pushing = false
        if setter then setter(v) end
    end

    slider:SetScript("OnValueChanged", function(_, v)
        if pushing then return end
        v = clean(v)
        edit:SetText(tostring(v))
        if setter then setter(v) end
    end)
    edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        push(self:GetText())
    end)
    edit:SetScript("OnEscapePressed", function(self)
        -- Read first: losing focus pushes the typed value on its own.
        local v
        if getter then v = getter() else v = slider:GetValue() end
        self:ClearFocus()
        push(v)
    end)
    edit:SetScript("OnEditFocusLost", function(self) push(self:GetText()) end)

    if getter then push(getter()) end
    return slider, edit
end

---------------------------------------------------------------- Fallback cog popup

local function PopupValueText(v, step)
    if type(v) ~= "number" then return tostring(v) end
    if type(step) == "number" and step > 0 and step < 1 then
        local digits = tostring(step):match("%.(%d+)")
        local places = min(max(digits and #digits or 1, 1), 3)
        return string.format("%." .. places .. "f", v)
    end
    return tostring(floor(v + 0.5))
end

local function BuildCogPopup(opts)
    opts = opts or {}
    local font = KT.FONT_PATH or DEFAULT_FONT
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(1200)
    f:SetClampedToScreen(true)
    f:Hide()
    if KT.AddBackdrop then KT:AddBackdrop(f, 0.04, 0.04, 0.05, 0.98) end
    if KT.AddBorder then KT:AddBorder(f, 0, 0, 0, 1) end

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(font, 12, "OUTLINE")
    title:SetTextColor(1, 1, 1, 1)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    title:SetText(opts.title and LText(opts.title) or "")

    local refreshing = false
    local drawn = {}
    local y = -32
    for _, row in ipairs(opts.rows or {}) do
        if row.type == "slider" then
            local label = f:CreateFontString(nil, "OVERLAY")
            label:SetFont(font, 11, "OUTLINE")
            label:SetTextColor(1, 1, 1, 0.85)
            label:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
            label:SetText(LText(row.label))

            local value = f:CreateFontString(nil, "OVERLAY")
            value:SetFont(font, 11, "OUTLINE")
            value:SetTextColor(1, 1, 1, 0.5)
            value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, y)

            local slider = CreateFrame("Slider", nil, f, "MinimalSliderTemplate")
            slider:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y - 16)
            slider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, y - 16)
            slider:SetHeight(16)
            slider:SetMinMaxValues(row.min or 0, row.max or 1)
            slider:SetValueStep(row.step or 0.1)
            slider:SetObeyStepOnDrag(true)
            slider:SetScript("OnValueChanged", function(_, v)
                if not refreshing and row.set then row.set(v) end
                value:SetText(PopupValueText(v, row.step))
            end)

            drawn[#drawn + 1] = { row = row, slider = slider, value = value }
            y = y - 46
        end
    end
    f:SetSize(280, max(70, abs(y) + 14))

    local function show(anchor)
        if not anchor then return end
        if f:IsShown() then
            f:Hide()
            return
        end
        refreshing = true
        for _, d in ipairs(drawn) do
            local v = d.row.get and d.row.get()
            if type(v) == "number" then
                d.slider:SetValue(v)
                d.value:SetText(PopupValueText(v, d.row.step))
            end
        end
        refreshing = false
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
        f:Show()
    end

    return f, show
end

-- A cog popup through whichever builder is installed. The Aura Reminders one pushes each row's
-- current value through its set when it shows, so nothing reaches a set while showing.
local function QuietCogPopup(opts)
    local showing = false
    local quiet = {}
    for k, v in pairs(opts) do quiet[k] = v end
    quiet.rows = {}
    for i, row in ipairs(opts.rows or {}) do
        local copy = {}
        for k, v in pairs(row) do copy[k] = v end
        if row.set then
            copy.set = function(...)
                if not showing then row.set(...) end
            end
        end
        quiet.rows[i] = copy
    end
    local frame, show = KT.BuildCogPopup(quiet)
    return frame, function(anchor)
        showing = true
        show(anchor)
        showing = false
    end
end

---------------------------------------------------------------- Row fields

-- W:DualRow is shared with other addons' panels (Cooldown Manager passes disabled too), and reads
-- none of tooltip, disabled, disabledTooltip, labelOnlyDisabled, disabledValues or trackWidth.
-- RowWidgets gives these pages a W whose rows add them on the finished control. Nothing polls: a
-- state follows a control change on the same parent, and its blocker's OnShow when the panel opens.
-- A multiSwatch is left out: W:MultiSwatch already honours disabled per swatch.
-- In a block: this file's main chunk has reached Lua's limit of 200 locals.
do
    local ROW_DIM = 0.4
    local rowStates = setmetatable({}, { __mode = "k" })
    local rowProxies = setmetatable({}, { __mode = "k" })

    local function RowIsOff(d)
        local off = d.disabled
        if type(off) == "function" then off = off() end
        return off and true or false
    end

    local function ApplyRowState(state)
        local off = RowIsOff(state.d)
        if state.d.labelOnlyDisabled then
            if state.ctrl._labelKT then state.ctrl._labelKT:SetAlpha(off and ROW_DIM or 1) end
            state.blocker:EnableMouse(false)
        else
            state.ctrl:SetAlpha(off and ROW_DIM or 1)
            state.blocker:EnableMouse(off)
        end
    end

    local function TrackRowState(state)
        if state.tracked then return end
        state.tracked = true
        local list = rowStates[state.parent]
        if not list then
            list = {}
            rowStates[state.parent] = list
        end
        list[#list + 1] = state
    end

    -- Rows gone from view are dropped here, so page rebuilds do not grow the list. A dropped row that
    -- comes back returns through its blocker's OnShow.
    local function RefreshRowStates(parent)
        local list = rowStates[parent]
        if not list then return end
        local kept = {}
        for _, state in ipairs(list) do
            if state.ctrl:IsVisible() then
                ApplyRowState(state)
                kept[#kept + 1] = state
            else
                state.tracked = false
            end
        end
        rowStates[parent] = kept
    end

    local function GuardRowSetter(parent, d, holder)
        if not (d and d.setValue) then return d end
        local copy = {}
        for k, v in pairs(d) do copy[k] = v end
        copy.setValue = function(...)
            if d.disabled ~= nil and not d.labelOnlyDisabled and RowIsOff(d) then return end
            if d.disabledValues and d.disabledValues((...)) then
                -- The dropdown has already drawn the picked text
                if holder.ctrl and holder.ctrl.Refresh then holder.ctrl.Refresh() end
                return
            end
            d.setValue(...)
            RefreshRowStates(parent)
        end
        return copy
    end

    local function ApplyTrackWidth(ctrl, d)
        local track, fill = ctrl._trackKT, ctrl._fillKT
        if not track then return end
        local room = ctrl:GetWidth() - 32
        local width = room > 0 and min(d.trackWidth, room) or d.trackWidth
        track:ClearAllPoints()
        track:SetPoint("BOTTOMLEFT", ctrl, "BOTTOMLEFT", 16, 14)
        track:SetWidth(width)
        for _, child in ipairs({ ctrl:GetChildren() }) do
            if child:IsObjectType("Slider") then
                child:ClearAllPoints()
                child:SetPoint("BOTTOMLEFT", ctrl, "BOTTOMLEFT", 16, 4)
                child:SetWidth(width)
            end
        end
        -- The fill was sized for the full track, and only repaints when the value changes
        if fill then
            local lo, hi = d.min or 0, d.max or 1
            local t = 0
            if hi > lo then t = max(0, min(1, ((tonumber(d.getValue()) or lo) - lo) / (hi - lo))) end
            fill:SetWidth(max(4, 7 + (width - 14) * t))
        end
    end

    local function RowTooltipText(d)
        if d.disabled ~= nil and d.disabledTooltip and RowIsOff(d) then return DisabledTooltip(d.disabledTooltip) end
        return d.tooltip
    end

    local function HookRowTooltip(ctrl, d)
        local function enter(self)
            local text = RowTooltipText(d)
            if text then ShowTooltip(self, text) end
        end
        ctrl:EnableMouse(true)
        ctrl:HookScript("OnEnter", enter)
        ctrl:HookScript("OnLeave", HideTooltip)
        for _, child in ipairs({ ctrl:GetChildren() }) do
            if child:IsObjectType("Slider") or child:IsObjectType("EditBox") or child:IsObjectType("Button") then
                child:HookScript("OnEnter", enter)
                child:HookScript("OnLeave", HideTooltip)
            end
        end
    end

    -- Lies over the control's own parts and under the cogs and swatches on the region (its level + 5).
    local function BuildRowBlocker(parent, ctrl, d)
        local state = { parent = parent, ctrl = ctrl, d = d }
        local blocker = CreateFrame("Frame", nil, ctrl)
        blocker:SetAllPoints(ctrl)
        blocker:SetFrameLevel(ctrl:GetFrameLevel() + 3)
        blocker:SetScript("OnEnter", function(self)
            local text = RowTooltipText(d)
            if text then ShowTooltip(self, text) end
        end)
        blocker:SetScript("OnLeave", HideTooltip)
        blocker:SetScript("OnShow", function()
            ApplyRowState(state)
            TrackRowState(state)
        end)
        state.blocker = blocker
        ApplyRowState(state)
        TrackRowState(state)
    end

    local function ApplyRowFields(parent, region, d, holder)
        local ctrl = region and region._control
        holder.ctrl = ctrl
        if not ctrl or d.type == "multiSwatch" then return end
        if d.trackWidth then ApplyTrackWidth(ctrl, d) end
        if d.tooltip or (d.labelOnlyDisabled and d.disabledTooltip) then HookRowTooltip(ctrl, d) end
        if d.disabled ~= nil then BuildRowBlocker(parent, ctrl, d) end
    end

    local function RowWidgets(W)
        local proxy = rowProxies[W]
        if proxy then return proxy end
        proxy = setmetatable({}, { __index = W })
        function proxy:DualRow(parent, y, left, right)
            local leftHolder, rightHolder = {}, {}
            local row, height = W:DualRow(parent, y,
                GuardRowSetter(parent, left, leftHolder), GuardRowSetter(parent, right, rightHolder))
            if row then
                if left then ApplyRowFields(parent, row._leftRegion, left, leftHolder) end
                if right then ApplyRowFields(parent, row._rightRegion, right, rightHolder) end
            end
            return row, height
        end
        rowProxies[W], rowProxies[proxy] = proxy, proxy
        return proxy
    end
    P.RowWidgets = RowWidgets
end

---------------------------------------------------------------- Colours

local function ColorAccess(k, onChange)
    local function read()
        local c = SavedT(k)
        return c.r, c.g, c.b
    end
    local function write(r, g, b)
        WriteDB(k, { r = r, g = g, b = b })
        onChange()
    end
    return read, write
end

local function PlayerClassColor()
    local _, class = UnitClass("player")
    return RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
end

local function CastTargetTint()
    if Saved("castTargetClassColor") then
        local c = PlayerClassColor()
        if c then return c.r, c.g, c.b end
        return 1, 1, 1
    end
    local c = SavedT("castTargetColor")
    return c.r, c.g, c.b
end

local function ClassTintSwatches(cfg)
    local clickTinted = cfg.clickTinted or cfg.isTinted
    local custom = {
        tooltip = LText("Custom Color"),
        getValue = cfg.customGet,
        setValue = function(r, g, b)
            cfg.customSet(r, g, b)
            cfg.apply()
        end,
        onClick = function(self)
            if clickTinted() then
                WriteDB(cfg.flag, false)
                cfg.apply()
                KT:RefreshPage()
                return
            end
        end,
        refreshAlpha = function() return cfg.isTinted() and 0.3 or 1 end,
    }
    local class = {
        tooltip = cfg.tintedTip or LText("Class Colored"),
        getValue = function()
            if cfg.tintedColor then
                local r, g, b = cfg.tintedColor()
                if r then return r, g, b, 1 end
            end
            local c = PlayerClassColor()
            if c then return c.r, c.g, c.b, 1 end
            return 1, 1, 1, 1
        end,
        setValue = function() end,
        onClick = function()
            WriteDB(cfg.flag, true)
            cfg.apply()
            KT:RefreshPage()
        end,
        refreshAlpha = function() return cfg.isTinted() and 1 or 0.3 end,
    }
    if cfg.extra then
        for k, v in pairs(cfg.extra) do
            custom[k] = v
            class[k] = v
        end
    end
    return { custom, class }
end

---------------------------------------------------------------- Live plates

local function CallOnAllPlates(method)
    for _, plate in pairs(plates) do plate[method](plate) end
end

local function RefreshAllPlates() CallOnAllPlates("UpdateHealth") end
local function RefreshAllAuras() CallOnAllPlates("UpdateAuras") end

local function RefreshAllFonts()
    local stackSize = SavedT("auraStackTextSize")
    for _, plate in pairs(plates) do
        plate:RefreshNamePosition()
        plate:UpdateHealthValues()
        if plate.castName then setFSFont(plate.castName, SavedT("castNameSize"), npOutline()) end
        if plate.castTarget then setFSFont(plate.castTarget, SavedT("castTargetSize"), npOutline()) end
        for i = 1, 4 do
            local d = plate.debuffs and plate.debuffs[i]
            if d and d.count then setFSFont(d.count, stackSize, "OUTLINE") end
            local b = plate.buffs and plate.buffs[i]
            if b and b.count then setFSFont(b.count, stackSize, "OUTLINE") end
        end
    end
end

local function GlowColorPair(k)
    local function read()
        local c = SavedT(k)
        return c.r, c.g, c.b
    end
    local function write(r, g, b)
        WriteDB(k, { r = r, g = g, b = b })
        RefreshAllAuras()
    end
    return read, write
end

---------------------------------------------------------------- Cast bar colours

local CAST_KEYS = {
    base = "castBar", interruptible = "castBar",
    ready = "interruptReady", cooldown = "interruptReady",
    uninterruptible = "castBarUninterruptible",
}

local function CastBarColor(state)
    local key = CAST_KEYS[state]
    if not key then return 1, 1, 1 end
    local db = _G.KullThranUINameplatesDB or defaults
    local c = db[key] or defaults[key]
    return c.r or 1, c.g or 1, c.b or 1
end

-- The missing-function case raises on purpose: see F1 in the specification.
local function SetCastBarColor(state, r, g, b, updater)
    local db = _G.KullThranUINameplatesDB
    if not db then return end
    local key = CAST_KEYS[state]
    if key then db[key] = { r = r, g = g, b = b } end
    ns.RefreshAllSettings()
    for _, plate in pairs(plates) do
        if plate.isCasting or plate._interrupted then plate:UpdateCast() end
    end
    if type(updater) == "function" then
        updater()
    elseif type(P.colorPreviewRefresh) == "function" then
        P.colorPreviewRefresh()
    end
end

local CAST_ROWS = {
    { "Interruptible Cast Color", "interruptible" },
    { "Interrupt On CD Color", "cooldown" },
    { "Color When Cast Is Uninterruptible", "uninterruptible" },
}

local function BuildCastBarColorSection(parent, y, W, updater)
    local _, h = W:SectionHeader(parent, "CAST BAR COLORS", y)
    y = y - h
    for _, def in ipairs(CAST_ROWS) do
        local state = def[2]
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        row:SetHeight(30)
        local label = row:CreateFontString(nil, "OVERLAY")
        label:SetFont(KT.FONT_PATH, 11, "")
        label:SetTextColor(0.92, 0.92, 0.92)
        label:SetPoint("LEFT", row, "LEFT", 12, 0)
        label:SetText(LText(def[1]))
        local swatch, repaint = BuildColorSwatch(row, row:GetFrameLevel() + 5,
            function() return CastBarColor(state) end,
            function(r, g, b) SetCastBarColor(state, r, g, b, updater) end, nil, 20)
        KT.PP.Point(swatch, "RIGHT", row, "RIGHT", -12, 0)
        RegisterWidgetRefresh(repaint)
        repaint()
        y = y - 30
    end
    local left = { type = "label", text = "" }
    local right = {
        type = "toggle",
        text = LText("Show Tick at Kick Ready Spot"),
        tooltip = LText("Shows a small white tick mark on the cast bar at the point where the cast will be when your interrupt comes off cooldown."),
        getValue = function()
            local db = _G.KullThranUINameplatesDB
            local v = db and db.kickTickEnabled
            if v ~= nil then return v end
            return true
        end,
        setValue = function(v)
            WriteDB("kickTickEnabled", v)
            ns.RefreshAllSettings()
            if type(updater) == "function" then updater() end
        end,
    }
    local _, dual = W:DualRow(parent, y, left, right)
    return y - dual
end

---------------------------------------------------------------- Health markers

local function ParseMarkerValues(raw, limit)
    local out = {}
    if type(raw) == "table" then
        for _, v in ipairs(raw) do
            local n = tonumber(v)
            if n then out[#out + 1] = n end
        end
    elseif type(raw) == "string" and raw ~= "" then
        for run in raw:gmatch("[%d%-%.]+") do
            local n = tonumber(run)
            if n then out[#out + 1] = n end
        end
    end
    table.sort(out)
    local result, seen = {}, {}
    local clampTo = type(limit) == "number" and limit > 0 and limit or nil
    for _, n in ipairs(out) do
        if clampTo then n = max(0, min(clampTo, n)) end
        if n > 0 then
            local key = string.format("%.3f", n)
            if not seen[key] and #result < 3 then
                seen[key] = true
                result[#result + 1] = n
            end
        end
    end
    return result
end

local function NewMarkerState()
    return { mode = "spec", showOn = "target", character = {}, specs = {} }
end

local function MarkerState()
    if ns.GetHealthMarkerState then return ns.GetHealthMarkerState() end
    local db = _G.KullThranUINameplatesDB
    if not db then return NewMarkerState() end
    if not db.healthMarkers then db.healthMarkers = NewMarkerState() end
    return db.healthMarkers
end

local function MarkerCfg()
    if ns.GetActiveHealthMarkerConfig then return ns.GetActiveHealthMarkerConfig() end
    local state = MarkerState()
    if not state.character then state.character = {} end
    return state.character
end

local function RebuildMarkerValues(cfg)
    if type(cfg) ~= "table" then return end
    -- Built with no holes: the parser's list read stops at the first nil
    local slots = {}
    for i = 1, 3 do slots[#slots + 1] = cfg["slot" .. i] end
    cfg.values = table.concat(ParseMarkerValues(slots, 100), ",")
    if ns.NormalizeHealthMarkerProfile then ns.NormalizeHealthMarkerProfile(cfg) end
end

local function MarkerSlot(cfg, i)
    if type(cfg) ~= "table" then return 0 end
    local v = cfg["slot" .. i]
    if type(v) == "number" and v > 0 then return v end
    return 0
end

local function SetMarkerSlot(cfg, i, v)
    if type(cfg) ~= "table" then return end
    v = tonumber(v)
    if v and v > 0 then
        cfg["slot" .. i] = min(v, 100)
    else
        cfg["slot" .. i] = nil
    end
    RebuildMarkerValues(cfg)
end

---------------------------------------------------------------- Shared art helpers

-- Snap to the enemy preview's pixel grid, read at that moment.
local function Snap(v)
    local s = activeEnemy and activeEnemy:GetEffectiveScale() or 1
    return floor(v * s + 0.5) / s
end

local function Unsnap(tex)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end

-- Four edges where left and right run between top and bottom, so corners are not drawn twice.
local function MakeEdges(frame, thickness, unsnap)
    local top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    local bottom = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    local left = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    local right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", 0, 0)
    right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
    local set = { top, bottom, left, right }
    for _, t in ipairs(set) do
        t:SetColorTexture(0, 0, 0, 1)
        if unsnap then Unsnap(t) end
    end
    top:SetHeight(thickness)
    bottom:SetHeight(thickness)
    left:SetWidth(thickness)
    right:SetWidth(thickness)
    return set
end

local function SetEdgeThickness(set, thickness)
    set[1]:SetHeight(thickness)
    set[2]:SetHeight(thickness)
    set[3]:SetWidth(thickness)
    set[4]:SetWidth(thickness)
end

local function NewFontString(parent, wrapLimited)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if wrapLimited then
        fs:SetWordWrap(false)
        fs:SetMaxLines(1)
    end
    return fs
end

---------------------------------------------------------------- Enemy preview: icon choice

local GENERIC_ICONS = { 136096, 135846, 135812, 136197, 136048, 135924, 132292, 132218 }

local function Pool(debuffs, buffs, ccs, casts) return { debuffs = debuffs, buffs = buffs, ccs = ccs, casts = casts } end

local ICON_POOLS = {
    DEATHKNIGHT = Pool({ 55095, 55078, 191587, 194310 }, { 48792, 48707, 55233, 51271 }, { 108194, 207167, 47476, 49576 }, { 49998, 49184, 85948, 47541 }),
    DEMONHUNTER = Pool({ 1490, 204021, 207685, 179057 }, { 198589, 187827, 196555, 188499 }, { 179057, 217832, 207685, 211881 }, { 162794, 198013, 185123, 203720 }),
    DRUID = Pool({ 8921, 1079, 164812, 155722, 164815 }, { 774, 8936, 1126, 102342 }, { 339, 33786, 5211, 99 }, { 5176, 78674, 194153, 197628 }),
    EVOKER = Pool({ 370898, 357209, 355689, 372245 }, { 363916, 368412, 370960, 355913 }, { 360806, 358385, 370665, 374251 }, { 361469, 356995, 362969, 355936 }),
    HUNTER = Pool({ 217200, 257284, 271788, 19434 }, { 186257, 186254, 288613, 19574 }, { 3355, 19577, 109248, 187650 }, { 19434, 185358, 56641, 53351 }),
    MAGE = Pool({ 12654, 122, 157997, 44457 }, { 1459, 11426, 12042, 45438 }, { 118, 31661, 82691, 157981 }, { 133, 116, 30451, 44614 }),
    MONK = Pool({ 115804, 116095, 124273, 115078 }, { 119611, 116849, 120954, 122783 }, { 115078, 119381, 116705, 198898 }, { 100780, 107428, 116670, 117952 }),
    PALADIN = Pool({ 197277, 25771, 204242, 853 }, { 1022, 1044, 642, 31884 }, { 853, 20066, 115750, 105421 }, { 275779, 85256, 85673, 53595 }),
    PRIEST = Pool({ 589, 34914, 214621, 204213 }, { 17, 139, 10060, 47585 }, { 8122, 605, 64044, 9484 }, { 585, 2061, 8092, 15407 }),
    ROGUE = Pool({ 1943, 703, 2818, 2094 }, { 1856, 1966, 5277, 2983 }, { 6770, 1776, 408, 1833 }, { 196819, 53, 8676, 315341 }),
    SHAMAN = Pool({ 188389, 196840, 197209, 17364 }, { 61295, 974, 108271, 79206 }, { 51514, 51490, 118905, 192058 }, { 188196, 51505, 8004, 188443 }),
    WARLOCK = Pool({ 980, 146739, 172, 348 }, { 104773, 108416, 113860, 80240 }, { 5782, 30283, 6789, 710 }, { 686, 29722, 116858, 6353 }),
    WARRIOR = Pool({ 262115, 772, 115767, 6343 }, { 6673, 18499, 871, 1719 }, { 5246, 132168, 107570, 46968 }, { 100, 5308, 12294, 167105 }),
    FALLBACK = Pool({ 8921, 1079, 589, 980 }, { 774, 1459, 17, 6673 }, { 339, 118, 8122, 853 }, { 133, 116, 686, 188196 }),
}

local function SpellIcon(id, fallback)
    if type(id) ~= "number" then return fallback end
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    if info and info.iconID then return info.iconID end
    local tex = GetSpellTexture and GetSpellTexture(id)
    return tex or fallback
end

-- Walks the pool from index, wrapping, for the first icon this preview has not used yet.
local function PickIcon(pool, index, fallback, used)
    local n = #pool
    for step = 0, n - 1 do
        local pos = (index - 1 + step) % n + 1
        local icon = SpellIcon(pool[pos], fallback)
        if icon == nil then icon = GENERIC_ICONS[(pos - 1) % #GENERIC_ICONS + 1] end
        if icon ~= nil and not used[icon] then
            used[icon] = true
            return icon
        end
    end
    n = #GENERIC_ICONS
    for step = 0, n - 1 do
        local icon = GENERIC_ICONS[(index - 1 + step) % n + 1]
        if not used[icon] then
            used[icon] = true
            return icon
        end
    end
    return fallback or GENERIC_ICONS[1]
end

---------------------------------------------------------------- Enemy preview: build

local function BuildImageBorder(wrapper, path)
    local i = 0.042
    local f = 1 - i
    local lo, hi = 0.5 - i, 0.5 + i
    local PP = KT.PP
    local border = CreateFrame("Frame", nil, wrapper)
    border:SetFrameLevel(wrapper:GetFrameLevel() + 1)
    border:SetAllPoints(wrapper)
    local r, g, b = DBColor("borderColor")
    local function piece(l, rr, t, bb)
        local tex = border:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(path)
        tex:SetTexCoord(l, rr, t, bb)
        tex:SetVertexColor(r, g, b)
        Unsnap(tex)
        return tex
    end
    local tl, tr = piece(i, 0.5, i, 0.5), piece(0.5, f, i, 0.5)
    local bl, br = piece(i, 0.5, 0.5, f), piece(0.5, f, 0.5, f)
    local top, bottom = piece(lo, hi, i, 0.5), piece(lo, hi, 0.5, f)
    local left, right = piece(i, 0.5, lo, hi), piece(0.5, f, lo, hi)
    for _, c in ipairs({ tl, tr, bl, br }) do PP.Size(c, 6, 6) end
    PP.Point(tl, "TOPLEFT", border, "TOPLEFT", 0, 0)
    PP.Point(tr, "TOPRIGHT", border, "TOPRIGHT", 0, 0)
    PP.Point(bl, "BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
    PP.Point(br, "BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
    PP.Height(top, 6)
    PP.Point(top, "TOPLEFT", tl, "TOPRIGHT", 0, 0)
    PP.Point(top, "TOPRIGHT", tr, "TOPLEFT", 0, 0)
    PP.Height(bottom, 6)
    PP.Point(bottom, "BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
    PP.Point(bottom, "BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
    PP.Width(left, 6)
    PP.Point(left, "TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
    PP.Point(left, "BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
    PP.Width(right, 6)
    PP.Point(right, "TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
    PP.Point(right, "BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
    border._texs = { tl, tr, bl, br, top, bottom, left, right }
    return border
end

local function BuildSolidEdges(wrapper)
    local PP = KT.PP
    local edges = {}
    for n = 1, 4 do
        local t = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(0, 0, 0, 1)
        Unsnap(t)
        edges[n] = t
    end
    local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
    PP.Point(top, "TOPLEFT", wrapper, "TOPLEFT", 0, 0)
    PP.Point(top, "TOPRIGHT", wrapper, "TOPRIGHT", 0, 0)
    PP.Point(bottom, "BOTTOMLEFT", wrapper, "BOTTOMLEFT", 0, 0)
    PP.Point(bottom, "BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", 0, 0)
    PP.Point(left, "TOPLEFT", wrapper, "TOPLEFT", 0, 0)
    PP.Point(left, "BOTTOMLEFT", wrapper, "BOTTOMLEFT", 0, 0)
    PP.Point(right, "TOPRIGHT", wrapper, "TOPRIGHT", 0, 0)
    PP.Point(right, "BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", 0, 0)
    -- One unit at every UI scale: set directly, never through PP, never re-snapped.
    top:SetHeight(1)
    bottom:SetHeight(1)
    left:SetWidth(1)
    right:SetWidth(1)
    return edges
end

-- Icon frame with inset art, a one-pixel border, and a text layer above both.
local function BuildAuraIcon(pf, p, level, size, iconTexture)
    local icon = CreateFrame("Frame", nil, pf)
    icon:SetFrameLevel(level)
    icon:SetSize(size, size)
    local px = Snap(1)
    local art = icon:CreateTexture(nil, "ARTWORK")
    Unsnap(art)
    art:SetPoint("TOPLEFT", icon, "TOPLEFT", px, -px)
    art:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -px, px)
    art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    art:SetTexture(iconTexture)
    p.pixelBorders[#p.pixelBorders + 1] = MakeEdges(icon, px, true)
    p.insets[#p.insets + 1] = { art = art, icon = icon }
    local layer = CreateFrame("Frame", nil, icon)
    layer:SetAllPoints(icon)
    layer:SetFrameLevel(icon:GetFrameLevel() + 2)
    return icon, layer
end

local function BuildBarAndBorders(pf, p, level)
    local H = level + 10
    local health = CreateFrame("StatusBar", nil, pf)
    health:SetFrameLevel(H)
    health:SetStatusBarTexture(FLAT)
    Unsnap(health:GetStatusBarTexture())
    health:SetMinMaxValues(0, 10000)
    local bg = health:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(health)
    bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    Unsnap(bg)
    p.healthBG = bg

    p.markers = {}
    for n = 1, 3 do
        local m = health:CreateTexture(nil, "OVERLAY", nil, 3)
        m:SetPoint("TOP", health, "TOP")
        m:SetPoint("BOTTOM", health, "BOTTOM")
        m:SetWidth(Snap(2))
        m:SetColorTexture(1, 1, 1, 0.8)
        Unsnap(m)
        m:Hide()
        p.markers[n] = m
    end

    local wrapper = CreateFrame("Frame", nil, pf)
    wrapper:SetFrameLevel(H + 4)
    wrapper:EnableMouse(false)
    p.framed = BuildImageBorder(wrapper, SHARED .. "FramedPanel.tga")
    p.simple = BuildImageBorder(wrapper, SHARED .. "Outline1px.tga")
    p.edges = BuildSolidEdges(wrapper)

    local glow = CreateFrame("Frame", nil, pf)
    glow:SetFrameLevel(level + 1)
    glow:Hide()
    local soft = glow:CreateTexture(nil, "BACKGROUND")
    soft:SetAllPoints(glow)
    soft:SetTexture(MEDIA .. "border.png")
    soft:SetBlendMode("ADD")
    local hard = glow:CreateTexture(nil, "BACKGROUND")
    hard:SetAllPoints(glow)
    hard:SetTexture(MEDIA .. "border-colorless.png")
    hard:SetBlendMode("BLEND")
    p.glow, p.glowSoft, p.glowHard = glow, soft, hard

    local inBar = CreateFrame("Frame", nil, health)
    inBar:SetFrameLevel(H + 2)
    inBar:SetAllPoints(health)
    local above = CreateFrame("Frame", nil, pf)
    above:SetFrameLevel(H + 6)
    above:SetAllPoints(health)
    p.inBar, p.above = inBar, above

    pf._health, pf._healthWrapper = health, wrapper
end

local function BuildMarkersAndArrows(pf, H)
    local health = pf._health
    local raid = CreateFrame("Frame", nil, health)
    raid:SetFrameLevel(H + 6)
    local raidTex = raid:CreateTexture(nil, "ARTWORK")
    raidTex:SetAllPoints(raid)
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(raidTex, 8)
    else
        raidTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        raidTex:SetTexCoord(0.75, 1, 0.25, 0.5)
    end
    pf._raidFrame = raid

    local left = pf:CreateTexture(nil, "OVERLAY")
    local right = pf:CreateTexture(nil, "OVERLAY")
    left:SetSize(11, 16)
    right:SetSize(11, 16)
    left:SetPoint("RIGHT", health, "LEFT", -8, 0)
    right:SetPoint("LEFT", health, "RIGHT", 8, 0)
    left:Hide()
    right:Hide()
    pf._arrows = { left = left, right = right }
    if ns.RefreshTargetIndicatorTextures then
        ns.RefreshTargetIndicatorTextures(pf, nil, SavedT("targetArrowScale") or 1)
    else
        left:SetTexture(MEDIA .. "arrow_right.png")
        right:SetTexture(MEDIA .. "arrow_right.png")
        left:SetTexCoord(1, 0, 0, 1)
        right:SetTexCoord(0, 1, 0, 1)
    end

    local elite = pf:CreateTexture(nil, "OVERLAY")
    elite:SetSize(24, 24)
    if elite.SetAtlas then elite:SetAtlas("nameplates-icon-elite-gold", true) end
    elite:Hide()
    pf._classIcon = elite
end

local function BuildCast(pf, p, level, castIcon)
    local C = defaults.castBarHeight or 20
    local cast = CreateFrame("StatusBar", nil, pf)
    cast:SetFrameLevel(level + 10)
    cast:SetStatusBarTexture(FLAT)
    Unsnap(cast:GetStatusBarTexture())
    cast:SetMinMaxValues(0, 1)
    local bg = cast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(cast)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    Unsnap(bg)
    p.castBG = bg

    local holder = CreateFrame("Frame", nil, cast)
    holder:SetSize(C, C)
    holder:SetPoint("TOPRIGHT", cast, "TOPLEFT", 0, 0)
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(holder)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(castIcon)
    Unsnap(icon)
    p.castIcon, p.castIconTexture = icon, castIcon
    p.pixelBorders[#p.pixelBorders + 1] = MakeEdges(holder, Snap(1), true)

    local spark = cast:CreateTexture(nil, "OVERLAY", nil, 1)
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetSize(8, C)
    spark:SetPoint("CENTER", cast:GetStatusBarTexture(), "RIGHT", 0, 0)
    spark:SetBlendMode("ADD")
    Unsnap(spark)
    p.spark = spark

    pf._cast, pf._castIconFrame = cast, holder
end

local function BuildClassPower(pf, level)
    local pips = {}
    for i = 1, 10 do
        local back = pf:CreateTexture(nil, "OVERLAY", nil, 2)
        back:SetColorTexture(0.082, 0.082, 0.082, 1)
        back:Hide()
        local pip = pf:CreateTexture(nil, "OVERLAY", nil, 3)
        pip:SetSize(8, 3)
        pip:SetColorTexture(1, 1, 1, 1)
        pip:Hide()
        pip._bg = back
        pips[i] = pip
    end
    pf._cpPips = pips
    pf._cpMax = 10

    local bar = CreateFrame("StatusBar", nil, pf)
    bar:SetFrameLevel(level + 5)
    bar:SetStatusBarTexture(FLAT)
    bar:Hide()
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(0.082, 0.082, 0.082, 1)
    bar._bg = bg
    pf._cpBar = bar
end

local function BuildTexts(pf, p, fontPath, outline)
    local health, cast = pf._health, pf._cast
    local pct = rollPct or 70

    local name = NewFontString(pf, true)
    PreviewFont(name, fontPath, 11, outline)
    name:SetPoint("BOTTOM", health, "TOP", 0, 4)
    name:SetText(LText("Enemy Name Text"))
    name:SetTextColor(1, 1, 1, 1)
    pf._nameFS = name

    local level = NewFontString(p.above, true)
    level:SetJustifyH("LEFT")
    level:SetSize(160, 48)
    level:SetPoint("BOTTOMLEFT", health, "TOPLEFT", 24, 4)
    pf._levelFS = level

    local percent = NewFontString(p.inBar)
    PreviewFont(percent, fontPath, 10, outline)
    percent:SetPoint("RIGHT", health, "RIGHT", -2, 0)
    percent:SetText(pct .. "%")
    pf._hpText = percent

    local number = NewFontString(p.inBar)
    PreviewFont(number, fontPath, 10, outline)
    number:SetPoint("CENTER", health, "CENTER", 0, 0)
    number:SetText(FormatThousands(floor(10000 * pct / 100)))
    number:Hide()
    pf._hpNumber = number

    local spell = NewFontString(cast, true)
    PreviewFont(spell, fontPath, 10, outline)
    spell:SetPoint("LEFT", cast, "LEFT", 5, 0)
    spell:SetJustifyH("LEFT")
    spell:SetText(LText("Spell Name"))
    pf._castNameFS = spell

    local target = NewFontString(cast, true)
    PreviewFont(target, fontPath, 10, outline)
    target:SetPoint("RIGHT", cast, "RIGHT", -3, 0)
    target:SetJustifyH("RIGHT")
    target:SetText(UnitName("player") or LText("Spell Target"))
    pf._castTargetFS = target
end

local DEBUFF_FALLBACKS = { 136096, 132152, 132123, 132122 }
local BUFF_FALLBACKS = { 136081, 136078 }
local CC_FALLBACKS = { 136100, 135848 }
local DEBUFF_TIMERS = { "8", "14", "6", "11" }
local DEBUFF_STACKS = { "", "3", "", "2" }
local BUFF_TIMERS = { "12", "7" }
local CC_TIMERS = { "5", "3" }

local function BuildAuras(pf, p, H, pool, used, fontPath)
    local name = pf._nameFS
    pf._debuffs = {}
    for i = 1, 4 do
        local icon, layer = BuildAuraIcon(pf, p, H + 8, 26, PickIcon(pool.debuffs, i, DEBUFF_FALLBACKS[i], used))
        icon:SetPoint("BOTTOM", name, "TOP", (i - 2.5) * 30, 2)
        local timer = layer:CreateFontString(nil, "OVERLAY")
        timer:SetFont(fontPath, 11, "OUTLINE")
        timer:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 4)
        timer:SetJustifyH("LEFT")
        timer:SetText(DEBUFF_TIMERS[i])
        local stack = layer:CreateFontString(nil, "OVERLAY")
        stack:SetFont(fontPath, 11, "OUTLINE")
        stack:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 1)
        stack:SetJustifyH("RIGHT")
        stack:SetText(DEBUFF_STACKS[i])
        icon.durationText, icon.stackText = timer, stack
        pf._debuffs[i] = icon
    end
    local function small(kind, fallbacks, timers)
        local out = {}
        for i = 1, 2 do
            local icon, layer = BuildAuraIcon(pf, p, H + 8, 24, PickIcon(kind, i, fallbacks[i], used))
            local timer = layer:CreateFontString(nil, "OVERLAY")
            timer:SetFont(fontPath, 12, "OUTLINE")
            timer:SetPoint("CENTER", icon, "CENTER", 0, 0)
            timer:SetText(timers[i])
            icon.durationText = timer
            out[i] = icon
        end
        return out
    end
    pf._buffs = small(pool.buffs, BUFF_FALLBACKS, BUFF_TIMERS)
    pf._ccs = small(pool.ccs, CC_FALLBACKS, CC_TIMERS)
end

---------------------------------------------------------------- Enemy preview: level text

local function ApplyLevelStyle(fs)
    if not isForever then
        if ns.ApplyNameplateLevelTextStyle then ns.ApplyNameplateLevelTextStyle(fs) end
        return
    end
    local path = ns.ResolveNameplateFont(Saved("levelFont"))
    local size = tonumber(Saved("levelFontSize")) or defaults.levelFontSize or 11
    size = max(6, min(48, size))
    local outline = Saved("levelFontOutline")
    if outline == "NONE" then
        outline = ""
    elseif type(outline) ~= "string" then
        outline = "OUTLINE"
    end
    if not pcall(fs.SetFont, fs, path, size, outline) then
        pcall(fs.SetFont, fs, ns.DEFAULT_FONT_PATH, size, outline)
    end
    local c = Saved("levelColor") or {}
    fs:SetTextColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
    if Saved("levelShadow") == false then
        fs:SetShadowColor(0, 0, 0, 0)
        fs:SetShadowOffset(0, 0)
    else
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    end
end

local function RefreshLevel(pf, ctx)
    local fs = pf._levelFS
    ApplyLevelStyle(fs)
    fs:SetText("30")
    fs:SetSize(max(80, ctx.barW + 80), max(16, (tonumber(Saved("levelFontSize")) or 11) + 6))
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOMLEFT", pf._health, "TOPLEFT", tonumber(Saved("levelXOffset")) or 24, tonumber(Saved("levelYOffset")) or 4)
    local shown
    if isForever then
        shown = not (Saved("showLevel") == false or (ns.HideRetailKuiLevel and ns.HideRetailKuiLevel()))
    else
        shown = Saved("showEnemyLevel") == true and ns.NameplateStyle ~= nil and ns.NameplateStyle() ~= "kui"
    end
    fs:SetShown(shown)
end

---------------------------------------------------------------- Enemy preview: Refresh context

local TEXT_SLOT_KEYS = { "textSlotTop", "textSlotRight", "textSlotLeft", "textSlotCenter" }

local function TextSlot(key)
    if (key == "textSlotTop" or key == "textSlotLeft") and ns.GetTextSlot then
        local v = ns.GetTextSlot(key)
        if v then return v end
    end
    return SavedT(key)
end

local CP_CLASSES = {
    ROGUE = { power = "ComboPoints", default = 5, combo = true },
    DRUID = { power = "ComboPoints", default = 5, combo = true },
    PALADIN = { power = "HolyPower", default = 5 },
    WARLOCK = { power = "SoulShards", default = 5 },
    MAGE = { power = "ArcaneCharges", default = 4 },
    EVOKER = { power = "Essence", default = 5 },
    DEATHKNIGHT = { power = "Runes", default = 6 },
    MONK = { bySpec = true, [268] = { stagger = true, default = 1 }, [269] = { power = "Chi", default = 5 } },
    DEMONHUNTER = { bySpec = true, [581] = { default = 6 } },
    SHAMAN = { bySpec = true, [263] = { maelstrom = true, default = 10 } },
    HUNTER = { bySpec = true, [255] = { default = 3 } },
    WARRIOR = { bySpec = true, [72] = { default = 4 } },
}

local PlayerSpecID

-- The resource's own piece for a preview entry, unless the flat bars are chosen.
local function EntryArt(entry)
    if not (entry and entry.power and ns.ClassPowerResourceArt and ns.GetClassPowerShape) then return nil end
    if ns.GetClassPowerShape() == "pip" then return nil end
    return ns.ClassPowerResourceArt(Enum.PowerType[entry.power])
end

-- Extra space above the bar for class power at the top. Spec-keyed classes use the plain height.
local function TopPush()
    if Saved("showClassPower") ~= true or Saved("classPowerPos") ~= "top" then return 0 end
    local scale = Saved("classPowerScale")
    local h = 3 * scale
    local _, class = UnitClass("player")
    local entry = CP_CLASSES[class]
    if entry and entry.bySpec then entry = entry[PlayerSpecID() or 0] end
    local art = EntryArt(entry)
    if entry and (entry.combo or art) and ns.ClassPowerPipLayout then
        local _, layoutH = ns.ClassPowerPipLayout(entry.combo == true, scale, Saved("classPowerGap"), nil, art and art.aspect)
        h = layoutH
    end
    return h + Saved("classPowerYOffset")
end

local FAMILIES = {
    { field = "_debuffs", slotKey = "debuffSlot", fixed = 26, timerKey = "debuffTimerPosition", isDebuff = true },
    { field = "_buffs", slotKey = "buffSlot", fixed = 24, timerKey = "buffTimerPosition" },
    { field = "_ccs", slotKey = "ccSlot", fixed = 24, timerKey = "ccTimerPosition" },
}

local function SlotOffsets(slot)
    if slot == "none" then return 0, 0 end
    return Saved(slot .. "SlotXOffset") or 0, Saved(slot .. "SlotYOffset") or 0
end

local function ReadFamilies(pf)
    local out = {}
    for n, def in ipairs(FAMILIES) do
        local slot = SavedT(def.slotKey)
        local size = def.fixed
        if slot ~= "none" then size = SavedT(slot .. "SlotSize") or def.fixed end
        local sx, sy = SlotOffsets(slot)
        out[n] = {
            def = def, icons = pf[def.field], n = #pf[def.field], slot = slot, size = size,
            spacing = size + SavedT("auraSpacing"), sx = sx, sy = sy,
        }
    end
    return out
end

local function ReadRaidMarker()
    local slot = SavedT("raidMarkerPos")
    local size = 24
    if slot ~= "none" then size = SavedT(slot .. "SlotSize") or 24 end
    local x, y = SlotOffsets(slot)
    return { slot = slot, size = size, x = x, y = y, lift = 0, shown = slot ~= "none" and P.flags.raidMarker }
end

local function ReadElite()
    local slot = SavedT("classificationSlot")
    local size = tonumber(Saved("rareEliteIconSize")) or defaults.rareEliteIconSize or 20
    local x, y = tonumber(Saved("classificationXOffset")) or 0, tonumber(Saved("classificationYOffset")) or 0
    if slot == "none" then x, y = 0, 0 end
    return { slot = slot, size = size, x = x, y = y, lift = 2, shown = slot ~= "none" and P.flags.classification }
end

local function NewContext(pf)
    local ctx = {}
    local rawW
    if ns.GetHealthBarWidth then rawW = ns.GetHealthBarWidth() end
    rawW = rawW or (barBase + Saved("healthBarWidth"))
    local h = ns.GetHealthBarHeight and ns.GetHealthBarHeight()
    ctx.rawW = rawW
    ctx.barH = Snap(h or Saved("healthBarHeight"))
    ctx.drag = (KT._sliderDragging or 0) > 0
    ctx.barW = ctx.drag and rawW or Snap(rawW)
    ctx.castH = Snap(SavedT("castBarHeight"))
    ctx.path = KT.GetNPFontPath("nameplates") or Saved("font")
    ctx.outline = KT.GetNPFontOutline() or "OUTLINE"
    ctx.cpPush = TopPush()
    pf._cpTopPush = ctx.cpPush

    local pct = rollPct or 70
    ctx.pct = pct
    ctx.healthValue = floor(10000 * pct / 100)

    ctx.d = SavedT("debuffYOffset")
    ctx.side = SavedT("sideAuraXOffset")
    ctx.nameY = SavedT("nameYOffset")

    ctx.slots = {}
    for _, key in ipairs(TEXT_SLOT_KEYS) do ctx.slots[key] = TextSlot(key) end
    local top = ctx.slots.textSlotTop
    ctx.topHolds = top
    ctx.topX = SavedT("textSlotTopXOffset") or 0
    ctx.topY = SavedT("textSlotTopYOffset") or 0
    ctx.topSize = SavedT("textSlotTopSize")
    ctx.p = top == "none" and ctx.cpPush or 0
    if top == "enemyName" then
        ctx.topAnchor = pf._nameFS
    elseif top == "healthNumber" then
        ctx.topAnchor = pf._hpNumber
    elseif top == "none" then
        ctx.topAnchor = pf._health
    else
        ctx.topAnchor = pf._hpText
    end

    ctx.families = ReadFamilies(pf)
    ctx.raid = ReadRaidMarker()
    ctx.elite = ReadElite()
    return ctx
end

---------------------------------------------------------------- Enemy preview: Refresh parts

local function RefreshIndicator(pf)
    local scale = SavedT("targetArrowScale") or 1
    if ns.RefreshTargetIndicatorTextures then
        ns.RefreshTargetIndicatorTextures(pf, SavedT("targetIndicatorStyle") or "arrows", scale)
    else
        local w, h = floor(11 * scale + 0.5), floor(16 * scale + 0.5)
        pf._arrows.left:SetSize(w, h)
        pf._arrows.right:SetSize(w, h)
    end
end

local function RefreshBorders(p)
    local style = SavedT("borderStyle")
    p.framed:SetShown(style ~= "none" and style ~= "simple")
    p.simple:SetShown(style == "simple")
    for _, e in ipairs(p.edges) do e:SetShown(style ~= "none") end

    local px = Snap(1)
    for _, set in ipairs(p.pixelBorders) do SetEdgeThickness(set, px) end
    for _, inset in ipairs(p.insets) do
        inset.art:SetPoint("TOPLEFT", inset.icon, "TOPLEFT", px, -px)
        inset.art:SetPoint("BOTTOMRIGHT", inset.icon, "BOTTOMRIGHT", -px, px)
    end

    local c = SavedT("borderColor")
    for _, t in ipairs(p.framed._texs) do t:SetVertexColor(c.r, c.g, c.b) end
    for _, t in ipairs(p.simple._texs) do t:SetVertexColor(c.r, c.g, c.b) end
    for _, e in ipairs(p.edges) do e:SetColorTexture(c.r, c.g, c.b, 1) end
end

local function RefreshCastBar(pf, p, ctx)
    local cast, holder = pf._cast, pf._castIconFrame
    local castH = ctx.castH
    cast:ClearAllPoints()
    cast:SetSize(ctx.barW, castH)
    cast:SetPoint("TOPLEFT", pf._health, "BOTTOMLEFT", 0, 0)
    local c = SavedT("castBar")
    cast:SetStatusBarColor(c.r, c.g, c.b, 1)
    cast:SetValue(rollFill or 0.60)
    p.castIcon:SetTexture(p.castIconTexture)

    local db = _G.KullThranUINameplatesDB
    if db and db.showCastIcon == false then
        holder:SetSize(castH, castH)
        holder:Hide()
    else
        holder:SetScale(1)
        local size = castH * SavedT("castIconScale")
        holder:SetSize(size, size)
        holder:ClearAllPoints()
        -- No default ships for these offsets, so they can be nil: see F16 in the specification.
        local x, y = SavedT("castIconXOffset"), SavedT("castIconYOffset")
        if db and db.castIconSide == "right" then
            holder:SetPoint("TOPLEFT", cast, "TOPRIGHT", x, y)
        else
            holder:SetPoint("TOPRIGHT", cast, "TOPLEFT", x, y)
        end
        holder:Show()
    end
    p.spark:SetHeight(castH)
end

local function RefreshSpellText(pf, ctx)
    local cast, spell, target = pf._cast, pf._castNameFS, pf._castTargetFS
    PreviewFont(spell, ctx.path, SavedT("castNameSize"), ctx.outline)
    PreviewFont(target, ctx.path, SavedT("castTargetSize"), ctx.outline)
    local c = SavedT("castNameColor")
    spell:SetTextColor(c.r, c.g, c.b, 1)
    local r, g, b = CastTargetTint()
    target:SetTextColor(r, g, b, 1)
    local nx, ny = SavedT("castNameXOffset") or 0, SavedT("castNameYOffset") or 0
    local tx, ty = SavedT("castTargetXOffset") or 0, SavedT("castTargetYOffset") or 0
    target:ClearAllPoints()
    target:SetPoint("RIGHT", cast, "RIGHT", -3 + tx, ty)
    spell:ClearAllPoints()
    spell:SetPoint("LEFT", cast, "LEFT", 5 + nx, ny)
    local measured
    if target.GetUnboundedStringWidth then measured = target:GetUnboundedStringWidth() else measured = target:GetStringWidth() end
    spell:SetWidth(max(20, ctx.barW - (5 + nx) - (3 - tx) - measured - 5))
end

local function RefreshHealthMarkers(pf, p, ctx)
    local cfg = MarkerCfg()
    local values = {}
    local on = type(cfg) == "table" and cfg.enabled == true
    if on then values = ParseMarkerValues(cfg.values, 100) end
    local health = pf._health
    for n, m in ipairs(p.markers) do
        local pct = values[n]
        if pct then
            local x = ctx.barW * pct / 100
            m:ClearAllPoints()
            m:SetPoint("TOP", health, "TOPLEFT", x, 0)
            m:SetPoint("BOTTOM", health, "BOTTOMLEFT", x, 0)
            m:SetWidth(Snap(tonumber(cfg.width) or 2))
            m:SetColorTexture(cfg.colorR or 1, cfg.colorG or 1, cfg.colorB or 1, cfg.colorA or 0.80)
            m:Show()
        else
            m:Hide()
        end
    end
end

---------------------------------------------------------------- Aura slots

local function RefreshTimer(icon, def, path)
    local timer = icon.durationText
    local pos = Saved(def.timerKey) or Saved("auraTextPosition") or Saved("debuffTextPosition") or defaults.auraTextPosition
    timer:SetFont(path, SavedT("auraDurationTextSize"), "OUTLINE")
    local c = SavedT("auraDurationTextColor")
    timer:SetTextColor(c.r, c.g, c.b, 1)
    if pos == "none" then
        timer:Hide()
        return
    end
    timer:Show()
    local x, y = SavedT("auraDurationXOffset") or 0, SavedT("auraDurationYOffset") or 0
    timer:ClearAllPoints()
    if pos == "center" then
        timer:SetPoint("CENTER", icon, "CENTER", x, y)
        timer:SetJustifyH("CENTER")
    elseif pos == "topright" then
        timer:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 3 + x, 4 + y)
        timer:SetJustifyH("RIGHT")
    else
        timer:SetPoint("TOPLEFT", icon, "TOPLEFT", -3 + x, 4 + y)
        timer:SetJustifyH("LEFT")
    end
end

local function RefreshStack(icon, path)
    local stack = icon.stackText
    if not stack then return end
    stack:SetFont(path, SavedT("auraStackTextSize"), "OUTLINE")
    local c = SavedT("auraStackTextColor")
    stack:SetTextColor(c.r, c.g, c.b, 1)
    local x, y = SavedT("auraStackXOffset") or 0, SavedT("auraStackYOffset") or 0
    stack:ClearAllPoints()
    stack:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1 + x, 1 + y)
    stack:SetJustifyH("RIGHT")
end

local function TopDebuffAlign()
    local v = SavedT("topDebuffAlign") or "center"
    if v == "left" or v == "right" then return v end
    return "center"
end

local function TopDebuffOffsetX()
    return SavedT("topDebuffOffsetX") or 0
end

local function AnchorTopDebuff(icon, fam, i, c, health, ctx)
    local e = 0
    if ctx.topHolds ~= "none" then e = 4 + ctx.nameY + ctx.topY + ctx.topSize end
    local y = ctx.d + ctx.p + fam.sy + e
    local o = TopDebuffOffsetX()
    local align = TopDebuffAlign()
    if align == "left" then
        icon:SetPoint("BOTTOMLEFT", health, "TOPLEFT", (i - 1) * fam.spacing + fam.sx + o, y)
    elseif align == "right" then
        icon:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", -(fam.n - i) * fam.spacing + fam.sx + o, y)
    else
        icon:SetPoint("BOTTOM", health, "TOP", c + fam.sx + o, y)
    end
end

local function AnchorCorner(icon, fam, i, health, ctx)
    local isLeft = fam.slot == "topleft"
    local growth = SavedT(fam.slot .. "SlotGrowth")
    local travel = (i - 1) * fam.spacing
    local x0 = (isLeft and -2 or 2) + fam.sx
    local y0 = ctx.d + ctx.cpPush + fam.sy
    local x, y = x0, y0
    if growth == "up" then
        y = y0 + travel
    elseif isLeft then
        x = growth == "right" and x0 + travel or x0 - travel
    else
        x = growth == "left" and x0 - travel or x0 + travel
    end
    if isLeft then
        icon:SetPoint("BOTTOMLEFT", health, "TOPLEFT", x, y)
    else
        icon:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", x, y)
    end
end

local function AnchorAura(pf, icon, fam, i, ctx)
    local health = pf._health
    local slot = fam.slot
    local c = (i - (fam.n + 1) / 2) * fam.spacing
    icon:ClearAllPoints()
    if slot == "top" then
        if fam.def.isDebuff then
            AnchorTopDebuff(icon, fam, i, c, health, ctx)
        else
            icon:SetPoint("BOTTOM", ctx.topAnchor, "TOP", c + fam.sx, ctx.d + ctx.p + fam.sy)
        end
    elseif slot == "left" then
        icon:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", -ctx.side - (i - 1) * fam.spacing + fam.sx, fam.sy)
    elseif slot == "right" then
        icon:SetPoint("BOTTOMLEFT", health, "BOTTOMRIGHT", ctx.side + (i - 1) * fam.spacing + fam.sx, fam.sy)
    elseif slot == "topleft" or slot == "topright" then
        AnchorCorner(icon, fam, i, health, ctx)
    elseif slot == "bottom" then
        icon:SetPoint("TOP", pf._cast, "BOTTOM", c + fam.sx, fam.sy - 2)
    end
end

local function RefreshAuras(pf, ctx)
    for _, fam in ipairs(ctx.families) do
        for i, icon in ipairs(fam.icons) do
            if fam.slot == "none" then
                icon:Hide()
            else
                icon:Show()
                icon:SetSize(Snap(fam.size), Snap(fam.size))
                RefreshTimer(icon, fam.def, ctx.path)
                RefreshStack(icon, ctx.path)
                AnchorAura(pf, icon, fam, i, ctx)
            end
        end
    end
end

-- A marker in the bottom slot stays cleared while shown: see F10 in the specification.
local function AnchorMarker(frame, m, pf, ctx)
    local health = pf._health
    local slot = m.slot
    if slot == "top" then
        frame:SetPoint("BOTTOM", health, "TOP", m.x, ctx.d + ctx.cpPush + m.y)
    elseif slot == "left" then
        frame:SetPoint("RIGHT", health, "LEFT", m.x - ctx.side, m.y)
    elseif slot == "right" then
        frame:SetPoint("LEFT", health, "RIGHT", m.x + ctx.side, m.y)
    elseif slot == "topleft" then
        frame:SetPoint("BOTTOMLEFT", health, "TOPLEFT", m.x - 2, m.lift + ctx.cpPush + m.y)
    elseif slot == "topright" then
        frame:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", m.x + 2, m.lift + ctx.cpPush + m.y)
    end
end

local function RefreshMarkerIcons(pf, ctx)
    local raid, elite = ctx.raid, ctx.elite
    local frame = pf._raidFrame
    frame:ClearAllPoints()
    frame:SetSize(raid.size, raid.size)
    if raid.shown then
        AnchorMarker(frame, raid, pf, ctx)
        frame:SetAlpha(1)
    end
    frame:SetShown(raid.shown)
    if pf._raidOverlay then pf._raidOverlay:SetShown(raid.shown) end

    local icon = pf._classIcon
    icon:ClearAllPoints()
    icon:SetSize(elite.size, elite.size)
    if elite.shown then AnchorMarker(icon, elite, pf, ctx) end
    icon:SetShown(elite.shown)
    if pf._classOverlay then pf._classOverlay:SetShown(elite.shown) end
end

local function RefreshArrows(pf, ctx)
    local on = Saved("showTargetArrows") == true
    local left, right = pf._arrows.left, pf._arrows.right
    if on then
        local leftExtent, rightExtent = 0, 0
        for _, fam in ipairs(ctx.families) do
            local reach = ctx.side + (fam.n - 1) * fam.spacing + fam.size
            if fam.slot == "left" then leftExtent = max(leftExtent, reach - fam.sx) end
            if fam.slot == "right" then rightExtent = max(rightExtent, reach + fam.sx) end
        end
        for _, m in ipairs({ ctx.raid, ctx.elite }) do
            if m.shown then
                local reach = ctx.side + m.size
                if m.slot == "left" then leftExtent = max(leftExtent, reach - m.x) end
                if m.slot == "right" then rightExtent = max(rightExtent, reach + m.x) end
            end
        end
        left:ClearAllPoints()
        left:SetPoint("RIGHT", pf._health, "LEFT", -(leftExtent + 8), 0)
        right:ClearAllPoints()
        right:SetPoint("LEFT", pf._health, "RIGHT", rightExtent + 8, 0)
    end
    if ns.SetTargetIndicatorShown then
        ns.SetTargetIndicatorShown(pf, on)
    else
        left:SetShown(on)
        right:SetShown(on)
    end
    if pf._arrowOverlay then pf._arrowOverlay:SetShown(on) end
end

---------------------------------------------------------------- Text slots

local IN_BAR = {
    textSlotRight = { point = "RIGHT", inset = -2 },
    textSlotLeft = { point = "LEFT", inset = 4 },
    textSlotCenter = { point = "CENTER", inset = 0 },
}

-- Which string shows an element and what it reads.
local function TextForElement(pf, el, ctx)
    local percent, plain = ctx.pct .. "%", tostring(ctx.pct)
    local number = FormatThousands(ctx.healthValue)
    if el == "enemyName" then return pf._nameFS, LText("Enemy Name Text") end
    if el == "healthPercent" then return pf._hpText, percent end
    if el == "healthPercentNoSign" then return pf._hpText, plain end
    if el == "healthNumber" then return pf._hpNumber, number end
    if el == "healthPctNum" then return pf._hpText, percent .. " | " .. number end
    if el == "healthNumPct" then return pf._hpText, number .. " | " .. percent end
end

local function TopNameWidth(ctx)
    local width = ctx.barW
    if ctx.raid.slot ~= "none" and P.flags.raidMarker then width = width - (2 * (ctx.raid.size - 2) + 7) end
    if P.flags.classification and ctx.elite.slot ~= "none" then width = width - (ctx.elite.size + 4) end
    return max(20, width)
end

local function InBarNameWidth(key, ctx)
    local width = ctx.barW
    for other in pairs(IN_BAR) do
        local el = ctx.slots[other]
        if other ~= key and el ~= "none" and el ~= "enemyName" then
            width = width - ns.EstimateHealthTextWidth(el)
        end
    end
    return max(20, width)
end

-- Font, parent, text, anchor, colour, Show. A shared string keeps every anchor: see F18.
local function PlaceSlot(pf, p, key, ctx)
    local el = ctx.slots[key]
    local fs, text = TextForElement(pf, el, ctx)
    if not fs then return end
    local x, y = SavedT(key .. "XOffset") or 0, SavedT(key .. "YOffset") or 0
    PreviewFont(fs, ctx.path, SavedT(key .. "Size"), ctx.outline)
    local place = IN_BAR[key]
    fs:SetParent(place and p.inBar or p.above)
    fs:SetText(text)
    if place then
        fs:SetPoint(place.point, pf._health, place.point, place.inset + x, y)
        if el == "enemyName" then
            fs:SetJustifyH(place.point)
            fs:SetWidth(InBarNameWidth(key, ctx))
        end
    else
        fs:SetPoint("BOTTOM", pf._health, "TOP", x, 4 + ctx.nameY + ctx.cpPush + y)
        if el == "enemyName" then
            fs:SetJustifyH("CENTER")
            fs:SetWidth(TopNameWidth(ctx))
        end
    end
    local c = SavedT(key .. "Color")
    fs:SetTextColor(c.r, c.g, c.b, 1)
    fs:Show()
end

local function RefreshTextSlots(pf, p, ctx)
    for _, fs in ipairs({ pf._nameFS, pf._hpText, pf._hpNumber }) do
        fs:Hide()
        fs:ClearAllPoints()
    end
    for _, key in ipairs(TEXT_SLOT_KEYS) do PlaceSlot(pf, p, key, ctx) end
end

---------------------------------------------------------------- Class power

PlayerSpecID = function()
    local info = C_SpecializationInfo
    local index
    if info and info.GetSpecialization then index = info.GetSpecialization() end
    if not index and GetSpecialization then index = GetSpecialization() end
    if not index then return nil end
    if info and info.GetSpecializationInfo then return (info.GetSpecializationInfo(index)) end
    if GetSpecializationInfo then return (GetSpecializationInfo(index)) end
end

local function PipCount(entry)
    if entry.power then
        local kind = Enum.PowerType[entry.power]
        local m = UnitPowerMax("player", kind)
        if m and m > 0 then return m end
        return entry.default
    end
    if entry.maelstrom then
        local _, m = KT.GetMaelstromWeapon()
        if m and m > 0 then return m end
        return 10
    end
    return entry.default
end

local function ClassPowerColor(class, entry)
    if Saved("classPowerClassColors") then
        if entry.power and ns.ClassPowerResourceColor then
            local rr, rg, rb = ns.ClassPowerResourceColor(Enum.PowerType[entry.power])
            if rr then return rr, rg, rb end
        end
        local colors = ns.CP_CLASS_COLORS or {}
        local c = colors[class] or ns.CP_DEFAULT_COLOR
        if c then return c[1], c[2], c[3] end
        return 1, 0.84, 0.30
    end
    local c = SavedT("classPowerCustomColor")
    return c.r, c.g, c.b
end

local function HidePip(pip)
    pip:Hide()
    pip._bg:Hide()
    if pip._circleBorder then pip._circleBorder:Hide() end
    if pip._cpIcon then pip._cpIcon:Hide() end
    if ns.SetClassPowerPipDecor then ns.SetClassPowerPipDecor(pip, false) end
end

local function ShowStagger(pf, cp)
    local bar = pf._cpBar
    local w, h = Snap(8 * cp.scale * 6), Snap(3 * cp.scale)
    bar:SetSize(w, h)
    bar:ClearAllPoints()
    if cp.pos == "top" then
        bar:SetPoint("BOTTOM", pf._health, "TOP", Snap(cp.xOff), Snap(cp.yOff))
    else
        bar:SetPoint("TOP", pf._cast, "BOTTOM", Snap(cp.xOff), Snap(-cp.yOff))
    end
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(45)
    bar:SetStatusBarColor(1, 0.85, 0.2, 1)
    local c = SavedT("classPowerBgColor")
    bar._bg:SetColorTexture(c.r, c.g, c.b, c.a)
    bar:Show()
    return h
end

local function ShowPip(pf, pip, i, cp, layout)
    local isTop = cp.pos == "top"
    local dir = isTop and 1 or -1
    pip:SetSize(layout.w, layout.h)
    pip:ClearAllPoints()
    local x = Snap(Snap((i - 1) * layout.pitch) - layout.half + cp.xOff)
    if isTop then
        pip:SetPoint("BOTTOMLEFT", pf._health, "TOP", x, Snap(dir * cp.yOff))
    else
        pip:SetPoint("TOPLEFT", pf._cast, "BOTTOM", x, Snap(dir * cp.yOff))
    end
    if ns.ApplyClassPowerPipShape then ns.ApplyClassPowerPipShape(pip, layout.round) end

    local back = pip._bg
    back:ClearAllPoints()
    back:SetAllPoints(pip)
    local bg = SavedT("classPowerBgColor")
    if layout.comboRed then
        back:SetColorTexture(0.22, 0.02, 0.02, bg.a)
    else
        back:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    end
    back:Show()

    local filled = i <= layout.filled
    if layout.art then
        ns.StyleClassPowerArtPip(pip, layout.art, i, filled, layout.artR, layout.artG, layout.artB, layout.artTinted)
        Unsnap(pip)
        pip:Show()
        return
    end
    pip:SetDesaturated(false)
    pip:SetVertexColor(1, 1, 1, 1)
    local empty = SavedT("classPowerEmptyColor")
    if filled then
        if layout.comboRed then
            pip:SetColorTexture(1, 0.05, 0.05, 1)
        else
            pip:SetColorTexture(layout.r, layout.g, layout.b, 1)
        end
    elseif layout.comboRed then
        pip:SetColorTexture(0.22, 0.02, 0.02, empty.a)
    else
        pip:SetColorTexture(empty.r, empty.g, empty.b, empty.a)
    end
    if ns.StyleForeverComboPip then
        local lr, lg, lb = 1, 0.05, 0.05
        if not layout.comboRed then lr, lg, lb = layout.r, layout.g, layout.b end
        ns.StyleForeverComboPip(pip, filled, lr, lg, lb)
    end
    Unsnap(pip)
    pip:Show()
end

local function ShowPips(pf, cp, entry, class, count)
    local scale = cp.scale
    local gap = SavedT("classPowerGap")
    local art, artR, artG, artB = EntryArt(entry)
    local w, h, g, round, comboRed = 8 * scale, 3 * scale, gap * scale, false, false
    if ns.ClassPowerPipLayout then w, h, g, round, comboRed = ns.ClassPowerPipLayout(entry.combo == true, scale, gap, nil, art and art.aspect) end
    w, h, g = Snap(w), Snap(h), Snap(g)
    local pitch = w + g
    local shownCount = min(count, pf._cpMax)
    local r, gr, b = ClassPowerColor(class, entry)
    local artTinted = art and not Saved("classPowerClassColors")
    if artTinted then artR, artG, artB = r, gr, b end
    local layout = {
        art = art, artR = artR, artG = artG, artB = artB, artTinted = artTinted,
        w = w, h = h, pitch = pitch, round = round, comboRed = comboRed, r = r, g = gr, b = b,
        half = Snap((Snap((count - 1) * pitch) + w) / 2),
        filled = floor(count * 0.70 + 0.5),
    }
    for i = 1, pf._cpMax do
        if i <= shownCount then
            ShowPip(pf, pf._cpPips[i], i, cp, layout)
        else
            HidePip(pf._cpPips[i])
        end
    end
    return h
end

-- Returns the room needed below the cast bar.
local function RefreshClassPower(pf)
    local entry, class
    local count = 0
    if Saved("showClassPower") == true then
        local _, c = UnitClass("player")
        class = c
        entry = CP_CLASSES[class]
        if entry and entry.bySpec then entry = entry[PlayerSpecID() or 0] end
        if entry then count = PipCount(entry) end
    end
    if count <= 0 then
        for _, pip in ipairs(pf._cpPips) do HidePip(pip) end
        pf._cpBar:Hide()
        return 0
    end
    local cp = {
        scale = SavedT("classPowerScale"), yOff = SavedT("classPowerYOffset"),
        xOff = SavedT("classPowerXOffset"), pos = SavedT("classPowerPos"),
    }
    local h
    if entry.stagger then
        for _, pip in ipairs(pf._cpPips) do HidePip(pip) end
        h = ShowStagger(pf, cp)
    else
        pf._cpBar:Hide()
        h = ShowPips(pf, cp, entry, class, count)
    end
    if cp.pos == "top" then return 0 end
    return cp.yOff + h
end

---------------------------------------------------------------- Heights, recentre, glow

local function RefreshHeights(pf, p, ctx, cpExtra)
    local topExtent, below = 0, 0
    local anyTop = false
    local function count(slot, size, y)
        if slot == "top" or slot == "topleft" or slot == "topright" then topExtent = max(topExtent, size + y) end
        if slot == "top" then anyTop = true end
        if slot == "bottom" then below = max(below, size + 2 - y) end
    end
    for _, fam in ipairs(ctx.families) do count(fam.slot, fam.size, fam.sy) end
    if ctx.raid.shown then count(ctx.raid.slot, ctx.raid.size, ctx.raid.y) end
    if ctx.elite.shown then count(ctx.elite.slot, ctx.elite.size, ctx.elite.y) end

    local hasTopText = ctx.topHolds ~= "none"
    local topText = hasTopText and (ctx.topSize + 4 + ctx.nameY + ctx.topY) or 0
    local dGap = (anyTop or hasTopText) and ctx.d or 0
    local fromTop = Snap(15 + 4 + topExtent + dGap + topText + ctx.cpPush)

    -- During a slider drag the bar widens around its stored centre instead of jumping between pixels.
    local x
    if ctx.drag and p.storedX then
        x = p.storedX - (ctx.rawW - p.storedRawW) / 2
    else
        x = Snap((p.L - ctx.barW) / 2)
        p.storedX, p.storedRawW = x, ctx.rawW
    end
    for _, bar in ipairs({ pf._health, pf._healthWrapper }) do
        bar:ClearAllPoints()
        bar:SetSize(ctx.barW, ctx.barH)
        bar:SetPoint("TOPLEFT", pf, "TOPLEFT", x, -fromTop)
    end

    pf:SetSize(p.L, Snap(fromTop + ctx.barH + ctx.castH + cpExtra + 15) + below)
end

local function GlowRGB(c, missingR, missingG, missingB)
    if not c then return missingR, missingG, missingB end
    return c.r or c[1] or 0.4117, c.g or c[2] or 0.6667, c.b or c[3] or 1.0
end

local function RefreshGlow(p)
    local PP = KT.PP
    local glow, soft, hard = p.glow, p.glowSoft, p.glowHard
    local wrapper = p.wrapper
    PP.Point(glow, "TOPLEFT", wrapper, "TOPLEFT", -4, 4)
    PP.Point(glow, "BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", 4, -4)
    local style = SavedT("targetGlowStyle")
    local on = P.flags.targetGlow
    local shown = on and (style == "kullthranui" or style == "vibrant")
    glow:SetShown(shown)
    local c = SavedT("targetGlowColor")
    if shown then
        local r, g, b = GlowRGB(c, 0, 0.6157, 1)
        soft:SetVertexColor(r, g, b, 1)
        hard:SetVertexColor(r, g, b, 1)
        if style == "vibrant" then
            soft:SetAlpha(0.55)
            hard:SetAlpha(0.30)
        else
            soft:SetAlpha(0.75)
            hard:SetAlpha(0.40)
        end
    end
    if on and style == "vibrant" then
        local r, g, b = GlowRGB(c, 0.4117, 0.6667, 1)
        for _, t in ipairs(p.framed._texs) do t:SetVertexColor(r, g, b) end
        for _, t in ipairs(p.simple._texs) do t:SetVertexColor(r, g, b) end
        for _, e in ipairs(p.edges) do e:SetColorTexture(r, g, b, 1) end
    end
end

local function RefreshTheme(pf, p, ctx)
    if not ns.ApplyThemePreview then return end
    ns.ApplyThemePreview(pf, pf._health, p.healthBG, pf._cast, p.castBG, pf._nameFS, pf._levelFS, p.framed, p.simple)
    -- The same elite dragon as in game: the custom one in KUI style, Blizzard's in the others.
    local icon = pf._classIcon
    local custom = ns.UseCustomEliteIcon and ns.UseCustomEliteIcon() and ns.CLASSIFICATION_TEXTURE_PATH
    if custom and not icon._customTexture then
        icon:SetTexture(custom)
        icon:SetTexCoord(0, 1, 0, 1)
        icon._customTexture = true
    elseif not custom and icon._customTexture then
        if icon.SetAtlas then icon:SetAtlas("nameplates-icon-elite-gold") end
        icon:SetSize(ctx.elite.size, ctx.elite.size)
        icon._customTexture = nil
    end
    if ns.ThemeClassificationLeft and ns.ThemeClassificationLeft() then
        -- Forever style: on the left end of the bar, as in game.
        if ctx.elite.shown then ns.PlaceThemeClassification(icon, pf._health, false) end
        return
    end
    if ctx.elite.slot == "topright" and ns.AnchorClassificationAdornment then
        ns.AnchorClassificationAdornment(pf._classIcon, ctx.elite.slot, ctx.elite.x, ctx.elite.y, ctx.cpPush, pf._themeProxy)
    end
end

local function RefreshBarLook(pf)
    local bar = pf._health
    local textures = ns.healthBarTextures
    local c = SavedT("enemyInCombat")
    bar:SetStatusBarColor(c.r, c.g, c.b, 1)
    bar:SetStatusBarTexture(textures[Saved("healthBarTexture") or "none"] or FLAT)
    Unsnap(bar:GetStatusBarTexture())
end

-- One complete restyle of the enemy preview. Creates no frame, texture or font string.
local function RefreshEnemy(self)
    local p = self._parts
    local ctx = NewContext(self)
    RefreshIndicator(self)
    self._health:SetValue(ctx.healthValue)
    RefreshLevel(self, ctx)
    RefreshBorders(p)
    RefreshCastBar(self, p, ctx)
    RefreshTextSlots(self, p, ctx)
    RefreshBarLook(self)
    if not isForever and ns.PositionNameplateLevelText then
        ns.PositionNameplateLevelText(self._levelFS, self._nameFS, self._health,
            ns.FindSlotForElement and ns.FindSlotForElement("enemyName"), SavedT("levelXOffset"), SavedT("levelYOffset"))
    end
    RefreshSpellText(self, ctx)
    RefreshHealthMarkers(self, p, ctx)
    RefreshAuras(self, ctx)
    RefreshMarkerIcons(self, ctx)
    RefreshArrows(self, ctx)
    local cpExtra = RefreshClassPower(self)
    RefreshHeights(self, p, ctx, cpExtra)
    RefreshGlow(p)
    if self._textOverlays then
        for _, overlay in ipairs(self._textOverlays) do
            if overlay._resizeToText then overlay._resizeToText() end
        end
    end
    RefreshTheme(self, p, ctx)
end

local function BuildEnemy(parent, width)
    local pf = CreateFrame("Frame", nil, parent)
    pf:SetPoint("TOP", parent)
    local scale = UIParent:GetEffectiveScale() / parent:GetEffectiveScale()
    pf:SetScale(scale)
    if not rollPct then RandomizeValues() end
    activeEnemy = pf

    local p = { L = width / scale, pixelBorders = {}, insets = {} }
    pf._parts = p
    local level = pf:GetFrameLevel()
    local H = level + 10
    local fontPath = KT.GetNPFontPath("nameplates") or Saved("font")
    local outline = OptOutline()
    local _, class = UnitClass("player")
    local pool = ICON_POOLS[class] or ICON_POOLS.FALLBACK
    local used = {}

    BuildBarAndBorders(pf, p, level)
    p.wrapper = pf._healthWrapper
    BuildMarkersAndArrows(pf, H)
    local castIcon = PickIcon(pool.casts, rollIndex, GENERIC_ICONS[(rollIndex - 1) % #GENERIC_ICONS + 1], used)
    BuildCast(pf, p, level, castIcon)
    BuildClassPower(pf, level)
    BuildTexts(pf, p, fontPath, outline)
    -- The client rejects SetText on a font string that has no font yet.
    ApplyLevelStyle(pf._levelFS)
    pf._levelFS:SetText("30")
    BuildAuras(pf, p, H, pool, used, fontPath)

    pf.Update = RefreshEnemy
    pf:Update()
    return pf:GetHeight() * scale
end

---------------------------------------------------------------- Friendly preview

local WHITE = { r = 1, g = 1, b = 1 }
local GREEN = { r = 0, g = 1, b = 0 }

local function FriendlyColor(k, fallback)
    local c = SavedT(k)
    if type(c) == "table" and c.r and c.g and c.b then return c end
    return fallback
end

local function FriendlyFont(fs, size)
    local path = KT.GetNPFontPath("nameplates") or Saved("font") or KT.FONT_PATH
    local outline = OptOutline()
    fs:SetFont(path, size or 11, outline)
    if KT.EnableTextFontFallback then KT:EnableTextFontFallback(fs, path) end
    if outline == "" and KT.GetNPFontUseShadow() then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
    end
end

local ALIGN_JUSTIFY = { left = "LEFT", right = "RIGHT" }

-- Anchor at the top of the entry, as wide as the bar.
local function TopAnchor(fs, entry, align, width)
    local point = align == "left" and "TOPLEFT" or align == "right" and "TOPRIGHT" or "TOP"
    fs:SetPoint(point, entry, point, 0, 0)
    fs:SetWidth(width)
end

local function GuildAnchor(guild, name, align, y, width)
    if align == "left" then
        guild:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, y)
    elseif align == "right" then
        guild:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", 0, y)
    else
        guild:SetPoint("TOP", name, "BOTTOM", 0, y)
    end
    guild:SetWidth(width)
end

local function NameHeight(fs) return max(fs:GetStringHeight(), 14) end

local function ClearEntry(e)
    e:ClearAllPoints()
    e.name:ClearAllPoints()
    e.guild:ClearAllPoints()
    e.health:ClearAllPoints()
    e.hpText:ClearAllPoints()
end

local function StyleFriendlyTexts(ff, s)
    local player, npc = ff._player, ff._npc
    FriendlyFont(player.name, SavedT("friendlyPlayerNameTextSize"))
    FriendlyFont(player.guild, SavedT("friendlyGuildTextSize"))
    FriendlyFont(player.hpText, SavedT("friendlyHealthTextSize"))
    FriendlyFont(npc.name, SavedT("friendlyNPCNameTextSize"))

    local nameColor = FriendlyColor("friendlyPlayerNameColor", WHITE)
    if Saved("classColorFriendly") ~= false and RAID_CLASS_COLORS and RAID_CLASS_COLORS.MAGE then
        nameColor = RAID_CLASS_COLORS.MAGE
    end
    player.name:SetTextColor(nameColor.r, nameColor.g, nameColor.b, 1)
    local c = FriendlyColor("friendlyGuildColor", WHITE)
    player.guild:SetTextColor(c.r, c.g, c.b, 1)
    c = FriendlyColor("friendlyHealthTextColor", WHITE)
    player.hpText:SetTextColor(c.r, c.g, c.b, 1)
    c = FriendlyColor("friendlyNPCNameColor", GREEN)
    npc.name:SetTextColor(c.r, c.g, c.b, 1)

    player.name:SetText(LText("Friendly Player"))
    player.guild:SetText("<KullThranUI>")
    player.hpText:SetText("82%")
    npc.name:SetText(LText("Friendly NPC"))
    player.guild:SetShown(s.guildShown)
    player.name:SetJustifyH(ALIGN_JUSTIFY[s.playerAlign] or "CENTER")
    player.guild:SetJustifyH(ALIGN_JUSTIFY[s.playerAlign] or "CENTER")
    npc.name:SetJustifyH(ALIGN_JUSTIFY[s.npcAlign] or "CENTER")
end

local function LayoutFriendlyBars(ff, s)
    local player, npc = ff._player, ff._npc
    for _, e in ipairs({ player, npc }) do
        e.health:SetSize(s.barW, s.barH)
        SetEdgeThickness(e.edges, s.px)
    end
    player.health:SetValue(82)
    player.health:SetStatusBarColor(0.41, 0.8, 0.94, 1)
    npc.health:SetValue(100)
    npc.health:SetStatusBarColor(0, 0.82, 0.62, 1)
    npc.hpText:Hide()
end

local FRIENDLY_BAR_OFF_ALPHA = 0.25
local FRIENDLY_ENTRY_OFF_ALPHA = 0.4

local function LayoutFriendlyPlayer(ff, s)
    local e = ff._player
    local name, guild = e.name, e.guild
    local nameH = NameHeight(name)
    local top = nameH
    if s.guildShown then top = top + max(guild:GetStringHeight(), 11) + 2 end
    s.top = top
    e:SetSize(s.barW, top + s.barH + 14)
    e:SetPoint("TOP", ff, "TOP", 0, -6)
    TopAnchor(name, e, s.playerAlign, s.barW)
    if s.guildShown then GuildAnchor(guild, name, s.playerAlign, -2, s.barW) end
    e.health:Show()
    e.health:SetPoint("TOP", s.guildShown and guild or name, "BOTTOM", 0, -8)
    e.hpText:SetPoint("RIGHT", e.health, "RIGHT", -3, 0)
    e.hpText:Show()
end

local function LayoutNpcWithBar(e, anchor, s)
    local npcName = NameHeight(e.name)
    e.health:Show()
    e:SetSize(s.barW, npcName + s.barH + 14)
    e:SetPoint("TOP", anchor, "BOTTOM", 0, -28)
    TopAnchor(e.name, e, s.npcAlign, s.barW)
    e.health:SetPoint("TOP", e.name, "BOTTOM", 0, -8)
    return npcName
end

-- Both bars are always laid out, so a switch changes how they look and never moves the preview.
-- A dim bar means name only; a dim entry means that nameplate is off.
local function LayoutFriendly(ff, s)
    local player, npc = ff._player, ff._npc
    LayoutFriendlyPlayer(ff, s)
    local npcName = LayoutNpcWithBar(npc, player.health, s)
    ff:SetSize(s.L, s.top + npcName + 2 * s.barH + 70)
    player.health:SetAlpha((s.playerNameOnly or s.playerOff) and FRIENDLY_BAR_OFF_ALPHA or 1)
    npc.health:SetAlpha((s.npcNameOnly or s.npcOff) and FRIENDLY_BAR_OFF_ALPHA or 1)
    player:SetAlpha(s.playerOff and FRIENDLY_ENTRY_OFF_ALPHA or 1)
    npc:SetAlpha(s.npcOff and FRIENDLY_ENTRY_OFF_ALPHA or 1)
end

local function RefreshFriendly(self)
    local scale = UIParent:GetEffectiveScale() / self._buildParent:GetEffectiveScale()
    self:SetScale(scale)
    local s = {
        L = (self._parentW or self._buildWidth) / scale,
        px = max(1 / scale, 1),
        barW = SavedT("friendlyHealthBarWidth"),
        barH = SavedT("friendlyHealthBarHeight"),
        guildShown = Saved("friendlyShowGuild") ~= false,
        playerAlign = SavedT("friendlyPlayerNameAlignment"),
        npcAlign = SavedT("friendlyNPCNameAlignment"),
        playerNameOnly = Saved("friendlyPlayerNameOnly") ~= false,
        npcNameOnly = Saved("friendlyNPCNameOnly") ~= false,
        playerOff = Saved("showFriendlyPlayers") == false and Saved("friendlyShowDefaultNames") ~= true,
        npcOff = Saved("showFriendlyNPCs") ~= true,
    }
    ClearEntry(self._player)
    ClearEntry(self._npc)
    StyleFriendlyTexts(self, s)
    LayoutFriendlyBars(self, s)
    LayoutFriendly(self, s)
end

local function BuildFriendlyEntry(ff)
    local e = CreateFrame("Frame", nil, ff)
    local health = CreateFrame("StatusBar", nil, e)
    health:SetStatusBarTexture(FLAT)
    health:SetMinMaxValues(0, 100)
    local bg = health:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(health)
    bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    e.health = health
    e.edges = MakeEdges(health, 1, false)
    e.name = NewFontString(e, true)
    e.guild = NewFontString(e, true)
    e.hpText = NewFontString(health)
    return e
end

local function BuildFriendly(parent, width)
    local ff = CreateFrame("Frame", nil, parent)
    ff:SetPoint("TOP", parent, "TOP", 0, 0)
    ff._parentW = width
    ff._buildParent, ff._buildWidth = parent, width
    ff._player = BuildFriendlyEntry(ff)
    ff._npc = BuildFriendlyEntry(ff)
    ff.Update = RefreshFriendly
    activeFriendly = ff
    ff:Update()
    return ff:GetHeight() * (UIParent:GetEffectiveScale() / parent:GetEffectiveScale())
end

---------------------------------------------------------------- Dragging

local DRAG_GROUP_SLOT = { debuffs = "debuffSlot", buffs = "buffSlot", ccs = "ccSlot" }
local DRAG_TEXT_KEYS = { castName = true, castTarget = true, auraDuration = true, auraStack = true }
local DRAG_ELEMENTS = {
    enemyName = { enemyName = true },
    healthText = { healthPercent = true, healthPercentNoSign = true, healthPctNum = true, healthNumPct = true },
    healthNumber = { healthNumber = true, healthPctNum = true, healthNumPct = true },
}

local function DragKeys(key, group)
    if group then
        local slot = Saved(DRAG_GROUP_SLOT[group])
        if slot == nil or slot == "none" then return nil end
        return slot .. "SlotXOffset", slot .. "SlotYOffset"
    end
    if DRAG_TEXT_KEYS[key] then return key .. "XOffset", key .. "YOffset" end
    -- The saved assignment picks the keys, not ns.GetTextSlot: see F19 in the fixes.
    local wanted = DRAG_ELEMENTS[key]
    if wanted then
        for _, slotKey in ipairs(TEXT_SLOT_KEYS) do
            if wanted[Saved(slotKey)] then return slotKey .. "XOffset", slotKey .. "YOffset" end
        end
    end
end

local function CursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

local function BeginDrag(pf, btn, key, group)
    local xKey, yKey = DragKeys(key, group)
    if not xKey then return nil end
    local bl, br, bt, bb = btn:GetLeft(), btn:GetRight(), btn:GetTop(), btn:GetBottom()
    local pl, pr, pt, pb = pf:GetLeft(), pf:GetRight(), pf:GetTop(), pf:GetBottom()
    if not (bl and br and bt and bb and pl and pr and pt and pb) then return nil end
    local cx, cy = CursorPosition()
    return {
        xKey = xKey, yKey = yKey,
        cursorX = cx, cursorY = cy,
        centerX = (bl + br) / 2, centerY = (bt + bb) / 2,
        halfW = (br - bl) / 2, halfH = (bt - bb) / 2,
        left = pl + 8, right = pr - 8, top = pt - 8, bottom = pb + 8,
        baseX = Saved(xKey) or 0, baseY = Saved(yKey) or 0,
        begun = false,
    }
end

-- New offset on one axis: stepped, kept inside the canvas, or centred when it cannot fit.
local function DragAxis(center, delta, half, lo, hi, base, px)
    local target = px(center + delta)
    local low, high = lo + half, hi - half
    if low > high then
        target = (lo + hi) / 2
    else
        target = max(low, min(high, target))
    end
    target = px(target)
    return max(-500, min(500, base + (target - center)))
end

local function DragStep(pf, d)
    local s = pf:GetEffectiveScale()
    if not s or s <= 0 then s = 1 end
    local function px(v) return floor(v * s + 0.5) / s end
    local cx, cy = CursorPosition()
    local dx, dy = px(cx - d.cursorX), px(cy - d.cursorY)
    if not d.begun then
        if abs(dx) < 3 and abs(dy) < 3 then return end
        d.begun = true
    end
    local x = DragAxis(d.centerX, dx, d.halfW, d.left, d.right, d.baseX, px)
    local y = DragAxis(d.centerY, dy, d.halfH, d.bottom, d.top, d.baseY, px)
    local db = _G.KullThranUINameplatesDB
    if not db then return end
    -- Compared with what is stored: an absent key differs from any number, defaults play no part.
    if db[d.xKey] ~= x or db[d.yKey] ~= y then
        db[d.xKey] = x
        db[d.yKey] = y
        UpdatePreview()
    end
end

---------------------------------------------------------------- Click targets

-- Accent outline shown on hover, on a child frame that fills the base.
local function AddHover(btn, base)
    local r, g, b = AccentRGB()
    local holder = CreateFrame("Frame", nil, base)
    holder:SetAllPoints(base)
    holder:SetFrameLevel(base:GetFrameLevel() + 1)
    local border = KT.PP.CreateBorder(holder, r, g, b, 1, 2, "OVERLAY", 7)
    border:Hide()
    btn:SetScript("OnEnter", function() border:Show() end)
    btn:SetScript("OnLeave", function() border:Hide() end)
end

-- Press and release: a press may start a drag, which owns the only OnUpdate in this file.
local function AddPressHandlers(pf, btn, key, group, navigate)
    btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    local drag
    local function onUpdate() DragStep(pf, drag) end
    btn:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        drag = BeginDrag(pf, btn, key, group)
        if drag then btn:SetScript("OnUpdate", onUpdate) end
    end)
    btn:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        btn:SetScript("OnUpdate", nil)
        local d = drag
        drag = nil
        if d and d.begun then
            DragStep(pf, d)
            if ns.RefreshAllSettings then ns.RefreshAllSettings() end
            UpdatePreview()
        else
            navigate(key)
        end
    end)
    btn:SetScript("OnHide", function()
        btn:SetScript("OnUpdate", nil)
        drag = nil
    end)
end

-- Target on an icon, bar or texture element.
local function ElementTarget(pf, element, key, navigate, level, group, isAura)
    local frame = element:GetObjectType() == "Texture" and element:GetParent() or element
    local btn = CreateFrame("Button", nil, frame)
    btn:SetAllPoints(element)
    btn:SetFrameLevel(level or frame:GetFrameLevel() + 20)
    if isAura then
        local base = CreateFrame("Frame", nil, element)
        base:SetAllPoints(element)
        base:SetFrameLevel(element:GetFrameLevel() + 1)
        AddHover(btn, base)
    else
        AddHover(btn, btn)
    end
    AddPressHandlers(pf, btn, key, group, navigate)
    return btn
end

-- Target on a font string, sized from the measured text.
local function TextTarget(pf, fs, key, navigate, level, overlays)
    local frame = fs:GetParent()
    local btn = CreateFrame("Button", nil, frame)
    btn:SetFrameLevel(level or frame:GetFrameLevel() + 20)
    local function resize()
        local ok, w, h = pcall(function() return fs:GetStringWidth(), fs:GetStringHeight() end)
        if ok then
            btn:SetSize(max(w or 0, 4) + 4, max(h or 0, 4) + 4)
        else
            btn:SetSize(44, 16)
        end
    end
    btn._resizeToText = resize
    resize()
    local justify = fs:GetJustifyH()
    if justify == "RIGHT" then
        btn:SetPoint("RIGHT", fs, "RIGHT", 2, 0)
    elseif justify == "CENTER" then
        btn:SetPoint("CENTER", fs, "CENTER", 0, 0)
    else
        btn:SetPoint("LEFT", fs, "LEFT", -2, 0)
    end
    btn:SetScript("OnShow", resize)
    AddHover(btn, btn)
    AddPressHandlers(pf, btn, key, nil, navigate)
    overlays[#overlays + 1] = btn
    return btn
end

local function CastTarget(pf, part, key, navigate, level)
    local btn = CreateFrame("Button", nil, pf._cast:GetParent())
    btn:SetAllPoints(part)
    btn:SetFrameLevel(level)
    btn:RegisterForClicks("LeftButtonDown")
    local r, g, b = AccentRGB()
    local border = KT.PP.CreateBorder(btn, r, g, b, 1, 2, "OVERLAY", 7)
    border:Hide()
    btn:SetScript("OnEnter", function() border:Show() end)
    btn:SetScript("OnLeave", function() border:Hide() end)
    btn:SetScript("OnMouseDown", function() navigate(key) end)
end

-- Four strokes around a target, appended to the button's highlight list.
local function AddStrokes(btn, target, thickness, pad)
    local r, g, b = AccentRGB()
    local list = btn._hlTextures
    local function stroke()
        local t = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(r, g, b, 1)
        Unsnap(t)
        t:Hide()
        list[#list + 1] = t
        return t
    end
    local top, bottom, left, right = stroke(), stroke(), stroke(), stroke()
    top:SetHeight(thickness)
    top:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
    top:SetPoint("TOPRIGHT", target, "TOPRIGHT", pad, pad)
    bottom:SetHeight(thickness)
    bottom:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -pad, -pad)
    bottom:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
    left:SetWidth(thickness)
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", 0, 0)
    right:SetWidth(thickness)
    right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
end

-- Button spanning first to last, highlighted by strokes, navigating on press.
local function SpanTarget(pf, first, last, key, navigate, level)
    local btn = CreateFrame("Button", nil, pf)
    btn:SetFrameLevel(level)
    btn:SetPoint("TOPLEFT", first, "TOPLEFT", -2, 2)
    btn:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 2, -2)
    btn._hlTextures = {}
    btn:SetScript("OnEnter", function()
        for _, t in ipairs(btn._hlTextures) do t:Show() end
    end)
    btn:SetScript("OnLeave", function()
        for _, t in ipairs(btn._hlTextures) do t:Hide() end
    end)
    btn:RegisterForClicks("LeftButtonDown")
    btn:SetScript("OnMouseDown", function() navigate(key) end)
    return btn
end

local function ClassResourceTarget(pf, navigate, level)
    local first, last
    for _, pip in ipairs(pf._cpPips) do
        if pip:IsShown() then
            first = first or pip
            last = pip
        end
    end
    if not first and pf._cpBar:IsShown() then first, last = pf._cpBar, pf._cpBar end
    if not first then return end
    local btn = SpanTarget(pf, first, last, "classResource", navigate, level)
    AddStrokes(btn, btn, Snap(2), 0)
    local function evaluate()
        local on = Saved("showClassPower") == true
        btn:EnableMouse(on)
        btn:SetAlpha(on and 1 or 0)
    end
    evaluate()
    RegisterWidgetRefresh(evaluate)
end

local function ArrowTarget(pf, navigate, level)
    local left, right = pf._arrows.left, pf._arrows.right
    local btn = SpanTarget(pf, left, right, "targetArrows", navigate, level)
    AddStrokes(btn, left, Snap(2), 2)
    AddStrokes(btn, right, Snap(2), 2)
    btn:SetShown(left:IsShown())
    pf._arrowOverlay = btn
end

local function AttachAuraTargets(pf, navigate, I, T, overlays)
    -- Icon by icon: icon, timer, then stack for debuffs. Overlap can follow creation order.
    for _, icon in ipairs(pf._ccs) do
        ElementTarget(pf, icon, "ccIcon", navigate, I, "ccs", true)
        TextTarget(pf, icon.durationText, "auraDuration", navigate, T, overlays)
    end
    for _, icon in ipairs(pf._buffs) do
        ElementTarget(pf, icon, "buffIcon", navigate, I, "buffs", true)
        TextTarget(pf, icon.durationText, "auraDuration", navigate, T, overlays)
    end
    for _, icon in ipairs(pf._debuffs) do
        ElementTarget(pf, icon, "debuffIcon", navigate, I, "debuffs", true)
        TextTarget(pf, icon.durationText, "auraDuration", navigate, T, overlays)
        TextTarget(pf, icon.stackText, "auraStack", navigate, T, overlays)
    end
end

-- The preview outlives the page, so its targets are made once and navigate must stay valid.
local function AttachClickTargets(navigate)
    local pf = activeEnemy
    if not pf or pf._clickTargetsBuilt then return end
    pf._clickTargetsBuilt = true
    local barLevel = pf._health and pf._health:GetFrameLevel() or 20
    local I = barLevel + 15
    local T = I + 10
    local CL = pf._cast:GetFrameLevel() + 20
    local CT = CL + 5
    local overlays = {}

    AttachAuraTargets(pf, navigate, I, T, overlays)
    CastTarget(pf, pf._castIconFrame, "castIcon", navigate, CL)
    CastTarget(pf, pf._cast, "castBar", navigate, CL)
    TextTarget(pf, pf._castNameFS, "castName", navigate, CT, overlays)
    TextTarget(pf, pf._castTargetFS, "castTarget", navigate, CT, overlays)
    TextTarget(pf, pf._nameFS, "enemyName", navigate, nil, overlays)
    TextTarget(pf, pf._hpText, "healthText", navigate, nil, overlays)
    TextTarget(pf, pf._hpNumber, "healthNumber", navigate, nil, overlays)
    ElementTarget(pf, pf._health, "healthBar", navigate)

    local raid = ElementTarget(pf, pf._raidFrame, "raidMarker", navigate)
    raid:SetShown(P.flags.raidMarker)
    pf._raidOverlay = raid
    local elite = ElementTarget(pf, pf._classIcon, "classIcon", navigate)
    elite:SetShown(P.flags.classification)
    pf._classOverlay = elite

    ClassResourceTarget(pf, navigate, I)
    ArrowTarget(pf, navigate, I)
    pf._textOverlays = overlays
end

---------------------------------------------------------------- Setup

local function MergeSharedTextures()
    if not (KT.AppendSharedMediaTextures and LSM) then return end
    local names, order, textures = ns.healthBarTextureNames, ns.healthBarTextureOrder, ns.healthBarTextures
    if not (names and order and textures) then return end
    for _, name in ipairs(LSM:List("statusbar")) do
        if names[name] == nil then
            names[name] = name
            order[#order + 1] = name
            textures[name] = LSM:Fetch("statusbar", name)
        end
    end
end

local function BuildTextureLists()
    local names = ns.healthBarTextureNames or {}
    local order, values = {}, {}
    for i, entry in ipairs(ns.healthBarTextureOrder or {}) do
        order[i] = entry
        if entry ~= "---" then values[entry] = names[entry] or entry end
    end
    values._menuOpts = {
        itemHeight = 28, kind = "texture", sharedMedia = true,
        background = function(entry) return ns.healthBarTextures[entry] end,
    }
    P.TextureOrder, P.TextureValues = order, values
end

local function HookPanelOpen()
    if KT.MenuPrincipal then
        KT.MenuPrincipal:HookScript("OnShow", UpdatePreview)
    elseif not KT._npOnShowHooked then
        KT._npOnShowHooked = true
        hooksecurefunc(KT, "OpenMenu", function() UpdatePreview() end)
    end
end

local function NoOp() end

-- The client comes only from the integrator's argument.
local function Setup(client)
    if client ~= "retail" and client ~= "forever" then
        error("OptionsPreview.Setup: client must be \"retail\" or \"forever\"", 2)
    end
    isForever = client == "forever"

    if not KT.SetContentHeader then KT.SetContentHeader = NoOp end
    if not KT.SetContentHeaderHeightSilent then KT.SetContentHeaderHeightSilent = NoOp end
    if not KT.KUI_NavArrowGlyph then KT.KUI_NavArrowGlyph = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\right_arrow.png" end
    KT.RESIZE_ICON = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png"
    if not KT.BuildCogPopup then KT.BuildCogPopup = BuildCogPopup end

    defaults = ns.defaults or _G.KullThranUINameplatesDefaults or {}
    plates = ns.plates
    barBase = tonumber(ns.BAR_W) or 168
    setFSFont = ns.SetFSFont
    npOutline = ns.GetNPOutline or npOutline

    MergeSharedTextures()
    BuildTextureLists()
    HookPanelOpen()
end

---------------------------------------------------------------- Exports

P.LText, P.AccentRGB, P.Accent = LText, AccentRGB, Accent
P.BuildSliderCore, P.BuildColorSwatch, P.RegisterWidgetRefresh = BuildSliderCore, BuildColorSwatch, RegisterWidgetRefresh
P.ShowTooltip, P.HideTooltip, P.DimSwatch, P.DisabledTooltip = ShowTooltip, HideTooltip, DimSwatch, DisabledTooltip
P.QuietCogPopup = QuietCogPopup
P.OptOutline, P.ApplyAccentToIcon = OptOutline, ApplyAccentToIcon

P.Setup = Setup
P.DB, P.DBVal, P.DBRaw, P.DBColor = DB, Saved, SavedT, DBColor
P.PreviewFont, P.FadeOnHover, P.ColorAccess, P.DimmableSwatch = PreviewFont, FadeOnHover, ColorAccess, DimmableSwatch
P.FormatThousands, P.CastTargetTint, P.ClassTintSwatches = FormatThousands, CastTargetTint, ClassTintSwatches
P.TopDebuffAlign, P.TopDebuffOffsetX = TopDebuffAlign, TopDebuffOffsetX
P.CastBarColor, P.SetCastBarColor, P.BuildCastBarColorSection = CastBarColor, SetCastBarColor, BuildCastBarColorSection
P.CallOnAllPlates, P.RefreshAllPlates, P.RefreshAllAuras, P.RefreshAllFonts = CallOnAllPlates, RefreshAllPlates, RefreshAllAuras, RefreshAllFonts
P.GlowColorPair = GlowColorPair
P.ParseMarkerValues, P.MarkerState, P.MarkerCfg = ParseMarkerValues, MarkerState, MarkerCfg
P.RebuildMarkerValues, P.MarkerSlot, P.SetMarkerSlot = RebuildMarkerValues, MarkerSlot, SetMarkerSlot
P.RandomizeValues, P.UpdatePreview = RandomizeValues, UpdatePreview
P.BuildEnemy, P.BuildFriendly = BuildEnemy, BuildFriendly
P.GetEnemy = function() return activeEnemy end
P.GetFriendly = function() return activeFriendly end
P.flags = { raidMarker = false, classification = false, targetGlow = false }
P.DEBUFF_COUNT, P.BUFF_COUNT, P.CC_COUNT = 4, 2, 2
P.AttachClickTargets = AttachClickTargets
