-- ===================================================================
--  KullThranUI - Party Frames Arena Trinket Handler
-- ===================================================================
do
    local function GetTrinketInfo()
        -- Placeholder: IDs de abalorios JcJ comunes. Deberían obtenerse de una fuente de datos del addon.
        local trinketSpellIDs = {
            [65546] = true, -- Medallón de Gladiador
            [208683] = true, -- Adaptación
        }
        return trinketSpellIDs
    end

    local function UpdateArenaTrinket(frame)
        -- Esta función se debe llamar desde el refresco de auras del marco de arena
        -- para mostrar el estado del abalorio del aliado.
        -- La lógica de posicionamiento (izquierda para DPS, abajo para Healer)
        -- se aplicaría aquí, comprobando el perfil de layout activo.
    end

    -- Inyección en el addon principal (ejemplo conceptual)
    -- El addon principal debería tener un punto de entrada para registrar módulos como este.
    -- Por ejemplo: KullThranUI_PartyFrames:RegisterModule("ArenaTrinket", {
    --   OnUpdate = UpdateArenaTrinket,
    --   OnEnable = function() print("Módulo de abalorio de arena activado.") end,
    -- })
end

-------------------------------------------------------------------------------
--  KUI_PF_Debug.lua
--  Debug & Performance Monitor para KullThranUI_PartyFrames
--  Uso: /kuipf debug      → muestra panel de métricas
--       /kuipf stress     → test de estrés (simula eventos de grupo)
--       /kuipf events     → muestra eventos registrados actualmente
--       /kuipf hooks      → muestra hooks instalados
--       /kuipf reset      → resetea contadores
--       /kuipf conflicts  → busca conflictos con otros addons
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- Solo activo si se carga este archivo
if not ns then ns = {} end

local _debug = {}
local _eventCounts  = {}   -- evento → nº de veces disparado
local _eventTimes   = {}   -- evento → tiempo total (ms) gastado en handler
local _updateCount  = 0
local _updateTime   = 0
local _lastReset    = GetTime()
local _hookList     = {}

