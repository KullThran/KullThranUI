-- AuraKit: shared wrapper around the client's custom aura container engine.
-- Builds containers and styles their engine-owned buttons, without ever reading aura data.

local InCombatLockdown, CreateFrame = InCombatLockdown, CreateFrame
local pcall, pairs, ipairs, next, type, select, unpack = pcall, pairs, ipairs, next, type, select, unpack
local floor = math.floor
local find, format, byte, sub = string.find, string.format, string.byte, string.sub

local AK = { styles = {} }

---------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------

local RESTYLE_BUDGET = 200
local RETRY_LIMIT = 3
local BUILD_BUDGET_MS = 8
local LOGIN_BUDGET_MS = 250
local LOGIN_WINDOW_SECONDS = 15
local WATCHDOG_TEXT = "script ran too long"
local RESTYLE_LABEL = "core.aurakit.restyle"
local BUILD_LABEL = "core.aurakit.build"
local DEFAULT_RING = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\square_border.tga"
local MEDIA = "Interface\\AddOns\\KullThranUI\\Media\\"

-- key, candidate token, layer, colour key, default r, g, b
local DISPEL_TYPES = {
    { "magic", "Magic", 5, "dispelColorMagic", 0.349, 0.475, 1.000 },
    { "curse", "Curse", 4, "dispelColorCurse", 0.636, 0.000, 0.640 },
    { "disease", "Disease", 3, "dispelColorDisease", 0.671, 0.384, 0.098 },
    { "poison", "Poison", 2, "dispelColorPoison", 0.000, 0.706, 0.286 },
    { "bleed", "Bleed", 1, "dispelColorBleed", 0.750, 0.150, 0.150 },
}

---------------------------------------------------------------------------------------
-- Registries. Private per-button data lives here, never on the button.
---------------------------------------------------------------------------------------

local WEAK_KEYS = { __mode = "k" }
local stateOf = setmetatable({}, WEAK_KEYS)       -- button -> private state (guards, regions, record)
local buttonsByKey = {}                           -- style key -> weak set of buttons
local containerData = setmetatable({}, WEAK_KEYS) -- container -> { spec, slotFrames }
local parked = {}                                 -- style keys waiting for the next clear edge

---------------------------------------------------------------------------------------
-- Restriction probe
---------------------------------------------------------------------------------------

local restrictedAt -- clock value of the last restricted answer

local function AurasRestricted()
    local now = GetTime()
    if restrictedAt == now then return true end
    local api = C_UnitAuras
    local probe = api and api.GetAuraDataByIndex
    if pcall(probe, "player", 1, "HELPFUL") then return false end
    restrictedAt = now
    return true
end
AK.AurasRestricted = AurasRestricted

---------------------------------------------------------------------------------------
-- Filter strings
---------------------------------------------------------------------------------------

local filterMemo = {}

local function Filter(...)
    local tokens, count = {}, 0
    for i = 1, select("#", ...) do
        local token = select(i, ...)
        if token ~= nil then
            count = count + 1
            tokens[count] = token
        end
    end
    local memoKey = table.concat(tokens, "\1")
    local cached = filterMemo[memoKey]
    if cached then return cached end

    local polarity
    local others, otherCount, sortKeys = {}, 0, {}
    for i = 1, count do
        local token = tokens[i]
        if token == "HELPFUL" or token == "HARMFUL" then
            polarity = token
        else
            otherCount = otherCount + 1
            others[otherCount] = token
            -- "!NAME" sorts as if it were "NAME!".
            sortKeys[token] = byte(token, 1) == 33 and (sub(token, 2) .. "!") or token
        end
    end
    table.sort(others, function(a, b) return sortKeys[a] < sortKeys[b] end)
    if polarity then table.insert(others, 1, polarity) end

    local result = table.concat(others, "|")
    filterMemo[memoKey] = result
    return result
end
AK.Filter = Filter

---------------------------------------------------------------------------------------
-- Font
---------------------------------------------------------------------------------------

function AK.DefaultFont()
    local core = KullThranUI
    local path = core and core.FONT_PATH
    if type(path) == "string" and path ~= "" then return path end
    return STANDARD_TEXT_FONT
end

---------------------------------------------------------------------------------------
-- Duration text
---------------------------------------------------------------------------------------

