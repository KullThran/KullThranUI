-- Modules/ActionBars/ActionBars_Glows.lua
-- Glows of the action buttons, each kind with its own look (style, colour and
-- opacity) and each spell able to override it. Shared byte for byte between
-- the Retail and Forever workspaces.
--   proc      Blizzard's spell alert (a proc). "native" keeps Blizzard's art;
--             any other style replaces it.
--   usable    A tracked spell glows while it is usable and off cooldown
--             (Overpower, Riposte, Execute...: procs the client does not alert).
--   cooldown  A tracked spell whose cooldown has just come back glows for a few
--             seconds (or until it is cast).
-- One glow per button; when several apply, the order above wins.
-- The styles are the Cooldown Manager's (KT.CDMGlowEngine, published by
-- KUICooldownManager.lua). Without that addon only a few fallbacks remain.
-- Secret values (Retail combat) are never compared: action -> spell is cached
-- while the values are public, cooldowns fall back to the button's own cooldown
-- widget, and a secret "usable" drives the glow's alpha directly.
local _, ns = ...
local KT = _G.KT
local Mod = KT and KT.GetModule and KT:GetModule("ActionBars", true)
if not Mod then return end

local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local GetTime = GetTime

local KINDS = { "proc", "usable", "cooldown" }
local KIND_DEFAULTS = {
    proc     = { enabled = true, style = "native",   color = { r = 1, g = 0.82, b = 0.1 },  opacity = 100 },
    usable   = { enabled = true, style = "blizzard", color = { r = 1, g = 0.12, b = 0.08 }, opacity = 100 },
    cooldown = { enabled = true, style = "button",   color = { r = 1, g = 1, b = 1 },       opacity = 100 },
}
ns.AB_GLOW_KINDS = KINDS
ns.AB_GLOW_COOLDOWN_SECONDS = { 2, 3, 5, 10, 0 } -- 0 = until it is cast

-- A cooldown no longer than this is the global cooldown, not the spell's own.
local GCD_LIMIT = 1.6

local function IsClassicClient()
    if not _G.GetBuildInfo then return false end
    local _, _, _, interface = _G.GetBuildInfo()
    return (tonumber(interface) or 0) < 100000
end

-- Spells each class tracks out of the box (rank 1 ids; buttons match by name,
-- so every rank counts). Cooldowns: the big ones worth a "ready" glow.
local COOLDOWN_SPELLS = {
    DRUID   = { 29166, 22812, 5217, 417141, 22842 },
    HUNTER  = { 3045, 19574, 19263 },
    MAGE    = { 12043, 12042, 11129, 11958 },
    PALADIN = { 642, 498, 633 },
    PRIEST  = { 14751, 10060, 586, 13908, 2651, 13896 },
    ROGUE   = { 13750, 13877, 14177, 5277, 1856 },
    SHAMAN  = { 16166 },
    WARRIOR = { 1719, 12328, 871, 12975 },
}
-- Racials of every race: only the ones on a button matter.
local RACIAL_COOLDOWNS = { 20572, 20554, 20594, 1259718, 7744, 20589, 20549, 20600 }
-- Reactive spells: glow while usable. The Retail client alerts these itself,
-- so they are defaults on the classic clients only.
local USABLE_SPELLS = {
    HUNTER  = { 19306, 1495 },
    PALADIN = { 24275 },
    ROGUE   = { 14251 },
    WARRIOR = { 7384, 6572, 5308, 402927 },
}

local function PlayerClass()
    if not _G.UnitClass then return nil end
    local _, class = _G.UnitClass("player")
    return class
end

local function IsSecret(value)
    return _G.issecretvalue ~= nil and _G.issecretvalue(value) == true
end

-- The value when Lua may read it; nil when it is secret.
local function Readable(value)
    if IsSecret(value) then return nil end
    if value ~= nil and _G.canaccessvalue and not _G.canaccessvalue(value) then return nil end
    return value
end

