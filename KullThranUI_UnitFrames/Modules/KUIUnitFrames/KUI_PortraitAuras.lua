-------------------------------------------------------------------------------
--  Portrait auras: the most important aura of a unit drawn over its portrait.
--
--  One icon per category, stacked by priority (the highest one that exists wins):
--      Crowd Control > Disarm > Big Defensive > External Defensive > Important
--
--  The categories are the client's own aura flags (CROWD_CONTROL, BIG_DEFENSIVE,
--  EXTERNAL_DEFENSIVE, IMPORTANT), evaluated by the engine, so they keep working while
--  aura data is secret. Each category is a single-icon AuraKit slot; the engine hides an
--  empty slot, so the next one down shows through.
--
--  Setting table: KT.db.profile.unitFrames.portraitAuras (see PA.DEFAULTS).
-------------------------------------------------------------------------------
local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local S = KT.PortraitAuraShared

local PA = ns.PortraitAuras or {}
ns.PortraitAuras = PA
PA.hosts = PA.hosts or {}
PA.previewHosts = PA.previewHosts or {}
PA.Catalog = S.Catalog

PA.UNITS = { "player", "target", "focus", "pet", "targettarget", "focustarget" }

PA.DEFAULTS = {
    enabled = false,
    reverseSwipe = true,
    showNumbers = true,
    fontScale = 1,
    units = { player = true, target = true, focus = true, pet = false, targettarget = false, focustarget = false },
    customSpells = "",
    disabledSpells = {},
    categories = S.CATEGORY_DEFAULTS,
}

PA.TIERS = S.TIERS

local ALWAYS_ASSISTABLE = { player = true, pet = true }
local ROUND_SWIPE = S.ROUND_SWIPE
local PREVIEW_DURATION = S.PREVIEW_DURATION

-------------------------------------------------------------------------------
--  Options
-------------------------------------------------------------------------------
local function Store()
    local profile = KT.db and KT.db.profile
    if not profile then return nil end
    profile.unitFrames = profile.unitFrames or {}
    profile.unitFrames.portraitAuras = profile.unitFrames.portraitAuras or {}
    return profile.unitFrames.portraitAuras
end

function PA.GetOption(key)
    local s = Store()
    local v = s and s[key]
    if v == nil then return PA.DEFAULTS[key] end
    return v
end

function PA.SetOption(key, value)
    local s = Store()
    if s then s[key] = value end
end

local function SubOption(group, key)
    local s = Store()
    local t = s and s[group]
    if type(t) == "table" and t[key] ~= nil then return t[key] end
    return PA.DEFAULTS[group][key]
end

function PA.GetSub(group, key) return SubOption(group, key) end

function PA.SetSub(group, key, value)
    local s = Store()
    if not s then return end
    s[group] = s[group] or {}
    s[group][key] = value
end

-- Catalog entries the user switched off in the visual catalog (every id of the entry).
function PA.IsEntryEnabled(entry)
    local disabled = PA.GetOption("disabledSpells")
    return not (type(disabled) == "table" and entry and entry.ids[1] and disabled[entry.ids[1]])
end

function PA.SetEntryEnabled(entry, on)
    local s = Store()
    if not (s and entry) then return end
    s.disabledSpells = type(s.disabledSpells) == "table" and s.disabledSpells or {}
    for _, id in ipairs(entry.ids) do
        s.disabledSpells[id] = (not on) and true or nil
    end
    PA._disabledVersion = (PA._disabledVersion or 0) + 1
end

function PA.SetEntriesEnabled(entries, on)
    for _, entry in ipairs(entries or {}) do PA.SetEntryEnabled(entry, on) end
end

function PA.SetGroupEnabled(group, on)
    local catalog = PA.Catalog
    if not (catalog and catalog.GetEntries) then return end
    for _, entry in ipairs(catalog.GetEntries(group)) do PA.SetEntryEnabled(entry, on) end
end

function PA.IsEnabled() return PA.GetOption("enabled") == true end
function PA.IsUnitOn(unit) return PA.IsEnabled() and SubOption("units", unit) == true end

