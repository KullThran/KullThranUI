-- Aura Reminders options: the Custom Auras page, the registration of all pages, the two slash commands.
-- Keeps every behaviour the specification flags as a suspected bug. No client difference: ctx.client selects nothing.
--
-- Layout: a toolbar (New Aura, Import, Move on Screen), the list of the player's auras on the left and, on the right,
-- the template gallery while creating or the editor of the selected aura. Every action has an own icon
-- (tools/photoshop/aura_reminders_icons.jsx) next to its text; deleting asks once more inline and can be undone for
-- the session. Sliders write the aura and redraw it without rebuilding the page, so a drag is never cut.

local _, ns = ...
local KT = ns.KT or (LibStub and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))
if not KT then return end

local M = {}
ns.AuraRemindersPageCustom = M

-- Set by Setup.
local S, P, Reminders, Talents, Cards

-- Session state, never saved: the selected aura, the editor's tab, the trigger being edited, the list's search,
-- whether the template gallery is open, the aura waiting for a second click to be deleted, and the last deleted aura
-- (for Undo).
local embeddedView = true
local selectedID
local selectedTab = "trigger"
local selectedTrigger = 1
local searchText = ""
local creating = false
local confirmDeleteID
local lastDeleted

-- Own art in Media\icons (tools/photoshop/aura_reminders_icons.jsx): pale grey, tinted with the accent.
local ICONS = "Interface\\AddOns\\KullThranUI_AuraReminders\\Modules\\KUIAuraReminders\\Media\\icons\\"

-- The editor's tabs, in order, with their icons.
local TABS = {
    { id = "trigger", label = "Trigger", icon = "tab_trigger" },
    { id = "stacks", label = "Stacks", icon = "tab_stacks" },
    { id = "display", label = "Display", icon = "tab_display" },
    { id = "conditions", label = "Conditions", icon = "tab_conditions" },
    { id = "load", label = "Loading", icon = "tab_load" },
    { id = "animations", label = "Animations", icon = "tab_anim" },
    { id = "sound", label = "Sound", icon = "tab_sound" },
}

-- Capability badges: what an option does in restricted combat on this client (E.Caps).
local BADGES = {
    combat = { "Works in Combat", 0.35, 0.85, 0.45 },
    ooc = { "Out of Combat Only", 1, 0.72, 0.25 },
    none = { "Not on This Client", 0.6, 0.6, 0.6 },
}

-- Fields each template record shares, then each template's own. Exact and not localised.
local SHARED_FIELDS = {
    enabled = true, opacity = 1.0, showGlow = false, size = 40, point = "CENTER", relativePoint = "CENTER",
    xOffset = 0, yOffset = 0, loadInstance = "ANY",
}
local TEMPLATE_FIELDS = {
    blank = {
        name = "New Aura", triggerType = "AURA", triggerSpellID = 17, triggerAuraType = "HELPFUL",
        triggerUnit = "player", triggerAuraMissing = false, loadCombat = "ANY",
    },
    defensive = {
        name = "Defensive CD", triggerType = "COOLDOWN", triggerSpellID = 108271, loadCombat = "IN_COMBAT",
    },
    offensive = {
        name = "Offensive Buff", triggerType = "AURA", triggerSpellID = 31884, triggerAuraType = "HELPFUL",
        triggerUnit = "player", triggerAuraMissing = false, loadCombat = "IN_COMBAT",
    },
    debuff = {
        name = "Important Debuff", triggerType = "AURA", triggerSpellID = 0, triggerAuraType = "HARMFUL",
        triggerUnit = "player", triggerAuraMissing = false, loadCombat = "ANY", size = 55, showGlow = true,
    },
    -- A buff the Cooldown Manager tracks: readable in combat, "missing" included.
    cdm = {
        name = "Tracked Buff", triggerType = "CDM", triggerSpellID = 0, triggerAuraMissing = false, loadCombat = "ANY",
    },
    -- A buff counted by its stacks: the count on the icon and a bar filled by them.
    stacks = {
        name = "Stacking Buff", triggerType = "AURA", triggerSpellID = 0, triggerAuraType = "HELPFUL",
        triggerUnit = "player", triggerAuraMissing = false, loadCombat = "ANY", customTextType = "STACKS",
        displayStyle = "BAR", barFill = "STACKS", stackMax = 5, stackAlert = 5,
    },
    -- Always on screen: greyed out with its swipe while the spell is on cooldown, bright when it is ready.
    cdtracker = {
        name = "Cooldown Tracker", triggerType = "COOLDOWN", triggerSpellID = 0, triggerCooldownReady = true,
        inactiveMode = "DESATURATE", showSwipe = true, customTextType = "DURATION", loadCombat = "ANY",
    },
    -- The player's health at 35% or less: a pulsing icon with the percentage.
    lowhealth = {
        name = "Low Health", triggerType = "HEALTH", triggerUnit = "player", triggerOp = "LE", triggerValue = 35,
        triggerValueMode = "PERCENT", customTextType = "TOKENS", customTextValue = "%p%%", showGlow = true,
        animMain = "PULSE", loadCombat = "ANY",
    },
    -- The player's main power as a bar with its value.
    resource = {
        name = "Resource Bar", triggerType = "POWER", triggerUnit = "player", triggerPowerType = -1, triggerOp = "NONE",
        displayStyle = "BAR", barFill = "VALUE", barWidth = 200, size = 24, customTextType = "TOKENS",
        customTextValue = "%v / %m", loadCombat = "ANY",
    },
    -- The target's cast as a bar with its remaining time.
    enemycast = {
        name = "Enemy Cast", triggerType = "CAST", triggerUnit = "target", triggerSpellID = 0, displayStyle = "BAR",
        barColor = { r = 0.95, g = 0.55, b = 0.15 }, customTextType = "DURATION", size = 28, loadCombat = "ANY",
    },
}

-- The gallery: template key, label, description, icon.
local GALLERY = {
    { "blank", "Blank Canvas", "Start from scratch", "blank" },
    { "defensive", "Defensive CD", "Tracks a cooldown", "defensive" },
    { "offensive", "Offensive Buff", "Tracks your buff", "offensive" },
    { "debuff", "Big Debuff", "Important warning", "debuff" },
    { "cdm", "Tracked Buff", "Buff from the Cooldown Manager", "cdm" },
    { "stacks", "Stacking Buff", "Counts the stacks of a buff", "tab_stacks" },
    { "cdtracker", "Cooldown Tracker", "Always shown, greyed while on cooldown", "tab_trigger" },
    { "lowhealth", "Low Health", "Warns when your health is low", "debuff" },
    { "resource", "Resource Bar", "Shows your power as a bar", "upkeep" },
    { "enemycast", "Enemy Cast", "Your target's cast as a bar", "control" },
}

-- What each trigger type is called in the list and the editor. Exact and not localised.
local KIND_LABELS = {
    AURA = "Aura", COOLDOWN = "Spell Cooldown", CDM = "Cooldown Manager Buff", CHARGES = "Spell Charges",
    USABLE = "Spell Usable", ITEM = "Item", HEALTH = "Health", POWER = "Power", CAST = "Casting",
    STATE = "Player State",
}
local KIND_ORDER = { "AURA", "COOLDOWN", "CDM", "CHARGES", "USABLE", "ITEM", "HEALTH", "POWER", "CAST", "STATE" }

-- Power types by their Enum.PowerType number; -1 is the unit's main power.
local POWER_LABELS = {
    [-1] = "Main Power", [0] = "Mana", [1] = "Rage", [2] = "Focus Power", [3] = "Energy", [4] = "Combo Points",
    [6] = "Runic Power", [7] = "Soul Shards", [9] = "Holy Power", [11] = "Maelstrom", [12] = "Chi",
    [13] = "Insanity", [16] = "Arcane Charges", [17] = "Fury", [19] = "Essence",
}
local POWER_ORDER = { -1, 0, 1, 2, 3, 4, 6, 7, 9, 11, 12, 13, 16, 17, 19 }

local STATE_LABELS = {
    combat = "In Combat", group = "In a Group", raid = "In a Raid", solo = "Solo", resting = "Resting",
    mounted = "Mounted", stealthed = "Stealthed", flying = "Flying", target = "Has a Target",
    attackable = "Target Can Be Attacked",
}
local STATE_ORDER = { "combat", "group", "raid", "solo", "resting", "mounted", "stealthed", "flying", "target",
    "attackable" }

local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
    "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
-- Classes the Forever client does not have.
local NOT_ON_FOREVER = { DEATHKNIGHT = true, MONK = true, DEMONHUNTER = true, EVOKER = true }

local function Engine()
    return ns.AuraEngine
end

local function ProfilesModule()
    local ok, mod = pcall(KT.GetModule, KT, "Profiles", true)
    return ok and mod or nil
end

local function UnlockModule()
    if type(KT.GetModule) ~= "function" then return nil end
    local ok, mod = pcall(KT.GetModule, KT, "UnlockMode", true)
    return ok and mod or nil
