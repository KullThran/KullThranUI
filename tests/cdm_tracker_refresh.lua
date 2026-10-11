local sourceFile = assert(io.open('KullThranUI_CooldownManager/Modules/KUICooldownManager/KUICooldownManager.lua', 'r'))
local source = sourceFile:read('*a'); sourceFile:close()
local routing = assert(source:match('(    local dirtyHasNoBar =.-)\n    if perfTickActive then\n        local now = debugprofilestop%(%)\n        CDMRT:PerfPhaseAdd%("bar_updates"'))
local run = assert(loadstring([[return function(wasDirty, viewerDirty, dirtyBars, updateAllBars)
local calls = {}
local ns = { BLIZZ_CDM_FRAMES = { buffs = 'BuffViewer', cooldowns = 'CooldownViewer' } }
local profile = { cdmBars = { useBlizzardDisplayDefaults = false, bars = {
    { key = 'buffs', enabled = true },
    { key = 'cooldowns', enabled = true },
    { key = 'kui_defensive', enabled = true, customSpells = { 642 } },
    { key = 'kui_potion', enabled = true, customSpells = { -13 } },
    { key = 'custom_empty', enabled = true, customSpells = {} },
    { key = 'disabled', enabled = false, customSpells = { 100 } },
} } }
local CDMRT = {}
local perfTickActive, allowBarStagger = false, false
local function SafeUpdateCustomBarIcons(key) calls[key] = true end
local function UpdateCDMBarIcons(key) calls[key] = true; return false end
]] .. routing .. [[
return calls
end]]))()
local calls = run(true, false, {}, false)
assert(calls.kui_defensive and calls.kui_potion and calls.custom_empty, 'generic spell/state events must refresh custom trackers')
assert(not calls.buffs and not calls.cooldowns and not calls.disabled, 'generic events must not rebuild native or disabled bars')
calls = run(true, true, { buffs = true }, false)
assert(calls.buffs and not calls.kui_defensive and not calls.kui_potion, 'targeted buff event must stay targeted')
calls = run(true, false, { kui_defensive = true }, false)
assert(calls.kui_defensive and not calls.kui_potion and not calls.buffs, 'targeted tracker event must stay targeted')
calls = run(true, false, {}, true)
assert(calls.buffs and calls.cooldowns and calls.kui_defensive and calls.kui_potion, 'full rebuild must refresh every enabled bar')
calls = run(false, false, {}, false)
assert(next(calls) == nil, 'idle tick must do no work')

local recovery = assert(source:match('(local function SafeUpdateCustomBarIcons.-)\nfunction ns.RefreshCDMBarFromConfig'))
local ns, errors = {}, { kui_defensive = 'defensive failure', kui_potion = 'potion failure' }
local environment = {
    ns = ns, pcall = pcall, GetTime = function() return 10 end,
    UpdateCustomBarIcons = function(key) if errors[key] then error(errors[key]) end end,
    C_Timer = { After = function() end },
}
setmetatable(environment, { __index = _G })
local chunk = assert(loadstring(recovery .. '\nreturn SafeUpdateCustomBarIcons'))
setfenv(chunk, environment)
local safeUpdate = chunk()
assert(not safeUpdate('kui_defensive'))
assert(safeUpdate('kui_trinket'))
assert(ns._customTrackerErrors.kui_defensive, 'a healthy bar must not erase another bar error')
assert(not safeUpdate('kui_potion'))
errors.kui_defensive = nil
assert(safeUpdate('kui_defensive'))
assert(not ns._customTrackerErrors.kui_defensive and ns._customTrackerErrors.kui_potion, 'recovery must clear only its own error')
print('KUI Tracker refresh and recovery tests passed')
