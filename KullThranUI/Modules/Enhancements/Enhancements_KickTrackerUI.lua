-------------------------------------------------------------------------------
--  Kick Tracker display (engine: Enhancements_KickTracker.lua).
--
--    nameplate icons  one per kicker beside the enemy's nameplate: the spell
--                     icon in a class-coloured frame, a cooldown sweep and the
--                     seconds left; ready kickers sit nearest the plate. Drawn
--                     above the nameplates so an overlapping plate never hides them.
--    bars             one row per member with an interrupt: name, seconds left
--                     (or Ready) and the raid marker of the enemy last kicked.
--                     Font, texture, sizes and background come from the
--                     options. Moved in KUI Unlock Mode (sample rows show
--                     there) or dragged straight away unless locked.
--    test mode        fake kicks on your target's nameplate and in the bars.
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not (Mod and Mod.KickTracker) then return end

local KTK = Mod.KickTracker
local Engine = KTK.Engine
local Config = KTK.Config
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GetTime = _G.GetTime
local issecretvalue = _G.issecretvalue or function() return false end
local ipairs, pairs, math = ipairs, pairs, math

local MARKER_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local TICK = 0.1

local function LText(text)
    if type(text) == "string" and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then return L[text] end
    end
    return text
end

-- A media choice from the options: a file path, or a SharedMedia name.
local function Media(kind, value)
    if type(value) ~= "string" or value == "" then return nil end
    if value:find("\\", 1, true) or value:find("/", 1, true) then return value end
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    return LSM and LSM:Fetch(kind, value, true) or nil
end

local function Font()
    return Media("font", Config().font)
        or (KT.ResolveFontPath and KT:ResolveFontPath()) or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function BarTexture()
    return Media("statusbar", Config().barTexture) or "Interface\\Buttons\\WHITE8X8"
end

local function IsUnlockModeOpen()
    local unlock = KT.GetModule and KT:GetModule("UnlockMode", true)
    return unlock and unlock.isOpen == true
end

local function ClassColor(class)
    local c = class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.7, 0.7, 0.7
end

local function SpellIcon(spellID)
    local api = _G.C_Spell
    local icon = api and api.GetSpellTexture and api.GetSpellTexture(spellID)
    if icon and not issecretvalue(icon) then return icon end
    return 134400
end

local function Seconds(remaining)
    if remaining >= 10 then return string.format("%d", math.ceil(remaining)) end
    return string.format("%.1f", remaining)
end

-------------------------------------------------------------------------------
--  Nameplate icons
-------------------------------------------------------------------------------
local iconPool, iconsUsed = {}, 0

local function Edge(frame, point1, point2, horizontal)
    local t = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    t:SetPoint(point1)
    t:SetPoint(point2)
    t.horizontal = horizontal
    return t
end

-- One kick icon: spell icon, class-coloured frame, cooldown sweep and seconds.
local function NewIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:EnableMouse(false)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.85)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1.5, -1.5)
    f.icon:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.icon)
    f.cooldown:SetDrawEdge(false)
    if f.cooldown.SetHideCountdownNumbers then f.cooldown:SetHideCountdownNumbers(true) end
    f.edges = { Edge(f, "TOPLEFT", "TOPRIGHT", true), Edge(f, "BOTTOMLEFT", "BOTTOMRIGHT", true),
        Edge(f, "TOPLEFT", "BOTTOMLEFT", false), Edge(f, "TOPRIGHT", "BOTTOMRIGHT", false) }
    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints()
    over:SetFrameLevel(f.cooldown:GetFrameLevel() + 2)
    f.text = over:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetShadowOffset(1, -1)
    return f
end

local function AcquireIcon()
    iconsUsed = iconsUsed + 1
    local f = iconPool[iconsUsed]
    if not f then
        f = NewIcon(UIParent)
        f:SetFrameStrata("HIGH")
        iconPool[iconsUsed] = f
    end
    f:Show()
    return f
end

local function ReleaseIcons()
    for i = 1, #iconPool do
        iconPool[i]:Hide()
        iconPool[i]:ClearAllPoints()
    end
    iconsUsed = 0
end

