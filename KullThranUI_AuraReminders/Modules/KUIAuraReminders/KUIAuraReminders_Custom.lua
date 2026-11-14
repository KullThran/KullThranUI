local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

-- Custom aura engine, core: the registry of frames, the pass over the saved auras, events and the public API used by
-- the options page. Shared byte for byte between the Retail and Forever workspaces: both clients run the Mainline API
-- with secret values. A value that may be secret is only stored, tested with issecretvalue or handed to a widget
-- setter; it is never compared or used in arithmetic.
--
-- The options page still writes v0 records; each pass reads them through E.Migrate, so the saved data is unchanged.
-- An answer that cannot be known now (secret) keeps the last one read for that unit. While an aura is secret, an
-- icon or bar whose single source the client's engine can show switches to a delegated AuraKit slot. Sounds play on
-- readable transitions, or are registered with the client for an aura it can show (E.Sound). Auras sharing a group
-- name are placed together after the pass (E.Group). Each aura outside a group, and each group, is an element of
-- KUI's unlock mode (E.Movers); while that mode is open the auras are drawn where they go. An aura whose trigger is
-- off can stay shown greyed out or faded; animations play as auras appear, while they show and as they go (E.Anim).

local E = ns.AuraEngine
local Icon = E.Icon
local Sound = E.Sound
local Group = E.Group
local Movers = E.Movers
local Anim = E.Anim
local AuraSource = E.Sources.aura

-- Global exposed tables
_G.KUIAuraReminders_Custom = _G.KUIAuraReminders_Custom or {}
local CustomSys = _G.KUIAuraReminders_Custom

local customFrames = {}
local database = nil       -- the AceDB object; its profile is read on every pass, so a profile switch is followed
local inCombat = false     -- set by the combat events: InCombatLockdown() is still false inside PLAYER_REGEN_DISABLED
local watchedUnits = {}    -- units the enabled auras read; UNIT_AURA for any other unit is ignored
local staleUnits = {}      -- units that changed (new target, focus or pet): their last known answers are dropped
local env = {}             -- facts handed to the sources and the load checks
local DIM = 0.4            -- alpha factor of an aura shown dimmed while its answer is secret
local ticking = false      -- whether an enabled aura needs the range ticker

local function Profile()
    return database and database.profile
end

local function IsUnlocked()
    return CustomSys.UnlockMode == true
end

-- Placing views: the page's own placing mode (dragged by the auras) or KUI's unlock mode (dragged by its movers).
local function IsPlacing()
    return CustomSys.UnlockMode == true or CustomSys.MoverMode == true
end

-- Drags write the position back into the saved record, in the fields the options page uses; a grouped aura moves
-- its group, whose point is saved in the group's settings.
local function OnMoved(f, target)
    local profile = Profile()
    if not profile then return end
    if target and target ~= f and f.groupName then
        if type(profile.customGroups) ~= "table" then profile.customGroups = {} end
        local settings = profile.customGroups[f.groupName]
        if type(settings) ~= "table" then
            settings = {}
            profile.customGroups[f.groupName] = settings
        end
        local p, _, rp, x, y = target:GetPoint()
        settings.point, settings.relativePoint, settings.xOffset, settings.yOffset = p, rp, x, y
        target.anchorKey = nil
        return
    end
    local conf = profile.customAuras and profile.customAuras[f.uid]
    if conf then
        local p, _, rp, x, y = f:GetPoint()
        conf.point = p
        conf.relativePoint = rp
        conf.xOffset = x
        conf.yOffset = y
    end
end

local function GetCustomAuraFrame(uid)
    local f = customFrames[uid]
    if not f then
        f = Icon.Create(uid, OnMoved, IsUnlocked)
        customFrames[uid] = f
    end
    return f
end

local GetTex, IconSpell = Icon.Texture, E.IconSpell

local function TextureOf(record, data)
    if E.IconTexture then return E.IconTexture(record, data, GetTex) end
    return GetTex(IconSpell(record))
end

