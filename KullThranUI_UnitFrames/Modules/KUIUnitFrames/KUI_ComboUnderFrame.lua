-------------------------------------------------------------------------------
--  Combo points under the Player unit frame (Target keeps its portrait ring).
--
--  Setting: KT.db.profile.unitFrames.comboUnderFrame = "off" | "modern" | "classic"
--    * nil (never touched) follows the visual style: Forever "modern",
--      Classic "classic", Retail and KUI Style "off".
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
CUF.extraLive = CUF.extraLive or {}

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
--   target: off | ring | both | modern | classic (key comboTargetStyle;
--           "ring" = the circular arc around the portrait, "both" = the ring
--           plus modern pips under the target frame)
-- Defaults (only while the key is unset):
--   Forever : target ring + modern points under the Player frame
--   Retail  : target ring only
--   Classic : target ring (classic art) + classic points under the Player frame
--   KUI     : target ring around the portrait
local function LegacyStyle(unit)
    local uf = KT.db and KT.db.profile and KT.db.profile.unitFrames
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    if unit == "target" then
        local v = uf and uf.comboTargetStyle
        if v == "off" or v == "ring" or v == "both" or v == "modern" or v == "classic" then return v end
        return "ring"
    end
    local v = uf and uf.comboUnderFrame
    if v == "off" or v == "modern" or v == "classic" then return v end
    if theme == "forever" then return "modern" end
    if theme == "classic" then return "classic" end
    return "off"
end

-- Independent displays are saved per visual style. Unedited profiles keep
-- explicit legacy choices, while Retail's untouched default is ring only.
function CUF.GetDisplays(unit)
    local uf = KT.db and KT.db.profile and KT.db.profile.unitFrames or {}
    local theme = KT.VisualThemes and KT.VisualThemes:GetRenderedTheme() or "kui"
    local saved = uf.comboDisplays and uf.comboDisplays[theme] and uf.comboDisplays[theme][unit]
    if saved then return saved end
    local old = LegacyStyle(unit)
    return { ring = unit == "target" and (old == "ring" or old == "both"),
        modern = old == "modern" or old == "both", classic = old == "classic" }
end
function CUF.SetDisplay(unit, key, enabled)
    local uf = KT.db.profile.unitFrames
    local theme = KT.VisualThemes and KT.VisualThemes:GetRenderedTheme() or "kui"
    local current = CUF.GetDisplays(unit)
    uf.comboDisplays = uf.comboDisplays or {}
    uf.comboDisplays[theme] = uf.comboDisplays[theme] or {}
    local saved = { ring = current.ring == true, modern = current.modern == true, classic = current.classic == true }
    saved[key] = enabled == true
    uf.comboDisplays[theme][unit] = saved
end
function CUF.GetStyle(unit)
    local selected = CUF.GetDisplays(unit)
    if selected.ring then return (selected.modern or selected.classic) and "both" or "ring" end
    return selected.modern and "modern" or selected.classic and "classic" or "off"
end
function CUF.ShowsRing(unit) return CUF.GetDisplays(unit).ring == true end
function CUF.GetBarStyle(unit)
    local selected = CUF.GetDisplays(unit)
    return selected.modern and "modern" or selected.classic and "classic" or "off"
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
        return type(GetShapeshiftFormID) == "function" and GetShapeshiftFormID() == 1
    end
    return false
end

-------------------------------------------------------------------------------
--  Other class resources on the Classic tray (holy power, shards, runes...)
--  The tray and empty slots are the same native combo art; the filled point
--  is a gem drawn for each resource (Libraries/texture/media/ClassicResource*).
-------------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local RESOURCE_BY_CLASS = {
    PALADIN     = { power = "HolyPower" },
    WARLOCK     = { power = "SoulShards" },
    DEATHKNIGHT = { power = "Runes" },
    EVOKER      = { power = "Essence" },
    MONK        = { power = "Chi", spec = 269 },           -- Windwalker
    MAGE        = { power = "ArcaneCharges", spec = 62 },  -- Arcane
}
local GEM = { HolyPower = "HolyPower", SoulShards = "SoulShard", Essence = "Essence",
    Chi = "Chi", ArcaneCharges = "ArcaneCharge" }
