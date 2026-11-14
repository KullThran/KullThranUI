-- Class resource display of the player unit frame: the pip row, its placement, and the switch with Blizzard's bar.
-- One file for Retail and Forever. Behaviour is defined by specs/ClassPowerBar.md; requirement IDs refer to it.

local _, ns = ...

local floor, mathMax = math.floor, math.max
local type, pcall = type, pcall

local VENGEANCE_SPELL = 228477
local THROTTLE = 0.1
local INDICATOR_TEXTURE = "Interface\\COMMON\\Indicator-Gray"
local SECRET_BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- Resource by class. Entries without `power` are tracked; their event lists add to the common tracked events.
local CLASS_RESOURCE = {
    ROGUE = { power = "ComboPoints" },
    WARLOCK = { power = "SoulShards" },
    PALADIN = { power = "HolyPower" },
    EVOKER = { power = "Essence" },
    DEATHKNIGHT = { power = "Runes" },
    DRUID = { power = "ComboPoints", spec = 103 },
    MAGE = { power = "ArcaneCharges", spec = 62 },
    MONK = { power = "Chi", spec = 269 },
    DEMONHUNTER = { spec = 581, pips = 6, vengeance = true, throttled = true, events = {}, unitEvents = {} },
    SHAMAN = { spec = 263, pips = 10, getter = "GetMaelstromWeapon", events = {}, unitEvents = { "UNIT_AURA" } },
    HUNTER = { spec = 255, pips = 3, getter = "GetTipOfTheSpear", throttled = true,
        events = { "PLAYER_DEAD", "PLAYER_ALIVE" }, unitEvents = { "UNIT_SPELLCAST_SUCCEEDED" } },
    WARRIOR = { spec = 72, pips = 4, getter = "GetWhirlwindStacks", throttled = true,
        events = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_REGEN_ENABLED" }, unitEvents = { "UNIT_SPELLCAST_SUCCEEDED" } },
}

local MODERN_COLOURS = {
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 }, EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04 }, DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 }, DEMONHUNTER = { r = 0.34, g = 0.06, b = 0.46 },
    MONK = { r = 0.00, g = 1.00, b = 0.60 }, SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 }, HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}
local MODERN_UNKNOWN = { r = 1.00, g = 0.84, b = 0.30 }
local WHITE = { r = 1, g = 1, b = 1 }
local CUSTOM_DEFAULT = { r = 1, g = 0.82, b = 0 }
local BG_DEFAULT = { r = 0.082, g = 0.082, b = 0.082, a = 1 }
local EMPTY_DEFAULT = { r = 0.2, g = 0.2, b = 0.2, a = 1 }
local BORDER_DEFAULT = { r = 0, g = 0, b = 0 }

local DECORATED_THEMES = { classic = true, forever = true, retail = true }

-- Cast bar holders already hooked this session (POS-6).
local hookedHolders = setmetatable({}, { __mode = "k" })

-- Spec ID of the player, or nil when the client cannot tell (RES-1).
local function CurrentSpecID()
    local info = C_SpecializationInfo
    if not info or not info.GetSpecialization or not info.GetSpecializationInfo then return nil end
    local index = info.GetSpecialization()
    if not index then return nil end
    return (info.GetSpecializationInfo(index))
end

-- Resource entry for the player's class and spec, or nil.
local function ResolveResource(class)
    local resource = CLASS_RESOURCE[class]
    if resource and resource.spec and CurrentSpecID() ~= resource.spec then return nil end
    return resource
end

-- Pip count at creation (RES-2, RES-4, table of 2.1).
local function CreationCount(ctx, resource, powerType)
    if powerType then
        local live = UnitPowerMax("player", powerType)
        if live and live > 0 then return live end
        return 5
    end
    if resource.getter == "GetMaelstromWeapon" then
        local getter = ctx.Compat.GetMaelstromWeapon
        if getter then
            local _, live = getter()
            if type(live) == "number" and live > 0 then return live end
        end
    end
    return resource.pips
end

-- Unsnapped pip width, pip height, gap and pad of a style (GEO table).
local function StyleGeometry(style, size, spacing)
    if style == "modern" then
        return floor(size * 1.4 + 0.5), mathMax(3, floor(size * 0.375)), spacing + 2, 0
    elseif style == "circles" then
        return size + 6, size + 6, spacing, 4
    end
    return size + 12, size, spacing + 2, 4
