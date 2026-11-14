-- Aura Reminders options: the Talent Reminders page. A console to pick zones and one talent and add a reminder, and
-- the saved list under it.
-- Keeps every behaviour the specification flags as a suspected bug. No client difference: ctx.client selects nothing.

local _, ns = ...
local KT = ns.KT or (LibStub and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))
if not KT then return end

local BUNDLED_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local CLOSE_ICON = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\kui-close.png"
local GLOW_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\InstallerWindow\\Toggle\\soft_glow.png"
local LINE_HEIGHT, BAND_HEIGHT, ICON_SIZE = 28, 50, 28
local PAGE_INSET, CONSOLE_PAD, CONSOLE_HEIGHT, LIST_TITLE_HEIGHT = 4, 16, 166, 22
local TITLE_Y, ZONE_CAPTION_Y, ZONE_BUTTON_Y, TALENT_CAPTION_Y, CONTROL_Y = -14, -42, -58, -104, -120
local ZONE_BUTTON_HEIGHT, CONTROL_HEIGHT, CONTROL_GAP, ADD_BUTTON_WIDTH = 34, 30, 10, 160
local GRID_STEP, GRID_ALPHA, CORNER_LENGTH, CORNER_THICKNESS = 40, 0.035, 10, 2
local SWITCH_WIDTH, SWITCH_HEIGHT, SWITCH_KNOB = 34, 18, 14
local TOOLTIP_TEXT = "Enable this to display a reminder to untalent\nout of this when it is not needed\n(all other dungeons/raids not selected)."

local M = {}
ns.AuraRemindersPageTalents = M

-- Set by Setup.
local S, P, Reminders

-----------------------------------------------------------------------------------------------------------------------
-- Talent data, measured at the build
-----------------------------------------------------------------------------------------------------------------------

-- The active config and the nodes of its first tree, or nothing when any step is missing.
local function readTree()
    local getConfig = C_ClassTalents and C_ClassTalents.GetActiveConfigID
    local config = getConfig and getConfig()
    if not config then return end
    local getInfo = C_Traits and C_Traits.GetConfigInfo
    local info = getInfo and getInfo(config)
    local tree = info and info.treeIDs and info.treeIDs[1]
    if not tree then return end
    local nodeIDs = C_Traits.GetTreeNodes(tree)
    if not nodeIDs then return end
    return config, nodeIDs
end

-- Midpoint of the widest gap between neighbouring posX values; the first widest when tied; 0 with fewer than two.
local function splitOf(nodes)
    local xs = {}
    for i, node in ipairs(nodes) do xs[i] = node.posX end
    table.sort(xs)
    local split, widest = 0, -1
    for i = 2, #xs do
        local gap = xs[i] - xs[i - 1]
        if gap > widest then
            widest = gap
            split = (xs[i] + xs[i - 1]) / 2
        end
    end
    return split
end

local function spellOfEntry(config, entryID)
    local entry = C_Traits.GetEntryInfo(config, entryID)
    local definitionID = entry and entry.definitionID
    local definition = definitionID and C_Traits.GetDefinitionInfo(definitionID)
    return definition and definition.spellID
end

