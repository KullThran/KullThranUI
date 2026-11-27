-- Nameplates options, Colors page: enemy, focus, threat, cast and quest colours,
-- and the small focus preview bar beside them. One text for both clients.
-- Nothing runs at load; Setup resolves references, Build makes the widgets.

local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)

local Colors = {}
ns.OptionsColors = Colors

-- P and defaults come from Setup, PP from each Build
local P, PP, defaults

-- Array read by the Slots file, replaced by each Build
local currentPreviews

local MEDIA = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\"
local FALLBACK_COG = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png"

---------------------------------------------------------------------------
-- Saved value readers and writers
---------------------------------------------------------------------------
local function LT(text) return P.LText(text) end
local function SavedOr(k) return P.DBVal(k) or defaults[k] end

local function Store(k, v)
    local db = P.DB()
    if db then db[k] = v end
end

local function StoreRGB(k, r, g, b) Store(k, { r = r, g = g, b = b }) end

-- Stored value when not nil, otherwise the default
local function StoredOrDefault(k)
    local db = P.DB()
    if db and db[k] ~= nil then return db[k] end
    return defaults[k]
end

local function FocusOff() return not StoredOrDefault("focusColorEnabled") end
local function TextureNone() return SavedOr("focusOverlayTexture") == "none" end
local function TankOff() return not StoredOrDefault("tankHasAggroEnabled") end

local function QuestOff() return P.DBVal("questMobColorEnabled") ~= true end

---------------------------------------------------------------------------
-- Running-offset widget helpers. b is the state of one Build.
---------------------------------------------------------------------------
local function Header(b, text)
    local _, height = b.W:SectionHeader(b.parent, text, b.y)
    b.y = b.y - height
end

local function Row(b, left, right)
    local row, height = b.W:DualRow(b.parent, b.y, left, right)
    b.y = b.y - height
    return row
end

local function Spacer(b, size)
    local _, height = b.W:Spacer(b.parent, b.y, size)
    b.y = b.y - height
end

-- Row side of colour swatches; entries are { tooltip, saved key }
local function SwatchRow(text, entries)
    local swatches = {}
    for i, entry in ipairs(entries) do
        local key = entry[2]
        swatches[i] = {
            tooltip = LT(entry[1]),
            getValue = function() return P.DBColor(key) end,
            setValue = function(r, g, b)
                StoreRGB(key, r, g, b)
                P.RefreshAllPlates()
            end,
        }
    end
    return { type = "multiSwatch", text = LT(text), swatches = swatches }
end

---------------------------------------------------------------------------
-- Focus preview bar
---------------------------------------------------------------------------
local TEXT_SLOTS = {
    { key = "textSlotRight", anchor = "RIGHT", inset = -2 },
    { key = "textSlotLeft", anchor = "LEFT", inset = 2 },
    { key = "textSlotCenter", anchor = "CENTER", inset = 0 },
}

local function FontPath()
    local value = KT.GetNPFontPath and KT.GetNPFontPath("nameplates")
    return value or P.DBVal("font")
end

-- Which string and text a slot value shows; nil for anything without a sample
local function SlotSample(value, bar)
    local p, n = bar.percent, P.FormatThousands(bar.number)
    if value == "healthPercent" then
        return bar.percentFS, p .. "%"
    elseif value == "healthPercentNoSign" then
        return bar.percentFS, tostring(p)
    elseif value == "healthNumber" then
        return bar.numberFS, n
    elseif value == "healthPctNum" then
        return bar.percentFS, p .. "% | " .. n
    elseif value == "healthNumPct" then
        return bar.percentFS, n .. " | " .. p .. "%"
    end
end

local function SlotValue(key) return P.DBVal(key) or defaults[key] end

-- Size of the first slot holding real text, at most 13
local function TextSize()
    for _, slot in ipairs(TEXT_SLOTS) do
        local value = SlotValue(slot.key)
        if value and value ~= "none" and value ~= "enemyName" then
            local sizeKey = slot.key .. "Size"
            return math.min(P.DBVal(sizeKey) or defaults[sizeKey] or 10, 13)
        end
    end
    return 10
end

-- Both font strings have their font from creation, so SetText below is always safe
local function TextPass(bar)
    local size, path, outline = TextSize(), FontPath(), P.OptOutline()
    for _, fs in ipairs({ bar.percentFS, bar.numberFS }) do
        P.PreviewFont(fs, path, size, outline)
        fs:ClearAllPoints()
        fs:Hide()
    end
    for _, slot in ipairs(TEXT_SLOTS) do
        local fs, text = SlotSample(SlotValue(slot.key), bar)
        if fs then
            local c = P.DBRaw(slot.key .. "Color")
            fs:SetTextColor(c.r, c.g, c.b, 1)
            fs:SetText(text)
            fs:SetPoint(slot.anchor, bar.statusBar, slot.anchor, slot.inset, 0)
            fs:Show()
        end
    end
