local ADDON_NAME, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("AddonConflictDetector", "AceEvent-3.0")

local _G = _G
local C_AddOns = C_AddOns
local UnitName = UnitName
local time = time

local function LText(text)
    if type(text) ~= "string" then return text end
    local locale = KT.GetLocale and KT:GetLocale()
    return locale and locale[text] or text
end

local FALLBACK_RULE_ICONS = {
    ui_suites = 135769,
    cooldown_manager = 236272,
    bags = 133640,
    chat = 134332,
    unit_frames = 135782,
    action_bars = 132349,
    cast_bar = 135740,
    minimap = 132775,
    minimap_buttons = 132775,
    nameplates = 237387,
    damage_meter = 132290,
    objective_tracker = 134269,
    cursor = 134400,
    frame_movers = 134400,
    mythic_plus_timer = 134269,
}

local FALLBACK_ADDON_ICONS = {
    BetterCooldownManager = 236272,
    CenteredCooldownManager = 236272,
    CooldownManagerCentered = 236272,
    ArcUI = 134400,
    EllesmereUI = 134400,
    ElvUI = 134400,
    GW2_UI = 136243,
    NDui = 136243,
    SpartanUI = 134400,
    Tukui = 134400,
    Baganator = 133640,
    Bagnon = 133640,
    AdiBags = 133640,
    ArkInventory = 133640,
    Cell = 135782,
    DandersFrames = 135782,
    DandersFramers = 135782,
    EasyFrames = 135782,
    Grid2 = 135782,
    HealBot = 135782,
    VuhDo = 135782,
    Plexus = 135782,
    BetterBlizzPlates = 237387,
    AzCastBar = 135740,
    Quartz = 135740,
    Gnosis = 135740,
    Castbars = 135740,
    OmniCD = 236272,
    ArchonTooltip = 134332,
    Details = 132290,
    BetterBags = 133640,
    BetterBlizzFrames = 135782,
    SenseiClassResourceBar = 236272,
    BasicChatMods = 134332,
    TipTac = 134332,
    HidingBar = 132775,
    CursorTrail = 134400,
    MoveAny = 134400,
    ["!KalielsTracker"] = 134269,
    SylingTracker = 134269,
    WarpDeplete = 134269,
    AngryKeystones = 134269,
}

local function GetAddonInfoSafe(addon)
    if not addon or addon == "" then return nil end

    if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
        local numAddons = C_AddOns.GetNumAddOns() or 0
        for i = 1, numAddons do
            local name, title, notes, loadable, reason, security = C_AddOns.GetAddOnInfo(i)
            if name == addon then
                return name, title, notes, loadable, reason, security
            end
        end
        return nil
    end

    if GetNumAddOns and GetAddOnInfo then
        local numAddons = GetNumAddOns() or 0
        for i = 1, numAddons do
            local name, title, notes, loadable, reason, security = GetAddOnInfo(i)
            if name == addon then
                return name, title, notes, loadable, reason, security
            end
        end
        return nil
    end

    if C_AddOns and C_AddOns.GetAddOnInfo then
        local name, title, notes, loadable, reason, security = C_AddOns.GetAddOnInfo(addon)
        if not name then return nil end
        return name, title, notes, loadable, reason, security
    end
    if GetAddOnInfo then
        return GetAddOnInfo(addon)
    end
    return nil
end

local function IsAddonLoadedSafe(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addon)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(addon)
    end
    return false
end

local function GetAddonEnableStateSafe(addon)
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        return C_AddOns.GetAddOnEnableState(UnitName("player"), addon)
    end
    if GetAddOnEnableState then
        return GetAddOnEnableState(UnitName("player"), addon)
    end
    return 0
end

