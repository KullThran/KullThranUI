local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then
    return
end

local Mod = KT:GetModule("Cursor", true) or KT:NewModule("Cursor", "AceEvent-3.0")
ns.Cursor = Mod

local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local GetCursorPosition = _G.GetCursorPosition
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsAltKeyDown = _G.IsAltKeyDown
local UnitClass = _G.UnitClass
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitPower = _G.UnitPower
local UnitPowerMax = _G.UnitPowerMax
local UnitPowerType = _G.UnitPowerType
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local PowerBarColor = _G.PowerBarColor
local CUSTOM_CLASS_COLORS = _G.CUSTOM_CLASS_COLORS
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local C_Spell = _G.C_Spell
local math = _G.math
local floor = math.floor
local pairs = _G.pairs
local ipairs = _G.ipairs
local tinsert = _G.table.insert
local tremove = _G.table.remove
local type = _G.type

local GCD_SPELL_ID = 61304
local BASE_SIZES = { 50, 70, 90 }
local SLOT_KEYS = { "innerRing", "mainRing", "outerRing" }
local LOCAL_MEDIA_PATH = "Interface\\AddOns\\KullThranUI_Cursor\\Modules\\Cursor\\Media\\"
local RING_TEXTURE = LOCAL_MEDIA_PATH .. "Ring_Main.tga"
local RETICLE_DOT_TEXTURE = LOCAL_MEDIA_PATH .. "Reticle_Dot.tga"
local RETICLE_RING_TEXTURE = LOCAL_MEDIA_PATH .. "Reticle_Circle.tga"
local PARTICLE_TEXTURE = LOCAL_MEDIA_PATH .. "Cursor_Particle.tga"
local CURSOR_POINT_TEXTURE = "Interface\\CURSOR\\Point"

local CURSOR_DEFAULTS = {
    enable = true,
    scale = 0.8,
    innerRing = "GCD",
    mainRing = "Main Ring",
    outerRing = "Cast",
    usePowerColors = false,
    reticleColorMode = "theme",
    reticleCustomColor = { r = 1.0, g = 1.0, b = 1.0 },
    mainRingColorMode = "theme",
    mainRingCustomColor = { r = 1.0, g = 1.0, b = 1.0 },
    gcdColorMode = "theme",
    gcdCustomColor = { r = 1.0, g = 1.0, b = 1.0 },
    castColorMode = "theme",
    castCustomColor = { r = 1.0, g = 1.0, b = 1.0 },
    healthColorMode = "theme",
    healthCustomColor = { r = 1.0, g = 1.0, b = 1.0 },
    healthColorLock = false,
    trailColorMode = "theme",
    trailCustomColor = { r = 1.0, g = 1.0, b = 1.0 },
    powerColorMode = "theme",
    powerCustomColor = { r = 1.0, g = 1.0, b = 1.0 },
    useMainRingClassColor = true,
    useGCDClassColor = true,
    useCastClassColor = true,
    useReticleClassColor = true,
    enableTrail = false,
    trailUseClassColor = true,
    trailDuration = 0.5,
    trailDensity = 0.005,
    trailScale = 1.0,
    trailMinMovement = 0.5,
    showOnlyInCombat = false,
    shiftAction = "None",
    ctrlAction = "None",
    altAction = "None",
    reticle = "Dot",
    reticleScale = 1.5,
    transparency = 1.0,
    enableClickAnimation = true,
    clickScale = 1.0,
    highContrastOuterThickness = 2,
    highContrastOuterColor = { r = 0.0, g = 0.0, b = 0.0 },
    highContrastOuterColorMode = "default",
    highContrastInnerThickness = -4,
    highContrastInnerColor = { r = 1.0, g = 1.0, b = 1.0 },
    highContrastInnerColorMode = "default",
    seasonalEffectStyle = "Candy Cane",
    seasonalParticleType = "Snowflakes",
    gcdFillDrain = "fill",
    castFillDrain = "fill",
    gcdRotation = 12,
    castRotation = 12,
}

local RING_OPTIONS = {
    "None",
    "Main Ring",
    "Main Ring + GCD",
    "Main Ring + Cast",
    "Cast",
    "GCD",
    "Health and Power",
    "Health",
    "Power",
    "High Contrast Ring",
}

local MODIFIER_OPTIONS = {
    "None",
    "Show Rings",
    "Ping with ring",
    "Ping with area",
    "Ping with crosshair",
    "Show Crosshair",
}

local RETICLE_OPTIONS = {
    "Dot",
    "Chevron",
    "Crosshair",
    "Diamond",
    "Flatline",
    "Star",
    "Ring",
    "Tech Arrow",
    "X",
    "No Reticle",
}

local SEASONAL_STYLE_OPTIONS = {
    "None",
    "Candy Cane",
    "Christmas Lights",
}

local SEASONAL_PARTICLE_OPTIONS = {
    "None",
    "Snowflakes",
    "Sparkles",
    "Both",
}

local RETICLE_TEXTURES = {
    ["Dot"] = { path = RETICLE_DOT_TEXTURE, scale = 0.5, isAtlas = false },
    ["Chevron"] = { path = "uitools-icon-chevron-down", scale = 1.0, isAtlas = true },
    ["Crosshair"] = { path = "uitools-icon-plus", scale = 1.0, isAtlas = true },
    ["Diamond"] = { path = "UF-SoulShard-FX-FrameGlow", scale = 1.0, isAtlas = true },
    ["Flatline"] = { path = "uitools-icon-minus", scale = 1.0, isAtlas = true },
    ["Star"] = { path = "AftLevelup-WhiteStarBurst", scale = 2.0, isAtlas = true },
    ["Ring"] = { path = RETICLE_RING_TEXTURE, scale = 1.0, isAtlas = false },
    ["Tech Arrow"] = { path = "ProgLan-w-4", scale = 1.0, isAtlas = true },
    ["X"] = { path = "uitools-icon-close", scale = 1.0, isAtlas = true },
    ["No Reticle"] = { path = nil, scale = 1.0, isAtlas = false },
}