local function PlateUnit(plate)
    local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if type(unit) == "string" and not issecretvalue(unit) then return unit end
    return nil
end

local function PaintIcon(f, member, now, size)
    local cfg = Config()
    f:SetSize(size, size)
    f.icon:SetTexture(SpellIcon(member.spellID))
    local border = math.max(0, tonumber(cfg.iconBorder) or 1.5)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", border, -border)
    f.icon:SetPoint("BOTTOMRIGHT", -border, border)
    local r, g, b = ClassColor(member.class)
    for _, edge in ipairs(f.edges) do
        if edge.horizontal then edge:SetHeight(math.max(0.01, border)) else edge:SetWidth(math.max(0.01, border)) end
        edge:SetColorTexture(r, g, b, 1)
        edge:SetShown(border > 0)
    end
    local remaining, duration
    if member.sample then
        remaining, duration = member.sample, member.cd
    else
        remaining, duration = Engine:Remaining(member, now)
    end
    local textSize = tonumber(cfg.iconTextSize) or 0
    if textSize <= 0 then textSize = math.max(9, math.floor(size * 0.45)) end
    f.text:SetFont(Font(), textSize, "OUTLINE")
    if remaining > 0 then
        f.icon:SetDesaturated(false)
        f.text:SetText(Seconds(remaining))
        local start = now + remaining - (duration or remaining)
        if f.cooldownStart ~= start then
            f.cooldownStart = start
            f.cooldown:SetCooldown(start, duration or remaining)
        end
    else
        f.cooldownStart = nil
        f.cooldown:Clear()
        f.text:SetText("")
    end
end

local function LayoutPlates(now)
    ReleaseIcons()
    local cfg = Config()
    if not (cfg.showIcons and (Engine.active or Engine.test)) then return end
    local api = _G.C_NamePlate
    if not (api and api.GetNamePlates) then return end
    local size = math.max(12, tonumber(cfg.iconSize) or 26)
    local right = cfg.iconSide ~= "LEFT"
    for _, plate in ipairs(api.GetNamePlates() or {}) do
        local unit = PlateUnit(plate)
        if unit then
            local anchor = plate.UnitFrame or plate
            local previous
            for _, member in ipairs(Engine:PlateIcons(unit, now)) do
                local f = AcquireIcon()
                PaintIcon(f, member, now, size)
                f:ClearAllPoints()
                if previous then
                    f:SetPoint(right and "LEFT" or "RIGHT", previous, right and "RIGHT" or "LEFT", right and 2 or -2, 0)
                elseif right then
                    f:SetPoint("LEFT", anchor, "RIGHT", tonumber(cfg.iconX) or 4, tonumber(cfg.iconY) or 0)
                else
                    f:SetPoint("RIGHT", anchor, "LEFT", -(tonumber(cfg.iconX) or 4), tonumber(cfg.iconY) or 0)
                end
                previous = f
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Bars
-------------------------------------------------------------------------------
local bars

local function BuildBars()
    if bars then return bars end
    bars = CreateFrame("Frame", "KUI_KickTrackerBars", UIParent, "BackdropTemplate")
    bars:SetFrameStrata("MEDIUM")
    bars:SetClampedToScreen(true)
    if KT.AddBackdrop then KT:AddBackdrop(bars, 0.03, 0.03, 0.04, 0.82) end
    if KT.AddBorder then KT:AddBorder(bars, 0, 0, 0, 1) end
    bars:SetMovable(true)
    bars:RegisterForDrag("LeftButton")
    -- Drag straight away (no Unlock Mode needed) unless the bars are locked.
    bars:SetScript("OnDragStart", function(self)
        if not Config().lockBars then self:StartMoving() end
    end)
    bars:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        Config().barsPosition = { point = point or "LEFT", relativePoint = relativePoint or point or "LEFT", x = x or 40, y = y or 120 }
    end)
    bars.title = bars:CreateFontString(nil, "OVERLAY")
    bars.title:SetPoint("TOPLEFT", 6, -5)
    bars.rows = {}
    bars:Hide()
    return bars
end

