local _, ns = ...
local KT = _G.KT
local Mod = KT:NewModule("BlizzardFrames", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

local _G = _G
local hooksecurefunc = _G.hooksecurefunc
local InCombatLockdown = _G.InCombatLockdown
local CreateFrame = _G.CreateFrame
local SetPortraitTexture = _G.SetPortraitTexture
local next = next
local issecretvalue = _G.issecretvalue

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local SafeIsMouseOver

local function IsAnyChildMouseOver(...)
    for i = 1, select("#", ...) do
        if SafeIsMouseOver((select(i, ...))) then return true end
    end
    return false
end

SafeIsMouseOver = function(frame)
    if not frame then return false end

    if frame.IsMouseOver then
        local over = frame:IsMouseOver()
        if not IsSecret(over) and over then return true end
    end

    if _G.MouseIsOver then
        local over = _G.MouseIsOver(frame)
        if not IsSecret(over) and over then return true end
    end

    if frame.GetChildren then
        if IsAnyChildMouseOver(frame:GetChildren()) then return true end
    end

    local focus = GetMouseFocus and GetMouseFocus() or nil
    if not focus then return false end
    if focus == frame then return true end

    if not focus.GetParent then return false end
    local success, parent = pcall(focus.GetParent, focus)
    if not success then return false end

    while parent do
        if parent == frame then return true end
        if not parent.GetParent then break end
        success, parent = pcall(parent.GetParent, parent)
        if not success then break end
    end

    return false
end

local function SafeSetAlpha(frame, target)
    if not (frame and frame.SetAlpha) then return end
    local alpha = frame.GetAlpha and frame:GetAlpha()
    if IsSecret(alpha) or type(alpha) ~= "number" then return end
    if math.abs(alpha - target) > 0.001 then
        -- UIFrameFade* calls Show() internally. That is unsafe for protected
        -- Blizzard bars in combat, while changing alpha does not alter state.
        frame:SetAlpha(target)
    end
end
local pairs = pairs
local ipairs = ipairs
local max = math.max

local SENSITIVE_BLIZZARD_FRAME_NAMES = {
    DamageMeter = true,
    DamageMeterFrame = true,
    DamageMeterViewer = true,
    DamageMeterSessionWindow = true,
    DamageMeterSessionWindow1 = true,
    DamageMeterSessionWindow2 = true,
}

local function GetQueueStatusFrame()
    return _G.QueueStatusButton or _G.QueueStatusMinimapButton
end

local function GetQueueAnchorFrame()
    return _G.Minimap or _G.MinimapCluster or _G.KT_MinimapHolder_Main
end

local function GetReadyCheckPortrait()
    local frame = _G.ReadyCheckFrame
    if not frame then
        return nil
    end

    return _G.ReadyCheckPortrait
        or _G.ReadyCheckFramePortrait
        or frame.portrait
        or frame.Portrait
        or nil
end

local QUEUE_DEFAULT_POSITION = {
    point = "TOPRIGHT",
    relativePoint = "BOTTOMLEFT",
    x = -4,
    y = 4,
}

local function IsLegacyQueueDefaultPosition(pos)
    return pos
        and pos.point == "RIGHT"
        and pos.relativePoint == "LEFT"
        and pos.x == -6
        and pos.y == 0
end

local function IsLegacyQueueAnchorFrame(frame)
    if not frame then
        return false
    end

    if frame == _G.MicroMenuContainer
        or frame == _G.MicroMenu
        or frame == _G.MicroButtonAndBagsBar
        or frame == _G.BagsBar then
        return true
    end

    local name = frame.GetName and frame:GetName() or nil
    return name == "MicroMenuContainer"
        or name == "MicroMenu"
        or name == "MicroButtonAndBagsBar"
        or name == "BagsBar"
end

local function IsQueueAnchoredToLegacyMicroBar(frame)
    if not frame or not frame.GetPoint then
        return false
    end

    local parent = frame.GetParent and frame:GetParent() or nil
    if IsLegacyQueueAnchorFrame(parent) then
        return true
    end

    local pointCount = frame.GetNumPoints and frame:GetNumPoints() or 1
    for i = 1, max(1, pointCount) do
        local _, relativeTo = frame:GetPoint(i)
        if IsLegacyQueueAnchorFrame(relativeTo) then
            return true
        end
    end

    return false
end

local function HasStoredPosition(framesDB, key)
    local saved = framesDB and framesDB[key]
    return saved and saved.point ~= nil
end

local function GetEditModeSelectionRegions(frame)
    local ok, regions = pcall(function()
        return { frame:GetRegions() }
    end)
    if ok and regions then
        return regions
    end
    return {}
end

local function ForEachEditModeSelectionRegion(root, callback)
    if not (root and callback) then
        return
    end

    local seenFrames = {}
    local seenRegions = {}

    local function walk(frame)
        if not frame or seenFrames[frame] then
            return
        end
        seenFrames[frame] = true

        for _, region in ipairs(GetEditModeSelectionRegions(frame)) do
            if region and not seenRegions[region] then
                seenRegions[region] = true
                callback(region, frame)
            end
        end

        local ok, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if ok and children then
            for i = 1, #children do
                walk(children[i])
            end
        end
    end

    walk(root)
end

function Mod:ApplyEditModeSelectionColor(selection)
    return
end

function Mod:HookEditModeSelection(selection)
    return
end

function Mod:RefreshEditModeSelections()
    return
end

function Mod:ScheduleEditModeSelectionRefresh()
    return
end

function Mod:HookEditModeSelections()
    -- Leave Blizzard's native HUD Edit Mode selections completely untouched.
    -- This avoids taint paths on sensitive Blizzard systems during combat.
    self._editModeSelectionsHooked = true
    return true
end

function Mod:RefreshReadyCheckPortrait(unit)
    local frame = _G.ReadyCheckFrame
    local portrait = GetReadyCheckPortrait()
    if not (frame and portrait) then
        return
    end

    local initiator = unit
        or frame.initiator
        or frame.unit
        or frame.displayedUnit
        or "player"

    portrait:Show()
    portrait:SetAlpha(1)
    if portrait.SetDrawLayer then
        pcall(portrait.SetDrawLayer, portrait, "ARTWORK", 7)
    end
    if portrait.SetTexCoord then
        portrait:SetTexCoord(0, 1, 0, 1)
    end
    if SetPortraitTexture and type(initiator) == "string" and initiator ~= "" then
        pcall(SetPortraitTexture, portrait, initiator)
    end
end

function Mod:HookReadyCheckPortrait()
    if self._readyCheckPortraitHooked then
        return
    end

    local frame = _G.ReadyCheckFrame
    if frame and not frame.KT_ReadyCheckPortraitHooked then
        frame:HookScript("OnShow", function(readyFrame)
            self:RefreshReadyCheckPortrait(
                readyFrame and (readyFrame.initiator or readyFrame.unit or readyFrame.displayedUnit) or nil
            )
        end)
        frame.KT_ReadyCheckPortraitHooked = true
    end

    if hooksecurefunc and _G.ReadyCheckFrame_Show then
        hooksecurefunc("ReadyCheckFrame_Show", function(initiator)
            self:RefreshReadyCheckPortrait(initiator)
        end)
    end

    if hooksecurefunc and _G.ReadyCheckFrame_Update then
        hooksecurefunc("ReadyCheckFrame_Update", function(initiator)
            self:RefreshReadyCheckPortrait(initiator)
        end)
    end

    self._readyCheckPortraitHooked = true
    _G.C_Timer.After(0, function()
        self:RefreshReadyCheckPortrait()
    end)
end

function Mod:OnEnable()
    if not KT.db.profile.blizzframes then
        KT.db.profile.blizzframes = {
            fadeMicroMenu = false,
            fadeBags = false,
            fadeObjectiveTracker = false,
            fadeStatusBar = false,
            fadeQueueStatus = false,
            trackerFont = "KullThran Font",
            trackerFontSizeHeaders = 16,
            trackerFontOutline = "OUTLINE",
            trackerColor = { r = 1, g = 1, b = 1, a = 1 },
        }
    end
    self.db = KT.db.profile.blizzframes

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshBlizzardFrameState")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshBlizzardFrameState")
    if KT.db and KT.db.RegisterCallback then
        KT.db.RegisterCallback(self, "OnProfileChanged", "RefreshFadeState")
        KT.db.RegisterCallback(self, "OnProfileCopied", "RefreshFadeState")
        KT.db.RegisterCallback(self, "OnProfileReset", "RefreshFadeState")
    end

    _G.C_Timer.After(1, function()
        self:RegisterFrames()
        self:UpdateMouseoverState()
        self:UpdateTrackerStyling()
        self:HookEditModeSelections()
        self:HookReadyCheckPortrait()
    end)

    if not self._editModeSelectionBootstrap then
        self._editModeSelectionBootstrap = _G.C_Timer.NewTicker(1, function()
            if self:HookEditModeSelections() then
                self._editModeSelectionBootstrap:Cancel()
                self._editModeSelectionBootstrap = nil
            end
        end)
    end
