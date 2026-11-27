-- Modules/Tooltip/TooltipPreview.lua
-- The Tooltip options page's live preview: the player tooltip, one of your
-- equipped items and one of your spells, side by side in one panel. Item and
-- spell use the client's real tooltip text plus the module's information block,
-- so every switch on the page shows up here at once. When the card style is on
-- (KT.TooltipCard), item and spell are drawn as cards.
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Preview = {}
KT.TooltipPreview = Preview

local _G = _G
local floor, max, min = math.floor, math.max, math.min
-- Same icon size and place as the live tooltip (Tooltip.lua).
local ICON_SIZE, ICON_INSET, ICON_GAP = 32, 6, 6
local format, tostring, type, pcall = string.format, tostring, type, pcall
local issecretvalue = _G.issecretvalue

local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

local function IsSecret(value)
    return issecretvalue ~= nil and value ~= nil and issecretvalue(value) == true
end

local WHITE = { 1, 1, 1 }
local SECTION = "|cff00ccff"
local LABEL = "|cffffd100"
local SPELL_BORDER = { 0.2, 0.6, 1 }
local SELL_PRICE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice or 11
local CARD_WIDTH = 290

local function DB()
    return KT.db and KT.db.profile and KT.db.profile.tooltip or {}
end

local function Clean(text)
    if type(text) ~= "string" or IsSecret(text) then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text or nil
end

local function ColorOf(color, fallback)
    if type(color) == "table" and not IsSecret(color) then
        if color.GetRGB then
            local ok, r, g, b = pcall(color.GetRGB, color)
            if ok and r and not IsSecret(r) then return { r, g, b } end
        elseif color.r and not IsSecret(color.r) then
            return { color.r, color.g, color.b }
        end
    end
    return { fallback[1], fallback[2], fallback[3] }
end

-- Tooltip data lines as { left, right, lc, rc, price, blank }; nil on secret data.
local function ReadLines(data)
    if type(data) ~= "table" or IsSecret(data) or type(data.lines) ~= "table" then return nil end
    local out = {}
    for _, line in ipairs(data.lines) do
        if type(line) ~= "table" or IsSecret(line) then return nil end
        local price = line.type == SELL_PRICE_TYPE and tonumber(line.price) or nil
        out[#out + 1] = {
            left = Clean(line.leftText),
            right = Clean(line.rightText),
            lc = ColorOf(line.leftColor, WHITE),
            rc = ColorOf(line.rightColor, WHITE),
            price = price,
            blank = not (line.leftText or line.rightText or price),
        }
    end
    return out[1] and out[1].left and out or nil
end

