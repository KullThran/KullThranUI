local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local INS = KT:NewModule("InspectArmory", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

-- Route any font name/path through the locale-aware resolver so Latin-only
-- faces (Friz Quadrata, FRIZQT__, Avant Garde) can never paint tofu on
-- non-Latin languages; on Latin locales raw paths are kept raw.
local function SafeFont(nameOrPath, fallback)
    if KT and KT.ResolveFontForLocale then
        return KT:ResolveFontForLocale(nameOrPath, fallback or "Fonts\\FRIZQT__.TTF")
    end
    return (LSM and nameOrPath and LSM:Fetch("font", nameOrPath)) or fallback or "Fonts\\FRIZQT__.TTF"
end

-- Cache
local _G = _G
local pairs, select, tonumber, string, math = pairs, select, tonumber, string, math
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local C_Item = C_Item
local C_TooltipInfo = C_TooltipInfo
local C_PaperDollInfo = C_PaperDollInfo
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local C_Traits = C_Traits
local GetInspectSpecialization = GetInspectSpecialization
    or (C_SpecializationInfo and C_SpecializationInfo.GetInspectSpecialization)
local GetSpecializationInfoByID = GetSpecializationInfoByID
local GetInventoryItemQuality = GetInventoryItemQuality
local C_ClassTalents = C_ClassTalents
local C_AddOns = C_AddOns
local C_Timer = C_Timer
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local GetTime = GetTime
local GetCurrentRegion = GetCurrentRegion
local GetRealmName = GetRealmName
local issecretvalue = issecretvalue
local securecallfunction = securecallfunction
local MenuUtil = MenuUtil or _G.MenuUtil -- Asegurar MenuUtil

-- RUTA DE TEXTURAS
local TEXTURE_PATH = "Interface\\AddOns\\KullThranUI\\Modules\\Armory\\Armory Textures\\"
local ENCHANT_QUALITY_ICON_PATTERN = "(|A.-|a)"

-- Forever ("camelot") has its own inspect window: a Ranged slot after the
-- weapons, the Talents button in the header (where Retail has View in
-- Dressing Room) and no Raider.IO.
local IS_FOREVER = (KT.IsForever and KT:IsForever()) and true or false

-- Slots (RangedSlot only exists in Forever; missing buttons are skipped).
local SLOT_NAMES = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "ShirtSlot", "ChestSlot", "WaistSlot", "LegsSlot", "FeetSlot", "WristSlot",
    "HandsSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot", "BackSlot", "MainHandSlot", "SecondaryHandSlot",
    "RangedSlot", "TabardSlot"
}

-- Header row: the row of Blizzard's center button (View in Dressing Room in
-- Retail, Talents in Forever), TOP -39 on InspectPaperDollFrame in both.
local HEADER_ROW_Y = -39
local HEADER_ROW_HEIGHT = 22
local HEADER_ICON_SIZE = 22
local HEADER_GAP = 5
-- Blizzard's level line sits above that row (TOP -27).
local LEVEL_ROW_Y = -23

-- Class tokens whose ClassIcon_<Name> file is not just the capitalised token.
local CLASS_ICON_NAMES = { DEATHKNIGHT = "DeathKnight", DEMONHUNTER = "DemonHunter" }

-- Lista de Fondos
local BACKGROUND_LIST = {
    { key = "CLASS",    name = "Class (Default)", file = nil },
    { key = "SPACE",    name = "Space / Cosmos",    file = "Space.blp" },
    { key = "CASTLE",   name = "Castle (Alliance)",  file = "Castle.blp" },
    { key = "EMPIRE",   name = "Empire (Horde)",     file = "TheEmpire.blp" },
    { key = "KYRIAN",   name = "Bastion (Kyrian)",    file = "Cov_Kyrian.blp" },
    { key = "NECRO",    name = "Necrolords",         file = "Cov_Necrolords.blp" },
    { key = "NIGHTFAE", name = "Night Fae",  file = "Cov_NightFae.blp" },
    { key = "VENTHYR",  name = "Venthyr",             file = "Cov_Venthyr.blp" },
    { key = "DK",       name = "Death Knight",    file = "DEATHKNIGHT.blp" },
    { key = "HUNTER",   name = "Hunter",             file = "HUNTER.blp" },
    { key = "MAGE",     name = "Mage",                file = "MAGE.blp" },
    { key = "WARRIOR",  name = "Warrior",            file = "WARRIOR.blp" },
    { key = "ROGUE",    name = "Rogue",              file = "ROGUE.blp" },
    { key = "DRUID",    name = "Druid",              file = "DRUID.blp" },
    { key = "SHAMAN",   name = "Shaman",              file = "SHAMAN.blp" },
    { key = "PRIEST",   name = "Priest",           file = "PRIEST.blp" },
    { key = "WARLOCK",  name = "Warlock",               file = "WARLOCK.blp" },
    { key = "PALADIN",  name = "Paladin",             file = "PALADIN.blp" },
    { key = "MONK",     name = "Monk",               file = "MONK.blp" },
    { key = "DH",       name = "Demon Hunter",    file = "DEMONHUNTER.blp" },
    { key = "EVOKER",   name = "Evoker",            file = "Cov_Dragon.blp" },
}

local function SafeValueEquals(left, right)
    if left == nil or right == nil then return false end
    if issecretvalue and (issecretvalue(left) or issecretvalue(right)) then
        if not securecallfunction then return false end
        return securecallfunction(function(a, b)
            return a == b
        end, left, right)
    end
    return left == right
end

function INS:OnInitialize()
    self.db = KT.db.profile.inspectArmory or KT.db.profile.armory
    if self.db.modelZoom == nil then self.db.modelZoom = 0 end
end

function INS:OnEnable()
    if not self.db.enable then return end
    self:RegisterEvent("INSPECT_READY")
    if C_AddOns.IsAddOnLoaded("Blizzard_InspectUI") then
        self:HookInspectUI()
    else
        self:RegisterEvent("ADDON_LOADED")
    end
end

function INS:ADDON_LOADED(event, addonName)
    if addonName == "Blizzard_InspectUI" then
        self:HookInspectUI()
        self:UnregisterEvent("ADDON_LOADED")
    end
end

