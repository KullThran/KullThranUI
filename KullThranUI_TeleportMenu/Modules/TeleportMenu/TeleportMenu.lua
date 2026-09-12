-- ============================================================================
-- TeleportMenu.lua
-- Modules/TeleportMenu/TeleportMenu.lua (moved from Modules/TeleportMenu.lua)
-- KullThranUI Module — Portal & Teleport Menu (Porter-style, integrated)
-- ============================================================================

local KT  = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local Mod = KT:NewModule("TeleportMenu", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
local LDB     = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local LSM     = LibStub("LibSharedMedia-3.0", true)

local ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"

-- ── Globals cache ─────────────────────────────────────────────────────────────
local _G               = _G
local pairs, ipairs, type, tinsert, math_ceil, math_abs = pairs, ipairs, type, table.insert, math.ceil, math.abs
local CreateFrame      = CreateFrame
local InCombatLockdown = InCombatLockdown
local C_Item           = C_Item
local C_Spell          = C_Spell
local C_ToyBox         = C_ToyBox
local C_Timer          = C_Timer
local C_Housing        = C_Housing
local PlayerHasToy     = PlayerHasToy
local IsPlayerSpell    = IsPlayerSpell
local GetInventoryItemID   = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local EquipItemByName      = EquipItemByName
local UnitClass = UnitClass
local UnitRace  = UnitRace
local GameTooltip = GameTooltip
local UIParent    = UIParent

-- ── Layout constants ──────────────────────────────────────────────────────────
local DEFAULT_SIZE    = 36
local DEFAULT_SPACING = 4
local DEFAULT_COLS    = 10
local SIDEBAR_WIDTH   = 156
local SIDEBAR_TAB_HEIGHT = 38
local SIDEBAR_TAB_GAP = 6
local SIDEBAR_ICON_SIZE = 20
local SIDEBAR_TEXT_SIZE = 11

local KT_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"

-- ── Colour helpers ────────────────────────────────────────────────────────────
local function RGB(r, g, b)   return r / 255, g / 255, b / 255 end
local GOLD_R, GOLD_G, GOLD_B = RGB(255, 200, 50)
local THEME_COLOR_EPSILON = 0.02

local KNOWN_THEME_BORDER_COLORS = {
    { r = 1.00, g = 0.18, b = 0.39, a = 1.00 },
    { r = 0.37, g = 0.84, b = 1.00, a = 1.00 },
    { r = 0.28, g = 0.95, b = 0.62, a = 1.00 },
    { r = 0.66, g = 0.60, b = 1.00, a = 1.00 },
    { r = 1.00, g = 0.74, b = 0.28, a = 1.00 },
    { r = 0.24, g = 0.94, b = 0.90, a = 1.00 },
    { r = 1.00, g = 0.28, b = 0.34, a = 1.00 },
    { r = 1.00, g = 0.86, b = 0.34, a = 1.00 },
    { r = 0.90, g = 0.46, b = 1.00, a = 1.00 },
    { r = 0.70, g = 0.80, b = 0.92, a = 1.00 },
    { r = 0.74, g = 0.96, b = 0.28, a = 1.00 },
}

local function ColorsMatch(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    return math_abs((a.r or 0) - (b.r or 0)) <= THEME_COLOR_EPSILON and
        math_abs((a.g or 0) - (b.g or 0)) <= THEME_COLOR_EPSILON and
        math_abs((a.b or 0) - (b.b or 0)) <= THEME_COLOR_EPSILON and
        math_abs((a.a or 1) - (b.a or 1)) <= THEME_COLOR_EPSILON
end

local function IsKnownThemeBorderColor(color)
    if type(color) ~= "table" then
        return false
    end

    for _, known in ipairs(KNOWN_THEME_BORDER_COLORS) do
        if ColorsMatch(color, known) then
            return true
        end
    end

    return false
end

local function GetThemeBorderColor()
    local palette = KT and KT.GetStylePalette and KT:GetStylePalette() or KT and KT.STYLE_PALETTE or nil
    local border = palette and (palette.border or palette.accent) or nil
    if border then
        return border.r, border.g, border.b, border.a or 1
    end

    return KT.C_R, KT.C_G, KT.C_B, 1
end

local function GetThemeAccentColor()
    local palette = KT and KT.GetStylePalette and KT:GetStylePalette() or KT and KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    if accent then
        return accent.r, accent.g, accent.b, accent.a or 1
    end

    return KT.C_R, KT.C_G, KT.C_B, 1
end

local function GetThemeHeaderColor()
    local palette = KT and KT.GetStylePalette and KT:GetStylePalette() or KT and KT.STYLE_PALETTE or nil
    local header = KT and KT.db and KT.db.profile and KT.db.profile.skin and KT.db.profile.skin.headerColor or nil
    local tint = palette and palette.backgroundTint or nil
    local background = palette and palette.background or nil

    if header then
        return header.r, header.g, header.b, header.a or 1
    end
    if tint then
        return tint.r, tint.g, tint.b, math.max(tint.a or 0.16, 0.32)
    end
    if background then
        local ar, ag, ab = GetThemeAccentColor()
        return background.r * 0.72 + ar * 0.28, background.g * 0.72 + ag * 0.28, background.b * 0.72 + ab * 0.28, 0.95
    end

    local ar, ag, ab = GetThemeAccentColor()
    return ar * 0.32, ag * 0.32, ab * 0.32, 0.95
end

local function GetTeleportBorderColor(db)
    if db and (db.useThemeBorderColor ~= false or db.borderColorOverride ~= true or IsKnownThemeBorderColor(db.borderColor)) then
        return GetThemeAccentColor()
    end

    local border = db and db.borderColor
    if border then
        return border.r or KT.C_R, border.g or KT.C_G, border.b or KT.C_B, border.a or 1
    end

    return GetThemeBorderColor()
end

local function EnsureOuterBorder(frame)
    if not frame or frame._ktOuterBorder then
        return frame and frame._ktOuterBorder or nil
    end

    local border = {}
    border.top = frame:CreateTexture(nil, "OVERLAY")
    border.bottom = frame:CreateTexture(nil, "OVERLAY")
    border.left = frame:CreateTexture(nil, "OVERLAY")
    border.right = frame:CreateTexture(nil, "OVERLAY")

    border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.top:SetHeight(1)

    border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(1)

    border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(1)

    border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(1)

    frame._ktOuterBorder = border
    return border
end

local function SetOuterBorderColor(frame, r, g, b, a)
    local border = EnsureOuterBorder(frame)
    if not border then return end

    border.top:SetColorTexture(r, g, b, a or 1)
    border.bottom:SetColorTexture(r, g, b, a or 1)
    border.left:SetColorTexture(r, g, b, a or 1)
    border.right:SetColorTexture(r, g, b, a or 1)
end

local HOUSE_ICON_TEXTURES = {
    "Interface\\Icons\\Achievement_Garrison_Architect",
    "Interface\\Icons\\Achievement_Garrison_Tier_01",
    "Interface\\Icons\\Achievement_Garrison_Tier01_Alliance",
    "Interface\\Icons\\Achievement_Garrison_Tier01_Horde",
    "Interface\\Icons\\INV_Misc_Map_01",
    ICON_PATH .. "TeleportMenu.png",
}

local function CollectHouseIconCandidates(houseInfo)
    local candidates = {}
    if type(houseInfo) == "table" then
        for _, key in ipairs({
            "icon", "iconID", "iconFileID", "texture", "textureID",
            "previewIcon", "previewIconID", "previewIconFileID",
        }) do
            local value = houseInfo[key]
            if type(value) == "string" or type(value) == "number" then
                tinsert(candidates, value)
            end
        end
    end

    for _, texture in ipairs(HOUSE_ICON_TEXTURES) do
        tinsert(candidates, texture)
    end

    return candidates
end

local function SetTextureWithFallback(textureObject, candidates)
    if not textureObject then return nil end

    for _, candidate in ipairs(candidates or {}) do
        textureObject:SetTexture(nil)
        textureObject:SetTexture(candidate)
        if textureObject:GetTexture() then
            return candidate
        end
    end

    textureObject:SetTexture(134400)
    return 134400
end

local CATEGORY_ICONS = {
    ["Hearthstones"]   = "Interface\\Icons\\INV_Misc_Rune_09",
    ["Class & Racial"] = "Interface\\Icons\\Spell_Arcane_TeleportOrgrimmar",
    ["Items"]          = "Interface\\Icons\\INV_Misc_Bag_07",
    ["Toys"]           = "Interface\\Icons\\Inv_misc_toy_05",
    ["Dungeons"]       = "Interface\\Icons\\INV_Misc_Map_01",
    ["Raids"]          = "Interface\\Icons\\INV_Misc_Head_Dragon_Bronze",
    ["Delves"]         = "Interface\\Icons\\Inv_misc_map05",
    ["House"]          = HOUSE_ICON_TEXTURES[1],
}

local function ApplySidebarTabState(tab, state)
    if not tab then return end
    local r, g, b = GetThemeAccentColor()

    if state == "active" then
        tab:SetBackdropColor(r * 0.18, g * 0.18, b * 0.18, 0.98)
        tab:SetBackdropBorderColor(r, g, b, 1)
        tab.text:SetTextColor(1, 1, 1, 1)
        tab.icon:SetVertexColor(1, 1, 1, 1)
        tab.iconBG:SetColorTexture(r * 0.25, g * 0.25, b * 0.25, 0.95)
        tab.activeBar:Show()
    elseif state == "hover" then
        tab:SetBackdropColor(0.16, 0.16, 0.16, 0.98)
        tab:SetBackdropBorderColor(r * 0.55, g * 0.55, b * 0.55, 1)
        tab.text:SetTextColor(0.95, 0.95, 0.95, 1)
        tab.icon:SetVertexColor(1, 1, 1, 1)
        tab.iconBG:SetColorTexture(0.18, 0.18, 0.18, 0.95)
        tab.activeBar:Hide()
    else
        tab:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
        tab:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
        tab.text:SetTextColor(0.80, 0.80, 0.80, 1)
        tab.icon:SetVertexColor(0.92, 0.92, 0.92, 1)
        tab.iconBG:SetColorTexture(0.14, 0.14, 0.14, 0.95)
        tab.activeBar:Hide()
    end
end

-- ============================================================================
-- DATA
-- ============================================================================

Mod.Categories = {
    "Hearthstones",
    "Class & Racial",
    "Items",
    "Toys",
    "Dungeons",
    "Raids",
    "Delves",
    "House",          -- â† Vivienda (C_Housing)
}

Mod.DungeonCurrentSeason = {
    ["Magisters' Terrace"] = true,
    ["Maisara Caverns"] = true,
    ["Nexus-Point Xenas"] = true,
    ["Windrunner Spire"] = true,
    ["Algeth'ar Academy"] = true,
    ["Pit of Saron"] = true,
    ["Seat of the Triumvirate"] = true,
    ["Skyreach"] = true,
}

Mod.DungeonExpansionOrder = {
    "The War Within",
    "Dragonflight",
    "Shadowlands",
    "Battle for Azeroth",
    "Legion",
    "Warlords of Draenor",
    "Mists of Pandaria",
    "Cataclysm",
}

Mod.DungeonExpansionByName = {
    ["Operation: Floodgate"] = "The War Within",
    ["Eco-Dome Al'dani"] = "The War Within",
    ["Ara-Kara, City of Echoes"] = "The War Within",
    ["The Dawnbreaker"] = "The War Within",
    ["Priory of the Sacred Flame"] = "The War Within",
    ["City of Threads"] = "The War Within",
    ["The Stonevault"] = "The War Within",
    ["Cinderbrew Meadery"] = "The War Within",
    ["Darkflame Cleft"] = "The War Within",
    ["The Rookery"] = "The War Within",
    ["Brackenhide Hollow"] = "Dragonflight",
    ["Halls of Infusion"] = "Dragonflight",
    ["Neltharus"] = "Dragonflight",
    ["Uldaman: Legacy of Tyr"] = "Dragonflight",
    ["Dawn of the Infinite"] = "Dragonflight",
    ["The Azure Vault"] = "Dragonflight",
    ["Algeth'ar Academy"] = "Dragonflight",
    ["The Nokhud Offensive"] = "Dragonflight",
    ["Ruby Life Pools"] = "Dragonflight",
    ["Tazavesh"] = "Shadowlands",
    ["Halls of Atonement"] = "Shadowlands",
    ["The Necrotic Wake"] = "Shadowlands",
    ["Plaguefall"] = "Shadowlands",
    ["Mists of Tirna Scithe"] = "Shadowlands",
    ["Spires of Ascension"] = "Shadowlands",
    ["Theater of Pain"] = "Shadowlands",
    ["De Other Side"] = "Shadowlands",
    ["Sanguine Depths"] = "Shadowlands",
    ["Freehold"] = "Battle for Azeroth",
    ["The Underrot"] = "Battle for Azeroth",
    ["Waycrest Manor"] = "Battle for Azeroth",
    ["Atal'Dazar"] = "Battle for Azeroth",
    ["Operation: Mechagon"] = "Battle for Azeroth",
    ["Siege of Boralus"] = "Battle for Azeroth",
    ["The MOTHERLODE!!"] = "Battle for Azeroth",
    ["Neltharion's Lair"] = "Legion",
    ["Black Rook Hold"] = "Legion",
    ["Darkheart Thicket"] = "Legion",
    ["Halls of Valor"] = "Legion",
    ["Court of Stars"] = "Legion",
    ["Return to Karazhan"] = "Legion",
    ["The Everbloom"] = "Warlords of Draenor",
    ["Grimrail Depot"] = "Warlords of Draenor",
    ["Iron Docks"] = "Warlords of Draenor",
    ["Auchindoun"] = "Warlords of Draenor",
    ["Bloodmaul Slag Mines"] = "Warlords of Draenor",
    ["Shadowmoon Burial Grounds"] = "Warlords of Draenor",
    ["Skyreach"] = "Warlords of Draenor",
    ["Upper Blackrock Spire"] = "Warlords of Draenor",
    ["Temple of the Jade Serpent"] = "Mists of Pandaria",
    ["Stormstout Brewery"] = "Mists of Pandaria",
    ["Shado-Pan Monastery"] = "Mists of Pandaria",
    ["Gate of the Setting Sun"] = "Mists of Pandaria",
    ["Mogu'shan Palace"] = "Mists of Pandaria",
    ["Siege of Niuzao Temple"] = "Mists of Pandaria",
    ["Scholomance"] = "Mists of Pandaria",
    ["The Vortex Pinnacle"] = "Cataclysm",
    ["Throne of the Tides"] = "Cataclysm",
    ["Grim Batol"] = "Cataclysm",
}

Mod.TeleportData = {
    -- ── Hearthstones ──────────────────────────────────────────────────────────
    ["Hearthstones"] = {
        { type = "item",  id = 6948,   name = "Hearthstone" },
        { type = "spell", id = 8690,   name = "Hearthstone (Spell)" },
        { type = "toy", id = 140192, name = "Dalaran Hearthstone" },
        { type = "toy", id = 110560, name = "Garrison Hearthstone" },
        { type = "toy", id = 142542, name = "Tome of Town Portal",                 cosmetic = true },
        { type = "toy", id = 188952, name = "Dominated Hearthstone",               cosmetic = true },
        { type = "toy", id = 172179, name = "Eternal Traveler's Hearthstone",      cosmetic = true },
        { type = "toy", id = 200630, name = "Ohn'ir Windsage's Hearthstone",       cosmetic = true },
        { type = "toy", id = 208704, name = "Deepdweller's Earthen Hearthstone",   cosmetic = true },
        { type = "toy", id = 209035, name = "Hearthstone of the Flame",            cosmetic = true },
        { type = "toy", id = 190237, name = "Broker Translocation Matrix",         cosmetic = true },
        { type = "toy", id = 184353, name = "Kyrian Hearthstone",                  cosmetic = true },
        { type = "toy", id = 183716, name = "Venthyr Sinstone",                    cosmetic = true },
        { type = "toy", id = 180290, name = "Night Fae Hearthstone",               cosmetic = true },
        { type = "toy", id = 182773, name = "Necrolord Hearthstone",               cosmetic = true },
        { type = "toy", id = 212337, name = "Stone of the Hearth",                 cosmetic = true },
        { type = "toy", id = 206195, name = "Path of the Naaru",                   cosmetic = true },
        { type = "toy", id = 260221, name = "Naaru's Embrace",                     cosmetic = true },
        { type = "toy", id = 166746, name = "Fire Eater's Hearthstone",            cosmetic = true },
        { type = "toy", id = 166747, name = "Brewfest Reveler's Hearthstone",      cosmetic = true },
        { type = "toy", id = 163045, name = "Headless Horseman's Hearthstone",     cosmetic = true },
        { type = "toy", id = 165669, name = "Lunar Elder's Hearthstone",           cosmetic = true },
        { type = "toy", id = 165670, name = "Peddlefeet's Lovely Hearthstone",     cosmetic = true },
        { type = "toy", id = 165802, name = "Noble Gardener's Hearthstone",        cosmetic = true },
        { type = "toy", id = 162973, name = "Greatfather Winter's Hearthstone",    cosmetic = true },
        { type = "toy", id = 168907, name = "Holographic Digitalization Hearthstone", cosmetic = true },
        { type = "toy", id = 245970, name = "P.O.S.T. Master's Express Hearthstone", cosmetic = true },
        { type = "toy", id = 193588, name = "Timewalker's Hearthstone",            cosmetic = true },
        { type = "toy", id = 228940, name = "Notorious Thread's Hearthstone",      cosmetic = true },
        { type = "toy", id = 64488,  name = "The Innkeeper's Daughter",            cosmetic = true },
        { type = "toy", id = 93672,  name = "Dark Portal",                         cosmetic = true },
        { type = "toy", id = 54452,  name = "Ethereal Portal",                     cosmetic = true },
        { type = "toy", id = 190196, name = "Enlightened Hearthstone",             cosmetic = true },
        { type = "toy", id = 246565, name = "Cosmic Hearthstone",                  cosmetic = true },
        { type = "toy", id = 265100, name = "Corewarden's Hearthstone",            cosmetic = true },
        { type = "toy", id = 263933, name = "Preyseeker's Hearthstone",            cosmetic = true },
        { type = "toy", id = 235016, name = "Redeployment Module",                 cosmetic = true },
    },

    -- ── Class & Racial ────────────────────────────────────────────────────────
    ["Class & Racial"] = {
        { type = "spell", id = 3561,   name = "Teleport: Stormwind",              classReq = "MAGE" },
        { type = "spell", id = 3562,   name = "Teleport: Ironforge",              classReq = "MAGE" },
        { type = "spell", id = 3565,   name = "Teleport: Darnassus",              classReq = "MAGE" },
        { type = "spell", id = 32271,  name = "Teleport: Exodar",                 classReq = "MAGE" },
        { type = "spell", id = 49359,  name = "Teleport: Theramore",              classReq = "MAGE" },
        { type = "spell", id = 33690,  name = "Teleport: Shattrath (Alliance)",   classReq = "MAGE" },
        { type = "spell", id = 132621, name = "Teleport: Vale (Alliance)",        classReq = "MAGE" },
        { type = "spell", id = 176248, name = "Teleport: Stormshield",            classReq = "MAGE" },
        { type = "spell", id = 281403, name = "Teleport: Boralus",                classReq = "MAGE" },
        { type = "spell", id = 3567,   name = "Teleport: Orgrimmar",              classReq = "MAGE" },
        { type = "spell", id = 3563,   name = "Teleport: Undercity",              classReq = "MAGE" },
        { type = "spell", id = 3566,   name = "Teleport: Thunder Bluff",          classReq = "MAGE" },
        { type = "spell", id = 32272,  name = "Teleport: Silvermoon",             classReq = "MAGE" },
        { type = "spell", id = 49358,  name = "Teleport: Stonard",                classReq = "MAGE" },
        { type = "spell", id = 35715,  name = "Teleport: Shattrath (Horde)",      classReq = "MAGE" },
        { type = "spell", id = 132627, name = "Teleport: Vale (Horde)",           classReq = "MAGE" },
        { type = "spell", id = 176242, name = "Teleport: Warspear",               classReq = "MAGE" },
        { type = "spell", id = 281404, name = "Teleport: Dazar'alor",             classReq = "MAGE" },
        { type = "spell", id = 53140,  name = "Teleport: Dalaran (Northrend)",    classReq = "MAGE" },
        { type = "spell", id = 224869, name = "Teleport: Dalaran (Broken Isles)", classReq = "MAGE" },
        { type = "spell", id = 88342,  name = "Teleport: Tol Barad (Alliance)",   classReq = "MAGE" },
        { type = "spell", id = 88344,  name = "Teleport: Tol Barad (Horde)",      classReq = "MAGE" },
        { type = "spell", id = 395277, name = "Teleport: Valdrakken",             classReq = "MAGE" },
        { type = "spell", id = 446540, name = "Teleport: Dornogal",               classReq = "MAGE" },
        { type = "spell", id = 344587, name = "Teleport: Oribos",                 classReq = "MAGE" },
        { type = "spell", id = 120145, name = "Ancient Teleport: Dalaran",        classReq = "MAGE" },
        { type = "spell", id = 193759, name = "Teleport: Hall of the Guardian",   classReq = "MAGE" },
        { type = "spell", id = 193753, name = "Dreamwalk",                        classReq = "DRUID" },
        { type = "spell", id = 50977,  name = "Death Gate",                       classReq = "DEATHKNIGHT" },
        { type = "spell", id = 126892, name = "Zen Pilgrimage",                   classReq = "MONK" },
        { type = "spell", id = 556,    name = "Astral Recall",                    classReq = "SHAMAN" },
        { type = "spell", id = 265225, name = "Mole Machine",                     raceReq = "DarkIronDwarf" },
        { type = "spell", id = 312370, name = "Make Camp",                        raceReq = "Vulpera" },
        { type = "spell", id = 312372, name = "Return to Camp",                   raceReq = "Vulpera" },
    },

    -- ── Items ─────────────────────────────────────────────────────────────────
    ["Items"] = {
        { type = "item", id = 63378,  name = "Hellscream's Reach Tabard",         equippable = true },
        { type = "item", id = 63379,  name = "Baradin's Wardens Tabard",          equippable = true },
        { type = "item", id = 65274,  name = "Cloak of Coordination (Horde)",     equippable = true },
        { type = "item", id = 65360,  name = "Cloak of Coordination (Alliance)",  equippable = true },
        { type = "item", id = 63352,  name = "Shroud of Cooperation (Horde)",     equippable = true },
        { type = "item", id = 63353,  name = "Shroud of Cooperation (Alliance)",  equippable = true },
        { type = "item", id = 63207,  name = "Wrap of Unity (Horde)",             equippable = true },
        { type = "item", id = 63206,  name = "Wrap of Unity (Alliance)",          equippable = true },
        { type = "item", id = 118663, name = "Blessed Medallion of Karabor" },
        { type = "item", id = 140493, name = "Adept's Guide to Dimensional Rifting" },
        { type = "item", id = 52251,  name = "Jaina's Locket" },
        { type = "item", id = 139599, name = "Empowered Ring of the Kirin Tor",   equippable = true },
        { type = "item", id = 46874,  name = "Argent Crusader's Tabard",          equippable = true },
        { type = "item", id = 32757,  name = "Blessed Medallion of Karabor" },
        { type = "item", id = 44935,  name = "Ring of the Kirin Tor",             equippable = true },
        { type = "item", id = 40586,  name = "Band of the Kirin Tor",             equippable = true },
        { type = "item", id = 193000, name = "Ring-Bound Hourglass",              equippable = true },
        { type = "item", id = 142469, name = "Violet Seal of the Grand Magus",    equippable = true },
        { type = "item", id = 40585,  name = "Signet of the Kirin Tor",           equippable = true },
        { type = "item", id = 95050,  name = "The Brassiest Knuckle",             equippable = true },
        { type = "item", id = 118907, name = "Pit Fighter's Punching Ring",       equippable = true },
        { type = "item", id = 144391, name = "Pugilist's Powerful Punching Ring", equippable = true },
        { type = "item", id = 128353, name = "Admiral's Compass" },
        { type = "item", id = 219222, name = "Time-Lost Artifact" },
        { type = "item", id = 202046, name = "Lucky Tortollan Charm" },
        { type = "item", id = 132523, name = "Reaves Battery",                    profReq = true },
        { type = "item", id = 144341, name = "Rechargeable Reaves Battery",       profReq = true },
        { type = "item", id = 50287,  name = "Boots of the Bay",                  equippable = true },
    },

    -- ── Toys ──────────────────────────────────────────────────────────────────
    ["Toys"] = {
        { type = "toy", id = 151016, name = "Fractured Necrolyte Skull" },
        { type = "toy", id = 37863,  name = "Direbrew's Remote" },
        { type = "toy", id = 211788, name = "Tess's Peacebloom",                  raceReq = "Worgen" },
        { type = "toy", id = 64457,  name = "The Last Relic of Argus" },
        { type = "toy", id = 243056, name = "Delver's Mana-Bound Ethergate" },
        { type = "toy", id = 48933,  name = "Wormhole Generator: Northrend",      profReq = true },
        { type = "toy", id = 87215,  name = "Wormhole Generator: Pandaria",       profReq = true },
        { type = "toy", id = 112059, name = "Wormhole Centrifuge",                profReq = true },
        { type = "toy", id = 168808, name = "Wormhole Generator: Zandalar",       profReq = true },
        { type = "toy", id = 168807, name = "Wormhole Generator: Kul Tiras",      profReq = true },
        { type = "toy", id = 172924, name = "Wormhole Generator: Shadowlands",    profReq = true },
        { type = "toy", id = 198156, name = "Wyrmhole Generator: Dragon Isles",   profReq = true },
        { type = "toy", id = 221966, name = "Wormhole Generator: Khaz Algar",     profReq = true },
        { type = "toy", id = 18984,  name = "Dimensional Ripper - Everlook",      profReq = true },
        { type = "toy", id = 18986,  name = "Ultrasafe Transporter: Gadgetzan",   profReq = true },
        { type = "toy", id = 30542,  name = "Dimensional Ripper - Area 52",       profReq = true },
        { type = "toy", id = 30544,  name = "Ultrasafe Transporter: Toshley's Station", profReq = true },
        { type = "toy", id = 151652, name = "Wormhole Generator: Argus",          profReq = true },
        { type = "toy", id = 153004, name = "Unstable Portal Emitter" },
        { type = "toy", id = 192443, name = "Element-Infused Rocket Helmet",      profReq = true },
    },

    -- ── Dungeons ──────────────────────────────────────────────────────────────
    ["Dungeons"] = {
        { type = "spell", id = 1216786, name = "Operation: Floodgate" },
        { type = "spell", id = 1237215, name = "Eco-Dome Al'dani" },
        { type = "spell", id = 445417,  name = "Ara-Kara, City of Echoes" },
        { type = "spell", id = 445414,  name = "The Dawnbreaker" },
        { type = "spell", id = 445444,  name = "Priory of the Sacred Flame" },
        { type = "spell", id = 367416,  name = "Tazavesh" },
        { type = "spell", id = 354465,  name = "Halls of Atonement" },
        { type = "spell", id = 445416,  name = "City of Threads" },
        { type = "spell", id = 445269,  name = "The Stonevault" },
        { type = "spell", id = 445440,  name = "Cinderbrew Meadery" },
        { type = "spell", id = 445441,  name = "Darkflame Cleft" },
        { type = "spell", id = 445443,  name = "The Rookery" },
        { type = "spell", id = 393267,  name = "Brackenhide Hollow" },
        { type = "spell", id = 393283,  name = "Halls of Infusion" },
        { type = "spell", id = 393276,  name = "Neltharus" },
        { type = "spell", id = 393222,  name = "Uldaman: Legacy of Tyr" },
        { type = "spell", id = 424197,  name = "Dawn of the Infinite" },
        { type = "spell", id = 393279,  name = "The Azure Vault" },
        { type = "spell", id = 393273,  name = "Algeth'ar Academy" },
        { type = "spell", id = 393262,  name = "The Nokhud Offensive" },
        { type = "spell", id = 393256,  name = "Ruby Life Pools" },
        { type = "spell", id = 354462,  name = "The Necrotic Wake" },
        { type = "spell", id = 354463,  name = "Plaguefall" },
        { type = "spell", id = 354464,  name = "Mists of Tirna Scithe" },
        { type = "spell", id = 354466,  name = "Spires of Ascension" },
        { type = "spell", id = 354467,  name = "Theater of Pain" },
        { type = "spell", id = 354468,  name = "De Other Side" },
        { type = "spell", id = 354469,  name = "Sanguine Depths" },
        { type = "spell", id = 410071,  name = "Freehold" },
        { type = "spell", id = 410074,  name = "The Underrot" },
        { type = "spell", id = 424167,  name = "Waycrest Manor" },
        { type = "spell", id = 424187,  name = "Atal'Dazar" },
        { type = "spell", id = 373274,  name = "Operation: Mechagon" },
        { type = "spell", id = 445418,  name = "Siege of Boralus" },
        { type = "spell", id = 272268,  name = "The MOTHERLODE!!" },
        { type = "spell", id = 410078,  name = "Neltharion's Lair" },
        { type = "spell", id = 424153,  name = "Black Rook Hold" },
        { type = "spell", id = 424163,  name = "Darkheart Thicket" },
        { type = "spell", id = 393764,  name = "Halls of Valor" },
        { type = "spell", id = 393766,  name = "Court of Stars" },
        { type = "spell", id = 373262,  name = "Return to Karazhan" },
        { type = "spell", id = 159901,  name = "The Everbloom" },
        { type = "spell", id = 159900,  name = "Grimrail Depot" },
        { type = "spell", id = 159896,  name = "Iron Docks" },
        { type = "spell", id = 159897,  name = "Auchindoun" },
        { type = "spell", id = 159895,  name = "Bloodmaul Slag Mines" },
        { type = "spell", id = 159899,  name = "Shadowmoon Burial Grounds" },
        { type = "spell", id = 159898,  name = "Skyreach" },
        { type = "spell", id = 159902,  name = "Upper Blackrock Spire" },
        { type = "spell", id = 131204,  name = "Temple of the Jade Serpent" },
        { type = "spell", id = 131205,  name = "Stormstout Brewery" },
        { type = "spell", id = 131206,  name = "Shado-Pan Monastery" },
        { type = "spell", id = 131225,  name = "Gate of the Setting Sun" },
        { type = "spell", id = 131222,  name = "Mogu'shan Palace" },
        { type = "spell", id = 131228,  name = "Siege of Niuzao Temple" },
        { type = "spell", id = 131232,  name = "Scholomance" },
        { type = "spell", id = 410080,  name = "The Vortex Pinnacle" },
        { type = "spell", id = 424142,  name = "Throne of the Tides" },
        { type = "spell", id = 445424,  name = "Grim Batol" },
    },

    -- ── Raids ─────────────────────────────────────────────────────────────────
    ["Raids"] = {
        { type = "spell", id = 1239155, name = "Manaforge Omega" },
        { type = "spell", id = 1226482, name = "Liberation of Undermine" },
        { type = "spell", id = 432254,  name = "Vault of the Incarnates" },
        { type = "spell", id = 432257,  name = "Aberrus, the Shadowed Crucible" },
        { type = "spell", id = 432258,  name = "Amirdrassil, the Dream's Hope" },
        { type = "spell", id = 373190,  name = "Castle Nathria" },
        { type = "spell", id = 373191,  name = "Sanctum of Domination" },
        { type = "spell", id = 373192,  name = "Sepulcher of the First Ones" },
    },

    -- ── Delves ────────────────────────────────────────────────────────────────
    ["Delves"] = {
        { type = "toy", id = 230850, name = "Delve-O-Bot 7001" },
    },

    -- ── House — populated dynamically via C_Housing ───────────────────────────
    ["House"] = {},
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Mod:OnInitialize()
    -- Defaults
    if not KT.db.profile.teleportMenu then
        KT.db.profile.teleportMenu = {
            enable        = true,
            minimap       = { hide = false },
            -- position object deprecated, replaced by anchor/x/y
            anchor        = "CENTER", xOffset = 0, yOffset = 0,
            showCosmetic  = true,
            hiddenItems   = {},
            buttonSize    = DEFAULT_SIZE,
            buttonSpacing = DEFAULT_SPACING,
            columns       = DEFAULT_COLS,
            fontSize      = 10,
            font          = "AAA_ITC_Avant_Garde",
            fontOutline   = "OUTLINE",
            showTooltip   = true,
            showLabels    = true,
            buttonStyle   = "BLIZZARD",
            bgColor       = { r = 0.07, g = 0.07, b = 0.07, a = 0.97 },
            useThemeBorderColor = true,
        }
    end
    
    -- Migration for old 'position' table if present
    if KT.db.profile.teleportMenu.position then
        KT.db.profile.teleportMenu.anchor  = KT.db.profile.teleportMenu.position.point or "CENTER"
        KT.db.profile.teleportMenu.xOffset = KT.db.profile.teleportMenu.position.x or 0
        KT.db.profile.teleportMenu.yOffset = KT.db.profile.teleportMenu.position.y or 0
        KT.db.profile.teleportMenu.position = nil
    end
    self.db = KT.db.profile.teleportMenu
    if self.db.borderColorOverride ~= true then
        self.db.useThemeBorderColor = true
    elseif self.db.useThemeBorderColor == nil then
        self.db.useThemeBorderColor = not self.db.borderColor or IsKnownThemeBorderColor(self.db.borderColor)
    end
    self.activeCategory = "Hearthstones"
    self.buttons        = {}
    self.secureButtons  = {}
    self.plainButtons   = {}
    self.pendingCategory = nil
end

function Mod:OnEnable()
    if not self.db.enable then return end

    self:SetupMinimapButton()
    self:ApplyTeleportMinimapButtonStyle()
    C_Timer.After(0.2, function()
        if Mod and Mod.ApplyTeleportMinimapButtonStyle then
            Mod:ApplyTeleportMinimapButtonStyle()
        end
    end)

    self:RegisterEvent("SPELL_UPDATE_COOLDOWN",    "UpdateAllCooldowns")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN",       "UpdateAllCooldowns")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA",     "OnZoneChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD",     "OnEnteringWorld")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED",  "OnEquipmentChanged")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED",  "OnSpellSucceeded")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED","OnSpellInterrupted")
    self:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED", "OnHouseListUpdated")
    self:RegisterEvent("PLAYER_REGEN_ENABLED",      "OnRegenEnabled")

    self:RegisterChatCommand("ktteleport", "Toggle")
    self:RegisterChatCommand("porter",     "Toggle")

    -- Request housing data from the server
    if C_Housing and C_Housing.GetPlayerOwnedHouses then
        C_Housing.GetPlayerOwnedHouses()
    end
end

function Mod:OnRegenEnabled()
    if self.pendingCategory then
        local category = self.pendingCategory
        self.pendingCategory = nil
        self:ShowCategory(category)
    end
end

-- ============================================================================
-- EQUIP-SLOT MAP  (for equippable porter items)
-- ============================================================================

local EQUIP_SLOT_MAP = {
    INVTYPE_CLOAK  = { 15 },
    INVTYPE_TABARD = { 19 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_FEET   = { 8 },
    INVTYPE_HEAD   = { 1 },
    INVTYPE_NECK   = { 2 },
}

function Mod:GetEquipSlots(itemID)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    return equipLoc and EQUIP_SLOT_MAP[equipLoc] or nil
end

-- ============================================================================
-- FRAME CONSTRUCTION
-- ============================================================================

function Mod:CreateMenuFrame()
    if self.menuFrame then return self.menuFrame end
    local accentR, accentG, accentB = GetThemeAccentColor()
    local headerR, headerG, headerB, headerA = GetThemeHeaderColor()

    -- ── Outer frame ───────────────────────────────────────────────────────────
    local f = CreateFrame("Frame", "KT_TeleportMenuFrame", UIParent, "BackdropTemplate")
    f:SetSize(660, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    self:ApplyFrameStyle(f)

    -- ── Header bar ────────────────────────────────────────────────────────────
    local header = f:CreateTexture(nil, "BACKGROUND")
    header:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -1)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    header:SetHeight(32)
    header:SetColorTexture(headerR, headerG, headerB, headerA)
    f.header = header

    local headerGlow = f:CreateTexture(nil, "BORDER")
    headerGlow:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    headerGlow:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerGlow:SetColorTexture(accentR, accentG, accentB, 0.08)
    f.headerGlow = headerGlow

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT_FONT, 14, "OUTLINE")
    title:SetPoint("LEFT", 12, 0)
    title:SetPoint("TOP",  f, "TOP", 0, -9)
    title:SetText(LText("Portal & Teleport"))

    -- ── Separator under header ────────────────────────────────────────────────
    local sep = f:CreateTexture(nil, "BACKGROUND")
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  1, -33)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -33)
    sep:SetHeight(1)
    sep:SetColorTexture(accentR, accentG, accentB, 0.8)
    f.headerSeparator = sep

    -- ── Close button ──────────────────────────────────────────────────────────
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetSize(28, 28)
    f.closeBtn = close

    -- ── Settings toggle (gear icon) ───────────────────────────────────────────
    local gear = CreateFrame("Button", nil, f, "BackdropTemplate")
    gear:SetSize(22, 22)
    gear:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
    local gearTex = gear:CreateTexture(nil, "ARTWORK")
    gearTex:SetAllPoints()
    gearTex:SetTexture(ICON_PATH .. "Config.png")
    gear:SetScript("OnClick",   function()
        if KT.OpenMenu then KT:OpenMenu("teleportmenu") end
    end)
    gear:SetScript("OnEnter",   function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine(LText("Teleport Menu Settings"), 1, 1, 1)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave",   function() GameTooltip:Hide() end)
    f.gearBtn = gear
    gearTex:SetTexture('Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png')
    gearTex:ClearAllPoints()
    gearTex:SetPoint('CENTER', gear, 'CENTER', 0, 0)
    gearTex:SetSize(18, 18)
    gearTex:SetVertexColor(accentR, accentG, accentB, 1)
    f.gearIcon = gearTex

    -- ── Left sidebar: category list ───────────────────────────────────────────
    local sidebar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT",    f, "TOPLEFT", 1, -34)
    sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    sidebar:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    sidebar:SetBackdropBorderColor(accentR * 0.4, accentG * 0.4, accentB * 0.4, 1)

    f.tabs = {}
    local tabY = -10
    for _, cat in ipairs(Mod.Categories) do
        local tab = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
        tab:SetHeight(SIDEBAR_TAB_HEIGHT)
        tab:SetPoint("LEFT",  sidebar, "LEFT",  8, 0)
        tab:SetPoint("RIGHT", sidebar, "RIGHT", -8, 0)
        tab:SetPoint("TOP",   sidebar, "TOP", 0, tabY)
        tab:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tab.activeBar = tab:CreateTexture(nil, "BORDER")
        tab.activeBar:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -1)
        tab.activeBar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 1)
        tab.activeBar:SetWidth(3)
        tab.activeBar:SetColorTexture(accentR, accentG, accentB, 1)
        tab.activeBar:Hide()

        tab.iconBG = tab:CreateTexture(nil, "BACKGROUND")
        tab.iconBG:SetSize(SIDEBAR_ICON_SIZE + 8, SIDEBAR_ICON_SIZE + 8)
        tab.iconBG:SetPoint("LEFT", 9, 0)

        local ico = tab:CreateTexture(nil, "ARTWORK")
        ico:SetSize(SIDEBAR_ICON_SIZE, SIDEBAR_ICON_SIZE)
        ico:SetPoint("LEFT", 13, 0)
        if cat == "House" then
            SetTextureWithFallback(ico, CollectHouseIconCandidates())
        else
            ico:SetTexture(CATEGORY_ICONS[cat] or "Interface\\Icons\\Inv_misc_note_01")
        end
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.icon = ico

        local txt = tab:CreateFontString(nil, "OVERLAY")
        txt:SetFont(KT_FONT, SIDEBAR_TEXT_SIZE, "OUTLINE")
        txt:SetPoint("LEFT",  ico, "RIGHT", 8, 0)
        txt:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
        txt:SetJustifyH("LEFT")
        txt:SetJustifyV("MIDDLE")
        txt:SetWordWrap(false)
        txt:SetText(cat)
        tab.text = txt

        tab.category = cat
        tab:SetScript("OnClick", function()
            Mod.activeCategory = cat
            Mod:ShowCategory(cat)
        end)
        tab:SetScript("OnEnter", function(s)
            if s.category ~= Mod.activeCategory then
                ApplySidebarTabState(s, "hover")
            end
        end)
        tab:SetScript("OnLeave", function(s)
            if s.category ~= Mod.activeCategory then
                ApplySidebarTabState(s, "inactive")
            end
        end)
        ApplySidebarTabState(tab, "inactive")

        tinsert(f.tabs, tab)
        tabY = tabY - (SIDEBAR_TAB_HEIGHT + SIDEBAR_TAB_GAP)
    end
    f.sidebar = sidebar

    -- ── Sidebar separator ─────────────────────────────────────────────────────
    local vsep = f:CreateTexture(nil, "BACKGROUND")
    vsep:SetPoint("TOPLEFT",    sidebar, "TOPRIGHT",    0, 0)
    vsep:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
    vsep:SetWidth(1)
    vsep:SetColorTexture(accentR, accentG, accentB, 0.5)
    f.sidebarSeparator = vsep

    -- ── Content area ──────────────────────────────────────────────────────────
    local contentOuter = CreateFrame("Frame", nil, f)
    contentOuter:SetPoint("TOPLEFT",    sidebar, "TOPRIGHT", 8,  -6)
    contentOuter:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  -8,  8)
    f.contentOuter = contentOuter

    -- Item count label
    local countLabel = contentOuter:CreateFontString(nil, "OVERLAY")
    countLabel:SetFont(KT_FONT, 9, "OUTLINE")
    countLabel:SetPoint("BOTTOMRIGHT", contentOuter, "BOTTOMRIGHT", -2, 2)
    countLabel:SetTextColor(0.6, 0.6, 0.6, 1)
    f.countLabel = countLabel

    -- ScrollFrame
    local scroll = CreateFrame("ScrollFrame", "KT_TeleportScroll", contentOuter, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     contentOuter, "TOPLEFT",  0,   0)
    scroll:SetPoint("BOTTOMRIGHT", contentOuter, "BOTTOMRIGHT", -20, 14)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    self:ApplyScrollBarStyle(scroll, contentOuter)
    f.content  = content
    f.scroll   = scroll

    self.menuFrame = f
    return f
