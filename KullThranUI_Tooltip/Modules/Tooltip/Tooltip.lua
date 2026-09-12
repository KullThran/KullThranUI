local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local TT = KT:NewModule("Tooltip", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

-- ============================================================================
-- CONFIGURACIÓN DE BANDAS
-- ============================================================================
local RAIDS_TO_TRACK = {
    {
        name = "TWW", -- The War Within
        maxBosses = 8,
        NM = { 40297, 40298, 40299, 40300, 40301, 40302, 40303, 40304 },
        HC = { 40305, 40306, 40307, 40308, 40309, 40310, 40311, 40312 },
        M  = { 40313, 40314, 40315, 40316, 40317, 40318, 40319, 40320 }
    },
    {
        name = "Midnight", -- The Voidspire (Raid 1)
        maxBosses = 6,
        NM = { 0, 0, 0, 0, 0, 0 }, 
        HC = { 0, 0, 0, 0, 0, 0 },
        M  = { 0, 0, 0, 0, 0, 0 }
    }
}

-- ============================================================================
-- API & VARIABLES
-- ============================================================================
local _G = _G
local select, tonumber, pairs, ipairs, string, table = select, tonumber, pairs, ipairs, string, table
local UnitName, UnitLevel, UnitRace, UnitClass, UnitGUID = UnitName, UnitLevel, UnitRace, UnitClass, UnitGUID
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local GetGuildInfo = GetGuildInfo
local C_TooltipInfo, C_Item, C_PlayerInfo, C_Spell = C_TooltipInfo, C_Item, C_PlayerInfo, C_Spell
local NotifyInspect, ClearInspectPlayer = NotifyInspect, ClearInspectPlayer
local GetAchievementInfo = GetAchievementInfo
local GetAchievementComparisonInfo = GetAchievementComparisonInfo 
local SetAchievementComparisonUnit, ClearAchievementComparisonUnit = SetAchievementComparisonUnit, ClearAchievementComparisonUnit
local GetSpecialization, GetSpecializationRole, GetInspectSpecialization, GetSpecializationRoleByID = GetSpecialization, GetSpecializationRole, GetInspectSpecialization, GetSpecializationRoleByID
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
local C_PvP = C_PvP
local GetMacroInfo = GetMacroInfo
local issecretvalue = issecretvalue
local GetMacroSpell = GetMacroSpell
local GetMacroItem = GetMacroItem
local GetActionInfo = GetActionInfo
local GetActionTexture = GetActionTexture
local GetMouseFocus = GetMouseFocus
local GetMouseFoci = GetMouseFoci
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown

-- Colores
local COLOR_SECTION_HEADER = "|cff00ccff"
local COLOR_VALUE_TEXT     = "|cffffffff"
local COLOR_LABEL_TEXT     = "|cffffd100"
local COLOR_GUILD          = "|cff40ff40"
local TOOLTIP_UNIT_INFO_HEADERS = {
    ["Mythic+ Score:"] = true,
    ["PvP Rating:"] = true,
    ["Item Level:"] = true,
    ["Raid Progress:"] = true,
}

-- Variables de estado
local lastInspectRequest = 0
local inspectGUID = nil
local inspectCache = {}
local inspectRequests = {}
local INSPECT_CACHE_TTL = 300
local INSPECT_REQUEST_COOLDOWN = 10

local function StripSecretValue(value)
    if value ~= nil and ((issecretvalue and issecretvalue(value)) or (_G.canaccessvalue and not _G.canaccessvalue(value))) then
        return nil
    end
    return value
end

local function GetSafeMouseFocus()
    if GetMouseFoci then
        local ok, foci = pcall(GetMouseFoci)
        if ok and StripSecretValue(foci) and type(foci) == "table" then
            return StripSecretValue(foci[1])
        end
    elseif GetMouseFocus then
        local ok, focus = pcall(GetMouseFocus)
        if ok then return StripSecretValue(focus) end
    end
end
local function SafeValueEquals(left, right)
    if left == nil or right == nil then return false end
    if issecretvalue and (issecretvalue(left) or issecretvalue(right)) then
        return false
    end
    return left == right
end

local function NormalizeTooltipText(text)
    if type(text) ~= "string" then return "" end
    -- In Midnight 12.x, GetText() inside securecallfunction chains can return a
    -- tainted "secret" string. type() still says "string" but indexing it (gsub)
    -- raises a taint error. pcall catches that and returns "" safely.
    local ok, result = pcall(function(t)
        t = t:gsub("|c%x%x%x%x%x%x%x%x", "")
        t = t:gsub("|r", "")
        t = t:gsub("|T.-|t", "")
        t = t:gsub("%s+", " ")
        return strtrim(t)
    end, text)
    return ok and result or ""
end

local function SafeUnitCall(func, ...)
    if not func then return nil end
    local ok, a, b, c, d, e = pcall(func, ...)
    if not ok then return nil end
    return StripSecretValue(a), StripSecretValue(b), StripSecretValue(c), StripSecretValue(d), StripSecretValue(e)
end

local function SafeUnitPredicate(func, ...)
    local result = SafeUnitCall(func, ...)
    return result == true
end

local function SafeGetTooltipUnit(tooltip)
    if not tooltip or tooltip:IsForbidden() or not tooltip.GetUnit then return nil end

    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or type(unit) ~= "string" then
        return nil
    end

    if issecretvalue and issecretvalue(unit) then
        return nil
    end

    if not SafeUnitPredicate(UnitExists, unit) then
        return nil
    end

    return unit
end

local function FormatItemLevel(ilvl)
    ilvl = tonumber(ilvl)
    if not ilvl or ilvl <= 0 then return nil end
    return string.format("|cffffffff%d|r", ilvl)
end

function TT:GetCachedInspectInfo(guid)
    if not guid or (issecretvalue and issecretvalue(guid)) then return nil end
    local data = inspectCache[guid]
    if not data then return nil end

    local now = GetTime and GetTime() or 0
    if data.time and now > 0 and (now - data.time) > INSPECT_CACHE_TTL then
        return nil
    end
    return data
end

function TT:SetCachedInspectInfo(guid, values)
    if not guid or (issecretvalue and issecretvalue(guid)) or not values then return end
    local data = inspectCache[guid] or {}
    for key, value in pairs(values) do
        data[key] = value
    end
    data.time = GetTime and GetTime() or 0
    inspectCache[guid] = data
end

function TT:CanRequestInspect(guid)
    if not guid or (issecretvalue and issecretvalue(guid)) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local now = GetTime and GetTime() or 0
    local cached = self:GetCachedInspectInfo(guid)
    if cached and cached.time and now > 0 and (now - cached.time) < INSPECT_REQUEST_COOLDOWN then
        return false
    end
    if inspectRequests[guid] and now > 0 and (now - inspectRequests[guid]) < INSPECT_REQUEST_COOLDOWN then
        return false
    end
    return true
end

local function GetRoleIcon(role)
    if role == "TANK" then
        return "|TInterface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\Tank.png:16:16:0:0|t"
    elseif role == "HEALER" then
        return "|TInterface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\Healer.png:16:16:0:0|t"
    elseif role == "DAMAGER" then
        return "|TInterface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\DPS.png:16:16:0:0|t"
    end
    return ""
end

local function FormatTargetingPlayerName(unitToken)
    local name = SafeUnitCall(UnitName, unitToken)
    if not name or name == "" then return nil end

    local _, classFilename = (KT.SafeUnitClass or UnitClass)(unitToken)
    local classColor = classFilename and C_ClassColor.GetClassColor(classFilename)
    if classColor then
        return string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, name)
    end
    return COLOR_VALUE_TEXT .. name .. "|r"
