-- Modules/DragonRiding/DragonRiding.lua (moved from Modules/DragonRiding.lua)
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule('DragonRiding', 'AceEvent-3.0', 'AceHook-3.0', 'AceTimer-3.0')
local LSM = LibStub("LibSharedMedia-3.0")

local function LText(text)
    local L = KT and KT.GetLocale and KT:GetLocale()
    return (L and L[text]) or text
end

-- ============================================================================
-- CONSTANTES
-- ============================================================================

local DRAGONRIDING_SPELL_IDS = {
    Vigor            = 372608,
    ThrillOfTheSkies = 377234,
    GroundSkimming   = 375585,
    SkywardAscent    = 372610,
    WhirlingSurge    = 361584,
    BronzeTimelock   = 403092,
    SecondWind       = 425782,
    LightningRush    = 418592,
    Soar             = 369536,
    SoarLegacy       = 381322,
}

local DRUID_FLIGHT_FORM_SPELL_IDS = {
    [783] = true,   -- Travel Form
    [33943] = true, -- Flight Form
    [40120] = true, -- Swift Flight Form
}

local COLORS = {
    Base     = {1, 0.2, 0.2, 1},        -- Rojo
    Thrill   = {0.2, 0.65, 0.88, 1},    -- Azul
    Skim     = {0.54, 0.28, 0.8, 1},    -- Morado
    Ascent   = {0.17, 0.69, 0.22, 1},   -- Verde
    Recharge = {1, 1, 1, 1},            -- Blanco
    Background = {0, 0, 0, 0.6},
}

-- Variables
local frame, speedBar, secondWindBar
local spellContainer = {}
local isSkyriding = false
local maxSpeed = 85
local UPDATE_THROTTLE = 0.07
local SPEED_EPSILON = 0.25
local ALT_MOUNT_POWER_TYPE = (Enum and Enum.PowerType and Enum.PowerType.AlternateMount) or 29
local VIGOR_PIP_COUNT = 6
local VIGOR_PIP_GAP = 4
local lastDisplayedVigor = VIGOR_PIP_COUNT
local lastKnownHasVigor = false
local soarCastGraceUntil = 0
local cachedAuras = {
    ascent = false,
    thrill = false,
    skim = false,
    soar = false,
}

-- Para restaurar el widget de Blizzard al desactivar
local blizzOriginalParent = nil

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================

function Mod:OnInitialize()
    if not KT.db.profile.dragonRiding then
        KT.db.profile.dragonRiding = {
            enable = true,
            width = 250,
            height = 16,
            yOffset = -150,
            xOffset = 0,
            showSpeedText = true,
            texture = "Melli",
            font = "AAA_ITC_Avant_Garde",
        }
    end
    self.db = KT.db.profile.dragonRiding
    
    -- [FIX] Migration for default position (Center -> Top)
    -- Resetear si el valor es positivo (se saldría de la pantalla por arriba con el anclaje TOP)
    if self.db.yOffset > 0 or self.db.yOffset == -250 then
        self.db.yOffset = -150
    end
    
    -- [FIX] Ensure defaults for texture/font
    if not self.db.texture then self.db.texture = "Melli" end
    if not self.db.font then self.db.font = "AAA_ITC_Avant_Garde" end

end

local function CreateStyledBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    local chosen = Mod.db.texture or "Melli"
    local texture
    -- Hard fallback for built-in KullThranUI textures to prevent "missing/transparent" bars
    -- if LibSharedMedia registration is wrong or the user is missing that media key.
    if chosen == "Melli" then
        texture = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
    elseif chosen == "Melli Dark" then
        texture = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"
    else
        texture = (LSM and LSM.Fetch and LSM:Fetch("statusbar", chosen)) or nil
    end
    if not texture or texture == "" then
        texture = "Interface\\Buttons\\WHITE8x8"
    end
    bar:SetStatusBarTexture(texture)
     
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(texture)
    bg:SetVertexColor(unpack(COLORS.Background))
    
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
    border:SetBackdropBorderColor(0, 0, 0, 1)

    return bar
end

local function ApplySafeFramePosition()
    if not frame or not Mod or not Mod.db then
        return
    end

    local uiWidth = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1920
    local uiHeight = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 1080
    local x = tonumber(Mod.db.xOffset) or 0
    local y = tonumber(Mod.db.yOffset) or -150
    local minX = -math.max(0, math.floor(uiWidth / 2) - 120)
    local maxX = math.max(0, math.floor(uiWidth / 2) - 120)
    local minY = -math.max(120, uiHeight - 120)
    local maxY = -20

    if x < minX or x > maxX then
        x = 0
    end
    if y < minY or y > maxY then
        y = -150
    end

    if Mod.db.xOffset ~= x then
        Mod.db.xOffset = x
    end
    if Mod.db.yOffset ~= y then
        Mod.db.yOffset = y
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", x, y)
end

local function GetSpellChargesCompat(spellID)
    if C_Spell and C_Spell.GetSpellCharges then
        local ok, chargeInfo = pcall(C_Spell.GetSpellCharges, spellID)
        if ok and type(chargeInfo) == "table" then
            return tonumber(chargeInfo.currentCharges or chargeInfo.charges),
                tonumber(chargeInfo.maxCharges),
                tonumber(chargeInfo.cooldownStartTime or chargeInfo.chargeStartTime or chargeInfo.startTime),
                tonumber(chargeInfo.cooldownDuration or chargeInfo.chargeDuration or chargeInfo.duration),
                tonumber(chargeInfo.chargeModRate or chargeInfo.modRate) or 1
        end
    end

    if GetSpellCharges then
        local currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = GetSpellCharges(spellID)
        return tonumber(currentCharges), tonumber(maxCharges), tonumber(cooldownStartTime), tonumber(cooldownDuration),
            tonumber(chargeModRate) or 1
    end
