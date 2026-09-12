local _, ns = ...

local KT = (ns and ns.KT) or _G.KT
if not KT then
    return
end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then
    return
end

local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local UIParent = _G.UIParent
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCanAttack = _G.UnitCanAttack
local UnitExists = _G.UnitExists
local GetTime = _G.GetTime
local SetPortraitTexture = _G.SetPortraitTexture
local AbbreviateNumbers = _G.AbbreviateNumbers
local CreateAbbreviateConfig = _G.CreateAbbreviateConfig
local Ambiguate = _G.Ambiguate
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local CLASS_ICON_TCOORDS = _G.CLASS_ICON_TCOORDS
local issecretvalue = _G.issecretvalue
local math = _G.math
local ipairs = _G.ipairs
local pcall = _G.pcall
local rawget = _G.rawget
local tonumber = _G.tonumber
local type = _G.type
local function LText(text)
    if type(text) ~= "string" then
        return text
    end
    local locale = KT.GetLocale and KT:GetLocale()
    return locale and locale[text] or text
end

local BAR_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
local CLASS_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local DAMAGE_METER_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local DAMAGE_METER_FONT_PATHS = {
    [DAMAGE_METER_FONT] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\FiraSans Medium.ttf"] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Ubuntu.ttf"] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Poppins.ttf"] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\font\\Tempesta Seven Condensed.ttf"] = true,
}
local function DAMAGE_METER_RESOLVED_FONT()
    return (KT and KT.ResolveStoredFontPath and KT:ResolveStoredFontPath(DAMAGE_METER_FONT)) or DAMAGE_METER_FONT
end
local DAMAGE_METER_TEXTURE_PATHS = {
    [BAR_TEXTURE] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Clean.blp"] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes_Thin.blp"] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Statusbar_Stripes.blp"] = true,
    ["Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\stripe-bar.tga"] = true,
}
local function GetDamageMeterFont(cfg)
    local path = cfg and cfg.font
    local selected = DAMAGE_METER_FONT_PATHS[path] and path or DAMAGE_METER_FONT
    if KT and KT.ResolveStoredFontPath then
        return KT:ResolveStoredFontPath(selected) or DAMAGE_METER_FONT
    end
    return selected
end
local function GetDamageMeterBarTexture(cfg)
    local path = cfg and cfg.barTexture
    return DAMAGE_METER_TEXTURE_PATHS[path] and path or BAR_TEXTURE
end
local DAMAGE_METER_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\damagemeter\\"
local KUI_ICON_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local DROPDOWN_ARROW = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\downarrow.png"
local HEADER_HEIGHT = 30
local ROW_SPACING = 2
local DAMAGE_METER_FOOTER_HEIGHT = 20
local MAX_ROW_POOL = 40
local MAX_SAVED_COMBAT_SESSIONS = 20
local SNAP_DISTANCE = 16
local SNAP_UPDATE_INTERVAL = 0.05
local SNAP_GAP = tonumber(KT.mult) or 1
local MIN_METER_WIDTH = 150
local MIN_METER_HEIGHT = 72
local MODE_LABELS = {
    damageDone = LText("Damage Done"),
    dps = LText("DPS"),
    healingDone = LText("Healing Done"),
    hps = LText("HPS"),
    absorbs = LText("Absorbs"),
    damageTaken = LText("Damage Taken"),
    enemyDamageTaken = LText("Enemy Damage Taken"),
    avoidableDamageTaken = LText("Avoidable Damage Taken"),
    interrupts = LText("Interrupts"),
    dispels = LText("Dispels"),
    deaths = LText("Deaths"),
}
local MODE_ENUM_KEYS = {
    damageDone = "DamageDone",
    dps = "Dps",
    healingDone = "HealingDone",
    hps = "Hps",
    absorbs = "Absorbs",
    damageTaken = "DamageTaken",
    enemyDamageTaken = "EnemyDamageTaken",
    avoidableDamageTaken = "AvoidableDamageTaken",
    interrupts = "Interrupts",
    dispels = "Dispels",
    deaths = "Deaths",
}
local MODE_GROUPS = {
    {
        label = "Damage",
        modes = { "damageDone", "dps", "damageTaken", "enemyDamageTaken", "avoidableDamageTaken" },
    },
    {
        label = "Healing",
        modes = { "healingDone", "hps", "absorbs" },
    },
    {
        label = "Miscellaneous",
        modes = { "interrupts", "dispels", "deaths" },
    },
}
local MODE_ICONS = {
    damageDone = DAMAGE_METER_MEDIA .. "DPS.png",
    dps = DAMAGE_METER_MEDIA .. "DPS.png",
    healingDone = DAMAGE_METER_MEDIA .. "HEALER.png",
    hps = DAMAGE_METER_MEDIA .. "HEALER.png",
    absorbs = DAMAGE_METER_MEDIA .. "HEALER.png",
    damageTaken = DAMAGE_METER_MEDIA .. "TANK.png",
    enemyDamageTaken = DAMAGE_METER_MEDIA .. "TANK.png",
    avoidableDamageTaken = DAMAGE_METER_MEDIA .. "TANK.png",
    interrupts = "Interface\\Icons\\Ability_Kick",
    dispels = "Interface\\Icons\\Spell_Holy_DispelMagic",
    deaths = KUI_ICON_MEDIA .. "UnitFramesIcons\\Dead.png",
}

local TARGET_ICON = "Interface\\Icons\\Ability_MeleeDamage"
local SPELL_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PET_FALLBACK_ICON = "Interface\\Icons\\Ability_Hunter_BeastCall"
local INSTALLER_BACKGROUND = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\InstallerBackground.png"
local abbreviationConfig
if CreateAbbreviateConfig then
    abbreviationConfig = {
        config = CreateAbbreviateConfig({
            { breakpoint = 1000000000, abbreviation = "B", significandDivisor = 10000000, fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 1000000, abbreviation = "M", significandDivisor = 10000, fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 1000, abbreviation = "K", significandDivisor = 100, fractionDivisor = 10, abbreviationIsGlobal = false },
            { breakpoint = 1, abbreviation = "", significandDivisor = 1, fractionDivisor = 1, abbreviationIsGlobal = false },
        }),
    }
end

local PREVIEW_DATA = {
    { name = "Mew", classFilename = "DEMONHUNTER", specIconID = 1247264, totalAmount = 3842000, amountPerSecond = 182300 },
    { name = "Ulkrad", classFilename = "WARRIOR", specIconID = 132355, totalAmount = 2746000, amountPerSecond = 130200 },
    { name = "Kullthran", classFilename = "MAGE", specIconID = 135932, totalAmount = 2194000, amountPerSecond = 104100 },
    { name = "Rogue", classFilename = "ROGUE", specIconID = 136189, totalAmount = 1987000, amountPerSecond = 94400 },
    { name = "Hunter", classFilename = "HUNTER", specIconID = 132164, totalAmount = 1712000, amountPerSecond = 81300 },
}
local PREVIEW_HEALING_DATA = {
    { name = "Vhii", classFilename = "PRIEST", specIconID = 135940, totalAmount = 3842000, amountPerSecond = 182300 },
    { name = "Shammy", classFilename = "SHAMAN", specIconID = 136048, totalAmount = 3168000, amountPerSecond = 150400 },
    { name = "Lunara", classFilename = "DRUID", specIconID = 136041, totalAmount = 2746000, amountPerSecond = 130200 },
    { name = "Aurelia", classFilename = "PALADIN", specIconID = 135920, totalAmount = 2194000, amountPerSecond = 104100 },
    { name = "Mewra", classFilename = "MONK", specIconID = 608951, totalAmount = 1812000, amountPerSecond = 85900 },
}
local HEALING_PREVIEW_MODES = { healingDone = true, hps = true, absorbs = true }
local function GetPreviewData(mode)
    return HEALING_PREVIEW_MODES[mode] and PREVIEW_HEALING_DATA or PREVIEW_DATA
end

local activeDropdown
local currentSessionIcon
local activeEncounterIcon
local sessionIcons = {}

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then return true end
    if _G.canaccessvalue and not _G.canaccessvalue(value) then return true end
    return false
end

local function IsDamageMeterPreviewing(frame)
    return frame and frame.damageMeterPreviewUntil and frame.damageMeterPreviewUntil > GetTime()
end

local function GetAccentColor()
    if KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        if r then
            return r, g, b
        end
    end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
end

local function IsUnlockModeOpen()
    local unlockMode = KT.GetModule and KT:GetModule("UnlockMode", true)
    return unlockMode and unlockMode.isOpen == true
end

local function IsDamageMeterModuleEnabled()
    local db = Mod:GetDB()
    return db.enable ~= false and (not db.damageMeter or db.damageMeter.moduleEnabled ~= false)
end

local function GetConfig()
    local db = Mod:GetDB()
    db.damageMeter = db.damageMeter or {}
    -- AceDB exposes defaults through its metatable, so rawget is required to
    -- distinguish an existing pre-layout profile from the new defaults.
    local layoutVersion = tonumber(rawget(db.damageMeter, "layoutVersion")) or 0
    if layoutVersion < 4 then
        if db.damageMeter.fontSize == nil or db.damageMeter.fontSize == 11 or db.damageMeter.fontSize == 14 then
            db.damageMeter.fontSize = 12
        end
        if db.damageMeter.rowHeight == nil or db.damageMeter.rowHeight == 22 then
            db.damageMeter.rowHeight = 19
        end
        if db.damageMeter.headerFontSize == nil then
            db.damageMeter.headerFontSize = 12
        end
        db.damageMeter.width = math.max(MIN_METER_WIDTH, tonumber(db.damageMeter.width) or 320)

        -- The old default/persisted behaviour forced the local player into the
        -- last visible row. That rewrote damageMeterScrollOffset on every live
        -- refresh, so a window left at the top jumped to ranges such as 8-17.
        -- Keep the feature available as an explicit option, but make the safe
        -- ranking view the migrated default for existing profiles and windows.
        if rawget(db.damageMeter, "alwaysShowPlayer") == true then
            db.damageMeter.alwaysShowPlayer = false
        end
        for _, windowConfig in ipairs(db.damageMeter.windows or {}) do
            if type(windowConfig) == "table" and rawget(windowConfig, "alwaysShowPlayer") == true then
                windowConfig.alwaysShowPlayer = false
            end
        end

        db.damageMeter.layoutVersion = 4
        layoutVersion = 4
    end
    if layoutVersion < 5 then
        if rawget(db.damageMeter, "rowHeight") == nil or db.damageMeter.rowHeight == 21 then
            db.damageMeter.rowHeight = 19
        end
        for _, windowConfig in ipairs(db.damageMeter.windows or {}) do
            if type(windowConfig) == "table"
                and (rawget(windowConfig, "rowHeight") == nil or windowConfig.rowHeight == 21) then
                windowConfig.rowHeight = 19
            end
        end
        db.damageMeter.layoutVersion = 5
    end
    if layoutVersion < 6 then
        -- The previous release shipped the replacement hidden by default. Repair
        -- that legacy state once; the player can disable it again in options.
        db.damageMeter.enabled = true
        db.damageMeter.layoutVersion = 6
    end
    if layoutVersion < 7 then
        -- Keep the replacement visually transparent by default while preserving
        -- an explicit background choice made by the player.
        if rawget(db.damageMeter, "showBackground") == nil then
            db.damageMeter.showBackground = false
        end
        for _, windowConfig in ipairs(db.damageMeter.windows or {}) do
            if type(windowConfig) == "table" and rawget(windowConfig, "showBackground") == nil then
                windowConfig.showBackground = false
            end
        end
        db.damageMeter.layoutVersion = 7
    end
    db.damageMeter.position = db.damageMeter.position
        or { point = "RIGHT", relativePoint = "RIGHT", x = -36, y = 0 }
    return db.damageMeter
end

local function GetFrameConfig(frame)
    return (frame and frame.damageMeterConfig) or GetConfig()
end

local function NormalizeHistoryMode(mode)
    if mode == "dps" then return "damageDone" end
    if mode == "hps" then return "healingDone" end
    return mode
end

local function GetSavedCombatHistory()
    local cfg = GetConfig()
    local history = rawget(cfg, "savedCombatHistory")
    if type(history) ~= "table" or history.version ~= 2 or type(history.sessions) ~= "table" then
        -- Version 2 stores utility spell breakdowns using opaque protected
        -- source GUIDs. Older snapshots only retained actor totals.
        history = { version = 2, sessions = {} }
        cfg.savedCombatHistory = history
    end
    return history
end

local function FindSavedCombatSession(key)
    if not key then return nil end
    for _, session in ipairs(GetSavedCombatHistory().sessions) do
        if session.key == key then return session end
    end
    return nil
end

local function BuildSessionStorageKey(session, fallbackIndex)
    if not session then return nil end
    local sessionID = session.sessionID
    if IsSecret(sessionID) then return nil end
    local name = session.name
    if IsSecret(name) or type(name) ~= "string" or name == "" then name = "Combat" end
    local duration = session.durationSeconds
    if IsSecret(duration) or type(duration) ~= "number" then duration = 0 end
    return string.format("%s|%s|%d", tostring(sessionID or fallbackIndex or 0), name, math.floor(duration + 0.5))
end

local function ResolveMode(modeKey)
    local types = Enum and Enum.DamageMeterType
    if not types then
        return nil
    end
    local enumKey = MODE_ENUM_KEYS[modeKey] or MODE_ENUM_KEYS.damageDone
    return types[enumKey]
end

local function IsModeSupported(modeKey)
    return ResolveMode(modeKey) ~= nil
end

local function ResolveSession(sessionKey)
    local sessions = Enum and Enum.DamageMeterSessionType
    if not sessions then
        return nil
    end
    if sessionKey == "overall" then
        return sessions.Overall
    end
    return sessions.Current
end

local function GetSessionLabel(cfg, frame)
    if frame and frame.selectedSessionID then
        return frame.selectedSessionLabel or LText("Segment")
    end
    return cfg.session == "overall" and LText("Overall") or LText("Current")
end

local function ResolveEncounterIcon(encounterID)
    local getEncounterInfo = _G.EJ_GetEncounterInfo
    local getEncounterInfoByIndex = _G.EJ_GetEncounterInfoByIndex
    local getCreatureInfo = _G.EJ_GetCreatureInfo
    if not getCreatureInfo then
        return nil
    end

    local journalEncounterID
    if getEncounterInfo then
        local _, _, returnedJournalID, _, _, _, dungeonEncounterID = getEncounterInfo(encounterID)
        if returnedJournalID and (dungeonEncounterID == encounterID or returnedJournalID == encounterID) then
            journalEncounterID = returnedJournalID
        end
    end

    if not journalEncounterID and getEncounterInfoByIndex and _G.EJ_GetInstanceForMap then
        local mapID = _G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")
        local journalInstanceID = mapID and _G.EJ_GetInstanceForMap(mapID)
        if journalInstanceID then
            local index = 1
            while index <= 40 do
                local _, _, candidateJournalID, _, _, _, candidateDungeonID =
                    getEncounterInfoByIndex(index, journalInstanceID)
                if not candidateJournalID then
                    break
                end
                if candidateDungeonID == encounterID or candidateJournalID == encounterID then
                    journalEncounterID = candidateJournalID
                    break
                end
                index = index + 1
            end
        end
    end

    if journalEncounterID then
        local _, _, _, _, iconImage = getCreatureInfo(1, journalEncounterID)
        return iconImage
    end
    return nil
end

local function GetDisplayedSessionIcon(cfg, frame)
    if frame and frame.selectedSessionID then
        return frame.selectedSessionIcon or sessionIcons[frame.selectedSessionID]
    end
    if cfg.session == "current" then
        return currentSessionIcon
    end
    return nil
end

local function SetHeaderArrowExpanded(button, expanded)
    if not button or not button.arrow then
        return
    end
    if expanded then
        button.arrow:SetTexCoord(0, 1, 1, 0)
    else
        button.arrow:SetTexCoord(0, 1, 0, 1)
    end
end

local function LayoutHeaderButton(button)
    if not button or not button.text or not button.arrow then
        return
    end

    local hasIcon = button.icon and button.icon:IsShown()
    local leadingWidth = hasIcon and 28 or 7
    local availableWidth = math.max(8, button:GetWidth() - leadingWidth - button.arrow:GetWidth() - 9)
    local textWidth = math.min(availableWidth, math.ceil(button.text:GetStringWidth() + 2))

    button.text:ClearAllPoints()
    if hasIcon then
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 5, 0)
    else
        button.text:SetPoint("LEFT", button, "LEFT", 7, 0)
    end
    button.text:SetWidth(textWidth)
    button.text:SetJustifyH("LEFT")

    button.arrow:ClearAllPoints()
    button.arrow:SetPoint("LEFT", button.text, "RIGHT", 4, 0)
end

local function RefreshSessionButtonIcon(frame)
    if not frame or not frame.sessionButton or not frame.sessionButton.icon then
        return
    end
    local button = frame.sessionButton
    local icon = GetDisplayedSessionIcon(GetFrameConfig(frame), frame)
    button.text:ClearAllPoints()
    if icon then
        button.icon:SetTexture(icon)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon:Show()
    else
        button.icon:Hide()
    end
    LayoutHeaderButton(button)
end

local function FormatNumber(value)
    if IsSecret(value) then
        if AbbreviateNumbers then
            local ok, result = pcall(AbbreviateNumbers, value, abbreviationConfig)
            if ok then
                return result
            end
        end
        return ""
    end
    if value == nil then
        return "0"
    end
    local number = tonumber(value) or 0
    if number >= 1000000000 then
        return string.format("%.1fB", number / 1000000000)
    elseif number >= 1000000 then
        return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        if number >= 100000 then
            return string.format("%.0fK", number / 1000)
        end
        return string.format("%.1fK", number / 1000)
    end
    return string.format("%.0f", number)
end

local function ShortName(name)
    if IsSecret(name) then
        return name
    end
    if name == nil then
        return "Unknown"
    end
    if Ambiguate then
        local ok, result = pcall(Ambiguate, name, "short")
        if ok and result then
            return result
        end
    end
    return name
end

local function GetClassColor(classFilename)
    if IsSecret(classFilename) then
        return GetAccentColor()
    end
    if classFilename and RAID_CLASS_COLORS then
        local color = RAID_CLASS_COLORS[classFilename]
        if color then
            return color.r, color.g, color.b
        end
    end
    return GetAccentColor()
end

-- Damage-meter amounts become secret numbers while combat is active. StatusBar
-- setters are allowed to receive those values directly; inspecting or replacing
-- them destroys the live fill (the old code converted every secret amount to 0,
-- leaving only the black row background visible).
local function GetStatusBarAmount(value, fallback, requirePositive)
    if IsSecret(value) then
        return value
    end
    if type(value) ~= "number" or (requirePositive and value <= 0) then
        return fallback
    end
    return value
end

local function GetReadableSessionTotal(session, sources)
    local total = session and session.totalAmount
    if not IsSecret(total) and type(total) == "number" and total > 0 then
        return total
    end

    -- Preview and older saved snapshots may not expose a session total.
    -- Build it only from ordinary numbers; never add protected combat values.
    total = 0
    for _, source in ipairs(sources or {}) do
        local amount = type(source) == "table" and source.totalAmount
        if IsSecret(amount) then return nil end
        if type(amount) == "number" then total = total + amount end
    end
    return total > 0 and total or nil
end

local function ApplyFontReadability(fontString)
    if not fontString then
        return
    end
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
end

local function SetSingleLine(fontString)
    if not fontString then return end
    fontString:SetWordWrap(false)
    if fontString.SetNonSpaceWrap then fontString:SetNonSpaceWrap(false) end
    if fontString.SetMaxLines then fontString:SetMaxLines(1) end
end

local function GetDamageMeterIconMode(cfg)
    cfg = cfg or GetConfig()
    local mode = cfg.iconMode
    if mode ~= "spec" and mode ~= "class" and mode ~= "none" then
        mode = cfg.showIcons == false and "none" or "spec"
    end
    if cfg.showIcons == false then
        return "none"
    end
    return mode
end

