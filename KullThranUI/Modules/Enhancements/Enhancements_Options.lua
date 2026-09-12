local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then
    return
end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then
    return
end

local Opt = KT.Options or {}
local LText = Opt.LText or function(text) return text end
local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks
local CreateOptionBlock = Opt.CreateOptionBlock
local FinalizeOptionBlock = Opt.FinalizeOptionBlock

local CreateFrame = _G.CreateFrame
local ipairs = _G.ipairs
local math = _G.math
local pairs = _G.pairs
local strtrim = _G.strtrim
local type = _G.type
local wipe = _G.wipe
local CLASS_ICON_TCOORDS = _G.CLASS_ICON_TCOORDS
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local READY_CHECK_READY_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local CLASS_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local function CurrentAccentColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    return (accent and accent.r) or KT.C_R or 1,
        (accent and accent.g) or KT.C_G or 0,
        (accent and accent.b) or KT.C_B or 0.3333333333
end

local function DB()
    return Mod:GetDB()
end

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = CopyValue(nested)
    end
    return copy
end

local function ResetModuleDefaults()
    local db = DB()
    wipe(db)
    for key, value in pairs(Mod:GetDefaults() or {}) do
        db[key] = CopyValue(value)
    end
end

local function Refresh(opts)
    if Mod and Mod.RefreshSettings then
        Mod:RefreshSettings()
    end
    if opts and opts.rebuild and KT and KT.RefreshPage then
        KT:RefreshPage(true)
    end
end

local function AddToggleList(container, W, items, startY)
    local y, h = startY or 0, 0
    for _, item in ipairs(items) do
        _, h = W:Toggle(container, LText(item.label), -y,
            function() return item.get() end,
            function(v)
                item.set(v)
                Refresh(item.refreshOpts)
            end)
        y = y + h
    end
    return y
end

local function AddOptimizationSettingList(container, W, settings, startY)
    local originY = startY or 0
    local y, h = originY, 0

    for _, setting in ipairs(settings or {}) do
        local current, _, optimal = Mod:GetOptimizationStatus(setting)

        local row = CreateFrame("Frame", nil, container, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 10, -y)
        row:SetPoint("TOPRIGHT", -10, -y)
        KT:AddBackdrop(row, 0.03, 0.035, 0.05, 0.92)
        do
            local accentR, accentG, accentB = CurrentAccentColor()
            KT:AddBorder(row, accentR, accentG, accentB, 0.16)
        end

        local title = row:CreateFontString(nil, "OVERLAY")
        title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        title:SetTextColor(1, 1, 1, 1)
        title:SetPoint("TOPLEFT", 10, -8)
        title:SetPoint("TOPRIGHT", -10, -8)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(true)
        title:SetText(LText(setting.name))

        local status = row:CreateFontString(nil, "OVERLAY")
        status:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 9, "")
        status:SetTextColor(0.74, 0.74, 0.78, 1)
        status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        status:SetPoint("TOPRIGHT", -10, 0)
        status:SetJustifyH("LEFT")
        status:SetWordWrap(true)
        status:SetText(string.format("%s -> %s", tostring(current), tostring(optimal)))

        local titleHeight = math.max(14, title:GetStringHeight())
        local statusHeight = math.max(14, status:GetStringHeight())
        local headerHeight = 12 + titleHeight + 4 + statusHeight + 8
        row:SetHeight(headerHeight)
        y = y + headerHeight

        _, h = W:Button(container, LText("Apply Recommended"), -y, function()
            Mod:ApplyOptimizationCVar(setting.cvar, setting.optimal)
            Refresh({ rebuild = true })
        end)
        y = y + h

        _, h = W:Button(container, LText("Revert Setting"), -y, function()
            Mod:RevertOptimizationCVar(setting.cvar)
            Refresh({ rebuild = true })
        end)
        y = y + h + 4
    end

    return y - originY
end

local function AddMonitorBlock(container, W, startY)
    local originY = startY or 0
    local y, h = originY, 0
    local function CreateMonitorLine(text)
        local line = CreateFrame("Frame", nil, container)
        line:SetSize(container:GetWidth() - 20, 18)
        line:SetPoint("TOPLEFT", 10, -y)

        local label = line:CreateFontString(nil, "OVERLAY")
        label:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "")
        label:SetTextColor(0.74, 0.74, 0.78, 1)
        label:SetPoint("LEFT", 4, 0)
        label:SetPoint("RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetText(text or "")

        local lineHeight = math.max(20, label:GetStringHeight() + 4)
        line:SetHeight(lineHeight)
        y = y + lineHeight + 2
        return label
    end

    local avgLabel = CreateMonitorLine(LText("Warming up..."))
    local lastLabel = CreateMonitorLine("")
    local peakLabel = CreateMonitorLine("")
    local encounterLabel = CreateMonitorLine("")

    local function UpdateLabels()
        local snapshot = Mod:GetOptimizationMonitorSnapshot()
        if snapshot.disabled then
            avgLabel:SetText(LText("AddOn Profiler is disabled."))
            lastLabel:SetText("")
            peakLabel:SetText("")
            encounterLabel:SetText("")
            return
        end
        if snapshot.unavailable then
            avgLabel:SetText(LText("Profiler unavailable."))
            lastLabel:SetText("")
            peakLabel:SetText("")
            encounterLabel:SetText("")
            return
        end

        if snapshot.warming then
            avgLabel:SetText(LText("Warming up..."))
            lastLabel:SetText("")
            peakLabel:SetText("")
            encounterLabel:SetText("")
            return
        end

        avgLabel:SetText(string.format("%s %.2f ms", LText("Average (60 ticks):"), snapshot.recentAvg or 0))
        lastLabel:SetText(string.format("%s %.2f ms", LText("Last tick:"), snapshot.lastTick or 0))
        peakLabel:SetText(string.format("%s %.2f ms", LText("Peak:"), snapshot.peak or 0))
        encounterLabel:SetText(string.format("%s %.2f ms", LText("Encounter average:"), snapshot.encounterAvg or 0))
    end

    UpdateLabels()

    if not container._ktEnhancementsMonitorUpdater then
        local updater = CreateFrame("Frame", nil, container)
        updater.elapsed = 0
        updater:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < 0.5 then
                return
            end
            self.elapsed = 0
            UpdateLabels()
        end)
        container._ktEnhancementsMonitorUpdater = updater
    end

    return y - originY
end

local function GetActiveCategory()
    local db = DB()
    db.ui = db.ui or {}
    if not db.ui.activeEnhancementCategory then
        db.ui.activeEnhancementCategory = "instance"
    end
    return db.ui.activeEnhancementCategory
end

local function SetActiveCategory(key)
    local db = DB()
    db.ui = db.ui or {}
    db.ui.activeEnhancementCategory = key
end

local function GetSystemSectionState(key, defaultOpen)
    local db = DB()
    db.ui = db.ui or {}
    if db.ui.activeEnhancementSystemSection == nil and defaultOpen then
        db.ui.activeEnhancementSystemSection = key
    end
    return db.ui.activeEnhancementSystemSection == key
end

local function SetSystemSectionState(key, value)
    local db = DB()
    db.ui = db.ui or {}
    db.ui.activeEnhancementSystemSection = value and key or nil
end

local CATEGORY_ORDER = { "instance", "damage", "timer", "automation", "interface", "system" }

local CATEGORY_META = {
    instance = {
        title = LText("Dungeon & Raid"),
        description = LText("Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."),
    },
    damage = {
        title = LText("Damage Meter"),
        description = LText("Combat rankings, display modes, sessions, bars, and meter layout."),
    },
    timer = {
        title = LText("Mythic+ Timer"),
        description = LText("Per-pull combat timing, live preview, colors, typography, and warnings."),
    },
    automation = {
        title = LText("Automation & Social"),
        description = LText("Quest automation, invite rules, group tools, and social quality-of-life settings."),
    },
    interface = {
        title = LText("Interface & Comfort"),
        description = LText("Visual cleanup, text sizing, and general comfort options for the client UI."),
    },
    system = {
        title = LText("System Tuning"),
        description = LText("Performance presets, graphics CVars, spell queue tuning, and live diagnostics."),
    },
}

local CATEGORY_ICONS = {
    instance = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\EnhacementsIcons\\Dungeon&Raids.tga",
    damage = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\EnhacementsIcons\\DamageMeter.tga",
    timer = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\EnhacementsIcons\\MythicPlusTimer.tga",
    automation = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\EnhacementsIcons\\Automation&Social.tga",
    interface = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\EnhacementsIcons\\Interface&Combat.tga",
    system = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\EnhacementsIcons\\SystemTuning.tga",
}

local CATEGORY_ICON_COLORS = {
    instance = { 1.00, 0.82, 0.10 }, -- yellow
    damage = { 1.00, 0.12, 0.12 }, -- red
    timer = { 0.72, 0.28, 1.00 }, -- purple
    automation = { 0.20, 1.00, 0.35 }, -- green
    interface = { 0.20, 0.55, 1.00 }, -- blue
    system = { 1.00, 1.00, 1.00 }, -- white
}

local CATEGORY_BUTTON_WIDTH = 198
local CATEGORY_TEXT_WIDTH = 174
local CATEGORY_DESCRIPTION_WIDTH = 146
local CATEGORY_BUTTON_MIN_HEIGHT = 88

local function StyleNavButton(button, active)
    local accentR, accentG, accentB = CurrentAccentColor()
    local borderAlpha = active and 0.9 or 0.28
    local fillAlpha = active and 0.18 or 0.08

    KT:AddBackdrop(button, 0.05, 0.06, 0.08, 0.94)
    KT:AddBorder(button, accentR, accentG, accentB, borderAlpha)

    if button._ktFill then
        button._ktFill:SetColorTexture(accentR, accentG, accentB, fillAlpha)
    end
    if button._ktBar then
        button._ktBar:SetColorTexture(accentR, accentG, accentB, active and 1 or 0.35)
    end
    if button._ktIconFrame then
        KT:AddBackdrop(button._ktIconFrame, 0.02, 0.02, 0.03, active and 0.92 or 0.78)
        KT:AddBorder(button._ktIconFrame, accentR, accentG, accentB, active and 1 or 0.68, 2)
    end
    if button._ktIcon then
        local iconColor = CATEGORY_ICON_COLORS[button._ktCategoryKey]
        local iconR = iconColor and iconColor[1] or accentR
        local iconG = iconColor and iconColor[2] or accentG
        local iconB = iconColor and iconColor[3] or accentB
        if button._ktIcon.SetDesaturated then
            button._ktIcon:SetDesaturated(true)
        end
        button._ktIcon:SetVertexColor(iconR, iconG, iconB, active and 1 or 0.88)
    end
    if button.Title then
        button.Title:SetTextColor(active and 1 or 0.82, active and 1 or 0.82, active and 1 or 0.82, 1)
    end
    if button.Description then
        button.Description:SetTextColor(active and 0.86 or 0.66, active and 0.86 or 0.66, active and 0.86 or 0.70, 1)
    end
end

local function CreateCategoryButton(parent, key, yOffset)
    local meta = CATEGORY_META[key]
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button._ktCategoryKey = key
    button:SetPoint("TOPLEFT", 8, yOffset)
    button:SetSize(CATEGORY_BUTTON_WIDTH, CATEGORY_BUTTON_MIN_HEIGHT)

    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    button._ktFill = fill

    local bar = button:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    bar:SetWidth(4)
    button._ktBar = bar

    local iconFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
    iconFrame:SetSize(30, 30)
    iconFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -7, 7)
    iconFrame:EnableMouse(false)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(CATEGORY_ICONS[key] or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button._ktIconFrame = iconFrame
    button._ktIcon = icon

    local title = button:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -8)
    title:SetWidth(CATEGORY_TEXT_WIDTH)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    title:SetText(LText(meta.title))
    button.Title = title

    local description = button:CreateFontString(nil, "OVERLAY")
    description:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 9, "")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    description:SetWidth(CATEGORY_DESCRIPTION_WIDTH)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    description:SetText(LText(meta.description))
    button.Description = description

    local titleHeight = math.max(14, title:GetStringHeight())
    local descriptionHeight = math.max(22, description:GetStringHeight())
    local buttonHeight = math.max(CATEGORY_BUTTON_MIN_HEIGHT, 12 + titleHeight + 6 + descriptionHeight + 12)
    button:SetHeight(buttonHeight)

    button:SetScript("OnEnter", function(self)
        if GetActiveCategory() ~= key then
            local accentR, accentG, accentB = CurrentAccentColor()
            KT:AddBorder(self, accentR, accentG, accentB, 0.55)
        end
    end)
    button:SetScript("OnLeave", function(self)
        StyleNavButton(self, GetActiveCategory() == key)
    end)
    button:SetScript("OnClick", function()
        SetActiveCategory(key)
        Refresh({ rebuild = true })
    end)

    StyleNavButton(button, GetActiveCategory() == key)
    return button, buttonHeight + 8
end