end

function Mod:UpdateTrackerStyling()
    if not LSM then return end

    -- Taint safety: ObjectiveTrackerFont and ObjectiveTrackerHeaderFont are Blizzard
    -- font objects. Mutating them from addon code can taint protected tooltip/widget
    -- text measurements elsewhere, including world map POI widgets.
    
    -- In 12.1, calling ObjectiveTrackerFrame:Update() manually taints the tracker
    -- which causes failures when it encounters secret auras (like Maw buffs).
    -- We let the tracker update itself organically instead.
end

local FadeDriver = CreateFrame("Frame")
FadeDriver.Frames = {}
FadeDriver.Interval = 0.1

function FadeDriver:Stop()
    if self._ticker and self._ticker.Cancel then
        self._ticker:Cancel()
    end
    self._ticker = nil
end

function FadeDriver:Start()
    if self._ticker then return end
    self._ticker = _G.C_Timer.NewTicker(self.Interval, function()
        local profiler = KT and KT.CombatProfiler
        local profileStarted = profiler and profiler:Begin("core.blizzardFrames.fade")
        if not next(FadeDriver.Frames) then
            FadeDriver:Stop()
            if profileStarted then profiler:End("core.blizzardFrames.fade", profileStarted) end
            return
        end

        for frame in pairs(FadeDriver.Frames) do
            if KT._unlockActive or SafeIsMouseOver(frame) then
                SafeSetAlpha(frame, 1)
            else
                SafeSetAlpha(frame, 0)
            end
        end
        if profileStarted then profiler:End("core.blizzardFrames.fade", profileStarted) end
    end)