end

local function Notify(text)
    if KT.Print then
        KT:Print(text)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

local function LocalText(text)
    local options = KT.Options
    return options and options.LText and options.LText(text) or text
end

-- `template` is a key of TEMPLATE_FIELDS or the fields themselves (class templates).
local function newRecord(template)
    local fields = type(template) == "table" and template or TEMPLATE_FIELDS[template]
    local record = {}
    for k, v in pairs(SHARED_FIELDS) do record[k] = v end
    for k, v in pairs(fields) do record[k] = v end
    -- Saved in the player's language: the name is shown as written from then on. A class template's name is the
    -- client's own spell name, already in that language.
    if record.name and type(template) ~= "table" then record.name = LocalText(record.name) end
    return record
end

-- aura_ followed by the time as text with its point removed; a taken ID gets _2, _3... so no aura is replaced.
local function newAuraID(auras)
    local base = "aura_" .. tostring(GetTime()):gsub("%.", "")
    local id, n = base, 1
    while auras[id] ~= nil do
        n = n + 1
        id = base .. "_" .. n
    end
    return id
end

-- The auras redrawn; the page stays as it is (sliders, colours: nothing on the page changes).
local function Redraw()
    local custom = _G.KUIAuraReminders_Custom
    if custom and custom.ForceUpdate then custom:ForceUpdate() end
end

-- Page rebuild, then the runtime's update. Each part only when present.
local function Refresh()
    if KT.RefreshPage then KT:RefreshPage(true) end
    Redraw()
end

local function templateFontPath()
    return KT.ResolveFontPath and KT:ResolveFontPath() or "Fonts\\FRIZQT__.TTF"
end

-- A page rebuild only: the auras themselves do not change.
local function RebuildPage()
    if KT.RefreshPage then KT:RefreshPage(true) end
end

local function Trim(text)
    if type(text) ~= "string" then return "" end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Accent()
    if KT.GetStyleAccentRGB then return KT:GetStyleAccentRGB() end
    return 1, 0.82, 0
end

-- Own art tinted with the accent, or a plain grey where the core cannot tint.
local function TintIcon(tex, active)
    if active ~= false and KT.SetAccentVertexColor then
        KT:SetAccentVertexColor(tex, 1)
    elseif active == false then
        tex:SetVertexColor(0.55, 0.55, 0.55, 1)
    end
end

local function ShowTip(owner, title, text)
    local tip = _G.GameTooltip
    if not tip then return end
    tip:SetOwner(owner, "ANCHOR_TOP")
    tip:SetText(title or "", 1, 1, 1)
    if text then tip:AddLine(text, 0.8, 0.8, 0.8, true) end
    tip:Show()
end

local function HideTip()
    local tip = _G.GameTooltip
    if tip then tip:Hide() end
end

-- A badge at the right end of a section header; its tooltip gives the reason.
local function attachBadge(widget, cap, L)
    local look = cap and BADGES[cap.level]
    if not (look and widget) then return end
    local badge = CreateFrame("Frame", nil, widget)
    badge:SetSize(150, 16)
    badge:SetPoint("RIGHT", widget, "RIGHT", -6, 0)
    local text = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetFont(templateFontPath(), 10, "")
    text:SetPoint("RIGHT", badge, "RIGHT", 0, 0)
    text:SetText(L(look[1]))
    text:SetTextColor(look[2], look[3], look[4])
    badge:EnableMouse(true)
    badge:SetScript("OnEnter", function(self)
        local tip = _G.GameTooltip
        if not tip then return end
        tip:SetOwner(self, "ANCHOR_TOP")
        tip:SetText(L(look[1]), look[2], look[3], look[4])
        if cap.reason then tip:AddLine(L(cap.reason), 1, 1, 1, true) end
        tip:Show()
    end)
    badge:SetScript("OnLeave", function()
        local tip = _G.GameTooltip
        if tip then tip:Hide() end
    end)
    badge.cap = cap
    widget.kuiBadge = badge
end

-- Accent header over a column.
local function columnHeader(column, localised, y)
    return KT.Widgets:Label(column, S.AccentColorCode() .. localised .. "|r", -y, 14)
end

-- Buttons -------------------------------------------------------------------------------------------------------------

local EDGE = { 0.25, 0.25, 0.25 }
local EDGE_HOVER = { 0.6, 0.6, 0.6 }
local DANGER_EDGE = { 0.85, 0.25, 0.25 }

