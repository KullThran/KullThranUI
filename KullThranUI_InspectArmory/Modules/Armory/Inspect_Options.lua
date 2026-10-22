-- Modules/Armory/Inspect_Options.lua
-- Registers the "Inspect Armory" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local GetFontValues = Opt.GetFontValues
local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks

-- Which client's inspect window the preview imitates. Each workspace ships to
-- its own client, so this is fixed per workspace ("retail" or "forever").
local PREVIEW_FLAVOR = "retail"

local function PreviewAccentColor()
    if KT and KT.GetStyleAccentRGB then
        return KT:GetStyleAccentRGB()
    end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
end

local function RefreshInspect()
    local M = KT:GetModule("InspectArmory", true)
    if M and M.Refresh then
        M:Refresh()
    end
end

-------------------------------------------------------------------------------
--  Preview character: a famous Warcraft hero in sample gear, rolled again
--  every time the page opens. Each client has its own roster: Forever only has
--  the classic world's heroes and classes, and its names carry a surname.
--  display is the hero's own creature display (CreatureDisplayInfo), so the 3D
--  model is really that NPC: Retail IDs come from the live Creature table,
--  Forever IDs from Wowhead's Forever database.
-------------------------------------------------------------------------------
local HEROES = {
    retail = {
        { name = "Thrall", class = "SHAMAN", display = 91636 },
        { name = "Jaina Proudmoore", class = "MAGE", display = 46819 },
        { name = "Sylvanas Windrunner", class = "HUNTER", display = 28213 },
        { name = "Arthas Menethil", class = "DEATHKNIGHT", display = 121918 },
        { name = "Varian Wrynn", class = "WARRIOR", display = 28127 },
        { name = "Magni Bronzebeard", class = "WARRIOR", display = 71764 },
        { name = "Tyrande Whisperwind", class = "PRIEST", display = 39620 },
        { name = "Malfurion Stormrage", class = "DRUID", display = 35095 },
        { name = "Illidan Stormrage", class = "DEMONHUNTER", display = 21135 },
        { name = "Cairne Bloodhoof", class = "WARRIOR", display = 64785 },
        { name = "Garrosh Hellscream", class = "WARRIOR", display = 32904 },
        { name = "Vol'jin", class = "SHAMAN", display = 31232 },
        { name = "Uther the Lightbringer", class = "PALADIN", display = 30821 },
        { name = "Khadgar", class = "MAGE", display = 56765 },
        { name = "Gul'dan", class = "WARLOCK", display = 59808 },
        { name = "Chen Stormstout", class = "MONK", display = 39698 },
        { name = "Anduin Wrynn", class = "PRIEST", display = 82047 },
        { name = "Baine Bloodhoof", class = "WARRIOR", display = 30272 },
        { name = "Lor'themar Theron", class = "HUNTER", display = 17122 },
        { name = "Velen", class = "PRIEST", display = 17822 },
        { name = "Kael'thas Sunstrider", class = "MAGE", display = 20023 },
        { name = "Genn Greymane", class = "WARRIOR", display = 29613 },
        { name = "Bolvar Fordragon", class = "PALADIN", display = 5566 },
        { name = "Rexxar", class = "HUNTER", display = 60766 },
    },
    forever = {
        { name = "Thrall Go'el", class = "SHAMAN", display = 4527 },
        { name = "Cairne Bloodhoof", class = "WARRIOR", display = 4307 },
        { name = "Sylvanas Windrunner", class = "HUNTER", display = 11657 },
        { name = "Jaina Proudmoore", class = "MAGE", display = 2970 },
        { name = "Magni Bronzebeard", class = "WARRIOR", display = 3597 },
        { name = "Tyrande Whisperwind", class = "PRIEST", display = 7274 },
        { name = "Vol'jin Darkspear", class = "SHAMAN", display = 10357 },
        { name = "Bolvar Fordragon", class = "PALADIN", display = 5566 },
        { name = "Anduin Wrynn", class = "PRIEST", display = 11655 },
        { name = "Malfurion Stormrage", class = "DRUID", display = 15399 },
        { name = "Mathias Shaw", class = "ROGUE", display = 1736 },
        { name = "Rexxar Mok'Nathal", class = "HUNTER", display = 11660 },
        { name = "Varok Saurfang", class = "WARRIOR", display = 14732 },
        { name = "Drek'Thar Frostwolf", class = "SHAMAN", display = 11894 },
        { name = "Vanndar Stormpike", class = "WARRIOR", display = 11896 },
        { name = "Fandral Staghelm", class = "DRUID", display = 1542 },
    },
}