end

local function AddTargetingPlayer(matches, seen, sourceUnit, targetUnit)
    if not (sourceUnit and targetUnit and UnitGUID) then return end
    local sourceTarget = sourceUnit == "player" and "target" or (sourceUnit .. "target")
    local sourceTargetGUID = SafeUnitCall(UnitGUID, sourceTarget)
    local targetGUID = SafeUnitCall(UnitGUID, targetUnit)
    if not (sourceTargetGUID and targetGUID and SafeValueEquals(sourceTargetGUID, targetGUID)) then return end

    local guid = SafeUnitCall(UnitGUID, sourceUnit)
    local key = guid or sourceUnit
    if seen[key] then return end
    seen[key] = true

    local displayName = FormatTargetingPlayerName(sourceUnit)
    if displayName then
        matches[#matches + 1] = displayName
    end
end

local function GetTargetingPlayersText(unit)
    local matches, seen = {}, {}
    AddTargetingPlayer(matches, seen, "player", unit)

    if IsInRaid and IsInRaid() then
        local total = (GetNumGroupMembers and GetNumGroupMembers()) or 0
        for i = 1, math.min(total, 40) do
            AddTargetingPlayer(matches, seen, "raid" .. i, unit)
        end
    else
        for i = 1, 4 do
            AddTargetingPlayer(matches, seen, "party" .. i, unit)
        end
    end

    if #matches == 0 then return nil end

    local maxShown = 8
    local shown = {}
    for i = 1, math.min(#matches, maxShown) do
        shown[#shown + 1] = matches[i]
    end
    local text = table.concat(shown, ", ")
    if #matches > maxShown then
        text = text .. string.format(" |cffaaaaaa+%d|r", #matches - maxShown)
    end
    return text
end

function TT:OnInitialize()
    self.db = KT.db.profile.tooltip
    if self.db.font == nil then self.db.font = "PT Sans Narrow" end
    if self.db.fontSize == nil then self.db.fontSize = 12 end
    if self.db.scoreType == nil then self.db.scoreType = "M+" end
    if self.db.showTargetingPlayers == nil then self.db.showTargetingPlayers = true end
end

-- [FIX] Función robusta para obtener el Rol de Raider.IO
function TT:GetRaiderIORole(unit)
    if not (_G.RaiderIO and _G.RaiderIO.GetProfile) then return nil end
    
    -- 1. Intentar obtener perfil (con fallback de Reino)
    local profile = _G.RaiderIO.GetProfile(unit)
    if not profile then
        local name, realm = UnitName(unit)
        if name then
            if not realm or realm == "" then realm = GetRealmName() end
            if realm then 
                realm = string.gsub(realm, " ", "") -- Raider.IO requiere reino sin espacios
                profile = _G.RaiderIO.GetProfile(name .. "-" .. realm) 
            end
        end
    end
    
    if not profile then return nil end


    
    -- 2. Intentar campo directo (mplusMainRole)
    if profile.mplusMainRole then
        if profile.mplusMainRole == "tank" then return "TANK"
        elseif profile.mplusMainRole == "healer" then return "HEALER"
        elseif profile.mplusMainRole == "dps" then return "DAMAGER" end
    end
    
    -- 3. [FIX] Fallback: Deducir rol desde el nombre de la Spec principal (ej: "Equilibrio" -> DAMAGER)
    if profile.mythicKeystoneProfile and profile.mythicKeystoneProfile.mainSpec then
        local _, _, classID = UnitClass(unit)
        if classID then
            for i = 1, 4 do
                local _, specName, _, _, role = GetSpecializationInfoForClassID(classID, i)
                if specName == profile.mythicKeystoneProfile.mainSpec then
                    return role
                end
            end
        end
    end
    
    return nil
end

function TT:UpdateGlobalFonts()
    local fontName = self.db.font or "PT Sans Narrow"
    local fontPath = LSM:Fetch("font", fontName) or GameFontNormal:GetFont()
    local size = self.db.fontSize or 12

    -- [FIX] Disabled global font overrides for Tooltip to prevent Blizzard UI taint (secret number value errors)
    -- if GameTooltipHeaderText then GameTooltipHeaderText:SetFont(fontPath, size + 2, "OUTLINE") end
    -- if Tooltip_MedFont then Tooltip_MedFont:SetFont(fontPath, size, "") end
    -- if Tooltip_SmallFont then Tooltip_SmallFont:SetFont(fontPath, size, "") end
end

function TT:OnEnable()
    self.db = KT.db.profile.tooltip
    if not self.db.enable then return end
    self:UpdateGlobalFonts()
    -- Leave Blizzard's generic GameTooltip show/update flow untouched.
    -- Styling is applied only to supported tooltip data types below.

    if TooltipDataProcessor then
        if not self.hooksAdded then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
                if tooltip == _G.GameTooltip then self:OnTooltipSetUnit(tooltip) end
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
                if tooltip == _G.GameTooltip then self:OnTooltipSetItem(tooltip) end
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip)
                if tooltip == _G.GameTooltip then self:OnTooltipSetSpell(tooltip) end
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Macro, function(tooltip)
                if tooltip == _G.GameTooltip then self:OnTooltipSetMacro(tooltip) end
            end)
            self.hooksAdded = true
        end
    else
        self:HookScript(_G.GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")
        self:HookScript(_G.GameTooltip, "OnTooltipSetItem", "OnTooltipSetItem")
        self:HookScript(_G.GameTooltip, "OnTooltipSetSpell", "OnTooltipSetSpell")
    end
    if _G.GameTooltip and not self.iconResetHooksAdded then
        _G.GameTooltip:HookScript("OnHide", function(tooltip)
            TT:ResetIcon(tooltip)
        end)
        _G.GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
            TT:ResetIcon(tooltip)
        end)
        self.iconResetHooksAdded = true
    end


    self:RegisterEvent("INSPECT_READY")
    self:SetupPositioning()
    self:StyleHealthBar()
end

function TT:OnDisable()
    self:UnhookAll()
    self:UnregisterAllEvents()
    local sb = GameTooltipStatusBar
    if sb and sb.bg then sb.bg:Hide() end
    if _G.GameTooltip then self:ResetIcon(_G.GameTooltip) end
end

function TT:Refresh()
    self.db = KT.db.profile.tooltip
    if not self.db.enable then 
        self:OnDisable()
        return 
    end
    self:UpdateGlobalFonts()
    if _G.GameTooltip and _G.GameTooltip:IsShown() then
        local _, itemLink = _G.GameTooltip:GetItem()
        local _, spellID = _G.GameTooltip:GetSpell()
        local unit = SafeGetTooltipUnit(_G.GameTooltip)
        if itemLink or spellID or unit then
            self:StyleTooltip(_G.GameTooltip)
        end
    end
    self:StyleHealthBar()
end

function TT:SetupPositioning()
    -- 1. Crear Frame de Anclaje (Mover)
    if not self.anchor then
        self.anchor = CreateFrame("Frame", "KT_TooltipAnchor", _G.UIParent, "BackdropTemplate")
        self.anchor:SetSize(240, 80)
        self.anchor:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 35, 395)
        self.anchor:SetFrameStrata("TOOLTIP")
        self.anchor:Hide()
    end

    -- 2. Registrar el Mover en EditMode
    local EM = KT:GetModule("EditMode", true)
    if EM then
        EM:RegisterFrame(self.anchor, "Tooltip Anchor", "tooltip_anchor", { 
            resizable = false,
            onEnter = function() 
                self.anchor:Show()
                
                self.anchor:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 2,
                })
                self.anchor:SetBackdropColor(KT.C_R or 0.85, KT.C_G or 0.15, KT.C_B or 0.15, 0.25)
                self.anchor:SetBackdropBorderColor(KT.C_R or 0.85, KT.C_G or 0.15, KT.C_B or 0.15, 1)

                if not self.anchor.text then
                    self.anchor.text = self.anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                    self.anchor.text:SetPoint("CENTER")
                    self.anchor.text:SetText(LText("Tooltip Anchor"))
                end
                self.anchor.text:SetTextColor(KT.C_R or 0.85, KT.C_G or 0.15, KT.C_B or 0.15)
            end,
            onExit = function() 
                self.anchor:Hide()
            end
        })
    end

    -- 3. Hook para forzar la posición al Mover
    -- 3. Leave Blizzard''s default GameTooltip anchoring untouched.
    -- Reanchoring the global tooltip can taint widget/world-content tooltip paths.
