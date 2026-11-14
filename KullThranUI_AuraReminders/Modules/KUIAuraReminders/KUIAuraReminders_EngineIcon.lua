-- Custom aura engine, regions. One frame per aura, drawn as an icon, a text or a timer bar: the own icon, cooldown
-- swipe, bar, value text, name label and glow for readable answers, and a child host holding a one-slot AuraKit
-- container that the client's aura engine fills while the aura is secret. The slot button carries its own name label,
-- static text, glow and, for bars, its own icon, bar and texts. The condition rules (E.Conditions) tint, grey, fade or
-- light the own parts. Shared byte for byte between the Retail and Forever workspaces.

local _, ns = ...
local KT = ns.KT or (LibStub and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local IsSecret, Field = E.IsSecret, E.Field

local Icon = {}
E.Icon = Icon

local STYLE_PREFIX = "kuiar.custom:"
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local CROP = { 0.08, 0.92, 0.08, 0.92 }
local WHITE = { r = 1, g = 1, b = 1 }

local function Font()
    return KT and KT.ResolveFontPath and KT:ResolveFontPath() or "Fonts\\FRIZQT__.TTF"
end

local function BarColor(region)
    return (region.bar and region.bar.color) or E.BAR_COLOR or { r = 0.25, g = 0.55, b = 0.95 }
end

local function BarWidth(region)
    local size = region.size or 40
    local width = (region.bar and region.bar.width) or E.BAR_WIDTH or 180
    return math.max(width, size + 20)
end

local function TimerEnums()
    local enum = Enum
    local interp = enum and enum.StatusBarInterpolation and enum.StatusBarInterpolation.Immediate or 0
    local direction = enum and enum.StatusBarTimerDirection and enum.StatusBarTimerDirection.RemainingTime or 1
    return interp, direction
end

-- Glow ----------------------------------------------------------------------------------------------------------------

local function GlowCall(method, frame, ...)
    local glows = KT and KT.Glows
    local fn = glows and glows[method]
    if type(fn) == "function" then return fn(frame, ...) end
end

-- Starts once and stops once; a size change restarts it.
function Icon.SetGlow(f, on, size)
    if on then
        if f.glowOn and f.glowSize == size then return end
        if f.glowOn then GlowCall("StopButtonGlow", f.glow) end
        GlowCall("StartButtonGlow", f.glow, size, 1, 0.8, 0.2, 1.2)
        f.glowOn, f.glowSize = true, size
    elseif f.glowOn then
        GlowCall("StopButtonGlow", f.glow)
        f.glowOn, f.glowSize = false, nil
    end
end

-- Low time ------------------------------------------------------------------------------------------------------------

-- A step colour curve over the remaining time: `low` below `lowTime` seconds, `normal` from there on. Kept per owner
-- and rebuilt only when its values change, so a style or a frame keeps the same object between passes.
local curves = {}

function Icon.LowTimeCurve(owner, lowTime, low, normal)
    if not lowTime then
        curves[owner] = nil
        return nil
    end
    local key = table.concat({ lowTime, low.r, low.g, low.b, normal.r, normal.g, normal.b }, ",")
    local cached = curves[owner]
    if cached and cached.key == key then return cached.curve end
    local util = C_CurveUtil
    if not (util and util.CreateColorCurve and CreateColor) then return nil end
    local ok, curve = pcall(util.CreateColorCurve)
    if not ok or not curve then return nil end
    local types = Enum and Enum.LuaCurveType
    if curve.SetType and types and types.Step then pcall(curve.SetType, curve, types.Step) end
    curve:AddPoint(0, CreateColor(low.r, low.g, low.b, 1))
    curve:AddPoint(lowTime, CreateColor(normal.r, normal.g, normal.b, 1))
    curves[owner] = { key = key, curve = curve }
    return curve
end

-- Readable numbers: the low colour while 0 < remaining <= lowTime. Applied on change only. Above it the text keeps its
-- base colour: white, or the stack alert's.
local function SetLow(self, low)
    if self.lowOn == low then return end
    self.lowOn = low
    local text = low and self.lowColor or self.baseText or WHITE
    self.valueText:SetTextColor(text.r, text.g, text.b, 1)
    if self.barActive then
        local bar = low and self.lowColor or self.effectColor or self.barColor
        self.bar:SetStatusBarColor(bar.r, bar.g, bar.b, 1)
    end
end

-- Secret remaining time: the client evaluates the curves, the colours go straight to the setters.
local function CurveTint(self)
    local object = self.durationObject
    if not (object and object.EvaluateRemainingDuration) then return end
    local function Paint(curve, region, setter)
        if not curve then return end
        local ok, color = pcall(object.EvaluateRemainingDuration, object, curve)
        if not ok or color == nil or not color.GetRGBA then return end
        local got, r, g, b, a = pcall(color.GetRGBA, color)
        if got then pcall(region[setter], region, r, g, b, a) end
    end
    Paint(self.lowCurve, self.valueText, "SetTextColor")
    if self.barActive then Paint(self.lowBarCurve, self.bar, "SetStatusBarColor") end
    self.lowOn = nil
end

-- Timers --------------------------------------------------------------------------------------------------------------

local function FormatRemaining(remain)
    if E.Text then return E.Text.Remaining(remain) end
    return string.format("%.1f", remain)
end

-- The remaining time (a number, possibly secret) and whether it is secret; nil when there is no timer.
local function Remaining(self)
    local object = self.durationObject
    if object then
        local ok, remain = pcall(object.GetRemainingDuration, object)
        if not ok or remain == nil then return nil, false end
        return remain, IsSecret(remain)
    end
    if self.expirationTime and self.expirationTime > 0 then
        return self.expirationTime - GetTime(), false
    end
    return nil, false
end

-- The condition rules on the own parts: icon and bar colour, grey icon, opacity and glow. Applied on change only.
local function ApplyEffects(self, remain, secret)
    local record = self.shownRecord
    if not record then return end
    local conditions = E.Conditions
    local effects = conditions and conditions.Effects(record.rules, self.shownData,
        (not secret) and remain or nil, self.shownAnswers) or {}
    if self.forceDesaturate then effects.desaturate = true end
    local key = (conditions and conditions.Key(effects) or "") .. (self.alertGlow and "|a" or "")
    if self.effectsKey == key then return end
    self.effectsKey = key
    local region = record.region
    local color = effects.color or WHITE
    self.icon:SetVertexColor(color.r, color.g, color.b, 1)
    if self.icon.SetDesaturated then self.icon:SetDesaturated(effects.desaturate == true) end
    self.effectColor = effects.color
    if self.barActive and not self.lowOn then
        local bar = effects.color or self.barColor
        if bar then self.bar:SetStatusBarColor(bar.r, bar.g, bar.b, 1) end
    end
    self:SetAlpha((effects.alpha or region.alpha or 1.0) * (self.alphaFactor or 1))
    local glow = region.kind ~= "text" and (region.glow == true or self.alertGlow == true or effects.glow == true)
    Icon.SetGlow(self, glow and not self.inactiveShown, region.size or 40)
end
Icon.ApplyEffects = ApplyEffects

local function RenderTokens(self, remain, secret)
    E.Text.Render(self.valueText, self.tokenTemplate, {
        name = self.shownRecord and self.shownRecord.name, data = self.shownData,
        remaining = remain, remainingSecret = secret,
    })
end

-- OnUpdate: duration text, numeric bar fill and the low time colour.
local function Tick(self)
    local remain, secret = Remaining(self)
    if self.mode == "TOKENS" and self.tokenTicks then RenderTokens(self, remain, secret) end
    if self.rulesTick then ApplyEffects(self, remain, secret) end
    if self.mode == "DURATION" then
        if remain == nil then
            if self.durationObject then self.valueText:SetText("") end
        elseif secret then
            -- A secret number can be formatted and shown, not compared.
            self.valueText:SetFormattedText("%.0f", remain)
        elseif remain > 0 then
            self.valueText:SetText(FormatRemaining(remain))
        else
            self.valueText:SetText("")
        end
    end
    if self.barNumeric and remain ~= nil and not secret then
        self.bar:SetValue(remain > 0 and remain or 0)
    end
    local lowTime = self.lowTime
    if lowTime then
        if secret then
            CurveTint(self)
        else
            SetLow(self, remain ~= nil and remain > 0 and remain <= lowTime)
        end
    end
end

-- `count` is the readable stack count (E.Stacks.Count), nil when unknown: a bar filled by stacks then shows full. A
-- bar filled by value takes the source's value and maximum as they are, secret or not.
local function ApplyBar(f, region, count, data)
    local bar = f.bar
    f.barNumeric = false
    if region.kind ~= "bar" then
        f.barActive = false
        bar:Hide()
        return
    end
    f.barActive = true
    bar:Show()
    local color = BarColor(region)
    f.barColor = color
    bar:SetStatusBarColor(color.r, color.g, color.b, 1)
    if region.bar and region.bar.fill == "stacks" then
        if bar.ClearTimerDuration then pcall(bar.ClearTimerDuration, bar) end
        local most = region.bar.max or E.STACK_MAX or 5
        bar:SetMinMaxValues(0, most)
        bar:SetValue(math.min(count or most, most))
        return
    end
    if region.bar and region.bar.fill == "value" then
        if bar.ClearTimerDuration then pcall(bar.ClearTimerDuration, bar) end
        local value, most
        if type(data) == "table" and not IsSecret(data) then value, most = data.value, data.max end
        if value ~= nil and most ~= nil and pcall(bar.SetMinMaxValues, bar, 0, most) and pcall(bar.SetValue, bar, value) then
            return
        end
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        return
    end
    if f.durationObject and bar.SetTimerDuration then
        local interp, direction = TimerEnums()
        if pcall(bar.SetTimerDuration, bar, f.durationObject, interp, direction) then return end
    end
    if bar.ClearTimerDuration then pcall(bar.ClearTimerDuration, bar) end
    if f.expirationTime and type(f.duration) == "number" and f.duration > 0 then
        bar:SetMinMaxValues(0, f.duration)
        f.barNumeric = true
    else
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
    end
end

-- The cooldown swipe over the icon, from the shown timer; cleared without one or when the region has none.
local function ApplySwipe(f, region)
    local cd = f.cooldown
    if not cd then return end
    local wanted = region.swipe == true and region.kind == "icon"
    if wanted and f.durationObject and cd.SetCooldownFromDurationObject then
        if pcall(cd.SetCooldownFromDurationObject, cd, f.durationObject) then
            cd:Show()
            return
        end
    end
    if wanted and f.expirationTime and type(f.duration) == "number" and f.duration > 0 and cd.SetCooldown then
        cd:SetCooldown(f.expirationTime - f.duration, f.duration)
        cd:Show()
        return
    end
    if cd.Clear then cd:Clear() end
    cd:Hide()
end
Icon.ApplySwipe = ApplySwipe

-- The readable display: timers from `data`, the bar, the value text, the low time and the stack alert conditions.
function Icon.ApplyValueText(f, region, data, conditions)
    local text = region.text or {}
    local object = Field(data, "durationObject")
    local expiration = Field(data, "expirationTime")
    f.durationObject, f.expirationTime, f.duration = nil, nil, nil
    if object then
        f.durationObject = object
    elseif type(expiration) == "number" and expiration > 0 then
        f.expirationTime = expiration
        f.duration = Field(data, "duration")
    end

    local lowTime = conditions and conditions.lowTime
    f.lowTime, f.lowOn = lowTime, nil
    if lowTime then
        local low = conditions.lowTimeColor or E.LOW_TIME_COLOR
        f.lowColor = low
        f.lowCurve = Icon.LowTimeCurve(f, lowTime, low, WHITE)
        f.lowBarCurve = region.kind == "bar" and Icon.LowTimeCurve(f.bar, lowTime, low, BarColor(region)) or nil
    end
    -- From stackAlert stacks: the alert colour on the text and the glow (readable counts only).
    local count = E.Stacks and E.Stacks.Count(data)
    local alert = conditions and conditions.stackAlert
    local base = WHITE
    f.alertGlow = false
    if alert and count and count >= alert then
        base = conditions.stackAlertColor or E.STACK_ALERT_COLOR or WHITE
        if region.kind ~= "text" then
            f.alertGlow = true
            Icon.SetGlow(f, true, region.size or 40)
        end
    end
    f.baseText = base
    f.valueText:SetTextColor(base.r, base.g, base.b, 1)

    ApplyBar(f, region, count, data)
    ApplySwipe(f, region)
    f.tokenTicks = false

    if text.mode == "STATIC" then
        f.mode = "STATIC"
        f.valueText:SetText(text.value or "")
    elseif text.mode == "STACKS" then
        f.mode = "STACKS"
        -- The client's own count text (Cooldown Manager bridge) may be secret: it is only shown. Charges and items
        -- show their count.
        local stackText, itemCount
        if type(data) == "table" and not IsSecret(data) then stackText, itemCount = data.applicationsText, data.count end
        if IsSecret(stackText) or type(stackText) == "string" then
            f.valueText:SetText(stackText)
        elseif itemCount ~= nil then
            if IsSecret(itemCount) then
                f.valueText:SetFormattedText("%d", itemCount)
            else
                f.valueText:SetText(tostring(itemCount))
            end
        else
            local stacks = Field(data, "applications")
            f.valueText:SetText((type(stacks) == "number" and stacks > 1) and tostring(stacks) or "")
        end
    elseif text.mode == "TOKENS" and E.Text then
        f.mode = "TOKENS"
        f.tokenTemplate = text.value or ""
        f.tokenTicks = E.Text.Ticks(f.tokenTemplate)
        local remain, secret = Remaining(f)
        RenderTokens(f, remain, secret)
    elseif text.mode == "DURATION" then
        f.mode = "DURATION"
        if not (f.durationObject or f.expirationTime) then f.valueText:SetText("") end
    else
        f.mode = "NONE"
        f.valueText:SetText("")
    end
    Tick(f)
end

-- Frame ---------------------------------------------------------------------------------------------------------------

-- `onMoved(f, target)` is called when a drag in placing mode ends; `target` is the frame that moved: the aura's own,
-- or its group's anchor (`f.groupFrame`, set by E.Group).
function Icon.Create(uid, onMoved, isUnlocked)
    local f = CreateFrame("Frame", "KUICustomAura_" .. uid, UIParent, "BackdropTemplate")
    f.uid = uid
    f:SetSize(40, 40)
    f:SetPoint("CENTER", 0, 0)
    f:Hide()
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(CROP[1], CROP[2], CROP[3], CROP[4])

    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetStatusBarTexture(BAR_TEXTURE)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(1)
    f.bar.background = f.bar:CreateTexture(nil, "BACKGROUND")
    f.bar.background:SetAllPoints()
    f.bar.background:SetTexture(BAR_TEXTURE)
    f.bar.background:SetVertexColor(0, 0, 0, 0.5)
    f.bar:Hide()

    -- The swipe of the shown timer, under the texts and the border.
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    if f.cooldown.SetDrawEdge then f.cooldown:SetDrawEdge(false) end
    if f.cooldown.SetHideCountdownNumbers then f.cooldown:SetHideCountdownNumbers(true) end
    if f.cooldown.EnableMouse then f.cooldown:EnableMouse(false) end
    f.cooldown:Hide()

    f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.border:SetPoint("TOPLEFT", -2, 2)
    f.border:SetPoint("BOTTOMRIGHT", 2, -2)
    KT:AddBackdrop(f.border, 0, 0, 0, 0)
    KT:AddBorder(f.border, 0, 0, 0, 1)

    -- Texts above the bar.
    f.texts = CreateFrame("Frame", nil, f)
    f.texts:SetAllPoints()
    f.texts:SetFrameLevel(f.bar:GetFrameLevel() + 2)

    local font = Font()
    f.valueText = f.texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.valueText:SetPoint("CENTER", 0, 0)
    f.valueText:SetFont(font, 18, "OUTLINE")

    f.nameText = f.texts:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.nameText:SetPoint("BOTTOM", 0, -15)
    f.nameText:SetFont(font, 10, "OUTLINE")

    f.glow = CreateFrame("Frame", nil, f)
    f.glow:SetAllPoints()

    -- Host of the delegated slot: hidden unless the client's engine draws this aura.
    f.delegate = CreateFrame("Frame", nil, f)
    f.delegate:SetAllPoints()
    f.delegate:Hide()

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not isUnlocked() then return end
        -- An aura anchored to another frame is placed by its offsets, not dragged.
        if self.record and self.record.region and self.record.region.anchorFrame then return end
        local target = self.groupFrame or self
        self.dragTarget = target
        target.dragging = true
        target:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        local target = self.dragTarget or self
        self.dragTarget = nil
        target.dragging = nil
        target:StopMovingOrSizing()
        if onMoved then onMoved(self, target) end
    end)
    f:SetScript("OnUpdate", Tick)
    return f
