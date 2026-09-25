local addon, ns = ...

if not ns then return end

local function GetHealthBarHeight(...)
    local getter = ns.GetHealthBarHeight
    return getter and getter(...) or 30
end
local function GetFriendlyHealthBarHeight(...)
    local getter = ns.GetFriendlyHealthBarHeight
    return getter and getter(...) or 17
end
local function GetFriendlyHealthBarWidth(...)
    local getter = ns.GetFriendlyHealthBarWidth
    return getter and getter(...) or 150
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

local function ConfigureMovingFontRendering(fs)
    if not fs then return end
    if fs.SetSnapToPixelGrid then
        fs:SetSnapToPixelGrid(false)
    end
    if fs.SetTexelSnappingBias then
        fs:SetTexelSnappingBias(0)
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

local FRIENDLY_BAR_W = 150
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

local function FriendlyLevelValue(key)
    local db = KullThranUINameplatesDB
    local defaults = (ns and ns.defaults) or _G.KullThranUINameplatesDefaults or {}
    if db and db[key] ~= nil then return db[key] end
    return defaults[key]
end

local function HideFriendlyLevelText(level)
    if not level then return end
    if ns.ApplyNameplateLevelTextStyle then
        pcall(ns.ApplyNameplateLevelTextStyle, level)
    end
    pcall(level.SetText, level, "")
    level:Hide()
end

local function UpdateFriendlyLevelText(level, name, health, unit)
    if not level then return end
    if not unit or not ns.ShouldShowNameplateLevel or not ns.ShouldShowNameplateLevel(true) then
        HideFriendlyLevelText(level)
        return
    end
    local levelText = ns.GetNameplateLevelText and ns.GetNameplateLevelText(unit)
    if not levelText then
        HideFriendlyLevelText(level)
        return
    end
    if ns.ApplyNameplateLevelTextStyle then ns.ApplyNameplateLevelTextStyle(level) end
    level:SetText(levelText)
    local width = level.GetUnboundedStringWidth and level:GetUnboundedStringWidth()
        or level.GetStringWidth and level:GetStringWidth() or 0
    level:SetWidth(math.max(20, tonumber(width) or 0) + 4)
    level:SetHeight(math.max(16, (tonumber(FriendlyLevelValue("levelFontSize")) or 11) + 6))
    if ns.PositionNameplateLevelText then
        ns.PositionNameplateLevelText(level, name, health, true,
            FriendlyLevelValue("levelXOffset") or 24,
            FriendlyLevelValue("levelYOffset") or 4)
    end
    level:Show()
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
    return FriendlyDBVal("friendlyPlayerNameTextSize", 13)
end

local function GetFriendlyGuildTextSize()
    return FriendlyDBVal("friendlyGuildTextSize", 12)
end

local function GetFriendlyHealthTextSize()
    return FriendlyDBVal("friendlyHealthTextSize", 10)
end

local function GetFriendlyNPCNameTextSize()
    return FriendlyDBVal("friendlyNPCNameTextSize", 13)
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

local function ApplyAlignedTextLayout(fs, anchor, yOffset, alignment)
    if not fs then return end
    local align = alignment or "center"
    fs:ClearAllPoints()
    fs:SetWidth(0)
    fs:SetHeight(0)
    fs:SetJustifyH(GetAlignmentJustify(align))
    if align == "left" then
        fs:SetPoint("LEFT", anchor, "LEFT", 0, yOffset or 0)
    elseif align == "right" then
        fs:SetPoint("RIGHT", anchor, "RIGHT", 0, yOffset or 0)
    else
        fs:SetPoint("CENTER", anchor, "CENTER", 0, yOffset or 0)
    end
end

local function GetFriendlyHealthAnchorYOffset(plate)
    local offset = FRIENDLY_PLATE_Y_OFFSET
    if plate and plate.guild and plate.guild.IsShown and plate.guild:IsShown() then
        offset = offset - (GetFriendlyGuildTextSize() + 6)
    end
    return offset
end

local function ApplyFriendlyHealthAnchor(plate)
    if not (plate and plate.health) then return end
    plate.health:ClearAllPoints()
    plate.health:SetPoint("CENTER", plate, "CENTER", 0, GetFriendlyHealthAnchorYOffset(plate))
