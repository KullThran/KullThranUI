-- Aura Reminders options: the four reminder pages (Control Center, Group Readiness, Class Upkeep, Consumable Loadout)
-- and the controls they share: toggle grid, inline icon buttons, disabled covers, button hover fade.
-- Keeps every behaviour the specification flags as a suspected bug. The client comes only through Setup's ctx.

local _, ns = ...
local KT = ns.KT or (LibStub and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))
if not KT then return end

local BUNDLED_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local ROW_HEIGHT = 50
local DROPDOWN_PAD, DROPDOWN_LABEL_GAP, DROPDOWN_MIN_BOX = 12, 8, 110
local GLOW_SWATCH_ROOM = 32

local M = {}
ns.AuraRemindersPageReminders = M

-- Set by Setup.
local S, P, client, inset

-----------------------------------------------------------------------------------------------------------------------
-- Shared controls
-----------------------------------------------------------------------------------------------------------------------

-- Fades through a per-button progress; the OnUpdate lives only while the progress is moving.
local function AttachHoverFade(button, apply)
    local progress, direction = 0, 1
    local function step(self, elapsed)
        progress = progress + direction * elapsed / 0.1
        if progress >= 1 then
            progress = 1
            self:SetScript("OnUpdate", nil)
        elseif progress <= 0 then
            progress = 0
            self:SetScript("OnUpdate", nil)
        end
        apply(progress)
    end
    button:SetScript("OnEnter", function(self)
        direction = 1
        self:SetScript("OnUpdate", step)
    end)
    button:SetScript("OnLeave", function(self)
        direction = -1
        self:SetScript("OnUpdate", step)
    end)
end

-- The region's leftmost inline control: the last one placed on it, otherwise its core control.
local function leftmostOf(inline, region)
    return inline[region] or region._control
end

-- Small icon button beside the region's inline controls. `inline` remembers the leftmost per region for one page build.
local function addInlineButton(inline, region, action, icon)
    local button = CreateFrame("Button", nil, region)
    button:SetSize(26, 26)
    button:SetFrameLevel(region:GetFrameLevel() + 5)
    button:SetAlpha(0.4)
    button:SetPoint("RIGHT", leftmostOf(inline, region), "LEFT", -8, 0)
    inline[region] = button

    local tex = button:CreateTexture(nil, "OVERLAY")
    tex:SetPoint("CENTER")
    if not icon or icon == KT.KUI_SettingsCogGlyph then
        tex:SetSize(16, 12)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tex:SetTexture(KT.KUI_SettingsCogGlyph)
    else
        tex:SetSize(16, 16)
        tex:SetTexture(icon)
    end

    button:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
    button:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
    button:SetScript("OnClick", function(self) action(self) end)
    return button
end

-- Mouse-taking cover over a control. Returns the check, which callers run at build and register.
local function addCover(control, reason, test, callback)
    local cover = CreateFrame("Frame", nil, control)
    cover:SetAllPoints(control)
    cover:SetFrameLevel(control:GetFrameLevel() + 10)
    cover:EnableMouse(true)
    cover:SetScript("OnEnter", function() KT.ShowWidgetTooltip(control, KT.DisabledTooltip(reason)) end)
    cover:SetScript("OnLeave", function() KT.HideWidgetTooltip() end)
    return function()
        local blocked = not not test()
        cover:SetShown(blocked)
        if callback then
            callback(blocked)
        else
            control:SetAlpha(blocked and 0.3 or 1)
        end
    end
end