end

-- The frame an aura is anchored to, when that frame exists now; nil for the screen.
function Icon.AnchorOf(region)
    local name = region and region.anchorFrame
    if not name then return nil end
    local frame = _G[name]
    if type(frame) == "table" and type(frame.GetObjectType) == "function" and frame ~= UIParent then return frame end
    return nil
end

-- A grouped aura is placed by its group (E.Group.Layout), not by its own point; a drag pending in KUI's unlock mode
-- (moverPoint, E.Movers) keeps the frame where it was dropped. An aura anchored to a frame that exists follows it.
function Icon.ApplyLayout(f, region)
    local anchor = not region.group and Icon.AnchorOf(region) or nil
    if anchor then
        f:ClearAllPoints()
        f:SetPoint(region.point or "CENTER", anchor, region.relativePoint or region.point or "CENTER", region.x or 0,
            region.y or 0)
    elseif region.point and not region.group and not f.moverPoint then
        f:ClearAllPoints()
        f:SetPoint(region.point, UIParent, region.relativePoint, region.x, region.y)
    end
    local size = region.size or 40
    local kind = region.kind == "bar" and "bar" or "icon"
    if kind == "bar" then f:SetSize(BarWidth(region), size) else f:SetSize(size, size) end

    local text = region.text or {}
    local textKey = tostring(text.point) .. ":" .. tostring(text.size)
    if f.layoutKind == kind and f.layoutSize == size and f.layoutText == textKey then return end
    f.layoutKind, f.layoutSize, f.layoutText = kind, size, textKey
    local font = Font()
    f.icon:ClearAllPoints()
    f.valueText:ClearAllPoints()
    f.nameText:ClearAllPoints()
    f.glow:ClearAllPoints()
    if kind == "bar" then
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        f.icon:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.icon:SetWidth(size)
        f.bar:ClearAllPoints()
        f.bar:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 1, 0)
        f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        local textSize = math.max(8, math.floor(size * 0.5 + 0.5))
        f.valueText:SetPoint("RIGHT", f.bar, "RIGHT", -4, 0)
        f.valueText:SetFont(font, text.size or textSize, "OUTLINE")
        f.nameText:SetPoint("LEFT", f.bar, "LEFT", 4, 0)
        f.nameText:SetFont(font, textSize, "OUTLINE")
        f.glow:SetAllPoints(f.icon)
    else
        f.icon:SetAllPoints(f)
        local point = text.point or "CENTER"
        f.valueText:SetPoint(point, f, point, 0, 0)
        f.valueText:SetFont(font, text.size or 18, "OUTLINE")
        f.nameText:SetPoint("BOTTOM", f, "BOTTOM", 0, -15)
        f.nameText:SetFont(font, 10, "OUTLINE")
        f.glow:SetAllPoints(f)
    end
