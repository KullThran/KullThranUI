if KT_CLIENT_BLOCKED then return end

local _, ns = ...
local AK = _G.KTAuraKit
if not AK then return end

local function Flow(token)
    local fd = AnchorUtil and AnchorUtil.FlowDirection
    if not fd then return nil end
    if token == "LEFT" then return fd.Left end
    if token == "UP" then return fd.Up end
    if token == "DOWN" then return fd.Down end
    return fd.Right
end

local function StyleKey(frame, kind)
    return "ktpf:" .. tostring(frame.mode or "party") .. ":" .. kind
end

local function DispelStylePrefix(frame)
    return 'ktpf:dispel:' .. tostring(frame)
end

local DISPEL_TYPES = {
    { "Magic", "dispelColorMagic", 0.349, 0.475, 1.000 },
    { "Curse", "dispelColorCurse", 0.636, 0.000, 0.640 },
    { "Disease", "dispelColorDisease", 0.671, 0.384, 0.098 },
    { "Poison", "dispelColorPoison", 0.000, 0.706, 0.286 },
    { "Bleed", "dispelColorBleed", 0.750, 0.150, 0.150 },
}

local function BuildDispelColorMap(db)
    local map, fp = {}, {}
    for i = 1, #DISPEL_TYPES do
        local def = DISPEL_TYPES[i]
        local c = db[def[2]]
        local r = (c and c.r) or def[3]
        local g = (c and c.g) or def[4]
        local b = (c and c.b) or def[5]
        map[def[1]] = CreateColor and CreateColor(r, g, b, 1) or { r = r, g = g, b = b, a = 1 }
        fp[#fp + 1] = string.format("%.3f,%.3f,%.3f", r, g, b)
    end
    return map, table.concat(fp, ";")
end

local function ConfigureStyle(frame, db, kind, size)
    local key = StyleKey(frame, kind)
    local dispelColorMap, dispelColorFP = BuildDispelColorMap(db)
    AK.styles[key] = {
        width = size, height = size,
        texCoord = { 0.08, 0.92, 0.08, 0.92 },
        border = { 0, 0, 0, 0.9, size = 1 },
        dispelBorder = kind ~= "buffs",
        dispelBorderPx = tonumber(db.dispelBorderThickness) or 2,
        dispelColorMap = dispelColorMap,
        dispelColorFP = dispelColorFP,
        cooldownReverse = true,
        noTooltips = false,
        durationFontSize = math.max(8, math.min(11, math.floor(size * 0.42 + 0.5))),
        durationPoint = "CENTER",
        durationRelPoint = "CENTER",
        durationX = 0,
        durationY = 0,
        stackFontSize = math.max(8, math.min(11, math.floor(size * 0.42 + 0.5))),
    }
    return key
end
local function BuildAuraContainerSpec(frame, db, kind, filter, count, size)
    local key = ConfigureStyle(frame, db, kind, size)
    -- processAura is intentionally absent: SetAuraProcessingPolicy has caused
    -- internal engine crashes (TableUtil.lua:266) with both tables and functions.
    return {
        point = { "CENTER", frame.health, "CENTER" },
        groups = {{
            key = "pf", filter = filter, maxFrameCount = count,
            style = key,
            layout = { elementWidth = size, elementHeight = size,
                elementSpacing = tonumber(db.auraIconSpacing) or 0,
                lineSpacing = tonumber(db.auraIconSpacing) or 0 },
        }},
    }
end

local function ConfigureDispelStyles(frame, db)
    local prefix = DispelStylePrefix(frame)
    AK.ConfigureDispelSlotStyles(prefix, frame.health, {
        colors = db,
        alpha = tonumber(db.dispelOverlayAlpha) or 1,
        thickness = tonumber(db.dispelBorderThickness) or 2,
        gradientAlpha = tonumber(db.dispelGradientAlpha) or 1,
        gradientSize = tonumber(db.dispelGradientSize) or 0.50,
    })
    return prefix
end

local function BuildDispelSlots(prefix, health)
    local slots = AK.BuildDispelSlotSpecs(prefix)
    for i = 1, #slots do
        slots[i].extraInit = function(button)
            button:SetPoint('CENTER', health, 'CENTER')
            button:SetFrameLevel(health:GetFrameLevel() + 1)
        end
    end
    return slots
end

local function ReleaseBundle(bundle)
    if not bundle then return end
    for _, key in ipairs({ "buffs", "debuffs", "cc", "dispel" }) do
        local container = bundle[key]
        if container then
            if AK.ReleaseContainer then
                AK.ReleaseContainer(container)
            else
                container:SetUnit("none")
                container:Hide()
            end
        end
    end
end

-- Creating an AuraContainer group eagerly asks Blizzard for a ten-button batch.
-- A battleground roster can expose many fresh raid frames in the same update, so
-- building all four containers synchronously can exhaust the script watchdog and
-- leave Blizzard's private aura tables half-initialized. Build one bounded engine
-- atom per shared AuraKit scheduler step instead; until the bundle is ready the
-- existing manual renderer remains active for the frame.
local function QueueBundleBuild(frame, db)
    frame._ktAuraBuildDB = db
    if frame._ktAuraBuildQueued then return end

    frame._ktAuraBuildGeneration = (frame._ktAuraBuildGeneration or 0) + 1
    local generation = frame._ktAuraBuildGeneration
    frame._ktAuraBuildQueued = true

    local size = math.max(10, math.min(28, tonumber(db.auraIconSize) or 18))
    local debuffSize = math.max(size, (frame.mode == "raid" or frame.mode == "raid40") and 22 or 24)
    local parent = frame.auraFrame or frame
    local baseLevel = (frame.auraFrame and frame.auraFrame:GetFrameLevel() or frame:GetFrameLevel())
    local b = {}
    b.dispelPrefix = ConfigureDispelStyles(frame, db)
    local specs = {
        dispel = {
            point = { 'CENTER', frame.health, 'CENTER' },
            slots = BuildDispelSlots(b.dispelPrefix, frame.health),
        },
        buffs = BuildAuraContainerSpec(frame, db, "buffs", { "HELPFUL" }, 5, size),
        debuffs = BuildAuraContainerSpec(frame, db, "debuffs", { "HARMFUL", "!CROWD_CONTROL" }, 5, debuffSize),
        cc = BuildAuraContainerSpec(frame, db, "cc", { "HARMFUL", "CROWD_CONTROL" }, 1, math.max(size + 2, 18)),
    }
    local stage = 1

    AK.QueueBuildJob(function()
        if frame._ktAuraBuildGeneration ~= generation then
            ReleaseBundle(b)
            return
        end

        if stage == 1 then
            b.dispel = AK.CreateContainerShell(parent, specs.dispel)
            b.dispel:SetFrameLevel(baseLevel + 20)
        elseif stage >= 2 and stage <= 6 then
            AK.AddSlotToContainer(b.dispel, specs.dispel.slots[stage - 1])
        elseif stage == 7 then
            AK.FinishContainer(b.dispel, "none")
        elseif stage == 8 then
            b.buffs = AK.CreateContainerShell(parent, specs.buffs)
            b.buffs:SetFrameLevel(baseLevel + 1)
        elseif stage == 9 then
            AK.AddGroupToContainer(b.buffs, specs.buffs.groups[1])
        elseif stage == 10 then
            AK.FinishContainer(b.buffs, "none")
        elseif stage == 11 then
            b.debuffs = AK.CreateContainerShell(parent, specs.debuffs)
            b.debuffs:SetFrameLevel(baseLevel + 1)
        elseif stage == 12 then
            AK.AddGroupToContainer(b.debuffs, specs.debuffs.groups[1])
        elseif stage == 13 then
            AK.FinishContainer(b.debuffs, "none")
        elseif stage == 14 then
            b.cc = AK.CreateContainerShell(parent, specs.cc)
            b.cc:SetFrameLevel(baseLevel + 1)
        elseif stage == 15 then
            AK.AddGroupToContainer(b.cc, specs.cc.groups[1])
        elseif stage == 16 then
            AK.FinishContainer(b.cc, "none")
        end

        stage = stage + 1
        if stage <= 16 then return "again" end

        frame.ktAuraContainers = b
        frame._ktAuraBuildQueued = nil
        frame._ktAuraContainerUnit = nil
        frame._ktAuraLayoutHash = nil
        local currentDB = frame._ktAuraBuildDB
        if currentDB and type(frame.unit) == "string" and not frame.fakeUnit then
            local ready = ns.PF_UpdateAuraContainers(frame, currentDB)
            if ready and ns.PF_OnAuraContainersReady then
                ns.PF_OnAuraContainersReady(frame)
            end
        end
    end, "PartyFrames aura bundle")
end

local function Ensure(frame, db)
    if frame.ktAuraContainers then return frame.ktAuraContainers end
    QueueBundleBuild(frame, db)
end

local function Bind(c, unit)
    c:SetUnit(unit or "none")
    if unit then c:UpdateAllAuras() end
end

function ns.PF_BindAuraContainers(frame, unit)
    local b = frame and frame.ktAuraContainers
    if not b then return end
    if frame._ktAuraContainerUnit == unit then return end
    Bind(b.buffs, unit)
    Bind(b.debuffs, unit)
    Bind(b.cc, unit)
    Bind(b.dispel, unit)
    frame._ktAuraContainerUnit = unit
end

-- Unbinds the containers (SetUnit "none") so the engine discards their buttons.
-- Used when the frame's unit is out of range / line of sight: aura data becomes
-- unavailable, UNIT_AURA stops firing, and without this the container keeps the
-- stale buttons from whoever occupied the frame last (duplicate-looking debuffs
-- on out-of-sight raid frames).
function ns.PF_UnbindAuraContainers(frame)
    local b = frame and frame.ktAuraContainers
    if not b then return end
    b.buffs:SetUnit("none")
    b.debuffs:SetUnit("none")
    b.cc:SetUnit("none")
    b.buffs:Hide()
    b.debuffs:Hide()
    b.cc:Hide()
    b.dispel:SetUnit('none')
    b.dispel:Hide()
    frame._ktAuraContainerUnit = nil
end

local function Layout(c, point, relative, relativePoint, x, y, anchor, gh, gv, size, spacing)
    c:ClearAllPoints()
    c:SetPoint(point, relative, relativePoint, x, y)
    AK.SetContainerAnchor(c, anchor)
    local h, v = Flow(gh), Flow(gv)
    if h and v then AK.SetContainerGrowth(c, h, v) end
    c:SetAuraGroupLayout("pf", {
        elementWidth = size, elementHeight = size,
        elementSpacing = spacing, lineSpacing = spacing,
    })
end

function ns.PF_UpdateAuraContainers(frame, db)
    if not (frame and db) or frame.fakeUnit or type(frame.unit) ~= "string" then return false end
    local size = math.max(10, math.min(28, tonumber(db.auraIconSize) or 18))
    local raid = frame.mode == "raid" or frame.mode == "raid40"
    local debuffSize = math.max(size, raid and 22 or 24)
    local ccSize = raid and math.max(size, 16) or math.max(size + 2, 18)
    local spacing = math.max(0, math.min(8, tonumber(db.auraIconSpacing) or 0))
    local maxBuffs = (db.showAuras == false or db.showBuffs == false) and 0
        or math.max(0, math.min(5, tonumber(db.auraMaxBuffs) or 3))
    local maxDebuffs = (db.showAuras == false or db.showDebuffs == false) and 0
        or math.max(0, math.min(5, tonumber(db.auraMaxDebuffs) or 3))
    local maxCC = (db.showAuras == false or db.showCrowdControl == false) and 0 or 1
    
    local bx, by = tonumber(db.buffIconsOffsetX) or 0, tonumber(db.buffIconsOffsetY) or 0
    local dx, dy = tonumber(db.debuffIconsOffsetX) or 0, tonumber(db.debuffIconsOffsetY) or 0
    local ax, ay = tonumber(db.auraIconOffsetX) or 0, tonumber(db.auraIconOffsetY) or 0
    local debuffAnchor = db.debuffAnchor or (raid and "BOTTOMLEFT" or "CENTER")
    local debuffGrowthH = db.debuffGrowthH or "RIGHT"
    local debuffGrowthV = db.debuffGrowthV or "DOWN"
    local debuffStartX = dx
    if debuffAnchor == "CENTER" and maxDebuffs > 1 then
        local centerShift = ((maxDebuffs - 1) * (debuffSize + spacing)) * 0.5
        debuffStartX = dx + (debuffGrowthH == "LEFT" and centerShift or -centerShift)
    end

    -- maxFrameCount changes are structural. Releasing the old bundle prevents
    -- inactive engine buttons from remaining stacked over the replacement. The
    -- first count stamp is not a change: the old order built a fresh bundle, saw
    -- nil here, and immediately destroyed/rebuilt it a second time for every new
    -- battleground member.
    local counts = maxBuffs .. ":" .. maxDebuffs .. ":" .. maxCC
    if frame.ktAuraContainers and frame._ktAuraCounts and frame._ktAuraCounts ~= counts then
        local old = frame.ktAuraContainers
        frame.ktAuraContainers = nil
        frame._ktAuraContainerUnit = nil
        frame._ktAuraLayoutHash = nil
        ReleaseBundle(old)
    end
    frame._ktAuraCounts = counts

    local b = Ensure(frame, db)
    if not b then return false end
    ConfigureDispelStyles(frame, db)

    -- LAYOUT signature: pure geometry. SetAuraGroupLayout / SetContainerAnchor
    -- re-position the existing buttons in place without creating or discarding
    -- any, so mutating them is leak-free and cheap.
    local hash = strjoin(":", size, tostring(raid), spacing, bx, by, dx, dy, ax, ay,
        debuffAnchor, debuffGrowthH, debuffGrowthV)
    if frame._ktAuraLayoutHash ~= hash then
        frame._ktAuraLayoutHash = hash

        -- Enemy buffs and allied harmful details are engine-filtered automatically in 12.1.
        b.buffs:SetAuraGroupMaxFrameCount("pf", frame.mode == "arenaEnemy" and 0 or maxBuffs)
        b.debuffs:SetAuraGroupMaxFrameCount("pf", maxDebuffs)
        b.cc:SetAuraGroupMaxFrameCount("pf", maxCC)

        Layout(b.buffs, "TOPRIGHT", frame.health, "TOPRIGHT", -3 + bx, -3 + by,
            "TOPRIGHT", "LEFT", "DOWN", size, spacing)
        local debuffY = dy + (raid and -3 or 0)
        Layout(b.debuffs, debuffAnchor, frame.health, debuffAnchor, debuffStartX, debuffY,
            debuffAnchor, debuffGrowthH, debuffGrowthV, debuffSize, spacing)
        Layout(b.cc, "CENTER", frame.health, "CENTER", ax, ay,
            "CENTER", "RIGHT", "DOWN", ccSize, spacing)
    end

    ns.PF_BindAuraContainers(frame, frame.unit)
    b.buffs:SetShown(maxBuffs > 0 and frame.mode ~= "arenaEnemy")
    b.debuffs:SetShown(maxDebuffs > 0)
    b.cc:SetShown(maxCC > 0)
    b.dispel:SetShown(db.showDispelOverlay ~= false)
    return true
end
