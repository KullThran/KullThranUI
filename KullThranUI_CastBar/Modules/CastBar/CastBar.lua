-------------------------------------------------------------------------------
-- Modules/CastBar/CastBar.lua (moved from Modules/CastBar.lua)
--  CastBar.lua -- KullThranUI Cast Bar Module
--
--  PRIORIDAD DE ANCLAJE (SnapToTop):
--    1. KUI_ResourceBarsTop   -- frame mas alto del stack de recursos (KRB)
--    2. KUI_CDMBar_cooldowns  -- si KRB no tiene barras activas
--    3. EssentialCooldownViewer / ECV_Container -- fallback Blizzard
--    4. Centro de pantalla    -- ultimo fallback
--
--  El ancho de la barra se iguala automaticamente al anchor (autoWidth).
-------------------------------------------------------------------------------
local KT  = _G.KT
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local Mod = KT:NewModule("CastBar", "AceEvent-3.0", "AceTimer-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

local UnitCastingInfo  = UnitCastingInfo
local UnitChannelInfo  = UnitChannelInfo
local UnitClass        = UnitClass
local GetTime          = GetTime
local GetUnitEmpowerHoldAtMaxTime = GetUnitEmpowerHoldAtMaxTime
local UnitEmpoweredStagePercentages = UnitEmpoweredStagePercentages
local CreateFrame      = CreateFrame
local UIParent         = UIParent
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local C_ClassColor     = C_ClassColor
local AUTO_WIDTH_SYNC_INTERVAL = 0.25
local AUTO_WIDTH_SYNC_TICKS = 16

-- Channel tick data for supported channeled spells.
-- ticks: fixed number of ticks across the full channel duration.
-- tickInterval: fixed interval in seconds; duration changes add/remove ticks.
local CHANNEL_TICK_DATA = {
    [356995] = { ticks = 4, modSpell = 1219723, modTicks = 5 }, -- Disintegrate
    [15407] = { ticks = 6 }, -- Mind Flay
    [129197] = { ticks = 6 }, -- Mind Flay (Insanity)
    [5143] = { ticks = 5 }, -- Arcane Missiles
    [7268] = { ticks = 5 }, -- Arcane Missiles
    [198013] = { tickInterval = 0.2 }, -- Eye Beam
    [320415] = { tickInterval = 0.2 }, -- Eye Beam
    [473728] = { tickInterval = 0.2 }, -- Void Ray
    [212084] = { ticks = 10 }, -- Fel Devastation
    [320639] = { ticks = 10 }, -- Fel Devastation
    [198590] = { ticks = 5 }, -- Drain Soul
    [1120] = { ticks = 5 }, -- Drain Soul
    [689] = { ticks = 5 }, -- Drain Life
    [89420] = { ticks = 5 }, -- Drain Life
    [234153] = { ticks = 5 }, -- Drain Life
    [47540] = { ticks = 3 }, -- Penance
    [47666] = { ticks = 3 }, -- Penance
    [47750] = { ticks = 3 }, -- Penance
}

local function ResolveChannelSpellID(unit, fallbackSpellID)
    if type(fallbackSpellID) == "number" and fallbackSpellID > 0 then
        return fallbackSpellID
    end

    local spellID = select(8, UnitChannelInfo(unit))
    if type(spellID) == "number" and spellID > 0 then
        return spellID
    end

    return nil
end

local function ResolveChannelTickCount(spellID, durationSeconds)
    local info = spellID and CHANNEL_TICK_DATA[spellID]
    if not info or not durationSeconds or durationSeconds <= 0 then
        return nil
    end

    if info.tickInterval and info.tickInterval > 0 then
        local ticks = math.floor((durationSeconds / info.tickInterval) + 0.5)
        return ticks > 1 and ticks or nil
    end

    local ticks = info.ticks
    if info.modSpell and info.modTicks and IsPlayerSpell and IsPlayerSpell(info.modSpell) then
        ticks = info.modTicks
    end

    if type(ticks) == "number" and ticks > 1 then
        return ticks
    end

    return nil
end

local function DebugValue(value)
    if value == nil then return "nil" end
    return tostring(value)
end

local function CastBarPrint(...)
    if KT and KT.Print then
        KT:Print(...)
    end
end

local function IsUsableAnchor(f)
    if not f then return false end
    if f._cdmHidden then return false end
    if not f.IsShown or not f:IsShown() then return false end
    if not f.GetWidth or f:GetWidth() <= 5 then return false end
    local _, _, _, _, y = f:GetPoint()
    if y and math.abs(y) > 3000 then return false end
    return true
end

function Mod:GetAnchorFrames()
    local anchor = (IsUsableAnchor(_G.KUI_ResourceBarsTop) and _G.KUI_ResourceBarsTop)
                or (IsUsableAnchor(_G["KUI_CDMBar_cooldowns"]) and _G["KUI_CDMBar_cooldowns"])
                or (IsUsableAnchor(_G.EssentialCooldownViewer) and _G.EssentialCooldownViewer)
                or (IsUsableAnchor(_G.ECV_Container) and _G.ECV_Container)
    local widthAnchor = (IsUsableAnchor(_G.KUI_ResourceBarsAnchor) and _G.KUI_ResourceBarsAnchor)
                     or anchor
    return anchor, widthAnchor
end

function Mod:GetStoredManualPosition()
    local pos = self.db and self.db.position
    if type(pos) ~= "table" or not pos.point then
        return nil
    end

    return {
        point = pos.point or "CENTER",
        relativePoint = pos.relativePoint or pos.point or "CENTER",
        x = tonumber(pos.x) or 0,
        y = tonumber(pos.y) or -225,
        scale = tonumber(pos.scale) or nil,
    }
end

function Mod:ApplyStoredManualPosition()
    if not self.bar then
        return false
    end

    local pos = self:GetStoredManualPosition()
    if not pos then
        return false
    end

    self.bar:ClearAllPoints()
    self.bar:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    return true
end

function Mod:SaveManualPosition(point, relativePoint, x, y, scale)
    if not self.db then
        return
    end

    self.db.position = {
        point = point or "CENTER",
        relativePoint = relativePoint or point or "CENTER",
        x = tonumber(x) or 0,
        y = tonumber(y) or 0,
        scale = tonumber(scale) or nil,
    }
    self.db.autoPosition = false
end

local function GetUnlockPreviewIconOffset()
    local db = Mod and Mod.db
    local bar = Mod and Mod.bar
    if not (db and db.showIcon) then
        return 0
    end

    local baseHeight = (db.height or (bar and bar.GetHeight and bar:GetHeight()) or 20)
    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = (bar and bar.GetEffectiveScale and bar:GetEffectiveScale()) or uiScale
    return (baseHeight + 2) * frameScale / uiScale
end

local function TranslateUnlockMoverPosition(pos)
    if type(pos) ~= "table" then
        return pos
    end

    local translated = {
        point = pos.point or "TOPLEFT",
        relativePoint = pos.relativePoint or pos.point or "TOPLEFT",
        x = tonumber(pos.x) or 0,
        y = tonumber(pos.y) or 0,
        scale = tonumber(pos.scale) or nil,
    }

    local db = Mod and Mod.db
    if db and db.showIcon and db.iconPosition ~= "RIGHT" then
        translated.x = translated.x + GetUnlockPreviewIconOffset()
    end

    return translated
end

function Mod:RegisterUnlockElement()
    if self.unlockElementRegistered or not KT or not KT.RegisterUnlockElement or not self.bar then
        return
    end

    KT.RegisterUnlockElement("castbar_player", {
        label = "Player Cast Bar",
        group = "Cast Bar",
        order = 10,
        getFrame = function()
            return Mod and Mod.bar or nil
        end,
        getSize = function()
            local bar = Mod and Mod.bar
            local db = Mod and Mod.db
            local width = bar and bar.GetWidth and bar:GetWidth() or 250
            local height = bar and bar.GetHeight and bar:GetHeight() or 20
            if db and db.showIcon then
                width = width + (db.height or height) + 2
                height = math.max(height, db.height or height)
            end
            return math.max(width, 180), math.max(height, 20)
        end,
        getRect = function()
            local bar = Mod and Mod.bar
            local db = Mod and Mod.db
            if not (bar and bar.GetLeft and bar.GetTop and bar:GetLeft() and bar:GetTop()) then
                return nil
            end

            local uiScale = UIParent:GetEffectiveScale()
            local frameScale = bar:GetEffectiveScale()
            local left = bar:GetLeft() * frameScale / uiScale
            local top = bar:GetTop() * frameScale / uiScale
            local width = (bar.GetWidth and bar:GetWidth() or 250) * frameScale / uiScale
            local height = (bar.GetHeight and bar:GetHeight() or 20) * frameScale / uiScale

            if db and db.showIcon then
                local extra = GetUnlockPreviewIconOffset()
                if db.iconPosition == "RIGHT" then
                    width = width + extra
                else
                    left = left - extra
                    width = width + extra
                end
                height = math.max(height, (db.height or 20) * frameScale / uiScale)
            end

            return left, top, math.max(width, 180), math.max(height, 20)
        end,
        translateMoverPosition = function(_, pos)
            return TranslateUnlockMoverPosition(pos)
        end,
        loadPosition = function()
            return Mod:GetStoredManualPosition()
        end,
        savePosition = function(_, point, relativePoint, x, y, scale)
            Mod:SaveManualPosition(point, relativePoint, x, y, scale)
        end,
        applyPosition = function()
            if Mod.db and Mod.db.autoPosition then
                Mod:SnapToTop()
            else
                Mod:ApplyStoredManualPosition()
            end
        end,
    })

    self.unlockElementRegistered = true
end
local function GetThemeAccentColor()
    if KT and KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        return r or 1, g or 0, b or 0.3333
    end
    return 1, 0, 0.3333
end

local function GetThemeAccentColorTable()
    local r, g, b = GetThemeAccentColor()
    return { r = r, g = g, b = b, a = 1 }
end

local function UsesGlobalClassColorTheme()
    local profile = KT and KT.db and KT.db.profile
    local skin = profile and profile.skin
    return skin and (skin.kullthranUIColorByClass == true or skin.borderTheme == "CLASS")
end

local function GetPlayerClassColor()
    local _, classTag = UnitClass("player")
    local classColor = classTag and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classTag)
    if not classColor and classTag and RAID_CLASS_COLORS then
        classColor = RAID_CLASS_COLORS[classTag]
    end
    return classColor
