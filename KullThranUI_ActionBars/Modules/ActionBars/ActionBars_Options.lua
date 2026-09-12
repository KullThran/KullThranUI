-- Modules/ActionBars/ActionBars_Options.lua
-- Registers the "Action Bars" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local GetFontValues = Opt.GetFontValues
local AddPageSubTabBar = KT.AddOptionsSubTabBar

local actionbarsSubTab = "general"
local ACTIONBARS_SUBTABS = {
    { id = "general", label = "General" },
    { id = "shapes",  label = "Shapes" },
    { id = "layout",  label = "Layout" },
    { id = "text",    label = "Typography" },
    { id = "fade",    label = "Fade" },
}

local function RefreshAB()
    local M = KT:GetModule("ActionBars", true)
    if M and M.StyleAllBars then
        M:StyleAllBars()
    end
end

local function RefreshFade()
    local M = KT:GetModule("ActionBars", true)
    if M and M.UpdateMouseoverState then
        M:UpdateMouseoverState()
    end
end

local function RefreshBlizzardFade()
    local M = KT:GetModule("BlizzardFrames", true)
    if M and M.UpdateMouseoverState then
        M:UpdateMouseoverState()
    end
end

KT:RegisterPage("actionbars", "Action Bars", 16, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.actionbars
    if not db then
        KT.db.profile.actionbars = KT.db.profile.actionbars or {}
        db = KT.db.profile.actionbars
    end
    KT.db.profile.blizzframes = KT.db.profile.blizzframes or {}
    local blizzDB = KT.db.profile.blizzframes

    -- Live preview (styling sample ActionButtons with current settings).
    local function EnsureLivePreview()
        local frameName = "KT_Options_ActionBarsPreviewFrame"
        local preview = _G[frameName]
        if not preview then
            preview = CreateFrame("Frame", frameName, sc, "BackdropTemplate")
            if KT.AddBackdrop then KT:AddBackdrop(preview, 0.1, 0.1, 0.1, 0.4) end
            if KT.AddBorder then KT:AddBorder(preview, 0, 0, 0, 1) end

            local lbl = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            -- Keep the caption clearly above the preview frame border.  The
            -- sticky preview host re-anchors the frame itself, so the label
            -- needs its own gap instead of sitting directly on the edge.
            lbl:SetPoint("BOTTOMLEFT", preview, "TOPLEFT", 0, 10)
            lbl:SetText(LText("LIVE PREVIEW"))
            KT:SetAccentTextColor(lbl, 1)
            preview._ktLivePreviewLabel = lbl

            preview._ktButtons = {}
            for i = 1, 4 do
                local btnName = "KT_Options_ActionBarsPreviewButton" .. i
                -- This is a purely visual sample. ActionButtonTemplate installs
                -- Blizzard's live action-slot OnEvent handler, which can receive
                -- secret cooldown values in restricted combat. Because an addon
                -- created the preview frame, that handler is tainted and its
                -- SetCooldown call fails even while the options are closed.
                local btn = CreateFrame("CheckButton", btnName, preview)
                btn:SetSize(40, 40)
                btn:EnableMouse(false)

                local icon = btn:CreateTexture(btnName .. "Icon", "ARTWORK")
                icon:SetAllPoints(btn)
                icon:SetTexture(136071)
                btn.icon = icon
                btn.Icon = icon

                local normal = btn:CreateTexture(nil, "BACKGROUND")
                normal:SetAllPoints(btn)
                normal:SetColorTexture(0, 0, 0, 0)
                btn:SetNormalTexture(normal)

                local pushed = btn:CreateTexture(nil, "OVERLAY")
                pushed:SetAllPoints(btn)
                pushed:SetColorTexture(1, 1, 1, 0.2)
                btn:SetPushedTexture(pushed)

                local checked = btn:CreateTexture(nil, "OVERLAY")
                checked:SetAllPoints(btn)
                checked:SetColorTexture(1, 0.9, 0, 0.2)
                btn:SetCheckedTexture(checked)

                local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints(btn)
                highlight:SetColorTexture(1, 1, 1, 0.12)
                btn:SetHighlightTexture(highlight)

                local hk = btn:CreateFontString(btnName .. "HotKey", "OVERLAY", "GameFontNormalSmall")
                hk:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -2)
                hk:SetText(tostring(i))
                btn.HotKey = hk

                local macro = btn:CreateFontString(btnName .. "Name", "OVERLAY", "GameFontNormalSmall")
                macro:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
                macro:SetText(i == 1 and "Macro" or "")
                btn.Name = macro

                preview._ktButtons[i] = btn
            end
        end

        preview:SetParent(sc)
        preview:ClearAllPoints()
        preview:SetPoint("TOP", sc, "TOP", 0, -10)
        preview:SetSize(math.max(1, (sc:GetWidth() or 1) - 20), 92)
        preview:Show()

        local activeIcons = {}
        if GetActionTexture and not (InCombatLockdown and InCombatLockdown()) then
            for i = 1, 12 do
                local ok, tex = pcall(GetActionTexture, i)
                local accessible = ok and tex
                    and not (_G.issecretvalue and _G.issecretvalue(tex))
                    and not (_G.canaccessvalue and not _G.canaccessvalue(tex))
                if accessible then
                    activeIcons[#activeIcons + 1] = tex
                    if #activeIcons >= 4 then break end
                end
            end
        end
        local fallback = { 136071, 136106, 135940, 135903 }

        for i, btn in ipairs(preview._ktButtons or {}) do
            btn:SetParent(preview)
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", preview, "CENTER", (i - 2.5) * 52, -6)
            btn:Show()

            if btn.Icon then
                btn.Icon:SetTexture(activeIcons[i] or fallback[i])
            end
        end

        if KT.AttachStickyPreview then
            KT:AttachStickyPreview(preview, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
        end

        local function RefreshPreview()
            local M = KT:GetModule("ActionBars", true)
            if not (M and M.StyleButton) then return end
            if InCombatLockdown and InCombatLockdown() then return end
            for _, btn in ipairs(preview._ktButtons or {}) do
                pcall(M.StyleButton, M, btn)
            end
        end

        RefreshPreview()
        return preview, RefreshPreview
    end

    local _, RefreshABPreview = EnsureLivePreview()
    local function RefreshABAll()
        RefreshAB()
        if RefreshABPreview then RefreshABPreview() end
    end

    y = y + 126

    if AddPageSubTabBar then
        _, h = AddPageSubTabBar(sc, -y, ACTIONBARS_SUBTABS, actionbarsSubTab, function(tabId)
            actionbarsSubTab = tabId
            KT:RefreshPage()
        end); y = y + h
    end

    if actionbarsSubTab == "general" then
        _, h = W:SectionHeader(sc, "General", -y); y = y + h
        _, h = W:Label(sc, "Choose the visual system first, then fine-tune visibility and feedback below.", -y, 11); y = y + h
        _, h = W:Toggle(sc, "Enable Module", -y,
            function() return db.enable ~= false end,
            function(v) db.enable = v; Reload() end); y = y + h

        _, h = W:Dropdown(sc, "Button Style", -y,
            { ["BLIZZARD"] = "Blizzard", ["KUI"] = "Modern KUI", ["SIMPLICITY"] = "Simplicity" },
            function() return db.buttonStyle or "BLIZZARD" end,
            function(v) db.buttonStyle = v; RefreshABAll(); KT:RefreshPage() end); y = y + h

        _, h = W:SectionHeader(sc, "Button Content", -y); y = y + h
        _, h = W:Toggle(sc, "Hide Hotkeys", -y,
            function() return db.hideHotkeys == true end,
            function(v) db.hideHotkeys = v; RefreshABAll() end); y = y + h
        _, h = W:Toggle(sc, "Show Pressed Key Indicator", -y,
            function() return db.showKeypressIndicator ~= false end,
            function(v) db.showKeypressIndicator = v end); y = y + h
        _, h = W:Toggle(sc, "Hide Macro Text", -y,
            function() return db.hideMacroText == true end,
            function(v) db.hideMacroText = v; RefreshABAll() end); y = y + h

    elseif actionbarsSubTab == "shapes" then
        _, h = W:SectionHeader(sc, "Button Shapes", -y); y = y + h
        _, h = W:Label(sc, "Shapes are live-previewed. Blizzard uses the default square because it does not support custom masks.", -y, 11); y = y + h

        if (db.buttonStyle or "BLIZZARD") == "BLIZZARD" then
            _, h = W:Label(sc, "Shapes are only available when using Modern KUI or Simplicity button styles.", -y, 11); y = y + h
        else
            local shapeChoices = {
                ["NONE"]    = "Square (Default)",
                ["CIRCLE"]  = "Circle",
                ["CSQUARE"] = "Rounded Square",
                ["HEXAGON"] = "Hexagon",
                ["DIAMOND"] = "Diamond",
                ["SHIELD"]  = "Shield",
            }
            local perBarChoices = {
                ["GLOBAL"]  = "Global Default",
                ["NONE"]    = "Square",
                ["CIRCLE"]  = "Circle",
                ["CSQUARE"] = "Rounded Square",
                ["HEXAGON"] = "Hexagon",
                ["DIAMOND"] = "Diamond",
                ["SHIELD"]  = "Shield",
            }

            _, h = W:SectionHeader(sc, "Global Shape", -y); y = y + h
            _, h = W:Dropdown(sc, "Global Button Shape", -y, shapeChoices,
                function() return db.buttonShape or "NONE" end,
                function(v) db.buttonShape = v; RefreshABAll() end); y = y + h

            _, h = W:SectionHeader(sc, "Per-Bar Overrides", -y); y = y + h
            local barShapes = {
                { k = "shapeBar1",   label = "Bar 1 (Main)" },
                { k = "shapeBar2",   label = "Bar 2 (Bottom Left)" },
                { k = "shapeBar3",   label = "Bar 3 (Bottom Right)" },
                { k = "shapeBar4",   label = "Bar 4 (Right 1)" },
                { k = "shapeBar5",   label = "Bar 5 (Right 2)" },
                { k = "shapeBar6",   label = "Bar 6" },
                { k = "shapeBar7",   label = "Bar 7" },
                { k = "shapeBar8",   label = "Bar 8" },
                { k = "shapePet",    label = "Pet Bar" },
                { k = "shapeStance", label = "Stance Bar" },
            }
            for _, t in ipairs(barShapes) do
                _, h = W:Dropdown(sc, t.label, -y, perBarChoices,
                    function() return db[t.k] or "GLOBAL" end,
                    function(v) db[t.k] = v; RefreshABAll() end); y = y + h
            end
        end

    elseif actionbarsSubTab == "layout" then
        _, h = W:SectionHeader(sc, "Layout", -y); y = y + h
        _, h = W:Label(sc, "Adjust the distance between buttons and the padding around each icon group.", -y, 11); y = y + h
        _, h = W:Slider(sc, "Spacing", -y,
            function() return db.buttonSpacing or 0 end,
            function(v) db.buttonSpacing = v; RefreshABAll() end, 0, 12, 1); y = y + h
        _, h = W:Slider(sc, "Padding", -y,
            function() return db.buttonPadding or 0 end,
            function(v) db.buttonPadding = v; RefreshABAll() end, 0, 12, 1); y = y + h

        _, h = W:ColorSwatch(sc, "Backdrop Color", -y,
            function()
                local c = db.buttonBackdropColor or { r = 0, g = 0, b = 0, a = 1 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a)
                db.buttonBackdropColor = { r = r, g = g, b = b, a = a }
                RefreshABAll()
            end, true); y = y + h

    elseif actionbarsSubTab == "text" then
        _, h = W:SectionHeader(sc, "Cooldown Text Typography", -y); y = y + h
        _, h = W:Label(sc, "These settings control the cooldown numbers displayed over action icons.", -y, 11); y = y + h
        _, h = W:Dropdown(sc, "Font", -y, GetFontValues,
            function() return db.font or "AAA_ITC_Avant_Garde" end,
            function(v) db.font = v; RefreshABAll() end); y = y + h
        _, h = W:Slider(sc, "Size", -y,
            function() return db.fontSize or 16 end,
            function(v) db.fontSize = v; RefreshABAll() end, 8, 26, 1); y = y + h
        _, h = W:Dropdown(sc, "Outline", -y,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.fontOutline or "OUTLINE" end,
            function(v) db.fontOutline = v; RefreshABAll() end); y = y + h
        _, h = W:ColorSwatch(sc, "Text Color", -y,
            function()
                local c = db.fontColor or { r = 1, g = 1, b = 1, a = 1 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a) db.fontColor = { r = r, g = g, b = b, a = a }; RefreshABAll() end, true); y = y + h

        _, h = W:SectionHeader(sc, "Hotkeys Typography", -y); y = y + h
        _, h = W:Dropdown(sc, "Font", -y, GetFontValues,
            function() return db.hotkeyFont or db.font or "AAA_ITC_Avant_Garde" end,
            function(v) db.hotkeyFont = v; RefreshABAll() end); y = y + h
        _, h = W:Slider(sc, "Size", -y,
            function() return db.hotkeyFontSize or 12 end,
            function(v) db.hotkeyFontSize = v; RefreshABAll() end, 8, 24, 1); y = y + h
        _, h = W:Dropdown(sc, "Outline", -y,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.hotkeyFontOutline or "OUTLINE" end,
            function(v) db.hotkeyFontOutline = v; RefreshABAll() end); y = y + h
        _, h = W:ColorSwatch(sc, "Hotkey Color", -y,
            function()
                local c = db.hotkeyFontColor or { r = 1, g = 1, b = 1, a = 1 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a) db.hotkeyFontColor = { r = r, g = g, b = b, a = a }; RefreshABAll() end, true); y = y + h

        _, h = W:SectionHeader(sc, "Macro Text Typography", -y); y = y + h
        _, h = W:Dropdown(sc, "Font", -y, GetFontValues,
            function() return db.macroFont or db.font or "AAA_ITC_Avant_Garde" end,
            function(v) db.macroFont = v; RefreshABAll() end); y = y + h
        _, h = W:Slider(sc, "Size", -y,
            function() return db.macroFontSize or 12 end,
            function(v) db.macroFontSize = v; RefreshABAll() end, 8, 24, 1); y = y + h
        _, h = W:Dropdown(sc, "Outline", -y,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.macroFontOutline or "OUTLINE" end,
            function(v) db.macroFontOutline = v; RefreshABAll() end); y = y + h
        _, h = W:ColorSwatch(sc, "Macro Color", -y,
            function()
                local c = db.macroFontColor or { r = 1, g = 1, b = 1, a = 1 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a) db.macroFontColor = { r = r, g = g, b = b, a = a }; RefreshABAll() end, true); y = y + h

    elseif actionbarsSubTab == "fade" then
        _, h = W:SectionHeader(sc, "Mouseover Fade", -y); y = y + h
        _, h = W:Label(sc, "Choose which bars fade while idle and return when the mouse enters them.", -y, 11); y = y + h
        local fadeKeys = {
            { k = "fadeBar1",   label = "Bar 1 (Main)" },
            { k = "fadeBar2",   label = "Bar 2 (Bottom Left)" },
            { k = "fadeBar3",   label = "Bar 3 (Bottom Right)" },
            { k = "fadeBar4",   label = "Bar 4 (Right 1)" },
            { k = "fadeBar5",   label = "Bar 5 (Right 2)" },
            { k = "fadeBar6",   label = "Bar 6" },
            { k = "fadeBar7",   label = "Bar 7" },
            { k = "fadeBar8",   label = "Bar 8" },
            { k = "fadePet",    label = "Pet Bar" },
            { k = "fadeStance", label = "Stance Bar" },
        }
        for _, t in ipairs(fadeKeys) do
            _, h = W:Toggle(sc, t.label, -y,
                function() return db[t.k] == true end,
                function(v) db[t.k] = v; RefreshFade() end); y = y + h
        end

        _, h = W:SectionHeader(sc, "Blizzard Bars", -y); y = y + h
        _, h = W:Label(sc, "These controls also apply to the default Blizzard micro menu and backpack.", -y, 11); y = y + h
        local blizzardFadeKeys = {
            { k = "fadeMicroMenu", label = "Micro Menu" },
            { k = "fadeBags",      label = "Backpack Button" },
        }
        for _, t in ipairs(blizzardFadeKeys) do
            _, h = W:Toggle(sc, t.label, -y,
                function() return blizzDB[t.k] == true end,
                function(v) blizzDB[t.k] = v; RefreshBlizzardFade() end); y = y + h
        end
    end

    return y
end)
