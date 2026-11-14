-- Recharge of the pips that refill on a timer: Death Knight runes and Evoker essence.
-- The client animates each pip's status bar from a duration object, so nothing runs per frame in Lua.
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local Recharge = { starts = {}, lengths = {} }
KT.ResourceRecharge = Recharge

local starts, lengths = Recharge.starts, Recharge.lengths
local pendingStarts, pendingLengths = {}, {}

local RECHARGE_ALPHA = 0.55
local timerUnsupported = false
local RESYNC_TOLERANCE = 0.25
local ESSENCE_DEFAULT_RATE = 0.2 -- points per second, the client's own fallback

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function Clear(maximum)
    for i = 1, maximum do
        starts[i], lengths[i] = nil, nil
    end
end

-- Ready count, or nil when the client hides the values. Fills starts/lengths by pip position:
-- ready runes first, then the recharging ones, soonest first, as the native rune bar sorts them.
function Recharge.ReadRunes(maximum)
    if not GetRuneCooldown then return nil end
    Clear(maximum)
    local ready, pending = 0, 0
    for i = 1, maximum do
        local start, length, isReady = GetRuneCooldown(i)
        if IsSecret(start) or IsSecret(length) or IsSecret(isReady) then return nil end
        if isReady then
            ready = ready + 1
        elseif start and length and length > 0 then
            local slot = pending + 1
            while slot > 1 and pendingStarts[slot - 1] > start do
                pendingStarts[slot], pendingLengths[slot] = pendingStarts[slot - 1], pendingLengths[slot - 1]
                slot = slot - 1
            end
            pendingStarts[slot], pendingLengths[slot] = start, length
            pending = pending + 1
        end
    end
    for i = 1, pending do
        starts[ready + i], lengths[ready + i] = pendingStarts[i], pendingLengths[i]
    end
    return ready
end

-- Fills starts/lengths for the one essence that is refilling, read like the native essence bar.
function Recharge.ReadEssence(current, maximum)
    Clear(maximum)
    local powerType = Enum and Enum.PowerType and Enum.PowerType.Essence
    if not (powerType and current < maximum and GetPowerRegenForPowerType and UnitPartialPower) then return end
    local rate = GetPowerRegenForPowerType(powerType)
    if IsSecret(rate) or not rate or rate <= 0 then rate = ESSENCE_DEFAULT_RATE end
    local partial = UnitPartialPower("player", powerType)
    if IsSecret(partial) or not partial then partial = 0 end
    local length = 1 / rate
    starts[current + 1], lengths[current + 1] = GetTime() - partial / 1000 * length, length
end

function Recharge.Show(pip, start, length, texture, r, g, b)
    local bar = pip._ktRecharge
    if not bar then
        if timerUnsupported then return end
        if not (C_DurationUtil and C_DurationUtil.CreateDuration and Enum.StatusBarTimerDirection) then
            timerUnsupported = true
            return
        end
        bar = CreateFrame("StatusBar", nil, pip)
        if not bar.SetTimerDuration then
            timerUnsupported = true
            return
        end
        bar:SetAllPoints(pip)
        bar:SetFrameLevel(pip:GetFrameLevel() + 1)
        bar:SetMinMaxValues(0, 1)
        bar._duration = C_DurationUtil.CreateDuration()
        pip._ktRecharge = bar
    end
    if bar._texture ~= texture then
        bar:SetStatusBarTexture(texture)
        bar._texture = texture
    end
    bar:SetStatusBarColor(r, g, b, RECHARGE_ALPHA)
    -- Power events arrive constantly: only a different timer may restart the animation.
    if not bar._start or bar._length ~= length or math.abs(bar._start - start) > RESYNC_TOLERANCE then
        bar._start, bar._length = start, length
        bar._duration:SetTimeFromStart(start, length)
        bar:SetTimerDuration(bar._duration, Enum.StatusBarInterpolation.None, Enum.StatusBarTimerDirection.ElapsedTime)
        if bar.SetToTargetValue then bar:SetToTargetValue() end
    end
    bar:Show()
end

function Recharge.Hide(pip)
    local bar = pip._ktRecharge
    if bar and bar._start then
        bar:Hide()
        bar._start = nil
    end
end
