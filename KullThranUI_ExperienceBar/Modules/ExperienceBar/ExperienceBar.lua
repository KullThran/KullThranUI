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

-- Until it is moved in Unlock Mode the bar takes the place of Blizzard's status
-- tracking bar (MainStatusTrackingBarContainer). Retail's Edit Mode keeps it at the
-- bottom of the screen under Action Bar 1, with the secondary container stacked
-- right over it when Blizzard shows two bars, and moves both wherever the player
-- drags them. Blizzard's bars there are only made transparent, so the slot keeps
-- its room. Without that slot (Blizzard shows no bar) it falls back to the spot
-- above Bars 2 and 3:
--   side by side (the default row over Bar 1): centred where Bar 2 meets Bar 3;
--   stacked: over Bar 2, under Bar 3; Bar 2 off: over Bar 1.
local ACTION_BAR_GAP = 6
local pairSpan, slotSpan

-- The bar's rim (3 px a side) stays inside each Blizzard row: Retail stacks the
-- two containers with no room between them.
local SLOT_RIM = 3
-- Most room Edit Mode may leave between the two containers to count as one slot.
local SLOT_SPACER = 5
-- Room kept at each end for the rim and the studs of the Forever style.
local SLOT_INSET = 10
-- Text above or below a bar: the gap the styles keep (TEXT_GAP in the styles).
local TEXT_GAP = 5

-- A frame's edge or size as a plain number; nil when unset or secret.
local function Geo(frame, method)
    local fn = frame and frame[method]
    if type(fn) ~= "function" then return nil end
    local v = fn(frame)
    if IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function Shown(frame)
    return frame and frame.IsShown and frame:IsShown() and Geo(frame, "GetLeft") ~= nil
end

-- The status bar slot, or nil when Blizzard is not showing a container there:
-- a span over its rows, its width and height, the height of one row, the top row
-- and, when Blizzard keeps two rows, the bottom one.
local function StatusBarSlot()
    local main = _G.MainStatusTrackingBarContainer
    local w, rowH = Geo(main, "GetWidth"), Geo(main, "GetHeight")
    if not (Shown(main) and w and rowH and w > 0 and rowH > 0) then
        return nil
    end
    local top, bottom = main, main
    local secondary = _G.SecondaryStatusTrackingBarContainer
    if Shown(secondary) then
        local mTop, mBottom, mLeft = Geo(main, "GetTop"), Geo(main, "GetBottom"), Geo(main, "GetLeft")
        local sTop, sBottom, sLeft = Geo(secondary, "GetTop"), Geo(secondary, "GetBottom"), Geo(secondary, "GetLeft")
        -- Only when Edit Mode stacked it right over the main one (the default) or under it.
        if mTop and mBottom and mLeft and sTop and sBottom and sLeft and math.abs(sLeft - mLeft) <= 1 then
            if math.abs(sBottom - mTop) <= SLOT_SPACER then
                top = secondary
            elseif math.abs(sTop - mBottom) <= SLOT_SPACER then
                bottom = secondary
            end
        end
    end
    local slotTop, slotBottom = Geo(top, "GetTop"), Geo(bottom, "GetBottom")
    if not (slotTop and slotBottom) then return nil end
    slotSpan = slotSpan or CreateFrame("Frame", nil, UIParent)
    slotSpan:ClearAllPoints()
    slotSpan:SetPoint("BOTTOMLEFT", bottom, "BOTTOMLEFT", 0, 0)
    slotSpan:SetPoint("TOPRIGHT", top, "TOPRIGHT", 0, 0)
    return slotSpan, w, slotTop - slotBottom, rowH, top, bottom ~= top and bottom or nil
end

-- Room from the bottom of `row` up to Action Bar 1 (the bottom of its border art
-- when that is drawn), in UIParent units. Nil when Bar 1 is not right over the
-- slot (moved elsewhere in Edit Mode).
local function RoomUnderMainBar(row, slotH)
    local bar = _G.MainActionBar or _G.MainMenuBar
    local rowBottom = Geo(row, "GetBottom")
    if not (Shown(bar) and rowBottom) then return nil end
    local region = bar
    local art = bar.BorderArt
    if art and art.IsVisible and art:IsVisible() and (Geo(art, "GetAlpha") or 0) > 0 and Geo(art, "GetBottom") then
        region = art
    end
    local bottom, regionScale = Geo(region, "GetBottom"), Geo(region, "GetEffectiveScale")
    local scale = Geo(UIParent, "GetEffectiveScale")
    if not (bottom and regionScale and scale and scale > 0) then return nil end
    local room = bottom * regionScale / scale - rowBottom
    if room < (slotH or 0) or room > 120 then return nil end
    return room
