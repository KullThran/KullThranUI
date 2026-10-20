-------------------------------------------------------------------------------
--  Bulk Buy: buy many of a vendor's items in one go.
--
--  Shift-click (the client's own "split stack" modifier) a stackable gold-priced
--  vendor item and a small panel opens above the merchant window instead of the
--  stock quantity box: a quantity field with - / + / Max / +1 Stack, the running
--  total, and a Buy button. Purchases are sent in stack-sized chunks a moment
--  apart so the server never throttles a big order.
--
--  Items that cost a currency or other items (extended cost) keep the stock
--  dialog. Works on Retail and on the Forever client (same API fallbacks).
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then return end

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer

local function Config()
    local db = Mod.GetDB and Mod:GetDB() or nil
    if not db then return { enable = true } end
    db.bulkBuy = db.bulkBuy or {}
    if db.bulkBuy.enable == nil then db.bulkBuy.enable = true end
    return db.bulkBuy
end

-------------------------------------------------------------------------------
--  Vendor data (Retail table API with the classic positional one as fallback)
-------------------------------------------------------------------------------
local function ItemData(index)
    local MerchantAPI = _G.C_MerchantFrame
    if MerchantAPI and MerchantAPI.GetItemInfo then
        local ok, info = pcall(MerchantAPI.GetItemInfo, index)
        if ok and type(info) == "table" and info.name then
            return {
                name = info.name, texture = info.texture, price = info.price or 0,
                bundle = max(1, info.stackCount or 1), available = info.numAvailable or -1,
                extended = info.hasExtendedCost and true or false,
                purchasable = info.isPurchasable ~= false,
            }
        end
    end
    if _G.GetMerchantItemInfo then
        local name, texture, price, quantity, available, purchasable, _, extended = _G.GetMerchantItemInfo(index)
        if name then
            return {
                name = name, texture = texture, price = price or 0, bundle = max(1, quantity or 1),
                available = available or -1, extended = extended and true or false,
                purchasable = purchasable ~= false,
            }
        end
    end
    return nil
end

local function FreeBagCapacity(index, maxStack)
    local container = _G.C_Container
    local free = 0
    for bag = 0, (_G.NUM_BAG_SLOTS or 4) do
        local slots, bagType
        if container and container.GetContainerNumFreeSlots then
            slots, bagType = container.GetContainerNumFreeSlots(bag)
        elseif _G.GetContainerNumFreeSlots then
            slots, bagType = _G.GetContainerNumFreeSlots(bag)
        end
        -- Only general-purpose bags: profession / reagent bags refuse most vendor goods.
        if slots and (bagType == nil or bagType == 0) then free = free + slots end
    end
    local capacity = free * maxStack
    -- Room left in a partially filled stack of the same item.
    local link = _G.GetMerchantItemLink and _G.GetMerchantItemLink(index)
    if link and maxStack > 1 then
        local count = (_G.C_Item and _G.C_Item.GetItemCount and _G.C_Item.GetItemCount(link))
            or (_G.GetItemCount and _G.GetItemCount(link)) or 0
        local rest = count % maxStack
        if rest > 0 then capacity = capacity + (maxStack - rest) end
    end
    return capacity
end

-- Highest quantity (in items) the player can buy right now.
local function MaxPurchasable(index, data, maxStack)
    local limit = FreeBagCapacity(index, maxStack)
    if data.price > 0 then
        local perItem = data.price / data.bundle
        limit = min(limit, floor((_G.GetMoney() or 0) / perItem))
    end
    if data.available and data.available >= 0 then
        limit = min(limit, data.available * data.bundle)
    end
    return max(0, limit)
end

local function TotalCost(data, count)
    return ceil(count / data.bundle) * data.price
end

-------------------------------------------------------------------------------
--  Buying
-------------------------------------------------------------------------------
local order  -- the purchase in progress: { index, remaining, chunk, ticker }

local function CancelOrder()
    if order and order.ticker then order.ticker:Cancel() end
    order = nil
end

local function SendChunk()
    if not order then return false end
    if not (_G.MerchantFrame and _G.MerchantFrame:IsShown()) or order.remaining <= 0 then
        CancelOrder()
        return false
    end
    local amount = min(order.remaining, order.chunk)
    _G.BuyMerchantItem(order.index, amount)
    order.remaining = order.remaining - amount
    if order.remaining <= 0 then
        CancelOrder()
        return false
    end
    return true
end

local function StartOrder(index, count, maxStack, bundle)
    CancelOrder()
    if count <= 0 then return end
    -- A purchase never exceeds one stack; bundles must stay whole.
    local chunk = max(bundle, floor(maxStack / bundle) * bundle)
    order = { index = index, remaining = count, chunk = chunk }
    if SendChunk() then
        order.ticker = C_Timer.NewTicker(0.18, function()
            if not SendChunk() then CancelOrder() end
        end)
    end
end

-------------------------------------------------------------------------------
--  Panel (a KUI-styled side panel to the right of the merchant window)
-------------------------------------------------------------------------------
local panel
local PRESETS = { 20, 50, 100, 200, 500, 999 }
local PANEL_WIDTH = 236
local INNER = PANEL_WIDTH - 28

local function Accent()
    return KT.C_R or 0.2, KT.C_G or 0.9, KT.C_B or 0.6
end

local function Skin(frame, bgAlpha, shade)
    if KT.AddBackdrop then KT:AddBackdrop(frame, 0.055, 0.058, 0.07, bgAlpha or 0.97) end
    if KT.AddBorder then
        local r, g, b = Accent()
        shade = shade or 0.55
        KT:AddBorder(frame, r * shade, g * shade, b * shade, 1)
    end
end

local function MakeButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height or 26)
    if KT.AddBackdrop then KT:AddBackdrop(button, 0.11, 0.115, 0.14, 1) end
    if KT.AddBorder then KT:AddBorder(button, 0, 0, 0, 1) end
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("CENTER")
    button.text:SetText(label)
    button:SetScript("OnEnter", function(self)
        local r, g, b = Accent()
        if KT.AddBorder then KT:AddBorder(self, r, g, b, 1) end
    end)
    button:SetScript("OnLeave", function(self)
        if KT.AddBorder then KT:AddBorder(self, 0, 0, 0, 1) end
    end)
    return button
