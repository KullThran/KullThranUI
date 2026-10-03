local _, ns = ...
local KUI_CDM = ns.KUI_CDM
local KT = ns.KT or _G.KT
local VALID_MODES = {
    always = true,
    lower_alpha_on_cd = true,
    hidden_on_cd_shift = true,
    hidden_cd_ready_shift = true,
    usable_shift = true,
    hidden_on_cd = true,
    hidden_cd_ready = true,
    usable = true,
    glow_cd_ready = true,
    glow_on_cd = true,
    glow_cd_ready_resource = true,
}

local SHIFT_MODES = {
    hidden_on_cd_shift = true,
    hidden_cd_ready_shift = true,
    usable_shift = true,
}

local VALID_MODIFIERS = {
    suppress_gcd = true,
    hide_charge_text = true,
    hide_swipe_charges = true,
    hide_recharge_edge = true,
    hide_duration_charges = true,
    stay_hidden_while_charges_remain = true,
    keep_colored_on_cd = true,
}

local function Profile()
    return KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
end

local function EnsureStore()
    local p = Profile()
    if not p then return nil end
    p.barGlows = p.barGlows or {}
    p.barGlows.usableVisibility = p.barGlows.usableVisibility or {}
    p.cdmUsableVisibilityAllSpecs = p.cdmUsableVisibilityAllSpecs or {}
    return p.barGlows.usableVisibility, p
end

local function EnsureModifierStore()
    local p = Profile()
    if not p then return nil end
    p.barGlows = p.barGlows or {}
    p.barGlows.cooldownStateModifiers = p.barGlows.cooldownStateModifiers or {}
    p.cdmCooldownStateModifiersAllSpecs = p.cdmCooldownStateModifiersAllSpecs or {}
    return p.barGlows.cooldownStateModifiers, p
end

local function EnsureBar(store, barKey)
    local rule = store[barKey]
    if not rule then
        rule = { spells = {} }
        store[barKey] = rule
    end
    rule.spells = rule.spells or {}
    return rule
end

local function Normalize(mode)
    return VALID_MODES[mode] and mode or "always"
end

function ns.GetCDMUsableVisibilityMode(barKey, spellID)
    local store, p = EnsureStore()
    if not store then return "always" end
    local rule = store[barKey]
    local value = rule and rule.spells and rule.spells[tostring(spellID)]
    if value ~= nil then return Normalize(value) end
    if rule and rule.barMode ~= nil then return Normalize(rule.barMode) end
    return Normalize(p.cdmUsableVisibilityAllSpecs[barKey])
end

function ns.SetCDMUsableVisibilityMode(barKey, spellID, mode, scope)
    local store, p = EnsureStore()
    if not store then return false end
    mode = Normalize(mode)
    if scope == "spell" then
        if type(spellID) ~= "number" or spellID <= 0 then return false end
        EnsureBar(store, barKey).spells[tostring(spellID)] = mode
    elseif scope == "bar_all_specs" then
        p.cdmUsableVisibilityAllSpecs[barKey] = mode
        store[barKey] = nil
        for _, specProfile in pairs(p.specProfiles or {}) do
            local glows = specProfile and specProfile.barGlows
            if glows and glows.usableVisibility then
                glows.usableVisibility[barKey] = nil
            end
        end
    else
        local rule = EnsureBar(store, barKey)
        rule.barMode = mode
        rule.spells = {}
    end
    if ns.RefreshCDMUsableVisibility then ns.RefreshCDMUsableVisibility() end
    return true
end

local function EnsureModifierBar(store, barKey)
    local rule = store[barKey]
    if not rule then rule = { bar = {}, spells = {} }; store[barKey] = rule end
    rule.bar = rule.bar or {}
    rule.spells = rule.spells or {}
    return rule
end

