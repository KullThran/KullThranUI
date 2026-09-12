-------------------------------------------------------------------------------
--  KUICooldownManager.lua
--  CDM Look Customization and Cooldown Display para KullThranUI
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-field, deprecated, inject-field, param-type-mismatch
local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or rawget(_G, "KT")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local issecretvalue = issecretvalue or (C_UI and C_UI.IsSecret) or function() return false end

-- Create addon core
local KUI_CDM = CreateFrame("Frame")
ns.KUI_CDM = KUI_CDM
_G.KUI_CDM = KUI_CDM
_G.KUI_CDM_NS = ns

-- Fallback para Pixel Perfect en caso de que KT no lo tenga definido nativamente
local PP = (KT and type(KT.PP) == "table" and KT.PP)
    or (type(rawget(_G, "KT")) == "table" and type(rawget(_G, "KT").PP) == "table" and rawget(_G, "KT").PP)
    or (type(rawget(_G, "PP")) == "table" and rawget(_G, "PP"))
    or {}
if KT and type(KT.PP) ~= "table" then
    KT.PP = PP
end
if type(PP.perfect) ~= "number" then
    local _, physH = GetPhysicalScreenSize()
    PP.perfect = (physH and physH > 0) and (768 / physH) or 1
end

local function GetCDMOutline() return "OUTLINE" end
local function SetCDMFont(fs, font, size)
    if not (fs and fs.SetFont) then return end
    local f = GetCDMOutline()
    if type(font) ~= "string" or font == "" then
        font = (type(_G.STANDARD_TEXT_FONT) == "string" and _G.STANDARD_TEXT_FONT ~= "")
            and _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
    size = (type(size) == "number" and size > 0) and size or 12
    local ok = pcall(fs.SetFont, fs, font, size, f)
    if not ok then
        pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, f)
    end
    if f == "" then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

-- Snap a value to the nearest physical pixel at a given bar scale
local function SnapForScale(x, barScale)
    if x == 0 then return 0 end
    local m = PP.perfect / ((UIParent:GetScale() or 1) * (barScale or 1))
    if m == 1 then return x end
    local y = m > 1 and m or -m
    return x - x % (x < 0 and y or -y)
end

local floor, abs, format            = math.floor, math.abs, string.format
local GetTime                       = GetTime
local debugprofilestart            = _G.debugprofilestart
local debugprofilestop             = _G.debugprofilestop
local InCombatLockdown              = InCombatLockdown
local GetSpecialization             = GetSpecialization

local DEFAULT_MAPPING_NAME          = "Buff Name (eg: Divine Purpose)"
local barDataByKey

-------------------------------------------------------------------------------
--  Shape Constants (shared with action bars)
-------------------------------------------------------------------------------
local CDM_SHAPE_MEDIA               = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local CDM_SHAPES = {}
CDM_SHAPES.masks = {
    circle   = CDM_SHAPE_MEDIA .. "circle_mask.tga",
    csquare  = CDM_SHAPE_MEDIA .. "csquare_mask.tga",
    diamond  = CDM_SHAPE_MEDIA .. "diamond_mask.tga",
    hexagon  = CDM_SHAPE_MEDIA .. "hexagon_mask.tga",
    portrait = CDM_SHAPE_MEDIA .. "portrait_mask.tga",
    shield   = CDM_SHAPE_MEDIA .. "shield_mask.tga",
    square   = CDM_SHAPE_MEDIA .. "square_mask.tga",
}
CDM_SHAPES.borders = {
    circle   = CDM_SHAPE_MEDIA .. "circle_border.tga",
    csquare  = CDM_SHAPE_MEDIA .. "csquare_border.tga",
    diamond  = CDM_SHAPE_MEDIA .. "diamond_border.tga",
    hexagon  = CDM_SHAPE_MEDIA .. "hexagon_border.tga",
    portrait = CDM_SHAPE_MEDIA .. "portrait_border.tga",
    shield   = CDM_SHAPE_MEDIA .. "shield_border.tga",
    square   = CDM_SHAPE_MEDIA .. "square_border.tga",
}
ns.CDM_SHAPE_INSETS                 = {
    circle = 17,
    csquare = 17,
    diamond = 14,
    hexagon = 17,
    portrait = 17,
    shield = 13,
    square = 17,
}
ns.CDM_SHAPE_ICON_EXPAND            = 7
ns.CDM_SHAPE_ICON_EXPAND_OFFSETS    = {
    circle = 2,
    csquare = 4,
    diamond = 2,
    hexagon = 4,
    portrait = 2,
    shield = 2,
    square = 4,
}
CDM_SHAPES.zoomDefaults = {
    none = 0.08,
    cropped = 0.02,
    square = 0.06,
    circle = 0.06,
    csquare = 0.06,
    diamond = 0.06,
    hexagon = 0.06,
    portrait = 0.06,
    shield = 0.06,
}

ns.CDM_NATIVE_SQUARE_DECOR = {
    'NormalTexture', 'NormalTexture2', 'PushedTexture', 'HighlightTexture',
    'IconBorder', 'Border', 'DebuffBorder', 'IconOverlay', 'IconOverlay2',
    'Shadow', 'SlotBackground', 'Background',
}

function ns.SetCDMNativeSquareDecorShown(frame, shown)
    if not frame then return end
    for _, key in ipairs(ns.CDM_NATIVE_SQUARE_DECOR) do
        local region = frame[key]
        if region and region ~= frame._tex and region.Show and region.Hide then
            if shown then region:Show() else region:Hide() end
        end
    end

    if not frame._kuiNativeSquareRegions and frame.GetNumRegions and frame.GetRegions then
        frame._kuiNativeSquareRegions = {}
        for index = 1, frame:GetNumRegions() do
            local region = select(index, frame:GetRegions())
            if region and region ~= frame._tex and region ~= frame._bg
                and region.GetObjectType and region:GetObjectType() == 'Texture'
                and region.GetDrawLayer then
                local layer = region:GetDrawLayer()
                if layer == 'BACKGROUND' or layer == 'BORDER' or layer == 'OVERLAY' then
                    frame._kuiNativeSquareRegions[#frame._kuiNativeSquareRegions + 1] = region
                end
            end
        end
    end
    for _, region in ipairs(frame._kuiNativeSquareRegions or {}) do
        if shown then region:Show() else region:Hide() end
    end
end
ns.CDM_SHAPE_EDGE_SCALES            = {
    circle = 0.75,
    csquare = 0.75,
    diamond = 0.70,
    hexagon = 0.65,
    portrait = 0.70,
    shield = 0.65,
    square = 0.75,
}
ns.CDM_SHAPE_MASKS                  = CDM_SHAPES.masks
ns.CDM_SHAPE_BORDERS                = CDM_SHAPES.borders
ns.CDM_SHAPE_ZOOM_DEFAULTS          = CDM_SHAPES.zoomDefaults

-------------------------------------------------------------------------------
--  Desaturation Curve for DurationObject evaluation
-------------------------------------------------------------------------------
local KUI_DESAT_CURVE               = C_CurveUtil.CreateCurve()
KUI_DESAT_CURVE:SetType(Enum.LuaCurveType.Step)
KUI_DESAT_CURVE:AddPoint(0, 0)
KUI_DESAT_CURVE:AddPoint(0.001, 1)

-- Forward declarations for glow helpers (defined later, used by consolidated helpers)
local StartNativeGlow, StopNativeGlow

local _gcdCheckSid
local function _CheckIsGCD()
    local cdData = C_Spell.GetSpellCooldown(_gcdCheckSid)
    return cdData and cdData.isOnGCD
end

local _multiChargeSpells     = {}
local _maxChargeCount        = {}

local _zeroStartChargeSpells = {
    [399491] = true, -- Teachings of the Monastery
    [115294] = true, -- Mana Tea
}

local function CacheMultiChargeSpell(spellID)
    if not spellID or not C_Spell.GetSpellCharges then return end
    if _multiChargeSpells[spellID] ~= nil then return end
    local charges = C_Spell.GetSpellCharges(spellID)
    if not charges or charges.maxCharges == nil then return end

    if not issecretvalue(charges.maxCharges) then
        local result = charges.maxCharges > 1
        _multiChargeSpells[spellID] = result or false
        if result then
            _maxChargeCount[spellID] = charges.maxCharges
            local db = KUI_CDM.db
            if db and db.global then
                if not db.global.multiChargeSpells then
                    db.global.multiChargeSpells = {}
                end
                db.global.multiChargeSpells[spellID] = true
            end
        end
    else
        local db = KUI_CDM.db
        if db and db.global and db.global.multiChargeSpells and db.global.multiChargeSpells[spellID] then
            _multiChargeSpells[spellID] = true
        end
    end
end

ns._multiChargeSpells    = _multiChargeSpells
ns._maxChargeCount       = _maxChargeCount
ns.CacheMultiChargeSpell = CacheMultiChargeSpell

local _castCountSpells   = {}
for sid in pairs(_zeroStartChargeSpells) do
    _castCountSpells[sid] = true
end

local playerIdentity = { race = nil, class = nil }

local function CacheCastCountSpell(spellID)
    if not spellID or not C_Spell.GetSpellCastCount then return end
    if _castCountSpells[spellID] == false then return end
    local ok, count = pcall(C_Spell.GetSpellCastCount, spellID)
    if not ok or count == nil then return end

    if not (issecretvalue and issecretvalue(count)) then
        if count > 0 then
            _castCountSpells[spellID] = count
            local db = KUI_CDM.db
            if db and db.global then
                if not db.global.castCountSpells then
                    db.global.castCountSpells = {}
                end
                db.global.castCountSpells[spellID] = true
            end
        end
    elseif _castCountSpells[spellID] == nil then
        local db = KUI_CDM.db
        if db and db.global and db.global.castCountSpells and db.global.castCountSpells[spellID] then
            _castCountSpells[spellID] = true
        end
    end
end

-------------------------------------------------------------------------------
--  Per-tick caches
-------------------------------------------------------------------------------
local _tickGCDCache           = {}
local _tickChargeCache        = {}
local _tickAuraCache          = {}
local _tickUsableCache        = {}
local _tickBlizzActiveCache   = {}
local _tickBlizzOverrideCache = {}
local _tickBlizzChildCache    = {}
local _tickBlizzAllChildCache = {}
local _tickBlizzBuffChildCache = {}
local _tickTotemCache         = {}
local _cdmChildHasDurObj     = {}
local _cdmDurObjCache        = {}
local _cdmRawStartCache      = {}
local _cdmRawDurCache        = {}
local _spellToCooldownID      = {}
local _spellIconCache         = {}

ns._tickBlizzActiveCache = _tickBlizzActiveCache
ns._tickBlizzAllChildCache = _tickBlizzAllChildCache
ns._tickBlizzBuffChildCache = _tickBlizzBuffChildCache
ns._tickAuraCache = _tickAuraCache
ns._cdmChildHasDurObj = _cdmChildHasDurObj
ns._cdmDurObjCache = _cdmDurObjCache
ns._cdmRawStartCache = _cdmRawStartCache
ns._cdmRawDurCache = _cdmRawDurCache
ns._cdIDToCorrectSID = ns._cdIDToCorrectSID or {}
ns._placedUnitStartCache = ns._placedUnitStartCache or {}
ns.PLACED_UNIT_DURATIONS = ns.PLACED_UNIT_DURATIONS or {
    [26573] = 12,
    [204242] = 12,
}
ns.BUFF_SPELLID_CORRECTIONS = ns.BUFF_SPELLID_CORRECTIONS or {}

-- Event-driven state table for Execute overlay.
-- Updated by SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE events (see eventFrame handler below).
-- This avoids calling C_Spell.IsSpellOverlayed every tick, which can return stale values.
local _executeFamily = {
    [5308]   = true, -- Execute (Arms/Fury base)
    [163201] = true, -- Execute (Prot)
    [280735] = true, -- Condemn (Arms Venthyr)
    [317349] = true, -- Condemn (Prot Venthyr)
    [260798] = true,
    [384318] = true,
    [384391] = true,
    [281000] = true, -- Execute with Massacre talent
    [280772] = true,
}
local _executeOverlayActive = false  -- true when any Execute variant has an active overlay

function ns.CDMHasUsableTarget()
    if not UnitExists then return false end
    local ok, exists = pcall(UnitExists, 'target')
    if not ok or (issecretvalue and issecretvalue(exists)) then
        return false
    end
    return exists == true
end

function ns.CDMCanShowProcGlow(icon, spellID)
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost('player') then
        return false
    end
    return ns.CDMHasUsableTarget()
end

local function GetSpellUsableInfo(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil, nil
    end

    local cached = _tickUsableCache[spellID]
    if cached ~= nil then
        return cached[1], cached[2]
    end

    local usable, insufficientPower
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, u, p = pcall(C_Spell.IsSpellUsable, spellID)
        if ok then
            if issecretvalue and issecretvalue(u) then
                usable = nil
            else
                usable = u
            end
            if issecretvalue and issecretvalue(p) then
                insufficientPower = nil
            else
                insufficientPower = p
            end
        end
    end

    -- Fallback: legacy API (only flags "no mana", may not cover non-mana resources)
    if usable == nil and rawget(_G, "IsUsableSpell") then
        local ok, u, noMana = pcall(rawget(_G, "IsUsableSpell"), spellID)
        if ok then
            if issecretvalue and issecretvalue(u) then
                usable = nil
            else
                usable = u
            end
            if issecretvalue and issecretvalue(noMana) then
                insufficientPower = nil
            else
                insufficientPower = noMana
            end
        end
    end

    -- Execute family: C_Spell.IsSpellUsable already knows target HP internally.
    -- The only problem is it returns (false, false) when not usable due to target HP —
    -- insufficientPower=false means the CDM would NOT desaturate. We fix that here.
    -- When usable=true (target below 20% or Sudden Death proc), we also trigger the CDM glow.
    if _executeFamily[spellID] then
        local prevActive = _executeOverlayActive
        if ns.CDMCanShowProcGlow(nil, spellID) and usable == true then
            insufficientPower = false
            _executeOverlayActive = true
        else
            insufficientPower = true
            _executeOverlayActive = false
        end
        -- If state changed, notify the proc glow system for the CDM icon
        if prevActive ~= _executeOverlayActive and ns and ns.OnProcGlowEvent then
            local evName = _executeOverlayActive
                and "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
                or  "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE"
            ns.OnProcGlowEvent(evName, spellID)
        end
    end

    cached = { usable == true, insufficientPower == true }
    _tickUsableCache[spellID] = cached
    return cached[1], cached[2]
end

local cdmUpdateThrottle       = 0
local CDM_UPDATE_INTERVAL     = 0.12 -- ~8.3fps in combat

local function GetCooldownViewerCategories()
    local out, seen = {}, {}
    local enum = Enum and Enum.CooldownViewerCategory
    local names = {
        "Essential", "Utility", "TrackedBuff", "TrackedBar", "GroupBuff",
        "SpecAgnosticEssential", "SpecAgnosticTracked",
        "EquipSlotEssential", "EquipSlotTracked",
    }
    if enum then
        for i = 1, #names do
            local value = enum[names[i]]
            if type(value) == "number" and not seen[value] then
                seen[value] = true
                out[#out + 1] = value
            end
        end
    end
    -- 12.1 added categories while older clients may expose an incomplete enum table.
    for value = 0, 8 do
        if not seen[value] then out[#out + 1] = value end
    end
    return out
end
ns.GetCooldownViewerCategories = GetCooldownViewerCategories

local function RebuildSpellToCooldownID()
    wipe(_spellToCooldownID)
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCategorySet then return end
    for _, cat in ipairs(GetCooldownViewerCategories()) do
        local ok, ids = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, cat, true)
        ids = ok and ids or nil
        if ids then
            for _, cdID in ipairs(ids) do
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                if info then
                    if info.spellID and info.spellID > 0 then
                        _spellToCooldownID[info.spellID] = cdID
                    end
                    if info.overrideSpellID and info.overrideSpellID > 0 then
                        _spellToCooldownID[info.overrideSpellID] = cdID
                    end
                    if type(info.linkedSpellIDs) == "table" then
                        for i = 1, #info.linkedSpellIDs do
                            local linkedID = info.linkedSpellIDs[i]
                            if type(linkedID) == "number" and linkedID > 0 then
                                _spellToCooldownID[linkedID] = cdID
                            end
                        end
                    end
                end
            end
        end
    end
end

ns.ApplyBuffSpellCorrection = function(spellID)
    if type(spellID) ~= "number"
        or (issecretvalue and issecretvalue(spellID))
        or spellID <= 0 then
        return nil
    end
    return ns.BUFF_SPELLID_CORRECTIONS[spellID] or spellID
end

ns.ResolveInfoSpellID = function(info)
    if type(info) ~= "table" then
        return nil
    end
    local function IsCleanSpellID(value)
        return type(value) == "number"
            and not (issecretvalue and issecretvalue(value))
            and value > 0
    end

    local sid
    if IsCleanSpellID(info.overrideSpellID) then
        sid = info.overrideSpellID
    else
        local linked = info.linkedSpellIDs
        if type(linked) == "table" then
            for i = 1, #linked do
                local linkedID = linked[i]
                if IsCleanSpellID(linkedID) then
                    sid = linkedID
                    break
                end
            end
        end

        if not sid and IsCleanSpellID(info.spellID) then
            sid = info.spellID
        end
    end

    return ns.ApplyBuffSpellCorrection(sid)
end

ns.ResolveChildSpellID = function(child)
    if not child then
        return nil
    end

    local function IsUsableSpellID(value)
        if type(value) ~= "number" then
            return false
        end
        if issecretvalue and issecretvalue(value) then
            return false
        end
        return value > 0
    end

    if child.GetAuraSpellID then
        local ok, auraID = pcall(child.GetAuraSpellID, child)
        if ok and IsUsableSpellID(auraID) then
            return ns.ApplyBuffSpellCorrection(auraID)
        end
    end

    if child.GetSpellID then
        local ok, frameSpellID = pcall(child.GetSpellID, child)
        if ok and IsUsableSpellID(frameSpellID) then
            return ns.ApplyBuffSpellCorrection(frameSpellID)
        end
    end

    local cdID = child.cooldownID or (child.cooldownInfo and child.cooldownInfo.cooldownID)
    if cdID and ns._cdIDToCorrectSID[cdID] then
        return ns._cdIDToCorrectSID[cdID]
    end

    if cdID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
        return ns.ResolveInfoSpellID(info)
    end

    return ns.ApplyBuffSpellCorrection(child.spellID or (child.cooldownInfo and child.cooldownInfo.spellID) or nil)
end

ns.RebuildCdIDToCorrectSID = function()
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
        return
    end

    for _, viewerName in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
        local viewer = _G[viewerName]
        if viewer then
            local children = { viewer:GetChildren() }
            for i = 1, #children do
                local child = children[i]
                if child then
                    local cdID = child.cooldownID or (child.cooldownInfo and child.cooldownInfo.cooldownID)
                    if cdID then
                        local correctSid = ns.ResolveChildSpellID(child)
                        if type(correctSid) == "number" and correctSid > 0 then
                            ns._cdIDToCorrectSID[cdID] = correctSid
                        end
                    end
                end
            end
        end
    end
end

local _cdmViewerNames = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}
local function FindCDMChildByCooldownID(cooldownID)
    if not cooldownID then return nil end
    for _, vname in ipairs(_cdmViewerNames) do
        local viewer = _G[vname]
        if viewer then
            if viewer.EnumerateChildren then
                for ch in viewer:EnumerateChildren() do
                    local chID = ch.cooldownID or (ch.cooldownInfo and ch.cooldownInfo.cooldownID)
                    if chID == cooldownID then
                        return ch
                    end
                end
            else
                local _children = { viewer:GetChildren() }
                for ci, ch in ipairs(_children) do
                    if ch then
                        local chID = ch.cooldownID or (ch.cooldownInfo and ch.cooldownInfo.cooldownID)
                        if chID == cooldownID then
                            return ch
                        end
                    end
                end
            end
        end
    end
    return nil
end

local _cdmKeybindCache       = {}
local _cdmTrinketSlotKeybindCache = ns._cdmTrinketSlotKeybindCache or {}
ns._cdmTrinketSlotKeybindCache = _cdmTrinketSlotKeybindCache
ns._cdmActionSlotCache = ns._cdmActionSlotCache or {}
ns._cdmTrinketMacroDebug = ns._cdmTrinketMacroDebug or { entries = {}, rebuildCount = 0, lastUpdated = 0 }
local _keybindRebuildPending = false
local _keybindCacheReady     = false

local _inCombat              = false
_G.KUI_CDM_inCombat = _inCombat

local NormalizeItemID, EncodeItemID, DecodeItemID, GetPotionTooltipClass
local HEALTH_ITEMS
local PREPOT_ITEM_IDS

function ns.FindCachedKeybind(spellID, baseSpellID)
    local function TryIdentifier(identifier)
        if not identifier then
            return nil
        end

        local key = ns.CDMKeybindCache[identifier]
        if key then
            return key
        end

        if type(identifier) ~= "number" or identifier <= 0 then
            return nil
        end

        local name = C_Spell.GetSpellName and C_Spell.GetSpellName(identifier)
        if name and ns.CDMKeybindCache[name] then
            return ns.CDMKeybindCache[name]
        end
        if name then
            local lowerName = strlower(name)
            if lowerName ~= "" and ns.CDMKeybindCache[lowerName] then
                return ns.CDMKeybindCache[lowerName]
            end
        end

        local override = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(identifier)
        if override and override ~= identifier then
            key = ns.CDMKeybindCache[override]
            if key then
                return key
            end

            local overrideName = C_Spell.GetSpellName and C_Spell.GetSpellName(override)
            if overrideName and ns.CDMKeybindCache[overrideName] then
                return ns.CDMKeybindCache[overrideName]
            end
            if overrideName then
                local lowerOverrideName = strlower(overrideName)
                if lowerOverrideName ~= "" and ns.CDMKeybindCache[lowerOverrideName] then
                    return ns.CDMKeybindCache[lowerOverrideName]
                end
            end
        end

        return nil
    end

    return TryIdentifier(spellID) or TryIdentifier(baseSpellID)
end

function ns.FindCachedActionSlot(spellID, baseSpellID)
    local function TryIdentifier(identifier)
        if not identifier then
            return nil
        end

        local slot = ns._cdmActionSlotCache[identifier]
        if slot then
            return slot
        end

        if type(identifier) ~= "number" or identifier <= 0 then
            return nil
        end

        local name = C_Spell.GetSpellName and C_Spell.GetSpellName(identifier)
        if name and ns._cdmActionSlotCache[name] then
            return ns._cdmActionSlotCache[name]
        end
        if name then
            local lowerName = strlower(name)
            if lowerName ~= "" and ns._cdmActionSlotCache[lowerName] then
                return ns._cdmActionSlotCache[lowerName]
            end
        end

        local override = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(identifier)
        if override and override ~= identifier then
            slot = ns._cdmActionSlotCache[override]
            if slot then
                return slot
            end

            local overrideName = C_Spell.GetSpellName and C_Spell.GetSpellName(override)
            if overrideName and ns._cdmActionSlotCache[overrideName] then
                return ns._cdmActionSlotCache[overrideName]
            end
            if overrideName then
                local lowerOverrideName = strlower(overrideName)
                if lowerOverrideName ~= "" and ns._cdmActionSlotCache[lowerOverrideName] then
                    return ns._cdmActionSlotCache[lowerOverrideName]
                end
            end
        end

        return nil
    end

    return TryIdentifier(spellID) or TryIdentifier(baseSpellID)
end

function ns.FindCachedActionSlotForItem(itemID)
    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    if not normalizedItemID then
        return nil
    end

    local encodedItemID = EncodeItemID and ns.EncodeItemID(normalizedItemID)
    local slot = encodedItemID and ns.FindCachedActionSlot(encodedItemID)
    if slot then
        return slot
    end

    if C_Item and C_Item.GetItemSpell then
        local _, itemSpellID = C_Item.GetItemSpell(normalizedItemID)
        if itemSpellID then
            slot = ns.FindCachedActionSlot(itemSpellID)
            if slot then
                return slot
            end
        end
    end

    return nil
end

function ns.FindCachedKeybindForIcon(icon)
    if not icon then
        return nil
    end

    if icon._spellID or icon._baseSpellID then
        local key = ns.FindCachedKeybind(icon._spellID, icon._baseSpellID)
        if key then
            return key
        end
    end

    if icon._itemID then
        local encodedItemID = ns.EncodeItemID(icon._itemID)
        local key = encodedItemID and ns.FindCachedKeybind(encodedItemID)
        if key then
            return key
        end

        if C_Item and C_Item.GetItemSpell then
            local _, itemSpellID = C_Item.GetItemSpell(icon._itemID)
            if itemSpellID then
                key = ns.FindCachedKeybind(itemSpellID)
                if key then
                    return key
                end
            end
        end
    end

    if icon._trinketSlot and ns._cdmTrinketSlotKeybindCache[icon._trinketSlot] then
        return ns._cdmTrinketSlotKeybindCache[icon._trinketSlot]
    end

    return nil
end
function ns.GetCandidateSlotsForBindingCommand(commandName, fallbackSlot)
    if type(commandName) ~= "string" or commandName == "" then
        return fallbackSlot and { fallbackSlot } or nil
    end

    local actionIndex = tonumber(commandName:match("^ACTIONBUTTON(%d+)$"))
    if actionIndex then
        local slots = {}
        local seen = {}
        local offsets = { 0, 12, 24, 36, 48, 60, 72, 84, 96, 108, 120, 132, 144, 156, 168 }
        for _, offset in ipairs(offsets) do
            local slot = actionIndex + offset
            if slot >= 1 and slot <= 180 and not seen[slot] then
                slots[#slots + 1] = slot
                seen[slot] = true
            end
        end
        return slots
    end

    local staticMappings = {
        { pattern = "^MULTIACTIONBAR1BUTTON(%d+)$", startSlot = 61 },
        { pattern = "^MULTIACTIONBAR2BUTTON(%d+)$", startSlot = 49 },
        { pattern = "^MULTIACTIONBAR3BUTTON(%d+)$", startSlot = 25 },
        { pattern = "^MULTIACTIONBAR4BUTTON(%d+)$", startSlot = 37 },
        { pattern = "^MULTIACTIONBAR5BUTTON(%d+)$", startSlot = 145 },
        { pattern = "^MULTIACTIONBAR6BUTTON(%d+)$", startSlot = 157 },
        { pattern = "^MULTIACTIONBAR7BUTTON(%d+)$", startSlot = 169 },
    }

    for _, mapping in ipairs(staticMappings) do
        local index = tonumber(commandName:match(mapping.pattern))
        if index and index >= 1 and index <= 12 then
            return { mapping.startSlot + index - 1 }
        end
    end

    return fallbackSlot and { fallbackSlot } or nil
end

function ns.GetBindingCommandForButton(button)
    if not button or not button.GetName then
        return nil
    end

    local name = button:GetName()
    if type(name) ~= "string" or name == "" then
        return nil
    end

    local mappings = {
        { "^ActionButton(%d+)$", "ACTIONBUTTON%s" },
        { "^MultiBarBottomLeftButton(%d+)$", "MULTIACTIONBAR1BUTTON%s" },
        { "^MultiBarBottomRightButton(%d+)$", "MULTIACTIONBAR2BUTTON%s" },
        { "^MultiBarRightButton(%d+)$", "MULTIACTIONBAR3BUTTON%s" },
        { "^MultiBarLeftButton(%d+)$", "MULTIACTIONBAR4BUTTON%s" },
        { "^MultiBar5Button(%d+)$", "MULTIACTIONBAR5BUTTON%s" },
        { "^MultiBar6Button(%d+)$", "MULTIACTIONBAR6BUTTON%s" },
        { "^MultiBar7Button(%d+)$", "MULTIACTIONBAR7BUTTON%s" },
    }

    for _, mapping in ipairs(mappings) do
        local index = name:match(mapping[1])
        if index then
            return format(mapping[2], index)
        end
    end

    return nil
end

function ns.GetClickBindingForButton(button)
    if not button or not button.GetName or not GetNumBindings or not GetBinding then
        return nil, nil
    end

    local name = button:GetName()
    if type(name) ~= "string" or name == "" then
        return nil, nil
    end

    for bindingIndex = 1, GetNumBindings() do
        local command, key1, key2 = GetBinding(bindingIndex)
        if type(command) == "string" and command:find("^CLICK ") then
            local candidateName = command:match("^CLICK%s+(.+)$")
            while candidateName and candidateName ~= "" do
                if candidateName == name then
                    return command, key1 or key2
                end
                candidateName = candidateName:match("^(.*):[^:]+$")
            end
        end
    end

    return nil, nil
end

-------------------------------------------------------------------------------
--  Consolidated cooldown/desat/charge-text helper
-------------------------------------------------------------------------------
local function ApplySpellCooldown(icon, spellID, desatOnCD, showCharges, swAlpha, skipCD, insufficientPower, hideGCDSwipe, blizzChild, isBuffBar)
    CacheMultiChargeSpell(spellID)

    local isChargeSpell = _multiChargeSpells[spellID] == true
    local ccd = isChargeSpell and C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(spellID)
    local scd = C_Spell.GetSpellCooldownDuration(spellID)

    local isGCD = _tickGCDCache[spellID]
    if isGCD == nil then
        _gcdCheckSid = spellID
        local okG, gcdVal = pcall(_CheckIsGCD)
        isGCD = okG and gcdVal or false
        _tickGCDCache[spellID] = isGCD
    end

    local isOnCooldown = false
    local isRecharging = false
    local hideGCD = (hideGCDSwipe == true) and isGCD

    local function TryApplyHookedBlizzCooldown()
        if not blizzChild or not icon or not icon._cooldown then
            return false
        end

        local durObj = _cdmDurObjCache and _cdmDurObjCache[blizzChild]
        
        -- 12.1 compat: If not cached, fetch directly from API using auraInstanceID
        if not durObj and blizzChild.auraInstanceID and (blizzChild.auraDataUnit or "player") and C_UnitAuras and C_UnitAuras.GetAuraDuration then
            local ok, fetched = pcall(C_UnitAuras.GetAuraDuration, blizzChild.auraDataUnit or "player", blizzChild.auraInstanceID)
            if ok and fetched then
                durObj = fetched
            end
        end

        if durObj then
            icon._cooldown:Clear()
            local ok = pcall(icon._cooldown.SetCooldownFromDurationObject, icon._cooldown, durObj, true)
            if not ok then
                ok = pcall(icon._cooldown.SetCooldownFromDurationObject, icon._cooldown, durObj)
            end
            if ok then
                icon._cooldown:SetDrawSwipe(true)
                icon._cooldown:SetDrawEdge(false)
                return true
            end
        end

        local rawStart = _cdmRawStartCache and _cdmRawStartCache[blizzChild]
        local rawDur = _cdmRawDurCache and _cdmRawDurCache[blizzChild]
        if rawStart and rawDur and not (issecretvalue and (issecretvalue(rawStart) or issecretvalue(rawDur))) then
            local ok = pcall(icon._cooldown.SetCooldown, icon._cooldown, rawStart, rawDur)
            if ok then
                icon._cooldown:SetDrawSwipe(true)
                icon._cooldown:SetDrawEdge(false)
                return true
            end
        end

        return false
    end

    if isChargeSpell then
        if not icon._scdShadow then
            local s = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
            s:SetAllPoints(icon)
            s:SetDrawSwipe(false)
            s:SetDrawEdge(false)
            s:SetDrawBling(false)
            s:SetHideCountdownNumbers(true)
            s:SetAlpha(0)
            icon._scdShadow = s
        end
        if not icon._ccdShadow then
            local s = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
            s:SetAllPoints(icon)
            s:SetDrawSwipe(false)
            s:SetDrawEdge(false)
            s:SetDrawBling(false)
            s:SetHideCountdownNumbers(true)
            s:SetAlpha(0)
            icon._ccdShadow = s
        end

        if isGCD then
            icon._scdShadow:SetCooldown(0, 0)
        else
            icon._scdShadow:Clear()
            if scd then
                icon._scdShadow:SetCooldownFromDurationObject(scd, true)
            else
                icon._scdShadow:SetCooldown(0, 0)
            end
        end

        icon._ccdShadow:Clear()
        if ccd then
            icon._ccdShadow:SetCooldownFromDurationObject(ccd, true)
        else
            icon._ccdShadow:SetCooldown(0, 0)
        end

        isOnCooldown = icon._scdShadow:IsShown()
        if not isOnCooldown then
            isRecharging = icon._ccdShadow:IsShown()
        end
    end

    if not skipCD then
        if isChargeSpell then
            if ccd then
                icon._cooldown:SetCooldownFromDurationObject(ccd, true)
                icon._cooldown:SetDrawSwipe(true)
            elseif scd and not hideGCD then
                icon._cooldown:SetCooldownFromDurationObject(scd, true)
                icon._cooldown:SetDrawSwipe(true)
            elseif TryApplyHookedBlizzCooldown() then
                -- Blizzard's viewer started the cooldown before C_Spell reflected it.
            else
                icon._cooldown:Clear()
            end
            icon._cooldown:SetDrawEdge(false)
        else
            if scd and not hideGCD then
                icon._cooldown:SetCooldownFromDurationObject(scd, true)
                icon._cooldown:SetDrawSwipe(true)
            elseif TryApplyHookedBlizzCooldown() then
                -- Use the live Blizzard CDM cooldown as an immediate fallback to avoid swipe delay.
            else
                icon._cooldown:Clear()
            end
        end
    end

    -- Cooldown desaturation + "insufficient power" (spender) state.
    -- We keep cooldown desat gradient (SetDesaturation) but also force full desat
    -- when the spell can't be used due to missing resource.
    local cdDesatVal = 0
    if desatOnCD and not skipCD then
        local shouldDesat = false
        if isChargeSpell then
            shouldDesat = isOnCooldown and icon._cooldown:IsShown()
        else
            shouldDesat = not isGCD and icon._cooldown:IsShown()
        end

        if shouldDesat and scd and scd.EvaluateRemainingDuration then
            -- Duration curves may return a secret number in combat. It is safe
            -- to pass that value to the texture API, but never to compare or
            -- combine it with regular Lua numbers.
            local ok, evaluated = pcall(scd.EvaluateRemainingDuration, scd, KUI_DESAT_CURVE, 0)
            if ok and evaluated ~= nil then
                if issecretvalue and issecretvalue(evaluated) then
                    cdDesatVal = evaluated
                elseif type(evaluated) == "number" then
                    cdDesatVal = evaluated
                end
            end
        end
    end

    local powerDesatVal = (insufficientPower == true) and 1 or 0
    local desatIsSecret = issecretvalue and issecretvalue(cdDesatVal)
    local finalDesatVal = cdDesatVal
    if desatIsSecret then
        -- A clean power-dim state must still win over the secret cooldown
        -- curve. Otherwise keep the secret value opaque to Lua and let the
        -- texture system consume it natively.
        if powerDesatVal > 0 then
            finalDesatVal = powerDesatVal
            desatIsSecret = false
        end
    elseif powerDesatVal > finalDesatVal then
        finalDesatVal = powerDesatVal
    end

    if desatIsSecret then
        local ok = pcall(icon._tex.SetDesaturation, icon._tex, finalDesatVal)
        if not ok then
            icon._tex:SetDesaturation(1)
        end
        icon._ktDesatVal = nil
        icon._ktDesatSecret = true
        icon._lastDesat = true
    else
        local prevDesatVal = icon._ktDesatVal or 0
        if icon._ktDesatSecret or finalDesatVal ~= prevDesatVal then
            icon._tex:SetDesaturation(finalDesatVal)
            icon._ktDesatVal = finalDesatVal
        end
        icon._ktDesatSecret = nil
        icon._lastDesat = finalDesatVal > 0
    end

    local wantsDim = (insufficientPower == true)
    if icon._ktPowerDim ~= wantsDim then
        icon._ktPowerDim = wantsDim
        if wantsDim then
            icon._tex:SetVertexColor(0.4, 0.4, 0.4, 1)
        else
            icon._tex:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- Buff viewers already render their applications count through Blizzard.
    -- Never add any KUI-owned numeric counter to those icons.
    if isBuffBar then
        icon._chargeText:Hide()
    elseif showCharges then
        local useChargePath = isChargeSpell and not _zeroStartChargeSpells[spellID]
        if useChargePath then
            local charges = _tickChargeCache[spellID]
            if charges == nil then
                charges = C_Spell.GetSpellCharges(spellID) or false
                _tickChargeCache[spellID] = charges
            end
            if charges and charges.currentCharges ~= nil then
                icon._chargeText:SetText(charges.currentCharges)
                icon._chargeText:Show()
            else
                icon._chargeText:Hide()
            end
        else
            -- Aura applications/stacks are rendered by Blizzard's CDM child.
            -- KUI only owns real spell charges/cast counts; mirroring aura counts
            -- here produces a second number on buff icons.
            if C_Spell.GetSpellCastCount then
                CacheCastCountSpell(spellID)
                if _castCountSpells[spellID] then
                    local ok, count = pcall(C_Spell.GetSpellCastCount, spellID)
                    if ok and count then
                        if issecretvalue and issecretvalue(count) then
                            icon._chargeText:SetText(count)
                            icon._chargeText:Show()
                        elseif count > 0 then
                            icon._chargeText:SetText(count)
                            icon._chargeText:Show()
                        else
                            icon._chargeText:Hide()
                        end
                    else
                        icon._chargeText:Hide()
                    end
                else
                    icon._chargeText:Hide()
                end
            else
                icon._chargeText:Hide()
            end
        end
    else
        icon._chargeText:Hide()
    end

    return scd
end

local function ApplyTrinketCooldown(icon, slot, desatOnCD)
    icon._blizzChild = nil

    if icon._ktPowerDim then
        icon._ktPowerDim = false
        icon._tex:SetVertexColor(1, 1, 1, 1)
    end

    local ok, start, dur, enable = pcall(GetInventoryItemCooldown, "player", slot)
    if not ok then
        start, dur, enable = nil, nil, nil
    end

    local isSecretCooldown = issecretvalue
        and (issecretvalue(start) or issecretvalue(dur))
    local isReadableCooldown = type(start) == "number"
        and type(dur) == "number"
        and not (issecretvalue and (issecretvalue(start) or issecretvalue(dur)
            or issecretvalue(enable)))
        and dur > 1.5
        and enable == 1

    if isReadableCooldown then
        icon._cooldown:SetCooldown(start, dur)
        if desatOnCD then
            icon._tex:SetDesaturation(1)
            icon._ktDesatVal = 1
            icon._lastDesat = true
        elseif icon._lastDesat then
            icon._tex:SetDesaturation(0)
            icon._ktDesatVal = 0
            icon._lastDesat = false
        end
    elseif isSecretCooldown then
        -- Secret start/duration values must stay inside Blizzard-owned cooldown widgets.
        if icon._cooldown.Clear then
            icon._cooldown:Clear()
        end
        local applied = false
        if applied and desatOnCD then
            icon._tex:SetDesaturation(1)
            icon._ktDesatVal = 1
            icon._lastDesat = true
        end
    else
        icon._cooldown:Clear()
        if icon._lastDesat then
            icon._tex:SetDesaturation(0)
            icon._ktDesatVal = 0
            icon._lastDesat = false
        end
    end
    icon._chargeText:Hide()
end

ns._itemSpellIDCache = ns._itemSpellIDCache or {}
ns._syntheticSpellToItemCache = ns._syntheticSpellToItemCache or {}
local _syntheticSpellToItemCache = ns._syntheticSpellToItemCache
local _syntheticSpellCacheReady = false
local _syntheticItemCooldownGroups = {}
local _syntheticTrackedItemCounts = nil
local _pendingPotionTrackerSecureRefresh = false

function ns.CDMApplyMouseStateSafely(frame, mouseEnabled, mouseMotionEnabled)
    if not frame then
        return false
    end

    mouseEnabled = mouseEnabled and true or false
    if mouseMotionEnabled == nil then
        mouseMotionEnabled = mouseEnabled
    else
        mouseMotionEnabled = mouseMotionEnabled and true or false
    end

    if InCombatLockdown and InCombatLockdown() then
        if (frame.IsProtected and frame:IsProtected())
            or (frame._icon and frame._icon.IsProtected and frame._icon:IsProtected())
        then
            _pendingPotionTrackerSecureRefresh = true
            return false
        end
    end

    frame:EnableMouse(mouseEnabled)
    if frame.EnableMouseMotion then
        frame:EnableMouseMotion(mouseMotionEnabled)
    end

    return true
end

local function GetFallbackItemCooldownDuration(itemID)
    local healthMeta = ns.CDMHealthItemsByID and ns.CDMHealthItemsByID[itemID]
    if healthMeta then
        return healthMeta.cooldown or ((itemID == 5512 or itemID == 224464) and 60 or 300)
    end
    if PREPOT_ITEM_IDS and PREPOT_ITEM_IDS[itemID] then
        return 300
    end
    if GetPotionTooltipClass then
        local potionClass = GetPotionTooltipClass(itemID)
        if potionClass == "health" or potionClass == "mana" or potionClass == "combat" then
            return 300
        end
    end
    return nil
end

local function GetSyntheticItemCooldownGroup(itemID)
    local duration = GetFallbackItemCooldownDuration(itemID)
    if duration == 60 then
        return "healthstone"
    elseif duration == 300 then
        return "potion"
    end
    return nil
end

local function ItemMatchesSyntheticGroup(itemID, group)
    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    if not normalizedItemID or not group then
        return false
    end
    return GetSyntheticItemCooldownGroup(normalizedItemID) == group
end

local function GetTrackerOwnedItemCount(candidateItemID)
    if not candidateItemID or not GetItemCount then
        return 0
    end

    if C_Item and C_Item.GetItemCount then
        local count = C_Item.GetItemCount(candidateItemID, false, true)
        if count ~= nil then
            return count or 0
        end
    end

    local count = GetItemCount(candidateItemID, false, true)
    if count ~= nil then
        return count or 0
    end

    return GetItemCount(candidateItemID, false, false) or 0
end

local function GetTrackedItemDisplayCount(itemID)
    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    if not normalizedItemID or not GetItemCount then
        return 0
    end

    local syntheticGroup = GetSyntheticItemCooldownGroup(normalizedItemID)
    if syntheticGroup ~= "healthstone" or not HEALTH_ITEMS then
        return GetTrackerOwnedItemCount(normalizedItemID)
    end

    local bagTotal = 0
    local seenItemIDs = {}

    if C_Container and C_Container.GetContainerNumSlots then
        for _, item in ipairs(HEALTH_ITEMS) do
            local candidateItemID = item and item.itemID
            candidateItemID = NormalizeItemID and ns.NormalizeItemID(candidateItemID) or candidateItemID
            if candidateItemID and ItemMatchesSyntheticGroup(candidateItemID, syntheticGroup) then
                seenItemIDs[candidateItemID] = true
            end
        end

        local function AccumulateBag(bagID)
            local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bagID, slot)
                local candidateItemID = info and info.itemID or C_Container.GetContainerItemID(bagID, slot)
                candidateItemID = NormalizeItemID and ns.NormalizeItemID(candidateItemID) or candidateItemID
                if candidateItemID and seenItemIDs[candidateItemID] then
                    local count = info and (info.stackCount or rawget(info, "quantity") or rawget(info, "charges")) or 1
                    bagTotal = bagTotal + (tonumber(count) or 1)
                end
            end
        end

        local maxBag = NUM_BAG_SLOTS or 4
        for bagID = 0, maxBag do
            AccumulateBag(bagID)
        end
        if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
            AccumulateBag(Enum.BagIndex.ReagentBag)
        end
    end

    local total = 0
    local seen = {}

    for _, item in ipairs(HEALTH_ITEMS) do
        local candidateItemID = item and item.itemID
        candidateItemID = NormalizeItemID and ns.NormalizeItemID(candidateItemID) or candidateItemID
        if candidateItemID and ItemMatchesSyntheticGroup(candidateItemID, syntheticGroup) and not seen[candidateItemID] then
            seen[candidateItemID] = true
            total = total + GetTrackerOwnedItemCount(candidateItemID)
        end
    end

    if bagTotal > 0 then
        if total > 0 then
            return math.max(bagTotal, total)
        end
        return bagTotal
    end

    if total > 0 then
        return total
    end

    return GetTrackerOwnedItemCount(normalizedItemID)
end

ns.CDMGetActiveSyntheticItemCooldownState = function(group)
    if not group then
        return nil
    end

    local state = _syntheticItemCooldownGroups[group]
    if not state then
        return nil
    end

    local now = GetTime()
    if not state.startTime or not state.duration or (state.startTime + state.duration) <= now then
        _syntheticItemCooldownGroups[group] = nil
        return nil
    end

    return state
end

local function GetActiveSyntheticItemCooldown(itemID)
    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    local group = normalizedItemID and GetSyntheticItemCooldownGroup(normalizedItemID) or nil
    if not group or not normalizedItemID then
        return nil
    end

    local state = ns.CDMGetActiveSyntheticItemCooldownState and ns.CDMGetActiveSyntheticItemCooldownState(group)
    if not state then
        return nil
    end

    if state.itemID and state.itemID ~= normalizedItemID then
        return nil
    end

    return state.startTime, state.duration
end

local function StartSyntheticItemCooldown(itemID, duration, startTime)
    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    local group = GetSyntheticItemCooldownGroup(normalizedItemID)
    if not group or not duration or duration <= 1.5 then
        return false
    end

    -- All potion ranks share one cooldown group, but the icon must keep the
    -- exact rank that was consumed. A later spellcast/cooldown event may resolve
    -- the shared spell to another rank; never replace an active rank-2 state
    -- with the rank-3 item that merely happens to be present in the bags.
    local current = _syntheticItemCooldownGroups[group]
    if current and current.startTime and current.duration
        and (current.startTime + current.duration) > GetTime()
        and current.itemID and current.itemID ~= normalizedItemID
    then
        return false
    end

    _syntheticItemCooldownGroups[group] = {
        startTime = startTime or GetTime(),
        duration = duration,
        itemID = normalizedItemID,
    }
    return true
end

ns.TriggerImmediateSyntheticItemCooldown = function(itemID)
    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    if not normalizedItemID then
        return false
    end

    -- A PostClick/UseAction hook can run before Blizzard's cooldown event.
    -- Do not restart an already active synthetic cooldown when the player clicks
    -- an item that is still recharging.
    local group = GetSyntheticItemCooldownGroup(normalizedItemID)
    if group and ns.CDMGetActiveSyntheticItemCooldownState
        and ns.CDMGetActiveSyntheticItemCooldownState(group)
    then
        return false
    end

    local duration = GetFallbackItemCooldownDuration(normalizedItemID)
    if not duration or duration <= 1.5 then
        return false
    end

    return StartSyntheticItemCooldown(normalizedItemID, duration)
end

local function RefreshSyntheticItemCooldownsFromBags()
    if not (C_Container and C_Container.GetContainerNumSlots) then
        return false
    end

    local currentCounts = {}
    local triggered = false
    wipe(_syntheticSpellToItemCache)

    local function TrackBag(bag)
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and info.itemID or C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local duration = GetFallbackItemCooldownDuration(itemID)
                if duration and duration > 1.5 then
                    local count = info and (info.stackCount or rawget(info, "quantity") or rawget(info, "charges")) or 1
                    currentCounts[itemID] = (currentCounts[itemID] or 0) + (tonumber(count) or 1)
                    local itemSpellID = ns.CDMResolveItemSpellID and ns.CDMResolveItemSpellID(itemID)
                    if itemSpellID then
                        _syntheticSpellToItemCache[itemSpellID] = itemID
                    end
                end
            end
        end
    end

    local maxBag = NUM_BAG_SLOTS or 4
    for bag = 0, maxBag do
        TrackBag(bag)
    end
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        TrackBag(Enum.BagIndex.ReagentBag)
    end

    _syntheticTrackedItemCounts = currentCounts
    _syntheticSpellCacheReady = true
    return triggered
end
ns.RefreshSyntheticItemCooldownsFromBags = RefreshSyntheticItemCooldownsFromBags

ns.ResetSyntheticItemCooldownObservation = function()
    wipe(_syntheticItemCooldownGroups)
    wipe(_syntheticSpellToItemCache)
    _syntheticSpellCacheReady = false
    _syntheticTrackedItemCounts = nil
end

ns.ResolveSyntheticItemIDFromSpellID = function(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end

    local cachedItemID = _syntheticSpellToItemCache[spellID]
    if cachedItemID then
        return cachedItemID
    end
    -- Once the owned-item index has been built, absence is authoritative:
    -- ordinary player spells must not rescan every bag on every successful cast.
    if _syntheticSpellCacheReady then
        return nil
    end

    local function TryItem(itemID)
        if not itemID then return nil end
        local itemSpellID = ns.CDMResolveItemSpellID and ns.CDMResolveItemSpellID(itemID)
        if itemSpellID and itemSpellID == spellID then
            _syntheticSpellToItemCache[spellID] = itemID
            return itemID
        end
        return nil
    end

    if HEALTH_ITEMS then
        for _, item in ipairs(HEALTH_ITEMS) do
            local matchedItemID = TryItem(item.itemID)
            if matchedItemID then
                return matchedItemID
            end
        end
    end

    if PREPOT_ITEM_IDS then
        for itemID in pairs(PREPOT_ITEM_IDS) do
            local matchedItemID = TryItem(itemID)
            if matchedItemID then
                return matchedItemID
            end
        end
    end

    if C_Container and C_Container.GetContainerNumSlots then
        local maxBag = NUM_BAG_SLOTS or 4
        for bag = 0, maxBag do
            local numSlots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local itemID = info and info.itemID or C_Container.GetContainerItemID(bag, slot)
                local matchedItemID = TryItem(itemID)
                if matchedItemID then
                    return matchedItemID
                end
            end
        end
        if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
            local bag = Enum.BagIndex.ReagentBag
            local numSlots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local itemID = info and info.itemID or C_Container.GetContainerItemID(bag, slot)
                local matchedItemID = TryItem(itemID)
                if matchedItemID then
                    return matchedItemID
                end
            end
        end
    end

    return nil
end

local function HandleSyntheticItemCooldownSpellcast(spellID)
    local itemID = ns.ResolveSyntheticItemIDFromSpellID and ns.ResolveSyntheticItemIDFromSpellID(spellID)
    if not itemID then
        return false
    end
    local duration = GetFallbackItemCooldownDuration(itemID)
    return StartSyntheticItemCooldown(itemID, duration)
end

ns.CDMResolveItemSpellID = function(itemID)
    itemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    if not itemID then
        return nil
    end
    if ns._itemSpellIDCache[itemID] ~= nil then
        return ns._itemSpellIDCache[itemID] or nil
    end

    local spellID
    if C_Item and C_Item.GetItemSpell then
        local ok, _, sid = pcall(C_Item.GetItemSpell, itemID)
        if ok and type(sid) == "number" and sid > 0 then
            spellID = sid
        end
    end

    if not spellID and HEALTH_ITEMS then
        for _, item in ipairs(HEALTH_ITEMS) do
            if item.itemID == itemID and type(item.spellID) == "number" and item.spellID > 0 then
                spellID = item.spellID
                break
            end
        end
    end

    ns._itemSpellIDCache[itemID] = spellID or false
    return spellID
end

ns.CDMResolveItemCooldownInfo = function(itemID)
    local function SafeCooldownNumber(value, fallback)
        if value == nil then
            return fallback
        end
        if not (issecretvalue and issecretvalue(value)) then
            if type(value) == "number" then
                return value
            end
            local n = tonumber(value)
            if n ~= nil then
                return n
            end
            return fallback
        end

        local ok, s = pcall(tostring, value)
        if ok and type(s) == "string" then
            local n = tonumber(s)
            if n ~= nil then
                return n
            end
        end
        return fallback
    end

    local function SafeCooldownEnabled(value, startValue, durationValue)
        if value == nil then
            local startNum = SafeCooldownNumber(startValue, 0)
            local durationNum = SafeCooldownNumber(durationValue, 0)
            return startNum > 0 and durationNum > 0
        end
        if issecretvalue and issecretvalue(value) then
            return true
        end
        return value == 1 or value == true
    end

    local start, dur, enable
    if C_Item and C_Item.GetItemCooldown then
        local rawCooldown, rawDuration, rawEnable = C_Item.GetItemCooldown(itemID)
        if type(rawCooldown) == "table" then
            start = rawCooldown.startTime or rawCooldown.start or rawCooldown.cooldownStartTime
            dur = rawCooldown.duration or rawCooldown.cooldownDuration
            enable = rawCooldown.isEnabled
            if enable == nil then
                enable = rawCooldown.enable
            end
        else
            start, dur, enable = rawCooldown, rawDuration, rawEnable
        end
    elseif GetItemCooldown then
        start, dur, enable = GetItemCooldown(itemID)
    end
    start = SafeCooldownNumber(start, 0)
    dur = SafeCooldownNumber(dur, 0)
    enable = SafeCooldownEnabled(enable, start, dur)

    if start > 0 and dur > 0.001 then
        return start, dur, 1
    end

    local spellID = ns.CDMResolveItemSpellID and ns.CDMResolveItemSpellID(itemID)
    if spellID and C_Spell and C_Spell.GetSpellCooldown then
        local scd = C_Spell.GetSpellCooldown(spellID)
        if scd then
            local scdStart = SafeCooldownNumber(scd.startTime, 0)
            local scdDuration = SafeCooldownNumber(scd.duration, 0)
            local scdEnabled = SafeCooldownEnabled(scd.isEnabled, scdStart, scdDuration)
            local scdIsNonGCD = not (issecretvalue and issecretvalue(scd.isOnGCD))
                and scd.isOnGCD == false
            if scdStart > 0 and scdDuration > 0.001 and (scdEnabled or scdIsNonGCD) then
                return scdStart, scdDuration, 1
            end
        end
    end

    local syntheticStart, syntheticDuration = GetActiveSyntheticItemCooldown(itemID)
    if syntheticStart and syntheticDuration then
        return syntheticStart, syntheticDuration, 1
    end

    return start, dur, (start > 0 and dur > 0.001) and 1 or (enable and 1 or 0)
end

local function ApplyItemCooldown(icon, itemID, desatOnCD, showCharges, showSingleCount)
    local iconBarData = icon and icon._barKey and barDataByKey and barDataByKey[icon._barKey] or nil
    local isPotionTrackerIcon = icon and icon._barKey == "kui_potion"
    local effectiveDesatOnCD = desatOnCD or isPotionTrackerIcon
    local effectiveShowCooldownText = (iconBarData and iconBarData.showCooldownText ~= false) or false
    if isPotionTrackerIcon and (not iconBarData or iconBarData.showCooldownText ~= false) then
        effectiveShowCooldownText = true
    end

    local function ShouldRefreshCooldownFrame(cooldownFrame, hasActiveCooldown, startTime, durationTime)
        if not cooldownFrame or not cooldownFrame.GetCooldownTimes then
            return true
        end

        local oldStart, oldDuration = cooldownFrame:GetCooldownTimes()
        -- Cooldown frame times can become secret in combat. A secret old
        -- snapshot cannot be compared in Lua, so force a native refresh and
        -- let the cooldown widget consume the clean duration object below.
        if (issecretvalue and (issecretvalue(oldStart) or issecretvalue(oldDuration))) then
            return true
        end
        if type(oldStart) ~= "number" or type(oldDuration) ~= "number" then
            return true
        end

        if hasActiveCooldown then
            if oldStart <= 0 or oldDuration <= 0 then
                return true
            end

            if type(startTime) ~= "number" or type(durationTime) ~= "number"
                or (issecretvalue and (issecretvalue(startTime) or issecretvalue(durationTime))) then
                return true
            end

            local oldEnd = (oldStart + oldDuration) / 1000
            local newEnd = startTime + durationTime
            return math.abs(oldEnd - newEnd) > 0.01
        end

        return oldStart > 0 and oldDuration > 0
    end

    local function ApplyCooldownFrame(cooldownFrame, startTime, durationTime)
        if not cooldownFrame then
            return
        end

        cooldownFrame:SetDrawEdge(false)
        cooldownFrame:SetDrawSwipe(true)
        cooldownFrame:SetDrawBling(false)
        cooldownFrame:SetHideCountdownNumbers(isPotionTrackerIcon or not effectiveShowCooldownText)
        cooldownFrame:SetReverse(false)

        if cooldownFrame.SetSwipeTexture then
            cooldownFrame:SetSwipeTexture("Interface\\Buttons\\WHITE8x8")
        end

        if cooldownFrame.SetSwipeColor then
            local swipeR = (iconBarData and iconBarData.swipeR) or 0
            local swipeG = (iconBarData and iconBarData.swipeG) or 0
            local swipeB = (iconBarData and iconBarData.swipeB) or 0
            cooldownFrame:SetSwipeColor(swipeR, swipeG, swipeB, (iconBarData and iconBarData.swipeAlpha) or 0.7)
        end

        if cooldownFrame.Show then
            cooldownFrame:Show()
        end

        if cooldownFrame.SetCooldownFromDurationObject and C_DurationUtil and C_DurationUtil.CreateDuration then
            local durationObject = C_DurationUtil.CreateDuration()
            durationObject:SetTimeFromStart(startTime, durationTime)
            local ok = pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, durationObject, true)
            if ok then
                return true
            end
            ok = pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, durationObject)
            if ok then
                return true
            end
        end

        cooldownFrame:SetCooldown(startTime, durationTime)
        return true
    end

    local function ClearCooldownFrame(cooldownFrame)
        if not cooldownFrame then
            return
        end

        cooldownFrame:SetDrawEdge(false)
        cooldownFrame:SetDrawSwipe(true)
        cooldownFrame:SetDrawBling(false)
        cooldownFrame:SetHideCountdownNumbers(isPotionTrackerIcon or not effectiveShowCooldownText)
        cooldownFrame:SetReverse(false)

        if cooldownFrame.Show then
            cooldownFrame:Show()
        end

        if cooldownFrame.SetCooldownFromDurationObject and C_DurationUtil and C_DurationUtil.CreateDuration then
            local ok = pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, C_DurationUtil.CreateDuration(), true)
            if ok then
                return
            end
            ok = pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, C_DurationUtil.CreateDuration())
            if ok then
                return
            end
        end

        if cooldownFrame.Clear then
            cooldownFrame:Clear()
            return
        end

        cooldownFrame:SetCooldown(0, 0)
    end

    local function CalculateDesaturation(startTime, durationTime)
        if type(startTime) ~= "number" or type(durationTime) ~= "number" then
            return 0
        end

        if (issecretvalue and issecretvalue(startTime)) or (issecretvalue and issecretvalue(durationTime)) then
            return 0
        end

        local remaining = (startTime + durationTime) - GetTime()
        return remaining > 0.001 and 1 or 0
    end

    icon._blizzChild = nil

    if icon._ktPowerDim then
        icon._ktPowerDim = false
        icon._tex:SetVertexColor(1, 1, 1, 1)
    end

    local start, dur, enable
    local hasActiveCooldown = false

    if isPotionTrackerIcon then
        local forcedItemID = icon._forcedPotionCooldownItemID
        local forcedStart = icon._forcedPotionCooldownStart
        local forcedDuration = icon._forcedPotionCooldownDuration
        local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
        if forcedItemID and forcedItemID ~= normalizedItemID then
            icon._forcedPotionCooldownItemID = nil
            icon._forcedPotionCooldownStart = nil
            icon._forcedPotionCooldownDuration = nil
        elseif type(forcedStart) == "number" and type(forcedDuration) == "number"
            and (forcedStart + forcedDuration) > GetTime() then
            start, dur, enable = forcedStart, forcedDuration, 1
            hasActiveCooldown = true
        end
    end

    if not hasActiveCooldown then
        if ns.CDMResolveItemCooldownInfo then
            start, dur, enable = ns.CDMResolveItemCooldownInfo(itemID)
        end
        hasActiveCooldown = (type(start) == "number" and type(dur) == "number" and start > 0 and dur > 0.001 and enable == 1) or false
    end

    -- ResolveItemCooldownInfo already prefers Blizzard's real cooldown data and only
    -- falls back to the synthetic timer when the live item/spell cooldown is missing.
    -- Keep that order for the potion tracker so the displayed timer matches the real CD
    -- whenever Blizzard provides it.

    local shouldRefreshCooldown = ShouldRefreshCooldownFrame(icon._cooldown, hasActiveCooldown, start, dur)

    if hasActiveCooldown then
        if shouldRefreshCooldown then
            ApplyCooldownFrame(icon._cooldown, start, dur)
        end
        if effectiveDesatOnCD then
            local desatValue = CalculateDesaturation(start, dur)
            icon._tex:SetDesaturation(desatValue)
            icon._ktDesatVal = desatValue
            icon._lastDesat = desatValue > 0
        elseif icon._lastDesat then
            icon._tex:SetDesaturation(0)
            icon._ktDesatVal = 0
            icon._lastDesat = false
        end
    else
        if shouldRefreshCooldown then
            ClearCooldownFrame(icon._cooldown)
        end
        if icon._lastDesat then
            icon._tex:SetDesaturation(0)
            icon._ktDesatVal = 0
            icon._lastDesat = false
        end
    end

    if ns.CDMSetPotionTrackerCooldownText then
        ns.CDMSetPotionTrackerCooldownText(icon, isPotionTrackerIcon and effectiveShowCooldownText and hasActiveCooldown, start, dur)
    end

    if showCharges then
        local count = GetTrackedItemDisplayCount(itemID)
        if count and ((issecretvalue and issecretvalue(count)) or count > 1 or (showSingleCount and count > 0)) then
            icon._chargeText:SetText(count)
            icon._chargeText:Show()
        else
            icon._chargeText:Hide()
        end
    else
        icon._chargeText:Hide()
    end
end

local function UpdatePotionTrackerSecureAction(icon, itemID)
    if not icon or not icon.SetAttribute then return end

    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    if InCombatLockdown and InCombatLockdown() then
        _pendingPotionTrackerSecureRefresh = true
        return
    end

    if normalizedItemID then
        local itemToken = "item:" .. normalizedItemID
        icon:SetAttribute("type", "item")
        icon:SetAttribute("item", itemToken)
        icon:SetAttribute("type1", "item")
        icon:SetAttribute("item1", itemToken)
        icon._ktClickableItemID = normalizedItemID
    else
        icon:SetAttribute("type", nil)
        icon:SetAttribute("item", nil)
        icon:SetAttribute("type1", nil)
        icon:SetAttribute("item1", nil)
        icon._ktClickableItemID = nil
    end

    if icon._UpdateMouseForTooltip then
        icon:_UpdateMouseForTooltip()
    end
end

function ns.SetCDMIconShown(icon, shouldShow)
    if not icon then
        return
    end

    -- Potion tracker icons are SecureActionButtonTemplate buttons. Never call
    -- Show/Hide on them from addon code: a stale combat flag can still taint
    -- the call during the combat transition and produce ADDON_ACTION_BLOCKED.
    local isPotionTrackerIcon = icon._barKey == "kui_potion"
    local combatLocked = InCombatLockdown and InCombatLockdown() or false
    local inCombat = _G.KUI_CDM_inCombat
    if inCombat == nil then
        inCombat = combatLocked
    end

    if isPotionTrackerIcon then
        icon._ktCDMShouldShow = shouldShow == true
        icon:SetAlpha(shouldShow and 1 or 0)
        if inCombat or combatLocked then
            _pendingPotionTrackerSecureRefresh = true
        end
        if ns.SyncProcGlowIndexForIcon then
            ns.SyncProcGlowIndexForIcon(icon)
        end
        return
    end

    local isProtected = false
    if icon.IsProtected then
        local ok, result = pcall(icon.IsProtected, icon)
        isProtected = ok and result == true
    end
    if (inCombat or combatLocked) and isProtected then
        icon:SetAlpha(shouldShow and 1 or 0)
        if ns.SyncProcGlowIndexForIcon then
            ns.SyncProcGlowIndexForIcon(icon)
        end
        return
    end

    if shouldShow then
        icon:Show()
    else
        icon:Hide()
    end

    if ns.SyncProcGlowIndexForIcon then
        ns.SyncProcGlowIndexForIcon(icon)
    end
end

ns.RequestPotionTrackerClickRefresh = function()
    local function RefreshPotionTracker()
        if ns.ScheduleKUITrackerSync then
            ns.ScheduleKUITrackerSync(0.05)
        elseif ns.SyncKUITrackerBars then
            ns.SyncKUITrackerBars()
        end
        if ns.RequestCustomCooldownUpdate then
            ns.RequestCustomCooldownUpdate("potion_click")
        end
    end

    RefreshPotionTracker()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, RefreshPotionTracker)
    end
end

function ns.CDMResolveExplicitBarSwipeOverride(icon)
    local bg = ns.GetBarGlows and ns.GetBarGlows()
    if not bg or bg.enabled == false or not ns.GetBarGlowSpellOverride then
        return nil
    end

    local identifiers = ns.CDMGetGlowCandidateIdentifiers and ns.CDMGetGlowCandidateIdentifiers(icon)
    if not identifiers then
        return nil
    end

    for i = 1, #identifiers do
        local identifier = identifiers[i]
        local spellOverride = ns.GetBarGlowSpellOverride(identifier, false)
        if spellOverride and spellOverride.useGlobalSwipeColor ~= true and spellOverride.swipeColor then
            local c = spellOverride.swipeColor
            return c.r or 0, c.g or 0, c.b or 0, identifier
        end
    end

    return nil
end

local function GetConfiguredSwipeColor(barData, icon)
    local overrideR, overrideG, overrideB = ns.CDMResolveExplicitBarSwipeOverride(icon)
    if overrideR ~= nil and overrideG ~= nil and overrideB ~= nil then
        return overrideR, overrideG, overrideB
    end
    if not barData then
        return 0, 0, 0
    end
    return barData.swipeR or 0, barData.swipeG or 0, barData.swipeB or 0
end

local function GetActiveSwipeColor(barData, glowR, glowG, glowB, icon)
    local overrideR, overrideG, overrideB = ns.CDMResolveExplicitBarSwipeOverride(icon)
    if overrideR ~= nil and overrideG ~= nil and overrideB ~= nil then
        return overrideR, overrideG, overrideB
    end
    if barData and barData.activeSwipeUsesGlowColor == false then
        return GetConfiguredSwipeColor(barData, icon)
    end
    return glowR or 1, glowG or 0.85, glowB or 0.0
end

function ns.CDMResolveActiveAnimGlowStyle(activeAnim)
    if activeAnim == "blizzard" then return "blizzard" end
    if activeAnim == "none" or activeAnim == "hideActive" then return 0 end
    if activeAnim == "1" or activeAnim == 1 then return "pixel" end
    if activeAnim == "2" or activeAnim == 2 then return "shape" end
    if activeAnim == "3" or activeAnim == 3 then return "button" end
    if activeAnim == "4" or activeAnim == 4 then return "autocast" end
    local s = tonumber(activeAnim)
    if s == 1 then return "pixel" end
    if s == 2 then return "shape" end
    if s == 3 then return "button" end
    if s == 4 then return "autocast" end
    if s == 6 then return "blizzard" end
    return "blizzard"
end

local function ApplyActiveAnimation(icon, auraHandled, barData, barKey, activeAnim, animR, animG, animB, swAlpha)
    local skipActiveAnim = barData.hideBuffsWhenInactive and (barKey == "buffs" or barData.barType == "buffs")
    local customGlowOwnsOverlay = icon._customModuleGlowWanted == true or icon._customModuleGlowActive == true
    local defaultSwipeR, defaultSwipeG, defaultSwipeB = GetConfiguredSwipeColor(barData, icon)
    if barData.assistedCombatHighlight and not UnitAffectingCombat("player") then
        skipActiveAnim = true
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost('player') then
        skipActiveAnim = true
    end
    if not ns.CDMHasUsableTarget() then
        skipActiveAnim = true
    end
    if not skipActiveAnim and auraHandled and not icon._isActive then
        if activeAnim ~= "none" and activeAnim ~= "hideActive" then
            local glowStyle = ns.CDMResolveActiveAnimGlowStyle(activeAnim)
            local glowR, glowG, glowB = animR, animG, animB
            local overrideStyle, overrideR, overrideG, overrideB, overrideIdentifier = ns.CDMResolveExplicitBarGlowOverride(icon, true)
            if overrideStyle ~= nil then
                glowStyle = overrideStyle
                glowR = overrideR or glowR
                glowG = overrideG or glowG
                glowB = overrideB or glowB
                ns.CDMGlowDebugPrint(
                    icon,
                    "active override",
                    "bar=" .. tostring(barKey),
                    "identifier=" .. tostring(overrideIdentifier),
                    "style=" .. tostring(glowStyle),
                    string.format("rgb=%.3f/%.3f/%.3f", glowR or 1, glowG or 0.82, glowB or 0.1)
                )
            end
            local swipeR, swipeG, swipeB = GetActiveSwipeColor(barData, glowR, glowG, glowB, icon)
            icon._cooldown:SetSwipeColor(swipeR, swipeG, swipeB, swAlpha)
            if glowStyle and glowStyle ~= 0 and icon._glowOverlay and not icon._procGlowActive and not customGlowOwnsOverlay then
                icon._glowOverlay._kuiGlowSource = "active:" .. tostring(barKey)
                ns.CDMGlowDebugPrint(icon, "active start", "bar=" .. tostring(barKey), "style=" .. tostring(glowStyle), "auraHandled=" .. tostring(auraHandled))
                StartNativeGlow(icon._glowOverlay, glowStyle, glowR, glowG, glowB)
            elseif glowStyle == 0 then
                ns.CDMGlowDebugPrint(icon, "active skipped", "bar=" .. tostring(barKey), "reason=override_none")
            end
        end
    elseif (skipActiveAnim or not auraHandled) and icon._isActive then
        icon._cooldown:SetSwipeColor(defaultSwipeR, defaultSwipeG, defaultSwipeB, swAlpha)
        if icon._glowOverlay and not icon._procGlowActive and not customGlowOwnsOverlay then
            ns.CDMGlowDebugPrint(icon, "active stop", "bar=" .. tostring(barKey), "auraHandled=" .. tostring(auraHandled), "skip=" .. tostring(skipActiveAnim))
            StopNativeGlow(icon._glowOverlay)
        end
    end
    icon._isActive = not skipActiveAnim and auraHandled
end

local function IsCleanPositiveNumber(value)
    if type(value) ~= "number" then
        return false
    end
    if issecretvalue and issecretvalue(value) then
        return false
    end
    return value > 0
end

local function GetCachedTotemInfo(slot)
    local cached = _tickTotemCache[slot]
    if cached ~= nil then
        return cached
    end

    local haveTotem = GetTotemInfo(slot)
    _tickTotemCache[slot] = haveTotem
    return haveTotem
end

local function CacheChildAuraDuration(ch)
    local auraID = ch and ch.auraInstanceID
    if not (auraID and C_UnitAuras and C_UnitAuras.GetAuraDuration) then
        return false
    end

    local ok, durationObject = pcall(C_UnitAuras.GetAuraDuration, ch.auraDataUnit or 'player', auraID)
    if not (ok and durationObject) then
        return false
    end

    _cdmChildHasDurObj[ch] = true
    _cdmDurObjCache[ch] = durationObject
    return true
end

local function IsTotemChildStillValid(ch)
    if ch and ch.IsShown and not ch:IsShown() then
        return false
    end

    if CacheChildAuraDuration(ch) then
        return true
    end

    if _cdmChildHasDurObj[ch] then
        return true
    end

    local rawDur = _cdmRawDurCache[ch]
    if rawDur ~= nil then
        if issecretvalue and issecretvalue(rawDur) then
            return true
        end
        if type(rawDur) == "number" then
            return rawDur > 0
        end
    end

    return false
end

local function IsBufChildCooldownActive(ch)
    if not ch then return false end

    local totemSlot = ch.preferredTotemUpdateSlot
    if totemSlot and type(totemSlot) == "number" and totemSlot > 0 then
        local haveTotem = GetCachedTotemInfo(totemSlot)
        if issecretvalue and issecretvalue(haveTotem) then
            return IsTotemChildStillValid(ch)
        end
        if haveTotem then return IsTotemChildStillValid(ch) end
        return false
    end

    -- Before consulting hook-cached cooldown state, verify the Blizzard pool frame
    -- is still shown. Blizzard natively hides CDM pool frames when their buff/aura
    -- expires (HideWhenInactive=1). A hidden frame means our cached state is stale.
    if ch.IsShown and not ch:IsShown() then
        _cdmChildHasDurObj[ch] = nil
        _cdmDurObjCache[ch] = nil
        _cdmRawStartCache[ch] = nil
        _cdmRawDurCache[ch] = nil
        return false
    end

    if CacheChildAuraDuration(ch) then
        return true
    end

    if _cdmChildHasDurObj[ch] then
        return true
    end

    local rawDur = _cdmRawDurCache[ch]
    if rawDur ~= nil then
        if issecretvalue and issecretvalue(rawDur) then
            return true
        end
        if type(rawDur) == "number" and rawDur > 0 then
            return true
        end
    end

    return false
end
ns.IsBufChildCooldownActive = IsBufChildCooldownActive

-- BuffIconCooldownViewer and BuffBarCooldownViewer only keep a real pooled
-- child shown while its effect is active. Some Blizzard tracked effects
-- (totems, guardians and a few spell-driven buffs) never expose a usable
-- auraInstanceID/DurationObject, so IsBufChildCooldownActive() alone reports
-- them inactive and KUI drops the whole Buffs bar. Use a
-- structural fallback: a shown, non-placeholder child in a buff viewer is an
-- active effect. Alpha is deliberately ignored because KUI makes the native
-- viewer shell transparent while continuing to mirror its children.
function ns.IsShownBuffViewerChild(ch)
    if not ch or ch._isPlaceholderFrame then return false end
    return ch.IsShown and ch:IsShown() or false
end

-- A Blizzard CDM pool child persists after its buff/aura/cooldown ends; only a
-- live cooldown/duration that has not yet expired means the effect is active.
local function IsBlizzChildEffectLive(ch)
    if not ch or not IsBufChildCooldownActive(ch) then
        return false
    end
    local durObj = _cdmDurObjCache[ch]
    if durObj then
        local et = durObj.endTime or durObj.expirationTime
        if et ~= nil and type(et) == "number" and not (issecretvalue and issecretvalue(et)) and et <= GetTime() * 1000 then
            return false
        end
    end
    return true
end

local function RegisterCDMChildCooldownHooks(ch)
    if not ch or not ch.Cooldown or ch._cdmHooked then
        return
    end

    ch._cdmHooked = true

    if ch.Cooldown.SetCooldownFromDurationObject then
        hooksecurefunc(ch.Cooldown, "SetCooldownFromDurationObject", function(_, durObj)
            _cdmChildHasDurObj[ch] = durObj ~= nil
            _cdmDurObjCache[ch] = durObj
        end)
    end

    hooksecurefunc(ch.Cooldown, "SetCooldown", function(_, start, dur)
        if issecretvalue and (issecretvalue(dur) or issecretvalue(start)) then
            _cdmRawStartCache[ch] = start
            _cdmRawDurCache[ch] = dur
        elseif dur and dur > 0 then
            _cdmRawStartCache[ch] = start
            _cdmRawDurCache[ch] = dur
        else
            _cdmChildHasDurObj[ch] = nil
            _cdmDurObjCache[ch] = nil
            _cdmRawStartCache[ch] = nil
            _cdmRawDurCache[ch] = nil
        end
    end)

    if ch.Cooldown.Clear then
        hooksecurefunc(ch.Cooldown, "Clear", function()
            _cdmChildHasDurObj[ch] = nil
            _cdmDurObjCache[ch] = nil
            _cdmRawStartCache[ch] = nil
            _cdmRawDurCache[ch] = nil
        end)
    end
end

local function CacheViewerChildSpell(cache, spellID, ch, allowReplace)
    if not IsCleanPositiveNumber(spellID) then
        return
    end
    if allowReplace or not cache[spellID] then
        cache[spellID] = ch
    end
end

local function BuildBlizzardMirrorDedupeKey(ch, resolvedSid, baseSpellID, cdID, viewerName)
    if IsCleanPositiveNumber(resolvedSid) then
        return "s:" .. tostring(resolvedSid)
    end
    if IsCleanPositiveNumber(baseSpellID) then
        return "b:" .. tostring(baseSpellID)
    end
    if IsCleanPositiveNumber(cdID) then
        return "c:" .. tostring(cdID)
    end
    if ch and ch.auraInstanceID then
        return "a:" .. tostring(ch.auraDataUnit or "player") .. ":" .. tostring(ch.auraInstanceID)
    end

    local texPath = ns._tickBlizzMirror and ns._tickBlizzMirror:getIconTexture(ch)
    if texPath and not (issecretvalue and issecretvalue(texPath)) then
        return "t:" .. tostring(viewerName or "") .. ":" .. tostring(texPath)
    end
    return nil
end

local function CacheBlizzardViewerChild(ch, info, viewerName)
    if not ch or type(info) ~= "table" then
        return
    end

    RegisterCDMChildCooldownHooks(ch)

    local cdID = ch.cooldownID or (ch.cooldownInfo and ch.cooldownInfo.cooldownID)
    local baseSpellID = info.spellID
    local resolvedSid = ns.ResolveInfoSpellID(info) or baseSpellID
    local isBuffViewer = viewerName == "BuffIconCooldownViewer" or viewerName == "BuffBarCooldownViewer"
    local isBuffIconViewer = viewerName == "BuffIconCooldownViewer"
    local linkedSpellIDs = type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or nil
    local mirrorBarKey = ns._tickBlizzMirror and ns._tickBlizzMirror:getBarKey(viewerName)
    local liveBuffState = isBuffViewer
        and (IsBufChildCooldownActive(ch) or ns.IsShownBuffViewerChild(ch))
        or false

    ch._cdmBaseSpellID = baseSpellID
    ch._cdmOverrideSid = info.overrideSpellID
    ch._cdmResolvedSid = resolvedSid
    ch._cdmCachedCdID = cdID
    ch._cdmCachedAuraInstID = ch.auraInstanceID
    ch._cdmLinkedSpellIDs = linkedSpellIDs
    if IsCleanPositiveNumber(baseSpellID) and IsCleanPositiveNumber(info.overrideSpellID) and info.overrideSpellID ~= baseSpellID then
        _tickBlizzOverrideCache[baseSpellID] = info.overrideSpellID
        _tickBlizzChildCache[info.overrideSpellID] = ch
    end

    if IsCleanPositiveNumber(resolvedSid) then
        _tickBlizzAllChildCache[resolvedSid] = ch
        if isBuffViewer then
            CacheViewerChildSpell(_tickBlizzBuffChildCache, resolvedSid, ch, isBuffIconViewer)
        end
    end

    if isBuffViewer and IsCleanPositiveNumber(baseSpellID) and baseSpellID ~= resolvedSid then
        _tickBlizzAllChildCache[baseSpellID] = ch
        CacheViewerChildSpell(_tickBlizzBuffChildCache, baseSpellID, ch, isBuffIconViewer)
    end

    if isBuffViewer and linkedSpellIDs then
        for i = 1, #linkedSpellIDs do
            local linkedID = linkedSpellIDs[i]
            if IsCleanPositiveNumber(linkedID) and linkedID ~= resolvedSid then
                _tickBlizzAllChildCache[linkedID] = ch
                CacheViewerChildSpell(_tickBlizzBuffChildCache, linkedID, ch, isBuffIconViewer)
            end
        end
    end

    if isBuffViewer and cdID then
        local correctSid = ns._cdIDToCorrectSID[cdID]
        if IsCleanPositiveNumber(correctSid) and correctSid ~= resolvedSid then
            _tickBlizzAllChildCache[correctSid] = ch
            CacheViewerChildSpell(_tickBlizzBuffChildCache, correctSid, ch, isBuffIconViewer)
        end
    end

    if mirrorBarKey then
        local texPath = ns._tickBlizzMirror and ns._tickBlizzMirror:getIconTexture(ch)
        if texPath and (mirrorBarKey ~= "buffs" or liveBuffState) then
            local seen = ns._tickBlizzMirror.seen[mirrorBarKey]
            local dedupeKey = BuildBlizzardMirrorDedupeKey(ch, resolvedSid, baseSpellID, cdID, viewerName)
            if not dedupeKey or not seen[dedupeKey] then
                if dedupeKey then
                    seen[dedupeKey] = true
                end
                local list = ns._tickBlizzMirror.icons[mirrorBarKey]
                list[#list + 1] = ch
            end
        end
    end

    -- Frames here come from EnumerateActive so they are by definition currently
    -- active. IsBufChildCooldownActive reads live aura/totem state and falls back
    -- to hook-captured cooldown caches which are valid for in-pool active frames.
    local auraBased = (ch.wasSetFromAura == true or ch.auraInstanceID ~= nil)
    local buffActive = isBuffViewer and liveBuffState
        or (auraBased and liveBuffState)

    if buffActive then
        if IsCleanPositiveNumber(resolvedSid) then
            _tickBlizzActiveCache[resolvedSid] = true
        end
        if isBuffViewer and IsCleanPositiveNumber(baseSpellID) then
            _tickBlizzActiveCache[baseSpellID] = true
        end
        if isBuffViewer and linkedSpellIDs then
            for i = 1, #linkedSpellIDs do
                local linkedID = linkedSpellIDs[i]
                if IsCleanPositiveNumber(linkedID) then
                    _tickBlizzActiveCache[linkedID] = true
                end
            end
        end
        if isBuffViewer and cdID then
            local correctSid = ns._cdIDToCorrectSID[cdID]
            if IsCleanPositiveNumber(correctSid) then
                _tickBlizzActiveCache[correctSid] = true
            end
        end
    end
end

local function IsCDMBuffActiveForBar(resolvedSpellID, spellID, fallbackChild)
    if resolvedSpellID and _tickBlizzActiveCache[resolvedSpellID] then
        return true
    end
    if spellID and _tickBlizzActiveCache[spellID] then
        return true
    end

    local blizzChild = fallbackChild
        or (resolvedSpellID and _tickBlizzBuffChildCache[resolvedSpellID])
        or (spellID and _tickBlizzBuffChildCache[spellID])
        or (resolvedSpellID and _tickBlizzAllChildCache[resolvedSpellID])
        or (spellID and _tickBlizzAllChildCache[spellID])
    if not blizzChild then
        return false
    end

    return IsBufChildCooldownActive(blizzChild)
        or ns.IsShownBuffViewerChild(blizzChild)
end
ns.IsCDMBuffActiveForBar = IsCDMBuffActiveForBar

local BuildAllCDMBars

local function RegisterCDMUnlockElements()
    if not (ns.KT and ns.KT.RegisterMovableElements) then return end

    local elements = {}

    -- Main bars
    for barKey, frame in pairs(ns.cdmBarFrames) do
        local barData = ns.barDataByKey[barKey]
        if barData and barData.enabled then
            table.insert(elements, {
                key = "CDM_" .. barKey,
                label = (barData.name or barKey) .. " (CDM)",
                getFrame = function() return frame end,
                getScale = function() return frame:GetScale() end,
                loadPosition = function()
                    local p = KUI_CDM.db and KUI_CDM.db.profile
                    local pos = p and p.cdmBarPositions and p.cdmBarPositions[barKey] or nil
                    if pos and pos.point then
                        return {
                            point = pos.point,
                            relativePoint = pos.relPoint or pos.point,
                            x = pos.x or 0,
                            y = pos.y or 0,
                        }
                    end
                    return nil
                end,
                savePosition = function(_, point, relativeTo, xOff, yOff, uiScale)
                    local p = KUI_CDM.db and KUI_CDM.db.profile
                    if not p then return end
                    p.cdmBarPositions = p.cdmBarPositions or {}
                    p.cdmBarPositions[barKey] = {
                        point = point or "CENTER",
                        relPoint = relativeTo or point or "CENTER",
                        x = xOff or 0,
                        y = yOff or 0,
                    }
                    barData.anchorTo = "none"
                end,
                applyPosition = function()
                    if BuildAllCDMBars then
                        BuildAllCDMBars()
                    end
                end,
                getSize = function()
                    local w, h = frame:GetSize()
                    if w and h and w > 5 and h > 5 then return w, h end
                    return barData.iconSize or 40, barData.iconSize or 40
                end
            })
        end
    end

    -- Utility trackers
    if KUI_CDM.db and KUI_CDM.db.profile and KUI_CDM.db.profile.customTracker then
        for trackerType, trackerData in pairs(KUI_CDM.db.profile.customTracker) do
            if trackerData.enabled then
                local frameName = "KUI_CustomTracker_" .. trackerType
                local frame = _G[frameName]
                if frame then
                    table.insert(elements, {
                        key = "CDM_Tracker_" .. trackerType,
                        label = trackerType:gsub("^%l", string.upper) .. " Tracker",
                        getFrame = function() return frame end,
                        getScale = function() return frame:GetScale() end,
                        savePosition = function(_, point, relativeTo, xOff, yOff, uiScale)
                            trackerData.x = xOff
                            trackerData.y = yOff
                        end,
                        getSize = function()
                            return frame:GetSize()
                        end
                    })
                end
            end
        end
    end

    ns.KT:RegisterMovableElements(elements)
end


local ForcePopulateBlizzardViewers
local StartResnapshotRetry
local SnapshotBlizzardCDM

-------------------------------------------------------------------------------
--  Defaults
-------------------------------------------------------------------------------
local DEFAULTS = {
    global = {
        multiChargeSpells = {},
    },
    profile = {
        _capturedOnce    = false,
        reskinBorders    = true,
        utilityScale     = 1.0,
        buffBarScale     = 1.0,
        cooldownBarScale = 1.0,
        spec             = {},
        activeSpecKey    = "0",
        barGlows         = {
            enabled = true,
            glowStyle = "blizzard",
            procGlowStyle = "blizzard",
            selectedBar = 1,
            selectedButton = nil,
            selectedSpellIdentifier = nil,
            selectedAssignment = 1,
            assignments = {},
            spellOverrides = {},
        },
        buffBars         = {
            enabled       = false,
            width         = 200,
            height        = 18,
            spacing       = 2,
            maxBars       = 8,
            growUp        = false,
            showTimer     = true,
            showIcon      = true,
            iconSize      = 18,
            borderSize    = 1,
            borderR       = 0,
            borderG       = 0,
            borderB       = 0,
            borderA       = 1,
            bgAlpha       = 0.4,
            barR          = 0.05,
            barG          = 0.82,
            barB          = 0.62,
            useClassColor = false,
            filterMode    = "all",
            filterList    = "",
            locked        = false,
            offsetX       = 300,
            offsetY       = -200,
        },
        cdmBars          = {
            enabled = true,
            hideBlizzard = true,
            unitFrameCDMOffsetX = 15,
            unitFrameCDMMinWidth = 180,
            useBlizzardDisplayDefaults = true,
            promptBlizzardLayoutChanges = true,
            barDefaults = {
                barStrata = "MEDIUM",
                iconSize = 36,
                numRows = 1,
                spacing = 2,
                borderSize = 1,
                borderR = 0,
                borderG = 0,
                borderB = 0,
                borderA = 1,
                borderClassColor = false,
                bgR = 0.08,
                bgG = 0.08,
                bgB = 0.08,
                bgA = 0.6,
                iconZoom = 0.08,
                iconShape = "none",
                growDirection = "RIGHT",
                verticalOrientation = false,
                barBgEnabled = false,
                barBgAlpha = 1.0,
                barBgR = 0,
                barBgG = 0,
                barBgB = 0,
                showCooldownText = true,
                cooldownFontSize = 12,
                showCharges = true,
                chargeFontSize = 11,
                desaturateOnCD = false,
                swipeAlpha = 0.7,
                swipeR = 0,
                swipeG = 0,
                swipeB = 0,
                activeSwipeUsesGlowColor = true,
                hideGCDSwipe = false,
                borderThickness = "thin",
                activeStateAnim = "blizzard",
                activeAnimClassColor = false,
                activeAnimR = 1.0,
                activeAnimG = 0.85,
                activeAnimB = 0.0,
                anchorTo = "none",
                anchorPosition = "left",
                anchorOffsetX = 0,
                anchorOffsetY = 0,
                barVisibility = "always",
                housingHideEnabled = true,
                hideBuffsWhenInactive = true,
                stackCountSize = 12,
                stackCountX = 0,
                stackCountY = 0,
                stackCountR = 1,
                stackCountG = 1,
                stackCountB = 1,
                showTooltip = false,
                showKeybind = false,
                keybindSize = 13,
                keybindOutline = true,
                keybindOffsetX = 2,
                keybindOffsetY = -2,
                keybindR = 1,
                keybindG = 1,
                keybindB = 1,
                keybindA = 0.9,
                assistedCombatHighlight = false,
                buttonPressHighlight = false,
                hideWhenMode = "ANY",
                hideWhen = {},
            },
            bars = {
                {
                    key = "cooldowns",
                    name = "Cooldowns",
                    enabled = true,
                    barStrata = "MEDIUM",
                    barScale = 1.0,
                    iconSize = 42,
                    numRows = 1,
                    spacing = 2,
                    borderSize = 1,
                    borderR = 0,
                    borderG = 0,
                    borderB = 0,
                    borderA = 1,
                    borderClassColor = false,
                    bgR = 0.08,
                    bgG = 0.08,
                    bgB = 0.08,
                    bgA = 0.6,
                    iconZoom = 0.08,
                    iconShape = "none",
                    growDirection = "RIGHT",
                    verticalOrientation = false,
                    barBgEnabled = false,
                    barBgAlpha = 1.0,
                    barBgR = 0,
                    barBgG = 0,
                    barBgB = 0,
                    showCooldownText = true,
                    cooldownFontSize = 12,
                    showCharges = true,
                    chargeFontSize = 11,
                    desaturateOnCD = false,
                    swipeAlpha = 0.7,
                    swipeR = 0,
                    swipeG = 0,
                    swipeB = 0,
                    activeSwipeUsesGlowColor = true,
                    hideGCDSwipe = false,
                    borderThickness = "thin",
                    activeStateAnim = "blizzard",
                    activeAnimClassColor = false,
                    activeAnimR = 1.0,
                    activeAnimG = 0.85,
                    activeAnimB = 0.0,
                    -- Cooldowns: posicion fija en la parte inferior de la pantalla
                    anchorTo = "none",
                    anchorOffsetX = 0,
                    anchorOffsetY = -250,
                    growCentered = true,
                    barVisibility = "always",
                    housingHideEnabled = true,
                    hideBuffsWhenInactive = true,
                    stackCountSize = 12,
                    stackCountX = 0,
                    stackCountY = 0,
                    stackCountR = 1,
                    stackCountG = 1,
                    stackCountB = 1,
                    showTooltip = false,
                    showKeybind = false,
                    keybindSize = 13,
                    keybindOutline = true,
                    keybindOffsetX = 2,
                    keybindOffsetY = -2,
                    keybindR = 1,
                    keybindG = 1,
                    keybindB = 1,
                    keybindA = 0.9,
                    assistedCombatHighlight = false,
                    buttonPressHighlight = false,
                    hideWhenMode = "ANY",
                    hideWhen = {},
                },
                {
                    key = "utility",
                    name = "Utility",
                    enabled = true,
                    barStrata = "MEDIUM",
                    barScale = 1.0,
                    iconSize = 28,
                    numRows = 2,
                    spacing = 2,
                    borderSize = 1,
                    borderR = 0,
                    borderG = 0,
                    borderB = 0,
                    borderA = 1,
                    borderClassColor = false,
                    bgR = 0.08,
                    bgG = 0.08,
                    bgB = 0.08,
                    bgA = 0.6,
                    iconZoom = 0.08,
                    iconShape = "none",
                    growDirection = "RIGHT",
                    verticalOrientation = false,
                    barBgEnabled = false,
                    barBgAlpha = 1.0,
                    barBgR = 0,
                    barBgG = 0,
                    barBgB = 0,
                    showCooldownText = true,
                    cooldownFontSize = 12,
                    showCharges = true,
                    chargeFontSize = 11,
                    desaturateOnCD = false,
                    swipeAlpha = 0.7,
                    swipeR = 0,
                    swipeG = 0,
                    swipeB = 0,
                    activeSwipeUsesGlowColor = true,
                    hideGCDSwipe = false,
                    borderThickness = "thin",
                    activeStateAnim = "blizzard",
                    activeAnimClassColor = false,
                    activeAnimR = 1.0,
                    activeAnimG = 0.85,
                    activeAnimB = 0.0,
                    -- Utility: centrada justo debajo de Cooldowns, sin separacion
                    anchorTo = "cooldowns",
                    anchorPosition = "bottom",
                    anchorOffsetX = 0,
                    anchorOffsetY = -2,
                    growCentered = true,
                    barVisibility = "always",
                    housingHideEnabled = true,
                    hideBuffsWhenInactive = true,
                    stackCountSize = 12,
                    stackCountX = 0,
                    stackCountY = 0,
                    stackCountR = 1,
                    stackCountG = 1,
                    stackCountB = 1,
                    showTooltip = false,
                    showKeybind = false,
                    keybindSize = 13,
                    keybindOutline = true,
                    keybindOffsetX = 2,
                    keybindOffsetY = -2,
                    keybindR = 1,
                    keybindG = 1,
                    keybindB = 1,
                    keybindA = 0.9,
                    assistedCombatHighlight = false,
                    buttonPressHighlight = false,
                    hideWhenMode = "ANY",
                    hideWhen = {},
                },
                {
                    key = "buffs",
                    name = "Buffs",
                    enabled = true,
                    barStrata = "MEDIUM",
                    barScale = 1.0,
                    iconSize = 32,
                    numRows = 1,
                    spacing = 2,
                    borderSize = 1,
                    borderR = 0,
                    borderG = 0,
                    borderB = 0,
                    borderA = 1,
                    borderClassColor = false,
                    bgR = 0.08,
                    bgG = 0.08,
                    bgB = 0.08,
                    bgA = 0.6,
                    iconZoom = 0.08,
                    iconShape = "none",
                    growDirection = "RIGHT",
                    verticalOrientation = false,
                    barBgEnabled = false,
                    barBgAlpha = 1.0,
                    barBgR = 0,
                    barBgG = 0,
                    barBgB = 0,
                    showCooldownText = true,
                    cooldownFontSize = 12,
                    showCharges = true,
                    chargeFontSize = 11,
                    desaturateOnCD = false,
                    swipeAlpha = 0.7,
                    swipeR = 0,
                    swipeG = 0,
                    swipeB = 0,
                    activeSwipeUsesGlowColor = true,
                    hideGCDSwipe = false,
                    borderThickness = "thin",
                    activeStateAnim = "blizzard",
                    activeAnimClassColor = false,
                    activeAnimR = 1.0,
                    activeAnimG = 0.85,
                    activeAnimB = 0.0,
                    -- Buffs: anclado centrado encima de la cast bar
                    anchorTo = "castbar",
                    anchorPosition = "top",
                    anchorOffsetX = 0,
                    anchorOffsetY = 15,
                    growCentered = true,
                    barVisibility = "always",
                    housingHideEnabled = true,
                    hideBuffsWhenInactive = false,
                    stackCountSize = 12,
                    stackCountX = 0,
                    stackCountY = 0,
                    stackCountR = 1,
                    stackCountG = 1,
                    stackCountB = 1,
                    showTooltip = false,
                    showKeybind = false,
                    keybindSize = 13,
                    keybindOutline = true,
                    keybindOffsetX = 2,
                    keybindOffsetY = -2,
                    keybindR = 1,
                    keybindG = 1,
                    keybindB = 1,
                    keybindA = 0.9,
                    assistedCombatHighlight = false,
                    buttonPressHighlight = false,
                    hideWhenMode = "ANY",
                    hideWhen = {},
                },
            },
        },
        customTracker    = {
            interrupt = { enabled = true, size = 42, showText = true, x = 0, y = 4, side = "TOPRIGHT_OUT", auto = true, maxIcons = 1, spells = {} },
            defensive = { enabled = true, size = 36, showText = true, x = 0, y = 4, side = "TOPRIGHT_OUT", auto = true, maxIcons = 2, spells = {} },
            trinket   = { enabled = true, size = 36, showText = true, x = 0, y = -4, side = "BOTTOMRIGHT_OUT", auto = true, maxIcons = 2, spells = {} },
            potion    = { enabled = true, size = 36, showText = true, x = 0, y = -4, side = "BOTTOMLEFT_OUT", auto = true, maxIcons = 3, spells = {}, trackManaPotion = false, potionQuality = "highest" },
        },
        cdmBarPositions  = {},
        tbbPositions     = {},
        specProfiles     = {},
    },
}

-------------------------------------------------------------------------------
--  Spec helpers
-------------------------------------------------------------------------------
local function GetCurrentSpecKey()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then return "0" end
    local specID = select(1, GetSpecializationInfo(specIndex))
    return tostring(specID or 0)
end

local _specValidated = false
local function ValidateSpec()
    local profile = KUI_CDM.db and KUI_CDM.db.profile
    local realKey = profile and GetCurrentSpecKey()
    if not realKey or realKey == "0" then return end
    -- Marcar validado antes de cualquier cambio de perfil
    _specValidated = true
    if profile.activeSpecKey ~= realKey and ns.SwitchSpecProfile then
        ns.SwitchSpecProfile(realKey)
    end
end

local function GetOrCreateSpecState(profile, key)
    profile.spec = profile.spec or {}

    local specState = profile.spec[key]
    if not specState then
        specState = { mappings = {}, selectedMapping = 1 }
        profile.spec[key] = specState
        return specState
    end

    specState.mappings = specState.mappings or {}
    specState.selectedMapping = tonumber(specState.selectedMapping) or 1
    return specState
end

local function GetStore()
    local p = KUI_CDM.db.profile
    return GetOrCreateSpecState(p, p.activeSpecKey or "0")
end

local function EnsureMappings(store)
    if not store.mappings then store.mappings = {} end
    if #store.mappings == 0 then
        store.mappings[1] = {
            enabled = false,
            name = DEFAULT_MAPPING_NAME,
            actionBar = 1,
            actionButton = 1,
            cdmSlot = 1,
            hideFromCDM = false,
            mode = "ACTIVE",
            glowStyle = 1,
            glowColor = { r = 1, g = 0.82, b = 0.1 },
        }
    end
    store.selectedMapping = tonumber(store.selectedMapping) or 1
    if store.selectedMapping < 1 then store.selectedMapping = 1 end
    if store.selectedMapping > #store.mappings then store.selectedMapping = #store.mappings end
    for _, m in ipairs(store.mappings) do
        if m.enabled == nil then m.enabled = true end
        if m.hideFromCDM == nil then m.hideFromCDM = false end
        if m.mode ~= "MISSING" then m.mode = "ACTIVE" end
        m.glowStyle = tonumber(m.glowStyle) or 1
        if not m.glowColor then m.glowColor = { r = 1, g = 0.82, b = 0.1 } end
        m.name = tostring(m.name or "")
        if type(m.actionBar) ~= "string" or not ns.CDM_BAR_ROOTS[m.actionBar] then
            m.actionBar = tonumber(m.actionBar) or 1
        end
        m.actionButton = tonumber(m.actionButton) or 1
        m.cdmSlot = tonumber(m.cdmSlot) or 1
    end
end

ns.DEFAULT_MAPPING_NAME = DEFAULT_MAPPING_NAME
ns.GetStore = GetStore
ns.EnsureMappings = EnsureMappings
-------------------------------------------------------------------------------
--  Per-Spec Profile Helpers
--  Saves/restores spell lists, bar glows, and buff bars per specialization.
--  Bar structure, settings, and positions are shared across all specs.
-------------------------------------------------------------------------------
local MAIN_BAR_KEYS = { cooldowns = true, utility = true, buffs = true }

-- Bar types that support talent-aware dormant slot persistence.
-- Trinket/racial/potion and buff bars are excluded.
local TALENT_AWARE_BAR_TYPES = { cooldowns = true, utility = true }


-------------------------------------------------------------------------------
--  Build a set of currently known (learned) spellIDs across all CDM categories.
-------------------------------------------------------------------------------
local function BuildKnownSpellIDSet()
    local known = {}
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCategorySet then return known end
    for _, cat in ipairs(GetCooldownViewerCategories()) do
        local ok, knownIDs = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, cat, false)
        knownIDs = ok and knownIDs or nil
        if knownIDs then
            for _, cdID in ipairs(knownIDs) do
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                if info and info.spellID and info.spellID > 0 then
                    known[info.spellID] = true
                end
            end
        end
    end
    return known
end

-- Iterative deep clone helper
local function CloneTableTree(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}

    local root = {}
    seen[value] = root

    -- Pila: { destino, clave_orig, valor_orig }
    local stack, sp = {}, 0
    for k, v in pairs(value) do
        sp = sp + 1; stack[sp] = { root, k, v }
    end

    while sp > 0 do
        local item = stack[sp]; sp = sp - 1
        local dest, rawKey, rawVal = item[1], item[2], item[3]

        -- Resolver clave
        local resolvedKey = rawKey
        if type(rawKey) == "table" then
            if seen[rawKey] then resolvedKey = seen[rawKey]
            else local kt = {}; seen[rawKey] = kt; resolvedKey = kt
                for k2, v2 in pairs(rawKey) do sp = sp + 1; stack[sp] = { kt, k2, v2 } end
            end
        end

        -- Resolver valor
        if type(rawVal) ~= "table" then
            dest[resolvedKey] = rawVal
        elseif seen[rawVal] then
            dest[resolvedKey] = seen[rawVal]
        else
            local vt = {}; seen[rawVal] = vt; dest[resolvedKey] = vt
            for k3, v3 in pairs(rawVal) do sp = sp + 1; stack[sp] = { vt, k3, v3 } end
        end
    end

    return root
end

--- Save the current spec's per-spec data into specProfiles[specKey]
local function SaveCurrentSpecProfile()
    local p = KUI_CDM.db.profile
    local specKey = p.activeSpecKey
    if not specKey or specKey == "0" then return end
    if not p.specProfiles then p.specProfiles = {} end

    local prof = {}

    -- 1) Spell lists for each bar
    prof.barSpells = {}
    for _, barData in ipairs(p.cdmBars.bars) do
        local key = barData.key
        if key then
            local entry = {}
            if MAIN_BAR_KEYS[key] then
                entry.trackedSpells = CloneTableTree(barData.trackedSpells)
                entry.extraSpells   = CloneTableTree(barData.extraSpells)
                entry.removedSpells = CloneTableTree(barData.removedSpells)
                entry.dormantSpells = CloneTableTree(barData.dormantSpells)
            elseif barData.barType ~= "trinkets" then
                entry.customSpells = CloneTableTree(barData.customSpells)
                if TALENT_AWARE_BAR_TYPES[barData.barType] then
                    entry.dormantSpells = CloneTableTree(barData.dormantSpells)
                end
            end
            prof.barSpells[key] = entry
        end
    end

    -- 2) Bar Glows (full table)
    prof.barGlows = CloneTableTree(p.barGlows)

    -- 3) Tracked buff bar state
    if p.trackedBuffBars then
        prof.trackedBuffBars = CloneTableTree(p.trackedBuffBars)
    end
    if p.tbbPositions then
        prof.tbbPositions = CloneTableTree(p.tbbPositions)
    end

    p.specProfiles[specKey] = prof
end

--- Restore a spec profile into the live data, or initialize fresh if none exists
local function LoadSpecProfile(specKey)
    local p = KUI_CDM.db.profile
    if not p.specProfiles then p.specProfiles = {} end
    local prof = p.specProfiles[specKey]

    if prof then
        if prof.barSpells then
            for _, barData in ipairs(p.cdmBars.bars) do
                local saved = prof.barSpells[barData.key]
                if saved then
                    if MAIN_BAR_KEYS[barData.key] then
                        barData.trackedSpells = CloneTableTree(saved.trackedSpells)
                        barData.extraSpells   = CloneTableTree(saved.extraSpells)
                        barData.removedSpells = CloneTableTree(saved.removedSpells)
                        barData.dormantSpells = CloneTableTree(saved.dormantSpells)
                    elseif barData.barType ~= "trinkets" then
                        barData.customSpells = CloneTableTree(saved.customSpells)
                        if TALENT_AWARE_BAR_TYPES[barData.barType] then
                            barData.dormantSpells = CloneTableTree(saved.dormantSpells)
                        end
                    end
                else
                    if MAIN_BAR_KEYS[barData.key] then
                        barData.trackedSpells = nil
                        barData.extraSpells = nil
                        barData.removedSpells = nil
                        barData.dormantSpells = nil
                    elseif barData.barType ~= "trinkets" then
                        barData.customSpells = {}
                        barData.dormantSpells = nil
                    end
                end
            end
        end

        if prof.barGlows then
            p.barGlows = CloneTableTree(prof.barGlows)
        end

        if prof.trackedBuffBars ~= nil then
            p.trackedBuffBars = CloneTableTree(prof.trackedBuffBars)
        end
        if prof.tbbPositions ~= nil then
            p.tbbPositions = CloneTableTree(prof.tbbPositions)
        end
    else
        for _, barData in ipairs(p.cdmBars.bars) do
            if MAIN_BAR_KEYS[barData.key] then
                barData.trackedSpells = nil
                barData.extraSpells = nil
                barData.removedSpells = nil
                barData.dormantSpells = nil
            elseif barData.barType ~= "trinkets" then
                barData.customSpells = {}
                barData.dormantSpells = nil
            end
        end

        p.barGlows = {
            enabled = true,
            selectedBar = 1,
            selectedButton = nil,
            selectedAssignment = 1,
            assignments = {},
        }
    end

    local barKeySet = {}
    for _, barData in ipairs(p.cdmBars.bars) do
        barKeySet[barData.key] = barData
    end
    for _, barData in ipairs(p.cdmBars.bars) do
        if barData.barType == "trinkets" and barData.anchorTo and barData.anchorTo ~= "none" then
            local anchor = barKeySet[barData.anchorTo]
            if anchor and anchor.barType ~= "trinkets" and not MAIN_BAR_KEYS[anchor.key] then
                local spells = anchor.customSpells
                if not spells or #spells == 0 then
                    barData.anchorTo = "none"
                    barData.anchorPosition = "left"
                    barData.anchorOffsetX = 0
                    barData.anchorOffsetY = 0
                end
            end
        end
    end
end

--- Full spec switch: save current, load new, rebuild everything
local function SwitchSpecProfile(newSpecKey)
    local p = KUI_CDM.db.profile
    local oldSpecKey = p.activeSpecKey

    if oldSpecKey and oldSpecKey ~= "0" then
        SaveCurrentSpecProfile()
    end

    p.activeSpecKey = newSpecKey
    GetOrCreateSpecState(p, newSpecKey)
    LoadSpecProfile(newSpecKey)

    C_Timer.After(0.5, function()
        BuildAllCDMBars()
        ns.BuildTrackedBuffBars()
        RegisterCDMUnlockElements()

        -- Fallback spell rebuilds since old snapshot functions were removed
        -- C_Timer.After(1, function() ns.BuildAllTrackedSpells() end)
        -- C_Timer.After(3, function() ns.BuildAllTrackedSpells() end)

        -- Refresh options panel if visible
        if KT and KT._mainFrame and KT._mainFrame:IsShown() then
            if KT.InvalidateContentHeaderCache then
                KT:InvalidateContentHeaderCache()
            end
            if KT.RefreshPage then
                KT:RefreshPage()
            end
        end
    end)
end
ns.SwitchSpecProfile = SwitchSpecProfile

-------------------------------------------------------------------------------
--  CDM Bar Roots
-------------------------------------------------------------------------------
ns.CDM_BAR_ROOTS = {
    CDM_COOLDOWN = "EssentialCooldownViewer",
    CDM_UTILITY  = "UtilityCooldownViewer",
}

-------------------------------------------------------------------------------
--  Action Button Lookup (supports Blizzard and popular bar addons)
-------------------------------------------------------------------------------
do
    local blizzBarNames = {
        [2] = "MultiBarBottomLeftButton",
        [3] = "MultiBarBottomRightButton",
        [4] = "MultiBarRightButton",
        [5] = "MultiBarLeftButton",
        [6] = "MultiBar5Button",
        [7] = "MultiBar6Button",
        [8] = "MultiBar7Button",
    }

    local actionButtonCache = {}

    local function FirstExisting(...)
        for i = 1, select("#", ...) do
            local f = _G[select(i, ...)]
            if f then return f end
        end
    end

    local function GetActionButton(bar, i)
        bar = bar or 1
        local cacheKey = bar * 100 + i
        if actionButtonCache[cacheKey] then return actionButtonCache[cacheKey] end
        local btn
        if bar == 1 then
            btn = FirstExisting(
                "BT4Button" .. i, "ElvUI_Bar1Button" .. i,
                "DominosActionButton" .. i, "ActionButton" .. i)
        else
            local offset = (bar - 1) * 12
            local blizz = blizzBarNames[bar]
            btn = FirstExisting(
                "BT4Button" .. (offset + i),
                "ElvUI_Bar" .. bar .. "Button" .. i,
                "DominosActionButton" .. (offset + i),
                blizz and (blizz .. i) or nil)
        end
        if btn then actionButtonCache[cacheKey] = btn end
        return btn
    end

    -------------------------------------------------------------------------------
    --  CDM Slot Helpers
    -------------------------------------------------------------------------------
    local function FindCooldown(frame)
        if not frame then return end
        local cd = frame.cooldown or frame.Cooldown
        if cd then return cd end
        local _children = { frame:GetChildren() }
        for i, child in ipairs(_children) do
            if child and child.GetObjectType and child:GetObjectType() == "Cooldown" then
                return child
            end
        end
    end

    local function SlotSortComparator(a, b)
        local ax, ay = a:GetCenter()
        local bx, by = b:GetCenter()
        ax, ay, bx, by = ax or 0, ay or 0, bx or 0, by or 0
        if abs(ay - by) > 2 then return ay > by end
        return ax < bx
    end

    local cachedSlots, cacheTime = nil, 0
    local CACHE_DURATION = 0.5

    local function GetSortedSlots(forceRefresh)
        local now = GetTime()
        if not forceRefresh and cachedSlots and (now - cacheTime) < CACHE_DURATION then
            return cachedSlots
        end
        local root = rawget(_G, "BuffIconCooldownViewer")
        if not root or not root.GetChildren then
            cachedSlots = nil; return nil
        end
        local slots = {}
        local _children = { root:GetChildren() }
        for i, c in ipairs(_children) do
            if c and c.GetCenter and FindCooldown(c) then
                slots[#slots + 1] = c
            end
        end
        if #slots == 0 then
            cachedSlots = nil; return nil
        end
        table.sort(slots, SlotSortComparator)
        cachedSlots = slots
        cacheTime = now
        return slots
    end

    local function GetAllCDMSlots(root)
        if not root or not root.GetChildren then return {} end
        local slots = {}
        local _children = { root:GetChildren() }
        for i, c in ipairs(_children) do
            if c and c.GetWidth and c:GetWidth() > 5 then
                slots[#slots + 1] = c
            end
        end
        return slots
    end

    local function GetCDMBarButton(barKey, slotIndex)
        local rootName = ns.CDM_BAR_ROOTS[barKey]
        if not rootName then return nil end
        local root = _G[rootName]
        if not root or not root.GetChildren then return nil end
        local slots = {}
        local _children = { root:GetChildren() }
        for i, c in ipairs(_children) do
            if c and c.GetWidth and c:GetWidth() > 5 then
                slots[#slots + 1] = c
            end
        end
        if #slots == 0 then return nil end
        table.sort(slots, SlotSortComparator)
        return slots[slotIndex]
    end

    local function GetTargetButton(actionBar, actionButtonIndex)
        if type(actionBar) == "string" and ns.CDM_BAR_ROOTS[actionBar] then
            return GetCDMBarButton(actionBar, actionButtonIndex)
        end
        return GetActionButton(tonumber(actionBar) or 1, actionButtonIndex)
    end

    -------------------------------------------------------------------------------
    --  CDM Look: Border Reskinning
    -------------------------------------------------------------------------------
    local cdmBorderFrames = {}
    local safeEq = function(a, b) return a == b end
    local cdmBorderBackdrop = { edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

    local function GetOrCreateCDMBorder(slot)
        if cdmBorderFrames[slot] then return cdmBorderFrames[slot] end

        slot.__KUIHidden   = slot.__KUIHidden or {}
        slot.__KUIIcon     = slot.__KUIIcon or nil
        slot.__KUICooldown = slot.__KUICooldown or nil

        if not slot.__KUIScanned then
            slot.__KUIHidden = {}
            slot.__KUIIcon = nil
            slot.__KUICooldown = nil

            for ri = 1, slot:GetNumRegions() do
                local region = select(ri, slot:GetRegions())
                if region and region.GetObjectType then
                    local objType = region:GetObjectType()
                    if objType == "MaskTexture" then
                        slot.__KUIHidden[#slot.__KUIHidden + 1] = region
                    elseif objType == "Texture" then
                        local ok, rawLayer = pcall(region.GetDrawLayer, region)
                        if ok and rawLayer ~= nil then
                            local okB, isBorder  = pcall(safeEq, rawLayer, "BORDER")
                            local okO, isOverlay = pcall(safeEq, rawLayer, "OVERLAY")
                            local okA, isArtwork = pcall(safeEq, rawLayer, "ARTWORK")
                            local okG, isBG      = pcall(safeEq, rawLayer, "BACKGROUND")
                            if (okB and isBorder) or (okO and isOverlay) then
                                slot.__KUIHidden[#slot.__KUIHidden + 1] = region
                            elseif not slot.__KUIIcon and ((okA and isArtwork) or (okG and isBG)) then
                                slot.__KUIIcon = region
                            end
                        end
                    end
                end
            end

            local _children = { slot:GetChildren() }
            for ci, child in ipairs(_children) do
                if child and child.GetObjectType then
                    local objType = child:GetObjectType()
                    if objType == "MaskTexture" then
                        slot.__KUIHidden[#slot.__KUIHidden + 1] = child
                    elseif objType == "Cooldown" then
                        slot.__KUICooldown = child
                        local _children = { child:GetChildren() }
                        for k, cdChild in ipairs(_children) do
                            if cdChild and cdChild.GetObjectType and cdChild:GetObjectType() == "MaskTexture" then
                                slot.__KUIHidden[#slot.__KUIHidden + 1] = cdChild
                            end
                        end
                        for k = 1, child:GetNumRegions() do
                            local cdRegion = select(k, child:GetRegions())
                            if cdRegion and cdRegion.GetObjectType and cdRegion:GetObjectType() == "MaskTexture" then
                                slot.__KUIHidden[#slot.__KUIHidden + 1] = cdRegion
                            end
                        end
                    end
                end
            end
            slot.__KUIScanned = true
        end

        local iconSize = slot.__KUIIcon and slot.__KUIIcon:GetWidth() or slot:GetWidth() or 35
        local edgeSize = iconSize < 35 and 2 or 1

        local border = CreateFrame("Frame", nil, slot, "BackdropTemplate")
        if slot.__KUIIcon then border:SetAllPoints(slot.__KUIIcon) else border:SetAllPoints() end
        border:SetFrameLevel(slot:GetFrameLevel() + 5)
        cdmBorderBackdrop.edgeSize = edgeSize
        border:SetBackdrop(cdmBorderBackdrop)
        border:SetBackdropBorderColor(0, 0, 0, 1)

        cdmBorderFrames[slot] = border
        slot.__KUIShapeBorderFrame = border
        return border
    end

    local CDM_ROOT_NAMES = {
        "BuffIconCooldownViewer", "BuffBarCooldownViewer",
        "EssentialCooldownViewer", "UtilityCooldownViewer",
    }

    local function UpdateUtilityScale()
        local utility = rawget(_G, "UtilityCooldownViewer")
        if utility and KUI_CDM.db then
            utility:SetScale(KUI_CDM.db.profile.utilityScale or 1.0)
        end
    end

    local function UpdateBuffBarScale()
        local buffBar = rawget(_G, "BuffIconCooldownViewer")
        if buffBar and KUI_CDM.db then
            buffBar:SetScale(KUI_CDM.db.profile.buffBarScale or 1.0)
        end
    end

    local function UpdateCooldownBarScale()
        local cdBar = rawget(_G, "EssentialCooldownViewer")
        if cdBar and KUI_CDM.db then
            cdBar:SetScale(KUI_CDM.db.profile.cooldownBarScale or 1.0)
        end
    end

    local function UpdateAllCDMBorders()
        local reskin = KUI_CDM.db and KUI_CDM.db.profile.reskinBorders
        local crop = 0.06

        UpdateUtilityScale()
        UpdateBuffBarScale()
        UpdateCooldownBarScale()

        for _, rootName in ipairs(CDM_ROOT_NAMES) do
            local root = _G[rootName]
            if root then
                for _, slot in ipairs(GetAllCDMSlots(root)) do
                    local border = GetOrCreateCDMBorder(slot)
                    local hasCustomShape = slot._shapeApplied and slot._shapeName and slot._shapeName ~= 'none'
                    if reskin then
                        if hasCustomShape then border:Hide() else border:Show() end
                        if slot.__KUIIcon then slot.__KUIIcon:SetTexCoord(crop, 1 - crop, crop, 1 - crop) end
                        if slot.__KUICooldown then
                            slot.__KUICooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8x8")
                        end
                        for _, h in ipairs(slot.__KUIHidden) do
                            if h and h.Hide then h:Hide() end
                        end
                    else
                        border:Hide()
                        if slot.__KUIIcon then slot.__KUIIcon:SetTexCoord(0, 1, 0, 1) end
                        if slot.__KUICooldown then
                            slot.__KUICooldown:SetSwipeTexture("Interface\\Cooldown\\cooldown-bling")
                        end
                        for _, h in ipairs(slot.__KUIHidden) do
                            if h and h.Show then h:Show() end
                        end
                    end
                end
            end
        end
    end

    ns.GetActionButton = GetActionButton
    ns.GetSortedSlots = GetSortedSlots
    ns.GetTargetButton = GetTargetButton
    ns.UpdateAllCDMBorders = UpdateAllCDMBorders
end

-------------------------------------------------------------------------------
-- Glow system helpers
--  lib.ShowOverlayGlow(frame) / lib.HideOverlayGlow(frame) operan sobre
-- Keep glow on the icon frame respecting shape and size
-------------------------------------------------------------------------------
-- NOTE: `code` is the legacy numeric style consumed by StartNativeGlow.
local GLOW_STYLES = {
    { id = "blizzard", name = "Proc Glow (WoW)",     code = 6 }, -- sparkle dorado (SpellActivationOverlay)
    { id = "autocast", name = "AutoCast Shine",      code = 1 }, -- rotating dots
    { id = "pixel",    name = "Pixel Border",        code = 2 }, -- animated pixel border
    { id = "button",   name = "Action Button Glow",  code = 4 }, -- modern button glow (if available)
    { id = "none",     name = "Sin Glow",            code = 0 },
}
ns.GLOW_STYLES = GLOW_STYLES

-- Glow System: LibButtonGlow-1.0 = el proc glow dorado de WoW (NO el AutoCast Shine).
-- AutoCast Shine = los puntos girando (AutoCastShine_AutoCastStart) - DIFERENTE.
-- LibButtonGlow = el efecto de sparkle+ants que sale cuando un proc se activa.
local _LBG = LibStub and LibStub("LibButtonGlow-1.0", true)

-- Keep a glow immediately above its own button. A global TOOLTIP strata made
-- CDM effects draw over Blizzard loot, Talking Head and other dialog frames.
local function ApplyCDMGlowLayer(glow, owner, levelOffset)
    if not glow then return end
    owner = owner or (glow.GetParent and glow:GetParent()) or glow
    local strata = owner.GetFrameStrata and owner:GetFrameStrata() or "MEDIUM"
    local level = owner.GetFrameLevel and owner:GetFrameLevel() or 0
    pcall(glow.SetFrameStrata, glow, strata)
    pcall(glow.SetFrameLevel, glow, level + (levelOffset or 1))
end

local function RaiseCDMGlowLayers(frame)
    if not frame then return end
    if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        return
    end
    local parent = frame.GetParent and frame:GetParent()
    local isGlowContainer = parent and (
        frame._kuiUseSelfGlowTarget
        or parent._glowOverlay == frame
        or parent._customModuleGlowOverlay == frame
        or parent._kuiProcGlow == frame
        or parent._kuiPixelBorderGlow == frame
        or parent._ktAutoCastGlow == frame
    )
    local owner = isGlowContainer and parent or frame
    if isGlowContainer then
        ApplyCDMGlowLayer(frame, owner, 3)
    end
    local child = frame.overlay
    if child then
        ApplyCDMGlowLayer(child, owner, 4)
    end
    child = frame.__LBGoverlay
    if child then
        ApplyCDMGlowLayer(child, owner, 4)
    end
    child = frame._kuiProcGlow
    if child then
        ApplyCDMGlowLayer(child, owner, 4)
    end
    child = frame._kuiPixelBorderGlow
    if child then
        ApplyCDMGlowLayer(child, owner, 4)
    end
    child = frame._ktAutoCastGlow
    if child then
        ApplyCDMGlowLayer(child, owner, 4)
    end
end

function ns.CDMHasNamedGlowSupport(style)
    local normalized = ns.CDMNormalizeNamedGlowStyle and ns.CDMNormalizeNamedGlowStyle(style) or style
    -- KUI supplies native fallbacks for every named style.  Do not report a
    -- style as unsupported merely because LibButtonGlow is absent/broken: that
    -- silently remapped the user's selection before StartNativeGlow could use
    -- the KUI implementation.
    if normalized == "shape" or normalized == "pixel" or normalized == "autocast"
        or normalized == "button" or normalized == "blizzard" or normalized == "none" then
        return true
    end
    return true
end

-- Color del glow por school mask de spell (para debuffs de diferente color)
local SCHOOL_COLORS = {
    [1]  = { r = 1, g = 1, b = 1 },     -- Physical
    [2]  = { r = 1, g = 0.9, b = 0.5 }, -- Holy
    [4]  = { r = 1, g = 0.3, b = 0.1 }, -- Fire (Sunfire/Fuego Solar)
    [8]  = { r = 0.3, g = 1, b = 0.3 }, -- Nature
    [16] = { r = 0.5, g = 0.8, b = 1 }, -- Frost
    [32] = { r = 0.7, g = 0.3, b = 1 }, -- Shadow (Moonfire/Fuego Lunar)
    [64] = { r = 0.9, g = 0.4, b = 1 }, -- Arcane
}

local function GetSpellGlowColor(spellID, baseCr, baseCg, baseCb)
    if baseCr ~= nil and baseCg ~= nil and baseCb ~= nil then
        return baseCr, baseCg, baseCb
    end
    if not spellID then return baseCr, baseCg, baseCb end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    local schoolMask = ok and info and rawget(info, "schoolMask") or nil
    if schoolMask then
        local c = SCHOOL_COLORS[schoolMask]
        if c then return c.r, c.g, c.b end
        -- Mask compuesto: buscar el bit dominante
        for mask = 64, 1, -1 do
            if bit.band(schoolMask, mask) > 0 then
                local cc = SCHOOL_COLORS[mask]
                if cc then return cc.r, cc.g, cc.b end
            end
        end
    end
    return baseCr or 1, baseCg or 0.82, baseCb or 0.1
end

function ns.CDMGetKTGlowAPI()
    local kt = KT or ns.KT or rawget(_G, "KT")
    if kt and type(kt.Glows) == "table" then
        return kt.Glows
    end
end

function ns.CDMNormalizeNamedGlowStyle(style)
    if type(style) ~= "string" then return nil end
    local s = style:lower()
    if s == "none" then return "none" end
    if s == "shape" then return "shape" end
    if s == "autocast" then return "autocast" end
    if s == "pixel" then return "pixel" end
    if s == "button" then return "button" end
    if s == "blizzard" or s == "proc" then return "blizzard" end
    return nil
end

function ns.CDMTintGlowTexture(tex, r, g, b, a)
    if type(r) == "table" then
        a = g
        g = r.g
        b = r.b
        r = r.r
    end
    if r == nil then r = 1 end
    if g == nil then g = 0.82 end
    if b == nil then b = 0.1 end
    if tex and tex.SetVertexColor then
        tex:SetVertexColor(r, g, b, a or 1)
        return true
    end
    return false
end

function ns.CDMTintGlowFrame(frame, r, g, b, a)
    if not frame then
        return false
    end

    local tinted = false
    local knownTextures = {
        "innerGlow",
        "innerGlowOver",
        "outerGlow",
        "outerGlowOver",
        "ants",
        "shine",
        "sparkle",
        "burst",
        "ProcStart",
        "ProcLoop",
    }

    for i = 1, #knownTextures do
        if ns.CDMTintGlowTexture(frame[knownTextures[i]], r, g, b, a) then
            tinted = true
        end
    end

    return tinted
end

function ns.CDMApplyGlowColor(target, r, g, b, a)
    if not target then
        return false
    end
    RaiseCDMGlowLayers(target)

    local tinted = false
    local glowFrames = {
        target.__LBGoverlay,
        target.overlay,
        target.SpellActivationAlert,
        target.spellActivationAlert,
        target.AutoCastShine,
        target.autoCastShine,
        target._kuiProcGlow,
    }

    for i = 1, #glowFrames do
        if ns.CDMTintGlowFrame(glowFrames[i], r, g, b, a) then
            tinted = true
        end
    end

    if target._glowTex and ns.CDMTintGlowTexture(target._glowTex, r, g, b, a) then
        tinted = true
    end

    return tinted
end

function ns.CDMScheduleGlowColorRefresh(target, r, g, b, a)
    if not (target and C_Timer and C_Timer.After) then
        return
    end

    C_Timer.After(0, function()
        if target then
            ns.CDMApplyGlowColor(target, r, g, b, a)
        end
    end)

    C_Timer.After(0.05, function()
        if target then
            ns.CDMApplyGlowColor(target, r, g, b, a)
        end
    end)
end

function ns.CDMSoftenLegacyGlow(target)
    if not target or not target.__LBGoverlay then
        return
    end

    local overlay = target.__LBGoverlay
    if overlay.animIn and overlay.animIn.IsPlaying and overlay.animIn:IsPlaying() then
        overlay.animIn:Stop()
    end

    local width = overlay:GetWidth() or target:GetWidth() or 0
    local height = overlay:GetHeight() or target:GetHeight() or 0

    if overlay.spark then overlay.spark:SetAlpha(0) end
    if overlay.innerGlow then
        overlay.innerGlow:SetAlpha(0)
        if width > 0 and height > 0 then
            overlay.innerGlow:SetSize(width, height)
        end
    end
    if overlay.innerGlowOver then overlay.innerGlowOver:SetAlpha(0) end
    if overlay.outerGlow then
        overlay.outerGlow:SetAlpha(0.95)
        if width > 0 and height > 0 then
            overlay.outerGlow:SetSize(width, height)
        end
    end
    if overlay.outerGlowOver then
        overlay.outerGlowOver:SetAlpha(0)
        if width > 0 and height > 0 then
            overlay.outerGlowOver:SetSize(width, height)
        end
    end
    if overlay.ants then overlay.ants:SetAlpha(0) end
end

function ns.CDMEnsureProcGlowFrame(target)
    if not target then
        return nil
    end

    local frame = target._kuiProcGlow
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", nil, target)
    target._kuiProcGlow = frame

    frame.ProcStart = frame:CreateTexture(nil, "ARTWORK")
    frame.ProcStart:SetBlendMode("ADD")
    frame.ProcStart:SetAtlas("UI-HUD-ActionBar-Proc-Start-Flipbook")
    frame.ProcStart:SetAlpha(1)
    frame.ProcStart:SetSize(150, 150)
    frame.ProcStart:SetPoint("CENTER")

    frame.ProcLoop = frame:CreateTexture(nil, "ARTWORK")
    frame.ProcLoop:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
    frame.ProcLoop:SetAlpha(0)
    frame.ProcLoop:SetAllPoints()

    frame.ProcLoopAnim = frame:CreateAnimationGroup()
    frame.ProcLoopAnim:SetLooping("REPEAT")
    frame.ProcLoopAnim:SetToFinalAlpha(true)

    local alphaRepeat = frame.ProcLoopAnim:CreateAnimation("Alpha")
    alphaRepeat:SetChildKey("ProcLoop")
    alphaRepeat:SetDuration(0.001)
    alphaRepeat:SetOrder(0)
    alphaRepeat:SetFromAlpha(1)
    alphaRepeat:SetToAlpha(1)

    local flipbookRepeat = frame.ProcLoopAnim:CreateAnimation("FlipBook")
    flipbookRepeat:SetChildKey("ProcLoop")
    flipbookRepeat:SetDuration(1)
    flipbookRepeat:SetOrder(0)
    flipbookRepeat:SetFlipBookRows(6)
    flipbookRepeat:SetFlipBookColumns(5)
    flipbookRepeat:SetFlipBookFrames(30)
    flipbookRepeat:SetFlipBookFrameWidth(0)
    flipbookRepeat:SetFlipBookFrameHeight(0)
    frame.ProcLoopAnim.flipbookRepeat = flipbookRepeat

    frame.ProcStartAnim = frame:CreateAnimationGroup()
    frame.ProcStartAnim:SetToFinalAlpha(true)

    local flipbookStartAlphaIn = frame.ProcStartAnim:CreateAnimation("Alpha")
    flipbookStartAlphaIn:SetChildKey("ProcStart")
    flipbookStartAlphaIn:SetDuration(0.001)
    flipbookStartAlphaIn:SetOrder(0)
    flipbookStartAlphaIn:SetFromAlpha(1)
    flipbookStartAlphaIn:SetToAlpha(1)

    local flipbookStart = frame.ProcStartAnim:CreateAnimation("FlipBook")
    flipbookStart:SetChildKey("ProcStart")
    flipbookStart:SetDuration(0.7)
    flipbookStart:SetOrder(1)
    flipbookStart:SetFlipBookRows(6)
    flipbookStart:SetFlipBookColumns(5)
    flipbookStart:SetFlipBookFrames(30)
    flipbookStart:SetFlipBookFrameWidth(0)
    flipbookStart:SetFlipBookFrameHeight(0)

    local flipbookStartAlphaOut = frame.ProcStartAnim:CreateAnimation("Alpha")
    flipbookStartAlphaOut:SetChildKey("ProcStart")
    flipbookStartAlphaOut:SetDuration(0.001)
    flipbookStartAlphaOut:SetOrder(2)
    flipbookStartAlphaOut:SetFromAlpha(1)
    flipbookStartAlphaOut:SetToAlpha(0)

    frame.ProcStartAnim:SetScript("OnFinished", function(self)
        local owner = self:GetParent()
        if owner and owner.ProcLoop then
            owner.ProcLoop:Show()
        end
        if owner and owner.ProcLoopAnim then
            owner.ProcLoopAnim:Play()
        end
    end)

    frame:SetScript("OnShow", function(self)
        if self._kuiProcStartAnim then
            if not self.ProcStartAnim:IsPlaying() and not self.ProcLoopAnim:IsPlaying() then
                local width, height = self:GetSize()
                self.ProcStart:SetSize((width / 42 * 150) / 1.4, (height / 42 * 150) / 1.4)
                self.ProcStart:Show()
                self.ProcStart:SetAlpha(1)
                self.ProcLoop:Hide()
                self.ProcLoop:SetAlpha(0)
                self.ProcStartAnim:Play()
            end
        else
            if not self.ProcLoopAnim:IsPlaying() then
                self.ProcStart:Hide()
                self.ProcLoop:Show()
                self.ProcLoop:SetAlpha(1)
                self.ProcLoopAnim:Play()
            end
        end
    end)

    frame:SetScript("OnHide", function(self)
        if self.ProcStartAnim and self.ProcStartAnim.IsPlaying and self.ProcStartAnim:IsPlaying() then
            self.ProcStartAnim:Stop()
        end
        if self.ProcLoopAnim and self.ProcLoopAnim.IsPlaying and self.ProcLoopAnim:IsPlaying() then
            self.ProcLoopAnim:Stop()
        end
    end)

    return frame
end

function ns.CDMSetupProcGlow(frame, r, g, b, a, duration, startAnim)
    if not frame then
        return
    end

    local rr = r or 1
    local rg = g or 0.82
    local rb = b or 0.1
    local ra = a or 1

    frame.ProcStart:SetDesaturated(1)
    frame.ProcStart:SetVertexColor(rr, rg, rb, ra)
    frame.ProcLoop:SetDesaturated(1)
    frame.ProcLoop:SetVertexColor(rr, rg, rb, ra)
    frame.ProcLoopAnim.flipbookRepeat:SetDuration(duration or 1)
    frame._kuiProcStartAnim = (startAnim ~= false)
end

function ns.CDMStartCustomProcGlow(target, r, g, b)
    local frame = ns.CDMEnsureProcGlowFrame(target)
    if not frame then
        ns.CDMStartFallbackOverlayGlow(target, r, g, b)
        return
    end

    local width = target:GetWidth() or 42
    local height = target:GetHeight() or width
    local xOffset = width * 0.2
    local yOffset = height * 0.2

    frame:ClearAllPoints()
    frame:SetParent(target)
    ApplyCDMGlowLayer(frame, target, 3)
    frame:SetPoint("TOPLEFT", target, "TOPLEFT", -xOffset, yOffset)
    frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", xOffset, -yOffset)

    -- Clip proc glow to icon shape if a shape mask exists on the parent icon
    local shapeMask = target:GetParent() and target:GetParent()._shapeMask
    if shapeMask ~= frame._kuiShapeMask then
        if frame._kuiShapeMask then
            pcall(frame.ProcStart.RemoveMaskTexture, frame.ProcStart, frame._kuiShapeMask)
            pcall(frame.ProcLoop.RemoveMaskTexture, frame.ProcLoop, frame._kuiShapeMask)
        end
        if shapeMask then
            pcall(frame.ProcStart.AddMaskTexture, frame.ProcStart, shapeMask)
            pcall(frame.ProcLoop.AddMaskTexture, frame.ProcLoop, shapeMask)
        end
        frame._kuiShapeMask = shapeMask
    end

    ns.CDMSetupProcGlow(frame, r, g, b, 1, 1, false)

    if frame.ProcStartAnim:IsPlaying() then
        frame.ProcStartAnim:Stop()
    end
    if frame.ProcLoopAnim:IsPlaying() then
        frame.ProcLoopAnim:Stop()
    end

    frame:Hide()
    frame:Show()
    target._kuiCustomProcGlowActive = true
    RaiseCDMGlowLayers(frame)
end

function ns.CDMStopCustomProcGlow(target)
    local frame = target and target._kuiProcGlow
    if not frame then
        return
    end

    if frame.ProcStartAnim and frame.ProcStartAnim.IsPlaying and frame.ProcStartAnim:IsPlaying() then
        frame.ProcStartAnim:Stop()
    end
    if frame.ProcLoopAnim and frame.ProcLoopAnim.IsPlaying and frame.ProcLoopAnim:IsPlaying() then
        frame.ProcLoopAnim:Stop()
    end
    frame:Hide()
    if target then
        target._kuiCustomProcGlowActive = false
    end
end

function ns.CDMGetGlowCandidateIdentifiers(icon)
    local ids = {}
    local seen = {}

    local function AddIdentifier(identifier)
        if type(identifier) ~= "number"
            or (issecretvalue and issecretvalue(identifier))
            or identifier <= 0 then return end
        local pending, read = { identifier }, 1
        while read <= #pending do
            local id = pending[read]
            read = read + 1
            if type(id) == "number" and not (issecretvalue and issecretvalue(id)) and id > 0 and not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
                if ns.ApplyBuffSpellCorrection then
                    local corrected = ns.ApplyBuffSpellCorrection(id)
                    if type(corrected) == "number" and corrected > 0 and not seen[corrected] then pending[#pending + 1] = corrected end
                end
                if C_Spell then
                    if C_Spell.GetBaseSpell then
                        local ok, base = pcall(C_Spell.GetBaseSpell, id)
                        if ok and type(base) == "number" and base > 0 and not seen[base] then pending[#pending + 1] = base end
                    end
                    if C_Spell.GetOverrideSpell then
                        local ok, override = pcall(C_Spell.GetOverrideSpell, id)
                        if ok and type(override) == "number" and override > 0 and not seen[override] then pending[#pending + 1] = override end
                    end
                end
            end
        end
    end

    if icon then
        AddIdentifier(icon._baseSpellID)
        AddIdentifier(icon._spellID)
        AddIdentifier(icon._actionSpellID)
        if icon._glowOverlay then
            AddIdentifier(icon._glowOverlay._baseSpellID)
            AddIdentifier(icon._glowOverlay._spellID)
            AddIdentifier(icon._glowOverlay._actionSpellID)
        end
    end

    return ids
end

function ns.CDMGetTrackedGlowDebugIdentifier(icon)
    local bg = ns.GetBarGlows and ns.GetBarGlows()
    local selectedIdentifier = bg and bg.selectedSpellIdentifier
    local ids = ns.CDMGetGlowCandidateIdentifiers(icon)

    if type(selectedIdentifier) == "number" then
        for i = 1, #ids do
            if ids[i] == selectedIdentifier then
                return selectedIdentifier
            end
        end
    end

    if ns.GetBarGlowSpellOverride then
        for i = 1, #ids do
            local identifier = ids[i]
            if ns.GetBarGlowSpellOverride(identifier, false) then
                return identifier
            end
        end
    end

    return nil
end

ns._cdmGlowDebugEnabled = ns._cdmGlowDebugEnabled == true

function ns.CDMGlowDebugPrint(icon, ...)
    -- Glow tracing is extremely chatty in combat. Keeping it permanently on
    -- generated thousands of strings and periodically shifted 500 entries out
    -- of the log one by one, causing the recurring profiler spikes.
    if not ns._cdmGlowDebugEnabled then return end

    if type(_G.KUI_CDM_DebugLog) ~= "table" then
        _G.KUI_CDM_DebugLog = {}
    end
    local label = icon and (icon._spellID or icon._baseSpellID or (icon.GetName and icon:GetName()) or "?") or "?"
    local parts = { "|cff66ccff[Glow]|r " .. tostring(label) }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    local line = table.concat(parts, " ")
    local log = _G.KUI_CDM_DebugLog
    log[#log + 1] = line
    if #log > 1500 then
        -- Rebuild the retained tail once instead of performing 500 O(n)
        -- front-removal shifts on the gameplay thread.
        local compacted = {}
        local first = math.max(1, #log - 999)
        for i = first, #log do
            compacted[#compacted + 1] = log[i]
        end
        _G.KUI_CDM_DebugLog = compacted
    end
end

function ns.CDMResolveExplicitBarGlowOverride(icon, useProcStyle)
    local bg = ns.GetBarGlows and ns.GetBarGlows()
    if not bg or bg.enabled == false or not ns.GetBarGlowSpellOverride then
        return nil
    end

    local identifiers = ns.CDMGetGlowCandidateIdentifiers(icon)
    for i = 1, #identifiers do
        local identifier = identifiers[i]
        local spellOverride = ns.GetBarGlowSpellOverride(identifier, false)
        if spellOverride then
            local style = ns.ResolveBarGlowStyleForTarget
                and ns.ResolveBarGlowStyleForTarget(identifier, nil, bg, useProcStyle)
            local r, g, b = nil, nil, nil
            if ns.ResolveBarGlowColorForTarget then
                r, g, b = ns.ResolveBarGlowColorForTarget(identifier, nil, bg)
            end
            return style, r, g, b, identifier
        end
    end

    return nil
end

local function GetProcGlowStyleAndColor(icon, fallbackR, fallbackG, fallbackB)
    local explicitStyle, explicitR, explicitG, explicitB, explicitIdentifier = ns.CDMResolveExplicitBarGlowOverride(icon, true)
    if explicitStyle ~= nil then
        ns.CDMGlowDebugPrint(
            icon,
            "proc override",
            "identifier=" .. tostring(explicitIdentifier),
            "style=" .. tostring(explicitStyle),
            string.format("rgb=%.3f/%.3f/%.3f", explicitR or 1, explicitG or 0.82, explicitB or 0.1)
        )
        return explicitStyle, explicitR, explicitG, explicitB
    end

    local style = ns.CDMGetConfiguredProcGlowStyle and ns.CDMGetConfiguredProcGlowStyle() or "blizzard"
    local r, g, b = fallbackR, fallbackG, fallbackB
    local identifier = icon and (icon._baseSpellID or icon._spellID)
    local bg = ns.GetBarGlows and ns.GetBarGlows()

    if bg and bg.enabled ~= false and identifier then
        if ns.ResolveBarGlowStyleForTarget then
            style = ns.ResolveBarGlowStyleForTarget(identifier, nil, bg, true) or style
        end
        if ns.ResolveBarGlowColorForTarget then
            local rr, rg, rb = ns.ResolveBarGlowColorForTarget(identifier, nil, bg)
            if rr ~= nil and rg ~= nil and rb ~= nil then
                r, g, b = rr, rg, rb
            end
        end
    end

    ns.CDMGlowDebugPrint(
        icon,
        "proc resolved",
        "identifier=" .. tostring(identifier),
        "style=" .. tostring(style),
        string.format("rgb=%.3f/%.3f/%.3f", r or 1, g or 0.82, b or 0.1)
    )
    return style, r, g, b
end

function ns.CDMStartFallbackOverlayGlow(target, r, g, b)
    if _G.ActionButton_ShowOverlayGlow then
        _G.ActionButton_ShowOverlayGlow(target)
        target._kuiActionButtonGlowActive = true
        ns.CDMApplyGlowColor(target, r, g, b, 1)
        ns.CDMScheduleGlowColorRefresh(target, r, g, b, 1)
        return
    end

    if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.ShowAlert then
        ActionButtonSpellAlertManager:ShowAlert(target)
        target._kuiVanillaGlowActive = true
        ns.CDMApplyGlowColor(target, r, g, b, 1)
        ns.CDMScheduleGlowColorRefresh(target, r, g, b, 1)
        return
    end

    if _LBG and _LBG.ShowOverlayGlow then
        _LBG.ShowOverlayGlow(target)
        target._lbgActive = true
        ns.CDMApplyGlowColor(target, r, g, b, 1)
        ns.CDMScheduleGlowColorRefresh(target, r, g, b, 1)
        return
    end

    if not target._glowTex then
        target._glowTex = target:CreateTexture(nil, "OVERLAY", nil, 7)
        target._glowTex:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
        target._glowTex:SetBlendMode("ADD")
        target._glowTex:SetTexCoord(0, 0.5, 0, 0.5)
    end
    -- Clip fallback glow to icon shape if a shape mask exists on the parent icon
    local fallbackMask = target:GetParent() and target:GetParent()._shapeMask
    if fallbackMask ~= target._glowTexMask then
        if target._glowTexMask then pcall(target._glowTex.RemoveMaskTexture, target._glowTex, target._glowTexMask) end
        if fallbackMask then pcall(target._glowTex.AddMaskTexture, target._glowTex, fallbackMask) end
        target._glowTexMask = fallbackMask
    end
    local sz = target:GetWidth() or 42
    if sz < 4 then sz = 42 end
    local tex = target._glowTex
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", target, "CENTER", 0, 0)
    tex:SetSize(sz * 1.6, sz * 1.6)
    tex:SetVertexColor(r, g, b)
    tex:SetAlpha(0.90)
    tex:Show()
    ns.CDMApplyGlowColor(target, r, g, b, 1)
    ns.CDMScheduleGlowColorRefresh(target, r, g, b, 1)
end

function ns.CDMStartPixelBorderGlow(target, r, g, b)
    if not target then return end
    local glow = target._kuiPixelBorderGlow
    if not glow then
        glow = CreateFrame("Frame", nil, target)
        glow:SetPoint("TOPLEFT", target, "TOPLEFT", -2, 2)
        glow:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 2, -2)
        ApplyCDMGlowLayer(glow, target, 2)
        glow:EnableMouse(false)
        glow.edges = {}
        for index = 1, 4 do
            glow.edges[index] = glow:CreateTexture(nil, "OVERLAY", nil, 20)
            glow.edges[index]:SetTexture("Interface\\Buttons\\WHITE8x8")
            glow.edges[index]:SetBlendMode("ADD")
        end
        glow.edges[1]:SetPoint("TOPLEFT"); glow.edges[1]:SetPoint("TOPRIGHT"); glow.edges[1]:SetHeight(2)
        glow.edges[2]:SetPoint("BOTTOMLEFT"); glow.edges[2]:SetPoint("BOTTOMRIGHT"); glow.edges[2]:SetHeight(2)
        glow.edges[3]:SetPoint("TOPLEFT"); glow.edges[3]:SetPoint("BOTTOMLEFT"); glow.edges[3]:SetWidth(2)
        glow.edges[4]:SetPoint("TOPRIGHT"); glow.edges[4]:SetPoint("BOTTOMRIGHT"); glow.edges[4]:SetWidth(2)
        glow.pulse = glow:CreateAnimationGroup()
        glow.pulse:SetLooping("REPEAT")
        local fadeOut = glow.pulse:CreateAnimation("Alpha")
        fadeOut:SetOrder(1); fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0.35); fadeOut:SetDuration(0.35)
        local fadeIn = glow.pulse:CreateAnimation("Alpha")
        fadeIn:SetOrder(2); fadeIn:SetFromAlpha(0.35); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.35)
        target._kuiPixelBorderGlow = glow
    end
    ApplyCDMGlowLayer(glow, target, 2)
    for _, edge in ipairs(glow.edges) do edge:SetVertexColor(r or 1, g or 0.82, b or 0.1, 1) end
    glow:Show()
    if not glow.pulse:IsPlaying() then glow.pulse:Play() end
    target._kuiPixelBorderGlowActive = true
end

function ns.CDMStopPixelBorderGlow(target)
    local glow = target and target._kuiPixelBorderGlow
    if not glow then return end
    if glow.pulse and glow.pulse:IsPlaying() then glow.pulse:Stop() end
    glow:Hide()
    target._kuiPixelBorderGlowActive = false
end

local function _StopAllGlowsOnOverlay(target)
    if not target then return end
    if target._kuiShapeGlowActive then
        local icon = target._kuiShapeGlowIcon
        local ov = icon and icon._shapeGlowBorder
        if ov and ov._kuiPulse and ov._kuiPulse.Stop then
            ov._kuiPulse:Stop()
        end
        if ov then ov:Hide() end
        target._kuiShapeGlowActive = false
        target._kuiShapeGlowIcon = nil
    end
    if target._kuiCustomProcGlowActive then
        ns.CDMStopCustomProcGlow(target)
    end
    if target._kuiPixelBorderGlowActive then
        ns.CDMStopPixelBorderGlow(target)
    end
    local glowAPI = ns.CDMGetKTGlowAPI and ns.CDMGetKTGlowAPI()
    if glowAPI then
        if glowAPI.StopProceduralAnts then glowAPI.StopProceduralAnts(target) end
        if glowAPI.StopAutoCastShine then glowAPI.StopAutoCastShine(target) end
        if glowAPI.StopButtonGlow then glowAPI.StopButtonGlow(target) end
    end
    if target._kuiActionButtonGlowActive and _G.ActionButton_HideOverlayGlow then
        _G.ActionButton_HideOverlayGlow(target)
        target._kuiActionButtonGlowActive = false
    end
    if target._kuiVanillaGlowActive and ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.HideAlert then
        ActionButtonSpellAlertManager:HideAlert(target)
        target._kuiVanillaGlowActive = false
    end
    if target._lbgActive and _LBG then
        if _LBG.HideOverlayGlow then _LBG.HideOverlayGlow(target) end
        if _LBG.PixelGlow_Stop then _LBG.PixelGlow_Stop(target) end
        if _LBG.AutoCastGlow_Stop then _LBG.AutoCastGlow_Stop(target) end
        if _LBG.ButtonGlow_Stop then _LBG.ButtonGlow_Stop(target) end
        target._lbgActive = false
    end
    -- Limpiar textura legacy si queda
    if target._glowTex then target._glowTex:Hide() end
end

function ns.CDMEnsureShapeGlowOverlay(icon)
    if not icon then return nil end
    if icon._shapeGlowBorder then return icon._shapeGlowBorder end
    local holder = icon._shapeBorderFrame or icon
    if not holder or not holder.CreateTexture then return nil end
    local tex = holder:CreateTexture(nil, "OVERLAY", nil, 20)
    if holder ~= icon then ApplyCDMGlowLayer(holder, icon, 2) end
    tex:Hide()
    tex:SetBlendMode("ADD")
    tex:SetAllPoints(icon)
    local pulse = tex:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")
    local up = pulse:CreateAnimation("Alpha")
    up:SetOrder(1)
    up:SetFromAlpha(0.25)
    up:SetToAlpha(1.0)
    up:SetDuration(0.35)
    local down = pulse:CreateAnimation("Alpha")
    down:SetOrder(2)
    down:SetFromAlpha(1.0)
    down:SetToAlpha(0.35)
    down:SetDuration(0.35)
    tex._kuiPulse = pulse
    icon._shapeGlowBorder = tex
    return tex
end

function ns.CDMStartShapeGlow(target, r, g, b)
    if not target then return false end
    local icon = target
    if not icon._shapeApplied then
        -- Walk __KUIIcon / _icon shortcuts first
        icon = target.__KUIIcon or target._icon or icon
        if not icon._shapeApplied and target.GetParent then
            local parent = target:GetParent()
            if parent then
                if parent._shapeApplied then
                    icon = parent
                else
                    -- Try parent's icon shortcuts
                    local pIcon = parent.__KUIIcon or parent._icon
                    if pIcon and pIcon._shapeApplied then
                        icon = pIcon
                    elseif parent.GetParent then
                        -- Go one more level up
                        local grandParent = parent:GetParent()
                        if grandParent then
                            local gIcon = grandParent.__KUIIcon or grandParent._icon
                            if gIcon and gIcon._shapeApplied then
                                icon = gIcon
                            elseif grandParent._shapeApplied then
                                icon = grandParent
                            end
                        end
                    end
                end
            end
        end
    end
    if not icon or not icon._shapeApplied or not icon._shapeName then return false end
    local borderPath = CDM_SHAPES.borders and CDM_SHAPES.borders[icon._shapeName]
    if not borderPath then return false end
    local tex = ns.CDMEnsureShapeGlowOverlay(icon)
    if not tex then return false end
    tex:SetTexture(borderPath)
    tex:SetVertexColor(r or 1, g or 0.82, b or 0.1, 1)
    tex:Show()
    if tex._kuiPulse and not tex._kuiPulse:IsPlaying() then
        tex._kuiPulse:Play()
    end
    target._kuiShapeGlowActive = true
    target._kuiShapeGlowIcon = icon
    return true
end

StartNativeGlow = function(icon, style, cr, cg, cb)
    if not icon then return end
    -- For CDM icons, icon = icon._glowOverlay, parent = icon
    -- For overlays in BarGlows, icon = KUI_GlowV2_xxx, parent = ActionButton
    local parent = icon:GetParent()
    local target = parent or icon
    local iconName = icon.GetName and icon:GetName()
    if icon._kuiUseSelfGlowTarget or (iconName and iconName:find("^KUI_Glow")) then
        -- Never touch the real action button's SpellActivationAlert / proc glow
        target = icon
    end

    _StopAllGlowsOnOverlay(target)

    -- Obtener color por school si no se especifica
    local spellID = icon._spellID or (parent and parent._spellID)
    local r, g, b = GetSpellGlowColor(spellID, cr, cg, cb)
    local namedStyle = ns.CDMNormalizeNamedGlowStyle and ns.CDMNormalizeNamedGlowStyle(style)
    local s = tonumber(style) or 1

    ns.CDMGlowDebugPrint(
        parent or icon,
        "start native",
        "source=" .. tostring(icon._kuiGlowSource or target._kuiGlowSource or "?"),
        "target=" .. tostring((target.GetName and target:GetName()) or target),
        "style=" .. tostring(namedStyle or s),
        string.format("rgb=%.3f/%.3f/%.3f", r or 1, g or 0.82, b or 0.1)
    )

    if namedStyle then
        local glowAPI = ns.CDMGetKTGlowAPI and ns.CDMGetKTGlowAPI()
        local glowSize = math.max(target:GetWidth() or 0, target:GetHeight() or 0, 26)
        if namedStyle == "shape" then
            if not ns.CDMStartShapeGlow(target, r, g, b) then
                ns.CDMStartFallbackOverlayGlow(target, r, g, b)
            end
        elseif namedStyle == "blizzard" then
            ns.CDMStartCustomProcGlow(target, r, g, b)
        elseif namedStyle == "autocast" then
            if glowAPI and glowAPI.StartAutoCastShine then
                glowAPI.StartAutoCastShine(target, glowSize, r, g, b)
                ns.CDMApplyGlowColor(target, r, g, b, 1)
                ns.CDMScheduleGlowColorRefresh(target, r, g, b, 1)
            else
                ns.CDMStartFallbackOverlayGlow(target, r, g, b)
            end
        elseif namedStyle == "pixel" then
            ns.CDMStartPixelBorderGlow(target, r, g, b)
        elseif namedStyle == "button" then
            ns.CDMStartFallbackOverlayGlow(target, r, g, b)
        elseif namedStyle ~= "none" then
            ns.CDMStartFallbackOverlayGlow(target, r, g, b)
        end
        RaiseCDMGlowLayers(target)
    elseif _LBG then
        local colorArray = { r, g, b, 1 }
        if s == 1 or s == 3 then
            if _LBG.AutoCastGlow_Start then _LBG.AutoCastGlow_Start(target, colorArray) else _LBG.ShowOverlayGlow(target) end
        elseif s == 2 then
            if _LBG.PixelGlow_Start then _LBG.PixelGlow_Start(target, colorArray) else _LBG.ShowOverlayGlow(target) end
        elseif s == 4 then
            if _LBG.ButtonGlow_Start then _LBG.ButtonGlow_Start(target, colorArray) else _LBG.ShowOverlayGlow(target) end
        elseif s == 6 then
            ns.CDMStartCustomProcGlow(target, r, g, b)
            icon._glowActive = true
            icon._glowStyle = namedStyle or s
            icon:SetAlpha(1)
            return
        else
            ns.CDMStartCustomProcGlow(target, r, g, b)
            icon._glowActive = true
            icon._glowStyle = namedStyle or s
            icon:SetAlpha(1)
            return
        end
        target._lbgActive = true
        ns.CDMApplyGlowColor(target, r, g, b, 1)
        ns.CDMScheduleGlowColorRefresh(target, r, g, b, 1)
    else
        ns.CDMStartCustomProcGlow(target, r, g, b)
    end

    icon._glowActive = true
    icon._glowStyle = namedStyle or s
    icon:SetAlpha(1)
end

StopNativeGlow = function(icon)
    if not icon then return end
    if not icon._glowActive then
        -- Most refresh passes touch inactive overlays. Do not call every glow
        -- backend (or emit a trace line) when KUI owns no active glow here.
        icon:SetAlpha(0)
        return
    end
    local parent = icon:GetParent()
    local target = parent or icon
    local iconName = icon.GetName and icon:GetName()
    if icon._kuiUseSelfGlowTarget or (iconName and iconName:find("^KUI_Glow")) then
        target = icon
    end
    ns.CDMGlowDebugPrint(
        parent or icon,
        "stop native",
        "source=" .. tostring(icon._kuiGlowSource or target._kuiGlowSource or "?"),
        "target=" .. tostring((target.GetName and target:GetName()) or target)
    )
    _StopAllGlowsOnOverlay(target)
    icon._glowActive = false
    icon._glowStyle = nil
    icon:SetAlpha(0)
end
ns.StartNativeGlow = StartNativeGlow
ns.StopNativeGlow = StopNativeGlow

-- Our bar frames (keyed by bar key)
local cdmBarFrames = {}
-- Icon frames per bar (keyed by bar key, array of icon frames)
local cdmBarIcons = {}
-- Metadata exists only for Blizzard-owned CDM item frames.  Keeping it in a
-- weak table avoids polluting/relying on fields Blizzard may recycle.
ns._nativeCDMFrameData = ns._nativeCDMFrameData or setmetatable({}, { __mode = "k" })

function ns.SyncNativeCDMBarAlpha(barKey)
    local container = cdmBarFrames[barKey]
    local icons = cdmBarIcons[barKey]
    if not (container and icons) then return end
    local alpha = container:IsShown() and (container:GetAlpha() or 1) or 0
    if container._kuiNativeAlpha == alpha then
        return
    end
    container._kuiNativeAlpha = alpha
    for _, icon in ipairs(icons) do
        if ns._nativeCDMFrameData[icon] then icon:SetAlpha(alpha) end
    end
end

function ns.SetCDMIconLayoutPoint(icon, point, relativeTo, relativePoint, x, y)
    local fd = ns._nativeCDMFrameData[icon]
    if fd then
        -- Stamp before SetPoint: the synchronous hook below must recognise KUI's
        -- own placement and reject only Blizzard's subsequent layout writes.
        fd.anchor = { point, relativeTo, relativePoint, x, y }
    end
    icon:SetPoint(point, relativeTo, relativePoint, x, y)
end
-- Fast barData lookup by key
barDataByKey = {}
local CDMRT = ns._cdmRuntime or {}
ns._cdmRuntime = CDMRT
CDMRT.mouseTrackFrames = CDMRT.mouseTrackFrames or {}
CDMRT.mouseTrackCount = CDMRT.mouseTrackCount or 0
CDMRT.coordinator = CDMRT.coordinator or nil
CDMRT.perf = CDMRT.perf or ns._perf or {
    capturing = false,
    tickCount = 0,
    totalMs = 0,
    peakMs = 0,
    bars = {},
    phases = {},
    phasePeaks = {},
    events = {},
    dirtyReasons = {},
    skippedTicks = 0,
    lastTick = {},
}
CDMRT.dirtyState = CDMRT.dirtyState or { any = true, reasons = {}, bars = {} }
CDMRT.dirtyState.bars = CDMRT.dirtyState.bars or {}
CDMRT.consumedDirtyBars = CDMRT.consumedDirtyBars or {}
CDMRT.viewerSnapshotElapsed = CDMRT.viewerSnapshotElapsed or 0
CDMRT.viewerSnapshotReady = CDMRT.viewerSnapshotReady or false
CDMRT.barUpdatePhase = CDMRT.barUpdatePhase or 0
ns._perf = CDMRT.perf

-- Expose our CDM bar frames so the glow system can reference them
ns.GetCDMBarFrame = function(barKey)
    return cdmBarFrames[barKey]
end
-- Global accessor for cross-addon frame lookups
_G._KUI_GetBarFrame = function(barKey)
    return cdmBarFrames[barKey]
end
-- Global accessors for party/player frame discovery
_G._KUI_FindPlayerPartyFrame = function()
    if ns and ns.FindPlayerPartyFrame then
        return ns.FindPlayerPartyFrame()
    end
    return nil
end
_G._KUI_FindPlayerUnitFrame = function()
    if ns and ns.FindPlayerUnitFrame then
        return ns.FindPlayerUnitFrame()
    end
    return nil
end
ns.GetCDMBarIcons = function(barKey)
    return cdmBarIcons[barKey]
end
ns.GetCDMMouseTrackCount = function()
    return CDMRT.mouseTrackCount or 0
end

function CDMRT:CountVisibleIconsForBar(barKey)
    local icons = cdmBarIcons[barKey]
    local totalIcons = icons and #icons or 0
    local visibleIcons = 0
    if icons then
        for _, icon in ipairs(icons) do
            if icon and icon.IsShown and icon:IsShown() then
                visibleIcons = visibleIcons + 1
            end
        end
    end
    return visibleIcons, totalIcons
end

function CDMRT:CountVisibleIcons()
    local visibleIcons = 0
    local totalIcons = 0
    for barKey in pairs(cdmBarIcons) do
        local barVisible, barTotal = self.CountVisibleIconsForBar(barKey)
        visibleIcons = visibleIcons + barVisible
        totalIcons = totalIcons + barTotal
    end
    return visibleIcons, totalIcons
end

function CDMRT:CountEnabledBars(profile)
    local enabledBars = 0
    local bars = profile and profile.cdmBars and profile.cdmBars.bars
    if not bars then
        return 0
    end

    for _, barData in ipairs(bars) do
        if barData and barData.enabled then
            enabledBars = enabledBars + 1
        end
    end

    return enabledBars
end

function CDMRT:MarkDirty(reason, targeted)
    local key = reason or "generic"
    self.dirtyState.any = true
    if not targeted then
        self.dirtyState.allBars = true
    end
    self.dirtyState.reasons[key] = (self.dirtyState.reasons[key] or 0) + 1
    self.perf.dirtyReasons[key] = (self.perf.dirtyReasons[key] or 0) + 1
end

function CDMRT:MarkBarDirty(barKey, reason, needsViewerSnapshot)
    self:MarkDirty(reason, true)
    if barKey then
        self.dirtyState.bars[barKey] = true
    end
    if needsViewerSnapshot then
        self.dirtyState.viewerSnapshot = true
    end
end

function CDMRT:ConsumeDirty()
    local wasDirty = self.dirtyState.any
    local viewerDirty = self.dirtyState.viewerSnapshot == true
    local allBarsDirty = self.dirtyState.allBars == true
    local dirtyBars = self.consumedDirtyBars
    wipe(dirtyBars)
    for barKey in pairs(self.dirtyState.bars) do
        dirtyBars[barKey] = true
    end
    for reason in pairs(self.dirtyState.reasons) do
        if reason == "late_viewer_settle"
            or reason == "player_entering_world"
            or reason == "talent_config"
            or reason == "spells_changed"
            or reason == "player_specialization_changed" then
            viewerDirty = true
            break
        end
    end
    self.dirtyState.any = false
    self.dirtyState.allBars = nil
    self.dirtyState.viewerSnapshot = nil
    wipe(self.dirtyState.reasons)
    wipe(self.dirtyState.bars)
    return wasDirty, viewerDirty, dirtyBars, allBarsDirty
end

function CDMRT:TrackEvent(eventName)
    if not eventName then
        return
    end
    self.perf.events[eventName] = (self.perf.events[eventName] or 0) + 1
end

function CDMRT:PerfPhaseAdd(phaseKey, deltaMs)
    if not (self.perf.capturing and phaseKey and deltaMs and deltaMs > 0) then
        return
    end

    self.perf.phases[phaseKey] = (self.perf.phases[phaseKey] or 0) + deltaMs
    if deltaMs > (self.perf.phasePeaks[phaseKey] or 0) then
        self.perf.phasePeaks[phaseKey] = deltaMs
    end
end

function CDMRT:PerfBarAdd(barKey, sourceKey, deltaMs)
    if not (self.perf.capturing and barKey and deltaMs and deltaMs >= 0) then
        return
    end

    local barPerf = self.perf.bars[barKey]
    if not barPerf then
        barPerf = {
            ticks = 0,
            totalMs = 0,
            peakMs = 0,
            sources = {},
            visibleIcons = 0,
            totalIcons = 0,
        }
        self.perf.bars[barKey] = barPerf
    end

    barPerf.ticks = barPerf.ticks + 1
    barPerf.totalMs = barPerf.totalMs + deltaMs
    if deltaMs > (barPerf.peakMs or 0) then
        barPerf.peakMs = deltaMs
    end
    if sourceKey then
        barPerf.sources[sourceKey] = (barPerf.sources[sourceKey] or 0) + deltaMs
    end

    local visibleIcons, totalIcons = self.CountVisibleIconsForBar(barKey)
    barPerf.visibleIcons = visibleIcons
    barPerf.totalIcons = totalIcons
end

function CDMRT:PerfFinalizeTick(totalMs, enabledBars, visibleIcons, totalIcons, skipped)
    self.perf.lastTick = {
        totalMs = totalMs or 0,
        enabledBars = enabledBars or 0,
        visibleIcons = visibleIcons or 0,
        totalIcons = totalIcons or 0,
        mouseTrackedBars = self.mouseTrackCount,
        skipped = skipped and true or false,
        dirty = self.dirtyState.any and true or false,
    }

    if skipped then
        self.perf.skippedTicks = (self.perf.skippedTicks or 0) + 1
    else
        self.perf.tickCount = (self.perf.tickCount or 0) + 1
        self.perf.totalMs = (self.perf.totalMs or 0) + (totalMs or 0)
        if (totalMs or 0) > (self.perf.peakMs or 0) then
            self.perf.peakMs = totalMs or 0
        end
    end

    if self.perf.capturing and self.perf.captureStart and self.perf.captureDur then
        if (GetTime() - self.perf.captureStart) >= self.perf.captureDur then
            self.perf.capturing = false
            local onDone = self.perf.onDone
            self.perf.onDone = nil
            if onDone then
                onDone()
            end
        end
    end
end

function CDMRT:EnsureMouseTrackCoordinator()
    if self.coordinator then
        return self.coordinator
    end

    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnUpdate", function()
        if self.mouseTrackCount <= 0 then
            frame:Hide()
            return
        end

        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx = floor(cx / scale + 0.5)
        cy = floor(cy / scale + 0.5)

        for trackedFrame in pairs(self.mouseTrackFrames) do
            if trackedFrame and trackedFrame._mouseTrack and trackedFrame:IsShown() then
                if cx ~= trackedFrame._mouseLastX or cy ~= trackedFrame._mouseLastY then
                    trackedFrame._mouseLastX = cx
                    trackedFrame._mouseLastY = cy
                    trackedFrame:ClearAllPoints()
                    trackedFrame:SetPoint(
                        trackedFrame._mousePointFrom or "LEFT",
                        UIParent,
                        "BOTTOMLEFT",
                        cx + (trackedFrame._mouseBaseOX or 0),
                        cy + (trackedFrame._mouseBaseOY or 0)
                    )
                end
            end
        end
    end)

    self.coordinator = frame
    return frame
end

function CDMRT:StopMouseTracking(frame)
    if not (frame and frame._mouseTrack) then
        return
    end

    if self.mouseTrackFrames[frame] then
        self.mouseTrackFrames[frame] = nil
        self.mouseTrackCount = math.max(0, self.mouseTrackCount - 1)
    end

    frame._mouseTrack = nil
    frame._mousePointFrom = nil
    frame._mouseBaseOX = nil
    frame._mouseBaseOY = nil
    frame._mouseLastX = nil
    frame._mouseLastY = nil

    if self.coordinator and self.mouseTrackCount <= 0 then
        self.coordinator:Hide()
    end
    if ns.RunCDMUpdateIfIdle then
        ns.RunCDMUpdateIfIdle()
    end
end

function CDMRT:StartMouseTracking(frame, pointFrom, baseOX, baseOY)
    if not frame then
        return
    end

    if not frame._mouseTrack then
        self.mouseTrackFrames[frame] = true
        self.mouseTrackCount = self.mouseTrackCount + 1
    end

    frame._mouseTrack = true
    frame._mousePointFrom = pointFrom
    frame._mouseBaseOX = baseOX
    frame._mouseBaseOY = baseOY
    frame._mouseLastX = nil
    frame._mouseLastY = nil

    local coordinator = self:EnsureMouseTrackCoordinator()
    if coordinator and not coordinator:IsShown() then
        coordinator:Show()
    end
    if ns.RunCDMUpdateIfIdle then
        ns.RunCDMUpdateIfIdle()
    end
end

-------------------------------------------------------------------------------
--  Proc Glow System: hooks Blizzard's SpellAlertManager to show proc glows
--  on our CDM icons when Blizzard fires ShowAlert/HideAlert on CDM children.
--  Custom bars use SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE events instead.
-------------------------------------------------------------------------------
-- PROC_GLOW_STYLE: default Blizzard glow with alternates
-- Default = Blizzard proc glow, with optional pixel/autocast alternates.
function ns.CDMGetConfiguredProcGlowStyle()
    local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
    local style = p and p.barGlows and p.barGlows.procGlowStyle
    style = (ns.CDMNormalizeNamedGlowStyle and ns.CDMNormalizeNamedGlowStyle(style)) or "blizzard"
    if style == "button" then
        return "blizzard"
    end
    return style
end

-- Reverse lookup: Blizzard CDM viewer frame name -> our bar key
local _blizzViewerToBarKey = {
    EssentialCooldownViewer = "cooldowns",
    UtilityCooldownViewer   = "utility",
    BuffIconCooldownViewer  = "buffs",
}

-- Walk up from a frame to find which Blizzard CDM viewer it belongs to
local function GetBarKeyForBlizzChild(frame)
    local current = frame
    while current do
        local parent = current:GetParent()
        if not parent then return nil end
        local name = parent.GetName and parent:GetName()
        if name and _blizzViewerToBarKey[name] then
            return _blizzViewerToBarKey[name], current
        end
        current = parent
    end
    return nil
end

-- Find our icon that mirrors a given Blizzard CDM child
local function FindOurIconForBlizzChild(barKey, blizzChild)
    local icons = cdmBarIcons[barKey]
    if not icons then return nil end
    for _, icon in ipairs(icons) do
        if icon._blizzChild == blizzChild then return icon end
    end
    return nil
end

-- Resolve spellID from a Blizzard CDM child (for IsSpellOverlayed guard)
local function ResolveBlizzChildSpellID(blizzChild)
    if not blizzChild then return nil end

    if IsCleanPositiveNumber(blizzChild._cdmResolvedSid) then
        return blizzChild._cdmResolvedSid
    end

    if blizzChild.GetAuraSpellID then
        local ok, auraID = pcall(blizzChild.GetAuraSpellID, blizzChild)
        if ok and auraID then
            local cmpOk, gt = pcall(function() return auraID > 0 end)
            if cmpOk and gt then return ns.ApplyBuffSpellCorrection(auraID) end
        end
    end

    if blizzChild.GetSpellID then
        local ok, frameSpellID = pcall(blizzChild.GetSpellID, blizzChild)
        if ok and frameSpellID then
            local cmpOk, gt = pcall(function() return frameSpellID > 0 end)
            if cmpOk and gt then return ns.ApplyBuffSpellCorrection(frameSpellID) end
        end
    end

    local cdID = blizzChild.cooldownID
    if not cdID and blizzChild.cooldownInfo then
        cdID = blizzChild.cooldownInfo.cooldownID
    end
    if cdID and IsCleanPositiveNumber(ns._cdIDToCorrectSID[cdID]) then
        return ns._cdIDToCorrectSID[cdID]
    end
    if cdID then
        local info = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
            and C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
        if info then
            return ns.ResolveInfoSpellID(info)
        end
    end
    return ns.ApplyBuffSpellCorrection(blizzChild.spellID or (blizzChild.cooldownInfo and blizzChild.cooldownInfo.spellID) or nil)
end

-- Show proc glow on one of our icons (separate from active state glow)
function ns.SyncProcGlowIndexForIcon(icon)
    if not icon then
        return
    end

    local isShown = icon:IsShown()
    local spellID = isShown and icon._spellID or nil
    local baseSpellID = isShown and icon._baseSpellID or nil
    if baseSpellID == spellID then
        baseSpellID = nil
    end

    if icon._procGlowIndexSpellID == spellID and icon._procGlowIndexBaseSpellID == baseSpellID then
        if not isShown and ns._activeProcGlowIcons then
            ns._activeProcGlowIcons[icon] = nil
        end
        return
    end

    if icon._procGlowIndexSpellID and ns._procGlowIconIndex and ns._procGlowIconIndex[icon._procGlowIndexSpellID] then
        ns._procGlowIconIndex[icon._procGlowIndexSpellID][icon] = nil
        if not next(ns._procGlowIconIndex[icon._procGlowIndexSpellID]) then
            ns._procGlowIconIndex[icon._procGlowIndexSpellID] = nil
        end
    end
    if icon._procGlowIndexBaseSpellID and ns._procGlowIconIndex and ns._procGlowIconIndex[icon._procGlowIndexBaseSpellID] then
        ns._procGlowIconIndex[icon._procGlowIndexBaseSpellID][icon] = nil
        if not next(ns._procGlowIconIndex[icon._procGlowIndexBaseSpellID]) then
            ns._procGlowIconIndex[icon._procGlowIndexBaseSpellID] = nil
        end
    end

    icon._procGlowIndexSpellID = nil
    icon._procGlowIndexBaseSpellID = nil

    if not isShown then
        if ns._activeProcGlowIcons then
            ns._activeProcGlowIcons[icon] = nil
        end
        return
    end

    if IsCleanPositiveNumber(spellID) then
        ns._procGlowIconIndex = ns._procGlowIconIndex or {}
        ns._procGlowIconIndex[spellID] = ns._procGlowIconIndex[spellID] or {}
        ns._procGlowIconIndex[spellID][icon] = true
        icon._procGlowIndexSpellID = spellID
    end

    if IsCleanPositiveNumber(baseSpellID) then
        ns._procGlowIconIndex = ns._procGlowIconIndex or {}
        ns._procGlowIconIndex[baseSpellID] = ns._procGlowIconIndex[baseSpellID] or {}
        ns._procGlowIconIndex[baseSpellID][icon] = true
        icon._procGlowIndexBaseSpellID = baseSpellID
    end
end

local function ShowProcGlow(icon, forceRefresh)
    if not icon or not icon._glowOverlay then return end
    if not ns.CDMCanShowProcGlow(icon) then
        if icon._procGlowActive or icon._glowOverlay._glowActive then
            StopNativeGlow(icon._glowOverlay)
        end
        icon._procGlowActive = false
        if ns._activeProcGlowIcons then
            ns._activeProcGlowIcons[icon] = nil
        end
        return
    end
    if icon._procGlowActive and not forceRefresh then
        ns.CDMGlowDebugPrint(icon, "proc keep", "reason=already_active")
        return
    end
    if icon._procGlowActive then
        StopNativeGlow(icon._glowOverlay)
        icon._procGlowActive = false
    end
    if icon._isActive and icon._glowOverlay._glowActive then
        StopNativeGlow(icon._glowOverlay)
    end
    local style, r, g, b = GetProcGlowStyleAndColor(icon)
    if style == "none" or style == 0 then
        ns.CDMGlowDebugPrint(icon, "proc skipped", "style=" .. tostring(style))
        return
    end
    icon._glowOverlay._kuiGlowSource = "proc:" .. tostring(icon._barKey or "?")
    ns.CDMGlowDebugPrint(
        icon,
        "proc start",
        "force=" .. tostring(forceRefresh == true),
        "style=" .. tostring(style),
        string.format("rgb=%.3f/%.3f/%.3f", r or 1, g or 0.82, b or 0.1)
    )
    StartNativeGlow(icon._glowOverlay, style, r, g, b)
    icon._procGlowActive = true
    ns._activeProcGlowIcons = ns._activeProcGlowIcons or {}
    ns._activeProcGlowIcons[icon] = true
end

function ns.RefreshActiveProcGlows()
    for icon in pairs(ns._activeProcGlowIcons or {}) do
        if icon and icon._procGlowActive and icon:IsShown() then
            ShowProcGlow(icon, true)
        else
            ns._activeProcGlowIcons[icon] = nil
        end
    end
end

-- Stop proc glow on one of our icons (restores active state glow if needed)
local function StopProcGlow(icon)
    if not icon or not icon._procGlowActive then return end
    ns.CDMGlowDebugPrint(icon, "proc stop")
    StopNativeGlow(icon._glowOverlay)
    icon._procGlowActive = false
    if ns._activeProcGlowIcons then
        ns._activeProcGlowIcons[icon] = nil
    end
    if icon._isActive and icon._glowOverlay then
        local barData = barDataByKey[icon._barKey]
        if barData then
            local activeAnim = barData.activeStateAnim or "2"
            local glowStyle = ns.CDMResolveActiveAnimGlowStyle(activeAnim)
            if glowStyle then
                local animR, animG, animB = 1.0, 0.85, 0.0
                if barData.activeAnimClassColor then
                    local _, ct = UnitClass("player")
                    if ct then
                        local cc = RAID_CLASS_COLORS[ct]; if cc then animR, animG, animB = cc.r, cc.g, cc.b end
                    end
                elseif barData.activeAnimR then
                    animR = barData.activeAnimR; animG = barData.activeAnimG or 0.85; animB = barData.activeAnimB or 0.0
                end
                local overrideStyle, overrideR, overrideG, overrideB, overrideIdentifier = ns.CDMResolveExplicitBarGlowOverride(icon, true)
                if overrideStyle ~= nil then
                    glowStyle = overrideStyle
                    animR = overrideR or animR
                    animG = overrideG or animG
                    animB = overrideB or animB
                    ns.CDMGlowDebugPrint(
                        icon,
                        "proc restore active override",
                        "identifier=" .. tostring(overrideIdentifier),
                        "style=" .. tostring(glowStyle),
                        string.format("rgb=%.3f/%.3f/%.3f", animR or 1, animG or 0.82, animB or 0.1)
                    )
                end
                if glowStyle ~= 0 and glowStyle ~= "none" then
                    icon._glowOverlay._kuiGlowSource = "active_restore:" .. tostring(icon._barKey or "?")
                    StartNativeGlow(icon._glowOverlay, glowStyle, animR, animG, animB)
                end
            end
        end
    end
end

-- Instala hooks seguros sobre el ActionButtonSpellAlertManager (una sola vez)
local _procGlowHooksInstalled = false
local function HookProcAlertManager()
    if _procGlowHooksInstalled then return end
    if not ActionButtonSpellAlertManager then return end

    -- Suprimir overlay nativo de Blizzard en un child CDM
    local function SuppressBlizzOverlay(cdmChild)
        local alert = cdmChild and cdmChild.SpellActivationAlert
        if alert then alert:SetAlpha(0); alert:Hide() end
    end

    -- Despachar glow por pointer directo o fallback por spellID
    local function DispatchGlow(barKey, cdmChild, glowEventName, glowFn)
        local ourIcon = FindOurIconForBlizzChild(barKey, cdmChild)
        if ourIcon then
            ns.CDMGlowDebugPrint(ourIcon, glowEventName,
                "bar=" .. tostring(barKey),
                "childSpell=" .. tostring(ResolveBlizzChildSpellID(cdmChild)))
            glowFn(ourIcon)
            return ourIcon
        end
        -- Fallback por spellID (ns indirecto para evitar forward reference)
        local sid = ResolveBlizzChildSpellID(cdmChild)
        if sid and ns.OnProcGlowEvent then
            ns.OnProcGlowEvent(
                glowEventName == "ShowAlert hook"
                    and "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
                    or  "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
                sid)
        end
        return nil
    end

    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, frame)
        if not frame then return end
        local barKey, cdmChild = GetBarKeyForBlizzChild(frame)
        if not barKey or not cdmChild then return end
        SuppressBlizzOverlay(cdmChild)
        -- Blizzard re-seeds ShowAlert repeatedly for the same proc (refresh
        -- ticks, pool re-show, target swaps). Memoize per child so the
        -- C_Timer.After + DispatchGlow (+ proc glow re-assert) only runs on
        -- the FIRST seed while the alert is still up; the rest are no-ops.
        if cdmChild._kuiAlertShown then return end
        cdmChild._kuiAlertShown = true
        C_Timer.After(0, function()
            if not cdmChild._kuiAlertShown then return end
            SuppressBlizzOverlay(cdmChild)
            DispatchGlow(barKey, cdmChild, "ShowAlert hook", ShowProcGlow)
        end)
    end)

    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, frame)
        if not frame then return end
        local barKey, cdmChild = GetBarKeyForBlizzChild(frame)
        if not barKey or not cdmChild then return end
        cdmChild._kuiAlertShown = nil

        local spellID = ResolveBlizzChildSpellID(cdmChild)
        local ourIcon = FindOurIconForBlizzChild(barKey, cdmChild)

        if ourIcon and ourIcon._procGlowActive then
            -- Check if Blizzard overlay is active before hiding
            if spellID and C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
                local ok, overlayed = pcall(C_SpellActivationOverlay.IsSpellOverlayed, spellID)
                if ok and overlayed then SuppressBlizzOverlay(cdmChild); return end
            end
            ns.CDMGlowDebugPrint(ourIcon, "HideAlert hook",
                "bar=" .. tostring(barKey), "childSpell=" .. tostring(spellID))
            StopProcGlow(ourIcon)
        elseif spellID then
            if ns.OnProcGlowEvent then ns.OnProcGlowEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", spellID) end
        end
    end)

    _procGlowHooksInstalled = true
end

-- Handle proc glow for custom bars via spell activation overlay events.
local function ProcSpellIDsMatch(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    if a == b then return true end
    local function aliases(id)
        local result, seen, pending = {}, {}, { id }
        local read = 1
        while read <= #pending do
            local current = pending[read]
            read = read + 1
            if type(current) == "number" and not (issecretvalue and issecretvalue(current)) and current > 0 and not seen[current] then
                seen[current] = true
                result[#result + 1] = current
                if ns.ApplyBuffSpellCorrection then
                    local corrected = ns.ApplyBuffSpellCorrection(current)
                    if type(corrected) == "number" and corrected > 0 and not seen[corrected] then pending[#pending + 1] = corrected end
                end
                if C_Spell then
                    if C_Spell.GetBaseSpell then
                        local ok, base = pcall(C_Spell.GetBaseSpell, current)
                        if ok and type(base) == "number" and base > 0 and not seen[base] then pending[#pending + 1] = base end
                    end
                    if C_Spell.GetOverrideSpell then
                        local ok, override = pcall(C_Spell.GetOverrideSpell, current)
                        if ok and type(override) == "number" and override > 0 and not seen[override] then pending[#pending + 1] = override end
                    end
                end
            end
        end
        return result
    end
    local left, right = aliases(a), aliases(b)
    for _, aID in ipairs(left) do for _, bID in ipairs(right) do if aID == bID then return true end end end
    return false
end

local function OnProcGlowEvent(event, spellID)
    if not spellID or not ns._procGlowIconIndex then return false end
    local shouldShow = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
    local allIcons = {}
    for indexedID, indexedIcons in pairs(ns._procGlowIconIndex) do
        local sameFamily = ProcSpellIDsMatch(indexedID, spellID)
        if not sameFamily and _executeFamily[spellID] and _executeFamily[indexedID] then sameFamily = true end
        if sameFamily then for icon in pairs(indexedIcons) do allIcons[icon] = true end end
    end
    if not next(allIcons) then return false end
    local handled = false
    for icon in pairs(allIcons) do
        if icon and icon:IsShown() then
            handled = true
            if shouldShow then ShowProcGlow(icon) else StopProcGlow(icon) end
        end
    end
    return handled
end
ns.OnProcGlowEvent = OnProcGlowEvent

function ns.ReconcileCDMProcGlowsForTarget()
    if not ns.CDMHasUsableTarget() then
        ns.ClearAllCDMGlowState()
        return
    end
    if not (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) then
        return
    end

    local visited = {}
    for spellID, icons in pairs(ns._procGlowIconIndex or {}) do
        local ok, overlayed = pcall(C_SpellActivationOverlay.IsSpellOverlayed, spellID)
        local canRead = ok and not (issecretvalue and issecretvalue(overlayed))
        for icon in pairs(icons) do
            if icon and not visited[icon] then
                visited[icon] = true
                if canRead and overlayed == true and icon:IsShown() then
                    ShowProcGlow(icon, true)
                elseif icon._procGlowActive then
                    StopProcGlow(icon)
                end
            end
        end
    end
end

function ns.ResetExecuteProcGlowState()
    _executeOverlayActive = false
    for spellID in pairs(_executeFamily) do
        _tickUsableCache[spellID] = nil
        local indexedIcons = ns._procGlowIconIndex and ns._procGlowIconIndex[spellID]
        if indexedIcons then
            for icon in pairs(indexedIcons) do
                icon._isActive = false
            end
        end
        OnProcGlowEvent('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE', spellID)
    end
end

function ns.ClearAllCDMGlowState()
    for _, icons in pairs(cdmBarIcons) do
        for _, icon in ipairs(icons) do
            if icon._glowOverlay then
                StopNativeGlow(icon._glowOverlay)
            end
            if icon._customModuleGlowOverlay then
                StopNativeGlow(icon._customModuleGlowOverlay)
            end
            icon._isActive = false
            icon._procGlowActive = false
            icon._buffGlowActive = false
            icon._customModuleGlowActive = false
            icon._customModuleGlowWanted = false
            icon._customModuleGlowStyle = nil
        end
    end
    if ns._activeProcGlowIcons then
        wipe(ns._activeProcGlowIcons)
    end
end
-------------------------------------------------------------------------------
--  CDM Bars: Our replacement for Blizzard's Cooldown Manager
--  Captures Blizzard positions on first login, then creates our own bars.
-------------------------------------------------------------------------------
local function GetCDMFont()
    local path = KT.FONT_PATH
    if type(path) == "string" and path ~= "" then return path end
    if type(_G.STANDARD_TEXT_FONT) == "string" and _G.STANDARD_TEXT_FONT ~= "" then return _G.STANDARD_TEXT_FONT end
    if _G.StandardTextFont and _G.StandardTextFont.GetFont then
        local p = _G.StandardTextFont:GetFont()
        if type(p) == "string" and p ~= "" then return p end
    end
    return "Fonts\\FRIZQT__.TTF"
end
local function SetBlizzCDMFont(fs, font, size)
    SetCDMFont(fs, font, size)
end

ns.CDMFormatPotionTrackerCooldownText = function(remaining)
    if type(remaining) ~= "number" or remaining <= 0 then
        return ""
    end

    if remaining >= 600 then
        return format("%dm", math.ceil(remaining / 60))
    end

    if remaining >= 60 then
        local minutes = math.floor(remaining / 60)
        local seconds = math.ceil(remaining - (minutes * 60))
        if seconds >= 60 then
            minutes = minutes + 1
            seconds = 0
        end
        return format("%d:%02d", minutes, seconds)
    end

    if remaining >= 10 then
        return tostring(math.ceil(remaining))
    end

    return format("%.1f", remaining)
end

ns.CDMSetPotionTrackerCooldownText = function(icon, showText, startTime, durationTime)
    if not icon then
        return
    end

    local overlay = icon._potionCooldownOverlay
    if not overlay then
        overlay = CreateFrame("Frame", nil, icon)
        overlay:SetAllPoints(icon)
        overlay:SetFrameLevel((icon:GetFrameLevel() or 0) + 9)
        overlay:EnableMouse(false)
        overlay._potionCooldownOwner = icon
        icon._potionCooldownOverlay = overlay
    end

    local label = icon._potionCooldownText
    if not label and overlay.CreateFontString then
        label = overlay:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        label:SetTextColor(1, 1, 1, 1)
        label:SetShadowOffset(0, 0)
        icon._potionCooldownText = label
        overlay._potionCooldownOwner = icon
    end

    if not label then
        return
    end

    local barData = icon._barKey and barDataByKey and barDataByKey[icon._barKey] or nil
    SetCDMFont(label, GetCDMFont(), (barData and barData.cooldownFontSize) or 12)
    label:SetTextColor(1, 1, 1, 1)
    label:SetShadowOffset(0, 0)
    if label.SetDrawLayer then
        label:SetDrawLayer("OVERLAY", 20)
    end

    -- LayoutCDMBar raises the normal cooldown and stack overlays. Keep the
    -- potion timer above both so the seconds cannot be darkened/covered.
    local iconLevel = icon.GetFrameLevel and icon:GetFrameLevel() or 0
    local cooldownLevel = icon._cooldown and icon._cooldown.GetFrameLevel
        and icon._cooldown:GetFrameLevel() or iconLevel
    local stackLevel = icon._textOverlay and icon._textOverlay.GetFrameLevel
        and icon._textOverlay:GetFrameLevel() or iconLevel
    local timerLevel = math.max(iconLevel + 27, cooldownLevel + 3, stackLevel + 3)
    pcall(overlay.SetFrameLevel, overlay, timerLevel)

    icon._potionCooldownTextEnabled = showText and true or false
    icon._potionCooldownStart = startTime
    icon._potionCooldownDuration = durationTime

    local function UpdateLabel(owner)
        local remaining = ((owner._potionCooldownStart or 0) + (owner._potionCooldownDuration or 0)) - GetTime()
        if not owner._potionCooldownTextEnabled or remaining <= 0.05 then
            if owner._potionCooldownText then
                owner._potionCooldownText:SetText("")
                owner._potionCooldownText:Hide()
            end
            return false
        end

        owner._potionCooldownText:SetText(ns.CDMFormatPotionTrackerCooldownText(remaining))
        owner._potionCooldownText:Show()
        return true
    end

    if not UpdateLabel(icon) then
        overlay:SetScript("OnUpdate", nil)
        return
    end

    overlay._potionCooldownElapsed = 0
    overlay:SetScript("OnUpdate", function(self, elapsed)
        self._potionCooldownElapsed = (self._potionCooldownElapsed or 0) + (elapsed or 0)
        if self._potionCooldownElapsed < 0.05 then
            return
        end
        self._potionCooldownElapsed = 0

        local owner = self._potionCooldownOwner
        if not owner or not owner._potionCooldownText then
            self:SetScript("OnUpdate", nil)
            return
        end

        if not UpdateLabel(owner) then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Blizzard CDM frame names
ns.BLIZZ_CDM_FRAMES = {
    cooldowns = "EssentialCooldownViewer",
    utility   = "UtilityCooldownViewer",
    buffs     = "BuffIconCooldownViewer",
}

ns.BLIZZ_CDM_FRAMES_SECONDARY = {
    buffs = "BuffBarCooldownViewer",
}

-- CDM category numbers per bar key (for C_CooldownViewer API)
ns.CDM_BAR_CATEGORIES = {
    cooldowns = { 0 },    -- Essential only
    utility   = { 1 },    -- Utility only
    buffs     = { 2, 3 }, -- Tracked Buff + Tracked Debuff
}

-- Maximum number of custom bars a user can create
ns.MAX_CUSTOM_BARS = 12

-------------------------------------------------------------------------------
--  Party Frame Discovery
-------------------------------------------------------------------------------
ns.PARTY_FRAME_PREFIXES = {
    { addon = "ElvUI",              prefix = "ElvUF_PartyGroup1UnitButton", count = 5 },
    { addon = "Cell",               prefix = "CellPartyFrameMember",        count = 5 },
    { addon = "UnhaltedUnitFrames", prefix = "UUF_PartyUnitButton",         count = 5 },
}

local _cachedPartyFrame
local _cachedPartyFrameRoster = 0

local function FindPlayerPartyFrame()
    local rosterToken = GetNumGroupMembers()
    if _cachedPartyFrame and _cachedPartyFrameRoster == rosterToken then
        if _cachedPartyFrame:IsVisible() then
            return _cachedPartyFrame
        end
    end
    _cachedPartyFrame = nil
    _cachedPartyFrameRoster = rosterToken

    for _, src in ipairs(ns.PARTY_FRAME_PREFIXES) do
        if not src.addon or (src.addon and C_AddOns.IsAddOnLoaded(src.addon)) then
            for i = 1, src.count do
                local frame = _G[src.prefix .. i]
                if frame and frame.GetAttribute and frame:GetAttribute("unit") == "player"
                    and frame.IsVisible and frame:IsVisible() then
                    _cachedPartyFrame = frame
                    return frame
                end
            end
        end
    end

    if C_AddOns.IsAddOnLoaded("DandersFrames") or C_AddOns.IsAddOnLoaded("DandersFramers") then
        local container = _G["DandersPartyContainer"] or _G["DandersFramesContainer"]
        if container and container.IsVisible and container:IsVisible() then
            _cachedPartyFrame = container
            return container
        end
    end

    return nil
end

-------------------------------------------------------------------------------
--  Player Frame Discovery
-------------------------------------------------------------------------------
ns.PLAYER_FRAME_SOURCES = {
    { addon = ADDON_NAME,           global = "KullThranUI_UF_Player" },
    { addon = ADDON_NAME,           global = "KT_PlayerFrame" },  -- Migrado para KT
    { addon = "ElvUI",              global = "ElvUF_Player" },
    { addon = "UnhaltedUnitFrames", global = "UUF_PlayerFrame" }, -- External player-frame global.
    { addon = "UnhaltedUnitFrames", global = "UUF_Player" },      -- fallback por si cambia
    { addon = "UnhaltedUnitFrames", global = "UUF_PlayerUnitFrame" },
    { addon = "UnhaltedUnitFrames", global = "UUF_PlayerUnit" },
}

local _cachedPlayerFrame
local _cachedPlayerFrameRoster = 0

local function IsBadPlayerFrame(frame)
    if not frame then return true end
    local name = frame.GetName and frame:GetName() or ""
    if name ~= "" then
        local ln = name:lower()
        if ln:find("petbattle") or ln:find("hider") then
            return true
        end
    end
    local uiW = UIParent and UIParent:GetWidth() or 0
    local uiH = UIParent and UIParent:GetHeight() or 0
    local w = (frame.GetWidth and frame:GetWidth()) or 0
    local h = (frame.GetHeight and frame:GetHeight()) or 0
    if uiW > 0 and uiH > 0 and w >= uiW * 0.9 and h >= uiH * 0.9 then
        return true
    end
    return false
end

ns.CDMIsFrameShownOrVisible = ns.CDMIsFrameShownOrVisible or function(frame)
    if not frame then return false end
    if frame.IsVisible and frame:IsVisible() then return true end
    if frame.IsShown and frame:IsShown() then return true end
    return false
end

ns.CDMIsBlizzardPlayerFrame = ns.CDMIsBlizzardPlayerFrame or function(frame)
    if not frame then return false end
    if frame == _G["PlayerFrame"] then return true end
    local name = frame.GetName and frame:GetName() or ""
    return name == "PlayerFrame" or name == "PlayerFrameContainer" or name == "PlayerFrameContent"
end

ns.CDMGetBlizzardPlayerFrameCandidate = ns.CDMGetBlizzardPlayerFrameCandidate or function()
    local pf = _G["PlayerFrame"]
    if not pf then return nil end

    local candidates = {
        pf,
        pf.PlayerFrameContainer,
        pf.PlayerFrameContent,
        _G["PlayerFrameContainer"],
        _G["PlayerFrameContent"],
    }

    local fallback
    for _, frame in ipairs(candidates) do
        if frame and not IsBadPlayerFrame(frame) then
            if ns.CDMIsFrameShownOrVisible(frame) then
                return frame
            end
            if not fallback then
                fallback = frame
            end
        end
    end
    return fallback
end

local function NormalizePlayerFrame(frame)
    if not frame or not frame.GetParent then return frame end
    if ns.CDMIsBlizzardPlayerFrame(frame) then return frame end
    local best = frame
    local bw = (frame.GetWidth and frame:GetWidth()) or 0
    local bh = (frame.GetHeight and frame:GetHeight()) or 0
    local parent = frame:GetParent()
    local depth = 0
    while parent and parent ~= UIParent and depth < 6 do
        if IsBadPlayerFrame(parent) then
            break
        end
        local w = (parent.GetWidth and parent:GetWidth()) or 0
        local h = (parent.GetHeight and parent:GetHeight()) or 0
        if w > bw and h > bh and w <= bw * 2 and h <= bh * 2 then
            best = parent
            bw = w
            bh = h
        end
        parent = parent:GetParent()
        depth = depth + 1
    end
    return best
end

local function FindPlayerUnitFrame()
    local rosterToken = GetNumGroupMembers()
    local cachedCandidate
    if _cachedPlayerFrame and _cachedPlayerFrameRoster == rosterToken then
        if not IsBadPlayerFrame(_cachedPlayerFrame) then
            local u = _cachedPlayerFrame.GetAttribute and _cachedPlayerFrame:GetAttribute("unit")
            if not u or UnitIsUnit(u, "player") then
                if ns.CDMIsFrameShownOrVisible(_cachedPlayerFrame) then
                    _cachedPlayerFrame = NormalizePlayerFrame(_cachedPlayerFrame)
                    return _cachedPlayerFrame
                end
                cachedCandidate = _cachedPlayerFrame
            end
        end
    end
    _cachedPlayerFrame = nil
    _cachedPlayerFrameRoster = rosterToken

    -- If no integrated unit frame addon is loaded, prefer Blizzard's player frame first.
    if not _G["KullThranUI_UF_Player"] and not C_AddOns.IsAddOnLoaded("UnhaltedUnitFrames") then
        local blizzFirst = (ns.CDMGetBlizzardPlayerFrameCandidate and ns.CDMGetBlizzardPlayerFrameCandidate()) or _G["PlayerFrame"]
        if blizzFirst and not IsBadPlayerFrame(blizzFirst) then
            _cachedPlayerFrame = NormalizePlayerFrame(blizzFirst)
            return _cachedPlayerFrame
        end
    end

    local fallbackFrame = (cachedCandidate and not IsBadPlayerFrame(cachedCandidate)) and cachedCandidate or nil
    for _, src in ipairs(ns.PLAYER_FRAME_SOURCES) do
        if not src.addon or src.addon == ADDON_NAME or C_AddOns.IsAddOnLoaded(src.addon) then
            local frame = _G[src.global]
            if frame and not IsBadPlayerFrame(frame) then
                if ns.CDMIsFrameShownOrVisible(frame) then
                    _cachedPlayerFrame = NormalizePlayerFrame(frame)
                    return _cachedPlayerFrame
                elseif not fallbackFrame then
                    fallbackFrame = NormalizePlayerFrame(frame)
                end
            end
        end
    end

    if C_AddOns.IsAddOnLoaded("DandersFrames") or C_AddOns.IsAddOnLoaded("DandersFramers") then
        local header = _G["DandersPartyHeader"] or _G["DandersFramesContainer"]
        if header then
            for i = 1, 5 do
                local child = header:GetAttribute("child" .. i)
                if child and child.GetAttribute and child:GetAttribute("unit") == "player"
                    and ns.CDMIsFrameShownOrVisible(child) then
                    if not IsBadPlayerFrame(child) then
                        _cachedPlayerFrame = NormalizePlayerFrame(child)
                        return _cachedPlayerFrame
                    end
                end
            end
        end
    end

    local blizz = ns.CDMGetBlizzardPlayerFrameCandidate()
    if blizz and not IsBadPlayerFrame(blizz) then
        _cachedPlayerFrame = NormalizePlayerFrame(blizz)
        return _cachedPlayerFrame
    end

    local fallbackList = { "PlayerFrame", "UUF_Player", "UUF_PlayerFrame", "UUF_PlayerUnitFrame", "UUF_PlayerUnit", "ElvUF_Player" }
    for _, name in ipairs(fallbackList) do
        local f = _G[name]
        if f and not IsBadPlayerFrame(f) then
            _cachedPlayerFrame = NormalizePlayerFrame(f)
            return _cachedPlayerFrame
        end
    end

    -- Never fall back to EnumerateFrames() here. This function runs from
    -- login/roster/spec anchor refreshes and a global frame walk is both
    -- expensive and capable of touching forbidden frames. All supported
    -- layouts are resolved explicitly above; otherwise use the cached or
    -- Blizzard candidate below.

    if fallbackFrame and not IsBadPlayerFrame(fallbackFrame) then
        _cachedPlayerFrame = NormalizePlayerFrame(fallbackFrame)
        return _cachedPlayerFrame
    end

    return nil
end

-------------------------------------------------------------------------------
--  Trinket / Racial / Health Potion data
-------------------------------------------------------------------------------
ns.TRINKET_SLOT_1 = 13
ns.TRINKET_SLOT_2 = 14
ns.ITEM_ID_NEG_OFFSET = 1000000

NormalizeItemID = function(itemID)
    if type(itemID) == "number" then
        return itemID
    end
    if type(itemID) ~= "string" or itemID == "" then
        return nil
    end

    local numericID = tonumber(itemID) or tonumber(itemID:match("item:(%d+)"))
    if numericID then
        return numericID
    end

    if C_Item and C_Item.GetItemInfoInstant then
        local resolvedID = C_Item.GetItemInfoInstant(itemID)
        if type(resolvedID) == "number" then
            return resolvedID
        end
    end

    return nil
end

ns.NormalizeItemID = NormalizeItemID

EncodeItemID = function(itemID)
    local normalizedID = ns.NormalizeItemID(itemID)
    if not normalizedID then
        return nil
    end
    return -(ns.ITEM_ID_NEG_OFFSET + normalizedID)
end

ns.EncodeItemID = EncodeItemID

DecodeItemID = function(spellID)
    local neg = -spellID
    if neg >= ns.ITEM_ID_NEG_OFFSET then
        return neg - ns.ITEM_ID_NEG_OFFSET
    end
    return nil
end

ns.RACE_RACIALS = {
    Scourge            = { 7744 },
    Tauren             = { 20549 },
    Orc                = { 20572, 33697, 33702 },
    BloodElf           = { 202719, 50613, 25046, 69179, 80483, 155145, 129597, 232633, 28730 },
    Dwarf              = { 20594 },
    Troll              = { 26297 },
    Draenei            = { 28880 },
    NightElf           = { 58984 },
    Human              = { 59752 },
    DarkIronDwarf      = { 265221 },
    Gnome              = { 20589 },
    HighmountainTauren = { 69041 },
    Worgen             = { 68992 },
    Goblin             = { 69070 },
    Pandaren           = { 107079 },
    MagharOrc          = { 274738 },
    LightforgedDraenei = { 255647 },
    VoidElf            = { 256948 },
    KulTiran           = { 287712 },
    ZandalariTroll     = { 291944 },
    Vulpera            = { 312411 },
    Mechagnome         = { 312924 },
    Dracthyr           = { 357214, { 368970, class = "EVOKER" } },
    EarthenDwarf       = { 436344 },
    Haranir            = { 1287685 },
}

HEALTH_ITEMS = {
    -- Midnight (12.0)
    { itemID = 241304, spellID = 1234768, cooldown = 300, name = "Silvermoon Health Potion" }, -- Quality 2
    { itemID = 241305, spellID = 1234768, cooldown = 300, name = "Silvermoon Health Potion" }, -- Quality 1
    { itemID = 241306, cooldown = 300, name = "Refreshing Serum" }, -- Quality 2
    { itemID = 241307, cooldown = 300, name = "Refreshing Serum" }, -- Quality 1

    -- The War Within (11.0)
    { itemID = 211878, cooldown = 300, name = "Algari Healing Potion" }, -- Quality 1
    { itemID = 211879, cooldown = 300, name = "Algari Healing Potion" }, -- Quality 2
    { itemID = 211880, cooldown = 300, name = "Algari Healing Potion" }, -- Quality 3
    { itemID = 212300, cooldown = 300, name = "Algari Healing Potion" },
    { itemID = 212301, cooldown = 300, name = "Algari Healing Potion" },
    { itemID = 212302, cooldown = 300, name = "Algari Healing Potion" },

    -- The War Within / K'aresh refresh
    { itemID = 244839, spellID = 455486, cooldown = 300, name = "Invigorating Healing Potion" }, -- Tier 3
    { itemID = 244838, spellID = 455486, cooldown = 300, name = "Invigorating Healing Potion" }, -- Tier 2
    { itemID = 244835, spellID = 455486, cooldown = 300, name = "Invigorating Healing Potion" }, -- Tier 1
    { itemID = 244849, spellID = 455486, cooldown = 300, name = "Fleeting Invigorating Healing Potion" },

    -- Healthstones
    { itemID = 224464, spellID = 452930, class = "WARLOCK", cooldown = 60, name = "Demonic Healthstone" },
    { itemID = 5512,   spellID = 6262, cooldown = 60, name = "Healthstone" },
}
ns.CDMHealthItemsByID = ns.CDMHealthItemsByID or {}
for _, item in ipairs(HEALTH_ITEMS) do
    ns.CDMHealthItemsByID[item.itemID] = item
end

PREPOT_ITEM_IDS = {
    -- Midnight (12.0)
    [241308] = true, [241309] = true,
    -- The War Within (11.0) - Tempered Potion / Potion templada
    [212260] = true, [212261] = true, [212262] = true,
    [212263] = true, [212264] = true, [212265] = true,
    -- Fleeting Tempered Potion
    [212939] = true, [212940] = true, [212941] = true,
    -- Frontline Potion (PvP)
    [212247] = true, [212248] = true, [212249] = true,
    -- Cavedweller's Delight
    [210967] = true, [210968] = true, [210969] = true,
    [212241] = true, [212242] = true, [212243] = true,
    -- Potion of Unwavering Focus
    [212257] = true, [212258] = true, [212259] = true,
}
ns.CDMPrepotItemIDs = PREPOT_ITEM_IDS
local POTION_TRACKER_HEALTH_PRIORITY = {
    241304, 241305, 241306, 241307, -- Midnight (Q2/Q1 pairs)
    244839, 244838, 244835, 244849, -- TWW latest patch
    212302, 212301, 212300,
    211880, 211879, 211878, -- TWW launch
}
do
local POTION_TRACKER_PREPOT_PRIORITY = {
    241308, 241309, -- Midnight (Quality 2, Quality 1)
    212941, 212940, 212939, -- Fleeting Tempered Potion
    212265, 212264, 212263, 212262, 212261, 212260, -- Tempered Potion
    212259, 212258, 212257, -- Potion of Unwavering Focus
    212243, 212242, 212241, 210969, 210968, 210967, -- Cavedweller's Delight
    212249, 212248, 212247, -- Frontline Potion
}
local POTION_TRACKER_HEALTHSTONE_PRIORITY_BY_CLASS = {
    WARLOCK = { 224464, 5512 },
    DEFAULT = { 5512, 224464 },
}

local POTION_TRACKER_QUALITY_BY_ITEM_ID = {
    [241304] = 2, [241305] = 1, -- Silvermoon Health Potion
    [241306] = 2, [241307] = 1, -- Refreshing Serum
    [241308] = 2, [241309] = 1, -- Light's Potential
    [245898] = 2, [245897] = 1, -- Fleeting Light's Potential
}
local potionTrackerQualityCache = {}

local function GetPotionTrackerQualityPreference()
    local potionCfg = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
        and KUI_CDM.db.profile.customTracker and KUI_CDM.db.profile.customTracker.potion
    local quality = potionCfg and tonumber(potionCfg.potionQuality)
    if quality and quality >= 1 and quality <= 3 then
        return quality
    end
    return nil
end

local function GetPotionTrackerItemQuality(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local knownQuality = POTION_TRACKER_QUALITY_BY_ITEM_ID[itemID]
    if knownQuality then return knownQuality end

    local cached = potionTrackerQualityCache[itemID]
    if cached ~= nil then return cached or nil end

    local quality
    if C_TradeSkillUI then
        if C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
            local ok, result = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, itemID)
            if ok then quality = tonumber(result) end
        end
        if not quality and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
            local ok, result = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemID)
            if ok then quality = tonumber(result) end
        end
    end

    -- Item data can arrive asynchronously after BAG_UPDATE. Cache successful
    -- lookups only so an unloaded item is retried on the next tracker refresh.
    if quality then potionTrackerQualityCache[itemID] = quality end
    return quality
end

local function PotionMatchesSelectedQuality(itemID)
    local wantedQuality = GetPotionTrackerQualityPreference()
    if not wantedQuality then return true end
    return GetPotionTrackerItemQuality(itemID) == wantedQuality
end

local function FindOwnedTrackerItem(priorityList, filterPotionQuality)
    if type(priorityList) ~= "table" then return nil end
    if not GetItemCount then return nil end
    for i = 1, #priorityList do
        local itemID = priorityList[i]
        if itemID and (not filterPotionQuality or PotionMatchesSelectedQuality(itemID))
            and GetTrackerOwnedItemCount(itemID) > 0 then
            return itemID
        end
    end
    return nil
end

local function ChooseTrackerItemFromPriority(priorityList, syntheticGroup)
    local filterPotionQuality = syntheticGroup == "potion"
    local syntheticState = syntheticGroup and ns.CDMGetActiveSyntheticItemCooldownState and ns.CDMGetActiveSyntheticItemCooldownState(syntheticGroup) or nil
    local syntheticItemID = syntheticState and syntheticState.itemID or nil
    if syntheticItemID and (not filterPotionQuality or PotionMatchesSelectedQuality(syntheticItemID)) then
        for i = 1, #priorityList do
            if priorityList[i] == syntheticItemID then
                return syntheticItemID
            end
        end
    end

    local ownedItemID = FindOwnedTrackerItem(priorityList, filterPotionQuality)
    if ownedItemID then
        return ownedItemID
    end

    if syntheticItemID and (not filterPotionQuality or PotionMatchesSelectedQuality(syntheticItemID)) then
        return syntheticItemID
    end

    return nil
end

ns.FindOwnedHealthPotionFallbackItem = function()
    if not (C_Container and C_Container.GetContainerNumSlots and GetPotionTooltipClass) then
        return nil
    end

    local function ResolveCandidate(candidateItemID)
        candidateItemID = NormalizeItemID and ns.NormalizeItemID(candidateItemID) or candidateItemID
        if not candidateItemID or not PotionMatchesSelectedQuality(candidateItemID)
            or GetTrackerOwnedItemCount(candidateItemID) <= 0 then
            return nil
        end

        local healthMeta = ns.CDMHealthItemsByID and ns.CDMHealthItemsByID[candidateItemID]
        if healthMeta and tonumber(healthMeta.cooldown) == 60 then
            return nil
        end

        if GetFallbackItemCooldownDuration(candidateItemID) ~= 300 then
            return nil
        end

        if GetPotionTooltipClass(candidateItemID) ~= "health" then
            return nil
        end

        return candidateItemID
    end

    local function ScanBag(bagID)
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            local foundItemID = ResolveCandidate((info and info.itemID) or C_Container.GetContainerItemID(bagID, slot))
            if foundItemID then
                return foundItemID
            end
        end
        return nil
    end

    local maxBag = NUM_BAG_SLOTS or 4
    for bagID = 0, maxBag do
        local foundItemID = ScanBag(bagID)
        if foundItemID then
            return foundItemID
        end
    end

    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        return ScanBag(Enum.BagIndex.ReagentBag)
    end

    return nil
end

ns.FindOwnedManaPotionFallbackItem = function()
    if not (C_Container and C_Container.GetContainerNumSlots and GetPotionTooltipClass) then
        return nil
    end

    local function ResolveCandidate(candidateItemID)
        candidateItemID = NormalizeItemID and ns.NormalizeItemID(candidateItemID) or candidateItemID
        if not candidateItemID or not PotionMatchesSelectedQuality(candidateItemID)
            or GetTrackerOwnedItemCount(candidateItemID) <= 0 then return nil end
        if GetFallbackItemCooldownDuration(candidateItemID) ~= 300 then return nil end
        if GetPotionTooltipClass(candidateItemID) ~= "mana" then return nil end
        return candidateItemID
    end

    local function ScanBag(bagID)
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            local foundItemID = ResolveCandidate((info and info.itemID) or C_Container.GetContainerItemID(bagID, slot))
            if foundItemID then return foundItemID end
        end
        return nil
    end

    local maxBag = NUM_BAG_SLOTS or 4
    for bagID = 0, maxBag do
        local foundItemID = ScanBag(bagID)
        if foundItemID then return foundItemID end
    end
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        return ScanBag(Enum.BagIndex.ReagentBag)
    end
    return nil
end

ns.FindOwnedCombatPotionFallbackItem = function()
    if not (C_Container and C_Container.GetContainerNumSlots and GetPotionTooltipClass) then
        return nil
    end

    local function ResolveCandidate(candidateItemID)
        candidateItemID = NormalizeItemID and ns.NormalizeItemID(candidateItemID) or candidateItemID
        if not candidateItemID or not PotionMatchesSelectedQuality(candidateItemID)
            or GetTrackerOwnedItemCount(candidateItemID) <= 0 then return nil end
        if GetFallbackItemCooldownDuration(candidateItemID) ~= 300 then return nil end
        if GetPotionTooltipClass(candidateItemID) ~= 'combat' then return nil end
        return candidateItemID
    end

    local function ScanBag(bagID)
        local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            local foundItemID = ResolveCandidate((info and info.itemID) or C_Container.GetContainerItemID(bagID, slot))
            if foundItemID then return foundItemID end
        end
        return nil
    end

    local maxBag = NUM_BAG_SLOTS or 4
    for bagID = 0, maxBag do
        local foundItemID = ScanBag(bagID)
        if foundItemID then return foundItemID end
    end
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then
        return ScanBag(Enum.BagIndex.ReagentBag)
    end
    return nil
end

local POTION_TRACKER_PREPOT_SET = {}
for _, itemID in ipairs(POTION_TRACKER_PREPOT_PRIORITY) do
    POTION_TRACKER_PREPOT_SET[itemID] = true
end

local POTION_TRACKER_HEALTH_SET = {}
for _, itemID in ipairs(POTION_TRACKER_HEALTH_PRIORITY) do
    POTION_TRACKER_HEALTH_SET[itemID] = true
end

local POTION_TRACKER_HEALTHSTONE_SET = {}
for _, item in ipairs(HEALTH_ITEMS) do
    if item and item.cooldown == 60 and item.itemID then
        POTION_TRACKER_HEALTHSTONE_SET[item.itemID] = true
    end
end

-- Auto potion tracking uses stable semantic slots instead of persisting the
-- concrete item IDs currently found in the bags. Swapping potion ranks or
-- rearranging stacks now only changes the item displayed by a slot; it does
-- not rebuild or reorder the custom bar.
local POTION_TRACKER_SLOT_IDS = {
    combat = -1001,
    health = -1002,
    healthstone = -1003,
    mana = -1004,
}
local POTION_TRACKER_SLOT_ORDER = {
    POTION_TRACKER_SLOT_IDS.combat,
    POTION_TRACKER_SLOT_IDS.health,
    POTION_TRACKER_SLOT_IDS.healthstone,
    POTION_TRACKER_SLOT_IDS.mana,
}
local POTION_TRACKER_SLOT_BY_ID = {
    [POTION_TRACKER_SLOT_IDS.combat] = "combat",
    [POTION_TRACKER_SLOT_IDS.health] = "health",
    [POTION_TRACKER_SLOT_IDS.healthstone] = "healthstone",
    [POTION_TRACKER_SLOT_IDS.mana] = "mana",
}
local POTION_TRACKER_SLOT_LABELS = {
    combat = "Combat Potion",
    health = "Health Potion",
    healthstone = "Healthstone",
    mana = "Mana Potion",
}
local potionTrackerSlotItems = {}
local potionTrackerSlotCacheReady = {}

ns.POTION_TRACKER_SLOT_IDS = POTION_TRACKER_SLOT_IDS
ns.POTION_TRACKER_SLOT_ORDER = POTION_TRACKER_SLOT_ORDER
ns.IsPotionTrackerSlotID = function(identifier)
    return POTION_TRACKER_SLOT_BY_ID[identifier] ~= nil
end
ns.GetPotionTrackerSlotKey = function(identifier)
    return POTION_TRACKER_SLOT_BY_ID[identifier]
end
ns.GetPotionTrackerSlotLabel = function(identifier)
    local slotKey = POTION_TRACKER_SLOT_BY_ID[identifier] or identifier
    return POTION_TRACKER_SLOT_LABELS[slotKey]
end

local function GetActiveSyntheticPotionForClass(expectedClass)
    local state = ns.CDMGetActiveSyntheticItemCooldownState
        and ns.CDMGetActiveSyntheticItemCooldownState("potion")
    local itemID = state and state.itemID
    if itemID and GetPotionTooltipClass
        and GetPotionTooltipClass(itemID) == expectedClass
        and PotionMatchesSelectedQuality(itemID) then
        return itemID
    end
    return nil
end

local function ResolvePotionTrackerSlotItemFresh(slotKey)
    local class = playerIdentity.class or select(2, UnitClass("player"))

    if slotKey == "combat" then
        return ChooseTrackerItemFromPriority(POTION_TRACKER_PREPOT_PRIORITY, "potion")
            or GetActiveSyntheticPotionForClass("combat")
            or (ns.FindOwnedCombatPotionFallbackItem and ns.FindOwnedCombatPotionFallbackItem())
    elseif slotKey == "health" then
        return ChooseTrackerItemFromPriority(POTION_TRACKER_HEALTH_PRIORITY, "potion")
            or GetActiveSyntheticPotionForClass("health")
            or (ns.FindOwnedHealthPotionFallbackItem and ns.FindOwnedHealthPotionFallbackItem())
    elseif slotKey == "healthstone" then
        local priority = POTION_TRACKER_HEALTHSTONE_PRIORITY_BY_CLASS[class]
            or POTION_TRACKER_HEALTHSTONE_PRIORITY_BY_CLASS.DEFAULT
        return ChooseTrackerItemFromPriority(priority, "healthstone")
    elseif slotKey == "mana" then
        return GetActiveSyntheticPotionForClass("mana")
            or (ns.FindOwnedManaPotionFallbackItem and ns.FindOwnedManaPotionFallbackItem())
    end

    return nil
end

local function RefreshPotionTrackerSlotItems()
    for slotKey in pairs(POTION_TRACKER_SLOT_IDS) do
        potionTrackerSlotItems[slotKey] = ResolvePotionTrackerSlotItemFresh(slotKey) or false
        potionTrackerSlotCacheReady[slotKey] = true
    end
end

ns.ResolvePotionTrackerSlotItem = function(identifier)
    local slotKey = POTION_TRACKER_SLOT_BY_ID[identifier] or identifier
    if not POTION_TRACKER_SLOT_IDS[slotKey] then
        return nil
    end
    if not potionTrackerSlotCacheReady[slotKey] then
        potionTrackerSlotItems[slotKey] = ResolvePotionTrackerSlotItemFresh(slotKey) or false
        potionTrackerSlotCacheReady[slotKey] = true
    end
    return potionTrackerSlotItems[slotKey] or nil
end

ns.ShouldShowPotionTrackerItem = function(itemID)
    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    if not normalizedItemID then return false end
    if not POTION_TRACKER_HEALTHSTONE_SET[normalizedItemID]
        and not PotionMatchesSelectedQuality(normalizedItemID) then
        return false
    end
    if GetTrackerOwnedItemCount(normalizedItemID) > 0 then return true end

    local syntheticGroup = GetSyntheticItemCooldownGroup(normalizedItemID)
    local state = syntheticGroup and ns.CDMGetActiveSyntheticItemCooldownState
        and ns.CDMGetActiveSyntheticItemCooldownState(syntheticGroup)
    local syntheticItemID = state and state.itemID
    syntheticItemID = NormalizeItemID and ns.NormalizeItemID(syntheticItemID) or syntheticItemID
    return syntheticItemID == normalizedItemID
end

ns.ResolvePotionTrackerDisplayItem = function(itemID)
    local normalizedItemID = NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
    if not normalizedItemID then
        return nil
    end

    local class = playerIdentity.class or select(2, UnitClass("player"))

    if POTION_TRACKER_PREPOT_SET[normalizedItemID] then
        return ChooseTrackerItemFromPriority(POTION_TRACKER_PREPOT_PRIORITY, "potion")
    end

    if POTION_TRACKER_HEALTH_SET[normalizedItemID] then
        return ChooseTrackerItemFromPriority(POTION_TRACKER_HEALTH_PRIORITY, "potion")
            or (ns.FindOwnedHealthPotionFallbackItem and ns.FindOwnedHealthPotionFallbackItem())
    end

    if POTION_TRACKER_HEALTHSTONE_SET[normalizedItemID] then
        local healthStonePriority = POTION_TRACKER_HEALTHSTONE_PRIORITY_BY_CLASS[class]
            or POTION_TRACKER_HEALTHSTONE_PRIORITY_BY_CLASS.DEFAULT
        return ChooseTrackerItemFromPriority(healthStonePriority, "healthstone")
    end

    local potionCfg = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
        and KUI_CDM.db.profile.customTracker and KUI_CDM.db.profile.customTracker.potion
    if potionCfg and potionCfg.trackManaPotion == true
        and GetPotionTooltipClass and GetPotionTooltipClass(normalizedItemID) == "mana" then
        return (ns.FindOwnedManaPotionFallbackItem and ns.FindOwnedManaPotionFallbackItem()) or normalizedItemID
    end

    return normalizedItemID
end
local _potionTooltipCache = {}
ns.InvalidatePotionTooltipCache = function(itemID)
    local normalizedItemID = ns.NormalizeItemID and ns.NormalizeItemID(itemID)
    if normalizedItemID then
        _potionTooltipCache[normalizedItemID] = nil
    else
        wipe(_potionTooltipCache)
    end
end
ns.CDMPotionKeywordsHealth = ns.CDMPotionKeywordsHealth or {
    "health", "healing", "restore", "restores", "salud", "vida", "cura", "curaci", "recupera"
}
ns.CDMPotionKeywordsMana = ns.CDMPotionKeywordsMana or {
    "mana", "man"
}
ns.CDMPotionKeywordsCombat = ns.CDMPotionKeywordsCombat or {
    "primary stat", "primary stats", "secondary stat", "secondary stats", "associated secondary stats",
    "critical strike", "haste", "mastery", "versatility", "agility", "strength", "intellect",
}
ns.CDMPotionKeywordsPotionLike = ns.CDMPotionKeywordsPotionLike or {
    "potion", "poci", "draught", "elixir", "tempered", "templada"
}
ns.CDMPotionKeywordsExclude = ns.CDMPotionKeywordsExclude or {
    "tongues", "lenguas", "recipe", "receta", "formula", "design", "schematic",
    "flask", "phial", "frasco", "vial"
}

local function ContainsKeyword(text, keywords)
    if not text then return false end
    local ln = text:lower()
    for _, k in ipairs(keywords) do
        if ln:find(k) then return true end
    end
    return false
end

GetPotionTooltipClass = function(itemID, itemLink)
    local normalizedItemID = ns.NormalizeItemID(itemID or itemLink)
    if not normalizedItemID then return nil end
    if type(itemLink) ~= "string" and type(itemID) == "string" and itemID ~= "" then
        itemLink = itemID
    end
    if _potionTooltipCache[normalizedItemID] ~= nil then
        return _potionTooltipCache[normalizedItemID]
    end

    local foundHealth = false
    local foundMana = false
    local foundCombat = false
    local foundPotionLike = false
    local foundExcluded = false

    local itemName = GetItemInfo and GetItemInfo(normalizedItemID)
    if itemName then
        foundPotionLike = ContainsKeyword(itemName, ns.CDMPotionKeywordsPotionLike) or foundPotionLike
        foundExcluded = ContainsKeyword(itemName, ns.CDMPotionKeywordsExclude) or foundExcluded
        foundHealth = ContainsKeyword(itemName, ns.CDMPotionKeywordsHealth) or foundHealth
        foundMana = ContainsKeyword(itemName, ns.CDMPotionKeywordsMana) or foundMana
    end

    local info = C_TooltipInfo and (itemLink and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(itemLink)
        or (C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(normalizedItemID)))
    if info and info.lines then
        for _, line in ipairs(info.lines) do
            local txt = line.leftText
            if txt then
                foundHealth = ContainsKeyword(txt, ns.CDMPotionKeywordsHealth) or foundHealth
                foundMana = ContainsKeyword(txt, ns.CDMPotionKeywordsMana) or foundMana
                foundCombat = ContainsKeyword(txt, ns.CDMPotionKeywordsCombat) or foundCombat
                foundPotionLike = ContainsKeyword(txt, ns.CDMPotionKeywordsPotionLike) or foundPotionLike
                foundExcluded = ContainsKeyword(txt, ns.CDMPotionKeywordsExclude) or foundExcluded
            end
        end
    end

    -- Only real potions/elixirs qualify. Requiring PotionLike stops bandages,
    -- food, runes and miscellaneous consumables with a "restores health/mana"
    -- line from leaking into the tracker.
    if foundPotionLike and not foundExcluded then
        if foundCombat then
            return "combat"
        end
        if foundHealth and not foundMana then
            return "health"
        end
        if foundMana and not foundHealth then
            return "mana"
        end
    end

    _potionTooltipCache[normalizedItemID] = "unknown"
    return "unknown"
end


-- Curated active defensives. IDs that are not learned by the current
-- character are removed by IsSpellKnownSafe below; keeping the wider list
-- here lets the tracker follow current talent/rank variants instead of
-- silently dying when Blizzard changes the default CDM composition.
local DEFENSIVE_BY_CLASS = {
    DEATHKNIGHT = { 48792, 48707, 55233, 101568 },
    DEMONHUNTER = { 198589, 196555, 187827, 212800, 207771 },
    DRUID       = { 22812, 22842, 61336, 102342, 1261872 },
    EVOKER      = { 404381, 363916, 374349 },
    HUNTER      = { 186265, 109304, 264735 },
    MAGE        = { 45438, 11426, 342246, 414658 },
    MONK        = { 115203, 122783, 122278, 125174, 132578, 322507 },
    PALADIN     = { 642, 498, 31850, 184662, 86659 },
    PRIEST      = { 47585, 33206, 19236, 586, 193065, 27827 },
    ROGUE       = { 31224, 5277, 1966, 185311 },
    SHAMAN      = { 108271, 260881 },
    WARLOCK     = { 104773, 108416, 132413, 387636, 389614 },
    WARRIOR     = { 871, 184364, 12975, 118038, 190456, 147833, 385391 },
}

local DEFENSIVE_EXCLUDES = {
    [20484] = true, -- Rebirth
    [2006]  = true, -- Resurrection
    [2008]  = true, -- Ancestral Spirit
    [7328]  = true, -- Redemption
    [50769] = true, -- Revive
}

-- KUI Custom Tracker -> backing CDM bars
local KUI_TRACKER_DEFS = {
    interrupt = { key = "kui_interrupt", name = "KUI Interrupt", side = "TOPRIGHT_OUT", defX = 0, defY = 6, kuiSide = "TOPRIGHT_OUT", kuiDefX = 0, kuiDefY = 6, defaultSpacing = 2 },
    defensive = { key = "kui_defensive", name = "KUI Defensive", side = "TOPRIGHT_OUT", defX = 0, defY = 4, kuiSide = "TOPRIGHT_OUT", kuiDefX = 0, kuiDefY = 4, defaultSpacing = 0 },
    trinket   = { key = "kui_trinket", name = "KUI Trinket", side = "BOTTOMRIGHT_OUT", defX = 0, defY = -4, kuiSide = "BOTTOMRIGHT_OUT", kuiDefX = 0, kuiDefY = -4, defaultSpacing = 0 },
    potion    = { key = "kui_potion", name = "KUI Potions", side = "BOTTOMLEFT_OUT", defX = 0, defY = -4, kuiSide = "BOTTOMLEFT_OUT", kuiDefX = 1, kuiDefY = -4, defaultSpacing = 0 },
}
local KUI_TRACKER_ORDER = { "defensive", "interrupt", "trinket", "potion" }
local KUI_TRACKER_BY_BAR = {}
for k, def in pairs(KUI_TRACKER_DEFS) do
    KUI_TRACKER_BY_BAR[def.key] = k
end

local function TrackerDebugOnce(tag, msg)
    if not KUI_CDM or not msg then return end
    KUI_CDM._trackerDebugOnce = KUI_CDM._trackerDebugOnce or {}
    if KUI_CDM._trackerDebugOnce[tag] then return end
    KUI_CDM._trackerDebugOnce[tag] = true
    -- if KT and KT.Print then KT:Print(msg) end -- Silenced per user request
end

local INTERRUPTS_BY_CLASS = {
    DEATHKNIGHT = { 47528 },
    DEMONHUNTER = { 183752 },
    DRUID = { 106839, 78675 },
    EVOKER = { 351338 },
    HUNTER = { 147362, 187707 },
    MAGE = { 2139 },
    MONK = { 116705, 173320 },
    PALADIN = { 96231 },
    PRIEST = { 15487 },
    ROGUE = { 1766 },
    SHAMAN = { 57994 },
    WARLOCK = { 119898, 19647, 115781, 119910 },
    WARRIOR = { 6552 },
}

local function IsSpellKnownSafe(spellID)
    if not spellID or spellID <= 0 then return false end

    local function ReadKnown(fn, ...)
        if not fn then return false end
        local ok, known = pcall(fn, ...)
        if not ok or (issecretvalue and issecretvalue(known)) then
            return false
        end
        return known == true
    end

    if ReadKnown(IsPlayerSpell, spellID) then return true end
    if ReadKnown(IsSpellKnown, spellID, false) then return true end
    if C_Spell and ReadKnown(C_Spell.IsSpellKnown, spellID) then return true end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook
        and ReadKnown(C_SpellBook.IsSpellInSpellBook, spellID) then
        return true
    end

    -- CDM is a reliable fallback for racials and talent variants while the
    -- spellbook is being rebuilt after SPELLS_CHANGED.
    if ns.IsSpellKnownInCDM then
        local ok, known = pcall(ns.IsSpellKnownInCDM, spellID)
        if ok and known == true then return true end
    end
    return false
end

local function TrackerSpellKey(spellOrItemID)
    return tostring(spellOrItemID or "")
end

local function IsTrackerSpellSuppressed(trackerKey, spellOrItemID)
    local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
    local ct = p and p.customTracker and p.customTracker[trackerKey]
    local removed = ct and ct.removedAutoSpells
    return removed and removed[TrackerSpellKey(spellOrItemID)] == true or false
end

local function SetTrackerSpellSuppressed(trackerKey, spellOrItemID, suppressed)
    local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
    local ct = p and p.customTracker and p.customTracker[trackerKey]
    if not ct or spellOrItemID == nil then return end
    ct.removedAutoSpells = ct.removedAutoSpells or {}
    local key = TrackerSpellKey(spellOrItemID)
    if suppressed then
        ct.removedAutoSpells[key] = true
    else
        ct.removedAutoSpells[key] = nil
    end
end
ns.SetTrackerSpellSuppressed = SetTrackerSpellSuppressed

local function FilterTrackerAutoSpells(trackerKey, list)
    if type(list) ~= "table" then return list end
    local filtered = {}
    for i = 1, #list do
        local id = list[i]
        if not IsTrackerSpellSuppressed(trackerKey, id) then
            filtered[#filtered + 1] = id
        end
    end
    return filtered
end


local function BuildAutoTrackerSpells(trackerKey)
    local out, seen = {}, {}
    local class = playerIdentity.class or select(2, UnitClass("player"))
    local race = playerIdentity.race or select(2, UnitRace("player"))
    local function ChoosePreferredItem(currentID, candidateID, rankMap)
        if not candidateID then return currentID end
        if not currentID then return candidateID end

        local currentRank = (rankMap and rankMap[currentID]) or 999999
        local candidateRank = (rankMap and rankMap[candidateID]) or 999999
        if candidateRank < currentRank then
            return candidateID
        end
        if candidateRank == currentRank and candidateID < currentID then
            return candidateID
        end
        return currentID
    end

    if trackerKey == "interrupt" then
        local list = class and INTERRUPTS_BY_CLASS[class]
        if list then
            for _, sid in ipairs(list) do
                if IsSpellKnownSafe(sid) then
                    out[#out + 1] = sid
                end
            end
        end
    elseif trackerKey == "defensive" then
        local defList, racialList = {}, {}
        local classList = class and DEFENSIVE_BY_CLASS[class]
        if classList then
            for _, sid in ipairs(classList) do
                if IsSpellKnownSafe(sid) then
                    defList[#defList + 1] = sid
                end
            end
        end
        if #defList == 0 then
            local party = KT and KT.db and KT.db.profile and KT.db.profile.partyTracker
            local spellMap = party and party.spells
            if spellMap then
                for sid in pairs(spellMap) do
                    if not DEFENSIVE_EXCLUDES[sid] and IsSpellKnownSafe(sid) then
                        defList[#defList + 1] = sid
                    end
                end
            end
        end
    if race and ns.RACE_RACIALS[race] then
        for _, entry in ipairs(ns.RACE_RACIALS[race]) do
                local sid = type(entry) == "table" and entry[1] or entry
                local reqClass = type(entry) == "table" and entry.class or nil
                if sid and (not reqClass or reqClass == class) and IsSpellKnownSafe(sid) then
                    racialList[#racialList + 1] = sid
                end
            end
        end
        local function SortByBaseCD(a, b)
            local function ReadBaseCooldown(spellID)
                if not GetSpellBaseCooldown then return 0 end
                local ok, value = pcall(GetSpellBaseCooldown, spellID)
                if not ok or (issecretvalue and issecretvalue(value)) then return 0 end
                return type(value) == "number" and value or 0
            end

            local ca = ReadBaseCooldown(a)
            local cb = ReadBaseCooldown(b)
            if ca ~= cb then return ca > cb end

            local function ReadSpellName(spellID)
                if not (C_Spell and C_Spell.GetSpellName) then
                    return tostring(spellID)
                end
                local ok, value = pcall(C_Spell.GetSpellName, spellID)
                if ok and type(value) == "string"
                    and not (issecretvalue and issecretvalue(value)) then
                    return value
                end
                return tostring(spellID)
            end

            return ReadSpellName(a) < ReadSpellName(b)
        end
        table.sort(defList, SortByBaseCD)
        table.sort(racialList, SortByBaseCD)
        if defList[1] then
            out[#out + 1] = defList[1]
            seen[defList[1]] = true
        end
        if racialList[1] and not seen[racialList[1]] then
            out[#out + 1] = racialList[1]
            seen[racialList[1]] = true
        end
    elseif trackerKey == "trinket" then
        out[1] = -13
        out[2] = -14
    elseif trackerKey == "potion" then
        RefreshPotionTrackerSlotItems()
        out[#out + 1] = POTION_TRACKER_SLOT_IDS.combat
        out[#out + 1] = POTION_TRACKER_SLOT_IDS.health
        out[#out + 1] = POTION_TRACKER_SLOT_IDS.healthstone

        -- Mana potion is opt-in (off by default) via KUI Tracker -> Potions.
        local ct = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
            and KUI_CDM.db.profile.customTracker
        if ct and ct.potion and ct.potion.trackManaPotion == true then
            out[#out + 1] = POTION_TRACKER_SLOT_IDS.mana
        end
    end

    return FilterTrackerAutoSpells(trackerKey, out)
end
ns.BuildAutoTrackerSpells = BuildAutoTrackerSpells

local function EnsureCustomTrackerDefaults(p)
    if not p.customTracker then
        p.customTracker = {}
    end
    local hasKUIUF = _G["KullThranUI_UF_Player"] or (KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
        and KT.db.profile.unitFrames.enable ~= false
        and KT.db.profile.unitFrames.enabledFrames and KT.db.profile.unitFrames.enabledFrames.player ~= false)
    for _, key in ipairs(KUI_TRACKER_ORDER) do
        local def = KUI_TRACKER_DEFS[key]
        local defSide = hasKUIUF and def.kuiSide or def.side
        local defX = hasKUIUF and def.kuiDefX or def.defX
        local defY = hasKUIUF and def.kuiDefY or def.defY
        if not p.customTracker[key] then
            p.customTracker[key] = {
                enabled = true,
                size = (key == "interrupt") and 52 or 36,
                showText = false,
                x = defX,
                y = defY,
                side = defSide,
                auto = true,
                maxIcons = (key == "interrupt") and 1 or ((key == "potion") and 3 or 2),
                spells = {},
            }
        else
            local ct = p.customTracker[key]
            if ct.enabled == nil then ct.enabled = true end
            if ct.size == nil then ct.size = (key == "interrupt") and 52 or 36 end
            if key == "interrupt" and (ct.size == 36 or ct.size == 42) then ct.size = 52 end
            if ct.showText == nil then ct.showText = true end
            if (ct.x == nil and ct.y == nil)
                or (ct.x == 24 and ct.y == 0)
                or (ct.x == 24 and ct.y == -42)
                or (ct.x == -24 and ct.y == -42)
                or (ct.x == 0 and ct.y == 32)
                or (ct.x == 0 and ct.y == 44)
                or (ct.x == 60 and ct.y == -6)
                or (ct.x == 60 and ct.y == -52)
                or (ct.x == -60 and ct.y == -52)
                or (ct.x == 0 and ct.y == 2)
                or (ct.x == 2 and ct.y == 0)
                or (ct.x == 2 and ct.y == -38)
                or (ct.x == -2 and ct.y == -38)
                or (ct.x == 0 and ct.y == 38)
                or (ct.x == 0 and ct.y == 0)
                or (ct.x == 0 and ct.y == -38)
                or (ct.x == 0 and ct.y == 2)
                or (ct.x == 0 and ct.y == 4)
                or (ct.x == 0 and ct.y == -4)
                or (ct.x == -6 and ct.y == 6)
                or (ct.x == -6 and ct.y == 4)
                or (ct.x == -6 and ct.y == -4)
                or (ct.x == 8 and ct.y == -4)
                or (ct.x == 3 and ct.y == -4)
            then
                ct.x = defX
                ct.y = defY
                ct.side = defSide
            else
                if ct.x == nil then ct.x = defX end
                if ct.y == nil then ct.y = defY end
            end
            if ct.side == nil then ct.side = defSide end
            if key == "interrupt" and ct.side == "TOP" then ct.side = defSide end
            if (key == "defensive" or key == "interrupt") and (ct.side == "TOPRIGHT") then
                ct.side = defSide
            end
            if ct.auto == nil then ct.auto = true end
            if ct.maxIcons == nil then
                ct.maxIcons = (key == "interrupt") and 1 or ((key == "potion") and 3 or 2)
            end
            if not ct.spells then ct.spells = {} end
            if key == "potion" and ct.potionSlotVersion == nil then
                -- Older profiles could enable mana while retaining the old
                -- three-icon limit, which made the fourth entry impossible to
                -- see. Apply this once without overriding later user choices.
                if ct.trackManaPotion == true and (ct.maxIcons or 3) < 4 then
                    ct.maxIcons = 4
                end
                ct.potionSlotVersion = 1
            end
            if key == "potion" then
                local quality = tostring(ct.potionQuality or "highest")
                if quality ~= "highest" and quality ~= "1" and quality ~= "2" and quality ~= "3" then
                    quality = "highest"
                end
                ct.potionQuality = quality
            end
        end
        p.customTracker[key].removedAutoSpells = p.customTracker[key].removedAutoSpells or {}
    end
end

local function SyncKUITrackerBars(syncMode)
    if not KUI_CDM.db or not KUI_CDM.db.profile then return end
    local p = KUI_CDM.db.profile
    local hasUUF = C_AddOns.IsAddOnLoaded("UnhaltedUnitFrames")
    local hasKUIUF = _G["KullThranUI_UF_Player"] or (KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
        and KT.db.profile.unitFrames.enable ~= false
        and KT.db.profile.unitFrames.enabledFrames and KT.db.profile.unitFrames.enabledFrames.player ~= false)
    local hasIntegratedUF = hasUUF or hasKUIUF
    EnsureCustomTrackerDefaults(p)
    if not p.cdmBars or not p.cdmBars.bars then return end

    local byKey = {}
    for _, b in ipairs(p.cdmBars.bars) do
        if type(b) == "table" and type(b.key) == "string" and b.key ~= "" then
            byKey[b.key] = b
        end
    end

    for _, tKey in ipairs(KUI_TRACKER_ORDER) do
        local def = KUI_TRACKER_DEFS[tKey]
        if def then
            local defSide = hasKUIUF and def.kuiSide or def.side
            local defX = hasKUIUF and def.kuiDefX or def.defX
            local defY = hasKUIUF and def.kuiDefY or def.defY
            local ct = p.customTracker[tKey]
            local barKey = def.key
            local bd = byKey[barKey]

            local needsAuto = (ct.auto ~= false)
            -- SPELLS_CHANGED only affects spell-backed trackers.  Re-scanning
            -- bags and classifying potion tooltips on this very noisy event was
            -- responsible for 50-74ms stalls in combat.
            local refreshAuto = syncMode ~= "spells"
                or tKey == "interrupt"
                or tKey == "defensive"
            if needsAuto and refreshAuto then
                local previousSpells = ct.spells
                local detectedSpells = BuildAutoTrackerSpells(tKey)
                if tKey == "potion" then
                    ct.spells = detectedSpells or {}
                elseif detectedSpells and #detectedSpells > 0 then
                    ct.spells = detectedSpells
                elseif type(previousSpells) == "table" and #previousSpells > 0 then
                    -- Do not erase a working tracker during a transient CDM
                    -- spellbook rebuild. SPELLS_CHANGED retries detection.
                    ct.spells = FilterTrackerAutoSpells(tKey, previousSpells)
                else
                    ct.spells = detectedSpells or {}
                end
            elseif not ct.spells then
                ct.spells = {}
            end
            if (not ct.spells or #ct.spells == 0) then
                TrackerDebugOnce(
                    "kui_autofail_" .. tKey,
                    string.format("KUI Tracker '%s' sin spells detectados (auto=%s).", tKey, tostring(ct.auto))
                )
            end

            if tKey == "defensive" and ct.spells and #ct.spells > 2 then
                ct.spells = { ct.spells[1], ct.spells[2] }
            end

            if tKey == "trinket" then
                local has13, has14 = false, false
                for _, sid in ipairs(ct.spells) do
                    if sid == -13 then has13 = true end
                    if sid == -14 then has14 = true end
                end
                if not has13 then table.insert(ct.spells, 1, -13) end
                if not has14 then table.insert(ct.spells, 2, -14) end
            end

            if not bd then
                local src = p.cdmBars.barDefaults or {}
                bd = {}
                for k, v in pairs(src) do
                    if type(v) == "table" then
                        local t = {}
                        for k2, v2 in pairs(v) do t[k2] = v2 end
                        bd[k] = t
                    else
                        bd[k] = v
                    end
                end
                bd.key = barKey
                bd.name = def.name
                bd.enabled = true
                bd.barType = "custom"
                bd.customSpells = {}
                bd.isKUITracker = true
                table.insert(p.cdmBars.bars, bd)
                byKey[barKey] = bd
            end

            bd.enabled = ct.enabled ~= false
            bd.iconSize = ct.size or bd.iconSize or 36
            local maxIcons = tonumber(ct.maxIcons) or ((tKey == "interrupt") and 1 or ((tKey == "potion") and 3 or 2))
            if tKey == "interrupt" then
                maxIcons = 1
            elseif tKey == "trinket" then
                maxIcons = math.max(1, math.min(2, maxIcons))
            else
                maxIcons = math.max(1, math.min(6, maxIcons))
            end
            ct.maxIcons = maxIcons
            bd.maxIcons = maxIcons
            bd.showCooldownText = (tKey == "potion") and true or (ct.showText ~= false)
            if bd.showKeybind == nil then
                bd.showKeybind = (tKey == "potion" or tKey == "trinket")
            end
            bd.showCharges = true
            if tKey == "potion" then
                bd.desaturateOnCD = true
            end
            local side = ct.side or defSide
            local grow = "RIGHT"
            if side == "RIGHT" or side == "TOPRIGHT" or side == "BOTTOMRIGHT" or side == "TOPRIGHT_OUT" or side == "BOTTOMRIGHT_OUT" then
                grow = "LEFT"
            elseif side == "LEFT" or side == "TOPLEFT" or side == "BOTTOMLEFT" or side == "TOPLEFT_OUT" or side == "BOTTOMLEFT_OUT" then
                grow = "RIGHT"
            end
            bd.growDirection = grow
            bd.growCentered = false
            bd.numRows = 1
            if bd.spacingCustomized then
                bd.spacing = bd.spacing or def.defaultSpacing or 2
            else
                bd.spacing = def.defaultSpacing or 2
            end
            bd.barScale = bd.barScale or 1.0
            local offX = ct.x or defX
            local offY = ct.y or defY
            if not hasIntegratedUF then
                side = defSide
                offX = defX
                offY = defY
                ct.side = side
                ct.x = offX
                ct.y = offY
            end
            bd.playerFrameSide = side
            bd.playerFrameOffsetX = offX
            bd.playerFrameOffsetY = offY

            if tKey == "interrupt" then
                local defBd = byKey[KUI_TRACKER_DEFS.defensive.key]
                if hasIntegratedUF and defBd and defBd.enabled ~= false then
                    bd.anchorTo = KUI_TRACKER_DEFS.defensive.key
                    bd.anchorPosition = "topright"
                    bd.anchorOffsetX = 0
                    bd.anchorOffsetY = 12
                else
                    bd.anchorTo = "playerframe"
                end
            else
                bd.anchorTo = "playerframe"
            end
            -- Dedup the tracker's own spell list every sync (by string key) so the
            -- same spell/item can never be rendered twice, even if a previous
            -- version of the drag-and-drop handler wrote a duplicate entry.
            do
                local cleaned = {}
                local cseen = {}
                for _, sid in ipairs(ct.spells or {}) do
                    local k = tostring(sid or "")
                    if k ~= "" and not cseen[k] then
                        cseen[k] = true
                        cleaned[#cleaned + 1] = sid
                    end
                end
                ct.spells = cleaned
            end
            bd.customSpells = ct.spells or {}
            bd.isKUITracker = true
            if bd.isKUITracker then
                local list = ct.spells or {}
                local sample = {}
                for i = 1, math.min(4, #list) do
                    sample[#sample + 1] = tostring(list[i])
                end
                TrackerDebugOnce(
                    "kui_sync_" .. tKey,
                    string.format(
                        "KUI Tracker '%s': enabled=%s auto=%s spells=%d [%s] size=%d side=%s x=%d y=%d anchorTo=%s anchorPos=%s",
                        tKey, tostring(ct.enabled ~= false), tostring(ct.auto ~= false), #list, table.concat(sample, ","),
                        bd.iconSize or 0, tostring(side), offX or 0, offY or 0, tostring(bd.anchorTo),
                        tostring(bd.anchorPosition)
                    )
                )
            end
        end
    end
end
local function SafeSyncKUITrackerBars(syncMode)
    local ok, err = pcall(SyncKUITrackerBars, syncMode)
    if not ok then
        KUI_CDM._trackerSyncLastError = {
            message = err,
            time = GetTime(),
        }
        return false
    end
    KUI_CDM._trackerSyncLastError = nil
    return true
end
ns.SyncKUITrackerBars = SafeSyncKUITrackerBars
-- Coalesce tracker sync: BAG_UPDATE_DELAYED / ITEM_PUSH / equip / cast bursts
-- (each keystroke that interacts with an item can fire several of these) used to
-- trigger the full bag scan + tooltip classify every time via BuildAutoTrackerSpells
-- for the potion tracker.  Tracker composition is not combat-critical, so defer
-- the expensive work until combat ends and run a whole burst only once.
local _trackerSyncPending = false
local _trackerSyncDeferred = false
local _trackerSyncNeedsFull = false
local _trackerSyncUpdateReason
ns.ScheduleKUITrackerSync = function(delay, updateReason, syncMode)
    if syncMode ~= "spells" then
        _trackerSyncNeedsFull = true
    end
    if updateReason then
        _trackerSyncUpdateReason = updateReason
    end

    if InCombatLockdown and InCombatLockdown() then
        _trackerSyncDeferred = true
        return
    end
    if _trackerSyncPending then return end
    _trackerSyncPending = true
    C_Timer.After(delay or 0.15, function()
        _trackerSyncPending = false
        if InCombatLockdown and InCombatLockdown() then
            _trackerSyncDeferred = true
            return
        end

        local mode = _trackerSyncNeedsFull and nil or "spells"
        local reason = _trackerSyncUpdateReason
        _trackerSyncNeedsFull = false
        _trackerSyncUpdateReason = nil
        _trackerSyncDeferred = false
        if ns.SyncKUITrackerBars then ns.SyncKUITrackerBars(mode) end
        if reason and ns.RequestCustomCooldownUpdate then
            ns.RequestCustomCooldownUpdate(reason)
        end
    end)
end
ns.FlushDeferredKUITrackerSync = function()
    if not _trackerSyncDeferred then return false end
    _trackerSyncDeferred = false
    local mode = _trackerSyncNeedsFull and nil or "spells"
    ns.ScheduleKUITrackerSync(0.12, _trackerSyncUpdateReason or "tracker_post_combat", mode)
    return true
end
ns.KUI_TRACKER_BY_BAR = KUI_TRACKER_BY_BAR
ns.TrackerDebugOnce = TrackerDebugOnce
end

local BuildCDMBar, LayoutCDMBar, UpdateCDMBarIcons, HideBlizzardCDM, RestoreBlizzardCDM
local CaptureCDMPositions, ApplyCDMBarPosition, ApplyShapeToCDMIcon

-------------------------------------------------------------------------------
--  Capture Blizzard CDM positions
-------------------------------------------------------------------------------
CaptureCDMPositions = function()
    local captured = {}
    local uiW, uiH = UIParent:GetSize()
    local uiScale = UIParent:GetEffectiveScale()

    for barKey, frameName in pairs(ns.BLIZZ_CDM_FRAMES) do
        local frame = _G[frameName]
        if frame then
            local data = {}

            local frameScale = frame:GetScale()
            if frameScale and frameScale > 0.1 then
                data.barScale = frameScale
            end

            local childCount = frame:GetNumChildren()
            local numDistinctY = {}
            local shownIcons = {}
            for ci = 1, childCount do
                local child = select(ci, frame:GetChildren())
                if child and child.Icon then
                    local cw = child:GetWidth()
                    local cs = child:GetScale()
                    if cw and cw > 1 and not data.iconSize then
                        local visual = cw * (cs or 1)
                        data.iconSize = math.floor(visual + 0.5)
                    end
                    if child:IsShown() then
                        shownIcons[#shownIcons + 1] = child
                        if child:GetPoint(1) then
                            local _, _, _, _, cy = child:GetPoint(1)
                            if cy then
                                numDistinctY[math.floor(cy + 0.5)] = true
                            end
                        end
                    end
                end
            end

            if #shownIcons >= 2 and data.iconSize then
                table.sort(shownIcons, function(a, b)
                    return (a:GetLeft() or 0) < (b:GetLeft() or 0)
                end)
                local bestStep = nil
                for si = 1, #shownIcons - 1 do
                    local aLeft = shownIcons[si]:GetLeft()
                    local bLeft = shownIcons[si + 1]:GetLeft()
                    if aLeft and bLeft then
                        local dist = bLeft - aLeft
                        if dist > 0 and (not bestStep or dist < bestStep) then
                            bestStep = dist
                        end
                    end
                end
                if bestStep then
                    local frameEff = frame:GetEffectiveScale()
                    local uiEff = UIParent:GetEffectiveScale()
                    local parentStep = bestStep * uiEff / frameEff
                    local cs = shownIcons[1]:GetScale() or 1
                    local stepInIconUnits = parentStep * cs
                    local gap = stepInIconUnits - data.iconSize
                    if gap < 0 then gap = 0 end
                    data.spacing = math.floor(gap + 0.5)
                end
            end

            local rowCount = 0
            for _ in pairs(numDistinctY) do rowCount = rowCount + 1 end
            if rowCount >= 1 then
                data.numRows = rowCount
            end

            if frame.isHorizontal ~= nil then
                data.isHorizontal = frame.isHorizontal
            end

            if frame:GetPoint(1) then
                local cx, cy = frame:GetCenter()
                if cx and cy then
                    local bScale = frame:GetEffectiveScale()
                    cx = cx * bScale / uiScale
                    cy = cy * bScale / uiScale
                    data.point = "CENTER"
                    data.relPoint = "CENTER"
                    data.x = cx - (uiW / 2)
                    data.y = cy - (uiH / 2)
                end
            end

            captured[barKey] = data
        end
    end

    return captured
end

-------------------------------------------------------------------------------
--  Hide / Restore Blizzard CDM
-------------------------------------------------------------------------------
local function SuppressBlizzardCDMEditModeFrame(frame)
    if not frame then return end
    if frame.Selection then
        frame.Selection:Hide()
        frame.Selection:SetAlpha(0)
    end
    if frame.isSelected then
        frame.isSelected = false
    end
    if frame.isHighlighted then
        frame.isHighlighted = false
    end
end

local function InstallBlizzardCDMSuppressionHooks(frame)
    if not frame or frame._kuiSuppressionHooked then return end
    frame._kuiSuppressionHooked = true

    if frame.Selection then
        hooksecurefunc(frame.Selection, "Show", function(self)
            if KT and KT:IsBlizzardEditModeActive() then
                self:Hide()
                self:SetAlpha(0)
            end
        end)
        hooksecurefunc(frame.Selection, "SetShown", function(self, shown)
            if KT and KT:IsBlizzardEditModeActive() and shown then
                self:Hide()
                self:SetAlpha(0)
            end
        end)
    end
end

function ns.ParkSecondaryCDMViewer(frame)
    if not frame then return end
    frame:SetAlpha(0)
end

function ns.QueueSecondaryCDMViewerPark(frame)
    if not frame then return end
    C_Timer.After(0, function()
        ns.ParkSecondaryCDMViewer(frame)
    end)
end

ns.DebugBlizzardCDMFrameState = function(tag)
    if not KT or not KT.Print then return end
    local names = {
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
        "BuffIconCooldownViewer",
        "BuffBarCooldownViewer",
    }

    for _, frameName in ipairs(names) do
        local frame = _G[frameName]
        if not frame then
            KT:Print(string.format("[CDM DEBUG %s] %s = nil", tostring(tag), frameName))
        else
            local shown = false
            if frame.IsShown then
                shown = frame:IsShown()
            end

            local alpha = 0
            if frame.GetAlpha then
                alpha = frame:GetAlpha()
            end

            local sizeX, sizeY = 0, 0
            if frame.GetSize then
                sizeX, sizeY = frame:GetSize()
            end

            local points = 0
            if frame.GetNumPoints then
                points = frame:GetNumPoints()
            end

            local parent = nil
            if frame.GetParent then
                parent = frame:GetParent()
            end

            local parentName = "nil"
            if parent and parent.GetDebugName then
                parentName = parent:GetDebugName()
            end

            KT:Print(string.format(
                "[CDM DEBUG %s] %s shown=%s alpha=%s size=%sx%s points=%d parent=%s",
                tostring(tag),
                frameName,
                tostring(shown),
                tostring(alpha),
                tostring(sizeX or 0),
                tostring(sizeY or 0),
                points,
                tostring(parentName)
            ))
        end
    end
end

HideBlizzardCDM = function()
    -- The giant edit-mode square is the root Blizzard cooldown-viewer shell,
    -- not the KUI bar. Force every native CDM root frame off-screen and hidden
    -- while the user is in Blizzard Edit Mode.
    for _, frameName in pairs(ns.BLIZZ_CDM_FRAMES) do
        local frame = _G[frameName]
        if frame then
            InstallBlizzardCDMSuppressionHooks(frame)
            if KT and KT:IsBlizzardEditModeActive() then
                SuppressBlizzardCDMEditModeFrame(frame)
            end
        end
    end

    -- BuffBarCooldownViewer is the duplicate presentation of the same buff
    -- catalogue. It is the only viewer parked; KUI claims BuffIcon children.
    for _, frameName in pairs(ns.BLIZZ_CDM_FRAMES_SECONDARY or {}) do
        local frame = _G[frameName]
        if frame then
            frame:SetAlpha(0)
        end
    end
end

RestoreBlizzardCDM = function()
    for _, frameName in pairs(ns.BLIZZ_CDM_FRAMES) do
        local frame = _G[frameName]
        if frame and frame.Selection then
            frame.Selection:Show()
            frame.Selection:SetAlpha(1)
        end
    end
    for _, frameName in pairs(ns.BLIZZ_CDM_FRAMES_SECONDARY or {}) do
        local frame = _G[frameName]
        if frame then
            frame:SetAlpha(1)
        end
    end
    if ns.RestoreNativeCDMFrames then ns.RestoreNativeCDMFrames() end
end

-------------------------------------------------------------------------------
--  CDM Bar Position Helpers
-------------------------------------------------------------------------------
local function ApplyBarPositionCentered(frame, pos, w, h, scale)
    if not pos or not pos.point then return end
    frame:ClearAllPoints()
    if pos.point == "TOPLEFT" and pos.relPoint == "TOPLEFT" then
        local fw, fh = frame:GetWidth() or 0, frame:GetHeight() or 0
        local uiW, uiH = UIParent:GetSize()
        local cx = (pos.x or 0) + fw * 0.5 - uiW * 0.5
        local cy = (pos.y or 0) - fh * 0.5 + uiH * 0.5
        frame:SetPoint("CENTER", UIParent, "CENTER", cx, cy)
        pos.point = "CENTER"
        pos.relPoint = "CENTER"
        pos.x = cx
        pos.y = cy
    else
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    end
end

local function SaveCDMBarPosition(barKey, frame)
    if not frame then return end
    local p = KUI_CDM.db.profile
    local scale = frame:GetScale() or 1
    local cx, cy = frame:GetCenter()
    if not cx then return end
    local uiW, uiH = UIParent:GetSize()
    local uiScale = UIParent:GetEffectiveScale()
    local fScale = frame:GetEffectiveScale()
    cx = cx * fScale / uiScale
    cy = cy * fScale / uiScale
    p.cdmBarPositions[barKey] = {
        point = "CENTER",
        relPoint = "CENTER",
        x = (cx - uiW / 2) / scale,
        y = (cy - uiH / 2) / scale,
    }
end

local function CDMFrameAnchorPoint(anchorSide, grow, centered)
    if centered then
        if anchorSide == "TOP" then return "BOTTOM" end
        if anchorSide == "BOTTOM" then return "TOP" end
        if anchorSide == "LEFT" then return "RIGHT" end
        if anchorSide == "RIGHT" then return "LEFT" end
    end
    if grow == "RIGHT" then return "LEFT" end
    if grow == "LEFT" then return "RIGHT" end
    if grow == "DOWN" then return "TOP" end
    if grow == "UP" then return "BOTTOM" end
    return "LEFT"
end

local function ApplyClickThroughState(rootFrame, clickThrough)
    if not rootFrame then return end

    -- Iterative BFS over the frame tree
    local queue, head, tail = {}, 1, 1
    queue[1] = rootFrame

    while head <= tail do
        local frame = queue[head]; head = head + 1

        -- Aplicar o restaurar estado de mouse
        if clickThrough then
            if frame._cdmMouseWas == nil then frame._cdmMouseWas = frame:IsMouseEnabled() end
            frame:EnableMouse(false)
            if frame.EnableMouseClicks then frame:EnableMouseClicks(false) end
            if frame.EnableMouseMotion then frame:EnableMouseMotion(false) end
        else
            local prev = frame._cdmMouseWas
            if prev ~= nil then frame:EnableMouse(prev); frame._cdmMouseWas = nil end
        end

        -- Encolar hijos directos
        for _, child in ipairs({ frame:GetChildren() }) do
            tail = tail + 1; queue[tail] = child
        end
    end
end

-------------------------------------------------------------------------------
--  Build a single CDM bar frame
-------------------------------------------------------------------------------
BuildCDMBar = function(barIndex)
    local p = KUI_CDM.db.profile
    local bars = p.cdmBars.bars
    local barData = bars[barIndex]
    if not barData then return end

    local key = barData.key
    local frame = cdmBarFrames[key]

    if not frame then
        frame = CreateFrame("Frame", "KUI_CDMBar_" .. key, UIParent)
        ns.CDM_SetProtectedFrameLayering(frame, ns.CDM_ResolveBarStrata(barData, p), 5)
        if frame.EnableMouseClicks then frame:EnableMouseClicks(false) end
        if frame.EnableMouseMotion then frame:EnableMouseMotion(true) end
        frame._barKey = key
        frame._barIndex = barIndex
        frame._clip = CreateFrame("ScrollFrame", nil, frame)
        frame._clip:SetAllPoints(frame)
        frame._clip:SetClipsChildren(true)
        frame._content = CreateFrame("Frame", nil, frame._clip)
        frame._content:SetSize(1, 1)
        frame._clip:SetScrollChild(frame._content)
        cdmBarFrames[key] = frame
        cdmBarIcons[key] = {}
    elseif not frame._content then
        frame._clip = CreateFrame("ScrollFrame", nil, frame)
        frame._clip:SetAllPoints(frame)
        frame._clip:SetClipsChildren(true)
        frame._content = CreateFrame("Frame", nil, frame._clip)
        frame._content:SetSize(1, 1)
        frame._clip:SetScrollChild(frame._content)
    end

    -- Apply strata on every rebuild (in case it changed)
    ns.CDM_ApplyBarStrata(frame, barData, p)

    if not barData.enabled then
        if frame._mouseTrack then
            CDMRT:StopMouseTracking(frame)
            if frame._preMousePos and not p.cdmBarPositions[key] then
                p.cdmBarPositions[key] = frame._preMousePos
            end
            frame._preMousePos = nil
            ApplyClickThroughState(frame, false)
            if frame.EnableMouseMotion then frame:EnableMouseMotion(true) end
        end
        frame:Hide()
        return
    end

    if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        ns._cdmLayoutPending = true
        return
    end

    local scale = barData.barScale or 1.0
    if scale < 0.1 then scale = 1.0 end
    frame:SetScale(scale)

    if frame._mouseTrack then
        CDMRT:StopMouseTracking(frame)
        if frame._preMousePos and not p.cdmBarPositions[key] then
            p.cdmBarPositions[key] = frame._preMousePos
        end
        frame._preMousePos = nil
        ApplyClickThroughState(frame, false)
        if frame.EnableMouseMotion then frame:EnableMouseMotion(true) end
        ns.CDM_ApplyBarStrata(frame, barData, p)
    end

    local anchorKey = barData.anchorTo
    local anchorPos = barData.anchorPosition or "left"
    local oX = barData.anchorOffsetX or 0
    local oY = barData.anchorOffsetY or 0

    -- KUI Tracker should only default to playerframe when it does not already
    -- have an explicit anchor (e.g. interrupt -> defensive, potion -> trinket).
    if barData.isKUITracker and (not anchorKey or anchorKey == "none") then
        local activePF = FindPlayerUnitFrame()
        if not activePF then
            activePF = (ns.CDMGetBlizzardPlayerFrameCandidate and ns.CDMGetBlizzardPlayerFrameCandidate()) or _G["PlayerFrame"]
        end
        if activePF then
            anchorKey = "playerframe"
            barData.anchorTo = "playerframe"
        end
    end

    if anchorKey == "mouse" then
        -- Determine SetPoint anchor and 15px directional nudge
        local pointFrom, baseOX, baseOY, forceGrow
        if anchorPos == "left" then
            pointFrom = "RIGHT"; forceGrow = "LEFT"
            baseOX = -15 + oX; baseOY = oY
        elseif anchorPos == "right" then
            pointFrom = "LEFT"; forceGrow = "RIGHT"
            baseOX = 15 + oX; baseOY = oY
        elseif anchorPos == "top" then
            pointFrom = "BOTTOM"; forceGrow = "UP"
            baseOX = oX; baseOY = 15 + oY
        elseif anchorPos == "bottom" then
            pointFrom = "TOP"; forceGrow = "DOWN"
            baseOX = oX; baseOY = -15 + oY
        else
            pointFrom = "LEFT"; forceGrow = "RIGHT"
            baseOX = 15 + oX; baseOY = oY
        end
        frame._mouseGrow = forceGrow
        -- Elevate to TOOLTIP strata so the bar renders above all UI
        ns.CDM_SetProtectedFrameLayering(frame, "TOOLTIP", 9980)
        -- Make frame and all children fully click-through while following cursor
        ApplyClickThroughState(frame, true)
        frame:ClearAllPoints()
        frame:SetPoint(pointFrom, UIParent, "BOTTOMLEFT", 0, 0)
        CDMRT:StartMouseTracking(frame, pointFrom, baseOX, baseOY)
    elseif anchorKey == "partyframe" then
        -- Anchor to the player's party frame
        local partyFrame = FindPlayerPartyFrame()
        if partyFrame then
            frame:ClearAllPoints()
            local side = barData.partyFrameSide or "LEFT"
            local oX = barData.partyFrameOffsetX or 0
            local oY = barData.partyFrameOffsetY or 0
            local grow = barData.growDirection or "RIGHT"
            local centered = barData.growCentered ~= false
            local fp = CDMFrameAnchorPoint(side, grow, centered)
            frame._anchorSide = side:upper()
            if side == "LEFT" then
                frame:SetPoint(fp, partyFrame, "LEFT", oX, oY)
            elseif side == "RIGHT" then
                frame:SetPoint(fp, partyFrame, "RIGHT", oX, oY)
            elseif side == "TOP" then
                frame:SetPoint(fp, partyFrame, "TOP", oX, oY)
            elseif side == "BOTTOM" then
                frame:SetPoint(fp, partyFrame, "BOTTOM", oX, oY)
            end
        else
            -- No party frame found -> fall back to saved position
            local pos = p.cdmBarPositions[key]
            if pos and pos.point then
                ApplyBarPositionCentered(frame, pos, 1, 1, scale)
            else
                frame:ClearAllPoints()
                local defY = (key == "cooldowns") and -250 or 0
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, defY)
            end
        end
    elseif anchorKey == "playerframe" then
        -- Anchor to the player's unit frame
        local playerFrame = FindPlayerUnitFrame()
        if not playerFrame then
            playerFrame = ns.CDMGetBlizzardPlayerFrameCandidate() or _G["PlayerFrame"]
        end
        if not playerFrame and barData.isKUITracker then
            playerFrame = _G["KUI_PrimaryBar"] or _G["KT_PrimaryBar"]
            if not playerFrame then
                ns.TrackerDebugOnce(
                    "kui_no_playerframe_" .. key,
                    string.format("KUI Tracker '%s' sin playerFrame (fallback inexistente).", key)
                )
            end
        end
        if playerFrame then
            frame:ClearAllPoints()
            local side = barData.playerFrameSide or "LEFT"
            local oX = barData.playerFrameOffsetX or 0
            local oY = barData.playerFrameOffsetY or 0
            local grow = barData.growDirection or "RIGHT"
            local centered = barData.growCentered ~= false
            local fp = CDMFrameAnchorPoint(side, grow, centered)
            frame._anchorSide = side:upper()
            if barData.isKUITracker then
                local pfName = playerFrame.GetName and playerFrame:GetName() or tostring(playerFrame)
                local pfW = playerFrame.GetWidth and playerFrame:GetWidth() or 0
                local pfH = playerFrame.GetHeight and playerFrame:GetHeight() or 0
                local pfScale = playerFrame.GetScale and playerFrame:GetScale() or 1
                ns.TrackerDebugOnce(
                    "kui_anchor_" .. key,
                    string.format(
                        "KUI Tracker '%s' anchor playerFrame=%s shown=%s size=%.0fx%.0f scale=%.2f side=%s oX=%d oY=%d grow=%s",
                        key, pfName, tostring(playerFrame:IsShown()), pfW, pfH, pfScale, side, oX, oY, tostring(grow)
                    )
                )
            end
            if side == "TOPRIGHT_OUT" then
                frame:SetPoint("BOTTOMRIGHT", playerFrame, "TOPRIGHT", oX, oY)
            elseif side == "TOPLEFT_OUT" then
                frame:SetPoint("BOTTOMLEFT", playerFrame, "TOPLEFT", oX, oY)
            elseif side == "BOTTOMRIGHT_OUT" then
                frame:SetPoint("TOPRIGHT", playerFrame, "BOTTOMRIGHT", oX, oY)
            elseif side == "BOTTOMLEFT_OUT" then
                frame:SetPoint("TOPLEFT", playerFrame, "BOTTOMLEFT", oX, oY)
            elseif side == "TOPRIGHT" then
                frame:SetPoint("TOPRIGHT", playerFrame, "TOPRIGHT", oX, oY)
            elseif side == "TOPLEFT" then
                frame:SetPoint("TOPLEFT", playerFrame, "TOPLEFT", oX, oY)
            elseif side == "BOTTOMRIGHT" then
                frame:SetPoint("BOTTOMRIGHT", playerFrame, "BOTTOMRIGHT", oX, oY)
            elseif side == "BOTTOMLEFT" then
                frame:SetPoint("BOTTOMLEFT", playerFrame, "BOTTOMLEFT", oX, oY)
            elseif side == "LEFT" then
                frame:SetPoint(fp, playerFrame, "LEFT", oX, oY)
            elseif side == "RIGHT" then
                frame:SetPoint(fp, playerFrame, "RIGHT", oX, oY)
            elseif side == "TOP" then
                frame:SetPoint(fp, playerFrame, "TOP", oX, oY)
            elseif side == "BOTTOM" then
                frame:SetPoint(fp, playerFrame, "BOTTOM", oX, oY)
            end
            if barData.isKUITracker then
                local cx, cy = frame:GetCenter()
                ns.TrackerDebugOnce(
                    "kui_anchor_pos_" .. key,
                    string.format("KUI Tracker '%s' frame center=%.1f,%.1f alpha=%.2f",
                        key, cx or 0, cy or 0, frame:GetAlpha() or 1)
                )
            end
        else
            if not InCombatLockdown() then
                C_Timer.After(1.0, function()
                    if InCombatLockdown() then return end
                    if BuildCDMBar then BuildCDMBar(barIndex) end
                end)
            end
            -- No player frame found -> fall back to saved position
            local pos = p.cdmBarPositions[key]
            if pos and pos.point then
                ApplyBarPositionCentered(frame, pos, 1, 1, scale)
            else
                frame:ClearAllPoints()
                local defY = (key == "cooldowns") and -250 or 0
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, defY)
            end
        end
    elseif anchorKey == "erb_castbar" or anchorKey == "erb_powerbar" or anchorKey == "erb_classresource" then
        -- Anchor to KullThranUI Resource Bars frames (migrado de ERB)
        local erbFrameNames = {
            erb_castbar = { "KT_CastBarFrame" },
            erb_powerbar = { "KUI_PrimaryBar", "KT_PrimaryBar" },
            erb_classresource = { "KUI_SecondaryFrame", "KT_SecondaryFrame" },
        }
        local erbFrame
        for _, frameName in ipairs(erbFrameNames[anchorKey] or {}) do
            erbFrame = _G[frameName]
            if erbFrame then
                break
            end
        end
        if erbFrame then
            local anchorPos = barData.anchorPosition or "left"
            frame:ClearAllPoints()
            local gap = barData.spacing or 2
            local oX = barData.anchorOffsetX or 0
            local oY = barData.anchorOffsetY or 0
            local grow = barData.growDirection or "RIGHT"
            local centered = barData.growCentered ~= false
            local fp = CDMFrameAnchorPoint(anchorPos:upper(), grow, centered)
            frame._anchorSide = anchorPos:upper()
            local ok
            if anchorPos == "left" then
                ok = pcall(frame.SetPoint, frame, fp, erbFrame, "LEFT", -gap + oX, oY)
            elseif anchorPos == "right" then
                ok = pcall(frame.SetPoint, frame, fp, erbFrame, "RIGHT", gap + oX, oY)
            elseif anchorPos == "top" then
                ok = pcall(frame.SetPoint, frame, fp, erbFrame, "TOP", oX, gap + oY)
            elseif anchorPos == "bottom" then
                ok = pcall(frame.SetPoint, frame, fp, erbFrame, "BOTTOM", oX, -gap + oY)
            end
            -- Circular anchor detected -> fall back to center
            if not ok then
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        else
            -- Resource Bars frame not available -> fall back to saved position
            local pos = p.cdmBarPositions[key]
            if pos and pos.point then
                ApplyBarPositionCentered(frame, pos, 1, 1, scale)
            else
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        end
    elseif anchorKey == "castbar" then
        -- Anchor to the standalone KullThranUI castbar frame even when it is visually hidden.
        local castBar = _G["KT_PlayerCastBar"] or _G["KT_CastBarFrame"] or _G["PlayerCastingBarFrame"]
        if castBar and castBar.IsObjectType and castBar:IsObjectType("Frame") then
            local anchorPos = barData.anchorPosition or "top"
            frame:ClearAllPoints()
            local oX = barData.anchorOffsetX or 0
            local oY = barData.anchorOffsetY or 4
            local grow = barData.growDirection or "RIGHT"
            local centered = barData.growCentered ~= false
            local fp = CDMFrameAnchorPoint(anchorPos:upper(), grow, centered)
            frame._anchorSide = anchorPos:upper()
            if anchorPos == "top" then
                frame:SetPoint(fp, castBar, "TOP", oX, oY)
            elseif anchorPos == "bottom" then
                frame:SetPoint(fp, castBar, "BOTTOM", oX, -math.abs(oY))
            elseif anchorPos == "left" then
                frame:SetPoint(fp, castBar, "LEFT", -math.abs(oX), oY)
            elseif anchorPos == "right" then
                frame:SetPoint(fp, castBar, "RIGHT", math.abs(oX), oY)
            else
                frame:SetPoint(fp, castBar, "TOP", oX, oY)
            end
        else
            -- Castbar not found: fallback a center-bottom
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, -415)
        end
    elseif anchorKey and anchorKey ~= "none" and cdmBarFrames[anchorKey] then
        local anchorFrame = cdmBarFrames[anchorKey]
        local anchorPos = barData.anchorPosition or "left"
        frame:ClearAllPoints()
        local gap = barData.spacing or 2
        local oX = barData.anchorOffsetX or 0
        local oY = barData.anchorOffsetY or 0
        local grow = barData.growDirection or "RIGHT"
        local centered = barData.growCentered ~= false
        local ok
        if anchorPos == "topright" then
            frame._anchorSide = "TOPRIGHT"
            ok = pcall(frame.SetPoint, frame, "BOTTOMRIGHT", anchorFrame, "TOPRIGHT", oX, oY)
        elseif anchorPos == "topleft" then
            frame._anchorSide = "TOPLEFT"
            ok = pcall(frame.SetPoint, frame, "BOTTOMLEFT", anchorFrame, "TOPLEFT", oX, oY)
        elseif anchorPos == "left" then
            local fp = CDMFrameAnchorPoint(anchorPos:upper(), grow, centered)
            frame._anchorSide = anchorPos:upper()
            ok = pcall(frame.SetPoint, frame, fp, anchorFrame, "LEFT", -gap + oX, oY)
        elseif anchorPos == "right" then
            local fp = CDMFrameAnchorPoint(anchorPos:upper(), grow, centered)
            frame._anchorSide = anchorPos:upper()
            ok = pcall(frame.SetPoint, frame, fp, anchorFrame, "RIGHT", gap + oX, oY)
        elseif anchorPos == "top" then
            local fp = CDMFrameAnchorPoint(anchorPos:upper(), grow, centered)
            frame._anchorSide = anchorPos:upper()
            ok = pcall(frame.SetPoint, frame, fp, anchorFrame, "TOP", oX, gap + oY)
        elseif anchorPos == "bottom" then
            local fp = CDMFrameAnchorPoint(anchorPos:upper(), grow, centered)
            frame._anchorSide = anchorPos:upper()
            ok = pcall(frame.SetPoint, frame, fp, anchorFrame, "BOTTOM", oX, -gap + oY)
        end
        if not ok then
            local pos = p.cdmBarPositions[key]
            if pos and pos.point then
                ApplyBarPositionCentered(frame, pos, 1, 1, scale)
            else
                frame:ClearAllPoints()
                local defY = (key == "cooldowns") and -250 or 0
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, defY)
            end
        end
    else
        local pos = p.cdmBarPositions[key]
        if pos and pos.point then
            ApplyBarPositionCentered(frame, pos, 1, 1, scale)
        else
            -- Default fallback positions
            frame:ClearAllPoints()
            if key == "cooldowns" then
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
            elseif key == "utility" then
                frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 66)
            elseif key == "buffs" then
                frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 15)
            else
                frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 90)
            end
        end
    end

    frame:Show()
end

-------------------------------------------------------------------------------
--  Layout icons within a CDM bar
-------------------------------------------------------------------------------
LayoutCDMBar = function(barKey)
    local frame = cdmBarFrames[barKey]
    local icons = cdmBarIcons[barKey]
    if not frame or not icons then return end
    local combatLocked = InCombatLockdown and InCombatLockdown()
    if combatLocked and (barKey == "kui_potion"
        or (frame.IsProtected and frame:IsProtected())) then
        ns._cdmLayoutPending = true
        return
    end

    local barData = barDataByKey[barKey]
    if not barData or not barData.enabled then return end

    local barScale = barData.barScale or 1.0
    if barScale < 0.1 then barScale = 1.0 end
    local iconW = SnapForScale(barData.iconSize or 36, barScale)
    local iconH = iconW
    local shape = barData.iconShape or "none"
    if shape == "cropped" then
        iconH = SnapForScale(math.floor((barData.iconSize or 36) * 0.80 + 0.5), barScale)
    end
    local spacing = SnapForScale(barData.spacing or 2, barScale)
    local grow = frame._mouseGrow or barData.growDirection or "RIGHT"
    local numRows = barData.numRows or 1
    if numRows < 1 then numRows = 1 end

    -- Collect visible icons (reuse buffer to avoid garbage)
    local visibleIcons = frame._visibleIconsBuf
    if not visibleIcons then
        visibleIcons = {}; frame._visibleIconsBuf = visibleIcons
    else
        wipe(visibleIcons)
    end
    local isKUIEditMode = (KT and KT._unlockActive)
    local isBlizzEditMode = (C_EditMode and C_EditMode.IsEditModeActive and C_EditMode.IsEditModeActive())
    local maxIcons = 9999
    if isKUIEditMode then
        maxIcons = (numRows * 5)
    elseif isBlizzEditMode then
        maxIcons = 0
    end
    for _, icon in ipairs(icons) do
        local includeInLayout
        if icon._barKey == "kui_potion" and icon._ktCDMShouldShow ~= nil then
            includeInLayout = icon._ktCDMShouldShow == true
        else
            includeInLayout = icon:IsShown()
        end
        if includeInLayout then
            if #visibleIcons < maxIcons then
                visibleIcons[#visibleIcons + 1] = icon
            else
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", frame, "CENTER")
                icon:SetAlpha(0)
            end
        end
    end

    local count = #visibleIcons
    if count == 0 then
        frame:SetSize(1, 1)
        if frame._barBg then frame._barBg:Hide() end
        return
    end

    local isHoriz = (grow == "RIGHT" or grow == "LEFT")
    local contentParent = frame._content or frame
    local stride = math.ceil(count / numRows)

    -- Container size (already snapped values)
    local totalW, totalH
    if isHoriz then
        totalW = stride * iconW + (stride - 1) * spacing
        totalH = numRows * iconH + (numRows - 1) * spacing
    else
        totalW = numRows * iconW + (numRows - 1) * spacing
        totalH = stride * iconH + (stride - 1) * spacing
    end

    local contentW, contentH = totalW, totalH

    contentParent:SetSize(contentW, contentH)
    if grow == "LEFT" then
        contentParent:ClearAllPoints()
        contentParent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    elseif grow == "UP" then
        contentParent:ClearAllPoints()
        contentParent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    else
        contentParent:ClearAllPoints()
        contentParent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    end

    frame:SetSize(contentW, contentH)

    -- Bar opacity (affects entire bar, but respect visibility overrides)
    local vis = barData.barVisibility or "always"
    if vis == "always" or (vis == "in_combat" and _inCombat) then
        frame:SetAlpha(barData.barBgAlpha or 1)
    elseif vis == "mouseover" then
        local hoverStates = ns._cdmHoverStates or rawget(_G, "_cdmHoverStates")
        local state = hoverStates and hoverStates[barKey] or nil
        if state and state.isHovered then
            frame:SetAlpha(barData.barBgAlpha or 1)
        end
    end

    -- Bar background
    if barData.barBgEnabled then
        if not frame._barBg then
            frame._barBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        end
        frame._barBg:ClearAllPoints()
        frame._barBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        frame._barBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame._barBg:SetColorTexture(barData.barBgR or 0, barData.barBgG or 0, barData.barBgB or 0, 0.5)
        frame._barBg:SetSnapToPixelGrid(false)
        frame._barBg:SetTexelSnappingBias(0)
        frame._barBg:Show()
    elseif frame._barBg then
        frame._barBg:Hide()
    end

    local stepW = iconW + spacing
    local stepH = iconH + spacing

    -- Position each icon in a grid anchored to the frame's corners.
    for i, icon in ipairs(visibleIcons) do
        ns.CDM_SetProtectedFrameLayering(
            icon,
            ns.CDM_ResolveBarStrata(barData, KUI_CDM.db and KUI_CDM.db.profile),
            5 + i
        )
        local layerBase = icon:GetFrameLevel()
        if icon._cooldown then
            pcall(icon._cooldown.SetFrameLevel, icon._cooldown, layerBase + 14)
        end
        if icon._glowOverlay then
            pcall(icon._glowOverlay.SetFrameLevel, icon._glowOverlay, layerBase + 16)
        end
        if icon._customModuleGlowOverlay then
            pcall(icon._customModuleGlowOverlay.SetFrameLevel, icon._customModuleGlowOverlay, layerBase + 17)
        end
        if icon._textOverlay then
            pcall(icon._textOverlay.SetFrameLevel, icon._textOverlay, layerBase + 23)
            pcall(icon._textOverlay.SetFrameStrata, icon._textOverlay, icon:GetFrameStrata())
        end
        if icon._shapeBorderFrame then
            pcall(icon._shapeBorderFrame.SetFrameStrata, icon._shapeBorderFrame, icon:GetFrameStrata())
        end
        if icon._potionCooldownOverlay then
            -- The manual potion timer must stay above the cooldown swipe and
            -- the regular stack/keybind overlay after every relayout.
            local cooldownLevel = icon._cooldown and icon._cooldown.GetFrameLevel
                and icon._cooldown:GetFrameLevel() or (layerBase + 14)
            local textLevel = icon._textOverlay and icon._textOverlay.GetFrameLevel
                and icon._textOverlay:GetFrameLevel() or (layerBase + 23)
            pcall(icon._potionCooldownOverlay.SetFrameLevel, icon._potionCooldownOverlay,
                math.max(layerBase + 27, cooldownLevel + 3, textLevel + 3))
        end
icon:SetSize(iconW, iconH)
        icon:SetScale(1)
        if icon._UpdateMouseForTooltip then icon:_UpdateMouseForTooltip() end
        if icon._glowOverlay then
            icon._glowOverlay:SetSize(iconW + 6, iconH + 6)
        end
        icon:ClearAllPoints()

        local idx = i - 1
        local col = idx % stride
        local row = math.floor(idx / stride)

        -- Count how many icons are in this row to detect partial rows
        local rowStart = row * stride
        local iconsInRow = math.min(stride, count - rowStart)

        if grow == "RIGHT" then
            local flippedRow = (numRows - 1) - row
            local rowOffset = math.floor((stride - iconsInRow) * stepW / 2)
            ns.SetCDMIconLayoutPoint(icon, "TOPLEFT", contentParent, "TOPLEFT",
                col * stepW + rowOffset,
                -(flippedRow * stepH))
        elseif grow == "LEFT" then
            local flippedRow = (numRows - 1) - row
            local rowOffset = math.floor((stride - iconsInRow) * stepW / 2)
            ns.SetCDMIconLayoutPoint(icon, "TOPRIGHT", contentParent, "TOPRIGHT",
                -(col * stepW + rowOffset),
                -(flippedRow * stepH))
        elseif grow == "DOWN" then
            local flippedRow = (numRows - 1) - row
            local rowOffset = math.floor((stride - iconsInRow) * stepH / 2)
            ns.SetCDMIconLayoutPoint(icon, "TOPLEFT", contentParent, "TOPLEFT",
                flippedRow * stepW,
                -(col * stepH + rowOffset))
        elseif grow == "UP" then
            local rowOffset = math.floor((stride - iconsInRow) * stepH / 2)
            ns.SetCDMIconLayoutPoint(icon, "BOTTOMLEFT", contentParent, "BOTTOMLEFT",
                row * stepW,
                col * stepH + rowOffset)
        end
    end
    ns.SyncNativeCDMBarAlpha(barKey)
end

-------------------------------------------------------------------------------
--  Create a single icon frame for a CDM bar
-------------------------------------------------------------------------------
local function CreateCDMIcon(barKey, index)
    local frame = cdmBarFrames[barKey]
    if not frame then return end

    local barData = barDataByKey[barKey]
    if not barData then return end

    local barScale = barData.barScale or 1.0
    if barScale < 0.1 then barScale = 1.0 end
    local iconSize = barData.iconSize or 36
    local borderSize = SnapForScale(barData.borderSize or 1, barScale)
    local zoom = barData.iconZoom or 0.08

    local iconParent = frame._content or frame
    local iconTemplate = (barKey == "kui_potion") and "SecureActionButtonTemplate" or nil
    local icon = CreateFrame("Button", "KUI_CDMIcon_" .. barKey .. "_" .. index, iconParent, iconTemplate)
    icon._kuiOwnedCDMIcon = true
    icon._barKey = barKey
    icon:SetSize(SnapForScale(iconSize, barScale), SnapForScale(iconSize, barScale))
    icon:RegisterForClicks("AnyUp")
    ns.CDMApplyMouseStateSafely(icon, false, false)

    -- Background
    local bg = icon:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(barData.bgR or 0.08, barData.bgG or 0.08, barData.bgB or 0.08, barData.bgA or 0.6)
    bg:SetSnapToPixelGrid(false)
    bg:SetTexelSnappingBias(0)
    icon._bg = bg

    -- Icon texture
    local tex = icon:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", icon, "TOPLEFT", borderSize, -borderSize)
    tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -borderSize, borderSize)
    tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    tex:SetSnapToPixelGrid(false)
    tex:SetTexelSnappingBias(0)
    icon._tex = tex

    -- Cooldown overlay (frame level above icon so swipe renders on top of texture)
    local cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cd:SetFrameLevel(icon:GetFrameLevel() + 1)
    cd:EnableMouse(false)
    cd:SetPoint("TOPLEFT", icon, "TOPLEFT", borderSize, -borderSize)
    cd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -borderSize, borderSize)
    cd:SetDrawEdge(false)
    cd:SetDrawSwipe(true)
    cd:SetDrawBling(false)
    do
        local swipeR, swipeG, swipeB = GetConfiguredSwipeColor(barData, icon)
        cd:SetSwipeColor(swipeR, swipeG, swipeB, barData.swipeAlpha or 0.7)
    end
    cd:SetSwipeTexture("Interface\\Buttons\\WHITE8x8", 0, 1, 0, 1)
    cd:SetHideCountdownNumbers(not barData.showCooldownText)
    cd:SetReverse(false)
    icon._cooldown = cd

    -- Cooldown text styling
    if barData.showCooldownText then
        icon._pendingFontPath = GetCDMFont(); icon._pendingFontSize = barData.cooldownFontSize or 12
    end

    -- Text overlay frame: sits above the cooldown swipe so charge/stack text
    -- is always visible on top of the swipe animation
    local textOverlay = CreateFrame("Frame", nil, icon)
    textOverlay:SetAllPoints(icon)
    textOverlay:SetFrameLevel(icon:GetFrameLevel() + 2)
    textOverlay:SetFrameStrata(icon:GetFrameStrata())
    textOverlay:EnableMouse(false)
    icon._textOverlay = textOverlay

    -- Charge count text
    local chargeText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetCDMFont(chargeText, GetCDMFont(), barData.stackCountSize or 12)
    chargeText:SetShadowOffset(0, 0)
    chargeText:SetPoint("BOTTOMRIGHT", textOverlay, "BOTTOMRIGHT", barData.stackCountX or 0,
        (barData.stackCountY or 0) + 2)
    chargeText:SetJustifyH("RIGHT")
    chargeText:SetTextColor(barData.stackCountR or 1, barData.stackCountG or 1, barData.stackCountB or 1)
    chargeText:Hide()
    icon._chargeText = chargeText

    -- Glow overlay (for active state animations -> extends 3px beyond icon so pixel glow ants are visible outside border)
    local glowOverlay = CreateFrame("Frame", nil, icon)
    glowOverlay:ClearAllPoints()
    glowOverlay:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
    glowOverlay:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
    ApplyCDMGlowLayer(glowOverlay, icon, 3)
    RaiseCDMGlowLayers(glowOverlay)
    glowOverlay:SetAlpha(0)
    glowOverlay:EnableMouse(false)
    glowOverlay._kuiUseSelfGlowTarget = true
    icon._glowOverlay = glowOverlay

    -- Button press highlight overlay (flash on UseAction)
    local pressOverlay = icon:CreateTexture(nil, "OVERLAY", nil, 7)
    pressOverlay:SetAllPoints(icon)
    pressOverlay:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    pressOverlay:SetBlendMode("ADD")
    pressOverlay:SetAlpha(0)
    pressOverlay:Hide()
    icon._pressOverlay = pressOverlay

    -- Keybind text overlay (top-left corner of icon)
    local keybindText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetCDMFont(keybindText, GetCDMFont(), barData.keybindSize or 13)
    keybindText:SetShadowOffset(0, 0)
    keybindText:SetPoint("TOPLEFT", textOverlay, "TOPLEFT", barData.keybindOffsetX or 2, barData.keybindOffsetY or -2)
    keybindText:SetJustifyH("LEFT")
    keybindText:SetTextColor(barData.keybindR or 1, barData.keybindG or 1, barData.keybindB or 1, barData.keybindA or 0.9)
    keybindText:Hide()
    icon._keybindText = keybindText

    -- Tooltip on hover
    local function UpdateIconMouseForTooltip(self)
        local owner = self._icon or self
        local bd = barDataByKey[owner._barKey]
        local wantsTooltip = bd and bd.showTooltip
        local wantsClick = owner._ktClickableItemID and self == owner
        if wantsTooltip or wantsClick then
            ns.CDMApplyMouseStateSafely(self, true, true)
        else
            ns.CDMApplyMouseStateSafely(self, false, false)
            if owner._tooltipShown then
                GameTooltip:Hide()
                owner._tooltipShown = false
            end
        end
    end
    icon._UpdateMouseForTooltip = UpdateIconMouseForTooltip
    local function HandleTooltipEnter(self)
        local owner = self._icon or self
        local bd = barDataByKey[owner._barKey]
        if not bd or not bd.showTooltip then return end
        local itemID = owner._itemID
        if itemID then
            GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
            GameTooltip._ktSourceIconTexture = owner._tex and owner._tex:GetTexture() or nil
            GameTooltip:SetItemByID(itemID)
            GameTooltip:Show()
            owner._tooltipShown = true
            return
        end
        local sid = owner._spellID or owner._baseSpellID
        if sid then
            GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
            GameTooltip._ktSourceIconTexture = owner._tex and owner._tex:GetTexture() or nil
            GameTooltip:SetSpellByID(sid)
            GameTooltip:Show()
            owner._tooltipShown = true
        end
    end
    local function HandleTooltipLeave(self)
        local owner = self._icon or self
        GameTooltip._ktSourceIconTexture = nil
        if owner._tooltipShown then
            GameTooltip:Hide()
            owner._tooltipShown = false
        end
    end
    icon:SetScript("OnEnter", HandleTooltipEnter)
    icon:SetScript("OnLeave", HandleTooltipLeave)
    icon._tooltipShown = false
    icon:HookScript("PostClick", function(self)
        local clickableItemID = self and (self._ktClickableItemID or self._itemID)
        if self and self._barKey == "kui_potion" then
            if clickableItemID and ns.TriggerImmediateSyntheticItemCooldown then
                ns.TriggerImmediateSyntheticItemCooldown(clickableItemID)
            end
            if ns.RequestPotionTrackerClickRefresh then
                ns.RequestPotionTrackerClickRefresh()
            end
        end
    end)

    local tooltipOverlay = CreateFrame("Frame", nil, icon)
    tooltipOverlay:SetAllPoints(icon)
    tooltipOverlay:SetFrameLevel(icon:GetFrameLevel() + 8)
    ns.CDMApplyMouseStateSafely(tooltipOverlay, false, false)
    tooltipOverlay._icon = icon
    tooltipOverlay._UpdateMouseForTooltip = UpdateIconMouseForTooltip
    tooltipOverlay:SetScript("OnEnter", HandleTooltipEnter)
    tooltipOverlay:SetScript("OnLeave", HandleTooltipLeave)
    icon._tooltipOverlay = tooltipOverlay
    tooltipOverlay:_UpdateMouseForTooltip()

    -- Border (4 edges)
    local edges = {}
    for i = 1, 4 do
        local e = icon:CreateTexture(nil, "OVERLAY", nil, 7)
        e:SetColorTexture(barData.borderR or 0, barData.borderG or 0, barData.borderB or 0, barData.borderA or 1)
        e:SetSnapToPixelGrid(false)
        e:SetTexelSnappingBias(0)
        edges[i] = e
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(borderSize)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(borderSize)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(borderSize)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(borderSize)
    icon._edges = edges

    -- State tracking
    icon._spellID = nil
    icon._isActive = false
    icon._barKey = barKey
    icon:HookScript("OnShow", function(self)
        if ns.SyncProcGlowIndexForIcon then
            ns.SyncProcGlowIndexForIcon(self)
        end
    end)
    icon:HookScript("OnHide", function(self)
        if self._customModuleGlowActive and self._customModuleGlowOverlay then
            StopNativeGlow(self._customModuleGlowOverlay)
            self._customModuleGlowActive = false
            self._customModuleGlowWanted = false
            self._customModuleGlowStyle = nil
        end
        if ns.SyncProcGlowIndexForIcon then
            ns.SyncProcGlowIndexForIcon(self)
        end
    end)

    -- Apply saved icon shape on creation
    local shape = barData.iconShape or "none"
    if shape ~= "none" then
        ApplyShapeToCDMIcon(icon, shape, barData)
    end

    ns.SetCDMIconShown(icon, false)
    return icon
end

-------------------------------------------------------------------------------
--  Apply custom shape to a CDM icon
-------------------------------------------------------------------------------
ApplyShapeToCDMIcon = function(icon, shape, barData)
    if not icon then return end
    local zoom = barData.iconZoom or 0.08
    local borderSz = barData.borderSize or 1
    local brdR = barData.borderR or 0
    local brdG = barData.borderG or 0
    local brdB = barData.borderB or 0
    local brdA = barData.borderA or 1
    if barData.borderClassColor then
        local _, ct = UnitClass("player")
        if ct then
            local cc = RAID_CLASS_COLORS[ct]
            if cc then brdR, brdG, brdB = cc.r, cc.g, cc.b end
        end
    end

    if shape == "none" or shape == "cropped" or not shape then
        if icon._cooldown then
            pcall(icon._cooldown.SetDrawEdge, icon._cooldown, false)
            pcall(icon._cooldown.SetDrawBling, icon._cooldown, false)
        end
        ns.SetCDMNativeSquareDecorShown(icon, true)
        -- Remove shape mask if previously applied
        if icon._shapeMask then
            local mask = icon._shapeMask
            if icon._tex then pcall(icon._tex.RemoveMaskTexture, icon._tex, mask) end
            if icon._bg then pcall(icon._bg.RemoveMaskTexture, icon._bg, mask) end
            if icon._cooldown then pcall(icon._cooldown.RemoveMaskTexture, icon._cooldown, mask) end
            mask:SetTexture(nil); mask:ClearAllPoints(); mask:SetSize(0.001, 0.001); mask:Hide()
        end
        if icon._shapeBorder then icon._shapeBorder:Hide() end
        icon._shapeApplied = nil
        icon._shapeName = nil

        -- Restore square borders
        if icon._edges then
            for i = 1, 4 do icon._edges[i]:Show() end
            if icon._bg then icon._bg:Show() end
            icon._edges[1]:SetHeight(borderSz)
            icon._edges[2]:SetHeight(borderSz)
            icon._edges[3]:SetWidth(borderSz)
            icon._edges[4]:SetWidth(borderSz)
            for i = 1, 4 do
                icon._edges[i]:SetColorTexture(brdR, brdG, brdB, brdA)
                icon._edges[i]:SetSnapToPixelGrid(false)
                icon._edges[i]:SetTexelSnappingBias(0)
            end
        end
        if icon.__KUIShapeBorderFrame then
            local reskin = KUI_CDM.db and KUI_CDM.db.profile.reskinBorders
            if reskin then icon.__KUIShapeBorderFrame:Show() else icon.__KUIShapeBorderFrame:Hide() end
        end

        -- Restore icon texture coords
        if icon._tex then
            icon._tex:ClearAllPoints()
            icon._tex:SetPoint("TOPLEFT", icon, "TOPLEFT", borderSz, -borderSz)
            icon._tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -borderSz, borderSz)
            if shape == "cropped" then
                icon._tex:SetTexCoord(zoom, 1 - zoom, zoom + 0.10, 1 - zoom - 0.10)
            else
                icon._tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
            end
        end

        -- Restore cooldown
        if icon._cooldown then
            icon._cooldown:ClearAllPoints()
            icon._cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", borderSz, -borderSz)
            icon._cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -borderSz, borderSz)
            pcall(icon._cooldown.SetSwipeTexture, icon._cooldown, "Interface\\Buttons\\WHITE8x8")
            if icon._cooldown.SetUseCircularEdge then pcall(icon._cooldown.SetUseCircularEdge, icon._cooldown, false) end
        end

        -- Restore background
        if icon._bg then
            icon._bg:ClearAllPoints(); icon._bg:SetAllPoints()
        end
        return
    end

    -- Custom shape
    local maskTex = CDM_SHAPES.masks[shape]
    if not maskTex then return end
    if icon._cooldown then
        pcall(icon._cooldown.SetDrawEdge, icon._cooldown, false)
        pcall(icon._cooldown.SetDrawBling, icon._cooldown, false)
    end
    ns.SetCDMNativeSquareDecorShown(icon, false)

    if not icon._shapeMask then
        icon._shapeMask = icon:CreateMaskTexture()
    end
    local mask = icon._shapeMask
    mask:SetTexture(maskTex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:Show()

    -- Remove existing mask refs before re-adding
    if icon._tex then pcall(icon._tex.RemoveMaskTexture, icon._tex, mask) end
    if icon._bg then pcall(icon._bg.RemoveMaskTexture, icon._bg, mask) end
    if icon._cooldown then pcall(icon._cooldown.RemoveMaskTexture, icon._cooldown, mask) end

    -- Apply mask to icon texture and background
    if icon._tex then icon._tex:AddMaskTexture(mask) end
    if icon._bg then icon._bg:AddMaskTexture(mask) end

    -- Expand icon beyond frame for shape
    local shapeOffset = ns.CDM_SHAPE_ICON_EXPAND_OFFSETS[shape] or 0
    local shapeDefault = CDM_SHAPES.zoomDefaults[shape] or 0.06
    local iconExp = ns.CDM_SHAPE_ICON_EXPAND + shapeOffset + ((zoom - shapeDefault) * 200)
    if iconExp < 0 then iconExp = 0 end
    local halfIE = iconExp / 2
    if icon._tex then
        icon._tex:ClearAllPoints()
        icon._tex:SetPoint("TOPLEFT", icon, "TOPLEFT", -halfIE, halfIE)
        icon._tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", halfIE, -halfIE)
    end

    -- Mask position (inset for border)
    mask:ClearAllPoints()
    if borderSz >= 1 then
        mask:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
        mask:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    else
        mask:SetAllPoints(icon)
    end

    -- Expand texcoords for shape
    local insetPx = ns.CDM_SHAPE_INSETS[shape] or 17
    local visRatio = (128 - 2 * insetPx) / 128
    local expand = ((1 / visRatio) - 1) * 0.5
    if icon._tex then icon._tex:SetTexCoord(-expand, 1 + expand, -expand, 1 + expand) end

    -- Hide square borders
    if icon._edges then
        for i = 1, 4 do icon._edges[i]:Hide() end
    end
    if icon._bg then icon._bg:Hide() end
    if icon.__KUIShapeBorderFrame then icon.__KUIShapeBorderFrame:Hide() end

    -- Shape border texture (on a dedicated frame above the cooldown swipe)
    if not icon._shapeBorderFrame then
        local sbf = CreateFrame("Frame", nil, icon)
        sbf:SetAllPoints(icon)
        sbf:SetFrameLevel(icon:GetFrameLevel() + 2)
        icon._shapeBorderFrame = sbf
    end
    icon._shapeBorderFrame:SetFrameLevel(icon:GetFrameLevel() + 2)
    icon._shapeBorderFrame:SetFrameStrata(icon:GetFrameStrata())
    if not icon._shapeBorder then
        icon._shapeBorder = icon._shapeBorderFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    end
    local borderTex = icon._shapeBorder
    borderTex:ClearAllPoints()
    borderTex:SetAllPoints(icon)
    if borderSz > 0 and CDM_SHAPES.borders[shape] then
        borderTex:SetTexture(CDM_SHAPES.borders[shape])
        borderTex:SetVertexColor(brdR, brdG, brdB, brdA)
        borderTex:SetSnapToPixelGrid(false)
        borderTex:SetTexelSnappingBias(0)
        borderTex:Show()
    else
        borderTex:Hide()
    end

    -- Apply mask to cooldown so swipe follows shape
    if icon._cooldown then
        icon._cooldown:ClearAllPoints()
        icon._cooldown:SetAllPoints(icon)
        pcall(icon._cooldown.AddMaskTexture, icon._cooldown, mask)
        if icon._cooldown.SetSwipeTexture then
            pcall(icon._cooldown.SetSwipeTexture, icon._cooldown, maskTex)
        end
        local useCircular = (shape ~= "square" and shape ~= "csquare")
        if icon._cooldown.SetUseCircularEdge then pcall(icon._cooldown.SetUseCircularEdge, icon._cooldown, useCircular) end
    local edgeScale = ns.CDM_SHAPE_EDGE_SCALES[shape] or 0.60
        if icon._cooldown.SetEdgeScale then pcall(icon._cooldown.SetEdgeScale, icon._cooldown, edgeScale) end
    end

    -- Restore background to full icon
    if icon._bg then
        icon._bg:ClearAllPoints(); icon._bg:SetAllPoints()
    end

    icon._shapeApplied = true
    icon._shapeName = shape
end
ns.ApplyShapeToCDMIcon = ApplyShapeToCDMIcon
-------------------------------------------------------------------------------
--  Update icons for a CDM bar based on Blizzard CDM children
--  We read the Blizzard CDM bar's children to know which spells are active,
--  then mirror them on our own bar.
-------------------------------------------------------------------------------
-- Shared sort comparator for Blizzard CDM children (avoids closure allocation per tick)
local function SortBlizzChildren(a, b)
    local ai = a.layoutIndex
    local bi = b.layoutIndex
    if type(ai) ~= "number" or (issecretvalue and issecretvalue(ai)) then ai = 0 end
    if type(bi) ~= "number" or (issecretvalue and issecretvalue(bi)) then bi = 0 end
    if ai ~= bi then return ai < bi end
    -- Frame coordinates may be secret in restricted combat.  Never read or
    -- compare GetLeft/GetTop for ordering; frame identity is a clean tiebreaker.
    return tostring(a) < tostring(b)
end

ns._tickBlizzMirror = ns._tickBlizzMirror or {
    icons = {
        cooldowns = {},
        utility = {},
        buffs = {},
    },
    seen = {
        cooldowns = {},
        utility = {},
        buffs = {},
    },
    reset = function(self)
        for barKey, list in pairs(self.icons) do
            wipe(list)
            wipe(self.seen[barKey])
        end
    end,
    getBarKey = function(_, viewerName)
        if viewerName == "EssentialCooldownViewer" then
            return "cooldowns"
        elseif viewerName == "UtilityCooldownViewer" then
            return "utility"
        elseif viewerName == "BuffIconCooldownViewer" then
            return "buffs"
        end
        return nil
    end,
    getIconTexture = function(_, child)
        local iconWidget = child and child.Icon
        if iconWidget and not iconWidget.GetTexture and iconWidget.Icon then
            iconWidget = iconWidget.Icon
        end
        if iconWidget and iconWidget.GetTexture then
            return iconWidget:GetTexture(), iconWidget
        end
        return nil, nil
    end,
}

-------------------------------------------------------------------------------
--  Update icons for a CDM bar based on Blizzard CDM children
--  Default bars (cooldowns/utility/buffs) mirror Blizzard CDM.
--  Custom bars track user-specified spells directly.
-------------------------------------------------------------------------------
local function UpdateCustomBarIcons(barKey)
    local frame = cdmBarFrames[barKey]
    if not frame then return end

    local barData = barDataByKey[barKey]
    if not barData or not barData.enabled then return end

    local customSpells = barData.customSpells
    local trackedSpells = barData.trackedSpells
    local extraSpells = barData.extraSpells

    local totalCount = 0
    if customSpells then
        totalCount = #customSpells
    elseif trackedSpells then
        totalCount = #trackedSpells + (extraSpells and #extraSpells or 0)
    end
    local icons = cdmBarIcons[barKey]

    if totalCount == 0 then
        local unlockPreview = (KT and KT._unlockActive)
        if unlockPreview then
            local rows = barData.numRows or 1
            if rows < 1 then rows = 1 end
            local placeholderCount = math.max(3, rows * 4)

            -- Ensure we have enough icon frames
            while #icons < placeholderCount do
                local newIcon = CreateCDMIcon(barKey, #icons + 1)
                icons[#icons + 1] = newIcon
            end

            for i, icon in ipairs(icons) do
                if i <= placeholderCount then
                    icon._tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    icon._lastTex = "Interface\\Icons\\INV_Misc_QuestionMark"
                    icon._spellID = nil
                    icon._itemID = nil
                    if icon._cooldown then icon._cooldown:Hide() end
                    if icon._chargeText then icon._chargeText:Hide() end
                    if icon._keybindText then icon._keybindText:Hide() end
                    ns.SetCDMIconShown(icon, true)
                else
                    ns.SetCDMIconShown(icon, false)
                end
            end

            LayoutCDMBar(barKey)
            return
        end

        -- Hide all icons
        if icons then
            for _, icon in ipairs(icons) do ns.SetCDMIconShown(icon, false) end
        end
        if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
            ns._cdmLayoutPending = true
        else
            frame:SetSize(1, 1)
        end
        if barData.isKUITracker then
            local p = KUI_CDM.db and KUI_CDM.db.profile
            local tKey = ns.KUI_TRACKER_BY_BAR and ns.KUI_TRACKER_BY_BAR[barKey]
            local ct = p and tKey and p.customTracker and p.customTracker[tKey]
            local count = (ct and ct.spells and #ct.spells) or 0
            local auto = ct and ct.auto
            local enabled = ct and ct.enabled
            local side = ct and ct.side or barData.playerFrameSide
            local ox = ct and ct.x or barData.playerFrameOffsetX or 0
            local oy = ct and ct.y or barData.playerFrameOffsetY or 0
            ns.TrackerDebugOnce(
                "kui_empty_" .. barKey,
                string.format("KUI Tracker '%s' sin iconos: enabled=%s auto=%s spells=%d side=%s x=%d y=%d",
                    barKey, tostring(enabled), tostring(auto), count, tostring(side), ox, oy)
            )
        end
        return
    end

    -- Active animation setup (same as tracked/mirrored bar paths)
    local activeAnim = barData.activeStateAnim or "2"
    local animR, animG, animB = 1.0, 0.85, 0.0
    if barData.activeAnimClassColor then
        local _, ct = UnitClass("player")
        if ct then
            local cc = RAID_CLASS_COLORS[ct]; if cc then animR, animG, animB = cc.r, cc.g, cc.b end
        end
    elseif barData.activeAnimR then
        animR = barData.activeAnimR; animG = barData.activeAnimG or 0.85; animB = barData.activeAnimB or 0.0
    end
    local swAlpha = barData.swipeAlpha or 0.7

    -- Ensure we have enough icon frames
    while #icons < totalCount do
        local newIcon = CreateCDMIcon(barKey, #icons + 1)
        icons[#icons + 1] = newIcon
    end

    local visibleCount = 0
    local visibleLimit = math.huge
    if barData.isKUITracker and barData.maxIcons and barData.maxIcons > 0 then
        visibleLimit = barData.maxIcons
    end
    local isPotionTrackerBar = barData.isKUITracker and ns.KUI_TRACKER_BY_BAR and ns.KUI_TRACKER_BY_BAR[barKey] == "potion"
    for i = 1, totalCount do
        local spellID
        if customSpells then
            spellID = customSpells[i]
        else
            if i <= #trackedSpells then
                spellID = trackedSpells[i]
            else
                spellID = extraSpells[i - #trackedSpells]
            end
        end

        local ourIcon = icons[i]
        if ourIcon then
            local potionSlotID = isPotionTrackerBar and ns.IsPotionTrackerSlotID
                and ns.IsPotionTrackerSlotID(spellID) and spellID or nil
            if potionSlotID then
                local slotItemID = ns.ResolvePotionTrackerSlotItem
                    and ns.ResolvePotionTrackerSlotItem(potionSlotID)
                spellID = slotItemID and ns.EncodeItemID(slotItemID) or 0
                ourIcon._potionTrackerSlotID = potionSlotID
            else
                ourIcon._potionTrackerSlotID = nil
            end

            -- Skip blank placeholder slots (0 entries from grid reordering)
            if spellID == 0 then
                UpdatePotionTrackerSecureAction(ourIcon, nil)
                ourIcon._blizzChild = nil
                ourIcon._trackedCountItemID = nil
                ourIcon._lastTrackedCount = nil
                ourIcon._forcedPotionCooldownItemID = nil
                ourIcon._forcedPotionCooldownStart = nil
                ourIcon._forcedPotionCooldownDuration = nil
                ns.SetCDMIconShown(ourIcon, false)
                -- Trinket slot entries use negative IDs (-13, -14)
            elseif spellID < 0 then
                local itemID = DecodeItemID(spellID)
                if itemID then
                    local displayItemID = isPotionTrackerBar and ns.ResolvePotionTrackerDisplayItem and ns.ResolvePotionTrackerDisplayItem(itemID) or itemID
                    local canShowItem = displayItemID ~= nil
                    if canShowItem and isPotionTrackerBar then
                        canShowItem = ns.ShouldShowPotionTrackerItem
                            and ns.ShouldShowPotionTrackerItem(displayItemID)
                            or GetTrackerOwnedItemCount(displayItemID) > 0
                    end
                    if canShowItem then
                        local tex = C_Item.GetItemIconByID(displayItemID)
                        if tex and tex ~= ourIcon._lastTex then
                            ourIcon._tex:SetTexture(tex)
                            ourIcon._lastTex = tex
                        end
                        ourIcon._itemID = displayItemID
                        ourIcon._spellID = nil
                        ourIcon._trinketSlot = nil
                        UpdatePotionTrackerSecureAction(ourIcon, isPotionTrackerBar and displayItemID or nil)
                        if isPotionTrackerBar then
                            local currentTrackedCount = GetTrackedItemDisplayCount(displayItemID)
                            if ourIcon._trackedCountItemID ~= displayItemID then
                                ourIcon._trackedCountItemID = displayItemID
                                ourIcon._lastTrackedCount = currentTrackedCount
                            else
                                local previousTrackedCount = tonumber(ourIcon._lastTrackedCount)
                                ourIcon._lastTrackedCount = currentTrackedCount
                            end
                        end
                        ApplyItemCooldown(ourIcon, displayItemID, barData.desaturateOnCD, barData.showCharges,
                            barData.isKUITracker == true)
                        if ourIcon._keybindText and barData.showKeybind then
                            local cachedKey = ns.FindCachedKeybindForIcon(ourIcon)
                            if cachedKey then
                                ourIcon._keybindText:SetText(cachedKey)
                                ourIcon._keybindText:Show()
                            else
                                ourIcon._keybindText:Hide()
                            end
                        elseif ourIcon._keybindText then
                            ourIcon._keybindText:Hide()
                        end
                        ns.SetCDMIconShown(ourIcon, true)
                        visibleCount = visibleCount + 1
                        if visibleCount > visibleLimit then
                            ns.SetCDMIconShown(ourIcon, false)
                            visibleCount = visibleCount - 1
                        end
                    else
                        UpdatePotionTrackerSecureAction(ourIcon, nil)
                        ourIcon._itemID = nil
                        ourIcon._spellID = nil
                        ourIcon._trinketSlot = nil
                        ourIcon._trackedCountItemID = nil
                        ourIcon._lastTrackedCount = nil
                        ourIcon._forcedPotionCooldownItemID = nil
                        ourIcon._forcedPotionCooldownStart = nil
                        ourIcon._forcedPotionCooldownDuration = nil
                        ns.SetCDMIconShown(ourIcon, false)
                    end
                else
                    local slot = -spellID
                    local invItemID = GetInventoryItemID("player", slot)
                    -- Keep an equipped trinket rendered while it is on cooldown.
                    -- IsUsableItem() is false during that cooldown, which used to
                    -- make the tracker hide the icon immediately after the first use.
                    if invItemID then
                        local tex = C_Item.GetItemIconByID(invItemID)
                        if not tex and GetInventoryItemTexture then
                            tex = GetInventoryItemTexture("player", slot)
                        end
                        if tex and tex ~= ourIcon._lastTex then
                            ourIcon._tex:SetTexture(tex)
                            ourIcon._lastTex = tex
                        end
                        ourIcon._itemID = invItemID
                        ourIcon._spellID = nil
                        ourIcon._trinketSlot = slot
                        UpdatePotionTrackerSecureAction(ourIcon, nil)
                        ApplyTrinketCooldown(ourIcon, slot, barData.desaturateOnCD)
                        if ourIcon._keybindText and barData.showKeybind then
                            local cachedKey = ns.FindCachedKeybindForIcon(ourIcon)
                            if cachedKey then
                                ourIcon._keybindText:SetText(cachedKey)
                                ourIcon._keybindText:Show()
                            else
                                ourIcon._keybindText:Hide()
                            end
                        elseif ourIcon._keybindText then
                            ourIcon._keybindText:Hide()
                        end
                        ns.SetCDMIconShown(ourIcon, true)
                        visibleCount = visibleCount + 1
                        if visibleCount > visibleLimit then
                            ns.SetCDMIconShown(ourIcon, false)
                            visibleCount = visibleCount - 1
                        end
                    else
                        UpdatePotionTrackerSecureAction(ourIcon, nil)
                        ourIcon._trinketSlot = nil
                        ourIcon._trackedCountItemID = nil
                        ourIcon._lastTrackedCount = nil
                        ourIcon._forcedPotionCooldownItemID = nil
                        ourIcon._forcedPotionCooldownStart = nil
                        ourIcon._forcedPotionCooldownDuration = nil
                        ns.SetCDMIconShown(ourIcon, false)
                        if barData.isKUITracker then
                            local reason = invItemID and "not_usable" or "empty_slot"
                            ns.TrackerDebugOnce(
                                "kui_trinket_" .. barKey .. "_" .. tostring(slot),
                                string.format("KUI Tracker '%s' trinket slot %d oculto (%s).", barKey, slot, reason)
                            )
                        end
                    end
                end
            else
                -- Resolve talent override: if the user added Holy Prism but the player
                -- now has Divine Toll selected, display and track Divine Toll instead.
                local resolvedID = spellID
                ourIcon._itemID = nil
                UpdatePotionTrackerSecureAction(ourIcon, nil)
                if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
                    -- The override API can be restricted/secret during combat. Never
                    -- let that transient state abort the whole custom tracker update.
                    local ok, overrideID = pcall(C_SpellBook.FindSpellOverrideByID, spellID)
                    if ok and IsCleanPositiveNumber(overrideID) then
                        resolvedID = overrideID
                    end
                end
                local isBuffBarForOverride = (barKey == "buffs" or barData.barType == "buffs")
                -- Second-level runtime override: e.g. spell A (base) -> spell B (talent)
                -- -> spell C (activation override, e.g. Avenging Crusader transforms Crusader Strike).
                -- FindSpellOverrideByID only resolves one level; check the Blizzard CDM
                -- children cache for a deeper override on the already-resolved ID.
                -- Skip on buff bars: buff bars show the base spell's state/CD, not the
                -- temporary replacement that appears while the spell is on cooldown.
                if not isBuffBarForOverride then
                    local blizzOverride = _tickBlizzOverrideCache[resolvedID] or _tickBlizzOverrideCache[spellID]
                    if blizzOverride then
                        resolvedID = blizzOverride
                    end
                end
                -- Propagate charge cache from base to override so talent-swapped spells
                -- show charges correctly even before the override ID has been seen OOC.
                -- Always attempt direct detection on the final resolvedID first -> it may
                -- have charges even if the base spell doesn't (three-level chain).
                if resolvedID ~= spellID then
                    -- Always try direct detection on the resolved ID (cheapest path)
                    CacheMultiChargeSpell(resolvedID)
                    -- If resolved ID still unknown (secret/combat), check if we have a
                    -- live Blizzard child for it and mark it as a charge spell so
                    -- ApplySpellCooldown uses the charge display path.
                    if _multiChargeSpells[resolvedID] == nil and _tickBlizzChildCache[resolvedID] then
                        -- We have a live Blizzard child -> treat as charge spell so the
                        -- charge display path runs. ApplySpellCooldown will call
                        -- GetSpellCharges which may still be secret, but the shadow
                        -- cooldown frames will correctly reflect the charge state.
                        _multiChargeSpells[resolvedID] = true
                    end
                    -- If still unknown, try propagating from intermediate (only if true)
                    if _multiChargeSpells[resolvedID] == nil then
                        local intermediate
                        if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
                            local ok, value = pcall(C_SpellBook.FindSpellOverrideByID, spellID)
                            if ok and IsCleanPositiveNumber(value) then
                                intermediate = value
                            end
                        end
                        if intermediate and intermediate ~= resolvedID then
                            CacheMultiChargeSpell(intermediate)
                            if _multiChargeSpells[intermediate] == true then
                                _multiChargeSpells[resolvedID] = true
                                if _maxChargeCount[intermediate] then
                                    _maxChargeCount[resolvedID] = _maxChargeCount[intermediate]
                                end
                            end
                        end
                    end
                    -- If still unknown, propagate from base -> but only if base is true
                    if _multiChargeSpells[resolvedID] == nil then
                        CacheMultiChargeSpell(spellID)
                        if _multiChargeSpells[spellID] == true then
                            _multiChargeSpells[resolvedID] = true
                            if _maxChargeCount[spellID] then
                                _maxChargeCount[resolvedID] = _maxChargeCount[spellID]
                            end
                        end
                    end
                end
                -- Cache spell icon texture to avoid C_Spell.GetSpellInfo per tick
                local texID = _spellIconCache[resolvedID]
                if not texID then
                    local spellInfo = C_Spell.GetSpellInfo(resolvedID)
                    if spellInfo then
                        texID = spellInfo.iconID
                        _spellIconCache[resolvedID] = texID
                    end
                end
                if texID then
                    if texID ~= ourIcon._lastTex then
                        ourIcon._tex:SetTexture(texID)
                        ourIcon._lastTex = texID
                    end

                    -- Cooldown, desaturation, and charge text (consolidated)
                    ourIcon._spellID = resolvedID
                    ourIcon._baseSpellID = spellID
                    -- Apply cached keybind for this spell if not already set
                    if ourIcon._keybindText and barData.showKeybind then
                        local cachedKey = ns.FindCachedKeybindForIcon(ourIcon)
                        if cachedKey then
                            ourIcon._keybindText:SetText(cachedKey)
                            ourIcon._keybindText:Show()
                        elseif ourIcon._keybindText:IsShown() then
                            ourIcon._keybindText:Hide()
                        end
                    end
                    -- Detect active aura state before applying cooldown.
                    -- If the spell has an active player aura, show its duration on the
                    -- cooldown frame (same as the main bar path for buff bars).
                    -- When the spell has a runtime override (resolvedID != spellID) on
                    -- a non-buff bar, skip aura display so the override's actual cooldown
                    -- is shown instead (e.g. a 2min ability that becomes a 24s kick).
                    local auraHandled = false
                    local skipCDDisplay = false
                    local hasRuntimeOverride = resolvedID ~= spellID and not isBuffBarForOverride
                    local stackBlizzChild, stackAuraID, stackAuraUnit = nil, nil, "player"
                    local summonFallbackHandled = false
                    do
                        -- Primary: look up the Blizzard CDM child for this spell via the
                        -- spellID -> cooldownID map, then find the child frame by cooldownID.
                        -- This works for custom bar spells not present in _tickBlizzAllChildCache
                        -- because they may not be visible in any viewer at the moment.
                        local blizzChild = _tickBlizzAllChildCache[resolvedID]
                        if not blizzChild then
                            local cdID = _spellToCooldownID[resolvedID] or _spellToCooldownID[spellID]
                            if cdID then
                                blizzChild = FindCDMChildByCooldownID(cdID)
                            end
                        end
                        if blizzChild then
                            -- A pooled Blizzard CDM child can be stale: once its
                            -- buff/aura/cooldown ends, Blizzard hides the pool frame
                            -- but the object persists in the viewer (EnumerateChildren
                            -- walks hidden pool frames too) and keeps wasSetFromAura.
                            -- Trusting it would leave the icon and its active glow
                            -- stuck "active" forever while in combat. Only trust a
                            -- child that is still shown or carries a live cooldown.
                            if blizzChild.IsShown and not blizzChild:IsShown()
                               and not IsBufChildCooldownActive(blizzChild)
                               and not ns.IsShownBuffViewerChild(blizzChild) then
                                blizzChild = nil
                            end
                            if blizzChild then
                                stackBlizzChild = blizzChild
                                stackAuraID = blizzChild.auraInstanceID
                                stackAuraUnit = blizzChild.auraDataUnit or "player"
                            end
                        end
                        local isAura = blizzChild and
                            (blizzChild.wasSetFromAura == true or blizzChild.auraInstanceID ~= nil)
                        local auraID = stackAuraID
                        local auraUnit = stackAuraUnit

                        -- Fallback: spell not in any CDM viewer -> check _tickBlizzActiveCache
                        -- which covers all four viewers scanned each tick.
                        if not isAura then
                            if _tickBlizzActiveCache[resolvedID] or _tickBlizzActiveCache[spellID] then
                                isAura = true
                            end
                        end

                        if isAura then
                            -- When the spell has a runtime override on a non-buff bar,
                            -- skip aura duration display so the override spell's actual
                            -- cooldown is shown (e.g. 2min ability becomes 24s kick).
                            if hasRuntimeOverride then
                                auraHandled = false
                            else
                                local chargeInfo = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(resolvedID)
                                local isChargeSid = chargeInfo ~= nil
                                if auraID and (not isChargeSid or isBuffBarForOverride) then
                                    local ok, auraDurObj = pcall(C_UnitAuras.GetAuraDuration, auraUnit, auraID)
                                    if ok and auraDurObj then
                                        ourIcon._cooldown:Clear()
                                        pcall(ourIcon._cooldown.SetCooldownFromDurationObject, ourIcon._cooldown,
                                            auraDurObj, true)
                                        ourIcon._cooldown:SetReverse(false)
                                        auraHandled = true
                                        skipCDDisplay = true
                                    else
                                        -- The aura lookup returned nothing: either the effect ended
                                        -- or its data is restricted (secret) while still active.
                                        -- Keep the effect live only while the Blizzard child still
                                        -- carries a non-expired cooldown/duration; otherwise the
                                        -- DoT is over and the active glow must be cleared.
                                        if IsBlizzChildEffectLive(blizzChild) then
                                            auraHandled = true
                                        end
                                    end
                                elseif not isChargeSid then
                                    -- No aura instance on the child: Blizzard may clear it once the
                                    -- effect ends. Keep active only while a live effect remains.
                                    if IsBlizzChildEffectLive(blizzChild) then
                                        auraHandled = true
                                    end
                                else
                                    auraHandled = true
                                end
                            end
                        end

                        -- Final fallback: _tickBlizzActiveCache covers spells active in CDM viewers
                        if not hasRuntimeOverride and not auraHandled and (_tickBlizzActiveCache[resolvedID] or _tickBlizzActiveCache[spellID]) then
                            auraHandled = true
                        end

                        -- Summon-type fallback: spells with no aura but whose Blizzard CDM
                        -- child is visible are considered active (e.g. pet summons).
                        -- On buff bars, copy the child's cooldown to show effect duration.
                        if not hasRuntimeOverride and not auraHandled then
                            local blzCh2 = _tickBlizzAllChildCache[resolvedID] or _tickBlizzAllChildCache[spellID]
                            if blzCh2 and blzCh2:IsShown() then
                                if not stackBlizzChild then
                                    stackBlizzChild = blzCh2
                                    stackAuraID = blzCh2.auraInstanceID
                                    stackAuraUnit = blzCh2.auraDataUnit or "player"
                                end
                                if isBuffBarForOverride then
                                    auraHandled = true
                                    skipCDDisplay = true
                                    summonFallbackHandled = true
                                    -- Use the cached DurationObject captured by our hook
                                    -- to avoid secret-value arithmetic from GetCooldownTimes.
                                    local blzCD = blzCh2.Cooldown
                                    if blzCD then
                                        ourIcon._cooldown:Clear()
                                        if _cdmDurObjCache[blzCh2] then
                                            pcall(ourIcon._cooldown.SetCooldownFromDurationObject, ourIcon._cooldown,
                                                _cdmDurObjCache[blzCh2], true)
                                        elseif _cdmRawStartCache[blzCh2] and _cdmRawDurCache[blzCh2]
                                            and not (issecretvalue and (issecretvalue(_cdmRawStartCache[blzCh2])
                                                or issecretvalue(_cdmRawDurCache[blzCh2]))) then
                                            pcall(ourIcon._cooldown.SetCooldown, ourIcon._cooldown, _cdmRawStartCache[blzCh2],
                                                _cdmRawDurCache[blzCh2])
                                        end
                                        ourIcon._cooldown:SetReverse(false)
                                    end
                                end
                            end
                        end
                    end

                    -- The DurationObject copied above is the supported aura
                    -- display path in restricted combat. Raw aura data cannot
                    -- be used to validate it once the aura becomes secret.

                    local _, insufficientPower = GetSpellUsableInfo(resolvedID)
                    ApplySpellCooldown(ourIcon, resolvedID, barData.desaturateOnCD, barData.showCharges, swAlpha,
                        skipCDDisplay, insufficientPower, barData.hideGCDSwipe, stackBlizzChild, isBuffBarForOverride)

                    if ourIcon._cooldown.SetUseAuraDisplayTime then
                        ourIcon._cooldown:SetUseAuraDisplayTime(auraHandled and skipCDDisplay)
                    end

                    ApplyActiveAnimation(ourIcon, auraHandled, barData, barKey, activeAnim, animR, animG, animB, swAlpha)
                    ourIcon._blizzChild = stackBlizzChild

                    ns.SetCDMIconShown(ourIcon, true)
                    visibleCount = visibleCount + 1
                    if visibleCount > visibleLimit then
                        ns.SetCDMIconShown(ourIcon, false)
                        visibleCount = visibleCount - 1
                    end

                    -- Hide buff icons when inactive
                    -- Skip during unlock mode so the bar is fully visible for repositioning
                    if barData.hideBuffsWhenInactive and isBuffBarForOverride and not KT._unlockActive
                        and not (KT._mainFrame and KT._mainFrame:IsShown()) then
                        local isActive = IsCDMBuffActiveForBar(resolvedID, spellID, stackBlizzChild)
                        if not isActive then
                            UpdatePotionTrackerSecureAction(ourIcon, nil)
                            ourIcon._blizzChild = nil
                            ns.SetCDMIconShown(ourIcon, false)
                            visibleCount = visibleCount - 1
                        end
                    end
                else
                    UpdatePotionTrackerSecureAction(ourIcon, nil)
                    ourIcon._blizzChild = nil
                    ns.SetCDMIconShown(ourIcon, false)
                end
            end -- spellID < 0 else
        end
    end

    if barData.isKUITracker then
        ns.TrackerDebugOnce(
            "kui_vis_" .. barKey,
            string.format("KUI Tracker '%s' visibles=%d total=%d alpha=%.2f",
                barKey, visibleCount, totalCount, frame:GetAlpha() or 1)
        )
    end

    if visibleCount == 0 and barData.isKUITracker then
        local list = {}
        if customSpells then
            for i = 1, math.min(4, #customSpells) do list[#list + 1] = tostring(customSpells[i]) end
        elseif trackedSpells then
            for i = 1, math.min(4, #trackedSpells) do list[#list + 1] = tostring(trackedSpells[i]) end
        end
        ns.TrackerDebugOnce(
            "kui_novis_" .. barKey,
            string.format("KUI Tracker '%s' sin iconos visibles (total=%d) sample=[%s].",
                barKey, totalCount, table.concat(list, ","))
        )
    end

    -- Hide excess
    for i = totalCount + 1, #icons do
        local ic = icons[i]
        if ic._procGlowActive then
            StopNativeGlow(ic._glowOverlay)
            ic._procGlowActive = false
        end
        UpdatePotionTrackerSecureAction(ic, nil)
        ns.SetCDMIconShown(ic, false)
    end

    -- Only re-layout when the visible or configured slot count changes.
    if visibleCount ~= (frame._prevVisibleCount or 0)
        or totalCount ~= (frame._prevCustomSlotCount or 0) then
        frame._prevVisibleCount = visibleCount
        frame._prevCustomSlotCount = totalCount
        LayoutCDMBar(barKey)
    end
end

local function SafeUpdateCustomBarIcons(barKey)
    local ok, err = pcall(UpdateCustomBarIcons, barKey)
    if ok then
        ns._customTrackerRecoveryAttempts = 0
        ns._customTrackerLastError = nil
        return true
    end

    ns._customTrackerLastError = {
        barKey = barKey,
        message = err,
        time = GetTime(),
    }

    local now = GetTime()
    if now - (ns._customTrackerRecoveryWindow or 0) > 2 then
        ns._customTrackerRecoveryWindow = now
        ns._customTrackerRecoveryAttempts = 0
    end

    if (ns._customTrackerRecoveryAttempts or 0) < 3
        and not ns._customTrackerRecoveryPending then
        ns._customTrackerRecoveryAttempts = (ns._customTrackerRecoveryAttempts or 0) + 1
        ns._customTrackerRecoveryPending = true
        C_Timer.After(0.1, function()
            ns._customTrackerRecoveryPending = nil
            if ns.RequestCustomCooldownUpdate then
                ns.RequestCustomCooldownUpdate("custom_tracker_recovery")
            end
        end)
    end

    return false
end
function ns.RefreshCDMBarFromConfig(barKey)
    local barData = barDataByKey and barDataByKey[barKey]
    if not barData then return false end

    local usedLocalLayout = false
    if ns.BLIZZ_CDM_FRAMES[barKey] then
        local nativeContainer = cdmBarFrames and cdmBarFrames[barKey]
        if nativeContainer then nativeContainer._nativeForceRefresh = true end
        UpdateCDMBarIcons(barKey)
        usedLocalLayout = ns.HasLocalMainBarLayout and ns.HasLocalMainBarLayout(barData) or false
    elseif barData.customSpells then
        SafeUpdateCustomBarIcons(barKey)
        usedLocalLayout = true
    elseif UpdateCDMBarIcons then
        UpdateCDMBarIcons(barKey)
    end

    if LayoutCDMBar then
        LayoutCDMBar(barKey)
    end
    if ns.CDMApplyVisibility then
        ns.CDMApplyVisibility()
    end
    if _keybindCacheReady and ns.ApplyCachedKeybinds then
        ns.ApplyCachedKeybinds()
    elseif ns.UpdateCDMKeybinds then
        ns.UpdateCDMKeybinds()
    end

    return usedLocalLayout
end

function ns.GetNativeCDMIconTexture(frame)
    local tex = frame and frame.Icon
    if tex and not tex.GetTexture and tex.Icon then tex = tex.Icon end
    return tex and tex.GetTexture and tex or nil
end

function ns.ReleaseNativeCDMFrame(frame)
    local fd = ns._nativeCDMFrameData[frame]
    if not fd then return end
    fd.suppressedByKUI = true
    fd.anchor = nil
    fd.barKey = nil
    frame._barKey = nil
    frame._blizzChild = nil
    if frame._glowOverlay then StopNativeGlow(frame._glowOverlay) end
    if frame._customModuleGlowOverlay then StopNativeGlow(frame._customModuleGlowOverlay) end
    frame._customModuleGlowActive = false
    frame._customModuleGlowWanted = false
    if frame._keybindText then frame._keybindText:Hide() end
    if frame._pressOverlay then frame._pressOverlay:Hide() end
    frame:SetAlpha(0)
    if fd.isBuffFrame then
        -- Blizzard owns buff-frame activation and hiding.
        if frame.Cooldown and frame.Cooldown.SetDrawSwipe then
            frame.Cooldown:SetDrawSwipe(false)
        end
    else
        if not fd.parkGuard then
            fd.parkGuard = true
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
            fd.parkGuard = nil
        end
    end
end

function ns.RestoreNativeCDMFrames()
    for frame, fd in pairs(ns._nativeCDMFrameData) do
        fd.anchor = nil
        fd.barKey = nil
        frame._barKey = nil
        frame._blizzChild = nil
        if frame._bg then frame._bg:Hide() end
        if frame._edges then
            for _, edge in ipairs(frame._edges) do edge:Hide() end
        end
        if frame._keybindText then frame._keybindText:Hide() end
        if frame._glowOverlay then StopNativeGlow(frame._glowOverlay) end
        if frame._pressOverlay then frame._pressOverlay:Hide() end
        if frame._shapeMask then
            if frame._tex then pcall(frame._tex.RemoveMaskTexture, frame._tex, frame._shapeMask) end
            if frame._cooldown then pcall(frame._cooldown.RemoveMaskTexture, frame._cooldown, frame._shapeMask) end
            frame._shapeMask:Hide()
        end
        if frame._tex then
            frame._tex:ClearAllPoints()
            frame._tex:SetAllPoints(frame)
            frame._tex:SetTexCoord(0, 1, 0, 1)
        end
        if frame._cooldown then
            frame._cooldown:ClearAllPoints()
            frame._cooldown:SetAllPoints(frame)
            if frame._cooldown.SetDrawSwipe then frame._cooldown:SetDrawSwipe(true) end
            frame._cooldown:SetHideCountdownNumbers(false)
        end
        if frame.Border then frame.Border:Show() end
        frame:SetAlpha(1)
    end

    for _, frameName in pairs(ns.BLIZZ_CDM_FRAMES) do
        local viewer = _G[frameName]
        if viewer and viewer.Layout then pcall(viewer.Layout, viewer) end
    end
end

function ns.IsNativeCDMFrameActive(frame, barKey)
    if not frame then return false end
    -- BuffIconCooldownViewer only contributes live frames to the hosted buffs
    -- bar. Other hosted bars may still represent an aura-backed spell.
    if barKey == "buffs" then return true end
    local fd = ns._nativeCDMFrameData[frame]
    if fd and fd.nativeActiveOverride ~= nil then
        -- The swipe-color override comes from Blizzard's SetSwipeColor hook and
        -- can go stale when Blizzard leaves the pool frame shown without
        -- repainting the swipe once the buff/aura/cooldown ends. Cross-check the
        -- child's live cooldown/duration state so a finished DoT clears the glow.
        if IsBlizzChildEffectLive(frame) then
            return fd.nativeActiveOverride
        end
        if not fd._staleWarned then
            fd._staleWarned = true
            ns.CDMGlowDebugPrint(frame, "native override stale", "bar=" .. tostring(barKey), "spell=" .. tostring(frame._spellID))
        end
        return false
    end
    local sid = IsCleanPositiveNumber(frame._spellID) and frame._spellID or nil
    local baseSid = IsCleanPositiveNumber(frame._baseSpellID) and frame._baseSpellID or nil
    return (sid and _tickBlizzActiveCache[sid])
        or (baseSid and _tickBlizzActiveCache[baseSid])
        or false
end

function ns.ApplyNativeCDMVisualState(frame)
    local fd = frame and ns._nativeCDMFrameData[frame]
    if not (fd and fd.barKey) or fd.applyingVisual then return end
    local barKey = fd.barKey
    local barData = barDataByKey[barKey]
    local cooldown = frame._cooldown or frame.Cooldown
    if not (barData and cooldown) then return end

    local baseLevel = frame:GetFrameLevel()
    if frame._textOverlay then pcall(frame._textOverlay.SetFrameLevel, frame._textOverlay, baseLevel + 23) end
    if frame._glowOverlay then pcall(frame._glowOverlay.SetFrameLevel, frame._glowOverlay, baseLevel + 16) end
    pcall(cooldown.SetFrameLevel, cooldown, baseLevel + 14)
    if frame.Applications then pcall(frame.Applications.SetFrameLevel, frame.Applications, baseLevel + 23) end
    if frame.ChargeCount then pcall(frame.ChargeCount.SetFrameLevel, frame.ChargeCount, baseLevel + 23) end

    local activeAnim = barData.activeStateAnim or "blizzard"
    local animR, animG, animB = 1.0, 0.85, 0.0
    if barData.activeAnimClassColor then
        local _, classToken = UnitClass("player")
        local color = classToken and RAID_CLASS_COLORS[classToken]
        if color then animR, animG, animB = color.r, color.g, color.b end
    elseif barData.activeAnimR then
        animR = barData.activeAnimR
        animG = barData.activeAnimG or 0.85
        animB = barData.activeAnimB or 0.0
    end

    local active = ns.IsNativeCDMFrameActive(frame, barKey) and true or false
    local overrideStyle, overrideR, overrideG, overrideB = ns.CDMResolveExplicitBarGlowOverride(frame, true)
    local signature = table.concat({
        tostring(active), tostring(activeAnim),
        tostring(animR), tostring(animG), tostring(animB),
        tostring(overrideStyle), tostring(overrideR), tostring(overrideG), tostring(overrideB),
        tostring(barData.swipeR), tostring(barData.swipeG), tostring(barData.swipeB),
        tostring(barData.swipeAlpha), tostring(barData.activeSwipeUsesGlowColor),
        tostring(barData.showCooldownText),
    }, ":")

    fd.applyingVisual = true
    if fd.activeVisualSignature ~= signature then
        fd.activeVisualSignature = signature
        if frame._isActive and frame._glowOverlay and not frame._procGlowActive
            and not frame._customModuleGlowActive then
            StopNativeGlow(frame._glowOverlay)
        end
        frame._isActive = false
    end

    ApplyActiveAnimation(
        frame, active, barData, barKey, activeAnim,
        animR, animG, animB, barData.swipeAlpha or 0.7
    )

    -- Blizzard may rewrite these properties whenever its native frame changes
    -- state. Reassert the effective KUI values in the CDM
    -- hooks, while the guard prevents our own Set* calls from recursing.
    local swipeR, swipeG, swipeB = GetConfiguredSwipeColor(barData, frame)
    if active and activeAnim ~= "none" and activeAnim ~= "hideActive" then
        local glowR, glowG, glowB = animR, animG, animB
        if overrideStyle ~= nil then
            glowR, glowG, glowB = overrideR or glowR, overrideG or glowG, overrideB or glowB
        end
        swipeR, swipeG, swipeB = GetActiveSwipeColor(barData, glowR, glowG, glowB, frame)
    end
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetSwipeColor then
        fd.desiredSwipeR, fd.desiredSwipeG, fd.desiredSwipeB = swipeR, swipeG, swipeB
        fd.desiredSwipeA = barData.swipeAlpha or 0.7
        cooldown:SetSwipeColor(swipeR, swipeG, swipeB, barData.swipeAlpha or 0.7)
    end
    fd.desiredHideCountdown = not barData.showCooldownText
    cooldown:SetHideCountdownNumbers(fd.desiredHideCountdown)
    fd.applyingVisual = nil
end

function ns.EnsureNativeCDMFrame(frame, barKey, barData)
    local fd = ns._nativeCDMFrameData[frame]
    if not fd then
        fd = {}
        ns._nativeCDMFrameData[frame] = fd
    end

    fd.suppressedByKUI = nil
    fd.barKey = barKey
    fd.isBuffFrame = (frame.viewerFrame == _G.BuffIconCooldownViewer
        or frame.viewerFrame == _G.BuffBarCooldownViewer) and true or false

    local tex = ns.GetNativeCDMIconTexture(frame)
    frame._tex = tex
    frame._cooldown = frame.Cooldown
    frame._blizzChild = frame
    frame._barKey = barKey
    frame._spellID = IsCleanPositiveNumber(frame._cdmResolvedSid) and frame._cdmResolvedSid or nil
    frame._baseSpellID = IsCleanPositiveNumber(frame._cdmBaseSpellID)
        and frame._cdmBaseSpellID or frame._spellID

    if not fd.decorated then
        fd.decorated = true

        frame:HookScript("OnHide", function(self)
            if self._customModuleGlowActive and self._customModuleGlowOverlay then
                StopNativeGlow(self._customModuleGlowOverlay)
                self._customModuleGlowActive = false
                self._customModuleGlowWanted = false
                self._customModuleGlowStyle = nil
            end
        end)

        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(frame)
        frame._bg = bg

        local textOverlay = CreateFrame("Frame", nil, frame)
        textOverlay:SetAllPoints(frame)
        textOverlay:EnableMouse(false)
        frame._textOverlay = textOverlay

        local keybindText = textOverlay:CreateFontString(nil, "OVERLAY")
        keybindText:SetJustifyH("LEFT")
        keybindText:Hide()
        frame._keybindText = keybindText

        local glowOverlay = CreateFrame("Frame", nil, frame)
        glowOverlay:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
        glowOverlay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
        ApplyCDMGlowLayer(glowOverlay, frame, 3)
        glowOverlay:SetAlpha(0)
        glowOverlay:EnableMouse(false)
        glowOverlay._kuiUseSelfGlowTarget = true
        frame._glowOverlay = glowOverlay

        local pressOverlay = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        pressOverlay:SetAllPoints(frame)
        pressOverlay:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        pressOverlay:SetBlendMode("ADD")
        pressOverlay:SetAlpha(0)
        pressOverlay:Hide()
        frame._pressOverlay = pressOverlay

        local edges = {}
        for i = 1, 4 do
            edges[i] = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        end
        edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT")
        edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT")
        edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT")
        edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT")
        frame._edges = edges

        -- KUI must never add a second stack counter to a native frame. Blizzard's
        -- Applications/ChargeCount widgets remain the sole count authority.
        frame._chargeText = nil

        if frame.Border then frame.Border:Hide() end
        if frame.DebuffBorder then frame.DebuffBorder:Hide() end

        hooksecurefunc(frame, "SetPoint", function(_, _, relativeTo)
            if fd.pointGuard then return end
            local anchor = fd.anchor
            if not anchor then
                if fd.decorated then ns.ReleaseNativeCDMFrame(frame) end
                return
            end
            if relativeTo == anchor[2] then return end
            fd.pointGuard = true
            frame:ClearAllPoints()
            frame:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
            fd.pointGuard = nil
        end)

        if frame.OnActiveStateChanged then
            hooksecurefunc(frame, "OnActiveStateChanged", function()
                -- Coalesced: a burst of pool frames flipping active state (procs,
                -- buffs expiring) must not invalidate the snapshot once per frame
                -- and queue an immediate update each time. Let the shared coalescer
                -- mark the bar dirty once per burst.
                if ns.NativeCDMViewerChanged then
                    local vName = nil
                    local vf = frame.viewerFrame or frame:GetParent()
                    if vf and vf.GetName then vName = vf:GetName() end
                    if not vName then
                        -- Fall back to the bar this frame belongs to so we still
                        -- get a targeted refresh instead of an unknown full pass.
                        if barKey == "cooldowns" then
                            vName = "EssentialCooldownViewer"
                        elseif barKey == "utility" then
                            vName = "UtilityCooldownViewer"
                        elseif barKey == "buffs" then
                            vName = "BuffIconCooldownViewer"
                        end
                    end
                    ns.NativeCDMViewerChanged("native_active_state", vName)
                else
                    CDMRT:MarkBarDirty(barKey, "native_active_state", barKey == "buffs")
                    if ns.RunCDMUpdateIfIdle then ns.RunCDMUpdateIfIdle() end
                end
            end)
        end

-- Suppressed frames still belong to Blizzard's pool, whose refreshes
        -- may raise their alpha without moving them. Keep only rejected frames
        -- at zero; claimed frames take the normal SyncNativeCDMBarAlpha path.
        hooksecurefunc(frame, "SetAlpha", function()
            if not fd.suppressedByKUI or fd.alphaGuard then return end
            fd.alphaGuard = true
            frame:SetAlpha(0)
            fd.alphaGuard = nil
        end)

        -- Blizzard scales pool icons individually to its own grid (e.g. the
        -- utility viewer sizes its icons at ~0.9). KUI computes its grid with
        -- the un-scaled iconW/H, so any non-1 icon scale distorts the layout:
        -- icons render smaller than their slot and leave a trailing gap in the
        -- bar box. While a frame is KUI-claimed, keep its scale at 1 and let
        -- barScale handle overall sizing. Released frames keep Blizzard's.
        hooksecurefunc(frame, "SetScale", function()
            if fd.suppressedByKUI or fd.scaleGuard then return end
            if not fd.barKey then return end
            fd.scaleGuard = true
            frame:SetScale(1)
            fd.scaleGuard = nil
        end)

        local nativeCooldown = frame.Cooldown
        if nativeCooldown and not fd.visualHooksInstalled then
            fd.visualHooksInstalled = true

            -- Blizzard repaints the native swipe after its item-state update.
            -- Reassert only the cached visual properties here; never queue an
            -- update or rebuild.  The guard makes our own Set* calls inert.
            hooksecurefunc(nativeCooldown, "SetSwipeColor", function()
                if fd.applyingVisual then return end

                local activeChanged = false
                if not fd.isBuffFrame then
                    local color = frame.cooldownSwipeColor
                    if color and type(color) ~= "number" and color.GetRGBA then
                        local ok, red = pcall(color.GetRGBA, color)
                        if ok and type(red) == "number"
                            and not (issecretvalue and issecretvalue(red)) then
                            local isActive = red ~= 0
                            activeChanged = fd.nativeActiveOverride ~= isActive
                            fd.nativeActiveOverride = isActive
                        end
                    end
                end

                if activeChanged then
                    ns.ApplyNativeCDMVisualState(frame)
                    return
                end

                if fd.desiredSwipeR ~= nil then
                    fd.applyingVisual = true
                    nativeCooldown:SetSwipeColor(fd.desiredSwipeR, fd.desiredSwipeG,
                        fd.desiredSwipeB, fd.desiredSwipeA or 0.7)
                    fd.applyingVisual = nil
                end
            end)

            hooksecurefunc(nativeCooldown, "SetDrawSwipe", function()
                if fd.applyingVisual then return end
                fd.applyingVisual = true
                nativeCooldown:SetDrawSwipe(true)
                fd.applyingVisual = nil
            end)

            hooksecurefunc(nativeCooldown, "SetHideCountdownNumbers", function()
                if fd.applyingVisual or fd.desiredHideCountdown == nil then return end
                fd.applyingVisual = true
                nativeCooldown:SetHideCountdownNumbers(fd.desiredHideCountdown)
                fd.applyingVisual = nil
            end)
        end
    end

    local baseLevel = frame:GetFrameLevel()
    if frame._bg then
        local hasCustomShape = frame._shapeApplied and frame._shapeName and frame._shapeName ~= 'none'
        if hasCustomShape then frame._bg:Hide() else frame._bg:Show() end
    end
    if frame._edges then
        local hasCustomShape = frame._shapeApplied and frame._shapeName and frame._shapeName ~= 'none'
        for _, edge in ipairs(frame._edges) do
            if hasCustomShape then edge:Hide() else edge:Show() end
        end
    end
    if frame._textOverlay then
        frame._textOverlay:SetFrameLevel(baseLevel + 23)
        frame._textOverlay:SetFrameStrata(frame:GetFrameStrata())
    end
    if frame._shapeBorderFrame then
        frame._shapeBorderFrame:SetFrameStrata(frame:GetFrameStrata())
    end
    if frame._glowOverlay then frame._glowOverlay:SetFrameLevel(baseLevel + 16) end
    -- Keep the Cooldown above its border,
    -- with glow/text still higher. Below the border the swipe only flickers at
    -- the edges, which was the exact failure visible in KUI.
    if frame.Cooldown then frame.Cooldown:SetFrameLevel(baseLevel + 14) end
    if frame.Applications then pcall(frame.Applications.SetFrameLevel, frame.Applications, baseLevel + 23) end
    if frame.ChargeCount then pcall(frame.ChargeCount.SetFrameLevel, frame.ChargeCount, baseLevel + 23) end

    if frame.Cooldown then
        if frame.Cooldown.SetDrawSwipe then frame.Cooldown:SetDrawSwipe(true) end
        frame.Cooldown:SetHideCountdownNumbers(not barData.showCooldownText)
        local countdown = frame.Cooldown.GetCountdownFontString and frame.Cooldown:GetCountdownFontString()
        if countdown then SetCDMFont(countdown, GetCDMFont(), barData.cooldownFontSize or 12) end
    end

    if frame._keybindText then
        SetCDMFont(frame._keybindText, GetCDMFont(), barData.keybindSize or 13)
        frame._keybindText:ClearAllPoints()
        frame._keybindText:SetPoint("TOPLEFT", frame, "TOPLEFT",
            barData.keybindOffsetX or 2, barData.keybindOffsetY or -2)
        frame._keybindText:SetTextColor(barData.keybindR or 1, barData.keybindG or 1,
            barData.keybindB or 1, barData.keybindA or 0.9)
        local key = barData.showKeybind and ns.FindCachedKeybindForIcon(frame)
        if key then frame._keybindText:SetText(key); frame._keybindText:Show()
        else frame._keybindText:Hide() end
    end

    local container = cdmBarFrames[barKey]
    frame:SetAlpha(container and container:IsShown() and (container:GetAlpha() or 1) or 0)
    return frame
end

function ns.FilterAndSortNativeFramesForBar(frames, barData)
    local configured = barData.customSpells or barData.trackedSpells
    local extras = barData.extraSpells
    local removed = barData.removedSpells
    local hasExplicitList = barData.customSpells ~= nil or barData.trackedSpells ~= nil

    -- With no imported/local layout, mirror Blizzard exactly. Once a list
    -- exists it is authoritative, including an intentionally empty list.
    if not hasExplicitList and not (removed and next(removed)) then
        table.sort(frames, SortBlizzChildren)
        return
    end

    local allowed, order = {}, {}
    local nextOrder = 0
    local function AddConfiguredSpell(sid)
        if not IsCleanPositiveNumber(sid) then return end
        nextOrder = nextOrder + 1
        local pending, read = { sid }, 1
        while read <= #pending do
            local current = pending[read]
            read = read + 1
            if IsCleanPositiveNumber(current) and not allowed[current] then
                allowed[current] = true
                if order[current] == nil then order[current] = nextOrder end

                local corrected = ns.ApplyBuffSpellCorrection and ns.ApplyBuffSpellCorrection(current)
                if IsCleanPositiveNumber(corrected) and not allowed[corrected] then
                    pending[#pending + 1] = corrected
                end
                if C_Spell then
                    if C_Spell.GetBaseSpell then
                        local ok, base = pcall(C_Spell.GetBaseSpell, current)
                        if ok and IsCleanPositiveNumber(base) and not allowed[base] then
                            pending[#pending + 1] = base
                        end
                    end
                    if C_Spell.GetOverrideSpell then
                        local ok, override = pcall(C_Spell.GetOverrideSpell, current)
                        if ok and IsCleanPositiveNumber(override) and not allowed[override] then
                            pending[#pending + 1] = override
                        end
                    end
                end
                if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
                    local ok, override = pcall(C_SpellBook.FindSpellOverrideByID, current)
                    if ok and IsCleanPositiveNumber(override) and not allowed[override] then
                        pending[#pending + 1] = override
                    end
                end
            end
        end
    end
    for _, sid in ipairs(configured or {}) do AddConfiguredSpell(sid) end
    for _, sid in ipairs(extras or {}) do AddConfiguredSpell(sid) end

    local function FrameOrder(frame)
        local candidates = {
            frame._cdmResolvedSid, frame._cdmBaseSpellID,
            frame._spellID, frame._baseSpellID,
        }
        local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
        if cdID then candidates[#candidates + 1] = ns._cdIDToCorrectSID[cdID] end
        for i = 1, #candidates do
            local sid = candidates[i]
            if IsCleanPositiveNumber(sid) and allowed[sid] then
                return order[sid] or 99999
            end
        end
        return nil
    end

    local write = 1
    for read = 1, #frames do
        local frame = frames[read]
        local frameOrder = FrameOrder(frame)
        local keep = frameOrder ~= nil
        if not hasExplicitList and removed and next(removed) then
            -- Legacy profile with only a removal blacklist.
            keep = true
            local sid = frame._cdmResolvedSid or frame._cdmBaseSpellID
            if IsCleanPositiveNumber(sid) and removed[sid] then keep = false end
            frameOrder = frameOrder or 99999
        end
        if keep then
            frame._kuiConfiguredOrder = frameOrder
            frames[write] = frame
            write = write + 1
        else
            frame._kuiConfiguredOrder = nil
        end
    end
    for i = #frames, write, -1 do frames[i] = nil end

    table.sort(frames, function(a, b)
        local ao = a._kuiConfiguredOrder or 99999
        local bo = b._kuiConfiguredOrder or 99999
        if ao ~= bo then return ao < bo end
        return SortBlizzChildren(a, b)
    end)
end

function ns.UpdateNativeCDMBarIcons(barKey)
    local barData = barDataByKey[barKey]
    local container = cdmBarFrames[barKey]
    local source = ns._tickBlizzMirror.icons[barKey]
    if not (barData and container and source) then return end

    local icons = cdmBarIcons[barKey]
    local previous = {}
    for i = 1, #icons do previous[i] = icons[i] end

    local claimed = {}
    local ordered = {}
    for i = 1, #source do ordered[i] = source[i] end
    ns.FilterAndSortNativeFramesForBar(ordered, barData)

    local compositionChanged = #previous ~= #ordered
    if not compositionChanged then
        for i = 1, #ordered do
            if previous[i] ~= ordered[i] then
                compositionChanged = true
                break
            end
        end
    end

    wipe(icons)
    for _, nativeFrame in ipairs(ordered) do
        ns.EnsureNativeCDMFrame(nativeFrame, barKey, barData)
        icons[#icons + 1] = nativeFrame
        claimed[nativeFrame] = true
    end

    -- Frames rejected by the explicit spell list may never have appeared in
    -- `previous` (notably on login/reload). Decorate once so the park/alpha
    -- guards exist, then suppress them at their Blizzard source.
    for _, sourceFrame in ipairs(source) do
        if not claimed[sourceFrame] and not sourceFrame._kuiOwnedCDMIcon then
            ns.EnsureNativeCDMFrame(sourceFrame, barKey, barData)
            ns.ReleaseNativeCDMFrame(sourceFrame)
        end
    end

    for _, oldIcon in ipairs(previous) do
        if oldIcon._kuiOwnedCDMIcon then
            ns.SetCDMIconShown(oldIcon, false)
            oldIcon._blizzChild = nil
        elseif ns._nativeCDMFrameData[oldIcon] and not claimed[oldIcon] then
            ns.ReleaseNativeCDMFrame(oldIcon)
        end
    end

    -- Appearance refresh stops/rebuilds glows and shape resources; layout writes
    -- every native frame point. Neither belongs in the steady-state update path.
    if compositionChanged or container._nativeForceRefresh then
        container._nativeForceRefresh = nil
        if ns.RefreshCDMIconAppearance then ns.RefreshCDMIconAppearance(barKey) end
        LayoutCDMBar(barKey)
    else
        ns.SyncNativeCDMBarAlpha(barKey)
    end
    for _, nativeFrame in ipairs(icons) do
        ns.ApplyNativeCDMVisualState(nativeFrame)
        if ns.SyncProcGlowIndexForIcon then ns.SyncProcGlowIndexForIcon(nativeFrame) end
    end
    container._prevVisibleCount = #icons
    return compositionChanged
end

function ns.NativeCDMHostingEnabled()
    local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
    return p and p.cdmBars and p.cdmBars.enabled
end

function ns.NativeCDMViewerChanged(reason, viewerName)
    if not ns.NativeCDMHostingEnabled() then return end
    local barKey
    if viewerName == "EssentialCooldownViewer" then
        barKey = "cooldowns"
    elseif viewerName == "UtilityCooldownViewer" then
        barKey = "utility"
    elseif viewerName == "BuffIconCooldownViewer" or viewerName == "BuffBarCooldownViewer" then
        barKey = "buffs"
    end
    -- Coalesce pool bursts. A single keystroke (or aura batch) can fire
    -- OnCooldownIDSet + Acquire + Release + SetAuraInstanceInfo in the same
    -- frame for every affected icon; taking a full viewer snapshot per event
    -- was the source of the ~400ms hook. Invalidate once and let the single
    -- coalesced tick rebuild the snapshot.
    local uniq = ns._nativeViewerChangedBars or {}
    if barKey then
        uniq[barKey] = true
    end
    ns._nativeViewerChangedBars = uniq
    ns._nativeViewerChangedReason = reason or ns._nativeViewerChangedReason or "native_viewer"
    if ns._nativeViewerChangedPending then return end
    ns._nativeViewerChangedPending = true
    C_Timer.After(0.05, function()
        ns._nativeViewerChangedPending = false
        -- Always consume what accumulated: a burst that keeps arriving during
        -- the window must still invalidate the snapshot when the timer fires,
        -- otherwise nothing ever gets repainted and the CDM layout goes stale
        -- (misplaced/overlapping icons until /reload).
        local pendingReason = ns._nativeViewerChangedReason or reason or "native_viewer"
        local bars = ns._nativeViewerChangedBars
        ns._nativeViewerChangedBars = nil
        ns._nativeViewerChangedReason = nil
        CDMRT.viewerSnapshotReady = false
        CDMRT.viewerSnapshotElapsed = 0
        if bars and next(bars) then
            for key in pairs(bars) do
                CDMRT:MarkBarDirty(key, pendingReason, true)
            end
        elseif barKey then
            CDMRT:MarkBarDirty(barKey, pendingReason, true)
        else
            -- Unknown viewer: conservative full pass so nothing goes stale.
            CDMRT:MarkDirty("native_viewer_unknown", false)
        end
        if ns.RunCDMUpdateIfIdle then ns.RunCDMUpdateIfIdle() end
    end)
end

local function GetHostedBarKeyForViewer(viewerName)
    if viewerName == "EssentialCooldownViewer" then
        return "cooldowns"
    elseif viewerName == "UtilityCooldownViewer" then
        return "utility"
    elseif viewerName == "BuffIconCooldownViewer" or viewerName == "BuffBarCooldownViewer" then
        return "buffs"
    end
end

-- Blizzard can run Viewer:Layout without changing the pool composition. That
-- still rewrites SetPoint/SetSize/alpha on the native item frames KUI hosts.
-- The pool signature is therefore only a composition test; it must never gate
-- re-applying KUI's layout and visual ownership.
function ns.ReassertNativeCDMViewerLayout(viewerName)
    if not ns.NativeCDMHostingEnabled() then return false end
    if InCombatLockdown and InCombatLockdown() then
        ns._cdmLayoutPending = true
        return false
    end

    local barKey = GetHostedBarKeyForViewer(viewerName)
    local container = barKey and cdmBarFrames[barKey]
    local icons = barKey and cdmBarIcons[barKey]
    if not (container and icons) then return false end

    -- Blizzard may have changed child alpha while the container alpha itself
    -- stayed constant. Invalidate the small alpha cache so every claimed child
    -- is restored even though the bar visibility did not transition.
    container._kuiNativeAlpha = nil
    LayoutCDMBar(barKey)
    for _, icon in ipairs(icons) do
        if ns._nativeCDMFrameData[icon] then
            ns.ApplyNativeCDMVisualState(icon)
            if ns.SyncProcGlowIndexForIcon then
                ns.SyncProcGlowIndexForIcon(icon)
            end
        end
    end
    ns.SyncNativeCDMBarAlpha(barKey)
    return true
end

function ns.NativeCDMViewerLayoutObserved(viewerName)
    local viewers = ns._nativeLayoutObservedViewers or {}
    if viewerName then viewers[viewerName] = true end
    ns._nativeLayoutObservedViewers = viewers
    if ns._nativeLayoutProbePending then return end
    ns._nativeLayoutProbePending = true

    -- Blizzard can call Layout periodically even when its active pools did not
    -- change. Treat Layout as a cheap composition probe; rebuilding the complete
    -- viewer snapshot here produced the recurring 50-150ms hitch.
    C_Timer.After(0, function()
        ns._nativeLayoutProbePending = false
        local pendingViewers = ns._nativeLayoutObservedViewers
        ns._nativeLayoutObservedViewers = nil

        -- Reclaim the existing frames first. A late Blizzard layout after
        -- /reload commonly keeps exactly the same IDs, so waiting for a
        -- signature change leaves the native layout visible indefinitely.
        if pendingViewers then
            local reassertedBars = {}
            for pendingViewerName in pairs(pendingViewers) do
                local barKey = GetHostedBarKeyForViewer(pendingViewerName)
                if barKey and not reassertedBars[barKey] then
                    reassertedBars[barKey] = true
                    ns.ReassertNativeCDMViewerLayout(pendingViewerName)
                end
            end
        elseif viewerName then
            ns.ReassertNativeCDMViewerLayout(viewerName)
        end

        local signatureChanged = true
        local getSignature = ns.GetCDMViewerPoolSignature
        if getSignature then
            local ok, signature = pcall(getSignature)
            if ok and CDMRT.viewerPoolSignature ~= nil
                and signature == CDMRT.viewerPoolSignature then
                signatureChanged = false
            end
        end
        if not signatureChanged then return end

        if pendingViewers then
            for pendingViewerName in pairs(pendingViewers) do
                if pendingViewerName == "BuffBarCooldownViewer" then
                    ns.WakeTrackedBuffBars()
                end
                ns.NativeCDMViewerChanged("native_viewer_layout", pendingViewerName)
            end
        else
            ns.NativeCDMViewerChanged("native_viewer_layout")
        end
    end)
end

function ns.WakeTrackedBuffBars()
    -- TBB caches both successful and failed cfg->BuffBar frame lookups. Pool
    -- churn after login/spec/instance transitions must retire a cached miss;
    -- otherwise the bar stays absent until /reload even though Blizzard has
    -- since acquired the correct child. Keep this scoped to BuffBar viewer
    -- edges so Essential/Utility layouts do not create needless TBB rescans.
    if ns.InvalidateTBBFrameCache then
        ns.InvalidateTBBFrameCache()
    end
    if ns.RequestTrackedBuffBarTimerRefresh then
        ns.RequestTrackedBuffBarTimerRefresh()
    end
end

function ns.SetupNativeCDMViewerHooks()
    -- PLAYER_LOGIN can run before Blizzard has created every CooldownViewer.
    -- Keep hook state per object so a later PLAYER_ENTERING_WORLD/data-loaded
    -- pass can attach the missing hooks without duplicating existing ones.
    local hookState = ns._nativeCDMViewerHookState
    if not hookState then
        hookState = { mixins = {}, pools = {}, acquire = {}, layout = {} }
        ns._nativeCDMViewerHookState = hookState
    end

    local function HookCooldownMixin(mixin)
        if mixin and mixin.OnCooldownIDSet and not hookState.mixins[mixin] then
            hookState.mixins[mixin] = true
            hooksecurefunc(mixin, "OnCooldownIDSet", function(itemFrame)
                local cooldownID = itemFrame and itemFrame.cooldownID
                if itemFrame and itemFrame._kuiNativeCooldownID == cooldownID then
                    return
                end
                if itemFrame then
                    itemFrame._kuiNativeCooldownID = cooldownID
                end
                if itemFrame and itemFrame.viewerFrame == _G.BuffBarCooldownViewer then
                    ns.WakeTrackedBuffBars()
                end
                local viewer = itemFrame and itemFrame.viewerFrame
                local viewerName = viewer and viewer.GetName and viewer:GetName()
                ns.NativeCDMViewerChanged("native_cooldown_id", viewerName)
            end)
        end
    end
    HookCooldownMixin(CooldownViewerBuffIconItemMixin)
    HookCooldownMixin(CooldownViewerBuffBarItemMixin)
    HookCooldownMixin(CooldownViewerEssentialItemMixin)
    HookCooldownMixin(CooldownViewerUtilityItemMixin)

    for _, viewerName in ipairs(_cdmViewerNames) do
        local viewer = _G[viewerName]
        if viewer then
            local sourceViewerName = viewerName
            local isTrackedBarViewer = viewerName == "BuffBarCooldownViewer"
            local itemFramePool = viewer.itemFramePool
            if itemFramePool and itemFramePool.Acquire and not hookState.pools[itemFramePool] then
                hookState.pools[itemFramePool] = true
                hooksecurefunc(itemFramePool, "Acquire", function()
                    if isTrackedBarViewer then ns.WakeTrackedBuffBars() end
                    ns.NativeCDMViewerChanged("native_pool_acquire", sourceViewerName)
                end)
            end
            if viewer.OnAcquireItemFrame and not hookState.acquire[viewer] then
                hookState.acquire[viewer] = true
                hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, itemFrame)
                    if ns.NativeCDMHostingEnabled() and itemFrame then itemFrame:SetAlpha(0) end
                    if isTrackedBarViewer then ns.WakeTrackedBuffBars() end
                    ns.NativeCDMViewerChanged("native_item_acquire", sourceViewerName)
                end)
            end
            if viewer.Layout and not hookState.layout[viewer] then
                hookState.layout[viewer] = true
                hooksecurefunc(viewer, "Layout", function()
                    ns.NativeCDMViewerLayoutObserved(sourceViewerName)
                end)
            end
        end
    end
    ns._nativeCDMViewerHooksInstalled = true
end

UpdateCDMBarIcons = function(barKey)
    if ns.BLIZZ_CDM_FRAMES[barKey] then
        return ns.UpdateNativeCDMBarIcons(barKey)
    end
end
-------------------------------------------------------------------------------
--  Keybind cache for CDM icons
--  Reads HotKey text directly from action button frames
-------------------------------------------------------------------------------
ns._barBindingDefs = {
    { prefix = "MULTIACTIONBAR1BUTTON", startSlot = 61 },  -- bar 2 bottom left
    { prefix = "MULTIACTIONBAR2BUTTON", startSlot = 49 },  -- bar 3 bottom right
    { prefix = "MULTIACTIONBAR3BUTTON", startSlot = 25 },  -- bar 4 right
    { prefix = "MULTIACTIONBAR4BUTTON", startSlot = 37 },  -- bar 5 left
    { prefix = "MULTIACTIONBAR5BUTTON", startSlot = 145 }, -- bar 6
    { prefix = "MULTIACTIONBAR6BUTTON", startSlot = 157 }, -- bar 7
    { prefix = "MULTIACTIONBAR7BUTTON", startSlot = 169 }, -- bar 8
    { prefix = "ACTIONBUTTON",          startSlot = 1 },   -- bar 1 (last = lowest priority)
}

ns.BINDING_LABEL_REPLACEMENTS = {
    { "SHIFT%-", "S" },
    { "CTRL%-", "C" },
    { "ALT%-", "A" },
    { "Mouse Button ", "M" },
    { "MOUSEWHEELUP", "MwU" },
    { "MOUSEWHEELDOWN", "MwD" },
    { "NUMPADDECIMAL", "N." },
    { "NUMPADPLUS", "N+" },
    { "NUMPADMINUS", "N-" },
    { "NUMPADMULTIPLY", "N*" },
    { "NUMPADDIVIDE", "N/" },
    { "NUMPAD", "N" },
    { "BUTTON", "M" },
}

local function NormalizeBindingLabel(bindingText)
    if type(bindingText) ~= "string" or bindingText == "" then return nil end
    -- Aplicar abreviaturas secuencialmente (fold sobre la tabla de reglas)
    local result = bindingText
    for _, rule in ipairs(ns.BINDING_LABEL_REPLACEMENTS) do
        result = result:gsub(rule[1], rule[2])
    end
    return (result ~= "") and result or nil
end

ns.NormalizeBindingLabel = NormalizeBindingLabel

local function RebuildKeybindCache()
    if ns.CDM_RebuildKeybindCache_Impl then
        return ns.CDM_RebuildKeybindCache_Impl()
    end
end

function ns.CDM_SetProtectedFrameLayering(frame, strata, level)
    if not frame then return false end
    if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        ns._cdmLayoutPending = true
        return false
    end
    if type(strata) == "string" and strata ~= "" then
        frame:SetFrameStrata(strata)
    end
    if type(level) == "number" then
        frame:SetFrameLevel(level)
    end
    return true
end


function ns.CDM_ResolveBarStrata(barData, profile)
    local strata = barData and barData.barStrata
    if not strata and profile and profile.cdmBars and profile.cdmBars.barDefaults then
        strata = profile.cdmBars.barDefaults.barStrata
    end
    strata = tostring(strata or "LOW"):upper()
    if strata ~= "BACKGROUND" and strata ~= "LOW" and strata ~= "MEDIUM"
        and strata ~= "HIGH" and strata ~= "DIALOG" and strata ~= "TOOLTIP" then
        strata = "LOW"
    end
    return strata
end

function ns.CDM_ApplyBarStrata(frame, barData, profile)
    if not frame then return end
    local strata = ns.CDM_ResolveBarStrata(barData, profile)
    ns.CDM_SetProtectedFrameLayering(frame, strata)
end

-- Apply the current cache to all visible CDM icon keybind texts
local function ApplyCachedKeybinds()
    for barKey, icons in pairs(cdmBarIcons) do
        local bd = barDataByKey[barKey]
        for _, icon in ipairs(icons) do
            if icon._keybindText then
                if bd and bd.showKeybind then
                    local key = ns.FindCachedKeybindForIcon(icon)

                    if key then
                        icon._keybindText:SetText(key)
                        icon._keybindText:Show()
                    else
                        icon._keybindText:Hide()
                    end
                else
                    icon._keybindText:Hide()
                end
            end
        end
    end
end

local function UpdateCDMKeybinds()
    -- Defer rebuild while in combat
    if _inCombat then _keybindRebuildPending = true; return end
    _keybindRebuildPending = false
    RebuildKeybindCache()
    ApplyCachedKeybinds()
    _keybindCacheReady = true
end
ns.UpdateCDMKeybinds = UpdateCDMKeybinds
ns.ApplyCachedKeybinds = ApplyCachedKeybinds
ns.CDMKeybindCache = _cdmKeybindCache

function ns.ScheduleActionBarRefresh()
    if ns._actionBarRefreshPending then
        return
    end

    ns._actionBarRefreshPending = true
    C_Timer.After(0.25, function()
        ns._actionBarRefreshPending = false
        UpdateCDMKeybinds()
        if ns.RefreshBarGlowRuntime then
            ns.RefreshBarGlowRuntime(true)
        end
    end)
end

function ns.CDMDidActionSlotStateChange(slot)
    slot = tonumber(slot)
    if not slot or slot <= 0 then
        return true
    end

    ns._cdmActionSlotEventState = ns._cdmActionSlotEventState or {}
    local currentType, currentID, currentSubType = GetActionInfo(slot)
    local previous = ns._cdmActionSlotEventState[slot]
    if previous
        and previous.actionType == currentType
        and previous.actionID == currentID
        and previous.subType == currentSubType then
        return false
    end

    ns._cdmActionSlotEventState[slot] = {
        actionType = currentType,
        actionID = currentID,
        subType = currentSubType,
    }
    return true
end

-- Button press highlight (flashes CDM icons when their action is used)
function ns.CDM_ResolveIdentifierFromActionSlot(slot)
    if type(slot) ~= "number" then return nil end
    local actionType, id, subType = GetActionInfo(slot)
    if actionType == "spell" then
        return id
    elseif actionType == "item" and id then
        return ns.EncodeItemID(id)
    elseif actionType == "macro" and id then
        if GetMacroSpell then
            local macroSpell = GetMacroSpell(id)
            if type(macroSpell) == "number" then
                return macroSpell
            elseif type(macroSpell) == "string" and macroSpell ~= "" then
                local sid = select(7, (rawget(_G, "GetSpellInfo") and rawget(_G, "GetSpellInfo")(macroSpell)))
                if sid then return sid end
            end
        end
        if GetMacroItem then
            local _, itemID = GetMacroItem(id)
            if itemID then return ns.EncodeItemID(itemID) end
        end
    end
    return nil
end

function ns.CDM_ResolveItemIDFromActionSlot(slot)
    if type(slot) ~= "number" then return nil end
    local actionType, id = GetActionInfo(slot)
    if actionType == "item" and id then
        return NormalizeItemID and ns.NormalizeItemID(id) or id
    end
    if actionType == "macro" and id and GetMacroItem then
        local _, itemID = GetMacroItem(id)
        if itemID then
            return NormalizeItemID and ns.NormalizeItemID(itemID) or itemID
        end
    end
    return nil
end

function ns.CDM_FlashPressOverlay(icon)
    if not icon or not icon._pressOverlay then return end
    icon._pressOverlay:SetAlpha(0.7)
    icon._pressOverlay:Show()
    icon._pressFlashToken = (icon._pressFlashToken or 0) + 1
    local token = icon._pressFlashToken
    C_Timer.After(0.15, function()
        if not icon or icon._pressFlashToken ~= token then return end
        if icon._pressOverlay then
            icon._pressOverlay:Hide()
            icon._pressOverlay:SetAlpha(0)
        end
    end)
end

function ns.CDM_FlashIconsForIdentifier(identifier)
    if not identifier then return end
    local itemID = (type(identifier) == "number") and DecodeItemID(identifier) or nil
    for barKey, icons in pairs(cdmBarIcons) do
        local bd = barDataByKey[barKey]
        if bd and bd.buttonPressHighlight then
            for _, icon in ipairs(icons) do
                if icon:IsShown() then
                    if identifier == icon._spellID or identifier == icon._baseSpellID then
                        ns.CDM_FlashPressOverlay(icon)
                    elseif itemID and icon._itemID == itemID then
                        ns.CDM_FlashPressOverlay(icon)
                    end
                end
            end
        end
    end
end

function ns.CDM_InstallButtonPressHighlightHook()
    if ns._pressHighlightHooked then return end
    ns._pressHighlightHooked = true
    hooksecurefunc("UseAction", function(slot)
        local p = KUI_CDM.db and KUI_CDM.db.profile
        if not p or not p.cdmBars or not p.cdmBars.bars then return end
        local identifier = ns.CDM_ResolveIdentifierFromActionSlot(slot)
        local itemID = ns.CDM_ResolveItemIDFromActionSlot and ns.CDM_ResolveItemIDFromActionSlot(slot)
        if not itemID and type(identifier) == "number" and ns.ResolveSyntheticItemIDFromSpellID then
            itemID = ns.ResolveSyntheticItemIDFromSpellID(identifier)
        end
        if not itemID and identifier then
            itemID = DecodeItemID(identifier)
        end
        if itemID and GetFallbackItemCooldownDuration(itemID) then
            if ns.TriggerImmediateSyntheticItemCooldown then
                ns.TriggerImmediateSyntheticItemCooldown(itemID)
            end
            if ns.RequestPotionTrackerClickRefresh then
                ns.RequestPotionTrackerClickRefresh()
            end
        end
        local any = false
        for _, b in ipairs(p.cdmBars.bars) do
            if b.buttonPressHighlight then
                any = true
                break
            end
        end
        if not any then return end
        if identifier then
            ns.CDM_FlashIconsForIdentifier(identifier)
        end
    end)
end

-- Refresh visual properties of existing icons (called when settings change)
local function RefreshCDMIconAppearance(barKey)
    local icons = cdmBarIcons[barKey]
    if not icons then return end

    local barData = barDataByKey[barKey]
    if not barData then return end

    local barScale = barData.barScale or 1.0
    if barScale < 0.1 then barScale = 1.0 end
    local borderSize = SnapForScale(barData.borderSize or 1, barScale)
    local zoom = barData.iconZoom or 0.08

    for _, icon in ipairs(icons) do
        -- Update texture zoom
        if icon._tex then
            icon._tex:ClearAllPoints()
            icon._tex:SetPoint("TOPLEFT", icon, "TOPLEFT", borderSize, -borderSize)
            icon._tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -borderSize, borderSize)
            icon._tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        end
        -- Update cooldown inset
        if icon._cooldown then
            icon._cooldown:ClearAllPoints()
            icon._cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", borderSize, -borderSize)
            icon._cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -borderSize, borderSize)
            do
                local swipeR, swipeG, swipeB = GetConfiguredSwipeColor(barData, icon)
                icon._cooldown:SetSwipeColor(swipeR, swipeG, swipeB, barData.swipeAlpha or 0.7)
            end
            icon._cooldown:SetHideCountdownNumbers(not barData.showCooldownText)
            -- Mark pending font update
            if barData.showCooldownText then
                icon._pendingFontPath = GetCDMFont(); icon._pendingFontSize = barData.cooldownFontSize or 12
            end
        end
        -- Update border edges
        if icon._edges then
            for _, e in ipairs(icon._edges) do
                e:SetColorTexture(barData.borderR or 0, barData.borderG or 0, barData.borderB or 0, barData.borderA or 1)
                e:SetSnapToPixelGrid(false)
                e:SetTexelSnappingBias(0)
            end
            icon._edges[1]:SetHeight(borderSize)
            icon._edges[2]:SetHeight(borderSize)
            icon._edges[3]:SetWidth(borderSize)
            icon._edges[4]:SetWidth(borderSize)
        end
        -- Update background
        if icon._bg then
            icon._bg:SetColorTexture(barData.bgR or 0.08, barData.bgG or 0.08, barData.bgB or 0.08, barData.bgA or 0.6)
            icon._bg:SetSnapToPixelGrid(false)
            icon._bg:SetTexelSnappingBias(0)
        end
        -- Update charge text font/position
        if icon._chargeText then
            SetCDMFont(icon._chargeText, GetCDMFont(), barData.stackCountSize or 12)
            icon._chargeText:SetShadowOffset(0, 0)
            icon._chargeText:ClearAllPoints()
            icon._chargeText:SetPoint("BOTTOMRIGHT", icon._textOverlay, "BOTTOMRIGHT", barData.stackCountX or 0,
                (barData.stackCountY or 0) + 2)
            icon._chargeText:SetTextColor(barData.stackCountR or 1, barData.stackCountG or 1, barData.stackCountB or 1)
        end
        -- Update keybind text style
        if icon._keybindText then
            SetCDMFont(icon._keybindText, GetCDMFont(), barData.keybindSize or 13)
            icon._keybindText:SetShadowOffset(0, 0)
            icon._keybindText:ClearAllPoints()
            icon._keybindText:SetPoint("TOPLEFT", icon._textOverlay, "TOPLEFT", barData.keybindOffsetX or 2,
                barData.keybindOffsetY or -2)
            icon._keybindText:SetTextColor(barData.keybindR or 1, barData.keybindG or 1, barData.keybindB or 1,
                barData.keybindA or 0.9)

            -- Apply keybind text for default bars.
            if barData.showKeybind then
                local key = ns.FindCachedKeybindForIcon(icon)
                if key then
                    icon._keybindText:SetText(key)
                    icon._keybindText:Show()
                else
                    icon._keybindText:Hide()
                end
            else
                icon._keybindText:Hide()
            end
        end

        -- Toggle mouse handling based on current icon state
        if ns._nativeCDMFrameData[icon] then
            -- Preserve Blizzard's own native tooltip scripts when KUI tooltips
            -- are enabled; native frames do not use the clone-only overlay.
            ns.CDMApplyMouseStateSafely(icon, barData.showTooltip == true, barData.showTooltip == true)
        else
            ns.CDMApplyMouseStateSafely(icon, false, false)
        end
        if icon._tooltipOverlay then
            if icon._tooltipOverlay._UpdateMouseForTooltip then
                icon._tooltipOverlay:_UpdateMouseForTooltip()
            elseif icon._UpdateMouseForTooltip then
                icon._UpdateMouseForTooltip(icon._tooltipOverlay)
            else
                ns.CDMApplyMouseStateSafely(icon._tooltipOverlay, barData.showTooltip and true or false,
                    barData.showTooltip and true or false)
            end
        elseif icon._UpdateMouseForTooltip then
            icon._UpdateMouseForTooltip(icon)
        end
        -- Apply custom shape
        local shape = barData.iconShape or "none"
        ApplyShapeToCDMIcon(icon, shape, barData)

        -- Reset active state so glow type change takes effect on next tick
        if icon._glowOverlay and not ns._nativeCDMFrameData[icon] then
            StopNativeGlow(icon._glowOverlay)
        end
        if not ns._nativeCDMFrameData[icon] then
            icon._isActive = false
            icon._procGlowActive = false
        end
    end
end
ns.RefreshCDMIconAppearance = RefreshCDMIconAppearance

function ns.CDM_IsPlayerCasting()
    if UnitCastingInfo and UnitCastingInfo("player") then return true end
    if UnitChannelInfo and UnitChannelInfo("player") then return true end
    return false
end

function ns.CDM_IsPlayerInVehicle()
    if UnitInVehicle and UnitInVehicle("player") then return true end
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    return false
end

function ns.CDM_IsSkyRiding()
    if C_PlayerInfo and C_PlayerInfo.IsPlayerInDragonriding then
        local ok, res = pcall(C_PlayerInfo.IsPlayerInDragonriding)
        if ok then return res end
    end
    if C_MountJournal and C_MountJournal.IsDragonriding then
        local ok, res = pcall(C_MountJournal.IsDragonriding)
        if ok then return res end
    end
    return false
end

local function BuildCDMVisibilityContext(inCombat)
    return {
        inCombat = inCombat,
        inInstance = IsInInstance and select(1, IsInInstance()) or false,
        inVehicle = ns.CDM_IsPlayerInVehicle(),
        inGroup = IsInGroup and IsInGroup() or false,
        inRaid = IsInRaid and IsInRaid() or false,
        hasTarget = UnitExists and UnitExists("target") or false,
        isCasting = ns.CDM_IsPlayerCasting(),
        isFlying = IsFlying and IsFlying() or false,
        isSwimming = IsSwimming and IsSwimming() or false,
        isMounted = IsMounted and IsMounted() or false,
        isResting = IsResting and IsResting() or false,
        isStealthed = IsStealthed and IsStealthed() or false,
        isDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false,
        isPvP = (UnitIsPVP and UnitIsPVP("player")) or (UnitIsPVPFreeForAll and UnitIsPVPFreeForAll("player")) or false,
        isBoss = (rawget(_G, "IsEncounterInProgress") and rawget(_G, "IsEncounterInProgress")()) or
            (UnitExists and UnitExists("boss1")) or false,
        inPetBattle = (C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()) or false,
        isSkyRiding = ns.CDM_IsSkyRiding(),
    }
end

function ns.CDM_ShouldHideWhen(bd, inCombat, context)
    local hw = bd and bd.hideWhen
    if not hw then return false end
    context = context or BuildCDMVisibilityContext(inCombat)
    local mode = tostring(bd.hideWhenMode or "ANY"):upper()
    local anySelected = false
    local anyMatch = false
    local allMatch = true

    local function Eval(flag, cond)
        if not flag then return end
        anySelected = true
        if cond then
            anyMatch = true
        else
            allMatch = false
        end
    end

    Eval(hw.always, true)
    Eval(hw.casting, context.isCasting)
    Eval(hw.notCasting, not context.isCasting)
    Eval(hw.inCombat, context.inCombat)
    Eval(hw.outOfCombat, not context.inCombat)
    Eval(hw.inInstance, context.inInstance)
    Eval(hw.inVehicle, context.inVehicle)
    Eval(hw.resting, context.isResting)
    Eval(hw.swimming, context.isSwimming)
    Eval(hw.flying, context.isFlying)
    Eval(hw.skyriding, context.isSkyRiding)
    Eval(hw.boss, context.isBoss)
    Eval(hw.petBattle, context.inPetBattle)
    Eval(hw.mounted, context.isMounted)
    Eval(hw.solo, not context.inGroup)
    Eval(hw.inGroup, context.inGroup)
    Eval(hw.inRaid, context.inRaid)
    Eval(hw.dead, context.isDead)
    Eval(hw.hasTarget, context.hasTarget)
    Eval(hw.noTarget, not context.hasTarget)
    Eval(hw.pvp, context.isPvP)
    Eval(hw.stealthed, context.isStealthed)

    if not anySelected then return false end
    if mode == "ALL" then
        return allMatch
    end
    return anyMatch
end

function ns.CDMApplyVisibility()
    local cdm = _G.KUI_CDM
    local p = cdm and cdm.db and cdm.db.profile
    if not p or not p.cdmBars or not p.cdmBars.enabled then return end

    local inCombat = _G.KUI_CDM_inCombat
    if inCombat == nil then inCombat = UnitAffectingCombat("player") end

    local frames = _G.KUI_CDM_BAR_FRAMES
    local dataByKey = _G.KUI_CDM_BAR_DATA
    if not frames or not dataByKey then
        local n = _G.KUI_CDM_NS
        frames = frames or (n and n.cdmBarFrames)
        dataByKey = dataByKey or (n and n.barDataByKey)
    end
    if not frames or not dataByKey then return end

    -- Visibility predicates share the same player state for the whole pass.
    -- Evaluate this context once; doing it per bar multiplies API
    -- calls exactly on the combat transition where they are most expensive.
    local visibilityContext = BuildCDMVisibilityContext(inCombat)

    for barKey, frame in pairs(frames) do
        local bd = dataByKey[barKey]
        if bd then
            local changed = false
            if bd.enabled == false then
                if frame:IsShown() then frame:Hide(); changed = true end
                if frame:GetAlpha() ~= 0 then frame:SetAlpha(0); changed = true end
            else
                local hideWhen = _G.KUI_CDM_NS and _G.KUI_CDM_NS.CDM_ShouldHideWhen
                    and _G.KUI_CDM_NS.CDM_ShouldHideWhen(bd, inCombat, visibilityContext) or false
                local kt = rawget(_G, "KT")
                if kt and kt._unlockActive then
                    hideWhen = false
                end

                if hideWhen then
                    if frame:IsShown() then frame:Hide(); changed = true end
                    if frame:GetAlpha() ~= 0 then frame:SetAlpha(0); changed = true end
                else
                    if not frame:IsShown() then
                        frame:Show(); changed = true
                    end

                    local alpha = bd.alpha or 1
                    if bd.showOnlyInCombat then
                        alpha = inCombat and alpha or 0
                    elseif bd.oocAlpha and not inCombat then
                        alpha = bd.oocAlpha
                    elseif bd.combatAlpha and inCombat then
                        alpha = bd.combatAlpha
                    end

                    -- Keep the bar fully visible during unlock/move mode regardless of combat
                    if kt and kt._unlockActive then
                        alpha = 1
                    end

                    if frame:GetAlpha() ~= alpha then
                        frame:SetAlpha(alpha)
                        changed = true
                    end
                end
            end
            -- Native children are synchronized only after an actual parent
            -- visibility/alpha transition. Repeating SetAlpha over every icon
            -- was one of the largest costs on PLAYER_REGEN_DISABLED.
            if changed then
                ns.SyncNativeCDMBarAlpha(barKey)
            end
        end
    end
end

BuildAllCDMBars = function()
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("cdm.rebuild.all")
    if ns.SyncKUITrackerBars then
        ns.SyncKUITrackerBars()
    end
    -- Last-resort spec guard
    if not _specValidated then
        ValidateSpec()
    end

    local p = KUI_CDM.db.profile
    if not p.cdmBars.enabled then
        RestoreBlizzardCDM()
        for key, frame in pairs(cdmBarFrames) do
            frame:Hide()
        end
        if profileStarted then profiler:End("cdm.rebuild.all", profileStarted) end
        return
    end

    -- Native hosting always needs the primary viewer shells alive and the
    -- duplicate BuffBar viewer parked. The old hideBlizzard toggle controlled
    -- clone-era behaviour and cannot safely gate this ownership setup.
    HideBlizzardCDM()

    -- PASO 1: crear/registrar todos los frames primero
    wipe(barDataByKey)
    for i, barData in ipairs(p.cdmBars.bars) do
        barDataByKey[barData.key] = barData
        -- Create frame if needed before applying layout
        local key = barData.key
        if not cdmBarFrames[key] then
            local frame = CreateFrame("Frame", "KUI_CDMBar_" .. key, UIParent)
            ns.CDM_SetProtectedFrameLayering(frame, ns.CDM_ResolveBarStrata(barData, p), 5)
            if frame.EnableMouseClicks then frame:EnableMouseClicks(false) end
            if frame.EnableMouseMotion then frame:EnableMouseMotion(true) end
            frame._barKey = key
            frame._barIndex = i
            frame._clip = CreateFrame("ScrollFrame", nil, frame)
            frame._clip:SetAllPoints(frame)
            frame._clip:SetClipsChildren(true)
            frame._content = CreateFrame("Frame", nil, frame._clip)
            frame._content:SetSize(1, 1)
            frame._clip:SetScrollChild(frame._content)
            cdmBarFrames[key] = frame
            cdmBarIcons[key] = {}
        end
    end

    -- PASO 2: Build default layout, shapes, and inner icon grids
    for i, barData in ipairs(p.cdmBars.bars) do
        RefreshCDMIconAppearance(barData.key)
        local frame = cdmBarFrames[barData.key]
        if frame then frame._prevVisibleCount = nil end
        LayoutCDMBar(barData.key)
    end

    -- PASO 3: apply positions and relative anchors now that grids have a size
    for i, barData in ipairs(p.cdmBars.bars) do
        BuildCDMBar(i)
    end

    -- Building containers is not enough for native CDM bars: their icon lists
    -- are populated by UpdateAllCDMBars from the Blizzard viewer snapshot.
    -- On /reload the generic login dirty pass can run before these containers
    -- exist and be consumed, leaving cooldowns/utility/buffs empty while the
    -- independently-rendered KUI Tracker bars still appear. Mark every rebuilt
    -- bar explicitly so the first post-build pass both snapshots and claims the
    -- native children.
    for _, barData in ipairs(p.cdmBars.bars) do
        if barData.enabled then
            local isNativeBar = ns.BLIZZ_CDM_FRAMES[barData.key] ~= nil
            CDMRT:MarkBarDirty(barData.key, "cdm_rebuild", isNativeBar)
        end
    end
    ns.CDMApplyVisibility()
    if _keybindCacheReady then
        ApplyCachedKeybinds()
    else
        UpdateCDMKeybinds()
    end

    -- Batch-apply pending cooldown font styling
    C_Timer.After(0, function()
        local profiler = _G.KT and _G.KT.CombatProfiler
        local profileStarted = profiler and profiler:Begin("cdm.rebuild.font_batch")
        for _, icons in pairs(cdmBarIcons) do
            for _, icon in ipairs(icons) do
                if icon._pendingFontPath and icon._cooldown then
                    local fontPath, fontSize = icon._pendingFontPath, icon._pendingFontSize
                    for ri = 1, icon._cooldown:GetNumRegions() do
                        local region = select(ri, icon._cooldown:GetRegions())
                        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                            SetBlizzCDMFont(region, fontPath, fontSize)
                            break
                        end
                    end
                    icon._pendingFontPath = nil; icon._pendingFontSize = nil
                end
            end
        end
        if profileStarted then profiler:End("cdm.rebuild.font_batch", profileStarted) end
    end)

    -- Retry anchoring the player frame next to cooldown bar
    if ns.RequestAnchorPlayerFrameToCDM then
        ns.RequestAnchorPlayerFrameToCDM()
    else
        C_Timer.After(0.2, function() ns.AnchorPlayerFrameToCDM() end)
        C_Timer.After(1.0, function() ns.AnchorPlayerFrameToCDM() end)
        C_Timer.After(2.5, function() ns.AnchorPlayerFrameToCDM() end)
    end
    if ns.RunCDMUpdateIfIdle then
        ns.RunCDMUpdateIfIdle()
    end
    if profileStarted then profiler:End("cdm.rebuild.all", profileStarted) end
end

ns.BuildAllCDMBars = BuildAllCDMBars
ns.cdmBarFrames = cdmBarFrames
_G.KUI_CDM_BAR_FRAMES = cdmBarFrames
ns.cdmBarIcons = cdmBarIcons
ns.barDataByKey = barDataByKey
_G.KUI_CDM_BAR_DATA = barDataByKey
ns.SaveCDMBarPosition = SaveCDMBarPosition
ns.LayoutCDMBar = LayoutCDMBar
ns.UpdateCDMBarIcons = UpdateCDMBarIcons
ns.FindPlayerPartyFrame = FindPlayerPartyFrame
ns.FindPlayerUnitFrame = FindPlayerUnitFrame
-------------------------------------------------------------------------------
--  Blizzard CDM Mirroring (Snapshot/Update)
-------------------------------------------------------------------------------

local blizzImport = { queuedSpecSave = false }

function blizzImport.BuildSnapshot(barKey)
    local frameName = ns.BLIZZ_CDM_FRAMES[barKey]
    if not frameName then return nil end
    local vf = _G[frameName]
    if not vf then return nil end

    local snapshot = {}
    local seen = {}

    local function CollectViewer(viewer)
        if not viewer then
            return
        end
        local _children = { viewer:GetChildren() }
        for ci, ch in ipairs(_children) do
            if ch and ch.Icon then
                local sid = ns.ResolveChildSpellID(ch)
                if type(sid) == "number" and sid > 0 and not seen[sid] then
                    seen[sid] = true
                    snapshot[#snapshot + 1] = sid
                    local cdID = ch.cooldownID or (ch.cooldownInfo and ch.cooldownInfo.cooldownID)
                    if cdID then
                        ns._cdIDToCorrectSID[cdID] = sid
                    end
                end
            end
        end
    end

    CollectViewer(vf)

    local secondaryName = ns.BLIZZ_CDM_FRAMES_SECONDARY[barKey]
    if secondaryName then
        CollectViewer(_G[secondaryName])
    end

    return (#snapshot > 0) and snapshot or nil
end

-- Capture the current spellIDs displayed on a Blizzard CDM viewer frame.
-- Returns true if spells were successfully found and tracked.
SnapshotBlizzardCDM = function(barKey, barData)
    local snapshot = blizzImport.BuildSnapshot(barKey)
    if not snapshot then
        local cats = ns.CDM_BAR_CATEGORIES[barKey]
        if cats and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet
            and C_CooldownViewer.GetCooldownViewerCooldownInfo then
            snapshot = {}
            local seen = {}
            for _, cat in ipairs(cats) do
                local knownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, false) or {}
                for _, cdID in ipairs(knownIDs) do
                    if not seen[cdID] then
                        seen[cdID] = true
                        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                        local spellID = ns.ResolveInfoSpellID(info)
                        if spellID and spellID > 0 then
                            snapshot[#snapshot + 1] = spellID
                        end
                    end
                end
            end
            if #snapshot == 0 then
                snapshot = nil
            end
        end
    end
    if snapshot then
        barData.trackedSpells = snapshot
        return true
    end
    return false
end

function blizzImport.QueueSpecProfileSave()
    if blizzImport.queuedSpecSave then return end
    blizzImport.queuedSpecSave = true
    C_Timer.After(0.5, function()
        blizzImport.queuedSpecSave = false
        local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
        if p and p.activeSpecKey and p.activeSpecKey ~= "0" then
            SaveCurrentSpecProfile()
        end
    end)
end

function blizzImport.HasTableEntries(tbl)
    return type(tbl) == "table" and next(tbl) ~= nil
end

function blizzImport.HasLocalMainBarLayout(barData)
    if not (barData and MAIN_BAR_KEYS[barData.key]) then
        return false
    end
    if type(barData.trackedSpells) == "table" and #barData.trackedSpells > 0 then
        return true
    end
    if blizzImport.HasTableEntries(barData.extraSpells) then
        return true
    end
    if blizzImport.HasTableEntries(barData.removedSpells) then
        return true
    end
    if blizzImport.HasTableEntries(barData.dormantSpells) then
        return true
    end
    return false
end
ns.HasLocalMainBarLayout = blizzImport.HasLocalMainBarLayout

function blizzImport.ImportDisplayedMainBars(forceOverwrite, silent)
    local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
    if not (p and p.cdmBars and p.cdmBars.bars) then
        return 0
    end

    local imported = 0

    for _, barData in ipairs(p.cdmBars.bars) do
        if MAIN_BAR_KEYS[barData.key] and ns.BLIZZ_CDM_FRAMES[barData.key] then
            local shouldImport = forceOverwrite or not blizzImport.HasLocalMainBarLayout(barData)
            if shouldImport then
                local previousTracked = CloneTableTree(barData.trackedSpells)
                local previousExtra = CloneTableTree(barData.extraSpells)
                local previousRemoved = CloneTableTree(barData.removedSpells)
                local previousDormant = CloneTableTree(barData.dormantSpells)

                if forceOverwrite then
                    barData.extraSpells = nil
                    barData.removedSpells = nil
                    barData.dormantSpells = nil
                end
                barData.trackedSpells = nil

                if SnapshotBlizzardCDM(barData.key, barData) then
                    imported = imported + 1
                else
                    barData.trackedSpells = previousTracked
                    barData.extraSpells = previousExtra
                    barData.removedSpells = previousRemoved
                    barData.dormantSpells = previousDormant
                end
            end
        end
    end

    if imported > 0 then
        BuildAllCDMBars()
        if ns.BuildTrackedBuffBars then ns.BuildTrackedBuffBars() end
        blizzImport.QueueSpecProfileSave()
        if not silent then
            print("KUI: Imported Blizzard CDM layout for " .. imported .. " default bar(s).")
        end
    elseif forceOverwrite and not silent then
        print("KUI: Couldn't read the Blizzard CDM layout yet. Open the Blizzard CDM once and try again.")
    end

    return imported
end
ns.ImportBlizzardDisplayedMainBars = blizzImport.ImportDisplayedMainBars

function blizzImport.GetDisplayedLayoutSignature()
    local signatures = {}
    for _, barKey in ipairs({ "cooldowns", "utility", "buffs" }) do
        local snapshot = blizzImport.BuildSnapshot(barKey)
        if snapshot then
            signatures[#signatures + 1] = barKey .. ":" .. table.concat(snapshot, ",")
        end
    end
    return table.concat(signatures, "|")
end
ns.GetBlizzardDisplayedLayoutSignature = blizzImport.GetDisplayedLayoutSignature

function blizzImport.TryShowInitialPrompt()
    local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
    if not (p and p.cdmBars and p.cdmBars.promptBlizzardLayoutChanges ~= false) then
        return false
    end
    if p._initialBlizzardLayoutPromptPending ~= true then
        return false
    end

    local current = blizzImport.GetDisplayedLayoutSignature()
    if not current or current == "" then
        return false
    end
    if StaticPopup_Visible and StaticPopup_Visible("KUI_CDM_IMPORT_BLIZZARD_LAYOUT") then
        return false
    end

    p._initialBlizzardLayoutPromptPending = false
    p._initialBlizzardLayoutPromptShown = true
    StaticPopup_Show("KUI_CDM_IMPORT_BLIZZARD_LAYOUT")
    return true
end

StaticPopupDialogs["KUI_CDM_IMPORT_BLIZZARD_LAYOUT"] = {
    text = "Blizzard CDM layout changed.\n\nImport Cooldowns, Utility and Buffs into KUI CDM for this spec?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        blizzImport.ImportDisplayedMainBars(true, false)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function blizzImport.HookPrompt()
    local settings = rawget(_G, "CooldownViewerSettings")
    if not settings or settings._kuiBlizzImportPromptHooked then
        return false
    end

    settings._kuiBlizzImportPromptHooked = true
    settings:HookScript("OnShow", function()
        KUI_CDM._blizzLayoutPromptBaseline = blizzImport.GetDisplayedLayoutSignature()
    end)
    settings:HookScript("OnHide", function()
        local baseline = KUI_CDM._blizzLayoutPromptBaseline
        KUI_CDM._blizzLayoutPromptBaseline = nil
        C_Timer.After(0.15, function()
            local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
            if not (p and p.cdmBars and p.cdmBars.promptBlizzardLayoutChanges ~= false) then
                return
            end
            if blizzImport.TryShowInitialPrompt() then
                return
            end
            local current = blizzImport.GetDisplayedLayoutSignature()
            if baseline and baseline ~= "" and current and current ~= "" and current ~= baseline then
                StaticPopup_Show("KUI_CDM_IMPORT_BLIZZARD_LAYOUT")
            end
        end)
    end)
    return true
end

-- Mirror Blizzard CDM icons for a default bar using local trackedSpells.
-- This ensures the player's custom order and hidden spells are respected.
-------------------------------------------------------------------------------
--  Player Unit Frame Anchor: ancla el unit frame del jugador al lado del CDM
--  Funciona con Blizzard, KullThranUI y marcos externos compatibles.
-- Only runs out of combat using pcall to avoid taint
-------------------------------------------------------------------------------
local function HasExplicitKUIUnitFramePosition(key)
    local profile = KT and KT.db and KT.db.profile
    local ufPos = profile and profile.unitFrames and profile.unitFrames.positions and profile.unitFrames.positions[key]
    if type(ufPos) == "table" and ufPos.point then
        -- NOTE: unitFrames.positions always has defaults; treat it as "explicit" only
        -- when the user has actually moved the frame (handled via KT EditMode key).
    end

    -- KUIUnitFrames registers its movers under "unitframes_<unit>"
    local unlockKey = "unitframes_" .. tostring(key or "")
    local editPos = profile and profile.editMode and profile.editMode.frames and profile.editMode.frames[unlockKey]
    if type(editPos) == "table" and editPos.point then
        return true
    end

    return false
end

local function ShouldSkipManagedFrameAutoAnchor(frame, unitKey)
    if not frame or not frame.GetName then
        return false
    end

    local name = frame:GetName()
    if unitKey == "player" and (name == "KullThranUI_UF_Player" or name == "KT_PlayerFrame") then
        return HasExplicitKUIUnitFramePosition("player")
    end
    if unitKey == "target" and (name == "KullThranUI_UF_Target" or name == "KT_TargetFrame") then
        return HasExplicitKUIUnitFramePosition("target")
    end

    return false
end

ns.AnchorPlayerFrameToCDM = function()
    -- No mover nada en combate
    -- AnchorPlayerFrameToCDM: busca frames externos compatibles
    -- y los ancla a izquierda (player) y derecha (target) de la barra Cooldowns.
    if ns._suppressAutoPlayerFrameAnchor then
        ns._playerFrameAnchorPending = false
        return false
    end
    if InCombatLockdown() then
        ns._playerFrameAnchorPending = true
        return false
    end

    local cdmBar = cdmBarFrames and cdmBarFrames["cooldowns"]
    -- Don't require :IsShown(); we still want a stable default anchor even when
    -- the bar is temporarily hidden (e.g. 0 visible icons).
    if not cdmBar or not cdmBar.GetPoint or not cdmBar:GetPoint(1) then
        ns._playerFrameAnchorPending = true
        return false
    end

    -- Patrones de nombres para frame del unit player y target en layouts compatibles
    local playerCandidates = {
        "KullThranUI_UF_Player", "KT_PlayerFrame",
        "UUF_Player", "UnhaltedUnitFrame_Player", "UnhaltedPlayerFrame", "UnhaltedPlayer",
        "oUF_Player", "SUFUnitplayer", "ElvUF_Player",
    }
    local targetCandidates = {
        "KullThranUI_UF_Target", "KT_TargetFrame",
        "UUF_Target", "UnhaltedUnitFrame_Target", "UnhaltedTargetFrame", "UnhaltedTarget",
        "oUF_Target", "SUFUnittarget", "ElvUF_Target",
    }

    local p = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
    local function EnsureMovedFramesTable()
        if not p or not p.cdmBars then return end
        p.cdmBars.userMovedFrames = p.cdmBars.userMovedFrames or {}
    end

    local function HasUserMovedFrame(frame)
        if not frame or not frame.GetName then return false end
        local name = frame:GetName()
        if not name or name == "" then return false end
        return p and p.cdmBars and p.cdmBars.userMovedFrames and p.cdmBars.userMovedFrames[name] or false
    end

    local function HookDetectUserMoved(frame)
        if not frame or frame.KT_CDM_MoveDetectHooked then return end
        if not frame.GetName then return end
        local name = frame:GetName()
        if not name or name == "" then return end

        frame.KT_CDM_MoveDetectHooked = true
        hooksecurefunc(frame, "SetPoint", function(self)
            if self.KT_CDM_Anchoring then return end
            EnsureMovedFramesTable()
            if p and p.cdmBars and p.cdmBars.userMovedFrames then
                p.cdmBars.userMovedFrames[name] = true
            end
        end)
    end

    local function PersistKUIUnitFramePosition(frame, unitKey)
        if not (frame and unitKey and KT and KT.db and KT.db.profile) then
            return
        end

        local name = frame.GetName and frame:GetName()
        if unitKey == "player" then
            if name ~= "KullThranUI_UF_Player" and name ~= "KT_PlayerFrame" then
                return
            end
        elseif unitKey == "target" then
            if name ~= "KullThranUI_UF_Target" and name ~= "KT_TargetFrame" then
                return
            end
        else
            return
        end

        local fx, fy = frame:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if type(fx) ~= "number" or type(fy) ~= "number" or type(ux) ~= "number" or type(uy) ~= "number" then
            return
        end

        KT.db.profile.unitFrames = KT.db.profile.unitFrames or {}
        KT.db.profile.unitFrames.positions = KT.db.profile.unitFrames.positions or {}
        KT.db.profile.unitFrames.positions[unitKey] = KT.db.profile.unitFrames.positions[unitKey] or {}

        local pos = KT.db.profile.unitFrames.positions[unitKey]
        pos.point = "CENTER"
        pos.x = math.floor((fx - ux) + 0.5)
        pos.y = math.floor((fy - uy) + 0.5)
    end

    local function TryAnchorFrame(frameRef, unitKey, point, relFrame, relPoint, ox, oy)
        local f = frameRef
        if type(frameRef) == "string" then
            f = _G[frameRef]
        end
        if not f then return false end
        if ShouldSkipManagedFrameAutoAnchor(f, unitKey) then return false end
        if HasUserMovedFrame(f) then return false end
        local ok = pcall(function()
            if f.SetUserPlaced and not InCombatLockdown() then
                pcall(f.SetUserPlaced, f, true)
            end
            f.KT_CDM_Anchoring = true
            f:ClearAllPoints()
            f:SetPoint(point, relFrame, relPoint, ox, oy)
            f.KT_CDM_Anchoring = nil
            PersistKUIUnitFramePosition(f, unitKey)
        end)
        return ok
    end

    local offsetX = (p and p.cdmBars and p.cdmBars.unitFrameCDMOffsetX) or 15
    local anchorFrame = ns._unitFrameCDMAnchorFrame
    if not anchorFrame then
        anchorFrame = CreateFrame("Frame", nil, UIParent)
        ns._unitFrameCDMAnchorFrame = anchorFrame
    end
    local barWidth = cdmBar:GetWidth() or 1
    local barScale = cdmBar.GetEffectiveScale and cdmBar:GetEffectiveScale() or 1
    local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if uiScale > 0 then
        barWidth = barWidth * barScale / uiScale
    end
    local minWidth = (p and p.cdmBars and p.cdmBars.unitFrameCDMMinWidth) or 180
    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint("CENTER", cdmBar, "CENTER", 0, 0)
    anchorFrame:SetSize(math.max(minWidth, barWidth), 1)

    local anchoredPlayer = false
    local resolvedPlayer = FindPlayerUnitFrame()
    if resolvedPlayer and TryAnchorFrame(resolvedPlayer, "player", "RIGHT", anchorFrame, "LEFT", -offsetX, 0) then
        anchoredPlayer = true
    end
    if not anchoredPlayer then
        for _, name in ipairs(playerCandidates) do
            if TryAnchorFrame(name, "player", "RIGHT", anchorFrame, "LEFT", -offsetX, 0) then
                anchoredPlayer = true
                break
            end
        end
    end
    if not anchoredPlayer then
        local blizzPlayer = ns.CDMGetBlizzardPlayerFrameCandidate and ns.CDMGetBlizzardPlayerFrameCandidate() or _G["PlayerFrame"]
        if blizzPlayer then
            HookDetectUserMoved(blizzPlayer)
            TryAnchorFrame(blizzPlayer, "player", "RIGHT", anchorFrame, "LEFT", -offsetX, 0)
        end
    end

    local anchoredTarget = false
    for _, name in ipairs(targetCandidates) do
        if TryAnchorFrame(name, "target", "LEFT", anchorFrame, "RIGHT", offsetX, 0) then
            anchoredTarget = true
            break
        end
    end
    if not anchoredTarget then
        local blizzTarget = _G["TargetFrame"] or _G["TargetFrameContainer"] or _G["TargetFrameContent"]
        if blizzTarget then
            HookDetectUserMoved(blizzTarget)
            TryAnchorFrame(blizzTarget, "target", "LEFT", anchorFrame, "RIGHT", offsetX, 0)
        end
    end

    ns._playerFrameAnchorPending = not (anchoredPlayer or anchoredTarget)
    return anchoredPlayer or anchoredTarget
end

function ns.RequestAnchorPlayerFrameToCDM()
    if ns._suppressAutoPlayerFrameAnchor then
        ns._playerFrameAnchorPending = false
        return
    end
    ns._playerFrameAnchorPending = true

    local function TryAnchorLater()
        if ns._suppressAutoPlayerFrameAnchor then
            ns._playerFrameAnchorPending = false
            return
        end
        if InCombatLockdown() then
            ns._playerFrameAnchorPending = true
            return
        end
        ns._playerFrameAnchorPending = false
        if ns.AnchorPlayerFrameToCDM then
            ns.AnchorPlayerFrameToCDM()
        end
    end

    C_Timer.After(0.2, TryAnchorLater)
    C_Timer.After(1.0, TryAnchorLater)
    C_Timer.After(2.5, TryAnchorLater)
end



-------------------------------------------------------------------------------
--  Interactive Preview Helpers (used by options spell picker)
-------------------------------------------------------------------------------
local function GetExtraSpells()
    local extras = {}

    -- Trinket slots
    for _, slot in ipairs({ ns.TRINKET_SLOT_1, ns.TRINKET_SLOT_2 }) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local tex = C_Item.GetItemIconByID(itemID)
            if tex then
                local label = (slot == ns.TRINKET_SLOT_1) and "Trinket Slot 1" or "Trinket Slot 2"
                extras[#extras + 1] = {
                    spellID = -slot,
                    cdID = nil,
                    name = label,
                    icon = tex,
                    isKnown = true,
                    isDisplayed = false,
                    isExtra = true,
                }
            end
        end
    end

    -- Racial abilities
    if playerIdentity.race and ns.RACE_RACIALS[playerIdentity.race] then
        for _, entry in ipairs(ns.RACE_RACIALS[playerIdentity.race]) do
            local sid = type(entry) == "table" and entry[1] or entry
            local reqClass = type(entry) == "table" and entry.class or nil
            if (not reqClass or reqClass == playerIdentity.class) and IsSpellKnownSafe(sid) then
                    local sName = C_Spell.GetSpellName(sid)
                    local sTex  = C_Spell.GetSpellTexture(sid)
                    if sName then
                        extras[#extras + 1] = {
                            spellID = sid,
                            cdID = nil,
                            name = sName,
                            icon = sTex,
                            isKnown = true,
                            isDisplayed = false,
                            isExtra = true,
                        }
                    end
                end
            end
        end
    -- Health potions
    for _, item in ipairs(HEALTH_ITEMS) do
        if not item.class or item.class == playerIdentity.class then
            local sName = (item.spellID and C_Spell.GetSpellName(item.spellID)) or item.name or (GetItemInfo and GetItemInfo(item.itemID))
            local sTex  = C_Item.GetItemIconByID(item.itemID)
            if sName then
                extras[#extras + 1] = {
                    spellID = item.spellID or ns.EncodeItemID(item.itemID),
                    cdID = nil,
                    name = sName,
                    icon = sTex or (item.spellID and C_Spell.GetSpellTexture(item.spellID)),
                    isKnown = true,
                    isDisplayed = false,
                    isExtra = true,
                }
            end
        end
    end

    return extras
end
ns.GetExtraSpells = GetExtraSpells

function ns.GetCDMSpellsForBar(barKey)
    local barType
    local p = KUI_CDM.db.profile
    local bd = barDataByKey[barKey]
    if bd then barType = bd.barType end
    if not barType then
        if barKey == "cooldowns" then
            barType = "cooldowns"
        elseif barKey == "utility" then
            barType = "utility"
        elseif barKey == "buffs" then
            barType = "buffs"
        end
    end

    if barType == "trinkets" then
        local extras = GetExtraSpells()
        table.sort(extras, function(a, b) return a.name < b.name end)
        return extras
    end

    local cats = ns.CDM_BAR_CATEGORIES[barKey]
        or ns.CDM_BAR_CATEGORIES[barType or "cooldowns"]
        or { 0, 1 }

    local ourPool = {}
    if bd then
        if bd.customSpells then
            for _, sid in ipairs(bd.customSpells) do
                if sid and sid ~= 0 then ourPool[sid] = true end
            end
        end
        if bd.trackedSpells then
            for _, sid in ipairs(bd.trackedSpells) do
                if sid and sid ~= 0 then ourPool[sid] = true end
            end
        end
        if bd.extraSpells then
            for _, sid in ipairs(bd.extraSpells) do
                if sid and sid ~= 0 then ourPool[sid] = true end
            end
        end
    end

    local blizzTracked = {}
    local function ScanViewerSpellIDs(viewerName)
        local vf = _G[viewerName]
        if not vf then return end
        local _children = { vf:GetChildren() }
        for i, child in ipairs(_children) do
            if child and child:IsShown() then
                local cdID = child.cooldownID
                if not cdID and child.cooldownInfo then cdID = child.cooldownInfo.cooldownID end
                if cdID then
                    local info = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
                        and C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    if info then
                        local sid = info.spellID
                        if sid and sid > 0 then blizzTracked[sid] = true end
                    end
                end
            end
        end
    end
    ScanViewerSpellIDs("EssentialCooldownViewer")
    ScanViewerSpellIDs("UtilityCooldownViewer")
    ScanViewerSpellIDs("BuffIconCooldownViewer")
    ScanViewerSpellIDs("BuffBarCooldownViewer")

    local spells = {}
    local seen = {}
    for _, cat in ipairs(cats) do
        local allIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true) or {}
        local knownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, false) or {}
        local knownSet = {}
        for _, id in ipairs(knownIDs) do knownSet[id] = true end

        for _, cdID in ipairs(allIDs) do
            if not seen[cdID] then
                seen[cdID] = true
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                if info then
                    local sid = info.spellID or 0
                    local name = sid > 0 and C_Spell.GetSpellName(sid) or nil
                    local tex = sid > 0 and C_Spell.GetSpellTexture(sid) or nil
                    if name then
                        spells[#spells + 1] = {
                            cdID = cdID,
                            spellID = sid,
                            name = name,
                            icon = tex,
                            cdmCat = cat,
                            isDisplayed = ourPool[sid] or blizzTracked[sid] or false,
                            isKnown = knownSet[cdID] or false,
                            originalOrder = #spells + 1,
                        }
                    end
                end
            end
        end
    end

    table.sort(spells, function(a, b)
        if a.cdmCat ~= b.cdmCat then return (a.cdmCat or 0) < (b.cdmCat or 0) end
        local aScore = (a.isKnown and 2 or 0) + (a.isDisplayed and 1 or 0)
        local bScore = (b.isKnown and 2 or 0) + (b.isDisplayed and 1 or 0)
        if aScore ~= bScore then return aScore > bScore end
        return a.originalOrder < b.originalOrder
    end)

    if barType == "trinkets" then
        local extras = GetExtraSpells()
        table.sort(extras, function(a, b) return a.name < b.name end)
        for _, ex in ipairs(extras) do
            spells[#spells + 1] = ex
        end
    end

    return spells
end

function ns.IsSpellDisplayedInCDM(barKey, cdID)
        local blizzName = ns.BLIZZ_CDM_FRAMES[barKey]
    if not blizzName then return false end
    local blizzFrame = _G[blizzName]
    if not blizzFrame then return false end
    local _children = { blizzFrame:GetChildren() }
    for i, child in ipairs(_children) do
        if child then
            local cid = child.cooldownID
            if not cid and child.cooldownInfo then
                cid = child.cooldownInfo.cooldownID
            end
            if cid == cdID then return true end
        end
    end
    return false
end

function ns.SwapTrackedSpells(barKey, idx1, idx2)
    local p = KUI_CDM.db.profile
    for _, b in ipairs(p.cdmBars.bars) do
        if b.key == barKey then
            if b.customSpells then
                local tKey = ns.KUI_TRACKER_BY_BAR and ns.KUI_TRACKER_BY_BAR[barKey]
                if tKey and p.customTracker and p.customTracker[tKey] then
                    p.customTracker[tKey].auto = false
                    p.customTracker[tKey].spells = b.customSpells
                end
                local t = b.customSpells
                if t and idx1 >= 1 and idx2 >= 1 then
                    local maxIdx = math.max(idx1, idx2)
                    while #t < maxIdx do t[#t + 1] = 0 end
                    t[idx1], t[idx2] = t[idx2], t[idx1]
                    while #t > 0 and (t[#t] == 0 or t[#t] == nil) do t[#t] = nil end
                    local frame = cdmBarFrames[barKey]
                    if frame then frame._blizzCache = nil end
                    return true
                end
            else
                if b.trackedSpells == nil then
                    b.trackedSpells = {}
                    local current = ns.GetCDMSpellsForBar(barKey)
                    if current then
                        for _, sp in ipairs(current) do
                            if sp.spellID and sp.isDisplayed then
                                table.insert(b.trackedSpells, sp.spellID)
                            end
                        end
                    end
                end

                if not b.trackedSpells then b.trackedSpells = {} end
                if not b.extraSpells then b.extraSpells = {} end
                local tracked = b.trackedSpells
                local extras  = b.extraSpells
                local tLen    = #tracked
                local eLen    = #extras
                local total   = tLen + eLen
                if idx1 < 1 or idx2 < 1 then return false end

                local maxIdx = math.max(idx1, idx2)
                if maxIdx > total then
                    while #tracked < maxIdx do tracked[#tracked + 1] = 0 end
                    tLen = #tracked
                    total = tLen + eLen
                end

                local function getVal(i)
                    if i <= tLen then return tracked[i] else return extras[i - tLen] end
                end
                local function setVal(i, v)
                    if i <= tLen then tracked[i] = v else extras[i - tLen] = v end
                end

                local v1 = getVal(idx1)
                local v2 = getVal(idx2)
                setVal(idx1, v2)
                setVal(idx2, v1)

                while #tracked > 0 and (tracked[#tracked] == 0 or tracked[#tracked] == nil) do tracked[#tracked] = nil end
                while #extras > 0 and (extras[#extras] == 0 or extras[#extras] == nil) do extras[#extras] = nil end
                local frame = cdmBarFrames[barKey]
                if frame then frame._blizzCache = nil end
                return true
            end
        end
    end
    return false
end

function ns.MoveTrackedSpell(barKey, fromIdx, toIdx)
    if fromIdx == toIdx then return false end
    local p = KUI_CDM.db.profile
    for _, b in ipairs(p.cdmBars.bars) do
        if b.key == barKey then
            if b.customSpells then
                local tKey = ns.KUI_TRACKER_BY_BAR and ns.KUI_TRACKER_BY_BAR[barKey]
                if tKey and p.customTracker and p.customTracker[tKey] then
                    p.customTracker[tKey].auto = false
                    p.customTracker[tKey].spells = b.customSpells
                end
                local t = b.customSpells
                if fromIdx < 1 or fromIdx > #t then return false end
                if toIdx < 1 then toIdx = 1 end
                while #t < toIdx do t[#t + 1] = 0 end
                local val = table.remove(t, fromIdx)
                table.insert(t, toIdx, val)
                while #t > 0 and (t[#t] == 0 or t[#t] == nil) do t[#t] = nil end
                local frame = cdmBarFrames[barKey]
                if frame then frame._blizzCache = nil end
                return true
            else
                if b.trackedSpells == nil then
                    b.trackedSpells = {}
                    local current = ns.GetCDMSpellsForBar(barKey)
                    if current then
                        for _, sp in ipairs(current) do
                            if sp.spellID and sp.isDisplayed then
                                table.insert(b.trackedSpells, sp.spellID)
                            end
                        end
                    end
                end

                if not b.trackedSpells then b.trackedSpells = {} end
                if not b.extraSpells then b.extraSpells = {} end
                local tracked = b.trackedSpells
                local extras = b.extraSpells
                local tLen = #tracked
                local eLen = #extras
                local total = tLen + eLen
                if fromIdx < 1 or fromIdx > total then return false end
                if toIdx < 1 then toIdx = 1 end
                if toIdx > total then
                    while #tracked < toIdx do tracked[#tracked + 1] = 0 end
                    tLen = #tracked
                    total = tLen + eLen
                end
                local combined = {}
                for i = 1, tLen do combined[i] = tracked[i] end
                for i = 1, eLen do combined[tLen + i] = extras[i] end
                local val = table.remove(combined, fromIdx)
                table.insert(combined, toIdx, val)

                b.trackedSpells = {}
                b.extraSpells = {}
                for i = 1, tLen do b.trackedSpells[i] = combined[i] end
                for i = tLen + 1, #combined do b.extraSpells[i - tLen] = combined[i] end
                while #b.trackedSpells > 0 and (b.trackedSpells[#b.trackedSpells] == 0 or b.trackedSpells[#b.trackedSpells] == nil) do b.trackedSpells[#b.trackedSpells] = nil end
                while #b.extraSpells > 0 and (b.extraSpells[#b.extraSpells] == 0 or b.extraSpells[#b.extraSpells] == nil) do b.extraSpells[#b.extraSpells] = nil end
                local frame = cdmBarFrames[barKey]
                if frame then frame._blizzCache = nil end
                return true
            end
        end
    end
    return false
end

function ns.AddTrackedSpell(barKey, id, isExtra)
    local p = KUI_CDM.db.profile
    for _, b in ipairs(p.cdmBars.bars) do
        if b.key == barKey then
            if b.customSpells then
                local tKey = ns.KUI_TRACKER_BY_BAR and ns.KUI_TRACKER_BY_BAR[barKey]
                if tKey and p.customTracker and p.customTracker[tKey] then
                    p.customTracker[tKey].auto = false
                    p.customTracker[tKey].spells = b.customSpells
                end
                for _, existing in ipairs(b.customSpells) do
                    if existing == id then return false end
                end
                b.customSpells[#b.customSpells + 1] = id
            elseif isExtra then
                if b.trackedSpells == nil then
                    b.trackedSpells = {}
                    local current = ns.GetCDMSpellsForBar(barKey)
                    if current then
                        for _, sp in ipairs(current) do
                            if sp.spellID and sp.isDisplayed then table.insert(b.trackedSpells, sp.spellID) end
                        end
                    end
                end

                if not b.extraSpells then b.extraSpells = {} end
                for _, existing in ipairs(b.extraSpells) do
                    if existing == id then return false end
                end
                b.extraSpells[#b.extraSpells + 1] = id
            else
                if not b.trackedSpells then b.trackedSpells = {} end
                if #b.trackedSpells == 0 then
                    local current = ns.GetCDMSpellsForBar(barKey)
                    if current then
                        for _, sp in ipairs(current) do
                            if sp.spellID and sp.isDisplayed then table.insert(b.trackedSpells, sp.spellID) end
                        end
                    end
                end

                for _, existing in ipairs(b.trackedSpells) do
                    if existing == id then return false end
                end
                b.trackedSpells[#b.trackedSpells + 1] = id
                if b.removedSpells then b.removedSpells[id] = nil end
            end
            local frame = cdmBarFrames[barKey]
            if frame then
                frame._blizzCache = nil; frame._prevVisibleCount = nil
            end
            return true
        end
    end
    return false
end

function ns.RemoveTrackedSpell(barKey, idx)
    local p = KUI_CDM.db.profile
    for _, b in ipairs(p.cdmBars.bars) do
        if b.key == barKey then
            if b.customSpells then
                local tKey = ns.KUI_TRACKER_BY_BAR and ns.KUI_TRACKER_BY_BAR[barKey]
                if tKey and p.customTracker and p.customTracker[tKey] then
                    p.customTracker[tKey].auto = false
                    p.customTracker[tKey].spells = b.customSpells
                end
                local list = b.customSpells
                if list and idx >= 1 and idx <= #list then
                    table.remove(list, idx)
                    local frame = cdmBarFrames[barKey]
                    if frame then
                        frame._blizzCache = nil; frame._prevVisibleCount = nil
                    end
                    return true
                end
            else
                if b.trackedSpells == nil then
                    b.trackedSpells = {}
                    local current = ns.GetCDMSpellsForBar(barKey)
                    if current then
                        for _, sp in ipairs(current) do
                            if sp.spellID and sp.isDisplayed then table.insert(b.trackedSpells, sp.spellID) end
                        end
                    end
                end

                local tracked = b.trackedSpells or {}
                local extras  = b.extraSpells or {}
                if idx >= 1 and idx <= #tracked then
                    local sid = tracked[idx]
                    table.remove(tracked, idx)
                    if sid and sid ~= 0 then
                        if not b.removedSpells then b.removedSpells = {} end
                        b.removedSpells[sid] = true
                    end
                    local frame = cdmBarFrames[barKey]
                    if frame then
                        frame._blizzCache = nil; frame._prevVisibleCount = nil
                    end
                    return true
                elseif idx > #tracked and idx <= #tracked + #extras then
                    table.remove(extras, idx - #tracked)
                    local frame = cdmBarFrames[barKey]
                    if frame then
                        frame._blizzCache = nil; frame._prevVisibleCount = nil
                    end
                    return true
                end
            end
        end
    end
    return false
end

function ns.ReplaceTrackedSpell(barKey, idx, newID, isExtra)
    local p = KUI_CDM.db.profile
    for _, b in ipairs(p.cdmBars.bars) do
        if b.key == barKey then
            if b.customSpells then
                local tKey = ns.KUI_TRACKER_BY_BAR and ns.KUI_TRACKER_BY_BAR[barKey]
                if tKey and p.customTracker and p.customTracker[tKey] then
                    p.customTracker[tKey].auto = false
                    p.customTracker[tKey].spells = b.customSpells
                end
                local list = b.customSpells
                while #list < idx do list[#list + 1] = 0 end
                if idx >= 1 then
                    for i, existing in ipairs(list) do
                        if existing == newID and i ~= idx then
                            table.remove(list, i)
                            if i < idx then idx = idx - 1 end
                            break
                        end
                    end
                    list[idx] = newID
                    while #list > 0 and (list[#list] == 0 or list[#list] == nil) do list[#list] = nil end
                    local frame = cdmBarFrames[barKey]
                    if frame then
                        frame._blizzCache = nil; frame._prevVisibleCount = nil
                    end
                    return true
                end
            else
                if b.trackedSpells == nil then
                    b.trackedSpells = {}
                    local current = ns.GetCDMSpellsForBar(barKey)
                    if current then
                        for _, sp in ipairs(current) do
                            if sp.spellID and sp.isDisplayed then table.insert(b.trackedSpells, sp.spellID) end
                        end
                    end
                end

                local tracked = b.trackedSpells or {}
                local extras  = b.extraSpells or {}
                if idx >= 1 and idx <= #tracked then
                    if isExtra then
                        table.remove(tracked, idx)
                        if not b.extraSpells then b.extraSpells = {} end
                        local found = false
                        for _, ex in ipairs(b.extraSpells) do
                            if ex == newID then
                                found = true; break
                            end
                        end
                        if not found then b.extraSpells[#b.extraSpells + 1] = newID end
                    else
                        while #b.trackedSpells < idx do b.trackedSpells[#b.trackedSpells + 1] = 0 end
                        for i, existing in ipairs(b.trackedSpells) do
                            if existing == newID and i ~= idx then
                                table.remove(b.trackedSpells, i)
                                if i < idx then idx = idx - 1 end
                                break
                            end
                        end
                        b.trackedSpells[idx] = newID
                        while #b.trackedSpells > 0 and (b.trackedSpells[#b.trackedSpells] == 0 or b.trackedSpells[#b.trackedSpells] == nil) do b.trackedSpells[#b.trackedSpells] = nil end
                        if b.removedSpells then b.removedSpells[newID] = nil end
                    end
                    local frame = cdmBarFrames[barKey]
                    if frame then
                        frame._blizzCache = nil; frame._prevVisibleCount = nil
                    end
                    return true
                elseif idx > #tracked and idx <= #tracked + #extras then
                    local eIdx = idx - #tracked
                    if isExtra then
                        for i, existing in ipairs(extras) do
                            if existing == newID and i ~= eIdx then
                                table.remove(extras, i)
                                if i < eIdx then eIdx = eIdx - 1 end
                                break
                            end
                        end
                        extras[eIdx] = newID
                    else
                        table.remove(extras, eIdx)
                        if not b.trackedSpells then b.trackedSpells = {} end
                        local found = false
                        for _, ex in ipairs(b.trackedSpells) do
                            if ex == newID then
                                found = true; break
                            end
                        end
                        if not found then b.trackedSpells[#b.trackedSpells + 1] = newID end
                        if b.removedSpells then b.removedSpells[newID] = nil end
                    end
                    local frame = cdmBarFrames[barKey]
                    if frame then
                        frame._blizzCache = nil; frame._prevVisibleCount = nil
                    end
                    return true
                end
            end
        end
    end
    return false
end

function ns.AddCDMBar(barType, name, numRows)
    local p = KUI_CDM.db.profile
    local bars = p.cdmBars.bars
    local customCount = 0
    for _, b in ipairs(bars) do
        if b.key ~= "cooldowns" and b.key ~= "utility" and b.key ~= "buffs" then
            customCount = customCount + 1
        end
    end
    if customCount >= ns.MAX_CUSTOM_BARS then return nil end
    barType = barType or "cooldowns"
    local typeLabel = barType == "cooldowns" and "Cooldowns"
        or barType == "utility" and "Utility"
        or barType == "buffs" and "Buffs"
        or barType == "trinkets" and "Trinkets/Racials/Potions"
        or "Cooldowns"
    local typeCount = 0
    for _, b in ipairs(bars) do
        if b.barType == barType then typeCount = typeCount + 1 end
    end
    local key = "custom_" .. (#bars + 1) .. "_" .. GetTime()
    key = key:gsub("%.", "_")
    bars[#bars + 1] = {
        key = key,
        name = name or
            ((barType == "trinkets" and "Miscellaneous " or "Custom " .. typeLabel .. " Bar ") .. (typeCount + 1)),
        barType = barType,
        enabled = true,
        barScale = 1.0,
        iconSize = 36,
        numRows = numRows or 1,
        spacing = 2,
        borderSize = 1,
        borderR = 0,
        borderG = 0,
        borderB = 0,
        borderA = 1,
        borderClassColor = false,
        borderThickness = "thin",
        bgR = 0.08,
        bgG = 0.08,
        bgB = 0.08,
        bgA = 0.6,
        iconZoom = 0.08,
        iconShape = "none",
        growDirection = "RIGHT",
        verticalOrientation = false,
        barBgEnabled = false,
        barBgAlpha = 1.0,
        barBgR = 0,
        barBgG = 0,
        barBgB = 0,
        showCooldownText = true,
        cooldownFontSize = 12,
        showCharges = true,
        chargeFontSize = 11,
        desaturateOnCD = false,
        swipeAlpha = 0.7,
        swipeR = 0,
        swipeG = 0,
        swipeB = 0,
        activeSwipeUsesGlowColor = true,
        hideGCDSwipe = false,
        activeStateAnim = "blizzard",
        -- Default: stack custom bars just below the Utility bar
        anchorTo = "utility",
        anchorPosition = "bottom",
        anchorOffsetX = 0,
        anchorOffsetY = -2,
        barVisibility = "always",
        housingHideEnabled = true,
        hideBuffsWhenInactive = true,
        stackCountSize = 12,
        stackCountX = 0,
        stackCountY = 0,
        stackCountR = 1,
        stackCountG = 1,
        stackCountB = 1,
        customSpells = {},
    }
    BuildAllCDMBars()
    SafeUpdateCustomBarIcons(key)
    LayoutCDMBar(key)
    RegisterCDMUnlockElements()
    return key
end

function ns.RemoveCDMBar(key)
    if key == "cooldowns" or key == "utility" or key == "buffs" then return false end
    local p = KUI_CDM.db.profile
    for i, barData in ipairs(p.cdmBars.bars) do
        if barData.key == key then
            local frame = cdmBarFrames[key]
            if frame then frame:Hide() end
            cdmBarFrames[key] = nil
            cdmBarIcons[key] = nil
            p.cdmBarPositions[key] = nil
            table.remove(p.cdmBars.bars, i)
            if KT and KT.UnregisterUnlockElement then
                KT:UnregisterUnlockElement("CDM_" .. key)
            end
            RegisterCDMUnlockElements()
            return true
        end
    end
    return false
end

local function IsCooldownUrgentUpdate(reason)
    return reason == "synthetic_spellcast"
        or reason == "synthetic_items"
end

local function RequestUpdate(reason)
    reason = reason or "request"
    if reason == 'spell_update_cooldown'
        or reason == 'spell_update_charges'
        or reason == 'actionbar_update_cooldown'
        or reason == 'item_count_changed'
        or reason == 'item_push'
        or reason == 'bag_update_delayed'
        or reason == 'player_spellcast_succeeded'
        or reason == 'synthetic_spellcast'
        or reason == 'synthetic_items'
    then
        if ns.RequestCustomCooldownUpdate then
            ns.RequestCustomCooldownUpdate(reason)
        end
        return
    end
    -- Targeted dirty: high-frequency reasons (hook, cooldowns, casts) must NEVER
    -- set allBars. A full-bar pass per keystroke/aura update was the source of
    -- the hundreds-of-ms hooks in combat. Real transitions (entering world,
    -- talents, spec) still force a full pass via forceFullPass below.
    CDMRT:MarkDirty(reason, true)
    if ns.RunCDMUpdateIfIdle then
        ns.RunCDMUpdateIfIdle(IsCooldownUrgentUpdate(reason))
    end
end
ns.RequestUpdate = RequestUpdate
ns.RequestCDMUpdate = RequestUpdate

-- Targeted-only dirty request for high-frequency hook sources (aura/pool edges).
-- Used by the viewer frame hooks so a keystroke never rebuilds every bar.
ns.MarkDirtyTargeted = function(reason)
    CDMRT:MarkDirty(reason or "hook", true)
    if ns.RunCDMUpdateIfIdle then
        ns.RunCDMUpdateIfIdle(false)
    end
end

function ns.RequestCustomCooldownUpdate(reason)
    if ns._customCooldownUpdatePending then return end
    ns._customCooldownUpdatePending = true
    -- Coalesce to 10 Hz, not per-frame: in a 23-40 man raid SPELL_UPDATE_COOLDOWN
    -- / SPELL_UPDATE_CHARGES / ACTIONBAR_UPDATE_COOLDOWN fire hundreds of times
    -- per second (every open-world mob and raid member). Rebuilding every custom
    -- bar + wiping five tick caches once per frame (60/s) was the sustained CDM
    -- cost in raid. The native cooldown widgets animate themselves; 10 Hz is the
    -- visible ceiling for an icon-timer refresh.
    C_Timer.After(0.10, function()
        ns._customCooldownUpdatePending = false
        local profile = KUI_CDM.db and KUI_CDM.db.profile
        if not (profile and profile.cdmBars and profile.cdmBars.enabled) then return end

        wipe(_tickGCDCache)
        wipe(_tickChargeCache)
        wipe(_tickAuraCache)
        wipe(_tickUsableCache)
        wipe(_tickTotemCache)

        for _, barData in ipairs(profile.cdmBars.bars or {}) do
            if barData.enabled and barData.customSpells and not ns.BLIZZ_CDM_FRAMES[barData.key] then
                SafeUpdateCustomBarIcons(barData.key)
            end
        end
    end)
end

local function InvalidateBlizzardViewerSnapshot()
    CDMRT.viewerSnapshotReady = false
    CDMRT.viewerSnapshotElapsed = 0
    wipe(_tickBlizzActiveCache)
    wipe(_tickBlizzOverrideCache)
    wipe(_tickBlizzChildCache)
    wipe(_tickBlizzAllChildCache)
    wipe(_tickBlizzBuffChildCache)
    if ns.InvalidateTBBFrameCache then
        ns.InvalidateTBBFrameCache()
    end
    if ns._tickBlizzMirror then
        ns._tickBlizzMirror:reset()
    end
end

-------------------------------------------------------------------------------
--  Initialization via Custom Event Frame (Replaces Ace3)
-------------------------------------------------------------------------------

local function CopyDefaults(src, dst)
    if type(src) ~= "table" then return {} end
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif type(v) ~= type(dst[k]) then
            dst[k] = v
        end
    end
    return dst
end

local function SyncExternalDBBindings()
    if not (KT and KT.db) then
        return nil
    end

    KT.db.global = KT.db.global or {}
    KT.db.profile.cooldownManager = CopyDefaults(DEFAULTS.profile, KT.db.profile.cooldownManager)
    KT.db.global.cooldownManager = CopyDefaults(DEFAULTS.global, KT.db.global.cooldownManager)

    KUI_CDM.db = KUI_CDM.db or {}
    KUI_CDM.db.profile = KT.db.profile.cooldownManager
    KUI_CDM.db.global = KT.db.global.cooldownManager

    _G._KUI_CDM_AceDB = KUI_CDM.db
    return KUI_CDM.db
end

ns.SyncExternalDBBindings = SyncExternalDBBindings
_G._KUI_CDM_SyncProfileDB = SyncExternalDBBindings

local _queuedCDMRebuildToken = 0
local function QueueCDMRebuild(delay, reason)
    _queuedCDMRebuildToken = _queuedCDMRebuildToken + 1
    local token = _queuedCDMRebuildToken
    C_Timer.After(delay or 0, function()
        if token ~= _queuedCDMRebuildToken then
            return
        end
        if BuildAllCDMBars then
            BuildAllCDMBars()
        end
        RequestUpdate(reason or "queued_rebuild")
    end)
end

local function UpdateAllCDMBars(dt)
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("cdm.update.all")
    local forceFullPass = CDMRT.forceFullPass == true
    if forceFullPass then
        cdmUpdateThrottle = CDM_UPDATE_INTERVAL
    end

    cdmUpdateThrottle = cdmUpdateThrottle + (dt or CDM_UPDATE_INTERVAL)
    if cdmUpdateThrottle < CDM_UPDATE_INTERVAL then
        if profileStarted then profiler:End("cdm.update.all", profileStarted) end
        return
    end
    cdmUpdateThrottle = 0
    CDMRT.forceFullPass = nil

    local profile = KUI_CDM.db and KUI_CDM.db.profile
    if not profile or not profile.cdmBars or not profile.cdmBars.enabled then
        if profileStarted then profiler:End("cdm.update.all", profileStarted) end
        return
    end

    local perfCapturing = CDMRT.perf and CDMRT.perf.capturing
    local perfAutoEnabled = CDMRT.perf and CDMRT.perf.auto and CDMRT.perf.auto.enabled
    local enabledBars = 0
    local visibleIconsBefore, totalIconsBefore = 0, 0
    if perfCapturing or perfAutoEnabled then
        enabledBars = CDMRT:CountEnabledBars(profile)
        visibleIconsBefore, totalIconsBefore = CDMRT:CountVisibleIcons()
    end

    local wasDirty, viewerDirty, dirtyBars, allBarsDirty = CDMRT:ConsumeDirty()
    -- Only a full pass when explicitly requested. `not next(dirtyBars)` used to
    -- make a NON-targeted dirty reason (e.g. every UNIT_SPELLCAST_SUCCEEDED and
    -- SPELL_UPDATE_COOLDOWN in combat) rebuild EVERY bar -- UpdateCDMBarIcons on
    -- every native bar, on every cast/cooldown tick -- which was the source of
    -- the repeated 50-500ms spikes. Composition is event-driven now: mark the
    -- specific bar dirty, or pass forceFullPass.
    local updateAllBars = forceFullPass or allBarsDirty
    local refreshBarGlowRuntime = viewerDirty and true or false
    local mouseTrackCount = CDMRT.mouseTrackCount or 0
    local visibleIconsNow = select(1, CDMRT:CountVisibleIcons())
    local inCombat = InCombatLockdown and InCombatLockdown() or false
    -- Native CooldownViewer frames and Cooldown widgets already animate their
    -- own timers.  The old clone renderer needed a combat poll, but KUI now
    -- mirrors native frames and custom trackers are refreshed by cooldown,
    -- aura, inventory and spellcast events.  Polling every 0.12s while any
    -- icon is visible rebuilt every KUI Tracker bar even when nothing changed.
    local shouldProcessTick = forceFullPass or wasDirty or mouseTrackCount > 0
    if not shouldProcessTick then
        if perfCapturing or perfAutoEnabled then
            CDMRT:PerfFinalizeTick(0, enabledBars, visibleIconsBefore, totalIconsBefore, true)
        end
        if perfAutoEnabled and CDMRT.PerfAutoEvaluate then
            CDMRT:PerfAutoEvaluate(0, false, mouseTrackCount, visibleIconsNow, false)
        end
        if profileStarted then profiler:End("cdm.update.all", profileStarted) end
        return
    end

    local allowBarStagger = mouseTrackCount <= 0 and not forceFullPass and not wasDirty
    if allowBarStagger then
        CDMRT.barUpdatePhase = 1 - (CDMRT.barUpdatePhase or 0)
    else
        CDMRT.barUpdatePhase = 0
    end

    local perfTickActive = (perfCapturing or perfAutoEnabled) and debugprofilestart and debugprofilestop
    local perfCursor = 0
    if perfTickActive then
        debugprofilestart()
    end

    -- Wipe per-tick caches
    wipe(_tickGCDCache)
    wipe(_tickChargeCache)
    wipe(_tickAuraCache)
    wipe(_tickUsableCache)
    wipe(_tickTotemCache)
    if perfTickActive then
        local now = debugprofilestop()
        CDMRT:PerfPhaseAdd("cache_wipe", now - perfCursor)
        perfCursor = now
    end

    -- Build Blizzard viewer caches only after a real composition edge. The
    -- periodic fallback performs a cheap pool-signature probe first.
    CDMRT.viewerSnapshotElapsed = (CDMRT.viewerSnapshotElapsed or 0) + (dt or CDM_UPDATE_INTERVAL)
    local snapshotInterval = 3.00
    local probedViewerSignature
    local shouldRefreshViewerSnapshot = (not CDMRT.viewerSnapshotReady) or forceFullPass or viewerDirty
    if not shouldRefreshViewerSnapshot and visibleIconsNow > 0 and CDMRT.viewerSnapshotElapsed >= snapshotInterval then
        CDMRT.viewerSnapshotElapsed = 0
        local getSignature = ns.GetCDMViewerPoolSignature
        if getSignature then
            local ok, signature = pcall(getSignature)
            if ok then
                probedViewerSignature = signature
                if CDMRT.viewerPoolSignature == nil then
                    CDMRT.viewerPoolSignature = signature
                elseif signature ~= CDMRT.viewerPoolSignature then
                    shouldRefreshViewerSnapshot = true
                end
            else
                shouldRefreshViewerSnapshot = true
            end
        else
            shouldRefreshViewerSnapshot = true
        end
    end
    if shouldRefreshViewerSnapshot then
        CDMRT.viewerSnapshotElapsed = 0
        do
            local hasBlizzardBar = false
            for _, barData in ipairs(profile.cdmBars.bars) do
                if barData.enabled and ns.BLIZZ_CDM_FRAMES[barData.key] then
                    hasBlizzardBar = true
                    break
                end
            end

            if hasBlizzardBar then
                wipe(_tickBlizzActiveCache)
                wipe(_tickBlizzOverrideCache)
                wipe(_tickBlizzChildCache)
                wipe(_tickBlizzAllChildCache)
                wipe(_tickBlizzBuffChildCache)
                ns._tickBlizzMirror:reset()
                local GetInfo = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
                if GetInfo then
                    for _, vName in ipairs(_cdmViewerNames) do
                        local vf = _G[vName]
                        if vf then
                            if vf.itemFramePool and vf.itemFramePool.EnumerateActive then
                                for ch in vf.itemFramePool:EnumerateActive() do
                                    local cdID = ch.cooldownID or (ch.cooldownInfo and ch.cooldownInfo.cooldownID)
                                    if cdID then
                                        local info = GetInfo(cdID)
                                        if info then
                                            CacheBlizzardViewerChild(ch, info, vName)
                                        end
                                    end
                                end
                            elseif vf.EnumerateChildren then
                                for ch in vf:EnumerateChildren() do
                                    local cdID = ch.cooldownID or (ch.cooldownInfo and ch.cooldownInfo.cooldownID)
                                    if cdID then
                                        local info = GetInfo(cdID)
                                        if info then
                                            CacheBlizzardViewerChild(ch, info, vName)
                                        end
                                    end
                                end
                            else
                                local _children = { vf:GetChildren() }
                                for ci, ch in ipairs(_children) do
                                    if ch then
                                        local cdID = ch.cooldownID or (ch.cooldownInfo and ch.cooldownInfo.cooldownID)
                                        if cdID then
                                            local info = GetInfo(cdID)
                                            if info then
                                                CacheBlizzardViewerChild(ch, info, vName)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    for _, barKey in ipairs({ "cooldowns", "utility", "buffs" }) do
                        table.sort(ns._tickBlizzMirror.icons[barKey], SortBlizzChildren)
                    end
                end
            else
                if next(_tickBlizzActiveCache) then wipe(_tickBlizzActiveCache) end
                if next(_tickBlizzOverrideCache) then wipe(_tickBlizzOverrideCache) end
                if next(_tickBlizzChildCache) then wipe(_tickBlizzChildCache) end
                if next(_tickBlizzAllChildCache) then wipe(_tickBlizzAllChildCache) end
                if next(_tickBlizzBuffChildCache) then wipe(_tickBlizzBuffChildCache) end
                ns._tickBlizzMirror:reset()
            end
        end
        CDMRT.viewerSnapshotReady = true
        if probedViewerSignature ~= nil then
            CDMRT.viewerPoolSignature = probedViewerSignature
        elseif ns.GetCDMViewerPoolSignature then
            local ok, signature = pcall(ns.GetCDMViewerPoolSignature)
            if ok then CDMRT.viewerPoolSignature = signature end
        end
    end
    if perfTickActive then
        local now = debugprofilestop()
        CDMRT:PerfPhaseAdd("viewer_snapshot", now - perfCursor)
        perfCursor = now
    end

    local barPhaseStart = perfTickActive and perfCursor or 0
    -- Non-targeted dirty (cast, cooldown, visibility) touches custom/KUI tracker
    -- bars, which read slot composition. Native Blizzard bars animate themselves
    -- and are covered by their pool hooks, so only custom/tracker bars fall back
    -- to a refresh when no specific bar was marked.
    local dirtyHasNoBar = wasDirty and not (next(dirtyBars) ~= nil)
    for i, barData in ipairs(profile.cdmBars.bars) do
        local barNeedsUpdate = updateAllBars or dirtyBars[barData.key]
        if barNeedsUpdate and dirtyHasNoBar and not viewerDirty
            and ns.BLIZZ_CDM_FRAMES and ns.BLIZZ_CDM_FRAMES[barData.key] then
            barNeedsUpdate = false
        end
        if barData.enabled and barNeedsUpdate then
            if allowBarStagger and barData.key ~= "buffs" and (i % 2) ~= CDMRT.barUpdatePhase then
                if perfTickActive then
                    CDMRT:PerfBarAdd(barData.key, "stagger_skip", 0)
                end
            else
            local barStart = perfTickActive and debugprofilestop() or 0
            local sourceKey = nil
            if ns.BLIZZ_CDM_FRAMES[barData.key] then
                local useBlizzardDefaults = profile.cdmBars and profile.cdmBars.useBlizzardDisplayDefaults ~= false
                -- Importing Blizzard defaults may update KUI's stored order, but
                -- rendering always claims the actual native item frames. A local
                -- order changes sorting only; it must never switch back to clones.
                -- Buffs must remain a live mirror. Snapshotting the currently
                -- active BuffIcon pool would turn a partial moment into a
                -- permanent tracked list and drop future buffs.
                if barData.key ~= "buffs"
                    and useBlizzardDefaults
                    and not blizzImport.HasLocalMainBarLayout(barData)
                    and SnapshotBlizzardCDM(barData.key, barData) then
                    blizzImport.QueueSpecProfileSave()
                end
                sourceKey = "blizzard_native"
                local compositionChanged = UpdateCDMBarIcons(barData.key)
                if compositionChanged then
                    refreshBarGlowRuntime = true
                end
            elseif barData.customSpells then
                -- Custom bar: track spells directly
                sourceKey = "custom_spells"
                SafeUpdateCustomBarIcons(barData.key)
            end

            if perfTickActive then
                local now = debugprofilestop()
                local delta = now - barStart
                CDMRT:PerfBarAdd(barData.key, sourceKey, delta)
                perfCursor = now
            end
            end
        end
    end

    if perfTickActive then
        local now = debugprofilestop()
        CDMRT:PerfPhaseAdd("bar_updates", now - barPhaseStart)
        perfCursor = now
    end

    if refreshBarGlowRuntime and ns.RefreshBarGlowRuntime then
        ns.RefreshBarGlowRuntime(false)
    end

    local visibleIconsAfter, totalIconsAfter = 0, 0
    if perfCapturing or perfAutoEnabled then
        visibleIconsAfter, totalIconsAfter = CDMRT:CountVisibleIcons()
    end
    local totalMs = 0
    if perfTickActive then
        totalMs = debugprofilestop()
        CDMRT:PerfPhaseAdd("tick_total", totalMs)
    end
    CDMRT:PerfFinalizeTick(totalMs, enabledBars, visibleIconsAfter, totalIconsAfter, false)
    if perfAutoEnabled and CDMRT.PerfAutoEvaluate then
        CDMRT:PerfAutoEvaluate(totalMs, inCombat, mouseTrackCount, visibleIconsAfter, true)
    end
    if profileStarted then profiler:End("cdm.update.all", profileStarted) end
end
ns.UpdateAllCDMBars = UpdateAllCDMBars


local _idleRefreshPending = false
function ns.RunCDMUpdateIfIdle(forceImmediate)
    if forceImmediate then
        CDMRT.forceFullPass = true
        UpdateAllCDMBars(CDM_UPDATE_INTERVAL)
        return
    end

    if _idleRefreshPending then return end
    _idleRefreshPending = true
    C_Timer.After(0, function()
        _idleRefreshPending = false
        -- Callers already mark the precise dirty reason. Turning every queued
        -- event into forceFullPass rebuilt the complete viewer snapshot on
        -- login, combat transitions and option changes.
        UpdateAllCDMBars(CDM_UPDATE_INTERVAL)
    end)
end

ns._lateCDMRefreshToken = ns._lateCDMRefreshToken or 0
function ns.GetCDMViewerPoolSignature()
    local signature = {}
    for _, viewerName in ipairs(_cdmViewerNames) do
        local viewer = _G[viewerName]
        local entries = {}
        if viewer and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
            for child in viewer.itemFramePool:EnumerateActive() do
                local cooldownID = child.cooldownID or (child.cooldownInfo and child.cooldownInfo.cooldownID)
                local ok, value = pcall(tostring, cooldownID or child)
                entries[#entries + 1] = ok and value or "restricted"
            end
        elseif viewer and viewer.EnumerateChildren then
            for child in viewer:EnumerateChildren() do
                if child and child.IsShown and child:IsShown() then
                    local cooldownID = child.cooldownID or (child.cooldownInfo and child.cooldownInfo.cooldownID)
                    local ok, value = pcall(tostring, cooldownID or child)
                    entries[#entries + 1] = ok and value or "restricted"
                end
            end
        end
        table.sort(entries)
        signature[#signature + 1] = viewerName
        signature[#signature + 1] = table.concat(entries, ",")
    end
    return table.concat(signature, "|")
end

function ns.ScheduleLateCDMRefreshes()
    ns._lateCDMRefreshToken = ns._lateCDMRefreshToken + 1
    local token = ns._lateCDMRefreshToken
    ns._lateCDMViewerSignature = nil
    ns._lateCDMStablePasses = 0

    -- These are bounded transition retries, not a permanent poll. The final
    -- pass covers slow arena/BG loading screens where Blizzard's pools settle
    -- more than a second after PLAYER_ENTERING_WORLD.
    for _, delay in ipairs({ 0.25, 1.0, 2.0, 6.0 }) do
        C_Timer.After(delay, function()
            if token ~= ns._lateCDMRefreshToken then return end
            if not (KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile and KUI_CDM.db.profile.cdmBars and KUI_CDM.db.profile.cdmBars.enabled) then
                return
            end

            -- Viewer objects and their pools may be created after the initial
            -- PLAYER_ENTERING_WORLD callback on /reload. Re-run the idempotent
            -- hook installer and reclaim already-known frames before the
            -- signature early-out; equal IDs do not mean equal layout state.
            if ns.SetupNativeCDMViewerHooks then ns.SetupNativeCDMViewerHooks() end
            if ns.ReassertNativeCDMViewerLayout then
                ns.ReassertNativeCDMViewerLayout("EssentialCooldownViewer")
                ns.ReassertNativeCDMViewerLayout("UtilityCooldownViewer")
                ns.ReassertNativeCDMViewerLayout("BuffIconCooldownViewer")
            end

            local signature = ns.GetCDMViewerPoolSignature()
            local changed = signature ~= ns._lateCDMViewerSignature
            if changed then
                ns._lateCDMViewerSignature = signature
                ns._lateCDMStablePasses = 0
            else
                ns._lateCDMStablePasses = (ns._lateCDMStablePasses or 0) + 1
                if ns._lateCDMStablePasses >= 1 then
                    return
                end
            end

            -- Instance transitions can leave ZONE_CHANGED_NEW_AREA evaluated
            -- with the old arena state, hiding the KUI containers. Blizzard
            -- also repopulates its CooldownViewer pools asynchronously.
            HideBlizzardCDM()
            if ns.CDMApplyVisibility then ns.CDMApplyVisibility() end
            InvalidateBlizzardViewerSnapshot()
            if ns.WakeTrackedBuffBars then ns.WakeTrackedBuffBars() end
            CDMRT:MarkDirty("late_viewer_settle")
            if changed and delay == 2.0 and BuildAllCDMBars and not (InCombatLockdown and InCombatLockdown()) then
                -- Reclaim Blizzard's pooled viewer children once after the
                -- arena/BG transition has settled.
                BuildAllCDMBars()
                CDMRT:MarkDirty("world_transition_rebuild")
            elseif changed and delay == 2.0 and InCombatLockdown and InCombatLockdown() then
                ns._transitionCDMRebuildPending = true
            end

            if ns.RunCDMUpdateIfIdle then
                ns.RunCDMUpdateIfIdle()
            end
        end)
    end
end

do
ns.initFrame = CreateFrame("Frame")
ns.initFrame:RegisterEvent("ADDON_LOADED")
ns.initFrame:RegisterEvent("PLAYER_LOGIN")
ns.initFrame:RegisterEvent("UPDATE_BINDINGS")
ns.initFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ns.initFrame:RegisterEvent("UPDATE_MACROS")
ns.initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

function KUI_CDM:CDMFinishSetup()
    ns.RebuildCdIDToCorrectSID()
    if ns.SetupNativeCDMViewerHooks then ns.SetupNativeCDMViewerHooks() end
    BuildAllCDMBars()
    if ns.BuildTrackedBuffBars then ns.BuildTrackedBuffBars() end
    ns.ScheduleLateCDMRefreshes()
    blizzImport.HookPrompt()
    C_Timer.After(1, blizzImport.HookPrompt)
    C_Timer.After(1, blizzImport.TryShowInitialPrompt)
    C_Timer.After(3, blizzImport.TryShowInitialPrompt)
    C_Timer.After(6, blizzImport.TryShowInitialPrompt)

    -- C_Timer.After(1, ForceResnapshotMainBars)
    -- C_Timer.After(3, ForceResnapshotMainBars)
    -- ForcePopulateBlizzardViewers(function()
    --     ForceResnapshotMainBars()
    --     StartResnapshotRetry()
    -- end)

    C_Timer.After(1, function()
        local p = KUI_CDM.db.profile
        if p.activeSpecKey and p.activeSpecKey ~= "0" then
            SaveCurrentSpecProfile()
        end
    end)

    C_Timer.After(0.5, UpdateCDMKeybinds)

    -- The old clone renderer required a 10 Hz full poll. Native cooldowns update
    -- themselves; pool/mixin/events above request a pass only when state changes.
    if self._cdmTickFrame then
        self._cdmTickFrame:SetScript("OnUpdate", nil)
        self._cdmTickFrame:Hide()
    end
    if ns.RunCDMUpdateIfIdle then
        ns.RunCDMUpdateIfIdle()
    end

    C_Timer.After(0.5, function()
        RegisterCDMUnlockElements()
        if ns.RegisterTBBUnlockElements then ns.RegisterTBBUnlockElements() end
    end)
end

ns.initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Connect the module to the shared KullThranUI database.
        if not KT.db then return end
        local hadCDMProfile = type(KT.db.profile.cooldownManager) == "table"

        if not KT.db.profile.cooldownManager then KT.db.profile.cooldownManager = {} end
        if not KT.db.global.cooldownManager then KT.db.global.cooldownManager = {} end
        SyncExternalDBBindings()

        -- Migrations
        local bars = KUI_CDM.db.profile.cdmBars and KUI_CDM.db.profile.cdmBars.bars
        if bars then
            for _, b in ipairs(bars) do
                if b.hideBuffsWhenInactive == nil then
                    b.hideBuffsWhenInactive = true
                end
            end
        end

        local p = KUI_CDM.db.profile
        if not hadCDMProfile and p._initialBlizzardLayoutPromptShown == nil then
            p._initialBlizzardLayoutPromptPending = true
        end
        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v13 then
            for _, b in ipairs(p.cdmBars.bars) do
                b.desaturateOnCD = false -- USER FORCED
                if b.key == "utility" then
                    b.iconSize = 40
                    b.anchorTo = "cooldowns"
                    b.anchorPosition = "bottom"
                    b.anchorOffsetX = 0
                    b.anchorOffsetY = -2
                elseif b.key == "buffs" then
                    b.anchorTo = "castbar"
                    b.anchorPosition = "top"
                    b.anchorOffsetX = 0
                    b.anchorOffsetY = 4
                elseif b.key == "cooldowns" and b.showKeybind == nil then
                    b.showKeybind = false
                end
            end
            if p.cdmBarPositions and p.cdmBarPositions["cooldowns"] then
                p.cdmBarPositions["cooldowns"].y = -450
                p.cdmBarPositions["cooldowns"].x = 0
                p.cdmBarPositions["cooldowns"].point = "CENTER"
            else
                p.cdmBarPositions = p.cdmBarPositions or {}
                p.cdmBarPositions["cooldowns"] = { point = "CENTER", x = 0, y = -450 }
            end
            p.migratedCDM_v13 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v14 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "buffs" then
                    b.anchorTo = "erb_powerbar"
                    b.anchorPosition = "top"
                    b.anchorOffsetX = 0
                    b.anchorOffsetY = 15
                end
            end
            p.migratedCDM_v14 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v15 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "buffs" then
                    b.anchorOffsetY = 15
                end
            end
            if p.cdmBarPositions and p.cdmBarPositions["cooldowns"] then
                p.cdmBarPositions["cooldowns"].y = -450
            end
            p.migratedCDM_v15 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v16 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "buffs" then
                    b.anchorOffsetY = 15
                end
            end
            if p.cdmBarPositions and p.cdmBarPositions["cooldowns"] then
                p.cdmBarPositions["cooldowns"].y = -450
            end
            p.migratedCDM_v16 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v17 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "buffs" then
                    b.anchorOffsetY = 15
                elseif b.key == "cooldowns" then
                    b.anchorOffsetY = -300
                elseif b.key == "utility" then
                    b.iconSize = 40
                end
            end
            if p.cdmBarPositions and p.cdmBarPositions["cooldowns"] then
                p.cdmBarPositions["cooldowns"].y = -300
            end
            p.migratedCDM_v17 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v18 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "cooldowns" then
                    b.anchorOffsetY = -250
                elseif b.key == "utility" then
                    b.iconSize = 40
                end
            end
            p.cdmBarPositions = p.cdmBarPositions or {}
            if not p.cdmBarPositions["cooldowns"] then
                p.cdmBarPositions["cooldowns"] = { point = "CENTER", x = 0, y = -250 }
            else
                p.cdmBarPositions["cooldowns"].y = -250
            end
            p.migratedCDM_v18 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v19 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "cooldowns" then
                    -- Forzar a que no tenga ancla para que use las posiciones guardadas
                    b.anchorTo = "none"
                elseif b.key == "utility" then
                    b.iconSize = 40
                end
            end
            p.cdmBarPositions = p.cdmBarPositions or {}
            if not p.cdmBarPositions["cooldowns"] then
                p.cdmBarPositions["cooldowns"] = { point = "CENTER", relPoint = "UIParent", x = 0, y = -450 }
            else
                p.cdmBarPositions["cooldowns"].y = -450
            end
            p.migratedCDM_v19 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v20 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "cooldowns" then
                    -- Baja el conjunto de cooldowns mas abajo por defecto
                    if b.anchorOffsetY == nil or b.anchorOffsetY == -450 or b.anchorOffsetY == -300 or b.anchorOffsetY == -250 then
                        b.anchorOffsetY = -500
                    end
                elseif b.key == "utility" then
                    -- Forzar icon size por defecto a 40px
                    if b.iconSize == nil or b.iconSize == 36 then
                        b.iconSize = 40
                    end
                end
            end
            p.cdmBarPositions = p.cdmBarPositions or {}
            local pos = p.cdmBarPositions["cooldowns"]
            if not pos then
                p.cdmBarPositions["cooldowns"] = { point = "CENTER", relPoint = "UIParent", x = 0, y = -500 }
            else
                if pos.y == -450 or pos.y == -300 or pos.y == -250 then
                    pos.y = -500
                end
            end
            p.migratedCDM_v20 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v21 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "cooldowns" then
                    -- Si el usuario no lo ha movido claramente, baja el bloque por defecto
                    if b.anchorOffsetY == nil or b.anchorOffsetY > -500 then
                        b.anchorOffsetY = -500
                    end
                elseif b.key == "utility" then
                    -- Mantener 40px como default si venia con el valor viejo
                    if b.iconSize == nil or b.iconSize == 36 then
                        b.iconSize = 40
                    end
                end
            end
            p.cdmBarPositions = p.cdmBarPositions or {}
            local pos = p.cdmBarPositions["cooldowns"]
            if not pos then
                p.cdmBarPositions["cooldowns"] = { point = "CENTER", relPoint = "UIParent", x = 0, y = -500 }
            else
                if pos.y == nil or pos.y > -500 then
                    pos.y = -500
                end
            end
            p.migratedCDM_v21 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v22 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "cooldowns" then
                    -- Subir 150px respecto al ultimo ajuste por defecto
                    if b.anchorOffsetY == nil or b.anchorOffsetY <= -500 then
                        b.anchorOffsetY = -350
                    end
                end
            end
            p.cdmBarPositions = p.cdmBarPositions or {}
            local pos = p.cdmBarPositions["cooldowns"]
            if not pos then
                p.cdmBarPositions["cooldowns"] = { point = "CENTER", relPoint = "UIParent", x = 0, y = -350 }
            else
                if pos.y == nil or pos.y <= -500 then
                    pos.y = -350
                end
            end
            p.migratedCDM_v22 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v23 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "cooldowns" then
                    -- Subir 100px respecto al ajuste anterior
                    if b.anchorOffsetY == nil or b.anchorOffsetY <= -350 then
                        b.anchorOffsetY = -250
                    end
                elseif b.key == "utility" then
                    -- Icon size default 40px
                    if b.iconSize == nil or b.iconSize == 36 then
                        b.iconSize = 40
                    end
                end
            end
            p.cdmBarPositions = p.cdmBarPositions or {}
            local pos = p.cdmBarPositions["cooldowns"]
            if not pos then
                p.cdmBarPositions["cooldowns"] = { point = "CENTER", relPoint = "UIParent", x = 0, y = -250 }
            else
                if pos.y == nil or pos.y <= -350 then
                    pos.y = -250
                end
            end
            p.migratedCDM_v23 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v24 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "buffs" then
                    b.anchorTo = "castbar"
                    b.anchorPosition = "top"
                    b.anchorOffsetX = 0
                    b.anchorOffsetY = 4
                end
            end
            p.migratedCDM_v24 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v25 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.keybindSize == nil or b.keybindSize == 10 or b.keybindSize == 12 then
                    b.keybindSize = 13
                end
                if b.keybindOutline == nil then
                    b.keybindOutline = true
                end
            end
            p.migratedCDM_v25 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v26 then
            if p.cdmBars.barDefaults and p.cdmBars.barDefaults.activeStateAnim == nil then
                p.cdmBars.barDefaults.activeStateAnim = "blizzard"
            end
            for _, b in ipairs(p.cdmBars.bars) do
                if (b.key == "cooldowns" or b.key == "utility" or b.key == "buffs")
                    and b.activeStateAnim == nil then
                    b.activeStateAnim = "blizzard"
                end
            end
            p.migratedCDM_v26 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v30 then
            if p.cdmBars.barDefaults and (p.cdmBars.barDefaults.activeStateAnim == nil or p.cdmBars.barDefaults.activeStateAnim == "2") then
                p.cdmBars.barDefaults.activeStateAnim = "blizzard"
            end
            for _, b in ipairs(p.cdmBars.bars) do
                if b.activeStateAnim == nil or b.activeStateAnim == "2" then
                    b.activeStateAnim = "blizzard"
                end
            end
            p.migratedCDM_v30 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v27 then
            for _, b in ipairs(p.cdmBars.bars) do
                if (b.key == "utility" or b.key == "cooldowns") and b.showKeybind == nil then
                    b.showKeybind = false
                end
                if b.keybindSize == nil or b.keybindSize == 10 or b.keybindSize == 12 then
                    b.keybindSize = 13
                end
            end
            p.migratedCDM_v27 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v28 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "buffs" and (b.anchorTo == nil or b.anchorTo == "erb_powerbar") then
                    b.anchorTo = "castbar"
                    b.anchorPosition = "top"
                    b.anchorOffsetX = 0
                    if b.anchorOffsetY == nil or b.anchorOffsetY > 20 then
                        b.anchorOffsetY = 4
                    end
                end
            end
            p.migratedCDM_v28 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v29 then
            if p.cdmBars.barDefaults then
                if p.cdmBars.barDefaults.barStrata == nil then
                    p.cdmBars.barDefaults.barStrata = "MEDIUM"
                end
                if p.cdmBars.barDefaults.assistedCombatHighlight == nil then
                    p.cdmBars.barDefaults.assistedCombatHighlight = false
                end
                if p.cdmBars.barDefaults.buttonPressHighlight == nil then
                    p.cdmBars.barDefaults.buttonPressHighlight = false
                end
                if p.cdmBars.barDefaults.hideWhenMode == nil then
                    p.cdmBars.barDefaults.hideWhenMode = "ANY"
                end
                if p.cdmBars.barDefaults.hideWhen == nil then
                    p.cdmBars.barDefaults.hideWhen = {}
                end
            end
            for _, b in ipairs(p.cdmBars.bars) do
                if b.barStrata == nil then b.barStrata = "MEDIUM" end
                if b.assistedCombatHighlight == nil then b.assistedCombatHighlight = false end
                if b.buttonPressHighlight == nil then b.buttonPressHighlight = false end
                if b.hideWhenMode == nil then b.hideWhenMode = "ANY" end
                if b.hideWhen == nil then b.hideWhen = {} end
            end
            if p.cdmBars.useBlizzardDisplayDefaults == nil then
                p.cdmBars.useBlizzardDisplayDefaults = true
            end
            if p.cdmBars.promptBlizzardLayoutChanges == nil then
                p.cdmBars.promptBlizzardLayoutChanges = true
            end
            p.migratedCDM_v29 = true
        end

        -- Default layout tweak: Utility bar uses 2 rows (legacy default was 1).
        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v30 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "utility" and (b.numRows == nil or b.numRows == 1) then
                    b.numRows = 2
                end
            end
            p.migratedCDM_v30 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v31 then
            if p.cdmBars.barDefaults and (p.cdmBars.barDefaults.stackCountSize == nil or p.cdmBars.barDefaults.stackCountSize == 11) then
                p.cdmBars.barDefaults.stackCountSize = 12
            end
            for _, b in ipairs(p.cdmBars.bars) do
                if b.stackCountSize == nil or b.stackCountSize == 11 then
                    b.stackCountSize = 12
                end
            end
            p.migratedCDM_v31 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v32 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "utility"
                    and (b.iconSize == nil or b.iconSize == 33 or b.iconSize == 40)
                    and (b.numRows == nil or b.numRows == 2)
                    and (b.anchorTo == nil or b.anchorTo == "cooldowns")
                    and (b.anchorOffsetY == nil or b.anchorOffsetY == -2) then
                    b.iconSize = 25
                end
            end
            p.migratedCDM_v32 = true
        end

        if p and p.cdmBars and p.cdmBars.bars and not p.migratedCDM_v33 then
            for _, b in ipairs(p.cdmBars.bars) do
                if b.key == "utility"
                    and (b.iconSize == nil or b.iconSize == 25 or b.iconSize == 28)
                    and (b.numRows == nil or b.numRows == 2)
                    and (b.anchorTo == nil or b.anchorTo == "cooldowns")
                    and (b.anchorPosition == nil or b.anchorPosition == "bottom")
                    and (b.anchorOffsetY == nil or b.anchorOffsetY == -2) then
                    b.iconSize = 28
                end
            end
            p.migratedCDM_v33 = true
        end

        if p and not p.migratedCDM_v34 then
            if p.customTracker and p.customTracker.potion then
                if p.customTracker.potion.maxIcons == nil or p.customTracker.potion.maxIcons == 2 then
                    p.customTracker.potion.maxIcons = 3
                end
            end
            if p.cdmBars and p.cdmBars.bars then
                for _, b in ipairs(p.cdmBars.bars) do
                    if b.key == "kui_potion" then
                        if b.showKeybind == nil or b.showKeybind == false then
                            b.showKeybind = true
                        end
                        if b.maxIcons == nil or b.maxIcons == 2 then
                            b.maxIcons = 3
                        end
                    end
                end
            end
            p.migratedCDM_v34 = true
        end


        if p and not p.migratedCDM_v35 then
            if p.cdmBars and p.cdmBars.bars then
                for _, b in ipairs(p.cdmBars.bars) do
                    if b.key == "kui_trinket" then
                        if b.showKeybind == nil or b.showKeybind == false then
                            b.showKeybind = true
                        end
                    end
                end
            end
            p.migratedCDM_v35 = true
        end

        -- BuffIconCooldownViewer is a live effect pool: its children are the
        -- currently active buffs, not the complete configured catalog. Importing
        -- that pool into trackedSpells freezes a partial snapshot and makes
        -- later buffs disappear from the CDM. Keep the native mirror authoritative
        -- unless the user has explicitly added/removes/dormant entries.
        if p and not p.migratedCDM_v36 then
            local function ResetAutoImportedBuffList(b)
                if not (b and b.key == "buffs"
                    and type(b.trackedSpells) == "table"
                    and #b.trackedSpells > 0
                    and (type(b.extraSpells) ~= "table" or next(b.extraSpells) == nil)
                    and (type(b.removedSpells) ~= "table" or next(b.removedSpells) == nil)
                    and (type(b.dormantSpells) ~= "table" or next(b.dormantSpells) == nil))
                then
                    return
                end
                b.trackedSpells = nil
            end

            if p.cdmBars and p.cdmBars.bars and p.cdmBars.useBlizzardDisplayDefaults ~= false then
                for _, b in ipairs(p.cdmBars.bars) do
                    ResetAutoImportedBuffList(b)
                end
            end
            -- Spec profiles store the same captured list independently. Clear
            -- their auto-imported buffs too, otherwise a spec switch restores
            -- the stale snapshot immediately after this migration.
            for _, specProfile in pairs(p.specProfiles or {}) do
                local saved = specProfile and specProfile.barSpells and specProfile.barSpells.buffs
                if saved and p.cdmBars and p.cdmBars.useBlizzardDisplayDefaults ~= false then
                    ResetAutoImportedBuffList({
                        key = "buffs",
                        trackedSpells = saved.trackedSpells,
                        extraSpells = saved.extraSpells,
                        removedSpells = saved.removedSpells,
                        dormantSpells = saved.dormantSpells,
                    })
                    if type(saved.extraSpells) ~= "table" or next(saved.extraSpells) == nil then
                        if type(saved.removedSpells) ~= "table" or next(saved.removedSpells) == nil then
                            if type(saved.dormantSpells) ~= "table" or next(saved.dormantSpells) == nil then
                                saved.trackedSpells = nil
                            end
                        end
                    end
                end
            end
            p.migratedCDM_v36 = true
        end
        KUI_CDM._needsCapture = not KUI_CDM.db.profile._capturedOnce
        _G._KUI_CDM_AceDB = KUI_CDM.db
        _G._KUI_CDM_Apply = function()
            RequestUpdate()
            if ns.UpdateBuffBars then ns.UpdateBuffBars() end
            BuildAllCDMBars()
            if ns.BuildTrackedBuffBars then ns.BuildTrackedBuffBars() end
            local p = KUI_CDM.db.profile
            if p.activeSpecKey and p.activeSpecKey ~= "0" then
                SaveCurrentSpecProfile()
            end
        end
    elseif event == "PLAYER_LOGIN" then
        playerIdentity.race = select(2, UnitRace("player"))
        playerIdentity.class = select(2, UnitClass("player"))

        local profile = KUI_CDM and KUI_CDM.db and KUI_CDM.db.profile
        if profile and profile.cdmBars and profile.cdmBars.enabled and C_CVar and C_CVar.SetCVar then
            pcall(C_CVar.SetCVar, "cooldownViewerEnabled", "1")
        end



        local p = KUI_CDM.db.profile
        local oldSpecKey = p.activeSpecKey
        local newSpecKey = GetCurrentSpecKey()

        if newSpecKey ~= "0" and oldSpecKey and oldSpecKey ~= "0" and oldSpecKey ~= newSpecKey then
            SaveCurrentSpecProfile()
            p.activeSpecKey = newSpecKey
            GetOrCreateSpecState(p, newSpecKey)
            LoadSpecProfile(newSpecKey)
            _specValidated = true
        elseif newSpecKey ~= "0" then
            p.activeSpecKey = newSpecKey
            GetOrCreateSpecState(p, newSpecKey)
            _specValidated = true
        else
            _specValidated = false
        end

        EnsureMappings(GetStore())

        if ns.InitBarGlows then
            ns.InitBarGlows(KUI_CDM, ns.GetTargetButton, ns.GetActionButton, ns.GetSortedSlots,
                StartNativeGlow, StopNativeGlow)
        end
        if ns.InitBuffBars then ns.InitBuffBars(KUI_CDM) end
        blizzImport.HookPrompt()
        C_Timer.After(1, blizzImport.HookPrompt)
        C_Timer.After(3, blizzImport.HookPrompt)

        -- Do not build the hosted CDM here. On /reload PLAYER_LOGIN may fire
        -- before Blizzard has created/populated the CooldownViewer pools. A
        -- fresh profile happened to avoid that race because capture deferred
        -- its build to PLAYER_ENTERING_WORLD. Use that stable path every time.
        KUI_CDM._initialSetupPending = true

        if ns.ApplyPerSlotHidingAndPackSoon then ns.ApplyPerSlotHidingAndPackSoon() end
        RequestUpdate()
        if ns.UpdateBuffBars then ns.UpdateBuffBars() end

        HookProcAlertManager()
        ns.CDM_InstallButtonPressHighlightHook()
        C_Timer.After(1, HookProcAlertManager)
        C_Timer.After(1.5, RebuildSpellToCooldownID)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if KUI_CDM._initialSetupPending and not KUI_CDM._initialSetupComplete then
            ns.initFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
            if KUI_CDM._needsCapture then
                local captured = CaptureCDMPositions()
                local p = KUI_CDM.db.profile
                for _, barData in ipairs(p.cdmBars.bars) do
                    local cap = captured[barData.key]
                    if cap then
                        if cap.barScale then barData.barScale = cap.barScale end
                        if cap.iconSize and (barData.iconSize == nil or barData.iconSize == 0) then
                            barData.iconSize = cap.iconSize
                        end
                        if cap.spacing then barData.spacing = cap.spacing end
                        if cap.numRows then barData.numRows = cap.numRows end
                        if cap.isHorizontal ~= nil then
                            barData.growDirection = cap.isHorizontal and "RIGHT" or "DOWN"
                            barData.verticalOrientation = not cap.isHorizontal
                        end
                        if cap.point then
                            local scale = barData.barScale or 1.0
                            if scale < 0.1 then scale = 1.0 end
                            local existing = p.cdmBarPositions and p.cdmBarPositions[barData.key]
                            local allow = not existing or barData.key ~= "cooldowns"
                            if allow then
                                p.cdmBarPositions[barData.key] = {
                                    point = cap.point,
                                    relPoint = cap.relPoint,
                                    x = cap.x / scale,
                                    y = cap.y / scale,
                                }
                            end
                        end
                    end
                end
                p._capturedOnce = true
                KUI_CDM._needsCapture = false
            end

            KUI_CDM:CDMFinishSetup()
            KUI_CDM._initialSetupPending = false
            KUI_CDM._initialSetupComplete = true
        end
    end
end)

-------------------------------------------------------------------------------
--  Event frame for Runtime Updates
-------------------------------------------------------------------------------
ns.eventFrame = CreateFrame("Frame")

-- Edit Mode suppression monitor
ns.editModeSuppressor = CreateFrame("Frame")
ns.editModeSuppressor._elapsed = 0
ns.editModeSuppressor:SetScript("OnUpdate", function(self, elapsed)
    self._elapsed = (self._elapsed or 0) + elapsed
    if self._elapsed < 0.1 then return end
    self._elapsed = 0

    if not (KT and KT:IsBlizzardEditModeActive()) then
        self:Hide()
        return
    end

    for _, frameName in pairs(ns.BLIZZ_CDM_FRAMES) do
        local frame = _G[frameName]
        if frame and frame.Selection and frame.Selection:IsShown() then
            frame.Selection:Hide()
            frame.Selection:SetAlpha(0)
        end
    end
end)
ns.editModeSuppressor:Hide()

local function SyncEditModeSuppressor()
    local active = KT and KT.IsBlizzardEditModeActive and KT:IsBlizzardEditModeActive()
    if active then
        ns.editModeSuppressor._elapsed = 0
        ns.editModeSuppressor:Show()
    else
        ns.editModeSuppressor:Hide()
    end
end
ns.SyncEditModeSuppressor = SyncEditModeSuppressor

local function HookEditModeSuppressor()
    if ns._editModeSuppressorHooked then return end
    local manager = _G.EditModeManagerFrame
    if not (manager and manager.HookScript) then
        if C_Timer and C_Timer.After then C_Timer.After(1, HookEditModeSuppressor) end
        return
    end
    ns._editModeSuppressorHooked = true
    manager:HookScript("OnShow", SyncEditModeSuppressor)
    manager:HookScript("OnHide", SyncEditModeSuppressor)
    SyncEditModeSuppressor()
end
HookEditModeSuppressor()

ns.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(ns.eventFrame.RegisterEvent, ns.eventFrame, "COOLDOWN_VIEWER_DATA_LOADED")
pcall(ns.eventFrame.RegisterEvent, ns.eventFrame, "EDIT_MODE_LAYOUTS_UPDATED")
ns.eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ns.eventFrame:RegisterEvent("SPELLS_CHANGED")
ns.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
ns.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
ns.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
ns.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
ns.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ns.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
ns.eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
ns.eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
ns.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
ns.eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
ns.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
ns.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
ns.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
ns.eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
ns.eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
ns.eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
ns.eventFrame:RegisterEvent("UPDATE_STEALTH")
ns.eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
ns.eventFrame:RegisterEvent("PLAYER_DEAD")
ns.eventFrame:RegisterEvent("PLAYER_ALIVE")
ns.eventFrame:RegisterEvent("PLAYER_UNGHOST")
ns.eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
ns.eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
ns.eventFrame:RegisterEvent("PET_BATTLE_OPENING_START")
ns.eventFrame:RegisterEvent("PET_BATTLE_CLOSE")
ns.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
ns.eventFrame:RegisterEvent("PLAYER_LOGOUT")
ns.eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
ns.eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
ns.eventFrame:RegisterEvent("UPDATE_BINDINGS")
ns.eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ns.eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
ns.eventFrame:RegisterEvent("UPDATE_MACROS")
ns.eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ns.eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
ns.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
ns.eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
pcall(ns.eventFrame.RegisterUnitEvent, ns.eventFrame, "UNIT_INVENTORY_CHANGED", "player")
ns.eventFrame:RegisterEvent("ITEM_COUNT_CHANGED")
ns.eventFrame:RegisterEvent("ITEM_PUSH")
ns.eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
ns.eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
ns.eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ns.eventFrame:RegisterEvent("CINEMATIC_STOP")
ns.eventFrame:RegisterEvent("STOP_MOVIE")

pcall(ns.eventFrame.RegisterEvent, ns.eventFrame, 'GET_ITEM_INFO_RECEIVED')

function ns.TalentAwareReconcile()
    local p = KUI_CDM.db.profile
    if not p or not p.cdmBars or not p.cdmBars.bars then return end

    local known = BuildKnownSpellIDSet()

    for _, barData in ipairs(p.cdmBars.bars) do
        if TALENT_AWARE_BAR_TYPES[barData.barType] then
            -- 1. Tracked -> Dormant (Lost spells)
            if barData.trackedSpells then
                local i = 1
                while i <= #barData.trackedSpells do
                    local sid = barData.trackedSpells[i]
                    if sid and sid > 0 and not known[sid] then
                        if not barData.dormantSpells then barData.dormantSpells = {} end
                        local found = false
                        for _, d in ipairs(barData.dormantSpells) do
                            if d == sid then
                                found = true; break
                            end
                        end
                        if not found then
                            table.insert(barData.dormantSpells, sid)
                        end
                        table.remove(barData.trackedSpells, i)
                    else
                        i = i + 1
                    end
                end
            end

            -- 2. Dormant -> Tracked (Learned spells)
            if barData.dormantSpells then
                local i = 1
                while i <= #barData.dormantSpells do
                    local sid = barData.dormantSpells[i]
                    if sid and sid > 0 and known[sid] then
                        if not barData.trackedSpells then barData.trackedSpells = {} end
                        local found = false
                        for _, t in ipairs(barData.trackedSpells) do
                            if t == sid then
                                found = true; break
                            end
                        end
                        if not found then
                            table.insert(barData.trackedSpells, sid)
                        end
                        table.remove(barData.dormantSpells, i)
                    else
                        i = i + 1
                    end
                end
            end
        end
    end
    BuildAllCDMBars()
end

ns._talentRebuildToken = ns._talentRebuildToken or 0
function ns.ScheduleTalentRebuild()
    ns._talentRebuildToken = ns._talentRebuildToken + 1
    local token = ns._talentRebuildToken
    C_Timer.After(0.5, function()
        if token ~= ns._talentRebuildToken then return end
        wipe(_multiChargeSpells)
        wipe(_maxChargeCount)
        local db = KUI_CDM.db
        if db and db.global and db.global.multiChargeSpells then
            wipe(db.global.multiChargeSpells)
        end
        ns.TalentAwareReconcile()
        wipe(_spellIconCache)
        UpdateCDMKeybinds()
    end)
end

ns._unitAuraTimer = ns._unitAuraTimer or nil
ns._buffViewerAuraRefreshPending = ns._buffViewerAuraRefreshPending or false
ns.eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
    if not KUI_CDM.db then return end
    CDMRT:TrackEvent(event)
    if event == "COOLDOWN_VIEWER_DATA_LOADED" then
        -- Blizzard can finish creating/replacing viewer pools after the world
        -- entry pass. Attach hooks to any late objects and rebuild once against
        -- the now-complete native set.
        if ns.SetupNativeCDMViewerHooks then ns.SetupNativeCDMViewerHooks() end
        if not KUI_CDM._initialSetupComplete then return end
        InvalidateBlizzardViewerSnapshot()
        if InCombatLockdown and InCombatLockdown() then
            ns._transitionCDMRebuildPending = true
        else
            BuildAllCDMBars()
            if ns.BuildTrackedBuffBars then ns.BuildTrackedBuffBars() end
        end
        CDMRT:MarkDirty("cooldown_viewer_data_loaded")
        if ns.RunCDMUpdateIfIdle then ns.RunCDMUpdateIfIdle() end
        return
    end
    if event == 'UNIT_AURA' then
        -- The UNIT_AURA payload (and each of its fields) can arrive *secret* in
        -- restricted/instanced content, and a secret can never be boolean-tested
        -- or compared in Lua (a hard error, not a falsy read) -- this was
        -- throwing on every event and inflating CPU. Reading a secret into a
        -- local is always legal; only *testing* it errors. So bind the fields,
        -- issecretvalue-gate every use, and when unreadable assume duration/
        -- stack-only churn: skip the viewer refresh rather than rebuild on the
        -- off chance (pool hooks remain the primary composition signal). Same
        -- guard shape as EllesmereUI.
        local updateInfo = ...
        local compositionChanged = true
        if type(updateInfo) == "table" and issecretvalue and not issecretvalue(updateInfo) then
            local isFull = updateInfo.isFullUpdate
            local added = updateInfo.addedAuras
            local removed = updateInfo.removedAuraInstanceIDs
            local anySecret = (issecretvalue and (issecretvalue(isFull) or issecretvalue(added) or issecretvalue(removed))) or false
            if not anySecret then
                compositionChanged = isFull == true
                    or (type(added) == "table" and next(added) ~= nil)
                    or (type(removed) == "table" and next(removed) ~= nil)
            end
        end
        if not compositionChanged then
            return
        end
        if not ns._buffViewerAuraRefreshPending then
            ns._buffViewerAuraRefreshPending = true
            C_Timer.After(0.10, function()
                ns._buffViewerAuraRefreshPending = false
                if not KUI_CDM.db then return end
                local profiler = _G.KT and _G.KT.CombatProfiler
                local profileStarted = profiler and profiler:Begin("cdm.aura.viewer_refresh")
                -- Mark the buffs bar targeted-dirty for a paint pass. Do NOT
                -- invalidate the full viewer snapshot here: pool hooks
                -- (Acquire/Release/OnCooldownIDSet/OnActiveStateChanged) are the
                -- authoritative snapshot signal and already invalidate it. With
                -- aura churn in combat this previously forced a full re-enumeration
                -- of every Blizzard viewer child (plus a GetCooldownViewerCooldownInfo
                -- and full cache re-write per child) every 0.10s, which was the
                -- source of the 20-100ms spikes.
                CDMRT:MarkBarDirty('buffs', 'player_aura_composition', false)
                if ns.RunCDMUpdateIfIdle then
                    ns.RunCDMUpdateIfIdle()
                end
                if profileStarted then profiler:End("cdm.aura.viewer_refresh", profileStarted) end
            end)
        end
        return
    end
    if event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "EDIT_MODE_SYSTEMS_UPDATED" then
        local p = KUI_CDM.db and KUI_CDM.db.profile
        if p and p.cdmBars and p.cdmBars.hideBlizzard then
            if KT and KT:IsBlizzardEditModeActive() then
                if ns.DebugBlizzardCDMFrameState then
                    ns.DebugBlizzardCDMFrameState("EDIT_MODE_LAYOUTS_UPDATED")
                end
                for _, frameName in pairs(ns.BLIZZ_CDM_FRAMES) do
                    local frame = _G[frameName]
                    if frame then
                        SuppressBlizzardCDMEditModeFrame(frame)
                    end
                end
            end
            HideBlizzardCDM()
            if ns.CDMApplyVisibility then
                ns.CDMApplyVisibility()
            end
        end
        return
    end
    if event == 'GET_ITEM_INFO_RECEIVED' then
        if ns.InvalidatePotionTooltipCache then
            ns.InvalidatePotionTooltipCache(unit)
        end
        if type(unit) == "number" and not (issecretvalue and issecretvalue(unit)) then
            -- A previous lookup may have cached `false` while Blizzard was
            -- still loading this item. Refresh only this entry, and update the
            -- reverse index when the item is one we already track as owned.
            ns._itemSpellIDCache[unit] = nil
            if _syntheticTrackedItemCounts and _syntheticTrackedItemCounts[unit] then
                local itemSpellID = ns.CDMResolveItemSpellID and ns.CDMResolveItemSpellID(unit)
                if itemSpellID then
                    _syntheticSpellToItemCache[itemSpellID] = unit
                end
            end
        end
        if ns.ScheduleKUITrackerSync then
            ns.ScheduleKUITrackerSync(0.2)
        elseif ns.SyncKUITrackerBars then
            ns.SyncKUITrackerBars()
        end
        if ns.RequestCustomCooldownUpdate then
            ns.RequestCustomCooldownUpdate('item_info_received')
        end
        return
    end
    if event == 'PLAYER_TARGET_CHANGED'
        or event == 'PLAYER_DEAD'
        or event == 'PLAYER_ALIVE'
        or event == 'PLAYER_UNGHOST'
    then
        ns.ResetExecuteProcGlowState()
        if event == 'PLAYER_DEAD'
            or (event == 'PLAYER_TARGET_CHANGED' and not ns.CDMHasUsableTarget())
        then
            ns.ClearAllCDMGlowState()
        elseif event == 'PLAYER_TARGET_CHANGED' then
            ns.ReconcileCDMProcGlowsForTarget()
        end
        if ns.RefreshBarGlowRuntime then
            ns.RefreshBarGlowRuntime(false)
        end
    end
    if event == "PLAYER_LOGOUT" then
        local p = KUI_CDM.db.profile
        if p.activeSpecKey and p.activeSpecKey ~= "0" then
            SaveCurrentSpecProfile()
        end
        return
    end
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        -- Update event-driven Execute overlay state so GetSpellUsableInfo uses the correct value
        if _executeFamily[unit] then
            local wasActive = _executeOverlayActive
            _executeOverlayActive = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
            -- Invalidate the per-tick usable cache for all Execute IDs so the next tick
            -- immediately picks up the new state without waiting for cache expiry.
            if wasActive ~= _executeOverlayActive then
                for sid in pairs(_executeFamily) do
                    _tickUsableCache[sid] = nil
                end
            end
        end
        if not OnProcGlowEvent(event, unit) then
            CDMRT:MarkDirty("overlay_glow_miss", true)
        end
        return
    end
    if event == "ACTIONBAR_SLOT_CHANGED" then
        if ns.CDMDidActionSlotStateChange and not ns.CDMDidActionSlotStateChange(unit) then
            return
        end
        ns.ScheduleActionBarRefresh()
        return
    end
    if event == "UPDATE_BINDINGS" or event == "UPDATE_MACROS" then
        ns.ScheduleActionBarRefresh()
        return
    end
    if event == "SPELL_UPDATE_COOLDOWN"
        or event == "SPELL_UPDATE_CHARGES"
        or event == "ACTIONBAR_UPDATE_COOLDOWN"
        or event == "ITEM_COUNT_CHANGED"
        or event == "ITEM_PUSH"
    then
        if event == 'SPELL_UPDATE_COOLDOWN' and type(unit) == 'number'
            and not (issecretvalue and issecretvalue(unit))
            and GetFallbackItemCooldownDuration(unit)
            and ns.CDMResolveItemCooldownInfo
        then
            local itemStart, itemDuration = ns.CDMResolveItemCooldownInfo(unit)
            if itemStart and itemStart > 0 and itemDuration and itemDuration > 1.5 then
                StartSyntheticItemCooldown(unit, itemDuration, itemStart)
            end
        end
        RequestUpdate(event:lower())
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then
            return
        end
        if ns.ScheduleKUITrackerSync then
            ns.ScheduleKUITrackerSync(0.15)
        end
        RequestUpdate("equipment_changed")
        if ns.RequestCustomCooldownUpdate then
            ns.RequestCustomCooldownUpdate("equipment_changed")
        end
        return
    end
        if event == "BAG_UPDATE_DELAYED" then
        RequestUpdate("bag_update_delayed")
        local syntheticTriggered = ns.RefreshSyntheticItemCooldownsFromBags and ns.RefreshSyntheticItemCooldownsFromBags()
        if ns.ScheduleKUITrackerSync then
            ns.ScheduleKUITrackerSync(0.2)
        end
        if syntheticTriggered then
            RequestUpdate("synthetic_items")
        end
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        local _, spellID = ...
        -- Native viewers already receive the cooldown event.  Keep this dirty
        -- marker targeted so a normal cast can never force a full-bar pass.
        CDMRT:MarkDirty("player_spellcast_succeeded", true)
        RequestUpdate("player_spellcast_succeeded")
        if HandleSyntheticItemCooldownSpellcast(spellID) then
            if ns.ScheduleKUITrackerSync then
                ns.ScheduleKUITrackerSync(0.05, "synthetic_spellcast")
            end
            RequestUpdate("synthetic_spellcast")
        end
        -- Cast visibility is updated by START/STOP/CHANNEL events. SUCCEEDED
        -- does not change that state, so another complete visibility pass here
        -- only duplicated work after every ability.
        return
    end
    if event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
        CDMRT:MarkDirty("talent_config")
        ns.ScheduleTalentRebuild()
        return
    end
    if event == "GROUP_ROSTER_UPDATE" then
        -- A roster edge can change the party-frame anchor, but it does not
        -- change native cooldown state. Let Blizzard's pool/mixin hooks wake
        -- the affected CDM bar; do not invalidate or rescan every viewer.
        _cachedPartyFrame = nil
        _cachedPartyFrameRoster = 0
        _cachedPlayerFrame = nil
        _cachedPlayerFrameRoster = 0
        ns._rosterAnchorToken = (ns._rosterAnchorToken or 0) + 1
        local token = ns._rosterAnchorToken
        C_Timer.After(0.08, function()
            if token ~= ns._rosterAnchorToken then return end
            ns.CDMApplyVisibility()
            if ns.RequestAnchorPlayerFrameToCDM then ns.RequestAnchorPlayerFrameToCDM() end
        end)
        return
    end
    if event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
        CDMRT:MarkDirty("shapeshift_state", true)
        InvalidateBlizzardViewerSnapshot()
        if not InCombatLockdown() and ns.RefreshTBBResolvedIDs then
            ns.RefreshTBBResolvedIDs()
        end
        ns.CDMApplyVisibility()
        if ns.UpdateTrackedBuffBarTimers then
            ns.UpdateTrackedBuffBarTimers()
        end
        RequestUpdate("shapeshift_state")
        if ns.UpdateBuffBars then ns.UpdateBuffBars() end
        return
    end
    if event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
        CDMRT:MarkDirty("cinematic_state", true)
        local p = KUI_CDM.db and KUI_CDM.db.profile
        if p and p.cdmBars and p.cdmBars.hideBlizzard then
            C_Timer.After(0, function() HideBlizzardCDM() end)
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "ZONE_CHANGED_NEW_AREA" then
        local nextCombatState = (event == "PLAYER_REGEN_DISABLED")
        local combatStateChanged = _inCombat ~= nextCombatState
        if event == "ZONE_CHANGED_NEW_AREA" then
            CDMRT:MarkDirty("zone_changed", true)
        end
        _inCombat = nextCombatState
        _G.KUI_CDM_inCombat = _inCombat
        -- Native CDM widgets own their cooldown animation and composition.
        -- Combat transitions only need visibility; do not dirty/rebuild every
        -- tracked bar merely because PLAYER_REGEN_DISABLED fired.
        if combatStateChanged or event == "ZONE_CHANGED_NEW_AREA" then
            ns.CDMApplyVisibility()
        end
        if event == "ZONE_CHANGED_NEW_AREA" and ns.RunCDMUpdateIfIdle then
            ns.RunCDMUpdateIfIdle()
        end
        if event == "PLAYER_REGEN_ENABLED" and ns.IsTBBRebuildPending and ns.IsTBBRebuildPending() then
            ns.BuildTrackedBuffBars()
        end
        if event == "PLAYER_REGEN_ENABLED" and _keybindRebuildPending then
            UpdateCDMKeybinds()
        end
        if event == "PLAYER_REGEN_ENABLED" then
            if ns.FlushDeferredKUITrackerSync then
                ns.FlushDeferredKUITrackerSync()
            end
            if ns._transitionCDMRebuildPending and BuildAllCDMBars then
                ns._transitionCDMRebuildPending = nil
                -- Stagger the world-transition rebuild: BuildAllCDMBars is heavy
                -- (re-hooks every pooled child, layout, glow setup) and previously
                -- ran synchronously in the same frame as PartyFrames' own
                -- post-combat ApplyLayout, producing the single 200-500ms freeze
                -- visible on leaving combat.
                local token = ns._transitionRebuildToken or 0
                token = token + 1
                ns._transitionRebuildToken = token
                if not ns._transitionRebuildPending then
                    ns._transitionRebuildPending = true
                    C_Timer.After(0.04, function()
                        ns._transitionRebuildPending = false
                        if token ~= ns._transitionRebuildToken then return end
                        BuildAllCDMBars()
                        InvalidateBlizzardViewerSnapshot()
                        CDMRT:MarkDirty("deferred_world_transition_rebuild")
                        if ns.RunCDMUpdateIfIdle then ns.RunCDMUpdateIfIdle() end
                    end)
                end
            end
            ns.RebuildCdIDToCorrectSID()
            local secondary = _G.BuffBarCooldownViewer
            if secondary then
                ns.ParkSecondaryCDMViewer(secondary)
            end
            if _pendingPotionTrackerSecureRefresh and UpdateCDMBarIcons then
                _pendingPotionTrackerSecureRefresh = false
                if ns.RefreshCDMIconAppearance then
                    ns.RefreshCDMIconAppearance("kui_potion")
                end
                UpdateCDMBarIcons("kui_potion")
            end
            if ns.RefreshTBBResolvedIDs then ns.RefreshTBBResolvedIDs() end
            if ns._cdmLayoutPending then
                ns._cdmLayoutPending = false
                local profile = KUI_CDM.db and KUI_CDM.db.profile
                local bars = profile and profile.cdmBars and profile.cdmBars.bars
                if bars then
                    for _, pendingBar in ipairs(bars) do
                        if pendingBar.enabled and cdmBarFrames[pendingBar.key] then
                            LayoutCDMBar(pendingBar.key)
                        end
                    end
                end
                CDMRT:MarkDirty("regen_layout", true)
                if ns.RunCDMUpdateIfIdle then ns.RunCDMUpdateIfIdle() end
            end
            if ns._playerFrameAnchorPending and ns.RequestAnchorPlayerFrameToCDM then
                ns.RequestAnchorPlayerFrameToCDM()
            end
        end
        return
    end
    if event == "PLAYER_TARGET_CHANGED"
        or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "PLAYER_UPDATE_RESTING"
        or event == "UPDATE_STEALTH"
        or event == "PLAYER_FLAGS_CHANGED"
        or event == "PLAYER_DEAD"
        or event == "PLAYER_ALIVE"
        or event == "PLAYER_UNGHOST"
        or event == "PET_BATTLE_OPENING_START"
        or event == "PET_BATTLE_CLOSE"
    then
        CDMRT:MarkDirty("visibility_state", true)
        ns.CDMApplyVisibility()
        return
    end
    if (event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_CHANNEL_UPDATE")
        and unit == "player" then
        CDMRT:MarkDirty("player_cast_state", true)
        ns.CDMApplyVisibility()
        return
    end
    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and unit == "player" then
        CDMRT:MarkDirty("vehicle_state", true)
        ns.CDMApplyVisibility()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        CDMRT:MarkDirty("player_entering_world")
        if ns.ResetSyntheticItemCooldownObservation then
            ns.ResetSyntheticItemCooldownObservation()
        end
        _inCombat = InCombatLockdown and InCombatLockdown() or false
        _G.KUI_CDM_inCombat = _inCombat
        -- ZONE_CHANGED_NEW_AREA may have hidden the bars while IsInInstance()
        -- still described the arena being left. PLAYER_ENTERING_WORLD is the
        -- authoritative point at which to restore their current-world state.
        HideBlizzardCDM()
        ns.CDMApplyVisibility()
        InvalidateBlizzardViewerSnapshot()
        if ns.RunCDMUpdateIfIdle then ns.RunCDMUpdateIfIdle() end
        ns.ScheduleLateCDMRefreshes()
        C_Timer.After(0.5, function()
            if ns.RefreshSyntheticItemCooldownsFromBags then
                ns.RefreshSyntheticItemCooldownsFromBags()
            end
            ns.RebuildCdIDToCorrectSID()
            ValidateSpec()
            if not _specValidated then return end
            local newSpecKey = GetCurrentSpecKey()
            local p = KUI_CDM.db and KUI_CDM.db.profile
            if p and newSpecKey == p.activeSpecKey then
                InvalidateBlizzardViewerSnapshot()
                CDMRT:MarkDirty("player_entering_world")
                RequestUpdate("player_entering_world")
            end
        end)
    end
    if event == "SPELLS_CHANGED" then
        local inCombat = InCombatLockdown and InCombatLockdown() or false
        -- In combat this event can fire periodically without a real loadout
        -- change. Do not let it force a full pass over every bar.
        CDMRT:MarkDirty("spells_changed", inCombat)
        if not inCombat then
            ns.RebuildCdIDToCorrectSID()
        end
        if ns.ScheduleKUITrackerSync then
            -- Only interrupt/defensive depend on the spellbook. Potion and
            -- trinket detection is intentionally excluded from this path.
            ns.ScheduleKUITrackerSync(0.20, "spells_changed", "spells")
        end
        if not _specValidated then
            ValidateSpec()
            if _specValidated then
                QueueCDMRebuild(0.3, "spells_changed")
            end
        end
        RequestUpdate("spells_changed")
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player" then
        CDMRT:MarkDirty("player_specialization_changed")
        _cachedPlayerFrame = nil
        _cachedPlayerFrameRoster = 0
        local newSpecKey = GetCurrentSpecKey()
        local p = KUI_CDM.db.profile
        if newSpecKey ~= "0" and newSpecKey ~= p.activeSpecKey then
            SwitchSpecProfile(newSpecKey)
            _specValidated = true
        elseif newSpecKey ~= "0" then
            p.activeSpecKey = newSpecKey
            GetOrCreateSpecState(p, newSpecKey)
            _specValidated = true
            QueueCDMRebuild(0.5, "player_specialization_changed")
        end
    end
    if event == "SPELL_UPDATE_COOLDOWN"
        or event == "BAG_UPDATE_DELAYED"
        or event == "ITEM_COUNT_CHANGED"
        or event == "ITEM_PUSH"
    then
        return
    end
    if ns.ApplyPerSlotHidingAndPackSoon then ns.ApplyPerSlotHidingAndPackSoon() end
    RequestUpdate(event and event:lower() or "event")
    if ns.UpdateBuffBars then ns.UpdateBuffBars() end
end)

-- Attribute the complete event callback, including paths that return early.
-- Individual hot sections remain instrumented separately for finer detail.
do
    local eventHandler = ns.eventFrame:GetScript("OnEvent")
    local eventLabels = {}
    ns.eventFrame:SetScript("OnEvent", function(frame, event, ...)
        local profiler = _G.KT and _G.KT.CombatProfiler
        local label, profileStarted
        if profiler and profiler.capturing then
            label = eventLabels[event]
            if not label then
                label = "cdm.event." .. tostring(event)
                eventLabels[event] = label
            end
            profileStarted = profiler:Begin(label)
        end
        eventHandler(frame, event, ...)
        if profileStarted then profiler:End(label, profileStarted) end
    end)
end

-------------------------------------------------------------------------------
--  Slash commands
-------------------------------------------------------------------------------
SLASH_KUI_CDM1 = "/kcdm"
SLASH_KUI_CDM2 = "/cdmeffects"
SLASH_KUI_CDM3 = "/cdm"
SlashCmdList.KUI_CDMKEYBINDS = function(msg)
    local filter = strtrim(msg or "")
    local filterLower = filter ~= "" and strlower(filter) or nil
    _G.KUI_CDM_DebugLog = {}
    local p = function(...)
        local parts = { "|cff66ccff[CDM Keybinds]|r" }
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        local line = table.concat(parts, " ")
        _G.KUI_CDM_DebugLog[#_G.KUI_CDM_DebugLog + 1] = line
        local chatModule = KT and KT.GetModule and KT:GetModule("Chat", true)
        if chatModule and chatModule.SendMessageToChat then
            chatModule:SendMessageToChat(line, 0.4, 0.8, 1)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(line)
        elseif ChatFrame1 and ChatFrame1.AddMessage then
            ChatFrame1:AddMessage(line)
        elseif UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(line, 0.4, 0.8, 1)
        end
    end

    local function MatchesText(value)
        return not filterLower or (type(value) == "string" and string.find(strlower(value), filterLower, 1, true) ~= nil)
    end

    local function MatchesKey(rawKey)
        if not filterLower then
            return true
        end
        local formatted = ns.NormalizeBindingLabel(rawKey)
        return MatchesText(rawKey) or MatchesText(formatted)
    end

    local function MatchesSpell(spellID)
        if not filterLower then
            return true
        end
        if tostring(spellID) == filterLower then
            return true
        end
        local name = spellID and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        return MatchesText(name)
    end

    UpdateCDMKeybinds()
    p("Filter:", filter ~= "" and filter or "<none>")

    p("Cache matches:")
    for key, bind in pairs(_cdmKeybindCache) do
        if type(key) == "number" and (MatchesSpell(key) or MatchesKey(bind)) then
            local name = C_Spell.GetSpellName and C_Spell.GetSpellName(key) or "?"
            p(" cache", tostring(key), tostring(name), "=>", tostring(bind))
        end
    end

    p("Action slot matches:")
    for _, def in ipairs(ns._barBindingDefs) do
        for offset = 0, 11 do
            local slot = def.startSlot + offset
            local commandName = def.prefix .. (offset + 1)
            local rawKey = GetBindingKey(commandName)
            local formatted = ns.NormalizeBindingLabel(rawKey)
            if formatted and MatchesKey(rawKey) then
                local candidateSlots = ns.GetCandidateSlotsForBindingCommand(commandName, slot)
                for _, candidateSlot in ipairs(candidateSlots or {}) do
                    local actionType, actionID, subType = GetActionInfo(candidateSlot)
                    if actionType == "spell" and MatchesSpell(actionID) then
                        local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(actionID) or "?"
                        p(" slot", tostring(candidateSlot), formatted, tostring(commandName), "spell", tostring(actionID),
                            tostring(spellName))
                    elseif actionType == "macro" and subType == "spell" and MatchesSpell(actionID) then
                        local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(actionID) or "?"
                        p(" slot", tostring(candidateSlot), formatted, tostring(commandName), "macro-spell", tostring(actionID),
                            tostring(spellName))
                    elseif actionType == "macro" and actionID then
                        local macroName, _, macroBody = GetMacroInfo(actionID)
                        local macroSpell = GetMacroSpell(actionID)
                        local show = MatchesText(macroName) or MatchesText(macroBody) or MatchesSpell(macroSpell)
                        if show then
                            local macroSpellName = macroSpell and C_Spell.GetSpellName and C_Spell.GetSpellName(macroSpell) or "?"
                            p(" slot", tostring(candidateSlot), formatted, tostring(commandName), "macro", tostring(actionID),
                                tostring(macroName), "macroSpell=", tostring(macroSpell), tostring(macroSpellName))
                            if type(macroBody) == "string" and macroBody ~= "" then
                                p("  body:", macroBody)
                            end
                        end
                    end
                end
            end
        end
    end

    p("All slot matches:")
    for slot = 1, 180 do
        local actionType, actionID, subType = GetActionInfo(slot)
        if actionType == "spell" and MatchesSpell(actionID) then
            local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(actionID) or "?"
            p(" allslot", tostring(slot), "spell", tostring(actionID), tostring(spellName))
        elseif actionType == "macro" and subType == "spell" and MatchesSpell(actionID) then
            local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(actionID) or "?"
            p(" allslot", tostring(slot), "macro-spell", tostring(actionID), tostring(spellName))
        elseif actionType == "macro" and actionID then
            local macroName, _, macroBody = GetMacroInfo(actionID)
            local macroSpell = GetMacroSpell(actionID)
            local show = MatchesText(macroName) or MatchesText(macroBody) or MatchesSpell(macroSpell)
            if show then
                local macroSpellName = macroSpell and C_Spell.GetSpellName and C_Spell.GetSpellName(macroSpell) or "?"
                p(" allslot", tostring(slot), "macro", tostring(actionID), tostring(macroName), "macroSpell=",
                    tostring(macroSpell), tostring(macroSpellName))
                if type(macroBody) == "string" and macroBody ~= "" then
                    p("  body:", macroBody)
                end
            end
        end
    end

    p("Visible button matches:")
    local function DebugButton(button)
        if not button then
            return
        end

        local slot = button.action or button._state_action or (button.GetAttribute and button:GetAttribute("action"))
        local rawKey
        if button.HotKey then
            rawKey = button.HotKey:GetText()
            if rawKey == RANGE_INDICATOR then
                rawKey = nil
            end
        end
        if not rawKey and button.commandName then
            rawKey = GetBindingKey(button.commandName)
        end
        if not rawKey and button.config and button.config.keyBoundTarget then
            rawKey = GetBindingKey(button.config.keyBoundTarget)
        end
        if not rawKey and button.GetName then
            local name = button:GetName()
            if type(name) == "string" then
                local mappings = {
                    { "^ActionButton(%d+)$", "ACTIONBUTTON%s" },
                    { "^MultiBarBottomLeftButton(%d+)$", "MULTIACTIONBAR1BUTTON%s" },
                    { "^MultiBarBottomRightButton(%d+)$", "MULTIACTIONBAR2BUTTON%s" },
                    { "^MultiBarRightButton(%d+)$", "MULTIACTIONBAR3BUTTON%s" },
                    { "^MultiBarLeftButton(%d+)$", "MULTIACTIONBAR4BUTTON%s" },
                    { "^MultiBar5Button(%d+)$", "MULTIACTIONBAR5BUTTON%s" },
                    { "^MultiBar6Button(%d+)$", "MULTIACTIONBAR6BUTTON%s" },
                    { "^MultiBar7Button(%d+)$", "MULTIACTIONBAR7BUTTON%s" },
                }
                for _, mapping in ipairs(mappings) do
                    local index = name:match(mapping[1])
                    if index then
                        rawKey = GetBindingKey(format(mapping[2], index))
                        if rawKey then
                            break
                        end
                    end
                end
            end
        end

        local formatted = ns.NormalizeBindingLabel(rawKey)
        local actionType, actionID, subType
        if slot then
            actionType, actionID, subType = GetActionInfo(slot)
        end
        if actionType == "spell" and (MatchesSpell(actionID) or MatchesKey(rawKey)) then
            local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(actionID) or "?"
            p(" button", button:GetName() or "?", "slot=", tostring(slot), "key=", tostring(formatted), "spell=",
                tostring(actionID), tostring(spellName))
        elseif actionType == "macro" and subType == "spell" and (MatchesSpell(actionID) or MatchesKey(rawKey)) then
            local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(actionID) or "?"
            p(" button", button:GetName() or "?", "slot=", tostring(slot), "key=", tostring(formatted), "macro-spell=",
                tostring(actionID), tostring(spellName))
        elseif actionType == "macro" and actionID then
            local macroName, _, macroBody = GetMacroInfo(actionID)
            local macroSpell = GetMacroSpell(actionID)
            local show = MatchesText(macroName) or MatchesText(macroBody) or MatchesSpell(macroSpell) or MatchesKey(rawKey)
            if show then
                local macroSpellName = macroSpell and C_Spell.GetSpellName and C_Spell.GetSpellName(macroSpell) or "?"
                p(" button", button:GetName() or "?", "slot=", tostring(slot), "key=", tostring(formatted), "macro=",
                    tostring(actionID), tostring(macroName), "macroSpell=", tostring(macroSpell), tostring(macroSpellName))
                if type(macroBody) == "string" and macroBody ~= "" then
                    p("  body:", macroBody)
                end
            end
        end
    end

    local blizzBars = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
    }
    for _, prefix in ipairs(blizzBars) do
        for i = 1, 12 do
            DebugButton(_G[prefix .. i])
        end
    end
    if _G["DominosActionButton1"] then
        for i = 1, 180 do
            DebugButton(_G["DominosActionButton" .. i])
        end
    end
    if _G["BT4Button1"] then
        for i = 1, 180 do
            DebugButton(_G["BT4Button" .. i])
        end
    end
    if _G["ElvUI_Bar1Button1"] then
        for barIdx = 1, 15 do
            for btnIdx = 1, 12 do
                DebugButton(_G["ElvUI_Bar" .. barIdx .. "Button" .. btnIdx])
            end
        end
    end
    p("Direct binding matches:")
    if GetNumBindings and GetBinding then
        for bindingIndex = 1, GetNumBindings() do
            local command, key1, key2 = GetBinding(bindingIndex)
            if type(command) == "string" and (key1 or key2) then
                local macroName = command:match("^MACRO%s+(.+)$")
                local spellToken = command:match("^SPELL%s+(.+)$")
                if macroName and (MatchesText(macroName) or MatchesKey(key1) or MatchesKey(key2)) then
                    p(" direct", tostring(ns.NormalizeBindingLabel(key1 or key2)), tostring(command))
                elseif spellToken then
                    local spellID = (ns.ResolveSpellIDFromSpellToken and ns.ResolveSpellIDFromSpellToken(spellToken))
                        or tonumber(spellToken)
                        or tonumber(spellToken:match("^spell:(%d+)$"))
                    if MatchesSpell(spellID) or MatchesKey(key1) or MatchesKey(key2) then
                        local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or spellToken
                        p(" direct", tostring(ns.NormalizeBindingLabel(key1 or key2)), tostring(command), tostring(spellID),
                            tostring(spellName))
                    end
                end
            end
        end
    end
    p("Click binding matches:")
    if GetNumBindings and GetBinding then
        for bindingIndex = 1, GetNumBindings() do
            local command, key1, key2 = GetBinding(bindingIndex)
            if type(command) == "string" and command:find("^CLICK ") then
                                local bindingTarget = command:match("^CLICK%s+(.+)$")
                local buttonName = bindingTarget
                local targetButton = bindingTarget and _G[bindingTarget] or nil
                if not targetButton and type(bindingTarget) == "string" then
                    local candidateName = bindingTarget
                    while candidateName and candidateName ~= "" do
                        candidateName = candidateName:match("^(.*):[^:]+$")
                        if candidateName and candidateName ~= "" then
                            targetButton = _G[candidateName]
                            if targetButton then
                                buttonName = candidateName
                                break
                            end
                        end
                    end
                end
                if targetButton then
                    local slot = targetButton.action or targetButton._state_action or (targetButton.GetAttribute and targetButton:GetAttribute("action"))
                    local actionType, actionID, subType
                    if slot then
                        actionType, actionID, subType = GetActionInfo(slot)
                    end
                    local rawKey = key1 or key2
                    local formatted = ns.NormalizeBindingLabel(rawKey)
                    if actionType == "spell" and (MatchesSpell(actionID) or MatchesKey(rawKey)) then
                        local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(actionID) or "?"
                        p(" click", tostring(formatted), tostring(command), "button=", tostring(buttonName), "slot=",
                            tostring(slot), "spell=", tostring(actionID), tostring(spellName))
                    elseif actionType == "macro" and subType == "spell" and (MatchesSpell(actionID) or MatchesKey(rawKey)) then
                        local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(actionID) or "?"
                        p(" click", tostring(formatted), tostring(command), "button=", tostring(buttonName), "slot=",
                            tostring(slot), "macro-spell=", tostring(actionID), tostring(spellName))
                    elseif actionType == "macro" and actionID then
                        local macroName, _, macroBody = GetMacroInfo(actionID)
                        local macroSpell = GetMacroSpell(actionID)
                        local show = MatchesText(macroName) or MatchesText(macroBody) or MatchesSpell(macroSpell) or MatchesKey(rawKey)
                        if show then
                            local macroSpellName = macroSpell and C_Spell.GetSpellName and C_Spell.GetSpellName(macroSpell) or "?"
                            p(" click", tostring(formatted), tostring(command), "button=", tostring(buttonName), "slot=",
                                tostring(slot), "macro=", tostring(actionID), tostring(macroName), "macroSpell=",
                                tostring(macroSpell), tostring(macroSpellName))
                            if type(macroBody) == "string" and macroBody ~= "" then
                                p("  body:", macroBody)
                            end
                        end
                    end
                end
            end
        end
    end
    local seenDebugButtons = {}
    local frame = EnumerateFrames and EnumerateFrames()
    while frame do
        if not seenDebugButtons[frame]
            and frame.IsObjectType
            and (frame:IsObjectType("CheckButton") or frame:IsObjectType("Button"))
        then
            local hasAction = rawget(frame, "action") ~= nil
                or rawget(frame, "_state_action") ~= nil
                or (frame.GetAttribute and (frame:GetAttribute("action") ~= nil or frame:GetAttribute("macrotext") ~= nil
                    or frame:GetAttribute("macrotext1") ~= nil))
            local frameConfig = rawget(frame, "config")
            local hasBindingHint = rawget(frame, "HotKey") ~= nil or rawget(frame, "commandName") ~= nil
                or (frameConfig and rawget(frameConfig, "keyBoundTarget") ~= nil)
            if hasAction and hasBindingHint then
                seenDebugButtons[frame] = true
                DebugButton(frame)
            end
        end
        frame = EnumerateFrames(frame)
    end

    p("Visible icon matches:")
    for barKey, icons in pairs(cdmBarIcons) do
        for _, icon in ipairs(icons) do
            if icon._spellID and MatchesSpell(icon._spellID) then
                local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(icon._spellID) or "?"
                local bind = ns.FindCachedKeybind(icon._spellID, icon._baseSpellID)
                p(" icon", tostring(barKey), "spell=", tostring(icon._spellID), tostring(spellName), "base=",
                    tostring(icon._baseSpellID), "bind=", tostring(bind))
            end
        end
    end
end

SlashCmdList.KUI_CDM = function(msg)
    local lowerMsg = strtrim(msg or "")
    if lowerMsg ~= "" then
        local cmd, rest = lowerMsg:match("^(%S+)%s*(.-)$")
        cmd = cmd and strlower(cmd)
        if cmd == "keybinds" or cmd == "kb" then
            SlashCmdList.KUI_CDMKEYBINDS(rest)
            return
        elseif cmd == "perf" and SlashCmdList.KUI_CDMPERF then
            SlashCmdList.KUI_CDMPERF(rest)
            return
        elseif cmd == "debug" and SlashCmdList.KUI_CDMDEBUG then
            SlashCmdList.KUI_CDMDEBUG(rest)
            return
        end
    end
    if InCombatLockdown and InCombatLockdown() then return end
    if KT and KT.ShowModule then
        KT:ShowModule("KUICooldownManager")
    end
end

function ns.CDMEnsureDebugWindow()
    if ns._cdmDebugWindow and ns._cdmDebugWindow._editBox then
        return ns._cdmDebugWindow
    end

    local frame = CreateFrame("Frame", "KUI_CDM_DebugWindow", UIParent, "BackdropTemplate")
    frame:SetSize(900, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)

    frame._title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame._title:SetPoint("TOPLEFT", 14, -12)
    frame._title:SetText(LText("KUI CDM Debug"))

    frame._close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame._close:SetPoint("TOPRIGHT", -6, -6)
    frame:HookScript("OnHide", function()
        -- Closing the diagnostics window must also stop high-volume glow
        -- tracing; performance captures can still use the same window.
        ns._cdmGlowDebugEnabled = false
    end)

    frame._clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame._clear:SetSize(68, 22)
    frame._clear:SetPoint("TOPRIGHT", frame._close, "TOPLEFT", -8, -2)
    frame._clear:SetText(LText("Clear"))
    frame._clear:SetScript("OnClick", function()
        _G.KUI_CDM_DebugLog = {}
        if ns.CDMRenderDebugWindow then ns.CDMRenderDebugWindow() end
    end)

    frame._scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame._scrollFrame:SetPoint("TOPLEFT", 12, -40)
    frame._scrollFrame:SetPoint("BOTTOMRIGHT", -30, 12)

    frame._editBox = CreateFrame("EditBox", nil, frame._scrollFrame)
    frame._editBox:SetMultiLine(true)
    frame._editBox:SetAutoFocus(false)
    frame._editBox:SetFontObject(ChatFontNormal)
    frame._editBox:SetWidth(840)
    frame._editBox:SetScript("OnEscapePressed", function(self)
        local p = self:GetParent()
        local owner = p and p:GetParent()
        if owner then owner:Hide() end
    end)
    frame._scrollFrame:SetScrollChild(frame._editBox)

    frame:Hide()
    ns._cdmDebugWindow = frame
    return frame
end

function ns.CDMRenderDebugWindow()
    local frame = ns.CDMEnsureDebugWindow and ns.CDMEnsureDebugWindow()
    if not (frame and frame._editBox and frame._scrollFrame) then
        return
    end

    local lines = _G.KUI_CDM_DebugLog or {}
    frame._editBox:SetText(table.concat(lines, "\n"))
    frame._editBox:HighlightText(0, 0)
    frame._scrollFrame:UpdateScrollChildRect()
    local maxScroll = math.max(0, frame._editBox:GetHeight() - frame._scrollFrame:GetHeight())
    frame._scrollFrame:SetVerticalScroll(maxScroll)
end

function ns.CDMOpenDebugWindow()
    local frame = ns.CDMEnsureDebugWindow and ns.CDMEnsureDebugWindow()
    if not frame then
        return
    end
    frame:Show()
    if ns.CDMRenderDebugWindow then ns.CDMRenderDebugWindow() end
end

function ns.CDMPerfPrint(...)
    if type(_G.KUI_CDM_DebugLog) ~= "table" then
        _G.KUI_CDM_DebugLog = {}
    end

    local parts = { "[CDM Perf]" }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    local log = _G.KUI_CDM_DebugLog
    log[#log + 1] = table.concat(parts, " ")

    if #log > 1500 then
        local compacted = {}
        local first = math.max(1, #log - 999)
        for i = first, #log do
            compacted[#compacted + 1] = log[i]
        end
        _G.KUI_CDM_DebugLog = compacted
    end

    if ns._cdmDebugWindow and ns._cdmDebugWindow:IsShown() and ns.CDMRenderDebugWindow then
        ns.CDMRenderDebugWindow()
    end
end

function ns.CDMPerfWipeTable(t)
    if type(t) == "table" then
        wipe(t)
    end
end

local function CDMPerfGetAddonCPULegacy()
    if not _G.GetAddOnCPUUsage then
        return nil
    end
    local scriptProfileEnabled = false
    if type(_G.IsScriptProfilingEnabled) == "function" then
        local ok, enabled = pcall(_G.IsScriptProfilingEnabled)
        if ok then scriptProfileEnabled = enabled and true or false end
    end
    if not scriptProfileEnabled and _G.GetCVar then
        scriptProfileEnabled = tostring(_G.GetCVar("scriptProfile")) == "1"
    end
    -- UpdateAddOnCPUUsage() is a synchronous global rescan and can take tens
    -- of milliseconds even while legacy script profiling is disabled. Never
    -- invoke it unless its counters are actually enabled.
    if not scriptProfileEnabled then
        return nil
    end
    if _G.UpdateAddOnCPUUsage then
        _G.UpdateAddOnCPUUsage()
    end

    local cached = ns._cdmPerfAddonCPUHandle
    if cached and cached.index then
        local ok, cpu = pcall(_G.GetAddOnCPUUsage, cached.index)
        if ok and cpu ~= nil then
            return cpu
        end
    end

    local candidates = {
        tostring(ADDON_NAME or ""),
        "KullThranUI_CooldownManager",
        "KullThranUI - Cooldown Manager",
    }

    local function NormalizeCAddOnInfo(raw1, raw2, raw3, ...)
        if type(raw1) == "table" then
            return raw1.name, raw1.title or raw1.Title or raw1.label or raw1.notes
        end
        return raw1, raw2 or raw3
    end

    local function TryCandidate(index, name, title)
        for c = 1, #candidates do
            local candidate = candidates[c]
            if candidate ~= "" and (name == candidate or title == candidate) then
                local cpuByIndex = _G.GetAddOnCPUUsage(index)
                local cpuByName = name and _G.GetAddOnCPUUsage(name) or nil
                ns._cdmPerfAddonCPUHandle = { index = index, name = name, title = title }
                if cpuByName ~= nil and cpuByName ~= cpuByIndex then
                    return cpuByName
                end
                return cpuByIndex
            end
        end
        return nil
    end

    local count = _G.GetNumAddOns and _G.GetNumAddOns() or 0
    if count > 0 and _G.GetAddOnInfo then
        for i = 1, count do
            local name, title = _G.GetAddOnInfo(i)
            local cpu = TryCandidate(i, name, title)
            if cpu ~= nil then
                return cpu
            end
        end
        for i = 1, count do
            local name, title = _G.GetAddOnInfo(i)
            local haystack = string.lower(tostring(name or "") .. " " .. tostring(title or ""))
            if haystack:find("kullthranui", 1, true) and haystack:find("cooldown", 1, true) then
                ns._cdmPerfAddonCPUHandle = { index = i, name = name, title = title }
                return _G.GetAddOnCPUUsage(i)
            end
        end
    end

    if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
        local cCount = C_AddOns.GetNumAddOns() or 0
        for i = 1, cCount do
            local name, title = NormalizeCAddOnInfo(C_AddOns.GetAddOnInfo(i))
            if (not title or title == "") and C_AddOns.GetAddOnMetadata then
                title = C_AddOns.GetAddOnMetadata(i, "Title")
            end
            local cpu = TryCandidate(i, name, title)
            if cpu ~= nil then
                return cpu
            end
        end
        for i = 1, cCount do
            local name, title = NormalizeCAddOnInfo(C_AddOns.GetAddOnInfo(i))
            if (not title or title == "") and C_AddOns.GetAddOnMetadata then
                title = C_AddOns.GetAddOnMetadata(i, "Title")
            end
            local haystack = string.lower(tostring(name or "") .. " " .. tostring(title or ""))
            if haystack:find("kullthranui", 1, true) and haystack:find("cooldown", 1, true) then
                ns._cdmPerfAddonCPUHandle = { index = i, name = name, title = title }
                return _G.GetAddOnCPUUsage(i)
            end
        end
    end

    local ok, cpu = pcall(_G.GetAddOnCPUUsage, ADDON_NAME)
    if ok and cpu ~= nil then
        ns._cdmPerfAddonCPUHandle = { index = ADDON_NAME, name = ADDON_NAME, title = ADDON_NAME }
        return cpu
    end

    return nil
end

function ns.CDMPerfGetAddonCPU()
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("cdm.perf.legacy_cpu")
    local cpu = CDMPerfGetAddonCPULegacy()
    if profileStarted then profiler:End("cdm.perf.legacy_cpu", profileStarted) end
    return cpu
end

function ns.CDMPerfPrintCPUInfo()
    local resolvedCpu = ns.CDMPerfGetAddonCPU and ns.CDMPerfGetAddonCPU() or nil

    ns.CDMPerfPrint("CPU info:")
    ns.CDMPerfPrint(" addon chunk=", tostring(ADDON_NAME))
    ns.CDMPerfPrint(" scriptProfile=", tostring(_G.GetCVar and _G.GetCVar("scriptProfile")))
    ns.CDMPerfPrint(" resolved cpu=", tostring(resolvedCpu))

    local function NormalizeCAddOnInfo(raw1, raw2, raw3, ...)
        if type(raw1) == "table" then
            return raw1.name, raw1.title or raw1.Title or raw1.label or raw1.notes
        end
        return raw1, raw2 or raw3
    end

    local count = _G.GetNumAddOns and _G.GetNumAddOns() or 0
    ns.CDMPerfPrint(" GetNumAddOns=", tostring(count))
    for i = 1, count do
        local name, title = _G.GetAddOnInfo(i)
        local haystack = string.lower(tostring(name or "") .. " " .. tostring(title or ""))
        if haystack:find("kullthranui", 1, true) or haystack:find("cooldown", 1, true) then
            local cpu = _G.GetAddOnCPUUsage and _G.GetAddOnCPUUsage(i)
            local cpuByName = name and _G.GetAddOnCPUUsage and _G.GetAddOnCPUUsage(name) or nil
            ns.CDMPerfPrint(string.format(" - #%d name=%s title=%s cpu=%s cpuByName=%s", i, tostring(name), tostring(title), tostring(cpu), tostring(cpuByName)))
        end
    end

    if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
        local cCount = C_AddOns.GetNumAddOns() or 0
        ns.CDMPerfPrint(" C_AddOns.GetNumAddOns=", tostring(cCount))
        for i = 1, cCount do
            local name, title = NormalizeCAddOnInfo(C_AddOns.GetAddOnInfo(i))
            if (not title or title == "") and C_AddOns.GetAddOnMetadata then
                title = C_AddOns.GetAddOnMetadata(i, "Title")
            end
            local haystack = string.lower(tostring(name or "") .. " " .. tostring(title or ""))
            if haystack:find("kullthranui", 1, true) or haystack:find("cooldown", 1, true) then
                local cpu = _G.GetAddOnCPUUsage and _G.GetAddOnCPUUsage(i)
                local cpuByName = name and _G.GetAddOnCPUUsage and _G.GetAddOnCPUUsage(name) or nil
                ns.CDMPerfPrint(string.format(" - C#%d name=%s title=%s cpu=%s cpuByName=%s", i, tostring(name), tostring(title), tostring(cpu), tostring(cpuByName)))
            end
        end
    end

    local handle = ns._cdmPerfAddonCPUHandle
    if handle then
        ns.CDMPerfPrint(string.format(" resolved handle: %s / %s / %s", tostring(handle.index), tostring(handle.name), tostring(handle.title)))
    else
        ns.CDMPerfPrint(" resolved handle: none")
    end
end

function ns.CDMPerfResetState(perf)
    if type(perf) ~= "table" then return end
    perf.tickCount = 0
    perf.totalMs = 0
    perf.peakMs = 0
    perf.skippedTicks = 0
    perf.lastTick = {}
    ns.CDMPerfWipeTable(perf.bars)
    ns.CDMPerfWipeTable(perf.phases)
    ns.CDMPerfWipeTable(perf.phasePeaks)
    ns.CDMPerfWipeTable(perf.events)
    ns.CDMPerfWipeTable(perf.dirtyReasons)
end

function ns.CDMPerfEnsureAutoState(perf)
    if type(perf) ~= "table" then
        return nil
    end

    perf.auto = perf.auto or {}
    local auto = perf.auto
    if auto.enabled == nil then auto.enabled = false end
    if auto.idleTickThresholdMs == nil then auto.idleTickThresholdMs = 8 end
    if auto.cpuMsPerSecThreshold == nil then auto.cpuMsPerSecThreshold = 35 end
    if auto.consecutiveTicks == nil then auto.consecutiveTicks = 4 end
    if auto.cooldown == nil then auto.cooldown = 8 end
    if auto.sampleInterval == nil then auto.sampleInterval = 5 end
    if auto.lastTriggerAt == nil then auto.lastTriggerAt = 0 end
    if auto.triggerCount == nil then auto.triggerCount = 0 end
    if auto.streak == nil then auto.streak = 0 end
    if auto.windowStart == nil then auto.windowStart = 0 end
    if auto.lastSamplePrintAt == nil then auto.lastSamplePrintAt = 0 end
    return auto
end

function ns.CDMPerfResetAutoWindow(perf)
    if type(perf) ~= "table" then
        return
    end

    local auto = ns.CDMPerfEnsureAutoState(perf)
    ns.CDMPerfResetState(perf)
    perf.captureElapsed = 0
    perf.captureDur = nil
    perf.captureStart = nil
    perf.cpuStart = nil
    perf.cpuEnd = nil
    perf.onDone = nil
    perf.capturing = false

    auto.windowStart = GetTime()
    auto.streak = 0
    auto.lastCpuSampleAt = auto.windowStart
    auto.lastCpuSampleValue = ns.CDMPerfGetAddonCPU()
    auto.lastCpuPerSec = nil
    auto.lastSamplePrintAt = 0
end

function ns.CDMPerfBuildRuntimeSnapshot()
    local snapshot = {
        visibleIcons = 0,
        totalIcons = 0,
        activeState = 0,
        procGlow = 0,
        buffGlow = 0,
        overlayGlow = 0,
        customProc = 0,
        shapeGlow = 0,
        customModule = 0,
        indexedProcIcons = 0,
        indexedProcBuckets = 0,
        bars = {},
    }

    if ns._activeProcGlowIcons then
        for icon in pairs(ns._activeProcGlowIcons) do
            if icon then
                snapshot.indexedProcIcons = snapshot.indexedProcIcons + 1
            end
        end
    end

    if ns._procGlowIconIndex then
        for _ in pairs(ns._procGlowIconIndex) do
            snapshot.indexedProcBuckets = snapshot.indexedProcBuckets + 1
        end
    end

    for barKey, icons in pairs(cdmBarIcons or {}) do
        local row = {
            key = tostring(barKey),
            total = 0,
            visible = 0,
            active = 0,
            proc = 0,
            buff = 0,
            overlay = 0,
            customProc = 0,
            shape = 0,
            customModule = 0,
        }

        for _, icon in ipairs(icons) do
            if icon then
                row.total = row.total + 1
                snapshot.totalIcons = snapshot.totalIcons + 1
                if icon.IsShown and icon:IsShown() then
                    row.visible = row.visible + 1
                    snapshot.visibleIcons = snapshot.visibleIcons + 1
                end
                if icon._isActive then
                    row.active = row.active + 1
                    snapshot.activeState = snapshot.activeState + 1
                end
                if icon._procGlowActive then
                    row.proc = row.proc + 1
                    snapshot.procGlow = snapshot.procGlow + 1
                end
                if icon._buffGlowActive then
                    row.buff = row.buff + 1
                    snapshot.buffGlow = snapshot.buffGlow + 1
                end
                if icon._customModuleGlowActive or icon._customModuleGlowWanted then
                    row.customModule = row.customModule + 1
                    snapshot.customModule = snapshot.customModule + 1
                end

                local glow = icon._glowOverlay
                if glow then
                    if glow._glowActive then
                        row.overlay = row.overlay + 1
                        snapshot.overlayGlow = snapshot.overlayGlow + 1
                    end
                    if glow._kuiCustomProcGlowActive then
                        row.customProc = row.customProc + 1
                        snapshot.customProc = snapshot.customProc + 1
                    end
                    if glow._kuiShapeGlowActive then
                        row.shape = row.shape + 1
                        snapshot.shapeGlow = snapshot.shapeGlow + 1
                    end
                end
            end
        end

        if row.total > 0 or row.visible > 0 or row.proc > 0 or row.overlay > 0 or row.buff > 0 then
            snapshot.bars[#snapshot.bars + 1] = row
        end
    end

    table.sort(snapshot.bars, function(a, b)
        local aScore = a.proc + a.buff + a.overlay + a.customProc + a.shape + a.visible
        local bScore = b.proc + b.buff + b.overlay + b.customProc + b.shape + b.visible
        if aScore == bScore then
            return a.key < b.key
        end
        return aScore > bScore
    end)

    return snapshot
end

function ns.CDMPerfPrintRuntimeSnapshot(label, snapshot)
    local state = snapshot or ns.CDMPerfBuildRuntimeSnapshot()
    if not state then
        return
    end

    ns.CDMPerfPrint((label and (label .. " ") or "") .. "runtime:")
    ns.CDMPerfPrint(string.format(
        " icons=%d/%d active=%d overlay=%d proc=%d buff=%d customProc=%d shape=%d customModule=%d procIndex=%d/%d",
        state.visibleIcons or 0,
        state.totalIcons or 0,
        state.activeState or 0,
        state.overlayGlow or 0,
        state.procGlow or 0,
        state.buffGlow or 0,
        state.customProc or 0,
        state.shapeGlow or 0,
        state.customModule or 0,
        state.indexedProcIcons or 0,
        state.indexedProcBuckets or 0
    ))

    local count = math.min(4, #(state.bars or {}))
    if count <= 0 then
        return
    end

    ns.CDMPerfPrint("Runtime bars:")
    for i = 1, count do
        local row = state.bars[i]
        ns.CDMPerfPrint(
            " -", row.key,
            string.format(
                "vis=%d/%d active=%d overlay=%d proc=%d buff=%d customProc=%d shape=%d customModule=%d",
                row.visible or 0,
                row.total or 0,
                row.active or 0,
                row.overlay or 0,
                row.proc or 0,
                row.buff or 0,
                row.customProc or 0,
                row.shape or 0,
                row.customModule or 0
            )
        )
    end
end

function CDMRT:PerfAutoEvaluate(totalMs, inCombat, mouseTrackCount, visibleIcons, processedTick)
    local perf = self.perf
    local auto = ns.CDMPerfEnsureAutoState(perf)
    if not (perf and auto and auto.enabled) then
        return
    end

    local now = GetTime()
    if auto.windowStart == 0 then
        auto.windowStart = now
    end
    perf.captureElapsed = now - auto.windowStart

    local idleState = not inCombat and (mouseTrackCount or 0) <= 0
    if idleState and processedTick and type(totalMs) == "number" and totalMs >= (auto.idleTickThresholdMs or 8) then
        auto.streak = (auto.streak or 0) + 1
    else
        auto.streak = 0
    end

    local cpuSpike = false
    local cpuReason = nil
    local cpuNow = ns.CDMPerfGetAddonCPU()
    if cpuNow then
        if auto.lastCpuSampleValue == nil then
            auto.lastCpuSampleValue = cpuNow
            auto.lastCpuSampleAt = now
        elseif (now - (auto.lastCpuSampleAt or 0)) >= 1 then
            local sampleDur = math.max(0.001, now - (auto.lastCpuSampleAt or now))
            local delta = cpuNow - auto.lastCpuSampleValue
            auto.lastCpuPerSec = delta / sampleDur
            auto.lastCpuSampleValue = cpuNow
            auto.lastCpuSampleAt = now
            if idleState and auto.lastCpuPerSec >= (auto.cpuMsPerSecThreshold or 35) then
                cpuSpike = true
                cpuReason = string.format("idle_cpu %.2fms/s", auto.lastCpuPerSec)
            end
        end
    end

    local tickSpike = idleState and (auto.streak or 0) >= (auto.consecutiveTicks or 4)
    if not tickSpike and not cpuSpike then
        return
    end

    if (now - (auto.lastTriggerAt or 0)) < (auto.cooldown or 8) then
        return
    end

    auto.lastTriggerAt = now
    auto.triggerCount = (auto.triggerCount or 0) + 1

    local runtime = ns.CDMPerfBuildRuntimeSnapshot()
    local reason = cpuReason or string.format(
        "idle_tick %.2fms x%d visible=%d",
        totalMs or 0,
        auto.streak or 0,
        visibleIcons or 0
    )

    ns.CDMPerfPrint(string.format("Auto anomaly #%d: %s", auto.triggerCount, reason))
    ns.CDMPerfPrint(string.format(" state inCombat=%s mouseTrack=%d processed=%s", tostring(inCombat == true), mouseTrackCount or 0,
        tostring(processedTick == true)))
    ns.CDMPerfPrintRuntimeSnapshot("Auto", runtime)
    ns.CDMPerfPrintReport("Auto anomaly")
    ns.CDMPerfResetAutoWindow(perf)
end

function ns.CDMPerfAutoTrigger(reason)
    local perf = CDMRT and CDMRT.perf
    local auto = perf and ns.CDMPerfEnsureAutoState(perf)
    if not (perf and auto and auto.enabled) then
        return
    end

    local now = GetTime()
    if (now - (auto.lastTriggerAt or 0)) < (auto.cooldown or 8) then
        return
    end

    auto.lastTriggerAt = now
    auto.triggerCount = (auto.triggerCount or 0) + 1

    local runtime = ns.CDMPerfBuildRuntimeSnapshot()
    ns.CDMPerfPrint(string.format("Auto anomaly #%d: %s", auto.triggerCount, tostring(reason or "unknown")))
    ns.CDMPerfPrintRuntimeSnapshot("Auto", runtime)
    ns.CDMPerfPrintReport("Auto anomaly")
    ns.CDMPerfResetAutoWindow(perf)
end

function ns.CDMPerfEnsureAutoMonitor()
    if ns._cdmPerfAutoMonitor then
        return ns._cdmPerfAutoMonitor
    end

    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnShow", function(self)
        if self._ticker and self._ticker.Cancel then
            self._ticker:Cancel()
        end

        self._ticker = C_Timer.NewTicker(1, function()
            local perf = CDMRT and CDMRT.perf
            local auto = perf and ns.CDMPerfEnsureAutoState(perf)
            if not (perf and auto and auto.enabled) then
                self:Hide()
                return
            end

            local now = GetTime()
            if auto.windowStart == 0 then
                auto.windowStart = now
            end
            perf.captureElapsed = now - auto.windowStart

            local cpuNow = ns.CDMPerfGetAddonCPU()
            local shouldSampleLog = ((now - (auto.lastSamplePrintAt or 0)) >= (auto.sampleInterval or 5))

            if cpuNow == nil then
                if shouldSampleLog then
                    auto.lastSamplePrintAt = now
                    ns.CDMPerfPrint("Auto sample: cpu unavailable (scriptProfile off or no counter).")
                    ns.CDMPerfPrintRuntimeSnapshot("Sample")
                end
                return
            end

            if auto.lastCpuSampleValue == nil then
                auto.lastCpuSampleValue = cpuNow
                auto.lastCpuSampleAt = now
                if shouldSampleLog then
                    auto.lastSamplePrintAt = now
                    ns.CDMPerfPrint(string.format("Auto sample: cpu total=%.2fms (warming up)", cpuNow))
                    ns.CDMPerfPrintRuntimeSnapshot("Sample")
                end
                return
            end

            local sampleDur = math.max(0.001, now - (auto.lastCpuSampleAt or now))
            if sampleDur < 0.95 then
                return
            end

            local delta = cpuNow - auto.lastCpuSampleValue
            auto.lastCpuPerSec = delta / sampleDur
            auto.lastCpuSampleValue = cpuNow
            auto.lastCpuSampleAt = now

            if shouldSampleLog then
                auto.lastSamplePrintAt = now
                ns.CDMPerfPrint(string.format("Auto sample: cpu total=%.2fms delta=%.2fms over %.2fs (%.2f ms/s)",
                    cpuNow, delta, sampleDur, auto.lastCpuPerSec or 0))
                ns.CDMPerfPrintRuntimeSnapshot("Sample")
            end

            if auto.lastCpuPerSec >= (auto.cpuMsPerSecThreshold or 35) then
                ns.CDMPerfAutoTrigger(string.format("background_cpu %.2fms/s", auto.lastCpuPerSec))
            end
        end)
    end)
    frame:SetScript("OnHide", function(self)
        if self._ticker and self._ticker.Cancel then
            self._ticker:Cancel()
        end
        self._ticker = nil
    end)

    ns._cdmPerfAutoMonitor = frame
    return frame
end

function ns.CDMPerfSetAutoMonitorEnabled(enabled)
    local frame = ns.CDMPerfEnsureAutoMonitor()
    if not frame then
        return
    end

    if enabled then
        if not frame:IsShown() then
            frame:Show()
        end
    elseif frame:IsShown() then
        frame:Hide()
    end
end

function ns.CDMPerfPrintTopMap(title, map, limit, suffix)
    if type(map) ~= "table" then return end
    local rows = {}
    for k, v in pairs(map) do
        if type(v) == "number" and v > 0 then
            rows[#rows + 1] = { key = tostring(k), val = v }
        end
    end
    table.sort(rows, function(a, b) return a.val > b.val end)
    local count = math.min(limit or 5, #rows)
    if count <= 0 then return end
    ns.CDMPerfPrint(title .. ":")
    for i = 1, count do
        local row = rows[i]
        ns.CDMPerfPrint(" -", row.key, string.format("%.2f", row.val) .. (suffix or ""))
    end
end

function ns.CDMPerfPrintTopBars(perf, limit)
    if type(perf) ~= "table" or type(perf.bars) ~= "table" then return end
    local rows = {}
    for key, data in pairs(perf.bars) do
        local total = type(data) == "table" and (data.totalMs or 0) or 0
        if total > 0 then
            local ticks = (type(data) == "table" and data.ticks) or 0
            rows[#rows + 1] = {
                key = tostring(key),
                total = total,
                avg = (ticks and ticks > 0) and (total / ticks) or 0,
                peak = (type(data) == "table" and data.peakMs) or 0,
                visible = (type(data) == "table" and data.visibleIcons) or 0,
                icons = (type(data) == "table" and data.totalIcons) or 0,
            }
        end
    end
    table.sort(rows, function(a, b) return a.total > b.total end)
    local count = math.min(limit or 3, #rows)
    if count <= 0 then return end
    ns.CDMPerfPrint("Top bars:")
    for i = 1, count do
        local row = rows[i]
        ns.CDMPerfPrint(
            " -", row.key,
            string.format("total=%.2fms avg=%.2fms peak=%.2fms icons=%d/%d", row.total, row.avg, row.peak, row.visible,
                row.icons)
        )
    end
end

function ns.CDMPerfPrintReport(label)
    local perf = CDMRT and CDMRT.perf
    if type(perf) ~= "table" then
        ns.CDMPerfPrint("No perf runtime available.")
        return
    end

    local ticks = perf.tickCount or 0
    local totalMs = perf.totalMs or 0
    local avgMs = ticks > 0 and (totalMs / ticks) or 0
    local peakMs = perf.peakMs or 0
    local skipped = perf.skippedTicks or 0
    local duration = tonumber(perf.captureElapsed or perf.captureDur or 0) or 0
    if duration <= 0 and perf.auto and perf.auto.windowStart and perf.auto.windowStart > 0 then
        duration = math.max(0, GetTime() - perf.auto.windowStart)
    end
    local tickRate = duration > 0 and (ticks / duration) or 0
    local skippedRate = (ticks + skipped) > 0 and (100 * skipped / (ticks + skipped)) or 0

    ns.CDMPerfPrint((label and (label .. " ") or "") .. "summary:")
    ns.CDMPerfPrint(string.format(" ticks=%d skipped=%d (%.1f%%) duration=%.1fs", ticks, skipped, skippedRate, duration))
    ns.CDMPerfPrint(string.format(" tick avg=%.2fms peak=%.2fms rate=%.2f/s", avgMs, peakMs, tickRate))

    local cpuStart = tonumber(perf.cpuStart)
    local cpuEnd = tonumber(perf.cpuEnd)
    if cpuStart and cpuEnd and cpuEnd >= cpuStart then
        local cpuDelta = cpuEnd - cpuStart
        local cpuPerSec = duration > 0 and (cpuDelta / duration) or 0
        ns.CDMPerfPrint(string.format(" addonCPU delta=%.2fms (%.2f ms/s)", cpuDelta, cpuPerSec))
    elseif _G.GetCVar and _G.GetCVar("scriptProfile") ~= "1" then
        ns.CDMPerfPrint(" addonCPU unavailable: enable /console scriptProfile 1 then /reload")
    end

    ns.CDMPerfPrintTopMap("Top phases", perf.phases, 5, "ms")
    ns.CDMPerfPrintTopBars(perf, 4)
    ns.CDMPerfPrintTopMap("Top dirty reasons", perf.dirtyReasons, 5, "")
    ns.CDMPerfPrintTopMap("Top events", perf.events, 5, "")
    ns.CDMPerfPrintRuntimeSnapshot("Current")
end

function ns.CDMPerfFinalizeCapture(label, fallbackDuration)
    local perf = CDMRT and CDMRT.perf
    if type(perf) ~= "table" then
        return
    end

    perf.capturing = false
    perf.onDone = nil
    perf.captureToken = (perf.captureToken or 0) + 1
    perf.captureElapsed = (perf.captureStart and (GetTime() - perf.captureStart)) or perf.captureElapsed or fallbackDuration or 0
    perf.cpuEnd = ns.CDMPerfGetAddonCPU()
    ns.CDMPerfPrintReport(label)
end

function ns.CDMPerfStartCapture(perf, duration, reportLabel, startMessage)
    if type(perf) ~= "table" then
        ns.CDMPerfPrint("Perf runtime not available.")
        return
    end

    -- Performance captures share the diagnostics window with glow tracing.
    -- Disable the high-volume trace and clear stale lines so the measurement
    -- is not distorted and its report cannot be buried.
    ns._cdmGlowDebugEnabled = false
    _G.KUI_CDM_DebugLog = {}

    ns.CDMPerfResetState(perf)
    perf.captureDur = duration
    perf.captureStart = GetTime()
    perf.captureElapsed = 0
    perf.cpuStart = ns.CDMPerfGetAddonCPU()
    perf.cpuEnd = nil
    perf.capturing = true
    perf.captureToken = (perf.captureToken or 0) + 1
    local token = perf.captureToken

    C_Timer.After(duration, function()
        if not (CDMRT and CDMRT.perf == perf) then
            return
        end
        if perf.captureToken ~= token or not perf.capturing then
            return
        end
        ns.CDMPerfFinalizeCapture(reportLabel, duration)
    end)

    ns.CDMPerfPrint(startMessage)
end

SLASH_KUI_CDMPERF1 = "/cdmperf"
SlashCmdList.KUI_CDMPERF = function(msg)
    if ns.CDMOpenDebugWindow then ns.CDMOpenDebugWindow() end
    local raw = strtrim(msg or "")
    local cmd, rest = raw:match("^(%S+)%s*(.-)$")
    cmd = cmd and strlower(cmd) or ""
    rest = rest or ""

    local perf = CDMRT and CDMRT.perf
    if type(perf) ~= "table" then
        ns.CDMPerfPrint("Perf runtime not available.")
        return
    end

    if cmd == "report" then
        ns.CDMPerfPrintReport("Current")
        return
    end

    if cmd == "auto" then
        local auto = ns.CDMPerfEnsureAutoState(perf)
        local subcmd, subrest = rest:match("^(%S+)%s*(.-)$")
        subcmd = subcmd and strlower(subcmd) or ""
        subrest = subrest or ""

        if subcmd == "off" or subcmd == "disable" or subcmd == "0" then
            auto.enabled = false
            auto.streak = 0
            ns.CDMPerfSetAutoMonitorEnabled(false)
            ns.CDMPerfPrint("Auto perf OFF")
            return
        end

        if subcmd == "status" then
            ns.CDMPerfPrint(string.format(
                "Auto perf %s tick>=%.2fms cpu>=%.2fms/s streak=%d cooldown=%.1fs sample=%.1fs triggers=%d",
                auto.enabled and "ON" or "OFF",
                auto.idleTickThresholdMs or 0,
                auto.cpuMsPerSecThreshold or 0,
                auto.consecutiveTicks or 0,
                auto.cooldown or 0,
                auto.sampleInterval or 0,
                auto.triggerCount or 0
            ))
            return
        end

        if subcmd == "config" then
            local tickMs, streak, cooldown, cpuMs, sampleInt = subrest:match("^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)%s*(%S*)$")
            tickMs = tonumber(tickMs) or auto.idleTickThresholdMs
            streak = tonumber(streak) or auto.consecutiveTicks
            cooldown = tonumber(cooldown) or auto.cooldown
            cpuMs = tonumber(cpuMs) or auto.cpuMsPerSecThreshold
            sampleInt = tonumber(sampleInt) or auto.sampleInterval
            auto.idleTickThresholdMs = math.max(1, tickMs or 8)
            auto.consecutiveTicks = math.max(1, streak or 4)
            auto.cooldown = math.max(1, cooldown or 8)
            auto.cpuMsPerSecThreshold = math.max(1, cpuMs or 35)
            auto.sampleInterval = math.max(1, sampleInt or 5)
            ns.CDMPerfPrint(string.format(
                "Auto perf config tick>=%.2fms cpu>=%.2fms/s streak=%d cooldown=%.1fs sample=%.1fs",
                auto.idleTickThresholdMs,
                auto.cpuMsPerSecThreshold,
                auto.consecutiveTicks,
                auto.cooldown,
                auto.sampleInterval
            ))
            return
        end

        auto.enabled = true
        ns.CDMPerfResetAutoWindow(perf)
        ns.CDMPerfSetAutoMonitorEnabled(true)
        ns.CDMPerfPrint(string.format(
            "Auto perf ON tick>=%.2fms cpu>=%.2fms/s streak=%d cooldown=%.1fs sample=%.1fs",
            auto.idleTickThresholdMs or 0,
            auto.cpuMsPerSecThreshold or 0,
            auto.consecutiveTicks or 0,
            auto.cooldown or 0,
            auto.sampleInterval or 0
        ))
        if _G.GetCVar and _G.GetCVar("scriptProfile") ~= "1" then
            ns.CDMPerfPrint(" scriptProfile is OFF: auto mode will still detect tick spikes, but CPU ms/s will be unavailable.")
        end
        return
    end

    if cmd == "stop" then
        ns.CDMPerfFinalizeCapture("Stopped", perf.captureDur)
        return
    end

    if cmd == "cpu" then
        local cpuNow = ns.CDMPerfGetAddonCPU()
        if cpuNow then
            ns.CDMPerfPrint(string.format(" addonCPU total=%.2fms", cpuNow))
        else
            ns.CDMPerfPrint(" addonCPU unavailable (likely scriptProfile off).")
        end
        return
    end

    if cmd == "cpuinfo" then
        if ns.CDMPerfPrintCPUInfo then
            ns.CDMPerfPrintCPUInfo()
        end
        return
    end

    if cmd == "idle" then
        local idleDuration = tonumber(rest) or 30
        if idleDuration < 5 then idleDuration = 5 end
        if idleDuration > 180 then idleDuration = 180 end

        if _G.GetCVar and _G.GetCVar("scriptProfile") ~= "1" then
            ns.CDMPerfPrint(" idle mode: scriptProfile is OFF; addonCPU delta will not be available.")
            ns.CDMPerfPrint(" enable with: /console scriptProfile 1  and /reload")
        end

        if _G.ResetCPUUsage then
            local ok = pcall(_G.ResetCPUUsage)
            if ok then
                ns.CDMPerfPrint(" idle mode: CPU counters reset.")
            end
        end

        ns.CDMPerfStartCapture(
            perf,
            idleDuration,
            "Idle capture",
            string.format("Idle capture %.1fs started. Do not cast/move/change target.", idleDuration)
        )
        return
    end

    local durationArg = tonumber(raw)
    local duration = durationArg or tonumber(rest) or 10
    if duration < 2 then duration = 2 end
    if duration > 120 then duration = 120 end

    ns.CDMPerfStartCapture(
        perf,
        duration,
        "Capture",
        string.format("Capturing %.1fs... (use /cdmperf stop to end early)", duration)
    )
end

SLASH_KUI_CDMDEBUG1 = "/cdmdebug"
SlashCmdList.KUI_CDMDEBUG = function(msg)
    local cmd = strlower(strtrim(msg or ""))
    if cmd == "hide" or cmd == "off" then
        ns._cdmGlowDebugEnabled = false
        if ns._cdmDebugWindow then ns._cdmDebugWindow:Hide() end
        return
    end
    if cmd == "status" then
        print("KUI CDM glow debug: " .. (ns._cdmGlowDebugEnabled and "ON" or "OFF"))
        return
    end
    if cmd == "clear" then
        _G.KUI_CDM_DebugLog = {}
        if ns.CDMOpenDebugWindow then ns.CDMOpenDebugWindow() end
        return
    end
    ns._cdmGlowDebugEnabled = true
    if ns.CDMOpenDebugWindow then ns.CDMOpenDebugWindow() end
end

SLASH_KUI_CDMSTACKS1 = "/cdmstacks"
SlashCmdList.KUI_CDMSTACKS = function()
    local p = function(...) print("|cff0cd29f[CDM Stacks]|r", ...) end
    p("--- Stack Count Debug ---")
    local BLIZZ = {
        cooldowns = "EssentialCooldownViewer",
        utility = "UtilityCooldownViewer",
        buffs =
        "BuffIconCooldownViewer"
    }
    local profile = KUI_CDM.db and KUI_CDM.db.profile
    if not profile or not profile.cdmBars then
        p("No CDM bars configured"); return
    end

    for _, barData in ipairs(profile.cdmBars.bars) do
        local key = barData.key
        local blizzName = BLIZZ[key]
        local blizzFrame = blizzName and _G[blizzName]
        if blizzFrame then
            p("|cff00ccff" .. key .. "|r  showCharges=" .. tostring(barData.showCharges))
            local _children = { blizzFrame:GetChildren() }
            for i, child in ipairs(_children) do
                if child and child.Icon and child.Icon:GetTexture() then
                    local cdID = child.cooldownID
                    if not cdID and child.cooldownInfo then cdID = child.cooldownInfo.cooldownID end
                    local resolvedSid
                    if cdID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
                        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                        if info then resolvedSid = info.overrideSpellID or info.spellID end
                    end
                    local spellName = resolvedSid and C_Spell.GetSpellName(resolvedSid) or "?"
                    local isAura = child.wasSetFromAura == true or child.auraInstanceID ~= nil
                    local auraInstID = child.auraInstanceID
                    local auraUnit = child.auraDataUnit or "player"
                    local appsFrame = child.Applications
                    local appsShown = appsFrame and appsFrame:IsShown()
                    local appsTxt = nil
                    if appsFrame and appsFrame.Applications then
                        local ok, t = pcall(appsFrame.Applications.GetText, appsFrame.Applications)
                        if ok then appsTxt = tostring(t) end
                    end
                    p("  " ..
                        (spellName or "?") ..
                        " (sid=" ..
                        tostring(resolvedSid) ..
                        ") appsShown=" .. tostring(appsShown) .. " appsTxt=" .. tostring(appsTxt))
                end
            end
        end
    end
end

SLASH_KUI_CDMCUSTOM1 = "/cdmcustom"
SlashCmdList.KUI_CDMCUSTOM = function()
    local p = function(...) print("|cff00ff99[CDM Custom]|r", ...) end
    p("=== Custom bar spells ===")
    local profile = KUI_CDM.db and KUI_CDM.db.profile
    if not profile or not profile.cdmBars then
        p("No profile"); return
    end
    for _, barData in ipairs(profile.cdmBars.bars) do
        if barData.customSpells and #barData.customSpells > 0 then
            p("Bar: " .. tostring(barData.key))
            for _, sid in ipairs(barData.customSpells) do
                if sid and sid > 0 then
                    local name = C_Spell.GetSpellName and C_Spell.GetSpellName(sid) or "?"
                    p("  sid=" .. sid .. " (" .. name .. ")")
                end
            end
        end
    end
end

SLASH_KUI_CDMTRINKETDEBUG1 = "/cdmtrinketdebug"
SLASH_KUI_CDMTRINKETDEBUG2 = "/cdmtdbg"
SlashCmdList.KUI_CDMTRINKETDEBUG = function(msg)
    local filter = strtrim(msg or "")
    local filterLower = filter ~= "" and strlower(filter) or nil
    _G.KUI_CDM_DebugLog = {}

    local p = function(...)
        local parts = { "|cff99ff66[CDM Trinket]|r" }
        for i = 1, select("#", ...) do
            parts[#parts + 1] = tostring(select(i, ...))
        end
        local line = table.concat(parts, " ")
        _G.KUI_CDM_DebugLog[#_G.KUI_CDM_DebugLog + 1] = line
        local chatModule = KT and KT.GetModule and KT:GetModule("Chat", true)
        if chatModule and chatModule.SendMessageToChat then
            chatModule:SendMessageToChat(line, 0.6, 1, 0.4)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(line)
        elseif ChatFrame1 and ChatFrame1.AddMessage then
            ChatFrame1:AddMessage(line)
        end
    end

    local function MatchesText(value)
        return not filterLower or (type(value) == "string" and string.find(strlower(value), filterLower, 1, true) ~= nil)
    end

    local function BodyUsesTrinket(body)
        if type(body) ~= "string" then
            return false
        end
        local lowerBody = strlower(body)
        return lowerBody:find("/use 13", 1, true)
            or lowerBody:find("/use 14", 1, true)
            or lowerBody:find("trinket1", 1, true)
            or lowerBody:find("trinket2", 1, true)
    end

    local function CollapseBody(body)
        if type(body) ~= "string" then
            return nil
        end
        body = body:gsub("\r", "")
        body = body:gsub("\n", " | ")
        return body
    end

    local function GetButtonBindingDebug(button)
        if not button then
            return nil, nil, nil
        end

        local rawKey = nil
        local commandName = nil

        if button.HotKey then
            rawKey = button.HotKey:GetText()
            if rawKey == RANGE_INDICATOR then
                rawKey = nil
            end
        end
        if not rawKey and button.commandName then
            commandName = button.commandName
            rawKey = GetBindingKey(commandName)
        end
        if not rawKey and button.config and button.config.keyBoundTarget then
            commandName = button.config.keyBoundTarget
            rawKey = GetBindingKey(commandName)
        end
        if not rawKey then
            commandName = ns.GetBindingCommandForButton and ns.GetBindingCommandForButton(button) or nil
            if commandName then
                rawKey = GetBindingKey(commandName)
            end
        end
        if not rawKey and button.GetName and GetNumBindings and GetBinding then
            local buttonName = button:GetName()
            if type(buttonName) == "string" and buttonName ~= "" then
                for bindingIndex = 1, GetNumBindings() do
                    local command, key1, key2 = GetBinding(bindingIndex)
                    if type(command) == "string" and command:find("^CLICK ") then
                        local candidateName = command:match("^CLICK%s+(.+)$")
                        while candidateName and candidateName ~= "" do
                            if candidateName == buttonName then
                                commandName = command
                                rawKey = key1 or key2
                                break
                            end
                            candidateName = candidateName:match("^(.*):[^:]+$")
                        end
                    end
                    if rawKey then
                        break
                    end
                end
            end
        end

        return ns.NormalizeBindingLabel(rawKey), commandName, rawKey
    end

    UpdateCDMKeybinds()

    p("Filter:", filter ~= "" and filter or "<none>")
    p("Rebuilds:", tostring(ns._cdmTrinketMacroDebug.rebuildCount), "lastUpdated=", tostring(ns._cdmTrinketMacroDebug.lastUpdated))

    p("Slot cache:")
    for _, slot in ipairs({ ns.TRINKET_SLOT_1, ns.TRINKET_SLOT_2 }) do
        local itemID = GetInventoryItemID("player", slot)
        local itemName = itemID and GetItemInfo and GetItemInfo(itemID) or nil
        local _, itemSpellID = itemID and C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(itemID)
        local itemSpellName = itemSpellID and C_Spell.GetSpellName and C_Spell.GetSpellName(itemSpellID) or nil
        p(" slot", tostring(slot), "cache=", tostring(ns._cdmTrinketSlotKeybindCache[slot]), "item=", tostring(itemID), tostring(itemName), "spell=", tostring(itemSpellID), tostring(itemSpellName))
    end

    p("Tracked macro segments:")
    local foundEntry = false
    for _, entry in ipairs(ns._cdmTrinketMacroDebug.entries or {}) do
        if MatchesText(entry.macroName) or MatchesText(entry.segment) or MatchesText(entry.formattedKey) then
            foundEntry = true
            p(" macroID=", tostring(entry.macroID), "name=", tostring(entry.macroName), "slot=", tostring(entry.slot), "actionSlot=", tostring(entry.actionSlot), "bind=", tostring(entry.formattedKey), "segment=", tostring(entry.segment), "line=", tostring(CollapseBody(entry.sourceLine)))
        end
    end
    if not foundEntry then
        p(" <none>")
    end

    p("Action slots using trinket macros:")
    local foundActionSlot = false
    for slot = 1, 180 do
        local actionType, actionID = GetActionInfo(slot)
        if actionType == "macro" and actionID then
            local macroName, _, macroBody = GetMacroInfo(actionID)
            if BodyUsesTrinket(macroBody) and (not filterLower or MatchesText(macroName) or MatchesText(macroBody)) then
                foundActionSlot = true
                local formatted = ns.NormalizeBindingLabel(GetBindingKeyForSlot(slot))
                p(" slot", tostring(slot), "macroID=", tostring(actionID), "name=", tostring(macroName), "bind=", tostring(formatted), "body=", tostring(CollapseBody(macroBody)))
            end
        end
    end
    if not foundActionSlot then
        p(" <none>")
    end

    p("Visible trinket icons:")
    local icons = cdmBarIcons and cdmBarIcons["kui_trinket"] or nil
    if not icons or #icons == 0 then
        p(" <none>")
    else
        for index, icon in ipairs(icons) do
            local keyText = icon and icon._keybindText and icon._keybindText:GetText() or nil
            local keyShown = icon and icon._keybindText and icon._keybindText:IsShown() or false
            local cachedKey = icon and ns.FindCachedKeybindForIcon and ns.FindCachedKeybindForIcon(icon) or nil
            p(" icon", tostring(index), "shown=", tostring(icon and icon:IsShown()), "slot=", tostring(icon and icon._trinketSlot), "item=", tostring(icon and icon._itemID), "cached=", tostring(cachedKey), "text=", tostring(keyText), "textShown=", tostring(keyShown))
        end
    end


    p("Visible macro-capable buttons:")
    local foundMacroButton = false
    local seenMacroButtons = {}
    local frame = EnumerateFrames and EnumerateFrames()
    while frame do
        if not seenMacroButtons[frame]
            and frame.IsObjectType
            and (frame:IsObjectType("CheckButton") or frame:IsObjectType("Button"))
        then
            seenMacroButtons[frame] = true

            local hasMacroAttrs = frame.GetAttribute and (
                frame:GetAttribute("macrotext") ~= nil
                or frame:GetAttribute("macrotext1") ~= nil
                or frame:GetAttribute("macro") ~= nil
                or frame:GetAttribute("macro1") ~= nil
                or frame:GetAttribute("macroName") ~= nil
                or frame:GetAttribute("macroName1") ~= nil
                or frame:GetAttribute("type") == "macro"
                or frame:GetAttribute("type1") == "macro"
            )

            if hasMacroAttrs then
                local formatted, commandName, rawKey = GetButtonBindingDebug(frame)
                local slot = frame.action or frame._state_action or (frame.GetAttribute and frame:GetAttribute("action"))
                local macroText = frame.GetAttribute and (frame:GetAttribute("macrotext") or frame:GetAttribute("macrotext1")) or nil
                local macroAttr = frame.GetAttribute and (frame:GetAttribute("macro") or frame:GetAttribute("macro1") or frame:GetAttribute("macroName") or frame:GetAttribute("macroName1")) or nil
                local buttonName = frame.GetName and frame:GetName() or nil
                local parentName = frame.GetParent and frame:GetParent() and frame:GetParent():GetName() or nil
                local candidateSlots = ns.GetCandidateSlotsForBindingCommand(commandName, slot)
                local joinedSlots = candidateSlots and table.concat(candidateSlots, ",") or nil

                if formatted or BodyUsesTrinket(macroText) or MatchesText(buttonName) or MatchesText(commandName) or MatchesText(macroText) or MatchesText(macroAttr) then
                    foundMacroButton = true
                    p(
                        " button",
                        tostring(buttonName or "?"),
                        "shown=", tostring(frame:IsShown()),
                        "slot=", tostring(slot),
                        "candidates=", tostring(joinedSlots),
                        "cmd=", tostring(commandName),
                        "key=", tostring(formatted),
                        "rawKey=", tostring(rawKey),
                        "parent=", tostring(parentName),
                        "type=", tostring(frame.GetAttribute and (frame:GetAttribute("type") or frame:GetAttribute("type1")) or nil),
                        "macroAttr=", tostring(macroAttr),
                        "macro=", tostring(CollapseBody(macroText))
                    )
                end
            end
        end
        frame = EnumerateFrames(frame)
    end
    if not foundMacroButton then
        p(" <none>")
    end
    if ns.CDMOpenDebugWindow then ns.CDMOpenDebugWindow() end
end

SLASH_KUI_CDMKEYBINDS1 = "/cdmkeybinds"
SLASH_KUI_CDMKEYBINDS2 = "/cdmkb"
end