-- Preferred formatter. Returns nil when the API is missing or refuses the breakpoints. With exactHours, hours and
-- days keep their remainder (1h26m, 1d3h) so long buffs show the real time left instead of a rounded-down hour.
local function BuildRuleFormatter(firstFormat, exactHours)
    local util = C_StringUtil
    local create = util and util.CreateNumericRuleFormatter
    local enums = Enum
    local rounding = enums and enums.NumericRuleFormatRounding
    if not create or not rounding then return nil end

    local formatter = create()
    local up, down = rounding.Up, rounding.Down
    local hours = { threshold = 3600, format = "%dh", components = { { div = 3600 } }, rounding = down, step = 1 }
    local days = { threshold = 86400, format = "%dd", components = { { div = 86400 } }, rounding = down, step = 1 }
    if exactHours then
        hours = { threshold = 3600, format = "%dh%dm", components = {
            { div = 3600, step = 1, rounding = down },
            { div = 60, mod = 60, step = 1, rounding = down },
        } }
        days = { threshold = 86400, format = "%dd%dh", components = {
            { div = 86400, step = 1, rounding = down },
            { div = 3600, mod = 24, step = 1, rounding = down },
        } }
    end
    local ok = pcall(formatter.SetBreakpoints, formatter, {
        { threshold = 0, format = firstFormat, rounding = up, step = 1 },
        { threshold = 60, format = "%dm", components = { { div = 60 } }, rounding = up, step = 1 },
        { threshold = 61, format = "%dm", components = { { div = 60 } }, rounding = down, step = 1 },
        hours,
        days,
    })
    if ok then return formatter end
    return nil
end

-- Fallback formatter. Returns nil when even this API is missing.
local function BuildSecondsFormatter(unitCount)
    local util = C_StringUtil
    local create = util and util.CreateSecondsFormatter
    local enums = Enum
    local curveUtil = C_CurveUtil
    local intervals = enums and enums.SecondsFormatterInterval
    local abbreviations = enums and enums.SecondsFormatterAbbreviation
    if not create or not intervals or not abbreviations or not curveUtil then return nil end

    local formatter = create()
    formatter:SetDefaultAbbreviation(abbreviations.OneLetter)
    formatter:SetMinInterval(intervals.Seconds)
    formatter:SetDesiredUnitCount(unitCount or 1)
    local curve = curveUtil.CreateCurve()
    curve:AddPoint(61, intervals.Minutes)
    curve:AddPoint(3601, intervals.Hours)
    curve:AddPoint(86401, intervals.Days)
    formatter:SetMaxIntervalCurve(curve)
    local whitespace = enums.SecondsFormatterIntervalWhitespace
    if formatter.SetStripIntervalWhitespace and whitespace then
        formatter:SetStripIntervalWhitespace(whitespace.Strip)
    end
    return formatter
end

local bareFormatter, unitFormatter

local function GetDurationFormatter(showSecondsUnit)
    if showSecondsUnit then
        if not unitFormatter then
            unitFormatter = BuildRuleFormatter("%ds", true) or BuildSecondsFormatter(2)
        end
        return unitFormatter
    end
    if not bareFormatter then
        bareFormatter = BuildRuleFormatter("%d") or BuildSecondsFormatter()
    end
    return bareFormatter
end
AK.GetDurationFormatter = GetDurationFormatter

local function DurationTextColor(curve)
    if curve == nil then return nil end
    local enums = Enum
    local properties = enums and enums.DurationTextBindingProperty
    local property = properties and properties.RemainingDuration
    if property == nil then property = 0 end
    return { curve = curve, property = property }
end
AK.DurationTextColor = DurationTextColor

local function BuildDurationTextOpts(formatter, colorCurve, updateInterval)
    local util = C_DurationUtil
    local createBinding = util and util.CreateDurationTextBinding
    local opts
    if updateInterval and createBinding then
        local binding = createBinding()
        if formatter ~= nil then binding:SetFormatter(formatter) end
        binding:SetUpdateInterval(updateInterval)
        opts = { binding = binding }
    else
        opts = { textFormatter = formatter }
    end
    opts.textColor = DurationTextColor(colorCurve)
    return opts
end
AK.BuildDurationTextOpts = BuildDurationTextOpts

-- Tries the options as given, then without colour, then empty. Never throws.
local function SetDurationTextSafe(button, fontString, opts)
    local register = button and button.SetDurationText
    if pcall(register, button, fontString, opts) then return true, true end
    if opts and opts.textColor ~= nil then
        opts.textColor = nil
        if pcall(register, button, fontString, opts) then return true, false end
    end
    if pcall(register, button, fontString, {}) then return true, false end
    return false, false
end
AK.SetDurationTextSafe = SetDurationTextSafe

---------------------------------------------------------------------------------------
-- Decoration: the hot path. Runs per button on every restyle, so everything is inline.
-- Button calls that have a guard record their value only after they succeeded.
---------------------------------------------------------------------------------------