-- The catalog sets for this client, rebuilt only when the custom ids change.
PA._cache = {}
function PA.GetCatalogSets()
    return S.GetCatalogSets(PA._cache, PA.GetOption("customSpells"), PA.GetOption("disabledSpells"), PA._disabledVersion)
end

local function WantTier(tier) return SubOption("categories", tier.opt) == true end

-------------------------------------------------------------------------------
--  Host (one per portrait)
-------------------------------------------------------------------------------
local function PortraitBackdrop(unit)
    local frame = ns.frames and ns.frames[unit]
    local portrait = frame and frame.Portrait
    local backdrop = portrait and portrait.backdrop
    return frame, backdrop
end

local function StyleKey(unit) return "kuiuf:portrait:" .. unit end

local function BuildStyle(backdrop)
    local width = backdrop and backdrop.GetWidth and backdrop:GetWidth() or 40
    return S.BuildStyle(width, PA.GetOption("reverseSwipe"), PA.GetOption("showNumbers"), PA.GetOption("fontScale"))
end

local function SeatMask(host)
    local backdrop = host.backdrop
    local mask = backdrop and backdrop._shapeMask
    S.SeatMask(host, mask, mask and ROUND_SWIPE or nil)
end

local function RaiseHost(host)
    local backdrop = host.backdrop
    if not backdrop then return end
    local level = backdrop:GetFrameLevel() or 1
    local model = backdrop._3d
    if model and model.GetFrameLevel then level = math.max(level, model:GetFrameLevel() or 0) end
    S.StackLevels(host, level + 3)
end

local function CreateHost(unit)
    local AK = _G.KTAuraKit
    local frame, backdrop = PortraitBackdrop(unit)
    if not (AK and AK.CreateContainer and frame and backdrop) then return nil end

    local host = { unit = unit, backdrop = backdrop, icons = {}, cooldowns = {}, buttonOrder = {} }
    host.frame = CreateFrame("Frame", nil, backdrop)
    host.frame:SetAllPoints(backdrop)
    host.frame:EnableMouse(false)

    local key = StyleKey(unit)
    AK.styles[key] = BuildStyle(backdrop)
    local slots = S.BuildSlots(host, key, PA.GetCatalogSets(), ALWAYS_ASSISTABLE[unit])

    PA.hosts[unit] = host
    AK.RequestContainer(host.frame, unit, { point = { "CENTER", host.frame, "CENTER" }, slots = slots },
        function(container)
            host.container = container
            container:SetAllPoints(host.frame)
            PA.RefreshUnit(unit, true)
        end)
    return host
end

-------------------------------------------------------------------------------
--  Refresh
-------------------------------------------------------------------------------
local function UpdateSlots(host)
    return S.UpdateSlots(host, PA.IsUnitOn(host.unit), WantTier, PA.GetCatalogSets())
end

function PA.RefreshUnit(unit, force)
    local host = PA.hosts[unit]
    if not host then
        if not PA.IsUnitOn(unit) then return end
        host = CreateHost(unit)
        if not host then return end
    end
    local _, backdrop = PortraitBackdrop(unit)
    if backdrop and backdrop ~= host.backdrop then
        -- The portrait was rebuilt: follow it.
        host.backdrop = backdrop
        host.frame:SetParent(backdrop)
        host.frame:ClearAllPoints()
        host.frame:SetAllPoints(backdrop)
        host.maskSeated = nil
    end
    S.SyncStyle(StyleKey(unit), BuildStyle(host.backdrop))
    SeatMask(host)
    RaiseHost(host)
    local changed = UpdateSlots(host)
    if (force or changed) and host.shown and host.container and host.container.UpdateAllAuras then
        host.container:UpdateAllAuras()
    end
end

function PA.RefreshAll()
    for _, unit in ipairs(PA.UNITS) do PA.RefreshUnit(unit, true) end
end