end

local function HandleFade(frame, enable)
    if not frame then return end

    if enable then
        local mouseEnabled = frame.IsMouseEnabled and frame:IsMouseEnabled()
        if not IsSecret(mouseEnabled) and mouseEnabled == false and not InCombatLockdown() then
            frame:EnableMouse(true)
        end
        if not SafeIsMouseOver(frame) then SafeSetAlpha(frame, 0) end
        FadeDriver.Frames[frame] = true
        FadeDriver:Start()
    else
        if FadeDriver.Frames[frame] then
            FadeDriver.Frames[frame] = nil
            SafeSetAlpha(frame, 1)
        end
        if not next(FadeDriver.Frames) then
            FadeDriver:Stop()
        end
    end
end

function Mod:UpdateMouseoverState()
    -- AceDB replaces the profile table on profile changes/imports. Never keep
    -- using the stale table captured by OnEnable.
    self.db = KT.db and KT.db.profile and KT.db.profile.blizzframes or self.db or {}

    local microMenu = _G.MicroMenuContainer or _G.MicroMenu
    if self._fadeMicroMenuFrame and self._fadeMicroMenuFrame ~= microMenu then
        HandleFade(self._fadeMicroMenuFrame, false)
    end
    self._fadeMicroMenuFrame = microMenu
    if microMenu then HandleFade(microMenu, self.db.fadeMicroMenu) end

    local bags = _G.BagsBar
    if self._fadeBagsFrame and self._fadeBagsFrame ~= bags then
        HandleFade(self._fadeBagsFrame, false)
    end
    self._fadeBagsFrame = bags
    if bags then HandleFade(bags, self.db.fadeBags) end

    local tracker = _G.ObjectiveTrackerFrame
    if tracker then
        tracker:EnableMouse(true)
        HandleFade(tracker, self.db.fadeObjectiveTracker)
    end

    if _G.StatusTrackingBarManager then HandleFade(_G.StatusTrackingBarManager, self.db.fadeStatusBar) end
    local queue = GetQueueStatusFrame()
    if queue then HandleFade(queue, self.db.fadeQueueStatus) end
end

