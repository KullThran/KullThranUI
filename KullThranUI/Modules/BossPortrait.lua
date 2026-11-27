-- Small round boss portraits for the dungeon trackers and their installer
-- previews (Retail Mythic+ Timer, Forever Dungeon Tracker). One file for both
-- clients: it only draws a creature display as a circle and, when asked,
-- reads the display of a unit the player can see.
local _, ns = ...
local _G = _G
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local type, pcall = type, pcall
local CreateFrame = _G.CreateFrame

local BossPortrait = {}
KT.BossPortrait = BossPortrait

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local PLACEHOLDER = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Plain(value)
    local secret = _G.issecretvalue
    if secret and secret(value) then return nil end
    return value
end

-- A holder frame with a dark ring, the masked portrait and nothing else.
function BossPortrait.Create(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(16, 16)
    holder:Hide()
    local ring = holder:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetPoint("CENTER")
    ring:SetColorTexture(0, 0, 0, 0.9)
    local ringMask = holder:CreateMaskTexture()
    ringMask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ringMask:SetAllPoints(ring)
    ring:AddMaskTexture(ringMask)
    local portrait = holder:CreateTexture(nil, "ARTWORK", nil, 2)
    portrait:SetPoint("CENTER")
    local mask = holder:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(portrait)
    portrait:AddMaskTexture(mask)
    holder.ring, holder.portrait = ring, portrait
    return holder
end

-- Shows a creature display (or the placeholder when there is none) at the
-- given size. A killed boss is shown grey and dimmed.
function BossPortrait.Set(holder, displayID, killed, size)
    if not holder then return end
    size = math.max(8, math.floor(size or 16))
    holder:SetSize(size, size)
    holder.ring:SetSize(size, size)
    holder.portrait:SetSize(size - 2, size - 2)
    local shown = false
    local setter = _G.SetPortraitTextureFromCreatureDisplayID
    if type(displayID) == "number" and displayID > 0 and type(setter) == "function" then
        shown = pcall(setter, holder.portrait, displayID) and true or false
        if shown then holder.portrait:SetTexCoord(0, 1, 0, 1) end
    end
    if not shown then
        holder.portrait:SetTexture(PLACEHOLDER)
        holder.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    holder.portrait:SetDesaturated((killed or not shown) and true or false)
    holder.portrait:SetAlpha(killed and 0.55 or (shown and 1 or 0.6))
    holder:Show()
end

-- The creature display of a unit the player can see, or nil. A tiny,
-- invisible model reads it; nothing is drawn.
local reader
function BossPortrait.DisplayFromUnit(unit)
    if type(unit) ~= "string" then return nil end
    local exists = _G.UnitExists
    if type(exists) == "function" and not Plain(exists(unit)) then return nil end
    if not reader then
        reader = CreateFrame("PlayerModel", nil, _G.UIParent)
        reader:SetSize(1, 1)
        reader:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMRIGHT", 10, -10)
        reader:SetAlpha(0)
        reader:EnableMouse(false)
    end
    if not (reader.SetUnit and reader.GetDisplayInfo) then return nil end
    reader:Show()
    local ok = pcall(reader.SetUnit, reader, unit)
    local id
    if ok then
        local okRead, value = pcall(reader.GetDisplayInfo, reader)
        id = okRead and Plain(value) or nil
    end
    pcall(reader.ClearModel, reader)
    reader:Hide()
    if type(id) == "number" and id > 0 then return id end
    return nil
end

-- Sample bosses for test modes and installer previews: the Deadmines' Mr.
-- Smite, Cookie and Edwin VanCleef, displays found in both clients.
BossPortrait.SAMPLE_DISPLAYS = { 2026, 1305, 2029 }
