-------------------------------------------------------------------------------
--  KUIResourceBars.lua
--  Módulo de Barras de Salud, Poder y Recursos de Clase para KullThranUI
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local function Loc(text)
    local L = KT and KT.GetLocale and KT:GetLocale()
    return (L and L[text]) or text
end
local KRB = KT:NewModule("ResourceBars", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)
ns.KRB = KRB

local floor, min, max = math.floor, math.min, math.max
local GetShapeshiftFormID = GetShapeshiftFormID
local DEFAULT_BAR_TEXTURE = "Melli Reforged"
local BAR_TEXTURE_DEFAULT_VERSION = 1

-------------------------------------------------------------------------------
--  Helpers Seguros Anti-Crash (Tainted Secret Values)
-------------------------------------------------------------------------------
local function IsSecret(v)
    if C_UI and C_UI.IsSecret then return C_UI.IsSecret(v) == true end
    if _G.IsSecretValue then return _G.IsSecretValue(v) == true end
    if issecretvalue then return issecretvalue(v) == true end
    return false
end

local function SafeNum(v, fallback)
    if type(v) == "number" and not IsSecret(v) then
        return v
    end

    if IsSecret(v) then
        -- Blizzard marks some combat/PvP numbers as secret. Any attempt to stringify
        -- or pattern-match them taints the execution path, so we must bail out here.
        return fallback or 0
    end

    if type(v) == "string" then
        local cleaned = v
        local okGsub, gsubRes = pcall(string.gsub, v, ",", "")
        if okGsub and type(gsubRes) == "string" then
            cleaned = gsubRes
        end

        local n = tonumber(cleaned) or tonumber(v)
        if not n then
            local okMatch, m = pcall(string.match, cleaned, "[-%d%.]+")
            if okMatch and m then
                n = tonumber(m)
            end
        end
        if n then return n end
    end

    return fallback or 0
end

-- FIX: FormatCur usa estilo abreviado:
--   >= 1M  → "1.2M"
--   >= 1K  → "250K"  (sin decimales si es redondo, con 1 decimal si tiene fracción)
--   < 1K   → número entero
local function FormatCur(val)
    if AbbreviateLargeNumbers then
        local ok, res = pcall(AbbreviateLargeNumbers, val)
        if ok and res ~= nil then return res end
    end
    if IsSecret(val) then
        local s = tostring(val)
        local n = tonumber(s)
        if n then return FormatCur(n) end
        return s
    end
    if type(val) == "string" then
        local n = tonumber(val)
        if n then return FormatCur(n) end
        return val
    end
    if type(val) ~= "number" then return tostring(val) end
    if val >= 1e6 then
        local v = val / 1e6
        if v == floor(v) then return string.format("%dM", v) end
        return string.format("%.1fM", v)
    end
    if val >= 1e3 then
        local v = val / 1e3
        if v == floor(v) then return string.format("%dK", v) end
        return string.format("%.1fK", v)
    end
    return tostring(floor(val))
end

local function FormatFull(val)
    if IsSecret(val) then
        local s = tostring(val)
        local n = tonumber(s)
        if n then return FormatFull(n) end
        return s
    end
    if type(val) == "string" then
        local n = tonumber(val)
        if n then return FormatFull(n) end
        return val
    end
    if type(val) ~= "number" then return tostring(val) end
    local n = floor(val)
    if BreakUpLargeNumbers then
        local ok, res = pcall(BreakUpLargeNumbers, n)
        if ok and res ~= nil then return res end
    end
    return tostring(n)
end

local function GetSafePct(cur, mx)
    if type(cur) ~= "number" or type(mx) ~= "number" then return "??" end
    -- Los valores secretos (issecretvalue) reportan type "number" pero no
    -- admiten aritmetica: cualquier operacion lanza error en contexto tainted.
    if IsSecret(cur) or IsSecret(mx) then return "??" end
    if mx <= 0 then return cur > 0 and 100 or 0 end
    return floor((cur / mx) * 100)
end

-- 12.x: UnitHealth/UnitPower pueden devolver valores secretos en contextos
-- restringidos; la aritmetica Lua sobre ellos lanza error. UnitHealthPercent,
-- AbbreviateNumbers y string.format son funciones C de Blizzard que los
-- manejan de forma nativa (se pueden mostrar, no calcular), asi que el texto
-- se construye SIEMPRE via C y nunca con operadores Lua sobre el valor crudo.
local formatStr = string.format

local function GetHealthPctStr(unit)
    -- Porcentaje de vida sin aritmetica Lua (C nativo, seguro con secretos).
    -- [FIX 12.x] Sin el curve ScaleTo100, UnitHealthPercent devuelve un ratio
    -- 0-1 (vida llena = "1%"). Con ScaleTo100 devuelve el rango correcto 0-100.
    if not UnitHealthPercent then return nil end
    local curve = CurveConstants and CurveConstants.ScaleTo100
    local ok, res = pcall(UnitHealthPercent, unit or "player", true, curve)
    if not ok or res == nil then return nil end
    local okF, resF = pcall(formatStr, "%d", res)
    if not okF then return nil end
    return resF
end

local function GetPowerPctStr(unit, powerType)
    -- [FIX 12.x] UnitPowerPercent existe en 12.x; con ScaleTo100 devuelve 0-100
    -- de forma nativa C (segura con secretos), igual que UnitHealthPercent.
    if UnitPowerPercent then
        local curve = CurveConstants and CurveConstants.ScaleTo100
        local ok, res = pcall(UnitPowerPercent, unit or "player", powerType, true, curve)
        if ok and res ~= nil then
            local okF, resF = pcall(formatStr, "%d", res)
            if okF then return resF end
        end
    end
    -- Fallback: aritmetica Lua solo cuando los valores NO son secretos.
    local cur = UnitPower(unit or "player", powerType)
    local mx = UnitPowerMax(unit or "player", powerType)
    if IsSecret(cur) or IsSecret(mx) then return nil end
    if type(cur) ~= "number" or type(mx) ~= "number" then return nil end
    local ok, res = pcall(function()
        if mx <= 0 then return cur > 0 and "100" or "0" end
        return formatStr("%d", floor((cur / mx) * 100))
    end)
    if not ok then return nil end
    return res
end

local function FormatCurSafe(val)
    if not IsSecret(val) then return FormatCur(val) end
    -- Valor secreto: AbbreviateNumbers (C) lo muestra como texto real.
    if AbbreviateNumbers then
        local ok, res = pcall(AbbreviateNumbers, val)
        if ok and res ~= nil then return res end
    end
    local ok, res = pcall(formatStr, "%d", val)
    if ok then return res end
    return ""
end

local function FormatFullSafe(val)
    if not IsSecret(val) then return FormatFull(val) end
    local ok, res = pcall(formatStr, "%d", val)
    if ok then return res end
    return ""
end