end

function Mod:GetResolvedBarColor()
    local db = self.db
    if not db then
        local r, g, b = GetThemeAccentColor()
        return r, g, b, 1
    end

    local alpha = 1
    if db.color and db.color.a ~= nil then
        alpha = db.color.a
    end

    if db.classColor or UsesGlobalClassColorTheme() then
        local classColor = GetPlayerClassColor()
        if classColor then
            return classColor.r or 1, classColor.g or 1, classColor.b or 1, alpha
        end
    end

    if db.colorMode ~= "CUSTOM" then
        local r, g, b = GetThemeAccentColor()
        return r, g, b, alpha
    end

    local c = db.color or {}
    return c.r or 1, c.g or 0, c.b or 0.3333, c.a or 1
end

function Mod:SyncAutoWidth(forceApply)
    if not self.db or not self.db.autoWidth or not self.bar then
        return false
    end

    local _, widthAnchor = self:GetAnchorFrames()
    if not widthAnchor or not widthAnchor.GetWidth then
        return false
    end

    local refW = widthAnchor:GetWidth()
    local iconSz = self.db.showIcon and self.db.height or 0
    local gap = self.db.showIcon and 2 or 0
    local newW = refW - iconSz - gap

    if newW > 20 and math.abs((self.db.width or 0) - newW) > 1 then
        self.db.width = newW
        if forceApply then
            self:ApplySettings()
        else
            self.bar:SetWidth(newW)
            if self.bar.Text then
                self.bar.Text:SetWidth(math.max(newW - 45, 10))
            end
        end
        return true
    end

    return false
end

function Mod:StopAutoWidthWatch()
    if self._autoWidthTicker then
        self._autoWidthTicker:Cancel()
        self._autoWidthTicker = nil
    end
end

function Mod:StartAutoWidthWatch(maxTicks)
    self:StopAutoWidthWatch()
    if not self.db or not self.db.autoWidth then
        return
    end

    local ticks = 0
    self._autoWidthTicker = C_Timer.NewTicker(AUTO_WIDTH_SYNC_INTERVAL, function()
        ticks = ticks + 1
        if not self.bar or not self.db or not self.db.autoWidth then
            self:StopAutoWidthWatch()
            return
        end

        if self:SyncAutoWidth(true) then
            self:SnapToTop()
        end

        if ticks >= (maxTicks or AUTO_WIDTH_SYNC_TICKS) then
            self:StopAutoWidthWatch()
        end
    end)
end

-- ============================================================================
-- OnInitialize
-- ============================================================================
function Mod:OnInitialize()
    if not KT.db then return end

    -- Migraciones de perfil antiguo
    if KT.db.profile.castbar then
        local db = KT.db.profile.castbar

        -- Color negro / naranja / transparente → rosa KUI
        -- Default migration: older KT profiles shipped with a 30px castbar height.
        -- Only migrate when it still looks like the old defaults to avoid overriding user choices.
        if not db._ktCastbarHeightDefaultMigrated_v1 then
            local h = tonumber(db.height)
            local w = tonumber(db.width)
            local s = tonumber(db.scale)
            if h == 30 and w == 250 and (s == 1 or s == 1.0) and db.frameStrata == "BACKGROUND" then
                db.height = 20
            end
            db._ktCastbarHeightDefaultMigrated_v1 = true
        end

        if type(db.color) ~= "table" then
            local r, g, b = GetThemeAccentColor()
            db.color = { r = r, g = g, b = b, a = 1 }
        end

        if db.texture == "Interface\\TargetingFrame\\UI-StatusBar" then
            db.texture = "Melli"
        end
        if not db.frameStrata then db.frameStrata = "MEDIUM" end
        if not db.frameLevel  then db.frameLevel  = 10 end
    end

    if not KT.db.profile.castbar then
        KT.db.profile.castbar = {
            enable        = true,
            autoPosition  = true,
            autoWidth     = true,
            width         = 250,
            height        = 20,
            scale         = 1.0,
            frameStrata   = "MEDIUM",
            frameLevel    = 10,
            texture       = "Melli",
            color         = GetThemeAccentColorTable(),
            colorMode     = "THEME",
            classColor    = false,
            textColor     = { r = 1, g = 1, b = 1, a = 1 },
            font          = KT and KT.DEFAULT_FONT_NAME or "AAA_ITC_Avant_Garde",
            fontSize      = 16,
            fontOutline   = "OUTLINE",
            showIcon      = true,
            iconPosition  = "LEFT",
            iconShape     = "SQUARE",
        }
    end

    self.db = KT.db.profile.castbar
    if self.db.autoPosition == nil then self.db.autoPosition = true end
    if self.db.autoWidth    == nil then self.db.autoWidth    = true end
    if self.db.classColor   == nil then self.db.classColor   = false end
    if self.db.colorMode    == nil then self.db.colorMode    = "THEME" end
    self.isDummy = false