local runtime = {
    frame = nil,
    reticle = nil,
    slots = {},
    trailPool = {},
    trailActive = {},
    trailTimer = 0,
    trailUpdateTimer = 0,
    trailLastX = nil,
    trailLastY = nil,
    stateTimer = 0,
    pingFrame = nil,
    pingTexture = nil,
    pingDuration = 0.5,
    pingTimer = 0,
    pingStartSize = 250,
    pingEndSize = 70,
    pingAnimating = false,
    clickFrame = nil,
    clickTexture = nil,
    clickTimer = 0,
    clickDuration = 0.32,
    clickBaseSize = 44,
    crosshair = nil,
    crosshairLines = {},
    crosshairDuration = 1.5,
    crosshairTimer = 0,
    crosshairAnimating = false,
    lastShift = false,
    lastCtrl = false,
    lastAlt = false,
    legacyTimer = 0,
    resourceMathBlocked = false,
    db = nil,
    lastFrameX = nil,
    lastFrameY = nil,
    hasDynamicRings = true,
}

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = CopyValue(nested)
    end
    return copy
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = CopyValue(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

local function Clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

local function IsSameDynamicState(a, b)
    if not a or not b then
        return false
    end
    return a.gcdStart == b.gcdStart
        and a.gcdDuration == b.gcdDuration
        and a.castStart == b.castStart
        and a.castDuration == b.castDuration
        and a.castIsChannel == b.castIsChannel
end

local function GetClassColor()
    local _, classTag = UnitClass("player")
    local color = classTag and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
    color = color and color[classTag]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function GetPowerTypeColor()
    local _, powerToken = UnitPowerType("player")
    local color = powerToken and PowerBarColor and PowerBarColor[powerToken]
    if color then
        return color.r or color[1] or 0, color.g or color[2] or 0.5, color.b or color[3] or 1
    end
    return 0.0, 0.5, 1.0
end

local function ClockToRadians(clockPosition)
    local position = tonumber(clockPosition) or 12
    if position == 12 then
        return 0
    end
    return position * math.pi / 6
end

local function SetTextureOrAtlas(texture, info)
    if not texture then
        return
    end

    if not info or not info.path then
        texture:Hide()
        return
    end

    texture:Show()
    if info.isAtlas then
        texture:SetAtlas(info.path)
    else
        texture:SetTexture(info.path)
    end
end

local function ConfigureCooldownFrame(frame, size)
    frame:SetSize(size, size)
    frame:SetPoint("CENTER")
    frame:SetSwipeTexture(RING_TEXTURE)
    if frame.SetDrawBling then
        frame:SetDrawBling(false)
    end
    if frame.SetDrawEdge then
        frame:SetDrawEdge(false)
    end
    if frame.SetHideCountdownNumbers then
        frame:SetHideCountdownNumbers(true)
    end
end

local function GetGCDInfo()
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
        if info and info.startTime and info.duration and info.startTime > 0 and info.duration > 0 then
            return info.startTime, info.duration
        end
    end

    if _G.GetSpellCooldown then
        local startTime, duration = _G.GetSpellCooldown(GCD_SPELL_ID)
        if startTime and duration and startTime > 0 and duration > 0 then
            return startTime, duration
        end
    end
end

local function GetCastInfo()
    local _, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
    local isChannel = false

    if not startTimeMS or not endTimeMS then
        local channelName
        channelName, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
        if channelName then
            isChannel = true
        end
    end

    if startTimeMS and endTimeMS and endTimeMS > startTimeMS then
        local startTime = startTimeMS / 1000
        local duration = (endTimeMS - startTimeMS) / 1000
        if duration > 0.05 then
            return startTime, duration, isChannel
        end
    end
end

local function ShowFinishedCooldown(frame)
    frame:Show()
    frame:SetReverse(false)
    frame:SetCooldown(GetTime() - 1, 0.01)
end

local function ClearCooldown(frame)
    if frame.Clear then
        frame:Clear()
    else
        frame:SetCooldown(0, 0)
    end
end

local function UpdateProgressCooldown(frame, percent, r, g, b, alpha)
    percent = Clamp(percent or 0, 0, 1)
    frame:SetSwipeColor(r, g, b, alpha)
    frame:SetReverse(false)
    ClearCooldown(frame)
    frame:SetCooldown(GetTime() - ((1 - percent) * 86400), 86400)
    frame:Show()
end

local function HideCooldown(frame)
    ClearCooldown(frame)
    frame:Hide()
end

local function HideStaticSlot(slot)
    slot.ring:Hide()
    if slot.bgRing then
        slot.bgRing:Hide()
    end
    slot.highOuter:Hide()
    slot.highInner:Hide()
end

local function HideDynamicSlot(slot, keepSecondary)
    HideCooldown(slot.background)
    HideCooldown(slot.primary)
    if not keepSecondary then
        HideCooldown(slot.secondary)
    end
end

local function HideSlot(slot)
    HideStaticSlot(slot)
    HideDynamicSlot(slot, false)
end

local function ShowStaticRing(slot, size, r, g, b, alpha)
    slot.ring:SetSize(size, size)
    slot.ring:SetVertexColor(r, g, b, alpha)
    slot.ring:Show()
end

local function SetLineColor(line, r, g, b, a)
    if line and line.SetColorTexture then
        line:SetColorTexture(r, g, b, a)
    end
end

local function GetHealthColor(db, percent)
    if db.healthColorLock or percent > 0.70 then
        return Mod:GetModeColor(db.healthColorMode, db.healthCustomColor, "health")
    end
    if percent > 0.50 then
        return 1.0, 0.788, 0.302
    end
    if percent > 0.35 then
        return 1.0, 0.451, 0.184
    end
    return 0.8, 0.0, 0.02
end

local function GetTrailStyleColor(style, index)
    if style == "Candy Cane" then
        if index % 2 == 0 then
            return 0.88, 0.12, 0.18
        end
        return 1.0, 1.0, 1.0
    end

    if style == "Christmas Lights" then
        local palette = {
            { 0.95, 0.10, 0.10 },
            { 0.12, 0.85, 0.20 },
            { 1.0, 0.84, 0.0 },
            { 0.3, 0.7, 1.0 },
            { 1.0, 1.0, 1.0 },
        }
        local color = palette[((index - 1) % #palette) + 1]
        return color[1], color[2], color[3]
    end

    return 1.0, 1.0, 1.0
end

local function TryGetResourcePercent(currentFunc, maxFunc)
    if runtime.resourceMathBlocked then
        return 1, false
    end

    local ok, percent = pcall(function()
        local maxValue = maxFunc("player")
        if not maxValue or maxValue == 0 then
            return 1
        end
        return currentFunc("player") / maxValue
    end)

    if ok and type(percent) == "number" then
        return Clamp(percent, 0, 1), true
    end

    runtime.resourceMathBlocked = true
    return 1, false
end

function Mod:GetDefaults()
    return CURSOR_DEFAULTS
end

function Mod:GetRingOptions()
    return RING_OPTIONS
end

function Mod:GetModifierOptions()
    return MODIFIER_OPTIONS
end

function Mod:GetReticleOptions()
    return RETICLE_OPTIONS
end

function Mod:GetSeasonalStyleOptions()
    return SEASONAL_STYLE_OPTIONS
end

function Mod:GetSeasonalParticleOptions()
    return SEASONAL_PARTICLE_OPTIONS
end

function Mod:GetMediaPaths()
    return {
        ring = RING_TEXTURE,
        reticleDot = RETICLE_DOT_TEXTURE,
        reticleRing = RETICLE_RING_TEXTURE,
        particle = PARTICLE_TEXTURE,
        cursorPoint = CURSOR_POINT_TEXTURE,
    }
end

function Mod:GetReticleTextureInfo(reticleName)
    return RETICLE_TEXTURES[reticleName or "Dot"] or RETICLE_TEXTURES["Dot"]
end

function Mod:GetModeColor(mode, customColor, ringType)
    if mode == "custom" and type(customColor) == "table" then
        return customColor.r or 1, customColor.g or 1, customColor.b or 1
    end

    if mode == "theme" and KT and KT.GetStyleAccentRGB then
        return KT:GetStyleAccentRGB()
    end
    if mode == "class" then
        return GetClassColor()
    end

    if mode == "power" and ringType == "power" then
        return GetPowerTypeColor()
    end

    if ringType == "power" then
        return 0.0, 0.5, 1.0
    end
    if ringType == "highContrastOuter" then
        return 0.0, 0.0, 0.0
    end
    if ringType == "highContrastInner" then
        return 1.0, 1.0, 1.0
    end
    return 1.0, 1.0, 1.0
end

function Mod:GetDB()
    KT.db.profile.cursor = KT.db.profile.cursor or {}
    local db = KT.db.profile.cursor

    if db._legacyImported ~= true and type(_G.UMC_Config) == "table" then
        for key in pairs(CURSOR_DEFAULTS) do
            if db[key] == nil and _G.UMC_Config[key] ~= nil then
                db[key] = CopyValue(_G.UMC_Config[key])
            end
        end
        db._legacyImported = true
    end

    MergeDefaults(db, CURSOR_DEFAULTS)
    if db._themeColorDefaultsMigrated ~= true then
        local modeKeys = {
            "reticleColorMode", "mainRingColorMode", "gcdColorMode", "castColorMode",
            "healthColorMode", "trailColorMode", "powerColorMode",
        }
        local colorKeys = {
            "reticleCustomColor", "mainRingCustomColor", "gcdCustomColor", "castCustomColor",
            "healthCustomColor", "trailCustomColor", "powerCustomColor",
        }
        local untouched = true
        for _, key in ipairs(modeKeys) do
            if db[key] ~= "class" then
                untouched = false
                break
            end
        end
        if untouched then
            for _, key in ipairs(colorKeys) do
                local color = db[key]
                if type(color) ~= "table"
                    or math.abs((color.r or 1) - 1) > 0.001
                    or math.abs((color.g or 1) - 1) > 0.001
                    or math.abs((color.b or 1) - 1) > 0.001 then
                    untouched = false
                    break
                end
            end
        end
        if untouched then
            for _, key in ipairs(modeKeys) do
                db[key] = "theme"
            end
        end
        db._themeColorDefaultsMigrated = true
    end
    runtime.db = db
    return db
end

local function HasDynamicRing(config)
    return config == "GCD"
        or config == "Cast"
        or config == "Main Ring + GCD"
        or config == "Main Ring + Cast"
        or config == "Health"
        or config == "Power"
        or config == "Health and Power"
end

local function HasAnyDynamicRings(db)
    if type(db) ~= "table" then
        return true
    end
    return HasDynamicRing(db.innerRing) or HasDynamicRing(db.mainRing) or HasDynamicRing(db.outerRing)
end

function Mod:HideLegacyCursor()
    local legacy = rawget(_G, "UltimateMouseCursor")
    if legacy then
        if legacy.PingFrame then
            legacy.PingFrame:Hide()
        end
        if legacy.CrosshairFrame then
            legacy.CrosshairFrame:Hide()
        end
    end

    local frames = {
        _G.UMC_CursorFrame,
        _G.UMC_PingFrame,
        _G.UMC_CrosshairFrame,
    }

    for _, frame in ipairs(frames) do
        if frame then
            frame:Hide()
        end
    end
end

function Mod:CreateTrailPool()
    if #runtime.trailPool > 0 then
        return
    end

    for _ = 1, 96 do
        local tex = UIParent:CreateTexture(nil, "OVERLAY")
        tex:SetBlendMode("ADD")
        tex:Hide()
        tinsert(runtime.trailPool, tex)
    end
end

function Mod:AcquireTrailTexture()
    if #runtime.trailPool == 0 then
        local totalTrailTextures = #runtime.trailActive + #runtime.trailPool
        if totalTrailTextures < 256 then
            for _ = 1, 32 do
                local tex = UIParent:CreateTexture(nil, "OVERLAY")
                tex:SetBlendMode("ADD")
                tex:Hide()
                tinsert(runtime.trailPool, tex)
            end
        end
    end

    if #runtime.trailPool == 0 then
        return
    end

    return tremove(runtime.trailPool)
end

function Mod:ReleaseTrailTexture(index)
    local tex = runtime.trailActive[index]
    if not tex then
        return
    end

    tex:Hide()
    tex:ClearAllPoints()
    tex.lastSize = nil
    runtime.trailActive[index] = runtime.trailActive[#runtime.trailActive]
    runtime.trailActive[#runtime.trailActive] = nil
    tinsert(runtime.trailPool, tex)
end

function Mod:ClearTrail()
    for index = #runtime.trailActive, 1, -1 do
        self:ReleaseTrailTexture(index)
    end
    runtime.trailTimer = 0
    runtime.trailUpdateTimer = 0
end

function Mod:CreateCrosshair()
    if runtime.crosshair then
        return
    end

    local frame = CreateFrame("Frame", "KT_CursorCrosshairFrame", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(10)
    frame:Hide()
    runtime.crosshair = frame

    local names = { "Top", "Bottom", "Left", "Right" }
    for _, name in ipairs(names) do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(1, 1, 1, 0.9)
        runtime.crosshairLines[name] = tex
    end
end

function Mod:CreatePingFrame()
    if runtime.pingFrame then
        return
    end

    local frame = CreateFrame("Frame", "KT_CursorPingFrame", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(20)
    frame:SetSize(runtime.pingStartSize, runtime.pingStartSize)
    frame:Hide()

    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetBlendMode("ADD")
    frame.texture = texture

    runtime.pingFrame = frame
    runtime.pingTexture = texture
end

function Mod:CreateClickFrame()
    if runtime.clickFrame then return end

    local frame = CreateFrame("Frame", "KT_CursorClickFrame", UIParent)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(18)
    frame:SetSize(runtime.clickBaseSize, runtime.clickBaseSize)
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, elapsed)
        Mod:UpdateClickAnimation(elapsed)
    end)

    local texture = frame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetTexture(RETICLE_RING_TEXTURE)
    texture:SetBlendMode("ADD")

    runtime.clickFrame = frame
    runtime.clickTexture = texture
end

function Mod:EnsureRuntime()
    if runtime.frame then
        return
    end

    self:CreateTrailPool()
    self:CreatePingFrame()
    self:CreateClickFrame()
    self:CreateCrosshair()

    local frame = CreateFrame("Frame", "KT_CursorFrame", UIParent)
    frame:SetSize(128, 128)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(5)
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, elapsed)
        Mod:OnFrameUpdate(elapsed)
    end)
    runtime.frame = frame

    for index, size in ipairs(BASE_SIZES) do
        local holder = CreateFrame("Frame", nil, frame)
        holder:SetSize(size, size)
        holder:SetPoint("CENTER")
        holder:SetFrameLevel(frame:GetFrameLevel() + index * 5)

        local ring = holder:CreateTexture(nil, "ARTWORK", nil, 1)
        ring:SetPoint("CENTER")
        ring:SetTexture(RING_TEXTURE)
        ring:Hide()

        local bgRing = holder:CreateTexture(nil, "ARTWORK", nil, 2)
        bgRing:SetPoint("CENTER")
        bgRing:SetTexture(RING_TEXTURE)
        bgRing:Hide()

        local highOuter = holder:CreateTexture(nil, "ARTWORK", nil, 3)
        highOuter:SetPoint("CENTER")
        highOuter:SetTexture(RING_TEXTURE)
        highOuter:Hide()

        local highInner = holder:CreateTexture(nil, "ARTWORK", nil, 4)
        highInner:SetPoint("CENTER")
        highInner:SetTexture(RING_TEXTURE)
        highInner:Hide()

        local background = CreateFrame("Cooldown", nil, holder)
        ConfigureCooldownFrame(background, size)
        background:SetFrameLevel(holder:GetFrameLevel() + 1)
        background:Hide()

        local primary = CreateFrame("Cooldown", nil, holder)
        ConfigureCooldownFrame(primary, size)
        primary:SetFrameLevel(holder:GetFrameLevel() + 2)
        primary:Hide()

        local secondary = CreateFrame("Cooldown", nil, holder)
        ConfigureCooldownFrame(secondary, size)
        secondary:SetFrameLevel(holder:GetFrameLevel() + 3)
        secondary:Hide()

        runtime.slots[index] = {
            holder = holder,
            ring = ring,
            bgRing = bgRing,
            highOuter = highOuter,
            highInner = highInner,
            background = background,
            primary = primary,
            secondary = secondary,
            size = size,
        }
    end

    local reticle = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    reticle:SetPoint("CENTER")
    runtime.reticle = reticle
end

function Mod:UpdateReticle()
    local db = self:GetDB()
    self:EnsureRuntime()

    local info = self:GetReticleTextureInfo(db.reticle)
    SetTextureOrAtlas(runtime.reticle, info)
    if not info or not info.path then
        return
    end

    local size = 16 * (info.scale or 1) * (db.reticleScale or 1.5)
    local r, g, b = self:GetModeColor(db.reticleColorMode, db.reticleCustomColor, "reticle")
    runtime.reticle:SetSize(size, size)
    runtime.reticle:SetVertexColor(r, g, b, db.transparency or 1)
end

function Mod:UpdateCrosshairAppearance()
    local db = self:GetDB()
    local r, g, b = self:GetModeColor(db.reticleColorMode, db.reticleCustomColor, "reticle")

    for _, line in pairs(runtime.crosshairLines) do
        SetLineColor(line, r, g, b, 0.9)
    end
end

function Mod:UpdateCrosshairPosition(cursorX, cursorY, uiScale)
    if not runtime.crosshair then
        return
    end

    local db = runtime.db or self:GetDB()
    local gap = 35 * (db.scale or 1.0)
    if not cursorX or not cursorY then
        cursorX, cursorY = GetCursorPosition()
    end
    uiScale = uiScale or UIParent:GetEffectiveScale() or 1
    local x = floor((cursorX / uiScale) + 0.5)
    local y = floor((cursorY / uiScale) + 0.5)
    local thickness = 2

    local top = runtime.crosshairLines.Top
    top:ClearAllPoints()
    top:SetPoint("TOP", UIParent, "TOPLEFT", x, 0)
    top:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, y + gap)
    top:SetWidth(thickness)

    local bottom = runtime.crosshairLines.Bottom
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, 0)
    bottom:SetPoint("TOP", UIParent, "BOTTOMLEFT", x, y - gap)
    bottom:SetWidth(thickness)

    local left = runtime.crosshairLines.Left
    left:ClearAllPoints()
    left:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, y)
    left:SetPoint("RIGHT", UIParent, "BOTTOMLEFT", x - gap, y)
    left:SetHeight(thickness)

    local right = runtime.crosshairLines.Right
    right:ClearAllPoints()
    right:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, y)
    right:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x + gap, y)
    right:SetHeight(thickness)
