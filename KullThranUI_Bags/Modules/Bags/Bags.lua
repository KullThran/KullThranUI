-- Bags.lua
-- Modules/Bags/Bags.lua (moved from Modules/Bags.lua)
-- Purpose: Provide KullThranUI's native bags module, own watched-item state and
-- a native backpack window, and bridge into Baganator through its documented
-- API while that temporary adapter remains in use.
-- Dependencies: Baganator public API only, with Syndicator available through
-- Baganator for inventory lookups.
-- Minimum compatible version: 792.
-- Extension: Replace the Baganator bridge helpers with richer native inventory
-- views without changing the public KullThranUI inventory API.

local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("Bags", "AceEvent-3.0")
local L = KT.GetLocale and KT:GetLocale() or nil

local function LText(key, fallback)
    local value = L and L[key]
    -- AceLocale commonly returns the key itself when no translation exists.
    if value == nil or value == "" or value == key then
        return fallback
    end
    return value
end

local KT_MODULE_NAME = "KullThranUI"
local KT_BAGANATOR_NAME = "Baganator"
local KT_BAGANATOR_MIN_VERSION = 792
local KT_BAGS_DB_KEY = "kullthran_bags_window"
local KT_BAGS_WINDOW_WIDTH = 780
local KT_BAGS_WINDOW_HEIGHT = 540
local KT_BAGS_COLUMNS = 10
local KT_ITEM_SIZE = 40
local KT_ITEM_SPACING = 3
local KT_ITEM_SIZE_MIN = 30
local KT_ITEM_SIZE_MAX = 52
local KT_BAGS_SIDEBAR_WIDTH = 196
local KT_BAGS_SIDEBAR_ROW_HEIGHT = 42
local KT_BAGS_SIDEBAR_ICON_SIZE = 32
local KT_EQUIPPED_BAG_ICON_SIZE = 28
local KT_EQUIPPED_BAG_ICON_SPACING = 4
local KT_FOOTER_CURRENCY_ICON_SIZE = 18
local KT_FOOTER_CURRENCY_SPACING = 10
-- Padding inside the scroll area to prevent default item button textures
-- (borders/highlights) getting clipped at the container edges.
local KT_GRID_PADDING = 4
local KT_BRAND_COLOR = { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.333 }
local KT_DEFAULT_FONT = KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
local KT_BAGS_ICON_TEXTURE = "Interface\\Buttons\\Button-Backpack-Up"
local KT_WATCH_ICON = "|TInterface\\COMMON\\Indicator-Yellow:12:12:0:0|t"
-- Default bag window panel color (hex #331900).
local KT_BAGS_DEFAULT_PANEL_COLOR = { r = 0.2, g = 0.0980392157, b = 0.0, a = 0.94 }
local KT_BAGS_WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local KT_BAGS_BACKGROUND_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\BagsBackground.png"
local KT_BAGS_KUI_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUISettingsSurface.png"

local function KT_Bags_ApplyKuiSurface(frame, washAlpha)
    if not (frame and frame.CreateTexture) then
        return
    end

    -- Keep the KUI texture above BackdropTemplate backgrounds while child
    -- controls continue to render above the surface.
    local artwork = frame.KT_BagsKUIArtwork
    if not artwork then
        artwork = frame:CreateTexture(nil, "ARTWORK", nil, -8)
        artwork:SetAllPoints(frame)
        artwork:SetTexture(KT_BAGS_KUI_TEXTURE)
        frame.KT_BagsKUIArtwork = artwork
    end
    artwork:SetAlpha(0.86)
    artwork:Show()

    local wash = frame.KT_BagsKUIWash
    if not wash then
        wash = frame:CreateTexture(nil, "ARTWORK", nil, -7)
        wash:SetAllPoints(frame)
        frame.KT_BagsKUIWash = wash
    end
    wash:SetColorTexture(0.008, 0.010, 0.016, washAlpha or 0.42)
    wash:Show()
end

local function KT_Bags_GetAccentColor(alpha)
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin or nil
    if skin and skin.bagsColorMode == "custom" and skin.bagsColor then
        local c = skin.bagsColor
        return c.r or KT_BRAND_COLOR.r, c.g or KT_BRAND_COLOR.g, c.b or KT_BRAND_COLOR.b, alpha or 1
    end
    if KT and KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        return r or KT_BRAND_COLOR.r, g or KT_BRAND_COLOR.g, b or KT_BRAND_COLOR.b, alpha or 1
    end
    return KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, alpha or 1
end

local function KT_Bags_GetAccentTextColor(alpha, strength)
    local accentR, accentG, accentB = KT_Bags_GetAccentColor()
    local mix = strength or 0.14
    local baseR, baseG, baseB = 0.92, 0.92, 0.95
    return (baseR * (1 - mix)) + (accentR * mix),
        (baseG * (1 - mix)) + (accentG * mix),
        (baseB * (1 - mix)) + (accentB * mix),
        alpha or 1
end

local function KT_Bags_ApplyTextureGradient(texture, orientation, startR, startG, startB, startA, endR, endG, endB, endA)
    if not texture then
        return
    end

    texture:SetTexture(KT_BAGS_WHITE8X8)
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha(
            orientation or "HORIZONTAL",
            startR or 1, startG or 1, startB or 1, startA or 1,
            endR or 1, endG or 1, endB or 1, endA or 1
        )
    else
        texture:SetColorTexture(startR or 1, startG or 1, startB or 1, math.max(startA or 0, endA or 0))
    end
end

local function KT_Bags_EnsureAccentSurface(frame)
    if not frame or frame.KT_AccentSurface then
        return frame and frame.KT_AccentSurface or nil
    end

    local surface = {}

    surface.topGlow = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
    surface.topGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    surface.topGlow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    surface.leftGlow = frame:CreateTexture(nil, "BACKGROUND", nil, 4)
    surface.leftGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    surface.leftGlow:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)

    surface.bottomLine = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    surface.bottomLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    surface.bottomLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    surface.bottomLine:SetHeight(1)
    surface.bottomLine:SetTexture(KT_BAGS_WHITE8X8)

    frame.KT_AccentSurface = surface
    return surface
end

local function KT_Bags_ApplyAccentSurface(frame, opts)
    local surface = KT_Bags_EnsureAccentSurface(frame)
    if not surface then
        return
    end

    opts = opts or {}
    local accentR, accentG, accentB = KT_Bags_GetAccentColor()
    local width = frame.GetWidth and frame:GetWidth() or 400
    local height = frame.GetHeight and frame:GetHeight() or 100

    local topHeight = math.max(1, math.floor(height * (opts.topCoverage or 0.42)))
    local leftWidth = math.max(1, math.floor(width * (opts.leftCoverage or 0.55)))
    surface.topGlow:SetHeight(topHeight)
    surface.leftGlow:SetWidth(leftWidth)

    KT_Bags_ApplyTextureGradient(surface.topGlow, "VERTICAL", accentR, accentG, accentB, opts.topAlpha or 0.035, accentR, accentG, accentB, 0)
    KT_Bags_ApplyTextureGradient(surface.leftGlow, "HORIZONTAL", accentR, accentG, accentB, opts.leftAlpha or 0.025, accentR, accentG, accentB, 0)
    KT_Bags_ApplyTextureGradient(surface.bottomLine, "HORIZONTAL", accentR, accentG, accentB, 0, accentR, accentG, accentB, opts.lineAlpha or 0.12)

    if frame.SetBackdropBorderColor and opts.accentBorderAlpha and opts.accentBorderAlpha > 0 then
        frame:SetBackdropBorderColor(accentR, accentG, accentB, opts.accentBorderAlpha)
    end
end

local function KT_Bags_StyleScrollBar(slider)
    if not slider then
        return
    end

    local ar, ag, ab = KT_Bags_GetAccentColor()
    slider:SetOrientation("VERTICAL")
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetWidth(8)
    slider:SetThumbTexture(KT_BAGS_WHITE8X8)

    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetWidth(8)
        thumb:SetHeight(42)
        thumb:SetVertexColor(ar, ag, ab, 0.92)
    end

    if not slider.KT_Track then
        slider.KT_Track = slider:CreateTexture(nil, "BACKGROUND")
        slider.KT_Track:SetAllPoints(slider)
        slider.KT_Track:SetTexture(KT_BAGS_WHITE8X8)
    end
    slider.KT_Track:SetColorTexture(0, 0, 0, 0.48)

    if not slider.KT_Border then
        slider.KT_Border = CreateFrame("Frame", nil, slider, "BackdropTemplate")
        slider.KT_Border:SetAllPoints(slider)
        slider.KT_Border:SetBackdrop({
            edgeFile = KT_BAGS_WHITE8X8,
            edgeSize = 1,
        })
    end
    slider.KT_Border:SetBackdropBorderColor(ar, ag, ab, 0.42)
end

local function KT_Bags_UpdateScrollBar(scrollFrame, slider, content)
    if not (scrollFrame and slider and content) then
        return
    end

    local viewHeight = scrollFrame:GetHeight() or 0
    local contentHeight = content:GetHeight() or 0
    local maxScroll = math.max(0, contentHeight - viewHeight)
    slider:SetMinMaxValues(0, maxScroll)

    if maxScroll <= 0 then
        slider:SetValue(0)
        scrollFrame:SetVerticalScroll(0)
        slider:Hide()
        return
    end

    if slider:GetValue() > maxScroll then
        slider:SetValue(maxScroll)
    end
    slider:Show()
end

local function KT_Bags_EnsureAmbientGradient(frame)
    if not frame or frame.KT_AmbientGradient then
        return frame and frame.KT_AmbientGradient or nil
    end

    local ambient = {}

    ambient.fill = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    ambient.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    ambient.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    ambient.fill:SetTexture(KT_BAGS_WHITE8X8)

    ambient.shade = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    ambient.shade:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    ambient.shade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    ambient.shade:SetTexture(KT_BAGS_WHITE8X8)

    ambient.art = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
    ambient.art:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    ambient.art:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    ambient.art:SetTexture(KT_BAGS_BACKGROUND_TEXTURE)
    ambient.art:SetBlendMode("MOD")

    frame.KT_AmbientGradient = ambient
    return ambient
end

local function KT_Bags_ApplyAmbientGradient(frame, opts)
    local ambient = KT_Bags_EnsureAmbientGradient(frame)
    if not ambient then
        return
    end

    opts = opts or {}
    local accentR, accentG, accentB = KT_Bags_GetAccentColor()
    KT_Bags_ApplyTextureGradient(
        ambient.fill,
        "HORIZONTAL",
        accentR, accentG, accentB, opts.fillAlpha or 0.16,
        0, 0, 0, opts.fillEndAlpha or 0.06
    )
    KT_Bags_ApplyTextureGradient(
        ambient.shade,
        "VERTICAL",
        0, 0, 0, opts.shadeTopAlpha or 0.10,
        0, 0, 0, opts.shadeBottomAlpha or 0.02
    )
    ambient.art:SetVertexColor(1, 1, 1, opts.artAlpha or 0.82)
end

local function KT_Bags_GetConfiguredItemSize(module)
    local size = tonumber(module and module.db and module.db.itemSize) or KT_ITEM_SIZE
    size = math.floor(size + 0.5)
    if size < KT_ITEM_SIZE_MIN then
        return KT_ITEM_SIZE_MIN
    end
    if size > KT_ITEM_SIZE_MAX then
        return KT_ITEM_SIZE_MAX
    end
    return size
end

local BAG_CATEGORY_ORDER = {
    "Equipment",
    "Consumables",
    "Crafting",
    "Quest",
    "Miscellaneous",
}

local BACKPACK_START = BACKPACK_CONTAINER or 0
local BACKPACK_END = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 5

local tinsert = table.insert
local format = string.format
local sort = table.sort
local lower = string.lower
local strtrim = strtrim

local function KT_Bags_IsEditModeActive()
    local editMode = _G.EditModeManagerFrame
    return editMode and editMode.IsEditModeActive and editMode:IsEditModeActive()
end

local function KT_Bags_GetPreviewHost()
    return _G.MicroButtonAndBagsBar
        or (_G.BagsBar and _G.BagsBar:GetParent())
        or _G.BagsBar
end

local function KT_Bags_GetButtonIconTexture(button)
    if not button then
        return nil
    end

    local icon = button.icon or button.Icon or _G[(button:GetName() or "") .. "IconTexture"]
    if icon and icon.GetTexture then
        local texture = icon:GetTexture()
        if texture then
            return texture
        end
    end

    if button.GetNormalTexture then
        local normal = button:GetNormalTexture()
        if normal and normal.GetTexture then
            local texture = normal:GetTexture()
            if texture then
                return texture
            end
        end
    end
end

local function KT_Bags_EnsureEditModeBagBarPreview()
    local host = KT_Bags_GetPreviewHost()
    if not host then
        return nil
    end

    local preview = host.KT_EditModePreview
    if preview then
        return preview
    end

    preview = _G.CreateFrame("Frame", nil, host)
    preview:SetAllPoints(host)
    preview:SetIgnoreParentAlpha(false)
    preview:EnableMouse(false)
    preview:SetFrameLevel(host:GetFrameLevel() + 5)
    host.KT_EditModePreview = preview

    preview.slots = {}
    for index = 1, 4 do
        local slot = preview:CreateTexture(nil, "ARTWORK")
        slot:SetSize(22, 22)
        slot:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        preview.slots[index] = slot
    end

    preview.arrow = preview:CreateTexture(nil, "ARTWORK")
    preview.arrow:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\right_arrow.png")
    preview.arrow:SetSize(10, 14)

    preview.backpack = preview:CreateTexture(nil, "ARTWORK")
    preview.backpack:SetSize(30, 30)
    preview.backpack:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    return preview
end

local function KT_Bags_RefreshEditModeBagBarPreview()
    local preview = KT_Bags_EnsureEditModeBagBarPreview()
    if not preview then
        return
    end

    local host = preview:GetParent()
    local centerY = 0
    local slotSpacing = 6
    local slotButtons = {
        _G.CharacterBag0Slot,
        _G.CharacterBag1Slot,
        _G.CharacterBag2Slot,
        _G.CharacterBag3Slot,
    }

    local previous
    for index = 1, 4 do
        local slot = preview.slots[index]
        local texture = KT_Bags_GetButtonIconTexture(slotButtons[index]) or KT_BAGS_ICON_TEXTURE
        slot:SetTexture(texture)
        slot:ClearAllPoints()
        if previous then
            slot:SetPoint("RIGHT", previous, "LEFT", -slotSpacing, 0)
        else
            slot:SetPoint("RIGHT", host, "RIGHT", -46, centerY)
        end
        previous = slot
        slot:Show()
    end

    preview.arrow:ClearAllPoints()
    preview.arrow:SetPoint("LEFT", previous, "RIGHT", 7, 0)
    preview.arrow:Show()

    preview.backpack:SetTexture(KT_Bags_GetButtonIconTexture(_G.MainMenuBarBackpackButton) or KT_BAGS_ICON_TEXTURE)
    preview.backpack:ClearAllPoints()
    preview.backpack:SetPoint("LEFT", preview.arrow, "RIGHT", 7, 0)
    preview.backpack:Show()
end

local function KT_Bags_SetEditModeBagBarPreviewVisible(visible)
    local preview = KT_Bags_EnsureEditModeBagBarPreview()
    if not preview then
        return
    end

    if visible then
        KT_Bags_RefreshEditModeBagBarPreview()
        preview:Show()
    else
        preview:Hide()
    end
end

local CRAFTING_CLASS_IDS = {}
if LE_ITEM_CLASS_TRADEGOODS then
    CRAFTING_CLASS_IDS[LE_ITEM_CLASS_TRADEGOODS] = true
end
if LE_ITEM_CLASS_RECIPE then
    CRAFTING_CLASS_IDS[LE_ITEM_CLASS_RECIPE] = true
end

local KT_BAGS_CATEGORY_DIVIDER = "----"
local KT_BAGS_CATEGORY_SECTION_END = "__end"
local KT_BAGS_CATEGORY_DEFAULT_ORDER = {
    "default_auto_recents",
    KT_BAGS_CATEGORY_DIVIDER,
    "default_hearthstone",
    "default_keystone",
    "default_potion",
    "default_food",
    "default_consumable",
    "default_questitem",
    "_1",
    "default_auto_equipment_sets",
    "default_weapon",
    "default_armor",
    KT_BAGS_CATEGORY_SECTION_END,
    "_2",
    "default_reagent",
    "default_tradegoods",
    "default_profession",
    "default_recipe",
    KT_BAGS_CATEGORY_SECTION_END,
    "_3",
    "default_housing",
    KT_BAGS_CATEGORY_SECTION_END,
    "default_gem",
    "default_itemenhancement",
    "default_container",
    "default_key",
    "default_miscellaneous",
    "default_battlepet",
    "default_toy",
    "default_other",
    KT_BAGS_CATEGORY_DIVIDER,
    "default_junk",
    "default_special_empty",
}
local KT_BAGS_CATEGORY_DEFAULT_SECTIONS = {
    ["1"] = { name = "EQUIPMENT" },
    ["2"] = { name = "CRAFTING" },
    ["3"] = { name = "HOUSING" },
}

local KT_BAGS_DEFAULT_SOURCE_TO_CATEGORY = nil

local function KT_Bags_SafeLower(value)
    if not value then
        return ""
    end
    return lower(value)
end

local function KT_Bags_GetItemClassName(classID, fallback)
    if classID and C_Item and C_Item.GetItemClassInfo then
        local name = C_Item.GetItemClassInfo(classID)
        if name and name ~= "" then
            return name
        end
    end
    return fallback or ""
end

local function KT_Bags_GetSyndicatorKeyword(key, fallback)
    if _G.Syndicator and _G.Syndicator.Locales and _G.Syndicator.Locales[key] then
        return _G.Syndicator.Locales[key]
    end
    return fallback or ""
end

local function KT_Bags_GetBaganatorLocale(key, fallback)
    if _G.BAGANATOR_LOCALES then
        local locale = GetLocale and GetLocale() or "enUS"
        local pack = _G.BAGANATOR_LOCALES[locale] or _G.BAGANATOR_LOCALES.enUS
        if pack and pack[key] then
            return pack[key]
        end
    end
    return fallback or ""
end

local function KT_Bags_GetItemLevel(itemLink)
    if not itemLink then
        return nil
    end

    local itemLevel
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
    elseif GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(itemLink)
    end

    if type(itemLevel) == "number" and itemLevel > 0 then
        return itemLevel
    end

    return nil
end

local function KT_Bags_IsRealEquipment(classID, equipLoc)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then
        return false
    end

    if equipLoc == "INVTYPE_BAG" or equipLoc == "INVTYPE_QUIVER" or equipLoc == "INVTYPE_AMMO"
        or equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" then
        return false
    end

    -- Item level is useful for actual gear, not for toys, consumables,
    -- hearthstones, reagents or other items that happen to expose a level.
    local weaponClass = LE_ITEM_CLASS_WEAPON or 2
    local armorClass = LE_ITEM_CLASS_ARMOR or 4
    return classID == weaponClass or classID == armorClass
end
local function KT_Bags_GetQualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r or 1, color.g or 1, color.b or 1
    end
    return 1, 0.82, 0
end

local KT_BAGS_CATEGORY_ICONS = {
    all = KT_BAGS_ICON_TEXTURE,
    onebag = "Interface\\Icons\\INV_Misc_Bag_08",
    watched = { atlas = "friendslist-recentallies-Pin-yellow" },
    default_auto_recents = { atlas = "auctionhouse-icon-clock" },
    default_auto_equipment_sets = 4871338,
    default_hearthstone = 134414,
    default_keystone = 525134,
    default_potion = 134730,
    default_food = 133971,
    default_consumable = 4620673,
    default_questitem = { atlas = "Crosshair_Quest_64" },
    default_weapon = 135349,
    default_armor = 132716,
    default_reagent = 134071,
    default_tradegoods = 132996,
    default_profession = 4620671,
    default_recipe = 134939,
    default_housing = 134453,
    default_gem = 134071,
    default_itemenhancement = 463531,
    default_container = "Interface\\Icons\\INV_Misc_Bag_10",
    default_key = 134237,
    default_miscellaneous = 134400,
    default_battlepet = 656579,
    default_toy = 454046,
    default_other = 134400,
    default_junk = 133724,
    default_special_empty = "Interface\\PaperDoll\\UI-Backpack-EmptySlot",
}

local function KT_Bags_SetIconTexture(texture, icon)
    if not texture then
        return
    end

    texture:SetSize(KT_BAGS_SIDEBAR_ICON_SIZE, KT_BAGS_SIDEBAR_ICON_SIZE)
    texture:SetVertexColor(1, 1, 1, 1)

    if type(icon) == "table" and icon.atlas and texture.SetAtlas then
        local ok = pcall(texture.SetAtlas, texture, icon.atlas, false)
        if ok then
            texture:SetSize(KT_BAGS_SIDEBAR_ICON_SIZE, KT_BAGS_SIDEBAR_ICON_SIZE)
            return
        end
    end

    texture:SetTexture(icon or KT_BAGS_ICON_TEXTURE)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    texture:SetSize(KT_BAGS_SIDEBAR_ICON_SIZE, KT_BAGS_SIDEBAR_ICON_SIZE)
end

local function KT_Bags_AddDefaultCategory(map, spec)
    spec.source = "default_" .. spec.key
    spec.priorityOffset = spec.priorityOffset or -70
    map[spec.source] = spec
end

local function KT_Bags_BuildDefaultSourceToCategory()
    if KT_BAGS_DEFAULT_SOURCE_TO_CATEGORY then
        return KT_BAGS_DEFAULT_SOURCE_TO_CATEGORY
    end

    local sourceToCategory = {}
    local class = Enum and Enum.ItemClass or nil

    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "keystone",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_KEYSTONE", LText("BAGS_CATEGORY_KEYSTONE", "Keystone")),
        search = "#" .. KT_Bags_GetSyndicatorKeyword("KEYWORD_KEYSTONE", "keystone"),
        priorityOffset = -40,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "potion",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_POTION", LText("BAGS_CATEGORY_POTION", "Potion")),
        search = "#" .. KT_Bags_GetSyndicatorKeyword("KEYWORD_POTION", "potion"),
        priorityOffset = -40,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "food",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_FOOD", LText("BAGS_CATEGORY_FOOD", "Food")),
        search = "#" .. KT_Bags_GetSyndicatorKeyword("KEYWORD_FOOD", "food"),
        priorityOffset = -40,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "consumable",
        name = KT_Bags_GetItemClassName(class and class.Consumable, LText("BAGS_CATEGORY_CONSUMABLE", "Consumable")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Consumable, "consumable")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "gem",
        name = KT_Bags_GetItemClassName(class and class.Gem, LText("BAGS_CATEGORY_GEM", "Gem")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Gem, "gem")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "itemenhancement",
        name = KT_Bags_GetItemClassName(class and class.ItemEnhancement, LText("BAGS_CATEGORY_ITEM_ENHANCEMENT", "Item Enhancement")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.ItemEnhancement, "item enhancement")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "profession",
        name = KT_Bags_GetItemClassName(class and class.Profession, LText("BAGS_CATEGORY_PROFESSION", "Profession")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Profession, "profession")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "key",
        name = KT_Bags_GetItemClassName(class and class.Key, LText("BAGS_CATEGORY_KEY", "Key")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Key, "key")),
        priorityOffset = -35,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "battlepet",
        name = KT_Bags_GetItemClassName(class and class.Battlepet, TOOLTIP_BATTLE_PET or "Battle Pet"),
        search = "#" .. KT_Bags_GetSyndicatorKeyword("KEYWORD_BATTLE_PET", "battle pet"),
        priorityOffset = -60,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "toy",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_TOY", TOY or LText("BAGS_CATEGORY_TOY", "Toy")),
        search = "#" .. KT_Bags_SafeLower(TOY or "toy"),
        priorityOffset = -20,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "housing",
        name = KT_Bags_GetItemClassName(class and class.Housing, LText("BAGS_CATEGORY_HOUSING", "Housing")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Housing, "housing")),
        priorityOffset = 0,
    })

    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "hearthstone",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_HEARTHSTONE", LText("BAGS_CATEGORY_HEARTHSTONE", "Hearthstone")),
        search = KT_Bags_SafeLower(KT_Bags_GetBaganatorLocale("CATEGORY_HEARTHSTONE", LText("BAGS_CATEGORY_HEARTHSTONE", "Hearthstone")))
            .. "&#"
            .. KT_Bags_SafeLower(ITEM_UNIQUE or "unique")
            .. "&#"
            .. KT_Bags_SafeLower(ITEM_SOULBOUND or "soulbound"),
        priorityOffset = -10,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "consumable",
        name = KT_Bags_GetItemClassName(class and class.Consumable, LText("BAGS_CATEGORY_CONSUMABLE", "Consumable")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Consumable, "consumable")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "reagent",
        name = KT_Bags_GetItemClassName(class and class.Reagent, LText("BAGS_CATEGORY_REAGENT", "Reagent")),
        search = "#" .. KT_Bags_GetSyndicatorKeyword("KEYWORD_REAGENT", "reagent"),
        priorityOffset = -50,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "auto_equipment_sets",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_EQUIPMENT_SETS_AUTO", LText("BAGS_CATEGORY_EQUIPMENT_SETS", "Equipment Sets")),
        auto = "equipment_sets",
        priorityOffset = -10,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "weapon",
        name = KT_Bags_GetItemClassName(class and class.Weapon, LText("BAGS_CATEGORY_WEAPON", "Weapon")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Weapon, "weapon")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "armor",
        name = KT_Bags_GetItemClassName(class and class.Armor, LText("BAGS_CATEGORY_ARMOR", "Armor")),
        search = "#"
            .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Armor, "armor"))
            .. "&#"
            .. KT_Bags_GetSyndicatorKeyword("KEYWORD_GEAR", "gear"),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "container",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_BAG", LText("BAGS_CATEGORY_BAG", "Bag")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Container, "container")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "tradegoods",
        name = KT_Bags_GetItemClassName(class and class.Tradegoods, LText("BAGS_CATEGORY_TRADEGOODS", "Trade Goods")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Tradegoods, "trade goods")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "recipe",
        name = KT_Bags_GetItemClassName(class and class.Recipe, LText("BAGS_CATEGORY_RECIPE", "Recipe")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Recipe, "recipe")),
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "questitem",
        name = KT_Bags_GetItemClassName(class and class.Questitem, LText("BAGS_CATEGORY_QUEST", "Quest")),
        search = "#" .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Questitem, "quest")),
        priorityOffset = -65,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "miscellaneous",
        name = KT_Bags_GetItemClassName(class and class.Miscellaneous, LText("BAGS_CATEGORY_MISC", "Miscellaneous")),
        search = "#"
            .. KT_Bags_SafeLower(KT_Bags_GetItemClassName(class and class.Miscellaneous, "miscellaneous"))
            .. "&!#"
            .. KT_Bags_GetSyndicatorKeyword("KEYWORD_GEAR", "gear"),
        priorityOffset = -30,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "other",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_OTHER", LText("BAGS_CATEGORY_OTHER", "Other")),
        search = "",
        priorityOffset = -90,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "junk",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_JUNK", LText("BAGS_CATEGORY_JUNK", "Junk")),
        search = "#" .. KT_Bags_GetSyndicatorKeyword("KEYWORD_JUNK", "junk"),
        priorityOffset = -15,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "auto_inventory_slots",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_INVENTORY_SLOTS_AUTO", LText("BAGS_CATEGORY_INVENTORY_SLOTS", "Inventory Slots")),
        auto = "inventory_slots",
        priorityOffset = -40,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "auto_recents",
        name = KT_Bags_GetBaganatorLocale("CATEGORY_RECENT_AUTO", LText("BAGS_CATEGORY_RECENT", "Recent")),
        auto = "recents",
        priorityOffset = 10000,
    })
    KT_Bags_AddDefaultCategory(sourceToCategory, {
        key = "special_empty",
        name = EMPTY or LText("BAGS_CATEGORY_EMPTY", "Empty"),
        emptySlots = true,
    })

    if _G.TSM_API then
        KT_Bags_AddDefaultCategory(sourceToCategory, {
            key = "auto_tradeskillmaster",
            name = KT_Bags_GetBaganatorLocale("CATEGORY_TRADESKILLMASTER_AUTO", "TradeSkillMaster (Auto)"),
            auto = "tradeskillmaster",
            priorityOffset = -15,
        })
    end

    KT_BAGS_DEFAULT_SOURCE_TO_CATEGORY = sourceToCategory
    return sourceToCategory