local DEFAULT_RULES = {
    {
        id = "ui_suites",
        title = "Complete UI Suites",
        kind = "conflict",
        severity = "high",
        modules = { "Multiple KUI modules" },
        addons = { "EllesmereUI", "ElvUI", "GW2_UI", "NDui", "SpartanUI", "Tukui", "SUI", "Orbit", "JugoUI", "AzeriteUI5_JuNNeZ_Edition" },
        reason = "Complete UI suites replace several interface systems at once and can override multiple KUI modules.",
    },
    {
        id = "cooldown_manager",
        title = "Cooldown Manager",
        kind = "conflict",
        severity = "high",
        modules = { "KUI Cooldown Manager", "KUI Resource Bars", "KUI Cast Bar" },
        addons = { "BetterCooldownManager", "CenteredCooldownManager", "CooldownManagerCentered", "OmniCD", "ArcUI", "EllesmereUI", "SenseiClassResourceBar", "asPowerBar" },
        reason = "Duplicate cooldown, cast, power, resource or tracker bars can overlap with KUI CDM, Resource Bars and Cast Bar.",
    },
    {
        id = "bags",
        title = "Bags",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Bags" },
        addons = { "Baganator", "Bagnon", "BetterBags", "AdiBags", "ArkInventory", "Sorted", "Inventorian", "Combuctor" },
        reason = "Bag replacements can override KUI Bags and category layouts.",
    },
    {
        id = "chat",
        title = "Chat",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Chat" },
        addons = { "Chattynator", "Prat-3.0", "Chatter", "WIM", "Glass", "BasicChatMods", "ElvUI", "ArchonTooltip" },
        reason = "Chat replacements may override KUI chat styling.",
    },
    {
        id = "unit_popup_tooltips",
        title = "Unit Popup / Tooltip Menus",
        kind = "conflict",
        severity = "medium",
        modules = { "KUI Tooltip", "Blizzard Unit Menus" },
        addons = { "ArchonTooltip", "TipTac", "TinyTooltip-Reforged" },
        reason = "Tooltip and unit menu extensions can taint Blizzard context menus and cause popup layout errors in combat or PvP.",
    },
    {
        id = "unit_frames",
        title = "Unit Frames",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Unit Frames", "KUI Party Frames" },
        addons = { "UnhaltedUnitFrames", "DandersFrames", "DandersFramers", "ShadowedUnitFrames", "PitBull4", "Cell", "Grid2", "VuhDo", "HealBot", "Plexus", "EasyFrames", "BetterBlizzFrames", "MidnightSimpleUnitFrames", "asUnitFrame", "Stuf", "TPerl", "BigDebuffs", "ElvUI" },
        reason = "Multiple unit, party or raid frame addons can cause duplicate, taint, or overlapping secure unit frames.",
    },
    {
        id = "action_bars",
        title = "Action Bars",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Action Bars" },
        addons = { "Bartender4", "Dominos", "Neuron", "ElvUI" },
        reason = "Multiple action bar addons can override bar layouts.",
    },
    {
        id = "cast_bar",
        title = "Cast Bar",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Cast Bar" },
        addons = { "Quartz", "Gnosis", "Castbars", "AzCastBar", "BetterCooldownManager", "ElvUI" },
        reason = "External cast bars can replace the KUI cast bar.",
    },
    {
        id = "minimap",
        title = "Minimap",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Minimap" },
        addons = { "SexyMap", "Chinchilla", "BasicMinimap" },
        reason = "Minimap replacements may override KUI minimap styling.",
    },
    {
        id = "minimap_buttons",
        title = "Minimap Button Collectors",
        kind = "conflict",
        severity = "medium",
        modules = { "KUI Minimap Button Bar" },
        addons = { "HidingBar", "MinimapButtonButton" },
        reason = "Multiple minimap button collectors can reparent or hide the same buttons, producing missing, duplicated, or inaccessible icons.",
    },
    {
        id = "objective_tracker",
        title = "Objective Tracker",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Objective Tracker" },
        addons = { "!KalielsTracker", "KalielsTracker", "SylingTracker" },
        reason = "Objective tracker replacements can move, rebuild, or hide the same Blizzard tracker styled and positioned by KUI.",
    },
    {
        id = "cursor",
        title = "Cursor Effects",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Cursor" },
        addons = { "CursorTrail", "CursorMod" },
        reason = "Running more than one cursor effect creates duplicate rings or trails and unnecessary per-frame updates.",
    },
    {
        id = "frame_movers",
        title = "Frame Movers / Edit Mode",
        kind = "conflict",
        severity = "high",
        modules = { "KUI Unlock Mode / BlizzMove" },
        addons = { "MoveAny", "MoveAnything", "BlizzMove", "EditModeExpanded" },
        reason = "Multiple frame movers can compete for anchors and protected Blizzard frames, causing position drift or taint after reloads and zone changes.",
        canDisableKUI = false,
    },
    {
        id = "damage_meter",
        title = "Damage Meter",
        kind = "conflict",
        severity = "high",
        modules = { "KUI Damage Meter" },
        addons = { "Details" },
        reason = "Running Details and KUI Damage Meter together duplicates combat tracking windows and their input, layout, and session controls.",
    },
    {
        id = "mythic_plus_timer",
        title = "Mythic+ Timer",
        kind = "conflict",
        severity = "medium",
        modules = { "KUI Mythic+ Tracker" },
        addons = { "WarpDeplete", "AngryKeystones" },
        reason = "WarpDeplete draws its own keystone timer, forces bar and objectives over the same screen space and reload position data tracked now by KUI's built-in Mythic+ Timer.",
    },
    {
        id = "nameplates",
        title = "Nameplates",
        kind = "conflict",
        severity = "high",
        modules = { "Nameplates" },
        addons = {
            "Plater",
            "Plater_Nameplates",
            "PlaterNameplates",
            "PlaterNameplatesBeta",
            "PlatyNator",
            "PlatyNator_Classic",
            "Kui_Nameplates",
            "KuiNameplates",
            "TidyPlates",
            "NeatPlates",
            "ThreatPlates",
            "BetterBlizzPlates",
            "ElvUI",
        },
        reason = "Multiple nameplate addons can cause duplicate elements, taint, and conflicting settings.",
    },
}

