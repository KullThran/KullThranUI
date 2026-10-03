-------------------------------------------------------------------------------
--  Combat feedback text (Dodge / Miss / Parry / damage / heal) over the portrait
--  of every KUI unit frame, like Blizzard's HitIndicator. Works in all visual
--  styles. Disable with KT.db.profile.unitFrames.hitText = false.
-------------------------------------------------------------------------------
local _, ns = ...
local KT = _G.KullThranUI

local HT = {}
ns.HitText = HT

local HOLD, FADE = 0.9, 0.9
local FONT = "Fonts\\FRIZQT__.TTF"

local COLORS = {
    WOUND = { 1, 0.1, 0.1 }, HEAL = { 0, 1, 0 }, ENERGIZE = { 0.41, 0.8, 0.94 },
}
local MISS_EVENTS = {
    DODGE = true, PARRY = true, BLOCK = true, EVADE = true, IMMUNE = true, MISS = true,
    DEFLECT = true, ABSORB = true, RESIST = true, REFLECT = true,
}

local function Enabled()
    local db = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
    if db and db.hitText ~= nil then return db.hitText ~= false end
    -- Unset: on for the Classic/Forever/Retail looks, off for KUI Style (Retail default).
    local VT = KT and KT.VisualThemes
    local theme = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
    return theme == "classic" or theme == "forever" or theme == "retail"
end

local function Build(frame)
    local host = CreateFrame("Frame", nil, frame)
    host:SetAllPoints(frame.Portrait and frame.Portrait.SetAllPoints and frame.Portrait or frame)
    host:SetFrameStrata("HIGH")
    host:SetFrameLevel((frame:GetFrameLevel() or 1) + 40)
    local fs = host:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, 20, "THICKOUTLINE")
    fs:SetPoint("CENTER", host, "CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    host.text = fs
    host:Hide()
    host:SetScript("OnUpdate", function(self, dt)
        self.t = (self.t or 0) + dt
        if self.t < HOLD then
            self:SetAlpha(1)
        elseif self.t < HOLD + FADE then
            self:SetAlpha(1 - (self.t - HOLD) / FADE)
        else
            self:Hide()
        end
    end)
    frame._kuiHitText = host
    return host
end

local function Show(frame, event, flagText, amount)
    local host = frame._kuiHitText or Build(frame)
    -- re-anchor each time: the portrait object can be swapped (2D/3D)
    local anchor = frame.Portrait
    host:ClearAllPoints()
    if anchor and anchor.GetCenter and anchor ~= frame then host:SetAllPoints(anchor) else host:SetAllPoints(frame) end

    local text, size, c
    if MISS_EVENTS[event] then
        text = _G[event] or event
        size, c = 20, { 1, 1, 1 }
    elseif event == "WOUND" or event == "HEAL" or event == "ENERGIZE" then
        c = COLORS[event]
        local db = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
        if db and db.hitTextWhiteNumbers then c = { 1, 1, 1 } end
        size = 18
        local ok, s = pcall(function()
            if event == "WOUND" then return tostring(amount) end
            return "+" .. tostring(amount)
        end)
        text = ok and s or ""
        if flagText == "CRITICAL" or flagText == "CRUSHING" then size = 24 end
    else
        return
    end
    host.text:SetFont(FONT, size, "THICKOUTLINE")
    host.text:SetTextColor(c[1], c[2], c[3])
    pcall(host.text.SetText, host.text, text)
    host.t = 0
    host:SetAlpha(1)
    host:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("UNIT_COMBAT")
ev:SetScript("OnEvent", function(_, _, unit, event, flagText, amount)
    if not Enabled() or not unit or not ns.frames then return end
    local frame = ns.frames[unit]
    if frame and frame.IsShown and frame:IsShown() then
        pcall(Show, frame, event, flagText, amount)
    end
end)