end

local function GetSpellNameCompat(spellID)
    if not spellID then
        return nil
    end

    if C_Spell and C_Spell.GetSpellName then
        local ok, spellName = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(spellName) == "string" and spellName ~= "" then
            return spellName
        end
    end

    if GetSpellInfo then
        local spellName = GetSpellInfo(spellID)
        if type(spellName) == "string" and spellName ~= "" then
            return spellName
        end
    end

    return nil
end

local function IsSoarSpellID(spellID)
    if not spellID then
        return false
    end

    if spellID == DRAGONRIDING_SPELL_IDS.Soar or spellID == DRAGONRIDING_SPELL_IDS.SoarLegacy then
        return true
    end

    if C_Spell and C_Spell.GetOverrideSpell then
        local okPrimary, primaryOverride = pcall(C_Spell.GetOverrideSpell, DRAGONRIDING_SPELL_IDS.Soar)
        if okPrimary and primaryOverride and spellID == primaryOverride then
            return true
        end

        local okLegacy, legacyOverride = pcall(C_Spell.GetOverrideSpell, DRAGONRIDING_SPELL_IDS.SoarLegacy)
        if okLegacy and legacyOverride and spellID == legacyOverride then
            return true
        end
    end

    local spellName = GetSpellNameCompat(spellID)
    if not spellName then
        return false
    end

    return spellName == GetSpellNameCompat(DRAGONRIDING_SPELL_IDS.Soar)
        or spellName == GetSpellNameCompat(DRAGONRIDING_SPELL_IDS.SoarLegacy)
end

local function MarkRecentSoarCast()
    local now = GetTime and GetTime() or 0
    soarCastGraceUntil = math.max(soarCastGraceUntil or 0, now + 4)
end

local function HasRecentSoarCast()
    if not GetTime then
        return false
    end

    return (soarCastGraceUntil or 0) > GetTime()
end

local function GetVigorChargeInfo()
    local currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate =
        GetSpellChargesCompat(DRAGONRIDING_SPELL_IDS.Vigor)

    if not maxCharges or maxCharges <= 0 then
        return nil
    end

    currentCharges = math.max(0, math.min(maxCharges, currentCharges or 0))
    cooldownStartTime = tonumber(cooldownStartTime) or 0
    cooldownDuration = tonumber(cooldownDuration) or 0
    chargeModRate = tonumber(chargeModRate) or 1

    return currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate
end

local function GetDisplayedVigor()
    if Mod and Mod.isPreviewing then
        lastDisplayedVigor = VIGOR_PIP_COUNT
        return VIGOR_PIP_COUNT
    end

    local currentCharges, maxCharges = GetVigorChargeInfo()
    if maxCharges and maxCharges > 0 then
        local clamped = math.min(VIGOR_PIP_COUNT, math.max(0, currentCharges or 0))
        lastDisplayedVigor = clamped
        return clamped
    end

    return lastDisplayedVigor or 0
end

local function LayoutVigorBar()
    if not secondWindBar or not secondWindBar.Charges or not speedBar then
        return
    end

    local totalWidth = math.min(Mod.db.width or 250, 180)
    local pipWidth = math.max(16, math.floor((totalWidth - (VIGOR_PIP_GAP * (VIGOR_PIP_COUNT - 1))) / VIGOR_PIP_COUNT))
    local totalBarWidth = (pipWidth * VIGOR_PIP_COUNT) + (VIGOR_PIP_GAP * (VIGOR_PIP_COUNT - 1))

    secondWindBar:SetSize(totalBarWidth, 6)
    secondWindBar:ClearAllPoints()
    secondWindBar:SetPoint("TOP", speedBar, "BOTTOM", 0, -8)

    for i, bar in ipairs(secondWindBar.Charges) do
        bar:SetSize(pipWidth, 6)
        bar:ClearAllPoints()
        if i == 1 then
            bar:SetPoint("LEFT", secondWindBar, "LEFT", 0, 0)
        else
            bar:SetPoint("LEFT", secondWindBar.Charges[i - 1], "RIGHT", VIGOR_PIP_GAP, 0)
        end
    end
end

