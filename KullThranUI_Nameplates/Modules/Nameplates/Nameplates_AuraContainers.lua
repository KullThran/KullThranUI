if KT_CLIENT_BLOCKED then return end

local _, ns = ...
local AK = _G.KTAuraKit
if not AK then return end

ns.NPC_OwnsAuras = true

local function Profile()
    return _G.KullThranUINameplatesDB or {}
end

local function Flow(token)
    local fd = AnchorUtil and AnchorUtil.FlowDirection
    if not fd then return nil end
    if token == "LEFT" then return fd.Left end
    if token == "UP" then return fd.Up end
    if token == "DOWN" then return fd.Down end
    return fd.Right
end

local function IsAuraTargetAllowed(unit)
    if not unit then return false end
    local okAttack, canAttack = pcall(UnitCanAttack, "player", unit)
    if not okAttack or canAttack ~= true then return false end
    local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
    if okPlayer and isPlayer then return true end
    local okReaction, reaction = pcall(UnitReaction, unit, "player")
    if okReaction and type(reaction) == "number" and reaction >= 5 then
        return false
    end
    return true
end

local function ClearAuraBundle(bundle)
    if not bundle then return end
    for _, container in pairs(bundle) do
        container:SetUnit("none")
        container:Hide()
    end
end

local DURATION_ANCHORS = {
    center = { point = 'CENTER', x = 0, y = 0 },
    topleft = { point = 'TOPLEFT', x = -3, y = 4 },
    topright = { point = 'TOPRIGHT', x = 3, y = 4 },
}

local function GetDurationPosition(kind, profile)
    local key = kind == 'debuffs' and 'debuffTimerPosition'
        or kind == 'buffs' and 'buffTimerPosition' or 'ccTimerPosition'
    local position = profile[key] or profile.auraTextPosition or 'topleft'
    local anchor = DURATION_ANCHORS[position] or DURATION_ANCHORS.topleft
    return position, anchor
end

local function BuildStyle(kind)
    local p = Profile()
    local size = kind == "debuffs" and ns.GetDebuffIconSize()
        or kind == "buffs" and ns.GetBuffIconSize() or ns.GetCCIconSize()
    local durationPosition, durationAnchor = GetDurationPosition(kind, p)
    return {
        width = size, height = size,
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        border = { 0, 0, 0, 1, size = 1 },
        cooldownReverse = true,
        noTooltips = true,
        durationFontSize = p.auraDurationTextSize or 15,
        durationColor = p.auraDurationTextColor or { r = 1, g = 1, b = 1 },
        durationPoint = durationAnchor.point,
        durationRelPoint = durationAnchor.point,
        durationX = durationAnchor.x,
        durationY = durationAnchor.y,
        hideDurationText = durationPosition == 'none',
        stackFontSize = p.auraStackTextSize or 11,
        stackColor = p.auraStackTextColor or { r = 1, g = 1, b = 1 },
        -- Keep application counts inside the icon. AuraKit's generic default
        -- places them two pixels below it, which overlaps a top-slot health bar.
        stackPoint = 'BOTTOMRIGHT',
        stackX = 1,
        stackY = 1,
    }
end

local function RefreshStyles()
    AK.styles["ktnp:debuffs"] = BuildStyle("debuffs")
    AK.styles["ktnp:buffs"] = BuildStyle("buffs")
    AK.styles["ktnp:cc"] = BuildStyle("cc")
end

local function MakeContainer(plate, kind, filter, maxCount, candidateFilters)
    local size = kind == "debuffs" and ns.GetDebuffIconSize()
        or kind == "buffs" and ns.GetBuffIconSize() or ns.GetCCIconSize()
    return AK.CreateContainer(plate, "none", {
        point = { "CENTER", plate, "CENTER" },
        groups = {{
            key = "np", filter = filter, maxFrameCount = maxCount,
            candidateFilters = candidateFilters,
            style = "ktnp:" .. kind,
            layout = { elementWidth = size, elementHeight = size,
                elementSpacing = ns.GetAuraSpacing(), lineSpacing = ns.GetAuraSpacing() },
        }},
    })
end

local function Ensure(plate)
    if plate.ktAuraContainers then return plate.ktAuraContainers end
    RefreshStyles()
    local p = Profile()
    local bundle = {}
    bundle.debuffs = MakeContainer(plate, "debuffs",
        { "HARMFUL", "PLAYER", "INCLUDE_NAME_PLATE_ONLY", "!CROWD_CONTROL" }, 4,
        p.showAllDebuffs and {} or { nameplateShowPersonal = true })
    bundle.buffs = MakeContainer(plate, "buffs",
        { "HELPFUL", "INCLUDE_NAME_PLATE_ONLY" }, 4,
        p.showAllEnemyBuffs and {} or { isStealable = true })
    bundle.cc = MakeContainer(plate, "cc", { "HARMFUL", "CROWD_CONTROL" }, 2)
    plate.ktAuraContainers = bundle
    plate.ktDebuffCont = bundle.debuffs
    plate.ktBuffCont = bundle.buffs
    return bundle
end

