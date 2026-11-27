-- Smoothly counting numbers for the health / power texts (unit frames, resource bars).
-- The bars already ease through the client's StatusBar interpolation; their texts used to
-- jump straight to each new value, a step per event. A channel keeps, per key (a unit and
-- what it shows), the number on screen and eases it towards the real value, then asks its
-- owner to redraw while any of its numbers is still moving. Nothing runs once all settle.
-- Secret values (combat on clients that hide them) are never touched: they pass through.
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local SmoothNumbers = {}
KT.SmoothNumbers = SmoothNumbers

local GetTime, exp, abs, floor, next, type = GetTime, math.exp, math.abs, math.floor, next, type

-- Time constant of the ease-out: the text covers 95% of a change in about 0.3 s,
-- close to the client's ExponentialEaseOut bars.
local TAU = 0.1
-- Longest an animation may last, whatever its size.
local SETTLE_TIME = 0.6
-- Redraws per second while a number moves.
local REDRAW_INTERVAL = 1 / 30

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local channels = {}
local driver

-- Where the number of a state is at `now`.
local function Position(state, now)
    local elapsed = now - state.start
    if elapsed >= SETTLE_TIME then return state.target, true end
    local value = state.target + (state.from - state.target) * exp(-elapsed / TAU)
    if abs(value - state.target) < 0.5 then return state.target, true end
    return value, false
end

local function EnsureDriver()
    if driver then return driver end
    driver = CreateFrame("Frame")
    driver:Hide()
    local sinceRedraw = 0
    driver:SetScript("OnUpdate", function(self, elapsed)
        sinceRedraw = sinceRedraw + elapsed
        if sinceRedraw < REDRAW_INTERVAL then return end
        sinceRedraw = 0
        local now = GetTime()
        local busy = false
        for channel in next, channels do
            local moving = channel.moving
            if next(moving) then
                -- Settled keys get one last redraw, at their exact value, then stop.
                local done
                for key, state in next, moving do
                    local _, settled = Position(state, now)
                    if settled then
                        done = done or {}
                        done[#done + 1] = key
                    end
                end
                local ok, err = pcall(channel.redraw, moving)
                if done then
                    for i = 1, #done do moving[done[i]] = nil end
                end
                if not ok then
                    -- A failing redraw must not keep the driver spinning.
                    for key in next, moving do moving[key] = nil end
                    if geterrorhandler then geterrorhandler()(err) end
                end
                if next(moving) then busy = true end
            end
        end
        if not busy then self:Hide() end
    end)
    return driver
end

local Channel = {}
Channel.__index = Channel

--- The number to show for `key`. `real` is the live value; `identity` (a GUID, a power
--- type...) makes the number jump instead of counting when what the key shows changes,
--- such as a new target. Returns `real` itself when it cannot or must not be smoothed.
function Channel:Value(key, real, identity)
    local states = self.states
    if IsSecret(real) or type(real) ~= "number" or IsSecret(identity) or not self.enabled() then
        states[key], self.moving[key] = nil, nil
        return real
    end
    local state = states[key]
    local now = GetTime()
    if not state or state.identity ~= identity then
        states[key] = { target = real, from = real, start = now, identity = identity }
        self.moving[key] = nil
        return real
    end
    if state.target ~= real then
        local position = Position(state, now)
        state.from, state.target, state.start = position, real, now
        self.moving[key] = state
        EnsureDriver():Show()
    end
    local value, settled = Position(state, now)
    if settled then return real end
    return floor(value + 0.5)
end

--- True while the number of `key` is still counting.
function Channel:IsMoving(key)
    return self.moving[key] ~= nil
end

--- Forgets `key`, so its next value is shown at once.
function Channel:Reset(key)
    if key == nil then
        wipe(self.states)
        wipe(self.moving)
    else
        self.states[key], self.moving[key] = nil, nil
    end
end

--- A set of smoothed numbers with one redraw callback. `redraw(moving)` receives the keys
--- still counting; `enabled()` tells whether smoothing is on (default: always).
function SmoothNumbers.NewChannel(redraw, enabled)
    local channel = setmetatable({
        states = {}, moving = {}, redraw = redraw,
        enabled = enabled or function() return true end,
    }, Channel)
    channels[channel] = true
    return channel
end