local function ParseMarkerValues(rawValues, maxValue)
    local parsed = {}
    local seen = {}

    if type(rawValues) == "table" then
        for _, value in ipairs(rawValues) do
            local numberValue = tonumber(value)
            if numberValue then
                parsed[#parsed + 1] = numberValue
            end
        end
    elseif type(rawValues) == "string" and rawValues ~= "" then
        for token in string.gmatch(rawValues, "[-%d%.]+") do
            local numberValue = tonumber(token)
            if numberValue then
                parsed[#parsed + 1] = numberValue
            end
        end
    end

    table.sort(parsed)

    local result = {}
    for _, value in ipairs(parsed) do
        local clamped = value
        if type(maxValue) == "number" and maxValue > 0 then
            clamped = max(0, min(value, maxValue))
        end

        if clamped > 0 then
            local key = string.format("%.3f", clamped)
            if not seen[key] then
                seen[key] = true
                result[#result + 1] = clamped
            end
        end
    end

    while #result > 3 do
        table.remove(result)
    end

    return result
end

local function CreateDefaultMarkerProfile()
    return {
        enabled = false,
        target = "auto",
        slot1 = nil,
        slot2 = nil,
        slot3 = nil,
        values = "",
        width = 2,
        colorR = 1,
        colorG = 1,
        colorB = 1,
        colorA = 0.95,
    }
end

local function BuildMarkerValueString(profile)
    local values = ParseMarkerValues({
        profile.slot1,
        profile.slot2,
        profile.slot3,
    })
    return table.concat(values, ",")
end

local function GetMarkerRenderValues(profile, maxValue)
    if type(profile) ~= "table" then
        return {}
    end

    local slotValues = ParseMarkerValues({
        profile.slot1,
        profile.slot2,
        profile.slot3,
    }, maxValue)

    if #slotValues > 0 then
        return slotValues
    end

    return ParseMarkerValues(profile.values, maxValue)
end

-- PT is declared further down; this function needs the mana type before it.
local MARKER_POWER_TYPE_MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

local function ShouldRenderMarkersOnPrimary(markerCfg, primaryPowerType, secondaryResource)
    if type(markerCfg) ~= "table" or markerCfg.enabled ~= true then
        return false
    end

    if markerCfg.target == "primary" then
        return primaryPowerType ~= MARKER_POWER_TYPE_MANA
    end
    if markerCfg.target == "secondary" then
        return false
    end

    if secondaryResource and secondaryResource.type == "bar" then
        return false
    end

    return primaryPowerType ~= MARKER_POWER_TYPE_MANA
end

local function ShouldRenderMarkersOnSecondary(markerCfg, secondaryResource)
    if type(markerCfg) ~= "table" or markerCfg.enabled ~= true then
        return false
    end

    if not (secondaryResource and secondaryResource.type == "bar") then
        return false
    end

    if markerCfg.target == "primary" then
        return false
    end

    return true
end

local function NormalizeMarkerProfile(profile)
    profile = type(profile) == "table" and profile or {}

    profile.enabled = profile.enabled == true
    if profile.target ~= "primary" and profile.target ~= "secondary" then
        profile.target = "auto"
    end

    -- Keep the 3 slots stable so clearing a slot doesn't "shift" other markers.
    -- Only backfill slots from the legacy `values` string when no slots are set at all.
    local slotCount = 0
    for index = 1, 3 do
        local key = "slot" .. index
        local value = tonumber(profile[key])
        if value and value > 0 then
            profile[key] = value
            slotCount = slotCount + 1
        else
            profile[key] = nil
        end
    end

    if slotCount == 0 and type(profile.values) == "string" and profile.values ~= "" then
        local parsed = ParseMarkerValues(profile.values)
        profile.slot1 = parsed[1]
        profile.slot2 = parsed[2]
        profile.slot3 = parsed[3]
    end

    -- Migration: older versions shipped default marker slots (30/60/90) even when disabled.
    -- Clear those so "disabled" doesn't come pre-populated for new setups.
    if profile.enabled ~= true
        and profile.slot1 == 30 and profile.slot2 == 60 and profile.slot3 == 90
        and (profile.width == nil or profile.width == 2)
        and (profile.colorR == nil or profile.colorR == 1)
        and (profile.colorG == nil or profile.colorG == 1)
        and (profile.colorB == nil or profile.colorB == 1)
        and (profile.colorA == nil or profile.colorA == 0.95) then
        profile.slot1 = nil
        profile.slot2 = nil
        profile.slot3 = nil
        profile.values = ""
    end

    profile.values = BuildMarkerValueString(profile)
    profile.width = profile.width or 2
    profile.colorR = profile.colorR or 1
    profile.colorG = profile.colorG or 1
    profile.colorB = profile.colorB or 1
    profile.colorA = profile.colorA or 0.95

    return profile
end

local function CloneMarkerConfig(source)
    if type(source) ~= "table" then
        return nil
    end

    local clone = {}
    for key, value in pairs(source) do
        clone[key] = value
    end
    return NormalizeMarkerProfile(clone)
end

local function EnsureMarkerState(state)
    if type(state) ~= "table" then
        state = {}
    end

    if state.mode or state.character or state.specs or state.loadouts then
        if state.mode ~= "character" and state.mode ~= "spec" and state.mode ~= "loadout" then
            state.mode = "loadout"
        end
        if state.mode == "spec" and state._scopeMigratedToLoadout ~= true then
            state.mode = "loadout"
            state._scopeMigratedToLoadout = true
        end
        state.character = NormalizeMarkerProfile(state.character or CreateDefaultMarkerProfile())
        state.specs = state.specs or {}
        state.loadouts = state.loadouts or {}
        return state
    end

    local migrated = {
        mode = "loadout",
        character = CloneMarkerConfig(state) or CreateDefaultMarkerProfile(),
        specs = {},
        loadouts = {},
        _scopeMigratedToLoadout = true,
    }
    return migrated
end

local function GetSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or not GetSpecializationInfo then
        return nil
    end
    local specID = GetSpecializationInfo(specIndex)
    if type(specID) == "number" and specID > 0 then
        return specID
    end
    return nil
end

local function GetActiveTalentPresetKey()
    local classTalents = _G.C_ClassTalents
    if type(classTalents) ~= "table" or type(classTalents.GetActiveConfigID) ~= "function" then
        return nil
    end

    local configID = classTalents.GetActiveConfigID()
    if type(configID) ~= "number" or configID <= 0 then
        return nil
    end

    local specID = GetSpecID()
    if specID then
        return tostring(specID) .. ":" .. tostring(configID)
    end

    return tostring(configID)
end

-- Enum.PowerType
local PT = {
    -- Prefer the live Enum.PowerType values when available (future-proof),
    -- with numeric fallbacks for older clients.
    MANA        = (Enum and Enum.PowerType and Enum.PowerType.Mana)          or 0,
    RAGE        = (Enum and Enum.PowerType and Enum.PowerType.Rage)          or 1,
    FOCUS       = (Enum and Enum.PowerType and Enum.PowerType.Focus)         or 2,
    ENERGY      = (Enum and Enum.PowerType and Enum.PowerType.Energy)        or 3,
    COMBO       = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints)   or 4,
    RUNES       = (Enum and Enum.PowerType and Enum.PowerType.Runes)         or 5,
    RUNIC_POWER = (Enum and Enum.PowerType and Enum.PowerType.RunicPower)    or 6,
    SOUL_SHARDS = (Enum and Enum.PowerType and Enum.PowerType.SoulShards)    or 7,
    LUNAR_POWER = (Enum and Enum.PowerType and Enum.PowerType.LunarPower)    or 8,
    HOLY_POWER  = (Enum and Enum.PowerType and Enum.PowerType.HolyPower)     or 9,
    MAELSTROM   = (Enum and Enum.PowerType and Enum.PowerType.Maelstrom)     or 11,
    CHI         = (Enum and Enum.PowerType and Enum.PowerType.Chi)           or 12,
    INSANITY    = (Enum and Enum.PowerType and Enum.PowerType.Insanity)      or 13,
    ARCANE      = (Enum and Enum.PowerType and Enum.PowerType.ArcaneCharges) or 16,
    FURY        = (Enum and Enum.PowerType and Enum.PowerType.Fury)          or 17,
    PAIN        = (Enum and Enum.PowerType and Enum.PowerType.Pain)          or 18,
    ESSENCE     = (Enum and Enum.PowerType and Enum.PowerType.Essence)       or 19,
}

local function NormalizeColorMode(mode, fallbackClassColor)
    if mode == "spec" or mode == "power" or mode == "custom" then
        return mode
    end
    return (fallbackClassColor == false) and "custom" or "power"
end

local POWER_COLOR_FALLBACKS = {
    [PT.MANA]        = { 0.00, 0.55, 1.00 },
    [PT.RAGE]        = { 0.90, 0.15, 0.15 },
    [PT.FOCUS]       = { 0.77, 0.53, 0.24 },
    [PT.ENERGY]      = { 1.00, 0.96, 0.41 },
    [PT.RUNIC_POWER] = { 0.00, 0.82, 1.00 },
    [PT.LUNAR_POWER] = { 0.30, 0.52, 0.90 },
    [PT.HOLY_POWER]  = { 0.95, 0.90, 0.60 },
    [PT.MAELSTROM]   = { 0.00, 0.50, 1.00 },
    [PT.CHI]         = { 0.71, 1.00, 0.92 },
    [PT.INSANITY]    = { 0.40, 0.00, 0.80 },
    [PT.ARCANE]      = { 0.10, 0.69, 0.97 },
    [PT.FURY]        = { 0.79, 0.26, 0.99 },
    [PT.PAIN]        = { 1.00, 0.61, 0.00 },
    [PT.ESSENCE]     = { 0.20, 0.58, 0.50 },
    [PT.SOUL_SHARDS] = { 0.58, 0.51, 0.79 },
    [PT.COMBO]       = { 1.00, 0.96, 0.41 },
    [PT.RUNES]       = { 0.77, 0.12, 0.23 },
}

local KUI_PREFERRED_POWER_COLORS = {
    [PT.COMBO]       = { 1.00, 0.90, 0.18 }, -- rogue / feral
    [PT.RUNES]       = { 0.37, 0.79, 1.00 }, -- death knight
    [PT.SOUL_SHARDS] = { 0.66, 0.42, 0.95 }, -- warlock
    [PT.ARCANE]      = { 0.12, 0.82, 1.00 }, -- arcane mage
    [PT.MAELSTROM]   = { 0.08, 0.66, 1.00 }, -- shaman
}

local POWER_TOKEN_BY_TYPE = {
    [PT.MANA] = "MANA",
    [PT.RAGE] = "RAGE",
    [PT.FOCUS] = "FOCUS",
    [PT.ENERGY] = "ENERGY",
    [PT.RUNIC_POWER] = "RUNIC_POWER",
    [PT.LUNAR_POWER] = "LUNAR_POWER",
    [PT.HOLY_POWER] = "HOLY_POWER",
    [PT.MAELSTROM] = "MAELSTROM",
    [PT.CHI] = "CHI",
    [PT.INSANITY] = "INSANITY",
    [PT.ARCANE] = "ARCANE_CHARGES",
    [PT.FURY] = "FURY",
    [PT.PAIN] = "PAIN",
    [PT.ESSENCE] = "ESSENCE",
    [PT.SOUL_SHARDS] = "SOUL_SHARDS",
    [PT.COMBO] = "COMBO_POINTS",
    [PT.RUNES] = "RUNES",
}

local AUTO_HIDE_MANA_SPEC_IDS = {
    [66] = true,
    [70] = true,
    [102] = true,
    [258] = true,
    [262] = true,
    [263] = true,
    [265] = true,
    [266] = true,
    [267] = true,
    [1467] = true,
    [1473] = true,
}

local function GetRawResourceBarsDB()
    if KT and KT.db and KT.db.profile then
        return KT.db.profile.resourceBars
    end
end

local function GetCustomPowerColorTuple(powerType)
    local rawDb = GetRawResourceBarsDB()
    local overrides = rawDb and rawDb.powerColors
    local entry = overrides and overrides[tostring(powerType or "")]
    if type(entry) == "table" then
        local r = tonumber(entry.r)
        local g = tonumber(entry.g)
        local b = tonumber(entry.b)
        if r and g and b then
            return r, g, b
        end
    end
    return nil
end

local function ShouldAutoHideManaForCurrentSpec()
    local specID = GetSpecID()
    return specID and AUTO_HIDE_MANA_SPEC_IDS[specID] == true or false
end

local function IsManaHiddenForCurrentSpec(db)
    local primary = db and db.primary
    if not primary then
        return false
    end

    local specKey = tostring(GetSpecID() or 0)
    local perSpec = primary.hideManaBySpec
    if type(perSpec) == "table" and perSpec[specKey] ~= nil then
        return perSpec[specKey] == true
    end

    if primary.hideMana ~= nil then
        return primary.hideMana == true
    end

    return ShouldAutoHideManaForCurrentSpec()
end

local function SetManaHiddenForCurrentSpec(db, value)
    local primary = db and db.primary
    if not primary then
        return
    end

    primary.hideManaBySpec = primary.hideManaBySpec or {}
    primary.hideManaBySpec[tostring(GetSpecID() or 0)] = value and true or false
    primary.hideMana = nil
end

local function GetPowerBarColorTuple(powerType)
    local customR, customG, customB = GetCustomPowerColorTuple(powerType)
    if customR and customG and customB then
        return customR, customG, customB
    end

    local preferred = KUI_PREFERRED_POWER_COLORS[powerType]
    if preferred then
        return preferred[1], preferred[2], preferred[3]
    end

    local powerColors = _G.PowerBarColor
    if powerColors then
        local direct = powerColors[powerType]
        if type(direct) == "table" and direct.r and direct.g and direct.b then
            return direct.r, direct.g, direct.b
        end

        local token = POWER_TOKEN_BY_TYPE[powerType]
        local tokenInfo = token and powerColors[token]
        if type(tokenInfo) == "table" and tokenInfo.r and tokenInfo.g and tokenInfo.b then
            return tokenInfo.r, tokenInfo.g, tokenInfo.b
        end
    end

    local fallback = POWER_COLOR_FALLBACKS[powerType]
    if fallback then
        return fallback[1], fallback[2], fallback[3]
    end
    return nil
end

local function EnsureSpecColorEntry(cfg, specID, powerType)
    cfg.specColors = cfg.specColors or {}
    local key = tostring(specID or 0)
    local entry = cfg.specColors[key]
    if type(entry) ~= "table" then
        entry = {
            -- Per-spec colors should inherit the module's authored defaults first.
            -- "Power Type" mode already exists for players who want Blizzard resource colors.
            r = cfg.fillR or 1,
            g = cfg.fillG or 1,
            b = cfg.fillB or 1,
            a = cfg.fillA or 1,
        }
        cfg.specColors[key] = entry
    end
    if entry.a == nil then
        entry.a = cfg.fillA or 1
    end
    return entry
end

local function ResolveSectionColor(cfg, powerType, alphaOverride)
    local mode = NormalizeColorMode(cfg and cfg.colorMode, cfg and cfg.classColor)
    local fallbackA = alphaOverride or (cfg and cfg.fillA) or 1

    if mode == "spec" then
        local specID = GetSpecID()
        local entry = EnsureSpecColorEntry(cfg, specID, powerType)
        return entry.r or 1, entry.g or 1, entry.b or 1, entry.a or fallbackA
    end

    if mode == "power" and powerType then
        local r, g, b = GetPowerBarColorTuple(powerType)
        if r and g and b then
            return r, g, b, fallbackA
        end
    end

    return (cfg and cfg.fillR) or 1, (cfg and cfg.fillG) or 1, (cfg and cfg.fillB) or 1, fallbackA
end

local function BuildSecondaryPipColorKey(resource)
    if type(resource) ~= "table" then
        return nil
    end

    local powerType = tonumber(resource.power)
    if not powerType and resource.kind == "runes" then
        powerType = PT.RUNES
    end
    if not powerType then
        return nil
    end

    local _, classFile = UnitClass("player")
    classFile = classFile or "UNKNOWN"

    return string.format("%s:%s:%s", classFile, tostring(resource.kind or resource.type or "resource"), tostring(powerType))
end

local function GetSecondaryPipColorBucket(db, resource, createIfMissing)
    if not (db and db.secondary) then
        return nil, nil
    end

    local key = BuildSecondaryPipColorKey(resource)
    if not key then
        return nil, nil
    end

    db.secondary.pipColors = db.secondary.pipColors or {}
    local bucket = db.secondary.pipColors[key]
    if type(bucket) ~= "table" then
        if not createIfMissing then
            return nil, key
        end
        bucket = {}
        db.secondary.pipColors[key] = bucket
    end

    return bucket, key
end

local function GetSecondaryPipColorOverride(db, resource, index)
    local bucket = GetSecondaryPipColorBucket(db, resource, false)
    if type(bucket) ~= "table" then
        return nil
    end

    local entry = bucket[tostring(index or "")]
    if type(entry) ~= "table" then
        return nil
    end

    local r = tonumber(entry.r)
    local g = tonumber(entry.g)
    local b = tonumber(entry.b)
    local a = tonumber(entry.a)
    if not (r and g and b) then
        return nil
    end

    return r, g, b, a
end

local function ResolveSecondaryPipColor(db, resource, index, alphaOverride)
    local r, g, b, a = GetSecondaryPipColorOverride(db, resource, index)
    if r and g and b then
        if a == nil then
            a = alphaOverride or (db and db.secondary and db.secondary.fillA) or 1
        end
        return r, g, b, a
    end

    return ResolveSectionColor(db and db.secondary, resource and resource.power, alphaOverride)
end

local function GetActiveMarkerConfig(db)
    db.secondary = db.secondary or {}
    db.secondary.markers = EnsureMarkerState(db.secondary.markers)

    local markerState = db.secondary.markers
    markerState.character = NormalizeMarkerProfile(markerState.character or CreateDefaultMarkerProfile())

    if markerState.mode == "loadout" then
        local loadoutKey = GetActiveTalentPresetKey()
        local specID = GetSpecID()
        local specProfile = specID and type(markerState.specs) == "table" and markerState.specs[specID] or nil
        local seedProfile = specProfile or markerState.character

        if loadoutKey then
            markerState.loadouts = markerState.loadouts or {}
            markerState.loadouts[loadoutKey] = NormalizeMarkerProfile(markerState.loadouts[loadoutKey] or CloneMarkerConfig(seedProfile))
            return markerState.loadouts[loadoutKey]
        end

        if specProfile then
            markerState.specs[specID] = NormalizeMarkerProfile(specProfile)
            return markerState.specs[specID]
        end
    end

    if markerState.mode == "spec" then
        local specID = GetSpecID()
        if not specID then
            return markerState.character
        end
        markerState.specs[specID] = NormalizeMarkerProfile(markerState.specs[specID] or CloneMarkerConfig(markerState.character))
        return markerState.specs[specID]
    end

    return markerState.character
end

-------------------------------------------------------------------------------
--  Constantes de Clases y Recursos
-------------------------------------------------------------------------------
local function GetRBFont()
    return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end

local function DisablePixelSnap(obj)
    if obj.SetSnapToPixelGrid then
        obj:SetSnapToPixelGrid(false)
        obj:SetTexelSnappingBias(0)
    end
end

local function GetStaggerBarColor(staggerAmount, healthMax, alpha)
    alpha = alpha or 1
    local pct = 0
    if type(staggerAmount) == "number" and type(healthMax) == "number" and healthMax > 0 then
        pct = staggerAmount / healthMax
    end

    -- Prefer Blizzard-provided thresholds when available.
    local yellow = _G.STAGGER_YELLOW_TRANSITION or 0.3
    local red = _G.STAGGER_RED_TRANSITION or 0.6

    if pct >= red then
        return 1.0, 0.20, 0.20, alpha -- heavy
    elseif pct >= yellow then
        return 1.0, 0.82, 0.25, alpha -- moderate
    elseif pct > 0 then
        return 0.25, 1.0, 0.35, alpha -- light
    end

    -- No stagger: keep it subtle.
    return 0.35, 0.35, 0.35, alpha * 0.35
end

local function GetPowerMax(unit, powerType, fallback)
    local mxRaw = UnitPowerMax(unit or "player", powerType)
    local mx = SafeNum(mxRaw, fallback or 0)
    if mx <= 0 then
        return fallback or 0
    end
    return mx
end

local function AuraCountFromFindResult(a1, a2, a3)
    -- Support both the "aura table" API and the classic multi-return API.
    if type(a1) == "table" then
        local points = a1.points
        local pointCount = type(points) == "table" and points[1] or nil
        return SafeNum(a1.applications or a1.charges or a1.count or a1.stackCount or pointCount or 0, 0)
    end
    if a1 ~= nil then
        return SafeNum(a3 or 0, 0)
    end
    return 0
end

local function GetAuraStacksBySpellIDs(unit, spellIDs)
    if not unit or type(spellIDs) ~= "table" then return 0 end

    if unit == "player" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for i = 1, #spellIDs do
            local id = spellIDs[i]
            if id then
                local auraData = C_UnitAuras.GetPlayerAuraBySpellID(id)
                local count = AuraCountFromFindResult(auraData)
                if count and count > 0 then
                    return count
                end
            end
        end
    end

    if AuraUtil and AuraUtil.FindAuraBySpellID then
        for i = 1, #spellIDs do
            local id = spellIDs[i]
            if id then
                local a1, a2, a3 = AuraUtil.FindAuraBySpellID(id, unit, "HELPFUL")
                local count = AuraCountFromFindResult(a1, a2, a3)
                if count and count > 0 then
                    return count
                end
            end
        end
    end

    -- Fallback scan (older clients / API differences)
    if UnitBuff then
        for idx = 1, 40 do
            local name, _, count, _, _, _, _, _, _, spellId = UnitBuff(unit, idx)
            if not name then break end
            for i = 1, #spellIDs do
                if spellId == spellIDs[i] then
                    return SafeNum(count or 0, 0)
                end
            end
        end
    end

    return 0
end

local function SetStatusBarMinMaxSafe(bar, mn, mx)
    if not bar then return end
    -- Prefer raw values (they may be valid even if marked secret), fallback to sanitized numbers.
    if pcall(bar.SetMinMaxValues, bar, mn, mx) then
        return
    end
    local smn, smx = SafeNum(mn, 0), SafeNum(mx, 1)
    if smx <= smn then
        smn, smx = 0, 1
    end
    pcall(bar.SetMinMaxValues, bar, smn, smx)
end

local function SetStatusBarValueSafe(bar, value)
    if not bar then return end
    -- Native StatusBar interpolation (the engine eases the fill, zero per-frame
    -- Lua). Gains and drops (damage, spending) both ease. The first paint
    -- after a build lands at once so a rebuilt bar does not sweep up from empty.
    local interp = bar._ktSmooth
    if interp and bar._ktSmoothPrimed then
        if pcall(bar.SetValue, bar, value, interp) then return end
    end
    bar._ktSmoothPrimed = true
    if pcall(bar.SetValue, bar, value) then
        return
    end
    pcall(bar.SetValue, bar, SafeNum(value, 0))
end

local POWER_COLORS = POWER_COLOR_FALLBACKS
_G._KRB_PowerColors = POWER_COLORS
_G._KRB_GetPowerBarColor = GetPowerBarColorTuple
_G._KRB_GetSecondaryPipColorKey = BuildSecondaryPipColorKey

-- ============================================================================
-- FIX DRUIDA BALANCE / MOONKIN:
--   El juego reporta UnitPowerType() = PT.MANA (0) INCLUSO en forma Moonkin.
--   Esto causaba que se mostraran DOS barras: Maná (primaria) + Astral Power
--   (secundaria) en forma de Moonkin, cuando solo debe mostrarse Astral Power.
--
--   Lógica correcta:
--     · Moonkin (formID 197) → primario = Astral Power,  secundario = nil
--     · Caster/humanoide     → primario = Maná,           secundario = barra AP
-- ============================================================================
local function GetPrimaryPowerType()
    local powerType = UnitPowerType("player")
    local _, classFile = UnitClass("player")
    local specID = GetSpecID()

    -- ── Druida (CUALQUIER SPEC) ──────────────────────────────────────────
    -- Basamos la lógica en la forma activa, no en la spec, para cubrir
    -- casos como Balance en forma de Oso o Feral sin forma.
    if classFile == "DRUID" then
        local formID = GetShapeshiftFormID and GetShapeshiftFormID() or 0
        if formID == 197 then
            -- Moonkin: el juego reporta MANA pero el recurso real es Astral Power
            return PT.LUNAR_POWER
        elseif formID ~= 0 then
            -- Cualquier otra forma (Oso=5, Gato=1, Viaje=3, etc.)
            -- El juego reporta correctamente Ira o Energía → usarlo tal cual
            return powerType
        else
            -- Sin forma (forma humanoide/caster) → Maná
            return PT.MANA
        end
    end

    -- Elemental Shaman: Maná primario, Maelstrom secundario
    if classFile == "SHAMAN" and specID == 262 then return PT.MANA end
    -- Shadow Priest: Maná primario, Insanity secundario
    if classFile == "PRIEST" and specID == 258 then return PT.MANA end

    -- Para el resto el juego devuelve el tipo correcto:
    -- Energía (Gato), Ira (Oso), Maná (caster), Furia (DH), etc.
    return powerType
end

-- Extra Mana Bar: mana on its own bar, next to the primary one, while the primary
-- resource is another (a druid in Cat, Bear or Moonkin Form, or any class whose
-- resource is not mana but that still has a mana pool).
local function ShouldShowExtraMana(db, primaryPowerType)
    if not (db and db.primary and db.primary.extraMana == true) then return false end
    if primaryPowerType == nil or primaryPowerType == PT.MANA then return false end
    local mx = UnitPowerMax("player", PT.MANA)
    if IsSecret(mx) then return true end
    return type(mx) == "number" and mx > 0
end

-- The primary section's color rules, for mana. A custom fill belongs to the main
-- resource, so the extra bar keeps the mana color then.
local function ResolveExtraManaColor(db)
    local mode = NormalizeColorMode(db.primary.colorMode, db.primary.classColor)
    if mode == "custom" then
        local r, g, b = GetPowerBarColorTuple(PT.MANA)
        if r and g and b then return r, g, b, db.primary.fillA or 1 end
    end
    return ResolveSectionColor(db.primary, PT.MANA, db.primary.fillA or 1)
end

local VENGEANCE_SOUL_CLEAVE = 228477

local function GetSecondaryResource()
    local _, classFile = UnitClass("player")
    local specID = GetSpecID()
    local pType = UnitPowerType("player")

    if classFile == "PALADIN"     then return { power = PT.HOLY_POWER,  max = GetPowerMax("player", PT.HOLY_POWER, 5), type = "pips" } end
    if classFile == "ROGUE"       then return { power = PT.COMBO,       max = GetPowerMax("player", PT.COMBO, 5),      type = "pips" } end

    -- ── Druida (CUALQUIER SPEC) ──────────────────────────────────────────
    if classFile == "DRUID" then
        local formID = GetShapeshiftFormID and GetShapeshiftFormID() or 0

        if formID == 197 then
            -- Moonkin: AP ya es el primario → sin secundario
            return nil
        elseif formID ~= 0 then
            -- Oso, Gato, Viaje, etc.: el recurso primario ya es Ira/Energía
            -- Feral (spec 2) muestra Puntos de Combo como secundario en forma Felina
            if formID == 1 then
                return { power = PT.COMBO, max = GetPowerMax("player", PT.COMBO, 5), type = "pips" }
            end
            -- Oso u otras formas sin recurso secundario relevante
            return nil
        else
            -- Sin forma (caster/humanoide):
            -- Combo points stay hidden outside Cat Form, including Feral spec.
            -- Balance: barra de AP como secundario bajo el Maná
            if specID == 102 then
                return { power = PT.LUNAR_POWER, max = GetPowerMax("player", PT.LUNAR_POWER, 100), type = "bar" }
            end
            -- Guardian/Restoration sin forma: sin secundario
            return nil
        end
    end

    -- Monk:
    --  - Brewmaster (268): Stagger (Aplazar) as a bar scaled to max health.
    --  - Windwalker (269): Chi as pips.
    if classFile == "MONK" and specID == 268 then
        return { kind = "stagger", type = "bar" }
    end
    if classFile == "MONK" and specID == 269 then
        return { power = PT.CHI, max = GetPowerMax("player", PT.CHI, 5), type = "pips" }
    end
    if classFile == "WARLOCK"                   then return { power = PT.SOUL_SHARDS, max = GetPowerMax("player", PT.SOUL_SHARDS, 5), type = "pips" } end
    if classFile == "DEATHKNIGHT"               then return { kind = "runes", power = PT.RUNES, max = 6, type = "pips" } end
    if classFile == "EVOKER"                    then return { power = PT.ESSENCE,     max = GetPowerMax("player", PT.ESSENCE, 5),    type = "pips" } end
    if classFile == "MAGE"        and specID == 62 then return { power = PT.ARCANE,      max = GetPowerMax("player", PT.ARCANE, 4),     type = "pips" } end
    if classFile == "PRIEST"      and specID == 258 then return { power = PT.INSANITY,    max = GetPowerMax("player", PT.INSANITY, 100), type = "bar"  } end

    if classFile == "SHAMAN" and specID == 262 then
        return { power = PT.MAELSTROM, max = GetPowerMax("player", PT.MAELSTROM, 100), type = "bar" }
    end
    -- Enhancement Shaman uses Maelstrom Weapon stacks (a buff), not the Maelstrom power bar.
    -- Show stacks as pips (0-10) so the class resource is still visible alongside mana.
    if classFile == "SHAMAN" and specID == 263 then
        local maxStacks = 5
        if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(384143) then
            maxStacks = 10
        end
        return {
            kind = "aura",
            power = PT.MAELSTROM, -- used for coloring
            max = maxStacks,
            type = "pips",
            auraSpellIDs = { 344179, 187880, 187881, 53817 }, -- modern + legacy spellIDs for "Maelstrom Weapon"
        }
    end

    -- Trackers without a power type of their own: power only picks the color, as for Maelstrom Weapon.
    if classFile == "DEMONHUNTER" then
        if specID == 581 then return { kind = "soulFragments", power = PT.FURY, max = 6, type = "pips" } end
        local specIndex = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
            and C_SpecializationInfo.GetSpecialization()
        if SPEC_DEMONHUNTER_DEVOURER and specIndex == SPEC_DEMONHUNTER_DEVOURER then
            return { kind = "devourer", power = PT.FURY, type = "bar" }
        end
    end
    if classFile == "HUNTER" and specID == 255 then
        return { kind = "tip", power = PT.FOCUS, max = 3, type = "pips" }
    end
    if classFile == "WARRIOR" and specID == 72 then
        return { kind = "whirlwind", power = PT.RAGE, max = 4, type = "pips" }
    end

    return nil
end

-- These change through player auras, so UNIT_AURA redraws them with no polling.
local AURA_DRIVEN_KINDS = { aura = true, soulFragments = true, tip = true, devourer = true }

-- Devourer's progress, read as the native bar reads it: Dark Heart stacks, or Silence
-- the Whispers against the Collapsing Star cost during Void Metamorphosis.
local function GetDevourerProgress()
    local ids = Constants and Constants.UnitPowerSpellIDs
    if not (ids and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return 0, nil end
    local inMetamorphosis = C_UnitAuras.GetPlayerAuraBySpellID(ids.VOID_METAMORPHOSIS_SPELL_ID) ~= nil
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(inMetamorphosis and ids.SILENCE_THE_WHISPERS_SPELL_ID or ids.DARK_HEART_SPELL_ID)
    local maximum
    if inMetamorphosis then
        maximum = GetCollapsingStarCost and GetCollapsingStarCost()
    elseif C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications then
        maximum = C_Spell.GetSpellMaxCumulativeAuraApplications(ids.DARK_HEART_SPELL_ID)
    end
    return aura and aura.applications or 0, maximum
end

-- The Resource Bars pips step aside while the player frame draws the same resource.
-- A class resource only shows when the character really has it:
--   * Forever has no Soul Shards, Holy Power, Chi, runes... (shards are bag items there):
--     its only class resource is combo points (Rogue, Cat Form).
--   * A power pip needs a live maximum: below the level that unlocks it the client
--     reports 0, and the old fallback drew five pips that could never fill.
do
    local rawGetSecondary = GetSecondaryResource
    GetSecondaryResource = function()
        local res = rawGetSecondary()
        if res and KT.IS_FOREVER and res.power ~= PT.COMBO then return nil end
        if res and res.type == "pips" and res.kind == nil and res.power and res.power ~= PT.COMBO then
            local mxRaw = UnitPowerMax("player", res.power)
            if not IsSecret(mxRaw) and not (type(mxRaw) == "number" and mxRaw > 0) then return nil end
        end
        -- Bars that have no equivalent on the frame (stagger, insanity, maelstrom) stay.
        if res and (res.type == "pips" or res.kind == "devourer") and KT.UnitFrameDrawsClassResource
            and KT.UnitFrameDrawsClassResource() then
            return nil
        end
        return res
    end
end

-------------------------------------------------------------------------------
--  Base de Datos: Inicialización Segura
-------------------------------------------------------------------------------
local function GetSafeDB()
    local function HasUserDefinedSpecColors(specColors)
        return type(specColors) == "table" and next(specColors) ~= nil
    end

    local function IsNear(a, b)
        return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < 0.0001
    end

    local function MatchesDefaultColor(section, r, g, b)
        if type(section) ~= "table" then
            return false
        end
        return IsNear(section.fillR, r) and IsNear(section.fillG, g) and IsNear(section.fillB, b)
    end

    if not KT.db.profile.resourceBars then
        KT.db.profile.resourceBars = {
            enabled    = true,
            general   = { anchorGap = 4, matchCooldownWidth = true, manualWidth = 250, strata = "MEDIUM", hideOOC = false, xOffset = 0, bgA = 0.8, previewMode = "stack", texture = DEFAULT_BAR_TEXTURE, textureDefaultVersion = BAR_TEXTURE_DEFAULT_VERSION, frameArtKit = "default" },
            powerColors = {},
            health    = { enabled = false, height = 25, borderSize = 1, fillR = 0.15, fillG = 0.75, fillB = 0.30, fillA = 1, textFormat = "both", textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE },
            primary   = { enabled = true,  height = 25, borderSize = 1, fillR = 0.00, fillG = 0.55, fillB = 1.00, fillA = 1, textFormat = "curpp", textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE, classColor = true, colorMode = "power", specColors = {}, hideManaBySpec = {}, markers = { enabled = false, values = "", width = 2, colorR = 1, colorG = 1, colorB = 1, colorA = 0.95 } },
            secondary = { enabled = true,  pipHeight = 14, pipSpacing = 2, borderSize = 1, fillR = 0.95, fillG = 0.90, fillB = 0.60, fillA = 1, showText = true, textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE, classColor = true, colorMode = "power", specColors = {}, pipColors = {}, markers = { mode = "loadout", character = CreateDefaultMarkerProfile(), specs = {}, loadouts = {} } },
        }
    end

    local db = KT.db.profile.resourceBars
    if db.enabled == nil then db.enabled = true end
    db.general   = db.general   or { anchorGap = 4, matchCooldownWidth = true, manualWidth = 250, strata = "MEDIUM", hideOOC = false, xOffset = 0, bgA = 0.8, previewMode = "stack", texture = DEFAULT_BAR_TEXTURE, textureDefaultVersion = BAR_TEXTURE_DEFAULT_VERSION, frameArtKit = "default" }
    if db.general.anchorGap == nil         then db.general.anchorGap          = 4    end
    if db.general.smoothBars == nil        then db.general.smoothBars         = true end
    if db.general.matchCooldownWidth == nil then db.general.matchCooldownWidth = true end
    if db.general.manualWidth == nil        then db.general.manualWidth        = 250  end
    if db.general.strata == nil             then db.general.strata             = "MEDIUM" end
    if db.general.hideOOC == nil            then db.general.hideOOC            = false end
    if db.general.xOffset == nil            then db.general.xOffset            = 0 end
    if db.general.bgA == nil                then db.general.bgA                = 0.8 end
    if db.general.previewMode == nil        then db.general.previewMode        = "stack" end
    if db.general.frameArtKit == nil        then db.general.frameArtKit        = "default" end

    db.health    = db.health    or { enabled = false, height = 25, borderSize = 1, fillR = 0.15, fillG = 0.75, fillB = 0.30, fillA = 1, textFormat = "both", textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE }
    db.primary   = db.primary   or { enabled = true,  height = 25, borderSize = 1, fillR = 0.00, fillG = 0.55, fillB = 1.00, fillA = 1, textFormat = "curpp", textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE, classColor = true, colorMode = "power", specColors = {}, hideManaBySpec = {}, markers = { enabled = false, values = "", width = 2, colorR = 1, colorG = 1, colorB = 1, colorA = 0.95 } }
    db.secondary = db.secondary or { enabled = true,  pipHeight = 14, pipSpacing = 2, borderSize = 1, fillR = 0.95, fillG = 0.90, fillB = 0.60, fillA = 1, showText = true, textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE, classColor = true, colorMode = "power", specColors = {}, pipColors = {}, markers = { mode = "loadout", character = CreateDefaultMarkerProfile(), specs = {}, loadouts = {} } }
    db.powerColors = db.powerColors or {}

    if (tonumber(db.general.textureDefaultVersion) or 0) < BAR_TEXTURE_DEFAULT_VERSION then
        for _, section in ipairs({ db.health, db.primary, db.secondary }) do
            if not section.texture or section.texture == "Melli" then
                section.texture = DEFAULT_BAR_TEXTURE
            end
        end
        if not db.general.texture or db.general.texture == "Melli" then
            db.general.texture = DEFAULT_BAR_TEXTURE
        end
        db.general.textureDefaultVersion = BAR_TEXTURE_DEFAULT_VERSION
    end
    if not db.general.texture then db.general.texture = db.primary.texture or DEFAULT_BAR_TEXTURE end
    if not db.health.texture then db.health.texture = DEFAULT_BAR_TEXTURE end
    if not db.primary.texture then db.primary.texture = DEFAULT_BAR_TEXTURE end
    if not db.secondary.texture then db.secondary.texture = DEFAULT_BAR_TEXTURE end
    -- Scalar backfill. The "section = section or { ... }" lines above only
    -- inject defaults when the whole section table is missing, so a profile
    -- saved before a field existed keeps that field nil forever. That is what
    -- produced the runtime cascade (nil pipSpacing arithmetic, then nil
    -- textSize reaching SetFont). Fill any missing scalar here, once, so the
    -- saved profile converges instead of relying on per-call Site guards.
    local SECTION_SCALAR_DEFAULTS = {
        { db.health,    { enabled = false, height = 25, borderSize = 1, textSize = 13, barAlpha = 1, fillA = 1, fillR = 0.15, fillG = 0.75, fillB = 0.30, textFormat = "both" } },
        -- VisualThemes can seed these section tables before Resource Bars
        -- initializes them. Backfill only missing enable flags so a profile
        -- reset starts with the module on, while an explicit false remains
        -- untouched.
        { db.primary,   { enabled = true, height = 25, borderSize = 1, textSize = 13, barAlpha = 1, fillA = 1, fillR = 0.00, fillG = 0.55, fillB = 1.00, textFormat = "curpp" } },
        { db.secondary, { enabled = true, pipHeight = 14, pipSpacing = 2, borderSize = 1, textSize = 13, barAlpha = 1, fillA = 1, fillR = 0.95, fillG = 0.90, fillB = 0.60, showText = true } },
    }
    for _, entry in ipairs(SECTION_SCALAR_DEFAULTS) do
        local section, defaults = entry[1], entry[2]
        for key, value in pairs(defaults) do
            if section[key] == nil then section[key] = value end
        end
    end

    if db.primary.classColor == nil then db.primary.classColor = true end
    if db.secondary.classColor == nil then db.secondary.classColor = true end
    if db.primary.colorMode == "spec" and not HasUserDefinedSpecColors(db.primary.specColors) and MatchesDefaultColor(db.primary, 0.00, 0.55, 1.00) then
        db.primary.colorMode = "power"
    end
    if db.secondary.colorMode == "spec" and not HasUserDefinedSpecColors(db.secondary.specColors) and MatchesDefaultColor(db.secondary, 0.95, 0.90, 0.60) then
        db.secondary.colorMode = "power"
    end
    db.primary.colorMode = NormalizeColorMode(db.primary.colorMode, db.primary.classColor)
    db.secondary.colorMode = NormalizeColorMode(db.secondary.colorMode, db.secondary.classColor)
    db.primary.specColors = db.primary.specColors or {}
    db.secondary.specColors = db.secondary.specColors or {}
    db.secondary.pipColors = db.secondary.pipColors or {}
    db.primary.hideManaBySpec = db.primary.hideManaBySpec or {}
    if db.primary.extraMana == nil then db.primary.extraMana = false end
    if db.primary.extraManaHeight == nil then db.primary.extraManaHeight = 10 end
    db.primary.markers = db.primary.markers or { enabled = false, values = "", width = 2, colorR = 1, colorG = 1, colorB = 1, colorA = 0.95 }
    db.secondary.markers = EnsureMarkerState(db.secondary.markers or CloneMarkerConfig(db.primary.markers))
    GetActiveMarkerConfig(db)

    if ns.EnsureSwingDefaults then ns.EnsureSwingDefaults(db) end
    return db
end

--- Restores every color/size scalar on the SAVED profile to the addon
--- defaults. GetSafeDB only fills nil, so a profile that already carries odd
--- values (e.g. written by an interrupted migration, or by the VisualThemes
--- adapter seeding sparse tables) keeps them forever and the bars render
--- "weird" even though the defaults are correct. This only touches
--- color/size fields -- never `general.matchCooldownWidth`/`manualWidth`,
--- never the enabled flags, never the round-pip clustering, because those are
--- deliberate per-client differences from the Retail tree.
function KRBRestoreProfileColorsAndSizes()
    local db = GetSafeDB()
    if not db then return false end

    local RESET = {
        health    = { enabled = false, fillR = 0.15, fillG = 0.75, fillB = 0.30, fillA = 1, height = 25, textSize = 13, barAlpha = 1, borderSize = 1 },
        primary   = { fillR = 0.00, fillG = 0.55, fillB = 1.00, fillA = 1, height = 25, textSize = 13, barAlpha = 1, borderSize = 1 },
        secondary = { fillR = 0.95, fillG = 0.90, fillB = 0.60, fillA = 1, pipHeight = 14, pipSpacing = 2, textSize = 13, barAlpha = 1, borderSize = 1 },
    }
    local changed = 0
    for section, defaults in pairs(RESET) do
        db[section] = type(db[section]) == "table" and db[section] or {}
        for key, value in pairs(defaults) do
            if db[section][key] ~= value then
                db[section][key] = value
                changed = changed + 1
            end
        end
    end
    db.health = db.health or {}
    db.health.enabled = false
    db.enabled = true
    db.primary = db.primary or {}
    db.secondary = db.secondary or {}
    db.primary.enabled = true
    db.secondary.enabled = true
    KRB:BuildBars()
    return changed
end

_G._KRB_RestoreProfileColorsAndSizes = KRBRestoreProfileColorsAndSizes

_G._KRB_GetDB = function() return GetSafeDB() end
_G._KRB_GetMarkerState = function()
    local db = GetSafeDB()
    return db and db.secondary and db.secondary.markers or nil
end
_G._KRB_GetActiveMarkerConfig = function()
    local db = GetSafeDB()
    return db and GetActiveMarkerConfig(db) or nil
end
_G._KRB_GetPrimaryPowerType = function()
    return GetPrimaryPowerType()
end
_G._KRB_GetSecondaryResource = function()
    return GetSecondaryResource()
end
_G._KRB_PowerTypes = PT
_G._KRB_PowerTypeTokens = POWER_TOKEN_BY_TYPE
_G._KRB_GetHideManaSetting = function()
    local db = GetSafeDB()
    return IsManaHiddenForCurrentSpec(db)
end
_G._KRB_SetHideManaSetting = function(value)
    local db = GetSafeDB()
    SetManaHiddenForCurrentSpec(db, value)
end

-------------------------------------------------------------------------------
--  Base anchor & Width Polling (Fix para el Ancho del Cooldown Manager)
-------------------------------------------------------------------------------
local function GetBaseAnchor()
    -- Comprobamos que el frame tenga posición accesible antes de usarlo como ancla.
    -- Si GetLeft() devuelve un secret value (taintado), lo ignoramos y devolvemos nil
    -- para que StackAbove use la posición fija de fallback en lugar de propagarle taint.
    local function IsSafeAnchor(f)
        if not f then return false end
        if not (f.GetPoint and f:GetPoint(1)) then return false end
        local _, _, _, _, y = f:GetPoint()
        if y and math.abs(y) > 3000 then return false end -- Ignore off-screen frames
        local ok, v = pcall(function() return f:GetLeft() end)
        if not ok then return false end
        if issecretvalue and issecretvalue(v) then return false end
        return true
    end

    local kuiBar = _G["KUI_CDMBar_cooldowns"]
    if IsSafeAnchor(kuiBar) then return kuiBar end
    local ecv = _G.EssentialCooldownViewer
    if IsSafeAnchor(ecv) then return ecv end
    return nil
end

_G._KRB_HasCooldownAnchor = function()
    return GetBaseAnchor() ~= nil
end

-- Lectura segura de ancho: los frames del Cooldown Viewer pueden estar taintados
-- por marcos externos compatibles. GetWidth() devuelve un "secret number" que
-- causa crash en Backdrop.lua si se usa directamente para geometría.
-- Usamos pcall + issecretvalue para aislar el valor antes de usarlo.
local function SafeGetWidth(frame)
    if not frame then return nil end
    local ok, w = pcall(function() return frame:GetWidth() end)
    if not ok then return nil end
    if issecretvalue and issecretvalue(w) then return nil end
    if type(w) ~= "number" or w <= 0 then return nil end
    return w
end

local function GetReferenceWidth()
    local db = GetSafeDB()
    if db.general.matchCooldownWidth ~= false then
        local kuiBar = _G["KUI_CDMBar_cooldowns"]
        if kuiBar and kuiBar:IsShown() then
            local w = SafeGetWidth(kuiBar)
            if w and w > 20 then
                db.general._cachedWidth = w
                return w
            end
        end
        local ecv = _G.EssentialCooldownViewer
        if ecv and ecv:IsShown() then
            local w = SafeGetWidth(ecv)
            if w and w > 20 then
                db.general._cachedWidth = w
                return w
            end
        end
        if db.general._cachedWidth and db.general._cachedWidth > 20 then
            return db.general._cachedWidth
        end
    else
        if db.general.manualWidth and db.general.manualWidth > 20 then
            return db.general.manualWidth
        end
    end
    return 250
end

-- Monitor activo de Ancho
local _widthCheckTicker
local function StartWidthPolling()
    if _widthCheckTicker then _widthCheckTicker:Cancel() end
    local ticks = 0
    _widthCheckTicker = C_Timer.NewTicker(0.5, function()
        ticks = ticks + 1
        local db = GetSafeDB()
        local shouldRebuild = false
        local anchor = GetBaseAnchor()
        if anchor ~= KRB._lastKnownAnchor then
            KRB._lastKnownAnchor = anchor
            shouldRebuild = true
        end
        if db.general.matchCooldownWidth then
            local w = GetReferenceWidth()
            if w and w > 20 and w ~= KRB._lastKnownValidWidth then
                KRB._lastKnownValidWidth = w
                shouldRebuild = true
            end
        end
        if shouldRebuild and KRB.BuildBars then KRB:BuildBars() end
        if ticks >= 20 then
            _widthCheckTicker:Cancel()
            _widthCheckTicker = nil
        end
    end)
end

-------------------------------------------------------------------------------
--  Pixel Border helper
-------------------------------------------------------------------------------
local function MakePixelBorder(parent, r, g, b, a, size)
    local bf = CreateFrame("Frame", nil, parent)
    bf:SetAllPoints(parent)
    bf:SetFrameLevel(parent:GetFrameLevel() + 1)

    local function MkEdge()
        local t = bf:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(r, g, b, a)
        DisablePixelSnap(t)
        return t
    end

    local eT, eB, eL, eR = MkEdge(), MkEdge(), MkEdge(), MkEdge()

    local function UpdateSizes(sz)
        eT:ClearAllPoints(); eT:SetPoint("TOPLEFT");      eT:SetPoint("TOPRIGHT");    eT:SetHeight(sz)
        eB:ClearAllPoints(); eB:SetPoint("BOTTOMLEFT");   eB:SetPoint("BOTTOMRIGHT"); eB:SetHeight(sz)
        eL:ClearAllPoints(); eL:SetPoint("TOPLEFT",  eT,  "BOTTOMLEFT");  eL:SetPoint("BOTTOMLEFT",  eB, "TOPLEFT");  eL:SetWidth(sz)
        eR:ClearAllPoints(); eR:SetPoint("TOPRIGHT", eT,  "BOTTOMRIGHT"); eR:SetPoint("BOTTOMRIGHT", eB, "TOPRIGHT"); eR:SetWidth(sz)
    end
    UpdateSizes(size)

    return {
        SetSize  = function(self, newSz) UpdateSizes(newSz) end,
        SetShown = function(self, shown)
            if shown then eT:Show(); eB:Show(); eL:Show(); eR:Show()
            else          eT:Hide(); eB:Hide(); eL:Hide(); eR:Hide() end
        end,
    }
end

-------------------------------------------------------------------------------
--  StatusBar factory
-------------------------------------------------------------------------------
local function CreateStatusBar(parent, name)
    local bar = CreateFrame("StatusBar", name, parent)
    local db = GetSafeDB()
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.07, 0.07, 0.07, db.general.bgA)
    bar._bg = bg

    bar._border = MakePixelBorder(bar, 0, 0, 0, 1, 1)

    -- Texto en un frame propio por encima de todo (borde, arte de tema, fills de
    -- otros modulos): como OVERLAY de la barra podia quedar tapado.
    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints(bar)
    textFrame:SetFrameLevel(bar:GetFrameLevel() + 20)
    textFrame:EnableMouse(false)
    local text = textFrame:CreateFontString(nil, "OVERLAY", nil, 7)
    text:SetFont(GetRBFont(), 13, "OUTLINE")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 1, 1)
    text:SetDrawLayer("OVERLAY", 7)
    bar._text = text
    bar._textFrame = textFrame

    return bar
end

local function EnsureMarkerTextures(bar, count)
    if not bar then
        return {}
    end

    bar._markers = bar._markers or {}
    for index = 1, count do
        if not bar._markers[index] then
            local marker = bar:CreateTexture(nil, "OVERLAY", nil, 3)
            marker:SetTexture("Interface\\Buttons\\WHITE8x8")
            DisablePixelSnap(marker)
            bar._markers[index] = marker
        end
    end

    return bar._markers
end

local function HideMarkers(bar)
    if not (bar and bar._markers) then
        return
    end

    for _, marker in pairs(bar._markers) do
        if marker and marker.Hide then
            marker:Hide()
        end
    end
end

local RESOURCE_CIRCLE_MASK = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_mask.tga"
local RESOURCE_CIRCLE_BORDER = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_border.tga"

-- How the class resource pips look (KUIResourceBars_PipArt.lua): the Pip Style, the
-- resource's own piece or the combo point art, and whether plain pips are round.
local function ResolvePipLook(db, sec)
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    local PipArt = ns.PipArt
    local frameArtKit = db and db.general and db.general.frameArtKit
    local look = {}
    if PipArt then
        look.style = PipArt.ResolveStyle(db and db.secondary, theme, frameArtKit)
    else
        look.style = (theme == "classic" or theme == "forever" or frameArtKit == "classic") and "circle" or "pip"
    end
    if PipArt and look.style ~= "pip" and sec and sec.type == "pips" then
        if sec.power == PT.COMBO then
            look.combo = PipArt.Combo(look.style)
        elseif sec.kind == nil or sec.kind == "runes" then
            look.piece = PipArt.Piece(sec.kind == "runes" and PT.RUNES or sec.power, GetSpecID())
        end
    end
    look.round = not look.piece and not look.combo and (look.style == "circle" or look.style == "forever")
    return look
end

-- Destruction reads its shards in tenths: the next shard fills by the fraction.
local DESTRUCTION_SPEC_ID = 267
local function GetPartialShard(sec)
    if not (sec and sec.power == PT.SOUL_SHARDS and GetSpecID() == DESTRUCTION_SPEC_ID) then return nil end
    local raw = UnitPower("player", PT.SOUL_SHARDS, true)
    if IsSecret(raw) or type(raw) ~= "number" then return nil end
    local whole = floor(raw / 10)
    local fraction = (raw - whole * 10) / 10
    if fraction <= 0 then return nil end
    return whole + 1, fraction
end

-- The partly filled pip: a status bar over the empty pip, at 75% of the pip colour.
local function ShowPartialPip(pip, fraction, texture, r, g, b)
    local bar = pip._ktPartial
    if not bar then
        bar = CreateFrame("StatusBar", nil, pip)
        bar:SetAllPoints(pip)
        bar:SetFrameLevel(pip:GetFrameLevel() + 1)
        bar:SetMinMaxValues(0, 1)
        pip._ktPartial = bar
    end
    if bar._texture ~= texture then
        bar:SetStatusBarTexture(texture)
        bar._texture = texture
    end
    bar:SetStatusBarColor(r * 0.75, g * 0.75, b * 0.75, 1)
    bar:SetValue(fraction)
    bar:Show()
end

local function HidePartialPip(pip)
    if pip._ktPartial then pip._ktPartial:Hide() end
end

-- Red combo pips belong to the Blizzard-art visual styles; KullThranUI Style
-- keeps its own pip colors.
local function IsComboSecondaryResource(resource)
    if not (resource and resource.power == PT.COMBO) then return false end
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    return theme ~= nil and theme ~= "kui"
end

--- Texture for the round (circular-masked) pips. The VisualThemes adapter
--- seeds "Melli Dark" for the forever theme because that is the right texture
--- for its BARS, but Melli Dark is a full-width bar strip: clipped to a small
--- circle it renders as a mostly-empty ring with one bright edge segment,
--- which is what made the combo pips look broken. Round pips always take
--- Melli Reforged, which was authored for small framed shapes.
local ROUND_PIP_TEXTURE_NAME = "Melli Reforged"
local ROUND_PIP_TEXTURE_PATH =
    "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga"

local function ResolvePipTexture(db, round)
    local name = db and db.secondary and db.secondary.texture or DEFAULT_BAR_TEXTURE
    if round then
        local fetched = LSM and LSM:Fetch("statusbar", ROUND_PIP_TEXTURE_NAME, true)
        if fetched then return fetched end
        return ROUND_PIP_TEXTURE_PATH
    end
    local fetched = LSM and LSM:Fetch("statusbar", name)
    return fetched or "Interface\\Buttons\\WHITE8x8"
end

local function ApplyResourcePipShape(pip, round, combo)
    if not pip then return end
    if round then
        local mask = pip._circleMask
        if not mask then
            mask = pip:CreateMaskTexture()
            pip._circleMask = mask
        end
        mask:SetTexture(RESOURCE_CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:ClearAllPoints()
        mask:SetAllPoints(pip)
        mask:Show()
        for _, tex in ipairs({ pip._bg, pip._fill }) do
            if tex and tex.AddMaskTexture then
                if tex.RemoveMaskTexture then pcall(tex.RemoveMaskTexture, tex, mask) end
                pcall(tex.AddMaskTexture, tex, mask)
            end
        end
        if pip._secretBar and pip._secretBar.GetStatusBarTexture then
            local fill = pip._secretBar:GetStatusBarTexture()
            if fill and fill.AddMaskTexture then
                if fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, mask) end
                pcall(fill.AddMaskTexture, fill, mask)
            end
        end
        local rechargeFill = pip._ktRecharge and pip._ktRecharge:GetStatusBarTexture()
        if rechargeFill and rechargeFill.AddMaskTexture then
            pcall(rechargeFill.RemoveMaskTexture, rechargeFill, mask)
            pcall(rechargeFill.AddMaskTexture, rechargeFill, mask)
        end
        if not pip._circleBorder then
            pip._circleBorder = pip:CreateTexture(nil, "OVERLAY", nil, 4)
            pip._circleBorder:SetTexture(RESOURCE_CIRCLE_BORDER)
            pip._circleBorder:SetAllPoints(pip)
        end
        local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
            and KT.VisualThemes:GetRenderedTheme()
        if theme == "forever" then
            -- Forever's bronze (#DC8560) for every round pip's outer ring.
            pip._circleBorder:SetVertexColor(0.862745, 0.521569, 0.376471, 1)
        else
            pip._circleBorder:SetVertexColor(1, combo and 0.82 or 1, combo and 0.08 or 1, 1)
        end
        pip._circleBorder:Show()
        if pip._border then pip._border:SetShown(false) end
    else
        local mask = pip._circleMask
        if mask then
            mask:Hide()
            for _, tex in ipairs({ pip._bg, pip._fill }) do
                if tex and tex.RemoveMaskTexture then pcall(tex.RemoveMaskTexture, tex, mask) end
            end
        end
        if pip._secretBar and pip._secretBar.GetStatusBarTexture then
            local fill = pip._secretBar:GetStatusBarTexture()
            if fill and fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, mask) end
        end
        local rechargeFill = mask and pip._ktRecharge and pip._ktRecharge:GetStatusBarTexture()
        if rechargeFill and rechargeFill.RemoveMaskTexture then
            pcall(rechargeFill.RemoveMaskTexture, rechargeFill, mask)
        end
        if pip._circleBorder then pip._circleBorder:Hide() end
        -- MakePixelBorder returns a plain table exposing only SetSize/SetShown,
        -- not a real Region -- :Show() doesn't exist on it and crashed here.
        if pip._border then pip._border:SetShown(true) end
    end