end

-- Pip colour of a row (COL-1 to COL-3).
local function PipColour(settings, style, class)
    local colour
    if settings.classPowerClassColor == false then
        colour = settings.classPowerCustomColor or CUSTOM_DEFAULT
    elseif style == "modern" then
        colour = MODERN_COLOURS[class] or MODERN_UNKNOWN
    else
        colour = RAID_CLASS_COLORS[class] or WHITE
    end
    return colour.r, colour.g, colour.b
end

-- First-need status bar of a pip (SEC-3).
local function MakeSecretBar(pip, r, g, b)
    local bar = CreateFrame("StatusBar", nil, pip)
    bar:SetAllPoints(pip._fill)
    bar:SetStatusBarTexture(SECRET_BAR_TEXTURE)
    bar:SetStatusBarColor(r, g, b, 1)
    bar:SetFrameLevel(pip:GetFrameLevel() + 1)
    pip._secretBar = bar
    return bar
end

-- Spans of a stretched row on the physical pixel grid (POS-10).
local function PipSpans(count, width, gap, scale)
    local gapPx = floor(gap * scale + 0.5) / scale
    local pipW = (width - (count - 1) * gapPx) / count
    local stride = pipW + gapPx
    local spans = {}
    for i = 1, count do
        local left = floor((i - 1) * stride * scale + 0.5) / scale
        local right = floor(((i - 1) * stride + pipW) * scale + 0.5) / scale
        spans[i] = { left, right - left }
    end
    return spans
end

local function Rise(settings)
    if (settings.classPowerStyle or "none") ~= "modern" or (settings.classPowerPosition or "top") ~= "above" then
        return 0
    end
    return mathMax(3, floor((settings.classPowerSize or 8) * 0.375))
end

