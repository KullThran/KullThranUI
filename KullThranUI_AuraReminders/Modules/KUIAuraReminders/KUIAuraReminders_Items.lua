-- Aura Reminders, items: weapon enchant reads, bag ownership, item finders and the "last used" memory.
-- One text for both clients. Every client difference is chosen once, at Setup, from ctx.client.

local _, ns = ...

local pcall, type, pairs, error = pcall, type, pairs, error

local Items = {}
ns.AuraRemindersItems = Items

-- Set at Setup, then only read.
local GetDB
local flaskItems, foodItems, weaponItems, weaponNameByKey
local fieldByItem          -- item ID to the db.char field that remembers it
local Owned                -- the client's ownership test
local retailCount          -- Retail only: the count function, fixed at Setup

-- Last known bag totals, item ID to count. Replaced by each diff and by the login timer.
local baseline = {}

-- Weapon enchants ---------------------------------------------------------------------------------------------------

-- Both slots, in order, slot globals read now. Runs under pcall on Forever. A nil slot raises here, as the API would.
local function readBothSlots(read)
    local slot = INVSLOT_MAINHAND
    if slot == nil then error("INVSLOT_MAINHAND is nil") end
    local main = read(slot)
    slot = INVSLOT_OFFHAND
    if slot == nil then error("INVSLOT_OFFHAND is nil") end
    return main, read(slot)
end

-- Retail: nothing is caught. The legacy read runs only when the modern field is absent.
local function enchantsRetail()
    local api = C_PaperDollInfo
    local read = api and api.GetTemporaryEnchantmentInfo
    if read == nil then
        return GetWeaponEnchantInfo()
    end

    local slot = INVSLOT_MAINHAND
    if slot == nil then error("INVSLOT_MAINHAND is nil") end
    local main = read(slot)
    slot = INVSLOT_OFFHAND
    if slot == nil then error("INVSLOT_OFFHAND is nil") end
    local off = read(slot)

    local mainOn, mainTime, mainCharges, mainID = false
    if main ~= nil then
        mainOn, mainTime, mainCharges, mainID = true, main.remainingTimeMs, main.chargesRemaining, main.enchantID
    end
    local offOn, offTime, offCharges, offID = false
    if off ~= nil then
        offOn, offTime, offCharges, offID = true, off.remainingTimeMs, off.chargesRemaining, off.enchantID
    end
    return mainOn, mainTime, mainCharges, mainID, offOn, offTime, offCharges, offID
end

-- Forever: modern read protected, then legacy protected, then the false tuple.
local function enchantsForever()
    local api = C_PaperDollInfo
    local read = api and api.GetTemporaryEnchantmentInfo
    if type(read) == "function" then
        local ok, main, off = pcall(readBothSlots, read)
        if ok then
            local mainOn, mainTime, mainCharges, mainID = false
            if main ~= nil then
                mainOn, mainTime, mainCharges, mainID = true, main.remainingTimeMs, main.chargesRemaining, main.enchantID
            end
            local offOn, offTime, offCharges, offID = false
            if off ~= nil then
                offOn, offTime, offCharges, offID = true, off.remainingTimeMs, off.chargesRemaining, off.enchantID
            end
            return mainOn, mainTime, mainCharges, mainID, offOn, offTime, offCharges, offID
        end
    end

    local legacy = GetWeaponEnchantInfo
    if type(legacy) == "function" then
        local ok, a, b, c, d, e, f, g, h = pcall(legacy)
        if ok then
            return a, b, c, d, e, f, g, h
        end
    end
    return false, nil, nil, nil, false, nil, nil, nil
end

-- Ownership ---------------------------------------------------------------------------------------------------------

-- Retail: count function fixed at Setup, nothing caught. Only a nil answer is tolerated.
local function ownedRetail(itemID)
    if not itemID then return false end
    local count = retailCount(itemID, false)
    if count == nil then return false end
    return count > 0
end

-- Forever: the comparison runs under pcall, and only a plain boolean comes out.
local function countAboveZero(count)
    if count > 0 then return true end
    return false
end

-- Forever: bags 0 to 4 until the first record with this item. Runs under pcall.
local function scanBagsForItem(itemID)
    local api = C_Container
    local numSlots = api and api.GetContainerNumSlots
    local itemInfo = api and api.GetContainerItemInfo
    if type(numSlots) ~= "function" or type(itemInfo) ~= "function" then return false end
    for bag = 0, 4 do
        local slots = numSlots(bag)
        if type(slots) == "number" then
            for slot = 1, slots do
                local record = itemInfo(bag, slot)
                if record and record.itemID == itemID then return true end
            end
        end
    end
    return false
end

-- Forever: count function resolved per call. Any failed step goes to the bag scan, whose failure is false.
local function ownedForever(itemID)
    if not itemID then return false end

    local api = C_Item
    local countFn = api and api.GetItemCount
    if type(countFn) ~= "function" then countFn = GetItemCount end
    if type(countFn) == "function" then
        local ok, count = pcall(countFn, itemID, false)
        if ok and type(count) == "number" then
            local compared, above = pcall(countAboveZero, count)
            if compared then return above end
        end
    end

    local scanned, found = pcall(scanBagsForItem, itemID)
    return scanned and found or false
end

