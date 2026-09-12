-- Opt-in function/event profiler for combat CPU spikes.
local _, ns = ...
local KT = ns and ns.KT
if not KT then return end

local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetTimePreciseSec = _G.GetTimePreciseSec
local debugprofilestop = _G.debugprofilestop
local NowMS = GetTimePreciseSec and function() return GetTimePreciseSec() * 1000 end
    or function() return (debugprofilestop and debugprofilestop()) or 0 end

local function GetLuaMemoryKB()
    if type(_G.collectgarbage) ~= "function" then return nil end
    local ok, value = pcall(_G.collectgarbage, "count")
    return ok and type(value) == "number" and value or nil
end

local profiler = KT.CombatProfiler or {}
KT.CombatProfiler = profiler
local frame = CreateFrame("Frame")

local function Print(message)
    local plain = "[ktcombat] " .. tostring(message)
    if type(_G.KUI_CDM_DebugLog) == "table" then
        _G.KUI_CDM_DebugLog[#_G.KUI_CDM_DebugLog + 1] = plain
        if #_G.KUI_CDM_DebugLog > 1500 then table.remove(_G.KUI_CDM_DebugLog, 1) end
    end
    if KT.Print then KT:Print("|cff00ff88[ktcombat]|r " .. tostring(message))
    else print("|cff00ff88[ktcombat]|r " .. tostring(message)) end
end

local function ResolveKullThranAddons()
    local addons, seen = {}, {}
    local function AddCandidate(index, rawName, rawTitle)
        local name, title = rawName, rawTitle
        if type(rawName) == "table" then
            name = rawName.name or rawName.Name
            title = rawName.title or rawName.Title or rawName.label or rawName.notes
        end
        local haystack = string.lower(tostring(name or "") .. " " .. tostring(title or ""))
        if not haystack:find("kullthranui", 1, true) then
            return
        end
        local key = name or title or ("addon_" .. tostring(index))
        if seen[key] then return end
        seen[key] = true
        addons[#addons + 1] = { index = index, name = name, key = key }
    end

    if _G.GetNumAddOns and _G.GetAddOnInfo then
        local count = _G.GetNumAddOns() or 0
        for index = 1, count do
            local name, title = _G.GetAddOnInfo(index)
            AddCandidate(index, name, title)
        end
    end

    local cAddOns = _G.C_AddOns
    if cAddOns and cAddOns.GetNumAddOns and cAddOns.GetAddOnInfo then
        local count = cAddOns.GetNumAddOns() or 0
        for index = 1, count do
            local name, title = cAddOns.GetAddOnInfo(index)
            if type(name) == "table" then
                AddCandidate(index, name, title)
            else
                if (not title or title == "") and cAddOns.GetAddOnMetadata and name then
                    local ok, metadataTitle = pcall(cAddOns.GetAddOnMetadata, name, "Title")
                    if ok then title = metadataTitle end
                end
                AddCandidate(index, name, title)
            end
        end
    end

    return addons
end

local function SnapshotKullThranCPU(addons)
    if not _G.GetAddOnCPUUsage then return nil end
    if _G.UpdateAddOnCPUUsage then pcall(_G.UpdateAddOnCPUUsage) end

    addons = addons or ResolveKullThranAddons()
    local snapshot, found = {}, 0
    for i = 1, #addons do
        local addon = addons[i]
        local ok, cpu
        if addon.name then ok, cpu = pcall(_G.GetAddOnCPUUsage, addon.name) end
        if not ok or type(cpu) ~= "number" then
            ok, cpu = pcall(_G.GetAddOnCPUUsage, addon.index)
        end
        if ok and type(cpu) == "number" then
            snapshot[addon.key] = cpu
            found = found + 1
        end
    end
    return found > 0 and snapshot or nil
end

local function ResolveLoadedAddonNames()
    local names = {}
    local cAddOns = _G.C_AddOns
    if not (cAddOns and cAddOns.GetNumAddOns and cAddOns.GetAddOnInfo) then return names end
    for index = 1, (cAddOns.GetNumAddOns() or 0) do
        local info = cAddOns.GetAddOnInfo(index)
        local name = type(info) == "table" and (info.name or info.Name) or info
        if name and (not cAddOns.IsAddOnLoaded or cAddOns.IsAddOnLoaded(name)) then
            names[#names + 1] = name
        end
    end
    return names
end

function profiler:Reset()
    self.samples, self.events, self.spikes, self.spells, self.frameHitches = {}, {}, {}, {}, {}
    self.worstFrameHitches, self.frameHitchTotal = {}, 0
    self.frameSections, self.frameSerial = {}, 0
    self.captureStart, self.captureEnd, self.combatStart = nil, nil, nil
    self.addonCPUStart, self.addonCPUEnd = nil, nil
    self.addonHandles = nil
    self.memoryStartKB, self.memoryEndKB = nil, nil
    self.memoryWindowLastKB = nil
    self.memorySampleElapsedMs, self.memoryPositivePeakKB = 0, 0
    self.gcDropCount, self.gcFreedKB, self.gcLargestDropKB = 0, 0, 0
    self.modernAddonNames, self.modernSamplerMs = {}, 0
    self.ownsCDMPerf = false
    self.combatMs, self.eventCount, self.castCount, self.frameCount = 0, 0, 0, 0
    self.lastEvent, self.lastEventAt, self.lastSpellID = "idle", nil, nil
end

function profiler:CaptureModernAddonTick()
    local api, metric = _G.C_AddOnProfiler, self.modernLastTimeMetric
    if not (self.modernProfilerEnabled and api and api.GetAddOnMetric and metric) then return nil end
    local startedAt = NowMS()
    local rows = {}
    if api.GetTopKAddOnsForMetric then
        local top = api.GetTopKAddOnsForMetric(metric, 5)
        for index = 1, #(top or {}) do
            local entry = top[index]
            rows[index] = {
                name = entry.addOnName or entry.name or "?",
                ms = entry.metricValue or entry.value or 0,
            }
        end
    end
    self.modernSamplerMs = (self.modernSamplerMs or 0) + math.max(0, NowMS() - startedAt)
    return rows
end

function profiler:CaptureModernAddonSummary()
    local api = _G.C_AddOnProfiler
    local metrics = _G.Enum and _G.Enum.AddOnProfilerMetric
    if not (api and api.GetAddOnMetric and metrics) then return nil end
    local recentMetric = metrics.RecentAverageTime
    local sessionMetric = metrics.SessionAverageTime
    local peakMetric = metrics.PeakTime
    if recentMetric == nil then return nil end
    local rows = {}
    for _, name in ipairs(ResolveLoadedAddonNames()) do
        local recent = api.GetAddOnMetric(name, recentMetric) or 0
        local session = sessionMetric ~= nil and (api.GetAddOnMetric(name, sessionMetric) or 0) or 0
        local peak = peakMetric ~= nil and (api.GetAddOnMetric(name, peakMetric) or 0) or 0
        if recent > 0 or session > 0 or peak > 0 then
            rows[#rows + 1] = { name = name, recent = recent, session = session, peak = peak }
        end
    end
    table.sort(rows, function(a, b)
        if a.recent == b.recent then return a.session > b.session end
        return a.recent > b.recent
    end)
    return rows
end

function profiler:PrintModernAddonSummary(title)
    local rows = self:CaptureModernAddonSummary()
    if not rows or #rows == 0 then return end
    Print(title or "CPU moderno por addon: reciente / sesion / pico (ms por frame)")
    local kuiRecent, kuiSession, kuiCount = 0, 0, 0
    local euiRecent, euiSession, euiCount = 0, 0, 0
    for i = 1, math.min(15, #rows) do
        local row = rows[i]
        Print(string.format("%2d. %-42s %.4f / %.4f / %.2fms",
            i, row.name, row.recent, row.session, row.peak))
    end
    -- Igual que el medidor oficial de EllesmereUI: sumar todos los paquetes
    -- cargados de la suite. Comparar solo los addons raiz es enganoso porque
    -- KUI y EUI distribuyen funciones distintas entre sus carpetas.
    for i = 1, #rows do
        local row = rows[i]
        if type(row.name) == "string" and row.name:find("^KullThranUI") then
            kuiRecent = kuiRecent + row.recent
            kuiSession = kuiSession + row.session
            kuiCount = kuiCount + 1
        elseif type(row.name) == "string" and row.name:find("^EllesmereUI") then
            euiRecent = euiRecent + row.recent
            euiSession = euiSession + row.session
            euiCount = euiCount + 1
        end
    end
    local fps = (_G.GetFramerate and _G.GetFramerate()) or 0
    local frameBudget = fps > 0 and (1000 / fps) or nil
    local function PrintSuite(label, recent, session, count)
        if count <= 0 then return end
        local percent = frameBudget and (recent / frameBudget * 100) or 0
        Print(string.format("%s total (%d addons): %.4f reciente / %.4f sesion ms por frame (%.1f%% a %.0f FPS)",
            label, count, recent, session, percent, fps))
    end
    PrintSuite("KullThranUI", kuiRecent, kuiSession, kuiCount)
    PrintSuite("EllesmereUI", euiRecent, euiSession, euiCount)
end

function profiler:Begin(label)
    if not self.capturing then return nil end
    return NowMS()
end

function profiler:End(label, startedAt)
    if not (self.capturing and startedAt and label) then return end
    local elapsed = math.max(0, NowMS() - startedAt)
    local sample = self.samples[label]
    if not sample then
        sample = { calls = 0, total = 0, peak = 0, over1 = 0, over5 = 0, over10 = 0 }
        self.samples[label] = sample
    end
    sample.calls = sample.calls + 1
    sample.total = sample.total + elapsed
    sample.peak = math.max(sample.peak, elapsed)
    if elapsed >= 1 then sample.over1 = sample.over1 + 1 end
    if elapsed >= 5 then sample.over5 = sample.over5 + 1 end
    if elapsed >= 10 then sample.over10 = sample.over10 + 1 end
    local frameSample = self.frameSections[label]
    if not frameSample then
        frameSample = { serial = -1, calls = 0, total = 0, peak = 0 }
        self.frameSections[label] = frameSample
    end
    if frameSample.serial ~= self.frameSerial then
        frameSample.serial, frameSample.calls, frameSample.total, frameSample.peak =
            self.frameSerial, 0, 0, 0
    end
    frameSample.calls = frameSample.calls + 1
    frameSample.total = frameSample.total + elapsed
    frameSample.peak = math.max(frameSample.peak, elapsed)
    if elapsed >= (self.spikeThresholdMs or 1) then
        local now = NowMS()
        local eventAge = self.lastEventAt and (now - self.lastEventAt) or math.huge
        local correlatedEvent = eventAge <= 500 and self.lastEvent or "periodic/idle"
        local spikes = self.spikes
        spikes[#spikes + 1] = {
            at = (now - (self.captureStart or now)) / 1000,
            label = label, ms = elapsed, event = correlatedEvent,
            eventAge = eventAge, spellID = eventAge <= 500 and self.lastSpellID or nil,
        }
        if #spikes > 80 then table.remove(spikes, 1) end
    end
end

function profiler:Event(event, detail)
    if not self.capturing then return end
    self.eventCount = self.eventCount + 1
    self.events[event] = (self.events[event] or 0) + 1
    self.lastEvent = detail and (event .. ":" .. tostring(detail)) or event
    self.lastEventAt = NowMS()
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then self.lastSpellID = nil end
end

function profiler:Start(duration, stopOnCombatEnd, includeCDMPerf, includeAddonCPU)
    if self.capturing then Print("ya hay una captura activa"); return end
    self:Reset()
    _G.KUI_CDM_DebugLog = {}
    self.capturing = true
    frame:Show()
    self.captureToken = (self.captureToken or 0) + 1
    self.captureStart = NowMS()
    self.duration = math.max(5, math.min(tonumber(duration) or 30, 600))
    self.stopOnCombatEnd = stopOnCombatEnd == true
    self.includeCDMPerf = includeCDMPerf ~= false
    self.includeAddonCPU = includeAddonCPU ~= false
    self.spikeThresholdMs = self.spikeThresholdMs or 1
    self.frameHitchThresholdMs = self.frameHitchThresholdMs or 30
    if self.includeAddonCPU then
        self.addonHandles = ResolveKullThranAddons()
        local scriptProfile = _G.GetCVar and _G.GetCVar("scriptProfile")
        self.scriptProfileEnabled = scriptProfile == nil or tostring(scriptProfile) == "1"
        self.addonCPUStart = self.scriptProfileEnabled and SnapshotKullThranCPU(self.addonHandles) or nil
    end
    self.memoryStartKB = GetLuaMemoryKB()
    self.memoryWindowLastKB = self.memoryStartKB
    local modernAPI = _G.C_AddOnProfiler
    local metricEnum = _G.Enum and _G.Enum.AddOnProfilerMetric
    self.modernLastTimeMetric = metricEnum and metricEnum.LastTime
    self.modernProfilerEnabled = modernAPI and modernAPI.GetAddOnMetric and
        self.modernLastTimeMetric and
        (not modernAPI.IsEnabled or modernAPI.IsEnabled()) and true or false
    if self.modernProfilerEnabled then self.modernAddonNames = ResolveLoadedAddonNames() end

    for _, event in ipairs({
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_SPELLCAST_SUCCEEDED",
        "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
        "UNIT_AURA", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
        "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
        "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED",
        "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
        "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
        "DAMAGE_METER_RESET",
    }) do frame:RegisterEvent(event) end

    local token = self.captureToken
    C_Timer.After(self.duration, function()
        if self.capturing and self.captureToken == token then self:Stop("timer") end
    end)

    local cdmNS = _G.KUI_CDM_NS
    local cdmPerf = cdmNS and cdmNS._perf
    if self.includeCDMPerf and cdmPerf and not cdmPerf.capturing and cdmNS.CDMPerfStartCapture then
        local ok = pcall(cdmNS.CDMPerfStartCapture, cdmPerf, self.duration, "ktcombat", "ktcombat CDM capture")
        self.ownsCDMPerf = ok == true
    end

    if self.includeAddonCPU then
        Print(string.format("captura iniciada %.0fs; frame >=%.0fms; CPU total por addon; termina con /ktcombat stop",
            self.duration, self.frameHitchThresholdMs))
    else
        Print(string.format("captura ligera iniciada %.0fs; frame >=%.0fms; C_AddOnProfiler=%s; termina con /ktfreeze stop",
            self.duration, self.frameHitchThresholdMs, self.modernProfilerEnabled and "si" or "no"))
    end
    if _G.KT_NAMEPLATE_AURA_BACKEND then
        Print("backend auras nameplates: " .. tostring(_G.KT_NAMEPLATE_AURA_BACKEND))
    end
    if self.includeAddonCPU and not self.addonCPUStart then
        Print("AVISO: atribucion por addon no disponible; activa /console scriptProfile 1 y haz /reload")
    end
end

function profiler:Arm(duration, includeCDMPerf, includeAddonCPU)
    self.armed = true
    self.armedDuration = math.max(5, math.min(tonumber(duration) or 30, 600))
    self.armedIncludeCDMPerf = includeCDMPerf ~= false
    self.armedIncludeAddonCPU = includeAddonCPU ~= false
    -- Arm mode must listen for the next combat transition; Start() registers
    -- the heavier capture events only after PLAYER_REGEN_DISABLED fires.
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    Print(string.format("armado para el proximo combate: %.0fs", self.armedDuration))
end

function profiler:Stop(reason)
    if not self.capturing then
        if self.armed then
            self.armed = false
            self.armedDuration = nil
            frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
            Print("armado cancelado")
        else
            Print("no hay captura activa")
        end
        return
    end
    self.captureEnd = NowMS()
    if self.combatStart then
        self.combatMs = self.combatMs + math.max(0, self.captureEnd - self.combatStart)
        self.combatStart = nil
    end
    if self.includeAddonCPU and self.scriptProfileEnabled then
        self.addonCPUEnd = self.addonCPUEnd or SnapshotKullThranCPU(self.addonHandles)
    end
    self.memoryEndKB = GetLuaMemoryKB()
    if self.ownsCDMPerf then
        local cdmNS = _G.KUI_CDM_NS
        local cdmPerf = cdmNS and cdmNS._perf
        if cdmPerf and cdmPerf.capturing and cdmNS.CDMPerfFinalizeCapture then
            pcall(cdmNS.CDMPerfFinalizeCapture, "ktcombat", self.duration)
        end
        self.ownsCDMPerf = false
    end
    self.capturing, self.armed = false, false
    frame:Hide()
    frame:UnregisterAllEvents()
    self:Report(reason or "manual")
    local reportToken = self.captureToken
    C_Timer.After(5, function()
        if not profiler.capturing and profiler.captureToken == reportToken then
            profiler:PrintModernAddonSummary(
                "CPU limpio 5s despues: reciente / sesion / pico (ms por frame)")
        end
    end)
end

function profiler:Report(reason)
    local finish = self.captureEnd or NowMS()
    local elapsed = (finish - (self.captureStart or finish)) / 1000
    local rows = {}
    for label, sample in pairs(self.samples or {}) do rows[#rows + 1] = { label = label, sample = sample } end
    table.sort(rows, function(a, b) return a.sample.total > b.sample.total end)
    Print(string.format("resultado %s: %.1fs, combate %.1fs, frames %d, lentos %d, eventos %d, casts %d",
        tostring(reason or "report"), elapsed, (self.combatMs or 0) / 1000,
        self.frameCount or 0, self.frameHitchTotal or #(self.frameHitches or {}),
        self.eventCount or 0, self.castCount or 0))
    if self.memoryStartKB and self.memoryEndKB then
        Print(string.format("memoria Lua: %.1fMB -> %.1fMB (delta %+.1fMB)",
            self.memoryStartKB / 1024, self.memoryEndKB / 1024,
            (self.memoryEndKB - self.memoryStartKB) / 1024))
        Print(string.format("memoria ventanas 100ms: rafaga maxima +%.1fKB; caidas >=512KB x%d, liberado %.1fMB, maxima %.1fMB",
            self.memoryPositivePeakKB or 0, self.gcDropCount or 0,
            (self.gcFreedKB or 0) / 1024, (self.gcLargestDropKB or 0) / 1024))
    end
    Print("top por tiempo: total / media / pico / llamadas / >=1ms >=5ms >=10ms")
    for i = 1, math.min(20, #rows) do
        local row, s = rows[i], rows[i].sample
        Print(string.format("%2d. %-30s %.2f / %.4f / %.2fms / x%d / %d %d %d",
            i, row.label, s.total, s.calls > 0 and s.total / s.calls or 0,
            s.peak, s.calls, s.over1, s.over5, s.over10))
    end
    if self.addonCPUStart then
        local cpuRows = {}
        local cpuStart = self.addonCPUStart
        local cpuEnd = self.addonCPUEnd or SnapshotKullThranCPU() or {}
        for name, finishCPU in pairs(cpuEnd) do
            local startCPU = cpuStart[name] or finishCPU
            local delta = math.max(0, finishCPU - startCPU)
            cpuRows[#cpuRows + 1] = { name = name, delta = delta }
        end
        table.sort(cpuRows, function(a, b) return a.delta > b.delta end)
        if #cpuRows > 0 then
            Print("CPU real por addon (delta durante la captura):")
            for i = 1, math.min(12, #cpuRows) do
                local row = cpuRows[i]
                Print(string.format("%2d. %-42s %.2fms (%.2fms/s)", i, row.name, row.delta,
                    elapsed > 0 and row.delta / elapsed or 0))
            end
        else
            local scriptProfile = _G.GetCVar and _G.GetCVar("scriptProfile") or "?"
            local cpuAPI = _G.GetAddOnCPUUsage and "si" or "no"
            Print("CPU real por addon no disponible (API=" .. cpuAPI .. ", scriptProfile=" ..
                tostring(scriptProfile) .. "); activa /console scriptProfile 1 y haz /reload")
        end
    end
    local events = {}
    for event, count in pairs(self.events or {}) do events[#events + 1] = { event = event, count = count } end
    table.sort(events, function(a, b) return a.count > b.count end)
    if #events > 0 then
        local text = "eventos:"
        for i = 1, math.min(12, #events) do text = text .. " " .. events[i].event .. "=" .. events[i].count end
        Print(text)
    end
    if #self.spikes > 0 then
        Print("ultimos picos >= " .. string.format("%.1fms", self.spikeThresholdMs or 1) .. ":")
        for i = math.max(1, #self.spikes - 9), #self.spikes do
            local spike = self.spikes[i]
            Print(string.format(" +%.3fs %-28s %.2fms %s%s", spike.at, spike.label, spike.ms,
                tostring(spike.event or "?"), spike.spellID and (" spell=" .. tostring(spike.spellID)) or ""))
        end
    end
    if self.worstFrameHitches and #self.worstFrameHitches > 0 then
        Print("peores frames >= " .. string.format("%.0fms", self.frameHitchThresholdMs or 30) ..
            ": tiempo / duracion / evento / addons LastTime / secciones KUI / memoria")
        Print(string.format("coste atribucion C_AddOnProfiler: %.2fms total", self.modernSamplerMs or 0))
        for i = 1, #self.worstFrameHitches do
            local hitch = self.worstFrameHitches[i]
            local addonText = " addons=n/d"
            if hitch.addons and #hitch.addons > 0 then
                local parts = {}
                for addonIndex = 1, math.min(3, #hitch.addons) do
                    local addon = hitch.addons[addonIndex]
                    parts[#parts + 1] = string.format("%s %.2fms", addon.name, addon.ms)
                end
                addonText = " addons=" .. table.concat(parts, "; ")
            end
            local sectionText = " secciones=ninguna"
            if hitch.sections and #hitch.sections > 0 then
                local parts = {}
                for sectionIndex = 1, math.min(3, #hitch.sections) do
                    local section = hitch.sections[sectionIndex]
                    parts[#parts + 1] = string.format("%s %.2fms/x%d",
                        section.label, section.total, section.calls)
                end
                sectionText = " secciones=" .. table.concat(parts, "; ")
            end
            local memoryText = ""
            if hitch.memoryKB then
                memoryText = string.format(" mem=%.1fMB", hitch.memoryKB / 1024)
                if hitch.memoryDeltaKB then
                    memoryText = memoryText .. string.format(" (%+.1fKB)", hitch.memoryDeltaKB)
                    if hitch.memoryDeltaKB <= -512 then memoryText = memoryText .. " GC?" end
                end
            end
            Print(string.format(" +%.3fs %.1fms %s%s%s%s", hitch.at, hitch.ms,
                tostring(hitch.event or "periodic/idle"), addonText, sectionText, memoryText))
        end
    else
        Print("frames lentos: ninguno por encima del umbral")
    end
    local cdmNS, cdmPerf = _G.KUI_CDM_NS, nil
    cdmPerf = cdmNS and cdmNS._perf
    if self.includeCDMPerf and cdmPerf and cdmPerf.tickCount and cdmPerf.tickCount > 0 then
        Print(string.format("CDM interno: ticks=%d omitidos=%d total=%.2fms pico=%.2fms",
            cdmPerf.tickCount, cdmPerf.skippedTicks or 0, cdmPerf.totalMs or 0, cdmPerf.peakMs or 0))

        local phaseRows = {}
        for phase, total in pairs(cdmPerf.phases or {}) do
            phaseRows[#phaseRows + 1] = {
                name = phase,
                total = total or 0,
                peak = (cdmPerf.phasePeaks and cdmPerf.phasePeaks[phase]) or 0,
            }
        end
        table.sort(phaseRows, function(a, b) return a.total > b.total end)
        if #phaseRows > 0 then
            Print("CDM fases internas: total / pico")
            for i = 1, math.min(10, #phaseRows) do
                local row = phaseRows[i]
                Print(string.format("%2d. %-28s %.2fms / %.2fms", i, row.name, row.total, row.peak))
            end
        end

        local barRows = {}
        for barKey, data in pairs(cdmPerf.bars or {}) do
            barRows[#barRows + 1] = {
                name = barKey,
                total = data.totalMs or 0,
                peak = data.peakMs or 0,
                ticks = data.ticks or 0,
                visible = data.visibleIcons or 0,
                icons = data.totalIcons or 0,
            }
        end
        table.sort(barRows, function(a, b) return a.total > b.total end)
        if #barRows > 0 then
            Print("CDM barras: total / pico / llamadas / iconos")
            for i = 1, math.min(12, #barRows) do
                local row = barRows[i]
                Print(string.format("%2d. %-20s %.2fms / %.2fms / x%d / %d:%d",
                    i, row.name, row.total, row.peak, row.ticks, row.visible, row.icons))
            end
        end

        local dirtyRows = {}
        for reasonName, count in pairs(cdmPerf.dirtyReasons or {}) do
            dirtyRows[#dirtyRows + 1] = { name = reasonName, count = count or 0 }
        end
        table.sort(dirtyRows, function(a, b) return a.count > b.count end)
        if #dirtyRows > 0 then
            local dirtyText = "CDM motivos dirty:"
            for i = 1, math.min(10, #dirtyRows) do
                dirtyText = dirtyText .. " " .. dirtyRows[i].name .. "=" .. dirtyRows[i].count
            end
            Print(dirtyText)
        end
    end
    if cdmNS and cdmNS.CDMOpenDebugWindow then
        cdmNS.CDMOpenDebugWindow()
    end
end

if not profiler.samples then profiler:Reset() end
frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "PLAYER_REGEN_DISABLED" then
        if profiler.armed and not profiler.capturing then
            local duration = profiler.armedDuration
            profiler.armed = false
            profiler:Start(duration, true, profiler.armedIncludeCDMPerf, profiler.armedIncludeAddonCPU)
        end
        if profiler.capturing and not profiler.combatStart then profiler.combatStart = NowMS() end
        profiler:Event(event)
        return
    end
    if not profiler.capturing then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if profiler.combatStart then
            profiler.combatMs = profiler.combatMs + math.max(0, NowMS() - profiler.combatStart)
            profiler.combatStart = nil
        end
        profiler:Event(event)
        if profiler.stopOnCombatEnd then profiler:Stop("combat end") end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        profiler.castCount = profiler.castCount + 1
        profiler.lastSpellID = spellID
        if spellID then profiler.spells[spellID] = (profiler.spells[spellID] or 0) + 1 end
        profiler:Event(event, spellID)
    elseif event == "UNIT_AURA" then
        profiler:Event(event, unit)
    else
        profiler:Event(event)
    end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
    if not profiler.capturing then return end
    local selfStarted = NowMS()
    profiler.frameCount = (profiler.frameCount or 0) + 1
    local elapsedMs = (elapsed or 0) * 1000
    local isHitch = elapsedMs >= (profiler.frameHitchThresholdMs or 30)
    profiler.memorySampleElapsedMs = (profiler.memorySampleElapsedMs or 0) + elapsedMs
    local memoryKB, memoryDeltaKB
    if isHitch or profiler.memorySampleElapsedMs >= 100 then
        memoryKB = GetLuaMemoryKB()
        memoryDeltaKB = memoryKB and profiler.memoryWindowLastKB and
            (memoryKB - profiler.memoryWindowLastKB) or nil
        profiler.memoryWindowLastKB = memoryKB or profiler.memoryWindowLastKB
        profiler.memorySampleElapsedMs = 0
        if memoryDeltaKB then
            if memoryDeltaKB > (profiler.memoryPositivePeakKB or 0) then
                profiler.memoryPositivePeakKB = memoryDeltaKB
            elseif memoryDeltaKB <= -512 then
                local freedKB = -memoryDeltaKB
                profiler.gcDropCount = (profiler.gcDropCount or 0) + 1
                profiler.gcFreedKB = (profiler.gcFreedKB or 0) + freedKB
                profiler.gcLargestDropKB = math.max(profiler.gcLargestDropKB or 0, freedKB)
            end
        end
    end
    local sectionRows
    if isHitch then
        sectionRows = {}
        for label, section in pairs(profiler.frameSections or {}) do
            if section.serial == profiler.frameSerial and section.total > 0 then
                sectionRows[#sectionRows + 1] = {
                    label = label, total = section.total,
                    peak = section.peak, calls = section.calls,
                }
            end
        end
        table.sort(sectionRows, function(a, b) return a.total > b.total end)
        while #sectionRows > 4 do sectionRows[#sectionRows] = nil end
    end
    profiler.frameSerial = (profiler.frameSerial or 0) + 1
    if not isHitch then return end

    local now = NowMS()
    local eventAge = profiler.lastEventAt and (now - profiler.lastEventAt) or math.huge
    local hitches = profiler.frameHitches
    local hitch = {
        at = (now - (profiler.captureStart or now)) / 1000,
        ms = elapsedMs,
        event = eventAge <= 500 and profiler.lastEvent or "periodic/idle",
        sections = sectionRows,
        -- Never query C_AddOnProfiler inside a hitch. Both the per-addon loop
        -- and GetTopKAddOnsForMetric allocate heavily enough to amplify an
        -- existing stutter into a GC feedback loop. The clean summary is read
        -- once, five seconds after the capture stops.
        addons = nil,
        memoryKB = memoryKB, memoryDeltaKB = memoryDeltaKB,
    }
    profiler.frameHitchTotal = (profiler.frameHitchTotal or 0) + 1
    hitches[#hitches + 1] = hitch
    if #hitches > 20 then table.remove(hitches, 1) end
    local worst = profiler.worstFrameHitches
    worst[#worst + 1] = hitch
    table.sort(worst, function(a, b) return a.ms > b.ms end)
    if #worst > 10 then worst[#worst] = nil end
    profiler:End("profiler.self.hitchFrame", selfStarted)
end)
frame:Hide()

local function HandleCommand(message)
    local command, rest = tostring(message or ""):lower():match("^(%S+)%s*(.-)$")
    command, rest = command or "status", rest or ""
    if command == "arm" or command == "auto" then profiler:Arm(tonumber(rest) or 30)
    elseif command == "start" or command == "on" then profiler:Start(tonumber(rest) or 30, false)
    elseif command == "stop" or command == "off" then profiler:Stop("manual")
    elseif command == "report" or command == "dump" then profiler:Report("manual report")
    elseif command == "reset" then
        profiler:Reset(); profiler.capturing, profiler.armed = false, false
        frame:UnregisterAllEvents()
        Print("contadores reiniciados")
    elseif command == "threshold" then
        profiler.spikeThresholdMs = math.max(0.1, tonumber(rest) or 1)
        Print(string.format("umbral de picos %.1fms", profiler.spikeThresholdMs))
    elseif command == "hitch" then
        profiler.frameHitchThresholdMs = math.max(10, tonumber(rest) or 30)
        Print(string.format("umbral de frame lento %.0fms", profiler.frameHitchThresholdMs))
    elseif command == "status" then
        Print(string.format("capturando=%s armado=%s ultimo=%s casts=%d",
            profiler.capturing and "si" or "no", profiler.armed and "si" or "no",
            tostring(profiler.lastEvent or "none"), profiler.castCount or 0))
    else Print("uso: /ktcombat arm [s] | start [s] | stop | report | reset | threshold [ms] | hitch [ms]") end
end

SLASH_KTCOMBAT1 = "/ktcombat"
SLASH_KTCOMBAT2 = "/kuicombat"
SlashCmdList.KTCOMBAT = HandleCommand

local function HandleFreezeCommand(message)
    local text = tostring(message or ""):lower():match("^%s*(.-)%s*$") or ""
    profiler.frameHitchThresholdMs = 20
    if text == "" then
        profiler:Start(60, false, false, false)
    elseif tonumber(text) then
        profiler:Start(tonumber(text), false, false, false)
    else
        local command, rest = text:match("^(%S+)%s*(.-)$")
        if command == "arm" or command == "auto" then
            profiler:Arm(tonumber(rest) or 120, false, false)
        elseif command == "start" or command == "on" then
            profiler:Start(tonumber(rest) or 60, false, false, false)
        else
            HandleCommand(text)
        end
    end
end

SLASH_KTFREEZE1 = "/ktfreeze"
SlashCmdList.KTFREEZE = HandleFreezeCommand