local function Anchor(container, kind, plate, slot)
    container:ClearAllPoints()
    if not slot or slot == "none" then
        container:Hide()
        return
    end
    local p = Profile()
    local x, y = 0, 0
    if ns._AuraLayout and ns._AuraLayout.ResolveOffsets then
        x, y = ns._AuraLayout.ResolveOffsets(kind == "debuffs" and "debuffSlot"
            or kind == "buffs" and "buffSlot" or "ccSlot")
    end
    -- Los slots superiores se anclan por Y encima de la barra de vida, pero el
    -- nombre/top-text ocupa esa misma franja. El path legado de iconos despeja
    -- el texto superior con GetTopTextVerticalLift; los contenedores deben
    -- replicarlo o los iconos caen encima del nombre.
    local lift = 0
    if kind == "debuffs" and (slot == "top" or slot == "topleft" or slot == "topright")
        and ns.GetTopTextVerticalLift and ns.GetTextSlot then
        lift = ns.GetTopTextVerticalLift(plate, ns.GetTextSlot("textSlotTop"))
    end
    local anchorPoint, gh, gv = "BOTTOMLEFT", "RIGHT", "UP"
    if slot == "top" then
        container:SetPoint("BOTTOM", plate.health, "TOP", x, ns.GetDebuffYOffset() + lift + y)
        anchorPoint, gv = "TOPLEFT", "DOWN"
    elseif slot == "left" then
        container:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMLEFT", -ns.GetSideAuraXOffset() + x, y)
        anchorPoint, gh = "BOTTOMRIGHT", "LEFT"
    elseif slot == "right" then
        container:SetPoint("BOTTOMLEFT", plate.health, "BOTTOMRIGHT", ns.GetSideAuraXOffset() + x, y)
    elseif slot == "topleft" then
        container:SetPoint("BOTTOMLEFT", plate.health, "TOPLEFT", x, ns.GetDebuffYOffset() + lift + y)
    elseif slot == "topright" then
        container:SetPoint("BOTTOMRIGHT", plate.health, "TOPRIGHT", x, ns.GetDebuffYOffset() + lift + y)
        anchorPoint, gh = "BOTTOMRIGHT", "LEFT"
    else
        container:Hide()
        return
    end
    AK.SetContainerAnchor(container, anchorPoint)
    local h, v = Flow(gh), Flow(gv)
    if h and v then AK.SetContainerGrowth(container, h, v) end
    local size = kind == "debuffs" and ns.GetDebuffIconSize()
        or kind == "buffs" and ns.GetBuffIconSize() or ns.GetCCIconSize()
    container:SetAuraGroupLayout("np", {
        elementWidth = size, elementHeight = size,
        elementSpacing = ns.GetAuraSpacing(), lineSpacing = ns.GetAuraSpacing(),
    })
    container:Show()
end

function ns.NPC_ApplyVisualSettings(plate)
    if not plate.ktAuraContainers then return end
    if not IsAuraTargetAllowed(plate.unit) then
        ClearAuraBundle(plate.ktAuraContainers)
        plate._ktAuraContainerUnit = nil
        return
    end
    local p = Profile()
    plate.ktAuraContainers.debuffs:SetAuraGroupCandidateFilters("np",
        p.showAllDebuffs and {} or { nameplateShowPersonal = true })
    plate.ktAuraContainers.buffs:SetAuraGroupCandidateFilters("np",
        p.showAllEnemyBuffs and {} or { isStealable = true })
    RefreshStyles()
    AK.RestyleSoon("ktnp:debuffs")
    AK.RestyleSoon("ktnp:buffs")
    AK.RestyleSoon("ktnp:cc")
    local ds, bs, cs = ns.GetAuraSlots()
    Anchor(plate.ktAuraContainers.debuffs, "debuffs", plate, ds)
    Anchor(plate.ktAuraContainers.buffs, "buffs", plate, bs)
    Anchor(plate.ktAuraContainers.cc, "cc", plate, cs)
end

function ns.NPC_Bind(plate, unit)
    local b = Ensure(plate)
    if not IsAuraTargetAllowed(unit) then
        ClearAuraBundle(b)
        plate._ktAuraContainerUnit = nil
        return
    end
    local ds, bs, cs = ns.GetAuraSlots()
    local rows = { { b.debuffs, ds }, { b.buffs, bs }, { b.cc, cs } }
    for i = 1, #rows do
        local c, slot = rows[i][1], rows[i][2]
        c:SetUnit(slot == "none" and "none" or unit)
        if slot ~= "none" then c:UpdateAllAuras() end
    end
    plate._ktAuraContainerUnit = unit
    ns.NPC_ApplyVisualSettings(plate)
    for i = 1, 4 do plate.debuffs[i]:Hide(); plate.buffs[i]:Hide() end
    for i = 1, 2 do plate.cc[i]:Hide() end
end

function ns.NPC_Update(plate)
    if not IsAuraTargetAllowed(plate.unit) then
        ClearAuraBundle(plate.ktAuraContainers)
        plate._ktAuraContainerUnit = nil
        return
    end
    local b = Ensure(plate)
    b.debuffs:UpdateAllAuras()
    b.buffs:UpdateAllAuras()
    b.cc:UpdateAllAuras()
end

function ns.NPC_Unbind(plate)
    local b = plate.ktAuraContainers
    if not b then return end
    for _, c in pairs(b) do
        c:SetUnit("none")
        c:Hide()
    end
    plate._ktAuraContainerUnit = nil
end