local function ApplyCooldownFont(cooldown)
    if not cooldown or not cooldown.GetNumRegions then
        return
    end

    local desiredFontKey = Mod.db and Mod.db.font or "AAA_ITC_Avant_Garde"
    if cooldown.KT_StyledFontKey == desiredFontKey and cooldown.KT_FontRegions then
        return
    end

    if not cooldown.KT_FontRegions then
        cooldown.KT_FontRegions = {}
        for j = 1, cooldown:GetNumRegions() do
            local region = select(j, cooldown:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("FontString") then
                cooldown.KT_FontRegions[#cooldown.KT_FontRegions + 1] = region
            end
        end
    end

    local fontPath = (LSM and LSM.Fetch and LSM:Fetch("font", desiredFontKey)) or "Fonts\\FRIZQT__.TTF"
    for _, region in ipairs(cooldown.KT_FontRegions) do
        region:SetFont(fontPath, 16, "OUTLINE")
    end

    cooldown.KT_StyledFontKey = desiredFontKey
end

function Mod:RegisterUnlockElement()
    if self.unlockElementRegistered or not KT or not KT.RegisterUnlockElement or not frame then
        return
    end

    KT.RegisterUnlockElement("dragonriding_frame", {
        label = "Dragon Riding",
        group = "Dragon Riding",
        order = 10,
        getFrame = function()
            return frame
        end,
        getSize = function()
            local width = frame and frame.GetWidth and frame:GetWidth() or (Mod.db and Mod.db.width) or 250
            local height = frame and frame.GetHeight and frame:GetHeight() or math.max(60, ((Mod.db and Mod.db.height) or 16) + 36)
            return math.max(width, 180), math.max(height, 40)
        end,
        getRect = function()
            if not (frame and frame.GetLeft and frame.GetTop and frame:GetLeft() and frame:GetTop()) then
                return nil
            end

            local uiScale = UIParent:GetEffectiveScale()
            local frameScale = frame:GetEffectiveScale()
            local left = frame:GetLeft() * frameScale / uiScale
            local top = frame:GetTop() * frameScale / uiScale
            local width = frame:GetWidth() * frameScale / uiScale
            local height = frame:GetHeight() * frameScale / uiScale
            return left, top, math.max(width, 180), math.max(height, 40)
        end,
        loadPosition = function()
            return {
                point = "TOP",
                relativePoint = "TOP",
                x = (Mod.db and Mod.db.xOffset) or 0,
                y = (Mod.db and Mod.db.yOffset) or -150,
            }
        end,
        translateMoverPosition = function(_, pos)
            local frameWidth = frame and frame:GetWidth() or (Mod.db and Mod.db.width) or 250
            return {
                point = "TOP",
                relativePoint = "TOP",
                x = (pos.x or 0) + (frameWidth * 0.5) - (UIParent:GetWidth() * 0.5),
                y = pos.y or -150,
                scale = pos.scale,
            }
        end,
        applyPendingPosition = function(_, pos)
            if not (frame and Mod.db and pos) then return end
            Mod.db.xOffset = pos.x or 0
            Mod.db.yOffset = pos.y or -150
            frame:ClearAllPoints()
            frame:SetPoint("TOP", UIParent, "TOP", Mod.db.xOffset, Mod.db.yOffset)
        end,
        savePosition = function(_, point, relativePoint, x, y)
            if not Mod.db then
                return
            end

            -- Unlock mode stores this mover relative to the top of UIParent, which
            -- matches the module's existing xOffset/yOffset placement model.
            Mod.db.xOffset = x or 0
            Mod.db.yOffset = y or -150
            frame:ClearAllPoints()
            frame:SetPoint("TOP", UIParent, "TOP", Mod.db.xOffset, Mod.db.yOffset)
        end,
        applyPosition = function()
            if not (frame and Mod.db) then
                return
            end
            frame:ClearAllPoints()
            frame:SetPoint("TOP", UIParent, "TOP", Mod.db.xOffset or 0, Mod.db.yOffset or -150)
        end,
    })

    self.unlockElementRegistered = true
end

-- ============================================================================
-- UI: BARRA DE VELOCIDAD + COOLDOWNS
-- ============================================================================

function Mod:BuildUI()
    if frame then return end

    -- MARCO PRINCIPAL (Padre de todo)
    frame = CreateFrame("Frame", "KT_DragonRidingFrame", UIParent)
    frame:SetSize(self.db.width, math.max(60, self.db.height + 36))
    frame:SetParent(UIParent)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(20)
    ApplySafeFramePosition()
    frame:Hide()

    -- 1. BARRA VELOCIDAD
    speedBar = CreateStyledBar(frame, self.db.width, self.db.height)
    speedBar:SetPoint("TOP", frame, "TOP", 0, 0)
    speedBar:SetMinMaxValues(0, 100)
    
    speedBar.Text = speedBar:CreateFontString(nil, "OVERLAY")
    speedBar.Text:SetPoint("CENTER", speedBar, "CENTER", 0, 0)
    speedBar.Text:SetShadowOffset(1, -1)
    local font = LSM:Fetch("font", self.db.font or "AAA_ITC_Avant_Garde") or "Fonts\\FRIZQT__.TTF"
    speedBar.Text:SetFont(font, 16, "OUTLINE")

    local spark = speedBar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetSize(20, self.db.height * 2.2)
    spark:SetPoint("CENTER", speedBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    spark:SetAlpha(0.8)
    speedBar.Spark = spark

    -- 2. VIGOR (6 cargas debajo)
    secondWindBar = CreateFrame("Frame", nil, frame)
    secondWindBar.Charges = {}

    for i = 1, VIGOR_PIP_COUNT do
        local sw = CreateStyledBar(secondWindBar, 24, 6)
        sw:SetStatusBarColor(unpack(COLORS.Recharge))
        sw:SetMinMaxValues(0, 1)
        sw:SetValue(1)
        sw:Hide()
        tinsert(secondWindBar.Charges, sw)
    end
    LayoutVigorBar()

    -- 3. ICONOS (Laterales)
    local spellList = {DRAGONRIDING_SPELL_IDS.WhirlingSurge, DRAGONRIDING_SPELL_IDS.BronzeTimelock}
    local iconSize = self.db.height + 16
    
    for i, spellID in ipairs(spellList) do
        local sFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        sFrame:SetSize(iconSize, iconSize)
        sFrame:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
        sFrame:SetBackdropBorderColor(0, 0, 0, 1)

        if i == 1 then
            sFrame:SetPoint("RIGHT", speedBar, "LEFT", -6, 0)
        else
            sFrame:SetPoint("LEFT", speedBar, "RIGHT", 6, 0)
        end

        local icon = sFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(C_Spell.GetSpellTexture(spellID))
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        local cd = CreateFrame("Cooldown", nil, sFrame, "CooldownFrameTemplate")
        cd:SetAllPoints()
        cd:SetDrawEdge(false)
        cd:SetSwipeColor(0, 0, 0, 0.8)
        
        -- [FIX] Change font to Avant Garde (cache regions; avoid scanning every SetCooldown)
        ApplyCooldownFont(cd)
        hooksecurefunc(cd, "SetCooldown", ApplyCooldownFont)
        cd:HookScript("OnShow", ApplyCooldownFont)
        
        sFrame.Icon = icon
        sFrame.Cooldown = cd
        sFrame.SpellID = spellID
        tinsert(spellContainer, sFrame)
    end

    -- Register with EditMode
    local EM = KT:GetModule("EditMode", true)
    if EM then
        EM:RegisterFrame(frame, LText("Dragon Riding"), "dragon_riding", {
            resizable = false,
            onEnter = function() 
                Mod:ToggleState(true)
            end,
            onExit = function() Mod:CheckMountState() end
        })
    end

    self:RegisterUnlockElement()
end

-- ============================================================================
-- MANIPULACIÓN DEL WIDGET DE BLIZZARD (VIGOR)
-- ============================================================================

local function UpdateBlizzardWidget()
    local container = _G.UIWidgetPowerBarContainerFrame
    if not container then return end
    if not blizzOriginalParent then
        blizzOriginalParent = container:GetParent()
    end

    if isSkyriding then
        -- 1. Secuestrar el contenedor de Blizzard
        if container:GetParent() ~= frame and not blizzOriginalParent then
            blizzOriginalParent = container:GetParent()
        end

        if blizzOriginalParent and container:GetParent() ~= blizzOriginalParent then
            container:SetParent(blizzOriginalParent)
        end
        container:SetAlpha(0)

        -- [FIX] Forzar visibilidad en TODOS los widgets del contenedor (sin depender del ID)
        -- Esto asegura que los círculos de vigor se vean siempre.
    else
        -- Restaurar a Blizzard si dejamos de volar
        if blizzOriginalParent and container:GetParent() ~= blizzOriginalParent then
            container:SetParent(blizzOriginalParent)
            container:SetPoint("TOP", _G.UIParent, "TOP", 0, -100) -- Posición aproximada predeterminada o dejar que la UI lo gestione
        end
    end
end

-- ============================================================================
-- LÓGICA DE ACTUALIZACIÓN
-- ============================================================================

local function UpdateSpeedBarColor(isGliding)
    if not isGliding then
        speedBar:SetStatusBarColor(unpack(COLORS.Base))
        return
    end

    if cachedAuras.ascent then
        speedBar:SetStatusBarColor(unpack(COLORS.Ascent))
    elseif cachedAuras.thrill then
        speedBar:SetStatusBarColor(unpack(COLORS.Thrill))
    elseif cachedAuras.skim then
        speedBar:SetStatusBarColor(unpack(COLORS.Skim))
    else
        speedBar:SetStatusBarColor(unpack(COLORS.Base))
    end
end

local function HasPlayerAuraBySpellID(spellID)
    if not spellID then
        return false
    end

    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok then
            return aura ~= nil
        end
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then
                break
            end
            if aura.spellId == spellID then
                return true
            end
        end
    end

    return false
end

function Mod:UpdateAuras()
    cachedAuras.ascent = HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.SkywardAscent)
    cachedAuras.thrill = HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.ThrillOfTheSkies)
    cachedAuras.skim = HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.GroundSkimming)
    cachedAuras.soar = HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.Soar) or HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.SoarLegacy)

    if frame and frame.KT_LastIsGliding ~= nil and speedBar then
        UpdateSpeedBarColor(frame.KT_LastIsGliding)
    end
