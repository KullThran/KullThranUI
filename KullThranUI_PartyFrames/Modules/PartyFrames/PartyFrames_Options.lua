local ADDON_NAME, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

local _G = _G
local CreateFrame = _G.CreateFrame
local IsShiftKeyDown = _G.IsShiftKeyDown
local AbbreviateNumbers = _G.AbbreviateNumbers
local strtrim = _G.strtrim
local math = math
local ipairs = ipairs
local tostring = tostring
local type = type

local LSM = LibStub("LibSharedMedia-3.0", true)

local function GetStatusbarValues()
    local values = {}
    local legacyPath = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
    local legacyNormalized = legacyPath:lower()
    if LSM then
        local list = LSM:List("statusbar")
        for i = 1, #(list or {}) do
            local name = list[i]
            local path = LSM:Fetch("statusbar", name, true)
            if type(path) == "string" and path:lower() == legacyNormalized then
                values[legacyPath] = name
            else
                values[name] = name
            end
        end
    end
    values[legacyPath] = values[legacyPath] or "Melli"
    values._menuOpts = { kind = "texture", sharedMedia = false }
    return values
end

local function ResolveStatusbarTexture(value, fallback)
    if type(value) == "string" and value ~= "" then
        if value:find("\\", 1, true) or value:find("/", 1, true) then
            return value
        end
        local sharedPath = LSM and LSM:Fetch("statusbar", value, true)
        if sharedPath then return sharedPath end
    end
    return fallback
end

local Opt = KT.Options or {}
local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks

local function LText(text)
    if Opt.LText then
        return Opt.LText(text)
    end
    if type(text) == "string" and KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] ~= nil then return L[text] end
    end
    return text
end

local function LTextFmt(text, ...)
    return string.format(LText(text), ...)
end

local activeMode = "party"
local rosterMode = "party"
local selectedSpecID
local livePreview
local profilesSelectionName
local profilesDraftName
local spellVisibilitySearch = {}
local spellVisibilityTypeFilter = {}

local MODE_TABS = {
    { id = "party", label = "Dungeons" },
    { id = "raid", label = "Raid" },
    { id = "raid40", label = "Raid 40" },
    { id = "arena", label = "Arena" },
    { id = "arenaEnemy", label = "Arena Enemies" },
    { id = "boss", label = "Boss" },
    { id = "manage", label = "Manage" },
}

local PREVIEW_MODE_TABS = {
    { id = "party", label = "Dungeons" },
    { id = "raid", label = "Raid" },
    { id = "raid40", label = "Raid 40" },
    { id = "arena", label = "Arena" },
    { id = "arenaEnemy", label = "Arena Enemies" },
    { id = "boss", label = "Boss" },
}

local DIRECTION_VALUES = {
    HORIZONTAL = "Horizontal",
    VERTICAL = "Vertical",
}

local DIRECTION_ORDER = { "HORIZONTAL", "VERTICAL" }
local FLOW_VALUES = {
    LEFT = "Left",
    RIGHT = "Right",
    UP = "Up",
    DOWN = "Down",
}

local FLOW_HORIZONTAL_ORDER = { "LEFT", "RIGHT" }
local FLOW_VERTICAL_ORDER = { "UP", "DOWN" }

local ANCHOR_VALUES = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local ANCHOR_ORDER = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}

local HEALTH_TEXT_VALUES = {
    PERCENT = "Percent",
    CURRENT = "Current",
    DEFICIT = "Deficit",
    CURRENTMAX = "Current / Max",
    NONE = "None",
}

local HEALTH_TEXT_ORDER = { "PERCENT", "CURRENT", "DEFICIT", "CURRENTMAX", "NONE" }

local SIDE_VALUES = {
    LEFT = "Left",
    RIGHT = "Right",
}

local SIDE_ORDER = { "LEFT", "RIGHT" }

local SAMPLE_NAMES = {
    "Kull", "Thran", "Alyra", "Dorn", "Mira",
    "Vael", "Nyra", "Orin", "Sel", "Kael",
    "Rin", "Voss", "Tara", "Nox", "Lio",
    "Eryn", "Hale", "Rook", "Iria", "Bren",
    "Vale", "Mek", "Sera", "Jor", "Kara",
}

local ROLE_COLORS = {
    TANK = { 0.24, 0.52, 1.00 },
    HEALER = { 0.20, 0.86, 0.45 },
    DAMAGER = { 0.92, 0.34, 0.25 },
}
local BLIZZARD_ROLE_COORDS = {
    TANK = { 0, 0.296875, 0.296875, 0.65 },
    HEALER = { 0.296875, 0.59375, 0, 0.296875 },
    DAMAGER = { 0.296875, 0.59375, 0.296875, 0.65 },
}

local CLASS_COLORS = {
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
    DRUID = { 1.00, 0.49, 0.04 },
    EVOKER = { 0.20, 0.58, 0.50 },
    HUNTER = { 0.67, 0.83, 0.45 },
    MONK = { 0.00, 1.00, 0.60 },
    WARRIOR = { 0.78, 0.61, 0.43 },
    PRIEST = { 1.00, 1.00, 1.00 },
    PALADIN = { 0.96, 0.55, 0.73 },
    MAGE = { 0.25, 0.78, 0.92 },
    ROGUE = { 1.00, 0.96, 0.41 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    WARLOCK = { 0.53, 0.53, 0.93 },
}

local PROFILE_VALUES = {
    auto = "Auto",
    dps_tank = "DPS / Tank",
    heal = "Heal",
}

local PROFILE_ORDER = { "auto", "dps_tank", "heal" }

local PREVIEW_FILL = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
local PREVIEW_BG = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"
local PREVIEW_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\"
local PREVIEW_ROLE_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\"
local PREVIEW_WHITE = "Interface\\Buttons\\WHITE8x8"
local PARTY_VERTICAL_NAME_LEFT_INSET = 24
local PARTY_VERTICAL_BUFF_TOP_OFFSET = 17
local DEFAULT_FONT_NAME = KT.DEFAULT_FONT_NAME or "AAA_ITC_Avant_Garde"
local DEFAULT_FONT_PATH = KT.DEFAULT_FONT_PATH or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local OFFLINE_HEALTH_COLOR = { 0.52, 0.54, 0.57, 0.9 }
local OFFLINE_POWER_COLOR = { 0.34, 0.35, 0.38, 0.9 }

local PREVIEW_UNITS = {
    { name = "Tankerino", class = "WARRIOR", role = "TANK", health = 0.98, power = 0.85, maxHealth = 100000, absorb = 0.20 },
    { name = "Healsworth", class = "PRIEST", role = "HEALER", health = 0.92, power = 0.90, maxHealth = 85000, absorb = 0.10 },
    { name = "Player", class = "PALADIN", role = "DAMAGER", health = 0.76, power = 0.65, maxHealth = 90000, absorb = 0.05, isPlayer = true },
    { name = "Alexandros", class = "MAGE", role = "DAMAGER", health = 0, power = 0, maxHealth = 75000, absorb = 0, status = "Dead" },
    { name = "Xx", class = "ROGUE", role = "DAMAGER", health = 0.34, power = 0.55, maxHealth = 70000, absorb = 0.12, status = "Offline" },
}

local AURA_SAMPLE_BUFFS = { 136078, 135932, 132333, 4622448, 4630367 }
local AURA_SAMPLE_BUFF_IDS = { 1126, 1459, 6673, 381748, 462854 }
local AURA_SAMPLE_DEBUFFS = {
    { icon = 136071, spellID = 118, color = { r = 0.20, g = 0.60, b = 1.00 } },
    { icon = 136139, spellID = 980, color = { r = 0.62, g = 0.08, b = 0.92 } },
    { icon = 136207, spellID = 589, color = { r = 0.54, g = 0.28, b = 0.84 } },
    { icon = 132155, spellID = 388539, color = { r = 1.00, g = 0.05, b = 0.05 } },
    { icon = 132140, spellID = 431491, color = { r = 0.88, g = 0.08, b = 0.08 } },
    { icon = 132152, spellID = 228318, color = { r = 1.00, g = 0.44, b = 0.05 } },
    { icon = 136066, spellID = 55078, color = { r = 0.70, g = 0.52, b = 0.10 } },
    { icon = 136067, spellID = 8680, color = { r = 0.05, g = 0.72, b = 0.16 } },
    { icon = 135781, spellID = 209858, color = { r = 0.18, g = 0.78, b = 0.28 } },
    { icon = 136182, spellID = 2094, color = { r = 0.95, g = 0.18, b = 0.18 } },
    { icon = 132298, spellID = 339, color = { r = 0.10, g = 0.72, b = 0.40 } },
    { icon = 237514, spellID = 115078, color = { r = 0.15, g = 0.75, b = 0.92 } },
    { icon = 135807, spellID = 2120, color = { r = 1.00, g = 0.30, b = 0.08 } },
    { icon = 236216, spellID = 316099, color = { r = 0.36, g = 0.82, b = 1.00 } },
    { icon = 135945, spellID = 3600, color = { r = 0.78, g = 0.74, b = 0.20 } },
    { icon = 463565, spellID = 25771, color = { r = 0.95, g = 0.60, b = 0.10 } },
}

-- Almacenar colores randomizados por posición de party (excepto player)
local MISSING_BUFF_PREVIEW_RULES = {
    DRUID = { key = "missingBuffCheckMark", name = "Mark of the Wild", icon = 136078, spellID = 1126 },
    PRIEST = { key = "missingBuffCheckStamina", name = "Power Word: Fortitude", icon = 135987, spellID = 21562 },
    MAGE = { key = "missingBuffCheckIntellect", name = "Arcane Intellect", icon = 135932, spellID = 1459 },
    WARRIOR = { key = "missingBuffCheckAttackPower", name = "Battle Shout", icon = 132333, spellID = 6673 },
    SHAMAN = { key = "missingBuffCheckSkyfury", name = "Skyfury", icon = 4630367, spellID = 462854 },
    EVOKER = { key = "missingBuffCheckBronze", name = "Blessing of the Bronze", icon = 4622448, spellID = 381748 },
}

local memberColorOverrides = {}
local previewDebuffSeed = 0
-- Lista de clases disponibles para randomizar
local classOrderForRandomization = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MONK",
    "WARRIOR", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "MAGE", "PALADIN"
}

