local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then return end

local issecretvalue = _G.issecretvalue

local function LText(text)
    if type(text) ~= "string" then
        return text
    end
    local locale = KT.GetLocale and KT:GetLocale()
    return locale and locale[text] or text
end

local function IsSecretValue(value)
    if value == nil or not issecretvalue then
        return false
    end
    return issecretvalue(value) == true
end


local objectiveTrackerAlpha
local objectiveTrackerPosition

local function CaptureObjectiveTrackerPosition(frame)
    if objectiveTrackerPosition or not frame or not frame.GetPoint then return end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if point then
        objectiveTrackerPosition = {
            point = point,
            relativeTo = relativeTo or UIParent,
            relativePoint = relativePoint or point,
            x = x or 0,
            y = y or 0,
        }
    end
end

local function RestoreObjectiveTrackerPosition(frame)
    if not frame or not objectiveTrackerPosition or not frame.ClearAllPoints then return end
    if InCombatLockdown and InCombatLockdown() then return end
    frame:ClearAllPoints()
    frame:SetPoint(
        objectiveTrackerPosition.point,
        objectiveTrackerPosition.relativeTo,
        objectiveTrackerPosition.relativePoint,
        objectiveTrackerPosition.x,
        objectiveTrackerPosition.y
    )
    objectiveTrackerPosition.testShifted = false
end

local function ShiftObjectiveTrackerForTest(frame)
    if not frame or not objectiveTrackerPosition or not frame.ClearAllPoints then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local tracker = Mod.mplusTrackerFrame
    local shift = tracker and tracker.GetHeight and math.max(40, (tracker:GetHeight() or 0) + 40) or 220
    if objectiveTrackerPosition.testShifted and objectiveTrackerPosition.testShift == shift then return end
    frame:ClearAllPoints()
    frame:SetPoint(
        objectiveTrackerPosition.point,
        objectiveTrackerPosition.relativeTo,
        objectiveTrackerPosition.relativePoint,
        objectiveTrackerPosition.x,
        objectiveTrackerPosition.y - shift
    )
    objectiveTrackerPosition.testShifted = true
    objectiveTrackerPosition.testShift = shift
end

local state = {
    active = false,
    mapID = nil,
    level = 0,
    startTime = nil,
    timeLimit = 0,
    deaths = 0,
    timePenalty = 0,
    forcesCurrent = 0,
    forcesMax = 0,
    bosses = {},
    affixes = {},
    completed = false,
    completionTime = nil,

    currentPull = {},
    deathDetails = {},
    isTestMode = false,
}

local function ResetRunProgress()
    state.active = false
    state.mapID = nil
    state.mapName = nil
    state.level = 0
    state.startTime = nil
    state.timeLimit = 0
    state.deaths = 0
    state.timePenalty = 0
    state.forcesCurrent = 0
    state.forcesMax = 0
    state.bosses = {}
    state.affixes = {}
    state.completed = false
    state.completionTime = nil
    state.currentPull = {}
    state.deathDetails = {}
end

local function GetConfig()
    local db = Mod:GetDB()
    db.mplusTracker = db.mplusTracker or {}
    -- Older profiles could persist the preview-era default that enabled the
    -- orange glow. Migrate once to the original yellow bar appearance.
    if db.mplusTracker._forcesAppearanceVersion ~= 2 then
        db.mplusTracker.showForcesGlow = false
        db.mplusTracker._forcesAppearanceVersion = 2
    end
    return db.mplusTracker
end

local function FormatTime(seconds)
    if not seconds or seconds < 0 then seconds = 0 end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

local function FormatForces(fmt, count, maxCount)
    if not maxCount or maxCount == 0 then return "" end
    local pct = string.format("%.2f%%", (count / maxCount) * 100)
    local res = string.gsub(fmt, ":percent:", function() return pct end)
    res = string.gsub(res, ":count:", function() return tostring(count) end)
    return res
end

local function GetMDT()
    return _G.MDT
end

local function UpdateObjectiveTrackerVisibility()
    local config = GetConfig()
    local trackerEnabled = Mod:GetDB().enable ~= false and config.enabled
    local shouldHide = trackerEnabled and state.active and not state.isTestMode
    local shouldShiftForTest = trackerEnabled and state.isTestMode

    -- The Objective Tracker skin also manages the parent alpha. Expose explicit
    -- ownership while a real challenge is active so that it does not restore
    -- Blizzard's tracker on its own update pass.
    if KT then
        KT._mplusTrackerOwnsObjectiveTracker = shouldHide == true
    end

    local scenario = _G.ScenarioObjectiveTracker
    if scenario then
        if scenario.SetAlpha then
            scenario:SetAlpha((shouldHide or shouldShiftForTest) and 0 or 1)
        end
        -- Only suppress the native tracker visually while KUI owns this area.
        -- Blizzard controls whether the scenario module, header and contents
        -- should be shown; forcing them visible leaves an orphan Scenario
        -- header behind when the player is not in a scenario.
    end

    if _G.ScenarioBlocksFrame and _G.ScenarioBlocksFrame.SetAlpha then
        _G.ScenarioBlocksFrame:SetAlpha((shouldHide or shouldShiftForTest) and 0 or 1)
    end

    local objectiveTracker = _G.ObjectiveTrackerFrame
    if objectiveTracker and objectiveTracker.SetAlpha then
        CaptureObjectiveTrackerPosition(objectiveTracker)
        if objectiveTrackerAlpha == nil and objectiveTracker.GetAlpha then
            objectiveTrackerAlpha = objectiveTracker:GetAlpha()
        end
        if shouldHide then
            objectiveTracker:SetAlpha(0)
        elseif objectiveTrackerAlpha ~= nil then
            objectiveTracker:SetAlpha(objectiveTrackerAlpha)
        else
            objectiveTracker:SetAlpha(1)
        end

        if shouldShiftForTest then
            ShiftObjectiveTrackerForTest(objectiveTracker)
        elseif objectiveTrackerPosition and objectiveTrackerPosition.testShifted then
            RestoreObjectiveTrackerPosition(objectiveTracker)
        end
    end
