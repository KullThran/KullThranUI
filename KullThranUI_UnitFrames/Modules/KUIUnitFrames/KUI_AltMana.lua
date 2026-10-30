-------------------------------------------------------------------------------
--  Alternate mana bar for druids: while a druid shapeshifts into a form that does not
--  use mana (cat, bear ...) Blizzard shows a second bar under the player's power bar.
--  Same here: the row of Blizzard's own class-resource plate (bronze for Forever, grey
--  for Retail) filled with its mana bar art, packaged so it looks the same on any client.
--  On by default for the Forever, Retail and Classic looks (KUI: off); the Unit Frames options
--  (KT.db.profile.unitFrames.altMana = true / false).
--  The combo points slide down by AM.Extent() so both fit.
-------------------------------------------------------------------------------
local _, ns = ...
local KT = _G.KullThranUI

local AM = {}
ns.AltMana = AM

local MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local FILE = [[Interface\AddOns\KullThranUI\Libraries\texture\media\altmana\altmana.tga]]
-- the fill has its own file so a StatusBar can crop it with its own texture coordinates
local FILL_FILE = {
    forever = [[Interface\AddOns\KullThranUI\Libraries\texture\media\altmana\fill_forever.tga]],
    retail = [[Interface\AddOns\KullThranUI\Libraries\texture\media\altmana\fill_retail.tga]],
}
local SHEET_W, SHEET_H = 256, 64
-- rects { x, y, w, h } in the sheet; inset = border widths left / top / right / bottom
local ART = {
    -- the Forever row ends in the plate's post: its right cap is the left cap mirrored
    forever = { key = "forever", frame = { 1, 1, 108, 12 }, fill = { 111, 1, 124, 10 }, inset = { 4, 2, 4, 2 }, mirrorRight = true,
        xOff = -3, wPad = 6 },
    -- Retail and Classic (steel-grey frame) wear the grey row, flush with the bars
    retail = { key = "retail", xOff = 0, wPad = 0, frame = { 1, 15, 125, 15 }, fill = { 128, 15, 124, 10 }, inset = { 4, 3, 4, 4 } },
}
local GAP = 2

local function Theme()
    local VT = KT and KT.VisualThemes
    return VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
end

local function IsForeverClient()
    local VT = KT and KT.VisualThemes
    return VT and VT.GetClientFlavor and VT:GetClientFlavor() == "forever" or false
end

-- Off by default on the Retail client (the player turns it on); on the Forever client it follows the look.
local function Enabled()
    local db = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
    if db and db.altMana ~= nil then return db.altMana == true end
    if not IsForeverClient() then return false end
    local theme = Theme()
    return theme == "forever" or theme == "retail" or theme == "classic"
end
AM.DefaultEnabled = function()
    if not IsForeverClient() then return false end
    local theme = Theme()
    return theme == "forever" or theme == "retail" or theme == "classic"
end
AM.IsEnabled = Enabled

local function ShouldShow()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return false end
    if UnitPowerType("player") == MANA then return false end
    local max = UnitPowerMax("player", MANA)
    if issecretvalue and issecretvalue(max) then return true end
    return type(max) == "number" and max > 0
end

local function Coords(tex, r)
    tex:SetTexCoord(r[1] / SHEET_W, (r[1] + r[3]) / SHEET_W, r[2] / SHEET_H, (r[2] + r[4]) / SHEET_H)
end

local function Build(frame, field)
    local bar = CreateFrame("Frame", nil, frame)
    bar.parts = {}
    for i = 1, 3 do
        bar.parts[i] = bar:CreateTexture(nil, "ARTWORK", nil, 2)
        bar.parts[i]:SetTexture(FILE)
    end
    bar.back = bar:CreateTexture(nil, "BACKGROUND")
    bar.back:SetColorTexture(0.04, 0.03, 0.03, 0.9)
    -- the fill is a plain texture cropped to the current amount (a StatusBar would rewrite the
    -- texture coordinates of the packaged sheet)
    bar.fillHost = CreateFrame("StatusBar", nil, bar)
    bar.fillHost:SetMinMaxValues(0, 1)
    bar.text = bar.fillHost:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar:Hide()
    frame[field or "_kuiAltMana"] = bar
    return bar
end

