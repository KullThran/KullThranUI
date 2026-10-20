-------------------------------------------------------------------------------
--  Distance over enemy nameplates (optional, off by default).
--
--  LibRangeCheck-3.0 does not measure yards: it answers with a bracket (min / max) from the
--  spells and items the player can use, so the text is "up to X yd" (or "min-max"). One shared
--  ticker updates every visible enemy plate a few times per second.
--
--  Settings (KullThranUINameplatesDB):
--    rangeEnabled  false         rangeFormat  "max" | "span"
--    rangeSize     11            rangeColor   "bands" | "white"
--    rangeScope    "all" | "target"          rangeMax     60 (hidden beyond this)
-------------------------------------------------------------------------------
local _, ns = ...

local R = {}
ns.PlateRange = R

local DEFAULTS = {
    rangeEnabled = false, rangeFormat = "max", rangeSize = 11,
    rangeColor = "bands", rangeScope = "all", rangeMax = 60,
}
R.DEFAULTS = DEFAULTS

local function Get(key)
    local db = _G.KullThranUINameplatesDB
    local value = db and db[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

local function Secret(value)
    return _G.issecretvalue and _G.issecretvalue(value) or false
end

-- cold -> hot: close targets are green, far ones fade to grey
local function BandColor(yards)
    if yards <= 10 then return 0.35, 1, 0.35 end
    if yards <= 20 then return 0.75, 1, 0.3 end
    if yards <= 30 then return 1, 0.9, 0.2 end
    if yards <= 40 then return 1, 0.6, 0.15 end
    return 0.85, 0.85, 0.85
end

local function Text(plate)
    local fs = plate._ktRange
    if fs then return fs end
    fs = plate:CreateFontString(nil, "OVERLAY", nil, 7)
    fs:SetJustifyH("CENTER")
    plate._ktRange = fs
    return fs
end

local function Place(plate, fs)
    local anchor = (plate.name and plate.name.IsShown and plate.name:IsShown() and plate.name) or plate.health or plate
    fs:ClearAllPoints()
    if anchor == plate.name then
        fs:SetPoint("BOTTOM", anchor, "TOP", 0, 1)
    else
        fs:SetPoint("BOTTOM", anchor, "TOP", 0, 3)
    end
    local fontPath
    if plate.name and plate.name.GetFont then fontPath = plate.name:GetFont() end
    fs:SetFont(fontPath or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", tonumber(Get("rangeSize")) or 11, "OUTLINE")
end

-- Returns the text and a representative number of yards for the colour, or nil.
local function Measure(unit)
    local lib = _G.LibStub and _G.LibStub("LibRangeCheck-3.0", true)
    if not (lib and lib.GetRange) then return nil end
    local ok, minRange, maxRange = pcall(lib.GetRange, lib, unit, false, false, 0.2)
    if not ok or Secret(minRange) or Secret(maxRange) then return nil end
    if type(minRange) ~= "number" and type(maxRange) ~= "number" then return nil end
    local limit = tonumber(Get("rangeMax")) or 60
    local yards = maxRange or minRange
    if (maxRange == nil and (minRange or 0) >= limit) or (maxRange and maxRange > limit) then return nil end
    local text
    if not maxRange then
        text = tostring(minRange) .. "+"
    elseif Get("rangeFormat") == "span" and minRange and minRange > 0 and minRange ~= maxRange then
        text = minRange .. "-" .. maxRange
    else
        text = tostring(maxRange)
    end
    return text, yards
end

local function UpdatePlate(plate, unit)
    local fs = plate._ktRange
    local show = false
    if unit and plate.IsShown and plate:IsShown() and UnitExists(unit) and UnitCanAttack("player", unit)
        and (Get("rangeScope") ~= "target" or UnitIsUnit(unit, "target")) then
        local text, yards = Measure(unit)
        if text then
            fs = Text(plate)
            Place(plate, fs)
            fs:SetText(text .. " yd")
            if Get("rangeColor") == "bands" then
                fs:SetTextColor(BandColor(yards))
            else
                fs:SetTextColor(1, 1, 1)
            end
            fs:Show()
            show = true
        end
    end
    if fs and not show then fs:Hide() end
end

local function HideAll()
    for _, plate in pairs(ns.plates or {}) do
        if plate._ktRange then plate._ktRange:Hide() end
    end
end

local ticker
function R.Refresh()
    if not Get("rangeEnabled") then
        if ticker then ticker:Cancel(); ticker = nil end
        HideAll()
        return
    end
    if not ticker then
        ticker = C_Timer.NewTicker(0.2, function()
            for unit, plate in pairs(ns.plates or {}) do
                UpdatePlate(plate, plate.unit or unit)
            end
        end)
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() R.Refresh() end)