end

local function CreateBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
    bar:SetStatusBarTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga")
    KT:AddBackdrop(bar, 0, 0, 0, 0.4)
    return bar
end

local function GetTimerLimits()
    local limit = tonumber(state.timeLimit) or 0
    if limit <= 0 then
        return 1, 0.8, 0.6
    end
    local t2 = math.floor(limit * 0.8)
    local t3 = math.floor(limit * 0.6)
    return limit, t2, t3
end

local function BuildUI()
    if Mod.mplusTrackerFrame then return Mod.mplusTrackerFrame end

    local f = CreateFrame("Frame", "KullThranUIMythicPlusTracker", UIParent, "BackdropTemplate")
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(20)
    f:SetSize(271, 150)
    KT:AddBackdrop(f, 0, 0, 0, 0.76)
    f:EnableMouse(true)

    f.deathsText = f:CreateFontString(nil, "OVERLAY")
    f.deathsText:SetJustifyH("RIGHT")
    f.timerText = f:CreateFontString(nil, "OVERLAY")
    f.timerText:SetJustifyH("RIGHT")
    f.timerRemainingText = f:CreateFontString(nil, "OVERLAY")
    f.timerRemainingText:SetJustifyH("RIGHT")
    f.timerTotalText = f:CreateFontString(nil, "OVERLAY")
    f.timerTotalText:SetJustifyH("RIGHT")
    f.timerRemainingText:Hide()
    f.timerTotalText:Hide()

    f.keyText = f:CreateFontString(nil, "OVERLAY")
    f.keyText:SetJustifyH("LEFT")
    f.keyDetailsText = f:CreateFontString(nil, "OVERLAY")
    f.keyDetailsText:SetJustifyH("RIGHT")

    f.barSegments = {}
    for i = 1, 3 do
        local seg = {}
        seg.bar = CreateBar(f)
        seg.text = seg.bar:CreateFontString(nil, "OVERLAY")
        seg.text:SetJustifyH("RIGHT")
        f.barSegments[i] = seg
    end

    f.forcesBar = CreateBar(f)
    local overlay = CreateFrame("StatusBar", nil, f.forcesBar)
    overlay:SetStatusBarTexture("Interface" .. string.char(92) .. "AddOns" .. string.char(92) .. "KullThranUI" .. string.char(92) .. "Libraries" .. string.char(92) .. "texture" .. string.char(92) .. "Melli.tga")
    overlay:SetAllPoints()
    overlay:SetFrameLevel(f.forcesBar:GetFrameLevel() + 1)
    overlay:SetStatusBarColor(1, 0.33, 0.08, 0.8)
    f.forcesBar.glow = overlay

    f.forcesTextLeft = f:CreateFontString(nil, "OVERLAY")
    f.forcesTextLeft:SetJustifyH("RIGHT")
    f.forcesTextLeft:SetJustifyV("MIDDLE")

    f.objectives = {}
    f.bossTexts = f.objectives
    f.bossSplits = {}
    for i = 1, 10 do
        local obj = f:CreateFontString(nil, "OVERLAY")
        obj:SetJustifyH("RIGHT")
        f.objectives[i] = obj
    end

    -- A ticker or zone event can refresh the tracker before UpdateStyle runs.
    -- Seed every FontString with a guaranteed Blizzard font so SetText is always safe.
    local defaultFont = "Fonts\\FRIZQT__.TTF"
    f.deathsText:SetFont(defaultFont, 15, "OUTLINE")
    f.timerText:SetFont(defaultFont, 26, "OUTLINE")
    f.timerRemainingText:SetFont(defaultFont, 26, "OUTLINE")
    f.timerTotalText:SetFont(defaultFont, 11, "OUTLINE")
    f.keyText:SetFont(defaultFont, 16, "OUTLINE")
    f.keyDetailsText:SetFont(defaultFont, 13, "OUTLINE")
    for i = 1, 3 do
        f.barSegments[i].text:SetFont(defaultFont, 13, "OUTLINE")
    end
    f.forcesTextLeft:SetFont(defaultFont, 13, "OUTLINE")
    for i = 1, 10 do
        f.objectives[i]:SetFont(defaultFont, 12, "OUTLINE")
    end

    Mod.mplusTrackerFrame = f
    return f
end

local SAFE_TRACKER_FONT = "Fonts" .. string.char(92) .. "FRIZQT__.TTF"

local function IsDirectMediaPath(value)
    return type(value) == "string" and (value:find(string.char(92), 1, true) ~= nil or value:find("/", 1, true) ~= nil)
end

