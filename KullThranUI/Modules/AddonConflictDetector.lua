local ADDON_NAME, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("AddonConflictDetector", "AceEvent-3.0")

local _G = _G
local C_AddOns = C_AddOns
local UnitName = UnitName
local UnitGUID = UnitGUID
local time = time

local function LText(text)
    if type(text) ~= "string" then return text end
    local locale = KT.GetLocale and KT:GetLocale()
    return locale and locale[text] or text
end

local FALLBACK_RULE_ICONS = {
    ui_suites = 135769,
    cooldown_manager = 236272,
    resource_bars = 136048,
    bags = 133640,
    chat = 134332,
    unit_popup_tooltips = 134332,
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
    buffs = 136243,
    experience_bar = 132369,
    friend_list = 132172,
    teleports = 136222,
    character_sheet = 132625,
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
    Skada = 132290,
    Recount = 132290,
    BetterBags = 133640,
    BetterBlizzFrames = 135782,
    SenseiClassResourceBar = 236272,
    IceHUD = 136048,
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

-- ---------------------------------------------------------------------------
-- Addon state
-- ---------------------------------------------------------------------------

-- The client keys per-character enable states by GUID (Blizzard's own AddOn
-- list passes UnitGUID("player")). A name is not a reliable key: Forever keys
-- its characters by "Name-Surname", so a name lookup fell back to the
-- account-wide state and reported disabled addons as enabled.
local function GetCharacterKeys()
    local keys = {}
    local guid = UnitGUID and UnitGUID("player")
    if type(guid) == "string" and guid ~= "" then keys[#keys + 1] = guid end
    local name = UnitName and UnitName("player")
    if type(name) == "string" and name ~= "" then keys[#keys + 1] = name end
    return keys
end

local function GetNumAddonsSafe()
    if C_AddOns and C_AddOns.GetNumAddOns then return C_AddOns.GetNumAddOns() or 0 end
    if _G.GetNumAddOns then return _G.GetNumAddOns() or 0 end
    return 0
end

local function GetAddonInfoRaw(index)
    if C_AddOns and C_AddOns.GetAddOnInfo then return C_AddOns.GetAddOnInfo(index) end
    if _G.GetAddOnInfo then return _G.GetAddOnInfo(index) end
end

-- One pass over the installed addons, keyed by lower-case folder name, so a
-- scan costs one lookup per known addon instead of a full list walk each.
local function BuildAddonIndex()
    local index = {}
    for i = 1, GetNumAddonsSafe() do
        local name, title, notes, loadable, reason, security = GetAddonInfoRaw(i)
        if type(name) == "string" and name ~= "" then
            index[name:lower()] = {
                index = i, name = name, title = title, notes = notes,
                loadable = loadable, reason = reason, security = security,
            }
        end
    end
    return index
end

local function IsAddonLoadedSafe(addon)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addon) and true or false
    end
    if _G.IsAddOnLoaded then
        return _G.IsAddOnLoaded(addon) and true or false
    end
    return false
end

-- Enable state for this character: 0 none, 1 some characters, 2 all.
-- Returns nil when no key could be read.
local function GetAddonEnableStateSafe(addon)
    for _, key in ipairs(GetCharacterKeys()) do
        local ok, state
        if C_AddOns and C_AddOns.GetAddOnEnableState then
            ok, state = pcall(C_AddOns.GetAddOnEnableState, addon, key)
        elseif _G.GetAddOnEnableState then
            ok, state = pcall(_G.GetAddOnEnableState, key, addon)
        end
        if ok and type(state) == "number" then return state end
        if ok and type(state) == "boolean" then return state and 2 or 0 end
    end
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, addon)
        if ok and type(state) == "number" then return state end
    end
    return nil
end

-- Whether the client would load the addon for this character, and why not.
local function GetAddonLoadableSafe(addon, info)
    if C_AddOns and C_AddOns.IsAddOnLoadable then
        for _, key in ipairs(GetCharacterKeys()) do
            local ok, loadable, reason = pcall(C_AddOns.IsAddOnLoadable, addon, key)
            if ok and loadable ~= nil then return loadable and true or false, reason end
        end
    end
    if info then return info.loadable and true or false, info.reason end
    return nil, nil
end

-- Reasons a not-loaded addon will not load after a reload either.
local BLOCKING_REASONS = {
    DISABLED = true, DEP_DISABLED = true, MISSING = true, DEP_MISSING = true,
    CORRUPT = true, INCOMPATIBLE = true, BANNED = true, INSECURE = true,
    INTERFACE_VERSION = true, DEP_INTERFACE_VERSION = true,
    DEP_CORRUPT = true, DEP_INCOMPATIBLE = true, DEP_BANNED = true, DEP_INSECURE = true,
}

-- ---------------------------------------------------------------------------
-- Rules
-- ---------------------------------------------------------------------------

local DEFAULT_RULES = {
    {
        id = "ui_suites",
        title = "Complete UI Suites",
        kind = "conflict",
        severity = "high",
        modules = { "Multiple KUI modules" },
        addons = { "EllesmereUI", "ElvUI", "GW2_UI", "NDui", "SpartanUI", "Tukui", "SUI", "Orbit", "JugoUI", "AzeriteUI5_JuNNeZ_Edition", "ClassicUI",
            "AzeriteUI", "nibRealUI", "LUI", "KkthnxUI", "DuffedUI", "ShestakUI" },
        reason = "Complete UI suites replace several interface systems at once and can override multiple KUI modules.",
    },
    {
        id = "cooldown_manager",
        title = "Cooldown Manager",
        kind = "conflict",
        severity = "high",
        modules = { "KUI Cooldown Manager", "KUI Resource Bars", "KUI Cast Bar" },
        addons = { "BetterCooldownManager", "CenteredCooldownManager", "CooldownManagerCentered", "OmniCD", "ArcUI", "EllesmereUI",
            "ClassUIEnhanced", "CooldownCursorManager", "TweaksUI_Cooldowns", "EllesmereUICooldownManager" },
        reason = "Duplicate cooldown, cast, power, resource or tracker bars can overlap with KUI CDM, Resource Bars and Cast Bar.",
    },
    {
        id = "resource_bars",
        title = "Resource Bars",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Resource Bars" },
        addons = { "SenseiClassResourceBar", "asPowerBar", "TwintopInsanityBar", "IceHUD" },
        reason = "Player power, class resource and health bars from another addon duplicate KUI Resource Bars in the same screen space.",
    },
    {
        id = "bags",
        title = "Bags",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Bags" },
        addons = { "Baganator", "Bagnon", "BetterBags", "AdiBags", "ArkInventory", "Sorted", "Inventorian", "Combuctor",
            "LiteBag", "DJBags", "OneBag3", "Bagshui" },
        reason = "Bag replacements can override KUI Bags and category layouts.",
    },
    {
        id = "chat",
        title = "Chat",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Chat" },
        addons = { "Chattynator", "Prat-3.0", "Chatter", "WIM", "Glass", "BasicChatMods", "ElvUI" },
        reason = "Chat replacements may override KUI chat styling.",
    },
    {
        id = "unit_popup_tooltips",
        title = "Unit Popup / Tooltip Menus",
        kind = "conflict",
        severity = "medium",
        modules = { "KUI Tooltip", "Blizzard Unit Menus" },
        addons = { "ArchonTooltip", "TipTac", "TinyTooltip-Reforged", "TinyTooltip", "TipTop" },
        reason = "Tooltip and unit menu extensions can taint Blizzard context menus and cause popup layout errors in combat or PvP.",
    },
    {
        id = "unit_frames",
        title = "Unit Frames",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Unit Frames", "KUI Party Frames" },
        addons = { "UnhaltedUnitFrames", "DandersFrames", "DandersFramers", "ShadowedUnitFrames", "PitBull4", "Cell", "Grid2", "VuhDo", "HealBot", "Plexus", "EasyFrames", "BetterBlizzFrames", "MidnightSimpleUnitFrames", "asUnitFrame", "Stuf", "TPerl", "BigDebuffs", "ElvUI",
            "Healium", "EllesmereUIUnitFrames", "ZPerl", "XPerl", "LunaUnitFrames" },
        reason = "Multiple unit, party or raid frame addons can cause duplicate, taint, or overlapping secure unit frames.",
    },
    {
        id = "action_bars",
        title = "Action Bars",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Action Bars" },
        addons = { "Bartender4", "Dominos", "Neuron", "ElvUI", "ConsolePort_Bar" },
        reason = "Multiple action bar addons can override bar layouts.",
    },
    {
        id = "cast_bar",
        title = "Cast Bar",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Cast Bar" },
        addons = { "Quartz", "Gnosis", "Castbars", "AzCastBar", "BetterCooldownManager", "ElvUI", "AscensionCastBar", "OpulentCastingBars" },
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
        addons = { "HidingBar", "MinimapButtonButton", "MBB" },
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
        addons = { "CursorTrail", "CursorMod", "UltimateMouseCursor" },
        reason = "Running more than one cursor effect creates duplicate rings or trails and unnecessary per-frame updates.",
    },
    {
        id = "frame_movers",
        title = "Frame Movers / Edit Mode",
        kind = "conflict",
        severity = "high",
        modules = { "KUI Unlock Mode / KUIMove" },
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
        addons = { "Details", "Skada", "Recount", "TinyDPS" },
        reason = "Running another damage meter next to KUI Damage Meter duplicates combat tracking windows and their input, layout, and session controls.",
    },
    {
        id = "mythic_plus_timer",
        title = "Mythic+ Timer",
        kind = "conflict",
        severity = "medium",
        modules = { "KUI Mythic+ Tracker" },
        addons = { "WarpDeplete", "AngryKeystones", "MythicPlusTimer" },
        reason = "Keystone timer addons draw their own timer, forces bar and objectives over the same screen space as the KUI Mythic+ Timer.",
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
            "Platynator",
            "TidyPlates_ThreatPlates",
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
    {
        id = "buffs",
        title = "Buffs & Debuffs",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Buffs & Debuffs" },
        addons = { "Raven", "SatrinaBuffFrame", "ElkBuffBars" },
        reason = "Buff frame replacements hide or rebuild the player buff and debuff frames that KUI Buffs & Debuffs styles.",
    },
    {
        id = "experience_bar",
        title = "Experience Bar",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Experience Bar" },
        addons = { "XPBarNone" },
        reason = "Experience and reputation bar replacements draw a second bar over the KUI Experience Bar.",
    },
    {
        id = "friend_list",
        title = "Friend List",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Enhanced Friend List" },
        addons = { "FriendGroups", "BetterFriendlist" },
        reason = "Friend list replacements rebuild the same Blizzard friends frame that KUI restyles and groups.",
    },
    {
        id = "teleports",
        title = "Teleport Menu",
        kind = "overlap",
        severity = "low",
        modules = { "KUI Teleport Menu" },
        addons = { "TeleportMenu", "DungeonPorts" },
        reason = "Teleport menus add a second set of dungeon and hearthstone buttons next to the KUI Teleport Menu.",
    },
    {
        id = "character_sheet",
        title = "Character Sheet",
        kind = "overlap",
        severity = "medium",
        modules = { "KUI Armory" },
        addons = { "ChonkyCharacterSheet", "DejaCharacterStats", "Narcissus" },
        reason = "Character sheet replacements resize and rebuild the character frame and its stat panel, which KUI Armory owns.",
    },
}

local SEVERITY_WEIGHT = { critical = 4, high = 3, medium = 2, low = 1 }

local function GetSeverityWeight(severity)
    return SEVERITY_WEIGHT[severity] or 0
end

-- ---------------------------------------------------------------------------
-- Popup layout
-- ---------------------------------------------------------------------------

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
    -- "Disable All & Reload" is the recommended answer: widest, on the right.
    if dialog.button3 and dialog.button3:IsShown() then
        dialog.button3:SetWidth(170)
        -- Close + Open (274 px) sit left of centre, this one right of it.
        dialog:SetWidth(math.max(popupWidth, 600))
        dialog.button3:ClearAllPoints()
        dialog.button3:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 6, 16)
        if dialog.button1 then
            dialog.button1:ClearAllPoints()
            dialog.button1:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -6, 16)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Saved settings