end

local function PaintHairlines(bar)
    local c = P.DBRaw("borderColor")
    local shown = SavedOr("borderStyle") ~= "none"
    for _, line in ipairs(bar.hairlines) do
        line:SetColorTexture(c.r, c.g, c.b, 1)
        line:SetShown(shown)
    end
end

local function BuildHairlines(layer)
    local function Line()
        return layer:CreateTexture(nil, "OVERLAY", nil, 7)
    end
    local top, bottom, left, right = Line(), Line(), Line(), Line()
    top:SetHeight(1)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    bottom:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    left:SetWidth(1)
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT", 0, 0)
    right:SetWidth(1)
    right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
    return { top, bottom, left, right }
end

local function SetColorOverride(bar, fn) bar.override = fn end

local function SetDim(bar, dim)
    bar.dim = dim
    bar.statusBar:SetAlpha(dim and 0.3 or 1)
end

local function UpdateBarColor(bar)
    local r, g, b
    if bar.override then r, g, b = bar.override() end
    if not r then
        local c = P.DBRaw("focus")
        r, g, b = c.r, c.g, c.b
    end
    bar.statusBar:SetStatusBarColor(r, g, b, 1)
end

local function NewClip(statusBar, sublevel)
    local clip = CreateFrame("Frame", nil, statusBar)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(statusBar:GetFrameLevel() + 1)
    local art = clip:CreateTexture(nil, "ARTWORK", nil, sublevel)
    art:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 1, -1)
    art:SetSize(161, 20)
    return clip, art
end

local function UpdateOverlay(bar)
    local name = SavedOr("focusOverlayTexture")
    if name == "none" then
        if bar.fillClip then
            bar.fillClip:Hide()
            bar.restClip:Hide()
        end
        return
    end
    local statusBar = bar.statusBar
    local fill = statusBar:GetStatusBarTexture()
    local alpha = SavedOr("focusOverlayAlpha")
    local tint = P.DBRaw("focusOverlayColor")

    if not bar.fillClip then
        bar.fillClip, bar.fillArt = NewClip(statusBar, 2)
        bar.fillClip:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, -1)
        bar.fillClip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 1)
        bar.restClip, bar.restArt = NewClip(statusBar, 1)
        bar.restClip:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, -1)
        bar.restClip:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", 0, 1)
    end

    local path = MEDIA .. name .. ".png"
    bar.fillArt:SetTexture(path)
    bar.fillArt:SetAlpha(alpha)
    bar.fillArt:SetVertexColor(tint.r, tint.g, tint.b)
    bar.restArt:SetTexture(path)
    bar.restArt:SetAlpha(alpha * 0.3)
    bar.restArt:SetVertexColor(tint.r, tint.g, tint.b)
    bar.fillClip:Show()
    bar.restClip:Show()
end

local function ReanchorBar(bar, rightRegion)
    bar.container:ClearAllPoints()
    PP.Point(bar.container, "RIGHT", rightRegion, "RIGHT", -20, 0)
end

local function BuildFocusBar(row)
    local rightRegion = row._rightRegion
    local bar = {}

    local container = CreateFrame("Frame", nil, row)
    container:SetFrameLevel(row:GetFrameLevel() + 2)
    PP.Size(container, 163, 22)
    PP.Point(container, "RIGHT", rightRegion, "RIGHT", -71, 0)
    bar.container = container

    -- The roll happens once, here, for the bar's whole life
    bar.percent = math.floor(60 + math.random() * 15)
    bar.number = math.floor(10000 * bar.percent / 100)

    local statusBar = CreateFrame("StatusBar", nil, container)
    statusBar:SetAllPoints()
    statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    statusBar:SetMinMaxValues(0, 100)
    statusBar:SetValue(bar.percent)
    bar.statusBar = statusBar
    local level = statusBar:GetFrameLevel()

    local backdrop = statusBar:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(0.20, 0.20, 0.20, 1.0)

    local borderLayer = CreateFrame("Frame", nil, container)
    borderLayer:SetFrameLevel(level + 2)
    borderLayer:SetAllPoints()
    bar.hairlines = BuildHairlines(borderLayer)
    PaintHairlines(bar)

    local textLayer = CreateFrame("Frame", nil, statusBar)
    textLayer:SetFrameLevel(level + 3)
    textLayer:SetAllPoints()
    -- Each font string gets its font here, before any SetText can reach it
    local path, outline = FontPath(), P.OptOutline()
    bar.percentFS = textLayer:CreateFontString(nil, "OVERLAY")
    P.PreviewFont(bar.percentFS, path, 10, outline)
    bar.numberFS = textLayer:CreateFontString(nil, "OVERLAY")
    P.PreviewFont(bar.numberFS, path, 10, outline)

    TextPass(bar)
    UpdateOverlay(bar)

    C_Timer.After(0, function() ReanchorBar(bar, rightRegion) end)
    row:HookScript("OnShow", function() statusBar:SetAlpha(bar.dim and 0.3 or 1) end)
    row:HookScript("OnShow", function() ReanchorBar(bar, rightRegion) end)
    return bar