local function HasTrackerFont(fontString)
    if not fontString then return false end
    local ok, path = pcall(fontString.GetFont, fontString)
    return ok and type(path) == "string" and path ~= ""
end

local function SetTrackerFont(fontString, fontPath, size, flags)
    if not fontString then return false end
    local requestedPath = type(fontPath) == "string" and fontPath ~= "" and fontPath or SAFE_TRACKER_FONT
    local requestedSize = size or 12
    local requestedFlags = flags or ""
    local ok = pcall(fontString.SetFont, fontString, requestedPath, requestedSize, requestedFlags)
    if not ok or not HasTrackerFont(fontString) then
        pcall(fontString.SetFont, fontString, SAFE_TRACKER_FONT, requestedSize, requestedFlags)
    end
    return HasTrackerFont(fontString)
end

local function GetFont(c, fontKey, defaultFont, fallbackKey)
    local value = c[fontKey]
    if (type(value) ~= "string" or value == "") and fallbackKey then
        value = c[fallbackKey]
    end
    if KT and KT.ResolveStoredFontName then
        value = KT:ResolveStoredFontName(value)
    end
    if value and value ~= "" then
        if IsDirectMediaPath(value) then return value end
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM and LSM:Fetch("font", value) then return LSM:Fetch("font", value) end
    end
    if IsDirectMediaPath(defaultFont) then return defaultFont end
    return defaultFont or KT.FONT_PATH or ("Fonts" .. string.char(92) .. "FRIZQT__.TTF")
end

local function GetTexture(c, textureKey, defaultTex)
    local value = c[textureKey]
    if value and value ~= "" then
        if IsDirectMediaPath(value) then return value end
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM and LSM:Fetch("statusbar", value) then return LSM:Fetch("statusbar", value) end
    end
    if IsDirectMediaPath(defaultTex) then return defaultTex end
    return defaultTex or ("Interface" .. string.char(92) .. "AddOns" .. string.char(92) .. "KullThranUI" .. string.char(92) .. "Libraries" .. string.char(92) .. "texture" .. string.char(92) .. "Melli.tga")
end

local function UpdateStyle()
    local f = BuildUI()
    local config = GetConfig()
    local scale = config.scale or 1
    local width = config.barWidth or 271
    local fontPath = GetFont(config, "globalFont", KT.FONT_PATH or ("Fonts" .. string.char(92) .. "FRIZQT__.TTF"))
    local barTexture = GetTexture(config, "barTexture", GetTexture(config, "timerTexture"))

    f:SetScale(scale)
    f:SetWidth(width)
    local background = config.backgroundColor or { r = 0.01, g = 0.01, b = 0.015, a = 0 }
    local backgroundAlpha = config.showBackground == true and (background.a or 0) or 0
    if f.SetBackdropColor then
        f:SetBackdropColor(background.r or 0, background.g or 0, background.b or 0, backgroundAlpha)
    elseif f._ktBackdropTexture then
        f._ktBackdropTexture:SetColorTexture(background.r or 0, background.g or 0, background.b or 0, backgroundAlpha)
    end
    KT:AddBorder(f, 0, 0, 0, backgroundAlpha > 0 and 1 or 0)

    SetTrackerFont(f.deathsText, GetFont(config, "deathsFont", fontPath), config.deathsFontSize or 15, config.deathsFontFlags or "OUTLINE")
    local dc = config.deathsColor or { r = 1, g = 0, b = 0.412 }
    f.deathsText:SetTextColor(dc.r, dc.g, dc.b, dc.a or 1)

    local timerFont = GetFont(config, "timerFont", fontPath)
    local timerSize = config.timerFontSize or 26
    local timerFlags = config.timerFontFlags or "OUTLINE"
    SetTrackerFont(f.timerText, timerFont, timerSize, timerFlags)
    SetTrackerFont(f.timerRemainingText, timerFont, timerSize, timerFlags)
    SetTrackerFont(f.timerTotalText, timerFont, math.max(10, math.floor(timerSize * 0.42)), timerFlags)
    local trc = config.timerRunningColor or { r = 1, g = 0.808, b = 0.714 }
    f.timerText:SetTextColor(trc.r, trc.g, trc.b, 1)
    f.timerRemainingText:SetTextColor(trc.r, trc.g, trc.b, 1)
    f.timerTotalText:SetTextColor(trc.r, trc.g, trc.b, 0.72)

    SetTrackerFont(f.keyText, GetFont(config, "keyFont", fontPath), config.keyFontSize or 16, config.keyFontFlags or "OUTLINE")
    local kc = config.keyColor or { r = 0.761, g = 0, b = 1 }
    f.keyText:SetTextColor(kc.r, kc.g, kc.b, 1)
    SetTrackerFont(f.keyDetailsText, GetFont(config, "keyDetailsFont", fontPath), config.keyDetailsFontSize or 13, config.keyDetailsFontFlags or "OUTLINE")
    local kdc = config.keyDetailsColor or { r = 1, g = 0.804, b = 0.569 }
    f.keyDetailsText:SetTextColor(kdc.r, kdc.g, kdc.b, 1)

    local barColors = {
        config.bar1Color or { r = 0, g = 1, b = 0.478, a = 1 },
        config.bar2Color or { r = 0, g = 0.749, b = 1, a = 1 },
        config.bar3Color or { r = 0.796, g = 0, b = 1, a = 1 },
    }
    for i = 1, 3 do
        local seg = f.barSegments[i]
        seg.bar:SetStatusBarTexture(barTexture)
        local c = barColors[i]
        seg.bar:SetStatusBarColor(c.r, c.g, c.b, c.a or 1)
        local segmentFont = GetFont(config, "bar" .. i .. "Font", GetFont(config, "timerFont", fontPath))
        SetTrackerFont(seg.text, segmentFont, math.max(11, timerSize * 0.55), timerFlags)
    end

    f.forcesBar:SetStatusBarTexture(GetTexture(config, "forcesTexture", barTexture))
    local fc = config.forcesBarColor or { r = 0.733, g = 0.62, b = 0.133, a = 1 }
    f.forcesBar:SetStatusBarColor(fc.r, fc.g, fc.b, fc.a or 1)
    local glowC = config.forcesGlowColor or { r = 1, g = 0.33, b = 0.08, a = 0.8 }
    f.forcesBar.glow:SetStatusBarTexture(GetTexture(config, "forcesOverlayTexture", barTexture))
    f.forcesBar.glow:SetStatusBarColor(glowC.r, glowC.g, glowC.b, glowC.a or 1)
    f.forcesBar.glow:SetAlpha((config.showForcesGlow == true) and 1 or 0)
    SetTrackerFont(f.forcesTextLeft, GetFont(config, "forcesFont", fontPath), config.forcesFontSize or 13, config.forcesFontFlags or "OUTLINE")
    local forcesC = config.forcesColor or { r = 1, g = 1, b = 1 }
    f.forcesTextLeft:SetTextColor(forcesC.r, forcesC.g, forcesC.b, 1)

    local objColor = config.objectivesColor or { r = 1, g = 1, b = 1 }
    for _, text in ipairs(f.objectives) do
        SetTrackerFont(text, GetFont(config, "objectivesFont", fontPath), config.objectivesFontSize or 12, config.objectivesFontFlags or "OUTLINE")
        text:SetTextColor(objColor.r, objColor.g, objColor.b, 1)
    end
