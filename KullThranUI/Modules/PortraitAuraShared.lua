-- Portrait auras: part shared by the Unit Frames and Party Frames modules.
--
-- A portrait shows at most one icon per category; when several categories have an aura the
-- one listed last in S.TIERS draws on top:
--     Crowd Control > Disarm > Big Defensive > External Defensive > Important
--
-- Categories are the client's own aura flags (CROWD_CONTROL, BIG_DEFENSIVE,
-- EXTERNAL_DEFENSIVE, IMPORTANT), resolved by the engine, so they still work while aura data
-- is secret. Every tier becomes one single-icon AuraKit slot (an empty slot hides itself and
-- lets the one below show).
--
-- Provided here: tier list, catalog sets, unit checks, slot specs, the per-host lane ledger
-- that turns slots on and off, mask seating and the preview icon. A module owns one "host"
-- table per portrait and hands it to these functions:
--     host = { unit, frame, icons, cooldowns, buttonOrder, lanes, container, shown, ... }
-- The spell catalog lives in PortraitAuraCatalog.lua (S.Catalog).
local KT = _G.KullThranUI
local S = KT.PortraitAuraShared or {}
KT.PortraitAuraShared = S

S.CATEGORY_DEFAULTS = {
    crowdControl = true, disarm = true, bigDefensive = true, externalDefensive = true, important = false,
}

-- Flagged as crowd control by the client but not crowd control.
S.CC_BLACKLIST = {
    [1280457] = true,   -- Mind Flay (Priest)
}

-- Lowest priority first: later tiers draw above earlier ones.
S.TIERS = {
    { key = "Important", opt = "important", filter = { "HELPFUL", "IMPORTANT", "!BIG_DEFENSIVE", "!EXTERNAL_DEFENSIVE" } },
    { key = "ExtDef",    opt = "externalDefensive", filter = { "HELPFUL", "EXTERNAL_DEFENSIVE", "!BIG_DEFENSIVE" } },
    { key = "BigDef",    opt = "bigDefensive", filter = { "HELPFUL", "BIG_DEFENSIVE" } },
    -- Disarms carry no flag, so the spell-id map is the only filter. The engine honours a
    -- harmful spell-id map only on a unit you cannot assist, so it is off everywhere else.
    { key = "Disarm",    opt = "disarm", filter = { "HARMFUL" }, needsSpellIDs = true, catalog = "disarm" },
    -- Crowd control the client does not flag, plus the ranked Classic spells and your own ids
    -- (PortraitAuraCatalog.lua). Same rule as disarms: enemies only.
    { key = "OtherCC",   opt = "crowdControl", filter = { "HARMFUL" }, needsSpellIDs = true, catalog = "control" },
    { key = "CC",        opt = "crowdControl", filter = { "HARMFUL", "CROWD_CONTROL" },
      candidateFilters = { excludeSpellIDs = S.CC_BLACKLIST } },
}

S.OFF_FILTERS = { includeSpellIDs = {} }
S.ICON_SIZE = 30
S.ROUND_SWIPE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
S.SQUARE_SWIPE = "Interface\\Buttons\\WHITE8X8"
S.PREVIEW_ICON = 136071
S.PREVIEW_DURATION = 8

-- Catalog sets (per client) and unit checks
-- Units the player can always assist, so a harmful spell-id map can never match them.
function S.IsAlwaysAssistable(unit)
    if type(unit) ~= "string" then return false end
    return unit == "player" or unit == "pet" or unit:find("^party%d") ~= nil or unit:find("^raid%d") ~= nil
end

-- The catalog sets for this client. `cache` belongs to the caller; the sets are rebuilt only
-- when the custom ids or the switched-off entries (`version` bumps) changed.
function S.GetCatalogSets(cache, text, disabled, version)
    if type(text) ~= "string" then text = "" end
    local stamp = text .. "|" .. (version or 0)
    if cache.sets and cache.stamp == stamp then return cache.sets end
    local catalog = S.Catalog
    local extra = catalog and catalog.ParseIds and catalog.ParseIds(text)
    local control, disarm = {}, {}
    if catalog and catalog.Build then control, disarm = catalog.Build(extra, disabled) end
    cache.sets = { control = control, disarm = disarm }
    cache.stamp = stamp
    return cache.sets
end

