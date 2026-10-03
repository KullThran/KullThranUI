local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local NIL_MARKER_KEY = "__ktVisualThemeNil"

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[DeepCopy(key, seen)] = DeepCopy(child, seen)
    end
    return result
end

local function PackValue(value)
    if value == nil then
        return { [NIL_MARKER_KEY] = true }
    end
    return DeepCopy(value)
end

local function UnpackValue(value)
    if type(value) == "table" and value[NIL_MARKER_KEY] == true then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        if count == 1 then return nil end
    end
    return DeepCopy(value)
end

local function GetPath(tbl, path)
    if type(tbl) ~= "table" or type(path) ~= "string" then return nil end
    local current = tbl
    for key in string.gmatch(path, "[^%.]+") do
        if type(current) ~= "table" then return nil end
        local numeric = tonumber(key)
        current = current[numeric or key]
    end
    return current
end

local function SetPath(tbl, path, value)
    if type(tbl) ~= "table" or type(path) ~= "string" then return end
    local keys = {}
    for key in string.gmatch(path, "[^%.]+") do
        keys[#keys + 1] = tonumber(key) or key
    end
    if #keys == 0 then return end
    local current = tbl
    for index = 1, #keys - 1 do
        local key = keys[index]
        if type(current[key]) ~= "table" then current[key] = {} end
        current = current[key]
    end
    current[keys[#keys]] = UnpackValue(value)
end

local function CapturePaths(profile, paths)
    local data = {}
    for _, path in ipairs(paths or {}) do
        data[path] = PackValue(GetPath(profile, path))
    end
    return data
end

local function ApplyPaths(profile, data)
    for path, value in pairs(data or {}) do
        SetPath(profile, path, value)
    end
end

local function GetClientFlavor()
    if _G.WOW_PROJECT_ID and _G.WOW_PROJECT_MAINLINE
        and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE then
        return "retail"
    end
    return "forever"
end

local function AdapterAvailable(adapter, clientFlavor)
    if type(adapter) ~= "table" then return false end
    if type(adapter.isAvailable) ~= "function" then return true end
    local ok, available = pcall(adapter.isAvailable, clientFlavor)
    return ok and available ~= false
end

local function AdapterProfile(adapter)
    if type(adapter) ~= "table" or type(adapter.getProfile) ~= "function" then return nil end
    local ok, profile = pcall(adapter.getProfile)
    if ok and type(profile) == "table" then return profile end
    return nil
end

function KT.VisualThemes:GetClientFlavor()
    return GetClientFlavor()
end

function KT.VisualThemes:RepairLegacyState(profile)
    local state = self:InitSlots(profile)
    if not state then return end
    local version = tonumber(state.schemaVersion) or 0
    -- Only the original pre-system migration (schema < 2) wipes slots and
    -- forces kui. Schema 2 -> 3 is handled additively by
    -- MigrateAddedThemePaths below and must never reach this wipe.
    if version >= self.LEGACY_REPAIR_SCHEMA_VERSION then return end

    local registry, order = self:GetAllAdapters()
    for _, moduleKey in ipairs(order or {}) do
        local adapter = registry[moduleKey]
        local oldSlot = state.slots[moduleKey] and state.slots[moduleKey].kui
        local moduleProfile = AdapterProfile(adapter)
        if moduleProfile and type(oldSlot) == "table" then
            ApplyPaths(moduleProfile, oldSlot)
        end
        if moduleProfile and type(adapter.validate) == "function" then
            pcall(adapter.validate, moduleProfile, "kui", GetClientFlavor())
        end
    end

    state.active = "kui"
    state.requested = "kui"
    state.modules = {}
    state.slots = {}
    state.applied = {}
    state.schemaVersion = self.SCHEMA_VERSION
end

-- Owned paths added in schema 3 (honest per-theme rendering). Slots saved
-- under schema 2 do not contain them, and the live profile of the active
-- non-kui theme was never seeded with them. Scoped per module on purpose:
-- e.g. nameplates already owned its own borderColor before schema 3.
local SCHEMA3_ADDED_PATH_PATTERNS = {
    unitframes = { "^frameArtKit$", "%.borderColor%.[rgb]$" },
    actionbars = { "^frameArtKit$" },
    castbar = { "^frameArtKit$" },
    resourcebars = { "^general%.frameArtKit$", "^health%.fill[RGB]$" },
    cooldownmanager = { "frameArtKit$" },
    partyframes = { "%.absorbBarColor%.[rgb]$" },
}

local function FilterAddedPaths(paths, patterns)
    local added = {}
    for _, path in ipairs(paths or {}) do
        for _, pattern in ipairs(patterns) do
            if string.find(path, pattern) then
                added[#added + 1] = path
                break
            end
        end
    end
    return added
end

local function SeededCopy(adapter, moduleProfile, themeKey, clientFlavor)
    local scratch = DeepCopy(moduleProfile)
    adapter.seed(scratch, themeKey, clientFlavor)
    return scratch
end

-- Additive schema 2 -> 3 step for one module. Never changes state.active,
-- never overwrites a value already stored in any slot, and on the live
-- profile only writes the schema-3 paths (so any other customization of
-- the active theme is kept).
function KT.VisualThemes:MigrateAddedThemePaths(state, moduleKey)
    local adapter = self:GetModuleAdapter(moduleKey)
    local patterns = SCHEMA3_ADDED_PATH_PATTERNS[moduleKey]
    if not adapter or not patterns then return true end
    local clientFlavor = GetClientFlavor()
    if not AdapterAvailable(adapter, clientFlavor) then return false end
    local moduleProfile = AdapterProfile(adapter)
    if not moduleProfile then return false end
    if type(adapter.seed) ~= "function" or type(adapter.getOwnedPaths) ~= "function" then return true end

    local activeTheme = state.active
    local ok, err = pcall(function()
        local added = FilterAddedPaths(adapter.getOwnedPaths(activeTheme, clientFlavor, moduleProfile), patterns)
        if #added == 0 then return end

        -- 1) Existing slots of the other themes: fill only the missing keys.
        --    Before schema 3 none of these paths was theme-owned, so the
        --    live value is the user's own value, i.e. what kui showed.
        --    Other themes get their own seed() value.
        local moduleSlots = state.slots[moduleKey]
        if type(moduleSlots) == "table" then
            for themeKey, slot in pairs(moduleSlots) do
                if type(slot) == "table" and themeKey ~= activeTheme and self:IsKnownTheme(themeKey) then
                    local seeded = SeededCopy(adapter, moduleProfile, themeKey, clientFlavor)
                    for _, path in ipairs(added) do
                        if slot[path] == nil then
                            local value = GetPath(seeded, path)
                            if themeKey == "kui" and GetPath(moduleProfile, path) ~= nil then
                                value = GetPath(moduleProfile, path)
                            end
                            slot[path] = PackValue(value)
                        end
                    end
                end
            end
        end

        -- 2) Live profile of the active theme: backfill only the added
        --    paths from that theme's own seed(). KUI Style is skipped: its
        --    live values are the user's own Retail settings.
        if activeTheme == "kui" then return end
        local seeded = SeededCopy(adapter, moduleProfile, activeTheme, clientFlavor)
        for _, path in ipairs(added) do
            local value = GetPath(seeded, path)
            if value ~= nil and value ~= GetPath(moduleProfile, path) then
                SetPath(moduleProfile, path, value)
            end
        end
    end)
    if not ok and KT.Print then
        KT:Print("Visual theme migration failed in " .. moduleKey .. ": " .. tostring(err))
    end
    -- A failure is not retried forever: the module keeps its current data.
    return true
end

function KT.VisualThemes:RunPendingThemeMigrations(state)
    local pending = state.pendingPathMigration
    if type(pending) ~= "table" then
        state.pendingPathMigration = nil
        return
    end
    for moduleKey in pairs(pending) do
        -- A module whose profile does not exist yet (addon disabled or not
        -- loaded) stays pending and is migrated the first time it appears.
        if self:MigrateAddedThemePaths(state, moduleKey) then
            pending[moduleKey] = nil
        end
    end
    if next(pending) == nil then state.pendingPathMigration = nil end
end

-- One-time: Retail and Forever default their Unit Frames bar texture to
-- "Blizzard Raid Bar". Slots/live profiles saved before the texture became
-- user-editable per style may still hold an older default, so reset them once.
local RAID_BAR_TEXTURE = "Blizzard Raid Bar"
local RAID_BAR_UNITS = { "player", "target", "focus", "pet", "boss", "totPet" }

function KT.VisualThemes:MigrateRaidBarDefault(state)
    if state.raidBarDefault20261002 then return end
    local adapter = self:GetModuleAdapter("unitframes")
    local moduleProfile = adapter and AdapterProfile(adapter)
    if not moduleProfile then return end -- retried once the module exists
    local slots = state.slots and state.slots.unitframes
    if type(slots) == "table" then
        for _, themeKey in ipairs({ "forever", "retail" }) do
            local slot = slots[themeKey]
            if type(slot) == "table" then
                for _, unit in ipairs(RAID_BAR_UNITS) do
                    local path = unit .. ".healthBarTexture"
                    if slot[path] ~= nil then slot[path] = RAID_BAR_TEXTURE end
                end
            end
        end
    end
    if state.active == "forever" or state.active == "retail" then
        for _, unit in ipairs(RAID_BAR_UNITS) do
            if type(moduleProfile[unit]) == "table" then
                moduleProfile[unit].healthBarTexture = RAID_BAR_TEXTURE
            end
        end
    end
    state.raidBarDefault20261002 = true
end

-- Forever's accent is #DC8560. Stored values (theme slots and, while Forever is the active
-- theme, the live module profiles) still hold the older gold/bronze, and seeds only run on
-- an explicit theme switch -- so push the new color once, for every Forever-owned path.
local FOREVER_ACCENT = { r = 0.862745, g = 0.521569, b = 0.376471, a = 1 }
local FOREVER_ACCENT_PATHS = {
    minimap = { borderColor = FOREVER_ACCENT },
    skin = {
        customBorderColor = FOREVER_ACCENT,
        ["accentColor.r"] = FOREVER_ACCENT.r, ["accentColor.g"] = FOREVER_ACCENT.g,
        ["accentColor.b"] = FOREVER_ACCENT.b, ["accentColor.a"] = 1,
    },
}

function KT.VisualThemes:MigrateForeverAccent(state)
    if state.foreverAccentDC8560 then return end
    for moduleKey, paths in pairs(FOREVER_ACCENT_PATHS) do
        local slot = type(state.slots) == "table" and type(state.slots[moduleKey]) == "table"
            and state.slots[moduleKey].forever or nil
        if type(slot) == "table" then
            for path, value in pairs(paths) do
                slot[path] = DeepCopy(value)
            end
        end
        if state.active == "forever" then
            local adapter = self:GetModuleAdapter(moduleKey)
            local moduleProfile = adapter and AdapterProfile(adapter)
            if not moduleProfile then return end -- retried once the module exists
            for path, value in pairs(paths) do
                SetPath(moduleProfile, path, value)
            end
        end
    end
    state.foreverAccentDC8560 = true
end

function KT.VisualThemes:EnsureInitialized()
    local profile = KT.db and KT.db.profile
    if not profile then return nil end
    self:RepairLegacyState(profile)
    local state = self:InitSlots(profile)
    local version = tonumber(state.schemaVersion) or 0
    if version < 3 then
        local pending = {}
        for moduleKey in pairs(SCHEMA3_ADDED_PATH_PATTERNS) do pending[moduleKey] = true end
        state.pendingPathMigration = pending
    end
    state.schemaVersion = self.SCHEMA_VERSION
    if not self:IsKnownTheme(state.active) then state.active = "kui" end
    if not self:IsKnownTheme(state.requested) then state.requested = state.active end
    if state.pendingPathMigration ~= nil then
        self:RunPendingThemeMigrations(state)
    end
    self:MigrateRaidBarDefault(state)
    self:MigrateForeverAccent(state)
    return profile, state
end

function KT.VisualThemes:GetRenderedTheme()
    local profile = KT.db and KT.db.profile
    if profile then
        self:EnsureInitialized()
    end
    local state = profile and profile.visualTheme
    if state and self:IsKnownTheme(state.active) then
        return state.active
    end
    return "kui"
end

-- Fixed chrome identity for the Damage Meter header/border. Classic and
-- Retail share the same "Blizzard style" gold; kui keeps following the
-- user's own accent color (returns nil so callers fall back to it).
local DAMAGE_METER_CHROME_COLORS = {
    classic = { 1.00, 0.82, 0.10 },
    retail = { 1.00, 0.82, 0.10 },
    forever = { 0.862745, 0.521569, 0.376471 }, -- #DC8560
}

function KT.VisualThemes:GetDamageMeterAccentColor()
    local color = DAMAGE_METER_CHROME_COLORS[self:GetRenderedTheme()]
    if color then return color[1], color[2], color[3] end
    return nil
end

function KT.VisualThemes:GetRequestedTheme()
    local profile = KT.db and KT.db.profile
    local state = profile and profile.visualTheme
    if state and self:IsKnownTheme(state.requested) then
        return state.requested
    end
    return self:GetRenderedTheme()
end

function KT.VisualThemes:ApplyCurrentThemeToModule(moduleKey)
    local profile, state = self:EnsureInitialized()
    if not profile or type(moduleKey) ~= "string" then return false end
    local adapter = self:GetModuleAdapter(moduleKey)
    if not adapter then return false end

    local clientFlavor = GetClientFlavor()
    if not AdapterAvailable(adapter, clientFlavor) then return false end
    local moduleProfile = AdapterProfile(adapter)
    if not moduleProfile then return false end

    local activeTheme = state.active
    if state.applied[moduleKey] == activeTheme then
        -- Validate theme-owned fields even when the persisted applied marker
        -- says this module was already initialized. This repairs slots from
        -- older builds without requiring the user to switch away and back.
        if type(adapter.validate) == "function" then
            pcall(adapter.validate, moduleProfile, activeTheme, clientFlavor)
        end
        return true
    end

    local ok, err = pcall(function()
        local destination = self:LoadSlot(profile, moduleKey, activeTheme)
        if destination then
            ApplyPaths(moduleProfile, destination)
        elseif activeTheme ~= "kui" and type(adapter.seed) == "function" then
            adapter.seed(moduleProfile, activeTheme, clientFlavor)
        end
        if type(adapter.validate) == "function" then
            adapter.validate(moduleProfile, activeTheme, clientFlavor)
        end
    end)
    if not ok then
        if KT.Print then KT:Print("Visual theme initialization failed in " .. moduleKey .. ": " .. tostring(err)) end
        return false
    end

    state.applied[moduleKey] = activeTheme
    return true
end

-- Re-selecting a theme (same or different) resets the combo point choices to the
-- theme's defaults, even if the user had picked a style in Unit Frames.
function KT.VisualThemes:ResetComboDefaults()
    -- Nameplates: selecting a theme drops a manually picked nameplate style preset (so the plates
    -- follow the theme again) and the enemy-plate sizes/dimensions saved under the previous one,
    -- exactly like clicking a preset tile in Nameplates > General. The adapter seed already set
    -- the theme's textures/border/colors.
    do
        local ad = self.GetModuleAdapter and self:GetModuleAdapter("nameplates")
        local P = ad and ad.getProfile and ad.getProfile()
        local _, kst = self:EnsureInitialized()
        local kuiTarget = kst and kst.active == "kui"
        -- KullThranUI Style keeps the user's own plate sizes: they are part
        -- of the kui slot, so going back to kui restores them instead of
        -- resetting them, and re-selecting kui with no slot changes nothing.
        local kuiSlot = kuiTarget and self:LoadSlot(KT.db.profile, "nameplates", "kui") or nil
        local tables = (not kuiTarget or kuiSlot) and { _G.KullThranUINameplatesDB, _G.KullThranUINameplatesDB_Forever, P } or {}
        local PREFIX = { "healthBar", "castBar", "cast", "enemyName", "level", "name", "classPower",
            "textSlot", "raidMarker", "rareElite", "targetArrow", "focusCast" }
        local seen = {}
        for _, tbl in ipairs(tables) do
            if type(tbl) == "table" and not seen[tbl] then
                seen[tbl] = true
                tbl.nameplateStyle = nil
                for k in pairs(tbl) do
                    if type(k) == "string" and not k:find("^friendly") then
                        for _, pre in ipairs(PREFIX) do
                            if k:sub(1, #pre) == pre then tbl[k] = nil; break end
                        end
                    end
                end
                tbl.classPowerPos = "bottom"
            end
        end
        -- re-seed the theme's own plate look (also covers re-selecting the active theme)
        local _, nst = self:EnsureInitialized()
        local nth = nst and nst.active
        if kuiTarget then
            if kuiSlot and P then ApplyPaths(P, kuiSlot) end
        elseif ad and ad.seed and P and nth then
            pcall(ad.seed, P, nth)
            if ad.validate then pcall(ad.validate, P) end
        end
        if type(KT.RefreshNameplateTheme) == "function" then pcall(KT.RefreshNameplateTheme) end
    end
    -- Minimap: selecting a theme overwrites any manual ring choice (auto = the theme's
    -- own ring: kui none, forever, retail, classic) and puts the round shape the ring needs.
    local mm = KT.db and KT.db.profile and KT.db.profile.minimap
    if type(mm) == "table" then
        local _, mst = self:EnsureInitialized()
        local mth = mst and mst.active
        mm.ringStyle = nil
        if mth == "forever" or mth == "retail" or mth == "classic" then mm.shape = "ROUND" end
        local MM = KT.GetModule and KT:GetModule("Minimap", true)
        if MM and MM.Refresh then pcall(MM.Refresh, MM) end
    end
    local uf = KT.db and KT.db.profile and KT.db.profile.unitFrames
    if type(uf) ~= "table" then return end
    uf.comboUnderFrame = nil
    uf.comboTargetStyle = nil
    -- Forever/Retail: health bar fill back to the theme's reference green.
    local _, st = self:EnsureInitialized()
    local th = st and st.active
    if th == "forever" or th == "retail" then
        -- modern PvP icon is the default here: drop any stored player/target style
        uf.pvpIconStyle = nil
        uf.pvpIconStyleTarget = nil
        for _, key in ipairs({ "player", "target" }) do
            uf[key] = type(uf[key]) == "table" and uf[key] or {}
            uf[key].customFillColor = { r = 0.57, g = 1.00, b = 0.235 }
            uf[key].healthClassColored = false
        end
        local root = KT.db.profile
        if type(root.visualThemeHealth) == "table" then root.visualThemeHealth[th] = nil end
    end
    if type(KT.RefreshComboUnderFrame) == "function" then pcall(KT.RefreshComboUnderFrame) end
end

function KT.VisualThemes:ApplyAll(targetTheme)
    if not self:IsKnownTheme(targetTheme) then
        if KT.Print then KT:Print("Unknown visual theme: " .. tostring(targetTheme)) end
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        if KT.Print then KT:Print("Visual themes cannot be changed during combat.") end
        return false
    end

    local profile, state = self:EnsureInitialized()
    if not profile then
        if KT.Print then KT:Print("The profile is not ready yet.") end
        return false
    end

    local currentTheme = state.active
    if targetTheme == currentTheme then return true end

    local registry, order = self:GetAllAdapters()
    local clientFlavor = GetClientFlavor()
    local slotBackup = DeepCopy(state.slots)
    local appliedBackup = DeepCopy(state.applied)
    local rollback = {}

    for _, moduleKey in ipairs(order or {}) do
        local adapter = registry[moduleKey]
        if AdapterAvailable(adapter, clientFlavor) then
            local moduleProfile = AdapterProfile(adapter)
            if moduleProfile then
                local paths = {}
                if type(adapter.getOwnedPaths) == "function" then
                    local ok, result = pcall(adapter.getOwnedPaths, currentTheme, clientFlavor, moduleProfile)
                    if ok and type(result) == "table" then paths = result end
                end

                rollback[#rollback + 1] = {
                    profile = moduleProfile,
                    data = CapturePaths(moduleProfile, paths),
                }
                self:SaveSlot(profile, moduleKey, currentTheme, CapturePaths(moduleProfile, paths))

                local ok, err = pcall(function()
                    local destination = self:LoadSlot(profile, moduleKey, targetTheme)
                    if destination then
                        ApplyPaths(moduleProfile, destination)
                    elseif type(adapter.seed) == "function" then
                        adapter.seed(moduleProfile, targetTheme, clientFlavor)
                    end
                    if type(adapter.validate) == "function" then
                        adapter.validate(moduleProfile, targetTheme, clientFlavor)
                    end
                end)

                if not ok then
                    for index = #rollback, 1, -1 do
                        ApplyPaths(rollback[index].profile, rollback[index].data)
                    end
                    state.slots = slotBackup
                    state.applied = appliedBackup
                    state.requested = currentTheme
                    if KT.Print then
                        KT:Print("Visual theme failed in " .. moduleKey .. ": " .. tostring(err))
                    end
                    return false
                end
                state.applied[moduleKey] = targetTheme
            else
                state.applied[moduleKey] = nil
            end
        else
            state.applied[moduleKey] = nil
        end
    end

    state.requested = targetTheme
    state.active = targetTheme
    state.schemaVersion = self.SCHEMA_VERSION
    self:ResetComboDefaults()

    if type(_G.ReloadUI) == "function" then
        _G.ReloadUI()
    end
    return true
end

function KT.VisualThemes:RequestApply(themeKey)
    if not self:IsKnownTheme(themeKey) then return false end
    if themeKey == self:GetRenderedTheme() then
        self:ResetComboDefaults()
        if KT.Print then KT:Print("Combo points restored to this theme's defaults.") end
        return true
    end

    local catalog = self:GetThemeCatalog()
    local theme = catalog[themeKey]
    StaticPopupDialogs.KT_VISUAL_THEME_CONFIRM = {
        text = "Apply %s and reload the interface?",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function(_, data)
            if data then KT.VisualThemes:ApplyAll(data) end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("KT_VISUAL_THEME_CONFIRM", theme.name, nil, themeKey)
    return true
end