function INS:HookInspectUI()
    self:SecureHook("InspectPaperDollItemSlotButton_Update", "UpdateSlot")
    if not self.inspectUnitHooked and _G.InspectUnit then
        self:SecureHook("InspectUnit", "OnInspectUnit")
        self.inspectUnitHooked = true
    end

    -- Blizzard may update the PvP inspect pane while InspectFrame is
    -- being hidden or switched. During that brief window INSPECTED_UNIT is
    -- nil, but InspectPVPFrame_Update still calls UnitFactionGroup() with it.
    -- Keep Blizzard's updater intact and skip only that invalid transition.
    if not self.pvpUpdateFixHooked and _G.InspectPVPFrame_Update then
        local originalPVPUpdate = _G.InspectPVPFrame_Update
        _G.InspectPVPFrame_Update = function(...)
            local inspectedUnit = _G.INSPECTED_UNIT
            if type(inspectedUnit) ~= "string" or inspectedUnit == "" then
                return
            end
            return originalPVPUpdate(...)
        end
        self.pvpUpdateFixHooked = true
    end
    
    -- Blizzard Bug: InspectGuildFrame crashes if guild name is nil (lag/cross-realm)
    -- In Midnight 12.x, InspectGuildFrame_Update is a local upvalue; overriding _G won't reach it.
    -- Primary fix: replace the OnShow script to guard before the local upvalue is invoked.
    if not self.guildFixHooked and _G.InspectGuildFrame then
        local origGuildOnShow = _G.InspectGuildFrame:GetScript("OnShow")
        if origGuildOnShow then
            _G.InspectGuildFrame:SetScript("OnShow", function(self_, ...)
                local unit = _G.InspectFrame and _G.InspectFrame.unit
                if unit and not GetGuildInfo(unit) then return end
                return origGuildOnShow(self_, ...)
            end)
            self.guildFixHooked = true
        end
    end
    -- Fallback: override global for older versions or when GetScript is not available
    if not self.guildFixHooked and _G.InspectGuildFrame_Update then
        local origin = _G.InspectGuildFrame_Update
        _G.InspectGuildFrame_Update = function()
            if _G.InspectFrame and _G.InspectFrame.unit and not GetGuildInfo(_G.InspectFrame.unit) then
                return -- Skip update if no guild info to prevent crash
            end
            return origin()
        end
        self.guildFixHooked = true
    end

    if _G.InspectFrame then
        _G.InspectFrame:SetMovable(true)
        _G.InspectFrame:SetClampedToScreen(true)
        _G.InspectFrame:RegisterForDrag("LeftButton")
        _G.InspectFrame:HookScript("OnDragStart", function(self) self:StartMoving() end)
        _G.InspectFrame:HookScript("OnDragStop", function(self) 
            self:StopMovingOrSizing() 
            self:SetUserPlaced(true)
        end)
        
        _G.InspectFrame:EnableMouseWheel(true)
        _G.InspectFrame:HookScript("OnMouseWheel", function(self, delta)
            if IsControlKeyDown() then
                local newScale = (self:GetScale() or 1) + (delta * 0.05)
                if newScale < 0.6 then newScale = 0.6 end
                if newScale > 1.6 then newScale = 1.6 end
                self:SetScale(newScale)
                INS.db.scale = newScale
            end
        end)
        
        _G.InspectFrame:HookScript("OnShow", function(self)
            if _G.CharacterFrame and _G.CharacterFrame:IsShown() then
                _G.CharacterFrame:ClearAllPoints()
                _G.CharacterFrame:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 40, -40)
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", _G.CharacterFrame, "TOPRIGHT", 60, 0)
            end
            C_Timer.After(0.01, function()
                INS:SetupLayout()
                local unit = self.unit
                if unit and UnitExists(unit) then INS:QueueInspectRefresh(unit, UnitGUID(unit)) end
            end)
        end)

        -- HOOK PARA EL ZOOM (Cuerpo entero forzado)
        if _G.InspectModelFrame then
            hooksecurefunc(_G.InspectModelFrame, "SetUnit", function(self)
                C_Timer.After(0, function()
                    if self.SetCameraDistance then pcall(self.SetCameraDistance, self, 3.5) end
                    self:SetPosition(0, 0, 0)    
                    self:SetFacing(0)          
                end)
            end)
        end
    end
    
    if _G.InspectFrame and _G.InspectFrame:IsShown() then
        self:SetupLayout()
    end
end

-- ============================================================================
-- LAYOUT Y JERARQUÍA
-- ============================================================================