function S.TierFilters(tier, sets)
    if tier.catalog then return { includeSpellIDs = sets[tier.catalog] } end
    return tier.candidateFilters
end

-- The engine matches a harmful spell-id map only on a unit you cannot assist.
function S.CanFilterBySpellID(unit)
    if S.IsAlwaysAssistable(unit) then return false end
    if not (unit and UnitExists(unit)) then return false end
    local ok, assist = pcall(UnitCanAssist, "player", unit, true, true)
    if not ok or (issecretvalue and issecretvalue(assist)) then return false end
    return not assist
end

-- Flag tokens stop being evaluated for a unit that is out of the player's visible world.
function S.AuraTokensReliable(unit)
    if not unit or not UnitExists(unit) then return true end
    local visible = UnitIsVisible(unit)
    if issecretvalue and issecretvalue(visible) then return true end
    return visible and true or false
end

-- Style, slot specs, masks
-- Text scales with the portrait so a small frame does not get an oversized timer.
function S.BuildStyle(portraitWidth, reverseSwipe, showNumbers, fontScale)
    local width = portraitWidth
    if type(width) ~= "number" or width <= 0 then width = 40 end
    local size = math.max(8, math.floor(width * 0.30 * (tonumber(fontScale) or 1) + 0.5))
    return {
        width = S.ICON_SIZE, height = S.ICON_SIZE,
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        cooldownReverse = reverseSwipe ~= false,
        durationFontSize = size,
        durationPoint = "CENTER", durationRelPoint = "CENTER", durationY = 0,
        hideDurationText = showNumbers == false,
        stackFontSize = math.max(8, math.floor(size * 0.7)),
        stackX = -1, stackY = 1,
    }
end

-- Copies a fresh style over the registered one and restyles when something changed.
function S.SyncStyle(styleKey, fresh)
    local AK = _G.KTAuraKit
    local style = AK and AK.styles[styleKey]
    if not style then return end
    local dirty = false
    for k, v in pairs(fresh) do
        if style[k] ~= v then style[k], dirty = v, true end
    end
    if dirty and AK.RestyleSoon then AK.RestyleSoon(styleKey) end
end

-- Slot spec for one tier. Whatever AuraKit creates for the slot (button, icon texture,
-- cooldown) is recorded on the host from the creation callback.
local function SlotSpec(host, tier, styleKey, sets)
    local function adopt(button, parts)
        -- Creation window: the only moment button calls are always legal.
        pcall(button.EnableMouse, button, false)
        pcall(button.SetAllPoints, button, host.frame)
        table.insert(host.buttonOrder, button)
        if parts.icon then table.insert(host.icons, parts.icon) end
        if parts.cooldown then table.insert(host.cooldowns, parts.cooldown) end
    end
    return {
        key = tier.key,
        filter = tier.filter,
        candidateFilters = S.TierFilters(tier, sets),
        sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Reverse,
        style = styleKey,
        extraInit = adopt,
    }
end

-- Creates the slot specs for a host and resets its lane ledger (one lane per tier in use:
-- the tier, whether the slot is currently enabled, and the catalog set last pushed to it).
-- `skipSpellIDTiers` leaves out the tiers that need a spell-id map, for units the player can
-- always assist. Returns the specs in tier order.
function S.BuildSlots(host, styleKey, sets, skipSpellIDTiers)
    host.icons = host.icons or {}
    host.cooldowns = host.cooldowns or {}
    host.buttonOrder = host.buttonOrder or {}
    host.lanes = {}
    local specs = {}
    for _, tier in ipairs(S.TIERS) do
        if skipSpellIDTiers and tier.needsSpellIDs then
            -- not offered for this unit
        else
            table.insert(host.lanes, { tier = tier, on = true, ids = tier.catalog and sets[tier.catalog] or nil })
            table.insert(specs, SlotSpec(host, tier, styleKey, sets))
        end
    end
    return specs
end