local DAMAGE_METER_ICON_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function SetDamageMeterIconShape(texture, shape)
    if not texture then
        return
    end

    local round = shape == "round"
    local mask = texture._kullThranRoundMask
    if round then
        if not mask then
            local parent = texture:GetParent()
            if not parent or not parent.CreateMaskTexture then
                return
            end
            mask = parent:CreateMaskTexture()
            mask:SetAllPoints(texture)
            mask:SetTexture(DAMAGE_METER_ICON_MASK)
            texture._kullThranRoundMask = mask
        end
        if not texture._kullThranRoundMaskAttached then
            local ok = pcall(texture.AddMaskTexture, texture, mask)
            texture._kullThranRoundMaskAttached = ok
        end
        mask:Show()
    elseif mask then
        if texture._kullThranRoundMaskAttached and texture.RemoveMaskTexture then
            pcall(texture.RemoveMaskTexture, texture, mask)
            texture._kullThranRoundMaskAttached = false
        end
        mask:Hide()
    end
end

local function ApplyClassIcon(texture, source, cfg)
    SetDamageMeterIconShape(texture, cfg and cfg.iconShape)
    local mode = GetDamageMeterIconMode(cfg)
    if mode == "none" then
        texture:Hide()
        return false
    end

    local classFilename = source and source.classFilename
    if mode == "class" then
        if not IsSecret(classFilename) and classFilename and CLASS_ICON_TCOORDS then
            local coords = CLASS_ICON_TCOORDS[classFilename]
            if coords then
                texture:SetTexture(CLASS_TEXTURE)
                texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                texture:SetVertexColor(1, 1, 1, 1)
                texture:Show()
                return true
            end
        end
        texture:Hide()
        return false
    end

    local specIconID = source and source.specIconID
    if type(specIconID) == "number" and not IsSecret(specIconID) and specIconID > 0 then
        texture:SetTexture(specIconID)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        texture:SetVertexColor(1, 1, 1, 1)
        texture:Show()
        return true
    end

    -- Preserve the old safe fallback when a source has no specialization icon.
    if not IsSecret(classFilename) and classFilename and CLASS_ICON_TCOORDS then
        local coords = CLASS_ICON_TCOORDS[classFilename]
        if coords then
            texture:SetTexture(CLASS_TEXTURE)
            texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            texture:SetVertexColor(1, 1, 1, 1)
            texture:Show()
            return true
        end
    end

    texture:Hide()
    return false
end

local function StyleHeaderButton(button)
    if not button then
        return
    end
    if KT.AddBackdrop then
        KT:AddBackdrop(button, 0, 0, 0, 0)
    end
    if button.borderKT and button.borderKT.Hide then
        button.borderKT:Hide()
    end
    if button.text then
        button.text:SetTextColor(1, 1, 1, 1)
        ApplyFontReadability(button.text)
    end
end

local function CreateHeaderButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetHeight(22)
    button.arrow = button:CreateTexture(nil, "OVERLAY")
    button.arrow:SetTexture(DROPDOWN_ARROW)
    -- Preserve the source texture's 3:2 aspect ratio. Squashing it to a
    -- square can reduce the two diagonal strokes to isolated pixels.
    button.arrow:SetSize(15, 10)
    button.arrow:SetPoint("RIGHT", button, "RIGHT", -5, 0)
    button.arrow:SetVertexColor(0.82, 0.82, 0.86, 1)
    SetHeaderArrowExpanded(button, false)

    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
    ApplyFontReadability(button.text)
    button.text:SetPoint("LEFT", 7, 0)
    button.text:SetPoint("RIGHT", button.arrow, "LEFT", -3, 0)
    button.text:SetJustifyH("CENTER")
    button:SetScript("OnEnter", function(self)
        local r, g, b = GetAccentColor()
        if self.text then
            self.text:SetTextColor(r, g, b, 1)
        end
        if self.arrow then
            self.arrow:SetVertexColor(r, g, b, 1)
        end
    end)
    button:SetScript("OnLeave", function(self)
        if self.arrow then
            self.arrow:SetVertexColor(0.82, 0.82, 0.86, 1)
        end
        StyleHeaderButton(self)
    end)
    StyleHeaderButton(button)
    return button
end

-- Actor totals come from C_DamageMeter. Spell/target relations are indexed
-- locally because Blizzard's public session result does not include them.
local breakdownStore = {}
local BuildNativeBreakdownSession

local function SavedBreakdownSession(frame)
    local saved = frame and FindSavedCombatSession(frame.selectedHistoryKey)
    local session = saved and saved.breakdown
    if not (session and type(session.actors) == "table") then return nil end
    session.names = session.names or {}
    if not session._namesRebuilt then
        for _, actor in pairs(session.actors) do
            if type(actor.name) == "string" then
                session.names[actor.name:lower()] = actor
                session.names[ShortName(actor.name):lower()] = actor
            end
        end
        session._namesRebuilt = true
    end
    return session
end

local function ResetBreakdown(key)
    breakdownStore[key] = { started = GetTime(), duration = 0, actors = {}, names = {} }
end

local function BreakdownSession(frame)
    if frame and frame.selectedSessionID and BuildNativeBreakdownSession then
        local native = BuildNativeBreakdownSession(frame)
        if native and next(native.actors or {}) then return native end
    end
    if frame and frame.selectedHistoryKey then
        local saved = SavedBreakdownSession(frame)
        if saved then return saved end
    end
    local cfg = GetFrameConfig(frame)
    return (BuildNativeBreakdownSession and BuildNativeBreakdownSession(frame))
        or breakdownStore[cfg.session == "overall" and "overall" or "current"]
end

local function ActorClass(guid)
    if not guid or IsSecret(guid) or not _G.GetPlayerInfoByGUID then return nil end
    local ok, _, class = pcall(_G.GetPlayerInfoByGUID, guid)
    return ok and class or nil
end

local function SpecIconFromID(specID)
    if type(specID) ~= "number" or specID <= 0 or not _G.GetSpecializationInfoByID then return nil end
    local ok, _, _, _, icon = pcall(_G.GetSpecializationInfoByID, specID)
    return ok and type(icon) == "number" and icon > 0 and icon or nil
end

