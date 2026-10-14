-- KUI Tracker potion slots must recognise every Midnight potion by ID, including
-- the ones whose tooltip carries no keyword the fallback scan understands.
local sourceFile = assert(io.open('KullThranUI_CooldownManager/Modules/KUICooldownManager/KUICooldownManager.lua', 'r'))
local source = sourceFile:read('*a'); sourceFile:close()
local catalogue = assert(source:match('\n(HEALTH_ITEMS = {.-)\nns%.FindOwnedHealthPotionFallbackItem = function'))

local function Load(bag, potionQuality)
    local ns = {}
    local env = setmetatable({
        ns = ns,
        KUI_CDM = { db = { profile = { customTracker = { potion = { potionQuality = potionQuality or 'highest' } } } } },
        GetItemCount = function(itemID) return bag[itemID] or 0 end,
        GetTrackerOwnedItemCount = function(itemID) return bag[itemID] or 0 end,
    }, { __index = _G })
    local chunk = assert(loadstring('local HEALTH_ITEMS, PREPOT_ITEM_IDS\n' .. catalogue
        .. '\nreturn { choose = ChooseTrackerItemFromPriority, prepot = POTION_TRACKER_PREPOT_PRIORITY,'
        .. ' health = POTION_TRACKER_HEALTH_PRIORITY, prepotIDs = PREPOT_ITEM_IDS }\nend'))
    setfenv(chunk, env)
    local api = chunk()
    api.ns = ns
    return api
end

local api = Load({ [241296] = 3 })
assert(api.choose(api.prepot, 'potion') == 241296, 'Potion of Zealotry must fill the combat slot')
api = Load({ [241289] = 4 })
assert(api.choose(api.prepot, 'potion') == 241289, 'Potion of Recklessness must fill the combat slot')
api = Load({ [245898] = 2, [241308] = 10 })
assert(api.choose(api.prepot, 'potion') == 245898, 'fleeting Light\'s Potential is spent before the crafted one')
api = Load({ [241304] = 10, [271884] = 5 })
assert(api.choose(api.health, 'potion') == 271884, 'Concentrated Silvermoon Health Potion beats the plain one')
api = Load({ [271883] = 5, [271884] = 5 }, '1')
assert(api.choose(api.health, 'potion') == 271883, 'quality 1 setting picks the quality 1 concentrated potion')
api = Load({ [241301] = 7 })
assert(api.choose(api.ns.CDMPotionTrackerManaPriority, 'potion') == 241301, 'Lightfused Mana Potion fills the mana slot')
for _, id in ipairs({ 241288, 241292, 241296, 245897, 245900, 245902, 245910 }) do
    assert(api.prepotIDs[id], 'missing combat potion ' .. id)
end

-- Manually added potion entries must show themselves, not the biggest combat stack.
local displaySource = assert(source:match('\n(HEALTH_ITEMS = {.-)\nlocal _potionTooltipCache = {}'))
local function LoadDisplay(bag, potionQuality)
    local ns = {}
    ns.NormalizeItemID = function(id) return tonumber(id) end
    ns.CDMGetActiveSyntheticItemCooldownState = function() return nil end
    local env = setmetatable({
        ns = ns,
        playerIdentity = { class = 'MAGE' },
        KUI_CDM = { db = { profile = { customTracker = { potion = { potionQuality = potionQuality or 'highest' } } } } },
        GetItemCount = function(itemID) return bag[itemID] or 0 end,
        GetTrackerOwnedItemCount = function(itemID) return bag[itemID] or 0 end,
        NormalizeItemID = ns.NormalizeItemID,
        GetSyntheticItemCooldownGroup = function() return 'potion' end,
        GetFallbackItemCooldownDuration = function() return 300 end,
        GetPotionTooltipClass = function() return 'unknown' end,
    }, { __index = _G })
    local chunk = assert(loadstring('local HEALTH_ITEMS, PREPOT_ITEM_IDS\n' .. displaySource
        .. '\nreturn ns.ResolvePotionTrackerDisplayItem\nend'))
    setfenv(chunk, env)
    return chunk()
end
local resolve = LoadDisplay({ [241308] = 85, [241288] = 10 }, 'most')
assert(resolve(241288) == 241288, 'a Recklessness entry must not turn into Light\'s Potential')
assert(resolve(241308) == 241308, 'a Light\'s Potential entry keeps its own potion')
resolve = LoadDisplay({ [241289] = 4 }, 'highest')
assert(resolve(241288) == 241289, 'ranks of the same potion may still swap')
resolve = LoadDisplay({ [241308] = 85 }, 'highest')
assert(resolve(241288) == nil, 'no Recklessness owned: the entry stays empty instead of borrowing another potion')

assert(loadstring(source), 'KUICooldownManager.lua must stay under the 200 local limit')
print('KUI Tracker potion catalogue tests passed')