end

-- ============================================================================
-- OnEnable
-- ============================================================================
function Mod:OnEnable()
    if not KT.db then return end
    self.db = KT.db.profile.castbar
    if not self.db.enable then
        self:OnDisable()
        return
    end
    self._suppressBlizzardCastBar = true
    self._blizzardOriginalAlpha = self._blizzardOriginalAlpha or {}
    self._blizzardAlphaGuarded = self._blizzardAlphaGuarded or {}
    self._blizzardAlphaApplying = self._blizzardAlphaApplying or {}

    -- Alpha alone is not enough for Blizzard's interrupted/failed animation:
    -- an AnimationGroup can supply the effective alpha after our OnUpdate has
    -- run. Parenting the native bars to a hidden frame keeps every animated
    -- region invisible as well, while still allowing us to restore the bars
    -- cleanly if this module is disabled.
    if not self.blizzardCastBarHiddenParent then
        self.blizzardCastBarHiddenParent = CreateFrame("Frame", nil, UIParent)
        self.blizzardCastBarHiddenParent:Hide()
    end

    local function ForceHiddenAlpha(frame)
        if not frame or not frame.SetAlpha or Mod._blizzardAlphaApplying[frame] then return end
        Mod._blizzardAlphaApplying[frame] = true
        frame:SetAlpha(0)
        Mod._blizzardAlphaApplying[frame] = nil
    end
    self._forceBlizzardCastBarAlpha = ForceHiddenAlpha

    local function SuppressBlizzardCastBar(frame, force)
        if not frame then return end
        if self._blizzardOriginalAlpha[frame] == nil and frame.GetAlpha then
            self._blizzardOriginalAlpha[frame] = frame:GetAlpha()
        end
        if frame._ktOriginalParent == nil and frame.GetParent then
            frame._ktOriginalParent = frame:GetParent()
        end
        if frame._ktOriginalPoints == nil and frame.GetNumPoints and frame.GetPoint then
            frame._ktOriginalPoints = {}
            for index = 1, frame:GetNumPoints() do
                frame._ktOriginalPoints[index] = { frame:GetPoint(index) }
            end
        end

        local hiddenParent = self.blizzardCastBarHiddenParent
        if hiddenParent and frame.GetParent and frame.SetParent
            and frame:GetParent() ~= hiddenParent
            and not (InCombatLockdown and InCombatLockdown()) then
            pcall(frame.SetParent, frame, hiddenParent)
        end

        local installedNow = false
        if not self._blizzardAlphaGuarded[frame] then
            self._blizzardAlphaGuarded[frame] = true
            installedNow = true
            -- SetAlpha is not protected. A secure post-hook lets us undo
            -- Blizzard's visibility reset in the same call, before rendering,
            -- without touching the casting bar's secret-value state machine.
            hooksecurefunc(frame, "SetAlpha", function(target)
                if Mod._suppressBlizzardCastBar then
                    ForceHiddenAlpha(target)
                end
            end)
        end

        if force or installedNow then
            ForceHiddenAlpha(frame)
        end
    end

    SuppressBlizzardCastBar(_G.PlayerCastingBarFrame, true)
    SuppressBlizzardCastBar(_G.OverlayPlayerCastingBarFrame, true)

    if not self.blizzardCastBarSuppressor then
        self.blizzardCastBarSuppressor = CreateFrame("Frame")
    end
    self.blizzardCastBarSuppressor:SetScript("OnUpdate", function()
        if not Mod._suppressBlizzardCastBar then return end
        -- Blizzard's finish/cancel animations can temporarily replace the
        -- effective alpha without making a normal SetAlpha call. Reassert it
        -- every frame as well as keeping the SetAlpha hook, so the native bar
        -- cannot flash for one frame when a cast is cancelled.
        SuppressBlizzardCastBar(_G.PlayerCastingBarFrame, true)
        SuppressBlizzardCastBar(_G.OverlayPlayerCastingBarFrame, true)
    end)
    self:CreateBar()

    self:RegisterEvent("UNIT_SPELLCAST_START")
    self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "SnapToTop")
    self:RegisterEvent("PLAYER_ENTERING_WORLD",         "OnZoneChange")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA",         "OnZoneChange")

    local function TryHookResourceBars()
        local rb = KT:GetModule("ResourceBars", true)
        if rb and type(rb.BuildBars) == "function" and not self.hookedResourceBarsBuild then
            hooksecurefunc(rb, "BuildBars", function()
                if self.db and self.db.autoWidth then
                    self:StartAutoWidthWatch(10)
                end
            end)
            self.hookedResourceBarsBuild = true
        end
    end
    TryHookResourceBars()

    C_Timer.After(0.8, function() self:SnapToTop() end)
    self:ApplySettings()
    if self.db and self.db.autoPosition == false then self:ApplyStoredManualPosition() end
    self:StartAutoWidthWatch()
    -- Reanclajes diferidos: KRB termina a ~0.5s, CDM a ~1.5s, todo estable a ~3s
    C_Timer.After(0.5, function() TryHookResourceBars() end)
    C_Timer.After(1.5, function() self:SnapToTop(); self:StartAutoWidthWatch() end)
    C_Timer.After(3.5, function() self:SnapToTop(); self:StartAutoWidthWatch() end)
end