-- ---------------------------------------------------------------------------

local function EnsureDB()
    if not KT.db or not KT.db.profile then return nil end
    KT.db.profile.conflictDetector = KT.db.profile.conflictDetector or {
        autoScan = true,
        notify = true,
        dontShowAgain = false,
        lastScan = 0,
    }
    local db = KT.db.profile.conflictDetector
    db.pendingReload = db.pendingReload or {}
    db.pendingModuleReload = db.pendingModuleReload or {}
    db.ignored = db.ignored or {}
    if db.popupSeverity ~= "medium" and db.popupSeverity ~= "high" then
        db.popupSeverity = "low"
    end
    return db
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
    if rule.id == "friend_list" then
        local e = p.enhancements
        return not (e and (e.enable == false or (e.social and e.social.enhancedFriendList == false)))
    end
    if rule.id == "teleports" then
        return not (p.teleportMenu and p.teleportMenu.enable == false)
    end
    if rule.id == "character_sheet" then
        return not (p.armory and p.armory.enable == false)
    end
    if rule.id == "chat" then
        return not (p.chat and p.chat.enable == false)
    end
    if rule.id == "unit_popup_tooltips" then
        return not (p.tooltip and p.tooltip.enable == false)
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
    if rule.id == "buffs" then
        return not (p.buffsAndDebuffs and p.buffsAndDebuffs.enable == false)
    end
    if rule.id == "experience_bar" then
        return not (p.experienceBar and p.experienceBar.enable == false)
    end
    if rule.id == "resource_bars" then
        local rb = p.resourceBars
        return rb ~= nil and (
            (rb.primary and rb.primary.enabled)
            or (rb.secondary and rb.secondary.enabled)
            or (rb.health and rb.health.enabled)
        ) and true or false
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