end

local function EnsureTrackerFonts(f)
    if not f then return false end
    local required = {
        f.deathsText, f.timerText, f.timerRemainingText, f.timerTotalText,
        f.keyText, f.keyDetailsText, f.forcesTextLeft,
    }
    for i = 1, 3 do
        required[#required + 1] = f.barSegments[i] and f.barSegments[i].text
    end
    for i = 1, 10 do
        required[#required + 1] = f.objectives[i]
    end
    for i = 1, #required do
        if not HasTrackerFont(required[i]) then
            UpdateStyle()
            break
        end
    end
    for i = 1, #required do
        if not HasTrackerFont(required[i]) then return false end
    end
    return true
end

local function UpdateObjectives()
    local f = BuildUI()
    local config = GetConfig()
    if not EnsureTrackerFonts(f) then return end
    local comp = config.completedObjectivesColor or { r = 0, g = 1, b = 0.14 }
    local readyTexture = "Interface" .. string.char(92) .. "RaidFrame" .. string.char(92) .. "ReadyCheck-Ready"
    for i, text in ipairs(f.objectives) do
        local boss = state.bosses[i]
        if boss then
            if boss.killed then
                local split = boss.killedTime and string.format(" (%s)", FormatTime(boss.killedTime)) or ""
                text:SetText(string.format("|cff%02x%02x%02x|T%s:12:12:0:0|t %s%s|r", math.floor(comp.r * 255), math.floor(comp.g * 255), math.floor(comp.b * 255), readyTexture, boss.name, split))
                text:SetTextColor(comp.r, comp.g, comp.b, comp.a or 1)
            else
                text:SetText(boss.name or "")
                local oc = config.objectivesColor or { r = 1, g = 1, b = 1 }
                text:SetTextColor(oc.r, oc.g, oc.b, oc.a or 1)
            end
        else
            text:SetText("")
            text:Hide()
        end
    end
end

local function LineHeight(fontString, fallback)
    local _, height = fontString:GetFont()
    return math.max(tonumber(height) or 0, fallback or 0)
end

local function LayoutUI()
    local f = BuildUI()
    local config = GetConfig()
    local width = config.barWidth or 271
    local pad = 8
    f:SetWidth(width)
    local top = 0

    f.deathsText:ClearAllPoints()
    if state.deaths > 0 then
        f.deathsText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -top)
        f.deathsText:Show()
        top = top + LineHeight(f.deathsText, 15) + 2
    else
        f.deathsText:Hide()
    end

    f.timerText:ClearAllPoints()
    f.timerRemainingText:ClearAllPoints()
    f.timerTotalText:ClearAllPoints()
    if config.showRemainingTimeOnly == true then
        f.timerText:Hide()
        f.timerRemainingText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -top)
        f.timerRemainingText:Show()
        top = top + LineHeight(f.timerRemainingText, 18) + 1
        f.timerTotalText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -top)
        f.timerTotalText:Show()
        top = top + LineHeight(f.timerTotalText, 10) + 3
    else
        f.timerRemainingText:Hide()
        f.timerTotalText:Hide()
        f.timerText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -top)
        f.timerText:Show()
        top = top + LineHeight(f.timerText, 18) + 2
    end

    if state.level > 0 then f.keyText:SetText(string.format("[%d]", state.level)) else f.keyText:SetText("") end
    f.keyDetailsText:SetText(table.concat(state.affixes or {}, " - "))
    f.keyText:ClearAllPoints()
    f.keyDetailsText:ClearAllPoints()
    f.keyText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -top)
    f.keyDetailsText:SetPoint("TOPRIGHT", f.keyText, "TOPLEFT", -6, 0)
    top = top + math.max(LineHeight(f.keyText, 14), LineHeight(f.keyDetailsText, 14), 14) + 4

    local barH = config.barHeight or 10
    local segGap = 2
    local availW = width - pad * 2
    local limit, limit2, limit3 = GetTimerLimits()
    local fractions = { limit3 / limit, (limit2 - limit3) / limit, (limit - limit2) / limit }
    local segWidth1 = math.max(20, math.floor((availW - segGap * 2) * fractions[1]))
    local segWidth2 = math.max(20, math.floor((availW - segGap * 2) * fractions[2]))
    local segWidth3 = math.max(20, availW - segGap * 2 - segWidth1 - segWidth2)
    local segX = pad
    local segWidths = { segWidth1, segWidth2, segWidth3 }
    for i = 1, 3 do
        local seg = f.barSegments[i]
        seg.bar:ClearAllPoints()
        seg.bar:SetPoint("TOPLEFT", f, "TOPLEFT", segX, -top)
        seg.bar:SetSize(segWidths[i], barH)
        seg.text:ClearAllPoints()
        seg.text:SetPoint("BOTTOMRIGHT", seg.bar, "BOTTOMRIGHT", -2, 1)
        segX = segX + segWidths[i] + segGap
    end
    top = top + barH + 15

    f.forcesBar:ClearAllPoints()
    f.forcesBar:SetPoint("TOPLEFT", f, "TOPLEFT", pad, -top)
    f.forcesBar:SetSize(availW, barH)
    f.forcesTextLeft:ClearAllPoints()
    f.forcesTextLeft:SetWidth(math.max(1, availW - 6))
    f.forcesTextLeft:SetHeight(math.max(barH, config.forcesFontSize or 13))
    f.forcesTextLeft:SetPoint("BOTTOMRIGHT", f.forcesBar, "TOPRIGHT", -3, 2)
    f.forcesTextLeft:SetDrawLayer("OVERLAY")
    top = top + barH + 15

    for i, text in ipairs(f.objectives) do
        if state.bosses[i] then
            text:ClearAllPoints()
            text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -top)
            text:SetWidth(availW)
            text:Show()
            top = top + LineHeight(text, config.objectivesFontSize or 12) + 2
        else
            text:Hide()
        end
    end
    f:SetHeight(math.max(120, top + 8))