end

-- ============================================================================
-- ESTILOS
-- ============================================================================

function TT:StyleTooltip(tooltip)
    if tooltip.NineSlice then tooltip.NineSlice:SetAlpha(0) end
    if tooltip.SetBackdrop then tooltip:SetBackdrop(nil) end
    
    -- Textures are visual-only children and do NOT participate in the frame's layout geometry.
    if not tooltip.ktBackdrop then
        local bg = tooltip:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -1, 1)
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

        local top = tooltip:CreateTexture(nil, "BORDER", nil, 0)
        top:SetHeight(1); top:SetPoint("TOPLEFT", tooltip, "TOPLEFT"); top:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT")
        local bottom = tooltip:CreateTexture(nil, "BORDER", nil, 0)
        bottom:SetHeight(1); bottom:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT")
        local left = tooltip:CreateTexture(nil, "BORDER", nil, 0)
        left:SetWidth(1); left:SetPoint("TOPLEFT", tooltip, "TOPLEFT"); left:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT")
        local right = tooltip:CreateTexture(nil, "BORDER", nil, 0)
        right:SetWidth(1); right:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT"); right:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT")

        tooltip.ktBackdrop = {
            bg = bg, top = top, bottom = bottom, left = left, right = right,
            SetBackdropColor = function(self, r, g, b, a) self.bg:SetColorTexture(r, g, b, a) end,
            SetBackdropBorderColor = function(self, r, g, b, a)
                self.top:SetColorTexture(r, g, b, a); self.bottom:SetColorTexture(r, g, b, a)
                self.left:SetColorTexture(r, g, b, a); self.right:SetColorTexture(r, g, b, a)
            end,
        }
        tooltip.ktBackdrop:SetBackdropBorderColor(0, 0, 0, 1)
    end
    
    if not tooltip.IsStyled then
        -- ICONO (Pixel Perfect 1,1)
        tooltip.ktIcon = tooltip:CreateTexture(nil, "OVERLAY", nil, 7)
        tooltip.ktIcon:SetSize(38, 38)
        tooltip.ktIcon:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", -1, 1) 
        tooltip.ktIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tooltip.ktIcon:Hide()
        
        tooltip.ktIconBorder = tooltip:CreateTexture(nil, "OVERLAY", nil, 7)
        tooltip.ktIconBorder:SetPoint("TOPLEFT", tooltip.ktIcon, "TOPLEFT", -1, 1)
        tooltip.ktIconBorder:SetPoint("BOTTOMRIGHT", tooltip.ktIcon, "BOTTOMRIGHT", 1, -1)
        tooltip.ktIconBorder:SetDrawLayer("OVERLAY", -1)
        tooltip.ktIconBorder:SetColorTexture(0, 0, 0, 1)
        tooltip.ktIconBorder:Hide()

        tooltip.IsStyled = true
    end

    if not tooltip.GetItem then return end -- Seguridad extra
    local _, link = tooltip:GetItem()
    local _, spellID = tooltip:GetSpell()
    if not link and not spellID then
        if tooltip.ktIcon then tooltip.ktIcon:Hide(); tooltip.ktIconBorder:Hide() end
    end


    
    self:ApplyBorderColor(tooltip)
