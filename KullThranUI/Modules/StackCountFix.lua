local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local M = KT:NewModule("StackCountFix", "AceEvent-3.0", "AceTimer-3.0")

local C_Timer = _G.C_Timer
local type = type
local issecretvalue = _G.issecretvalue
local STACK_FIX_ENABLED = false

local function IsSafeString(value)
    if type(value) ~= "string" then
        return false
    end
    if issecretvalue and issecretvalue(value) then
        return false
    end
    return value ~= ""
end

local function IsPointString(value)
    return IsSafeString(value)
end

local function IsFontString(obj)
    return obj and type(obj) == "table" and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "FontString"
end

local function EnsureOverlayHost(button)
    if not button or type(button.GetFrameLevel) ~= "function" then
        return nil
    end

    if button._ktStackOverlayHost then
        return button._ktStackOverlayHost
    end

    local host = CreateFrame("Frame", nil, button)
    host:SetAllPoints(button)
    host:SetFrameLevel(button:GetFrameLevel() + 100)
    button._ktStackOverlayHost = host
    return host
end

local function FixFontString(button, fs)
    if not button or not IsFontString(fs) then
        return
    end

    if fs._ktStackFixed then
        return
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = fs:GetPoint(1)
    local originalParent = fs:GetParent()
    local host = EnsureOverlayHost(button)
    if not host then
        return
    end

    fs:SetParent(host)
    fs:SetDrawLayer("OVERLAY", 7)

    -- Preserve original position when possible
    fs:ClearAllPoints()
    if IsPointString(point) then
        local rel = host
        if relativeTo and relativeTo ~= button and relativeTo ~= host and relativeTo ~= originalParent then
            rel = relativeTo
        end
        if relativeTo == button or relativeTo == host or relativeTo == originalParent then
            rel = host
        end
        fs:SetPoint(point, rel, IsPointString(relativePoint) and relativePoint or point, xOfs or 0, yOfs or 0)
    else
        fs:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1, 1)
    end

    fs._ktStackFixed = true
end

local function ShouldFixFontString(button, fs)
    if not button or not IsFontString(fs) then
        return false
    end

    if fs == button.Count or fs == button.count or fs == button.StackCount or fs == button.stackCount then
        return true
    end
    if fs == button.ChargeText or fs == button.chargeText or fs == button.ChargesText or fs == button.chargesText then
        return true
    end

    local name = type(fs.GetName) == "function" and fs:GetName() or nil
    if IsSafeString(name) then
        local ln = name:lower()
        if ln:find("count", 1, true) or ln:find("charge", 1, true) or ln:find("stack", 1, true) then
            return true
        end
    end

    return false
end

local function FixButton(button)
    if not button then
        return
    end

    local direct = {
        button.Count, button.count, button.StackCount, button.stackCount,
        button.ChargeText, button.chargeText, button.ChargesText, button.chargesText,
    }
    for i = 1, #direct do
        FixFontString(button, direct[i])
    end

    if type(button.GetRegions) == "function" then
        local ok, regions = pcall(function()
            return { button:GetRegions() }
        end)
        if ok and regions then
            for i = 1, #regions do
                local r = regions[i]
                if ShouldFixFontString(button, r) then
                    FixFontString(button, r)
                end
            end
        end
    end
end

local function FixAuraFrame(frame)
    if not frame then return end
    local container = frame.AuraContainer or frame
    if not container or type(container.GetChildren) ~= "function" then
        return
    end

    local ok, children = pcall(function()
        return { container:GetChildren() }
    end)
    if not ok or not children then
        return
    end

    for i = 1, #children do
        FixButton(children[i])
    end
end

function M:ApplyAll()
    if not STACK_FIX_ENABLED then
        return
    end
    -- Blizzard Buff/Debuff frames
    FixAuraFrame(_G.BuffFrame)
    FixAuraFrame(_G.DebuffFrame)
end

function M:ScheduleBurst()
    if not STACK_FIX_ENABLED then
        return
    end
    if self._burstTimer then return end
    local tries = 0
    self._burstTimer = self:ScheduleRepeatingTimer(function()
        tries = tries + 1
        self:ApplyAll()
        if tries >= 25 then
            self:CancelTimer(self._burstTimer)
            self._burstTimer = nil
        end
    end, 0.4)
end

function M:UNIT_AURA(_, unit)
    if not STACK_FIX_ENABLED then
        return
    end
    if unit == "player" then
        self:ScheduleBurst()
    end
end

function M:OnEnable()
    if not STACK_FIX_ENABLED then
        if KT and KT.RegisterChatCommand and not self._cmdRegistered then
            self._cmdRegistered = true
            KT:RegisterChatCommand("ktfixcounts", function()
                if KT.Print then
                    KT:Print("|cffff8844[ktfixcounts]|r desactivado por seguridad: estaba causando taint en marcos Blizzard.")
                end
            end)
        end
        return
    end

    self:RegisterEvent("PLAYER_LOGIN", "ScheduleBurst")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScheduleBurst")
    self:RegisterEvent("ADDON_LOADED", "ScheduleBurst")
    self:RegisterEvent("UNIT_AURA")

    if KT and KT.RegisterChatCommand and not self._cmdRegistered then
        self._cmdRegistered = true
        KT:RegisterChatCommand("ktfixcounts", function()
            self:ApplyAll()
            if KT.Print then KT:Print("|cff00FF88[ktfixcounts]|r aplicado.") end
        end)
    end

    -- Last-resort delayed attempt
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function() if self and self.ApplyAll then self:ApplyAll() end end)
    end
end