end

local function KT_Bags_GetBaganatorProfile()
    if not _G.BAGANATOR_CONFIG or not _G.BAGANATOR_CONFIG.Profiles or not _G.BAGANATOR_CURRENT_PROFILE then
        if not _G.BAGANATOR_CONFIG or not _G.BAGANATOR_CONFIG.Profiles then
            return nil
        end
        for _, profile in pairs(_G.BAGANATOR_CONFIG.Profiles) do
            return profile
        end
        return nil
    end
    return _G.BAGANATOR_CONFIG.Profiles[_G.BAGANATOR_CURRENT_PROFILE]
end

local function KT_Bags_GetAddedItemData(itemID, itemLink)
    local petID = itemLink and tonumber((itemLink:match("battlepet:(%d+)")))
    if petID then
        return "p:" .. petID
    end
    return "i:" .. tostring(itemID or 0)
end

local function KT_Bags_GetEquipmentSetMap()
    local setIDs = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetEquipmentSetIDs() or nil
    if not setIDs or #setIDs == 0 then
        return nil
    end

    local map = {}
    map.__setIcons = {}
    for _, setID in ipairs(setIDs) do
        local name, iconFileID = C_EquipmentSet.GetEquipmentSetInfo(setID)
        local itemIDs = C_EquipmentSet.GetItemIDs(setID)
        if name and iconFileID then
            map.__setIcons[name] = iconFileID
        end
        if name and itemIDs then
            for _, itemID in pairs(itemIDs) do
                if itemID then
                    map[itemID] = map[itemID] or {}
                    map[itemID][name] = true
                end
            end
        end
    end

    return map
end

local function KT_Bags_GetBaganatorCategoryData()
    local baganator = _G.Baganator
    local opts = baganator and baganator.Config and baganator.Config.Options or nil
    local displayOrder
    local customCategories
    local categoryMods
    local sections

    if baganator and baganator.Config and baganator.Config.Get and opts then
        displayOrder = baganator.Config.Get(opts.CATEGORY_DISPLAY_ORDER)
        customCategories = baganator.Config.Get(opts.CUSTOM_CATEGORIES)
        categoryMods = baganator.Config.Get(opts.CATEGORY_MODIFICATIONS)
        sections = baganator.Config.Get(opts.CATEGORY_SECTIONS)
    else
        local profile = KT_Bags_GetBaganatorProfile()
        if profile then
            displayOrder = profile.category_display_order
            customCategories = profile.custom_categories
            categoryMods = profile.category_modifications
            sections = profile.category_sections
        end
    end

    if type(displayOrder) ~= "table" or #displayOrder == 0 then
        displayOrder = CopyTable(KT_BAGS_CATEGORY_DEFAULT_ORDER)
    else
        displayOrder = CopyTable(displayOrder)
    end

    if type(sections) ~= "table" or next(sections) == nil then
        sections = CopyTable(KT_BAGS_CATEGORY_DEFAULT_SECTIONS)
    else
        sections = CopyTable(sections)
    end

    if type(customCategories) ~= "table" then
        customCategories = {}
    else
        customCategories = CopyTable(customCategories)
    end

    if type(categoryMods) ~= "table" then
        categoryMods = {}
    else
        categoryMods = CopyTable(categoryMods)
    end

    local dividerName = KT_BAGS_CATEGORY_DIVIDER
    local sectionEnd = KT_BAGS_CATEGORY_SECTION_END
    local sourceToCategory = KT_Bags_BuildDefaultSourceToCategory()

    if baganator and baganator.CategoryViews and baganator.CategoryViews.Constants then
        sourceToCategory = baganator.CategoryViews.Constants.SourceToCategory or sourceToCategory
        dividerName = baganator.CategoryViews.Constants.DividerName or dividerName
        sectionEnd = baganator.CategoryViews.Constants.SectionEnd or sectionEnd
    end

    return {
        displayOrder = displayOrder,
        customCategories = customCategories,
        categoryMods = categoryMods,
        sections = sections,
        sourceToCategory = sourceToCategory,
        dividerName = dividerName,
        sectionEnd = sectionEnd,
    }
end