end

local function UpdateMarkers(bar, markerCfg, maxValue)
    if not bar then
        return
    end

    if not markerCfg or markerCfg.enabled ~= true or type(maxValue) ~= "number" or maxValue <= 0 or not bar:IsShown() then
        HideMarkers(bar)
        return
    end

    local values = GetMarkerRenderValues(markerCfg, maxValue)
    if #values == 0 then
        HideMarkers(bar)
        return
    end

    local markers = EnsureMarkerTextures(bar, #values)
    local barWidth = bar:GetWidth() or 0
    local inset = 2
    local markerWidth = max(1, markerCfg.width or 2)
    local markerHeight = max(1, (bar:GetHeight() or 0) - (inset * 2))
    local usedMarkers = {}

    for index, value in ipairs(values) do
        local marker = markers[index]
        usedMarkers[index] = true
        local ratio = value / maxValue
        local offset = ratio * barWidth
        offset = max(markerWidth * 0.5, min(offset, max(markerWidth * 0.5, barWidth - (markerWidth * 0.5))))

        marker:ClearAllPoints()
        marker:SetSize(markerWidth, markerHeight)
        marker:SetPoint("CENTER", bar, "LEFT", offset, 0)
        marker:SetColorTexture(
            markerCfg.colorR or 1,
            markerCfg.colorG or 1,
            markerCfg.colorB or 1,
            markerCfg.colorA or 0.95
        )
        marker:Show()
    end

    for index, marker in pairs(markers) do
        if not usedMarkers[index] and marker and marker.Hide then
            marker:Hide()
        end
    end
end

-------------------------------------------------------------------------------
--  Frames
-------------------------------------------------------------------------------
local healthBar, primaryBar, secondaryFrame, secondaryBar, resourceAnchor, extraManaBar
local pips = {}
local _postCombatAnchorTicker
local KT_RB_UNLOCK_KEY = "resource_bars"

local function GetResourceBarsUnlockFallbackSize()
    local db = GetSafeDB()
    local width = (db and db.general and db.general.manualWidth) or 250
    local gap = (db and db.general and db.general.anchorGap) or 4
    local height = 0
    local visibleCount = 0

    if db and db.secondary and db.secondary.enabled then
        height = height + math.max(db.secondary.pipHeight or 14, 10)
        visibleCount = visibleCount + 1
    end
    if db and db.primary and db.primary.enabled and not IsManaHiddenForCurrentSpec(db) then
        height = height + math.max(db.primary.height or 25, 10)
        visibleCount = visibleCount + 1
    end
    if db and db.health and db.health.enabled then
        height = height + math.max(db.health.height or 25, 10)
        visibleCount = visibleCount + 1
    end
    if visibleCount > 1 then
        height = height + ((visibleCount - 1) * gap)
    end

    return math.max(width, 120), math.max(height, 18)
end

-------------------------------------------------------------------------------
--  Detached bars: a section can leave the stack and move on its own
-------------------------------------------------------------------------------
-- Each detached section gets a holder of its own with an Unlock Mode mover
-- ("resource_bars_<section>"). Until it is moved it keeps its slot in the
-- stack, so ticking the option alone moves nothing; once it has a saved
-- position it leaves the stack and the bars above it close the gap.
local DETACH_SECTIONS = {
    { key = "secondary", label = "Class Resource Bar" },
    { key = "primary", label = "Primary Power Bar" },
    { key = "extraMana", label = "Extra Mana Bar" },
    { key = "health", label = "Health Bar" },
    { key = "swing", label = "Autoattack Bars" },
}
local detachHolders = {}

local function DetachUnlockKey(section)
    return KT_RB_UNLOCK_KEY .. "_" .. section
end

local function IsDetached(db, section)
    local map = db and db.general and db.general.detached
    return type(map) == "table" and map[section] == true
end

local function IsSectionEnabled(db, section)
    if section == "secondary" then return db.secondary and db.secondary.enabled end
    if section == "primary" then return db.primary and db.primary.enabled end
    if section == "extraMana" then return db.primary and db.primary.extraMana == true end
    if section == "health" then return db.health and db.health.enabled end
    if section == "swing" then return db.swing and db.swing.enabled end
end

local function GetOpenUnlockMode()
    local um = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
    if um and um.isOpen then return um end
end

-- A drag not yet saved belongs to Unlock Mode: a rebuild in the meantime
-- (shapeshift, Cooldown Manager layout, cast bar settings) keeps the bar
-- where the mover left it instead of throwing it back to its saved spot or
-- into the stack under the mover.
local function GetUnlockPosition(key)
    local um = GetOpenUnlockMode()
    local pending = um and type(um.pendingPositions) == "table" and um.pendingPositions[key]
    if type(pending) == "table" and pending.point then return pending end
    local editMode = KT.db and KT.db.profile and KT.db.profile.editMode
    local saved = editMode and editMode.frames and editMode.frames[key]
    if type(saved) == "table" and saved.point then return saved end
end

local function GetDetachedPosition(section)
    return GetUnlockPosition(DetachUnlockKey(section))
end

-- A rebuild moves the stack and the detached holders (a bar leaving the stack
-- closes its gap): put the Resource Bars movers back over them. The mover
-- being dragged is left to the drag.
local function SyncResourceBarMovers()
    local um = GetOpenUnlockMode()
    local movers = um and um.movers
    if not movers then return end
    local function Sync(key)
        local mover = movers[key]
        if mover and mover.Sync and mover:IsShown() and not mover.isDragging then
            mover:Sync()
        end
    end
    Sync(KT_RB_UNLOCK_KEY)
    for _, entry in ipairs(DETACH_SECTIONS) do Sync(DetachUnlockKey(entry.key)) end
end

local function EnsureDetachHolder(section)
    local holder = detachHolders[section]
    if not holder then
        holder = CreateFrame("Frame", "KUI_ResourceBarsDetached_" .. section, UIParent)
        holder:SetClampedToScreen(true)
        holder:SetSize(1, 1)
        detachHolders[section] = holder
    end
    return holder
end

-- Lays the bars bottom to top on the stack anchor; bars of a detached section
-- go on that section's holder (see above).
local function NewStackPlacer(anchorFrame, db, gap, ensureHolder, savedPosition)
    local placer = { totalHeight = 0, sections = {} }
    local strata = db.general.strata or "MEDIUM"
    function placer.Place(frame, section)
        frame:ClearAllPoints()
        frame:SetFrameStrata(strata)
        if not (section and IsDetached(db, section)) then
            frame:SetParent(anchorFrame)
            frame:SetPoint("BOTTOM", anchorFrame, "BOTTOM", 0, placer.totalHeight)
            placer.last = frame
            placer.totalHeight = placer.totalHeight + frame:GetHeight() + gap
            return
        end
        local place = placer.sections[section]
        if not place then
            local saved = savedPosition(section)
            place = { holder = ensureHolder(section), height = 0, width = 0, inStack = not saved }
            placer.sections[section] = place
            place.holder:SetFrameStrata(strata)
            place.holder:ClearAllPoints()
            if saved then
                place.holder:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
            else
                place.holder:SetPoint("BOTTOM", anchorFrame, "BOTTOM", 0, placer.totalHeight)
            end
        end
        frame:SetParent(place.holder)
        frame:SetPoint("BOTTOM", place.holder, "BOTTOM", 0, place.height)
        place.height = place.height + frame:GetHeight() + gap
        place.width = math.max(place.width, frame:GetWidth() or 0)
        if place.inStack then
            placer.last = frame
            placer.totalHeight = placer.totalHeight + frame:GetHeight() + gap
        end
    end
    function placer.Finish(holders)
        for section, holder in pairs(holders) do
            local place = placer.sections[section]
            if place then
                holder:SetSize(math.max(place.width, 1), math.max(place.height - gap, 1))
                holder:Show()
            else
                holder:Hide()
            end
        end
    end
    return placer
end

local function SnapCastBarToResourceBars()
    local cb = KT:GetModule("CastBar", true)
    if cb and cb.db and cb.db.autoPosition and cb.SnapToTop then
        cb:SnapToTop()
    end
end

function KRB:RegisterUnlockElement()
    if self.unlockElementRegistered or not KT or not KT.RegisterUnlockElement then
        return
    end

    KT.RegisterUnlockElement(KT_RB_UNLOCK_KEY, {
        label = Loc("Resource Bars"),
        group = "Resource Bars",
        order = 20,
        getFrame = function()
            return resourceAnchor
        end,
        getSize = function()
            if resourceAnchor and resourceAnchor.GetWidth and resourceAnchor.GetHeight then
                return math.max(resourceAnchor:GetWidth() or 1, 120), math.max(resourceAnchor:GetHeight() or 1, 18)
            end
            return GetResourceBarsUnlockFallbackSize()
        end,
        -- The stack grows upwards from its bottom edge: keep that edge where
        -- the mover drops it, so a bar shown, hidden or detached later moves
        -- the top of the stack and not the bars already in place.
        translateMoverPosition = function(_, pos)
            if not resourceAnchor then return pos end
            local ratio = UIParent:GetEffectiveScale() / resourceAnchor:GetEffectiveScale()
            return {
                point = "BOTTOMLEFT",
                relativePoint = "BOTTOMLEFT",
                x = pos.x or 0,
                y = (pos.y or 0) + UIParent:GetHeight() * ratio - (resourceAnchor:GetHeight() or 0),
                scale = pos.scale,
            }
        end,
        loadPosition = function()
            local editMode = KT.db and KT.db.profile and KT.db.profile.editMode
            local frames = editMode and editMode.frames
            local saved = frames and frames[KT_RB_UNLOCK_KEY]
            if saved and saved.point then
                return saved
            end
            return nil
        end,
        savePosition = function(_, point, relativePoint, x, y, scale)
            KT.db.profile.editMode = KT.db.profile.editMode or {}
            KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}
            KT.db.profile.editMode.frames[KT_RB_UNLOCK_KEY] = {
                point = point,
                relativePoint = relativePoint or point,
                x = x or 0,
                y = y or 0,
                scale = scale or (resourceAnchor and resourceAnchor:GetScale()) or 1,
            }
            self:BuildBars()
            local cb = KT:GetModule("CastBar", true)
            if cb and cb.db and cb.db.autoPosition and cb.SnapToTop then
                cb:SnapToTop()
            end
        end,
        applyPosition = function()
            self:BuildBars()
            local cb = KT:GetModule("CastBar", true)
            if cb and cb.db and cb.db.autoPosition and cb.SnapToTop then
                cb:SnapToTop()
            end
        end,
        revertPendingPosition = function()
            self:BuildBars()
            SnapCastBarToResourceBars()
        end,
        -- Reset: the stack goes back to following the Cooldown Manager.
        resetPosition = function()
            local editMode = KT.db and KT.db.profile and KT.db.profile.editMode
            if editMode and editMode.frames then editMode.frames[KT_RB_UNLOCK_KEY] = nil end
            self:BuildBars()
            SnapCastBarToResourceBars()
            return true
        end,
        isHidden = function()
            local db = GetSafeDB()
            return not (db and ((db.health and db.health.enabled) or (db.primary and db.primary.enabled) or (db.secondary and db.secondary.enabled)))
        end,
    })

    for index, entry in ipairs(DETACH_SECTIONS) do
        local section, unlockKey = entry.key, DetachUnlockKey(entry.key)
        KT.RegisterUnlockElement(unlockKey, {
            label = Loc("Resource Bars") .. ": " .. Loc(entry.label),
            group = "Resource Bars",
            order = 20 + index,
            getFrame = function()
                return EnsureDetachHolder(section)
            end,
            getSize = function()
                local holder = detachHolders[section]
                if holder and holder.GetWidth and holder.GetHeight then
                    return math.max(holder:GetWidth() or 1, 60), math.max(holder:GetHeight() or 1, 8)
                end
                return 120, 18
            end,
            loadPosition = function()
                return GetDetachedPosition(section)
            end,
            savePosition = function(_, point, relativePoint, x, y, scale)
                KT.db.profile.editMode = KT.db.profile.editMode or {}
                KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}
                KT.db.profile.editMode.frames[unlockKey] = {
                    point = point,
                    relativePoint = relativePoint or point,
                    x = x or 0,
                    y = y or 0,
                    scale = scale or 1,
                }
                self:BuildBars()
                SnapCastBarToResourceBars()
            end,
            applyPosition = function()
                self:BuildBars()
                SnapCastBarToResourceBars()
            end,
            -- Discard: a rebuild during the drag may have closed the stack
            -- gap; rebuild from the saved positions (pending is wiped by now).
            revertPendingPosition = function()
                self:BuildBars()
                SnapCastBarToResourceBars()
            end,
            resetPosition = function()
                local editMode = KT.db and KT.db.profile and KT.db.profile.editMode
                if editMode and editMode.frames then editMode.frames[unlockKey] = nil end
                self:BuildBars()
                SnapCastBarToResourceBars()
                return true
            end,
            isHidden = function()
                local db = GetSafeDB()
                return not (db and db.enabled ~= false and IsDetached(db, section) and IsSectionEnabled(db, section))
            end,
        })
    end

    self.unlockElementRegistered = true