end

-- ============================================================================
-- STYLING
-- ============================================================================
function Mod:ApplyFrameStyle(f)
    if not f then return end
    local bg = self.db.bgColor or { r=0.07, g=0.07, b=0.07, a=0.97 }
    local bcr, bcg, bcb, bca = GetTeleportBorderColor(self.db)
    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    f:SetBackdropBorderColor(0, 0, 0, 0)
    SetOuterBorderColor(f, bcr, bcg, bcb, bca)
end

function Mod:SetScrollBarVisualState(scrollbar, state)
    if not scrollbar then return end
    local thumb = scrollbar.ThumbTexture or (scrollbar.GetThumbTexture and scrollbar:GetThumbTexture())
    if not thumb then return end

    local r, g, b = GetThemeAccentColor()
    local borderAlpha, glowAlpha = 0.75, 0.10

    if state == "hover" then
        r = math.min(r + 0.10, 1)
        g = math.min(g + 0.10, 1)
        b = math.min(b + 0.10, 1)
        borderAlpha, glowAlpha = 0.95, 0.18
    elseif state == "drag" then
        r = math.min(r + 0.18, 1)
        g = math.min(g + 0.18, 1)
        b = math.min(b + 0.18, 1)
        borderAlpha, glowAlpha = 1, 0.28
    end

    thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    thumb:SetVertexColor(r, g, b, 0.95)

    if scrollbar.thumbFrame then
        if KT.AddBackdrop then KT:AddBackdrop(scrollbar.thumbFrame, 0.02, 0.02, 0.03, 0.88) end
        if KT.AddBorder then KT:AddBorder(scrollbar.thumbFrame, r, g, b, borderAlpha) end
    end
    if scrollbar.thumbGlow then
        scrollbar.thumbGlow:SetColorTexture(r, g, b, glowAlpha)
    end