local function Decorate(button, state, style)
    local key = state.key
    local noTooltips = style.noTooltips
    local core = KullThranUI
    local pp = core and core.PP

    -- Size
    local width = style.width or 32
    local height = style.height or width
    if width ~= state.width or height ~= state.height then
        button:SetSize(width, height)
        state.width, state.height = width, height
    end

    -- Icon
    local icon = state.icon
    if icon then
        local coords = style.texCoord
        if coords then
            icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        elseif style.iconCrop then
            local inset = style.iconZoom or 0.07
            icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
    end

    -- Cooldown
    local cooldown = state.cooldown
    if cooldown then
        cooldown:SetReverse(style.cooldownReverse ~= false)
        cooldown:SetDrawEdge(style.cooldownDrawEdge == true)
        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetShown(style.hideSwipe ~= true)
    end

    -- Stack and duration text
    local stack, duration = state.stack, state.duration
    if stack and not style.noDefaultFonts then
        local defaultFont = core and core.FONT_PATH
        if type(defaultFont) ~= "string" or defaultFont == "" then defaultFont = STANDARD_TEXT_FONT end

        stack:SetFont(style.stackFont or defaultFont, style.stackFontSize or 12, style.stackFontFlags or "OUTLINE")
        local point, x, y = style.stackPoint or "BOTTOMRIGHT", style.stackX or 2, style.stackY or -2
        if point ~= state.stackPoint or x ~= state.stackX or y ~= state.stackY then
            stack:ClearAllPoints()
            stack:SetPoint(point, button, point, x, y)
            state.stackPoint, state.stackX, state.stackY = point, x, y
        end
        local color = style.stackColor
        if color then
            stack:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3], color.a or color[4] or 1)
        end

        duration:SetFont(style.durationFont or defaultFont, style.durationFontSize or 11, style.durationFontFlags or "OUTLINE")
        local relPoint
        point, relPoint, x, y = style.durationPoint or "TOP", style.durationRelPoint or "BOTTOM", style.durationX or 0, style.durationY or -2
        if point ~= state.durationPoint or relPoint ~= state.durationRelPoint or x ~= state.durationX or y ~= state.durationY then
            duration:ClearAllPoints()
            duration:SetPoint(point, button, relPoint, x, y)
            state.durationPoint, state.durationRelPoint, state.durationX, state.durationY = point, relPoint, x, y
        end
    end
    if duration then duration:SetShown(not style.hideDurationText) end

    -- Border host
    local host = state.host
    if host then
        local border = style.border
        if not border or not pp then
            host:Hide()
        else
            local size = border.size or 1
            local r, g, b, a = border.r or border[1] or 0, border.g or border[2] or 0, border.b or border[3] or 0, border.a or border[4] or 1
            local texture = border.texture
            if texture and core.ApplyBorderStyle then
                local rectWidth = style.width or 18
                local rectHeight = style.height or rectWidth
                if rectWidth ~= state.hostWidth or rectHeight ~= state.hostHeight then
                    host:ClearAllPoints()
                    host:SetPoint("CENTER", button, "CENTER")
                    host:SetSize(rectWidth, rectHeight)
                    state.hostWidth, state.hostHeight = rectWidth, rectHeight
                end
                local level
                if border.behindUnitFrame then
                    level = (border.unitFrameLevel or 1) - 1
                    if level < 0 then level = 0 end
                elseif border.behind then
                    level = button:GetFrameLevel() - 1
                    if level < 0 then level = 0 end
                else
                    level = cooldown:GetFrameLevel() + 1
                end
                host:SetFrameLevel(level)
                core.ApplySecretSafeBorderStyle(host, state.record, size, r, g, b, a, texture,
                    border.offsetX, border.offsetY, border.shiftX, border.shiftY, "unitframes", size)
            elseif state.borderMade then
                pp.UpdateBorder(host, size, r, g, b, a)
            else
                pp.CreateBorder(host, r, g, b, a, size, "OVERLAY", 7)
                state.borderMade = true
            end
            host:Show()
        end
    end

    -- Dispel ring
    local holder = state.holder
    if holder then
        local ring = state.ring
        local wantsRing = style.dispelBorder
        local tint
        if wantsRing then
            local enums = Enum
            local tintEnum = enums and enums.CustomAuraButtonDispelTypeTextureStyle
            tint = tintEnum and tintEnum.PreserveAsset
            if tint == nil then
                tintEnum = enums and enums.CustomAuraButtonBorderStyle
                tint = tintEnum and tintEnum.Color
            end
            if tint == nil then
                tintEnum = AuraButtonBorderStyle
                tint = tintEnum and tintEnum.Color
            end
            if not ring and tint ~= nil and (button.AddDispelTypeTexture or button.SetAuraBorder) then
                ring = holder:CreateTexture(nil, "OVERLAY")
                if ring.SetSnapToPixelGrid and ring.SetTexelSnappingBias then
                    ring:SetSnapToPixelGrid(false)
                    ring:SetTexelSnappingBias(0)
                end
                ring:SetAllPoints(holder)
                state.ring = ring
            end
        end

        if ring then
            ring:SetTexture(style.dispelTexture or DEFAULT_RING)

            -- Holder and carrier follow the host.
            local hostLevel = host and host:GetFrameLevel() or 0
            if hostLevel ~= state.ringHostLevel then
                holder:SetFrameLevel(hostLevel + 4)
                state.carrier:SetFrameLevel(hostLevel + 5)
                state.ringHostLevel = hostLevel
            end

            -- Thickness comes from cropping the art.
            local ringPx = style.dispelBorderPx or 2
            local ringSize = style.width or 18
            local thickness = ringPx
            local scale = holder:GetEffectiveScale()
            if scale > 0 then
                thickness = thickness * (pp and pp.perfect or 0.75) / scale
            end
            local trim = 0
            if ringSize > 4 * thickness then
                trim = (ringSize - 4 * thickness) / (4 * (ringSize - 2 * thickness))
            end
            local roundedTrim = trim * 10000 + 0.5
            roundedTrim = roundedTrim - roundedTrim % 1
            if ringSize ~= state.ringCropSize or roundedTrim ~= state.ringCropTrim then
                ring:SetTexCoord(trim, 1 - trim, trim, 1 - trim)
                state.ringCropSize, state.ringCropTrim = ringSize, roundedTrim
            end

            -- Engine registration, re-synced only when it differs.
            local wanted = (wantsRing and (style.border or style.dispelBorderIndependent) and ringPx > 0) and true or false
            local fingerprint = style.dispelColorFP or ""
            local registered = state.ringRegistered
            if wanted ~= registered or (wanted and fingerprint ~= state.ringFingerprint) then
                local clear = button.ClearDispelTypeTextures or button.ClearAuraBorder
                if not wanted then
                    if clear and pcall(clear, button) then
                        ring:Hide()
                        state.ringRegistered = false
                    elseif key ~= nil and AurasRestricted() then
                        parked[key] = true
                    end
                else
                    -- Adds stack, so an existing registration must go first.
                    local clean = true
                    if registered then
                        if clear and pcall(clear, button) then
                            state.ringRegistered = false
                        else
                            clean = false
                            if key ~= nil and AurasRestricted() then parked[key] = true end
                        end
                    end
                    if clean then
                        local add = button.AddDispelTypeTexture or button.SetAuraBorder
                        if add and pcall(add, button, ring, {
                            style = tint,
                            showWhenHarmful = true,
                            showWhenHelpful = false,
                            customDispelColorMap = style.dispelColorMap,
                        }) then
                            state.ringRegistered = true
                            state.ringFingerprint = fingerprint
                        else
                            -- Back to "unknown", so a later pass that turns the ring off still clears and hides.
                            state.ringRegistered = nil
                            if key ~= nil and AurasRestricted() then parked[key] = true end
                        end
                    end
                end
            end
        end
    end

    -- Tooltips
    if not noTooltips then
        if state.motionOff then
            local enable = button.SetMouseMotionEnabled
            if enable then
                if pcall(enable, button, true) then
                    state.motionOff = nil
                elseif key ~= nil and AurasRestricted() then
                    parked[key] = true
                end
            end
        end

        local hideInCombat = style.tooltipCombatHide and true or false
        local setHide = button.SetHideTooltipInCombat
        if setHide and hideInCombat ~= state.tooltipHide then
            if pcall(setHide, button, hideInCombat) then
                state.tooltipHide = hideInCombat
            elseif key ~= nil and AurasRestricted() then
                parked[key] = true
            end
        end

        local anchor = style.tooltipAnchor == "cursor" and "ANCHOR_CURSOR" or "ANCHOR_BOTTOMLEFT"
        local setAnchor = button.SetTooltipAnchorPoint
        if setAnchor and anchor ~= state.tooltipAnchor then
            if pcall(setAnchor, button, anchor) then
                state.tooltipAnchor = anchor
            elseif key ~= nil and AurasRestricted() then
                parked[key] = true
            end
        end
    end

    -- Mouse state, after the tooltip calls that turn the mouse back on
    if not style.cancelButtons then
        local setClick = button.SetMouseClickEnabled
        if setClick and not pcall(setClick, button, false) and key ~= nil and AurasRestricted() then
            parked[key] = true
        end
    end
    if noTooltips then
        local setMotion = button.SetMouseMotionEnabled
        if setMotion then
            if pcall(setMotion, button, false) then
                state.motionOff = true
            elseif key ~= nil and AurasRestricted() then
                parked[key] = true
            end
        end
    end

    local applyExtra = style.applyExtra
    if applyExtra then applyExtra(button, state.record, style) end
