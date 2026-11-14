-- Aura Reminders, beacons: a row of two plain icons for a Holy Paladin, lit from the spell activation overlay.
-- Reads no aura data, so it works in combat. Same behaviour on both clients; ctx.Known carries what differs.

local _, ns = ...

local tonumber = tonumber

local BOL, BOF, VIRTUE = 53563, 156910, 200025
local SHOW_EVENT = "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
local HIDE_EVENT = "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE"

-- Overlay payloads are recognised by table lookup.
local IS_BEACON = { [BOL] = true, [BOF] = true }

local Beacons = {}
ns.AuraRemindersBeacons = Beacons

-- Context, set at Setup and then only read.
local GetDB, IsOptionsVisible, GetCombatAnchor, IsGrouped, Known, GetPlayerClass
-- The main file's table with db and optionsVisible, kept current by it, so refresh reads them with no call.
-- Without ctx.Live the two closures are used.
local live
local GetSpellTexture, GetShortLabel, PlainIcon, StyleCaption, GlowFromSettings, RemoveGlow, LayoutIconRow

local State              -- published; holds the live flags, the anchor and the icon tables
local icons, iconState   -- the same tables as State.icons and State.iconState
local overlayReader      -- fixed at Setup, may be nil
local eventFrame
local glowApplied = {}   -- spell ID to whether a glow is on
local refreshPending = false