end

function Mod:ApplyScrollBarStyle(scroll, contentOuter)
    if not scroll then return end
    local accentR, accentG, accentB = GetThemeAccentColor()

    local scrollbar = scroll.ScrollBar or (scroll.GetName and _G[scroll:GetName() .. "ScrollBar"])
    if not scrollbar or scrollbar._ktStyled then return end
    scrollbar._ktStyled = true

    scrollbar:ClearAllPoints()
    scrollbar:SetPoint("TOPRIGHT", contentOuter, "TOPRIGHT", -2, -2)
    scrollbar:SetPoint("BOTTOMRIGHT", contentOuter, "BOTTOMRIGHT", -2, 18)
    scrollbar:SetWidth(14)

    for _, regionName in ipairs({
        "Track", "Top", "Bottom", "Middle", "BG", "Background", "Back",
        "TopImage", "BottomImage", "MiddleImage",
    }) do
        local region = scrollbar[regionName]
        if region then
            if region.Hide then region:Hide() end
            if region.SetAlpha then region:SetAlpha(0) end
        end
    end

    if scrollbar.ScrollUpButton then
        scrollbar.ScrollUpButton:Hide()
        scrollbar.ScrollUpButton:SetHeight(0.01)
    end
    if scrollbar.ScrollDownButton then
        scrollbar.ScrollDownButton:Hide()
        scrollbar.ScrollDownButton:SetHeight(0.01)
    end

    if scrollbar.SetThumbTexture then
        scrollbar:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    end

    local thumb = scrollbar.ThumbTexture or (scrollbar.GetThumbTexture and scrollbar:GetThumbTexture())
    if thumb then
        thumb:SetWidth(6)
        thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    end

    scrollbar.trackFrame = scrollbar.trackFrame or CreateFrame("Frame", nil, scrollbar, "BackdropTemplate")
    scrollbar.trackFrame:SetFrameLevel(scrollbar:GetFrameLevel() - 1)
    scrollbar.trackFrame:ClearAllPoints()
    scrollbar.trackFrame:SetPoint("TOPLEFT", scrollbar, "TOPLEFT", 2, -2)
    scrollbar.trackFrame:SetPoint("BOTTOMRIGHT", scrollbar, "BOTTOMRIGHT", -2, 2)
    if KT.AddBackdrop then KT:AddBackdrop(scrollbar.trackFrame, 0.01, 0.01, 0.02, 0.94) end
    if KT.AddBorder then KT:AddBorder(scrollbar.trackFrame, accentR * 0.45, accentG * 0.45, accentB * 0.45, 0.95) end

    scrollbar.trackLine = scrollbar.trackLine or scrollbar.trackFrame:CreateTexture(nil, "ARTWORK")
    scrollbar.trackLine:ClearAllPoints()
    scrollbar.trackLine:SetPoint("TOP", scrollbar.trackFrame, "TOP", 0, -3)
    scrollbar.trackLine:SetPoint("BOTTOM", scrollbar.trackFrame, "BOTTOM", 0, 3)
    scrollbar.trackLine:SetWidth(1)
    scrollbar.trackLine:SetColorTexture(accentR, accentG, accentB, 0.24)

    scrollbar.thumbFrame = scrollbar.thumbFrame or CreateFrame("Frame", nil, scrollbar, "BackdropTemplate")
    scrollbar.thumbFrame:SetFrameLevel(scrollbar:GetFrameLevel() + 6)
    scrollbar.thumbGlow = scrollbar.thumbGlow or scrollbar.thumbFrame:CreateTexture(nil, "BACKGROUND")
    scrollbar.thumbGlow:SetAllPoints()

    local function UpdateThumbFrame()
        local currentThumb = scrollbar.ThumbTexture or (scrollbar.GetThumbTexture and scrollbar:GetThumbTexture())
        if not currentThumb then return end
        scrollbar.thumbFrame:ClearAllPoints()
        scrollbar.thumbFrame:SetPoint("TOPLEFT", currentThumb, "TOPLEFT", -2, 2)
        scrollbar.thumbFrame:SetPoint("BOTTOMRIGHT", currentThumb, "BOTTOMRIGHT", 2, -2)
    end

    UpdateThumbFrame()
    self:SetScrollBarVisualState(scrollbar, "normal")

    if not scrollbar._ktHooksInstalled then
        scrollbar._ktHooksInstalled = true
        scrollbar:HookScript("OnValueChanged", UpdateThumbFrame)
        scrollbar:HookScript("OnSizeChanged", UpdateThumbFrame)
        scrollbar:HookScript("OnEnter", function(sb)
            if not sb._ktDragging then
                Mod:SetScrollBarVisualState(sb, "hover")
            end
        end)
        scrollbar:HookScript("OnLeave", function(sb)
            if not sb._ktDragging then
                Mod:SetScrollBarVisualState(sb, "normal")
            end
        end)
        scrollbar:HookScript("OnMouseDown", function(sb)
            sb._ktDragging = true
            Mod:SetScrollBarVisualState(sb, "drag")
        end)
        scrollbar:HookScript("OnMouseUp", function(sb)
            sb._ktDragging = nil
            if sb:IsMouseOver() then
                Mod:SetScrollBarVisualState(sb, "hover")
            else
                Mod:SetScrollBarVisualState(sb, "normal")
            end
        end)
    end
