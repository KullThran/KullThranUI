-------------------------------------------------------------------------------
--  KUI_ProgressBars_Options.lua
--  Pestaña de opciones independiente para Aura Bars y Buff Bars
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

-- Variables de Color
local function CurrentAccentColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    return (accent and accent.r) or KT.C_R or 1,
        (accent and accent.g) or KT.C_G or 0,
        (accent and accent.b) or KT.C_B or 0.3333333333
end

local ACCENT = setmetatable({}, {
    __index = function(_, key)
        local r, g, b = CurrentAccentColor()
        if key == "r" then return r end
        if key == "g" then return g end
        if key == "b" then return b end
        return nil
    end,
})

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

local function NormalizeProgressSpellID(value)
    if type(value) == "number" then
        if value == 0 then return 0 end
        return math.floor(value)
    end
    if type(value) == "string" then
        local token = value:match("-?%d+")
        local num = token and tonumber(token)
        if num then
            return math.floor(num)
        end
    end
    return 0
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, innerValue in pairs(value) do
        copy[key] = DeepCopy(innerValue)
    end
    return copy
end

local function IsGenericProgressBarName(name)
    if type(name) ~= "string" then return true end
    if name == "" then return true end
    return name:match("^Buff Bar %d+$") or name:match("^Aura Bar %d+$")
end

local function GetResolvedProgressBarName(cfg)
    if not cfg then return "Bar" end

    local spellID = NormalizeProgressSpellID(cfg.spellID)
    if spellID > 0 and C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name and (IsGenericProgressBarName(cfg.name) or cfg._forceSpellNameLabel) then
            return info.name
        end
    elseif spellID < 0 and C_Item and C_Item.GetItemNameByID then
        local itemName = C_Item.GetItemNameByID(-spellID)
        if itemName and (IsGenericProgressBarName(cfg.name) or cfg._forceSpellNameLabel) then
            return itemName
        end
    end

    if type(cfg.name) == "string" and cfg.name ~= "" then
        return cfg.name
    end

    return "Bar"
end

local function GetSuggestedProgressBarDuration(spellID, fallback, spellName)
    if ns and ns.GetStoredProgressSpellDuration then
        return ns.GetStoredProgressSpellDuration(spellID, fallback or 10, spellName)
    end
    return fallback or 10
end

local function IsKnownPlayerSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return false end
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    if IsSpellKnown and IsSpellKnown(spellID) then return true end
    if C_Spell and C_Spell.IsSpellKnown and C_Spell.IsSpellKnown(spellID) then return true end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID)
        if ok and known then return true end
    end
    return false
end