end

local function UpdateSecondWind()
    if not secondWindBar or not secondWindBar.Charges then
        return
    end

    if Mod.isPreviewing then
        for i = 1, VIGOR_PIP_COUNT do
            local bar = secondWindBar.Charges[i]
            if bar then
                bar:Show()
                bar:SetMinMaxValues(0, 1)
                if i <= 4 then
                    bar:SetValue(1)
                    bar:SetAlpha(1)
                    bar:SetStatusBarColor(unpack(COLORS.Recharge))
                elseif i == 5 then
                    bar:SetValue(0.6)
                    bar:SetAlpha(1)
                    bar:SetStatusBarColor(unpack(COLORS.Recharge))
                else
                    bar:SetValue(0)
                    bar:SetAlpha(0.35)
                    bar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
                end
            end
        end
        return
    end

    local currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = GetVigorChargeInfo()
    if not maxCharges or maxCharges <= 0 then
        maxCharges = VIGOR_PIP_COUNT
        currentCharges = GetDisplayedVigor()
        cooldownStartTime = 0
        cooldownDuration = 0
        chargeModRate = 1
    end

    local effectiveDuration = cooldownDuration
    if effectiveDuration and effectiveDuration > 0 and chargeModRate and chargeModRate > 0 then
        effectiveDuration = effectiveDuration / chargeModRate
    end

    local chargeProgress = 0
    if effectiveDuration and effectiveDuration > 0 and cooldownStartTime and cooldownStartTime > 0 then
        chargeProgress = math.max(0, math.min(1, (GetTime() - cooldownStartTime) / effectiveDuration))
    end

    for i = 1, VIGOR_PIP_COUNT do
        local bar = secondWindBar.Charges[i]
        if bar then
            bar:Show()
            bar:SetMinMaxValues(0, 1)

            if i <= currentCharges then
                bar:SetValue(1)
                bar:SetAlpha(1)
                bar:SetStatusBarColor(unpack(COLORS.Recharge))
            elseif i == (currentCharges + 1) and effectiveDuration and effectiveDuration > 0 then
                bar:SetValue(chargeProgress)
                bar:SetAlpha(1)
                bar:SetStatusBarColor(unpack(COLORS.Recharge))
            else
                bar:SetValue(0)
                bar:SetAlpha(0.35)
                bar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
            end
        end
    end
