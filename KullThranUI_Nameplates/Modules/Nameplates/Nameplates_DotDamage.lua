if KT_CLIENT_BLOCKED then return end

local _, ns = ...

-- Pending DoT damage: paints over the enemy health bar the health your own bleeds
-- and DoTs will still take before they expire. The damage comes from the DoT
-- tracker (Nameplates_DotTracker.lua), which works from your casts and the damage
-- the units take, since auras and the combat log are out of reach in combat.

local DEFAULT_COLOR = { r = 0.90, g = 0.10, b = 0.10, a = 0.85 }

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax

local function Profile()
    return _G.KullThranUINameplatesDB or {}
end

local function IsEnabled()
    return Profile().dotDamageEnabled == true
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) == true
end

local function Readable(value)
    return value ~= nil and not IsSecret(value)
end

function ns.GetDotDamageColor()
    local c = Profile().dotDamageColor or DEFAULT_COLOR
    return c.r or DEFAULT_COLOR.r, c.g or DEFAULT_COLOR.g, c.b or DEFAULT_COLOR.b, c.a or DEFAULT_COLOR.a
end

local function PendingDamage(unit)
    if not ns.DotDamageForUnit then return 0 end
    return (ns.DotDamageForUnit(unit))
end

-- Every plate that ever got an overlay. Plates are pooled and reused for other
-- units, so the overlays are hidden here when the feature is turned off.
local overlays = setmetatable({}, { __mode = "k" })

local function EnsureOverlay(plate)
    if plate.ktDotDamage then return plate.ktDotDamage end
    local health = plate.health
    -- The bar is anchored to the right edge of the health fill and grows left, so it
    -- covers the health the DoTs will take. The clip frame keeps it inside the bar
    -- when the DoTs would deal more than the health left.
    local clip = CreateFrame("Frame", nil, health)
    clip:SetAllPoints(health)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(health:GetFrameLevel())
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 0)
    bar:SetReverseFill(true)
    bar:SetPoint("TOPRIGHT", health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    bar:SetFrameLevel(health:GetFrameLevel())
    plate.ktDotDamage = { clip = clip, bar = bar }
    overlays[plate] = true
    clip:Hide()
    return plate.ktDotDamage
end

local function HideOverlay(plate)
    local o = plate.ktDotDamage
    if not o then return end
    o.clip:Hide()
end

local function HideAll()
    for plate in pairs(overlays) do HideOverlay(plate) end
end

local function RefreshPlate(plate)
    local unit = plate.unit
    if not unit or not plate.health then return end
    local pending = PendingDamage(unit)
    if pending <= 0 then
        HideOverlay(plate)
        return
    end
    -- Health may be secret in combat: the status bar still takes it as its range,
    -- and the clip frame trims whatever would spill past the start of the bar.
    local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
    local known = Readable(health) and Readable(maxHealth)
    if known and maxHealth <= 0 then
        HideOverlay(plate)
        return
    end
    local o = EnsureOverlay(plate)
    local width = plate.health:GetWidth()
    if o.width ~= width then
        o.bar:SetWidth(width)
        o.width = width
    end
    o.bar:SetMinMaxValues(0, maxHealth)
    o.bar:SetValue((known and pending > health) and health or pending)
    o.bar:SetStatusBarColor(ns.GetDotDamageColor())
    o.clip:Show()
end

-- Ticks, health changes and aura refreshes all move the overlay, so a light
-- ticker repaints the visible plates while the feature is on.
local ticker
local function RefreshAll()
    if not IsEnabled() then
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
        HideAll()
        return
    end
    if not ticker then ticker = C_Timer.NewTicker(0.2, RefreshAll) end
    for _, plate in pairs(ns.plates or {}) do RefreshPlate(plate) end
end
ns.RefreshDotDamage = RefreshAll

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", RefreshAll)

-- /kuidot: prints what the tracker counts on the target, to check the estimate.
SLASH_KUIDOT1 = "/kuidot"
SlashCmdList.KUIDOT = function()
    local function Show(value) return Readable(value) and tostring(value) or "secret" end
    local pending, count = 0, 0
    if ns.DotDamageForUnit then pending, count = ns.DotDamageForUnit("target") end
    print(SLASH_KUIDOT1, Show(UnitHealth("target")), Show(UnitHealthMax("target")), pending, count)
end