local function CreateSidebar(parent, W)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetWidth(214)
    KT:AddBackdrop(frame, 0.03, 0.04, 0.06, 0.96)
    do
        local accentR, accentG, accentB = CurrentAccentColor()
        KT:AddBorder(frame, accentR, accentG, accentB, 0.28)
    end

    local y, h = 0, 0
    _, h = W:SectionHeader(frame, LText("Views"), 0)
    y = y + h
    _, h = W:Label(frame, LText("Choose a focus area to reduce noise and keep related options together."), -y, 10)
    y = y + h + 8

    for _, key in ipairs(CATEGORY_ORDER) do
        _, h = CreateCategoryButton(frame, key, -y)
        y = y + h
    end

    frame:SetHeight(y + 8)
    return frame
end

local function BuildCombatRezBlock(container, W, db)
    return AddToggleList(container, W, {
        { label = LText("Enable Combat Res Timer"), get = function() return db.combatRez.enabled end, set = function(v) db.combatRez.enabled = v end, refreshOpts = { rebuild = true } },
        { label = LText("Death as Warning"), get = function() return db.combatRez.deathWarning end, set = function(v) db.combatRez.deathWarning = v end },
    })
end

local function SetPreviewBorderColor(frame, r, g, b, a)
    if not (frame and frame._ktBorders) then
        return
    end
    for _, edge in ipairs(frame._ktBorders) do
        edge:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    end
end

local TRACKER_DEFAULT_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local TRACKER_DEFAULT_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
local TRACKER_FONTS = {
    [TRACKER_DEFAULT_FONT] = LText("Avant Garde"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\FiraSans Medium.ttf"] = LText("Fira Sans"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Ubuntu.ttf"] = LText("Ubuntu"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Poppins.ttf"] = LText("Poppins"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\font\\Tempesta Seven Condensed.ttf"] = LText("Tempesta Seven"),
}
local TRACKER_FONT_ORDER = {
    TRACKER_DEFAULT_FONT,
    "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\FiraSans Medium.ttf",
    "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Ubuntu.ttf",
    "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Poppins.ttf",
    "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Tempesta Seven Condensed.ttf",
}
local TRACKER_TEXTURES = {
    [TRACKER_DEFAULT_TEXTURE] = LText("Melli"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"] = LText("Melli Dark"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Clean.blp"] = LText("Statusbar Clean"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes_Thin.blp"] = LText("Statusbar Stripes Thin"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes.blp"] = LText("Statusbar Stripes"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\stripe-bar.tga"] = LText("Stripe Bar"),
}
local TRACKER_TEXTURE_ORDER = {
    TRACKER_DEFAULT_TEXTURE,
    "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
    "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Clean.blp",
    "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes_Thin.blp",
    "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes.blp",
    "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\stripe-bar.tga",
}

local function TrackerMediaLabel(value)
    if type(value) ~= "string" or value == "" then
        return value
    end
    if not value:find("\\", 1, true) and not value:find("/", 1, true) then
        return value
    end
    local normalized = value:gsub("\\", "/")
    local name = normalized:match("([^/]+)$") or normalized
    name = name:gsub("%.[^%.]+$", "")
    name = name:gsub("_", " ")
    return name
end

local function BuildTrackerMediaChoices(mediaType, fixedValues, fixedOrder)
    local values, order, seen = {}, {}, {}
    local function Add(key, label)
        if type(key) ~= "string" or key == "" or seen[key] then
            return
        end
        seen[key] = true
        if type(label) ~= "string" or label == "" then
            label = TrackerMediaLabel(key)
        end
        values[key] = label
        order[#order + 1] = key
    end

    for _, key in ipairs(fixedOrder or {}) do
        Add(key, fixedValues and fixedValues[key])
    end

    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM.List then
        for _, key in ipairs(LSM:List(mediaType) or {}) do
            Add(key, key)
        end
    end

    return values, order
end

local function GetTrackerFontValues()
    local values = BuildTrackerMediaChoices("font", TRACKER_FONTS, TRACKER_FONT_ORDER)
    return values
end

local function GetTrackerFontOrder()
    local _, order = BuildTrackerMediaChoices("font", TRACKER_FONTS, TRACKER_FONT_ORDER)
    return order
end

local function GetTrackerTextureValues()
    local values = BuildTrackerMediaChoices("statusbar", TRACKER_TEXTURES, TRACKER_TEXTURE_ORDER)
    return values
end

local function GetTrackerTextureOrder()
    local _, order = BuildTrackerMediaChoices("statusbar", TRACKER_TEXTURES, TRACKER_TEXTURE_ORDER)
    return order
end
local function ScrollEnhancementPreviewToOptions(preview)
    local menu = KT and KT.MenuPrincipal
    local scrollFrame = menu and menu.scrollFrame
    local scrollChild = menu and menu.scrollChild
    if not (preview and scrollFrame and scrollChild and preview.GetTop and scrollChild.GetTop) then
        return
    end

    local previewTop = select(2, preview:GetTop())
    local contentTop = select(2, scrollChild:GetTop())
    if not (previewTop and contentTop) then
        return
    end

    local target = (contentTop - previewTop) + (preview:GetHeight() or 0) + 8
    if KT.SmoothScrollTo then
        KT.SmoothScrollTo(math.max(0, target))
    elseif scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:SetValue(math.max(0, target))
    end
end

local function MakeEnhancementPreviewClickable(preview, categoryKey)
    if not preview then
        return
    end

    local hit = CreateFrame("Button", nil, preview)
    hit:SetAllPoints()
    hit:SetFrameLevel((preview:GetFrameLevel() or 1) + 50)
    hit:RegisterForClicks("LeftButtonUp")

    local highlight = hit:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    local ar, ag, ab = CurrentAccentColor()
    highlight:SetColorTexture(ar, ag, ab, 0.08)

    hit:SetScript("OnClick", function()
        if GetActiveCategory() ~= categoryKey then
            SetActiveCategory(categoryKey)
            Refresh({ rebuild = true })
            return
        end
        ScrollEnhancementPreviewToOptions(preview)
    end)
    hit:SetScript("OnEnter", function()
        local r, g, b = CurrentAccentColor()
        highlight:SetColorTexture(r, g, b, 0.08)
    end)
    hit:SetScript("OnLeave", function()
        highlight:SetColorTexture(ar, ag, ab, 0.08)
    end)

    preview._enhancementPreviewHit = hit
end

local function CreateMythicPlusLivePreview(container, startY, db)
    db.mplusTracker = db.mplusTracker or {}
    local config = db.mplusTracker

    local y = startY or 0
    local previewWidth = math.max(240, (container:GetWidth() or 260) - 20)
    local preview = CreateFrame("Frame", nil, container, "BackdropTemplate")
    preview:SetPoint("TOP", container, "TOP", 0, -y)
    preview:SetSize(previewWidth, 180)

    local barTex = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
    local fontPath = KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
    KT:AddBackdrop(preview, 0.05, 0.05, 0.05, 0)
    KT:AddBorder(preview, 0, 0, 0, 0)

    local deaths = preview:CreateFontString(nil, "OVERLAY")
    deaths:SetJustifyH("RIGHT")
    local timer = preview:CreateFontString(nil, "OVERLAY")
    local timerRemaining = preview:CreateFontString(nil, "OVERLAY")
    timerRemaining:SetJustifyH("RIGHT")
    local timerTotal = preview:CreateFontString(nil, "OVERLAY")
    timerTotal:SetJustifyH("RIGHT")
    timer:SetJustifyH("RIGHT")
    local key = preview:CreateFontString(nil, "OVERLAY")
    key:SetJustifyH("LEFT")
    local keyDetails = preview:CreateFontString(nil, "OVERLAY")
    keyDetails:SetJustifyH("RIGHT")
    local keyRow = CreateFrame("Frame", nil, preview)
    keyRow:SetHeight(24)

    local segments = {}
    for i = 1, 3 do
        local bar = CreateFrame("StatusBar", nil, preview, "BackdropTemplate")
        bar:SetStatusBarTexture(barTex)
        KT:AddBackdrop(bar, 0, 0, 0, 0.4)
        local text = bar:CreateFontString(nil, "OVERLAY")
        text:SetJustifyH("RIGHT")
        segments[i] = { bar = bar, text = text }
    end

    local forces = CreateFrame("StatusBar", nil, preview, "BackdropTemplate")
    forces:SetStatusBarTexture(barTex)
    KT:AddBackdrop(forces, 0, 0, 0, 0.4)
    local forcesGlow = CreateFrame("StatusBar", nil, forces)
    forcesGlow:SetAllPoints()
    forcesGlow:SetFrameLevel(forces:GetFrameLevel() + 1)
    local forcesText = forces:CreateFontString(nil, "OVERLAY")
    forcesText:SetJustifyH("RIGHT")
    forcesText:SetJustifyV("MIDDLE")

    local objectives = {}
    for i = 1, 3 do
        objectives[i] = preview:CreateFontString(nil, "OVERLAY")
        objectives[i]:SetJustifyH("RIGHT")
    end

    local function ResolveFont(c, key, fallbackKey)
        local name = c[key]
        if (type(name) ~= "string" or name == "") and fallbackKey then
            name = c[fallbackKey]
        end
        local resolved
        if type(name) == "string" and name ~= "" then
            if name:sub(1, 10) == "Interface\\" then
                resolved = name
            else
                local LSM = LibStub("LibSharedMedia-3.0", true)
                resolved = LSM and LSM:Fetch("font", name)
            end
        end
        if not resolved then
            local globalFont = c.globalFont
            if type(globalFont) == "string" and globalFont ~= "" then
                if globalFont:sub(1, 10) == "Interface\\" then
                    resolved = globalFont
                else
                    local LSM = LibStub("LibSharedMedia-3.0", true)
                    resolved = LSM and LSM:Fetch("font", globalFont)
                end
            end
        end
        resolved = resolved or fontPath
        if KT and KT.ResolveFontForLocale then
            return KT:ResolveFontForLocale(resolved, fontPath)
        end
        return resolved
    end

    local function Apply()
        local c = db.mplusTracker or {}
        local configuredWidth = math.max(150, math.min(720, tonumber(c.barWidth) or 271))
        preview:SetWidth(configuredWidth)
        local previewBackground = c.backgroundColor or { r = 0.01, g = 0.01, b = 0.015, a = 0 }
        local previewBackgroundAlpha = c.showBackground == true and (previewBackground.a or 0) or 0
        if preview.SetBackdropColor then
            preview:SetBackdropColor(previewBackground.r or 0, previewBackground.g or 0, previewBackground.b or 0, previewBackgroundAlpha)
        end
        SetPreviewBorderColor(preview, 0, 0, 0, previewBackgroundAlpha > 0 and 1 or 0)
        local pad = 8
        local width = math.max(120, configuredWidth - pad * 2)
        local top = 0

        local dc = c.deathsColor or { r = 1, g = 0, b = 0.412, a = 1 }
        deaths:SetFont(ResolveFont(c, "deathsFont"), c.deathsFontSize or 13, c.deathsFontFlags or "OUTLINE")
        deaths:SetTextColor(dc.r, dc.g, dc.b, dc.a or 1)
        deaths:ClearAllPoints()
        deaths:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -pad, -top)
        deaths:SetText(string.format("%d Deaths (-%s)", 2, "00:10"))
        top = top + (c.deathsFontSize or 13) + 4

        local trc = c.timerRunningColor or { r = 1, g = 0.808, b = 0.714, a = 1 }
        local timerFont = ResolveFont(c, "timerFont")
        local timerSize = c.timerFontSize or 22
        timer:SetFont(timerFont, timerSize, c.timerFontFlags or "OUTLINE")
        timer:SetTextColor(trc.r, trc.g, trc.b, 1)
        timer:Hide()
        timerRemaining:SetFont(timerFont, timerSize, c.timerFontFlags or "OUTLINE")
        timerRemaining:SetTextColor(trc.r, trc.g, trc.b, 1)
        timerRemaining:Hide()
        timerTotal:SetFont(timerFont, math.max(9, math.floor(timerSize * 0.42)), c.timerFontFlags or "OUTLINE")
        timerTotal:SetTextColor(trc.r, trc.g, trc.b, 0.72)
        timerTotal:Hide()

        if c.showRemainingTimeOnly == true then
            timerRemaining:ClearAllPoints()
            timerRemaining:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -pad, -top)
            timerRemaining:SetText("10:00")
            timerRemaining:Show()
            top = top + math.max(timerSize, 18) + 1
            timerTotal:ClearAllPoints()
            timerTotal:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -pad, -top)
            timerTotal:SetText("30:00")
            timerTotal:Show()
            top = top + math.max(9, math.floor(timerSize * 0.42)) + 3
        else
            timer:ClearAllPoints()
            timer:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -pad, -top)
            timer:SetText("20:00 / 30:00")
            timer:Show()
            top = top + math.max(timerSize, 18) + 4
        end
        local kc = c.keyColor or { r = 0.761, g = 0, b = 1, a = 1 }
        local kdc = c.keyDetailsColor or { r = 1, g = 0.804, b = 0.569, a = 1 }
        key:SetFont(ResolveFont(c, "keyFont"), c.keyFontSize or 14, c.keyFontFlags or "OUTLINE")
        key:SetTextColor(kc.r, kc.g, kc.b, 1)
        key:SetText("[10]")
        keyDetails:SetFont(ResolveFont(c, "keyDetailsFont"), c.keyDetailsFontSize or 11, c.keyDetailsFontFlags or "OUTLINE")
        keyDetails:SetTextColor(kdc.r, kdc.g, kdc.b, 1)
        keyDetails:SetText("Tyrannical - Fortified")
        key:ClearAllPoints()
        keyDetails:ClearAllPoints()
        keyRow:ClearAllPoints()
        local keyWidth = math.max(1, key:GetStringWidth() or 0)
        local detailsWidth = math.max(1, keyDetails:GetStringWidth() or 0)
        local keyHeight = math.max(
            key:GetStringHeight() or 0,
            keyDetails:GetStringHeight() or 0,
            c.keyFontSize or 14,
            c.keyDetailsFontSize or 11,
            14)
        keyRow:SetSize(detailsWidth + keyWidth + 6, keyHeight)
        keyRow:SetPoint("TOP", preview, "TOP", 0, -top)
        keyDetails:SetPoint("LEFT", keyRow, "LEFT", 0, 0)
        key:SetPoint("LEFT", keyDetails, "RIGHT", 6, 0)
        -- Keep the chest-timer bars on a separate row below the affixes.
        top = top + keyHeight + 8

        -- Segments (+3, +2, +1 -> left to right)
        local barH = c.barHeight or 10
        local texturePath = c.barTexture
        if type(texturePath) ~= "string" or texturePath == "" then texturePath = TRACKER_DEFAULT_TEXTURE end
        if texturePath:sub(1, 10) ~= "Interface\\" then
            local LSM = LibStub("LibSharedMedia-3.0", true)
            texturePath = (LSM and LSM:Fetch("statusbar", texturePath)) or TRACKER_DEFAULT_TEXTURE
        end
        local gap = 2
        local availW = width - pad * 2
        local frac1, frac2, frac3 = 0.6, 0.2, 0.2
        local w1 = math.max(20, math.floor((availW - gap * 2) * frac1))
        local w2 = math.max(20, math.floor((availW - gap * 2) * frac2))
        local w3 = math.max(20, availW - gap * 2 - w1 - w2)
        local colors = {
            c.bar1Color or { r = 0, g = 1, b = 0.478, a = 1 },
            c.bar2Color or { r = 0, g = 0.749, b = 1, a = 1 },
            c.bar3Color or { r = 0.796, g = 0, b = 1, a = 1 },
        }
        local widths = { w1, w2, w3 }
        local x = pad
        for i = 1, 3 do
            local seg = segments[i]
            seg.bar:SetStatusBarTexture(texturePath)
            local segmentColor = colors[i]
            seg.bar:SetStatusBarColor(segmentColor.r, segmentColor.g, segmentColor.b, segmentColor.a or 1)
            seg.bar:ClearAllPoints()
            seg.bar:SetPoint("TOPLEFT", preview, "TOPLEFT", x, -top)
            seg.bar:SetSize(widths[i], barH)
            seg.bar:SetMinMaxValues(0, 1)
            seg.bar:SetValue(0.42)
            seg.text:SetFont(ResolveFont(c, "bar" .. i .. "Font", "timerFont"), math.max(10, (c.timerFontSize or 22) * 0.55), "OUTLINE")
            seg.text:SetTextColor(trc.r, trc.g, trc.b, 1)
            seg.text:SetText(string.format("%d:%02d", i * 4, 0))
            seg.text:ClearAllPoints()
            seg.text:SetPoint("BOTTOMRIGHT", seg.bar, "BOTTOMRIGHT", -2, 1)
            x = x + widths[i] + gap
        end
        top = top + barH + 14

        -- Forces
        local fc = c.forcesBarColor or { r = 0.733, g = 0.62, b = 0.133, a = 1 }
        forces:SetStatusBarTexture(texturePath)
        forces:SetStatusBarColor(fc.r, fc.g, fc.b, fc.a or 1)
        forces:ClearAllPoints()
        forces:SetPoint("TOPLEFT", preview, "TOPLEFT", pad, -top)
        forces:SetSize(availW, barH)
        forces:SetMinMaxValues(0, 1)
        forces:SetValue(0.82)
        local glowC = c.forcesGlowColor or { r = 1, g = 0.33, b = 0.08, a = 0.8 }
        forcesGlow:SetStatusBarTexture(texturePath)
        forcesGlow:SetStatusBarColor(glowC.r, glowC.g, glowC.b, glowC.a or 0.8)
        forcesGlow:SetMinMaxValues(0, 1)
        forcesGlow:SetValue(0.82)
        forcesGlow:SetAlpha(c.showForcesGlow == true and 1 or 0)
        local forcesC = c.forcesColor or { r = 1, g = 1, b = 1, a = 1 }
        forcesText:SetFont(ResolveFont(c, "forcesFont"), c.forcesFontSize or 11, c.forcesFontFlags or "OUTLINE")
        forcesText:SetTextColor(forcesC.r, forcesC.g, forcesC.b, 1)
        forcesText:SetText(LText("Forces") .. ": 82.33%")
        forcesText:ClearAllPoints()
        forcesText:SetWidth(math.max(1, availW - 6))
        forcesText:SetHeight(math.max(barH, c.forcesFontSize or 11))
        forcesText:SetPoint("BOTTOMRIGHT", forces, "TOPRIGHT", -3, 2)
        forcesText:SetDrawLayer("OVERLAY")
        top = top + barH + 14

        -- Objectives
        local objColor = c.objectivesColor or { r = 1, g = 1, b = 1, a = 1 }
        local okColor = c.completedObjectivesColor or { r = 0, g = 1, b = 0.14, a = 1 }
        local objFontSize = c.objectivesFontSize or 11
        local bossLines = {
            string.format("|cff%02x%02x%02x|T%s:12:12:0:0|t First Boss (03:20)|r", math.floor(okColor.r * 255), math.floor(okColor.g * 255), math.floor(okColor.b * 255), READY_CHECK_READY_TEXTURE),
            string.format("|cff%02x%02x%02x|T%s:12:12:0:0|t Second Boss (06:40)|r", math.floor(okColor.r * 255), math.floor(okColor.g * 255), math.floor(okColor.b * 255), READY_CHECK_READY_TEXTURE),
            "[ ] Third Boss",
        }
        for i = 1, 3 do
            local text = objectives[i]
            text:SetFont(ResolveFont(c, "objectivesFont"), objFontSize, c.objectivesFontFlags or "OUTLINE")
            text:SetTextColor(objColor.r, objColor.g, objColor.b, objColor.a or 1)
            text:ClearAllPoints()
            text:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -pad, -top)
            text:SetText(bossLines[i])
            top = top + objFontSize + 4
        end
    end

    MakeEnhancementPreviewClickable(preview, "timer")
    preview:SetScript("OnUpdate", function(self, elapsed)
        self._acc = (self._acc or 0) + elapsed
        if self._acc < 0.15 then
            return
        end
        self._acc = 0
        Apply()
    end)
    Apply()
    return 180
