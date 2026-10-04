local addon, ns = ...

if not ns then return end

local PP = (KullThranUI and KullThranUI.PP) or (KT and KT.PP)

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

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local friendlyEnabled = false
local friendlyPlates = {}
ns.friendlyPlates = friendlyPlates
ns.friendlyPlatesByNameplate = ns.friendlyPlatesByNameplate or {}

local FRIENDLY_BAR_W = 80
local FRIENDLY_PLATE_Y_OFFSET = -18

local function IsInFollowerDungeon()
    if ns and ns.IsInFollowerDungeon then
        return ns.IsInFollowerDungeon()
    end
    if C_LFGInfo and C_LFGInfo.IsInLFGFollowerDungeon and C_LFGInfo.IsInLFGFollowerDungeon() then
        return true
    end
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID == 208 then
        return true
    end
    return false
end

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

local function GetFriendlyNPCDescription(unit)
    if not unit or UnitIsPlayer(unit) or UnitCanAttack("player", unit) then return nil end

    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, info = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and IsAccessible(info) and type(info) == "table" then
            local lines = info.lines
            if IsAccessible(lines) and type(lines) == "table" then
                local tooltipTypes = Enum and Enum.TooltipDataLineType
                local titleType = tooltipTypes and tooltipTypes.UnitTitle
                local unitName = UnitName(unit)
                if not IsAccessible(unitName) then unitName = nil end

                -- Preferred path: Blizzard explicitly marks the occupation.
                for _, line in ipairs(lines) do
                    if IsAccessible(line) and type(line) == "table" then
                        local lineType = IsAccessible(line.type) and line.type or nil
                        if titleType and lineType == titleType then
                            local title = SafeTooltipLineText(line)
                            if IsNPCOccupationCandidate(unit, title, unitName) then
                                return title
                            end
                        end
                    end
                end

                -- Forever may expose the same occupation as an untyped
                -- tooltip line. Accept it, but never use race/type text.
                for _, line in ipairs(lines) do
                    if IsAccessible(line) and type(line) == "table" then
                        local lineType = IsAccessible(line.type) and line.type or nil
                        if not IsNonOccupationTooltipType(lineType, tooltipTypes) then
                            local candidate = SafeTooltipLineText(line)
                            if IsNPCOccupationCandidate(unit, candidate, unitName) then
                                return candidate
                            end
                        end
                    end
                end
            end
        end
    end

    -- Do not fall back to UnitCreatureFamily/UnitCreatureType: those are
    -- race/type labels such as "Humanoid", not the NPC occupation.
    return nil
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

-- Friendly NPC color: #00ff00
local NPC_COLOR_R, NPC_COLOR_G, NPC_COLOR_B = 0, 1, 0

-------------------------------------------------------------------------------
--  Friendly name-only font override (NEUTRALIZED — taint safety)
--  IMPORTANT: Do NOT call SystemFont_NamePlate:SetFont() or
--  SystemFont_NamePlate_Outlined:SetFont() from addon code.
--  Those are global Blizzard font objects inherited by DamageMeterEntry
--  FontStrings. Modifying them from insecure addon code taints every string
--  those FontStrings contain (combat-log names), causing:
--    "attempt to compare local 'text' (a secret string value tainted by KullThranUI)"
--  in DamageMeterEntry.lua:86 UpdateName().
--  Font is applied per-nameplate via ApplyFontToNameText() instead.
-------------------------------------------------------------------------------
local fontOverrideApplied = false -- kept for compat; no-op

local function ApplyFriendlyFontOverride()
    -- INTENTIONALLY LEFT EMPTY: see taint safety note above.
    -- Per-nameplate font is applied via ApplyFontToNameText() on nameplate creation.
    fontOverrideApplied = true
end

local function RestoreFriendlyFontOverride()
    -- INTENTIONALLY LEFT EMPTY: no global font objects were modified.
    fontOverrideApplied = false
end