local function KT_Bags_GetAutoCategoryDetails(category, everything, equipmentSetMap)
    local searches, searchLabels, attachedItems, icons = {}, {}, {}, {}
    if category.auto == "equipment_sets" then
        local groupedItems = {}
        for _, item in ipairs(everything) do
            if item.setInfo then
                for _, setEntry in ipairs(item.setInfo) do
                    local setName = setEntry.name
                    if setName and setName ~= "" then
                        groupedItems[setName] = groupedItems[setName] or {}
                        groupedItems[setName][item.key] = true
                    end
                end
            elseif equipmentSetMap and item.itemID then
                local sets = equipmentSetMap[item.itemID]
                if sets then
                    for setName in pairs(sets) do
                        groupedItems[setName] = groupedItems[setName] or {}
                        groupedItems[setName][item.key] = true
                    end
                end
            end
        end

        local names = {}
        for setName in pairs(groupedItems) do
            table.insert(names, setName)
        end
        table.sort(names)

        if #names > 0 then
            for _, setName in ipairs(names) do
                local index = #searches + 1
                searches[index] = ""
                searchLabels[index] = setName
                attachedItems[index] = groupedItems[setName]
                icons[index] = equipmentSetMap and equipmentSetMap.__setIcons and equipmentSetMap.__setIcons[setName] or nil
            end
        else
            table.insert(searchLabels, KT_Bags_GetBaganatorLocale("CATEGORY_EQUIPMENT_SET", CATEGORY_EQUIPMENT_SET or "Equipment Set"))
            table.insert(searches, "#" .. (Syndicator and Syndicator.Locales and Syndicator.Locales.KEYWORD_EQUIPMENT_SET or "equipment set"))
        end
    elseif category.auto == "inventory_slots" then
        local inventorySlots = {
            "INVTYPE_2HWEAPON",
            "INVTYPE_WEAPON",
            "INVTYPE_WEAPONMAINHAND",
            "INVTYPE_WEAPONOFFHAND",
            "INVTYPE_SHIELD",
            "INVTYPE_HOLDABLE",
            "INVTYPE_RANGED",
            "INVTYPE_RANGEDRIGHT",
            "INVTYPE_THROWN",
            "INVTYPE_AMMO",
            "INVTYPE_QUIVER",
            "INVTYPE_RELIC",
            "INVTYPE_HEAD",
            "INVTYPE_SHOULDER",
            "INVTYPE_CLOAK",
            "INVTYPE_CHEST",
            "INVTYPE_ROBE",
            "INVTYPE_WRIST",
            "INVTYPE_HAND",
            "INVTYPE_WAIST",
            "INVTYPE_LEGS",
            "INVTYPE_FEET",
            "INVTYPE_NECK",
            "INVTYPE_FINGER",
            "INVTYPE_TRINKET",
            "INVTYPE_BODY",
            "INVTYPE_TABARD",
            "INVTYPE_PROFESSION_TOOL",
            "INVTYPE_PROFESSION_GEAR",
            "INVTYPE_BAG",
        }
        for _, slot in ipairs(inventorySlots) do
            local name = _G[slot]
            if name then
                table.insert(searchLabels, name)
                local gearKeyword = Syndicator and Syndicator.Locales and Syndicator.Locales.KEYWORD_GEAR or "gear"
                table.insert(searches, "#" .. gearKeyword .. "&#" .. name:lower())
            end
        end
    elseif category.auto == "recents" then
        table.insert(searches, "")
        table.insert(searchLabels, KT_Bags_GetBaganatorLocale("CATEGORY_RECENT", RECENTLY_LOOTED or "Recent"))
        local newItems = {}
        for _, item in ipairs(everything) do
            if item.isNewItem and item.key then
                newItems[item.key] = true
            end
        end
        attachedItems[1] = newItems
    elseif category.auto == "tradeskillmaster" then
        if _G.TSM_API then
            local groups = {}
            for _, item in ipairs(everything) do
                local itemString = TSM_API.ToItemString(item.itemLink)
                if itemString then
                    local groupPath = TSM_API.GetGroupPathByItem(itemString)
                    if groupPath then
                        groups[groupPath] = groups[groupPath] or {}
                        groups[groupPath][item.key] = KT_Bags_GetAddedItemData(item.itemID, item.itemLink)
                    end
                end
            end
            local prevLevel = 1
            for _, groupPath in ipairs(TSM_API.GetGroupPaths({})) do
                local parts = { strsplit("`", groupPath) }
                if #parts > prevLevel then
                    attachedItems[#searches + 1] = attachedItems[#searches]
                    attachedItems[#searches] = nil
                    table.insert(searches, #searches, "__start")
                    searchLabels[#searches] = searchLabels[#searches - 1]
                    searchLabels[#searches - 1] = parts[prevLevel]
                end
                while #parts < prevLevel do
                    prevLevel = prevLevel - 1
                    table.insert(searches, "__end")
                end
                local index = #searches + 1
                searches[index] = ""
                searchLabels[index] = parts[#parts]
                attachedItems[index] = groups[groupPath]
                prevLevel = #parts
            end
            while prevLevel > 1 do
                prevLevel = prevLevel - 1
                table.insert(searches, "__end")
            end
        end
    end

    return { searches = searches, searchLabels = searchLabels, attachedItems = attachedItems, icons = icons }
end

local function KT_Bags_ComposeCategories(everything, location, categoryData, equipmentSetMap)
    local allDetails = {}
    local customCategories = categoryData.customCategories or {}
    local categoryMods = categoryData.categoryMods or {}
    local sections = categoryData.sections or {}
    local displayOrder = categoryData.displayOrder or {}
    local sourceToCategory = categoryData.sourceToCategory or {}

    local currentSection = {}
    for _, source in ipairs(displayOrder) do
        local section = CopyTable(currentSection)
        if source == categoryData.dividerName then
            table.insert(allDetails, {
                type = "divider",
                section = section,
            })
        end
        if source == categoryData.sectionEnd then
            table.remove(currentSection)
            table.remove(section)
            table.insert(allDetails, {
                type = "divider",
                section = section,
            })
        elseif source:sub(1, 1) == "_" then
            local sectionID = source:match("^_(.*)")
            table.insert(allDetails, {
                type = "divider",
                section = section,
            })
            local sectionDetails = sections[sectionID]
            local sectionName = sectionDetails and sectionDetails.name or sectionID
            local label = KT_Bags_GetBaganatorLocale("SECTION_" .. sectionName, sectionName)
            table.insert(currentSection, sectionID)
            table.insert(allDetails, {
                type = "section",
                source = sectionID,
                label = label,
                section = section,
            })
        end

        local priority = categoryMods[source] and categoryMods[source].priority and (categoryMods[source].priority + 1) * 200 or 0
        local mods = categoryMods[source]
        local group, groupPrefix, attachedItems
        local shouldShow = true
        if mods then
            if mods.addedItems and next(mods.addedItems) then
                attachedItems = mods.addedItems
            end
            group = mods.group
            groupPrefix = mods.showGroupPrefix
            shouldShow = mods.hideIn == nil or not mods.hideIn[location]
        end

        local category = sourceToCategory[source]
        if category and shouldShow then
            if category.auto then
                local autoDetails = KT_Bags_GetAutoCategoryDetails(category, everything, equipmentSetMap)
                local currentTree = {}
                for index = 1, #autoDetails.searches do
                    section = CopyTable(currentSection)
                    local search = autoDetails.searches[index]
                    if search == "__start" or search == "__end" then
                        if search == "__end" then
                            table.remove(currentTree)
                            table.remove(currentSection)
                            table.remove(section)
                            table.insert(allDetails, {
                                type = "divider",
                                section = section,
                            })
                        elseif search == "__start" then
                            table.insert(allDetails, {
                                type = "divider",
                                section = section,
                            })
                            table.insert(currentTree, autoDetails.searchLabels[index])
                            local sectionSource = source .. "$" .. table.concat(currentTree, "$")
                            table.insert(currentSection, sectionSource)
                            table.insert(allDetails, {
                                type = "section",
                                color = category.source,
                                source = sectionSource,
                                label = autoDetails.searchLabels[index],
                                section = section,
                            })
                        end
                    else
                        if search == "" then
                            search = "________" .. (#allDetails + 1)
                        end
                        allDetails[#allDetails + 1] = {
                            type = "category",
                            source = source,
                            search = search,
                            label = autoDetails.searchLabels[index],
                            priority = (category.priorityOffset or 0) + priority,
                            index = #allDetails + 1,
                            attachedItems = autoDetails.attachedItems[index],
                            icon = autoDetails.icons[index],
                            group = group,
                            groupPrefix = groupPrefix,
                            color = category.source,
                            auto = true,
                            autoIndex = index,
                            section = section,
                        }
                    end
                end
            elseif category.emptySlots then
                allDetails[#allDetails + 1] = {
                    type = "category",
                    source = source,
                    index = #allDetails + 1,
                    section = section,
                    search = "________" .. (#allDetails + 1),
                    priority = 0,
                    auto = true,
                    emptySlots = true,
                    label = EMPTY or "Empty",
                }
            else
                allDetails[#allDetails + 1] = {
                    type = "category",
                    source = source,
                    search = category.search,
                    label = category.name,
                    priority = (category.priorityOffset or 0) + priority,
                    index = #allDetails + 1,
                    attachedItems = attachedItems,
                    group = group,
                    groupPrefix = groupPrefix,
                    section = section,
                }
            end
        end
        category = customCategories[source]
        if category and shouldShow then
            local search = (category.search or ""):lower()
            if search == "" then
                search = "________" .. (#allDetails + 1)
            end

            allDetails[#allDetails + 1] = {
                type = "category",
                source = source,
                search = search,
                label = category.name,
                priority = priority,
                index = #allDetails + 1,
                attachedItems = attachedItems,
                group = group,
                groupPrefix = groupPrefix,
                section = section,
            }
        end
    end

    local copy = tFilter(allDetails, function(a) return a.type == "category" end, true)
    table.sort(copy, function(a, b)
        if a.priority == b.priority then
            return a.index < b.index
        else
            return a.priority > b.priority
        end
    end)

    local seenSearches = {}
    local prioritisedSearches = {}
    for _, details in ipairs(copy) do
        if seenSearches[details.search] then
            details.search = "________" .. details.index
        end
        prioritisedSearches[#prioritisedSearches + 1] = details.search
        seenSearches[details.search] = true
    end

    local result = {
        details = allDetails,
        start = 1,
        searches = {},
        section = {},
        categoryKeys = {},
        prioritisedSearches = prioritisedSearches,
    }

    for index, details in ipairs(allDetails) do
        if details.search then
            details.results = {}
        end
        details.next = index + 1
        details.index = nil
        details.priority = nil
        if details.type == "category" then
            table.insert(result.searches, details.search)
            table.insert(result.section, details.section)
            result.categoryKeys[details.search] = details.source
        end
    end
    if next(allDetails) then
        allDetails[#allDetails].next = nil
    end

    return result
end

local function KT_Bags_ApplyCategorySearches(composed, everything)
    if not composed or not composed.details or not composed.prioritisedSearches then
        return
    end

    local detailsBySearch = {}
    for _, details in ipairs(composed.details) do
        if details.search then
            details.results = {}
            detailsBySearch[details.search] = details
        end
    end

    local attachedSearchByKey = {}
    for _, search in ipairs(composed.prioritisedSearches) do
        local details = detailsBySearch[search]
        if details and details.attachedItems then
            for key, hit in pairs(details.attachedItems) do
                if hit and not attachedSearchByKey[key] then
                    attachedSearchByKey[key] = search
                end
            end
        end
    end

    for _, item in ipairs(everything) do
        local attachmentKey = KT_Bags_GetAddedItemData(item.itemID, item.itemLink)
        local search = attachedSearchByKey[item.key] or attachedSearchByKey[attachmentKey]
        if search then
            table.insert(detailsBySearch[search].results, item)
        else
            for _, searchCandidate in ipairs(composed.prioritisedSearches) do
                local match = Syndicator.Search.CheckItem(item, searchCandidate)
                if match == nil and item.itemID then
                    C_Item.RequestLoadItemDataByID(item.itemID)
                end
                if match then
                    table.insert(detailsBySearch[searchCandidate].results, item)
                    break
                end
            end
        end
    end
end

--- Execute a callback with Blizzard's error handler protection.
-- @param func function Callback to execute safely.
-- @param ... any Callback arguments.
-- @return boolean, any xpcall success flag and first return value.
local function KT_SafeCallback(func, ...)
    return xpcall(func, CallErrorHandler, ...)
end

--- Return the public KullThranUI table used for externally callable methods.
-- @return table Public addon table.
local function KT_GetPublicAddon()
    _G.KullThranUI = _G.KullThranUI or _G.KT or KT
    return _G.KullThranUI
end

local function KT_BagsDebugPrint(...)
    if not Mod or not Mod._ktBagsDebug then
        return
    end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    local msg = "[ktbagsdebug] " .. table.concat(parts, " ")
    if KT and KT.Print then
        KT:Print(msg)
    elseif _G.DEFAULT_CHAT_FRAME then
        _G.DEFAULT_CHAT_FRAME:AddMessage(msg)
    else
        print(msg)
    end
end

_G.SLASH_KTBAGSDEBUG1 = "/ktbagsdebug"
SlashCmdList["KTBAGSDEBUG"] = function()
    Mod._ktBagsDebug = not Mod._ktBagsDebug
    local state = Mod._ktBagsDebug and "ON" or "OFF"
    if KT and KT.Print then
        KT:Print("[ktbagsdebug] " .. state)
    elseif _G.DEFAULT_CHAT_FRAME then
        _G.DEFAULT_CHAT_FRAME:AddMessage("[ktbagsdebug] " .. state)
    else
        print("[ktbagsdebug] " .. state)
    end
end

--- Check whether Baganator and its public API are currently available.
-- @return table|nil Baganator.API when available, otherwise nil.
local function KT_IsBaganatorActive()
    if C_AddOns.IsAddOnLoaded(KT_BAGANATOR_NAME) and _G.Baganator and _G.Baganator.API then
        return _G.Baganator.API
    end
    return nil
end

--- Parse the first numeric portion of an addon version string.
-- @param addonName string Addon name to inspect.
-- @return number|nil Parsed version number, or nil when unavailable.
local function KT_GetAddonVersionNumber(addonName)
    local versionString = C_AddOns.GetAddOnMetadata(addonName, "Version")
    if type(versionString) ~= "string" then
        return nil
    end

    return tonumber(versionString:match("(%d+)"))
end

--- Check whether the loaded Baganator version is within the supported range.
-- @return boolean True when compatible or version metadata is unavailable.
local function KT_IsBaganatorCompatible()
    local versionNumber = KT_GetAddonVersionNumber(KT_BAGANATOR_NAME)
    return versionNumber == nil or versionNumber >= KT_BAGANATOR_MIN_VERSION
end

function Mod:CanUseCopiedCategories()
    if not _G.Syndicator or not _G.Syndicator.Search or not _G.Syndicator.Locales then
        return false
    end

    return KT_Bags_GetBaganatorCategoryData() ~= nil
end

--- Normalize public API arguments so both dot and colon calls work.
-- @param first any First received argument.
-- @param second any Second received argument.
-- @return any Normalized payload argument.
local function KT_NormalizePublicSingleArg(first, second)
    if type(first) == "table" and second ~= nil then
        return second
    end

    return first
end

--- Return the item count shown on a live bag item.
-- @param itemInfo table|nil Container item info.
-- @return number Stack count.
local function KT_GetStackCount(itemInfo)
    if type(itemInfo) ~= "table" then
        return 0
    end

    return itemInfo.stackCount or itemInfo.quantity or 0
end

local KT_Bags_ScanTooltip
do
    local tooltip = CreateFrame("GameTooltip", "KT_BagsTooltipScanner", nil, "GameTooltipTemplate")
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    KT_Bags_ScanTooltip = function(setter)
        tooltip:ClearLines()
        setter(tooltip)
        local name = tooltip:GetName()
        local lines = {}
        local row = 1
        while _G[name .. "TextLeft" .. row] ~= nil do
            local leftFontString = _G[name .. "TextLeft" .. row]
            local rightFontString = _G[name .. "TextRight" .. row]
            local entry = {
                leftText = leftFontString:GetText(),
                leftColor = CreateColor(leftFontString:GetTextColor()),
            }
            if rightFontString and rightFontString:IsShown() then
                entry.rightText = rightFontString:GetText()
                entry.rightColor = CreateColor(rightFontString:GetTextColor())
            end
            if entry.leftText or entry.rightText then
                table.insert(lines, entry)
            end
            row = row + 1
        end
        return { lines = lines }
    end
end

local function KT_Bags_BuildTooltipGetter(bagID, slotID, itemLink)
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        return function()
            return C_TooltipInfo.GetBagItem(bagID, slotID)
        end
    end

    if itemLink and itemLink ~= "" and KT_Bags_ScanTooltip then
        return function()
            return KT_Bags_ScanTooltip(function(tip)
                tip:SetHyperlink(itemLink)
            end)
        end
    end

    return function()
        return { lines = {} }
    end
end

local function KT_Bags_FormatMoney(amount)
    if GetMoneyString then
        local result = GetMoneyString(amount, true)
        result = result:gsub("0:0:2:0", "15")
        result = result:gsub("|T", " |T")
        return result
    end

    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    if BreakUpLargeNumbers then
        gold = BreakUpLargeNumbers(gold)
    end
    return format("%sg %ds %dc", gold, silver, copper)
end

--- Apply a consistent icon-button skin to a module-owned button.
-- @param button Button Button to style.
-- @param iconPath string Texture path used for the icon art.
-- @return Texture Created icon texture.
local function KT_StyleIconButton(button, iconPath)
    KT:AddBackdrop(button, 0.05, 0.04, 0.07, 0.92)
    KT:AddBorder(button, KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.45)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetVertexColor(0.95, 0.95, 1.0, 0.95)
    button.KT_Icon = icon

    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local highlight = button:GetHighlightTexture()
    highlight:SetVertexColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.12)

    return icon
end

--- Hide Blizzard backpack windows and route bag toggles into the native KullThranUI frame.
-- This prevents duplicated inventory UIs when the native bags module is enabled.
-- @param module table Bags module instance.
-- @return nil
local function KT_InstallNativeBagOverride(module)
    if _G.KT_BagsOverrideInstalled then
        return
    end

    local suppressBagAPIHooks = false

    local function WithSuppressedBagAPIHooks(callback)
        local previous = suppressBagAPIHooks
        suppressBagAPIHooks = true
        local ok, result = pcall(callback)
        suppressBagAPIHooks = previous
        if not ok then
            error(result)
        end
        return result
    end

    local function hideDefaultBags()
        WithSuppressedBagAPIHooks(function()
            if _G.ContainerFrameCombinedBags then
                _G.ContainerFrameCombinedBags:Hide()
                if not _G.ContainerFrameCombinedBags.KT_HideHooked then
                    _G.ContainerFrameCombinedBags:HookScript("OnShow", function(frame)
                        WithSuppressedBagAPIHooks(function()
                            frame:Hide()
                        end)
                    end)
                    _G.ContainerFrameCombinedBags.KT_HideHooked = true
                end
            end

            local index = 1
            while _G["ContainerFrame" .. index] do
                local frame = _G["ContainerFrame" .. index]
                frame:Hide()
                if not frame.KT_HideHooked then
                    frame:HookScript("OnShow", function(widget)
                        WithSuppressedBagAPIHooks(function()
                            widget:Hide()
                        end)
                    end)
                    frame.KT_HideHooked = true
                end
                index = index + 1
            end
        end)
    end

    local function showNativeWindow()
        hideDefaultBags()
        if module and module.CreateNativeWindow then
            local window = module:CreateNativeWindow()
            if window then
                window:Show()
                if module.db and module.db.window then
                    module.db.window.visible = true
                end
                if module.RefreshBagSlots then
                    module:RefreshBagSlots()
                end
            end
        end
    end

    local function toggleNativeWindow()
        hideDefaultBags()
        if module and module.ToggleWindow then
            module:ToggleWindow()
        else
            showNativeWindow()
        end
    end

    local function closeNativeWindow()
        hideDefaultBags()
        if _G.KT_BagsWindow then
            _G.KT_BagsWindow:Hide()
            if module and module.db and module.db.window then
                module.db.window.visible = false
            end
        end
    end

    local pendingAction = nil
    local flushScheduled = false
    local toggleQueued = false

    local function flushPendingAction()
        flushScheduled = false

        local action = pendingAction
        pendingAction = nil
        toggleQueued = false

        if action == "show" then
            showNativeWindow()
        elseif action == "hide" then
            closeNativeWindow()
        elseif action == "toggle" then
            toggleNativeWindow()
        end
    end

    local function queueAction(action)
        if action ~= "show" and action ~= "hide" and action ~= "toggle" then
            return
        end

        -- Blizzard bag APIs can call each other internally (for example
        -- ToggleAllBags -> OpenAllBags/CloseAllBags). For the native KUI window
        -- we must preserve the user's toggle intent, otherwise hidden Blizzard
        -- bags make every toggle look like a one-way "open".
        if action == "toggle" then
            pendingAction = "toggle"
            toggleQueued = true
        elseif toggleQueued then
            pendingAction = "toggle"
        elseif pendingAction == "show" or pendingAction == "hide" then
            if action == "show" or action == "hide" then
                pendingAction = action
            end
        elseif pendingAction == "toggle" then
            pendingAction = "toggle"
        else
            pendingAction = action
        end

        if flushScheduled then
            return
        end

        flushScheduled = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0, flushPendingAction)
        else
            flushPendingAction()
        end
    end

    _G.KT_HideDefaultBags = hideDefaultBags

    if hooksecurefunc then
        hooksecurefunc("ToggleAllBags", function()
            if suppressBagAPIHooks then return end
            queueAction("toggle")
        end)
        hooksecurefunc("OpenAllBags", function()
            if suppressBagAPIHooks then return end
            queueAction("show")
        end)
        hooksecurefunc("CloseAllBags", function()
            if suppressBagAPIHooks then return end
            queueAction("hide")
        end)
        if _G.ToggleBackpack and _G.ToggleBackpack ~= _G.ToggleAllBags then
            hooksecurefunc("ToggleBackpack", function()
                if suppressBagAPIHooks then return end
                queueAction("toggle")
            end)
        end
        if _G.OpenBackpack and _G.OpenBackpack ~= _G.OpenAllBags then
            hooksecurefunc("OpenBackpack", function()
                if suppressBagAPIHooks then return end
                queueAction("show")
            end)
        end
        if _G.CloseBackpack and _G.CloseBackpack ~= _G.CloseAllBags then
            hooksecurefunc("CloseBackpack", function()
                if suppressBagAPIHooks then return end
                queueAction("hide")
            end)
        end
    end

    _G.KT_BagsOverrideInstalled = true
end


--- Ensure the module database exists with safe defaults.
-- @return nil
function Mod:EnsureDB()
    KT.db.profile.bags = KT.db.profile.bags or {
        enable = true,
        watchedItems = {},
        viewMode = "category",
        lockPosition = false,
        showItemLevel = true,
        itemSize = KT_ITEM_SIZE,
        itemLevelColorByRarity = true,
        showEquippedBags = false,
        bagIconStyle = "modern",
        bagIconSize = KT_EQUIPPED_BAG_ICON_SIZE,
        panelColor = { r = KT_BAGS_DEFAULT_PANEL_COLOR.r, g = KT_BAGS_DEFAULT_PANEL_COLOR.g, b = KT_BAGS_DEFAULT_PANEL_COLOR.b, a = KT_BAGS_DEFAULT_PANEL_COLOR.a },
        currency = {
            show = true,
            showGold = true,
            mode = "backpack",
            max = 3,
            spacing = KT_FOOTER_CURRENCY_SPACING,
            customList = "",
            clickOpensTokenFrame = true,
            rightClickUntracks = true,
            enableTracking = true,
            showTrackingGains = true,
        },
        currencyTracking = {},
        window = {
            visible = true,
            width = KT_BAGS_WINDOW_WIDTH,
            height = KT_BAGS_WINDOW_HEIGHT,
            migratedLayoutV5 = true,
            migratedLayoutV6 = true,
            migratedLayoutV7 = true,
            migratedLayoutV8 = true,
        },
    }

    KT.db.profile.bags.window = KT.db.profile.bags.window or {}
    if KT.db.profile.bags.window.visible == nil then
        KT.db.profile.bags.window.visible = true
    end
    KT.db.profile.bags.viewMode = KT.db.profile.bags.viewMode or "category"
    if KT.db.profile.bags.lockPosition == nil then KT.db.profile.bags.lockPosition = false end
    if KT.db.profile.bags.showItemLevel == nil then KT.db.profile.bags.showItemLevel = true end
    KT.db.profile.bags.itemSize = KT.db.profile.bags.itemSize or KT_ITEM_SIZE
    if KT.db.profile.bags.itemLevelColorByRarity == nil then KT.db.profile.bags.itemLevelColorByRarity = true end
    if KT.db.profile.bags.showEquippedBags == nil then KT.db.profile.bags.showEquippedBags = false end
    KT.db.profile.bags.bagIconStyle = KT.db.profile.bags.bagIconStyle or "modern"
    KT.db.profile.bags.bagIconSize = KT.db.profile.bags.bagIconSize or KT_EQUIPPED_BAG_ICON_SIZE
    KT.db.profile.bags.currency = KT.db.profile.bags.currency or {}
    if KT.db.profile.bags.currency.show == nil then KT.db.profile.bags.currency.show = true end
    if KT.db.profile.bags.currency.showGold == nil then KT.db.profile.bags.currency.showGold = true end
    KT.db.profile.bags.currency.mode = KT.db.profile.bags.currency.mode or "backpack"
    KT.db.profile.bags.currency.max = KT.db.profile.bags.currency.max or 3
    KT.db.profile.bags.currency.spacing = KT.db.profile.bags.currency.spacing or KT_FOOTER_CURRENCY_SPACING
    KT.db.profile.bags.currency.customList = KT.db.profile.bags.currency.customList or ""
    if KT.db.profile.bags.currency.clickOpensTokenFrame == nil then KT.db.profile.bags.currency.clickOpensTokenFrame = true end
    if KT.db.profile.bags.currency.rightClickUntracks == nil then KT.db.profile.bags.currency.rightClickUntracks = true end
    if KT.db.profile.bags.currency.enableTracking == nil then KT.db.profile.bags.currency.enableTracking = true end
    if KT.db.profile.bags.currency.showTrackingGains == nil then KT.db.profile.bags.currency.showTrackingGains = true end
    KT.db.profile.bags.currencyTracking = KT.db.profile.bags.currencyTracking or {}
    KT.db.profile.bags.panelColor = KT.db.profile.bags.panelColor or { r = KT_BAGS_DEFAULT_PANEL_COLOR.r, g = KT_BAGS_DEFAULT_PANEL_COLOR.g, b = KT_BAGS_DEFAULT_PANEL_COLOR.b, a = KT_BAGS_DEFAULT_PANEL_COLOR.a }
    if KT.db.profile.bags.window.migratedLayoutV6 ~= true then
        local width = tonumber(KT.db.profile.bags.window.width) or 760
        local height = tonumber(KT.db.profile.bags.window.height) or 560
        KT.db.profile.bags.window.width = math.max(480, math.floor((width * 0.75) + 0.5))
        KT.db.profile.bags.window.height = math.max(320, math.floor((height * 0.75) + 0.5))
        KT.db.profile.bags.window.migratedLayoutV6 = true
    end
    if KT.db.profile.bags.window.migratedLayoutV7 ~= true then
        local height = tonumber(KT.db.profile.bags.window.height) or 420
        KT.db.profile.bags.window.height = math.max(320, math.floor((height * 0.85) + 0.5))
        KT.db.profile.bags.window.migratedLayoutV7 = true
    end
    if KT.db.profile.bags.window.migratedLayoutV8 ~= true then
        local width = tonumber(KT.db.profile.bags.window.width) or KT_BAGS_WINDOW_WIDTH
        local height = tonumber(KT.db.profile.bags.window.height) or KT_BAGS_WINDOW_HEIGHT
        if width <= 620 then
            KT.db.profile.bags.window.width = KT_BAGS_WINDOW_WIDTH
        end
        if height <= 430 then
            KT.db.profile.bags.window.height = KT_BAGS_WINDOW_HEIGHT
        end
        if (tonumber(KT.db.profile.bags.itemSize) or KT_ITEM_SIZE) <= 36 then
            KT.db.profile.bags.itemSize = KT_ITEM_SIZE
        end
        KT.db.profile.bags.window.migratedLayoutV8 = true
    end
    do
        -- Migrate the old default (#0D1217-ish) to the new desired default (#331900).
        local c = KT.db.profile.bags.panelColor
        if type(c) ~= "table" then
            KT.db.profile.bags.panelColor = { r = KT_BAGS_DEFAULT_PANEL_COLOR.r, g = KT_BAGS_DEFAULT_PANEL_COLOR.g, b = KT_BAGS_DEFAULT_PANEL_COLOR.b, a = KT_BAGS_DEFAULT_PANEL_COLOR.a }
        else
            local function Nearly(a, b)
                if type(a) ~= "number" or type(b) ~= "number" then return false end
                return math.abs(a - b) < 0.0001
            end
            if Nearly(c.r, 0.05) and Nearly(c.g, 0.07) and Nearly(c.b, 0.09) and Nearly(c.a or 0.94, 0.94) then
                KT.db.profile.bags.panelColor = { r = KT_BAGS_DEFAULT_PANEL_COLOR.r, g = KT_BAGS_DEFAULT_PANEL_COLOR.g, b = KT_BAGS_DEFAULT_PANEL_COLOR.b, a = KT_BAGS_DEFAULT_PANEL_COLOR.a }
            else
                c.a = c.a or KT_BAGS_DEFAULT_PANEL_COLOR.a
            end
        end
    end
    if not KT.db.profile.bags.window.migratedLayoutV5 then
        KT.db.profile.bags.window.width = KT_BAGS_WINDOW_WIDTH
        KT.db.profile.bags.window.height = KT_BAGS_WINDOW_HEIGHT
        KT.db.profile.bags.window.migratedLayoutV5 = true
    end
    KT.db.profile.bags.window.width = KT.db.profile.bags.window.width or KT_BAGS_WINDOW_WIDTH
    KT.db.profile.bags.window.height = KT.db.profile.bags.window.height or KT_BAGS_WINDOW_HEIGHT
    KT.db.profile.bags.watchedItems = KT.db.profile.bags.watchedItems or {}

    self.db = KT.db.profile.bags
end

--- Initialise module state and publish the public bags API.
-- @return nil
function Mod:OnInitialize()
    self:EnsureDB()

    self.bridgeRegistered = false
    self.editModeRegistered = false
    self.unlockRegistered = false
    self.itemButtons = {}
    self.lastInventoryInfo = nil
    self.lastInventoryQuery = nil
    self.selectedItemLink = nil
    self.selectedItemName = nil
    self.selectedCategorySource = nil
    self.selectedSpecialView = nil
    self.selectedBagID = nil
    self.searchText = ""
    self:RefreshWatchedItemsReference()

    local publicAddon = KT_GetPublicAddon()
    publicAddon.GetItemInventory = function(first, second)
        local itemLink = KT_NormalizePublicSingleArg(first, second)
        return self:GetItemInventory(itemLink)
    end
    publicAddon.WatchItem = function(first, second)
        local itemLink = KT_NormalizePublicSingleArg(first, second)
        return self:AddWatchedItem(itemLink)
    end
    publicAddon.UnwatchItem = function(first, second)
        local itemLink = KT_NormalizePublicSingleArg(first, second)
        return self:RemoveWatchedItem(itemLink)
    end

    _G.KT_ToggleBagsWindow = function()
        local module = KT:GetModule("Bags", true)
        if module then
            module:ToggleWindow()
        end
    end
end

--- Enable the module, create the native backpack window and register integrations.
-- @return nil
function Mod:OnEnable()
    self:EnsureDB()
    if self.db.enable == false then
        return
    end

    if KT.db and KT.db.RegisterCallback then
        KT.db.RegisterCallback(self, "OnProfileChanged", "OnProfileUpdate")
        KT.db.RegisterCallback(self, "OnProfileCopied", "OnProfileUpdate")
        KT.db.RegisterCallback(self, "OnProfileReset", "OnProfileUpdate")
    end

    self:CreateNativeWindow()
    self:EnsureThemeHook()
    KT_InstallNativeBagOverride(self)
    if _G.KT_HideDefaultBags then
        _G.KT_HideDefaultBags()
    end
    -- The bags window should not appear as a movable element inside Blizzard/KT Edit Mode.
    -- It remains movable via KT UnlockMode instead.
    self:RegisterWithUnlockMode()
    self:RegisterBagEvents()
    self:RefreshBagSlots()

    KT:RegisterChatCommand("ktbags", function()
        self:ToggleWindow()
    end)

    if C_AddOns.IsAddOnLoaded(KT_BAGANATOR_NAME) then
        self:RegisterBaganatorBridge()
    else
        self:RegisterEvent("ADDON_LOADED")
    end
end

function Mod:IsPositionLocked()
    return self.db and self.db.lockPosition == true
end

function Mod:ApplyWindowLockState(window)
    window = window or _G.KT_BagsWindow
    if not window or not window.KT_Header then
        return
    end

    local locked = self:IsPositionLocked()
    if locked and window.StopMovingOrSizing then
        window:StopMovingOrSizing()
    end
    if window.KT_Tip then
        window.KT_Tip:SetText(locked and LText("Locked", "Locked") or "")
    end
end

--- Refresh module database pointers after a profile operation.
-- @return nil
function Mod:OnProfileUpdate()
    self:EnsureDB()
    self:RefreshWatchedItemsReference()
    KT_InstallNativeBagOverride(self)
    if _G.KT_HideDefaultBags then
        _G.KT_HideDefaultBags()
    end

    if _G.KT_BagsWindow then
        _G.KT_BagsWindow:SetSize(self.db.window.width, self.db.window.height)
        self:ApplyWindowLockState(_G.KT_BagsWindow)
        if self.db.window.visible then
            _G.KT_BagsWindow:Show()
        else
            _G.KT_BagsWindow:Hide()
        end
    end

    self:ApplyPanelColor()
    self:RefreshBagSlots()
end

function Mod:RefreshTheme()
    if not _G.KT_BagsWindow then
        return
    end

    self:ApplyPanelColor()
    self:RefreshBagSlots()
end

function Mod:EnsureThemeHook()
    if self.themeHooked or not (KT and KT.RefreshStylePalette and hooksecurefunc) then
        return
    end

    hooksecurefunc(KT, "RefreshStylePalette", function()
        if Mod and Mod.RefreshTheme then
            Mod:RefreshTheme()
        end
    end)
    self.themeHooked = true
end

--- Handle addon loading and defer bridge registration until Baganator is ready.
-- @param event string Fired event name.
-- @param addonName string Loaded addon name.
-- @return nil
function Mod:ADDON_LOADED(event, addonName)
    if addonName ~= KT_BAGANATOR_NAME then
        return
    end

    self:RegisterBaganatorBridge()
    self:UnregisterEvent("ADDON_LOADED")
end

local KT_Bags_UpdateItemCooldown

--- Register the live bag events the native inventory listens to.
-- @return nil
function Mod:RegisterBagEvents()
    self:RegisterEvent("BAG_UPDATE_DELAYED", "HandleBagContentsChanged")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", "RefreshItemCooldowns")
    self:RegisterEvent("ITEM_LOCK_CHANGED", "HandleBagLockChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleBagContentsChanged")
    self:RegisterEvent("PLAYER_MONEY", "RefreshGoldDisplay")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "RefreshCurrencyDisplay")
end

function Mod:HandleBagContentsChanged()
    local window = _G.KT_BagsWindow
    if not (window and window:IsShown()) then
        self.bagRefreshPending = true
        return
    end

    self.bagRefreshPending = nil
    local profiler = _G.KT and _G.KT.CombatProfiler
    local startedAt = profiler and profiler:Begin("bags.refresh.full")
    self:RefreshBagSlots()
    if startedAt then profiler:End("bags.refresh.full", startedAt) end
end

function Mod:RefreshItemCooldowns()
    local window = _G.KT_BagsWindow
    if not (window and window:IsShown() and KT_Bags_UpdateItemCooldown) then
        return
    end

    local profiler = _G.KT and _G.KT.CombatProfiler
    local startedAt = profiler and profiler:Begin("bags.cooldowns.incremental")
    for _, button in ipairs(self.itemButtons or {}) do
        local holder = button and (button.KT_Holder or button)
        if button and button.KT_HasItem and holder and holder:IsShown() and button:IsShown() then
            KT_Bags_UpdateItemCooldown(button, button.KT_BagID, button.KT_SlotID)
        end
    end
    if startedAt then profiler:End("bags.cooldowns.incremental", startedAt) end
end

function Mod:HandleBagLockChanged()
    local window = _G.KT_BagsWindow
    if not (window and window:IsShown()) then
        self.bagRefreshPending = true
        return
    end
    if self.itemLockRefreshQueued then
        return
    end

    self.itemLockRefreshQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if Mod then
                Mod.itemLockRefreshQueued = false
                Mod:HandleBagContentsChanged()
            end
        end)
    else
        self.itemLockRefreshQueued = false
        self:HandleBagContentsChanged()
    end
end

--- Keep the global compatibility alias pointing at the module-owned watched table.
-- @return nil
function Mod:RefreshWatchedItemsReference()
    self.watchedItems = self.db.watchedItems
    _G.KT_WatchedItems = self.watchedItems
end

--- Create the module-owned information panel registered as a Baganator region.
-- @return Frame Backpack region frame.
function Mod:EnsureBagsPanel()
    local panel = _G.KT_BagsPanel
    if panel then
        return panel
    end

    panel = CreateFrame("Frame", "KT_BagsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(200, 28)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.06, 0.07, 0.10, 0.92)
    panel:SetBackdropBorderColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.35)

    local text = panel:CreateFontString(nil, "OVERLAY")
    text:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
    text:SetPoint("CENTER", panel, "CENTER", 0, 0)
    text:SetText(KT_MODULE_NAME)
    text:SetTextColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 1)
    panel.KT_Text = text

    return panel
end

--- Create the native KullThranUI backpack window.
-- @return Frame Native bags window.
function Mod:CreateNativeWindow()
    local window = _G.KT_BagsWindow
    if window then
        return window
    end

    window = CreateFrame("Frame", "KT_BagsWindow", UIParent, "BackdropTemplate")
    window:SetSize(self.db.window.width, self.db.window.height)
    window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 160)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    -- Keep the bags window above minimap/overlay widgets.
    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetFrameLevel(500)
    window:SetToplevel(true)
    window:SetAlpha(1)

    KT:AddBackdrop(window, 0.05, 0.07, 0.09, 0.94)
    KT_Bags_ApplyKuiSurface(window, 0.62)
    KT:AddBorder(window, 0.10, 0.10, 0.10, 1)
    KT_Bags_ApplyAccentSurface(window, {
        topAlpha = 0.03,
        leftAlpha = 0.018,
        lineAlpha = 0.11,
        topCoverage = 0.22,
        leftCoverage = 0.18,
    })
    window:SetScript("OnShow", function()
        window:Raise()
    end)
    local header = CreateFrame("Frame", nil, window, "BackdropTemplate")
    header:SetPoint("TOPLEFT", window, "TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -6)
    header:SetHeight(34)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header:SetBackdropColor(0.08, 0.08, 0.09, 0.95)
    header:SetBackdropBorderColor(0.16, 0.16, 0.16, 1)
    KT_Bags_ApplyKuiSurface(header, 0.62)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if self:IsPositionLocked() then
            return
        end
        -- In some edge cases (taint/protected states, or other addons toggling flags),
        -- the frame may no longer be movable and StartMoving would throw.
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        local movable = nil
        if window and window.IsMovable then
            local ok, res = pcall(window.IsMovable, window)
            if ok then
                movable = res
            end
        end
        if movable == false and window and window.SetMovable then
            pcall(window.SetMovable, window, true)
            local ok, res = pcall(window.IsMovable, window)
            if ok then movable = res end
        end
        if movable ~= false and window and window.StartMoving then
            pcall(window.StartMoving, window)
        end
    end)
    header:SetScript("OnDragStop", function()
        if window and window.StopMovingOrSizing then
            pcall(window.StopMovingOrSizing, window)
        end
    end)
    KT_Bags_ApplyAccentSurface(header, {
        topAlpha = 0.065,
        leftAlpha = 0.028,
        lineAlpha = 0.18,
        accentBorderAlpha = 0.18,
        topCoverage = 0.42,
        leftCoverage = 0.24,
    })
    window.KT_Header = header

    local headerIcon = header:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(18, 18)
    headerIcon:SetPoint("LEFT", header, "LEFT", 6, 0)
    headerIcon:SetTexture(KT_BAGS_ICON_TEXTURE)
    headerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    do
        local ar, ag, ab = KT_Bags_GetAccentTextColor(1, 0.22)
        headerIcon:SetVertexColor(ar, ag, ab, 1)
    end
    window.KT_HeaderIcon = headerIcon

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT_DEFAULT_FONT, 15, "OUTLINE")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetText(LText("BAGS_TITLE", "Bags"))
    do
        local ar, ag, ab = KT_Bags_GetAccentTextColor(1, 0.3)
        title:SetTextColor(ar, ag, ab, 1)
    end
    window.KT_Title = title

    local closeHint = header:CreateFontString(nil, "OVERLAY")
    closeHint:SetFont(KT_DEFAULT_FONT, 11, "OUTLINE")
    closeHint:SetPoint("RIGHT", header, "RIGHT", -180, 0)
    closeHint:SetText("")
    closeHint:SetTextColor(0.85, 0.85, 0.90, 0.85)
    window.KT_Tip = closeHint

    local closeButton = CreateFrame("Button", nil, header, "BackdropTemplate")
    closeButton:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    closeButton:SetSize(28, 24)
    closeButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    closeButton:SetBackdropColor(0.10, 0.05, 0.05, 0.94)
    closeButton:SetBackdropBorderColor(0.32, 0.14, 0.14, 1)
    closeButton.Text = closeButton:CreateFontString(nil, "OVERLAY")
    closeButton.Text:SetFont(KT_DEFAULT_FONT, 13, "OUTLINE")
    closeButton.Text:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    closeButton.Text:SetText("X")
    closeButton.Text:SetTextColor(1, 0.82, 0.82, 1)
    closeButton:SetScript("OnClick", function()
        window:Hide()
        self.db.window.visible = false
    end)
    closeButton:SetScript("OnEnter", function(widget)
        widget:SetBackdropBorderColor(0.90, 0.28, 0.28, 1)
    end)
    closeButton:SetScript("OnLeave", function(widget)
        widget:SetBackdropBorderColor(0.32, 0.14, 0.14, 1)
    end)
    window.KT_CloseButton = closeButton
    self:ApplyWindowLockState(window)

    local modeButton = CreateFrame("Button", nil, header, "BackdropTemplate")
    modeButton:SetPoint("RIGHT", closeButton, "LEFT", -6, 0)
    modeButton:SetSize(64, 24)
    modeButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    modeButton:SetBackdropColor(0.09, 0.09, 0.11, 0.92)
    modeButton:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
    modeButton.Text = modeButton:CreateFontString(nil, "OVERLAY")
    modeButton.Text:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
    modeButton.Text:SetPoint("CENTER", modeButton, "CENTER", 0, 0)
    modeButton:SetScript("OnClick", function()
        self.db.viewMode = self.db.viewMode == "category" and "compact" or "category"
        self:RefreshBagSlots()
    end)
    window.KT_ModeButton = modeButton

    local optionsButton = CreateFrame("Button", nil, header, "BackdropTemplate")
    optionsButton:SetPoint("RIGHT", modeButton, "LEFT", -6, 0)
    optionsButton:SetSize(74, 24)
    optionsButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    optionsButton:SetBackdropColor(0.09, 0.09, 0.11, 0.92)
    optionsButton:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
    optionsButton.Text = optionsButton:CreateFontString(nil, "OVERLAY")
    optionsButton.Text:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
    optionsButton.Text:SetPoint("CENTER", optionsButton, "CENTER", 0, 0)
    optionsButton.Text:SetText(LText("Options", "Options"))
    do
        local tr, tg, tb = KT_Bags_GetAccentTextColor(1, 0.2)
        optionsButton.Text:SetTextColor(tr, tg, tb, 1)
    end
    optionsButton:SetScript("OnClick", function()
        self:OpenOptionsPage()
    end)
    window.KT_OptionsButton = optionsButton

    local toolbar = CreateFrame("Frame", nil, window, "BackdropTemplate")
    toolbar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    toolbar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -6)
    toolbar:SetHeight(58)
    toolbar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    toolbar:SetBackdropColor(0.05, 0.05, 0.06, 0.94)
    toolbar:SetBackdropBorderColor(0.14, 0.14, 0.14, 1)
    KT_Bags_ApplyKuiSurface(toolbar, 0.62)
    KT_Bags_ApplyAccentSurface(toolbar, {
        topAlpha = 0.038,
        leftAlpha = 0.02,
        lineAlpha = 0.12,
        topCoverage = 0.32,
        leftCoverage = 0.2,
    })
    window.KT_Toolbar = toolbar

    local searchBox = CreateFrame("EditBox", nil, toolbar, "BackdropTemplate")
    searchBox:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 8, -10)
    searchBox:SetPoint("BOTTOMRIGHT", toolbar, "BOTTOMRIGHT", -320, 12)
    searchBox:SetAutoFocus(false)
    searchBox:SetFont(KT_DEFAULT_FONT, 15, "OUTLINE")
    searchBox:SetTextInsets(40, 12, 0, 0)
    searchBox:SetTextColor(1, 1, 1, 1)
    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(0.01, 0.01, 0.02, 0.92)
    do
        local ar, ag, ab = KT_Bags_GetAccentColor()
        searchBox:SetBackdropBorderColor(ar, ag, ab, 0.72)
    end
    KT_Bags_ApplyAccentSurface(searchBox, {
        topAlpha = 0.032,
        leftAlpha = 0.018,
        lineAlpha = 0.22,
        accentBorderAlpha = 0.72,
        topCoverage = 0.46,
        leftCoverage = 0.2,
    })
    local searchIcon = searchBox:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(28, 28)
    searchIcon:SetPoint("LEFT", searchBox, "LEFT", 12, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    do
        local ar, ag, ab = KT_Bags_GetAccentTextColor(0.9, 0.18)
        searchIcon:SetVertexColor(ar, ag, ab, 0.9)
    end
    searchBox.KT_SearchIcon = searchIcon
    searchBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)
    searchBox:SetScript("OnTextChanged", function(editBox)
        self.searchText = lower(strtrim(editBox:GetText() or ""))
        self:RefreshBagSlots()
    end)
    window.KT_SearchBox = searchBox

    local refreshButton = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    refreshButton:SetPoint("RIGHT", toolbar, "RIGHT", -8, 0)
    refreshButton:SetSize(30, 30)
    refreshButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    refreshButton:SetBackdropColor(0.09, 0.09, 0.11, 0.92)
    do
        local ar, ag, ab = KT_Bags_GetAccentColor()
        refreshButton:SetBackdropBorderColor(ar, ag, ab, 0.58)
    end
    KT_Bags_ApplyAccentSurface(refreshButton, {
        topAlpha = 0.045,
        leftAlpha = 0.022,
        lineAlpha = 0.16,
        accentBorderAlpha = 0.58,
        topCoverage = 0.48,
        leftCoverage = 0.30,
    })
    -- Icon must live on a child frame so global skinning (StripTextures on the button)
    -- doesn't zero its alpha.
    local refreshIconFrame = CreateFrame("Frame", nil, refreshButton)
    refreshIconFrame:SetPoint("TOPLEFT", refreshButton, "TOPLEFT", 3, -3)
    refreshIconFrame:SetPoint("BOTTOMRIGHT", refreshButton, "BOTTOMRIGHT", -3, 3)
    refreshIconFrame:SetFrameLevel(refreshButton:GetFrameLevel() + 5)
    refreshButton.Icon = refreshIconFrame:CreateTexture(nil, "OVERLAY")
    refreshButton.Icon:SetAllPoints()
    if refreshButton.Icon.SetAtlas then
        refreshButton.Icon:SetAtlas("UI-RefreshButton", true)
    else
        refreshButton.Icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
        refreshButton.Icon:SetTexCoord(0, 1, 0, 1)
    end
    refreshButton.Icon:SetVertexColor(0.95, 0.95, 1.0, 0.95)
    refreshButton:SetScript("OnClick", function()
        self:RefreshBagSlots()
    end)
    refreshButton:SetScript("OnEnter", function(widget)
        GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
        GameTooltip:SetText(LText("BAGS_REFRESH", "Refresh"), 1, 1, 1)
        GameTooltip:Show()
    end)
    refreshButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    window.KT_RefreshButton = refreshButton

    local cleanupButton = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    cleanupButton:SetPoint("RIGHT", refreshButton, "LEFT", -6, 0)
    cleanupButton:SetSize(30, 30)
    cleanupButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    cleanupButton:SetBackdropColor(0.12, 0.08, 0.02, 0.96)
    cleanupButton:SetBackdropBorderColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.65)
    -- Same child-frame trick as refreshButton: prevents global skinning from
    -- hiding the icon texture.
    local cleanupIconFrame = CreateFrame("Frame", nil, cleanupButton)
    cleanupIconFrame:SetPoint("TOPLEFT", cleanupButton, "TOPLEFT", 3, -3)
    cleanupIconFrame:SetPoint("BOTTOMRIGHT", cleanupButton, "BOTTOMRIGHT", -3, 3)
    cleanupIconFrame:SetFrameLevel(cleanupButton:GetFrameLevel() + 5)
    cleanupButton.Icon = cleanupIconFrame:CreateTexture(nil, "OVERLAY")
    cleanupButton.Icon:SetAllPoints()
    if cleanupButton.Icon.SetAtlas then
        local ok = pcall(cleanupButton.Icon.SetAtlas, cleanupButton.Icon, "bags-button-autosort-up", true)
        if not ok then
            cleanupButton.Icon:SetTexture("Interface\\Icons\\INV_Misc_Broom_01")
            cleanupButton.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
    else
        cleanupButton.Icon:SetTexture("Interface\\Icons\\INV_Misc_Broom_01")
        cleanupButton.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    cleanupButton.Icon:SetVertexColor(0.95, 0.95, 1.0, 0.95)
    cleanupButton:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local cleanupHL = cleanupButton:GetHighlightTexture()
    if cleanupHL then
        cleanupHL:SetVertexColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.18)
    end
    cleanupButton:SetScript("OnClick", function()
        if C_Container and C_Container.CleanUpBags then
            C_Container.CleanUpBags()
        elseif C_Container and C_Container.SortBags then
            C_Container.SortBags()
        end
    end)
    cleanupButton:SetScript("OnEnter", function(widget)
        GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
        GameTooltip:SetText(LText("BAGS_REORGANIZE", "Reorganize Bags"), 1, 1, 1)
        GameTooltip:Show()
    end)
    cleanupButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    cleanupButton:Show()
    window.KT_CleanupButton = cleanupButton

    local sortButton = CreateFrame("Button", nil, toolbar, "BackdropTemplate")
    sortButton:SetPoint("RIGHT", cleanupButton, "LEFT", -6, 0)
    sortButton:SetSize(30, 30)
    sortButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sortButton:SetBackdropColor(0.09, 0.09, 0.11, 0.92)
    do
        local ar, ag, ab = KT_Bags_GetAccentColor()
        sortButton:SetBackdropBorderColor(ar, ag, ab, 0.58)
    end
    KT_Bags_ApplyAccentSurface(sortButton, {
        topAlpha = 0.045,
        leftAlpha = 0.022,
        lineAlpha = 0.16,
        accentBorderAlpha = 0.58,
        topCoverage = 0.48,
        leftCoverage = 0.30,
    })
    local sortIconFrame = CreateFrame("Frame", nil, sortButton)
    sortIconFrame:SetPoint("TOPLEFT", sortButton, "TOPLEFT", 3, -3)
    sortIconFrame:SetPoint("BOTTOMRIGHT", sortButton, "BOTTOMRIGHT", -3, 3)
    sortIconFrame:SetFrameLevel(sortButton:GetFrameLevel() + 5)
    sortButton.Icon = sortIconFrame:CreateTexture(nil, "OVERLAY")
    sortButton.Icon:SetAllPoints()
    sortButton.Icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    sortButton.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    sortButton.Icon:SetVertexColor(0.95, 0.95, 1.0, 0.95)
    sortButton:SetScript("OnClick", function()
        self.db.showEquippedBags = not self.db.showEquippedBags
        if not self.db.showEquippedBags then
            self.selectedBagID = nil
        end
        self:RefreshBagSlots()
    end)
    sortButton:SetScript("OnEnter", function(widget)
        GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
        local text = self.db.showEquippedBags and LText("BAGS_HIDE_EQUIPPED", "Hide Equipped Bags") or LText("BAGS_SHOW_EQUIPPED", "Show Equipped Bags")
        GameTooltip:SetText(text, 1, 1, 1)
        GameTooltip:Show()
    end)
    sortButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    window.KT_SortButton = sortButton

    local watchedBadge = CreateFrame("Frame", nil, toolbar, "BackdropTemplate")
    watchedBadge:SetPoint("RIGHT", sortButton, "LEFT", -8, 0)
    watchedBadge:SetSize(68, 30)
    watchedBadge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    watchedBadge:SetBackdropColor(0.09, 0.09, 0.11, 0.96)
    watchedBadge:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
    KT_Bags_ApplyAccentSurface(watchedBadge, {
        topAlpha = 0.05,
        leftAlpha = 0.024,
        lineAlpha = 0.15,
        accentBorderAlpha = 0.18,
        topCoverage = 0.54,
        leftCoverage = 0.26,
    })
    watchedBadge.Text = watchedBadge:CreateFontString(nil, "OVERLAY")
    watchedBadge.Text:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
    watchedBadge.Text:SetPoint("CENTER", watchedBadge, "CENTER", 0, 0)
    watchedBadge.Text:SetText(LText("BAGS_WATCH_LABEL", "Watch"))
    do
        local ar, ag, ab = KT_Bags_GetAccentTextColor(1, 0.26)
        watchedBadge.Text:SetTextColor(ar, ag, ab, 1)
    end
    window.KT_WatchedHeader = watchedBadge.Text
    window.KT_WatchedBadge = watchedBadge

    local bagIconFrame = CreateFrame("Frame", nil, toolbar)
    bagIconFrame:SetPoint("RIGHT", watchedBadge, "LEFT", -8, 0)
    bagIconFrame:SetSize(1, KT_EQUIPPED_BAG_ICON_SIZE)
    bagIconFrame:Hide()
    window.KT_BagIconFrame = bagIconFrame

    window.KT_BagIcons = {}
    window.KT_BagIconHolders = {}
    for index = 1, (NUM_BAG_SLOTS or 4) do
        local iconSize = (self.db and self.db.bagIconSize) or KT_EQUIPPED_BAG_ICON_SIZE
        local holder = CreateFrame("Button", nil, bagIconFrame, "BackdropTemplate")
        holder:SetSize(iconSize + 6, iconSize + 6)
        holder:RegisterForClicks("LeftButtonUp")
        holder:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        holder:SetBackdropColor(0.025, 0.025, 0.032, 0.96)
        do
            local ar, ag, ab = KT_Bags_GetAccentColor()
            holder:SetBackdropBorderColor(ar, ag, ab, 0.56)
        end
        KT_Bags_ApplyAccentSurface(holder, {
            topAlpha = 0.05,
            leftAlpha = 0.022,
            lineAlpha = 0.18,
            accentBorderAlpha = 0.56,
            topCoverage = 0.50,
            leftCoverage = 0.32,
        })
        if index == 1 then
            holder:SetPoint("LEFT", bagIconFrame, "LEFT", 0, 0)
        else
            holder:SetPoint("LEFT", window.KT_BagIconHolders[index - 1], "RIGHT", KT_EQUIPPED_BAG_ICON_SPACING, 0)
        end
        local icon = holder:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", holder, "TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -3, 3)
        icon:SetSize(iconSize, iconSize)
        icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        holder.KT_BagID = index
        holder:SetScript("OnClick", function(button)
            local bagID = button.KT_BagID
            self.selectedBagID = self.selectedBagID == bagID and nil or bagID
            self.selectedSpecialView = nil
            self.selectedCategorySource = nil
            self:RefreshBagSlots()
        end)
        holder:SetScript("OnEnter", function(button)
            local bagID = button.KT_BagID
            local invID = C_Container and C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bagID)
            GameTooltip:SetOwner(button, "ANCHOR_TOP")
            if not (invID and GameTooltip:SetInventoryItem("player", invID)) then
                GameTooltip:SetText(BAGSLOT or "Bag", 1, 1, 1)
            end
            local ar, ag, ab = KT_Bags_GetAccentColor()
            button:SetBackdropBorderColor(ar, ag, ab, 1)
            GameTooltip:Show()
        end)
        holder:SetScript("OnLeave", function(button)
            local ar, ag, ab = KT_Bags_GetAccentColor()
            button:SetBackdropBorderColor(ar, ag, ab, self.selectedBagID == button.KT_BagID and 1 or 0.56)
            GameTooltip:Hide()
        end)
        window.KT_BagIconHolders[index] = holder
        window.KT_BagIcons[index] = icon
    end
    window.KT_BagStyleButton = nil

    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 8, -6)
    searchBox:SetPoint("TOPRIGHT", watchedBadge, "LEFT", -8, -6)
    searchBox:SetHeight(46)

    local content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -8)
    content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -6, 56)
    content:SetClipsChildren(true)
    window.KT_Content = content

    local sidebar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(KT_BAGS_SIDEBAR_WIDTH)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sidebar:SetBackdropColor(0.018, 0.018, 0.022, 0.95)
    sidebar:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
    KT_Bags_ApplyKuiSurface(sidebar, 0.62)
    KT_Bags_ApplyAccentSurface(sidebar, {
        topAlpha = 0.026,
        leftAlpha = 0.018,
        lineAlpha = 0.12,
        topCoverage = 0.16,
        leftCoverage = 0.45,
    })
    window.KT_Sidebar = sidebar
    window.KT_SidebarRows = {}

    local sidebarTitle = sidebar:CreateFontString(nil, "OVERLAY")
    sidebarTitle:SetFont(KT_DEFAULT_FONT, 11, "OUTLINE")
    sidebarTitle:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, -8)
    sidebarTitle:SetText(LText("BAGS_CATEGORIES", "Categories"))
    do
        local ar, ag, ab = KT_Bags_GetAccentTextColor(0.85, 0.12)
        sidebarTitle:SetTextColor(ar, ag, ab, 0.85)
    end
    window.KT_SidebarTitle = sidebarTitle

    local sidebarScrollFrame = CreateFrame("ScrollFrame", nil, sidebar)
    sidebarScrollFrame:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -30)
    sidebarScrollFrame:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -14, 6)
    sidebarScrollFrame:EnableMouseWheel(true)
    window.KT_SidebarScrollFrame = sidebarScrollFrame

    local sidebarContent = CreateFrame("Frame", nil, sidebarScrollFrame)
    sidebarContent:SetPoint("TOPLEFT", sidebarScrollFrame, "TOPLEFT", 0, 0)
    sidebarContent:SetSize(KT_BAGS_SIDEBAR_WIDTH - 18, 1)
    sidebarScrollFrame:SetScrollChild(sidebarContent)
    window.KT_SidebarContent = sidebarContent

    local sidebarScrollBar = CreateFrame("Slider", nil, sidebar, "BackdropTemplate")
    sidebarScrollBar:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -4, -30)
    sidebarScrollBar:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -4, 6)
    sidebarScrollBar:SetMinMaxValues(0, 0)
    sidebarScrollBar:SetValue(0)
    KT_Bags_StyleScrollBar(sidebarScrollBar)
    sidebarScrollBar:SetScript("OnValueChanged", function(_, value)
        sidebarScrollFrame:SetVerticalScroll(value or 0)
    end)
    sidebarScrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local minValue, maxValue = sidebarScrollBar:GetMinMaxValues()
        local nextValue = sidebarScrollBar:GetValue() - ((delta or 0) * KT_BAGS_SIDEBAR_ROW_HEIGHT)
        sidebarScrollBar:SetValue(math.max(minValue, math.min(maxValue, nextValue)))
    end)
    sidebarScrollFrame:HookScript("OnSizeChanged", function()
        KT_Bags_UpdateScrollBar(sidebarScrollFrame, sidebarScrollBar, sidebarContent)
    end)
    sidebarScrollBar:Hide()
    window.KT_SidebarScrollBar = sidebarScrollBar

    local gridPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    gridPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    gridPanel:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    gridPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    gridPanel:SetBackdropColor(0.012, 0.012, 0.016, 0.94)
    gridPanel:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
    KT_Bags_ApplyKuiSurface(gridPanel, 0.62)
    KT_Bags_ApplyAmbientGradient(gridPanel, {
        fillAlpha = 0.16,
        fillEndAlpha = 0.06,
        shadeTopAlpha = 0.10,
        shadeBottomAlpha = 0.02,
        artAlpha = 0.42,
    })
    KT_Bags_ApplyAccentSurface(gridPanel, {
        topAlpha = 0.03,
        leftAlpha = 0.014,
        lineAlpha = 0.11,
        topCoverage = 0.14,
        leftCoverage = 0.12,
    })
    window.KT_GridPanel = gridPanel

    local gridHeader = gridPanel:CreateFontString(nil, "OVERLAY")
    gridHeader:SetFont(KT_DEFAULT_FONT, 14, "OUTLINE")
    gridHeader:SetPoint("TOPLEFT", gridPanel, "TOPLEFT", 10, -8)
    gridHeader:SetText(LText("BAGS_BACKPACK", "Backpack"))
    do
        local ar, ag, ab = KT_Bags_GetAccentTextColor(1, 0.26)
        gridHeader:SetTextColor(ar, ag, ab, 1)
    end
    window.KT_GridHeader = gridHeader
    window.KT_GridHeaderIcon = nil

    -- Gold moved to footer; keep header clean

    local scrollFrame = CreateFrame("ScrollFrame", nil, gridPanel)
    scrollFrame:SetPoint("TOPLEFT", gridPanel, "TOPLEFT", 8, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", gridPanel, "BOTTOMRIGHT", -22, 8)
    scrollFrame:EnableMouseWheel(true)
    window.KT_GridScrollFrame = scrollFrame

    local grid = CreateFrame("Frame", nil, scrollFrame)
    grid:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    grid:SetSize(1, 1)
    scrollFrame:SetScrollChild(grid)
    window.KT_Grid = grid

    local gridScrollBar = CreateFrame("Slider", nil, gridPanel, "BackdropTemplate")
    gridScrollBar:SetPoint("TOPRIGHT", gridPanel, "TOPRIGHT", -8, -30)
    gridScrollBar:SetPoint("BOTTOMRIGHT", gridPanel, "BOTTOMRIGHT", -8, 8)
    gridScrollBar:SetMinMaxValues(0, 0)
    gridScrollBar:SetValue(0)
    KT_Bags_StyleScrollBar(gridScrollBar)
    gridScrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value or 0)
    end)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local minValue, maxValue = gridScrollBar:GetMinMaxValues()
        local nextValue = gridScrollBar:GetValue() - ((delta or 0) * 48)
        gridScrollBar:SetValue(math.max(minValue, math.min(maxValue, nextValue)))
    end)
    scrollFrame:HookScript("OnSizeChanged", function()
        KT_Bags_UpdateScrollBar(scrollFrame, gridScrollBar, grid)
    end)
    gridScrollBar:Hide()
    window.KT_GridScrollBar = gridScrollBar

    local footer = CreateFrame("Frame", nil, window, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 6, 6)
    footer:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -6, 6)
    footer:SetHeight(48)
    footer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    footer:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
    footer:SetBackdropBorderColor(0.14, 0.14, 0.14, 1)
    KT_Bags_ApplyKuiSurface(footer, 0.62)
    KT_Bags_ApplyAccentSurface(footer, {
        topAlpha = 0.032,
        leftAlpha = 0.016,
        lineAlpha = 0.11,
        topCoverage = 0.28,
        leftCoverage = 0.18,
    })
    window.KT_Footer = footer

    local selectedIconFrame = CreateFrame("Frame", nil, footer, "BackdropTemplate")
    selectedIconFrame:SetSize(30, 30)
    selectedIconFrame:SetPoint("LEFT", footer, "LEFT", 6, 0)
    selectedIconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    selectedIconFrame:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
    selectedIconFrame:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
    KT_Bags_ApplyAccentSurface(selectedIconFrame, {
        topAlpha = 0.024,
        leftAlpha = 0.014,
        lineAlpha = 0.1,
        accentBorderAlpha = 0.12,
        topCoverage = 0.38,
        leftCoverage = 0.3,
    })
    window.KT_SelectedIconFrame = selectedIconFrame

    local selectedIcon = selectedIconFrame:CreateTexture(nil, "ARTWORK")
    selectedIcon:SetPoint("TOPLEFT", selectedIconFrame, "TOPLEFT", 2, -2)
    selectedIcon:SetPoint("BOTTOMRIGHT", selectedIconFrame, "BOTTOMRIGHT", -2, 2)
    selectedIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    window.KT_SelectedIcon = selectedIcon

    local status = footer:CreateFontString(nil, "OVERLAY")
    status:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
    status:SetPoint("TOPLEFT", selectedIconFrame, "TOPRIGHT", 8, -5)
    status:SetWidth(170)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.95, 0.95, 0.98, 1)
    window.KT_Status = status

    local summary = footer:CreateFontString(nil, "OVERLAY")
    summary:SetFont(KT_DEFAULT_FONT, 11, "OUTLINE")
    summary:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    summary:SetWidth(170)
    summary:SetJustifyH("LEFT")
    summary:SetTextColor(0.84, 0.84, 0.88, 1)
    window.KT_Summary = summary

    local selected = footer:CreateFontString(nil, "OVERLAY")
    selected:SetFont(KT_DEFAULT_FONT, 11, "OUTLINE")
    selected:SetPoint("LEFT", footer, "LEFT", 220, 0)
    selected:SetWidth(170)
    selected:SetJustifyH("LEFT")
    selected:SetTextColor(0.92, 0.92, 0.95, 1)
    window.KT_Selected = selected

    local watchedList = footer:CreateFontString(nil, "OVERLAY")
    watchedList:SetFont(KT_DEFAULT_FONT, 11, "OUTLINE")
    watchedList:SetPoint("RIGHT", footer, "RIGHT", -8, 0)
    watchedList:SetWidth(1)
    watchedList:SetJustifyH("RIGHT")
    watchedList:SetTextColor(0.92, 0.92, 0.95, 1)
    window.KT_WatchedList = watchedList

    local footerGold = footer:CreateFontString(nil, "OVERLAY")
    footerGold:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
    footerGold:SetPoint("RIGHT", footer, "RIGHT", -10, 0)
    footerGold:SetJustifyH("RIGHT")
    footerGold:SetTextColor(1, 1, 1, 1)
    window.KT_FooterGold = footerGold
    window.KT_FooterBagIcon = nil
    window.KT_FooterBagLabel = nil

    window.KT_CurrencyButtons = window.KT_CurrencyButtons or {}

    if self.db.window.visible then
        window:Show()
    else
        window:Hide()
    end

    self:ApplyPanelColor()
    self:EnsureBackgroundDropSlot()

    return window
