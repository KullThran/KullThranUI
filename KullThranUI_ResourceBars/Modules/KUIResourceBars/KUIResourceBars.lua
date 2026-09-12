-------------------------------------------------------------------------------
--  KUIResourceBars.lua
--  Módulo de Barras de Salud, Poder y Recursos de Clase para KullThranUI
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local KRB = KT:NewModule("ResourceBars", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

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

local function ShouldRenderMarkersOnPrimary(markerCfg, primaryPowerType, secondaryResource)
    if type(markerCfg) ~= "table" or markerCfg.enabled ~= true then
        return false
    end

    if markerCfg.target == "primary" then
        return primaryPowerType ~= PT.MANA
    end
    if markerCfg.target == "secondary" then
        return false
    end

    if secondaryResource and secondaryResource.type == "bar" then
        return false
    end

    return primaryPowerType ~= PT.MANA
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
            if (specID == 103 or pType == PT.ENERGY) then
                return { power = PT.COMBO, max = GetPowerMax("player", PT.COMBO, 5), type = "pips" }
            end
            -- Oso u otras formas sin recurso secundario relevante
            return nil
        else
            -- Sin forma (caster/humanoide):
            -- Feral conserva Puntos de Combo visibles fuera de forma
            if specID == 103 then
                return { power = PT.COMBO, max = GetPowerMax("player", PT.COMBO, 5), type = "pips" }
            end
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

    return nil
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
            general   = { anchorGap = 4, matchCooldownWidth = true, manualWidth = 250, strata = "MEDIUM", hideOOC = false, xOffset = 0, bgA = 0.8, previewMode = "stack", texture = DEFAULT_BAR_TEXTURE, textureDefaultVersion = BAR_TEXTURE_DEFAULT_VERSION },
            powerColors = {},
            health    = { enabled = false, height = 25, borderSize = 1, fillR = 0.15, fillG = 0.75, fillB = 0.30, fillA = 1, textFormat = "both", textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE },
            primary   = { enabled = true,  height = 25, borderSize = 1, fillR = 0.00, fillG = 0.55, fillB = 1.00, fillA = 1, textFormat = "curpp", textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE, classColor = true, colorMode = "power", specColors = {}, hideManaBySpec = {}, markers = { enabled = false, values = "", width = 2, colorR = 1, colorG = 1, colorB = 1, colorA = 0.95 } },
            secondary = { enabled = true,  pipHeight = 14, pipSpacing = 2, borderSize = 1, fillR = 0.95, fillG = 0.90, fillB = 0.60, fillA = 1, showText = true, textSize = 13, barAlpha = 1, texture = DEFAULT_BAR_TEXTURE, classColor = true, colorMode = "power", specColors = {}, pipColors = {}, markers = { mode = "loadout", character = CreateDefaultMarkerProfile(), specs = {}, loadouts = {} } },
        }
    end

    local db = KT.db.profile.resourceBars
    if db.enabled == nil then db.enabled = true end
    db.general   = db.general   or { anchorGap = 4, matchCooldownWidth = true, manualWidth = 250, strata = "MEDIUM", hideOOC = false, xOffset = 0, bgA = 0.8, previewMode = "stack", texture = DEFAULT_BAR_TEXTURE, textureDefaultVersion = BAR_TEXTURE_DEFAULT_VERSION }
    if db.general.anchorGap == nil         then db.general.anchorGap          = 4    end
    if db.general.matchCooldownWidth == nil then db.general.matchCooldownWidth = true end
    if db.general.manualWidth == nil        then db.general.manualWidth        = 250  end
    if db.general.strata == nil             then db.general.strata             = "MEDIUM" end
    if db.general.hideOOC == nil            then db.general.hideOOC            = false end
    if db.general.xOffset == nil            then db.general.xOffset            = 0 end
    if db.general.bgA == nil                then db.general.bgA                = 0.8 end
    if db.general.previewMode == nil        then db.general.previewMode        = "stack" end

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
    db.primary.markers = db.primary.markers or { enabled = false, values = "", width = 2, colorR = 1, colorG = 1, colorB = 1, colorA = 0.95 }
    db.secondary.markers = EnsureMarkerState(db.secondary.markers or CloneMarkerConfig(db.primary.markers))
    GetActiveMarkerConfig(db)

    return db
end

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
        if f._ecmeHidden then return false end -- [FIX] Ignore hidden Blizzard CDM
        if not (f.GetPoint and f:GetPoint(1)) then return false end
        local _, _, _, _, y = f:GetPoint()
        if y and math.abs(y) > 3000 then return false end -- [FIX] Ignore off-screen frames
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

    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(GetRBFont(), 13, "OUTLINE")
    text:SetPoint("CENTER")
    bar._text = text

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
local healthBar, primaryBar, secondaryFrame, secondaryBar, resourceAnchor
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