local function Layout(frame, bar, art)
    local power = frame.Power or frame.power          -- the options preview uses lowercase fields
    local health = frame.Health or frame.health
    local anchor = (power and power.IsShown and power:IsShown()) and power or health or frame
    local f, inset = art.frame, art.inset
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", art.xOff or 0, -1)
    -- as wide as the widest bar of the frame
    local width = anchor:GetWidth() or 0
    if health and health.GetWidth then width = math.max(width, health:GetWidth() or 0) end
    bar:SetSize(math.max(40, width + (art.wPad or 0)), f[4])
    bar:SetFrameLevel((frame:GetFrameLevel() or 1) + 6)

    -- left cap / stretched middle / right cap of the packaged row
    local cap = 4
    local p = bar.parts
    local fr = { f[1], f[2], f[3], f[4] }
    local function part(tex, x0, x1)
        Coords(tex, { x0, fr[2], x1 - x0, fr[4] })
    end
    part(p[1], fr[1], fr[1] + cap)
    part(p[2], fr[1] + cap, fr[1] + fr[3] - cap)
    if art.mirrorRight then
        p[3]:SetTexCoord((fr[1] + cap) / SHEET_W, fr[1] / SHEET_W, fr[2] / SHEET_H, (fr[2] + fr[4]) / SHEET_H)
    else
        part(p[3], fr[1] + fr[3] - cap, fr[1] + fr[3])
    end
    p[1]:ClearAllPoints(); p[1]:SetPoint("TOPLEFT"); p[1]:SetPoint("BOTTOMLEFT"); p[1]:SetWidth(cap)
    p[3]:ClearAllPoints(); p[3]:SetPoint("TOPRIGHT"); p[3]:SetPoint("BOTTOMRIGHT"); p[3]:SetWidth(cap)
    p[2]:ClearAllPoints(); p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT"); p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
    for i = 1, 3 do p[i]:Show() end

    bar.back:ClearAllPoints()
    bar.back:SetPoint("TOPLEFT", bar, "TOPLEFT", inset[1], -inset[2])
    bar.back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -inset[3], inset[4])
    bar.fillHost:ClearAllPoints()
    bar.fillHost:SetPoint("TOPLEFT", bar, "TOPLEFT", inset[1], -inset[2])
    bar.fillHost:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -inset[3], inset[4])
    bar.fillHost:SetFrameLevel(bar:GetFrameLevel() + 1)
    -- same texture and mana colour as the frame's own power bar
    local powerTex = power and power.GetStatusBarTexture and power:GetStatusBarTexture()
    local texture = power and power.__texture
    if not texture and powerTex then texture = powerTex:GetAtlas() or powerTex:GetTexture() end
    bar.fillHost:SetStatusBarTexture(texture or FILL_FILE[art.key])
    local colors = frame.colors and frame.colors.power
    local color = colors and (colors.MANA or colors[MANA])
    if not color and PowerBarColor then color = PowerBarColor.MANA or PowerBarColor[MANA] end
    local fill = bar.fillHost:GetStatusBarTexture()
    if fill then
        fill:SetTexCoord(0, 1, 0, 1)
        if color and color.GetRGB then fill:SetVertexColor(color:GetRGB())
        elseif color then fill:SetVertexColor(color.r or 0, color.g or 0, color.b or 1)
        else fill:SetVertexColor(0, 0, 1) end
    end
    bar.art = art
end

-- Options live preview: the same bar on the preview player frame (always shown when enabled,
-- with sample values, so every style can be checked without a druid).
function AM.ApplyPreview(frame, unitKey)
    if not frame then return end
    local bar = frame._kuiAltManaPreview
    if unitKey ~= "player" or not Enabled() then
        if bar then bar:Hide() end
        return
    end
    bar = bar or Build(frame, "_kuiAltManaPreview")
    local theme = Theme()
    Layout(frame, bar, ART[theme == "forever" and "forever" or "retail"])
    bar.fillHost:SetMinMaxValues(0, 100)
    bar.fillHost:SetValue(72)
    bar.text:SetText("1432")
    bar:Show()
end

function AM.PreviewExtent(frame, snug)
    local bar = frame and frame._kuiAltManaPreview
    if not (bar and bar:IsShown()) then return 0 end
    return (bar:GetHeight() or 0) + (snug and -3 or GAP)
end

