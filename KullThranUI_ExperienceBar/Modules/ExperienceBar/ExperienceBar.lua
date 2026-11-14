local ADDON_NAME, ns = ...
local KT = _G.KT

local Mod = KT:NewModule("ExperienceBar", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)
local Styles = KT.ExperienceBarStyles

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

local DEFAULT_EXPERIENCE_BAR_POINT = "BOTTOM"
local DEFAULT_EXPERIENCE_BAR_Y = 8

-- Until it is moved in Unlock Mode the bar sits between Action Bars 2 and 3, this
-- far above them (Edit Mode sizes each bar to its buttons):
--   side by side (the default row over Bar 1): centred where Bar 2 meets Bar 3;
--   stacked: over Bar 2, under Bar 3; Bar 2 off: over Bar 1.
local ACTION_BAR_GAP = 6
local pairSpan

local function Shown(frame)
    return frame and frame.IsShown and frame:IsShown() and frame:GetLeft() ~= nil
end

local function AnchorBar()
    local bar2, bar3 = _G.MultiBarBottomLeft, _G.MultiBarBottomRight
    if Shown(bar2) and Shown(bar3) and bar3:GetLeft() >= bar2:GetRight() - 1 then
        -- One frame spanning both bars along their top edge: its centre is the joint.
        pairSpan = pairSpan or CreateFrame("Frame", nil, UIParent)
        pairSpan:ClearAllPoints()
        pairSpan:SetPoint("BOTTOMLEFT", bar2, "TOPLEFT", 0, 0)
        pairSpan:SetPoint("BOTTOMRIGHT", bar3, "TOPRIGHT", 0, 0)
        pairSpan:SetHeight(1)
        return pairSpan, "BOTTOM"
    end
    if bar2 and bar2:IsShown() then return bar2, "TOP" end
    return _G.MainActionBar or _G.MainMenuBar, "TOP"
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
    textPosition = "ABOVE",
    showSessionData = false,
    animate = true,
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

        -- The text sits above the bar by default; earlier builds stored INSIDE for everyone.
        if not self.db._textAboveDefault20261109 then
            self.db.textPosition = "ABOVE"
            self.db._textAboveDefault20261109 = true
        end

        -- Migrate legacy profiles that were left pinned to HONOR by default.
        if not self.db._defaultTrackingModeMigrated_v1 then
            if self.db.mode == "HONOR" then
                self.db.mode = "AUTO"
            end
            self.db._defaultTrackingModeMigrated_v1 = true
        end

        -- The old default overlapped the action bars. A bar moved by hand keeps its place.
        if not self.db._defaultPositionMigrated_v1 then
            if self.db.point == "BOTTOM" and self.db.y == 70 then
                self.db.y = 8
            end
            self.db._defaultPositionMigrated_v1 = true
        end
    end
end

function Mod:OnEnable()
    if not self.db then self:OnInitialize() end
    self:EnsureFrame()
    self:ResetSession()
    -- Blizzard's bars are only replaced while this module is enabled.
    self:ShowBlizzardBars(self.db.enable == false)

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
    -- Give the XP/reputation bar back to Blizzard when the module is disabled.
    self:ShowBlizzardBars(true)
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
                reaction = data.reaction,
            }
        end
    end

    if GetWatchedFactionInfo then
        local name, reaction, barMin, barMax, barValue = GetWatchedFactionInfo()
        if name then
            return { name = name, min = barMin, max = barMax, value = barValue, reaction = reaction }
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
    -- Bar, rested overlay, text and the art of every style (ExperienceBar_Styles.lua).
    local f = Styles:Build(UIParent, "KT_ExperienceBar")
    f:SetFrameStrata("BACKGROUND")
    f:SetFrameLevel(10)
    f:SetSize(400, 12)
    f:SetClampedToScreen(true)
    -- Build() stacked its children from the default level; restack them above 10.
    f._rested:SetFrameLevel(11)
    f._bar:SetFrameLevel(12)
    f._flow:SetFrameLevel(13)
    f._art:SetFrameLevel(15)
    f._text:GetParent():SetFrameLevel(17)

    self.frame = f

    -- KUI Unlock Mode. Until it is dragged there, the bar sits between Action Bars 2
    -- and 3 (ApplyLayout); a drag saved in Unlock Mode places it freely, and
    -- resetting it there puts it back between the bars.
    if KT.RegisterUnlockElement then
        KT.RegisterUnlockElement("experience_bar", {
            label = "Experience Bar",
            group = "Progress Bars",
            -- Open Configuration: the Experience Bar page, not the group's (Progress Bars).
            optionsPage = "expbar",
            order = 25,
            getFrame = function()
                return f
            end,
            getSize = function()
                return f:GetWidth(), f:GetHeight()
            end,
            getScale = function()
                return f:GetScale()
            end,
            setScale = function(_, scale)
                if scale and f.SetScale then
                    f:SetScale(scale)
                end
            end,
            isHidden = function()
                return false
            end,
            loadPosition = function()
                local db = Mod.db
                if db and db.unlockMoved and db.point then
                    return {
                        point = db.point,
                        relativePoint = db.relativePoint or db.point,
                        x = tonumber(db.x) or 0,
                        y = tonumber(db.y) or 0,
                        scale = f:GetScale() or 1,
                    }
                end
                -- Between the action bars: where it is on screen now, in UIParent units.
                local left, bottom = f:GetLeft(), f:GetBottom()
                if left and bottom then
                    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
                    return {
                        point = "BOTTOMLEFT",
                        relativePoint = "BOTTOMLEFT",
                        x = left * k,
                        y = bottom * k,
                        scale = f:GetScale() or 1,
                    }
                end
                return {
                    point = DEFAULT_EXPERIENCE_BAR_POINT,
                    relativePoint = DEFAULT_EXPERIENCE_BAR_POINT,
                    x = 0,
                    y = DEFAULT_EXPERIENCE_BAR_Y,
                    scale = f:GetScale() or 1,
                }
            end,
            savePosition = function(_, point, relativePoint, x, y, scale)
                if not Mod.db then return end
                -- Unlock Mode also replays stored positions at login: only a save
                -- made while it is open (a drag) frees the bar from the action bars.
                local UM = KT.GetModule and KT:GetModule("UnlockMode", true)
                if UM and UM.isOpen then
                    Mod.db.unlockMoved = true
                end
                Mod.db.point = point or DEFAULT_EXPERIENCE_BAR_POINT
                Mod.db.relativePoint = relativePoint or Mod.db.point
                Mod.db.x = tonumber(x) or 0
                Mod.db.y = tonumber(y) or 0
                if scale and f.SetScale then
                    f:SetScale(scale)
                end
                Mod:ApplyLayout()
            end,
            applyPosition = function()
                Mod:ApplyLayout()
            end,
            resetPosition = function()
                if not Mod.db then return false end
                Mod.db.unlockMoved = nil
                Mod:ApplyLayout()
                return true
            end,
        })
    end