end

-- The profile default of `key` (Modules/Defaults): a value still at its default
-- means "not chosen", and the slot sizes the bar.
local function ProfileDefault(key)
    local defaults = KT.db and KT.db.defaults
    local xp = defaults and defaults.profile and defaults.profile.experienceBar
    return xp and xp[key]
end

local function ChosenSize(db, key)
    local v = tonumber(db[key])
    if v and v > 0 and v ~= ProfileDefault(key) then return v end
    return nil
end

-- Height the text takes on `side` ("ABOVE" / "BELOW") of a bar, or 0.
local function TextRoom(db, side)
    if db.showText == false or db.textPosition ~= side then return 0 end
    return (tonumber(db.fontSize) or 12) + TEXT_GAP
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
    -- Second bar: reputation or honor, above or below the main bar.
    secondBar = false,
    secondMode = "REPUTATION",
    secondPosition = "ABOVE",
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
    -- The XP gained across a level is counted by PLAYER_XP_UPDATE (UpdateSessionXP).
    self:RegisterEvent("PLAYER_LEVEL_UP", "UpdateBar")
    self:RegisterEvent("UPDATE_EXHAUSTION", "UpdateBar")
    self:RegisterEvent("UPDATE_FACTION", "UpdateBar")
    self:RegisterEvent("HONOR_XP_UPDATE", "UpdateBar")
    self:RegisterEvent("PLAYER_PVP_KILLS_CHANGED", "UpdateBar")
    self:RegisterEvent("ENABLE_XP_GAIN", "UpdateBar")
    self:RegisterEvent("DISABLE_XP_GAIN", "UpdateBar")
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("MAJOR_FACTION_RENOWN_LEVEL_CHANGED") then
        self:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "UpdateBar")
    end
    self:HookStatusBarSlot()

    self:Refresh()
end

function Mod:OnDisable()
    -- Give the XP/reputation bar back to Blizzard when the module is disabled.
    self:ShowBlizzardBars(true)
    if self.frame then
        self.frame:Hide()
    end
    if self.frame2 then
        self.frame2:Hide()
    end
end