local function DisableResourceBars(p)
    p.resourceBars = p.resourceBars or {}
    p.resourceBars.primary = p.resourceBars.primary or {}
    p.resourceBars.secondary = p.resourceBars.secondary or {}
    p.resourceBars.health = p.resourceBars.health or {}
    p.resourceBars.primary.enabled = false
    p.resourceBars.secondary.enabled = false
    p.resourceBars.health.enabled = false
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
        DisableResourceBars(p)
        p.castbar = p.castbar or {}; p.castbar.enable = false
        return true, "KUI Cooldown Manager / Resource Bars / Cast Bar"
    elseif ruleId == "resource_bars" then
        DisableResourceBars(p)
        return true, "KUI Resource Bars"
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
    elseif ruleId == "buffs" then
        p.buffsAndDebuffs = p.buffsAndDebuffs or {}; p.buffsAndDebuffs.enable = false
        return true, "KUI Buffs & Debuffs"
    elseif ruleId == "experience_bar" then
        p.experienceBar = p.experienceBar or {}; p.experienceBar.enable = false
        return true, "KUI Experience Bar"
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
    elseif ruleId == "friend_list" then
        p.enhancements = p.enhancements or {}
        p.enhancements.social = p.enhancements.social or {}
        p.enhancements.social.enhancedFriendList = false
        return true, "KUI Enhanced Friend List"
    elseif ruleId == "teleports" then
        p.teleportMenu = p.teleportMenu or {}; p.teleportMenu.enable = false
        return true, "KUI Teleport Menu"
    elseif ruleId == "character_sheet" then
        p.armory = p.armory or {}; p.armory.enable = false
        return true, "KUI Armory"
    elseif ruleId == "nameplates" then
        _G.KullThranUINameplatesDB = _G.KullThranUINameplatesDB or {}
        _G.KullThranUINameplatesDB.enable = false
        return true, "KUI Nameplates"
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