-- The values and order of one side's dropdown.
local function choicesFrom(found)
    table.sort(found, function(a, b) return a.name < b.name end)
    local values, order = { [0] = S.LText("Select a talent...") }, { 0 }
    for _, talent in ipairs(found) do
        values[talent.spellID] = talent.name
        order[#order + 1] = talent.spellID
    end
    return values, order
end

-- Reads the tree once and returns the choices of the class side and the spec side.
local function readChoices()
    local classFound, specFound = {}, {}
    local config, nodeIDs = readTree()
    if config then
        local kept = {}
        for _, nodeID in ipairs(nodeIDs) do
            local node = C_Traits.GetNodeInfo(config, nodeID)
            if node and node.ID and node.ID > 0 and node.entryIDs and #node.entryIDs > 0 then
                kept[#kept + 1] = node
            end
        end
        local split = splitOf(kept)
        local classSeen, specSeen = {}, {}
        for _, node in ipairs(kept) do
            if not node.subTreeID then
                local isClass = node.posX < split
                local found, seen = isClass and classFound or specFound, isClass and classSeen or specSeen
                for _, entryID in ipairs(node.entryIDs) do
                    local spell = spellOfEntry(config, entryID)
                    local name = spell and C_Spell.GetSpellName(spell)
                    if name and name ~= "" and not seen[spell] then
                        seen[spell] = true
                        found[#found + 1] = { spellID = spell, name = name }
                    end
                end
            end
        end
    end
    local classValues, classOrder = choicesFrom(classFound)
    local specValues, specOrder = choicesFrom(specFound)
    return classValues, classOrder, specValues, specOrder
end

-----------------------------------------------------------------------------------------------------------------------
-- Page
-----------------------------------------------------------------------------------------------------------------------

-- A form in progress handed to the next build when removing a reminder rebuilds the page.
local carriedForm

-- Everything below lives in one build's closure: the font, the accent table, the form, the flash frames.
local function newBuild(page)
    local B = {}
    B.page = page
    B.fontPath = KT.GetFontPath and KT.GetFontPath("auraReminders") or BUNDLED_FONT
    B.accent = KT.KUI_ACCENT
    B.form = carriedForm or { zones = {}, spellID = nil, spellName = nil, classID = 0, specID = 0 }
    carriedForm = nil
    B.flashes = {}
    B.zones = _G._KUIAR_TALENT_REMINDER_ZONES or {}
    return B
end

-- A font string with its font set before anything can give it text.
local function newText(B, parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(B.fontPath, size, P.Outline())
    return fs
end

-- Square with a fill and a border; used by zone lines.
local function newSquare(parent, size)
    local square = CreateFrame("Frame", nil, parent)
    square:SetSize(size, size)
    local fill = square:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.06, 0.06, 0.08, 1)
    KT:AddBorder(square, 1, 1, 1, 0.12)
    return square
end

local function newMark(B, square, size)
    local mark = square:CreateTexture(nil, "OVERLAY")
    mark:SetSize(size, size)
    mark:SetPoint("CENTER")
    mark:SetColorTexture(B.accent.r, B.accent.g, B.accent.b, 1)
    return mark
end

-- Marked zone names, raw and sorted.
local function markedNames(B)
    local names = {}
    for i, zone in ipairs(B.zones) do
        if B.form.zones[i] then names[#names + 1] = zone.name end
    end
    table.sort(names)
    return names
end

local function zoneSummary(B)
    local names = markedNames(B)
    if #names == 0 then return "Select Dungeon/Raid" end
    return table.concat(names, ", ")
end

local function hasMarkedZone(B)
    for i = 1, #B.zones do
        if B.form.zones[i] == true then return true end
    end
    return false
end

-- The console's live count of what the form holds.
local function paintReadout(B)
    B.readout:SetText(string.format(S.LText("Zones: %d  ·  Talent: %d"), #markedNames(B), B.form.spellID and 1 or 0))
end

-----------------------------------------------------------------------------------------------------------------------
-- Console: the framed grid that holds the form
-----------------------------------------------------------------------------------------------------------------------

-- Faint grid lines over the panel's fill.
local function addGrid(panel, width, height)
    local function line()
        local tex = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
        tex:SetColorTexture(1, 1, 1, GRID_ALPHA)
        return tex
    end
    for x = GRID_STEP, width - 1, GRID_STEP do
        local tex = line()
        tex:SetWidth(1)
        tex:SetPoint("TOPLEFT", panel, "TOPLEFT", x, 0)
        tex:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, 0)
    end
    for y = GRID_STEP, height - 1, GRID_STEP do
        local tex = line()
        tex:SetHeight(1)
        tex:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
        tex:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -y)
    end
end

-- An accent bracket on each corner of the panel, over its border.
local function addCorners(panel)
    local corners = CreateFrame("Frame", nil, panel)
    corners:SetAllPoints()
    corners:SetFrameLevel(panel:GetFrameLevel() + 3)
    for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local across = corners:CreateTexture(nil, "OVERLAY")
        across:SetSize(CORNER_LENGTH, CORNER_THICKNESS)
        across:SetPoint(point, corners, point, 0, 0)
        KT:SetAccentTexture(across, 1)
        local down = corners:CreateTexture(nil, "OVERLAY")
        down:SetSize(CORNER_THICKNESS, CORNER_LENGTH)
        down:SetPoint(point, corners, point, 0, 0)
        KT:SetAccentTexture(down, 1)
    end
end

-- Title, line, readout across one row; returns the readout.
local function newTitleBar(B, parent, x, y, titleText, lineAlpha)
    local title = newText(B, parent, 12)
    title:SetTextColor(1, 1, 1, 1)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    title:SetText(titleText)

    local readout = newText(B, parent, 11)
    readout:SetTextColor(1, 1, 1, 0.6)
    readout:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -x, y)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", title, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", readout, "LEFT", -10, 0)
    KT:SetAccentTexture(line, lineAlpha)
    return readout
end

-- A caption over a control.
local function newCaption(B, parent, x, y, width, text)
    local caption = newText(B, parent, 11)
    caption:SetTextColor(KT.TEXT_SECTION_R or 0.45, KT.TEXT_SECTION_G or 0.50, KT.TEXT_SECTION_B or 0.55, KT.TEXT_SECTION_A or 1)
    caption:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    caption:SetWidth(width)
    caption:SetJustifyH("LEFT")
    caption:SetWordWrap(false)
    caption:SetText(text)
    return caption
end

-- A caption's text led by its step number in the accent.
local function stepCaption(number, text)
    return S.AccentColorCode() .. number .. "|r  " .. text
end

-- The panel with its fill, grid, corners and title bar. Returns it and the width its content has.
local function buildConsole(B, y)
    local page = B.page
    local width = page:GetWidth() - 2 * PAGE_INSET
    local panel = CreateFrame("Frame", nil, page)
    panel:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_INSET, y)
    panel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -PAGE_INSET, y)
    panel:SetHeight(CONSOLE_HEIGHT)

    local fill = panel:CreateTexture(nil, "BACKGROUND", nil, 0)
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 0.45)
    KT:AddBorder(panel, 1, 1, 1, 0.10)
    addGrid(panel, width, CONSOLE_HEIGHT)
    addCorners(panel)

    B.readout = newTitleBar(B, panel, CONSOLE_PAD, TITLE_Y, S.LText("NEW REMINDER"), 0.55)
    return panel, width - 2 * CONSOLE_PAD