end

local function BuildMythicPlusTrackerBlock(container, W, db)
    db.mplusTracker = db.mplusTracker or {}
    local config = db.mplusTracker
    local y, h = 0, 0

    h = CreateMythicPlusLivePreview(container, y, db)
    y = y + h + 8

    -- Keep the actions next to the preview so testing never requires scrolling
    -- through every display setting first.
    _, h = W:Button(container, LText("Test Tracker"), -y, function()
        if Mod.RunMythicPlusTrackerTest then Mod:RunMythicPlusTrackerTest() end
    end)
    y = y + h

    _, h = W:Button(container, LText("Stop Test"), -y, function()
        if Mod.StopMythicPlusTrackerTest then Mod:StopMythicPlusTrackerTest() end
    end)
    y = y + h + 8

    local function RefreshTracker()
        if Mod.RefreshMythicPlusTracker then
            Mod:RefreshMythicPlusTracker()
        end
    end

    local function GetColorValue(color, default)
        local c = color or default
        return c.r, c.g, c.b, c.a or 1
    end

    local function AddColorSetting(parent, key, label, default, offset)
        local _, rowHeight = W:ColorSwatch(parent, LText(label), -offset,
            function()
                return GetColorValue(config[key], default)
            end,
            function(r, g, b, a)
                config[key] = { r = r, g = g, b = b, a = a or 1 }
                RefreshTracker()
            end,
            true)
        return rowHeight
    end

    local columns = BeginOptionBlocks(container, y, { gap = 10, columnGap = 10 })

    AddOptionBlock(columns, "left", LText("Tracker & Layout"), function(parent)
        local by, rowHeight = 0, 0
        local function AddToggle(label, getter, setter, refresh)
            _, rowHeight = W:Toggle(parent, LText(label), -by, getter, function(value)
                setter(value)
                if refresh ~= false then RefreshTracker() end
            end)
            by = by + rowHeight
        end

        AddToggle("Enable Mythic+ Tracker", function() return config.enabled == true end, function(value) config.enabled = value and true or false end)
        AddToggle("Insert Keystone Automatically", function() return config.insertKeystoneAutomatically end, function(value) config.insertKeystoneAutomatically = value end)
        AddToggle("Show MS (milliseconds) on Complete", function() return config.showMillisecondsWhenDungeonCompleted end, function(value) config.showMillisecondsWhenDungeonCompleted = value end)
        AddToggle("Show Remaining Time Only", function() return config.showRemainingTimeOnly == true end, function(value) config.showRemainingTimeOnly = value and true or false end)
        AddToggle("Show Tooltip Forces Count", function() return config.showTooltipCount ~= false end, function(value) config.showTooltipCount = value end)
        AddToggle("Show Deaths Tooltip (Hover)", function() return config.showDeathsTooltip ~= false end, function(value) config.showDeathsTooltip = value end)
        AddToggle("Show Tracker Background", function() return config.showBackground == true end, function(value) config.showBackground = value and true or false end)
        AddToggle("Show Forces Glow", function() return config.showForcesGlow == true end, function(value) config.showForcesGlow = value and true or false end)

        _, rowHeight = W:Slider(parent, LText("Scale"), -by,
            function() return config.scale or 1 end,
            function(value) config.scale = value; RefreshTracker() end,
            0.5, 2, 0.05)
        by = by + rowHeight
        _, rowHeight = W:Slider(parent, LText("Bar Width"), -by,
            function() return config.barWidth or 271 end,
            function(value) config.barWidth = value; RefreshTracker() end,
            150, 400, 1)
        by = by + rowHeight
        _, rowHeight = W:Slider(parent, LText("Bar Height"), -by,
            function() return config.barHeight or 10 end,
            function(value) config.barHeight = value; RefreshTracker() end,
            4, 40, 1)
        by = by + rowHeight
        return by
    end)

    AddOptionBlock(columns, "right", LText("Typography"), function(parent)
        local by, rowHeight = 0, 0
        local function AddSize(label, key, default)
            _, rowHeight = W:Slider(parent, LText(label), -by,
                function() return config[key] or default end,
                function(value) config[key] = value; RefreshTracker() end,
                8, 48, 1)
            by = by + rowHeight
        end
        AddSize("Key Level Font Size", "keyFontSize", 16)
        AddSize("Key Details Font Size", "keyDetailsFontSize", 13)
        AddSize("Timer Font Size", "timerFontSize", 26)
        AddSize("Forces Font Size", "forcesFontSize", 13)
        AddSize("Deaths Font Size", "deathsFontSize", 15)
        AddSize("Objectives Font Size", "objectivesFontSize", 12)
        return by
    end)

    AddOptionBlock(columns, "right", LText("Tracker Media"), function(parent)
        local by, rowHeight = 0, 0
        local function AddFontChoice(label, key, fallbackKey)
            _, rowHeight = W:Dropdown(parent, LText(label), -by, GetTrackerFontValues,
                function()
                    return config[key] or (fallbackKey and config[fallbackKey]) or config.globalFont or TRACKER_DEFAULT_FONT
                end,
                function(value)
                    config[key] = value
                    RefreshTracker()
                end,
                GetTrackerFontOrder, "font")
            by = by + rowHeight
        end

        AddFontChoice("Tracker Font", "globalFont")
        AddFontChoice("Chest +3 Font", "bar1Font", "timerFont")
        AddFontChoice("Chest +2 Font", "bar2Font", "timerFont")
        AddFontChoice("Chest +1 Font", "bar3Font", "timerFont")
        AddFontChoice("Mobs Font", "forcesFont")
        by = by + 6

        _, rowHeight = W:Dropdown(parent, LText("Bar Texture"), -by, GetTrackerTextureValues,
            function() return config.barTexture or TRACKER_DEFAULT_TEXTURE end,
            function(value) config.barTexture = value; RefreshTracker() end,
            GetTrackerTextureOrder, "texture")
        by = by + rowHeight
        return by
    end)
    AddOptionBlock(columns, "left", LText("Timer & Key Colors"), function(parent)
        local by, rowHeight = 0, 0
        local function AddColor(key, label, default)
            rowHeight = AddColorSetting(parent, key, label, default, by)
            by = by + rowHeight
        end
        AddColor("backgroundColor", LText("Background Color"), { r = 0.01, g = 0.01, b = 0.015, a = 0 })
        AddColor("keyColor", LText("Key Level Color"), { r = 0.761, g = 0, b = 1, a = 1 })
        AddColor("keyDetailsColor", LText("Key Details Color"), { r = 1, g = 0.804, b = 0.569, a = 1 })
        AddColor("timerRunningColor", LText("Timer Running Color"), { r = 1, g = 0.808, b = 0.714, a = 1 })
        AddColor("timerSuccessColor", LText("Timer Success Color"), { r = 0.118, g = 1, b = 0.714, a = 1 })
        AddColor("timerExpiredColor", LText("Timer Expired Color"), { r = 1, g = 0.16, b = 0.18, a = 1 })
        AddColor("completedObjectivesColor", LText("Completed Objectives Color"), { r = 0, g = 1, b = 0.14, a = 1 })
        AddColor("deathsColor", LText("Deaths Color"), { r = 1, g = 0, b = 0.412, a = 1 })
        return by
    end)

    AddOptionBlock(columns, "right", LText("Forces & Segment Colors"), function(parent)
        local by, rowHeight = 0, 0
        local function AddColor(key, label, default)
            rowHeight = AddColorSetting(parent, key, label, default, by)
            by = by + rowHeight
        end
        AddColor("forcesColor", LText("Forces Text Color"), { r = 1, g = 1, b = 1, a = 1 })
        AddColor("forcesBarColor", LText("Forces Bar Color"), { r = 0.733, g = 0.62, b = 0.133, a = 1 })
        AddColor("forcesGlowColor", LText("Forces Glow Color"), { r = 1, g = 0.33, b = 0.08, a = 0.8 })
        AddColor("bar1Color", LText("+3 Segment Color"), { r = 0, g = 1, b = 0.478, a = 1 })
        AddColor("bar2Color", LText("+2 Segment Color"), { r = 0, g = 0.749, b = 1, a = 1 })
        AddColor("bar3Color", LText("+1 Segment Color"), { r = 0.796, g = 0, b = 1, a = 1 })
        return by
    end)

    y = EndOptionBlocks(columns) + 6
    _, h = W:Label(container, LText("Drag the timer from KUI Unlock Mode under Enhancements. The tracker background is disabled by default."), -y, 10)
    y = y + h

    return y