local function BarRow(frame, index)
    local row = frame.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, frame)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    row.bar:SetMinMaxValues(0, 1)
    row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.06)
    row.name = row.bar:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("LEFT", 5, 0)
    row.name:SetJustifyH("LEFT")
    row.time = row.bar:CreateFontString(nil, "OVERLAY")
    row.time:SetPoint("RIGHT", -5, 0)
    row.marker = row.bar:CreateTexture(nil, "OVERLAY")
    row.marker:SetPoint("RIGHT", row.time, "LEFT", -5, 0)
    frame.rows[index] = row
    return row
end

-- Sample rows while Unlock Mode is open and nobody is tracked yet.
local SAMPLE_ROWS = {
    { name = "Ulkrad", class = "ROGUE", spellID = 1766, cd = 15, sample = 0 },
    { name = "Kullthran", class = "MAGE", spellID = 2139, cd = 24, sample = 14, lastMarker = 7 },
    { name = "Shammy", class = "SHAMAN", spellID = 57994, cd = 12, sample = 6, lastMarker = 2 },
}

local function LayoutBars(now)
    local cfg = Config()
    local members = Engine:Members()
    local unlocking = cfg.enable and IsUnlockModeOpen()
    if #members == 0 and unlocking then members = SAMPLE_ROWS end
    local show = cfg.showBars and (Engine.active or Engine.test or unlocking) and #members > 0
    if not show then
        if bars then bars:Hide() end
        return
    end
    BuildBars()
    bars:SetScale(math.max(0.5, tonumber(cfg.barScale) or 1))
    bars:EnableMouse(not cfg.lockBars)
    KTK.PaintBars(bars, members, now)
    if not bars._ktPlaced then KTK.ApplyBarsPosition() end
    bars:Show()
end

-- Paints a bars frame (the live one or the options preview): background,
-- title and one row per member, all from the options.
function KTK.PaintBars(frame, members, now)
    local cfg = Config()
    local width = math.max(120, tonumber(cfg.barWidth) or 190)
    local height = math.max(10, tonumber(cfg.barHeight) or 18)
    local spacing = math.max(0, tonumber(cfg.barSpacing) or 3)
    local font = Font()
    local texture = BarTexture()
    local background = cfg.showBackground ~= false
    if frame.bgKT then frame.bgKT:SetShown(background) end
    if frame.SetBackdropColor then frame:SetBackdropColor(0.03, 0.03, 0.04, background and (tonumber(cfg.backgroundAlpha) or 0.82) or 0) end
    if KT.AddBorder then KT:AddBorder(frame, 0, 0, 0, background and 1 or 0) end
    local top = 4
    if cfg.showTitle ~= false then
        frame.title:SetFont(font, math.max(8, tonumber(cfg.titleSize) or 10), "OUTLINE")
        frame.title:SetText(LText("Kicks"))
        if KT.SetAccentTextColor then KT:SetAccentTextColor(frame.title, 1) end
        frame.title:Show()
        top = 8 + math.max(8, tonumber(cfg.titleSize) or 10)
    else
        frame.title:Hide()
    end
    for index, member in ipairs(members) do
        local row = BarRow(frame, index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -top)
        row:SetSize(width - 8, height)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon:SetSize(height, height)
        row.icon:SetTexture(SpellIcon(member.spellID))
        row.icon:SetShown(cfg.showBarIcon ~= false)
        row.bar:ClearAllPoints()
        if cfg.showBarIcon ~= false then
            row.bar:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 2, 0)
        else
            row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        end
        row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.bar:SetStatusBarTexture(texture)
        local r, g, b = ClassColor(member.class)
        if cfg.classColors == false then r, g, b = 0.55, 0.55, 0.6 end
        local remaining, duration
        if member.sample then
            remaining, duration = member.sample, member.cd
        else
            remaining, duration = Engine:Remaining(member, now)
        end
        row.bar:SetStatusBarColor(r * 0.6, g * 0.6, b * 0.6, 1)
        row.bar:SetValue(remaining > 0 and (1 - remaining / math.max(0.1, duration or remaining)) or 1)
        row.name:SetFont(font, math.max(7, tonumber(cfg.nameSize) or 10), "OUTLINE")
        row.name:SetText(member.name or "?")
        row.name:SetTextColor(1, 1, 1, 1)
        row.time:SetFont(font, math.max(7, tonumber(cfg.timeSize) or 10), "OUTLINE")
        if remaining > 0 then
            row.time:SetText(Seconds(remaining))
            row.time:SetTextColor(1, 1, 1, 1)
        else
            row.time:SetText(LText("Ready"))
            row.time:SetTextColor(0.45, 1, 0.45, 1)
        end
        local marker = member.lastMarker or (member.focusPending and member.focusMarker)
        if marker then
            row.marker:SetTexture(MARKER_TEXTURE .. marker)
            row.marker:SetSize(height - 4, height - 4)
            row.marker:Show()
        else
            row.marker:Hide()
        end
        row:Show()
        top = top + height + spacing
    end
    for index = #members + 1, #frame.rows do frame.rows[index]:Hide() end
    frame:SetSize(width, top + 4 - spacing)
