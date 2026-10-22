-------------------------------------------------------------------------------
--  Party Frames portrait auras: the most important aura of a unit drawn over its portrait.
--
--  Same feature as the Unit Frames one (KullThranUI/Modules/PortraitAuraShared.lua holds the
--  tiers, the spell catalog and the slot logic), with one host per party frame:
--      * the host lives on frame.portraitFrame, which is permanent, so it survives every
--        layout change and portrait rebuild;
--      * the frame is recycled between units, so the host follows frame.unit: the container is
--        re-bound whenever SetFrameUnit runs (PF_BindAuraContainers) and unbound while the
--        unit is out of range (PF_UnbindAuraContainers), like the other aura containers;
--      * the settings are per mode (party, raid, arena...) and flat in the mode table, keys
--        portraitAuras* (see M.DEFAULTS).
--  Test frames have no unit: they show a preview icon instead.
-------------------------------------------------------------------------------
if KT_CLIENT_BLOCKED then return end

local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT.PortraitAuraShared
if not S then return end

local M = ns.PF_PortraitAuras or {}
ns.PF_PortraitAuras = M

M.DEFAULTS = {
    portraitAurasEnabled = false,
    portraitAurasReverse = true,
    portraitAurasNumbers = true,
    portraitAurasFontScale = 1,
    portraitAurasSpells = "",
    portraitAurasCC = true,
    portraitAurasDisarm = true,
    portraitAurasBigDef = true,
    portraitAurasExtDef = true,
    portraitAurasImportant = false,
}

-- Category (tier.opt) -> key in the mode table.
M.CATEGORY_KEYS = {
    crowdControl = "portraitAurasCC",
    disarm = "portraitAurasDisarm",
    bigDefensive = "portraitAurasBigDef",
    externalDefensive = "portraitAurasExtDef",
    important = "portraitAurasImportant",
}

local function Opt(db, key)
    local v = db and db[key]
    if v == nil then return M.DEFAULTS[key] end
    return v
end
M.Get = Opt

-- Catalog sets are the same for every frame: one cache per custom-id text.
local caches, cacheCount = {}, 0
local function CatalogSets(db)
    local text = Opt(db, "portraitAurasSpells")
    if type(text) ~= "string" then text = "" end
    local cache = caches[text]
    if not cache then
        if cacheCount >= 8 then caches, cacheCount = {}, 0 end
        cache = {}
        caches[text] = cache
        cacheCount = cacheCount + 1
    end
    return S.GetCatalogSets(cache, text)
end

-------------------------------------------------------------------------------
--  Preview (test frames have no unit)
-------------------------------------------------------------------------------
local previews, previewTicker = {}, nil

local function RestartPreviews()
    local now = GetTime()
    for host in pairs(previews) do
        if host.preview then host.preview.cooldown:SetCooldown(now, S.PREVIEW_DURATION) end
    end
end

local function SetPreviewShown(host, show)
    if show then
        local p = S.EnsurePreview(host)
        S.StylePreview(p, Opt(host.db, "portraitAurasReverse"), Opt(host.db, "portraitAurasNumbers"))
        if not previews[host] then
            previews[host] = true
            p:Show()
            p.cooldown:SetCooldown(GetTime(), S.PREVIEW_DURATION)
        end
        if not previewTicker and C_Timer and C_Timer.NewTicker then
            previewTicker = C_Timer.NewTicker(S.PREVIEW_DURATION, RestartPreviews)
        end
    elseif previews[host] then
        previews[host] = nil
        if host.preview then host.preview:Hide() end
        if previewTicker and next(previews) == nil then
            previewTicker:Cancel()
            previewTicker = nil
        end
    end
end

-------------------------------------------------------------------------------
--  Host (one per party frame)
-------------------------------------------------------------------------------
local function StyleKey(frame) return "ktpf:portrait:" .. (frame.GetName and frame:GetName() or tostring(frame)) end

local function BuildStyle(frame, db)
    local width = frame.portraitFrame and frame.portraitFrame.GetWidth and frame.portraitFrame:GetWidth()
    return S.BuildStyle(width, Opt(db, "portraitAurasReverse"), Opt(db, "portraitAurasNumbers"), Opt(db, "portraitAurasFontScale"))
end

local function WantTier(host)
    return function(tier) return Opt(host.db, M.CATEGORY_KEYS[tier.opt]) == true end
end

-- The unit the container should read: nothing for test frames, empty slots and frames whose
-- unit is out of range (aura data is gone there, the buttons would be stale).
local function ActiveUnit(frame, host)
    if not host.wanted or host.suppressed or frame.fakeUnit then return nil end
    local unit = frame.unit
    if type(unit) ~= "string" then return nil end
    return unit
end

-------------------------------------------------------------------------------
--  Placement: the icon covers what shows of the portrait, nothing more
-------------------------------------------------------------------------------
-- circle_mask.tga is opaque on 102 of its 128 pixels.
local CIRCLE_MASK = ns.PF_Portrait.media .. "circle_mask.tga"
local CIRCLE_FILL = 102 / 128
-- The icon draws above the native ring: it stops a little short of the hole so the ring line
-- stays whole.
local NATIVE_FIT = 0.94