end

-- The own parts shown (readable answer, placing mode) or hidden (delegated).
function Icon.SetOwnParts(f, region, shown)
    local iconStyle = shown and region.kind ~= "text"
    f.icon:SetShown(iconStyle)
    if f.cooldown and not (shown and region.kind == "icon") then
        if f.cooldown.Clear then f.cooldown:Clear() end
        f.cooldown:Hide()
    end
    f.border:SetShown(iconStyle)
    f.glow:SetShown(iconStyle)
    f.valueText:SetShown(shown)
    if not (shown and region.kind == "bar") then
        f.bar:Hide()
        f.barActive, f.barNumeric = false, false
    end
    if not shown then
        f.nameText:Hide()
        Icon.SetGlow(f, false)
    end
end

-- The icon of a spell, through the module's texture reader when it has one.
function Icon.Texture(spellID)
    local reader = _G._KUIAR_Tex
    return (reader and reader(spellID))
        or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)) or 134400
end

-- A readable answer drawn with the frame's own parts (the play pass and the editor's preview). `answers` are the
-- sources' answers for the rules; `alphaFactor` dims the whole aura (a guess shown dimmed, an inactive aura).
function Icon.ShowReadable(f, record, data, texture, answers, alphaFactor)
    local region = record.region
    f:Show()
    f:SetAlpha((region.alpha or 1.0) * (alphaFactor or 1))
    f.delegate:Hide()
    f.icon:SetTexture(texture)
    Icon.ApplyLayout(f, region)
    Icon.SetOwnParts(f, region, true)
    if region.nameLabel == true then
        f.nameText:SetText(record.name or "")
        f.nameText:Show()
    else
        f.nameText:Hide()
    end
    f.shownRecord, f.shownData, f.shownAnswers = record, data, answers
    f.alphaFactor = alphaFactor or 1
    f.effectsKey = nil
    Icon.SetGlow(f, region.kind ~= "text" and region.glow == true and not f.inactiveShown, region.size or 40)
    Icon.ApplyValueText(f, region, data, record.conditions)
    f.rulesTick = E.Conditions ~= nil and E.Conditions.Ticks(record.rules)
    local remain, secret = Remaining(f)
    ApplyEffects(f, remain, secret)