end

--- Toggle the visibility of the native bags window.
-- @return nil
function Mod:ToggleWindow()
    local window = self:CreateNativeWindow()
    if window:IsShown() then
        window:Hide()
        self.db.window.visible = false
    else
        window:Show()
        self.db.window.visible = true
        self:RefreshBagSlots()
    end
end

--- Add an item link to the module-owned watched items set.
-- @param itemLink string Item link to mark as watched.
-- @return boolean True when the watch list changed.
function Mod:AddWatchedItem(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return false
    end

    if self.watchedItems[itemLink] then
        return false
    end

    self.watchedItems[itemLink] = true
    self:RequestItemButtonsRefresh()
    self:RefreshBagSlots()
    return true
end

--- Remove an item link from the module-owned watched items set.
-- @param itemLink string Item link to unmark.
-- @return boolean True when the watch list changed.
function Mod:RemoveWatchedItem(itemLink)
    if not self.watchedItems[itemLink] then
        return false
    end

    self.watchedItems[itemLink] = nil
    self:RequestItemButtonsRefresh()
    self:RefreshBagSlots()
    return true
end

--- Check whether the provided item is currently watched by the module.
-- @param itemLink string|nil Item link to inspect.
-- @return boolean True when watched.
function Mod:IsWatchedItem(itemLink)
    return itemLink ~= nil and self.watchedItems[itemLink] == true
end

--- Request an item button refresh through the public Baganator API when active.
-- @return nil
function Mod:RequestItemButtonsRefresh()
    local api = KT_IsBaganatorActive()
    if api then
        api.RequestItemButtonsRefresh()
    end
end

--- Apply the configured panel color across the native bags window surfaces.
-- @return nil
function Mod:ApplyPanelColor()
    local window = _G.KT_BagsWindow
    if not window then
        return
    end

    local color = self.db.panelColor or KT_BAGS_DEFAULT_PANEL_COLOR
    local accentR, accentG, accentB = KT_Bags_GetAccentColor()
    if window.bgKT then
        window.bgKT:SetColorTexture(color.r, color.g, color.b, color.a)
    end
    if window.KT_Header then
        window.KT_Header:SetBackdropColor(color.r * 0.58, color.g * 0.58, color.b * 0.58, math.min(1, color.a))
        KT_Bags_ApplyAccentSurface(window.KT_Header, {
            topAlpha = 0.065,
            leftAlpha = 0.028,
            lineAlpha = 0.18,
            accentBorderAlpha = 0.18,
            topCoverage = 0.42,
            leftCoverage = 0.24,
        })
    end
    if window.KT_Toolbar then
        window.KT_Toolbar:SetBackdropColor(color.r * 0.42, color.g * 0.42, color.b * 0.42, math.min(1, color.a))
        KT_Bags_ApplyAccentSurface(window.KT_Toolbar, {
            topAlpha = 0.038,
            leftAlpha = 0.02,
            lineAlpha = 0.12,
            topCoverage = 0.32,
            leftCoverage = 0.2,
        })
    end
    if window.KT_GridPanel then
        window.KT_GridPanel:SetBackdropColor(0.012, 0.012, 0.016, 0.94)
        KT_Bags_ApplyAmbientGradient(window.KT_GridPanel, {
            fillAlpha = 0.16,
            fillEndAlpha = 0.06,
            shadeTopAlpha = 0.10,
            shadeBottomAlpha = 0.02,
            artAlpha = 0.42,
        })
        KT_Bags_ApplyAccentSurface(window.KT_GridPanel, {
            topAlpha = 0.03,
            leftAlpha = 0.014,
            lineAlpha = 0.11,
            topCoverage = 0.14,
            leftCoverage = 0.12,
        })
    end
    if window.KT_Footer then
        window.KT_Footer:SetBackdropColor(color.r * 0.48, color.g * 0.48, color.b * 0.48, math.min(1, color.a))
        KT_Bags_ApplyAccentSurface(window.KT_Footer, {
            topAlpha = 0.032,
            leftAlpha = 0.016,
            lineAlpha = 0.11,
            topCoverage = 0.28,
            leftCoverage = 0.18,
        })
    end
    if window.KT_SearchBox then
        KT_Bags_ApplyAccentSurface(window.KT_SearchBox, {
            topAlpha = 0.032,
            leftAlpha = 0.018,
            lineAlpha = 0.22,
            accentBorderAlpha = 0.72,
            topCoverage = 0.46,
            leftCoverage = 0.2,
        })
    end
    if window.KT_WatchedBadge then
        KT_Bags_ApplyAccentSurface(window.KT_WatchedBadge, {
            topAlpha = 0.05,
            leftAlpha = 0.024,
            lineAlpha = 0.15,
            accentBorderAlpha = 0.18,
            topCoverage = 0.54,
            leftCoverage = 0.26,
        })
    end
    if window.KT_SelectedIconFrame then
        KT_Bags_ApplyAccentSurface(window.KT_SelectedIconFrame, {
            topAlpha = 0.024,
            leftAlpha = 0.014,
            lineAlpha = 0.1,
            accentBorderAlpha = 0.12,
            topCoverage = 0.38,
            leftCoverage = 0.3,
        })
    end
    if window.KT_BagIconHolders then
        for _, holder in ipairs(window.KT_BagIconHolders) do
            local selected = self.selectedBagID == holder.KT_BagID
            KT_Bags_ApplyAccentSurface(holder, {
                topAlpha = 0.05,
                leftAlpha = 0.022,
                lineAlpha = selected and 0.32 or 0.18,
                accentBorderAlpha = selected and 1 or 0.56,
                topCoverage = 0.50,
                leftCoverage = 0.32,
            })
        end
    end
    KT_Bags_StyleScrollBar(window.KT_GridScrollBar)
    KT_Bags_StyleScrollBar(window.KT_SidebarScrollBar)
    if window.KT_HeaderIcon then
        local tr, tg, tb = KT_Bags_GetAccentTextColor(1, 0.22)
        window.KT_HeaderIcon:SetVertexColor(tr, tg, tb, 1)
    end
    if window.KT_SearchBox and window.KT_SearchBox.KT_SearchIcon then
        local tr, tg, tb = KT_Bags_GetAccentTextColor(0.9, 0.18)
        window.KT_SearchBox.KT_SearchIcon:SetVertexColor(tr, tg, tb, 0.9)
    end
    if window.KT_Title then
        local tr, tg, tb = KT_Bags_GetAccentTextColor(1, 0.3)
        window.KT_Title:SetTextColor(tr, tg, tb, 1)
    end
    if window.KT_OptionsButton and window.KT_OptionsButton.Text then
        local tr, tg, tb = KT_Bags_GetAccentTextColor(1, 0.2)
        window.KT_OptionsButton.Text:SetTextColor(tr, tg, tb, 1)
    end
    if window.KT_GridHeader then
        local tr, tg, tb = KT_Bags_GetAccentTextColor(1, 0.26)
        window.KT_GridHeader:SetTextColor(tr, tg, tb, 1)
    end
    if window.KT_WatchedHeader then
        local tr, tg, tb = KT_Bags_GetAccentTextColor(1, 0.26)
        window.KT_WatchedHeader:SetTextColor(tr, tg, tb, 1)
    end
end

function Mod:OpenOptionsPage()
    if KT and KT.OpenMenu then
        KT:OpenMenu("bags")
        return
    end
    if KT and KT.ToggleConfig then
        KT:ToggleConfig()
    end
end

function Mod:BuildBaganatorCategoryLayout(visibleSlots)
    if not self:CanUseCopiedCategories() then
        return nil
    end

    local categoryData = KT_Bags_GetBaganatorCategoryData()
    if not categoryData then
        return nil
    end

    local equipmentSetMap = KT_Bags_GetEquipmentSetMap()

    for _, slotData in ipairs(visibleSlots) do
        if not slotData.key then
            local classID = slotData.classID
            local subclassID = slotData.subclassID
            if classID == (Enum and Enum.ItemClass and Enum.ItemClass.Reagent) and subclassID == (Enum and Enum.ItemReagentSubclass and Enum.ItemReagentSubclass.Keystone) then
                slotData.key = "keystone:" .. tostring(slotData.itemID or 0)
            else
                slotData.key = "item:" .. tostring(slotData.itemID or 0)
            end
        end
        slotData.keyNoGUID = slotData.keyNoGUID or slotData.key
        slotData.keyLink = slotData.keyLink or slotData.key
        slotData.invType = slotData.equipLoc
        slotData.itemCount = slotData.itemCount or (slotData.itemInfo and (slotData.itemInfo.stackCount or slotData.itemInfo.quantity) or 1)
        slotData.isNewItem = slotData.isNewItem or (slotData.itemInfo and slotData.itemInfo.isNewItem) or false
        slotData.quality = slotData.quality or (slotData.itemInfo and slotData.itemInfo.quality) or 0
        slotData.isBound = slotData.isBound or (slotData.itemInfo and slotData.itemInfo.isBound) or false
        slotData.hasLoot = slotData.hasLoot or (slotData.itemInfo and slotData.itemInfo.hasLoot) or false

        if equipmentSetMap and slotData.itemID then
            local sets = equipmentSetMap[slotData.itemID]
            if sets then
                slotData.setInfo = {}
                for setName in pairs(sets) do
                    table.insert(slotData.setInfo, { name = setName })
                end
            end
        end
    end

    local composed = KT_Bags_ComposeCategories(visibleSlots, "backpack", categoryData, equipmentSetMap)

    return composed
end

--- Classify a live bag slot into a native category group.
-- @param slotData table Collected slot data from the backpack.
-- @return string Category name.
function Mod:GetSlotCategory(slotData)
    if not slotData or (not slotData.itemLink and not slotData.itemID) then
        return "Miscellaneous"
    end

    local itemType, itemSubType, equipLoc, classID, subclassID
    local queryValue = slotData.itemLink or slotData.itemID

    local _, _, _, _, _, resolvedItemType, resolvedItemSubType, _, resolvedEquipLoc, _, _, resolvedClassID, resolvedSubclassID =
        GetItemInfo(queryValue)
    itemType = resolvedItemType
    itemSubType = resolvedItemSubType
    equipLoc = resolvedEquipLoc
    classID = resolvedClassID
    subclassID = resolvedSubclassID

    if (classID == nil or equipLoc == nil) and slotData.itemID then
        local _, instantItemType, instantItemSubType, instantEquipLoc, _, instantClassID, instantSubclassID = GetItemInfoInstant(slotData.itemID)
        itemType = itemType or instantItemType
        itemSubType = itemSubType or instantItemSubType
        equipLoc = equipLoc or instantEquipLoc
        classID = classID or instantClassID
        subclassID = subclassID or instantSubclassID
    end

    if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP" then
        return "Equipment"
    end

    if classID == LE_ITEM_CLASS_QUESTITEM or itemType == ITEM_CLASS_QUESTITEM then
        return "Quest"
    elseif classID == LE_ITEM_CLASS_CONSUMABLE or itemType == ITEM_CLASS_CONSUMABLE then
        return "Consumables"
    elseif classID == LE_ITEM_CLASS_WEAPON or classID == LE_ITEM_CLASS_ARMOR then
        return "Equipment"
    elseif CRAFTING_CLASS_IDS[classID] or classID == LE_ITEM_CLASS_GEM then
        return "Crafting"
    elseif itemType == ITEM_CLASS_TRADE_GOODS or itemType == ITEM_CLASS_RECIPES then
        return "Crafting"
    elseif classID == LE_ITEM_CLASS_MISCELLANEOUS and subclassID == 0 then
        return "Miscellaneous"
    elseif itemSubType == AUCTION_CATEGORY_REAGENT then
        return "Crafting"
    end

    return "Miscellaneous"
end

--- Check whether a live bag slot matches the active native search filter.
-- @param slotData table Collected slot data from the backpack.
-- @return boolean True when the slot should remain visible.
function Mod:SlotMatchesSearch(slotData)
    if self.searchText == nil or self.searchText == "" then
        return true
    end

    if not slotData or not slotData.itemLink then
        return false
    end

    local itemName = lower(slotData.itemName or "")
    local itemLink = lower(slotData.itemLink or "")
    return itemName:find(self.searchText, 1, true) ~= nil
        or itemLink:find(self.searchText, 1, true) ~= nil
end

function Mod:ShouldShowCompactEmptySlots()
    return self.db
        and self.db.viewMode == "compact"
        and (self.searchText == nil or self.searchText == "")
end

function Mod:ShouldDisplaySlot(slotData)
    if not slotData then
        return false
    end

    local hasItem = slotData.itemInfo ~= nil or slotData.itemLink ~= nil
    if hasItem then
        return self:SlotMatchesSearch(slotData)
    end

    return self:ShouldShowCompactEmptySlots()
end

--- Build a flat list of all backpack slots currently available.
-- @return table, number, number, number Slot list, used count, free count, total slots.
function Mod:CollectBagSlots()
    local slots = {}
    local used = 0
    local free = 0
    local total = 0

    for bagID = BACKPACK_START, BACKPACK_END do
        local numSlots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            total = total + 1
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slotID)
            local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
            local itemID = itemInfo and itemInfo.itemID or nil
            local itemCount = 0
            local isNewItem = false
            local classID, subclassID, equipLoc
            if itemID then
                local _, _, _, itemEquipLoc, _, itemClassID, itemSubclassID = GetItemInfoInstant(itemID)
                classID = itemClassID
                subclassID = itemSubclassID
                equipLoc = itemEquipLoc
            end
            if itemInfo then
                itemCount = itemInfo.stackCount or itemInfo.quantity or 1
                isNewItem = itemInfo.isNewItem or false
            end
            if itemInfo then
                used = used + 1
            else
                free = free + 1
            end

            tinsert(slots, {
                bagID = bagID,
                slotID = slotID,
                itemInfo = itemInfo,
                itemID = itemID,
                itemLink = itemLink,
                itemName = itemLink and GetItemInfo(itemLink) or nil,
                itemCount = itemCount,
                isNewItem = isNewItem,
                tooltipGetter = KT_Bags_BuildTooltipGetter(bagID, slotID, itemLink),
                itemLocation = ItemLocation and ItemLocation:CreateFromBagAndSlot(bagID, slotID) or nil,
                classID = classID,
                subclassID = subclassID,
                equipLoc = equipLoc,
                itemLevel = (itemLink and KT_Bags_IsRealEquipment(classID, equipLoc)) and KT_Bags_GetItemLevel(itemLink) or nil,
                quality = itemInfo and itemInfo.quality or nil,
            })
        end
    end

    return slots, used, free, total