end

function Mod:PlayPing(texturePath)
    self:EnsureRuntime()

    runtime.pingAnimating = true
    runtime.pingTimer = 0
    runtime.pingFrame:SetSize(runtime.pingStartSize, runtime.pingStartSize)
    runtime.pingFrame:SetAlpha(1)
    runtime.pingTexture:SetTexture(texturePath or RING_TEXTURE)
    runtime.pingTexture:SetVertexColor(1, 1, 1, 1)
    runtime.pingFrame:Show()
end

function Mod:PlayClickAnimation()
    local db = runtime.db or self:GetDB()
    if db.enable == false or db.enableClickAnimation == false then return end
    if db.showOnlyInCombat and not InCombatLockdown() then return end

    self:EnsureRuntime()
    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale() or 1
    local x = floor((cursorX / uiScale) + 0.5)
    local y = floor((cursorY / uiScale) + 0.5)
    local baseSize = runtime.clickBaseSize * (tonumber(db.clickScale) or 1)
    local r, g, b = self:GetModeColor("theme", nil, "click")

    runtime.clickTimer = 0
    runtime.clickCurrentBaseSize = baseSize
    runtime.clickFrame:ClearAllPoints()
    runtime.clickFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    runtime.clickFrame:SetSize(baseSize, baseSize)
    runtime.clickFrame:SetAlpha(1)
    runtime.clickTexture:SetVertexColor(r, g, b, 1)
    runtime.clickFrame:Show()