end


local function EnsureResourceAnchor(width, height, fallbackAnchor, gap, xOffset, strata)
    if not resourceAnchor then
        resourceAnchor = CreateFrame("Frame", "KUI_ResourceBarsAnchor", UIParent)
        resourceAnchor:SetClampedToScreen(true)
        resourceAnchor.KT_IsResourceBarsAnchor = true
        _G.KUI_ResourceBarsAnchor = resourceAnchor
    end

    resourceAnchor:SetFrameStrata(strata or "MEDIUM")
    resourceAnchor:SetSize(width or 1, height or 1)
    KRB:RegisterUnlockElement()

    -- A stack moved in Unlock Mode stays where it was put (a drag not yet
    -- saved included); otherwise it sits on top of the Cooldown Manager.
    local saved = GetUnlockPosition(KT_RB_UNLOCK_KEY)
    if saved then
        resourceAnchor:ClearAllPoints()
        resourceAnchor:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    elseif fallbackAnchor and fallbackAnchor.GetPoint and fallbackAnchor:GetPoint(1) then
        resourceAnchor:ClearAllPoints()
        resourceAnchor:SetPoint("BOTTOM", fallbackAnchor, "TOP", xOffset or 0, gap or 4)
    else
        resourceAnchor:ClearAllPoints()
        resourceAnchor:SetPoint("CENTER", UIParent, "CENTER", xOffset or 0, -160)
    end

    resourceAnchor:Show()
    return resourceAnchor
