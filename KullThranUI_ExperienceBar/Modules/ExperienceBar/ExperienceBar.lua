local ADDON_NAME, ns = ...
local KT = _G.KT

local Mod = KT:NewModule("ExperienceBar", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

local UIParent = _G.UIParent
local min, max, floor = math.min, math.max, math.floor
local time = time

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function SafeNum(v, fallback)
    if IsSecret(v) or type(v) ~= "number" then return fallback or 0 end
    return v
end

local function FormatCur(val)
    if AbbreviateLargeNumbers then
        local ok, res = pcall(AbbreviateLargeNumbers, val)
        if ok and res ~= nil then return res end
    end
    if IsSecret(val) then
        local s = tostring(val)
        local n = tonumber(s)
        if n then return FormatCur(n) end
        return s
    end
    if type(val) == "string" then
        local n = tonumber(val)
        if n then return FormatCur(n) end
        return val
    end
    if type(val) ~= "number" then return tostring(val) end
    if val >= 1e6 then
        local v = val / 1e6
        if v == floor(v) then return string.format("%dM", v) end
        return string.format("%.1fM", v)
    end
    if val >= 1e3 then
        local v = val / 1e3
        if v == floor(v) then return string.format("%dK", v) end
        return string.format("%.1fK", v)
    end
    return tostring(floor(val))
end

local function FormatFull(val)
    if IsSecret(val) then
        local s = tostring(val)
        local n = tonumber(s)
        if n then return FormatFull(n) end
        return s
    end
    if type(val) == "string" then
        local n = tonumber(val)
        if n then return FormatFull(n) end
        return val
    end
    if type(val) ~= "number" then return tostring(val) end
    local n = floor(val)
    if BreakUpLargeNumbers then
        local ok, res = pcall(BreakUpLargeNumbers, n)
        if ok and res ~= nil then return res end
    end
    return tostring(n)
end

local function FormatTime(seconds)
    if not seconds or seconds <= 0 or seconds == math.huge then
        return "--"
    end
    local s = floor(seconds)
    local h = floor(s / 3600)
    local m = floor((s % 3600) / 60)
    if h > 0 then
        return string.format("%dh %dm", h, m)
    end
    return string.format("%dm", m)
end

local function GetMaxLevel()
    if GetMaxPlayerLevel then return GetMaxPlayerLevel() end
    if GetMaxLevelForPlayerExpansion then return GetMaxLevelForPlayerExpansion() end
    if MAX_PLAYER_LEVEL then return MAX_PLAYER_LEVEL end
    return 0
end

local function GetPlayerReachableMaxLevel()
    if GetMaxLevelForPlayerExpansion then
        local ok, level = pcall(GetMaxLevelForPlayerExpansion)
        if ok and type(level) == "number" and level > 0 then
            return level
        end
    end

    if GetAccountExpansionLevel and GetMaxLevelForExpansionLevel then
        local okExpansion, expansionLevel = pcall(GetAccountExpansionLevel)
        if okExpansion and type(expansionLevel) == "number" then
            local okLevel, level = pcall(GetMaxLevelForExpansionLevel, expansionLevel)
            if okLevel and type(level) == "number" and level > 0 then
                return level
            end
        end
    end

    return GetMaxLevel()
end

local function IsMaxLevel()
    if UnitIsMaxLevel then
        local ok, res = pcall(UnitIsMaxLevel, "player")
        if ok and res then return true end
    end
    local lvl = UnitLevel and UnitLevel("player") or 0
    local maxLvl = GetPlayerReachableMaxLevel()
    return maxLvl > 0 and lvl >= maxLvl
end

local function CanPlayerGainLevels()
    local level = UnitLevel and UnitLevel("player") or 0
    local maxLevel = GetPlayerReachableMaxLevel()
    return maxLevel <= 0 or level < maxLevel
end

local DEFAULTS = {
    enable = true,
    visible = true,
    disableAtMaxLevel = true,
    mode = "AUTO",
    autoTrackReputation = false,
    width = 300,
    height = 10,
    x = 0,
    y = 0,
    texture = "Melli",
    font = "AAA_ITC_Avant_Garde",
    fontSize = 12,
    fontOutline = "OUTLINE",
    showText = true,
    showSessionData = false,
}

function Mod:OnInitialize()
    if KT.db and KT.db.profile then
        KT.db.profile.experienceBar = KT.db.profile.experienceBar or {}
        self.db = KT.db.profile.experienceBar
        for key, value in pairs(DEFAULTS) do
            if self.db[key] == nil then
                self.db[key] = value
            end
        end

        -- Migrate legacy profiles that were left pinned to HONOR by default.
        if not self.db._defaultTrackingModeMigrated_v1 then
            if self.db.mode == "HONOR" then
                self.db.mode = "AUTO"
            end
            self.db._defaultTrackingModeMigrated_v1 = true
        end
    end
end

function Mod:OnEnable()
    if not self.db then self:OnInitialize() end
    self:EnsureFrame()
    self:ResetSession()
    -- Always hide Blizzard status bars when this module is running.
    self:ShowBlizzardBars(false)

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateBar")
    self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", "UpdateBar")
    self:RegisterEvent("PLAYER_XP_UPDATE", "OnXPUpdate")
    self:RegisterEvent("PLAYER_LEVEL_UP", "OnXPUpdate")
    self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateBar")
    self:RegisterEvent("UPDATE_FACTION", "UpdateBar")
    self:RegisterEvent("HONOR_XP_UPDATE", "UpdateBar")
    self:RegisterEvent("PLAYER_PVP_KILLS_CHANGED", "UpdateBar")
    self:RegisterEvent("ENABLE_XP_GAIN", "UpdateBar")
    self:RegisterEvent("DISABLE_XP_GAIN", "UpdateBar")

    self:Refresh()
end

function Mod:OnDisable()
    -- Keep Blizzard bars hidden even when this module is disabled.
    self:ShowBlizzardBars(false)
    if self.frame then
        self.frame:Hide()
    end
end

function Mod:OnEnterWorld()
    self:ResetSession()
    self:UpdateBar()
end

function Mod:ResetSession()
    self.session = {
        start = time(),
        gained = 0,
        lastXP = SafeNum(UnitXP and UnitXP("player") or 0, 0),
        lastMax = SafeNum(UnitXPMax and UnitXPMax("player") or 0, 0),
    }
end

function Mod:UpdateSessionXP()
    if not self.session then
        self:ResetSession()
        return
    end
    local cur = SafeNum(UnitXP and UnitXP("player") or 0, 0)
    local mx  = SafeNum(UnitXPMax and UnitXPMax("player") or 0, 0)
    if mx <= 0 then return end

    local lastXP = self.session.lastXP or cur
    local lastMax = self.session.lastMax or mx
    local gained = 0

    if cur < lastXP then
        gained = (lastMax - lastXP) + cur
    else
        gained = cur - lastXP
    end

    if gained > 0 then
        self.session.gained = (self.session.gained or 0) + gained
    end

    self.session.lastXP = cur
    self.session.lastMax = mx
end

function Mod:OnXPUpdate()
    self:UpdateSessionXP()
    self:UpdateBar()
end

function Mod:GetWatchedReputation()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = C_Reputation.GetWatchedFactionData()
        if data and data.name then
            local minVal = data.reactionThreshold or 0
            local maxVal = data.nextThreshold or 0
            local curVal = data.currentStanding or 0
            return {
                name = data.name,
                min = minVal,
                max = maxVal,
                value = curVal,
            }
        end
    end

    if GetWatchedFactionInfo then
        local name, _, barMin, barMax, barValue = GetWatchedFactionInfo()
        if name then
            return { name = name, min = barMin, max = barMax, value = barValue }
        end
    end

    return nil
end

function Mod:IsHonorActive()
    if C_PvP and C_PvP.IsHonorSystemActive then
        local ok, res = pcall(C_PvP.IsHonorSystemActive)
        if ok then return res end
    end
    local maxHonor = 0
    if UnitHonorMax then
        maxHonor = SafeNum(UnitHonorMax("player"), 0)
    end
    return maxHonor > 0
end

function Mod:IsInInstancedPvP()
    if not IsInInstance then
        return false
    end

    local ok, _, instanceType = pcall(IsInInstance)
    if not ok then
        return false
    end

    return instanceType == "pvp" or instanceType == "arena"
end

function Mod:ShouldAutoTrackHonor()
    return self:IsInInstancedPvP() and self:IsHonorActive()
end

function Mod:GetTrackingMode()
    local mode = (self.db and self.db.mode) or "AUTO"
    if mode == "AUTO" then
        if CanPlayerGainLevels() then
            return "XP"
        end
        if self:ShouldAutoTrackHonor() then
            return "HONOR"
        end
        if self.db and self.db.autoTrackReputation then
            local rep = self:GetWatchedReputation()
            if rep and rep.max and rep.max > rep.min then
                return "REPUTATION"
            end
        end
        return "NONE"
    end
    return mode
end

function Mod:ShowBlizzardBars(show)
    local manager = _G.StatusTrackingBarManager
    local main = _G.MainStatusTrackingBarContainer
    local secondary = _G.SecondaryStatusTrackingBarContainer
    local legacyExperience = _G.MainMenuExpBar

    -- Avoid calling Show/Hide on Blizzard's tracking bar containers.
    -- Those frames are tied into EditMode templates and can trigger protected calls (HideBase)
    -- which results in ADDON_ACTION_BLOCKED / taint, especially around combat or EditMode transitions.
    local a = show and 1 or 0
    self._blizzardAlphaApplying = self._blizzardAlphaApplying or {}
    self._blizzardAlphaHooked = self._blizzardAlphaHooked or {}
    self._blizzardBarsSuppressed = not show

    local function ApplyAlpha(frame)
        if not (frame and frame.SetAlpha) then return end

        if not self._blizzardAlphaHooked[frame] then
            self._blizzardAlphaHooked[frame] = true
            hooksecurefunc(frame, "SetAlpha", function(target)
                if Mod and Mod._blizzardBarsSuppressed
                    and not Mod._blizzardAlphaApplying[target] then
                    Mod._blizzardAlphaApplying[target] = true
                    target:SetAlpha(0)
                    Mod._blizzardAlphaApplying[target] = nil
                end
            end)
        end

        self._blizzardAlphaApplying[frame] = true
        frame:SetAlpha(a)
        self._blizzardAlphaApplying[frame] = nil
    end

    -- Suppress both the manager and its animated containers. The containers'
    -- FadeInAnimation can override their own alpha, but it cannot override the
    -- effective alpha inherited from the manager.
    ApplyAlpha(manager)
    ApplyAlpha(main)
    ApplyAlpha(secondary)
    ApplyAlpha(legacyExperience)
end

function Mod:EnsureFrame()
    if self.frame then return end
    local f = CreateFrame("Frame", "KT_ExperienceBar", UIParent)
    f:SetFrameStrata("BACKGROUND")
    f:SetFrameLevel(10)
    f:SetSize(400, 12)
    f:SetClampedToScreen(true)

    local bg = KT.AddBackdrop and KT:AddBackdrop(f, 0.07, 0.07, 0.07, 0.6)
    f._bg = bg

    local rested = CreateFrame("StatusBar", nil, f)
    rested:SetAllPoints()
    rested:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    rested:SetMinMaxValues(0, 1)
    rested:SetValue(0)
    rested:Hide()

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetAllPoints()
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    text:SetShadowOffset(1, -1)

    f._rested = rested
    f._bar = bar
    f._text = text

    if KT.AddBorder then
        KT:AddBorder(f, 0, 0, 0, 1)
    end

    local EM = KT:GetModule("EditMode", true)
    if EM then
        EM:RegisterFrame(f, "Experience Bar", "experience_bar", {
            resizable = false,
            onDragStop = function()
                if not Mod.db then return end
                local point, _, relativePoint, x, y = f:GetPoint()
                Mod.db.point = point
                Mod.db.relativePoint = relativePoint
                Mod.db.x = x
                Mod.db.y = y
            end,
        })
    end

    self.frame = f
end

function Mod:ApplyLayout()
    if not self.db or not self.frame then return end
    local db = self.db
    local f = self.frame

    local w = db.width or 400
    local h = db.height or 12
    f:SetSize(w, h)

    local point = db.point or "BOTTOM"
    local relativePoint = db.relativePoint or point
    local x = db.x
    local y = db.y
    if type(x) ~= "number" then x = db.xOffset or 0 end
    if type(y) ~= "number" then y = db.yOffset or 0 end

    f:ClearAllPoints()
    f:SetPoint(point, UIParent, relativePoint, x, y)

    local tex = (LSM and db.texture and LSM:Fetch("statusbar", db.texture)) or "Interface\\Buttons\\WHITE8x8"
    f._bar:SetStatusBarTexture(tex)
    f._rested:SetStatusBarTexture(tex)

    local font = (KT and KT.ResolveFontForLocale and KT:ResolveFontForLocale(db.font, "Fonts\\FRIZQT__.TTF"))
        or (LSM and db.font and LSM:Fetch("font", db.font))
        or "Fonts\\FRIZQT__.TTF"
    local size = db.fontSize or 12
    local outline = db.fontOutline or "OUTLINE"
    f._text:SetFont(font, size, outline)
end

function Mod:Refresh()
    if not self.db then self:OnInitialize() end
    self:EnsureFrame()
    self:ApplyLayout()
    self:UpdateBar()
end

function Mod:UpdateBar()
    if not self.db or not self.frame then return end
    local db = self.db

    local mode = self:GetTrackingMode()
    local barActive = (db.enable ~= false) and (db.visible ~= false)

    if mode == "NONE" then
        barActive = false
    end

    if mode == "XP" and not CanPlayerGainLevels() then
        barActive = false
    end

    if mode == "XP" and db.disableAtMaxLevel and IsMaxLevel() then
        barActive = false
    end

    -- Never show Blizzard bars; this module owns the status bars.
    self:ShowBlizzardBars(false)

    if not barActive then
        self.frame:Hide()
        return
    end

    self.frame:Show()
    self:ApplyLayout()

    local bar = self.frame._bar
    local rested = self.frame._rested
    local text = self.frame._text

    local showText = db.showText
    if showText then text:Show() else text:Hide() end

    if mode == "XP" then
        local cur = SafeNum(UnitXP and UnitXP("player") or 0, 0)
        local mx = SafeNum(UnitXPMax and UnitXPMax("player") or 0, 0)
        if mx <= 0 then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            rested:Hide()
            if showText then text:SetText("") end
            return
        end
        bar:SetMinMaxValues(0, mx)
        bar:SetValue(cur)
        local c = db.xpColor or { r = 0.33, g = 0.38, b = 1, a = 1 }
        bar:SetStatusBarColor(c.r, c.g, c.b, c.a)

        local rest = SafeNum(GetXPExhaustion and GetXPExhaustion() or 0, 0)
        if rest > 0 then
            local rc = db.restedColor or { r = 1, g = 0.2, b = 1, a = 0.5 }
            rested:SetStatusBarColor(rc.r, rc.g, rc.b, rc.a)
            rested:SetMinMaxValues(0, mx)
            rested:SetValue(min(mx, cur + rest))
            rested:Show()
        else
            rested:Hide()
        end

        if showText then
            local pct = mx > 0 and floor((cur / mx) * 100 + 0.5) or 0
            local level = UnitLevel and UnitLevel("player") or 0
            local base = string.format("%s %d | %s: %s / %s (%d%%)", _G.LEVEL or "Level", level, _G.XP or "XP", FormatCur(cur), FormatCur(mx), pct)
            if db.showSessionData and self.session then
                local elapsed = max(time() - (self.session.start or time()), 1)
                local gained = self.session.gained or 0
                local perHour = (elapsed > 0) and (gained / elapsed * 3600) or 0
                if gained > 0 and perHour > 0 then
                    local toLevel = max(mx - cur, 0)
                    local eta = (perHour > 0) and FormatTime((toLevel / perHour) * 3600) or "--"
                    base = string.format("%s | %s/hr | %s", base, FormatCur(perHour), eta)
                end
            end
            text:SetText(base)
        end
        return
    end

    if mode == "HONOR" then
        local cur = SafeNum(UnitHonor and UnitHonor("player") or 0, 0)
        local mx = SafeNum(UnitHonorMax and UnitHonorMax("player") or 0, 0)
        if mx <= 0 then
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
            rested:Hide()
            if showText then text:SetText("") end
            return
        end
        bar:SetMinMaxValues(0, mx)
        bar:SetValue(cur)
        local c = db.honorColor or { r = 1, g = 0.2, b = 0.2, a = 1 }
        bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
        rested:Hide()

        if showText then
            local pct = mx > 0 and floor((cur / mx) * 100 + 0.5) or 0
            text:SetText(string.format("%s: %s / %s (%d%%)", _G.HONOR or "Honor", FormatCur(cur), FormatCur(mx), pct))
        end
        return
    end

    -- Reputation
    local rep = self:GetWatchedReputation()
    if not rep or not rep.max or rep.max <= rep.min then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        rested:Hide()
        if showText then text:SetText("") end
        return
    end

    local cur = SafeNum(rep.value, 0) - SafeNum(rep.min, 0)
    local mx = SafeNum(rep.max, 0) - SafeNum(rep.min, 0)
    if mx <= 0 then mx = 1 end
    bar:SetMinMaxValues(0, mx)
    bar:SetValue(cur)
    local c = db.repColor or { r = 0, g = 0.8, b = 0, a = 1 }
    bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
    rested:Hide()

    if showText then
        local pct = mx > 0 and floor((cur / mx) * 100 + 0.5) or 0
        text:SetText(string.format("%s: %s %s / %s (%d%%)", _G.REPUTATION or "Reputation", rep.name or "", FormatCur(cur), FormatCur(mx), pct))
    end
end