function Mod:OnInitialize()
    self.rules = self.rules or DEFAULT_RULES
    local db = EnsureDB()
    -- A new UI session applied every change queued before the reload, so the
    -- "reload required" marks from the previous session no longer apply.
    if db then
        wipe(db.pendingReload)
        wipe(db.pendingModuleReload)
    end
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

function Mod:GetRules()
    return self.rules or DEFAULT_RULES
end

function Mod:GetSeverityWeight(severity)
    return GetSeverityWeight(severity)
end

-- False when the KUI module a rule protects is turned off (the rule is not
-- checked then).
function Mod:IsRuleRelevant(rule)
    return IsRuleRelevant(rule)
end

-- Installed addons keyed by lower-case folder name.
function Mod:GetInstalledAddonIndex()
    return BuildAddonIndex()
end

function Mod:IsIgnored(addonName)
    local db = EnsureDB()
    return db and addonName and db.ignored[addonName] == true or false
end

function Mod:SetIgnored(addonName, ignored)
    local db = EnsureDB()
    if not db or not addonName or addonName == "" then return end
    db.ignored[addonName] = ignored and true or nil
    self.lastReport = nil
end

function Mod:ClearIgnored()
    local db = EnsureDB()
    if db then wipe(db.ignored) end
    self.lastReport = nil
