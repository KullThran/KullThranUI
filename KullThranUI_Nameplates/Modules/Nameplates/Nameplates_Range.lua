-------------------------------------------------------------------------------
--  Distance over enemy nameplates (optional, off by default).
--
--  LibRangeCheck-3.0 does not measure yards: it answers with a bracket (min / max) from the
--  spells and items the player can use, so the text is "up to X yd" (or "min-max"). One shared
--  ticker updates every visible enemy plate a few times per second.
--
--  Settings (KullThranUINameplatesDB):
--    rangeEnabled  false         rangeFormat  "max" | "span"
--    rangeSize     16            rangeColor   "bands" | "white"
--    rangeScope    "all" | "target"          rangeMax     100 (hidden beyond this)
--    rangeFont     "Russo One"   (a LibSharedMedia font name)
-------------------------------------------------------------------------------
local _, ns = ...

local R = {}
ns.PlateRange = R

local DEFAULTS = {
    rangeEnabled = false, rangeFormat = "max", rangeSize = 16, rangeFont = "Russo One",
    rangeColor = "bands", rangeScope = "all", rangeMax = 100,
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

-- Russo One ships with the addon (OFL, see Libraries/texture/media/fonts/OFL.txt).
local RUSSO_ONE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Russo One.ttf"
local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
if LSM and not LSM:IsValid("font", "Russo One") then
    LSM:Register("font", "Russo One", RUSSO_ONE)
end
R.DEFAULT_FONT_PATH = RUSSO_ONE

local function FontPath()
    local name = Get("rangeFont")
    local path = LSM and type(name) == "string" and LSM:Fetch("font", name, true)
    return path or RUSSO_ONE
end

local function SetFont(fs, size, flags)
    if not fs:SetFont(FontPath(), size, flags) then
        fs:SetFont(RUSSO_ONE, size, flags)
    end
end

-- The number and its unit are two strings: plate._ktRange (the yards) and plate._ktRangeUnit.
local function Text(plate)
    local fs = plate._ktRange
    if fs then return fs end
    fs = plate:CreateFontString(nil, "OVERLAY", nil, 7)
    fs:SetJustifyH("LEFT")
    local unit = plate:CreateFontString(nil, "OVERLAY", nil, 7)
    unit:SetJustifyH("LEFT")
    plate._ktRange, plate._ktRangeUnit = fs, unit
    return fs
end

-- A fat number past the bar's right end, just above its top edge, with a small "yd" after it.
-- Outside the bar's width the name row (name centred over the bar) never reaches it, so the
-- name keeps its place; the level badge beside the bar sits below it.
local function Place(plate, fs)
    local unit = plate._ktRangeUnit
    local bar = plate.health or plate
    local size = tonumber(Get("rangeSize")) or DEFAULTS.rangeSize
    SetFont(fs, size, "THICKOUTLINE")
    SetFont(unit, math.max(7, math.floor(size * 0.6 + 0.5)), "OUTLINE")
    -- Text only after the font: the client refuses text on a string without one.
    unit:SetText("yd")
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOMLEFT", bar, "TOPRIGHT", 3, 4)
    unit:ClearAllPoints()
    unit:SetPoint("BOTTOMLEFT", fs, "BOTTOMRIGHT", 1, 1)
end

-- Returns the text and a representative number of yards for the colour, or nil.
local function Measure(unit)
    local lib = _G.LibStub and _G.LibStub("LibRangeCheck-3.0", true)
    if not (lib and lib.GetRange) then return nil end
    local ok, minRange, maxRange = pcall(lib.GetRange, lib, unit, false, false, 0.2)
    if not ok or Secret(minRange) or Secret(maxRange) then return nil end
    if type(minRange) ~= "number" and type(maxRange) ~= "number" then return nil end
    local limit = tonumber(Get("rangeMax")) or DEFAULTS.rangeMax
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
            fs:SetText(text)
            local r, g, b = 1, 1, 1
            if Get("rangeColor") == "bands" then
                r, g, b = BandColor(yards)
            end
            fs:SetTextColor(r, g, b)
            plate._ktRangeUnit:SetTextColor(r, g, b)
            fs:Show()
            plate._ktRangeUnit:Show()
            show = true
        end
    end
    if fs and not show then
        fs:Hide()
        plate._ktRangeUnit:Hide()
    end
end

local function HideAll()
    for _, plate in pairs(ns.plates or {}) do
        if plate._ktRange then
            plate._ktRange:Hide()
            plate._ktRangeUnit:Hide()
        end
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