end

local function KT_Bags_HideRegion(region)
    if region and region.Hide then
        region:Hide()
    end
end

local KT_BagsHiddenParent
local function KT_Bags_GetHiddenParent()
    if KT_BagsHiddenParent then
        return KT_BagsHiddenParent
    end
    KT_BagsHiddenParent = CreateFrame("Frame")
    KT_BagsHiddenParent:Hide()
    return KT_BagsHiddenParent
end

local function KT_Bags_GetItemButtonIcon(button)
    if not button then
        return nil
    end
    return button.icon or button.Icon or button.iconTexture
end

local function KT_Bags_StyleItemButton(button)
    if not button then
        return
    end

    local holder = button.KT_Holder
    if holder then
        button:ClearAllPoints()
        button:SetAllPoints(holder)
    end
end

-- ContainerFrameItemButtonTemplate (and Baganator's live item button) ship with
-- several decorative textures (slot art, borders, "new item" glows). In our
-- native bags window we render our own holder backdrop/border, so we strip
-- those layers to avoid persistent blue slot highlights after reload/login.
local function KT_Bags_StripItemButtonArt(button)
    if not button then
        return
    end

    local hidden = KT_Bags_GetHiddenParent()
    local function hideAndDetach(region)
        if region and region.Hide then
            region:Hide()
            if region.SetParent then
                region:SetParent(hidden)
            end
        end
    end

    local name = button.GetName and button:GetName()

    if button.ClearNormalTexture then
        pcall(button.ClearNormalTexture, button)
    elseif button.SetNormalTexture then
        pcall(button.SetNormalTexture, button, nil)
    end

    if button.SetNormalAtlas then
        pcall(button.SetNormalAtlas, button, nil)
    end

    hideAndDetach(button.GetNormalTexture and button:GetNormalTexture())
    hideAndDetach(button.NormalTexture or button.normalTexture or (name and _G[name .. "NormalTexture"]))
    hideAndDetach(button.SlotBackground or button.SlotTexture or button.Background)
    hideAndDetach(button.SearchOverlay or button.searchOverlay)
    hideAndDetach(button.ItemContextOverlay)
    hideAndDetach(button.BaganatorBagHighlight)
    hideAndDetach(button.IconBorder or button.iconBorder)
    hideAndDetach(button.IconOverlay or button.iconOverlay)
    hideAndDetach(button.JunkIcon or button.junkIcon)
    hideAndDetach(button.UpgradeIcon or button.upgradeIcon)
    hideAndDetach(button.QuestBorder or button.questBorder)
    hideAndDetach(button.IconQuestTexture or button.iconQuestTexture or button.QuestIcon or button.questIcon)
    hideAndDetach(button.BattlepayItemTexture or button.battlepayItemTexture)
    hideAndDetach(button.ProfessionQualityOverlay or button.professionQualityOverlay)

    hideAndDetach(button.NewItemTexture or button.newItemTexture or (name and _G[name .. "NewItemTexture"]))
    hideAndDetach(button.NewItemGlow or button.newItemGlow)
    hideAndDetach(button.NewItemOverlay or button.newItemOverlay)

    if button.newItemAnim and button.newItemAnim.Stop then
        pcall(button.newItemAnim.Stop, button.newItemAnim)
    end
    if button.NewItemAnim and button.NewItemAnim.Stop then
        pcall(button.NewItemAnim.Stop, button.NewItemAnim)
    end

    -- Some templates re-apply textures to unnamed regions. Hide any leftover slot art textures
    -- while keeping the icon and our highlight texture intact.
    local icon = KT_Bags_GetItemButtonIcon(button)
    local keep = {
        [icon] = true,
    }
    if button.GetHighlightTexture then
        keep[button:GetHighlightTexture()] = true
    end

    for _, region in ipairs({ button:GetRegions() }) do
        if region and not keep[region] and region.GetObjectType and region:GetObjectType() == "Texture" then
            local atlas = region.GetAtlas and region:GetAtlas()
            if type(atlas) == "string" then
                local lowerAtlas = atlas:lower()
                -- Retail container templates use atlases for slot backgrounds (e.g. "bags-item-slot64"),
                -- which won't be picked up by GetTexture() string checks.
                if lowerAtlas:find("bags-item-slot", 1, true) or lowerAtlas:find("bags-glow", 1, true) then
                    hideAndDetach(region)
                end
            end
            local tex = region.GetTexture and region:GetTexture()
            if type(tex) == "string" then
                local lowerTex = tex:lower()
                if lowerTex:find("quickslot", 1, true)
                    or lowerTex:find("containerslot", 1, true)
                    or lowerTex:find("bagslot", 1, true)
                    or lowerTex:find("slot", 1, true) and lowerTex:find("interface", 1, true)
                then
                    hideAndDetach(region)
                end
            end
        end
    end
end

--- Create a native item button owned by the bags module.
-- @param index number Item button index.
-- @return Button Native item button.
function Mod:EnsureItemButton(index)
    if self.itemButtons[index] then
        return self.itemButtons[index]
    end

    local parent = _G.KT_BagsWindow and _G.KT_BagsWindow.KT_Grid
    local itemSize = KT_Bags_GetConfiguredItemSize(self)
    -- Keep the container identity on a dedicated, otherwise untouched parent.
    -- Blizzard's protected click handler obtains the bag from self:GetParent():GetID().
    local indexFrame = CreateFrame("Frame", nil, parent)
    indexFrame:SetAllPoints(parent)
    indexFrame:SetID(0)
    indexFrame:SetFrameLevel(parent:GetFrameLevel() + 1)

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(itemSize, itemSize)
    holder:EnableMouse(false)
    KT:AddBackdrop(holder, 0.035, 0.028, 0.02, 0.9)
    KT:AddBorder(holder, 0.26, 0.19, 0.08, 0.95)

    holder.KT_NewItemBorder = CreateFrame("Frame", nil, holder)
    holder.KT_NewItemBorder:SetAllPoints(holder)
    KT:AddBorder(holder.KT_NewItemBorder, 1.0, 0.82, 0.12, 0.95, 2)
    holder.KT_NewItemBorder:Hide()

    local button
    do
        local templates = { "ContainerFrameItemButtonTemplate" }
        if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(KT_BAGANATOR_NAME) then
            templates = { "BaganatorRetailLiveContainerItemButtonTemplate", "ContainerFrameItemButtonTemplate" }
        end
        for _, template in ipairs(templates) do
            local ok, created = pcall(CreateFrame, "ItemButton", nil, indexFrame, template)
            if ok and created then
                button = created
                break
            end
        end

        if not button then
            -- Last resort fallback: show something instead of erroring.
            button = CreateFrame("Button", nil, indexFrame)
        end
    end
    button:SetAllPoints(holder)
    button:SetFrameLevel(holder:GetFrameLevel() + 1)
    if button.EnableMouse then
        button:EnableMouse(true)
    end
    if button.RegisterForClicks then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    if button.RegisterForDrag then
        button:RegisterForDrag("LeftButton")
    end

    -- If this is a Baganator live item button, apply its texture settings once.
    if button.UpdateTextures then
        pcall(function()
            button:UpdateTextures()
        end)
    end

    -- Remove Blizzard's default blue slot art (normal texture / slot background),
    -- since the KT holder already provides the background + border.
    KT_Bags_StripItemButtonArt(button)
    KT_Bags_StyleItemButton(button)

    -- Baganator item buttons support a "bag highlight" overlay (atlas "bags-glow-heirloom")
    -- toggled via :BGRSetHighlight(). After /reload this can remain stuck visible when
    -- the frame is embedded into other UIs. We never rely on it in the KT bags window,
    -- so force-hide it any time it's toggled.
    if hooksecurefunc and button.BGRSetHighlight and not button.KT_BGRHighlightSuppressed then
        button.KT_BGRHighlightSuppressed = true
        hooksecurefunc(button, "BGRSetHighlight", function(widget)
            if widget and widget.BaganatorBagHighlight then
                widget.BaganatorBagHighlight:Hide()
                if widget.BaganatorBagHighlight.SetParent then
                    widget.BaganatorBagHighlight:SetParent(KT_Bags_GetHiddenParent())
                end
            end
        end)
    end

    -- Some templates re-show IconBorder/IconOverlay from SetItemButtonQuality during async item info
    -- callbacks. Strip again after each quality update so the KT holder border remains the only one.
    if hooksecurefunc and button.SetItemButtonQuality and not button.KT_StripQualityHooked then
        button.KT_StripQualityHooked = true
        hooksecurefunc(button, "SetItemButtonQuality", function(widget)
            KT_Bags_StripItemButtonArt(widget)
            KT_Bags_StyleItemButton(widget)
        end)
    end

    if button.HookScript and not button.KT_StripShowHooked then
        button:HookScript("OnShow", function(widget)
            C_Timer.After(0, function()
                KT_Bags_StripItemButtonArt(widget)
                KT_Bags_StyleItemButton(widget)
            end)
        end)
        button.KT_StripShowHooked = true
    end

    if hooksecurefunc and button.UpdateTextures and not button.KT_StripUpdateTexturesHooked then
        hooksecurefunc(button, "UpdateTextures", function(widget)
            KT_Bags_StripItemButtonArt(widget)
            KT_Bags_StyleItemButton(widget)
        end)
        button.KT_StripUpdateTexturesHooked = true
    end

    if hooksecurefunc and button.SetItemDetails and not button.KT_StripSetItemDetailsHooked then
        hooksecurefunc(button, "SetItemDetails", function(widget)
            KT_Bags_StripItemButtonArt(widget)
            KT_Bags_StyleItemButton(widget)
        end)
        button.KT_StripSetItemDetailsHooked = true
    end

    -- Subtle KT highlight (no blue glow).
    if button.SetHighlightTexture and button.GetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        local hl = button:GetHighlightTexture()
        if hl and hl.SetVertexColor then
            hl:SetVertexColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.14)
        end
    end

    -- Watched marker overlay (ours).
    button.WatchMark = button:CreateFontString(nil, "OVERLAY")
    button.WatchMark:SetFont(KT_DEFAULT_FONT, 13, "OUTLINE")
    button.WatchMark:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.WatchMark:SetTextColor(1.0, 0.82, 0.0, 1.0)

    button.KT_ItemLevelText = button:CreateFontString(nil, "OVERLAY")
    button.KT_ItemLevelText:SetFont(KT_DEFAULT_FONT, 11, "OUTLINE")
    button.KT_ItemLevelText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 3, 3)
    button.KT_ItemLevelText:SetJustifyH("LEFT")
    button.KT_ItemLevelText:SetTextColor(1.0, 0.82, 0.0, 1.0)
    button.KT_ItemLevelText:Hide()

    -- The Blizzard item-button template is not guaranteed to update its
    -- cooldown when the button is populated manually, so keep a dedicated
    -- overlay for bag item cooldowns.
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetFrameLevel(button:GetFrameLevel() + 10)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(true) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(false) end
    cooldown:Hide()
    button.KT_Cooldown = cooldown

    button.KT_Holder = holder
    button.KT_IndexFrame = indexFrame

    if button.HookScript and C_NewItems and C_NewItems.RemoveNewItem and C_NewItems.IsNewItem then
        button:HookScript("OnEnter", function(widget)
            local bagID = widget.KT_BagID
            local slotID = widget.KT_SlotID
            if not bagID or not slotID then
                return
            end
            local ok, isNew = pcall(C_NewItems.IsNewItem, bagID, slotID)
            if ok and isNew then
                pcall(C_NewItems.RemoveNewItem, bagID, slotID)
                local holderFrame = widget.KT_Holder
                if holderFrame and holderFrame.KT_NewItemBorder then
                    holderFrame.KT_NewItemBorder:Hide()
                end
            end
        end)
    end

    self.itemButtons[index] = button
    return button
end

local function KT_Bags_GetCursorItemID()
    local cursorType, itemID = GetCursorInfo()
    if cursorType ~= "item" then
        return nil
    end
    return itemID
end

local function KT_Bags_IteratePlayerBagIDs()
    local ids = {}
    for bagID = BACKPACK_START, BACKPACK_END do
        ids[#ids + 1] = bagID
    end
    local reagentBag = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag)
        or _G.REAGENTBAG_CONTAINER
    if reagentBag ~= nil then
        ids[#ids + 1] = reagentBag
    end
    return ids
end

function Mod:FindFirstEmptySlotForItem(itemID)
    if not itemID then
        return nil, nil
    end

    local itemFamily = GetItemFamily and GetItemFamily(itemID) or 0
    local bagIDs = KT_Bags_IteratePlayerBagIDs()

    for _, bagID in ipairs(bagIDs) do
        local freeSlots, bagFamily = 0, 0
        if C_Container and C_Container.GetContainerNumFreeSlots then
            freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bagID)
        end
        if freeSlots and freeSlots > 0 then
            local canUseBag = (bagFamily == 0)
                or (itemFamily ~= 0 and bit and bit.band and bit.band(itemFamily, bagFamily) ~= 0)
            if canUseBag then
                local numSlots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bagID) or 0
                for slotID = 1, numSlots do
                    local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bagID, slotID) or nil
                    if not info then
                        return bagID, slotID
                    end
                end
            end
        end
    end

    return nil, nil
