-- AFK screen: enters on the AFK flag, restores UIParent on key press or combat,
-- never acts on a secret AFK value and stays off when the option is disabled.
local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path)); local s = f:read("*a"); f:close(); return s
end

local function Widget()
    local w = { shown = true, events = {} }
    return setmetatable(w, { __index = function(t, k)
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "GetWidth" then return function() return 1920 end end
        if k == "GetHeight" then return function() return 1080 end end
        if k == "GetEffectiveScale" then return function() return 1 end end
        if k == "SetScript" then return function(self, name, fn) self[name] = fn end end
        if k == "RegisterEvent" then return function(self, e) self.events[e] = true end end
        if k == "UnregisterEvent" then return function(self, e) self.events[e] = nil end end
        if k == "UnregisterAllEvents" then return function(self) self.events = {} end end
        if k == "CreateTexture" or k == "CreateFontString" then return function() return Widget() end end
        return function() end
    end })
end

local frames = {}
local afkFlag, inCombat, spinning = false, false, false
local mod = { db = { enable = true } }
function mod:GetDB() return self.db end
function mod:RefreshSettings() end
local kt = {}
function kt:GetModule() return mod end
local uiParent = Widget()

local env = setmetatable({
    KT = kt, UIParent = uiParent,
    CreateFrame = function(_, name) local f = Widget(); frames[#frames + 1] = f; if name then frames[name] = f end; return f end,
    GetTime = function() return 100 end,
    InCombatLockdown = function() return inCombat end,
    UnitIsAFK = function() return afkFlag end,
    UnitClass = function() return "Mage", "MAGE" end,
    UnitName = function() return "Kull" end,
    MoveViewLeftStart = function() spinning = true end,
    MoveViewLeftStop = function() spinning = false end,
    C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end },
    hooksecurefunc = function(t, name, post)
        local orig = t[name]
        t[name] = function(...) local r = orig(...); post(...); return r end
    end,
}, { __index = _G })
env._G = env

local chunk = assert(loadstring(read("KullThranUI/Modules/Enhancements/Enhancements_AFK.lua")))
setfenv(chunk, env); chunk("KullThranUI", { KT = kt, Enhancements = mod })

mod:RefreshSettings()
local driver = frames[1]
assert(driver.events.PLAYER_FLAGS_CHANGED and driver.events.PLAYER_REGEN_DISABLED, "events registered")

afkFlag = true
driver.OnEvent(driver, "PLAYER_FLAGS_CHANGED", "player")
local screen = frames.KullThranUIAFKFrame
assert(screen and screen.shown and not uiParent.shown and spinning, "AFK flag shows the screen")
assert(screen.chat.events.CHAT_MSG_WHISPER, "AFK chat listens to whispers")

screen.OnKeyDown(screen, "W")
assert(not screen.shown and uiParent.shown and not spinning, "a key press restores the UI")

driver.OnEvent(driver, "PLAYER_FLAGS_CHANGED", "player")
inCombat = true
driver.OnEvent(driver, "PLAYER_REGEN_DISABLED")
assert(uiParent.shown and not screen.shown, "combat closes the screen")
inCombat = false

-- Previews must close on combat even with the feature disabled.
mod.db.afk.enabled = false
mod:RefreshSettings()
assert(not driver.events.PLAYER_FLAGS_CHANGED and driver.events.PLAYER_REGEN_DISABLED)
mod:PreviewAFKScreen()
assert(screen.shown and not uiParent.shown, "preview shows the screen")
driver.OnEvent(driver, "PLAYER_REGEN_DISABLED")
assert(uiParent.shown, "combat closes the preview")

driver.OnEvent(driver, "PLAYER_FLAGS_CHANGED", "player")
assert(uiParent.shown, "disabled option ignores the AFK flag")

mod.db.afk.enabled = true
mod:RefreshSettings()
env.issecretvalue = function() return true end
driver.OnEvent(driver, "PLAYER_FLAGS_CHANGED", "player")
assert(uiParent.shown, "secret AFK values are ignored")
print("afk_screen ok")
