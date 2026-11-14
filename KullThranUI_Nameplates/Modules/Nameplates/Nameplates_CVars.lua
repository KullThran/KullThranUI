-- Nameplates runtime, CVars and click area: a queue of CVar writes applied one frame later and never in combat, the
-- fixed set of nameplate CVars from the profile, the click area of plates, and the once-only hooks on Blizzard's driver.

local _, ns = ...

local module = {}
ns.NameplatesCVars = module

local ctx
local isRetail = false
local driverFrame
local blizzardDriverDone = false

-- Armed means the driver frame is shown. It starts shown.
local armed = true

-- Named CVars, one slot per name. Values are stored and never read here.
local pendingNames = {}

-- Bitfields, in queue order, as parallel lists: a nil value is a real entry, and a known one needs no allocation.
-- Entries up to bitsFlushed have already been written by the flush under way.
local bitFields, bitIndexes, bitValues = {}, {}, {}
local bitCount, bitsFlushed = 0, 0

-- The client caps the distance CVars (Retail takes 60, Classic-era clients
-- less) and a refused value leaves the old, short one in place. The flush
-- steps down from the wanted distance until a value sticks. Retail keeps a
-- separate distance for player plates, 40 by default; clients without it skip it.
-- Forever stores 60 but its engine shows no plate past 45 (measured in game),
-- so Forever asks for 45 and the CVar says what the player sees.
local RETAIL_MAX_DISTANCE, FOREVER_MAX_DISTANCE = 60, 45
local MAX_DISTANCE_STEPS = { 60, 50, 45, 41, 40, 35, 30, 25, 20 }
local DISTANCE_CVARS = { nameplateMaxDistance = true, nameplatePlayerMaxDistance = true }
local wantedDistances = {}

local function queueCVar(name, value)
    if name == nil then return end
    if DISTANCE_CVARS[name] then
        wantedDistances[name] = tonumber(value)
        if not armed then
            armed = true
            driverFrame:Show()
        end
        return
    end
    pendingNames[name] = value
    if not armed then
        armed = true
        driverFrame:Show()
    end
end

local function queueBitfield(field, bitIndex, value)
    if field == nil or bitIndex == nil then return end
    -- G3: a repeat replaces the value in its place and returns before arming.
    for i = bitsFlushed + 1, bitCount do
        if bitFields[i] == field and bitIndexes[i] == bitIndex then
            bitValues[i] = value
            return
        end
    end
    bitCount = bitCount + 1
    bitFields[bitCount] = field
    bitIndexes[bitCount] = bitIndex
    bitValues[bitCount] = value
    if not armed then
        armed = true
        driverFrame:Show()
    end
end

local function flush()
    if InCombatLockdown() then
        driverFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    driverFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")

    -- G9: with no SetCVar the names wait for a later flush, with no new arming.
    local setCVar = SetCVar
    if setCVar then
        local name, value = next(pendingNames)
        while name ~= nil do
            pendingNames[name] = nil
            pcall(setCVar, name, value)
            name, value = next(pendingNames)
        end
        local getCVar = GetCVar
        if getCVar then
            local distanceName, wanted = next(wantedDistances)
            while distanceName ~= nil do
                wantedDistances[distanceName] = nil
                local ok, current = pcall(getCVar, distanceName)
                if ok and current ~= nil then
                    for _, distance in ipairs(MAX_DISTANCE_STEPS) do
                        if distance <= wanted then
                            pcall(setCVar, distanceName, distance)
                            ok, current = pcall(getCVar, distanceName)
                            -- A clamping client may store its own maximum: that is as far as it goes.
                            if ok and tonumber(current) and tonumber(current) >= distance then break end
                        end
                    end
                end
                distanceName, wanted = next(wantedDistances)
            end
        end
    end

    local setBitfield = C_CVar and C_CVar.SetCVarBitfield
    if setBitfield then
        while bitsFlushed < bitCount do
            local i = bitsFlushed + 1
            bitsFlushed = i
            local field, bitIndex, value = bitFields[i], bitIndexes[i], bitValues[i]
            bitFields[i], bitIndexes[i], bitValues[i] = nil, nil, nil
            pcall(setBitfield, field, bitIndex, value)
        end
        bitCount, bitsFlushed = 0, 0
    end