end

-----------------------------------------------------------------------------------------------------------------------
-- Zones
-----------------------------------------------------------------------------------------------------------------------

-- One zone line; returns its mark so the list can repaint it.
local function buildZoneLine(B, child, i, zone)
    local line = CreateFrame("Button", nil, child)
    line:SetHeight(LINE_HEIGHT)
    line:SetPoint("TOPLEFT", child, "TOPLEFT", 1, -(i - 1) * LINE_HEIGHT)
    line:SetPoint("TOPRIGHT", child, "TOPRIGHT", -1, -(i - 1) * LINE_HEIGHT)

    local glow = line:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, 0)

    local square = newSquare(line, 14)
    square:SetPoint("LEFT", line, "LEFT", 10, 0)
    local mark = newMark(B, square, 10)
    mark:Hide()

    local text = newText(B, line, 11)
    text:SetTextColor(0.75, 0.75, 0.78, 1)
    text:SetPoint("LEFT", square, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", line, "RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    if zone.type == "raid" then
        text:SetText(string.format(S.LText("%s (Raid)"), zone.name))
    else
        text:SetText(zone.name)
    end

    line:SetScript("OnEnter", function()
        text:SetTextColor(1, 1, 1, 1)
        glow:SetColorTexture(1, 1, 1, 0.08)
    end)
    line:SetScript("OnLeave", function()
        text:SetTextColor(0.75, 0.75, 0.78, 1)
        glow:SetColorTexture(1, 1, 1, 0)
    end)
    line:SetScript("OnClick", function()
        B.form.zones[i] = not B.form.zones[i]
        mark:SetShown(not not B.form.zones[i])
        B.zoneLabel:SetText(zoneSummary(B))
        paintReadout(B)
    end)
    return mark
end

-- The floating list of zones, as wide as its button. Its watcher stays set and so runs only while the list is shown.
local function buildZoneList(B, button, width)
    local count = #B.zones
    local list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetFrameLevel(200)
    list:SetClampedToScreen(true)
    list:SetSize(width, math.min(count * LINE_HEIGHT + 8, 300))
    list:Hide()
    local fill = list:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.10, 0.10, 0.12, 0.97)
    KT:AddBorder(list, 1, 1, 1, 0.12)

    local view = CreateFrame("ScrollFrame", nil, list)
    view:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -4)
    view:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 0, 4)
    local child = CreateFrame("Frame", nil, view)
    child:SetSize(width, math.max(1, count * LINE_HEIGHT))
    view:SetScrollChild(child)

    local offset = 0
    local function onWheel(_, delta)
        local limit = math.max(0, child:GetHeight() - view:GetHeight())
        offset = math.min(limit, math.max(0, offset - delta * 56))
        view:SetVerticalScroll(offset)
    end
    view:SetScript("OnMouseWheel", onWheel)
    list:SetScript("OnMouseWheel", onWheel)

    local marks = {}
    for i, zone in ipairs(B.zones) do
        marks[i] = buildZoneLine(B, child, i, zone)
    end

    list:SetScript("OnShow", function(self)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        offset = 0
        view:SetVerticalScroll(0)
        for i, mark in ipairs(marks) do
            mark:SetShown(not not B.form.zones[i])
        end
    end)
    list:SetScript("OnUpdate", function(self)
        if IsMouseButtonDown("LeftButton") and not self:IsMouseOver() and not button:IsMouseOver() then
            self:Hide()
        end
    end)
    return list