end

function Mod:RefreshThemeColors()
    local f = self.menuFrame
    if not f then return end

    local r, g, b = GetThemeAccentColor()
    local _, _, _, borderAlpha = GetTeleportBorderColor(self.db)

    -- Repaint the outer frame too, because the menu frame is reused between
    -- the standalone window and the embedded options preview.
    if f.SetBackdropColor then
        local bg = self.db.bgColor or { r = 0.07, g = 0.07, b = 0.07, a = 0.97 }
        f:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        f:SetBackdropBorderColor(0, 0, 0, 0)
    end
    SetOuterBorderColor(f, r, g, b, borderAlpha or 1)

    if f.header then
        local hr, hg, hb, ha = GetThemeHeaderColor()
        f.header:SetColorTexture(hr, hg, hb, ha)
    end
    if f.headerGlow then
        f.headerGlow:SetColorTexture(r, g, b, 0.08)
    end
    if f.headerSeparator then
        f.headerSeparator:SetColorTexture(r, g, b, 0.8)
    end
    if f.gearIcon then
        f.gearIcon:SetVertexColor(r, g, b, 1)
    end
    if f.sidebar then
        f.sidebar:SetBackdropBorderColor(r * 0.4, g * 0.4, b * 0.4, 1)
    end
    if f.sidebarSeparator then
        f.sidebarSeparator:SetColorTexture(r, g, b, 0.5)
    end

    for _, tab in ipairs(f.tabs or {}) do
        if tab.activeBar then
            tab.activeBar:SetColorTexture(r, g, b, 1)
        end
        ApplySidebarTabState(tab, tab.category == self.activeCategory and "active" or "inactive")
    end

    local scrollbar = f.scroll and (f.scroll.ScrollBar or (f.scroll.GetName and _G[f.scroll:GetName() .. "ScrollBar"])) or nil
    if scrollbar then
        if scrollbar.trackFrame and KT.AddBorder then
            KT:AddBorder(scrollbar.trackFrame, r * 0.45, g * 0.45, b * 0.45, 0.95)
        end
        if scrollbar.trackLine then
            scrollbar.trackLine:SetColorTexture(r, g, b, 0.24)
        end

        local state = "normal"
        if scrollbar._ktDragging then
            state = "drag"
        elseif scrollbar.IsMouseOver and scrollbar:IsMouseOver() then
            state = "hover"
        end
        self:SetScrollBarVisualState(scrollbar, state)
    end
