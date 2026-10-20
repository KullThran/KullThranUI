if KT_CLIENT_BLOCKED then return end

local _, ns = ...

-- Class icons: a big round icon over friendly player nameplates, as in
-- BetterBlizzPlates' class indicator. Healers get the healer cross, other players
-- their spec icon when the unit tooltip names the spec, or their class icon.

local DEFAULT_SIZE = 34
local HEALER_TEXTURE = "interface/lfgframe/uilfgprompts"
local HEALER_COORDS = { 0.015, 0.1077, 0.7684, 0.8606 }
local CLASS_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

ns.CLASS_ICON_DEFAULT_SIZE = DEFAULT_SIZE

local function Profile()
    return _G.KullThranUINameplatesDB or {}
end

local function IsEnabled()
    return Profile().friendlyClassIcons == true
end

local function Readable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function Unpack(ok, ...)
    if not ok then return nil end
    return ...
end

local function Call(fn, ...)
    if not fn then return nil end
    return Unpack(pcall(fn, ...))
end

-- Spec per player GUID: { icon, role } once the tooltip has named it.
local specCache = {}

local function ReadSpec(unit, classID)
    if not (classID and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID
        and C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return nil
    end
    local data = Call(C_TooltipInfo.GetUnit, unit)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local specs = {}
    for i = 1, (Call(GetNumSpecializationsForClassID, classID) or 0) do
        local _, name, _, icon, role = Call(GetSpecializationInfoForClassID, classID, i)
        if Readable(name) and name ~= "" then specs[#specs + 1] = { name = name, icon = icon, role = role } end
    end
    for _, line in ipairs(data.lines) do
        local text = line and line.leftText
        if Readable(text) and type(text) == "string" then
            for _, spec in ipairs(specs) do
                if text == spec.name or text:sub(1, #spec.name + 1) == spec.name .. " " then
                    return spec
                end
            end
        end
    end
    return nil
end

local function ResolveIcon(unit)
    local _, classToken, classID = Call(UnitClass, unit)
    if not Readable(classToken) then return nil end
    local guid = Call(UnitGUID, unit)
    local spec = Readable(guid) and specCache[guid]
    if not spec then
        spec = ReadSpec(unit, Readable(classID) and classID or nil)
        if spec and Readable(guid) then specCache[guid] = spec end
    end
    local role = Call(UnitGroupRolesAssigned, unit)
    if (Readable(role) and role == "HEALER") or (spec and spec.role == "HEALER") then
        return HEALER_TEXTURE, HEALER_COORDS
    end
    if spec and spec.icon then return spec.icon, nil end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if coords then return CLASS_TEXTURE, coords end
    return nil
end

local icons = {}

local function Acquire(nameplate)
    local f = icons[nameplate]
    if f then return f end
    f = CreateFrame("Frame", nil, nameplate)
    f:SetFrameStrata("LOW")
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.mask = f:CreateMaskTexture()
    f.mask:SetTexture("Interface/Masks/CircleMaskScalable")
    f.mask:SetAllPoints(f.icon)
    f.icon:AddMaskTexture(f.mask)
    f.border = f:CreateTexture(nil, "OVERLAY")
    f.border:SetAtlas("AutoQuest-badgeborder")
    f.border:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
    f.border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
    icons[nameplate] = f
    return f
end

local function GetNameplate(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local nameplate = Call(C_NamePlate.GetNamePlateForUnit, unit, issecure and issecure())
    if not nameplate or (nameplate.IsForbidden and nameplate:IsForbidden()) then return nil end
    return nameplate
end

local function HideFor(nameplate)
    local f = nameplate and icons[nameplate]
    if f then f:Hide() end
end

local function Update(unit)
    local nameplate = GetNameplate(unit)
    if not nameplate then return end
    local isPlayer, isFriend = Call(UnitIsPlayer, unit), Call(UnitIsFriend, "player", unit)
    if not IsEnabled() or not (Readable(isPlayer) and isPlayer) or not (Readable(isFriend) and isFriend)
        or Call(UnitIsUnit, unit, "player") then
        HideFor(nameplate)
        return
    end
    local texture, coords = ResolveIcon(unit)
    if not texture then
        HideFor(nameplate)
        return
    end
    local p = Profile()
    local size = tonumber(p.friendlyClassIconSize) or DEFAULT_SIZE
    local y = (tonumber(p.friendlyNameOnlyYOffset) or 0) + 10 + (tonumber(p.friendlyClassIconYOffset) or 0)
    local f = Acquire(nameplate)
    f:SetSize(size, size)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", nameplate, "CENTER", 0, y)
    f.icon:SetTexture(texture)
    if coords then
        f.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        f.icon:SetTexCoord(0, 1, 0, 1)
    end
    f:Show()
end

local function RefreshAll()
    for nameplate, f in pairs(icons) do
        if not IsEnabled() then f:Hide() end
    end
    if not IsEnabled() or not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, nameplate in ipairs(Call(C_NamePlate.GetNamePlates, issecure and issecure()) or {}) do
        local unit = nameplate.namePlateUnitToken
        if Readable(unit) and unit then Update(unit) end
    end
end
ns.RefreshClassIcons = RefreshAll

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
watcher:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if not IsEnabled() then return end
        Update(unit)
        -- The tooltip may not name the spec yet when the plate appears.
        C_Timer.After(1, function() Update(unit) end)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        HideFor(GetNameplate(unit))
    else
        if event == "PLAYER_ENTERING_WORLD" then wipe(specCache) end
        RefreshAll()
    end
end)