end

local function ApplyFriendlyBarTextAnchors(plate)
    if not plate or not plate.health then return end
    local width = math.max(GetFriendlyHealthBarWidth(), 140)
    local align = (plate.unit and UnitIsPlayer(plate.unit)) and GetFriendlyPlayerNameAlignment() or
        GetFriendlyNPCNameAlignment()
    if plate.name then
        plate.name:ClearAllPoints()
        plate.name:SetWidth(width)
        plate.name:SetJustifyH(GetAlignmentJustify(align))
        if align == "left" then
            plate.name:SetPoint("BOTTOMLEFT", plate.health, "TOPLEFT", 0, 4)
        elseif align == "right" then
            plate.name:SetPoint("BOTTOMRIGHT", plate.health, "TOPRIGHT", 0, 4)
        else
            plate.name:SetPoint("BOTTOM", plate.health, "TOP", 0, 4)
        end
    end
    if plate.guild and plate.name then
        plate.guild:ClearAllPoints()
        plate.guild:SetWidth(width)
        plate.guild:SetJustifyH(GetAlignmentJustify(align))
        if align == "left" then
            plate.guild:SetPoint("TOPLEFT", plate.name, "BOTTOMLEFT", 0, -1)
        elseif align == "right" then
            plate.guild:SetPoint("TOPRIGHT", plate.name, "BOTTOMRIGHT", 0, -1)
        else
            plate.guild:SetPoint("TOP", plate.name, "BOTTOM", 0, -1)
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
        nameFS:SetPoint("LEFT", uf, "LEFT", 0, 0)
    elseif align == "right" then
        nameFS:SetPoint("RIGHT", uf, "RIGHT", 0, 0)
    else
        nameFS:SetPoint("CENTER", uf, "CENTER", 0, 0)
    end
end

local ApplyFontToNameText
local IsNameOnlyMode

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
end

local function EnforceFriendlyPlayerNameOnly(nameplate, unit)
    if not (nameplate and IsNameOnlyMode()) then return end
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

local function IsFriendlyEnabled()
    return KullThranUINameplatesDB and (KullThranUINameplatesDB.friendlyNameOnly == false)
end

IsNameOnlyMode = function()
    local db = KullThranUINameplatesDB
    return not db or (db.friendlyNameOnly ~= false)
end

local function UpdateFriendlyNameOnlyLevel(nameplate, unit)
    local uf = nameplate and nameplate.UnitFrame
    local name = uf and uf.name
    if not (uf and name) or not unit or not UnitIsPlayer(unit) or not IsNameOnlyMode() then
        HideFriendlyLevelText(uf and uf._ktFriendlyLevel)
        return
    end
    local level = uf._ktFriendlyLevel
    if not level then
        level = uf:CreateFontString(nil, "OVERLAY")
        if ns.ApplyNameplateLevelTextStyle then
            ns.ApplyNameplateLevelTextStyle(level)
        end
        level:SetJustifyH("LEFT")
        level:SetWordWrap(false)
        level:SetMaxLines(1)
        uf._ktFriendlyLevel = level
    end
    UpdateFriendlyLevelText(level, name, uf.healthBar or uf.HealthBar or nameplate, unit)
end

function ns.RefreshFriendlyNameOnlyLevels()
    local plates = GetAccessibleNamePlates(true)
    for index = 1, #plates do
        local nameplate = plates[index]
        local unit = nameplate and nameplate.namePlateUnitToken
        UpdateFriendlyNameOnlyLevel(nameplate, unit)
    end
    if ns.RefreshFriendlyNPCLevels then
        ns.RefreshFriendlyNPCLevels()
    end
end