-- A flat button with an own icon and its text. opts: tip (tooltip line), danger (red), fontSize, dim (grey icon).
local function actionButton(parent, x, y, width, height, icon, text, onClick, opts)
    opts = opts or {}
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    local edge = opts.danger and DANGER_EDGE or EDGE
    if opts.active then
        local r, g, b = 1, 0.6, 0.4
        if KT.GetStyleAccentRGB then r, g, b = KT:GetStyleAccentRGB() end
        edge = { r, g, b }
    end
    if opts.danger then
        KT:AddBackdrop(b, 0.30, 0.06, 0.06, 0.95)
    else
        KT:AddBackdrop(b, 0.08, 0.10, 0.13, 0.95)
    end
    KT:AddBorder(b, edge[1], edge[2], edge[3], 1)

    local tex = b:CreateTexture(nil, "ARTWORK")
    local size = math.min(height - 10, 22)
    tex:SetSize(size, size)
    tex:SetTexture(ICONS .. icon .. ".png")
    if opts.danger then
        tex:SetVertexColor(1, 0.5, 0.5, 1)
    else
        TintIcon(tex, not opts.dim)
    end

    local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetFont(templateFontPath(), opts.fontSize or 12)
    label:SetText(text or "")
    if text and text ~= "" then
        tex:SetPoint("LEFT", b, "LEFT", 8, 0)
        label:SetPoint("LEFT", tex, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    else
        tex:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    if opts.danger then label:SetTextColor(1, 0.85, 0.85) else label:SetTextColor(1, 1, 1) end

    b:SetScript("OnEnter", function(self)
        KT:AddBorder(self, EDGE_HOVER[1], EDGE_HOVER[2], EDGE_HOVER[3], 1)
        if opts.tip then ShowTip(self, opts.tipTitle or text, opts.tip) end
    end)
    b:SetScript("OnLeave", function(self)
        KT:AddBorder(self, edge[1], edge[2], edge[3], 1)
        HideTip()
    end)
    b:SetScript("OnClick", onClick)
    b.icon, b.label, b.kuiAction = tex, label, icon
    return b
end

-- Actions -------------------------------------------------------------------------------------------------------------

local function selectAura(id)
    if id ~= selectedID then selectedTrigger = 1 end
    selectedID, creating, confirmDeleteID = id, false, nil
end

local function createFrom(profile, template)
    local id = newAuraID(profile.customAuras)
    profile.customAuras[id] = newRecord(template)
    selectAura(id)
    selectedTab = "trigger"
    Refresh()
end

-- The first click asks, the second deletes; the aura can be brought back for the session.
local function requestDelete(profile, id)
    if confirmDeleteID ~= id then
        confirmDeleteID = id
        RebuildPage()
        return
    end
    lastDeleted = { id = id, conf = profile.customAuras[id] }
    profile.customAuras[id] = nil
    if selectedID == id then selectedID = nil end
    confirmDeleteID = nil
    Refresh()
end

local function undoDelete(profile)
    local entry = lastDeleted
    if not (entry and entry.conf) then return end
    local id = entry.id
    if profile.customAuras[id] ~= nil then id = newAuraID(profile.customAuras) end
    profile.customAuras[id] = entry.conf
    lastDeleted = nil
    selectAura(id)
    Refresh()
end

-- KUI's unlock mode places the auras with every other element; without it, the page's own placing mode.
local function moveOnScreen()
    local um = UnlockModule()
    if um and um.OpenUnlockMode then
        um:OpenUnlockMode()
        return
    end
    local runtime = _G.KUIAuraReminders_Custom
    if not runtime then return end
    runtime:SetUnlockMode(not runtime.UnlockMode)
    Refresh()
end

local function importAuras(profile, L)
    local profiles = ProfilesModule()
    local engine = Engine()
    if not (profiles and profiles.ShowImportPopup and engine and engine.Codec) then return end
    profiles:ShowImportPopup(L("Import Auras"), L("Paste a KUI aura string. The auras are added; nothing is replaced."),
        function(text)
            -- Strings of the full aura engine belong to the Full Aura Editor: switch to it and import there.
            local embedded = ns.AuraRemindersEmbedded
            if embedded and embedded.IsEngineString and embedded.IsEngineString(text) then
                embeddedView = true
                embedded.Import(text)
                RebuildPage()
                return true
            end
            local ids, result = engine.Codec.Import(profile, text)
            if not ids then error(L(result), 0) end
            for _, warning in ipairs(result) do Notify(L(warning)) end
            selectAura(ids[1])
            Refresh()
            return true
        end)
end

-----------------------------------------------------------------------------------------------------------------------
-- Toolbar
-----------------------------------------------------------------------------------------------------------------------

-- Returns the toolbar's height.
local function buildToolbar(parent, L, profile, y)
    local runtime = _G.KUIAuraReminders_Custom
    local placing = runtime and runtime.UnlockMode and not UnlockModule()
    local moveText = placing and L("Lock Custom Auras") or L("Move on Screen")
    actionButton(parent, 0, y, 170, 34, "ed_new", L("New Aura"), function()
        creating, confirmDeleteID = true, nil
        RebuildPage()
    end, { tip = L("Choose a template to start from.") })
    actionButton(parent, 180, y, 150, 34, "ed_import", L("Import Auras"), function()
        confirmDeleteID = nil
        importAuras(profile, L)
    end, { tip = L("Paste a KUI aura string. The auras are added; nothing is replaced.") })
    actionButton(parent, 340, y, 190, 34, "ed_move", moveText, moveOnScreen,
        { tip = L("Opens the unlock mode: drag each aura or group where you want it.") })
    return 34
end

-----------------------------------------------------------------------------------------------------------------------
-- Left column: the list
-----------------------------------------------------------------------------------------------------------------------

local LIST_W = 210
local ROW_H = 38

-- What the row says under the name: the first trigger, its spell or item, and how many more triggers there are.
local function rowSubtitle(conf, L)
    local kind = L(KIND_LABELS[conf.triggerType] or "Aura")
    local id = tonumber(conf.triggerType == "ITEM" and conf.triggerItemID or conf.triggerSpellID)
    local text = kind
    if id and id > 0 then text = kind .. " · " .. id end
    local extra = type(conf.extraTriggers) == "table" and #conf.extraTriggers or 0
    if extra > 0 then text = text .. " +" .. extra end
    return text
end

-- The icon an aura shows, as the engine picks it (its own spell, an item, the trigger's spell).
local function confTexture(conf)
    local engine = Engine()
    local record = engine and engine.Migrate and engine.Migrate(conf)
    if record and engine.IconTexture then return engine.IconTexture(record, nil, P.Tex) end
    return P.Tex(tonumber(conf.triggerSpellID) or 0)
end

local function buildListRow(column, L, profile, top, id, conf)
    local selected = id == selectedID
    local asking = id == confirmDeleteID
    local name = conf.name or LocalText("Unnamed")
    local b = CreateFrame("Button", nil, column)
    b:SetSize(LIST_W, ROW_H - 2)
    b:SetPoint("TOPLEFT", 5, -top)

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local idle = selected and 0.12 or 0.05
    bg:SetColorTexture(1, 1, 1, idle)
    if selected then
        local bar = b:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        bar:SetWidth(3)
        local r, g, bl = Accent()
        bar:SetColorTexture(r, g, bl, 1)
    end

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", b, "LEFT", 7, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetTexture(confTexture(conf))
    if not conf.enabled then icon:SetVertexColor(0.4, 0.4, 0.4, 1) end

    local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetFont(templateFontPath(), 12)
    text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 7, -1)
    text:SetPoint("RIGHT", b, "RIGHT", -60, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(name)
    if conf.enabled then
        text:SetTextColor(1, 1, 1)
    else
        text:SetTextColor(0.5, 0.5, 0.5)
    end

    local sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetFont(templateFontPath(), 10)
    sub:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 7, 1)
    sub:SetPoint("RIGHT", b, "RIGHT", -60, 0)
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(false)
    if asking then
        sub:SetText(L("Delete? Click again."))
        sub:SetTextColor(1, 0.45, 0.45)
    else
        sub:SetText(rowSubtitle(conf, L))
        sub:SetTextColor(0.55, 0.55, 0.55)
    end

    b:SetScript("OnEnter", function() bg:SetColorTexture(1, 1, 1, idle + 0.07) end)
    b:SetScript("OnLeave", function() bg:SetColorTexture(1, 1, 1, idle) end)
    b:SetScript("OnClick", function()
        selectAura(id)
        RebuildPage()
    end)

    -- Show or hide, and delete: square targets at the row's right end, each with its tooltip.
    local eye = actionButton(b, LIST_W - 58, 6, 24, 24, conf.enabled and "ed_on" or "ed_off", "", function()
        conf.enabled = not conf.enabled
        confirmDeleteID = nil
        Refresh()
    end, { tipTitle = conf.enabled and L("Enabled") or L("Disabled"), tip = L("Click to turn this aura on or off."),
        dim = not conf.enabled })
    eye.kuiRole = "toggle"
    local trash = actionButton(b, LIST_W - 30, 6, 24, 24, "ed_delete", "", function() requestDelete(profile, id) end,
        { tipTitle = L("Delete Aura"), tip = asking and L("Click again to delete it.") or L("Asks once more first."),
            danger = asking })
    trash.kuiRole = "delete"
    b.kuiID = id
    return b
end

-- Whether a record matches the search: its name or group contains the text, or its spell ID is the text.
local function matchesSearch(conf, query)
    if query == "" then return true end
    query = query:lower()
    local name = type(conf.name) == "string" and conf.name:lower() or LocalText("Unnamed"):lower()
    if name:find(query, 1, true) then return true end
    if type(conf.group) == "string" and conf.group:lower():find(query, 1, true) then return true end
    return tostring(conf.triggerSpellID) == query or tostring(conf.triggerItemID) == query
end

-- Returns the column's used height.
local function buildLeftColumn(column, L, profile)
    local W = KT.Widgets
    local left = 0
    local rows, total = {}, 0
    for id, conf in pairs(profile.customAuras) do
        total = total + 1
        if matchesSearch(conf, searchText) then
            local group = type(conf.group) == "string" and conf.group ~= "" and conf.group or nil
            rows[#rows + 1] = { id = id, conf = conf, name = conf.name or LocalText("Unnamed"), group = group }
        end
    end

    local _, h = columnHeader(column, string.format(L("YOUR AURAS (%d)"), total), left)
    left = left + h + 5

    if lastDeleted and lastDeleted.conf then
        local name = lastDeleted.conf.name or LocalText("Unnamed")
        actionButton(column, 5, left, LIST_W, 30, "ed_undo", string.format(L("Undo Delete: %s"), name),
            function() undoDelete(profile) end, { tip = L("Brings the deleted aura back.") })
        left = left + 36
    end

    if total == 0 then
        local _, nh = W:Label(column, L("You have no custom auras yet. Press New Aura to make one from a template."),
            -left, 12, { r = 0.7, g = 0.7, b = 0.7 })
        return left + nh
    end

    -- The search shows once there is something to search.
    local _, sh = W:Input(column, L("Search (name, group or spell ID)"), -left, function() return searchText end,
        function(text)
            searchText = Trim(text)
            RebuildPage()
        end)
    left = left + sh + 5

    -- Ungrouped auras first, then each group under its name; by name inside.
    table.sort(rows, function(a, b)
        if (a.group or "") ~= (b.group or "") then return (a.group or "") < (b.group or "") end
        return a.name < b.name
    end)
    local counts = {}
    for _, row in ipairs(rows) do
        if row.group then counts[row.group] = (counts[row.group] or 0) + 1 end
    end
    local lastGroup
    for _, row in ipairs(rows) do
        if row.group and row.group ~= lastGroup then
            lastGroup = row.group
            local _, gh = W:Label(column, string.format(L("Group: %s (%d)"), row.group, counts[row.group]), -left, 11,
                { r = 0.6, g = 0.6, b = 0.6 })
            left = left + gh
        end
        buildListRow(column, L, profile, left, row.id, row.conf)
        left = left + ROW_H
    end
    if #rows == 0 then
        local _, nh = W:Label(column, L("No aura matches the search."), -left, 11, { r = 0.6, g = 0.6, b = 0.6 })
        left = left + nh
    end
    return left
end

-----------------------------------------------------------------------------------------------------------------------
-- Right column: the gallery
-----------------------------------------------------------------------------------------------------------------------

local TILE_H = 58

local function buildTemplateButton(column, x, top, width, text, description, iconID, template, profile)
    -- `template`: a key of TEMPLATE_FIELDS or the record's own fields.
    local b = CreateFrame("Button", nil, column)
    b:SetSize(width, TILE_H - 6)
    b:SetPoint("TOPLEFT", x, -top)
    KT:AddBackdrop(b, 0.08, 0.10, 0.13, 0.9)
    KT:AddBorder(b, 0.2, 0.2, 0.2, 1)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("LEFT", b, "LEFT", 9, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- A number is a spell (class templates): its own icon. Text is a file of own art: tinted with the accent.
    if type(iconID) == "string" then
        icon:SetTexture(iconID)
        if KT.SetAccentVertexColor then KT:SetAccentVertexColor(icon, 1) end
    else
        icon:SetTexture(P.Tex(iconID))
    end

    -- Both font strings have a font from their template at creation.
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, -2)
    label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    label:SetFont(templateFontPath(), 13)
    local r, g, bl = Accent()
    label:SetTextColor(r, g, bl)

    local desc = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 9, 2)
    desc:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText(description)
    desc:SetFont(templateFontPath(), 11)
    desc:SetTextColor(0.6, 0.6, 0.6)

    b:SetScript("OnEnter", function(self) KT:AddBorder(self, 0.6, 0.6, 0.6, 1) end)
    b:SetScript("OnLeave", function(self) KT:AddBorder(self, 0.2, 0.2, 0.2, 1) end)
    b:SetScript("OnClick", function() createFrom(profile, template) end)
    return b
end

-- Two tiles a row. Returns the column's used height.
local function buildGallery(column, L, profile, total)
    local width = math.max(column:GetWidth(), 300)
    local tileW = math.floor((width - 15) / 2)
    local top = 0
    local _, h = columnHeader(column, L("CHOOSE A STARTING POINT"), top)
    top = top + h + 5
    for i, t in ipairs(GALLERY) do
        local x = ((i - 1) % 2) * (tileW + 5) + 5
        buildTemplateButton(column, x, top, tileW, L(t[2]), L(t[3]), ICONS .. t[4] .. ".png", t[1], profile)
        if i % 2 == 0 or i == #GALLERY then top = top + TILE_H end
    end
    top = top + 10

    -- The major cooldowns of the player's class that the character knows, for this client.
    local engine = Engine()
    local classTemplates = engine and engine.Templates and engine.Templates.ForPlayer() or {}
    if #classTemplates > 0 then
        _, h = columnHeader(column, L("CLASS TEMPLATES"), top)
        top = top + h + 5
        local shown = math.min(#classTemplates, 6)
        for i = 1, shown do
            local entry = classTemplates[i]
            local fields = engine.Templates.Record(entry)
            local description = entry.role == "offensive" and L("Offensive cooldown ready")
                or L("Defensive cooldown ready")
            local x = ((i - 1) % 2) * (tileW + 5) + 5
            buildTemplateButton(column, x, top, tileW, fields.name, description, entry.spellID, fields, profile)
            if i % 2 == 0 or i == shown then top = top + TILE_H end
        end
        top = top + 10
    end

    if total > 0 then
        actionButton(column, 5, top, 150, 30, "ed_undo", L("Cancel"), function()
            creating = false
            RebuildPage()
        end)
        top = top + 36
    end
    return top
end

-----------------------------------------------------------------------------------------------------------------------
-- Right column: the editor
-----------------------------------------------------------------------------------------------------------------------

-- With the engine: the aura drawn as in play with mock data (E.Preview.Attach keeps it redrawn, so edits show at
-- once). Without it: the spell's icon.
local function buildPreview(column, conf)
    local engine = Engine()
    if engine and engine.Preview and engine.Preview.Attach then
        local host = CreateFrame("Frame", nil, column)
        host:SetSize(260, 56)
        host:SetPoint("TOP", column, "TOP", 0, -5)
        engine.Preview.Attach(host, conf)
        return
    end
    local frame = CreateFrame("Frame", nil, column)
    frame:SetSize(56, 56)
    frame:SetPoint("TOP", column, "TOP", 0, -5)
    KT:AddBackdrop(frame, 0.05, 0.07, 0.09, 1)
    KT:AddBorder(frame, 0.4, 0.4, 0.4, 1)
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    tex:SetTexture(confTexture(conf))
end

-- The tab strip: an own icon over each label; the selected tab is tinted and underlined with the accent.
local function buildTabs(column, L, top, current)
    local width = math.max(column:GetWidth() - 20, 300)
    local tabW = math.floor(width / #TABS)
    local height = 50
    local strip = CreateFrame("Frame", nil, column)
    strip:SetSize(tabW * #TABS, height)
    strip:SetPoint("TOPLEFT", column, "TOPLEFT", 10, -top)
    local line = strip:CreateTexture(nil, "BACKGROUND")
    line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, 0.12)
    for i, t in ipairs(TABS) do
        local on = t.id == current
        local b = CreateFrame("Button", nil, strip)
        b:SetSize(tabW, height)
        b:SetPoint("TOPLEFT", strip, "TOPLEFT", (i - 1) * tabW, 0)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, on and 0.08 or 0)
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("TOP", b, "TOP", 0, -5)
        icon:SetTexture(ICONS .. t.icon .. ".png")
        TintIcon(icon, on)
        local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetFont(templateFontPath(), 11)
        label:SetPoint("BOTTOM", b, "BOTTOM", 0, 6)
        label:SetWidth(tabW - 4)
        label:SetWordWrap(false)
        label:SetText(L(t.label))
        if on then
            local r, g, bl = Accent()
            label:SetTextColor(r, g, bl)
            local under = b:CreateTexture(nil, "ARTWORK")
            under:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 0)
            under:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 0)
            under:SetHeight(2)
            under:SetColorTexture(r, g, bl, 1)
        else
            label:SetTextColor(0.7, 0.7, 0.7)
        end
        b:SetScript("OnEnter", function() if not on then bg:SetColorTexture(1, 1, 1, 0.05) end end)
        b:SetScript("OnLeave", function() if not on then bg:SetColorTexture(1, 1, 1, 0) end end)
        b:SetScript("OnClick", function()
            selectedTab, confirmDeleteID = t.id, nil
            RebuildPage()
        end)
        b.kuiTab = t.id
    end
    strip.kuiTabs = true
    return strip, height