end

---------------------------------------------------------------------------------------
-- Button creation
---------------------------------------------------------------------------------------

local function CreateOverlayFrame(button, level)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints(button)
    frame:SetFrameLevel(level)
    frame:EnableMouse(false)
    return frame
end

-- Creates every region of a standard button. Only legal inside the initializer.
local function CreateRegions(button, state)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)

    local hostLevel = cooldown:GetFrameLevel() + 1
    local host = CreateOverlayFrame(button, hostLevel)
    local holder = CreateOverlayFrame(button, hostLevel + 4)
    local carrier = CreateOverlayFrame(button, hostLevel + 5)

    state.icon, state.cooldown = icon, cooldown
    state.host, state.holder, state.carrier = host, holder, carrier
    state.ringHostLevel = hostLevel
    state.stack = carrier:CreateFontString(nil, "OVERLAY")
    state.duration = carrier:CreateFontString(nil, "OVERLAY")
    state.record.icon, state.record.cooldown = icon, cooldown
end

local function MakeInitializer(styleKey, extra)
    return function(button)
        local style = AK.styles[styleKey] or {}
        local record = {}
        local state = { key = styleKey, record = record, building = true }
        stateOf[button] = state

        local standard = not style.noRegions
        if standard then
            CreateRegions(button, state)
            if not style.cancelButtons then
                local setClick = button.SetMouseClickEnabled
                if setClick then pcall(setClick, button, false) end
            end
        end

        Decorate(button, state, style)

        if standard then
            button:SetIcon(state.icon)
            button:SetDurationCooldown(state.cooldown)
            button:SetApplicationCount(state.stack, {})
            SetDurationTextSafe(button, state.duration, BuildDurationTextOpts(
                GetDurationFormatter(style.durationShowSeconds), style.durationColorCurve, style.durationUpdateInterval))
            if style.cancelButtons then button:SetCancelAuraButtons(style.cancelButtons) end
        end

        if styleKey ~= nil then
            local registered = buttonsByKey[styleKey]
            if not registered then
                registered = setmetatable({}, WEAK_KEYS)
                buttonsByKey[styleKey] = registered
            end
            registered[button] = true
        end

        if extra then extra(button, record, style) end
        state.building = nil
    end