end

local function buildZonePicker(B, panel, width)
    local PP = KT.PP
    newCaption(B, panel, CONSOLE_PAD, ZONE_CAPTION_Y, width, stepCaption("01", S.LText("Dungeons & Raids")))

    local button = CreateFrame("Button", nil, panel)
    PP.Size(button, width, ZONE_BUTTON_HEIGHT)
    PP.Point(button, "TOPLEFT", panel, "TOPLEFT", CONSOLE_PAD, ZONE_BUTTON_Y)
    button:SetFrameLevel(panel:GetFrameLevel() + 1)
    B.zoneButton = button

    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.075, 0.113, 0.141, 0.9)
    KT:AddBorder(button, 1, 1, 1, 0.20)
    button:SetScript("OnEnter", function() fill:SetColorTexture(0.095, 0.143, 0.181, 1) end)
    button:SetScript("OnLeave", function() fill:SetColorTexture(0.075, 0.113, 0.141, 0.9) end)

    local label = newText(B, button, 13)
    label:SetTextColor(1, 1, 1, 0.50)
    label:SetMaxLines(1)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(hasMarkedZone(B) and zoneSummary(B) or S.LText("Select Dungeon/Raid"))
    B.zoneLabel = label
    local chevron = S.AddChevron(button)
    label:SetPoint("LEFT", button, "LEFT", 14, 0)
    label:SetPoint("RIGHT", chevron, "LEFT", -5, 0)

    local list = buildZoneList(B, button, width)
    button:SetScript("OnClick", function() list:SetShown(not list:IsShown()) end)
end

-----------------------------------------------------------------------------------------------------------------------
-- Talents
-----------------------------------------------------------------------------------------------------------------------

-- Caption and dropdown of one side, at x on the console.
local function buildSide(B, panel, x, width, captionText, values, order, getter, setter, options)
    newCaption(B, panel, x, TALENT_CAPTION_Y, width, captionText)
    local dropdown = KT.BuildDropdownControl(panel, width, panel:GetFrameLevel() + 1, values, order, getter, setter, options)
    KT.PP.Point(dropdown, "TOPLEFT", panel, "TOPLEFT", x, CONTROL_Y)
    return dropdown
end