end

-- Off shows the enemy colour, dimmed; on shows the focus colour
local function FocusSync(bar, enabled)
    if enabled then
        SetColorOverride(bar, nil)
    else
        SetColorOverride(bar, function() return P.DBColor("enemyInCombat") end)
    end
    SetDim(bar, not enabled)
    UpdateBarColor(bar)
end

---------------------------------------------------------------------------
-- Focus controls
---------------------------------------------------------------------------
local function ReserveRight(region, amount)
    local control = region._control
    if control and control.SetReservedRightSpace then control:SetReservedRightSpace(amount) end
end

local function BuildFocusSwatch(b, region)
    local _, writer = P.ColorAccess("focus", function()
        P.RefreshAllPlates()
        UpdateBarColor(b.bar)
    end)
    P.DimmableSwatch(region, function() return P.DBColor("focus") end, writer, FocusOff, function(swatch)
        PP.Point(swatch, "RIGHT", region, "RIGHT", -10, 0)
        ReserveRight(region, 34)
    end)
end

local function BuildOverlaySwatch(b, region)
    local reader, writer = P.ColorAccess("focusOverlayColor", function()
        P.RefreshAllPlates()
        UpdateOverlay(b.bar)
    end)
    P.DimmableSwatch(region, reader, writer, TextureNone, function(swatch)
        PP.Point(swatch, "RIGHT", region, "RIGHT", -45, 0)
        region._lastInline = swatch
    end)
end

local function BuildTextureCog(b, region)
    local _, show = P.QuietCogPopup({
        title = "Focus Texture Settings",
        rows = {
            {
                type = "slider", label = "Opacity", min = 0, max = 1.0, step = 0.05,
                get = function() return SavedOr("focusOverlayAlpha") end,
                set = function(v)
                    Store("focusOverlayAlpha", v)
                    P.RefreshAllPlates()
                    UpdateOverlay(b.bar)
                end,
            },
        },
    })

    local button = CreateFrame("Button", nil, region)
    button:SetSize(26, 26)
    PP.Point(button, "RIGHT", region, "RIGHT", -10, 0)
    button:SetFrameLevel(region:GetFrameLevel() + 6)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture(KT.RESIZE_ICON or FALLBACK_COG)
    P.ApplyAccentToIcon(icon)
    icon:SetAlpha(0.4)
    ReserveRight(region, 76)

    button:SetScript("OnEnter", function() icon:SetAlpha(0.7) end)
    button:SetScript("OnLeave", function() icon:SetAlpha(0.4) end)
    button:SetScript("OnClick", function(self) show(self) end)

    local function DimCog()
        local none = TextureNone()
        button:SetAlpha(none and 0.15 or 1)
        button:EnableMouse(not none)
    end
    DimCog()
    P.RegisterWidgetRefresh(DimCog)
end

local function BuildFocusSection(b)
    Header(b, "FOCUS")
    local toggleRow = Row(b, {
        type = "toggle", text = LT("Focus Color"),
        getValue = function() return StoredOrDefault("focusColorEnabled") end,
        setValue = function(v)
            Store("focusColorEnabled", v)
            P.RefreshAllPlates()
            FocusSync(b.bar, v)
            KT:RefreshPage()
        end,
    }, { type = "label", text = "" })
    BuildFocusSwatch(b, toggleRow._leftRegion)

    local textureRow = Row(b, {
        type = "dropdown", text = LT("Focus Texture"),
        values = { ["striped-v2"] = "Stripes", ["striped-wide-v2"] = "Wide Stripes", none = "None" },
        order = { "striped-v2", "striped-wide-v2", "none" },
        getValue = function() return SavedOr("focusOverlayTexture") end,
        setValue = function(v)
            Store("focusOverlayTexture", v)
            P.RefreshAllPlates()
            UpdateOverlay(b.bar)
            KT:RefreshPage()
        end,
    }, { type = "label", text = LT("Focus Preview") })
    BuildOverlaySwatch(b, textureRow._leftRegion)
    BuildTextureCog(b, textureRow._leftRegion)

    b.bar = BuildFocusBar(textureRow)
    FocusSync(b.bar, not FocusOff())
end

---------------------------------------------------------------------------
-- Threat, cast and quest
---------------------------------------------------------------------------
local TANK_TIP = "Shows a special color for non caster/mini-boss enemies when you have aggro on them."