local function RandomizePartyMemberColors()
    memberColorOverrides = {}
    ns.PF_TestStatusOverrides = {}
    local statusOverrides = ns.PF_TestStatusOverrides
    statusOverrides[1] = math.random(1, 2) == 1 and "Offline" or "Dead"
    ns.PF_TestNoDispelOverlay = { [2] = true, [5] = true }
    previewDebuffSeed = math.random(1, 100000)
    local shuffledClasses = {}
    for i = 1, #classOrderForRandomization do
        shuffledClasses[i] = classOrderForRandomization[i]
    end
    -- Simple Fisher-Yates shuffle
    for i = #shuffledClasses, 2, -1 do
        local j = math.random(1, i)
        shuffledClasses[i], shuffledClasses[j] = shuffledClasses[j], shuffledClasses[i]
    end

    -- Asignar clases randomizadas a cada índice
    for i = 1, 40 do
        memberColorOverrides[i] = shuffledClasses[((i - 1) % #classOrderForRandomization) + 1]
    end
end

local function GetPreviewDebuffSample(unitIndex, iconIndex, mode, offset)
    local modeShift = mode == "raid40" and 9 or (mode == "raid" and 5 or (mode == "arena" and 13 or 0))
    local seedShift = previewDebuffSeed or 0
    local index = (((unitIndex or 1) * 7) + ((iconIndex or 1) * 11) + modeShift + seedShift + (offset or 0)) % #AURA_SAMPLE_DEBUFFS
    return AURA_SAMPLE_DEBUFFS[index + 1]
end

local function GetMod()
    return KT:GetModule("PartyFrames", true)
end

local function GetProfilesModule()
    return KT:GetModule("Profiles", true)
end

local function PrintStatus(msg)
    if KT and KT.Print then
        KT:Print(msg)
    else
        print("|cFF00FFFF[KullThranUI]|r " .. tostring(msg))
    end
end

local function RefreshPage()
    if KT and KT.RefreshPage then
        KT:RefreshPage()
    end
end

local function ApplyValue(mode, key, value)
    local mod = GetMod()
    if not (mod and mod.SetConfigValue) then return end
    local ok, reason = mod:SetConfigValue(mode, key, value)
    if not ok and reason == "combat" then
        PrintStatus("Party Frames layout change saved. It will be applied after combat.")
    end
    if livePreview and livePreview.Refresh then
        livePreview:Refresh()
    end
end

local function GetValue(mode, key, fallback)
    local mod = GetMod()
    if mod and mod.GetConfigValue then
        return mod:GetConfigValue(mode, key, fallback)
    end
    return fallback
end

local function GetRootValue(key, fallback)
    local mod = GetMod()
    if mod and mod.GetRootConfigValue then
        return mod:GetRootConfigValue(key, fallback)
    end
    return fallback
end

local function ApplyRootValue(key, value)
    local mod = GetMod()
    if mod and mod.SetRootConfigValue then
        local ok, reason = mod:SetRootConfigValue(key, value)
        if not ok and reason == "combat" then
            PrintStatus("Party Frames profile change saved. It will be applied after combat.")
        end
    end
    if livePreview and livePreview.Refresh then
        livePreview:Refresh()
    end
    RefreshPage()
end

local function RequestReload()
    if StaticPopup_Show then
        StaticPopup_Show("KULLTHRANUI_RELOAD")
    end
end

local function NudgeValue(mode, key, delta, minValue, maxValue)
    local value = tonumber(GetValue(mode, key, minValue)) or minValue
    value = value + delta
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    ApplyValue(mode, key, value)
end

local function ApplyPreset(presetKey)
    local mod = GetMod()
    if not (mod and mod.ApplyPreset) then return end
    local ok, reason = mod:ApplyPreset(presetKey)
    if not ok and reason == "combat" then
        PrintStatus("Party Frames presets cannot be applied during combat.")
        return
    end
    if livePreview and livePreview.Refresh then
        livePreview:Refresh()
    end
    RefreshPage()
end

local function ResolveFontPath(fontName)
    if KT.ResolveFontPath then
        return KT:ResolveFontPath(fontName or DEFAULT_FONT_NAME, DEFAULT_FONT_PATH)
    end
    return DEFAULT_FONT_PATH
end

local ROLE_STYLE_VALUES = {
    ["BLIZZARD"] = "Blizzard Original",
    ["KT"] = "KullThranUI Icons",
}
local ROLE_STYLE_ORDER = { "BLIZZARD", "KT" }

local function ApplyPreviewFont(text, cfg, sizeKey, fallbackSize, maxSize)
    if not text then return end
    local outline = (cfg and cfg.textOutline) or "OUTLINE"
    if outline == "NONE" then outline = "" end
    local size = tonumber(cfg and cfg[sizeKey]) or fallbackSize
    if maxSize and size > maxSize then
        size = math.max(8, maxSize)
    end
    text:SetFont(ResolveFontPath(cfg and cfg.textFont), size, outline)
    text:SetTextColor(1, 1, 1, 1)
end

local function FormatValue(value, abbreviate)
    if abbreviate and AbbreviateNumbers then
        return AbbreviateNumbers(value)
    end
    return tostring(value)
end

local function FitText(value, maxChars)
    value = tostring(value or "")
    maxChars = tonumber(maxChars) or 0
    if maxChars <= 0 or #value <= maxChars then
        return value
    end
    if maxChars <= 3 then
        return value:sub(1, maxChars)
    end
    return value:sub(1, maxChars - 1) .. "."
end

local function FormatPreviewHealth(unit, cfg, health)
    local format = cfg.healthTextFormat or "CURRENTMAX"
    if format == "NONE" then return "" end
    local maxHealth = unit.maxHealth or 100000
    local current = math.floor((health or 0) * maxHealth)
    local deficit = maxHealth - current
    local abbreviate = cfg.healthTextAbbreviate ~= false
    if format == "CURRENT" then
        return FormatValue(current, abbreviate)
    elseif format == "DEFICIT" then
        return deficit > 0 and ("-" .. FormatValue(deficit, abbreviate)) or ""
    elseif format == "CURRENTMAX" then
        return FormatValue(current, abbreviate) .. "/" .. FormatValue(maxHealth, abbreviate)
    end
    return string.format("%.0f%%", (health or 0) * 100)
end

local function GetPreviewUnit(index, count, mode, includePlayer)
    local middle = math.floor(count / 2) + 1
    if includePlayer and index == middle then
        return PREVIEW_UNITS[3]
    end
    local sample
    if mode == "raid" or mode == "raid40" then
        sample = PREVIEW_UNITS[((index - 1) % #PREVIEW_UNITS) + 1]
        if sample.isPlayer then sample = PREVIEW_UNITS[1] end
    else
        sample = PREVIEW_UNITS[index] or PREVIEW_UNITS[((index - 1) % #PREVIEW_UNITS) + 1]
        if sample.isPlayer then sample = PREVIEW_UNITS[1] end
    end
    local statusOverrides = ns.PF_TestStatusOverrides
    if statusOverrides then
        local result = {}
        for key, value in pairs(sample) do
            result[key] = value
        end
        result.status = statusOverrides[index]
        if result.status == "Dead" then
            result.health = 0
            result.power = 0
            result.absorb = 0
        end
        return result
    end
    return sample
end

local function GetPlayerRealClass()
    if _G.UnitClass then
        local _, classToken = _G.UnitClass("player")
        if classToken then return classToken end
    end
    -- Fallback si no se puede obtener
    return "PALADIN"
end

-- Cache para almacenar la clase real del jugador
local playerRealClass = GetPlayerRealClass()

local function GetPreviewMissingBuffRule(cfg)
    if cfg and cfg.showMissingBuffs == false then return nil end
    local rule = MISSING_BUFF_PREVIEW_RULES[playerRealClass] or MISSING_BUFF_PREVIEW_RULES.DRUID
    if not rule or (cfg and cfg[rule.key] == false) then return nil end
    return rule
end

local function GetPreviewColor(sample, cfg, index, count, includePlayer)
    -- Si es el player, siempre usa su color de clase REAL
    if sample.isPlayer then
        if cfg and cfg.colorByClass ~= false then
            local c = playerRealClass and CLASS_COLORS[playerRealClass]
            if c then return c end
        end
        return ROLE_COLORS[sample.role or "DAMAGER"] or ROLE_COLORS.DAMAGER
    end

    -- Para otros miembros, usar colores randomizados si colorByClass está activo
    if cfg and cfg.colorByClass ~= false then
        -- Obtener la clase randomizada para este índice
        local randomClass = memberColorOverrides[index]
        if randomClass then
            local c = CLASS_COLORS[randomClass]
            if c then return c end
        end
        -- Fallback al color de clase del sample
        local c = sample.class and CLASS_COLORS[sample.class]
        if c then return c end
    end
    return ROLE_COLORS[sample.role or "DAMAGER"] or ROLE_COLORS.DAMAGER
end

local function GetPreviewExternalAuraReserve(cfg, mode)
    return 0
end

local function BuildSpecValues(mod)
    local values, order = {}, {}
    local specs = mod and mod.GetPlayerSpecs and mod:GetPlayerSpecs() or {}
    for _, spec in ipairs(specs) do
        local key = tostring(spec.id)
        local auto = spec.id == 1473 and "Heal" or (spec.role == "HEALER" and "Heal" or "DPS / Tank")
        values[key] = (spec.name or key) .. " - Auto: " .. auto
        order[#order + 1] = key
    end
    return values, order
end

local function SetEdgeBorder(frame, r, g, b, a)
    frame._pfEdges = frame._pfEdges or {}
    for i = 1, 4 do
        frame._pfEdges[i] = frame._pfEdges[i] or frame:CreateTexture(nil, "BORDER")
        frame._pfEdges[i]:SetColorTexture(r, g, b, a)
        frame._pfEdges[i]:ClearAllPoints()
    end
    frame._pfEdges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame._pfEdges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame._pfEdges[1]:SetHeight(1)
    frame._pfEdges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame._pfEdges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame._pfEdges[2]:SetHeight(1)
    frame._pfEdges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame._pfEdges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame._pfEdges[3]:SetWidth(1)
    frame._pfEdges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame._pfEdges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame._pfEdges[4]:SetWidth(1)
end

local function AddSimpleBorder(frame, alpha)
    if KT and KT.AddBackdrop then
        KT:AddBackdrop(frame, 0.04, 0.05, 0.07, alpha or 0.92)
    end
    -- Border intentionally omitted here to avoid a double outline.
end

local function CreatePreviewAuraIcon(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(18, 18)
    holder.bg = holder:CreateTexture(nil, "BACKGROUND")
    holder.bg:SetAllPoints()
    holder.bg:SetColorTexture(0, 0, 0, 0.86)
    holder.icon = holder:CreateTexture(nil, "ARTWORK")
    holder.icon:SetPoint("TOPLEFT", 2, -2)
    holder.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    holder.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder.border = {}
    for i = 1, 4 do
        holder.border[i] = holder:CreateTexture(nil, "OVERLAY")
        holder.border[i]:SetColorTexture(0, 0, 0, 0.8)
    end
    holder.border[1]:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    holder.border[1]:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    holder.border[1]:SetHeight(1)
    holder.border[2]:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    holder.border[2]:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    holder.border[2]:SetHeight(1)
    holder.border[3]:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    holder.border[3]:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    holder.border[3]:SetWidth(1)
    holder.border[4]:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
    holder.border[4]:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    holder.border[4]:SetWidth(1)
    holder:Hide()
    return holder
end

local function CreatePreviewDispelBorder(parent)
    local border = {}
    for i = 1, 4 do
        border[i] = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        border[i]:SetColorTexture(0, 0, 0, 0)
        border[i]:Hide()
    end
    border[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border[1]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border[2]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border[2]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border[3]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border[3]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border[4]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border[4]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientTop = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientTop:SetTexture(PREVIEW_WHITE)
    border.gradientTop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.gradientTop:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.gradientTop:Hide()
    border.gradientBottom = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientBottom:SetTexture(PREVIEW_WHITE)
    border.gradientBottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.gradientBottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientBottom:Hide()
    border.gradientLeft = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientLeft:SetTexture(PREVIEW_WHITE)
    border.gradientLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.gradientLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.gradientLeft:Hide()
    border.gradientRight = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientRight:SetTexture(PREVIEW_WHITE)
    border.gradientRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.gradientRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientRight:Hide()
    return border
end

local function CreatePreviewOverlayIcon(parent, size)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size or 16, size or 16)
    if parent and parent.GetFrameLevel then
        holder:SetFrameLevel((parent:GetFrameLevel() or 0) + 20)
    end
    holder.texture = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    holder.texture:SetAllPoints()
    holder:Hide()
    return holder
end

local function SetPreviewBlizzardRoleIconCoords(texture, role)
    if not texture then return end
    local coords = BLIZZARD_ROLE_COORDS[role]
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function SetPreviewRaidTargetIcon(texture, index)
    if not texture or not index then return end
    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    if _G.SetRaidTargetIconTexture then
        _G.SetRaidTargetIconTexture(texture, index)
        return
    end
    local col = ((index - 1) % 4) / 4
    local row = math.floor((index - 1) / 4) / 4
    texture:SetTexCoord(col, col + 0.25, row, row + 0.25)
end

local function ApplyPreviewDispelGradient(texture, orientation, r, g, b, startAlpha, endAlpha)
    if not texture then return end
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    startAlpha = tonumber(startAlpha) or 0
    endAlpha = tonumber(endAlpha) or 0
    if not (r and g and b) then
        texture:SetColorTexture(0, 0, 0, 0)
        return
    end
    if texture.SetGradient and _G.CreateColor then
        local minColor = _G.CreateColor(r, g, b, startAlpha)
        local maxColor = _G.CreateColor(r, g, b, endAlpha)
        local ok = pcall(texture.SetGradient, texture, orientation, minColor, maxColor)
        if ok then return end
    end
    if texture.SetGradientAlpha then
        local ok = pcall(texture.SetGradientAlpha, texture, orientation, r, g, b, startAlpha, r, g, b, endAlpha)
        if ok then return end
    end
    texture:SetVertexColor(r, g, b, math.max(startAlpha or 0, endAlpha or 0))
end

local function SetPreviewDispelBorder(unit, color, alpha, thickness, gradientAlpha, gradientSize)
    local border = unit and unit.dispelBorder
    if not border then return end
    if not color then
        for _, edge in ipairs(border) do
            edge:Hide()
        end
        if border.gradientTop then border.gradientTop:Hide() end
        if border.gradientBottom then border.gradientBottom:Hide() end
        if border.gradientLeft then border.gradientLeft:Hide() end
        if border.gradientRight then border.gradientRight:Hide() end
        return
    end
    thickness = math.max(1, math.min(4, tonumber(thickness) or 2))
    alpha = tonumber(alpha) or 1.0
    gradientAlpha = tonumber(gradientAlpha) or 1.0
    gradientSize = math.max(0.12, math.min(0.60, tonumber(gradientSize) or 0.5))
    border[1]:SetHeight(thickness)
    border[2]:SetHeight(thickness)
    border[3]:SetWidth(thickness)
    border[4]:SetWidth(thickness)
    for _, edge in ipairs(border) do
        edge:SetColorTexture(color.r, color.g, color.b, alpha)
        edge:Show()
    end
    local width = unit:GetWidth() or 1
    local height = unit:GetHeight() or 1
    local edgeH = math.max(thickness + 3, math.floor(height * gradientSize))
    local edgeW = math.max(thickness + 3, math.floor(width * gradientSize))
    local fadeAlpha = math.min(tonumber(gradientAlpha) or 1.0, alpha * 0.9)
    if border.gradientTop then
        border.gradientTop:SetTexture(PREVIEW_WHITE)
        border.gradientTop:SetHeight(edgeH)
        ApplyPreviewDispelGradient(border.gradientTop, "VERTICAL", color.r, color.g, color.b, 0, fadeAlpha)
        border.gradientTop:SetBlendMode("BLEND")
        border.gradientTop:Show()
    end
    if border.gradientBottom then
        border.gradientBottom:SetTexture(PREVIEW_WHITE)
        border.gradientBottom:SetHeight(edgeH)
        ApplyPreviewDispelGradient(border.gradientBottom, "VERTICAL", color.r, color.g, color.b, fadeAlpha, 0)
        border.gradientBottom:SetBlendMode("BLEND")
        border.gradientBottom:Show()
    end
    if border.gradientLeft then
        border.gradientLeft:SetTexture(PREVIEW_WHITE)
        border.gradientLeft:SetWidth(edgeW)
        ApplyPreviewDispelGradient(border.gradientLeft, "HORIZONTAL", color.r, color.g, color.b, fadeAlpha, 0)
        border.gradientLeft:SetBlendMode("BLEND")
        border.gradientLeft:Show()
    end
    if border.gradientRight then
        border.gradientRight:SetTexture(PREVIEW_WHITE)
        border.gradientRight:SetWidth(edgeW)
        ApplyPreviewDispelGradient(border.gradientRight, "HORIZONTAL", color.r, color.g, color.b, 0, fadeAlpha)
        border.gradientRight:SetBlendMode("BLEND")
        border.gradientRight:Show()
    end
end

local function HidePreviewAuraIcon(icon)
    if not icon then return end
    icon.icon:SetTexture(nil)
    if icon.border then
        for _, edge in ipairs(icon.border) do
            edge:SetColorTexture(0, 0, 0, 0.8)
        end
    end
    icon:Hide()
end

local function RenderPreviewAuraIcon(icon, texture, color)
    if not icon then return end
    if not texture then
        HidePreviewAuraIcon(icon)
        return
    end
    icon.icon:SetTexture(texture)
    local r, g, b = 0, 0, 0
    if color then
        r, g, b = color.r or 0, color.g or 0, color.b or 0
    end
    if icon.border then
        for _, edge in ipairs(icon.border) do
            edge:SetColorTexture(r, g, b, 1.0)
        end
    end
    icon:Show()
end

local function EnsureUnit(preview, index)
    preview.units = preview.units or {}
    local unit = preview.units[index]
    if unit then return unit end

    unit = CreateFrame("Button", nil, preview.canvas)
    unit:SetHighlightTexture("")
    unit:EnableMouse(true)
    AddSimpleBorder(unit, 0.88)
    SetEdgeBorder(unit, 0.00, 0.55, 0.78, 0.85)

    unit.health = CreateFrame("StatusBar", nil, unit)
    unit.health:SetPoint("TOPLEFT", 3, -3)
    unit.health:SetPoint("TOPRIGHT", -3, -3)
    unit.health:SetMinMaxValues(0, 100)
    unit.health:SetStatusBarTexture(PREVIEW_FILL)
    unit.health.bg = unit.health:CreateTexture(nil, "BACKGROUND")
    unit.health.bg:SetAllPoints()
    unit.health.bg:SetTexture(PREVIEW_BG)
    unit.health.bg:SetVertexColor(0.06, 0.06, 0.07, 1)

    unit.absorb = CreateFrame("StatusBar", nil, unit.health)
    unit.absorb:SetMinMaxValues(0, 100)
    unit.absorb:SetReverseFill(true)
    unit.absorb:SetFrameLevel(unit.health:GetFrameLevel() + 2)
    unit.absorb:SetStatusBarTexture(PREVIEW_FILL)
    unit.absorb:Hide()

    unit.power = CreateFrame("StatusBar", nil, unit)
    unit.power:SetStatusBarTexture(PREVIEW_FILL)
    unit.power:SetStatusBarColor(0.22, 0.45, 0.95, 0.9)
    unit.power.bg = unit.power:CreateTexture(nil, "BACKGROUND")
    unit.power.bg:SetAllPoints()
    unit.power.bg:SetTexture(PREVIEW_BG)
    unit.power.bg:SetVertexColor(0.03, 0.03, 0.04, 1)

    unit.overlayFrame = CreateFrame("Frame", nil, unit)
    unit.overlayFrame:SetAllPoints(unit.health)
    unit.overlayFrame:SetFrameLevel(unit.health:GetFrameLevel() + 5)

    unit.dispelOverlay = unit.health:CreateTexture(nil, "ARTWORK", nil, 5)
    unit.dispelOverlay:SetAllPoints(unit.health)
    unit.dispelOverlay:SetTexture(PREVIEW_WHITE)
    unit.dispelOverlay:SetBlendMode("ADD")
    unit.dispelOverlay:Hide()
    unit.dispelBorderFrame = CreateFrame("Frame", nil, unit)
    unit.dispelBorderFrame:SetAllPoints(unit)
    unit.dispelBorderFrame:SetFrameLevel(unit:GetFrameLevel() + 16)
    unit.dispelBorder = CreatePreviewDispelBorder(unit.dispelBorderFrame)

    unit.name = unit.overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unit.name:SetJustifyH("LEFT")
    unit.name:SetWordWrap(false)
    unit.name:SetTextColor(1, 1, 1, 1)
    if unit.name.SetNonSpaceWrap then unit.name:SetNonSpaceWrap(false) end

    unit.value = unit.overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unit.value:SetJustifyH("RIGHT")
    unit.value:SetWordWrap(false)
    unit.value:SetTextColor(1, 1, 1, 1)
    if unit.value.SetNonSpaceWrap then unit.value:SetNonSpaceWrap(false) end

    unit.roleIcon = unit.overlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    unit.roleIcon:SetSize(18, 18)
    unit.roleIcon:Hide()

    unit.leaderIcon = CreatePreviewOverlayIcon(unit.overlayFrame, 12)
    unit.raidTargetIcon = CreatePreviewOverlayIcon(unit, 16)
    unit.readyCheckIcon = CreatePreviewOverlayIcon(unit.overlayFrame, 16)

    unit.status = unit.overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unit.status:SetJustifyH("CENTER")
    unit.status:SetWordWrap(false)
    unit.status:SetTextColor(1, 1, 1, 1)
    if unit.status.SetNonSpaceWrap then unit.status:SetNonSpaceWrap(false) end
    unit.status:Hide()

    unit.statusIconFrame = CreateFrame("Frame", nil, unit)
    unit.statusIconFrame:SetAllPoints(unit.health)
    unit.statusIconFrame:SetFrameLevel(unit.dispelBorderFrame:GetFrameLevel() + 2)
    unit.statusIcon = unit.statusIconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    unit.statusIcon:SetSize(20, 20)
    unit.statusIcon:SetPoint("CENTER", unit.health, "CENTER", 0, 0)
    unit.statusIcon:Hide()

    unit.auraFrame = CreateFrame("Frame", nil, unit)
    unit.auraFrame:SetAllPoints(unit)
    unit.auraFrame:SetFrameLevel(unit.overlayFrame:GetFrameLevel() + 2)
    unit.auraFrame:SetFrameStrata(unit:GetFrameStrata())
    unit.buffIcons = {}
    unit.debuffIcons = {}
    for i = 1, 5 do
        unit.buffIcons[i] = CreatePreviewAuraIcon(unit.auraFrame)
        unit.debuffIcons[i] = CreatePreviewAuraIcon(unit.auraFrame)
    end
    unit.ccIcon = CreatePreviewAuraIcon(unit.auraFrame)
    unit.ccText = unit.ccIcon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unit.ccText:SetPoint("CENTER")
    unit.ccText:SetText(LText("CC"))
    unit.ccText:SetTextColor(1, 0.16, 0.16, 1)
    unit.ccText:SetShadowColor(0, 0, 0, 1)
    unit.ccText:SetShadowOffset(1, -1)
    unit.missingBuffIcon = CreatePreviewAuraIcon(unit.auraFrame)
    unit.missingText = unit.missingBuffIcon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unit.missingText:SetPoint("BOTTOM", 0, -1)
    unit.missingText:SetText("!")
    unit.missingText:SetTextColor(1, 0.12, 0.12, 1)
    unit.missingText:SetShadowColor(0, 0, 0, 1)
    unit.missingText:SetShadowOffset(1, -1)
    unit.missingText:Hide()

    unit:SetScript("OnClick", function()
        local mode = preview.mode or activeMode
        local mod = GetMod()
        if mod and mod.HighlightVisibleFrames then
            mod:HighlightVisibleFrames()
        end
        rosterMode = mode == "raid40" and "raid" or mode
        activeMode = mode
        RefreshPage()
        C_Timer.After(0, function()
            if KT and KT.SmoothScrollTo then KT.SmoothScrollTo(0) end
        end)
    end)

    preview.units[index] = unit
    return unit
end

local function RefreshLivePreview(preview)
    local mod = GetMod()
    local mode = preview.mode or activeMode
    local configMode = mode
    local cfg = mod and mod.GetLayoutConfig and mod:GetLayoutConfig(configMode) or nil
    local db = mod and mod.GetModeDB and mod:GetModeDB(configMode) or nil
    cfg = cfg or db or {}

    local includePlayer = configMode ~= "raid" and cfg.showPlayer ~= false
    local count = includePlayer and 5 or 4
    if preview.includePlayerOverride ~= nil then
        includePlayer = preview.includePlayerOverride and true or false
        count = includePlayer and 5 or 4
    end
    if mode == "raid40" then
        count = 40
    elseif configMode == "raid" then
        count = math.max(5, math.min(40, tonumber((db and db.raidTestFrameCount) or 20) or 20))
    elseif mode == "arena" or mode == "arenaEnemy" then
        count = 3
    elseif mode == "boss" then
        count = 5
    end
    if preview.countOverride then
        count = math.max(1, math.floor(tonumber(preview.countOverride) or count))
    end
    local rawW = tonumber(preview.frameWidthOverride) or tonumber(cfg.frameWidth) or 125
    local rawH = tonumber(preview.frameHeightOverride) or tonumber(cfg.frameHeight) or 64
    local spacing = tonumber(preview.frameSpacingOverride) or tonumber(cfg.frameSpacing) or 2
    local scale = tonumber(preview.frameScaleOverride) or tonumber(cfg.frameScale) or 1
    local direction = preview.directionOverride or cfg.growDirection or "HORIZONTAL"
    local isRaidMode = configMode == "raid" or configMode == "raid40"
    local grouped = isRaidMode and cfg.raidUseGroups ~= false

    local canvasW = math.max(240, preview.canvas:GetWidth() or 240)
    local canvasH = math.max(112, preview.canvas:GetHeight() or 112)
    local cols, rows
    local ppg = tonumber(cfg.raidPlayersPerRow) or 5
    local maxGroups = tonumber(cfg.raidGroupsPerRow) or 8

    if isRaidMode and grouped then
        cols = math.max(1, math.min(maxGroups, math.ceil(count / ppg)))
        local totalGroups = math.ceil(count / ppg)
        rows = math.max(1, (math.floor((totalGroups - 1) / maxGroups) + 1) * ppg)
    elseif isRaidMode then
        cols = math.max(5, math.floor(canvasW / 72))
        cols = math.max(1, math.min(cols, count))
        rows = math.max(1, math.ceil(count / cols))
    elseif direction == "VERTICAL" then
        cols = 1
        rows = math.max(1, count)
    else
        cols = math.max(1, count)
        rows = 1
    end

    local targetW = rawW * scale
    local targetH = rawH * scale
    local targetAuraReserve = GetPreviewExternalAuraReserve(cfg, configMode) * scale
    local fitW = (canvasW - ((cols - 1) * math.max(0, spacing))) / cols
    local fitH = (canvasH - ((rows - 1) * math.max(0, spacing))) / rows
    local fitLimit = preview.allowUpscale == false and 1 or 1.25
    local fit = math.min(fitLimit, fitW / targetW, fitH / targetH)
    if targetAuraReserve > 0 then
        fit = math.min(fit, fitH / (targetH + targetAuraReserve))
    end
    if fit <= 0 or fit ~= fit then fit = 1 end

    local w = math.max(38, math.floor(targetW * fit))
    local h = math.max(22, math.floor(targetH * fit))
    local auraReserve = math.max(0, math.floor(targetAuraReserve * fit))
    local gap = math.max(1, math.floor(spacing * fit))
    local layoutGap = gap
    if configMode == "party" and auraReserve > 0 then
        layoutGap = math.max(gap, math.floor(6 * fit))
    end
    local gridW = (cols * w) + ((cols - 1) * gap)
    local gridH = (rows * (h + auraReserve)) + ((rows - 1) * layoutGap)
    local startX = math.floor((canvasW - gridW) * 0.5)
    local startY = -math.floor((canvasH - gridH) * 0.5)

    if preview.title then
        local suffix = grouped and "grouped raid" or (isRaidMode and "flat raid" or direction:lower())
        preview.title:SetText(LTextFmt("Party Frames %s preview - %s", LText(mode), LText(suffix)))
    end
    if preview.partyBtn and preview.partyBtn.text and mod and mod.IsTestMode then
        preview.partyBtn.text:SetText(LText(mod:IsTestMode("party") and "Stop Party Test" or "Party Test"))
    end
    if preview.raidBtn and preview.raidBtn.text and mod and mod.IsTestMode then
        preview.raidBtn.text:SetText(LText(mod:IsTestMode("raid") and "Stop Raid Test" or "Raid Test"))
    end
    if preview.raid40Btn and preview.raid40Btn.text and mod and mod.IsTestMode then
        preview.raid40Btn.text:SetText(LText(mod:IsTestMode("raid40") and "Stop Raid 40 Test" or "Raid 40 Test"))
    end
    if preview.arenaBtn and preview.arenaBtn.text and mod and mod.IsTestMode then
        preview.arenaBtn.text:SetText(LText(mod:IsTestMode("arena") and "Stop Arena Test" or "Arena Test"))
    end
    if preview.arenaEnemyBtn and preview.arenaEnemyBtn.text and mod and mod.IsTestMode then
        preview.arenaEnemyBtn.text:SetText(LText(mod:IsTestMode("arenaEnemy") and "Stop Enemy Arena Test" or "Enemy Arena Test"))
    end
    
    local isArena = (mode == "arena" or mode == "arenaEnemy")
    if preview.partyBtn then preview.partyBtn:SetShown(not isArena) end
    if preview.raidBtn then preview.raidBtn:SetShown(not isArena) end
    if preview.raid40Btn then preview.raid40Btn:SetShown(not isArena) end
    if preview.arenaBtn then preview.arenaBtn:SetShown(isArena) end
    if preview.arenaEnemyBtn then preview.arenaEnemyBtn:SetShown(isArena) end
    
    if isArena and preview.arenaBtn then
        if preview.stopBtn then preview.stopBtn:SetPoint("LEFT", preview.arenaEnemyBtn, "RIGHT", 8, 0) end
    elseif preview.partyBtn then
        if preview.stopBtn then preview.stopBtn:SetPoint("LEFT", preview.raid40Btn, "RIGHT", 8, 0) end
    end

    for i = 1, count do
        local unit = EnsureUnit(preview, i)
        local sample = GetPreviewUnit(i, count, mode, includePlayer)
        local col, row
        if isRaidMode and grouped then
            local groupIndex = math.floor((i - 1) / ppg)
            local indexInGroup = (i - 1) % ppg
            col = groupIndex % maxGroups
            row = (math.floor(groupIndex / maxGroups) * ppg) + indexInGroup
        else
            col = (i - 1) % cols
            row = math.floor((i - 1) / cols)
        end
        unit:ClearAllPoints()
        unit:SetPoint("TOPLEFT", preview.canvas, "TOPLEFT", startX + (col * (w + gap)), startY - (row * (h + auraReserve + layoutGap)))
        unit:SetSize(w, h)
        unit:Show()

        local role = sample.role or "DAMAGER"
        local color = GetPreviewColor(sample, cfg, i, count, includePlayer)
        local padding = math.max(0, math.floor((tonumber(cfg.framePadding) or 0) * fit))
        local powerHeight = math.max(4, math.floor((tonumber(cfg.powerBarHeight) or 4) * fit))
        local showPower = cfg.showPowerBar == true
        unit.health:ClearAllPoints()
        unit.power:ClearAllPoints()
        unit.health:SetPoint("TOPLEFT", unit, "TOPLEFT", padding, -padding)
        unit.health:SetPoint("TOPRIGHT", unit, "TOPRIGHT", -padding, -padding)
        if showPower then
            unit.power:SetPoint("BOTTOMLEFT", unit, "BOTTOMLEFT", padding, padding)
            unit.power:SetPoint("BOTTOMRIGHT", unit, "BOTTOMRIGHT", -padding, padding)
            unit.power:SetHeight(powerHeight)
            unit.health:SetPoint("BOTTOMRIGHT", unit.power, "TOPRIGHT", 0, 1)
        else
            unit.health:SetPoint("BOTTOMRIGHT", unit, "BOTTOMRIGHT", -padding, padding)
            unit.power:SetHeight(powerHeight)
        end
        unit.health:SetStatusBarTexture(ResolveStatusbarTexture(cfg.healthTexture, PREVIEW_FILL))
        unit.health:SetValue((sample.health or 0.75) * 100)
        unit.health:SetStatusBarColor(color[1], color[2], color[3], 0.9)
        unit.health.bg:SetVertexColor(color[1] * 0.18, color[2] * 0.18, color[3] * 0.18, 1)
        unit.power:SetMinMaxValues(0, 100)
        unit.power:SetStatusBarTexture(ResolveStatusbarTexture(cfg.healthTexture, PREVIEW_FILL))
        unit.power:SetValue((sample.power or 0.7) * 100)
        unit.power:SetShown(showPower)
        if sample.status == "Offline" then
            unit.health:SetStatusBarColor(OFFLINE_HEALTH_COLOR[1], OFFLINE_HEALTH_COLOR[2], OFFLINE_HEALTH_COLOR[3], OFFLINE_HEALTH_COLOR[4])
            unit.health.bg:SetVertexColor(0.09, 0.10, 0.11, 1)
            unit.power:SetStatusBarColor(OFFLINE_POWER_COLOR[1], OFFLINE_POWER_COLOR[2], OFFLINE_POWER_COLOR[3], OFFLINE_POWER_COLOR[4])
            unit.power.bg:SetVertexColor(0.06, 0.07, 0.08, 1)
        else
            unit.power:SetStatusBarColor(0.22, 0.45, 0.95, 0.9)
            unit.power.bg:SetVertexColor(0.04, 0.04, 0.05, 1)
        end
        unit.absorb:ClearAllPoints()
        unit.absorb:SetPoint("TOPRIGHT", unit.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        unit.absorb:SetPoint("BOTTOMRIGHT", unit.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
        unit.absorb:SetWidth(math.max(1, w - (padding * 2)))
        unit.absorb:SetStatusBarTexture(ResolveStatusbarTexture(cfg.absorbBarTexture, PREVIEW_FILL))
        unit.absorb:SetStatusBarColor(0.11, 1.00, 0.62, 0.82)
        unit.absorb:SetValue((sample.absorb or 0) * 100)
        unit.absorb:SetShown(cfg.showAbsorbBar ~= false and (sample.absorb or 0) > 0)

        local auraSize = math.max(10, math.min(28, math.floor((tonumber(cfg.auraIconSize) or 20) * fit)))
        local auraGap = math.max(0, math.min(8, math.floor((tonumber(cfg.auraIconSpacing) or 0) * fit)))
        local missingSize = math.max(14, math.min(44, math.floor((tonumber(cfg.missingBuffIconSize) or 30) * fit)))
        local fitBuffs, fitDebuffs = 5, 5
        if ns.GetAuraFitLimits then
            fitBuffs, fitDebuffs = ns.GetAuraFitLimits(w, cfg, configMode)
        end
        local maxBuffs = math.max(0, math.min(5, fitBuffs, tonumber(cfg.auraMaxBuffs) or 5))
        local maxDebuffs = math.max(0, math.min(5, fitDebuffs, tonumber(cfg.auraMaxDebuffs) or 5))
        local buffX = math.floor((tonumber(cfg.buffIconsOffsetX) or 0) * fit)
        local buffY = math.floor((tonumber(cfg.buffIconsOffsetY) or 0) * fit)
        local debuffX = math.floor((tonumber(cfg.debuffIconsOffsetX) or 0) * fit)
        local debuffY = math.floor((tonumber(cfg.debuffIconsOffsetY) or 0) * fit)
        local auraX = math.floor((tonumber(cfg.auraIconOffsetX) or 0) * fit)
        local auraY = math.floor((tonumber(cfg.auraIconOffsetY) or 0) * fit)
        local missingX = math.floor((tonumber(cfg.missingBuffOffsetX) or 0) * fit)
        local missingY = math.floor((tonumber(cfg.missingBuffOffsetY) or 0) * fit)
        local debuffAnchor = ANCHOR_VALUES[cfg.debuffAnchor] and cfg.debuffAnchor or (isRaidMode and "BOTTOMLEFT" or "CENTER")
        local debuffGrowthH = FLOW_VALUES[cfg.debuffGrowthH] and cfg.debuffGrowthH or "RIGHT"
        local debuffGrowthV = FLOW_VALUES[cfg.debuffGrowthV] and cfg.debuffGrowthV or "DOWN"
        local debuffStartX = debuffX
        if debuffAnchor == "CENTER" and maxDebuffs > 1 then
            local centerShift = ((maxDebuffs - 1) * (math.max(auraSize, isRaidMode and 22 or 24) + auraGap)) * 0.5
            debuffStartX = debuffX + (debuffGrowthH == "LEFT" and centerShift or -centerShift)
        end
        if configMode == "party" and direction == "VERTICAL" then
            buffY = buffY + math.floor(PARTY_VERTICAL_BUFF_TOP_OFFSET * fit)
        end
        local canShowAuras = not sample.status
        for j, icon in ipairs(unit.buffIcons or {}) do
            icon:ClearAllPoints()
            local iconSize = auraSize
            icon:SetSize(iconSize, iconSize)
            if j == 1 then
                icon:SetPoint("TOPRIGHT", unit.health, "TOPRIGHT", -3 + buffX, -3 + buffY)
            else
                icon:SetPoint("RIGHT", unit.buffIcons[j - 1], "LEFT", -auraGap, 0)
            end
            local sampleIndex = ((i + j - 2) % #AURA_SAMPLE_BUFFS) + 1
            local spellID = AURA_SAMPLE_BUFF_IDS[sampleIndex]
            local spellVisible = not (mod and mod.IsAuraSpellVisible) or mod:IsAuraSpellVisible(configMode, spellID) ~= false
            local show = canShowAuras and spellVisible and cfg.showAuras ~= false and j <= maxBuffs and j <= 2 + (i % 2)
            RenderPreviewAuraIcon(icon, show and AURA_SAMPLE_BUFFS[sampleIndex] or nil)
        end
        for j, icon in ipairs(unit.debuffIcons or {}) do
            icon:ClearAllPoints()
            local iconSize = math.max(auraSize, isRaidMode and 22 or 24)
            icon:SetSize(iconSize, iconSize)
            if j == 1 then
                icon:SetPoint(debuffAnchor, unit.health, debuffAnchor, debuffStartX, debuffY + (isRaidMode and -3 or 0))
            elseif debuffGrowthH == "LEFT" then
                icon:SetPoint("RIGHT", unit.debuffIcons[j - 1], "LEFT", -auraGap, 0)
            else
                icon:SetPoint("LEFT", unit.debuffIcons[j - 1], "RIGHT", auraGap, 0)
            end
            local sampleDebuff = GetPreviewDebuffSample(i, j, configMode)
            local spellVisible = not (mod and mod.IsAuraSpellVisible) or mod:IsAuraSpellVisible(configMode, sampleDebuff.spellID) ~= false
            local show = canShowAuras and spellVisible and cfg.showAuras ~= false and cfg.showDebuffs ~= false and j <= maxDebuffs
            RenderPreviewAuraIcon(icon, show and sampleDebuff.icon or nil, show and sampleDebuff.color or nil)
        end
        unit.ccIcon:ClearAllPoints()
        unit.ccIcon:SetSize(math.max(auraSize, isRaidMode and 16 or 18), math.max(auraSize, isRaidMode and 16 or 18))
        unit.ccIcon:SetPoint("CENTER", unit.health, "CENTER", auraX, auraY)
        local ccVisible = not (mod and mod.IsAuraSpellVisible) or mod:IsAuraSpellVisible(configMode, 118) ~= false
        RenderPreviewAuraIcon(unit.ccIcon, canShowAuras and ccVisible and cfg.showAuras ~= false and cfg.showCrowdControl ~= false and i % 3 == 1 and 136071 or nil, { r = 1, g = 0.12, b = 0.12 })
        unit.missingBuffIcon:ClearAllPoints()
        if isRaidMode then
            unit.missingBuffIcon:SetSize(missingSize, missingSize)
            unit.missingBuffIcon:SetPoint("CENTER", unit.health, "CENTER", missingX, missingY)
        else
            local partyMissingSize = math.min(missingSize, 29)
            unit.missingBuffIcon:SetSize(partyMissingSize, partyMissingSize)
            unit.missingBuffIcon:SetPoint("CENTER", unit.health, "CENTER", missingX, missingY)
        end
        local missingRule = GetPreviewMissingBuffRule(cfg)
        local missingVisible = missingRule and (not (mod and mod.IsAuraSpellVisible) or mod:IsAuraSpellVisible(configMode, missingRule.spellID) ~= false)
        RenderPreviewAuraIcon(unit.missingBuffIcon, canShowAuras and missingVisible and cfg.showAuras ~= false and i % 5 == 2 and missingRule.icon or nil, { r = 1, g = 0.08, b = 0.08 })
        if unit.dispelOverlay then
            local overlayDebuff = GetPreviewDebuffSample(i, 1, configMode, 3)
            if canShowAuras and cfg.showDispelOverlay ~= false and not (ns.PF_TestNoDispelOverlay and ns.PF_TestNoDispelOverlay[i]) then
                unit.dispelOverlay:Hide()
                SetPreviewDispelBorder(unit, overlayDebuff.color, tonumber(cfg.dispelOverlayAlpha) or 1.0, tonumber(cfg.dispelBorderThickness) or 2, tonumber(cfg.dispelGradientAlpha) or 1.0, tonumber(cfg.dispelGradientSize) or 0.5)
            else
                unit.dispelOverlay:Hide()
                SetPreviewDispelBorder(unit, nil)
            end
        else
            SetPreviewDispelBorder(unit, nil)
        end
        if sample.status == "Dead" then
            unit.statusIcon:SetTexture(PREVIEW_ICON_PATH .. "Dead.png")
            unit.statusIcon:Show()
            unit.statusIcon:SetAlpha(1)
            unit.name:SetAlpha(isRaidMode and 0.3 or 1)
        elseif sample.status == "Offline" then
            unit.statusIcon:SetTexture(PREVIEW_ICON_PATH .. "Offline.png")
            unit.statusIcon:Show()
            unit.statusIcon:SetAlpha(1)
            unit.name:SetAlpha(isRaidMode and 0.3 or 1)
        elseif sample.status == "AFK" then
            unit.statusIcon:SetTexture(PREVIEW_ICON_PATH .. "AFK.png")
            unit.statusIcon:Show()
            unit.statusIcon:SetAlpha(1)
            unit.name:SetAlpha(isRaidMode and 0.3 or 1)
        else
            unit.statusIcon:Hide()
            unit.statusIcon:SetAlpha(1)
            unit.name:SetAlpha(1)
        end
        local maxName = isRaidMode and math.floor(h * 0.40) or nil
        local maxValue = isRaidMode and math.floor(h * 0.35) or nil
        ApplyPreviewFont(unit.name, cfg, "nameFontSize", isRaidMode and 11 or 15, maxName)
        ApplyPreviewFont(unit.value, cfg, "healthTextFontSize", isRaidMode and 11 or 12, maxValue)
        ApplyPreviewFont(unit.status, cfg, "healthTextFontSize", isRaidMode and 11 or 12, maxValue)

        local nx = tonumber(cfg.nameOffsetX) or 0
        local ny = tonumber(cfg.nameOffsetY) or 0
        local hx = tonumber(cfg.healthOffsetX) or 0
        local hy = tonumber(cfg.healthOffsetY) or 0

        local innerWidth = math.max(1, w - (padding * 2))
        unit.name:ClearAllPoints()
        unit.value:ClearAllPoints()
        local maxChars
        local statusValueWidth = math.min(70, innerWidth)
        if targetH >= 70 or (w < 140 and targetH >= 40) then
            maxChars = math.max(3, math.floor(innerWidth / ((tonumber(cfg.nameFontSize) or (isRaidMode and 11 or 15)) * 0.58)))
            unit.name:SetJustifyH("CENTER")
            unit.name:SetPoint("CENTER", unit.health, "CENTER", 0 + nx, 10 + ny)
            unit.name:SetWidth(innerWidth - 12)
            unit.name:SetHeight(18)
            unit.value:SetJustifyH("CENTER")
            unit.value:SetPoint("CENTER", unit.health, "CENTER", 0 + hx, -10 + hy)
            unit.value:SetWidth(innerWidth - 12)
            unit.value:SetHeight(16)
        else
            local format = cfg.healthTextFormat or "CURRENTMAX"
            local valueWidth
            if format == "NONE" then
                valueWidth = 1
            elseif format == "PERCENT" then
                valueWidth = 38
            else
                valueWidth = math.min(math.max(72, math.floor(innerWidth * 0.44)), math.max(44, innerWidth - 34))
            end
            statusValueWidth = valueWidth
            local reserveRoleIcon = configMode == "arena" or configMode == "arenaEnemy"
                or (configMode == "party" and direction == "VERTICAL")
            local nameLeftInset = reserveRoleIcon and math.max(6, math.floor(PARTY_VERTICAL_NAME_LEFT_INSET * fit)) or 6
            local nameWidth = math.max(24, innerWidth - valueWidth - 16 - (nameLeftInset - 6))
            maxChars = math.max(3, math.floor(nameWidth / ((tonumber(cfg.nameFontSize) or (isRaidMode and 11 or 15)) * 0.58)))
            unit.name:SetJustifyH("LEFT")
            unit.name:SetPoint("LEFT", unit.health, "LEFT", nameLeftInset + nx, 0 + ny)
            unit.name:SetWidth(nameWidth)
            unit.name:SetHeight(math.max(12, h - (padding * 2)))
            unit.value:SetJustifyH("RIGHT")
            unit.value:SetPoint("RIGHT", unit.health, "RIGHT", -6 + hx, 0 + hy)
            unit.value:SetWidth(valueWidth)
            unit.value:SetHeight(math.max(12, h - (padding * 2)))
        end
        unit.status:ClearAllPoints()
        unit.status:SetJustifyH("CENTER")
        local centeredStatus = targetH >= 70 or (w < 140 and targetH >= 40)
        local horizontalCenteredStatus = centeredStatus and direction == "HORIZONTAL"
        if isRaidMode and (targetH >= 70 or (w < 140 and targetH >= 40)) then
            unit.status:SetWidth(innerWidth - 12)
            unit.status:SetHeight(14)
            unit.status:SetPoint("CENTER", unit.health, "CENTER", 0, -12)
        elseif centeredStatus then
            unit.status:SetJustifyH(horizontalCenteredStatus and "CENTER" or "LEFT")
            unit.status:SetWidth(horizontalCenteredStatus and math.min(90, innerWidth - 12) or math.min(70, innerWidth - 24))
            unit.status:SetHeight(16)
            unit.status:SetPoint("CENTER", unit.health, "CENTER", horizontalCenteredStatus and 0 or 12, horizontalCenteredStatus and -3 or 0)
        else
            unit.status:SetJustifyH("LEFT")
            unit.status:SetWidth(math.max(34, math.min(statusValueWidth, innerWidth - 24)))
            unit.status:SetHeight(math.max(12, h - (padding * 2)))
            unit.status:SetPoint("RIGHT", unit.health, "RIGHT", -6, 0)
        end
        unit.statusIcon:ClearAllPoints()
        if sample.status == "AFK" then
            unit.statusIcon:SetSize(32, 16)
            unit.statusIcon:SetAlpha(1)
        elseif isRaidMode then
            unit.statusIcon:SetSize(20, 20)
            unit.statusIcon:SetPoint("CENTER", unit.health, "CENTER", 0, 5)
            unit.statusIcon:SetAlpha(1)
        elseif centeredStatus then
            local iconSize = targetH >= 70 and 22 or 18
            unit.statusIcon:SetSize(iconSize, iconSize)
            unit.statusIcon:SetAlpha(1)
        else
            unit.statusIcon:SetSize(14, 14)
            unit.statusIcon:SetAlpha(1)
        end
        if not isRaidMode then
            unit.statusIcon:ClearAllPoints()
            if horizontalCenteredStatus then
                unit.statusIcon:SetPoint("TOP", unit.status, "BOTTOM", 0, -1)
            else
                unit.statusIcon:SetPoint("RIGHT", unit.status, "LEFT", -3, 0)
            end
        end
        unit.roleIcon:ClearAllPoints()
        unit.roleIcon:SetSize(18, 18)
        unit.roleIcon:SetPoint("BOTTOMLEFT", unit, "BOTTOMLEFT", 2, 2)
        unit.roleIcon:SetShown(true)

        unit.leaderIcon:ClearAllPoints()
        unit.leaderIcon:SetSize(12, 12)
        unit.leaderIcon:SetPoint("TOPLEFT", unit, "TOPLEFT", 0, 1)
        unit.raidTargetIcon:ClearAllPoints()
        unit.raidTargetIcon:SetSize(16, 16)
        unit.raidTargetIcon:SetPoint("BOTTOMRIGHT", unit, "BOTTOMRIGHT", -2, 2)
        unit.readyCheckIcon:ClearAllPoints()
        unit.readyCheckIcon:SetSize(16, 16)
        unit.readyCheckIcon:SetScale(1.6)
        unit.readyCheckIcon:SetPoint("CENTER", unit, "CENTER", 0, 0)

        unit.name:SetText(FitText(sample.name or SAMPLE_NAMES[((i - 1) % #SAMPLE_NAMES) + 1], maxChars))
        unit.name:Show()
        if sample.status then
            -- Show status in the value slot (right side / below) instead of hiding name
            if targetH >= 70 or (w < 140 and targetH >= 40) then
                -- Tall frame: status text centered below the icon
                unit.value:SetText("")
                unit.value:Hide()
                unit.status:SetText(sample.status)
                unit.status:Show()
            else
                -- Flat frame: name left, status text in value position (right)
                unit.value:SetText("")
                unit.value:Hide()
                unit.status:SetText(sample.status)
                unit.status:Show()
            end
        else
            if targetH >= 70 or (w < 140 and targetH >= 40) then
                unit.value:SetJustifyH("CENTER")
            else
                unit.value:SetJustifyH("RIGHT")
            end
            unit.status:Hide()
            unit.value:SetText(FormatPreviewHealth(sample, cfg, sample.health))
            unit.value:Show()
        end
        
        local style = cfg.roleIconStyle or "BLIZZARD"
        if role == "DAMAGER" or role == "HEALER" or role == "TANK" then
            if style == "KT" then
                unit.roleIcon:SetTexture(PREVIEW_ROLE_ICON_PATH .. (role == "DAMAGER" and "DPS" or (role == "HEALER" and "Healer" or "Tank")) .. ".png")
                unit.roleIcon:SetTexCoord(0, 1, 0, 1)
            else
                unit.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
                SetPreviewBlizzardRoleIconCoords(unit.roleIcon, role)
            end
            unit.roleIcon:Show()
        else
            unit.roleIcon:Hide()
        end
        if cfg.showLeaderIcon ~= false then
            if i == 1 then
                unit.leaderIcon.texture:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
                unit.leaderIcon:Show()
            elseif i == 2 then
                unit.leaderIcon.texture:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
                unit.leaderIcon:Show()
            else
                unit.leaderIcon:Hide()
            end
        else
            unit.leaderIcon:Hide()
        end
        if i % 5 == 0 then
            SetPreviewRaidTargetIcon(unit.raidTargetIcon.texture, ((i - 1) % 8) + 1)
            unit.raidTargetIcon:Show()
        else
            unit.raidTargetIcon:Hide()
        end
        if not sample.status and i % 6 == 0 then
            unit.readyCheckIcon.texture:SetTexture(i % 12 == 0 and "Interface\\RaidFrame\\ReadyCheck-NotReady" or "Interface\\RaidFrame\\ReadyCheck-Ready")
            unit.readyCheckIcon:Show()
        else
            unit.readyCheckIcon:Hide()
        end
        unit:SetAlpha(sample.status == "Offline" and 0.50 or (sample.status == "Dead" and 0.62 or 1))
    end

    if preview.units then
        for i = count + 1, #preview.units do
            preview.units[i]:Hide()
        end
    end
end

local function CreateLivePreview(parent, y, options)
    options = options or {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", options.x or 10, -(y or options.y or 10))
    frame:SetSize(options.width or (parent:GetWidth() - 20), options.height or 285)
    AddSimpleBorder(frame, 0.88)
    frame.mode = options.modeOverride or activeMode
    frame.directionOverride = options.directionOverride
    frame.countOverride = options.countOverride
    frame.frameWidthOverride = options.frameWidthOverride
    frame.frameHeightOverride = options.frameHeightOverride
    frame.frameSpacingOverride = options.frameSpacingOverride
    frame.frameScaleOverride = options.frameScaleOverride
    frame.allowUpscale = options.allowUpscale
    frame.includePlayerOverride = options.includePlayerOverride
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetJustifyH("LEFT")
    frame.title = title


    local canvas = CreateFrame("Frame", nil, frame)
    canvas:SetPoint("TOPLEFT", 12, -34)
    canvas:SetPoint("BOTTOMRIGHT", -12, options.controls == false and 12 or 44)
    canvas:SetClipsChildren(true)
    canvas:EnableMouseWheel(true)
    canvas:SetScript("OnMouseWheel", function(_, delta)
        local mode = frame.mode or activeMode
        if IsShiftKeyDown and IsShiftKeyDown() then
            NudgeValue(mode, "frameSpacing", delta > 0 and 1 or -1, -5, 50)
        else
            NudgeValue(mode, "frameScale", delta > 0 and 0.05 or -0.05, 0.5, 2)
        end
    end)
    frame.canvas = canvas

    local partyBtn = CreateFrame("Button", nil, frame)
    partyBtn:SetSize(102, 24)
    partyBtn:SetPoint("BOTTOMLEFT", 12, 12)
    AddSimpleBorder(partyBtn, 0.82)
    SetEdgeBorder(partyBtn, 0.35, 0.35, 0.40, 1)
    partyBtn.text = partyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    partyBtn.text:SetAllPoints()
    partyBtn.text:SetText(LText("Party Test"))
    partyBtn:SetScript("OnClick", function()
        RandomizePartyMemberColors()
        local mod = GetMod()
        if mod and mod.RandomizeTestAuras then mod:RandomizeTestAuras("party") end
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("party") end
        frame:Refresh()
        RefreshPage()
    end)
    frame.partyBtn = partyBtn

    local raidBtn = CreateFrame("Button", nil, frame)
    raidBtn:SetSize(102, 24)
    raidBtn:SetPoint("LEFT", partyBtn, "RIGHT", 8, 0)
    AddSimpleBorder(raidBtn, 0.82)
    SetEdgeBorder(raidBtn, 0.35, 0.35, 0.40, 1)
    raidBtn.text = raidBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raidBtn.text:SetAllPoints()
    raidBtn.text:SetText(LText("Raid Test"))
    raidBtn:SetScript("OnClick", function()
        RandomizePartyMemberColors()
        local mod = GetMod()
        if mod and mod.RandomizeTestAuras then mod:RandomizeTestAuras("raid") end
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("raid") end
        frame:Refresh()
        RefreshPage()
    end)
    frame.raidBtn = raidBtn

    local raid40Btn = CreateFrame("Button", nil, frame)
    raid40Btn:SetSize(102, 24)
    raid40Btn:SetPoint("LEFT", raidBtn, "RIGHT", 8, 0)
    AddSimpleBorder(raid40Btn, 0.82)
    SetEdgeBorder(raid40Btn, 0.35, 0.35, 0.40, 1)
    raid40Btn.text = raid40Btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    raid40Btn.text:SetAllPoints()
    raid40Btn.text:SetText(LText("Raid 40 Test"))
    raid40Btn:SetScript("OnClick", function()
        RandomizePartyMemberColors()
        local mod = GetMod()
        if mod and mod.RandomizeTestAuras then mod:RandomizeTestAuras("raid40") end
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("raid40") end
        frame:Refresh()
        RefreshPage()
    end)
    frame.raid40Btn = raid40Btn

    local arenaBtn = CreateFrame("Button", nil, frame)
    arenaBtn:SetSize(102, 24)
    arenaBtn:SetPoint("BOTTOMLEFT", 12, 12)
    AddSimpleBorder(arenaBtn, 0.82)
    SetEdgeBorder(arenaBtn, 0.35, 0.35, 0.40, 1)
    arenaBtn.text = arenaBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arenaBtn.text:SetAllPoints()
    arenaBtn.text:SetText(LText("Arena Test"))
    arenaBtn:SetScript("OnClick", function()
        RandomizePartyMemberColors()
        local mod = GetMod()
        if mod and mod.RandomizeTestAuras then mod:RandomizeTestAuras("arena") end
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("arena") end
        frame:Refresh()
        RefreshPage()
    end)
    frame.arenaBtn = arenaBtn

    local arenaEnemyBtn = CreateFrame("Button", nil, frame)
    arenaEnemyBtn:SetSize(115, 24)
    arenaEnemyBtn:SetPoint("LEFT", arenaBtn, "RIGHT", 8, 0)
    AddSimpleBorder(arenaEnemyBtn, 0.82)
    SetEdgeBorder(arenaEnemyBtn, 0.35, 0.35, 0.40, 1)
    arenaEnemyBtn.text = arenaEnemyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arenaEnemyBtn.text:SetAllPoints()
    arenaEnemyBtn.text:SetText(LText("Enemy Arena Test"))
    arenaEnemyBtn:SetScript("OnClick", function()
        RandomizePartyMemberColors()
        local mod = GetMod()
        if mod and mod.RandomizeTestAuras then mod:RandomizeTestAuras("arenaEnemy") end
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("arenaEnemy") end
        frame:Refresh()
        RefreshPage()
    end)
    frame.arenaEnemyBtn = arenaEnemyBtn
    
    local stopBtn = CreateFrame("Button", nil, frame)
    stopBtn:SetSize(102, 24)
    stopBtn:SetPoint("LEFT", raid40Btn, "RIGHT", 8, 0)
    AddSimpleBorder(stopBtn, 0.82)
    SetEdgeBorder(stopBtn, 0.35, 0.35, 0.40, 1)
    stopBtn.text = stopBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stopBtn.text:SetAllPoints()
    stopBtn.text:SetText(LText("Stop Tests"))
    stopBtn:SetScript("OnClick", function()
        local mod = GetMod()
        if mod and mod.HideAllTests then mod:HideAllTests() end
        frame:Refresh()
        RefreshPage()
    end)
    frame.stopBtn = stopBtn

    local scaleDown = CreateFrame("Button", nil, frame)
    scaleDown:SetSize(78, 24)
    scaleDown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -98, 12)
    AddSimpleBorder(scaleDown, 0.82)
    SetEdgeBorder(scaleDown, 0.35, 0.35, 0.40, 1)
    scaleDown.text = scaleDown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleDown.text:SetAllPoints()
    scaleDown.text:SetText(LText("Scale -"))
    scaleDown:SetScript("OnClick", function()
        NudgeValue(frame.mode or activeMode, "frameScale", -0.05, 0.5, 2)
    end)

    local scaleUp = CreateFrame("Button", nil, frame)
    scaleUp:SetSize(78, 24)
    scaleUp:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    AddSimpleBorder(scaleUp, 0.82)
    SetEdgeBorder(scaleUp, 0.35, 0.35, 0.40, 1)
    scaleUp.text = scaleUp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleUp.text:SetAllPoints()
    scaleUp.text:SetText(LText("Scale +"))
    scaleUp:SetScript("OnClick", function()
        NudgeValue(frame.mode or activeMode, "frameScale", 0.05, 0.5, 2)
    end)

    if options.controls == false then
        canvas:EnableMouseWheel(false)
        canvas:SetScript("OnMouseWheel", nil)
        partyBtn:Hide()
        raidBtn:Hide()
        raid40Btn:Hide()
        arenaBtn:Hide()
        arenaEnemyBtn:Hide()
        stopBtn:Hide()
        scaleDown:Hide()
        scaleUp:Hide()
    end
    -- Randomizar colores de los miembros del party al abrir el preview
    RandomizePartyMemberColors()
    frame.Refresh = RefreshLivePreview
    frame:SetScript("OnSizeChanged", function(self) self:Refresh() end)
    frame:Refresh()
    if options.attachSticky ~= false and KT and KT.AttachStickyPreview then
        KT:AttachStickyPreview(frame, {
            point = "TOPLEFT",
            relativePoint = "TOPLEFT",
            x = 10,
            y = -10,
            height = 285,
            extraPad = 10,
        })
    end
    if options.registerGlobal ~= false then
        livePreview = frame
    end
    return frame, (options.height or 285) + 28
end

_G.KullThranUI_PartyFramesOptions = _G.KullThranUI_PartyFramesOptions or {}
_G.KullThranUI_PartyFramesOptions.CreateLivePreview = CreateLivePreview
local function AddLayoutControls(container, W, mode)
    local configMode = mode
    local by = 0
    local _, h
    -- Grow Direction y Show Player primero (opciones de orientación/visibilidad más importantes)
    _, h = W:Dropdown(container, "Grow Direction", -by, DIRECTION_VALUES,
        function() return GetValue(configMode, "growDirection", "HORIZONTAL") end,
        function(v) ApplyValue(configMode, "growDirection", v) end,
        DIRECTION_ORDER
    ); by = by + h
    _, h = W:Toggle(container, "Show Aura Icons", -by,
        function() return GetValue(configMode, "showAuras", true) ~= false end,
        function(v) ApplyValue(configMode, "showAuras", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Show Buff Icons", -by,
        function() return GetValue(configMode, "showBuffs", true) ~= false end,
        function(v) ApplyValue(configMode, "showBuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Show Debuff Icons", -by,
        function() return GetValue(configMode, "showDebuffs", true) ~= false end,
        function(v) ApplyValue(configMode, "showDebuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Show Missing Class Buff", -by,
        function() return GetValue(configMode, "showMissingBuffs", true) ~= false end,
        function(v) ApplyValue(configMode, "showMissingBuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Show Ready Check Icons", -by,
        function() return GetValue(configMode, "showReadyCheckIcon", true) ~= false end,
        function(v) ApplyValue(configMode, "showReadyCheckIcon", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Show Leader Icons", -by,
        function() return GetValue(configMode, "showLeaderIcon", true) ~= false end,
        function(v) ApplyValue(configMode, "showLeaderIcon", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Show Raid Mark Icons", -by,
        function() return GetValue(configMode, "showRaidTargetIcon", true) ~= false end,
        function(v) ApplyValue(configMode, "showRaidTargetIcon", v and true or false) end
    ); by = by + h
    if configMode ~= "raid" and configMode ~= "raid40" then
        _, h = W:Toggle(container, "Show Player Frame", -by,
            function() return GetValue(configMode, "showPlayer", configMode ~= "party") ~= false end,
            function(v) ApplyValue(configMode, "showPlayer", v and true or false) end
        ); by = by + h
    end
    _, h = W:Slider(container, "Frame Width", -by,
        function() return GetValue(configMode, "frameWidth", 125) end,
        function(v) ApplyValue(configMode, "frameWidth", v) end,
        60, 300, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Frame Height", -by,
        function() return GetValue(configMode, "frameHeight", 64) end,
        function(v) ApplyValue(configMode, "frameHeight", v) end,
        20, 300, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Frame Scale", -by,
        function() return GetValue(configMode, "frameScale", 1) end,
        function(v) ApplyValue(configMode, "frameScale", v) end,
        0.5, 2, 0.05, "%.2f"
    ); by = by + h
    _, h = W:Slider(container, "Frame Spacing", -by,
        function() return GetValue(configMode, "frameSpacing", 2) end,
        function(v) ApplyValue(configMode, "frameSpacing", v) end,
        -5, 50, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Frame Padding", -by,
        function() return GetValue(configMode, "framePadding", 0) end,
        function(v) ApplyValue(configMode, "framePadding", v) end,
        0, 10, 1, "%d"
    ); by = by + h
    _, h = W:Dropdown(container, "Growth Anchor", -by, ANCHOR_VALUES,
        function() return GetValue(configMode, "growthAnchor", "CENTER") end,
        function(v) ApplyValue(configMode, "growthAnchor", v) end,
        ANCHOR_ORDER
    ); by = by + h
    _, h = W:Toggle(container, "Pixel Perfect", -by,
        function() return GetValue(configMode, "pixelPerfect", true) and true or false end,
        function(v) ApplyValue(configMode, "pixelPerfect", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Class Colors", -by,
        function() return GetValue(configMode, "colorByClass", true) ~= false end,
        function(v) ApplyValue(configMode, "colorByClass", v and true or false) end
    ); by = by + h
    _, h = W:Dropdown(container, "Health Bar Texture", -by, GetStatusbarValues,
        function() return GetValue(configMode, "healthTexture", PREVIEW_FILL) end,
        function(v) ApplyValue(configMode, "healthTexture", v) end
    ); by = by + h
    _, h = W:Dropdown(container, "Absorb Bar Texture", -by, GetStatusbarValues,
        function() return GetValue(configMode, "absorbBarTexture", PREVIEW_FILL) end,
        function(v) ApplyValue(configMode, "absorbBarTexture", v) end
    ); by = by + h
    _, h = W:Toggle(container, "Absorb Overlay", -by,
        function() return GetValue(configMode, "showAbsorbBar", true) ~= false end,
        function(v) ApplyValue(configMode, "showAbsorbBar", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Power Bar", -by,
        function() return GetValue(configMode, "showPowerBar", false) == true end,
        function(v) ApplyValue(configMode, "showPowerBar", v and true or false) end
    ); by = by + h
    _, h = W:Dropdown(container, "Health Text", -by, HEALTH_TEXT_VALUES,
        function() return GetValue(configMode, "healthTextFormat", "CURRENTMAX") end,
        function(v) ApplyValue(configMode, "healthTextFormat", v) end,
        HEALTH_TEXT_ORDER
    ); by = by + h
    _, h = W:Dropdown(container, "Role Icon Style", -by, ROLE_STYLE_VALUES,
        function() return GetValue(configMode, "roleIconStyle", "BLIZZARD") end,
        function(v) ApplyValue(configMode, "roleIconStyle", v) end,
        ROLE_STYLE_ORDER
    ); by = by + h
    
local fontValues, fontOrder
    if LSM then
        fontValues = {}
        fontOrder = {}
        for _, name in pairs(LSM:List("font")) do
            if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
                fontValues[name] = name
                table.insert(fontOrder, name)
            end
        end
        table.sort(fontOrder)
    else
        fontValues = { ["AAA_ITC_Avant_Garde"] = "AAA_ITC_Avant_Garde" }
        fontOrder = { "AAA_ITC_Avant_Garde" }
    end
    _, h = W:Dropdown(container, "Role Icon Style", -by, ROLE_STYLE_VALUES,
        function() return GetValue(configMode, "roleIconStyle", "BLIZZARD") end,
        function(v) ApplyValue(configMode, "roleIconStyle", v) end,
        ROLE_STYLE_ORDER
    ); by = by + h

    local OUTLINE_VALUES = { [""] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROME"] = "Monochrome", ["OUTLINEMONOCHROME"] = "Monochrome Outline" }
    local OUTLINE_ORDER = { "", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "OUTLINEMONOCHROME" }
    _, h = W:Dropdown(container, "Text Outline", -by, OUTLINE_VALUES,
        function() return GetValue(configMode, "textOutline", "OUTLINE") end,
        function(v) ApplyValue(configMode, "textOutline", v) end,
        OUTLINE_ORDER
    ); by = by + h

    _, h = W:Slider(container, "Name Font Size", -by,
        function() return GetValue(configMode, "nameFontSize", 15) end,
        function(v) ApplyValue(configMode, "nameFontSize", v) end,
        8, 32, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Health Font Size", -by,
        function() return GetValue(configMode, "healthTextFontSize", 12) end,
        function(v) ApplyValue(configMode, "healthTextFontSize", v) end,
        8, 32, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Name Offset X", -by,
        function() return GetValue(configMode, "nameOffsetX", 0) end,
        function(v) ApplyValue(configMode, "nameOffsetX", v) end,
        -50, 50, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Name Offset Y", -by,
        function() return GetValue(configMode, "nameOffsetY", 0) end,
        function(v) ApplyValue(configMode, "nameOffsetY", v) end,
        -50, 50, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Health Offset X", -by,
        function() return GetValue(configMode, "healthOffsetX", 0) end,
        function(v) ApplyValue(configMode, "healthOffsetX", v) end,
        -50, 50, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Health Offset Y", -by,
        function() return GetValue(configMode, "healthOffsetY", 0) end,
        function(v) ApplyValue(configMode, "healthOffsetY", v) end,
        -50, 50, 1, "%d"
    ); by = by + h
    
    _, h = W:Toggle(container, "Group Text Outline", -by,
        function() return GetValue(configMode, "raidGroupOutline", true) ~= false end,
        function(v) ApplyValue(configMode, "raidGroupOutline", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Abbreviate Health Text", -by,
        function() return GetValue(configMode, "healthTextAbbreviate", true) ~= false end,
        function(v) ApplyValue(configMode, "healthTextAbbreviate", v and true or false) end
    ); by = by + h
    return by
end

local function AuraTypeLabel(auraType)
    if auraType == "buff" then return LText("Buff") end
    if auraType == "debuff" then return LText("Aura") end
    if auraType == "missing" then return LText("Missing") end
    return LText("Aura")
end

local function AddAuraSpellVisibilityControls(container, W, mode, startY)
    local by = startY or 0
    local mod = GetMod()
    local catalog = mod and mod.GetAuraSpellCatalog and mod:GetAuraSpellCatalog(mode) or {}
    local searchBox
    local BuildList
    local _, h = W:Label(container, "Manage discovered aura spells without expanding the whole options page.", -by, 11); by = by + h
    _, h = W:DualRow(container, -by,
        {
            type = "button",
            text = "Show All",
            onClick = function()
                local ok, reason
                if mod and mod.ResetAuraSpellVisibility then
                    ok, reason = mod:ResetAuraSpellVisibility(mode)
                end
                if not ok and reason == "combat" then
                    PrintStatus("Party Frames aura spell visibility will refresh after combat.")
                end
                if livePreview and livePreview.Refresh then livePreview:Refresh() end
                if BuildList then BuildList() end
            end,
        },
        {
            type = "button",
            text = "Clear Search",
            onClick = function()
                spellVisibilitySearch[mode] = ""
                if searchBox then
                    searchBox:SetText("")
                elseif BuildList then
                    BuildList()
                end
            end,
        }
    ); by = by + h

    if #catalog == 0 then
        _, h = W:Label(container, "No aura spells have been discovered yet. Enable test frames or join a group to populate this list.", -by, 10); by = by + h
        return by
    end

    local panelH = 360
    local rowH = 28
    local panel = CreateFrame("Frame", nil, container, "BackdropTemplate")
    panel:SetSize(math.max(260, container:GetWidth() - 20), panelH)
    panel:SetPoint("TOPLEFT", container, "TOPLEFT", 10, -by)
    if KT.AddBackdrop then KT:AddBackdrop(panel, 0.035, 0.035, 0.045, 0.92) end
    if KT.AddBorder then KT:AddBorder(panel, 0.18, 0.18, 0.22, 0.85) end

    searchBox = CreateFrame("EditBox", nil, panel)
    searchBox:SetAutoFocus(false)
    searchBox:SetHeight(24)
    searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    searchBox:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
    searchBox:SetFont(KT.FONT_PATH or DEFAULT_FONT_PATH, 11, "")
    searchBox:SetTextColor(1, 1, 1, 1)
    searchBox:SetTextInsets(8, 8, 0, 0)
    if KT.AddBackdrop then KT:AddBackdrop(searchBox, 0.06, 0.06, 0.075, 1) end
    if KT.AddBorder then KT:AddBorder(searchBox, 0.20, 0.20, 0.25, 1) end
    searchBox:SetText(spellVisibilitySearch[mode] or "")
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local filters = CreateFrame("Frame", nil, panel)
    filters:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -8)
    filters:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -8)
    filters:SetHeight(24)

    local activeType = spellVisibilityTypeFilter[mode] or "all"
    local filterButtons = {}
    local function StyleFilterButton(btn)
        if not btn then return end
        local active = activeType == btn.value
        local r, g, b = 1, 0, 0.3333333333
        if KT.GetStyleAccentRGB then r, g, b = KT:GetStyleAccentRGB() end
        if KT.AddBackdrop then
            KT:AddBackdrop(btn, active and (r * 0.18) or 0.06, active and (g * 0.18) or 0.06, active and (b * 0.18) or 0.08, 1)
        end
        if KT.AddBorder then
            KT:AddBorder(btn, active and r or 0.22, active and g or 0.22, active and b or 0.28, active and 0.85 or 1)
        end
    end
    local function RefreshFilterButtons()
        for _, btn in ipairs(filterButtons) do
            StyleFilterButton(btn)
        end
    end
    local function SetFilter(value)
        activeType = value or "all"
        spellVisibilityTypeFilter[mode] = activeType
        RefreshFilterButtons()
        if BuildList then BuildList() end
    end
    local function AddFilterButton(text, value, x)
        local btn = CreateFrame("Button", nil, filters)
        btn.value = value
        btn:SetSize(74, 22)
        btn:SetPoint("LEFT", filters, "LEFT", x, 0)
        StyleFilterButton(btn)
        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetFont(KT.FONT_PATH or DEFAULT_FONT_PATH, 10, "OUTLINE")
        label:SetPoint("CENTER")
        label:SetText(LText(text))
        label:SetTextColor(1, 1, 1, 1)
        btn:SetScript("OnClick", function() SetFilter(value) end)
        filterButtons[#filterButtons + 1] = btn
        return x + 80
    end
    local fx = 0
    fx = AddFilterButton("All", "all", fx)
    fx = AddFilterButton("Buffs", "buff", fx)
    fx = AddFilterButton("Auras", "debuff", fx)
    AddFilterButton("Missing", "missing", fx)

    local status = panel:CreateFontString(nil, "OVERLAY")
    status:SetFont(KT.FONT_PATH or DEFAULT_FONT_PATH, 10, "")
    status:SetPoint("TOPLEFT", filters, "BOTTOMLEFT", 2, -7)
    status:SetPoint("TOPRIGHT", filters, "BOTTOMRIGHT", -2, -7)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.72, 0.72, 0.76, 1)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -2, -8)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 10)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetPoint("TOPLEFT", 0, 0)
    content:SetPoint("TOPRIGHT", 0, 0)
    content:SetWidth(math.max(220, panel:GetWidth() - 48))
    scroll:SetScrollChild(content)

    local function MatchesSearch(entry, query)
        if not query or query == "" then return true end
        local name = string.lower(tostring(entry.name or ""))
        local spellID = tostring(entry.spellID or "")
        local auraType = string.lower(AuraTypeLabel(entry.auraType))
        return name:find(query, 1, true) or spellID:find(query, 1, true) or auraType:find(query, 1, true)
    end

    local function MatchesType(entry)
        local filter = activeType or "all"
        if filter == "all" then return true end
        return entry.auraType == filter
    end

    BuildList = function(preserveScroll)
        local previousScroll = preserveScroll and (scroll:GetVerticalScroll() or 0) or 0
        for _, child in ipairs({ content:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        local query = string.lower(strtrim(searchBox:GetText() or ""))
        spellVisibilitySearch[mode] = query
        local entries = {}
        local hidden = 0
        for _, entry in ipairs(catalog) do
            if mod and mod.IsAuraSpellVisible and mod:IsAuraSpellVisible(mode, tonumber(entry.spellID)) == false then
                hidden = hidden + 1
            end
            if MatchesType(entry) and MatchesSearch(entry, query) then
                entries[#entries + 1] = entry
            end
        end
        table.sort(entries, function(a, b)
            local ta, tb = AuraTypeLabel(a.auraType), AuraTypeLabel(b.auraType)
            if ta ~= tb then return ta < tb end
            return tostring(a.name or "") < tostring(b.name or "")
        end)
        status:SetText(LTextFmt("%d shown / %d discovered, %d hidden", #entries, #catalog, hidden))

        local width = math.max(220, (scroll:GetWidth() or panel:GetWidth()) - 4)
        for i, entry in ipairs(entries) do
            local spellID = tonumber(entry.spellID)
            local row = CreateFrame("Button", nil, content)
            row:SetSize(width, rowH)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * rowH))
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.03, 0.03, 0.04, i % 2 == 0 and 0.42 or 0.24)

            local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            check:SetSize(22, 22)
            check:SetPoint("LEFT", row, "LEFT", 4, 0)
            check:SetChecked(not (mod and mod.IsAuraSpellVisible and mod:IsAuraSpellVisible(mode, spellID) == false))

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", check, "RIGHT", 2, 0)
            icon:SetTexture(entry.icon or 134400)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local text = row:CreateFontString(nil, "OVERLAY")
            text:SetFont(KT.FONT_PATH or DEFAULT_FONT_PATH, 10, "")
            text:SetPoint("LEFT", icon, "RIGHT", 7, 0)
            text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            text:SetJustifyH("LEFT")
            text:SetTextColor(0.92, 0.92, 0.95, 1)
            text:SetText(string.format("%s: %s (%d)", AuraTypeLabel(entry.auraType), tostring(entry.name or "Spell"), spellID or 0))

            local function IsSpellEnabled()
                return not (mod and mod.IsAuraSpellVisible and mod:IsAuraSpellVisible(mode, spellID) == false)
            end
            local function SetSpellEnabled(enabled)
                enabled = enabled == true
                check:SetChecked(enabled)
                local ok, reason
                if mod and mod.DebugAuraSpellClick then
                    mod:DebugAuraSpellClick(mode, spellID, enabled, "checkbox")
                end
                if mod and mod.SetAuraSpellVisible then
                    ok, reason = mod:SetAuraSpellVisible(mode, spellID, enabled)
                end
                if mod and mod.IsAuraSpellVisible then
                    check:SetChecked(mod:IsAuraSpellVisible(mode, spellID) ~= false)
                end
                if not ok and reason == "combat" then
                    PrintStatus("Party Frames aura spell visibility will refresh after combat.")
                end
                if livePreview and livePreview.Refresh then livePreview:Refresh() end
                BuildList(true)
            end
            local function ToggleSpell()
                SetSpellEnabled(not IsSpellEnabled())
            end
            local suppressRowClick = false
            row:SetScript("OnClick", function()
                if suppressRowClick then
                    suppressRowClick = false
                    return
                end
                ToggleSpell()
            end)
            check:SetScript("OnClick", function(self)
                suppressRowClick = true
                ToggleSpell()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        suppressRowClick = false
                    end)
                else
                    suppressRowClick = false
                end
            end)
            row:SetScript("OnEnter", function() bg:SetColorTexture(0.16, 0.16, 0.20, 0.70) end)
            row:SetScript("OnLeave", function() bg:SetColorTexture(0.03, 0.03, 0.04, i % 2 == 0 and 0.42 or 0.24) end)
        end

        content:SetHeight(math.max(1, #entries * rowH))
        local maxScroll = math.max(0, (#entries * rowH) - (scroll:GetHeight() or 1))
        local targetScroll = preserveScroll and math.min(previousScroll, maxScroll) or 0
        if scroll.SetVerticalScroll then
            scroll:SetVerticalScroll(targetScroll)
        end
        if scroll.ScrollBar then
            scroll.ScrollBar:SetShown(#entries * rowH > (scroll:GetHeight() or 1))
            scroll.ScrollBar:SetValue(targetScroll)
        end
    end

    searchBox:SetScript("OnTextChanged", function()
        BuildList(false)
    end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local _, maxScroll = self.ScrollBar and self.ScrollBar:GetMinMaxValues() or 0, 0
        local nextValue = math.max(0, math.min(maxScroll, current - (delta * rowH * 3)))
        self:SetVerticalScroll(nextValue)
    end)
    BuildList()

    by = by + panelH + 8
    return by
end

local function AddAuraControls(container, W, mode)
    local by = 0
    local _, h
    _, h = W:Toggle(container, "Enable Auras", -by,
        function() return GetValue(mode, "showAuras", true) ~= false end,
        function(v) ApplyValue(mode, "showAuras", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Buff Icons", -by,
        function() return GetValue(mode, "showBuffs", true) ~= false end,
        function(v) ApplyValue(mode, "showBuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Only My Buffs", -by,
        function() return GetValue(mode, "auraOnlyPlayerBuffs", true) ~= false end,
        function(v) ApplyValue(mode, "auraOnlyPlayerBuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Debuff Icons", -by,
        function() return GetValue(mode, "showDebuffs", true) ~= false end,
        function(v) ApplyValue(mode, "showDebuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Show All Debuffs", -by,
        function() return GetValue(mode, "auraShowAllDebuffs", true) == true end,
        function(v) ApplyValue(mode, "auraShowAllDebuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Dispel Overlay", -by,
        function() return GetValue(mode, "showDispelOverlay", true) ~= false end,
        function(v) ApplyValue(mode, "showDispelOverlay", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Crowd Control", -by,
        function() return GetValue(mode, "showCrowdControl", true) ~= false end,
        function(v) ApplyValue(mode, "showCrowdControl", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Missing Class Buff", -by,
        function() return GetValue(mode, "showMissingBuffs", true) ~= false end,
        function(v) ApplyValue(mode, "showMissingBuffs", v and true or false) end
    ); by = by + h
    _, h = W:Slider(container, "Aura Icon Size", -by,
        function() return GetValue(mode, "auraIconSize", 20) end,
        function(v) ApplyValue(mode, "auraIconSize", math.floor(v + 0.5)) end,
        10, 28, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Buff Icon Count", -by,
        function() return GetValue(mode, "auraMaxBuffs", 5) end,
        function(v) ApplyValue(mode, "auraMaxBuffs", math.floor(v + 0.5)) end,
        0, 5, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Debuff Icon Count", -by,
        function() return GetValue(mode, "auraMaxDebuffs", 5) end,
        function(v) ApplyValue(mode, "auraMaxDebuffs", math.floor(v + 0.5)) end,
        0, 5, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Dispel Border Alpha", -by,
        function() return GetValue(mode, "dispelOverlayAlpha", 1.0) end,
        function(v) ApplyValue(mode, "dispelOverlayAlpha", v) end,
        0.05, 1.00, 0.05, "%.2f"
    ); by = by + h
    _, h = W:Slider(container, "Dispel Border Size", -by,
        function() return GetValue(mode, "dispelBorderThickness", 2) end,
        function(v) ApplyValue(mode, "dispelBorderThickness", math.floor(v + 0.5)) end,
        1, 4, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Dispel Gradient Alpha", -by,
        function() return GetValue(mode, "dispelGradientAlpha", 1.0) end,
        function(v) ApplyValue(mode, "dispelGradientAlpha", v) end,
        0.05, 1.00, 0.05, "%.2f"
    ); by = by + h
    _, h = W:Slider(container, "Dispel Gradient Size", -by,
        function() return GetValue(mode, "dispelGradientSize", 0.5) end,
        function(v) ApplyValue(mode, "dispelGradientSize", v) end,
        0.12, 0.60, 0.02, "%.2f"
    ); by = by + h
    _, h = W:Slider(container, "Missing Buff Size", -by,
        function() return GetValue(mode, "missingBuffIconSize", 30) end,
        function(v) ApplyValue(mode, "missingBuffIconSize", math.floor(v + 0.5)) end,
        14, 44, 1, "%d"
    ); by = by + h
    _, h = W:Label(container, "Icon Position Offsets", -by, 12); by = by + h
    _, h = W:Slider(container, "Buff Icons X", -by,
        function() return GetValue(mode, "buffIconsOffsetX", 0) end,
        function(v) ApplyValue(mode, "buffIconsOffsetX", math.floor(v + 0.5)) end,
        -120, 120, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Buff Icons Y", -by,
        function() return GetValue(mode, "buffIconsOffsetY", 0) end,
        function(v) ApplyValue(mode, "buffIconsOffsetY", math.floor(v + 0.5)) end,
        -80, 80, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Debuff Icons X", -by,
        function() return GetValue(mode, "debuffIconsOffsetX", 0) end,
        function(v) ApplyValue(mode, "debuffIconsOffsetX", math.floor(v + 0.5)) end,
        -120, 120, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Debuff Icons Y", -by,
        function() return GetValue(mode, "debuffIconsOffsetY", 0) end,
        function(v) ApplyValue(mode, "debuffIconsOffsetY", math.floor(v + 0.5)) end,
        -80, 80, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Aura Icon X", -by,
        function() return GetValue(mode, "auraIconOffsetX", 0) end,
        function(v) ApplyValue(mode, "auraIconOffsetX", math.floor(v + 0.5)) end,
        -120, 120, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Aura Icon Y", -by,
        function() return GetValue(mode, "auraIconOffsetY", 0) end,
        function(v) ApplyValue(mode, "auraIconOffsetY", math.floor(v + 0.5)) end,
        -80, 80, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Missing Buff X", -by,
        function() return GetValue(mode, "missingBuffOffsetX", 0) end,
        function(v) ApplyValue(mode, "missingBuffOffsetX", math.floor(v + 0.5)) end,
        -120, 120, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Missing Buff Y", -by,
        function() return GetValue(mode, "missingBuffOffsetY", 0) end,
        function(v) ApplyValue(mode, "missingBuffOffsetY", math.floor(v + 0.5)) end,
        -80, 80, 1, "%d"
    ); by = by + h
    _, h = W:Toggle(container, "Track Mark of the Wild", -by,
        function() return GetValue(mode, "missingBuffCheckMark", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckMark", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Fortitude", -by,
        function() return GetValue(mode, "missingBuffCheckStamina", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckStamina", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Intellect", -by,
        function() return GetValue(mode, "missingBuffCheckIntellect", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckIntellect", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Battle Shout", -by,
        function() return GetValue(mode, "missingBuffCheckAttackPower", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckAttackPower", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Skyfury", -by,
        function() return GetValue(mode, "missingBuffCheckSkyfury", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckSkyfury", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Blessing of the Bronze", -by,
        function() return GetValue(mode, "missingBuffCheckBronze", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckBronze", v and true or false) end
    ); by = by + h
    by = by + 8
    _, h = W:Label(container, "Spell Visibility", -by, 12); by = by + h
    by = AddAuraSpellVisibilityControls(container, W, mode, by)
    return by
end

local function AddFrameLayoutControls(container, W, mode)
    local configMode = mode
    local by = 0
    local _, h
    
    if configMode == "arena" or configMode == "arenaEnemy" then
        _, h = W:Toggle(container, "Enable Frames", -by,
            function() return GetValue(configMode, "enable", true) ~= false end,
            function(v) ApplyValue(configMode, "enable", v and true or false); RefreshPage() end
        ); by = by + h
    end
    
    _, h = W:Dropdown(container, "Grow Direction", -by, DIRECTION_VALUES,
        function() return GetValue(configMode, "growDirection", "HORIZONTAL") end,
        function(v) ApplyValue(configMode, "growDirection", v) end,
        DIRECTION_ORDER
    ); by = by + h
    if configMode ~= "raid" and configMode ~= "raid40" then
        _, h = W:Toggle(container, "Show Player Frame", -by,
            function() return GetValue(configMode, "showPlayer", configMode ~= "party") ~= false end,
            function(v) ApplyValue(configMode, "showPlayer", v and true or false) end
        ); by = by + h
    end
    _, h = W:Slider(container, "Frame Width", -by,
        function() return GetValue(configMode, "frameWidth", 125) end,
        function(v) ApplyValue(configMode, "frameWidth", v) end,
        60, 300, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Frame Height", -by,
        function() return GetValue(configMode, "frameHeight", 64) end,
        function(v) ApplyValue(configMode, "frameHeight", v) end,
        20, 300, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Frame Scale", -by,
        function() return GetValue(configMode, "frameScale", 1) end,
        function(v) ApplyValue(configMode, "frameScale", v) end,
        0.5, 2, 0.05, "%.2f"
    ); by = by + h
    _, h = W:Slider(container, "Frame Spacing", -by,
        function() return GetValue(configMode, "frameSpacing", 2) end,
        function(v) ApplyValue(configMode, "frameSpacing", v) end,
        -5, 50, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Frame Padding", -by,
        function() return GetValue(configMode, "framePadding", 0) end,
        function(v) ApplyValue(configMode, "framePadding", v) end,
        0, 10, 1, "%d"
    ); by = by + h
    _, h = W:Dropdown(container, "Growth Anchor", -by, ANCHOR_VALUES,
        function() return GetValue(configMode, "growthAnchor", "CENTER") end,
        function(v) ApplyValue(configMode, "growthAnchor", v) end,
        ANCHOR_ORDER
    ); by = by + h
    _, h = W:Toggle(container, "Pixel Perfect", -by,
        function() return GetValue(configMode, "pixelPerfect", true) and true or false end,
        function(v) ApplyValue(configMode, "pixelPerfect", v and true or false) end
    ); by = by + h
    return by
end

local function AddFrameAppearanceControls(container, W, mode)
    local by = 0
    local _, h = W:Toggle(container, "Class Colors", -by,
        function() return GetValue(mode, "colorByClass", true) ~= false end,
        function(v) ApplyValue(mode, "colorByClass", v and true or false) end
    ); by = by + h
    _, h = W:Dropdown(container, "Health Bar Texture", -by, GetStatusbarValues,
        function() return GetValue(mode, "healthTexture", PREVIEW_FILL) end,
        function(v) ApplyValue(mode, "healthTexture", v) end
    ); by = by + h
    _, h = W:Dropdown(container, "Absorb Bar Texture", -by, GetStatusbarValues,
        function() return GetValue(mode, "absorbBarTexture", PREVIEW_FILL) end,
        function(v) ApplyValue(mode, "absorbBarTexture", v) end
    ); by = by + h
    _, h = W:Toggle(container, "Absorb Overlay", -by,
        function() return GetValue(mode, "showAbsorbBar", true) ~= false end,
        function(v) ApplyValue(mode, "showAbsorbBar", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Power Bar", -by,
        function() return GetValue(mode, "showPowerBar", false) == true end,
        function(v) ApplyValue(mode, "showPowerBar", v and true or false) end
    ); by = by + h
    _, h = W:Dropdown(container, "Health Text", -by, HEALTH_TEXT_VALUES,
        function() return GetValue(mode, "healthTextFormat", "CURRENTMAX") end,
        function(v) ApplyValue(mode, "healthTextFormat", v) end,
        HEALTH_TEXT_ORDER
    ); by = by + h
    _, h = W:Dropdown(container, "Role Icon Style", -by, ROLE_STYLE_VALUES,
        function() return GetValue(mode, "roleIconStyle", "BLIZZARD") end,
        function(v) ApplyValue(mode, "roleIconStyle", v) end,
        ROLE_STYLE_ORDER
    ); by = by + h
    return by
end

local function AddFrameTextControls(container, W, mode)
    local by = 0
    local fontValues, fontOrder
    if LSM then
        fontValues = {}
        fontOrder = {}
        for _, name in pairs(LSM:List("font")) do
            if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
                fontValues[name] = name
                table.insert(fontOrder, name)
            end
        end
        table.sort(fontOrder)
    else
        fontValues = { ["AAA_ITC_Avant_Garde"] = "AAA_ITC_Avant_Garde" }
        fontOrder = { "AAA_ITC_Avant_Garde" }
    end

    local _, h = W:Dropdown(container, "Text Font", -by, fontValues,
        function() return GetValue(mode, "textFont", "AAA_ITC_Avant_Garde") end,
        function(v) ApplyValue(mode, "textFont", v) end,
        fontOrder
    ); by = by + h

    local OUTLINE_VALUES = { [""] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROME"] = "Monochrome", ["OUTLINEMONOCHROME"] = "Monochrome Outline" }
    local OUTLINE_ORDER = { "", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "OUTLINEMONOCHROME" }
    _, h = W:Dropdown(container, "Text Outline", -by, OUTLINE_VALUES,
        function() return GetValue(mode, "textOutline", "OUTLINE") end,
        function(v) ApplyValue(mode, "textOutline", v) end,
        OUTLINE_ORDER
    ); by = by + h
    _, h = W:Slider(container, "Name Font Size", -by,
        function() return GetValue(mode, "nameFontSize", 15) end,
        function(v) ApplyValue(mode, "nameFontSize", v) end,
        8, 32, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Health Font Size", -by,
        function() return GetValue(mode, "healthTextFontSize", 12) end,
        function(v) ApplyValue(mode, "healthTextFontSize", v) end,
        8, 32, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Name Offset X", -by,
        function() return GetValue(mode, "nameOffsetX", 0) end,
        function(v) ApplyValue(mode, "nameOffsetX", v) end,
        -50, 50, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Name Offset Y", -by,
        function() return GetValue(mode, "nameOffsetY", 0) end,
        function(v) ApplyValue(mode, "nameOffsetY", v) end,
        -50, 50, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Health Offset X", -by,
        function() return GetValue(mode, "healthOffsetX", 0) end,
        function(v) ApplyValue(mode, "healthOffsetX", v) end,
        -50, 50, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Health Offset Y", -by,
        function() return GetValue(mode, "healthOffsetY", 0) end,
        function(v) ApplyValue(mode, "healthOffsetY", v) end,
        -50, 50, 1, "%d"
    ); by = by + h
    _, h = W:Toggle(container, "Group Text Outline", -by,
        function() return GetValue(mode, "raidGroupOutline", true) ~= false end,
        function(v) ApplyValue(mode, "raidGroupOutline", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Abbreviate Health Text", -by,
        function() return GetValue(mode, "healthTextAbbreviate", true) ~= false end,
        function(v) ApplyValue(mode, "healthTextAbbreviate", v and true or false) end
    ); by = by + h
    return by
end

local function AddFrameIndicatorControls(container, W, mode)
    local by = 0
    local _, h = W:Toggle(container, "Ready Check Icons", -by,
        function() return GetValue(mode, "showReadyCheckIcon", true) ~= false end,
        function(v) ApplyValue(mode, "showReadyCheckIcon", v and true or false) end
    ); by = by + h
    if mode == "party" then
        _, h = W:Toggle(container, "Show Character Level", -by,
            function() return GetRootValue("showCharacterLevel", false) == true end,
            function(v) ApplyRootValue("showCharacterLevel", v and true or false) end
        ); by = by + h
        _, h = W:Toggle(container, "Show PvP Faction Icon", -by,
            function() return GetRootValue("showPvPIcon", false) == true end,
            function(v) ApplyRootValue("showPvPIcon", v and true or false) end
        ); by = by + h
        local levelFonts = {}
        if LSM and LSM.List then
            for _, name in ipairs(LSM:List("font")) do levelFonts[name] = name end
        end
        levelFonts[GetRootValue("levelFont", "AAA_ITC_Avant_Garde")] = GetRootValue("levelFont", "AAA_ITC_Avant_Garde")
        _, h = W:Dropdown(container, "Level Font", -by, levelFonts,
            function() return GetRootValue("levelFont", "AAA_ITC_Avant_Garde") end,
            function(v) ApplyRootValue("levelFont", v) end
        ); by = by + h
        _, h = W:Slider(container, "Level Font Size", -by,
            function() return tonumber(GetRootValue("levelFontSize", 11)) or 11 end,
            function(v) ApplyRootValue("levelFontSize", v) end, 6, 48, 1
        ); by = by + h
        local outlineValues = { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline", MONOCHROME = "Monochrome", OUTLINEMONOCHROME = "Monochrome Outline" }
        _, h = W:Dropdown(container, "Level Text Outline", -by, outlineValues,
            function() return GetRootValue("levelFontOutline", "OUTLINE") end,
            function(v) ApplyRootValue("levelFontOutline", v) end
        ); by = by + h
        _, h = W:ColorSwatch(container, "Level Text Color", -by,
            function() local c = GetRootValue("levelColor", { r = 1, g = 0.82, b = 0.20, a = 1 }); return c.r, c.g, c.b, c.a end,
            function(r, g, b, a) ApplyRootValue("levelColor", { r = r, g = g, b = b, a = a or 1 }) end, true
        ); by = by + h
        _, h = W:Slider(container, "Level X Offset", -by,
            function() return tonumber(GetRootValue("levelX", 3)) or 3 end,
            function(v) ApplyRootValue("levelX", v) end, -200, 200, 1
        ); by = by + h
        _, h = W:Slider(container, "Level Y Offset", -by,
            function() return tonumber(GetRootValue("levelY", 1)) or 1 end,
            function(v) ApplyRootValue("levelY", v) end, -100, 200, 1
        ); by = by + h
    end
    _, h = W:Toggle(container, "Leader Icons", -by,
        function() return GetValue(mode, "showLeaderIcon", true) ~= false end,
        function(v) ApplyValue(mode, "showLeaderIcon", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Raid Mark Icons", -by,
        function() return GetValue(mode, "showRaidTargetIcon", true) ~= false end,
        function(v) ApplyValue(mode, "showRaidTargetIcon", v and true or false) end
    ); by = by + h
    return by
end

local function AddAuraBasicsControls(container, W, mode)
    local by = 0
    local _, h
    _, h = W:Toggle(container, "Enable Auras", -by,
        function() return GetValue(mode, "showAuras", true) ~= false end,
        function(v) ApplyValue(mode, "showAuras", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Buff Icons", -by,
        function() return GetValue(mode, "showBuffs", true) ~= false end,
        function(v) ApplyValue(mode, "showBuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Only My Buffs", -by,
        function() return GetValue(mode, "auraOnlyPlayerBuffs", true) ~= false end,
        function(v) ApplyValue(mode, "auraOnlyPlayerBuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Debuff Icons", -by,
        function() return GetValue(mode, "showDebuffs", true) ~= false end,
        function(v) ApplyValue(mode, "showDebuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Show All Debuffs", -by,
        function() return GetValue(mode, "auraShowAllDebuffs", true) == true end,
        function(v) ApplyValue(mode, "auraShowAllDebuffs", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Crowd Control", -by,
        function() return GetValue(mode, "showCrowdControl", true) ~= false end,
        function(v) ApplyValue(mode, "showCrowdControl", v and true or false) end
    ); by = by + h
    if mode == "arenaEnemy" or mode == "arena" then
        _, h = W:Toggle(container, "PvP Trinket", -by,
            function() return GetValue(mode, "showArenaTrinket", true) ~= false end,
            function(v) ApplyValue(mode, "showArenaTrinket", v and true or false) end
        ); by = by + h
        _, h = W:Toggle(container, "Diminishing Returns", -by,
            function() return GetValue(mode, "showArenaDR", true) ~= false end,
            function(v) ApplyValue(mode, "showArenaDR", v and true or false) end
        ); by = by + h
        _, h = W:Slider(container, "PvP Trinket Icon Size", -by,
            function() return GetValue(mode, "arenaTrinketIconSize", 40) end,
            function(v) ApplyValue(mode, "arenaTrinketIconSize", math.floor(v + 0.5)) end,
            28, 52, 1, "%d"
        ); by = by + h
        _, h = W:Slider(container, "DR Icon Size", -by,
            function() return GetValue(mode, "arenaDRIconSize", 32) end,
            function(v) ApplyValue(mode, "arenaDRIconSize", math.floor(v + 0.5)) end,
            20, 40, 1, "%d"
        ); by = by + h
        _, h = W:Dropdown(container, "PvP Trinket Side", -by, SIDE_VALUES,
            function() return GetValue(mode, "arenaTrinketSide", "RIGHT") end,
            function(v) ApplyValue(mode, "arenaTrinketSide", v) end,
            SIDE_ORDER
        ); by = by + h
        _, h = W:Dropdown(container, "Spec Icon Side", -by, SIDE_VALUES,
            function() return GetValue(mode, "arenaSpecIconSide", "LEFT") end,
            function(v) ApplyValue(mode, "arenaSpecIconSide", v) end,
            SIDE_ORDER
        ); by = by + h
        _, h = W:Dropdown(container, "DR Icon Side", -by, SIDE_VALUES,
            function() return GetValue(mode, "arenaDRSide", "LEFT") end,
            function(v) ApplyValue(mode, "arenaDRSide", v) end,
            SIDE_ORDER
        ); by = by + h
    end
    _, h = W:Toggle(container, "Missing Class Buff", -by,
        function() return GetValue(mode, "showMissingBuffs", true) ~= false end,
        function(v) ApplyValue(mode, "showMissingBuffs", v and true or false) end
    ); by = by + h
    _, h = W:Slider(container, "Aura Icon Size", -by,
        function() return GetValue(mode, "auraIconSize", 20) end,
        function(v) ApplyValue(mode, "auraIconSize", math.floor(v + 0.5)) end,
        10, 28, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Buff Icon Count", -by,
        function() return GetValue(mode, "auraMaxBuffs", 5) end,
        function(v) ApplyValue(mode, "auraMaxBuffs", math.floor(v + 0.5)) end,
        0, 5, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Debuff Icon Count", -by,
        function() return GetValue(mode, "auraMaxDebuffs", 5) end,
        function(v) ApplyValue(mode, "auraMaxDebuffs", math.floor(v + 0.5)) end,
        0, 5, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Missing Buff Size", -by,
        function() return GetValue(mode, "missingBuffIconSize", 30) end,
        function(v) ApplyValue(mode, "missingBuffIconSize", math.floor(v + 0.5)) end,
        14, 44, 1, "%d"
    ); by = by + h
    return by
end

local function AddAuraDispelControls(container, W, mode)
    local by = 0
    local _, h = W:Toggle(container, "Dispel Border", -by,
        function() return GetValue(mode, "showDispelOverlay", true) ~= false end,
        function(v) ApplyValue(mode, "showDispelOverlay", v and true or false) end
    ); by = by + h
    _, h = W:Slider(container, "Dispel Border Alpha", -by,
        function() return GetValue(mode, "dispelOverlayAlpha", 1.0) end,
        function(v) ApplyValue(mode, "dispelOverlayAlpha", v) end,
        0.05, 1.00, 0.05, "%.2f"
    ); by = by + h
    _, h = W:Slider(container, "Dispel Border Size", -by,
        function() return GetValue(mode, "dispelBorderThickness", 2) end,
        function(v) ApplyValue(mode, "dispelBorderThickness", math.floor(v + 0.5)) end,
        1, 4, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Dispel Gradient Alpha", -by,
        function() return GetValue(mode, "dispelGradientAlpha", 1.0) end,
        function(v) ApplyValue(mode, "dispelGradientAlpha", v) end,
        0.05, 1.00, 0.05, "%.2f"
    ); by = by + h
    _, h = W:Slider(container, "Dispel Gradient Size", -by,
        function() return GetValue(mode, "dispelGradientSize", 0.5) end,
        function(v) ApplyValue(mode, "dispelGradientSize", v) end,
        0.12, 0.60, 0.02, "%.2f"
    ); by = by + h

    _, h = W:ColorSwatch(container, "Magic Color", -by,
        function()
            local c = GetValue(mode, "dispelColorMagic")
            if c then return c.r, c.g, c.b, 1 end
            return 0.2, 0.6, 1.0, 1
        end,
        function(r, g, b, a) ApplyValue(mode, "dispelColorMagic", { r = r, g = g, b = b }) end, false
    ); by = by + h

    _, h = W:ColorSwatch(container, "Curse Color", -by,
        function()
            local c = GetValue(mode, "dispelColorCurse")
            if c then return c.r, c.g, c.b, 1 end
            return 0.6, 0.0, 1.0, 1
        end,
        function(r, g, b, a) ApplyValue(mode, "dispelColorCurse", { r = r, g = g, b = b }) end, false
    ); by = by + h

    _, h = W:ColorSwatch(container, "Disease Color", -by,
        function()
            local c = GetValue(mode, "dispelColorDisease")
            if c then return c.r, c.g, c.b, 1 end
            return 0.6, 0.4, 0.0, 1
        end,
        function(r, g, b, a) ApplyValue(mode, "dispelColorDisease", { r = r, g = g, b = b }) end, false
    ); by = by + h

    _, h = W:ColorSwatch(container, "Poison Color", -by,
        function()
            local c = GetValue(mode, "dispelColorPoison")
            if c then return c.r, c.g, c.b, 1 end
            return 0.0, 0.6, 0.0, 1
        end,
        function(r, g, b, a) ApplyValue(mode, "dispelColorPoison", { r = r, g = g, b = b }) end, false
    ); by = by + h

    _, h = W:ColorSwatch(container, "Enrage Color", -by,
        function()
            local c = GetValue(mode, "dispelColorEnrage")
            if c then return c.r, c.g, c.b, 1 end
            return 1.0, 0.0, 0.0, 1
        end,
        function(r, g, b, a) ApplyValue(mode, "dispelColorEnrage", { r = r, g = g, b = b }) end, false
    ); by = by + h

    _, h = W:ColorSwatch(container, "Bleed Color", -by,
        function()
            local c = GetValue(mode, "dispelColorBleed")
            if c then return c.r, c.g, c.b, 1 end
            return 0.8, 0.0, 0.0, 1
        end,
        function(r, g, b, a) ApplyValue(mode, "dispelColorBleed", { r = r, g = g, b = b }) end, false
    ); by = by + h

    return by
end

local function AddAuraPositionControls(container, W, mode)
    local by = 0
    local _, h
    local debuffDefaultAnchor = (mode == "raid" or mode == "raid40") and "BOTTOMLEFT" or "CENTER"
    _, h = W:Dropdown(container, "Debuff Anchor", -by, ANCHOR_VALUES,
        function() return GetValue(mode, "debuffAnchor", debuffDefaultAnchor) end,
        function(v) ApplyValue(mode, "debuffAnchor", v) end,
        ANCHOR_ORDER
    ); by = by + h
    _, h = W:Dropdown(container, "Debuff Horizontal Growth", -by, FLOW_VALUES,
        function() return GetValue(mode, "debuffGrowthH", "RIGHT") end,
        function(v) ApplyValue(mode, "debuffGrowthH", v) end,
        FLOW_HORIZONTAL_ORDER
    ); by = by + h
    _, h = W:Dropdown(container, "Debuff Vertical Growth", -by, FLOW_VALUES,
        function() return GetValue(mode, "debuffGrowthV", "DOWN") end,
        function(v) ApplyValue(mode, "debuffGrowthV", v) end,
        FLOW_VERTICAL_ORDER
    ); by = by + h
    _, h = W:Slider(container, "Buff Icons X", -by,
        function() return GetValue(mode, "buffIconsOffsetX", 0) end,
        function(v) ApplyValue(mode, "buffIconsOffsetX", math.floor(v + 0.5)) end,
        -120, 120, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Buff Icons Y", -by,
        function() return GetValue(mode, "buffIconsOffsetY", 0) end,
        function(v) ApplyValue(mode, "buffIconsOffsetY", math.floor(v + 0.5)) end,
        -80, 80, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Debuff Icons X", -by,
        function() return GetValue(mode, "debuffIconsOffsetX", 0) end,
        function(v) ApplyValue(mode, "debuffIconsOffsetX", math.floor(v + 0.5)) end,
        -120, 120, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Debuff Icons Y", -by,
        function() return GetValue(mode, "debuffIconsOffsetY", 0) end,
        function(v) ApplyValue(mode, "debuffIconsOffsetY", math.floor(v + 0.5)) end,
        -80, 80, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Aura Icon X", -by,
        function() return GetValue(mode, "auraIconOffsetX", 0) end,
        function(v) ApplyValue(mode, "auraIconOffsetX", math.floor(v + 0.5)) end,
        -120, 120, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Aura Icon Y", -by,
        function() return GetValue(mode, "auraIconOffsetY", 0) end,
        function(v) ApplyValue(mode, "auraIconOffsetY", math.floor(v + 0.5)) end,
        -80, 80, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Missing Buff X", -by,
        function() return GetValue(mode, "missingBuffOffsetX", 0) end,
        function(v) ApplyValue(mode, "missingBuffOffsetX", math.floor(v + 0.5)) end,
        -120, 120, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Missing Buff Y", -by,
        function() return GetValue(mode, "missingBuffOffsetY", 0) end,
        function(v) ApplyValue(mode, "missingBuffOffsetY", math.floor(v + 0.5)) end,
        -80, 80, 1, "%d"
    ); by = by + h
    return by
end

local function AddMissingBuffTrackingControls(container, W, mode)
    local by = 0
    local _, h = W:Toggle(container, "Track Mark of the Wild", -by,
        function() return GetValue(mode, "missingBuffCheckMark", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckMark", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Fortitude", -by,
        function() return GetValue(mode, "missingBuffCheckStamina", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckStamina", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Intellect", -by,
        function() return GetValue(mode, "missingBuffCheckIntellect", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckIntellect", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Battle Shout", -by,
        function() return GetValue(mode, "missingBuffCheckAttackPower", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckAttackPower", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Skyfury", -by,
        function() return GetValue(mode, "missingBuffCheckSkyfury", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckSkyfury", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Track Blessing of the Bronze", -by,
        function() return GetValue(mode, "missingBuffCheckBronze", true) ~= false end,
        function(v) ApplyValue(mode, "missingBuffCheckBronze", v and true or false) end
    ); by = by + h
    return by
end

local function AddAuraSpellBlock(container, W, mode)
    return AddAuraSpellVisibilityControls(container, W, mode, 0)
end

local function AddPresetControls(container, W)
    local by = 0
    local _, h = W:Label(container, "Native presets for DPS/Tank and Healer layouts: size, spacing, sorting, absorbs and positions.", -by, 11); by = by + h
    _, h = W:Button(container, "Apply DPS / Tank Preset", -by, function()
        ApplyPreset("dps_tank")
    end, "FULL", true, "Apply Party Frames DPS / Tank preset?"); by = by + h
    _, h = W:Button(container, "Apply Heal Preset", -by, function()
        ApplyPreset("heal")
    end, "FULL", true, "Apply Party Frames Heal preset?"); by = by + h
    _, h = W:Label(container, "Applying a preset updates Party, Raid, Arena and Unlock Mode positions.", -by, 10); by = by + h
    return by
end

local function AddSpecProfileControls(container, W)
    local by = 0
    local mod = GetMod()
    local current = mod and mod.GetCurrentSpecInfo and mod:GetCurrentSpecInfo() or nil
    if current and not selectedSpecID then
        selectedSpecID = current.id
    end
    local activePreset = GetRootValue("activePreset", "dps_tank")
    local currentLabel = current and (current.name .. " -> " .. (PROFILE_VALUES[activePreset] or activePreset)) or "No active specialization detected."
    local _, h = W:Label(container, currentLabel, -by, 11); by = by + h
    _, h = W:Toggle(container, "Auto Profile by Spec", -by,
        function() return GetRootValue("autoProfileBySpec", true) ~= false end,
        function(v) ApplyRootValue("autoProfileBySpec", v and true or false) end
    ); by = by + h
    _, h = W:Dropdown(container, "Specialization", -by,
        function()
            local values = BuildSpecValues(mod)
            return values
        end,
        function()
            if selectedSpecID then return tostring(selectedSpecID) end
            local info = mod and mod.GetCurrentSpecInfo and mod:GetCurrentSpecInfo() or nil
            return info and tostring(info.id) or ""
        end,
        function(v)
            selectedSpecID = tonumber(v)
            RefreshPage()
        end,
        select(2, BuildSpecValues(mod))
    ); by = by + h
    _, h = W:Dropdown(container, "Profile for Selected Spec", -by, PROFILE_VALUES,
        function()
            local specID = tonumber(selectedSpecID)
            if mod and mod.GetSpecProfileAssignment and specID then
                return mod:GetSpecProfileAssignment(specID)
            end
            return "auto"
        end,
        function(v)
            local specID = tonumber(selectedSpecID)
            if mod and mod.SetSpecProfileAssignment and specID then
                local ok, reason = mod:SetSpecProfileAssignment(specID, v)
                if not ok and reason == "combat" then
                    PrintStatus("Party Frames profile change saved. It will be applied after combat.")
                end
            end
            if livePreview and livePreview.Refresh then
                livePreview:Refresh()
            end
            RefreshPage()
        end,
        PROFILE_ORDER
    ); by = by + h
    _, h = W:Label(container, "Auto maps tank and DPS specs to DPS / Tank, healers to Heal, and Augmentation to Heal.", -by, 10); by = by + h
    return by
end

local function AddRaidControls(container, W, mode)
    mode = mode == "raid40" and "raid40" or "raid"
    local by = AddFrameLayoutControls(container, W, mode)
    local _, h = W:Toggle(container, "Grouped Raid Headers", -by,
        function() return GetValue(mode, "raidUseGroups", true) ~= false end,
        function(v) ApplyValue(mode, "raidUseGroups", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Pop Out Own Group", -by,
        function() return GetValue(mode, "raidPopOutOwnGroup", false) == true end,
        function(v) ApplyValue(mode, "raidPopOutOwnGroup", v and true or false) end
    ); by = by + h
    if mode ~= "raid40" then
        _, h = W:Slider(container, "Raid Test Members", -by,
            function() return GetValue("raid", "raidTestFrameCount", 20) end,
            function(v) ApplyValue("raid", "raidTestFrameCount", math.floor(v + 0.5)) end,
            5, 40, 1, "%d"
        ); by = by + h
    else
        _, h = W:Label(container, "Raid 40 preview is fixed at 40 members while sharing the Raid layout.", -by, 10); by = by + h
    end
    _, h = W:Slider(container, "Group Spacing", -by,
        function() return GetValue(mode, "raidGroupSpacing", 8) end,
        function(v) ApplyValue(mode, "raidGroupSpacing", v) end,
        0, 40, 1, "%d"
    ); by = by + h
    _, h = W:Slider(container, "Groups Per Row", -by,
        function() return GetValue(mode, "raidGroupsPerRow", 4) end,
        function(v) ApplyValue(mode, "raidGroupsPerRow", math.floor(v + 0.5)) end,
        1, 8, 1, "%d"
    ); by = by + h
    return by
end

local function AddSortingControls(container, W, mode)
    mode = mode == "raid40" and "raid40" or "raid"
    local by = 0
    local _, h = W:Label(container, "Sorting values are stored by Party Frames and applied only outside combat.", -by, 11); by = by + h
    _, h = W:Toggle(container, "Enable Sorting", -by,
        function() return GetValue(mode, "sortEnabled", true) ~= false end,
        function(v) ApplyValue(mode, "sortEnabled", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Sort by Class", -by,
        function() return GetValue(mode, "sortByClass", false) == true end,
        function(v) ApplyValue(mode, "sortByClass", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Sort Alphabetically", -by,
        function() return GetValue(mode, "sortAlphabetical", false) == true end,
        function(v) ApplyValue(mode, "sortAlphabetical", v and true or false) end
    ); by = by + h
    _, h = W:Toggle(container, "Separate Melee / Ranged", -by,
        function() return GetValue(mode, "sortSeparateMeleeRanged", false) == true end,
        function(v) ApplyValue(mode, "sortSeparateMeleeRanged", v and true or false) end
    ); by = by + h
    return by
end

local function AddQuickActions(container, W)
    local by = 0
    local mod = GetMod()
    local partyActive = mod and mod.IsTestMode and mod:IsTestMode("party")
    local raidActive = mod and mod.IsTestMode and mod:IsTestMode("raid")
    local raid40Active = mod and mod.IsTestMode and mod:IsTestMode("raid40")
    local arenaActive = mod and mod.IsTestMode and mod:IsTestMode("arena")
    local arenaEnemyActive = mod and mod.IsTestMode and mod:IsTestMode("arenaEnemy")
    local bossActive = mod and mod.IsTestMode and mod:IsTestMode("boss")
    local _, h = W:Button(container, partyActive and "Stop Party / Dungeon Test" or "Start Party / Dungeon Test", -by, function()
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("party") end
        RefreshPage()
    end, "FULL"); by = by + h
    _, h = W:Button(container, raidActive and "Stop Raid Test" or "Start Raid Test", -by, function()
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("raid") end
        RefreshPage()
    end, "FULL"); by = by + h
    _, h = W:Button(container, raid40Active and "Stop Raid 40 Test" or "Start Raid 40 Test", -by, function()
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("raid40") end
        RefreshPage()
    end, "FULL"); by = by + h
    _, h = W:Button(container, arenaActive and "Stop Allied Arena Test" or "Start Allied Arena Test", -by, function()
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("arena") end
        RefreshPage()
    end, "FULL"); by = by + h
    _, h = W:Button(container, arenaEnemyActive and "Stop Enemy Arena Test" or "Start Enemy Arena Test", -by, function()
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("arenaEnemy") end
        RefreshPage()
    end, "FULL"); by = by + h
    _, h = W:Button(container, bossActive and "Stop Boss Test" or "Start Boss Test", -by, function()
        if mod and mod.ToggleTestMode then mod:ToggleTestMode("boss") end
        RefreshPage()
    end, "FULL"); by = by + h
    _, h = W:Button(container, "Stop Test Frames", -by, function()
        if mod and mod.HideAllTests then mod:HideAllTests() end
    end, "FULL"); by = by + h
    _, h = W:Button(container, "Highlight Visible Party Frames", -by, function()
        if mod and mod.HighlightVisibleFrames then mod:HighlightVisibleFrames() end
    end, "FULL"); by = by + h
    _, h = W:Label(container, "Test mode uses Party Frames addon samples and unlock-mode movers.", -by, 10); by = by + h
    return by
end

local function EnsureManageProfileState(profileMod)
    if not profileMod or not KT.db then return end
    if not profilesSelectionName or profilesSelectionName == "" then
        profilesSelectionName = KT.db:GetCurrentProfile()
    end
    if not profilesDraftName or profilesDraftName == "" then
        profilesDraftName = profilesSelectionName or KT.db:GetCurrentProfile() or ""
    end
end

local function AddManageProfiles(container, W)
    local by = 0
    local profileMod = GetProfilesModule()
    if not profileMod then
        local _, h = W:Label(container, "Profiles module not available.", -by, 11, { r = 1, g = 0.35, b = 0.35 }); by = by + h
        return by
    end
    EnsureManageProfileState(profileMod)
    local assigned = profileMod.GetCurrentSpecAssignment and profileMod:GetCurrentSpecAssignment() or nil
    local currentProfile = KT.db and KT.db:GetCurrentProfile() or "Unknown"
    local _, h = W:Label(container, LText("Current profile: ") .. tostring(currentProfile), -by, 11); by = by + h
    _, h = W:Label(container, assigned and (LText("Current spec assignment: ") .. tostring(assigned)) or LText("Current spec assignment: Auto / none"), -by, 10); by = by + h
    _, h = W:Dropdown(container, "Saved Profiles", -by,
        function()
            return select(1, profileMod:GetProfileValues())
        end,
        function()
            EnsureManageProfileState(profileMod)
            return profilesSelectionName
        end,
        function(v)
            profilesSelectionName = v
        end
    ); by = by + h
    _, h = W:Input(container, "Save Current As", -by,
        function() return profilesDraftName end,
        function(v) profilesDraftName = v end
    ); by = by + h
    _, h = W:DualRow(container, -by,
        {
            type = "button",
            text = "Load Selected",
            onClick = function()
                local ok, err = profileMod:SwitchProfile(profilesSelectionName)
                if not ok and err then KT:Print(err) end
                RefreshPage()
            end,
        },
        {
            type = "button",
            text = "Save As",
            onClick = function()
                local name = strtrim and strtrim(profilesDraftName or "") or (profilesDraftName or "")
                local ok, err = profileMod:SaveCurrentAsProfile(name)
                if not ok and err then KT:Print(err) end
                profilesSelectionName = KT.db and KT.db:GetCurrentProfile() or profilesSelectionName
                profilesDraftName = profilesSelectionName or profilesDraftName
                RefreshPage()
            end,
        }
    ); by = by + h
    _, h = W:Button(container, "Delete Selected Profile", -by, function()
        local ok, err = profileMod:DeleteProfile(profilesSelectionName)
        if not ok and err then KT:Print(err) end
        profilesSelectionName = KT.db and KT.db:GetCurrentProfile() or profilesSelectionName
        profilesDraftName = profilesSelectionName or profilesDraftName
        RefreshPage()
    end, "FULL", true, "Delete selected KullThranUI profile?"); by = by + h
    _, h = W:DualRow(container, -by,
        {
            type = "button",
            text = "Assign To Spec",
            onClick = function()
                local target = profilesSelectionName or (KT.db and KT.db:GetCurrentProfile())
                local ok, err = profileMod:AssignCurrentSpec(target)
                if not ok and err then KT:Print(err) end
                RefreshPage()
            end,
        },
        {
            type = "button",
            text = "Clear Spec Assign",
            onClick = function()
                local ok, err = profileMod:ClearCurrentSpecAssignment()
                if not ok and err then KT:Print(err) end
                RefreshPage()
            end,
        }
    ); by = by + h
    return by
end

local function AddManageTransfer(container, W)
    local by = 0
    local profileMod = GetProfilesModule()
    if not profileMod then
        local _, h = W:Label(container, "Profiles module not available.", -by, 11, { r = 1, g = 0.35, b = 0.35 }); by = by + h
        return by
    end
    local _, h = W:Label(container, "Export and import either the full KullThranUI profile or only Party Frames.", -by, 11); by = by + h
    _, h = W:Button(container, "Export Current Profile", -by, function()
        local exportString, err = profileMod:ExportCurrentProfileString()
        if not exportString then
            KT:Print(err)
        else
            profileMod:ShowExportPopup(LText("Export Current Profile"), exportString)
        end
    end, "FULL"); by = by + h
    _, h = W:Button(container, "Import Profile", -by, function()
        profileMod:ShowImportPopup(LText("Import Profile"), LText("|cffff5555This overwrites the active KullThranUI profile.|r"), function(text)
            local ok, err = profileMod:ImportProfileString(text)
            if not ok and err then KT:Print(err) end
            RefreshPage()
        end)
    end, "FULL"); by = by + h
    _, h = W:DualRow(container, -by,
        {
            type = "button",
            text = "Export Party Frames",
            onClick = function()
                local exportString, err = profileMod:ExportModulesString({ "partyframes" })
                if not exportString then
                    KT:Print(err)
                else
                    profileMod:ShowExportPopup(LText("Export Party Frames"), exportString)
                end
            end,
        },
        {
            type = "button",
            text = "Import Party Frames",
            onClick = function()
                profileMod:ShowImportPopup(LText("Import Party Frames"), LText("|cffff5555This merges imported Party Frames into the active profile.|r"), function(text)
                    local ok, err = profileMod:ImportProfileString(text)
                    if not ok and err then KT:Print(err) end
                    RefreshPage()
                end)
            end,
        }
    ); by = by + h
    return by
end

local function AddRosterControls(container, W)
    local by = 0
    local mod = GetMod()
    local _, h
    _, h = W:Dropdown(container, "Roster Source", -by,
        { party = "Party / Dungeon", raid = "Raid", arena = "Arena" },
        function() return rosterMode end,
        function(v) rosterMode = v; RefreshPage() end,
        { "party", "raid", "arena" }
    ); by = by + h

    local rows = mod and mod.GetRosterSnapshot and mod:GetRosterSnapshot(rosterMode) or {}
    if #rows == 0 then
        _, h = W:Label(container, "No group members or Party Frames units are visible right now.", -by, 11); by = by + h
    else
        local maxRows = math.min(#rows, 14)
        for i = 1, maxRows do
            local row = rows[i]
            _, h = W:Label(container, row.unit .. "  " .. row.name .. "  " .. row.role, -by, 10); by = by + h
        end
        if #rows > maxRows then
            _, h = W:Label(container, LTextFmt("...and %d more.", #rows - maxRows), -by, 10); by = by + h
        end
    end
    return by
end

KT:RegisterPage("partyframes", "Party Frames", 11.1, function(sc, W)
    local y, h = 0, 0
    local mod = GetMod()

    if not mod then
        _, h = W:SectionHeader(sc, "Party Frames", -y); y = y + h
        _, h = W:Label(sc, "Party Frames module is not available.", -y, 11, { r = 1, g = 0.35, b = 0.35 }); y = y + h
        return y
    end

    local previewMode = activeMode == "manage" and rosterMode or activeMode
    local oldActiveMode = activeMode
    activeMode = previewMode
    _, h = CreateLivePreview(sc, y); y = y + h
    activeMode = oldActiveMode

    _, h = W:SectionHeader(sc, "Party Frames", -y); y = y + h


    _, h = W:Toggle(sc, "Enable Party Frames", -y,
        function()
            return GetRootValue("enable", true) ~= false
        end,
        function(v)
            ApplyRootValue("enable", v and true or false)
            RequestReload()
        end
    ); y = y + h

    if KT.AddOptionsSubTabBar then
        _, h = KT.AddOptionsSubTabBar(sc, -y, MODE_TABS, activeMode, function(tabId)
            activeMode = tabId or "party"
            if tabId ~= "manage" then
                rosterMode = tabId == "raid40" and "raid" or tabId
            end
            RefreshPage()
        end); y = y + h
    end

    _, h = W:Button(sc, "Restore Defaults", -y, function()
        local active = GetRootValue("activePreset", "dps_tank")
        ApplyPreset(active)
    end, "FULL", true, "Restore the current Party Frames preset to its factory defaults?"); y = y + h

    local cols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 14 })
    if activeMode == "manage" then
        AddOptionBlock(cols, "left", "KUI Profiles", function(container)
            return AddManageProfiles(container, W)
        end)
        AddOptionBlock(cols, "right", "Profile Transfer", function(container)
            return AddManageTransfer(container, W)
        end)
        AddOptionBlock(cols, "left", "Party Frame Presets", function(container)
            return AddPresetControls(container, W)
        end)
        AddOptionBlock(cols, "right", "Spec Profiles", function(container)
            return AddSpecProfileControls(container, W)
        end)
        AddOptionBlock(cols, "right", "Quick Actions", function(container)
            return AddQuickActions(container, W)
        end)
    elseif activeMode == "raid" then
        AddOptionBlock(cols, "left", "Raid Layout", function(container)
            return AddRaidControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "left", "Appearance", function(container)
            return AddFrameAppearanceControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "left", "Text", function(container)
            return AddFrameTextControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "left", "Indicators", function(container)
            return AddFrameIndicatorControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "right", "Aura Basics", function(container)
            return AddAuraBasicsControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "right", "Icon Positions", function(container)
            return AddAuraPositionControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "right", "Dispel", function(container)
            return AddAuraDispelControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "right", "Missing Buffs", function(container)
            return AddMissingBuffTrackingControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "right", "Spell Visibility", function(container)
            return AddAuraSpellBlock(container, W, "raid")
        end)
        AddOptionBlock(cols, "right", "Sorting", function(container)
            return AddSortingControls(container, W, "raid")
        end)
        AddOptionBlock(cols, "right", "Roster", function(container)
            return AddRosterControls(container, W)
        end)
    elseif activeMode == "raid40" then
        AddOptionBlock(cols, "left", "Raid 40 Layout", function(container)
            return AddRaidControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "left", "Appearance", function(container)
            return AddFrameAppearanceControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "left", "Text", function(container)
            return AddFrameTextControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "left", "Indicators", function(container)
            return AddFrameIndicatorControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "right", "Aura Basics", function(container)
            return AddAuraBasicsControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "right", "Icon Positions", function(container)
            return AddAuraPositionControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "right", "Dispel", function(container)
            return AddAuraDispelControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "right", "Missing Buffs", function(container)
            return AddMissingBuffTrackingControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "right", "Spell Visibility", function(container)
            return AddAuraSpellBlock(container, W, "raid40")
        end)
        AddOptionBlock(cols, "right", "Sorting", function(container)
            return AddSortingControls(container, W, "raid40")
        end)
        AddOptionBlock(cols, "right", "Roster", function(container)
            return AddRosterControls(container, W)
        end)
    elseif activeMode == "arena" or activeMode == "arenaEnemy" then
        local arenaMode = activeMode
        local arenaTitle = arenaMode == "arenaEnemy" and "Enemy Arena Layout" or "Allied Arena Layout"
        AddOptionBlock(cols, "left", arenaTitle, function(container)
            return AddFrameLayoutControls(container, W, arenaMode)
        end)
        AddOptionBlock(cols, "right", "Appearance", function(container)
            return AddFrameAppearanceControls(container, W, arenaMode)
        end)
        AddOptionBlock(cols, "left", "Text", function(container)
            return AddFrameTextControls(container, W, arenaMode)
        end)
        AddOptionBlock(cols, "right", "Indicators", function(container)
            return AddFrameIndicatorControls(container, W, arenaMode)
        end)
        AddOptionBlock(cols, "left", "Aura Basics", function(container)
            return AddAuraBasicsControls(container, W, arenaMode)
        end)
        AddOptionBlock(cols, "left", "Icon Positions", function(container)
            return AddAuraPositionControls(container, W, arenaMode)
        end)
        AddOptionBlock(cols, "right", "Dispel", function(container)
            return AddAuraDispelControls(container, W, arenaMode)
        end)
        AddOptionBlock(cols, "right", "Missing Buffs", function(container)
            return AddMissingBuffTrackingControls(container, W, arenaMode)
        end)
        AddOptionBlock(cols, "right", "Spell Visibility", function(container)
            return AddAuraSpellBlock(container, W, arenaMode)
        end)

    elseif activeMode == "boss" then
        AddOptionBlock(cols, "left", "Boss Layout", function(container)
            return AddFrameLayoutControls(container, W, "boss")
        end)
        AddOptionBlock(cols, "left", "Appearance", function(container)
            return AddFrameAppearanceControls(container, W, "boss")
        end)
        AddOptionBlock(cols, "left", "Text", function(container)
            return AddFrameTextControls(container, W, "boss")
        end)
        AddOptionBlock(cols, "left", "Indicators", function(container)
            return AddFrameIndicatorControls(container, W, "boss")
        end)
        AddOptionBlock(cols, "right", "Aura Basics", function(container)
            return AddAuraBasicsControls(container, W, "boss")
        end)
        AddOptionBlock(cols, "right", "Icon Positions", function(container)
            return AddAuraPositionControls(container, W, "boss")
        end)
        AddOptionBlock(cols, "right", "Dispel", function(container)
            return AddAuraDispelControls(container, W, "boss")
        end)
        AddOptionBlock(cols, "right", "Missing Buffs", function(container)
            return AddMissingBuffTrackingControls(container, W, "boss")
        end)
        AddOptionBlock(cols, "right", "Spell Visibility", function(container)
            return AddAuraSpellBlock(container, W, "boss")
        end)

    else
        AddOptionBlock(cols, "left", "Party Frame Presets", function(container)
            return AddPresetControls(container, W)
        end)
        AddOptionBlock(cols, "left", "Dungeon Layout", function(container)
            return AddFrameLayoutControls(container, W, "party")
        end)
        AddOptionBlock(cols, "left", "Appearance", function(container)
            return AddFrameAppearanceControls(container, W, "party")
        end)
        AddOptionBlock(cols, "left", "Text", function(container)
            return AddFrameTextControls(container, W, "party")
        end)
        AddOptionBlock(cols, "left", "Indicators", function(container)
            return AddFrameIndicatorControls(container, W, "party")
        end)
        AddOptionBlock(cols, "right", "Aura Basics", function(container)
            return AddAuraBasicsControls(container, W, "party")
        end)
        AddOptionBlock(cols, "right", "Icon Positions", function(container)
            return AddAuraPositionControls(container, W, "party")
        end)
        AddOptionBlock(cols, "right", "Dispel", function(container)
            return AddAuraDispelControls(container, W, "party")
        end)
        AddOptionBlock(cols, "right", "Missing Buffs", function(container)
            return AddMissingBuffTrackingControls(container, W, "party")
        end)
        AddOptionBlock(cols, "right", "Spell Visibility", function(container)
            return AddAuraSpellBlock(container, W, "party")
        end)
        AddOptionBlock(cols, "right", "Quick Actions", function(container)
            return AddQuickActions(container, W)
        end)
        AddOptionBlock(cols, "right", "Roster", function(container)
            return AddRosterControls(container, W)
        end)
    end

    return EndOptionBlocks(cols) + 8
end)