local RUNE_GEM = { [250] = "RuneBlood", [251] = "RuneFrost", [252] = "RuneUnholy" }

local function PlayerSpecID()
    local S = C_SpecializationInfo
    if not (S and S.GetSpecialization and S.GetSpecializationInfo) then return nil end
    local spec = S.GetSpecialization()
    return spec and S.GetSpecializationInfo(spec) or nil
end

-- powerType, gem texture of the player's non-combo class resource, or nil.
function CUF.PlayerClassResource()
    local _, class = UnitClass("player")
    local def = RESOURCE_BY_CLASS[class]
    local powerType = def and Enum and Enum.PowerType and Enum.PowerType[def.power]
    if not powerType then return nil end
    local specID = PlayerSpecID()
    if def.spec and specID ~= def.spec then return nil end
    local gem = def.power == "Runes" and (RUNE_GEM[specID] or "RuneBlood") or GEM[def.power]
    return powerType, MEDIA .. "ClassicResource" .. gem .. ".tga"
end

-- The Player's Classic display takes over these resources while the class
-- power bar is the custom one (not turned off, not Blizzard's own bar);
-- CreateCustomClassPower then skips its rectangular pips.
function CUF.OwnsClassResource()
    if not CUF.GetDisplays("player").classic then return false end
    local uf = KT.db and KT.db.profile and KT.db.profile.unitFrames
    local style = uf and uf.player and uf.player.classPowerStyle
    if style == nil or style == "none" or style == "blizzard" then return false end
    return CUF.PlayerClassResource() ~= nil
end

local function ReadyRunes(max)
    if not GetRuneCooldown then return nil end
    local ok, n = pcall(function()
        local ready = 0
        for i = 1, max do
            if select(3, GetRuneCooldown(i)) then ready = ready + 1 end
        end
        return ready
    end)
    return ok and n or nil
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

local function ApplyPipArt(p, style, gem)
    local emptyAtlas, fillAtlas = ArtFor(style)
    if HasAtlas(emptyAtlas) then
        p.empty:SetAtlas(emptyAtlas, false)
        p.empty:SetVertexColor(1, 1, 1, 1)
    else
        p.empty:SetTexture(FALLBACK_EMPTY)
        p.empty:SetVertexColor(0.08, 0.08, 0.08, 1)
    end
    if gem then
        p.bar:SetStatusBarTexture(gem)
        p.bar:SetStatusBarColor(1, 1, 1, 1)
    elseif HasAtlas(fillAtlas) then
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

-- gem: optional texture for the filled point (non-combo class resources).
function Widget:SetStyle(style, gem)
    self.style = style
    self.gem = gem
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
    for _, p in ipairs(self.pips) do ApplyPipArt(p, style, gem) end
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
    if not above and topAnchor then
        local hb = topAnchor.Health or topAnchor.health
        if hb and ref.GetBottom and hb.GetBottom then
            local bottom, barBottom = ref:GetBottom(), hb:GetBottom()
            if bottom and barBottom then
                y = y + bottom - barBottom
                ref = hb
            end
        end
    end
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
        if self.style then self:SetStyle(self.style, self.gem) end   -- redraw the tray mirrored / normal
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

-- Native tray geometry (126x20): 11px left cap, one 21px cell per point
-- (20px opening + 1px gap) and a 10px right cap.  The atlas has five
-- openings baked in; other counts (runes, essence, arcane charges...) are
-- rebuilt from slices of the same atlas so every point sits in an opening.
local PLATE_W, CAP_L, CELL, CAP_R = 126, 11, 21, 10

function Widget:LayoutPlate(n, k, snap)
    local info = self.style == "classic" and n ~= 5 and HasAtlas(ATLAS.plate)
        and C_Texture.GetAtlasInfo(ATLAS.plate)
    local file = info and (info.file or info.filename)
    local segs = self.plateSegs
    if not file then
        if segs then for _, t in ipairs(segs) do t:Hide() end end
        if self.style == "classic" and HasAtlas(ATLAS.plate) then self.plate:Show() end
        return
    end
    self.plate:Hide()
    segs = segs or {}
    self.plateSegs = segs
    local L, R = info.leftTexCoord, info.rightTexCoord
    local T, B = info.topTexCoord, info.bottomTexCoord
    if self.flipped then T, B = B, T end
    local pieces = { { 0, CAP_L } }
    for i = 1, n do
        local c = (i == 1 and 1) or (i == n and 5) or (2 + (i - 2) % 3)
        local x0 = CAP_L + CELL * (c - 1)
        pieces[#pieces + 1] = { x0, x0 + CELL }
    end
    pieces[#pieces + 1] = { PLATE_W - CAP_R, PLATE_W }
    local x = 0
    for i, src in ipairs(pieces) do
        local t = segs[i] or self.frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        segs[i] = t
        local w = src[2] - src[1]
        local left, right = snap(x * k), snap((x + w) * k)
        t:SetTexture(file)
        t:SetTexCoord(L + (R - L) * src[1] / PLATE_W, L + (R - L) * src[2] / PLATE_W, T, B)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", self.frame, "TOPLEFT", left, 0)
        t:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", left, 0)
        t:SetWidth(right - left)
        t:Show()
        x = x + w
    end
    for i = #pieces + 1, #segs do segs[i]:Hide() end
end

function Widget:Layout()
    local f = self.frame
    local n = self.count or 5
    if self.style == "classic" then
        local W = f:GetWidth()
        if not W or W <= 0 then return end
        -- Whole physical pixels: the effective scale is fractional, so slice
        -- seams and point offsets are rounded to the screen grid.
        local es = f.GetEffectiveScale and f:GetEffectiveScale()
        if not es or es <= 0 then es = 1 end
        local function snap(v) return math.floor(v * es + 0.5) / es end
        local k = W / (CAP_L + CELL * n + CAP_R)
        local d = 20 * k
        if math.abs((f:GetHeight() or 0) - d) > 0.5 then f:SetHeight(d) end
        self:LayoutPlate(n, k, snap)
        for i, p in ipairs(self.pips) do
            p:ClearAllPoints()
            if i <= n then
                local sz = snap(d * 1.1)
                p:SetSize(sz, sz)
                p:SetPoint("LEFT", f, "LEFT", snap((CAP_L + CELL * (i - 1)) * k - (sz - d) / 2),
                    snap((self.flipped and d or -d) * 0.18))
            end
        end
    else
        if self.plateSegs then for _, t in ipairs(self.plateSegs) do t:Hide() end end
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
    local anchor = frame.Power and frame.Power:IsShown() and frame.Power or frame.Health or frame
    local bottom = anchor.GetBottom and anchor:GetBottom()
    for _, region in pairs({ frame.Debuffs, frame.Castbar and frame.Castbar.GetParent and frame.Castbar:GetParent() }) do
        if region and region.IsShown and region:IsShown() and region.GetBottom then
            local candidate = region:GetBottom()
            if candidate and bottom and candidate < bottom then anchor, bottom = region, candidate end
        end
    end
    return anchor
end

function CUF:UpdateUnit(unit)
    local frame = ns.frames and ns.frames[unit]
    local obj = self.live[unit]
    if not frame then return end
    -- Player without combo points: holy power, shards, runes... on the Classic tray.
    local resourceType, gem
    if unit == "player" and not CUF.PlayerHasCombo() and CUF.OwnsClassResource() then
        resourceType, gem = CUF.PlayerClassResource()
    end
    local style = resourceType and "classic" or CUF.GetBarStyle(unit)
    local show = style ~= "off" and frame:IsShown() and (resourceType ~= nil or CUF.PlayerHasCombo())
    if show and unit == "target" then
        show = UnitExists("target") and not (UnitIsFriend and UnitIsFriend("player", "target"))
    end
    if not show then
        if obj then obj.frame:Hide() end
        if self.extraLive[unit] then self.extraLive[unit].frame:Hide() end
        return
    end
    if not obj then
        obj = CUF.Create(frame)
        self.live[unit] = obj
    end
    local anchor = AnchorFor(unit, frame)
    obj:SetStyle(style, gem)
    local pos, px, py = CUF.GetPlacement(unit)
    obj:Place(anchor, style, frame.Health and frame.Health:GetWidth(), pos, px, py, frame)

    local powerType = resourceType or ComboPowerType()
    local okMax, maxPower = pcall(UnitPowerMax, "player", powerType)
    if not okMax or type(maxPower) ~= "number" or maxPower <= 0 then maxPower = 5 end
    local okCur, cur = pcall(UnitPower, "player", powerType)
    if resourceType and Enum.PowerType.Runes == resourceType then
        local ready = ReadyRunes(maxPower)
        if ready then okCur, cur = true, ready end
    end
    obj:SetValues(okCur and cur or 0, maxPower)
    obj.frame:Show()
    local extra = self.extraLive[unit]
    local selected = CUF.GetDisplays(unit)
    if not resourceType and selected.modern and selected.classic then
        if not extra then extra = CUF.Create(frame); self.extraLive[unit] = extra end
        extra:SetStyle("classic")
        local offset = (obj.frame:GetHeight() + 8) * (pos == "above" and 1 or -1)
        extra:Place(anchor, "classic", frame.Health and frame.Health:GetWidth(), pos, px, py + offset, frame)
        extra:SetValues(okCur and cur or 0, maxPower)
        extra.frame:Show()
    elseif extra then extra.frame:Hide() end
end

function CUF:RefreshAll()
    -- Hand the resource back and forth with the custom class power bar.
    local owns = CUF.OwnsClassResource()
    if self._ownsResource ~= nil and owns ~= self._ownsResource
        and ns.frames and ns.frames._toggleClassPower and not InCombatLockdown() then
        local uf = KT.db.profile.unitFrames
        ns.frames._toggleClassPower(uf.player and uf.player.classPowerStyle)
    end
    self._ownsResource = owns
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
for _, event in ipairs({ "RUNE_POWER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, event)   -- not every client has these
end
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
    if (style == "ring" or style == "both") and O and frame.portraitFrame and frame.portraitFrame:IsShown() then
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

    style = (unitKey == "player" or unitKey == "target") and CUF.GetBarStyle(unitKey) or "off"
    if style == "off" or style == "ring" then
        if obj then obj.frame:Hide() end
        if frame._ktComboExtraPreview then frame._ktComboExtraPreview.frame:Hide() end
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
                local extra = frame._ktComboExtraPreview
                local selected = CUF.GetDisplays(unitKey)
                if extra and extra.frame:IsShown() and selected.modern and selected.classic then
                    local offset = (obj.frame:GetHeight() + 8) * (pos == "above" and 1 or -1)
                    extra:Place(anchor, "classic", anchor:GetWidth(), pos, px, py + offset, frame)
                end
            end
        end)
    end
    obj:SetValues(2, 5)
    obj.frame:Show()
    local extra = frame._ktComboExtraPreview
    local selected = CUF.GetDisplays(unitKey)
    if selected.modern and selected.classic then
        if not extra then extra = CUF.Create(frame); frame._ktComboExtraPreview = extra end
        extra:SetStyle("classic")
        local offset = (obj.frame:GetHeight() + 8) * (pos == "above" and 1 or -1)
        extra:Place(anchor, "classic", anchor:GetWidth(), pos, px, py + offset, frame)
        extra:SetValues(2, 5)
        extra.frame:Show()
    elseif extra then extra.frame:Hide() end
end
