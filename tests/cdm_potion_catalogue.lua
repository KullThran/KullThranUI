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

assert(loadstring(source), 'KUICooldownManager.lua must stay under the 200 local limit')
print('KUI Tracker potion catalogue tests passed')