end

function TT:AttachIcon(tooltip, iconTexture)
    if not tooltip.ktIcon or not iconTexture then return end
    tooltip.ktIcon:SetTexture(iconTexture)
    tooltip.ktIcon:Show()
    tooltip.ktIconBorder:Show()
end

function TT:ResetIcon(tooltip)
    if tooltip.ktIcon then
        tooltip.ktIcon:Hide()
        tooltip.ktIconBorder:Hide()
        tooltip.ktIcon:SetTexture(nil)
    end
end

local function ResolveSpellTexture(spellID)
    if not spellID then return nil end
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if icon then return icon end
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    return info and info.iconID or nil
end

function TT:GetActionMacroIcon(macroID)
    if not macroID then return nil end

    local _, icon = GetMacroInfo and GetMacroInfo(macroID)
    if icon and icon ~= 134400 and icon ~= "Interface\\Icons\\INV_Misc_QuestionMark" then
        return icon
    end

    if GetMacroSpell then
        local macroSpell = GetMacroSpell(macroID)
        if type(macroSpell) == "number" then
            icon = ResolveSpellTexture(macroSpell)
            if icon then return icon end
        end
    end

    if GetMacroItem and C_Item and C_Item.GetItemIconByID then
        local _, itemID = GetMacroItem(macroID)
        if itemID then
            icon = C_Item.GetItemIconByID(itemID)
            if icon then return icon end
        end
    end

    return nil
end

function TT:GetFocusedActionTooltipIcon()
    local focus = GetSafeMouseFocus()
    local current = focus

    while current do
        local slot = StripSecretValue(current.action or current._state_action or (current.GetAttribute and current:GetAttribute("action")))
        if type(slot) == "number" then
            local actionType, actionID = GetActionInfo(slot)
            if actionType == "macro" and actionID then
                return self:GetActionMacroIcon(actionID) or GetActionTexture(slot)
            end
            if actionType == "spell" and actionID then
                return GetActionTexture(slot) or ResolveSpellTexture(actionID)
            end
            if actionType == "item" then
                return GetActionTexture(slot)
            end
        end
        current = current.GetParent and current:GetParent() or nil
    end

    return nil
end

function TT:GetTooltipIconFallback(tooltip, spellID)
    local icon = tooltip and tooltip._ktSourceIconTexture
    if icon then return icon end

    icon = ResolveSpellTexture(spellID)
    if icon then return icon end

    return self:GetFocusedActionTooltipIcon()
end