-- Both sides; returns the x where the row has room left.
local function buildTalentPickers(B, panel, width)
    local form = B.form
    local sideWidth = math.floor((width - ADD_BUTTON_WIDTH - 2 * CONTROL_GAP) / 2)

    local classValues, classOrder, specValues, specOrder = readChoices()
    local options = {
        rowHeight = 24,
        maxVisibleRows = 10,
        iconSize = 18,
        getIcon = function(id)
            id = tonumber(id)
            if not id or id <= 0 then return nil end
            if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
        end,
    }

    -- Choosing: a talent clears the other side and refreshes it; 0 clears only this side and the form's talent.
    local function chooser(ownField, otherField, values, otherDropdownField)
        return function(id)
            form[ownField] = id
            if id == 0 then
                form.spellID, form.spellName = nil, nil
                paintReadout(B)
                return
            end
            form[otherField] = 0
            form.spellID, form.spellName = id, values[id]
            B[otherDropdownField].Refresh()
            paintReadout(B)
        end
    end

    B.classDropdown = buildSide(B, panel, CONSOLE_PAD, sideWidth, stepCaption("02", S.LText("Class Talent")),
        classValues, classOrder,
        function() return form.classID end,
        chooser("classID", "specID", classValues, "specDropdown"), options)
    B.specDropdown = buildSide(B, panel, CONSOLE_PAD + sideWidth + CONTROL_GAP, sideWidth,
        string.format(S.LText("or %s"), S.LText("Spec Talent")), specValues, specOrder,
        function() return form.specID end,
        chooser("specID", "classID", specValues, "classDropdown"), options)
    return CONSOLE_PAD + 2 * (sideWidth + CONTROL_GAP)
end

-----------------------------------------------------------------------------------------------------------------------
-- Adding
-----------------------------------------------------------------------------------------------------------------------

-- The red flash: three straight-edged blinks that lose strength until the border is gone.
-- One persistent frame per target for this build, a fresh clock per flash.
local FLASH_SECONDS = 1.2
local FLASH_BLINK_SECONDS = 0.4
local function flash(B, target)
    local frame = B.flashes[target]
    if not frame then
        frame = CreateFrame("Frame", nil, target)
        frame:SetAllPoints()
        frame:SetFrameLevel(target:GetFrameLevel() + 10)
        KT:AddBorder(frame, 0.95, 0.25, 0.2, 1)
        B.flashes[target] = frame
    end
    frame:Show()
    frame:SetAlpha(1)
    local clock = 0
    frame:SetScript("OnUpdate", function(self, dt)
        clock = clock + dt
        if clock >= FLASH_SECONDS then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            return
        end
        local blink = math.abs((clock / FLASH_BLINK_SECONDS) % 1 * 2 - 1)
        self:SetAlpha((1 - clock / FLASH_SECONDS) * (0.4 + 0.6 * blink))
    end)
end