-------------------------------------------------------------------------------
--  Preview (a fake icon over every enabled portrait, for the options page)
-------------------------------------------------------------------------------
local function RestartPreview()
    local now = GetTime()
    for _, host in pairs(PA.hosts) do
        if host.preview then host.preview.cooldown:SetCooldown(now, PREVIEW_DURATION) end
    end
    for host in pairs(PA.previewHosts) do
        if host.preview and host.preview:IsShown() then host.preview.cooldown:SetCooldown(now, PREVIEW_DURATION) end
    end
end

-- The live preview of the options page (its mock frames, not the real ones). `frame` is a mock
-- unit with a portraitFrame; the fake icon follows the preview switch and the unit's switch.
local PREVIEW_UNIT = { totPet = "targettarget" }
function PA.ApplyPreview(frame, unitKey)
    if not (frame and frame.portraitFrame) then return end
    local unit = PREVIEW_UNIT[unitKey] or unitKey
    local host = frame._ktPortraitAuraPreview
    local show = PA.previewOn and SubOption("units", unit) == true and frame.portraitFrame:IsShown()
    if not show then
        if host and host.preview then host.preview:Hide() end
        return
    end
    if not host then
        host = { frame = frame.portraitFrame, icons = {}, cooldowns = {}, buttonOrder = {} }
        frame._ktPortraitAuraPreview = host
        PA.previewHosts[host] = true
    end
    local p = S.EnsurePreview(host)
    S.StylePreview(p, PA.GetOption("reverseSwipe"), PA.GetOption("showNumbers"))
    local mask = frame.portraitMask
    if mask and not (mask.IsShown and mask:IsShown()) then mask = nil end
    S.SeatMask(host, mask, mask and ROUND_SWIPE or nil)
    p:SetFrameLevel((frame.portraitFrame:GetFrameLevel() or 1) + 1)
    p:Show()
    if not host.started then
        host.started = true
        p.cooldown:SetCooldown(GetTime(), PREVIEW_DURATION)
    end
end

function PA.SetPreview(show)
    if PA.previewTicker then PA.previewTicker:Cancel(); PA.previewTicker = nil end
    PA.previewOn = show and true or false
    for _, unit in ipairs(PA.UNITS) do
        local host = PA.hosts[unit]
        if not host and show and PA.IsUnitOn(unit) then
            PA.RefreshUnit(unit, true)
            host = PA.hosts[unit]
        end
        if host then
            local p = show and PA.IsUnitOn(unit) and S.EnsurePreview(host) or host.preview
            if p then
                S.StylePreview(p, PA.GetOption("reverseSwipe"), PA.GetOption("showNumbers"))
                p:SetShown(show and PA.IsUnitOn(unit))
            end
            SeatMask(host)
            RaiseHost(host)
        end
    end
    if show then
        RestartPreview()
        PA.previewTicker = C_Timer.NewTicker(PREVIEW_DURATION, RestartPreview)
    end
end

function PA.IsPreviewOn() return PA.previewOn == true end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:RegisterUnitEvent("UNIT_PET", "player")
ev:RegisterUnitEvent("UNIT_FACTION", "target", "focus")
ev:RegisterUnitEvent("UNIT_FLAGS", "target", "focus")
ev:RegisterUnitEvent("UNIT_CONNECTION", "target", "focus")
-- The target of the target / of the focus changes without the target changing.
ev:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
ev:SetScript("OnEvent", function(_, event, unit)
    if not PA.IsEnabled() then
        if next(PA.hosts) then PA.RefreshAll() end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        PA.RefreshUnit("target", true)
        PA.RefreshUnit("targettarget", true)
    elseif event == "PLAYER_FOCUS_CHANGED" then
        PA.RefreshUnit("focus", true)
        PA.RefreshUnit("focustarget", true)
    elseif event == "UNIT_TARGET" then
        PA.RefreshUnit(unit == "focus" and "focustarget" or "targettarget", true)
    elseif event == "UNIT_PET" then
        PA.RefreshUnit("pet", true)
    elseif unit then
        PA.RefreshUnit(unit, event == "UNIT_FACTION")
    else
        PA.RefreshAll()
    end
end)