end

-- An aura whose trigger is off, kept on screen greyed out or faded (region.inactive): the icon with its timer (the
-- cooldown being waited for) and texts, never a glow.
function Icon.ShowInactive(f, record, data, texture, answers)
    local region = record.region
    f.inactiveShown = true
    f.forceDesaturate = region.inactive == "desaturate"
    Icon.ShowReadable(f, record, data, texture, answers, region.inactive == "dim" and 0.4 or 1)
end

-- Leaves the inactive look before the frame is drawn active again.
function Icon.ClearInactive(f)
    f.inactiveShown, f.forceDesaturate = nil, nil
end

function Icon.Hide(f)
    f:Hide()
    f:EnableMouse(false)
    f.delegate:Hide()
    Icon.SetGlow(f, false)
    f.mode = "NONE"
    f.durationObject = nil
    f.expirationTime = nil
    f.lowTime = nil
    f.barNumeric = false
    f.shownRecord, f.shownData, f.shownAnswers = nil, nil, nil
    f.rulesTick, f.tokenTicks, f.effectsKey, f.effectColor, f.alertGlow = false, false, nil, nil, false
    f.inactiveShown, f.forceDesaturate, f.alphaFactor = nil, nil, nil
    if f.cooldown then
        if f.cooldown.Clear then f.cooldown:Clear() end
        f.cooldown:Hide()
    end
