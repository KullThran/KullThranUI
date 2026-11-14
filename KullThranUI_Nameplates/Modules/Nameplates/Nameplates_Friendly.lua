local addon, ns = ...

if not ns then return end

local PP = (KullThranUI and KullThranUI.PP) or (KT and KT.PP)

local function Loc(text)
    local core = ns.KT or KullThranUI or KT
    local L = core and core.GetLocale and core:GetLocale()
    return (L and L[text]) or text
end

local function PixelPoint(frame, point, relativeTo, relativePoint, x, y)
    if PP and PP.Point then
        PP.Point(frame, point, relativeTo, relativePoint, x, y)
    else
        frame:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    end
end

local function PixelSize(frame, width, height)
    if PP and PP.Size then
        PP.Size(frame, width, height)
    else
        frame:SetSize(width or 0, height or 0)
    end
end

local function PixelWidth(frame, width)
    if PP and PP.Width then
        PP.Width(frame, width)
    else
        frame:SetWidth(width or 0)
    end
end

local function PixelHeight(frame, height)
    if PP and PP.Height then
        PP.Height(frame, height)
    else
        frame:SetHeight(height or 0)
    end
end
local function GetHealthBarHeight(...)
    local getter = ns.GetHealthBarHeight
    return getter and getter(...) or 30
end
local function GetFriendlyHealthBarHeight(...)
    local getter = ns.GetFriendlyHealthBarHeight
    return getter and getter(...) or 12
end
local function GetFriendlyHealthBarWidth(...)
    local getter = ns.GetFriendlyHealthBarWidth
    return getter and getter(...) or 80
end

local function SetFriendlyFSFont(fs, size, flags)
    local setter = ns and ns.SetFSFont
    if setter then
        return setter(fs, size, flags)
    end

    if not fs or not fs.SetFont then
        return
    end

    local fontPath = (ns and ns.GetFont and ns.GetFont()) or "Fonts\\FRIZQT__.TTF"
    local outline = flags
    if outline == nil then
        outline = (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE"
    end
    fs:SetFont(fontPath, tonumber(size) or 11, outline)
    if KT and KT.EnableTextFontFallback then
        KT:EnableTextFontFallback(fs, fontPath)
    end
    if outline == "" then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local pairs, ipairs = pairs, ipairs
local unpack = unpack or table.unpack
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitName, UnitIsUnit = UnitName, UnitIsUnit
local UnitCanAttack, UnitIsPlayer = UnitCanAttack, UnitIsPlayer
local UnitClass, UnitIsDeadOrGhost = UnitClass, UnitIsDeadOrGhost
local UnitExists, UnitHealthPercent = UnitExists, UnitHealthPercent
local GetGuildInfo = GetGuildInfo
local GetRaidTargetIndex, SetRaidTargetIconTexture = GetRaidTargetIndex, SetRaidTargetIconTexture
local C_NamePlate = C_NamePlate
local C_TooltipInfo = C_TooltipInfo
local Enum = Enum
local issecretvalue, canaccessvalue = issecretvalue, canaccessvalue

local RawUnitAPI = {
    UnitName = UnitName, UnitIsUnit = UnitIsUnit, UnitCanAttack = UnitCanAttack,
    UnitIsPlayer = UnitIsPlayer, UnitClass = UnitClass,
    UnitIsDeadOrGhost = UnitIsDeadOrGhost, UnitExists = UnitExists,
    UnitHealthPercent = UnitHealthPercent, UnitReaction = UnitReaction,
    GetGuildInfo = GetGuildInfo, GetRaidTargetIndex = GetRaidTargetIndex,
}

local function IsAccessible(value)
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return true
end

local function SafePredicate(func, inaccessibleFallback, ...)
    if not func then return inaccessibleFallback end
    local ok, value = pcall(func, ...)
    if not ok or not IsAccessible(value) then return inaccessibleFallback end
    return value == true
end

UnitIsUnit = function(...) return SafePredicate(RawUnitAPI.UnitIsUnit, false, ...) end
UnitCanAttack = function(...) return SafePredicate(RawUnitAPI.UnitCanAttack, true, ...) end
UnitIsPlayer = function(...) return SafePredicate(RawUnitAPI.UnitIsPlayer, true, ...) end
UnitIsDeadOrGhost = function(...) return SafePredicate(RawUnitAPI.UnitIsDeadOrGhost, false, ...) end
UnitExists = function(...) return SafePredicate(RawUnitAPI.UnitExists, false, ...) end
UnitName = function(...)
    local value = RawUnitAPI.UnitName and RawUnitAPI.UnitName(...)
    return IsAccessible(value) and type(value) == "string" and value or nil
end
UnitClass = function(...)
    if not RawUnitAPI.UnitClass then return nil, nil end
    local localized, token = RawUnitAPI.UnitClass(...)
    if not IsAccessible(localized) or not IsAccessible(token) then return nil, nil end
    return localized, token
end
UnitHealthPercent = function(...)
    local value = RawUnitAPI.UnitHealthPercent and RawUnitAPI.UnitHealthPercent(...)
    return IsAccessible(value) and type(value) == "number" and value or nil
end
GetGuildInfo = function(...)
    local value = RawUnitAPI.GetGuildInfo and RawUnitAPI.GetGuildInfo(...)
    return IsAccessible(value) and type(value) == "string" and value or nil
end
GetRaidTargetIndex = function(...)
    local value = RawUnitAPI.GetRaidTargetIndex and RawUnitAPI.GetRaidTargetIndex(...)
    return IsAccessible(value) and type(value) == "number" and value or nil
end

-- Raid marker as the client gives it. For friendly units it can be a secret
-- value, which the wrapper above drops: allied NPCs never showed their marker.
-- Blizzard's SetRaidTargetIconTexture takes it as is (the enemy plates pass it
-- the same way); only type() is used on it here.
function ns.FriendlyRaidMarker(unit)
    local get = RawUnitAPI.GetRaidTargetIndex
    if not get then return nil end
    local ok, value = pcall(get, unit)
    if not ok or type(value) == "nil" then return nil end
    return value
end

function ns.SetFriendlyRaidMarkerTexture(texture, index)
    return (pcall(SetRaidTargetIconTexture, texture, index))
end

local function GetAccessibleNamePlates(includeForbidden)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return {} end
    local ok, plates = pcall(C_NamePlate.GetNamePlates, includeForbidden)
    if not ok or not IsAccessible(plates) or type(plates) ~= "table" then return {} end
    local copy = {}
    local copied = pcall(function()
        for index = 1, #plates do
            local plate = plates[index]
            if plate then copy[#copy + 1] = plate end
        end
    end)
    return copied and copy or {}
end

-- Pooled health-bar frames keyed by unit token; shared with Nameplates.lua.
local friendlyPlates = {}
ns.friendlyPlates = friendlyPlates
ns.friendlyPlatesByNameplate = ns.friendlyPlatesByNameplate or {}

local FRIENDLY_BAR_W = 80
local FRIENDLY_PLATE_Y_OFFSET = -18

local function FriendlyDBVal(key, defaultValue)
    local db = KullThranUINameplatesDB
    if db and db[key] ~= nil then
        return db[key]
    end
    return defaultValue
end

local function FriendlyDBColor(key, defaultR, defaultG, defaultB)
    local db = KullThranUINameplatesDB
    local c = db and db[key]
    if c then
        return c.r, c.g, c.b
    end
    return defaultR, defaultG, defaultB
end

local function GetFriendlyPlayerNameTextSize()
    return FriendlyDBVal("friendlyPlayerNameTextSize", 12)
end

local function GetFriendlyGuildTextSize()
    return FriendlyDBVal("friendlyGuildTextSize", 12)
end

local function GetFriendlyHealthTextSize()
    return FriendlyDBVal("friendlyHealthTextSize", 10)
end

local function GetFriendlyNPCNameTextSize()
    -- Friendly NPC names use the same readable size as friendly player names.
    return FriendlyDBVal("friendlyNPCNameTextSize", 12)
end

local function GetFriendlyPlayerNameAlignment()
    return FriendlyDBVal("friendlyPlayerNameAlignment", FriendlyDBVal("friendlyNameAlignment", "center"))
end

local function GetFriendlyNPCNameAlignment()
    return FriendlyDBVal("friendlyNPCNameAlignment", "center")
end

local function GetAlignmentJustify(alignment)
    if alignment == "left" then
        return "LEFT"
    elseif alignment == "right" then
        return "RIGHT"
    end
    return "CENTER"
end

local function GetFriendlyPlayerNameColor()
    return FriendlyDBColor("friendlyPlayerNameColor", 1, 1, 1)
end

local function GetFriendlyGuildColor()
    return FriendlyDBColor("friendlyGuildColor", 1, 1, 1)
end

local function GetFriendlyHealthTextColor()
    return FriendlyDBColor("friendlyHealthTextColor", 1, 1, 1)
end

local function GetFriendlyNPCNameColor()
    return FriendlyDBColor("friendlyNPCNameColor", 0, 1, 0)
end

local function GetFriendlyNPCDescriptionTextSize()
    return FriendlyDBVal("friendlyNPCDescriptionTextSize", 10)
end

local function GetFriendlyNPCDescriptionColor()
    return FriendlyDBColor("friendlyNPCDescriptionColor", 0.85, 0.85, 0.85)
end

local function SafeTooltipLineText(line)
    if not IsAccessible(line) or type(line) ~= "table" then return nil end
    local text = line.leftText
    if not IsAccessible(text) or type(text) ~= "string" or text == "" then return nil end
    -- Tooltip text can carry color/icon markup; the nameplate only needs the
    -- readable occupation text.
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T.-|t", "")
        :gsub("|A.-|a", "")
    text = text:match("^%s*(.-)%s*$")
    return text ~= "" and text or nil
end

local function GetTooltipUnitText(unit, functionName)
    local fn = _G[functionName]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, unit)
    if ok and IsAccessible(value) and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function IsNonOccupationTooltipType(lineType, tooltipTypes)
    if not lineType or not tooltipTypes then return false end
    local excluded = {
        "UnitName", "UnitLevel", "UnitClass", "UnitRace", "UnitGuild",
        "UnitFaction", "UnitReaction", "UnitCreatureType",
        "UnitCreatureFamily", "UnitClassification",
    }
    for _, key in ipairs(excluded) do
        if tooltipTypes[key] and lineType == tooltipTypes[key] then
            return true
        end
    end
    return false
end

local function IsNPCOccupationCandidate(unit, text, unitName)
    if not text or text == "" then return false end
    if unitName and text == unitName then return false end
    if text:match("^%d+$") or text:match("^%d+%s*[-:]") then return false end

    local unitLevel
    if type(UnitLevel) == "function" then
        local ok, value = pcall(UnitLevel, unit)
        if ok and IsAccessible(value) and type(value) == "number" and value >= 0 then
            unitLevel = tostring(value)
        end
    end
    if unitLevel then
        local lowerText = text:lower()
        local levelLabel = type(_G.LEVEL) == "string" and _G.LEVEL:lower() or "level"
        if lowerText == (levelLabel .. " " .. unitLevel)
            or lowerText == ("level " .. unitLevel)
            or lowerText == ("nivel " .. unitLevel) then
            return false
        end
    end

    local creatureType = GetTooltipUnitText(unit, "UnitCreatureType")
    local creatureFamily = GetTooltipUnitText(unit, "UnitCreatureFamily")
    if (creatureType and text == creatureType) or (creatureFamily and text == creatureFamily) then
        return false
    end

    -- Keep the guard for clients that return a localized creature type in
    -- the tooltip but do not expose it through UnitCreatureType().
    local lower = text:lower()
    local commonCreatureTypes = {
        humanoid = true, beast = true, demon = true, dragonkin = true,
        elemental = true, giant = true, undead = true, mechanical = true,
        critter = true, aberration = true, gas = true,
    }
    return not commonCreatureTypes[lower]