-- Row teardown (DST-1). Leaves ns.FrameWidgets.ClassResources.bar to the caller.
local function Destroy(ctx)
    local frames = ctx.frames
    local row = frames._customClassPower
    if not row then return end
    row:Hide()
    local children = { row:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        child:UnregisterAllEvents()
        child:SetScript("OnEvent", nil)
        child:Hide()
    end
    row:SetParent(nil)
    frames._customClassPower = nil
end

-- Builds the row and its drivers. Everything decided here stays fixed for the row's life (MEC-10).
local function Create(ctx, style)
    local _, class = UnitClass("player")
    local resource = ResolveResource(class)
    if not resource then return nil end

    local powerType = resource.power and Enum.PowerType[resource.power]
    if powerType and ctx.OwnsClassResource and ctx.OwnsClassResource() then return nil end

    local count = CreationCount(ctx, resource, powerType)
    local settings = ctx.GetProfile().player
    local PP = ctx.PP

    local rawW, rawH, rawGap, rawPad = StyleGeometry(style, settings.classPowerSize or 8, settings.classPowerSpacing or 2)
    local w, h, gap, pad = PP.Scale(rawW), PP.Scale(rawH), PP.Scale(rawGap), PP.Scale(rawPad)

    local r, g, b = PipColour(settings, style, class)
    local emptyColour = settings.classPowerEmptyColor or EMPTY_DEFAULT
    local bgColour = settings.classPowerBgColor or BG_DEFAULT
    local circles = style == "circles"

    local readTheme = ctx.GetRenderedTheme
    local theme = readTheme and readTheme()
    local decorate = not circles and (ctx.client == "forever" or (theme and DECORATED_THEMES[theme]))

    local row = CreateFrame("Frame", nil, UIParent)
    PP.Size(row, count * w + (count - 1) * gap + pad, h + pad)
    row:SetFrameStrata("LOW")
    row:SetFrameLevel(10)

    local bg = row:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints(row)
    bg:SetColorTexture(bgColour.r, bgColour.g, bgColour.b, bgColour.a)

    -- Raises for non-modern styles while MakeBorder does not exist (F5).
    if style ~= "modern" then ctx.MakeBorder(row, 0, 0, 0, 0.8) end

    local lineFrame = CreateFrame("Frame", nil, row)
    lineFrame:SetAllPoints(row)
    lineFrame:SetFrameLevel(row:GetFrameLevel() + 2)
    lineFrame:Hide()
    local line = lineFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    line:SetHeight(1)
    PP.Point(line, "BOTTOMLEFT", lineFrame, "BOTTOMLEFT", 0, 0)
    PP.Point(line, "BOTTOMRIGHT", lineFrame, "BOTTOMRIGHT", 0, 0)

    local pips = {}

    -- Creates pip i with its layers and appends it.
    local function AddPip(i)
        local layout = ctx.PP
        local pip = CreateFrame("Frame", nil, row)
        layout.Size(pip, w, h)
        layout.Point(pip, "LEFT", row, "LEFT", (i - 1) * (w + gap) + pad / 2, 0)

        local empty = pip:CreateTexture(nil, "ARTWORK", nil, 0)
        empty:SetAllPoints(pip)
        local fill = pip:CreateTexture(nil, "ARTWORK", nil, 1)
        fill:SetAllPoints(pip)
        if circles then
            empty:SetTexture(INDICATOR_TEXTURE)
            empty:SetVertexColor(emptyColour.r, emptyColour.g, emptyColour.b, emptyColour.a)
            fill:SetTexture(INDICATOR_TEXTURE)
            fill:SetVertexColor(r, g, b, 1)
        else
            empty:SetColorTexture(emptyColour.r, emptyColour.g, emptyColour.b, emptyColour.a)
            fill:SetColorTexture(r, g, b, 1)
        end
        pip._empty, pip._fill = empty, fill

        if decorate and ctx.DecorateRectPip then ctx.DecorateRectPip(pip) end
        pips[i] = pip
        return pip
    end

    for i = 1, count do AddPip(i) end

    -- MAX-2. Runs when the max differs from what the row shows, whatever the list length.
    local shownMax = count
    local function RebuildForMax(maximum)
        shownMax = maximum
        for i = 1, #pips do pips[i]:Hide() end
        row:SetWidth(maximum * w + (maximum - 1) * gap + pad)
        local layout = ctx.PP
        for i = 1, maximum do
            local pip = pips[i] or AddPip(i)
            pip:ClearAllPoints()
            layout.Point(pip, "TOPLEFT", row, "TOPLEFT", (i - 1) * (w + gap) + pad / 2, 0)
            layout.Size(pip, w, h)
            pip:Show()
        end
    end

    local isDruidForm = class == "DRUID"
    local isRunes = resource.power == "Runes"
    local core = ctx.KT or _G.KullThranUI
    local readCombo = resource.power == "ComboPoints" and core and core.ReadComboPoints
    local isCombo = readCombo and true or false
    local isEssence = resource.power == "Essence"
    local recharge = (isRunes or isEssence) and ctx.Recharge or nil
    local rechargeTexture = circles and INDICATOR_TEXTURE or SECRET_BAR_TEXTURE
    local isVengeance = resource.vengeance
    local getterName = resource.getter

    -- Hot path. `current` may be secret: only the nil default, IsSecret and the pcall'd SetValue may touch it,
    -- until IsSecret has said it is clean (SEC-2).
    local function Update()
        if isDruidForm then
            if type(GetShapeshiftFormID) == "function" and GetShapeshiftFormID() == 1 then
                row:SetAlpha(1)
            else
                row:SetAlpha(0)
            end
        end

        local current, maximum
        if powerType then
            if isCombo then
                current = readCombo(powerType) or 0
            else
                current = UnitPower("player", powerType) or 0
            end
            maximum = UnitPowerMax("player", powerType) or count
            local sorted = isRunes and recharge and recharge.ReadRunes(maximum)
            if sorted then
                current = sorted
            elseif isRunes then
                current = 0
                for i = 1, maximum do
                    local _, _, ready = GetRuneCooldown(i)
                    if ready then current = current + 1 end
                end
            elseif isEssence and recharge and not ctx.IsSecret(current) then
                recharge.ReadEssence(current, maximum)
            end
        elseif isVengeance then
            local spellApi = C_Spell
            local readCount = spellApi and spellApi.GetSpellCastCount
            current = readCount and readCount(VENGEANCE_SPELL) or 0
            maximum = count
        else
            local getter = ctx.Compat[getterName]
            if getter then
                current, maximum = getter()
            else
                current, maximum = 0, count
            end
            if not maximum or maximum <= 0 then maximum = count end
        end

        -- Max is assumed clean (F4); the list never shrinks.
        if maximum ~= shownMax and maximum > 0 then RebuildForMax(maximum) end

        if isVengeance or ctx.IsSecret(current) then
            for i = 1, #pips do
                local pip = pips[i]
                local bar = pip._secretBar or MakeSecretBar(pip, r, g, b)
                bar:SetMinMaxValues(i - 1, i)
                local ok = pcall(bar.SetValue, bar, current)
                bar:SetStatusBarColor(r, g, b, 1)
                bar:SetShown(ok)
                pip._fill:Hide()
            end
        else
            for i = 1, #pips do
                local pip = pips[i]
                local bar = pip._secretBar
                if bar then bar:Hide() end
                if i <= current then
                    pip._fill:Show()
                else
                    pip._fill:Hide()
                end
                if recharge then
                    local start = recharge.starts[i]
                    if start then
                        recharge.Show(pip, start, recharge.lengths[i], rechargeTexture, r, g, b)
                    else
                        recharge.Hide(pip)
                    end
                end
            end
        end
    end

    local driver = CreateFrame("Frame", nil, row)
    if powerType then
        driver:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        driver:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
        if isDruidForm then driver:RegisterEvent("UPDATE_SHAPESHIFT_FORM") end
        if isRunes then driver:RegisterEvent("RUNE_POWER_UPDATE") end
        if isCombo and core.RegisterComboTargetEvents then core.RegisterComboTargetEvents(driver) end

        driver:SetScript("OnEvent", function(_, event, unit)
            if event == "PLAYER_ENTERING_WORLD" or event == "RUNE_POWER_UPDATE"
                or event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_TARGET_CHANGED"
                or event == "COMBO_TARGET_CHANGED" or unit == "player" then
                Update()
            end
        end)
    else
        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
        driver:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
        for i = 1, #resource.events do driver:RegisterEvent(resource.events[i]) end
        for i = 1, #resource.unitEvents do driver:RegisterUnitEvent(resource.unitEvents[i], "player") end

        local function RequestReload()
            local reload = ctx.ReloadFrames
            if reload then reload() end
        end

        driver:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
            if event == "PLAYER_SPECIALIZATION_CHANGED" then
                Destroy(ctx)
                ns.FrameWidgets.ClassResources.bar = nil
                C_Timer.After(0.1, RequestReload)
                return
            end

            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                if unit == "player" then
                    local compat = ctx.Compat
                    local handleTip, handleWhirlwind = compat.HandleTipOfTheSpear, compat.HandleWhirlwindStacks
                    if handleTip then handleTip(event, unit, castGUID, spellID) end
                    if handleWhirlwind then handleWhirlwind(event, unit, castGUID, spellID) end
                end
            elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
                local compat = ctx.Compat
                local handleTip, handleWhirlwind = compat.HandleTipOfTheSpear, compat.HandleWhirlwindStacks
                if handleTip then handleTip(event) end
                if handleWhirlwind then handleWhirlwind(event) end
            elseif event == "PLAYER_REGEN_ENABLED" then
                local handleWhirlwind = ctx.Compat.HandleWhirlwindStacks
                if handleWhirlwind then handleWhirlwind(event) end
            end
            Update()
        end)

        if resource.throttled then
            local sinceUpdate = 0
            driver:SetScript("OnUpdate", function(_, elapsed)
                sinceUpdate = sinceUpdate + elapsed
                if sinceUpdate >= THROTTLE then
                    sinceUpdate = 0
                    Update()
                end
            end)
        end
    end

    Update()

    row._pips = pips
    row._pipSize, row._pipH, row._gap, row._pad = w, h, gap, pad
    row._updatePips = Update
    row._bg = bg
    row._bottomBdrFrame, row._bottomBdr = lineFrame, line

    -- POS-9. Surplus hidden pips take part in the spans (F2).
    row._repositionForWidth = function(targetW)
        local n = #pips
        if n == 0 then return end
        local scale = row:GetEffectiveScale()
        if not scale or scale <= 0 then scale = 1 end
        local width = floor(targetW)
        local spans = PipSpans(n, width, gap, scale)
        for i = 1, n do
            local pip, span = pips[i], spans[i]
            pip:ClearAllPoints()
            pip:SetSize(span[2], h)
            pip:SetPoint("TOPLEFT", row, "TOPLEFT", span[1], 0)
        end
        row:SetWidth(width)
        row:SetHeight(h)
    end

    return row