local function GetConflictPopupMetrics()
    local screenW, screenH = GetPhysicalScreenSize()
    screenW = tonumber(screenW) or 1920
    screenH = tonumber(screenH) or 1080

    local textWidth = math.floor(screenW * 0.26)
    if textWidth < 320 then textWidth = 320 end
    if textWidth > 520 then textWidth = 520 end

    local popupWidth = textWidth + 56
    local minHeight = math.max(150, math.floor(screenH * 0.18))
    local maxHeight = math.max(260, math.floor(screenH * 0.42))
    return textWidth, popupWidth, minHeight, maxHeight
end

local function EnsureConflictPopupScroll(dialog)
    if not dialog or dialog._ktConflictScroll then
        return dialog and dialog._ktConflictScroll or nil
    end

    local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local step = 28
        local range = self:GetVerticalScrollRange() or 0
        local target = current - (delta * step)
        if target < 0 then
            target = 0
        elseif target > range then
            target = range
        end
        self:SetVerticalScroll(target)
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local text = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetPoint("TOPRIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)

    dialog._ktConflictScroll = scroll
    dialog._ktConflictScrollContent = content
    dialog._ktConflictScrollText = text
    return scroll
end

local function ApplyConflictPopupLayout(dialog, displayText)
    if not dialog or not dialog.text then return end

    local scroll = EnsureConflictPopupScroll(dialog)
    local scrollContent = dialog._ktConflictScrollContent
    local scrollText = dialog._ktConflictScrollText
    if not (scroll and scrollContent and scrollText) then
        return
    end

    local textWidth, popupWidth, minHeight, maxHeight = GetConflictPopupMetrics()
    local resolvedText = displayText or dialog._ktConflictFullText or dialog.text:GetText() or ""
    dialog._ktConflictFullText = resolvedText

    dialog.text:SetText("")
    dialog.text:Hide()

    scrollText:SetWidth(textWidth)
    scrollText:SetText(resolvedText)
    local textHeight = math.ceil(scrollText:GetStringHeight() or 0)
    local bodyHeight = math.max(minHeight, math.min(maxHeight, textHeight + 12))
    local targetHeight = bodyHeight + 96

    dialog:SetWidth(popupWidth)
    dialog:SetHeight(targetHeight)

    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -28)
    scroll:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -36, -28)
    scroll:SetHeight(bodyHeight)

    scrollContent:SetWidth(textWidth)
    scrollContent:SetHeight(math.max(bodyHeight, textHeight + 8))
    scroll:SetVerticalScroll(0)

    if dialog.button1 then
        dialog.button1:SetWidth(140)
        dialog.button1:ClearAllPoints()
        dialog.button1:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -6, 16)
    end
    if dialog.button2 then
        dialog.button2:SetWidth(120)
        dialog.button2:ClearAllPoints()
        if dialog.button1 then
            dialog.button2:SetPoint("RIGHT", dialog.button1, "LEFT", -8, 0)
        else
            dialog.button2:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 16)
        end
    end
