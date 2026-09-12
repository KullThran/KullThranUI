-- ============================================================
--  KullThranUI - ProfileHandlers.lua
--  Fix: Inyección en Vivo (AceDB) y Soporte para Blizzard Edit Mode
-- ============================================================

local ADDON_NAME, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
ns.Handlers = {}

local LibDeflate    = LibStub("LibDeflate", true)
local LibSerialize  = LibStub("LibSerialize", true)
local AceSerializer = LibStub("AceSerializer-3.0", true)

local function DeepCopy(orig)
    local t = type(orig)
    if t ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do copy[DeepCopy(k)] = DeepCopy(v) end
    return setmetatable(copy, getmetatable(orig))
end

function ns.Handlers.Decode_LibSerialize(encoded)
    if not LibDeflate or not LibSerialize then
        return false, "LibSerialize no disponible"
    end
    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then return false, "DecodeForPrint falló" end
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return false, "DecompressDeflate falló" end
    local ok, data = LibSerialize:Deserialize(serialized)
    if not ok then return false, "LibSerialize Deserialize falló" end
    return true, data
end

function ns.Handlers.Decode_AceSer(encoded)
    if not LibDeflate or not AceSerializer then
        return false, "AceSerializer/LibDeflate no disponible"
    end
    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then return false, "DecodeForPrint falló" end
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return false, "DecompressDeflate falló" end
    local ok, data = AceSerializer:Deserialize(serialized)
    if not ok then return false, "AceSerializer Deserialize falló" end
    return true, data
end

-- ──────────────────────────────────────────────────────────
-- HELPER: Inyección Segura (Memoria en Vivo + Respaldo _G)
-- ──────────────────────────────────────────────────────────
local function ResolveAddonObject(addonGlobal)
    local candidates = type(addonGlobal) == "table" and addonGlobal or { addonGlobal }

    for _, candidate in ipairs(candidates) do
        if type(candidate) == "string" and candidate ~= "" then
            if LibStub("AceAddon-3.0", true) then
                local addonObj = LibStub("AceAddon-3.0"):GetAddon(candidate, true)
                if addonObj and addonObj.db then
                    return addonObj
                end
            end

            local globalObj = _G[candidate]
            if type(globalObj) == "table" and globalObj.db then
                return globalObj
            end
        end
    end
end

local function ApplyAceDBProfile(savedVarName, addonGlobal, profileName, profileData, opts)
    opts = opts or {}
    local activateProfile = opts.activate ~= false

    -- 1. Escribir en la base de datos cruda (_G) por si el addon carga después
    if not _G[savedVarName] then _G[savedVarName] = {} end
    local rawDB = _G[savedVarName]
    
    rawDB["profiles"] = rawDB["profiles"] or {}
    rawDB["profiles"][profileName] = DeepCopy(profileData)

    if savedVarName == "DandersFramesDB_v2" and activateProfile then
        rawDB["currentProfile"] = profileName
        if _G.DandersFramesCharDB then
            _G.DandersFramesCharDB.currentProfile = profileName
        end
    end

    if activateProfile then
        rawDB["profileKeys"] = rawDB["profileKeys"] or {}
        local charKey = UnitName("player") .. " - " .. GetRealmName()
        rawDB["profileKeys"][charKey] = profileName

        local safeName = UnitName("player"):gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
        for k in pairs(rawDB["profileKeys"]) do
            if type(k) == "string" and k:find("^" .. safeName .. " %-") then
                rawDB["profileKeys"][k] = profileName
            end
        end
    end

    -- 2. Inyección en VIVO (Obliga al addon a actualizarse al instante sin hacer /reload)
    local addonObj = ResolveAddonObject(addonGlobal)

    if addonObj and activateProfile and type(addonObj.SetProfile) == "function" then
        pcall(function() addonObj:SetProfile(profileName) end)
    end

    if addonObj and addonObj.db and type(addonObj.db) == "table" then
        if type(addonObj.db.profiles) == "table" then
            addonObj.db.profiles[profileName] = DeepCopy(profileData)
        end
        if activateProfile and type(addonObj.db.SetProfile) == "function" then
            pcall(function() addonObj.db:SetProfile(profileName) end)
        end
    end

    return true
end

-- ──────────────────────────────────────────────────────────
-- HANDLERS
-- ──────────────────────────────────────────────────────────

function ns.Handlers.DandersFrames(profileName, profileData)
    if type(profileData) == "table" and profileData.DPS then
        local ok1, err1 = ns.Handlers.DandersFrames("KullThranUI - DPS/Tank", profileData.DPS)
        local ok2, err2 = ns.Handlers.DandersFrames("KullThranUI - Healer", profileData.Healer)
        return ok1 and ok2, (err1 or "") .. " " .. (err2 or "")
    end

    local data = profileData
    if type(profileData) == "string" then
        local clean = profileData:gsub("^!DFP%d+!", "")
        local ok, decoded = ns.Handlers.Decode_LibSerialize(clean)
        if not ok then return false, "DandersFrames Decode Error" end
        data = decoded
    end

    local targets = {
        { savedVar = "DandersFramesDB_v2", addonNames = { "DandersFrames", "DF" } },
    }

    for _, target in ipairs(targets) do
        local ok, err = pcall(ApplyAceDBProfile, target.savedVar, target.addonNames, profileName, data, { activate = false })
        if not ok then
            return false, "DandersFrames: " .. tostring(err)
        end
    end

    return true