end

-- Sizes the player frame for a given rise above its bars (RSZ-1, RSZ-2).
local function Resize(ctx, rise)
    local player = ctx.frames.player
    if not player then return end
    local settings = ctx.GetPlayerSettings()
    local Kit = ctx.Kit
    local base = settings.healthHeight + Kit.PowerStack(settings)
    local shown, docked = Kit.PortraitState(settings)
    local side, edge, frameWidth, leftInset, rightInset = Kit.PortraitFit(settings, shown, docked, base + rise, "left")
    ctx.PP.Size(player, frameWidth, base + rise + Kit.BtbExtra(settings))

    local health = player.Health
    if health then
        ns.FrameWidgets.HealthInsets(health).left = leftInset
        ns.FrameWidgets.HealthInsets(health).right = rightInset
    end
    local portrait = player.Portrait
    if portrait and portrait.backdrop and shown then
        Kit.SeatPortrait(player, nil, side, docked, edge, 0, 0, 0, false, true)
    end
end

-- Re-anchors the player health bar from its stored insets (RSZ-3).
local function SeatHealth(ctx, extraTop)
    local player = ctx.frames.player
    local health = player and player.Health
    if not health then return end
    local top = extraTop + ctx.Kit.BtbTopRise(ctx.GetProfile().player)
    health:ClearAllPoints()
    ctx.PP.Point(health, "TOPLEFT", player, "TOPLEFT", ns.FrameWidgets.HealthInsets(health).left or 0, -top)
    ctx.PP.Point(health, "RIGHT", player, "RIGHT", -(ns.FrameWidgets.HealthInsets(health).right or 0), 0)
