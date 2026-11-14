local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

-- 1 -> 2: legacy repair (RepairLegacyState, wipes slots and forces kui).
-- 2 -> 3: additive backfill of the owned paths added by the honest
--         per-theme rendering pass (MigrateAddedThemePaths); never resets
--         the active theme and never overwrites an existing slot value.
KT.VisualThemes.SCHEMA_VERSION = 3
KT.VisualThemes.LEGACY_REPAIR_SCHEMA_VERSION = 2

function KT.VisualThemes:InitSlots(profile)
    if type(profile) ~= "table" then return nil end
    profile.visualTheme = profile.visualTheme or {}
    local state = profile.visualTheme
    state.active = state.active or "kui"
    state.requested = state.requested or state.active
    state.modules = type(state.modules) == "table" and state.modules or {}
    state.slots = type(state.slots) == "table" and state.slots or {}
    state.applied = type(state.applied) == "table" and state.applied or {}
    return state
end

function KT.VisualThemes:SaveSlot(profile, moduleKey, themeKey, data)
    local state = self:InitSlots(profile)
    if not state then return end
    state.slots[moduleKey] = state.slots[moduleKey] or {}
    state.slots[moduleKey][themeKey] = data
end

function KT.VisualThemes:LoadSlot(profile, moduleKey, themeKey)
    local state = self:InitSlots(profile)
    local moduleSlots = state and state.slots[moduleKey]
    return moduleSlots and moduleSlots[themeKey] or nil
end