function ns.RefreshFriendlyNameOnlyLevel(nameplate, unit)
    UpdateFriendlyNameOnlyLevel(nameplate, unit or (nameplate and nameplate.namePlateUnitToken))
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
    -- Removed SetSnapToPixelGrid(false) and SetTexelSnappingBias(0) to prevent blurry text when moving
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
    UpdateFriendlyNameOnlyLevel(nameplate, nameplate.namePlateUnitToken)
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
    if not IsNameOnlyMode() then return end
    -- Recopilar placas elegibles antes de aplicar; evita re-evaluar dentro del bucle
    local plates = GetAccessibleNamePlates(true)
    local n = #plates
    for idx = 1, n do
        local np = plates[idx]
        local tok = np.namePlateUnitToken
        if tok and not UnitIsUnit(tok, "player") and not UnitCanAttack("player", tok) then
            ApplyFontToNameplate(np)
        end
    end
end

-------------------------------------------------------------------------------
--  Name-only NPC overlay
--  In name-only mode, Blizzard's name FontString is restricted and can't be
--  resized.  Instead of trying to modify it, we fully suppress the Blizzard
--  UnitFrame (reparent to hidden frame) and render our own name FontString
--  on the nameplate.  This gives us full control over width, color, and font.
-------------------------------------------------------------------------------
local npcOverlays = {}    -- nameplate → overlay frame
local npcOverlayPool = {} -- recycled overlay frames

-- Name-only mode: optional guild line below friendly player names.
local playerGuildLines = {} -- nameplate → FontString
local function HidePlayerGuildLine(nameplate)
    local fs = nameplate and playerGuildLines[nameplate]
    if fs and fs.Hide then fs:Hide() end
end
local function UpdatePlayerGuildLine(nameplate, unit)
    if not (nameplate and unit) then return end
    if not IsNameOnlyMode() then HidePlayerGuildLine(nameplate); return end
    if not ShouldShowFriendlyGuild() then HidePlayerGuildLine(nameplate); return end
    if UnitCanAttack("player", unit) then HidePlayerGuildLine(nameplate); return end
    if UnitIsUnit(unit, "player") then HidePlayerGuildLine(nameplate); return end
    if not UnitIsPlayer(unit) then HidePlayerGuildLine(nameplate); return end

    local uf = nameplate.UnitFrame
    local nameFS = uf and uf.name
    if not (nameFS and nameFS.GetFont) then HidePlayerGuildLine(nameplate); return end

    local guildName = GetGuildInfo and GetGuildInfo(unit)
    if issecretvalue and issecretvalue(guildName) then
        HidePlayerGuildLine(nameplate)
        return
    end
    if not guildName or guildName == "" then HidePlayerGuildLine(nameplate); return end

    local fs = playerGuildLines[nameplate]
    if not fs then
        fs = (uf or nameplate):CreateFontString(nil, "OVERLAY")
        fs:SetWordWrap(false)
        fs:SetMaxLines(1)
        fs:SetTextColor(1, 1, 1, 1)
        playerGuildLines[nameplate] = fs
    end

    fs:SetFont((ns and ns.GetFont and ns.GetFont()) or "Fonts\\FRIZQT__.TTF",
        GetFriendlyGuildTextSize(),
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    if KT and KT.EnableTextFontFallback then
        KT:EnableTextFontFallback(fs, (ns and ns.GetFont and ns.GetFont()) or 'Fonts\\FRIZQT__.TTF')
    end
    local _, _, flags = nameFS:GetFont()
    if not ns or not ns.GetNPUseShadow or ns.GetNPUseShadow() then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
    end
    -- Removed snapping bias to prevent blur

    local align = GetFriendlyPlayerNameAlignment()
    fs:ClearAllPoints()
    fs:SetWidth(math.max(GetFriendlyHealthBarWidth(), 140))
    fs:SetJustifyH(GetAlignmentJustify(align))
    if align == "left" then
        fs:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -1)
    elseif align == "right" then
        fs:SetPoint("TOPRIGHT", nameFS, "BOTTOMRIGHT", 0, -1)
    else
        fs:SetPoint("TOP", nameFS, "BOTTOM", 0, -1)
    end
    local r, g, b = GetFriendlyGuildColor()
    fs:SetTextColor(r, g, b, 1)
    fs:SetText("<" .. guildName .. ">")
    fs:Show()
end

local function GetNPCNameColor(unit)
    -- UnitReaction: 1-3 = hostile, 4 = neutral, 5+ = friendly
    local reaction = RawUnitAPI.UnitReaction and RawUnitAPI.UnitReaction(unit, "player")
    if not IsAccessible(reaction) then reaction = nil end
    if reaction and reaction == 4 then
        -- Neutral: yellow
        return 0.9, 0.7, 0.0
    end
    -- Friendly NPC
    return GetFriendlyNPCNameColor()