function KRB:RegisterUnlockElement()
    if self.unlockElementRegistered or not KT or not KT.RegisterUnlockElement then
        return
    end

    KT.RegisterUnlockElement(KT_RB_UNLOCK_KEY, {
        label = "Resource Bars",
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
        isHidden = function()
            local db = GetSafeDB()
            return not (db and ((db.health and db.health.enabled) or (db.primary and db.primary.enabled) or (db.secondary and db.secondary.enabled)))
        end,
    })

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

    local EM = KT:GetModule("EditMode", true)
    if EM and not resourceAnchor.KT_EditModeRegistered then
        EM:RegisterFrame(resourceAnchor, "Resource Bars", "resource_bars", {
            resizable = false,
            onEnter = function()
                resourceAnchor:Show()
                KRB:BuildBars()
            end,
            onExit = function()
                KRB:BuildBars()
            end,
        })
        resourceAnchor.KT_EditModeRegistered = true
    end

    local saved = EM and EM.db and EM.db.frames and EM.db.frames["resource_bars"]
    if saved and saved.point then
        resourceAnchor:ClearAllPoints()
        resourceAnchor:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
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
local function UpdateCombatVisibility()
    local db = GetSafeDB()
    local inCombat = InCombatLockdown()
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
--  BuildBars
-------------------------------------------------------------------------------
function KRB:BuildBars()
    local db         = GetSafeDB()
    if db.enabled == false then
        if healthBar then healthBar:Hide() end
        if primaryBar then primaryBar:Hide() end
        if secondaryFrame then secondaryFrame:Hide() end
        if resourceAnchor then resourceAnchor:Hide() end
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

    local anchorFrame = EnsureResourceAnchor(refWidth, 1, baseAnchor, gap, xOff, db.general.strata or "MEDIUM")
    local lastAnchorFrame
    local totalHeight = 0

    local function StackAbove(frame)
        frame:SetParent(anchorFrame)
        frame:ClearAllPoints()
        frame:SetFrameStrata(db.general.strata or "MEDIUM")
        frame:SetPoint("BOTTOM", anchorFrame, "BOTTOM", 0, totalHeight)
        lastAnchorFrame = frame
        totalHeight = totalHeight + frame:GetHeight() + gap
    end

    -- ── 1. Recurso Secundario ─────────────────────────────────────────────
    local sec = GetSecondaryResource()
    if db.secondary.enabled and sec then
        if not secondaryFrame then
            secondaryFrame = CreateFrame("Frame", "KUI_SecondaryFrame", UIParent)
        end

        local secW = refWidth
        if db.general.matchCooldownWidth then secW = refWidth
        else secW = db.general.manualWidth or 250 end

        secondaryFrame:SetSize(secW, db.secondary.pipHeight)
        StackAbove(secondaryFrame)

        if sec.type == "bar" then
            for i = 1, #pips do if pips[i] then pips[i]:Hide() end end
            
            if not secondaryBar then
                secondaryBar = CreateStatusBar(secondaryFrame, "KUI_SecondaryBar")
            end
            secondaryBar:SetSize(secW, db.secondary.pipHeight)
            secondaryBar:ClearAllPoints()
            secondaryBar:SetPoint("CENTER", secondaryFrame, "CENTER")
            
            secondaryBar:SetStatusBarTexture(texSec)
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
            secondaryBar._text:SetFont(GetRBFont(), db.secondary.textSize, "OUTLINE")
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
            
            local pipW = (secW - (db.secondary.pipSpacing * (sec.max - 1))) / sec.max
            for i = 1, sec.max do
                if not pips[i] then
                    pips[i] = CreateFrame("Frame", nil, secondaryFrame)
                    pips[i]._bg   = pips[i]:CreateTexture(nil, "BACKGROUND")
                    pips[i]._bg:SetAllPoints()
                    pips[i]._fill = pips[i]:CreateTexture(nil, "ARTWORK")
                    pips[i]._fill:SetAllPoints()
                    pips[i]._border = MakePixelBorder(pips[i], 0, 0, 0, 1, 1)
                end
                local x = (i - 1) * (pipW + db.secondary.pipSpacing)
                pips[i]:SetSize(pipW, db.secondary.pipHeight)
                pips[i]:ClearAllPoints()
                pips[i]:SetPoint("LEFT", secondaryFrame, "LEFT", x, 0)
                pips[i]._bg:SetColorTexture(0.07, 0.07, 0.07, db.general.bgA)
                pips[i]._fill:SetTexture(texSec)
                
                local r, g, b, a = ResolveSecondaryPipColor(db, sec, i, db.secondary.fillA or 1)
                pips[i]._fill:SetVertexColor(r, g, b, a)
                
                pips[i]:SetAlpha(db.secondary.barAlpha or 1)
                pips[i]._border:SetSize(db.secondary.borderSize)
                pips[i]._border:SetShown(db.secondary.borderSize > 0)
                pips[i]:Show()
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
        primaryBar:SetSize(refWidth, db.primary.height)
        StackAbove(primaryBar)
        primaryBar:SetStatusBarTexture(texPri)
        primaryBar._bg:SetColorTexture(0.07, 0.07, 0.07, db.general.bgA)
        
        local r, g, b, a = ResolveSectionColor(db.primary, ppTypeNow, db.primary.fillA or 1)
        primaryBar:GetStatusBarTexture():SetVertexColor(r, g, b, a)
        
        primaryBar:SetAlpha(db.primary.barAlpha or 1)
        primaryBar._border:SetSize(db.primary.borderSize)
        primaryBar._border:SetShown(db.primary.borderSize > 0)
        primaryBar._text:SetFont(GetRBFont(), db.primary.textSize, "OUTLINE")
        primaryBar:Show()
        HideMarkers(primaryBar)
    elseif primaryBar then
        HideMarkers(primaryBar)
        primaryBar:Hide()
    end

    -- ── 3. Barra de Salud ────────────────────────────────────────────────
    if db.health.enabled then
        if not healthBar then
            healthBar = CreateStatusBar(anchorFrame, "KUI_HealthBar")
        end
        healthBar:SetSize(refWidth, db.health.height)
        StackAbove(healthBar)
        healthBar:SetStatusBarTexture(texHea)
        healthBar._bg:SetColorTexture(0.07, 0.07, 0.07, db.general.bgA)
        healthBar:GetStatusBarTexture():SetVertexColor(db.health.fillR, db.health.fillG, db.health.fillB, db.health.fillA or 1)
        healthBar:SetAlpha(db.health.barAlpha or 1)
        healthBar._border:SetSize(db.health.borderSize)
        healthBar._border:SetShown(db.health.borderSize > 0)
        healthBar._text:SetFont(GetRBFont(), db.health.textSize, "OUTLINE")
        healthBar:Show()
    elseif healthBar then
        healthBar:Hide()
    end

    anchorFrame:SetSize(refWidth, max(totalHeight - gap, 1))
    anchorFrame:SetShown(totalHeight > gap or (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive()))

    _G.KUI_ResourceBarsTop = lastAnchorFrame

    self:UpdateBars()
    UpdateCombatVisibility()