end

-- ============================================================================
-- CATEGORY DISPLAY
-- ============================================================================

function Mod:ShowCategory(category)
    if InCombatLockdown() then
        self.pendingCategory = category or self.activeCategory or "Hearthstones"
        return
    end

    local frame = self:CreateMenuFrame()
    local content = frame.content

    frame.scroll:Show()
    frame.countLabel:Show()

    self.buttons = {}
    self.secureButtons = self.secureButtons or {}
    self.plainButtons = self.plainButtons or {}
    for _, btn in ipairs(self.secureButtons) do btn:Hide() end
    for _, btn in ipairs(self.plainButtons) do btn:Hide() end
    self.groupHeaders = self.groupHeaders or {}
    for _, header in ipairs(self.groupHeaders) do header:Hide() end

    for _, tab in ipairs(frame.tabs) do
        if tab.category == category then
            ApplySidebarTabState(tab, "active")
        else
            ApplySidebarTabState(tab, "inactive")
        end
    end

    local list = Mod.TeleportData[category]
    if not list then return end

    local playerClass = select(2, UnitClass("player"))
    local _, playerRace = UnitRace("player")
    local validItems = {}

    for _, item in ipairs(list) do
        local show = true
        if item.classReq and item.classReq ~= playerClass then show = false end
        if item.raceReq and item.raceReq ~= playerRace then show = false end
        if item.cosmetic and not Mod.db.showCosmetic then show = false end
        -- Right-click hiding has been disabled to prevent accidental loss of entries.
        -- Legacy hiddenItems are ignored so previously hidden entries become visible again.

        if show then
            if item.type == "spell" and not IsPlayerSpell(item.id) then show = false end
            if item.type == "toy" and not PlayerHasToy(item.id) then show = false end
            if item.type == "housing" then show = true end
            if show then
                tinsert(validItems, item)
            end
        end
    end

    local bSize = self.db.buttonSize or DEFAULT_SIZE
    local bSpace = self.db.buttonSpacing or DEFAULT_SPACING
    local bCols = self.db.columns or DEFAULT_COLS
    local showLabels = self.db.showLabels ~= false
    local labelHeight = showLabels and 24 or 0
    local cellW = math.max(bSize, 64)
    local cellH = bSize + labelHeight
    local availableW = 0
    if frame.contentOuter and frame.contentOuter.GetWidth then
        availableW = frame.contentOuter:GetWidth()
    end
    if not availableW or availableW <= 10 then
        availableW = (frame.GetWidth and frame:GetWidth() or 660) - 170
    end
    availableW = math.max(100, availableW - 8)
    local maxCols = math.max(1, math.floor((availableW + bSpace) / (cellW + bSpace)))
    bCols = math.min(bCols, maxCols)
    local totalWidth = bCols * (cellW + bSpace) - bSpace

    local function AcquireGroupHeader(index)
        local header = self.groupHeaders[index]
        if not header then
            local lineR, lineG, lineB = GetThemeAccentColor()
            header = CreateFrame("Frame", nil, content)
            header.text = header:CreateFontString(nil, "OVERLAY")
            header.text:SetFont(KT_FONT, 11, "OUTLINE")
            header.text:SetPoint("LEFT", header, "LEFT", 0, 0)
            header.text:SetJustifyH("LEFT")
            header.line = header:CreateTexture(nil, "ARTWORK")
            header.line:SetHeight(1)
            header.line:SetColorTexture(lineR, lineG, lineB, 0.5)
            self.groupHeaders[index] = header
        end
        return header
    end

    local function ApplyButtonItem(index, item, x, y)
        local isSecureButton = item.type ~= "housing"
        local pool = isSecureButton and self.secureButtons or self.plainButtons
        local btn = pool[index]
        if not btn then
            local buttonName = isSecureButton and ("KT_TeleportSecureBtn" .. index) or ("KT_TeleportHousingBtn" .. index)
            local template = isSecureButton and "SecureActionButtonTemplate,BackdropTemplate" or "BackdropTemplate"
            btn = CreateFrame("Button", buttonName, content, template)
            btn:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            btn:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
            btn:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            btn.dimmer = btn:CreateTexture(nil, "OVERLAY")
            btn.dimmer:SetColorTexture(0, 0, 0, 0.5)
            btn.dimmer:Hide()

            btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
            btn.cooldown:SetDrawEdge(true)

            btn.nameLabel = btn:CreateFontString(nil, "OVERLAY")
            btn.nameLabel:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -bSize - 2)
            btn.nameLabel:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -bSize - 2)
            btn.nameLabel:SetJustifyH("CENTER")
            btn.nameLabel:SetJustifyV("TOP")
            btn.nameLabel:SetWordWrap(true)
            btn.nameLabel:SetTextColor(0.85, 0.85, 0.85, 1)
            btn.nameLabel:SetSpacing(0)

            btn.badge = btn:CreateTexture(nil, "OVERLAY")
            btn.badge:SetSize(10, 10)
            btn.badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
            btn.badge:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 0.85)
            btn.badge:Hide()

            btn:SetScript("OnEnter", function(s)
                if Mod.db.showTooltip ~= false then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if s.itemID then GameTooltip:SetItemByID(s.itemID)
                    elseif s.spellID then GameTooltip:SetSpellByID(s.spellID)
                    elseif s.toyID then GameTooltip:SetToyByItemID(s.toyID)
                    elseif s.housingData then
                        GameTooltip:AddLine(s.housingData.name, 1, 1, 1)
                        GameTooltip:AddLine(LText("Click to teleport to your house."), 0.7, 0.7, 0.7)
                    end
                    GameTooltip:Show()
                end
                local hoverR, hoverG, hoverB = GetThemeAccentColor()
                s:SetBackdropBorderColor(hoverR, hoverG, hoverB, 1)
            end)
            btn:SetScript("OnLeave", function(s)
                GameTooltip:Hide()
                s:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
            end)

            if isSecureButton then
                -- Register both up and down to respect ActionButtonUseKeyDown settings.
                btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
            else
                btn:RegisterForClicks("LeftButtonUp")
            end

            pool[index] = btn
        end

        btn:SetSize(cellW, cellH)
        btn:SetParent(content)
        btn:Show()
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOP", btn, "TOP", 0, 0)
        btn.icon:SetSize(bSize, bSize)
        btn.dimmer:ClearAllPoints()
        btn.dimmer:SetPoint("TOP", btn, "TOP", 0, 0)
        btn.dimmer:SetSize(bSize, bSize)
        btn.cooldown:ClearAllPoints()
        btn.cooldown:SetPoint("TOP", btn, "TOP", 0, 0)
        btn.cooldown:SetSize(bSize, bSize)

        btn.spellID, btn.itemID, btn.toyID, btn.housingData = nil, nil, nil, nil
        if not isSecureButton then
            btn:SetScript("OnClick", nil)
        end
        btn:SetScript("PreClick", nil)
        btn:SetScript("PostClick", nil)
        if isSecureButton then
            btn:SetAttribute("type", nil)
            btn:SetAttribute("spell", nil)
            btn:SetAttribute("item", nil)
            btn:SetAttribute("macrotext", nil)
        end
        btn.badge:Hide()

        local font = (self.db.font and LSM and LSM:Fetch("font", self.db.font)) or KT_FONT
        local outline = self.db.fontOutline
        if not outline or outline == "NONE" then
            outline = "OUTLINE"
        end
        btn.nameLabel:SetFont(font, self.db.fontSize or 10, outline)
        btn.nameLabel:SetText(item.name or "")
        btn.nameLabel:SetWidth(cellW)
        btn.nameLabel:SetHeight(labelHeight > 0 and labelHeight or 1)
        if showLabels then btn.nameLabel:Show() else btn.nameLabel:Hide() end

        if item.type == "spell" then
            local info = C_Spell.GetSpellInfo(item.id)
            btn.icon:SetTexture(info and info.iconID or 134400)
            btn.spellID = item.id
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/cast " .. (info and info.name or ""))
        elseif item.type == "item" then
            local _, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(item.id)
            local _, _, _, _, iconID = GetItemInfoInstant(item.id)
            btn.icon:SetTexture(itemIcon or iconID or 134400)
            btn.itemID = item.id
            if item.equippable then
                btn.badge:Show()
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/equip item:" .. item.id .. "\n/use item:" .. item.id)
                btn:SetScript("PreClick", function()
                    local slots = Mod:GetEquipSlots(item.id)
                    if not slots then return end
                    local snapshot = {}
                    for _, slot in ipairs(slots) do
                        snapshot[slot] = {
                            id   = GetInventoryItemID("player", slot),
                            link = GetInventoryItemLink("player", slot),
                        }
                    end
                    Mod.pendingReequip = { slots = snapshot, porterItemID = item.id }
                end)
            else
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/use item:" .. item.id)
            end
        elseif item.type == "toy" then
            local _, _, toyIcon = C_ToyBox.GetToyInfo(item.id)
            local _, _, _, _, iconID = GetItemInfoInstant(item.id)
            btn.icon:SetTexture(toyIcon or iconID or 134400)
            btn.toyID = item.id
            btn:SetAttribute("type", "macro")
            btn:SetAttribute("macrotext", "/use item:" .. item.id)
        elseif item.type == "housing" then
            if item.iconAtlas and btn.icon.SetAtlas then
                btn.icon:SetAtlas(item.iconAtlas, true)
            else
                SetTextureWithFallback(btn.icon, CollectHouseIconCandidates(item))
            end
            btn.housingData = item
            btn:SetScript("OnClick", function()
                if not InCombatLockdown() and C_Housing and C_Housing.TeleportToHouse then
                    C_Housing.TeleportToHouse(item.houseGUID)
                end
            end)
        end

        self.buttons[index] = btn
    end

    if category == "Dungeons" then
        local grouped = {}
        local currentGroup = { label = "Current Season", items = {} }
        for _, item in ipairs(validItems) do
            if self.DungeonCurrentSeason[item.name] then
                currentGroup.items[#currentGroup.items + 1] = item
            end
        end
        if #currentGroup.items > 0 then
            grouped[#grouped + 1] = currentGroup
        end

        for _, expansion in ipairs(self.DungeonExpansionOrder) do
            local items = {}
            for _, item in ipairs(validItems) do
                if not self.DungeonCurrentSeason[item.name] and self.DungeonExpansionByName[item.name] == expansion then
                    items[#items + 1] = item
                end
            end
            if #items > 0 then
                grouped[#grouped + 1] = { label = expansion, items = items }
            end
        end

        local others = {}
        for _, item in ipairs(validItems) do
            if not self.DungeonCurrentSeason[item.name] and not self.DungeonExpansionByName[item.name] then
                others[#others + 1] = item
            end
        end
        if #others > 0 then
            grouped[#grouped + 1] = { label = "Other", items = others }
        end

        local buttonIndex = 1
        local headerIndex = 1
        local cursorY = 0

        for _, group in ipairs(grouped) do
            local header = AcquireGroupHeader(headerIndex)
            header:SetParent(content)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -cursorY)
            header:SetSize(totalWidth, 18)
            header.text:SetText(group.label)
            header.text:SetTextColor(1, 0.82, 0.25, 1)
            header.line:ClearAllPoints()
            header.line:SetPoint("LEFT", header.text, "RIGHT", 8, 0)
            header.line:SetPoint("RIGHT", header, "RIGHT", 0, 0)
            header.line:SetPoint("CENTER", header, "CENTER", 0, 0)
            header:Show()
            headerIndex = headerIndex + 1
            cursorY = cursorY + 24

            local col, row = 0, 0
            for _, item in ipairs(group.items) do
                ApplyButtonItem(buttonIndex, item, col * (cellW + bSpace), -cursorY - row * (cellH + bSpace))
                buttonIndex = buttonIndex + 1
                col = col + 1
                if col >= bCols then
                    col = 0
                    row = row + 1
                end
            end

            cursorY = cursorY + math_ceil(#group.items / bCols) * (cellH + bSpace) + 10
        end

        content:SetSize(totalWidth, math.max(1, cursorY))
    else
        local col, row = 0, 0
        for i, item in ipairs(validItems) do
            ApplyButtonItem(i, item, col * (cellW + bSpace), -row * (cellH + bSpace))
            col = col + 1
            if col >= bCols then
                col = 0
                row = row + 1
            end
        end

        local totalRows = math_ceil(#validItems / bCols)
        content:SetSize(totalWidth, math.max(1, totalRows * (cellH + bSpace) + bSpace))
    end

    frame.countLabel:SetText(#validItems .. " available")
    self:UpdateAllCooldowns()
end

-- ============================================================================
-- COOLDOWNS
-- ============================================================================

function Mod:UpdateAllCooldowns()
    for _, btn in ipairs(self.buttons) do
        if btn:IsShown() then
            local start, duration
            if btn.spellID then
                local cd = C_Spell.GetSpellCooldown(btn.spellID)
                if cd then start, duration = cd.startTime, cd.duration end
            elseif btn.itemID then
                start, duration = C_Item.GetItemCooldown(btn.itemID)
            elseif btn.toyID then
                start, duration = C_Item.GetItemCooldown(btn.toyID)
            end

            if start and duration and duration > 0 then
                btn.cooldown:SetCooldown(start, duration)
                btn.dimmer:Show()
            else
                btn.cooldown:Clear()
                btn.dimmer:Hide()
            end
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function Mod:OnZoneChanged()
    self:UpdateAllCooldowns()
    if self.reequipData then self:DoReequip() end
end

function Mod:OnEnteringWorld()
    self:ApplyTeleportMinimapButtonStyle()
    C_Timer.After(0.1, function()
        if Mod and Mod.ApplyTeleportMinimapButtonStyle then
            Mod:ApplyTeleportMinimapButtonStyle()
        end
    end)
    self:UpdateAllCooldowns()
    if self.reequipData then self:DoReequip() end
    if C_Housing and C_Housing.GetPlayerOwnedHouses then
        C_Housing.GetPlayerOwnedHouses()
    end
end

function Mod:OnEquipmentChanged()
    -- Porter pattern: save displaced item for later re-equip
    if self.pendingReequip and not self.reequipData then
        local pending = self.pendingReequip
        for slotID, oldData in pairs(pending.slots) do
            local equippedNow = GetInventoryItemID("player", slotID)
            if equippedNow
               and equippedNow == pending.porterItemID
               and equippedNow ~= oldData.id then
                self.pendingReequip = nil
                self.reequipData    = { link = oldData.link, itemID = oldData.id }
                break
            end
        end
    end
end

function Mod:OnSpellSucceeded(_, unit)
    if unit == "player" and self.reequipData then
        self:DoReequip()
    end
end

function Mod:OnSpellInterrupted(_, unit)
    if unit == "player" and self.reequipData and not self.reequipTimer then
        local name = C_Item.GetItemInfo(self.reequipData.itemID)
        print("|cff00FFFF[KT Teleport]|r Cast interrupted — re-equipping "
              .. (name or "previous item") .. " in 12 s.")
        local data = self.reequipData
        self.reequipTimer = C_Timer.NewTimer(12, function() self:DoReequip() end)
    end
end

-- ── Porter re-equip pattern ───────────────────────────────────────────────────
function Mod:DoReequip()
    local reequip = self.reequipData
    if not reequip then return end
    self.reequipData = nil
    if self.reequipTimer then
        self.reequipTimer:Cancel()
        self.reequipTimer = nil
    end
    C_Timer.After(1, function()
        if not InCombatLockdown() then
            EquipItemByName(reequip.link or reequip.itemID)
            local name = C_Item.GetItemInfo(reequip.itemID)
            print("|cff00FFFF[KT Teleport]|r Re-equipped " .. (name or "previous item") .. ".")
        end
    end)
end

-- ── Housing ───────────────────────────────────────────────────────────────────
function Mod:OnHouseListUpdated(_, houseInfos)
    if not houseInfos then return end
    local houseData = {}
    for _, house in ipairs(houseInfos) do
        tinsert(houseData, {
            type              = "housing",
            name              = house.neighborhoodName or house.houseName or "My House",
            neighborhoodGUID  = house.neighborhoodGUID,
            houseGUID         = house.houseGUID,
            plotID            = house.plotID,
            icon              = house.icon or house.iconID or house.iconFileID or house.previewIcon or house.previewIconID or house.previewIconFileID,
            iconAtlas         = house.iconAtlas or house.atlas,
        })
    end
    Mod.TeleportData["House"] = houseData
    self:Refresh()
end

-- ============================================================================
-- TOGGLE / REFRESH
-- ============================================================================

function Mod:Toggle()
    local f = self:CreateMenuFrame()

    if f:GetParent() ~= UIParent then
        f:SetParent(UIParent)
        f:SetClampedToScreen(true)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(20)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:ClearAllPoints()
        f:SetPoint(
            self.db.anchor or "CENTER",
            UIParent, "CENTER",
            self.db.xOffset or 0,
            self.db.yOffset or 0
        )
        f._ktEmbedded = nil
        if f._ktEmbeddedCloseButtons then
            for button in pairs(f._ktEmbeddedCloseButtons) do
                if button then
                    button:Show()
                end
            end
        end
        if f.closeBtn then
            f.closeBtn:Show()
        end
        if f.gearBtn then
            f.gearBtn:Show()
        end
        f:Show()
        self:ShowCategory(self.activeCategory or "Hearthstones")
    elseif f:IsShown() then
        f:Hide()
    else
        f:Show()
        self:ShowCategory(self.activeCategory or "Hearthstones")
    end
end

function Mod:Refresh()
    if InCombatLockdown() then
        self.pendingCategory = self.activeCategory or "Hearthstones"
        return
    end

    self:ApplyTeleportMinimapButtonStyle()

    if self.menuFrame then
        self:ApplyFrameStyle(self.menuFrame)
        self:RefreshThemeColors()
        self:ShowCategory(self.activeCategory)
    end
end

-- ============================================================================
-- MINIMAP BUTTON
-- ============================================================================

function Mod:ApplyTeleportMinimapButtonStyle()
    if not Minimap then return end

    local iconPath = 'Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\extra\\PortalMinimapIconCustom.png'
    local broker = LDB and LDB.GetDataObjectByName and LDB:GetDataObjectByName('KT_Teleport')
    if broker then
        broker.icon = iconPath
        broker.text = 'KullThranUI - Teleport Menu'
        broker.OnTooltipShow = function(tooltip)
            tooltip:AddLine(LText('KullThranUI - Teleport Menu'))
            tooltip:AddLine(LText('Left-click: open/close'), 1, 1, 1)
            tooltip:AddLine(LText('Right-click: settings'), 1, 1, 1)
        end
    end

    self.db.minimap = self.db.minimap or {}
    self.db.minimap.hide = false
    self.db.minimap.lock = true
    if LDBIcon and LDBIcon.Show then
        LDBIcon:Show('KT_Teleport')
    end
    if LDBIcon and LDBIcon.Lock then
        LDBIcon:Lock('KT_Teleport')
    end

    local button = (LDBIcon and LDBIcon:GetMinimapButton('KT_Teleport')) or self.nativeMinimapButton
    if not button then return end

    button._ktMenuLabel = 'KullThranUI - Teleport Menu'
    -- This button sits outside Minimap's bounds; UIParent prevents its mouse
    -- region and artwork from being clipped by the minimap or its overlays.
    button:SetParent(UIParent)
    -- Match the 22x22 Friends/Guild minimap launchers.
    button:SetSize(22, 22)
    button:SetScale(1)
    button:SetAlpha(1)
    button:EnableMouse(true)
    button:Show()
    button:ClearAllPoints()
    button:SetPoint('BOTTOMRIGHT', Minimap, 'BOTTOMLEFT', 0, 0)
    button:SetFrameStrata('HIGH')
    button:SetFrameLevel(51)

    if not button._ktModernBackground then
        local background = button:CreateTexture(nil, 'BACKGROUND')
        background:SetAllPoints()
        background:SetColorTexture(0.012, 0.012, 0.016, 0.96)
        button._ktModernBackground = background

        button._ktModernEdges = {}
        for index = 1, 4 do
            local edge = button:CreateTexture(nil, 'BORDER')
            button._ktModernEdges[index] = edge
        end
        button._ktModernEdges[1]:SetPoint('TOPLEFT')
        button._ktModernEdges[1]:SetPoint('TOPRIGHT')
        button._ktModernEdges[1]:SetHeight(1)
        button._ktModernEdges[2]:SetPoint('BOTTOMLEFT')
        button._ktModernEdges[2]:SetPoint('BOTTOMRIGHT')
        button._ktModernEdges[2]:SetHeight(1)
        button._ktModernEdges[3]:SetPoint('TOPLEFT')
        button._ktModernEdges[3]:SetPoint('BOTTOMLEFT')
        button._ktModernEdges[3]:SetWidth(1)
        button._ktModernEdges[4]:SetPoint('TOPRIGHT')
        button._ktModernEdges[4]:SetPoint('BOTTOMRIGHT')
        button._ktModernEdges[4]:SetWidth(1)
    end

    for _, edge in ipairs(button._ktModernEdges or {}) do
        edge:Hide()
    end

    if button.icon then
        button.icon:SetAlpha(0)
        button.icon:Hide()
    end
    if not button._ktPortalIcon then
        button._ktPortalIcon = button:CreateTexture(nil, 'ARTWORK', nil, 1)
    end
    button._ktPortalIcon:SetTexture(iconPath)
    button._ktPortalIcon:ClearAllPoints()
    button._ktPortalIcon:SetPoint('CENTER', button, 'CENTER', 0, 0)
    button._ktPortalIcon:SetSize(16, 16)
    button._ktPortalIcon:SetTexCoord(0, 1, 0, 1)
    button._ktPortalIcon:SetVertexColor(1, 1, 1, 1)
    button._ktPortalIcon:Show()
    if button.border then button.border:Hide() end
    if button.background then button.background:Hide() end
end

function Mod:SetupMinimapButton()
    if not LDB or not LDBIcon then
        local button = self.nativeMinimapButton or _G.KT_TeleportNativeButton
        if not button then
            button = CreateFrame('Button', 'KT_TeleportNativeButton', UIParent)
            button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
            button.icon = button:CreateTexture(nil, 'ARTWORK')
            button.icon:SetAllPoints()
            button:SetScript('OnClick', function(_, mouseButton)
                if mouseButton == 'LeftButton' then
                    Mod:Toggle()
                elseif mouseButton == 'RightButton' and KT.OpenMenu then
                    Mod:Toggle()
                    KT:OpenMenu('teleportmenu')
                end
            end)
            button:SetScript('OnEnter', function(owner)
                GameTooltip:SetOwner(owner, 'ANCHOR_RIGHT')
                GameTooltip:AddLine(LText('KullThranUI - Teleport Menu'))
                GameTooltip:AddLine(LText('Left-click: open/close'), 1, 1, 1)
                GameTooltip:AddLine(LText('Right-click: settings'), 1, 1, 1)
                GameTooltip:Show()
            end)
            button:SetScript('OnLeave', function() GameTooltip:Hide() end)
        end
        self.nativeMinimapButton = button
        self:ApplyTeleportMinimapButtonStyle()
        return
    end

    local broker = LDB:NewDataObject("KT_Teleport", {
        type  = "launcher",
        text  = "Teleport",
        icon  = "Interface\\Icons\\Spell_Arcane_TeleportStormwind",
        OnClick = function(_, button)
            if button == "LeftButton" then
                Mod:Toggle()
            elseif button == "RightButton" and KT.OpenMenu then
                Mod:Toggle()
                KT:OpenMenu("teleportmenu")
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine(LText("KullThran — Teleport Menu"))
            tt:AddLine(LText("Left-click: open/close"), 1, 1, 1)
            tt:AddLine(LText("Right-click: settings"),  1, 1, 1)
        end,
    })
    LDBIcon:Register("KT_Teleport", broker, self.db.minimap)
end