-- ============================================================================
-- CreateBar
-- ============================================================================
function Mod:CreateBar()
    if self.bar then return end

    local bar = CreateFrame("StatusBar", "KT_PlayerCastBar", UIParent, "BackdropTemplate")
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(10)
    bar:SetAlpha(0)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, -225)

    bar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    bar:SetBackdropColor(0, 0, 0, 0.5)
    bar:SetBackdropBorderColor(0, 0, 0, 1)

    -- Spark
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    spark:SetBlendMode("ADD")
    spark:SetWidth(20)
    bar.Spark = spark

    -- SafeZone (Lag/Latency indicator)
    local safeZone = bar:CreateTexture(nil, "OVERLAY")
    safeZone:SetTexture("Interface\\Buttons\\WHITE8x8")
    safeZone:SetColorTexture(1, 0, 0, 0.4)
    safeZone:SetPoint("TOP")
    safeZone:SetPoint("BOTTOM")
    safeZone:Hide()
    bar.SafeZone = safeZone

    local tickHost = CreateFrame("Frame", nil, bar)
    tickHost:SetAllPoints(bar)
    tickHost:SetFrameLevel(bar:GetFrameLevel() + 3)
    tickHost:EnableMouse(false)
    tickHost:Hide()
    bar.TickHost = tickHost
    bar.TickMarks = {}

    -- Texto nombre
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", 5, 0)
    bar.Text = text

    -- Texto tiempo
    local time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    time:SetPoint("RIGHT", -5, 0)
    bar.Time = time

    -- Icono
    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.Icon = icon

    -- Fondo del icono
    local iconBg = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    iconBg:SetFrameLevel(bar:GetFrameLevel() - 1)
    iconBg:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    iconBg:SetBackdropBorderColor(0, 0, 0, 1)
    bar.IconBg = iconBg

    bar:HookScript("OnShow", function()
        if Mod and Mod.DebugCastBar then
            Mod:DebugCastBar("Frame OnShow")
        end
    end)
    bar:HookScript("OnHide", function()
        if Mod and Mod.DebugCastBar then
            Mod:DebugCastBar("Frame OnHide")
        end
    end)

    self.bar = bar
    bar:Show()

    -- Registro EditMode
    local EM = KT:GetModule("EditMode", true)
    if EM then
        EM:RegisterFrame(bar, "Player CastBar", "castbar_player", {
            onEnter = function()
                Mod:Unlock()
                if not bar.KT_EditModeBg then
                    local f   = CreateFrame("Frame", nil, bar)
                    f:SetAllPoints()
                    f:SetFrameLevel(bar:GetFrameLevel() + 10)
                    local tex = f:CreateTexture(nil, "BACKGROUND")
                    tex:SetAllPoints()
                    tex:SetColorTexture(0, 0.6, 1, 0.4)
                    local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    lbl:SetPoint("CENTER")
                    lbl:SetText(LText("Player CastBar"))
                    bar.KT_EditModeBg = f
                end
                bar.KT_EditModeBg:Show()
            end,
            onExit = function()
                if not Mod.configWindow or not Mod.configWindow:IsShown() then Mod:Lock() end
                if bar.KT_EditModeBg then bar.KT_EditModeBg:Hide() end
            end,
            resizable = false,
        })
    end

    self:RegisterUnlockElement()
end

function Mod:ClearChannelTicks()
    local bar = self.bar
    if not bar then
        return
    end

    bar.channelSpellID = nil
    bar.channelTicks = nil
    bar.empowerStages = nil
    if bar.TickHost then
        bar.TickHost:Hide()
    end

    for _, tick in ipairs(bar.TickMarks or {}) do
        tick:Hide()
    end
end

function Mod:LayoutChannelTicks()
    local bar = self.bar
    local tickCount = bar and bar.channelTicks or nil
    if not (bar and bar.TickHost and tickCount and tickCount > 1) then
        self:ClearChannelTicks()
        return
    end

    local host = bar.TickHost
    local lineCount = tickCount - 1
    for i = 1, lineCount do
        local tick = bar.TickMarks[i]
        if not tick then
            tick = host:CreateTexture(nil, "OVERLAY")
            tick:SetTexture("Interface\\Buttons\\WHITE8x8")
            tick:SetColorTexture(1, 1, 1, 0.7)
            bar.TickMarks[i] = tick
        end

        tick:ClearAllPoints()
        tick:SetWidth(2)
        tick:SetPoint("TOP", host, "TOPLEFT", math.floor((bar:GetWidth() * (i / tickCount)) + 0.5), -1)
        tick:SetPoint("BOTTOM", host, "BOTTOMLEFT", math.floor((bar:GetWidth() * (i / tickCount)) + 0.5), 1)
        tick:Show()
    end

    for i = lineCount + 1, #(bar.TickMarks or {}) do
        bar.TickMarks[i]:Hide()
    end

    host:Show()
end

function Mod:LayoutEmpowerTicks()
    local bar = self.bar
    local stages = bar and bar.empowerStages or nil
    if not (bar and bar.TickHost and type(stages) == "table") then
        self:ClearChannelTicks()
        return
    end

    local host = bar.TickHost
    local width = bar:GetWidth() or 0
    local cumulative = 0
    local lineIndex = 0

    for stage = 1, #stages do
        local stageSection = tonumber(stages[stage])
        if stageSection and stageSection > 0 then
            cumulative = cumulative + stageSection
            if cumulative > 0 and cumulative < 0.999 then
                lineIndex = lineIndex + 1
                local tick = bar.TickMarks[lineIndex]
                if not tick then
                    tick = host:CreateTexture(nil, "OVERLAY")
                    tick:SetTexture("Interface\\Buttons\\WHITE8x8")
                    tick:SetColorTexture(1, 1, 1, 0.7)
                    bar.TickMarks[lineIndex] = tick
                end

                tick:ClearAllPoints()
                tick:SetWidth(2)
                tick:SetPoint("TOP", host, "TOPLEFT", math.floor((width * cumulative) + 0.5), -1)
                tick:SetPoint("BOTTOM", host, "BOTTOMLEFT", math.floor((width * cumulative) + 0.5), 1)
                tick:Show()
            end
        end
    end

    if lineIndex <= 0 then
        self:ClearChannelTicks()
        return
    end

    for i = lineIndex + 1, #(bar.TickMarks or {}) do
        bar.TickMarks[i]:Hide()
    end

    host:Show()
end

function Mod:UpdateChannelTicks(spellID, startTimeSeconds, endTimeSeconds)
    local bar = self.bar
    if not bar then
        return
    end

    local duration = (endTimeSeconds and startTimeSeconds) and (endTimeSeconds - startTimeSeconds) or nil
    local tickCount = ResolveChannelTickCount(spellID, duration)
    if not tickCount then
        self:ClearChannelTicks()
        return
    end

    bar.channelSpellID = spellID
    bar.channelTicks = tickCount
    self:LayoutChannelTicks()
end

function Mod:UpdateEmpowerTicks(unit)
    local bar = self.bar
    if not bar or type(UnitEmpoweredStagePercentages) ~= "function" then
        self:ClearChannelTicks()
        return
    end

    local ok, stages = pcall(UnitEmpoweredStagePercentages, unit or "player")
    if not ok or type(stages) ~= "table" or #stages <= 1 then
        self:ClearChannelTicks()
        return
    end

    bar.channelSpellID = nil
    bar.channelTicks = nil
    bar.empowerStages = stages
    self:LayoutEmpowerTicks()
end


-- ============================================================================
-- SnapToTop: ancla la CastBar encima del frame más alto disponible
-- ============================================================================
function Mod:SnapToTop()
    if not self.bar or not self.db then
        return
    end

    if self.db.autoPosition == false then
        if not self:ApplyStoredManualPosition() then
            self.bar:ClearAllPoints()
            self.bar:SetPoint("CENTER", UIParent, "CENTER", 0, -225)
        end
        return
    end

    local anchor, widthAnchor = self:GetAnchorFrames()

    if not anchor then
        local EM    = KT:GetModule("EditMode", true)
        local saved = EM and EM.db and EM.db.frames
                      and EM.db.frames["castbar_player"]
                      and EM.db.frames["castbar_player"].point
        if not saved then
            self.bar:ClearAllPoints()
            self.bar:SetPoint("CENTER", UIParent, "CENTER", 0, -225)
        end
        return
    end

    if self.db.autoWidth and widthAnchor then
        self:SyncAutoWidth(true)
    end

    if self.db.autoPosition then
        local xOffset = 0
        if self.db.showIcon then
            local shift = (self.db.height + 2) / 2
            xOffset = (self.db.iconPosition == "RIGHT") and -shift or shift
        end
        self.bar:ClearAllPoints()
        self.bar:SetPoint("BOTTOM", anchor, "TOP", xOffset, 5)
    end
