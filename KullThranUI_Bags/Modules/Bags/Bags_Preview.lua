-- Bags_Preview.lua
-- Purpose: the Bags options live preview. The bag window as you use it -
-- header icon buttons, search bar with the watched badge and bag slots, the
-- Categories sidebar, the grid with your own items in their categories and
-- the footer with slots, currencies and gold - built at the real window's
-- sizes (the width follows your columns, icon size and sidebar size) and
-- scaled down to fit the options page. The grid and the sidebar scroll with
-- the mouse wheel inside their panels.
--
-- Each part leads to its setting: hovering it draws an accent outline with a
-- hint, and a click scrolls the page to the option that changes it (the page
-- passes the handler through box:SetJumpHandler). It is painted by the
-- module's own code: Mod:ApplyPanelColor colours its panels and puts the frame
-- of the bag style picked on the Bags page, Mod:ApplySidebarRowVisual draws the
-- category rows, Mod:GetPreviewContents reads the backpack, and Mod.PreviewKit
-- lends the surface, icon and font helpers.

local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end
local Mod = KT.GetModule and KT:GetModule("Bags", true)
if not Mod then return end

local PREVIEW_WINDOW_HEIGHT = 440 -- the real default is 640: a shorter window
local PREVIEW_MAX_SCALE = 0.86
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function LText(text)
    if KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then return L[text] end
    end
    return text
end

local function Kit()
    return Mod.PreviewKit or {}
end

-- Shown when the bags cannot be read (or are empty): label key, fallback,
-- icon key (Bags.lua category icons), items { icon, count }.
local SAMPLE = {
    { "BAGS_CATEGORY_HEARTHSTONE", "Hearthstone", "default_hearthstone", { { 134414 } } },
    { "BAGS_CATEGORY_KEYSTONE", "Keystone", "default_keystone", { { 525134 } } },
    { "BAGS_CATEGORY_CONSUMABLE", "Consumable", "default_consumable", {
        { 134730, 158 }, { 134830, 3 }, { 134731, 20 }, { 133971, 20 }, { 7548911, 8 }, { 134877, 3 },
        { 133984, 4 }, { 135913, 2 }, { 236272, 35 }, { 134818, 5 }, { 134857, 36 }, { 134712, 19 },
        { 237446, 153 }, { 132932, 68 }, { 133975, 3 }, { 134760, 26 }, { 134766, 4 }, { 134799, 21 },
    } },
}

local SAMPLE_CURRENCIES = { { "Interface\\Icons\\INV_Misc_Coin_17", 75 }, { "Interface\\Icons\\Achievement_Arena_2v2_7", 1 } }
local SAMPLE_MONEY = 2555432020 -- 255,543g 20s 20c

-- The backpack as the window shows it, or the sample.
local function Contents()
    local live = Mod.GetPreviewContents and Mod:GetPreviewContents()
    if live then return live end
    local kit, Label = Kit(), Kit().Label or function(_, fallback) return fallback end
    local icons = kit.CATEGORY_ICONS or {}
    local categories, all, used = {}, {}, 0
    for index, def in ipairs(SAMPLE) do
        local icon = kit.GetCategoryIcon and kit.GetCategoryIcon(def[3]) or icons[def[3]]
        categories[index] = { label = Label(def[1], def[2]), icon = icon, items = def[4] }
        for _, item in ipairs(def[4]) do
            used = used + 1
            all[used] = item
        end
    end
    for slot = used + 1, 32 do all[slot] = {} end
    return { used = 156, free = 44, total = 200, watched = 0, categories = categories, all = all }
end

