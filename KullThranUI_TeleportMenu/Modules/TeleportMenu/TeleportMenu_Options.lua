-- Modules/TeleportMenu/TeleportMenu_Options.lua
-- Registers the "Teleport Menu" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local GetFontValues = Opt.GetFontValues

local function RefreshTeleportMenu()
    local M = KT:GetModule("TeleportMenu", true)
    if M and M.Refresh then
        M:Refresh()
    end
end

local function GetTeleportThemeBorderColor()
    local palette = KT and KT.GetStylePalette and KT:GetStylePalette() or KT and KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    if accent then
        return accent.r, accent.g, accent.b, accent.a or 1
    end

    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333, 1
end

KT:RegisterPage("teleportmenu", "Teleport Menu", 49, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.teleportMenu
    if not db then
        KT.db.profile.teleportMenu = KT.db.profile.teleportMenu or {}
        db = KT.db.profile.teleportMenu
    end

    -- Embed the actual TeleportMenu UI (as in the last functional version).
    local TM = KT:GetModule("TeleportMenu", true)
    if TM and (db.enable ~= false) and TM.CreateMenuFrame then
        local tmFrame = TM:CreateMenuFrame()

        tmFrame:SetParent(sc)
        tmFrame:ClearAllPoints()
        tmFrame:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -y)
        tmFrame:SetSize((sc:GetWidth() or 660) - 10, 520)
        tmFrame:SetFrameStrata("MEDIUM")
        tmFrame:SetMovable(false)
        tmFrame:SetClampedToScreen(false)
        tmFrame:RegisterForDrag()
        tmFrame._ktEmbedded = true

        if TM.ApplyFrameStyle then
            TM:ApplyFrameStyle(tmFrame)
        end
        if TM.RefreshThemeColors then
            TM:RefreshThemeColors()
        end

        if tmFrame.closeBtn then
            tmFrame.closeBtn:Hide()
        end
        if tmFrame.gearBtn then
            tmFrame.gearBtn:Hide()
        end

        tmFrame._ktEmbeddedCloseButtons = tmFrame._ktEmbeddedCloseButtons or {}
        for _, child in ipairs({ tmFrame:GetChildren() }) do
            if child and child.GetObjectType and child:GetObjectType() == "Button" then
                local tex = child.GetNormalTexture and child:GetNormalTexture()
                local texturePath = tex and tex.GetTexture and tex:GetTexture()
                if texturePath and tostring(texturePath):find("UI%-Panel%-MinimizeButton") then
                    child:Hide()
                    tmFrame._ktEmbeddedCloseButtons[child] = true
                end
            end
        end

        tmFrame:Show()
        if TM.ShowCategory then
            TM:ShowCategory(TM.activeCategory or "Hearthstones")
        end

        y = y + 530
    else
        _, h = W:Label(sc, "|cffFF4444" .. LText("TeleportMenu module not enabled.") .. "|r", -y, 12); y = y + h
    end

    _, h = W:SectionHeader(sc, "General", -y); y = y + h
    _, h = W:Toggle(sc, "Enable Module", -y,
        function() return db.enable ~= false end,
        function(v) db.enable = v; Reload() end); y = y + h

    _, h = W:Toggle(sc, "Show Tooltip", -y,
        function() return db.showTooltip ~= false end,
        function(v) db.showTooltip = v; RefreshTeleportMenu() end); y = y + h
    _, h = W:Toggle(sc, "Show Labels", -y,
        function() return db.showLabels ~= false end,
        function(v) db.showLabels = v; RefreshTeleportMenu() end); y = y + h
    _, h = W:Toggle(sc, "Show Cosmetic", -y,
        function() return db.showCosmetic ~= false end,
        function(v) db.showCosmetic = v; RefreshTeleportMenu() end); y = y + h

    _, h = W:SectionHeader(sc, "Minimap Button", -y); y = y + h
    db.minimap = db.minimap or { hide = false }
    _, h = W:Toggle(sc, "Hide Minimap Button", -y,
        function() return db.minimap.hide == true end,
        function(v)
            db.minimap.hide = v
            Reload()
        end); y = y + h

    _, h = W:SectionHeader(sc, "Position", -y); y = y + h
    _, h = W:Dropdown(sc, "Anchor", -y,
        { ["CENTER"] = "Center", ["TOP"] = "Top", ["BOTTOM"] = "Bottom", ["LEFT"] = "Left", ["RIGHT"] = "Right", ["TOPLEFT"] = "Top Left", ["TOPRIGHT"] = "Top Right", ["BOTTOMLEFT"] = "Bottom Left", ["BOTTOMRIGHT"] = "Bottom Right" },
        function() return db.anchor or "CENTER" end,
        function(v) db.anchor = v; RefreshTeleportMenu() end); y = y + h
    _, h = W:Slider(sc, "X Offset", -y,
        function() return db.xOffset or 0 end,
        function(v) db.xOffset = v; RefreshTeleportMenu() end, -1000, 1000, 1); y = y + h
    _, h = W:Slider(sc, "Y Offset", -y,
        function() return db.yOffset or 0 end,
        function(v) db.yOffset = v; RefreshTeleportMenu() end, -1000, 1000, 1); y = y + h
    _, h = W:Label(sc, "Position is applied when the Teleport Menu is toggled.", -y, 11); y = y + h

    _, h = W:SectionHeader(sc, "Buttons", -y); y = y + h
    _, h = W:Slider(sc, "Button Size", -y,
        function() return db.buttonSize or 36 end,
        function(v) db.buttonSize = v; RefreshTeleportMenu() end, 20, 80, 1); y = y + h
    _, h = W:Slider(sc, "Spacing", -y,
        function() return db.buttonSpacing or 6 end,
        function(v) db.buttonSpacing = v; RefreshTeleportMenu() end, 0, 20, 1); y = y + h
    _, h = W:Slider(sc, "Columns", -y,
        function() return db.columns or 8 end,
        function(v) db.columns = v; RefreshTeleportMenu() end, 1, 20, 1); y = y + h

    _, h = W:Dropdown(sc, "Button Style", -y,
        { ["BLIZZARD"] = "Blizzard", ["KUI"] = "Modern KUI", ["SIMPLICITY"] = "Simplicity" },
        function() return db.buttonStyle or "BLIZZARD" end,
        function(v) db.buttonStyle = v; RefreshTeleportMenu() end); y = y + h

    _, h = W:SectionHeader(sc, "Typography", -y); y = y + h
    _, h = W:Dropdown(sc, "Font", -y, GetFontValues,
        function() return db.font or "AAA_ITC_Avant_Garde" end,
        function(v) db.font = v; RefreshTeleportMenu() end); y = y + h
    _, h = W:Slider(sc, "Font Size", -y,
        function() return db.fontSize or 10 end,
        function(v) db.fontSize = v; RefreshTeleportMenu() end, 8, 24, 1); y = y + h
    _, h = W:Dropdown(sc, "Outline", -y,
        { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
        function() return db.fontOutline or "OUTLINE" end,
        function(v) db.fontOutline = v; RefreshTeleportMenu() end); y = y + h

    _, h = W:SectionHeader(sc, "Colors", -y); y = y + h
    _, h = W:ColorSwatch(sc, "Background", -y,
        function()
            local c = db.bgColor or { r = 0.07, g = 0.07, b = 0.07, a = 0.97 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a) db.bgColor = { r = r, g = g, b = b, a = a }; RefreshTeleportMenu() end, true); y = y + h
    _, h = W:ColorSwatch(sc, "Border", -y,
        function()
            local c = db.borderColor
            local looksLikeThemeColor = c and (
                (math.abs((c.r or 0) - 1.00) <= 0.02 and math.abs((c.g or 0) - 0.18) <= 0.02 and math.abs((c.b or 0) - 0.39) <= 0.02) or
                (math.abs((c.r or 0) - 0.37) <= 0.02 and math.abs((c.g or 0) - 0.84) <= 0.02 and math.abs((c.b or 0) - 1.00) <= 0.02) or
                (math.abs((c.r or 0) - 0.28) <= 0.02 and math.abs((c.g or 0) - 0.95) <= 0.02 and math.abs((c.b or 0) - 0.62) <= 0.02) or
                (math.abs((c.r or 0) - 0.66) <= 0.02 and math.abs((c.g or 0) - 0.60) <= 0.02 and math.abs((c.b or 0) - 1.00) <= 0.02) or
                (math.abs((c.r or 0) - 1.00) <= 0.02 and math.abs((c.g or 0) - 0.74) <= 0.02 and math.abs((c.b or 0) - 0.28) <= 0.02) or
                (math.abs((c.r or 0) - 0.24) <= 0.02 and math.abs((c.g or 0) - 0.94) <= 0.02 and math.abs((c.b or 0) - 0.90) <= 0.02) or
                (math.abs((c.r or 0) - 1.00) <= 0.02 and math.abs((c.g or 0) - 0.28) <= 0.02 and math.abs((c.b or 0) - 0.34) <= 0.02) or
                (math.abs((c.r or 0) - 1.00) <= 0.02 and math.abs((c.g or 0) - 0.86) <= 0.02 and math.abs((c.b or 0) - 0.34) <= 0.02) or
                (math.abs((c.r or 0) - 0.90) <= 0.02 and math.abs((c.g or 0) - 0.46) <= 0.02 and math.abs((c.b or 0) - 1.00) <= 0.02) or
                (math.abs((c.r or 0) - 0.70) <= 0.02 and math.abs((c.g or 0) - 0.80) <= 0.02 and math.abs((c.b or 0) - 0.92) <= 0.02) or
                (math.abs((c.r or 0) - 0.74) <= 0.02 and math.abs((c.g or 0) - 0.96) <= 0.02 and math.abs((c.b or 0) - 0.28) <= 0.02)
            )
            if db.useThemeBorderColor ~= false or db.borderColorOverride ~= true or looksLikeThemeColor then
                return GetTeleportThemeBorderColor()
            end
            c = db.borderColor or { r = KT.C_R, g = KT.C_G, b = KT.C_B, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a)
            db.useThemeBorderColor = false
            db.borderColorOverride = true
            db.borderColor = { r = r, g = g, b = b, a = a }
            RefreshTeleportMenu()
        end, true); y = y + h

    return y
end)