-- The player's cast bar sits right under the power bar: while the mana bar shows it moves
-- down so it stays visible, and goes back to its own anchor when the mana bar hides.
local function SeatCastbar(frame, bar, shown, fresh)
    local cb = frame.Castbar and frame.Castbar.GetParent and frame.Castbar:GetParent()
    if not (cb and cb:GetParent() == frame) then return end
    local uf = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
    if uf and uf.player and uf.player.lockCastbarToFrame == false then return end
    if shown then
        if fresh or not cb._kuiAltManaOrig then
            local point, rel, relPoint, x, y = cb:GetPoint(1)
            if not point or rel == bar then return end
            cb._kuiAltManaOrig = { point, rel, relPoint, x or 0, y or 0 }
        end
        local o = cb._kuiAltManaOrig
        cb._kuiAmBusy = true
        cb:ClearAllPoints()
        if o[1] == "TOPLEFT" then
            cb:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", o[4] - (bar.art and bar.art.xOff or 0), -GAP + 1)
        else
            cb:SetPoint(o[1], bar, "BOTTOM", o[4], -GAP + 1)
        end
        cb._kuiAmBusy = nil
        -- the unit frame and the theme re-anchor the cast bar on every refresh: follow them
        if not cb._kuiAmHooked then
            cb._kuiAmHooked = true
            hooksecurefunc(cb, "SetPoint", function(self)
                if self._kuiAmBusy then return end
                local f = ns.frames and ns.frames.player
                local b2 = f and f._kuiAltMana
                if b2 and b2:IsShown() then pcall(SeatCastbar, f, b2, true, true) end
            end)
        end
    elseif cb._kuiAltManaOrig then
        local o = cb._kuiAltManaOrig
        cb._kuiAltManaOrig = nil
        cb._kuiAmBusy = true
        cb:ClearAllPoints()
        cb:SetPoint(o[1], o[2], o[3], o[4], o[5])
        cb._kuiAmBusy = nil
    end
end

-- Height the combo points have to give way (0 when the bar is not showing).
-- `snug` (the Classic combo tray, whose top already has its own little posts) sits closer.
function AM.Extent(snug)
    local frame = ns.frames and ns.frames.player
    local bar = frame and frame._kuiAltMana
    if not (bar and bar:IsShown()) then return 0 end
    return (bar:GetHeight() or 0) + (snug and -3 or GAP)
end

function AM.Update()
    local frame = ns.frames and ns.frames.player
    if not frame then return end
    local bar = frame._kuiAltMana
    local wasShown = bar and bar:IsShown() or false
    if not (Enabled() and ShouldShow() and frame:IsShown()) then
        if bar then bar:Hide() end
    else
        bar = bar or Build(frame)
        -- Forever wears the bronze row; Retail and Classic the grey one
        local theme = Theme()
        local art = ART[theme == "forever" and "forever" or "retail"]
        Layout(frame, bar, art)
        -- mana can be a secret value: only hand it to the StatusBar / text APIs, never compute with it
        local cur, max = UnitPower("player", MANA), UnitPowerMax("player", MANA)
        bar.fillHost:SetMinMaxValues(0, max)
        bar.fillHost:SetValue(cur)
        if not pcall(bar.text.SetFormattedText, bar.text, "%d", cur) then bar.text:SetText("") end
        bar:Show()
    end
    local isShown = bar and bar:IsShown() or false
    pcall(SeatCastbar, frame, bar, isShown)
    if isShown ~= wasShown then
        -- the combo points sit just below this bar
        local cuf = ns.ComboUnderFrame
        if cuf and cuf.RefreshAll then pcall(cuf.RefreshAll, cuf) end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
ev:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
ev:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.5, function()
            local ok, err = pcall(AM.Update)
            if not ok and not AM.errorShown then
                AM.errorShown = true
                print("|cffff6666KUI alt mana bar error|r " .. tostring(err))
            end
        end)
        return
    end
    local ok, err = pcall(AM.Update)
    if not ok and not AM.errorShown then
        AM.errorShown = true
        print("|cffff6666KUI alt mana bar error|r " .. tostring(err))
    end
end)

-- A profile switch / import / reset can change altMana (nil = follow the Visual Style).
if KT and KT.RefreshAllModules then
    hooksecurefunc(KT, "RefreshAllModules", function() pcall(AM.Update) end)
end

-- /ktaltmana : prints why the bar is (not) showing
_G.SLASH_KTALTMANA1 = "/ktaltmana"
_G.SlashCmdList.KTALTMANA = function()
    local frame = ns.frames and ns.frames.player
    local bar = frame and frame._kuiAltMana
    local _, class = UnitClass("player")
    print("|cff66ccffKUI alt mana|r theme=" .. tostring(Theme()) .. " enabled=" .. tostring(Enabled())
        .. " class=" .. tostring(class) .. " powerType=" .. tostring(UnitPowerType("player"))
        .. " shouldShow=" .. tostring(ShouldShow()) .. " playerFrame=" .. tostring(frame ~= nil)
        .. " bar=" .. tostring(bar ~= nil) .. " shown=" .. tostring(bar and bar:IsShown()))
    if bar then
        print("  size=" .. tostring(bar:GetWidth()) .. "x" .. tostring(bar:GetHeight()) .. " top=" .. tostring(bar:GetTop())
            .. " parentShown=" .. tostring(frame:IsShown()) .. " alpha=" .. tostring(bar:GetEffectiveAlpha()))
    end
    AM.Update()
end
