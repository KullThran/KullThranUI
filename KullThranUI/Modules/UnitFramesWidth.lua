local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local M = KT:NewModule("UnitFramesWidth", "AceEvent-3.0", "AceTimer-3.0")

local C_AddOns = _G.C_AddOns
local InCombatLockdown = _G.InCombatLockdown
local hooksecurefunc = _G.hooksecurefunc

local DESIRED_WIDTH = 230
local MIN_VALID_WIDTH = 40
local LEGACY_DEFAULT_WIDTHS = {
    [181] = true,
    [187] = true,
}

local PLAYER_FRAME_GLOBALS = {
    "KullThranUI_UF_Player",
    "KT_PlayerFrame",
    "UUF_Player",
    "UUF_PlayerFrame",
    "UUF_PlayerUnitFrame",
    "UUF_PlayerUnit",
    "UnhaltedUnitFrame_Player",
    "UnhaltedPlayerFrame",
    "oUF_Player",
    "ElvUF_Player",
    "PlayerFrame",
}

local TARGET_FRAME_GLOBALS = {
    "KullThranUI_UF_Target",
    "KT_TargetFrame",
    "UUF_Target",
    "UUF_TargetFrame",
    "UUF_TargetUnitFrame",
    "UUF_TargetUnit",
    "UnhaltedUnitFrame_Target",
    "UnhaltedTargetFrame",
    "oUF_Target",
    "ElvUF_Target",
    "TargetFrame",
}

local PLAYER_NAME_PATTERNS = {
    "^UUF_.*Player",
    "^Unhalted.*Player",
    "^oUF_.*Player",
    "^ElvUF_.*Player",
}

local TARGET_NAME_PATTERNS = {
    "^UUF_.*Target",
    "^Unhalted.*Target",
    "^oUF_.*Target",
    "^ElvUF_.*Target",
}

-- Blizzard cast bars participate in protected/secret-value state transitions.
-- This module only normalizes unit-frame geometry; touching those bars here
-- taints CastingBarFrame:UpdateShownState during a cast.
local UNIT_CASTBAR_GLOBALS = {}

local function SetWidthSafe(obj, width)
    if not obj or type(obj.SetWidth) ~= "function" then
        return
    end
    pcall(obj.SetWidth, obj, width)
end

local function SetSizeSafe(obj, width, height)
    if not obj or type(obj.SetSize) ~= "function" then
        return
    end
    pcall(obj.SetSize, obj, width, height)
end

local function IsUsableWidth(width)
    return type(width) == "number" and width >= MIN_VALID_WIDTH
end

local function IsLegacyDefaultWidth(width)
    if type(width) ~= "number" then
        return false
    end
    return LEGACY_DEFAULT_WIDTHS[math.floor(width + 0.5)] == true
end

local function NormalizeTargetWidth(width)
    if not IsUsableWidth(width) or IsLegacyDefaultWidth(width) then
        return DESIRED_WIDTH
    end
    return width
end

local function GetObjectWidth(obj)
    if not obj or type(obj.GetWidth) ~= "function" then
        return nil
    end
    local ok, width = pcall(obj.GetWidth, obj)
    if ok and IsUsableWidth(width) then
        return width
    end
end