-- Icons per armor type, plus each class's weapons. Classic icon names, so both
-- clients have them.
local ARMOR_OF_CLASS = {
    WARRIOR = "plate", PALADIN = "plate", DEATHKNIGHT = "plate",
    HUNTER = "mail", SHAMAN = "mail",
    ROGUE = "leather", DRUID = "leather", MONK = "leather", DEMONHUNTER = "leather",
    MAGE = "cloth", PRIEST = "cloth", WARLOCK = "cloth",
}
local ARMOR_ICONS = {
    plate = { HeadSlot = "INV_Helmet_24", ShoulderSlot = "INV_Shoulder_25", ChestSlot = "INV_Chest_Plate16",
        WristSlot = "INV_Bracer_07", HandsSlot = "INV_Gauntlets_29", WaistSlot = "INV_Belt_13",
        LegsSlot = "INV_Pants_Plate_17", FeetSlot = "INV_Boots_Plate_04" },
    mail = { HeadSlot = "INV_Helmet_08", ShoulderSlot = "INV_Shoulder_14", ChestSlot = "INV_Chest_Chain_15",
        WristSlot = "INV_Bracer_13", HandsSlot = "INV_Gauntlets_10", WaistSlot = "INV_Belt_27",
        LegsSlot = "INV_Pants_04", FeetSlot = "INV_Boots_05" },
    leather = { HeadSlot = "INV_Helmet_03", ShoulderSlot = "INV_Shoulder_02", ChestSlot = "INV_Chest_Leather_09",
        WristSlot = "INV_Bracer_07", HandsSlot = "INV_Gauntlets_10", WaistSlot = "INV_Belt_27",
        LegsSlot = "INV_Pants_04", FeetSlot = "INV_Boots_05" },
    cloth = { HeadSlot = "INV_Helmet_10", ShoulderSlot = "INV_Shoulder_02", ChestSlot = "INV_Chest_Cloth_45",
        WristSlot = "INV_Bracer_13", HandsSlot = "INV_Gauntlets_10", WaistSlot = "INV_Belt_27",
        LegsSlot = "INV_Pants_04", FeetSlot = "INV_Boots_05" },
}
local SHARED_ICONS = {
    NeckSlot = "INV_Jewelry_Necklace_07", BackSlot = "INV_Misc_Cape_18", ShirtSlot = "INV_Shirt_White_01",
    TabardSlot = "INV_Shirt_GuildTabard_01", Finger0Slot = "INV_Jewelry_Ring_15", Finger1Slot = "INV_Jewelry_Ring_36",
    Trinket0Slot = "INV_Jewelry_Talisman_07", Trinket1Slot = "INV_Misc_Orb_01",
}
local WEAPONS_OF_CLASS = {
    WARRIOR = { "INV_Sword_04", "INV_Shield_05", "INV_Weapon_Bow_07" },
    PALADIN = { "INV_Hammer_04", "INV_Shield_05", "INV_Relics_LibramofHope" },
    DEATHKNIGHT = { "INV_Sword_39" },
    HUNTER = { "INV_Weapon_Bow_07", "INV_Axe_09", "INV_Weapon_Bow_07" },
    SHAMAN = { "INV_Hammer_04", "INV_Shield_05", "INV_Relics_TotemofRebirth" },
    ROGUE = { "INV_Sword_04", "INV_Weapon_ShortBlade_05", "INV_Weapon_Crossbow_02" },
    DRUID = { "INV_Staff_13", nil, "INV_Relics_IdolofRejuvenation" },
    MONK = { "INV_Staff_13" },
    DEMONHUNTER = { "INV_Weapon_Glaive_01", "INV_Weapon_Glaive_01" },
    MAGE = { "INV_Staff_13", nil, "INV_Wand_07" },
    PRIEST = { "INV_Staff_13", nil, "INV_Wand_07" },
    WARLOCK = { "INV_Staff_13", nil, "INV_Wand_07" },
}

