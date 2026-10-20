if KT_CLIENT_BLOCKED then return end

local _, ns = ...

-- Execute range: when an enemy drops under a health percent, its health bar is
-- painted in the execute color, with an optional mark at the threshold and a skull.
-- Health is secret in combat, so the "under the threshold" test is a step curve fed
-- to UnitHealthPercent: it returns 1 or 0 as an alpha the engine applies without
-- us ever reading the value. The color layer mirrors the health bar's own values.

local DEFAULT_COLOR = { r = 0.85, g = 0.05, b = 0.05, a = 1 }
local DEFAULT_THRESHOLD = 20
local SKULL_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

ns.EXECUTE_DEFAULT_THRESHOLD = DEFAULT_THRESHOLD

local function Profile()
    return _G.KullThranUINameplatesDB or {}
end

local function IsEnabled()
    return Profile().executeEnabled == true
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) == true
end

function ns.GetExecuteThreshold()
    local t = tonumber(Profile().executeThreshold) or DEFAULT_THRESHOLD
    return math.max(1, math.min(99, t))
end

function ns.GetExecuteColor()
    local c = Profile().executeColor or DEFAULT_COLOR
    return c.r or DEFAULT_COLOR.r, c.g or DEFAULT_COLOR.g, c.b or DEFAULT_COLOR.b, c.a or DEFAULT_COLOR.a
end

local curve, curveThreshold
local function GetCurve(threshold)
    if curveThreshold ~= threshold then
        curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        local t = threshold / 100
        curve:AddPoint(0.0, 1)
        curve:AddPoint(t, 1)
        curve:AddPoint(t + 0.001, 0)
        curve:AddPoint(1.0, 0)
        curveThreshold = threshold
    end
    return curve
end

-- 1 when the unit is in execute range, 0 when not; possibly a secret number.
local function InRangeAlpha(unit)
    local threshold = ns.GetExecuteThreshold()
    if UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType then
        local ok, alpha = pcall(UnitHealthPercent, unit, true, GetCurve(threshold))
        if ok and alpha ~= nil then return alpha end
    end
    local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
    if IsSecret(health) or IsSecret(maxHealth) or not maxHealth or maxHealth <= 0 then return 0 end
    return (health / maxHealth * 100 <= threshold) and 1 or 0
end

-- Every plate that ever got the layer. Plates are pooled and reused for other
-- units, so the layers are hidden here when the feature is turned off.
local layers = setmetatable({}, { __mode = "k" })

local function Ensure(plate)
    if plate.ktExecute then return plate.ktExecute end
    local health = plate.health
    local bar = CreateFrame("StatusBar", nil, health)
    bar:SetAllPoints(health)
    bar:SetFrameLevel(health:GetFrameLevel())
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    local mark = health:CreateTexture(nil, "OVERLAY", nil, 6)
    mark:SetColorTexture(1, 1, 1, 0.9)
    mark:SetWidth(2)
    local skull = health:CreateTexture(nil, "OVERLAY", nil, 7)
    skull:SetTexture(SKULL_TEXTURE)
    skull:SetSize(16, 16)
    skull:SetPoint("RIGHT", health, "LEFT", -4, 0)
    local layer = { bar = bar, mark = mark, skull = skull }
    plate.ktExecute = layer
    layers[plate] = true
    -- Mirror the health bar so the color layer always fills exactly like it.
    health:HookScript("OnValueChanged", function(_, value)
        if layer.on then
            layer.bar:SetValue(value)
            if plate.unit then
                local alpha = InRangeAlpha(plate.unit)
                layer.bar:SetAlpha(alpha)
                if layer.skullOn then layer.skull:SetAlpha(alpha) end
            end
        end
    end)
    health:HookScript("OnMinMaxChanged", function(_, minValue, maxValue)
        if layer.on then layer.bar:SetMinMaxValues(minValue, maxValue) end
    end)
    return layer
end

local function Hide(plate)
    local layer = plate.ktExecute
    if not layer then return end
    layer.on = nil
    layer.bar:Hide()
    layer.mark:Hide()
    layer.skull:Hide()
end

local function Refresh(plate)
    local unit = plate.unit
    if not unit or not plate.health then return end
    local p = Profile()
    local layer = Ensure(plate)
    local health = plate.health
    local texture = health:GetStatusBarTexture() and health:GetStatusBarTexture():GetTexture()
    if texture and not IsSecret(texture) then layer.bar:SetStatusBarTexture(texture) end
    layer.bar:SetStatusBarColor(ns.GetExecuteColor())
    layer.bar:SetMinMaxValues(health:GetMinMaxValues())
    layer.bar:SetValue(health:GetValue())
    local alpha = InRangeAlpha(unit)
    layer.bar:SetAlpha(alpha)
    layer.bar:Show()
    layer.on = true

    if p.executeMark ~= false then
        local x = health:GetWidth() * ns.GetExecuteThreshold() / 100
        layer.mark:ClearAllPoints()
        layer.mark:SetPoint("TOP", health, "TOPLEFT", x, 0)
        layer.mark:SetPoint("BOTTOM", health, "BOTTOMLEFT", x, 0)
        layer.mark:Show()
    else
        layer.mark:Hide()
    end

    layer.skullOn = p.executeSkull ~= false
    if layer.skullOn then
        layer.skull:SetAlpha(alpha)
        layer.skull:Show()
    else
        layer.skull:Hide()
    end
end

local function RefreshAll()
    if not IsEnabled() then
        for plate in pairs(layers) do Hide(plate) end
        return
    end
    for _, plate in pairs(ns.plates or {}) do Refresh(plate) end
end
ns.RefreshExecute = RefreshAll

-- A plate is (re)bound to a unit on NAME_PLATE_UNIT_ADDED; refresh it once the
-- plate code has run so the layer follows the new unit.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
watcher:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        C_Timer.After(0, function()
            local plate = ns.plates and ns.plates[unit]
            if not plate then return end
            if IsEnabled() then Refresh(plate) else Hide(plate) end
        end)
    else
        RefreshAll()
    end
end)