-- Lit icons in fixed order, on the anchor. Runs only when an icon changed.
local function layoutRow()
    local anchor = State.anchor
    if not anchor then return end

    local lightLit, faithLit = iconState[BOL], iconState[BOF]
    if not lightLit and not faithLit then
        anchor:Hide()
        return
    end

    local list = {}
    if lightLit then list[1] = icons[BOL] end
    if faithLit then list[#list + 1] = icons[BOF] end

    anchor:Show()
    -- A database with no profile raises here (G5).
    local scale = 1.0
    local db
    if live then db = live.db else db = GetDB() end
    if db then
        local auras = db.profile.auras
        scale = auras and auras.scale or 1.0
    end
    LayoutIconRow(list, anchor, scale)
end

local function setVisible(spellID, show)
    local icon = icons[spellID]
    if not icon then return end

    local lit = iconState[spellID]
    if show then
        if lit then return end
        StyleCaption(icon, GetShortLabel(spellID == BOL and "Beacon of Light" or "Beacon of Faith"))
        icon:Show()
        iconState[spellID] = true
        GlowFromSettings(icon)
        glowApplied[spellID] = true
        layoutRow()
    else
        if not lit then return end
        if glowApplied[spellID] then
            RemoveGlow(icon)
            glowApplied[spellID] = false
        end
        icon._text:SetText("")
        icon:Hide()
        iconState[spellID] = false
        layoutRow()
    end
end

-- Gates first, then per beacon with the overlay asked last. Any failed gate hides both.
local function refresh()
    if not State.isPaladin then return end

    local wantLight, wantFaith = false, false
    local db
    if live then db = live.db else db = GetDB() end
    local profile = db and db.profile
    if profile and profile.enable ~= false then
        local optionsOpen
        if live then optionsOpen = live.optionsVisible else optionsOpen = IsOptionsVisible() end
        if not optionsOpen and overlayReader
            and not UnitInVehicle("player") and not (IsMounted() and IsFlying())
            and State.inInstance and IsGrouped() then
            local auras = profile.auras
            local enabled = auras and auras.enabled
            if enabled then
                if enabled.bol ~= false and Known(BOL) and not Known(VIRTUE) and overlayReader(BOL) then
                    wantLight = true
                end
                if enabled.bof ~= false and Known(BOF) and overlayReader(BOF) then
                    wantFaith = true
                end
            end
        end
    end

    setVisible(BOL, wantLight)
    setVisible(BOF, wantFaith)
end

-- Reads the zone, then registers or unregisters the overlay events only when the wanted state changed.
local function syncZone()
    local _, instanceType, difficulty = GetInstanceInfo()
    local inInstance = false
    if (tonumber(difficulty) or 0) ~= 0 then
        local garrison = C_Garrison
        local onGarrisonMap = garrison and garrison.IsOnGarrisonMap and garrison.IsOnGarrisonMap()
        if not onGarrisonMap and (instanceType == "party" or instanceType == "raid") then
            inInstance = true
        end
    end
    State.inInstance = inInstance

    if inInstance == State.overlayRegistered then return end
    State.overlayRegistered = inInstance
    if inInstance then
        eventFrame:RegisterEvent(SHOW_EVENT)
        eventFrame:RegisterEvent(HIDE_EVENT)
    else
        eventFrame:UnregisterEvent(SHOW_EVENT)
        eventFrame:UnregisterEvent(HIDE_EVENT)
    end
end

local function onSpellTimer()
    refreshPending = false
    refresh()
end

local function onEvent(_, event, spellID)
    if not State.isPaladin then return end

    if event == SHOW_EVENT or event == HIDE_EVENT then
        if IS_BEACON[spellID] then refresh() end
    elseif event == "GROUP_ROSTER_UPDATE" then
        refresh()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        syncZone()
        refresh()
    elseif not refreshPending then
        -- Spell and talent events: one zero timer, so a burst is one refresh.
        refreshPending = true
        C_Timer.After(0, onSpellTimer)
    end
end

local function makeIcon(spellID)
    local icon = PlainIcon(nil, UIParent, "HIGH", 120)
    icon._icon:SetTexture(GetSpellTexture(spellID))
    icon._spellID = spellID
    icons[spellID] = icon
end

-- Paladins only: icons, anchor, zone sync, first refresh.
local function init()
    if GetPlayerClass() ~= "PALADIN" then return end
    State.isPaladin = true

    makeIcon(BOL)
    makeIcon(BOF)

    local anchor = CreateFrame("Frame", "KUIAR_BeaconAnchor", UIParent)
    anchor:SetSize(1, 1)
    anchor:SetFrameStrata("HIGH")
    anchor:EnableMouse(false)
    anchor:Hide()
    local combatAnchor = GetCombatAnchor()
    if combatAnchor then
        anchor:SetPoint("CENTER", combatAnchor, "CENTER", 0, -60)
    else
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
    State.anchor = anchor

    syncZone()
    refresh()
end

local function getAnchor()
    return State.anchor
end

function Beacons.Setup(ctx)
    GetDB, IsOptionsVisible, GetCombatAnchor = ctx.GetDB, ctx.IsOptionsVisible, ctx.GetCombatAnchor
    IsGrouped, Known, GetPlayerClass = ctx.IsGrouped, ctx.Known, ctx.GetPlayerClass
    GetSpellTexture, GetShortLabel, PlainIcon = ctx.GetSpellTexture, ctx.GetShortLabel, ctx.PlainIcon
    StyleCaption, GlowFromSettings, RemoveGlow = ctx.StyleCaption, ctx.GlowFromSettings, ctx.RemoveGlow
    LayoutIconRow = ctx.LayoutIconRow
    live = ctx.Live

    local overlayApi = C_SpellActivationOverlay
    overlayReader = (overlayApi and overlayApi.IsSpellOverlayed) or IsSpellOverlayed

    icons, iconState = {}, {}
    State = {
        isPaladin = false,
        inInstance = false,
        overlayRegistered = false,
        icons = icons,
        iconState = iconState,
        isSpellOverlayed = overlayReader,
    }

    Beacons.BOL, Beacons.BOF, Beacons.VIRTUE = BOL, BOF, VIRTUE
    Beacons.Init = init
    Beacons.Refresh = refresh
    Beacons.SetVisible = setVisible
    Beacons.State = State

    _G._KUIAR_BeaconRefresh = refresh
    _G._KUIAR_BeaconAnchor = getAnchor

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    eventFrame:SetScript("OnEvent", onEvent)
end