end

local function CoinText(copper)
    return _G.GetCoinTextureString and _G.GetCoinTextureString(copper) or tostring(copper)
end

local function Refresh()
    if not (panel and panel.index) then return end
    local data = ItemData(panel.index)
    if not data then panel:Hide() return end
    panel.data = data
    panel.maxStack = max(1, (_G.GetMerchantItemMaxStack and _G.GetMerchantItemMaxStack(panel.index)) or 1)
    panel.maxCount = MaxPurchasable(panel.index, data, panel.maxStack)
    panel.count = max(0, min(panel.count or 0, panel.maxCount))
    panel.icon:SetTexture(data.texture)
    panel.itemName:SetText("(" .. (data.name or "") .. ")")
    panel.stackText:SetText("Max Stack: " .. panel.maxStack)
    panel.total:SetText("Total: " .. CoinText(TotalCost(data, panel.count)))
    if not panel.box:HasFocus() then panel.box:SetText(tostring(panel.count)) end
    panel.buy:SetAlpha(panel.count > 0 and 1 or 0.4)
    for _, button in ipairs(panel.presets) do
        button:SetAlpha(button.value <= panel.maxCount and 1 or 0.4)
    end
end

local function SetCount(value)
    if not panel then return end
    panel.count = max(0, min(floor(tonumber(value) or 0), panel.maxCount or 0))
    panel.box:SetText(tostring(panel.count))
    Refresh()
end

