-- Power bar of a unit frame, the cast bar parts the frame build file does not make, and show-on-cast.

local _, ns = ...

local PowerCast = {}
ns.PowerCast = PowerCast

local WHITE8 = "Interface\\Buttons\\WHITE8X8"

-- Value text placement by position name: the justify, anchor point and base x.
local TEXT_ANCHORS = {
    left = { point = "LEFT", x = 2 },
    right = { point = "RIGHT", x = -2 },
    center = { point = "CENTER", x = 0 },
}

-- Cast events that make the watcher reconcile visibility, one registration per unit.
local CAST_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
}

-- The extra event of units that can change what they point at.
local RETARGET_EVENTS = {
    target = "PLAYER_TARGET_CHANGED",
    focus = "PLAYER_FOCUS_CHANGED",
}

---------------------------------------------------------------------------------------------------
-- Safe colour step
---------------------------------------------------------------------------------------------------

-- oUF's colour step with the same rules, skipping values that are secret. Runs on every colour update.
function ns.PowerSafeUpdateColor(self, event, unit)
    if self.unit ~= unit then return end

    local element = self.Power
    if element.__texture then
        element:SetStatusBarTexture(element.__texture)
    end
    local fill = element:GetStatusBarTexture()
    if not fill then return end

    local color, r, g, b
    if element.colorPower then
        local isSecret = issecretvalue
        local palette = self.colors.power

        local displayType = element.displayType
        if displayType and not (isSecret and isSecret(displayType)) then
            color = palette[displayType]
        end

        if not color then
            local ok, powerType, token, altR, altG, altB = pcall(UnitPowerType, unit)
            if ok then
                if token and not (isSecret and isSecret(token)) then
                    color = palette[token]
                end
                if not color then
                    if type(altR) == "number" and not (isSecret and isSecret(altR)) then
                        -- Only red is checked for secrecy.
                        if altR > 1 or altG > 1 or altB > 1 then
                            r, g, b = altR / 255, altG / 255, altB / 255
                        else
                            r, g, b = altR, altG, altB
                        end
                    elseif powerType and not (isSecret and isSecret(powerType)) then
                        color = palette[powerType]
                    end
                end
            end
            if not color and not r then
                color = palette.MANA
            end
        end

        if color then
            fill:SetVertexColor(color:GetRGB())
        elseif r then
            fill:SetVertexColor(r, g, b)
        end
    end

    if element.PostUpdateColor then
        element:PostUpdateColor(unit, color, r, g, b)
    end
end

---------------------------------------------------------------------------------------------------
-- Power bar
---------------------------------------------------------------------------------------------------

-- Alternate power of a player priest: mana on Shadow, otherwise the unit's own power.
local function PriestDisplayPower()
    local getSpecialization = GetSpecialization
    if getSpecialization and getSpecialization() == 3 then
        return 0
    end
    return nil
end

-- Size and anchors of the bar by its position setting.
local function PlacePowerBar(ctx, bar, frame, settings)
    local position = settings.powerPosition or "below"
    local detached = position == "detached_top" or position == "detached_bottom"

    local width = settings.frameWidth
    if detached and settings.powerWidth and settings.powerWidth > 0 then
        width = settings.powerWidth
    end
    ctx.PP.Size(bar, width, settings.powerHeight)

    local health = frame.Health
    if position == "none" then
        bar:Hide()
    elseif position == "above" then
        ctx.PP.Point(bar, "BOTTOMLEFT", health, "TOPLEFT", 0, 0)
        ctx.PP.Point(bar, "BOTTOMRIGHT", health, "TOPRIGHT", 0, 0)
    elseif position == "detached_top" then
        bar:SetPoint("BOTTOM", health, "TOP", settings.powerX or 0, ns.FrameLayout.DetachedGap + (settings.powerY or 0))
    elseif position == "detached_bottom" then
        bar:SetPoint("TOP", health, "BOTTOM", settings.powerX or 0, -ns.FrameLayout.DetachedGap + (settings.powerY or 0))
    else
        ctx.PP.Point(bar, "TOPLEFT", health, "BOTTOMLEFT", 0, 0)
        ctx.PP.Point(bar, "TOPRIGHT", health, "BOTTOMRIGHT", 0, 0)
    end
end