end

function Mod:GetIgnoredCount()
    local db = EnsureDB()
    local count = 0
    for _, flag in pairs(db and db.ignored or {}) do
        if flag then count = count + 1 end
    end
    return count
end

-- addonIndex: optional result of BuildAddonIndex, shared by a whole scan.
function Mod:GetAddonStatus(addon, addonIndex)
    addonIndex = addonIndex or BuildAddonIndex()
    local info = type(addon) == "string" and addonIndex[addon:lower()] or nil
    local status = {
        name = addon,
        title = addon,
        installed = info ~= nil,
        enabled = false,
        loaded = false,
        active = false,
        ignored = false,
        conflict = false,
    }
    if not info then return status end

    -- The folder name as installed; the rule may differ in letter case.
    local name = info.name
    status.name = name
    status.title = info.title or name
    status.notes = info.notes
    status.security = info.security
    status.loaded = IsAddonLoadedSafe(name)

    local state = GetAddonEnableStateSafe(name)
    local loadable, reason = GetAddonLoadableSafe(name, info)
    local enabled
    if state ~= nil then
        enabled = state > 0
    else
        enabled = loadable == true
    end
    if reason == "DISABLED" then
        enabled = false
    end
    status.enabled = enabled
    status.loadable = loadable
    status.reason = reason

    -- Enabled but unable to load (missing dependency, out of date...): it
    -- will not run after a reload, so it cannot interfere with KUI.
    status.blocked = enabled and not status.loaded and loadable == false
        and reason ~= nil and BLOCKING_REASONS[reason] == true or false

    status.active = status.loaded or (enabled and not status.blocked) or false
    status.ignored = self:IsIgnored(name)
    status.conflict = status.active and not status.ignored
    return status
end

function Mod:GetAddonIcon(addonName, ruleId)
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    if getMetadata and addonName then
        for _, key in ipairs({ "IconTexture", "X-Icon", "Icon", "X-Texture" }) do
            local ok, value = pcall(getMetadata, addonName, key)
            if ok and value and value ~= "" then
                return tonumber(value) or value
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

-- Calls Enable/DisableAddOn for this character (GUID first, as Blizzard's own
-- AddOn list does), falling back to the name and then to all characters.
local function SetAddonState(addonName, enable)
    local modern = C_AddOns and (enable and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn)
    local legacy = enable and _G.EnableAddOn or _G.DisableAddOn
    local fn = modern or legacy
    if not fn then return false end
    for _, key in ipairs(GetCharacterKeys()) do
        if pcall(fn, addonName, key) then return true end
    end
    return pcall(fn, addonName) and true or false
end

function Mod:DisableAddon(addonName)
    if not addonName or addonName == "" then
        return false, "invalid"
    end

    local db = EnsureDB()
    local disabled = SetAddonState(addonName, false)
    if disabled and db then
        db.pendingReload[addonName] = true
    end
    self.lastReport = nil
    return disabled
end

function Mod:EnableAddon(addonName)
    if not addonName or addonName == "" then
        return false, "invalid"
    end

    local db = EnsureDB()
    local enabled = SetAddonState(addonName, true)
    if enabled and db then
        db.pendingReload[addonName] = true
        db.ignored[addonName] = nil
    end
    self.lastReport = nil
    return enabled
end

local function IsConflicting(addon)
    if not addon then return false end
    if addon.conflict ~= nil then return addon.conflict end
    return (addon.loaded or addon.enabled) and true or false
end

function Mod:IsConflicting(addon)
    return IsConflicting(addon)
end

-- Disables every conflicting addon of the active conflicts at once, so the
-- user does one reload instead of one per addon. Returns how many were
-- disabled and how many could not be. Ignored addons are left alone.
function Mod:DisableAllConflicts(active)
    active = active or self:GetActiveConflicts(self:Scan())
    local seen, disabled, failed = {}, 0, 0
    for _, entry in ipairs(active or {}) do
        for _, addon in ipairs(entry.addons or {}) do
            local name = addon and addon.name
            if name and not seen[name] and IsConflicting(addon) and not self:HasPendingReload(name) then
                seen[name] = true
                if self:DisableAddon(name) then
                    disabled = disabled + 1
                else
                    failed = failed + 1
                end
            end
        end
    end
    return disabled, failed