-- Hides through the going animation when the aura has one.
local function HideAura(f, record)
    if Anim then
        Anim.Hide(f, record, Icon.Hide)
    else
        Icon.Hide(f)
    end
end

local function Shown(f, record)
    if Anim then Anim.Shown(f, record) end
end

-------------------------------------------------------------------------------
--  Passes
-------------------------------------------------------------------------------
local function ShowPlacing(f, record)
    local region = record.region
    if Anim then Anim.Reset(f) end
    Icon.ClearInactive(f)
    f:Show()
    f:SetAlpha(1)
    f:EnableMouse(true)
    f.delegate:Hide()
    f.icon:SetTexture(TextureOf(record, nil))
    if f.icon.SetDesaturated then f.icon:SetDesaturated(false) end
    f.icon:SetVertexColor(1, 1, 1, 1)
    f.nameText:SetText(record.name or LText("Custom Aura"))
    f.nameText:SetShown(region.nameLabel == true)
    Icon.ApplyLayout(f, region)
    Icon.SetOwnParts(f, region, true)
    Icon.ApplyValueText(f, region, nil, nil)
    f.valueText:SetText(region.text and region.text.value or "")
    Icon.SetGlow(f, false)
    f.mode = "NONE"
end

local function ShowReadable(f, record, data, answers, alphaFactor)
    Icon.ClearInactive(f)
    Icon.ShowReadable(f, record, data, TextureOf(record, data), answers, alphaFactor)
    Shown(f, record)
end

local function ShowInactive(f, record, data, answers)
    Icon.ShowInactive(f, record, data, TextureOf(record, data), answers)
    Shown(f, record)
end

-- The client's engine shows the slot only while the aura is there; the frame stays shown as its host.
local function ShowDelegated(f, record)
    local region = record.region
    Icon.ClearInactive(f)
    f.shownRecord = nil
    f:Show()
    f:SetAlpha(region.alpha or 1.0)
    Icon.ApplyLayout(f, region)
    Icon.SetOwnParts(f, region, false)
    f.mode = "NONE"
    f.delegate:Show()
    Shown(f, record)
end

local function UpdateAura(uid, conf)
    local f = GetCustomAuraFrame(uid)
    local record = E.Migrate(conf)
    f.record = record
    if not record then
        if Anim then Anim.Reset(f) end
        Icon.Hide(f)
        return
    end

    local combatNow = inCombat or (InCombatLockdown and InCombatLockdown()) or false
    if IsPlacing() then
        f.soundState = nil
        if CustomSys.UnlockMode or record.enabled then
            ShowPlacing(f, record)
            f:EnableMouse(CustomSys.UnlockMode == true)
        else
            -- KUI's unlock mode has no mover for a disabled aura.
            if Anim then Anim.Reset(f) end
            Icon.Hide(f)
        end
        return
    end
    f:EnableMouse(false)

    -- The slot is prepared whenever it could be needed, so it exists before combat starts.
    local delegable = record.region.kind ~= "text" and E.DelegableSource(record) or nil
    local slotReady = false
    local spec
    if delegable and record.enabled then
        spec = AuraSource.SlotSpec(delegable)
        slotReady = Icon.SyncDelegate(f, record, spec, combatNow)
    end

    local active, data, answers
    local unknownNow = false
    if record.enabled then
        for unit in pairs(E.UnitsOf and E.UnitsOf(record) or {}) do
            watchedUnits[unit] = true
            if staleUnits[unit] then f.knownActive, f.knownData = nil, nil end
        end
        if E.NeedsTicker and E.NeedsTicker(record) then ticking = true end
        active, data, answers = E.Evaluate(record, env)
        if active == nil then
            -- Unknown right now (secret): never "missing". By the record's choice: the last answer read, shown
            -- normally or dimmed, or nothing.
            unknownNow = true
            if record.unknown == "hide" then
                active, data = false, nil
            else
                active, data = f.knownActive, f.knownData
            end
        else
            f.knownActive, f.knownData = active, data
        end
    end

    local loaded = E.CheckLoad(record, env)
    -- The engine sounds of a delegable aura, while it is loaded.
    local soundSpec = (spec and loaded and Sound.EngineEligible(record, delegable)) and spec or nil
    Sound.SyncEngine(f, record, soundSpec, combatNow)

    if not loaded then
        HideAura(f, record)
        Sound.Transition(f, record, nil)
    elseif slotReady and AuraSource.IsRestricted(delegable) then
        ShowDelegated(f, record)
        Sound.Transition(f, record, nil)
    elseif active then
        ShowReadable(f, record, data, answers, (unknownNow and record.unknown == "dim") and DIM or 1)
        Sound.Transition(f, record, (not unknownNow) or nil)
    elseif unknownNow then
        HideAura(f, record)
        Sound.Transition(f, record, nil)
    else
        -- false when known to be off, nil when not known yet.
        local state = nil
        if active == false then state = false end
        local inactive = record.region.inactive
        if active == false and (inactive == "desaturate" or inactive == "dim") and record.region.kind ~= "text" then
            ShowInactive(f, record, data, answers)
        else
            HideAura(f, record)
        end
        Sound.Transition(f, record, state)
    end