function TT:StyleHealthBar()
    if not self.db.enable then return end
    local sb = GameTooltipStatusBar
    if not sb or sb:IsForbidden() then return end
    sb:SetHeight(6)
    sb:ClearAllPoints()
    sb:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 0, 2)
    sb:SetPoint("BOTTOMRIGHT", GameTooltip, "TOPRIGHT", 0, 2)
    sb:SetStatusBarTexture(LSM:Fetch("statusbar", "Details Flat") or "Interface\\TargetingFrame\\UI-StatusBar")
    
    if not sb.bg then
        sb.bg = sb:CreateTexture(nil, "BACKGROUND")
        sb.bg:SetAllPoints()
        sb.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    end
    sb.bg:Show()

    if not sb.ktColorHooksAdded then
        sb:HookScript("OnShow", function()
            TT:RefreshTooltipStatusBarColor()
        end)
        sb:HookScript("OnValueChanged", function()
            TT:RefreshTooltipStatusBarColor()
        end)
        hooksecurefunc(sb, "SetStatusBarColor", function()
            if TT._settingTooltipStatusBarColor then return end
            TT:RefreshTooltipStatusBarColor()
        end)
        sb.ktColorHooksAdded = true
    end
end

function TT:SetTooltipStatusBarColor(unit)
    local sb = GameTooltipStatusBar
    if not sb or sb:IsForbidden() or not unit then return end
    if issecretvalue and issecretvalue(unit) then return end
 
    local r, g, b = 0, 1, 0
 
    if SafeUnitPredicate(UnitIsPlayer, unit) then
        local _, classFilename = (KT.SafeUnitClass or UnitClass)(unit)
        local classColor = classFilename and C_ClassColor.GetClassColor(classFilename)
        if classColor then r, g, b = classColor.r, classColor.g, classColor.b end
    else
        local reaction = SafeUnitCall(UnitReaction, unit, "player")
        local reactionColor = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
        if reactionColor then
            r, g, b = reactionColor.r, reactionColor.g, reactionColor.b
        else
            local tapDenied = SafeUnitPredicate(UnitIsTapDenied, unit)
            local isFriend = SafeUnitPredicate(UnitIsFriend, "player", unit)
            if tapDenied then
                r, g, b = 0.55, 0.55, 0.55
            elseif isFriend then
                r, g, b = 0, 1, 0
            else
                r, g, b = 1, 0, 0
            end
        end
    end
 
    self._settingTooltipStatusBarColor = true
    sb:SetStatusBarColor(r, g, b)
    self._settingTooltipStatusBarColor = nil
end

function TT:RefreshTooltipStatusBarColor(tooltip)
    if not self.db.enable then return end

    tooltip = tooltip or _G.GameTooltip
    if not tooltip or tooltip:IsForbidden() or not tooltip:IsShown() then return end

    local unit = SafeGetTooltipUnit(tooltip)
    if not unit then return end

    self:SetTooltipStatusBarColor(unit)
end

function TT:FindTooltipLineIndex(tooltip, predicate, startLine)
    if not tooltip or not predicate then return nil end

    for i = startLine or 2, tooltip:NumLines() do
        local left = _G[tooltip:GetName().."TextLeft"..i]
        local text = left and NormalizeTooltipText(left:GetText()) or ""
        if predicate(text, i, left) then
            return i, left
        end
    end
end

function TT:EnsureUnitInfoSpacer(tooltip)
    for i = 2, tooltip:NumLines() do
        local left = _G[tooltip:GetName().."TextLeft"..i]
        local text = left and NormalizeTooltipText(left:GetText()) or ""
        if TOOLTIP_UNIT_INFO_HEADERS[text] then
            return
        end
    end

    tooltip:AddLine(" ")
end

function TT:ApplyBorderColor(tooltip)
    if not tooltip or tooltip:IsForbidden() or not tooltip.SetBackdropBorderColor then return end
    local unit = SafeGetTooltipUnit(tooltip)
    local _, link = tooltip:GetItem()
    local _, spellID = tooltip:GetSpell()
    
    local r, g, b = 0.6, 0.6, 0.6 

    if unit then
        if SafeUnitPredicate(UnitIsPlayer, unit) then
            local _, classFilename = (KT.SafeUnitClass or UnitClass)(unit)
            if classFilename then
                local c = C_ClassColor.GetClassColor(classFilename)
                if c then r, g, b = c.r, c.g, c.b end
            end
        end
    elseif link then
        local quality = C_Item.GetItemQualityByID(link)
        if quality then r, g, b = C_Item.GetItemQualityColor(quality) end
    elseif spellID then
        r, g, b = 0.2, 0.6, 1 
    else
        r, g, b = 0, 0, 0
    end
    
    if tooltip.ktBackdrop then
        tooltip.ktBackdrop:SetBackdropBorderColor(r, g, b, 1)
    end
    if tooltip.ktIconBorder then tooltip.ktIconBorder:SetColorTexture(r, g, b, 1) end
end

-- Actualización en tiempo real
function TT:OnTooltipUpdate(tooltip)
    if not self.db.enable or tooltip:IsForbidden() then return end

    local unit = SafeGetTooltipUnit(tooltip)
    if unit then
        self:SetTooltipStatusBarColor(unit)
    end
end

-- ============================================================================
-- 1. TOOLTIP DE JUGADOR (UNIT)
-- ============================================================================

