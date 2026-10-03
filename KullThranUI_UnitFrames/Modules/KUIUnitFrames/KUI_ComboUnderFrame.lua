-------------------------------------------------------------------------------
--  Combo points under the Player unit frame (Target keeps its portrait ring).
--
--  Setting: KT.db.profile.unitFrames.comboUnderFrame = "off" | "modern" | "classic"
--    * nil (never touched) resolves to "classic" when the Classic visual style
--      is rendered and to "off" for every other style/preset.
--    * "modern"  : atlas pips (uf-roguecp-*).
--    * "classic" : slim ornament plate with round slots (Classic look).
--
--  Structure: a bar anchored under the
--  frame, one pip per combo point, driven by UnitPower/UnitPowerMax and refreshed
--  on power / max-power / target / shapeshift events.  Drawing is done here with
--  plain textures (no Blizzard XML templates).
-------------------------------------------------------------------------------
local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local CUF = ns.ComboUnderFrame or {}
ns.ComboUnderFrame = CUF
CUF.live = CUF.live or {}

local MAX_PIPS = 7

local ATLAS = {
    plate         = "ComboPoints-AllPointsBG",
    classicEmpty  = "ComboPoints-PointBg",
    classicFill   = "ComboPoints-ComboPoint",
    modernEmpty   = "uf-roguecp-bg",
    modernFill    = "uf-roguecp-icon-red",
}
local FALLBACK_FILL  = "Interface\\COMMON\\Indicator-Red"
local FALLBACK_EMPTY = "Interface\\COMMON\\Indicator-Gray"

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end
CUF.HasAtlas = HasAtlas
CUF.ATLAS = ATLAS

-------------------------------------------------------------------------------
--  Setting resolution
-------------------------------------------------------------------------------
-- unit = "player" (default) or "target".
--   player: off | modern | classic      (key comboUnderFrame)
--   target: off | ring | modern | classic (key comboTargetStyle; "ring" = the
--           circular arc around the portrait; default off)
function CUF.GetStyle(unit)
    local uf = KT.db and KT.db.profile and KT.db.profile.unitFrames
    if unit == "target" then
        local v = uf and uf.comboTargetStyle
        if v == "off" or v == "ring" or v == "modern" or v == "classic" then return v end
        return "off"
    end
    local v = uf and uf.comboUnderFrame
    if v == "off" or v == "modern" or v == "classic" then return v end
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    if theme == "classic" then return "classic" end
    if theme == "forever" then return "modern" end
    return "off" -- retail and kui
end
-- Exposed on the core addon so other modules (Resource Bars) can query it.
KT.GetComboUnderFrameStyle = CUF.GetStyle
KT.RefreshComboUnderFrame = function() if CUF.RefreshAll then CUF:RefreshAll() end end

-- Placement per unit: position "below" (default) or "above" the frame, plus X/Y offsets.
--   keys: comboPosPlayer/comboXPlayer/comboYPlayer, comboPosTarget/comboXTarget/comboYTarget
function CUF.GetPlacement(unit)
    local uf = KT.db and KT.db.profile and KT.db.profile.unitFrames or {}
    local suffix = (unit == "target") and "Target" or "Player"
    local pos = uf["comboPos" .. suffix]
    if pos ~= "above" then pos = "below" end
    return pos, tonumber(uf["comboX" .. suffix]) or 0, tonumber(uf["comboY" .. suffix]) or 0
end

local function ComboPowerType()
    return Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
end

-- Rogue always; Druid only in Cat Form (form id 1).
function CUF.PlayerHasCombo()
    local _, class = UnitClass("player")
    if class == "ROGUE" then return true end
    if class == "DRUID" then
        return GetShapeshiftFormID == nil or GetShapeshiftFormID() == 1
    end
    return false
end

-------------------------------------------------------------------------------
--  Widget (shared by the live frames and the options preview)
-------------------------------------------------------------------------------
local function MakePip(parent)
    local p = CreateFrame("Frame", nil, parent)
    p.empty = p:CreateTexture(nil, "ARTWORK", nil, 0)
    p.empty:SetAllPoints()
    p.bar = CreateFrame("StatusBar", nil, p)
    p.bar:SetAllPoints()
    p.bar:SetFrameLevel(p:GetFrameLevel() + 1)
    p.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    return p
end