end

-- Alias de compatibilidad (KRB llama SnapToECV)
Mod.SnapToECV = Mod.SnapToTop

-- ============================================================================
-- OnZoneChange
-- ============================================================================
function Mod:OnZoneChange()
    C_Timer.After(1, function() self:SnapToTop() end)
    C_Timer.After(3, function() self:SnapToTop() end)
    self:StartAutoWidthWatch()
end

function Mod:StartBarUpdates()
    if not self.bar then return end
    if self.bar:GetScript("OnUpdate") then return end
    self.bar:SetScript("OnUpdate", function(s, elapsed) self:OnUpdate(s, elapsed) end)
end

function Mod:StopBarUpdates()
    if not self.bar then return end
    self.bar:SetScript("OnUpdate", nil)
end

function Mod:DebugCastBar(label, eventCastID)
    if not self._debugCastBar then return end

    local apiCastID = select(10, UnitCastingInfo("player"))
    local apiChannelCastID = select(11, UnitChannelInfo("player"))
    local bar = self.bar
    local parent = bar and bar.GetParent and bar:GetParent()
    local parentName = parent and (parent.GetName and parent:GetName() or tostring(parent)) or "nil"

    CastBarPrint(string.format(
        "[KT CastBar Debug] %s shown=%s visible=%s alpha=%s parent=%s casting=%s channeling=%s empowering=%s stored=%s event=%s apiCast=%s apiChannel=%s value=%s min=%s max=%s",
        label or "state",
        bar and bar:IsShown() and "1" or "0",
        bar and bar.IsVisible and bar:IsVisible() and "1" or "0",
        DebugValue(bar and bar.GetAlpha and bar:GetAlpha() or nil),
        parentName,
        bar and bar.casting and "1" or "0",
        bar and bar.channeling and "1" or "0",
        bar and bar.empowering and "1" or "0",
        DebugValue(bar and bar.castID),
        DebugValue(eventCastID),
        DebugValue(apiCastID),
        DebugValue(apiChannelCastID),
        DebugValue(bar and bar.GetValue and bar:GetValue() or nil),
        DebugValue(bar and bar.minValue),
        DebugValue(bar and bar.maxValue or bar and bar.endTime)
    ))
end

function Mod:CancelBarFailsafe()
    if self._barFailsafeTimer then
        self._barFailsafeTimer:Cancel()
        self._barFailsafeTimer = nil
    end
    self._barFailsafeToken = nil
end

function Mod:HideBarNow()
    if not self.bar then return end
    self:DebugCastBar("HideBarNow", self.bar.castID)
    self:CancelBarFailsafe()
    self.bar.casting = false
    self.bar.channeling = false
    self.bar.empowering = false
    self.bar.castID = nil
    self:ClearChannelTicks()
    self:StopBarUpdates()
    self.bar:SetAlpha(0)
    self.bar.Text:SetText("")
    self.bar.Time:SetText("")
    if self._suppressBlizzardCastBar and self._forceBlizzardCastBarAlpha then
        self._forceBlizzardCastBarAlpha(_G.PlayerCastingBarFrame)
        self._forceBlizzardCastBarAlpha(_G.OverlayPlayerCastingBarFrame)
    end
    self:DebugCastBar("HideBarNow post-hide")
    C_Timer.After(0, function()
        if self and self.DebugCastBar then
            self:DebugCastBar("HideBarNow next-frame")
        end
    end)
end

function Mod:ScheduleBarFailsafe(endTime, castID)
    if not self.bar or not endTime then return end
    self:CancelBarFailsafe()

    local token = castID or endTime
    local delay = math.max(0.15, (endTime - GetTime()) + 0.15)
    self._barFailsafeToken = token
    self._barFailsafeTimer = C_Timer.NewTimer(delay, function()
        self._barFailsafeTimer = nil
        if self.isDummy or not self.bar or self._barFailsafeToken ~= token then
            return
        end
        if UnitCastingInfo("player") or UnitChannelInfo("player") then
            return
        end
        self:HideBarNow()
    end)
end

-- ============================================================================
-- ApplySettings
-- ============================================================================
function Mod:ApplySettings()
    if not self.bar or not self.db then return end
    local bar = self.bar
    local db = self.db

    bar:SetWidth(db.width or 250)
    bar:SetHeight(db.height or 20)
    bar:SetScale(db.scale or 1)
    bar:SetFrameStrata(db.frameStrata or "MEDIUM")
    bar:SetFrameLevel(db.frameLevel  or 10)

    -- Textura
    local tex = LSM and LSM:Fetch("statusbar", db.texture) or db.texture
    if db.texture == "Melli" and (not tex or tex == "Melli") then
        tex = "Interface\\TargetingFrame\\UI-StatusBar"
    end
    if not tex or tex == "" then tex = "Interface\\TargetingFrame\\UI-StatusBar" end
    bar:SetStatusBarTexture(tex)
    if bar:GetStatusBarTexture() then
        bar:GetStatusBarTexture():SetHorizTile(false)
        bar:GetStatusBarTexture():SetVertTile(false)
    end
    do
        local r, g, b, a = self:GetResolvedBarColor()
        bar:SetStatusBarColor(r, g, b, a)
    end

    -- Fuente
    local font        = (KT and KT.ResolveFontForLocale and KT:ResolveFontForLocale(db.font)) or (LSM and LSM:Fetch("font", db.font)) or db.font
    local outline     = db.fontOutline or "OUTLINE"
    local adjustedSz  = math.min(db.fontSize, math.max(8, db.width / 12))
    bar.Text:SetFont(font, adjustedSz, outline)
    bar.Text:SetTextColor(db.textColor.r, db.textColor.g, db.textColor.b, db.textColor.a)
    bar.Text:SetWidth(db.width - 45)
    bar.Text:SetWordWrap(false)
    bar.Time:SetFont(font, adjustedSz, outline)
    bar.Time:SetTextColor(db.textColor.r, db.textColor.g, db.textColor.b, db.textColor.a)

    -- Icono
    if db.showIcon then
        bar.Icon:Show()
        bar.IconBg:Show()
        bar.Icon:ClearAllPoints()
        bar.Icon:SetSize(db.height, db.height)

        if db.iconPosition == "RIGHT" then
            bar.Icon:SetPoint("LEFT", bar, "RIGHT", 2, 0)
        else
            bar.Icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
        end

        bar.IconBg:ClearAllPoints()
        bar.IconBg:SetPoint("TOPLEFT",     bar.Icon, "TOPLEFT",     -1,  1)
        bar.IconBg:SetPoint("BOTTOMRIGHT", bar.Icon, "BOTTOMRIGHT",  1, -1)

        if db.iconShape == "CIRCLE" then
            if not bar.IconMask then
                bar.IconMask = bar:CreateMaskTexture()
                bar.IconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                bar.IconMask:SetAllPoints(bar.Icon)
                bar.Icon:AddMaskTexture(bar.IconMask)
            end
            bar.IconMask:Show()
            bar.IconBg:Hide()
        else
            if bar.IconMask then bar.IconMask:Hide() end
            bar.IconBg:Show()
        end
    else
        bar.Icon:Hide()
        bar.IconBg:Hide()
    end

    if bar.empowering and bar.empowerStages then
        self:LayoutEmpowerTicks()
    elseif bar.channeling and not bar.empowering and bar.channelTicks then
        self:LayoutChannelTicks()
    else
        self:ClearChannelTicks()
    end
