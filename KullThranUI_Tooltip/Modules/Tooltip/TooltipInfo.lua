-- Modules/Tooltip/TooltipInfo.lua
-- The information block the Tooltip module adds to item, spell and aura
-- tooltips: one switch per line, the rows built from the client's item and
-- spell data. Shared by the live tooltips, the options page and its preview.
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Info = {}
KT.TooltipInfo = Info

local _G = _G
local format, tostring, tonumber, type, select, pcall = string.format, tostring, tonumber, type, select, pcall
local floor = math.floor
local issecretvalue = _G.issecretvalue

local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

-- Retail clients report a 10.0+ interface; Forever reports 1.x.
local build = _G.GetBuildInfo and select(4, _G.GetBuildInfo())
Info.IS_RETAIL = (tonumber(build) or 0) >= 100000

-- ---------------------------------------------------------------- switches
-- key, option label. retail: only offered where the client has that data.
-- off: shown only once switched on (the lines the module showed before stay on).
Info.ITEM_LINES = {
    { key = "showItemID",          label = "Show Item ID" },
    { key = "showItemIconID",      label = "Show Icon ID",            off = true },
    { key = "showItemLevelLine",   label = "Show Item Level",         off = true },
    { key = "showRequiredLevel",   label = "Show Required Level",     off = true },
    { key = "showItemQuality",     label = "Show Quality",            off = true },
    { key = "showAHCategory",      label = "Show AH Category" },
    { key = "showEquipSlot",       label = "Show Equip Slot",         off = true },
    { key = "showBindType",        label = "Show Binding",            off = true },
    { key = "showStackSize",       label = "Show Max Stack Size" },
    { key = "showVendorPrice",     label = "Show Vendor Price",       off = true },
    { key = "showItemCount",       label = "Show Item Count",         off = true },
    { key = "showItemSpell",       label = "Show Use Effect Spell",   off = true },
    { key = "showItemSetID",       label = "Show Item Set ID",        off = true },
    { key = "showExpansion",       label = "Show Expansion",          off = true, retail = true },
    { key = "showCraftingReagent", label = "Show Crafting Reagent",   off = true, retail = true },
    { key = "showLinkIDs",         label = "Show Enchant and Bonus IDs", off = true },
    { key = "showBagSlot",         label = "Show Bag and Slot" },
}
Info.SPELL_LINES = {
    { key = "showSpellID",         label = "Show Spell ID" },
    { key = "showSpellIconID",     label = "Show Icon ID",            off = true },
    { key = "showSpellRank",       label = "Show Rank",               off = true },
    { key = "showCastTime",        label = "Show Cast Time" },
    { key = "showSpellRange",      label = "Show Range",              off = true },
    { key = "showSpellCooldown",   label = "Show Cooldown",           off = true },
    { key = "showSpellCost",       label = "Show Cost",               off = true },
    { key = "showSpellCharges",    label = "Show Charges",            off = true, retail = true },
    { key = "showSpellKnown",      label = "Show Known",              off = true },
    { key = "showSpellPassive",    label = "Show Passive",            off = true },
}
Info.AURA_LINES = {
    { key = "showAuraSpellID",     label = "Show Aura Spell ID",      off = true },
    { key = "showAuraCaster",      label = "Show Aura Caster",        off = true },
}

local DEFAULT_OFF = {}
for _, list in ipairs({ Info.ITEM_LINES, Info.SPELL_LINES, Info.AURA_LINES }) do
    for _, line in ipairs(list) do
        if line.off then DEFAULT_OFF[line.key] = true end
    end
end