end

local function EnsureDB()
    if not KT.db or not KT.db.profile then return nil end
    KT.db.profile.conflictDetector = KT.db.profile.conflictDetector or {
        autoScan = true,
        notify = true,
        dontShowAgain = false,
        lastScan = 0,
        pendingReload = {},
        pendingModuleReload = {},
    }
    KT.db.profile.conflictDetector.pendingReload = KT.db.profile.conflictDetector.pendingReload or {}
    KT.db.profile.conflictDetector.pendingModuleReload = KT.db.profile.conflictDetector.pendingModuleReload or {}
    return KT.db.profile.conflictDetector
end

local function GetSeverityWeight(severity)
    if severity == "critical" then return 4 end
    if severity == "high" then return 3 end
    if severity == "medium" then return 2 end
    if severity == "low" then return 1 end
    return 0
end

local function IsRuleRelevant(rule)
    if not rule or not rule.id then return true end
    local p = KT and KT.db and KT.db.profile
    if not p then return true end

    if rule.id == "unit_frames" then
        local unitFramesEnabled = not (p.unitFrames and p.unitFrames.enable == false)
        local partyFramesEnabled = not (p.partyFrames and p.partyFrames.enable == false)
        return unitFramesEnabled or partyFramesEnabled
    end
    if rule.id == "bags" then
        return not (p.bags and p.bags.enable == false)
    end
    if rule.id == "chat" then
        return not (p.chat and p.chat.enable == false)
    end
    if rule.id == "action_bars" then
        return not (p.actionbars and p.actionbars.enable == false)
    end
    if rule.id == "cast_bar" then
        return not (p.castbar and p.castbar.enable == false)
    end
    if rule.id == "minimap" then
        return not (p.minimap and p.minimap.enable == false)
    end
    if rule.id == "minimap_buttons" then
        return not (p.minimapButton and p.minimapButton.enable == false)
    end
    if rule.id == "objective_tracker" then
        return not (p.objectiveTracker and p.objectiveTracker.enable == false)
    end
    if rule.id == "cursor" then
        return not (p.cursor and p.cursor.enable == false)
    end
    if rule.id == "cooldown_manager" then
        local cdmEnabled = not (p.cooldownManager and p.cooldownManager.cdmBars and p.cooldownManager.cdmBars.enabled == false)
        local resourceEnabled = p.resourceBars and (
            (p.resourceBars.primary and p.resourceBars.primary.enabled)
            or (p.resourceBars.secondary and p.resourceBars.secondary.enabled)
            or (p.resourceBars.health and p.resourceBars.health.enabled)
        )
        local castEnabled = not (p.castbar and p.castbar.enable == false)
        return cdmEnabled or resourceEnabled or castEnabled
    end
    if rule.id == "damage_meter" then
        local enhancements = p.enhancements
        local damageMeter = enhancements and enhancements.damageMeter
        if not damageMeter or enhancements.enable == false then
            return false
        end
        if damageMeter.enabled == true then
            return true
        end
        for _, window in ipairs(damageMeter.windows or {}) do
            if window.enabled == true then
                return true
            end
        end
        return false
    end
    if rule.id == "mythic_plus_timer" then
        local enhancements = p.enhancements
        if not enhancements or enhancements.enable == false then
            return false
        end
        local tracker = enhancements.mplusTracker
        return tracker ~= nil and tracker.enabled == true
    end

    return true
end

