-- Layout rules shared by construction and refresh. Values here describe the
-- existing layout and profile compatibility, rather than the current UI scale.
local _, ns = ...
local Layout = {}
ns.FrameLayout = Layout

Layout.DetachedGap = 15
Layout.PortraitMinimum = 8
Layout.DetachedPortraitExtra = 10
Layout.DetachedPortraitY = 5

function Layout.Portrait(settings, shown, attached, height, defaultSide)
    local side = settings.portraitSide or defaultSide
    if attached and side == "top" then side = defaultSide end
    local edge = math.max(Layout.PortraitMinimum,
        height + (settings.portraitSize or 0) + (attached and 0 or Layout.DetachedPortraitExtra))
    local occupiesBar = shown and attached
    return {
        side = side, edge = edge, shown = shown, attached = attached,
        width = settings.frameWidth + (occupiesBar and edge or 0),
        left = occupiesBar and side == "left" and edge or 0,
        right = occupiesBar and side == "right" and edge or 0,
    }
end

function Layout.BarAnchor(frame, stackedPower)
    return (stackedPower and frame.Power) or frame.Health
end

-- The layout reserves these widths, even when the actual glyphs are narrower.
-- Retaining the reservations preserves name truncation in existing profiles.
local TEXT_RESERVATIONS = {
    perhpnosign = 40,
    curhpshort = 48, perhp = 48, deficit = 48, perpp = 48, curpp = 48,
    curhp = 70,
    both = 85, perhpnum = 85, curhp_curpp = 85, perhp_perpp = 85,
    curhp_perhp = 100,
}
function Layout.TextWidth(content)
    return TEXT_RESERVATIONS[content] or 10
end

-- Preserve the classification-based background rule. It deliberately does not
-- infer mana capacity: that would change which NPCs receive the muted backdrop.
function Layout.MutedEnemy(unit)
    if unit == "player" or not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsPlayer(unit) then
        return false
    end
    local classification = UnitClassification(unit)
    local elite = classification == "elite" or classification == "rareelite"
    local level, playerLevel = UnitLevel(unit), UnitLevel("player")
    local elevated = elite and (level == -1 or (playerLevel and level >= playerLevel + 1))
    -- An enemy NPC's class can come back secret on Forever: it cannot be
    -- compared, so an unreadable class does not count as a paladin.
    local classBase = UnitClassBase and UnitClassBase(unit)
    local paladin = not (issecretvalue and issecretvalue(classBase)) and classBase == "PALADIN"
    return classification ~= "worldboss" and not elevated and not paladin
end

function Layout.ApplyPowerBackdrop(frame, unit, position)
    if position ~= "below" and position ~= "above" then return end
    if Layout.MutedEnemy(unit) and frame.Power.bg then
        frame.Power.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
        frame.Power.bg:SetAlpha(1)
    end
end

-- This is a recognition value for old saved profiles, not a new colour default.
local LEGACY_CASTBAR = { r = 0.114, g = 0.655, b = 0.514 }
function Layout.IsLegacyCastbarColor(color)
    return color
        and math.abs((color.r or 0) - LEGACY_CASTBAR.r) < 0.001
        and math.abs((color.g or 0) - LEGACY_CASTBAR.g) < 0.001
        and math.abs((color.b or 0) - LEGACY_CASTBAR.b) < 0.001
end

-- Apply a portrait/bar stack using the measured portrait width after pixel
-- rounding. Callers add unit-specific art and castbar handling afterwards.
function Layout.RefreshStack(kit, pp, frame, unit, settings, portraitShown, defaultSide)
    local powerPosition = settings.powerPosition or "below"
    local stackHeight = settings.healthHeight + kit.PowerStack(settings, 6)
    local _, attached = kit.PortraitState(settings)
    local fit = Layout.Portrait(settings, portraitShown, attached, stackHeight, defaultSide)
    local top = kit.BtbTopRise(settings)
    local dy = (settings.portraitY or 0) + (attached and 0 or Layout.DetachedPortraitY)

    pp.Size(frame, fit.width, stackHeight + kit.BtbExtra(settings))
    if frame.Portrait and frame.Portrait.backdrop then
        kit.SeatPortrait(frame, settings, fit.side, fit.attached, fit.edge, top,
            settings.portraitX or 0, dy, portraitShown and attached)
    end
    if frame.Health then
        frame.Health:ClearAllPoints()
        fit.left, fit.right = kit.SnapInsets(frame, portraitShown, attached, fit.side, fit.left, fit.right)
        kit.AnchorHealth(frame, settings, fit.left, fit.right, top + kit.PowerAbove(settings, 6))
    end
    if frame.Power then kit.PlacePower(frame, settings, powerPosition, 6) end
    kit.RefreshTexts(frame, settings, "perhp")
    fit.barAnchor = Layout.BarAnchor(frame, powerPosition == "below" or powerPosition == "above")
    return fit
end
