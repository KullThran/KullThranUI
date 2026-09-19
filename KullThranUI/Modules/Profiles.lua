local addonName, addonNS = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local ns = _G.KullThranUI_NS or addonNS or {}
local LibDeflate = LibStub("LibDeflate", true)
local Mod = KT:NewModule("Profiles")

local function LText(text)
    local L = KT and KT.GetLocale and KT:GetLocale()
    return (L and L[text]) or text
end

local EXPORT_PREFIX = "!KTUI_"
local CDM_EXPORT_PREFIX = "!KTCDM_"
local PROFILE_BRIDGE_VERSION = 1

local MODULE_DEFS = {
    {
        id = "general",
        label = "General",
        keys = { "globalFont", "language", "uiScale", "autoResolutionScale", "useBlizzardUIScale", "menuCustomWidth", "menuCustomHeight", "editMode" },
        -- Accept keys emitted by older General module strings, but do not put
        -- them in new exports now that they belong to their own page scopes.
        importKeys = { "skin", "objectiveTracker", "blizzframes", "externalAddons", "uufIntegration" },
    },
    { id = "skins", label = "Skins", keys = { "skin" } },
    { id = "minimap", label = "Minimap", keys = { "minimap", "minimapButton" } },
    { id = "actionbars", label = "Action Bars", keys = { "actionbars", "blizzframes" } },
    { id = "unitframes", label = "Unit Frames", keys = { "unitFrames" } },
    { id = "partyframes", label = "Party Frames", keys = { "partyFrames" } },
    { id = "cooldownmanager", label = "Cooldown Manager", keys = { "cooldownManager" }, external = { "spellDurations" } },
    { id = "resourcebars", label = "Resource Bars", keys = { "resourceBars" } },
    { id = "buffs", label = "Buffs & Debuffs", keys = { "buffsAndDebuffs" } },
    { id = "interrupts", label = "Interrupts", keys = { "interruptsGlow" } },
    { id = "castbar", label = "Cast Bar", keys = { "castbar" } },
    { id = "chat", label = "Chat", keys = { "chat" } },
    { id = "bags", label = "Bags", keys = { "bags" }, nested = { skin = { "bagsColorMode", "bagsColor" } } },
    { id = "tooltip", label = "Tooltip", keys = { "tooltip" } },
    { id = "enhancements", label = "Enhancements", keys = { "enhancements", "friendListTypography" }, omit = { enhancements = { damageMeter = true, mplusTracker = true } } },
    { id = "damagemeter", label = "Damage Meter", keys = {}, nested = { enhancements = { "damageMeter" } } },
    { id = "mythicplustimer", label = "Mythic+ Timer", keys = {}, nested = { enhancements = { "mplusTracker" } } },
    { id = "objectivetracker", label = "Objective Tracker", keys = { "objectiveTracker" } },
    { id = "kuimove", label = "KUIMove", keys = { "kuiMove" }, importKeys = { "kuiMove", "blizzMove", "BlizzMove", "KUIMove" } },
    { id = "cursor", label = "Cursor", keys = { "cursor" } },
    { id = "teleportmenu", label = "Teleport Menu", keys = { "teleportMenu" } },
    { id = "armory", label = "Armory", keys = { "armory" }, importKeys = { "inspectArmory" } },
    { id = "inspectarmory", label = "Inspect Armory", keys = { "inspectArmory" } },
    { id = "dragonriding", label = "Dragon Riding", keys = { "dragonRiding" } },
    { id = "expbar", label = "Experience Bar", keys = { "experienceBar" } },
    { id = "progressbars", label = "Progress Bars", keys = { "progressBars" }, external = { "spellDurations" } },
    { id = "external", label = "External Addons", keys = { "externalAddons", "uufIntegration" } },
    { id = "nameplates", label = "Nameplates", keys = {}, external = { "nameplates" } },
    { id = "aurareminders", label = "Aura Reminders", keys = {}, external = { "auraReminders" } },
}

local LEGACY_MODULE_DEFS = {}

-- Option pages do not always map one-to-one to a stored module. Enhancements,
-- for example, contains two independently exportable children. Keeping this
-- map beside MODULE_DEFS makes the page integration declarative and prevents
-- every options addon from implementing its own profile logic.
local PAGE_PROFILE_SCOPES = {
    skins = { "skins" },
    minimap = { "minimap" },
    actionbars = { "actionbars" },
    unitframes = { "unitframes" },
    partyframes = { "partyframes" },
    cooldownmanager = { "cooldownmanager" },
    resourcebars = { "resourcebars" },
    buffs = { "buffs" },
    castbar = { "castbar" },
    chat = { "chat" },
    bags = { "bags" },
    tooltip = { "tooltip" },
    enhancements = { "enhancements", "damagemeter", "mythicplustimer" },
    damagemeter = { "damagemeter" },
    mythicplustimer = { "mythicplustimer" },
    objectivetracker = { "objectivetracker" },
    cursor = { "cursor" },
    teleportmenu = { "teleportmenu" },
    armory = { "armory" },
    inspectarmory = { "inspectarmory" },
    dragonriding = { "dragonriding" },
    expbar = { "expbar" },
    progressbars = { "progressbars" },
    nameplates = { "nameplates" },
    aurareminders = { "aurareminders" },
}

local MODULE_BY_ID = {}
for _, def in ipairs(MODULE_DEFS) do
    MODULE_BY_ID[def.id] = def
end
for id, def in pairs(LEGACY_MODULE_DEFS) do
    MODULE_BY_ID[id] = def
end

local MAIN_BAR_KEYS = {
    cooldowns = true,
    utility = true,
    buffs = true,
}

local TALENT_AWARE_BAR_TYPES = {
    cooldowns = true,
    utility = true,
}

local CDM_SPELL_KEYS = {
    trackedSpells = true,
    extraSpells = true,
    removedSpells = true,
    dormantSpells = true,
    customSpells = true,
}

local function DeepCopy(src)
    if type(src) ~= "table" then
        return src
    end

    local copy = {}
    for key, value in pairs(src) do
        copy[DeepCopy(key)] = DeepCopy(value)
    end
    return copy
end

local function WipeTable(tbl)
    if type(tbl) ~= "table" then
        return
    end

    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local Serializer = {}