end

function Mod:UpdateClickAnimation(elapsed)
    local frame = runtime.clickFrame
    if not (frame and frame:IsShown()) then return end

    runtime.clickTimer = runtime.clickTimer + elapsed
    local progress = runtime.clickTimer / runtime.clickDuration
    if progress >= 1 then
        frame:Hide()
        return
    end

    local scale, alpha
    if progress < 0.30 then
        scale = 1 - (0.28 * (progress / 0.30))
        alpha = 1
    else
        local expansion = (progress - 0.30) / 0.70
        scale = 0.72 + (0.76 * expansion)
        alpha = 1 - (expansion * expansion)
    end

    local size = (runtime.clickCurrentBaseSize or runtime.clickBaseSize) * scale
    frame:SetSize(size, size)
    frame:SetAlpha(alpha)
end

function Mod:GLOBAL_MOUSE_DOWN()
    self:PlayClickAnimation()
end

function Mod:PlayCrosshairFade()
    self:EnsureRuntime()
    runtime.crosshairAnimating = true
    runtime.crosshairTimer = 0
    runtime.crosshair:SetAlpha(1)
    runtime.crosshair:Show()
end

function Mod:UpdateVisibility(forceCombatState)
    self:EnsureRuntime()
    local db = runtime.db or self:GetDB()

    if db.enable == false then
        runtime.frame:Hide()
        if runtime.pingFrame then
            runtime.pingFrame:Hide()
        end
        if runtime.crosshair then
            runtime.crosshair:Hide()
        end
        if runtime.clickFrame then
            runtime.clickFrame:Hide()
        end
        self:ClearTrail()
        return
    end

    local modifierShow = (IsShiftKeyDown() and db.shiftAction == "Show Rings")
        or (IsControlKeyDown() and db.ctrlAction == "Show Rings")
        or (IsAltKeyDown() and db.altAction == "Show Rings")

    if modifierShow then
        runtime.frame:Show()
        return
    end

    if db.showOnlyInCombat then
        local inCombat = forceCombatState
        if inCombat == nil then
            inCombat = InCombatLockdown()
        end
        runtime.frame:SetShown(inCombat)
        if not inCombat then
            self:ClearTrail()
        end
        return
    end

    local pushToShow = (db.shiftAction == "Show Rings")
        or (db.ctrlAction == "Show Rings")
        or (db.altAction == "Show Rings")

    runtime.frame:SetShown(not pushToShow)
    if pushToShow then
        self:ClearTrail()
    end