end

-- Anchor of the bottom layout, pushed below a visible cast bar when y is 0 (POS-4).
local function AnchorBelow(ctx, bar, player, holder, x, y, showCastbar)
    local offsetY = -1 + y
    if y == 0 and holder and holder:IsShown() and showCastbar then
        offsetY = -1 - holder:GetHeight()
    end
    bar:ClearAllPoints()
    ctx.PP.Point(bar, "TOP", player, "BOTTOM", x, offsetY)
end

-- Shows or hides the base line of a row; other bars have none (POS-3).
local function SetBaseLine(bar, on, settings)
    local lineFrame = bar._bottomBdrFrame
    if not lineFrame then return end
    if on then
        local colour = settings.borderColor or BORDER_DEFAULT
        bar._bottomBdr:SetColorTexture(colour.r, colour.g, colour.b, 1)
        lineFrame:Show()
    else
        lineFrame:Hide()
    end
end

-- Places any bar around the player frame. Callers guard combat (MEC-6).
local function Position(ctx, bar)
    local player = ctx.frames.player
    if not bar or not player then return end
    bar:ClearAllPoints()

    local watcher = bar._castbarWatcher
    if watcher then
        watcher:SetScript("OnUpdate", nil)
        watcher:Hide()
    end

    local profile = ctx.GetProfile()
    local settings = profile.player
    local style = settings.classPowerStyle or "none"
    local position = settings.classPowerPosition or "top"
    local x, y = settings.classPowerBarX or 0, settings.classPowerBarY or 0
    local health = player.Health
    local PP = ctx.PP

    if style == "modern" and position == "above" then
        local rise = bar._pipH or 3
        bar:SetParent(player)
        Resize(ctx, rise)
        SeatHealth(ctx, rise)
        PP.Point(bar, "BOTTOMLEFT", health, "TOPLEFT", 0, 0)
        PP.Point(bar, "BOTTOMRIGHT", health, "TOPRIGHT", 0, 0)
        if bar._repositionForWidth then bar._repositionForWidth(settings.frameWidth or 181) end
        SetBaseLine(bar, true, settings)
    elseif style == "modern" and position == "top" then
        bar:SetParent(player)
        Resize(ctx, 0)
        SeatHealth(ctx, 0)
        PP.Point(bar, "BOTTOM", health, "TOP", x, y)
        SetBaseLine(bar, false)
    elseif not settings.lockClassPowerToFrame then
        local positions = profile.positions
        local saved = positions and positions.classPower
        local point = saved and saved.point or "CENTER"
        local savedX = saved and saved.x or 0
        local savedY = saved and saved.y or -220
        SeatHealth(ctx, 0)
        bar:SetParent(UIParent)
        PP.Point(bar, point, UIParent, point, savedX, savedY)
        Resize(ctx, 0)
        SetBaseLine(bar, false)
    else
        local castbar = player.Castbar
        local holder = castbar and castbar:GetParent()
        local showCastbar = settings.showPlayerCastbar
        SeatHealth(ctx, 0)
        bar:SetParent(player)
        SetBaseLine(bar, false)
        AnchorBelow(ctx, bar, player, holder, x, y, showCastbar)
        if showCastbar then
            -- Hooks stay bound to this bar and these offsets for the session (F7).
            if holder and not hookedHolders[holder] then
                hookedHolders[holder] = true
                local function FollowCastbar()
                    local show = ctx.GetProfile().player.showPlayerCastbar
                    if show then AnchorBelow(ctx, bar, player, holder, x, y, show) end
                end
                holder:HookScript("OnShow", FollowCastbar)
                holder:HookScript("OnHide", FollowCastbar)
            end
            if not bar._castbarWatcher then
                bar._castbarWatcher = CreateFrame("Frame", nil, bar)
            end
            if holder then AnchorBelow(ctx, bar, player, holder, x, y, showCastbar) end
        end
        Resize(ctx, 0)
    end

    bar:SetFrameStrata(player:GetFrameStrata())
    bar:SetFrameLevel(player:GetFrameLevel() + 5)
    bar:Show()