end

local function runDriverFrame(self)
    self:Hide()
    armed = false
    flush()
end

local function onDriverEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        flush()
    end
end

-- The one click area function: the zero-delay timer, ns.ApplyNamePlateClickArea and the options hook all run this.
-- G2: in combat it returns and nothing retries it. G7: it does not re-anchor plates.
local function applyClickArea()
    if InCombatLockdown() then return end

    local saved = KullThranUINameplatesDB or ctx.defaults
    local scaleX = (saved.hitboxScaleX or 100) / 100
    local scaleY = (saved.hitboxScaleY or 100) / 100

    if C_NamePlate and C_NamePlate.SetNamePlateSize then
        C_NamePlate.SetNamePlateSize(ctx.GetHealthBarWidth() * scaleX, ctx.GetHealthBarHeight() * scaleY)
    end

    local setInsets = C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets
    local plateTypes = Enum and Enum.NamePlateType
    if setInsets and plateTypes then
        setInsets(plateTypes.Enemy, -10000, -10000, -10000, -10000)
        setInsets(plateTypes.Friendly, -10000, -10000, -10000, -10000)
    end
end

-- G1: a nil bar ends the walk there.
local function silenceClassBars(driver)
    local bar = driver.classNamePlatePowerBar
    if not bar then return end
    bar:Hide()
    bar:UnregisterAllEvents()

    bar = driver.classNamePlateMechanicFrame
    if not bar then return end
    bar:Hide()
    bar:UnregisterAllEvents()

    bar = driver.classNamePlateAlternatePowerBar
    if not bar then return end
    bar:Hide()
    bar:UnregisterAllEvents()
end

local function onPlateAdded(_, unit)
    if unit == "preview" then return end
    local plate = ctx.GetSafeNamePlateForUnit(unit)
    if plate and unit and ns.IsEnemyNameplateUnit(unit, plate) then
        ns.HideBlizzardFrame(plate, unit)
    end
end

local function queueAuraBitfields()
    if not (C_CVar and C_CVar.SetCVarBitfield and NamePlateConstants and Enum) then return end
    local queueBit = ns.QueueNameplateCVarBitfield

    local field = NamePlateConstants.ENEMY_NPC_AURA_DISPLAY_CVAR
    local bits = Enum.NamePlateEnemyNpcAuraDisplay
    if field ~= nil and bits ~= nil then
        if bits.Debuffs ~= nil then queueBit(field, bits.Debuffs, true) end
        if bits.CrowdControl ~= nil then queueBit(field, bits.CrowdControl, true) end
    end

    field = NamePlateConstants.ENEMY_PLAYER_AURA_DISPLAY_CVAR
    bits = Enum.NamePlateEnemyPlayerAuraDisplay
    if field ~= nil and bits ~= nil then
        if bits.Debuffs ~= nil then queueBit(field, bits.Debuffs, true) end
        if bits.LossOfControl ~= nil then queueBit(field, bits.LossOfControl, true) end
    end
end