end

-------------------------------------------------------------------------------
--  Combat Visibility
-------------------------------------------------------------------------------
local function UpdateCombatVisibility(event)
    local db = GetSafeDB()
    -- InCombatLockdown() is still false while PLAYER_REGEN_DISABLED fires.
    local inCombat
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    else
        inCombat = InCombatLockdown()
    end
    if KRB.UpdateSwingVisibility then KRB:UpdateSwingVisibility(db, inCombat) end
    local shouldShow = not db.general.hideOOC or inCombat
    local ppType = GetPrimaryPowerType()
    local hidePrimaryMana = (IsManaHiddenForCurrentSpec(db) and ppType == PT.MANA)

    if secondaryFrame then
        if shouldShow and db.secondary.enabled and GetSecondaryResource() then
            secondaryFrame:SetAlpha(db.secondary.barAlpha or 1)
        else
            secondaryFrame:SetAlpha(0)
        end
    end

    if primaryBar then
        if shouldShow and db.primary.enabled and not hidePrimaryMana then
            primaryBar:SetAlpha(db.primary.barAlpha or 1)
        else
            primaryBar:SetAlpha(0)
        end
    end

    if extraManaBar then
        if shouldShow and ShouldShowExtraMana(db, ppType) then
            extraManaBar:SetAlpha(db.primary.barAlpha or 1)
        else
            extraManaBar:SetAlpha(0)
        end
    end

    if healthBar then
        if shouldShow and db.health.enabled then
            healthBar:SetAlpha(db.health.barAlpha or 1)
        else
            healthBar:SetAlpha(0)
        end
    end
end

local function RB_Print(...)
    local prefix = "|cFF00FFFF[KUI ResourceBars]|r "
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    local msg = table.concat(parts, " ")
    if KT and KT.Print then
        KT:Print(prefix .. msg)
    else
        print(prefix .. msg)
    end
end