end

local function UpdateForces()
    local f = BuildUI()
    local config = GetConfig()
    if not EnsureTrackerFonts(f) then return end
    local maxForces = tonumber(state.forcesMax) or 0
    if maxForces <= 0 then
        f.forcesBar:SetMinMaxValues(0, 1)
        f.forcesBar:SetValue(0)
        f.forcesBar.glow:Hide()
        f.forcesTextLeft:SetText("")
        return
    end
    local current = math.max(0, tonumber(state.forcesCurrent) or 0)
    local pullCount = 0
    for _, value in pairs(state.currentPull or {}) do
        if value ~= "DEAD" then pullCount = pullCount + 1 end
    end
    local text = LText("Forces") .. ": " .. FormatForces(config.forcesFormat or ":percent:", current, maxForces)
    if pullCount > 0 then
        text = text .. " " .. FormatForces(config.currentPullFormat or "(+:percent:)", pullCount, maxForces)
    end
    f.forcesBar:SetMinMaxValues(0, maxForces)
    f.forcesBar:SetValue(math.min(maxForces, current))
    f.forcesBar.glow:SetMinMaxValues(0, maxForces)
    f.forcesBar.glow:SetValue(math.min(maxForces, current))
    f.forcesTextLeft:SetText(text)
    f.forcesBar.glow:SetShown(config.showForcesGlow == true and current > 0)
end

local function UpdateDeaths()
    local f = BuildUI()
    if not EnsureTrackerFonts(f) then return end
    if state.deaths > 0 then
        f.deathsText:SetText(string.format("%d %s (-%s)", state.deaths, LText("Deaths"), FormatTime(state.timePenalty)))
        f.deathsText:Show()
    else
        f.deathsText:Hide()
    end
end

