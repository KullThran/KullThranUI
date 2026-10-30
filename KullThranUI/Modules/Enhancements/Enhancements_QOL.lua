local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then
    return
end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then
    return
end

local C_AddOnProfiler = _G.C_AddOnProfiler
local C_ChallengeMode = _G.C_ChallengeMode
local C_Container = _G.C_Container
local C_Cursor = _G.C_Cursor
local C_EquipmentSet = _G.C_EquipmentSet
local C_Item = _G.C_Item
local C_Spell = _G.C_Spell
local C_Timer = _G.C_Timer
local C_TooltipInfo = _G.C_TooltipInfo
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local GetCVar = _G.GetCVar
local GetInstanceInfo = _G.GetInstanceInfo
local GetInventoryItemDurability = _G.GetInventoryItemDurability
local GetInventoryItemID = _G.GetInventoryItemID
local GetInventoryItemLink = _G.GetInventoryItemLink
local GetInventoryItemQuality = _G.GetInventoryItemQuality
local GetInventoryItemTexture = _G.GetInventoryItemTexture
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsInInstance = _G.IsInInstance
local PlaySound = _G.PlaySound
local RaidNotice_AddMessage = _G.RaidNotice_AddMessage
local ReloadUI = _G.ReloadUI
local SetCVar = _G.SetCVar
local SetLFGRoles = _G.SetLFGRoles
local SOUNDKIT = _G.SOUNDKIT
local StaticPopupDialogs = _G.StaticPopupDialogs
local StaticPopup_Show = _G.StaticPopup_Show
local StaticPopup_Visible = _G.StaticPopup_Visible
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitGUID = _G.UnitGUID
local completeLFGRoleCheck = _G.CompleteLFGRoleCheck
local ipairs = _G.ipairs
local issecretvalue = _G.issecretvalue
local math = _G.math
local pairs = _G.pairs
local strtrim = _G.strtrim
local table = _G.table
local tostring = _G.tostring
local tonumber = _G.tonumber
local type = _G.type