function TT:OnTooltipSetUnit(tooltip)
    if not self.db.enable or tooltip:IsForbidden() then return end
    self:ResetIcon(tooltip)
    local unit = SafeGetTooltipUnit(tooltip)
    if not unit then return end
    
    if not SafeUnitPredicate(UnitIsPlayer, unit) then return end

    local name, realm = SafeUnitCall(UnitName, unit)
    if not name or name == "" then return end

    local _, classFilename = (KT.SafeUnitClass or UnitClass)(unit)
    local classColor = C_ClassColor.GetClassColor(classFilename) or {r=1, g=1, b=1}
    local level = SafeUnitCall(UnitLevel, unit) or -1
    local guildName, guildRankName = SafeUnitCall(GetGuildInfo, unit)
    local race = SafeUnitCall(UnitRace, unit) or ""

    self:SetTooltipStatusBarColor(unit)
    
    local nameText = _G[tooltip:GetName().."TextLeft1"]
    local realmText = (realm and realm ~= "") and ("-"..realm) or ""
    if nameText then
        nameText:SetText(string.format("|cff%02x%02x%02x%s|r%s", classColor.r*255, classColor.g*255, classColor.b*255, name, realmText))
    end

    local levelPrefix = NormalizeTooltipText(LEVEL or "Level")
    local levelLineIndex = self:FindTooltipLineIndex(tooltip, function(text)
        return text ~= "" and text:find(levelPrefix, 1, true) == 1
    end, 2) or (guildName and 3 or 2)

    local line2 = _G[tooltip:GetName().."TextLeft"..levelLineIndex]
    if line2 then
        local levelColor = GetQuestDifficultyColor(level)
        local levelText = string.format("|cff%02x%02x%02x%s|r", levelColor.r*255, levelColor.g*255, levelColor.b*255, level)
        local className = (KT.SafeUnitClass or UnitClass)(unit) or ""
        line2:SetText(string.format("Level %s %s %s", levelText, race, className))
        line2:SetTextColor(1, 1, 1)
    end

    if guildName then
        local guildText = string.format("%s<%s>|r  |cffaaaaaa%s|r", COLOR_GUILD, guildName, (guildRankName or ""))
        local guildLineIndex = self:FindTooltipLineIndex(tooltip, function(text)
            return text ~= "" and text:find("<"..guildName..">", 1, true) ~= nil
        end, 2)

        if guildLineIndex then
            local guildLine = _G[tooltip:GetName().."TextLeft"..guildLineIndex]
            if guildLine then
                guildLine:SetText(guildText)
            end
        else
            tooltip:AddLine(guildText)
        end
    end

    self:EnsureUnitInfoSpacer(tooltip)

    if self.db.showTargetingPlayers ~= false then
        local targetingPlayers = GetTargetingPlayersText(unit)
        if targetingPlayers then
            self:UpdateLine(tooltip, "Targeted by:", targetingPlayers)
        end
    end

    -- Score (M+ / PvP)
    local scoreType = self.db.scoreType or "M+"
    local isRaiderIOLoaded = C_AddOns.IsAddOnLoaded("RaiderIO")
    
    if scoreType == "M+" and not isRaiderIOLoaded then
        local score = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        local roleIcon = ""
        
        -- [FIX] Usar nueva función robusta para detectar el rol de RIO
        local rioRole = self:GetRaiderIORole(unit)

        if rioRole then
            roleIcon = GetRoleIcon(rioRole)
        else
            -- Fallback: Rol actual (Spec)
            if SafeUnitPredicate(UnitIsUnit, unit, "player") then
                local spec = GetSpecialization()
                if spec then roleIcon = GetRoleIcon(GetSpecializationRole(spec)) end
            else
                local specID = SafeUnitCall(GetInspectSpecialization, unit)
                if specID and specID > 0 then
                    roleIcon = GetRoleIcon(GetSpecializationRoleByID(specID))
                end
            end
        end
        if roleIcon ~= "" then roleIcon = " " .. roleIcon end

        if score and score.currentSeasonScore and score.currentSeasonScore > 0 then
            local color = C_ChallengeMode.GetDungeonScoreRarityColor(score.currentSeasonScore) or {r=1,g=1,b=1}
            tooltip:AddDoubleLine("Mythic+ Score:", score.currentSeasonScore .. roleIcon, 1, 0.8, 0, color.r, color.g, color.b)
        else
            tooltip:AddDoubleLine("Mythic+ Score:", "...", 1, 0.8, 0, 0.5, 0.5, 0.5)
        end
    elseif scoreType == "PVP" then
        self:EnsureLine(tooltip, "PvP Rating:", "|cff808080...|r")
    end

    local guid = SafeUnitCall(UnitGUID, unit)
    local cachedInspect = guid and self:GetCachedInspectInfo(guid)
    self:EnsureLine(tooltip, "Item Level:", (cachedInspect and cachedInspect.ilvlText) or "|cff808080...|r")
    if not isRaiderIOLoaded then
        self:EnsureLine(tooltip, "Raid Progress:", "|cff808080...|r")
    end

    local canInspect = SafeUnitCall(CanInspect, unit)
    local now = GetTime and GetTime() or 0
    if canInspect and NotifyInspect and guid and self:CanRequestInspect(guid) and (now - lastInspectRequest > 2) then
        lastInspectRequest = now
        inspectRequests[guid] = now
        inspectGUID = guid
        NotifyInspect(unit)
    end

    self:StyleTooltip(tooltip)
    -- tooltip:Show() -- [FIX] Removed to prevent conflicts
end

-- ============================================================================
-- 4. TOOLTIP DE MACROS
-- ============================================================================

function TT:OnTooltipSetMacro(tooltip)
    if not self.db.enable or not tooltip or tooltip:IsForbidden() then return end
    self:ResetIcon(tooltip)
    local data = tooltip:GetTooltipData()
    if not data or not data.id then return end


    local icon = self:GetActionMacroIcon(data.id) or self:GetFocusedActionTooltipIcon()
    if icon then self:AttachIcon(tooltip, icon) end

    self:StyleTooltip(tooltip)
    -- tooltip:Show() -- [FIX] Removed to prevent conflicts
end