end

-- Delegated slot ------------------------------------------------------------------------------------------------------

-- The parts this module adds to each slot button, by button.
local partsOf = setmetatable({}, { __mode = "k" })

function Icon.PartsOf(button)
    return partsOf[button]
end

-- Runs from AuraKit's decoration (creation and every restyle) and after the parts are built. Out of combat or in the
-- creation window only, as AuraKit restyles; a refused call parks the restyle until the restriction lifts.
local function ApplyPartsNow(button, parts, style)
    local h = style.height or 40
    local isBar = parts.kind == "bar"
    local font = Font()
    local textSize = isBar and math.max(8, math.floor(h * 0.5 + 0.5)) or math.max(8, math.floor(h * 0.45 + 0.5))

    parts.name:SetFont(font, isBar and textSize or 10, "OUTLINE")
    parts.name:SetText(style.kuiName or "")
    parts.name:SetShown(style.kuiNameShown == true)
    parts.text:SetFont(font, textSize, "OUTLINE")
    parts.text:SetText(style.kuiStatic or "")
    parts.text:SetShown(style.kuiStaticShown == true)
    parts.glow:SetShown(style.kuiGlow == true)

    local anchor = isBar and parts.icon or button
    local spread = h * 0.35
    parts.glow:ClearAllPoints()
    parts.glow:SetPoint("TOPLEFT", anchor, "TOPLEFT", -spread, spread)
    parts.glow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", spread, -spread)

    if isBar then
        parts.icon:SetWidth(h)
        parts.bar:SetStatusBarColor(style.kuiBarR or 0.25, style.kuiBarG or 0.55, style.kuiBarB or 0.95, 1)
        parts.count:SetFont(font, math.max(8, math.floor(h * 0.4 + 0.5)), "OUTLINE")
        parts.duration:SetFont(font, textSize, "OUTLINE")
        parts.duration:SetShown(style.hideDurationText ~= true)
    end