function KRB:DebugDump()
    local _, classFile = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization() or nil
    local specID = GetSpecID()
    local specName = nil
    if specIndex and GetSpecializationInfo then
        local _, name = GetSpecializationInfo(specIndex)
        specName = name
    end

    local pt, token, alt = UnitPowerType("player")
    RB_Print("class=", classFile, "specIndex=", tostring(specIndex), "specID=", tostring(specID), "specName=", tostring(specName))
    RB_Print("UnitPowerType:", tostring(pt), tostring(token), tostring(alt))
    RB_Print("Enum.PowerType.Maelstrom=", tostring(Enum and Enum.PowerType and Enum.PowerType.Maelstrom), "PT.MAELSTROM=", tostring(PT.MAELSTROM))
    RB_Print("Enum.PowerType.Mana=", tostring(Enum and Enum.PowerType and Enum.PowerType.Mana), "PT.MANA=", tostring(PT.MANA))

    local manaCur, manaMax = UnitPower("player", PT.MANA), UnitPowerMax("player", PT.MANA)
    local maeCur, maeMax = UnitPower("player", PT.MAELSTROM), UnitPowerMax("player", PT.MAELSTROM)
    RB_Print("mana:", "cur=", tostring(manaCur), "max=", tostring(manaMax), "secretCur=", tostring(IsSecret(manaCur)), "secretMax=", tostring(IsSecret(manaMax)), "safeCur=", SafeNum(manaCur, -1), "safeMax=", SafeNum(manaMax, -1))
    RB_Print("maelstrom:", "cur=", tostring(maeCur), "max=", tostring(maeMax), "secretCur=", tostring(IsSecret(maeCur)), "secretMax=", tostring(IsSecret(maeMax)), "safeCur=", SafeNum(maeCur, -1), "safeMax=", SafeNum(maeMax, -1))

    local sec = GetSecondaryResource()
    if sec then
        RB_Print("secondary:", "kind=", tostring(sec.kind), "type=", tostring(sec.type), "power=", tostring(sec.power), "max=", tostring(sec.max))
    else
        RB_Print("secondary: nil")
    end

    local function DumpBarState(label, bar)
        if not bar then
            RB_Print(label .. ":", "nil")
            return
        end
        local okMinMax, mn, mx = pcall(bar.GetMinMaxValues, bar)
        local okVal, v = pcall(bar.GetValue, bar)
        local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or nil
        local okCol, r, g, b, a = false, nil, nil, nil, nil
        if tex and tex.GetVertexColor then
            okCol, r, g, b, a = pcall(tex.GetVertexColor, tex)
        end
        RB_Print(label .. ":", "shown=", tostring(bar.IsShown and bar:IsShown()), "min=", okMinMax and tostring(mn) or "?", "max=", okMinMax and tostring(mx) or "?", "val=", okVal and tostring(v) or "?")
        RB_Print(label .. ":", "tex=", tostring(tex), "color=", okCol and string.format("%.2f %.2f %.2f %.2f", r or 0, g or 0, b or 0, a or 0) or "?")
    end

    DumpBarState("primaryBar", primaryBar)
    DumpBarState("secondaryBar", secondaryBar)
end

-------------------------------------------------------------------------------
--  VisualThemes: marco clasico opcional de 8 piezas
-------------------------------------------------------------------------------
-- Puramente decorativo: se ancla justo fuera del rect de cada barra/contenedor
-- (sin tocar backdrop, pixel border, tamano o anclajes existentes). Un unico
-- campo de perfil (db.general.frameArtKit) controla las tres barras a la vez
-- -- salud/poder primario/recurso secundario forman una sola identidad visual
-- apilada, no tres widgets independientes.
--
-- Grosor del anillo: ThemeBorderKit.lua dibuja 16px hacia FUERA del rect a
-- scale = 1 (BASE_RING_SIZE, local privado alli; se refleja aqui a proposito,
-- mantener sincronizado). Las tres barras se apilan a solo
-- db.general.anchorGap px (4 por defecto, ver StackAbove), asi que un anillo
-- de 16px por barra invadiria la barra vecina. Igual que el arreglo de CDM
-- (ComputeClassicBorderScale en KUICooldownManager.lua): el alcance del
-- anillo se limita a la mitad del hueco real, de modo que dos anillos
-- vecinos se tocan en el centro del hueco sin solaparse. Tambien se limita
-- a la mitad de los 5px con los que CastBar se auto-posiciona encima de la
-- barra superior (CastBar.lua SnapToTop), para no invadir su anillo.
local RB_CLASSIC_BORDER_BASE_RING_SIZE = 16
local RB_CLASSIC_BORDER_MAX_REACH = 5 / 2

local function ComputeClassicBorderScale(db)
    local gap = tonumber(db and db.general and db.general.anchorGap) or 4
    local reach = gap / 2
    if reach > RB_CLASSIC_BORDER_MAX_REACH then reach = RB_CLASSIC_BORDER_MAX_REACH end
    local scale = reach / RB_CLASSIC_BORDER_BASE_RING_SIZE
    if scale > 1 then scale = 1 end
    -- scale <= 0 significa "sin definir" (=1) en ThemeBorderKit.lua: se deja
    -- una linea fina en su lugar para huecos de 0 o negativos.
    if scale < 0.02 then scale = 0.02 end
    return scale
end

local function ApplyClassicFrameArt(frame, db)
    if not frame then return end
    local VT = KT.VisualThemes
    if not (VT and VT.CreateClassicBorder and VT.SeatClassicBorder and VT.ShowClassicBorder) then
        return
    end
    local wantClassic = db and db.general and db.general.frameArtKit == "classic"
    if wantClassic then
        frame.classicBorder = frame.classicBorder or VT:CreateClassicBorder(frame)
        if frame.classicBorder then
            VT:SeatClassicBorder(frame.classicBorder, frame, ComputeClassicBorderScale(db))
            VT:ShowClassicBorder(frame.classicBorder, true)
        end
    elseif frame.classicBorder then
        VT:ShowClassicBorder(frame.classicBorder, false)
    end
end

-------------------------------------------------------------------------------
--  BuildBars
-------------------------------------------------------------------------------
-- The resource and pip count a build drew, to tell when a new build is due.
function KRB:SecondaryShapeKey(sec)
    if not sec then return "none" end
    return tostring(sec.kind or sec.power) .. ":" .. tostring(sec.type) .. ":" .. tostring(sec.max)
end

function KRB:BuildBars()
    local db         = GetSafeDB()
    if db.enabled == false then
        if healthBar then healthBar:Hide() end
        if primaryBar then primaryBar:Hide() end
        if extraManaBar then extraManaBar:Hide() end
        if secondaryFrame then secondaryFrame:Hide() end
        if self.HideSwingBars then self:HideSwingBars() end
        if resourceAnchor then resourceAnchor:Hide() end
        for _, holder in pairs(detachHolders) do holder:Hide() end
        _G.KUI_ResourceBarsTop = nil
        return
    end
    self._cachedMarkerConfig = GetActiveMarkerConfig(db)
    local secondaryMarkerConfig = self._cachedMarkerConfig
    local refWidth   = GetReferenceWidth()
    local baseAnchor = GetBaseAnchor()
    local gap        = db.general.anchorGap or 4
    local xOff       = db.general.xOffset or 0
    local ppTypeNow  = GetPrimaryPowerType()
    local hidePrimaryMana = (IsManaHiddenForCurrentSpec(db) and ppTypeNow == PT.MANA)
    
    local texSec     = LSM and LSM:Fetch("statusbar", db.secondary.texture) or "Interface\\Buttons\\WHITE8x8"
    local texPri     = LSM and LSM:Fetch("statusbar", db.primary.texture) or "Interface\\Buttons\\WHITE8x8"
    local texHea     = LSM and LSM:Fetch("statusbar", db.health.texture) or "Interface\\Buttons\\WHITE8x8"
    local texSecBar  = texSec   -- pips are plain textures and keep the file texture
    -- Retail/Forever: the bars wear Blizzard's own untinted unit-frame bar art
    -- (tinted by the usual vertex colour) while the texture is still the theme's
    -- seeded default; a texture picked by hand is respected.
    do
        local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme and KT.VisualThemes:GetRenderedTheme()
        local seeded = theme == "retail" and "Blizzard Raid Bar" or theme == "forever" and "Melli Dark" or nil
        local function NativeBar(section, kind, fallback)
            if not (seeded and section and section.texture == seeded and C_Texture and C_Texture.GetAtlasInfo) then
                return fallback
            end
            for _, owner in ipairs({ "Player", "Party" }) do
                local atlas = "UI-HUD-UnitFrame-" .. owner .. "-PortraitOn-Bar-" .. kind .. "-Status"
                if C_Texture.GetAtlasInfo(atlas) then return atlas end
            end
            return fallback
        end
        texPri = NativeBar(db.primary, "Mana", texPri)
        texSecBar = NativeBar(db.secondary, "Mana", texSec)
        texHea = NativeBar(db.health, "Health", texHea)
    end

    local anchorFrame = EnsureResourceAnchor(refWidth, 1, baseAnchor, gap, xOff, db.general.strata or "MEDIUM")
    local placer = NewStackPlacer(anchorFrame, db, gap, EnsureDetachHolder, GetDetachedPosition)
    local StackAbove = placer.Place

    -- ── 1. Recurso Secundario ─────────────────────────────────────────────
    local sec = GetSecondaryResource()
    local comboResourcePips = IsComboSecondaryResource(sec)
    local pipLook = ResolvePipLook(db, sec)
    self._ktPipLook = pipLook
    -- What was built: UNIT_MAXPOWER rebuilds when the resource or its pip count changes.
    self._ktBuiltSecKey = self:SecondaryShapeKey(sec)
    if db.secondary.enabled and sec then
        if not secondaryFrame then
            secondaryFrame = CreateFrame("Frame", "KUI_SecondaryFrame", UIParent)
        end

        local secW = refWidth
        if db.general.matchCooldownWidth then secW = refWidth
        else secW = db.general.manualWidth or 250 end

        -- Pieces and combo points stand taller than the Height: the stack makes room.
        local secH = db.secondary.pipHeight or 14
        if sec.type ~= "bar" and ns.PipArt then
            local _, artH = ns.PipArt.Geometry(pipLook.style, secH, 0, pipLook.piece, pipLook.combo)
            secH = max(secH, artH or secH)
        end
        secondaryFrame:SetSize(secW, secH)
        StackAbove(secondaryFrame, "secondary")

        if sec.type == "bar" then
            for i = 1, #pips do if pips[i] then pips[i]:Hide() end end
            
            if not secondaryBar then
                secondaryBar = CreateStatusBar(secondaryFrame, "KUI_SecondaryBar")
            end
            secondaryBar:SetSize(secW, db.secondary.pipHeight or 14)
            secondaryBar:ClearAllPoints()
            secondaryBar:SetPoint("CENTER", secondaryFrame, "CENTER")
            
            secondaryBar:SetStatusBarTexture(texSecBar)
            secondaryBar._bg:SetColorTexture(0.07, 0.07, 0.07, db.general.bgA)
            
            if sec.kind == "stagger" and NormalizeColorMode(db.secondary.colorMode, db.secondary.classColor) == "power" then
                local stag = SafeNum(UnitStagger and UnitStagger("player"), 0)
                local hm = SafeNum(UnitHealthMax("player"), 0)
                local r, g, b, a = GetStaggerBarColor(stag, hm, db.secondary.fillA or 1)
                secondaryBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
            else
                local r, g, b, a = ResolveSectionColor(db.secondary, sec.power, db.secondary.fillA or 1)
                secondaryBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
            end
            
            secondaryBar:SetAlpha(db.secondary.barAlpha or 1)
            secondaryBar._border:SetSize(db.secondary.borderSize)
            secondaryBar._border:SetShown(db.secondary.borderSize > 0)
            secondaryBar._text:SetFont(GetRBFont(), SafeNum(db.secondary.textSize, 13), "OUTLINE")
            secondaryBar:Show()
            local markerMax = 0
            if sec.kind == "stagger" then
                markerMax = SafeNum(UnitHealthMax("player"), 0)
            else
                markerMax = SafeNum(sec.max, SafeNum(UnitPowerMax("player", sec.power), 0))
            end
            if ShouldRenderMarkersOnSecondary(secondaryMarkerConfig, sec) then
                UpdateMarkers(secondaryBar, secondaryMarkerConfig, markerMax)
            else
                HideMarkers(secondaryBar)
            end
        else
            if secondaryBar then
                HideMarkers(secondaryBar)
                secondaryBar:Hide()
            end
            
            -- A profile saved before pipSpacing existed has no such key, and the
            -- raw db.secondary.pipSpacing read then threw on arithmetic during
            -- BuildBars. Resolve it once, defensively, and reuse it below.
            local pipSpacing = SafeNum(db.secondary.pipSpacing, 2)
            local baseH = db.secondary.pipHeight or 14
            local pipW = (secW - (pipSpacing * (sec.max - 1))) / sec.max
            local pipH = baseH
            local clusterOffsetX = 0
            -- Round pips, pieces and combo points keep their own proportions: they are
            -- sized from the Height and clustered at the centre instead of spread
            -- across the whole width (a stretched circle mask turns into an oval).
            local look = pipLook
            local fixedW, fixedH, fixedSpacing = nil, baseH, pipSpacing
            if ns.PipArt then
                fixedW, fixedH, fixedSpacing = ns.PipArt.Geometry(look.style, baseH, pipSpacing, look.piece, look.combo)
            elseif look.round then
                fixedW, fixedH = baseH * 1.15, baseH * 1.15
            end
            if look.round then
                -- Round pips switch off the theme's bar strip texture; see
                -- ResolvePipTexture for why.
                texSec = ResolvePipTexture(db, true)
            end
            if fixedW then
                pipW, pipH, pipSpacing = fixedW, fixedH, fixedSpacing
                local clusterW = pipW * sec.max + pipSpacing * (sec.max - 1)
                clusterOffsetX = math.max(0, (secW - clusterW) / 2)
            end
            local tintPieces = NormalizeColorMode(db.secondary.colorMode, db.secondary.classColor) ~= "power"
            for i = 1, sec.max do
                if not pips[i] then
                    pips[i] = CreateFrame("Frame", nil, secondaryFrame)
                    pips[i]._bg   = pips[i]:CreateTexture(nil, "BACKGROUND")
                    pips[i]._bg:SetAllPoints()
                    pips[i]._fill = pips[i]:CreateTexture(nil, "ARTWORK")
                    pips[i]._fill:SetAllPoints()
                    pips[i]._border = MakePixelBorder(pips[i], 0, 0, 0, 1, 1)
                end
                local pip = pips[i]
                local x = clusterOffsetX + (i - 1) * (pipW + pipSpacing)
                pip:SetSize(pipW, pipH)
                pip:ClearAllPoints()
                pip:SetPoint("LEFT", secondaryFrame, "LEFT", x, 0)
                HidePartialPip(pip)

                local r, g, b, a = ResolveSecondaryPipColor(db, sec, i, db.secondary.fillA or 1)
                if look.piece or look.combo then
                    -- The resource's own piece: no flat fill, background or pixel border.
                    ApplyResourcePipShape(pip, false, false)
                    pip._bg:SetColorTexture(0, 0, 0, 0)
                    pip._fill:Hide()
                    pip._ktActive = nil
                    pip._border:SetShown(false)
                    local tinted = tintPieces or GetSecondaryPipColorOverride(db, sec, i) ~= nil
                    if look.piece then
                        if tinted then
                            ns.PipArt.ApplyPiece(pip, look.piece, i, r, g, b)
                        else
                            ns.PipArt.ApplyPiece(pip, look.piece, i)
                        end
                    else
                        ns.PipArt.ApplyCombo(pip, look.combo)
                    end
                    pip._ktArtTint = tinted
                    pip._ktColorR, pip._ktColorG, pip._ktColorB, pip._ktColorA = r, g, b, a
                else
                    if ns.PipArt then ns.PipArt.Clear(pip) end
                    ApplyResourcePipShape(pip, look.round, comboResourcePips)
                    pip._bg:SetColorTexture(comboResourcePips and 0.22 or 0.07, comboResourcePips and 0.02 or 0.07, comboResourcePips and 0.02 or 0.07, db.general.bgA)
                    pip._fill:SetTexture(texSec)
                    if comboResourcePips then r, g, b, a = 1.0, 0.05, 0.05, db.secondary.fillA or 1 end
                    pip._fill:SetVertexColor(r, g, b, a)
                    pip._border:SetSize(db.secondary.borderSize)
                    pip._border:SetShown(db.secondary.borderSize > 0 and not look.round)
                end

                pip:SetAlpha(db.secondary.barAlpha or 1)
                pip:Show()
            end
            for i = sec.max + 1, #pips do
                if pips[i] then pips[i]:Hide() end
            end
        end
        
        secondaryFrame:Show()
    elseif secondaryFrame then
        if secondaryBar then
            HideMarkers(secondaryBar)
        end
        secondaryFrame:Hide()
    end

    -- ── 2. Barra de Poder Primario ────────────────────────────────────────
    if db.primary.enabled and not hidePrimaryMana then
        if not primaryBar then
            primaryBar = CreateStatusBar(anchorFrame, "KUI_PrimaryBar")
        end
        primaryBar:SetSize(refWidth, db.primary.height or 25)
        StackAbove(primaryBar, "primary")
        primaryBar:SetStatusBarTexture(texPri)
        primaryBar._bg:SetColorTexture(0.07, 0.07, 0.07, db.general.bgA)
        
        local r, g, b, a = ResolveSectionColor(db.primary, ppTypeNow, db.primary.fillA or 1)
        primaryBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
        
        primaryBar:SetAlpha(db.primary.barAlpha or 1)
        primaryBar._border:SetSize(db.primary.borderSize)
        primaryBar._border:SetShown(db.primary.borderSize > 0)
        primaryBar._text:SetFont(GetRBFont(), SafeNum(db.primary.textSize, 13), "OUTLINE")
        primaryBar:Show()
        HideMarkers(primaryBar)
    elseif primaryBar then
        HideMarkers(primaryBar)
        primaryBar:Hide()
    end

    -- ── 2b. Extra Mana Bar (above the primary resource) ──────────────────
    if ShouldShowExtraMana(db, ppTypeNow) then
        if not extraManaBar then
            extraManaBar = CreateStatusBar(anchorFrame, "KUI_ExtraManaBar")
        end
        local manaH = SafeNum(db.primary.extraManaHeight, 10)
        extraManaBar:SetSize(refWidth, manaH)
        StackAbove(extraManaBar, "extraMana")
        extraManaBar:SetStatusBarTexture(texPri)
        extraManaBar._bg:SetColorTexture(0.07, 0.07, 0.07, db.general.bgA)
        local r, g, b, a = ResolveExtraManaColor(db)
        extraManaBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
        extraManaBar:SetAlpha(db.primary.barAlpha or 1)
        extraManaBar._border:SetSize(db.primary.borderSize)
        extraManaBar._border:SetShown(db.primary.borderSize > 0)
        -- A thin bar keeps its text no taller than itself.
        extraManaBar._text:SetFont(GetRBFont(), min(SafeNum(db.primary.textSize, 13), max(8, manaH)), "OUTLINE")
        extraManaBar._ktTextLast, extraManaBar._ktMaxValue = nil, nil
        extraManaBar:Show()
    elseif extraManaBar then
        extraManaBar:Hide()
    end

    -- ── 3. Barra de Salud ────────────────────────────────────────────────
    if db.health.enabled then
        if not healthBar then
            healthBar = CreateStatusBar(anchorFrame, "KUI_HealthBar")
        end
        healthBar:SetSize(refWidth, db.health.height or 25)
        StackAbove(healthBar, "health")
        healthBar:SetStatusBarTexture(texHea)
        healthBar._bg:SetColorTexture(0.07, 0.07, 0.07, db.general.bgA)
        healthBar:GetStatusBarTexture():SetVertexColor(
            SafeNum(db.health.fillR, 0.15), SafeNum(db.health.fillG, 0.75),
            SafeNum(db.health.fillB, 0.30), SafeNum(db.health.fillA, 1))
        healthBar:SetAlpha(db.health.barAlpha or 1)
        healthBar._border:SetSize(db.health.borderSize)
        healthBar._border:SetShown(db.health.borderSize > 0)
        healthBar._text:SetFont(GetRBFont(), SafeNum(db.health.textSize, 13), "OUTLINE")
        healthBar:Show()
    elseif healthBar then
        healthBar:Hide()
    end

    if self.BuildSwingBars then self:BuildSwingBars(db, refWidth, StackAbove) end

    placer.Finish(detachHolders)
    anchorFrame:SetSize(refWidth, max(placer.totalHeight - gap, 1))
    anchorFrame:SetShown(placer.totalHeight > gap or (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()))

    -- VisualThemes: un unico interruptor (db.general.frameArtKit)
    -- decide el marco clasico de las tres barras. secondaryFrame es el
    -- contenedor tanto en modo barra como en modo pips, asi que un solo
    -- marco alrededor de el cubre ambos sin depender de cuantos pips haya.
    ApplyClassicFrameArt(healthBar, db)
    ApplyClassicFrameArt(primaryBar, db)
    ApplyClassicFrameArt(extraManaBar, db)
    ApplyClassicFrameArt(secondaryFrame, db)

    _G.KUI_ResourceBarsTop = placer.last
    SyncResourceBarMovers()

    do
        local interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
        local smooth = interp and db.general.smoothBars ~= false and interp or nil
        for _, bar in ipairs({ healthBar or false, primaryBar or false, extraManaBar or false, secondaryBar or false }) do
            if bar then bar._ktSmooth = smooth end
        end
    end

    self:UpdateBars()
    UpdateCombatVisibility()