-- The saved record for the form as it stands.
local function newRecord(B)
    local ids = {}
    for i, zone in ipairs(B.zones) do
        if B.form.zones[i] then
            local id = tonumber(zone.instanceID)
            if id then ids[#ids + 1] = id end
        end
    end
    table.sort(ids)
    return {
        zoneNames = markedNames(B),
        zoneIDs = ids,
        spellID = B.form.spellID,
        spellName = B.form.spellName,
        showNotNeeded = false,
    }
end

-- The list changed height, so the rows and the sections under them are laid out again.
local function relayoutPage()
    KT:RefreshPage(true)
end

-- A successful add leaves an empty form: the rebuild starts a new one.
local function onAddClick(B)
    if not hasMarkedZone(B) then
        flash(B, B.zoneButton)
        return
    end
    if not B.form.spellID then
        flash(B, B.classDropdown)
        flash(B, B.specDropdown)
        return
    end
    local profile = P.DB()
    if not profile then return end
    if not profile.talentReminders then profile.talentReminders = {} end
    local reminders = profile.talentReminders
    for _, entry in ipairs(reminders) do
        if entry.spellID == B.form.spellID then
            flash(B, B.classDropdown)
            flash(B, B.specDropdown)
            return
        end
    end
    reminders[#reminders + 1] = newRecord(B)
    P.RefreshAll()
    relayoutPage()
end

-- A soft accent glow that the button clips.
local function newButtonGlow(host, size)
    local glow = host:CreateTexture(nil, "ARTWORK")
    glow:SetSize(size, size)
    glow:SetTexture(GLOW_TEXTURE)
    glow:SetBlendMode("ADD")
    KT:SetAccentVertexColor(glow, 1)
    P.NoSnap(glow)
    return glow
end

local function buildAddButton(B, panel, x, width)
    local accent = B.accent
    local button = CreateFrame("Button", nil, panel)
    button:SetSize(width, CONTROL_HEIGHT)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, CONTROL_Y)
    button:SetFrameLevel(panel:GetFrameLevel() + 1)
    local dark = KT.KUI_PanelBaseColor
    local r, g, b = 0.05, 0.07, 0.09
    if dark then r, g, b = dark.r, dark.g, dark.b end
    local fill = KT.SolidTex(button, "BACKGROUND", r, g, b, 0.92)
    fill:SetAllPoints()

    local clip = CreateFrame("Frame", nil, button)
    clip:SetAllPoints()
    clip:SetClipsChildren(true)
    local host = CreateFrame("Frame", nil, clip)
    host:SetAllPoints()
    local glowNear, glowFar = newButtonGlow(host, 46), newButtonGlow(host, 70)

    -- Above the glows: the text, its underline and the border.
    local face = CreateFrame("Frame", nil, button)
    face:SetAllPoints()
    face:SetFrameLevel(button:GetFrameLevel() + 5)
    local border = KT:AddBorder(face, accent.r, accent.g, accent.b, 0.7)
    local text = newText(B, face, 13)
    text:SetPoint("LEFT", face, "LEFT", 12, 1)
    text:SetPoint("RIGHT", face, "RIGHT", -12, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(S.LText("Add Reminder"))
    local underline = face:CreateTexture(nil, "OVERLAY")
    underline:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    underline:SetWidth(math.min(text:GetStringWidth(), width - 24))

    -- The glows drift inside the fade the button already runs on hover.
    local function apply(t)
        local alpha = KT.lerp(0.7, 1, t)
        text:SetTextColor(1, 1, 1, KT.lerp(0.85, 1, t))
        border:SetColor(accent.r, accent.g, accent.b, alpha)
        underline:SetColorTexture(accent.r, accent.g, accent.b, alpha)
        underline:SetHeight(t < 0.5 and 1 or 2)
        glowNear:SetAlpha(KT.lerp(0.45, 0.85, t))
        glowNear:SetPoint("CENTER", host, "TOPRIGHT", KT.lerp(-20, -6, t), KT.lerp(-6, -12, t))
        glowFar:SetAlpha(KT.lerp(0.2, 0.55, t))
        glowFar:SetPoint("CENTER", host, "BOTTOMRIGHT", KT.lerp(-58, -96, t), KT.lerp(-4, 2, t))
    end
    apply(0)
    Reminders.AttachHoverFade(button, apply)
    button:SetScript("OnClick", function() onAddClick(B) end)
end

-----------------------------------------------------------------------------------------------------------------------
-- Saved list
-----------------------------------------------------------------------------------------------------------------------

-- A row: closing line and hover tint; returns it with the function that lights it. Content is the caller's.
local function newBand(container, i)
    local band = CreateFrame("Frame", nil, container)
    band:SetHeight(BAND_HEIGHT)
    band:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * BAND_HEIGHT)
    band:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -(i - 1) * BAND_HEIGHT)
    local tint = band:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints()
    KT:SetAccentTexture(tint, 0.14)
    tint:Hide()
    local closing = band:CreateTexture(nil, "ARTWORK")
    closing:SetHeight(1)
    closing:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", 0, 0)
    closing:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", 0, 0)
    KT:SetAccentTexture(closing, 0.22)
    return band, function(lit) tint:SetShown(lit) end
end

local function zoneTextOf(entry)
    if entry.zoneNames and #entry.zoneNames > 0 then return table.concat(entry.zoneNames, ", ") end
    return entry.zoneName or "Unknown"
end