local function TankToggle(text)
    return {
        type = "toggle", text = LT(text), tooltip = LT(TANK_TIP),
        getValue = function() return StoredOrDefault("tankHasAggroEnabled") end,
        setValue = function(v)
            Store("tankHasAggroEnabled", v)
            P.RefreshAllPlates()
            KT:RefreshPage()
        end,
    }
end

-- Swatch left of a row's control. Returns the swatch and its repaint.
local function SwatchBesideControl(region, get, set)
    local swatch, repaint = P.BuildColorSwatch(region, region:GetFrameLevel() + 5, get, set, nil, 20)
    PP.Point(swatch, "RIGHT", region._control, "LEFT", -12, 0)
    return swatch, repaint
end

local function TankSwatch(region)
    return SwatchBesideControl(region, function() return P.DBColor("tankHasAggro") end, function(r, g, b)
        StoreRGB("tankHasAggro", r, g, b)
        P.RefreshAllPlates()
    end)
end

local function BuildBaseColors(b)
    Header(b, "BASE COLORS")
    local row = Row(b, SwatchRow("Enemies", { { "Enemies", "enemyInCombat" } }), TankToggle("Enable Tank 'Has Aggro' Color"))
    local swatch, repaint = TankSwatch(row._rightRegion)
    P.DimSwatch(swatch, TankOff())
    P.RegisterWidgetRefresh(function()
        P.DimSwatch(swatch, TankOff())
        repaint()
    end)
end

local function BuildQuestRow(b)
    local row = Row(b, {
        type = "toggle", text = LT("Enable Quest Mob Color"),
        tooltip = LT("Colors enemy nameplates for quest mobs you still need to kill."),
        getValue = function() return P.DBVal("questMobColorEnabled") == true end,
        setValue = function(v)
            Store("questMobColorEnabled", v)
            P.CallOnAllPlates("UpdateHealthColor")
            KT:RefreshPage()
        end,
    }, nil)

    local region = row._leftRegion
    local swatch, repaint = SwatchBesideControl(region, function()
        -- No guard: with no saved table this raises, and the swatch's protected paint swallows it
        local c = P.DB().questMobColor or defaults.questMobColor
        return c.r, c.g, c.b
    end, function(r, g, b)
        StoreRGB("questMobColor", r, g, b)
        for _, plate in pairs(ns.plates) do plate:UpdateHealthColor() end
    end)
    region._lastInline = swatch
    P.DimSwatch(swatch, QuestOff())
    P.RegisterWidgetRefresh(function()
        P.DimSwatch(swatch, QuestOff())
        repaint()
    end)
    swatch:SetScript("OnEnter", function(self)
        if QuestOff() then P.ShowTooltip(self, P.DisabledTooltip("Enable Quest Mob Color")) end
    end)
    swatch:SetScript("OnLeave", function() P.HideTooltip() end)
end

local function BuildLevelRow(b)
    Row(b, {
        type = "toggle", text = LT("Color Enemies by Level"),
        tooltip = LT("Colors enemy nameplates by their level compared to yours, like the level on the unit frames: grey is far below you, then green, yellow, orange and red. Enemy players keep their class color, and threat, focus and quest mob colors take priority."),
        getValue = function() return P.DBVal("levelDifficultyColorEnabled") == true end,
        setValue = function(v)
            Store("levelDifficultyColorEnabled", v)
            P.CallOnAllPlates("UpdateHealthColor")
        end,
    }, nil)
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
function Colors.Setup(client)
    if client ~= "retail" and client ~= "forever" then
        error("OptionsColors.Setup: client must be \"retail\" or \"forever\"", 2)
    end
    P = ns.OptionsPreview
    defaults = ns.defaults or _G.KullThranUINameplatesDefaults or {}
end

function Colors.Build(ctx)
    PP = KT.PP
    currentPreviews = {}
    ctx.parent._showRowDivider = true

    local b = { parent = ctx.parent, y = ctx.y, W = ctx.W }

    local want = ctx.sections
    if want.base then
        BuildBaseColors(b)
        BuildQuestRow(b)
        BuildLevelRow(b)
        Spacer(b, 14)
    end
    if want.focus then
        BuildFocusSection(b)
        local bar = b.bar
        -- The Border Style and Border Color controls call these
        currentPreviews[1] = {
            RefreshBorderStyle = function() PaintHairlines(bar) end,
            RefreshBorderColor = function() PaintHairlines(bar) end,
        }
        P.RegisterWidgetRefresh(function() UpdateBarColor(bar) end)
        P.RegisterWidgetRefresh(function() UpdateOverlay(bar) end)
        P.colorPreviewRefresh = function()
            UpdateBarColor(bar)
            UpdateOverlay(bar)
            PaintHairlines(bar)
            TextPass(bar)
        end
    end

    return { y = b.y }
end

function Colors.ColorPreviews()
    return currentPreviews
end