end

local function BuildCombatTimerBlock(container, W, db)
    db.combatTimer = db.combatTimer or {}
    local y = AddToggleList(container, W, {
        { label = LText("Enable Combat Timer"), get = function() return db.combatTimer.enabled == true end, set = function(v) db.combatTimer.enabled = v and true or false end },
        { label = LText("Show Combat Timer Background"), get = function() return db.combatTimer.showBackground == true end, set = function(v) db.combatTimer.showBackground = v and true or false end },
    })
    local h

    _, h = W:Slider(container, LText("Timer Font Size"), -y,
        function() return tonumber(db.combatTimer.fontSize) or 22 end,
        function(v) db.combatTimer.fontSize = math.floor(v + 0.5); Refresh() end,
        12, 48, 1)
    y = y + h

    _, h = W:Dropdown(container, LText("Font Outline"), -y,
        {
            none = LText("No Outline"),
            outline = LText("Outline"),
            thick = LText("Thick Outline"),
        },
        function()
            if db.combatTimer.outline == "" then return "none" end
            if db.combatTimer.outline == "THICKOUTLINE" then return "thick" end
            return "outline"
        end,
        function(value)
            db.combatTimer.outline = value == "none" and "" or (value == "thick" and "THICKOUTLINE" or "OUTLINE")
            Refresh()
        end,
        { "outline", "thick", "none" })
    y = y + h

    _, h = W:ColorSwatch(container, LText("Timer Color"), -y,
        function()
            local c = db.combatTimer.color or { r = 1, g = 1, b = 1, a = 1 }
            return c.r or 1, c.g or 1, c.b or 1, c.a or 1
        end,
        function(r, g, b, a)
            db.combatTimer.color = { r = r, g = g, b = b, a = a or 1 }
            Refresh()
        end)
    y = y + h

    _, h = W:ColorSwatch(container, LText("Background Color"), -y,
        function()
            local c = db.combatTimer.backgroundColor or { r = 0.01, g = 0.01, b = 0.015, a = 0.78 }
            return c.r or 0.01, c.g or 0.01, c.b or 0.015, c.a or 0.78
        end,
        function(r, g, b, a)
            db.combatTimer.backgroundColor = { r = r, g = g, b = b, a = a or 1 }
            Refresh()
        end)
    y = y + h

    _, h = W:Label(container, LText("Drag the timer from KUI Unlock Mode under Enhancements."), -y, 11)
    y = y + h

    return y
end

local function BuildCombatTextBlock(container, W, db)
    db.combatText = db.combatText or {}
    local y, h = AddToggleList(container, W, {
        { label = LText("Enable Combat Status Text"), get = function() return db.combatText.enabled == true end, set = function(v) db.combatText.enabled = v and true or false end },
        { label = LText("Show enter combat message"), get = function() return db.combatText.enterEnabled ~= false end, set = function(v) db.combatText.enterEnabled = v and true or false end },
        { label = LText("Show leave combat message"), get = function() return db.combatText.leaveEnabled ~= false end, set = function(v) db.combatText.leaveEnabled = v and true or false end },
        { label = LText("Show Combat Text Background"), get = function() return db.combatText.showBackground == true end, set = function(v) db.combatText.showBackground = v and true or false end },
    })

    _, h = W:Input(container, LText("Enter Combat Text"), -y,
        function()
            return Mod:GetCombatTextMessage("enter")
        end,
        function(value)
            Mod:SetCombatTextMessage("enter", value)
            Refresh()
        end)
    y = y + h

    _, h = W:Input(container, LText("Leave Combat Text"), -y,
        function()
            return Mod:GetCombatTextMessage("leave")
        end,
        function(value)
            Mod:SetCombatTextMessage("leave", value)
            Refresh()
        end)
    y = y + h

    _, h = W:Dropdown(container, LText("Combat Text Animation"), -y,
        {
            none = LText("No Animation"),
            fade = LText("Fade"),
            fadeScale = LText("Fade and Scale"),
        },
        function() return db.combatText.animation or "fadeScale" end,
        function(value)
            db.combatText.animation = value
            Refresh()
        end,
        { "fadeScale", "fade", "none" })
    y = y + h

    _, h = W:Dropdown(container, LText("Font Outline"), -y,
        {
            none = LText("No Outline"),
            outline = LText("Outline"),
            thick = LText("Thick Outline"),
        },
        function()
            if db.combatText.outline == "" then return "none" end
            if db.combatText.outline == "THICKOUTLINE" then return "thick" end
            return "outline"
        end,
        function(value)
            db.combatText.outline = value == "none" and "" or (value == "thick" and "THICKOUTLINE" or "OUTLINE")
            Refresh()
        end,
        { "none", "outline", "thick" })
    y = y + h

    _, h = W:Slider(container, LText("Font Size"), -y,
        function() return db.combatText.fontSize or 32 end,
        function(value) db.combatText.fontSize = value; Refresh() end,
        10, 72, 1)
    y = y + h

    _, h = W:Slider(container, LText("Display Duration"), -y,
        function() return db.combatText.duration or 1.6 end,
        function(value) db.combatText.duration = value; Refresh() end,
        0.5, 5, 0.1)
    y = y + h

    _, h = W:Slider(container, LText("Fade In Duration"), -y,
        function() return db.combatText.fadeIn or 0.12 end,
        function(value) db.combatText.fadeIn = value; Refresh() end,
        0, 1, 0.05)
    y = y + h

    _, h = W:Slider(container, LText("Fade Out Duration"), -y,
        function() return db.combatText.fadeOut or 0.35 end,
        function(value) db.combatText.fadeOut = value; Refresh() end,
        0, 2, 0.05)
    y = y + h

    _, h = W:ColorSwatch(container, LText("Enter Combat Color"), -y,
        function()
            local color = db.combatText.enterColor or { r = 1, g = 0.18, b = 0.18, a = 1 }
            return color.r, color.g, color.b, color.a
        end,
        function(r, g, b, a)
            db.combatText.enterColor = { r = r, g = g, b = b, a = a or 1 }
            Refresh()
        end, true)
    y = y + h

    _, h = W:ColorSwatch(container, LText("Leave Combat Color"), -y,
        function()
            local color = db.combatText.leaveColor or { r = 0.20, g = 1, b = 0.45, a = 1 }
            return color.r, color.g, color.b, color.a
        end,
        function(r, g, b, a)
            db.combatText.leaveColor = { r = r, g = g, b = b, a = a or 1 }
            Refresh()
        end, true)
    y = y + h

    _, h = W:ColorSwatch(container, LText("Combat Text Background Color"), -y,
        function()
            local color = db.combatText.backgroundColor or { r = 0.01, g = 0.01, b = 0.015, a = 0.76 }
            return color.r, color.g, color.b, color.a
        end,
        function(r, g, b, a)
            db.combatText.backgroundColor = { r = r, g = g, b = b, a = a or 1 }
            Refresh()
        end, true)
    y = y + h

    _, h = W:Button(container, LText("Preview Enter Combat"), -y, function()
        Mod:PreviewCombatText("enter")
    end)
    y = y + h

    _, h = W:Button(container, LText("Preview Leave Combat"), -y, function()
        Mod:PreviewCombatText("leave")
    end)
    y = y + h

    _, h = W:Label(container, LText("Move it from KUI Unlock Mode under Enhancements."), -y, 10)
    y = y + h

    return y
end

local DAMAGE_PREVIEW_MODES = {
    damageDone = LText("Damage Done"),
    dps = LText("DPS"),
    damageTaken = LText("Damage Taken"),
    enemyDamageTaken = LText("Enemy Damage Taken"),
    avoidableDamageTaken = LText("Avoidable Damage Taken"),
    healingDone = LText("Healing Done"),
    hps = LText("HPS"),
    absorbs = LText("Absorbs"),
    interrupts = LText("Interrupts"),
    dispels = LText("Dispels"),
    deaths = LText("Deaths"),
}

local DAMAGE_ICON_MODES = {
    spec = LText("Specialization Icon"),
    class = LText("Class Icon"),
    none = LText("No Icon"),
}

local DAMAGE_ICON_SHAPES = {
    square = LText("Square Icons"),
    round = LText("Round Icons"),
}

local DAMAGE_METER_DEFAULT_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local DAMAGE_METER_DEFAULT_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
local DAMAGE_METER_FONTS = {
    [DAMAGE_METER_DEFAULT_FONT] = LText("Avant Garde"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\FiraSans Medium.ttf"] = LText("Fira Sans"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Ubuntu.ttf"] = LText("Ubuntu"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Poppins.ttf"] = LText("Poppins"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\font\\Tempesta Seven Condensed.ttf"] = LText("Tempesta Seven"),
}
local DAMAGE_METER_FONT_ORDER = {
    DAMAGE_METER_DEFAULT_FONT,
    "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\FiraSans Medium.ttf",
    "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Ubuntu.ttf",
    "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Poppins.ttf",
    "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Tempesta Seven Condensed.ttf",
}
local DAMAGE_METER_TEXTURES = {
    [DAMAGE_METER_DEFAULT_TEXTURE] = LText("Melli"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"] = LText("Melli Dark"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Clean.blp"] = LText("Statusbar Clean"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes_Thin.blp"] = LText("Statusbar Stripes Thin"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes.blp"] = LText("Statusbar Stripes"),
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\stripe-bar.tga"] = LText("Stripe Bar"),
}
local DAMAGE_METER_TEXTURE_ORDER = {
    DAMAGE_METER_DEFAULT_TEXTURE,
    "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
    "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Clean.blp",
    "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes_Thin.blp",
    "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes.blp",
    "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\stripe-bar.tga",
}
local DAMAGE_METER_ICON_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function SetDamageMeterPreviewIconShape(texture, shape)
    if not texture then
        return
    end

    local round = shape == "round"
    local mask = texture._kullThranRoundMask
    if round then
        if not mask then
            local parent = texture:GetParent()
            if not parent or not parent.CreateMaskTexture then
                return
            end
            mask = parent:CreateMaskTexture()
            mask:SetAllPoints(texture)
            mask:SetTexture(DAMAGE_METER_ICON_MASK)
            texture._kullThranRoundMask = mask
        end
        if not texture._kullThranRoundMaskAttached then
            local ok = pcall(texture.AddMaskTexture, texture, mask)
            texture._kullThranRoundMaskAttached = ok
        end
        mask:Show()
    elseif mask then
        if texture._kullThranRoundMaskAttached and texture.RemoveMaskTexture then
            pcall(texture.RemoveMaskTexture, texture, mask)
            texture._kullThranRoundMaskAttached = false
        end
        mask:Hide()
    end