-- Left half: remove button, icon, talent over its zones.
local function buildBandLeft(B, band, i, entry, light)
    local PP = KT.PP
    local remove = CreateFrame("Button", nil, band)
    remove:SetSize(20, 20)
    PP.Point(remove, "LEFT", band, "LEFT", 10, 0)
    remove:SetFrameLevel(band:GetFrameLevel() + 5)
    remove:SetAlpha(0.75)
    local cross = remove:CreateTexture(nil, "OVERLAY")
    PP.Size(cross, 14, 14)
    PP.Point(cross, "CENTER", remove, "CENTER", 0, 0)
    P.NoSnap(cross)
    cross:SetTexture(CLOSE_ICON)
    remove:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        light(true)
    end)
    remove:SetScript("OnLeave", function(self)
        self:SetAlpha(0.75)
        light(false)
    end)
    remove:SetScript("OnClick", function()
        local profile = P.DB()
        if not profile then return end
        if profile.talentReminders then table.remove(profile.talentReminders, i) end
        P.RefreshAll()
        carriedForm = B.form
        relayoutPage()
    end)

    local edge = band:CreateTexture(nil, "ARTWORK", nil, 1)
    edge:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    edge:SetPoint("LEFT", remove, "RIGHT", 7, 0)
    edge:SetColorTexture(0, 0, 0, 1)
    local icon = band:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", edge, "CENTER", 0, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetTexture(P.Tex(entry.spellID))

    local talentText = newText(B, band, 13)
    talentText:SetTextColor(1, 1, 1, 1)
    talentText:SetPoint("TOPLEFT", edge, "TOPRIGHT", 10, 0)
    talentText:SetPoint("RIGHT", band, "CENTER", -12, 0)
    talentText:SetJustifyH("LEFT")
    talentText:SetWordWrap(false)
    talentText:SetMaxLines(1)
    talentText:SetText(entry.spellName or S.LText("Unknown"))

    local zoneText = newText(B, band, 11)
    zoneText:SetTextColor(1, 1, 1, 0.55)
    zoneText:SetPoint("BOTTOMLEFT", edge, "BOTTOMRIGHT", 10, 0)
    zoneText:SetPoint("RIGHT", band, "CENTER", -12, 0)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)
    zoneText:SetMaxLines(1)
    zoneText:SetText(zoneTextOf(entry))
end

-- Right half: click area, option text, switch, tooltip zone.
local function buildBandRight(B, band, i, light)
    local half = CreateFrame("Button", nil, band)
    half:SetPoint("LEFT", band, "CENTER", 0, 0)
    half:SetPoint("TOPRIGHT", band, "TOPRIGHT", 0, 0)
    half:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", 0, 0)
    half:SetFrameLevel(band:GetFrameLevel() + 3)

    local track = KT.Widgets:RoundRect(band, "ARTWORK", 0, SWITCH_HEIGHT / 2)
    track:SetSize(SWITCH_WIDTH, SWITCH_HEIGHT)
    track:SetPoint("RIGHT", band, "RIGHT", -14, 0)
    local knob = KT.Widgets:RoundRect(band, "OVERLAY", 0, SWITCH_KNOB / 2)
    knob:SetSize(SWITCH_KNOB, SWITCH_KNOB)

    local option = newText(B, band, 12)
    option:SetPoint("RIGHT", track.box, "LEFT", -10, 0)
    option:SetWordWrap(false)
    option:SetText(S.LText("Show 'Not Needed' Reminder"))

    -- The saved entry, looked up with a test of the profile only.
    local function savedEntry()
        local profile = P.DB()
        return profile and profile.talentReminders[i]
    end

    local function paint(hovered)
        local entry = savedEntry()
        local on = entry and entry.showNotNeeded == true
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", track.box, "LEFT", on and (SWITCH_WIDTH - SWITCH_KNOB - 2) or 2, 0)
        if on then
            track:SetColor(B.accent.r, B.accent.g, B.accent.b, 1)
            knob:SetColor(1, 1, 1, 1)
        else
            track:SetColor(KT.MenuSkins:Color("controlOff"))
            knob:SetColor(0.55, 0.55, 0.6, 1)
        end
        option:SetTextColor(1, 1, 1, on and 1 or (hovered and 0.8 or 0.4))
    end
    paint(false)

    half:SetScript("OnEnter", function()
        paint(true)
        light(true)
    end)
    half:SetScript("OnLeave", function()
        paint(false)
        light(false)
    end)
    half:SetScript("OnClick", function()
        local entry = savedEntry()
        if not entry then return end
        entry.showNotNeeded = not entry.showNotNeeded
        paint(true)
        P.RefreshAll()
    end)

    local tip = CreateFrame("Frame", nil, band)
    tip:SetFrameLevel(half:GetFrameLevel() + 1)
    tip:EnableMouse(true)
    tip:SetPoint("LEFT", option, "LEFT", 0, 0)
    tip:SetPoint("RIGHT", option, "RIGHT", 0, 0)
    tip:SetPoint("TOP", option, "TOP", 0, 4)
    tip:SetPoint("BOTTOM", option, "BOTTOM", 0, -4)
    tip:SetScript("OnEnter", function()
        light(true)
        KT.ShowWidgetTooltip(option, S.LText(TOOLTIP_TEXT))
    end)
    tip:SetScript("OnLeave", function()
        light(false)
        KT.HideWidgetTooltip()
    end)