-- Acceso a BD (usa la misma para mantener compatibilidad con tu motor)
local function GetDefaultCatalogForPlayer()
    local _, classToken = UnitClass("player")
    local defaults = {}

    if classToken == "PALADIN" then
        defaults[#defaults + 1] = 1044  -- Blessing of Freedom
        defaults[#defaults + 1] = 1022  -- Blessing of Protection
        defaults[#defaults + 1] = 642   -- Divine Shield
    elseif classToken == "MAGE" then
        defaults[#defaults + 1] = 45438 -- Ice Block
        defaults[#defaults + 1] = 12051 -- Evocation
    elseif classToken == "DRUID" then
        defaults[#defaults + 1] = 22812 -- Barkskin
        defaults[#defaults + 1] = 102342 -- Ironbark
    elseif classToken == "PRIEST" then
        defaults[#defaults + 1] = 33206 -- Pain Suppression
        defaults[#defaults + 1] = 47788 -- Guardian Spirit
        defaults[#defaults + 1] = 194384 -- Atonement (buff)
    elseif classToken == "WARRIOR" then
        defaults[#defaults + 1] = 871   -- Shield Wall
        defaults[#defaults + 1] = 23920 -- Spell Reflection
    elseif classToken == "HUNTER" then
        defaults[#defaults + 1] = 5384  -- Feign Death
        defaults[#defaults + 1] = 186265 -- Aspect of the Turtle
    elseif classToken == "WARLOCK" then
        defaults[#defaults + 1] = 104773 -- Unending Resolve
    elseif classToken == "DEMONHUNTER" then
        defaults[#defaults + 1] = 187827 -- Metamorphosis
    elseif classToken == "DEATHKNIGHT" then
        defaults[#defaults + 1] = 48792 -- Icebound Fortitude
        defaults[#defaults + 1] = 55233 -- Vampiric Blood
    elseif classToken == "SHAMAN" then
        defaults[#defaults + 1] = 108271 -- Astral Shift
    elseif classToken == "MONK" then
        defaults[#defaults + 1] = 115203 -- Fortifying Brew
    elseif classToken == "ROGUE" then
        defaults[#defaults + 1] = 31224 -- Cloak of Shadows
        defaults[#defaults + 1] = 5277  -- Evasion
    elseif classToken == "EVOKER" then
        defaults[#defaults + 1] = 363916 -- Obsidian Scales
    end

    return defaults
end

local function BuildCatalogForCurrentPlayer(existingCatalog)
    local final = {}
    local seen = {}

    local function TryAdd(entryID, allowShared)
        local spellID = NormalizeProgressSpellID(entryID)
        if spellID == 0 or seen[spellID] then return end

        if spellID < 0 then
            if C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(-spellID) then
                seen[spellID] = true
                final[#final + 1] = spellID
            end
            return
        end

        if not (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) then
            return
        end

        if allowShared or IsKnownPlayerSpell(spellID) then
            seen[spellID] = true
            final[#final + 1] = spellID
        end
    end

    for _, spellID in ipairs(GetDefaultCatalogForPlayer()) do
        TryAdd(spellID, true)
    end
    for _, spellID in ipairs(existingCatalog or {}) do
        TryAdd(spellID, false)
    end

    return final
end

local function DB()
    KT.db.profile.progressBars = KT.db.profile.progressBars or {}
    local p = KT.db.profile.progressBars
    if p.enable == nil then
        p.enable = true
    end
    if not p._migratedFromCooldownManager then
        local legacy = KT.db.profile.cooldownManager
        if type(legacy) == "table" then
            if p.trackedBuffBars == nil and type(legacy.trackedBuffBars) == "table" then
                p.trackedBuffBars = DeepCopy(legacy.trackedBuffBars)
            end
            if p.customAuraBars == nil and type(legacy.customAuraBars) == "table" then
                p.customAuraBars = DeepCopy(legacy.customAuraBars)
            end
            if p.catalog == nil and type(legacy.catalog) == "table" then
                p.catalog = DeepCopy(legacy.catalog)
            end
            if p._selectedBuffID == nil and legacy._selectedBuffID ~= nil then
                p._selectedBuffID = legacy._selectedBuffID
            end
            if p._selectedAuraID == nil and legacy._selectedAuraID ~= nil then
                p._selectedAuraID = legacy._selectedAuraID
            end
            if p.tbbPositions == nil and type(legacy.tbbPositions) == "table" then
                p.tbbPositions = DeepCopy(legacy.tbbPositions)
            end
        end
        p._migratedFromCooldownManager = true
    end
    if not p.trackedBuffBars then p.trackedBuffBars = { selectedBar = 1, bars = {} } end
    if not p.customAuraBars then p.customAuraBars = { selectedBar = 1, bars = {} } end
    if not p.catalog then p.catalog = {} end
    if not p.tbbPositions then p.tbbPositions = {} end
    p._catalogSeeded = true
    p.catalog = BuildCatalogForCurrentPlayer(p.catalog)
    for _, cfg in ipairs(p.trackedBuffBars.bars or {}) do
        cfg.spellID = NormalizeProgressSpellID(cfg.spellID)
        cfg.triggerType = "trackedbuff"
        cfg.unit = "player"
        if not cfg.useCustomDuration and cfg.spellID ~= 0 then
            cfg.duration = GetSuggestedProgressBarDuration(cfg.spellID, cfg.duration or 10)
        end
    end
    for _, cfg in ipairs(p.customAuraBars.bars or {}) do
        cfg.spellID = NormalizeProgressSpellID(cfg.spellID)
        if not cfg.useCustomDuration and cfg.spellID ~= 0 then
            cfg.duration = GetSuggestedProgressBarDuration(cfg.spellID, cfg.duration or 10)
        end
    end

    local function RestoreSelectedSpell(profileKey, selectedKey)
        local profile = p[profileKey]
        local bars = profile and profile.bars
        if type(bars) ~= "table" or #bars ~= 1 then
            return
        end

        local selectedID = NormalizeProgressSpellID(p[selectedKey])
        local onlyBar = bars[1]
        if not onlyBar or NormalizeProgressSpellID(onlyBar.spellID) ~= 0 or selectedID == 0 then
            return
        end

        onlyBar.spellID = selectedID
        if not onlyBar.useCustomDuration then
            onlyBar.duration = GetSuggestedProgressBarDuration(selectedID, onlyBar.duration or 10, onlyBar.name)
        end
        if selectedID > 0 and C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(selectedID)
            if info and info.name and (IsGenericProgressBarName(onlyBar.name) or onlyBar._forceSpellNameLabel) then
                onlyBar.name = info.name
            end
        elseif selectedID < 0 and C_Item and C_Item.GetItemNameByID then
            local itemName = C_Item.GetItemNameByID(-selectedID)
            if itemName and (IsGenericProgressBarName(onlyBar.name) or onlyBar._forceSpellNameLabel) then
                onlyBar.name = itemName
            end
        end
    end

    RestoreSelectedSpell("trackedBuffBars", "_selectedBuffID")
    RestoreSelectedSpell("customAuraBars", "_selectedAuraID")
    return p
end

function ns.GetTBBProfile() return DB().trackedBuffBars end
function ns.GetAuraProfile() return DB().customAuraBars end

local pbActiveTab = "buffbars"
local selectedTBBIndex = 1
local selectedAuraBarIndex = 1

local function SelectedTBB()
    local tbb = ns.GetTBBProfile()
    if selectedTBBIndex < 1 then selectedTBBIndex = 1 end
    if #tbb.bars == 0 then return nil end
    if selectedTBBIndex > #tbb.bars then selectedTBBIndex = #tbb.bars end
    return tbb.bars[selectedTBBIndex]
end

local function SelectedAuraBar()
    local ab = ns.GetAuraProfile()
    if selectedAuraBarIndex < 1 then selectedAuraBarIndex = 1 end
    if #ab.bars == 0 then return nil end
    if selectedAuraBarIndex > #ab.bars then selectedAuraBarIndex = #ab.bars end
    return ab.bars[selectedAuraBarIndex]
end

local function Refresh()
    if ns.BuildInGameProgressBars then ns.BuildInGameProgressBars() end
end

local function GetProgressBarTextureName(cfg)
    if cfg and type(cfg.texture) == "string" and cfg.texture ~= "" then
        return cfg.texture
    end
    if LSM and LSM:Fetch("statusbar", "Melli", true) then
        return "Melli"
    end
    return nil
end

local function GetProgressBarTexturePath(cfg)
    local textureName = GetProgressBarTextureName(cfg)
    if LSM and textureName then
        local texturePath = LSM:Fetch("statusbar", textureName, true)
        if texturePath and texturePath ~= "" then
            return texturePath
        end
    end
    return "Interface\\Buttons\\WHITE8x8"
end

-- ============================================================================
-- HELPERS BÁSICOS
-- ============================================================================
local function MakeSeparator(parent, yOff, alpha)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1); sep:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOff); sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOff)
    sep:SetColorTexture(1, 1, 1, alpha or 0.06)
    return sep, 8
end

local _cachedSCWidth = 0
local function SafeFrameWidth(frame, fallback)
    fallback = fallback or 300
    if not frame then return fallback end
    local ok, w = pcall(function() return frame:GetWidth() end)
    if not ok or type(w) ~= "number" or w < 10 then return fallback end
    return math.floor(w)
end
local function GetSCSafeWidth(sc)
    local w = SafeFrameWidth(sc, _cachedSCWidth > 10 and _cachedSCWidth or 300)
    if w > 10 then _cachedSCWidth = w end
    return w
end

local function SafeAddBackdrop(frame, r, g, b, a)
    if not frame or not KT.AddBackdrop then return end
    pcall(KT.AddBackdrop, KT, frame, r, g, b, a)
end
local function SafeAddBorder(frame, r, g, b, a)
    if not frame or not KT.AddBorder then return end
    pcall(KT.AddBorder, KT, frame, r, g, b, a)
end

local function SafeInput(parent, yOff, title, getValue, setValue)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(SafeFrameWidth(parent, 300) - 20, 50)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOff)

    local lbl = frame:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    lbl:SetTextColor(0.7, 0.7, 0.7, 1); lbl:SetPoint("TOPLEFT", 0, -4); lbl:SetText(title)

    local box = CreateFrame("EditBox", nil, frame)
    box:SetSize(SafeFrameWidth(frame, 280) - 4, 22); box:SetPoint("TOPLEFT", 0, -20)
    box:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, ""); box:SetTextColor(1, 1, 1, 1); box:SetAutoFocus(false); box:SetMaxLetters(64)
    local boxBg = box:CreateTexture(nil, "BACKGROUND"); boxBg:SetAllPoints(); boxBg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    box:SetText(getValue() or "")
    
    box:SetScript("OnEnterPressed", function(self)
        setValue(self:GetText()); self:ClearFocus()
        if KT.RefreshPage then KT:RefreshPage() end
    end)
    box:SetScript("OnEscapePressed", function(self) self:SetText(getValue() or ""); self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self) setValue(self:GetText()) end)
    return frame, 54
end

local function GetIDFromCursor()
    local infoType, val1, val2, val3 = GetCursorInfo()
    if infoType == "spell" then return val3 or val1 elseif infoType == "item" then return -val1 end
    return nil
end

-- ============================================================================
-- AÑADIR/ELIMINAR BARRAS
-- ============================================================================
local DEFAULT_BAR_CONFIG = { 
    height = 24, width = 270, fillR = ACCENT.r, fillG = ACCENT.g, fillB = ACCENT.b, fillA = 1,
    bgR = 0, bgG = 0, bgB = 0, bgA = 0.4, borderR = 0, borderG = 0, borderB = 0, borderSize = 1,
    showName = true, showTimer = true, showSpark = false, opacity = 1.0, iconDisplay = "left", iconSize = 24,
    iconX = 0, iconY = 0, iconBorderSize = 0, triggerType = "spellcast", unit = "player", barMode = "duration", duration = 10,
    texture = "Melli",
}

function ns.AddTBB()
    local tbb = ns.GetTBBProfile(); local newBar = {}
    local p = DB()
    local selectedID = NormalizeProgressSpellID(p and p._selectedBuffID)
    local source = (#tbb.bars > 0) and tbb.bars[#tbb.bars] or DEFAULT_BAR_CONFIG
    for k, v in pairs(source) do newBar[k] = v end
    newBar.spellID = selectedID ~= 0 and selectedID or 0
    newBar.name = "Buff Bar " .. (#tbb.bars + 1)
    newBar.triggerType = "trackedbuff"
    newBar.unit = "player"
    newBar._forceSpellNameLabel = true
    if selectedID ~= 0 then
        newBar.duration = GetSuggestedProgressBarDuration(selectedID, newBar.duration or 10)
        newBar.name = GetResolvedProgressBarName(newBar)
    end
    table.insert(tbb.bars, newBar); selectedTBBIndex = #tbb.bars; Refresh()
end
function ns.RemoveTBB()
    local tbb = ns.GetTBBProfile()
    if selectedTBBIndex >= 1 and selectedTBBIndex <= #tbb.bars then
        table.remove(tbb.bars, selectedTBBIndex); selectedTBBIndex = math.max(1, #tbb.bars); Refresh()
    end
end
function ns.AddAuraBar()
    local ab = ns.GetAuraProfile(); local newBar = {}
    local p = DB()
    local selectedID = NormalizeProgressSpellID(p and p._selectedAuraID)
    local source = (#ab.bars > 0) and ab.bars[#ab.bars] or DEFAULT_BAR_CONFIG
    for k, v in pairs(source) do newBar[k] = v end
    newBar.spellID = selectedID ~= 0 and selectedID or 0
    newBar.name = "Aura Bar " .. (#ab.bars + 1)
    newBar.triggerType = "spellcast"
    if selectedID ~= 0 then
        newBar.duration = GetSuggestedProgressBarDuration(selectedID, newBar.duration or 10)
        newBar.name = GetResolvedProgressBarName(newBar)
    end
    table.insert(ab.bars, newBar); selectedAuraBarIndex = #ab.bars; Refresh()
end
function ns.RemoveAuraBar()
    local ab = ns.GetAuraProfile()
    if selectedAuraBarIndex >= 1 and selectedAuraBarIndex <= #ab.bars then
        table.remove(ab.bars, selectedAuraBarIndex); selectedAuraBarIndex = math.max(1, #ab.bars); Refresh()
    end
end

-- ============================================================================
-- AURA CATALOG BUILDER
-- ============================================================================
local function BuildCatalogSection(sc, W, yOff, isBuff)
    local y = math.abs(yOff); local _, h; local p = DB(); local scW = GetSCSafeWidth(sc)

    _, h = W:SectionHeader(sc, "Aura Catalog", -y); y = y + h
    
    local dz = CreateFrame("Button", nil, sc, "BackdropTemplate")
    dz:SetSize(scW - 20, 60); dz:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
    SafeAddBackdrop(dz, 0.08, 0.08, 0.10, 0.8); SafeAddBorder(dz, ACCENT.r, ACCENT.g, ACCENT.b, 0.6)
    
    local dzBookBtn = CreateFrame("Button", nil, sc, "BackdropTemplate")
    dzBookBtn:SetSize(60, 60); dzBookBtn:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
    SafeAddBackdrop(dzBookBtn, 0.08, 0.08, 0.10, 0.9); SafeAddBorder(dzBookBtn, ACCENT.r, ACCENT.g, ACCENT.b, 0.7)

    local dzIcon = dzBookBtn:CreateTexture(nil, "ARTWORK")
    dzIcon:SetPoint("TOPLEFT", 4, -4); dzIcon:SetPoint("BOTTOMRIGHT", -4, 4)
    dzIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09"); dzIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92); dzIcon:SetAlpha(0.85)

    local dzBookLabel = dzBookBtn:CreateFontString(nil, "OVERLAY")
    dzBookLabel:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE"); dzBookLabel:SetPoint("BOTTOM", dzBookBtn, "BOTTOM", 0, 2)
    dzBookLabel:SetText(LText("Spellbook")); dzBookLabel:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.9)

    local function OnCatalogDrop()
        local spellID = NormalizeProgressSpellID(GetIDFromCursor())
        if spellID ~= 0 then
            local found = false
            for _, v in ipairs(p.catalog) do if v == spellID then found = true break end end
            if not found then table.insert(p.catalog, spellID) end
            ClearCursor(); if KT.RefreshPage then KT:RefreshPage() end
        end
    end

    dzBookBtn:SetScript("OnClick", function()
        if GetCursorInfo() then OnCatalogDrop()
        else
            if PlayerSpellsFrame then
                if PlayerSpellsFrame:IsShown() then PlayerSpellsFrame:Hide() else PlayerSpellsFrame:Show() end
            elseif C_SpellBook and C_SpellBook.OpenSpellBook then C_SpellBook.OpenSpellBook() end
        end
    end)
    dzBookBtn:SetScript("OnReceiveDrag", OnCatalogDrop)

    local dzText = dz:CreateFontString(nil, "OVERLAY")
    dzText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE"); dzText:SetPoint("CENTER", dz, "CENTER", 0, 0)
    dzText:SetText(LText("|cff00ff00Drag & Drop|r a Spell or Item from your Spellbook\ninto this area or the book button to track it."))
    dzText:SetTextColor(1, 1, 1, 0.8); dzText:SetJustifyH("CENTER")

    dz:ClearAllPoints(); dz:SetSize(scW - 20 - 70, 60); dz:SetPoint("LEFT", dzBookBtn, "RIGHT", 6, 0)
    dz:SetScript("OnReceiveDrag", OnCatalogDrop)
    dz:SetScript("OnClick", function() if GetCursorInfo() then OnCatalogDrop() end end)

    y = y + 70
    
    if #p.catalog == 0 then
        _, h = W:Label(sc, "|cff888888Your catalog is empty. Drag a spell above to start.|r", -y, 11); y = y + h + 10
        return y
    end

    local cx = 0; local cy = y
    local selectedID = isBuff and p._selectedBuffID or p._selectedAuraID

    for i, spellID in ipairs(p.catalog) do
        local btn = CreateFrame("Button", nil, sc, "BackdropTemplate")
        btn:SetSize(40, 40); btn:SetPoint("TOPLEFT", sc, "TOPLEFT", 10 + cx, -cy)
        SafeAddBackdrop(btn, 0.08, 0.08, 0.10, 1)
        
        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 2, -2); tex:SetPoint("BOTTOMRIGHT", -2, 2); tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        if spellID > 0 then tex:SetTexture(C_Spell.GetSpellTexture(spellID) or 134400) else tex:SetTexture(C_Item.GetItemIconByID(-spellID) or 134400) end

        if selectedID == spellID then SafeAddBorder(btn, ACCENT.r, ACCENT.g, ACCENT.b, 1) else SafeAddBorder(btn, 0, 0, 0, 1) end

        btn:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                table.remove(p.catalog, i)
                if isBuff and p._selectedBuffID == spellID then p._selectedBuffID = nil end
                if not isBuff and p._selectedAuraID == spellID then p._selectedAuraID = nil end
            else
                if isBuff then p._selectedBuffID = spellID else p._selectedAuraID = spellID end
            end
            if KT.RefreshPage then KT:RefreshPage() end
        end)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            if spellID > 0 then GameTooltip:SetSpellByID(spellID) else GameTooltip:SetItemByID(-spellID) end
            GameTooltip:AddLine(" "); GameTooltip:AddLine(LText("Left-Click to select"), 0, 1, 0); GameTooltip:AddLine(LText("Right-Click to remove from catalog"), 1, 0, 0)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        cx = cx + 46
        if (10 + cx + 40) > (scW - 20) then cx = 0; cy = cy + 46 end
    end

    y = cy + 50

    if selectedID then
        local sName = selectedID > 0 and C_Spell.GetSpellName(selectedID) or C_Item.GetItemNameByID(-selectedID)
        local accentHex = string.format("|cff%02x%02x%02x", ACCENT.r*255, ACCENT.g*255, ACCENT.b*255)
        _, h = W:Label(sc, accentHex .. "Selected:|r " .. (sName or "Unknown ID: " .. selectedID), -y, 13); y = y + h
        
        _, h = W:Button(sc, LText("Create Bar for Selected"), -y, function()
            local targetProfile = isBuff and ns.GetTBBProfile() or ns.GetAuraProfile()
            table.insert(targetProfile.bars, {
                spellID = selectedID, name = sName or "New Bar", height = 24, width = 270,
                fillR = ACCENT.r, fillG = ACCENT.g, fillB = ACCENT.b, fillA = 1, bgR = 0, bgG = 0, bgB = 0, bgA = 0.4,
                borderR = 0, borderG = 0, borderB = 0, borderSize = 1, showName = true, showTimer = true, showSpark = false,
                opacity = 1.0, iconDisplay = "left", iconSize = 24, iconX = 0, iconY = 0, iconBorderSize = 0, triggerType = isBuff and "trackedbuff" or "spellcast",
                unit = "player", barMode = "duration", duration = GetSuggestedProgressBarDuration(selectedID, 10, sName), texture = "Melli",
                _forceSpellNameLabel = isBuff and true or nil,
            })
            if isBuff then selectedTBBIndex = #targetProfile.bars else selectedAuraBarIndex = #targetProfile.bars end
            Refresh(); if KT.RefreshPage then KT:RefreshPage() end
        end); y = y + h
    end

    _, h = MakeSeparator(sc, -y, 0.2); y = y + h + 10
    return y
end

-- ============================================================================
-- LIVE PREVIEW PARA PROGRESS BARS
-- ============================================================================
local function DrawStatusBarPreview(parent, yOff, tbd)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    local w, h = tbd.width or 270, tbd.height or 24
    f:SetSize(w, h); f:SetPoint("TOP", parent, "TOP", 0, yOff)

    local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    bg:SetColorTexture(tbd.bgR or 0, tbd.bgG or 0, tbd.bgB or 0, tbd.bgA or 0.4)

    local bar = CreateFrame("StatusBar", nil, f); bar:SetAllPoints()
    local tex = GetProgressBarTexturePath(tbd)
    bar:SetStatusBarTexture(tex); bar:SetStatusBarColor(tbd.fillR or ACCENT.r, tbd.fillG or ACCENT.g, tbd.fillB or ACCENT.b, tbd.fillA or 1)
    bar:SetMinMaxValues(0, 1); bar:SetValue(0.65)

    if tbd.showSpark then
        local spark = bar:CreateTexture(nil, "OVERLAY")
        spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark"); spark:SetBlendMode("ADD"); spark:SetSize(16, h * 2)
        spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    end

    local defaultIcon, firstID = 134400, nil
    if type(tbd.spellID) == "string" then for id in string.gmatch(tbd.spellID, "%d+") do firstID = tonumber(id); break end else firstID = tonumber(tbd.spellID) end
    if firstID and firstID > 0 then defaultIcon = C_Spell.GetSpellTexture(firstID) or 134400 elseif firstID and firstID < 0 then defaultIcon = C_Item.GetItemIconByID(-firstID) or 134400 end

    if tbd.iconDisplay and tbd.iconDisplay ~= "none" then
        local icon = f:CreateTexture(nil, "ARTWORK")
        local iSz = tbd.iconSize or 24
        icon:SetSize(iSz, iSz)
        local ix, iy = tbd.iconX or 0, tbd.iconY or 0
        if tbd.iconDisplay == "left" then icon:SetPoint("RIGHT", f, "LEFT", -2 + ix, iy) else icon:SetPoint("LEFT", f, "RIGHT", 2 + ix, iy) end
        icon:SetTexture(defaultIcon); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if tbd.iconBorderSize and tbd.iconBorderSize > 0 then
            local ib = CreateFrame("Frame", nil, f, "BackdropTemplate")
            ib:SetAllPoints(icon); ib:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = tbd.iconBorderSize})
            ib:SetBackdropBorderColor(tbd.borderR or 0, tbd.borderG or 0, tbd.borderB or 0, 1)
        end
    end

    if tbd.showName ~= false then
        local txt = bar:CreateFontString(nil, "OVERLAY")
        txt:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", tbd.nameSize or 11, "OUTLINE")
        txt:SetPoint("LEFT", 4 + (tbd.nameX or 0), tbd.nameY or 0)
        local dName = tbd.name or "Aura Name"
        if firstID and firstID > 0 then local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(firstID); if info and info.name then dName = info.name end elseif firstID and firstID < 0 then local itemName = C_Item.GetItemNameByID(-firstID); if itemName then dName = itemName end end
        txt:SetText(dName)
    end

    if tbd.showTimer then
        local tmr = bar:CreateFontString(nil, "OVERLAY")
        tmr:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", tbd.timerSize or 11, "OUTLINE")
        tmr:SetPoint("RIGHT", -4 + (tbd.timerX or 0), tbd.timerY or 0); tmr:SetText("12.5")
    end

    if tbd.borderSize and tbd.borderSize > 0 then
        local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
        border:SetAllPoints(); border:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = tbd.borderSize})
        border:SetBackdropBorderColor(tbd.borderR or 0, tbd.borderG or 0, tbd.borderB or 0, 1)
    end

    local dropHint = f:CreateFontString(nil, "OVERLAY")
    dropHint:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    dropHint:SetPoint("BOTTOM", f, "TOP", 0, 4); dropHint:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1); dropHint:SetText(LText("↑ Drag & Drop Spell Here ↑"))

    dropHint:SetText(LText("↑ Drag & Drop Spell Here ↑"))
    local function OnDrop()
        local spellID = NormalizeProgressSpellID(GetIDFromCursor())
        if spellID ~= 0 then
            tbd.spellID = spellID
            if spellID > 0 then
                local info = C_Spell.GetSpellInfo(spellID)
                if info and info.name then tbd.name = info.name end
            elseif spellID < 0 and C_Item and C_Item.GetItemNameByID then
                local itemName = C_Item.GetItemNameByID(-spellID)
                if itemName then tbd.name = itemName end
            end
            ClearCursor(); Refresh(); if KT.RefreshPage then KT:RefreshPage() end
        end
    end
    f:SetScript("OnReceiveDrag", OnDrop)
    f:SetScript("OnClick", function() if GetCursorInfo() then OnDrop() end end)

    return f, math.max(h, tbd.iconDisplay ~= "none" and (tbd.iconSize or 24) or 0) + 30
end

local function DrawSpellIconBadge(sc, y, tbd)
    local sid
    if type(tbd.spellID) == "number" then sid = tbd.spellID ~= 0 and tbd.spellID or nil
    elseif type(tbd.spellID) == "string" then for id in string.gmatch(tostring(tbd.spellID), "-?%d+") do sid = tonumber(id); break end end
    if not sid or sid == 0 then return y end

    local iconID = sid > 0 and (C_Spell.GetSpellTexture(sid) or 134400) or (C_Item.GetItemIconByID(-sid) or 134400)
    local spellName = sid > 0 and (C_Spell.GetSpellName(sid) or ("ID: "..sid)) or (C_Item.GetItemNameByID(-sid) or ("Item: "..-sid))

    local iSz = 40
    local badge = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    badge:SetSize(SafeFrameWidth(sc, 300) - 20, iSz + 8)
    badge:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
    SafeAddBackdrop(badge, 0.06, 0.06, 0.08, 0.92); SafeAddBorder(badge, ACCENT.r, ACCENT.g, ACCENT.b, 0.8)

    local iconTex = badge:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(iSz, iSz); iconTex:SetPoint("LEFT", badge, "LEFT", 4, 0)
    iconTex:SetTexture(iconID); iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local nameTxt = badge:CreateFontString(nil, "OVERLAY")
    nameTxt:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    nameTxt:SetPoint("TOPLEFT", iconTex, "TOPRIGHT", 8, -4)
    nameTxt:SetText(string.format("|cff%02x%02x%02x%s|r", ACCENT.r*255, ACCENT.g*255, ACCENT.b*255, spellName))

    local idTxt = badge:CreateFontString(nil, "OVERLAY")
    idTxt:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    idTxt:SetPoint("BOTTOMLEFT", iconTex, "BOTTOMRIGHT", 8, 4)
    idTxt:SetText(LText("|cff555555ID: ")..tostring(sid).."|r")

    return y + iSz + 14
end

local function CreateSettingsContainer(parent, startY, title)
    local block = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local width = SafeFrameWidth(parent, 320) - 20
    block:SetSize(width, 1)
    block:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -startY)
    SafeAddBackdrop(block, 0.06, 0.06, 0.08, 0.94)
    SafeAddBorder(block, ACCENT.r, ACCENT.g, ACCENT.b, 0.75)

    local y = 12
    local titleText = block:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    titleText:SetPoint("TOPLEFT", block, "TOPLEFT", 12, -y)
    titleText:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
    titleText:SetText(LText(title))
    y = y + 20

    local sep = block:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", block, "TOPLEFT", 12, -y)
    sep:SetPoint("TOPRIGHT", block, "TOPRIGHT", -12, -y)
    sep:SetHeight(1)
    sep:SetColorTexture(1, 1, 1, 0.08)
    y = y + 10

    return block, y
end

local function BuildProgressBarsTab(sc, W, startY, isBuff)
    local y, h = startY, 0
    local profile = isBuff and ns.GetTBBProfile() or ns.GetAuraProfile()

    y = BuildCatalogSection(sc, W, -y, isBuff)

    local tbBars = profile.bars or {}
    local activeBlock, activeY = CreateSettingsContainer(sc, y, "Active Bars")

    if #tbBars == 0 then
        _, h = W:Label(activeBlock, LText("No bars configured yet."), -activeY, 11); activeY = activeY + h
        _, h = W:Button(activeBlock, LText("+ Add New Bar"), -activeY, function()
            if isBuff then ns.AddTBB() else ns.AddAuraBar() end
            if KT.RefreshPage then KT:RefreshPage() end
        end, 160); activeY = activeY + h
        activeBlock:SetHeight(activeY + 12)
        return y + activeBlock:GetHeight() + 12
    end

    local tbbLabels, tbbOrder = {}, {}
    for i, b in ipairs(tbBars) do
        local ks = tostring(i)
        tbbLabels[ks] = GetResolvedProgressBarName(b) or ("Bar " .. i)
        tbbOrder[#tbbOrder + 1] = ks
    end
    
    _, h = W:Dropdown(activeBlock, LText("Select Bar"), -activeY, tbbLabels,
        function() return tostring(isBuff and selectedTBBIndex or selectedAuraBarIndex) end,
        function(v) 
            if isBuff then selectedTBBIndex = tonumber(v) or 1 else selectedAuraBarIndex = tonumber(v) or 1 end
            if KT.RefreshPage then KT:RefreshPage() end 
        end,
        tbbOrder
    ); activeY = activeY + h

    _, h = W:Button(activeBlock, LText("+ Add Bar"), -activeY, function()
        if isBuff then ns.AddTBB() else ns.AddAuraBar() end
        if KT.RefreshPage then KT:RefreshPage() end
    end, 140); activeY = activeY + h

    _, h = W:Button(activeBlock, "— Delete Selected", -activeY, function()
        if isBuff then ns.RemoveTBB() else ns.RemoveAuraBar() end
        if KT.RefreshPage then KT:RefreshPage() end
    end, 160); activeY = activeY + h
    activeBlock:SetHeight(activeY + 12)
    y = y + activeBlock:GetHeight() + 12

    local tbd = isBuff and SelectedTBB() or SelectedAuraBar()
    if not tbd then return y end

    tbd.triggerType = isBuff and "trackedbuff" or "spellcast"
    if isBuff then
        tbd.unit = "player"
    end
    tbd.texture = GetProgressBarTextureName(tbd) or tbd.texture
    local configBlock, configY = CreateSettingsContainer(sc, y, isBuff and "Buff Bar Configuration" or "Aura Bar Configuration")

    _, h = W:SectionHeader(configBlock, LText("Live Preview & Drop Zone"), -configY); configY = configY + h
    local pv, pvH = DrawStatusBarPreview(configBlock, -configY, tbd)
    configY = configY + pvH + 8

    _, h = W:SectionHeader(configBlock, LText("Tracking Configuration"), -configY); configY = configY + h

    local fName, fH = SafeInput(configBlock, -configY, LText("Bar Name"),
        function() return tbd.name end,
        function(v) tbd.name = v; Refresh() end
    ); configY = configY + fH

    local sName, sH = SafeInput(configBlock, -configY, LText("Spell ID (Type & Enter, OR Drag Spell here)"),
        function()
            local sid = NormalizeProgressSpellID(tbd.spellID)
            return sid ~= 0 and tostring(sid) or ""
        end,
        function(v) 
            local sid = NormalizeProgressSpellID(v)
            tbd.spellID = sid
            if sid > 0 then
                local info = C_Spell.GetSpellInfo(sid)
                if info and info.name and (IsGenericProgressBarName(tbd.name) or tbd._forceSpellNameLabel) then
                    tbd.name = info.name
                end
            elseif sid < 0 and C_Item and C_Item.GetItemNameByID then
                local itemName = C_Item.GetItemNameByID(-sid)
                if itemName and (IsGenericProgressBarName(tbd.name) or tbd._forceSpellNameLabel) then
                    tbd.name = itemName
                end
            end
            if not tbd.useCustomDuration then
                tbd.duration = GetSuggestedProgressBarDuration(sid, tbd.duration or 10, tbd.name)
            end
            Refresh(); if KT.OpenMenu then KT:OpenMenu() end
        end
    ); configY = configY + sH

    do
        local p = DB()
        if p.catalog and #p.catalog > 0 then
            local values, order = {}, {}
            for _, id in ipairs(p.catalog) do
                local key = tostring(id)
                local nm
                if id > 0 then
                    nm = C_Spell.GetSpellName(id)
                elseif id < 0 and C_Item and C_Item.GetItemNameByID then
                    nm = C_Item.GetItemNameByID(-id)
                end
                values[key] = (nm and (nm .. " (" .. key .. ")")) or ("ID: " .. key)
                order[#order + 1] = key
            end

            _, h = W:Dropdown(configBlock, LText("Catalog Quick Pick"), -configY,
                values,
                function()
                    local selectedID = isBuff and p._selectedBuffID or p._selectedAuraID
                    return tostring(selectedID or p.catalog[1])
                end,
                function(v)
                    local sid = tonumber(v)
                    if not sid then return end
                    if isBuff then p._selectedBuffID = sid else p._selectedAuraID = sid end
                    ApplySelectedCatalogIDToBar(tbd, sid)
                    end,
                    order
            ); configY = configY + h
        end
    end

    configY = DrawSpellIconBadge(configBlock, configY, tbd)

    if not isBuff then
        _, h = W:Dropdown(configBlock, LText("Unit to Track"), -configY,
            { player = LText("Player"), target = LText("Target"), pet = LText("Pet"), focus = LText("Focus") },
            function() return tbd.unit or "player" end,
            function(v) tbd.unit = v; Refresh() end,
            { "player", "target", "pet", "focus" }
        ); configY = configY + h
    end

    _, h = W:Dropdown(configBlock, LText("Tracking Mode"), -configY,
        { duration = LText("Duration (Depletes over time)"), stacks = LText("Stacks (Fills per stack)") },
        function() return tbd.barMode or "duration" end,
        function(v) tbd.barMode = v; Refresh() end,
        { "duration", "stacks" }
    ); configY = configY + h

    _, h = W:SectionHeader(configBlock, LText("Manual Timer Duration"), -configY); configY = configY + h
    
    _, h = W:Slider(configBlock, LText("Timer Duration (Seconds)"), -configY,
        function() return tbd.duration or 10 end,
        function(v) tbd.duration = v; Refresh() end,
        1, 120, 1
    ); configY = configY + h
    
    _, h = W:Toggle(configBlock, LText("Override Blizzard Duration"), -configY,
        function() return tbd.useCustomDuration end,
        function(v) tbd.useCustomDuration = v; Refresh() end
    ); configY = configY + h

    _, h = W:SectionHeader(configBlock, LText("Bar Dimensions"), -configY); configY = configY + h
    _, h = W:Slider(configBlock, LText("Height"), -configY, function() return tbd.height or 24 end, function(v) tbd.height = v; Refresh() end, 1, 60, 1); configY = configY + h
    _, h = W:Slider(configBlock, LText("Width"), -configY, function() return tbd.width or 270 end, function(v) tbd.width = v; Refresh() end, 50, 500, 1); configY = configY + h

    _, h = W:SectionHeader(configBlock, LText("Appearance"), -configY); configY = configY + h
    _, h = W:Toggle(configBlock, LText("Show Spark"), -configY, function() return tbd.showSpark end, function(v) tbd.showSpark = v; Refresh() end); configY = configY + h
    _, h = W:Toggle(configBlock, LText("Show Buff Name"), -configY, function() return tbd.showName ~= false end, function(v) tbd.showName = v; Refresh() end); configY = configY + h
    _, h = W:Toggle(configBlock, LText("Show Duration Timer"), -configY, function() return tbd.showTimer end, function(v) tbd.showTimer = v; Refresh() end); configY = configY + h

    _, h = W:SectionHeader(configBlock, LText("Colors"), -configY); configY = configY + h
    if W.ColorSwatch then
        _, h = W:ColorSwatch(configBlock, LText("Fill Color"), -configY, function() return tbd.fillR or ACCENT.r, tbd.fillG or ACCENT.g, tbd.fillB or ACCENT.b, tbd.fillA or 1 end, function(r, g, b, a) tbd.fillR, tbd.fillG, tbd.fillB, tbd.fillA = r, g, b, a; Refresh() end, true); configY = configY + h
        _, h = W:ColorSwatch(configBlock, LText("Background Color"), -configY, function() return tbd.bgR or 0, tbd.bgG or 0, tbd.bgB or 0, tbd.bgA or 0.4 end, function(r, g, b, a) tbd.bgR, tbd.bgG, tbd.bgB, tbd.bgA = r, g, b, a; Refresh() end, true); configY = configY + h
        _, h = W:ColorSwatch(configBlock, LText("Border Color"), -configY, function() return tbd.borderR or 0, tbd.borderG or 0, tbd.borderB or 0 end, function(r, g, b) tbd.borderR, tbd.borderG, tbd.borderB = r, g, b; Refresh() end, false); configY = configY + h
    end
    _, h = W:Slider(configBlock, LText("Border Size"), -configY, function() return tbd.borderSize or 1 end, function(v) tbd.borderSize = v; Refresh() end, 0, 5, 1); configY = configY + h

    _, h = W:SectionHeader(configBlock, LText("Icon"), -configY); configY = configY + h
    _, h = W:Dropdown(configBlock, LText("Show Icon"), -configY, { none = LText("None"), left = LText("Left"), right = LText("Right") }, function() return tbd.iconDisplay or "none" end, function(v) tbd.iconDisplay = v; Refresh() end, { "none", "left", "right" }); configY = configY + h
    _, h = W:Slider(configBlock, LText("Icon Size"), -configY, function() return tbd.iconSize or 24 end, function(v) tbd.iconSize = v; Refresh() end, 8, 64, 1); configY = configY + h
    _, h = W:Slider(configBlock, LText("Icon X Offset"), -configY, function() return tbd.iconX or 0 end, function(v) tbd.iconX = v; Refresh() end, -40, 40, 1); configY = configY + h

    _, h = W:SectionHeader(configBlock, LText("Text Settings"), -configY); configY = configY + h
    _, h = W:Slider(configBlock, LText("Name Font Size"), -configY, function() return tbd.nameSize or 11 end, function(v) tbd.nameSize = v; Refresh() end, 6, 24, 1); configY = configY + h
    _, h = W:Slider(configBlock, LText("Timer Font Size"), -configY, function() return tbd.timerSize or 11 end, function(v) tbd.timerSize = v; Refresh() end, 6, 24, 1); configY = configY + h

    configBlock:SetHeight(configY + 12)
    return y + configBlock:GetHeight() + 12
end

local function ApplySelectedCatalogIDToBar(tbd, selectedID)
    if not tbd or not selectedID then return end
    tbd.spellID = selectedID
    if not tbd.useCustomDuration then
        tbd.duration = GetSuggestedProgressBarDuration(selectedID, tbd.duration or 10, tbd.name)
    end
    if selectedID > 0 then
        local info = C_Spell.GetSpellInfo(selectedID)
        if info and info.name and (IsGenericProgressBarName(tbd.name) or tbd._forceSpellNameLabel) then
            tbd.name = info.name
        end
    elseif selectedID < 0 then
        local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(-selectedID)
        if itemName and (IsGenericProgressBarName(tbd.name) or tbd._forceSpellNameLabel) then
            tbd.name = itemName
        end
    end
    Refresh()
    if KT.RefreshPage then KT:RefreshPage() end
end

-- Reusable render hooks so other pages (e.g. CDM > Buff Bars) can embed this UI.
function ns.RenderProgressBarsTab(sc, W, startY, isBuff)
    return BuildProgressBarsTab(sc, W, startY, isBuff == true)
end

function ns.RenderProgressBuffBarsTab(sc, W, startY)
    return BuildProgressBarsTab(sc, W, startY, true)
end

-- ============================================================================
-- TAB BAR & PÁGINA PRINCIPAL
-- ============================================================================
local TAB_H   = 30
local TAB_GAP = 4
local _tabBarFrame = nil

local function BuildTabBar(sc, yOff)
    local tabs = {
        { id="buffbars",  label="Buff Bars"   },
        { id="aurabars",  label="Aura Bars"   },
    }
    local containerH = TAB_H + 6
    local container
    if _tabBarFrame and _tabBarFrame:GetParent() == sc then
        container = _tabBarFrame
        for _, child in ipairs({container:GetChildren()}) do child:Hide() end
    else
        if _tabBarFrame then _tabBarFrame:Hide() end
        container = CreateFrame("Frame", nil, sc)
        _tabBarFrame = container
    end
    container:SetHeight(containerH); container:ClearAllPoints(); container:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOff); container:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -4, yOff); container:Show()

    local scW = GetSCSafeWidth(sc)
    local tabWidth = math.floor((scW - 4 - (#tabs-1)*TAB_GAP) / #tabs)

    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == pbActiveTab)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetHeight(TAB_H); btn:SetWidth(tabWidth); btn:SetPoint("LEFT", container, "LEFT", (i-1)*(tabWidth+TAB_GAP), 0)
        if isActive then SafeAddBackdrop(btn, ACCENT.r, ACCENT.g, ACCENT.b, 0.15); SafeAddBorder(btn, ACCENT.r, ACCENT.g, ACCENT.b, 0.9)
        else SafeAddBackdrop(btn, 0.08, 0.08, 0.10, 0.7); SafeAddBorder(btn, 0.15, 0.15, 0.15, 0.6) end
        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE"); lbl:SetText(LText(tab.label)); lbl:SetAllPoints(); lbl:SetJustifyH("CENTER")
        if isActive then lbl:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1) else lbl:SetTextColor(0.75, 0.75, 0.75, 1) end
        local tid = tab.id
        btn:SetScript("OnClick", function() pbActiveTab = tid; if KT.RefreshPage then KT:RefreshPage() end end)
        btn:SetScript("OnEnter", function() if pbActiveTab ~= tid then lbl:SetTextColor(1,1,1,1) end end)
        btn:SetScript("OnLeave", function() if pbActiveTab ~= tid then lbl:SetTextColor(0.75,0.75,0.75,1) else lbl:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1) end end)
        btn:Show()
    end
    return container, containerH + 8
end

if KT and KT.RegisterPage then
    KT:RegisterPage("progressbars", LText("Progress Bars"), 14.5, function(sc, W)
        local y, h = 0, 0
        local db = DB()

        _, h = W:SectionHeader(sc, LText("Progress Bars"), -y)
        y = y + h
        _, h = W:Label(sc, LText("Independent progress bars for spell-triggered and aura-style tracking."), -y, 11)
        y = y + h
        _, h = W:Toggle(sc, LText("Enable Module"), -y,
            function() return db.enable ~= false end,
            function(v)
                db.enable = v and true or false
                Reload()
            end)
        y = y + h

        local _, tabH = BuildTabBar(sc, -y)
        y = y + tabH

        if pbActiveTab == "buffbars" then
            y = BuildProgressBarsTab(sc, W, y, true)
        else
            y = BuildProgressBarsTab(sc, W, y, false)
        end

        return y
    end)
end