-- The switches this client offers, in order.
function Info:Lines(list)
    local out = {}
    for _, line in ipairs(list) do
        if not line.retail or self.IS_RETAIL then out[#out + 1] = line end
    end
    return out
end

local function DB()
    return KT.db and KT.db.profile and KT.db.profile.tooltip
end

function Info:IsShown(key)
    local db = DB()
    local value = db and db[key]
    if value == nil then return not DEFAULT_OFF[key] end
    return value ~= false
end

-- ---------------------------------------------------------------- safe reads
local function IsSecret(value)
    return issecretvalue ~= nil and value ~= nil and issecretvalue(value) == true
end

-- Calls an API and drops every secret value it returns (secure tooltips carry them).
-- Always returns at least one value, so tonumber(Safe(...)) never sees "no value".
local function DropSecrets(ok, ...)
    if not ok then return nil end
    local n = select("#", ...)
    if n == 0 then return nil end
    local values = { ... }
    for i = 1, n do
        if IsSecret(values[i]) then values[i] = nil end
    end
    return unpack(values, 1, n)
end

local function Safe(func, ...)
    if type(func) ~= "function" then return nil end
    return DropSecrets(pcall(func, ...))
end
Info.Safe = Safe

local function API(namespace, name, legacy)
    local ns = _G[namespace]
    return (ns and ns[name]) or (legacy and _G[legacy]) or nil
end

local function YesNo(value)
    return value and LText("Yes") or LText("No")
end

local function Seconds(ms)
    ms = tonumber(ms)
    if not ms then return nil end
    local text = format("%.2f", ms / 1000):gsub("0+$", ""):gsub("%.$", "")
    return format(LText("%s sec"), text)
end

local function Money(copper)
    copper = tonumber(copper)
    if not copper or copper <= 0 then return nil end
    if _G.GetMoneyString then
        local ok, text = pcall(_G.GetMoneyString, copper, true)
        if ok and text then return text end
    end
    if _G.GetCoinTextureString then
        local ok, text = pcall(_G.GetCoinTextureString, copper)
        if ok and text then return text end
    end
    return tostring(copper)
end

local function FirstGlobal(...)
    for i = 1, select("#", ...) do
        local text = _G[select(i, ...)]
        if type(text) == "string" and text ~= "" then return text end
    end
end

-- Enum.ItemBind values; both clients share the first ones.
local BIND_NAMES = {
    [1] = { "ITEM_BIND_ON_PICKUP" },
    [2] = { "ITEM_BIND_ON_EQUIP" },
    [3] = { "ITEM_BIND_ON_USE" },
    [4] = { "ITEM_BIND_QUEST" },
    [7] = { "ITEM_ACCOUNTBOUND", "ITEM_BIND_TO_ACCOUNT" },
    [8] = { "ITEM_BNETACCOUNTBOUND", "ITEM_BIND_TO_BNETACCOUNT" },
    [9] = { "ITEM_ACCOUNTBOUND_UNTIL_EQUIP", "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP" },
}

-- Numbers after the item ID in an item link (enchant, gems, suffix, bonus IDs).
local function LinkIDs(link)
    if type(link) ~= "string" or IsSecret(link) then return nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil end
    local fields = {}
    for value in (body .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = tonumber(value) end
    local function NonZero(i) local v = fields[i]; return v and v ~= 0 and v or nil end
    local out = { enchant = NonZero(2), suffix = NonZero(7) }
    local gems = {}
    for i = 3, 6 do
        if NonZero(i) then gems[#gems + 1] = tostring(fields[i]) end
    end
    if #gems > 0 then out.gems = table.concat(gems, ", ") end
    -- Retail links: field 13 counts the bonus IDs that follow it.
    local count = Info.IS_RETAIL and fields[13]
    if count and count > 0 then
        local bonus = {}
        for i = 14, 13 + count do
            if fields[i] then bonus[#bonus + 1] = tostring(fields[i]) end
        end
        if #bonus > 0 then out.bonus = table.concat(bonus, ", ") end
    end
    return out
end

-- ---------------------------------------------------------------- rows
-- Each row: { label (locale key), value (text) }. Empty when every line is off.
function Info:ItemRows(link)
    local rows = {}
    if link == nil or IsSecret(link) then return rows end
    local function Add(label, value)
        if value ~= nil and value ~= "" then rows[#rows + 1] = { label, tostring(value) } end
    end
    local Shown = function(key) return self:IsShown(key) end

    local instant = API("C_Item", "GetItemInfoInstant", "GetItemInfoInstant")
    local itemID, _, _, equipLoc, icon, classID, subclassID = Safe(instant, link)
    local getInfo = API("C_Item", "GetItemInfo", "GetItemInfo")
    local _, _, quality, itemLevel, minLevel, _, _, stackCount, _, _, sellPrice, _, _, bindType,
        expansionID, setID, isReagent = Safe(getInfo, link)

    if Shown("showItemID") then Add("Item ID", itemID or "?") end
    if Shown("showItemIconID") and type(icon) == "number" then Add("Icon ID", icon) end
    if Shown("showItemLevelLine") then
        local detailed = Safe(API("C_Item", "GetDetailedItemLevelInfo", "GetDetailedItemLevelInfo"), link)
        local level = tonumber(detailed) or tonumber(itemLevel)
        if level and level > 0 then Add("Item Level", floor(level + 0.5)) end
    end
    if Shown("showRequiredLevel") and tonumber(minLevel) and minLevel > 0 then Add("Required Level", minLevel) end
    if Shown("showItemQuality") and tonumber(quality) then
        local name = _G["ITEM_QUALITY" .. quality .. "_DESC"]
        if name then
            local _, _, _, hex = Safe(API("C_Item", "GetItemQualityColor", "GetItemQualityColor"), quality)
            Add("Quality", hex and ("|c" .. hex .. name .. "|r") or name)
        end
    end
    if Shown("showAHCategory") and classID then
        local className = Safe(API("C_Item", "GetItemClassInfo", "GetItemClassInfo"), classID)
        local subName = Safe(API("C_Item", "GetItemSubClassInfo", "GetItemSubClassInfo"), classID, subclassID)
        Add("AH Category", className)
        Add("AH Subcategory", subName)
    end
    if Shown("showEquipSlot") and type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        Add("Equip Slot", _G[equipLoc] or equipLoc)
    end
    if Shown("showBindType") and tonumber(bindType) then
        local names = BIND_NAMES[bindType]
        Add("Binding", (names and FirstGlobal(unpack(names))) or (bindType == 0 and LText("None")) or nil)
    end
    if Shown("showStackSize") then
        local stack = tonumber(Safe(API("C_Item", "GetItemMaxStackSizeByID"), link)) or tonumber(stackCount)
        if stack and stack > 1 then Add("Max stack size", stack) end
    end
    if Shown("showVendorPrice") and tonumber(sellPrice) then
        Add("Vendor Price", Money(sellPrice) or FirstGlobal("ITEM_UNSELLABLE") or LText("None"))
    end
    if Shown("showItemCount") then
        local count = API("C_Item", "GetItemCount", "GetItemCount")
        local inBags = tonumber(Safe(count, link))
        local total = tonumber(Safe(count, link, true))
        if inBags then Add("In Bags", inBags) end
        if total and total ~= inBags then Add("Total (with bank)", total) end
    end
    if Shown("showItemSpell") then
        local spellName, spellID = Safe(API("C_Item", "GetItemSpell", "GetItemSpell"), link)
        if spellName then Add("Use Effect", spellID and format("%s (%s)", spellName, spellID) or spellName) end
    end
    if Shown("showItemSetID") and tonumber(setID) and setID > 0 then Add("Item Set ID", setID) end
    if self.IS_RETAIL and Shown("showExpansion") and tonumber(expansionID) then
        Add("Expansion", _G["EXPANSION_NAME" .. expansionID])
    end
    if self.IS_RETAIL and Shown("showCraftingReagent") and isReagent ~= nil then
        Add("Crafting Reagent", YesNo(isReagent))
    end
    if Shown("showLinkIDs") then
        local ids = LinkIDs(link)
        if ids then
            Add("Enchant ID", ids.enchant)
            Add("Gem IDs", ids.gems)
            Add("Suffix ID", ids.suffix)
            Add("Bonus IDs", ids.bonus)
        end
    end
    return rows
end

function Info:SpellRows(spellID)
    local rows = {}
    spellID = (not IsSecret(spellID)) and tonumber(spellID) or nil
    if not spellID then return rows end
    local function Add(label, value)
        if value ~= nil and value ~= "" then rows[#rows + 1] = { label, tostring(value) } end
    end
    local Shown = function(key) return self:IsShown(key) end

    local icon, castTime, minRange, maxRange
    if _G.C_Spell and C_Spell.GetSpellInfo then
        local info = Safe(C_Spell.GetSpellInfo, spellID)
        if type(info) == "table" and not IsSecret(info) then
            local function Field(k) local v = info[k]; if not IsSecret(v) then return v end end
            icon, castTime, minRange, maxRange = Field("iconID"), Field("castTime"), Field("minRange"), Field("maxRange")
        end
    elseif _G.GetSpellInfo then
        local _, _, legacyIcon, legacyCast, legacyMin, legacyMax = Safe(_G.GetSpellInfo, spellID)
        icon, castTime, minRange, maxRange = legacyIcon, legacyCast, legacyMin, legacyMax
    end

    if Shown("showSpellID") then Add("Spell ID", spellID) end
    if Shown("showSpellIconID") and type(icon) == "number" then Add("Icon ID", icon) end
    if Shown("showSpellRank") then
        Add("Rank", Safe(API("C_Spell", "GetSpellSubtext", "GetSpellSubtext"), spellID))
    end
    if Shown("showCastTime") and tonumber(castTime) then
        Add("Cast Time", castTime == 0 and LText("Instant") or Seconds(castTime))
    end
    if Shown("showSpellRange") then
        minRange, maxRange = tonumber(minRange), tonumber(maxRange)
        if maxRange and maxRange > 0 then
            if minRange and minRange > 0 then
                Add("Range", format(LText("%s - %s yd"), minRange, maxRange))
            else
                Add("Range", format(LText("%s yd"), maxRange))
            end
        end
    end
    if Shown("showSpellCooldown") then
        local cooldown, gcd = Safe(_G.GetSpellBaseCooldown, spellID)
        cooldown, gcd = tonumber(cooldown), tonumber(gcd)
        if cooldown and cooldown > 0 then Add("Cooldown", Seconds(cooldown)) end
        if gcd and gcd > 0 then Add("Global Cooldown", Seconds(gcd)) end
    end
    if Shown("showSpellCost") then
        local costs = Safe(API("C_Spell", "GetSpellPowerCost", "GetSpellPowerCost"), spellID)
        if type(costs) == "table" and not IsSecret(costs) then
            local parts = {}
            for _, cost in ipairs(costs) do
                if type(cost) == "table" and not IsSecret(cost) then
                    local amount, percent, name = cost.cost, cost.costPercent, cost.name
                    if IsSecret(amount) then amount = nil end
                    if IsSecret(percent) then percent = nil end
                    if IsSecret(name) then name = nil end
                    local power = (type(name) == "string" and _G[name]) or name or ""
                    if tonumber(amount) and amount > 0 then
                        parts[#parts + 1] = format("%s %s", amount, power)
                    elseif tonumber(percent) and percent > 0 then
                        parts[#parts + 1] = format("%s%% %s", percent, power)
                    end
                end
            end
            if #parts > 0 then Add("Cost", table.concat(parts, ", ")) end
        end
    end
    if self.IS_RETAIL and Shown("showSpellCharges") then
        local charges = Safe(API("C_Spell", "GetSpellCharges"), spellID)
        local maxCharges = type(charges) == "table" and not IsSecret(charges) and charges.maxCharges
        if tonumber(maxCharges) and not IsSecret(maxCharges) and maxCharges > 1 then Add("Charges", maxCharges) end
    end
    if Shown("showSpellKnown") then
        local known = Safe(_G.IsPlayerSpell, spellID)
        if known == nil then known = Safe(_G.IsSpellKnown, spellID) end
        if known == nil then known = Safe(API("C_SpellBook", "IsSpellKnown"), spellID) end
        if known ~= nil then Add("Known", YesNo(known)) end
    end
    if Shown("showSpellPassive") then
        local passive = Safe(API("C_Spell", "IsSpellPassive", "IsPassiveSpell"), spellID)
        if passive ~= nil then Add("Passive", YesNo(passive)) end
    end
    return rows
end

-- Caster name in its class color, or the unit's plain name.
local function CasterText(unit)
    if not unit or IsSecret(unit) then return nil end
    local name = Safe(_G.UnitName, unit)
    if not name then return nil end
    local _, classFile = Safe(_G.UnitClass, unit)
    local color = classFile and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color and color.colorStr then return "|c" .. color.colorStr .. name .. "|r" end
    return name
end

function Info:AuraRows(spellID, sourceUnit)
    local rows = {}
    spellID = (not IsSecret(spellID)) and tonumber(spellID) or nil
    if spellID and self:IsShown("showAuraSpellID") then rows[#rows + 1] = { "Spell ID", tostring(spellID) } end
    if self:IsShown("showAuraCaster") then
        local caster = CasterText(sourceUnit)
        if caster then rows[#rows + 1] = { "Caster", caster } end
    end
    return rows
end

-- spellID and caster of an aura shown by GameTooltip:SetUnitAura and friends.
function Info:ReadAura(unit, index, filter, byInstance)
    if not unit or IsSecret(unit) or IsSecret(index) then return nil end
    local auras = _G.C_UnitAuras
    local data
    if byInstance then
        data = auras and Safe(auras.GetAuraDataByAuraInstanceID, unit, index)
    elseif auras and auras.GetAuraDataByIndex then
        data = Safe(auras.GetAuraDataByIndex, unit, index, filter)
    elseif _G.UnitAura then
        local _, _, _, _, _, _, source, _, _, spellID = Safe(_G.UnitAura, unit, index, filter)
        return spellID, source
    end
    if type(data) ~= "table" or IsSecret(data) then return nil end
    local spellID, source = data.spellId, data.sourceUnit
    if IsSecret(spellID) then spellID = nil end
    if IsSecret(source) then source = nil end
    return spellID, source
end