-- Enchants the client of each flavour actually puts on these slots.
local ENCHANTS = {
    retail = {
        BackSlot = { "Chant of Winged Grace", "Chant of Leeching Fangs" },
        ChestSlot = { "Crystalline Radiance", "Council's Intellect" },
        WristSlot = { "Chant of Armored Avoidance", "Whisper of Armored Leech" },
        LegsSlot = { "Sunset Spellthread", "Stormbound Armor Kit" },
        FeetSlot = { "Defender's March", "Scout's March" },
        Finger0Slot = { "Radiant Mastery", "Radiant Haste", "Cursed Critical Strike" },
        Finger1Slot = { "Radiant Mastery", "Radiant Versatility", "Glimmering Haste" },
        MainHandSlot = { "Authority of Radiant Power", "Stormrider's Fury", "Council's Guile" },
        SecondaryHandSlot = { "Authority of Radiant Power", "Stonebound Artistry" },
    },
    forever = {
        HeadSlot = { "+8 Stamina", "Arcanum of Focus" },
        ShoulderSlot = { "Might of the Scourge", "Power of the Scourge" },
        BackSlot = { "+3 Agility", "Greater Defense" },
        ChestSlot = { "+4 All Stats", "+100 Health" },
        WristSlot = { "+9 Strength", "+7 Intellect" },
        HandsSlot = { "+7 Agility", "Minor Haste" },
        LegsSlot = { "+8 Stamina", "+1% Dodge" },
        FeetSlot = { "Minor Speed", "+7 Agility" },
        MainHandSlot = { "Crusader", "Fiery Weapon", "Lifestealing" },
        SecondaryHandSlot = { "+7 Stamina", "Crusader" },
    },
}

-- Paper-doll slots: left column, right column, then the weapon row, with the
-- slot IDs the real module uses to align enchant text (see INS:UpdateSlot).
local LEFT_SLOTS = {
    { "HeadSlot", 1 }, { "NeckSlot", 2 }, { "ShoulderSlot", 3 }, { "BackSlot", 15 },
    { "ChestSlot", 5 }, { "ShirtSlot", 4 }, { "TabardSlot", 19 }, { "WristSlot", 9 },
}
local RIGHT_SLOTS = {
    { "HandsSlot", 10 }, { "WaistSlot", 6 }, { "LegsSlot", 7 }, { "FeetSlot", 8 },
    { "Finger0Slot", 11 }, { "Finger1Slot", 12 }, { "Trinket0Slot", 13 }, { "Trinket1Slot", 14 },
}
local RIGHT_ALIGNED = { [6] = true, [7] = true, [8] = true, [10] = true, [11] = true,
    [12] = true, [13] = true, [14] = true, [16] = true }
local COSMETIC_SLOTS = { ShirtSlot = true, TabardSlot = true }

local lastHeroIndex