local function SerializeValue(value, parts)
    local valueType = type(value)
    if valueType == "string" then
        parts[#parts + 1] = "s"
        parts[#parts + 1] = #value
        parts[#parts + 1] = ":"
        parts[#parts + 1] = value
    elseif valueType == "number" then
        parts[#parts + 1] = "n"
        parts[#parts + 1] = tostring(value)
        parts[#parts + 1] = ";"
    elseif valueType == "boolean" then
        parts[#parts + 1] = value and "T" or "F"
    elseif valueType == "nil" then
        parts[#parts + 1] = "N"
    elseif valueType == "table" then
        local index = 1
        local length = #value
        parts[#parts + 1] = "{"

        while index <= length do
            SerializeValue(value[index], parts)
            index = index + 1
        end

        for key, child in pairs(value) do
            local keyType = type(key)
            local isArrayKey = keyType == "number" and key >= 1 and key <= length and key == math.floor(key)
            if not isArrayKey then
                parts[#parts + 1] = "K"
                SerializeValue(key, parts)
                SerializeValue(child, parts)
            end
        end

        parts[#parts + 1] = "}"
    end
end

local function DeserializeValue(serialized, position)
    local tag = serialized:sub(position, position)
    if tag == "s" then
        local colonPosition = serialized:find(":", position + 1, true)
        if not colonPosition then
            return nil, position
        end

        local length = tonumber(serialized:sub(position + 1, colonPosition - 1))
        if not length then
            return nil, position
        end

        local value = serialized:sub(colonPosition + 1, colonPosition + length)
        return value, colonPosition + length + 1
    end

    if tag == "n" then
        local semicolonPosition = serialized:find(";", position + 1, true)
        if not semicolonPosition then
            return nil, position
        end
        return tonumber(serialized:sub(position + 1, semicolonPosition - 1)), semicolonPosition + 1
    end

    if tag == "T" then
        return true, position + 1
    end

    if tag == "F" then
        return false, position + 1
    end

    if tag == "N" then
        return nil, position + 1
    end

    if tag == "{" then
        local tbl = {}
        local arrayIndex = 1
        local cursor = position + 1

        while cursor <= #serialized do
            local currentTag = serialized:sub(cursor, cursor)
            if currentTag == "}" then
                return tbl, cursor + 1
            end

            if currentTag == "K" then
                local key
                local value
                key, cursor = DeserializeValue(serialized, cursor + 1)
                value, cursor = DeserializeValue(serialized, cursor)
                if key ~= nil then
                    tbl[key] = value
                end
            else
                local value
                value, cursor = DeserializeValue(serialized, cursor)
                tbl[arrayIndex] = value
                arrayIndex = arrayIndex + 1
            end
        end

        return tbl, cursor
    end

    return nil, position + 1
end

function Serializer.Serialize(tbl)
    local parts = {}
    SerializeValue(tbl, parts)
    return table.concat(parts)
end

function Serializer.Deserialize(serialized)
    if not serialized or serialized == "" then
        return nil
    end

    local value = DeserializeValue(serialized, 1)
    return value
end

local function DeepCopyCDMLayoutOnly(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    local omittedKeys = {
        specProfiles = true,
        activeSpecKey = true,
        spec = true,
        barGlows = true,
        trackedBuffBars = true,
        tbbPositions = true,
    }

    for key, value in pairs(source) do
        if not omittedKeys[key] then
            if key == "cdmBars" and type(value) == "table" then
                local barsCopy = {}
                for barKey, barValue in pairs(value) do
                    if barKey == "bars" and type(barValue) == "table" then
                        local barList = {}
                        for index, barData in ipairs(barValue) do
                            local barCopy = {}
                            for field, fieldValue in pairs(barData) do
                                if not CDM_SPELL_KEYS[field] then
                                    barCopy[field] = DeepCopy(fieldValue)
                                end
                            end
                            barList[index] = barCopy
                        end
                        barsCopy[barKey] = barList
                    else
                        barsCopy[barKey] = DeepCopy(barValue)
                    end
                end
                copy[key] = barsCopy
            else
                copy[key] = DeepCopy(value)
            end
        end
    end

    return copy
end

local function CopyDefinitionRootValue(definition, rootKey, value)
    local copy
    if rootKey == "cooldownManager" then
        copy = DeepCopyCDMLayoutOnly(value)
    else
        copy = DeepCopy(value)
    end
    local omitted = definition.omit and definition.omit[rootKey]
    if type(copy) == "table" and type(omitted) == "table" then
        for childKey in pairs(omitted) do
            copy[childKey] = nil
        end
    end
    return copy
end

local function GetMetaDB()
    if not KT or not KT.db then
        return nil
    end

    KT.db.global = KT.db.global or {}
    KT.db.global.profileManager = KT.db.global.profileManager or {
        specAssignments = {},
        characterSpecAssignments = {},
    }
    KT.db.global.profileManager.specAssignments = KT.db.global.profileManager.specAssignments or {}
    KT.db.global.profileManager.characterSpecAssignments = KT.db.global.profileManager.characterSpecAssignments or {}
    KT.db.global.profileManager.externalProfiles = KT.db.global.profileManager.externalProfiles or {}
    KT.db.global.profileManager.bridgeVersion = math.max(
        tonumber(KT.db.global.profileManager.bridgeVersion) or 0,
        PROFILE_BRIDGE_VERSION
    )
    return KT.db.global.profileManager
end

local function GetCurrentCharacterKey()
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    if not name or name == "" then
        return nil
    end
    if not realm or realm == "" then
        return name
    end
    return name .. " - " .. realm
end

local function GetCharacterSpecAssignments(create)
    local meta = GetMetaDB()
    local characterKey = GetCurrentCharacterKey()
    if not meta or not characterKey then
        return nil, characterKey, meta
    end

    if create then
        meta.characterSpecAssignments[characterKey] = meta.characterSpecAssignments[characterKey] or {}
    end

    return meta.characterSpecAssignments[characterKey], characterKey, meta
end

local function GetRootProfile()
    if not KT or not KT.db then
        return nil
    end
    return KT.db.profile
end

local EXTERNAL_PROFILE_SOURCES = {
    nameplates = {
        kind = "global",
        globalName = "KullThranUINameplatesDB",
    },
    spellDurations = {
        kind = "global",
        globalName = "KUISpellDurationDB",
    },
    auraReminders = {
        kind = "aceProfile",
        globalName = "KUIAuraRemindersDB",
        aceGlobalName = "_KUIAR_AceDB",
    },
}

local function GetAceDBCurrentProfileName(source)
    local aceDB = source and source.aceGlobalName and _G[source.aceGlobalName]
    if aceDB and aceDB.GetCurrentProfile then
        local ok, profileName = pcall(aceDB.GetCurrentProfile, aceDB)
        if ok and type(profileName) == "string" and profileName ~= "" then
            return profileName
        end
    end

    local rawDB = source and source.globalName and _G[source.globalName]
    local characterKey = GetCurrentCharacterKey()
    if type(rawDB) == "table" and type(rawDB.profileKeys) == "table" and characterKey then
        local profileName = rawDB.profileKeys[characterKey]
        if type(profileName) == "string" and profileName ~= "" then
            return profileName
        end
    end

    return "Default"
end

local function CaptureExternalProfileSource(sourceID)
    local source = EXTERNAL_PROFILE_SOURCES[sourceID]
    if not source then
        return nil
    end

    if source.kind == "global" then
        local data = _G[source.globalName]
        if type(data) == "table" then
            return {
                kind = source.kind,
                globalName = source.globalName,
                data = DeepCopy(data),
            }
        end
        return nil
    end

    if source.kind == "aceProfile" then
        local aceDB = source.aceGlobalName and _G[source.aceGlobalName]
        local profileData = aceDB and aceDB.profile
        local profileName = GetAceDBCurrentProfileName(source)
        if type(profileData) ~= "table" then
            local rawDB = _G[source.globalName]
            profileData = rawDB and rawDB.profiles and rawDB.profiles[profileName]
        end

        if type(profileData) == "table" then
            return {
                kind = source.kind,
                globalName = source.globalName,
                aceGlobalName = source.aceGlobalName,
                profileName = profileName,
                data = DeepCopy(profileData),
            }
        end
    end

    return nil
end

local function CaptureExternalProfileSources(sourceIDs)
    local exported = {}
    if type(sourceIDs) ~= "table" then
        return exported
    end

    for _, sourceID in ipairs(sourceIDs) do
        local snapshot = CaptureExternalProfileSource(sourceID)
        if snapshot then
            exported[sourceID] = snapshot
        end
    end

    return exported
end

local function HasExternalProfileSource(sourceID)
    local source = EXTERNAL_PROFILE_SOURCES[sourceID]
    if not source then
        return false
    end

    if source.kind == "global" then
        return type(_G[source.globalName]) == "table"
    end

    if source.kind == "aceProfile" then
        local aceDB = source.aceGlobalName and _G[source.aceGlobalName]
        if aceDB and type(aceDB.profile) == "table" then
            return true
        end

        local rawDB = _G[source.globalName]
        local profileName = GetAceDBCurrentProfileName(source)
        return type(rawDB) == "table"
            and type(rawDB.profiles) == "table"
            and type(rawDB.profiles[profileName]) == "table"
    end

    return false
end

local function CaptureAllExternalProfileSources()
    local sourceIDs = {}
    local seen = {}
    for _, definition in ipairs(MODULE_DEFS) do
        if type(definition.external) == "table" then
            for _, sourceID in ipairs(definition.external) do
                if not seen[sourceID] then
                    sourceIDs[#sourceIDs + 1] = sourceID
                    seen[sourceID] = true
                end
            end
        end
    end
    return CaptureExternalProfileSources(sourceIDs)
end

local function ApplyExternalProfileSource(sourceID, snapshot)
    local source = EXTERNAL_PROFILE_SOURCES[sourceID]
    if not source or type(snapshot) ~= "table" or type(snapshot.data) ~= "table" then
        return true
    end

    if source.kind == "global" then
        _G[source.globalName] = _G[source.globalName] or {}
        WipeTable(_G[source.globalName])
        for key, value in pairs(snapshot.data) do
            _G[source.globalName][key] = DeepCopy(value)
        end
        return true
    end

    if source.kind == "aceProfile" then
        local aceDB = source.aceGlobalName and _G[source.aceGlobalName]
        if aceDB and type(aceDB.profile) == "table" then
            WipeTable(aceDB.profile)
            for key, value in pairs(snapshot.data) do
                aceDB.profile[key] = DeepCopy(value)
            end
            return true
        end

        _G[source.globalName] = _G[source.globalName] or {}
        local rawDB = _G[source.globalName]
        rawDB.profiles = rawDB.profiles or {}
        local profileName = GetAceDBCurrentProfileName(source)
        rawDB.profiles[profileName] = DeepCopy(snapshot.data)
        return true
    end

    return true
end

local function ApplyExternalProfileSources(snapshots)
    if type(snapshots) ~= "table" then
        return true
    end

    for sourceID, snapshot in pairs(snapshots) do
        local ok, err = ApplyExternalProfileSource(sourceID, snapshot)
        if not ok then
            return false, err
        end
    end

    return true
end

local function SaveExternalProfileSnapshot(profileName)
    local meta = GetMetaDB()
    if not meta or type(profileName) ~= "string" or profileName == "" then
        return
    end

    meta.externalProfiles = meta.externalProfiles or {}
    meta.externalProfiles[profileName] = CaptureAllExternalProfileSources()
end

local function ResetExternalProfileSources()
    local inCombat = InCombatLockdown and InCombatLockdown()
    if not inCombat and type(ns.ResetNameplatesDB) == "function" then
        pcall(ns.ResetNameplatesDB)
    end

    local auraDB = rawget(_G, "_KUIAR_AceDB")
    if auraDB and type(auraDB.ResetProfile) == "function" then
        pcall(auraDB.ResetProfile, auraDB)
    end
end

local function RestoreExternalProfileSnapshot(profileName)
    local meta = GetMetaDB()
    if not meta or type(profileName) ~= "string" or profileName == "" then
        return
    end

    local snapshots = meta.externalProfiles and meta.externalProfiles[profileName]
    if type(snapshots) == "table" then
        ApplyExternalProfileSources(snapshots)
    end
end

local function GetCDMProfile()
    local profile = GetRootProfile()
    if not profile then
        return nil
    end

    profile.cooldownManager = profile.cooldownManager or {}
    return profile.cooldownManager
end

local function GetCurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization() or nil
    if not specIndex or specIndex <= 0 then
        return nil
    end

    local specID = GetSpecializationInfo(specIndex)
    return specID
end

local function NormalizeImportString(importString)
    if type(importString) ~= "string" then
        return nil
    end
    return importString:gsub("^%s+", ""):gsub("%s+$", "")
end

local function EncodePayload(prefix, payload)
    if not LibDeflate then
        return nil, "LibDeflate no disponible."
    end

    local serialized = Serializer.Serialize(payload)
    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then
        return nil, "No se pudo comprimir la cadena."
    end

    return prefix .. LibDeflate:EncodeForPrint(compressed)
end

local function DecodePayload(prefix, importString)
    if not LibDeflate then
        return nil, "LibDeflate no disponible."
    end

    importString = NormalizeImportString(importString)
    if not importString or importString == "" then
        return nil, "Cadena vacia."
    end

    if importString:sub(1, #prefix) ~= prefix then
        return nil, "Prefijo invalido."
    end

    local encoded = importString:sub(#prefix + 1)
    local decoded = LibDeflate:DecodeForPrint(encoded)
    if not decoded then
        return nil, "No se pudo decodificar la cadena."
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return nil, "No se pudo descomprimir la cadena."
    end

    local payload = Serializer.Deserialize(decompressed)
    if type(payload) ~= "table" then
        return nil, "No se pudo leer el payload."
    end

    return payload
end

local function CaptureCurrentCDMSpec()
    local profile = GetCDMProfile()
    if not profile then
        return
    end

    local specKey = tostring(profile.activeSpecKey or "0")
    if specKey == "0" then
        return
    end

    profile.specProfiles = profile.specProfiles or {}

    local captured = {
        barSpells = {},
        barGlows = DeepCopy(profile.barGlows),
    }

    if profile.cdmBars and profile.cdmBars.bars then
        for _, barData in ipairs(profile.cdmBars.bars) do
            if barData.key then
                local entry = {}
                if MAIN_BAR_KEYS[barData.key] then
                    entry.trackedSpells = DeepCopy(barData.trackedSpells)
                    entry.extraSpells = DeepCopy(barData.extraSpells)
                    entry.removedSpells = DeepCopy(barData.removedSpells)
                    entry.dormantSpells = DeepCopy(barData.dormantSpells)
                elseif barData.barType ~= "trinkets" then
                    entry.customSpells = DeepCopy(barData.customSpells)
                    if TALENT_AWARE_BAR_TYPES[barData.barType] then
                        entry.dormantSpells = DeepCopy(barData.dormantSpells)
                    end
                end
                captured.barSpells[barData.key] = entry
            end
        end
    end

    profile.specProfiles[specKey] = captured
end

local function ApplyCDMSpecToLive(specKey)
    local profile = GetCDMProfile()
    if not profile or not profile.specProfiles then
        return
    end

    local snapshot = profile.specProfiles[specKey]
    if not snapshot then
        return
    end

    if snapshot.barSpells and profile.cdmBars and profile.cdmBars.bars then
        for _, barData in ipairs(profile.cdmBars.bars) do
            local saved = snapshot.barSpells[barData.key]
            if saved then
                if MAIN_BAR_KEYS[barData.key] then
                    barData.trackedSpells = DeepCopy(saved.trackedSpells)
                    barData.extraSpells = DeepCopy(saved.extraSpells)
                    barData.removedSpells = DeepCopy(saved.removedSpells)
                    barData.dormantSpells = DeepCopy(saved.dormantSpells)
                elseif barData.barType ~= "trinkets" then
                    barData.customSpells = DeepCopy(saved.customSpells)
                    if TALENT_AWARE_BAR_TYPES[barData.barType] then
                        barData.dormantSpells = DeepCopy(saved.dormantSpells)
                    end
                end
            end
        end
    end

    if snapshot.barGlows ~= nil then
        profile.barGlows = DeepCopy(snapshot.barGlows)
    end

    if ns.BuildAllCDMBars then
        ns.BuildAllCDMBars()
    end
end

local function RemoveAssignedProfile(profileName)
    local meta = GetMetaDB()
    if not meta then
        return
    end

    if meta.specAssignments then
        for specID, assignedProfile in pairs(meta.specAssignments) do
            if assignedProfile == profileName then
                meta.specAssignments[specID] = nil
            end
        end
    end

    if meta.characterSpecAssignments then
        for _, assignmentTable in pairs(meta.characterSpecAssignments) do
            if type(assignmentTable) == "table" then
                for specID, assignedProfile in pairs(assignmentTable) do
                    if assignedProfile == profileName then
                        assignmentTable[specID] = nil
                    end
                end
            end
        end
    end
end

local function PromptReloadPopup(message)
    StaticPopup_Show("KT_PROFILE_RELOAD", message or "Se recomienda recargar la interfaz para aplicar todos los cambios.")
end

local function SyncCDMProfileBridge()
    if type(rawget(_G, "_KUI_CDM_SyncProfileDB")) == "function" then
        pcall(_G._KUI_CDM_SyncProfileDB)
    end
end

local function SafeCallModuleMethod(moduleName, ...)
    if not KT or not KT.GetModule then
        return false
    end

    local module = KT:GetModule(moduleName, true)
    if not module then
        return false
    end

    for index = 1, select("#", ...) do
        local methodName = select(index, ...)
        if type(module[methodName]) == "function" then
            pcall(module[methodName], module)
            return true
        end
    end

    return false
end

local function GetAccentRGB()
    if KT and KT.GetStyleAccentRGB then
        return KT:GetStyleAccentRGB()
    end
    return 1, 0, 0.3333333333
end

local function ApplyProfileTransferButtonStyle(button, primary)
    if not button then return end
    local r, g, b = GetAccentRGB()
    if KT and KT.AddBackdrop then
        KT:AddBackdrop(button, primary and r * 0.16 or 0.06, primary and g * 0.16 or 0.06, primary and b * 0.16 or 0.08, 0.96)
    end
    if KT and KT.AddBorder then
        KT:AddBorder(button, primary and r or r * 0.55, primary and g or g * 0.55, primary and b or b * 0.55, primary and 0.95 or 0.65, 1)
    end
    if button.text then
        button.text:SetTextColor(primary and 1 or 0.88, primary and 1 or 0.88, primary and 1 or 0.9, 1)
    end
end

local function CreateProfileTransferButton(parent, text, width, onClick, primary)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, 30)
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont(KT.FONT_PATH, 11, "OUTLINE")
    button.text:SetPoint("CENTER")
    button.text:SetText(text or "")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        local r, g, b = GetAccentRGB()
        if KT and KT.AddBackdrop then
            KT:AddBackdrop(self, r * 0.22, g * 0.22, b * 0.22, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        ApplyProfileTransferButtonStyle(self, primary)
    end)
    ApplyProfileTransferButtonStyle(button, primary)
    return button
end

local function UpdateProfileTransferWindowStyle(frame)
    if not frame then return end
    local r, g, b = GetAccentRGB()
    if KT and KT.AddBackdrop then
        KT:AddBackdrop(frame, 0.015, 0.015, 0.018, 0.98)
        KT:AddBackdrop(frame.editBackdrop, 0.02, 0.02, 0.026, 0.98)
    end
    if KT and KT.AddBorder then
        KT:AddBorder(frame, r, g, b, 0.95, 1)
        KT:AddBorder(frame.editBackdrop, r * 0.55, g * 0.55, b * 0.55, 0.82, 1)
    end
    if frame.title then frame.title:SetTextColor(r, g, b, 1) end
    if frame.accentLine then frame.accentLine:SetColorTexture(r, g, b, 0.72) end
    if frame.closeButton and frame.closeButton.text then frame.closeButton.text:SetTextColor(r, g, b, 1) end
    local scrollBar = frame.scroll and (frame.scroll.ScrollBar or frame.scroll.scrollBar)
    if scrollBar then
        if scrollBar.GetThumbTexture then
            local thumb = scrollBar:GetThumbTexture()
            if thumb and thumb.SetColorTexture then
                thumb:SetColorTexture(r, g, b, 0.82)
            elseif thumb and thumb.SetVertexColor then
                thumb:SetVertexColor(r, g, b, 0.82)
            end
        end
        for _, region in ipairs({ scrollBar:GetRegions() }) do
            if region and region.SetVertexColor then
                region:SetVertexColor(r * 0.45, g * 0.45, b * 0.45, 0.62)
            end
        end
    end
    ApplyProfileTransferButtonStyle(frame.primaryButton, true)
    ApplyProfileTransferButtonStyle(frame.secondaryButton, false)
end

function Mod:CreateProfileTransferWindow()
    if self.profileTransferWindow then
        return self.profileTransferWindow
    end

    local frame = CreateFrame("Frame", "KullThranUIProfileTransferWindow", UIParent, "BackdropTemplate")
    frame:SetSize(640, 470)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(900)
    if frame.SetToplevel then
        frame:SetToplevel(true)
    end
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont(KT.FONT_PATH, 18, "OUTLINE")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -20)
    frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -48, -20)
    frame.title:SetJustifyH("LEFT")

    frame.closeButton = CreateFrame("Button", nil, frame)
    frame.closeButton:SetSize(24, 24)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
    frame.closeButton.text = frame.closeButton:CreateFontString(nil, "OVERLAY")
    frame.closeButton.text:SetFont(KT.FONT_PATH, 16, "OUTLINE")
    frame.closeButton.text:SetPoint("CENTER", 0, 1)
    frame.closeButton.text:SetText("X")
    frame.closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.accentLine = frame:CreateTexture(nil, "ARTWORK")
    frame.accentLine:SetHeight(1)
    frame.accentLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -54)
    frame.accentLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -54)

    frame.warning = frame:CreateFontString(nil, "OVERLAY")
    frame.warning:SetFont(KT.FONT_PATH, 11, "OUTLINE")
    frame.warning:SetTextColor(0.94, 0.86, 0.86, 1)
    frame.warning:SetJustifyH("LEFT")
    frame.warning:SetJustifyV("TOP")
    frame.warning:SetPoint("TOPLEFT", frame.accentLine, "BOTTOMLEFT", 0, -14)
    frame.warning:SetPoint("TOPRIGHT", frame.accentLine, "BOTTOMRIGHT", 0, -14)

    frame.editBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.editBackdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -94)
    frame.editBackdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 72)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame.editBackdrop, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame.editBackdrop, "TOPLEFT", 10, -10)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.editBackdrop, "BOTTOMRIGHT", -28, 10)
    frame.scroll:EnableMouseWheel(true)
    local function ScrollEditBox(delta)
        local current = frame.scroll:GetVerticalScroll() or 0
        local range = frame.scroll:GetVerticalScrollRange() or 0
        local nextValue = current - ((tonumber(delta) or 0) * 40)
        frame.scroll:SetVerticalScroll(math.max(0, math.min(range, nextValue)))
    end
    frame.scroll:SetScript("OnMouseWheel", function(_, delta)
        ScrollEditBox(delta)
    end)

    frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
    frame.editBox:SetMultiLine(true)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:EnableMouseWheel(true)
    frame.editBox:SetFont(KT.FONT_PATH, 11, "")
    frame.editBox:SetTextColor(0.94, 0.94, 0.96, 1)
    frame.editBox:SetJustifyH("LEFT")
    frame.editBox:SetJustifyV("TOP")
    frame.editBox:SetWidth(560)
    frame.editBox:SetHeight(260)
    frame.editBox:SetMaxLetters(0)
    frame.editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    frame.editBox:SetScript("OnMouseWheel", function(_, delta)
        ScrollEditBox(delta)
    end)
    frame.editBox:SetScript("OnTextChanged", function(self)
        local textHeight
        if self.GetStringHeight then
            textHeight = self:GetStringHeight()
        elseif self.GetNumLines then
            textHeight = (self:GetNumLines() or 1) * 14
        else
            local lines = 1
            local text = self:GetText() or ""
            for _ in text:gmatch("\n") do
                lines = lines + 1
            end
            textHeight = lines * 14
        end
        self:SetHeight(math.max(260, textHeight + 24))
    end)
    frame.scroll:SetScrollChild(frame.editBox)

    frame.status = frame:CreateFontString(nil, "OVERLAY")
    frame.status:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    frame.status:SetTextColor(0.88, 0.88, 0.9, 1)
    frame.status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 28)
    frame.status:SetPoint("RIGHT", frame, "RIGHT", -300, 0)
    frame.status:SetJustifyH("LEFT")

    frame.secondaryButton = CreateProfileTransferButton(frame, LText("Cancel"), 116, function()
        frame:Hide()
    end, false)
    frame.secondaryButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 22)

    frame.primaryButton = CreateProfileTransferButton(frame, LText("Import"), 132, function()
        if frame.mode == "import" and frame.handler then
            local text = frame.editBox and frame.editBox:GetText() or ""
            if strtrim(text or "") == "" then
                frame.status:SetText(LText("Paste a profile string before importing."))
                return
            end
            local ok, err = pcall(frame.handler, text)
            if not ok then
                frame.status:SetText(tostring(err or LText("The profile could not be imported.")))
                return
            end
            frame:Hide()
        else
            if frame.editBox then
                frame.editBox:SetFocus()
                frame.editBox:HighlightText()
            end
        end
    end, true)
    frame.primaryButton:SetPoint("RIGHT", frame.secondaryButton, "LEFT", -10, 0)

    frame:SetScript("OnShow", function(self)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:SetFrameLevel(900)
        if self.Raise then
            self:Raise()
        end
        UpdateProfileTransferWindowStyle(self)
    end)
    self.profileTransferWindow = frame
    return frame
end

function Mod:ShowProfileTransferWindow(mode, title, value, warning, handler)
    local frame = self:CreateProfileTransferWindow()
    frame.mode = mode
    frame.handler = handler
    frame.title:SetText(title or LText(mode == "import" and "Import" or "Export"))
    frame.warning:SetText(warning or "")
    frame.status:SetText(mode == "export" and LText("Text selected. Press Ctrl+C to copy it.") or "")
    frame.primaryButton.text:SetText(LText(mode == "import" and "Import" or "Select"))
    frame.secondaryButton.text:SetText(LText(mode == "import" and "Cancel" or "Close"))
    frame.editBox:SetText(mode == "export" and (value or "") or "")
    frame.editBox:SetCursorPosition(0)
    UpdateProfileTransferWindowStyle(frame)
    frame:Show()
    frame.editBox:SetFocus()
    if mode == "export" then
        frame.editBox:HighlightText()
    else
        frame.editBox:HighlightText(0, 0)
    end
end

function Mod:OnInitialize()

    StaticPopupDialogs["KT_PROFILE_RELOAD"] = {
        text = LText("Reloading the interface is recommended to apply the profile change.\n\n%s"),
        button1 = LText("Reload UI"),
        button2 = LText("Later"),
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function()
            ReloadUI()
        end,
    }

    self.specWatcher = CreateFrame("Frame")
    self.specWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.specWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.specWatcher:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            Mod:RegisterProfileCallbacks()
            Mod:InitializeProfileBridge()
        else
            Mod:HandleSpecChange()
        end
    end)
    self.specWatcher:RegisterEvent("PLAYER_LOGIN")

    self:RegisterProfileCallbacks()
    C_Timer.After(0, function()
        Mod:RegisterProfileCallbacks()
        Mod:InitializeProfileBridge()
    end)
end

function Mod:RegisterProfileCallbacks()
    if self._profileCallbacksRegistered or not (KT and KT.db and KT.db.RegisterCallback) then
        return self._profileCallbacksRegistered == true
    end

    KT.db.RegisterCallback(self, "OnProfileShutdown", "HandleProfileShutdown")
    KT.db.RegisterCallback(self, "OnProfileChanged", "HandleProfileChanged")
    KT.db.RegisterCallback(self, "OnProfileReset", "HandleProfileReset")
    KT.db.RegisterCallback(self, "OnProfileDeleted", "HandleProfileDeleted")
    self._profileCallbacksRegistered = true
    return true
end

function Mod:InitializeProfileBridge()
    if not (KT and KT.db) then
        return
    end

    self:RegisterProfileCallbacks()
    local currentProfile = KT.db:GetCurrentProfile()
    local meta = GetMetaDB()
    if currentProfile and meta and not meta.externalProfiles[currentProfile] then
        -- Existing installations predate the external-profile bridge. Capture
        -- the live state once; do not overwrite any snapshot already present.
        SaveExternalProfileSnapshot(currentProfile)
    end
end

function Mod:HandleProfileShutdown(_, db)
    if self._profileTransition or not db then
        return
    end

    local profileName = db.GetCurrentProfile and db:GetCurrentProfile()
    if profileName then
        CaptureCurrentCDMSpec()
        SaveExternalProfileSnapshot(profileName)
    end
end

function Mod:HandleProfileChanged(_, db, profileName)
    if self._profileTransition or not (db and profileName) then
        return
    end

    self._profileTransition = true
    local meta = GetMetaDB()
    if meta and meta.externalProfiles and meta.externalProfiles[profileName] then
        RestoreExternalProfileSnapshot(profileName)
    elseif meta then
        -- A legacy KUI profile has no historical external state. Preserve the
        -- currently loaded external settings and associate them with it so a
        -- later switch cannot accidentally inherit another profile's state.
        SaveExternalProfileSnapshot(profileName)
    end
    self._profileTransition = nil
    self:RefreshProfileRuntime()
end

function Mod:HandleProfileReset(_, db)
    if self._profileTransition then
        return
    end

    self._profileTransition = true
    ResetExternalProfileSources()
    local profileName = db and db.GetCurrentProfile and db:GetCurrentProfile()
    if profileName then
        local meta = GetMetaDB()
        if meta and meta.externalProfiles then
            meta.externalProfiles[profileName] = nil
        end
        SaveExternalProfileSnapshot(profileName)
    end
    self._profileTransition = nil
end

function Mod:HandleProfileDeleted(_, _, profileName)
    if not profileName then
        return
    end
    RemoveAssignedProfile(profileName)
    local meta = GetMetaDB()
    if meta and meta.externalProfiles then
        meta.externalProfiles[profileName] = nil
    end
end

function Mod:ShowExportPopup(title, value)
    self:ShowProfileTransferWindow("export", title, value)
end

function Mod:ShowImportPopup(title, warning, handler)
    self:ShowProfileTransferWindow("import", title, nil, warning, handler)
end

function Mod:RefreshProfileRuntime()
    SyncCDMProfileBridge()

    if KT and KT.ApplyUIScale then
        pcall(KT.ApplyUIScale, KT)
    end

    if KT and KT.RefreshAllModules then
        pcall(KT.RefreshAllModules, KT)
    end

    SafeCallModuleMethod("Minimap", "Refresh", "UpdateAll")
    SafeCallModuleMethod("MinimapButton", "Refresh")
    SafeCallModuleMethod("Chat", "OnProfileUpdate")
    SafeCallModuleMethod("Bags", "OnProfileUpdate")
    SafeCallModuleMethod("CastBar", "Refresh", "ApplySettings")
    SafeCallModuleMethod("Tooltip", "Refresh")
    SafeCallModuleMethod("Enhancements", "RefreshSettings")
    SafeCallModuleMethod("Armory", "Refresh")
    SafeCallModuleMethod("InspectArmory", "Refresh")
    SafeCallModuleMethod("ExperienceBar", "Refresh", "UpdateBar", "ApplyLayout")
    SafeCallModuleMethod("ResourceBars", "UpdateBars")
    SafeCallModuleMethod("UnitFrames", "Refresh")
    SafeCallModuleMethod("BlizzardFrames", "Refresh", "RefreshFadeState", "UpdateMouseoverState")

    if _G._KUI_CDM_Apply then
        pcall(_G._KUI_CDM_Apply)
    end

    if KT and KT.RefreshPage then
        pcall(KT.RefreshPage, KT)
    end
end

function Mod:CaptureCurrentCDMSpec()
    CaptureCurrentCDMSpec()
end

function Mod:GetModuleDefinitions()
    local definitions = {}
    local root = GetRootProfile()
    for _, definition in ipairs(MODULE_DEFS) do
        local hasData = false
        for _, key in ipairs(definition.keys) do
            if root and root[key] ~= nil then
                hasData = true
                break
            end
        end
        if not hasData and root then
            for rootKey, childKeys in pairs(definition.nested or {}) do
                local rootValue = root[rootKey]
                for _, childKey in ipairs(childKeys) do
                    if type(rootValue) == "table" and rootValue[childKey] ~= nil then
                        hasData = true
                        break
                    end
                end
                if hasData then
                    break
                end
            end
        end
        if not hasData then
            for _, sourceID in ipairs(definition.external or {}) do
                if HasExternalProfileSource(sourceID) then
                    hasData = true
                    break
                end
            end
        end
        if hasData then
            definitions[#definitions + 1] = definition
        end
    end
    return definitions
end

function Mod:GetPageProfileInfo(pageID)
    local scope = PAGE_PROFILE_SCOPES[pageID]
    if type(scope) ~= "table" or #scope == 0 then
        return nil
    end

    local moduleIDs = {}
    for _, moduleID in ipairs(scope) do
        if MODULE_BY_ID[moduleID] and not LEGACY_MODULE_DEFS[moduleID] then
            moduleIDs[#moduleIDs + 1] = moduleID
        end
    end
    if #moduleIDs == 0 then
        return nil
    end

    local primary = MODULE_BY_ID[moduleIDs[1]]
    return {
        pageID = pageID,
        label = primary and primary.label or tostring(pageID),
        moduleIDs = moduleIDs,
    }
end

function Mod:SnapshotModule(moduleID)
    if LEGACY_MODULE_DEFS[moduleID] then
        return nil
    end
    local definition = MODULE_BY_ID[moduleID]
    local root = GetRootProfile()
    if not definition or not root then
        return nil
    end

    local snapshot = {}
    local hasData = false
    for _, key in ipairs(definition.keys) do
        if root[key] ~= nil then
            snapshot[key] = CopyDefinitionRootValue(definition, key, root[key])
            hasData = true
        end
    end
    for rootKey, childKeys in pairs(definition.nested or {}) do
        local rootValue = root[rootKey]
        if type(rootValue) == "table" then
            for _, childKey in ipairs(childKeys) do
                if rootValue[childKey] ~= nil then
                    snapshot[rootKey] = snapshot[rootKey] or {}
                    snapshot[rootKey][childKey] = DeepCopy(rootValue[childKey])
                    hasData = true
                end
            end
        end
    end
    if type(definition.external) == "table" then
        local external = CaptureExternalProfileSources(definition.external)
        if next(external) then
            snapshot._external = external
            hasData = true
        end
    end

    return hasData and snapshot or nil
end

function Mod:ApplyModulesFromProfile(profileName, moduleIDs)
    if not (KT and KT.db and KT.db.sv and KT.db.sv.profiles) then
        return false, "Base de datos no disponible."
    end
    local sourceRoot = KT.db.sv.profiles[profileName]
    if type(sourceRoot) ~= "table" then
        return false, "Perfil de origen invalido."
    end
    if type(moduleIDs) ~= "table" or #moduleIDs == 0 then
        return false, "Selecciona al menos un modulo."
    end

    local modules = {}
    local meta = GetMetaDB()
    for _, moduleID in ipairs(moduleIDs) do
        local definition = MODULE_BY_ID[moduleID]
        if definition and not LEGACY_MODULE_DEFS[moduleID] then
            local snapshot = {}
            local hasData = false
            for _, key in ipairs(definition.keys or {}) do
                if sourceRoot[key] ~= nil then
                    snapshot[key] = CopyDefinitionRootValue(definition, key, sourceRoot[key])
                    hasData = true
                end
            end
            for rootKey, childKeys in pairs(definition.nested or {}) do
                local sourceValue = sourceRoot[rootKey]
                if type(sourceValue) == "table" then
                    for _, childKey in ipairs(childKeys) do
                        if sourceValue[childKey] ~= nil then
                            snapshot[rootKey] = snapshot[rootKey] or {}
                            snapshot[rootKey][childKey] = DeepCopy(sourceValue[childKey])
                            hasData = true
                        end
                    end
                end
            end
            local external = meta and meta.externalProfiles and meta.externalProfiles[profileName]
            if (type(external) ~= "table" or not next(external))
                and KT.db:GetCurrentProfile() == profileName then
                -- The active profile may be from before the bridge existed.
                -- Its live external state is the only authoritative fallback.
                external = CaptureAllExternalProfileSources()
            end
            if type(external) == "table" and type(definition.external) == "table" then
                snapshot._external = {}
                for _, sourceID in ipairs(definition.external) do
                    if external[sourceID] then
                        snapshot._external[sourceID] = DeepCopy(external[sourceID])
                        hasData = true
                    end
                end
            end
            if hasData then modules[moduleID] = snapshot end
        end
    end

    if not next(modules) then return false, LText("The profile contains no data for those modules.") end
    local ok, err = self:ApplyModules(modules)
    if not ok then return false, err end
    self:RefreshProfileRuntime()
    return true
end

local function SanitizeInterruptGlowProfile(value)
    if type(value) ~= "table" then
        return nil
    end
    return {
        enable = value.enable,
        cdText = value.cdText,
        cdm = value.cdm,
    }
end

local function BuildTransferProfile(profileData)
    local snapshot = {}
    for key, value in pairs(profileData or {}) do
        if key == "interruptsGlow" then
            snapshot[key] = SanitizeInterruptGlowProfile(value)
        elseif key ~= "progressBars" and key ~= "kuiMove" and key ~= "blizzMove" and key ~= "BlizzMove" and key ~= "KUIMove" and key ~= "dandersIntegration" then
            snapshot[key] = DeepCopy(value)
        end
    end
    if snapshot.kuiMove == nil and type(profileData) == "table" then
        snapshot.kuiMove = DeepCopy(profileData.kuiMove or profileData.blizzMove or profileData.BlizzMove or profileData.KUIMove)
    end
    return snapshot
end

function Mod:ExportCurrentProfileString()
    local root = GetRootProfile()
    if not root then
        return nil, "Perfil no disponible."
    end

    local profileSnapshot = BuildTransferProfile(root)

    local payload = {
        version = 1,
        type = "full",
        data = profileSnapshot,
        savedVariables = CaptureAllExternalProfileSources(),
    }
    return EncodePayload(EXPORT_PREFIX, payload)
end

function Mod:ExportModulesString(moduleIDs)
    if type(moduleIDs) ~= "table" or #moduleIDs == 0 then
        return nil, "Selecciona al menos un modulo."
    end

    local exported = {}
    for _, moduleID in ipairs(moduleIDs) do
        local snapshot = self:SnapshotModule(moduleID)
        if snapshot then
            exported[moduleID] = snapshot
        end
    end

    if not next(exported) then
        return nil, "No se pudo capturar ningun modulo."
    end

    local payload = {
        version = 1,
        type = "modules",
        data = {
            modules = exported,
        },
    }
    return EncodePayload(EXPORT_PREFIX, payload)
end

function Mod:ExportPageProfileString(pageID)
    local info = self:GetPageProfileInfo(pageID)
    if not info then
        return nil, "Esta pagina no tiene un perfil de modulo registrado."
    end
    return self:ExportModulesString(info.moduleIDs)
end

function Mod:ResetSubmoduleProfile(pageID)
    local key = pageID == "damagemeter" and "damageMeter"
        or pageID == "mythicplustimer" and "mplusTracker"
    if not key then return false, "Unknown submodule profile." end
    local root = GetRootProfile()
    if not root then return false, "Profile unavailable." end
    root.enhancements = root.enhancements or {}
    root.enhancements[key] = nil
    self:RefreshProfileRuntime()
    PromptReloadPopup("Submodule profile reset.")
    return true
end

function Mod:ApplyFullProfile(profileData)
    local root = GetRootProfile()
    if type(root) ~= "table" or type(profileData) ~= "table" then
        return false, "Perfil invalido."
    end

    local transferProfile = BuildTransferProfile(profileData)
    WipeTable(root)
    for key, value in pairs(transferProfile) do
        root[key] = DeepCopy(value)
    end
    return true
end

function Mod:ApplyModules(moduleData)
    local root = GetRootProfile()
    if type(root) ~= "table" or type(moduleData) ~= "table" then
        return false, "Modulo invalido."
    end

    for moduleID, snapshot in pairs(moduleData) do
        local definition = MODULE_BY_ID[moduleID]
        if definition and type(snapshot) == "table" then
            for _, key in ipairs(definition.keys) do
                if snapshot[key] ~= nil then
                    if key == "interruptsGlow" then
                        root[key] = SanitizeInterruptGlowProfile(snapshot[key])
                    else
                        local preserved = {}
                        for childKey in pairs((definition.omit and definition.omit[key]) or {}) do
                            if type(root[key]) == "table" and root[key][childKey] ~= nil then
                                preserved[childKey] = DeepCopy(root[key][childKey])
                            end
                        end
                        root[key] = DeepCopy(snapshot[key])
                        if next(preserved) then
                            root[key] = root[key] or {}
                            for childKey, childValue in pairs(preserved) do
                                root[key][childKey] = childValue
                            end
                        end
                    end
                end
            end
            for rootKey, childKeys in pairs(definition.nested or {}) do
                local snapshotRoot = snapshot[rootKey]
                if type(snapshotRoot) == "table" then
                    root[rootKey] = root[rootKey] or {}
                    for _, childKey in ipairs(childKeys) do
                        if snapshotRoot[childKey] ~= nil then
                            root[rootKey][childKey] = DeepCopy(snapshotRoot[childKey])
                        end
                    end
                end
            end
            for _, key in ipairs(definition.importKeys or {}) do
                if snapshot[key] ~= nil then
                    local targetKey = (key == "blizzMove" or key == "BlizzMove" or key == "KUIMove") and "kuiMove" or key
                    root[targetKey] = DeepCopy(snapshot[key])
                end
            end
            local ok, err = ApplyExternalProfileSources(snapshot._external)
            if not ok then
                return false, err
            end
        end
    end

    return true
end

function Mod:ImportProfileString(importString)
    importString = NormalizeImportString(importString)
    if importString and importString:sub(1, #CDM_EXPORT_PREFIX) == CDM_EXPORT_PREFIX then
        return false, "Esa cadena es un perfil CDM por especializacion. Usa el importador CDM."
    end

    local payload, err = DecodePayload(EXPORT_PREFIX, importString)
    if not payload then
        return false, err
    end

    if payload.version ~= 1 then
        return false, "Version de perfil no soportada."
    end

    if payload.type == "full" then
        local ok, applyErr = self:ApplyFullProfile(payload.data)
        if not ok then
            return false, applyErr
        end
        ok, applyErr = ApplyExternalProfileSources(payload.savedVariables)
        if not ok then
            return false, applyErr
        end
        SaveExternalProfileSnapshot(KT.db and KT.db:GetCurrentProfile())
    elseif payload.type == "modules" then
        local modules = payload.data and payload.data.modules
        local ok, applyErr = self:ApplyModules(modules)
        if not ok then
            return false, applyErr
        end
        SaveExternalProfileSnapshot(KT.db and KT.db:GetCurrentProfile())
    else
        return false, "Tipo de importacion desconocido."
    end

    self:RefreshProfileRuntime()
    PromptReloadPopup("El perfil se ha importado correctamente.")
    return true
end

function Mod:ImportPageProfileString(pageID, importString)
    local info = self:GetPageProfileInfo(pageID)
    if not info then
        return false, "Esta pagina no tiene un perfil de modulo registrado."
    end

    importString = NormalizeImportString(importString)
    if importString and importString:sub(1, #CDM_EXPORT_PREFIX) == CDM_EXPORT_PREFIX then
        return false, "Esa cadena es un perfil CDM por especializacion."
    end

    local payload, err = DecodePayload(EXPORT_PREFIX, importString)
    if not payload then
        return false, err
    end
    if payload.version ~= 1 then
        return false, "Version de perfil no soportada."
    end
    if payload.type ~= "modules" then
        return false, "Este importador solo acepta perfiles de modulos, no perfiles completos."
    end

    local sourceModules = payload.data and payload.data.modules
    if type(sourceModules) ~= "table" then
        return false, "La cadena no contiene datos de modulos."
    end

    -- Apply only the scope owned by the open page. A string containing several
    -- modules is safe to paste here: unrelated modules are deliberately ignored.
    local filtered = {}
    local importedLabels = {}
    for _, moduleID in ipairs(info.moduleIDs) do
        if type(sourceModules[moduleID]) == "table" then
            filtered[moduleID] = DeepCopy(sourceModules[moduleID])
            local definition = MODULE_BY_ID[moduleID]
            importedLabels[#importedLabels + 1] = definition and definition.label or moduleID
        end
    end
    if not next(filtered) then
        return false, "La cadena no contiene datos para " .. tostring(info.label) .. "."
    end

    local ok, applyErr = self:ApplyModules(filtered)
    if not ok then
        return false, applyErr
    end

    SaveExternalProfileSnapshot(KT.db and KT.db:GetCurrentProfile())
    self:RefreshProfileRuntime()
    PromptReloadPopup("Se ha importado: " .. table.concat(importedLabels, ", ") .. ".")
    return true
end

function Mod:GetProfileValues()
    if not KT or not KT.db then
        return {}, {}
    end

    local list = KT.db:GetProfiles({})
    table.sort(list, function(left, right)
        return tostring(left) < tostring(right)
    end)

    local values = {}
    for _, name in ipairs(list) do
        values[name] = name
    end
    return values, list
end

function Mod:SaveCurrentAsProfile(name)
    if not KT or not KT.db then
        return false, "Base de datos no disponible."
    end

    name = name and strtrim(name) or ""
    if name == "" then
        return false, "Escribe un nombre de perfil."
    end

    local currentName = KT.db:GetCurrentProfile()
    if name == currentName then
        return true
    end

    CaptureCurrentCDMSpec()
    SaveExternalProfileSnapshot(currentName)

    local currentSnapshot = DeepCopy(GetRootProfile())
    local currentExternalSnapshot = CaptureAllExternalProfileSources()
    KT.db:SetProfile(name)

    local root = GetRootProfile()
    if type(root) ~= "table" then
        return false, "No se pudo crear el nuevo perfil."
    end

    WipeTable(root)
    if type(currentSnapshot) == "table" then
        for key, value in pairs(currentSnapshot) do
            root[key] = DeepCopy(value)
        end
    end
    local metaDB = GetMetaDB()
    if metaDB then
        metaDB.externalProfiles = metaDB.externalProfiles or {}
        metaDB.externalProfiles[name] = DeepCopy(currentExternalSnapshot)
    end

    local specAssignments = GetCharacterSpecAssignments(true)
    local specID = GetCurrentSpecID()
    local meta = GetMetaDB()
    local specKey = specID and tostring(specID) or nil
    if specAssignments and specKey then
        if specAssignments[specKey] == currentName then
            specAssignments[specKey] = name
        elseif specAssignments[specKey] == nil and meta and meta.specAssignments and meta.specAssignments[specKey] == currentName then
            specAssignments[specKey] = name
        end
    end

    self:RefreshProfileRuntime()
    return true
end

function Mod:SwitchProfile(name)
    if not KT or not KT.db then
        return false, "Base de datos no disponible."
    end

    if not name or name == "" then
        return false, "Perfil invalido."
    end

    if KT.db:GetCurrentProfile() == name then
        return true
    end

    CaptureCurrentCDMSpec()
    SaveExternalProfileSnapshot(KT.db:GetCurrentProfile())
    KT.db:SetProfile(name)
    RestoreExternalProfileSnapshot(name)
    self:RefreshProfileRuntime()
    PromptReloadPopup("Se ha cambiado al perfil '" .. name .. "'.")
    return true
end

function Mod:DeleteProfile(name)
    if not KT or not KT.db then
        return false, "Base de datos no disponible."
    end

    if not name or name == "" then
        return false, "Perfil invalido."
    end

    if KT.db:GetCurrentProfile() == name then
        return false, "No puedes borrar el perfil activo."
    end

    KT.db:DeleteProfile(name, true)
    RemoveAssignedProfile(name)
    local meta = GetMetaDB()
    if meta and meta.externalProfiles then
        meta.externalProfiles[name] = nil
    end

    self:RefreshProfileRuntime()
    return true
end

function Mod:GetCurrentSpecAssignment()
    local meta = GetMetaDB()
    local specID = GetCurrentSpecID()
    if not meta or not specID then
        return nil
    end

    local specKey = tostring(specID)
    local characterAssignments = GetCharacterSpecAssignments(false)
    if characterAssignments and characterAssignments[specKey] ~= nil then
        local assignedProfile = characterAssignments[specKey]
        if type(assignedProfile) == "string" and assignedProfile ~= "" then
            return assignedProfile
        end
        return nil
    end

    return nil
end

function Mod:AssignCurrentSpec(profileName)
    local characterAssignments = GetCharacterSpecAssignments(true)
    local specID = GetCurrentSpecID()
    if not characterAssignments or not specID then
        return false, "No se pudo detectar la especializacion actual."
    end

    characterAssignments[tostring(specID)] = profileName
    return true
end

function Mod:ClearCurrentSpecAssignment()
    local characterAssignments = GetCharacterSpecAssignments(true)
    local specID = GetCurrentSpecID()
    if not characterAssignments or not specID then
        return false, "No se pudo detectar la especializacion actual."
    end

    characterAssignments[tostring(specID)] = false
    return true
end

function Mod:HandleSpecChange()
    local specID = GetCurrentSpecID()
    if not specID or not KT or not KT.db then
        return
    end

    local pendingChoices = KT.db.global and KT.db.global.installerProfileChoicePendingByCharacter
    local characterKey = KT.GetInstallerCharacterKey and KT:GetInstallerCharacterKey()
    if characterKey and pendingChoices and pendingChoices[characterKey] then
        return
    end

    local targetProfile = self:GetCurrentSpecAssignment()
    if not targetProfile or targetProfile == "" then
        return
    end

    if KT.db:GetCurrentProfile() == targetProfile then
        return
    end

    CaptureCurrentCDMSpec()
    SaveExternalProfileSnapshot(KT.db:GetCurrentProfile())
    KT.db:SetProfile(targetProfile)
    RestoreExternalProfileSnapshot(targetProfile)
    self:RefreshProfileRuntime()
    PromptReloadPopup("Se ha asignado automaticamente el perfil '" .. targetProfile .. "' a tu especializacion actual.")
end

function Mod:GetCDMSpecEntries()
    local entries = {}
    local _, _, classID = UnitClass("player")
    local cdmProfile = GetCDMProfile()
    if cdmProfile and cdmProfile.activeSpecKey and cdmProfile.activeSpecKey ~= "0" then
        CaptureCurrentCDMSpec()
    end
    local stored = cdmProfile and cdmProfile.specProfiles or nil

    local count = GetNumSpecializationsForClassID and classID and GetNumSpecializationsForClassID(classID) or GetNumSpecializations()
    for index = 1, (count or 0) do
        local specID
        local specName
        local icon

        if GetSpecializationInfoForClassID and classID then
            specID, specName, _, icon = GetSpecializationInfoForClassID(classID, index)
        else
            specID, specName, _, icon = GetSpecializationInfo(index)
        end

        if specID then
            local key = tostring(specID)
            entries[#entries + 1] = {
                key = key,
                name = specName or ("Spec " .. key),
                icon = icon,
                hasData = stored and stored[key] ~= nil or false,
            }
        end
    end

    return entries
end

function Mod:ExportCDMSpellsString(specKeys)
    if type(specKeys) ~= "table" or #specKeys == 0 then
        return nil, "Selecciona al menos una especializacion."
    end

    CaptureCurrentCDMSpec()

    local cdmProfile = GetCDMProfile()
    if not cdmProfile or not cdmProfile.specProfiles then
        return nil, "No hay perfiles CDM guardados."
    end

    local exported = {}
    for _, specKey in ipairs(specKeys) do
        if cdmProfile.specProfiles[specKey] then
            exported[specKey] = DeepCopy(cdmProfile.specProfiles[specKey])
        end
    end

    if not next(exported) then
        return nil, "No hay datos CDM para las especializaciones seleccionadas."
    end

    local payload = {
        version = 1,
        type = "cdm_spells",
        data = exported,
    }
    return EncodePayload(CDM_EXPORT_PREFIX, payload)
end

function Mod:ImportCDMSpellsString(importString)
    importString = NormalizeImportString(importString)
    if importString and importString:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
        return false, "Esa cadena es un perfil general o de modulos. Usa el importador de perfiles."
    end

    local payload, err = DecodePayload(CDM_EXPORT_PREFIX, importString)
    if not payload then
        return false, err
    end

    if payload.version ~= 1 or payload.type ~= "cdm_spells" then
        return false, "Cadena CDM no valida."
    end

    local cdmProfile = GetCDMProfile()
    if not cdmProfile then
        return false, "Perfil CDM no disponible."
    end

    cdmProfile.specProfiles = cdmProfile.specProfiles or {}
    for specKey, specData in pairs(payload.data or {}) do
        cdmProfile.specProfiles[specKey] = DeepCopy(specData)
    end

    local currentSpecKey = tostring(cdmProfile.activeSpecKey or "0")
    if currentSpecKey ~= "0" and cdmProfile.specProfiles[currentSpecKey] then
        ApplyCDMSpecToLive(currentSpecKey)
    end

    self:RefreshProfileRuntime()
    PromptReloadPopup("El perfil CDM se ha importado correctamente.")
    return true
end