function INS:SetupLayout()
    if not _G.InspectFrame then return end
    if not _G.InspectPaperDollFrame then return end -- Asegurar que existe para el parent
    
    _G.InspectFrame:SetScale(self.db.scale or 1)
    -- Eliminado tamaño forzado para evitar descentrado en pestañas PvP/Guild

    -- Asegurar que el botón de cerrar esté por encima del modelo 3D
    local closeBtn = _G.InspectFrameCloseButton or _G.InspectFrame.CloseButton
    if closeBtn then
        closeBtn:SetFrameStrata("DIALOG")
        closeBtn:SetFrameLevel(1000)
    end

    -- MODELO 3D
    local model = _G.InspectModelFrame
    if model then
        -- Parent to PaperDollFrame so it hides on PvP/Guild tabs
        model:SetParent(_G.InspectPaperDollFrame)
        model:ClearAllPoints()
        model:SetPoint("TOPLEFT", _G.InspectFrame, "TOPLEFT", 20, -70)
        model:SetPoint("BOTTOMRIGHT", _G.InspectFrame, "BOTTOMRIGHT", -20, 25)
        model:SetFrameStrata("HIGH") 
        -- Usar ordenamiento dinámico para evitar que tape los slots
        model:Lower()
        model:Show()
        
        -- Habilitar rotación con ratón Y ZOOM con rueda
        model:EnableMouse(true)
        model:EnableMouseWheel(true) -- Importante para la rueda

        model:SetScript("OnMouseWheel", function(self, delta)
            if not self.GetCameraDistance or not self.SetCameraDistance then return end
            local current = self:GetCameraDistance()
            local step = 0.5
            
            if delta > 0 then -- Rueda arriba (Zoom In)
                if current > 0.5 then
                    pcall(self.SetCameraDistance, self, current - step)
                end
            else -- Rueda abajo (Zoom Out)
                if current < 15 then
                    pcall(self.SetCameraDistance, self, current + step)
                end
            end
        end)

        local lastClick = 0
        model:SetScript("OnMouseDown", function(self, button)
            -- Detección manual de Doble Clic
            local now = GetTime()
            if now - lastClick < 0.3 then
                if self.SetAnimation then self:SetAnimation(67) end -- 67 = Wave/Hello
            end
            lastClick = now

            if button == "LeftButton" then
                self.prevX = GetCursorPosition()
                self:SetScript("OnUpdate", function(self)
                    if IsMouseButtonDown("LeftButton") then
                        local x = GetCursorPosition()
                        local diff = (x - self.prevX) * 0.015
                        self:SetFacing(self:GetFacing() + diff)
                        self.prevX = x
                    else
                        self:SetScript("OnUpdate", nil)
                    end
                end)
            end
        end)
        model:SetScript("OnMouseUp", function(self)
            self:SetScript("OnUpdate", nil)
        end)

        if model.BackgroundTopLeft then model.BackgroundTopLeft:Hide() end
        if model.BackgroundTopRight then model.BackgroundTopRight:Hide() end
        if model.BackgroundBotLeft then model.BackgroundBotLeft:Hide() end
        if model.BackgroundBotRight then model.BackgroundBotRight:Hide() end
        if model.BackgroundOverlay then model.BackgroundOverlay:Hide() end
    end

    -- SLOTS
    if _G.InspectPaperDollFrame then 
        -- Ocultar texturas de fondo de Blizzard para que no tapen el modelo
        for i=1, _G.InspectPaperDollFrame:GetNumRegions() do
            local region = select(i, _G.InspectPaperDollFrame:GetRegions())
            if region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end
        
        _G.InspectPaperDollFrame:SetFrameStrata("HIGH")
        _G.InspectPaperDollFrame:Raise()
        -- Desactivar ratón en el marco contenedor para que los clics pasen al modelo 3D
        _G.InspectPaperDollFrame:EnableMouse(false)
    end

    for _, slotName in pairs(SLOT_NAMES) do
        local slot = _G["Inspect"..slotName]
        if slot then 
            slot:SetFrameStrata("HIGH")
            slot:Raise() -- Asegurar que esté visualmente encima del contenedor
        end
    end
    
    -- FONDO
    if model and not model.KT_BG then
        local bg = model:CreateTexture(nil, "ARTWORK")
        bg:SetDrawLayer("BACKGROUND", -8)
        bg:SetAllPoints(model)
        model.KT_BG = bg
    end
    
    -- Average item level: right end of the header row, "iLvl" before the
    -- number. Beside the trinkets it covered the upgrade and enchant texts
    -- that ArmoryProgressBridge draws next to the slots.
    if not _G.InspectFrame.KT_AvgIlvl then
        -- Parent to PaperDollFrame so it hides on PvP/Guild tabs
        local f = CreateFrame("Frame", nil, _G.InspectPaperDollFrame)
        f:SetSize(120, HEADER_ROW_HEIGHT)
        f:SetFrameStrata("HIGH")
        f:SetFrameLevel(100)

        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        f.text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
        f.text:SetJustifyH("RIGHT")

        f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.label:SetPoint("RIGHT", f.text, "LEFT", -4, 0)
        f.label:SetJustifyH("RIGHT")
        f.label:SetText(LText("iLvl"))

        _G.InspectFrame.KT_AvgIlvl = f
    end
    _G.InspectFrame.KT_AvgIlvl:ClearAllPoints()
    _G.InspectFrame.KT_AvgIlvl:SetPoint("TOPRIGHT", _G.InspectPaperDollFrame, "TOPRIGHT", -10, HEADER_ROW_Y)

    -- Class icon (square, in the style's slot frame like the Armory header)
    -- and spec icon (round), on the left of the header row.
    if not _G.InspectFrame.KT_ClassIcon then
        local f = CreateFrame("Frame", nil, _G.InspectPaperDollFrame)
        f:SetSize(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
        f:SetFrameStrata("HIGH")
        f:SetFrameLevel(105)
        f.Icon = f:CreateTexture(nil, "ARTWORK")
        f.Icon:SetPoint("CENTER")
        f.Icon:SetSize(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
        f:SetScript("OnEnter", function(self)
            if self.className then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.className, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f:Hide()
        _G.InspectFrame.KT_ClassIcon = f
    end

    if not _G.InspectFrame.KT_SpecIcon then
        local f = CreateFrame("Frame", nil, _G.InspectPaperDollFrame)
        f:SetSize(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
        f:SetFrameStrata("HIGH")
        f:SetFrameLevel(105)

        f.Icon = f:CreateTexture(nil, "ARTWORK")
        f.Icon:SetAllPoints()
        f.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        f.Mask = f:CreateMaskTexture()
        f.Mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        f.Mask:SetAllPoints(f.Icon)
        f.Icon:AddMaskTexture(f.Mask)

        f:SetScript("OnEnter", function(self)
            if self.specName then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.specName, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f:Hide()

        _G.InspectFrame.KT_SpecIcon = f
    end

    self:UpdateBackground()
    self:CreateBackgroundSelector() -- Botón de Mapa (Estilo Armory)
    self:CreateRaiderIOButton()
    self:LayoutHeader()
    self:PlaceTalentsButton()
end

-- ============================================================================
-- VISUAL STYLE: the Armory's slot frames and glyphs (KullThranUI_Armory)
-- ============================================================================

-- The Armory module carries the per-style tokens (AR.Styles) and drawing
-- helpers (AR.StatStyle). Without it the slots keep flat quality edges.
local function GetArmoryStyles()
    local armory = KT.GetModule and KT:GetModule("Armory", true)
    if not armory then return nil, nil end
    return armory.Styles, armory.StatStyle
end

-- Inspect style for the current Visual Style (its own choice, as the Armory,
-- Bags and Chat have theirs; without one, the Visual Style's own look).
function INS:GetStyleKey()
    local vt = KT.VisualThemes
    return (vt and vt.ResolveModuleStyle and vt:ResolveModuleStyle(self.db)) or "kui"
end

-- Slot border settings, each kept per style:
--   slotBorder.enabled[style]  false hides the KUI slot borders
--   slotBorder.tint[style]     false keeps them uncoloured by item quality
--   slotBorder.strength[style] tint strength (0-1; style default when nil)
function INS:GetSlotBorderSettings()
    local db = self.db
    if type(db.slotBorder) ~= "table" then db.slotBorder = {} end
    local sb = db.slotBorder
    if type(sb.enabled) ~= "table" then sb.enabled = {} end
    if type(sb.tint) ~= "table" then sb.tint = {} end
    if type(sb.strength) ~= "table" then sb.strength = {} end
    return sb
end

function INS:GetSlotFrameStyle(key)
    key = key or self:GetStyleKey()
    local styles = GetArmoryStyles()
    local style = styles and styles.Get and styles:Get(key)
    return style and style.slotFrame or nil, key
end

function INS:IsSlotBorderEnabled(key)
    return self:GetSlotBorderSettings().enabled[key or self:GetStyleKey()] ~= false
end

function INS:IsSlotBorderTinted(key)
    return self:GetSlotBorderSettings().tint[key or self:GetStyleKey()] ~= false
end

function INS:GetSlotBorderStrength(key)
    local slotFrame
    slotFrame, key = self:GetSlotFrameStyle(key)
    local value = self:GetSlotBorderSettings().strength[key]
    return value or (slotFrame and slotFrame.tintStrength) or 1
end

local function EnsureSlotBorder(slot)
    local border = slot.ktInspectBorder
    if border then return border end

    border = CreateFrame("Frame", nil, slot)
    border:SetFrameLevel(slot:GetFrameLevel() + 8)
    border:EnableMouse(false)

    -- Flat quality edges (no styled frame for the style).
    border.edges = {}
    for index = 1, 4 do
        border.edges[index] = border:CreateTexture(nil, "OVERLAY", nil, 7)
    end
    border.edges[1]:SetPoint("TOPLEFT"); border.edges[1]:SetPoint("TOPRIGHT"); border.edges[1]:SetHeight(2)
    border.edges[2]:SetPoint("BOTTOMLEFT"); border.edges[2]:SetPoint("BOTTOMRIGHT"); border.edges[2]:SetHeight(2)
    border.edges[3]:SetPoint("TOPLEFT"); border.edges[3]:SetPoint("BOTTOMLEFT"); border.edges[3]:SetWidth(2)
    border.edges[4]:SetPoint("TOPRIGHT"); border.edges[4]:SetPoint("BOTTOMRIGHT"); border.edges[4]:SetWidth(2)

    -- Styled frame: the style's metal plus a white layer tinted with the
    -- item quality.
    border.frame = border:CreateTexture(nil, "OVERLAY", nil, 6)
    border.tint = border:CreateTexture(nil, "OVERLAY", nil, 7)
    border.tint:SetBlendMode("BLEND")

    slot.ktInspectBorder = border
    return border
end

-- Slot texts (item level, enchant) go on a layer above the border, so the
-- frame art never covers the number in the corner.
function INS:GetSlotTextLayer(slot)
    local layer = slot.ktTextLayer
    if not layer then
        layer = CreateFrame("Frame", nil, slot)
        layer:SetAllPoints(slot)
        layer:EnableMouse(false)
        slot.ktTextLayer = layer
    end
    layer:SetFrameLevel(slot:GetFrameLevel() + 10)
    return layer
end

-- Draws the Inspect style's slot border on a slot-sized frame (the real
-- slots and the options preview). Returns "styled" (the style's frame),
-- "flat" (quality edges) or "none" (nothing drawn).
function INS:DrawSlotBorder(slot, quality, hasItem)
    local key = self:GetStyleKey()
    local border = slot.ktInspectBorder
    if not self:IsSlotBorderEnabled(key) then
        if border then border:Hide() end
        return "none"
    end

    border = EnsureSlotBorder(slot)
    local target = slot.backdrop or slot
    border:ClearAllPoints()
    border:SetAllPoints(target)
    local tinted = quality ~= nil and self:IsSlotBorderTinted(key)
    local slotFrame = self:GetSlotFrameStyle(key)

    if slotFrame then
        -- Sized from the slot itself: a skin backdrop can report 0x0 before
        -- its anchors resolve.
        local width, height = slot:GetSize()
        for index = 1, 4 do border.edges[index]:Hide() end
        for _, layer in ipairs({ border.frame, border.tint }) do
            layer:ClearAllPoints()
            layer:SetPoint("CENTER", target, "CENTER")
            layer:SetSize(width * slotFrame.scale, height * slotFrame.scale)
        end
        border.frame:SetTexture(slotFrame.frame)
        border.frame:Show()
        if tinted and quality >= (slotFrame.minTintQuality or 0) then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            border.tint:SetTexture(slotFrame.tint)
            border.tint:SetVertexColor(r, g, b)
            border.tint:SetAlpha(self:GetSlotBorderStrength(key))
            border.tint:Show()
        else
            border.tint:Hide()
        end
        border:Show()
        return "styled"
    end

    border.frame:Hide()
    border.tint:Hide()
    if not (hasItem and tinted) then
        border:Hide()
        return "none"
    end
    local r, g, b = C_Item.GetItemQualityColor(quality)
    for index = 1, 4 do
        border.edges[index]:SetColorTexture(r, g, b, 1)
        border.edges[index]:Show()
    end
    border:Show()
    return "flat"
end

local function GetSlotQuality(unit, slotID, link)
    if not link then return nil end
    local quality = GetInventoryItemQuality and GetInventoryItemQuality(unit, slotID)
    if quality == nil and C_Item and C_Item.GetItemQualityByID then
        quality = C_Item.GetItemQualityByID(link)
    end
    if quality == nil then
        local _, _, cached = GetItemInfo(link)
        quality = cached
    end
    return quality
end

-- Real inspect slot: border, then the skin edge and Blizzard's quality
-- border get out of its way (and come back when the border is off).
function INS:UpdateSlotBorder(button, unit, slotID, link)
    local quality = GetSlotQuality(unit, slotID, link)
    local mode = self:DrawSlotBorder(button, quality, link ~= nil)
    if button.backdrop and button.backdrop.SetBackdropBorderColor then
        button.backdrop:SetBackdropBorderColor(0, 0, 0, mode == "styled" and 0 or 1)
    end
    if button.IconBorder then
        if mode ~= "none" then
            button.IconBorder:SetAlpha(0)
            button._ktIconBorderHidden = true
        elseif button._ktIconBorderHidden then
            button.IconBorder:SetAlpha(1)
            button._ktIconBorderHidden = nil
        end
    end
    return quality
end

-- ============================================================================
-- SELECTOR DE FONDO
-- ============================================================================

function INS:CreateBackgroundSelector()
    local model = _G.InspectModelFrame
    if not (model and _G.InspectPaperDollFrame) then return end

    local btn = model.KT_BGSelector
    if not btn then
        -- In the header row (LayoutHeader), parented to the paper doll so it
        -- hides with the PvP and Guild tabs.
        btn = CreateFrame("Button", "KT_InspectBGSelector", _G.InspectPaperDollFrame)
        btn:SetSize(20, 20)
        btn:SetFrameStrata("HIGH")
        btn:SetFrameLevel(105)
        btn:SetNormalTexture("Interface\\Icons\\INV_Misc_Map02")
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

        btn:SetScript("OnClick", function(self)
            if not MenuUtil then return end
            MenuUtil.CreateContextMenu(self, function(owner, root)
                root:CreateTitle(LText("Select Background"))
                for _, data in ipairs(BACKGROUND_LIST) do
                    root:CreateCheckbox(LText(data.name),
                        function() return INS.db.backgroundType == data.key end,
                        function() INS.db.backgroundType = data.key; INS:UpdateBackground() end
                    )
                end
            end)
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(LText("Select Background"))
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        model.KT_BGSelector = btn
    end

    -- The style's own background glyph, as on the Armory; the map icon
    -- without the Armory.
    local normal = btn:GetNormalTexture()
    if normal then
        local styles, statStyle = GetArmoryStyles()
        local style = styles and styles.Get and styles:Get(self:GetStyleKey())
        local drawn = style and statStyle and statStyle.SetGlyph and statStyle:SetGlyph(normal, style.stats, "background")
        if not drawn then
            normal:SetTexture("Interface\\Icons\\INV_Misc_Map02")
            normal:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            normal:SetVertexColor(1, 1, 1, 1)
        end
    end
end

-- ============================================================================
-- HEADER ROW
-- ============================================================================

-- Blizzard's button in the header row: View in Dressing Room (Retail) or,
-- where that one stays hidden, Talents (Forever).
function INS:GetHeaderCenterButton()
    local pd = _G.InspectPaperDollFrame
    if not pd then return nil end
    local view, talents = pd.ViewButton, pd.InspectTalents
    if view and view:IsShown() then return view end
    if talents and talents:IsShown() then return talents end
    return nil
end

-- Right to left from the center button: background selector, spec, class.
-- Without that button the row starts at the frame's left edge instead.
function INS:LayoutHeader()
    local frame, pd = _G.InspectFrame, _G.InspectPaperDollFrame
    if not (frame and pd) then return end
    local selector = _G.InspectModelFrame and _G.InspectModelFrame.KT_BGSelector

    local chain = {}
    local function add(item)
        if item and item:IsShown() then chain[#chain + 1] = item end
    end
    add(selector)
    add(frame.KT_SpecIcon)
    add(frame.KT_ClassIcon)

    local center = self:GetHeaderCenterButton()
    if center then
        local previous = center
        for _, item in ipairs(chain) do
            item:ClearAllPoints()
            item:SetPoint("RIGHT", previous, "LEFT", -HEADER_GAP, 0)
            previous = item
        end
    else
        local previous
        for index = #chain, 1, -1 do
            local item = chain[index]
            item:ClearAllPoints()
            if previous then
                item:SetPoint("LEFT", previous, "RIGHT", HEADER_GAP, 0)
            else
                item:SetPoint("LEFT", pd, "TOPLEFT", 12, HEADER_ROW_Y - HEADER_ROW_HEIGHT / 2)
            end
            previous = item
        end
    end
end

-- Retail keeps Talents in the bottom-right corner, right where the off-hand
-- upgrade and enchant texts go: it moves under the frame, after the tabs.
-- Forever has it in the header row, where it stays.
function INS:PlaceTalentsButton()
    if IS_FOREVER then return end
    local frame = _G.InspectFrame
    local items = _G.InspectPaperDollItemsFrame
    local talents = (items and items.InspectTalents)
        or (_G.InspectPaperDollFrame and _G.InspectPaperDollFrame.InspectTalents)
    if not (frame and talents) or talents == self:GetHeaderCenterButton() then return end

    talents:ClearAllPoints()
    talents:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -6, -4)

    -- Long tab names: keep the button clear of the last tab.
    local lastTab
    for index = 1, 6 do
        local tab = _G["InspectFrameTab" .. index]
        if tab and tab:IsShown() then lastTab = tab end
    end
    local tabRight = lastTab and lastTab:GetRight()
    local frameRight = frame:GetRight()
    if tabRight and frameRight and tabRight + 4 > frameRight - 6 - (talents:GetWidth() or 0) then
        talents:ClearAllPoints()
        talents:SetPoint("LEFT", lastTab, "RIGHT", 4, 0)
    end
end

-- ============================================================================
-- RAIDER.IO (Retail only)
-- ============================================================================

function INS:ShowRaiderIOURL()
    local unit = _G.InspectFrame and _G.InspectFrame.unit
    if not unit then return end

    local name, realm = UnitName(unit)
    if not name then return end
    if not realm or realm == "" then realm = GetRealmName() end

    local region = "us"
    local regionID = GetCurrentRegion()
    if regionID == 3 then region = "eu"
    elseif regionID == 4 then region = "tw"
    elseif regionID == 5 then region = "cn"
    elseif regionID == 2 then region = "kr" end

    -- Realm slug: spaces to dashes, no apostrophes, lower case.
    realm = realm:gsub(" ", "-")
    realm = realm:gsub("'", "")
    realm = string.lower(realm)

    -- Encode Name (Special Chars like è -> %C3%A8)
    name = name:gsub("([^%w])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)

    local url = string.format("https://raider.io/characters/%s/%s/%s", region, realm, name)

    StaticPopupDialogs["KT_COPY_RAIDERIO"] = {
        text = LText("Copy Raider.IO URL (Ctrl+C):"),
        button1 = _G.CLOSE or "Close",
        hasEditBox = true,
        editBoxWidth = 350,
        OnShow = function(self)
            self.EditBox:SetText(url)
            self.EditBox:HighlightText()
            self.EditBox:SetFocus()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("KT_COPY_RAIDERIO")
end

-- Compact button at the right end of the level line, so the header row keeps
-- room for the average item level. Forever has no Raider.IO: no button.
function INS:CreateRaiderIOButton()
    local frame, pd = _G.InspectFrame, _G.InspectPaperDollFrame
    if not (frame and pd) then return end
    if frame.KT_TalentOverlay then frame.KT_TalentOverlay:Hide() end

    if IS_FOREVER then
        if frame.KT_RaiderIOBtn then frame.KT_RaiderIOBtn:Hide() end
        return
    end

    local btn = frame.KT_RaiderIOBtn
    if not btn then
        btn = CreateFrame("Button", nil, pd, "UIPanelButtonTemplate")
        btn:SetSize(64, 16)
        btn:SetText(LText("Raider.IO"))
        if btn.SetNormalFontObject then
            btn:SetNormalFontObject("GameFontNormalSmall")
            btn:SetHighlightFontObject("GameFontHighlightSmall")
        end
        btn:SetScript("OnClick", function() INS:ShowRaiderIOURL() end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(LText("Copy Raider.IO URL"))
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.KT_RaiderIOBtn = btn
    end
    btn:ClearAllPoints()
    btn:SetPoint("TOPRIGHT", pd, "TOPRIGHT", -10, LEVEL_ROW_Y)
    btn:Show()
end
-- Background Type choices (key -> label) for the options page dropdown.
function INS:GetBackgroundValues()
    local values = {}
    for _, d in ipairs(BACKGROUND_LIST) do
        values[d.key] = d.name
    end
    return values
end

-- Background art for the chosen Background Type and a class file; nil means no
-- art (Blizzard's own backdrop). Shared with the options page preview.
function INS:GetBackgroundFile(classFilename)
    local type = self.db and self.db.backgroundType or "CLASS"
    local filename
    if type == "CLASS" then
        if classFilename then
            if classFilename == "EVOKER" then
                filename = "Cov_Dragon.blp"
            else
                filename = classFilename .. ".blp"
            end
        end
    else
        for _, d in ipairs(BACKGROUND_LIST) do
            if d.key == type then filename = d.file break end
        end
    end
    return filename and (TEXTURE_PATH .. filename) or nil
end

-- Average item level as shown on the frame, honouring Avg iLvl Decimals.
function INS:FormatAverageIlvl(avg)
    avg = tonumber(avg) or 0
    if self.db and self.db.avgIlvlDecimals then
        return string.format("%.1f", math.floor(avg * 10) / 10)
    end
    return tostring(math.floor(avg))
end

function INS:UpdateBackground()
    if not _G.InspectFrame then return end

    local model = _G.InspectModelFrame
    local bg = model and model.KT_BG

    if bg then
        local unit = _G.InspectFrame.unit or "target"
        if not UnitExists(unit) then unit = "player" end

        local _, classFilename = UnitClass(unit)
        local file = self:GetBackgroundFile(classFilename)

        if file then
            bg:SetTexture(file)
            bg:SetTexCoord(0, 1, 0, 1)
            bg:Show()
            if model.BackgroundOverlay then model.BackgroundOverlay:Hide() end
        else
            bg:Hide()
            if model.BackgroundOverlay then model.BackgroundOverlay:Show() end
        end
    end
    
    local f = _G.InspectFrame.KT_AvgIlvl
    if f and f.text then
        local fontName = self.db.avgIlvlFont or "Friz Quadrata TT"
        local fontPath = SafeFont(fontName)
        local size = self.db.avgIlvlSize or 20
        local outline = self.db.avgIlvlOutline or "OUTLINE"
        local c = self.db.avgIlvlColor or {r=1, g=0.82, b=0}
        
        f.text:SetFont(fontPath, size, outline)
        f.text:SetTextColor(c.r, c.g, c.b)
        
        if f.label then
            local lFontName = self.db.avgIlvlLabelFont or "Friz Quadrata TT"
            local lFontPath = SafeFont(lFontName)
            local lSize = self.db.avgIlvlLabelSize or 10
            local lOutline = self.db.avgIlvlLabelOutline or "OUTLINE"
            local lColor = self.db.avgIlvlLabelColor or {r=1, g=1, b=1}
            
            f.label:SetFont(lFontPath, lSize, lOutline)
            f.label:SetTextColor(lColor.r, lColor.g, lColor.b)
        end
        
        f:SetShown(self.db.showAvgIlvl ~= false)
    end
end

-- Class icon (style frame when the slot borders are on) and spec icon of
-- the inspected unit; the spec icon hides where the unit has no spec data.
-- Forever has one specialization per class, with the class's own name and
-- icon: there the spec icon would repeat the class icon next to it.
function INS:UpdateHeaderIcons(unit)
    local frame = _G.InspectFrame
    if not frame then return end
    local hasUnit = unit and UnitExists(unit)

    local classIcon = frame.KT_ClassIcon
    if classIcon then
        local className, classFile
        if hasUnit then className, classFile = UnitClass(unit) end
        local drawn = false
        if type(classFile) == "string" and classFile ~= "" then
            local _, statStyle = GetArmoryStyles()
            local slotFrame = self:IsSlotBorderEnabled() and self:GetSlotFrameStyle() or nil
            if statStyle and statStyle.ClassIcon then
                drawn = statStyle:ClassIcon(classIcon, classIcon.Icon, classFile, slotFrame)
            else
                local name = CLASS_ICON_NAMES[classFile] or (classFile:sub(1, 1) .. classFile:sub(2):lower())
                classIcon.Icon:SetTexture("Interface\\Icons\\ClassIcon_" .. name)
                classIcon.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                drawn = true
            end
        end
        classIcon.className = className
        classIcon:SetShown(drawn and true or false)
    end

    local specIcon = frame.KT_SpecIcon
    if specIcon then
        local specID = not IS_FOREVER and hasUnit and GetInspectSpecialization and GetInspectSpecialization(unit) or nil
        local name, icon
        if specID and specID > 0 and GetSpecializationInfoByID then
            _, name, _, icon = GetSpecializationInfoByID(specID)
        end
        if icon then
            specIcon.Icon:SetTexture(icon)
            specIcon.specName = name
            specIcon:Show()
        else
            specIcon.specName = nil
            specIcon:Hide()
        end
    end

    self:LayoutHeader()
end

function INS:UpdateSpecIcon(unit)
    self:UpdateHeaderIcons(unit)
end

function INS:FixModelCamera(unit)
    if not _G.InspectFrame then return end
    local model = _G.InspectModelFrame
    if not model then return end

    if unit and UnitExists(unit) then model:SetUnit(unit) end
    
    C_Timer.After(0.01, function()
        if not model:IsVisible() then return end
        if model.SetCameraDistance then pcall(model.SetCameraDistance, model, 3.5) end
        model:SetPosition(0, 0, 0)
        model:SetFacing(0)
    end)
end

function INS:IsCurrentInspectUnit(unit, expectedGUID)
    if not unit or not UnitExists(unit) or not _G.InspectFrame or not _G.InspectFrame:IsShown() then
        return false
    end
    if _G.InspectFrame.unit and not UnitIsUnit(unit, _G.InspectFrame.unit) then
        return false
    end
    return not expectedGUID or SafeValueEquals(UnitGUID(unit), expectedGUID)
end

function INS:RefreshInspectUnit(unit, expectedGUID)
    if not self:IsCurrentInspectUnit(unit, expectedGUID) then return false end
    self:SetupLayout()
    self:UpdateBackground()
    self:UpdateSpecIcon(unit)
    local links = 0
    for _, slotName in pairs(SLOT_NAMES) do
        local button = _G["Inspect" .. slotName]
        if button then self:UpdateSlot(button) end
        local link = button and GetInventoryItemLink(unit, button:GetID())
        if link then
            links = links + 1
            local itemID = _G.GetItemInfoInstant and _G.GetItemInfoInstant(link)
            if itemID and C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(itemID)
            end
        end
    end
    if links == 0 then return false end
    -- Without a spec API (or spec data) the item links are all there is.
    return not GetInspectSpecialization or (GetInspectSpecialization(unit) or 0) > 0
end

function INS:QueueInspectRefresh(unit, expectedGUID)
    if not unit or not UnitExists(unit) then return end
    expectedGUID = expectedGUID or UnitGUID(unit)
    self.inspectRefreshToken = (self.inspectRefreshToken or 0) + 1
    local token = self.inspectRefreshToken
    local delays = { 0, 0.12, 0.35, 0.8, 1.5, 2.5 }
    for pass, delay in ipairs(delays) do
        local refreshPass = pass
        C_Timer.After(delay, function()
            if token ~= INS.inspectRefreshToken or not INS:IsCurrentInspectUnit(unit, expectedGUID) then return end
            local complete = INS:RefreshInspectUnit(unit, expectedGUID)
            if complete then return end
            if refreshPass == 4 and _G.CanInspect and _G.NotifyInspect and not UnitIsUnit(unit, "player") then
                local now = GetTime()
                if (not INS.lastInspectRequestAt or now - INS.lastInspectRequestAt >= 2)
                    and _G.CanInspect(unit, false) then
                    INS.lastInspectRequestAt = now
                    _G.NotifyInspect(unit)
                end
            end
        end)
    end
end

function INS:OnInspectUnit(unit)
    C_Timer.After(0.05, function()
        local currentUnit = (_G.InspectFrame and _G.InspectFrame.unit) or unit
        if currentUnit and UnitExists(currentUnit) then
            INS:QueueInspectRefresh(currentUnit, UnitGUID(currentUnit))
        end
    end)
end


function INS:CalculateAverageIlvl(unit)
    if not unit or not UnitExists(unit) then return 0 end
    return C_PaperDollInfo.GetInspectItemLevel(unit) or 0
end

function INS:INSPECT_READY(event, unitGUID)
    if not _G.InspectFrame then return end
    local unit = _G.InspectFrame.unit
    if not unit then return end
    
    if SafeValueEquals(UnitGUID(unit), unitGUID) then
        self:SetupLayout()
        self:FixModelCamera(unit)
        self:UpdateBackground()
        self:UpdateSpecIcon(unit)
        for _, slotName in pairs(SLOT_NAMES) do
            local btn = _G["Inspect"..slotName]
            if btn then self:UpdateSlot(btn) end
        end
        self:QueueInspectRefresh(unit, unitGUID)
    end
end

function INS:UpdateSlot(button)
    if not _G.InspectFrame then return end
    local unit = _G.InspectFrame.unit
    if not unit then return end 

    -- Texts on a layer above the slot border (see GetSlotTextLayer).
    local textLayer = self:GetSlotTextLayer(button)
    if not button.ktIlvl then
        button.ktIlvl = textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.ktIlvl:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.ktIlvl:SetDrawLayer("OVERLAY", 7)
    elseif button.ktIlvl:GetParent() ~= textLayer then
        button.ktIlvl:SetParent(textLayer)
    end
    if not button.ktEnchant then
        button.ktEnchant = textLayer:CreateFontString(nil, "OVERLAY", "SystemFont_Tiny")
        button.ktEnchant:SetDrawLayer("OVERLAY", 7)
    elseif button.ktEnchant:GetParent() ~= textLayer then
        button.ktEnchant:SetParent(textLayer)
    end

    button.ktEnchant:ClearAllPoints()
    local slotID = button:GetID()
    local isRight = (slotID == 6 or slotID == 7 or slotID == 8 or slotID == 10 or slotID == 11 or slotID == 12 or slotID == 13 or slotID == 14 or slotID == 16)
    
    if isRight then
        button.ktEnchant:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", (self.db.enchantX or 0), (self.db.enchantY or 2))
        button.ktEnchant:SetJustifyH("RIGHT")
    else
        button.ktEnchant:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", (self.db.enchantX or 0), (self.db.enchantY or 2))
        button.ktEnchant:SetJustifyH("LEFT")
    end
    
    local link = GetInventoryItemLink(unit, slotID)
    local quality = self:UpdateSlotBorder(button, unit, slotID, link)

    if _G.InspectFrame.KT_AvgIlvl then
        local avg = self:CalculateAverageIlvl(unit)
        if avg > 0 then _G.InspectFrame.KT_AvgIlvl.text:SetText(self:FormatAverageIlvl(avg))
        else _G.InspectFrame.KT_AvgIlvl.text:SetText(LText("...")) end
        _G.InspectFrame.KT_AvgIlvl:SetShown(self.db.showAvgIlvl ~= false)
    end

    if not link then
        button.ktIlvl:SetText("")
        button.ktEnchant:SetText("")
        return
    end

    if self.db.showIlvl then
        local effectiveILvl = C_Item.GetDetailedItemLevelInfo(link) or ""
        
        local fontName = self.db.ilvlFont or "Friz Quadrata TT"
        local fontFile = SafeFont(fontName)
        local fontSize = self.db.ilvlSize or 12
        local fontOutline = self.db.ilvlOutline or "OUTLINE"

        button.ktIlvl:SetFont(fontFile, fontSize, fontOutline)
        button.ktIlvl:SetText(effectiveILvl)
        button.ktIlvl:Show()
        
        if self.db.ilvlColorByRarity and quality then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            button.ktIlvl:SetTextColor(r, g, b)
        else
            local c = self.db.ilvlColor or {r=1,g=1,b=1}
            button.ktIlvl:SetTextColor(c.r, c.g, c.b)
        end
    else
        button.ktIlvl:Hide()
    end

    if self.db.showEnchant then
        local enchantText, enchantIcon = self:GetEnchantText(link)
        local fontName = self.db.enchantFont or "Friz Quadrata TT"
        local fontPath = SafeFont(fontName)
        
        button.ktEnchant:SetFont(fontPath, self.db.enchantSize or 10, "OUTLINE")
        
        if enchantText then
            if string.len(enchantText) > 18 then enchantText = string.sub(enchantText, 1, 15).."..." end
            if enchantIcon then
                enchantText = enchantText.." "..enchantIcon
            end
            button.ktEnchant:SetText(enchantText)
            local c = self.db.enchantColor or {r=0,g=1,b=0}
            button.ktEnchant:SetTextColor(c.r, c.g, c.b)
            -- ArmoryProgressBridge draws the enchant beside the slot (ktEnchantDetail) and hides
            -- this one; a later refresh here must not show it again on top.
            button.ktEnchant:SetShown(not button.ktEnchantDetail)
        else
            button.ktEnchant:Hide()
        end
    else
        button.ktEnchant:Hide()
    end
end

function INS:GetEnchantText(itemLink)
    if not itemLink then return nil end
    local enchantID = tonumber(string.match(itemLink, "item:%d+:(%d+):"))
    if not enchantID or enchantID == 0 then return nil end

    local data = C_TooltipInfo.GetHyperlink(itemLink)
    if (issecretvalue and issecretvalue(data))
        or (canaccessvalue and not canaccessvalue(data))
        or type(data) ~= "table" then return nil end
    local lines = data.lines
    if (issecretvalue and issecretvalue(lines))
        or (canaccessvalue and not canaccessvalue(lines))
        or type(lines) ~= "table" then return nil end
    
    local pattern = _G.ENCHANTED_TOOLTIP_LINE:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    pattern = pattern:gsub("%%%%s", "(.+)")

    for _, line in ipairs(lines) do
        local lineAccessible = not (issecretvalue and issecretvalue(line))
            and (not canaccessvalue or canaccessvalue(line))
        local text = lineAccessible and type(line) == "table" and line.leftText or nil
        if text and not (issecretvalue and issecretvalue(text))
            and (not canaccessvalue or canaccessvalue(text)) then
            -- Limpiar códigos de color para asegurar que el patrón coincida
            local icon = text:match(ENCHANT_QUALITY_ICON_PATTERN)
            local cleanText = text
                :gsub("|c%x%x%x%x%x%x%x%x", "")
                :gsub("|r", "")
                :gsub("|T.-|t", "")
                :gsub(ENCHANT_QUALITY_ICON_PATTERN, "")
            local enchant = cleanText:match(pattern)
            if enchant then
                enchant = enchant:gsub("^%s+", ""):gsub("%s+$", "")
                local prefix, effect = enchant:match("^([^:%-]+)%s*[:%-]%s*(.+)$")
                if prefix and effect and prefix:lower():find("enchant", 1, true) then
                    enchant = effect
                end
                enchant = enchant:gsub("^[Ee]nchant%s+[Ss]houlders?%s*[:%-]?%s*", "")
                enchant = enchant:gsub("^%s+", ""):gsub("%s+$", "")
                if enchant ~= "" then return enchant, icon end
            end
        end
    end
    return nil
end

function INS:GetOptions()
    local function GetOpt(info) return self.db[info[#info]] end
    local function SetOpt(info, value) self.db[info[#info]] = value; self:Refresh() end
    
    local bgValues = {}
    for _, v in ipairs(BACKGROUND_LIST) do
        bgValues[v.key] = LText(v.name)
    end

    local options = {
        name = LText("Inspect"),
        type = "group",
        order = 20,
        args = {
            header = { order = 0, type = "header", name = LText("Inspect Armory") },
            enable = {
                order = 1, type = "toggle", name = LText("Enable"),
                get = GetOpt,
                set = function(info, value) self.db.enable = value; if value then self:OnEnable() else self:OnDisable() end end,
            },
            scale = {
                order = 2, type = "range", name = LText("Scale"), min = 0.6, max = 1.6, step = 0.05,
                get = GetOpt, set = function(info, value) self.db.scale = value; if _G.InspectFrame then _G.InspectFrame:SetScale(value) end end,
            },
            backgroundType = {
                order = 3, type = "select", name = LText("Background"), values = bgValues,
                get = GetOpt, set = SetOpt,
            },
            generalGroup = {
                order = 10, type = "group", name = LText("General Settings"), inline = true,
                args = {
                    showIlvl = { order = 1, type = "toggle", name = LText("Show Item Level"), get = GetOpt, set = SetOpt },
                    showEnchant = { order = 2, type = "toggle", name = LText("Show Enchants"), get = GetOpt, set = SetOpt },
                },
            },
            avgIlvlGroup = {
                order = 20, type = "group", name = LText("Average iLvl (Big Number)"), inline = true,
                args = {
                    avgIlvlFont = {
                        type = "select", dialogControl = "LSM30_Font", order = 1, name = LText("Font"),
                        values = LSM:HashTable("font"), get = GetOpt, set = SetOpt,
                    },
                    avgIlvlSize = { order = 2, type = "range", name = LText("Size"), min = 10, max = 60, step = 1, get = GetOpt, set = SetOpt },
                    avgIlvlOutline = {
                        order = 3, type = "select", name = LText("Outline"),
                        values = { ["NONE"] = LText("None"), ["OUTLINE"] = LText("Outline"), ["THICKOUTLINE"] = LText("Thick Outline") },
                        get = GetOpt, set = SetOpt,
                    },
                    avgIlvlColor = {
                        order = 4, type = "color", name = LText("Color"), hasAlpha = false,
                        get = function(info) local c = self.db.avgIlvlColor; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) self.db.avgIlvlColor = {r=r, g=g, b=b}; self:Refresh() end,
                    },
                },
            },
            enchantGroup = {
                order = 30, type = "group", name = LText("Enchants Text"), inline = true,
                args = {
                    enchantFont = {
                        type = "select", dialogControl = "LSM30_Font", order = 1, name = LText("Font"),
                        values = LSM:HashTable("font"), get = GetOpt, set = SetOpt,
                    },
                    enchantSize = { order = 2, type = "range", name = LText("Size"), min = 8, max = 20, step = 1, get = GetOpt, set = SetOpt },
                    enchantColor = {
                        order = 3, type = "color", name = LText("Color"), hasAlpha = false,
                        get = function(info) local c = self.db.enchantColor; return c.r, c.g, c.b end,
                        set = function(info, r, g, b) self.db.enchantColor = {r=r, g=g, b=b}; self:Refresh() end,
                    },
                },
            },
        },
    }
    return options
end

function INS:Refresh()
    self.db = KT.db.profile.inspectArmory or KT.db.profile.armory
    
    if _G.InspectFrame and _G.InspectFrame:IsShown() then
        self:SetupLayout()
        self:UpdateHeaderIcons(_G.InspectFrame.unit)
        for _, slotName in pairs(SLOT_NAMES) do
            local btn = _G["Inspect"..slotName]
            if btn then self:UpdateSlot(btn) end
        end
    end
end