end

local function UpdateCooldowns()
    for _, sFrame in ipairs(spellContainer) do
        local info = C_Spell.GetSpellCooldown(sFrame.SpellID)
        if info then
            sFrame.Cooldown:SetCooldown(info.startTime, info.duration)
            if info.duration > 0 then
                sFrame.Icon:SetDesaturated(true)
                sFrame.Icon:SetVertexColor(0.6, 0.6, 0.6)
            else
                sFrame.Icon:SetDesaturated(false)
                sFrame.Icon:SetVertexColor(1, 1, 1)
            end
        end
    end
end

local function HasVisibleBlizzardVigorWidget()
    local container = _G.UIWidgetPowerBarContainerFrame
    if not container or not container.IsShown or not container:IsShown() then
        return false
    end

    local ok, children = pcall(function()
        return { container:GetChildren() }
    end)
    if not ok or not children then
        return false
    end

    for _, child in ipairs(children) do
        if child and child.IsShown and child:IsShown() then
            local width = child.GetWidth and child:GetWidth() or 0
            local height = child.GetHeight and child:GetHeight() or 0
            if width > 0 and height > 0 then
                return true
            end
        end
    end

    return false
end

local function HasActiveAdvancedFlightResource(powerType, hasAltMountPower, hasVisibleVigorWidget, nativeDragonriding)
    return nativeDragonriding
        or powerType == ALT_MOUNT_POWER_TYPE
        or hasAltMountPower
        or hasVisibleVigorWidget
end

local function HasDynamicFlightPowerBar()
    local powerBarID = UnitPowerBarID and UnitPowerBarID("player") or 0
    return powerBarID ~= nil and powerBarID ~= 0 and powerBarID ~= 650
end

local function IsBlizzardSkyridingState(canGlide)
    if GetBonusBarIndex and GetBonusBarOffset and GetBonusBarIndex() == 11 and GetBonusBarOffset() == 5 then
        return true
    end

    local powerBarID = UnitPowerBarID and UnitPowerBarID("player") or 0
    if powerBarID == 650 then
        return false
    end

    return canGlide and powerBarID ~= 0
end

local function IsFlyableContext()
    -- When available, the advanced-flight API is authoritative. Falling back
    -- to IsFlyableArea after it returns false incorrectly treats places that
    -- permit steady flight but disable Skyriding as valid Dragon Riding areas.
    if type(IsAdvancedFlyableArea) == "function" then
        local ok, canUseAdvancedFlight = pcall(IsAdvancedFlyableArea)
        if ok then
            return canUseAdvancedFlight == true
        end
    end

    if type(IsFlyableArea) == "function" then
        local ok, canFly = pcall(IsFlyableArea)
        return ok and canFly == true
    end

    return false
end

local function IsDruidFlightCapableForm()
    local _, classToken = UnitClass("player")
    if classToken ~= "DRUID" then
        return false
    end

    if not GetShapeshiftForm then
        return false
    end

    local formIndex = GetShapeshiftForm()
    if not formIndex or formIndex == 0 then
        return false
    end

    if GetShapeshiftFormInfo then
        local _, _, _, spellID = GetShapeshiftFormInfo(formIndex)
        if spellID and DRUID_FLIGHT_FORM_SPELL_IDS[spellID] then
            return true
        end
    end

    return formIndex == 3
end

local function IsPlayerAirborne(isGliding)
    if isGliding then
        return true
    end

    return IsFlying and IsFlying() or false
end

local IsNativeDragonridingState