-- Puts the portrait's shape mask (nil = square) on every icon and the matching swipe on every
-- cooldown. `swipe` is the swipe texture to use, nil to leave the swipe alone.
function S.SeatMask(host, mask, swipe)
    if host.mask == mask and host.maskSeated and host.swipe == swipe then return end
    for _, tex in ipairs(host.icons) do
        if host.mask and tex.RemoveMaskTexture then pcall(tex.RemoveMaskTexture, tex, host.mask) end
        if mask and tex.AddMaskTexture then pcall(tex.AddMaskTexture, tex, mask) end
    end
    for _, cooldown in ipairs(host.cooldowns) do
        if cooldown.SetSwipeTexture and swipe then cooldown:SetSwipeTexture(swipe) end
    end
    host.mask, host.swipe, host.maskSeated = mask, swipe, true
end

-- Frame levels from `base` up: one level per tier so the higher tier draws on top.
function S.StackLevels(host, base)
    host.frame:SetFrameLevel(base)
    local level = host.frame:GetFrameLevel()
    for index, button in ipairs(host.buttonOrder) do
        pcall(button.SetFrameLevel, button, level + index)
    end
    if host.container then pcall(host.container.SetFrameLevel, host.container, level) end
    if host.preview then host.preview:SetFrameLevel(level + #S.TIERS + 1) end
end

-- Slot switching
-- Should this lane's slot be enabled? `gate` is nil for an inactive portrait, otherwise the
-- unit facts { ids = spell-id maps usable, live = flag tokens evaluated }.
local function LaneWanted(tier, gate, wantTier)
    if not gate or not wantTier(tier) then return false end
    if tier.needsSpellIDs then return gate.ids and true or false end
    return gate.live and true or false
end

-- Switches one slot when its state differs from the ledger. Returns true if it changed.
local function ApplyLaneState(container, lane, enabled, sets)
    if lane.on == enabled then return false end
    lane.on = enabled
    if container.SetAuraSlotEnabled then
        container:SetAuraSlotEnabled(lane.tier.key, enabled)
    elseif container.SetAuraSlotCandidateFilters then
        container:SetAuraSlotCandidateFilters(lane.tier.key, enabled and S.TierFilters(lane.tier, sets) or S.OFF_FILTERS)
    end
    return true
end

-- A catalog set that was replaced (custom ids edited) is pushed to a slot that is on.
local function ApplyLaneIds(container, lane, sets)
    local fresh = sets[lane.tier.catalog]
    if lane.ids == fresh then return false end
    lane.ids = fresh
    if container.SetAuraSlotCandidateFilters then
        container:SetAuraSlotCandidateFilters(lane.tier.key, S.TierFilters(lane.tier, sets))
    end
    return true
end

-- Brings the host's slots in line with the unit and the categories the user chose:
-- `wantTier(tier)` tells whether a tier's category is switched on. The container is shown
-- only while at least one slot is on. Returns true when anything changed.
function S.UpdateSlots(host, active, wantTier, sets)
    local container = host.container
    if not container then return false end

    local gate
    if active then
        gate = { ids = S.CanFilterBySpellID(host.unit), live = S.AuraTokensReliable(host.unit) }
    end

    local changed, anyLane = false, false
    for _, lane in ipairs(host.lanes) do
        local enabled = LaneWanted(lane.tier, gate, wantTier)
        anyLane = anyLane or enabled
        if ApplyLaneState(container, lane, enabled, sets) then changed = true end
        if enabled and lane.tier.catalog and ApplyLaneIds(container, lane, sets) then changed = true end
    end

    if host.shown ~= anyLane then
        host.shown = anyLane
        changed = true
        container:SetEnabled(anyLane)
        container:SetShown(anyLane)
    end
    return changed
end

-- Preview icon: a fake aura over the portrait for options pages and test frames
function S.EnsurePreview(host)
    if host.preview then return host.preview end
    local p = CreateFrame("Frame", nil, host.frame)
    p:SetAllPoints(host.frame)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints(p)
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.icon:SetTexture(S.PREVIEW_ICON)
    p.cooldown = CreateFrame("Cooldown", nil, p, "CooldownFrameTemplate")
    p.cooldown:SetAllPoints(p)
    p.cooldown:SetDrawEdge(false)
    p:Hide()
    host.preview = p
    host.icons[#host.icons + 1] = p.icon
    host.cooldowns[#host.cooldowns + 1] = p.cooldown
    host.maskSeated = nil
    return p
end

function S.StylePreview(p, reverseSwipe, showNumbers)
    p.cooldown:SetReverse(reverseSwipe ~= false)
    p.cooldown:SetHideCountdownNumbers(showNumbers == false)
end