end

function KTK.ApplyBarsPosition()
    local f = BuildBars()
    local p = Config().barsPosition
    f:ClearAllPoints()
    f:SetPoint(p and p.point or "LEFT", UIParent, p and (p.relativePoint or p.point) or "LEFT", p and p.x or 40, p and p.y or 120)
    f._ktPlaced = true
end

-------------------------------------------------------------------------------
--  Refresh: on every engine change, and on a short ticker while anything shows
-------------------------------------------------------------------------------
local ticker

local function Refresh()
    local now = GetTime()
    LayoutPlates(now)
    LayoutBars(now)
    local busy = iconsUsed > 0 or (bars and bars:IsShown())
    if busy and not ticker then
        ticker = _G.C_Timer.NewTicker(TICK, Refresh)
    elseif not busy and ticker then
        ticker:Cancel()
        ticker = nil
    end
end
Engine.onChanged = Refresh
KTK.RefreshDisplay = Refresh

-------------------------------------------------------------------------------
--  Test mode: fake kickers, kicking your target's nameplate on a loop
-------------------------------------------------------------------------------
local TEST_MEMBERS = {
    { name = "Ulkrad", class = "ROGUE" },
    { name = "Kullthran", class = "MAGE" },
    { name = "Shammy", class = "SHAMAN" },
}

local testTicker

local function TargetPlateUnit()
    local api = _G.C_NamePlate
    local plate = api and api.GetNamePlateForUnit and api.GetNamePlateForUnit("target")
    return plate and PlateUnit(plate)
end

local function TestStep()
    local now = GetTime()
    local unit = TargetPlateUnit()
    for _, guid in ipairs(Engine.order) do
        local member = Engine.members[guid]
        if Engine:Remaining(member, now) == 0 and math.random() < 0.35 then
            Engine:RecordKick(guid, unit, now)
        end
    end
    Refresh()
end