local function ArtFor(style)
    if style == "classic" then
        return ATLAS.classicEmpty, ATLAS.classicFill
    end
    return ATLAS.modernEmpty, ATLAS.modernFill
end

local function ApplyPipArt(p, style)
    local emptyAtlas, fillAtlas = ArtFor(style)
    if HasAtlas(emptyAtlas) then
        p.empty:SetAtlas(emptyAtlas, false)
        p.empty:SetVertexColor(1, 1, 1, 1)
    else
        p.empty:SetTexture(FALLBACK_EMPTY)
        p.empty:SetVertexColor(0.08, 0.08, 0.08, 1)
    end
    if HasAtlas(fillAtlas) then
        local t = p.bar:GetStatusBarTexture()
        if t then t:SetAtlas(fillAtlas, false) end
        p.bar:SetStatusBarColor(1, 1, 1, 1)
    else
        p.bar:SetStatusBarTexture(FALLBACK_FILL)
        p.bar:SetStatusBarColor(1, 1, 1, 1)
    end
end

local Widget = {}
Widget.__index = Widget

function CUF.Create(parent)
    local o = setmetatable({ pips = {}, count = 5 }, Widget)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel((parent:GetFrameLevel() or 1) + 6)
    o.frame = f

    -- Classic plate: native atlas when present, else a dark box + silver edge.
    o.plate = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    o.plate:SetAllPoints()
    o.edges = {}
    local function Edge(p1, p2, w, h)
        local t = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetColorTexture(0.62, 0.62, 0.66, 1)
        t:SetPoint(p1, f, p1)
        t:SetPoint(p2, f, p2)
        if w then t:SetWidth(w) end
        if h then t:SetHeight(h) end
        o.edges[#o.edges + 1] = t
    end
    Edge("TOPLEFT", "TOPRIGHT", nil, 1)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

    for i = 1, MAX_PIPS do
        o.pips[i] = MakePip(f)
    end
    f:SetScript("OnSizeChanged", function() o:Layout() end)
    return o
end

function Widget:SetStyle(style)
    self.style = style
    local usePlateAtlas = style == "classic" and HasAtlas(ATLAS.plate)
    if style == "classic" then
        if usePlateAtlas then
            self.plate:SetAtlas(ATLAS.plate, false)
            self.plate:SetVertexColor(1, 1, 1, 1)
            -- The tray is drawn to hang BELOW a frame; above it is mirrored vertically.
            -- Pristine atlas coords are read ONCE (first draw is never flipped) and cached: SetAtlas
            -- with the same atlas can keep the previous coords, so swapping "whatever is there" flips
            -- back and forth on every refresh.
            if not self._plateBase then
                local ulx, uly, llx, lly, urx, ury, lrx, lry = self.plate:GetTexCoord()
                if ulx and lry then self._plateBase = { ulx, uly, llx, lly, urx, ury, lrx, lry } end
            end
            local bse = self._plateBase
            if bse then
                if self.flipped then
                    self.plate:SetTexCoord(bse[3], bse[4], bse[1], bse[2], bse[7], bse[8], bse[5], bse[6])
                else
                    self.plate:SetTexCoord(bse[1], bse[2], bse[3], bse[4], bse[5], bse[6], bse[7], bse[8])
                end
            end
        else
            self.plate:SetColorTexture(0.03, 0.03, 0.03, 0.95)
        end
        self.plate:Show()
        for _, e in ipairs(self.edges) do e:SetShown(not usePlateAtlas) end
    else
        self.plate:Hide()
        for _, e in ipairs(self.edges) do e:Hide() end
    end
    for _, p in ipairs(self.pips) do ApplyPipArt(p, style) end
end

-- Anchor below `anchor` (or above `topAnchor` when pos == "above").  Classic
-- spans the anchor's width; modern is centred.  x / y are user offsets.
function Widget:Place(anchor, style, width, pos, x, y, topAnchor)
    local f = self.frame
    f:ClearAllPoints()
    x, y = x or 0, y or 0
    local above = pos == "above"
    local ref = above and (topAnchor or anchor) or anchor
    -- Classic tray above: same width as the bars (not the whole frame with the portrait), stacked
    -- on the TOP edge of the name tab when the name sits above the bars (Classic stock art), else
    -- on the top edge of the health bar.
    local extraY, modernDy = 0, 0
    if above and topAnchor then
        local hb = topAnchor.Health or topAnchor.health
        local nameFS = topAnchor._ktStockNameText or topAnchor.NameText or topAnchor.nameText or topAnchor.LeftText or topAnchor.name
        local nt, ht = nil, hb and hb.GetTop and hb:GetTop()
        if nameFS and nameFS.GetTop then nt = nameFS:GetTop() end
        local nameAbove = nt and ht and nt > ht + 2
        if style == "classic" then
            ref = hb or ref
            if nameAbove then extraY = (nt - ht) + 4 end
        elseif nameAbove and hb then
            -- stock layouts (Classic/Forever/Retail art): centre on the BARS (not on the whole frame
            -- with the portrait) and sit on the top of the name tab (name text top + 4px)
            ref = hb
            modernDy = (nt + 4) - ht
        end
    end
    if (self.flipped or false) ~= above then
        self.flipped = above
        if self.style then self:SetStyle(self.style) end   -- redraw the tray mirrored / normal
    end
    if style == "classic" then
        if above then
            f:SetPoint("BOTTOMLEFT", ref, "TOPLEFT", x, y - 1 + extraY)
            f:SetPoint("BOTTOMRIGHT", ref, "TOPRIGHT", x, y - 1 + extraY)
        else
            f:SetPoint("TOPLEFT", ref, "BOTTOMLEFT", x, 1 + y)
            f:SetPoint("TOPRIGHT", ref, "BOTTOMRIGHT", x, 1 + y)
        end
        f:SetHeight(20)
    else
        if above then
            f:SetPoint("BOTTOM", ref, "TOP", x, 3 + y + modernDy)
        else
            f:SetPoint("TOP", ref, "BOTTOM", x, -3 + y)
        end
        self.modernWidth = width or ref:GetWidth() or 100
    end
    self:Layout()
end

function Widget:Layout()
    local f = self.frame
    local n = self.count or 5
    if self.style == "classic" then
        local W = f:GetWidth()
        if not W or W <= 0 then return end
        local k = W / 126
        local d = 20 * k
        if math.abs((f:GetHeight() or 0) - d) > 0.5 then f:SetHeight(d) end
        for i, p in ipairs(self.pips) do
            p:ClearAllPoints()
            if i <= n then
                local sz = d * 1.1
                p:SetSize(sz, sz)
                if n == 5 then
                    p:SetPoint("LEFT", f, "LEFT", (11 + 21 * (i - 1)) * k - (sz - d) / 2, (self.flipped and d or -d) * 0.18)
                else
                    local gap = (W - n * sz) / (n + 1)
                    p:SetPoint("LEFT", f, "LEFT", gap + (i - 1) * (sz + gap), (self.flipped and d or -d) * 0.18)
                end
            end
        end
    else
        local W = self.modernWidth or 100
        local S = math.max(10, math.min(18, W / 6))
        local gap = S * 0.25
        f:SetSize(n * S + (n - 1) * gap, S)
        for i, p in ipairs(self.pips) do
            p:ClearAllPoints()
            if i <= n then
                p:SetSize(S, S)
                p:SetPoint("LEFT", f, "LEFT", (i - 1) * (S + gap), 0)
            end
        end
    end
end

-- cur may be a secret value: StatusBar:SetValue accepts it.
function Widget:SetValues(cur, max)
    max = tonumber(max) or 5
    max = math.max(1, math.min(MAX_PIPS, math.floor(max + 0.5)))
    local changed = max ~= self.count
    self.count = max
    for i, p in ipairs(self.pips) do
        if i <= max then
            p.bar:SetMinMaxValues(i - 1, i)
            p.bar:SetValue(0)
            if cur ~= nil then pcall(p.bar.SetValue, p.bar, cur) end
            p:Show()
        else
            p:Hide()
        end
    end
    if changed then self:Layout() end
end

-------------------------------------------------------------------------------
--  Live frames
-------------------------------------------------------------------------------
local function AnchorFor(unit, frame)
    if unit == "target" and ns.KTTargetCombo and ns.KTTargetCombo._LowestRegion then
        return ns.KTTargetCombo:_LowestRegion(frame)
    end
    return frame.Power or frame.Health or frame
end

function CUF:UpdateUnit(unit)
    local frame = ns.frames and ns.frames[unit]
    local obj = self.live[unit]
    if not frame then return end
    local style = CUF.GetStyle(unit)
    if style == "ring" then style = "off" end -- ring is drawn by KTTargetCombo
    local show = style ~= "off" and frame:IsShown() and CUF.PlayerHasCombo()
    if show and unit == "target" then
        show = UnitExists("target") and not (UnitIsFriend and UnitIsFriend("player", "target"))
    end
    if not show then
        if obj then obj.frame:Hide() end
        return
    end
    if not obj then
        obj = CUF.Create(frame)
        self.live[unit] = obj
    end
    local anchor = AnchorFor(unit, frame)
    obj:SetStyle(style)
    local pos, px, py = CUF.GetPlacement(unit)
    obj:Place(anchor, style, frame.Health and frame.Health:GetWidth(), pos, px, py, frame)

    local comboType = ComboPowerType()
    local okMax, maxPower = pcall(UnitPowerMax, "player", comboType)
    if not okMax or type(maxPower) ~= "number" or maxPower <= 0 then maxPower = 5 end
    local okCur, cur = pcall(UnitPower, "player", comboType)
    obj:SetValues(okCur and cur or 0, maxPower)
    obj.frame:Show()
end

function CUF:RefreshAll()
    self:UpdateUnit("player")
    self:UpdateUnit("target")
    -- The portrait ring / kui bar of the Target follows comboTargetStyle too.
    local target = ns.frames and ns.frames.target
    if target and ns.KTTargetCombo and ns.KTTargetCombo.Refresh then
        ns.KTTargetCombo:Refresh(target)
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
ev:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
ev:SetScript("OnEvent", function() CUF:RefreshAll() end)

-------------------------------------------------------------------------------
--  Options preview (same pattern as the Rare / Elite ring preview)
-------------------------------------------------------------------------------
function CUF.ApplyPreview(frame, unitKey)
    if not frame then return end
    local obj = frame._ktComboPreview
    local style = (unitKey == "player" or unitKey == "target") and CUF.GetStyle(unitKey) or "off"

    -- Circular ring (Target): Blizzard's combo arc around the preview portrait.
    local ringPips = frame._ktComboRingPreview
    local O = ns.KUIOrnaments
    if style == "ring" and O and frame.portraitFrame and frame.portraitFrame:IsShown() then
        if not ringPips then
            ringPips = {}
            for i = 1, 5 do
                local holder = CreateFrame("Frame", nil, frame)
                holder:SetFrameLevel((frame:GetFrameLevel() or 1) + 8)
                ringPips[i] = holder
            end
            frame._ktComboRingPreview = ringPips
        end
        local pw = frame.portraitFrame:GetWidth() or 40
        local size = math.max(7, pw * 12 / 64)
        local rPos, rX, rY = CUF.GetPlacement("target")
        local layout = O.LayoutRing(frame, frame.portraitFrame, 5, size, rPos == "above") or {}
        local art = O.GetComboArt()
        for i, holder in ipairs(ringPips) do
            local spot = layout[i]
            if spot then
                holder:SetSize(size, size)
                holder:ClearAllPoints()
                holder:SetPoint("CENTER", frame.portraitFrame, "CENTER", spot[1] + rX, spot[2] + rY)
                O.StylePip(holder, art, size)
                holder._lit:SetShown(i <= 2)
                holder:Show()
            else
                holder:Hide()
            end
        end
    elseif ringPips then
        for _, holder in ipairs(ringPips) do holder:Hide() end
    end

    if style == "off" or style == "ring" then
        if obj then obj.frame:Hide() end
        return
    end
    if not obj then
        obj = CUF.Create(frame)
        frame._ktComboPreview = obj
    end
    local anchor = (frame.power and frame.power:IsShown()) and frame.power or frame.health or frame
    obj:SetStyle(style)
    local pos, px, py = CUF.GetPlacement(unitKey)
    obj:Place(anchor, style, anchor:GetWidth(), pos, px, py, frame)
    -- the preview is laid out a frame later: re-place once the name / bars have real positions
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if obj.frame and obj.frame:IsShown() then
                obj:Place(anchor, style, anchor:GetWidth(), pos, px, py, frame)
            end
        end)
    end
    obj:SetValues(2, 5)
    obj.frame:Show()
end
