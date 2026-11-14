-- Modules//Bags//Bags_Options.lua
-- Options page: bags

-- Auto-generated from Options.lua
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local LTextFmt = Opt.LTextFmt or function(t, ...) return string.format(t, ...) end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local ResetConfirm = Opt.ResetConfirm or function() StaticPopup_Show("KULLTHRANUI_RESET_CONFIRM") end

local GetFontValues = Opt.GetFontValues
local GetStatusbarValues = Opt.GetStatusbarValues
local GetBackgroundValues = Opt.GetBackgroundValues

local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks

local AddPageSubTabBar = KT.AddOptionsSubTabBar

KT:RegisterPage("bags", "Bags", 73, function(sc, W)
    local y, h = 0, 0
    local db = KT.db.profile.bags or {}
    KT.db.profile.skin = KT.db.profile.skin or {}
    local skin = KT.db.profile.skin
    db.window = db.window or {}
    db.panelColor = db.panelColor or { r = 0.2, g = 0.0980392157, b = 0.0, a = 0.94 }
    db.currency = db.currency or {}
    skin.bagsColorMode = skin.bagsColorMode or "accent"
    if db.lockPosition == nil then db.lockPosition = false end
    if db.showItemLevel == nil then db.showItemLevel = true end
    db.itemSize = db.itemSize or 36
    db.columns = db.columns or 12
    if db.itemLevelColorByRarity == nil then db.itemLevelColorByRarity = true end
    if db.currency.show == nil then db.currency.show = true end
    if db.currency.showGold == nil then db.currency.showGold = true end
    db.currency.mode = db.currency.mode or "backpack"
    db.currency.max = db.currency.max or 3
    db.currency.spacing = db.currency.spacing or 10
    db.currency.customList = db.currency.customList or ""
    if db.currency.clickOpensTokenFrame == nil then db.currency.clickOpensTokenFrame = true end
    if db.currency.rightClickUntracks == nil then db.currency.rightClickUntracks = true end

    local preview
    -- Where each part of the live preview leads (Bags_Preview.lua keys).
    local targets = {}
    local function Refresh()
        local M = KT:GetModule("Bags", true)
        if M and M.OnProfileUpdate then
            M:OnProfileUpdate()
        end
        if preview then preview:Refresh() end
    end

    local function GetThemeAccent()
        if KT and KT.GetStyleAccentRGB then
            local r, g, b = KT:GetStyleAccentRGB()
            return r or KT.C_R or 1, g or KT.C_G or 0, b or KT.C_B or 0.333
        end
        return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333
    end

    -- Scrolls the page to an option and flashes it in the accent colour.
    local function JumpTo(target)
        local menu = KT.MenuPrincipal
        local sf = KT._scrollFrame or (menu and menu.scrollFrame)
        local child = sf and sf.GetScrollChild and sf:GetScrollChild()
        local top, childTop = target and target:GetTop(), child and child:GetTop()
        if top and childTop then
            local pos = math.max(0, (childTop - top) - 40)
            if KT.SmoothScrollTo then
                KT.SmoothScrollTo(pos)
            elseif sf.SetVerticalScroll then
                sf:SetVerticalScroll(pos)
            end
        end
        if not target.KT_JumpFlash then
            local flash = target:CreateTexture(nil, "OVERLAY")
            flash:SetAllPoints()
            flash:SetTexture("Interface\\Buttons\\WHITE8X8")
            flash:SetBlendMode("ADD")
            local anim = flash:CreateAnimationGroup()
            local fadeIn = anim:CreateAnimation("Alpha")
            fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.15); fadeIn:SetOrder(1)
            local fadeOut = anim:CreateAnimation("Alpha")
            fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(0.7); fadeOut:SetOrder(2)
            anim:SetScript("OnPlay", function() flash:Show() end)
            anim:SetScript("OnFinished", function() flash:Hide() end)
            flash:Hide()
            target.KT_JumpFlash, target.KT_JumpAnim = flash, anim
        end
        local r, g, b = GetThemeAccent()
        target.KT_JumpFlash:SetVertexColor(r, g, b, 0.35)
        target.KT_JumpAnim:Stop()
        target.KT_JumpAnim:Play()
    end

    -- Live preview: the bag window with your items, painted by the module's
    -- own code (Bags_Preview.lua); it follows the style cards and the options
    -- below, and a click on any part of it leads to its option.
    do
        local M = KT:GetModule("Bags", true)
        if M and M.CreateOptionsPreview then
            preview = M:CreateOptionsPreview(sc, math.max(280, (sc:GetWidth() or 600) - 20))
            preview:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -(y + 10))
            y = y + 10 + preview:GetHeight() + 14
            if preview.SetJumpHandler then
                preview:SetJumpHandler(function(key)
                    if targets[key] then JumpTo(targets[key]) end
                end)
            end
        end
    end

    -- Style cards, as on the Chat and Cast Bar pages: the bag window's frame
    -- for the current Visual Style, applied as soon as a card is picked.
    do
        local anchor = CreateFrame("Frame", nil, sc)
        anchor:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
        anchor:SetPoint("RIGHT", sc, "RIGHT", -10, 0)
        anchor:SetHeight(110)
        targets.style = anchor
    end
    if KT.VisualThemes and KT.VisualThemes.AddStyleCards then
        y = KT.VisualThemes:AddStyleCards(sc, y, LText("Bags Style"), db, function()
            local M = KT:GetModule("Bags", true)
            if M and M.ApplyPanelColor then M:ApplyPanelColor() end
            if preview then preview:Refresh() end
        end)
    end

    local cols = BeginOptionBlocks(sc, y)

    targets.general = AddOptionBlock(cols, "left", "General", function(container)
        local by = 0
        targets.enable, h = W:Toggle(container, "Enable Module", -by, function() return db.enable end, function(v) db.enable = v; Reload() end); by = by + h
        targets.viewMode, h = W:Dropdown(container, "View Mode", -by,
            { compact = "Compact", category = "Category" },
            function() return db.viewMode or "category" end,
            function(v) db.viewMode = v; Refresh() end); by = by + h
        _, h = W:Toggle(container, "Lock Position", -by,
            function() return db.lockPosition == true end,
            function(v) db.lockPosition = v; Refresh() end); by = by + h
        -- The window width follows the columns.
        targets.columns, h = W:Slider(container, "Columns", -by, function() return db.columns or 12 end, function(v) db.columns = v; Refresh() end, 8, 24, 1); by = by + h
        _, h = W:Slider(container, "Height", -by, function() return db.window.height or 640 end, function(v) db.window.height = v; Refresh() end, 360, 1000, 1); by = by + h
        targets.smallCategories, h = W:Toggle(container, "Small Category Buttons", -by,
            function() return db.smallCategories == true end,
            function(v) db.smallCategories = v; Refresh() end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Appearance", function(container)
        local by = 0
        targets.panelColor, h = W:ColorSwatch(container, "Panel Color", -by,
            function() local c = db.panelColor; return c.r, c.g, c.b, c.a end,
            function(r, g, b, a) db.panelColor = { r = r, g = g, b = b, a = a }; Refresh() end, true); by = by + h
        _, h = W:Dropdown(container, "Bags Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.bagsColorMode or "accent" end,
            function(v) skin.bagsColorMode = v; Refresh() end,
            { "accent", "custom" }); by = by + h
        targets.accent, h = W:ColorSwatch(container, "Bags Accent", -by,
            function()
                local mode = skin.bagsColorMode or "accent"
                local r, g, b = GetThemeAccent()
                local c = (mode == "accent") and { r = r, g = g, b = b, a = 1 } or (skin.bagsColor or { r = r, g = g, b = b, a = 1 })
                return c.r, c.g, c.b, c.a or 1
            end,
            function(r, g, b)
                skin.bagsColorMode = "custom"
                skin.bagsColor = { r = r, g = g, b = b, a = 1 }
                Refresh()
            end, false); by = by + h
        targets.itemSize, h = W:Slider(container, "Item Icon Size", -by,
            function() return db.itemSize or 36 end,
            function(v) db.itemSize = v; Refresh() end,
            30, 52, 1); by = by + h
        _, h = W:Toggle(container, "Show Item Level", -by,
            function() return db.showItemLevel ~= false end,
            function(v) db.showItemLevel = v; Refresh() end); by = by + h
        _, h = W:Toggle(container, "Color Item Level by Quality", -by,
            function() return db.itemLevelColorByRarity == true end,
            function(v) db.itemLevelColorByRarity = v; Refresh() end); by = by + h
        _, h = W:Label(container, "The grid now reflows automatically when you change icon size, so the bag layout stays stable.", -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
        return by
    end)

    targets.currencies = AddOptionBlock(cols, "right", "Currencies", function(container)
        local by = 0
        targets.showGold, h = W:Toggle(container, "Show Gold", -by,
            function() return db.currency.showGold ~= false end,
            function(v) db.currency.showGold = v; Refresh() end); by = by + h
        targets.showCurrencies, h = W:Toggle(container, "Show Currencies", -by,
            function() return db.currency.show ~= false end,
            function(v) db.currency.show = v; Refresh() end); by = by + h
        _, h = W:Dropdown(container, "Currency Source", -by,
            { backpack = "WoW Tracked", custom = "Custom List", both = "Tracked + Custom" },
            function() return db.currency.mode or "backpack" end,
            function(v) db.currency.mode = v; Refresh() end); by = by + h
        _, h = W:Slider(container, "Max Currencies", -by,
            function() return db.currency.max or 3 end,
            function(v) db.currency.max = v; Refresh() end,
            0, 10, 1); by = by + h
        _, h = W:Slider(container, "Currency Spacing", -by,
            function() return db.currency.spacing or 10 end,
            function(v) db.currency.spacing = v; Refresh() end,
            0, 24, 1); by = by + h
        _, h = W:Input(container, "Custom Currencies", -by,
            function() return db.currency.customList or "" end,
            function(v) db.currency.customList = v; Refresh() end); by = by + h
        _, h = W:Label(container, "Use comma-separated currency names, IDs, links, or wowhead currency URLs.", -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
        _, h = W:Toggle(container, "Click Opens Currency Window", -by,
            function() return db.currency.clickOpensTokenFrame ~= false end,
            function(v) db.currency.clickOpensTokenFrame = v; Refresh() end); by = by + h
        _, h = W:Toggle(container, "Right-Click Untracks", -by,
            function() return db.currency.rightClickUntracks ~= false end,
            function(v) db.currency.rightClickUntracks = v; Refresh() end); by = by + h
        return by
    end)

    y = EndOptionBlocks(cols)

    return y
end)