local function UpdateTimer()
    if not state.active then return end
    local f = BuildUI()
    local config = GetConfig()
    if not EnsureTrackerFonts(f) then return end
    local elapsed = GetTime() - state.startTime
    if state.completed then elapsed = state.completionTime end
    local remaining = (state.timeLimit or 0) - elapsed

    if config.showRemainingTimeOnly == true then
        local remainingText = (remaining < 0 and "-" or "") .. FormatTime(math.abs(remaining))
        if state.completed and config.showMillisecondsWhenDungeonCompleted then
            local absoluteRemaining = math.abs(remaining)
            remainingText = string.format("%s%s.%03d", remaining < 0 and "-" or "", FormatTime(absoluteRemaining), math.floor((absoluteRemaining % 1) * 1000))
        end
        f.timerText:Hide()
        f.timerRemainingText:SetText(remainingText)
        f.timerTotalText:SetText(FormatTime(state.timeLimit))
        f.timerRemainingText:Show()
        f.timerTotalText:Show()
    else
        local txt = FormatTime(elapsed) .. " / " .. FormatTime(state.timeLimit)
        if state.completed and config.showMillisecondsWhenDungeonCompleted then
            local diffSeconds = elapsed % 1
            txt = string.format("%s.%03d / %s", FormatTime(math.floor(elapsed)), math.floor(diffSeconds * 1000), FormatTime(state.timeLimit))
        end
        f.timerText:SetText(txt)
        f.timerText:Show()
        f.timerRemainingText:Hide()
        f.timerTotalText:Hide()
    end

    local timerColor = config.timerRunningColor or { r = 1, g = 0.808, b = 0.714 }
    if state.completed then
        local completedOnTime = elapsed <= state.timeLimit
        timerColor = completedOnTime and (config.timerSuccessColor or { r = 0.118, g = 1, b = 0.714 }) or (config.timerExpiredColor or { r = 1, g = 0.16, b = 0.18 })
    elseif elapsed > state.timeLimit then
        timerColor = config.timerExpiredColor or { r = 1, g = 0.16, b = 0.18 }
    end
    f.timerText:SetTextColor(timerColor.r, timerColor.g, timerColor.b, 1)
    f.timerRemainingText:SetTextColor(timerColor.r, timerColor.g, timerColor.b, 1)
    f.timerTotalText:SetTextColor(timerColor.r, timerColor.g, timerColor.b, 0.72)

    local limit, limit2, limit3 = GetTimerLimits()
    local upperLimits = { limit3, limit2, limit }
    local lowerLimits = { 0, limit3, limit2 }
    for i = 1, 3 do
        local seg = f.barSegments[i]
        local barLimit = upperLimits[i]
        local lowerLimit = lowerLimits[i]
        local zone = math.max(0.001, barLimit - lowerLimit)
        local segmentRemaining = barLimit - elapsed
        local progress = math.max(0, math.min(1, (elapsed - lowerLimit) / zone))
        seg.bar:SetMinMaxValues(0, 1)
        seg.bar:SetValue(progress)

        local timeText
        local color
        if state.completed then
            if segmentRemaining <= 0 then
                color = config.timerExpiredColor or { r = 1, g = 0.16, b = 0.18 }
                timeText = "-" .. FormatTime(math.abs(segmentRemaining))
            else
                color = config.timerSuccessColor or { r = 0.118, g = 1, b = 0.714 }
                timeText = FormatTime(segmentRemaining)
            end
        elseif segmentRemaining <= 0 and i == 1 then
            color = config.timerExpiredColor or { r = 1, g = 0.16, b = 0.18 }
            timeText = "-" .. FormatTime(math.abs(segmentRemaining))
        elseif segmentRemaining <= 0 then
            color = config.timerRunningColor or { r = 1, g = 0.808, b = 0.714 }
            timeText = ""
        else
            color = config.timerRunningColor or { r = 1, g = 0.808, b = 0.714 }
            timeText = FormatTime(segmentRemaining)
        end
        seg.text:SetText(timeText)
        seg.text:SetTextColor(color.r, color.g, color.b, 1)
    end
end

local function SyncState()
    local challengeActive = C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive() == true
    local mapID = challengeActive and C_ChallengeMode.GetActiveChallengeMapID() or nil
    if (not challengeActive or not mapID) and not state.isTestMode then
        state.active = false
        state.mapID = nil
        if Mod.mplusTrackerFrame then Mod.mplusTrackerFrame:Hide() end
        UpdateObjectiveTrackerVisibility()
        return
    end

    local config = GetConfig()
    local enhancementsDB = Mod:GetDB()
    if enhancementsDB.enable == false or not config.enabled then
        state.active = false
        if Mod.mplusTrackerFrame then Mod.mplusTrackerFrame:Hide() end
        UpdateObjectiveTrackerVisibility()
        return
    end

    if not state.isTestMode then
        local preserveBossProgress = state.active == true and state.mapID == mapID
        state.active = true
        state.mapID = mapID
        local name, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
        state.mapName = name
        state.timeLimit = tonumber(timeLimit) or 0

        local level, affixIDs = C_ChallengeMode.GetActiveKeystoneInfo()
        state.level = level or 0
        state.affixes = {}
        if affixIDs then
            for _, affixID in ipairs(affixIDs) do
                local affixName = C_ChallengeMode.GetAffixInfo(affixID)
                if affixName then
                    table.insert(state.affixes, affixName)
                end
            end
        end

        local elapsedNow = select(2, GetWorldElapsedTime(1)) or 0

        local prevBosses = preserveBossProgress and (state.bosses or {}) or {}
        local prevBossesByName = {}
        for _, boss in ipairs(prevBosses) do
            if boss.name and boss.name ~= "" then
                prevBossesByName[boss.name] = boss
            end
        end
        state.bosses = {}
        state.forcesCurrent = 0
        state.forcesMax = 0
        local stepCount = select(3, C_Scenario.GetStepInfo())
        if stepCount and stepCount > 0 then
            for i = 1, stepCount do
                local info = C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo(i)
                if info then
                    if info.isWeightedProgress then
                        if info.totalQuantity and info.totalQuantity > 0 then
                            state.forcesMax = info.totalQuantity
                            local q = info.quantityString and tonumber(info.quantityString:match("%d+")) or 0
                            state.forcesCurrent = q
                        end
                    else
                        local bossName = info.description or ""
                        local prev = bossName ~= "" and prevBossesByName[bossName] or nil
                        local killed = info.completed == true or (prev and prev.killed == true)
                        local killedTime = killed and prev and prev.killedTime or nil
                        if killed and not killedTime and info.elapsed then
                            killedTime = elapsedNow - info.elapsed
                        end
                        table.insert(state.bosses, {
                            name = bossName,
                            killed = killed,
                            killedTime = killedTime,
                        })
                    end
                end
            end
        end

        local deathCount, timeLost = C_ChallengeMode.GetDeathCount()
        state.deaths = deathCount or 0
        state.timePenalty = timeLost or 0
        state.startTime = GetTime() - elapsedNow
    end

    local f = BuildUI()
    f:Show()
    UpdateObjectiveTrackerVisibility()
    UpdateStyle()
    LayoutUI()
    UpdateObjectiveTrackerVisibility()
    UpdateForces()
    UpdateTimer()
    UpdateDeaths()
    UpdateObjectives()

    Mod:ApplyMythicPlusTrackerPosition()