local function DisableKUIRuleModules(ruleId)
    local p = KT and KT.db and KT.db.profile
    if not p then return false end

    if ruleId == "ui_suites" then
        p.actionbars = p.actionbars or {}; p.actionbars.enable = false
        p.bags = p.bags or {}; p.bags.enable = false
        p.chat = p.chat or {}; p.chat.enable = false
        p.castbar = p.castbar or {}; p.castbar.enable = false
        p.minimap = p.minimap or {}; p.minimap.enable = false
        p.unitFrames = p.unitFrames or {}; p.unitFrames.enable = false
        p.partyFrames = p.partyFrames or {}; p.partyFrames.enable = false
        return true, "Multiple KUI modules"
    elseif ruleId == "cooldown_manager" then
        p.cooldownManager = p.cooldownManager or {}
        p.cooldownManager.cdmBars = p.cooldownManager.cdmBars or {}
        p.cooldownManager.cdmBars.enabled = false
        p.resourceBars = p.resourceBars or {}
        p.resourceBars.primary = p.resourceBars.primary or {}
        p.resourceBars.secondary = p.resourceBars.secondary or {}
        p.resourceBars.health = p.resourceBars.health or {}
        p.resourceBars.primary.enabled = false
        p.resourceBars.secondary.enabled = false
        p.resourceBars.health.enabled = false
        p.castbar = p.castbar or {}; p.castbar.enable = false
        return true, "KUI Cooldown Manager / Resource Bars / Cast Bar"
    elseif ruleId == "bags" then
        p.bags = p.bags or {}; p.bags.enable = false
        return true, "KUI Bags"
    elseif ruleId == "chat" then
        p.chat = p.chat or {}; p.chat.enable = false
        return true, "KUI Chat"
    elseif ruleId == "unit_popup_tooltips" then
        p.tooltip = p.tooltip or {}; p.tooltip.enable = false
        return true, "KUI Tooltip"
    elseif ruleId == "unit_frames" then
        p.unitFrames = p.unitFrames or {}; p.unitFrames.enable = false
        p.partyFrames = p.partyFrames or {}; p.partyFrames.enable = false
        return true, "KUI Unit Frames / Party Frames"
    elseif ruleId == "action_bars" then
        p.actionbars = p.actionbars or {}; p.actionbars.enable = false
        return true, "KUI Action Bars"
    elseif ruleId == "cast_bar" then
        p.castbar = p.castbar or {}; p.castbar.enable = false
        return true, "KUI Cast Bar"
    elseif ruleId == "minimap" then
        p.minimap = p.minimap or {}; p.minimap.enable = false
        return true, "KUI Minimap"
    elseif ruleId == "minimap_buttons" then
        p.minimapButton = p.minimapButton or {}; p.minimapButton.enable = false
        return true, "KUI Minimap Button Bar"
    elseif ruleId == "objective_tracker" then
        p.objectiveTracker = p.objectiveTracker or {}; p.objectiveTracker.enable = false
        return true, "KUI Objective Tracker"
    elseif ruleId == "cursor" then
        p.cursor = p.cursor or {}; p.cursor.enable = false
        return true, "KUI Cursor"
    elseif ruleId == "damage_meter" then
        p.enhancements = p.enhancements or {}
        p.enhancements.damageMeter = p.enhancements.damageMeter or {}
        p.enhancements.damageMeter.enabled = false
        for _, window in ipairs(p.enhancements.damageMeter.windows or {}) do
            window.enabled = false
        end
        return true, "KUI Damage Meter"
    elseif ruleId == "mythic_plus_timer" then
        p.enhancements = p.enhancements or {}
        p.enhancements.mplusTracker = p.enhancements.mplusTracker or {}
        p.enhancements.mplusTracker.enabled = false
        return true, "KUI Mythic+ Tracker"
    elseif ruleId == "nameplates" then
        _G.KullThranUINameplatesDB = _G.KullThranUINameplatesDB or {}
        _G.KullThranUINameplatesDB.enable = false
        return true, "KUI Nameplates"
    end

    return false
end

function Mod:OnInitialize()
    self.rules = self.rules or DEFAULT_RULES
    EnsureDB()
end

function Mod:GetDB()
    return EnsureDB()
end

function Mod:OnEnable()
    EnsureDB()
    self:RegisterEvent("PLAYER_LOGIN", "AutoScan")
end

function Mod:RegisterRule(rule)
    if type(rule) ~= "table" then return end
    self.rules = self.rules or {}
    table.insert(self.rules, rule)
end

function Mod:GetAddonStatus(addon)
    local name, title, notes, loadable, reason, security = GetAddonInfoSafe(addon)
    local installed = name ~= nil
    local enabled = installed and (GetAddonEnableStateSafe(addon) > 0) or false
    local loaded = installed and IsAddonLoadedSafe(addon) or false
    return {
        name = addon,
        title = title or addon,
        installed = installed,
        enabled = enabled,
        loaded = loaded,
        loadable = loadable,
        reason = reason,
        security = security,
    }