-------------------------------------------------------------------------------
--  Per-FontString font override
--  Instead of modifying the global SystemFont_NamePlate objects (which causes
--  sub-pixel shimmer/warping), we hook each nameplate's name FontString and
--  apply our font + pixel snap settings directly on it.  This preserves
--  Blizzard's internal font object rendering properties.
-------------------------------------------------------------------------------
local styledNameTexts = {} -- nameText → true (tracks which FontStrings we've styled)
local hookedNameFonts = {} -- nameText → true (permanent hooks, applied once)

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

-------------------------------------------------------------------------------
--  Stable name-only friendly overlay
--  Friendly names are best rendered in addon-owned regions. Keeping the Blizzard name FontString while attaching custom level/guild
--  regions produces mixed layout passes as the projected plate scale changes.
-------------------------------------------------------------------------------
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

    if overlay.level then
        overlay.level:ClearAllPoints()
        PixelPoint(overlay.level, "RIGHT", overlay.name, "LEFT", -4, 0)
    end
    if overlay.pvpFrame then
        overlay.pvpFrame:ClearAllPoints()
        PixelPoint(overlay.pvpFrame, "LEFT", overlay.name, "RIGHT", 4, 0)
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
end

local function ShowNPCOverlay(nameplate, unit)
    if not (nameplate and unit) then return end
    local existing = npcOverlays[nameplate]
    if existing then
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

    overlay:UnregisterAllEvents()
    pcall(overlay.RegisterUnitEvent, overlay, "UNIT_NAME_UPDATE", unit)
    pcall(overlay.RegisterUnitEvent, overlay, "UNIT_GUILD_UPDATE", unit)
    pcall(overlay.RegisterUnitEvent, overlay, "UNIT_CLASSIFICATION_CHANGED", unit)
    pcall(overlay.RegisterUnitEvent, overlay, "UNIT_LEVEL", unit)

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
    overlay:ClearAllPoints()
    overlay:SetParent(UIParent)
    overlay:Hide()
    npcOverlayPool[#npcOverlayPool + 1] = overlay
end
-------------------------------------------------------------------------------
--  Runtime layout comparison
--  Debug command [target|mouseover|nameplateN] prints the same scale, parent and
--  font metrics for the Blizzard and KUI nameplate regions.
-------------------------------------------------------------------------------
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
        print("|cff66ccffKNP debug|r " .. label .. ": unavailable")
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
        print("|cff66ccffKNP debug|r Target or mouse over a visible nameplate first.")
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

SLASH_KULLTHRANNAMEPLATEDEBUG1 = "/knpdebug"
SlashCmdList.KULLTHRANNAMEPLATEDEBUG = function(message)
    local requested = type(message) == "string" and message:match("^%s*(.-)%s*$") or nil
    DumpFriendlyLayout(requested ~= "" and requested or nil)
end
-------------------------------------------------------------------------------
--  Hidden frame — Blizzard sub-frames reparented here become invisible
--  and stop receiving layout updates.  This suppresses the default frames.
-------------------------------------------------------------------------------
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

-------------------------------------------------------------------------------
--  Blizzard UnitFrame suppression via NamePlateDriverFrame hooks
--  Hook OnNamePlateAdded/Removed on the
--  NamePlateDriverFrame so suppression happens BEFORE any addon event fires.
--  This eliminates the flash of Blizzard nameplates.
-------------------------------------------------------------------------------
local hookedUFs = {}   -- UnitFrame → true  (hooks are permanent, only applied once)
local modifiedUFs = {} -- unit → { uf = UnitFrame, nameplate = nameplate }
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

local function SuppressBlizzardUF(unit, nameplate)
    if modifiedUFs[unit] then return end -- already suppressed
    local uf = nameplate and nameplate.UnitFrame
    if not uf then return end

    local entry = { uf = uf, nameplate = nameplate }
    modifiedUFs[unit] = entry

    uf:SetAlpha(0)

    -- Reparent the entire UnitFrame to the hidden frame.
    -- This makes everything invisible. We do NOT unregister events
    -- because we need Blizzard's UF to stay functional for when
    -- we restore it (e.g. toggling back to name-only mode).
    uf:SetParent(hiddenFrame)

    -- Permanent SetAlpha hook (once per UF instance)
    if not hookedUFs[uf] then
        hookedUFs[uf] = true
        local locked = false
        hooksecurefunc(uf, "SetAlpha", function(self)
            if locked or self:IsForbidden() then return end
            locked = true
            local ufUnit = self.unit or (self.GetUnit and self:GetUnit())
            if ufUnit and modifiedUFs[ufUnit] then
                self:SetAlpha(0)
            end
            locked = false
        end)
    end
end

local function RestoreBlizzardUF(unit)
    local entry = modifiedUFs[unit]
    if not entry then return end
    local parent, frame = entry.nameplate, entry.uf
    -- Liberar la referencia antes de tocar el frame; el hook de SetAlpha
    -- consulta modifiedUFs, así que debe estar limpio primero
    modifiedUFs[unit] = nil
    frame:SetParent(parent)
    frame:Show()
    frame:SetAlpha(1)
end

-------------------------------------------------------------------------------
--  Name-only NPC suppression
--  Fully suppress the Blizzard UnitFrame for NPC plates in name-only mode
--  by reparenting it to the hidden frame (same technique as health-bar mode).
--  Then show our own name overlay on top.
-------------------------------------------------------------------------------
local nameOnlyNPCSuppressed = {} -- nameplate → true

local function SuppressNPCNameplate(nameplate, unit)
    if nameOnlyNPCSuppressed[nameplate] then return end
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

-------------------------------------------------------------------------------
--  NamePlateDriverFrame hooks — suppress Blizzard UFs at the earliest moment
--  These fire synchronously inside Blizzard's nameplate creation, BEFORE
--  NAME_PLATE_UNIT_ADDED reaches any addon event handler.
-------------------------------------------------------------------------------
hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
    if not unit or unit == "preview" then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if ns.IsEnemyNameplateUnit and ns.IsEnemyNameplateUnit(unit, nameplate) then return end
    if UnitIsUnit(unit, "player") then return end

    -- Each friendly unit type can independently use a custom health bar or
    -- the stable name-only overlay. Suppress Blizzard's UnitFrame before the
    -- regular NAME_PLATE_UNIT_ADDED event so no native health bar flashes.
    if not nameplate then return end

    if IsFriendlyBarForUnit(unit) then
        SuppressBlizzardUF(unit, nameplate)
        return
    end

    if IsNameOnlyMode(unit) then
        SuppressNPCNameplate(nameplate, unit)
    end
end)

hooksecurefunc(NamePlateDriverFrame, "OnNamePlateRemoved", function(_, unit)
    -- Guard: Blizzard settings panel can fire this with "preview" which is not a valid unit
    if not unit or not unit:find("^nameplate") then return end
    -- Clean up NPC overlay if present
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate then
        HideNPCOverlay(nameplate)
        nameOnlyNPCSuppressed[nameplate] = nil
        HideFriendlyPlayerLevel(nameplate)
        HideFriendlyPlayerPvPMarker(nameplate)
    end
    if modifiedUFs[unit] then
        RestoreBlizzardUF(unit)
    end
end)

-------------------------------------------------------------------------------
--  Frame pool for custom friendly plates
-------------------------------------------------------------------------------
local friendlyFrameCache = CreateFramePool("Frame", UIParent, nil, nil, false, function(plate)
    -- Use a stable display root: a small, fixed-size child of
    -- Blizzard's projected nameplate whose render layers are composed once.
    plate:SetSize(10, 10)
    plate:SetFlattensRenderLayers(true)
    if plate.SetCollapsesLayout then
        plate:SetCollapsesLayout(true)
    end
    if plate.SetIgnoreParentScale then
        plate:SetIgnoreParentScale(false)
    end

    plate.health = CreateFrame("StatusBar", nil, plate)
    plate.health:SetFrameLevel(10)
    PixelPoint(plate.health, "CENTER", plate, "CENTER", 0, FRIENDLY_PLATE_Y_OFFSET)
    PixelSize(plate.health, GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight())
    plate.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

    plate.healthBG = plate.health:CreateTexture(nil, "BACKGROUND")
    plate.healthBG:SetAllPoints()
    plate.healthBG:SetColorTexture(0.12, 0.12, 0.12, 1.0)

    -- Custom health markers (up to 3 vertical lines)
    plate.healthMarkers = plate.healthMarkers or {}
    for i = 1, 3 do
        local marker = plate.health:CreateTexture(nil, "OVERLAY", nil, 4)
        marker:SetColorTexture(1, 1, 1, 0.8)
        marker:SetWidth(2)
        marker:SetPoint("TOP", plate.health, "TOP", 0, 0)
        marker:SetPoint("BOTTOM", plate.health, "BOTTOM", 0, 0)
        marker:Hide()
        plate.healthMarkers[i] = marker
    end

    plate.borderFrame = CreateFrame("Frame", nil, plate.health)
    plate.borderFrame:SetFrameLevel(plate.health:GetFrameLevel() + 5)
    plate.borderFrame:SetAllPoints()
    do
        local thickness = 1
        local function Mk()
            local t = plate.borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetColorTexture(0, 0, 0, 1)
            return t
        end
        local top = Mk()
        top:SetPoint("TOPLEFT", plate.borderFrame, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", plate.borderFrame, "TOPRIGHT", 0, 0)
        top:SetHeight(thickness)

        local bottom = Mk()
        bottom:SetPoint("BOTTOMLEFT", plate.borderFrame, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", plate.borderFrame, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(thickness)

        local left = Mk()
        left:SetPoint("TOPLEFT", plate.borderFrame, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", plate.borderFrame, "BOTTOMLEFT", 0, 0)
        left:SetWidth(thickness)

        local right = Mk()
        right:SetPoint("TOPRIGHT", plate.borderFrame, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", plate.borderFrame, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(thickness)
    end

    plate.glowFrame = CreateFrame("Frame", nil, plate)
    plate.glowFrame:SetFrameStrata("BACKGROUND")
    plate.glowFrame:SetFrameLevel(1)
    local GLOW_EXTEND = 6
    plate.glowFrame:SetPoint("TOPLEFT", plate.health, "TOPLEFT", -GLOW_EXTEND, GLOW_EXTEND)
    plate.glowFrame:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", GLOW_EXTEND, -GLOW_EXTEND)
    plate.glow = plate.glowFrame
    plate.glowFrame:Hide()

    plate.hpText = plate.health:CreateFontString(nil, "OVERLAY")
    SetFriendlyFSFont(plate.hpText, GetFriendlyHealthTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    plate.hpText:SetPoint("RIGHT", plate.health, -2, 0)
    do
        local r, g, b = GetFriendlyHealthTextColor()
        plate.hpText:SetTextColor(r, g, b, 1)
    end

    plate.highlight = plate.health:CreateTexture(nil, "OVERLAY", nil, 6)
    plate.highlight:SetAllPoints()
    plate.highlight:SetColorTexture(1, 1, 1, 0.3)
    plate.highlight:Hide()

    plate.name = plate:CreateFontString(nil, "OVERLAY")
    SetFriendlyFSFont(plate.name, GetFriendlyPlayerNameTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    plate.name:SetWordWrap(false)
    plate.name:SetMaxLines(1)

    plate.level = plate:CreateFontString(nil, "OVERLAY")
    ApplyFriendlyPlayerLevelStyle(plate.level)
    plate.level:SetJustifyH("RIGHT")
    plate.level:SetWordWrap(false)
    plate.level:SetMaxLines(1)
    plate.level:Hide()

    plate.guild = plate:CreateFontString(nil, "OVERLAY")
    SetFriendlyFSFont(plate.guild, GetFriendlyGuildTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    plate.guild:SetWordWrap(false)
    plate.guild:SetMaxLines(1)
    do
        local r, g, b = GetFriendlyGuildColor()
        plate.guild:SetTextColor(r, g, b, 1)
    end
    plate.guild:Hide()

    plate.description = plate:CreateFontString(nil, "OVERLAY")
    SetFriendlyFSFont(plate.description, GetFriendlyNPCDescriptionTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    plate.description:SetWordWrap(false)
    plate.description:SetMaxLines(1)
    do
        local dr, dg, db = GetFriendlyNPCDescriptionColor()
        plate.description:SetTextColor(dr, dg, db, 1)
    end
    plate.description:Hide()
    ApplyFriendlyBarTextAnchors(plate)

    plate.leftArrow = plate:CreateTexture(nil, "OVERLAY")
    plate.leftArrow:SetPoint("RIGHT", plate.health, "LEFT", -4, 0)
    plate.leftArrow:Hide()
    plate.rightArrow = plate:CreateTexture(nil, "OVERLAY")
    plate.rightArrow:SetPoint("LEFT", plate.health, "RIGHT", 4, 0)
    plate.rightArrow:Hide()
    if ns.RefreshTargetIndicatorTextures then
        ns.RefreshTargetIndicatorTextures(plate)
    end

    plate.raidFrame = CreateFrame("Frame", nil, plate)
    plate.raidFrame:SetSize(24, 24)
    plate.raidFrame:SetPoint("BOTTOMRIGHT", plate.health, "TOPRIGHT", 2, 2)
    plate.raidFrame:Hide()
    plate.raid = plate.raidFrame:CreateTexture(nil, "ARTWORK")
    plate.raid:SetPoint("TOPLEFT", 1, -1)
    plate.raid:SetPoint("BOTTOMRIGHT", -1, 1)
    plate.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    plate.raid:SetTexCoord(0, 1, 0, 1)

    plate.pvpFrame = CreateFrame("Frame", nil, plate)
    plate.pvpFrame:SetSize(24, 24)
    plate.pvpFrame:SetPoint("LEFT", plate.name, "RIGHT", 4, 0)
    plate.pvpFrame:Hide()
    plate.pvp = plate.pvpFrame:CreateTexture(nil, "OVERLAY")
    plate.pvp:SetAllPoints()

    if CreateUnitHealPredictionCalculator then
        plate.hpCalculator = CreateUnitHealPredictionCalculator()
        if plate.hpCalculator.SetMaximumHealthMode then
            plate.hpCalculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
        end
    end

    plate:SetScript("OnEvent", function(self, event, ...)
        local handler = self[event]
        if handler then handler(self, ...) end
    end)
    plate:SetScript("OnSizeChanged", function(self)
        if not self.unit or self._ktApplyingStableLayout then return end
        self._ktStableLayoutFrames = 0
        self:SetScript("OnUpdate", function(frame)
            frame._ktStableLayoutFrames = (frame._ktStableLayoutFrames or 0) + 1
            if frame._ktStableLayoutFrames < 2 then return end
            frame:SetScript("OnUpdate", nil)
            frame._ktStableLayoutFrames = nil
            if not frame.unit or not frame.nameplate then return end
            frame._ktApplyingStableLayout = true
            frame:RefreshPixelPerfectLayout()
            frame._ktApplyingStableLayout = nil
        end)
    end)
end)

-------------------------------------------------------------------------------
--  FriendlyFrame mixin
-------------------------------------------------------------------------------
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

function FriendlyFrame:SetUnit(unit, nameplate)
    self.unit = unit
    self.nameplate = nameplate
    self:SetParent(nameplate)
    if self.SetIgnoreParentScale then
        self:SetIgnoreParentScale(true)
    end
    self:ClearAllPoints()
    local yOff = KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyPlateYOffset or 0
    self:SetPoint("CENTER", nameplate, "CENTER", 0, yOff)
    self:SetSize(10, 10)
    self:SetFrameLevel(nameplate:GetFrameLevel() + 1)
    self:Show()

    PixelSize(self.health, GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight())
    ApplyFriendlyHealthAnchor(self)

    -- Suppress Blizzard UF via reparenting (immediate, no OnUpdate needed)
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
        self.health:SetStatusBarColor(NPC_COLOR_R, NPC_COLOR_G, NPC_COLOR_B)
        self.name:SetTextColor(GetFriendlyNPCNameColor())
    end

    SetFriendlyFSFont(self.name, UnitIsPlayer(unit) and GetFriendlyPlayerNameTextSize() or GetFriendlyNPCNameTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    SetFriendlyFSFont(self.hpText, GetFriendlyHealthTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    SetFriendlyFSFont(self.guild, GetFriendlyGuildTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    SetFriendlyFSFont(self.description, GetFriendlyNPCDescriptionTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    ApplyFriendlyBarTextAnchors(self)
    do
        local hr, hg, hb = GetFriendlyHealthTextColor()
        self.hpText:SetTextColor(hr, hg, hb, 1)
        local gr, gg, gb = GetFriendlyGuildColor()
        self.guild:SetTextColor(gr, gg, gb, 1)
        local dr, dg, db = GetFriendlyNPCDescriptionColor()
        self.description:SetTextColor(dr, dg, db, 1)
    end

    self:UpdateHealth()
    self:UpdateName()
    self:UpdateRaidIcon()
    self:UpdatePvPMarker()
    self:ApplyTarget()
    if ns.ApplyHealthBarTexture then ns.ApplyHealthBarTexture(self) end
end

function FriendlyFrame:ClearUnit()
    self:SetScript("OnUpdate", nil)
    self._ktStableLayoutFrames = nil
    self._ktApplyingStableLayout = nil
    self:UnregisterAllEvents()
    self.name:SetText("")
    if self.level then self.level:SetText(""); self.level:Hide() end
    if self.guild then self.guild:SetText(""); self.guild:Hide() end
    if self.description then self.description:SetText(""); self.description:Hide() end
    -- Restore Blizzard UF before clearing our reference
    if self.unit then RestoreBlizzardUF(self.unit) end
    self.unit = nil
    self.nameplate = nil
    if self.SetIgnoreParentScale then
        self:SetIgnoreParentScale(true)
    end
    self.glow:Hide()
    self.highlight:Hide()
    self.raidFrame:Hide()
    self.pvpFrame:Hide()
    self.leftArrow:Hide()
    self.rightArrow:Hide()
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
    local markerIndex = GetRaidTargetIndex and GetRaidTargetIndex(self.unit)
    if pos == "none" or not markerIndex then
        self.raidFrame:Hide()
        return
    end

    SetRaidTargetIconTexture(self.raid, markerIndex)
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

function FriendlyFrame:UNIT_HEALTH() self:UpdateHealth() end

function FriendlyFrame:UNIT_NAME_UPDATE() self:UpdateName() end

function FriendlyFrame:UNIT_LEVEL() self:UpdateLevel() end

function FriendlyFrame:UNIT_CLASSIFICATION_CHANGED() self:UpdatePvPMarker() end

-------------------------------------------------------------------------------
--  Friendly event manager (target, mouseover, raid icons)
--  Only registered when friendly plates are active -- zero CPU when disabled.
-------------------------------------------------------------------------------
local friendlyManager = CreateFrame("Frame")
local friendlyManagerRegistered = false
local friendlyMouseoverPlate = nil
local friendlyTargetPlate = nil

local RegisterFriendlyManager   -- forward declaration
local UnregisterFriendlyManager -- forward declaration

-------------------------------------------------------------------------------
--  Add / Remove helpers
-------------------------------------------------------------------------------
local function ClearAllFriendlyPlates()
    for unit, plate in pairs(friendlyPlates) do
        plate:ClearUnit()
        friendlyFrameCache:Release(plate)
        friendlyPlates[unit] = nil
    end
    wipe(ns.friendlyPlatesByNameplate)
    friendlyMouseoverPlate = nil
    friendlyTargetPlate = nil
end

local function TryAddFriendlyPlate(unit)
    -- Auto-enable on first call if DB says we should be active but the
    -- runtime flag hasn't been set yet (happens when NAME_PLATE_UNIT_ADDED
    -- fires before PLAYER_LOGIN).
    if not friendlyEnabled then
        if IsFriendlyEnabled() then
            friendlyEnabled = true
            RegisterFriendlyManager()
        else
            return
        end
    end
    if UnitCanAttack("player", unit) then return end
    if UnitIsUnit(unit, "player") then return end
    -- Skip non-player units unless friendly NPC plates are enabled
    if not IsFriendlyBarForUnit(unit) then return end
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return end
    if friendlyPlates[unit] then return end

    local plate = friendlyFrameCache:Acquire()
    if not plate._mixedIn then
        Mixin(plate, FriendlyFrame)
        plate._mixedIn = true
    end
    friendlyPlates[unit] = plate
    ns.friendlyPlatesByNameplate[nameplate] = plate
    plate:SetUnit(unit, nameplate)
end
ns.TryAddFriendlyPlate = TryAddFriendlyPlate

function ns.RemoveFriendlyPlate(unit)
    local plate = friendlyPlates[unit]
    if not plate then return end
    if friendlyMouseoverPlate == plate then
        friendlyMouseoverPlate = nil
    end
    if friendlyTargetPlate == plate then
        friendlyTargetPlate = nil
    end
    if plate.nameplate then
        ns.friendlyPlatesByNameplate[plate.nameplate] = nil
    end
    plate:ClearUnit()
    friendlyFrameCache:Release(plate)
    friendlyPlates[unit] = nil
end

-- Variante sin restaurar el UF de Blizzard; se usa al promover friendly → enemy
-- para que HideBlizzardFrame del plate enemigo tome el control sin parpadeo.
function ns.RemoveFriendlyPlateNoRestore(unit)
    local plate = friendlyPlates[unit]
    if not plate then return end

    -- Limpiar referencias globales primero para que ningún evento posterior
    -- encuentre un plate zombie
    friendlyPlates[unit] = nil
    modifiedUFs[unit] = nil

    if plate.nameplate then
        ns.friendlyPlatesByNameplate[plate.nameplate] = nil
    end

    -- Descartar punteros de selección/mouseover si apuntan a este plate
    if friendlyTargetPlate == plate then friendlyTargetPlate = nil end
    if friendlyMouseoverPlate == plate then friendlyMouseoverPlate = nil end

    -- Detener eventos y limpiar estado visual
    plate:UnregisterAllEvents()
    plate:Hide()
    plate.unit = nil
    plate.nameplate = nil
    plate.name:SetText("")
    if plate.description then plate.description:SetText(""); plate.description:Hide() end
    plate.glow:Hide()
    plate.highlight:Hide()
    plate.raidFrame:Hide()
    plate.pvpFrame:Hide()
    plate.leftArrow:Hide()
    plate.rightArrow:Hide()

    -- Reparentar y devolver al pool
    plate:ClearAllPoints()
    plate:SetParent(UIParent)
    friendlyFrameCache:Release(plate)
end

-------------------------------------------------------------------------------
--  Friendly event manager function definitions
-------------------------------------------------------------------------------
-- Eventos que el manager necesita; definidos una vez para registro y des-registro
local friendlyManagerEvents = {
    "PLAYER_TARGET_CHANGED",
    "UPDATE_MOUSEOVER_UNIT",
    "RAID_TARGET_UPDATE",
}

function RegisterFriendlyManager()
    if friendlyManagerRegistered then return end
    for _, ev in ipairs(friendlyManagerEvents) do
        friendlyManager:RegisterEvent(ev)
    end
    friendlyManagerRegistered = true
end

function UnregisterFriendlyManager()
    if not friendlyManagerRegistered then return end
    friendlyManager:UnregisterAllEvents()
    friendlyManagerRegistered = false
end

friendlyManager:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_TARGET_CHANGED" then
        local targetNameplate = UnitExists("target") and C_NamePlate.GetNamePlateForUnit("target")
        local newTargetPlate = targetNameplate and ns.friendlyPlatesByNameplate[targetNameplate] or nil
        if friendlyTargetPlate and friendlyTargetPlate ~= newTargetPlate then
            friendlyTargetPlate:ApplyTarget()
        end
        if newTargetPlate then
            newTargetPlate:ApplyTarget()
        end
        friendlyTargetPlate = newTargetPlate
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if friendlyMouseoverPlate then
            friendlyMouseoverPlate.highlight:Hide()
            friendlyMouseoverPlate = nil
        end
        if UnitExists("mouseover") then
            local mouseoverNameplate = C_NamePlate.GetNamePlateForUnit("mouseover")
            local plate = mouseoverNameplate and ns.friendlyPlatesByNameplate[mouseoverNameplate] or nil
            if plate then
                plate.highlight:Show()
                friendlyMouseoverPlate = plate
            end
        end
    elseif event == "RAID_TARGET_UPDATE" then
        for _, plate in pairs(friendlyPlates) do plate:UpdateRaidIcon() end
    end
end)

-------------------------------------------------------------------------------
--  Live refresh of friendly plate Y offset
-------------------------------------------------------------------------------
function ns.RefreshFriendlyPlateYOffset()
    local yOff = KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyPlateYOffset or 0
    for _, plate in pairs(friendlyPlates) do
        if plate.nameplate then
            plate:ClearAllPoints()
            plate:SetPoint("CENTER", plate.nameplate, "CENTER", 0, yOff)
        end
    end
end

-------------------------------------------------------------------------------
--  Live refresh of friendly plate size (height / width)
-------------------------------------------------------------------------------
function ns.RefreshFriendlyPlateSize()
    local h = GetFriendlyHealthBarHeight()
    local w = GetFriendlyHealthBarWidth()
    for _, plate in pairs(friendlyPlates) do
        PixelSize(plate.health, w, h)
        ApplyFriendlyHealthAnchor(plate)
        ApplyFriendlyBarTextAnchors(plate)
        if plate.UpdateHealthMarkers then
            plate:UpdateHealthMarkers()
        end
    end
end

function FriendlyFrame:RefreshPixelPerfectLayout()
    if not (self.unit and self.nameplate) then return end

    local yOff = KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyPlateYOffset or 0
    self:ClearAllPoints()
    self:SetPoint("CENTER", self.nameplate, "CENTER", 0, yOff)
    self:SetSize(10, 10)
    PixelSize(self.health, GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight())
    ApplyFriendlyHealthAnchor(self)
    ApplyFriendlyBarTextAnchors(self)
    self:UpdateLevel()
    self:UpdateRaidIcon()
    self:UpdatePvPMarker()
    self:UpdateHealthMarkers()
end
function ns.RefreshFriendlyPixelPerfectLayout()
    for _, plate in pairs(friendlyPlates) do
        plate:RefreshPixelPerfectLayout()
    end
end

function ns.RefreshFriendlyHealthText()
    for _, plate in pairs(friendlyPlates) do
        plate:UpdateHealth()
    end
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

function ns.RefreshFriendlyTextStyle()
    for _, plate in pairs(friendlyPlates) do
        if plate.name then
            local size = (plate.unit and UnitIsPlayer(plate.unit)) and GetFriendlyPlayerNameTextSize() or
                GetFriendlyNPCNameTextSize()
            SetFriendlyFSFont(plate.name, size, (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
        end
        if plate.hpText then
            SetFriendlyFSFont(plate.hpText, GetFriendlyHealthTextSize(),
                (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
            local hr, hg, hb = GetFriendlyHealthTextColor()
            plate.hpText:SetTextColor(hr, hg, hb, 1)
        end
        if plate.guild then
            SetFriendlyFSFont(plate.guild, GetFriendlyGuildTextSize(),
                (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
            local gr, gg, gb = GetFriendlyGuildColor()
            plate.guild:SetTextColor(gr, gg, gb, 1)
        end
        if plate.description then
            SetFriendlyFSFont(plate.description, GetFriendlyNPCDescriptionTextSize(),
                (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
            local dr, dg, db = GetFriendlyNPCDescriptionColor()
            plate.description:SetTextColor(dr, dg, db, 1)
        end
        ApplyFriendlyHealthAnchor(plate)
        ApplyFriendlyBarTextAnchors(plate)
        if plate.UpdateName then plate:UpdateName() end
        if plate.UpdateHealth then plate:UpdateHealth() end
    end

    for _, overlay in pairs(npcOverlays) do
        if overlay and overlay.unit then
            UpdateStableOverlayContent(overlay)
            ApplyStableOverlayLayout(overlay, true)
        end
    end
end

function ns.RefreshFriendlyNameOnlyOverlayLayout()
    for _, overlay in pairs(npcOverlays) do
        if overlay and overlay.unit then
            UpdateStableOverlayContent(overlay)
            ApplyStableOverlayLayout(overlay, true)
        end
    end
end

-- Options historically call this name after font changes.
ns.RefreshFriendlyFontOverride = ns.RefreshFriendlyNameOnlyOverlayLayout
-------------------------------------------------------------------------------
--  System enable / disable  (called from toggle setValue and on login)
-------------------------------------------------------------------------------
function ns.UpdateFriendlyNameplateSystem()
    local db = KullThranUINameplatesDB or {}
    local hasBars = IsFriendlyEnabled()
    local showPlayers
    local showNPCs
    if ns.ShouldShowFriendlyNameplates then
        showPlayers = ns.ShouldShowFriendlyNameplates(true)
        showNPCs = ns.ShouldShowFriendlyNameplates(false)
    else
        showPlayers = db.showFriendlyPlayers ~= false
        showNPCs = db.showFriendlyNPCs == true
    end
    local playerNameOnly = showPlayers and FriendlyNameOnlyValue(true)
    local npcNameOnly = showNPCs and FriendlyNameOnlyValue(false)
    local hasNameOnly = playerNameOnly or npcNameOnly

    SetFriendlyAuraCVars(hasBars or hasNameOnly)

    if not (showPlayers and playerNameOnly) then
        for nameplate in pairs(friendlyPlayerPvPMarkers) do
            HideFriendlyPlayerPvPMarker(nameplate)
        end
    end

    if ns.QueueNameplateCVar then
        ns.QueueNameplateCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", playerNameOnly and 1 or 0)
        ns.QueueNameplateCVar("nameplateShowFriendlyPlayers", showPlayers and 1 or 0)
        ns.QueueNameplateCVar("nameplateShowFriends", showPlayers and 1 or 0)
        ns.QueueNameplateCVar("nameplateShowFriendlyNPCs", showNPCs and 1 or 0)
        ns.QueueNameplateCVar("nameplateShowFriendlyNpcs", showNPCs and 1 or 0)
        -- Quest givers use Blizzard's special-NPC state for their native ? marker.
        ns.QueueNameplateCVar("UnitNameFriendlySpecialNPCName", showNPCs and 1 or 0)
    end

    -- Remove custom bars for units that have just switched to name-only.
    for unit in pairs(friendlyPlates) do
        if not IsFriendlyBarForUnit(unit) then
            ns.RemoveFriendlyPlate(unit)
        end
    end

    local function SweepStableFriendlyOverlays()
        local allPlates = GetAccessibleNamePlates()
        if not allPlates then return end
        for _, nameplate in ipairs(allPlates) do
            local unit = nameplate.namePlateUnitToken
            if unit and IsFriendlyNameOnlyForUnit(unit) then
                SuppressNPCNameplate(nameplate, unit)
            elseif nameOnlyNPCSuppressed[nameplate] then
                RestoreNPCNameplate(nameplate, unit)
            end
        end
    end

    -- Restore overlays before creating a custom bar for the same unit.
    SweepStableFriendlyOverlays()

    if hasBars then
        friendlyEnabled = true
        RegisterFriendlyManager()
        local allPlates = GetAccessibleNamePlates()
        if allPlates then
            for _, nameplate in ipairs(allPlates) do
                local unit = nameplate.namePlateUnitToken
                if unit then TryAddFriendlyPlate(unit) end
            end
        end
        if ns.pendingUnits then
            for unit in pairs(ns.pendingUnits) do TryAddFriendlyPlate(unit) end
        end
    else
        friendlyEnabled = false
        UnregisterFriendlyManager()
        ClearAllFriendlyPlates()
    end

    -- A delayed sweep catches plates whose unit token becomes queryable after
    -- PLAYER_LOGIN or after Blizzard recycles a nameplate frame.
    SweepStableFriendlyOverlays()
    C_Timer.After(0.1, SweepStableFriendlyOverlays)
    C_Timer.After(0.5, SweepStableFriendlyOverlays)
end

-------------------------------------------------------------------------------
--  Bootstrap — wait for DB then enable system
--  PLAYER_LOGIN enables the system; PLAYER_ENTERING_WORLD does a follow-up
--  sweep because some friendly nameplates may not be queryable yet at
--  PLAYER_LOGIN time (the world isn't fully loaded).
-------------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        ns.UpdateFriendlyNameplateSystem()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.UpdateFriendlyNameplateSystem()
        -- Sweep every zone transition / reload to pick up any plates that
        -- were missed during the initial enable or that appeared between
        -- PLAYER_LOGIN and the world being fully rendered.
        C_Timer.After(0, function()
            if friendlyEnabled then
                local allPlates = GetAccessibleNamePlates()
                if allPlates then
                    for _, nameplate in ipairs(allPlates) do
                        local u = nameplate.namePlateUnitToken
                        if u then TryAddFriendlyPlate(u) end
                    end
                end
            end
            -- Name-only NPC sweep: suppress health bars and color names
            if IsNameOnlyMode(u) then
                local allPlates = GetAccessibleNamePlates()
                if allPlates then
                    for _, nameplate in ipairs(allPlates) do
                        local u = nameplate.namePlateUnitToken
                        if u and not UnitCanAttack("player", u) and not UnitIsUnit(u, "player") and not UnitIsPlayer(u) then
                            SuppressNPCNameplate(nameplate, u)
                        end
                    end
                end
            end
        end)
    end
end)

-------------------------------------------------------------------------------
--  Exported API (NAME_PLATE_UNIT_ADDED/REMOVED)
--  These wrap the new overlay system so the main file doesn't need to change.
-------------------------------------------------------------------------------
function ns.TryColorFriendlyNPCName(unit, nameplate)
    -- In name-only mode, NPC overlay handles coloring automatically
    -- (SuppressNPCNameplate is called from OnNamePlateAdded hook)
end

function ns.TrySuppressNPCHealthBar(unit, nameplate)
    -- The early Blizzard hook normally performs this suppression first, but
    -- NAME_PLATE_UNIT_ADDED must be able to enforce it too. Frames are
    -- recycled and the main handler may run after another addon restored the
    -- native UnitFrame.
    if not (unit and nameplate) then return end
    if not (unit and IsNameOnlyMode(unit)) or UnitIsPlayer(unit) then return end
    if UnitIsPlayer(unit) or UnitCanAttack('player', unit) then return end
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
function ns.RestoreFriendlyNPCNameColor(nameplate)
    if not nameplate then return end
    local tok = nameplate.namePlateUnitToken
    -- Solo procesar NPCs (los jugadores no tienen overlay propio)
    if not tok or UnitIsPlayer(tok) then return end
    RestoreNPCNameplate(nameplate, tok)
end

function ns.RestoreNPCHealthBar(nameplate)
    local unit = nameplate and nameplate.namePlateUnitToken
    if unit and not UnitIsPlayer(unit) then
        RestoreNPCNameplate(nameplate, unit)
    end
end