end

-- Builds the editor for one record and returns the column's used height. The name and the actions stay on top; the
-- options are split in tabs. With the engine, each section header carries the badge of what its options do in combat.
local function buildEditor(column, L, profile, id, conf)
    local W = KT.Widgets
    buildPreview(column, conf)
    local right = 70
    local engine = Engine()
    local caps = engine and engine.Caps and engine.Caps.Of(conf) or {}

    local function get(key, fallback)
        if fallback == nil then
            return function() return conf[key] end
        end
        return function() return conf[key] or fallback end
    end
    -- Changes what the page shows (a type, a mode): rebuild and redraw.
    local function set(key)
        return function(value)
            conf[key] = value
            Refresh()
        end
    end
    -- Sliders: write and redraw only; the slider being dragged stays the same widget.
    local function live(key)
        return function(value)
            conf[key] = value
            Redraw()
        end
    end
    local function numberGet(key, empty)
        return function()
            if conf[key] == nil then return empty end
            return tostring(conf[key])
        end
    end
    local function numberSet(key)
        return function(text)
            conf[key] = tonumber(text) or 0
            Refresh()
        end
    end
    -- Settings of the aura's group, made on first write.
    local function groupSettings()
        if type(profile.customGroups) ~= "table" then profile.customGroups = {} end
        local settings = profile.customGroups[conf.group]
        if type(settings) ~= "table" then
            settings = {}
            profile.customGroups[conf.group] = settings
        end
        return settings
    end
    local function groupGet(key, fallback)
        return function()
            local groups = profile.customGroups
            local settings = type(groups) == "table" and groups[conf.group] or nil
            local value = nil
            if type(settings) == "table" then value = settings[key] end
            if value == nil then return fallback end
            return value
        end
    end
    local function groupSet(key)
        return function(value)
            groupSettings()[key] = value
            Refresh()
        end
    end
    local function groupLive(key)
        return function(value)
            groupSettings()[key] = value
            Redraw()
        end
    end
    local function exportIDs(ids, title)
        local profiles = ProfilesModule()
        engine = Engine()
        if not (engine and engine.Codec) then return end
        local text, err = engine.Codec.Export(profile, ids)
        if not text then
            Notify(L(err))
        elseif profiles and profiles.ShowExportPopup then
            profiles:ShowExportPopup(title, text)
        end
    end
    -- Colours are saved as { r, g, b }.
    local function colorGet(key, r, g, b)
        return function()
            local c = conf[key]
            if type(c) == "table" then return c.r or r, c.g or g, c.b or b, 1 end
            return r, g, b, 1
        end
    end
    -- The swatch shows the colour itself: only the auras are redrawn, so the picker is not rebuilt while it is open.
    local function colorSet(key)
        return function(r, g, b)
            conf[key] = { r = r, g = g, b = b }
            Redraw()
        end
    end
    -- Each helper places one widget at the running height and grows it by the widget's height and the gap.
    local function grow(gap, _, h)
        right = right + h + gap
    end
    local function label(text, gap, cap)
        local header, h = columnHeader(column, text, right)
        attachBadge(header, cap, L)
        grow(gap, header, h)
    end
    local function note(text)
        grow(5, W:Label(column, text, -right, 11, { r = 0.65, g = 0.65, b = 0.65 }))
    end
    local function dropdown(text, key, fallback, values, order, gap)
        grow(gap, W:Dropdown(column, text, -right, values, get(key, fallback), set(key), order))
    end
    local function numberInput(text, key, empty, gap)
        grow(gap, W:Input(column, text, -right, numberGet(key, empty), numberSet(key)))
    end
    local function toggle(text, key, gap)
        grow(gap, W:Toggle(column, text, -right, get(key), set(key)))
    end
    local function slider(text, key, fallback, minV, maxV, step, fmt)
        grow(5, W:Slider(column, text, -right, get(key, fallback), live(key), minV, maxV, step, fmt))
    end

    -- The trigger being edited: 1 is the record itself, 2 to 4 the entries of its extraTriggers.
    local triggers = (engine and engine.TriggersOf) and engine.TriggersOf(conf) or { conf }
    local maxTriggers = (engine and engine.MAX_TRIGGERS) or 4
    local tIndex = math.max(1, math.min(selectedTrigger, #triggers))
    local tc = triggers[tIndex]
    local function tget(key, fallback)
        return function()
            local value = tc[key]
            if value == nil then return fallback end
            return value
        end
    end
    local function tset(key)
        return function(value)
            tc[key] = value
            Refresh()
        end
    end
    local function tdropdown(text, key, fallback, values, order)
        grow(5, W:Dropdown(column, text, -right, values, tget(key, fallback), tset(key), order))
    end
    local function tnumber(text, key, empty)
        grow(5, W:Input(column, text, -right, function()
            if tc[key] == nil then return empty end
            return tostring(tc[key])
        end, function(text)
            tc[key] = tonumber(text) or 0
            Refresh()
        end))
    end
    local function ttoggle(text, key)
        grow(5, W:Toggle(column, text, -right, function() return tc[key] == true end, tset(key)))
    end
    local function localised(labels, order)
        local values = {}
        for _, key in ipairs(order) do values[key] = L(labels[key]) end
        return values
    end
    local UNIT_VALUES = { player = L("Player"), target = L("Target"), focus = L("Focus"), pet = L("Pet") }
    local UNIT_ORDER = { "player", "target", "focus", "pet" }
    -- A comparison of the trigger's value; `always` names the choice that compares nothing.
    local function compare(always)
        tdropdown(L("Compare"), "triggerOp", "NONE", {
            NONE = always, GE = L("At Least"), GT = L("More Than"), LE = L("At Most"), LT = L("Less Than"), EQ = L("Exactly"),
        }, { "NONE", "GE", "GT", "LE", "LT", "EQ" })
        if tc.triggerOp and tc.triggerOp ~= "NONE" then tnumber(L("Value"), "triggerValue", "0") end
    end

    -- Name, then the actions as one row of buttons with their icons.
    grow(8, W:Input(column, L("Aura Name"), -right, get("name"), set("name")))
    local width = math.max(column:GetWidth() - 20, 300)
    local actionW = math.floor((width - 15) / 4)
    local asking = confirmDeleteID == id
    actionButton(column, 10, right, actionW, 32, conf.enabled and "ed_on" or "ed_off",
        conf.enabled and L("Enabled") or L("Disabled"), function()
            conf.enabled = not conf.enabled
            confirmDeleteID = nil
            Refresh()
        end, { tip = L("Click to turn this aura on or off."), dim = not conf.enabled }).kuiRole = "toggle"
    actionButton(column, 10 + (actionW + 5), right, actionW, 32, "ed_copy", L("Duplicate Aura"), function()
        -- Through the import whitelist when the engine is there, else a plain copy.
        engine = Engine()
        local copy
        if engine and engine.Codec then
            copy = engine.Codec.CleanAura(conf)
        else
            copy = {}
            for k, v in pairs(conf) do
                if type(v) == "table" then
                    local t = {}
                    for kk, vv in pairs(v) do t[kk] = vv end
                    v = t
                end
                copy[k] = v
            end
        end
        copy.name = string.format(L("%s (Copy)"), conf.name or LocalText("Unnamed"))
        local newID = newAuraID(profile.customAuras)
        profile.customAuras[newID] = copy
        selectAura(newID)
        Refresh()
    end, { tip = L("Makes a copy of this aura.") }).kuiRole = "duplicate"
    actionButton(column, 10 + 2 * (actionW + 5), right, actionW, 32, "ed_export", L("Export Aura"), function()
        confirmDeleteID = nil
        exportIDs({ id }, L("Export Aura"))
    end, { tip = L("Gives a string to share this aura.") }).kuiRole = "export"
    actionButton(column, 10 + 3 * (actionW + 5), right, actionW, 32, "ed_delete",
        asking and L("Click to Confirm") or L("Delete Aura"), function() requestDelete(profile, id) end,
        { tip = asking and L("Click again to delete it.") or L("Asks once more first."), danger = asking }).kuiRole =
        "delete"
    right = right + 32 + 10

    local tab = selectedTab
    local known = false
    for _, t in ipairs(TABS) do
        if t.id == tab then known = true end
    end
    if not known then tab = "trigger" end
    grow(10, buildTabs(column, L, right, tab))

    local hasStacks = (conf.triggerType == "AURA" or conf.triggerType == "CDM") and not conf.triggerAuraMissing

    if tab == "trigger" then
        label(L("TRIGGER"), 5, caps.trigger)
        -- One button per trigger, then Add and Remove.
        local x = 10
        for i = 1, #triggers do
            local chip = actionButton(column, x, right, 60, 28, "tab_trigger", tostring(i), function()
                selectedTrigger = i
                RebuildPage()
            end, { tipTitle = string.format(L("Trigger %d"), i), tip = L("Click to edit this trigger."),
                dim = i ~= tIndex })
            chip.kuiRole, chip.kuiTrigger = "trigger", i
            x = x + 65
        end
        if #triggers < maxTriggers then
            actionButton(column, x, right, 130, 28, "ed_new", L("Add Trigger"), function()
                if type(conf.extraTriggers) ~= "table" then conf.extraTriggers = {} end
                table.insert(conf.extraTriggers, {
                    triggerType = "AURA", triggerSpellID = 0, triggerUnit = "player", triggerAuraType = "HELPFUL",
                })
                selectedTrigger = #conf.extraTriggers + 1
                Refresh()
            end, { tip = L("Adds another trigger. Combine Triggers decides how they count together.") }).kuiRole =
                "addTrigger"
            x = x + 135
        end
        if tIndex > 1 then
            actionButton(column, x, right, 130, 28, "ed_delete", L("Remove Trigger"), function()
                table.remove(conf.extraTriggers, tIndex - 1)
                if #conf.extraTriggers == 0 then conf.extraTriggers = nil end
                selectedTrigger = 1
                Refresh()
            end, { tip = L("Removes this trigger from the aura.") }).kuiRole = "removeTrigger"
        end
        right = right + 28 + 8
        if #triggers > 1 then
            dropdown(L("Combine Triggers"), "triggerLogic", "ALL",
                { ALL = L("All Triggers Active"), ANY = L("Any Trigger Active") }, { "ALL", "ANY" }, 5)
        end

        tdropdown(L("Trigger Type"), "triggerType", "AURA", localised(KIND_LABELS, KIND_ORDER), KIND_ORDER)
        local kind = tc.triggerType or "AURA"
        if kind == "AURA" then
            tnumber(L("Spell ID"), "triggerSpellID", "")
            grow(5, W:DualRow(column, -right, {
                type = "dropdown", text = L("Unit"), values = UNIT_VALUES, order = UNIT_ORDER,
                getValue = tget("triggerUnit", "player"), setValue = tset("triggerUnit"),
            }, {
                type = "dropdown", text = L("Aura Type"),
                values = { HELPFUL = L("Buff"), HARMFUL = L("Debuff") },
                order = { "HELPFUL", "HARMFUL" },
                getValue = tget("triggerAuraType", "HELPFUL"), setValue = tset("triggerAuraType"),
            }))
            grow(5, W:Toggle(column, L("Only Cast by Me"), -right, function() return tc.triggerCaster == "PLAYER" end,
                function(on)
                    tc.triggerCaster = on and "PLAYER" or nil
                    Refresh()
                end))
            ttoggle(L("Trigger when Missing"), "triggerAuraMissing")
        elseif kind == "COOLDOWN" then
            tnumber(L("Spell ID"), "triggerSpellID", "")
            ttoggle(L("Trigger when Ready (Not on Cooldown)"), "triggerCooldownReady")
        elseif kind == "CDM" then
            tnumber(L("Spell ID"), "triggerSpellID", "")
            ttoggle(L("Trigger when Missing"), "triggerAuraMissing")
        elseif kind == "CHARGES" then
            tnumber(L("Spell ID"), "triggerSpellID", "")
            compare(L("Always (Show the Charges)"))
        elseif kind == "USABLE" then
            tnumber(L("Spell ID"), "triggerSpellID", "")
            ttoggle(L("Also in Range of the Target"), "triggerInRange")
        elseif kind == "ITEM" then
            tnumber(L("Item ID"), "triggerItemID", "")
            tdropdown(L("Item State"), "triggerItemMode", "READY",
                { READY = L("Ready to Use"), COOLDOWN = L("On Cooldown"), COUNT = L("Number Owned") },
                { "READY", "COOLDOWN", "COUNT" })
            if tc.triggerItemMode == "COUNT" then compare(L("Always (Show the Count)")) end
        elseif kind == "HEALTH" or kind == "POWER" then
            tdropdown(L("Unit"), "triggerUnit", "player", UNIT_VALUES, UNIT_ORDER)
            if kind == "POWER" then
                tdropdown(L("Power Type"), "triggerPowerType", -1, localised(POWER_LABELS, POWER_ORDER), POWER_ORDER)
            end
            compare(L("Always (Show the Value)"))
            if tc.triggerOp and tc.triggerOp ~= "NONE" then
                tdropdown(L("Compare As"), "triggerValueMode", kind == "HEALTH" and "PERCENT" or "VALUE",
                    { PERCENT = L("Percentage"), VALUE = L("Exact Value") }, { "PERCENT", "VALUE" })
            end
        elseif kind == "CAST" then
            tdropdown(L("Unit"), "triggerUnit", "player", UNIT_VALUES, UNIT_ORDER)
            tnumber(L("Spell ID (0 for any cast)"), "triggerSpellID", "0")
        elseif kind == "STATE" then
            tdropdown(L("State"), "triggerState", "combat", localised(STATE_LABELS, STATE_ORDER), STATE_ORDER)
        end
        dropdown(L("While Secret"), "unknownMode", "LAST",
            { LAST = L("Keep Last Known"), HIDE = L("Hide Until Readable"), DIM = L("Dim Last Known") },
            { "LAST", "HIDE", "DIM" }, 5)

    elseif tab == "stacks" then
        -- Stacks: the filter, the count on the aura, the bar filled by stacks and the alert (E.Stacks).
        label(L("STACKS"), 5, caps.stacks)
        if not hasStacks then
            note(L("Stacks are counted for an aura that is there, not for a cooldown or a missing aura."))
        else
            dropdown(L("Show Only When Stacks Are"), "stacksOp", "NONE",
                { NONE = L("Any Number"), GE = L("At Least"), LE = L("At Most"), EQ = L("Exactly") },
                { "NONE", "GE", "LE", "EQ" }, 5)
            if conf.stacksOp == "GE" or conf.stacksOp == "LE" or conf.stacksOp == "EQ" then
                slider(L("Stack Count"), "stacksValue", 1, 1, 50, 1, "%d")
            end
            grow(5, W:Toggle(column, L("Show the Stack Count"), -right,
                function() return conf.customTextType == "STACKS" end,
                function(on)
                    if on then
                        conf.customTextType = "STACKS"
                    elseif conf.customTextType == "STACKS" then
                        conf.customTextType = "NONE"
                    end
                    Refresh()
                end))
            right = right + 10

            label(L("STACK BAR"), 5, caps.stacks)
            grow(5, W:Toggle(column, L("Fill a Bar by Stacks"), -right,
                function() return conf.displayStyle == "BAR" and conf.barFill == "STACKS" end,
                function(on)
                    if on then
                        conf.displayStyle, conf.barFill = "BAR", "STACKS"
                    else
                        conf.barFill = "TIME"
                    end
                    Refresh()
                end))
            if conf.displayStyle == "BAR" and conf.barFill == "STACKS" then
                slider(L("Maximum Stacks"), "stackMax", 5, 1, 50, 1, "%d")
            end
            right = right + 10

            label(L("STACK ALERT"), 5, caps.stacks)
            slider(L("Alert From Stacks (0 = off)"), "stackAlert", 0, 0, 50, 1, "%d")
            grow(5, W:ColorSwatch(column, L("Alert Color"), -right, colorGet("stackAlertColor", 0.3, 1, 0.3),
                colorSet("stackAlertColor")))
            note(L("From that many stacks the count takes this colour and the aura glows."))
        end

    elseif tab == "display" then
        label(L("CUSTOM TEXT"), 5, caps.display)
        dropdown(L("Text Mode"), "customTextType", "NONE",
            { NONE = "None", STATIC = "Static Text", STACKS = "Aura Stacks", DURATION = "Remaining Duration",
                TOKENS = L("Text with Values") },
            { "NONE", "STATIC", "STACKS", "DURATION", "TOKENS" }, 5)
        if conf.customTextType == "STATIC" then
            grow(5, W:Input(column, L("Static Text Value"), -right, get("customTextValue", ""), set("customTextValue")))
        elseif conf.customTextType == "TOKENS" then
            grow(5, W:Input(column, L("Text to Show"), -right, get("customTextValue", ""), set("customTextValue")))
            note(L("%n name, %s stacks, %t time left, %v value, %m maximum, %p percent, %c count, %% a percent sign."))
        end
        if conf.customTextType and conf.customTextType ~= "NONE" then
            if conf.displayStyle ~= "BAR" and conf.displayStyle ~= "TEXT" then
                dropdown(L("Text Position"), "textPoint", "CENTER", {
                    CENTER = L("Center"), TOP = L("Top"), BOTTOM = L("Bottom"), LEFT = L("Left"), RIGHT = L("Right"),
                    TOPLEFT = L("Top Left"), TOPRIGHT = L("Top Right"), BOTTOMLEFT = L("Bottom Left"),
                    BOTTOMRIGHT = L("Bottom Right"),
                }, { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }, 5)
            end
            slider(L("Text Size"), "textSize", conf.displayStyle == "BAR" and 14 or 18, 6, 48, 1, "%d")
        end
        right = right + 10

        label(L("DISPLAY & STYLE"), 5, caps.display)
        dropdown(L("Display Style"), "displayStyle", "ICON",
            { ICON = L("Icon (Default)"), TEXT = L("Text Only"), BAR = L("Timer Bar") }, { "ICON", "TEXT", "BAR" }, 5)
        slider(L("Size"), "size", 40, 10, 100, 1, "%d")
        if conf.displayStyle == "BAR" then
            slider(L("Bar Width"), "barWidth", 180, 60, 400, 1, "%d")
            grow(5, W:ColorSwatch(column, L("Bar Color"), -right, colorGet("barColor", 0.25, 0.55, 0.95),
                colorSet("barColor")))
            dropdown(L("Bar Fills By"), "barFill", "TIME",
                { TIME = L("Remaining Time"), STACKS = L("Stacks"), VALUE = L("Value (health, power, charges)") },
                { "TIME", "STACKS", "VALUE" }, 5)
        end
        slider(L("Opacity"), "opacity", 1.0, 0, 1, 0.05, "%.2f")
        toggle(L("Show Glow Action"), "showGlow", 5)
        grow(5, W:Toggle(column, L("Show Name Label Below"), -right,
            function() return conf.showNameLabel == true end, set("showNameLabel")))
        if conf.displayStyle ~= "BAR" and conf.displayStyle ~= "TEXT" then
            grow(5, W:Toggle(column, L("Show Cooldown Swipe"), -right, function() return conf.showSwipe == true end,
                set("showSwipe")))
        end
        if conf.displayStyle ~= "TEXT" then
            dropdown(L("When the Trigger Is Off"), "inactiveMode", "HIDE",
                { HIDE = L("Hide"), DESATURATE = L("Show Greyed Out"), DIM = L("Show Faded") },
                { "HIDE", "DESATURATE", "DIM" }, 5)
            numberInput(L("Icon Spell ID (0 for the trigger's)"), "iconSpellID", "0", 5)
        end
        right = right + 10

        -- Position: on the screen (moved in the unlock mode) or on another frame, by its global name.
        label(L("POSITION"), 5)
        grow(5, W:Input(column, L("Anchor to Frame (empty for the screen)"), -right, get("anchorFrame", ""),
            function(text)
                text = Trim(text)
                conf.anchorFrame = text ~= "" and text or nil
                Refresh()
            end))
        if type(conf.anchorFrame) == "string" and conf.anchorFrame ~= "" then
            local points = {
                CENTER = L("Center"), TOP = L("Top"), BOTTOM = L("Bottom"), LEFT = L("Left"), RIGHT = L("Right"),
                TOPLEFT = L("Top Left"), TOPRIGHT = L("Top Right"), BOTTOMLEFT = L("Bottom Left"),
                BOTTOMRIGHT = L("Bottom Right"),
            }
            local pointOrder = { "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT",
                "BOTTOMRIGHT" }
            dropdown(L("Aura Point"), "point", "CENTER", points, pointOrder, 5)
            dropdown(L("Frame Point"), "relativePoint", "CENTER", points, pointOrder, 5)
            slider(L("Offset X"), "xOffset", 0, -500, 500, 1, "%d")
            slider(L("Offset Y"), "yOffset", 0, -500, 500, 1, "%d")
            local engineIcon = engine and engine.Icon
            local found = engineIcon and engineIcon.AnchorOf and engineIcon.AnchorOf({ anchorFrame = conf.anchorFrame })
            if not found then note(L("No frame has this name now: the aura stays at its screen position.")) end
            note(L("An aura on a frame is placed by these offsets, not in the unlock mode."))
        end
        right = right + 10

        -- Group: auras with the same name are placed together and moved as one.
        label(L("GROUP"), 5)
        grow(5, W:Input(column, L("Group Name (empty for none)"), -right, get("group", ""), function(text)
            text = Trim(text)
            conf.group = text ~= "" and text or nil
            Refresh()
        end))
        if type(conf.group) == "string" and conf.group ~= "" then
            local defaults = engine and engine.Group and engine.Group.DEFAULTS or {}
            grow(5, W:Input(column, L("Order in Group"), -right, numberGet("groupOrder", "0"), numberSet("groupOrder")))
            grow(5, W:Dropdown(column, L("Direction"), -right,
                { RIGHT = L("Grow Right"), LEFT = L("Grow Left"), UP = L("Grow Up"), DOWN = L("Grow Down") },
                groupGet("direction", defaults.direction or "RIGHT"), groupSet("direction"),
                { "RIGHT", "LEFT", "UP", "DOWN" }))
            grow(5, W:Slider(column, L("Spacing"), -right, groupGet("spacing", defaults.spacing or 4),
                groupLive("spacing"), 0, 40, 1, "%d"))
            grow(5, W:Toggle(column, L("Close Gaps of Hidden Auras"), -right,
                groupGet("dynamic", defaults.dynamic ~= false), groupSet("dynamic")))
            grow(5, W:Slider(column, L("New Line After (0 = one line)"), -right, groupGet("wrap", defaults.wrap or 0),
                groupLive("wrap"), 0, 20, 1, "%d"))
            grow(5, W:Dropdown(column, L("Sort"), -right,
                { ORDER = L("By Order in Group"), REMAINING = L("By Remaining Time") },
                groupGet("sort", defaults.sort or "ORDER"), groupSet("sort"), { "ORDER", "REMAINING" }))
            grow(5, W:Button(column, L("Export Group"), -right, function()
                local ids = {}
                for auraID, other in pairs(profile.customAuras) do
                    if other.group == conf.group then ids[#ids + 1] = auraID end
                end
                table.sort(ids)
                exportIDs(ids, L("Export Group"))
            end))
        end

    elseif tab == "conditions" then
        -- Conditions: the low time colour of the duration text and the bar.
        label(L("CONDITIONS"), 5, caps.display)
        slider(L("Low Time Warning (seconds, 0 = off)"), "lowTime", 0, 0, 30, 1, "%d")
        grow(5, W:ColorSwatch(column, L("Low Time Color"), -right, colorGet("lowTimeColor", 1, 0.2, 0.2),
            colorSet("lowTimeColor")))
        note(L("The stack alert is in the Stacks tab."))
        right = right + 10

        -- Rules: each one changes the look while it holds (E.Conditions).
        label(L("RULES"), 5, caps.display)
        note(L("Each rule changes the look while it holds; a later rule wins. A secret reading never passes."))
        local rules = type(conf.rules) == "table" and conf.rules or {}
        local checkValues = {
            REMAINING = L("Remaining Time (seconds)"), STACKS = L("Stacks"), VALUE = L("Value"),
            PERCENT = L("Percentage"), COUNT = L("Count (charges, items)"), TRIGGER = L("Trigger Is Active"),
        }
        local checkOrder = { "REMAINING", "STACKS", "VALUE", "PERCENT", "COUNT", "TRIGGER" }
        for i, rule in ipairs(rules) do
            local function rget(key, fallback)
                return function()
                    local value = rule[key]
                    if value == nil then return fallback end
                    return value
                end
            end
            local function rset(key)
                return function(value)
                    rule[key] = value
                    Refresh()
                end
            end
            grow(4, W:Label(column, string.format(L("Rule %d"), i), -right, 12, { r = 0.85, g = 0.85, b = 0.85 }))
            grow(5, W:Dropdown(column, L("When"), -right, checkValues, rget("check", "REMAINING"), rset("check"),
                checkOrder))
            if rule.check == "TRIGGER" then
                local triggerValues, triggerOrder = {}, {}
                for n = 1, maxTriggers do
                    triggerValues[n] = string.format(L("Trigger %d"), n)
                    triggerOrder[n] = n
                end
                grow(5, W:Dropdown(column, L("Trigger"), -right, triggerValues, rget("trigger", 1), rset("trigger"),
                    triggerOrder))
            else
                grow(5, W:Dropdown(column, L("Compare"), -right, {
                    GE = L("At Least"), GT = L("More Than"), LE = L("At Most"), LT = L("Less Than"), EQ = L("Exactly"),
                }, rget("op", "LE"), rset("op"), { "GE", "GT", "LE", "LT", "EQ" }))
                grow(5, W:Input(column, L("Value"), -right, function() return tostring(rule.value or 0) end,
                    function(text)
                        rule.value = tonumber(text) or 0
                        Refresh()
                    end))
            end
            grow(5, W:Toggle(column, L("Change Color"), -right, function() return rule.useColor == true end,
                rset("useColor")))
            if rule.useColor then
                grow(5, W:ColorSwatch(column, L("Color"), -right, function()
                    local c = type(rule.color) == "table" and rule.color or {}
                    return c.r or 1, c.g or 0.3, c.b or 0.3, 1
                end, function(r, g, b)
                    rule.color = { r = r, g = g, b = b }
                    Redraw()
                end))
            end
            grow(5, W:Toggle(column, L("Glow"), -right, function() return rule.glow == true end, rset("glow")))
            grow(5, W:Toggle(column, L("Grey Out the Icon"), -right, function() return rule.desaturate == true end,
                rset("desaturate")))
            grow(5, W:Slider(column, L("Opacity (1 = unchanged)"), -right, rget("alpha", 1), function(value)
                rule.alpha = value < 1 and value or nil
                Redraw()
            end, 0, 1, 0.05, "%.2f"))
            grow(8, W:Button(column, L("Remove Rule"), -right, function()
                table.remove(conf.rules, i)
                if #conf.rules == 0 then conf.rules = nil end
                Refresh()
            end))
        end
        if #rules < ((engine and engine.MAX_RULES) or 4) then
            grow(5, W:Button(column, L("Add Rule"), -right, function()
                if type(conf.rules) ~= "table" then conf.rules = {} end
                table.insert(conf.rules, {
                    check = "REMAINING", op = "LE", value = 3, useColor = true, color = { r = 1, g = 0.3, b = 0.3 },
                })
                Refresh()
            end))
        end

    elseif tab == "load" then
        label(L("LOAD CONDITIONS"), 5)
        dropdown(L("Combat Status"), "loadCombat", "ANY",
            { ANY = "Any", IN_COMBAT = "In Combat", OUT_COMBAT = "Out of Combat" }, { "ANY", "IN_COMBAT", "OUT_COMBAT" }, 5)
        dropdown(L("Instance Type"), "loadInstance", "ANY", {
            ANY = "Any", NONE = "None (World)", PARTY = "Party/Dungeon", RAID = "Raid", ARENA = "Arena",
            PVP = "Battleground",
        }, { "ANY", "NONE", "PARTY", "RAID", "ARENA", "PVP" }, 5)
        dropdown(L("Boss Fight"), "loadBoss", "ANY",
            { ANY = L("Any Fight"), BOSS = L("Boss Fights Only"), NO_BOSS = L("Outside Boss Fights") },
            { "ANY", "BOSS", "NO_BOSS" }, 5)
        if conf.loadBoss == "BOSS" then
            numberInput(L("Encounter ID (0 for any)"), "loadEncounterID", "0", 5)
        end
        numberInput(L("Talent Spell ID (0 to ignore)"), "loadTalent", "0", 5)
        numberInput(L("Zone Map ID (0 to ignore)"), "loadZoneID", "0", 5)
        right = right + 10

        -- The character: class, specialization, role, group, level, mount.
        label(L("CHARACTER"), 5)
        local forever = engine and engine.Codec and engine.Codec.Client() == "forever"
        local names = _G.LOCALIZED_CLASS_NAMES_MALE or {}
        local classValues, classOrder = { ANY = L("Any Class") }, { "ANY" }
        for _, token in ipairs(CLASS_ORDER) do
            if not (forever and NOT_ON_FOREVER[token]) then
                classValues[token] = names[token] or token
                classOrder[#classOrder + 1] = token
            end
        end
        dropdown(L("Class"), "loadClass", "ANY", classValues, classOrder, 5)
        -- Specializations of the chosen class (or the player's), where the client has them.
        local specCount = type(_G.GetNumSpecializations) == "function" and _G.GetNumSpecializations() or 0
        if type(specCount) == "number" and specCount > 0 then
            local specValues, specOrder = { [0] = L("Any Specialization") }, { 0 }
            for i = 1, specCount do
                local name
                if type(_G.GetSpecializationInfo) == "function" then
                    local _, specName = _G.GetSpecializationInfo(i)
                    name = specName
                end
                specValues[i] = name or tostring(i)
                specOrder[#specOrder + 1] = i
            end
            dropdown(L("Specialization"), "loadSpec", 0, specValues, specOrder, 5)
        end
        dropdown(L("Role"), "loadRole", "ANY",
            { ANY = L("Any Role"), TANK = L("Tank"), HEALER = L("Healer"), DAMAGER = L("Damage") },
            { "ANY", "TANK", "HEALER", "DAMAGER" }, 5)
        dropdown(L("Group"), "loadGroup", "ANY", {
            ANY = L("Any"), SOLO = L("Solo"), PARTY = L("Party Only"), RAID = L("Raid Only"),
            GROUP = L("Party or Raid"),
        }, { "ANY", "SOLO", "PARTY", "RAID", "GROUP" }, 5)
        numberInput(L("Minimum Level (0 to ignore)"), "loadMinLevel", "0", 5)
        grow(5, W:Toggle(column, L("Hide While Mounted"), -right, function() return conf.loadNotMounted == true end,
            set("loadNotMounted")))

    elseif tab == "animations" then
        label(L("ANIMATIONS"), 5)
        dropdown(L("When It Appears"), "animStart", "NONE",
            { NONE = L("None"), FADE = L("Fade In"), ZOOM = L("Zoom In") }, { "NONE", "FADE", "ZOOM" }, 5)
        dropdown(L("While It Shows"), "animMain", "NONE",
            { NONE = L("None"), PULSE = L("Pulse"), FLASH = L("Flash"), SHAKE = L("Shake") },
            { "NONE", "PULSE", "FLASH", "SHAKE" }, 5)
        dropdown(L("When It Goes"), "animFinish", "NONE",
            { NONE = L("None"), FADE = L("Fade Out"), SHRINK = L("Shrink") }, { "NONE", "FADE", "SHRINK" }, 5)
        note(L("The preview plays the loop; the other two play in game as the aura appears and goes."))

    elseif tab == "sound" then
        -- Sounds: LibSharedMedia names; "None" plays nothing.
        label(L("SOUNDS"), 5, caps.sound)
        local soundValues, soundOrder = { None = L("None") }, { "None" }
        local sound = engine and engine.Sound
        for _, name in ipairs(sound and sound.List() or {}) do
            if name ~= "None" and soundValues[name] == nil then
                soundValues[name] = name
                soundOrder[#soundOrder + 1] = name
            end
        end
        dropdown(L("Sound When Shown"), "soundApplied", "None", soundValues, soundOrder, 5)
        dropdown(L("Sound When Hidden"), "soundRemoved", "None", soundValues, soundOrder, 5)
        dropdown(L("Sound Channel"), "soundChannel", "Master", {
            Master = L("Master"), SFX = L("Sound Effects"), Music = L("Music"), Ambience = L("Ambience"),
            Dialog = L("Dialogue"),
        }, { "Master", "SFX", "Music", "Ambience", "Dialog" }, 5)
    end
    return right
end

-- Returns the column's used height.
local function buildRightColumn(column, L, profile)
    local total = 0
    for _ in pairs(profile.customAuras) do total = total + 1 end
    local conf = selectedID and profile.customAuras[selectedID]
    if creating or total == 0 then
        return buildGallery(column, L, profile, total)
    end
    if conf then
        return buildEditor(column, L, profile, selectedID, conf)
    end
    local _, h = KT.Widgets:Label(column, L("Select an aura on the left to edit it, or press New Aura."), 0, 12,
        { r = 0.6, g = 0.6, b = 0.6 })
    return h + 5
end

-----------------------------------------------------------------------------------------------------------------------
-- Page
-----------------------------------------------------------------------------------------------------------------------

local function BuildPage(_, parent, yOffset)
    local W = KT.Widgets
    local options = KT.Options
    local function L(text)
        if options then return options.LText(text) end
        return text
    end

    -- With no database this raises, as a kept suspected bug.
    local profile = _G._KUIAR_AceDB.profile
    if type(profile.customAuras) ~= "table" then profile.customAuras = {} end
    if selectedID and profile.customAuras[selectedID] == nil then selectedID = nil end
    if confirmDeleteID and profile.customAuras[confirmDeleteID] == nil then confirmDeleteID = nil end

    local y = yOffset
    local embedded = ns.AuraRemindersEmbedded
    local selectorH = 0
    if embedded then
        actionButton(parent, 0, y, 210, 34, "custom", L("Full Aura Editor"), function()
            embeddedView = true
            RebuildPage()
        end, { active = embeddedView })
        actionButton(parent, 220, y, 210, 34, "ed_copy", L("Existing KUI Auras"), function()
            embeddedView = false
            embedded.Close()
            RebuildPage()
        end, { active = not embeddedView })
        selectorH = 46
        y = y + selectorH
        if embeddedView then return selectorH + embedded.BuildPage(parent, y) end
        embedded.Close()
    end
    local _, labelH = W:Label(parent, L("Create standalone custom auras with specific load conditions. They can be freely positioned anywhere on the screen."), -y, 12)
    y = y + labelH + 10

    local toolbarH = buildToolbar(parent, L, profile, y)
    y = y + toolbarH + 12

    local leftColumn = CreateFrame("Frame", nil, parent)
    leftColumn:SetSize(LIST_W + 10, 500)
    leftColumn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    local leftH = buildLeftColumn(leftColumn, L, profile)

    local rightColumn = CreateFrame("Frame", nil, parent)
    rightColumn:SetSize(parent:GetWidth() - LIST_W - 30, 500)
    rightColumn:SetPoint("TOPLEFT", parent, "TOPLEFT", LIST_W + 20, -y)
    local rightH = buildRightColumn(rightColumn, L, profile)

    return selectorH + labelH + 10 + toolbarH + 12 + math.max(leftH, rightH)
end

-----------------------------------------------------------------------------------------------------------------------
-- Registration
-----------------------------------------------------------------------------------------------------------------------

local function onSlash()
    local inCombat = _G.InCombatLockdown
    if inCombat and inCombat() then return end
    KT:ShowModule("KUIAuraReminders")
end

local function Register()
    if not KT.RegisterModule then return end
    local Pages = S.Pages

    KT:RegisterModule("KUIAuraReminders", {
        title = S.LText("Aura Readiness"),
        description = S.LText("Prepare group buffs, class upkeep and consumables from one KUI workspace."),
        pages = { Pages.CONTROL, Pages.GROUP, Pages.CLASS, Pages.CONSUMABLES, Pages.TALENTS, Pages.CUSTOM_AURAS },
        buildNavigation = Cards and Cards.BuildNavigation,
        usesViewport = function(name)
            return name == Pages.CUSTOM_AURAS and embeddedView and ns.AuraRemindersEmbedded ~= nil
        end,
        hasPreview = function(name)
            return name == Pages.CONTROL or name == Pages.GROUP or name == Pages.CLASS or name == Pages.CONSUMABLES
        end,
        buildPage = function(name, parent, y)
            if name == Pages.CONTROL or name == Pages.GROUP or name == Pages.CLASS or name == Pages.CONSUMABLES then
                return Reminders.BuildPage(name, parent, y)
            elseif name == Pages.TALENTS then
                return Talents.BuildPage(name, parent, y)
            elseif name == Pages.CUSTOM_AURAS then
                return BuildPage(name, parent, y)
            end
            return nil
        end,
        getHeaderBuilder = function(name)
            if name == Pages.CONTROL then return P.HeaderBuilder end
            return nil
        end,
        onPageCacheRestore = function(name)
            if name == Pages.CONTROL then P.RestoreControlPreview() end
        end,
        onShow = function()
            local hide = _G._KUIAR_HideAllIcons
            if hide then hide() end
        end,
        onHide = function()
            local refresh = _G._KUIAR_RequestRefresh
            if refresh then refresh() end
        end,
        onReset = function()
            local db = _G._KUIAR_AceDB
            if db then db:ResetProfile() end
            local refresh = _G._KUIAR_RequestRefresh
            if refresh then refresh() end
        end,
    })

    -- Half a second lets the runtime create its movers first.
    C_Timer.After(0.5, function()
        local registerUnlock = _G._KUIAR_RegisterUnlock
        if registerUnlock then registerUnlock() end
    end)

    _G.SLASH_KUIAR1 = "/kuiar"
    _G.SLASH_KUIAR2 = "/kuir"
    SlashCmdList.KUIAR = onSlash
end

function M.Setup(ctx)
    if not ctx or (ctx.client ~= "retail" and ctx.client ~= "forever") then
        error("AuraRemindersPageCustom.Setup: ctx.client must be \"retail\" or \"forever\"", 2)
    end
    S, P, Reminders, Talents, Cards = ctx.Widgets, ctx.Preview, ctx.Reminders, ctx.Talents, ctx.Cards
    M.BuildPage = BuildPage
    M.Register = Register
end