-- The module's information block as tooltip lines.
local function InfoLines(title, rows)
    local lines = {}
    if not rows or #rows == 0 then return lines end
    lines[1] = { left = SECTION .. LText(title) .. "|r", lc = WHITE, rc = WHITE }
    for _, row in ipairs(rows) do
        lines[#lines + 1] = { left = LABEL .. LText(row[1]) .. "|r", right = row[2], lc = WHITE, rc = WHITE }
    end
    return lines
end

-- ---------------------------------------------------------------- samples
local EQUIP_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function EquippedSlots()
    local out = {}
    if not _G.GetInventoryItemLink then return out end
    for _, slot in ipairs(EQUIP_SLOTS) do
        local ok, link = pcall(GetInventoryItemLink, "player", slot)
        if ok and type(link) == "string" and not IsSecret(link) then out[#out + 1] = slot end
    end
    return out
end

local function SpellbookSpells()
    local active, passive = {}, {}
    local function Add(id, isPassive)
        id = tonumber(id)
        if not id or IsSecret(id) then return end
        if isPassive then passive[#passive + 1] = id else active[#active + 1] = id end
    end
    local book = _G.C_SpellBook
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
        local okCount, count = pcall(book.GetNumSpellBookSkillLines)
        for i = 1, (okCount and tonumber(count) or 0) do
            local okLine, line = pcall(book.GetSpellBookSkillLineInfo, i)
            if okLine and type(line) == "table" and not line.offSpecID and not line.isGuild then
                local first = (line.itemIndexOffset or 0) + 1
                for j = first, first + (line.numSpellBookItems or 0) - 1 do
                    local okItem, item = pcall(book.GetSpellBookItemInfo, j, bank)
                    if okItem and type(item) == "table" and item.itemType == spellType and not item.isOffSpec then
                        Add(item.spellID or item.actionID, item.isPassive)
                    end
                end
            end
        end
    elseif _G.GetNumSpellTabs and _G.GetSpellTabInfo and _G.GetSpellBookItemInfo then
        local okTabs, tabs = pcall(GetNumSpellTabs)
        for i = 1, (okTabs and tonumber(tabs) or 0) do
            local okTab, _, _, offset, numSlots = pcall(GetSpellTabInfo, i)
            if okTab then
                for j = (offset or 0) + 1, (offset or 0) + (numSlots or 0) do
                    local okItem, kind, id = pcall(GetSpellBookItemInfo, j, _G.BOOKTYPE_SPELL or "spell")
                    if okItem and kind == "SPELL" then
                        local isPassive = _G.IsPassiveSpell and select(2, pcall(IsPassiveSpell, id)) == true
                        Add(id, isPassive)
                    end
                end
            end
        end
    end
    return #active > 0 and active or passive
end

local function PickOne(list, previous)
    if #list == 0 then return nil end
    if #list == 1 then return list[1] end
    local pick
    for _ = 1, 8 do
        pick = list[math.random(#list)]
        if pick ~= previous then break end
    end
    return pick
end

local function Pick(previous)
    previous = previous or {}
    return { slot = PickOne(EquippedSlots(), previous.slot), spell = PickOne(SpellbookSpells(), previous.spell) }
end

local function ItemMeta(link)
    local Info = KT.TooltipInfo
    local Safe = Info and Info.Safe or function(f, ...) if f then return f(...) end end
    local instant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    local _, itemType, subType, equipLoc, icon = Safe(instant, link)
    local _, _, _, itemLevel = Safe(getInfo, link)
    local detailed = Safe((C_Item and C_Item.GetDetailedItemLevelInfo) or _G.GetDetailedItemLevelInfo, link)
    local meta = { icon = icon, itemType = itemType, subType = subType, itemLevel = tonumber(detailed) or itemLevel }
    if type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        meta.equippable = equipLoc ~= "INVTYPE_BAG" and equipLoc ~= "INVTYPE_QUIVER"
        meta.equipName = _G[equipLoc]
    end
    return meta
end

local function ItemSample(slot)
    if not slot or not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local okLink, link = pcall(GetInventoryItemLink, "player", slot)
    if not okLink or type(link) ~= "string" or IsSecret(link) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
    local lines = ok and ReadLines(data)
    if not lines then return nil end
    local Info = KT.TooltipInfo
    local quality = (C_Item and C_Item.GetItemQualityByID) and select(2, pcall(C_Item.GetItemQualityByID, link))
    local border = WHITE
    if tonumber(quality) and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then border = { r, g, b } end
    end
    return {
        kind = "item", lines = lines, meta = ItemMeta(link), border = border,
        extras = InfoLines("Item information", Info and Info:ItemRows(link) or {}),
    }
end

local function SpellIcon(spellID)
    return (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID))
        or (_G.GetSpellTexture and _G.GetSpellTexture(spellID))
end

local function SpellSample(spellID)
    if not spellID or not (C_TooltipInfo and C_TooltipInfo.GetSpellByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetSpellByID, spellID)
    local lines = ok and ReadLines(data)
    if not lines then return nil end
    local Info = KT.TooltipInfo
    local okIcon, icon = pcall(SpellIcon, spellID)
    return {
        kind = "spell", lines = lines, meta = { icon = okIcon and icon or nil }, border = SPELL_BORDER,
        extras = InfoLines("Spell information", Info and Info:SpellRows(spellID) or {}),
    }
end

-- Shown before any item or spell can be read (nothing equipped, data not loaded).
local function FallbackName(itemID, spellID, fallback)
    local Safe = KT.TooltipInfo and KT.TooltipInfo.Safe
    local name
    if Safe and itemID then
        name = Safe(C_Item and C_Item.GetItemNameByID, itemID) or Safe(_G.GetItemInfo, itemID)
    elseif Safe and spellID then
        name = Safe(C_Spell and C_Spell.GetSpellName, spellID) or Safe(_G.GetSpellInfo, spellID)
    end
    return Clean(name) or LText(fallback)
end

local function FallbackSamples()
    local Info = KT.TooltipInfo
    local item = {
        kind = "item", border = WHITE,
        lines = {
            { left = FallbackName(6948, nil, "Hearthstone"), lc = WHITE },
            { left = _G.ITEM_SOULBOUND or _G.ITEM_BIND_ON_PICKUP, lc = WHITE },
        },
        meta = { icon = "Interface\\Icons\\INV_Misc_Rune_01" },
        extras = InfoLines("Item information", Info and Info:ItemRows("item:6948") or {}),
    }
    local spell = {
        kind = "spell", border = SPELL_BORDER,
        lines = {
            { left = FallbackName(nil, 6603, "Auto Attack"), lc = WHITE },
            { left = _G.SPELL_CAST_TIME_INSTANT or _G.SPELL_CAST_TIME_INSTANT_NO_MANA, lc = WHITE },
        },
        meta = { icon = "Interface\\Icons\\INV_Sword_04" },
        extras = InfoLines("Spell information", Info and Info:SpellRows(6603) or {}),
    }
    return item, spell
end

-- ---------------------------------------------------------------- the module's usual skin
-- One screen pixel in the panel's units. With the UI scale and the preview's own scale a
-- UI unit is less than a pixel, so a 1-unit inset let the fill cover the border on one side.
local function OnePixel(frame)
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale()
    local pixelUtil = _G.PixelUtil
    if type(scale) == "number" and scale > 0 and pixelUtil and pixelUtil.GetNearestPixelSize then
        local ok, size = pcall(pixelUtil.GetNearestPixelSize, 1, scale, 1)
        if ok and type(size) == "number" and size > 0 then return size end
    end
    return 1
end

-- The fill sits one pixel inside the border on every side.
local function PixelInset(panel)
    local px = OnePixel(panel)
    if panel.insetPx == px then return end
    panel.insetPx = px
    panel.bg:ClearAllPoints()
    panel.bg:SetPoint("TOPLEFT", px, -px)
    panel.bg:SetPoint("BOTTOMRIGHT", -px, px)
end

local function NewPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel.texts, panel.used = {}, 0
    panel.border = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    panel.border:SetAllPoints()
    panel.bg = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    panel.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    PixelInset(panel)
    panel.iconEdge = panel:CreateTexture(nil, "ARTWORK", nil, 0)
    panel.iconEdge:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    panel.iconEdge:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -ICON_INSET + 1, -ICON_INSET + 1)
    panel.icon = panel:CreateTexture(nil, "ARTWORK", nil, 1)
    panel.icon:SetSize(ICON_SIZE, ICON_SIZE)
    panel.icon:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -ICON_INSET, -ICON_INSET)
    panel.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return panel
end

local function PanelText(panel, font, size, color, justify)
    panel.used = panel.used + 1
    local text = panel.texts[panel.used]
    if not text then
        text = panel:CreateFontString(nil, "OVERLAY")
        text:SetShadowColor(0, 0, 0, 0.9)
        text:SetShadowOffset(1, -1)
        panel.texts[panel.used] = text
    end
    text:SetFont(font, size, "")
    text:SetTextColor(color[1], color[2], color[3], 1)
    text:SetJustifyH(justify)
    text:SetWordWrap(true)
    text:SetWidth(0)
    text:ClearAllPoints()
    text:Show()
    return text
end

local function CoinText(copper)
    if _G.GetMoneyString then
        local ok, text = pcall(GetMoneyString, copper, true)
        if ok and text then return text end
    end
    return tostring(copper)
end

-- Draws sample as the Tooltip module draws it in game; returns width, height.
local function RenderSkin(panel, sample)
    for _, text in ipairs(panel.texts) do text:Hide() end
    panel.used = 0
    local textFont, textSize = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12
    local headFont, headSize = textFont, 14
    if _G.GameTooltipText and GameTooltipText.GetFont then textFont, textSize = GameTooltipText:GetFont() end
    if _G.GameTooltipHeaderText and GameTooltipHeaderText.GetFont then headFont, headSize = GameTooltipHeaderText:GetFont() end
    textSize, headSize = floor((textSize or 12) + 0.5), floor((headSize or 14) + 0.5)
    local pad, gap, maxW, minW = 10, 2, 300, 170

    local rows = {}
    for index, line in ipairs(sample.lines) do
        if line.price then
            rows[#rows + 1] = { left = (_G.SELL_PRICE or "Sell Price") .. ": " .. CoinText(line.price), lc = WHITE }
        elseif line.blank then
            rows[#rows + 1] = { blank = true }
        else
            rows[#rows + 1] = { left = line.left, right = line.right, lc = line.lc, rc = line.rc, header = index == 1 }
        end
    end
    if sample.extras and #sample.extras > 0 then
        rows[#rows + 1] = { blank = true }
        for _, line in ipairs(sample.extras) do rows[#rows + 1] = line end
    end

    -- The icon sits inside the top-right corner; the lines beside it keep clear of it.
    local icon = sample.meta and sample.meta.icon
    local showIcon = icon and (not KT.TooltipInfo or KT.TooltipInfo:IsShown("showIcon"))
    local iconZone = showIcon and (ICON_INSET + ICON_SIZE + 2) or 0
    local iconRoom = ICON_SIZE + ICON_INSET + ICON_GAP - pad

    local natural = minW
    local yy = pad
    for _, row in ipairs(rows) do
        if row.blank then
            yy = yy + textSize * 0.6
        else
            local font, size = row.header and headFont or textFont, row.header and headSize or textSize
            row.l = row.left and PanelText(panel, font, size, row.lc or WHITE, "LEFT")
            row.r = row.right and PanelText(panel, font, size, row.rc or WHITE, "RIGHT")
            if row.l then row.l:SetText(row.left) end
            if row.r then row.r:SetText(row.right) end
            row.beside = yy < iconZone
            local w = (row.l and row.l:GetStringWidth() or 0) + (row.r and row.r:GetStringWidth() + 20 or 0)
                + (row.beside and iconRoom or 0)
            natural = max(natural, min(maxW - pad * 2, w) + pad * 2)
            yy = yy + max(row.l and row.l:GetStringHeight() or 0, row.r and row.r:GetStringHeight() or 0) + gap
        end
    end
    local w = floor(min(maxW, natural) + 0.5)
    local y = pad
    for _, row in ipairs(rows) do
        if row.blank then
            y = y + textSize * 0.6
        else
            local room = y < iconZone and iconRoom or 0
            local lineH, avail = 0, w - pad * 2 - room
            if row.r then
                row.r:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad - room, -y)
                avail = max(40, avail - row.r:GetStringWidth() - 12)
                lineH = row.r:GetStringHeight()
            end
            if row.l then
                row.l:SetWidth(avail)
                row.l:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y)
                lineH = max(lineH, row.l:GetStringHeight())
            end
            y = y + lineH + gap
        end
    end
    local h = floor(y - gap + pad + 0.5)
    if showIcon then h = max(h, ICON_SIZE + ICON_INSET * 2) end

    local border = sample.border or WHITE
    panel.border:SetColorTexture(border[1], border[2], border[3], 1)
    panel.iconEdge:SetColorTexture(border[1], border[2], border[3], 1)
    panel.iconEdge:SetShown(showIcon and true or false)
    panel.icon:SetShown(showIcon and true or false)
    if showIcon then panel.icon:SetTexture(icon) end
    return w, h
end

-- ---------------------------------------------------------------- card style
local function CardActive()
    local Card = KT.TooltipCard
    return Card and Card.Render and Card.ModelFor and DB().cardStyle == true
end

local function RenderCard(holder, index, sample)
    local Card = KT.TooltipCard
    holder.kuiTTCards = holder.kuiTTCards or {}
    local frame = holder.kuiTTCards[index]
    if not frame then
        frame = Card:CreateFrame(holder)
        holder.kuiTTCards[index] = frame
    end
    local ok, h = pcall(function()
        local model = Card:ModelFor(sample)
        return model and Card:Render(frame, model, CARD_WIDTH)
    end)
    if not ok or not h then return nil end
    return frame, CARD_WIDTH, h
end

-- ---------------------------------------------------------------- layout
-- Draws the preview inside holder.
-- opts.lead: { frame, width, height } drawn first (the player tooltip).
-- opts.width / opts.height: the space to fill; everything scales down to fit.
-- opts.reshuffle: pick another item and spell.
function Preview:Draw(holder, opts)
    opts = opts or {}
    if opts.reshuffle or not holder.kuiTTPick then holder.kuiTTPick = Pick(holder.kuiTTPick) end
    holder.kuiTTPanels = holder.kuiTTPanels or { NewPanel(holder), NewPanel(holder) }
    local fallbackItem, fallbackSpell = FallbackSamples()
    local samples = {
        ItemSample(holder.kuiTTPick.slot) or fallbackItem,
        SpellSample(holder.kuiTTPick.spell) or fallbackSpell,
    }

    local entries = {}
    if opts.lead and opts.lead.frame then
        entries[#entries + 1] = { frame = opts.lead.frame, w = opts.lead.width, h = opts.lead.height }
    end
    local cards = CardActive()
    for i, sample in ipairs(samples) do
        local panel = holder.kuiTTPanels[i]
        local frame, w, h
        if cards then frame, w, h = RenderCard(holder, i, sample) end
        if frame then
            panel:Hide()
        else
            if holder.kuiTTCards and holder.kuiTTCards[i] then holder.kuiTTCards[i]:Hide() end
            frame = panel
            w, h = RenderSkin(panel, sample)
        end
        frame:SetSize(w, h)
        entries[#entries + 1] = { frame = frame, w = w, h = h }
    end

    local width = opts.width or holder:GetWidth() or 600
    local height = opts.height or holder:GetHeight() or 300
    local gap, top, bottom, side = 22, cards and 14 or 46, 14, 14
    local total, tallest = gap * (#entries - 1), 0
    for _, e in ipairs(entries) do
        total = total + e.w
        tallest = max(tallest, e.h)
    end
    local scale = min(1, (width - side * 2) / total, (height - top - bottom) / max(1, tallest))
    local x = (width - total * scale) / 2
    for _, e in ipairs(entries) do
        e.frame:SetScale(scale)
        e.frame:ClearAllPoints()
        e.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", x / scale, -top / scale)
        if e.frame.insetPx then PixelInset(e.frame) end
        e.frame:Show()
        x = x + (e.w + gap) * scale
    end
end