-- ─── Monkey-patch del frame principal ────────────────────────────────────────
local function WrapPartyFramesHandlers()
    -- Busca el eventFrame del módulo
    local pf_ns = ns
    if not pf_ns then return end

    -- Detectar el frame de eventos del addon (suele llamarse eventFrame o similar)
    local candidates = {}
    for k, v in pairs(pf_ns) do
        if type(v) == "table" and type(v.GetScript) == "function" then
            local onEvent = v:GetScript("OnEvent")
            if onEvent then
                candidates[#candidates+1] = { key = k, frame = v }
            end
        end
    end

    for _, c in ipairs(candidates) do
        local origOnEvent = c.frame:GetScript("OnEvent")
        if origOnEvent then
            c.frame:SetScript("OnEvent", function(self, event, ...)
                local t0 = debugprofilestart and debugprofilestart() or 0
                origOnEvent(self, event, ...)
                local dt = debugprofilestop and debugprofilestop() or 0
                _eventCounts[event] = (_eventCounts[event] or 0) + 1
                _eventTimes[event]  = (_eventTimes[event]  or 0) + (dt - t0)
            end)
            -- print("|cff00ff00[KUI PF Debug]|r Wrapping OnEvent en frame: " .. c.key)
        end
    end
end

-- ─── Panel de métricas ───────────────────────────────────────────────────────
local debugFrame
local function CreateDebugPanel()
    if debugFrame then debugFrame:Show(); return end

    debugFrame = CreateFrame("Frame", "KUIPFDebugFrame", UIParent, "BackdropTemplate")
    debugFrame:SetSize(520, 460)
    debugFrame:SetPoint("CENTER", 0, 100)
    debugFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left=8, right=8, top=8, bottom=8 }
    })
    debugFrame:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    debugFrame:SetMovable(true)
    debugFrame:EnableMouse(true)
    debugFrame:RegisterForDrag("LeftButton")
    debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
    debugFrame:SetScript("OnDragStop",  debugFrame.StopMovingOrSizing)
    debugFrame:SetFrameStrata("DIALOG")

    -- Título
    local title = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("|cff00ccff[KUI PartyFrames Debug]|r")

    -- Texto principal
    local txt = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("TOPLEFT", 18, -48)
    txt:SetPoint("BOTTOMRIGHT", -18, 40)
    txt:SetJustifyH("LEFT")
    txt:SetJustifyV("TOP")
    debugFrame._txt = txt

    -- Botón cerrar
    local closeBtn = CreateFrame("Button", nil, debugFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    -- Botón reset
    local resetBtn = CreateFrame("Button", nil, debugFrame, "GameMenuButtonTemplate")
    resetBtn:SetSize(100, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 18, 12)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        wipe(_eventCounts); wipe(_eventTimes)
        _updateCount = 0; _updateTime = 0
        _lastReset = GetTime()
        print("|cff00ff00[KUI PF Debug]|r Contadores reseteados.")
    end)

    -- Botón stress
    local stressBtn = CreateFrame("Button", nil, debugFrame, "GameMenuButtonTemplate")
    stressBtn:SetSize(120, 22)
    stressBtn:SetPoint("BOTTOMLEFT", 130, 12)
    stressBtn:SetText("Stress Test")
    stressBtn:SetScript("OnClick", function()
        print("|cffffff00[KUI PF Debug]|r Iniciando stress test (50 ciclos)...")
        local start = debugprofilestart and debugprofilestart() or 0
        -- Simula 50 actualizaciones del frame
        local pf_ns2 = ns
        local refreshFn = pf_ns2 and (pf_ns2.RefreshAll or pf_ns2.ApplyLayout or pf_ns2.UpdateAll)
        if refreshFn then
            for i = 1, 50 do refreshFn() end
            local elapsed = debugprofilestop and (debugprofilestop() - start) or 0
            print(string.format("|cff00ff00[KUI PF Debug]|r 50 RefreshAll completados en %.2f ms (%.3f ms/call)", elapsed, elapsed/50))
        else
            -- Dispara eventos de grupo simulados
            local pf_frame = _G["KUIPartyFramesEventFrame"] or _G["KUI_PartyEventFrame"]
            if pf_frame then
                for i = 1, 20 do
                    local ok, err = pcall(pf_frame.GetScript(pf_frame, "OnEvent"), pf_frame, "GROUP_ROSTER_UPDATE")
                    if not ok then print("|cffff0000[KUI PF Debug]|r Error en stress: " .. tostring(err)); break end
                end
                local elapsed2 = debugprofilestop and (debugprofilestop() - start) or 0
                print(string.format("|cff00ff00[KUI PF Debug]|r 20x GROUP_ROSTER_UPDATE en %.2f ms", elapsed2))
            else
                print("|cffff8800[KUI PF Debug]|r No se encontró el eventFrame. Usa /kuipf events para inspeccionar.")
            end
        end
    end)

    -- Botón conflictos
    local confBtn = CreateFrame("Button", nil, debugFrame, "GameMenuButtonTemplate")
    confBtn:SetSize(120, 22)
    confBtn:SetPoint("BOTTOMRIGHT", -18, 12)
    confBtn:SetText("Conflictos")
    confBtn:SetScript("OnClick", function()
        KUI_PF_CheckConflicts()
    end)

    local gradBtn = CreateFrame("Button", nil, debugFrame, "GameMenuButtonTemplate")
    gradBtn:SetSize(120, 22)
    gradBtn:SetPoint("BOTTOM", 0, 12)
    gradBtn:SetText("Test Gradients")
    gradBtn:SetScript("OnClick", function()
        KUI_PF_TestGradients()
    end)


    -- Ticker de actualización del panel
    debugFrame._ticker = C_Timer.NewTicker(0.5, function()
        if not debugFrame:IsShown() then return end
        KUI_PF_RefreshPanel()
    end)
end