function ns.GetCDMCooldownStateModifiers(barKey, spellID)
    local store, p = EnsureModifierStore()
    local result = {}
    if not store then return result end
    local shared = p.cdmCooldownStateModifiersAllSpecs[barKey]
    for key in pairs(VALID_MODIFIERS) do
        local value = shared and shared[key]
        local rule = store[barKey]
        if rule and rule.bar and rule.bar[key] ~= nil then value = rule.bar[key] end
        local spell = rule and rule.spells and rule.spells[tostring(spellID)]
        if spell and spell[key] ~= nil then value = spell[key] end
        result[key] = value == true
    end
    return result
end

local function ClearModifierFromBar(store, barKey, key)
    local rule = store and store[barKey]
    if not rule then return end
    if rule.bar then rule.bar[key] = nil end
    for _, spell in pairs(rule.spells or {}) do spell[key] = nil end
end

function ns.SetCDMCooldownStateModifier(barKey, spellID, key, enabled, scope)
    if not VALID_MODIFIERS[key] then return false end
    local store, p = EnsureModifierStore()
    if not store then return false end
    enabled = enabled == true
    if scope == "spell" then
        if type(spellID) ~= "number" or spellID <= 0 then return false end
        local rule = EnsureModifierBar(store, barKey)
        local spellKey = tostring(spellID)
        rule.spells[spellKey] = rule.spells[spellKey] or {}
        rule.spells[spellKey][key] = enabled
    elseif scope == "bar_all_specs" then
        local shared = p.cdmCooldownStateModifiersAllSpecs[barKey] or {}
        p.cdmCooldownStateModifiersAllSpecs[barKey] = shared
        shared[key] = enabled
        ClearModifierFromBar(store, barKey, key)
        for _, specProfile in pairs(p.specProfiles or {}) do
            local glows = specProfile and specProfile.barGlows
            ClearModifierFromBar(glows and glows.cooldownStateModifiers, barKey, key)
        end
    else
        local rule = EnsureModifierBar(store, barKey)
        rule.bar[key] = enabled
        for _, spell in pairs(rule.spells) do spell[key] = nil end
    end
    if ns.RefreshCDMUsableVisibility then ns.RefreshCDMUsableVisibility() end
    return true
end

function ns.CDMShouldKeepCooldownColored(barKey, spellID)
    return ns.GetCDMCooldownStateModifiers(barKey, spellID).keep_colored_on_cd == true
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function CleanSpellID(spellID)
    if spellID ~= nil and not IsSecret(spellID)
        and type(spellID) == "number" and spellID > 0 then
        return spellID
    end
end

local function ConfiguredSpellID(icon)
    return icon and CleanSpellID(icon._baseSpellID or icon._cdmBaseSpellID
        or icon._spellID or icon._cdmResolvedSid)
end

local function LiveIconSpellID(icon)
    return icon and CleanSpellID(icon._spellID or icon._cdmResolvedSid
        or icon._baseSpellID or icon._cdmBaseSpellID)
end

local function LiveSpellID(spellID)
    if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
        local ok, override = pcall(C_SpellBook.FindSpellOverrideByID, spellID)
        if ok and type(override) == "number" and override > 0
            and not IsSecret(override) then
            return override
        end
    end
    return spellID
end

local function SpellState(spellID)
    local state = { usable = false, usableIgnoringPower = false, insufficientPower = false, onCooldown = false }
    if type(spellID) ~= "number" or not C_Spell then return state end
    spellID = LiveSpellID(spellID)

    if C_Spell.IsSpellUsable then
        local ok, usable, insufficientPower = pcall(C_Spell.IsSpellUsable, spellID)
        if ok then
            state.usable = not IsSecret(usable) and usable == true
            local lacksPower = not IsSecret(insufficientPower) and insufficientPower == true
            state.insufficientPower = lacksPower
            state.usableIgnoringPower = state.usable or lacksPower
        end
    end

    local isGCD = false
    if C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        local value = ok and info and info.isOnGCD
        isGCD = value ~= nil and not IsSecret(value) and value == true
    end
    local spellDuration, chargeDuration
    if C_Spell.GetSpellCooldownDuration then
        local ok, value = pcall(C_Spell.GetSpellCooldownDuration, spellID)
        if ok then spellDuration = value end
    end
    if C_Spell.GetSpellChargeDuration then
        local ok, value = pcall(C_Spell.GetSpellChargeDuration, spellID)
        if ok then chargeDuration = value end
    end
    if C_Spell.GetSpellCharges then
        local ok, charges = pcall(C_Spell.GetSpellCharges, spellID)
        if ok and charges then
            local current, maximum = charges.currentCharges, charges.maxCharges
            if current ~= nil and not IsSecret(current) and type(current) == "number" then
                state.currentCharges = current
            end
            if maximum ~= nil and not IsSecret(maximum) and type(maximum) == "number" then
                state.maxCharges = maximum
            end
        end
    end
    state.isGCD = isGCD
    state.recharging = chargeDuration ~= nil
    state.isCharge = state.recharging or (state.maxCharges and state.maxCharges > 1) or false
    state.onCooldown = not isGCD and (spellDuration ~= nil or chargeDuration ~= nil)
    return state