end

function Mod:ApplyStaticSlot(slot, config, db)
    HideSlot(slot)

    if config == "None" then
        return
    end

    local alpha = db.transparency or 1
    local size = slot.size

    if config == "Main Ring" or config == "Main Ring + GCD" or config == "Main Ring + Cast" then
        local r, g, b = self:GetModeColor(db.mainRingColorMode, db.mainRingCustomColor, "main")
        ShowStaticRing(slot, size, r, g, b, alpha)
        return
    end

    if config == "Health" then
        local r, g, b = GetHealthColor(db, 1)
        ShowStaticRing(slot, size, r, g, b, alpha * 0.85)
        return
    end

    if config == "Power" then
        local r, g, b = self:GetModeColor(db.powerColorMode, db.powerCustomColor, "power")
        ShowStaticRing(slot, size, r, g, b, alpha * 0.85)
        return
    end

    if config == "Health and Power" then
        local hr, hg, hb = GetHealthColor(db, 1)
        local pr, pg, pb = self:GetModeColor(db.powerColorMode, db.powerCustomColor, "power")
        ShowStaticRing(slot, size, hr, hg, hb, alpha * 0.85)
        slot.secondary:SetSwipeColor(pr, pg, pb, alpha * 0.50)
        ShowFinishedCooldown(slot.secondary)
        return
    end

    if config == "GCD" or config == "Cast" then
        if slot.bgRing then
            slot.bgRing:SetSize(size, size)
            slot.bgRing:SetVertexColor(0.45, 0.45, 0.45, 0)
            slot.bgRing:Show()
        end
        return
    end

    if config == "High Contrast Ring" then
        local outerSize = size + ((db.highContrastOuterThickness or 2) * 2)
        local innerSize = size + ((db.highContrastInnerThickness or -4) * 2)
        local orR, orG, orB = self:GetModeColor(
            db.highContrastOuterColorMode,
            db.highContrastOuterColor,
            "highContrastOuter"
        )
        local irR, irG, irB = self:GetModeColor(
            db.highContrastInnerColorMode,
            db.highContrastInnerColor,
            "highContrastInner"
        )
        slot.highOuter:SetSize(outerSize, outerSize)
        slot.highInner:SetSize(innerSize, innerSize)
        slot.highOuter:SetVertexColor(orR, orG, orB, alpha)
        slot.highInner:SetVertexColor(irR, irG, irB, alpha)
        slot.highOuter:Show()
        slot.highInner:Show()
    end