end

function Mod:EnsureBackgroundDropSlot()
    local window = _G.KT_BagsWindow
    if not window or window.KT_BackgroundDropButton then
        return
    end

    local parent = window.KT_GridScrollFrame or window.KT_GridPanel or window
    local indexFrame = CreateFrame("Frame", nil, parent)
    indexFrame:SetAllPoints(parent)
    indexFrame:SetFrameLevel(parent:GetFrameLevel() + 1)
    -- ContainerFrameItemButtonTemplate resolves its bag through the parent
    -- frame ID. Keep the button itself limited to the slot ID; SetBagID() on an
    -- addon-owned button taints the value later passed to UseContainerItem().
    indexFrame:SetID(BACKPACK_START or 0)

    local template = "ContainerFrameItemButtonTemplate"
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(KT_BAGANATOR_NAME) then
        template = "BaganatorRetailLiveContainerItemButtonTemplate"
    end

    local ok, dropButton = pcall(CreateFrame, "ItemButton", nil, indexFrame, template)
    if not ok or not dropButton then
        return
    end

    dropButton:SetAllPoints(parent)
    dropButton:SetAlpha(0)
    dropButton:SetFrameLevel((window.KT_Grid and window.KT_Grid:GetFrameLevel() or parent:GetFrameLevel()) + 1)
    dropButton:SetMotionScriptsWhileDisabled(true)
    if dropButton.RegisterForClicks then
        dropButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    if dropButton.RegisterForDrag then
        dropButton:RegisterForDrag("LeftButton")
    end
    -- Make it an invisible drop target; its only job is to provide a valid
    -- container-slot button under the cursor so dropping doesn't become "Delete".
    dropButton:ClearHighlightTexture()
    dropButton:ClearNormalTexture()
    dropButton:ClearDisabledTexture()
    dropButton:ClearPushedTexture()

    local hidden = KT_Bags_GetHiddenParent()
    for _, region in ipairs({ dropButton:GetRegions() }) do
        region:Hide()
        region:SetParent(hidden)
    end
    for _, child in ipairs({ dropButton:GetChildren() }) do
        child:Hide()
        child:SetParent(hidden)
    end

    local cursorChanged = false
    local function UpdateVisibility()
        cursorChanged = true
        if window.KT_BackgroundDropSuppressed then
            dropButton:Hide()
            return
        end
        local cursorType = GetCursorInfo()
        if cursorType == "item" then
            dropButton:Show()
        else
            dropButton:Hide()
        end
    end

    dropButton:RegisterEvent("CURSOR_CHANGED")
    dropButton:SetScript("OnEvent", UpdateVisibility)

    dropButton:SetScript("OnEnter", function(selfBtn)
        if window.KT_BackgroundDropSuppressed then
            selfBtn:Hide()
            return
        end
        if not cursorChanged then
            return
        end
        cursorChanged = false

        local itemID = KT_Bags_GetCursorItemID()
        if not itemID then
            selfBtn:Hide()
            return
        end

        local bagID, slotID = Mod:FindFirstEmptySlotForItem(itemID)
        if bagID and slotID then
            selfBtn:Enable()
            indexFrame:SetID(bagID)
            selfBtn:SetID(slotID)
        else
            -- No valid empty slot; keep it hidden so we don't swallow drops.
            selfBtn:Disable()
            selfBtn:Hide()
        end
    end)
    dropButton:SetScript("OnLeave", nil)

    UpdateVisibility()
    dropButton.KT_UpdateVisibility = UpdateVisibility

    window.KT_BackgroundDropIndex = indexFrame
    window.KT_BackgroundDropButton = dropButton
end

function Mod:RefreshBackgroundDropTarget()
    local window = _G.KT_BagsWindow
    if not window or not window.KT_BackgroundDropButton then
        return
    end

    window.KT_BackgroundDropSuppressed = self:ShouldShowCompactEmptySlots()
    if window.KT_BackgroundDropButton.KT_UpdateVisibility then
        window.KT_BackgroundDropButton.KT_UpdateVisibility()
    elseif window.KT_BackgroundDropSuppressed then
        window.KT_BackgroundDropButton:Hide()
    end
end

--- Show the standard item tooltip for a native bag item button.
-- @param button Button Native item button.
-- @return nil
function Mod:ShowItemTooltip(button)
    if not button or not button.KT_BagID or not button.KT_SlotID then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(button.KT_BagID, button.KT_SlotID)
    GameTooltip:Show()
end

--- Handle clicks on a native item button using Blizzard container APIs.
-- Alt+Click toggles the watched state for the item.
-- @param button Button Native item button.
-- @param mouseButton string Clicked mouse button.
-- @return nil
function Mod:HandleItemButtonClick(button, mouseButton)
    if not button or not button.KT_BagID or not button.KT_SlotID then
        KT_BagsDebugPrint("HandleClick", "missing bag/slot")
        return
    end

    if button.KT_HasItem == false then
        KT_BagsDebugPrint("HandleClick", "no item", "bag=" .. tostring(button.KT_BagID), "slot=" .. tostring(button.KT_SlotID))
        return
    end

    local itemLink = button.KT_ItemLink
    if itemLink then
        self.selectedItemLink = itemLink
        self.selectedItemName = button.KT_ItemName or GetItemInfo(itemLink) or itemLink
    else
        self.selectedItemLink = nil
        self.selectedItemName = nil
    end

    if itemLink and IsAltKeyDown() and mouseButton == "LeftButton" then
        if self:IsWatchedItem(itemLink) then
            self:RemoveWatchedItem(itemLink)
        else
            self:AddWatchedItem(itemLink)
        end
        KT_BagsDebugPrint("HandleClick", "alt watch toggle", itemLink)
        return
    end

    if mouseButton == "RightButton" then
        return
    end

    return
end

KT_Bags_UpdateItemCooldown = function(button, bagID, slotID)
    if not button or not button.KT_Cooldown then
        return
    end

    local startTime, duration, enable
    if C_Container and C_Container.GetContainerItemCooldown and bagID and slotID then
        local ok, start, length, enabled = pcall(C_Container.GetContainerItemCooldown, bagID, slotID)
        if ok then
            startTime, duration, enable = start, length, enabled
        end
    elseif GetContainerItemCooldown and bagID and slotID then
        local ok, start, length, enabled = pcall(GetContainerItemCooldown, bagID, slotID)
        if ok then
            startTime, duration, enable = start, length, enabled
        end
    end

    local active = type(startTime) == "number" and type(duration) == "number"
        and startTime > 0 and duration > 0 and enable ~= 0
    if active then
        if button.KT_CooldownStart ~= startTime or button.KT_CooldownDuration ~= duration then
            button.KT_CooldownStart = startTime
            button.KT_CooldownDuration = duration
            button.KT_Cooldown:SetCooldown(startTime, duration)
        end
        if not button.KT_Cooldown:IsShown() then
            button.KT_Cooldown:Show()
        end
    else
        button.KT_CooldownStart = nil
        button.KT_CooldownDuration = nil
        if button.KT_Cooldown:IsShown() then
            button.KT_Cooldown:Hide()
        end
    end
end
function Mod:ApplyItemButtonMetrics(button)
    if not button then
        return
    end

    local itemSize = KT_Bags_GetConfiguredItemSize(self)
    local inset = math.max(2, math.floor(itemSize * 0.08))
    local watchFontSize = math.max(11, math.floor(itemSize * 0.34))
    local ilvlFontSize = math.max(11, math.floor(itemSize * 0.30))
    local countFontSize = math.max(12, math.floor(itemSize * 0.32))

    if button.KT_Holder then
        button.KT_Holder:SetSize(itemSize, itemSize)
    end
    if button.WatchMark then
        button.WatchMark:SetFont(KT_DEFAULT_FONT, watchFontSize, "OUTLINE")
        button.WatchMark:ClearAllPoints()
        button.WatchMark:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    end

    if button.KT_ItemLevelText then
        button.KT_ItemLevelText:SetFont(KT_DEFAULT_FONT, ilvlFontSize, "OUTLINE")
        button.KT_ItemLevelText:ClearAllPoints()
        button.KT_ItemLevelText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset, inset)
    end
    if button.Count then
        button.Count:SetFont(KT_DEFAULT_FONT, countFontSize, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
        button.Count:SetJustifyH("RIGHT")
    end
end

--- Update the visuals of a native item button from live container data.
-- @param button Button Native item button.
-- @param slotData table Slot data collected from the backpack.
-- @return nil
function Mod:UpdateItemButton(button, slotData)
    self:ApplyItemButtonMetrics(button)

    local bagID = slotData.bagID
    local slotID = slotData.slotID
    local itemInfo = slotData.itemInfo
    local itemLink = slotData.itemLink
    local isNewItem = slotData.isNewItem == true
    if C_NewItems and C_NewItems.IsNewItem and bagID and slotID then
        local ok, value = pcall(C_NewItems.IsNewItem, bagID, slotID)
        if ok and type(value) == "boolean" then
            isNewItem = value
        end
    end
    slotData.isNewItem = isNewItem

    -- Ensure no stale highlight state persists across refreshes.
    if button.UnlockHighlight then
        button:UnlockHighlight()
    end

    -- Keep Blizzard's protected inputs isolated from KUI's decorated holder:
    -- the dedicated parent frame ID is the bag and the button ID is the slot.
    -- Do not call SetBagID() or store Blizzard's hasItem/itemLink fields here.
    button.KT_BagID = bagID
    button.KT_SlotID = slotID
    button.KT_ItemLink = itemLink
    button.KT_ItemName = slotData.itemName
    button.KT_ItemID = slotData.itemID
    button.KT_HasItem = (itemInfo ~= nil) or (itemLink ~= nil)
    if button.KT_IndexFrame then
        button.KT_IndexFrame:SetID(bagID or 0)
    end
    if button.SetID then
        button:SetID(slotID or 0)
    end

    KT_BagsDebugPrint(
        "Update",
        "bag=" .. tostring(bagID),
        "slot=" .. tostring(slotID),
        "hasItem=" .. tostring(button.KT_HasItem),
        "template=ContainerFrameItemButtonTemplate"
    )

    if button.SetItemDetails then
        button:SetItemDetails({
            itemLink = itemLink,
            iconTexture = itemInfo and itemInfo.iconFileID or nil,
            itemCount = itemInfo and (slotData.itemCount or (itemInfo and (itemInfo.stackCount or itemInfo.quantity) or 1)) or 0,
            quality = itemInfo and itemInfo.quality or nil,
            itemID = slotData.itemID,
            isNewItem = isNewItem,
            isBound = itemInfo and itemInfo.isBound or false,
            hasLoot = itemInfo and itemInfo.hasLoot or false,
            -- Match Baganator/Syndicator live-container itemLocation shape.
            itemLocation = (bagID and slotID) and { bagID = bagID, slotIndex = slotID } or nil,
        })
    elseif itemInfo then
        if button.SetItemButtonTexture then
            button:SetItemButtonTexture(itemInfo.iconFileID)
        elseif SetItemButtonTexture and button.icon then
            SetItemButtonTexture(button, itemInfo.iconFileID)
        end
        if SetItemButtonCount and button.Count then
            SetItemButtonCount(button, slotData.itemCount or KT_GetStackCount(itemInfo))
        end
    else
        if button.SetItemButtonTexture then
            button:SetItemButtonTexture(nil)
        elseif SetItemButtonTexture and button.icon then
            SetItemButtonTexture(button, nil)
        end
        if SetItemButtonCount and button.Count then
            SetItemButtonCount(button, 0)
        end
    end

    local icon = KT_Bags_GetItemButtonIcon(button)
    if icon then
        if itemInfo and itemInfo.iconFileID then
            icon:Show()
            if icon.SetDesaturated then
                icon:SetDesaturated(false)
            end
            if icon.SetVertexColor then
                icon:SetVertexColor(1, 1, 1, 1)
            end
        else
            icon:SetTexture(nil)
            icon:Hide()
        end
    end

    if button.WatchMark then
        if self:IsWatchedItem(itemLink) then
            button.WatchMark:SetText(KT_WATCH_ICON)
        else
            button.WatchMark:SetText("")
        end
    end

    KT_Bags_UpdateItemCooldown(button, bagID, slotID)

    if button.KT_ItemLevelText then
        local showItemLevel = self.db and self.db.showItemLevel ~= false
        local itemLevel = slotData.itemLevel
        local stackOrChargeText = button.Count and button.Count.GetText and button.Count:GetText() or nil
        local hasVisibleCount = button.Count and button.Count.IsShown and button.Count:IsShown() and stackOrChargeText and stackOrChargeText ~= "" and stackOrChargeText ~= "1"
        if showItemLevel and itemLevel and not hasVisibleCount then
            local red, green, blue = 1.0, 0.82, 0.0
            if self.db and self.db.itemLevelColorByRarity then
                red, green, blue = KT_Bags_GetQualityColor(slotData.quality)
            end
            button.KT_ItemLevelText:SetText(itemLevel)
            button.KT_ItemLevelText:SetTextColor(red, green, blue, 1)
            button.KT_ItemLevelText:Show()
        else
            button.KT_ItemLevelText:SetText("")
            button.KT_ItemLevelText:Hide()

        end
    end

    if button.KT_Holder and button.KT_Holder.KT_NewItemBorder then
        button.KT_Holder.KT_NewItemBorder:SetShown(isNewItem)
    end

    -- Some templates re-apply Blizzard's default blue slot art during updates.
    -- Strip it every refresh so the KT holder skin stays consistent.
    KT_Bags_StripItemButtonArt(button)
    KT_Bags_StyleItemButton(button)
end

function Mod:RefreshEquippedBagIcons()
    local window = _G.KT_BagsWindow
    if not window or not window.KT_BagIcons or not window.KT_BagIconFrame then
        return
    end
    if not C_Container or not C_Container.ContainerIDToInventoryID then
        return
    end

    local showIcons = self.db and self.db.showEquippedBags
    local style = self.db and self.db.bagIconStyle or "modern"
    local iconSize = (self.db and self.db.bagIconSize) or KT_EQUIPPED_BAG_ICON_SIZE
    if window.KT_BagIconFrame and window.KT_BagIconFrame.KT_Bg then
        if style == "dark" then
            window.KT_BagIconFrame.KT_Bg:SetColorTexture(0, 0, 0, 0.6)
            window.KT_BagIconFrame.KT_Bg:Show()
        else
            window.KT_BagIconFrame.KT_Bg:SetColorTexture(0, 0, 0, 0.25)
            window.KT_BagIconFrame.KT_Bg:Show()
        end
    end

    local holderSize = iconSize + 6
    for index, icon in ipairs(window.KT_BagIcons) do
        local holder = window.KT_BagIconHolders and window.KT_BagIconHolders[index]
        if holder then
            local selected = self.selectedBagID == index
            local ar, ag, ab = KT_Bags_GetAccentColor()
            holder:SetSize(holderSize, holderSize)
            holder:ClearAllPoints()
            if index == 1 then
                holder:SetPoint("LEFT", window.KT_BagIconFrame, "LEFT", 0, 0)
            else
                holder:SetPoint("LEFT", window.KT_BagIconHolders[index - 1], "RIGHT", KT_EQUIPPED_BAG_ICON_SPACING, 0)
            end
            if selected then
                holder:SetBackdropColor(ar * 0.22, ag * 0.22, ab * 0.22, 0.98)
            else
                holder:SetBackdropColor(0.018, 0.018, 0.024, 0.98)
            end
            holder:SetBackdropBorderColor(ar, ag, ab, selected and 1 or 0.56)
            KT_Bags_ApplyAccentSurface(holder, {
                topAlpha = 0.05,
                leftAlpha = 0.022,
                lineAlpha = selected and 0.32 or 0.18,
                accentBorderAlpha = selected and 1 or 0.56,
                topCoverage = 0.50,
                leftCoverage = 0.32,
            })
        end
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
        if index == 1 then
            icon:SetPoint("TOPLEFT", holder or window.KT_BagIconFrame, "TOPLEFT", holder and 3 or 0, holder and -3 or 0)
        else
            icon:SetPoint("TOPLEFT", holder or window.KT_BagIcons[index - 1], holder and "TOPLEFT" or "RIGHT", holder and 3 or KT_EQUIPPED_BAG_ICON_SPACING, holder and -3 or 0)
        end
        if holder then
            icon:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -3, 3)
        end

        local bagID = index
        local invID = C_Container.ContainerIDToInventoryID(bagID)
        local texture = invID and GetInventoryItemTexture("player", invID) or nil
        if texture then
            icon:SetTexture(texture)
            icon:SetDesaturated(false)
            icon:SetVertexColor(1, 1, 1, 1)
        else
            icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
            icon:SetDesaturated(true)
            icon:SetVertexColor(0.72, 0.72, 0.78, 1)
        end
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    if window.KT_BagIconFrame then
        local bagSlots = #window.KT_BagIcons
        local width = (bagSlots * holderSize) + ((bagSlots - 1) * KT_EQUIPPED_BAG_ICON_SPACING)
        window.KT_BagIconFrame:SetSize(width, holderSize)
        window.KT_BagIconFrame:SetShown(showIcons and bagSlots > 0)
    end

    if window.KT_SearchBox and window.KT_WatchedBadge then
        window.KT_SearchBox:ClearAllPoints()
        window.KT_SearchBox:SetPoint("TOPLEFT", window.KT_Toolbar, "TOPLEFT", 8, -6)
        if showIcons and window.KT_BagIconFrame and window.KT_BagIconFrame:IsShown() then
            window.KT_SearchBox:SetPoint("TOPRIGHT", window.KT_BagIconFrame, "LEFT", -8, -6)
        else
            window.KT_SearchBox:SetPoint("TOPRIGHT", window.KT_WatchedBadge, "LEFT", -8, -6)
        end
        window.KT_SearchBox:SetHeight(46)
    end
end

function Mod:RefreshGoldDisplay()
    local window = _G.KT_BagsWindow
    if not window or not window.KT_FooterGold then
        return
    end

    local showGold = true
    if self.db and self.db.currency and self.db.currency.showGold == false then
        showGold = false
    end
    window.KT_FooterGold:SetShown(showGold)
    if not showGold then
        window.KT_FooterGold:SetText("")
        return
    end

    local money = GetMoney and GetMoney() or 0
    window.KT_FooterGold:SetText(KT_Bags_FormatMoney(money))
end

local function KT_Bags_ToggleCurrencyFrame()
    if ToggleCharacter then
        ToggleCharacter("TokenFrame")
        return
    end
    if _G.TokenFrame and _G.TokenFrame:IsShown() then
        _G.TokenFrame:Hide()
    elseif _G.TokenFrame then
        _G.TokenFrame:Show()
    end
end

local function KT_Bags_GetBackpackCurrencies()
    local result = {}
    for i = 1, 100 do
        local currencyID, quantity, iconFileID
        if C_CurrencyInfo and C_CurrencyInfo.GetBackpackCurrencyInfo then
            local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
            if not info then
                break
            end
            currencyID = info.currencyTypesID or info.currencyID
            quantity = info.quantity or info.count or 0
            iconFileID = info.iconFileID or info.icon or nil
        elseif GetBackpackCurrencyInfo then
            local name, count, icon, id = GetBackpackCurrencyInfo(i)
            if not name then
                break
            end
            currencyID = id
            quantity = count or 0
            iconFileID = icon
        else
            break
        end

        if currencyID then
            table.insert(result, { currencyID = currencyID, quantity = quantity or 0, iconFileID = iconFileID })
        end
    end
    return result
end

local function KT_Bags_GetKnownCurrencyNameMap()
    local map = {}
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize and C_CurrencyInfo.GetCurrencyListInfo then
        local listSize = C_CurrencyInfo.GetCurrencyListSize()
        for index = 1, listSize do
            local info = C_CurrencyInfo.GetCurrencyListInfo(index)
            if info and not info.isHeader and not info.isTypeUnused and info.name and info.currencyTypesID then
                map[KT_Bags_SafeLower(info.name)] = info.currencyTypesID
            end
        end
    end
    return map
end