end

local function AcquireOverlay()
    local overlay = table.remove(npcOverlayPool)
    if overlay then return overlay end
    overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetSize(1, 1)
    overlay.name = overlay:CreateFontString(nil, "OVERLAY")
    SetFriendlyFSFont(overlay.name, 9, "")
    overlay.level = overlay:CreateFontString(nil, "OVERLAY")
    if ns.ApplyNameplateLevelTextStyle then ns.ApplyNameplateLevelTextStyle(overlay.level) end
    overlay.level:SetJustifyH("LEFT")
    overlay.level:SetWordWrap(false)
    overlay.level:SetMaxLines(1)
    overlay.level:Hide()
    ConfigureMovingFontRendering(overlay.name)
    overlay.name:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    overlay.name:SetShadowOffset(1, -1)
    overlay.name:SetShadowColor(0, 0, 0, 1)
    -- Removed snapping bias to prevent blur
    return overlay
end

local NPC_OVERLAY_FONT_SIZE = 13
local NPC_OVERLAY_Y_OFFSET = 5 -- positive = lower on screen (closer to character)

local function ApplyFriendlyNPCOverlayTextAnchors(overlay)
    if not (overlay and overlay.name) then return end
    ApplyAlignedTextLayout(overlay.name, overlay, 0, GetFriendlyNPCNameAlignment())
end