end

function ns.Handlers.Plater(profileName, profileData)
    profileName = profileName or "KullThranUI"
    local data = profileData
    if type(profileData) == "string" then
        local clean = profileData:gsub("^!PLATER:%d+!", "")
        local ok, decoded = ns.Handlers.Decode_AceSer(clean)
        if not ok then return false, "Plater Decode Error" end
        data = decoded
    end

    local ok, err = pcall(ApplyAceDBProfile, "PlaterDB", "Plater", profileName, data)
    if not ok then return false, "Plater: " .. tostring(err) end

    local PlaterAddon = _G["Plater"]
    if PlaterAddon and PlaterAddon.WipeAndRecompileAllScripts then
        C_Timer.After(0.5, function() pcall(PlaterAddon.WipeAndRecompileAllScripts, PlaterAddon, "hook", false) end)
    end
    return true
end

function ns.Handlers.UnhaltedUnitFrames(profileName, profileData)
    profileName = profileName or "KullThranUI"
    local data = profileData
    if type(profileData) == "string" then
        local clean = profileData:gsub("^!UUF_T", "")
        local ok, decoded = ns.Handlers.Decode_LibSerialize(clean)
        if not ok then return false, "UUF Decode Error" end
        data = decoded
    end
    local ok, err = pcall(ApplyAceDBProfile, "UUFDB", "UnhaltedUnitFrames", profileName, data)
    if not ok then return false, "UnhaltedUnitFrames: " .. tostring(err) end
    return true
end

function ns.Handlers.BetterCooldownManager(profileName, profileData)
    profileName = profileName or "KullThranUI"
    local data = profileData
    if type(profileData) == "string" then
        local clean = profileData:gsub("^!BCDM_T", "")
        local ok, decoded = ns.Handlers.Decode_AceSer(clean)
        if not ok then return false, "BCM Decode Error" end
        data = decoded
    end
    
    pcall(ApplyAceDBProfile, "BetterCooldownManagerDB", "BetterCooldownManager", profileName, data)
    pcall(ApplyAceDBProfile, "BCMDB", "BetterCooldownManager", profileName, data)
    return true
end

-- Diálogo emergente para importar el Edit Mode de Blizzard
StaticPopupDialogs["KT_EDITMODE_IMPORT"] = {
    text = "Se ha detectado un perfil de Edit Mode de Blizzard.\nCopia el texto de abajo (CTRL+C) y pégalo en:\n|cffffff00Modo Edición -> Diseño -> Importar|r",
    button1 = "Aceptar",
    hasEditBox = true,
    OnShow = function(self, data)
        self.editBox:SetText(data)
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ns.Handlers.Layout(profileName, profileData)
    -- [1] Si es un código nativo de Blizzard, mostramos el popup para que el usuario lo importe
    if type(profileData) == "string" then
        StaticPopup_Show("KT_EDITMODE_IMPORT", "", "", profileData)
        return true
    end

    -- [2] Si es un layout interno de KullThranUI (Escala y Marcos propios)
    if type(profileData) ~= "table" then return false, "Formato de Layout inválido." end

    if KT.db:GetCurrentProfile() ~= profileName then
        KT.db:SetProfile(profileName)
    end

    if profileData.uiScale then
        if KT.db and KT.db.profile and KT.db.profile.useBlizzardUIScale and KT.SetBlizzardUIScale then
            KT:SetBlizzardUIScale(profileData.uiScale)
        else
            KT.db.profile.uiScale = profileData.uiScale
            if KT.ApplyUIScale then KT:ApplyUIScale() end
        end
    end

    if profileData.frames then
        if not KT.db.profile.editMode then KT.db.profile.editMode = {} end
        local frames = DeepCopy(profileData.frames)
        if KT.SanitizeEditModeFramesDB then
            KT:SanitizeEditModeFramesDB(frames)
        end
        KT.db.profile.editMode.frames = frames
        
        local EM = KT:GetModule("EditMode", true)
        if EM and EM.RestoreAllPositions then
            EM:RestoreAllPositions()
        end
    end
    
    return true
end

function ns.Handlers.InstallAll(profileData, callback)
    local profileName = "KullThranUI"
    local results = {}
    local steps = {
        { name = "DandersFrames",         fn = ns.Handlers.DandersFrames },
        { name = "Plater",                fn = ns.Handlers.Plater },
        { name = "UnhaltedUnitFrames",    fn = ns.Handlers.UnhaltedUnitFrames },
        { name = "BetterCooldownManager", fn = ns.Handlers.BetterCooldownManager },
        { name = "Layout",                fn = ns.Handlers.Layout }, -- [FIX] Añadido aquí
    }

    for _, step in ipairs(steps) do
        local data = profileData[step.name]
        if data then
            local ok, err = step.fn(profileName, data)
            results[step.name] = { success = ok, error = err }
        else
            results[step.name] = { success = true, skipped = true }
        end
    end
    if callback then callback(results) end
    return results
end
