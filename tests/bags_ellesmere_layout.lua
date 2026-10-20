-- Bags window sized like EllesmereUI: width from the columns, fixed height,
-- small category buttons, real free slots in the category view, OneBag
-- sections and swapping equipped bags by dragging.
-- Usage: lua5.1 tests/bags_ellesmere_layout.lua [root] [forever]
local root = arg[1] or "."
local forever = arg[2] == "forever"
local f = assert(io.open(root .. "/KullThranUI_Bags/Modules/Bags/Bags.lua"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()

-- Generic frame mock: known methods keep state, anything else is a no-op.
local frameMethods = {}
local verbs = { "Set", "Get", "Is", "Enable", "Register", "Clear", "Hook", "Add", "Raise", "Start", "Stop", "Unregister", "Create", "Lock", "Unlock", "Disable" }
local function NewFrame(kind, name, parent)
    local o = { kind = kind, shown = true, w = 0, h = 0, scripts = {}, parent = parent, points = {}, level = 1 }
    if name then _G[name] = o end
    return setmetatable(o, { __index = function(_, key)
        if frameMethods[key] then return frameMethods[key] end
        for _, verb in ipairs(verbs) do
            if key:sub(1, #verb) == verb then return function() end end
        end
        return nil
    end })
end
function frameMethods:SetSize(w, h) self.w, self.h = w, h end
function frameMethods:SetWidth(w) self.w = w end
function frameMethods:SetHeight(h) self.h = h end
function frameMethods:GetWidth() return self.w end
function frameMethods:GetHeight() return self.h end
function frameMethods:GetSize() return self.w, self.h end
function frameMethods:Show() self.shown = true end
function frameMethods:Hide() self.shown = false end
function frameMethods:SetShown(v) self.shown = not not v end
function frameMethods:IsShown() return self.shown end
function frameMethods:IsVisible() return self.shown end
function frameMethods:SetText(t) self.text = t end
function frameMethods:GetText() return self.text end
function frameMethods:SetTexture(t) self.texture = t end
function frameMethods:SetScript(k, fn) self.scripts[k] = fn end
function frameMethods:HookScript(k, fn) self.scripts[k] = self.scripts[k] or fn end
function frameMethods:GetScript(k) return self.scripts[k] end
function frameMethods:ClearAllPoints() self.points = {} end
function frameMethods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function frameMethods:GetFrameLevel() return self.level end
function frameMethods:SetFrameLevel(l) self.level = l end
function frameMethods:GetParent() return self.parent end
function frameMethods:SetID(id) self.id = id end
function frameMethods:GetID() return self.id or 0 end
function frameMethods:GetMinMaxValues() return 0, 0 end
function frameMethods:GetValue() return 0 end
function frameMethods:GetVerticalScroll() return 0 end
function frameMethods:CreateTexture() return NewFrame("Texture") end
function frameMethods:CreateFontString() return NewFrame("FontString") end
function frameMethods:GetRegions() return end
function frameMethods:GetChildren() return end
function frameMethods:IsMovable() return true end
function frameMethods:GetHighlightTexture() return NewFrame("Texture") end
function frameMethods:GetThumbTexture() return NewFrame("Texture") end
function frameMethods:GetName() return nil end

-- Bags: backpack (16, 2 items), bag 1 (10, empty), bag 2 = quiver (4, 1 item),
-- and on Retail the reagent bag 5 (6, 1 item).
local bagSlots = { [0] = 16, [1] = 10, [2] = 4, [3] = 0, [4] = 0, [5] = forever and 0 or 6 }
local items = {
    ["0:1"] = { itemID = 6948, stackCount = 1, quality = 1 },
    ["0:2"] = { itemID = 2589, stackCount = 20, quality = 1 },
    ["2:1"] = { itemID = 2512, stackCount = 200, quality = 1 },
    ["5:1"] = { itemID = 2589, stackCount = 5, quality = 1 },
}
local cursor, calls = nil, {}

_G.C_Container = {
    GetContainerNumSlots = function(bag) return bagSlots[bag] or 0 end,
    GetContainerItemInfo = function(bag, slot) return items[bag .. ":" .. slot] end,
    GetContainerItemLink = function(bag, slot) local i = items[bag .. ":" .. slot]; return i and ("|Hitem:" .. i.itemID .. "|h[x]|h") end,
    ContainerIDToInventoryID = function(bag) return 30 + bag end,
    GetContainerNumFreeSlots = function(bag) return 0, (bag == 2) and 1 or 0 end,
    GetBagName = function(bag) return bag == 2 and "Light Quiver" or ("Bag " .. bag) end,
}
_G.Enum = { BagIndex = { ReagentBag = 5 }, ItemClass = {} }
_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
_G.NUM_BAG_SLOTS = 4
_G.BACKPACK_CONTAINER = 0
_G.UIParent = NewFrame("Frame"); UIParent.w, UIParent.h = 1920, 1080
_G.GameTooltip = NewFrame("GameTooltip")
_G.CreateFrame = function(kind, name, parent)
    local frame = NewFrame(kind, name, parent)
    if kind == "ItemButton" then
        frame.icon = NewFrame("Texture")
        frame.Count = NewFrame("FontString")
    end
    return frame
end
_G.InCombatLockdown = function() return false end
_G.GetCursorInfo = function() return cursor end
_G.PickupBagFromSlot = function(inv) calls[#calls + 1] = "pickup:" .. inv; cursor = "item" end
_G.PutItemInBag = function(inv) calls[#calls + 1] = "put:" .. inv; cursor = nil end
_G.GetInventoryItemTexture = function(_, inv) return (inv == 31 or inv == 32) and 133639 or nil end
_G.GetItemInfoInstant = function(id) return id, "Misc", "Junk", "", 0, 15, 0 end
_G.GetItemInfo = function() return nil end
_G.C_Item = nil
_G.ItemLocation = nil
_G.C_Timer = { After = function() end }
_G.hooksecurefunc = function() end
_G.CopyTable = function(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.tinsert = table.insert
_G.lower = string.lower
_G.sort = table.sort
_G.SlashCmdList = {}
_G.tFilter = function(t, pred) local out = {} for _, v in ipairs(t) do if pred(v) then out[#out + 1] = v end end return out end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local KT = { FONT_PATH = "font", db = { profile = {} } }
function KT:IsForever() return forever end
function KT:NewModule() local m = {}; function m:RegisterEvent() end; KT._mod = m; return m end
function KT:AddBackdrop() end
function KT:AddBorder() end
_G.LibStub = function() return { GetAddon = function() return KT end } end

local chunk = assert(loadstring(source, "Bags.lua"))
local env = setmetatable({}, { __index = _G })
setfenv(chunk, env)
chunk()

local Mod = assert(KT._mod, "module not created")
Mod:OnInitialize()
Mod.db.window.visible = true

local function Rows(mod)
    local window = _G.KT_BagsWindow
    local out = {}
    for _, row in ipairs(window.KT_SidebarRows or {}) do
        if row.shown and row.KT_Label then out[#out + 1] = row end
    end
    return out
end

local function ShownHeaders()
    local out = {}
    for _, header in ipairs(Mod.categoryHeaders or {}) do
        if header.shown then out[#out + 1] = header.text end
    end
    return out
end

local function ShownButtons()
    local n = 0
    for _, button in ipairs(Mod.itemButtons) do
        if button.shown then n = n + 1 end
    end
    return n
end

-- Category view: width from 12 columns of 36 px, fixed height.
Mod:RefreshBagSlots()
local window = _G.KT_BagsWindow
local gridWidth = 12 * (36 + 3) - 3 + 8
assert(Mod:GetColumns() == 12, "default columns")
assert(window.w == 196 + gridWidth + 50, "large sidebar width " .. tostring(window.w))
if forever then
    assert(window.h <= 640, "forever fits the content, capped at the normal height")
else
    assert(window.h == 640, "retail keeps the fixed height " .. tostring(window.h))
end

-- Real free slots show up as their own category.
local total, used = 0, 0
for bag, n in pairs(bagSlots) do total = total + n end
for key in pairs(items) do
    local bag, slot = key:match("(%d+):(%d+)")
    if tonumber(slot) <= bagSlots[tonumber(bag)] then used = used + 1 end
end
local freeRow
for _, row in ipairs(Rows()) do
    if row.KT_Label.text == "Free Slots" then freeRow = row end
end
assert(freeRow, "Free Slots row in the sidebar")
assert(tonumber(freeRow.KT_Count.text) == total - used, "free slot count " .. tostring(freeRow.KT_Count.text))
assert(ShownButtons() == total, "items plus free slots are drawn in the category view")

-- Small category buttons shrink the sidebar and the window with it.
window.KT_SidebarSizeToggle.scripts.OnClick(window.KT_SidebarSizeToggle)
assert(Mod.db.smallCategories == true, "toggle is saved in the options")
assert(window.KT_Sidebar.w == 160, "small sidebar width")
assert(window.w == 160 + gridWidth + 50, "window follows the small sidebar")
for _, row in ipairs(Rows()) do
    if row.KT_Icon.shown then
        assert(row.h == 26 or row.h == 18, "small row height " .. tostring(row.h))
    end
end
window.KT_SidebarSizeToggle.scripts.OnClick(window.KT_SidebarSizeToggle)
assert(Mod.db.smallCategories == false and window.KT_Sidebar.w == 196)

-- OneBag: same width, sidebar kept, Main Bags and special bag sections.
Mod:SetSidebarSelection("compact")
assert(window.KT_Sidebar.shown, "OneBag keeps the category list")
assert(window.w == 196 + gridWidth + 50, "OneBag keeps the width")
local headers = ShownHeaders()
assert(headers[1] == "Main Bags (2 / 26)", "main bags header " .. tostring(headers[1]))
assert(headers[2] == "Light Quiver (1 / 4)", "quiver section " .. tostring(headers[2]))
if forever then
    assert(#headers == 2, "no reagent bag on Forever")
else
    assert(headers[3] == "Reagent Bag (1 / 6)", "reagent section " .. tostring(headers[3]))
end
assert(ShownButtons() == total, "OneBag draws every slot")

-- Dragging bag 1 onto bag 2 swaps them like the Blizzard bag bar.
Mod.db.showEquippedBags = true
Mod:RefreshBagSlots()
local holders = window.KT_BagIconHolders
holders[1].scripts.OnDragStart(holders[1])
holders[2].scripts.OnReceiveDrag(holders[2])
assert(calls[1] == "pickup:31" and calls[2] == "put:32", table.concat(calls, ","))
-- A click while carrying a bag drops it instead of filtering by that bag.
cursor = "item"
holders[3].scripts.OnClick(holders[3])
assert(calls[3] == "put:33" and Mod.selectedBagID == nil, "click drops the carried bag")
holders[3].scripts.OnClick(holders[3])
assert(Mod.selectedBagID == 3, "click without a bag still filters")

-- Dragging the header outside Unlock Mode saves the position for /reload.
window.GetPoint = function() return "TOPLEFT", nil, "BOTTOMLEFT", 120, 480 end
local unlockSaved
KT.GetModule = function(_, name)
    if name == "UnlockMode" then
        return { SaveElementPosition = function(_, key, pos) unlockSaved = { key = key, pos = pos } end }
    end
end
window.KT_Header.scripts.OnDragStop(window.KT_Header)
-- Forever restores Unlock Mode's own copy on reload, so the drag must reach it.
assert(unlockSaved and unlockSaved.key == "kullthran_bags_window" and unlockSaved.pos.x == 120 and unlockSaved.pos.y == 480, "header drag saves through Unlock Mode")
KT.GetModule = nil
local saved = KT.db.profile.editMode.frames.kullthran_bags_window
assert(saved and saved.point == "TOPLEFT" and saved.relativePoint == "BOTTOMLEFT" and saved.x == 120 and saved.y == 480, "header drag saves position")
window.points = {}
Mod:ApplySavedWindowPosition(window)
local p = window.points[#window.points]
assert(p and p[1] == "TOPLEFT" and p[3] == "BOTTOMLEFT" and p[4] == 120 and p[5] == 480, "saved position is restored")

print("PASS: bags sized like EllesmereUI, free slots, OneBag sections, bag swapping and drag position (" .. (forever and "forever" or "retail") .. ")")
