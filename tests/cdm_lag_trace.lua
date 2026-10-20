-- CDM latency trace (/ktcdmlag): opt-in timeline from the aura event to the buffs row being
-- claimed, so a "the buff icon appears late" report can be attributed to Blizzard or to a
-- specific KUI stage. It must cost nothing when off and be wired to every stage of the chain.
local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_CooldownManager/Modules/KUICooldownManager/KUICooldownManager.lua"))
local source = f:read("*a"); f:close()

local a = assert(source:find("function ns.CDMLagToggle()", 1, true), "toggle exists")
local b = assert(source:find("\nfunction ns.NativeCDMViewerChanged", a, true))
local chunk = source:sub(a, b - 1)

local clock, printed = 1000, {}
local frame = { events = {} }
function frame:RegisterUnitEvent(e) self.events[e] = true end
function frame:UnregisterAllEvents() self.events = {} end
function frame:SetScript(n, fn) self[n] = fn end

local env = setmetatable({
    ns = {}, SlashCmdList = {}, GetTimePreciseSec = function() return clock end,
    CreateFrame = function() return frame end,
    print = function(s) printed[#printed + 1] = s end,
    string = string, table = table,
}, { __index = _G })
setfenv(assert(loadstring(chunk, "lag")), env)()
local ns = env.ns

assert(ns._lagTrace == nil, "off by default (no per-hook cost)")

-- On: events are registered and a trace starts with the aura.
ns.CDMLagToggle()
assert(type(ns._lagTrace) == "function" and frame.events.UNIT_AURA)
frame.OnEvent(frame); clock = clock + 0.002
frame.OnEvent(frame)                    -- repeated UNIT_AURA must not flood the timeline
clock = clock + 0.040; ns._lagTrace("pool_acquire")
clock = clock + 0.070; ns._lagTrace("changed_timer")
clock = clock + 0.900; ns._lagTrace("claimed:3+comp", true)

assert(#printed == 2, "one line for 'on', one timeline")
local line = printed[2]
assert(line:find("unit_aura x2 +0ms", 1, true), "consecutive aura events are collapsed: " .. line)
assert(not line:find("unit_aura.-unit_aura"), line)
assert(line:find("pool_acquire +42ms", 1, true) and line:find("changed_timer +112ms", 1, true)
    and line:find("claimed:3+comp +1012ms", 1, true), line)

-- A stale half-trace (no 'claimed') does not leak into the next one.
clock = clock + 10; ns._lagTrace("pool_acquire")
clock = clock + 10; ns._lagTrace("pool_acquire"); ns._lagTrace("claimed:1", true)
assert(not printed[#printed]:find("+10000ms", 1, true) and printed[#printed]:find("pool_acquire +0ms", 1, true), printed[#printed])

-- A flood of repeats (viewer refresh sets 14 cooldown IDs) collapses, and a long trace
-- still ends with the closing mark (the real report once lost it to a fixed cap).
clock = clock + 10
ns._lagTrace("unit_aura")
for _ = 1, 14 do ns._lagTrace("cooldown_id") end
for i = 1, 40 do ns._lagTrace("stage" .. i) end
clock = clock + 0.5; ns._lagTrace("claimed:3+comp", true)
local flood = printed[#printed]
assert(flood:find("cooldown_id x14", 1, true), flood)
assert(flood:find("claimed:3+comp +500ms", 1, true), "closing mark survives the cap: " .. flood)

-- Off again: hooks become no-ops.
ns.CDMLagToggle()
assert(ns._lagTrace == nil and next(frame.events) == nil)

-- Wired into every stage, always behind the cheap guard.
for _, stage in ipairs({ "pool_acquire", "acquire_item", "cooldown_id", "layout", "changed_timer", "update_pass", "claimed:" }) do
    local at = assert(source:find('_lagTrace("' .. stage, 1, true) or source:find('_lagTrace(' .. (stage == "claimed:" and '"claimed:"' or '"' .. stage .. '"'), 1, true),
        "stage wired: " .. stage)
    local before = source:sub(math.max(1, at - 160), at)
    assert(before:find("if ns._lagTrace", 1, true), "guarded: " .. stage)
end
assert(source:find("SLASH_KTCDMLAG1", 1, true) and source:find("ns.CDMLagToggle", 1, true), "slash command")

print("cdm_lag_trace: ok")