end

local function GetDamageMeterFontValues()
    local values = BuildTrackerMediaChoices("font", DAMAGE_METER_FONTS, DAMAGE_METER_FONT_ORDER)
    return values
end

local function GetDamageMeterFontOrder()
    local _, order = BuildTrackerMediaChoices("font", DAMAGE_METER_FONTS, DAMAGE_METER_FONT_ORDER)
    return order
end

local function GetDamageMeterTextureValues()
    local values = BuildTrackerMediaChoices("statusbar", DAMAGE_METER_TEXTURES, DAMAGE_METER_TEXTURE_ORDER)
    return values
end

local function GetDamageMeterTextureOrder()
    local _, order = BuildTrackerMediaChoices("statusbar", DAMAGE_METER_TEXTURES, DAMAGE_METER_TEXTURE_ORDER)
    return order
end

local function ResolveEnhancementMediaPath(mediaType, value, fallback)
    local resolved = fallback
    if type(value) == "string" and value ~= "" then
        if value:sub(1, 10) == "Interface\\" then
            resolved = value
        else
            local LSM = LibStub("LibSharedMedia-3.0", true)
            local fetched = LSM and LSM:Fetch(mediaType, value, true)
            if fetched and fetched ~= "" then
                resolved = fetched
            end
        end
    end
    if mediaType == "font" and KT and KT.ResolveFontForLocale then
        return KT:ResolveFontForLocale(resolved, fallback)
    end
    return resolved
