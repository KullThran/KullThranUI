if KT_CLIENT_BLOCKED then return end

local _, ns = ...

-- Pending DoT damage: paints over the enemy health bar the health your own bleeds
-- and DoTs will still take before they expire, and can mark the plate with a skull
-- when that is enough to kill it. Damage per tick comes from your periodic hits in
-- the combat log; the ticks left come from the aura's expiration on the unit. Any
-- secret value (Retail combat restrictions) simply leaves the overlay hidden.

local DEFAULT_COLOR = { r = 0.90, g = 0.10, b = 0.10, a = 0.85 }
local DEFAULT_INTERVAL = 3
local SKULL_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

ns.DOT_DAMAGE_DEFAULT_COLOR = DEFAULT_COLOR

local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local floor = math.floor

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

-- dots[destGUID][spellName] = { amount, interval, lastTick }
local dots = {}
local tracked = 0
local playerGUID

local function Forget(destGUID)
    if dots[destGUID] then
        dots[destGUID] = nil
        tracked = tracked - 1
    end
end

local function RecordTick(destGUID, spellName, amount, critical)
    local now = GetTime()
    local byUnit = dots[destGUID]
    if not byUnit then
        byUnit = {}
        dots[destGUID] = byUnit
        tracked = tracked + 1
    end
    local dot = byUnit[spellName]
    if not dot then
        dot = { interval = DEFAULT_INTERVAL }
        byUnit[spellName] = dot
    elseif dot.lastTick then
        local gap = now - dot.lastTick
        if gap > 0.5 and gap < 6 then dot.interval = gap end
    end
    -- A critical tick would overstate every tick left; keep the last normal one.
    if not critical or not dot.amount then dot.amount = amount end
    dot.lastTick = now
end

-- Remaining time of your own debuff with this name on the unit, or nil.
local function GetAuraExpiration(unit, spellName)
    for i = 1, 40 do
        local name, expiration
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL|PLAYER")
            if not aura then return nil end
            name, expiration = aura.name, aura.expirationTime
        elseif UnitAura then
            local auraName, _, _, _, _, auraExpiration = UnitAura(unit, i, "HARMFUL|PLAYER")
            if not auraName then return nil end
            name, expiration = auraName, auraExpiration
        else
            return nil
        end
        if not Readable(name) or not Readable(expiration) then return nil end
        if name == spellName then
            return expiration
        end
    end
    return nil
end

local function PendingDamage(unit, guid)
    local byUnit = dots[guid]
    if not byUnit then return 0 end
    local total, now = 0, GetTime()
    for spellName, dot in pairs(byUnit) do
        local expiration = dot.amount and GetAuraExpiration(unit, spellName)
        if expiration and expiration > now then
            local ticks = floor((expiration - dot.lastTick) / dot.interval + 0.05)
            -- Ticks already past (late combat log) are not pending any more.
            local passed = floor((now - dot.lastTick) / dot.interval)
            ticks = ticks - passed
            if ticks > 0 then total = total + ticks * dot.amount end
        else
            byUnit[spellName] = nil
        end
    end
    if next(byUnit) == nil then Forget(guid) end
    return total
end

-- Every plate that ever got an overlay. Plates are pooled and reused for other
-- units, so the overlays are hidden here when tracking stops.
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
    local guid = UnitGUID(unit)
    if not Readable(guid) or not dots[guid] then
        HideOverlay(plate)
        return
    end
    local pending = PendingDamage(unit, guid)
    local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
    if pending <= 0 or not Readable(health) or not Readable(maxHealth) or maxHealth <= 0 then
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
    o.bar:SetValue(pending < health and pending or health)
    o.bar:SetStatusBarColor(ns.GetDotDamageColor())
    o.clip:Show()
    o.skull:SetShown(Profile().dotDamageSkull ~= false and pending >= health)
end

local function RefreshAll()
    if not IsEnabled() then
        HideAll()
        return
    end
    for _, plate in pairs(ns.plates or {}) do RefreshPlate(plate) end
end
ns.RefreshDotDamage = RefreshAll

-- Health and aura changes happen between ticks; a light ticker keeps the overlay in
-- step while anything is tracked, and stops itself when nothing is.
local ticker
local function SetTicker(on)
    if on and not ticker then
        ticker = C_Timer.NewTicker(0.2, function()
            RefreshAll()
            if tracked <= 0 then
                HideAll()
                ticker:Cancel()
                ticker = nil
            end
        end)
    elseif not on and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local PERIODIC = { SPELL_PERIODIC_DAMAGE = true }
local GONE = { SPELL_AURA_REMOVED = true }

local function OnCombatLog()
    if not IsEnabled() or not CombatLogGetCurrentEventInfo then return end
    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, _, spellName, _, amount,
        _, _, _, _, _, critical = CombatLogGetCurrentEventInfo()
    if not Readable(subevent) or not Readable(sourceGUID) or not Readable(destGUID) then return end
    if subevent == "UNIT_DIED" then
        Forget(destGUID)
        return
    end
    if sourceGUID ~= playerGUID or not Readable(spellName) then return end
    if PERIODIC[subevent] then
        if not Readable(amount) or type(amount) ~= "number" then return end
        RecordTick(destGUID, spellName, amount, Readable(critical) and critical == true)
        SetTicker(true)
    elseif GONE[subevent] and dots[destGUID] then
        dots[destGUID][spellName] = nil
        if next(dots[destGUID]) == nil then Forget(destGUID) end
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(watcher.RegisterEvent, watcher, "COMBAT_LOG_EVENT_UNFILTERED")
watcher:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog()
    elseif event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Out of combat nothing ticks any more: drop what is left so stale entries
        -- of mobs that evaded or despawned do not pile up.
        C_Timer.After(1, function()
            if UnitAffectingCombat and UnitAffectingCombat("player") then return end
            wipe(dots)
            tracked = 0
            HideAll()
        end)
    end
end)