end

function Mod:ApplyStaticRings()
    local db = self:GetDB()
    self:EnsureRuntime()

    for index, key in ipairs(SLOT_KEYS) do
        self:ApplyStaticSlot(runtime.slots[index], db[key], db)
    end
end

function Mod:UpdateDynamicSlot(slot, config, state, db)
    local alpha = db.transparency or 1

    if config == "Main Ring + GCD" then
        HideCooldown(slot.background)
        if state.gcdDuration and state.gcdDuration > 0 then
            local sr, sg, sb = self:GetModeColor(db.gcdColorMode, db.gcdCustomColor, "gcd")
            slot.primary:SetSwipeColor(sr, sg, sb, alpha)
            slot.primary:SetReverse((db.gcdFillDrain or "fill") == "fill")
            slot.primary:SetRotation(ClockToRadians(db.gcdRotation or 12))
            slot.primary:SetCooldown(state.gcdStart, state.gcdDuration)
            slot.primary:Show()
        else
            HideCooldown(slot.primary)
        end
        return
    end

    if config == "Main Ring + Cast" then
        HideCooldown(slot.background)
        if state.castDuration and state.castDuration > 0 then
            local sr, sg, sb = self:GetModeColor(db.castColorMode, db.castCustomColor, "cast")
            local reverse = (db.castFillDrain or "fill") == "fill"
            if state.castIsChannel then
                reverse = not reverse
            end
            slot.primary:SetSwipeColor(sr, sg, sb, alpha)
            slot.primary:SetReverse(reverse)
            slot.primary:SetRotation(ClockToRadians(db.castRotation or 12))
            slot.primary:SetCooldown(state.castStart, state.castDuration)
            slot.primary:Show()
        else
            HideCooldown(slot.primary)
        end
        return
    end

    if config == "GCD" then
        HideCooldown(slot.background)
        if state.gcdDuration and state.gcdDuration > 0 then
            local r, g, b = self:GetModeColor(db.gcdColorMode, db.gcdCustomColor, "gcd")
            slot.primary:SetSwipeColor(r, g, b, alpha)
            slot.primary:SetReverse((db.gcdFillDrain or "fill") == "fill")
            slot.primary:SetRotation(ClockToRadians(db.gcdRotation or 12))
            slot.primary:SetCooldown(state.gcdStart, state.gcdDuration)
            slot.primary:Show()
        else
            HideCooldown(slot.primary)
        end
        return
    end

    if config == "Cast" then
        HideCooldown(slot.background)
        if state.castDuration and state.castDuration > 0 then
            local r, g, b = self:GetModeColor(db.castColorMode, db.castCustomColor, "cast")
            local reverse = (db.castFillDrain or "fill") == "fill"
            if state.castIsChannel then
                reverse = not reverse
            end
            slot.primary:SetSwipeColor(r, g, b, alpha)
            slot.primary:SetReverse(reverse)
            slot.primary:SetRotation(ClockToRadians(db.castRotation or 12))
            slot.primary:SetCooldown(state.castStart, state.castDuration)
            slot.primary:Show()
        else
            HideCooldown(slot.primary)
        end
        return
    end

    HideCooldown(slot.background)
    HideCooldown(slot.primary)
    if config ~= "Health and Power" then
        HideCooldown(slot.secondary)
    end
end