local function Pick(list)
    if type(list) ~= "table" or #list == 0 then return nil end
    return list[math.random(1, #list)]
end

local function RollHero()
    local roster = HEROES[PREVIEW_FLAVOR] or HEROES.retail
    local pool = {}
    for index = 1, #roster do
        if index ~= lastHeroIndex then pool[#pool + 1] = index end
    end
    local index = Pick(pool) or 1
    lastHeroIndex = index
    return roster[index]
end

-- Sample item levels around the player's own equipped level, so the numbers
-- look like this client and season whatever they are.
local function BaseItemLevel()
    local ok, overall, equipped = pcall(_G.GetAverageItemLevel)
    local base = ok and tonumber(equipped or overall) or nil
    if not base or base < 5 then
        base = (PREVIEW_FLAVOR == "forever") and 60 or 600
    end
    return math.floor(base + 0.5)
end

local function QualityColor(quality)
    local c = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function ClassColor(class)
    local c = (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS or {})[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function RollGear(hero)
    local base = BaseItemLevel()
    local spread = (PREVIEW_FLAVOR == "forever") and 4 or 7
    local icons = ARMOR_ICONS[ARMOR_OF_CLASS[hero.class] or "cloth"]
    local weapons = WEAPONS_OF_CLASS[hero.class] or {}
    local enchants = ENCHANTS[PREVIEW_FLAVOR] or {}
    local gear, total, count = {}, 0, 0

    local function add(slot, icon)
        if not icon then return end
        local item = { icon = "Interface\\Icons\\" .. icon }
        if COSMETIC_SLOTS[slot] then
            item.ilvl, item.quality = 1, 1
        else
            item.ilvl = base + math.random(-spread, spread)
            item.quality = (math.random() < 0.85) and 4 or 3
            item.enchant = Pick(enchants[slot])
            total, count = total + item.ilvl, count + 1
        end
        gear[slot] = item
    end

    for _, entry in ipairs(LEFT_SLOTS) do add(entry[1], icons[entry[1]] or SHARED_ICONS[entry[1]]) end
    for _, entry in ipairs(RIGHT_SLOTS) do add(entry[1], icons[entry[1]] or SHARED_ICONS[entry[1]]) end
    add("MainHandSlot", weapons[1])
    add("SecondaryHandSlot", weapons[2])
    if PREVIEW_FLAVOR == "forever" then
        add("RangedSlot", weapons[3])
    end
    gear.average = (count > 0) and (total / count) or base
    return gear
end

-- Random spec of the hero's class for the header icon; nil where the client
-- has no specialization API (the class icon stands in).
local function RollSpecIcon(class)
    local ok, icon = pcall(function()
        for i = 1, (_G.GetNumClasses and _G.GetNumClasses() or 0) do
            local _, file, classID = _G.GetClassInfo(i)
            if file == class then
                local specs = _G.GetNumSpecializationsForClassID(classID) or 0
                if specs < 1 then return nil end
                local _, _, _, specIcon = _G.GetSpecializationInfoForClassID(classID, math.random(1, specs))
                return specIcon
            end
        end
    end)
    return ok and icon or nil
end

KT:RegisterPage("inspectarmory", "Inspect Armory", 57, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.inspectArmory
    if not db then
        KT.db.profile.inspectArmory = KT.db.profile.inspectArmory or {}
        db = KT.db.profile.inspectArmory
    end

    local function FetchFont(fontKey)
        if KT and KT.ResolveFontForLocale then
            return KT:ResolveFontForLocale(fontKey, "Fonts\\FRIZQT__.TTF")
        end
        if LSM and fontKey then
            local fetched = LSM:Fetch("font", fontKey)
            if fetched then return fetched end
        end
        return "Fonts\\FRIZQT__.TTF"
    end

    local hero = RollHero()
    local gear = RollGear(hero)
    local specIcon = RollSpecIcon(hero.class)

    ---------------------------------------------------------------------------
    --  Preview frame, pinned above the options (sticky host) like Armory's.
    ---------------------------------------------------------------------------
    local PREVIEW_HEIGHT = 400
    local stickyHost = KT.MenuPrincipal and KT.MenuPrincipal._stickyPreviewHost
    local prevContainer = CreateFrame("Frame", nil, stickyHost or sc, "BackdropTemplate")
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, PREVIEW_HEIGHT)
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    if stickyHost then
        prevContainer:SetFrameStrata(stickyHost:GetFrameStrata())
        prevContainer:SetFrameLevel((stickyHost:GetFrameLevel() or 1) + 1)
    end
    if KT.AddBackdrop then KT:AddBackdrop(prevContainer, 0.05, 0.05, 0.06, 0.98) end
    if KT.AddBorder then KT:AddBorder(prevContainer, 0, 0, 0, 1) end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(prevContainer, { point = "TOP", relativePoint = "TOP", x = 0, y = -10, extraPad = 10 })
    end

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 12, -10)
    lblPrev:SetText(LText("LIVE PREVIEW"))
    KT:SetAccentTextColor(lblPrev, 1)

    ---------------------------------------------------------------------------
    --  The inspect window: title bar, level/class header, paper doll. Built at
    --  the real frame's proportions and scaled to fit, so text sizes keep their
    --  real ratio to the slots.
    ---------------------------------------------------------------------------
    local SLOT, GAP, PAD, HEADER = 37, 4, 8, 60
    local columnHeight = (#LEFT_SLOTS * SLOT) + ((#LEFT_SLOTS - 1) * GAP)
    local dollWidth = 380
    local dollHeight = HEADER + PAD + columnHeight + 10 + SLOT + PAD
    local doll = CreateFrame("Frame", nil, prevContainer, "BackdropTemplate")
    doll:SetSize(dollWidth, dollHeight)
    doll:SetScale((PREVIEW_HEIGHT - 20) / dollHeight)
    doll:SetPoint("TOP", prevContainer, "TOP", 0, -10 / doll:GetScale())
    if KT.AddBackdrop then KT:AddBackdrop(doll, 0.04, 0.04, 0.05, 1) end
    if KT.AddAccentBorder then
        KT:AddAccentBorder(doll, 0.9)
    elseif KT.AddBorder then
        KT:AddBorder(doll, PreviewAccentColor())
    end

    -- Title bar with the inspected character's name.
    local titleBar = doll:CreateTexture(nil, "BORDER")
    titleBar:SetPoint("TOPLEFT", doll, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", doll, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(22)
    titleBar:SetColorTexture(0.11, 0.11, 0.13, 1)
    local title = doll:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    title:SetText(hero.name)

    -- Spec (or class) icon, "Level N Class" and the Raider.IO button, as on
    -- the KUI inspect frame.
    local headerY = -22 - (HEADER - 22) / 2
    local specFrame = CreateFrame("Frame", nil, doll)
    specFrame:SetSize(30, 30)
    specFrame:SetPoint("LEFT", doll, "TOPLEFT", PAD + 4, headerY)
    local specTexture = specFrame:CreateTexture(nil, "ARTWORK")
    specTexture:SetAllPoints(specFrame)
    if specIcon then
        specTexture:SetTexture(specIcon)
        specTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local mask = specFrame:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        mask:SetAllPoints(specTexture)
        specTexture:AddMaskTexture(mask)
    else
        specTexture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        local coords = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[hero.class]
        if coords then specTexture:SetTexCoord(unpack(coords)) end
    end

    local level = (pcall(_G.GetMaxPlayerLevel) and _G.GetMaxPlayerLevel()) or (_G.UnitLevel and _G.UnitLevel("player")) or 1
    local className = (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[hero.class]) or hero.class
    local cr, cg, cb = ClassColor(hero.class)
    local levelLine = doll:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    levelLine:SetPoint("CENTER", doll, "TOP", 0, headerY)
    levelLine:SetText(format("%s %s |cff%02x%02x%02x%s|r", _G.LEVEL or "Level", tostring(level),
        math.floor(cr * 255), math.floor(cg * 255), math.floor(cb * 255), className))

    local raiderIO = CreateFrame("Button", nil, doll, "UIPanelButtonTemplate")
    raiderIO:SetSize(80, 22)
    raiderIO:SetPoint("RIGHT", doll, "TOPRIGHT", -PAD, headerY)
    raiderIO:SetText(LText("Raider.IO"))
    raiderIO:EnableMouse(false)

    -- Class background behind the model and slots (Background Type).
    local bg = doll:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("TOPLEFT", doll, "TOPLEFT", 1, -HEADER)
    bg:SetPoint("BOTTOMRIGHT", doll, "BOTTOMRIGHT", -1, 1)

    -- The hero's own 3D model. The class crest stands in until it loads.
    local crest = doll:CreateTexture(nil, "ARTWORK")
    crest:SetSize(96, 96)
    crest:SetPoint("CENTER", doll, "CENTER", 0, -HEADER / 2)
    crest:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    local crestCoords = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[hero.class]
    if crestCoords then crest:SetTexCoord(unpack(crestCoords)) else crest:Hide() end

    local model = CreateFrame("PlayerModel", nil, doll)
    model:SetPoint("TOPLEFT", doll, "TOPLEFT", PAD + SLOT + 4, -HEADER)
    model:SetPoint("BOTTOMRIGHT", doll, "BOTTOMRIGHT", -(PAD + SLOT + 4), PAD + SLOT + 6)
    model:SetFrameLevel(doll:GetFrameLevel() + 2)
    pcall(model.SetScript, model, "OnModelLoaded", function(self)
        crest:Hide()
        pcall(self.SetFacing, self, 0.35)
    end)
    pcall(model.SetDisplayInfo, model, hero.display)
    pcall(model.SetFacing, model, 0.35)

    local slots = {}
    local function CreateSlot(slotName, slotID)
        local item = gear[slotName]
        local slot = CreateFrame("Frame", nil, doll, "BackdropTemplate")
        slot:SetSize(SLOT, SLOT)
        slot:SetFrameLevel(doll:GetFrameLevel() + 5)
        slot:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        slot:SetBackdropColor(0, 0, 0, 0.75)
        local icon = slot:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if item then
            icon:SetTexture(item.icon)
            slot:SetBackdropBorderColor(QualityColor(item.quality))
        else
            slot:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
        end
        -- Same text objects and anchors as INS:UpdateSlot.
        slot.ilvl = slot:CreateFontString(nil, "OVERLAY")
        slot.ilvl:SetPoint("TOPLEFT", 2, -2)
        slot.enchant = slot:CreateFontString(nil, "OVERLAY")
        slot.item, slot.slotID = item, slotID
        slots[#slots + 1] = slot
        return slot
    end

    local top = -(HEADER + PAD)
    for index, entry in ipairs(LEFT_SLOTS) do
        local slot = CreateSlot(entry[1], entry[2])
        slot:SetPoint("TOPLEFT", doll, "TOPLEFT", PAD, top - (index - 1) * (SLOT + GAP))
    end
    local rightSlots = {}
    for index, entry in ipairs(RIGHT_SLOTS) do
        local slot = CreateSlot(entry[1], entry[2])
        slot:SetPoint("TOPRIGHT", doll, "TOPRIGHT", -PAD, top - (index - 1) * (SLOT + GAP))
        rightSlots[entry[1]] = slot
    end
    local weaponRow = { { "MainHandSlot", 16 }, { "SecondaryHandSlot", 17 } }
    if PREVIEW_FLAVOR == "forever" then weaponRow[#weaponRow + 1] = { "RangedSlot", 18 } end
    local rowWidth = (#weaponRow * SLOT) + ((#weaponRow - 1) * GAP)
    for index, entry in ipairs(weaponRow) do
        local slot = CreateSlot(entry[1], entry[2])
        slot:SetPoint("BOTTOMLEFT", doll, "BOTTOM", -rowWidth / 2 + (index - 1) * (SLOT + GAP), PAD)
    end

    -- Average item level: left of the last trinket, as on the inspect frame.
    local avg = CreateFrame("Frame", nil, doll)
    avg:SetSize(100, 40)
    avg:SetFrameLevel(doll:GetFrameLevel() + 6)
    avg:SetPoint("BOTTOMRIGHT", rightSlots.Trinket1Slot, "BOTTOMLEFT", -10, 0)
    avg.text = avg:CreateFontString(nil, "OVERLAY")
    avg.text:SetPoint("RIGHT", 0, 0)
    avg.text:SetJustifyH("RIGHT")
    avg.label = avg:CreateFontString(nil, "OVERLAY")
    avg.label:SetPoint("BOTTOMRIGHT", avg.text, "TOPRIGHT", 0, 2)

    local function UpdatePreview()
        local M = KT:GetModule("InspectArmory", true)

        local bgFile = M and M.GetBackgroundFile and M:GetBackgroundFile(hero.class)
        if bgFile then
            bg:SetTexture(bgFile)
            bg:Show()
        else
            bg:Hide()
        end

        local ilvlFont = FetchFont(db.ilvlFont or "Friz Quadrata TT")
        local enchantFont = FetchFont(db.enchantFont or "Friz Quadrata TT")
        local enchantColor = db.enchantColor or { r = 0, g = 1, b = 0 }
        local ilvlColor = db.ilvlColor or { r = 1, g = 1, b = 1 }
        for _, slot in ipairs(slots) do
            local item = slot.item
            slot.ilvl:SetFont(ilvlFont, db.ilvlSize or 12, db.ilvlOutline or "OUTLINE")
            slot.ilvl:SetText(item and item.ilvl or "")
            if item and db.ilvlColorByRarity then
                slot.ilvl:SetTextColor(QualityColor(item.quality))
            else
                slot.ilvl:SetTextColor(ilvlColor.r, ilvlColor.g, ilvlColor.b)
            end
            slot.ilvl:SetShown(db.showIlvl and item ~= nil)

            slot.enchant:SetFont(enchantFont, db.enchantSize or 10, "OUTLINE")
            slot.enchant:ClearAllPoints()
            if RIGHT_ALIGNED[slot.slotID] then
                slot.enchant:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", db.enchantX or 0, db.enchantY or 2)
                slot.enchant:SetJustifyH("RIGHT")
            else
                slot.enchant:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", db.enchantX or 0, db.enchantY or 2)
                slot.enchant:SetJustifyH("LEFT")
            end
            local enchant = item and item.enchant
            if enchant and string.len(enchant) > 18 then enchant = string.sub(enchant, 1, 15) .. "..." end
            slot.enchant:SetText(enchant or "")
            slot.enchant:SetTextColor(enchantColor.r, enchantColor.g, enchantColor.b)
            slot.enchant:SetShown(db.showEnchant ~= false and enchant ~= nil)
        end

        local valueColor = db.avgIlvlColor or { r = 1, g = 0.82, b = 0 }
        avg.text:SetFont(FetchFont(db.avgIlvlFont or "Friz Quadrata TT"), db.avgIlvlSize or 20, db.avgIlvlOutline or "OUTLINE")
        avg.text:SetTextColor(valueColor.r, valueColor.g, valueColor.b)
        avg.text:SetText(M and M.FormatAverageIlvl and M:FormatAverageIlvl(gear.average)
            or tostring(math.floor(gear.average)))
        local labelColor = db.avgIlvlLabelColor or { r = 1, g = 1, b = 1 }
        avg.label:SetFont(FetchFont(db.avgIlvlLabelFont or "Friz Quadrata TT"), db.avgIlvlLabelSize or 10,
            db.avgIlvlLabelOutline or "OUTLINE")
        avg.label:SetTextColor(labelColor.r, labelColor.g, labelColor.b)
        avg.label:SetText(LText("iLvl"))
        avg:SetShown(db.showAvgIlvl ~= false)
    end

    local function RefreshAndPreview()
        RefreshInspect()
        UpdatePreview()
    end

    UpdatePreview()
    y = y + PREVIEW_HEIGHT + 36

    local cols = BeginOptionBlocks(sc, y, { gap = 12, columnGap = 16 })

    AddOptionBlock(cols, "left", "General", function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Module", -by,
            function() return db.enable ~= false end,
            function(v) db.enable = v; Reload() end); by = by + h
        _, h = W:Slider(container, "Scale", -by,
            function() return db.scale or 1.25 end,
            function(v) db.scale = v; RefreshInspect() end, 0.5, 2.0, 0.01); by = by + h
        _, h = W:Dropdown(container, "Background Type", -by,
            { ["CLASS"] = "Class Color", ["DARK"] = "Dark", ["NONE"] = "None" },
            function() return db.backgroundType or "CLASS" end,
            function(v) db.backgroundType = v; RefreshAndPreview() end); by = by + h
        _, h = W:Slider(container, "Model Zoom", -by,
            function() return db.modelZoom or 0 end,
            function(v) db.modelZoom = v; RefreshInspect() end, -1, 1, 0.01); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Slot Item Level", function(container)
        local by = 0
        _, h = W:Toggle(container, "Show Slot iLvl", -by,
            function() return db.showIlvl ~= false end,
            function(v) db.showIlvl = v; RefreshAndPreview() end); by = by + h
        _, h = W:Slider(container, "iLvl Font Size", -by,
            function() return db.ilvlSize or 12 end,
            function(v) db.ilvlSize = v; RefreshAndPreview() end, 8, 24, 1); by = by + h
        _, h = W:Toggle(container, "Color by Quality", -by,
            function() return db.ilvlColorByRarity ~= false end,
            function(v) db.ilvlColorByRarity = v; RefreshAndPreview() end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Stats Text", function(container)
        local by = 0
        _, h = W:Toggle(container, "Color Stats", -by,
            function() return db.colorStats ~= false end,
            function(v) db.colorStats = v; RefreshInspect() end); by = by + h
        _, h = W:Dropdown(container, "Stat Font", -by, GetFontValues,
            function() return db.statFont or "AAA_ITC_Avant_Garde" end,
            function(v) db.statFont = v; RefreshAndPreview() end); by = by + h
        _, h = W:Slider(container, "Stat Font Size", -by,
            function() return db.statFontSize or 12 end,
            function(v) db.statFontSize = v; RefreshAndPreview() end, 8, 24, 1); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Average Item Level", function(container)
        local by = 0
        _, h = W:Toggle(container, "Show Average iLvl", -by,
            function() return db.showAvgIlvl ~= false end,
            function(v) db.showAvgIlvl = v; RefreshAndPreview() end); by = by + h
        _, h = W:Toggle(container, "Avg iLvl Decimals", -by,
            function() return db.avgIlvlDecimals == true end,
            function(v) db.avgIlvlDecimals = v; RefreshAndPreview() end); by = by + h
        _, h = W:Dropdown(container, "Avg iLvl Font", -by, GetFontValues,
            function() return db.avgIlvlFont or "AAA_ITC_Avant_Garde" end,
            function(v) db.avgIlvlFont = v; RefreshAndPreview() end); by = by + h
        _, h = W:Slider(container, "Avg iLvl Size", -by,
            function() return db.avgIlvlSize or 20 end,
            function(v) db.avgIlvlSize = v; RefreshAndPreview() end, 10, 40, 1); by = by + h
        _, h = W:Dropdown(container, "Avg iLvl Outline", -by,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.avgIlvlOutline or "OUTLINE" end,
            function(v) db.avgIlvlOutline = v; RefreshAndPreview() end); by = by + h
        _, h = W:ColorSwatch(container, "Avg iLvl Color", -by,
            function()
                local r, g, b = PreviewAccentColor()
                local c = db.avgIlvlColor or { r = r, g = g, b = b, a = 1 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a) db.avgIlvlColor = { r = r, g = g, b = b, a = a }; RefreshAndPreview() end, true); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Enchants", function(container)
        local by = 0
        _, h = W:Toggle(container, "Show Enchants", -by,
            function() return db.showEnchant ~= false end,
            function(v) db.showEnchant = v; RefreshAndPreview() end); by = by + h
        _, h = W:Dropdown(container, "Enchant Font", -by, GetFontValues,
            function() return db.enchantFont or "AAA_ITC_Avant_Garde" end,
            function(v) db.enchantFont = v; RefreshAndPreview() end); by = by + h
        _, h = W:Slider(container, "Enchant Size", -by,
            function() return db.enchantSize or 10 end,
            function(v) db.enchantSize = v; RefreshAndPreview() end, 8, 20, 1); by = by + h
        _, h = W:ColorSwatch(container, "Enchant Color", -by,
            function()
                local c = db.enchantColor or { r = 0, g = 1, b = 0, a = 1 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a) db.enchantColor = { r = r, g = g, b = b, a = a }; RefreshAndPreview() end, true); by = by + h
        return by
    end)

    y = EndOptionBlocks(cols)
    return y
end)