end

local function ApplyParts(button, _, style)
    local parts = partsOf[button]
    if parts then pcall(ApplyPartsNow, button, parts, style) end
end

-- The bar's own icon, bar and texts, bound to the button so the client drives them.
local function BuildBarParts(button, overlay, parts, style)
    local AK = _G.KTAuraKit
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    icon:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    icon:SetWidth(style.height or 40)
    icon:SetTexCoord(CROP[1], CROP[2], CROP[3], CROP[4])

    local bar = CreateFrame("StatusBar", nil, button)
    bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, 0)
    bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(BAR_TEXTURE)
    background:SetVertexColor(0, 0, 0, 0.5)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)

    local count = overlay:CreateFontString(nil, "OVERLAY")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    local duration = overlay:CreateFontString(nil, "OVERLAY")
    duration:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    local font = Font()
    count:SetFont(font, 10, "OUTLINE")
    duration:SetFont(font, 12, "OUTLINE")

    parts.icon, parts.bar, parts.count, parts.duration = icon, bar, count, duration
    parts.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
    parts.text:SetPoint("CENTER", bar, "CENTER", 0, 0)

    local interp, direction = TimerEnums()
    pcall(button.SetIcon, button, icon)
    pcall(button.SetDurationBar, button, bar, { interpolation = interp, direction = direction })
    pcall(button.SetApplicationCount, button, count, {})
    if AK and AK.SetDurationTextSafe then
        local formatter = AK.GetDurationFormatter and AK.GetDurationFormatter(false)
        local opts = AK.BuildDurationTextOpts and AK.BuildDurationTextOpts(formatter, style.durationColorCurve) or {}
        AK.SetDurationTextSafe(button, duration, opts)
    end