function Mod:RefreshFadeState()
    self:UpdateMouseoverState()

    -- Blizzard can rebuild/reparent these systems immediately after a profile,
    -- Edit Mode or world transition. Re-resolve the live frames after it settles.
    self._fadeRefreshToken = (self._fadeRefreshToken or 0) + 1
    local token = self._fadeRefreshToken
    _G.C_Timer.After(0, function()
        if self and self._fadeRefreshToken == token then
            self:UpdateMouseoverState()
        end
    end)
    _G.C_Timer.After(0.25, function()
        if self and self._fadeRefreshToken == token then
            self:UpdateMouseoverState()
        end
    end)
end

function Mod:Refresh()
    self:RefreshFadeState()
end

function Mod:FixPartyFrameBug()
    return
end

local function EnsureFramesDB()
    if not (KT.db and KT.db.profile) then
        return nil
    end
    KT.db.profile.editMode = KT.db.profile.editMode or {}
    KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}
    return KT.db.profile.editMode.frames
end

local function SaveStoredPosition(framesDB, key, point, relativePoint, x, y)
    framesDB[key] = framesDB[key] or {}
    framesDB[key].point = point
    framesDB[key].relativePoint = relativePoint
    framesDB[key].x = x
    framesDB[key].y = y
end

local function CaptureFramePosition(frame)
    if frame and frame.GetPoint then
        local point, _, relativePoint, x, y = frame:GetPoint()
        if point then
            return {
                point = point,
                relativePoint = relativePoint or point,
                x = x or 0,
                y = y or 0,
            }
        end
    end
end

local function ResolvePosition(framesDB, key, frame, defaultPos)
    local saved = framesDB[key]
    if saved and saved.point then
        return {
            point = saved.point,
            relativePoint = saved.relativePoint,
            x = saved.x,
            y = saved.y,
        }
    end

    local current = CaptureFramePosition(frame)
    if current then
        return current
    end

    if type(defaultPos) == "function" then
        return defaultPos()
    end
    return defaultPos
end

local function IsBlizzardEditModeActive()
    if KT and KT.IsBlizzardEditModeTransitionActive then
        return KT:IsBlizzardEditModeTransitionActive()
    end

    local frame = _G.EditModeManagerFrame
    return frame and frame.IsEditModeActive and frame:IsEditModeActive()
end

local function IsSensitiveBlizzardFrame(frame)
    if not frame then
        return false
    end

    local cur = frame
    local depth = 0
    while cur and depth < 8 do
        local name = cur.GetName and cur:GetName() or nil
        if name and SENSITIVE_BLIZZARD_FRAME_NAMES[name] then
            return true
        end
        cur = cur.GetParent and cur:GetParent() or nil
        depth = depth + 1
    end

    return false
end

local function ApplyPosition(frame, pos, forceParent)
    if not frame or not pos or InCombatLockdown() or IsBlizzardEditModeActive() then
        return
    end
    if IsSensitiveBlizzardFrame(frame) then
        return
    end

    frame.KT_RestoringPosition = true
    if forceParent and frame:GetParent() ~= forceParent then
        pcall(frame.SetParent, frame, forceParent)
    end
    pcall(frame.ClearAllPoints, frame)
    pcall(frame.SetPoint, frame, pos.point or "TOPLEFT", _G.UIParent, pos.relativePoint or pos.point or "TOPLEFT", pos.x or 0, pos.y or 0)

    local wasMovable = frame.IsMovable and frame:IsMovable()
    if frame.SetMovable and not wasMovable then pcall(frame.SetMovable, frame, true) end
    if frame.SetMovable and not wasMovable then pcall(frame.SetMovable, frame, false) end
    frame.KT_RestoringPosition = nil
end

local function ApplyQueueDefaultPosition(frame)
    local anchor = GetQueueAnchorFrame()
    if not frame or not anchor or InCombatLockdown() or IsBlizzardEditModeActive() then
        return
    end
    if IsSensitiveBlizzardFrame(frame) then
        return
    end

    frame.KT_RestoringPosition = true
    if frame:GetParent() ~= _G.UIParent then
        pcall(frame.SetParent, frame, _G.UIParent)
    end
    pcall(frame.ClearAllPoints, frame)
    pcall(frame.SetPoint, frame,
        QUEUE_DEFAULT_POSITION.point,
        anchor,
        QUEUE_DEFAULT_POSITION.relativePoint,
        QUEUE_DEFAULT_POSITION.x,
        QUEUE_DEFAULT_POSITION.y)

    local wasMovable = frame.IsMovable and frame:IsMovable()
    if frame.SetMovable and not wasMovable then pcall(frame.SetMovable, frame, true) end
    if frame.SetMovable and not wasMovable then pcall(frame.SetMovable, frame, false) end
    frame.KT_RestoringPosition = nil