function Mod:UpdateDynamicRings()
    local db = runtime.db or self:GetDB()
    self:EnsureRuntime()

    local gcdStart, gcdDuration = GetGCDInfo()
    local castStart, castDuration, castIsChannel = GetCastInfo()

    local state = {
        gcdStart = gcdStart,
        gcdDuration = gcdDuration,
        castStart = castStart,
        castDuration = castDuration,
        castIsChannel = castIsChannel,
    }

    if IsSameDynamicState(runtime.lastDynamicState, state) then
        return
    end
    runtime.lastDynamicState = state

    for index, key in ipairs(SLOT_KEYS) do
        self:UpdateDynamicSlot(runtime.slots[index], db[key], state, db)
    end
end

function Mod:UpdateRings()
    self:ApplyStaticRings()
    self:UpdateDynamicRings()
end

function Mod:UpdateTrail(elapsed, cursorX, cursorY, uiScale, db)
    db = db or runtime.db or self:GetDB()
    if not (db.enableTrail and runtime.frame and runtime.frame:IsShown()) then
        self:ClearTrail()
        return
    end

    runtime.trailUpdateTimer = (runtime.trailUpdateTimer or 0) + elapsed
    if runtime.trailUpdateTimer < 0.011 then
        return
    end
    elapsed = runtime.trailUpdateTimer
    runtime.trailUpdateTimer = 0

    if not cursorX or not cursorY then
        cursorX, cursorY = GetCursorPosition()
    end
    uiScale = uiScale or UIParent:GetEffectiveScale()
    local movementX = runtime.trailLastX and (cursorX - runtime.trailLastX) or 0
    local movementY = runtime.trailLastY and (cursorY - runtime.trailLastY) or 0
    local movementSq = (movementX * movementX) + (movementY * movementY)
    local density = math.max(db.trailDensity or 0.005, 0.003)
    local minMovement = math.max(db.trailMinMovement or 0.5, 0.25)
    local minMovementSq = minMovement * minMovement

    runtime.trailTimer = runtime.trailTimer + elapsed
    if runtime.trailTimer >= density and movementSq >= minMovementSq then
        runtime.trailTimer = runtime.trailTimer - density

        local tex = self:AcquireTrailTexture()
        if tex then
            local index = #runtime.trailActive + 1
            runtime.trailActive[index] = tex
            tex.life = db.trailDuration or 0.5
            tex.maxLife = tex.life
            tex.x = floor((cursorX / uiScale) + 0.5)
            tex.y = floor((cursorY / uiScale) + 0.5)

            tex:SetTexture(RETICLE_DOT_TEXTURE)
            tex:SetBlendMode("ADD")
            local r, g, b = self:GetModeColor(db.trailColorMode, db.trailCustomColor, "trail")
            tex:SetVertexColor(r, g, b, 0.95)
            tex.sizeJitter = 0.92 + ((index % 4) * 0.05)
            tex.baseSize = 24 * (db.trailScale or 1.0)

            local baseSize = (tex.baseSize or (24 * (db.trailScale or 1.0))) * tex.sizeJitter
            tex.lastSize = baseSize
            tex:SetSize(baseSize, baseSize)
            tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", tex.x, tex.y)
            tex:SetAlpha(0.95)
            tex:Show()
        end
    end

    runtime.trailLastX = cursorX
    runtime.trailLastY = cursorY

    for index = #runtime.trailActive, 1, -1 do
        local tex = runtime.trailActive[index]
        tex.life = tex.life - elapsed
        if tex.life <= 0 then
            self:ReleaseTrailTexture(index)
        else
            local progress = Clamp(tex.life / tex.maxLife, 0, 1)
            local baseSize = (tex.baseSize or (24 * (db.trailScale or 1.0))) * (tex.sizeJitter or 1.0)
            local scaledSize = math.max(4, baseSize * (0.55 + (progress * 0.45)))
            if not tex.lastSize or math.abs(scaledSize - tex.lastSize) >= 0.5 then
                tex:SetSize(scaledSize, scaledSize)
                tex.lastSize = scaledSize
            end
            tex:SetAlpha(progress * 0.95)
        end
    end
end

function Mod:HandleModifierAction(keyDown, lastState, action)
    if keyDown and not lastState then
        if action == "Ping with ring" then
            self:PlayPing(RING_TEXTURE)
        elseif action == "Ping with area" then
            self:PlayPing(RETICLE_DOT_TEXTURE)
        elseif action == "Ping with crosshair" then
            self:PlayCrosshairFade()
        end
    end
end

function Mod:UpdateModifiers(cursorX, cursorY, uiScale, db)
    db = db or runtime.db or self:GetDB()
    local shiftDown = IsShiftKeyDown()
    local ctrlDown = IsControlKeyDown()
    local altDown = IsAltKeyDown()

    self:HandleModifierAction(shiftDown, runtime.lastShift, db.shiftAction)
    self:HandleModifierAction(ctrlDown, runtime.lastCtrl, db.ctrlAction)
    self:HandleModifierAction(altDown, runtime.lastAlt, db.altAction)

    local holdCrosshair = (shiftDown and db.shiftAction == "Show Crosshair")
        or (ctrlDown and db.ctrlAction == "Show Crosshair")
        or (altDown and db.altAction == "Show Crosshair")

    if holdCrosshair then
        runtime.crosshairAnimating = false
        runtime.crosshair:SetAlpha(1)
        runtime.crosshair:Show()
        self:UpdateCrosshairPosition(cursorX, cursorY, uiScale)
    elseif ((not shiftDown) and runtime.lastShift and db.shiftAction == "Show Crosshair")
        or ((not ctrlDown) and runtime.lastCtrl and db.ctrlAction == "Show Crosshair")
        or ((not altDown) and runtime.lastAlt and db.altAction == "Show Crosshair") then
        self:PlayCrosshairFade()
    end

    local heldShowRings = (shiftDown and db.shiftAction == "Show Rings")
        or (ctrlDown and db.ctrlAction == "Show Rings")
        or (altDown and db.altAction == "Show Rings")

    if heldShowRings then
        self:UpdateVisibility(true)
    elseif ((not shiftDown) and runtime.lastShift and db.shiftAction == "Show Rings")
        or ((not ctrlDown) and runtime.lastCtrl and db.ctrlAction == "Show Rings")
        or ((not altDown) and runtime.lastAlt and db.altAction == "Show Rings") then
        self:UpdateVisibility()
    end

    runtime.lastShift = shiftDown
    runtime.lastCtrl = ctrlDown
    runtime.lastAlt = altDown