-- One cell. Creation order inside it makes the hit area take the clicks.
local function buildCell(row, column, colW, item)
    local cell = CreateFrame("Frame", nil, row)
    cell:SetSize(colW, ROW_HEIGHT)
    cell:SetPoint("TOPLEFT", row, "TOPLEFT", column * colW, 0)

    local r, g, b = 1, 1, 1
    local classColor = item.token and RAID_CLASS_COLORS[item.token]
    if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
    local label = KT.MakeFont(cell, 12, nil, r, g, b)
    label:SetPoint("LEFT", cell, "LEFT", 20, 0)
    label:SetPoint("RIGHT", cell, "RIGHT", -50, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetMaxLines(1)
    label:SetText(item.label)

    local box = CreateFrame("Frame", nil, cell)
    box:SetSize(18, 18)
    box:SetPoint("RIGHT", cell, "RIGHT", -20, 0)
    local fill = box:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.12, 0.12, 0.14, 1)
    P.NoSnap(fill)
    local border = KT:AddBorder(box, 0.25, 0.25, 0.28, 0.6)
    local mark = box:CreateTexture(nil, "ARTWORK")
    mark:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    local accent = KT.KUI_ACCENT
    mark:SetColorTexture(accent.r, accent.g, accent.b, 1)
    P.NoSnap(mark)

    local function paint()
        local on = item.read()
        mark:SetShown(not not on)
        label:SetAlpha(on and 1 or 0.5)
        if on then
            local a = KT.KUI_ACCENT
            border:SetColor(a.r, a.g, a.b, 0.15)
        else
            border:SetColor(0.25, 0.25, 0.28, 0.6)
        end
    end
    paint()

    local hit = CreateFrame("Button", nil, cell)
    hit:SetAllPoints(cell)
    hit:SetFrameLevel(cell:GetFrameLevel() + 2)
    hit:SetScript("OnEnter", function()
        if not item.read() then label:SetAlpha(0.8) end
    end)
    hit:SetScript("OnLeave", function()
        if not item.read() then label:SetAlpha(0.5) end
    end)
    hit:SetScript("OnClick", function()
        item.write(not item.read())
        paint()
        P.RefreshAll()
        P.RebuildHeader()
    end)

    KT.RegisterWidgetRefresh(paint)
    return cell
end

-- Four columns, three when the settings column is too narrow for a name beside its box.
local function gridColumns(width)
    return width >= 640 and 4 or 3
end

