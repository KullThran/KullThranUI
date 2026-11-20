local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local pcall = pcall
local ipairs = ipairs
local type = type
local hooksecurefunc = hooksecurefunc
local math_abs = math.abs
local table_concat = table.concat
local CreateFrame = CreateFrame

-- Loot Rolls window (GroupLootHistoryFrame) in KUI style. Blizzard only shows who rolled what in a tooltip, so
-- every item card here lists the rolls under the item: one line per Need / Greed / Transmog roll with its number,
-- then one line with the players who passed and one with the players still deciding. The cards grow with that
-- list; the view's extent calculator is swapped for one that measures it. Blizzard keeps every handler.
local WINDOW_WIDTH = 300
local MIN_HEIGHT, MAX_HEIGHT = 300, 900
local CARD_HEADER = 44
local LINE_HEIGHT = 15
local LIST_PADDING = 6
local ICON_SIZE = 32
local ROLL_ICON = 13
local NUMBER_WIDTH = 24
local BLIZZARD_FILL_WIDTH = 234
local WHITE = "Interface\\Buttons\\WHITE8x8"

local State = _G.Enum and _G.Enum.EncounterLootDropRollState or {}
local NEED_MAIN = State.NeedMainSpec or 0
local NEED_OFF = State.NeedOffSpec or 1
local TRANSMOG = State.Transmog or 2
local GREED = State.Greed or 3
local NO_ROLL = State.NoRoll or 4
local PASS = State.Pass or 5

local ROLL_ATLAS = {
    [NEED_MAIN] = "lootroll-icon-need",
    [NEED_OFF] = "lootroll-icon-need",
    [TRANSMOG] = "lootroll-icon-transmog",
    [GREED] = "lootroll-icon-greed",
    [PASS] = "lootroll-icon-pass",
}

local function ClassColor(class)
    local colors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local color = class and colors and colors[class]
    if color then return color.r, color.g, color.b end
    return 0.9, 0.9, 0.9
end

local function ColoredName(roll)
    local r, g, b = ClassColor(roll.playerClass)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, roll.playerName or "?")
end

local function QualityColor(link)
    if type(link) ~= "string" then return nil end
    local quality
    local getInfo = _G.C_Item and _G.C_Item.GetItemQualityByID
    if _G.GetItemInfo then quality = select(3, _G.GetItemInfo(link)) end
    if not quality and getInfo then quality = getInfo(link) end
    if type(quality) ~= "number" then return nil end
    local manager = _G.ColorManager
    local data = manager and manager.GetColorDataForItemQuality and manager.GetColorDataForItemQuality(quality)
    if data and data.color then return data.color:GetRGB() end
    local legacy = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality]
    if legacy then return legacy.r, legacy.g, legacy.b end
    return nil
end

local function GetDropInfo(encounterID, lootListKey)
    local api = _G.C_LootHistory
    if not (api and api.GetSortedInfoForDrop and encounterID and lootListKey) then return nil end
    local ok, info = pcall(api.GetSortedInfoForDrop, encounterID, lootListKey)
    if ok and type(info) == "table" then return info end
    return nil
end