end

function Mod:UpdatePing(elapsed)
    if not runtime.pingAnimating then
        return
    end

    runtime.pingTimer = runtime.pingTimer + elapsed
    if runtime.pingTimer >= runtime.pingDuration then
        runtime.pingAnimating = false
        runtime.pingFrame:Hide()
        return
    end

    local progress = runtime.pingTimer / runtime.pingDuration
    local size = runtime.pingStartSize - ((runtime.pingStartSize - runtime.pingEndSize) * progress)
    runtime.pingFrame:SetSize(size, size)
    runtime.pingFrame:SetAlpha(1 - progress)
    runtime.pingFrame:SetPoint("CENTER", runtime.frame, "CENTER")
end

function Mod:UpdateCrosshairFade(elapsed, cursorX, cursorY, uiScale)
    if not runtime.crosshairAnimating then
        return
    end

    runtime.crosshairTimer = runtime.crosshairTimer + elapsed
    if runtime.crosshairTimer >= runtime.crosshairDuration then
        runtime.crosshairAnimating = false
        runtime.crosshair:Hide()
        return
    end

    local progress = runtime.crosshairTimer / runtime.crosshairDuration
    local alpha = 1
    if progress > 0.7 then
        alpha = 1 - ((progress - 0.7) / 0.3)
    end
    runtime.crosshair:SetAlpha(alpha)
    self:UpdateCrosshairPosition(cursorX, cursorY, uiScale)
end

function Mod:ApplySettings()
    local db = runtime.db or self:GetDB()
    self:EnsureRuntime()
    self:HideLegacyCursor()

    runtime.frame:SetScale(db.scale or 1.0)
    runtime.frame:SetAlpha(1)
    if runtime.frame.SetIgnoreParentScale then
        runtime.frame:SetIgnoreParentScale(false)
    end
    runtime.trailLastX = nil
    runtime.trailLastY = nil
    runtime.trailTimer = 0
    runtime.trailUpdateTimer = 0
    runtime.lastFrameX = nil
    runtime.lastFrameY = nil
    runtime.hasDynamicRings = HasAnyDynamicRings(db)
    runtime.lastDynamicState = nil

    self:UpdateReticle()
    self:UpdateCrosshairAppearance()
    self:ApplyStaticRings()
    self:UpdateDynamicRings()
    self:UpdateVisibility()
end

function Mod:ApplyToAddon()
    self:ApplySettings()
    return true
end

function Mod:OnFrameUpdate(elapsed)
    if not runtime.frame then
        return
    end

    local db = runtime.db or self:GetDB()

    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale() or 1
    local frameScale = runtime.frame:GetEffectiveScale() or uiScale
    local frameX = floor((cursorX / frameScale) + 0.5)
    local frameY = floor((cursorY / frameScale) + 0.5)

    if frameX ~= runtime.lastFrameX or frameY ~= runtime.lastFrameY then
        runtime.frame:ClearAllPoints()
        runtime.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", frameX, frameY)
        runtime.lastFrameX = frameX
        runtime.lastFrameY = frameY
    end

    self:UpdateModifiers(cursorX, cursorY, uiScale, db)
    if db.enableTrail or #runtime.trailActive > 0 then
        self:UpdateTrail(elapsed, cursorX, cursorY, uiScale, db)
    end
    self:UpdatePing(elapsed)
    self:UpdateCrosshairFade(elapsed, cursorX, cursorY, uiScale)

    if runtime.hasDynamicRings then
        runtime.stateTimer = runtime.stateTimer + elapsed
        if runtime.stateTimer >= 0.05 then
            runtime.stateTimer = 0
            self:UpdateDynamicRings()
        end
    end

    runtime.legacyTimer = runtime.legacyTimer + elapsed
    if runtime.legacyTimer >= 1.0 then
        runtime.legacyTimer = 0
        self:HideLegacyCursor()
    end
end

function Mod:OnProfileUpdate()
    self:GetDB()
    self:ApplySettings()
end

function Mod:PLAYER_ENTERING_WORLD()
    self:ApplySettings()
end

function Mod:PLAYER_REGEN_DISABLED()
    self:UpdateVisibility(true)
end

function Mod:PLAYER_REGEN_ENABLED()
    self:UpdateVisibility(false)
end

function Mod:OnEnable()
    self:GetDB()
    self:EnsureRuntime()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")

    if KT.db and KT.db.RegisterCallback then
        KT.db.RegisterCallback(self, "OnProfileChanged", "OnProfileUpdate")
        KT.db.RegisterCallback(self, "OnProfileCopied", "OnProfileUpdate")
        KT.db.RegisterCallback(self, "OnProfileReset", "OnProfileUpdate")
    end

    self:ApplySettings()
end

function Mod:OnDisable()
    if runtime.frame then
        runtime.frame:Hide()
    end
    if runtime.pingFrame then
        runtime.pingFrame:Hide()
    end
    if runtime.crosshair then
        runtime.crosshair:Hide()
    end
    if runtime.clickFrame then
        runtime.clickFrame:Hide()
    end
    self:ClearTrail()
end