end
AK.MakeInitializer = MakeInitializer

---------------------------------------------------------------------------------------
-- Restyle: synchronous entry and the budgeted worker
---------------------------------------------------------------------------------------

function AK.Restyle(styleKey)
    local style = AK.styles[styleKey]
    local registered = styleKey ~= nil and buttonsByKey[styleKey]
    if not style or not registered then return end
    for button in pairs(registered) do
        Decorate(button, stateOf[button], style)
    end
end

local restyleFrame = CreateFrame("Frame")
restyleFrame:Hide()

local keyQueue, keyHead, keyTail = {}, 1, 0 -- FIFO of keys waiting for a pass
local keyQueued = {}                        -- key -> true while it waits

local passKey, passButtons, passCount, passPosition, passCuts -- pass in flight

local function RestyleSoon(styleKey)
    if styleKey == nil then return end
    if not keyQueued[styleKey] then
        keyQueued[styleKey] = true
        keyTail = keyTail + 1
        keyQueue[keyTail] = styleKey
    end
    restyleFrame:Show()
end
AK.RestyleSoon = RestyleSoon

function AK.DeferRestyle(styleKey)
    if styleKey ~= nil then parked[styleKey] = true end
end

restyleFrame:SetScript("OnUpdate", function(self)
    local kt = KT
    local profiler = kt and kt.CombatProfiler
    local stamp = profiler and profiler:Begin(RESTYLE_LABEL)

    local budget = RESTYLE_BUDGET
    local endSlice = false
    local sliceOpen = false
    local sliceStyle, sliceRestricted

    while budget > 0 and not endSlice do
        if not passButtons then
            local styleKey = keyQueue[keyHead]
            if styleKey == nil then
                keyHead, keyTail = 1, 0
                self:Hide()
                break
            end
            keyQueue[keyHead] = nil
            keyHead = keyHead + 1
            keyQueued[styleKey] = nil

            -- Snapshot the buttons; a key with no style or no buttons costs nothing.
            local registered = buttonsByKey[styleKey]
            if AK.styles[styleKey] and registered and next(registered) ~= nil then
                local snapshot, count = {}, 0
                for button in pairs(registered) do
                    count = count + 1
                    snapshot[count] = button
                end
                passKey, passButtons, passCount, passPosition, passCuts = styleKey, snapshot, count, 1, 0
                sliceOpen = false
            end
        end

        if passButtons then
            if not sliceOpen then
                sliceOpen = true
                sliceStyle = AK.styles[passKey]
                sliceRestricted = sliceStyle and AurasRestricted()
            end

            while budget > 0 and passPosition <= passCount do
                local button = passButtons[passPosition]
                passPosition = passPosition + 1
                budget = budget - 1

                local state = sliceStyle and stateOf[button]
                if state then
                    local ok, err = pcall(Decorate, button, state, sliceStyle)
                    if not ok then
                        if passCuts < RETRY_LIMIT and type(err) == "string" and find(err, WATCHDOG_TEXT, 1, true) then
                            -- The client watchdog cut us: same button again next frame.
                            passCuts = passCuts + 1
                            passPosition = passPosition - 1
                            endSlice = true
                            break
                        elseif sliceRestricted then
                            parked[passKey] = true
                        else
                            geterrorhandler()(err)
                        end
                    end
                end
            end

            if passPosition > passCount then
                passKey, passButtons, passCount, passPosition = nil, nil, nil, nil
            end
        end
    end

    if profiler and stamp ~= nil then profiler:End(RESTYLE_LABEL, stamp) end
end)