-- Fixed white fill and the flat background texture.
local function DressPowerBar(ctx, bar, settings)
    bar:SetStatusBarTexture(WHITE8)
    local fill = bar:GetStatusBarTexture()
    fill:SetHorizTile(false)
    ctx.UnsnapTexture(fill)

    local background = bar:CreateTexture(nil, "BACKGROUND")
    ctx.PP.Point(background, "TOPLEFT", bar, "TOPLEFT", 0, 0)
    ctx.PP.Point(background, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    local tone = settings.customPowerBgColor
    if tone then
        background:SetColorTexture(tone.r, tone.g, tone.b, 1)
    else
        background:SetColorTexture(17 / 255, 17 / 255, 17 / 255, 1)
    end
    ctx.UnsnapTexture(background)
    bar.bg = background
end

-- Power colour through oUF, or a fixed colour kept by a callback.
local function SetPowerFillMode(ctx, bar, unit, settings)
    if settings.powerPercentPowerColor ~= false then
        bar.colorPower = true
        return
    end

    bar.colorPower = false
    local custom = settings.customPowerFillColor
    if custom then
        bar:SetStatusBarColor(custom.r, custom.g, custom.b)
        bar.PostUpdateColor = function(self)
            local s = ctx.SettingsFor(unit)
            local live = s and s.customPowerFillColor
            if live then
                self:SetStatusBarColor(live.r, live.g, live.b)
            end
        end
    else
        bar:SetStatusBarColor(0, 0, 1)
        bar.PostUpdateColor = function(self)
            self:SetStatusBarColor(0, 0, 1)
        end
    end
end

-- The tag string for the value text settings.
local function ValueTextTag(ctx, s)
    local format = s.powerTextFormat or "perpp"
    local suffix = "%"
    if s.powerShowPercent == false then suffix = "" end

    if format == "curpp" then
        if ctx.UsesModernNumbers() then return "[kui-ppfull]" end
        return "[kui-powcur]"
    elseif format == "both" then
        return "[kui-powcur] | [kui-powpct]" .. suffix
    elseif format == "smart" then
        if not ctx.SmartPowerPercent() then return "[kui-powcur]" end
    end
    return "[kui-powpct]" .. suffix
end

-- Makes the text host and font string, with the font set first, and leaves the apply function on the bar.
local function BuildValueText(ctx, bar, frame, unit, settings)
    local host = CreateFrame("Frame", nil, bar)
    host:SetAllPoints(bar)
    host:SetFrameLevel(frame:GetFrameLevel() + 11)
    bar._ppTextOvr = host

    local text = host:CreateFontString(nil, "OVERLAY")
    ctx.SetFont(text, settings.powerPercentSize or 9)
    text:Hide()
    local function ApplyValueText(s)
        local position = s.powerPercentText or "none"

        ctx.SetFont(text, s.powerPercentSize or 9)
        text:ClearAllPoints()
        if text._curTag then
            frame:Untag(text)
            text._curTag = nil
        end

        if position == "none" then
            text:Hide()
            return
        end

        local anchor = TEXT_ANCHORS[position] or TEXT_ANCHORS.center
        text:SetJustifyH(anchor.point)
        ctx.PP.Point(text, anchor.point, host, anchor.point, anchor.x + (s.powerPercentX or 0), s.powerPercentY or 0)

        local tag = ValueTextTag(ctx, s)
        frame:Tag(text, tag)
        text._curTag = tag
        if frame.UpdateTags then
            frame:UpdateTags()
        end

        local r, g, b, a = 1, 1, 1, 1
        if s.powerPercentTextPowerColor then
            -- The first return is used as a key unchecked, so a secret value raises here.
            local entry = PowerBarColor[UnitPowerType(unit)]
            if entry then
                r, g, b = entry.r, entry.g, entry.b
            end
        elseif s.powerTextColor then
            local custom = s.powerTextColor
            r, g, b, a = custom.r, custom.g, custom.b, custom.a or 1
        end
        text:SetTextColor(r, g, b, a)
        text:Show()
    end

    ns.FrameWidgets.RegisterPowerText(bar, text, ApplyValueText)
    ns.FrameWidgets.RefreshPowerText(bar, settings)
end

-- Builds and returns the power bar. The caller assigns frame.Power.
function PowerCast.PowerBar(ctx, frame, unit, settings)
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetFrameStrata(frame:GetFrameStrata())
    bar:SetFrameLevel(frame:GetFrameLevel() + 3)

    PlacePowerBar(ctx, bar, frame, settings)
    bar.UpdateColor = ns.PowerSafeUpdateColor
    DressPowerBar(ctx, bar, settings)
    SetPowerFillMode(ctx, bar, unit, settings)

    BuildValueText(ctx, bar, frame, unit, settings)
    ctx.PowerAlpha(bar, ctx.SettingsKeyFor(unit))

    -- oUF's further arguments are current, min and max: they may be secret and are not named here.
    bar.PostUpdate = function(self, updatedUnit)
        ctx.UpdatePowerBackground(self, updatedUnit, ctx.SettingsFor(updatedUnit))
    end

    if unit == "player" then
        local _, classFile = UnitClass("player")
        if classFile == "PRIEST" then
            bar.displayAltPower = true
            bar.GetDisplayPower = PriestDisplayPower
        end
    end

    ctx.SmoothBar(bar)
    return bar
end

---------------------------------------------------------------------------------------------------
-- Cast bar
---------------------------------------------------------------------------------------------------

-- Remaining time text. Runs every frame while a cast shows. The duration may be secret: it only goes to the widget.
local function CastTimeText(castbar, durationObject)
    if durationObject == nil then return end
    local delay = castbar.delay
    if delay == nil or delay == 0 then
        castbar.Time:SetFormattedText("%.1f", durationObject:GetRemainingDuration())
    else
        castbar.Time:SetFormattedText("%.1f|cffff0000%s%.2f|r", durationObject:GetRemainingDuration(),
            castbar.channeling and "-" or "+", delay)
    end
end

-- A hidden white overlay that follows the bar's fill.
local function NewTintLayer(castbar, fill, sublevel, r, g, b)
    local layer = castbar:CreateTexture(nil, "ARTWORK", nil, sublevel)
    layer:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    layer:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    layer:SetTexture(WHITE8)
    layer:SetVertexColor(r, g, b)
    layer:SetAlpha(0)
    return layer
end

-- The layout function: places icon box, bar and text from the live settings and the holder's height.
local function NewIconLayout(ctx, unit, holder, castbar, box, fallbackHeight)
    return function()
        local s = ctx.SettingsFor(unit)
        local iconOn = false
        if s then
            if unit == "player" then
                iconOn = s.showPlayerCastIcon ~= false
            else
                iconOn = s.showCastIcon ~= false
            end
        end
        local height = holder:GetHeight() or fallbackHeight
        local text = castbar.Text

        castbar:ClearAllPoints()
        box:ClearAllPoints()
        text:ClearAllPoints()

        if iconOn and unit == "target" then
            local side = math.max(height - 1, 10)
            box:SetSize(side, side)
            ctx.PP.Point(box, "TOPRIGHT", holder, "TOPRIGHT", 0, 0)
            ctx.PP.Point(castbar, "TOPLEFT", holder, "TOPLEFT", 0, 0)
            ctx.PP.Point(castbar, "BOTTOMRIGHT", box, "BOTTOMLEFT", -2, 0)
            text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
            text:SetPoint("RIGHT", castbar, "RIGHT", -18, 1)
            return
        end

        local iconInside = false
        if iconOn then
            if unit ~= "player" then
                iconInside = true
            else
                local themes = ctx.KT.VisualThemes
                iconInside = themes ~= nil and themes.GetRenderedTheme ~= nil and themes:GetRenderedTheme() ~= "kui"
            end
        end

        if iconInside then
            local side = math.max(height - 1, 10)
            box:SetSize(side, side)
            ctx.PP.Point(box, "TOPLEFT", holder, "TOPLEFT", 0, 0)
            ctx.PP.Point(castbar, "TOPLEFT", box, "TOPRIGHT", 2, 0)
            ctx.PP.Point(castbar, "BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
        else
            box:SetSize(height + 1, height + 1)
            ctx.PP.Point(box, "TOPRIGHT", holder, "TOPLEFT", 1, 1)
            ctx.PP.Point(castbar, "TOPLEFT", holder, "TOPLEFT", 0, 0)
            ctx.PP.Point(castbar, "BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
        end
        text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
        text:SetPoint("RIGHT", castbar, "RIGHT", -5, 1)
    end
end

-- Builds and returns the cast bar. The caller assigns frame.Castbar.
function PowerCast.CastBar(ctx, frame, unit)
    local frameBuild = ns.FrameBuild
    local settings = ctx.SettingsFor(unit)
    local fallbackHeight = settings and settings.castbarHeight or 14

    local holder, castbar = frameBuild.CastbarFrame(ctx, frame, unit)
    frameBuild.CastbarTexts(ctx, castbar)

    local shield = castbar:CreateTexture(nil, "OVERLAY")
    shield:SetSize(1, 1)
    shield:SetAlpha(0)
    shield:Hide()
    castbar.Shield = shield

    local fill = castbar:GetStatusBarTexture()
    local castColor = ctx.CastColor()
    castbar.castTintLayer = NewTintLayer(castbar, fill, 1, castColor.r, castColor.g, castColor.b)
    castbar._shieldedTint = NewTintLayer(castbar, fill, 2, 0.5, 0.5, 0.5)

    -- Colours the fill for a starting cast. The uninterruptible flag may be secret: it only goes to the widget.
    local function tint(self)
        local layer = self.castTintLayer
        if not layer then return end
        layer:SetAlpha(1)
        if self._ktClassicLook then
            layer:SetVertexColor(1.0, 0.70, 0.0)
        else
            local owner = self.__owner
            local color = ctx.CastFillColor(owner and owner.unit, self._ktCastSettings)
            layer:SetVertexColor(color.r, color.g, color.b)
        end
        local shielded = self._shieldedTint
        if shielded then
            shielded:SetAlphaFromBoolean(self.notInterruptible, 1, 0)
        end
    end
    castbar.PostCastStart = tint
    castbar.PostChannelStart = tint
    castbar.PostCastInterruptible = tint
    castbar.CustomTimeText = CastTimeText
    castbar.CustomDelayText = CastTimeText

    local box = frameBuild.CastbarIcon(ctx, holder, castbar)

    castbar._updateIconLayout = NewIconLayout(ctx, unit, holder, castbar, box, fallbackHeight)
    castbar._updateIconLayout()
    return castbar
end

---------------------------------------------------------------------------------------------------
-- Show on cast
---------------------------------------------------------------------------------------------------

-- Decides when bar, icon box and holder are visible, and keeps them right through oUF's callbacks and a watcher.
-- The enabled and icon tests are written out in the sync and in the start so those paths call no helper.
function PowerCast.ShowOnCast(ctx, frame, unit)
    local castbar = frame.Castbar
    local holder = castbar:GetParent()
    -- The interruptible callback always stays the plain tint, so a second setup does not wrap the start again.
    local tint = castbar.PostCastInterruptible

    local isPlayer = unit == "player"
    local enabledKey = isPlayer and "showPlayerCastbar" or "showCastbar"
    local iconKey = isPlayer and "showPlayerCastIcon" or "showCastIcon"
    local iconWithoutSettings = not isPlayer

    -- Read once, here.
    local settings = ctx.SettingsFor(unit)
    local hideWhenInactive = true
    if settings then
        hideWhenInactive = settings.castbarHideWhenInactive
        if hideWhenInactive == nil then
            hideWhenInactive = unit ~= "target"
        end
    end

    -- One visibility call per object, in the order bar, box, holder.
    local function sync()
        local s
        if ctx.GetProfile() then s = ctx.SettingsFor(unit) end
        local box = castbar._iconFrame

        if s and s[enabledKey] == false then
            castbar:Hide()
            if box then box:Hide() end
            holder:Hide()
            return
        end

        -- The cast returns may be secret: they are only compared with nil.
        local active = false
        if UnitExists(unit) then
            active = UnitCastingInfo(unit) ~= nil or UnitChannelInfo(unit) ~= nil
        end

        if active then
            castbar:Show()
            if box then
                local wantIcon = iconWithoutSettings
                if s then wantIcon = s[iconKey] ~= false end
                if wantIcon then box:Show() else box:Hide() end
            end
            holder:Show()
        else
            castbar:Hide()
            if box then box:Hide() end
            if hideWhenInactive then holder:Hide() else holder:Show() end
        end
    end
    castbar._syncInactiveVisibility = sync

    -- Cast start: shows the three objects and tints, or dismisses when the bar is turned off.
    local function start(self, castUnit)
        local s
        if ctx.GetProfile() then s = ctx.SettingsFor(unit) end
        local box = self._iconFrame

        if s and s[enabledKey] == false then
            self:Hide()
            if box then box:Hide() end
            if hideWhenInactive then holder:Hide() end
            return
        end

        holder:Show()
        self:Show()
        if box then
            local wantIcon = iconWithoutSettings
            if s then wantIcon = s[iconKey] ~= false end
            if wantIcon then box:Show() else box:Hide() end
        end
        tint(self, castUnit)
    end
    castbar.PostCastStart = start
    castbar.PostChannelStart = start

    -- Cast end of any kind.
    local function dismiss(self)
        self:Hide()
        local box = self._iconFrame
        if box then box:Hide() end
        if hideWhenInactive then holder:Hide() end
    end
    castbar.PostCastStop = dismiss
    castbar.PostChannelStop = dismiss
    castbar.PostCastFail = dismiss
    castbar.PostCastInterrupted = dismiss

    local watcher = castbar._castStateWatcher
    if not watcher then
        watcher = CreateFrame("Frame", nil, frame)
        for _, event in ipairs(CAST_EVENTS) do
            watcher:RegisterUnitEvent(event, unit)
        end
        if RETARGET_EVENTS[unit] then
            watcher:RegisterEvent(RETARGET_EVENTS[unit])
        end
        castbar._castStateWatcher = watcher
    end

    -- Each event schedules one sync a frame later, or runs it at once without the timer API.
    watcher:SetScript("OnEvent", function()
        local timers = C_Timer
        local after = timers and timers.After
        if after then
            after(0, sync)
        else
            sync()
        end
    end)

    sync()
end