local function KT_Bags_ParseCurrencyList(input)
    local resolved = {}
    local seen = {}
    local nameMap = KT_Bags_GetKnownCurrencyNameMap()

    for token in string.gmatch(input or "", "[^,\r\n;]+") do
        local trimmed = strtrim(token or "")
        if trimmed ~= "" then
            local currencyID = tonumber(trimmed)
            if not currencyID then
                currencyID = tonumber(trimmed:match("currency:(%d+)"))
            end
            if not currencyID then
                currencyID = tonumber(trimmed:match("currency=(%d+)"))
            end
            if not currencyID then
                currencyID = nameMap[KT_Bags_SafeLower(trimmed)]
            end

            if currencyID and not seen[currencyID] then
                resolved[#resolved + 1] = currencyID
                seen[currencyID] = true
            end
        end
    end

    return resolved
end

local function KT_Bags_GetCustomCurrencies(module)
    local result = {}
    local cfg = module and module.db and module.db.currency or {}
    local customIDs = KT_Bags_ParseCurrencyList(cfg.customList or "")

    for _, currencyID in ipairs(customIDs) do
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            result[#result + 1] = {
                currencyID = currencyID,
                quantity = info.quantity or 0,
                iconFileID = info.iconFileID or info.icon,
            }
        end
    end

    return result
end

local function KT_Bags_GetDisplayCurrencies(module)
    local cfg = module and module.db and module.db.currency or {}
    local mode = cfg.mode or "backpack"
    local result = {}
    local seen = {}

    local function addList(list)
        for _, details in ipairs(list) do
            local currencyID = details and details.currencyID
            if currencyID and not seen[currencyID] then
                seen[currencyID] = true
                result[#result + 1] = details
            end
        end
    end

    if mode == "custom" or mode == "both" then
        addList(KT_Bags_GetCustomCurrencies(module))
    end
    if mode == "backpack" or mode == "both" then
        addList(KT_Bags_GetBackpackCurrencies())
    end

    return result
end

local function KT_Bags_RemoveCustomCurrency(module, currencyID)
    local cfg = module and module.db and module.db.currency
    if not cfg or not currencyID then
        return false
    end

    local ids = KT_Bags_ParseCurrencyList(cfg.customList or "")
    local kept = {}
    local removed = false
    for _, value in ipairs(ids) do
        if value ~= currencyID then
            kept[#kept + 1] = tostring(value)
        else
            removed = true
        end
    end

    if removed then
        cfg.customList = table.concat(kept, ", ")
    end

    return removed
end

function Mod:EnsureCurrencyButton(index)
    local window = _G.KT_BagsWindow
    if not window or not window.KT_Footer then
        return nil
    end
    window.KT_CurrencyButtons = window.KT_CurrencyButtons or {}
    if window.KT_CurrencyButtons[index] then
        return window.KT_CurrencyButtons[index]
    end

    local button = CreateFrame("Button", nil, window.KT_Footer)
    button:SetHeight(KT_FOOTER_CURRENCY_ICON_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetSize(KT_FOOTER_CURRENCY_ICON_SIZE, KT_FOOTER_CURRENCY_ICON_SIZE)
    button.Icon:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.Text = button:CreateFontString(nil, "OVERLAY")
    button.Text:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
    button.Text:SetPoint("LEFT", button.Icon, "RIGHT", 2, 0)
    button.Text:SetJustifyH("LEFT")
    button.Text:SetTextColor(0.92, 0.92, 0.95, 1)

    button:SetScript("OnEnter", function(btn)
        if not btn.currencyID then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        if GameTooltip.SetCurrencyByID then
            GameTooltip:SetCurrencyByID(btn.currencyID)
        else
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(btn.currencyID)
            GameTooltip:SetText(info and info.name or LText("CURRENCY", "Currency"), 1, 1, 1)
        end
        
        -- Add tracking information if enabled
        local currencyCfg = (self.db and self.db.currency) or {}
        if currencyCfg.enableTracking ~= false and currencyCfg.showTrackingGains ~= false then
            local trackingInfo = self:GetCurrencyTrackingInfo(btn.currencyID)
            if trackingInfo and (trackingInfo.totalGained > 0 or trackingInfo.totalLost > 0) then
                GameTooltip:AddLine(" ")
                if trackingInfo.totalGained > 0 then
                    GameTooltip:AddLine(format("|cff4bff5cGained: +%s|r", tostring(trackingInfo.totalGained)), 0.2, 1, 0.2)
                end
                if trackingInfo.totalLost > 0 then
                    GameTooltip:AddLine(format("|cffff4b4bLost: -%s|r", tostring(trackingInfo.totalLost)), 1, 0.2, 0.2)
                end
            end
        end
        
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(btn, mouseButton)
        if not btn.currencyID then
            return
        end

        local cfg = (self.db and self.db.currency) or {}
        if mouseButton == "RightButton" and cfg.rightClickUntracks ~= false then
            if (cfg.mode == "custom" or cfg.mode == "both") and KT_Bags_RemoveCustomCurrency(self, btn.currencyID) then
                self:RefreshCurrencyDisplay()
                return
            end
            -- Quick untrack (mirrors Blizzard backpack tracking).
            if C_CurrencyInfo and C_CurrencyInfo.SetCurrencyBackpackByID then
                C_CurrencyInfo.SetCurrencyBackpackByID(btn.currencyID, false)
            end
            return
        end

        -- Shift-click to chat link the currency, otherwise open the currency UI.
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            local GetCurrencyLink = (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink) or GetCurrencyLink
            if GetCurrencyLink and btn.quantity then
                local link = GetCurrencyLink(btn.currencyID, btn.quantity)
                if link and KT and KT.InsertLink then
                    KT:InsertLink(link)
                elseif ChatEdit_InsertLink then
                    ChatEdit_InsertLink(link)
                end
            end
            return
        end

        if cfg.clickOpensTokenFrame ~= false then
            KT_Bags_ToggleCurrencyFrame()
        end
    end)

    window.KT_CurrencyButtons[index] = button
    return button
end

--- Track currency changes for gain/loss information.
-- @param currencyID number The currency ID to track.
-- @param quantity number The current quantity.
-- @return nil
function Mod:TrackCurrencyChange(currencyID, quantity)
    local cfg = (self.db and self.db.currency) or {}
    if cfg.enableTracking == false then
        return
    end

    local tracking = (self.db and self.db.currencyTracking) or {}
    if not tracking[currencyID] then
        tracking[currencyID] = {
            previous = quantity,
            previousTime = time(),
            totalGained = 0,
            totalLost = 0,
        }
        return
    end

    local entry = tracking[currencyID]
    local now = time()
    local timeDiff = (now - (entry.previousTime or now))
    
    -- Only update if at least 1 second has passed (prevents rapid updates)
    if timeDiff >= 1 then
        local diff = quantity - (entry.previous or 0)
        if diff > 0 then
            entry.totalGained = (entry.totalGained or 0) + diff
        elseif diff < 0 then
            entry.totalLost = (entry.totalLost or 0) + math.abs(diff)
        end
        entry.previous = quantity
        entry.previousTime = now
    end
end

--- Get currency tracking information for tooltip display.
-- @param currencyID number The currency ID to query.
-- @return table Tracking information or nil.
function Mod:GetCurrencyTrackingInfo(currencyID)
    local tracking = (self.db and self.db.currencyTracking[currencyID])
    if not tracking then
        return nil
    end
    return {
        totalGained = tracking.totalGained or 0,
        totalLost = tracking.totalLost or 0,
        previous = tracking.previous or 0,
    }
end

--- Reset currency tracking for a specific currency or all currencies.
-- @param currencyID number Optional. The currency ID to reset. If nil, resets all.
-- @return nil
function Mod:ResetCurrencyTracking(currencyID)
    if not (self.db and self.db.currencyTracking) then
        return
    end
    
    if currencyID then
        self.db.currencyTracking[currencyID] = nil
    else
        self.db.currencyTracking = {}
    end
end

function Mod:RefreshCurrencyDisplay()
    local window = _G.KT_BagsWindow
    if not window or not window.KT_FooterGold then
        return
    end

    local currencyCfg = (self.db and self.db.currency) or {}
    if currencyCfg.show == false then
        window.KT_CurrencyButtons = window.KT_CurrencyButtons or {}
        for i = 1, #window.KT_CurrencyButtons do
            if window.KT_CurrencyButtons[i] then
                window.KT_CurrencyButtons[i]:Hide()
            end
        end
        return
    end

    local list = KT_Bags_GetDisplayCurrencies(self)
    local maxShown = currencyCfg.max or 3
    local spacing = currencyCfg.spacing or KT_FOOTER_CURRENCY_SPACING
    if type(maxShown) ~= "number" or maxShown < 0 then
        maxShown = 3
    end
    if type(spacing) ~= "number" or spacing < 0 then
        spacing = KT_FOOTER_CURRENCY_SPACING
    end
    if maxShown == 0 then
        list = {}
    elseif #list > maxShown then
        for i = #list, maxShown + 1, -1 do
            list[i] = nil
        end
    end

    local prev = window.KT_FooterGold and window.KT_FooterGold:IsShown() and window.KT_FooterGold or nil

    for i = 1, #list do
        local details = list[i]
        local btn = self:EnsureCurrencyButton(i)
        if btn then
            btn.currencyID = details.currencyID
            btn.quantity = details.quantity or 0
            
            -- Track currency changes
            self:TrackCurrencyChange(details.currencyID, btn.quantity)
            
            if details.iconFileID then
                btn.Icon:SetTexture(details.iconFileID)
            end

            local text = BreakUpLargeNumbers and BreakUpLargeNumbers(btn.quantity) or tostring(btn.quantity)
            if AbbreviateNumbers and strlenutf8 and strlenutf8(text) > 5 then
                text = AbbreviateNumbers(btn.quantity)
            end
            btn.Text:SetText(text)

            local w = (btn.Text:GetStringWidth() or 0) + KT_FOOTER_CURRENCY_ICON_SIZE + 2
            btn:SetWidth(math.max(12, math.ceil(w)))

            btn:ClearAllPoints()
            if prev then
                btn:SetPoint("RIGHT", prev, "LEFT", -spacing, 0)
            else
                btn:SetPoint("RIGHT", window.KT_Footer, "RIGHT", -10, 0)
            end
            btn:Show()
            prev = btn
        end
    end

    window.KT_CurrencyButtons = window.KT_CurrencyButtons or {}
    for i = #list + 1, #window.KT_CurrencyButtons do
        local btn = window.KT_CurrencyButtons[i]
        if btn then
            btn.currencyID = nil
            btn.quantity = nil
            btn:Hide()
        end
    end
end

--- Update the side panel text for the native backpack window.
-- @param used number Used slots count.
-- @param free number Free slots count.
-- @param total number Total slots count.
-- @return nil
function Mod:RefreshSidePanel(used, free, total)
    local window = _G.KT_BagsWindow
    if not window then
        return
    end

    local watchedCount = 0
    for _ in pairs(self.watchedItems) do
        watchedCount = watchedCount + 1
    end

    if window.KT_ModeButton and window.KT_ModeButton.Text then
        window.KT_ModeButton.Text:SetText(self.db.viewMode == "category" and LText("BAGS_MODE_COMPACT", "Compact") or LText("BAGS_MODE_SECTIONS", "Sections"))
    end

    window.KT_Status:SetText(format(LText("BAGS_SLOTS", "Slots %d/%d"), used, total))
    window.KT_Summary:SetText(format(LText("BAGS_FREE", "Free %d"), free))

    if self.selectedItemLink then
        window.KT_SelectedIcon:SetTexture(GetItemIcon(self.selectedItemLink))
        window.KT_SelectedIcon:Show()
        window.KT_Selected:SetText(
            format(
                "%s",
                self.selectedItemName or self.selectedItemLink
            )
        )
    else
        window.KT_SelectedIcon:SetTexture(nil)
        window.KT_SelectedIcon:Hide()
        window.KT_Selected:SetText(LText("BAGS_NO_ITEM_SELECTED", "No item selected"))
    end

    window.KT_WatchedHeader:SetText(format(LText("BAGS_WATCH", "Watch %d"), watchedCount))
    if window.KT_FooterBagLabel then
        window.KT_FooterBagLabel:SetText("")
        window.KT_FooterBagLabel:Hide()
    end
    if window.KT_WatchedList then
        window.KT_WatchedList:SetText("")
    end

    self:RefreshEquippedBagIcons()
    self:RefreshGoldDisplay()
    self:RefreshCurrencyDisplay()
end

function Mod:GetBaganatorCategoryFilter()
    if self.baganatorCategoryFilter then
        return self.baganatorCategoryFilter
    end

    if not _G.BaganatorCategoryViewsCategoryFilterMixin then
        return nil
    end

    local filter = CreateFrame("Frame", nil, UIParent)
    Mixin(filter, _G.BaganatorCategoryViewsCategoryFilterMixin)
    filter:OnLoad()
    filter:SetScript("OnHide", filter.OnHide)
    self.baganatorCategoryFilter = filter
    return filter
end

function Mod:GetBaganatorCategoryGrouping()
    if self.baganatorCategoryGrouping then
        return self.baganatorCategoryGrouping
    end

    if not _G.BaganatorCategoryViewsCategoryGroupingMixin then
        return nil
    end

    local grouping = CreateFrame("Frame", nil, UIParent)
    Mixin(grouping, _G.BaganatorCategoryViewsCategoryGroupingMixin)
    grouping:SetScript("OnHide", grouping.OnHide)
    self.baganatorCategoryGrouping = grouping
    return grouping
end

function Mod:ApplyBaganatorCategoryFilters(composed, everything, callback)
    local filter = self:GetBaganatorCategoryFilter()
    if not filter then
        return false
    end

    local grouping = self:GetBaganatorCategoryGrouping()

    filter:Cancel()
    if grouping then
        grouping:Cancel()
    end

    if grouping then
        filter:ApplySearches(composed, everything, function()
            grouping:ApplyGroupings(composed, function()
                callback()
            end)
        end)
    else
        filter:ApplySearches(composed, everything, callback)
    end
    return true
end

function Mod:SetSidebarSelection(kind, source)
    self.selectedBagID = nil
    if kind == "compact" then
        self.db.viewMode = "compact"
        self.selectedSpecialView = nil
        self.selectedCategorySource = nil
    elseif kind == "watched" then
        self.db.viewMode = "category"
        self.selectedSpecialView = "watched"
        self.selectedCategorySource = nil
    elseif kind == "category" and source then
        self.db.viewMode = "category"
        self.selectedSpecialView = nil
        self.selectedCategorySource = source
    else
        self.db.viewMode = "category"
        self.selectedSpecialView = nil
        self.selectedCategorySource = nil
    end
    self:RefreshBagSlots()
end

function Mod:ApplySidebarRowVisual(row, active, hover)
    if not row then
        return
    end

    local ar, ag, ab = KT_Bags_GetAccentColor()
    if active then
        row:SetBackdropColor(ar * 0.20, ag * 0.20, ab * 0.20, 0.58)
        row:SetBackdropBorderColor(ar, ag, ab, 0.42)
        if row.KT_Left then row.KT_Left:SetColorTexture(ar, ag, ab, 0.85) end
        if row.KT_Label then row.KT_Label:SetTextColor(0.98, 0.98, 1, 1) end
        if row.KT_Count then row.KT_Count:SetTextColor(0.86, 0.86, 0.90, 0.95) end
    elseif hover then
        row:SetBackdropColor(0.09, 0.09, 0.105, 0.74)
        row:SetBackdropBorderColor(ar, ag, ab, 0.22)
        if row.KT_Left then row.KT_Left:SetColorTexture(ar, ag, ab, 0.36) end
        if row.KT_Label then row.KT_Label:SetTextColor(0.92, 0.92, 0.96, 1) end
        if row.KT_Count then row.KT_Count:SetTextColor(0.78, 0.78, 0.84, 0.9) end
    else
        row:SetBackdropColor(0, 0, 0, 0)
        row:SetBackdropBorderColor(0, 0, 0, 0)
        if row.KT_Left then row.KT_Left:SetColorTexture(ar, ag, ab, 0) end
        if row.KT_Label then row.KT_Label:SetTextColor(0.82, 0.82, 0.86, 0.96) end
        if row.KT_Count then row.KT_Count:SetTextColor(0.62, 0.62, 0.68, 0.86) end
    end
end

function Mod:EnsureSidebarRow(window, index)
    window.KT_SidebarRows = window.KT_SidebarRows or {}
    local row = window.KT_SidebarRows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, window.KT_SidebarContent or window.KT_Sidebar, "BackdropTemplate")
    row:SetHeight(KT_BAGS_SIDEBAR_ROW_HEIGHT)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    row.KT_Left = row:CreateTexture(nil, "ARTWORK")
    row.KT_Left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.KT_Left:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
    row.KT_Left:SetWidth(3)

    row.KT_Icon = row:CreateTexture(nil, "ARTWORK")
    row.KT_Icon:SetSize(KT_BAGS_SIDEBAR_ICON_SIZE, KT_BAGS_SIDEBAR_ICON_SIZE)
    row.KT_Icon:SetPoint("LEFT", row, "LEFT", 7, 0)

    row.KT_Label = row:CreateFontString(nil, "OVERLAY")
    row.KT_Label:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
    row.KT_Label:SetPoint("LEFT", row.KT_Icon, "RIGHT", 8, 0)
    row.KT_Label:SetPoint("RIGHT", row, "RIGHT", -38, 0)
    row.KT_Label:SetJustifyH("LEFT")
    if row.KT_Label.SetWordWrap then row.KT_Label:SetWordWrap(false) end
    if row.KT_Label.SetNonSpaceWrap then row.KT_Label:SetNonSpaceWrap(false) end
    if row.KT_Label.SetMaxLines then row.KT_Label:SetMaxLines(1) end

    row.KT_Count = row:CreateFontString(nil, "OVERLAY")
    row.KT_Count:SetFont(KT_DEFAULT_FONT, 11, "OUTLINE")
    row.KT_Count:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.KT_Count:SetJustifyH("RIGHT")
    if row.KT_Count.SetWordWrap then row.KT_Count:SetWordWrap(false) end
    if row.KT_Count.SetMaxLines then row.KT_Count:SetMaxLines(1) end

    row:SetScript("OnClick", function(widget)
        if widget.KT_Click then
            widget.KT_Click()
        end
    end)
    row:SetScript("OnEnter", function(widget)
        Mod:ApplySidebarRowVisual(widget, widget.KT_Active, true)
    end)
    row:SetScript("OnLeave", function(widget)
        Mod:ApplySidebarRowVisual(widget, widget.KT_Active, false)
    end)

    window.KT_SidebarRows[index] = row
    return row
end

function Mod:RefreshCategorySidebar(window, composed, visibleSlots, used, total)
    if not (window and window.KT_Sidebar) then
        return
    end

    local rows = {}
    local watchedCount = 0
    for _, slotData in ipairs(visibleSlots or {}) do
        if self:IsWatchedItem(slotData.itemLink) then
            watchedCount = watchedCount + 1
        end
    end

    rows[#rows + 1] = {
        kind = "all",
        label = LText("BAGS_ALL_ITEMS", "All Items"),
        count = used or #(visibleSlots or {}),
        icon = KT_BAGS_CATEGORY_ICONS.all,
        active = self.db.viewMode == "category" and not self.selectedSpecialView and not self.selectedCategorySource,
    }
    rows[#rows + 1] = {
        kind = "compact",
        label = LText("BAGS_ONEBAG", "OneBag"),
        count = total or #(visibleSlots or {}),
        icon = KT_BAGS_CATEGORY_ICONS.onebag,
        active = self.db.viewMode == "compact",
    }
    rows[#rows + 1] = {
        kind = "watched",
        label = LText("BAGS_PINNED_ITEMS", "Pinned Items"),
        count = watchedCount,
        icon = KT_BAGS_CATEGORY_ICONS.watched,
        active = self.selectedSpecialView == "watched",
    }

    if composed and composed.details then
        local sectionHasItems = {}
        for _, details in ipairs(composed.details) do
            if details.type == "category" and #(details.results or {}) > 0 and type(details.section) == "table" then
                for _, section in ipairs(details.section) do
                    sectionHasItems[section] = true
                end
            end
        end

        local detailIndex = composed.start or 1
        local guard = 0
        while detailIndex and composed.details[detailIndex] and guard < 200 do
            guard = guard + 1
            local details = composed.details[detailIndex]
            if details.type == "section" and details.label and details.label ~= "" and (not details.source or sectionHasItems[details.source]) then
                rows[#rows + 1] = {
                    heading = true,
                    label = details.label,
                }
            elseif details.type == "category" then
                local count = #(details.results or {})
                if count > 0 then
                    rows[#rows + 1] = {
                        kind = "category",
                        source = details.source,
                        label = details.label or "",
                        count = count,
                        icon = details.icon or KT_BAGS_CATEGORY_ICONS[details.source] or KT_BAGS_CATEGORY_ICONS.default_other,
                        active = self.db.viewMode == "category" and self.selectedCategorySource == details.source,
                    }
                end
            end
            detailIndex = details.next
        end
    else
        local grouped = {}
        for _, key in ipairs(BAG_CATEGORY_ORDER) do grouped[key] = 0 end
        for _, slotData in ipairs(visibleSlots or {}) do
            local category = self:GetSlotCategory(slotData)
            grouped[category] = (grouped[category] or 0) + 1
        end
        for _, key in ipairs(BAG_CATEGORY_ORDER) do
            if (grouped[key] or 0) > 0 then
                rows[#rows + 1] = {
                    heading = false,
                    kind = "fallback",
                    label = key,
                    count = grouped[key],
                    icon = KT_BAGS_CATEGORY_ICONS.default_other,
                    active = false,
                }
            end
        end
    end

    local rowParent = window.KT_SidebarContent or window.KT_Sidebar
    local y = 0
    local rowIndex = 1
    for _, data in ipairs(rows) do
        local row = self:EnsureSidebarRow(window, rowIndex)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", rowParent, "TOPLEFT", 7, -y)
        row:SetPoint("TOPRIGHT", rowParent, "TOPRIGHT", -7, -y)
        row.KT_Active = data.active == true
        row.KT_Click = nil

        if data.heading then
            row:SetHeight(18)
            row:EnableMouse(false)
            row.KT_Icon:Hide()
            row.KT_Count:SetText("")
            row.KT_Label:ClearAllPoints()
            row.KT_Label:SetPoint("LEFT", row, "LEFT", 3, 0)
            row.KT_Label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.KT_Label:SetFont(KT_DEFAULT_FONT, 10, "OUTLINE")
            if row.KT_Label.SetWordWrap then row.KT_Label:SetWordWrap(false) end
            if row.KT_Label.SetNonSpaceWrap then row.KT_Label:SetNonSpaceWrap(false) end
            if row.KT_Label.SetMaxLines then row.KT_Label:SetMaxLines(1) end
            row.KT_Label:SetText(data.label)
            row.KT_Label:SetTextColor(0.60, 0.60, 0.66, 0.88)
            row:SetBackdropColor(0, 0, 0, 0)
            row:SetBackdropBorderColor(0, 0, 0, 0)
            if row.KT_Left then row.KT_Left:SetColorTexture(0, 0, 0, 0) end
            y = y + 18
        else
            row:SetHeight(KT_BAGS_SIDEBAR_ROW_HEIGHT)
            row:EnableMouse(true)
            row.KT_Icon:Show()
            row.KT_Label:ClearAllPoints()
            row.KT_Label:SetPoint("LEFT", row.KT_Icon, "RIGHT", 8, 0)
            row.KT_Label:SetPoint("RIGHT", row, "RIGHT", -38, 0)
            row.KT_Label:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
            if row.KT_Label.SetWordWrap then row.KT_Label:SetWordWrap(false) end
            if row.KT_Label.SetNonSpaceWrap then row.KT_Label:SetNonSpaceWrap(false) end
            if row.KT_Label.SetMaxLines then row.KT_Label:SetMaxLines(1) end
            row.KT_Label:SetText(data.label)
            row.KT_Count:SetText(tostring(data.count or 0))
            KT_Bags_SetIconTexture(row.KT_Icon, data.icon)
            row.KT_Click = function()
                self:SetSidebarSelection(data.kind, data.source)
            end
            self:ApplySidebarRowVisual(row, data.active == true, false)
            y = y + KT_BAGS_SIDEBAR_ROW_HEIGHT + 2
        end

        row:Show()
        rowIndex = rowIndex + 1
    end

    for index = rowIndex, #(window.KT_SidebarRows or {}) do
        window.KT_SidebarRows[index]:Hide()
    end

    if window.KT_SidebarContent then
        local contentWidth = window.KT_SidebarScrollFrame and window.KT_SidebarScrollFrame:GetWidth() or (KT_BAGS_SIDEBAR_WIDTH - 18)
        if contentWidth < 40 then
            contentWidth = KT_BAGS_SIDEBAR_WIDTH - 18
        end
        window.KT_SidebarContent:SetSize(math.max(1, contentWidth), math.max(1, y + 4))
        KT_Bags_UpdateScrollBar(window.KT_SidebarScrollFrame, window.KT_SidebarScrollBar, window.KT_SidebarContent)
    end
end

function Mod:PlaceCategoryHeaderLine(window, index, header, pad, yOffset, alpha)
    if not (window and window.KT_Grid and header) then
        return
    end

    self.categoryHeaderLines = self.categoryHeaderLines or {}
    local line = self.categoryHeaderLines[index]
    if not line then
        line = window.KT_Grid:CreateTexture(nil, "ARTWORK")
        line:SetTexture(KT_BAGS_WHITE8X8)
        self.categoryHeaderLines[index] = line
    end

    local ar, ag, ab = KT_Bags_GetAccentColor()
    line:ClearAllPoints()
    line:SetPoint("LEFT", header, "RIGHT", 8, -1)
    line:SetPoint("RIGHT", window.KT_Grid, "TOPRIGHT", -pad, -(yOffset + pad + 8))
    line:SetHeight(1)
    line:SetVertexColor(ar, ag, ab, alpha or 0.22)
    line:Show()
end

function Mod:ApplyNativeViewLayout(window, isCompact)
    if not (window and window.KT_Content and window.KT_GridPanel) then return end

    if window.KT_Sidebar then
        window.KT_Sidebar:SetShown(not isCompact)
    end

    window.KT_GridPanel:ClearAllPoints()
    if isCompact then
        window.KT_GridPanel:SetPoint("TOPLEFT", window.KT_Content, "TOPLEFT", 0, 0)
    else
        window.KT_GridPanel:SetPoint("TOPLEFT", window.KT_Sidebar, "TOPRIGHT", 8, 0)
    end
    window.KT_GridPanel:SetPoint("BOTTOMRIGHT", window.KT_Content, "BOTTOMRIGHT", 0, 0)

    if window.KT_GridScrollFrame then
        window.KT_GridScrollFrame:ClearAllPoints()
        window.KT_GridScrollFrame:SetPoint("TOPLEFT", window.KT_GridPanel, "TOPLEFT", 8, -30)
        window.KT_GridScrollFrame:SetPoint("BOTTOMRIGHT", window.KT_GridPanel, "BOTTOMRIGHT", isCompact and -8 or -22, 8)
        if isCompact then
            window.KT_GridScrollFrame:SetVerticalScroll(0)
        end
    end
    if isCompact and window.KT_GridScrollBar then
        window.KT_GridScrollBar:SetValue(0)
        window.KT_GridScrollBar:Hide()
    end
end

function Mod:FinalizeBagLayout(window, visibleSlots, columns, gridWidth, buttonIndex, offsetY, used, free, total, isCategoryView)
    for index = buttonIndex, #self.itemButtons do
        local btn = self.itemButtons[index]
        local anchor = btn and (btn.KT_Holder or btn)
        if anchor then
            anchor:Hide()
        end
        if btn then
            btn:Hide()
        end
    end

    local totalRows = math.max(1, math.ceil(#visibleSlots / columns))
    local itemSize = KT_Bags_GetConfiguredItemSize(self)
    local contentHeight = offsetY
    if not isCategoryView then
        contentHeight = totalRows * (itemSize + KT_ITEM_SPACING)
    end
    local paddedHeight = contentHeight + (KT_GRID_PADDING * 2)
    window.KT_Grid:SetSize(gridWidth, math.max(paddedHeight, 1))

    local minWindowHeight = self.db.window.height or KT_BAGS_WINDOW_HEIGHT
    local requiredHeight = math.ceil(paddedHeight + 162)
    local maxWindowHeight = math.max(minWindowHeight, math.floor(UIParent:GetHeight() * (isCategoryView and 0.72 or 0.92)))
    if isCategoryView then
        window:SetHeight(math.min(maxWindowHeight, math.max(minWindowHeight, requiredHeight)))
    else
        window:SetHeight(math.min(maxWindowHeight, math.max(310, requiredHeight)))
    end

    KT_Bags_UpdateScrollBar(window.KT_GridScrollFrame, window.KT_GridScrollBar, window.KT_Grid)
    if not isCategoryView and window.KT_GridScrollBar then
        -- Compact mode is a combined-backpack grid, not a scrolling category
        -- browser. Its frame grows to the rows it needs.
        window.KT_GridScrollBar:SetValue(0)
        window.KT_GridScrollBar:Hide()
        window.KT_GridScrollFrame:SetVerticalScroll(0)
    end

    if self.searchText ~= "" then
        window.KT_GridHeader:SetText(format(LText("BAGS_BACKPACK_MATCHES", "Backpack (%d matches)"), #visibleSlots))
    elseif isCategoryView then
        window.KT_GridHeader:SetText(LText("BAGS_BACKPACK_CATEGORIES", "Backpack Categories"))
    elseif self:ShouldShowCompactEmptySlots() then
        window.KT_GridHeader:SetText(format(LText("BAGS_BACKPACK_SLOTS_VIEW", "Backpack (%d slots)"), #visibleSlots))
    else
        window.KT_GridHeader:SetText(format(LText("BAGS_BACKPACK_ITEMS", "Backpack (%d items)"), #visibleSlots))
    end

    self:RefreshSidePanel(used, free, total)
end

function Mod:RenderCategoryLayout(window, composed, visibleSlots, columns, gridWidth, used, free, total)
    self:RefreshCategorySidebar(window, composed, visibleSlots, used, total)

    local buttonIndex = 1
    local offsetY = 0
    local usedHeaders = 0
    local headerIndex = 1
    local pad = KT_GRID_PADDING
    local itemSize = KT_Bags_GetConfiguredItemSize(self)
    local renderedAny = false
    local pendingDivider = false
    local selectedSource = self.selectedCategorySource

    -- Sections ("EQUIPMENT", "CRAFTING", etc.) are metadata in the display order and
    -- can exist even when no category under them has results. Hide those empty
    -- section headers to avoid showing a bunch of blank titles.
    local sectionHasItems = {}
    for _, d in ipairs(composed.details or {}) do
        if d.type == "category" then
            local group = d.results or {}
            if #group > 0 and (not selectedSource or d.source == selectedSource) and type(d.section) == "table" then
                for _, sec in ipairs(d.section) do
                    sectionHasItems[sec] = true
                end
            end
        end
    end

    local function ApplyPendingDivider()
        if renderedAny and pendingDivider then
            offsetY = offsetY + 12
        end
        pendingDivider = false
    end

    local detailIndex = composed.start or 1
    while detailIndex do
        local details = composed.details[detailIndex]
        if not details then
            break
        end
        if details.type == "divider" then
            -- Only apply divider spacing if we actually render something after it.
            pendingDivider = true
        elseif details.type == "section" then
            if not selectedSource and (not details.source or sectionHasItems[details.source]) then
                ApplyPendingDivider()
                local header = self.categoryHeaders[headerIndex]
                if not header then
                    header = window.KT_Grid:CreateFontString(nil, "OVERLAY")
                    header:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
                    do
                        local ar, ag, ab = KT_Bags_GetAccentTextColor(0.96, 0.12)
                        header:SetTextColor(ar, ag, ab, 0.92)
                    end
                    self.categoryHeaders[headerIndex] = header
                else
                    local ar, ag, ab = KT_Bags_GetAccentTextColor(0.96, 0.12)
                    header:SetTextColor(ar, ag, ab, 0.92)
                end
                header:SetFont(KT_DEFAULT_FONT, 12, "OUTLINE")
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", window.KT_Grid, "TOPLEFT", pad, -(offsetY + pad))
                header:SetText(details.label or "")
                header:Show()
                self:PlaceCategoryHeaderLine(window, headerIndex, header, pad, offsetY, 0.12)
                offsetY = offsetY + 18
                headerIndex = headerIndex + 1
                usedHeaders = usedHeaders + 1
                renderedAny = true
            end
        elseif details.type == "category" then
            local group = details.results or {}
            if #group > 0 and (not selectedSource or details.source == selectedSource) then
                ApplyPendingDivider()
                sort(group, function(a, b)
                    return (a.itemName or a.itemLink or "") < (b.itemName or b.itemLink or "")
                end)

                local header = self.categoryHeaders[headerIndex]
                if not header then
                    header = window.KT_Grid:CreateFontString(nil, "OVERLAY")
                    header:SetFont(KT_DEFAULT_FONT, 14, "OUTLINE")
                    do
                        local ar, ag, ab = KT_Bags_GetAccentTextColor(1, 0.22)
                        header:SetTextColor(ar, ag, ab, 1)
                    end
                    self.categoryHeaders[headerIndex] = header
                else
                    local ar, ag, ab = KT_Bags_GetAccentTextColor(1, 0.22)
                    header:SetTextColor(ar, ag, ab, 1)
                end
                header:SetFont(KT_DEFAULT_FONT, 14, "OUTLINE")
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", window.KT_Grid, "TOPLEFT", pad, -(offsetY + pad))
                header:SetText(details.label or "")
                header:Show()
                self:PlaceCategoryHeaderLine(window, headerIndex, header, pad, offsetY, 0.24)
                offsetY = offsetY + 22

                for groupIndex, slotData in ipairs(group) do
                    local button = self:EnsureItemButton(buttonIndex)
                    local anchor = button.KT_Holder or button
                    local row = math.floor((groupIndex - 1) / columns)
                    local column = (groupIndex - 1) % columns
                    anchor:ClearAllPoints()
                    anchor:SetPoint(
                        "TOPLEFT",
                        window.KT_Grid,
                        "TOPLEFT",
                        pad + (column * (itemSize + KT_ITEM_SPACING)),
                        -(offsetY + row * (itemSize + KT_ITEM_SPACING) + pad)
                    )
                    anchor:Show()
                    button:Show()
                    self:UpdateItemButton(button, slotData)
                    buttonIndex = buttonIndex + 1
                end

                offsetY = offsetY + (math.ceil(#group / columns) * (itemSize + KT_ITEM_SPACING)) + 10
                headerIndex = headerIndex + 1
                usedHeaders = usedHeaders + 1
                renderedAny = true
            end
        end
        detailIndex = details.next
    end

    for index = 1, #self.categoryHeaders do
        if index > usedHeaders then
            self.categoryHeaders[index]:Hide()
        end
    end
    for index = 1, #(self.categoryHeaderLines or {}) do
        if index > usedHeaders then
            self.categoryHeaderLines[index]:Hide()
        end
    end

    self:FinalizeBagLayout(window, visibleSlots, columns, gridWidth, buttonIndex, offsetY, used, free, total, true)
end

function Mod:RenderFallbackCategoryLayout(window, visibleSlots, columns, gridWidth, used, free, total)
    self:RefreshCategorySidebar(window, nil, visibleSlots, used, total)

    local buttonIndex = 1
    local offsetY = 0
    local usedHeaders = 0
    local pad = KT_GRID_PADDING
    local itemSize = KT_Bags_GetConfiguredItemSize(self)

    sort(visibleSlots, function(a, b)
        local aCategory = self:GetSlotCategory(a)
        local bCategory = self:GetSlotCategory(b)
        if aCategory ~= bCategory then
            return aCategory < bCategory
        end
        return (a.itemName or a.itemLink or "") < (b.itemName or b.itemLink or "")
    end)

    local grouped = {}
    for _, key in ipairs(BAG_CATEGORY_ORDER) do
        grouped[key] = {}
    end
    for _, slotData in ipairs(visibleSlots) do
        local category = self:GetSlotCategory(slotData)
        grouped[category] = grouped[category] or {}
        tinsert(grouped[category], slotData)
    end

    local headerIndex = 1
    for _, category in ipairs(BAG_CATEGORY_ORDER) do
        local group = grouped[category]
        if group and #group > 0 then
            local header = self.categoryHeaders[headerIndex]
            if not header then
                header = window.KT_Grid:CreateFontString(nil, "OVERLAY")
                header:SetFont(KT_DEFAULT_FONT, 14, "OUTLINE")
                do
                    local ar, ag, ab = KT_Bags_GetAccentTextColor(1, 0.22)
                    header:SetTextColor(ar, ag, ab, 1)
                end
                self.categoryHeaders[headerIndex] = header
            end
            do
                local ar, ag, ab = KT_Bags_GetAccentTextColor(1, 0.22)
                header:SetTextColor(ar, ag, ab, 1)
            end
            header:SetFont(KT_DEFAULT_FONT, 14, "OUTLINE")
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", window.KT_Grid, "TOPLEFT", pad, -(offsetY + pad))
            header:SetText(category)
            header:Show()
            self:PlaceCategoryHeaderLine(window, headerIndex, header, pad, offsetY, 0.24)
            offsetY = offsetY + 22

            for groupIndex, slotData in ipairs(group) do
                local button = self:EnsureItemButton(buttonIndex)
                local anchor = button.KT_Holder or button
                local row = math.floor((groupIndex - 1) / columns)
                local column = (groupIndex - 1) % columns
                anchor:ClearAllPoints()
                    anchor:SetPoint(
                        "TOPLEFT",
                        window.KT_Grid,
                        "TOPLEFT",
                        pad + (column * (itemSize + KT_ITEM_SPACING)),
                        -(offsetY + row * (itemSize + KT_ITEM_SPACING) + pad)
                    )
                anchor:Show()
                button:Show()
                self:UpdateItemButton(button, slotData)
                buttonIndex = buttonIndex + 1
            end

            offsetY = offsetY + (math.ceil(#group / columns) * (itemSize + KT_ITEM_SPACING)) + 10
            headerIndex = headerIndex + 1
            usedHeaders = usedHeaders + 1
        end
    end

    for index = 1, #self.categoryHeaders do
        if index > usedHeaders then
            self.categoryHeaders[index]:Hide()
        end
    end
    for index = 1, #(self.categoryHeaderLines or {}) do
        if index > usedHeaders then
            self.categoryHeaderLines[index]:Hide()
        end
    end

    self:FinalizeBagLayout(window, visibleSlots, columns, gridWidth, buttonIndex, offsetY, used, free, total, true)
end

function Mod:RenderCompactLayout(window, visibleSlots, columns, gridWidth, used, free, total)
    self:RefreshCategorySidebar(window, nil, visibleSlots, used, total)

    local buttonIndex = 1
    local pad = KT_GRID_PADDING
    local itemSize = KT_Bags_GetConfiguredItemSize(self)
    for index, slotData in ipairs(visibleSlots) do
        local button = self:EnsureItemButton(index)
        local anchor = button.KT_Holder or button
        local row = math.floor((index - 1) / columns)
        local column = (index - 1) % columns

        anchor:ClearAllPoints()
        anchor:SetPoint(
            "TOPLEFT",
            window.KT_Grid,
            "TOPLEFT",
            pad + (column * (itemSize + KT_ITEM_SPACING)),
            -(pad + (row * (itemSize + KT_ITEM_SPACING)))
        )
        anchor:Show()
        button:Show()
        self:UpdateItemButton(button, slotData)
        buttonIndex = index + 1
    end

    for _, header in ipairs(self.categoryHeaders) do
        header:Hide()
    end
    for _, line in ipairs(self.categoryHeaderLines or {}) do
        line:Hide()
    end

    self:FinalizeBagLayout(window, visibleSlots, columns, gridWidth, buttonIndex, 0, used, free, total, false)
end

--- Refresh the native backpack grid from live container contents.
-- @return nil
function Mod:RefreshBagSlots()
    self.bagRefreshPending = nil
    local window = self:CreateNativeWindow()
    local isCompact = self.db.viewMode == "compact"
    self:ApplyNativeViewLayout(window, isCompact)
    local slots, used, free, total = self:CollectBagSlots()
    local visibleSlots = {}
    local selectedBagID = self.selectedBagID
    if selectedBagID then
        used, free, total = 0, 0, 0
        for _, slotData in ipairs(slots) do
            if slotData.bagID == selectedBagID then
                total = total + 1
                if slotData.itemInfo or slotData.itemLink then
                    used = used + 1
                else
                    free = free + 1
                end
            end
        end
    end
    self.categoryLayoutRequestID = (self.categoryLayoutRequestID or 0) + 1
    local requestID = self.categoryLayoutRequestID
    local viewWidth = 0
    if window.KT_GridScrollFrame then
        viewWidth = math.floor(window.KT_GridScrollFrame:GetWidth() or 0)
    end
    if viewWidth <= 0 and window.KT_GridPanel then
        viewWidth = math.floor((window.KT_GridPanel:GetWidth() or 0) - 36)
    end
    viewWidth = math.max(viewWidth, 360)
    local itemSize = KT_Bags_GetConfiguredItemSize(self)
    local columns = math.max(6, math.floor((viewWidth + KT_ITEM_SPACING) / (itemSize + KT_ITEM_SPACING)))
    if isCompact then
        columns = math.max(columns, 12)
    end
    local gridWidth = math.max(1, (columns * (itemSize + KT_ITEM_SPACING)) - KT_ITEM_SPACING + (KT_GRID_PADDING * 2))

    self.categoryHeaders = self.categoryHeaders or {}

    for _, slotData in ipairs(slots) do
        if (not selectedBagID or slotData.bagID == selectedBagID) and self:ShouldDisplaySlot(slotData) then
            tinsert(visibleSlots, slotData)
        end
    end

    if self.selectedSpecialView == "watched" then
        local watchedSlots = {}
        for _, slotData in ipairs(visibleSlots) do
            if self:IsWatchedItem(slotData.itemLink) then
                watchedSlots[#watchedSlots + 1] = slotData
            end
        end
        visibleSlots = watchedSlots
    end

    if isCompact and #visibleSlots > 0 then
        local availableHeight = math.max(1, math.floor(UIParent:GetHeight() * 0.92) - 162 - (KT_GRID_PADDING * 2))
        local maxRows = math.max(1, math.floor(availableHeight / (itemSize + KT_ITEM_SPACING)))
        columns = math.max(columns, math.ceil(#visibleSlots / maxRows))
        gridWidth = math.max(1, (columns * (itemSize + KT_ITEM_SPACING)) - KT_ITEM_SPACING + (KT_GRID_PADDING * 2))
    end

    self:RefreshBackgroundDropTarget()

    if self.db.viewMode == "category" then
        local composed = self:BuildBaganatorCategoryLayout(visibleSlots)
        if composed then
            local function render()
                if self.categoryLayoutRequestID ~= requestID then
                    return
                end
                self:RenderCategoryLayout(window, composed, visibleSlots, columns, gridWidth, used, free, total)
            end

            if self:ApplyBaganatorCategoryFilters(composed, visibleSlots, render) then
                return
            end

            KT_Bags_ApplyCategorySearches(composed, visibleSlots)
            render()
        else
            if self.baganatorCategoryFilter then
                self.baganatorCategoryFilter:Cancel()
            end
            self:RenderFallbackCategoryLayout(window, visibleSlots, columns, gridWidth, used, free, total)
        end
    else
        if self.baganatorCategoryFilter then
            self.baganatorCategoryFilter:Cancel()
        end
        self:RenderCompactLayout(window, visibleSlots, columns, gridWidth, used, free, total)
    end
end

--- Create the watched-item corner marker frame for a Baganator item button.
-- @param itemButton Button Baganator item button.
-- @return Frame Corner frame attached to the item button.
function Mod:CreateCornerWidget(itemButton)
    local cornerFrame = CreateFrame("Frame", nil, itemButton)
    cornerFrame:SetSize(14, 14)
    cornerFrame:SetPoint("TOPLEFT", itemButton, "TOPLEFT", 1, -1)

    local label = cornerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", cornerFrame, "TOPLEFT", 0, 0)
    label:SetTextColor(1.0, 0.82, 0.0, 1.0)
    label:SetText("")
    cornerFrame.KT_Label = label

    return cornerFrame
end

--- Protected corner init callback passed to Baganator.
-- @param itemButton Button Baganator item button.
-- @return Frame|nil Corner frame for the item button.
function Mod:CornerInit(itemButton)
    local ok, frame = KT_SafeCallback(function()
        return self:CreateCornerWidget(itemButton)
    end)
    if ok then
        return frame
    end
    return nil
end

--- Update the watched-item marker based on the module-owned watch list.
-- @param cornerFrame Frame Corner frame created during initialization.
-- @param itemDetails table Item details supplied by Baganator.
-- @return boolean True to show the widget, false to hide it.
function Mod:UpdateCornerWidget(cornerFrame, itemDetails)
    if not cornerFrame or type(itemDetails) ~= "table" then
        return false
    end

    if self:IsWatchedItem(itemDetails.itemLink) then
        cornerFrame.KT_Label:SetText(KT_WATCH_ICON)
        return true
    end

    cornerFrame.KT_Label:SetText("")
    return false
end

--- Protected corner update callback passed to Baganator.
-- @param cornerFrame Frame Corner frame created during initialization.
-- @param itemDetails table Item details supplied by Baganator.
-- @return boolean|nil Visibility hint for Baganator.
function Mod:CornerUpdate(cornerFrame, itemDetails)
    local ok, shouldShow = KT_SafeCallback(function()
        return self:UpdateCornerWidget(cornerFrame, itemDetails)
    end)
    if ok then
        return shouldShow
    end
    return nil
end

--- Extract the quest ID from a live bag slot using Blizzard container APIs.
-- @param bagID number Bag identifier provided by Baganator.
-- @param slotID number Slot identifier provided by Baganator.
-- @return number|nil Quest ID when available.
function Mod:GetContainerQuestID(bagID, slotID)
    if not C_Container or not C_Container.GetContainerItemQuestInfo then
        return nil
    end

    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID)
    if type(questInfo) == "table" then
        return questInfo.questID
    end

    return questInfo
end

--- Mark completed quest items as junk through Baganator's junk plugin API.
-- @param bagID number Bag identifier.
-- @param slotID number Slot identifier.
-- @param itemID number Item ID.
-- @param itemLink string|nil Full item link.
-- @return boolean|nil True when the item should be marked as junk.
function Mod:QuestJunkCallback(bagID, slotID, itemID, itemLink)
    local _, _, _, _, _, classID = GetItemInfoInstant(itemLink or itemID or 0)
    if classID ~= LE_ITEM_CLASS_QUESTITEM then
        return false
    end

    local questID = self:GetContainerQuestID(bagID, slotID)
    if not questID then
        return false
    end

    return C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end

--- Protected junk plugin callback passed to Baganator.
-- @param bagID number Bag identifier.
-- @param slotID number Slot identifier.
-- @param itemID number Item ID.
-- @param itemLink string|nil Full item link.
-- @return boolean|nil True when the item should be marked as junk.
function Mod:ProtectedQuestJunkCallback(bagID, slotID, itemID, itemLink)
    local ok, isJunk = KT_SafeCallback(function()
        return self:QuestJunkCallback(bagID, slotID, itemID, itemLink)
    end)
    if ok then
        return isJunk
    end
    return nil
end

--- Create or update a KullThranUI border overlay for a Baganator item button.
-- @param itemButton Frame Item button region skinned by Baganator.
-- @return nil
function Mod:ApplyItemButtonBorder(itemButton)
    if itemButton and itemButton.KT_BagsBrandBorder then
        itemButton.KT_BagsBrandBorder:Hide()
    end
end

--- Apply the KullThranUI brand border only when the Blizzard Baganator skin is active.
-- @param details table Skin listener payload from Baganator.
-- @return nil
function Mod:SkinListener(details)
    if type(details) ~= "table" or details.regionType ~= "ItemButton" or not details.region then
        return
    end

    if details.region.KT_BagsBrandBorder then
        details.region.KT_BagsBrandBorder:Hide()
    end
end

--- Protected skin listener callback passed to Baganator.
-- @param details table Skin listener payload from Baganator.
-- @return nil
function Mod:ProtectedSkinListener(details)
    KT_SafeCallback(function()
        self:SkinListener(details)
    end)
end

--- Register the native bags window with KullThranUI Edit Mode.
-- @return nil
function Mod:RegisterWithEditMode()
    if self.editModeRegistered then
        return
    end

    local EM = KT:GetModule("EditMode", true)
    local window = _G.KT_BagsWindow
    if not EM or not window then
        return
    end

    local function RaiseHeaderButtonsAboveOverlay()
        local reg = EM.RegisteredFrames and EM.RegisteredFrames[window]
        local overlay = reg and reg.overlay
        if overlay and overlay.GetFrameLevel then
            local topLevel = (overlay:GetFrameLevel() or 0) + 20
            for _, btn in ipairs({ window.KT_CloseButton, window.KT_ModeButton }) do
                if btn and btn.SetFrameStrata and btn.SetFrameLevel then
                    if not btn.KT_OrigStrata then
                        btn.KT_OrigStrata = btn:GetFrameStrata()
                        btn.KT_OrigLevel = btn:GetFrameLevel()
                    end
                    -- Ensure these remain clickable even when the EditMode overlay is shown.
                    btn:SetFrameStrata("DIALOG")
                    btn:SetFrameLevel(topLevel)
                end
            end
        end
    end

    local function PositionOverlay()
        local reg = EM.RegisteredFrames and EM.RegisteredFrames[window]
        local overlay = reg and reg.overlay
        local header = window.KT_Header
        local stopBefore = window.KT_ModeButton or window.KT_CloseButton
        if not overlay or not header then
            return
        end

        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
        overlay:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
        if stopBefore then
            overlay:SetPoint("TOPRIGHT", stopBefore, "TOPLEFT", -6, 0)
            overlay:SetPoint("BOTTOMRIGHT", stopBefore, "BOTTOMLEFT", -6, 0)
        else
            overlay:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
            overlay:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
        end
    end

    local function RestoreHeaderButtons()
        for _, btn in ipairs({ window.KT_CloseButton, window.KT_ModeButton }) do
            if btn and btn.KT_OrigStrata and btn.SetFrameStrata then
                btn:SetFrameStrata(btn.KT_OrigStrata)
                btn.KT_OrigStrata = nil
            end
            if btn and btn.KT_OrigLevel and btn.SetFrameLevel then
                btn:SetFrameLevel(btn.KT_OrigLevel)
                btn.KT_OrigLevel = nil
            end
        end
    end

    EM:RegisterFrame(window, LText("BAGS_TITLE", "Bags"), KT_BAGS_DB_KEY, {
        resizable = false,
        onEnter = function()
            window:SetAlpha(1)
            -- Do not force-open bags when entering EditMode.
            -- If the user opens the bags while EditMode is active, our OnShow hook
            -- below will show the overlay and allow moving.
            if window:IsShown() then
                PositionOverlay()
                RaiseHeaderButtonsAboveOverlay()
            end
        end,
        onExit = function()
            RestoreHeaderButtons()

            if self.db.window.visible == false then
                window:Hide()
            end
        end,
        onDragStop = function()
            self.db.window.visible = window:IsShown()
        end,
    })
    PositionOverlay()

    -- If the bags are opened while EditMode is already active, show/hide the overlay
    -- and keep the close button clickable.
    if not window.KT_EditModeVisHooked and window.HookScript then
        window.KT_EditModeVisHooked = true
        window:HookScript("OnShow", function()
            if _G.EditModeManagerFrame and _G.EditModeManagerFrame.IsEditModeActive and _G.EditModeManagerFrame:IsEditModeActive() then
                local reg = EM.RegisteredFrames and EM.RegisteredFrames[window]
                if reg and reg.overlay then
                    PositionOverlay()
                    reg.overlay:Show()
                end
                pcall(window.SetMovable, window, true)
                RaiseHeaderButtonsAboveOverlay()
            end
        end)
        window:HookScript("OnHide", function()
            local reg = EM.RegisteredFrames and EM.RegisteredFrames[window]
            if reg and reg.overlay then
                reg.overlay:Hide()
            end
        end)
    end

    self.editModeRegistered = true
end

--- Register the native bags window with KullThranUI Unlock Mode.
-- @return nil
function Mod:RegisterWithUnlockMode()
    if self.unlockRegistered or not _G.KT_BagsWindow then
        return
    end

    KT.RegisterUnlockElement(KT_BAGS_DB_KEY, {
        label = "Bags",
        group = "Other",
        order = 121,
        getFrame = function()
            return _G.KT_BagsWindow
        end,
        getSize = function()
            return _G.KT_BagsWindow:GetWidth(), _G.KT_BagsWindow:GetHeight()
        end,
        getScale = function()
            return _G.KT_BagsWindow:GetScale()
        end,
        loadPosition = function()
            local saved = KT.db.profile.editMode
                and KT.db.profile.editMode.frames
                and KT.db.profile.editMode.frames[KT_BAGS_DB_KEY]
            if saved and saved.point then
                return saved
            end
            return nil
        end,
        savePosition = function(_, pt, rpt, x, y)
            KT.db.profile.editMode = KT.db.profile.editMode or {}
            KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}
            KT.db.profile.editMode.frames[KT_BAGS_DB_KEY] = {
                point = pt,
                relativePoint = rpt,
                x = x,
                y = y,
                scale = _G.KT_BagsWindow:GetScale(),
            }
        end,
        applyPosition = function()
            local saved = KT.db.profile.editMode
                and KT.db.profile.editMode.frames
                and KT.db.profile.editMode.frames[KT_BAGS_DB_KEY]
            if saved and saved.point then
                _G.KT_BagsWindow:ClearAllPoints()
                _G.KT_BagsWindow:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
            end
        end,
        unlockClose = function()
            if _G.KT_BagsWindow and _G.KT_BagsWindow.Hide then
                _G.KT_BagsWindow:Hide()
            end
        end,
    })

    self.unlockRegistered = true
end

--- Register the temporary Baganator bridge through the public API.
-- @return nil
function Mod:RegisterBaganatorBridge()
    local api = KT_IsBaganatorActive()
    if not api or self.bridgeRegistered or not KT_IsBaganatorCompatible() then
        return
    end

    api.RegisterRegion("KullThranUI", "kullthran_panel", "backpack", "bottom_left", self:EnsureBagsPanel())
    api.RegisterCornerWidget(
        "KullThran Watched Items",
        "kullthran_watched_items",
        function(cornerFrame, itemDetails)
            return self:CornerUpdate(cornerFrame, itemDetails)
        end,
        function(itemButton)
            return self:CornerInit(itemButton)
        end,
        { corner = "top_left", priority = 3 },
        false
    )
    api.RegisterJunkPlugin(
        "KullThran Quest Items",
        "kullthran_quest_junk",
        function(bagID, slotID, itemID, itemLink)
            return self:ProtectedQuestJunkCallback(bagID, slotID, itemID, itemLink)
        end
    )
    api.Skins.RegisterListener(function(details)
        self:ProtectedSkinListener(details)
    end)

    self.bridgeRegistered = true
    self:RefreshBagSlots()
end

--- Query item inventory data through Baganator's Syndicator-backed public API.
-- @param itemLink string Full item link to inspect.
-- @return table|nil Inventory information, or nil when Baganator is unavailable.
function Mod:GetItemInventory(itemLink)
    local api = KT_IsBaganatorActive()
    self.lastInventoryQuery = itemLink or "none"
    if not api or not C_AddOns.IsAddOnLoaded("Syndicator") then
        self.lastInventoryInfo = nil
        self:RefreshBagSlots()
        return nil
    end

    local ok, inventoryInfo = KT_SafeCallback(api.GetInventoryInfo, itemLink, false, false)
    if ok then
        self.lastInventoryInfo = inventoryInfo
        self:RefreshBagSlots()
        return inventoryInfo
    end

    self.lastInventoryInfo = nil
    self:RefreshBagSlots()
    return nil
end