local function SpellName(id)
    id = tonumber(id)
    if not id then return nil end
    local name
    if _G.C_Spell and _G.C_Spell.GetSpellName then
        local ok, value = pcall(_G.C_Spell.GetSpellName, id)
        name = ok and Readable(value) or nil
    end
    if not name and _G.GetSpellInfo then
        local ok, value = pcall(_G.GetSpellInfo, id)
        name = ok and Readable(value) or nil
    end
    return type(name) == "string" and name ~= "" and name or nil
end
ns.ABGlowSpellName = SpellName

function ns.ABGlowSpellIcon(id)
    id = tonumber(id)
    if not id then return nil end
    for _, fn in ipairs({ _G.C_Spell and _G.C_Spell.GetSpellTexture or false, _G.GetSpellTexture or false }) do
        if fn then
            local ok, value = pcall(fn, id)
            if ok and Readable(value) then return value end
        end
    end
end

-- "Name", "12345" or a spell link -> a spell id the client knows.
function ns.ABGlowResolveSpell(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    local id = tonumber(text) or tonumber(text:match("spell:(%d+)"))
    if id then return SpellName(id) and id or nil end
    if text == "" then return nil end
    if _G.C_Spell and _G.C_Spell.GetSpellInfo then
        local ok, info = pcall(_G.C_Spell.GetSpellInfo, text)
        if ok and type(info) == "table" and tonumber(Readable(info.spellID)) then
            return tonumber(info.spellID)
        end
    end
    if _G.GetSpellInfo then
        local ok, _, _, _, _, _, _, spellID = pcall(_G.GetSpellInfo, text)
        if ok and tonumber(Readable(spellID)) then return tonumber(spellID) end
    end
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
local function CopyColor(c) return { r = c.r, g = c.g, b = c.b } end

function Mod:GetGlowsDB()
    local profile = KT.db and KT.db.profile
    if not profile then return nil end
    profile.actionbars = profile.actionbars or {}
    local db = profile.actionbars.glows
    -- The ticker asks many times a second: repair a table only once.
    if type(db) == "table" and db == self._abGlowsDB then return db end
    if type(db) ~= "table" then
        db = {}
        profile.actionbars.glows = db
    end
    -- Off until the player turns them on in Action Bars > Glows.
    if db.enable == nil then db.enable = false end
    db.kinds = type(db.kinds) == "table" and db.kinds or {}
    for kind, def in pairs(KIND_DEFAULTS) do
        local k = type(db.kinds[kind]) == "table" and db.kinds[kind] or {}
        if k.enabled == nil then k.enabled = def.enabled end
        if type(k.style) ~= "string" then k.style = def.style end
        if type(k.color) ~= "table" then k.color = CopyColor(def.color) end
        if tonumber(k.opacity) == nil then k.opacity = def.opacity end
        db.kinds[kind] = k
    end
    local seconds, valid = tonumber(db.cooldownSeconds), false
    for _, choice in ipairs(ns.AB_GLOW_COOLDOWN_SECONDS) do
        if seconds == choice then valid = true end
    end
    db.cooldownSeconds = valid and seconds or 3
    if db.cooldownInCombatOnly == nil then db.cooldownInCombatOnly = true end
    if db.cooldownAtFightStart == nil then db.cooldownAtFightStart = false end
    db.spells = type(db.spells) == "table" and db.spells or {}
    db.custom = type(db.custom) == "table" and db.custom or {}
    self._abGlowsDB = db
    return db
end

local function SpellKey(kind, id) return kind .. ":" .. tostring(id) end
ns.ABGlowSpellKey = SpellKey

-- Every spell of a kind: the class defaults, then the player's own additions.
-- Each entry: { id, kind, isCustom }.
function Mod:GetGlowSpellList(kind)
    local db = self:GetGlowsDB()
    local list, seen = {}, {}
    local function Add(id, isCustom)
        id = tonumber(id)
        if not id or seen[id] then return end
        seen[id] = true
        list[#list + 1] = { id = id, kind = kind, isCustom = isCustom }
    end
    local class = PlayerClass()
    if kind == "cooldown" then
        for _, id in ipairs(COOLDOWN_SPELLS[class] or {}) do Add(id) end
        for _, id in ipairs(RACIAL_COOLDOWNS) do Add(id) end
    elseif kind == "usable" and IsClassicClient() then
        for _, id in ipairs(USABLE_SPELLS[class] or {}) do Add(id) end
    end
    for _, cue in ipairs(db and db.custom or {}) do
        if type(cue) == "table" and cue.kind == kind then Add(cue.id, true) end
    end
    return list
end

function Mod:AddGlowSpell(kind, id)
    local db = self:GetGlowsDB()
    id = tonumber(id)
    if not db or not id or not KIND_DEFAULTS[kind] then return false end
    for _, entry in ipairs(self:GetGlowSpellList(kind)) do
        if entry.id == id then return false end
    end
    db.custom[#db.custom + 1] = { id = id, kind = kind }
    self:RefreshGlows()
    return true
end

function Mod:RemoveGlowSpell(kind, id)
    local db = self:GetGlowsDB()
    if not db then return end
    for index = #db.custom, 1, -1 do
        local cue = db.custom[index]
        if type(cue) == "table" and cue.kind == kind and tonumber(cue.id) == tonumber(id) then
            table.remove(db.custom, index)
        end
    end
    db.spells[SpellKey(kind, id)] = nil
    self:RefreshGlows()
end

-- The look a glow uses: the spell's own override, else its kind's.
function Mod:GetGlowLook(kind, spellID)
    local db = self:GetGlowsDB()
    local base = db and db.kinds[kind] or KIND_DEFAULTS[kind]
    local override = spellID and db and db.spells[SpellKey(kind, spellID)] or nil
    local color = (override and type(override.color) == "table" and override.color) or base.color
    return {
        enabled = base.enabled ~= false and not (override and override.off),
        style = (override and type(override.style) == "string" and override.style) or base.style,
        r = color.r or 1, g = color.g or 1, b = color.b or 1,
        opacity = tonumber(override and override.opacity) or tonumber(base.opacity) or 100,
    }
end

-- ---------------------------------------------------------------------------
-- Glow engine
-- ---------------------------------------------------------------------------
local function Engine()
    local engine = KT.CDMGlowEngine
    return type(engine) == "table" and engine.Start and engine.Stop and engine or nil
end

local FALLBACK_STYLES = {
    { id = "blizzard", label = "Proc Glow (WoW)" },
    { id = "autocast", label = "AutoCast Shine" },
    { id = "none",     label = "None" },
}

-- values/order for W:Dropdown. `withNative` adds Blizzard's own proc art,
-- `withInherit` the "same as its kind" choice of a spell override.
function ns.ABGlowStyleChoices(localize, withNative, withInherit)
    local values, order = {}, {}
    local function Add(id, label)
        if values[id] then return end
        values[id] = localize and localize(label) or label
        order[#order + 1] = id
    end
    if withInherit then Add("inherit", "Same as its kind") end
    if withNative then Add("native", "Blizzard (unchanged)") end
    local engine = Engine()
    local list = engine and engine.GetStyles and engine.GetStyles() or FALLBACK_STYLES
    for _, style in ipairs(list) do Add(style.id, style.label) end
    return values, order
end

-- KUI action-bar shape -> the Cooldown Manager's name for the same mask.
local SHAPE_NAMES = { CIRCLE = "circle", CSQUARE = "csquare", HEXAGON = "hexagon", DIAMOND = "diamond", SHIELD = "shield" }

local overlays = {} -- btn -> overlay frame

local function GetOverlay(btn)
    local overlay = overlays[btn]
    if overlay then return overlay end
    local name = btn.GetName and btn:GetName()
    if not name then return nil end
    -- A "KUI_Glow..." frame is its own glow target for the CDM engine, so the
    -- real button's spell alert is never touched.
    overlay = CreateFrame("Frame", "KUI_GlowAB_" .. name, btn)
    overlay:SetAllPoints(btn)
    overlay:EnableMouse(false)
    overlay:Hide()
    overlays[btn] = overlay
    return overlay
end

-- Lets the engine's shape-aware styles follow a shaped button's silhouette.
local function SyncOverlayShape(overlay, btn)
    local shape = Mod.GetButtonShape and Mod:GetButtonShape(btn)
    local mask = btn.KT_ShapeMask
    if shape and SHAPE_NAMES[shape] and mask and mask:IsShown() then
        overlay._shapeApplied, overlay._shapeName, overlay._shapeMask = true, SHAPE_NAMES[shape], mask
    else
        overlay._shapeApplied, overlay._shapeName, overlay._shapeMask = nil, nil, nil
    end
end

local function StopOverlay(overlay)
    if not overlay or not overlay._abGlowKey then return end
    local engine = Engine()
    if overlay._abFallback == "lbg" then
        local LBG = LibStub and LibStub("LibButtonGlow-1.0", true)
        if LBG and LBG.HideOverlayGlow then LBG.HideOverlayGlow(overlay) end
    elseif overlay._abFallback == "autocast" then
        if KT.Glows and KT.Glows.StopAutoCastShine then KT.Glows.StopAutoCastShine(overlay) end
    elseif engine then
        engine.Stop(overlay)
    end
    overlay._abGlowKey, overlay._abFallback = nil, nil
    overlay:Hide()
end

local function StartOverlay(overlay, btn, look, key)
    if overlay._abGlowKey == key then return end
    StopOverlay(overlay)
    if look.style == "none" then return end
    SyncOverlayShape(overlay, btn)
    overlay:SetFrameLevel((btn:GetFrameLevel() or 0) + 10)
    overlay:Show()
    local engine = Engine()
    if engine then
        engine.Start(overlay, look.style, look.r, look.g, look.b)
    else
        local LBG = LibStub and LibStub("LibButtonGlow-1.0", true)
        if look.style == "autocast" and KT.Glows and KT.Glows.StartAutoCastShine then
            local size = math.max(btn:GetWidth() or 36, btn:GetHeight() or 36)
            KT.Glows.StartAutoCastShine(overlay, size, look.r, look.g, look.b)
            overlay._abFallback = "autocast"
        elseif LBG and LBG.ShowOverlayGlow then
            LBG.ShowOverlayGlow(overlay)
            overlay._abFallback = "lbg"
        end
    end
    overlay:SetAlpha(math.max(0, math.min(100, look.opacity)) / 100)
    overlay._abGlowKey = key
end

-- ---------------------------------------------------------------------------
-- Buttons and their spells
-- ---------------------------------------------------------------------------
local BAR_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}

local buttonSpell = {}   -- btn -> { id, name }, cached while the values are public
local trackedByName = {} -- kind -> spell name -> spell id of the list entry
local candidates = {}    -- btn -> true when its spell is tracked by some kind
local cooldownState = {} -- btn -> { real, glowUntil, untilCast }
local widgetShownAt = {} -- btn -> when its cooldown widget appeared
local procActive = {}    -- btn -> true while Blizzard's alert is up

local function ButtonAction(btn)
    local action = Readable(btn.action)
    if action == nil and btn.GetAttribute then
        local ok, value = pcall(btn.GetAttribute, btn, "action")
        action = ok and Readable(value) or nil
    end
    return tonumber(action)
end

-- spellID, or false for a slot that is readable but holds no spell, or nil
-- when the slot cannot be read now.
local function ReadActionSpell(action)
    if not action or not _G.GetActionInfo then return nil end
    local ok, actionType, id = pcall(_G.GetActionInfo, action)
    if not ok or IsSecret(actionType) or IsSecret(id) then return nil end
    if actionType == "spell" then return tonumber(id) or false end
    if actionType == "macro" and _G.GetMacroSpell then
        local okMacro, spellID = pcall(_G.GetMacroSpell, id)
        if not okMacro or IsSecret(spellID) then return nil end
        return tonumber(spellID) or false
    end
    return false
end

function Mod:ForEachGlowButton(fn)
    for _, prefix in ipairs(BAR_PREFIXES) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then fn(btn) end
        end
    end
end

local function RebuildCandidates()
    for btn in pairs(candidates) do candidates[btn] = nil end
    for btn, spell in pairs(buttonSpell) do
        for _, kind in ipairs(KINDS) do
            if spell.name and trackedByName[kind] and trackedByName[kind][spell.name] then
                candidates[btn] = true
            end
        end
    end
end

function Mod:RefreshGlowButtonSpells()
    self:ForEachGlowButton(function(btn)
        local id = ReadActionSpell(ButtonAction(btn))
        if id then
            local cached = buttonSpell[btn]
            if not cached or cached.id ~= id then buttonSpell[btn] = { id = id, name = SpellName(id) } end
        elseif id == false then
            buttonSpell[btn] = nil
        end
    end)
    RebuildCandidates()
end

function Mod:RefreshGlowSpells()
    for _, kind in ipairs(KINDS) do
        local map = {}
        for _, entry in ipairs(self:GetGlowSpellList(kind)) do
            local name = SpellName(entry.id)
            if name then map[name] = entry.id end
        end
        trackedByName[kind] = map
    end
    RebuildCandidates()
end

-- The list entry (spell id) of `kind` this button's spell matches, if any.
local function TrackedSpell(btn, kind)
    local spell = buttonSpell[btn]
    local map = trackedByName[kind]
    return spell and spell.name and map and map[spell.name] or nil
end

-- ---------------------------------------------------------------------------
-- Cooldowns
-- ---------------------------------------------------------------------------
-- true / false when the action's cooldown can be read; nil when it is secret.
local function ReadRealCooldown(action)
    if not action then return nil end
    local start, duration
    if _G.C_ActionBar and _G.C_ActionBar.GetActionCooldown then
        local ok, info = pcall(_G.C_ActionBar.GetActionCooldown, action)
        if ok and type(info) == "table" then start, duration = info.startTime, info.duration end
    elseif _G.GetActionCooldown then
        local ok, s, d = pcall(_G.GetActionCooldown, action)
        if ok then start, duration = s, d end
    end
    start, duration = tonumber(Readable(start)), tonumber(Readable(duration))
    if not start or not duration then return nil end
    if start <= 0 or duration <= GCD_LIMIT then return false end
    return start + duration > GetTime()
end

-- A real cooldown read from the button's own widget: shown longer than a GCD.
local function WidgetRealCooldown(btn, now)
    local cd = btn.cooldown or (btn.GetName and _G[btn:GetName() .. "Cooldown"])
    local shown = cd and cd.IsShown and Readable(cd:IsShown())
    if shown then
        widgetShownAt[btn] = widgetShownAt[btn] or now
        return now - widgetShownAt[btn] > GCD_LIMIT
    end
    widgetShownAt[btn] = nil
    return false
end

local function IsOnRealCooldown(btn, now)
    local real = ReadRealCooldown(ButtonAction(btn))
    if real == nil then return WidgetRealCooldown(btn, now) end
    return real
end

local function InCombat()
    return (_G.InCombatLockdown and _G.InCombatLockdown())
        or (_G.UnitAffectingCombat and _G.UnitAffectingCombat("player")) or false
end

local function StartReadyGlow(state, db, now)
    local seconds = db.cooldownSeconds or 3
    state.untilCast = seconds == 0
    state.glowUntil = seconds == 0 and math.huge or now + seconds
end

-- Whether the button shows its "cooldown ready" glow now, and for which spell.
local function UpdateCooldown(btn, db, now)
    local spellID = TrackedSpell(btn, "cooldown")
    if not spellID then
        cooldownState[btn] = nil
        return false
    end
    local state = cooldownState[btn]
    if not state then
        state = {}
        cooldownState[btn] = state
    end
    local real = IsOnRealCooldown(btn, now)
    if real then
        state.glowUntil, state.untilCast = nil, nil
    elseif state.real and (not db.cooldownInCombatOnly or InCombat()) then
        StartReadyGlow(state, db, now) -- just came back
    end
    state.real = real
    if state.glowUntil and now >= state.glowUntil then
        state.glowUntil, state.untilCast = nil, nil
    end
    return state.glowUntil ~= nil, spellID
end

-- ---------------------------------------------------------------------------
-- Per-button decision
-- ---------------------------------------------------------------------------
-- usable (a boolean, or the secret value itself), isSecret.
local function Usable(btn, now)
    local action = ButtonAction(btn)
    local fn = (_G.C_ActionBar and _G.C_ActionBar.IsUsableAction) or _G.IsUsableAction
    if not action or not fn then return false end
    local ok, usable = pcall(fn, action)
    if not ok then return false end
    if IsSecret(usable) then return usable, true end
    return usable and not IsOnRealCooldown(btn, now) or false
end

function Mod:UpdateButtonGlow(btn, now)
    local db = self:GetGlowsDB()
    local overlay = overlays[btn]
    if not db or not db.enable then
        StopOverlay(overlay)
        return
    end
    now = now or GetTime()
    local cooldownOn, cooldownSpell = UpdateCooldown(btn, db, now)
    local spell = buttonSpell[btn]

    local kind, spellID, secretUsable
    if procActive[btn] and self:IsProcGlowReplaced(btn) then
        kind, spellID = "proc", spell and spell.id
    end
    if not kind then
        local usableSpell = TrackedSpell(btn, "usable")
        if usableSpell and self:GetGlowLook("usable", usableSpell).enabled then
            local usable, isSecret = Usable(btn, now)
            if isSecret then
                kind, spellID, secretUsable = "usable", usableSpell, usable
            elseif usable then
                kind, spellID = "usable", usableSpell
            end
        end
    end
    if not kind and cooldownOn and self:GetGlowLook("cooldown", cooldownSpell).enabled then
        kind, spellID = "cooldown", cooldownSpell
    end

    if not kind then
        StopOverlay(overlay)
        return
    end
    overlay = overlay or GetOverlay(btn)
    if not overlay then return end
    local look = self:GetGlowLook(kind, spellID)
    StartOverlay(overlay, btn, look, table.concat({ kind, look.style, look.r, look.g, look.b, look.opacity }, "|"))
    if secretUsable ~= nil and overlay.SetAlphaFromBoolean then
        overlay:SetAlphaFromBoolean(secretUsable, look.opacity / 100, 0)
    end
end

function Mod:UpdateAllGlows()
    local now = GetTime()
    for btn in pairs(candidates) do self:UpdateButtonGlow(btn, now) end
    for btn in pairs(procActive) do
        if not candidates[btn] then self:UpdateButtonGlow(btn, now) end
    end
    for btn, overlay in pairs(overlays) do
        if overlay._abGlowKey and not candidates[btn] and not procActive[btn] then StopOverlay(overlay) end
    end
end

-- Whether a spell alert on this button is drawn by KUI instead of Blizzard.
function Mod:IsProcGlowReplaced(btn)
    local db = self:GetGlowsDB()
    if not btn or not db or not db.enable then return false end
    local spell = buttonSpell[btn]
    local look = self:GetGlowLook("proc", spell and spell.id)
    return look.enabled and look.style ~= "native"
end

-- Called when Blizzard shows or hides a button's spell alert.
function Mod:OnGlowProcChanged(btn, shown)
    if not btn then return end
    procActive[btn] = shown and true or nil
    local replaced = shown and self:IsProcGlowReplaced(btn)
    for _, native in ipairs({ btn.SpellActivationAlert or false, btn.overlay or false }) do
        if native then
            if replaced then
                native:SetAlpha(0)
            elseif btn.KT_ProcAlertReplaced and not btn.KT_ProcAlertHidden then
                native:SetAlpha(1)
            end
        end
    end
    btn.KT_ProcAlertReplaced = replaced or nil
    self:UpdateButtonGlow(btn)
end

-- ---------------------------------------------------------------------------
-- Events and the ticker
-- ---------------------------------------------------------------------------
local ticker

function Mod:RestartGlowTicker()
    if ticker then ticker:Cancel(); ticker = nil end
    local db = self:GetGlowsDB()
    if not (db and db.enable and next(candidates)) then return end
    if not (db.kinds.usable.enabled or db.kinds.cooldown.enabled) then return end
    if C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(0.1, function() Mod:UpdateAllGlows() end)
    end
end

-- After any settings change.
function Mod:RefreshGlows()
    self:RefreshGlowSpells()
    self:RefreshGlowButtonSpells()
    self:RestartGlowTicker()
    for btn in pairs(procActive) do self:OnGlowProcChanged(btn, true) end
    self:UpdateAllGlows()
end

function Mod:OnGlowCombatStart()
    local db = self:GetGlowsDB()
    if not db or not db.enable or not db.cooldownAtFightStart then return end
    local now = GetTime()
    for btn in pairs(candidates) do
        if TrackedSpell(btn, "cooldown") and not IsOnRealCooldown(btn, now) then
            cooldownState[btn] = cooldownState[btn] or {}
            StartReadyGlow(cooldownState[btn], db, now)
        end
    end
    self:UpdateAllGlows()
end

function Mod:OnGlowCombatEnd()
    local db = self:GetGlowsDB()
    if db and db.cooldownInCombatOnly then
        for _, state in pairs(cooldownState) do state.glowUntil, state.untilCast = nil, nil end
    end
    -- Pages and forms may have changed while the slots were secret.
    self:RefreshGlowButtonSpells()
    self:RestartGlowTicker()
    self:UpdateAllGlows()
end

function Mod:OnGlowSpellCast(unit, spellID)
    if unit ~= "player" then return end
    local name = SpellName(Readable(spellID))
    if not name then return end
    for btn, state in pairs(cooldownState) do
        local spell = buttonSpell[btn]
        if state.untilCast and spell and spell.name == name then
            state.glowUntil, state.untilCast = nil, nil
            self:UpdateButtonGlow(btn)
        end
    end
end

function Mod:OnGlowBarsChanged()
    if self._abGlowBarsPending then return end
    self._abGlowBarsPending = true
    C_Timer.After(0, function()
        Mod._abGlowBarsPending = nil
        Mod:RefreshGlowButtonSpells()
        Mod:RestartGlowTicker()
        Mod:UpdateAllGlows()
    end)
end

function Mod:InitGlows()
    if self._abGlowsReady then return end
    self._abGlowsReady = true
    self:GetGlowsDB()
    local events = CreateFrame("Frame")
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "ACTIONBAR_SLOT_CHANGED",
        "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    }) do
        pcall(events.RegisterEvent, events, event)
    end
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    events:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            Mod:OnGlowCombatStart()
        elseif event == "PLAYER_REGEN_ENABLED" then
            Mod:OnGlowCombatEnd()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellID = ...
            Mod:OnGlowSpellCast(unit, spellID)
        elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            Mod:RefreshGlows()
        else
            Mod:OnGlowBarsChanged()
        end
    end)
    -- Clients with the older overlay API instead of the spell-alert manager.
    if not _G.ActionButtonSpellAlertManager then
        if _G.ActionButton_ShowOverlayGlow then
            hooksecurefunc("ActionButton_ShowOverlayGlow", function(btn) Mod:OnGlowProcChanged(btn, true) end)
        end
        if _G.ActionButton_HideOverlayGlow then
            hooksecurefunc("ActionButton_HideOverlayGlow", function(btn) Mod:OnGlowProcChanged(btn, false) end)
        end
    end
    self:RefreshGlows()
end