-- Forever only: item icon, or the fallback for any failure.
local function getSafeItemIcon(itemID, fallback)
    if itemID == nil then return fallback end
    local api = C_Item
    local read = api and api.GetItemIconByID
    if type(read) ~= "function" then read = GetItemIcon end
    if type(read) ~= "function" then return fallback end
    local ok, icon = pcall(read, itemID)
    if ok and icon ~= nil then return icon end
    return fallback
end

-- Finding items -----------------------------------------------------------------------------------------------------

local function findFlaskItem(preferredKey, lastUsedItemID)
    if preferredKey == nil then return nil end
    local anyKey = preferredKey == "last_used"
    if anyKey and Owned(lastUsedItemID) then return lastUsedItemID end
    for i = 1, #flaskItems do
        local flask = flaskItems[i]
        if anyKey or flask.key == preferredKey then
            local items = flask.items
            for j = 1, #items do
                local itemID = items[j]
                if Owned(itemID) then return itemID end
            end
        end
    end
    return nil
end

local function findFoodItem(preferredKey, lastUsedItemID)
    if preferredKey == nil then return nil end
    local anyKey = preferredKey == "last_used"
    if anyKey and Owned(lastUsedItemID) then return lastUsedItemID end
    for i = 1, #foodItems do
        local food = foodItems[i]
        if anyKey or food.key == preferredKey then
            local itemID = food.itemID
            if Owned(itemID) then return itemID end
        end
    end
    return nil
end

-- Catalogue order. The name and family reject a record before its count is asked.
local function firstFittingWeaponItem(family, wantedName)
    for i = 1, #weaponItems do
        local item = weaponItems[i]
        local weaponType = item.weaponType
        if (weaponType == "NEUTRAL" or (family ~= nil and weaponType == family))
            and (wantedName == nil or item.name == wantedName) then
            local itemID = item.itemID
            if Owned(itemID) then return itemID end
        end
    end
    return nil
end

local function findWeaponEnchantItem(preferredKey, lastUsedItemID, family)
    if preferredKey == nil then return nil end
    if preferredKey == "last_used" then
        if Owned(lastUsedItemID) then return lastUsedItemID end
        return firstFittingWeaponItem(family, nil)
    end
    local wantedName = weaponNameByKey[preferredKey]
    if wantedName == nil then return nil end
    return firstFittingWeaponItem(family, wantedName)
end

-- Item use memory ---------------------------------------------------------------------------------------------------

-- Totals per item over bags 0 to 4. Not protected on either client (G5).
local function takeSnapshot()
    local totals = {}
    local api = C_Container
    if not api then return totals end
    local numSlots, itemInfo = api.GetContainerNumSlots, api.GetContainerItemInfo
    for bag = 0, 4 do
        -- A bag with no slot count is an empty bag.
        local slots = numSlots(bag)
        if slots ~= nil then
            for slot = 1, slots do
                local record = itemInfo(bag, slot)
                if record then
                    local itemID = record.itemID
                    if itemID then
                        totals[itemID] = (totals[itemID] or 0) + record.stackCount
                    end
                end
            end
        end
    end
    return totals
end

local function onLoginTimer()
    baseline = takeSnapshot()
end

-- Login arms the delayed baseline. A bag update saves each catalogued item whose total fell, then moves the baseline.
local function onEvent(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, onLoginTimer)
        return
    end

    local db = GetDB()
    local char = db and db.char
    if not char then return end

    local fresh = takeSnapshot()
    for itemID, oldTotal in pairs(baseline) do
        if (fresh[itemID] or 0) < oldTotal then
            local field = fieldByItem[itemID]
            if field then char[field] = itemID end
        end
    end
    baseline = fresh
end

-- Item ID to saved field. Later lists overwrite earlier ones: flask over food over weapon.
local function buildItemMap()
    local map = {}
    for i = 1, #weaponItems do
        map[weaponItems[i].itemID] = "lastUsedWeaponEnchant"
    end
    for i = 1, #foodItems do
        map[foodItems[i].itemID] = "lastUsedFood"
    end
    for i = 1, #flaskItems do
        local items = flaskItems[i].items
        for j = 1, #items do
            map[items[j]] = "lastUsedFlask"
        end
    end
    return map
end

-- Setup -------------------------------------------------------------------------------------------------------------

function Items.Setup(ctx)
    local client = ctx and ctx.client
    if client ~= "retail" and client ~= "forever" then
        error("KUIAuraReminders_Items: ctx.client must be \"retail\" or \"forever\"", 2)
    end

    GetDB = ctx.GetDB
    flaskItems, foodItems = ctx.FlaskItems, ctx.FoodItems
    weaponItems, weaponNameByKey = ctx.WeaponEnchantItems, ctx.WeaponEnchantNameByKey
    fieldByItem = buildItemMap()

    if client == "retail" then
        local api = C_Item
        retailCount = (api and api.GetItemCount) or GetItemCount
        Owned = ownedRetail
        Items.GetTemporaryWeaponEnchants = enchantsRetail
    else
        Owned = ownedForever
        Items.GetTemporaryWeaponEnchants = enchantsForever
        Items.GetSafeItemIcon = getSafeItemIcon
    end

    Items.Owned = Owned
    Items.FindFlaskItem = findFlaskItem
    Items.FindFoodItem = findFoodItem
    Items.FindWeaponEnchantItem = findWeaponEnchantItem
    Items.FirstFittingWeaponItem = firstFittingWeaponItem

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", onEvent)
end