end

local RequestUpdate

-- What the unlock mode's elements read and do (E.Movers).
local moverContext = {
    profile = Profile,
    auraFrame = GetCustomAuraFrame,
    groupFrame = function(name) return Group.FrameOf(name, true) end,
    changed = function() RequestUpdate() end,
    label = LText,
}

local function UpdateCustomAuras()
    local profile = Profile()
    local auras = profile and profile.customAuras
    if type(auras) ~= "table" then auras = {} end

    env.inCombat = inCombat
    wipe(watchedUnits)
    ticking = false
    local grouped, entries = {}, {}
    for uid, conf in pairs(auras) do
        UpdateAura(uid, conf)
        local f = customFrames[uid]
        if f and f.record then entries[#entries + 1] = { uid = uid, record = f.record } end
        if f and f.record and f.record.region.group then
            grouped[#grouped + 1] = { uid = uid, f = f, record = f.record }
        elseif f then
            Group.Release(f)
        end
    end
    wipe(staleUnits)
    Group.Layout(profile, grouped, inCombat or (InCombatLockdown and InCombatLockdown()) or false)
    if Movers then Movers.Sync(KT, moverContext, entries) end
    CustomSys.SetTicker(ticking)

    -- Frames of deleted auras, or of another profile.
    for uid, f in pairs(customFrames) do
        if auras[uid] == nil then
            if Anim then Anim.Reset(f) end
            Icon.Hide(f)
            Group.Release(f)
            f.record = nil
            f.knownActive, f.knownData, f.soundState = nil, nil, nil
            Sound.ClearEngine(f, inCombat or (InCombatLockdown and InCombatLockdown()) or false)
        end
    end
end

-------------------------------------------------------------------------------
--  Event Engine
-------------------------------------------------------------------------------
local engine = CreateFrame("Frame")

-- Some events exist in one client only; registering an unknown event raises.
local EVENTS = {
    "UNIT_AURA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELLS_CHANGED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET", "GROUP_ROSTER_UPDATE",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "PLAYER_SPECIALIZATION_CHANGED",
    "ADDON_RESTRICTION_STATE_CHANGED", "ENCOUNTER_START", "ENCOUNTER_END", "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    -- Value triggers and the new load checks.
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
    "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_USABLE", "UPDATE_STEALTH", "UNIT_FLAGS",
    "PLAYER_LEVEL_UP", "ROLE_CHANGED_INFORM", "PLAYER_ROLES_ASSIGNED", "ACTIVE_TALENT_GROUP_CHANGED",
}
for _, event in ipairs(EVENTS) do
    pcall(engine.RegisterEvent, engine, event)
end

-- Unit events that are dropped for a unit no enabled aura reads.
local UNIT_EVENTS = {
    UNIT_AURA = true, UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true,
    UNIT_DISPLAYPOWER = true, UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_DELAYED = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true, UNIT_SPELLCAST_EMPOWER_START = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true, UNIT_FLAGS = true,
}

-- Events are coalesced: one pass on the next frame however many arrive.
local function RunPending(self)
    self:SetScript("OnUpdate", nil)
    UpdateCustomAuras()
end

function RequestUpdate()
    engine:SetScript("OnUpdate", RunPending)
end

-- A Cooldown Manager item gaining or losing its aura asks for a pass.
E.Sources.cdm.Watch(RequestUpdate)

-- Range is not sent as an event: while an aura asks for it, a pass every RANGE_PERIOD seconds.
local RANGE_PERIOD = 0.25
local ticker

function CustomSys.SetTicker(on)
    if on and not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(RANGE_PERIOD, function() RequestUpdate() end)
    elseif not on and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

engine:SetScript("OnEvent", function(_, event, unit)
    if UNIT_EVENTS[event] then
        if not watchedUnits[unit] then return end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        inCombat = (InCombatLockdown and InCombatLockdown())
            or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
        env.encounterID = nil
    elseif event == "ENCOUNTER_START" then
        -- The second argument is the encounter ID.
        env.encounterID = type(unit) == "number" and unit or 0
    elseif event == "ENCOUNTER_END" then
        env.encounterID = nil
    elseif event == "PLAYER_TARGET_CHANGED" then
        staleUnits.target = true
    elseif event == "PLAYER_FOCUS_CHANGED" then
        staleUnits.focus = true
    elseif event == "UNIT_PET" then
        if unit ~= "player" then return end
        staleUnits.pet = true
    end
    RequestUpdate()
end)

-- KUI's unlock mode: the auras are drawn while it is open (a close that asks first keeps it open), then its movers are
-- synced to the frames now shown. Hooked once.
local unlockHooked = false
local function HookUnlockMode()
    if unlockHooked or not (Movers and hooksecurefunc) then return end
    local um = Movers.UnlockModule(KT)
    if not (um and um.OpenUnlockMode and um.CloseUnlockMode) then return end
    unlockHooked = true
    local function Follow()
        CustomSys:SetMoverMode(um.isOpen == true)
        if um.isOpen and um.RefreshMovers then pcall(um.RefreshMovers, um) end
    end
    hooksecurefunc(um, "OpenUnlockMode", Follow)
    hooksecurefunc(um, "CloseUnlockMode", Follow)
end

function CustomSys:Init(db)
    database = db
    HookUnlockMode()
    inCombat = (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
    local profile = Profile()
    -- Ensure customAuras exists
    if profile and type(profile.customAuras) ~= "table" then
        profile.customAuras = {}
    end
    if db and type(db.RegisterCallback) == "function" then
        local function OnProfile()
            local current = Profile()
            if current and type(current.customAuras) ~= "table" then current.customAuras = {} end
            UpdateCustomAuras()
        end
        db.RegisterCallback(CustomSys, "OnProfileChanged", OnProfile)
        db.RegisterCallback(CustomSys, "OnProfileCopied", OnProfile)
        db.RegisterCallback(CustomSys, "OnProfileReset", OnProfile)
    end
    UpdateCustomAuras()
end

function CustomSys:SetUnlockMode(state)
    self.UnlockMode = state
    UpdateCustomAuras()
end

-- While KUI's unlock mode is open. Leaving it drops the drags it left pending; the saved points are drawn again.
function CustomSys:SetMoverMode(state)
    state = state == true
    if self.MoverMode == state then return end
    self.MoverMode = state
    if not state then
        for _, f in pairs(customFrames) do
            f.moverPoint = nil
            local g = f.groupFrame
            if g then g.moverPoint, g.anchorKey = nil, nil end
        end
        local profile = Profile()
        for name in pairs(profile and type(profile.customGroups) == "table" and profile.customGroups or {}) do
            local g = Group.FrameOf(name)
            if g then g.moverPoint, g.anchorKey = nil, nil end
        end
    end
    UpdateCustomAuras()
end

function CustomSys:ForceUpdate()
    UpdateCustomAuras()
end