end

-- ============================================================================
-- OnUpdate
-- ============================================================================
function Mod:OnUpdate(bar, elapsed)
    if self.isDummy then return end

    if bar.casting then
        local time = GetTime()
        if not bar.maxValue or not bar.minValue then return end
        if time > bar.maxValue then time = bar.maxValue end
        bar:SetValue(time)
        local remaining = bar.maxValue - time
        if remaining > 0 then
            bar.Time:SetFormattedText("%.1f", remaining)
        else
            if self._debugCastBar and not bar._ktDebugNearEndLogged then
                bar._ktDebugNearEndLogged = true
                self:DebugCastBar("OnUpdate cast near-end", bar.castID)
            end
            bar.Time:SetText("")
        end
        local dur = bar.maxValue - bar.minValue
        if dur > 0 then
            local sp = math.max(0, math.min((time - bar.minValue) / dur * bar:GetWidth(), bar:GetWidth()))
            bar.Spark:SetPoint("CENTER", bar, "LEFT", sp, 0)
        end

    elseif bar.empowering then
        local time = GetTime()
        if not bar.endTime or not bar.startTime then return end
        if time > bar.endTime then time = bar.endTime end
        bar:SetValue(time)
        local remaining = bar.endTime - time
        if remaining > 0 then
            bar.Time:SetFormattedText("%.1f", remaining)
        else
            if self._debugCastBar and not bar._ktDebugNearEndLogged then
                bar._ktDebugNearEndLogged = true
                self:DebugCastBar("OnUpdate empower near-end", bar.castID)
            end
            bar.Time:SetText("")
        end
        local dur = bar.endTime - bar.startTime
        if dur > 0 then
            local sp = math.max(0, math.min((time - bar.startTime) / dur * bar:GetWidth(), bar:GetWidth()))
            bar.Spark:SetPoint("CENTER", bar, "LEFT", sp, 0)
        end
    elseif bar.channeling then
        local time = GetTime()
        if not bar.endTime or not bar.startTime then return end
        if time > bar.endTime then time = bar.endTime end
        local remaining = bar.endTime - time
        bar:SetValue(remaining)
        if remaining > 0 then
            bar.Time:SetFormattedText("%.1f", remaining)
        else
            if self._debugCastBar and not bar._ktDebugNearEndLogged then
                bar._ktDebugNearEndLogged = true
                self:DebugCastBar("OnUpdate channel near-end", bar.castID)
            end
            bar.Time:SetText("")
        end
        local dur = bar.endTime - bar.startTime
        if dur > 0 then
            local sp = math.max(0, math.min((remaining / dur) * bar:GetWidth(), bar:GetWidth()))
            bar.Spark:SetPoint("CENTER", bar, "LEFT", sp, 0)
        end
    end
end

-- ============================================================================
-- Eventos de cast
-- ============================================================================
function Mod:UpdateSafeZone()
    local bar = self.bar
    if not bar or not bar.SafeZone then return end

    local latency = select(4, GetNetStats())
    if not latency then
        bar.SafeZone:Hide()
        return
    end
    latency = latency / 1000

    local duration
    if bar.casting then
        duration = (bar.maxValue or 0) - (bar.minValue or 0)
        bar.SafeZone:ClearAllPoints()
        bar.SafeZone:SetPoint("TOPRIGHT")
        bar.SafeZone:SetPoint("BOTTOMRIGHT")
    elseif bar.channeling or bar.empowering then
        duration = (bar.endTime or 0) - (bar.startTime or 0)
        bar.SafeZone:ClearAllPoints()
        bar.SafeZone:SetPoint("TOPLEFT")
        bar.SafeZone:SetPoint("BOTTOMLEFT")
    else
        bar.SafeZone:Hide()
        return
    end

    if not duration or duration <= 0 then
        bar.SafeZone:Hide()
        return
    end

    local ratio = latency / duration
    if ratio > 1 then ratio = 1 end

    bar.SafeZone:SetWidth(bar:GetWidth() * ratio)
    bar.SafeZone:Show()
end