end

function Mod:EnableAddonAndDisableKUIRule(addonName, ruleId)
    local addonEnabled = self:EnableAddon(addonName)
    if not addonEnabled then
        return false, false, false, nil
    end

    local moduleDisabled, label = self:DisableKUIRule(ruleId)
    return addonEnabled and moduleDisabled, addonEnabled, moduleDisabled, label
end

-- Every rule that has at least one installed addon. An entry is a conflict
-- (hasLoaded) when one of its addons runs, or will run after a reload, and
-- was not ignored by the player. Rules for KUI modules that are turned off
-- are skipped: nothing overlaps a disabled module.
function Mod:Scan()
    local results = {}
    local addonIndex = BuildAddonIndex()
    local statusCache = {}

    for _, rule in ipairs(self:GetRules()) do
        if rule.enabled ~= false and IsRuleRelevant(rule) then
            local addons = {}
            local seen = {}
            local hasLoaded = false

            for _, addon in ipairs(rule.addons or {}) do
                local key = type(addon) == "string" and addon:lower() or nil
                if key and addonIndex[key] and not seen[key] then
                    seen[key] = true
                    local st = statusCache[key]
                    if not st then
                        st = self:GetAddonStatus(addon, addonIndex)
                        statusCache[key] = st
                    end
                    if st.conflict then
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

-- Active conflicts at or above the severity the player wants to be warned
-- about at login (popup and installer page).
function Mod:GetNotifiableConflicts(report)
    local db = EnsureDB()
    local minWeight = GetSeverityWeight(db and db.popupSeverity or "low")
    local list = {}
    for _, entry in ipairs(self:GetActiveConflicts(report)) do
        if GetSeverityWeight(entry.rule and entry.rule.severity) >= minWeight then
            list[#list + 1] = entry
        end
    end
    return list
end

function Mod:GetUniqueAddonCount(report, activeOnly)
    local seen = {}
    local count = 0
    for _, entry in ipairs(report or {}) do
        for _, addon in ipairs(entry.addons or {}) do
            local qualifies = addon and (addon.installed ~= false)
            if activeOnly then
                qualifies = qualifies and IsConflicting(addon)
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

local POPUP_KEY = "KT_ADDON_CONFLICTS"

function Mod:HideConflictPopup()
    if _G.StaticPopup_Hide then
        _G.StaticPopup_Hide(POPUP_KEY)
    end
end

function Mod:NotifyIfConflicts(report)
    local db = EnsureDB()
    if not db or not db.notify then return end
    if db.dontShowAgain then return end
    local active = self:GetNotifiableConflicts(report)
    if #active == 0 then return end

    local count = self:GetUniqueAddonCount(active, true)

    -- The installer opens with its own conflict page (KT:ProcessLoginPopups):
    -- a second popup on top of it, or of its reload prompt, only got in the way.
    -- The installer also hides this popup when its conflict page appears later.
    local installerDb = KT.db and KT.db.profile and KT.db.profile.installer
    local installerFrame = _G.KullThranUIInstallerFrame
    local installerPending = (installerFrame and installerFrame:IsShown())
        or (installerDb and KT:GetModule("Installer", true) and installerDb.dontShowAgain ~= true and (installerDb.showOnLogin
            or installerDb.reopenOnReload or installerDb.reopenStep or installerDb.resumeStep))
    if installerPending then return end

    local msg = string.format(LText("KullThranUI: Possible conflicts with other addons (%d). Open the Compatibility panel to review."), count)
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
            if IsConflicting(addon) and addon.name and not seen[addon.name] then
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

    if not _G.StaticPopupDialogs[POPUP_KEY] then
        _G.StaticPopupDialogs[POPUP_KEY] = {
            text = "%s",
            button1 = LText("Open Compatibility"),
            button2 = _G.CLOSE or "Close",
            button3 = LText("Disable All & Reload"),
            OnAlt = function()
                local detector = KT and KT.GetModule and KT:GetModule("AddonConflictDetector", true)
                local disabled = detector and detector:DisableAllConflicts() or 0
                if disabled > 0 and ReloadUI then ReloadUI() end
            end,
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
