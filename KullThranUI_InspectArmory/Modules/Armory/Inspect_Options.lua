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

KT:RegisterPage("inspectarmory", "Inspect Armory", 57, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.inspectArmory
    if not db then
        KT.db.profile.inspectArmory = KT.db.profile.inspectArmory or {}
        db = KT.db.profile.inspectArmory
    end

    -- Live preview (as in the last functional version): inspect text typography.
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

    local prevContainer = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, 132)
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    if KT.AddBackdrop then KT:AddBackdrop(prevContainer, 0.1, 0.1, 0.1, 0.4) end
    if KT.AddBorder then KT:AddBorder(prevContainer, 0, 0, 0, 1) end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(prevContainer, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
    end

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 12, -10)
    lblPrev:SetText(LText("LIVE PREVIEW (INSPECT TEXT)"))
    KT:SetAccentTextColor(lblPrev, 1)

    local previewLabel = prevContainer:CreateFontString(nil, "OVERLAY")
    previewLabel:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 12, -30)
    previewLabel:SetJustifyH("LEFT")

    local previewValue = prevContainer:CreateFontString(nil, "OVERLAY")
    previewValue:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -4)
    previewValue:SetJustifyH("LEFT")

    local previewIlvl = prevContainer:CreateFontString(nil, "OVERLAY")
    previewIlvl:SetPoint("TOPRIGHT", prevContainer, "TOPRIGHT", -12, -30)
    previewIlvl:SetJustifyH("RIGHT")

    local previewEnchant = prevContainer:CreateFontString(nil, "OVERLAY")
    previewEnchant:SetPoint("BOTTOMLEFT", prevContainer, "BOTTOMLEFT", 12, 10)
    previewEnchant:SetJustifyH("LEFT")

    local previewStat = prevContainer:CreateFontString(nil, "OVERLAY")
    previewStat:SetPoint("BOTTOMRIGHT", prevContainer, "BOTTOMRIGHT", -12, 10)
    previewStat:SetJustifyH("RIGHT")

    local function UpdatePreview()
        local labelFont = FetchFont(db.avgIlvlLabelFont or db.statFont)
        previewLabel:SetFont(labelFont, db.avgIlvlLabelSize or 10, db.avgIlvlLabelOutline or "OUTLINE")
        local labelColor = db.avgIlvlLabelColor or { r = 1, g = 1, b = 1, a = 1 }
        previewLabel:SetTextColor(labelColor.r, labelColor.g, labelColor.b, labelColor.a or 1)
        previewLabel:SetText(LText("Average iLvl"))

        local valueFont = FetchFont(db.avgIlvlFont or db.statFont)
        previewValue:SetFont(valueFont, db.avgIlvlSize or 20, db.avgIlvlOutline or "OUTLINE")
        local valueColor = db.avgIlvlColor or { r = 1, g = 0.82, b = 0, a = 1 }
        previewValue:SetTextColor(valueColor.r, valueColor.g, valueColor.b, valueColor.a or 1)
        previewValue:SetText((db.avgIlvlDecimals == true) and "489.3" or "489")

        local ilvlFont = FetchFont(db.ilvlFont or db.statFont)
        previewIlvl:SetFont(ilvlFont, db.ilvlSize or 12, db.ilvlOutline or "OUTLINE")
        previewIlvl:SetText(LText("iLvl: 489"))

        local enchFont = FetchFont(db.enchantFont or db.statFont)
        previewEnchant:SetFont(enchFont, db.enchantSize or 10, "OUTLINE")
        local enchColor = db.enchantColor or { r = 0, g = 1, b = 0, a = 1 }
        previewEnchant:SetTextColor(enchColor.r, enchColor.g, enchColor.b, enchColor.a or 1)
        previewEnchant:SetText(LText("Enchant: Sophic Devotion"))

        local statFont = FetchFont(db.statFont or db.avgIlvlFont)
        previewStat:SetFont(statFont, db.statFontSize or 12, "OUTLINE")
        local statColor = db.attrColor or { r = 1, g = 1, b = 1, a = 1 }
        previewStat:SetTextColor(statColor.r, statColor.g, statColor.b, statColor.a or 1)
        previewStat:SetText(LText("Agility: 12345"))
    end

    local function RefreshAndPreview()
        RefreshInspect()
        UpdatePreview()
    end

    UpdatePreview()
    y = y + 152

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
            function(v) db.backgroundType = v; RefreshInspect() end); by = by + h
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
            function(v) db.ilvlColorByRarity = v; RefreshInspect() end); by = by + h
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
