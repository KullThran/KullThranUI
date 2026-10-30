-- Where the player frame really draws, and what hangs on it, for modules
-- that dock around it (KUI Tracker). Measured from what is drawn, not from
-- the frame box: the Forever/Retail atlas (198x71) sits centred in a 232x100
-- box, so docking to the box left ~17px of empty space on every side.
--
-- Elements that can appear later (in combat or on a form change) keep their
-- room even while hidden: the cast bar locked to the frame, the druid's
-- alternate mana bar when that option is on, and combo points for classes
-- that use them. Docked frames cannot move in combat, so they must never sit
-- where one of these will show up.
local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local GAP = 2

local function Settings()
    local uf = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
    return uf, uf and uf.player or {}
end

local function AltManaEnabled(uf)
    if uf and uf.altMana ~= nil then return uf.altMana == true end
    local am = ns.AltMana
    return am and am.DefaultEnabled and am.DefaultEnabled() or false
end

-- Returns left, right, top, bottom of the player's footprint as offsets from
-- the player frame's TOPLEFT, in the player frame's own units; nil if the
-- frame is not laid out yet.
function ns.GetPlayerFootprint()
    local frame = ns.frames and ns.frames.player
    if not (frame and frame.GetEffectiveScale and frame:IsShown()) then return nil end
    local scale = frame:GetEffectiveScale()
    local frameLeft, frameTop = frame:GetLeft(), frame:GetTop()
    if not (scale and scale > 0 and frameLeft and frameTop) then return nil end

    local L, R, T, B
    local function Add(region, verticalOnly)
        if not (region and region.IsShown and region:IsShown() and region.GetRect) then return false end
        local l, b, w, h = region:GetRect()
        if not (l and b and w and h) or w <= 0 or h <= 0 then return false end
        local k = region:GetEffectiveScale() / scale
        l, b, w, h = l * k, b * k, w * k, h * k
        if not verticalOnly then
            L = L and math.min(L, l) or l
            R = R and math.max(R, l + w) or l + w
        end
        T = T and math.max(T, b + h) or b + h
        B = B and math.min(B, b) or b
        return true
    end

    local native = frame._ktForeverLayoutActive or frame._ktClassicLayoutActive
    local art = frame._ktForeverPortraitArt or frame._ktClassicPortraitArt
    if not (native and Add(art)) then Add(frame) end
    Add(frame.Health)
    Add(frame.Power)
    Add(frame.Portrait and frame.Portrait.backdrop)
    if not (L and R and T and B) then return nil end

    -- Aura rows sit where the frame's settings put them (player buffs above
    -- by default). An enabled row keeps its room even while empty: buffs
    -- arrive in combat, when docked frames can no longer move.
    for _, auras in ipairs({ frame.Buffs, frame.Debuffs, frame.KTDebuffs }) do
        if auras and (auras.num == nil or auras.num > 0) then Add(auras, true) end
    end

    local uf, settings = Settings()
    local _, class = UnitClass("player")

    -- Hung below the bars: whatever shows now counts as drawn, the rest is
    -- reserved by its real height under the lowest one.
    local reserve = 0
    local altMana = frame._kuiAltMana
    if not Add(altMana, true) and class == "DRUID" and AltManaEnabled(uf) then
        local h = altMana and altMana:GetHeight() or 0
        reserve = reserve + (h > 0 and h or 10) + GAP
    end
    local cpBar = ns.frames._classPowerBar
    if cpBar and cpBar.GetParent and cpBar:GetParent() == frame then Add(cpBar, true) end
    local cuf = ns.ComboUnderFrame
    local combo = cuf and cuf.live and cuf.live.player
    -- Druids only get combo points in Cat Form: reserve them for Feral (who
    -- lives there) or while already in it, not for every druid spec.
    local comboClass = class == "ROGUE"
    if class == "DRUID" then
        local spec = GetSpecialization and GetSpecialization()
        local specID = spec and GetSpecializationInfo and GetSpecializationInfo(spec)
        comboClass = specID == 103 or (GetShapeshiftFormID and GetShapeshiftFormID() == 1) or false
    end
    if not (combo and Add(combo.frame, true)) and comboClass
        and cuf and cuf.GetBarStyle and cuf.GetBarStyle("player") ~= "off"
        and (not cuf.GetPlacement or cuf.GetPlacement("player") ~= "above") then
        local h = combo and combo.frame and combo.frame:GetHeight() or 0
        reserve = reserve + (h > 0 and h or 14) + 3
    end
    if cuf and cuf.extraLive and cuf.extraLive.player then Add(cuf.extraLive.player.frame, true) end
    local castbar = frame.Castbar
    local castHost = castbar and castbar.GetParent and castbar:GetParent()
    if castHost and castHost ~= frame and castHost:GetParent() == frame
        and settings.lockCastbarToFrame ~= false and not Add(castHost, true) then
        local h = castHost:GetHeight() or 0
        reserve = reserve + (h > 0 and h or 16) + GAP
    end
    B = B - reserve

    return L - frameLeft, R - frameLeft, T - frameTop, B - frameTop
end

_G.KullThranUI_GetPlayerFootprint = function() return ns.GetPlayerFootprint() end