end

local function ApplyQueuePosition(frame, framesDB)
    if HasStoredPosition(framesDB, "queue_status") then
        local pos = ResolvePosition(framesDB, "queue_status", nil, QUEUE_DEFAULT_POSITION)
        if IsLegacyQueueDefaultPosition(pos) then
            SaveStoredPosition(framesDB, "queue_status",
                QUEUE_DEFAULT_POSITION.point,
                QUEUE_DEFAULT_POSITION.relativePoint,
                QUEUE_DEFAULT_POSITION.x,
                QUEUE_DEFAULT_POSITION.y)
            pos = ResolvePosition(framesDB, "queue_status", nil, QUEUE_DEFAULT_POSITION)
        end
        ApplyPosition(frame, pos, _G.UIParent)
        return
    end

    local isUserPlaced = frame.IsUserPlaced and frame:IsUserPlaced()
    local captured = CaptureFramePosition(frame)
    if IsQueueAnchoredToLegacyMicroBar(frame) or not isUserPlaced or IsLegacyQueueDefaultPosition(captured) then
        ApplyQueueDefaultPosition(frame)
    end
end

function Mod:RestoreQueuePosition()
    local queue = GetQueueStatusFrame()
    local framesDB = EnsureFramesDB()
    if not queue or not framesDB then return end
    if InCombatLockdown() or IsBlizzardEditModeActive() or KT._unlockActive then
        self._queuePositionRestorePending = true
        return
    end

    self._queuePositionRestorePending = nil
    ApplyQueuePosition(queue, framesDB)
end

function Mod:ScheduleQueuePositionRestore(delay)
    delay = delay or 0
    self._queueRestoreTimers = self._queueRestoreTimers or {}
    local timerKey = tostring(delay)
    if self._queueRestoreTimers[timerKey] then return end

    self._queueRestoreTimers[timerKey] = true
    _G.C_Timer.After(delay, function()
        if not Mod then return end
        Mod._queueRestoreTimers[timerKey] = nil
        Mod:RestoreQueuePosition()
    end)
end

function Mod:RefreshBlizzardFrameState()
    self:RefreshFadeState()
    -- QueueStatusButton is rebuilt/reanchored around world transitions and
    -- after combat. Repair it after Blizzard's immediate and deferred passes.
    self:ScheduleQueuePositionRestore(0)
    self:ScheduleQueuePositionRestore(0.15)
    self:ScheduleQueuePositionRestore(0.6)
end

local function CreateUnlockProxy(name, label, width, height)
    local frame = _G[name]
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", name, _G.UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(1)
    frame:EnableMouse(false)
    frame:SetClampedToScreen(true)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333, 0.18)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(label or "")
    text:SetTextColor(1, 1, 1, 1)

    if KT.AddBorder then
        KT:AddBorder(frame, KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333, 1)
    end

    frame:SetAlpha(0.01)
    frame:Show()
    return frame
end