end

-------------------------------------------------------------------------------
--  UpdateBars
-------------------------------------------------------------------------------
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
    local secondaryMarkerConfig = (updatePrimary or updateSecondary)
        and (self._cachedMarkerConfig or GetActiveMarkerConfig(db)) or nil
    local ppTypeNow = updatePrimary and GetPrimaryPowerType() or nil
    local hidePrimaryMana = updatePrimary
        and (IsManaHiddenForCurrentSpec(db) and ppTypeNow == PT.MANA)
    local sec = (updatePrimary or updateSecondary) and GetSecondaryResource() or nil
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

            local fmt = db.health.textFormat
            local txt
            local pctStr = GetHealthPctStr("player")
            if fmt == "both" then
                txt = FormatCurSafe(hpRaw) .. " - " .. (pctStr or GetSafePct(hpRaw, mxRaw)) .. "%"
            elseif fmt == "perhp" then
                txt = (pctStr or GetSafePct(hpRaw, mxRaw)) .. "%"
            elseif fmt == "curhpshort" then
                txt = FormatCurSafe(hpRaw)
            elseif fmt == "curhpfull" then
                txt = FormatFullSafe(hpRaw)
            else
                txt = ""
            end
            local secretTxt = IsSecret(txt)
            if fmt ~= healthBar._ktTextFmt or secretTxt or txt ~= healthBar._ktTextLast then
                healthBar._text:SetText(txt)
                healthBar._ktTextFmt = fmt
                if secretTxt then
                    healthBar._ktTextLast = nil
                else
                    healthBar._ktTextLast = txt
                end
            end
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
            -- FIX: Usamos FormatCur para abreviar (250K en vez de 250000)
            local fmt = db.primary.textFormat
            local txt
            local pctStr = GetPowerPctStr("player", ppTypeNow)
            if fmt == "both" then
                txt = FormatCurSafe(ppRaw) .. " - " .. (pctStr or GetSafePct(ppRaw, mxRaw)) .. "%"
            elseif fmt == "perpp" then
                txt = (pctStr or GetSafePct(ppRaw, mxRaw)) .. "%"
            elseif fmt == "curpp" then
                txt = FormatCurSafe(ppRaw)
            elseif fmt == "curppfull" then
                txt = FormatFullSafe(ppRaw)
            else
                txt = ""
            end
            local secretTxt = IsSecret(txt)
            if fmt ~= primaryBar._ktTextFmt or secretTxt or txt ~= primaryBar._ktTextLast then
                primaryBar._text:SetText(txt)
                primaryBar._ktTextFmt = fmt
                if secretTxt then
                    primaryBar._ktTextLast = nil
                else
                    primaryBar._ktTextLast = txt
                end
            end

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

    if updateSecondary and secondaryFrame and secondaryFrame:IsShown() then
        if sec then
            local ppRaw, ppNum
            if sec.kind == "runes" then
                -- Runes aren't a typical "power" bar; count ready runes via cooldown API for reliable updates.
                local ready = 0
                local maxRunes = (sec.max and sec.max > 0) and sec.max or 6
                if GetRuneCooldown then
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
            else
                ppRaw = UnitPower("player", sec.power)
                ppNum = SafeNum(ppRaw, 0)
            end
            if sec.max and sec.max > 0 and ppNum > sec.max then ppNum = sec.max end
            
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
                        mxRaw = UnitPowerMax("player", sec.power)
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
                    
                    local secondaryText = db.secondary.showText and FormatCurSafe(ppRaw) or ""
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
                for i = 1, sec.max do
                    if pips[i] then
                        local r, g, b, a = ResolveSecondaryPipColor(db, sec, i, db.secondary.fillA or 1)
                        if fullUpdate or pips[i]._ktColorR ~= r or pips[i]._ktColorG ~= g
                            or pips[i]._ktColorB ~= b or pips[i]._ktColorA ~= a then
                            pips[i]._fill:SetVertexColor(r, g, b, a)
                            pips[i]._ktColorR, pips[i]._ktColorG = r, g
                            pips[i]._ktColorB, pips[i]._ktColorA = b, a
                        end
                        
                        local active = i <= ppNum
                        if pips[i]._ktActive ~= active then
                            pips[i]._fill:SetShown(active)
                            pips[i]._ktActive = active
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
                if ns.RequestAnchorPlayerFrameToCDM then
                    ns.RequestAnchorPlayerFrameToCDM()
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
    UpdateCombatVisibility()
    if event == "PLAYER_REGEN_ENABLED" then
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

    self:RegisterEvent("UNIT_DISPLAYPOWER",             "BuildBars")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM",        "BuildBars")
    
    self:RegisterEvent("UNIT_HEALTH",                   "UpdateBars")
    self:RegisterEvent("UNIT_MAXHEALTH",                "UpdateBars")
    self:RegisterEvent("UNIT_POWER_UPDATE",             "UpdateBars")
    self:RegisterEvent("UNIT_POWER_FREQUENT",           "UpdateBars")
    -- Death Knight runes don't always trigger UNIT_POWER_* reliably; use rune events for accurate pip updates.
    self:RegisterEvent("RUNE_POWER_UPDATE",             "UpdateBars")
    self:RegisterEvent("RUNE_TYPE_UPDATE",              "UpdateBars")
    -- Brewmaster stagger changes can occur without health/power updates (e.g. Purifying Brew).
    self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED",    "UpdateBars")
    self:RegisterEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED","UpdateBars")
    self:RegisterEvent("UNIT_MAXPOWER",                 "UpdateBars")
    self:RegisterEvent("UNIT_AURA",                     "OnUnitAura")
    self:RegisterEvent("PLAYER_ENTERING_WORLD",         "OnEnteringWorld")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "BuildBars")
    
    self:RegisterEvent("PLAYER_REGEN_DISABLED",         "HandleCombatState")
    self:RegisterEvent("PLAYER_REGEN_ENABLED",          "HandleCombatState")
end

function KRB:OnUnitAura(event, unit)
    if unit ~= "player" then return end
    local sec = GetSecondaryResource()
    if sec and sec.kind == "aura" then
        self:UpdateBars(event, unit)
    end
end

function KRB:OnEnteringWorld()
    StartWidthPolling()
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