-- Tracked currencies (the backpack ones), or the sample.
local function Currencies(max)
    local list = {}
    local info = C_CurrencyInfo and C_CurrencyInfo.GetBackpackCurrencyInfo
    if info then
        for index = 1, max do
            local c = info(index)
            if not c then break end
            list[#list + 1] = { c.iconFileID, c.quantity }
        end
        return list
    end
    for index = 1, math.min(max, #SAMPLE_CURRENCIES) do list[index] = SAMPLE_CURRENCIES[index] end
    return list
end

local function Backdrop(frame, r, g, b, a, br, bg, bb, ba)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(br, bg, bb, ba or 1)
end

local function Accent()
    local kit = Kit()
    if kit.GetAccentColor then return kit.GetAccentColor() end
    return 1, 0.5, 0
end

local function Panel(parent, r, g, b, a, br, bg, bb, surface)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Backdrop(f, r, g, b, a, br, bg, bb)
    local kit = Kit()
    if kit.ApplyKuiSurface then kit.ApplyKuiSurface(f, "inset") end
    if surface and kit.ApplyAccentSurface then kit.ApplyAccentSurface(f, surface) end
    return f
end

-- A header or toolbar glyph button, painted like the window's own
-- (Bags.lua KT_Bags_PaintIconButton).
local function GlyphButton(parent, size, glyph)
    local kit = Kit()
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(size, size)
    Backdrop(f, 0.07, 0.07, 0.085, 0.92, 0.3, 0.3, 0.3)
    f.Icon = f:CreateTexture(nil, "OVERLAY")
    f.Icon:SetPoint("CENTER")
    f.Icon:SetSize(size - 4, size - 4)
    if kit.SetToolbarGlyph then kit.SetToolbarGlyph(f.Icon, glyph) end
    return f
end

local function IconButton(parent, size, icon)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(size, size)
    Backdrop(f, 0.025, 0.025, 0.032, 0.96, 0.3, 0.3, 0.3)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 3, -3)
    f.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    f.icon:SetTexture(icon)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return f
end

-- Hint under the cursor: what the part is and that a click leads to it.
local function ShowHint(owner, label)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(LText(label), 1, 1, 1)
    GameTooltip:AddLine(LText("Click to jump to its settings block."), 0.75, 0.82, 0.9, true)
    GameTooltip:Show()
end

local function HideHint()
    if GameTooltip then GameTooltip:Hide() end
end

-- Makes `frame` lead to the option `key`: accent outline and hint on hover,
-- jump on click. The outline sits on top and lets the mouse through.
local function Jump(box, frame, key, label)
    local outline = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    outline:SetAllPoints()
    outline:SetFrameLevel((frame:GetFrameLevel() or 0) + 30)
    outline:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
    outline:EnableMouse(false)
    outline:Hide()
    frame.KT_JumpOutline = outline
    frame.KT_JumpKey = key
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        local r, g, b = Accent()
        outline:SetBackdropBorderColor(r, g, b, 1)
        outline:Show()
        if self.KT_ShowTooltip then self:KT_ShowTooltip(label) else ShowHint(self, label) end
    end)
    frame:SetScript("OnLeave", function()
        outline:Hide()
        HideHint()
    end)
    frame:SetScript("OnMouseUp", function() box:Jump(key) end)
    box.jumps[#box.jumps + 1] = frame
    return frame
end

-- An invisible frame over a text, so the text can lead to its option too.
local function TextHit(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", text, "TOPLEFT", -4, 4)
    f:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 4, -4)
    return f
end

-- Mouse wheel scrolling of `content` inside `clip`, by `step` pixels.
local function Scrollable(box, clip, content, step)
    clip:SetClipsChildren(true)
    content.scroll = 0
    clip:EnableMouseWheel(true)
    clip:SetScript("OnMouseWheel", function(_, delta)
        local range = math.max(0, (content.contentHeight or 0) - (clip:GetHeight() or 0))
        content.scroll = math.max(0, math.min(range, content.scroll - delta * step()))
        box:Refresh()
    end)
end

local function Slot(parent, box)
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    -- Same slot holder as the real grid (Bags.lua EnsureItemButton).
    if KT.AddBackdrop then KT:AddBackdrop(holder, 0.035, 0.028, 0.02, 0.9) end
    if KT.AddBorder then KT:AddBorder(holder, 0.26, 0.19, 0.08, 0.95) end
    holder.icon = holder:CreateTexture(nil, "ARTWORK")
    holder.icon:SetPoint("TOPLEFT", 1, -1)
    holder.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    holder.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    holder.count = holder:CreateFontString(nil, "OVERLAY")
    holder.level = holder:CreateFontString(nil, "OVERLAY")
    -- Item quality: the real grid's rarity frame (kit.PaintQualityBorder) sits
    -- under this layer so the count and item level stay on top.
    holder.texts = CreateFrame("Frame", nil, holder)
    holder.texts:SetAllPoints()
    holder.texts:EnableMouse(false)
    holder.count:SetParent(holder.texts)
    holder.level:SetParent(holder.texts)
    holder.hover = holder:CreateTexture(nil, "HIGHLIGHT")
    holder.hover:SetAllPoints(holder.icon)
    holder.hover:SetTexture(WHITE)
    holder.hover:SetVertexColor(1, 1, 1, 0.14)
    -- Hovering a real item shows the game's tooltip for it.
    function holder:KT_ShowTooltip(label)
        local item = self.item
        if not (GameTooltip and item and item.bagID and item[1] and GameTooltip.SetBagItem) then
            return ShowHint(self, label)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(item.bagID, item.slotID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(LText(label), 1, 1, 1)
        GameTooltip:AddLine(LText("Click to jump to its settings block."), 0.75, 0.82, 0.9, true)
        GameTooltip:Show()
    end
    Jump(box, holder, "itemSize", "Item Icon Size")
    return holder
end

-- Builds the preview box with the window inside `parent`; returns the box.
function Mod:CreateOptionsPreview(parent, width)
    local kit = Kit()
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box.jumps = {}
    if KT.AddBackdrop then KT:AddBackdrop(box, 0.03, 0.03, 0.035, 0.9) end
    local caption = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("TOPLEFT", 8, -6)
    caption:SetText(LText("LIVE PREVIEW"))
    if KT.SetAccentTextColor then KT:SetAccentTextColor(caption, 1) end
    -- Glass card border (Widgets.lua W:PreviewCard).
    if KT.Widgets and KT.Widgets.PreviewCard then KT.Widgets:PreviewCard(box) end

    -- The page decides where each key leads (Bags_Options.lua).
    function box:SetJumpHandler(handler) self.onJump = handler end
    function box:Jump(key)
        HideHint()
        if self.onJump then self.onJump(key) end
    end

    -- The window (real sizes; scaled as a whole).
    local win = CreateFrame("Frame", nil, box, "BackdropTemplate")
    if KT.AddBackdrop then KT:AddBackdrop(win, 0.05, 0.07, 0.09, 0.94) end
    if kit.ApplyKuiSurface then kit.ApplyKuiSurface(win, "window") end
    if KT.AddBorder then KT:AddBorder(win, 0.10, 0.10, 0.10, 1) end
    Jump(box, win, "style", "Bags Style")

    -- Window chrome sizes (Bags.lua constants through the kit).
    local INSET = kit.WINDOW_INSET or 3
    local GAP = kit.PANEL_GAP or 3
    local HEADER_H = kit.HEADER_HEIGHT or 22
    local HEADER_BTN = kit.HEADER_BUTTON_SIZE or 18
    local TOOL_BTN = kit.TOOL_BUTTON_SIZE or 20
    local GRID_TITLE = kit.GRID_TITLE_HEIGHT or 20
    local GRID_INSET = kit.GRID_INSET or 3
    local GRID_PAD = kit.GRID_PADDING or 3
    local LANE = kit.SCROLL_LANE or 12
    local LIST_TOP = kit.SIDEBAR_LIST_TOP or 20
    local function ToolbarHeight()
        return kit.GetToolbarHeight and kit.GetToolbarHeight() or (kit.TOOLBAR_HEIGHT or 26)
    end

    -- Header: bag icon, title, options / compact view / close glyphs.
    local header = Panel(win, 0.08, 0.08, 0.09, 0.95, 0.16, 0.16, 0.16)
    header:SetPoint("TOPLEFT", win, "TOPLEFT", INSET, -INSET)
    header:SetPoint("TOPRIGHT", win, "TOPRIGHT", -INSET, -INSET)
    header:SetHeight(HEADER_H)
    win.KT_Header = header
    Jump(box, header, "panelColor", "Panel Color")
    local headerIcon = header:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(16, 16)
    headerIcon:SetPoint("LEFT", header, "LEFT", 4, 0)
    headerIcon:SetTexture(kit.ICON)
    headerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    win.KT_HeaderIcon = headerIcon
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", headerIcon, "RIGHT", 5, 0)
    win.KT_Title = title
    Jump(box, TextHit(header, title), "style", "Bags Style")
    local close = GlyphButton(header, HEADER_BTN, "close")
    close.KT_Danger = true
    close:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    Jump(box, close, "enable", "Enable Module")
    local mode = GlyphButton(header, HEADER_BTN, "compact")
    mode:SetPoint("RIGHT", close, "LEFT", -3, 0)
    Jump(box, mode, "viewMode", "View Mode")
    local options = GlyphButton(header, HEADER_BTN, "options")
    options:SetPoint("RIGHT", mode, "LEFT", -3, 0)
    win.KT_OptionsButton = options
    Jump(box, options, "general", "General")

    -- Toolbar: search box, equipped bags, watched badge, bag slots toggle / clean up / refresh.
    local toolbar = Panel(win, 0.05, 0.05, 0.06, 0.94, 0.14, 0.14, 0.14)
    toolbar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -GAP)
    toolbar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -GAP)
    toolbar:SetHeight(ToolbarHeight())
    win.KT_Toolbar = toolbar
    Jump(box, toolbar, "panelColor", "Panel Color")
    local refresh = GlyphButton(toolbar, TOOL_BTN, "refresh")
    refresh:SetPoint("RIGHT", toolbar, "RIGHT", -3, 0)
    local cleanup = GlyphButton(toolbar, TOOL_BTN, "sort")
    cleanup:SetPoint("RIGHT", refresh, "LEFT", -3, 0)
    local sort = GlyphButton(toolbar, TOOL_BTN, "bags")
    sort:SetPoint("RIGHT", cleanup, "LEFT", -3, 0)
    for _, button in ipairs({ refresh, cleanup, sort }) do Jump(box, button, "accent", "Bags Accent") end
    local watched = GlyphButton(toolbar, TOOL_BTN, "watch")
    watched.Icon:ClearAllPoints()
    watched.Icon:SetPoint("LEFT", watched, "LEFT", 2, 0)
    watched.Text = watched:CreateFontString(nil, "OVERLAY")
    watched.Text:SetPoint("LEFT", watched.Icon, "RIGHT", 2, 0)
    watched:SetPoint("RIGHT", sort, "LEFT", -3, 0)
    win.KT_WatchedBadge = watched
    Jump(box, watched, "accent", "Bags Accent")
    win.KT_BagIconHolders = {}
    local previous = watched
    for index, icon in ipairs({ "Interface\\Icons\\INV_Misc_Bag_08", "Interface\\Icons\\INV_Misc_Bag_10",
        "Interface\\Icons\\INV_Misc_Bag_10", "Interface\\Icons\\INV_Misc_Bag_10" }) do
        local holder = IconButton(toolbar, 20, icon)
        holder:SetPoint("RIGHT", previous, "LEFT", index == 1 and -3 or -2, 0)
        Jump(box, holder, "accent", "Bags Accent")
        win.KT_BagIconHolders[index] = holder
        previous = holder
    end
    local search = Panel(toolbar, 0.01, 0.01, 0.02, 0.92, 0.3, 0.3, 0.3)
    search:SetPoint("LEFT", toolbar, "LEFT", 3, 0)
    search:SetPoint("RIGHT", previous, "LEFT", -3, 0)
    search:SetHeight((kit.TOOLBAR_HEIGHT or 26) - 6)
    win.KT_SearchBox = search
    Jump(box, search, "accent", "Bags Accent")
    local searchIcon = search:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", search, "LEFT", 4, 0)
    if kit.SetToolbarGlyph then
        kit.SetToolbarGlyph(searchIcon, "search")
    else
        searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    end
    search.KT_SearchIcon = searchIcon
    local searchHint = search:CreateFontString(nil, "OVERLAY")
    searchHint:SetPoint("LEFT", searchIcon, "RIGHT", 4, 0)

    -- Sidebar: the Categories list, scrolling inside its panel.
    local sidebar = Panel(win, 0.018, 0.018, 0.022, 0.95, 0.12, 0.12, 0.12, {
        topAlpha = 0.026, leftAlpha = 0.018, lineAlpha = 0.12, topCoverage = 0.16, leftCoverage = 0.45,
    })
    sidebar:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -GAP)
    Jump(box, sidebar, "smallCategories", "Small Category Buttons")
    local sidebarTitle = sidebar:CreateFontString(nil, "OVERLAY")
    sidebarTitle:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -5)
    local sidebarClip = CreateFrame("Frame", nil, sidebar)
    sidebarClip:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 1, -LIST_TOP)
    sidebarClip:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -1, GRID_INSET)
    local sidebarContent = CreateFrame("Frame", nil, sidebarClip)
    sidebarContent:SetPoint("TOPLEFT")
    sidebarContent:SetPoint("TOPRIGHT")
    sidebarContent:SetHeight(1)
    Scrollable(box, sidebarClip, sidebarContent, function()
        local metrics = Mod.GetSidebarMetrics and Mod:GetSidebarMetrics()
        return (metrics and metrics.rowHeight or 42) + 2
    end)
    local rows = {}
    local function Row(index)
        local row = rows[index]
        if row then return row end
        row = CreateFrame("Frame", nil, sidebarContent, "BackdropTemplate")
        Backdrop(row, 0, 0, 0, 0, 0, 0, 0, 0)
        row.KT_Left = row:CreateTexture(nil, "ARTWORK")
        row.KT_Left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        row.KT_Left:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
        row.KT_Left:SetWidth(3)
        row.KT_Icon = row:CreateTexture(nil, "ARTWORK")
        row.KT_Label = row:CreateFontString(nil, "OVERLAY")
        row.KT_Label:SetJustifyH("LEFT")
        row.KT_Count = row:CreateFontString(nil, "OVERLAY")
        row.KT_Count:SetJustifyH("RIGHT")
        Jump(box, row, "smallCategories", "Small Category Buttons")
        rows[index] = row
        return row
    end

    -- Grid: the backpack by category, scrolling inside its panel.
    local grid = Panel(win, 0.012, 0.012, 0.016, 0.94, 0.12, 0.12, 0.12)
    win.KT_GridPanel = grid
    Jump(box, grid, "columns", "Columns")
    local gridHeader = grid:CreateFontString(nil, "OVERLAY")
    gridHeader:SetPoint("TOPLEFT", grid, "TOPLEFT", 6, -5)
    win.KT_GridHeader = gridHeader
    local gridClip = CreateFrame("Frame", nil, grid)
    gridClip:SetPoint("TOPLEFT", grid, "TOPLEFT", GRID_INSET, -GRID_TITLE)
    gridClip:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", -LANE, GRID_INSET)
    local gridContent = CreateFrame("Frame", nil, gridClip)
    gridContent:SetPoint("TOPLEFT")
    gridContent:SetPoint("TOPRIGHT")
    gridContent:SetHeight(1)
    Scrollable(box, gridClip, gridContent, function()
        return (kit.GetItemSize and kit.GetItemSize() or 36) + (kit.ITEM_SPACING or 2)
    end)
    local scrollLane = grid:CreateTexture(nil, "ARTWORK")
    scrollLane:SetTexture(WHITE)
    scrollLane:SetWidth(4)
    local scrollThumb = grid:CreateTexture(nil, "OVERLAY")
    scrollThumb:SetTexture(WHITE)
    scrollThumb:SetWidth(4)
    local titles, lines, slots = {}, {}, {}

    -- Footer: selected item, slots, currencies and gold.
    local footer = Panel(win, 0.06, 0.06, 0.07, 0.95, 0.14, 0.14, 0.14)
    footer:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", INSET, INSET)
    footer:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -INSET, INSET)
    footer:SetHeight(kit.FOOTER_HEIGHT or 22)
    win.KT_Footer = footer
    Jump(box, footer, "currencies", "Currencies")
    local selectedFrame = CreateFrame("Frame", nil, footer, "BackdropTemplate")
    selectedFrame:SetSize(18, 18)
    selectedFrame:SetPoint("LEFT", footer, "LEFT", 2, 0)
    Backdrop(selectedFrame, 0.02, 0.02, 0.03, 0.95, 0.15, 0.15, 0.15)
    win.KT_SelectedIconFrame = selectedFrame
    local status = footer:CreateFontString(nil, "OVERLAY")
    status:SetPoint("LEFT", selectedFrame, "RIGHT", 5, 0)
    local summary = footer:CreateFontString(nil, "OVERLAY")
    summary:SetPoint("LEFT", status, "RIGHT", 6, 0)
    local selectedText = footer:CreateFontString(nil, "OVERLAY")
    selectedText:SetPoint("LEFT", summary, "RIGHT", 10, 0)
    local gold = footer:CreateFontString(nil, "OVERLAY")
    gold:SetPoint("RIGHT", footer, "RIGHT", -5, 0)
    local goldHit = Jump(box, TextHit(footer, gold), "showGold", "Show Gold")
    local currencies = {}
    local currencyHit = CreateFrame("Frame", nil, footer)
    Jump(box, currencyHit, "showCurrencies", "Show Currencies")

    box.win, box.rows, box.slots, box.gold, box.sidebar = win, rows, slots, gold, sidebar
    box.gridContent, box.sidebarContent, box.gridClip, box.sidebarClip = gridContent, sidebarContent, gridClip, sidebarClip
    box.status, box.goldHit = status, goldHit

    function box:Refresh()
        local db = Mod.db or {}
        local font = kit.FONT or "Fonts\\FRIZQT__.TTF"
        local Label = kit.Label or function(_, fallback) return fallback end
        local size = kit.GetItemSize and kit.GetItemSize() or 36
        local gap = kit.ITEM_SPACING or 3
        local columns = Mod.GetColumns and Mod:GetColumns() or 12
        local metrics = Mod.GetSidebarMetrics and Mod:GetSidebarMetrics()
            or { width = 196, rowHeight = 42, iconSize = 32, labelFont = 12, countFont = 11 }
        local layout = Mod.GetSidebarRowLayout and Mod:GetSidebarRowLayout() or {
            metrics = metrics, showIcons = true, small = false, labelFont = metrics.labelFont,
            countFont = metrics.countFont, rowHeight = metrics.rowHeight, rowStep = metrics.rowHeight + 2,
        }
        local small = layout.small
        local showIcons = layout.showIcons
        local icons = kit.CATEGORY_ICONS or {}
        local function Icon(key)
            if kit.GetCategoryIcon then return kit.GetCategoryIcon(key) end
            return icons[key]
        end
        local function Scaled(fontSize)
            return Mod.ScaledFont and Mod:ScaledFont(fontSize) or fontSize
        end
        local textScale = Mod.GetTextScale and Mod:GetTextScale() or 1
        local borderOptions = Mod.GetQualityBorderOptions and Mod:GetQualityBorderOptions() or { mode = "style" }
        local category = (db.viewMode or "category") == "category"
        local cell = size + gap
        local data = Contents()
        local ar, ag, ab = Accent()

        -- Size: the real width for these columns, scaled to fit the box. The
        -- box keeps the height it opened with (the page below it does not
        -- move), so the window is scaled to fit it as well.
        local winW = Mod.GetWindowWidth and Mod:GetWindowWidth() or 760
        local winH = PREVIEW_WINDOW_HEIGHT
        win:SetSize(winW, winH)
        local boxW = self:GetWidth() or width
        local scale = math.min(PREVIEW_MAX_SCALE, (boxW - 24) / winW)
        if not self.fixedHeight then self.fixedHeight = 24 + winH * scale + 14 end
        scale = math.min(scale, (self.fixedHeight - 38) / winH)
        win:SetScale(scale)
        win:ClearAllPoints()
        win:SetPoint("TOP", self, "TOP", 0, -24 / scale)
        self:SetHeight(self.fixedHeight)

        -- Header and toolbar texts (same fonts and colours as Bags.lua).
        title:SetFont(font, 13, "OUTLINE")
        title:SetText(Label("BAGS_TITLE", "Bags"))
        -- Glyph buttons, lit like the window's toggles.
        if kit.PaintIconButton then
            kit.PaintIconButton(close)
            kit.PaintIconButton(mode, not category)
            kit.PaintIconButton(options)
            kit.PaintIconButton(refresh)
            kit.PaintIconButton(cleanup)
            kit.PaintIconButton(sort, db.showEquippedBags == true)
            kit.PaintIconButton(watched, false)
        end
        toolbar:SetHeight(ToolbarHeight())
        local bagIcon = tonumber(db.bagIconSize) or 18
        for _, holder in ipairs(win.KT_BagIconHolders) do
            holder:SetSize(bagIcon + 2, bagIcon + 2)
            holder.icon:ClearAllPoints()
            holder.icon:SetPoint("TOPLEFT", 1, -1)
            holder.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        end
        watched.Text:SetFont(font, 11, "OUTLINE")
        watched.Text:SetText(tostring(data.watched or 0))
        watched.Text:SetTextColor(0.92, 0.92, 0.96, 1)
        watched:SetWidth(2 + (TOOL_BTN - 4) + 2 + math.ceil(watched.Text:GetStringWidth() or 6) + 4)
        searchHint:SetFont(font, 11, "OUTLINE")
        searchHint:SetText(Label("BAGS_SEARCH_HINT", LText("Search")))
        searchHint:SetTextColor(0.55, 0.55, 0.6, 1)

        -- Sidebar rows: All Items, OneBag, Pinned Items, then the categories.
        local contentTop = INSET + HEADER_H + GAP + ToolbarHeight() + GAP
        local contentH = winH - contentTop - (kit.FOOTER_HEIGHT or 22) - GAP - INSET
        local showSidebar = not (Mod.ShowsCategorySidebar and not Mod:ShowsCategorySidebar())
        sidebar:SetShown(showSidebar)
        sidebar:SetSize(metrics.width, contentH)
        sidebarTitle:SetFont(font, Scaled(11), "OUTLINE")
        sidebarTitle:SetText(Label("BAGS_CATEGORIES", "Categories"))
        sidebarTitle:SetTextColor(0.82, 0.82, 0.86, 1)
        local entries = {
            { Label("BAGS_ALL_ITEMS", "All Items"), Icon("all"), data.used, true },
            { Label("BAGS_ONEBAG", "OneBag"), Icon("onebag"), data.total },
            { Label("BAGS_PINNED_ITEMS", "Pinned Items"), Icon("watched"), data.watched or 0 },
        }
        for _, c in ipairs(data.categories) do entries[#entries + 1] = { c.label, c.icon, #c.items } end
        local rowStep = layout.rowStep
        local rowY = -2
        for index, entry in ipairs(entries) do
            local row = Row(index)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sidebarContent, "TOPLEFT", 3, rowY)
            row:SetPoint("TOPRIGHT", sidebarContent, "TOPRIGHT", -3, rowY)
            row:SetHeight(layout.rowHeight)
            row.KT_Icon:ClearAllPoints()
            row.KT_Icon:SetPoint("LEFT", row, "LEFT", small and 5 or 7, 0)
            row.KT_Icon:SetShown(showIcons)
            if showIcons and kit.SetIconTexture then kit.SetIconTexture(row.KT_Icon, entry[2], metrics.iconSize) end
            row.KT_Label:ClearAllPoints()
            if showIcons then
                row.KT_Label:SetPoint("LEFT", row.KT_Icon, "RIGHT", small and 6 or 8, 0)
            else
                row.KT_Label:SetPoint("LEFT", row, "LEFT", small and 8 or 10, 0)
            end
            row.KT_Label:SetPoint("RIGHT", row, "RIGHT", small and -30 or -38, 0)
            row.KT_Label:SetFont(font, layout.labelFont, "OUTLINE")
            if row.KT_Label.SetWordWrap then row.KT_Label:SetWordWrap(false) end
            row.KT_Label:SetText(entry[1])
            row.KT_Count:ClearAllPoints()
            row.KT_Count:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.KT_Count:SetFont(font, layout.countFont, "OUTLINE")
            row.KT_Count:SetText(tostring(entry[3] or 0))
            Mod:ApplySidebarRowVisual(row, entry[4] == true, false)
            row:Show()
            rowY = rowY - rowStep
        end
        for index = #entries + 1, #rows do rows[index]:Hide() end
        sidebarContent.contentHeight = -rowY + 4
        local sidebarRange = math.max(0, sidebarContent.contentHeight - (contentH - LIST_TOP - GRID_INSET))
        sidebarContent.scroll = math.min(sidebarContent.scroll, sidebarRange)
        sidebarContent:ClearAllPoints()
        sidebarContent:SetPoint("TOPLEFT", sidebarClip, "TOPLEFT", 0, sidebarContent.scroll)
        sidebarContent:SetPoint("TOPRIGHT", sidebarClip, "TOPRIGHT", 0, sidebarContent.scroll)

        -- Grid: the categories (or OneBag: every slot in bag order).
        grid:ClearAllPoints()
        if showSidebar then
            grid:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", GAP, 0)
        else
            grid:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -GAP)
        end
        grid:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, GAP)
        gridHeader:SetFont(font, 12, "OUTLINE")
        gridHeader:SetText(category and Label("BAGS_BACKPACK_CATEGORIES", "Backpack Categories")
            or string.format(Label("BAGS_BACKPACK_SLOTS_VIEW", "Backpack (%d slots)"), data.total))
        local tr, tg, tb = ar, ag, ab
        if kit.GetAccentTextColor then tr, tg, tb = kit.GetAccentTextColor(1, 0.22) end
        local groups = category and data.categories or { { items = data.all } }
        local showLevel = db.showItemLevel ~= false
        local y, used = GRID_PAD, 0
        for index, group in ipairs(groups) do
            local titleText, line = titles[index], lines[index]
            if not titleText then
                titleText = gridContent:CreateFontString(nil, "OVERLAY")
                line = gridContent:CreateTexture(nil, "ARTWORK")
                line:SetTexture(WHITE)
                line:SetHeight(1)
                titles[index], lines[index] = titleText, line
            end
            local titled = group.label ~= nil
            titleText:SetShown(titled)
            line:SetShown(titled)
            if titled then
                titleText:SetFont(font, Scaled(kit.CATEGORY_FONT or 12), "OUTLINE")
                titleText:SetTextColor(tr, tg, tb, 1)
                titleText:SetText(group.label)
                titleText:ClearAllPoints()
                titleText:SetPoint("TOPLEFT", gridContent, "TOPLEFT", GRID_PAD, -y)
                line:ClearAllPoints()
                line:SetPoint("LEFT", titleText, "RIGHT", 8, 0)
                line:SetPoint("RIGHT", gridContent, "RIGHT", -GRID_PAD, 0)
                line:SetVertexColor(ar, ag, ab, 0.22)
                y = y + (Mod.GetCategoryHeaderStep and Mod:GetCategoryHeaderStep() or 16)
            end
            for itemIndex, item in ipairs(group.items) do
                used = used + 1
                local slot = slots[used] or Slot(gridContent, box)
                slots[used] = slot
                local col, row = (itemIndex - 1) % columns, math.floor((itemIndex - 1) / columns)
                slot.item = item
                slot:ClearAllPoints()
                slot:SetSize(size, size)
                slot:SetPoint("TOPLEFT", gridContent, "TOPLEFT", GRID_PAD + col * cell, -(y + row * cell))
                slot.icon:SetTexture(item[1])
                slot.icon:SetShown(item[1] ~= nil)
                -- Same icon inset as the real buttons, inside the rarity frame.
                local iconInset = 1
                if borderOptions.mode == "flat" then
                    iconInset = 2
                elseif borderOptions.mode ~= "off" then
                    iconInset = math.max(2, math.floor(size * 0.09 + 0.5))
                end
                slot.icon:ClearAllPoints()
                slot.icon:SetPoint("TOPLEFT", iconInset, -iconInset)
                slot.icon:SetPoint("BOTTOMRIGHT", -iconInset, iconInset)
                slot.icon:SetDesaturated(Mod.IsGreyedJunk and Mod:IsGreyedJunk(item.quality, item.isQuestItem) or false)
                local inset = math.max(2, math.floor(size * 0.08))
                slot.count:SetFont(font, math.floor(math.max(12, math.floor(size * 0.32)) * textScale + 0.5), "OUTLINE")
                slot.count:ClearAllPoints()
                slot.count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -inset, inset)
                slot.count:SetText(item[2] and tostring(item[2]) or "")
                local level = showLevel and item.itemLevel and not item[2]
                slot.level:SetShown(level and true or false)
                if level then
                    local lr, lg, lb = 1, 0.82, 0
                    if db.itemLevelColorByRarity and kit.GetQualityColor then lr, lg, lb = kit.GetQualityColor(item.quality) end
                    slot.level:SetFont(font, math.floor(math.max(11, math.floor(size * 0.30)) * textScale + 0.5), "OUTLINE")
                    slot.level:ClearAllPoints()
                    slot.level:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", inset, inset)
                    slot.level:SetText(item.itemLevel)
                    slot.level:SetTextColor(lr, lg, lb, 1)
                end
                if kit.PaintQualityBorder then
                    borderOptions.level = slot:GetFrameLevel() + 1
                    kit.PaintQualityBorder(slot, item[1] and (item.quality or 1) or nil, borderOptions)
                end
                slot.texts:SetFrameLevel(slot:GetFrameLevel() + 3)
                slot:Show()
            end
            y = y + math.ceil(#group.items / columns) * cell + (titled and (kit.GROUP_GAP or 6) or 0)
        end
        for index = #groups + 1, #titles do
            titles[index]:Hide()
            lines[index]:Hide()
        end
        for index = used + 1, #slots do slots[index]:Hide() end

        -- Scroll: keep the offset in range and move the thumb with it.
        local viewH = contentH - GRID_TITLE - GRID_INSET
        gridContent.contentHeight = y
        local range = math.max(0, y - viewH)
        gridContent.scroll = math.min(gridContent.scroll, range)
        gridContent:ClearAllPoints()
        gridContent:SetPoint("TOPLEFT", gridClip, "TOPLEFT", 0, gridContent.scroll)
        gridContent:SetPoint("TOPRIGHT", gridClip, "TOPRIGHT", 0, gridContent.scroll)
        local laneH = viewH - 4
        scrollLane:ClearAllPoints()
        scrollLane:SetPoint("TOPRIGHT", grid, "TOPRIGHT", -GRID_INSET, -GRID_TITLE)
        scrollLane:SetHeight(laneH)
        scrollLane:SetVertexColor(1, 1, 1, 0.06)
        local thumbH = range > 0 and math.max(24, laneH * viewH / y) or laneH
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOPRIGHT", scrollLane, "TOPRIGHT", 0, range > 0 and -(laneH - thumbH) * gridContent.scroll / range or 0)
        scrollThumb:SetHeight(thumbH)
        scrollThumb:SetVertexColor(ar, ag, ab, 0.55)

        -- Footer.
        status:SetFont(font, 11, "OUTLINE")
        status:SetText(string.format(Label("BAGS_SLOTS", "Slots %d/%d"), data.used, data.total))
        status:SetTextColor(0.95, 0.95, 0.98, 1)
        summary:SetFont(font, 11, "OUTLINE")
        summary:SetText(string.format(Label("BAGS_FREE", "Free %d"), data.free))
        summary:SetTextColor(0.84, 0.84, 0.88, 1)
        selectedText:SetFont(font, 11, "OUTLINE")
        selectedText:SetText(Label("BAGS_NO_ITEM_SELECTED", "No item selected"))
        selectedText:SetTextColor(0.92, 0.92, 0.95, 1)
        gold:SetFont(font, 12, "OUTLINE")
        local showGold = not (db.currency and db.currency.showGold == false)
        gold:SetShown(showGold)
        local money = GetMoney and GetMoney() or SAMPLE_MONEY
        gold:SetText(showGold and kit.FormatMoney and kit.FormatMoney(money) or "")
        goldHit:SetShown(showGold)
        local currencyDb = db.currency or {}
        local list = currencyDb.show ~= false and Currencies(currencyDb.max or 3) or {}
        local spacing = currencyDb.spacing or 10
        local anchor = showGold and gold or nil
        local first, last
        for index = 1, math.max(#list, #currencies) do
            local c = currencies[index]
            if not c then
                c = { icon = footer:CreateTexture(nil, "ARTWORK"), amount = footer:CreateFontString(nil, "OVERLAY") }
                c.icon:SetSize(14, 14)
                c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                currencies[index] = c
            end
            local def = list[index]
            c.icon:SetShown(def ~= nil)
            c.amount:SetShown(def ~= nil)
            if def then
                c.icon:SetTexture(def[1])
                c.amount:SetFont(font, 12, "OUTLINE")
                c.amount:SetText(tostring(def[2] or 0))
                c.amount:SetTextColor(0.95, 0.95, 0.98, 1)
                c.amount:ClearAllPoints()
                if anchor then
                    c.amount:SetPoint("RIGHT", anchor, "LEFT", -spacing, 0)
                else
                    c.amount:SetPoint("RIGHT", footer, "RIGHT", -5, 0)
                end
                c.icon:ClearAllPoints()
                c.icon:SetPoint("RIGHT", c.amount, "LEFT", -4, 0)
                anchor = c.icon
                first = first or c.amount
                last = c.icon
            end
        end
        currencyHit:ClearAllPoints()
        currencyHit:SetShown(first ~= nil)
        if first then
            currencyHit:SetPoint("TOPLEFT", last, "TOPLEFT", -4, 6)
            currencyHit:SetPoint("BOTTOMRIGHT", first, "BOTTOMRIGHT", 4, -6)
        end

        -- Panel colours, accent surfaces and the bag style's frame: the real code.
        Mod:ApplyPanelColor(win)
    end

    box:SetWidth(width)
    box:Refresh()
    return box
end
