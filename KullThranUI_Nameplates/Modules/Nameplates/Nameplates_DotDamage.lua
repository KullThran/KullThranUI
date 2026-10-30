if KT_CLIENT_BLOCKED then return end

local _, ns = ...

-- Pending DoT damage on enemy nameplates: a marker over the health bar for the damage your bleeds and DoTs
-- still have to deal, and optionally a kill icon when that is enough to finish the mob. The damage comes
-- from the DoT tracker (Nameplates_DotTracker.lua). Third-party code: see THIRD_PARTY_NOTICES.txt.
--
-- The marker is a status bar over the plate's health bar with a range of 0..max health and a value of the
-- pending damage, so if the health ends inside the marker the DoTs will kill it. Health is secret in combat,
-- and status bars accept secret values, so the comparison is left to the widgets. The kill icon works the
-- same way: a very long bar (range 0..health, value = damage) inside a small clipping window, with the icon
-- at the end of its fill, which only reaches the window once damage >= health.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TEXTURE_DIR = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\DotDamage\\"
local UPDATE_INTERVAL = 0.1
local MAX_SEGMENTS = 4
local ICON_BAR_LENGTH = 10000

ns.DOT_DAMAGE_DEFAULTS = {
    dotDamageKillIcon = false,
    dotDamageIcon = "skull",
    dotDamageIconSize = 18,
    dotDamageIconPosition = "left",
    dotDamageIconOffsetX = 0,
    dotDamageIconOffsetY = 0,
    dotDamageColors = "single",
    dotDamageFill = "flat",
    dotDamageColor = { r = 1, g = 1, b = 1 },
    dotDamageFillOpacity = 45,
    dotDamageOutline = "solid",
    dotDamageDashLength = 2,
    dotDamageOutlineThickness = 1,
    dotDamageOutlineColor = { r = 1, g = 1, b = 1 },
    dotDamageOutlineOpacity = 100,
    dotDamageWaitFirstTick = "off",
}
local DEFAULTS = ns.DOT_DAMAGE_DEFAULTS