function TT:EnsureLine(tooltip, headerText, defaultText)
    for i = 2, tooltip:NumLines() do
        local left = _G[tooltip:GetName().."TextLeft"..i]
        if left then
            -- GetText() inside securecallfunction chains can return a tainted
            -- secret string; comparing it directly raises a taint error.
            local ok, match = pcall(function() return left:GetText() == headerText end)
            if ok and match then
                return -- La línea ya existe; no tocar
            end
        end
    end
    tooltip:AddDoubleLine(headerText, defaultText)
end

function TT:INSPECT_READY(event, guid)
    if not SafeValueEquals(inspectGUID, guid) then return end
    
    local tooltip = _G.GameTooltip
    if tooltip:IsForbidden() then return end
    local unit = SafeGetTooltipUnit(tooltip)
    if not unit then return end
    
    local currentGUID = SafeUnitCall(UnitGUID, unit)
    if not SafeValueEquals(currentGUID, guid) then return end
    
    local isRaiderIOLoaded = C_AddOns.IsAddOnLoaded("RaiderIO")
    
    -- Update M+ Score with Role (Inspect Data Available)
    if self.db.scoreType == "M+" and not isRaiderIOLoaded then
        local score = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        if score and score.currentSeasonScore and score.currentSeasonScore > 0 then
            local roleIcon = ""
            
            -- [FIX] Usar nueva función robusta para detectar el rol de RIO
            local rioRole = self:GetRaiderIORole(unit)

            if rioRole then
                roleIcon = GetRoleIcon(rioRole)
            else
                local specID = SafeUnitCall(GetInspectSpecialization, unit)
                if specID and specID > 0 then
                    roleIcon = GetRoleIcon(GetSpecializationRoleByID(specID))
                end
            end
            if roleIcon ~= "" then roleIcon = " " .. roleIcon end
            
            local c = C_ChallengeMode.GetDungeonScoreRarityColor(score.currentSeasonScore) or {r=1,g=1,b=1}
            self:UpdateLine(tooltip, "Mythic+ Score:", string.format("|cff%02x%02x%02x%d|r%s", c.r*255, c.g*255, c.b*255, score.currentSeasonScore, roleIcon))
        end
    end

    -- 1. ITEM LEVEL
    local ilvl = SafeUnitCall(C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel, unit)
    local ilvlText = FormatItemLevel(ilvl)
    if ilvlText then
        self:SetCachedInspectInfo(guid, { ilvl = ilvl, ilvlText = ilvlText })
        self:UpdateLine(tooltip, "Item Level:", ilvlText)
    end

    -- PvP Rating Update
    if self.db.scoreType == "PVP" then
        local maxRating = 0
        if C_PvP then
            -- Arena 2v2, 3v3
            if C_PvP.GetInspectArenaData then
                for i = 1, 2 do -- 1=2v2, 2=3v3
                    local arenaData = C_PvP.GetInspectArenaData(i)
                    if arenaData and arenaData.rating and arenaData.rating > maxRating then maxRating = arenaData.rating end

                end
            end
            -- RBG
            if C_PvP.GetInspectRatedBattlegroundData then
                local rbgData = C_PvP.GetInspectRatedBattlegroundData()
                if rbgData and rbgData.rating and rbgData.rating > maxRating then maxRating = rbgData.rating end
            end
        end

        -- Solo Shuffle
        if C_PvP and C_PvP.GetInspectSoloShuffleData then
             local shuffle = C_PvP.GetInspectSoloShuffleData(unit)
             if shuffle and shuffle.rating and shuffle.rating > maxRating then maxRating = shuffle.rating end
        end
        
        local color = {r=0.5, g=0.5, b=0.5}
        if maxRating >= 2400 then color = {r=1, g=0.5, b=0} -- Elite
        elseif maxRating >= 2100 then color = {r=0.6, g=0.2, b=0.8} -- Duelist
        elseif maxRating >= 1800 then color = {r=0, g=0.44, b=0.87} -- Rival
        elseif maxRating >= 1600 then color = {r=0, g=0.8, b=0} -- Challenger
        elseif maxRating >= 1400 then color = {r=0.8, g=0.8, b=0} -- Combatant
        end
        
        self:UpdateLine(tooltip, "PvP Rating:", string.format("|cff%02x%02x%02x%d|r", color.r*255, color.g*255, color.b*255, maxRating))
    end

    -- 2. RAID PROGRESS
    if not isRaiderIOLoaded then
        SetAchievementComparisonUnit(unit)
        local fullProgressText = ""
        
        for _, raid in ipairs(RAIDS_TO_TRACK) do
            local txtNormal = self:CountBosses(unit, raid.NM, raid.maxBosses, "|cff1eff00") -- Verde
            local txtHeroic = self:CountBosses(unit, raid.HC, raid.maxBosses, "|cff0070dd") -- Azul
            local txtMythic = self:CountBosses(unit, raid.M,  raid.maxBosses, "|cffa335ee") -- Morado
            
            local summary = ""
            if string.find(txtMythic, "0/") == nil then
                 summary = txtMythic .. " M"
            elseif string.find(txtHeroic, "0/") == nil then
                 summary = txtHeroic .. " HC"
            elseif string.find(txtNormal, "0/") == nil then
                 summary = txtNormal .. " NM"
            else
                 summary = "|cff8080800/" .. raid.maxBosses .. "|r"
            end
            
            if fullProgressText ~= "" then fullProgressText = fullProgressText .. "  " end
            fullProgressText = fullProgressText .. "|cffffd100["..raid.name.."]|r " .. summary
        end
        
        ClearAchievementComparisonUnit()
        self:UpdateLine(tooltip, "Raid Progress:", fullProgressText)
    end

    -- tooltip:Show() -- [FIX] Removed to prevent conflicts
    self:StyleTooltip(tooltip)
    ClearInspectPlayer()
    inspectGUID = nil