end

function Mod:ApplyMythicPlusTrackerPosition()
    local f = BuildUI()
    local p = GetConfig().position
    if p then
        f:ClearAllPoints()
        f:SetPoint(p.point or "RIGHT", UIParent, p.relativePoint or p.point or "RIGHT", p.x or -16, p.y or 224)
    end
end

function Mod:RefreshMythicPlusTracker()
    SyncState()
end

function Mod:RunMythicPlusTrackerTest(msg)
    state.isTestMode = true
    state.active = true
    state.mapID = 379
    state.mapName = "Test Dungeon"
    state.level = 10
    state.timeLimit = 1800
    state.startTime = GetTime() - 600
    state.deaths = 20
    state.timePenalty = 100
    state.forcesCurrent = 120
    state.forcesMax = 300
    state.bosses = {
        { name = "First Boss", killed = true, killedTime = 200 },
        { name = "Second Boss", killed = true, killedTime = 400 },
        { name = "Third Boss", killed = false }
    }
    state.completed = false
    state.currentPull = {}

    local f = BuildUI()
    f:Show()

    UpdateObjectiveTrackerVisibility()
    UpdateStyle()
    LayoutUI()
    UpdateObjectiveTrackerVisibility()
    if f.barSegments then UpdateTimer() end
    UpdateForces()
    UpdateDeaths()
    UpdateObjectives()

    Mod:ApplyMythicPlusTrackerPosition()

    if not Mod.mplusTestTimer then
        Mod.mplusTestTimer = C_Timer.NewTicker(1, function()
            if not state.isTestMode then Mod.mplusTestTimer:Cancel(); Mod.mplusTestTimer = nil; return end
            UpdateTimer()
        end)
    end
end

function Mod:StopMythicPlusTrackerTest()
    local f = BuildUI()
    state.isTestMode = false
    ResetRunProgress()
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(20)
    f:Hide()
    SyncState()
end

function Mod:RegisterMythicPlusTrackerMover()
    if self.mythicPlusTrackerMoverRegistered or not (KT and KT.RegisterMovableElements) then
        return
    end

    KT:RegisterMovableElements({
        {
            key = "ENH_MYTHIC_PLUS_TRACKER",
            label = LText("Mythic+ Timer"),
            group = "Enhancements",
            getFrame = function() return Mod:GetMythicPlusTrackerFrame() end,
            getSize = function()
                local frame = Mod:GetMythicPlusTrackerFrame()
                return frame:GetWidth(), frame:GetHeight()
            end,
            isHidden = function() return false end,
            loadPosition = function()
                local position = GetConfig().position
                return {
                    point = position and position.point or "RIGHT",
                    relativePoint = position and position.relativePoint or (position and position.point) or "RIGHT",
                    x = position and position.x or -16,
                    y = position and position.y or 224,
                }
            end,
            savePosition = function(_, point, relativePoint, x, y)
                GetConfig().position = {
                    point = point or "RIGHT",
                    relativePoint = relativePoint or point or "RIGHT",
                    x = x or -16,
                    y = y or 224,
                }
            end,
            applyPosition = function()
                Mod:ApplyMythicPlusTrackerPosition()
            end,
            applyPendingPosition = function(_, pos)
                local frame = Mod:GetMythicPlusTrackerFrame()
                frame:ClearAllPoints()
                frame:SetPoint(
                    pos.point or "RIGHT",
                    UIParent,
                    pos.relativePoint or pos.point or "RIGHT",
                    pos.x or -16,
                    pos.y or 224
                )
            end,
        },
    })
    self.mythicPlusTrackerMoverRegistered = true
end

function Mod:GetMythicPlusTrackerFrame()
    return BuildUI()
end