function KUI_PF_TestGradients()
    local pf_ns = nil
    if LibStub then
        local AceAddon = LibStub("AceAddon-3.0", true)
        local KT = AceAddon and AceAddon:GetAddon("KullThranUI", true)
        if KT then
            pf_ns = KT:GetModule("PartyFrames", true)
        end
    end

    if not pf_ns or not pf_ns.frames then
        print("|cffff0000[KUI PF Debug]|r No se pudo acceder a los frames.")
        return
    end

    local testFrame = nil
    for _, mode in pairs(pf_ns.frames) do
        for _, f in ipairs(mode) do
            if f:IsShown() then
                testFrame = f
                break
            end
        end
        if testFrame then break end
    end

    if not testFrame then
        print("|cffff0000[KUI PF Debug]|r No hay marcos de grupo visibles para probar. Entra en un grupo.")
        return
    end

    print("|cff00ccff[KUI PF Debug]|r Inyectando estado de Dispel (Poison) usando lógica nativa...")
    
    local unit = testFrame.unit
    if type(unit) ~= "string" or testFrame.fakeUnit then
        print("|cffff9900[KUI PF Debug]|r El test de gradiente requiere un frame vivo con unidad real.|r")
        return
    end
    
    -- Inyectar estado falso en la caché
    local oldCache = pf_ns.auraCache and pf_ns.auraCache[unit]
    if pf_ns.auraCache then
        pf_ns.auraCache[unit] = {
            buffs = {},
            debuffs = {},
            dispelType = "Poison",
            dispelAuraInstanceID = nil
        }
    end
    
    -- Forzar actualización nativa
    pf_ns:UpdateFrameAuras(testFrame)

    C_Timer.After(5, function()
        if pf_ns.auraCache then
            pf_ns.auraCache[unit] = oldCache
            if testFrame.unit == unit and testFrame:IsShown() then
                pf_ns:UpdateFrameAuras(testFrame)
            end
        end
        print("|cff00ccff[KUI PF Debug]|r Test de gradiente finalizado.")
    end)
end

