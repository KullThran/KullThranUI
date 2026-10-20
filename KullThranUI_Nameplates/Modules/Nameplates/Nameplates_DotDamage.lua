if KT_CLIENT_BLOCKED then return end

local _, ns = ...

-- Pending DoT damage: paints over the enemy health bar the health your own bleeds
-- and DoTs will still take before they expire, and can mark the plate with a skull
-- when that is enough to kill it. The combat log is a protected event on these
-- clients, so everything comes from your auras on the unit: the damage per tick is
-- the aura's first effect value, and periodic auras tick on a grid that ends at
-- their expiration, so the ticks still to come are ceil(remaining / interval). Any
-- secret value (combat restrictions) simply leaves the overlay hidden.

local DEFAULT_COLOR = { r = 0.90, g = 0.10, b = 0.10, a = 0.85 }
local TICK_INTERVAL = 3
local SKULL_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

local GetTime = GetTime
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local ceil = math.ceil

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

local function TickAmount(aura)
    local points = aura.points
    if type(points) ~= "table" or IsSecret(points) then return nil end
    for i = 1, #points do
        local value = points[i]
        if Readable(value) and type(value) == "number" and value > 0 then return value end
    end
    return nil
end

local function PendingDamage(unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return 0 end
    local total, now = 0, GetTime()
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL|PLAYER")
        if not aura then break end
        local expiration, duration = aura.expirationTime, aura.duration
        if Readable(expiration) and Readable(duration) and duration > 0 and expiration > now then
            local amount = TickAmount(aura)
            if amount then
                total = total + ceil((expiration - now) / TICK_INTERVAL - 0.01) * amount
            end
        end
    end
    return total
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
    local skull = health:CreateTexture(nil, "OVERLAY", nil, 7)
    skull:SetTexture(SKULL_TEXTURE)
    skull:SetSize(16, 16)
    skull:SetPoint("RIGHT", health, "LEFT", -4, 0)
    skull:Hide()
    plate.ktDotDamage = { clip = clip, bar = bar, skull = skull }
    overlays[plate] = true
    clip:Hide()
    return plate.ktDotDamage
end

local function HideOverlay(plate)
    local o = plate.ktDotDamage
    if not o then return end
    o.clip:Hide()
    o.skull:Hide()
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
    o.skull:SetShown(known and Profile().dotDamageSkull ~= false and pending >= health)
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

-- /kuidot: prints what the client exposes for your debuffs on the target, so the
-- estimate can be checked in and out of combat.
SLASH_KUIDOT1 = "/kuidot"
SlashCmdList.KUIDOT = function()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    local function Show(value) return Readable(value) and tostring(value) or "secret" end
    local now = GetTime()
    print(SLASH_KUIDOT1, Show(UnitHealth("target")), Show(UnitHealthMax("target")), PendingDamage("target"))
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")
        if not aura then break end
        local points = {}
        if type(aura.points) == "table" and not IsSecret(aura.points) then
            for j = 1, #aura.points do points[j] = Show(aura.points[j]) end
        end
        local remaining = Readable(aura.expirationTime) and string.format("%.1f", aura.expirationTime - now)
        print(" ", Show(aura.name), Show(aura.spellId), Show(aura.duration), remaining or "secret",
            table.concat(points, ","))
    end
end