end

local function BaseAlpha(icon, barKey)
    if not (ns._nativeCDMFrameData and ns._nativeCDMFrameData[icon]) then
        return 1
    end
    local bar = ns.cdmBarFrames and ns.cdmBarFrames[barKey]
    return bar and bar:IsShown() and (bar:GetAlpha() or 1) or 0
end

local function Editing()
    return KT and (KT._unlockActive or (KT._mainFrame and KT._mainFrame:IsShown()))
end

local function ApplyStateGlow(icon, wanted)
    if not (ns.StartNativeGlow and ns.StopNativeGlow) then return end
    local overlay = icon._kuiStateEffectGlow
    if wanted and not overlay then
        overlay = CreateFrame("Frame", nil, icon)
        overlay:SetAllPoints(icon)
        overlay:SetFrameLevel(icon:GetFrameLevel() + 18)
        overlay:SetAlpha(0)
        overlay:EnableMouse(false)
        overlay._kuiUseSelfGlowTarget = true
        overlay._kuiGlowSource = "cooldown_state_effect"
        icon._kuiStateEffectGlow = overlay
    end
    if wanted and not icon._kuiStateEffectGlowActive then
        local style = ns.CDMGetConfiguredProcGlowStyle and ns.CDMGetConfiguredProcGlowStyle() or "blizzard"
        ns.StartNativeGlow(overlay, style, 1, 0.82, 0.1)
        icon._kuiStateEffectGlowActive = true
    elseif not wanted and overlay and icon._kuiStateEffectGlowActive then
        ns.StopNativeGlow(overlay)
        icon._kuiStateEffectGlowActive = nil
    end
end

local function ApplyModifiers(icon, barKey, modifiers, state)
    local chargesRemain = state.currentCharges and state.currentCharges > 0
    local hideSwipe = (modifiers.suppress_gcd and state.isGCD)
        or (modifiers.hide_swipe_charges and state.recharging and chargesRemain)
    local hideDuration = modifiers.hide_duration_charges and state.recharging and chargesRemain
    icon._kuiStateHideSwipe = hideSwipe or nil
    icon._kuiStateHideDuration = hideDuration or nil
    icon._kuiStateHideChargeText = modifiers.hide_charge_text or nil
    icon._kuiStateHideRechargeEdge = modifiers.hide_recharge_edge or nil

    local cooldown = icon._cooldown or icon.Cooldown
    if cooldown then
        if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(not hideSwipe) end
        if cooldown.SetHideCountdownNumbers then
            local barData = ns.barDataByKey and ns.barDataByKey[barKey]
            cooldown:SetHideCountdownNumbers(hideDuration or not (barData and barData.showCooldownText))
        end
        if modifiers.hide_recharge_edge and cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    end
    if modifiers.hide_charge_text then
        if icon._chargeText then icon._chargeText:Hide() end
        if icon.Applications then icon.Applications:Hide() end
        if icon.ChargeCount then icon.ChargeCount:Hide() end
    end
    if modifiers.keep_colored_on_cd and state.onCooldown and not state.insufficientPower
        and icon._tex and icon._tex.SetDesaturation then
        icon._tex:SetDesaturation(0)
        icon._ktDesatVal = 0
        icon._ktDesatSecret = nil
    end