function Mod:RegisterFrames()
    local framesDB = EnsureFramesDB()
    if not framesDB then return end

    local elements = {}

    local function addElement(def)
        elements[#elements + 1] = def
    end

    -- Minimap positioning is owned by Blizzard Edit Mode. We intentionally avoid
    -- storing or restoring it here so Alt+Z/UI toggles do not fight Blizzard.

    local queue = GetQueueStatusFrame()
    if queue then
        queue:SetParent(_G.UIParent)
        queue:SetFrameStrata("MEDIUM")
        queue:SetFrameLevel(50)

        if not queue.KT_UnlockParentHooked and hooksecurefunc then
            hooksecurefunc(queue, "SetParent", function(frame, parent)
                if parent ~= _G.UIParent and not frame.KT_RestoringPosition and not KT._unlockActive and not IsBlizzardEditModeActive() then
                    if InCombatLockdown() then
                        Mod._queuePositionRestorePending = true
                        return
                    end
                    frame.KT_RestoringPosition = true
                    frame:SetParent(_G.UIParent)
                    frame.KT_RestoringPosition = nil
                    Mod:ScheduleQueuePositionRestore(0)
                end
            end)
            queue.KT_UnlockParentHooked = true
        end

        if not queue.KT_UnlockSetPointHooked and hooksecurefunc then
            hooksecurefunc(queue, "SetPoint", function(frame)
                if frame.KT_RestoringPosition or KT._unlockActive or IsBlizzardEditModeActive() then return end
                if InCombatLockdown() then
                    Mod._queuePositionRestorePending = true
                    return
                end
                Mod:ScheduleQueuePositionRestore(0)
            end)
            queue.KT_UnlockSetPointHooked = true
        end

        if not queue.KT_UnlockOnShowHooked and queue.HookScript then
            queue:HookScript("OnShow", function()
                if InCombatLockdown() then
                    Mod._queuePositionRestorePending = true
                    return
                end
                Mod:ScheduleQueuePositionRestore(0)
                Mod:ScheduleQueuePositionRestore(0.15)
            end)
            queue.KT_UnlockOnShowHooked = true
        end

        local function loadQueuePosition()
            if HasStoredPosition(framesDB, "queue_status") then
                return ResolvePosition(framesDB, "queue_status", nil, {
                    point = QUEUE_DEFAULT_POSITION.point,
                    relativePoint = QUEUE_DEFAULT_POSITION.relativePoint,
                    x = QUEUE_DEFAULT_POSITION.x,
                    y = QUEUE_DEFAULT_POSITION.y,
                })
            end

            local captured = CaptureFramePosition(queue)
            if IsQueueAnchoredToLegacyMicroBar(queue)
                or (not (queue.IsUserPlaced and queue:IsUserPlaced()))
                or IsLegacyQueueDefaultPosition(captured) then
                return QUEUE_DEFAULT_POSITION
            end
            return captured or QUEUE_DEFAULT_POSITION
        end

        ApplyQueuePosition(queue, framesDB)

        addElement({
            key = "queue_status",
            label = "LFG Eye",
            group = "Blizzard Frames",
            order = 20,
            getFrame = function() return queue end,
            getSize = function()
                return max(queue:GetWidth(), 24), max(queue:GetHeight(), 24)
            end,
            loadPosition = function()
                return loadQueuePosition()
            end,
            savePosition = function(_, point, relativePoint, x, y)
                SaveStoredPosition(framesDB, "queue_status", point, relativePoint, x, y)
            end,
            applyPosition = function()
                ApplyQueuePosition(queue, framesDB)
            end,
        })
    end

    -- In WoW 11.0 (Midnight), moving BNToastFrame taints the UIParent layout path,
    -- which eventually taints ActionButton_UpdatePressAndHoldAction
    -- causing ADDON_ACTION_BLOCKED on MultiBars. Do not move or skin it.
    -- local toast = _G.BNToastFrame
    -- if toast then ... end

    local zoneFrame = _G.ZoneAbilityFrame
    if zoneFrame then
        local zoneProxy = CreateUnlockProxy("KT_ZoneAbilityUnlockProxy", "Zone Button", 72, 72)
        local function zoneDefault()
            return {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 390,
                y = -300,
            }
        end

        -- Without a saved position, use KUI's reference layout instead of
        -- capturing Blizzard's transient native anchor.
        local zonePos = ResolvePosition(framesDB, "zone_ability", nil, zoneDefault)
        ApplyPosition(zoneProxy, zonePos, nil)

        if not zoneFrame.KT_UnlockOnShowHooked and zoneFrame.HookScript then
            zoneFrame:HookScript("OnShow", function()
                ApplyPosition(zoneFrame, ResolvePosition(framesDB, "zone_ability", zoneProxy, zoneDefault), _G.UIParent)
            end)
            zoneFrame.KT_UnlockOnShowHooked = true
        end

        addElement({
            key = "zone_ability",
            label = "Zone Button",
            group = "Blizzard Frames",
            order = 40,
            getFrame = function() return zoneProxy end,
            getSize = function() return 72, 72 end,
            loadPosition = function()
                return ResolvePosition(framesDB, "zone_ability", zoneProxy, zoneDefault)
            end,
            savePosition = function(_, point, relativePoint, x, y)
                SaveStoredPosition(framesDB, "zone_ability", point, relativePoint, x, y)
            end,
            applyPosition = function()
                local pos = ResolvePosition(framesDB, "zone_ability", zoneProxy, zoneDefault)
                ApplyPosition(zoneProxy, pos, nil)
                ApplyPosition(zoneFrame, pos, _G.UIParent)
            end,
        })
    end

    local mirror = _G.MirrorTimerContainer
    if mirror then
        local mirrorProxy = CreateUnlockProxy("KT_MirrorTimerUnlockProxy", "Breath/Fatigue", max(mirror:GetWidth(), 220), max(mirror:GetHeight(), 30))
        local mirrorDefault = {
            point = "TOP",
            relativePoint = "TOP",
            x = 0,
            y = -220,
        }
        local mirrorPos = ResolvePosition(framesDB, "mirror_timer", mirror, mirrorDefault)
        ApplyPosition(mirrorProxy, mirrorPos, nil)

        if not mirror.KT_UnlockOnShowHooked and mirror.HookScript then
            mirror:HookScript("OnShow", function()
                ApplyPosition(mirror, ResolvePosition(framesDB, "mirror_timer", mirrorProxy, mirrorDefault), _G.UIParent)
            end)
            mirror.KT_UnlockOnShowHooked = true
        end

        addElement({
            key = "mirror_timer",
            label = "Breath/Fatigue",
            group = "Blizzard Frames",
            order = 50,
            getFrame = function() return mirrorProxy end,
            getSize = function()
                return max(mirrorProxy:GetWidth(), 220), max(mirrorProxy:GetHeight(), 30)
            end,
            loadPosition = function()
                return ResolvePosition(framesDB, "mirror_timer", mirrorProxy, mirrorDefault)
            end,
            savePosition = function(_, point, relativePoint, x, y)
                SaveStoredPosition(framesDB, "mirror_timer", point, relativePoint, x, y)
            end,
            applyPosition = function()
                local pos = ResolvePosition(framesDB, "mirror_timer", mirrorProxy, mirrorDefault)
                ApplyPosition(mirrorProxy, pos, nil)
                ApplyPosition(mirror, pos, _G.UIParent)
            end,
        })
    end

    local durability = _G.DurabilityFrame
    if durability then
        local durabilityProxy = CreateUnlockProxy("KT_DurabilityUnlockProxy", "Equipment Durability", 60, 75)
        local durabilityDefault = {
            point = "TOPRIGHT",
            relativePoint = "TOPRIGHT",
            x = -150,
            y = -200,
        }
        local durabilityPos = ResolvePosition(framesDB, "durability_frame", durability, durabilityDefault)
        ApplyPosition(durabilityProxy, durabilityPos, nil)

        if not durability.KT_UnlockOnShowHooked and durability.HookScript then
            durability:HookScript("OnShow", function()
                ApplyPosition(durability, ResolvePosition(framesDB, "durability_frame", durabilityProxy, durabilityDefault), _G.UIParent)
            end)
            durability.KT_UnlockOnShowHooked = true
        end

        if not durability.KT_UnlockSetPointHooked and hooksecurefunc then
            hooksecurefunc(durability, "SetPoint", function(frame)
                if frame.KT_RestoringPosition or KT._unlockActive or InCombatLockdown() or IsBlizzardEditModeActive() then return end
                _G.C_Timer.After(0, function()
                    ApplyPosition(frame, ResolvePosition(framesDB, "durability_frame", durabilityProxy, durabilityDefault), _G.UIParent)
                end)
            end)
            durability.KT_UnlockSetPointHooked = true
        end

        addElement({
            key = "durability_frame",
            label = "Equipment Durability",
            group = "Blizzard Frames",
            order = 60,
            getFrame = function() return durabilityProxy end,
            getSize = function() return 60, 75 end,
            loadPosition = function() return ResolvePosition(framesDB, "durability_frame", durabilityProxy, durabilityDefault) end,
            savePosition = function(_, point, relativePoint, x, y) SaveStoredPosition(framesDB, "durability_frame", point, relativePoint, x, y) end,
            applyPosition = function()
                local pos = ResolvePosition(framesDB, "durability_frame", durabilityProxy, durabilityDefault)
                ApplyPosition(durabilityProxy, pos, nil)
                ApplyPosition(durability, pos, _G.UIParent)
            end,
        })
    end

    if KT.RegisterMovableElements then
        KT:RegisterMovableElements(elements)
    end
end