end

function TT:CountBosses(unit, idTable, maxBosses, colorCode)
    local count = 0
    local isPlayer = SafeUnitPredicate(UnitIsUnit, unit, "player")
    for _, achievementID in ipairs(idTable) do
        if achievementID > 0 then
            local completed = false
            if isPlayer then
                _, _, _, completed = GetAchievementInfo(achievementID)
            else
                if GetAchievementComparisonInfo then
                    completed = GetAchievementComparisonInfo(achievementID)
                end
            end
            if completed then count = count + 1 end
        end
    end
    
    if count == 0 then
        return string.format("|cff808080%d/%d|r", count, maxBosses)
    else
        return string.format("%s%d/%d|r", colorCode, count, maxBosses)
    end
end

function TT:UpdateLine(tooltip, headerText, newText)
    for i = 2, tooltip:NumLines() do
        local left = _G[tooltip:GetName().."TextLeft"..i]
        if left then
            local ok, match = pcall(function() return left:GetText() == headerText end)
            if ok and match then
                local right = _G[tooltip:GetName().."TextRight"..i]
                if right then
                    local sameText = false
                    local okText = pcall(function()
                        sameText = right:GetText() == newText
                    end)
                    if okText and sameText then
                        return
                    end
                    right:SetText(newText)
                end
                return
            end
        end
    end
    tooltip:AddDoubleLine(headerText, newText)
end

-- ============================================================================
-- 2. TOOLTIP DE OBJETOS
-- ============================================================================

function TT:OnTooltipSetItem(tooltip)
    if not self.db.enable or not tooltip or tooltip:IsForbidden() then return end
    self:ResetIcon(tooltip)
    local _, link = tooltip:GetItem()
    if not link then return end
    
    
    local itemID, _, _, _, icon = C_Item.GetItemInfoInstant(link)
    local stackSize = C_Item.GetItemMaxStackSizeByID(link)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    
    tooltip:AddLine(" ") 
    tooltip:AddLine(COLOR_SECTION_HEADER .. "Item information|r")
    
    if stackSize and stackSize > 1 then
        tooltip:AddDoubleLine(COLOR_LABEL_TEXT.."Max stack size|r", COLOR_VALUE_TEXT..stackSize.."|r")
    end
    
    if classID then
        local className = C_Item.GetItemClassInfo(classID)
        local subClassName = C_Item.GetItemSubClassInfo(classID, subclassID)
        tooltip:AddDoubleLine(COLOR_LABEL_TEXT.."AH Category|r", COLOR_VALUE_TEXT..className.."|r")
        tooltip:AddDoubleLine(COLOR_LABEL_TEXT.."AH Subcategory|r", COLOR_VALUE_TEXT..subClassName.."|r")
    end
    
    tooltip:AddDoubleLine(COLOR_LABEL_TEXT.."Item ID|r", COLOR_VALUE_TEXT..(itemID or "?").."|r")
    if icon then self:AttachIcon(tooltip, icon) end

    local mouseFocus = GetSafeMouseFocus()
    if mouseFocus and not mouseFocus:IsForbidden() and mouseFocus.GetID and mouseFocus:GetParent() and mouseFocus:GetParent().GetID then
        local bagID = mouseFocus:GetParent():GetID()
        local slotID = mouseFocus:GetID()
        if bagID and type(bagID) == "number" and bagID >= 0 and bagID <= 5 then
             tooltip:AddLine(" ") 
             tooltip:AddLine(COLOR_SECTION_HEADER .. "Container information|r")
             tooltip:AddDoubleLine(COLOR_LABEL_TEXT.."Bag number|r", COLOR_VALUE_TEXT..bagID.."|r")
             tooltip:AddDoubleLine(COLOR_LABEL_TEXT.."Slot number|r", COLOR_VALUE_TEXT..slotID.."|r")
        end
    end

    self:StyleTooltip(tooltip)
    -- tooltip:Show() -- [FIX] Removed to prevent conflicts
end

-- ============================================================================
-- 3. TOOLTIP DE HABILIDADES
-- ============================================================================

function TT:OnTooltipSetSpell(tooltip)
    if not self.db.enable or not tooltip or tooltip:IsForbidden() then return end
    self:ResetIcon(tooltip)
    local name, spellID = tooltip:GetSpell()
    if not spellID then return end


    local icon = self:GetTooltipIconFallback(tooltip, spellID)
    
    tooltip:AddLine(" ") 
    tooltip:AddLine(COLOR_SECTION_HEADER .. "Spell information|r")
    tooltip:AddDoubleLine(COLOR_LABEL_TEXT.."Spell ID|r", COLOR_VALUE_TEXT..spellID.."|r")
    
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo and spellInfo.castTime then
        -- [FIX] Use pcall to avoid "secret number value" errors in secure paths (EncounterTimeline)
        local castTime = spellInfo.castTime
        local success, isInstant = pcall(function() return castTime == 0 end)
        if success then
            local castText = isInstant and "Instant" or (castTime/1000).." sec"
            tooltip:AddDoubleLine(COLOR_LABEL_TEXT.."Cast Time|r", COLOR_VALUE_TEXT..castText.."|r")
        end
    end

    if icon then self:AttachIcon(tooltip, icon) end

    self:StyleTooltip(tooltip)
    -- tooltip:Show() -- [FIX] Removed to prevent conflicts
end