end

local evaluating = false
function ns.EvaluateCDMUsableVisibility()
    if evaluating then return end
    evaluating = true
    for barKey, icons in pairs(ns.cdmBarIcons or {}) do
        local relayout = false
        for _, icon in ipairs(icons) do
            local configuredID = ConfiguredSpellID(icon)
            local usableID = LiveIconSpellID(icon)
            local mode = configuredID and ns.GetCDMUsableVisibilityMode(barKey, configuredID) or "always"
            local modifiers = configuredID and ns.GetCDMCooldownStateModifiers(barKey, configuredID) or {}
            local state = SpellState(usableID)
            local editing = Editing()
            local hide, lowerAlpha, glow = false, false, false
            if not editing then
                if mode == "lower_alpha_on_cd" then
                    lowerAlpha = state.onCooldown
                elseif mode == "hidden_on_cd" or mode == "hidden_on_cd_shift" then
                    hide = state.onCooldown
                elseif mode == "hidden_cd_ready" or mode == "hidden_cd_ready_shift" then
                    hide = not state.onCooldown
                    if modifiers.stay_hidden_while_charges_remain
                        and state.currentCharges and state.currentCharges > 0 then
                        hide = true
                    end
                elseif mode == "usable" or mode == "usable_shift" then
                    hide = not (state.usableIgnoringPower and not state.onCooldown)
                elseif mode == "glow_cd_ready" then
                    glow = not state.onCooldown
                elseif mode == "glow_on_cd" then
                    glow = state.onCooldown
                elseif mode == "glow_cd_ready_resource" then
                    glow = not state.onCooldown and state.usable
                end
            end
            local shift = hide and SHIFT_MODES[mode] == true
            if icon._kuiUsableShiftHidden ~= shift then
                icon._kuiUsableShiftHidden = shift
                relayout = true
            end
            icon._kuiUsableVisibilityHidden = hide or nil
            icon._kuiUsableVisibilityAlpha = hide and 0 or (lowerAlpha and 0.5 or nil)
            icon:SetAlpha(hide and 0 or (lowerAlpha and 0.5 or BaseAlpha(icon, barKey)))
            ApplyModifiers(icon, barKey, modifiers, state)
            ApplyStateGlow(icon, glow and not hide)
        end
        if relayout and ns.LayoutCDMBar then ns.LayoutCDMBar(barKey) end
    end
    evaluating = false
end

local function HasRules()
    local store, p = EnsureStore()
    if not store then return false end
    for _, rule in pairs(store) do
        if rule.barMode and rule.barMode ~= "always" then return true end
        for _, mode in pairs(rule.spells or {}) do
            if mode ~= "always" then return true end
        end
    end
    for _, mode in pairs(p.cdmUsableVisibilityAllSpecs or {}) do
        if mode ~= "always" then return true end
    end
    local modifiers = p.barGlows and p.barGlows.cooldownStateModifiers
    for _, rule in pairs(modifiers or {}) do
        for _, enabled in pairs(rule.bar or {}) do if enabled then return true end end
        for _, spell in pairs(rule.spells or {}) do
            for _, enabled in pairs(spell) do if enabled then return true end end
        end
    end
    for _, shared in pairs(p.cdmCooldownStateModifiersAllSpecs or {}) do
        for _, enabled in pairs(shared) do if enabled then return true end end
    end
    return false
end

local ticker
local function SyncTicker()
    local needed = HasRules()
    if needed and not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(0.15, ns.EvaluateCDMUsableVisibility)
    elseif not needed and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

function ns.RefreshCDMUsableVisibility()
    SyncTicker()
    ns.EvaluateCDMUsableVisibility()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:RegisterEvent("SPELL_UPDATE_USABLE")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("SPELL_UPDATE_CHARGES")
events:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
events:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
events:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        C_Timer.After(0.5, ns.RefreshCDMUsableVisibility)
    elseif HasRules() then
        C_Timer.After(0, ns.EvaluateCDMUsableVisibility)
    end
end)