end

-- Builds a row and places it; no resource leaves the frames table as it was (MNT-1).
local function Mount(ctx, style)
    local row = Create(ctx, style)
    if not row then return end
    local frames = ctx.frames
    frames._customClassPower = row
    ns.FrameWidgets.ClassResources.bar = row
    Position(ctx, row)
end

-- Run once during frame initialisation (MNT-2).
local function Startup(ctx, style, savedBar)
    local frames = ctx.frames
    local player = frames.player
    if style == "none" or not player then return end

    if style == "blizzard" then
        local native = ctx.Native
        if native and native:IsSupported() then
            ns.FrameWidgets.ClassResources.bar = native:Activate(player, ctx.GetProfile())
        elseif savedBar then
            Position(ctx, savedBar)
            ns.FrameWidgets.ClassResources.bar = savedBar
        end
        return
    end

    Destroy(ctx)
    Mount(ctx, style)
end

-- Switches the saved style and rebuilds what shows (TOG-1 to TOG-5).
local function Toggle(ctx, style)
    local frames = ctx.frames
    local profile = ctx.GetProfile()
    local settings = profile.player
    style = style or settings.classPowerStyle or "none"
    settings.showClassPowerBar = (style ~= "none")
    settings.classPowerStyle = style

    local native = ctx.Native
    if native and native.active then
        native:Deactivate()
        ns.FrameWidgets.ClassResources.bar = nil
    end

    if frames._customClassPower then
        Destroy(ctx)
        ns.FrameWidgets.ClassResources.bar = nil
    elseif ns.FrameWidgets.ClassResources.bar then
        local bar = ns.FrameWidgets.ClassResources.bar
        bar:Hide()
        bar:ClearAllPoints()
        bar:SetParent(PlayerFrame or UIParent)
        if PlayerFrame then PlayerFrame.classPowerBar = bar end
        ns.FrameWidgets.ClassResources.bar = nil
    end

    if style == "none" then
        SeatHealth(ctx, 0)
        Resize(ctx, 0)
    elseif style == "blizzard" then
        if native and native:IsSupported() then
            ns.FrameWidgets.ClassResources.bar = native:Activate(frames.player, profile)
            return
        end
        local blizzardBar = PlayerFrame and PlayerFrame.classPowerBar
        if native and native.YieldsToComboDisplay and native:YieldsToComboDisplay() then
            blizzardBar = nil
        end
        if blizzardBar then
            PlayerFrame.classPowerBar = nil
            blizzardBar:SetParent(UIParent)
            ns.FrameWidgets.ClassResources.bar = blizzardBar
        end
        if ns.FrameWidgets.ClassResources.bar and frames.player then
            Position(ctx, ns.FrameWidgets.ClassResources.bar)
        end
    else
        Mount(ctx, style)
    end
end

ns.ClassPowerBar = {
    Create = Create,
    Destroy = Destroy,
    Position = Position,
    Resize = Resize,
    SeatHealth = SeatHealth,
    Mount = Mount,
    Startup = Startup,
    Toggle = Toggle,
    PipSpans = PipSpans,
    Rise = Rise,
}
