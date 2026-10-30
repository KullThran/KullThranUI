-------------------------------------------------------------------------------
--  Incoming-heal prediction on every KUI unit frame, all visual styles.
--  A teal/green segment is drawn after the end of the health fill showing the
--  heal that is about to land (like Blizzard's default frames). Uses the same
--  secret-safe API as the oUF HealthPrediction element
--  (CreateUnitHealPredictionCalculator + UnitGetDetailedHealPrediction).
--  Disable with KT.db.profile.unitFrames.healPrediction = false.
-------------------------------------------------------------------------------
local _, ns = ...
local KT = _G.KullThranUI

local HP = {}
ns.HealPrediction = HP

local WHITE = "Interface\\Buttons\\WHITE8x8"
local R, G, B, A = 0.0, 0.83, 0.77, 0.95

local function Enabled()
    local db = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
    return not (db and db.healPrediction == false)
end

local function Build(frame)
    local hp = frame.Health
    local bar = CreateFrame("StatusBar", nil, hp)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(R, G, B, A)
    bar:SetFrameLevel((hp:GetFrameLevel() or 1) + 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    hp:SetClipsChildren(true)
    if CreateUnitHealPredictionCalculator then
        bar.calc = CreateUnitHealPredictionCalculator()
    end
    frame._kuiHealPred = bar
    return bar
end

function HP:UpdateFrame(frame)
    local hp = frame and frame.Health
    local unit = frame and frame.unit
    if not hp or not unit then return end
    local bar = frame._kuiHealPred
    if not Enabled() or not UnitExists(unit) or not UnitGetDetailedHealPrediction then
        if bar then bar:Hide() end
        return
    end
    bar = bar or Build(frame)
    local fill = hp:GetStatusBarTexture()
    if not fill or not bar.calc then bar:Hide(); return end

    -- re-anchor each update: the health fill texture object can be swapped
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
    local w = hp:GetWidth()
    if w and w > 0 then bar:SetWidth(w) end

    local ok = pcall(function()
        local maxHealth = UnitHealthMax(unit)
        UnitGetDetailedHealPrediction(unit, "player", bar.calc)
        local allHeal = bar.calc:GetIncomingHeals()
        bar:SetMinMaxValues(0, maxHealth)
        bar:SetValue(allHeal)
    end)
    if ok then bar:Show() else bar:Hide() end
end

function HP:UpdateUnit(unit)
    local frame = ns.frames and ns.frames[unit]
    if frame and frame.IsShown and frame:IsShown() then self:UpdateFrame(frame) end
end

function HP:UpdateAll()
    if not ns.frames then return end
    for _, frame in pairs(ns.frames) do
        if type(frame) == "table" and frame.Health and frame.unit then
            pcall(self.UpdateFrame, self, frame)
        end
    end
end
KT.RefreshHealPrediction = function() HP:UpdateAll() end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_HEAL_PREDICTION", "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do ev:RegisterEvent(e) end
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, event, unit)
    if event:sub(1, 5) == "UNIT_" and event ~= "UNIT_PET" then
        if unit then pcall(HP.UpdateUnit, HP, unit) end
    else
        pcall(HP.UpdateAll, HP)
    end
end)
C_Timer.After(2, function() pcall(HP.UpdateAll, HP) end)