local function ActorSpecIcon(guid)
    if not guid or IsSecret(guid) then return nil end
    local playerGUID = _G.UnitGUID and _G.UnitGUID("player")
    if not IsSecret(playerGUID) and guid == playerGUID and _G.GetSpecialization and _G.GetSpecializationInfo then
        local specIndex = _G.GetSpecialization()
        if specIndex then
            local ok, _, _, _, icon = pcall(_G.GetSpecializationInfo, specIndex)
            if ok and type(icon) == "number" and icon > 0 then return icon end
        end
    end
    if not (_G.UnitGUID and _G.GetInspectSpecialization) then return nil end
    local units = {}
    if _G.IsInRaid and _G.IsInRaid() then
        for index = 1, (_G.GetNumGroupMembers and _G.GetNumGroupMembers() or 0) do units[#units + 1] = "raid" .. index end
    elseif _G.IsInGroup and _G.IsInGroup() then
        units[#units + 1] = "player"
        for index = 1, (_G.GetNumSubgroupMembers and _G.GetNumSubgroupMembers() or 0) do units[#units + 1] = "party" .. index end
    end
    for _, unit in ipairs(units) do
        local unitGUID = _G.UnitGUID(unit)
        if not IsSecret(unitGUID) and unitGUID == guid then
            local ok, specID = pcall(_G.GetInspectSpecialization, unit)
            if ok then return SpecIconFromID(specID) end
        end
    end
end
local function BreakdownActor(session, guid, name)
    if IsSecret(guid) then guid = nil end
    if IsSecret(name) or type(name) ~= "string" then return nil end
    if not session then return nil end
    local key = guid or name
    local actor = session.actors[key]
    if not actor then
        actor = {
            guid = guid, name = ShortName(name), classFilename = ActorClass(guid), specIconID = ActorSpecIcon(guid),
            damageDone = { total = 0, spells = {}, targets = {} },
            healingDone = { total = 0, spells = {}, targets = {} },
            damageTaken = { total = 0, spells = {}, targets = {} },
            interrupts = { total = 0, spells = {}, targets = {} },
            dispels = { total = 0, spells = {}, targets = {} },
            deaths = { total = 0, spells = {}, targets = {} },
        }
        session.actors[key] = actor
    end
    if type(actor.name) == "string" then session.names[actor.name:lower()] = actor end
    if type(name) == "string" then session.names[name:lower()] = actor end
    return actor
end

local function RecordBreakdown(session, guid, name, bucketKey, amount, spellKey, spellName, icon, targetGUID, targetName)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    local actor = BreakdownActor(session, guid, name)
    local bucket = actor and actor[bucketKey]
    if not bucket then return end
    spellKey, targetName = spellKey or spellName or "unknown", ShortName(targetName or LText("Unknown"))
    local targetKey = targetGUID or targetName
    bucket.total = bucket.total + amount
    local spell = bucket.spells[spellKey]
    if not spell then
        spell = { key = spellKey, name = spellName or LText("Unknown"), icon = icon, amount = 0, targets = {} }
        bucket.spells[spellKey] = spell
    end
    spell.amount = spell.amount + amount
    spell.targets[targetKey] = (spell.targets[targetKey] or 0) + amount
    local target = bucket.targets[targetKey]
    if not target then
        target = { key = targetKey, name = targetName, icon = TARGET_ICON, kind = "target", amount = 0, spells = {} }
        bucket.targets[targetKey] = target
    end
    target.amount = target.amount + amount
    target.spells[spellKey] = (target.spells[spellKey] or 0) + amount
end

local nativeBreakdownCache

local function ResolveNativeSourceGUID(source)
    if IsSecret(source) or type(source) ~= "table" then return nil end
    local guid = source.sourceGUID
    if not IsSecret(guid) and type(guid) == "string" then
        return guid
    end
    local isLocalPlayer = source.isLocalPlayer
    if not IsSecret(isLocalPlayer) and isLocalPlayer == true and _G.UnitGUID then
        local playerGUID = _G.UnitGUID("player")
        return not IsSecret(playerGUID) and playerGUID or nil
    end
end

local function ResolveNativeSourceName(source)
    if IsSecret(source) or type(source) ~= "table" then return nil end
    local isLocalPlayer = source.isLocalPlayer
    if not IsSecret(isLocalPlayer) and isLocalPlayer == true then
        local name, realm
        if _G.UnitFullName then
            name, realm = _G.UnitFullName("player")
        elseif _G.UnitName then
            name, realm = _G.UnitName("player")
        end
        if not IsSecret(name) and type(name) == "string" then
            if not IsSecret(realm) and type(realm) == "string" and realm ~= "" then
                return name .. "-" .. realm
            end
            return name
        end
    end
    local name = source.name
    return not IsSecret(name) and type(name) == "string" and name or nil
end

local function IsLocalDamageMeterSource(source, playerGUID, playerName, playerRealm)
    if IsSecret(source) or type(source) ~= "table" then return false end
    local isLocalPlayer = source.isLocalPlayer
    if not IsSecret(isLocalPlayer) and isLocalPlayer == true then
        return true
    end
    local sourceGUID = ResolveNativeSourceGUID(source)
    if playerGUID and sourceGUID == playerGUID then
        return true
    end
    if not playerName or IsSecret(playerName) then return false end
    local sourceName = ResolveNativeSourceName(source)
    if IsSecret(sourceName) or type(sourceName) ~= "string" then return false end
    local sourceShortName = sourceName:match("^([^%-]+)") or sourceName
    local playerFullName = playerName
    if not IsSecret(playerRealm) and type(playerRealm) == "string" and playerRealm ~= "" then
        playerFullName = playerName .. "-" .. playerRealm
    end
    return sourceName == playerName or sourceName == playerFullName or sourceShortName == playerName
end

local function GetNativeSegment(frame, meterType)
    local api = _G.C_DamageMeter
    if not api or meterType == nil then return nil end
    if frame and frame.selectedSessionID and api.GetCombatSessionFromID then
        local ok, result = pcall(api.GetCombatSessionFromID, frame.selectedSessionID, meterType)
        return ok and not IsSecret(result) and type(result) == "table" and result or nil
    end
    if api.GetCombatSessionFromType then
        local sessionType = ResolveSession(GetFrameConfig(frame).session)
        local ok, result = pcall(api.GetCombatSessionFromType, sessionType, meterType)
        return ok and not IsSecret(result) and type(result) == "table" and result or nil
    end
end

local function GetNativeSpells(frame, meterType, sourceGUID, sourceCreatureID)
    local api = _G.C_DamageMeter
    if not api then return nil end
    local ok, result
    if frame and frame.selectedSessionID and api.GetCombatSessionSourceFromID then
        ok, result = pcall(api.GetCombatSessionSourceFromID, frame.selectedSessionID, meterType, sourceGUID, sourceCreatureID)
    elseif api.GetCombatSessionSourceFromType then
        ok, result = pcall(api.GetCombatSessionSourceFromType,
            ResolveSession(GetFrameConfig(frame).session), meterType, sourceGUID, sourceCreatureID)
    end
    return ok and not IsSecret(result) and type(result) == "table" and result or nil
end

local function ResolveNativeCombatSpell(spell, classFilename, spellIndex)
    local rawSpellID
    local creatureName
    if not IsSecret(spell) and type(spell) == "table" then
        -- Assign directly. Appending `or nil` would evaluate the truthiness of
        -- the protected value and taint this execution path.
        rawSpellID = spell.spellID
        creatureName = spell.creatureName
    end
    local protectedSpellID = IsSecret(rawSpellID)
    local spellID = not protectedSpellID and type(rawSpellID) == "number" and rawSpellID or nil
    if IsSecret(creatureName) or type(creatureName) ~= "string" or creatureName == "" then creatureName = nil end

    -- Protected C_DamageMeter spell IDs are still valid inputs for C_Spell.
    -- Never coerce or use them as Lua table keys: doing so produced the false
    -- 0/1 labels and can taint every later lookup in the breakdown table.
    local lookupID
    if protectedSpellID then
        lookupID = rawSpellID
    else
        lookupID = spellID
    end
    local info
    local nativeName
    local nativeIcon
    if (protectedSpellID or lookupID ~= nil) and _G.C_Spell then
        if _G.C_Spell.GetSpellInfo then
            local ok, value = pcall(_G.C_Spell.GetSpellInfo, lookupID)
            if ok and not IsSecret(value) and type(value) == "table" then info = value end
        end
        if info then
            nativeName = info.name
            nativeIcon = info.iconID
        end
        -- These focused APIs accept protected spell identifiers and return
        -- display-safe values that can be forwarded directly to UI regions.
        if _G.C_Spell.GetSpellName then
            local ok, value = pcall(_G.C_Spell.GetSpellName, lookupID)
            if ok then nativeName = value end
        end
        if _G.C_Spell.GetSpellTexture then
            local ok, value = pcall(_G.C_Spell.GetSpellTexture, lookupID)
            if ok then nativeIcon = value end
        end
    end
    local protectedName = IsSecret(nativeName)
    local protectedIcon = IsSecret(nativeIcon)
    if not protectedName and (type(nativeName) ~= "string" or nativeName == "") then nativeName = nil end
    if not protectedIcon and (type(nativeIcon) ~= "number" or nativeIcon <= 0) then nativeIcon = nil end

    local name
    if protectedName then
        name = nativeName
    elseif nativeName and creatureName then
        name = nativeName .. " (" .. ShortName(creatureName) .. ")"
    else
        name = nativeName or (creatureName and ShortName(creatureName)) or LText("Unknown")
    end

    -- A protected value must never become a key. The native array slot is an
    -- accessible, stable key for the lifetime of this rebuilt snapshot.
    local key = protectedSpellID and ("protected:" .. tostring(spellIndex or 0))
        or spellID or ("unknown:" .. tostring(spellIndex or 0))
    if creatureName then key = tostring(key) .. ":creature:" .. creatureName end

    local icon
    if protectedIcon then
        icon = nativeIcon
    else
        icon = nativeIcon or (creatureName and PET_FALLBACK_ICON) or SPELL_FALLBACK_ICON
    end
    return key, name, icon, spellID, protectedName, protectedIcon
end

local function AddNativeSpells(session, frame, actor, meterType, bucketKey, source, yieldStep)
    local rawSourceGUID
    local sourceCreatureID
    if not IsSecret(source) and type(source) == "table" then
        -- Protected GUIDs are valid opaque inputs for C_DamageMeter. Do not
        -- compare, stringify or use them as table keys; forward them directly.
        rawSourceGUID = source.sourceGUID
        sourceCreatureID = source.sourceCreatureID
    end
    if IsSecret(sourceCreatureID) then sourceCreatureID = nil end
    -- Blizzard resolves player sources by GUID and creature/pet sources by
    -- creature ID. Passing both can resolve a different aggregate (or no
    -- aggregate at all) on the current Damage Meter API.
    local lookupGUID, lookupCreatureID
    if IsSecret(rawSourceGUID) then
        lookupGUID = rawSourceGUID
    elseif type(rawSourceGUID) == "string" and rawSourceGUID ~= "" then
        lookupGUID = rawSourceGUID
    else
        lookupCreatureID = sourceCreatureID
    end
    local container = GetNativeSpells(frame, meterType, lookupGUID, lookupCreatureID)
    local combatSpells
    if container then combatSpells = container.combatSpells end
    if IsSecret(combatSpells) or type(combatSpells) ~= "table" then return end
    for spellIndex, spell in ipairs(combatSpells) do
        if IsSecret(spell) or type(spell) ~= "table" then return end
        local amount = spell.totalAmount
        if not IsSecret(amount) and type(amount) == "number" and amount > 0 then
            local amountPerSecond = spell.amountPerSecond
            if IsSecret(amountPerSecond) or type(amountPerSecond) ~= "number" then amountPerSecond = nil end
            local spellKey, name, icon, spellID, protectedName, protectedIcon = ResolveNativeCombatSpell(spell, actor.classFilename, spellIndex)
            local bucket = actor[bucketKey]
            local entry = bucket.spells[spellKey]
            if not entry then
                entry = { key = spellKey, spellID = spellID, name = name, icon = icon, protectedName = protectedName,
                    protectedIcon = protectedIcon, amount = 0, amountPerSecond = 0, targets = {} }
                bucket.spells[spellKey] = entry
            end
            entry.amount = entry.amount + amount
            if amountPerSecond then entry.amountPerSecond = entry.amountPerSecond + amountPerSecond end
        end
        if yieldStep and spellIndex % 8 == 0 then yieldStep() end
    end
end

local function AddNativeActors(session, frame, meterType, bucketKey, yieldStep)
    local segment = GetNativeSegment(frame, meterType)
    if not segment then return end
    local duration = segment.durationSeconds
    if not IsSecret(duration) and type(duration) == "number" and duration > 0 then
        session.duration = math.max(session.duration or 0, duration)
    end
    local combatSources = segment.combatSources
    if IsSecret(combatSources) or type(combatSources) ~= "table" then return end
    for sourceIndex, source in ipairs(combatSources) do
        if IsSecret(source) or type(source) ~= "table" then return end
        local name = ResolveNativeSourceName(source)
        local total = source.totalAmount
        if name and not IsSecret(total) and type(total) == "number" then
            local sourceGUID = ResolveNativeSourceGUID(source)
            local actor = BreakdownActor(session, sourceGUID, name)
            actor.classFilename = not IsSecret(source.classFilename) and source.classFilename or actor.classFilename
            local sourceSpecIcon = not IsSecret(source.specIconID) and source.specIconID or nil
            actor.specIconID = (type(sourceSpecIcon) == "number" and sourceSpecIcon > 0 and sourceSpecIcon)
                or actor.specIconID or ActorSpecIcon(sourceGUID)
            AddNativeSpells(session, frame, actor, meterType, bucketKey, source, yieldStep)
            actor[bucketKey].total = total
        end
        if yieldStep and sourceIndex % 4 == 0 then yieldStep() end
    end
end

local function AddNativeTargets(session, frame, yieldStep)
    -- Type 10 is the target-centric source table used by Blizzard's current
    -- DamageMeter implementation. Each spell detail identifies the group
    -- player (unitName) responsible for that amount against the target.
    local targetType = ResolveMode("enemyDamageTaken") or 10
    local segment = GetNativeSegment(frame, targetType)
    if not segment then return end
    local combatSources = segment.combatSources
    if IsSecret(combatSources) or type(combatSources) ~= "table" then return end
    for targetIndex, targetSource in ipairs(combatSources) do
        if IsSecret(targetSource) or type(targetSource) ~= "table" then return end
        local targetName = targetSource.name
        local creatureID = targetSource.sourceCreatureID
        if not IsSecret(targetName) and type(targetName) == "string" and not IsSecret(creatureID) then
            -- Match Blizzard/Details' target lookup: target-centric records
            -- are addressed by creature ID, not by the transient unit GUID.
            local container = GetNativeSpells(frame, targetType, nil, creatureID)
            local combatSpells
            if container then combatSpells = container.combatSpells end
            if IsSecret(combatSpells) or type(combatSpells) ~= "table" then return end
            for spellIndex, result in ipairs(combatSpells) do
                if IsSecret(result) or type(result) ~= "table" then return end
                local details = result.combatSpellDetails
                local playerName
                if not IsSecret(details) and type(details) == "table" then playerName = details.unitName end
                local amount = result.totalAmount
                if not IsSecret(playerName) and type(playerName) == "string"
                    and not IsSecret(amount) and type(amount) == "number" and amount > 0 then
                    local amountPerSecond = result.amountPerSecond
                    if IsSecret(amountPerSecond) or type(amountPerSecond) ~= "number" then amountPerSecond = nil end
                    local actor = session.names[playerName:lower()] or session.names[ShortName(playerName):lower()]
                    local bucket = actor and actor.damageDone
                    if bucket then
                        local key = "creature:" .. tostring(creatureID or 0) .. ":" .. targetName
                        local target = bucket.targets[key]
                        if not target then
                            target = { key = key, name = targetName, icon = TARGET_ICON, kind = "target",
                                amount = 0, amountPerSecond = 0, spells = {} }
                            bucket.targets[key] = target
                        end
                        target.amount = target.amount + amount
                        if amountPerSecond then target.amountPerSecond = target.amountPerSecond + amountPerSecond end
                        local spellKey, _, _, spellID = ResolveNativeCombatSpell(result, actor.classFilename, spellIndex)
                        local spell = bucket.spells[spellKey]
                        if not spell and spellID then
                            for _, candidate in pairs(bucket.spells) do
                                if candidate.spellID == spellID then
                                    spell, spellKey = candidate, candidate.key
                                    break
                                end
                            end
                        end
                        if spell then
                            target.spells[spellKey] = (target.spells[spellKey] or 0) + amount
                            spell.targets[key] = (spell.targets[key] or 0) + amount
                        end
                    end
                end
                if yieldStep and spellIndex % 8 == 0 then yieldStep() end
            end
        end
        if yieldStep and targetIndex % 3 == 0 then yieldStep() end
    end
end

BuildNativeBreakdownSession = function(frame, yieldStep)
    local api = _G.C_DamageMeter
    if not api then return nil end
    local cfg = GetFrameConfig(frame)
    local requestedMode = NormalizeHistoryMode(cfg.mode or "damageDone")
    local buildAllModes = yieldStep ~= nil
    local cacheKey = table.concat({
        tostring(frame and frame.selectedSessionID or cfg.session),
        buildAllModes and "all" or requestedMode,
    }, ":")
    local now = GetTime()
    if nativeBreakdownCache and nativeBreakdownCache.key == cacheKey
        and now - nativeBreakdownCache.stamp < 0.2 then
        return nativeBreakdownCache.session
    end

    local session = { started = now, duration = 1, actors = {}, names = {} }
    if buildAllModes then
        for _, mode in ipairs({ "damageDone", "healingDone", "damageTaken", "interrupts", "dispels", "deaths" }) do
            AddNativeActors(session, frame, ResolveMode(mode), mode, yieldStep)
            yieldStep()
        end
        AddNativeTargets(session, frame, yieldStep)
    else
        AddNativeActors(session, frame, ResolveMode(requestedMode), requestedMode)
        if requestedMode == "damageDone" then AddNativeTargets(session, frame) end
    end
    nativeBreakdownCache = { key = cacheKey, stamp = now, session = session }
    return session
end

local HISTORY_MODE_KEYS = {
    "damageDone", "healingDone", "damageTaken", "enemyDamageTaken",
    "avoidableDamageTaken", "interrupts", "dispels", "deaths",
}

local HISTORY_SOURCE_FIELDS = {
    "name", "classFilename", "specIconID", "totalAmount", "amountPerSecond",
    "sourceGUID", "sourceCreatureID", "deathRecapID",
}

local DEATH_RECAP_EVENT_FIELDS = {
    "event", "timestamp", "spellId", "spellName", "sourceName",
    "amount", "overkill", "currentHP",
}

local function CopyDeathRecap(source, copy)
    local recapID = source and source.deathRecapID
    local api = _G.C_DeathRecap
    if IsSecret(recapID) or type(recapID) ~= "number" or recapID <= 0
        or not (api and api.GetRecapEvents) then
        return
    end

    local ok, rawEvents = pcall(api.GetRecapEvents, recapID)
    if ok and not IsSecret(rawEvents) and type(rawEvents) == "table" then
        local events = {}
        for _, event in ipairs(rawEvents) do
            if not IsSecret(event) and type(event) == "table" then
                local eventCopy = {}
                for _, field in ipairs(DEATH_RECAP_EVENT_FIELDS) do
                    local value = event[field]
                    if value ~= nil and not IsSecret(value) then
                        local valueType = type(value)
                        if valueType == "string" or valueType == "number" or valueType == "boolean" then
                            eventCopy[field] = value
                        end
                    end
                end
                if next(eventCopy) then events[#events + 1] = eventCopy end
            end
        end
        if #events > 0 then copy.deathRecapEvents = events end
    end

    if api.GetRecapMaxHealth then
        local healthOK, maxHealth = pcall(api.GetRecapMaxHealth, recapID)
        if healthOK and not IsSecret(maxHealth) and type(maxHealth) == "number" and maxHealth > 0 then
            copy.deathRecapMaxHealth = maxHealth
        end
    end
end

local function CopyHistorySource(source)
    if type(source) ~= "table" then return nil end
    local copy = {}
    for _, field in ipairs(HISTORY_SOURCE_FIELDS) do
        local value = source[field]
        if value ~= nil and not IsSecret(value) then
            local valueType = type(value)
            if valueType == "string" or valueType == "number" or valueType == "boolean" then
                copy[field] = value
            end
        end
    end
    CopyDeathRecap(source, copy)
    return next(copy) and copy or nil
end

local function CopySerializable(value, depth, seen, yieldStep, copyState)
    if IsSecret(value) then return nil end
    local valueType = type(value)
    if valueType == "string" or valueType == "number" or valueType == "boolean" then return value end
    if valueType ~= "table" or depth <= 0 then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local copy = {}
    for key, child in pairs(value) do
        if yieldStep then
            copyState = copyState or { count = 0 }
            copyState.count = copyState.count + 1
            if copyState.count % 64 == 0 then yieldStep() end
        end
        local keyType = type(key)
        if (keyType == "string" or keyType == "number") and not (keyType == "string" and key:sub(1, 1) == "_") then
            local childCopy = CopySerializable(child, depth - 1, seen, yieldStep, copyState)
            if childCopy ~= nil then copy[key] = childCopy end
        end
    end
    seen[value] = nil
    return copy
end

local function SnapshotNativeCombatSession(sessionInfo, index, yieldStep)
    if IsSecret(sessionInfo) or type(sessionInfo) ~= "table" then return nil end
    local api = _G.C_DamageMeter
    local sessionID = sessionInfo and sessionInfo.sessionID
    local key = BuildSessionStorageKey(sessionInfo, index)
    if not (api and key and sessionID ~= nil and not IsSecret(sessionID)) then return nil end

    local name = sessionInfo.name
    if IsSecret(name) or type(name) ~= "string" or name == "" then name = string.format(LText("Combat %d"), index or 1) end
    local duration = sessionInfo.durationSeconds
    if IsSecret(duration) or type(duration) ~= "number" then duration = 0 end
    local snapshot = {
        key = key,
        nativeID = sessionID,
        name = name,
        durationSeconds = duration,
        capturedAt = _G.time and _G.time() or 0,
        modes = {},
    }

    for _, modeKey in ipairs(HISTORY_MODE_KEYS) do
        local meterType = ResolveMode(modeKey)
        if meterType ~= nil and api.GetCombatSessionFromID then
            local ok, nativeSession = pcall(api.GetCombatSessionFromID, sessionID, meterType)
            if ok and not IsSecret(nativeSession) and type(nativeSession) == "table"
                and not IsSecret(nativeSession.combatSources) and type(nativeSession.combatSources) == "table" then
                local sources = {}
                for sourceIndex, source in ipairs(nativeSession.combatSources) do
                    local copy = CopyHistorySource(source)
                    if copy then sources[#sources + 1] = copy end
                    if yieldStep and sourceIndex % 8 == 0 then yieldStep() end
                end
                snapshot.modes[modeKey] = { combatSources = sources }
            end
        end
        if yieldStep then yieldStep() end
    end

    local probe = { selectedSessionID = sessionID, damageMeterConfig = { session = "current", mode = "damageDone" } }
    local breakdown = BuildNativeBreakdownSession(probe, yieldStep)
    if breakdown and next(breakdown.actors or {}) then
        if yieldStep then yieldStep() end
        snapshot.breakdown = {
            started = 0,
            duration = duration,
            actors = CopySerializable(breakdown.actors, 8, {}, yieldStep, { count = 0 }),
            names = {},
        }
    end
    return snapshot
end

function Mod:CaptureDamageMeterHistory(yieldStep)
    if not IsDamageMeterModuleEnabled() then return end
    local api = _G.C_DamageMeter
    if not (api and api.GetAvailableCombatSessions) then return end
    local ok, sessions = pcall(api.GetAvailableCombatSessions)
    if not ok or IsSecret(sessions) or type(sessions) ~= "table" then return end

    -- Never retain Blizzard's session array across coroutine yields. Copy only
    -- the accessible scalar identity fields while the API result is valid, then
    -- release the protected container before beginning the incremental work.
    local sessionList = {}
    for index = 1, #sessions do
        local info = sessions[index]
        if not IsSecret(info) and type(info) == "table" then
            local sessionID = info.sessionID
            local name = info.name
            local duration = info.durationSeconds
            if not IsSecret(sessionID) and sessionID ~= nil then
                if IsSecret(name) or type(name) ~= "string" then name = nil end
                if IsSecret(duration) or type(duration) ~= "number" then duration = 0 end
                sessionList[#sessionList + 1] = {
                    index = index,
                    info = { sessionID = sessionID, name = name, durationSeconds = duration },
                }
            end
        end
    end
    sessions = nil

    local history = GetSavedCombatHistory()
    local oldByKey = {}
    for _, saved in ipairs(history.sessions) do oldByKey[saved.key] = saved end
    local nextSessions, included = {}, {}
    local firstIndex = math.max(1, #sessionList - MAX_SAVED_COMBAT_SESSIONS + 1)
    for listIndex = #sessionList, firstIndex, -1 do
        local entry = sessionList[listIndex]
        local index = entry.index
        local info = entry.info
        local key = BuildSessionStorageKey(info, index)
        local saved = key and oldByKey[key]
        if not saved then saved = SnapshotNativeCombatSession(info, index, yieldStep) end
        if saved and not included[saved.key] then
            nextSessions[#nextSessions + 1] = saved
            included[saved.key] = true
        end
    end
    for _, saved in ipairs(history.sessions) do
        if #nextSessions >= MAX_SAVED_COMBAT_SESSIONS then break end
        if saved.key and not included[saved.key] then
            nextSessions[#nextSessions + 1] = saved
            included[saved.key] = true
        end
    end
    history.sessions = nextSessions
end

function Mod:ScheduleDamageMeterHistoryCapture(delay)
    if not IsDamageMeterModuleEnabled() or self._damageHistoryCapturePending then return end
    self._damageHistoryCapturePending = true
    C_Timer.After(delay or 0.25, function()
        if not Mod then return end
        -- Snapshotting a BG can involve every player, spell and target. Keep the
        -- exact persisted data but yield between bounded chunks so the session
        -- commit cannot monopolize a single render frame.
        local job = coroutine.create(function()
            Mod:CaptureDamageMeterHistory(coroutine.yield)
        end)
        Mod._damageHistoryCaptureCoroutine = job

        local function ResumeCapture()
            if not Mod or Mod._damageHistoryCaptureCoroutine ~= job then return end
            local profiler = KT and KT.CombatProfiler
            local profileStarted = profiler and profiler:Begin("enh.damage.history.resume")
            local ok, err = coroutine.resume(job)
            if profileStarted then profiler:End("enh.damage.history.resume", profileStarted) end
            if not ok then
                Mod._damageHistoryCaptureCoroutine = nil
                Mod._damageHistoryCapturePending = nil
                error(err)
            elseif coroutine.status(job) == "dead" then
                Mod._damageHistoryCaptureCoroutine = nil
                Mod._damageHistoryCapturePending = nil
            else
                C_Timer.After(0.01, ResumeCapture)
            end
        end

        ResumeCapture()
    end)
end

function Mod:DAMAGE_METER_COMBAT_SESSION_UPDATED()
    local profiler = KT and KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("enh.damage.event.session")
    nativeBreakdownCache = nil
    if self.InvalidateDamageMeterDataCache then self:InvalidateDamageMeterDataCache() end
    self:ScheduleDamageMeterHistoryCapture(0.35)
    if self._damageMeterLiveRefresh then
        if not self._damageMeterTicker and self.StartDamageMeterLiveRefresh then
            self:StartDamageMeterLiveRefresh()
        end
    elseif self.ScheduleDamageMeterRefresh then
        self:ScheduleDamageMeterRefresh(0.1)
    end
    if profileStarted then profiler:End("enh.damage.event.session", profileStarted) end
end

function Mod:DAMAGE_METER_CURRENT_SESSION_UPDATED()
    local profiler = KT and KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("enh.damage.event.current")
    nativeBreakdownCache = nil
    if self.InvalidateDamageMeterDataCache then self:InvalidateDamageMeterDataCache() end
    if self.MarkDamageMeterCurrentSessionFresh then
        self:MarkDamageMeterCurrentSessionFresh()
    end
    -- This event can fire continuously throughout combat. Creating a delayed
    -- history capture for every emission produced thousands of timers in a BG.
    -- The shared combat ticker owns live repainting; history is captured when
    -- Blizzard commits the combat session instead.
    if self._damageMeterLiveRefresh then
        if not self._damageMeterTicker and self.StartDamageMeterLiveRefresh then
            self:StartDamageMeterLiveRefresh()
        end
    elseif self.ScheduleDamageMeterRefresh then
        self:ScheduleDamageMeterRefresh(0.15)
    end
    if profileStarted then profiler:End("enh.damage.event.current", profileStarted) end
end

function Mod:DAMAGE_METER_RESET()
    nativeBreakdownCache = nil
    if self.InvalidateDamageMeterDataCache then self:InvalidateDamageMeterDataCache() end
    if self.ScheduleDamageMeterRefresh then self:ScheduleDamageMeterRefresh(0) end
    -- Blizzard can emit this for automatic/session-scope resets during loading
    -- screens. Keep KUI's persisted history; the explicit Reset All action is
    -- the only operation that clears both native and saved data.
end

function Mod:PLAYER_LOGOUT()
    self:CaptureDamageMeterHistory()
end

ResetBreakdown("current")
ResetBreakdown("overall")

local function ModeBucket(actor, mode)
    if mode == "dps" then mode = "damageDone" elseif mode == "hps" then mode = "healingDone" end
    return actor and actor[mode]
end

local function FindBreakdownActor(frame, source)
    local session = BreakdownSession(frame)
    if not session or not source then return nil, session end
    local guid = ResolveNativeSourceGUID(source)
    if guid and session.actors[guid] then return session.actors[guid], session end
    local name = ShortName(source.name)
    if IsSecret(name) or type(name) ~= "string" then return nil, session end
    return session.names[name:lower()], session
end

local function SortedBreakdown(map, factory)
    local entries = {}
    for key, value in pairs(map or {}) do entries[#entries + 1] = factory and factory(key, value) or value end
    table.sort(entries, function(a, b) return (a.amount or 0) > (b.amount or 0) end)
    return entries
end

local function BreakdownRate(entryOrAmount, session)
    local entry = type(entryOrAmount) == "table" and entryOrAmount or nil
    local amount = entry and entry.amount or entryOrAmount
    local nativeRate = entry and entry.amountPerSecond
    if nativeRate ~= nil and not IsSecret(nativeRate) and type(nativeRate) == "number" then
        return FormatNumber(nativeRate)
    end
    local duration = session and (session.duration or 0) or 0
    if session and session.activeSince then duration = duration + (GetTime() - session.activeSince) end
    if duration <= 0 and session then duration = GetTime() - session.started end
    return FormatNumber((amount or 0) / math.max(1, duration))
end

local function GetDeathRecapEntries(source)
    if IsSecret(source) or type(source) ~= "table" then return nil end

    local rawEvents = source.deathRecapEvents
    local maxHealth = source.deathRecapMaxHealth
    local recapID = source.deathRecapID
    if IsSecret(rawEvents) or type(rawEvents) ~= "table" then
        local api = _G.C_DeathRecap
        if IsSecret(recapID) or type(recapID) ~= "number" or recapID <= 0
            or not (api and api.GetRecapEvents) then
            return nil
        end
        local ok
        ok, rawEvents = pcall(api.GetRecapEvents, recapID)
        if not ok or IsSecret(rawEvents) or type(rawEvents) ~= "table" then return nil end
        if api.GetRecapMaxHealth then
            local healthOK, value = pcall(api.GetRecapMaxHealth, recapID)
            if healthOK then maxHealth = value end
        end
    end
    if #rawEvents == 0 then return nil end

    local plainMaxHealth = not IsSecret(maxHealth) and type(maxHealth) == "number" and maxHealth > 0 and maxHealth or nil
    local newest = rawEvents[1]
    local deathTime = not IsSecret(newest) and type(newest) == "table" and newest.timestamp or nil
    if IsSecret(deathTime) or type(deathTime) ~= "number" then deathTime = nil end

    local entries = {}
    for rawIndex = #rawEvents, 1, -1 do
        local event = rawEvents[rawIndex]
        if not IsSecret(event) and type(event) == "table" then
            local eventType = event.event
            if IsSecret(eventType) or type(eventType) ~= "string" then eventType = "" end
            local isHeal = eventType == "SPELL_HEAL" or eventType == "SPELL_PERIODIC_HEAL"

            local spellID = event.spellId
            local protectedSpellID = IsSecret(spellID)
            local icon
            if (protectedSpellID or (spellID ~= nil and type(spellID) == "number" and spellID > 0))
                and _G.C_Spell and _G.C_Spell.GetSpellTexture then
                local iconOK, value = pcall(_G.C_Spell.GetSpellTexture, spellID)
                if iconOK then icon = value end
            end

            local spellName = event.spellName
            local protectedName = IsSecret(spellName)
            if not protectedName and (type(spellName) ~= "string" or spellName == "") then
                spellName = isHeal and LText("Heal")
                    or (eventType == "SWING_DAMAGE" and LText("Melee") or LText("Unknown"))
            end

            local currentHealth = event.currentHP
            local healthPercent
            if plainMaxHealth and not IsSecret(currentHealth) and type(currentHealth) == "number" then
                healthPercent = math.min(1, math.max(0, currentHealth / plainMaxHealth))
            end

            local timestamp = event.timestamp
            local timeBeforeDeath
            if deathTime and not IsSecret(timestamp) and type(timestamp) == "number" then
                timeBeforeDeath = math.max(0, deathTime - timestamp)
            end

            entries[#entries + 1] = {
                name = spellName,
                sourceName = event.sourceName,
                icon = icon or TARGET_ICON,
                protectedName = protectedName,
                protectedIcon = IsSecret(icon),
                kind = isHeal and "deathHeal" or "deathDamage",
                isHeal = isHeal,
                amount = event.amount or 0,
                overkill = event.overkill,
                healthPercent = healthPercent,
                timeBeforeDeath = timeBeforeDeath,
            }
        end
    end

    for index = #entries, 1, -1 do
        if not entries[index].isHeal then
            entries[index].isFatal = true
            entries[index].kind = "deathFatal"
            break
        end
    end
    return #entries > 0 and entries or nil
end

local function SetDeathRecapName(fontString, entry)
    local sourceName = entry.sourceName
    local hasSource = IsSecret(sourceName) or (type(sourceName) == "string" and sourceName ~= "")
    if entry.timeBeforeDeath then
        if hasSource then
            fontString:SetFormattedText("-%.1fs %s - %s", entry.timeBeforeDeath, entry.name, sourceName)
        else
            fontString:SetFormattedText("-%.1fs %s", entry.timeBeforeDeath, entry.name)
        end
    elseif hasSource then
        fontString:SetFormattedText("%s - %s", entry.name, sourceName)
    else
        fontString:SetFormattedText("%s", entry.name)
    end
end

local function SetDeathRecapValue(fontString, entry)
    local amount = entry.amount
    if IsSecret(amount) then
        fontString:SetFormattedText("%s", FormatNumber(amount))
    else
        amount = tonumber(amount) or 0
        local sign = entry.isHeal and "+" or "-"
        local health = entry.healthPercent and string.format("  %.0f%%", entry.healthPercent * 100) or ""
        local overkill = entry.isFatal and not IsSecret(entry.overkill)
            and type(entry.overkill) == "number" and entry.overkill > 0 and entry.overkill or nil
        if overkill then
            fontString:SetText(string.format("%s%s  (%s %s)%s", sign, FormatNumber(math.abs(amount)),
                FormatNumber(overkill), LText("Overkill"), health))
        else
            fontString:SetText(string.format("%s%s%s", sign, FormatNumber(math.abs(amount)), health))
        end
    end
    if entry.isHeal then
        fontString:SetTextColor(0.35, 1, 0.45, 1)
    elseif entry.isFatal then
        fontString:SetTextColor(1, 0.25, 0.25, 1)
    else
        fontString:SetTextColor(1, 1, 1, 1)
    end
end

local function HideDamageMeterTooltipRows()
    local tooltip = _G.GameTooltip
    local rows = tooltip and tooltip._ktDamageMeterRows
    if not tooltip then return end
    tooltip._ktDamageMeterRowIndex = 0
    if not rows then return end
    for _, texture in ipairs(rows) do texture:Hide() end
end

local function AddDamageMeterTooltipRow(lineIndex, rowIndex, kind)
    local tooltip = _G.GameTooltip
    if not tooltip or not tooltip.GetName then return end
    local tooltipName = tooltip:GetName()
    local left = tooltipName and _G[tooltipName .. "TextLeft" .. lineIndex]
    local right = tooltipName and _G[tooltipName .. "TextRight" .. lineIndex]
    if not left or not right then return end

    tooltip._ktDamageMeterRows = tooltip._ktDamageMeterRows or {}
    tooltip._ktDamageMeterRowIndex = (tooltip._ktDamageMeterRowIndex or 0) + 1
    local poolIndex = tooltip._ktDamageMeterRowIndex
    local texture = tooltip._ktDamageMeterRows[poolIndex]
    if not texture then
        texture = tooltip:CreateTexture(nil, "ARTWORK", nil, -7)
        tooltip._ktDamageMeterRows[poolIndex] = texture
    end

    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", left, "TOPLEFT", -3, 2)
    texture:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 3, -2)
    if kind == "target" then
        texture:SetColorTexture(0.34, 0.29, 0.13, rowIndex % 2 == 0 and 0.78 or 0.9)
    elseif kind == "deathHeal" then
        texture:SetColorTexture(0.06, 0.28, 0.09, rowIndex % 2 == 0 and 0.78 or 0.9)
    elseif kind == "deathFatal" then
        texture:SetColorTexture(0.52, 0.035, 0.035, 0.94)
    elseif kind == "deathDamage" then
        texture:SetColorTexture(0.30, 0.035, 0.035, rowIndex % 2 == 0 and 0.78 or 0.9)
    else
        local shade = rowIndex % 2 == 0 and 0.20 or 0.27
        texture:SetColorTexture(shade, shade, shade + 0.015, 0.9)
    end
    texture:Show()
end

local function ShowDeathRecapTooltip(row, source)
    local tooltip = _G.GameTooltip
    if not tooltip then return end
    local entries = GetDeathRecapEntries(source)
    HideDamageMeterTooltipRows()
    tooltip:SetOwner(row, "ANCHOR_LEFT")
    tooltip:ClearLines()
    tooltip:AddLine(ResolveNativeSourceName(source) or ShortName(source.name), 1, 0.82, 0)
    if not entries then
        tooltip:AddLine(LText("Death recap unavailable."), 0.72, 0.72, 0.76, true)
    else
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(LText("Death Recap"), LText("Amount") .. " / " .. LText("Health"), 1, 1, 1, 1, 0.82, 0)
        local startIndex = math.max(1, #entries - 5 + 1)
        for index = startIndex, #entries do
            local entry = entries[index]
            tooltip:AddDoubleLine("", "")
            local lineIndex = tooltip:NumLines()
            local tooltipName = tooltip:GetName()
            local left = tooltipName and _G[tooltipName .. "TextLeft" .. lineIndex]
            local right = tooltipName and _G[tooltipName .. "TextRight" .. lineIndex]
            if left then SetDeathRecapName(left, entry) end
            if right then SetDeathRecapValue(right, entry) end
            AddDamageMeterTooltipRow(lineIndex, index - startIndex + 1, entry.kind)
        end
        tooltip:AddLine(" ")
        tooltip:AddLine(LText("Click for a complete breakdown"), 0.68, 0.68, 0.74)
    end
    tooltip:Show()
end

local function TooltipSection(title, entries, total, session, limit, kind)
    if #entries == 0 then return end
    _G.GameTooltip:AddLine(" ")
    _G.GameTooltip:AddDoubleLine(title, LText("Amount") .. "     " .. LText("DPS") .. "     %", 1, 1, 1, 1, 0.82, 0)
    for index = 1, math.min(limit, #entries) do
        local entry = entries[index]
        local icon = not entry.protectedIcon and entry.icon and ("|T" .. entry.icon .. ":15:15:0:0:64:64:5:59:5:59|t ") or ""
        local values = string.format("%s     %s     %.1f%%", FormatNumber(entry.amount), BreakdownRate(entry, session),
            total > 0 and entry.amount / total * 100 or 0)
        if entry.protectedName then
            _G.GameTooltip:AddDoubleLine(entry.name, values, 1, 1, 1, 1, 0.82, 0)
        else
            _G.GameTooltip:AddDoubleLine(icon .. (entry.name or LText("Unknown")), values, 1, 1, 1, 1, 0.82, 0)
        end
        AddDamageMeterTooltipRow(_G.GameTooltip:NumLines(), index, kind)
    end
end
function Mod:ShowDamageMeterActorTooltip(row)
    local frame, source = row and row.damageMeterFrame, row and row.damageSource
    if not frame or not source or not _G.GameTooltip then return end
    if GetFrameConfig(frame).mode == "deaths" then
        ShowDeathRecapTooltip(row, source)
        return
    end
    local actor, session = FindBreakdownActor(frame, source)
    local bucket = ModeBucket(actor, GetFrameConfig(frame).mode)
    HideDamageMeterTooltipRows()
    _G.GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    _G.GameTooltip:ClearLines()
    _G.GameTooltip:AddLine(ResolveNativeSourceName(source) or ShortName(source.name), 1, 0.82, 0)
    if bucket then
        TooltipSection(LText("Spell Name"), SortedBreakdown(bucket.spells), bucket.total, session, 5, "spell")
        TooltipSection(LText("Targets"), SortedBreakdown(bucket.targets), bucket.total, session, 4, "target")
        _G.GameTooltip:AddLine(" ")
        _G.GameTooltip:AddLine(LText("Click for a complete breakdown"), 0.68, 0.68, 0.74)
    else
        _G.GameTooltip:AddLine(LText("Detailed data will be collected during combat."), 0.72, 0.72, 0.76, true)
    end
    _G.GameTooltip:Show()
end

local function CreateBreakdownList(parent, title, width, height, count)
    local list = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    list:SetSize(width, height)
    list.offset = 0
    list.visibleCount = count
    list:EnableMouseWheel(true)
    if KT.AddBackdrop then KT:AddBackdrop(list, 0.018, 0.02, 0.027, 0.96) end
    list.title = list:CreateFontString(nil, "OVERLAY")
    list.title:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
    ApplyFontReadability(list.title)
    list.title:SetPoint("TOPLEFT", 7, -6)
    list.title:SetText(title)
    list.range = list:CreateFontString(nil, "OVERLAY")
    list.range:SetFont(DAMAGE_METER_RESOLVED_FONT(), 10, "OUTLINE")
    ApplyFontReadability(list.range)
    list.range:SetPoint("TOPRIGHT", -7, -7)
    list.range:SetTextColor(0.62, 0.62, 0.68, 1)
    list.rows = {}
    local rowHeight = math.floor((height - 27) / count)
    for index = 1, count do
        local row = CreateFrame("Button", nil, list)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            local wheelHandler = list:GetScript("OnMouseWheel")
            if wheelHandler then wheelHandler(list, delta) end
        end)
        row:SetPoint("TOPLEFT", 5, -(22 + ((index - 1) * rowHeight)))
        row:SetPoint("TOPRIGHT", -5, -(22 + ((index - 1) * rowHeight)))
        row:SetHeight(rowHeight - 1)
        row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.06, 0.065, 0.085, index % 2 == 0 and 0.72 or 0.48)
        row.bar = row:CreateTexture(nil, "BORDER"); row.bar:SetPoint("TOPLEFT"); row.bar:SetPoint("BOTTOMLEFT")
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetPoint("LEFT", 2, 0); row.icon:SetSize(rowHeight - 3, rowHeight - 3)
        row.name = row:CreateFontString(nil, "OVERLAY"); row.name:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
        ApplyFontReadability(row.name)
        SetSingleLine(row.name)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 3, 0); row.name:SetPoint("RIGHT", -116, 0); row.name:SetJustifyH("LEFT")
        row.values = row:CreateFontString(nil, "OVERLAY"); row.values:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
        ApplyFontReadability(row.values)
        SetSingleLine(row.values)
        row.values:SetPoint("RIGHT", -2, 0); row.values:SetWidth(112); row.values:SetJustifyH("RIGHT")
        list.rows[index] = row
    end
    list:SetScript("OnMouseWheel", function(self, delta)
        local entries = self.entries or {}
        local maximumOffset = math.max(0, #entries - #self.rows)
        local nextOffset = math.max(0, math.min(maximumOffset, (self.offset or 0) - (delta * 3)))
        if nextOffset ~= self.offset then
            self.offset = nextOffset
            if self.Refresh then self:Refresh() end
        end
    end)
    return list
end

local function ApplyBreakdownIcon(texture, entry)
    if not texture or not entry then return end
    local icon = entry.icon
    if entry.protectedIcon then
        texture:SetTexture(icon)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif (type(icon) == "number" and not IsSecret(icon) and icon > 0) or (type(icon) == "string" and icon ~= "") then
        texture:SetTexture(icon)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif entry.classFilename and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[entry.classFilename] then
        local coords = CLASS_ICON_TCOORDS[entry.classFilename]
        texture:SetTexture(CLASS_TEXTURE)
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    elseif entry.kind == "target" then
        texture:SetTexture(TARGET_ICON)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        texture:SetTexture(entry.fallbackIcon or SPELL_FALLBACK_ICON)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    texture:SetVertexColor(1, 1, 1, 1)
    texture:Show()
end
local function IsCountMode(mode)
    return mode == "interrupts" or mode == "dispels" or mode == "deaths"
end

local function PopulateBreakdownList(list, entries, total, session, click, mode)
    list.entries, list.total, list.session = entries, total, session
    list.click, list.mode = click, mode
    list.offset = math.max(0, math.min(list.offset or 0, math.max(0, #entries - #list.rows)))
    list.Refresh = function(self)
        PopulateBreakdownList(self, self.entries or {}, self.total or 0, self.session, self.click, self.mode)
    end
    local maximum = 1
    if mode ~= "deathRecap" and mode ~= "deathActor" then
        maximum = entries[1] and entries[1].amount or 1
    end
    local firstIndex = list.offset + 1
    local lastIndex = math.min(#entries, list.offset + #list.rows)
    if #entries > #list.rows then
        list.range:SetText(string.format("%d-%d / %d", firstIndex, lastIndex, #entries))
        list.range:Show()
    else
        list.range:Hide()
    end
    for rowIndex, row in ipairs(list.rows) do
        local entryIndex = list.offset + rowIndex
        local entry = entries[entryIndex]
        if not entry then row:Hide() else
            row.entry = entry; ApplyBreakdownIcon(row.icon, entry)
            if list.selectedEntry == entry then
                local accentR, accentG, accentB = GetAccentColor()
                row.bg:SetColorTexture(accentR, accentG, accentB, 0.34)
            else
                row.bg:SetColorTexture(0.06, 0.065, 0.085, entryIndex % 2 == 0 and 0.72 or 0.48)
            end
            if mode == "deathRecap" then
                SetDeathRecapName(row.name, entry)
            elseif entry.protectedName then
                row.name:SetText(entry.name)
            else
                row.name:SetText(entryIndex .. ". " .. (entry.name or LText("Unknown")))
            end
            local percent = 0
            if mode == "deathRecap" then
                SetDeathRecapValue(row.values, entry)
            elseif mode == "deathActor" then
                row.values:SetText("")
                row.values:SetTextColor(1, 1, 1, 1)
            elseif IsCountMode(mode) then
                row.values:SetTextColor(1, 1, 1, 1)
                percent = total > 0 and entry.amount / total * 100 or 0
                row.values:SetText(string.format("%s  %.1f%%", FormatNumber(entry.amount), percent))
            else
                row.values:SetTextColor(1, 1, 1, 1)
                percent = total > 0 and entry.amount / total * 100 or 0
                row.values:SetText(string.format("%s  %s  %.1f%%", FormatNumber(entry.amount), BreakdownRate(entry, session), percent))
            end
            local r, g, b
            if mode == "deathRecap" then
                if entry.isHeal then
                    r, g, b = 0.08, 0.42, 0.12
                elseif entry.isFatal then
                    r, g, b = 0.78, 0.035, 0.035
                else
                    r, g, b = 0.48, 0.045, 0.045
                end
            elseif entry.classFilename then
                r, g, b = GetClassColor(entry.classFilename)
            elseif entry.kind == "target" then
                -- Targets use a muted gold to distinguish them from spell rows.
                r, g, b = 0.48, 0.40, 0.16
            else
                -- WoW does not expose icon pixel colors. Use a neutral Details-like
                -- spell bar, alternating slightly so adjacent abilities are clear.
                local shade = entryIndex % 2 == 0 and 0.34 or 0.43
                r, g, b = shade, shade, shade + 0.02
            end
            row.bar:SetColorTexture(r, g, b, 0.72)
            if mode == "deathRecap" then
                row.bar:SetWidth(math.max(1, (list:GetWidth() - 10) * (entry.healthPercent or 1)))
            elseif mode == "deathActor" then
                row.bar:SetWidth(list:GetWidth() - 10)
            else
                row.bar:SetWidth(math.max(1, (list:GetWidth() - 10) * entry.amount / math.max(1, maximum)))
            end
            row:SetScript("OnClick", click and function(self) click(self.entry) end or nil)
            row:Show()
        end
    end
end

local breakdownModes = {
    "damageDone", "dps", "healingDone", "hps",
    "damageTaken", "interrupts", "dispels", "deaths",
}
local RefreshBreakdownPanel

local function ApplyBreakdownBackgroundTheme(panel)
    local background = panel and panel.backgroundImage
    if not background then return end

    local skin = KT.db and KT.db.profile and KT.db.profile.skin
    local presetKey = skin and skin.stylePreset or "kui_crimson"
    local themeMode = skin and skin.borderTheme or "KULLTHRAN"
    if skin and skin.kullthranUIColorByClass then themeMode = "CLASS" end
    local useOriginalBackground = presetKey == "kui_crimson"
        and themeMode ~= "CLASS" and themeMode ~= "CUSTOM"

    if background.SetDesaturated then
        background:SetDesaturated(not useOriginalBackground)
    end
    if useOriginalBackground then
        background:SetVertexColor(1, 1, 1, 1)
    else
        local r, g, b = GetAccentColor()
        local lift = 0.15
        background:SetVertexColor(
            r + (1 - r) * lift,
            g + (1 - g) * lift,
            b + (1 - b) * lift,
            1
        )
    end
    background:SetAlpha(1)
    background:Show()
end

local function HasDeathRecap(source)
    if IsSecret(source) or type(source) ~= "table" then return false end
    if type(source.deathRecapEvents) == "table" and #source.deathRecapEvents > 0 then return true end
    local recapID = source.deathRecapID
    return not IsSecret(recapID) and type(recapID) == "number" and recapID > 0
end

local function SameDeathRecap(first, second)
    if first == second then return true end
    local firstID = first and first.deathRecapID
    local secondID = second and second.deathRecapID
    if IsSecret(firstID) or IsSecret(secondID) then return false end
    return firstID ~= nil and secondID ~= nil and firstID == secondID
end

local function RefreshDeathBreakdownPanel(panel)
    local sources = panel.sourceFrame and panel.sourceFrame._damageMeterSources or {}
    local actors = {}
    local selectedEntry
    for sourceIndex = #sources, 1, -1 do
        local source = sources[sourceIndex]
        if HasDeathRecap(source) then
            local name = ShortName(source.name)
            local entry = {
                source = source,
                name = name,
                protectedName = IsSecret(name),
                classFilename = not IsSecret(source.classFilename) and source.classFilename or nil,
                icon = not IsSecret(source.specIconID) and source.specIconID or nil,
                fallbackIcon = MODE_ICONS.deaths,
                kind = "actor",
                amount = 1,
            }
            actors[#actors + 1] = entry
            if SameDeathRecap(source, panel.damageSource) then selectedEntry = entry end
        end
    end
    if not selectedEntry then selectedEntry = actors[1] end
    panel.damageSource = selectedEntry and selectedEntry.source or panel.damageSource

    panel.actors.selectedEntry = selectedEntry
    PopulateBreakdownList(panel.actors, actors, #actors, nil, function(entry)
        panel.damageSource = entry.source
        panel.actors.offset, panel.spells.offset, panel.targets.offset, panel.relations.offset = 0, 0, 0, 0
        RefreshBreakdownPanel(panel)
    end, "deathActor")

    local entries = GetDeathRecapEntries(panel.damageSource)
    local fatal
    if entries then
        for index = #entries, 1, -1 do
            if entries[index].isFatal then fatal = entries[index]; break end
        end
    end
    panel.spells.title:SetText(LText("Death Recap"))
    panel.targets.title:SetText(LText("Killing Blow"))
    panel.relations.title:SetText(LText("Death Details"))
    panel.spells.selectedEntry, panel.targets.selectedEntry = nil, nil
    PopulateBreakdownList(panel.spells, entries or {}, 1, nil, nil, "deathRecap")
    PopulateBreakdownList(panel.targets, fatal and { fatal } or {}, 1, nil, nil, "deathRecap")
    PopulateBreakdownList(panel.relations, {}, 1, nil, nil, "deathRecap")
    panel.empty:SetText(LText("Death recap unavailable."))
    panel.empty:SetShown(not entries)

    local playerName = panel.damageSource and ShortName(panel.damageSource.name)
        or panel.actorName or LText("Damage Meter")
    panel.title:SetFormattedText("%s - %s", playerName, LText("Death Recap"))
    for _, button in ipairs(panel.modeButtons) do
        local r, g, b = GetAccentColor()
        local selected = button.mode == panel.mode
        button.text:SetTextColor(selected and r or 0.72, selected and g or 0.72, selected and b or 0.76)
        if button.icon then button.icon:SetAlpha(selected and 1 or 0.72) end
    end
end

RefreshBreakdownPanel = function(panel)
    ApplyBreakdownBackgroundTheme(panel)
    if panel.accentLine then
        local accentR, accentG, accentB = GetAccentColor()
        panel.accentLine:SetColorTexture(accentR, accentG, accentB, 1)
    end
    if panel.mode == "deaths" then
        RefreshDeathBreakdownPanel(panel)
        return
    end
    panel.spells.title:SetText(LText("Spells"))
    panel.targets.title:SetText(LText("Targets"))
    panel.relations.title:SetText(LText("Select a spell or target"))
    panel.empty:SetText(LText("Detailed data will be collected during combat."))
    local session, actors = panel.sourceFrame and BreakdownSession(panel.sourceFrame), {}
    if session then
        for _, actor in pairs(session.actors) do
            local bucket = ModeBucket(actor, panel.mode)
            if bucket and bucket.total > 0 then
                actors[#actors + 1] = { actor = actor, name = actor.name, classFilename = actor.classFilename, icon = actor.specIconID, fallbackIcon = MODE_ICONS[panel.mode], kind = "actor", amount = bucket.total }
            end
        end
        table.sort(actors, function(a, b) return a.amount > b.amount end)
    end
    if not panel.actor and session and panel.actorName then panel.actor = session.names[panel.actorName:lower()] end
    if not panel.actor and actors[1] then panel.actor = actors[1].actor end
    PopulateBreakdownList(panel.actors, actors, actors[1] and actors[1].amount or 0, session, function(entry)
        panel.actor, panel.spell, panel.target = entry.actor, nil, nil
        panel.spells.offset, panel.targets.offset, panel.relations.offset = 0, 0, 0
        RefreshBreakdownPanel(panel)
    end, panel.mode)
    local bucket = ModeBucket(panel.actor, panel.mode)
    local spells = bucket and SortedBreakdown(bucket.spells) or {}
    local targets = bucket and SortedBreakdown(bucket.targets) or {}
    panel.spells.selectedEntry = panel.spell
    panel.targets.selectedEntry = panel.target
    panel.title:SetText((panel.actor and panel.actor.name or panel.actorName or LText("Damage Meter")) .. " - " .. LText(MODE_LABELS[panel.mode]))
    panel.empty:SetShown(not bucket or (not next(bucket.spells or {}) and not IsCountMode(panel.mode)))
    PopulateBreakdownList(panel.spells, spells, bucket and bucket.total or 0, session, function(entry)
        panel.spell, panel.target = panel.spell == entry and nil or entry, nil
        panel.relations.offset = 0
        RefreshBreakdownPanel(panel)
    end, panel.mode)
    PopulateBreakdownList(panel.targets, targets, bucket and bucket.total or 0, session, function(entry)
        panel.target, panel.spell = panel.target == entry and nil or entry, nil
        panel.relations.offset = 0
        RefreshBreakdownPanel(panel)
    end, panel.mode)
    local relations = {}
    if panel.spell then
        if panel.spell.protectedName then
            panel.relations.title:SetText(LText("Targets"))
        else
            panel.relations.title:SetText(LText("Targets") .. " - " .. panel.spell.name)
        end
        relations = SortedBreakdown(panel.spell.targets, function(key, amount)
            local target = bucket.targets[key]; return { name = target and target.name or LText("Unknown"), icon = TARGET_ICON, kind = "target", amount = amount }
        end)
    elseif panel.target then
        panel.relations.title:SetText(LText("Spells") .. " - " .. panel.target.name)
        relations = SortedBreakdown(panel.target.spells, function(key, amount)
            local spell = bucket.spells[key]
            if spell and spell.protectedName then
                return { name = spell.name, icon = spell.icon, protectedName = true, protectedIcon = spell.protectedIcon, fallbackIcon = SPELL_FALLBACK_ICON, kind = "spell", amount = amount }
            end
            return { name = spell and spell.name or LText("Unknown"), icon = spell and spell.icon, protectedIcon = spell and spell.protectedIcon, fallbackIcon = SPELL_FALLBACK_ICON, kind = "spell", amount = amount }
        end)
    else panel.relations.title:SetText(LText("Select a spell or target")) end
    PopulateBreakdownList(panel.relations, relations, bucket and bucket.total or 0, session, nil, panel.mode)
    for _, button in ipairs(panel.modeButtons) do
        local r, g, b = GetAccentColor()
        local selected = button.mode == panel.mode
        button.text:SetTextColor(selected and r or 0.72, selected and g or 0.72, selected and b or 0.76)
        if button.icon then button.icon:SetAlpha(selected and 1 or 0.72) end
    end
end

local function BreakdownPanel()
    if Mod.damageMeterBreakdownPanel then return Mod.damageMeterBreakdownPanel end
    local panel = CreateFrame("Frame", "KullThranUIDamageMeterBreakdown", UIParent, "BackdropTemplate")
    panel:SetSize(1050, 700); panel:SetPoint("CENTER"); panel:SetFrameStrata("FULLSCREEN_DIALOG"); panel:SetFrameLevel(200); panel:SetClampedToScreen(true)
    panel:HookScript("OnShow", function(self)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:SetFrameLevel(200)
        if self.Raise then self:Raise() end
    end)
    _G.UISpecialFrames[#_G.UISpecialFrames + 1] = panel:GetName()
    panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving); panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel.backgroundImage = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    panel.backgroundImage:SetAllPoints(panel)
    panel.backgroundImage:SetTexture(INSTALLER_BACKGROUND)
    if KT.AddBackdrop then KT:AddBackdrop(panel, 0, 0, 0, 0) end
    if panel.SetBackdropColor then panel:SetBackdropColor(0, 0, 0, 0) end
    ApplyBreakdownBackgroundTheme(panel)
    local accent = panel:CreateTexture(nil, "OVERLAY"); accent:SetPoint("TOPLEFT", 1, -1); accent:SetPoint("TOPRIGHT", -1, -1)
    panel.accentLine = accent
    local accentR, accentG, accentB = GetAccentColor()
    accent:SetHeight(2); accent:SetColorTexture(accentR, accentG, accentB, 1)
    panel.title = panel:CreateFontString(nil, "OVERLAY"); panel.title:SetFont(DAMAGE_METER_RESOLVED_FONT(), 15, "OUTLINE"); ApplyFontReadability(panel.title); panel.title:SetPoint("TOPLEFT", 14, -12)
    local close = CreateFrame("Button", nil, panel); close:SetSize(24, 24); close:SetPoint("TOPRIGHT", -5, -5)
    close.text = close:CreateFontString(nil, "OVERLAY"); close.text:SetFont(DAMAGE_METER_RESOLVED_FONT(), 16, "OUTLINE"); ApplyFontReadability(close.text); close.text:SetAllPoints(); close.text:SetText("X")
    close:SetScript("OnClick", function() panel:Hide() end)
    panel.modeButtons = {}
    local visibleButtonIndex = 0
    for _, mode in ipairs(breakdownModes) do
        if IsModeSupported(mode) then
            visibleButtonIndex = visibleButtonIndex + 1
            local button = CreateFrame("Button", nil, panel, "BackdropTemplate"); button:SetSize(102, 24)
            local column = (visibleButtonIndex - 1) % 4
            local buttonRow = math.floor((visibleButtonIndex - 1) / 4)
            button:SetPoint("TOPLEFT", panel, "TOPLEFT", 180 + column * 106, -38 - buttonRow * 28)
            if KT.AddBackdrop then KT:AddBackdrop(button, 0.04, 0.045, 0.06, 0.9) end
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetSize(16, 16); button.icon:SetPoint("LEFT", 6, 0)
            button.icon:SetTexture(MODE_ICONS[mode] or MODE_ICONS.damageDone)
            button.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            button.text = button:CreateFontString(nil, "OVERLAY"); button.text:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
            ApplyFontReadability(button.text)
            button.text:SetPoint("LEFT", button.icon, "RIGHT", 4, 0); button.text:SetPoint("RIGHT", -4, 0)
            button.text:SetJustifyH("CENTER"); button.text:SetText(LText(MODE_LABELS[mode])); button.mode = mode
            button:SetScript("OnClick", function(self)
                panel.mode, panel.actor, panel.spell, panel.target, panel.damageSource = self.mode, nil, nil, nil, nil
                panel.actors.offset, panel.spells.offset, panel.targets.offset, panel.relations.offset = 0, 0, 0, 0
                local cfg = GetFrameConfig(panel.sourceFrame); cfg.mode = self.mode
                Mod:RefreshDamageMeterStyle(false, panel.sourceFrame); Mod:UpdateDamageMeterData(panel.sourceFrame)
                RefreshBreakdownPanel(panel)
            end)
            panel.modeButtons[#panel.modeButtons + 1] = button
        end
    end
    panel.actors = CreateBreakdownList(panel, LText("Players"), 270, 585, 30); panel.actors:SetPoint("TOPLEFT", 10, -104)
    panel.spells = CreateBreakdownList(panel, LText("Spells"), 460, 360, 17); panel.spells:SetPoint("TOPLEFT", 287, -104)
    panel.targets = CreateBreakdownList(panel, LText("Targets"), 460, 218, 10); panel.targets:SetPoint("TOPLEFT", panel.spells, "BOTTOMLEFT", 0, -7)
    panel.relations = CreateBreakdownList(panel, LText("Select a spell or target"), 286, 585, 30); panel.relations:SetPoint("TOPLEFT", 754, -104)
    panel.empty = panel:CreateFontString(nil, "OVERLAY"); panel.empty:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE"); ApplyFontReadability(panel.empty)
    panel.empty:SetPoint("CENTER", panel.spells); panel.empty:SetWidth(350); panel.empty:SetText(LText("Detailed data will be collected during combat."))
    panel:Hide(); Mod.damageMeterBreakdownPanel = panel
    return panel
end

function Mod:OpenDamageMeterBreakdown(row)
    if not row or not row.damageMeterFrame or not row.damageSource then return end
    local panel = BreakdownPanel()
    local actorName = ResolveNativeSourceName(row.damageSource) or ShortName(row.damageSource.name)
    if IsSecret(actorName) or type(actorName) ~= "string" then return end
    panel.sourceFrame, panel.actorName, panel.mode = row.damageMeterFrame, actorName, GetFrameConfig(row.damageMeterFrame).mode
    panel.damageSource = row.damageSource
    panel.actor, panel.spell, panel.target = nil, nil, nil
    panel.actors.offset, panel.spells.offset, panel.targets.offset, panel.relations.offset = 0, 0, 0, 0
    RefreshBreakdownPanel(panel); panel:Show()
end


local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row.index = index
    row:EnableMouse(true)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta)
        local wheelHandler = parent:GetScript("OnMouseWheel")
        if wheelHandler then wheelHandler(parent, delta) end
    end)
    row:SetScript("OnEnter", function(self) Mod:ShowDamageMeterActorTooltip(self) end)
    row:SetScript("OnLeave", function(self)
        if _G.GameTooltip and _G.GameTooltip:IsOwned(self) then HideDamageMeterTooltipRows(); _G.GameTooltip:Hide() end
    end)
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then Mod:OpenDamageMeterBreakdown(self) end
    end)

    row.icon = row:CreateTexture(nil, "ARTWORK")

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetColorTexture(0.025, 0.028, 0.038, 0.86)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture(BAR_TEXTURE)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(0)

    row.shade = row.bar:CreateTexture(nil, "ARTWORK")
    row.shade:SetAllPoints()
    row.shade:SetColorTexture(0, 0, 0, 0.14)

    row.textLayer = CreateFrame("Frame", nil, row.bar)
    row.textLayer:SetAllPoints()
    row.textLayer:SetFrameLevel(row.bar:GetFrameLevel() + 2)

    row.rank = row.textLayer:CreateFontString(nil, "OVERLAY")
    row.rank:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
    ApplyFontReadability(row.rank)
    row.rank:SetJustifyH("LEFT")
    row.rank:SetTextColor(1, 1, 1, 1)
    SetSingleLine(row.rank)

    row.name = row.textLayer:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
    ApplyFontReadability(row.name)
    row.name:SetJustifyH("LEFT")
    row.name:SetTextColor(1, 1, 1, 1)
    SetSingleLine(row.name)

    row.rate = row.textLayer:CreateFontString(nil, "OVERLAY")
    row.rate:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
    ApplyFontReadability(row.rate)
    row.rate:SetJustifyH("RIGHT")
    row.rate:SetTextColor(1, 1, 1, 1)
    SetSingleLine(row.rate)

    row.amount = row.textLayer:CreateFontString(nil, "OVERLAY")
    row.amount:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
    ApplyFontReadability(row.amount)
    row.amount:SetJustifyH("RIGHT")
    row.amount:SetTextColor(1, 1, 1, 1)
    SetSingleLine(row.amount)

    row:Hide()
    return row
end

local function GetDamageMeterDockID(frame)
    if not frame then
        return nil
    end
    return frame.isAdditionalDamageMeter and frame.additionalDamageMeterIndex or 0
end

local function GetDamageMeterFrameByDockID(dockID)
    if dockID == 0 then
        return Mod.damageMeterFrame
    end
    return Mod.additionalDamageMeterFrames and Mod.additionalDamageMeterFrames[dockID]
end

local function GetDamageMeterFrames()
    local frames = {}
    if Mod.damageMeterFrame then
        frames[#frames + 1] = Mod.damageMeterFrame
    end
    for _, frame in pairs(Mod.additionalDamageMeterFrames or {}) do
        if frame and GetFrameConfig(frame).enabled == true then
            frames[#frames + 1] = frame
        end
    end
    return frames
end

local DAMAGE_METER_REFRESH_INTERVAL = 0.5

function Mod:InvalidateDamageMeterDataCache()
    self._damageMeterSessionCache = nil
    nativeBreakdownCache = nil
end

function Mod:RefreshVisibleDamageMeterWindows()
    if not IsDamageMeterModuleEnabled() then return end
    local profiler = KT and KT.CombatProfiler
    local refreshStarted = profiler and profiler:Begin("enh.damage.refresh.all")
    -- One cache generation per shared repaint. Windows displaying the same
    -- session and meter type reuse the exact C_DamageMeter result.
    self._damageMeterSessionCache = {}
    self._damageMeterLastRefreshAt = GetTime()
    for _, frame in ipairs(GetDamageMeterFrames()) do
        local visibilityStarted = profiler and profiler:Begin("enh.damage.refresh.visibility")
        self:UpdateDamageMeterVisibility(frame)
        if visibilityStarted then profiler:End("enh.damage.refresh.visibility", visibilityStarted) end
        if frame:IsShown() then
            local dataStarted = profiler and profiler:Begin("enh.damage.refresh.data")
            self:UpdateDamageMeterData(frame)
            if dataStarted then profiler:End("enh.damage.refresh.data", dataStarted) end
        end
    end
    if refreshStarted then profiler:End("enh.damage.refresh.all", refreshStarted) end
end

function Mod:PrepareDamageMeterCombatStart()
    for _, frame in ipairs(GetDamageMeterFrames()) do
        frame.damageMeterScrollOffset = 0
        frame._damageMeterManualScroll = nil
        if GetFrameConfig(frame).session == "current" then
            -- Give Blizzard a short window to replace the native session.
            frame._damageMeterPinSuppressedUntil = GetTime() + 0.35
        else
            frame._damageMeterPinSuppressedUntil = nil
        end
    end
end

function Mod:MarkDamageMeterCurrentSessionFresh()
    for _, frame in ipairs(GetDamageMeterFrames()) do
        if frame._damageMeterPinSuppressedUntil then
            frame.damageMeterScrollOffset = 0
            frame._damageMeterManualScroll = nil
            frame._damageMeterPinSuppressedUntil = nil
        end
    end
end

function Mod:DebugDamageMeter()
    local frames = GetDamageMeterFrames()
    if #frames == 0 then
        if KT and KT.Print then KT:Print("|cff66ccff[ktdmdebug]|r no damage meter frame") end
        return
    end

    for index, frame in ipairs(frames) do
        local cfg = GetFrameConfig(frame)
        local sourceCount = tonumber(frame._damageMeterSourceCount) or 0
        local visibleLimit = tonumber(frame._damageMeterVisibleLimit) or 0
        local offset = tonumber(frame.damageMeterScrollOffset) or 0
        local maximumOffset = math.max(0, sourceCount - visibleLimit)
        local suppressed = frame._damageMeterPinSuppressedUntil
            and frame._damageMeterPinSuppressedUntil > GetTime()
        local frameName = frame.GetName and frame:GetName() or ("frame" .. index)
        local line = string.format(
            "%s pin=%s detected=%s rank=%s manual=%s offset=%d/%d visible=%d sources=%d suppressed=%s",
            frameName,
            cfg.alwaysShowPlayer == true and "on" or "off",
            frame._damageMeterPlayerDetected and "yes" or "no",
            tostring(frame._damageMeterPlayerRank or "-"),
            frame._damageMeterManualScroll and "yes" or "no",
            offset,
            maximumOffset,
            visibleLimit,
            sourceCount,
            suppressed and "yes" or "no"
        )
        if KT and KT.Print then
            KT:Print("|cff66ccff[ktdmdebug]|r " .. line)
        else
            print("|cff66ccff[ktdmdebug]|r " .. line)
        end
    end
end
function Mod:ResetDamageMeterScroll()
    for _, frame in ipairs(GetDamageMeterFrames()) do
        frame.damageMeterScrollOffset = 0
        frame._damageMeterManualScroll = nil
        self:UpdateDamageMeterData(frame)
    end
end

function Mod:ScheduleDamageMeterRefresh(delay)
    if not IsDamageMeterModuleEnabled() or self._damageMeterRefreshPending then return end
    local now = GetTime()
    local earliest = (self._damageMeterLastRefreshAt or 0) + DAMAGE_METER_REFRESH_INTERVAL
    delay = math.max(tonumber(delay) or 0, earliest - now, 0)
    self._damageMeterRefreshPending = true
    C_Timer.After(delay, function()
        if not Mod then return end
        Mod._damageMeterRefreshPending = nil
        Mod:RefreshVisibleDamageMeterWindows()
    end)
end

function Mod:StartDamageMeterLiveRefresh()
    if not IsDamageMeterModuleEnabled() then return end
    local hasEnabledWindow = GetConfig().enabled == true
    if not hasEnabledWindow then
        for _, cfg in ipairs(GetConfig().windows or {}) do
            if cfg and cfg.enabled == true then hasEnabledWindow = true; break end
        end
    end
    if not hasEnabledWindow then
        self._damageMeterLiveRefresh = nil
        if self._damageMeterTicker then
            self._damageMeterTicker:Cancel()
            self._damageMeterTicker = nil
        end
        return
    end
    self._damageMeterLiveRefresh = true
    local started
    if not self._damageMeterTicker then
        started = true
        self._damageMeterTicker = C_Timer.NewTicker(DAMAGE_METER_REFRESH_INTERVAL, function()
            if not Mod or not Mod._damageMeterLiveRefresh then return end
            Mod:RefreshVisibleDamageMeterWindows()
        end)
    end
    if started then self:ScheduleDamageMeterRefresh(0) end
end

function Mod:StopDamageMeterLiveRefresh(finalRefresh)
    self._damageMeterLiveRefresh = nil
    if self._damageMeterTicker then
        self._damageMeterTicker:Cancel()
        self._damageMeterTicker = nil
    end
    if finalRefresh then self:ScheduleDamageMeterRefresh(0) end
end

local function SaveDamageMeterAbsolutePosition(frame)
    if not frame then
        return
    end
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not frameX or not parentX then
        return
    end
    local cfg = GetFrameConfig(frame)
    cfg.position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = frameX - parentX,
        y = frameY - parentY,
    }
end

local function SetDamageMeterSnapGlow(frame, shown)
    if not frame or not frame.snapGlow then
        return
    end
    local r, g, b = GetAccentColor()
    for _, texture in ipairs(frame.snapGlow) do
        texture:SetColorTexture(r, g, b, 0.9)
        texture:SetShown(shown == true)
    end
end

local function IsSameDamageMeterDockCluster(firstFrame, secondFrame)
    local firstID = GetDamageMeterDockID(firstFrame)
    local secondID = GetDamageMeterDockID(secondFrame)
    if firstID == nil or secondID == nil then
        return false
    end

    local visited = { [firstID] = true }
    local changed = true
    while changed do
        changed = false
        for _, frame in ipairs(GetDamageMeterFrames()) do
            local frameID = GetDamageMeterDockID(frame)
            local dock = GetFrameConfig(frame).dock
            local targetID = dock and dock.target
            if frameID ~= nil and targetID ~= nil then
                if visited[frameID] and not visited[targetID] then
                    visited[targetID] = true
                    changed = true
                elseif visited[targetID] and not visited[frameID] then
                    visited[frameID] = true
                    changed = true
                end
            end
        end
    end
    return visited[secondID] == true
end

local function ApplyDamageMeterDock(frame, dock)
    if not frame or not dock then
        return false
    end
    local target = GetDamageMeterFrameByDockID(dock.target)
    if not target or target == frame then
        return false
    end
    local cfg = GetFrameConfig(frame)
    local resized
    if dock.point == "LEFT" or dock.point == "RIGHT" then
        local targetHeight = target:GetHeight()
        if math.abs(frame:GetHeight() - targetHeight) > 0.01 then
            frame:SetHeight(targetHeight)
            resized = true
        end
        cfg.height = math.floor(targetHeight + 0.5)
    elseif dock.point == "TOP" or dock.point == "BOTTOM" then
        local targetWidth = target:GetWidth()
        if math.abs(frame:GetWidth() - targetWidth) > 0.01 then
            frame:SetWidth(targetWidth)
            resized = true
        end
        cfg.width = math.floor(targetWidth + 0.5)
    end
    local offsetX = dock.x
    local offsetY = dock.y
    if offsetX == nil then
        offsetX = dock.point == "LEFT" and SNAP_GAP or (dock.point == "RIGHT" and -SNAP_GAP or 0)
    end
    if offsetY == nil then
        offsetY = dock.point == "BOTTOM" and SNAP_GAP or (dock.point == "TOP" and -SNAP_GAP or 0)
    end
    frame:ClearAllPoints()
    frame:SetPoint(
        dock.point or "LEFT",
        target,
        dock.relativePoint or "RIGHT",
        offsetX,
        offsetY
    )
    if resized and Mod.RefreshDamageMeterStyle then
        Mod:RefreshDamageMeterStyle(true, frame)
        Mod:UpdateDamageMeterData(frame)
    end
    return true
end

local function SyncDamageMeterDockDependents(targetFrame, visited)
    local targetID = GetDamageMeterDockID(targetFrame)
    if targetID == nil then
        return
    end
    visited = visited or {}
    if visited[targetID] then
        return
    end
    visited[targetID] = true
    for _, frame in ipairs(GetDamageMeterFrames()) do
        local dock = GetFrameConfig(frame).dock
        if frame ~= targetFrame and dock and dock.target == targetID then
            ApplyDamageMeterDock(frame, dock)
            SyncDamageMeterDockDependents(frame, visited)
        end
    end
end

local function FindDamageMeterSnapCandidate(frame)
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then
        return nil
    end
    local centerX, centerY = (left + right) * 0.5, (top + bottom) * 0.5
    local best

    local function Consider(target, edgeGap, alignmentGap, point, relativePoint, offsetX, offsetY)
        if edgeGap > SNAP_DISTANCE or alignmentGap > SNAP_DISTANCE then
            return
        end
        local score = edgeGap + alignmentGap
        if not best or score < best.score then
            best = {
                target = target,
                targetID = GetDamageMeterDockID(target),
                point = point,
                relativePoint = relativePoint,
                x = offsetX or 0,
                y = offsetY or 0,
                score = score,
            }
        end
    end

    for _, target in ipairs(GetDamageMeterFrames()) do
        if target ~= frame and target:IsShown() and not IsSameDamageMeterDockCluster(frame, target) then
            local targetLeft, targetRight = target:GetLeft(), target:GetRight()
            local targetTop, targetBottom = target:GetTop(), target:GetBottom()
            if targetLeft and targetRight and targetTop and targetBottom then
                local targetCenterX = (targetLeft + targetRight) * 0.5
                local targetCenterY = (targetTop + targetBottom) * 0.5
                Consider(target, math.abs(left - targetRight), math.abs(centerY - targetCenterY), "LEFT", "RIGHT", SNAP_GAP, 0)
                Consider(target, math.abs(right - targetLeft), math.abs(centerY - targetCenterY), "RIGHT", "LEFT", -SNAP_GAP, 0)
                Consider(target, math.abs(bottom - targetTop), math.abs(centerX - targetCenterX), "BOTTOM", "TOP", 0, SNAP_GAP)
                Consider(target, math.abs(top - targetBottom), math.abs(centerX - targetCenterX), "TOP", "BOTTOM", 0, -SNAP_GAP)
            end
        end
    end
    return best
end

function Mod:ApplyDamageMeterPosition(targetFrame)
    local frame = targetFrame or self.damageMeterFrame
    if not frame then
        return
    end
    local cfg = GetFrameConfig(frame)
    if cfg.dock and ApplyDamageMeterDock(frame, cfg.dock) then
        return
    end
    local pos = cfg.position or {}
    cfg.position = pos
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "RIGHT", UIParent, pos.relativePoint or pos.point or "RIGHT", pos.x or -36, pos.y or 0)
end

local function RefreshDamageMeterLockControl(frame)
    if not frame or not frame.lockButton then
        return
    end
    local locked = GetFrameConfig(frame).locked == true
    frame.lockButton.text:SetText(locked and LText("UNLOCK") or LText("LOCK"))
    frame.lockButton:ClearAllPoints()
    frame.lockButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", locked and -3 or -18, 1)
    if locked then
        local r, g, b = GetAccentColor()
        frame.lockButton.text:SetTextColor(r, g, b, 1)
    else
        frame.lockButton.text:SetTextColor(0.78, 0.78, 0.82, 1)
    end
    if frame.resizeHandle then
        frame.resizeHandle:SetShown(not locked)
    end
    local isMouseOver = frame.IsMouseOver and frame:IsMouseOver()
    frame.lockButton:SetAlpha(locked and not isMouseOver and 0 or 1)
end

function Mod:RefreshDamageMeterStyle(useCurrentSize, targetFrame)
    local frame = targetFrame or self.damageMeterFrame
    if not frame then
        return
    end
    
    -- Prevent re-entrance to avoid timeout
    if frame._styleRefreshInProgress then
        return
    end
    frame._styleRefreshInProgress = true

    local cfg = GetFrameConfig(frame)
    local meterFont = GetDamageMeterFont(cfg)
    local barTexture = GetDamageMeterBarTexture(cfg)
    if not IsModeSupported(cfg.mode) then
        cfg.mode = "damageDone"
    end
    local width = math.max(MIN_METER_WIDTH, useCurrentSize and frame:GetWidth() or (tonumber(cfg.width) or 320))
    local height = math.max(MIN_METER_HEIGHT, useCurrentSize and frame:GetHeight() or (tonumber(cfg.height) or 220))
    if not useCurrentSize then
        frame:SetSize(width, height)
    end

    if KT.AddBackdrop then
        if cfg.showBackground == false then
            KT:AddBackdrop(frame, 0, 0, 0, 0)
        else
            KT:AddBackdrop(frame, 0.012, 0.014, 0.02, 0.94)
        end
    end
    if frame.borderKT and frame.borderKT.Hide then
        frame.borderKT:Hide()
    end
    if frame.accentLine then
        frame.accentLine:Hide()
    end

    StyleHeaderButton(frame.modeButton)
    StyleHeaderButton(frame.sessionButton)
    frame.modeButton.text:SetText(LText(MODE_LABELS[cfg.mode] or MODE_LABELS.damageDone))
    frame.sessionButton.text:SetText(GetSessionLabel(cfg, frame))
    frame.modeButton.text:SetFont(meterFont, math.max(10, tonumber(cfg.headerFontSize) or 12), "OUTLINE")
    frame.sessionButton.text:SetFont(meterFont, math.max(10, tonumber(cfg.headerFontSize) or 12), "OUTLINE")
    local sessionWidth = math.max(60, math.min(130, width * 0.34))
    frame.sessionButton:SetWidth(sessionWidth)
    frame.modeButton:SetWidth(math.max(65, width - sessionWidth - 15))
    RefreshSessionButtonIcon(frame)
    if frame.modeButton.icon then
        frame.modeButton.icon:SetTexture(MODE_ICONS[cfg.mode] or MODE_ICONS.damageDone)
    end
    LayoutHeaderButton(frame.modeButton)

    local rowHeight = math.max(14, tonumber(cfg.rowHeight) or 19)
    local fontSize = math.max(9, tonumber(cfg.fontSize) or 12)
    local iconSize = rowHeight
    local iconMode = GetDamageMeterIconMode(cfg)
    local showIcons = iconMode ~= "none"
    local iconGap = showIcons and (iconSize + 1) or 0
    local showPercentages = cfg.showPercentages == true
    local amountWidth = math.max(42, math.min(70, width * 0.18))
    local rateWidth = showPercentages
        and math.max(78, math.min(105, width * 0.29))
        or amountWidth
    local showRate = cfg.mode ~= "interrupts" and cfg.mode ~= "dispels" and cfg.mode ~= "deaths"

    for index, row in ipairs(frame.rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -(HEADER_HEIGHT + 4 + ((index - 1) * (rowHeight + ROW_SPACING))))
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -(HEADER_HEIGHT + 4 + ((index - 1) * (rowHeight + ROW_SPACING))))
        row:SetHeight(rowHeight)

        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon:SetSize(iconSize, iconSize)

        row.background:ClearAllPoints()
        row.background:SetPoint("TOPLEFT", row, "TOPLEFT", iconGap, 0)
        row.background:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

        row.bar:ClearAllPoints()
        row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", iconGap, 0)
        row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        row.bar:SetStatusBarTexture(barTexture)

        row.rank:SetFont(meterFont, fontSize, "OUTLINE")
        row.name:SetFont(meterFont, fontSize, "OUTLINE")
        row.amount:SetFont(meterFont, fontSize, "OUTLINE")
        row.rate:SetFont(meterFont, fontSize, "OUTLINE")
        ApplyFontReadability(row.rank)
        ApplyFontReadability(row.name)
        ApplyFontReadability(row.amount)
        ApplyFontReadability(row.rate)

        row.rank:ClearAllPoints()
        row.rank:SetPoint("LEFT", row.textLayer, "LEFT", 3, 0)
        -- Leave enough room for the rank separator at 30+; the old 30px
        -- width clipped the final digit/period with the outlined KUI font.
        row.rank:SetWidth(40)

        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.rank, "RIGHT", 1, 0)

        row.rate:ClearAllPoints()
        row.rate:SetPoint("RIGHT", row.textLayer, "RIGHT", -4, 0)
        row.rate:SetWidth(rateWidth)
        row.rate:SetShown(showRate)

        row.amount:ClearAllPoints()
        if showRate then
            row.amount:SetPoint("RIGHT", row.rate, "LEFT", -4, 0)
        else
            row.amount:SetPoint("RIGHT", row.textLayer, "RIGHT", -4, 0)
        end
        row.amount:SetWidth(amountWidth)

        row.name:SetPoint("RIGHT", row.amount, "LEFT", -5, 0)
    end

    frame.emptyText:SetFont(meterFont, fontSize, "OUTLINE")
    ApplyFontReadability(frame.emptyText)
    if frame.scrollText then
        frame.scrollText:SetFont(meterFont, 10, "OUTLINE")
        ApplyFontReadability(frame.scrollText)
    end
    if frame.lockButton and frame.lockButton.text then
        frame.lockButton.text:SetFont(meterFont, 9, "OUTLINE")
        ApplyFontReadability(frame.lockButton.text)
    end
    frame.emptyText:SetTextColor(0.62, 0.62, 0.68, 1)
    RefreshDamageMeterLockControl(frame)
    
    frame._styleRefreshInProgress = false
end

local function GetSessionData(cfg, frame)
    local C_DamageMeter = _G.C_DamageMeter
    if not C_DamageMeter then
        return nil
    end
    local meterType = ResolveMode(cfg.mode)
    if meterType == nil then
        return nil
    end

    local getter
    local firstArgument
    if frame and frame.selectedSessionID and C_DamageMeter.GetCombatSessionFromID then
        getter = C_DamageMeter.GetCombatSessionFromID
        firstArgument = frame.selectedSessionID
    elseif C_DamageMeter.GetCombatSessionFromType then
        getter = C_DamageMeter.GetCombatSessionFromType
        firstArgument = ResolveSession(cfg.session)
    end
    if not getter or firstArgument == nil then
        return nil
    end

    local cacheKey
    if not IsSecret(firstArgument) and not IsSecret(meterType) then
        cacheKey = table.concat({
            frame and frame.selectedSessionID and "id" or "type",
            tostring(firstArgument), tostring(meterType),
            tostring(frame and frame.selectedHistoryKey or ""),
        }, ":")
    end
    local cache = Mod._damageMeterSessionCache
    local cached = cacheKey and cache and cache[cacheKey]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local ok, session = pcall(getter, firstArgument, meterType)
    if ok and not IsSecret(session) and type(session) == "table"
        and not IsSecret(session.combatSources) and type(session.combatSources) == "table"
        and #session.combatSources > 0 then
        if cacheKey and cache then cache[cacheKey] = session end
        return session
    end
    local saved = frame and FindSavedCombatSession(frame.selectedHistoryKey)
    local savedMode = saved and saved.modes and saved.modes[NormalizeHistoryMode(cfg.mode)]
    if cacheKey and cache then cache[cacheKey] = savedMode or false end
    if savedMode then return savedMode end
    return nil
end

function Mod:UpdateDamageMeterData(targetFrame)
    local frame = targetFrame or self.damageMeterFrame
    if not frame then
        return
    end
    
    -- Prevent re-entrance to avoid infinite loops during rapid updates
    if frame._damageDataUpdateInProgress then
        return
    end
    frame._damageDataUpdateInProgress = true
    
    local function cleanup()
        frame._damageDataUpdateInProgress = false
    end
    
    local cfg = GetFrameConfig(frame)
    local previewing = IsDamageMeterPreviewing(frame)
    local session = not previewing and GetSessionData(cfg, frame) or nil
    local sources = previewing and GetPreviewData(cfg.mode) or (session and session.combatSources)
    frame._damageMeterSources = (not IsSecret(sources) and type(sources) == "table") and sources or nil
    local sourceCount = (not IsSecret(sources) and type(sources) == "table") and #sources or 0
    local rowHeight = math.max(14, tonumber(cfg.rowHeight) or 19)
    local rowStride = rowHeight + ROW_SPACING
    local rowLimit = math.max(3, tonumber(cfg.maxRows) or 10)

    -- Keep the window compact when it contains fewer rows than its configured
    -- limit. A manually resized or docked window keeps its explicit geometry.
    if cfg.autoHeight ~= false and not cfg.dock and not frame._damageMeterSizing then
        local contentRows = math.min(sourceCount, rowLimit, MAX_ROW_POOL)
        local targetHeight
        if sourceCount > rowLimit then
            targetHeight = math.max(MIN_METER_HEIGHT, tonumber(cfg.height) or 220)
        else
            targetHeight = HEADER_HEIGHT + 4
                + (contentRows * rowHeight)
                + (math.max(0, contentRows - 1) * ROW_SPACING)
                + DAMAGE_METER_FOOTER_HEIGHT
            targetHeight = math.max(MIN_METER_HEIGHT, targetHeight)
        end
        if math.abs(frame:GetHeight() - targetHeight) > 0.5 then
            frame:SetHeight(targetHeight)
            SyncDamageMeterDockDependents(frame)
        end
    end

    local availableHeight = frame:GetHeight() - HEADER_HEIGHT - 4 - DAMAGE_METER_FOOTER_HEIGHT
    local visibleLimit = math.min(
        MAX_ROW_POOL,
        math.max(1, math.floor((availableHeight + ROW_SPACING) / rowStride)),
        rowLimit
    )

    -- Keep the successful data snapshot available to the wheel handler. The
    -- native Damage Meter API can return protected data again when queried
    -- directly from an input callback, even though this refresh already got
    -- a usable source list.
    frame._damageMeterVisibleLimit = visibleLimit
    frame._damageMeterSourceCount = sourceCount

    if IsSecret(sources) or type(sources) ~= "table" or #sources == 0 then
        for _, row in ipairs(frame.rows) do
            row:Hide()
        end
        if frame.scrollText then frame.scrollText:Hide() end
        frame.emptyText:SetText(LText(_G.C_DamageMeter and "No combat data" or "Damage Meter API unavailable"))
        frame.emptyText:Show()
        cleanup()
        return
    end

    frame.emptyText:Hide()
    frame._damageMeterPlayerRank = nil
    frame._damageMeterPlayerDetected = false
    local playerSource, playerRank
    local pinSuppressed = frame._damageMeterPinSuppressedUntil and frame._damageMeterPinSuppressedUntil > GetTime()
    if cfg.alwaysShowPlayer == true and not previewing and not pinSuppressed then
        local playerGUID = _G.UnitGUID and _G.UnitGUID("player")
        if IsSecret(playerGUID) then playerGUID = nil end
        local playerName, playerRealm
        if _G.UnitFullName then
            playerName, playerRealm = _G.UnitFullName("player")
        elseif _G.UnitName then
            playerName, playerRealm = _G.UnitName("player")
        end
        if IsSecret(playerName) or type(playerName) ~= "string" then playerName = nil end
        if IsSecret(playerRealm) or type(playerRealm) ~= "string" then playerRealm = nil end
        for sourceIndex, candidate in ipairs(sources) do
            if IsLocalDamageMeterSource(candidate, playerGUID, playerName, playerRealm) then
                playerSource, playerRank = candidate, sourceIndex
                break
            end
        end
    end
    frame._damageMeterPlayerRank = playerRank
    frame._damageMeterPlayerDetected = playerSource ~= nil
    local maximumOffset = math.max(0, #sources - visibleLimit)
    frame.damageMeterScrollOffset = math.max(0, math.min(frame.damageMeterScrollOffset or 0, maximumOffset))
    local scrollOffset = frame.damageMeterScrollOffset
    
    -- Pin the player at the last visible row whenever the list has more
    -- entries than it can display. This also handles ranks already visible.
    local pinnedRowIndex = nil
    if playerSource and #sources > visibleLimit and playerRank > (scrollOffset + visibleLimit) then
        -- Match Details: keep the real scroll range untouched and replace the
        -- last visible row only while the player is below the current range.
        pinnedRowIndex = visibleLimit
    end
    if frame.scrollText then
        if maximumOffset > 0 then
            if pinnedRowIndex then
                frame.scrollText:SetText(string.format("%d-%d + #%d / %d", scrollOffset + 1,
                    math.min(#sources - 1, scrollOffset + pinnedRowIndex - 1), playerRank, #sources))
            else
                frame.scrollText:SetText(string.format("%d-%d / %d", scrollOffset + 1,
                    math.min(#sources, scrollOffset + visibleLimit), #sources))
            end
            frame.scrollText:Show()
        else
            frame.scrollText:Hide()
        end
    end
    local firstSource = sources[1]
    if IsSecret(firstSource) or type(firstSource) ~= "table" then
        firstSource = {}
    end
    local maxAmount = firstSource.totalAmount
    maxAmount = GetStatusBarAmount(maxAmount, 1, true)
    local sessionTotal = cfg.showPercentages == true and GetReadableSessionTotal(session, sources) or nil

    for index, row in ipairs(frame.rows) do
        local sourceIndex
        local source
        if pinnedRowIndex and index == pinnedRowIndex then
            source, sourceIndex = playerSource, playerRank
        elseif index <= visibleLimit and (not pinnedRowIndex or index < pinnedRowIndex) then
            sourceIndex = scrollOffset + index
            -- Only skip player in rankings if we're pinning them at the bottom
            if pinnedRowIndex and playerRank and sourceIndex >= playerRank then sourceIndex = sourceIndex + 1 end
            source = sources[sourceIndex]
        end
        if IsSecret(source) or type(source) ~= "table" then source = nil end
        if not source then
            row.damageSource = nil
            row.damageMeterFrame = nil
            row:Hide()
        else
            local totalAmount = source.totalAmount
            totalAmount = GetStatusBarAmount(totalAmount, 0, false)
            local amountPerSecond = source.amountPerSecond
            local classFilename = source.classFilename
            local r, g, b
            if cfg.classColors == false then
                r, g, b = GetAccentColor()
            else
                r, g, b = GetClassColor(classFilename)
            end

            row.bar:SetMinMaxValues(0, maxAmount)
            row.bar:SetValue(totalAmount)
            row.bar:SetStatusBarColor(r, g, b, 1)
            row.rank:SetText(sourceIndex .. ".")
            row.name:SetText(ShortName(source.isLocalPlayer == true and cfg.customNick ~= "" and cfg.customNick or source.name))
            row.amount:SetText(FormatNumber(totalAmount))

            if cfg.mode == "interrupts" or cfg.mode == "dispels" or cfg.mode == "deaths" then
                row.rate:SetText("")
            else
                local rateText = FormatNumber(amountPerSecond)
                if sessionTotal and not IsSecret(totalAmount) and type(totalAmount) == "number" then
                    row.rate:SetText(string.format("(%s, %.0f%%)", rateText, totalAmount / sessionTotal * 100))
                else
                    row.rate:SetText(rateText)
                end
            end

            ApplyClassIcon(row.icon, source, cfg)
            row.damageSource = source
            row.damageMeterFrame = frame
            row:Show()
        end
    end
    
    cleanup()
end

function Mod:UpdateDamageMeterVisibility(targetFrame)
    local frame = targetFrame or self.damageMeterFrame
    if not frame then
        return
    end
    local cfg = GetFrameConfig(frame)
    local previewing = IsDamageMeterPreviewing(frame)
    local shouldShow = IsDamageMeterModuleEnabled()
        and cfg.enabled == true
        and (cfg.showOnlyInCombat ~= true or UnitAffectingCombat("player") or IsUnlockModeOpen() or previewing)
    frame:SetShown(shouldShow and true or false)
end

local function RefreshAfterMenuSelection(frame)
    frame.damageMeterScrollOffset = 0
    Mod:RefreshDamageMeterStyle(false, frame)
    Mod:UpdateDamageMeterData(frame)
end

local function HideDropdown(dropdown)
    dropdown = dropdown or activeDropdown
    if not dropdown then
        return
    end
    SetHeaderArrowExpanded(dropdown.owner, false)
    dropdown:Hide()
    if dropdown.closer then
        dropdown.closer:Hide()
    end
    if activeDropdown == dropdown then
        activeDropdown = nil
    end
end

local function CreateDropdown(owner, globalName)
    local dropdown = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetClampedToScreen(true)
    dropdown:EnableMouse(true)
    dropdown.rows = {}
    dropdown.owner = owner
    dropdown:Hide()
    KT:AddBackdrop(dropdown, 0.025, 0.03, 0.04, 0.98)
    local r, g, b = GetAccentColor()
    KT:AddBorder(dropdown, r, g, b, 0.7)

    dropdown.closer = CreateFrame("Frame", nil, UIParent)
    dropdown.closer:SetAllPoints()
    dropdown.closer:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdown.closer:EnableMouse(true)
    dropdown.closer:Hide()
    dropdown.closer:SetScript("OnMouseDown", function()
        HideDropdown(dropdown)
    end)
    owner._ktDamageMeterDropdown = dropdown
    return dropdown
end

local function ConfigureDropdownRow(row, entry, width)
    row:SetWidth(width - 2)
    row:SetHeight(entry.isSpacer and 8 or 22)
    row:EnableMouse(not entry.isTitle and not entry.isSpacer and not entry.disabled)
    local accentR, accentG, accentB = GetAccentColor()
    row.active:SetColorTexture(accentR, accentG, accentB, 1)
    row.selectionTop:SetColorTexture(accentR, accentG, accentB, 0.65)
    row.selectionBottom:SetColorTexture(accentR, accentG, accentB, 0.65)
    row.separator:SetColorTexture(accentR, accentG, accentB, 0.4)
    if entry.checked then
        row.bg:SetColorTexture(accentR, accentG, accentB, 0.26)
    else
        row.bg:SetColorTexture(0, 0, 0, 0)
    end
    row.active:SetShown(entry.checked == true)
    row.selectionTop:SetShown(entry.checked == true)
    row.selectionBottom:SetShown(entry.checked == true)
    row.icon:Hide()
    row.icon:ClearAllPoints()
    row.plus:Hide()
    row.separator:Hide()
    row.text:ClearAllPoints()
    row.text:SetFont(DAMAGE_METER_RESOLVED_FONT(), entry.isTitle and 10 or 11, "OUTLINE")

    if entry.isSpacer then
        row.text:SetText("")
        row.separator:Show()
        row:SetScript("OnClick", nil)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        return
    end

    row.text:SetText(entry.text or "")
    if entry.isTitle then
        local r, g, b = GetAccentColor()
        row.text:SetTextColor(r, g, b, 1)
        row.text:SetPoint("LEFT", row, "LEFT", 9, 0)
        row:SetScript("OnClick", nil)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        return
    end

    if entry.createWindow then
        local r, g, b = GetAccentColor()
        row.plus:SetTextColor(r, g, b, 1)
        row.plus:Show()
        row.text:SetPoint("LEFT", row.plus, "RIGHT", 6, 0)
    elseif entry.icon then
        row.icon:SetTexture(entry.icon)
        row.icon:SetPoint("LEFT", row, "LEFT", 7, 0)
        row.icon:Show()
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    else
        row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
    end
    row.text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    if entry.danger then
        row.text:SetTextColor(1, 0.25, 0.35, 1)
    else
        row.text:SetTextColor(1, 1, 1, entry.disabled and 0.45 or 1)
    end

    row:SetScript("OnClick", function()
        HideDropdown(row:GetParent())
        if entry.func then
            entry.func()
        end
    end)
    row:SetScript("OnEnter", function(self)
        local r, g, b = GetAccentColor()
        self.bg:SetColorTexture(r, g, b, entry.checked and 0.34 or 0.22)
    end)
    row:SetScript("OnLeave", function(self)
        if entry.checked then
            local r, g, b = GetAccentColor()
            self.bg:SetColorTexture(r, g, b, 0.26)
        else
            self.bg:SetColorTexture(0, 0, 0, 0)
        end
    end)
end

local function ShowDropdown(owner, globalName, menu)
    if not owner or not menu then
        return
    end
    local dropdown = owner._ktDamageMeterDropdown or CreateDropdown(owner, globalName)
    if dropdown:IsShown() then
        HideDropdown(dropdown)
        return
    end
    HideDropdown(activeDropdown)

    local accentR, accentG, accentB = GetAccentColor()
    KT:AddBorder(dropdown, accentR, accentG, accentB, 0.7)
    local width = math.max(240, owner:GetWidth())
    local y = 2
    for index, entry in ipairs(menu) do
        local row = dropdown.rows[index]
        if not row then
            row = CreateFrame("Button", nil, dropdown)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.active = row:CreateTexture(nil, "ARTWORK")
            row.active:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.active:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            row.active:SetWidth(3)
            local r, g, b = GetAccentColor()
            row.active:SetColorTexture(r, g, b, 1)
            row.selectionTop = row:CreateTexture(nil, "ARTWORK")
            row.selectionTop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.selectionTop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
            row.selectionTop:SetHeight(1)
            row.selectionBottom = row:CreateTexture(nil, "ARTWORK")
            row.selectionBottom:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            row.selectionBottom:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            row.selectionBottom:SetHeight(1)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(16, 16)
            row.plus = row:CreateFontString(nil, "OVERLAY")
            row.plus:SetFont(DAMAGE_METER_RESOLVED_FONT(), 16, "OUTLINE")
            row.plus:SetPoint("LEFT", row, "LEFT", 9, 0)
            row.plus:SetText("+")
            row.separator = row:CreateTexture(nil, "ARTWORK")
            row.separator:SetPoint("LEFT", row, "LEFT", 7, 0)
            row.separator:SetPoint("RIGHT", row, "RIGHT", -7, 0)
            row.separator:SetHeight(1)
            local r, g, b = GetAccentColor()
            row.separator:SetColorTexture(r, g, b, 0.4)
            row.text = row:CreateFontString(nil, "OVERLAY")
            ApplyFontReadability(row.text)
            dropdown.rows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 1, -y)
        ConfigureDropdownRow(row, entry, width)
        row:Show()
        y = y + row:GetHeight()
    end
    for index = #menu + 1, #dropdown.rows do
        dropdown.rows[index]:Hide()
    end

    dropdown:SetSize(width, y + 2)
    dropdown:ClearAllPoints()
    local availableBelow = owner:GetBottom() or 0
    if availableBelow > dropdown:GetHeight() + 8 then
        dropdown:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -3)
    else
        dropdown:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 3)
    end
    dropdown.closer:Show()
    dropdown:Show()
    SetHeaderArrowExpanded(owner, true)
    activeDropdown = dropdown
end

local function BuildModeMenu(frame)
    local cfg = GetFrameConfig(frame)
    local menu = {
        {
            text = LText("Create New Window"),
            createWindow = true,
            func = function()
                if Mod.CreateAdditionalDamageMeterWindow then
                    Mod:CreateAdditionalDamageMeterWindow(frame)
                    -- The options page may already be open and its window
                    -- selector is built from a previous snapshot of the profile.
                    -- Rebuild it on the next frame after the menu closes.
                    if KT and KT.RefreshPage and C_Timer and C_Timer.After then
                        C_Timer.After(0, function()
                            if KT.MenuPrincipal and KT.MenuPrincipal.IsShown and KT.MenuPrincipal:IsShown() then
                                KT:RefreshPage(true)
                            end
                        end)
                    end
                end
            end,
        },
    }
    if frame and frame.isAdditionalDamageMeter then
        menu[#menu + 1] = {
            text = LText("Close This Window"),
            danger = true,
            func = function()
                if Mod.CloseAdditionalDamageMeterWindow then
                    Mod:CloseAdditionalDamageMeterWindow(frame)
                end
            end,
        }
    end
    menu[#menu + 1] = { isSpacer = true }

    for _, group in ipairs(MODE_GROUPS) do
        local groupStart = #menu
        menu[#menu + 1] = { text = LText(group.label):upper(), isTitle = true }
        for _, configuredModeKey in ipairs(group.modes) do
            local modeKey = configuredModeKey
            if IsModeSupported(modeKey) then
                menu[#menu + 1] = {
                    text = LText(MODE_LABELS[modeKey]),
                    icon = MODE_ICONS[modeKey],
                    checked = cfg.mode == modeKey,
                    func = function()
                        cfg.mode = modeKey
                        RefreshAfterMenuSelection(frame)
                    end,
                }
            end
        end
        if #menu == groupStart + 1 then
            menu[#menu] = nil
        end
    end
    return menu
end

local function FormatSessionDuration(seconds)
    if IsSecret(seconds) or type(seconds) ~= "number" or seconds < 0 then
        return nil
    end
    return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function SelectSession(frame, sessionKey, sessionID, label, historyKey)
    local cfg = GetFrameConfig(frame)
    frame.selectedSessionID = sessionID
    frame.selectedSessionLabel = sessionID and label or nil
    frame.selectedSessionIcon = sessionID and sessionIcons[sessionID] or nil
    frame.selectedHistoryKey = sessionID and (historyKey or frame.selectedHistoryKey) or nil
    cfg.selectedSessionID = sessionID
    cfg.selectedSessionLabel = sessionID and label or nil
    cfg.selectedHistoryKey = frame.selectedHistoryKey
    if not sessionID then
        cfg.session = sessionKey
    end
    RefreshAfterMenuSelection(frame)
end

local function BuildSessionMenu(frame)
    local cfg = GetFrameConfig(frame)
    local menu = {}
    local C_DamageMeter = _G.C_DamageMeter
    local seenHistoryKeys = {}
    local hasHistoricalSessions = false

    if C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions then
        local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
        if ok and not IsSecret(sessions) and type(sessions) == "table" and #sessions > 0 then
            local firstIndex = math.max(1, #sessions - 11)
            for index = #sessions, firstIndex, -1 do
                local session = sessions[index]
                if IsSecret(session) or type(session) ~= "table" then session = nil end
                local sessionID = session and session.sessionID
                if sessionID ~= nil and not IsSecret(sessionID) then
                    local label = session.name
                    if IsSecret(label) or type(label) ~= "string" or label == "" then
                        label = string.format(LText("Combat %d"), index)
                    end
                    local duration = FormatSessionDuration(session.durationSeconds)
                    local menuLabel = duration and (label .. "  " .. duration) or label
                    local historyKey = BuildSessionStorageKey(session, index)
                    if historyKey then seenHistoryKeys[historyKey] = true end
                    menu[#menu + 1] = {
                        text = menuLabel,
                        icon = sessionIcons[sessionID],
                        checked = frame.selectedSessionID == sessionID and (not frame.selectedHistoryKey or frame.selectedHistoryKey == historyKey),
                        isNotRadio = false,
                        func = function()
                            SelectSession(frame, nil, sessionID, label, historyKey)
                        end,
                    }
                    hasHistoricalSessions = true
                end
            end
        end
    end

    for _, saved in ipairs(GetSavedCombatHistory().sessions) do
        if saved.key and not seenHistoryKeys[saved.key] then
            local duration = FormatSessionDuration(saved.durationSeconds)
            local label = saved.name or LText("Combat")
            menu[#menu + 1] = {
                text = duration and (label .. "  " .. duration) or label,
                checked = frame.selectedHistoryKey == saved.key,
                isNotRadio = false,
                func = function()
                    SelectSession(frame, nil, saved.nativeID, label, saved.key)
                end,
            }
            hasHistoricalSessions = true
        end
    end
    if hasHistoricalSessions then menu[#menu + 1] = { isSpacer = true } end

    menu[#menu + 1] = {
        text = LText("Current"),
        icon = currentSessionIcon,
        checked = not frame.selectedSessionID and cfg.session ~= "overall",
        isNotRadio = false,
        func = function()
            SelectSession(frame, "current")
        end,
    }
    menu[#menu + 1] = {
        text = LText("Overall"),
        checked = not frame.selectedSessionID and cfg.session == "overall",
        isNotRadio = false,
        func = function()
            SelectSession(frame, "overall")
        end,
    }

    if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
        menu[#menu + 1] = {
            text = LText("Reset All Data"),
            danger = true,
            func = function()
                pcall(C_DamageMeter.ResetAllCombatSessions)
                GetSavedCombatHistory().sessions = {}
                SelectSession(frame, "current")
            end,
        }
    end
    return menu
end

local function SetCurrentSessionIcon(frame, icon)
    if not icon or IsSecret(icon) then
        return false
    end
    currentSessionIcon = icon
    if not frame.selectedSessionID and GetFrameConfig(frame).session == "current" then
        RefreshSessionButtonIcon(frame)
    end
    return true
end

local function CaptureTargetSessionIcon(frame)
    if activeEncounterIcon or not frame or not frame.sessionPortraitProbe then
        return false
    end
    if not (SetPortraitTexture and UnitExists and UnitCanAttack) then
        return false
    end
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        return false
    end

    local ok = pcall(SetPortraitTexture, frame.sessionPortraitProbe, "target")
    if not ok then
        return false
    end
    return SetCurrentSessionIcon(frame, frame.sessionPortraitProbe:GetTexture())
end

function Mod:UndockDamageMeterFrame(frame)
    if not frame then
        return
    end
    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    local cfg = GetFrameConfig(frame)
    local restoreWidth = cfg.preDockWidth
    local restoreHeight = cfg.preDockHeight
    cfg.dock = nil
    if frameX and parentX then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", frameX - parentX, frameY - parentY)
        if restoreWidth then
            frame:SetWidth(math.max(MIN_METER_WIDTH, restoreWidth))
            cfg.width = math.floor(frame:GetWidth() + 0.5)
        end
        if restoreHeight then
            frame:SetHeight(math.max(MIN_METER_HEIGHT, restoreHeight))
            cfg.height = math.floor(frame:GetHeight() + 0.5)
        end
        SaveDamageMeterAbsolutePosition(frame)
    end
    cfg.preDockWidth = nil
    cfg.preDockHeight = nil
end

function Mod:BeginDamageMeterDrag(frame, fromHeader)
    if not frame or frame._damageMeterSizing then
        return
    end
    if GetFrameConfig(frame).locked == true then
        return
    end
    HideDropdown(activeDropdown)
    local cfg = GetFrameConfig(frame)
    local frameCenterX, frameCenterY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    local cursorX, cursorY = _G.GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale

    -- Preserve the exact on-screen rectangle when detaching. Restoring the old
    -- pre-dock size here made the frame jump underneath the cursor.
    cfg.dock = nil
    cfg.preDockWidth = nil
    cfg.preDockHeight = nil
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", frameCenterX - parentCenterX, frameCenterY - parentCenterY)
    frame._damageMeterDragging = true
    frame._damageMeterSnapElapsed = 0
    frame._damageMeterHeaderDragged = fromHeader == true
    frame._damageMeterDragCursorX = cursorX
    frame._damageMeterDragCursorY = cursorY
    frame._damageMeterDragOriginX = frameCenterX - parentCenterX
    frame._damageMeterDragOriginY = frameCenterY - parentCenterY
end

function Mod:UpdateDamageMeterDrag(frame, elapsed)
    if not frame or not frame._damageMeterDragging then
        return
    end
    local cursorX, cursorY = _G.GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local x = frame._damageMeterDragOriginX + cursorX - frame._damageMeterDragCursorX
    local y = frame._damageMeterDragOriginY + cursorY - frame._damageMeterDragCursorY
    local halfWidth, halfHeight = frame:GetWidth() * 0.5, frame:GetHeight() * 0.5
    x = math.max(-(UIParent:GetWidth() * 0.5) + halfWidth, math.min(UIParent:GetWidth() * 0.5 - halfWidth, x))
    y = math.max(-(UIParent:GetHeight() * 0.5) + halfHeight, math.min(UIParent:GetHeight() * 0.5 - halfHeight, y))
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    frame._damageMeterSnapElapsed = (frame._damageMeterSnapElapsed or 0) + elapsed
    if frame._damageMeterSnapElapsed < SNAP_UPDATE_INTERVAL then
        return
    end
    frame._damageMeterSnapElapsed = 0

    local previous = frame._damageMeterSnapCandidate
    local candidate = FindDamageMeterSnapCandidate(frame)
    if previous and previous.target ~= (candidate and candidate.target) then
        SetDamageMeterSnapGlow(previous.target, false)
    end
    frame._damageMeterSnapCandidate = candidate
    SetDamageMeterSnapGlow(frame, candidate ~= nil)
    if candidate then
        SetDamageMeterSnapGlow(candidate.target, true)
    end
end

function Mod:EndDamageMeterDrag(frame)
    if not frame or not frame._damageMeterDragging then
        return
    end
    frame._damageMeterDragging = nil
    frame._damageMeterDragCursorX = nil
    frame._damageMeterDragCursorY = nil
    frame._damageMeterDragOriginX = nil
    frame._damageMeterDragOriginY = nil

    local candidate = frame._damageMeterSnapCandidate or FindDamageMeterSnapCandidate(frame)
    frame._damageMeterSnapCandidate = nil
    SetDamageMeterSnapGlow(frame, false)
    if candidate then
        SetDamageMeterSnapGlow(candidate.target, false)
        local cfg = GetFrameConfig(frame)
        if candidate.point == "LEFT" or candidate.point == "RIGHT" then
            cfg.preDockHeight = cfg.preDockHeight or frame:GetHeight()
        else
            cfg.preDockWidth = cfg.preDockWidth or frame:GetWidth()
        end
        cfg.dock = {
            target = candidate.targetID,
            point = candidate.point,
            relativePoint = candidate.relativePoint,
            x = candidate.x,
            y = candidate.y,
        }
        ApplyDamageMeterDock(frame, cfg.dock)
    else
        SaveDamageMeterAbsolutePosition(frame)
    end
    if frame._damageMeterHeaderDragged then
        C_Timer.After(0, function()
            if frame and not frame._damageMeterDragging then
                frame._damageMeterHeaderDragged = nil
            end
        end)
    end
end

function Mod:RegisterDamageMeterDirectDrag(frame)
    if not frame or frame.damageMeterDirectDragRegistered then
        return
    end
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        Mod:BeginDamageMeterDrag(self, false)
        if self._damageMeterDragging then
            self:SetScript("OnUpdate", function(activeFrame, elapsed)
                Mod:UpdateDamageMeterDrag(activeFrame, elapsed)
            end)
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        Mod:EndDamageMeterDrag(self)
    end)

    for _, button in ipairs({ frame.modeButton, frame.sessionButton }) do
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function()
            Mod:BeginDamageMeterDrag(frame, true)
            if frame._damageMeterDragging then
                frame:SetScript("OnUpdate", function(activeFrame, elapsed)
                    Mod:UpdateDamageMeterDrag(activeFrame, elapsed)
                end)
            end
        end)
        button:SetScript("OnDragStop", function()
            frame:SetScript("OnUpdate", nil)
            Mod:EndDamageMeterDrag(frame)
        end)
    end
    frame.damageMeterDirectDragRegistered = true
end

local function CreateDamageMeterFrame(self, frameName, damageMeterConfig)
    local frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    frame.damageMeterConfig = damageMeterConfig
    frame.selectedSessionID = damageMeterConfig.selectedSessionID
    frame.selectedSessionLabel = damageMeterConfig.selectedSessionLabel
    frame.selectedHistoryKey = damageMeterConfig.selectedHistoryKey
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_METER_WIDTH, MIN_METER_HEIGHT, 720, 700)
    frame:HookScript("OnHide", function()
        HideDropdown(activeDropdown)
    end)
    frame:HookScript("OnShow", function(self)
        self:SetFrameStrata("DIALOG")
        self:SetFrameLevel(100)
        if self.Raise then self:Raise() end
    end)

    frame.accentLine = frame:CreateTexture(nil, "ARTWORK")
    frame.accentLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.accentLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.accentLine:SetHeight(2)

    frame.snapGlow = {}
    local snapAnchors = {
        { "TOPLEFT", "TOPRIGHT", 2 },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 2 },
        { "TOPLEFT", "BOTTOMLEFT", nil, 2 },
        { "TOPRIGHT", "BOTTOMRIGHT", nil, 2 },
    }
    for index, anchors in ipairs(snapAnchors) do
        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetPoint(anchors[1], frame, anchors[1], 0, 0)
        texture:SetPoint(anchors[2], frame, anchors[2], 0, 0)
        if anchors[3] then
            texture:SetHeight(anchors[3])
        else
            texture:SetWidth(anchors[4])
        end
        texture:Hide()
        frame.snapGlow[index] = texture
    end

    frame.modeButton = CreateHeaderButton(frame)
    frame.modeButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    frame.modeButton:SetWidth(166)
    frame.modeButton.icon = frame.modeButton:CreateTexture(nil, "ARTWORK")
    frame.modeButton.icon:SetSize(18, 18)
    frame.modeButton.icon:SetPoint("LEFT", frame.modeButton, "LEFT", 5, 0)
    frame.modeButton.text:ClearAllPoints()
    frame.modeButton.text:SetPoint("LEFT", frame.modeButton.icon, "RIGHT", 5, 0)
    frame.modeButton.text:SetPoint("RIGHT", frame.modeButton.arrow, "LEFT", -3, 0)
    frame.modeButton.text:SetJustifyH("LEFT")
    frame.modeButton.damageMeterFrame = frame
    frame.modeButton:SetScript("OnClick", function(self)
        if frame._damageMeterHeaderDragged then
            frame._damageMeterHeaderDragged = nil
            return
        end
        ShowDropdown(self, frameName .. "ModeDropdown", BuildModeMenu(self.damageMeterFrame))
    end)

    frame.sessionButton = CreateHeaderButton(frame)
    frame.sessionButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    frame.sessionButton:SetWidth(84)
    frame.sessionButton.icon = frame.sessionButton:CreateTexture(nil, "ARTWORK")
    frame.sessionButton.icon:SetSize(18, 18)
    frame.sessionButton.icon:SetPoint("LEFT", frame.sessionButton, "LEFT", 5, 0)
    frame.sessionButton.icon:Hide()
    frame.sessionButton.damageMeterFrame = frame
    frame.sessionButton:SetScript("OnClick", function(self)
        if frame._damageMeterHeaderDragged then
            frame._damageMeterHeaderDragged = nil
            return
        end
        ShowDropdown(self, frameName .. "SessionDropdown", BuildSessionMenu(self.damageMeterFrame))
    end)

    frame.sessionPortraitProbe = frame:CreateTexture(nil, "BACKGROUND")
    frame.sessionPortraitProbe:SetSize(1, 1)
    frame.sessionPortraitProbe:Hide()

    frame.emptyText = frame:CreateFontString(nil, "OVERLAY")
    frame.emptyText:SetFont(DAMAGE_METER_RESOLVED_FONT(), 12, "OUTLINE")
    ApplyFontReadability(frame.emptyText)
    frame.emptyText:SetPoint("CENTER", frame, "CENTER", 0, -8)
    frame.emptyText:SetText(LText("No combat data"))

    frame.scrollText = frame:CreateFontString(nil, "OVERLAY")
    frame.scrollText:SetFont(DAMAGE_METER_RESOLVED_FONT(), 10, "OUTLINE")
    ApplyFontReadability(frame.scrollText)
    frame.scrollText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 4)
    frame.scrollText:SetTextColor(0.62, 0.62, 0.68, 1)
    frame.scrollText:Hide()

    frame.rows = {}
    for index = 1, MAX_ROW_POOL do
        frame.rows[index] = CreateRow(frame, index)
    end

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        local visibleLimit = self._damageMeterVisibleLimit
        local sourceCount = self._damageMeterSourceCount
        if type(visibleLimit) ~= "number" or type(sourceCount) ~= "number" or sourceCount < 1 then
            return
        end
        local maximumOffset = math.max(0, sourceCount - visibleLimit)
        local nextOffset = math.max(0, math.min(maximumOffset, (self.damageMeterScrollOffset or 0) - (delta * 3)))
        if nextOffset ~= self.damageMeterScrollOffset then
            self.damageMeterScrollOffset = nextOffset
            self._damageMeterManualScroll = true
            Mod:UpdateDamageMeterData(self)
        end
    end)

    frame.resizeHandle = CreateFrame("Button", nil, frame)
    frame.resizeHandle:SetSize(16, 16)
    frame.resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 8)
    frame.resizeHandle.texture = frame.resizeHandle:CreateTexture(nil, "OVERLAY")
    frame.resizeHandle.texture:SetAllPoints()
    frame.resizeHandle.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resizeHandle.texture:SetVertexColor(0.78, 0.78, 0.82, 0.7)
    frame.resizeHandle:SetScript("OnEnter", function(self)
        self.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        self.texture:SetVertexColor(1, 1, 1, 1)
    end)
    frame.resizeHandle:SetScript("OnLeave", function(self)
        self.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        self.texture:SetVertexColor(0.78, 0.78, 0.82, 0.7)
    end)
    frame.resizeHandle:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or GetFrameConfig(frame).locked == true then
            return
        end
        local left, top = frame:GetLeft(), frame:GetTop()
        if not left or not top then
            return
        end
        local cfg = GetFrameConfig(frame)
        -- StartSizing keeps the opposite corner of the active anchor fixed.
        -- Saved CENTER/dock anchors therefore made BOTTOMRIGHT resizing move
        -- the window. Pin its top-left corner and detach any dock without
        -- restoring the old pre-dock size.
        cfg.dock = nil
        cfg.preDockWidth = nil
        cfg.preDockHeight = nil
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        frame._damageMeterSizing = true
        frame:StartSizing("BOTTOMRIGHT")
    end)
    frame.resizeHandle:SetScript("OnMouseUp", function()
        if not frame._damageMeterSizing then
            return
        end
        frame:StopMovingOrSizing()
        frame._damageMeterSizing = nil
        local cfg = GetFrameConfig(frame)
        cfg.width = math.floor(frame:GetWidth() + 0.5)
        cfg.height = math.floor(frame:GetHeight() + 0.5)
        cfg.autoHeight = false
        SaveDamageMeterAbsolutePosition(frame)
        Mod:RefreshDamageMeterStyle(false, frame)
        Mod:UpdateDamageMeterData(frame)
        if not Mod._syncingDamageMeterDockSizes then
            Mod._syncingDamageMeterDockSizes = true
            SyncDamageMeterDockDependents(frame)
            Mod._syncingDamageMeterDockSizes = nil
        end
    end)
    frame.resizeHandle:SetScript("OnHide", function()
        if frame._damageMeterSizing then
            frame:StopMovingOrSizing()
            frame._damageMeterSizing = nil
        end
    end)

    frame.lockButton = CreateFrame("Button", nil, frame)
    frame.lockButton:SetSize(54, 16)
    frame.lockButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 1)
    frame.lockButton:SetFrameLevel(frame:GetFrameLevel() + 9)
    frame.lockButton.text = frame.lockButton:CreateFontString(nil, "OVERLAY")
    frame.lockButton.text:SetFont(DAMAGE_METER_RESOLVED_FONT(), 9, "OUTLINE")
    frame.lockButton.text:SetAllPoints()
    frame.lockButton.text:SetJustifyH("RIGHT")
    ApplyFontReadability(frame.lockButton.text)
    frame.lockButton:SetScript("OnClick", function()
        local cfg = GetFrameConfig(frame)
        cfg.locked = cfg.locked ~= true
        RefreshDamageMeterLockControl(frame)
    end)
    frame.lockButton:SetScript("OnEnter", function(self)
        local r, g, b = GetAccentColor()
        self:SetAlpha(1)
        self.text:SetTextColor(r, g, b, 1)
    end)
    frame.lockButton:SetScript("OnLeave", function()
        RefreshDamageMeterLockControl(frame)
    end)
    frame:HookScript("OnEnter", function()
        RefreshDamageMeterLockControl(frame)
    end)
    frame:HookScript("OnLeave", function()
        C_Timer.After(0, function()
            if frame then
                RefreshDamageMeterLockControl(frame)
            end
        end)
    end)

    frame:SetScript("OnSizeChanged", function()
        -- Native anchors and the backdrop resize continuously. Rebuilding all
        -- rows and querying C_DamageMeter on every mouse pixel caused visible
        -- jumps and needless work; commit the expensive refresh on MouseUp.
    end)

    self:RegisterDamageMeterDirectDrag(frame)
    self:RefreshDamageMeterStyle(false, frame)
    self:ApplyDamageMeterPosition(frame)
    self:UpdateDamageMeterData(frame)
    self:UpdateDamageMeterVisibility(frame)
    return frame
end

function Mod:GetDamageMeterFrame()
    if not self.damageMeterFrame then
        self.damageMeterFrame = CreateDamageMeterFrame(self, "KullThranUIDamageMeterFrame", GetConfig())
    else
        self.damageMeterFrame.damageMeterConfig = GetConfig()
    end
    return self.damageMeterFrame
end

local function CreateAdditionalConfig(sourceFrame, index)
    local source = GetFrameConfig(sourceFrame)
    local sourceX, sourceY = 0, 0
    local sourceCenterX, sourceCenterY
    if sourceFrame then
        sourceCenterX, sourceCenterY = sourceFrame:GetCenter()
    end
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    if sourceCenterX and parentCenterX then
        sourceX = sourceCenterX - parentCenterX
        sourceY = sourceCenterY - parentCenterY
    end

    local mode = source.mode or "damageDone"
    if mode == "damageDone" and IsModeSupported("healingDone") then
        mode = "healingDone"
    end
    return {
        enabled = true,
        locked = false,
        showOnlyInCombat = source.showOnlyInCombat == true,
        showBackground = source.showBackground ~= false,
        showIcons = source.showIcons ~= false,
        iconMode = source.iconMode or (source.showIcons == false and "none" or "spec"),
        iconShape = source.iconShape == "round" and "round" or "square",
        font = source.font or DAMAGE_METER_FONT,
        barTexture = source.barTexture or BAR_TEXTURE,
        autoHeight = source.autoHeight ~= false,
        classColors = source.classColors ~= false,
        alwaysShowPlayer = source.alwaysShowPlayer == true,
        showPercentages = source.showPercentages == true,
        mode = mode,
        session = source.session or "current",
        width = tonumber(source.width) or 320,
        height = tonumber(source.height) or 220,
        rowHeight = tonumber(source.rowHeight) or 19,
        maxRows = tonumber(source.maxRows) or 10,
        fontSize = tonumber(source.fontSize) or 12,
        headerFontSize = tonumber(source.headerFontSize) or 12,
        position = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = sourceX + (24 * index),
            y = sourceY - (24 * index),
        },
    }
end

function Mod:RegisterAdditionalDamageMeterMover(index, frame, cfg)
    if not KT.RegisterMovableElements or frame.damageMeterMoverRegistered then
        return
    end
    KT:RegisterMovableElements({
        {
            key = "ENH_DAMAGE_METER_" .. index,
            label = string.format(LText("Damage Meter %d"), index + 1),
            group = "Enhancements",
            getFrame = function() return frame end,
            getSize = function() return frame:GetWidth(), frame:GetHeight() end,
            isHidden = function() return GetFrameConfig(frame).enabled ~= true end,
            loadPosition = function()
                local pos = GetFrameConfig(frame).position or {}
                return {
                    point = pos.point or "CENTER",
                    relativePoint = pos.relativePoint or pos.point or "CENTER",
                    x = pos.x or 0,
                    y = pos.y or 0,
                }
            end,
            savePosition = function(_, point, relativePoint, x, y)
                local currentCfg = GetFrameConfig(frame)
                currentCfg.dock = nil
                currentCfg.position = {
                    point = point or "CENTER",
                    relativePoint = relativePoint or point or "CENTER",
                    x = x or 0,
                    y = y or 0,
                }
            end,
            applyPosition = function()
                Mod:ApplyDamageMeterPosition(frame)
            end,
            applyPendingPosition = function(_, pos)
                GetFrameConfig(frame).dock = nil
                frame:ClearAllPoints()
                frame:SetPoint(
                    pos.point or "CENTER",
                    UIParent,
                    pos.relativePoint or pos.point or "CENTER",
                    pos.x or 0,
                    pos.y or 0
                )
            end,
        },
    })
    frame.damageMeterMoverRegistered = true
end

function Mod:CreateAdditionalDamageMeterWindow(sourceFrame, existingIndex, existingConfig)
    local primary = GetConfig()
    if rawget(primary, "windows") == nil then
        primary.windows = {}
    end
    local windows = primary.windows
    local index = existingIndex
    local cfg = existingConfig

    if not index then
        for candidateIndex, candidateConfig in ipairs(windows) do
            if candidateConfig.enabled == false then
                index = candidateIndex
                cfg = candidateConfig
                cfg.enabled = true
                break
            end
        end
    end
    if not index then
        if #windows >= 5 then
            return nil
        end
        index = #windows + 1
        cfg = CreateAdditionalConfig(sourceFrame or self:GetDamageMeterFrame(), index)
        windows[index] = cfg
    end
    cfg.position = cfg.position or {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 24 * index,
        y = -24 * index,
    }
    cfg.width = math.max(MIN_METER_WIDTH, tonumber(cfg.width) or 320)
    cfg.height = math.max(MIN_METER_HEIGHT, tonumber(cfg.height) or 220)
    cfg.mode = IsModeSupported(cfg.mode) and cfg.mode or "damageDone"
    cfg.session = cfg.session == "overall" and "overall" or "current"

    self.additionalDamageMeterFrames = self.additionalDamageMeterFrames or {}
    local frame = self.additionalDamageMeterFrames[index]
    if frame then
        frame.damageMeterConfig = cfg
        frame.isAdditionalDamageMeter = true
        frame.additionalDamageMeterIndex = index
        self:RefreshDamageMeterStyle(false, frame)
        self:ApplyDamageMeterPosition(frame)
        self:UpdateDamageMeterVisibility(frame)
        self:UpdateDamageMeterData(frame)
    else
        frame = CreateDamageMeterFrame(self, "KullThranUIDamageMeterFrame" .. (index + 1), cfg)
        frame.isAdditionalDamageMeter = true
        frame.additionalDamageMeterIndex = index
        self.additionalDamageMeterFrames[index] = frame
    end
    self:RegisterAdditionalDamageMeterMover(index, frame, cfg)
    self:UpdateDamageMeterVisibility(frame)
    if UnitAffectingCombat("player") then self:StartDamageMeterLiveRefresh() end
    return frame
end

function Mod:CloseAdditionalDamageMeterWindow(frame)
    if not frame or not frame.isAdditionalDamageMeter then
        return
    end
    local closedID = GetDamageMeterDockID(frame)
    for _, otherFrame in ipairs(GetDamageMeterFrames()) do
        local otherDock = GetFrameConfig(otherFrame).dock
        if otherFrame ~= frame and otherDock and otherDock.target == closedID then
            self:UndockDamageMeterFrame(otherFrame)
        end
    end
    local cfg = GetFrameConfig(frame)
    if cfg.dock then
        self:UndockDamageMeterFrame(frame)
    end
    cfg.enabled = false
    HideDropdown(activeDropdown)
    frame:Hide()
    if UnitAffectingCombat("player") then self:StartDamageMeterLiveRefresh() end
end

function Mod:RestoreAdditionalDamageMeterWindows()
    local primary = GetConfig()
    if rawget(primary, "windows") == nil then
        primary.windows = {}
    end
    for index, frame in pairs(self.additionalDamageMeterFrames or {}) do
        local cfg = primary.windows[index]
        if cfg then
            frame.damageMeterConfig = cfg
        else
            frame.damageMeterConfig = {
                enabled = false,
                position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
            }
            frame:Hide()
        end
    end
    for index, cfg in ipairs(primary.windows) do
        if cfg.enabled == true then
            self:CreateAdditionalDamageMeterWindow(self:GetDamageMeterFrame(), index, cfg)
        elseif self.additionalDamageMeterFrames and self.additionalDamageMeterFrames[index] then
            self.additionalDamageMeterFrames[index]:Hide()
        end
    end
end

function Mod:RegisterDamageMeterMover()
    if self.damageMeterMoverRegistered or not KT.RegisterMovableElements then
        return
    end
    KT:RegisterMovableElements({
        {
            key = "ENH_DAMAGE_METER",
            label = LText("Damage Meter"),
            group = "Enhancements",
            getFrame = function() return Mod:GetDamageMeterFrame() end,
            getSize = function()
                local frame = Mod:GetDamageMeterFrame()
                return frame:GetWidth(), frame:GetHeight()
            end,
            isHidden = function()
                return GetConfig().enabled ~= true
            end,
            loadPosition = function()
                local pos = GetConfig().position
                return {
                    point = pos.point or "RIGHT",
                    relativePoint = pos.relativePoint or pos.point or "RIGHT",
                    x = pos.x or -36,
                    y = pos.y or 0,
                }
            end,
            savePosition = function(_, point, relativePoint, x, y)
                local cfg = GetConfig()
                cfg.dock = nil
                cfg.position = {
                    point = point or "RIGHT",
                    relativePoint = relativePoint or point or "RIGHT",
                    x = x or -36,
                    y = y or 0,
                }
            end,
            applyPosition = function()
                Mod:ApplyDamageMeterPosition()
            end,
            applyPendingPosition = function(_, pos)
                local frame = Mod:GetDamageMeterFrame()
                GetConfig().dock = nil
                frame:ClearAllPoints()
                frame:SetPoint(pos.point or "RIGHT", UIParent, pos.relativePoint or pos.point or "RIGHT", pos.x or -36, pos.y or 0)
            end,
        },
    })
    self.damageMeterMoverRegistered = true
end

function Mod:PreviewDamageMeter(windowIndex)
    windowIndex = tonumber(windowIndex) or 0
    local frame
    if windowIndex > 0 then
        local windows = GetConfig().windows or {}
        local cfg = windows[windowIndex]
        if cfg then
            cfg.enabled = true
            frame = self:CreateAdditionalDamageMeterWindow(self:GetDamageMeterFrame(), windowIndex, cfg)
        end
    else
        frame = self:GetDamageMeterFrame()
        GetFrameConfig(frame).enabled = true
    end
    if not frame then
        return
    end
    frame.damageMeterPreviewUntil = GetTime() + 10
    self:RefreshDamageMeterStyle(false, frame)
    self:ApplyDamageMeterPosition(frame)
    self:UpdateDamageMeterVisibility(frame)
    self:UpdateDamageMeterData(frame)
    frame:Show()
    C_Timer.After(10.05, function()
        if frame and not IsDamageMeterPreviewing(frame) then
            Mod:UpdateDamageMeterVisibility(frame)
        end
    end)
end

function Mod:RefreshDamageMeter()
    if not IsDamageMeterModuleEnabled() then
        self:StopDamageMeterLiveRefresh(false)
        if self.damageMeterFrame then self.damageMeterFrame:Hide() end
        for _, frame in pairs(self.additionalDamageMeterFrames or {}) do frame:Hide() end
        return
    end
    self:RegisterDamageMeterMover()
    self:GetDamageMeterFrame()
    self:RestoreAdditionalDamageMeterWindows()
    self:RefreshDamageMeterStyle()
    self:ApplyDamageMeterPosition()
    for _, frame in pairs(self.additionalDamageMeterFrames or {}) do
        self:RefreshDamageMeterStyle(false, frame)
        self:ApplyDamageMeterPosition(frame)
    end
    self:InvalidateDamageMeterDataCache()
    self:RefreshVisibleDamageMeterWindows()
    if UnitAffectingCombat("player") then
        self:StartDamageMeterLiveRefresh()
    else
        self:StopDamageMeterLiveRefresh(false)
    end
end