-- The host gets its own mask, laid over the same rect as the icons, and the cooldowns swipe
-- with that same mask file, so the dark swipe matches the icon instead of spilling past it.
local function Place(frame, host)
    local portrait = frame.portraitFrame
    local root = host.frame
    local maskPath
    root:ClearAllPoints()
    if frame._pfNativeStyle then
        -- Native cards (PartyFrames_Styles.lua) grow the portrait frame past the ring hole
        -- (_pfNativePad on each side): only a circle the size of the hole shows through.
        local width = portrait:GetWidth() or 0
        local hole = width - 2 * (frame._pfNativePad or 0)
        local circle = math.min(width * CIRCLE_FILL, hole * NATIVE_FIT)
        local size = math.max(1, circle / CIRCLE_FILL)
        root:SetPoint("CENTER", portrait, "CENTER", 0, 0)
        root:SetSize(size, size)
        maskPath = CIRCLE_MASK
    else
        -- KUI portraits: the same rect and shape as frame.portraitMask (SetMask in
        -- PartyFrames.lua), square portraits fill the whole frame.
        maskPath = frame._portraitMaskAdded and frame._portraitMaskPath or nil
        local inset = maskPath and 1 or 0
        ns.PF_Portrait.Point(root, "TOPLEFT", portrait, "TOPLEFT", inset, -inset)
        ns.PF_Portrait.Point(root, "BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -inset, inset)
    end

    local mask
    if maskPath then
        mask = host.shapeMask
        if not mask then
            mask = root:CreateMaskTexture()
            mask:SetAllPoints(root)
            host.shapeMask = mask
        end
        if host.shapePath ~= maskPath then
            mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            host.shapePath = maskPath
        end
    end
    S.SeatMask(host, mask, maskPath or S.SQUARE_SWIPE)
end
M.Place = function(frame)
    local host = frame and frame._ktPortraitAuras
    if host then Place(frame, host) end
end

function M.Apply(frame)
    local host = frame and frame._ktPortraitAuras
    if not host then return end
    local db = host.db
    local unit = ActiveUnit(frame, host)

    S.SyncStyle(host.styleKey, BuildStyle(frame, db))
    Place(frame, host)

    -- Test frames show a fake icon for as long as the feature is on.
    SetPreviewShown(host, host.wanted and frame.fakeUnit ~= nil)

    local container = host.container
    if not container then return end
    host.unit = unit
    local desired = unit or "none"
    local bindChanged = host.boundUnit ~= desired
    if bindChanged then
        container:SetUnit(desired)
        host.boundUnit = desired
    end
    local changed = S.UpdateSlots(host, unit ~= nil, WantTier(host), CatalogSets(db))
    if (bindChanged or changed) and host.shown and unit then
        container:UpdateAllAuras()
    end
end

-- The container is built in bounded steps, one per AuraKit scheduler tick, so a battleground
-- roster full of fresh frames cannot stack its work into one frame.
local function CreateHost(frame, db)
    local AK = _G.KTAuraKit
    if not (AK and AK.QueueBuildJob and AK.CreateContainerShell and frame.portraitFrame) then return nil end

    local host = { owner = frame, db = db, icons = {}, cooldowns = {}, buttonOrder = {}, boundUnit = "none" }
    host.frame = CreateFrame("Frame", nil, frame.portraitFrame)
    host.frame:SetAllPoints(frame.portraitFrame)
    host.frame:EnableMouse(false)
    host.styleKey = StyleKey(frame)
    AK.styles[host.styleKey] = BuildStyle(frame, db)
    -- Disarms and extra crowd control only work on units you cannot assist: arena enemies.
    local slots = S.BuildSlots(host, host.styleKey, CatalogSets(db), frame.mode ~= "arenaEnemy")
    frame._ktPortraitAuras = host

    local stage, building = 0, nil
    AK.QueueBuildJob(function()
        stage = stage + 1
        if stage == 1 then
            building = AK.CreateContainerShell(host.frame, { point = { "CENTER", host.frame, "CENTER" } })
            building:SetAllPoints(host.frame)
        elseif stage <= #slots + 1 then
            AK.AddSlotToContainer(building, slots[stage - 1])
        else
            AK.FinishContainer(building, "none")
            host.container = building
            M.Apply(frame)
            if ns.PF_Portrait and ns.PF_Portrait.SyncLevels then ns.PF_Portrait.SyncLevels(frame) end
            return
        end
        return "again"
    end, "PartyFrames portrait auras")
    return host
end

-- Called after every portrait paint: `shown` is whether the portrait is on screen.
function M.Sync(frame, db, shown)
    if not frame then return end
    local wanted = shown and Opt(db, "portraitAurasEnabled") == true
    local host = frame._ktPortraitAuras
    if not host then
        if not wanted then return end
        host = CreateHost(frame, db)
        if not host then return end
    end
    host.db = db
    host.wanted = wanted and true or false
    M.Apply(frame)
end

-------------------------------------------------------------------------------
--  Unit changes (frame recycling) and range, called from PartyFrames_AuraContainers.lua
-------------------------------------------------------------------------------
function M.Bind(frame, unit)
    local host = frame and frame._ktPortraitAuras
    if not host then return end
    host.suppressed = nil
    local desired = (host.wanted and not frame.fakeUnit and type(unit) == "string") and unit or "none"
    if host.boundUnit ~= desired or host.unit ~= (desired ~= "none" and desired or nil) then M.Apply(frame) end
end

function M.Unbind(frame)
    local host = frame and frame._ktPortraitAuras
    if not host then return end
    host.suppressed = true
    if host.container and host.boundUnit ~= "none" then
        host.container:SetUnit("none")
        host.boundUnit = "none"
        host.unit = nil
    end
end

-------------------------------------------------------------------------------
--  Frame levels (PartyFrames.lua SyncLevels)
-------------------------------------------------------------------------------
-- Levels the host needs between the portrait model and the ring: one per tier plus the frame.
function M.LevelGap(frame)
    local host = frame and frame._ktPortraitAuras
    if host and host.wanted then return #S.TIERS + 1 end
    return 0
end

function M.Raise(frame, base)
    local host = frame and frame._ktPortraitAuras
    if host and host.wanted then S.StackLevels(host, base) end
end