-- The lines a card shows, in Blizzard's sort order (rolls first, highest number on top).
-- A roll above the winner's belongs to a player whose copy of the item went elsewhere: it stays, dimmed.
local function BuildLines(dropInfo)
    local lines = {}
    if not (dropInfo and type(dropInfo.rollInfos) == "table") then return lines end
    local winner = dropInfo.winner
    local passed, waiting = {}, {}
    for _, roll in ipairs(dropInfo.rollInfos) do
        local state = roll.state
        if state == PASS then
            passed[#passed + 1] = ColoredName(roll)
        elseif state == NO_ROLL then
            waiting[#waiting + 1] = ColoredName(roll)
        elseif state ~= nil then
            local dimmed = winner and not roll.isWinner and roll.roll and winner.roll and roll.roll > winner.roll
            lines[#lines + 1] = { kind = "roll", roll = roll, dimmed = dimmed and true or false }
        end
    end
    if #passed > 0 then
        lines[#lines + 1] = { kind = "list", atlas = ROLL_ATLAS[PASS], text = table_concat(passed, ", ") }
    end
    if #waiting > 0 and not winner and not dropInfo.allPassed then
        lines[#lines + 1] = { kind = "list", waiting = true, text = table_concat(waiting, ", ") }
    end
    return lines
end

local function CardHeight(lineCount)
    if lineCount <= 0 then return CARD_HEADER end
    return CARD_HEADER + lineCount * LINE_HEIGHT + LIST_PADDING
end

local function NewFont(parent, template, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    S:HandleFont(text)
    text:SetJustifyH(justify or "LEFT")
    if text.SetWordWrap then text:SetWordWrap(false) end
    return text
end

-- One reusable row of the roll list.
local function AcquireLine(card, index)
    local rows = card.KT_RollLines
    local row = rows[index]
    if row then return row end
    row = {}
    local y = -(CARD_HEADER + (index - 1) * LINE_HEIGHT)

    row.highlight = card:CreateTexture(nil, "BORDER")
    row.highlight:SetTexture(WHITE)
    row.highlight:SetPoint("TOPLEFT", card, "TOPLEFT", 6, y)
    row.highlight:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, y)
    row.highlight:SetHeight(LINE_HEIGHT)

    row.icon = card:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROLL_ICON, ROLL_ICON)
    row.icon:SetPoint("LEFT", card, "TOPLEFT", 12, y - LINE_HEIGHT / 2)

    row.number = NewFont(card, nil, "RIGHT")
    row.number:SetWidth(NUMBER_WIDTH)
    row.number:SetPoint("LEFT", row.icon, "RIGHT", 2, 0)

    row.name = NewFont(card)
    row.name:SetPoint("LEFT", row.number, "RIGHT", 7, 0)

    row.check = card:CreateTexture(nil, "ARTWORK")
    row.check:SetAtlas("lootroll-icon-checkmark", true)
    row.check:SetPoint("LEFT", row.name, "RIGHT", 4, 0)

    -- Pass and waiting lists: one line each, cut with an ellipsis (the tooltip still lists everybody).
    row.list = NewFont(card)
    row.list:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.list:SetPoint("RIGHT", card, "RIGHT", -10, 0)

    rows[index] = row
    return row
end

local function HideLine(row)
    row.highlight:Hide(); row.icon:Hide(); row.number:Hide(); row.name:Hide(); row.check:Hide(); row.list:Hide()
end

local function FitName(card, row)
    local text = row.name
    text:SetWidth(0)
    local available = card:GetWidth() - (12 + ROLL_ICON + 2 + NUMBER_WIDTH + 7) - 30
    local width = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth()
    if available > 20 and width > available then text:SetWidth(available) end
end

local function PaintLine(card, row, line)
    HideLine(row)
    if line.kind == "roll" then
        local roll = line.roll
        local atlas = ROLL_ATLAS[roll.state]
        if atlas then row.icon:SetAtlas(atlas); row.icon:Show() end
        row.number:SetText(roll.roll and tostring(roll.roll) or "")
        if roll.isWinner then
            local accent = S:GetAccentColor()
            row.number:SetTextColor(accent[1], accent[2], accent[3])
            row.highlight:SetVertexColor(accent[1], accent[2], accent[3], 0.16)
            row.highlight:Show()
        else
            row.number:SetTextColor(S.NEUTRO.text[1], S.NEUTRO.text[2], S.NEUTRO.text[3])
        end
        row.number:Show()
        local name = ColoredName(roll)
        if roll.state == NEED_OFF and _G.LOOT_HISTORY_OFF_SPEC_FMT then
            name = _G.LOOT_HISTORY_OFF_SPEC_FMT:format(name)
        end
        row.name:SetText(name)
        row.name:Show()
        FitName(card, row)
        row.check:SetShown(roll.isWinner and true or false)
        local alpha = line.dimmed and 0.45 or 1
        row.icon:SetAlpha(alpha); row.number:SetAlpha(alpha); row.name:SetAlpha(alpha)
    else
        if line.atlas then
            row.icon:SetAtlas(line.atlas)
            row.icon:SetAlpha(0.8)
            row.icon:Show()
        end
        local label = line.waiting and (_G.LOOT_HISTORY_WAITING_ON or "Waiting on: ") or ""
        row.list:SetText(label .. line.text)
        if line.waiting then
            local dim = S.NEUTRO.disabledText
            row.list:SetTextColor(dim[1], dim[2], dim[3])
        else
            row.list:SetTextColor(S.NEUTRO.text[1], S.NEUTRO.text[2], S.NEUTRO.text[3])
        end
        row.list:SetAlpha(1)
        row.list:Show()
    end
end

local function PaintCardBorder(card, hovered)
    local backdrop = card.KT_CardBackdrop
    if not backdrop then return end
    local color = hovered and S:GetAccentColor() or S.NEUTRO.border
    backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

local refreshPending = false
local function QueueFullRefresh()
    if refreshPending then return end
    refreshPending = true
    _G.C_Timer.After(0, function()
        refreshPending = false
        local window = _G.GroupLootHistoryFrame
        if window and window:IsShown() and window.GetSelectedEncounterID and window:GetSelectedEncounterID()
            and window.DoFullRefresh then
            window:DoFullRefresh()
        end
    end)
end

local function UpdateCard(card)
    local dropInfo = card.dropInfo
    if not dropInfo then return end

    local r, g, b = QualityColor(dropInfo.itemHyperlink)
    local icon = card.Item
    if icon and icon.backdrop then
        if r then icon.backdrop:SetBackdropBorderColor(r, g, b, 1) else S:ApplyBorderColor(icon.backdrop) end
    end
    if card.KT_QualityStripe then
        card.KT_QualityStripe:SetVertexColor(r or 0.5, g or 0.5, b or 0.5, 1)
    end

    local lines = BuildLines(dropInfo)
    for index, line in ipairs(lines) do PaintLine(card, AcquireLine(card, index), line) end
    for index = #lines + 1, #card.KT_RollLines do HideLine(card.KT_RollLines[index]) end

    -- A new roll can add a line after the view sized the card: let Blizzard rebuild the list once.
    if card ~= (_G.GroupLootHistoryFrame and _G.GroupLootHistoryFrame.PerfectAnimFrame)
        and math_abs(card:GetHeight() - CardHeight(#lines)) > 1 then
        QueueFullRefresh()
    end
end

local function PlaceStatus(card, info)
    if not info then return end
    info:ClearAllPoints()
    info:SetPoint("RIGHT", card, "TOPRIGHT", -10, -31)
end

local function SkinCard(card)
    if not card or card.KT_LootHistorySkinned then return end
    card.KT_LootHistorySkinned = true
    card.KT_RollLines = {}

    local art = card.BackgroundArtFrame
    if art then S:StripTextures(art, true) end

    S:CreateBackdrop(card)
    local backdrop = card.backdrop
    if backdrop then
        backdrop:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
        backdrop:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
        backdrop:SetBackdropColor(0, 0, 0, 0)
        if KT.Surface then KT.Surface:Apply(backdrop, "inset") end
        card.KT_CardBackdrop = backdrop
        PaintCardBorder(card, false)
    end

    local stripe = card:CreateTexture(nil, "BORDER")
    stripe:SetTexture(WHITE)
    stripe:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    stripe:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 1, 1)
    stripe:SetWidth(2)
    card.KT_QualityStripe = stripe

    local item = card.Item
    if item then
        item:ClearAllPoints()
        item:SetSize(ICON_SIZE, ICON_SIZE)
        item:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -6)
        if item.IconBorder then item.IconBorder:SetAlpha(0) end
        if item.IconOverlay then item.IconOverlay:SetAlpha(0) end
        local normal = item.GetNormalTexture and item:GetNormalTexture()
        if normal then normal:SetAlpha(0) end
        local icon = item.icon or item.Icon
        if icon then
            icon:ClearAllPoints()
            icon:SetAllPoints(item)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        S:CreateBackdrop(item)
    end

    local name = card.ItemName
    if name then
        S:HandleFont(name)
        name:ClearAllPoints()
        name:SetPoint("TOPLEFT", item or card, item and "TOPRIGHT" or "TOPLEFT", 8, -2)
        name:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        name:SetHeight(14)
        name:SetJustifyH("LEFT")
        if name.SetWordWrap then name:SetWordWrap(false) end
    end

    local winning = card.WinningRollInfo
    if winning then
        PlaceStatus(card, winning)
        if winning.WinningRoll then S:HandleFont(winning.WinningRoll) end
    end
    local pending = card.PendingRollInfo
    if pending then
        PlaceStatus(card, pending)
        local text = pending.CurrentWinnerText
        if text then
            S:HandleFont(text)
            local dim = S.NEUTRO.disabledText
            text:SetTextColor(dim[1], dim[2], dim[3])
        end
    end
    local passed = card.AllPassedInfo
    if passed then
        PlaceStatus(card, passed)
        if passed.AllPassedText then
            S:HandleFont(passed.AllPassedText)
            passed.AllPassedText:SetTextColor(1, 0.3, 0.3)
        end
    end

    -- "You rolled Need/Greed" badge: smaller, on the icon's corner.
    local badge = card.PlayerRoll
    if badge and item then
        badge:ClearAllPoints()
        badge:SetSize(22, 20)
        badge:SetPoint("CENTER", item, "TOPLEFT", 2, -2)
        if badge.PlayerRollIcon then badge.PlayerRollIcon:SetSize(22, 20) end
    end

    card:HookScript("OnEnter", function(self) PaintCardBorder(self, true) end)
    card:HookScript("OnLeave", function(self) PaintCardBorder(self, false) end)
    hooksecurefunc(card, "Init", UpdateCard)
    S:RegisterBlizzardAccentRefresh(card, UpdateCard)
    if card.dropInfo then UpdateCard(card) end
end

local function SkinPassedHeader(frame)
    if not frame or frame.KT_LootHistorySkinned then return end
    frame.KT_LootHistorySkinned = true
    S:HandleFont(frame)
end

local function OnAcquired(_, frame)
    if not frame then return end
    if frame.Item and frame.ItemName then SkinCard(frame) else SkinPassedHeader(frame) end
end

-- Taller cards for the roll list; the "Passed" header and its spacer keep Blizzard's sizes.
local function InstallExtentCalculator(scrollBox)
    local view = scrollBox and scrollBox.GetView and scrollBox:GetView()
    if not (view and view.SetElementExtentCalculator) then return end
    local original = view.GetElementExtentCalculator and view:GetElementExtentCalculator()
    view:SetElementExtentCalculator(function(dataIndex, elementData)
        if elementData and elementData.lootListKey then
            local dropInfo = GetDropInfo(elementData.encounterID, elementData.lootListKey)
            return CardHeight(#BuildLines(dropInfo))
        end
        if original then return original(dataIndex, elementData) end
        return 14
    end)
end

local function PaintTimer(window)
    local timer = window.Timer
    local fill = timer and timer.Fill
    if not fill then return end
    local accent = S:GetAccentColor()
    fill:SetVertexColor(accent[1], accent[2], accent[3], 1)
end

local function SkinTimer(window)
    local timer = window.Timer
    if not timer then return end
    timer:ClearAllPoints()
    timer:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -62)
    timer:SetPoint("TOPRIGHT", window, "TOPRIGHT", -10, -62)
    timer:SetHeight(6)
    if timer.Background then timer.Background:SetAlpha(0) end
    if timer.Border then timer.Border:SetAlpha(0) end
    S:CreateBackdrop(timer, true)
    if timer.backdrop then timer.backdrop:SetBackdropColor(0, 0, 0, 0.6) end

    local fill = timer.Fill
    if fill then
        fill:SetTexture(WHITE)
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT", timer, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMLEFT", timer, "BOTTOMLEFT", 0, 0)
    end
    PaintTimer(window)

    -- Blizzard sizes the fill for its 234 px bar; stretch that share over this bar.
    if window.UpdateTimer then
        hooksecurefunc(window, "UpdateTimer", function(self)
            local bar = self.Timer and self.Timer.Fill
            if not (bar and bar:IsShown()) then return end
            local share = bar:GetWidth() / BLIZZARD_FILL_WIDTH
            if share > 1 then share = 1 end
            bar:SetWidth(math.max(0.01, share * self.Timer:GetWidth()))
        end)
    end
end

local function SkinResizeButton(window)
    local button = window.ResizeButton
    if not button then return end
    S:StripTextures(button, true)
    button:ClearAllPoints()
    button:SetSize(36, 10)
    button:SetPoint("BOTTOM", window, "BOTTOM", 0, 1)
    local grip = button:CreateTexture(nil, "OVERLAY")
    grip:SetTexture(WHITE)
    grip:SetSize(28, 2)
    grip:SetPoint("CENTER", button, "CENTER", 0, 0)
    local function Paint(hovered)
        local c = hovered and S:GetAccentColor() or S.NEUTRO.border
        grip:SetVertexColor(c[1], c[2], c[3], 1)
    end
    Paint(false)
    button:HookScript("OnEnter", function() Paint(true) end)
    button:HookScript("OnLeave", function() Paint(false) end)
end

local function SkinWindow(window)
    if not window or window.KT_LootHistorySkinned then return end
    if window.IsForbidden and window:IsForbidden() then return end
    window.KT_LootHistorySkinned = true

    S:SkinPremiumWindow(window)
    -- The flat panel's own background frame sits under the window; the KUI surface replaces it.
    if window.Bg then window.Bg:SetAlpha(0) end
    if window.TitleContainer then
        S:StripTextures(window.TitleContainer, true)
        if window.TitleContainer.TitleText then S:HandleFont(window.TitleContainer.TitleText) end
    end
    if window.ClosePanelButton then S:HandleCloseButton(window.ClosePanelButton) end

    window:SetWidth(WINDOW_WIDTH)
    if window.SetResizeBounds then
        window:SetResizeBounds(WINDOW_WIDTH, MIN_HEIGHT, WINDOW_WIDTH, MAX_HEIGHT)
    end

    local dropdown = window.EncounterDropdown
    if dropdown then
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOP", window, "TOP", 0, -30)
        S:HandleDropDownBox(dropdown, WINDOW_WIDTH - 20)
    end

    SkinTimer(window)

    local scrollBox = window.ScrollBox
    if scrollBox then
        scrollBox:ClearAllPoints()
        scrollBox:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -72)
        scrollBox:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -20, 12)
        InstallExtentCalculator(scrollBox)
        if _G.ScrollUtil and _G.ScrollUtil.AddAcquiredFrameCallback then
            _G.ScrollUtil.AddAcquiredFrameCallback(scrollBox, OnAcquired, window, true)
        end
    end
    local scrollBar = window.ScrollBar
    if scrollBar and scrollBox then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -4)
        scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 4)
        S:HandleScrollBar(scrollBar)
    end

    if window.NoInfoString then
        S:HandleFont(window.NoInfoString)
        local dim = S.NEUTRO.disabledText
        window.NoInfoString:SetTextColor(dim[1], dim[2], dim[3])
        window.NoInfoString:SetWidth(WINDOW_WIDTH - 40)
    end

    SkinResizeButton(window)
    -- The 100-roll animation is a copy of a card laid over the real one.
    SkinCard(window.PerfectAnimFrame)

    S:RegisterBlizzardAccentRefresh(window, PaintTimer)
    if window:IsShown() and window.DoFullRefresh and window.GetSelectedEncounterID and window:GetSelectedEncounterID() then
        window:DoFullRefresh()
    end
end

-- The window lives in FrameXML on Forever and in a load-on-demand panel addon on some Retail builds.
local watcher
local function SkinLootHistory()
    local window = _G.GroupLootHistoryFrame
    if window then
        SkinWindow(window)
        if watcher then watcher:UnregisterAllEvents() end
        return
    end
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:RegisterEvent("ADDON_LOADED")
        watcher:SetScript("OnEvent", function()
            if _G.GroupLootHistoryFrame and S:IsWindowEnabled("loothistory") then SkinLootHistory() end
        end)
    end
end

S:RegisterWindow("loothistory", { label = "Loot History", name = "LootHistory", apply = SkinLootHistory })