end

-------------------------------------------------------------------------------
--  UpdateBars
-------------------------------------------------------------------------------
-- The health / resource numbers count to each new value with their bar (General >
-- Smooth Bars) instead of jumping a step per event. Secret values pass through.
local RenderHealthText, RenderPowerText
local SmoothText = KT.SmoothNumbers and KT.SmoothNumbers.NewChannel(function(moving)
    local db = GetSafeDB()
    if moving.hp and healthBar and healthBar:IsShown() then
        RenderHealthText(db, UnitHealth("player"), UnitHealthMax("player"))
    end
    if moving.pp and primaryBar and primaryBar:IsShown() then
        local powerType = GetPrimaryPowerType()
        RenderPowerText(primaryBar, "pp", db, powerType, UnitPower("player", powerType), UnitPowerMax("player", powerType))
    end
    if moving.mana and extraManaBar and extraManaBar:IsShown() then
        RenderPowerText(extraManaBar, "mana", db, PT.MANA, UnitPower("player", PT.MANA), UnitPowerMax("player", PT.MANA))
    end
end, function()
    local db = GetRawResourceBarsDB()
    return not (db and db.general and db.general.smoothBars == false)
end)

-- The number to show for `key`, and its whole percent while it is counting (nil once
-- it settles, so the client's own percent is shown).
local function CountingValue(key, raw, maxRaw, identity)
    if not SmoothText then return raw, nil end
    local shown = SmoothText:Value(key, raw, identity)
    if not SmoothText:IsMoving(key) or IsSecret(maxRaw) or type(maxRaw) ~= "number" or maxRaw <= 0 then
        return shown, nil
    end
    return shown, tostring(floor(shown / maxRaw * 100))
end

local function SetBarText(bar, fmt, txt)
    local secretTxt = IsSecret(txt)
    if fmt ~= bar._ktTextFmt or secretTxt or txt ~= bar._ktTextLast then
        bar._text:SetText(txt)
        bar._ktTextFmt = fmt
        if secretTxt then bar._ktTextLast = nil else bar._ktTextLast = txt end
    end
end

RenderHealthText = function(db, hpRaw, mxRaw)
    local fmt = db.health.textFormat
    local shown, countingPct = CountingValue("hp", hpRaw, mxRaw, "player")
    local pctStr = countingPct or GetHealthPctStr("player") or GetSafePct(hpRaw, mxRaw)
    local txt
    if fmt == "both" then
        txt = FormatCurSafe(shown) .. " - " .. pctStr .. "%"
    elseif fmt == "perhp" then
        txt = pctStr .. "%"
    elseif fmt == "curhpshort" then
        txt = FormatCurSafe(shown)
    elseif fmt == "curhpfull" then
        txt = FormatFullSafe(shown)
    else
        txt = ""
    end
    SetBarText(healthBar, fmt, txt)
end

-- FormatCur abbreviates (250K instead of 250000).
RenderPowerText = function(bar, key, db, powerType, ppRaw, mxRaw)
    local fmt = db.primary.textFormat
    local shown, countingPct = CountingValue(key, ppRaw, mxRaw, powerType)
    local pctStr = countingPct or GetPowerPctStr("player", powerType) or GetSafePct(ppRaw, mxRaw)
    local ppShown = KT.PowerDisplayValue(shown, "player", powerType)
    local txt
    if fmt == "both" then
        txt = FormatCurSafe(ppShown) .. " - " .. pctStr .. "%"
    elseif fmt == "perpp" then
        txt = pctStr .. "%"
    elseif fmt == "curpp" then
        txt = FormatCurSafe(ppShown)
    elseif fmt == "curppfull" then
        txt = FormatFullSafe(ppShown)
    else
        txt = ""
    end
    SetBarText(bar, fmt, txt)
end

function KRB:UpdateBars(event, unit)
    -- UNIT_* handlers pass a unit token; rune handlers pass a numeric rune
    -- index in the same argument position and must not be filtered out.
    if type(unit) == "string" and unit ~= "player" then return end
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        local frameStamp = GetTime()
        if self._ktPowerFrameStamp == frameStamp then return end
        self._ktPowerFrameStamp = frameStamp
    end
    local db = GetSafeDB()
    local fullUpdate = event == nil
    local updateHealth = fullUpdate or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH"
    local updatePrimary = fullUpdate or event == "UNIT_POWER_UPDATE"
        or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER"
    local updateSecondary = fullUpdate or event == "UNIT_POWER_UPDATE"
        or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER"
        or event == "UNIT_MAXHEALTH"
        or event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE"
        or event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED"
        or event == "UNIT_AURA"
        or (event == "UNIT_HEALTH" and self._ktSecStagger)   -- stagger derives from health
    local secondaryMarkerConfig = (updatePrimary or updateSecondary)
        and (self._cachedMarkerConfig or GetActiveMarkerConfig(db)) or nil
    local ppTypeNow = updatePrimary and GetPrimaryPowerType() or nil
    local hidePrimaryMana = updatePrimary
        and (IsManaHiddenForCurrentSpec(db) and ppTypeNow == PT.MANA)
    local sec = (updatePrimary or updateSecondary) and GetSecondaryResource() or nil
    if sec ~= nil or updateSecondary then self._ktSecStagger = sec and sec.kind == "stagger" or false end
    -- A maximum that changes the resource or its pip count (a level unlocking Holy Power,
    -- a talent adding a pip) needs a new build, not just a repaint.
    if event == "UNIT_MAXPOWER" and self._ktBuiltSecKey ~= nil
        and self._ktBuiltSecKey ~= self:SecondaryShapeKey(GetSecondaryResource()) then
        return self:BuildBars()
    end
    local pipLook = self._ktPipLook or ResolvePipLook(db, sec)
    local roundResourcePips = pipLook.round
    local comboResourcePips = IsComboSecondaryResource(sec)
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileName = updateHealth and not updatePrimary and "resources.health.paint"
        or updatePrimary and not updateHealth and not updateSecondary and "resources.power.paint"
        or updateSecondary and not updateHealth and not updatePrimary and "resources.secondary.paint"
        or "resources.mixed.paint"
    local profileStarted = profiler and profiler:Begin(profileName)

    if updateHealth and healthBar and healthBar:IsShown() then
        local hpRaw = UnitHealth("player")
        local mxRaw = UnitHealthMax("player")
        local mx    = SafeNum(mxRaw, 1)
        if mx > 0 then
            local maxSecret = IsSecret(mxRaw)
            if fullUpdate or event == "UNIT_MAXHEALTH" or maxSecret or healthBar._ktMaxValue ~= mxRaw then
                SetStatusBarMinMaxSafe(healthBar, 0, mxRaw)
                if maxSecret then healthBar._ktMaxValue = nil else healthBar._ktMaxValue = mxRaw end
            end
            SetStatusBarValueSafe(healthBar, hpRaw)
            RenderHealthText(db, hpRaw, mxRaw)
        end
    end

    if updatePrimary and primaryBar and primaryBar:IsShown() and not hidePrimaryMana then
        local ppRaw  = UnitPower("player", ppTypeNow)
        local mxRaw  = UnitPowerMax("player", ppTypeNow)
        local mx     = SafeNum(mxRaw, 1)
        
        do
            local r, g, b, a = ResolveSectionColor(db.primary, ppTypeNow, db.primary.fillA or 1)
            if fullUpdate or primaryBar._ktColorR ~= r or primaryBar._ktColorG ~= g
                or primaryBar._ktColorB ~= b or primaryBar._ktColorA ~= a then
                primaryBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
                primaryBar._ktColorR, primaryBar._ktColorG = r, g
                primaryBar._ktColorB, primaryBar._ktColorA = b, a
            end
        end
        
        if mx > 0 then
            local maxSecret = IsSecret(mxRaw)
            if fullUpdate or event == "UNIT_MAXPOWER" or maxSecret or primaryBar._ktMaxValue ~= mxRaw then
                SetStatusBarMinMaxSafe(primaryBar, 0, mxRaw)
                if maxSecret then primaryBar._ktMaxValue = nil else primaryBar._ktMaxValue = mxRaw end
            end
            SetStatusBarValueSafe(primaryBar, ppRaw)
            RenderPowerText(primaryBar, "pp", db, ppTypeNow, ppRaw, mxRaw)

            -- Custom markers are configured under the "Class Resource" section.
            -- When that class-resource becomes the primary power bar (e.g. Moonkin Astral Power),
            -- or when the primary bar is shown without a secondary "bar" resource,
            -- we still want the same custom markers to render.
            if ShouldRenderMarkersOnPrimary(secondaryMarkerConfig, ppTypeNow, sec) then
                if fullUpdate or event == "UNIT_MAXPOWER"
                    or primaryBar._ktMarkerMax ~= mx
                    or primaryBar._ktMarkerConfig ~= secondaryMarkerConfig then
                    UpdateMarkers(primaryBar, secondaryMarkerConfig, mx)
                    primaryBar._ktMarkerMax = mx
                    primaryBar._ktMarkerConfig = secondaryMarkerConfig
                end
            else
                HideMarkers(primaryBar)
                primaryBar._ktMarkerMax = nil
                primaryBar._ktMarkerConfig = nil
            end
        else
            HideMarkers(primaryBar)
            primaryBar._ktMarkerMax = nil
            primaryBar._ktMarkerConfig = nil
        end
    end

    if updatePrimary and extraManaBar and extraManaBar:IsShown() then
        local mpRaw = UnitPower("player", PT.MANA)
        local mxRaw = UnitPowerMax("player", PT.MANA)
        if IsSecret(mxRaw) or SafeNum(mxRaw, 0) > 0 then
            local maxSecret = IsSecret(mxRaw)
            if fullUpdate or event == "UNIT_MAXPOWER" or maxSecret or extraManaBar._ktMaxValue ~= mxRaw then
                SetStatusBarMinMaxSafe(extraManaBar, 0, mxRaw)
                if maxSecret then extraManaBar._ktMaxValue = nil else extraManaBar._ktMaxValue = mxRaw end
            end
            SetStatusBarValueSafe(extraManaBar, mpRaw)
            -- Same text as the primary bar (Resource Text).
            RenderPowerText(extraManaBar, "mana", db, PT.MANA, mpRaw, mxRaw)
        end
    end

    if updateSecondary and secondaryFrame and secondaryFrame:IsShown() then
        if sec then
            local ppRaw, ppNum
            local recharge = KT.ResourceRecharge
            local timedPips = false
            if sec.kind == "runes" then
                -- Runes aren't a typical "power" bar; count ready runes via cooldown API for reliable updates.
                local ready = 0
                local maxRunes = (sec.max and sec.max > 0) and sec.max or 6
                local sorted = recharge and recharge.ReadRunes(maxRunes)
                if sorted then
                    ready = sorted
                    timedPips = true
                elseif GetRuneCooldown then
                    for i = 1, maxRunes do
                        local _, _, runeReady = GetRuneCooldown(i)
                        if runeReady then
                            ready = ready + 1
                        end
                    end
                else
                    -- Fallback: some clients expose runes as UnitPower(Enum.PowerType.Runes).
                    ready = SafeNum(UnitPower("player", sec.power), 0)
                end
                ppRaw = ready
                ppNum = ready
            elseif sec.kind == "stagger" then
                ppRaw = SafeNum(UnitStagger and UnitStagger("player"), 0)
                ppNum = SafeNum(ppRaw, 0)
            elseif sec.kind == "aura" then
                ppRaw = GetAuraStacksBySpellIDs("player", sec.auraSpellIDs)
                ppNum = SafeNum(ppRaw, 0)
            elseif sec.kind == "soulFragments" then
                local readCount = C_Spell and C_Spell.GetSpellCastCount
                ppRaw = readCount and readCount(VENGEANCE_SOUL_CLEAVE) or 0
                ppNum = SafeNum(ppRaw, 0)
            elseif sec.kind == "tip" then
                ppRaw = KT:GetTipOfTheSpear()
                ppNum = SafeNum(ppRaw, 0)
            elseif sec.kind == "whirlwind" then
                ppRaw = KT:GetWhirlwindStacks()
                ppNum = SafeNum(ppRaw, 0)
            elseif sec.kind == "devourer" then
                ppRaw = GetDevourerProgress()
                ppNum = SafeNum(ppRaw, 0)
            else
                ppRaw = UnitPower("player", sec.power)
                ppNum = SafeNum(ppRaw, 0)
            end
            if sec.max and sec.max > 0 and ppNum > sec.max then ppNum = sec.max end
            if recharge and sec.power == PT.ESSENCE and not IsSecret(ppRaw) then
                recharge.ReadEssence(ppNum, sec.max)
                timedPips = true
            end
            
            if sec.type == "bar" then
                if secondaryBar then
                    local mxRaw, mx
                    if sec.kind == "stagger" then
                        mxRaw = UnitHealthMax("player")
                        mx = SafeNum(mxRaw, 1)
                        if mx <= 0 then mx = 1 end
                        local maxSecret = IsSecret(mxRaw)
                        if fullUpdate or event == "UNIT_MAXHEALTH" or maxSecret or secondaryBar._ktMaxValue ~= mxRaw then
                            local maxForBar = mxRaw
                            if not maxSecret and type(maxForBar) ~= "number" then maxForBar = mx end
                            SetStatusBarMinMaxSafe(secondaryBar, 0, maxForBar)
                            if maxSecret then secondaryBar._ktMaxValue = nil else secondaryBar._ktMaxValue = mxRaw end
                        end
                        SetStatusBarValueSafe(secondaryBar, ppRaw)

                        local r, g, b, a
                        if NormalizeColorMode(db.secondary.colorMode, db.secondary.classColor) == "power" then
                            r, g, b, a = GetStaggerBarColor(ppRaw, mx, db.secondary.fillA or 1)
                        else
                            r, g, b, a = ResolveSectionColor(db.secondary, sec.power, db.secondary.fillA or 1)
                        end
                        secondaryBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
                    else
                        if sec.kind == "devourer" then
                            local _, devourerMax = GetDevourerProgress()
                            mxRaw = devourerMax
                        else
                            mxRaw = UnitPowerMax("player", sec.power)
                        end
                        mx = SafeNum(mxRaw, sec.max or 100)
                        if mx <= 0 then mx = sec.max or 100 end
                        local maxSecret = IsSecret(mxRaw)
                        if fullUpdate or event == "UNIT_MAXPOWER" or maxSecret or secondaryBar._ktMaxValue ~= mxRaw then
                            local maxForBar = mxRaw
                            if not maxSecret and type(maxForBar) ~= "number" then maxForBar = mx end
                            SetStatusBarMinMaxSafe(secondaryBar, 0, maxForBar)
                            if maxSecret then secondaryBar._ktMaxValue = nil else secondaryBar._ktMaxValue = mxRaw end
                        end
                        SetStatusBarValueSafe(secondaryBar, ppRaw)

                        local r, g, b, a = ResolveSectionColor(db.secondary, sec.power, db.secondary.fillA or 1)
                        if fullUpdate or secondaryBar._ktColorR ~= r or secondaryBar._ktColorG ~= g
                            or secondaryBar._ktColorB ~= b or secondaryBar._ktColorA ~= a then
                            secondaryBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
                            secondaryBar._ktColorR, secondaryBar._ktColorG = r, g
                            secondaryBar._ktColorB, secondaryBar._ktColorA = b, a
                        end
                    end
                    
                    local secondaryText = db.secondary.showText and FormatCurSafe(KT.PowerDisplayValue(ppRaw, "player", sec.power)) or ""
                    local secretText = IsSecret(secondaryText)
                    if secretText or secondaryBar._ktTextLast ~= secondaryText then
                        secondaryBar._text:SetText(secondaryText)
                        if secretText then secondaryBar._ktTextLast = nil else secondaryBar._ktTextLast = secondaryText end
                    end

                    if ShouldRenderMarkersOnSecondary(secondaryMarkerConfig, sec) then
                        if fullUpdate or event == "UNIT_MAXPOWER" or event == "UNIT_MAXHEALTH"
                            or secondaryBar._ktMarkerMax ~= mx
                            or secondaryBar._ktMarkerConfig ~= secondaryMarkerConfig then
                            UpdateMarkers(secondaryBar, secondaryMarkerConfig, mx)
                            secondaryBar._ktMarkerMax = mx
                            secondaryBar._ktMarkerConfig = secondaryMarkerConfig
                        end
                    else
                        HideMarkers(secondaryBar)
                        secondaryBar._ktMarkerMax = nil
                        secondaryBar._ktMarkerConfig = nil
                    end
                end
            else
                if secondaryBar then
                    HideMarkers(secondaryBar)
                end
                local PipArt = ns.PipArt
                local partialIndex, partialFraction
                if not IsSecret(ppRaw) then partialIndex, partialFraction = GetPartialShard(sec) end
                local tintPieces = NormalizeColorMode(db.secondary.colorMode, db.secondary.classColor) ~= "power"
                for i = 1, sec.max do
                    local pip = pips[i]
                    if pip then
                        local art = pip._ktArt
                        if not art then ApplyResourcePipShape(pip, roundResourcePips, comboResourcePips) end
                        local r, g, b, a = ResolveSecondaryPipColor(db, sec, i, db.secondary.fillA or 1)
                        if comboResourcePips and not art then r, g, b, a = 1.0, 0.05, 0.05, db.secondary.fillA or 1 end
                        if fullUpdate or pip._ktColorR ~= r or pip._ktColorG ~= g
                            or pip._ktColorB ~= b or pip._ktColorA ~= a then
                            if art and pipLook.piece and PipArt then
                                -- A new spec / custom colour re-tints the piece.
                                if pip._ktArtTint then
                                    PipArt.ApplyPiece(pip, pipLook.piece, i, r, g, b)
                                else
                                    PipArt.ApplyPiece(pip, pipLook.piece, i)
                                end
                                pip._ktActive = nil
                            elseif not art then
                                pip._fill:SetVertexColor(r, g, b, a)
                            end
                            pip._ktColorR, pip._ktColorG = r, g
                            pip._ktColorB, pip._ktColorA = b, a
                        end
                        -- The texture a status bar over this pip fills with.
                        local fillTexture = art and PipArt and PipArt.FillTexture(pip) or pip._fill:GetTexture()
                        if art and pipLook.combo then fillTexture = "Interface\\Buttons\\WHITE8X8" end
                        local tintR, tintG, tintB = r, g, b
                        if art and pipLook.piece and not pip._ktArtTint then tintR, tintG, tintB = 1, 1, 1 end

                        -- A tracker or a client can expose the count as a secret number. Do
                        -- not compare it in Lua; let a StatusBar consume it and
                        -- fill each pip through its own [i-1, i] range.
                        if IsSecret(ppRaw) then
                            local secretBar = pip._secretBar
                            if not secretBar then
                                secretBar = CreateFrame("StatusBar", nil, pip)
                                secretBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                                secretBar:SetFrameLevel(pip:GetFrameLevel() + 1)
                                pip._secretBar = secretBar
                            end
                            secretBar:ClearAllPoints()
                            if art and pipLook.combo and pip._ktArtGem then
                                -- Combo art: the count fills the gem's place inside the socket.
                                secretBar:SetAllPoints(pip._ktArtGem)
                            else
                                secretBar:SetAllPoints(pip)
                            end
                            if secretBar._ktTexture ~= fillTexture then
                                secretBar:SetStatusBarTexture(fillTexture)
                                secretBar._ktTexture = fillTexture
                            end
                            if not art then ApplyResourcePipShape(pip, roundResourcePips, comboResourcePips) end
                            secretBar:SetMinMaxValues(i - 1, i)
                            SetStatusBarValueSafe(secretBar, ppRaw)
                            if art and pipLook.combo then
                                secretBar:SetStatusBarColor(1.0, 0.05, 0.05, 1)
                            else
                                secretBar:SetStatusBarColor(tintR, tintG, tintB, 1)
                            end
                            secretBar:Show()
                            if art then PipArt.SetLit(pip, false, r, g, b) else pip._fill:Hide() end
                            pip._ktActive = nil
                            HidePartialPip(pip)
                        else
                            if pip._secretBar then pip._secretBar:Hide() end
                            local active = i <= ppNum
                            if pip._ktActive ~= active then
                                if art then
                                    PipArt.SetLit(pip, active, r, g, b)
                                else
                                    pip._fill:SetShown(active)
                                end
                                pip._ktActive = active
                            end
                            if partialIndex == i and not active then
                                ShowPartialPip(pip, partialFraction, fillTexture, tintR, tintG, tintB)
                            else
                                HidePartialPip(pip)
                            end
                        end
                        if timedPips then
                            local start = recharge.starts[i]
                            if start then
                                local fresh = not pip._ktRecharge
                                recharge.Show(pip, start, recharge.lengths[i], fillTexture, tintR, tintG, tintB)
                                if fresh and not art then ApplyResourcePipShape(pip, roundResourcePips, comboResourcePips) end
                            else
                                recharge.Hide(pip)
                            end
                        end
                    end
                end
            end
        elseif secondaryBar then
            HideMarkers(secondaryBar)
        end
    end
    if profileStarted then profiler:End(profileName, profileStarted) end
end

-------------------------------------------------------------------------------
--  Rebuild & Hooks
-------------------------------------------------------------------------------
function KRB:RebuildFromAnchor()
    self:BuildBars()
    local CBMod = KT:GetModule("CastBar", true)
    if CBMod and CBMod.SnapToTop then
        CBMod:SnapToTop()
    end
end

function KRB:QueuePostCombatAnchor()
    if _postCombatAnchorTicker then
        _postCombatAnchorTicker:Cancel()
        _postCombatAnchorTicker = nil
    end

    local delays = { 0.1, 0.5, 1.5, 3.0 }
    local index = 0
    local ticker
    ticker = C_Timer.NewTicker(0.35, function()
        if InCombatLockdown() then return end
        index = index + 1
        local delay = delays[index]
        if delay then
            C_Timer.After(delay, function()
                if InCombatLockdown() then return end
                self:RebuildFromAnchor()
                -- The function lives in the Cooldown Manager addon's namespace, which it publishes as KUI_CDM_NS.
                local cdmNS = rawget(_G, "KUI_CDM_NS")
                if type(cdmNS) == "table" and cdmNS.RequestAnchorPlayerFrameToCDM then
                    cdmNS.RequestAnchorPlayerFrameToCDM()
                end
            end)
        end
        if index >= #delays then
            if ticker then ticker:Cancel() end
            _postCombatAnchorTicker = nil
        end
    end)
    _postCombatAnchorTicker = ticker
end

function KRB:OnCDMLayout()
    StartWidthPolling()
    if InCombatLockdown() then
        self:QueuePostCombatAnchor()
    else
        C_Timer.After(0.05, function()
            if InCombatLockdown() then return end
            self:RebuildFromAnchor()
        end)
    end
end

function KRB:HandleCombatState(event)
    UpdateCombatVisibility(event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:OnResourceCast(event)
        self:QueuePostCombatAnchor()
    end
end

-------------------------------------------------------------------------------
--  Eventos
-------------------------------------------------------------------------------
function KRB:OnEnable()
    if KT and KT.RegisterChatCommand and not self._debugCmdRegistered then
        KT:RegisterChatCommand("ktrbdebug", function() self:DebugDump() end)
        self._debugCmdRegistered = true
    end

    local CBMod = KT:GetModule("CastBar", true)
    if CBMod and not self.hookedCB then
        hooksecurefunc(CBMod, "ApplySettings", function() self:BuildBars() end)
        self.hookedCB = true
    end

    local function TryHookCDM()
        local cdm_ns = _G.KUI_CDM_NS
        if cdm_ns and not self.hookedCDMBuild and cdm_ns.BuildAllCDMBars then
            hooksecurefunc(cdm_ns, "BuildAllCDMBars", function()
                C_Timer.After(0.1, function() self:RebuildFromAnchor() end)
            end)
            self.hookedCDMBuild = true
        end
        
        if not self.hookedCDMLayout then
            local kuiBar = _G["KUI_CDMBar_cooldowns"]
            if kuiBar then
                kuiBar:HookScript("OnSizeChanged", function()
                    self:OnCDMLayout()
                end)
                self.hookedCDMLayout = true
            end
        end
    end
    TryHookCDM()

    for _, delay in ipairs({ 0.5, 1.5, 3.0 }) do
        C_Timer.After(delay, function()
            TryHookCDM()
            self:BuildBars()
            local cb = KT:GetModule("CastBar", true)
            if cb and cb.SnapToTop then cb:SnapToTop() end
        end)
    end

    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM",        "BuildBars")

    -- UNIT_* events are registered for the player only: a plain RegisterEvent
    -- delivered them for every nameplate and group member, only to be thrown
    -- away in Lua. AceEvent has no unit filter, so a private frame carries them.
    -- Brewmaster stagger can change without health/power updates (Purifying
    -- Brew), hence the absorb events.
    if not self._ktUnitEventFrame then
        -- Only these classes have a resource that a cast changes.
        local _, playerClass = UnitClass("player")
        local trackerClass = playerClass == "HUNTER" or playerClass == "WARRIOR" or playerClass == "DEMONHUNTER"
        local unitEvents = {
            UNIT_SPELLCAST_SUCCEEDED        = trackerClass and "OnResourceCast" or nil,
            UNIT_DISPLAYPOWER               = "BuildBars",
            UNIT_HEALTH                     = "UpdateBars",
            UNIT_MAXHEALTH                  = "UpdateBars",
            UNIT_POWER_UPDATE               = "UpdateBars",
            UNIT_POWER_FREQUENT             = "UpdateBars",
            UNIT_ABSORB_AMOUNT_CHANGED      = "UpdateBars",
            UNIT_HEAL_ABSORB_AMOUNT_CHANGED = "UpdateBars",
            UNIT_MAXPOWER                   = "UpdateBars",
            UNIT_AURA                       = "OnUnitAura",
            -- A spec change arrives with a burst of talent events (and also
            -- fires for group members): one coalesced rebuild covers them all.
            PLAYER_SPECIALIZATION_CHANGED   = "OnTalentChange",
        }
        local frame = CreateFrame("Frame")
        for event in pairs(unitEvents) do
            frame:RegisterUnitEvent(event, "player")
        end
        frame:SetScript("OnEvent", function(_, event, ...)
            KRB[unitEvents[event]](KRB, event, ...)
        end)
        self._ktUnitEventFrame = frame
    end
    self:RegisterEvent("PLAYER_DEAD", "OnResourceCast")
    self:RegisterEvent("PLAYER_ALIVE", "OnResourceCast")
    -- Death Knight runes don't always trigger UNIT_POWER_* reliably; use rune events for accurate pip updates.
    self:RegisterEvent("RUNE_POWER_UPDATE",             "UpdateBars")
    self:RegisterEvent("RUNE_TYPE_UPDATE",              "UpdateBars")
    self:RegisterEvent("PLAYER_ENTERING_WORLD",         "OnEnteringWorld")
    -- A talent can add or remove a class resource; a burst of node events
    -- coalesces into one rebuild.
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "OnTalentChange")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnTalentChange")
    
    self:RegisterEvent("PLAYER_REGEN_DISABLED",         "HandleCombatState")
    self:RegisterEvent("PLAYER_REGEN_ENABLED",          "HandleCombatState")
end

function KRB:OnUnitAura(event, unit)
    if unit ~= "player" then return end
    local sec = GetSecondaryResource()
    if sec and AURA_DRIVEN_KINDS[sec.kind] then
        self:UpdateBars(event, unit)
    end
end

-- Casts, death and leaving combat feed the trackers that have no event of their own.
function KRB:OnResourceCast(event, unit, castGUID, spellID)
    local sec = GetSecondaryResource()
    local kind = sec and sec.kind
    if kind == "whirlwind" then
        KT:HandleWhirlwindStacks(event, unit, castGUID, spellID)
    elseif kind == "tip" then
        KT:HandleTipOfTheSpear(event, unit, castGUID, spellID)
    elseif kind ~= "soulFragments" and kind ~= "devourer" then
        return
    end
    self:UpdateBars("UNIT_AURA", "player")
end

function KRB:OnTalentChange()
    if self._ktTalentPending then return end
    self._ktTalentPending = true
    C_Timer.After(0.2, function()
        self._ktTalentPending = nil
        self:BuildBars()
    end)
end

function KRB:OnEnteringWorld()
    StartWidthPolling()
    C_Timer.After(0, function() self:BuildBars() end)
    C_Timer.After(0.3, function() self:BuildBars() end)
    C_Timer.After(2.0, function() self:BuildBars() end)
    if InCombatLockdown() then
        self:QueuePostCombatAnchor()
    else
        C_Timer.After(0.5, function() self:RebuildFromAnchor() end)
        C_Timer.After(2.0, function() self:RebuildFromAnchor() end)
    end
end

_G._KRB_Apply = function()
    if KRB and KRB.BuildBars then KRB:BuildBars() end
end

-- Shared Resource Bars rendering for the optional autoattack timers.
ns.CreateResourceStatusBar = CreateStatusBar
ns.GetResourceBarFont = GetRBFont
ns.ApplyResourceFrameArt = ApplyClassicFrameArt