local function GetLinkedCastBars(unitKey)
    local names = UNIT_CASTBAR_GLOBALS[unitKey]
    local bars = {}
    if not names then
        return bars
    end

    for i = 1, #names do
        local bar = _G[names[i]]
        if bar then
            bars[#bars + 1] = bar
        end
    end

    return bars
end

local function GetReferenceWidth(frame, unitKey)
    local width = GetObjectWidth(frame)
    if width then
        return NormalizeTargetWidth(width)
    end

    local bars = {
        frame.Health, frame.Power, frame.Castbar,
        frame.health, frame.power, frame.castbar,
        frame.HealthBar, frame.PowerBar, frame.CastBar,
        frame.healthBar, frame.powerBar, frame.castBar,
    }

    for i = 1, #bars do
        width = GetObjectWidth(bars[i])
        if width then
            return NormalizeTargetWidth(width)
        end
    end

    local linkedBars = GetLinkedCastBars(unitKey)
    for i = 1, #linkedBars do
        width = GetObjectWidth(linkedBars[i])
        if width then
            return NormalizeTargetWidth(width)
        end
    end

    return DESIRED_WIDTH
end

local function ApplyBarWidths(frame, width, unitKey)
    width = width or GetReferenceWidth(frame, unitKey)

    local bars = {
        frame.Health, frame.Power, frame.Castbar,
        frame.health, frame.power, frame.castbar,
        frame.HealthBar, frame.PowerBar, frame.CastBar,
        frame.healthBar, frame.powerBar, frame.castBar,
    }

    for i = 1, #bars do
        SetWidthSafe(bars[i], width)
    end

    local linkedBars = GetLinkedCastBars(unitKey)
    for i = 1, #linkedBars do
        SetWidthSafe(linkedBars[i], width)
    end

    if type(frame.GetChildren) == "function" then
        local ok, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if ok and children then
            for i = 1, #children do
                local child = children[i]
                if child and type(child.GetObjectType) == "function" and child:GetObjectType() == "StatusBar" then
                    SetWidthSafe(child, width)
                end
            end
        end
    end
end

local function IsBlizzardUnitFrame(frame)
    if not frame or type(frame.GetName) ~= "function" then
        return false
    end
    local name = frame:GetName()
    return name == "PlayerFrame" or name == "TargetFrame"
end

local function IsKUIManagedUnitFrame(frame)
    if not frame or type(frame.GetName) ~= "function" then
        return false
    end

    local name = frame:GetName()
    if type(name) ~= "string" or name == "" then
        return false
    end

    return name == "KullThranUI_UF_Player"
        or name == "KT_PlayerFrame"
        or name == "KullThranUI_UF_Target"
        or name == "KT_TargetFrame"
end

local function SyncFrameWidths(self, frame, unitKey, widthHint)
    if InCombatLockdown and InCombatLockdown() and not IsKUIManagedUnitFrame(frame) then
        self._pendingApply = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
        return
    end

    ApplyBarWidths(frame, NormalizeTargetWidth(widthHint or GetReferenceWidth(frame, unitKey)), unitKey)
end

local function HookEnforceWidth(self, frame, unitKey)
    if not hooksecurefunc or not frame or frame._ktUnitFrameWidthHooked then
        return
    end
    frame._ktUnitFrameWidthHooked = true

    local reentry = false
    local function Enforce(widthHint)
        if reentry then return end
        reentry = true

        SyncFrameWidths(self, frame, unitKey, widthHint)

        reentry = false
    end

    hooksecurefunc(frame, "SetWidth", function(_, w)
        if IsUsableWidth(w) then
            Enforce(w)
        end
    end)

    hooksecurefunc(frame, "SetSize", function(_, w, h)
        if IsUsableWidth(w) and type(h) == "number" then
            Enforce(w)
        end
    end)
end

function M:ApplyWidthToFrame(frame, unitKey)
    if not frame or type(frame.SetWidth) ~= "function" then
        return false
    end

    local isKUIFrame = IsKUIManagedUnitFrame(frame)

    if InCombatLockdown and InCombatLockdown() and not isKUIFrame then
        self._pendingApply = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
        return false
    end

    local currentWidth = GetObjectWidth(frame)
    local width = NormalizeTargetWidth(GetReferenceWidth(frame, unitKey))
    if not isKUIFrame
        and not IsBlizzardUnitFrame(frame)
        and (not IsUsableWidth(currentWidth) or IsLegacyDefaultWidth(currentWidth))
        and IsUsableWidth(width)
    then
        local h = (type(frame.GetHeight) == "function" and frame:GetHeight()) or nil
        if type(h) == "number" and h > 0 then
            SetSizeSafe(frame, width, h)
        else
            SetWidthSafe(frame, width)
        end
    end
    ApplyBarWidths(frame, width, unitKey)
    HookEnforceWidth(self, frame, unitKey)

    if not self._hooked then self._hooked = {} end
    if not self._hooked[frame] and type(frame.HookScript) == "function" then
        self._hooked[frame] = true

        frame:HookScript("OnShow", function(f)
            if InCombatLockdown and InCombatLockdown() then return end
            SyncFrameWidths(self, f, unitKey)
        end)

        frame:HookScript("OnSizeChanged", function(f, w)
            if InCombatLockdown and InCombatLockdown() then return end
            if IsUsableWidth(w) then
                SyncFrameWidths(self, f, unitKey, w)
            end
        end)
    end

    return true
end

local function IsFrameObject(obj)
    if not obj or type(obj) ~= "table" or type(obj.GetObjectType) ~= "function" then
        return false
    end
    local ok, t = pcall(obj.GetObjectType, obj)
    return ok and type(t) == "string"
end

local function AddFrame(out, seen, frame)
    if not frame or seen[frame] or not IsFrameObject(frame) then
        return
    end
    seen[frame] = true
    out[#out + 1] = frame
end

local function MatchesAnyPattern(name, patterns)
    if type(name) ~= "string" then return false end
    for i = 1, #patterns do
        if name:match(patterns[i]) then
            return true
        end
    end
    return false
end

local function HasUnitAttribute(frame, unitKey)
    if not frame or not unitKey then return false end
    if frame.unit == unitKey then return true end
    if type(frame.GetAttribute) ~= "function" then return false end
    local ok, unit = pcall(frame.GetAttribute, frame, "unit")
    return ok and unit == unitKey
end

local function ResolveFrames(unitKey, globalNames, namePatterns, allowScan)
    local frames, seen = {}, {}

    for i = 1, #globalNames do
        AddFrame(frames, seen, _G[globalNames[i]])
    end

    return frames
end

local function TryPatchExternalUnitFramesDb(unitKey, widthHint)
    local ok, addonObj = pcall(function()
        return LibStub("AceAddon-3.0"):GetAddon("UnhaltedUnitFrames", true)
    end)
    if not ok or not addonObj or type(addonObj.db) ~= "table" or type(addonObj.db.profile) ~= "table" then
        return false
    end

    local profile = addonObj.db.profile
    local containerCandidates = {
        profile.units,
        profile.unitFrames,
        profile.unitframes,
        profile.frames,
    }

    local changed = false
    for i = 1, #containerCandidates do
        local container = containerCandidates[i]
        local unitDef = type(container) == "table" and container[unitKey] or nil
        if type(unitDef) == "table" then
            local currentWidth = unitDef.width
            local targetWidth = currentWidth
            if not IsUsableWidth(targetWidth) or IsLegacyDefaultWidth(targetWidth) then
                targetWidth = widthHint
            end
            targetWidth = NormalizeTargetWidth(targetWidth)

            if currentWidth ~= targetWidth and (not IsUsableWidth(currentWidth) or IsLegacyDefaultWidth(currentWidth)) then
                unitDef.width = targetWidth
                changed = true
            end

            local subs = { unitDef.health, unitDef.power, unitDef.castbar, unitDef.bars }
            for s = 1, #subs do
                local sub = subs[s]
                if type(sub) == "table" and sub.width ~= targetWidth then
                    sub.width = targetWidth
                    changed = true
                end
            end
        end
    end

    if changed then
        local refreshFns = { "UpdateAllFrames", "UpdateAll", "UpdateFrames", "Refresh", "Update" }
        for i = 1, #refreshFns do
            local fn = addonObj[refreshFns[i]]
            if type(fn) == "function" then
                pcall(fn, addonObj)
            end
        end
    end

    return changed
end

function M:ApplyAll()
    if not (KT.db and KT.db.profile) then return end
    if KT.db.profile.unitFrames and KT.db.profile.unitFrames.enable == false then return end

    self._cachedFrames = self._cachedFrames or {}
    local playerFrames = self._cachedFrames.player or ResolveFrames("player", PLAYER_FRAME_GLOBALS, PLAYER_NAME_PATTERNS, false)
    local targetFrames = self._cachedFrames.target or ResolveFrames("target", TARGET_FRAME_GLOBALS, TARGET_NAME_PATTERNS, false)

    local foundAny = (#playerFrames > 0) or (#targetFrames > 0)
    if not foundAny then
        playerFrames = ResolveFrames("player", PLAYER_FRAME_GLOBALS, PLAYER_NAME_PATTERNS, true)
        targetFrames = ResolveFrames("target", TARGET_FRAME_GLOBALS, TARGET_NAME_PATTERNS, true)
    end

    foundAny = (#playerFrames > 0) or (#targetFrames > 0)

    if #playerFrames > 0 then self._cachedFrames.player = playerFrames end
    if #targetFrames > 0 then self._cachedFrames.target = targetFrames end

    local playerWidth = (#playerFrames > 0) and GetReferenceWidth(playerFrames[1], "player") or nil
    local targetWidth = (#targetFrames > 0) and GetReferenceWidth(targetFrames[1], "target") or nil

    if (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("UnhaltedUnitFrames")) then
        TryPatchExternalUnitFramesDb("player", playerWidth)
        TryPatchExternalUnitFramesDb("target", targetWidth)
    end

    for i = 1, #playerFrames do
        self:ApplyWidthToFrame(playerFrames[i], "player")
    end
    for i = 1, #targetFrames do
        self:ApplyWidthToFrame(targetFrames[i], "target")
    end

    local pending = self._retryTimer and true or false

    if not foundAny and not pending then
        self._retryCount = 0
        self._retryTimer = self:ScheduleRepeatingTimer("RetryApply", 0.75)
    elseif foundAny and self._retryTimer then
        self:CancelTimer(self._retryTimer)
        self._retryTimer = nil
    end
end

function M:RetryApply()
    self._retryCount = (self._retryCount or 0) + 1
    self:ApplyAll()

    if self._retryTimer and self._retryCount >= 20 then
        self:CancelTimer(self._retryTimer)
        self._retryTimer = nil
    end
end

function M:OnRegenEnabled()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if self._pendingApply then
        self._pendingApply = nil
        self:ApplyAll()
    end
end

function M:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN", "ApplyAll")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ApplyAll")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "ApplyAll")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")

    if KT and KT.RegisterChatCommand and not self._ktCmdRegistered then
        self._ktCmdRegistered = true
        KT:RegisterChatCommand("ktufwidth", function()
            self:ApplyAll()

            local function Dump(unitKey)
                local list = self._cachedFrames and self._cachedFrames[unitKey] or {}
                KT:Print("UFWidth [" .. unitKey .. "]: " .. tostring(#list) .. " frame(s)")
                for i = 1, #list do
                    local f = list[i]
                    local name = (type(f.GetName) == "function" and f:GetName()) or tostring(f)
                    local w = (type(f.GetWidth) == "function" and math.floor((f:GetWidth() or 0) + 0.5)) or 0
                    KT:Print(" - " .. tostring(name) .. " width=" .. tostring(w))
                end
            end

            Dump("player")
            Dump("target")
        end)
    end
end

function M:OnAddonLoaded(_, addonName)
    if addonName == "UnhaltedUnitFrames" or addonName == "KUIUnitFrames" then
        self:ApplyAll()
    end
end