end

-- The profile can change after OnInitialize (per-character profiles, a copy or a
-- reset): always use the table the options page edits, not the first one seen.
function Mod:SyncDB()
    local profile = KT.db and KT.db.profile
    if profile and (not self.db or profile.experienceBar ~= self.db) then
        self:OnInitialize()
    end
    return self.db
end

function Mod:ApplyLayout()
    if not self:SyncDB() or not self.frame then return end
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
    local anchor, edge
    if not db.unlockMoved then anchor, edge = AnchorBar() end
    if anchor then
        -- Follows the action bars when Edit Mode moves or resizes them.
        f:SetPoint("BOTTOM", anchor, edge, 0, ACTION_BAR_GAP)
    else
        -- Moved in Unlock Mode: where it was dropped.
        f:SetPoint(point, UIParent, relativePoint, x, y)
    end

    -- Chrome and fill art of the style in use for the applied Visual Style.
    Styles:Apply(f, db)

    local font = (KT and KT.ResolveFontForLocale and KT:ResolveFontForLocale(db.font, "Fonts\\FRIZQT__.TTF"))
        or (LSM and db.font and LSM:Fetch("font", db.font))
        or "Fonts\\FRIZQT__.TTF"
    local size = db.fontSize or 12
    local outline = db.fontOutline or "OUTLINE"
    f._text:SetFont(font, size, outline)
end

function Mod:Refresh()
    self:SyncDB()
    self:EnsureFrame()
    self:ApplyLayout()
    self:UpdateBar()
end

function Mod:UpdateBar()
    if not self:SyncDB() or not self.frame then return end
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

    -- This module owns the status bars only while it is enabled.
    self:ShowBlizzardBars(db.enable == false)

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
            rested:SetValue(0)
            if showText then text:SetText("") end
            return
        end
        bar:SetMinMaxValues(0, mx)
        bar:SetValue(cur)

        local rest = SafeNum(GetXPExhaustion and GetXPExhaustion() or 0, 0)
        Styles:SetFill(self.frame, db, "xp", rest > 0)
        if rest > 0 then
            rested:SetMinMaxValues(0, mx)
            rested:SetValue(min(mx, cur + rest))
            rested:Show()
        else
            rested:SetValue(0)
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
            rested:SetValue(0)
            if showText then text:SetText("") end
            return
        end
        bar:SetMinMaxValues(0, mx)
        bar:SetValue(cur)
        Styles:SetFill(self.frame, db, "honor")
        rested:SetValue(0)

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
        rested:SetValue(0)
        if showText then text:SetText("") end
        return
    end

    local cur = SafeNum(rep.value, 0) - SafeNum(rep.min, 0)
    local mx = SafeNum(rep.max, 0) - SafeNum(rep.min, 0)
    if mx <= 0 then mx = 1 end
    bar:SetMinMaxValues(0, mx)
    bar:SetValue(cur)
    Styles:SetFill(self.frame, db, "rep", false, tonumber(rep.reaction))
    rested:SetValue(0)

    if showText then
        local pct = mx > 0 and floor((cur / mx) * 100 + 0.5) or 0
        text:SetText(string.format("%s: %s %s / %s (%d%%)", _G.REPUTATION or "Reputation", rep.name or "", FormatCur(cur), FormatCur(mx), pct))
    end
end