---------------------------------------------------------------------------------------
-- Restriction lift
---------------------------------------------------------------------------------------

local liftCallbacks = {}

function AK.OnRestrictionLift(fn)
    liftCallbacks[#liftCallbacks + 1] = fn
end

local liftFrame = CreateFrame("Frame")
liftFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
liftFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
liftFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
liftFrame:RegisterEvent("ENCOUNTER_END")
liftFrame:RegisterEvent("CVAR_UPDATE")
liftFrame:SetScript("OnEvent", function(_, event, cvarName)
    if event == "CVAR_UPDATE" and cvarName ~= nil and not find(cvarName, "RestrictionsForced", 1, true) then
        return
    end
    if next(parked) == nil and #liftCallbacks == 0 then return end
    if AurasRestricted() then return end

    for styleKey in pairs(parked) do
        parked[styleKey] = nil
        RestyleSoon(styleKey)
    end
    for i = 1, #liftCallbacks do
        liftCallbacks[i]()
    end
end)

---------------------------------------------------------------------------------------
-- Container layout
---------------------------------------------------------------------------------------

function AK.SetContainerAnchor(c, anchorPoint)
    local set = c.SetFlowLayoutAnchorPoint or c.SetAuraLayoutAnchorPoint
    if set then set(c, anchorPoint) end
end

function AK.SetContainerGrowth(c, h, v)
    local set = c.SetFlowLayoutGrowthDirection or c.SetAuraLayoutGrowthDirection
    if set then set(c, h, v) end
end

function AK.SetContainerPadding(c, l, r, t, b)
    local set = c.SetFlowLayoutPadding or c.SetAuraLayoutPadding
    if set then set(c, l, r, t, b) end
end

function AK.SetContainerRowWidth(c, width)
    local set = c.SetFlowLayoutMaximumLineSize or c.SetAuraLayoutRowWidth
    if set then set(c, width) end
end

function AK.SetContainerAxis(c, vertical)
    local util = AnchorUtil
    local axis = util and util.FlowLayoutAxis
    if not axis or not c.SetFlowLayoutAxis then return end
    c:SetFlowLayoutAxis(vertical and axis.Vertical or axis.Horizontal)
end

local function ApplyContainerLayout(c, layout)
    if not layout then return end
    if layout.anchorPoint ~= nil then AK.SetContainerAnchor(c, layout.anchorPoint) end
    if layout.growthH ~= nil and layout.growthV ~= nil then
        AK.SetContainerGrowth(c, layout.growthH, layout.growthV)
    end
    local padding = layout.padding
    if padding then
        AK.SetContainerPadding(c, padding[1] or 0, padding[2] or 0, padding[3] or 0, padding[4] or 0)
    end
    AK.SetContainerRowWidth(c, layout.rowWidth) -- nil removes the limit
end
AK.ApplyContainerLayout = ApplyContainerLayout

---------------------------------------------------------------------------------------
-- Containers
---------------------------------------------------------------------------------------

local function CreateContainerShell(parent, spec)
    spec = spec or {}
    local c = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if spec.point then c:SetPoint(unpack(spec.point)) end
    c:SetSize(1, 1)
    if spec.processAura then
        c:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, spec.processAura)
    end
    ApplyContainerLayout(c, spec.layout)
    containerData[c] = { spec = spec, slotFrames = {} }
    return c
end
AK.CreateContainerShell = CreateContainerShell

local function AddGroupToContainer(c, group)
    c:AddAuraGroup(group.key, Filter(unpack(group.filter or {})), {
        candidateFilters = group.candidateFilters,
        sortMethod = group.sortMethod,
        sortDirection = group.sortDirection,
        maxFrameCount = group.maxFrameCount,
        layout = group.layout,
        initializeFrame = MakeInitializer(group.style, group.extraInit),
    })
end
AK.AddGroupToContainer = AddGroupToContainer

local function AddSlotToContainer(c, slot)
    local button = c:AddAuraSlot(slot.key, Filter(unpack(slot.filter or {})), {
        candidateFilters = slot.candidateFilters,
        sortMethod = slot.sortMethod,
        sortDirection = slot.sortDirection,
        initializeFrame = MakeInitializer(slot.style, slot.extraInit),
    })
    local data = containerData[c]
    if data and slot.key ~= nil then data.slotFrames[slot.key] = button end
    return button
end
AK.AddSlotToContainer = AddSlotToContainer

-- The unit comes last: binding it is when the engine decides on its event registration.
local function FinishContainer(c, unit)
    c:SetUnit(unit)
    c:UpdateAllAuras()
end
AK.FinishContainer = FinishContainer

local function CreateContainer(parent, unit, spec)
    local c = CreateContainerShell(parent, spec)
    for _, group in ipairs(spec and spec.groups or {}) do AddGroupToContainer(c, group) end
    for _, slot in ipairs(spec and spec.slots or {}) do AddSlotToContainer(c, slot) end
    FinishContainer(c, unit)
    return c, containerData[c].slotFrames