local function LText(text)
    if type(text) ~= "string" then
        return text
    end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then
            return L[text]
        end
    end
    return text
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

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = CopyValue(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

local EXTRA_DEFAULTS = {
    automation = {
        deathReleaseProtection = false,
        durabilityWarning = false,
        durabilityThreshold = 30,
        skipLFGRoleCheck = false,
        lfgRoles = {
            tank = false,
            healer = false,
            damager = false,
        },
    },
    visibility = {
        skipQueueConfirmation = false,
        hideMinimapIcon = false,
    },
    gameOptions = {
        easyItemDestroy = false,
        autoInsertKeystone = false,
        ahCurrentExpansion = false,
    },
    combatRez = {
        enabled = false,
        deathWarning = false,
        point = "CENTER",
        x = 0,
        y = 150,
        iconSize = 40,
    },
    equipmentReminder = {
        enabled = false,
        showOnInstance = true,
        showOnReadyCheck = true,
        autoHideDelay = 10,
        iconSize = 40,
        point = "CENTER",
        x = 0,
        y = 100,
        enchantCheck = false,
        useAllSpecs = true,
        setRules = {},
        specRules = {},
    },
    optimizations = {
        spellQueueWindow = 150,
        savedSettings = {},
        cvarBackups = {},
    },
}

local OPTIMIZATION_SETTINGS = {
    { cvar = "renderScale", optimal = "1", name = LText("Render Scale"), category = "render" },
    { cvar = "VSync", optimal = "0", name = LText("VSync"), category = "render" },
    { cvar = "MSAAQuality", optimal = "0", name = LText("Multisampling"), category = "render" },
    { cvar = "LowLatencyMode", optimal = "3", name = LText("Low Latency Mode"), category = "render" },
    { cvar = "ffxAntiAliasingMode", optimal = "4", name = LText("Anti-Aliasing"), category = "render" },
    { cvar = "graphicsShadowQuality", optimal = "1", name = LText("Shadow Quality"), category = "graphics" },
    { cvar = "graphicsLiquidDetail", optimal = "2", name = LText("Liquid Detail"), category = "graphics" },
    { cvar = "graphicsParticleDensity", optimal = "3", name = LText("Particle Density"), category = "graphics" },
    { cvar = "graphicsSSAO", optimal = "0", name = LText("SSAO"), category = "graphics" },
    { cvar = "graphicsDepthEffects", optimal = "0", name = LText("Depth Effects"), category = "graphics" },
    { cvar = "graphicsComputeEffects", optimal = "0", name = LText("Compute Effects"), category = "graphics" },
    { cvar = "graphicsOutlineMode", optimal = "2", name = LText("Outline Mode"), category = "graphics" },
    { cvar = "graphicsTextureResolution", optimal = "2", name = LText("Texture Resolution"), category = "graphics" },
    { cvar = "graphicsSpellDensity", optimal = "0", name = LText("Spell Density"), category = "graphics" },
    { cvar = "graphicsProjectedTextures", optimal = "1", name = LText("Projected Textures"), category = "graphics" },
    { cvar = "graphicsViewDistance", optimal = "3", name = LText("View Distance"), category = "detail" },
    { cvar = "graphicsEnvironmentDetail", optimal = "3", name = LText("Environment Detail"), category = "detail" },
    { cvar = "graphicsGroundClutter", optimal = "0", name = LText("Ground Clutter"), category = "detail" },
    { cvar = "GxMaxFrameLatency", optimal = "2", name = LText("Triple Buffering"), category = "advanced" },
    { cvar = "TextureFilteringMode", optimal = "5", name = LText("Texture Filtering"), category = "advanced" },
    { cvar = "shadowRt", optimal = "0", name = LText("Ray Traced Shadows"), category = "advanced" },
    { cvar = "ResampleQuality", optimal = "3", name = LText("Resample Quality"), category = "advanced" },
    { cvar = "GxApi", optimal = "D3D12", name = LText("Graphics API"), category = "advanced" },
    { cvar = "physicsLevel", optimal = "1", name = LText("Physics Integration"), category = "advanced" },
    { cvar = "useTargetFPS", optimal = "0", name = LText("Target FPS"), category = "fps" },
    { cvar = "useMaxFPSBk", optimal = "1", name = LText("Background FPS Enabled"), category = "fps" },
    { cvar = "maxFPSBk", optimal = "30", name = LText("Background FPS"), category = "fps" },
    { cvar = "ResampleSharpness", optimal = "0", name = LText("Resample Sharpness"), category = "post" },
    { cvar = "cameraShake", optimal = "0", name = LText("Camera Shake"), category = "post" },
}

local OPTIMIZATION_CATEGORIES = {
    render = { title = LText("Render & Display"), order = 1 },
    graphics = { title = LText("Graphics Quality"), order = 2 },
    detail = { title = LText("View Distance & Detail"), order = 3 },
    advanced = { title = LText("Advanced Settings"), order = 4 },
    fps = { title = LText("FPS Limits"), order = 5 },
    post = { title = LText("Post Processing"), order = 6 },
}

local COMBAT_REZ_SPELL_IDS = { 20484, 61999, 20707, 391054 }
local EQUIPMENT_SLOTS = {
    { id = 13, name = LText("Trinket 1") },
    { id = 14, name = LText("Trinket 2") },
    { id = 16, name = LText("Main Hand") },
    { id = 17, name = LText("Off Hand") },
}
local ENCHANTABLE_SLOTS = {
    { id = 1, name = LText("Head") },
    { id = 2, name = LText("Neck") },
    { id = 3, name = LText("Shoulder") },
    { id = 5, name = LText("Chest") },
    { id = 6, name = LText("Waist") },
    { id = 7, name = LText("Legs") },
    { id = 8, name = LText("Feet") },
    { id = 9, name = LText("Wrist") },
    { id = 10, name = LText("Hands") },
    { id = 11, name = LText("Ring 1") },
    { id = 12, name = LText("Ring 2") },
    { id = 15, name = LText("Back") },
    { id = 16, name = LText("Main Hand") },
    { id = 17, name = LText("Off Hand") },
}

local SLOT_NAMES = {}
for _, slotInfo in ipairs(ENCHANTABLE_SLOTS) do
    SLOT_NAMES[slotInfo.id] = slotInfo.name
end

Mod.OptimizationSettings = OPTIMIZATION_SETTINGS
Mod.OptimizationCategories = OPTIMIZATION_CATEGORIES
Mod.EquipmentReminderEnchantableSlots = ENCHANTABLE_SLOTS

local runtime = {
    hooksInstalled = false,
    keystoneHookInstalled = false,
    lfgDialogHookInstalled = false,
    combatRezFrame = nil,
    inMythicPlus = false,
    encounterActive = false,
    equipmentFrame = nil,
    equipmentButtons = {},
    equipmentStatusRow = nil,
    equipmentAutoHideTimer = nil,
    durabilityFrame = nil,
    durabilityTicker = nil,
    deathReleaseBlocker = nil,
    deathReleaseLabel = nil,
    deathReleaseStart = 0,
    deathReleaseReady = false,
    optimizationMonitorPeak = 0,
    optimizationMonitorStart = GetTime(),
}

local baseGetDefaults = Mod.GetDefaults
function Mod:GetDefaults()
    local defaults = baseGetDefaults and baseGetDefaults(self) or {}
    MergeDefaults(defaults, EXTRA_DEFAULTS)
    return defaults
end

local baseGetDB = Mod.GetDB
function Mod:GetDB()
    local db = baseGetDB and baseGetDB(self) or {}
    MergeDefaults(db, EXTRA_DEFAULTS)

    if not db.automation.lfgRoleCheckMigrated then
        if db.visibility.skipQueueConfirmation == true then
            db.automation.skipLFGRoleCheck = true
            local spec = GetSpecialization and GetSpecialization()
            local role = spec and _G.GetSpecializationRole and _G.GetSpecializationRole(spec)
            if role == "TANK" then
                db.automation.lfgRoles.tank = true
            elseif role == "HEALER" then
                db.automation.lfgRoles.healer = true
            elseif role == "DAMAGER" then
                db.automation.lfgRoles.damager = true
            end
        end
        db.automation.lfgRoleCheckMigrated = true
    end

    return db
end

local function IsSecret(value)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then return true end
    end
    if _G.canaccessvalue then
        local ok, canAccess = pcall(_G.canaccessvalue, value)
        if ok and not canAccess then return true end
    end
    return false
end

local RAID_WARNING_COLOR = { r = 1.0, g = 0.1, b = 0.1 }

local function OptimizationMessage(text)
    if KT and KT.Print then
        KT:Print(text)
    end
end

local function EnsureReloadPopup()
    if StaticPopupDialogs["KT_ENHANCEMENTS_SYSTEM_RELOAD"] then
        return
    end

    StaticPopupDialogs["KT_ENHANCEMENTS_SYSTEM_RELOAD"] = {
        text = LText("Some system changes need a UI reload to fully apply."),
        button1 = LText("Reload UI"),
        button2 = LText("Cancel"),
        OnAccept = function()
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function SaveOptimizationSnapshot(db)
    local optimizations = db.optimizations
    optimizations.savedSettings = optimizations.savedSettings or {}
    if next(optimizations.savedSettings) ~= nil then
        return
    end

    for _, setting in ipairs(OPTIMIZATION_SETTINGS) do
        local ok, current = pcall(GetCVar, setting.cvar)
        if ok and current ~= nil then
            optimizations.savedSettings[setting.cvar] = tostring(current)
        end
    end

    local sqw = GetCVar("SpellQueueWindow")
    if sqw then
        optimizations.savedSettings.SpellQueueWindow = tostring(sqw)
    end
end

function Mod:GetOptimizationCategoryOrder()
    local out = {}
    for key, info in pairs(OPTIMIZATION_CATEGORIES) do
        out[#out + 1] = { key = key, order = info.order, title = info.title }
    end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end

function Mod:GetOptimizationSettingsForCategory(category)
    local out = {}
    for _, setting in ipairs(OPTIMIZATION_SETTINGS) do
        if setting.category == category then
            out[#out + 1] = setting
        end
    end
    return out
end

function Mod:HasOptimizationSnapshot()
    local db = self:GetDB()
    return db.optimizations and db.optimizations.savedSettings and next(db.optimizations.savedSettings) ~= nil
end

function Mod:HasOptimizationBackup(cvar)
    local db = self:GetDB()
    return db.optimizations and db.optimizations.cvarBackups and db.optimizations.cvarBackups[cvar] ~= nil
end

function Mod:GetOptimizationStatus(setting)
    local ok, current = pcall(GetCVar, setting.cvar)
    if not ok or current == nil or current == "" then
        current = "0"
    end

    local optimal = tostring(setting.optimal)
    local currentNum = tonumber(current)
    local optimalNum = tonumber(optimal)
    local currentDisplay = tostring(current)
    local optimalDisplay = optimal

    if setting.cvar == "graphicsViewDistance" or setting.cvar == "graphicsEnvironmentDetail" or setting.cvar == "graphicsGroundClutter" then
        currentDisplay = string.format(LText("Level %d"), (currentNum or 0) + 1)
        optimalDisplay = string.format(LText("Level %d"), (optimalNum or 0) + 1)
    elseif setting.cvar == "renderScale" then
        currentDisplay = string.format("%d%%", math.floor((currentNum or 1) * 100))
        optimalDisplay = string.format("%d%%", math.floor((optimalNum or 1) * 100))
    elseif setting.cvar == "VSync" or setting.cvar == "graphicsProjectedTextures" or setting.cvar == "useTargetFPS" or setting.cvar == "useMaxFPSBk" then
        currentDisplay = (current == "1" or current == "true") and LText("Enabled") or LText("Disabled")
        optimalDisplay = (optimal == "1" or optimal == "true") and LText("Enabled") or LText("Disabled")
    elseif setting.cvar == "maxFPSBk" then
        currentDisplay = tostring(current) .. " FPS"
        optimalDisplay = tostring(optimal) .. " FPS"
    elseif setting.cvar == "GxApi" then
        local apiMap = {
            D3D11 = "DX11",
            D3D12 = "DX12",
            OPENGL = "OpenGL",
        }
        currentDisplay = apiMap[string.upper(tostring(current))] or tostring(current)
        optimalDisplay = apiMap[string.upper(tostring(optimal))] or tostring(optimal)
    end

    local isOptimal
    if currentNum and optimalNum then
        isOptimal = currentNum == optimalNum
    else
        isOptimal = tostring(current) == tostring(optimal)
    end

    return currentDisplay, isOptimal, optimalDisplay
end

function Mod:ApplyOptimizationCVar(cvar, value)
    local db = self:GetDB()
    db.optimizations.cvarBackups = db.optimizations.cvarBackups or {}

    local ok, current = pcall(GetCVar, cvar)
    if ok and current ~= nil then
        db.optimizations.cvarBackups[cvar] = tostring(current)
    end

    local success = pcall(SetCVar, cvar, tostring(value))
    if success then
        OptimizationMessage(string.format(LText("%s set to %s."), cvar, tostring(value)))
    else
        OptimizationMessage(string.format(LText("Could not set %s."), cvar))
    end
    return success
end

function Mod:RevertOptimizationCVar(cvar)
    local db = self:GetDB()
    local savedValue = db.optimizations and db.optimizations.cvarBackups and db.optimizations.cvarBackups[cvar]
    if savedValue == nil then
        return false
    end

    local success = pcall(SetCVar, cvar, tostring(savedValue))
    if success then
        db.optimizations.cvarBackups[cvar] = nil
        OptimizationMessage(string.format(LText("%s restored to %s."), cvar, tostring(savedValue)))
    end
    return success
end

function Mod:ApplyOptimalFPSSettings()
    local db = self:GetDB()
    SaveOptimizationSnapshot(db)

    local applied = 0
    for _, setting in ipairs(OPTIMIZATION_SETTINGS) do
        if pcall(SetCVar, setting.cvar, setting.optimal) then
            applied = applied + 1
        end
    end

    OptimizationMessage(string.format(LText("Applied %d recommended system settings."), applied))
    EnsureReloadPopup()
    StaticPopup_Show("KT_ENHANCEMENTS_SYSTEM_RELOAD")
end

function Mod:RestoreOptimalFPSSettings()
    local db = self:GetDB()
    local saved = db.optimizations and db.optimizations.savedSettings
    if not saved or next(saved) == nil then
        return false
    end

    local restored = 0
    for cvar, value in pairs(saved) do
        if pcall(SetCVar, cvar, value) then
            restored = restored + 1
        end
    end

    db.optimizations.savedSettings = {}
    OptimizationMessage(string.format(LText("Restored %d saved system settings."), restored))
    EnsureReloadPopup()
    StaticPopup_Show("KT_ENHANCEMENTS_SYSTEM_RELOAD")
    return true
end

function Mod:SetSpellQueueWindow(value)
    local db = self:GetDB()
    local queueValue = math.max(50, math.min(500, tonumber(value) or 150))
    db.optimizations.spellQueueWindow = queueValue
    SetCVar("SpellQueueWindow", queueValue)
end

function Mod:IsAddonProfilerEnabled()
    return GetCVar("scriptProfile") == "1"
end

function Mod:SetAddonProfilerEnabled(enabled)
    local desired = enabled and "1" or "0"
    if GetCVar("scriptProfile") == desired then
        return false
    end

    local success = pcall(SetCVar, "scriptProfile", desired)
    if not success then
        OptimizationMessage(LText("Could not change AddOn profiling."))
        return false
    end

    EnsureReloadPopup()
    StaticPopup_Show("KT_ENHANCEMENTS_SYSTEM_RELOAD")
    if enabled then
        OptimizationMessage(LText("Addon profiling has been enabled. Reload the UI to start collecting metrics."))
    else
        OptimizationMessage(LText("Addon profiling has been disabled. Reload the UI to stop collecting metrics."))
    end
    return true
end

function Mod:ToggleAddonProfiler()
    return self:SetAddonProfilerEnabled(not self:IsAddonProfilerEnabled())
end

function Mod:EnableAddonProfiler()
    return self:SetAddonProfilerEnabled(true)
end

function Mod:GetOptimizationMonitorSnapshot()
    if not self:IsAddonProfilerEnabled() then
        return { disabled = true }
    end
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric) then
        return { unavailable = true }
    end

    if (GetTime() - runtime.optimizationMonitorStart) < 3 then
        return { warming = true }
    end

    local recentAvg = C_AddOnProfiler.GetAddOnMetric(addonName, 1) or 0
    local encounterAvg = C_AddOnProfiler.GetAddOnMetric(addonName, 2) or 0
    local lastTick = C_AddOnProfiler.GetAddOnMetric(addonName, 3) or 0

    if lastTick > runtime.optimizationMonitorPeak then
        runtime.optimizationMonitorPeak = lastTick
    end

    return {
        recentAvg = recentAvg,
        encounterAvg = encounterAvg,
        lastTick = lastTick,
        peak = runtime.optimizationMonitorPeak,
    }
end

local function EnsureCombatRezFrame()
    if runtime.combatRezFrame then
        return runtime.combatRezFrame
    end

    local frame = CreateFrame("Frame", "KT_EnhancementsCombatRez", _G.UIParent, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    KT:AddBackdrop(frame, 0.05, 0.07, 0.09, 0.86)
    KT:AddBorder(frame, KT.C_R, KT.C_G, KT.C_B, 0.9)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.Icon = icon

    local timerText = frame:CreateFontString(nil, "OVERLAY")
    timerText:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    timerText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    timerText:SetTextColor(1, 1, 1, 1)
    frame.TimerText = timerText

    local countText = frame:CreateFontString(nil, "OVERLAY")
    countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    countText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    countText:SetTextColor(1, 1, 1, 1)
    frame.CountText = countText

    runtime.combatRezFrame = frame
    return frame
end

function Mod:RegisterCombatRezMover()
    if self.combatRezMoverRegistered or not (KT and KT.RegisterMovableElements) then
        return
    end

    KT:RegisterMovableElements({
        {
            key = "ENH_COMBAT_REZ",
            label = LText("Combat Res"),
            group = "Enhancements",
            getFrame = function()
                return EnsureCombatRezFrame()
            end,
            getSize = function()
                local combatRez = Mod:GetDB().combatRez
                local size = tonumber(combatRez.iconSize) or 40
                return size, size
            end,
            isHidden = function()
                local db = Mod:GetDB()
                return not (db and db.combatRez and db.combatRez.enabled)
            end,
            loadPosition = function()
                local combatRez = Mod:GetDB().combatRez
                return {
                    point = combatRez.point or "CENTER",
                    relativePoint = combatRez.relativePoint or combatRez.point or "CENTER",
                    x = combatRez.x or 0,
                    y = combatRez.y or 150,
                }
            end,
            savePosition = function(_, point, relativePoint, x, y)
                local combatRez = Mod:GetDB().combatRez
                combatRez.point = point or "CENTER"
                combatRez.relativePoint = relativePoint or point or "CENTER"
                combatRez.x = x or 0
                combatRez.y = y or 150
            end,
            applyPosition = function()
                Mod:RefreshCombatRezDisplay()
            end,
            applyPendingPosition = function(_, position)
                position = position or {}
                local frame = EnsureCombatRezFrame()
                frame:ClearAllPoints()
                frame:SetPoint(
                    position.point or "CENTER",
                    _G.UIParent,
                    position.relativePoint or position.point or "CENTER",
                    position.x or 0,
                    position.y or 150
                )
            end,
        },
    })
    self.combatRezMoverRegistered = true
end

local function GetCombatRezCharges()
    for _, spellID in ipairs(COMBAT_REZ_SPELL_IDS) do
        local charges = C_Spell and C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID)
        if charges then
            return charges, spellID
        end
    end
    return nil, nil
end

local function ShouldShowCombatRez()
    local db = Mod:GetDB()
    if not (db and db.combatRez and db.combatRez.enabled) then
        return false
    end
    return runtime.inMythicPlus or runtime.encounterActive
end

function Mod:RefreshCombatRezDisplay()
    local db = self:GetDB()
    local frame = EnsureCombatRezFrame()
    local size = db.combatRez.iconSize or 40

    frame:ClearAllPoints()
    frame:SetPoint(db.combatRez.point or "CENTER", _G.UIParent, db.combatRez.relativePoint or db.combatRez.point or "CENTER", db.combatRez.x or 0, db.combatRez.y or 150)
    frame:SetSize(size, size)

    if not ShouldShowCombatRez() then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        return
    end

    local function update()
        local charges, activeSpellID = GetCombatRezCharges()
        if not charges then
            frame.Icon:SetTexture("Interface\\Icons\\Spell_Nature_Reincarnation")
            frame.TimerText:SetText("")
            frame.CountText:SetText("0")
            return
        end

        frame.Icon:SetTexture((C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(activeSpellID)) or "Interface\\Icons\\Spell_Nature_Reincarnation")

        local currentCharges = charges.currentCharges or 0
        local maxCharges = charges.maxCharges or currentCharges
        local cooldownDuration = charges.cooldownDuration or 0
        local cooldownStart = charges.cooldownStartTime or 0

        frame.CountText:SetText(tostring(currentCharges))

        if not IsSecret(currentCharges) and not IsSecret(maxCharges) and currentCharges < maxCharges and not IsSecret(cooldownDuration) and not IsSecret(cooldownStart) then
            local remaining = cooldownDuration - (GetTime() - cooldownStart)
            if remaining > 0 then
                local minutes = math.floor(remaining / 60)
                local seconds = math.floor(remaining % 60)
                frame.TimerText:SetText(string.format("%d:%02d", minutes, seconds))
            else
                frame.TimerText:SetText("")
            end
        else
            frame.TimerText:SetText("")
        end

        if frame.Icon.SetDesaturated then
            frame.Icon:SetDesaturated(currentCharges == 0)
        end
    end

    frame:Show()
    update()
    frame:SetScript("OnUpdate", function(_, elapsed)
        frame._elapsed = (frame._elapsed or 0) + elapsed
        if frame._elapsed < 0.1 then
            return
        end
        frame._elapsed = 0
        update()
    end)
end

local function GuidBelongsToGroup(guid)
    if not guid then
        return false
    end

    if UnitGUID("player") == guid then
        return true
    end

    for i = 1, 4 do
        if UnitGUID("party" .. i) == guid then
            return true
        end
    end

    for i = 1, 40 do
        if UnitGUID("raid" .. i) == guid then
            return true
        end
    end

    return false
end

local function HandleCombatRezDeathWarning(destGUID)
    local db = Mod:GetDB()
    if not (db.combatRez.enabled and db.combatRez.deathWarning) then
        return
    end
    if IsSecret(destGUID) or not destGUID then
        return
    end
    if not GuidBelongsToGroup(destGUID) then
        return
    end

    -- Do not pass unit-derived values to Blizzard's RaidWarningFrame. Retail can
    -- mark those strings as secret/tainted and Blizzard later performs arithmetic
    -- on the resulting FontString layout values.
    local msg = "A group member died"

    PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    if RaidNotice_AddMessage and _G.RaidWarningFrame then
        pcall(RaidNotice_AddMessage, _G.RaidWarningFrame, msg, RAID_WARNING_COLOR)
    end
end

local function ParseEnchantName(text)
    if not text then
        return nil
    end

    local cleaned = text:match("Enchanted: (.+)") or text
    cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A.-|a", "")
    cleaned = strtrim(cleaned)
    return cleaned ~= "" and cleaned or nil
end

local function GetPermanentEnchantText(slotID)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then
        return nil, nil
    end

    local tooltipData = C_TooltipInfo.GetInventoryItem("player", slotID)
    if IsSecret(tooltipData) or type(tooltipData) ~= "table" then
        return nil, nil
    end

    local lines = tooltipData.lines
    if IsSecret(lines) or type(lines) ~= "table" then return nil, nil end
    for _, line in ipairs(lines) do
        if not IsSecret(line) and type(line) == "table" and not IsSecret(line.type) and line.type == 15 then
            local leftText = line.leftText
            local enchantID = line.enchantID
            if IsSecret(leftText) then leftText = nil end
            if IsSecret(enchantID) then enchantID = nil end
            return leftText, enchantID
        end
    end

    return nil, nil
end

local function GetEquipmentReminderRuleKey(db)
    local equipmentReminder = db and db.equipmentReminder
    if not equipmentReminder then
        return nil
    end

    if equipmentReminder.useAllSpecs then
        return 0
    end

    local specIndex = GetSpecialization()
    return specIndex and GetSpecializationInfo(specIndex) or nil
end

local function NormalizeEquipmentSetID(setID)
    setID = tonumber(setID)
    if setID and setID > 0 then
        return setID
    end
    return 0
end

local function GetEquipmentSetData(setID)
    setID = NormalizeEquipmentSetID(setID)
    if setID == 0 or not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo and C_EquipmentSet.GetItemIDs) then
        return nil, nil, nil
    end

    local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
    local itemIDs = C_EquipmentSet.GetItemIDs(setID)
    if not name or not itemIDs then
        return nil, nil, nil
    end

    return setID, name, itemIDs
end

function Mod:GetEquipmentReminderSetChoices()
    local choices = {
        [0] = LText("Current Equipped Gear"),
    }

    if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetEquipmentSetInfo) then
        return choices
    end

    local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
    if IsSecret(setIDs) or type(setIDs) ~= "table" then return choices end
    for _, setID in ipairs(setIDs) do
        local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
        if name and name ~= "" then
            choices[setID] = name
        end
    end

    return choices
end

function Mod:GetSelectedEquipmentReminderSetID()
    local db = self:GetDB()
    db.equipmentReminder.setRules = db.equipmentReminder.setRules or {}

    local ruleKey = GetEquipmentReminderRuleKey(db)
    if ruleKey == nil then
        return 0
    end

    local setID = NormalizeEquipmentSetID(db.equipmentReminder.setRules[ruleKey])
    if setID > 0 then
        local validSetID = GetEquipmentSetData(setID)
        if not validSetID then
            db.equipmentReminder.setRules[ruleKey] = 0
            setID = 0
        end
    end

    return setID
end

function Mod:SetSelectedEquipmentReminderSetID(setID)
    local db = self:GetDB()
    db.equipmentReminder.setRules = db.equipmentReminder.setRules or {}

    local ruleKey = GetEquipmentReminderRuleKey(db)
    if ruleKey == nil then
        return
    end

    db.equipmentReminder.setRules[ruleKey] = NormalizeEquipmentSetID(setID)
    if runtime.equipmentFrame and runtime.equipmentFrame:IsShown() then
        self:RefreshEquipmentReminderFrame()
    end
end

function Mod:GetEquipmentReminderGearMismatches()
    local setID, setName, itemIDs = GetEquipmentSetData(self:GetSelectedEquipmentReminderSetID())
    if not setID then
        return {}, nil, nil
    end

    local mismatches = {}
    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local expectedItemID = tonumber(itemIDs[slotInfo.id])
        local equippedItemID = GetInventoryItemID("player", slotInfo.id)

        if expectedItemID and expectedItemID > 0 then
            if equippedItemID ~= expectedItemID then
                mismatches[#mismatches + 1] = {
                    slotID = slotInfo.id,
                    slotName = slotInfo.name,
                    issue = equippedItemID and "wrong" or "missing",
                    expectedItemID = expectedItemID,
                    equippedItemID = equippedItemID,
                }
            end
        elseif equippedItemID then
            mismatches[#mismatches + 1] = {
                slotID = slotInfo.id,
                slotName = slotInfo.name,
                issue = "unexpected",
                equippedItemID = equippedItemID,
            }
        end
    end

    return mismatches, setName, itemIDs
end

function Mod:CaptureEquipmentReminderEnchants()
    local db = self:GetDB()
    db.equipmentReminder.specRules = db.equipmentReminder.specRules or {}

    local ruleKey = GetEquipmentReminderRuleKey(db)
    if not ruleKey then
        return 0
    end

    db.equipmentReminder.specRules[ruleKey] = db.equipmentReminder.specRules[ruleKey] or {}
    local rules = db.equipmentReminder.specRules[ruleKey]
    local captured = 0

    for _, slotInfo in ipairs(ENCHANTABLE_SLOTS) do
        local enchantText, enchantID = GetPermanentEnchantText(slotInfo.id)
        local parsedName = ParseEnchantName(enchantText)
        if enchantID and enchantID > 0 and parsedName then
            rules[slotInfo.id] = { id = enchantID, name = parsedName }
            captured = captured + 1
        end
    end

    if runtime.equipmentFrame and runtime.equipmentFrame:IsShown() then
        self:RefreshEquipmentReminderFrame()
    end

    return captured
end

function Mod:ClearEquipmentReminderEnchants()
    local db = self:GetDB()
    db.equipmentReminder.specRules = {}
    if runtime.equipmentFrame and runtime.equipmentFrame:IsShown() then
        self:RefreshEquipmentReminderFrame()
    end
end

function Mod:GetEquipmentReminderMismatches()
    local db = self:GetDB()
    if not (db.equipmentReminder and db.equipmentReminder.enchantCheck) then
        return {}
    end

    local ruleKey = GetEquipmentReminderRuleKey(db)
    local rules = ruleKey and db.equipmentReminder.specRules and db.equipmentReminder.specRules[ruleKey]
    if not rules then
        return {}
    end

    local mismatches = {}
    for slotID, expectedData in pairs(rules) do
        local numericSlotID = tonumber(slotID)
        local expectedName = expectedData and expectedData.name
        if numericSlotID and expectedName and GetInventoryItemID("player", numericSlotID) then
            local enchantText = GetPermanentEnchantText(numericSlotID)
            local equippedName = ParseEnchantName(enchantText)
            if not equippedName then
                mismatches[#mismatches + 1] = {
                    slotName = SLOT_NAMES[numericSlotID] or ("Slot " .. tostring(numericSlotID)),
                    issue = "missing",
                    expectedName = expectedName,
                }
            elseif equippedName ~= expectedName then
                mismatches[#mismatches + 1] = {
                    slotName = SLOT_NAMES[numericSlotID] or ("Slot " .. tostring(numericSlotID)),
                    issue = "wrong",
                    expectedName = expectedName,
                    equippedName = equippedName,
                }
            end
        end
    end

    return mismatches
end

local function BuildEquipmentReminderStatusText(db)
    local parts = {}
    local hasIssues = false

    local gearMismatches, setName = Mod:GetEquipmentReminderGearMismatches()
    if setName then
        if #gearMismatches == 0 then
            parts[#parts + 1] = string.format(LText("Set ready: %s"), setName)
        else
            parts[#parts + 1] = string.format(LText("%d Gear Issues"), #gearMismatches)
            hasIssues = true
        end
    end

    if db.equipmentReminder.enchantCheck then
        local enchantMismatches = Mod:GetEquipmentReminderMismatches()
        if #enchantMismatches == 0 then
            parts[#parts + 1] = LText("Enchants OK")
        else
            parts[#parts + 1] = string.format(LText("%d Enchant Issues"), #enchantMismatches)
            hasIssues = true
        end
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, " | "), hasIssues
end

local function CreateEquipmentButton(parent, slotInfo)
    local button = CreateFrame("Button", nil, parent)
    button.slotID = slotInfo.id
    button.slotName = slotInfo.name

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = CreateFrame("Frame", nil, button)
    border:SetAllPoints()
    KT:AddBorder(border, 0.12, 0.12, 0.12, 0.85)
    button.Border = border

    button:SetScript("OnEnter", function(self)
        _G.GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if self.expectedItemID then
            _G.GameTooltip:SetItemByID(self.expectedItemID)
            if self.targetSetName then
                _G.GameTooltip:AddLine(" ")
                _G.GameTooltip:AddLine(string.format(LText("Target set: %s"), self.targetSetName), 1, 0.82, 0, true)
            end
            if self.expectedEmpty then
                _G.GameTooltip:AddLine(LText("Target set leaves this slot empty"), 1, 0.4, 0.4, true)
            elseif self.currentItemID == self.expectedItemID then
                _G.GameTooltip:AddLine(LText("Currently equipped"), 0.3, 0.85, 0.3, true)
            elseif self.currentItemID then
                _G.GameTooltip:AddLine(LText("Currently equipped item differs"), 1, 0.4, 0.4, true)
            else
                _G.GameTooltip:AddLine(LText("Empty"), 1, 0.4, 0.4, true)
            end
        elseif self.expectedEmpty then
            _G.GameTooltip:SetText(LText(self.slotName))
            if self.targetSetName then
                _G.GameTooltip:AddLine(string.format(LText("Target set: %s"), self.targetSetName), 1, 0.82, 0, true)
            end
            _G.GameTooltip:AddLine(LText("Target set leaves this slot empty"), 1, 0.4, 0.4, true)
        elseif GetInventoryItemID("player", self.slotID) then
            _G.GameTooltip:SetInventoryItem("player", self.slotID)
        else
            _G.GameTooltip:SetText(LText(self.slotName) .. " - " .. LText("Empty"))
        end
        _G.GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        _G.GameTooltip:Hide()
    end)

    return button
end

local function EnsureEquipmentFrame()
    if runtime.equipmentFrame then
        return runtime.equipmentFrame
    end

    local db = Mod:GetDB()
    local frame = CreateFrame("Frame", "KT_EnhancementsEquipmentReminder", _G.UIParent, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    KT:AddBackdrop(frame, 0.05, 0.07, 0.09, 0.92)
    if KT.AddAccentBorder then
        KT:AddAccentBorder(frame, 0.9)
    else
        KT:AddBorder(frame, KT.C_R, KT.C_G, KT.C_B, 0.9)
    end

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.equipmentReminder.point = point or "CENTER"
        db.equipmentReminder.x = x or 0
        db.equipmentReminder.y = y or 100
    end)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText(LText("Equipment Reminder"))
    title:SetTextColor(1, 0.82, 0, 1)
    frame.Title = title

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeButton:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    closeButton:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
        if runtime.equipmentAutoHideTimer then
            runtime.equipmentAutoHideTimer:Cancel()
            runtime.equipmentAutoHideTimer = nil
        end
    end)

    local buttonContainer = CreateFrame("Frame", nil, frame)
    buttonContainer:SetPoint("TOP", title, "BOTTOM", 0, -10)
    frame.ButtonContainer = buttonContainer

    for index, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local button = CreateEquipmentButton(buttonContainer, slotInfo)
        runtime.equipmentButtons[index] = button
    end

    local statusRow = CreateFrame("Frame", nil, frame)
    statusRow:SetPoint("TOP", buttonContainer, "BOTTOM", 0, -8)
    statusRow:SetHeight(20)
    statusRow.Text = statusRow:CreateFontString(nil, "OVERLAY")
    statusRow.Text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    statusRow.Text:SetPoint("CENTER")
    frame.StatusRow = statusRow
    runtime.equipmentStatusRow = statusRow
    runtime.equipmentFrame = frame
    return frame
end

function Mod:RefreshEquipmentReminderFrame()
    local db = self:GetDB()
    local frame = EnsureEquipmentFrame()
    if KT.AddAccentBorder then
        KT:AddAccentBorder(frame, 0.9)
    end
    local size = db.equipmentReminder.iconSize or 40
    local spacing = 6
    local totalWidth = (#EQUIPMENT_SLOTS * size) + ((#EQUIPMENT_SLOTS - 1) * spacing)
    local startX = (-totalWidth / 2) + (size / 2)
    local gearMismatches, selectedSetName, selectedSetItems = self:GetEquipmentReminderGearMismatches()
    local mismatchBySlot = {}

    for _, mismatch in ipairs(gearMismatches) do
        mismatchBySlot[mismatch.slotID] = mismatch
    end

    frame:ClearAllPoints()
    frame:SetPoint(db.equipmentReminder.point or "CENTER", _G.UIParent, db.equipmentReminder.point or "CENTER", db.equipmentReminder.x or 0, db.equipmentReminder.y or 100)
    frame:SetWidth(math.max(230, totalWidth + 24))
    frame.ButtonContainer:SetSize(totalWidth, size)

    for index, button in ipairs(runtime.equipmentButtons) do
        local expectedItemID = selectedSetItems and tonumber(selectedSetItems[button.slotID]) or nil
        local currentItemID = GetInventoryItemID("player", button.slotID)
        local mismatch = mismatchBySlot[button.slotID]
        local displayTexture = nil

        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("CENTER", frame.ButtonContainer, "CENTER", startX + ((index - 1) * (size + spacing)), 0)
        button.currentItemID = currentItemID
        button.expectedItemID = expectedItemID
        button.expectedEmpty = selectedSetItems and not expectedItemID or nil
        button.targetSetName = selectedSetName

        if expectedItemID and C_Item and C_Item.GetItemIconByID then
            displayTexture = C_Item.GetItemIconByID(expectedItemID)
        end
        if not displayTexture then
            displayTexture = GetInventoryItemTexture("player", button.slotID) or 0
        end

        button.Icon:SetTexture(displayTexture)
        button.Icon:SetDesaturated(mismatch and true or false)

        if selectedSetItems then
            if mismatch then
                KT:AddBorder(button.Border, 1, 0.25, 0.25, 0.95)
            else
                KT:AddBorder(button.Border, 0.28, 0.9, 0.42, 0.95)
            end
        else
            KT:AddBorder(button.Border, 0.12, 0.12, 0.12, 0.85)
        end
    end

    local statusText, hasIssues = BuildEquipmentReminderStatusText(db)
    if statusText then
        runtime.equipmentStatusRow.Text:SetText(statusText)
        if hasIssues then
            runtime.equipmentStatusRow.Text:SetTextColor(1, 0.4, 0.4, 1)
        else
            runtime.equipmentStatusRow.Text:SetTextColor(0.3, 0.85, 0.3, 1)
        end
        runtime.equipmentStatusRow:Show()
        frame:SetHeight(size + 70)
    else
        runtime.equipmentStatusRow:Hide()
        frame:SetHeight(size + 48)
    end
end

function Mod:ShowEquipmentReminder()
    local db = self:GetDB()
    if not db.equipmentReminder.enabled or InCombatLockdown() then
        return
    end

    self:RefreshEquipmentReminderFrame()
    local frame = EnsureEquipmentFrame()
    frame:Show()

    if runtime.equipmentAutoHideTimer then
        runtime.equipmentAutoHideTimer:Cancel()
        runtime.equipmentAutoHideTimer = nil
    end

    local delay = tonumber(db.equipmentReminder.autoHideDelay) or 10
    if delay > 0 and C_Timer and C_Timer.NewTimer then
        runtime.equipmentAutoHideTimer = C_Timer.NewTimer(delay, function()
            if runtime.equipmentFrame then
                runtime.equipmentFrame:Hide()
            end
            runtime.equipmentAutoHideTimer = nil
        end)
    end
end

function Mod:HideEquipmentReminder()
    if runtime.equipmentFrame then
        runtime.equipmentFrame:Hide()
    end
    if runtime.equipmentAutoHideTimer then
        runtime.equipmentAutoHideTimer:Cancel()
        runtime.equipmentAutoHideTimer = nil
    end
end

local function EnsureDurabilityFrame()
    if runtime.durabilityFrame then
        return runtime.durabilityFrame
    end

    local frame = CreateFrame("Frame", "KT_EnhancementsDurabilityWarning", _G.UIParent)
    frame:SetSize(420, 42)
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 250)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    text:SetPoint("CENTER")
    frame.Text = text

    runtime.durabilityFrame = frame
    return frame
end

local function GetLowestDurability()
    local lowest
    for slotID = 1, 19 do
        local current, maximum = GetInventoryItemDurability(slotID)
        if current and maximum and maximum > 0 then
            local percent = (current / maximum) * 100
            if not lowest or percent < lowest then
                lowest = percent
            end
        end
    end
    return lowest
end

local function HideDurabilityWarning()
    if runtime.durabilityFrame then
        runtime.durabilityFrame:Hide()
    end
end

local function ShowDurabilityWarning(percent, threshold)
    local frame = EnsureDurabilityFrame()
    local red, green, blue = 1, 0.35, 0.35
    if percent > math.max(15, threshold - 5) then
        red, green, blue = 1, 0.82, 0
    end
    frame.Text:SetText(string.format(LText("Durability low: %d%%"), math.floor(percent)))
    frame.Text:SetTextColor(red, green, blue, 1)
    frame:Show()
end

function Mod:UpdateDurabilityWarning()
    local db = self:GetDB()
    if not (db.automation.durabilityWarning and not UnitAffectingCombat("player")) then
        HideDurabilityWarning()
        return
    end

    local threshold = tonumber(db.automation.durabilityThreshold) or 30
    local lowest = GetLowestDurability()
    if not lowest or lowest >= threshold then
        HideDurabilityWarning()
        return
    end

    ShowDurabilityWarning(lowest, threshold)
end

function Mod:RefreshDurabilityTicker()
    if runtime.durabilityTicker then
        runtime.durabilityTicker:Cancel()
        runtime.durabilityTicker = nil
    end

    local db = self:GetDB()
    if not db.automation.durabilityWarning then
        HideDurabilityWarning()
        return
    end

    -- Durability changes already have dedicated game events. Polling every
    -- three seconds did unnecessary inventory API work everywhere, including
    -- the open world, and could present as a regular micro-stutter.
    self:UpdateDurabilityWarning()
end

local function EnsureDeathReleaseBlocker(button)
    if runtime.deathReleaseBlocker then
        runtime.deathReleaseBlocker:SetParent(button)
        runtime.deathReleaseBlocker:SetAllPoints()
        return runtime.deathReleaseBlocker
    end

    local blocker = CreateFrame("Button", nil, button)
    blocker:SetAllPoints()
    blocker:SetFrameStrata("DIALOG")
    blocker:EnableMouse(true)
    blocker:RegisterForClicks("AnyUp", "AnyDown")

    local bg = blocker:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.85)

    local label = blocker:CreateFontString(nil, "OVERLAY")
    label:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetTextColor(1, 0.65, 0, 1)

    blocker:SetScript("OnClick", function() end)
    runtime.deathReleaseBlocker = blocker
    runtime.deathReleaseLabel = label
    return blocker
end

local function ClearDeathReleaseState()
    runtime.deathReleaseStart = 0
    runtime.deathReleaseReady = false
    if runtime.deathReleaseBlocker then
        runtime.deathReleaseBlocker:SetScript("OnUpdate", nil)
        runtime.deathReleaseBlocker:Hide()
    end
end

function Mod:ActivateDeathReleaseProtection()
    local db = self:GetDB()
    if not db.automation.deathReleaseProtection then
        return
    end

    local _, instanceType = GetInstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then
        return
    end

    local dialogName = StaticPopup_Visible("DEATH")
    local popup = dialogName and _G[dialogName]
    if not popup then
        return
    end

    local button = popup.GetButton and popup:GetButton(1)
    if not button then
        return
    end

    local blocker = EnsureDeathReleaseBlocker(button)
    ClearDeathReleaseState()
    runtime.deathReleaseLabel:SetText(string.format(LText("Hold Alt %.1f"), 1.0))
    blocker:Show()
    blocker:SetScript("OnUpdate", function()
        if runtime.deathReleaseReady then
            blocker:Hide()
            return
        end

        if IsAltKeyDown() then
            if runtime.deathReleaseStart == 0 then
                runtime.deathReleaseStart = GetTime()
            end

            local remaining = 1.0 - (GetTime() - runtime.deathReleaseStart)
            if remaining <= 0 then
                runtime.deathReleaseReady = true
                blocker:Hide()
            else
                runtime.deathReleaseLabel:SetText(string.format(LText("Hold Alt %.1f"), remaining))
            end
        else
            runtime.deathReleaseStart = 0
            runtime.deathReleaseLabel:SetText(string.format(LText("Hold Alt %.1f"), 1.0))
        end
    end)
end

function Mod:ApplyHideMinimapIcon()
    local db = self:GetDB()
    local hide = db.visibility.hideMinimapIcon
    local bag = _G.KT_MinimapButtonBag
    local toggle = _G.KT_MinimapButtonBagToggle
    local minimapButtonModule = KT.GetModule and KT:GetModule("MinimapButton", true)

    if hide then
        if bag then
            bag:Hide()
        end
        if toggle then
            toggle:Hide()
        end
        return
    end

    if minimapButtonModule and minimapButtonModule.Refresh then
        minimapButtonModule:Refresh()
    end
end

local function HandleEasyItemDestroy()
    local db = Mod:GetDB()
    if not db.gameOptions.easyItemDestroy then
        return
    end

    for index = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() then
            local editBox = _G["StaticPopup" .. index .. "EditBox"]
            local button = _G["StaticPopup" .. index .. "Button1"]
            if editBox and editBox:IsShown() then
                editBox:Hide()
            end
            if button then
                button:Enable()
            end
            return
        end
    end
end

local function TrySlotKeystone()
    local reagentType = Enum and Enum.ItemClass and Enum.ItemClass.Reagent
    local keystoneType = Enum and Enum.ItemReagentSubclass and Enum.ItemReagentSubclass.Keystone
    if not (reagentType and keystoneType and C_ChallengeMode and C_ChallengeMode.SlotKeystone and C_Container) then
        return
    end

    for bag = 0, (NUM_BAG_FRAMES or 4) do
        local slots = C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID = C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local _, _, _, _, _, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
                if classID == reagentType and subclassID == keystoneType then
                    C_Container.PickupContainerItem(bag, slot)
                    if not C_Cursor or not C_Cursor.GetCursorItem or C_Cursor.GetCursorItem() then
                        C_ChallengeMode.SlotKeystone()
                        return
                    end
                end
            end
        end
    end
end

local function EnsureKeystoneHook()
    if runtime.keystoneHookInstalled or not _G.ChallengesKeystoneFrame then
        return
    end
    runtime.keystoneHookInstalled = true
    _G.ChallengesKeystoneFrame:HookScript("OnShow", function()
        local db = Mod:GetDB()
        if not db.gameOptions.autoInsertKeystone then
            return
        end
        if C_ChallengeMode and C_ChallengeMode.HasSlottedKeystone and C_ChallengeMode.HasSlottedKeystone() then
            return
        end
        TrySlotKeystone()
    end)
end

local function ApplyAuctionHouseCurrentExpansion()
    local db = Mod:GetDB()
    if not db.gameOptions.ahCurrentExpansion then
        return
    end

    C_Timer.After(0, function()
        if _G.AuctionHouseFrame and _G.AuctionHouseFrame.SearchBar then
            local filterButton = _G.AuctionHouseFrame.SearchBar.FilterButton
            if filterButton and filterButton.filters and Enum and Enum.AuctionHouseFilter then
                filterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
                if _G.AuctionHouseFrame.SearchBar.UpdateClearFiltersButton then
                    _G.AuctionHouseFrame.SearchBar:UpdateClearFiltersButton()
                end
            end
        end
    end)
end

local function HandleSkipQueueRoleCheck()
    local db = Mod:GetDB()
    if not IsModuleEnabled or not IsModuleEnabled() or not (db.automation and db.automation.skipLFGRoleCheck) or IsControlKeyDown() then
        return
    end

    local roles = db.automation.lfgRoles or {}
    local tank = roles.tank == true
    local healer = roles.healer == true
    local damager = roles.damager == true
    if not (tank or healer or damager) then
        return
    end

    local getRoleUpdate = _G.GetLFGRoleUpdate
    if getRoleUpdate then
        local _, _, _, _, _, isBGRoleCheck = getRoleUpdate()
        if isBGRoleCheck then
            return
        end
    end

    local setRoles = SetLFGRoles or _G.SetLFGRoles
    local completeRoleCheck = completeLFGRoleCheck or _G.CompleteLFGRoleCheck
    local getRoles = _G.GetLFGRoles
    if not (setRoles and completeRoleCheck) then
        return
    end

    local oldLeader = false
    if getRoles then
        local leader = getRoles()
        if type(leader) == "boolean" then
            oldLeader = leader
        end
    end

    local function TryComplete(attempt)
        if not IsModuleEnabled or not IsModuleEnabled() then
            return
        end

        local setCallOK = pcall(setRoles, oldLeader, tank, healer, damager)
        if not setCallOK then
            return
        end

        local completeCallOK, completeResult = pcall(completeRoleCheck, true)
        if completeCallOK and completeResult ~= false then
            return
        end

        if attempt < 3 and C_Timer and C_Timer.After then
            C_Timer.After(0.1, function()
                TryComplete(attempt + 1)
            end)
        end
    end

    -- The role-check event can arrive before Blizzard has finished populating
    -- the solo queue state, so wait one frame before using the role APIs.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            TryComplete(1)
        end)
    else
        TryComplete(1)
    end
end
local function EnsureQueueConfirmationHook()
    if runtime.lfgDialogHookInstalled or not _G.LFGListApplicationDialog then
        return
    end
    runtime.lfgDialogHookInstalled = true
    _G.LFGListApplicationDialog:HookScript("OnShow", function(dialog)
        local db = Mod:GetDB()
        if not IsModuleEnabled or not IsModuleEnabled() or not db.visibility.skipQueueConfirmation or IsControlKeyDown() then
            return
        end
        local button = dialog.SignUpButton
        if button and button.IsEnabled and button:IsEnabled() then
            if Mod.ApplyPersistentLFGNoteNow then
                Mod:ApplyPersistentLFGNoteNow()
            elseif Mod.ApplyPersistentLFGNote then
                Mod:ApplyPersistentLFGNote()
            end
            button:Click()
        end
    end)
end

local function EnsureHooks()
    if runtime.hooksInstalled then
        return
    end
    EnsureQueueConfirmationHook()
    EnsureKeystoneHook()
    runtime.hooksInstalled = true
end

local function HandleSystemEvent(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        runtime.inMythicPlus = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() or false
        runtime.encounterActive = _G.C_InstanceEncounter and _G.C_InstanceEncounter.IsEncounterInProgress and _G.C_InstanceEncounter.IsEncounterInProgress() or false
        EnsureHooks()
        Mod:RefreshCombatRezDisplay()
        Mod:RefreshDurabilityTicker()
        Mod:ApplyHideMinimapIcon()

        local db = Mod:GetDB()
        if db.equipmentReminder.enabled and db.equipmentReminder.showOnInstance then
            local inInstance, instanceType = IsInInstance()
            if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario") then
                C_Timer.After(1, function()
                    if Mod and Mod.ShowEquipmentReminder then
                        Mod:ShowEquipmentReminder()
                    end
                end)
            end
        end
        return
    end

    if event == "READY_CHECK" then
        local db = Mod:GetDB()
        if db.equipmentReminder.enabled and db.equipmentReminder.showOnReadyCheck then
            C_Timer.After(0.2, function()
                if Mod and Mod.ShowEquipmentReminder then
                    Mod:ShowEquipmentReminder()
                end
            end)
        end
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            Mod:UpdateDurabilityWarning()
            if runtime.equipmentFrame and runtime.equipmentFrame:IsShown() then
                Mod:RefreshEquipmentReminderFrame()
            end
        end
        return
    end

    if event == "UPDATE_INVENTORY_DURABILITY" then
        Mod:UpdateDurabilityWarning()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" then
            Mod:RefreshCombatRezDisplay()
            if runtime.equipmentFrame and runtime.equipmentFrame:IsShown() then
                Mod:RefreshEquipmentReminderFrame()
            end
        end
        return
    end

    if event == "EQUIPMENT_SETS_CHANGED" then
        if runtime.equipmentFrame and runtime.equipmentFrame:IsShown() then
            Mod:RefreshEquipmentReminderFrame()
        end
        return
    end

    if event == "CHALLENGE_MODE_START" then
        runtime.inMythicPlus = true
        Mod:RefreshCombatRezDisplay()
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" then
        runtime.inMythicPlus = false
        Mod:RefreshCombatRezDisplay()
        return
    end

    if event == "ENCOUNTER_START" then
        runtime.encounterActive = true
        Mod:RefreshCombatRezDisplay()
        return
    end

    if event == "ENCOUNTER_END" then
        runtime.encounterActive = false
        Mod:RefreshCombatRezDisplay()
        return
    end

    if event == "UNIT_DIED" then
        local destGUID = ...
        HandleCombatRezDeathWarning(destGUID)
        return
    end

    if event == "PLAYER_DEAD" then
        HideDurabilityWarning()
        C_Timer.After(0.05, function()
            if Mod and Mod.ActivateDeathReleaseProtection then
                Mod:ActivateDeathReleaseProtection()
            end
        end)
        return
    end

    if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        ClearDeathReleaseState()
        Mod:UpdateDurabilityWarning()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        HideDurabilityWarning()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        Mod:UpdateDurabilityWarning()
        return
    end

    if event == "DELETE_ITEM_CONFIRM" then
        HandleEasyItemDestroy()
        return
    end

    if event == "AUCTION_HOUSE_SHOW" then
        ApplyAuctionHouseCurrentExpansion()
        return
    end

    if event == "LFG_ROLE_CHECK_SHOW" then
        HandleSkipQueueRoleCheck()
        return
    end

    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == "Blizzard_ChallengesUI" then
            EnsureKeystoneHook()
        elseif loadedAddon == "Blizzard_GroupFinder" then
            EnsureQueueConfirmationHook()
        end
    end
end

local function EnsureSystemEventFrame()
    if runtime.eventFrame then
        return
    end

    local frame = CreateFrame("Frame", "KT_EnhancementsSystemEventFrame")
    runtime.eventFrame = frame
    frame:SetScript("OnEvent", HandleSystemEvent)

    for _, eventName in ipairs({
        "PLAYER_ENTERING_WORLD",
        "READY_CHECK",
        "UNIT_INVENTORY_CHANGED",
        "UPDATE_INVENTORY_DURABILITY",
        "PLAYER_SPECIALIZATION_CHANGED",
        "EQUIPMENT_SETS_CHANGED",
        "CHALLENGE_MODE_START",
        "CHALLENGE_MODE_COMPLETED",
        "ENCOUNTER_START",
        "ENCOUNTER_END",
        "UNIT_DIED",
        "PLAYER_DEAD",
        "PLAYER_ALIVE",
        "PLAYER_UNGHOST",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED",
        "DELETE_ITEM_CONFIRM",
        "AUCTION_HOUSE_SHOW",
        "LFG_ROLE_CHECK_SHOW",
        "ADDON_LOADED",
    }) do
        frame:RegisterEvent(eventName)
    end
end

local baseRefreshSettings = Mod.RefreshSettings
function Mod:RefreshSettings(...)
    if baseRefreshSettings then
        baseRefreshSettings(self, ...)
    end
    EnsureHooks()
    self:RegisterCombatRezMover()
    self:RefreshCombatRezDisplay()
    self:RefreshDurabilityTicker()
    self:ApplyHideMinimapIcon()
    self:SetSpellQueueWindow(self:GetDB().optimizations.spellQueueWindow or 150)
    if runtime.equipmentFrame and runtime.equipmentFrame:IsShown() then
        self:RefreshEquipmentReminderFrame()
    end
end

local baseOnEnable = Mod.OnEnable
function Mod:OnEnable(...)
    if baseOnEnable then
        baseOnEnable(self, ...)
    end
    EnsureReloadPopup()
    EnsureHooks()
    EnsureSystemEventFrame()
    self:RegisterCombatRezMover()
    runtime.inMythicPlus = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() or false
    runtime.encounterActive = _G.C_InstanceEncounter and _G.C_InstanceEncounter.IsEncounterInProgress and _G.C_InstanceEncounter.IsEncounterInProgress() or false
    self:RefreshCombatRezDisplay()
    self:RefreshDurabilityTicker()
    self:ApplyHideMinimapIcon()
end