local function GetDragonRidingState()
    local isGliding, canGlide = C_PlayerInfo.GetGlidingInfo()
    local powerType = UnitPowerType("player")
    local powerBarID = UnitPowerBarID and UnitPowerBarID("player") or 0
    local hasDynamicPowerBar = powerBarID ~= 0 and powerBarID ~= 650
    local altMountPowerMax = UnitPowerMax("player", ALT_MOUNT_POWER_TYPE) or 0
    local _, maxVigor = GetVigorChargeInfo()
    local hasVigor = (maxVigor or 0) > 0
    local hasAltMountPower = altMountPowerMax > 0
    local hasVisibleVigorWidget = HasVisibleBlizzardVigorWidget()
    local nativeDragonriding = IsNativeDragonridingState()
    local bonusBarIndex = GetBonusBarIndex and GetBonusBarIndex() or 0
    local bonusBarOffset = GetBonusBarOffset and GetBonusBarOffset() or 0
    local isMounted = IsMounted()
    local _, classToken = UnitClass("player")
    local formIndex = GetShapeshiftForm and GetShapeshiftForm() or 0
    local formSpellID = nil
    local flyable = IsFlyableContext()
    local soarAura = false
    local soarRecent = false
    local druidFlightForm = false
    local airborne = IsPlayerAirborne(isGliding)
    local reasons = {}
    local hasBonusBarSkyriding = bonusBarIndex == 11 and bonusBarOffset == 5

    if formIndex and formIndex > 0 and GetShapeshiftFormInfo then
        local _, _, _, spellID = GetShapeshiftFormInfo(formIndex)
        formSpellID = spellID
    end

    if classToken == "EVOKER" then
        soarAura = cachedAuras.soar
            or HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.Soar)
            or HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.SoarLegacy)
        soarRecent = HasRecentSoarCast()
    elseif classToken == "DRUID" then
        druidFlightForm = IsDruidFlightCapableForm()
    end

    if hasBonusBarSkyriding then reasons[#reasons + 1] = "bonusBar" end
    if canGlide and hasDynamicPowerBar then reasons[#reasons + 1] = "dynamicPowerBar" end
    if isGliding then reasons[#reasons + 1] = "gliding" end
    if nativeDragonriding then reasons[#reasons + 1] = "native" end
    if isMounted and powerType == ALT_MOUNT_POWER_TYPE then reasons[#reasons + 1] = "mountedAltPowerType" end
    if isMounted and hasAltMountPower then reasons[#reasons + 1] = "mountedAltPowerMax" end
    if isMounted and hasVisibleVigorWidget then reasons[#reasons + 1] = "mountedWidget" end

    local shouldShow = #reasons > 0

    if not shouldShow and classToken == "EVOKER" and (soarRecent or soarAura) then
        shouldShow = true
        reasons[#reasons + 1] = soarRecent and "soarRecent" or "soarAura"
    end

    if not shouldShow and classToken == "DRUID" and druidFlightForm and (airborne or nativeDragonriding or hasDynamicPowerBar or (canGlide and (hasAltMountPower or hasVisibleVigorWidget or hasVigor))) then
        shouldShow = true
        reasons[#reasons + 1] = "druidFlightForm"
    end

    -- A flying-capable mount can retain its Skyriding resources and native
    -- state while grounded in an indoor or otherwise non-flyable area. Both
    -- the area's permission and Blizzard's live canGlide state must confirm
    -- that advanced flight is currently usable.
    local blockedByNonFlyableMountedContext = isMounted and (not flyable or not canGlide)
    if blockedByNonFlyableMountedContext then
        shouldShow = false
        reasons = { "nonFlyableMountedContext" }
    end

    return {
        shouldShow = shouldShow,
        isGliding = isGliding,
        canGlide = canGlide,
        powerType = powerType,
        powerBarID = powerBarID,
        hasDynamicPowerBar = hasDynamicPowerBar,
        altMountPowerMax = altMountPowerMax,
        hasVigor = hasVigor,
        hasAltMountPower = hasAltMountPower,
        hasVisibleVigorWidget = hasVisibleVigorWidget,
        nativeDragonriding = nativeDragonriding,
        bonusBarIndex = bonusBarIndex,
        bonusBarOffset = bonusBarOffset,
        hasBonusBarSkyriding = hasBonusBarSkyriding,
        isMounted = isMounted,
        classToken = classToken,
        formIndex = formIndex,
        formSpellID = formSpellID,
        soarAura = soarAura,
        soarRecent = soarRecent,
        flyable = flyable,
        druidFlightForm = druidFlightForm,
        airborne = airborne,
        blockedByNonFlyableMountedContext = blockedByNonFlyableMountedContext,
        reasons = reasons,
    }
end

local function ShouldShowDragonRidingBar()
    local state = GetDragonRidingState()
    return state.shouldShow, state.isGliding, state.canGlide, state.hasVigor
end

IsNativeDragonridingState = function()
    if C_PlayerInfo and C_PlayerInfo.IsPlayerInDragonriding then
        local ok, result = pcall(C_PlayerInfo.IsPlayerInDragonriding)
        if ok and result then
            return true
        end
    end

    if C_MountJournal and C_MountJournal.IsDragonriding then
        local ok, result = pcall(C_MountJournal.IsDragonriding)
        if ok and result then
            return true
        end
    end

    return false
end

local function IsEvokerDracthyrForm()
    local _, classToken = UnitClass("player")
    if classToken ~= "EVOKER" then
        return false
    end

    if C_PlayerInfo and C_PlayerInfo.GetAlternateFormInfo then
        local ok, hasAlternateForm, inAlternateForm = pcall(C_PlayerInfo.GetAlternateFormInfo)
        if ok and hasAlternateForm then
            return not inAlternateForm
        end
    end

    return true
end

local function IsEvokerSoaringState(isGliding, canGlide, hasAdvancedFlightResource)
    local _, classToken = UnitClass("player")
    if classToken ~= "EVOKER" then
        return false
    end

    if HasRecentSoarCast() then
        return true
    end

    if cachedAuras.soar or HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.Soar) or HasPlayerAuraBySpellID(DRAGONRIDING_SPELL_IDS.SoarLegacy) then
        return true
    end

    if isGliding or IsBlizzardSkyridingState(canGlide) or hasAdvancedFlightResource then
        return true
    end

    if IsFlying and IsFlying() and C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(DRAGONRIDING_SPELL_IDS.Soar)
        if info and tonumber(info.duration or 0) > 0 then
            return true
        end
    end

    return false
end

local function IsUnmountedAdvancedFlightState(classToken, isMounted, isGliding, canGlide, hasAdvancedFlightResource, hasVigor)
    if isMounted then
        return false
    end

    if classToken ~= "DRUID" and classToken ~= "EVOKER" then
        return false
    end

    if classToken == "EVOKER" and IsEvokerSoaringState(isGliding, canGlide, hasAdvancedFlightResource) then
        return true
    end

    if classToken == "EVOKER" and not IsEvokerDracthyrForm() then
        return false
    end

    if classToken == "DRUID" and IsDruidFlightCapableForm() then
        if IsBlizzardSkyridingState(canGlide) or hasAdvancedFlightResource or hasVigor then
            return true
        end

        if IsFlyableContext() or IsPlayerAirborne(isGliding) then
            return true
        end
    end

    if IsBlizzardSkyridingState(canGlide) then
        return true
    end

    if not IsPlayerAirborne(isGliding) then
        return false
    end

    return isGliding
        or canGlide
        or hasAdvancedFlightResource
        or hasVigor
end

local function UpdateLoop(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < UPDATE_THROTTLE then return end
    self.elapsed = 0

    local shouldShow, isGliding, canGlide = ShouldShowDragonRidingBar()
    local _, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
    if self.KT_LastIsGliding ~= isGliding then
        self.KT_LastIsGliding = isGliding
        UpdateSpeedBarColor(isGliding)
    end

    if not shouldShow then
        Mod:ToggleState(false)
        return
    end

    local speedPct = 0
    if forwardSpeed and forwardSpeed > 0 then
        speedPct = (forwardSpeed / maxSpeed) * 100
        if speedPct > 100 then speedPct = 100 end
    end
    
    if self.KT_LastSpeedPct == nil or math.abs(speedPct - self.KT_LastSpeedPct) >= SPEED_EPSILON then
        self.KT_LastSpeedPct = speedPct
        speedBar:SetValue(speedPct)
    end
    UpdateSecondWind()
    
    if Mod.db.showSpeedText and forwardSpeed then
        local displayVal = (forwardSpeed / 7) * 100
        local newText = string.format("%d%%", displayVal)
        if self.KT_LastSpeedText ~= newText then
            self.KT_LastSpeedText = newText
            speedBar.Text:SetText(newText)
        end
    else
        if self.KT_LastSpeedText ~= "" then
            self.KT_LastSpeedText = ""
            speedBar.Text:SetText("")
        end
    end

    -- Color actualizado cuando cambia el estado o auras.
    
    -- Forzar actualización constante de posición del widget de blizzard
    -- por si el juego intenta moverlo
    -- El widget de vigor se re-ancla via hooks; evitar trabajo por tick.
end

-- ============================================================================
-- GESTIÓN DE ESTADO
-- ============================================================================

function Mod:ToggleState(enable)
    if enable then
        isSkyriding = true
        frame:SetParent(UIParent)
        frame:SetClampedToScreen(true)
        frame:SetFrameStrata("MEDIUM")
        frame:SetFrameLevel(20)
        ApplySafeFramePosition()
        frame:SetAlpha(1)
        frame:Show()
        frame:SetScript("OnUpdate", UpdateLoop)
        
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN", UpdateCooldowns)
        self:RegisterEvent("UNIT_POWER_UPDATE", "HandleVigorPowerUpdate")
        
        self:UpdateAuras()
        UpdateCooldowns()
        UpdateSecondWind()
        
        -- Activar secuestro del widget
        UpdateBlizzardWidget()
    else
        isSkyriding = false
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
        self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
        self:UnregisterEvent("UNIT_POWER_UPDATE")
        
        -- Liberar widget
        UpdateBlizzardWidget()
        local container = _G.UIWidgetPowerBarContainerFrame
        if container then
            container:SetAlpha(1)
        end
    end

end

function Mod:UNIT_AURA(_, unit)
    if unit == "player" then
        self:UpdateAuras()
        self:CheckMountState()
    end
end

function Mod:HandleVigorPowerUpdate(_, unit)
    if unit == "player" then
        UpdateSecondWind()
        if not isSkyriding then
            self:CheckMountState()
        end
    end
end

function Mod:HandleVigorChargesUpdate()
    if isSkyriding then
        UpdateSecondWind()
    end
    self:CheckMountState()
end

function Mod:UNIT_SPELLCAST_SUCCEEDED(_, unit, _, spellID)
    if unit == "player" then
        self:CheckMountState()
        if IsSoarSpellID(spellID) then
            MarkRecentSoarCast()
            if not isSkyriding then
                self:ToggleState(true)
            end
            self:ScheduleTimer(function()
                self:CheckMountState()
            end, 0.6)
            self:ScheduleTimer(function()
                self:CheckMountState()
            end, 1.7)
            self:ScheduleTimer(function()
                self:CheckMountState()
            end, 3.0)
        end
    end
end

function Mod:CheckMountState(event)
    if self.isPreviewing then return end -- No ocultar durante la previsualización
    -- [FIX] Delay check slightly to allow API to update during mount swap
    if self.mountStateTimer then
        self:CancelTimer(self.mountStateTimer, true)
        self.mountStateTimer = nil
    end

    self.mountStateTimer = self:ScheduleTimer(function()
        self:UpdateAuras()
        local state = GetDragonRidingState()

        lastKnownHasVigor = state.hasVigor

        if state.shouldShow then
            if not isSkyriding then self:ToggleState(true) end
        else
            if isSkyriding then self:ToggleState(false) end
        end
        self.mountStateTimer = nil
    end, 0.1)
end

function Mod:TogglePreview()
    self.isPreviewing = not self.isPreviewing
    if self.isPreviewing then
        self:ToggleState(true)
        if speedBar then speedBar:SetValue(100); speedBar.Text:SetText("100%") end
    else
        self:CheckMountState()
    end
end

function Mod:OnEnable()
    if not self.db.enable then return end
    self:BuildUI()
    self:RegisterEvent("COMPANION_UPDATE", "CheckMountState")
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "CheckMountState")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckMountState")
    self:RegisterEvent("ZONE_CHANGED", "CheckMountState")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "CheckMountState")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckMountState")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", "CheckMountState")
    self:RegisterEvent("UNIT_EXITED_VEHICLE", "CheckMountState")
    self:RegisterEvent("UNIT_MAXPOWER", "CheckMountState") -- [FIX] Re-check if Vigor becomes available
    self:RegisterEvent("UNIT_POWER_BAR_SHOW", "CheckMountState")
    self:RegisterEvent("UNIT_POWER_BAR_HIDE", "CheckMountState")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "CheckMountState") -- [FIX] Druid Flight Form support
    self:RegisterEvent("UNIT_MODEL_CHANGED", "CheckMountState") -- [FIX] Evoker Dracthyr/Visage form support
    self:RegisterEvent("UNIT_DISPLAYPOWER", "CheckMountState") -- [FIX] Power type change support
    self:RegisterEvent("SPELL_UPDATE_CHARGES", "CheckMountState")
    self:RegisterEvent("PLAYER_CAN_GLIDE_CHANGED", "CheckMountState")
    self:RegisterEvent("PLAYER_IS_GLIDING_CHANGED", "CheckMountState")
    self:RegisterEvent("UPDATE_BONUS_ACTIONBAR", "CheckMountState")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    -- Hook extra de seguridad para el widget
    if _G.UIWidgetPowerBarContainerFrame then
         _G.UIWidgetPowerBarContainerFrame:HookScript("OnShow", function()
            if Mod and Mod.CheckMountState then
                Mod:CheckMountState()
            end
         end)
         _G.UIWidgetPowerBarContainerFrame:HookScript("OnHide", function()
            if Mod and Mod.CheckMountState then
                Mod:CheckMountState()
            end
         end)
         self:SecureHook(_G.UIWidgetPowerBarContainerFrame, "SetPoint", function(s)
            if isSkyriding then
                 s:SetAlpha(0)
            end
         end)
    end
    self:CheckMountState()
end

function Mod:OnDisable()
    self:ToggleState(false)
    if self.CancelAllTimers then
        self:CancelAllTimers()
    end
    self:UnregisterAllEvents()
    self:UnhookAll()
    if frame then frame:Hide() end
end

function Mod:Refresh()
    self.db = KT.db.profile.dragonRiding
    if frame then
        frame:SetSize(self.db.width, math.max(60, self.db.height + 36))
        frame:SetParent(UIParent)
        frame:SetClampedToScreen(true)
        frame:SetFrameStrata("MEDIUM")
        frame:SetFrameLevel(20)
        ApplySafeFramePosition()
        if speedBar then
            speedBar:SetSize(self.db.width, self.db.height)
            speedBar:ClearAllPoints()
            speedBar:SetPoint("TOP", frame, "TOP", 0, 0)
        end
        if secondWindBar then
            LayoutVigorBar()
            UpdateSecondWind()
        end
        local iconSize = self.db.height + 16
        for i, sFrame in ipairs(spellContainer) do
            sFrame:SetSize(iconSize, iconSize)
            sFrame:ClearAllPoints()
            if i == 1 then
                sFrame:SetPoint("RIGHT", speedBar, "LEFT", -6, 0)
            else
                sFrame:SetPoint("LEFT", speedBar, "RIGHT", 6, 0)
            end
        end
    end
    self:RegisterUnlockElement()
    self:CheckMountState()
end

-- ============================================================================
-- OPCIONES (Sliders para moverlo)
-- ============================================================================

function Mod:GetOptions()
    return {
        type = "group",
        name = LText("Dragon Riding"),
        order = 100,
        get = function(info) return self.db[info[#info]] end,
        set = function(info, value)
            self.db[info[#info]] = value
            self:Refresh()
        end,
        args = {
            header = { type = "header", name = LText("General"), order = 1 },
            enable = {
                type = "toggle", name = LText("Enable Module"), order = 2,
                set = function(info, val) self.db.enable = val; if val then self:OnEnable() else self:OnDisable() end end
            },
            showSpeedText = { type = "toggle", name = LText("Show Speed Text"), order = 3 },
            
            headerPos = { type = "header", name = LText("Position"), order = 10 },
            xOffset = { type = "range", name = LText("X Position"), min = -1000, max = 1000, step = 1, order = 11 },
            yOffset = { type = "range", name = LText("Y Position"), min = -1000, max = 1000, step = 1, order = 12 },
            width = { type = "range", name = LText("Width"), min = 100, max = 600, step = 1, order = 13 },
            height = { type = "range", name = LText("Height"), min = 10, max = 50, step = 1, order = 14 },
        }
    }
end