function Mod:InitializeMythicPlusTracker()
    if self.mplusTrackerInitialized then return end
    self.mplusTrackerInitialized = true

    local f = CreateFrame("Frame")
    f:RegisterEvent("SCENARIO_UPDATE")
    f:RegisterEvent("SCENARIO_POI_UPDATE")
    f:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    f:RegisterEvent("WORLD_STATE_TIMER_START")
    f:RegisterEvent("WORLD_STATE_TIMER_STOP")
    f:RegisterEvent("CHALLENGE_MODE_START")
    f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    f:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
    f:RegisterEvent("CHALLENGE_MODE_RESET")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("ZONE_CHANGED_INDOORS")
    f:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")

    f:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
    f:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    f:RegisterEvent("UNIT_DIED")
    f:RegisterEvent("ENCOUNTER_START")
    f:RegisterEvent("ENCOUNTER_END")

    f:SetScript("OnEvent", function(_, event, ...)
        if event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" then
            local _, _, difficulty = GetInstanceInfo()
            if GetConfig().insertKeystoneAutomatically and (difficulty == 8 or difficulty == 23) then
                for bagIndex = 0, NUM_BAG_SLOTS do
                    for invIndex = 1, C_Container.GetContainerNumSlots(bagIndex) do
                        local itemID = C_Container.GetContainerItemID(bagIndex, invIndex)
                        if itemID and C_Item.IsItemKeystoneByID(itemID) then
                            C_Container.UseContainerItem(bagIndex, invIndex)
                            return
                        end
                    end
                end
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if state.active then
                state.currentPull = {}
                UpdateForces()
            end
        elseif event == "UNIT_THREAT_LIST_UPDATE" then
            local unit = ...
            if not GetMDT() or not state.active then return end
            if not InCombatLockdown() or not unit or not UnitExists(unit) then return end

            local guid = UnitGUID(unit)
            if not guid or state.currentPull[guid] then return end

            local _, _, _, _, _, npcID = strsplit("-", guid)
            if npcID then
                local count = GetMDT():GetEnemyForces(tonumber(npcID))
                if count and count > 0 then
                    state.currentPull[guid] = count
                    UpdateForces()
                end
            end
        elseif event == "UNIT_DIED" then
            local unitTarget = ...
            if not unitTarget then return end

            -- UNIT_DIED can expose a protected/secret GUID and name in combat.
            -- Never feed those values into UnitInParty or use them as table keys.
            if IsSecretValue(unitTarget) then return end

            local name = UnitNameFromGUID(unitTarget)
            if name and type(name) == "string" and not IsSecretValue(name) then
                local inPartyOK, inParty = pcall(UnitInParty, name)
                if inPartyOK and inParty then
                    local infoOK, _, class = pcall(GetPlayerInfoByGUID, unitTarget)
                    if not infoOK or IsSecretValue(class) then
                        class = nil
                    end
                    table.insert(state.deathDetails, { name = name, class = class, time = (GetTime() - (state.startTime or GetTime())) })
                end
            end

            if state.currentPull[unitTarget] then
                state.currentPull[unitTarget] = "DEAD"
                UpdateForces()
            end
        elseif event == "ENCOUNTER_START" then
            state.currentPull = {}
            UpdateForces()
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, difficultyID, groupSize, success = ...
            if success and state.active then
                for _, boss in ipairs(state.bosses) do
                    if not boss.killed and string.find(boss.name, encounterName) then
                        boss.killed = true
                        boss.killedTime = GetTime() - state.startTime
                    end
                end
                SyncState()
            end
        else
            if event == "CHALLENGE_MODE_START" then
                ResetRunProgress()
            elseif event == "CHALLENGE_MODE_RESET" then
                ResetRunProgress()
            elseif event == "CHALLENGE_MODE_COMPLETED" then
                state.completed = true
                state.completionTime = GetTime() - state.startTime
            end
            SyncState()
        end
    end)

    if not Mod.mplusTimer then
        Mod.mplusTimer = C_Timer.NewTicker(1, function()
            if state.active and not state.isTestMode then
                UpdateTimer()
            end
        end)
    end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        local config = GetConfig()
        if not config.showTooltipCount or not GetMDT() then return end

        local _, unit = tooltip:GetUnit()
        if unit then
            local guid = UnitGUID(unit)
            if guid then
                local _, _, _, _, _, npcID = strsplit("-", guid)
                if npcID then
                    local count = GetMDT():GetEnemyForces(tonumber(npcID))
                    if count and count > 0 and state.forcesMax > 0 then
                        local fmt = config.tooltipCountFormat or "+:count: / :percent:"
                        tooltip:AddLine(LText("Forces") .. ": " .. FormatForces(fmt, count, state.forcesMax), 1, 0.82, 0)
                    end
                end
            end
        end
    end)

    Mod:RegisterMythicPlusTrackerMover()
    SyncState()
end

-- ============================================================================
-- /ktmptimer slash command (Mythic+ Tracker test)
-- ============================================================================

local function RegisterTrackerChatCommand()
    if KT and KT.RegisterChatCommand and not Mod.trackerCommandRegistered then
        Mod.trackerCommandRegistered = true
        KT:RegisterChatCommand("ktmptimer", function(msg)
            local cmd = strlower(strtrim(msg or ""))
            if cmd == "test" then
                Mod:RunMythicPlusTrackerTest()
                if KT.Print then KT:Print(LText("Mythic+ Tracker test started. Use /ktmptimer stop to finish.")) end
            elseif cmd == "stop" then
                Mod:StopMythicPlusTrackerTest()
                if KT.Print then KT:Print(LText("Mythic+ Tracker test stopped.")) end
            elseif cmd == "config" then
                if KT.ToggleConfig then KT:ToggleConfig() end
            else
                if KT.Print then KT:Print(LText("Usage: /ktmptimer [test | stop | config]")) end
            end
        end)
    end
end

RegisterTrackerChatCommand()
