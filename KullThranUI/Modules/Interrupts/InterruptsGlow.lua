local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local IG = KT:NewModule("InterruptsGlow", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")

-- Cache de globales
local _G = _G
local InCombatLockdown = _G.InCombatLockdown
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitIsUnit = _G.UnitIsUnit
local UnitCanAttack = _G.UnitCanAttack
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local GetActionInfo = _G.GetActionInfo
local GetMacroInfo = _G.GetMacroInfo
local GetMacroSpell = _G.GetMacroSpell
local GetActionCooldown = _G.GetActionCooldown
local EnumerateFrames = _G.EnumerateFrames
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local C_Spell = _G.C_Spell
local C_NamePlate = _G.C_NamePlate
local GetTime = _G.GetTime
local GetServerTime = _G.GetServerTime
local pairs, type, tostring, tonumber = pairs, type, tostring, tonumber

-- ============================================================================
-- Helpers y Constantes
-- ============================================================================

local function IsSecret(v)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(v) or false
end

local function WipeTable(t)
    if type(t) ~= "table" then return end
    for k in pairs(t) do t[k] = nil end
end

local function WipeArray(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function WipeMap(t)
    for k in pairs(t) do t[k] = nil end
end

local function SafeBool(v)
    if IsSecret(v) then return nil end
    if v == true then return true end
    if v == false then return false end
    return nil
end

local function UnitExistsSafe(unit)
    if not UnitExists then return false end
    local v = UnitExists(unit)
    v = SafeBool(v)
    return v == true
end

local function UnitIsUnitSafe(a, b)
    if not UnitIsUnit then return false end
    local v = UnitIsUnit(a, b)
    v = SafeBool(v)
    return v == true
end

local function UnitCanAttackSafe(a, b)
    if not UnitCanAttack then return false end
    local v = UnitCanAttack(a, b)
    v = SafeBool(v)
    return v == true
end

local function UnitIsDeadOrGhostSafe(unit)
    if not UnitIsDeadOrGhost then return false end
    local v = UnitIsDeadOrGhost(unit)
    v = SafeBool(v)
    return v == true
end

local function SpellName(spellID)
    if _G.GetSpellInfo then return _G.GetSpellInfo(spellID) end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name or nil
    end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return nil
end

local function SpellKnown(spellID)
    if not spellID then return false end
    if _G.IsPlayerSpell and _G.IsPlayerSpell(spellID) then return true end
    if _G.IsSpellKnown and _G.IsSpellKnown(spellID) then return true end
    if C_Spell and C_Spell.IsSpellKnown and C_Spell.IsSpellKnown(spellID) then return true end
    return false
end

local function SpellTexture(spellID)
    if not spellID then return nil end
    if _G.GetSpellTexture then return _G.GetSpellTexture(spellID) end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then return info.iconID or info.icon end
    end
    return nil
end

local INTERRUPTS_BY_CLASS = {
    DEATHKNIGHT = { 47528 }, DEMONHUNTER = { 183752 }, DRUID = { 106839, 78675 },
    EVOKER = { 351338 }, HUNTER = { 147362, 187707 }, MAGE = { 2139 },
    MONK = { 116705, 173320 }, PALADIN = { 96231 }, PRIEST = { 15487 },
    ROGUE = { 1766 }, SHAMAN = { 57994 }, WARLOCK = { 119898, 19647, 115781, 119910 },
    WARRIOR = { 6552 },
}

local GCD_THRESHOLD = 1.8

-- ============================================================================
-- Inicialización del Módulo
-- ============================================================================

function IG:OnInitialize()
    if not KT.db.profile.interruptsGlow then
        KT.db.profile.interruptsGlow = {
            enable = true,
            cdText = false,
            cdm = true,
            slots = {},
            localCD = {},
        }
    end
    self.db = KT.db.profile.interruptsGlow
    
    -- Sanitize localCD
    if type(self.db.localCD) ~= "table" then self.db.localCD = {} end
    if type(self.db.slots) ~= "table" then self.db.slots = {} end
    
    self.class = select(2, UnitClass("player"))
    
    -- Inicializar tablas internas
    self.interruptSpellSet = {}
    self.interruptNameToID = {}
    self.interruptTokens = {}
    self.trackedSlots = {}
    self.slotSpellID = {}
    self.slotMeta = {}
    self.trackedButtons = {}
    self.extraButtons = {}
    
    -- Estados
    self.CastActive = { target = false, focus = false }
    self.CastNI = { target = nil, focus = nil }
    self.CastNISrc = { target = nil, focus = nil }
    self.TRACKED_UNITS = { "target", "focus" }
    
    self._localCD = {
        nextReadyTime = nil,
        baseCD = nil,
        lastCastAt = nil,
    }
end

function IG:OnEnable()
    if not self.db.enable then return end
    
    self:BuildInterruptCaches()
    self:UpdateLocalCooldownBase()
    self:RestoreLocalCooldownFromDB()
    self:RescanInterruptButtons(true)
    self:HookCooldownDoneFrames()
    self:HookButtonForgeCallbacks()
    self:HookUnitFrameCastBars()

    -- Sync inicial
    self:SyncUnitState("target")
    self:SyncUnitState("focus")
    self:UpdateInterruptReady()
    
    if self.db.cdText then self:PrepareCDText() end
    if self.db.cdm and C_Timer then
        C_Timer.After(1.0, function() self:TryFindCDMButton() end)
    end
    
    self:ScheduleCDTextTick()
    self:ApplyGlowDecision()

    -- Registro de Eventos
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED") -- Usamos el mismo handler para rescan si hace falta
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("SPELLS_CHANGED", "HandleRescanEvent")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "HandleRescanEvent")
    self:RegisterEvent("UPDATE_BINDINGS", "HandleRescanEvent")
    self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", "HandleCooldownEvent")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "HandleCooldownEvent")
    
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED")
    
    self:RegisterEvent("UNIT_SPELLCAST_START", "HandleCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "HandleCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "HandleCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "HandleCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "HandleCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "HandleCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "HandleCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "HandleCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    
    -- Hook dinámico para addons que cargan tarde
    self:RegisterEvent("ADDON_LOADED")
end

function IG:OnDisable()
    self:SetGlow(false)
    self:ClearExtraButtons()
    self:UnregisterAllEvents()
    self:CancelAllTimers()
end

-- ============================================================================
-- Lógica Principal (Port del Core.lua original)
-- ============================================================================

function IG:BuildInterruptCaches()
    WipeMap(self.interruptSpellSet)
    WipeMap(self.interruptNameToID)
    WipeArray(self.interruptTokens)
    self.interruptSpellID = nil

    local list = INTERRUPTS_BY_CLASS[self.class]
    if not list then return end

    for i = 1, #list do
        local spellID = list[i]
        if spellID then
            self.interruptSpellSet[spellID] = true
            table.insert(self.interruptTokens, tostring(spellID))

            local name = SpellName(spellID)
            if name then
                local ln = name:lower()
                self.interruptNameToID[ln] = self.interruptNameToID[ln] or spellID
                table.insert(self.interruptTokens, ln)
            end

            if not self.interruptSpellID and SpellKnown(spellID) then
                self.interruptSpellID = spellID
            end
        end
    end
end

-- ============================================================================
-- Manejo de Eventos (Adaptado a AceEvent)
-- ============================================================================

function IG:PLAYER_REGEN_ENABLED()
    if self._hookCooldownDeferred then
        self:HookCooldownDoneFrames()
    end
    if self.needsRescan then
        self:BuildInterruptCaches()
        if self._needsLightRescan then
            self:LightRescanInterruptButtons()
        else
            self:RescanInterruptButtons(true)
        end
        self:HookCooldownDoneFrames()
        if self.db.cdm then C_Timer.After(0, function() self:TryFindCDMButton() end) end
        if self.db.cdText then self:PrepareCDText() end
        self:MarkReadyDirty("regen")
    end
end

function IG:ADDON_LOADED(_, addon)
    if addon and type(addon) == "string" and addon:find("Blizzard_UnitFrame") then
        C_Timer.After(0.2, function() self:HookUnitFrameCastBars() end)
    end
    if addon == "ButtonForge" then
        self:HookButtonForgeCallbacks()
        self:LightRescanInterruptButtons()
        self:HookCooldownDoneFrames()
        if self.db.cdText then self:PrepareCDText() end
        self:MarkReadyDirty("buttonforge")
    end
    if self.db.cdm and (addon:find("Blizzard_Cooldown") or addon:find("CooldownManager")) then
        C_Timer.After(0.2, function() self:TryFindCDMButton() end)
    end
end

function IG:PLAYER_ENTERING_WORLD()
    if not InCombatLockdown() then self:HookUnitFrameCastBars() end
    self:SyncUnitState("target")
    self:SyncUnitState("focus")
    self:MarkReadyDirty("entering-world")
end

function IG:HandleRescanEvent()
    self:BuildInterruptCaches()
    self:UpdateLocalCooldownBase()
    self:LightRescanInterruptButtons()
    self:HookCooldownDoneFrames()
    if self.db.cdm then C_Timer.After(0, function() self:TryFindCDMButton() end) end
    if self.db.cdText then self:PrepareCDText() end
    self:MarkReadyDirty("rescan")
end

function IG:HandleCooldownEvent()
    self:MarkReadyDirty("cooldown")
end

function IG:PLAYER_TARGET_CHANGED()
    if not InCombatLockdown() then self:HookUnitFrameCastBars() end
    self:SyncUnitState("target")
    self:ApplyGlowDecision()
    C_Timer.After(0, function() self:ApplyGlowDecision() end)
end

function IG:PLAYER_FOCUS_CHANGED()
    if not InCombatLockdown() then self:HookUnitFrameCastBars() end
    self:SyncUnitState("focus")
    self:ApplyGlowDecision()
    C_Timer.After(0, function() self:ApplyGlowDecision() end)
end

function IG:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellID)
    if unit == "player" and self.interruptSpellSet[spellID] then
        self:StartLocalCooldownFromCast(spellID)
        self:MarkReadyDirty("interrupt-used")
        C_Timer.After(0.05, function() self:MarkReadyDirty("interrupt-used-delay") end)
    end
end

local function MapEventUnit(unit)
    if not unit then return nil end
    if unit == "target" then return "target" end
    if unit == "focus" then return "focus" end
    if UnitIsUnitSafe(unit, "target") then return "target" end
    if UnitIsUnitSafe(unit, "focus")  then return "focus" end
    return nil
end

function IG:HandleCastEvent(event, unit)
    local mapped = MapEventUnit(unit)
    if not mapped then return end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        self.CastActive[mapped] = true
        self.CastNI[mapped] = nil
        self.CastNISrc[mapped] = nil
        self:MarkReadyDirty("cast-start")
        C_Timer.After(0, function() self:ApplyGlowDecision() end)
    elseif event:find("STOP") or event:find("FAILED") or event:find("INTERRUPTED") then
        self.CastActive[mapped] = false
        self.CastNI[mapped] = nil
        self.CastNISrc[mapped] = nil
        self:ApplyGlowDecision()
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        self.CastNI[mapped] = true
        self.CastNISrc[mapped] = "event"
        self:ApplyGlowDecision()
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        self.CastNI[mapped] = false
        self.CastNISrc[mapped] = "event"
        self:ApplyGlowDecision()
    end
end

-- ============================================================================
-- Glow & Visuals
-- ============================================================================

local PROC_TEMPLATES = {
    "ActionButtonSpellAlertTemplate",
    "ActionBarButtonSpellActivationAlert",
    "ActionButtonSpellActivationAlert",
    "SpellActivationAlertTemplate",
    "SpellActivationAlert",
}

local function EnsureIGAlert(btn)
    if not btn or btn.IsForbidden and btn:IsForbidden() then return nil end
    if btn.__IG_Alert then return btn.__IG_Alert end

    local w, h = 0, 0
    if btn.GetSize then w, h = btn:GetSize() end

    for i = 1, #PROC_TEMPLATES do
        local ok, f = pcall(CreateFrame, "Frame", nil, btn, PROC_TEMPLATES[i])
        if ok and f then
            if w and h and w > 0 and h > 0 then
                f:SetSize(w * 1.4, h * 1.4)
            else
                f:SetAllPoints(btn)
            end
            f:SetPoint("CENTER", btn, "CENTER", 0, 0)
            f:SetFrameStrata("HIGH")
            f:SetFrameLevel((btn.GetFrameLevel and btn:GetFrameLevel() or 0) + 50)
            f:Hide()
            btn.__IG_Alert = f
            return f
        end
    end
end

local function SafePlay(obj)
    if obj and obj.Play then pcall(obj.Play, obj); return true end
    return false
end

local function SafeStop(obj)
    if obj and obj.Stop then pcall(obj.Stop, obj); return true end
    return false
end

local function StartProc(alert)
    if not alert then return end
    local start = alert.ProcStartAnim or alert.procStartAnim or alert.AnimIn or alert.animIn
    local loop  = alert.ProcLoopAnim  or alert.procLoopAnim  or alert.AnimLoop or alert.animLoop
    local out = alert.ProcEndAnim or alert.procEndAnim or alert.AnimOut or alert.animOut
    if out and out.IsPlaying and out:IsPlaying() then pcall(out.Stop, out) end
    SafePlay(start)
    SafePlay(loop)
end

local function StopProc(alert)
    if not alert then return end
    local out = alert.ProcEndAnim or alert.procEndAnim or alert.AnimOut or alert.animOut
    if out and out.Play then pcall(out.Play, out); return end
    SafeStop(alert.ProcStartAnim or alert.procStartAnim or alert.AnimIn or alert.animIn)
    SafeStop(alert.ProcLoopAnim  or alert.procLoopAnim  or alert.AnimLoop or alert.animLoop)
end

local function HookAlertAnims(alert)
    if not alert or alert.__IG_AnimHooked or not alert.HookScript then return end
    alert.__IG_AnimHooked = true
    alert:HookScript("OnShow", function(self) StartProc(self) end)
    alert:HookScript("OnHide", function(self) StopProc(self) end)
end

local function ShowGlow(btn)
    local alert = EnsureIGAlert(btn)
    if not alert then return end
    HookAlertAnims(alert)
    alert:SetShown(true)
end

local function HideGlow(btn)
    local alert = btn and btn.__IG_Alert
    if not alert then return end
    HookAlertAnims(alert)
    alert:SetShown(false)
end

function IG:SetGlow(active)
    if IsSecret(active) then
        self.glowActive = "secret"
        self._glowSecretReady = active
        
        local function ApplySecret(alert)
            if not alert then return end
            HookAlertAnims(alert)
            if alert.SetAlphaFromBoolean then
                alert:Show()
                alert:SetAlphaFromBoolean(active, 1, 0)
                StartProc(alert)
            else
                alert:Show()
            end
        end
        
        for i = 1, #self.trackedButtons do ApplySecret(EnsureIGAlert(self.trackedButtons[i])) end
        for i = 1, #self.extraButtons do ApplySecret(EnsureIGAlert(self.extraButtons[i])) end
        return
    end
    
    if active == self.glowActive then return end
    self.glowActive = (active == true)
    self._glowSecretReady = nil

    if active then
        for i = 1, #self.trackedButtons do ShowGlow(self.trackedButtons[i]) end
        for i = 1, #self.extraButtons do ShowGlow(self.extraButtons[i]) end
    else
        for i = 1, #self.trackedButtons do HideGlow(self.trackedButtons[i]) end
        for i = 1, #self.extraButtons do HideGlow(self.extraButtons[i]) end
    end
end

function IG:ApplyGlowDecision()
    if not self.interruptReadyIsSecret and not self.interruptReady then
        self:SetGlow(false)
        return
    end

    for _, unit in ipairs(self.TRACKED_UNITS) do
        local canAttack = SafeBool(UnitCanAttack("player", unit))
        if canAttack and self.CastActive[unit] and (self.CastNI[unit] ~= true) then
            if self.interruptReadyIsSecret then
                self:SetGlow(self.interruptReady)
            else
                self:SetGlow(true)
            end
            return
        end
    end

    self:SetGlow(false)
end

-- ============================================================================
-- Cooldown Text
-- ============================================================================

function IG:EnsureCDText(btn)
    if not btn or btn.IsForbidden and btn:IsForbidden() then return end
    if btn.__IGCDText then return btn.__IGCDText end
    
    local fs = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:Hide()
    btn.__IGCDText = fs
    return fs
end

function IG:PrepareCDText()
    if InCombatLockdown() then return end
    for i = 1, #self.trackedButtons do self:EnsureCDText(self.trackedButtons[i]) end
    for i = 1, #self.extraButtons do self:EnsureCDText(self.extraButtons[i]) end
end

function IG:UpdateCDText()
    if not self.db.cdText then return end
    local rem = self.cdRem
    local text = ""
    if type(rem) == "number" and not IsSecret(rem) and rem > 0.05 then
        text = tostring(math.ceil(rem))
    end
    
    local function Set(btn)
        if btn and not (btn.IsForbidden and btn:IsForbidden()) and btn.__IGCDText then
            if text ~= "" then btn.__IGCDText:SetText(text); btn.__IGCDText:Show() else btn.__IGCDText:Hide() end
        end
    end
    
    for i = 1, #self.trackedButtons do Set(self.trackedButtons[i]) end
    for i = 1, #self.extraButtons do Set(self.extraButtons[i]) end
end

function IG:ScheduleCDTextTick()
    if not self.db.cdText then 
        if self._cdTextTimer then self:CancelTimer(self._cdTextTimer) end
        return 
    end
    self:UpdateCDText()
    
    local rem = self.cdRem
    if type(rem) ~= "number" or IsSecret(rem) or rem <= 0.05 then
        if self._cdTextTimer then self:CancelTimer(self._cdTextTimer) end
        self._cdTextTimer = nil
        return
    end
    
    local frac = rem - math.floor(rem)
    local delay = (frac < 0.05) and 0.95 or frac
    
    self._cdTextTimer = self:ScheduleTimer("ScheduleCDTextTick", delay)
end

-- ============================================================================
-- Scanning & Readiness (Versión Simplificada para el Módulo)
-- ============================================================================

local function MacroMatchesInterrupt(macroId, spellSet, nameToID, tokens)
    if not macroId then return false end
    if GetMacroSpell then
        local ms = GetMacroSpell(macroId)
        if ms then
            if type(ms) == "number" and spellSet[ms] then return true end
            if type(ms) == "string" and nameToID[ms:lower()] then return true end
        end
    end
    if not GetMacroInfo then return false end
    local _, _, body = GetMacroInfo(macroId)
    if not body or body == "" then return false end
    local b = body:lower()
    for i = 1, #tokens do
        if b:find(tokens[i], 1, true) then return true end
    end
    return false
end

local function ResolveInterruptSpellIDFromMacro(macroId, spellSet, nameToID)
    if not macroId then return nil end
    if GetMacroSpell then
        local ms = GetMacroSpell(macroId)
        if type(ms) == "number" and spellSet[ms] then return ms end
        if type(ms) == "string" then
            local sid = nameToID[ms:lower()]
            if sid then return sid end
        end
    end
    if GetMacroInfo then
        local _, _, body = GetMacroInfo(macroId)
        if type(body) == "string" and body ~= "" then
            local b = body:lower()
            for sid in pairs(spellSet) do
                if b:find(tostring(sid), 1, true) then return sid end
            end
            for name, sid in pairs(nameToID) do
                if b:find(name, 1, true) then return sid end
            end
        end
    end
    return nil
end

function IG:ScanActionSlots()
    WipeMap(self.trackedSlots)
    WipeMap(self.slotSpellID)
    WipeMap(self.slotMeta)
    
    local foundSlots = {}
    local n = 0
    
    for slot = 1, 180 do
        local actionType, id = GetActionInfo(slot)
        local ok, sid, aType, aId = false, nil, actionType, id
        
        if actionType == "spell" and type(id) == "number" and self.interruptSpellSet[id] then
            ok, sid = true, id
        elseif actionType == "macro" and id then
            if MacroMatchesInterrupt(id, self.interruptSpellSet, self.interruptNameToID, self.interruptTokens) then
                ok = true
                sid = ResolveInterruptSpellIDFromMacro(id, self.interruptSpellSet, self.interruptNameToID)
            elseif type(id) == "number" and self.interruptSpellSet[id] then
                ok, sid = true, id
            end
        end
        
        if ok then
            self.trackedSlots[slot] = true
            self.slotSpellID[slot] = sid
            self.slotMeta[slot] = { actionType = aType, actionId = aId, spellID = sid }
            n = n + 1
            foundSlots[n] = slot
        end
    end
    
    self.db.slots = foundSlots
    self.primarySlot = foundSlots[1]
    self._slotResolvedSpellID = self.primarySlot and self.slotSpellID[self.primarySlot] or nil
end

local function GetButtonActionSlot(btn)
    local t = type(btn)
    if t ~= "table" and t ~= "userdata" then return nil end
    local a = btn.action
    if type(a) == "number" then return a end
    if type(a) == "string" then local n = tonumber(a); if n then return n end end
    a = btn._state_action
    if type(a) == "number" then return a end
    if type(a) == "string" then local n = tonumber(a); if n then return n end end
    if btn.GetAttribute then
        a = btn:GetAttribute("action")
        if type(a) == "number" then return a end
        if type(a) == "string" then local n = tonumber(a); if n then return n end end
    end
    return nil
end

local function AddUniqueButton(list, btn)
    for i = 1, #list do if list[i] == btn then return end end
    list[#list + 1] = btn
end

local function ButtonForgeActionMatchesInterrupt(api, buttonName, spellSet, nameToID, tokens)
    if not api or type(api.GetButtonActionInfo) ~= "function" then return false, nil end
    local actionType, id = api.GetButtonActionInfo(buttonName)
    if actionType == "spell" and type(id) == "number" and spellSet[id] then
        return true, id
    end
    if actionType == "macro" and id then
        if MacroMatchesInterrupt(id, spellSet, nameToID, tokens) then
            return true, ResolveInterruptSpellIDFromMacro(id, spellSet, nameToID)
        end
    end
    return false, nil
end

function IG:ButtonAttributesLookLikeInterrupt(btn)
    if not btn.GetAttribute then return false, nil, nil end

    local t = btn:GetAttribute("type") or btn:GetAttribute("type1")

    if t == "spell" then
        local sp = btn:GetAttribute("spell") or btn:GetAttribute("spell1")
        if type(sp) == "number" and self.interruptSpellSet[sp] then
            return true, "attr spellID", sp
        end
        if type(sp) == "string" then
            local sid = self.interruptNameToID[sp:lower()]
            if sid then
                return true, "attr spell name", sid
            end
        end

    elseif t == "macro" then
        local txt = btn:GetAttribute("macrotext") or btn:GetAttribute("macrotext1")
        if type(txt) == "string" and txt ~= "" then
            local b = txt:lower()
            for sid in pairs(self.interruptSpellSet) do
                if b:find(tostring(sid), 1, true) then
                    return true, "attr macrotext spellID", sid
                end
            end
            for name, sid in pairs(self.interruptNameToID) do
                if b:find(name, 1, true) then
                    return true, "attr macrotext name", sid
                end
            end
        end
    end

    -- Some buttons do not set type but still have spell attributes
    local sp = btn:GetAttribute("spell") or btn:GetAttribute("spell1")
    if type(sp) == "number" and self.interruptSpellSet[sp] then
        return true, "attr spellID (no type)", sp
    end
    if type(sp) == "string" then
        local sid = self.interruptNameToID[sp:lower()]
        if sid then
            return true, "attr spell name (no type)", sid
        end
    end

    return false, nil, nil
end

function IG:MapButtonsFromButtonForge()
    local api = _G.ButtonForge_API1
    if not api or type(api.GetButtonFrameNames) ~= "function" then return end
    if api.GetButtonForgeInitialised and not api.GetButtonForgeInitialised() then return end

    local names = api.GetButtonFrameNames()
    if type(names) ~= "table" then return end

    for i = 1, #names do
        local name = names[i]
        local btn = type(name) == "string" and _G[name] or nil
        if btn then
            local slot = GetButtonActionSlot(btn)
            if slot and self.trackedSlots[slot] then
                AddUniqueButton(self.trackedButtons, btn)
            else
                local ok, _, sid = self:ButtonAttributesLookLikeInterrupt(btn)
                if ok then
                    AddUniqueButton(self.trackedButtons, btn)
                    self._attrResolvedSpellID = self._attrResolvedSpellID or sid
                else
                    local ok2, sid2 = ButtonForgeActionMatchesInterrupt(api, name, self.interruptSpellSet, self.interruptNameToID, self.interruptTokens)
                    if ok2 then
                        AddUniqueButton(self.trackedButtons, btn)
                        self._attrResolvedSpellID = self._attrResolvedSpellID or sid2
                    end
                end
            end
        end
    end
end

function IG:RescanInterruptButtons(deep)
    if InCombatLockdown() then self.needsRescan = true; return end
    self.needsRescan = false
    
    -- Limpiar listas
    self:SetGlow(false)
    WipeArray(self.trackedButtons)
    WipeArray(self.extraButtons)
    self.cdmButton = nil
    self._cdmLastScan = nil
    self._slotResolvedSpellID = nil
    self._attrResolvedSpellID = nil
    
    self:ScanActionSlots()
    self:MapButtonsFromNamedBars()
    self:MapButtonsFromButtonForge()
    
    -- Elegir mejor botón primario
    local bestSlot, bestBtn, bestScore = nil, nil, -1
    for i = 1, #self.trackedButtons do
        local b = self.trackedButtons[i]
        local s = GetButtonActionSlot(b)
        if s and self.trackedSlots[s] then
            local score = 0
            local m = self.slotMeta[s]
            if m and m.actionType == "spell" then score = score + 100 end
            if m and m.actionType == "macro" then score = score + 50 end
            if b:IsVisible() then score = score + 10 end
            if score > bestScore then bestScore, bestSlot, bestBtn = score, s, b end
        end
    end
    
    if not bestSlot then bestSlot = self.db.slots and self.db.slots[1] or nil end
    self.primarySlot = bestSlot
    self.primaryButton = bestBtn or self.trackedButtons[1]
    self._slotResolvedSpellID = bestSlot and self.slotSpellID[bestSlot] or nil
    
    -- Resolver SpellID final
    self.interruptSpellID = self._slotResolvedSpellID or self._attrResolvedSpellID
    if not self.interruptSpellID then
        -- Fallback al primero de la clase
        local list = INTERRUPTS_BY_CLASS[self.class]
        if list then self.interruptSpellID = list[1] end
    end
end

function IG:LightRescanInterruptButtons()
    if InCombatLockdown() then self.needsRescan = true; self._needsLightRescan = true; return end
    self.needsRescan = false
    self._needsLightRescan = false
    
    self:ScanActionSlots()
    
    -- Podar botones inválidos
    for i = #self.trackedButtons, 1, -1 do
        local b = self.trackedButtons[i]
        if not b or (b.IsForbidden and b:IsForbidden()) then
            table.remove(self.trackedButtons, i)
        else
            local slot = GetButtonActionSlot(b)
            if slot and not self.trackedSlots[slot] then
                table.remove(self.trackedButtons, i)
            end
        end
    end
    
    self:MapButtonsFromNamedBars()
    self:MapButtonsFromButtonForge()
    
    self:HookCooldownDoneFrames()
    if self.db.cdText then self:PrepareCDText() end
end

function IG:MapButtonsFromNamedBars()
    local NAMED_SETS = {
        { prefix = "ActionButton", count = 12 },
        { prefix = "MultiBarBottomLeftButton", count = 12 },
        { prefix = "MultiBarBottomRightButton", count = 12 },
        { prefix = "MultiBarRightButton", count = 12 },
        { prefix = "MultiBarLeftButton", count = 12 },
        { prefix = "MultiBar5Button", count = 12 },
        { prefix = "MultiBar6Button", count = 12 },
        { prefix = "MultiBar7Button", count = 12 },
        { prefix = "BT4Button", count = 180 },
        { prefix = "DominosActionButton", count = 180 },
    }
    
    for _, set in ipairs(NAMED_SETS) do
        for i = 1, set.count do
            local btn = _G[set.prefix .. i]
            if btn then
                local slot = GetButtonActionSlot(btn)
                if slot and self.trackedSlots[slot] then AddUniqueButton(self.trackedButtons, btn) end
            end
        end
    end
    
    for bar = 1, 10 do
        for i = 1, 12 do
            local btn = _G["ElvUI_Bar" .. bar .. "Button" .. i]
            if btn then
                local slot = GetButtonActionSlot(btn)
                if slot and self.trackedSlots[slot] then AddUniqueButton(self.trackedButtons, btn) end
            end
        end
    end
end

function IG:EnumerateAndMapButtons(maxFrames)
    -- Deliberately disabled.
    -- Scanning every Button in the UI can taint unrelated Blizzard widgets
    -- and combat systems such as Blizzard_DamageMeter. We only support
    -- known action bar button sets plus explicit integrations.
    return
end

function IG:MarkReadyDirty()
    if self._readyTimer then return end
    self._readyTimer = C_Timer.NewTimer(0.1, function()
        self._readyTimer = nil
        self:UpdateInterruptReady()
        self:ApplyGlowDecision()
        self:UpdateCDText()
        self:ScheduleCDTextTick()
    end)
end

-- ============================================================================
-- Lógica de Cooldown Real (Complex)
-- ============================================================================

local function RemainingFromStartDuration(st, du, now)
    if IsSecret(st) or IsSecret(du) then return nil end
    if type(st) ~= "number" or type(du) ~= "number" then return nil end
    if st <= 0 or du <= 0 then return 0 end
    local rem = (st + du) - (now or 0)
    if rem < 0 then rem = 0 end
    return rem
end

local function GetSpellCooldownState(spellID, now)
    if not spellID then return false end
    
    -- 1. C_Spell
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellID)
        if cd then
            local st, du = cd.startTime, cd.duration
            if not IsSecret(st) and not IsSecret(du) and type(st) == "number" and type(du) == "number" then
                if st <= 0 or du <= 0 or du <= GCD_THRESHOLD then return true, true, false, 0, "spell:ready" end
                local rem = RemainingFromStartDuration(st, du, now)
                return true, (rem or 0) <= 0.05, false, rem, "spell:cd"
            end
        end
    end
    
    -- 2. Legacy
    if _G.GetSpellCooldown then
        local st, du = _G.GetSpellCooldown(spellID)
        if not IsSecret(st) and not IsSecret(du) and type(st) == "number" and type(du) == "number" then
            if st <= 0 or du <= 0 or du <= GCD_THRESHOLD then return true, true, false, 0, "spell:ready" end
            local rem = RemainingFromStartDuration(st, du, now)
            return true, (rem or 0) <= 0.05, false, rem, "spell:cd"
        end
    end
    
    return false
end

local function GetActionCooldownState(slot, now)
    if not slot then return false end
    if C_ActionBar and C_ActionBar.GetActionCooldown then
        local cd = C_ActionBar.GetActionCooldown(slot)
        if cd then
            local st, du = cd.startTime, cd.duration
            if not IsSecret(st) and not IsSecret(du) and type(st) == "number" and type(du) == "number" then
                if st <= 0 or du <= 0 or du <= GCD_THRESHOLD then return true, true, false, 0, "action:ready" end
                local rem = RemainingFromStartDuration(st, du, now)
                return true, (rem or 0) <= 0.05, false, rem, "action:cd"
            end
        end
    end
    if GetActionCooldown then
        local st, du = GetActionCooldown(slot)
        if not IsSecret(st) and not IsSecret(du) and type(st) == "number" and type(du) == "number" then
            if st <= 0 or du <= 0 or du <= GCD_THRESHOLD then return true, true, false, 0, "action:ready" end
            local rem = RemainingFromStartDuration(st, du, now)
            return true, (rem or 0) <= 0.05, false, rem, "action:cd"
        end
    end
    return false
end

function IG:UpdateInterruptReady()
    local now = GetTime and GetTime() or 0
    self.cdSrc = nil
    self.cdRem = nil
    self.interruptReadyIsSecret = false
    
    local known, ready, readyIsSecret, rem, src
    
    if self.primarySlot then
        known, ready, readyIsSecret, rem, src = GetActionCooldownState(self.primarySlot, now)
        
        -- Override de macro si la acción dice READY pero el spell no
        local meta = self.slotMeta and self.slotMeta[self.primarySlot]
        if known and ready == true and meta and meta.actionType == "macro" and self.interruptSpellID then
            local k2, r2, rs2, rem2, src2 = GetSpellCooldownState(self.interruptSpellID, now)
            if k2 and r2 == false then
                known, ready, readyIsSecret, rem, src = k2, r2, rs2, rem2, "spell:override"
            end
        end
    end
    
    if not known then
        known, ready, readyIsSecret, rem, src = GetSpellCooldownState(self.interruptSpellID, now)
    end
    
    -- Fallback a Local Cooldown si todo falla (APIs restringidas)
    if not known and self._localCD and type(self._localCD.nextReadyTime) == "number" then
        local nrt = self._localCD.nextReadyTime
        if not IsSecret(nrt) then
            local remL = nrt - now
            if remL > 0.05 then
                known, ready, readyIsSecret, rem, src = true, false, false, remL, "local:cast"
            else
                self._localCD.nextReadyTime = nil
                known, ready, readyIsSecret, rem, src = true, true, false, 0, "local:ready"
            end
        end
    end
    
    -- Sincronizar local tracker si tenemos datos fiables
    if known and not IsSecret(ready) and self._localCD then
        if ready == true then
            self._localCD.nextReadyTime = nil
        elseif type(rem) == "number" and rem > 0.05 then
            self._localCD.nextReadyTime = now + rem
        end
    end
    
    if known then
        self.interruptReady = (ready == true)
        self.interruptReadyIsSecret = false
        if type(rem) == "number" and not IsSecret(rem) then self.cdRem = rem end
        self.cdSrc = src
    else
        self.interruptReady = true
        self.interruptReadyIsSecret = false
        self.cdRem = nil
        self.cdSrc = "unknown"
    end
end

-- ============================================================================
-- Integración CDM (Cooldown Manager)
-- ============================================================================

local function GetFrameSpellID(f)
    if not f then return nil end
    local sid = f.spellID or f.spellId
    if type(sid) == "number" then return sid end
    if f.GetSpellID then
        local ok, v = pcall(f.GetSpellID, f)
        if ok and type(v) == "number" then return v end
    end
    return nil
end

local function CollectChildrenForSpell(root, spellID, maxNodes, out, seen)
    if not root then return end
    out = out or {}
    seen = seen or {}
    local queue = { root }
    local q = 1
    local nodes = 0
    
    while q <= #queue and nodes < maxNodes do
        local fr = queue[q]
        q = q + 1
        nodes = nodes + 1
        
        if fr and fr.GetObjectType then
            local ot = fr:GetObjectType()
            if ot == "Button" or ot == "Frame" then
                local sid = GetFrameSpellID(fr)
                if sid and not IsSecret(sid) and sid == spellID then
                    if not seen[fr] then
                        out[#out + 1] = fr
                        seen[fr] = true
                    end
                end
            end
        end
        
        if fr and fr.GetChildren then
            local children = { fr:GetChildren() }
            for i = 1, #children do queue[#queue + 1] = children[i] end
        end
    end
end

function IG:TryFindCDMButton()
    if not self.db.cdm then return end
    if not self.interruptSpellID then return end
    if InCombatLockdown() then return end
    
    local roots = {}
    if _G.EssentialCooldownViewer then table.insert(roots, _G.EssentialCooldownViewer) end
    if _G.UtilityCooldownViewer then table.insert(roots, _G.UtilityCooldownViewer) end
    
    if #roots == 0 then return end
    
    local found = {}
    local seen = {}
    for i = 1, #roots do
        CollectChildrenForSpell(roots[i], self.interruptSpellID, 6000, found, seen)
    end
    
    if #found > 0 then
        WipeArray(self.extraButtons)
        for i = 1, #found do self.extraButtons[i] = found[i] end
        self.cdmButton = found[1]
        self:HookCooldownDoneFrames()
        if self.db.cdText then self:PrepareCDText() end
        self:MarkReadyDirty("cdm-scan")
    end
end

function IG:ClearExtraButtons()
    if self.glowActive then
        for i = 1, #self.extraButtons do HideGlow(self.extraButtons[i]) end
    end
    WipeArray(self.extraButtons)
    self.cdmButton = nil
end

-- ============================================================================
-- Local Cooldown / Castbars Hooks (Helpers)
-- ============================================================================

local function GetSpellBaseCooldownSeconds(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellBaseCooldown then
        local a = C_Spell.GetSpellBaseCooldown(spellID)
        if not IsSecret(a) and type(a) == "number" and a > 0 then return a / 1000 end
    end
    return nil
end

function IG:UpdateLocalCooldownBase()
    if not self.interruptSpellID then return end
    local cd = GetSpellBaseCooldownSeconds(self.interruptSpellID)
    if type(cd) == "number" and cd >= 0 then
        self._localCD.baseCD = cd
    end
end

function IG:RestoreLocalCooldownFromDB()
    local t = self.db.localCD
    if type(t) ~= "table" then return end
    local srvNow = (GetServerTime and GetServerTime()) or nil
    if type(srvNow) ~= "number" then return end
    
    local srvCast = t.lastCastServer
    local dur = t.lastCastDur
    if type(srvCast) ~= "number" or type(dur) ~= "number" then return end
    
    local elapsed = srvNow - srvCast
    if elapsed < 0 or elapsed > (dur + 5) then return end
    
    local rem = dur - elapsed
    if rem > 0.05 then
        local now = GetTime()
        self._localCD.nextReadyTime = now + rem
        self._localCD.lastCastAt = now - elapsed
    end
end

function IG:StartLocalCooldownFromCast(spellID)
    if not spellID or not self.interruptSpellSet[spellID] then return end
    local now = GetTime()
    
    if type(self._localCD.baseCD) ~= "number" then self:UpdateLocalCooldownBase() end
    
    local dur = nil
    local k, r, rs, rem = GetSpellCooldownState(spellID, now)
    if k and r == false and type(rem) == "number" and rem > (GCD_THRESHOLD + 0.1) then
        dur = rem
    end
    
    if not dur then dur = self._localCD.baseCD end
    if not dur then dur = 15 end -- Fallback final
    
    self._localCD.lastCastAt = now
    self._localCD.nextReadyTime = now + dur
    
    if GetServerTime then
        local srv = GetServerTime()
        if type(srv) == "number" then
            self.db.localCD.lastCastServer = srv
            self.db.localCD.lastCastDur = dur
            self.db.localCD.lastSpellID = spellID
        end
    end
end

local function GetButtonCooldownWidget(btn)
    if not btn or (btn.IsForbidden and btn:IsForbidden()) then return nil end
    if btn.__IGCooldownWidget then return btn.__IGCooldownWidget end
    
    local cd = btn.cooldown or btn.Cooldown or btn.IconCooldown
    if cd then btn.__IGCooldownWidget = cd; return cd end
    
    if btn.GetChildren then
        for _, c in ipairs({btn:GetChildren()}) do
            if c.GetObjectType and c:GetObjectType() == "Cooldown" then
                btn.__IGCooldownWidget = c; return c
            end
        end
    end
    return nil
end

function IG:HookCooldownDoneFrames()
    if InCombatLockdown() then self._hookCooldownDeferred = true; return end
    self._hookCooldownDeferred = false
    
    local function Hook(btn)
        local cd = GetButtonCooldownWidget(btn)
        if not cd or (cd.IsForbidden and cd:IsForbidden()) then return end
        -- Midnight secret-value clients: the native cooldown widget of a Blizzard
        -- secure action button cannot carry addon script hooks without tainting
        -- the button's update path (SetShown / SetCooldown secret rejections).
        if cd.IsProtected and cd:IsProtected() then return end
        if not cd.HookScript or cd.__IGCooldownDoneHooked then return end
        cd.__IGCooldownDoneHooked = true
        cd:HookScript("OnCooldownDone", function() IG:MarkReadyDirty("cooldown-done") end)
    end
    
    for i = 1, #self.trackedButtons do Hook(self.trackedButtons[i]) end
    for i = 1, #self.extraButtons do Hook(self.extraButtons[i]) end
end

function IG:HookButtonForgeCallbacks()
    if self._bfCallbackRegistered then return end
    local api = _G.ButtonForge_API1
    if not api or type(api.RegisterCallback) ~= "function" then return end
    self._bfCallbackRegistered = true
    api.RegisterCallback(function(_, event)
        if event == "INITIALISED" or event == "BUTTON_ALLOCATED" or event == "BUTTON_DEALLOCATED" then
            IG:RescanInterruptButtons(true)
            IG:HookCooldownDoneFrames()
            if IG.db.cdText then IG:PrepareCDText() end
            IG:MarkReadyDirty("buttonforge")
        end
    end, self)
end

local function HookCastBarShield(unit, bar)
    if not bar or (bar.IsForbidden and bar:IsForbidden()) then return end
    local shield = bar.BorderShield or bar.BorderShieldFrame or bar.Shield
    
    -- [FIX] Ensure shield is a Frame before hooking. Textures cannot be hooked.
    if not shield or not shield.IsObjectType or not shield:IsObjectType("Frame") then return end
    
    if not shield or not shield.HookScript or (shield.IsForbidden and shield:IsForbidden()) then return end
    if shield.__IG_ShieldHooked then return end
    shield.__IG_ShieldHooked = true
    
    shield:HookScript("OnShow", function()
        IG.CastNI[unit] = true
        IG.CastNISrc[unit] = "shield"
        IG:ApplyGlowDecision()
    end)
    shield:HookScript("OnHide", function()
        if IG.CastNISrc[unit] == "shield" then
            IG.CastNI[unit] = nil
            IG.CastNISrc[unit] = nil
            IG:ApplyGlowDecision()
        end
    end)
end

local function HookUnitFrameCastBar(unit, bar)
    if not bar or not bar.HookScript or bar.__IG_Hooked then return end
    if bar.IsForbidden and bar:IsForbidden() then return end
    bar.__IG_Hooked = true
    
    HookCastBarShield(unit, bar)
    
    bar:HookScript("OnShow", function()
        -- [FIX] Sync state from API instead of assuming defaults, handles non-interruptible correctly
        IG:SyncUnitState(unit)
        IG:ApplyGlowDecision()
    end)
    bar:HookScript("OnHide", function()
        IG.CastActive[unit] = false
        IG.CastNI[unit] = nil
        IG.CastNISrc[unit] = nil
        IG:ApplyGlowDecision()
    end)
end

function IG:HookUnitFrameCastBars() 
    HookUnitFrameCastBar("target", _G.TargetFrameSpellBar)
    HookUnitFrameCastBar("focus",  _G.FocusFrameSpellBar)
    
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local np = C_NamePlate.GetNamePlateForUnit("target")
        local uf = np and (np.UnitFrame or np.unitFrame)
        local cb = uf and (uf.castBar or uf.CastBar or uf.castbar)
        if cb then HookCastBarShield("target", cb) end
    end
end

function IG:SyncUnitState(unit)
    local casting = UnitCastingInfo(unit)
    local channeling = UnitChannelInfo(unit)
    local active = (casting or channeling)
    
    -- [FIX] Use SafeBool to prevent taint error on secret values
    -- Logic correction: CastNI (Not Interruptible) should be true if the cast is shielded (notInterruptible=true)
    local _, _, _, _, _, _, _, notIntCast = UnitCastingInfo(unit)
    local _, _, _, _, _, _, notIntChannel = UnitChannelInfo(unit)
    local isNotInterruptible = SafeBool(notIntCast) or SafeBool(notIntChannel)
    
    if unit == "target" then 
        self.CastActive.target = active
        self.CastNI.target = isNotInterruptible
    elseif unit == "focus" then
        self.CastActive.focus = active
        self.CastNI.focus = isNotInterruptible
    end
end