end
local function CreateDamageMeterLivePreview(container, config, startY)
    local y = startY or 0
    local previewWidth = math.max(150, tonumber(config and config.width) or 320)
    local previewHeight = math.max(72, tonumber(config and config.height) or 220)
    local preview = CreateFrame("Frame", nil, container, "BackdropTemplate")
    preview:SetPoint("TOP", container, "TOP", 0, -y)
    preview:SetSize(previewWidth, previewHeight + 26)
    KT:AddBackdrop(preview, 0.018, 0.022, 0.032, 0.98)
    do
        local r, g, b = CurrentAccentColor()
        KT:AddBorder(preview, r, g, b, 0.38)
    end

    local title = preview:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    title:SetPoint("TOPLEFT", preview, "TOPLEFT", 10, -8)
    title:SetText(LText("LIVE PREVIEW"))
    do
        local r, g, b = CurrentAccentColor()
        title:SetTextColor(r, g, b, 1)
    end

    local hint = preview:CreateFontString(nil, "OVERLAY")
    hint:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 9, "")
    hint:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -10, -9)
    hint:SetText(LText("Simulated combat data"))
    hint:SetTextColor(0.62, 0.64, 0.70, 1)

    local meter = CreateFrame("Frame", nil, preview, "BackdropTemplate")
    meter:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, -26)
    meter:SetSize(previewWidth, previewHeight)
    KT:AddBackdrop(meter, 0.012, 0.014, 0.02, 0.94)
    KT:AddBorder(meter, 1, 1, 1, 0.16)

    local modeText = meter:CreateFontString(nil, "OVERLAY")
    modeText:SetPoint("TOPLEFT", meter, "TOPLEFT", 7, -7)
    modeText:SetJustifyH("LEFT")

    local sessionText = meter:CreateFontString(nil, "OVERLAY")
    sessionText:SetPoint("TOPRIGHT", meter, "TOPRIGHT", -7, -7)
    sessionText:SetJustifyH("RIGHT")
    -- A real class/spec roster keeps the preview meaningful and uses the same
    -- class colours as the live meter instead of invented names and colours.
    local damageNames = { "Arms Warrior", "Fire Mage", "Assassination Rogue", "Marksmanship Hunter", "Havoc Demon Hunter", "Frost Death Knight", "Enhancement Shaman", "Retribution Paladin", "Windwalker Monk", "Devastation Evoker" }
    local damageIcons = { 132355, 135810, 136189, 132164, 1247264, 135771, 136048, 135920, 608951, 462245 }
    local damageClasses = { "WARRIOR", "MAGE", "ROGUE", "HUNTER", "DEMONHUNTER", "DEATHKNIGHT", "SHAMAN", "PALADIN", "MONK", "EVOKER" }
    local damageClassIDs = { 1, 8, 4, 3, 12, 6, 7, 2, 10, 13 }
    local damageSpecIndices = { 1, 2, 1, 2, 1, 2, 2, 3, 3, 1 }
    local healingNames = { "Holy Priest", "Restoration Shaman", "Restoration Druid", "Holy Paladin", "Mistweaver Monk", "Preservation Evoker" }
    local healingIcons = { 135940, 136048, 136041, 135920, 608951, 462245 }
    local healingClasses = { "PRIEST", "SHAMAN", "DRUID", "PALADIN", "MONK", "EVOKER" }
    local healingClassIDs = { 5, 7, 11, 2, 10, 13 }
    local healingSpecIndices = { 2, 3, 4, 1, 2, 2 }
    local rows = {}
    for index = 1, 40 do
        local row = CreateFrame("Frame", nil, meter)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetColorTexture(0.03, 0.035, 0.05, 0.92)
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetJustifyH("LEFT")
        row.value = row:CreateFontString(nil, "OVERLAY")
        row.value:SetJustifyH("RIGHT")
        row.rank = row:CreateFontString(nil, "OVERLAY")
        row.rank:SetJustifyH("LEFT")
        rows[index] = row
    end

    preview.previewTime = 0
    preview.updateElapsed = 0
    local function UpdatePreview()
        local cfg = config or {}
        local accentR, accentG, accentB = CurrentAccentColor()
        local headerSize = math.max(10, math.min(18, tonumber(cfg.headerFontSize) or 12))
        local fontSize = math.max(9, math.min(16, tonumber(cfg.fontSize) or 12))
        local rowHeight = math.max(16, math.min(26, tonumber(cfg.rowHeight) or 19))
        previewWidth = math.max(150, tonumber(cfg.width) or 320)
        previewHeight = math.max(72, tonumber(cfg.height) or 220)
        local availableWidth = math.max(280, (container:GetWidth() or previewWidth) - 20)
        preview:SetScale(math.min(1, availableWidth / previewWidth))
        preview:SetSize(previewWidth, previewHeight + 26)
        meter:SetSize(previewWidth, previewHeight)
        local previewAvailableHeight = math.max(1, previewHeight - 30 - 4 - 20)
        local shownRows = math.min(#rows, math.max(3, tonumber(cfg.maxRows) or 10), math.max(1, math.floor((previewAvailableHeight + 2) / (rowHeight + 2))))
        local mode = cfg.mode or "damageDone"
        local isHealing = mode == "healingDone" or mode == "hps" or mode == "absorbs"
        local previewNames = isHealing and healingNames or damageNames
        local previewIcons = isHealing and healingIcons or damageIcons
        local previewClasses = isHealing and healingClasses or damageClasses
        local previewClassIDs = isHealing and healingClassIDs or damageClassIDs
        local previewSpecIndices = isHealing and healingSpecIndices or damageSpecIndices
        local previewFont = ResolveEnhancementMediaPath("font", cfg.font, DAMAGE_METER_DEFAULT_FONT)
        local previewTexture = ResolveEnhancementMediaPath("statusbar", cfg.barTexture, DAMAGE_METER_DEFAULT_TEXTURE)
        local iconMode = cfg.iconMode
        if iconMode ~= "spec" and iconMode ~= "class" and iconMode ~= "none" then
            iconMode = cfg.showIcons == false and "none" or "spec"
        end
        local iconShape = cfg.iconShape == "round" and "round" or "square"
        local showIcons = cfg.showIcons ~= false and iconMode ~= "none"

        if meter.SetBackdropColor then
            local background = cfg.backgroundColor or { r = 0.012, g = 0.014, b = 0.02, a = 0.94 }
            meter:SetBackdropColor(background.r, background.g, background.b,
                cfg.showBackground == false and 0 or (background.a or 0.94))
        end
        SetPreviewBorderColor(meter, accentR, accentG, accentB, cfg.showBackground == false and 0.24 or 0.42)

        modeText:SetFont(previewFont, headerSize, cfg.fontOutline or "OUTLINE")
        sessionText:SetFont(previewFont, headerSize, cfg.fontOutline or "OUTLINE")
        modeText:SetText(LText(DAMAGE_PREVIEW_MODES[mode] or "Damage Done"))
        sessionText:SetText(cfg.session == "overall" and LText("Overall") or LText("Current"))
        modeText:SetTextColor(1, 1, 1, 1)
        sessionText:SetTextColor(0.74, 0.76, 0.82, 1)

        local meterWidth = previewWidth
        local rowWidth = meterWidth - 10
        local topOffset = 34
        for index, row in ipairs(rows) do
            local shown = index <= shownRows
            row:SetShown(shown)
            if shown then
                local rosterIndex = ((index - 1) % #previewNames) + 1
                local previewClass = previewClasses[rosterIndex]
                local previewName = previewNames[rosterIndex]
                local previewIcon = previewIcons[rosterIndex]
                local getSpecInfo = _G.GetSpecializationInfoForClassID
                local classID, specIndex = previewClassIDs[rosterIndex], previewSpecIndices[rosterIndex]
                if getSpecInfo and classID and specIndex then
                    local ok, _, localizedName, _, icon = _G.pcall(getSpecInfo, classID, specIndex)
                    if ok then
                        previewName = type(localizedName) == "string" and localizedName or previewName
                        previewIcon = type(icon) == "number" and icon or previewIcon
                    end
                end
                local iconGap = showIcons and (rowHeight + 1) or 0
                local fraction = math.max(0.14, math.min(1, (1.02 - (index * 0.14)) + (math.sin(preview.previewTime * 1.4 + index) * 0.035)))
                local barWidth = math.max(4, (rowWidth - iconGap) * fraction)
                local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[previewClass]
                local color = cfg.classColors == false and { accentR, accentG, accentB }
                    or { (classColor and classColor.r) or accentR, (classColor and classColor.g) or accentG, (classColor and classColor.b) or accentB }
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", meter, "TOPLEFT", 5, -(topOffset + ((index - 1) * (rowHeight + 2))))
                row:SetSize(rowWidth, rowHeight)
                row.background:ClearAllPoints()
                row.background:SetPoint("TOPLEFT", row, "TOPLEFT", iconGap, 0)
                row.background:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
                row.bar:ClearAllPoints()
                row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", iconGap, 0)
                row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", iconGap, 0)
                row.bar:SetWidth(barWidth)
                row.bar:SetTexture(previewTexture)
                row.bar:SetVertexColor(color[1], color[2], color[3], 0.72)

                if showIcons then
                    if iconMode == "class" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[previewClass] then
                        local coords = CLASS_ICON_TCOORDS[previewClass]
                        row.icon:SetTexture(CLASS_TEXTURE)
                        row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    else
                        row.icon:SetTexture(previewIcon)
                        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    end
                end
                SetDamageMeterPreviewIconShape(row.icon, iconShape)
                row.icon:SetShown(showIcons)
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.icon:SetSize(rowHeight, rowHeight)

                row.rank:SetFont(previewFont, fontSize, cfg.fontOutline or "OUTLINE")
                row.name:SetFont(previewFont, fontSize, cfg.fontOutline or "OUTLINE")
                row.value:SetFont(previewFont, fontSize, cfg.fontOutline or "OUTLINE")
                row.rank:ClearAllPoints()
                row.rank:SetPoint("LEFT", row, "LEFT", iconGap + 4, 0)
                row.rank:SetWidth(40)
                row.rank:SetText(index .. ".")
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", row.rank, "RIGHT", 1, 0)
                row.name:SetPoint("RIGHT", row.value, "LEFT", -5, 0)
                row.name:SetText(index == 1 and (cfg.customNick or previewName) or previewName)
                row.value:ClearAllPoints()
                row.value:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                row.value:SetWidth(cfg.showPercentages == true and 88 or 64)
                local amount = math.floor((1284000 * fraction) + (preview.previewTime * 1750))
                if cfg.showPercentages == true then
                    row.value:SetText(string.format("%.1f%%  %.1fk", fraction * 100, amount / 1000))
                else
                    row.value:SetText(string.format("%.1fk", amount / 1000))
                end
                local textColor = cfg.textColor or { r = 1, g = 1, b = 1, a = 1 }
                row.rank:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
                row.name:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
                row.value:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a or 1)
            end
        end
    end

    MakeEnhancementPreviewClickable(preview, "damage")
    preview:SetScript("OnUpdate", function(self, elapsed)
        self.updateElapsed = self.updateElapsed + elapsed
        self.previewTime = self.previewTime + elapsed
        if self.updateElapsed < 0.05 then
            return
        end
        self.updateElapsed = 0
        UpdatePreview()
    end)
    UpdatePreview()
    return preview, previewHeight + 26
end

local selectedDamageMeterWindow = "main"

local function BuildDamageMeterBlock(container, W, db)
    db.damageMeter = db.damageMeter or {}
    db.damageMeter.windows = db.damageMeter.windows or {}

    local windowLabels = { main = LText("Window 1 - Main") }
    local windowOrder = { "main" }
    for index in ipairs(db.damageMeter.windows) do
        local key = "window_" .. index
        windowLabels[key] = string.format("%s %d", LText("Window"), index + 1)
        windowOrder[#windowOrder + 1] = key
    end

    local selectedIndex = tonumber(selectedDamageMeterWindow:match("^window_(%d+)$")) or 0
    local damageMeterConfig = selectedIndex == 0 and db.damageMeter or db.damageMeter.windows[selectedIndex]
    if not damageMeterConfig then
        selectedDamageMeterWindow = "main"
        selectedIndex = 0
        damageMeterConfig = db.damageMeter
    end
    local function ClearSelectedSession()
        local frame = selectedIndex == 0 and Mod.damageMeterFrame
            or (Mod.additionalDamageMeterFrames and Mod.additionalDamageMeterFrames[selectedIndex])
        if frame then
            frame.selectedSessionID = nil
            frame.selectedSessionLabel = nil
            frame.selectedSessionIcon = nil
        end
    end

    local y, h = 0, 0
    _, h = CreateDamageMeterLivePreview(container, damageMeterConfig, y)
    y = y + h

    _, h = W:Dropdown(container, LText("Configure Window"), -y,
        windowLabels,
        function() return selectedDamageMeterWindow end,
        function(v)
            selectedDamageMeterWindow = v or "main"
            Refresh({ rebuild = true })
        end,
        windowOrder)
    y = y + h

    _, h = W:Button(container, LText("Create New Window"), -y, function()
        if Mod and Mod.CreateAdditionalDamageMeterWindow then
            local frame = Mod:CreateAdditionalDamageMeterWindow(Mod:GetDamageMeterFrame())
            if frame and frame.additionalDamageMeterIndex then
                selectedDamageMeterWindow = "window_" .. frame.additionalDamageMeterIndex
            end
        end
        Refresh({ rebuild = true })
    end)
    y = y + h

    y = AddToggleList(container, W, {
        { label = LText("Enable This Window"), get = function() return damageMeterConfig.enabled == true end, set = function(v) damageMeterConfig.enabled = v and true or false end },
        { label = LText("Lock Window"), get = function() return damageMeterConfig.locked == true end, set = function(v) damageMeterConfig.locked = v and true or false end },
        { label = LText("Show only in combat"), get = function() return damageMeterConfig.showOnlyInCombat == true end, set = function(v) damageMeterConfig.showOnlyInCombat = v and true or false end },
        { label = LText("Show Background"), get = function() return damageMeterConfig.showBackground ~= false end, set = function(v) damageMeterConfig.showBackground = v and true or false end },
        { label = LText("Auto-fit Window Height"), get = function() return damageMeterConfig.autoHeight ~= false end, set = function(v) damageMeterConfig.autoHeight = v and true or false end },
        { label = LText("Class Colored Bars"), get = function() return damageMeterConfig.classColors ~= false end, set = function(v) damageMeterConfig.classColors = v and true or false end },
        { label = LText("Show Percentages"), get = function() return damageMeterConfig.showPercentages == true end, set = function(v) damageMeterConfig.showPercentages = v and true or false end },
        { label = LText("Pin Player At Bottom"), get = function() return damageMeterConfig.alwaysShowPlayer == true end, set = function(v)
            damageMeterConfig.alwaysShowPlayer = v and true or false
            if Mod and Mod.ResetDamageMeterScroll then
                Mod:ResetDamageMeterScroll()
            end
        end },
    }, y)

    _, h = W:Dropdown(container, LText("Player Icon"), -y,
        DAMAGE_ICON_MODES,
        function()
            local mode = damageMeterConfig.iconMode
            if mode == "spec" or mode == "class" or mode == "none" then
                return mode
            end
            return damageMeterConfig.showIcons == false and "none" or "spec"
        end,
        function(v)
            damageMeterConfig.iconMode = v
            damageMeterConfig.showIcons = v ~= "none"
            Refresh()
        end,
        { "spec", "class", "none" })
    y = y + h

    _, h = W:Dropdown(container, LText("Icon Shape"), -y,
        DAMAGE_ICON_SHAPES,
        function()
            return damageMeterConfig.iconShape == "round" and "round" or "square"
        end,
        function(v)
            damageMeterConfig.iconShape = v == "round" and "round" or "square"
            Refresh()
        end,
        { "square", "round" })
    y = y + h

    _, h = W:Dropdown(container, LText("Damage Meter Font"), -y,
        GetDamageMeterFontValues,
        function() return damageMeterConfig.font or DAMAGE_METER_DEFAULT_FONT end,
        function(v) damageMeterConfig.font = v; Refresh() end,
        GetDamageMeterFontOrder, "font")
    y = y + h

    _, h = W:Dropdown(container, LText("Bar Texture"), -y,
        GetDamageMeterTextureValues,
        function() return damageMeterConfig.barTexture or DAMAGE_METER_DEFAULT_TEXTURE end,
        function(v) damageMeterConfig.barTexture = v; Refresh() end,
        GetDamageMeterTextureOrder, "texture")
    y = y + h

    local customNickH
    _, customNickH = W:Input(container, LText("Custom Nick"), -y,
        function() return damageMeterConfig.customNick or "" end,
        function(v) damageMeterConfig.customNick = (type(v) == "string" and strtrim(v) ~= "") and strtrim(v) or nil; Refresh() end)
    y = y + customNickH

    local modeLabels = {}
    local modeOrder = {}
    local damageMeterTypes = _G.Enum and _G.Enum.DamageMeterType
    local availableModes = {
        { key = "damageDone", enumKey = "DamageDone", label = LText("Damage Done") },
        { key = "dps", enumKey = "Dps", label = LText("DPS") },
        { key = "damageTaken", enumKey = "DamageTaken", label = LText("Damage Taken") },
        { key = "enemyDamageTaken", enumKey = "EnemyDamageTaken", label = LText("Enemy Damage Taken") },
        { key = "avoidableDamageTaken", enumKey = "AvoidableDamageTaken", label = LText("Avoidable Damage Taken") },
        { key = "healingDone", enumKey = "HealingDone", label = LText("Healing Done") },
        { key = "hps", enumKey = "Hps", label = LText("HPS") },
        { key = "absorbs", enumKey = "Absorbs", label = LText("Absorbs") },
        { key = "interrupts", enumKey = "Interrupts", label = LText("Interrupts") },
        { key = "dispels", enumKey = "Dispels", label = LText("Dispels") },
        { key = "deaths", enumKey = "Deaths", label = LText("Deaths") },
    }
    for _, mode in ipairs(availableModes) do
        if damageMeterTypes and damageMeterTypes[mode.enumKey] ~= nil then
            modeLabels[mode.key] = LText(mode.label)
            modeOrder[#modeOrder + 1] = mode.key
        end
    end
    if #modeOrder == 0 then
        modeLabels.damageDone = LText("Damage Done")
        modeOrder[1] = "damageDone"
    end

    _, h = W:Dropdown(container, LText("Mode"), -y,
        modeLabels,
        function() return damageMeterConfig.mode or "damageDone" end,
        function(v) damageMeterConfig.mode = v; Refresh() end,
        modeOrder)
    y = y + h

    _, h = W:Dropdown(container, LText("Session"), -y,
        {
            current = LText("Current"),
            overall = LText("Overall"),
        },
        function() return damageMeterConfig.session or "current" end,
        function(v)
            damageMeterConfig.session = v
            ClearSelectedSession()
            Refresh()
        end,
        { "current", "overall" })
    y = y + h

    _, h = W:Slider(container, LText("Damage Bar Width"), -y,
        function() return damageMeterConfig.width or 320 end,
        function(v) damageMeterConfig.width = v; Refresh() end,
        150, 720, 5)
    y = y + h

    _, h = W:Slider(container, LText("Window Height"), -y,
        function() return damageMeterConfig.height or 220 end,
        function(v) damageMeterConfig.height = v; damageMeterConfig.autoHeight = false; Refresh() end,
        72, 700, 2)
    y = y + h

    _, h = W:Slider(container, LText("Damage Bar Height"), -y,
        function() return damageMeterConfig.rowHeight or 19 end,
        function(v) damageMeterConfig.rowHeight = v; Refresh() end,
        14, 32, 1)
    y = y + h

    _, h = W:Slider(container, LText("Maximum Rows"), -y,
        function() return damageMeterConfig.maxRows or 10 end,
        function(v) damageMeterConfig.maxRows = v; Refresh() end,
        3, 40, 1)
    y = y + h

    _, h = W:Slider(container, LText("Font Size"), -y,
        function() return damageMeterConfig.fontSize or 12 end,
        function(v) damageMeterConfig.fontSize = v; Refresh() end,
        9, 16, 1)
    y = y + h

    _, h = W:Slider(container, LText("Header Font Size"), -y,
        function() return damageMeterConfig.headerFontSize or 12 end,
        function(v) damageMeterConfig.headerFontSize = v; Refresh() end,
        10, 18, 1)
    y = y + h

    _, h = W:Button(container, LText("Preview Damage Meter"), -y, function()
        damageMeterConfig.enabled = true
        if Mod and Mod.PreviewDamageMeter then
            Mod:PreviewDamageMeter(selectedIndex)
        end
        Refresh()
    end)
    y = y + h

    _, h = W:Label(container,
        LText("Uses Blizzard combat-session data."),
        -y, 10)
    y = y + h

    return y
end

local function BuildEquipmentReminderBlock(container, W, db)
    local y, h = AddToggleList(container, W, {
        { label = LText("Enable Equipment Reminder"), get = function() return db.equipmentReminder.enabled end, set = function(v) db.equipmentReminder.enabled = v end, refreshOpts = { rebuild = true } },
        { label = LText("Show on instance entry"), get = function() return db.equipmentReminder.showOnInstance end, set = function(v) db.equipmentReminder.showOnInstance = v end },
        { label = LText("Show on ready check"), get = function() return db.equipmentReminder.showOnReadyCheck end, set = function(v) db.equipmentReminder.showOnReadyCheck = v end },
        { label = LText("Enable enchant checker"), get = function() return db.equipmentReminder.enchantCheck end, set = function(v) db.equipmentReminder.enchantCheck = v end, refreshOpts = { rebuild = true } },
        { label = LText("Use same enchant rules for all specs"), get = function() return db.equipmentReminder.useAllSpecs end, set = function(v) db.equipmentReminder.useAllSpecs = v end, refreshOpts = { rebuild = true } },
    })

    _, h = W:Dropdown(container, LText("Equipment set"), -y,
        function() return Mod:GetEquipmentReminderSetChoices() end,
        function() return Mod:GetSelectedEquipmentReminderSetID() end,
        function(v)
            Mod:SetSelectedEquipmentReminderSetID(v)
            Refresh()
        end)
    y = y + h

    _, h = W:Label(container, LText("Choose which equipment set should be checked and shown in the reminder preview. Leave it on Current Equipped Gear if you only want to inspect what you have equipped now."), -y, 10)
    y = y + h

    _, h = W:Slider(container, LText("Auto-hide delay"), -y,
        function() return db.equipmentReminder.autoHideDelay or 10 end,
        function(v) db.equipmentReminder.autoHideDelay = v; Refresh() end,
        0, 30, 1)
    y = y + h

    _, h = W:Slider(container, LText("Icon size"), -y,
        function() return db.equipmentReminder.iconSize or 40 end,
        function(v) db.equipmentReminder.iconSize = v; Refresh({ rebuild = true }) end,
        32, 64, 2)
    y = y + h

    _, h = W:Button(container, LText("Preview Equipment Reminder"), -y, function()
        Mod:ShowEquipmentReminder()
    end)
    y = y + h

    _, h = W:Button(container, LText("Capture Current Enchants"), -y, function()
        Mod:CaptureEquipmentReminderEnchants()
        Refresh({ rebuild = true })
    end)
    y = y + h

    _, h = W:Button(container, LText("Clear Captured Enchants"), -y, function()
        Mod:ClearEquipmentReminderEnchants()
        Refresh({ rebuild = true })
    end)
    y = y + h

    return y
end

local function BuildItemsLootBlock(container, W, db)
    local y, h = AddToggleList(container, W, {
        { label = LText("Faster Auto Loot"), get = function() return db.gameOptions.fasterAutoLoot end, set = function(v) db.gameOptions.fasterAutoLoot = v end },
        { label = LText("Suppress Loot Warnings"), get = function() return db.gameOptions.disableLootWarnings end, set = function(v) db.gameOptions.disableLootWarnings = v end },
        { label = LText("Easy Item Destroy"), get = function() return db.gameOptions.easyItemDestroy end, set = function(v) db.gameOptions.easyItemDestroy = v end },
        { label = LText("Auto Insert Keystone"), get = function() return db.gameOptions.autoInsertKeystone end, set = function(v) db.gameOptions.autoInsertKeystone = v end },
        { label = LText("AH Current Expansion"), get = function() return db.gameOptions.ahCurrentExpansion end, set = function(v) db.gameOptions.ahCurrentExpansion = v end },
    })

    _, h = W:Slider(container, LText("Auto loot delay"), -y,
        function() return db.gameOptions.autoLootDelay or 0.1 end,
        function(v) db.gameOptions.autoLootDelay = v; Refresh() end,
        0.0, 0.3, 0.1)
    y = y + h

    return y
end

local function BuildDeathBlock(container, W, db)
    local y, h = AddToggleList(container, W, {
        { label = LText("Do not release spirit by accident"), get = function() return db.automation.deathReleaseProtection end, set = function(v) db.automation.deathReleaseProtection = v end },
        { label = LText("Repair automatically"), get = function() return db.automation.autoRepair end, set = function(v) db.automation.autoRepair = v end },
        { label = LText("Use guild funds"), get = function() return db.automation.repairUseGuildFunds end, set = function(v) db.automation.repairUseGuildFunds = v end },
        { label = LText("Repair summary in chat"), get = function() return db.automation.repairShowSummary end, set = function(v) db.automation.repairShowSummary = v end },
        { label = LText("Durability Warning"), get = function() return db.automation.durabilityWarning end, set = function(v) db.automation.durabilityWarning = v end, refreshOpts = { rebuild = true } },
    })

    _, h = W:Slider(container, LText("Warning Threshold"), -y,
        function() return db.automation.durabilityThreshold or 30 end,
        function(v) db.automation.durabilityThreshold = v; Refresh() end,
        10, 60, 1)
    y = y + h

    return y
end

local function BuildAutomationBlock(container, W, db)
    return AddToggleList(container, W, {
        { label = LText("Automate quests"), get = function() return db.automation.autoQuests end, set = function(v) db.automation.autoQuests = v end },
        { label = LText("Automate gossip"), get = function() return db.automation.autoGossip end, set = function(v) db.automation.autoGossip = v end },
        { label = LText("Accept summon"), get = function() return db.automation.acceptSummon end, set = function(v) db.automation.acceptSummon = v end },
        { label = LText("Accept resurrection"), get = function() return db.automation.acceptResurrection end, set = function(v) db.automation.acceptResurrection = v end },
        { label = LText("Release in PvP"), get = function() return db.automation.releaseInPvP end, set = function(v) db.automation.releaseInPvP = v end },
    })
end

local function BuildLGFAutomationBlock(container, W, db)
    db.automation.lfgRoles = db.automation.lfgRoles or {}

    local y, h = AddToggleList(container, W, {
        { label = LText("Auto-confirm LFG role check"), get = function() return db.automation.skipLFGRoleCheck == true end, set = function(v) db.automation.skipLFGRoleCheck = v and true or false end },
    })

    _, h = W:Label(container, LText("Automatically confirms the LFG role check using the roles selected below. Hold Ctrl to skip it once."), -y, 10)
    y = y + h + 4

    _, h = W:SectionHeader(container, LText("Roles to select automatically"), -y)
    y = y + h

    y = AddToggleList(container, W, {
        { label = LText("Tank"), get = function() return db.automation.lfgRoles.tank == true end, set = function(v) db.automation.lfgRoles.tank = v and true or false end },
        { label = LText("Healer"), get = function() return db.automation.lfgRoles.healer == true end, set = function(v) db.automation.lfgRoles.healer = v and true or false end },
        { label = LText("Damage (DPS)"), get = function() return db.automation.lfgRoles.damager == true end, set = function(v) db.automation.lfgRoles.damager = v and true or false end },
    }, y)

    _, h = W:Label(container, LText("Select at least one role. The game will ignore roles your character cannot perform."), -y, 10)
    y = y + h

    return y
end

local function BuildBlocksBlock(container, W, db)
    return AddToggleList(container, W, {
        { label = LText("Block duels"), get = function() return db.blocks.blockDuels end, set = function(v) db.blocks.blockDuels = v end },
        { label = LText("Block pet battle duels"), get = function() return db.blocks.blockPetBattleDuels end, set = function(v) db.blocks.blockPetBattleDuels = v end },
        { label = LText("Block party invites"), get = function() return db.blocks.blockPartyInvites end, set = function(v) db.blocks.blockPartyInvites = v end },
        { label = LText("Block requested invites"), get = function() return db.blocks.blockRequestedInvites end, set = function(v) db.blocks.blockRequestedInvites = v end },
        { label = LText("Block friend requests"), get = function() return db.blocks.blockFriendRequests end, set = function(v) db.blocks.blockFriendRequests = v end },
        { label = LText("Block shared quests"), get = function() return db.blocks.blockSharedQuests end, set = function(v) db.blocks.blockSharedQuests = v end },
    })
end

local function BuildGroupsBlock(container, W, db)
    local y, h = AddToggleList(container, W, {
        { label = LText("Party from friends"), get = function() return db.groups.partyFromFriends end, set = function(v) db.groups.partyFromFriends = v end },
        { label = LText("Sync from friends"), get = function() return db.groups.syncFromFriends end, set = function(v) db.groups.syncFromFriends = v end },
        { label = LText("Queue from friends"), get = function() return db.groups.queueFromFriends end, set = function(v) db.groups.queueFromFriends = v end },
        { label = LText("Invite from whispers"), get = function() return db.groups.inviteFromWhispers end, set = function(v) db.groups.inviteFromWhispers = v end },
        { label = LText("Persistent LFG note"), get = function() return db.groups.persistentLFGNoteEnabled end, set = function(v) db.groups.persistentLFGNoteEnabled = v end },
        { label = LText("Whispers only from friends"), get = function() return db.groups.whisperFriendsOnly end, set = function(v) db.groups.whisperFriendsOnly = v end },
        { label = LText("Treat guild as friends"), get = function() return db.groups.guildAsFriends end, set = function(v) db.groups.guildAsFriends = v end },
        { label = LText("Treat communities as friends"), get = function() return db.groups.communitiesAsFriends end, set = function(v) db.groups.communitiesAsFriends = v end },
    })

    _, h = W:Input(container, LText("Whisper keyword"), -y,
        function() return db.groups.whisperKeyword or "inv" end,
        function(v)
            local trimmed = (v and strtrim(v)) or ""
            db.groups.whisperKeyword = trimmed ~= "" and trimmed or "inv"
            Refresh()
        end)
    y = y + h

    _, h = W:Input(container, LText("Persistent LFG note text"), -y,
        function()
            if Mod and Mod.GetPersistentLFGNote then
                return Mod:GetPersistentLFGNote()
            end
            return db.groups.persistentLFGNote or ""
        end,
        function(v)
            if Mod and Mod.SetPersistentLFGNote then
                Mod:SetPersistentLFGNote(v)
            else
                db.groups.persistentLFGNote = (v and strtrim(v)) or ""
                db.groups.persistentLFGNoteBackup = db.groups.persistentLFGNote
                db.groups.persistentLFGNoteEnabled = db.groups.persistentLFGNote ~= ""
            end
            if Mod and Mod.ApplyPersistentLFGNote then
                Mod:ApplyPersistentLFGNote()
            end
        end,
        { commitOnTextChanged = true })
    y = y + h

    return y
end

local function BuildSocialBlock(container, W, db)
    return AddToggleList(container, W, {
        { label = LText("Enhanced Friend List"), get = function() return db.social.enhancedFriendList ~= false end, set = function(v) db.social.enhancedFriendList = v and true or false end },
    })
end

local function BuildUIClutterBlock(container, W, db)
    return AddToggleList(container, W, {
        { label = LText("Hide Alerts"), get = function() return db.visibility.hideAlerts end, set = function(v) db.visibility.hideAlerts = v end },
        { label = LText("Hide Talking Head"), get = function() return db.visibility.hideTalkingFrame end, set = function(v) db.visibility.hideTalkingFrame = v end },
        { label = LText("Hide Event Toasts"), get = function() return db.visibility.hideEventToasts end, set = function(v) db.visibility.hideEventToasts = v end },
        { label = LText("Hide Zone Text"), get = function() return db.visibility.hideZoneText end, set = function(v) db.visibility.hideZoneText = v end },
        { label = LText("Auto-confirm LFG application"), get = function() return db.visibility.skipQueueConfirmation end, set = function(v) db.visibility.skipQueueConfirmation = v end },
        { label = LText("Hide Minimap Icon"), get = function() return db.visibility.hideMinimapIcon end, set = function(v) db.visibility.hideMinimapIcon = v end, refreshOpts = { rebuild = true } },
    })
end

local function BuildTextSizeBlock(container, W, db)
    local y, h = AddToggleList(container, W, {
        { label = LText("Resize mail text"), get = function() return db.textSize.resizeMailText end, set = function(v) db.textSize.resizeMailText = v end },
        { label = LText("Resize quest text"), get = function() return db.textSize.resizeQuestText end, set = function(v) db.textSize.resizeQuestText = v end },
    })

    _, h = W:Slider(container, LText("Mail font size"), -y,
        function() return db.textSize.mailFontSize or 16 end,
        function(v) db.textSize.mailFontSize = v; Refresh() end,
        10, 26, 1)
    y = y + h

    _, h = W:Slider(container, LText("Quest font size"), -y,
        function() return db.textSize.questFontSize or 14 end,
        function(v) db.textSize.questFontSize = v; Refresh() end,
        10, 26, 1)
    y = y + h

    return y
end

local function BuildGraphicsSoundBlock(container, W, db)
    local y, h = AddToggleList(container, W, {
        { label = LText("Disable screen glow"), get = function() return db.graphicsSound.disableScreenGlow end, set = function(v) db.graphicsSound.disableScreenGlow = v end },
        { label = LText("Disable screen effects"), get = function() return db.graphicsSound.disableScreenEffects end, set = function(v) db.graphicsSound.disableScreenEffects = v end },
        { label = LText("Set weather density"), get = function() return db.graphicsSound.setWeatherDensity end, set = function(v) db.graphicsSound.setWeatherDensity = v end },
        { label = LText("Max camera zoom"), get = function() return db.graphicsSound.maxCameraZoom end, set = function(v) db.graphicsSound.maxCameraZoom = v end },
        { label = LText("Keep audio synced"), get = function() return db.graphicsSound.keepAudioSynced end, set = function(v) db.graphicsSound.keepAudioSynced = v end },
    })

    _, h = W:Slider(container, LText("Weather density"), -y,
        function() return db.graphicsSound.weatherDensity or 0 end,
        function(v) db.graphicsSound.weatherDensity = v; Refresh() end,
        0, 3, 1)
    y = y + h

    return y
end

local function BuildLegacyGameOptionsBlock(container, W, db)
    return AddToggleList(container, W, {
        { label = LText("Remove raid restrictions"), get = function() return db.gameOptions.removeRaidRestrictions end, set = function(v) db.gameOptions.removeRaidRestrictions = v end },
        { label = LText("Faster movie skip"), get = function() return db.gameOptions.fasterMovieSkip end, set = function(v) db.gameOptions.fasterMovieSkip = v end },
        { label = LText("Combat plates"), get = function() return db.gameOptions.combatPlates end, set = function(v) db.gameOptions.combatPlates = v end },
    })
end

local function BuildSystemPresetBlock(container, W, startY)
    local originY = startY or 0
    local y, h = originY, 0

    _, h = W:Button(container, LText("Optimal FPS Settings"), -y, function()
        Mod:ApplyOptimalFPSSettings()
        Refresh({ rebuild = true })
    end)
    y = y + h

    _, h = W:Button(container, LText("Revert Settings"), -y, function()
        Mod:RestoreOptimalFPSSettings()
        Refresh({ rebuild = true })
    end)
    y = y + h

    return y - originY
end

local function BuildSpellQueueBlock(container, W, db, startY)
    local originY = startY or 0
    local y, h = originY, 0

    _, h = W:Slider(container, LText("Spell Queue Window (ms)"), -y,
        function() return db.optimizations.spellQueueWindow or 150 end,
        function(v) Mod:SetSpellQueueWindow(v); Refresh() end,
        50, 500, 1)
    y = y + h

    _, h = W:Label(container, LText("Recommended: 100-400ms. Lower is more responsive; higher is more tolerant to latency."), -y, 10)
    y = y + h

    return y - originY
end

local function BuildDiagnosticsBlock(container, W, startY)
    local originY = startY or 0
    local y, h = originY, 0

    _, h = W:Toggle(container, LText("AddOn Profiler"), -y,
        function()
            return Mod:IsAddonProfilerEnabled()
        end,
        function(value)
            Mod:SetAddonProfilerEnabled(value and true or false)
            Refresh({ rebuild = true })
        end)
    y = y + h

    _, h = W:Label(container, LText("Enables or disables script profiling. Reload the UI after changing it so the new state is fully applied."), -y, 10)
    y = y + h

    return y - originY
end

local function BuildSystemPresetSection(container, W, db)
    local y, h = 0, 0

    _, h = W:Label(container, LText("Use this block for one-click actions before touching individual settings."), -y, 10)
    y = y + h

    y = y + BuildSystemPresetBlock(container, W, y)

    _, h = W:Label(container, LText("Backups are stored automatically when you apply the preset, so you can revert afterwards."), -y, 10)
    y = y + h + 4

    _, h = W:SectionHeader(container, LText("Diagnostics"), -y)
    y = y + h
    y = y + BuildDiagnosticsBlock(container, W, y)

    return y
end

local function BuildSystemGraphicsSection(container, W, db)
    local y, h = 0, 0

    _, h = W:SectionHeader(container, LText("Render & Display"), -y)
    y = y + h
    y = y + AddOptimizationSettingList(container, W, Mod:GetOptimizationSettingsForCategory("render"), y)

    _, h = W:SectionHeader(container, LText("Graphics Quality"), -y)
    y = y + h
    y = y + AddOptimizationSettingList(container, W, Mod:GetOptimizationSettingsForCategory("graphics"), y)

    _, h = W:SectionHeader(container, LText("View Distance & Detail"), -y)
    y = y + h
    y = y + AddOptimizationSettingList(container, W, Mod:GetOptimizationSettingsForCategory("detail"), y)

    _, h = W:SectionHeader(container, LText("Advanced Settings"), -y)
    y = y + h
    y = y + AddOptimizationSettingList(container, W, Mod:GetOptimizationSettingsForCategory("advanced"), y)

    _, h = W:SectionHeader(container, LText("Post Processing"), -y)
    y = y + h
    y = y + AddOptimizationSettingList(container, W, Mod:GetOptimizationSettingsForCategory("post"), y)

    return y
end

local function BuildSystemPerformanceSection(container, W, db)
    local y, h = 0, 0

    _, h = W:SectionHeader(container, LText("FPS Limits"), -y)
    y = y + h
    y = y + AddOptimizationSettingList(container, W, Mod:GetOptimizationSettingsForCategory("fps"), y)

    _, h = W:SectionHeader(container, LText("Spell Queue Window"), -y)
    y = y + h
    y = y + BuildSpellQueueBlock(container, W, db, y)

    return y
end

local function BuildSystemDiagnosticsSection(container, W, db)
    local y, h = 0, 0

    _, h = W:Label(container, LText("Keep this section collapsed unless you are actively testing performance."), -y, 10)
    y = y + h + 2

    _, h = W:SectionHeader(container, LText("Real-Time Monitor"), -y)
    y = y + h
    y = y + AddMonitorBlock(container, W, y)

    return y
end

local function AddAccordionSection(parent, key, title, buildFn, defaultOpen, W, db, yOffset)
    local accentR, accentG, accentB = CurrentAccentColor()
    local isOpen = GetSystemSectionState(key, defaultOpen)

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", 0, yOffset)
    frame:SetPoint("TOPRIGHT", 0, yOffset)

    local header = CreateFrame("Button", nil, frame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(36)
    KT:AddBackdrop(header, 0.05, 0.06, 0.08, 0.98)
    KT:AddBorder(header, accentR, accentG, accentB, isOpen and 0.75 or 0.38)

    local headerFill = header:CreateTexture(nil, "BACKGROUND")
    headerFill:SetAllPoints()
    headerFill:SetColorTexture(accentR, accentG, accentB, isOpen and 0.14 or 0.06)

    local accentBar = header:CreateTexture(nil, "ARTWORK")
    accentBar:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    accentBar:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    accentBar:SetWidth(4)
    accentBar:SetColorTexture(accentR, accentG, accentB, isOpen and 1 or 0.45)

    local titleText = header:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    titleText:SetPoint("LEFT", 14, 0)
    titleText:SetPoint("RIGHT", -30, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetText(LText(title))
    titleText:SetTextColor(1, 1, 1, 1)

    local arrow = header:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    arrow:SetPoint("RIGHT", -12, 0)
    arrow:SetText(isOpen and "-" or "+")
    arrow:SetTextColor(accentR, accentG, accentB, 1)

    local totalHeight = header:GetHeight()

    if isOpen then
        local contentShell = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        contentShell:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
        contentShell:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -6)
        KT:AddBackdrop(contentShell, 0.025, 0.03, 0.045, 0.94)
        KT:AddBorder(contentShell, accentR, accentG, accentB, 0.24)

        local content = CreateFrame("Frame", nil, contentShell)
        content:SetPoint("TOPLEFT", contentShell, "TOPLEFT", 8, -8)
        content:SetWidth(parent:GetWidth() - 16)

        local contentHeight = buildFn(content, W, db) or 0
        content:SetHeight(contentHeight)
        contentShell:SetHeight(contentHeight + 16)
        totalHeight = totalHeight + contentShell:GetHeight() + 6
    end

    frame:SetHeight(totalHeight)
    header:SetScript("OnClick", function()
        SetSystemSectionState(key, not isOpen)
        Refresh({ rebuild = true })
    end)

    return frame, totalHeight
end

local function BuildSystemAccordion(parent, W, db, startY)
    local y = startY
    local h

    _, h = AddAccordionSection(parent, "system_actions", LText("System Optimizations: Presets"), BuildSystemPresetSection, true, W, db, -y)
    y = y + h + 10
    _, h = AddAccordionSection(parent, "system_graphics", LText("Graphics Quality"), BuildSystemGraphicsSection, false, W, db, -y)
    y = y + h + 10
    _, h = AddAccordionSection(parent, "system_performance", LText("FPS Limits"), BuildSystemPerformanceSection, false, W, db, -y)
    y = y + h + 10
    _, h = AddAccordionSection(parent, "system_monitor", LText("Diagnostics"), BuildSystemDiagnosticsSection, false, W, db, -y)
    y = y + h

    return y
end

local function BuildMythicPlusHistoryBlock(container, W, db)
    local history = Mod.MythicPlusHistory
    if not history then return 0 end
    local config = history:Config()
    local y, h = 0, 0
    _, h = W:Toggle(container, LText("Record Mythic+ history"), -y,
        function() return config.enabled == true end,
        function(value)
            config.enabled = value and true or false
            if config.enabled then
                KT:Print(LText("Mythic+ History will initialize after /reload."))
            end
        end)
    y = y + h
    _, h = W:Toggle(container, LText("Open history after completing a key"), -y,
        function() return config.autoShow ~= false end,
        function(value) config.autoShow = value and true or false end)
    y = y + h
    _, h = W:Dropdown(container, LText("History Font"), -y,
        function() return BuildTrackerMediaChoices("font") end,
        function() return config.font or (KT.db.profile.globalFont and KT.db.profile.globalFont.font) or "Avant Garde" end,
        function(value)
            config.font = value
            if history.RefreshStyle then history:RefreshStyle() end
        end,
        function() local _, order = BuildTrackerMediaChoices("font"); return order end,
        "font")
    y = y + h
    _, h = W:Button(container, LText("Open Mythic+ history"), -y,
        function() if Mod.ShowMythicPlusHistory then Mod:ShowMythicPlusHistory() end end)
    y = y + h
    _, h = W:Button(container, LText("Preview history (not saved)"), -y,
        function() if history.Preview then history:Preview() end end)
    y = y + h
    _, h = W:Label(container, LText("Stores 50 keys per character and imports available Blizzard history. Imported keys have no historical gear or party data. Open with /ktkeys."), -y, 11)
    return y + h + 6
end

local CATEGORY_SECTIONS = {
    instance = {
        { column = "left", title = LText("Mythic+ History"), build = BuildMythicPlusHistoryBlock },
        { column = "left", title = LText("Combat Res"), build = BuildCombatRezBlock },
        { column = "right", title = LText("Equipment Reminder"), build = BuildEquipmentReminderBlock },
        { column = "left", title = LText("Items / Loot"), build = BuildItemsLootBlock },
        { column = "right", title = LText("Death / Durability / Repair"), build = BuildDeathBlock },
    },
    damage = {
        { column = "left", title = LText("Damage Meter"), build = BuildDamageMeterBlock },
    },
    timer = {
        { column = "left", title = LText("Mythic+ Keystones Tracker"), build = BuildMythicPlusTrackerBlock },
    },
    automation = {
        { column = "left", title = LText("Automation"), build = BuildAutomationBlock },
        { column = "right", title = LText("LFG Automation"), build = BuildLGFAutomationBlock },
        { column = "right", title = LText("Groups"), build = BuildGroupsBlock },
        { column = "left", title = LText("Blocks"), build = BuildBlocksBlock },
        { column = "right", title = LText("Social"), build = BuildSocialBlock },
    },
    interface = {
        { column = "left", title = LText("UI Clutter"), build = BuildUIClutterBlock },
        { column = "right", title = LText("Text Size"), build = BuildTextSizeBlock },
        { column = "right", title = LText("Combat Status Text"), build = BuildCombatTextBlock },
        { column = "left", title = LText("Combat Timer"), build = BuildCombatTimerBlock },
        { column = "left", title = LText("Graphics and Sound"), build = BuildGraphicsSoundBlock },
        { column = "right", title = LText("Legacy Game Options"), build = BuildLegacyGameOptionsBlock },
    },
    system = {
    },
}

local function BuildActiveCategory(parent, W, db)
    local activeKey = GetActiveCategory()
    local meta = CATEGORY_META[activeKey] or CATEGORY_META.instance
    local y, h = 0, 0

    _, h = W:SectionHeader(parent, LText(meta.title), 0)
    y = y + h

    _, h = W:Label(parent, LText(meta.description), -y, 11)
    y = y + h + 6

    if activeKey == "system" then
        return BuildSystemAccordion(parent, W, db, y)
    end

    if (activeKey == "damage" or activeKey == "timer") and CreateOptionBlock and FinalizeOptionBlock then
        local blockWidth = math.max(280, parent:GetWidth() - 36)
        local section = CATEGORY_SECTIONS[activeKey][1]
        local frame, content = CreateOptionBlock(parent, LText(section.title), 10, -y, blockWidth)
        local contentHeight = section.build(content, W, db)
        if Opt.AppendModuleProfileTools then
            contentHeight = Opt.AppendModuleProfileTools(content, W,
                activeKey == "damage" and "damagemeter" or "mythicplustimer", contentHeight)
        end
        local _, resetHeight = W:Button(content, LText("Reset Profile"), -contentHeight, function()
            local profiles = KT:GetModule("Profiles", true)
            if profiles then
                local ok, err = profiles:ResetSubmoduleProfile(
                    activeKey == "damage" and "damagemeter" or "mythicplustimer")
                if not ok then KT:Print(err) end
            end
        end, "FULL", true, LText("Reset this submodule profile to defaults?"))
        contentHeight = contentHeight + resetHeight
        local totalHeight = FinalizeOptionBlock(frame, content, contentHeight)
        return y + totalHeight + 14
    end

    local cols = BeginOptionBlocks(parent, y, { gap = 14, columnGap = 14 })
    for _, section in ipairs(CATEGORY_SECTIONS[activeKey] or CATEGORY_SECTIONS.instance) do
        AddOptionBlock(cols, section.column, LText(section.title), function(container)
            return section.build(container, W, db)
        end)
    end

    return EndOptionBlocks(cols)
end

KT:RegisterPage("enhancements", LText("Enhancements"), 52, function(sc, W)
    local y, h = 0, 0
    local db = DB()

    _, h = W:SectionHeader(sc, LText("Enhancements"), -y)
    y = y + h

    _, h = W:Label(sc, LText("Automation and quality-of-life settings for KullThranUI."), -y, 11)
    y = y + h

    _, h = W:Label(sc, LText("Open one view at a time to keep related options together and make the module easier to navigate."), -y, 10)
    y = y + h + 4

    _, h = W:Toggle(sc, LText("Enable Module"), -y,
        function() return db.enable ~= false end,
        function(v)
            db.enable = v and true or false
            Refresh()
        end)
    y = y + h

    _, h = W:Button(sc, LText("Reset Module Defaults"), -y, function()
        ResetModuleDefaults()
        Refresh({ rebuild = true })
    end, "FULL", true, LText("Reset all Enhancements settings to defaults?"))
    y = y + h + 10

    local shell = CreateFrame("Frame", nil, sc)
    shell:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
    shell:SetSize(sc:GetWidth() - 20, 10)

    local sidebar = CreateSidebar(shell, W)
    sidebar:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, 0)

    local contentShellWidth = shell:GetWidth() - sidebar:GetWidth() - 16
    local contentShell = CreateFrame("Frame", nil, shell, "BackdropTemplate")
    contentShell:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 16, 0)
    contentShell:SetWidth(contentShellWidth)
    KT:AddBackdrop(contentShell, 0.025, 0.03, 0.045, 0.96)
    do
        local accentR, accentG, accentB = CurrentAccentColor()
        KT:AddBorder(contentShell, accentR, accentG, accentB, 0.26)
    end

    local content = CreateFrame("Frame", nil, contentShell)
    content:SetPoint("TOPLEFT", contentShell, "TOPLEFT", 12, -12)
    content:SetWidth(contentShellWidth - 24)

    local contentHeight = BuildActiveCategory(content, W, db)
    content:SetHeight(contentHeight + 4)
    contentShell:SetHeight(content:GetHeight() + 24)

    shell:SetHeight(math.max(sidebar:GetHeight(), contentShell:GetHeight()))

    return y + shell:GetHeight() + 8
end)
