local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_Chat/Modules/Chat.lua"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local a = assert(source:find("function Mod:ApplyFrameFading(frame)", 1, true))
local b = assert(source:find("function Mod:RegisterPopups()", a, true))

local now = 100
local timers = {}
local window = { alpha = 1, shown = true }
function window:GetAlpha() return self.alpha end
function window:SetAlpha(value) self.alpha = value end
function window:Show() self.shown = true end

local editBox = { shown = false }
function editBox:IsShown() return self.shown end

local G = { KT_ChatWindow = window, ChatFrame1EditBox = editBox }
local Mod = { db = { fadeEnabled = true, fadeTimeVisible = 10, fadeDuration = 0, window = { visible = true } } }
function Mod:CreateNativeWindow() return window end

local env = setmetatable({
    Mod = Mod, _G = G, math = math, tonumber = tonumber,
    GetTime = function() return now end,
    InCombatLockdown = function() return false end,
    C_Timer = {
        NewTimer = function(delay, fn)
            local t = { delay = delay, fn = fn }
            function t:Cancel() self.cancelled = true end
            timers[#timers + 1] = t
            return t
        end,
        NewTicker = function(_, fn)
            local t = { Cancel = function() end }
            now = now + 1
            fn()
            return t
        end,
    },
}, { __index = _G })
local chunk = assert(loadstring(source:sub(a, b - 1)))
setfenv(chunk, env)
chunk()

local function FireLastTimer()
    local t = timers[#timers]
    assert(t and not t.cancelled, "a fade timer must be armed")
    t.fn()
end

-- Idle: the window rests at the configured opacity, not at zero.
Mod:RecordChatActivity()
Mod:ScheduleWindowFade()
assert(timers[#timers].delay == 10)
FireLastTimer()
assert(math.abs(window.alpha - 0.3) < 1e-6, "default resting opacity is 30%")

Mod.db.fadeRestAlpha = 0.55
Mod:ScheduleWindowFade()
FireLastTimer()
assert(math.abs(window.alpha - 0.55) < 1e-6)

-- Out-of-range values are clamped.
Mod.db.fadeRestAlpha = 3
assert(Mod:GetFadeRestAlpha() == 1)
Mod.db.fadeRestAlpha = -1
assert(Mod:GetFadeRestAlpha() == 0)
Mod.db.fadeRestAlpha = 0.4

-- Typing keeps the window at full opacity.
editBox.shown = true
local before = #timers
Mod:ScheduleWindowFade()
assert(#timers == before, "no fade while the edit box is open")
editBox.shown = false

-- Activity (hover, new message) wakes it back to full opacity.
Mod.db.fadeDuration = 0
window.alpha = 0.4
Mod:ShowWindowForActivity(false)
assert(window.alpha == 1)

-- Blizzard line fading is its own opt-in setting.
local frame = {}
function frame:SetFading(v) self.fading = v end
Mod:ApplyFrameFading(frame)
assert(frame.fading == false, "old messages stay by default")
Mod.db.fadeLines = true
Mod:ApplyFrameFading(frame)
assert(frame.fading == true)

print("PASS: chat fades to a configurable resting opacity and wakes on activity")