local function ShowNPCOverlay(nameplate, unit)
    if npcOverlays[nameplate] then return end
    local overlay = AcquireOverlay()
    overlay:SetParent(nameplate)
    overlay:ClearAllPoints()
    overlay:SetPoint("CENTER", nameplate, "CENTER", 0, -NPC_OVERLAY_Y_OFFSET)
    overlay:SetFrameLevel(nameplate:GetFrameLevel() + 5)
    overlay:Show()
    -- Set name text
    local unitName = UnitName(unit) or ""
    overlay.name:SetText(unitName)
    overlay.name:SetWidth(0)
    overlay.name:SetWordWrap(false)
    overlay.name:SetNonSpaceWrap(false)
    overlay.name:SetMaxLines(1)
    overlay.name:SetHeight(0)
    -- Apply our font
    local font = (ns and ns.GetFont and ns.GetFont()) or "Fonts\\FRIZQT__.TTF"
    overlay.name:SetFont(font, GetFriendlyNPCNameTextSize() or NPC_OVERLAY_FONT_SIZE,
        (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
    ConfigureMovingFontRendering(overlay.name)
    if not ns or not ns.GetNPUseShadow or ns.GetNPUseShadow() then
        overlay.name:SetShadowOffset(1, -1)
        overlay.name:SetShadowColor(0, 0, 0, 1)
    else
        overlay.name:SetShadowOffset(0, 0)
    end
    -- Removed snapping bias to prevent blur
    -- Color based on reaction
    local r, g, b = GetNPCNameColor(unit)
    overlay.name:SetTextColor(r, g, b)
    ApplyFriendlyNPCOverlayTextAnchors(overlay)
    UpdateFriendlyLevelText(overlay.level, overlay.name, nameplate, unit)
    overlay.unit = unit
    -- Listen for name updates (server may not have sent the name yet)
    overlay:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    overlay:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_NAME_UPDATE" then
            local updatedName = UnitName(self.unit) or ""
            self.name:SetText(updatedName)
            UpdateFriendlyLevelText(self.level, self.name, self:GetParent(), self.unit)
        end
    end)
    npcOverlays[nameplate] = overlay
end

local function HideNPCOverlay(nameplate)
    local overlay = npcOverlays[nameplate]
    if not overlay then return end
    -- Primero desvinculamos del registro para cortar eventos cuanto antes
    npcOverlays[nameplate] = nil
    overlay.unit = nil
    HideFriendlyLevelText(overlay.level)
    -- Limpieza visual: ocultar, desanclar y reparentar al contenedor neutro
    overlay:UnregisterAllEvents()
    overlay:ClearAllPoints()
    overlay:SetParent(UIParent)
    overlay:Hide()
    -- Devolver al pool para reutilización
    npcOverlayPool[#npcOverlayPool + 1] = overlay
end

function ns.RefreshFriendlyNPCLevels()
    for nameplate, overlay in pairs(npcOverlays) do
        if overlay and overlay.unit then
            UpdateFriendlyLevelText(overlay.level, overlay.name, nameplate, overlay.unit)
        end
    end
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

    -- Health-bar mode: full UF suppression for players (and NPCs if enabled)
    if IsFriendlyEnabled() then
        if not UnitIsPlayer(unit) and not IsFriendlyNPCEnabled() then return end
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate then
            SuppressBlizzardUF(unit, nameplate)
        end
        return
    end

    -- Name-only mode: suppress Blizzard UF and show our own name overlay for NPCs
    if IsNameOnlyMode() and IsFriendlyNPCEnabled() and not UnitIsPlayer(unit) then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate then
            SuppressNPCNameplate(nameplate, unit)
        end
    end

    -- Name-only mode (players): remove Blizzard's width constraint on the
    -- name FontString so long names are never truncated with "...".
    if IsNameOnlyMode() and UnitIsPlayer(unit) then
        if nameplate and nameplate.UnitFrame and nameplate.UnitFrame.name then
            local nameFS = nameplate.UnitFrame.name
            RestoreFriendlyPlayerNameText(nameplate, unit)
            EnforceFriendlyPlayerNameOnly(nameplate, unit)
            -- Hook SetWidth so Blizzard can't re-apply a constraint later
            if not hookedNameFonts[nameFS] then
                hookedNameFonts[nameFS] = true
                local guard = false
                local function KeepNameAutoSized(self)
                    if guard then return end
                    if not IsNameOnlyMode() then return end
                    -- Do not inspect incoming dimensions: protected plates may
                    -- supply secret values. Constants are safe display writes.
                    guard = true
                    self:SetWidth(0)
                    self:SetHeight(0)
                    guard = false
                end
                hooksecurefunc(nameFS, "SetWidth", KeepNameAutoSized)
                if nameFS.SetSize then
                    hooksecurefunc(nameFS, "SetSize", KeepNameAutoSized)
                end
                hooksecurefunc(nameFS, "SetFont", function(self)
                    if self._ktApplyingFont or self._ktTextFontApplying or not IsNameOnlyMode() then return end
                    ApplyFontToNameText(self)
                end)
                hooksecurefunc(nameFS, "SetFontObject", function(self)
                    if self._ktApplyingFont or self._ktTextFontApplying or not IsNameOnlyMode() then return end
                    ApplyFontToNameText(self)
                end)
            end

            local showFriendly = KullThranUINameplatesDB and KullThranUINameplatesDB.showFriendlyPlayers ~= false
            if showFriendly then
                UpdatePlayerGuildLine(nameplate, unit)
                UpdateFriendlyNameOnlyLevel(nameplate, unit)
                C_Timer.After(0, function()
                    local np = C_NamePlate.GetNamePlateForUnit(unit)
                    if np then
                        RestoreFriendlyPlayerNameText(np, unit)
                        EnforceFriendlyPlayerNameOnly(np, unit)
                        UpdateFriendlyNameOnlyLevel(np, unit)
                        UpdatePlayerGuildLine(np, unit)
                    end
                end)
                C_Timer.After(0.1, function()
                    local np = C_NamePlate.GetNamePlateForUnit(unit)
                    if np then
                        RestoreFriendlyPlayerNameText(np, unit)
                        EnforceFriendlyPlayerNameOnly(np, unit)
                        UpdateFriendlyNameOnlyLevel(np, unit)
                        UpdatePlayerGuildLine(np, unit)
                    end
                end)
                C_Timer.After(0.5, function()
                    local np = C_NamePlate.GetNamePlateForUnit(unit)
                    if np then
                        RestoreFriendlyPlayerNameText(np, unit)
                        EnforceFriendlyPlayerNameOnly(np, unit)
                        UpdateFriendlyNameOnlyLevel(np, unit)
                        UpdatePlayerGuildLine(np, unit)
                    end
                end)
            end
        end
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
        HidePlayerGuildLine(nameplate)
    end
    if modifiedUFs[unit] then
        RestoreBlizzardUF(unit)
    end
end)

-------------------------------------------------------------------------------
--  Frame pool for custom friendly plates
-------------------------------------------------------------------------------
local friendlyFrameCache = CreateFramePool("Frame", UIParent, nil, nil, false, function(plate)
    plate:SetFlattensRenderLayers(true)

    plate.health = CreateFrame("StatusBar", nil, plate)
    plate.health:SetFrameLevel(10)
    plate.health:SetPoint("CENTER", plate, "CENTER", 0, FRIENDLY_PLATE_Y_OFFSET)
    plate.health:SetSize(GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight())
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
    if ns.ApplyNameplateLevelTextStyle then ns.ApplyNameplateLevelTextStyle(plate.level) end
    plate.level:SetJustifyH("LEFT")
    plate.level:SetWordWrap(false)
    plate.level:SetMaxLines(1)
    plate.level:SetWidth(24)
    plate.level:SetHeight(18)
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
end)

-------------------------------------------------------------------------------
--  FriendlyFrame mixin
-------------------------------------------------------------------------------
local FriendlyFrame = {}

function FriendlyFrame:SetUnit(unit, nameplate)
    self.unit = unit
    self.nameplate = nameplate
    self:SetParent(nameplate)
    if self.SetIgnoreParentScale then
        self:SetIgnoreParentScale(true)
    end
    self:ClearAllPoints()
    -- Single center anchor to prevent pixel shimmer when nameplate bounces
    local yOff = KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyPlateYOffset or 0
    self:SetPoint("CENTER", nameplate, "CENTER", 0, yOff)
    self:SetSize(1, 1)
    self:SetFrameLevel(nameplate:GetFrameLevel() + 1)
    self:Show()

    self.health:SetSize(GetFriendlyHealthBarWidth(), GetFriendlyHealthBarHeight())
    ApplyFriendlyHealthAnchor(self)

    -- Suppress Blizzard UF via reparenting (immediate, no OnUpdate needed)
    SuppressBlizzardUF(unit, nameplate)

    self:RegisterUnitEvent("UNIT_HEALTH", unit)
    self:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    self:RegisterUnitEvent("UNIT_LEVEL", unit)

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
    ApplyFriendlyBarTextAnchors(self)
    do
        local hr, hg, hb = GetFriendlyHealthTextColor()
        self.hpText:SetTextColor(hr, hg, hb, 1)
        local gr, gg, gb = GetFriendlyGuildColor()
        self.guild:SetTextColor(gr, gg, gb, 1)
    end

    self:UpdateHealth()
    self:UpdateName()
    self:UpdateLevel()
    self:UpdateRaidIcon()
    self:ApplyTarget()
    if ns.ApplyHealthBarTexture then ns.ApplyHealthBarTexture(self) end
end

function FriendlyFrame:ClearUnit()
    self:UnregisterAllEvents()
    self.name:SetText("")
    HideFriendlyLevelText(self.level)
    if self.guild then self.guild:SetText(""); self.guild:Hide() end
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

    -- Fase 1: resolver valores de vida seg\u00fan el m\u00e9todo disponible
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

    -- Fase 2: texto de porcentaje — evaluar condiciones de mayor a menor prioridad
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
    ApplyFriendlyHealthAnchor(self)
    ApplyFriendlyBarTextAnchors(self)
    self:UpdateLevel()
end

function FriendlyFrame:UpdateLevel()
    UpdateFriendlyLevelText(self.level, self.name, self.health, self.unit)
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
    if not UnitIsPlayer(unit) and not IsFriendlyNPCEnabled() then return end
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
    HideFriendlyLevelText(plate.level)
    plate.glow:Hide()
    plate.highlight:Hide()
    plate.raidFrame:Hide()
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
        plate.health:SetSize(w, h)
        ApplyFriendlyHealthAnchor(plate)
        ApplyFriendlyBarTextAnchors(plate)
        if plate.UpdateLevel then plate:UpdateLevel() end
        if plate.UpdateHealthMarkers then
            plate:UpdateHealthMarkers()
        end
    end
end

function ns.RefreshFriendlyHealthText()
    for _, plate in pairs(friendlyPlates) do
        plate:UpdateHealth()
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
        if plate.level and ns.ApplyNameplateLevelTextStyle then
            ns.ApplyNameplateLevelTextStyle(plate.level)
        end
        if plate.guild then
            SetFriendlyFSFont(plate.guild, GetFriendlyGuildTextSize(),
                (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
            local gr, gg, gb = GetFriendlyGuildColor()
            plate.guild:SetTextColor(gr, gg, gb, 1)
        end
        ApplyFriendlyHealthAnchor(plate)
        ApplyFriendlyBarTextAnchors(plate)
        if plate.UpdateName then plate:UpdateName() end
        if plate.UpdateHealth then plate:UpdateHealth() end
    end

    for nameplate, overlay in pairs(npcOverlays) do
        if overlay and overlay.name then
            overlay.name:SetFont((ns and ns.GetFont and ns.GetFont()) or "Fonts\\FRIZQT__.TTF",
                GetFriendlyNPCNameTextSize() or NPC_OVERLAY_FONT_SIZE,
                (ns and ns.GetNPOutline and ns.GetNPOutline()) or "OUTLINE")
            ConfigureMovingFontRendering(overlay.name)
            if not ns or not ns.GetNPUseShadow or ns.GetNPUseShadow() then
                overlay.name:SetShadowOffset(1, -1)
                overlay.name:SetShadowColor(0, 0, 0, 1)
            else
                overlay.name:SetShadowOffset(0, 0)
            end
            local r, g, b = GetFriendlyNPCNameColor()
            overlay.name:SetTextColor(r, g, b, 1)
            ApplyFriendlyNPCOverlayTextAnchors(overlay)
        end
        if nameplate and overlay and overlay.unit then
            local updatedName = UnitName(overlay.unit) or ""
            overlay.name:SetText(updatedName)
        end
    end

    for nameplate, _ in pairs(playerGuildLines) do
        if nameplate and nameplate.namePlateUnitToken then
            UpdatePlayerGuildLine(nameplate, nameplate.namePlateUnitToken)
        end
    end

    if IsNameOnlyMode() then
        for _, nameplate in ipairs(GetAccessibleNamePlates(true)) do
            local unit = nameplate.namePlateUnitToken
            if unit and not UnitCanAttack("player", unit) and not UnitIsUnit(unit, "player") and UnitIsPlayer(unit) then
                ApplyFontToNameplate(nameplate)
            end
        end
    end
end

-------------------------------------------------------------------------------
--  System enable / disable  (called from toggle setValue and on login)
-------------------------------------------------------------------------------
function ns.UpdateFriendlyNameplateSystem()
    local shouldEnable = IsFriendlyEnabled() -- health-bar mode
    local nameOnly     = IsNameOnlyMode()    -- name-only mode
    local showFriendly = KullThranUINameplatesDB and KullThranUINameplatesDB.showFriendlyPlayers ~= false
    SetFriendlyAuraCVars(shouldEnable or (nameOnly and showFriendly))

    if ns.QueueNameplateCVar then
        local db = KullThranUINameplatesDB
        if db then
            local showPlayers = (db.showFriendlyPlayers ~= false)
            local showNPCs = (db.showFriendlyNPCs == true)
            ns.QueueNameplateCVar("nameplateShowFriendlyPlayers", showPlayers and 1 or 0)
            ns.QueueNameplateCVar("nameplateShowFriends", showPlayers and 1 or 0)
            ns.QueueNameplateCVar("nameplateShowFriendlyNPCs", showNPCs and 1 or 0)
            ns.QueueNameplateCVar("nameplateShowFriendlyNpcs", showNPCs and 1 or 0)
        end
    end

    if shouldEnable and not friendlyEnabled then
        -- Switching TO health-bar mode
        RestoreFriendlyFontOverride() -- undo any font override
        -- Clean up any name-only NPC overlays
        for np in pairs(nameOnlyNPCSuppressed) do
            local u = np.namePlateUnitToken
            RestoreNPCNameplate(np, u)
        end
        friendlyEnabled = true
        RegisterFriendlyManager()
        -- Pick up any nameplates already visible.
        local units = {}
        if ns.pendingUnits then
            for unit, _ in pairs(ns.pendingUnits) do
                units[unit] = true
            end
        end
        local allPlates = GetAccessibleNamePlates()
        if allPlates then
            for _, nameplate in ipairs(allPlates) do
                local unit = nameplate.namePlateUnitToken
                if unit then units[unit] = true end
            end
        end
        for unit, _ in pairs(units) do
            TryAddFriendlyPlate(unit)
        end
    elseif shouldEnable and friendlyEnabled then
        -- Already in health-bar mode — re-sweep to pick up NPC plates that
        -- may have been skipped (e.g. user just toggled showFriendlyNPCs on)
        local allPlates = GetAccessibleNamePlates()
        if allPlates then
            for _, nameplate in ipairs(allPlates) do
                local unit = nameplate.namePlateUnitToken
                if unit then TryAddFriendlyPlate(unit) end
            end
        end
    elseif not shouldEnable and friendlyEnabled then
        -- Switching FROM health-bar mode
        friendlyEnabled = false
        UnregisterFriendlyManager()
        ClearAllFriendlyPlates()
        -- Clean up any leftover NPC overlays from name-only mode
        for np in pairs(nameOnlyNPCSuppressed) do
            local u = np.namePlateUnitToken
            RestoreNPCNameplate(np, u)
        end
    end

    -- Name-only font override: apply when name-only AND friendly plates are shown
    if nameOnly and showFriendly then
        ApplyFriendlyFontOverride()
        -- (nameplate sizing handled by Blizzard in name-only mode)
        -- Set class-color CVar for Blizzard's name-only rendering
        if ns.QueueNameplateCVar then
            local db = KullThranUINameplatesDB
            local cc = (db and db.classColorFriendly ~= false) and 1 or 0
            ns.QueueNameplateCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", cc)
        end
        -- Sweep NPC plates: suppress health bars and color names green
        local npcEnabled = IsFriendlyNPCEnabled()
        local function SweepNPCPlates()
            local allPlates = GetAccessibleNamePlates()
            if allPlates then
                for _, nameplate in ipairs(allPlates) do
                    local u = nameplate.namePlateUnitToken
                    if u and not UnitCanAttack("player", u) and not UnitIsUnit(u, "player") and not UnitIsPlayer(u) then
                        if npcEnabled then
                            SuppressNPCNameplate(nameplate, u)
                        else
                            RestoreNPCNameplate(nameplate, u)
                        end
                    end
                end
            end
        end
        SweepNPCPlates()
        -- Delayed sweep: Blizzard creates NPC plates asynchronously after
        -- the CVar changes, so sweep again after a short delay.
        C_Timer.After(0.1, SweepNPCPlates)
        C_Timer.After(0.5, SweepNPCPlates)

        local function SweepPlayerGuild()
            if not ShouldShowFriendlyGuild() then
                for np in pairs(playerGuildLines) do HidePlayerGuildLine(np) end
                return
            end
            local allPlates = GetAccessibleNamePlates()
            if allPlates then
                for _, nameplate in ipairs(allPlates) do
                    local u = nameplate.namePlateUnitToken
                    if u and not UnitCanAttack("player", u) and not UnitIsUnit(u, "player") and UnitIsPlayer(u) then
                        UpdatePlayerGuildLine(nameplate, u)
                    end
                end
            end
        end
        SweepPlayerGuild()
        C_Timer.After(0.1, SweepPlayerGuild)
        C_Timer.After(0.5, SweepPlayerGuild)
    elseif not shouldEnable then
        -- Not in health-bar mode — restore fonts (covers disabled + name-only-off)
        RestoreFriendlyFontOverride()
        for np in pairs(playerGuildLines) do HidePlayerGuildLine(np) end
    end
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
            if IsNameOnlyMode() and IsFriendlyNPCEnabled() then
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
    if not IsNameOnlyMode() or not IsFriendlyNPCEnabled() then return end
    if UnitIsPlayer(unit) or UnitCanAttack('player', unit) then return end
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