-- The session (XP per hour) runs from login or reload, not from each loading screen.
function Mod:OnEnterWorld(_, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        self:ResetSession()
    end
    self:UpdateBar()
end

-- The slot appears, moves or resizes with Blizzard's bars and Edit Mode: lay the bar
-- out again whenever it does. HookScript leaves Blizzard's frames untainted.
function Mod:HookStatusBarSlot()
    if self._slotHooked then return end
    local function Relayout()
        if Mod.frame then Mod:ApplyLayout() end
    end
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local container = _G[name]
        if container and container.HookScript then
            container:HookScript("OnShow", Relayout)
            container:HookScript("OnHide", Relayout)
            container:HookScript("OnSizeChanged", Relayout)
            self._slotHooked = true
        end
    end
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

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
    return nil
end

-- The watched faction as the bar draws it, the way Blizzard's reputation bar reads
-- it: min / max / value of the current step, its label and the reaction for the
-- color. Paragon, renown and friendship factions use their own progress; a faction
-- at its last step is `capped` (a full bar with no numbers).
function Mod:GetWatchedReputation()
    local R = C_Reputation
    local data = R and Call(R.GetWatchedFactionData)
    if type(data) == "table" and type(data.name) == "string" and data.name ~= "" then
        local id = data.factionID
        local reaction = data.reaction
        local lo = data.currentReactionThreshold or data.reactionThreshold or 0
        local hi = data.nextReactionThreshold or data.nextThreshold or 0
        local value = data.currentStanding or 0
        local label = reaction and _G["FACTION_STANDING_LABEL" .. reaction]
        local capped = false

        if id and id ~= 0 then
            local friendship = C_GossipInfo and Call(C_GossipInfo.GetFriendshipReputation, id)
            if Call(R.IsFactionParagonForCurrentPlayer or R.IsFactionParagon, id) then
                local cur, threshold, _, pending = Call(R.GetFactionParagonInfo, id)
                if type(cur) == "number" and type(threshold) == "number" and threshold > 0 then
                    lo, hi = 0, threshold
                    value = pending and threshold or (cur % threshold)
                end
            elseif Call(R.IsMajorFaction, id) and C_MajorFactions then
                local major = Call(C_MajorFactions.GetMajorFactionData, id)
                if type(major) == "table" then
                    lo, hi = 0, major.renownLevelThreshold or 0
                    value = major.renownReputationEarned or value
                    if major.renownLevel and _G.RENOWN_LEVEL_LABEL then
                        local ok, text = pcall(string.format, _G.RENOWN_LEVEL_LABEL, major.renownLevel)
                        if ok then label = text end
                    end
                    if Call(C_MajorFactions.HasMaximumRenown, id) then capped = true end
                end
                reaction = nil
            elseif type(friendship) == "table" and (friendship.friendshipFactionID or 0) > 0 then
                if type(friendship.reaction) == "string" and friendship.reaction ~= "" then
                    label = friendship.reaction
                end
                if friendship.nextThreshold then
                    lo, hi, value = friendship.reactionThreshold or 0, friendship.nextThreshold, friendship.standing or 0
                else
                    capped = true
                end
                reaction = 5  -- friendships always wear the same color, as in Blizzard's bar
            end
        end

        lo, hi, value = SafeNum(lo, 0), SafeNum(hi, 0), SafeNum(value, 0)
        if capped or hi <= lo then
            lo, hi, value, capped = 0, 1, 1, true
        end
        return { name = data.name, min = lo, max = hi, value = value,
            reaction = reaction, label = label, capped = capped }
    end

    -- Clients without C_Reputation.GetWatchedFactionData.
    if GetWatchedFactionInfo then
        local name, reaction, barMin, barMax, barValue = GetWatchedFactionInfo()
        if name and name ~= "" then
            local lo, hi, value = SafeNum(barMin, 0), SafeNum(barMax, 0), SafeNum(barValue, 0)
            local capped = hi <= lo
            if capped then lo, hi, value = 0, 1, 1 end
            return { name = name, min = lo, max = hi, value = value, reaction = reaction,
                label = reaction and _G["FACTION_STANDING_LABEL" .. reaction], capped = capped }
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
    if mode == "REP" then mode = "REPUTATION" end
    if mode == "AUTO" then
        if CanPlayerGainLevels() then
            return "XP"
        end
        if self:ShouldAutoTrackHonor() then
            return "HONOR"
        end
        if self.db and self.db.autoTrackReputation then
            local rep = self:GetWatchedReputation()
            if rep then
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

    -- The second bar (reputation or honor): the same art, size and text. It has no
    -- place of its own: it keeps next to the main bar (ApplyLayout).
    local f2 = Styles:Build(UIParent, "KT_ExperienceBar2")
    f2:SetFrameStrata(f:GetFrameStrata())
    f2:SetFrameLevel(10)
    f2:SetSize(400, 12)
    f2:SetClampedToScreen(true)
    f2._rested:SetFrameLevel(11)
    f2._bar:SetFrameLevel(12)
    f2._flow:SetFrameLevel(13)
    f2._art:SetFrameLevel(15)
    f2._text:GetParent():SetFrameLevel(17)
    f2:Hide()
    self.frame2 = f2

    -- KUI Unlock Mode. Until it is dragged there, the bar sits in Blizzard's status
    -- bar slot (ApplyLayout); a drag saved in Unlock Mode places it freely, and
    -- resetting it there puts it back in the slot.
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
                -- In the slot or by the action bars: where it is on screen now, in UIParent units.
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
                -- made while it is open (a drag) frees the bar from the status bar slot.
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

-- Room between the main bar and the second one: both rims, plus the text when it
-- sits outside the bars (it would land between them).
local STACK_RIM_GAP = 8

local function StackGap(db)
    local gap = STACK_RIM_GAP
    if db.showText ~= false and (db.textPosition == "ABOVE" or db.textPosition == "BELOW") then
        gap = gap + (tonumber(db.fontSize) or 12) + 4
    end
    return gap
end

local function EdgeY(frame, edge)
    if not (frame and frame.GetTop) then return nil end
    if edge == "BOTTOM" then return frame:GetBottom() end
    return frame:GetTop()
end

-- The bottom action bar stacked right over the spot the bars sit on (Edit Mode's
-- stacked layout puts Bar 3 over Bar 2), or nil: the bars must not run into it.
local function BarAbove(anchor, edge)
    local y = EdgeY(anchor, edge)
    local left, right = anchor and anchor:GetLeft(), anchor and anchor:GetRight()
    if not (y and left and right) then return nil end
    local best
    for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight" }) do
        local bar = _G[name]
        if Shown(bar) and bar ~= anchor and bar:GetBottom() and bar:GetBottom() >= y - 1
            and bar:GetLeft() < right and bar:GetRight() > left
            and (not best or bar:GetBottom() < best:GetBottom()) then
            best = bar
        end
    end
    return best
end

-- Above the action bars: `lower` on them, `upper` (if any) on `lower`. When a bar
-- stacked above leaves no room for both, `upper` goes over that bar instead, so
-- neither covers a button.
local function PlaceStack(lower, upper, db)
    local anchor, edge = AnchorBar()
    lower:SetPoint("BOTTOM", anchor, edge, 0, ACTION_BAR_GAP)
    if not upper then return end
    local gap = StackGap(db)
    local base = EdgeY(anchor, edge)
    local blocker = BarAbove(anchor, edge)
    if base and blocker then
        local need = ACTION_BAR_GAP + lower:GetHeight() + gap + upper:GetHeight() + ACTION_BAR_GAP
        if blocker:GetBottom() - base < need then
            upper:SetPoint("BOTTOM", blocker, "TOP", 0, ACTION_BAR_GAP)
            return
        end
    end
    upper:SetPoint("BOTTOM", lower, "TOP", 0, gap)
end

function Mod:ApplyLayout()
    if not self:SyncDB() or not self.frame then return end
    local db = self.db
    local f = self.frame
    local f2 = self.frame2

    -- The bars on screen, bottom to top: the main one, plus the second one above or
    -- below it (UpdateBar decides which are shown). The second one alone takes the
    -- main one's place.
    local mainOn = self._mainShown ~= false
    local second = f2 and self._secondMode and f2 or nil
    local lower, upper = mainOn and f or second or f, nil
    if mainOn and second then
        if db.secondPosition == "BELOW" then
            lower, upper = second, f
        else
            upper = second
        end
    end

    local w = db.width or 400
    local h = db.height or 12
    f:SetSize(w, h)
    if f2 then f2:SetSize(w, h) end
    -- Classic keeps its stock 1024 x 13 unless the slot below gives it a row to fill.
    local classic = Styles:Resolve(db) == "classic"
    f._ktClassicWidth = nil
    if f2 then f2._ktClassicWidth = nil end

    local point = db.point or "BOTTOM"
    local relativePoint = db.relativePoint or point
    local x = db.x
    local y = db.y
    if type(x) ~= "number" then x = db.xOffset or 0 end
    if type(y) ~= "number" then y = db.yOffset or 0 end

    f:ClearAllPoints()
    if f2 then f2:ClearAllPoints() end
    if db.unlockMoved then
        -- Moved in Unlock Mode: the main bar where it was dropped (the second one there
        -- while the main one is hidden), the second one next to it.
        local placed = mainOn and f or lower
        placed:SetPoint(point, UIParent, relativePoint, x, y)
        if upper then
            if db.secondPosition == "BELOW" then
                second:SetPoint("TOP", f, "BOTTOM", 0, -StackGap(db))
            else
                second:SetPoint("BOTTOM", f, "TOP", 0, StackGap(db))
            end
        end
    else
        local slot, slotW, slotH, rowH, topRow, bottomRow = StatusBarSlot()
        if slot then
            -- In the status bar slot: as long as the slot and as tall as one Blizzard
            -- bar unless a Width / Height was chosen (Classic keeps its stock height
            -- and fills the slot's length).
            local maxW = max(50, floor(slotW - SLOT_INSET * 2))
            w = min(ChosenSize(db, "width") or maxW, maxW)
            if classic then
                -- The stock Classic bar runs the whole row: its strips carry their
                -- own rails and need no room at the ends.
                f._ktClassicWidth = floor(slotW)
                if f2 then f2._ktClassicWidth = floor(slotW) end
            end
            -- One Blizzard row tall with the rim inside it (Blizzard's own bar is 11 px).
            local rowFill = max(4, floor(rowH - SLOT_RIM * 2))
            local textOut = TextRoom(db, "ABOVE") + TextRoom(db, "BELOW") > 0
            if upper and bottomRow and not textOut then
                -- Blizzard keeps two rows there: one bar in each.
                local between = max(0, (Geo(topRow, "GetBottom") or 0) - (Geo(bottomRow, "GetTop") or 0))
                h = min(ChosenSize(db, "height") or rowFill, max(4, floor(rowH + between - SLOT_RIM * 2)))
                lower:SetSize(w, h)
                upper:SetSize(w, h)
                lower:SetPoint("CENTER", bottomRow, "CENTER", 0, 0)
                upper:SetPoint("CENTER", topRow, "CENTER", 0, 0)
            else
                -- One bar on the lowest row, its rim on the row's bottom edge (Classic,
                -- rimless, right on it), raised when its text below would leave the screen.
                local lowest = bottomRow or topRow
                local base = classic and 0 or SLOT_RIM
                local below = TextRoom(db, "BELOW")
                local rowBottom = Geo(lowest, "GetBottom") or 0
                if below > 0 and rowBottom + base < below then
                    base = below - rowBottom
                end
                -- Taller only as far as Bar 1 (and the text above the bar) leaves room.
                local room = RoomUnderMainBar(lowest, slotH)
                local cap = room and floor(room - base - SLOT_RIM - 2 - TextRoom(db, "ABOVE"))
                    or floor(slotH - SLOT_RIM * 2)
                h = min(ChosenSize(db, "height") or rowFill, max(4, cap))
                lower:SetSize(w, h)
                lower:SetPoint("BOTTOM", lowest, "BOTTOM", 0, base)
                if upper then
                    -- The other bar over this one while both fit under Bar 1, else
                    -- over the action bars, clear of every button.
                    upper:SetSize(w, h)
                    local gap = StackGap(db)
                    local need = base + h + gap + h + SLOT_RIM + TextRoom(db, "ABOVE")
                    if not room or need <= room then
                        upper:SetPoint("BOTTOM", lower, "TOP", 0, gap)
                    else
                        PlaceStack(upper, nil, db)
                    end
                end
            end
        else
            -- Follows the action bars when Edit Mode moves or resizes them.
            PlaceStack(lower, upper, db)
        end
    end

    -- Chrome and fill art of the style in use for the applied Visual Style.
    local font = (KT and KT.ResolveFontForLocale and KT:ResolveFontForLocale(db.font, "Fonts\\FRIZQT__.TTF"))
        or (LSM and db.font and LSM:Fetch("font", db.font))
        or "Fonts\\FRIZQT__.TTF"
    local size = db.fontSize or 12
    local outline = db.fontOutline or "OUTLINE"
    for _, frame in ipairs({ f, f2 or false }) do
        if frame then
            Styles:Apply(frame, db)
            frame._text:SetFont(font, size, outline)
        end
    end
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

    -- The second bar shows with the module, also while the main one is hidden.
    local moduleOn = db.enable ~= false and db.visible ~= false
    local secondMode = moduleOn and self:GetSecondTrackingMode(barActive and mode or nil) or nil
    self._mainShown = barActive
    self._secondMode = secondMode
    if self.frame2 then self.frame2:SetShown(secondMode ~= nil) end

    if not barActive then
        self.frame:Hide()
        if secondMode then
            self:ApplyLayout()
            self:RenderBar(self.frame2, secondMode)
        end
        return
    end

    self.frame:Show()
    self:ApplyLayout()
    if secondMode then self:RenderBar(self.frame2, secondMode) end
    self:RenderBar(self.frame, mode)
end

-- The second bar's mode, or nil while it is off or would repeat the main bar.
function Mod:GetSecondTrackingMode(mainMode)
    local db = self.db
    if not (db and db.secondBar == true) then return nil end
    local mode = db.secondMode == "HONOR" and "HONOR" or "REPUTATION"
    if mainMode == mode then return nil end
    return mode
end

-- Fills `frame` (the main bar or the second one) for `mode`: XP, HONOR or REPUTATION.
function Mod:RenderBar(frame, mode)
    local db = self.db
    local bar = frame._bar
    local rested = frame._rested
    local text = frame._text

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
        Styles:SetFill(frame, db, "xp", rest > 0)
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
        Styles:SetFill(frame, db, "honor")
        rested:SetValue(0)

        if showText then
            local pct = mx > 0 and floor((cur / mx) * 100 + 0.5) or 0
            text:SetText(string.format("%s: %s / %s (%d%%)", _G.HONOR or "Honor", FormatCur(cur), FormatCur(mx), pct))
        end
        return
    end

    -- Reputation: the faction marked "Show as Experience Bar" in the reputation panel.
    local rep = self:GetWatchedReputation()
    if not rep then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        rested:SetValue(0)
        Styles:SetFill(frame, db, "rep")
        if showText then
            text:SetText(string.format("%s: %s", _G.REPUTATION or "Reputation", _G.NONE or "None"))
        end
        return
    end

    local cur = rep.value - rep.min
    local mx = rep.max - rep.min
    if mx <= 0 then mx = 1 end
    cur = max(0, min(cur, mx))
    bar:SetMinMaxValues(0, mx)
    bar:SetValue(cur)
    Styles:SetFill(frame, db, "rep", false, tonumber(rep.reaction))
    rested:SetValue(0)

    if showText then
        local title = rep.name
        if rep.label and rep.label ~= "" then
            title = string.format("%s | %s", rep.name, rep.label)
        end
        if rep.capped then
            text:SetText(title)
        else
            local pct = floor((cur / mx) * 100 + 0.5)
            text:SetText(string.format("%s: %s / %s (%d%%)", title, FormatCur(cur), FormatCur(mx), pct))
        end
    end
end