-- Choices for the options, in display order: { value, label }.
ns.DOT_DAMAGE_LISTS = {
    icons = {
        { "skull", "Raid skull", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
        { "cross", "Red X", "Interface\\RaidFrame\\ReadyCheck-NotReady" },
        { "check", "Green checkmark", "Interface\\RaidFrame\\ReadyCheck-Ready" },
        { "boss", "Boss skull", "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
        { "shades", "Sunglasses", TEXTURE_DIR .. "Sunglasses" },
    },
    fills = {
        { "none", "None" },
        { "flat", "Flat", WHITE },
        { "smooth", "Health bar texture", "Interface\\TargetingFrame\\UI-StatusBar" },
        { "raid", "Raid bar texture", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
        { "stripes", "Diagonal stripes", TEXTURE_DIR .. "Stripes", true },
    },
    outlines = { { "dashed", "Dashed" }, { "solid", "Solid" }, { "none", "None" } },
    dashLengths = {
        { 1, "Fine dots (1px)" }, { 2, "Dots (2px)" }, { 4, "Short dashes (4px)" },
        { 8, "Dashes (8px)" }, { 16, "Long dashes (16px)" },
    },
    iconPositions = {
        { "right", "Right of the health bar" }, { "left", "Left of the health bar" },
        { "above", "Above the health bar" },
    },
    dotColors = {
        { "single", "One color (fill color)" }, { "school", "By spell school" },
        { "each", "Different color per DoT" },
    },
    waitModes = {
        { "off", "Never (estimate straight away)" }, { "unsure", "When unsure" },
        { "always", "Always (real ticks only)" },
    },
}
local LISTS = ns.DOT_DAMAGE_LISTS

-- "By spell school" colors, keyed by school mask (Frostfire = Fire + Frost).
local SCHOOL_COLORS = {
    [1] = { 1, 0.3, 0.3 },      -- Physical (bleeds)
    [2] = { 1, 0.9, 0.45 },     -- Holy
    [4] = { 1, 0.55, 0.15 },    -- Fire
    [8] = { 0.35, 1, 0.35 },    -- Nature
    [16] = { 0.45, 0.8, 1 },    -- Frost
    [20] = { 0.75, 0.6, 1 },    -- Frostfire
    [32] = { 0.7, 0.35, 1 },    -- Shadow
    [64] = { 1, 0.55, 1 },      -- Arcane
}

-- "Different color per DoT": each spell keeps the palette color it got when first seen this session, so
-- colors don't shuffle when DoTs are recast or expire.
local DOT_PALETTE = {
    { 0.95, 0.3, 0.3 }, { 0.3, 0.75, 1 }, { 1, 0.8, 0.2 }, { 0.45, 1, 0.45 },
    { 0.85, 0.4, 1 }, { 1, 0.55, 0.15 }, { 0.3, 1, 0.9 }, { 1, 0.45, 0.75 },
}
local paletteIndexByName, nextPaletteIndex = {}, 1

local function Profile()
    return _G.KullThranUINameplatesDB or {}
end

local function Setting(key)
    local value = Profile()[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

local function IsEnabled()
    return Profile().dotDamageEnabled == true
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) == true
end

local function Readable(value)
    return value ~= nil and not IsSecret(value)
end

local function Find(list, value)
    for _, entry in ipairs(list) do
        if entry[1] == value then return entry end
    end
    return list[1]
end

local function ColorSetting(key)
    local c = Setting(key)
    local d = DEFAULTS[key]
    if type(c) ~= "table" then c = d end
    return c.r or d.r, c.g or d.g, c.b or d.b
end

function ns.GetDotDamageColor()
    return ColorSetting("dotDamageColor")
end

function ns.GetDotDamageOutlineColor()
    return ColorSetting("dotDamageOutlineColor")
end

local function DotColor(entry, mode)
    if mode == "school" then
        return SCHOOL_COLORS[entry.school] or { 1, 1, 1 }
    end
    local index = paletteIndexByName[entry.name]
    if not index then
        index = (nextPaletteIndex - 1) % #DOT_PALETTE + 1
        paletteIndexByName[entry.name], nextPaletteIndex = index, nextPaletteIndex + 1
    end
    return DOT_PALETTE[index]
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local widgetsByPlate = setmetatable({}, { __mode = "k" })

local function CoverSpan(texture, span)
    texture:SetPoint("TOPLEFT", span, "TOPLEFT")
    texture:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
end

local function InvisibleBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    return bar
end

local function CreateWidgets(plate, healthBar)
    local w = { healthBar = healthBar }

    w.marker = InvisibleBar(plate)
    w.marker:SetAllPoints(healthBar)
    w.span = w.marker:GetStatusBarTexture()
    w.fill = w.marker:CreateTexture(nil, "ARTWORK")
    CoverSpan(w.fill, w.span)

    w.segments = {}
    for i = 1, MAX_SEGMENTS do
        local bar = InvisibleBar(w.marker)
        bar:SetAllPoints(w.marker)
        local fillEnd = bar:GetStatusBarTexture()
        local texture = w.marker:CreateTexture(nil, "ARTWORK", nil, 1)
        if i == 1 then
            texture:SetPoint("TOPLEFT", w.marker, "TOPLEFT")
        else
            texture:SetPoint("TOPLEFT", w.segments[i - 1].fillEnd, "TOPRIGHT")
        end
        texture:SetPoint("BOTTOMRIGHT", fillEnd, "BOTTOMRIGHT")
        w.segments[i] = { bar = bar, fillEnd = fillEnd, texture = texture }
    end

    w.edges = {}
    for _, points in ipairs({ { true, "TOPLEFT", "TOPRIGHT" }, { true, "BOTTOMLEFT", "BOTTOMRIGHT" },
        { false, "TOPLEFT", "BOTTOMLEFT" }, { false, "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local edge = w.marker:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(points[2], w.span, points[2])
        edge:SetPoint(points[3], w.span, points[3])
        table.insert(w.edges, { texture = edge, horizontal = points[1] })
    end

    w.iconWindow = CreateFrame("Frame", nil, plate)
    w.iconWindow:SetClipsChildren(true)
    w.iconBar = InvisibleBar(w.iconWindow)
    w.iconBar:SetPoint("RIGHT", w.iconWindow, "RIGHT")
    w.icon = w.iconBar:CreateTexture(nil, "OVERLAY")
    w.icon:SetPoint("RIGHT", w.iconBar:GetStatusBarTexture(), "RIGHT")

    local level = healthBar:GetFrameLevel()
    w.marker:SetFrameLevel(level + 1)
    w.iconWindow:SetFrameLevel(level + 20)
    w.iconBar:SetFrameLevel(level + 21)

    widgetsByPlate[plate] = w
    return w
end

local STYLE_KEYS = {
    "dotDamageFill", "dotDamageFillOpacity", "dotDamageColors", "dotDamageOutline", "dotDamageDashLength",
    "dotDamageOutlineThickness", "dotDamageOutlineOpacity", "dotDamageIcon", "dotDamageIconSize",
    "dotDamageIconPosition", "dotDamageIconOffsetX", "dotDamageIconOffsetY",
}

local function ApplyStyle(w)
    local fr, fg, fb = ns.GetDotDamageColor()
    local or_, og, ob = ns.GetDotDamageOutlineColor()
    local parts = { fr, fg, fb, or_, og, ob }
    for _, key in ipairs(STYLE_KEYS) do parts[#parts + 1] = tostring(Setting(key)) end
    local signature = table.concat(parts, "|")
    if signature == w.signature then return end
    w.signature = signature

    local fill = Find(LISTS.fills, Setting("dotDamageFill"))
    local path, tiled = fill[3], fill[4] or false
    local wrap = tiled and "REPEAT" or nil
    local fillOpacity = (tonumber(Setting("dotDamageFillOpacity")) or 45) / 100
    w.fill:SetShown(path ~= nil and Setting("dotDamageColors") == "single")
    if path then
        w.fill:SetTexture(path, wrap, wrap)
        w.fill:SetHorizTile(tiled)
        w.fill:SetVertTile(tiled)
        w.fill:SetVertexColor(fr, fg, fb, fillOpacity)
    end
    for _, segment in ipairs(w.segments) do
        segment.texture:SetTexture(path or WHITE, wrap, wrap)
        segment.texture:SetHorizTile(tiled)
        segment.texture:SetVertTile(tiled)
    end

    local outline = Setting("dotDamageOutline")
    local thickness = tonumber(Setting("dotDamageOutlineThickness")) or 1
    local outlineOpacity = (tonumber(Setting("dotDamageOutlineOpacity")) or 100) / 100
    for _, edge in ipairs(w.edges) do
        if outline == "dashed" then
            local file = (edge.horizontal and "DashH" or "DashV") .. tostring(Setting("dotDamageDashLength"))
            edge.texture:SetTexture(TEXTURE_DIR .. file, "REPEAT", "REPEAT")
            edge.texture:SetHorizTile(edge.horizontal)
            edge.texture:SetVertTile(not edge.horizontal)
        else
            edge.texture:SetTexture(WHITE)
            edge.texture:SetHorizTile(false)
            edge.texture:SetVertTile(false)
        end
        if edge.horizontal then
            edge.texture:SetHeight(thickness)
        else
            edge.texture:SetWidth(thickness)
        end
        edge.texture:SetVertexColor(or_, og, ob, outlineOpacity)
        edge.texture:SetShown(outline ~= "none")
    end

    local size = tonumber(Setting("dotDamageIconSize")) or 18
    w.iconWindow:SetSize(size, size)
    w.iconBar:SetSize(ICON_BAR_LENGTH, size)
    w.icon:SetSize(size, size)
    w.icon:SetTexture(Find(LISTS.icons, Setting("dotDamageIcon"))[3])
    w.iconWindow:ClearAllPoints()
    local x, y = tonumber(Setting("dotDamageIconOffsetX")) or 0, tonumber(Setting("dotDamageIconOffsetY")) or 0
    local position = Setting("dotDamageIconPosition")
    if position == "left" then
        w.iconWindow:SetPoint("RIGHT", w.healthBar, "LEFT", -4 + x, y)
    elseif position == "above" then
        w.iconWindow:SetPoint("BOTTOM", w.healthBar, "TOP", x, 4 + y)
    else
        w.iconWindow:SetPoint("LEFT", w.healthBar, "RIGHT", 4 + x, y)
    end
end

local function HideWidgets(w)
    w.marker:Hide()
    w.iconWindow:Hide()
end

local function DrawPlate(w, entries, total, maxHealth, health)
    ApplyStyle(w)
    local colorMode = Setting("dotDamageColors")
    local perDot = colorMode ~= "single"
    local count = perDot and math.min(#entries, MAX_SEGMENTS) or 0
    local opacity = (tonumber(Setting("dotDamageFillOpacity")) or 45) / 100
    local ok = pcall(function()
        w.marker:SetMinMaxValues(0, maxHealth)
        w.marker:SetValue(total)
        local running = 0
        for i, segment in ipairs(w.segments) do
            local entry = entries[i]
            if i <= count then
                running = running + entry.damage
                if i == count then running = total end
                local color = DotColor(entry, colorMode)
                segment.texture:SetVertexColor(color[1], color[2], color[3], opacity)
            end
            segment.bar:SetMinMaxValues(0, maxHealth)
            segment.bar:SetValue(i <= count and running or total)
            segment.texture:SetShown(i <= count)
        end
        w.iconBar:SetMinMaxValues(0, health)
        w.iconBar:SetValue(total)
    end)
    if not ok then
        HideWidgets(w)
        return
    end
    w.marker:Show()
    w.iconWindow:SetShown(Setting("dotDamageKillIcon") == true)
end

local function WidgetsFor(plate)
    local w = widgetsByPlate[plate]
    if not w or w.healthBar ~= plate.health then w = CreateWidgets(plate, plate.health) end
    return w
end

local function RefreshPlate(plate)
    local unit = plate.unit
    if not unit or not plate.health or not ns.DotBreakdownForUnit then return end
    local entries, total = ns.DotBreakdownForUnit(unit)
    if total <= 0 then
        local w = widgetsByPlate[plate]
        if w then HideWidgets(w) end
        return
    end
    DrawPlate(WidgetsFor(plate), entries, total, UnitHealthMax(unit), UnitHealth(unit))
end

local seenPlates = {}
local function RefreshAll()
    wipe(seenPlates)
    if IsEnabled() then
        for _, plate in pairs(ns.plates or {}) do
            seenPlates[plate] = true
            RefreshPlate(plate)
        end
    end
    for plate, w in pairs(widgetsByPlate) do
        if not seenPlates[plate] then HideWidgets(w) end
    end
end
ns.RefreshDotDamage = function()
    for _, w in pairs(widgetsByPlate) do w.signature = nil end
    RefreshAll()
end

local driver = CreateFrame("Frame")
local sinceUpdate = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    if not IsEnabled() and next(widgetsByPlate) == nil then return end
    RefreshAll()
end)

-- /kuidot: what the tracker counts on the target and its recent events (casts it read or skipped, ticks).
SLASH_KUIDOT1 = "/kuidot"
SlashCmdList.KUIDOT = function()
    local function Show(value) return Readable(value) and tostring(value) or "secret" end
    local pending, count = 0, 0
    if ns.DotDamageForUnit then pending, count = ns.DotDamageForUnit("target") end
    print(SLASH_KUIDOT1, GetLocale and GetLocale() or "", Show(UnitHealth("target")), Show(UnitHealthMax("target")),
        pending, count)
    local log = ns.DotTrackerLog and ns.DotTrackerLog() or {}
    for i = math.max(1, #log - 11), #log do print(" ", log[i]) end
end