function KTK.StartTest()
    Engine.test = true
    Engine.members, Engine.order, Engine.plateKicks = {}, {}, {}
    local _, playerClass = _G.UnitClass("player")
    local roster = { { name = _G.UnitName("player"), class = playerClass } }
    for _, m in ipairs(TEST_MEMBERS) do roster[#roster + 1] = m end
    for index, m in ipairs(roster) do
        local key, spell = KTK.InterruptFor(m.class)
        if spell then
            local guid = "test-" .. index
            Engine.members[guid] = { guid = guid, name = m.name, class = m.class, spellKey = key,
                spellID = spell.id, cd = spell.cd, readyAt = 0, lastMarker = index <= 3 and (9 - index) or nil }
            Engine.order[#Engine.order + 1] = guid
        end
    end
    local unit = TargetPlateUnit()
    for i = 2, math.min(3, #Engine.order) do Engine:RecordKick(Engine.order[i], unit, GetTime() - i * 3) end
    if testTicker then testTicker:Cancel() end
    testTicker = _G.C_Timer.NewTicker(1, TestStep)
    if not unit and KT.Print then KT:Print(LText("Kick Tracker test: target an enemy with a nameplate to see the icons.")) end
    Refresh()
end

function KTK.StopTest()
    if testTicker then testTicker:Cancel(); testTicker = nil end
    Engine.test = false
    Engine.members, Engine.order, Engine.plateKicks = {}, {}, {}
    if KTK.Refresh then KTK.Refresh() end
    Refresh()
end

-------------------------------------------------------------------------------
--  Options live preview: an enemy nameplate with kick icons beside it and the
--  bars, painted by the same code as in game and animated (kicks count down
--  and come back Ready).
-------------------------------------------------------------------------------
local PREVIEW_KICKERS = {
    { name = "Ulkrad", class = "ROGUE", spellID = 1766, cd = 15, phase = 2, lastMarker = 8 },
    { name = "Kullthran", class = "MAGE", spellID = 2139, cd = 24, phase = 17, lastMarker = 7 },
    { name = "Shammy", class = "SHAMAN", spellID = 57994, cd = 12, phase = 8, lastMarker = 2 },
}
local PREVIEW_READY = 4 -- seconds each kick shows Ready before it is used again

local function PreviewMembers(now)
    local list = {}
    for _, m in ipairs(PREVIEW_KICKERS) do
        local cycle = m.cd + PREVIEW_READY
        local left = (m.phase - now) % cycle - PREVIEW_READY
        m.sample = math.max(0, left)
        list[#list + 1] = m
    end
    table.sort(list, function(a, b)
        if (a.sample == 0) ~= (b.sample == 0) then return a.sample == 0 end
        return a.sample < b.sample
    end)
    return list
end

function KTK.CreatePreview(parent, width, height)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetSize(width, height)
    p:SetClipsChildren(true)
    if KT.AddBackdrop then KT:AddBackdrop(p, 0.02, 0.02, 0.025, 0.85) end
    if KT.AddBorder then KT:AddBorder(p, 0, 0, 0, 1) end
    p.label = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.label:SetPoint("TOPLEFT", 8, -6)
    p.label:SetText(LText("LIVE PREVIEW"))
    -- Glass card border (Widgets.lua W:PreviewCard).
    if KT.Widgets and KT.Widgets.PreviewCard then KT.Widgets:PreviewCard(p) end
    if KT.SetAccentTextColor then KT:SetAccentTextColor(p.label, 1) end

    -- A stand-in enemy nameplate: name, health bar, an interrupted cast.
    local plate = CreateFrame("Frame", nil, p)
    plate:SetSize(150, 12)
    plate:SetPoint("LEFT", p, "LEFT", math.floor(width * 0.12), 4)
    plate.bg = plate:CreateTexture(nil, "BACKGROUND")
    plate.bg:SetAllPoints()
    plate.bg:SetColorTexture(0.08, 0.02, 0.02, 1)
    plate.fill = plate:CreateTexture(nil, "ARTWORK")
    plate.fill:SetPoint("TOPLEFT")
    plate.fill:SetPoint("BOTTOMLEFT")
    plate.fill:SetWidth(150 * 0.72)
    plate.fill:SetColorTexture(0.78, 0.16, 0.16, 1)
    if KT.AddBorder then KT:AddBorder(plate, 0, 0, 0, 1) end
    plate.name = plate:CreateFontString(nil, "OVERLAY")
    plate.name:SetPoint("BOTTOM", plate, "TOP", 0, 3)
    plate.cast = CreateFrame("Frame", nil, p)
    plate.cast:SetSize(150, 8)
    plate.cast:SetPoint("TOP", plate, "BOTTOM", 0, -2)
    plate.cast.fill = plate.cast:CreateTexture(nil, "ARTWORK")
    plate.cast.fill:SetAllPoints()
    plate.cast.fill:SetColorTexture(0.85, 0.2, 0.2, 1)
    plate.cast.text = plate.cast:CreateFontString(nil, "OVERLAY")
    plate.cast.text:SetPoint("LEFT", 3, 0)
    p.plate = plate
    p.icons = {}

    p.bars = CreateFrame("Frame", nil, p, "BackdropTemplate")
    if KT.AddBackdrop then KT:AddBackdrop(p.bars, 0.03, 0.03, 0.04, 0.82) end
    p.bars.title = p.bars:CreateFontString(nil, "OVERLAY")
    p.bars.title:SetPoint("TOPLEFT", 6, -5)
    p.bars.rows = {}
    p.bars:SetPoint("TOPRIGHT", p, "TOPRIGHT", -14, -22)

    function p:Refresh()
        local cfg = Config()
        local now = GetTime()
        local members = PreviewMembers(now)
        local font = Font()
        plate.name:SetFont(font, 9, "OUTLINE")
        plate.name:SetText(LText("Enemy Caster"))
        plate.cast.text:SetFont(font, 7, "OUTLINE")
        plate.cast.text:SetText(LText("Interrupted"))
        local size = math.max(12, tonumber(cfg.iconSize) or 26)
        local right = cfg.iconSide ~= "LEFT"
        local previous
        for index, member in ipairs(members) do
            local f = self.icons[index] or NewIcon(self)
            self.icons[index] = f
            f:SetShown(cfg.showIcons ~= false)
            PaintIcon(f, member, now, size)
            f:ClearAllPoints()
            if previous then
                f:SetPoint(right and "LEFT" or "RIGHT", previous, right and "RIGHT" or "LEFT", right and 2 or -2, 0)
            elseif right then
                f:SetPoint("LEFT", plate, "RIGHT", tonumber(cfg.iconX) or 4, tonumber(cfg.iconY) or 0)
            else
                f:SetPoint("RIGHT", plate, "LEFT", -(tonumber(cfg.iconX) or 4), tonumber(cfg.iconY) or 0)
            end
            previous = f
        end
        -- Icons on the left of the plate need room: move the plate over.
        plate:ClearAllPoints()
        if right then
            plate:SetPoint("LEFT", self, "LEFT", 24, 4)
        else
            plate:SetPoint("LEFT", self, "LEFT", 24 + (#members * (size + 2)) + math.abs(tonumber(cfg.iconX) or 4), 4)
        end
        self.bars:SetScale(math.max(0.5, tonumber(cfg.barScale) or 1))
        self.bars:SetShown(cfg.showBars ~= false)
        KTK.PaintBars(self.bars, members, now)
    end
    p:SetScript("OnUpdate", function(self, elapsed)
        self._acc = (self._acc or 0) + (elapsed or 0)
        if self._acc < 0.1 then return end
        self._acc = 0
        self:Refresh()
    end)
    p:Refresh()
    return p
end

-------------------------------------------------------------------------------
--  Unlock Mode
-------------------------------------------------------------------------------
local function RegisterMover()
    if KTK.moverRegistered or not KT.RegisterMovableElements then return end
    KT:RegisterMovableElements({
        {
            key = "ENH_KICK_TRACKER_BARS",
            label = LText("Kick Tracker"),
            group = "Enhancements",
            getFrame = function() return BuildBars() end,
            getSize = function()
                Refresh()
                local f = BuildBars()
                return math.max(120, f:GetWidth()), math.max(40, f:GetHeight())
            end,
            isHidden = function() return not Config().enable end,
            loadPosition = function()
                local p = Config().barsPosition
                return { point = p and p.point or "LEFT", relativePoint = p and (p.relativePoint or p.point) or "LEFT",
                    x = p and p.x or 40, y = p and p.y or 120 }
            end,
            savePosition = function(_, point, relativePoint, x, y)
                Config().barsPosition = { point = point or "LEFT", relativePoint = relativePoint or point or "LEFT", x = x or 40, y = y or 120 }
            end,
            applyPosition = function() KTK.ApplyBarsPosition() end,
            applyPendingPosition = function(_, pos)
                local f = BuildBars()
                f:ClearAllPoints()
                f:SetPoint(pos.point or "LEFT", UIParent, pos.relativePoint or pos.point or "LEFT", pos.x or 40, pos.y or 120)
            end,
        },
    })
    KTK.moverRegistered = true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    RegisterMover()
    -- The bars show sample rows while Unlock Mode is open.
    local unlock = KT.GetModule and KT:GetModule("UnlockMode", true)
    if unlock and _G.hooksecurefunc then
        for _, method in ipairs({ "OpenUnlockMode", "CloseUnlockMode" }) do
            if type(unlock[method]) == "function" then _G.hooksecurefunc(unlock, method, function() Refresh() end) end
        end
    end
    if KTK.Refresh then KTK.Refresh() end
end)