local function BuildPanel()
    if panel then return panel end
    panel = CreateFrame("Frame", "KT_BulkBuyFrame", _G.UIParent)
    panel:SetSize(PANEL_WIDTH, 316)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(50)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    Skin(panel)

    local r, g, b = Accent()
    local accentLine = panel:CreateTexture(nil, "OVERLAY")
    accentLine:SetColorTexture(r, g, b, 1)
    accentLine:SetPoint("TOPLEFT", 1, -1)
    accentLine:SetPoint("TOPRIGHT", -1, -1)
    accentLine:SetHeight(2)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOP", 0, -12)
    panel.title:SetText("Bulk Buy")

    local close = CreateFrame("Button", nil, panel)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -6, -8)
    close.text = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    close.text:SetPoint("CENTER")
    close.text:SetText("x")
    close:SetScript("OnClick", function() panel:Hide() end)

    -- Item
    local iconFrame = CreateFrame("Frame", nil, panel)
    iconFrame:SetSize(44, 44)
    iconFrame:SetPoint("TOP", 0, -38)
    if KT.AddBackdrop then KT:AddBackdrop(iconFrame, 0.02, 0.02, 0.03, 1) end
    if KT.AddBorder then KT:AddBorder(iconFrame, r * 0.55, g * 0.55, b * 0.55, 1) end
    panel.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    panel.icon:SetPoint("TOPLEFT", 2, -2)
    panel.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    panel.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    panel.itemName = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.itemName:SetPoint("TOP", iconFrame, "BOTTOM", 0, -8)
    panel.itemName:SetWidth(INNER)
    panel.itemName:SetWordWrap(false)

    panel.stackText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.stackText:SetPoint("TOP", panel.itemName, "BOTTOM", 0, -5)

    panel.total = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.total:SetPoint("TOP", panel.stackText, "BOTTOM", 0, -5)

    -- Quantity
    panel.box = CreateFrame("EditBox", nil, panel)
    panel.box:SetSize(INNER - 58, 26)
    panel.box:SetPoint("TOPLEFT", 14, -166)
    panel.box:SetFontObject("GameFontHighlight")
    panel.box:SetJustifyH("LEFT")
    panel.box:SetTextInsets(8, 8, 0, 0)
    panel.box:SetAutoFocus(false)
    panel.box:SetNumeric(true)
    panel.box:SetMaxLetters(5)
    if KT.AddBackdrop then KT:AddBackdrop(panel.box, 0.02, 0.02, 0.03, 1) end
    if KT.AddBorder then KT:AddBorder(panel.box, r * 0.55, g * 0.55, b * 0.55, 1) end
    panel.box:SetScript("OnEnterPressed", function(self)
        SetCount(self:GetText())
        self:ClearFocus()
    end)
    panel.box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        Refresh()
    end)
    panel.box:SetScript("OnTextChanged", function(self, user)
        if user and panel.data then
            panel.count = max(0, min(floor(tonumber(self:GetText()) or 0), panel.maxCount or 0))
            panel.total:SetText("Total: " .. CoinText(TotalCost(panel.data, panel.count)))
        end
    end)
    panel.box:EnableMouseWheel(true)
    panel.box:SetScript("OnMouseWheel", function(_, delta)
        SetCount((panel.count or 0) + delta * (_G.IsShiftKeyDown() and 10 or 1))
    end)

    panel.maxBtn = MakeButton(panel, "Max", 52, 26)
    panel.maxBtn:SetPoint("LEFT", panel.box, "RIGHT", 6, 0)
    panel.maxBtn:SetScript("OnClick", function() SetCount(panel.maxCount or 0) end)

    -- Presets, 3 x 2
    panel.presets = {}
    local gap, width = 6, floor((INNER - 12) / 3)
    for index, value in ipairs(PRESETS) do
        local button = MakeButton(panel, tostring(value), width, 26)
        local column, row = (index - 1) % 3, floor((index - 1) / 3)
        button:SetPoint("TOPLEFT", 14 + column * (width + gap), -204 - row * 32)
        button.value = value
        button:SetScript("OnClick", function() SetCount(min(value, panel.maxCount or 0)) end)
        panel.presets[index] = button
    end

    -- Buy
    panel.buy = CreateFrame("Button", nil, panel)
    panel.buy:SetSize(INNER, 32)
    panel.buy:SetPoint("BOTTOM", 0, 14)
    panel.buy.fill = panel.buy:CreateTexture(nil, "BACKGROUND")
    panel.buy.fill:SetAllPoints()
    panel.buy.fill:SetColorTexture(r * 0.8, g * 0.8, b * 0.8, 1)
    panel.buy.text = panel.buy:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.buy.text:SetPoint("CENTER")
    panel.buy.text:SetText("Buy")
    panel.buy.text:SetTextColor(1, 1, 1)
    panel.buy:SetScript("OnEnter", function(self) self.fill:SetColorTexture(r, g, b, 1) end)
    panel.buy:SetScript("OnLeave", function(self) self.fill:SetColorTexture(r * 0.8, g * 0.8, b * 0.8, 1) end)
    panel.buy:SetScript("OnClick", function()
        if not (panel.index and panel.count and panel.count > 0) then return end
        StartOrder(panel.index, panel.count, panel.maxStack or 1, panel.data and panel.data.bundle or 1)
        panel:Hide()
    end)

    panel:SetScript("OnHide", function() panel.index = nil end)
    panel:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_CLOSED" then
            self:Hide()
            CancelOrder()
        elseif self:IsShown() then
            Refresh()
        end
    end)
    for _, event in ipairs({ "MERCHANT_CLOSED", "MERCHANT_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_MONEY" }) do
        panel:RegisterEvent(event)
    end
    panel:Hide()
    return panel
end

local function Open(index)
    local data = ItemData(index)
    if not data or data.extended or not data.purchasable then return false end
    local maxStack = max(1, (_G.GetMerchantItemMaxStack and _G.GetMerchantItemMaxStack(index)) or 1)
    if maxStack <= 1 then return false end

    BuildPanel()
    panel.index = index
    panel.count = min(maxStack, MaxPurchasable(index, data, maxStack))
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", _G.MerchantFrame, "TOPRIGHT", 4, -20)
    panel:Show()
    Refresh()
    return true
end

-------------------------------------------------------------------------------
--  Hook the merchant's own modified click
-------------------------------------------------------------------------------
local hooked
local function Install()
    if hooked or not _G.MerchantItemButton_OnModifiedClick then return end
    hooked = true
    hooksecurefunc("MerchantItemButton_OnModifiedClick", function(self)
        if not Config().enable then return end
        if not (_G.MerchantFrame and _G.MerchantFrame.selectedTab == 1) then return end
        if not _G.IsModifiedClick("SPLITSTACK") then return end
        -- Shift-click that linked the item into an open chat box is not a purchase.
        if _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow() then return end
        if Open(self:GetID()) then
            if _G.StackSplitFrame and _G.StackSplitFrame:IsShown() and _G.StackSplitCancelButton_OnClick then
                pcall(_G.StackSplitCancelButton_OnClick)
            end
        end
    end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("MERCHANT_SHOW")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function() Install() end)
Install()

Mod.BulkBuy = { Open = Open, Config = Config }
