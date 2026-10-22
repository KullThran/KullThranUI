-- KUI Tracker potion timers: a click or key press that never used the item must
-- not leave a five minute cooldown, and a stale timer must yield to the real one.
local sourceFile = assert(io.open('KullThranUI_CooldownManager/Modules/KUICooldownManager/KUICooldownManager.lua', 'r'))
local source = sourceFile:read('*a'); sourceFile:close()
local region = assert(source:match('\n(ns%.CDMGetActiveSyntheticItemCooldownState = function.-)\nlocal function ApplyItemCooldown'))

local LIGHTS, LIGHTS_Q1, HEALTH = 241308, 241309, 241304

local function Load(options)
    options = options or {}
    local clock = { now = 100 }
    local ns = { _itemSpellIDCache = {} }
    ns.NormalizeItemID = function(id) return tonumber(id) end
    ns.RequestCustomCooldownUpdate = function() end
    local real = options.real or { start = 0, duration = 0 }
    local env = setmetatable({
        ns = ns,
        GetTime = function() return clock.now end,
        InCombatLockdown = function() return options.combat or false end,
        IsEncounterInProgress = function() return false end,
        C_Item = {
            GetItemCooldown = function() return real.start, real.duration, 1 end,
            GetItemSpell = function() return nil end,
        },
        CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end,
        C_Timer = { After = function() end },
        HEALTH_ITEMS = {},
    }, { __index = _G })
    env.PREPOT_ITEM_IDS = { [LIGHTS] = true, [LIGHTS_Q1] = true }
    local chunk = assert(loadstring([[
local HEALTH_ITEMS, PREPOT_ITEM_IDS = HEALTH_ITEMS, PREPOT_ITEM_IDS
local _syntheticItemCooldownGroups, _syntheticSpellToItemCache = {}, {}
local _syntheticSpellCacheReady, _syntheticTrackedItemCounts = false, nil
local NormalizeItemID = ns.NormalizeItemID
local function GetFallbackItemCooldownDuration(id) return (id == 5512) and 60 or 300 end
local function GetSyntheticItemCooldownGroup(id) return GetFallbackItemCooldownDuration(id) == 60 and 'healthstone' or 'potion' end
local function ItemMatchesSyntheticGroup() return true end
]] .. region .. [[

return {
    trigger = ns.TriggerImmediateSyntheticItemCooldown,
    spellcast = HandleSyntheticItemCooldownSpellcast,
    state = ns.CDMGetActiveSyntheticItemCooldownState,
    confirm = ns.CDMConfirmPendingSyntheticItemCooldown,
    resolve = ns.CDMResolveItemCooldownInfo,
    reset = ns.CDMResetSyntheticPotionCooldowns,
    cache = _syntheticSpellToItemCache,
}]]))
    setfenv(chunk, env)
    local api = chunk()
    api.clock = clock
    api.real = real
    return api
end

-- A press that was never confirmed leaves no cooldown behind.
local api = Load()
assert(api.trigger(LIGHTS), 'a press is shown at once')
assert(api.state('potion'), 'pending cooldown is visible right after the press')
api.clock.now = api.clock.now + 2
assert(not api.state('potion'), 'an unconfirmed press expires')

-- A real cast confirms it, even when the cast resolves to another rank.
api = Load()
api.cache[1236616] = LIGHTS_Q1
api.trigger(LIGHTS)
api.clock.now = api.clock.now + 0.4
assert(api.spellcast(1236616), 'the cast confirms the pending press')
api.clock.now = api.clock.now + 5
local state = api.state('potion')
assert(state and state.itemID == LIGHTS and not state.pending, 'the clicked rank keeps the timer')

-- A bag count change confirms it as well.
api = Load()
api.trigger(LIGHTS)
api.confirm(LIGHTS)
api.clock.now = api.clock.now + 10
assert(api.state('potion'), 'a confirmed press keeps its five minute timer')

-- A stale timer yields to a readable "ready" cooldown, but not while unknown.
api = Load()
api.cache[1236616] = LIGHTS
api.spellcast(1236616)
api.clock.now = api.clock.now + 30
local start, duration, enabled = api.resolve(LIGHTS)
assert(enabled == 0 and not api.state('potion'), 'real cooldown reads ready: stale timer dropped')
api = Load({ combat = true })
api.cache[1236616] = LIGHTS
api.spellcast(1236616)
api.clock.now = api.clock.now + 30
start, duration, enabled = api.resolve(LIGHTS)
assert(enabled == 1 and duration == 300, 'in combat the reading is not trusted: own timer stays')
api = Load()
api.cache[1236616] = LIGHTS
api.spellcast(1236616)
api.clock.now = api.clock.now + 1
start, duration, enabled = api.resolve(LIGHTS)
assert(enabled == 1, 'right after a cast the client may lag: own timer stays')
api = Load({ real = { start = 90, duration = 300 } })
start, duration, enabled = api.resolve(LIGHTS)
assert(start == 90 and duration == 300 and enabled == 1, 'a real cooldown is always shown')

-- Boss resets and key starts clear the timers; healthstones only on a key start.
api = Load()
api.cache[1236616] = LIGHTS
api.spellcast(1236616)
api.reset()
assert(not api.state('potion'), 'encounter end clears the potion timer')

assert(loadstring(source), 'KUICooldownManager.lua must stay under the 200 local limit')
print('KUI Tracker potion cooldown state tests passed')