function Mod:UNIT_SPELLCAST_START(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_DELAYED" and not self.bar.casting then return end
    local name, text, texture, startTime, endTime = UnitCastingInfo(unit)
    if not name or not startTime or not endTime then
        if event == "UNIT_SPELLCAST_START" and not self._castRetrying then
            self._castRetrying = true
            C_Timer.After(0.01, function()
                self._castRetrying = false
                if UnitCastingInfo(unit) then
                    self:UNIT_SPELLCAST_START(event, unit, castGUID, spellID)
                end
            end)
        end
        return
    end

    self.bar.minValue  = startTime / 1000
    self.bar.maxValue  = endTime   / 1000
    self.bar:SetMinMaxValues(self.bar.minValue, self.bar.maxValue)
    self.bar:SetValue(GetTime())
    self.bar.Text:SetText(text)
    self.bar.Icon:SetTexture(texture)
    self.bar.casting   = true
    self.bar.channeling = false
    self.bar.empowering = false
    self.bar._ktDebugNearEndLogged = false
    self.bar.castID    = castGUID
    self:ClearChannelTicks()
    self.bar.Spark:Show()
    self:UpdateSafeZone()
    do
        local r, g, b, a = self:GetResolvedBarColor()
        self.bar:SetStatusBarColor(r, g, b, a)
    end
    self:StartBarUpdates()
    if self.bar:GetParent() ~= UIParent then
        self.bar:SetParent(UIParent)
    end
    self.bar:Show()
    self.bar:SetAlpha(1)
    if not self.bar:IsShown() then
        self.bar:SetParent(UIParent)
        self.bar:Show()
    end
    self:DebugCastBar(event or "UNIT_SPELLCAST_START", castGUID)
end

function Mod:UNIT_SPELLCAST_CHANNEL_START(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_CHANNEL_UPDATE" and not self.bar.channeling then return end
    if event == "UNIT_SPELLCAST_EMPOWER_UPDATE" and not self.bar.empowering then return end
    local name, text, texture, startTime, endTime, _, _, _, isEmpowered = UnitChannelInfo(unit)
    if not name or not startTime or not endTime then
        if (event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START") and not self._channelRetrying then
            self._channelRetrying = true
            C_Timer.After(0.01, function()
                self._channelRetrying = false
                if UnitChannelInfo(unit) then
                    self:UNIT_SPELLCAST_CHANNEL_START(event, unit, castGUID, spellID)
                end
            end)
        end
        return
    end

    self.bar.startTime  = startTime / 1000
    self.bar.endTime    = endTime   / 1000
    if isEmpowered and GetUnitEmpowerHoldAtMaxTime then
        local holdAtMax = GetUnitEmpowerHoldAtMaxTime(unit)
        if type(holdAtMax) == "number" and holdAtMax > 0 then
            self.bar.endTime = (endTime + holdAtMax) / 1000
        end
    end
    if isEmpowered then
        self.bar:SetMinMaxValues(self.bar.startTime, self.bar.endTime)
        self.bar:SetValue(GetTime())
    else
        local remaining = self.bar.endTime - GetTime()
        self.bar:SetMinMaxValues(0, math.max(self.bar.endTime - self.bar.startTime, 0))
        self.bar:SetValue(math.max(remaining, 0))
    end
    self.bar.Text:SetText(text or name)
    self.bar.Icon:SetTexture(texture)
    self.bar.casting    = false
    self.bar.channeling = not isEmpowered
    self.bar.empowering = not not isEmpowered
    self.bar._ktDebugNearEndLogged = false
    self.bar.castID     = castGUID
    self.bar.Spark:Show()
    if isEmpowered then
        self:UpdateEmpowerTicks(unit)
    else
        self:UpdateChannelTicks(
            ResolveChannelSpellID(unit, spellID),
            self.bar.startTime,
            self.bar.endTime
        )
    end

    self:UpdateSafeZone()

    do
        local r, g, b, a = self:GetResolvedBarColor()
        self.bar:SetStatusBarColor(r, g, b, a)
    end

    self:StartBarUpdates()

    if self.bar:GetParent() ~= UIParent then
        self.bar:SetParent(UIParent)
    end

    self.bar:Show()
    self.bar:SetAlpha(1)
    if not self.bar:IsShown() then
        self.bar:SetParent(UIParent)
        self.bar:Show()
    end
    self:DebugCastBar(event or "UNIT_SPELLCAST_CHANNEL_START", castGUID)
end

function Mod:HandleCastStop(eventCastID)
    if not self.bar or not (self.bar.casting or self.bar.channeling or self.bar.empowering) then return end
    if eventCastID and self.bar.castID and eventCastID ~= self.bar.castID then
        self:DebugCastBar("HandleCastStop mismatch", eventCastID)
        return
    end
    self:DebugCastBar("HandleCastStop match", eventCastID)
    self:HideBarNow()
end

function Mod:HandleCastFailed(eventCastID)
    if not self.bar or not (self.bar.casting or self.bar.channeling or self.bar.empowering) then return end
    if eventCastID and self.bar.castID and eventCastID ~= self.bar.castID then
        self:DebugCastBar("HandleCastFailed mismatch", eventCastID)
        return
    end
    self:DebugCastBar("HandleCastFailed match", eventCastID)
    self:HideBarNow()
end

function Mod:HandleChannelStop(eventCastID)
    if not self.bar or not (self.bar.casting or self.bar.channeling or self.bar.empowering) then return end
    if eventCastID and self.bar.castID and eventCastID ~= self.bar.castID then
        self:DebugCastBar("HandleChannelStop mismatch", eventCastID)
        return
    end
    self:DebugCastBar("HandleChannelStop match", eventCastID)
    self:HideBarNow()
end

function Mod:UNIT_SPELLCAST_STOP(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    self:HandleCastStop(castGUID)
end

function Mod:UNIT_SPELLCAST_FAILED(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    self:HandleCastFailed(castGUID)
end

function Mod:UNIT_SPELLCAST_INTERRUPTED(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    self:HandleCastFailed(castGUID)
end

function Mod:UNIT_SPELLCAST_CHANNEL_STOP(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    self:HandleChannelStop(castGUID)
end

function Mod:UNIT_SPELLCAST_EMPOWER_STOP(event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    self:HandleChannelStop(castGUID)
end

Mod.UNIT_SPELLCAST_DELAYED        = Mod.UNIT_SPELLCAST_START
Mod.UNIT_SPELLCAST_CHANNEL_UPDATE = Mod.UNIT_SPELLCAST_CHANNEL_START
Mod.UNIT_SPELLCAST_EMPOWER_START  = Mod.UNIT_SPELLCAST_CHANNEL_START
Mod.UNIT_SPELLCAST_EMPOWER_UPDATE = Mod.UNIT_SPELLCAST_CHANNEL_START

-- ============================================================================
-- Lock / Unlock / Refresh
-- ============================================================================
function Mod:Lock()
    if not self.bar then return end
    self.isDummy = false
    if not self.bar.casting and not self.bar.channeling and not self.bar.empowering then
        self.bar:SetAlpha(0)
        self.bar.Text:SetText("")
        self.bar.Time:SetText("")
    end
end

function Mod:Unlock()
    if not self.bar then return end
    self.isDummy = true
    self.bar:Show()
    self.bar:SetAlpha(1)
    self.bar:SetValue(50)
    self.bar:SetMinMaxValues(0, 100)
    self.bar.Text:SetText(LText("Cast Bar Preview"))
    self.bar.Icon:SetTexture(136243)
    self.bar.Icon:Show()
    self.bar.Time:SetText("2.5")
    do
        local r, g, b, a = self:GetResolvedBarColor()
        self.bar:SetStatusBarColor(r, g, b, a)
    end
end

function Mod:Refresh()
    if not KT.db.profile.castbar then
        KT.db.profile.castbar = {
            enable = true, autoPosition = true, autoWidth = true,
            width = 250, height = 20, scale = 1.0,
            frameStrata = "MEDIUM", frameLevel = 10, texture = "Melli",
            color = GetThemeAccentColorTable(),
            colorMode = "THEME",
            classColor = false,
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            font = KT and KT.DEFAULT_FONT_NAME or "AAA_ITC_Avant_Garde",
            fontSize = 16, fontOutline = "OUTLINE",
            showIcon = true, iconPosition = "LEFT", iconShape = "SQUARE",
        }
    end
    self.db = KT.db.profile.castbar
    if self.db.classColor == nil then
        self.db.classColor = false
    end
    if self.db.colorMode == nil then
        self.db.colorMode = "THEME"
    end
    if type(self.db.color) ~= "table" then
        local r, g, b = GetThemeAccentColor()
        self.db.color = { r = r, g = g, b = b, a = 1 }
    end
    C_Timer.After(0.1, function() self:SnapToTop() end)
    self:ApplySettings()
    if self.db and self.db.autoPosition == false then self:ApplyStoredManualPosition() end
    self:StartAutoWidthWatch()
    C_Timer.After(0.2, function() self:SnapToTop() end)
end

function Mod:CaptureCurrentCastBarPosition()
    local bar = self.bar
    if not (bar and UIParent and bar.GetCenter) then return nil end

    local centerX, centerY = bar:GetCenter()
    if not centerX or not centerY then return nil end

    local barScale = bar.GetEffectiveScale and bar:GetEffectiveScale() or 1
    local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not uiScale or uiScale == 0 then uiScale = 1 end

    return {
        x = (centerX * barScale / uiScale) - (UIParent:GetWidth() * 0.5),
        y = (centerY * barScale / uiScale) - (UIParent:GetHeight() * 0.5),
    }
end

function Mod:ApplyBlizzardCastBarPosition(frame, position)
    if not frame then return end
    if InCombatLockdown and InCombatLockdown() then
        C_Timer.After(0.5, function()
            self:ApplyBlizzardCastBarPosition(frame, position)
        end)
        return
    end

    if type(frame._ktOriginalPoints) == "table" and #frame._ktOriginalPoints > 0 then
        frame:ClearAllPoints()
        for _, point in ipairs(frame._ktOriginalPoints) do
            frame:SetPoint(unpack(point))
        end
    end
end

function Mod:RestoreBlizzardCastBar(frame)
    if not (frame and UIParent) then return end
    if InCombatLockdown and InCombatLockdown() then
        C_Timer.After(0.5, function()
            self:RestoreBlizzardCastBar(frame)
        end)
        return
    end

    if frame.SetParent and frame._ktOriginalParent and frame:GetParent() ~= frame._ktOriginalParent then
        frame:SetParent(frame._ktOriginalParent)
    end
    if frame.SetAlpha then
        frame:SetAlpha((self._blizzardOriginalAlpha and self._blizzardOriginalAlpha[frame]) or frame._ktOriginalAlpha or 1)
    end
    self:ApplyBlizzardCastBarPosition(frame, self._blizzardRestorePosition)
end

function Mod:OnDisable()
    self._suppressBlizzardCastBar = false
    if self.blizzardCastBarSuppressor then
        self.blizzardCastBarSuppressor:SetScript("OnUpdate", nil)
    end
    self:UnregisterAllEvents()
    self:StopAutoWidthWatch()
    if self.bar then
        self.bar:Hide()
    end

    local function RestoreAll()
        self:RestoreBlizzardCastBar(_G.PlayerCastingBarFrame)
        self:RestoreBlizzardCastBar(_G.OverlayPlayerCastingBarFrame)
    end

    RestoreAll()
    C_Timer.After(0, RestoreAll)
    C_Timer.After(0.2, RestoreAll)
end
-- ============================================================================
-- Slash debug
-- ============================================================================
SLASH_KTCASTBAR1 = "/ktcastbar"
SlashCmdList["KTCASTBAR"] = function(msg)
    if msg == "show" then
        Mod:Unlock()
    elseif msg == "hide" then
        Mod:Lock()
    elseif msg == "debug" then
        Mod._debugCastBar = not Mod._debugCastBar
        CastBarPrint("KT CastBar debug: " .. (Mod._debugCastBar and "ON" or "OFF"))
        if Mod._debugCastBar then
            Mod:DebugCastBar("manual dump")
        end
    elseif msg == "dump" then
        Mod:DebugCastBar("manual dump")
    elseif msg == "snap" then
        Mod:SnapToTop()
        CastBarPrint("KT CastBar: SnapToTop ejecutado")
        local t = _G.KUI_ResourceBarsTop
        CastBarPrint("  KUI_ResourceBarsTop:", t and (t:GetName() or tostring(t)) or "nil")
        CastBarPrint("  KUI_CDMBar_cooldowns:", _G["KUI_CDMBar_cooldowns"] and "exists" or "nil")
        CastBarPrint("  EssentialCooldownViewer:", _G.EssentialCooldownViewer and "exists" or "nil")
    else
        CastBarPrint("KT CastBar Commands:")
        CastBarPrint("  /ktcastbar show   - Preview")
        CastBarPrint("  /ktcastbar hide   - Ocultar")
        CastBarPrint("  /ktcastbar snap   - Forzar re-anclaje y debug")
        CastBarPrint("  /ktcastbar debug  - Toggle debug de eventos")
        CastBarPrint("  /ktcastbar dump   - Estado actual")
    end
end

-- ============================================================================
-- Ventana de config (sin cambios respecto al original)
-- ============================================================================
local function CreateConfigSlider(parent, label, minVal, maxVal, step, yOffset, getValue, setValue)
    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", 10, yOffset)
    labelText:SetText(label)

    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPRIGHT", -10, yOffset)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 10, yOffset - 20)
    slider:SetWidth(parent:GetWidth() - 20)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    if slider.Low  then slider.Low:SetText("")  end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("")  end

    slider:SetScript("OnValueChanged", function(self, value)
        if parent.isUpdating then return end
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(string.format("%.0f", value))
        setValue(value)
    end)
    slider.Update = function(self)
        parent.isUpdating = true
        local value = getValue()
        self:SetValue(value)
        valueText:SetText(string.format("%.0f", value))
        parent.isUpdating = false
    end
    return slider
end

local function CreateConfigCheckbox(parent, label, yOffset, getFunc, setFunc)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", 10, yOffset)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    text:SetText(label)
    cb:SetScript("OnClick", function(self) setFunc(self:GetChecked()) end)
    cb.Update = function(self) self:SetChecked(getFunc()) end
    return cb
end

function Mod:CreateCastBarConfigMenu()
    if self.ConfigMenu then return self.ConfigMenu end

    local menu = CreateFrame("Frame", "KT_CastBarConfigMenu", UIParent, "BackdropTemplate")
    menu:SetSize(220, 280)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(200)
    menu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    menu:EnableMouse(true)
    menu:SetMovable(true)
    menu:RegisterForDrag("LeftButton")
    menu:SetClampedToScreen(true)
    menu:Hide()

    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText(LText("Cast Bar Settings"))

    local closeBtn = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() menu:Hide() end)

    menu:SetScript("OnDragStart", function(self) self:StartMoving() end)
    menu:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    local yPos = -40
    menu.autoPosBtn   = CreateConfigCheckbox(menu, "Auto Position", yPos,
        function() return self.db.autoPosition end,
        function(v) self.db.autoPosition = v; self:SnapToTop() end)
    yPos = yPos - 30
    menu.autoWidthBtn = CreateConfigCheckbox(menu, "Auto Width", yPos,
        function() return self.db.autoWidth end,
        function(v)
            self.db.autoWidth = v
            if v then
                self:SnapToTop()
                self:StartAutoWidthWatch()
            else
                self:StopAutoWidthWatch()
            end
        end)
    yPos = yPos - 40
    menu.widthSlider  = CreateConfigSlider(menu, "Width",  100, 600, 1, yPos,
        function() return self.db.width end,
        function(v) self.db.width = v; self:ApplySettings() end)
    yPos = yPos - 50
    menu.heightSlider = CreateConfigSlider(menu, "Height", 10, 100, 1, yPos,
        function() return self.db.height end,
        function(v) self.db.height = v; self:ApplySettings() end)
    yPos = yPos - 50

    local iconBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    iconBtn:SetSize(140, 24)
    iconBtn:SetPoint("TOP", 0, yPos)
    iconBtn:SetText(LText("Toggle Icon Side"))
    iconBtn:SetScript("OnClick", function()
        self.db.iconPosition = (self.db.iconPosition == "LEFT" and "RIGHT" or "LEFT")
        self:ApplySettings()
    end)

    self.ConfigMenu = menu
    return menu
end

function Mod:ShowCastBarConfigMenu()
    local menu = self:CreateCastBarConfigMenu()
    menu.autoPosBtn:Update()
    menu.autoWidthBtn:Update()
    menu.widthSlider:Update()
    menu.heightSlider:Update()
    menu:ClearAllPoints()
    menu:SetPoint("CENTER", UIParent, "CENTER")
    menu:Show()
end