end

local function BuildParts(button, host, kind, style)
    -- Creation window: the only moment button calls are always legal.
    pcall(button.EnableMouse, button, false)
    pcall(button.SetAllPoints, button, host)

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 6)
    if overlay.EnableMouse then overlay:EnableMouse(false) end

    local parts = { kind = kind, overlay = overlay }
    parts.name = overlay:CreateFontString(nil, "OVERLAY")
    parts.text = overlay:CreateFontString(nil, "OVERLAY")
    parts.glow = overlay:CreateTexture(nil, "OVERLAY")
    parts.glow:SetTexture(GLOW_TEXTURE)
    parts.glow:SetBlendMode("ADD")
    parts.glow:SetVertexColor(1, 0.8, 0.2, 1)

    if kind == "bar" then
        BuildBarParts(button, overlay, parts, style)
    else
        parts.name:SetPoint("BOTTOM", button, "BOTTOM", 0, -15)
        parts.text:SetPoint("CENTER", button, "CENTER", 0, 0)
    end
    partsOf[button] = parts
    ApplyParts(button, nil, style)
end

local function DelegateStyle(record, kind, uid)
    local region = record.region
    local size = region.size or 40
    local text = region.text or {}
    local conditions = record.conditions or {}
    local style = {
        width = size, height = size,
        texCoord = CROP,
        hideDurationText = text.mode ~= "DURATION",
        durationFontSize = math.max(8, math.floor(size * 0.36 + 0.5)),
        durationPoint = "CENTER", durationRelPoint = "CENTER", durationY = 0,
        stackFontSize = math.max(8, math.floor(size * 0.28 + 0.5)),
        applyExtra = ApplyParts,
        kuiName = record.name or "",
        kuiNameShown = region.nameLabel == true,
        kuiStatic = text.mode == "STATIC" and (text.value or "") or "",
        kuiStaticShown = text.mode == "STATIC",
        kuiGlow = region.glow == true,
    }
    if kind == "bar" then
        local color = BarColor(region)
        style.width = BarWidth(region)
        style.noRegions = true
        style.kuiBarR, style.kuiBarG, style.kuiBarB = color.r, color.g, color.b
    end
    if text.mode == "DURATION" then
        style.durationColorCurve = Icon.LowTimeCurve(STYLE_PREFIX .. uid, conditions.lowTime,
            conditions.lowTimeColor or E.LOW_TIME_COLOR, WHITE)
    end
    return style