function KUI_PF_RefreshPanel()
    if not debugFrame or not debugFrame._txt then return end

    local elapsed = GetTime() - _lastReset
    local lines = {}
    lines[#lines+1] = string.format("|cffaaaaaa Tiempo monitorizando: |r%.1f s", elapsed)
    lines[#lines+1] = ""

    -- Eventos más frecuentes
    lines[#lines+1] = "|cff00ccff── Eventos (Top 15 por frecuencia) ──|r"
    local sorted = {}
    for ev, count in pairs(_eventCounts) do
        sorted[#sorted+1] = { ev = ev, count = count, ms = _eventTimes[ev] or 0 }
    end
    table.sort(sorted, function(a,b) return a.count > b.count end)

    for i = 1, math.min(15, #sorted) do
        local e = sorted[i]
        local avg = e.count > 0 and (e.ms / e.count) or 0
        local color = avg > 0.5 and "|cffff4444" or avg > 0.1 and "|cffffff44" or "|cff88ff88"
        lines[#lines+1] = string.format("  %s%-35s|r %4dx  %s%.3f ms/call|r",
            "|cffffcc00", e.ev, e.count, color, avg)
    end

    lines[#lines+1] = ""
    lines[#lines+1] = string.format("|cff00ccff── OnUpdate ──|r  %d calls  |cff88ff88%.3f ms/call|r",
        _updateCount, _updateCount > 0 and _updateTime/_updateCount or 0)

    -- Addons cargados que pueden conflictuar
    lines[#lines+1] = ""
    lines[#lines+1] = "|cff00ccff── Addons de Party Frames detectados ──|r"
    local riskAddons = {
        "ElvUI", "Cell", "Grid2", "VuhDo", "Healbot",
        "sArena", "Gladius", "oUF", "ShadowUF", "PitBull4",
        "LimeWire", "KGPanels", "SUF"
    }
    for _, a in ipairs(riskAddons) do
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded(a)
        if loaded then
            lines[#lines+1] = "  |cffff6644⚠ " .. a .. "|r  (activo — posible conflicto de frames)"
        end
    end

    debugFrame._txt:SetText(table.concat(lines, "\n"))
end

function KUI_PF_CheckConflicts()
    local pf_ns2 = ns
    print("|cff00ccff[KUI PF Debug] ── Análisis de conflictos ──|r")

    -- 1. Hooks en CompactRaidFrameManager
    local hookTargets = {
        "CompactRaidFrameManager_UpdateShown",
        "CompactRaidFrameManager_SetSetting",
        "CompactUnitFrame_UpdateAll",
        "CompactUnitFrame_UpdateHealthColor",
        "CompactUnitFrame_UpdateAuras",
    }
    for _, fn in ipairs(hookTargets) do
        if rawget(_G, fn) then
            -- No podemos saber directamente quién la hookea, pero sí si existe
            print(string.format("  |cffaaaaaa%s|r — existe en _G (puede haber hooks)", fn))
        end
    end

    -- 2. CompactRaidFrameContainer visibility
    local crf = _G["CompactRaidFrameContainer"]
    if crf then
        local vis = crf:IsShown() and "|cff00ff00visible|r" or "|cffff4444oculto|r"
        print("  CompactRaidFrameContainer: " .. vis)
        print("  Alpha: " .. tostring(crf:GetAlpha()))
    end

    -- 3. Blizzard party frames
    local bf = _G["PartyFrame"]
    if bf then
        local vis2 = bf:IsShown() and "|cff00ff00visible|r" or "|cffff4444oculto|r"
        print("  PartyFrame (Blizzard): " .. vis2)
    end

    -- 4. Otros addons con party frames
    local conflicts = {}
    local addonsToCheck = { "ElvUI", "Cell", "VuhDo", "Grid2", "sArena" }
    for _, a in ipairs(addonsToCheck) do
        if C_AddOns and C_AddOns.IsAddOnLoaded(a) then
            conflicts[#conflicts+1] = a
        end
    end
    if #conflicts > 0 then
        print("  |cffff8800⚠ Addons conflictivos cargados: |r" .. table.concat(conflicts, ", "))
        print("  |cffaaaaaa  → Asegúrate de que KUI deshabilita los frames de Blizzard")
        print("  |cffaaaaaa  → y de que los otros addons no re-habilitan CompactRaidFrames|r")
    else
        print("  |cff00ff00✓ Sin addons conflictivos detectados.|r")
    end

    
    -- 5. Eventos de partido actualmente registrados (escaneo de frames globales)
    print("")
    print("|cff00ccff[KUI PF Debug]|r Eventos registrados (Omitido por Taint)")
    print("  (Escaneo omitido para evitar errores de Taint de Blizzard)")
end


-- ─── Dump de Leader Icon ────────────────────────────────────────────────────
local function PF_IsSecret(value)
    if C_UI and C_UI.IsSecret then
        local ok, secret = pcall(C_UI.IsSecret, value)
        if ok and secret == true then return true end
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret == true then return true end
    end
    return false
end

local function PF_FormatValue(ok, val)
    if not ok then return "ERR" end
    if PF_IsSecret(val) then return "(SECRET)" end
    return tostring(val)
end

function KUI_PF_LeaderDump()
    print("|cff00ccff[KUI PF Debug] ── Dump de Leader Icon ──|r")
    print(string.format("  type(_G.issecretvalue) = %s", type(_G.issecretvalue)))
    print(string.format("  type(_G.IsSecretValue) = %s", type(_G.IsSecretValue)))
    print(string.format("  C_UI.IsSecret          = %s", (C_UI and C_UI.IsSecret and "function" or "nil")))

    local KT = LibStub and LibStub("AceAddon-3.0", true) and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
    local mod = KT and KT:GetModule("PartyFrames", true)
    if not mod or not mod.frames then
        print("|cffff0000[KUI PF Debug]|r No se pudo acceder al módulo PartyFrames.")
        return
    end

    local okGC, groupCount = false, nil
    if GetNumGroupMembers then okGC, groupCount = pcall(GetNumGroupMembers) end
    local okIR, inRaid = false, nil
    if IsInRaid then okIR, inRaid = pcall(IsInRaid) end
    print(string.format("  GetNumGroupMembers = %s  IsInRaid = %s",
        tostring(okGC and groupCount or "ERR"),
        tostring(okIR and inRaid or "ERR")))
    local anyShown = false
    for mode, frames in pairs(mod.frames) do
        local db = mod and mod.GetModeDB and mod:GetModeDB(mode)
        print(string.format("  Modo %-10s showLeaderIcon = %s", tostring(mode), tostring(db and db.showLeaderIcon)))
        for _, f in ipairs(frames) do
            if f:IsShown() and f.unit then
                anyShown = true
                local unit = f.unit
                local okL, valL = false, nil
                if UnitIsGroupLeader then okL, valL = pcall(UnitIsGroupLeader, unit) end
                local okA, valA = false, nil
                if UnitIsGroupAssistant then okA, valA = pcall(UnitIsGroupAssistant, unit) end
                local okE, exists = false, nil
                if UnitExists then okE, exists = pcall(UnitExists, unit) end
                local okIP, inParty = false, nil
                if UnitInParty then okIP, inParty = pcall(UnitInParty, unit) end
                local okIR2, inRaid2 = false, nil
                if UnitInRaid then okIR2, inRaid2 = pcall(UnitInRaid, unit) end
                local icon = f.leaderIcon
                local texOK, texPath = false, nil
                if icon and icon.texture then texOK, texPath = pcall(icon.texture.GetTexture, icon.texture) end
                local pt, relTo, rpt, xOfs, yOfs = icon and icon:GetPoint(1) or ""
                print(string.format("    %-14s %s LDR:%s AST:%s exists:%s party:%s raid:%s icon:%s vis:%s overlay:%s last=%s pending=%s tex=%s pt=%s%s%s",
                    unit,
                    (f.fakeUnit and "FAKE" or "REAL"),
                    PF_FormatValue(okL, valL),
                    PF_FormatValue(okA, valA),
                    PF_FormatValue(okE, exists),
                    PF_FormatValue(okIP, inParty),
                    PF_FormatValue(okIR2, inRaid2),
                    (icon and (icon:IsShown() and "|cff00ff00SHOW|r" or "|cffff4444HIDE|r")) or "NIL",
                    (icon and (icon:IsVisible() and "|cff00ff00VIS|r" or "|cffff4444INVIS|r")) or "NIL",
                    (f.overlayFrame and (f.overlayFrame:IsShown() and "|cff00ff00show|r" or "|cffff4444hide|r")) or "-",
                    tostring(f._lastLeaderState),
                    tostring(f._leaderReadPending),
                    tostring(texOK and texPath or "nil"),
                    tostring(pt),
                    xOfs and string.format(" (%.0f,%.0f)", xOfs, yOfs) or "",
                    relTo and (" parent=" .. tostring(relTo)) or ""))
            end
        end
    end
    if not anyShown then
        print("  |cffaaaaaa(Ningún frame visible con unidad asignada — entra en un grupo)|r")
    end
    print("|cff00ff00[KUI PF Debug]|r Dump finalizado. Copia esta salida en el reporte.")
end


-- ─── Comando slash ──────────────────────────────────────────────────────────
SLASH_KUIPF1 = "/kuipf"
SlashCmdList["KUIPF"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "debug" or msg == "" then
        CreateDebugPanel()
        debugFrame:Show()
        KUI_PF_RefreshPanel()
    elseif msg == "leader" then
        KUI_PF_LeaderDump()
    elseif msg == "reset" then
        wipe(_eventCounts); wipe(_eventTimes)
        _updateCount = 0; _updateTime = 0
        _lastReset = GetTime()
        print("|cff00ff00[KUI PF Debug]|r Contadores reseteados.")
    elseif msg == "events" then
        print("|cff00ccff[KUI PF Debug] Eventos registrados en _eventCounts:|r")
        local count = 0
        for ev, n in pairs(_eventCounts) do
            print(string.format("  %-40s %d veces  %.3f ms total", ev, n, _eventTimes[ev] or 0))
            count = count + 1
        end
        if count == 0 then print("  (ningún evento capturado aún — prueba /kuipf debug primero)") end
    elseif msg == "gradients" then
        KUI_PF_TestGradients()
    elseif msg == "conflicts" then
        KUI_PF_CheckConflicts()
    elseif msg == "stress" then
        print("|cffffff00[KUI PF Debug]|r Usa el botón Stress Test del panel (/kuipf debug)")
    else
        print("|cff00ccff[KUI PF Debug] Comandos:|r /kuipf debug | leader | reset | events | conflicts | stress")
    end
end

-- ─── Auto-hook al cargar ─────────────────────────────────────────────────────
-- Runtime event-handler wrapping is intentionally disabled. Profilers can taint
-- PvP event execution, and wrapping the live handler makes that taint persist.