end
AK.CreateContainer = CreateContainer

local parkedRequests = {}
local requestFrame -- created on the first parked request

-- Each batch is detached first, so an error loses the rest of that batch only.
local function BuildParkedRequests()
    local batch = parkedRequests
    parkedRequests = {}
    for i = 1, #batch do
        local request = batch[i]
        local c, slotFrames = CreateContainer(request.parent, request.unit, request.spec)
        if request.callback then request.callback(c, slotFrames) end
    end
end

function AK.RequestContainer(parent, unit, spec, callback)
    if InCombatLockdown() then
        parkedRequests[#parkedRequests + 1] = { parent = parent, unit = unit, spec = spec, callback = callback }
        if not requestFrame then
            requestFrame = CreateFrame("Frame")
            requestFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            requestFrame:SetScript("OnEvent", BuildParkedRequests)
        end
        return
    end
    local c, slotFrames = CreateContainer(parent, unit, spec)
    if callback then callback(c, slotFrames) end
end

function AK.GetContainerData(c)
    if c == nil then return nil end
    return containerData[c]
end

function AK.ReleaseContainer(c)
    if c == nil then return end
    local data = containerData[c]
    if data then
        for _, button in pairs(data.slotFrames) do
            local state = stateOf[button]
            if state then
                local registered = state.key ~= nil and buttonsByKey[state.key]
                if registered then registered[button] = nil end
                stateOf[button] = nil
            end
        end
        containerData[c] = nil
    end
    c:Hide()
end

---------------------------------------------------------------------------------------
-- Dispel slots
---------------------------------------------------------------------------------------

function AK.BuildDispelSlotSpecs(prefix)
    local specs = {}
    for i, def in ipairs(DISPEL_TYPES) do
        specs[i] = {
            key = def[1],
            filter = { "HARMFUL" },
            candidateFilters = { includeDispelTypes = { [def[2]] = true } },
            style = prefix .. ":" .. def[1],
        }
    end
    return specs
end

local function CreateEdge(button, layer, file)
    local edge = button:CreateTexture(nil, "OVERLAY", nil, layer)
    edge:SetTexture(MEDIA .. file)
    edge:SetBlendMode("BLEND")
    return edge
end

-- applyExtra of the dispel slot styles. A health size that is secret, fails or is not a
-- number is a refusal: the key parks if restricted and the edges keep their last size.
-- Only the first draw, having no size to keep, goes on with 1 for that dimension.
local function DrawDispelEdges(button, _, style)
    local health = style.healthFrame
    if not health then return end
    local state = stateOf[button]
    if not state then return end

    local edges = state.edges
    if not edges then
        if not state.building then return end -- children of a button only in its creation window
        local layer = style.layer
        edges = {
            top = CreateEdge(button, layer, "DF_Gradient_V"),
            bottom = CreateEdge(button, layer, "DF_Gradient_V_Rev"),
            left = CreateEdge(button, layer, "DF_Gradient_H"),
            right = CreateEdge(button, layer, "DF_Gradient_H_Rev"),
        }
        state.edges = edges
    end
    local top, bottom, left, right = edges.top, edges.bottom, edges.left, edges.right

    local refused = false
    local isSecret = issecretvalue
    local widthOk, healthWidth = pcall(health.GetWidth, health)
    if not widthOk or (isSecret and isSecret(healthWidth)) or type(healthWidth) ~= "number" then
        healthWidth = 1
        refused = true
    end
    local heightOk, healthHeight = pcall(health.GetHeight, health)
    if not heightOk or (isSecret and isSecret(healthHeight)) or type(healthHeight) ~= "number" then
        healthHeight = 1
        refused = true
    end
    if refused then
        local key = state.key
        if key ~= nil and AurasRestricted() then parked[key] = true end
    end

    if edges.pinnedTo ~= health then
        top:ClearAllPoints()
        top:SetPoint("TOPLEFT", health, "TOPLEFT")
        top:SetPoint("TOPRIGHT", health, "TOPRIGHT")
        bottom:ClearAllPoints()
        bottom:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT")
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", health, "TOPLEFT")
        left:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT")
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", health, "TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT")
        edges.pinnedTo = health
    end

    if not refused or not edges.sized then
        local size = style.gradientSize or 0.35
        if size < 0.12 then size = 0.12 elseif size > 0.60 then size = 0.60 end
        local thickness = style.thickness or 2
        if thickness < 1 then thickness = 1 elseif thickness > 6 then thickness = 6 end
        local minimum = thickness + 3

        local edgeHeight = floor(healthHeight * size)
        if edgeHeight < minimum then edgeHeight = minimum end
        local edgeWidth = floor(healthWidth * size)
        if edgeWidth < minimum then edgeWidth = minimum end
        top:SetHeight(edgeHeight)
        bottom:SetHeight(edgeHeight)
        left:SetWidth(edgeWidth)
        right:SetWidth(edgeWidth)
        edges.sized = true
    end

    -- The plain alpha only counts when gradientAlpha is nil.
    local r, g, b, a = style.r, style.g, style.b, style.gradientAlpha or style.alpha or 1
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    top:SetVertexColor(r, g, b, a)
    bottom:SetVertexColor(r, g, b, a)
    left:SetVertexColor(r, g, b, a)
    right:SetVertexColor(r, g, b, a)
    top:Show()
    bottom:Show()
    left:Show()
    right:Show()
end

local dispelFingerprints = {} -- prefix -> last configured values
local fingerprintParts = {}   -- reused on every call
local NO_OPTIONS = {}

-- Each channel falls back to the default on its own.
local function DispelChannels(colors, def)
    local color = colors[def[4]]
    return color and color.r or def[5], color and color.g or def[6], color and color.b or def[7]
end

function AK.ConfigureDispelSlotStyles(prefix, health, options)
    if prefix == nil or health == nil then return end
    options = options or NO_OPTIONS
    local colors = options.colors or NO_OPTIONS
    local alpha = options.alpha or 1
    local thickness = options.thickness or 2
    local gradientAlpha = options.gradientAlpha or 0.90
    local gradientSize = options.gradientSize or 0.35

    -- Compare everything to three decimals.
    fingerprintParts[1] = format("%.3f|%.3f|%.3f|%.3f", alpha, thickness, gradientAlpha, gradientSize)
    for i, def in ipairs(DISPEL_TYPES) do
        fingerprintParts[i + 1] = format("%.3f|%.3f|%.3f", DispelChannels(colors, def))
    end
    local fingerprint = table.concat(fingerprintParts, "|")
    if dispelFingerprints[prefix] == fingerprint then return end
    dispelFingerprints[prefix] = fingerprint

    for _, def in ipairs(DISPEL_TYPES) do
        local styleKey = prefix .. ":" .. def[1]
        local r, g, b = DispelChannels(colors, def)
        AK.styles[styleKey] = {
            width = 1,
            height = 1,
            noRegions = true,
            healthFrame = health,
            r = r,
            g = g,
            b = b,
            alpha = alpha,
            gradientAlpha = gradientAlpha,
            gradientSize = gradientSize,
            thickness = thickness,
            layer = def[3],
            applyExtra = DrawDispelEdges,
        }
        RestyleSoon(styleKey)
    end
end

---------------------------------------------------------------------------------------
-- Build queue
---------------------------------------------------------------------------------------

local buildFrame = CreateFrame("Frame")
buildFrame:Hide()

local jobs, jobHead, jobTail = {}, 1, 0 -- the running job stays at the head until it finishes
local jobCuts = 0                       -- watchdog cuts of the job at the head
local loginStamp                        -- nil keeps the large-budget window closed

local function QueueBuildJob(fn, _)
    if not fn then return end
    jobTail = jobTail + 1
    jobs[jobTail] = fn
    buildFrame:Show()
end
AK.QueueBuildJob = QueueBuildJob
AK.QueueLiveBuildJob = QueueBuildJob

buildFrame:SetScript("OnUpdate", function(self)
    local kt = KT
    local profiler = kt and kt.CombatProfiler
    local stamp = profiler and profiler:Begin(BUILD_LABEL)

    local budget = BUILD_BUDGET_MS
    local inCombat = InCombatLockdown()
    if not inCombat and loginStamp and GetTime() - loginStamp < LOGIN_WINDOW_SECONDS then
        budget = LOGIN_BUDGET_MS
    end
    local started = debugprofilestop()

    while true do
        local job = jobs[jobHead]
        if job == nil then
            jobHead, jobTail = 1, 0
            self:Hide()
            break
        end

        local ok, result = pcall(job)
        local cut = false
        if ok then
            cut = result == "watchdog" -- a job returning this literal acts as a cut
        elseif type(result) == "string" then
            cut = find(result, WATCHDOG_TEXT, 1, true) ~= nil
        end

        if cut and jobCuts < RETRY_LIMIT then
            -- Stays next in line; resumes next frame.
            jobCuts = jobCuts + 1
            break
        end

        if not ok or cut or result ~= "again" then
            jobs[jobHead] = nil
            jobHead = jobHead + 1
            jobCuts = 0
            if not ok or cut then geterrorhandler()(result) end
        end

        if debugprofilestop() - started >= budget then break end
    end

    if profiler and stamp ~= nil then profiler:End(BUILD_LABEL, stamp) end
end)

-- Regen reopens the window only for a backlog held back by combat's small budget.
buildFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
buildFrame:SetScript("OnEvent", function(self)
    if jobs[jobHead] ~= nil then
        loginStamp = GetTime()
        self:Show()
    end
end)

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function()
    loginStamp = GetTime()
    buildFrame:Show()
end)

KTAuraKit = AK