end

-- Returns the readable line array of the unit tooltip, or nil when the data
-- is missing or restricted.
local function ReadUnitTooltipLines(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
    local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or not IsAccessible(info) or type(info) ~= "table" then return nil end
    local lines = info.lines
    if not IsAccessible(lines) or type(lines) ~= "table" then return nil end
    return lines
end

-- Walks the tooltip lines once and returns the first occupation candidate
-- whose (readable) line type passes `acceptType`.
local function FirstOccupationLine(unit, lines, unitName, acceptType)
    for _, line in ipairs(lines) do
        if IsAccessible(line) and type(line) == "table" then
            local lineType = IsAccessible(line.type) and line.type or nil
            if acceptType(lineType) then
                local text = SafeTooltipLineText(line)
                if IsNPCOccupationCandidate(unit, text, unitName) then return text end
            end
        end
    end
    return nil
end

-- Occupation subtitle ("Innkeeper", "Flight Master"...) of a friendly NPC.
-- Lines tagged as UnitTitle win; otherwise any untagged line that is not a
-- name/level/race/faction line is accepted (some clients leave it untyped).
-- Creature type/family labels are never used as a fallback.
local function GetFriendlyNPCDescription(unit)
    if not unit or UnitIsPlayer(unit) or UnitCanAttack("player", unit) then return nil end

    local lines = ReadUnitTooltipLines(unit)
    if not lines then return nil end

    local lineTypes = Enum and Enum.TooltipDataLineType
    local titleType = lineTypes and lineTypes.UnitTitle
    local unitName = UnitName(unit)
    if not IsAccessible(unitName) then unitName = nil end

    local tagged = titleType and FirstOccupationLine(unit, lines, unitName, function(lineType)
        return lineType == titleType
    end)
    if tagged then return tagged end
    return FirstOccupationLine(unit, lines, unitName, function(lineType)
        return not IsNonOccupationTooltipType(lineType, lineTypes)
    end)
end
local function ApplyAlignedTextLayout(fs, anchor, yOffset, alignment)
    if not fs then return end
    local align = alignment or "center"
    fs:ClearAllPoints()
    fs:SetWidth(0)
    fs:SetHeight(0)
    fs:SetJustifyH(GetAlignmentJustify(align))
    if align == "left" then
        PixelPoint(fs, "LEFT", anchor, "LEFT", 0, yOffset or 0)
    elseif align == "right" then
        PixelPoint(fs, "RIGHT", anchor, "RIGHT", 0, yOffset or 0)
    else
        PixelPoint(fs, "CENTER", anchor, "CENTER", 0, yOffset or 0)
    end
end

local function GetFriendlyHealthAnchorYOffset(plate)
    local offset = FRIENDLY_PLATE_Y_OFFSET
    if plate and plate.guild and plate.guild.IsShown and plate.guild:IsShown() then
        offset = offset - (GetFriendlyGuildTextSize() + 6)
    elseif plate and plate.description and plate.description.IsShown and plate.description:IsShown() then
        offset = offset - (GetFriendlyNPCDescriptionTextSize() + 6)
    end
    return offset
end

local function ApplyFriendlyHealthAnchor(plate)
    if not (plate and plate.health) then return end
    plate.health:ClearAllPoints()
    PixelPoint(plate.health, "CENTER", plate, "CENTER", 0, GetFriendlyHealthAnchorYOffset(plate))
end

local function ApplyFriendlyBarTextAnchors(plate)
    if not plate or not plate.health then return end
    local width = math.max(tonumber(GetFriendlyHealthBarWidth()) or 80, 80)
    local align = (plate.unit and UnitIsPlayer(plate.unit)) and GetFriendlyPlayerNameAlignment() or
        GetFriendlyNPCNameAlignment()
    if plate.name then
        plate.name:ClearAllPoints()
        PixelWidth(plate.name, width)
        plate.name:SetJustifyH(GetAlignmentJustify(align))
        if align == "left" then
            PixelPoint(plate.name, "BOTTOMLEFT", plate.health, "TOPLEFT", 0, 4)
        elseif align == "right" then
            PixelPoint(plate.name, "BOTTOMRIGHT", plate.health, "TOPRIGHT", 0, 4)
        else
            PixelPoint(plate.name, "BOTTOM", plate.health, "TOP", 0, 4)
        end
    end
    if plate.guild and plate.name then
        plate.guild:ClearAllPoints()
        PixelWidth(plate.guild, width)
        plate.guild:SetJustifyH(GetAlignmentJustify(align))
        if align == "left" then
            PixelPoint(plate.guild, "TOPLEFT", plate.name, "BOTTOMLEFT", 0, -1)
        elseif align == "right" then
            PixelPoint(plate.guild, "TOPRIGHT", plate.name, "BOTTOMRIGHT", 0, -1)
        else
            PixelPoint(plate.guild, "TOP", plate.name, "BOTTOM", 0, -1)
        end
    end
    if plate.description and plate.name then
        plate.description:ClearAllPoints()
        PixelWidth(plate.description, width)
        plate.description:SetJustifyH(GetAlignmentJustify(align))
        if align == "left" then
            PixelPoint(plate.description, "TOPLEFT", plate.name, "BOTTOMLEFT", 0, 1)
        elseif align == "right" then
            PixelPoint(plate.description, "TOPRIGHT", plate.name, "BOTTOMRIGHT", 0, 1)
        else
            PixelPoint(plate.description, "TOP", plate.name, "BOTTOM", 0, 1)
        end
    end
end

local function ApplyFriendlyNameOnlyTextAnchors(nameplate)
    if not (nameplate and nameplate.UnitFrame and nameplate.UnitFrame.name) then return end
    local nameFS = nameplate.UnitFrame.name
    local uf = nameplate.UnitFrame
    local align = GetFriendlyPlayerNameAlignment()
    nameFS:ClearAllPoints()
    -- Let the native region auto-size on both axes. A stale Blizzard height
    -- clips glyph columns while the projected plate crosses fractional pixels.
    nameFS:SetWidth(0)
    nameFS:SetHeight(0)
    nameFS:SetWordWrap(false)
    nameFS:SetMaxLines(1)
    nameFS:SetJustifyH(GetAlignmentJustify(align))
    if align == "left" then
            PixelPoint(nameFS, "LEFT", uf, "LEFT", 0, 0)
    elseif align == "right" then
            PixelPoint(nameFS, "RIGHT", uf, "RIGHT", 0, 0)
    else
        PixelPoint(nameFS, "CENTER", uf, "CENTER", 0, 0)
    end
    -- Blizzard seats the raid marker by the health bar, which is hidden here,
    -- so the marker floated far above the name: keep it just over the name.
    -- Re-applied after Blizzard's own UpdateAnchors (anchors only: Forever
    -- plate regions can't be measured).
    local raid = uf.RaidTargetFrame
    if raid then
        raid:ClearAllPoints()
        PixelPoint(raid, "BOTTOM", nameFS, "TOP", 0, 4)
        if not uf._kuiNameOnlyRaidHook and type(uf.UpdateAnchors) == "function" then
            uf._kuiNameOnlyRaidHook = true
            hooksecurefunc(uf, "UpdateAnchors", function(frame)
                local unit = frame.unit
                -- Friendly players shown as a name only (helpers looked up at
                -- run time: they are defined further down this file).
                local nameOnly = (ns.IsFriendlyUnitNameOnly and ns.IsFriendlyUnitNameOnly(unit))
                    or (not ns.IsFriendlyUnitNameOnly and ns.GetEffectiveFriendlyNameOnly
                        and ns.GetEffectiveFriendlyNameOnly(true))
                if frame.name and frame.RaidTargetFrame and type(unit) == "string" and nameOnly
                    and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
                    and not UnitCanAttack("player", unit) then
                    frame.RaidTargetFrame:ClearAllPoints()
                    PixelPoint(frame.RaidTargetFrame, "BOTTOM", frame.name, "TOP", 0, 4)
                end
            end)
        end
    end
end

local function AnchorFriendlyLevelBeforeName(level, name)
    if not (level and name) then return end
    level:ClearAllPoints()
    -- The FontString is auto-sized. Anchoring directly to its LEFT edge lets
    -- WoW resolve the dependency when the text layout changes; measuring the
    -- string width here races the renderer while the camera scale is moving.
    PixelPoint(level, "RIGHT", name, "LEFT", -4, 0)
end
local function ApplyFriendlyPlayerLevelStyle(level)
    if ns.ApplyNameplateLevelTextStyle then
        ns.ApplyNameplateLevelTextStyle(level)
        return
    end
    SetFriendlyFSFont(level, 11, "OUTLINE")
end

local function HideFriendlyPlayerLevel(nameplate)
    local level = nameplate and nameplate._kuiFriendlyPlayerLevel
    if level then
        level:SetText("")
        level:Hide()
    end
end

local function ShouldShowFriendlyPlayerLevel()
    if ns and ns.ShouldShowNameplateLevel then
        return ns.ShouldShowNameplateLevel(true)
    end
    local db = KullThranUINameplatesDB or {}
    if db.showFriendlyLevel ~= nil then return db.showFriendlyLevel == true end
    return db.showLevel == true
end

local function IsFriendlyPlayerUnit(unit)
    if not unit then return false end
    if not UnitIsPlayer(unit) then return false end
    if UnitIsUnit(unit, "player") then return false end
    return not UnitCanAttack("player", unit)
end

local friendlyPlayerPvPMarkers = {}
local PVP_CLASSIFICATION_ATLASES = {}
do
    local classifications = Enum and Enum.PvPUnitClassification
    if classifications then
        local atlasByKey = {
            FlagCarrierHorde = "nameplates-icon-flag-horde",
            FlagCarrierAlliance = "nameplates-icon-flag-alliance",
            FlagCarrierNeutral = "nameplates-icon-flag-neutral",
            CartRunnerHorde = "nameplates-icon-cart-horde",
            CartRunnerAlliance = "nameplates-icon-cart-alliance",
            AssassinHorde = "nameplates-icon-bounty-horde",
            AssassinAlliance = "nameplates-icon-bounty-alliance",
            OrbCarrierBlue = "nameplates-icon-orb-blue",
            OrbCarrierGreen = "nameplates-icon-orb-green",
            OrbCarrierOrange = "nameplates-icon-orb-orange",
            OrbCarrierPurple = "nameplates-icon-orb-purple",
        }
        for key, atlas in pairs(atlasByKey) do
            local classification = classifications[key]
            if classification ~= nil then
                PVP_CLASSIFICATION_ATLASES[classification] = atlas
            end
        end
    end
end

local function GetFriendlyPlayerPvPAtlas(unit)
    if not IsFriendlyPlayerUnit(unit) or type(UnitPvpClassification) ~= "function" then
        return nil
    end
    local ok, classification = pcall(UnitPvpClassification, unit)
    if not ok or not IsAccessible(classification) or classification == nil then
        return nil
    end
    return PVP_CLASSIFICATION_ATLASES[classification]
end

local function HideFriendlyPlayerPvPMarker(nameplate)
    local marker = nameplate and friendlyPlayerPvPMarkers[nameplate]
    if not marker then return end
    marker:UnregisterAllEvents()
    marker.unit = nil
    marker.nameplate = nil
    marker:Hide()
end

local function UpdateFriendlyPlayerPvPMarker(nameplate, unit)
    local db = KullThranUINameplatesDB or {}
    local showPlayers
    if ns.ShouldShowFriendlyNameplates then
        showPlayers = ns.ShouldShowFriendlyNameplates(true)
    else
        showPlayers = db.showFriendlyPlayers ~= false
    end
    if not ns.IsFriendlyNameOnlyForUnit(unit) or not showPlayers
        or not (nameplate and unit and IsFriendlyPlayerUnit(unit)) then
        HideFriendlyPlayerPvPMarker(nameplate)
        return
    end

    local uf = nameplate.UnitFrame
    local name = uf and uf.name
    if not name then
        HideFriendlyPlayerPvPMarker(nameplate)
        return
    end

    local marker = friendlyPlayerPvPMarkers[nameplate]
    if not marker then
        marker = CreateFrame("Frame", nil, uf)
        marker:SetSize(24, 24)
        marker.icon = marker:CreateTexture(nil, "OVERLAY")
        marker.icon:SetAllPoints()
        marker:SetScript("OnEvent", function(self, _, changedUnit)
            if not changedUnit or changedUnit == self.unit then
                UpdateFriendlyPlayerPvPMarker(self.nameplate, self.unit)
            end
        end)
        friendlyPlayerPvPMarkers[nameplate] = marker
    end

    marker:SetParent(uf)
    marker:SetFrameLevel(uf:GetFrameLevel() + 10)
    marker:ClearAllPoints()
    marker:SetPoint("LEFT", name, "RIGHT", 4, 0)
    marker.unit = unit
    marker.nameplate = nameplate
    marker:UnregisterAllEvents()
    pcall(marker.RegisterUnitEvent, marker, "UNIT_CLASSIFICATION_CHANGED", unit)

    local atlas = GetFriendlyPlayerPvPAtlas(unit)
    if not atlas then
        marker:Hide()
        return
    end
    local atlasSet = pcall(marker.icon.SetAtlas, marker.icon, atlas, false)
    marker:SetShown(atlasSet)
end

local function UpdateFriendlyPlayerLevel(nameplate, unit)
    local db = KullThranUINameplatesDB or {}
    if not nameplate or not unit or not ns.IsFriendlyNameOnlyForUnit(unit)
        or db.showFriendlyPlayers == false or not ShouldShowFriendlyPlayerLevel()
        or not IsFriendlyPlayerUnit(unit) then
        HideFriendlyPlayerLevel(nameplate)
        return
    end

    local uf = nameplate.UnitFrame
    local name = uf and uf.name
    if not name then
        HideFriendlyPlayerLevel(nameplate)
        return
    end

    local level = nameplate._kuiFriendlyPlayerLevel
    if not level then
        level = uf:CreateFontString(nil, "OVERLAY")
        ApplyFriendlyPlayerLevelStyle(level)
        level:SetJustifyH("RIGHT")
        level:SetWordWrap(false)
        level:SetMaxLines(1)
        nameplate._kuiFriendlyPlayerLevel = level
    end

    local text = ns.GetNameplateLevelText and ns.GetNameplateLevelText(unit)
    if not text then
        level:SetText("")
        level:Hide()
        return
    end

    ApplyFriendlyPlayerLevelStyle(level)
    level:SetText(text)
    PixelWidth(level, math.max(24, (tonumber(KullThranUINameplatesDB and KullThranUINameplatesDB.levelFontSize) or 11) + 10))
    PixelHeight(level, math.max(12, (tonumber(KullThranUINameplatesDB and KullThranUINameplatesDB.levelFontSize) or 11) + 4))
    AnchorFriendlyLevelBeforeName(level, name, GetFriendlyPlayerNameAlignment())
    level:Show()
end

ns.UpdateFriendlyPlayerLevel = UpdateFriendlyPlayerLevel

local function RestoreFriendlyPlayerNameText(nameplate, unit)
    if not (nameplate and unit) then return end
    local uf = nameplate.UnitFrame
    local nameFS = uf and uf.name
    if not nameFS then return end

    if uf:GetParent() ~= nameplate then
        uf:SetParent(nameplate)
    end
    uf:SetAlpha(1)
    uf:Show()

    if nameFS.GetParent and nameFS:GetParent() ~= uf then
        nameFS:SetParent(uf)
    end
    -- Blizzard-owned name regions can expose a protected alpha in PvP.
    -- Writing the intended constant is safe; reading/comparing it is not.
    nameFS:SetAlpha(1)
    if nameFS.Show then
        nameFS:Show()
    end

    -- Blizzard owns and updates this FontString. Reassigning UnitName here is
    -- unnecessary and can propagate a protected identity value.

    ApplyFontToNameText(nameFS)
    ApplyFriendlyNameOnlyTextAnchors(nameplate)
    UpdateFriendlyPlayerPvPMarker(nameplate, unit)
end

local function EnforceFriendlyPlayerNameOnly(nameplate, unit)
    if not (nameplate and unit and IsNameOnlyMode(unit)) then return end
    local uf = nameplate.UnitFrame
    if not uf then return end

    -- A recycled Blizzard unit frame may have its health widgets shown again
    -- in battlegrounds. Keep the native name, but suppress only bar widgets.
    local widgets = {
        uf.HealthBarsContainer,
        uf.healthBar,
        uf.PowerBar,
        uf.powerBar,
        uf.CastBarsContainer,
    }
    for index = 1, #widgets do
        local widget = widgets[index]
        if widget then
            pcall(widget.SetAlpha, widget, 0)
            pcall(widget.Hide, widget)
        end
    end
end
ns.EnforceFriendlyPlayerNameOnly = EnforceFriendlyPlayerNameOnly

local function ShouldShowFriendlyGuild()
    local db = KullThranUINameplatesDB
    if db and db.friendlyShowGuild == false then return false end
    return true
end

local function FriendlyNameOnlyValue(isPlayer)
    if ns.GetEffectiveFriendlyNameOnly then
        return ns.GetEffectiveFriendlyNameOnly(isPlayer)
    end
    local db = KullThranUINameplatesDB or {}
    local key = isPlayer and "friendlyPlayerNameOnly" or "friendlyNPCNameOnly"
    if db[key] ~= nil then return db[key] ~= false end
    -- Profiles created before the split used one setting for both unit types.
    return db.friendlyNameOnly ~= false
end

local function IsFriendlyNameOnlyForUnit(unit)
    if not unit or UnitIsUnit(unit, "player") or UnitCanAttack("player", unit) then
        return false
    end
    return FriendlyNameOnlyValue(UnitIsPlayer(unit))
end
ns.IsFriendlyNameOnlyForUnit = IsFriendlyNameOnlyForUnit

local function IsFriendlyBarForUnit(unit)
    if not unit or UnitIsUnit(unit, "player") or UnitCanAttack("player", unit) then
        return false
    end
    local db = KullThranUINameplatesDB or {}
    local isPlayer = UnitIsPlayer(unit)
    local shown
    if ns.ShouldShowFriendlyNameplates then
        shown = ns.ShouldShowFriendlyNameplates(isPlayer)
    else
        shown = isPlayer and db.showFriendlyPlayers ~= false or db.showFriendlyNPCs == true
    end
    return shown and not FriendlyNameOnlyValue(isPlayer)
end
ns.IsFriendlyBarForUnit = IsFriendlyBarForUnit

local function IsFriendlyEnabled()
    local db = KullThranUINameplatesDB
    if not db then return false end
    local showPlayers
    local showNPCs
    if ns.ShouldShowFriendlyNameplates then
        showPlayers = ns.ShouldShowFriendlyNameplates(true)
        showNPCs = ns.ShouldShowFriendlyNameplates(false)
    else
        showPlayers = db.showFriendlyPlayers ~= false
        showNPCs = db.showFriendlyNPCs == true
    end
    local playerBars = showPlayers and not FriendlyNameOnlyValue(true)
    local npcBars = showNPCs and not FriendlyNameOnlyValue(false)
    return playerBars or npcBars
end

IsNameOnlyMode = function(unit)
    if unit then return IsFriendlyNameOnlyForUnit(unit) end
    local db = KullThranUINameplatesDB
    if not db then return true end
    local showPlayers
    local showNPCs
    if ns.ShouldShowFriendlyNameplates then
        showPlayers = ns.ShouldShowFriendlyNameplates(true)
        showNPCs = ns.ShouldShowFriendlyNameplates(false)
    else
        showPlayers = db.showFriendlyPlayers ~= false
        showNPCs = db.showFriendlyNPCs == true
    end
    return (showPlayers and FriendlyNameOnlyValue(true))
        or (showNPCs and FriendlyNameOnlyValue(false))
end
local function IsFriendlyNPCEnabled()
    return KullThranUINameplatesDB and (KullThranUINameplatesDB.showFriendlyNPCs == true)
end

-- Bar colour for friendly NPCs without a class colour (pure green).
local FRIENDLY_NPC_BAR_RGB = { 0, 1, 0 }

-- Name font handling. The shared SystemFont_NamePlate* font objects are
-- never touched here: other Blizzard frames (the damage meter rows among
-- them) inherit them, and writing to them from addon code would taint the
-- secret combat names those rows display. Each name FontString is styled
-- individually instead; that also keeps the text crisp while plates scale.
local styledNameTexts = {} -- name FontString -> true once styled

ApplyFontToNameText = function(nameText)
    if not nameText or not nameText.SetFont then return end
    local font = (ns and ns.GetFont and ns.GetFont()) or "Fonts\\FRIZQT__.TTF"
    local outline = (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE"
    nameText._ktApplyingFont = true
    nameText:SetFont(font, GetFriendlyPlayerNameTextSize(), outline)
    if KT and KT.EnableTextFontFallback then
        KT:EnableTextFontFallback(nameText, font)
    end
    if outline == "" and (not ns or not ns.GetNPUseShadow or ns.GetNPUseShadow()) then
        nameText:SetShadowOffset(1, -1)
        nameText:SetShadowColor(0, 0, 0, 1)
    else
        nameText:SetShadowOffset(0, 0)
        nameText:SetShadowColor(0, 0, 0, 0)
    end
    nameText._ktApplyingFont = nil
    styledNameTexts[nameText] = true
end

local function ApplyFontToNameplate(nameplate)
    if not nameplate then return end
    local uf = nameplate.UnitFrame
    local nameText = uf and uf.name
    if not nameText then return end
    ApplyFontToNameText(nameText)
    ApplyFriendlyNameOnlyTextAnchors(nameplate)
end
ns.ApplyFontToNameplate = ApplyFontToNameplate

local function RestoreFontOnNameplate(nameplate)
    -- Cadena de acceso directa: si cualquier eslabón falta, no hay nada que restaurar
    local nameText = nameplate and nameplate.UnitFrame and nameplate.UnitFrame.name
    if not nameText then return end
    styledNameTexts[nameText] = nil
end

-- Exposed so the options panel can trigger a refresh after font changes
function ns.RefreshFriendlyFontOverride()
    -- Recopilar placas elegibles antes de aplicar; evita re-evaluar dentro del bucle
    local plates = GetAccessibleNamePlates(true)
    local n = #plates
    for idx = 1, n do
        local np = plates[idx]
        local tok = np.namePlateUnitToken
        if tok and IsFriendlyNameOnlyForUnit(tok) then
            ApplyFontToNameplate(np)
        end
    end
end

-- Name-only presentation: the whole friendly name block (name, level, guild,
-- occupation, PvP icon) lives in one addon-owned overlay frame, so every
-- region shares a single layout pass when the projected plate rescales.
local npcOverlays = {}    -- nameplate -> stable friendly overlay
local npcOverlayPool = {} -- recycled overlay frames

local NPC_OVERLAY_FONT_SIZE = 12
local NPC_OVERLAY_Y_OFFSET = 5

local function GetNPCNameColor(unit)
    local reaction = RawUnitAPI.UnitReaction and RawUnitAPI.UnitReaction(unit, "player")
    if not IsAccessible(reaction) then reaction = nil end
    if reaction and reaction == 4 then
        return 0.9, 0.7, 0.0
    end
    return GetFriendlyNPCNameColor()
end

local function StyleStableOverlayFont(fs, size)
    if not fs then return end
    SetFriendlyFSFont(fs, size, (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    -- Smooth scaling is only meaningful for SLUG fonts. The KUI font
    -- does not use that flag, so forcing it here makes moving text softer.
    if fs.SetSmoothScaling then
        fs:SetSmoothScaling(false)
    end
end

local function AnchorStableSecondLine(line, name, alignment)
    if not (line and name) then return end
    line:ClearAllPoints()
    line:SetWidth(0)
    line:SetHeight(0)
    line:SetJustifyH(GetAlignmentJustify(alignment))
    if alignment == "left" then
        PixelPoint(line, "TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    elseif alignment == "right" then
        PixelPoint(line, "TOPRIGHT", name, "BOTTOMRIGHT", 0, -1)
    else
        PixelPoint(line, "TOP", name, "BOTTOM", 0, -1)
    end
end

-- Soft targeting (switched on by addons such as ForeverLootSparkles) puts the
-- interact target's cursor icon, a quest "!" or "?", on Blizzard's plate just
-- above its top edge, which is where the NPC's name sits. It goes above the
-- name instead; Blizzard's own place comes back when the overlay lets go.
local function PlaceSoftTargetIcon(overlay, aboveName)
    local uf = overlay.nameplate and overlay.nameplate.UnitFrame
    local soft = uf and uf.SoftTargetFrame
    if not soft or (soft.IsForbidden and soft:IsForbidden()) then return end
    pcall(soft.ClearAllPoints, soft)
    if aboveName then
        pcall(soft.SetPoint, soft, "BOTTOM", overlay.name, "TOP", 0, 2)
    else
        pcall(soft.SetPoint, soft, "BOTTOM", uf, "TOP", 0, -8) -- Blizzard_NamePlates.xml
    end
end

local function ApplyStableOverlayLayout(overlay, includeRoot)
    if not (overlay and overlay.name and overlay.unit and overlay.nameplate) then return end
    local isPlayer = UnitIsPlayer(overlay.unit)
    local alignment = isPlayer and GetFriendlyPlayerNameAlignment() or GetFriendlyNPCNameAlignment()

    if includeRoot then
        local db = KullThranUINameplatesDB or {}
        local yOffset = isPlayer and (tonumber(db.friendlyNameOnlyYOffset) or 0) or -NPC_OVERLAY_Y_OFFSET
        overlay:ClearAllPoints()
        overlay:SetPoint("CENTER", overlay.nameplate, "CENTER", 0, yOffset)
        overlay:SetSize(10, 10)
    end

    ApplyAlignedTextLayout(overlay.name, overlay, 0, alignment)
    PlaceSoftTargetIcon(overlay, not isPlayer)

    if overlay.level then
        overlay.level:ClearAllPoints()
        PixelPoint(overlay.level, "RIGHT", overlay.name, "LEFT", -4, 0)
    end
    if overlay.pvpFrame then
        overlay.pvpFrame:ClearAllPoints()
        PixelPoint(overlay.pvpFrame, "LEFT", overlay.name, "RIGHT", 4, 0)
    end
    if overlay.raidFrame then
        overlay.raidFrame:ClearAllPoints()
        PixelPoint(overlay.raidFrame, "BOTTOM", overlay.name, "TOP", 0, 4)
    end

    AnchorStableSecondLine(overlay.guild, overlay.name, alignment)
    AnchorStableSecondLine(overlay.description, overlay.name, alignment)
end

local function ScheduleStableOverlayLayout(overlay)
    if not overlay then return end
    overlay._ktLayoutFrames = 0
    overlay:SetScript("OnUpdate", function(self)
        self._ktLayoutFrames = (self._ktLayoutFrames or 0) + 1
        if self._ktLayoutFrames < 2 then return end
        self._ktLayoutFrames = nil
        self:SetScript("OnUpdate", nil)
        -- Wait two render frames after OnSizeChanged before
        -- asking PixelUtil to resolve anchors at the new projected scale.
        ApplyStableOverlayLayout(self, false)
    end)
end

local UpdateStableOverlayContent

local function AcquireOverlay()
    local overlay = table.remove(npcOverlayPool)
    if overlay then return overlay end

    overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetSize(10, 10)
    overlay:SetFlattensRenderLayers(true)
    if overlay.SetCollapsesLayout then
        overlay:SetCollapsesLayout(true)
    end
    if overlay.SetIgnoreParentScale then
        overlay:SetIgnoreParentScale(false)
    end

    overlay.name = overlay:CreateFontString(nil, "OVERLAY")
    overlay.name:SetWordWrap(false)
    overlay.name:SetNonSpaceWrap(false)
    overlay.name:SetMaxLines(1)

    overlay.level = overlay:CreateFontString(nil, "OVERLAY")
    overlay.level:SetWordWrap(false)
    overlay.level:SetMaxLines(1)
    overlay.level:Hide()

    overlay.guild = overlay:CreateFontString(nil, "OVERLAY")
    overlay.guild:SetWordWrap(false)
    overlay.guild:SetNonSpaceWrap(false)
    overlay.guild:SetMaxLines(1)
    overlay.guild:Hide()

    overlay.description = overlay:CreateFontString(nil, "OVERLAY")
    overlay.description:SetWordWrap(false)
    overlay.description:SetNonSpaceWrap(false)
    overlay.description:SetMaxLines(1)
    overlay.description:Hide()

    -- Every pooled FontString receives a font before any SetText call. This
    -- also protects NPC-only/player-only reuse paths from "Font not set".
    StyleStableOverlayFont(overlay.name, NPC_OVERLAY_FONT_SIZE)
    StyleStableOverlayFont(overlay.level, 11)
    StyleStableOverlayFont(overlay.guild, GetFriendlyGuildTextSize())
    StyleStableOverlayFont(overlay.description, GetFriendlyNPCDescriptionTextSize())
    overlay.pvpFrame = CreateFrame("Frame", nil, overlay)
    overlay.pvpFrame:SetSize(20, 20)
    overlay.pvpFrame:Hide()
    overlay.pvp = overlay.pvpFrame:CreateTexture(nil, "OVERLAY")
    overlay.pvp:SetAllPoints()
    overlay.raidFrame = CreateFrame("Frame", nil, overlay)
    overlay.raidFrame:SetSize(22, 22)
    overlay.raidFrame:Hide()
    overlay.raid = overlay.raidFrame:CreateTexture(nil, "ARTWORK")
    overlay.raid:SetAllPoints()
    overlay.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

    overlay:SetScript("OnSizeChanged", function(self)
        if not self._ktApplyingLayout then
            ScheduleStableOverlayLayout(self)
        end
    end)
    overlay:SetScript("OnEvent", function(self, _, changedUnit)
        if not changedUnit or changedUnit == self.unit then
            UpdateStableOverlayContent(self)
            ApplyStableOverlayLayout(self, false)
        end
    end)
    return overlay
end

UpdateStableOverlayContent = function(overlay)
    local unit = overlay and overlay.unit
    if not unit then return end

    local isPlayer = UnitIsPlayer(unit)
    local db = KullThranUINameplatesDB or {}
    local nameSize = isPlayer and GetFriendlyPlayerNameTextSize()
        or (GetFriendlyNPCNameTextSize() or NPC_OVERLAY_FONT_SIZE)

    StyleStableOverlayFont(overlay.name, nameSize)
    overlay.name:SetText(UnitName(unit) or "")

    if isPlayer then
        local classColor
        if db.classColorFriendly ~= false then
            local _, classToken = UnitClass(unit)
            classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
        end
        if classColor then
            overlay.name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
        else
            overlay.name:SetTextColor(GetFriendlyPlayerNameColor())
        end

        local levelText = ShouldShowFriendlyPlayerLevel() and ns.GetNameplateLevelText
            and ns.GetNameplateLevelText(unit) or nil
        if levelText then
            ApplyFriendlyPlayerLevelStyle(overlay.level)
            overlay.level:SetText(levelText)
            overlay.level:Show()
        else
            overlay.level:SetText("")
            overlay.level:Hide()
        end

        local guildName = ShouldShowFriendlyGuild() and GetGuildInfo and GetGuildInfo(unit) or nil
        if guildName and guildName ~= "" then
            StyleStableOverlayFont(overlay.guild, GetFriendlyGuildTextSize())
            local gr, gg, gb = GetFriendlyGuildColor()
            overlay.guild:SetTextColor(gr, gg, gb, 1)
            overlay.guild:SetText("<" .. guildName .. ">")
            overlay.guild:Show()
        else
            overlay.guild:SetText("")
            overlay.guild:Hide()
        end

        overlay.description:SetText("")
        overlay.description:Hide()

        local atlas = GetFriendlyPlayerPvPAtlas(unit)
        if atlas and overlay.pvp and overlay.pvp.SetAtlas then
            local atlasSet = pcall(overlay.pvp.SetAtlas, overlay.pvp, atlas, false)
            overlay.pvpFrame:SetShown(atlasSet)
        else
            overlay.pvpFrame:Hide()
        end
    else
        local r, g, b = GetNPCNameColor(unit)
        overlay.name:SetTextColor(r, g, b, 1)
        overlay.level:SetText("")
        overlay.level:Hide()
        overlay.guild:SetText("")
        overlay.guild:Hide()
        overlay.pvpFrame:Hide()

        local descriptionText = GetFriendlyNPCDescription(unit)
        StyleStableOverlayFont(overlay.description, GetFriendlyNPCDescriptionTextSize())
        local dr, dg, dbColor = GetFriendlyNPCDescriptionColor()
        overlay.description:SetTextColor(dr, dg, dbColor, 1)
        overlay.description:SetText(descriptionText or "")
        overlay.description:SetShown(descriptionText ~= nil and descriptionText ~= "")
    end

    -- The overlay replaces Blizzard's name-only plate, whose raid marker sits
    -- above the name; the overlay draws it in the same place.
    local markerIndex = ns.FriendlyRaidMarker(unit)
    if type(markerIndex) ~= "nil" and ns.GetRaidMarkerPos() ~= "none"
        and ns.SetFriendlyRaidMarkerTexture(overlay.raid, markerIndex) then
        local size = ns.GetRaidMarkerSize()
        overlay.raidFrame:SetSize(size, size)
        overlay.raidFrame:Show()
    else
        overlay.raidFrame:Hide()
    end
end

local function RegisterOverlayUnitEvents(overlay, unit)
    overlay:UnregisterAllEvents()
    pcall(overlay.RegisterUnitEvent, overlay, "UNIT_NAME_UPDATE", unit)
    pcall(overlay.RegisterUnitEvent, overlay, "UNIT_GUILD_UPDATE", unit)
    pcall(overlay.RegisterUnitEvent, overlay, "UNIT_CLASSIFICATION_CHANGED", unit)
    pcall(overlay.RegisterUnitEvent, overlay, "UNIT_LEVEL", unit)
    -- No unit argument: the handler refreshes on a nil unit.
    overlay:RegisterEvent("RAID_TARGET_UPDATE")
end

local function ShowNPCOverlay(nameplate, unit)
    if not (nameplate and unit) then return end
    local existing = npcOverlays[nameplate]
    if existing then
        -- A recycled nameplate keeps its overlay: follow the new unit's events.
        if existing.unit ~= unit then RegisterOverlayUnitEvents(existing, unit) end
        existing.unit = unit
        existing.nameplate = nameplate
        UpdateStableOverlayContent(existing)
        ApplyStableOverlayLayout(existing, true)
        return
    end

    local overlay = AcquireOverlay()
    npcOverlays[nameplate] = overlay
    overlay.unit = unit
    overlay.nameplate = nameplate
    overlay:SetParent(nameplate)
    overlay:SetFrameLevel(nameplate:GetFrameLevel() + 5)
    overlay:Show()

    RegisterOverlayUnitEvents(overlay, unit)

    UpdateStableOverlayContent(overlay)
    overlay._ktApplyingLayout = true
    ApplyStableOverlayLayout(overlay, true)
    overlay._ktApplyingLayout = nil

    if not nameplate._ktStableOverlaySizeHook then
        nameplate._ktStableOverlaySizeHook = true
        nameplate:HookScript("OnSizeChanged", function(self)
            local current = npcOverlays[self]
            if current then
                ScheduleStableOverlayLayout(current)
            end
        end)
    end

    if C_Timer and C_Timer.After then
        for _, delay in ipairs({ 0, 0.1, 0.5 }) do
            C_Timer.After(delay, function()
                local current = npcOverlays[nameplate]
                if current and current.unit == unit then
                    UpdateStableOverlayContent(current)
                    ApplyStableOverlayLayout(current, false)
                end
            end)
        end
    end
end

local function HideNPCOverlay(nameplate)
    local overlay = npcOverlays[nameplate]
    if not overlay then return end
    npcOverlays[nameplate] = nil
    if overlay.nameplate then PlaceSoftTargetIcon(overlay, false) end
    overlay:UnregisterAllEvents()
    overlay:SetScript("OnUpdate", nil)
    overlay._ktLayoutFrames = nil
    overlay.unit = nil
    overlay.nameplate = nil
    overlay.name:SetText("")
    overlay.level:SetText("")
    overlay.level:Hide()
    overlay.guild:SetText("")
    overlay.guild:Hide()
    overlay.description:SetText("")
    overlay.description:Hide()
    overlay.pvpFrame:Hide()
    overlay.raidFrame:Hide()
    overlay:ClearAllPoints()
    overlay:SetParent(UIParent)
    overlay:Hide()
    npcOverlayPool[#npcOverlayPool + 1] = overlay
end

-- /knpdebug [unit]: prints size, scale, anchor and font data of the Blizzard
-- frame, the KUI overlay/bar and other nameplate addons on one plate, so
-- their layouts can be compared side by side.
local function DebugValue(frame, methodName)
    local fn = frame and frame[methodName]
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, frame)
    if not ok or not IsAccessible(a) then return nil end
    return a, b, c, d, e
end

local function DebugNumber(value)
    return type(value) == "number" and string.format("%.4f", value) or "-"
end

local function DebugFrameName(frame)
    if not frame then return "nil" end
    local name = DebugValue(frame, "GetDebugName") or DebugValue(frame, "GetName")
    return type(name) == "string" and name or tostring(frame)
end

local function PrintLayoutFrame(label, frame, fontString)
    if not frame then
        print("|cff66ccffKNP debug|r " .. string.format(Loc("%s: unavailable"), tostring(label)))
        return
    end

    local width, height = DebugValue(frame, "GetSize")
    local scale = DebugValue(frame, "GetScale")
    local effectiveScale = DebugValue(frame, "GetEffectiveScale")
    local parent = DebugValue(frame, "GetParent")
    local point, relativeTo, relativePoint, x, y = DebugValue(frame, "GetPoint")
    local flatten = DebugValue(frame, "GetFlattensRenderLayers")
    local ignoreScale = DebugValue(frame, "GetIgnoreParentScale")

    print(string.format(
        "|cff66ccffKNP debug|r %s parent=%s size=%sx%s scale=%s effective=%s point=%s/%s x=%s y=%s flatten=%s ignoreParentScale=%s",
        label,
        DebugFrameName(parent),
        DebugNumber(width), DebugNumber(height),
        DebugNumber(scale), DebugNumber(effectiveScale),
        tostring(point or "-"), tostring(relativePoint or "-"),
        DebugNumber(x), DebugNumber(y),
        tostring(flatten), tostring(ignoreScale)
    ))

    if fontString then
        local font, fontSize, flags = DebugValue(fontString, "GetFont")
        local textScale = DebugValue(fontString, "GetTextScale")
        local fontScale = DebugValue(fontString, "GetScale")
        local stringWidth = DebugValue(fontString, "GetStringWidth")
        print(string.format(
            "|cff66ccffKNP debug|r %s.font file=%s size=%s flags=%s scale=%s textScale=%s stringWidth=%s parent=%s",
            label,
            tostring(font or "-"), DebugNumber(fontSize), tostring(flags or ""),
            DebugNumber(fontScale), DebugNumber(textScale), DebugNumber(stringWidth),
            DebugFrameName(DebugValue(fontString, "GetParent"))
        ))
    end
end

local function FindPlatynatorDisplay(nameplate)
    if not nameplate or not nameplate.GetChildren then return nil, nil end
    local children = { nameplate:GetChildren() }
    for _, child in ipairs(children) do
        if type(child) == "table" and type(child.ApplyPixelPerfectSizing) == "function"
            and type(child.widgets) == "table" then
            local text
            for _, widget in ipairs(child.widgets) do
                if widget and widget.text and widget:IsShown() then
                    text = widget.text
                    break
                end
            end
            return child, text
        end
    end
    return nil, nil
end

local function FindDebugNameplate(requestedUnit)
    if requestedUnit and requestedUnit ~= "" then
        local requested = C_NamePlate.GetNamePlateForUnit(requestedUnit)
        if requested then return requestedUnit, requested end
    end

    for _, unit in ipairs({ "target", "mouseover" }) do
        local plate = UnitExists(unit) and C_NamePlate.GetNamePlateForUnit(unit)
        if plate then return unit, plate end
    end

    for _, plate in ipairs(GetAccessibleNamePlates()) do
        local unit = plate.namePlateUnitToken
        if unit and not UnitCanAttack("player", unit) and not UnitIsUnit(unit, "player") then
            return unit, plate
        end
    end
end

local function DumpFriendlyLayout(requestedUnit)
    local unit, nameplate = FindDebugNameplate(requestedUnit)
    if not nameplate then
        print("|cff66ccffKNP debug|r " .. Loc("Target or mouse over a visible nameplate first."))
        return
    end

    print(string.format("|cff66ccffKNP debug|r unit=%s name=%s plate=%s",
        tostring(unit), tostring(UnitName(unit) or "<secret>"), DebugFrameName(nameplate)))
    PrintLayoutFrame("Blizzard", nameplate.UnitFrame,
        nameplate.UnitFrame and nameplate.UnitFrame.name)

    local kuiOverlay = npcOverlays[nameplate]
    PrintLayoutFrame("KUI-overlay", kuiOverlay, kuiOverlay and kuiOverlay.name)

    local kuiBar = ns.friendlyPlatesByNameplate and ns.friendlyPlatesByNameplate[nameplate]
    PrintLayoutFrame("KUI-bar", kuiBar, kuiBar and kuiBar.name)

    local platerFrame = nameplate.unitFrame
    local platerFont = platerFrame and (platerFrame.ActorNameSpecial or platerFrame.unitName)
    PrintLayoutFrame("Plater", platerFrame, platerFont)

    local platynatorFrame, platynatorFont = FindPlatynatorDisplay(nameplate)
    PrintLayoutFrame("Platynator", platynatorFrame, platynatorFont)
end

local function HandleNameplateDebugSlash(message)
    local requested = type(message) == "string" and message:match("^%s*(.-)%s*$") or nil
    if requested == "" then requested = nil end
    DumpFriendlyLayout(requested)
end
SLASH_KULLTHRANNAMEPLATEDEBUG1 = "/knpdebug"
SlashCmdList.KULLTHRANNAMEPLATEDEBUG = HandleNameplateDebugSlash

-- Blizzard's friendly UnitFrame is parked under this never-shown frame while
-- KUI draws the plate; it stays fully functional so it can be handed back.
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

-- unit token -> { frame = Blizzard UnitFrame, home = its nameplate }
local suppressedUFs = {}
local originalFriendlyBuffsCVar
local originalFriendlyDebuffsCVar

local function SetFriendlyAuraCVars(disable)
    if not GetCVar then return end

    if disable then
        if originalFriendlyBuffsCVar == nil then
            originalFriendlyBuffsCVar = GetCVar("nameplateShowFriendlyBuffs")
        end
        if originalFriendlyDebuffsCVar == nil then
            originalFriendlyDebuffsCVar = GetCVar("nameplateShowDebuffsOnFriendly")
        end
        ns.QueueNameplateCVar("nameplateShowFriendlyBuffs", 0)
        ns.QueueNameplateCVar("nameplateShowDebuffsOnFriendly", 0)
        return
    end

    if originalFriendlyBuffsCVar ~= nil then
        ns.QueueNameplateCVar("nameplateShowFriendlyBuffs", originalFriendlyBuffsCVar)
        originalFriendlyBuffsCVar = nil
    end
    if originalFriendlyDebuffsCVar ~= nil then
        ns.QueueNameplateCVar("nameplateShowDebuffsOnFriendly", originalFriendlyDebuffsCVar)
        originalFriendlyDebuffsCVar = nil
    end
end

local EnsureUFAlphaHook
do
    -- UnitFrames that already carry the permanent alpha hook (hooks cannot
    -- be removed, so each frame is hooked at most once).
    local hooked = {}
    -- Frames whose alpha the hook is resetting right now (re-entrancy guard).
    local resetting = {}

    -- Runs after every SetAlpha on a hooked UnitFrame: while its unit is
    -- suppressed, Blizzard fading it back in is immediately undone.
    local function KeepSuppressedUFTransparent(frame)
        if resetting[frame] or frame:IsForbidden() then return end
        resetting[frame] = true
        local owner = frame.unit or (frame.GetUnit and frame:GetUnit())
        if owner and suppressedUFs[owner] then
            frame:SetAlpha(0)
        end
        resetting[frame] = nil
    end

    EnsureUFAlphaHook = function(uf)
        if hooked[uf] then return end
        hooked[uf] = true
        hooksecurefunc(uf, "SetAlpha", KeepSuppressedUFTransparent)
    end
end

-- Hides Blizzard's UnitFrame by parking it under hiddenFrame. Its events
-- stay registered so the frame is up to date when it is restored.
local function SuppressBlizzardUF(unit, nameplate)
    if suppressedUFs[unit] then return end
    local uf = nameplate and nameplate.UnitFrame
    if not uf then return end
    suppressedUFs[unit] = { frame = uf, home = nameplate }
    uf:SetAlpha(0)
    uf:SetParent(hiddenFrame)
    EnsureUFAlphaHook(uf)
end

local function RestoreBlizzardUF(unit)
    local record = suppressedUFs[unit]
    if not record then return end
    -- Forget the unit first so the alpha hook lets SetAlpha(1) through.
    suppressedUFs[unit] = nil
    local uf = record.frame
    uf:SetParent(record.home)
    uf:Show()
    uf:SetAlpha(1)
end

-- Nameplates whose Blizzard UnitFrame was parked for the name-only overlay.
local nameOnlyNPCSuppressed = {} -- nameplate -> true

local function SuppressNPCNameplate(nameplate, unit)
    -- Already done for this unit. A nameplate recycled for another unit must
    -- not keep showing the previous unit's name.
    local current = npcOverlays[nameplate]
    if nameOnlyNPCSuppressed[nameplate] and current and current.unit == unit then return end
    -- Mostrar primero el overlay propio para que el jugador nunca vea un hueco
    ShowNPCOverlay(nameplate, unit)
    SuppressBlizzardUF(unit, nameplate)
    nameOnlyNPCSuppressed[nameplate] = true
end

local function RestoreNPCNameplate(nameplate, unit)
    if not nameOnlyNPCSuppressed[nameplate] then return end
    -- Restaurar el UF de Blizzard antes de ocultar el overlay;
    -- así el frame nativo ya está visible cuando quitamos el nuestro
    if unit then RestoreBlizzardUF(unit) end
    HideNPCOverlay(nameplate)
    nameOnlyNPCSuppressed[nameplate] = nil
end

-- Drops every name-only friendly element (overlay name/guild/level/PvP marker
-- and the hidden Blizzard UnitFrame) for a unit that just became attackable
-- (duel) so the hostile bar plate is the only look left on the nameplate.
function ns.RemoveFriendlyNameOnlyPresentation(unit, nameplate)
    nameplate = nameplate or (unit and C_NamePlate.GetNamePlateForUnit(unit))
    if nameplate then
        if nameOnlyNPCSuppressed[nameplate] then
            RestoreNPCNameplate(nameplate, unit)
        else
            HideNPCOverlay(nameplate)
        end
        HideFriendlyPlayerLevel(nameplate)
        HideFriendlyPlayerPvPMarker(nameplate)
    end
    if unit then RestoreBlizzardUF(unit) end
end

-- NamePlateDriverFrame runs these inside Blizzard's own plate setup, before
-- NAME_PLATE_UNIT_ADDED reaches any addon, so the native UnitFrame of a
-- friendly unit is hidden before it can be drawn even once.
local function OnDriverPlateAdded(_, unit)
    if not unit or unit == "preview" then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if ns.IsEnemyNameplateUnit and ns.IsEnemyNameplateUnit(unit, nameplate) then return end
    if UnitIsUnit(unit, "player") or not nameplate then return end

    -- Bar units only need the native frame gone; name-only units also get
    -- the overlay. Players and NPCs pick their mode independently.
    if IsFriendlyBarForUnit(unit) then
        SuppressBlizzardUF(unit, nameplate)
    elseif IsNameOnlyMode(unit) then
        SuppressNPCNameplate(nameplate, unit)
    end
end

local function FindOverlayPlateForUnit(unit)
    for plate, overlay in pairs(npcOverlays) do
        if overlay.unit == unit then return plate end
    end
    return nil
end

local function OnDriverPlateRemoved(_, unit)
    -- Only real nameplate tokens; the settings preview also lands here.
    if not unit or not unit:find("^nameplate") then return end
    -- Restricted plates may not resolve any more; fall back to the overlay
    -- that still shows this unit.
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit) or FindOverlayPlateForUnit(unit)
    if nameplate then
        HideNPCOverlay(nameplate)
        nameOnlyNPCSuppressed[nameplate] = nil
        HideFriendlyPlayerLevel(nameplate)
        HideFriendlyPlayerPvPMarker(nameplate)
    end
    RestoreBlizzardUF(unit)
end

hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", OnDriverPlateAdded)
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", OnDriverPlateRemoved)

local function NameplateOutline()
    return (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE"
end

-- Applies an RGB triple (as returned by the colour getters) at full alpha.
local function TintOpaque(fs, r, g, b)
    fs:SetTextColor(r, g, b, 1)
end

-- Pool of custom friendly bars. The builders below run once per pooled
-- frame and are scoped to this block.
local friendlyFrameCache
do
    local function BuildBarRoot(plate)
        -- Fixed-size root parented to the projected nameplate; its render layers
        -- are flattened so the bar composes as a single unit.
        plate:SetSize(10, 10)
        plate:SetFlattensRenderLayers(true)
        if plate.SetCollapsesLayout then
            plate:SetCollapsesLayout(true)
        end
        if plate.SetIgnoreParentScale then
            plate:SetIgnoreParentScale(false)
        end
    end

    -- One-pixel black frame around the health bar: each edge is pinned to two
    -- corners of the border frame and sized on its free axis.
    local BAR_BORDER_EDGES = {
        { "TOPLEFT", "TOPRIGHT", "SetHeight" },
        { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        { "TOPLEFT", "BOTTOMLEFT", "SetWidth" },
        { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
    }

    local BAR_GLOW_PADDING = 6

    local function BuildBarHealth(plate)
        local health = CreateFrame("StatusBar", nil, plate)
        plate.health = health
        health:SetFrameLevel(10)
        PixelPoint(health, "CENTER", plate, "CENTER", 0, FRIENDLY_PLATE_Y_OFFSET)
        PixelSize(health, GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight())
        health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

        plate.healthBG = health:CreateTexture(nil, "BACKGROUND")
        plate.healthBG:SetAllPoints()
        plate.healthBG:SetColorTexture(0.12, 0.12, 0.12, 1.0)

        -- Three optional vertical health-threshold markers.
        plate.healthMarkers = plate.healthMarkers or {}
        for i = 1, 3 do
            local marker = health:CreateTexture(nil, "OVERLAY", nil, 4)
            marker:SetColorTexture(1, 1, 1, 0.8)
            marker:SetWidth(2)
            marker:SetPoint("TOP", health, "TOP", 0, 0)
            marker:SetPoint("BOTTOM", health, "BOTTOM", 0, 0)
            marker:Hide()
            plate.healthMarkers[i] = marker
        end

        local border = CreateFrame("Frame", nil, health)
        plate.borderFrame = border
        border:SetFrameLevel(health:GetFrameLevel() + 5)
        border:SetAllPoints()
        for _, edge in ipairs(BAR_BORDER_EDGES) do
            local line = border:CreateTexture(nil, "OVERLAY", nil, 7)
            line:SetColorTexture(0, 0, 0, 1)
            line:SetPoint(edge[1], border, edge[1], 0, 0)
            line:SetPoint(edge[2], border, edge[2], 0, 0)
            line[edge[3]](line, 1)
        end

        local glow = CreateFrame("Frame", nil, plate)
        plate.glowFrame, plate.glow = glow, glow
        glow:SetFrameStrata("BACKGROUND")
        glow:SetFrameLevel(1)
        glow:SetPoint("TOPLEFT", health, "TOPLEFT", -BAR_GLOW_PADDING, BAR_GLOW_PADDING)
        glow:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", BAR_GLOW_PADDING, -BAR_GLOW_PADDING)
        glow:Hide()

        plate.hpText = health:CreateFontString(nil, "OVERLAY")
        SetFriendlyFSFont(plate.hpText, GetFriendlyHealthTextSize(), NameplateOutline())
        plate.hpText:SetPoint("RIGHT", health, -2, 0)
        TintOpaque(plate.hpText, GetFriendlyHealthTextColor())

        plate.highlight = health:CreateTexture(nil, "OVERLAY", nil, 6)
        plate.highlight:SetAllPoints()
        plate.highlight:SetColorTexture(1, 1, 1, 0.3)
        plate.highlight:Hide()
    end

    -- Single-line FontString on the bar root. `size` nil leaves the font to the
    -- caller; `colorGetter` tints it; `hidden` starts it hidden.
    local function NewBarTextLine(plate, size, colorGetter, hidden)
        local fs = plate:CreateFontString(nil, "OVERLAY")
        if size then SetFriendlyFSFont(fs, size, NameplateOutline()) end
        fs:SetWordWrap(false)
        fs:SetMaxLines(1)
        if colorGetter then TintOpaque(fs, colorGetter()) end
        if hidden then fs:Hide() end
        return fs
    end

    local function BuildBarTexts(plate)
        plate.name = NewBarTextLine(plate, GetFriendlyPlayerNameTextSize())

        local level = NewBarTextLine(plate, nil, nil, true)
        ApplyFriendlyPlayerLevelStyle(level)
        level:SetJustifyH("RIGHT")
        plate.level = level

        plate.guild = NewBarTextLine(plate, GetFriendlyGuildTextSize(), GetFriendlyGuildColor, true)
        plate.description = NewBarTextLine(plate, GetFriendlyNPCDescriptionTextSize(),
            GetFriendlyNPCDescriptionColor, true)
        ApplyFriendlyBarTextAnchors(plate)
    end

    -- Hidden 24x24 holder frame plus the texture that fills (part of) it.
    local function NewIconHolder(plate, layer)
        local holder = CreateFrame("Frame", nil, plate)
        holder:SetSize(24, 24)
        holder:Hide()
        return holder, holder:CreateTexture(nil, layer)
    end

    local function BuildBarIndicators(plate)
        local health = plate.health
        plate.leftArrow = plate:CreateTexture(nil, "OVERLAY")
        plate.leftArrow:SetPoint("RIGHT", health, "LEFT", -4, 0)
        plate.leftArrow:Hide()
        plate.rightArrow = plate:CreateTexture(nil, "OVERLAY")
        plate.rightArrow:SetPoint("LEFT", health, "RIGHT", 4, 0)
        plate.rightArrow:Hide()
        if ns.RefreshTargetIndicatorTextures then
            ns.RefreshTargetIndicatorTextures(plate)
        end

        local raidHolder, raidIcon = NewIconHolder(plate, "ARTWORK")
        raidHolder:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 2, 2)
        raidIcon:SetPoint("TOPLEFT", 1, -1)
        raidIcon:SetPoint("BOTTOMRIGHT", -1, 1)
        raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        raidIcon:SetTexCoord(0, 1, 0, 1)
        plate.raidFrame, plate.raid = raidHolder, raidIcon

        local pvpHolder, pvpIcon = NewIconHolder(plate, "OVERLAY")
        pvpHolder:SetPoint("LEFT", plate.name, "RIGHT", 4, 0)
        pvpIcon:SetAllPoints()
        plate.pvpFrame, plate.pvp = pvpHolder, pvpIcon
    end

    -- Heal prediction calculator (clients that have it) reporting plain max HP.
    local function NewBarHealthCalculator()
        if not CreateUnitHealPredictionCalculator then return nil end
        local calc = CreateUnitHealPredictionCalculator()
        if calc.SetMaximumHealthMode then
            calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
        end
        return calc
    end

    -- Unit events registered by FriendlyFrame:SetUnit and the method each runs.
    local BAR_EVENT_UPDATERS = {
        UNIT_HEALTH = "UpdateHealth",
        UNIT_NAME_UPDATE = "UpdateName",
        UNIT_LEVEL = "UpdateLevel",
        UNIT_CLASSIFICATION_CHANGED = "UpdatePvPMarker",
    }

    local function OnBarEvent(self, event)
        local method = BAR_EVENT_UPDATERS[event]
        if method then self[method](self) end
    end

    -- After a resize the projected scale is only final a couple of frames
    -- later, so the pixel-perfect relayout waits for the second OnUpdate.
    local function SettleBarLayout(frame)
        local waited = (frame._ktStableLayoutFrames or 0) + 1
        frame._ktStableLayoutFrames = waited
        if waited < 2 then return end
        frame:SetScript("OnUpdate", nil)
        frame._ktStableLayoutFrames = nil
        if not (frame.unit and frame.nameplate) then return end
        frame._ktApplyingStableLayout = true
        frame:RefreshPixelPerfectLayout()
        frame._ktApplyingStableLayout = nil
    end

    local function OnBarSizeChanged(self)
        if not self.unit or self._ktApplyingStableLayout then return end
        self._ktStableLayoutFrames = 0
        self:SetScript("OnUpdate", SettleBarLayout)
    end

    friendlyFrameCache = CreateFramePool("Frame", UIParent, nil, nil, false, function(plate)
        BuildBarRoot(plate)
        BuildBarHealth(plate)
        BuildBarTexts(plate)
        BuildBarIndicators(plate)
        plate.hpCalculator = NewBarHealthCalculator()
        plate:SetScript("OnEvent", OnBarEvent)
        plate:SetScript("OnSizeChanged", OnBarSizeChanged)
        end)
end -- bar pool builders

-- Methods mixed into every pooled bar frame.
local FriendlyFrame = {}

local function UpdateFriendlyBarLevel(plate)
    local level = plate and plate.level
    local name = plate and plate.name
    local unit = plate and plate.unit
    local db = KullThranUINameplatesDB or {}
    if not (level and name and unit) or not ShouldShowFriendlyPlayerLevel()
        or db.showFriendlyPlayers == false or not IsFriendlyPlayerUnit(unit) then
        if level then
            level:SetText("")
            level:Hide()
        end
        return
    end

    local text = ns.GetNameplateLevelText and ns.GetNameplateLevelText(unit)
    if not text then
        level:SetText("")
        level:Hide()
        return
    end

    ApplyFriendlyPlayerLevelStyle(level)
    level:SetText(text)
    PixelWidth(level, math.max(24, (tonumber(db.levelFontSize) or 11) + 10))
    PixelHeight(level, math.max(12, (tonumber(db.levelFontSize) or 11) + 4))
    AnchorFriendlyLevelBeforeName(level, name, GetFriendlyPlayerNameAlignment())
    level:Show()
end

function FriendlyFrame:UpdateLevel()
    UpdateFriendlyBarLevel(self)
end

local function FriendlyBarYOffset()
    local db = KullThranUINameplatesDB
    return db and db.friendlyPlateYOffset or 0
end

-- Centres a bar on its nameplate using the profile's vertical offset.
local function AnchorBarToNameplate(plate, yOff)
    plate:ClearAllPoints()
    plate:SetPoint("CENTER", plate.nameplate, "CENTER", 0, yOff or FriendlyBarYOffset())
end

function FriendlyFrame:SetUnit(unit, nameplate)
    self.unit = unit
    self.nameplate = nameplate
    self:SetParent(nameplate)
    if self.SetIgnoreParentScale then
        self:SetIgnoreParentScale(true)
    end
    AnchorBarToNameplate(self)
    self:SetSize(10, 10)
    self:SetFrameLevel(nameplate:GetFrameLevel() + 1)
    self:Show()

    PixelSize(self.health, GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight())
    ApplyFriendlyHealthAnchor(self)

    -- The native frame is parked right away; the bar now replaces it.
    SuppressBlizzardUF(unit, nameplate)

    self:RegisterUnitEvent("UNIT_HEALTH", unit)
    self:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    pcall(self.RegisterUnitEvent, self, "UNIT_LEVEL", unit)
    pcall(self.RegisterUnitEvent, self, "UNIT_CLASSIFICATION_CHANGED", unit)

    local classColor
    local db = KullThranUINameplatesDB
    if UnitIsPlayer(unit) then
        local _, classToken = UnitClass(unit)
        if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
            classColor = RAID_CLASS_COLORS[classToken]
        end
    end
    if classColor then
        self.health:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
        if db and db.classColorFriendly ~= false then
            self.name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
        else
            self.name:SetTextColor(GetFriendlyPlayerNameColor())
        end
    else
        self.health:SetStatusBarColor(unpack(FRIENDLY_NPC_BAR_RGB))
        self.name:SetTextColor(GetFriendlyNPCNameColor())
    end

    local outline = NameplateOutline
    SetFriendlyFSFont(self.name, UnitIsPlayer(unit) and GetFriendlyPlayerNameTextSize() or GetFriendlyNPCNameTextSize(),
        outline())
    SetFriendlyFSFont(self.hpText, GetFriendlyHealthTextSize(), outline())
    SetFriendlyFSFont(self.guild, GetFriendlyGuildTextSize(), outline())
    SetFriendlyFSFont(self.description, GetFriendlyNPCDescriptionTextSize(), outline())
    ApplyFriendlyBarTextAnchors(self)
    TintOpaque(self.hpText, GetFriendlyHealthTextColor())
    TintOpaque(self.guild, GetFriendlyGuildColor())
    TintOpaque(self.description, GetFriendlyNPCDescriptionColor())

    self:UpdateHealth()
    self:UpdateName()
    self:UpdateRaidIcon()
    self:UpdatePvPMarker()
    self:ApplyTarget()
    if ns.ApplyHealthBarTexture then ns.ApplyHealthBarTexture(self) end
end

-- Empties and hides an optional secondary text line.
local function BlankBarLine(fs)
    if not fs then return end
    fs:SetText("")
    fs:Hide()
end

-- Indicator regions every released bar must hide, in hide order.
local BAR_INDICATOR_KEYS = { "glow", "highlight", "raidFrame", "pvpFrame", "leftArrow", "rightArrow" }

local function HideBarIndicators(plate)
    for _, key in ipairs(BAR_INDICATOR_KEYS) do
        plate[key]:Hide()
    end
end

function FriendlyFrame:ClearUnit()
    self:SetScript("OnUpdate", nil)
    self._ktStableLayoutFrames = nil
    self._ktApplyingStableLayout = nil
    self:UnregisterAllEvents()
    self.name:SetText("")
    BlankBarLine(self.level)
    BlankBarLine(self.guild)
    BlankBarLine(self.description)
    -- Hand the native frame back while the unit token is still known.
    if self.unit then RestoreBlizzardUF(self.unit) end
    self.unit = nil
    self.nameplate = nil
    if self.SetIgnoreParentScale then
        self:SetIgnoreParentScale(true)
    end
    HideBarIndicators(self)
    self:Hide()
    self:SetParent(UIParent)
    self:ClearAllPoints()
end

function FriendlyFrame:UpdateHealthMarkers()
    if not (self.health and self.healthMarkers and ns and ns.ApplyHealthMarkersToBar) then
        if self.healthMarkers then
            for i = 1, #self.healthMarkers do
                local tex = self.healthMarkers[i]
                if tex and tex.Hide then tex:Hide() end
            end
        end
        return
    end

    local unit = self.unit
    if not unit then return end
    local isTarget = UnitIsUnit(unit, "target")
    ns.ApplyHealthMarkersToBar(self.health, self.healthMarkers, isTarget)
end

function FriendlyFrame:UpdateHealth()
    local unit = self.unit
    if not unit then return end

    -- Paso 1: resolver valores de vida seg\u00fan el m\u00e9todo disponible
    local curHP, maxHP
    local calc = self.hpCalculator
    if calc and calc.GetMaximumHealth then
        UnitGetDetailedHealPrediction(unit, nil, calc)
        calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
        maxHP = calc:GetMaximumHealth()
        curHP = calc:GetCurrentHealth()
    else
        maxHP = UnitHealthMax(unit)
        curHP = UnitHealth(unit)
    end
    self.health:SetMinMaxValues(0, maxHP)
    self.health:SetValue(curHP)

    -- Paso 2: texto de porcentaje — evaluar condiciones de mayor a menor prioridad
    local label
    if UnitIsDeadOrGhost(unit) then
        label = "0%"
    elseif not UnitHealthPercent then
        label = ""
    else
        local cfg = KullThranUINameplatesDB
        if cfg and cfg.friendlyHideHealthText then
            label = ""
        else
            local scaleTo100 = CurveConstants and CurveConstants.ScaleTo100 or nil
            local percentValue = UnitHealthPercent(unit, true, scaleTo100)
            label = percentValue and string.format("%d%%", percentValue) or ""
        end
    end
    self.hpText:SetText(label)

    self:UpdateHealthMarkers()
end

function FriendlyFrame:UpdateName()
    local unit = self.unit
    if not unit then return end
    local unitName = UnitName(unit)
    self.name:SetText(unitName or "")
    if UnitIsPlayer(unit) then
        local db = KullThranUINameplatesDB
        if db and db.classColorFriendly ~= false then
            local _, classToken = UnitClass(unit)
            local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            if classColor then
                self.name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
            else
                self.name:SetTextColor(GetFriendlyPlayerNameColor())
            end
        else
            self.name:SetTextColor(GetFriendlyPlayerNameColor())
        end
    else
        self.name:SetTextColor(GetFriendlyNPCNameColor())
    end
    if self.guild then
        if ShouldShowFriendlyGuild() and UnitIsPlayer(unit) and GetGuildInfo then
            local g = GetGuildInfo(unit)
            if g and g ~= "" then
                local gr, gg, gb = GetFriendlyGuildColor()
                self.guild:SetTextColor(gr, gg, gb, 1)
                self.guild:SetText("<" .. g .. ">")
                self.guild:Show()
            else
                self.guild:SetText("")
                self.guild:Hide()
            end
        else
            self.guild:SetText("")
            self.guild:Hide()
        end
    end
    if self.description then
        if not UnitIsPlayer(unit) then
            local descriptionText = GetFriendlyNPCDescription(unit)
            self.description:SetText(descriptionText or "")
            self.description:SetShown(descriptionText ~= nil and descriptionText ~= "")
        else
            self.description:SetText("")
            self.description:Hide()
        end
    end
    ApplyFriendlyHealthAnchor(self)
    ApplyFriendlyBarTextAnchors(self)
    self:UpdateLevel()
end

function FriendlyFrame:UpdateRaidIcon()
    if not self.unit then
        self.raidFrame:Hide()
        return
    end

    local pos = ns.GetRaidMarkerPos()
    local markerIndex = ns.FriendlyRaidMarker(self.unit)
    if pos == "none" or type(markerIndex) == "nil"
        or not ns.SetFriendlyRaidMarkerTexture(self.raid, markerIndex) then
        self.raidFrame:Hide()
        return
    end
    local sz = ns.GetRaidMarkerSize()
    local rmY = ns.GetRaidMarkerYOffset()
    self.raidFrame:SetSize(sz, sz)
    self.raidFrame:ClearAllPoints()

    local sideOffset = ns.GetSideAuraXOffset()
    local pointByPosition = {
        top = { "BOTTOM", self.health, "TOP", 0, ns.GetDebuffYOffset() },
        left = { "RIGHT", self.health, "LEFT", -sideOffset, 0 },
        right = { "LEFT", self.health, "RIGHT", sideOffset, 0 },
        topleft = { "BOTTOMLEFT", self.health, "TOPLEFT", -2, rmY },
        topright = { "BOTTOMRIGHT", self.health, "TOPRIGHT", 2, rmY },
    }
    local anchor = pointByPosition[pos]
    if anchor then
        self.raidFrame:SetPoint(unpack(anchor))
    end

    self.raidFrame:Show()
end

function FriendlyFrame:UpdatePvPMarker()
    if not self.unit or not self.pvpFrame or not self.pvp then
        if self.pvpFrame then self.pvpFrame:Hide() end
        return
    end

    local atlas = GetFriendlyPlayerPvPAtlas(self.unit)
    if not atlas then
        self.pvpFrame:Hide()
        return
    end

    local atlasSet = pcall(self.pvp.SetAtlas, self.pvp, atlas, false)
    self.pvpFrame:SetShown(atlasSet)
end

function FriendlyFrame:ApplyTarget()
    if not self.unit then return end
    local isTarget = UnitIsUnit(self.unit, "target")
    local style = ns.GetTargetGlowStyle and ns.GetTargetGlowStyle() or "kullthranui"
    if isTarget and style ~= "none" then
        if ns.ApplyTargetGlowStyleToPlate then
            ns.ApplyTargetGlowStyleToPlate(self, style)
        end
        self.glow:Show()
    else
        self.glow:Hide()
    end
    local showArrows = isTarget and ns.GetShowTargetArrows and ns.GetShowTargetArrows()
    if ns.RefreshTargetIndicatorTextures then
        ns.RefreshTargetIndicatorTextures(self)
    end
    if ns.SetTargetIndicatorShown then
        ns.SetTargetIndicatorShown(self, showArrows or false)
    else
        self.leftArrow:SetShown(showArrows or false)
        self.rightArrow:SetShown(showArrows or false)
    end

    self:UpdateHealthMarkers()
end

-- Bar lifecycle and the target / mouseover / raid-icon watcher (Nameplates_FriendlyBars.lua).
ns.NameplatesFriendlyBars.Setup({
    client = "retail",
    friendlyPlates = friendlyPlates,
    suppressedUFs = suppressedUFs,
    pool = friendlyFrameCache,
    FriendlyFrame = FriendlyFrame,
    -- This file's secret guards, never the client's globals of the same names.
    UnitCanAttack = UnitCanAttack,
    UnitIsUnit = UnitIsUnit,
    UnitExists = UnitExists,
    IsFriendlyEnabled = IsFriendlyEnabled,
    HideBarIndicators = HideBarIndicators,
    IsFriendlyBarForUnit = IsFriendlyBarForUnit,
    BlankBarLine = BlankBarLine,
})

-- Re-applies size-dependent anchors of one bar after a size change.
local function ResizeBarHealth(plate, w, h)
    PixelSize(plate.health, w, h)
    ApplyFriendlyHealthAnchor(plate)
    ApplyFriendlyBarTextAnchors(plate)
end

-- Live option refreshes (offset / bar size), run over every active bar.
function ns.RefreshFriendlyPlateYOffset()
    local yOff = FriendlyBarYOffset()
    for _, plate in pairs(friendlyPlates) do
        if plate.nameplate then AnchorBarToNameplate(plate, yOff) end
    end
end

function ns.RefreshFriendlyPlateSize()
    local w, h = GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight()
    for _, plate in pairs(friendlyPlates) do
        ResizeBarHealth(plate, w, h)
        if plate.UpdateHealthMarkers then
            plate:UpdateHealthMarkers()
        end
    end
end

function FriendlyFrame:RefreshPixelPerfectLayout()
    if not (self.unit and self.nameplate) then return end
    AnchorBarToNameplate(self)
    self:SetSize(10, 10)
    ResizeBarHealth(self, GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight())
    self:UpdateLevel()
    self:UpdateRaidIcon()
    self:UpdatePvPMarker()
    self:UpdateHealthMarkers()
end

-- Per-tick relayout throttle for ns.RefreshFriendlyPixelPerfectLayout (called
-- by the nameplate manager tick). A bar is relaid out only when its effective
-- scale moved, it shows a different unit, the offset/size options changed, or
-- on every 10th tick as a catch-all.
do
    local FULL_RELAYOUT_EVERY = 10
    local SCALE_EPSILON = 0.003
    local tick = { count = 0 }

    local function BarNeedsRelayout(plate, forced)
        if forced or plate._ktFriendlyTickUnit ~= plate.unit then return true end
        local scale = plate.GetEffectiveScale and plate:GetEffectiveScale()
        local last = plate._ktFriendlyTickScale
        return type(scale) ~= "number" or not last or math.abs(last - scale) >= SCALE_EPSILON
    end

    function ns.RefreshFriendlyPixelPerfectLayout()
        local yOff = FriendlyBarYOffset()
        local w, h = GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight()
        tick.count = tick.count + 1
        local forced = tick.count >= FULL_RELAYOUT_EVERY
            or tick.yOff ~= yOff or tick.w ~= w or tick.h ~= h
        if tick.count >= FULL_RELAYOUT_EVERY then tick.count = 0 end
        tick.yOff, tick.w, tick.h = yOff, w, h
        for _, plate in pairs(friendlyPlates) do
            if BarNeedsRelayout(plate, forced) then
                plate._ktFriendlyTickScale = plate.GetEffectiveScale and plate:GetEffectiveScale()
                plate._ktFriendlyTickUnit = plate.unit
                plate:RefreshPixelPerfectLayout()
            end
        end
    end
end

function ns.RefreshFriendlyHealthText()
    for _, plate in pairs(friendlyPlates) do plate:UpdateHealth() end
end

function ns.RefreshFriendlyPlayerLevels()
    for _, plate in pairs(friendlyPlates) do
        if plate.UpdateLevel then plate:UpdateLevel() end
    end

    for _, overlay in pairs(npcOverlays) do
        if overlay and overlay.unit and UnitIsPlayer(overlay.unit) then
            UpdateStableOverlayContent(overlay)
            ApplyStableOverlayLayout(overlay, false)
        end
    end
end

-- Secondary bar lines restyled by the text options: field, size, colour.
local BAR_STYLED_LINES = {
    { "hpText", GetFriendlyHealthTextSize, GetFriendlyHealthTextColor },
    { "guild", GetFriendlyGuildTextSize, GetFriendlyGuildColor },
    { "description", GetFriendlyNPCDescriptionTextSize, GetFriendlyNPCDescriptionColor },
}

local function RestyleBarTexts(plate)
    if plate.name then
        local isPlayer = plate.unit and UnitIsPlayer(plate.unit)
        SetFriendlyFSFont(plate.name,
            isPlayer and GetFriendlyPlayerNameTextSize() or GetFriendlyNPCNameTextSize(), NameplateOutline())
    end
    for _, spec in ipairs(BAR_STYLED_LINES) do
        local fs = plate[spec[1]]
        if fs then
            SetFriendlyFSFont(fs, spec[2](), NameplateOutline())
            TintOpaque(fs, spec[3]())
        end
    end
end

-- Rebuilds content and full layout of every live name-only overlay.
local function RefreshAllOverlays()
    for _, overlay in pairs(npcOverlays) do
        if overlay and overlay.unit then
            UpdateStableOverlayContent(overlay)
            ApplyStableOverlayLayout(overlay, true)
        end
    end
end

function ns.RefreshFriendlyTextStyle()
    for _, plate in pairs(friendlyPlates) do
        RestyleBarTexts(plate)
        ApplyFriendlyHealthAnchor(plate)
        ApplyFriendlyBarTextAnchors(plate)
        if plate.UpdateName then plate:UpdateName() end
        if plate.UpdateHealth then plate:UpdateHealth() end
    end
    RefreshAllOverlays()
end

ns.RefreshFriendlyNameOnlyOverlayLayout = RefreshAllOverlays
-- The options panel refreshes fonts through this older name as well.
ns.RefreshFriendlyFontOverride = RefreshAllOverlays

-- Calls fn(nameplate, unitToken) for every readable nameplate; the token is
-- nil for plates that are not bound to a unit at the moment.
local function ForEachReadablePlate(fn)
    for _, nameplate in ipairs(GetAccessibleNamePlates()) do
        fn(nameplate, nameplate.namePlateUnitToken)
    end
end

local function AddBarForPlate(_, unit)
    if unit then ns.TryAddFriendlyPlate(unit) end
end

-- Puts every plate into the presentation its unit's mode asks for: name-only
-- units get the overlay; plates that no longer qualify get Blizzard's back.
local function SyncNameOnlyPlate(nameplate, unit)
    if unit and IsFriendlyNameOnlyForUnit(unit) then
        SuppressNPCNameplate(nameplate, unit)
    elseif nameOnlyNPCSuppressed[nameplate] then
        RestoreNPCNameplate(nameplate, unit)
    end
end

local function SweepNameOnlyPlates()
    ForEachReadablePlate(SyncNameOnlyPlate)
end

-- Profile-derived visibility per friendly unit type.
local function FriendlyTypesShown(db)
    if ns.ShouldShowFriendlyNameplates then
        return ns.ShouldShowFriendlyNameplates(true), ns.ShouldShowFriendlyNameplates(false)
    end
    return db.showFriendlyPlayers ~= false, db.showFriendlyNPCs == true
end

-- Blizzard visibility CVars, each set to 1/0 from one of the mode flags
-- computed in UpdateFriendlyNameplateSystem (queued in this order).
local FRIENDLY_VISIBILITY_CVARS = {
    { "nameplateShowOnlyNameForFriendlyPlayerUnits", "playerNameOnly" },
    { "nameplateShowFriendlyPlayers", "showPlayers" },
    { "nameplateShowFriends", "showPlayers" },
    { "nameplateShowFriendlyNPCs", "showNPCs" },
    { "nameplateShowFriendlyNpcs", "showNPCs" },
    -- Drives Blizzard's own quest-giver "?" marker on special NPCs.
    { "UnitNameFriendlySpecialNPCName", "showNPCs" },
}

-- Turns the system on/off from the profile; runs on login, zone changes and
-- whenever a friendly nameplate option changes.
function ns.UpdateFriendlyNameplateSystem()
    local db = KullThranUINameplatesDB or {}
    local hasBars = IsFriendlyEnabled()
    local showPlayers, showNPCs = FriendlyTypesShown(db)
    local mode = {
        showPlayers = showPlayers,
        showNPCs = showNPCs,
        playerNameOnly = showPlayers and FriendlyNameOnlyValue(true),
    }
    local npcNameOnly = showNPCs and FriendlyNameOnlyValue(false)

    SetFriendlyAuraCVars(hasBars or mode.playerNameOnly or npcNameOnly)

    -- The PvP marker only exists for name-only friendly players.
    if not (showPlayers and mode.playerNameOnly) then
        for nameplate in pairs(friendlyPlayerPvPMarkers) do
            HideFriendlyPlayerPvPMarker(nameplate)
        end
    end

    if ns.QueueNameplateCVar then
        for _, cvar in ipairs(FRIENDLY_VISIBILITY_CVARS) do
            ns.QueueNameplateCVar(cvar[1], mode[cvar[2]] and 1 or 0)
        end
    end

    -- Units whose type switched to name-only give their bar back.
    for unit in pairs(friendlyPlates) do
        if not IsFriendlyBarForUnit(unit) then
            ns.RemoveFriendlyPlate(unit)
        end
    end

    -- Hand overlays back first, so a unit moving to bars never shows both.
    SweepNameOnlyPlates()

    ns.NameplatesFriendlyBars.SetEnabled(hasBars)
    if hasBars then
        ForEachReadablePlate(AddBarForPlate)
        for unit in pairs(ns.pendingUnits or {}) do ns.TryAddFriendlyPlate(unit) end
    else
        ns.NameplatesFriendlyBars.ClearAll()
    end

    -- Unit tokens can become readable only after login or plate recycling;
    -- sweep again now and twice more shortly after.
    SweepNameOnlyPlates()
    C_Timer.After(0.1, SweepNameOnlyPlates)
    C_Timer.After(0.5, SweepNameOnlyPlates)
end

-- Friendly NPC plates without a custom bar get the name-only overlay.
local function SuppressNameOnlyNPCPlate(nameplate, unit)
    if unit and not UnitCanAttack("player", unit) and not UnitIsUnit(unit, "player")
        and not UnitIsPlayer(unit) then
        SuppressNPCNameplate(nameplate, unit)
    end
end

-- Follow-up after each loading screen: plates that were not readable during
-- login or the zone change are picked up one frame later.
local function CatchUpAfterLoadingScreen()
    if ns.NameplatesFriendlyBars.IsEnabled() then
        ForEachReadablePlate(AddBarForPlate)
    end
    -- Note: evaluated without a unit, i.e. "any friendly type is name-only".
    if IsNameOnlyMode() then
        ForEachReadablePlate(SuppressNameOnlyNPCPlate)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        ns.UpdateFriendlyNameplateSystem()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.UpdateFriendlyNameplateSystem()
        C_Timer.After(0, CatchUpAfterLoadingScreen)
    end
end)

-- Entry points used by the NAME_PLATE_UNIT_ADDED / REMOVED handlers in
-- Nameplates.lua.

-- Kept for the caller; overlays already colour friendly NPC names.
function ns.TryColorFriendlyNPCName()
end

-- The driver hook normally parks the native frame first; this re-applies
-- it from NAME_PLATE_UNIT_ADDED for recycled frames that another addon may
-- have restored in between.
function ns.TrySuppressNPCHealthBar(unit, nameplate)
    if not (unit and nameplate) or UnitIsPlayer(unit) then return end
    if not IsNameOnlyMode(unit) or UnitCanAttack("player", unit) then return end
    SuppressNPCNameplate(nameplate, unit)
end

function ns.TrySuppressFriendlyPlayerNameplate(unit, nameplate)
    if not (unit and nameplate and IsNameOnlyMode(unit)) then return end
    local db = KullThranUINameplatesDB or {}
    if db.showFriendlyPlayers == false then return end
    if not UnitIsPlayer(unit) or UnitIsUnit(unit, "player")
        or UnitCanAttack("player", unit) then
        return
    end
    SuppressNPCNameplate(nameplate, unit)
end

-- Gives an NPC plate its Blizzard frame back; player plates are left alone.
local function RestoreNPCPlate(nameplate)
    local unit = nameplate and nameplate.namePlateUnitToken
    if unit and not UnitIsPlayer(unit) then
        RestoreNPCNameplate(nameplate, unit)
    end
end
ns.RestoreFriendlyNPCNameColor = RestoreNPCPlate
ns.RestoreNPCHealthBar = RestoreNPCPlate