end

function Mod:GetAddonIcon(addonName, ruleId)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local metadataKeys = { "IconTexture", "X-Icon", "Icon", "X-Texture" }
        for _, key in ipairs(metadataKeys) do
            local ok, value = pcall(C_AddOns.GetAddOnMetadata, addonName, key)
            if ok and value and value ~= "" then
                local numeric = tonumber(value)
                return numeric or value
            end
        end
    elseif GetAddOnMetadata then
        local metadataKeys = { "IconTexture", "X-Icon", "Icon", "X-Texture" }
        for _, key in ipairs(metadataKeys) do
            local ok, value = pcall(GetAddOnMetadata, addonName, key)
            if ok and value and value ~= "" then
                local numeric = tonumber(value)
                return numeric or value
            end
        end
    end
    return FALLBACK_ADDON_ICONS[addonName] or FALLBACK_RULE_ICONS[ruleId] or 134400
end

function Mod:HasPendingReload(addonName)
    local db = EnsureDB()
    return db and db.pendingReload and db.pendingReload[addonName] == true or false
end

function Mod:HasPendingModuleReload(ruleId)
    local db = EnsureDB()
    return db and db.pendingModuleReload and db.pendingModuleReload[ruleId] == true or false
end

function Mod:DisableKUIRule(ruleId)
    if not ruleId or ruleId == "" then
        return false, "invalid"
    end

    local ok, label = DisableKUIRuleModules(ruleId)
    local db = EnsureDB()
    if ok and db then
        db.pendingModuleReload[ruleId] = true
    end
    return ok, label
end

function Mod:DisableAddon(addonName)
    if not addonName or addonName == "" then
        return false, "invalid"
    end

    local db = EnsureDB()
    local playerName = UnitName("player")
    local disabled = false

    if C_AddOns and C_AddOns.DisableAddOn then
        disabled = pcall(C_AddOns.DisableAddOn, addonName, playerName)
        if not disabled then
            disabled = pcall(C_AddOns.DisableAddOn, addonName)
        end
    elseif DisableAddOn then
        disabled = pcall(DisableAddOn, addonName, playerName)
        if not disabled then
            disabled = pcall(DisableAddOn, addonName)
        end
    end

    if disabled and db then
        db.pendingReload[addonName] = true
    end

    return disabled
end

function Mod:EnableAddon(addonName)
    if not addonName or addonName == "" then
        return false, "invalid"
    end

    local db = EnsureDB()
    local playerName = UnitName("player")
    local enabled = false

    if C_AddOns and C_AddOns.EnableAddOn then
        enabled = pcall(C_AddOns.EnableAddOn, addonName, playerName)
        if not enabled then
            enabled = pcall(C_AddOns.EnableAddOn, addonName)
        end
    elseif EnableAddOn then
        enabled = pcall(EnableAddOn, addonName, playerName)
        if not enabled then
            enabled = pcall(EnableAddOn, addonName)
        end
    end

    if enabled and db then
        db.pendingReload[addonName] = true
    end

    return enabled
end

function Mod:EnableAddonAndDisableKUIRule(addonName, ruleId)
    local addonEnabled = self:EnableAddon(addonName)
    if not addonEnabled then
        return false, false, false, nil
    end

    local moduleDisabled, label = self:DisableKUIRule(ruleId)
    return addonEnabled and moduleDisabled, addonEnabled, moduleDisabled, label
end

function Mod:Scan()
    local results = {}
    local rules = self.rules or DEFAULT_RULES

    for _, rule in ipairs(rules) do
        if rule.enabled ~= false and IsRuleRelevant(rule) then
            local addons = {}
            local hasLoaded = false

            for _, addon in ipairs(rule.addons or {}) do
                local st = self:GetAddonStatus(addon)
                if st.installed then
                    if st.loaded or st.enabled then
                        hasLoaded = true
                    end
                    table.insert(addons, st)
                end
            end

            if #addons > 0 then
                table.insert(results, {
                    rule = rule,
                    addons = addons,
                    hasLoaded = hasLoaded,
                })
            end
        end
    end

    table.sort(results, function(a, b)
        local sa = GetSeverityWeight(a.rule and a.rule.severity)
        local sb = GetSeverityWeight(b.rule and b.rule.severity)
        if sa == sb then
            if a.hasLoaded ~= b.hasLoaded then
                return a.hasLoaded
            end
            local at = (a.rule and a.rule.title) or ""
            local bt = (b.rule and b.rule.title) or ""
            return at < bt
        end
        return sa > sb
    end)

    self.lastReport = results
    return results
