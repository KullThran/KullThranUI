-------------------------------------------------------------------------------
--  Portrait auras, shared part (Unit Frames and Party Frames).
--
--  One icon per category, stacked by priority (the highest one that exists wins):
--      Crowd Control > Disarm > Big Defensive > External Defensive > Important
--
--  The categories are the client's own aura flags (CROWD_CONTROL, BIG_DEFENSIVE,
--  EXTERNAL_DEFENSIVE, IMPORTANT), evaluated by the engine, so they keep working while
--  aura data is secret. Each category is a single-icon AuraKit slot; the engine hides an
--  empty slot, so the next one down shows through.
--
--  This file holds what both modules need: the tier list, the spell catalog sets, the unit
--  checks, the slot specs, the slot switching, the mask seating and the preview icon. A
--  module keeps one "host" table per portrait and passes it in:
--      host = { unit, frame, icons, cooldowns, buttonOrder, slotOn, slotSets, tiers, container }
--  The spell catalog itself is PortraitAuraCatalog.lua (S.Catalog).
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
--  Catalog sets (per client) and unit checks
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
--  Style, slots, masks
-------------------------------------------------------------------------------
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

-- One single-icon slot per tier. `skipSpellIDTiers` drops the disarm and extra crowd control
-- slots (units the player can always assist). Fills host.tiers / slotOn / slotSets and
-- returns the slot specs in tier order.
function S.BuildSlots(host, styleKey, sets, skipSpellIDTiers)
    local slots = {}
    host.tiers, host.slotOn, host.slotSets = {}, {}, {}
    host.icons, host.cooldowns, host.buttonOrder = host.icons or {}, host.cooldowns or {}, host.buttonOrder or {}
    for index, tier in ipairs(S.TIERS) do
        if not (tier.needsSpellIDs and skipSpellIDTiers) then
            host.tiers[index] = tier
            host.slotOn[index] = true
            if tier.catalog then host.slotSets[index] = sets[tier.catalog] end
            slots[#slots + 1] = {
                key = tier.key, filter = tier.filter,
                candidateFilters = S.TierFilters(tier, sets),
                sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ExpirationOnly,
                sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Reverse,
                style = styleKey,
                extraInit = function(button, d)
                    -- Creation window: the only moment button calls are always legal.
                    pcall(button.EnableMouse, button, false)
                    pcall(button.SetAllPoints, button, host.frame)
                    host.buttonOrder[#host.buttonOrder + 1] = button
                    if d.icon then host.icons[#host.icons + 1] = d.icon end
                    if d.cooldown then host.cooldowns[#host.cooldowns + 1] = d.cooldown end
                end,
            }
        end
    end
    return slots
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

-------------------------------------------------------------------------------
--  Slot switching
-------------------------------------------------------------------------------
-- Turns each slot on or off for the unit and the chosen categories. `wantTier(tier)` says
-- whether the user switched the tier's category on. Returns true when anything changed.
function S.UpdateSlots(host, active, wantTier, sets)
    local container = host.container
    if not container then return false end
    local unit = host.unit
    local idsUsable = active and S.CanFilterBySpellID(unit)
    local tokensOk = active and S.AuraTokensReliable(unit)
    local changed, anyOn = false, false

    for index, tier in pairs(host.tiers) do
        local on = active and wantTier(tier)
            and (not tier.needsSpellIDs or idsUsable)
            and (tokensOk or tier.needsSpellIDs) and true or false
        if on then anyOn = true end
        if host.slotOn[index] ~= on then
            host.slotOn[index] = on
            changed = true
            if container.SetAuraSlotEnabled then
                container:SetAuraSlotEnabled(tier.key, on)
            elseif container.SetAuraSlotCandidateFilters then
                container:SetAuraSlotCandidateFilters(tier.key, on and S.TierFilters(tier, sets) or S.OFF_FILTERS)
            end
        end
        -- A catalog that changed (custom ids) is pushed even while the slot stays on.
        if tier.catalog and on then
            local set = sets[tier.catalog]
            if host.slotSets[index] ~= set then
                host.slotSets[index] = set
                changed = true
                if container.SetAuraSlotCandidateFilters then
                    container:SetAuraSlotCandidateFilters(tier.key, S.TierFilters(tier, sets))
                end
            end
        end
    end

    if host.shown ~= anyOn then
        host.shown = anyOn
        changed = true
        container:SetEnabled(anyOn)
        container:SetShown(anyOn)
    end
    return changed
end

-------------------------------------------------------------------------------
--  Preview icon (a fake aura over the portrait, for options pages and test frames)
-------------------------------------------------------------------------------
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