-- Grid on the page at y. Remembers each keyed cell in `cells`. Returns the height used.
local function buildGrid(page, y, items, cells)
    local count = #items
    if count == 0 then return 0 end

    local width = page:GetWidth() - 2 * inset
    local COLUMNS = gridColumns(width)
    local colW = math.floor(width / COLUMNS)
    local rows = math.ceil(count / COLUMNS)
    local PP = KT.PP
    local index = 0
    for rowIndex = 0, rows - 1 do
        local row = CreateFrame("Frame", nil, page)
        PP.Size(row, width, ROW_HEIGHT)
        PP.Point(row, "TOPLEFT", page, "TOPLEFT", inset, y - rowIndex * ROW_HEIGHT)
        KT.RowBg(row, page)
        for i = 1, COLUMNS - 1 do
            local line = row:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, 0.06)
            P.NoSnap(line)
            line:SetWidth(1)
            PP.Point(line, "TOP", row, "TOPLEFT", i * colW, 0)
            PP.Point(line, "BOTTOM", row, "BOTTOMLEFT", i * colW, 0)
        end
        for column = 0, COLUMNS - 1 do
            index = index + 1
            local item = items[index]
            if not item then break end
            local cell = buildCell(row, column, colW, item)
            if item.key then
                cells[#cells + 1] = { key = item.key, cell = cell }
            end
        end
    end
    return rows * ROW_HEIGHT
end

-- Adds a catalogue's entries as grid items. A nil catalogue is an empty one.
local function addCatalogue(items, catalogue, getSection, token)
    if not catalogue then return end
    for _, entry in ipairs(catalogue) do
        local key = entry.key
        items[#items + 1] = {
            label = entry.name,
            token = token or entry.class,
            key = key,
            read = function() return P.IsOn(getSection(), key) end,
            write = function(value)
                local section = getSection()
                if section and section.enabled then section.enabled[key] = value end
            end,
        }
    end
end

-- Empties the shared mapping table in place and returns it.
local function resetMappings()
    local mappings = P.ClickMappings
    wipe(mappings)
    return mappings
end

local function mapCells(mappings, cells)
    for _, e in ipairs(cells) do
        mappings["item:" .. e.key] = { section = e.cell, target = e.cell }
    end
end

-- A toggle entry over a plain field of a section; writes then refreshes.
local function fieldToggle(text, getSection, key)
    return {
        type = "toggle",
        text = text,
        getValue = function()
            local section = getSection()
            return section and section[key]
        end,
        setValue = function(value)
            local section = getSection()
            if not section then return end
            section[key] = value
            P.RefreshAll()
        end,
    }
end

-----------------------------------------------------------------------------------------------------------------------
-- Control Center
-----------------------------------------------------------------------------------------------------------------------

local function displayReader(key, fallback)
    return function()
        local d = P.DDB()
        if fallback == nil then return d and d[key] end
        return d and d[key] or fallback
    end
end

local function displayWriter(key, after)
    return function(value)
        local d = P.DDB()
        if not d then return end
        d[key] = value
        if after then after() end
    end
end

local function refreshRestyle()
    P.RefreshAll()
    P.UpdateHeader()
end

local function refreshRestylePage()
    P.RefreshAll()
    P.UpdateHeader()
    KT:RefreshPage()
end

local function buildSwatch(region, key, fr, fg, fb)
    local swatch = KT.BuildColorSwatch(region, region:GetFrameLevel() + 5,
        function()
            local d = P.DDB()
            local c = d and d[key]
            if c then return c.r, c.g, c.b, 1 end
            return fr, fg, fb, 1
        end,
        function(r, g, b)
            local d = P.DDB()
            if not d then return end
            d[key] = { r = r, g = g, b = b }
            refreshRestyle()
        end,
        false, 20)
    return swatch
end

local function popupSlider(label, key, minV, maxV, fallback, after)
    return {
        type = "slider", label = label, min = minV, max = maxV, step = 1,
        get = displayReader(key, fallback),
        set = displayWriter(key, after),
    }
end

-- This panel's columns are narrow for the shared dropdown's fixed box: the label takes the room it needs, the box what
-- is left, and a label that still does not fit goes to two lines. `reserve` keeps room for a control between them.
local function fitDropdown(control, reserve)
    local box, label = control and control._boxKT, control and control._labelKT
    if not box or not label then return end
    local room = control:GetWidth() - 2 * DROPDOWN_PAD - DROPDOWN_LABEL_GAP - (reserve or 0)
    local wanted = math.ceil(label:GetStringWidth()) + 2
    local labelW = math.min(wanted, room - DROPDOWN_MIN_BOX)
    box:SetWidth(math.min(box:GetWidth(), room - labelW))
    label:SetWidth(labelW)
    if wanted > labelW then
        label:SetWordWrap(true)
        label:SetMaxLines(2)
    end
end

local function fitRowDropdowns(row, leftReserve)
    fitDropdown(row._leftRegion._control, leftReserve)
    fitDropdown(row._rightRegion._control)
end

-- Glow swatch on row 1's left half, between the dropdown's label and its box.
local function decorateGlowHalf(inline, region)
    local swatch = buildSwatch(region, "glowColor", 1, 0.776, 0.376)
    local control = region._control
    swatch:SetPoint("RIGHT", control and control._boxKT or leftmostOf(inline, region), "LEFT", -12, 0)
    inline[region] = swatch
    local check = addCover(swatch, S.LText("a Glow Type other than None"), function()
        local d = P.DDB()
        return not d or (d.glowType or 0) == 0
    end)
    check()
    KT.RegisterWidgetRefresh(check)
end

-- Text swatch, its cover, the text popup, its button, the button's cover, on row 1's right half.
local function decorateTextHalf(inline, region)
    local function textOff()
        local d = P.DDB()
        return not d or not d.showText
    end

    local swatch = buildSwatch(region, "textColor", 1, 1, 1)
    swatch:SetPoint("RIGHT", region, "RIGHT", -62, 0)
    inline[region] = swatch
    local swatchCheck = addCover(swatch, S.LText("Show Text"), textOff)

    local _, showPopup = KT.BuildCogPopup({
        title = S.LText("Text Settings"),
        rows = {
            popupSlider(S.LText("Text Size"), "textSize", 6, 24, 11, refreshRestyle),
            popupSlider(S.LText("X Offset"), "textXOffset", -50, 50, 0, refreshRestyle),
            popupSlider(S.LText("Y Offset"), "textYOffset", -50, 50, -2, refreshRestyle),
        },
    })
    local button = addInlineButton(inline, region, showPopup)
    local buttonCheck = addCover(button, S.LText("Show Text"), textOff, function(blocked)
        button:SetAlpha(blocked and 0.15 or 0.4)
    end)

    local function check()
        swatchCheck()
        buttonCheck()
    end
    check()
    KT.RegisterWidgetRefresh(check)
end

-- Layout popup and its button on row 2's right half; no cover.
local function decorateSpacingHalf(inline, region)
    local _, showPopup = KT.BuildCogPopup({
        title = S.LText("Layout Settings"),
        rows = {
            popupSlider("Y", "yOffset", -600, 600, 0, function()
                local apply = _G._KUIAR_ApplyUnlockPos
                if apply then apply() end
            end),
        },
    })
    addInlineButton(inline, region, showPopup, KT.KUI_NavArrowGlyph)
end

local function buildControlCenter(page, y)
    local W = KT.Widgets
    local inline = {}
    local frame, h

    frame, h = W:SectionHeader(page, S.LText("MODULE STATUS"), y)
    y = y - h
    frame, h = W:Toggle(page, S.LText("Enable Module"), y,
        function()
            local profile = P.DB()
            if not profile then return true end
            return profile.enable ~= false
        end,
        function(value)
            local profile = P.DB()
            if not profile then return end
            profile.enable = not not value
            S.Reload()
        end)
    y = y - h

    local displayHeader
    displayHeader, h = W:SectionHeader(page, S.LText(S.Sections.DISPLAY), y)
    y = y - h

    local row1
    row1, h = W:DualRow(page, y, {
        type = "dropdown",
        text = S.LText("Glow Type"),
        values = _G._KUIAR_GLOW_VALUES or { [0] = "None" },
        order = _G._KUIAR_GLOW_ORDER or { 0 },
        getValue = displayReader("glowType", 0),
        setValue = displayWriter("glowType", refreshRestylePage),
    }, {
        type = "toggle",
        text = S.LText("Show Text"),
        getValue = displayReader("showText"),
        setValue = displayWriter("showText", refreshRestylePage),
    })
    y = y - h
    fitRowDropdowns(row1, GLOW_SWATCH_ROOM)
    decorateGlowHalf(inline, row1._leftRegion)
    decorateTextHalf(inline, row1._rightRegion)

    local row2
    row2, h = W:DualRow(page, y, {
        type = "slider",
        text = S.LText("Scale"),
        min = 0.5, max = 3.0, step = 0.05,
        getValue = displayReader("scale", 1.0),
        setValue = displayWriter("scale", refreshRestyle),
    }, {
        type = "slider",
        text = S.LText("Icon Spacing"),
        min = 0, max = 50, step = 1,
        getValue = displayReader("iconSpacing", 8),
        setValue = displayWriter("iconSpacing", function()
            P.RefreshAll()
            P.RelayoutIcons()
        end),
    })
    y = y - h
    decorateSpacingHalf(inline, row2._rightRegion)

    frame, h = W:DualRow(page, y, {
        type = "toggle",
        text = S.LText("Attach Important Buffs to Cursor"),
        getValue = displayReader("cursorAttach"),
        setValue = displayWriter("cursorAttach", function() P.RefreshAll() end),
    }, {
        type = "slider",
        text = S.LText("Opacity"),
        min = 0, max = 1, step = 0.05,
        getValue = displayReader("opacity", 1),
        setValue = displayWriter("opacity", refreshRestyle),
    })
    y = y - h

    frame, h = W:DualRow(page, y, {
        type = "dropdown",
        text = S.LText("Frame Strata"),
        values = _G._KUIAR_STRATA_VALUES or { MEDIUM = "Medium" },
        order = _G._KUIAR_STRATA_ORDER or { "MEDIUM" },
        getValue = displayReader("frameStrata", "MEDIUM"),
        setValue = displayWriter("frameStrata", function()
            local apply = _G._KUIAR_ApplyStrata
            if apply then apply() end
        end),
    }, { type = "label", text = "" })
    y = y - h
    fitRowDropdowns(frame)

    frame, h = W:Spacer(page, y, 20)
    y = y - h

    local mappings = resetMappings()
    mappings.display = { section = displayHeader, target = row1 }
    mappings.showText = { section = displayHeader, target = row1 }
    return y
end

-----------------------------------------------------------------------------------------------------------------------
-- Group Readiness
-----------------------------------------------------------------------------------------------------------------------

-- The first row differs per client.
local function buildBuffsFirstRow(page, y)
    local W = KT.Widgets
    if client == "retail" then
        return W:DualRow(page, y,
            fieldToggle(S.LText("Show Others Missing"), P.RDB, "showOthersMissing"),
            fieldToggle(S.LText("Show Buffs Outside Instances"), P.RDB, "showNonInstanced"))
    end
    local entry = fieldToggle(S.LText("Show Buffs Outside Instances"), P.RDB, "showNonInstanced")
    return W:Toggle(page, entry.text, y, entry.getValue, entry.setValue)
end

local function buildGroupReadiness(page, y)
    local W = KT.Widgets
    local cells = {}
    local h, frame, items

    local buffHeader, firstRow
    buffHeader, h = W:SectionHeader(page, S.LText(S.Sections.RAID_BUFFS), y)
    y = y - h
    firstRow, h = buildBuffsFirstRow(page, y)
    y = y - h

    items = {}
    addCatalogue(items, _G._KUIAR_RAID_BUFFS, P.RDB)
    y = y - buildGrid(page, y, items, cells)
    frame, h = W:Spacer(page, y, 20)
    y = y - h

    local auraHeader, auraRow
    auraHeader, h = W:SectionHeader(page, S.LText(S.Sections.AURAS), y)
    y = y - h
    auraRow, h = W:DualRow(page, y,
        fieldToggle(S.LText("Show Auras Outside Instances"), P.ADB, "showNonInstanced"),
        fieldToggle(S.LText("Show Specials Outside Instances"), P.CDB, "showSpecialsNonInstanced"))
    y = y - h

    items = {}
    addCatalogue(items, _G._KUIAR_AURAS, P.ADB)
    y = y - buildGrid(page, y, items, cells)
    frame, h = W:Spacer(page, y, 20)
    y = y - h

    local mappings = resetMappings()
    mappings.raidbuff = { section = buffHeader, target = firstRow }
    mappings.aura = { section = auraHeader, target = auraRow }
    mapCells(mappings, cells)
    return y
end

-----------------------------------------------------------------------------------------------------------------------
-- Class Upkeep
-----------------------------------------------------------------------------------------------------------------------

local function buildClassUpkeep(page, y)
    local W = KT.Widgets
    local cells = {}
    local blocks = {
        { title = S.Sections.ROGUE, token = "ROGUE", first = _G._KUIAR_ROGUE_POISONS },
        { title = S.Sections.PALADIN, token = "PALADIN", first = _G._KUIAR_PALADIN_RITES },
        { title = S.Sections.SHAMAN, token = "SHAMAN", first = _G._KUIAR_SHAMAN_IMBUES, second = _G._KUIAR_SHAMAN_SHIELDS },
    }
    for _, block in ipairs(blocks) do
        local frame, h = W:SectionHeader(page, S.LText(block.title), y)
        y = y - h
        local items = {}
        addCatalogue(items, block.first, P.CDB, block.token)
        addCatalogue(items, block.second, P.CDB, block.token)
        y = y - buildGrid(page, y, items, cells)
        frame, h = W:Spacer(page, y, 10)
        y = y - h
    end

    mapCells(resetMappings(), cells)
    return y
end

-----------------------------------------------------------------------------------------------------------------------
-- Consumable Loadout
-----------------------------------------------------------------------------------------------------------------------

-- Toggle over consumables.enabled[key]. `after` runs even with no section.
local function kitToggle(text, key, after)
    return {
        type = "toggle",
        text = text,
        getValue = function() return P.IsOn(P.CDB(), key) end,
        setValue = function(value)
            local section = P.CDB()
            if section and section.enabled then
                section.enabled[key] = value
                P.RefreshAll()
                P.RebuildHeader()
            end
            if after then after() end
        end,
    }
end

-- Name of a food in the dropdown. Differs per client only when the item API gives nothing.
local function foodName(entry)
    local id = entry.itemID
    local lookup = C_Item and C_Item.GetItemInfo
    local name = lookup and lookup(id)
    if not name then
        if client == "retail" and lookup then
            name = lookup(id)
        else
            local global = _G.GetItemInfo
            name = global and global(id)
        end
    end
    return name or S.LText(entry.name)
end

local function flaskName(entry)
    local lookup = C_Spell and C_Spell.GetSpellInfo
    local info = lookup and lookup(entry.buffID)
    return info and info.name or S.LText(entry.name)
end

local function weaponName(entry)
    return S.LText(entry.name)
end

-- Toggle and "preferred" dropdown row data for one catalogue.
local function preferredDropdown(choiceKey, catalogue, nameOf)
    local values, order = { last_used = S.LText("Last Used") }, { "last_used" }
    if catalogue then
        for _, entry in ipairs(catalogue) do
            order[#order + 1] = entry.key
            values[entry.key] = nameOf(entry)
        end
    end
    return {
        type = "dropdown",
        text = S.LText("Preferred Click to Buff"),
        dropdownWidth = 220,
        values = values,
        order = order,
        getValue = function()
            local section = P.CDB()
            local chosen = section and section[choiceKey]
            -- A key this build no longer lists (an imported or switched-to profile
            -- not yet scrubbed at login) shows the default instead of a blank box.
            return values[chosen] and chosen or "last_used"
        end,
        setValue = function(value)
            local section = P.CDB()
            if not section then return end
            section[choiceKey] = value
            P.RefreshAll()
        end,
    }
end

-- Pet note on the row, font first.
local function addPetNote(row, fontPath)
    local note = row:CreateFontString(nil, "OVERLAY")
    note:SetFont(fontPath, 11, P.Outline())
    note:SetTextColor(1, 1, 1, 0.45)
    note:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    note:SetText(S.LText("Click reminder icon to open pet menu"))
end

-- Choose Zones button, its popup and its cover, in the inky row's empty right region.
local function addChooseZones(region)
    local button = CreateFrame("Button", nil, region)
    button:SetSize(110, 24)
    button:SetPoint("RIGHT", region, "RIGHT", -20, 0)
    button:SetFrameLevel(region:GetFrameLevel() + 5)

    local border = KT:AddBorder(button, 1, 1, 1, 0.3)
    local dark = KT.KUI_PanelBaseColor
    local r, g, b = 0.05, 0.07, 0.09
    if dark then r, g, b = dark.r, dark.g, dark.b end
    local fill = KT.SolidTex(button, "BACKGROUND", r, g, b, 0.92)
    fill:SetAllPoints()
    local caption = KT.MakeFont(button, 12, nil, 1, 1, 1)
    caption:SetPoint("CENTER")
    caption:SetText(S.LText("Choose Zones"))

    AttachHoverFade(button, function(t)
        caption:SetTextColor(1, 1, 1, KT.lerp(0.5, 0.8, t))
        border:SetColor(1, 1, 1, KT.lerp(0.3, 0.5, t))
    end)

    button:SetScript("OnClick", function()
        local section = P.CDB()
        local hereID = C_Map.GetBestMapForUnit("player")
        KT.ShowInputPopup({
            title = S.LText("Inky Black Potion Zone IDs"),
            message = S.LText("The reminder for this potion appears only in the zones listed here.\nSeparate map IDs with commas, or add where you are now."),
            placeholder = hereID and string.format(S.LText("You are in zone %s"), tostring(hereID)) or S.LText("Map IDs"),
            maxLetters = 1000,
            initialText = section and section.inkyBlackZones or "",
            confirmText = S.LText("Save"),
            extraButton = {
                text = S.LText("Add Current Zone"),
                onClick = function(box)
                    local mapID = C_Map.GetBestMapForUnit("player")
                    if not mapID then return end
                    local listed = box:GetText() or ""
                    box:SetText(listed == "" and tostring(mapID) or (listed .. ", " .. mapID))
                end,
            },
            onConfirm = function(text)
                local now = P.CDB()
                if not now then return end
                now.inkyBlackZones = text or ""
                P.RefreshAll()
            end,
        })
    end)

    local check = addCover(button, S.LText("Inky Black Potion"), function()
        return not P.IsOn(P.CDB(), "inky_black")
    end)
    check()
    KT.RegisterWidgetRefresh(check)
end

local function buildConsumableLoadout(page, y, fontPath)
    local W = KT.Widgets
    local header, h, flaskRow, foodRow, petRow, weaponRow, frame

    header, h = W:SectionHeader(page, S.LText(S.Sections.CONSUMABLES), y)
    y = y - h

    flaskRow, h = W:DualRow(page, y, kitToggle(S.LText("Flask"), "flask"),
        preferredDropdown("preferredFlask", _G._KUIAR_FLASK_ITEMS, flaskName))
    y = y - h
    fitRowDropdowns(flaskRow)

    foodRow, h = W:DualRow(page, y, kitToggle(S.LText("Food"), "food"),
        preferredDropdown("preferredFood", _G._KUIAR_FOOD_ITEMS, foodName))
    y = y - h
    fitRowDropdowns(foodRow)

    local _, class = UnitClass("player")
    if P.PetIcons[class] then
        petRow, h = W:DualRow(page, y, kitToggle(S.LText("Pet Reminder"), "pet"), nil)
        y = y - h
        if petRow._leftRegion._control then addPetNote(petRow, fontPath) end
    end

    weaponRow, h = W:DualRow(page, y, kitToggle(S.LText("Weapon Enhancement"), "weapon_enchant"),
        preferredDropdown("preferredWeaponEnchant", _G._KUIAR_WEAPON_ENCHANT_CHOICES, weaponName))
    y = y - h
    fitRowDropdowns(weaponRow)

    frame, h = W:DualRow(page, y, kitToggle(S.LText("Augment Rune"), "augment_rune"), {
        type = "dropdown",
        text = S.LText("Display In:"),
        values = {
            mythic = S.LText("Mythic Only"),
            heroic_mythic = S.LText("Heroic and Mythic"),
            all = S.LText("All Instanced Content"),
        },
        order = { "mythic", "heroic_mythic", "all" },
        getValue = function()
            local section = P.CDB()
            return section and section.runeDisplayMode or "mythic"
        end,
        setValue = function(value)
            local section = P.CDB()
            if not section then return end
            section.runeDisplayMode = value
            P.RefreshAll()
        end,
    })
    local runeRow = frame
    y = y - h
    fitRowDropdowns(frame)

    local inkyRow
    inkyRow, h = W:DualRow(page, y, kitToggle(S.LText("Inky Black Potion"), "inky_black", function() KT:RefreshPage() end), nil)
    y = y - h
    addChooseZones(inkyRow._rightRegion)

    local mappings = resetMappings()
    mappings.consumable = { section = header, target = flaskRow }
    mappings["item:flask"] = { section = flaskRow, target = flaskRow }
    mappings["item:food"] = { section = foodRow, target = foodRow }
    if petRow then mappings["item:pet"] = { section = petRow, target = petRow } end
    mappings["item:weapon_enchant"] = { section = weaponRow, target = weaponRow }
    mappings["item:augment_rune"] = { section = runeRow, target = runeRow }
    return y
end

-----------------------------------------------------------------------------------------------------------------------
-- Entry points
-----------------------------------------------------------------------------------------------------------------------

local function BuildPage(pageName, parent, yOffset)
    KT:SetContentHeader(P.HeaderBuilder)

    local fontPath = KT.GetFontPath and KT.GetFontPath("auraReminders") or BUNDLED_FONT
    local y
    if pageName == S.Pages.CONTROL then
        y = buildControlCenter(parent, yOffset)
    elseif pageName == S.Pages.GROUP then
        y = buildGroupReadiness(parent, yOffset)
    elseif pageName == S.Pages.CLASS then
        y = buildClassUpkeep(parent, yOffset)
    else
        y = buildConsumableLoadout(parent, yOffset, fontPath)
    end
    return math.abs(y)
end

function M.Setup(ctx)
    if not ctx or (ctx.client ~= "retail" and ctx.client ~= "forever") then
        error("AuraRemindersPageReminders.Setup: ctx.client must be \"retail\" or \"forever\"", 2)
    end
    client = ctx.client
    S, P = ctx.Widgets, ctx.Preview
    inset = KT.CONTENT_PAD or 16
    M.BuildPage = BuildPage
    M.AttachHoverFade = AttachHoverFade
end