local function queueAllCVars()
    local queue = ns.QueueNameplateCVar
    local saved = KullThranUINameplatesDB or ctx.defaults

    queue("nameplateSize", 3)
    queue("nameplateMinScale", 1)
    queue("nameplateMaxScale", 1)
    queue("nameplateSelectedScale", 1)
    queue("nameplateOverlapH", 1)
    queue("nameplateMaxAlpha", 1)
    queue("nameplateMaxAlphaDistance", 40)
    queue("nameplateMinAlpha", 0.6)
    queue("nameplateMinAlphaDistance", -100000)
    local maxDistance = isRetail and RETAIL_MAX_DISTANCE or FOREVER_MAX_DISTANCE
    queue("nameplateMaxDistance", maxDistance)
    queue("nameplatePlayerMaxDistance", maxDistance)
    queue("nameplateTargetBehindMaxDistance", 30)
    -- Forever marks units in plain sight as occluded and drops their plates to 40%:
    -- only the target stayed readable (measured in game). No fade for occlusion there.
    if not isRetail then queue("nameplateOccludedAlphaMult", 1) end
    queue("clampTargetNameplateToScreen", 1)
    queue("ShowClassColorInNameplate", 1)

    -- The one client difference. G6: on Retail the main file always defines the functions.
    local nameOnly, players, npcs
    if isRetail and ns.GetEffectiveFriendlyNameOnly then
        nameOnly = ns.GetEffectiveFriendlyNameOnly(true)
        players = ns.ShouldShowFriendlyNameplates(true)
        npcs = ns.ShouldShowFriendlyNameplates(false)
    else
        if isRetail then
            nameOnly = saved.friendlyPlayerNameOnly
            if nameOnly == nil then nameOnly = saved.friendlyNameOnly ~= false end
        else
            nameOnly = saved.friendlyPlayerNameOnly ~= false
        end
        players = saved.showFriendlyPlayers ~= false
        npcs = saved.showFriendlyNPCs == true
    end

    local playersValue = players and 1 or 0
    local npcsValue = npcs and 1 or 0
    local classColorValue = saved.classColorFriendly ~= false and 1 or 0

    queue("nameplateShowOnlyNameForFriendlyPlayerUnits", nameOnly and 1 or 0)
    queue("nameplateShowFriendlyPlayers", playersValue)
    queue("nameplateShowFriends", playersValue)
    queue("UnitNameFriendlyPlayerName", (players or saved.friendlyShowDefaultNames == true) and 1 or 0)
    -- G4: both spellings, always the same value. The wrong one raises inside the flush's protected call.
    queue("nameplateShowFriendlyNPCs", npcsValue)
    queue("nameplateShowFriendlyNpcs", npcsValue)
    queue("UnitNameFriendlySpecialNPCName", npcsValue)
    queue("ShowClassColorInFriendlyNameplate", classColorValue)
    queue("nameplateUseClassColorForFriendlyPlayerUnitNames", classColorValue)
    queue("nameplateShowEnemyPets", saved.showEnemyPets == true and 1 or 0)

    local showAll = saved.nameplateShowAll
    if showAll ~= nil then
        queue("nameplateShowAll", showAll and 1 or 0)
    else
        local current = tonumber(GetCVar("nameplateShowAll") or 0)
        if current then queue("nameplateShowAll", current) end
    end

    queue("nameplateOverlapV", saved.nameplateOverlapV or ctx.defaults.nameplateOverlapV)
end

-- Taint-sensitive: exact order, hooks only, once. G5: nothing is undone. G8: no lockdown test.
local function installBlizzardDriverWork()
    if blizzardDriverDone then return end
    local driver = NamePlateDriverFrame
    if not driver then return end
    blizzardDriverDone = true

    driver:UnregisterEvent("DISPLAY_SIZE_CHANGED")
    driver:UnregisterEvent("CVAR_UPDATE")
    hooksecurefunc(driver, "UpdateNamePlateOptions", applyClickArea)
    if driver.SetupClassNameplateBars then
        hooksecurefunc(driver, "SetupClassNameplateBars", silenceClassBars)
    end
    hooksecurefunc(driver, "OnNamePlateAdded", onPlateAdded)
end

local function applyAll()
    queueAuraBitfields()
    queueAllCVars()
    ns.RefreshStackingMotion()
    C_Timer.After(0, applyClickArea)
    installBlizzardDriverWork()
    ns.ApplyNamePlateClickArea = applyClickArea
end

function module.Setup(setupCtx)
    if type(setupCtx) ~= "table" then
        error("NameplatesCVars.Setup: ctx required", 2)
    end
    if setupCtx.client ~= "retail" and setupCtx.client ~= "forever" then
        error("NameplatesCVars.Setup: client must be retail or forever", 2)
    end
    ctx = setupCtx
    isRetail = setupCtx.client == "retail"

    driverFrame = CreateFrame("Frame")
    driverFrame:SetScript("OnEvent", onDriverEvent)
    driverFrame:SetScript("OnUpdate", runDriverFrame)

    ns.QueueNameplateCVar = queueCVar
    ns.QueueNameplateCVarBitfield = queueBitfield
    module.ApplyAll = applyAll
end