end

function Mod:GetActiveConflicts(report)
    report = report or self.lastReport or self:Scan()
    local active = {}
    for _, entry in ipairs(report) do
        if entry.hasLoaded then
            table.insert(active, entry)
        end
    end
    return active
end

function Mod:GetUniqueAddonCount(report, activeOnly)
    local seen = {}
    local count = 0
    for _, entry in ipairs(report or {}) do
        for _, addon in ipairs(entry.addons or {}) do
            local qualifies = addon and addon.installed
            if activeOnly then
                qualifies = qualifies and (addon.loaded or addon.enabled)
            end
            if qualifies and addon.name and not seen[addon.name] then
                seen[addon.name] = true
                count = count + 1
            end
        end
    end
    return count
end

function Mod:AutoScan()
    local db = EnsureDB()
    if not db or not db.autoScan then return end
    local report = self:Scan()
    db.lastScan = time()
    self:NotifyIfConflicts(report)
end

function Mod:NotifyIfConflicts(report)
    local db = EnsureDB()
    if not db or not db.notify then return end
    if db.dontShowAgain then return end
    local active = self:GetActiveConflicts(report)
    if #active == 0 then return end

    local count = self:GetUniqueAddonCount(active, true)

    local msg = string.format("KullThranUI: Detected %d addon%s that may conflict. Open the Compatibility panel to review.",
        count, count == 1 and "" or "s")
    if KT.Print then
        KT:Print(msg)
    elseif _G.DEFAULT_CHAT_FRAME then
        _G.DEFAULT_CHAT_FRAME:AddMessage(msg)
    end

    self:ShowConflictPopup(active, count)
end

function Mod:BuildPopupText(active, total)
    local lines = {
        LText("KullThranUI detected addons that may conflict:"),
        ""
    }

    local shown = 0
    local seen = {}
    local maxLines = 8
    for _, entry in ipairs(active) do
        local ruleTitle = LText(entry.rule and entry.rule.title or "Unknown")
        for _, addon in ipairs(entry.addons or {}) do
            if addon and (addon.loaded or addon.enabled) and addon.name and not seen[addon.name] then
                seen[addon.name] = true
                if shown < maxLines then
                    shown = shown + 1
                    local addonName = addon.title or addon.name or "Addon"
                    table.insert(lines, string.format("- %s (%s)", addonName, ruleTitle))
                end
            end
        end
    end

    if total and total > shown then
        table.insert(lines, string.format(LText("...and %d more."), total - shown))
    end

    table.insert(lines, "")
    table.insert(lines, LText("Open the Compatibility panel to review?"))
    return table.concat(lines, "\n")
end

function Mod:ShowConflictPopup(active, total)
    if self._popupShown then return end
    if not _G.StaticPopupDialogs or not _G.StaticPopup_Show then return end

    local POPUP_KEY = "KT_ADDON_CONFLICTS"
    if not _G.StaticPopupDialogs[POPUP_KEY] then
        _G.StaticPopupDialogs[POPUP_KEY] = {
            text = "%s",
             button1 = LText("Open Compatibility"),
             button2 = _G.CLOSE or "Close",
             OnAccept = function()
                if KT and KT.OpenCompatibilityPanel then
                    KT:OpenCompatibilityPanel()
                    return
                end

                 if KT and KT.Print then
                     KT:Print(LText("Compatibility panel not available right now."))
                  end
              end,
             OnShow = function(self)
                ApplyConflictPopupLayout(self)
             end,
              timeout = 0,
              whileDead = true,
              hideOnEscape = true,
             preferredIndex = 3,
        }
    end

    local text = self:BuildPopupText(active, total)
    local dialog = _G.StaticPopup_Show(POPUP_KEY, text)
    if dialog then
        dialog._ktConflictFullText = text
        ApplyConflictPopupLayout(dialog, text)
    end
    self._popupShown = true
end