end

-- Title bar and rows of the saved list; returns the height they take. Adding or removing rebuilds the page.
local function buildList(B, y)
    local page = B.page
    local count = newTitleBar(B, page, PAGE_INSET, y, S.LText("ACTIVE REMINDERS"), 0.25)

    local container = CreateFrame("Frame", nil, page)
    container:SetPoint("TOPLEFT", page, "TOPLEFT", PAGE_INSET, y - LIST_TITLE_HEIGHT)
    container:SetPoint("TOPRIGHT", page, "TOPRIGHT", -PAGE_INSET, y - LIST_TITLE_HEIGHT)
    container:SetHeight(1)

    local profile = P.DB()
    if not profile then return LIST_TITLE_HEIGHT end
    local reminders = profile.talentReminders or {}
    count:SetText(#reminders)

    if #reminders == 0 then
        local band = newBand(container, 1)
        local message = newText(B, band, 13)
        message:SetTextColor(0.5, 0.5, 0.5, 1)
        message:SetPoint("CENTER")
        message:SetText(S.LText("No talent reminders configured"))
        container:SetHeight(BAND_HEIGHT)
        return LIST_TITLE_HEIGHT + BAND_HEIGHT
    end

    for i, entry in ipairs(reminders) do
        local band, light = newBand(container, i)
        band:EnableMouse(true)
        band:SetScript("OnEnter", function() light(true) end)
        band:SetScript("OnLeave", function() light(false) end)
        buildBandLeft(B, band, i, entry, light)
        buildBandRight(B, band, i, light)
    end
    local height = #reminders * BAND_HEIGHT
    container:SetHeight(height)
    return LIST_TITLE_HEIGHT + height
end

local function BuildPage(_, parent, yOffset)
    local W = KT.Widgets
    local B = newBuild(parent)
    local y = yOffset
    local _, h

    _, h = W:SectionHeader(parent, S.LText("TALENT REMINDER STATUS"), y)
    y = y - h
    _, h = W:Toggle(parent, S.LText("Enable Module"), y,
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
    y = y - 14

    local panel, width = buildConsole(B, y)
    buildZonePicker(B, panel, width)
    local addX = buildTalentPickers(B, panel, width)
    buildAddButton(B, panel, addX, width - addX + CONSOLE_PAD)
    paintReadout(B)
    y = y - CONSOLE_HEIGHT - 18

    y = y - buildList(B, y)

    _, h = W:Spacer(parent, y, 20)
    y = y - h
    return math.abs(y)
end

function M.Setup(ctx)
    if not ctx or (ctx.client ~= "retail" and ctx.client ~= "forever") then
        error("AuraRemindersPageTalents.Setup: ctx.client must be \"retail\" or \"forever\"", 2)
    end
    S, P, Reminders = ctx.Widgets, ctx.Preview, ctx.Reminders
    M.BuildPage = BuildPage
end