end

-- Plain values are compared and a change queues a restyle; tables (the crop, the colour curve) are only replaced.
-- The colour curve is read when a button is created.
local function SyncStyle(AK, key, fresh)
    local style = AK.styles[key]
    if not style then
        AK.styles[key] = fresh
        return
    end
    local dirty = false
    for k, v in pairs(fresh) do
        if style[k] ~= v then
            style[k] = v
            if type(v) ~= "table" then dirty = true end
        end
    end
    for k in pairs(style) do
        if fresh[k] == nil and k == "durationColorCurve" then style[k] = nil end
    end
    if dirty and AK.RestyleSoon then AK.RestyleSoon(key) end
end

-- Makes sure the slot exists and matches `spec` (Sources.aura.SlotSpec) and the record's look. Containers are built
-- out of combat by AuraKit; a change found in combat waits for the next pass out of combat. Switching between icon and
-- bar builds a new container, since the button's regions are made once. Returns true once the slot is ready.
function Icon.SyncDelegate(f, record, spec, inCombat)
    local AK = _G.KTAuraKit
    if not (AK and AK.RequestContainer and AK.styles) then return false end
    local host = f.delegate
    local kind = record.region.kind == "bar" and "bar" or "icon"

    if host.kind and host.kind ~= kind then
        if inCombat then return host.container ~= nil end
        if host.container and AK.ReleaseContainer then pcall(AK.ReleaseContainer, host.container) end
        host.container, host.requested, host.kind, host.token = nil, nil, nil, nil
    end

    local key = STYLE_PREFIX .. f.uid .. ":" .. kind
    SyncStyle(AK, key, DelegateStyle(record, kind, f.uid))

    local c = host.container
    if not c then
        if not host.requested then
            host.requested, host.kind = true, kind
            local token = {}
            host.token = token
            AK.RequestContainer(host, spec.unit, {
                point = { "CENTER", host, "CENTER" },
                slots = { {
                    key = "aura",
                    filter = spec.filter,
                    candidateFilters = spec.candidateFilters,
                    style = key,
                    extraInit = function(button, _, style)
                        BuildParts(button, host, kind, style or AK.styles[key] or {})
                    end,
                } },
            }, function(container)
                if host.token ~= token then
                    -- Built after the look switched kind: not wanted any more.
                    if AK.ReleaseContainer then pcall(AK.ReleaseContainer, container) end
                    return
                end
                host.container = container
                host.signature, host.unit = spec.signature, spec.unit
            end)
        end
        return host.container ~= nil
    end

    if host.signature ~= spec.signature and not inCombat then
        local filter = AK.Filter and AK.Filter(unpack(spec.filter)) or table.concat(spec.filter, "|")
        if c.SetAuraSlotFilterString then pcall(c.SetAuraSlotFilterString, c, "aura", filter) end
        if c.SetAuraSlotCandidateFilters then pcall(c.SetAuraSlotCandidateFilters, c, "aura", spec.candidateFilters) end
        if host.unit ~= spec.unit and c.SetUnit then pcall(c.SetUnit, c, spec.unit) end
        if c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
        host.signature, host.unit = spec.signature, spec.unit
    end
    return true
end
