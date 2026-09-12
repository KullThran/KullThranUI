-- Modules/BuffsAndDebuffs/BuffsAndDebuffs_Options.lua
-- Registers the "Buffs & Debuffs" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local GetFontValues = Opt.GetFontValues
local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks

local function RefreshBAD()
    local M = KT:GetModule("BuffsAndDebuffs", true)
    if M and M.UpdateAll then
        M:UpdateAll()
    elseif M and M.Refresh then
        M:Refresh()
    end
end

KT:RegisterPage("buffs", "Buffs & Debuffs", 17, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.buffsAndDebuffs
    if not db then
        KT.db.profile.buffsAndDebuffs = KT.db.profile.buffsAndDebuffs or {}
        db = KT.db.profile.buffsAndDebuffs
    end

    db.buffs = db.buffs or { size = 40, spacing = 2, perRow = 12, growDir = "LEFT" }
    db.debuffs = db.debuffs or { size = 44, spacing = 2, perRow = 10, growDir = "LEFT" }

    -- Live preview (buffs + debuffs) skinned by the module's SkinButton.
    local function EnsureLivePreview()
        local frameName = "KT_Options_BuffsPreviewFrame"
        local preview = _G[frameName]
        if not preview then
            preview = CreateFrame("Frame", frameName, sc, "BackdropTemplate")
            if KT.AddBackdrop then KT:AddBackdrop(preview, 0.1, 0.1, 0.1, 0.4) end
            if KT.AddBorder then KT:AddBorder(preview, 0, 0, 0, 1) end

            local lbl = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("TOPLEFT", preview, "TOPLEFT", 10, -6)
            lbl:SetText(LText("LIVE PREVIEW"))
            KT:SetAccentTextColor(lbl, 1)
            preview._ktLivePreviewLabel = lbl

            local labelFont = KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"

            local lblBuffs = preview:CreateFontString(nil, "OVERLAY")
            lblBuffs:SetFont(labelFont, 9, "OUTLINE")
            lblBuffs:SetPoint("TOPLEFT", preview, "TOPLEFT", 10, -22)
            lblBuffs:SetText(LText("BUFFS"))
            lblBuffs:SetTextColor(0.55, 0.55, 0.55, 1)
            preview._ktBuffsLabel = lblBuffs

            local lblDebuffs = preview:CreateFontString(nil, "OVERLAY")
            lblDebuffs:SetFont(labelFont, 9, "OUTLINE")
            lblDebuffs:SetPoint("TOPLEFT", preview, "TOP", 10, -22)
            lblDebuffs:SetText(LText("DEBUFFS"))
            lblDebuffs:SetTextColor(0.55, 0.55, 0.55, 1)
            preview._ktDebuffsLabel = lblDebuffs

            local function CreateAuraButton(btnName)
                local btn = CreateFrame("Button", btnName, preview)
                btn:EnableMouse(false)

                local icon = btn:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints()
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                btn.Icon = icon

                local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                cd:SetAllPoints(icon)
                btn.Cooldown = cd

                local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                count:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 2, 2)
                btn.Count = count

                local dur = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                dur:SetPoint("TOP", btn, "BOTTOM", 0, -2)
                btn.Duration = dur

                return btn
            end

            preview._ktBuffButtons = {}
            preview._ktDebuffButtons = {}
            for i = 1, 4 do
                preview._ktBuffButtons[i] = CreateAuraButton("KT_Options_BuffsPreviewBuff" .. i)
                preview._ktDebuffButtons[i] = CreateAuraButton("KT_Options_BuffsPreviewDebuff" .. i)
            end
        end

        preview:SetParent(sc)
        preview:ClearAllPoints()
        preview:SetPoint("TOP", sc, "TOP", 0, -10)

        if KT.AttachStickyPreview then
            KT:AttachStickyPreview(preview, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
        end

        local function GetBuffIcons(maxCount)
            local icons = {}
            if _G.KTAuraKit and _G.KTAuraKit.AurasRestricted and _G.KTAuraKit.AurasRestricted() then
                return icons
            end
            if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
                for i = 1, 40 do
                    local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
                    aura = ok and aura or nil
                    if aura and aura.icon then
                        icons[#icons + 1] = aura.icon
                        if #icons >= maxCount then break end
                    end
                end
            elseif C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                for i = 1, 40 do
                    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                    aura = ok and aura or nil
                    if aura and aura.icon then
                        icons[#icons + 1] = aura.icon
                        if #icons >= maxCount then break end
                    end
                end
            end
            return icons
        end

        local function GetDebuffIcons(maxCount)
            local icons = {}
            if _G.KTAuraKit and _G.KTAuraKit.AurasRestricted and _G.KTAuraKit.AurasRestricted() then
                return icons
            end
            if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
                for i = 1, 40 do
                    local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, "player", i)
                    aura = ok and aura or nil
                    if aura and aura.icon then
                        icons[#icons + 1] = aura.icon
                        if #icons >= maxCount then break end
                    end
                end
            elseif C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                for i = 1, 40 do
                    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HARMFUL")
                    aura = ok and aura or nil
                    if aura and aura.icon then
                        icons[#icons + 1] = aura.icon
                        if #icons >= maxCount then break end
                    end
                end
            end
            return icons
        end

        local function RefreshPreview()
            local M = KT:GetModule("BuffsAndDebuffs", true)
            if not (M and M.SkinButton) then return end

            local buffSize = tonumber(db.buffs and db.buffs.size) or 40
            local debuffSize = tonumber(db.debuffs and db.debuffs.size) or 44
            local spacing = 10

            local previewW = math.max(1, (sc:GetWidth() or 1) - 20)
            local rowH = math.max(buffSize, debuffSize) + 44
            preview:SetSize(previewW, math.max(100, rowH + 28))

            if preview._ktBuffsLabel then
                preview._ktBuffsLabel:ClearAllPoints()
                preview._ktBuffsLabel:SetPoint("TOPLEFT", preview, "TOPLEFT", 10, -22)
            end
            if preview._ktDebuffsLabel then
                preview._ktDebuffsLabel:ClearAllPoints()
                preview._ktDebuffsLabel:SetPoint("TOPLEFT", preview, "TOP", 10, -22)
            end

            local buffIcons = GetBuffIcons(4)
            local debuffIcons = GetDebuffIcons(4)
            local fallbackBuffs = { 136071, 136106, 135940, 135903 }
            local fallbackDebuffs = { 136075, 135810, 132114, 135824 }
            local debuffTypes = { "Magic", "Curse", "Disease", "Poison" }

            local leftX = 10
            local rightX = math.floor(previewW / 2) + 10
            local topY = -38

            for i, btn in ipairs(preview._ktBuffButtons or {}) do
                btn:SetParent(preview)
                btn:SetSize(buffSize, buffSize)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", preview, "TOPLEFT", leftX + (i - 1) * (buffSize + spacing), topY)
                btn:Show()

                btn.auraData = nil
                if btn.Icon then
                    btn.Icon:SetTexture(buffIcons[i] or fallbackBuffs[i])
                end
                if btn.Count then
                    btn.Count:SetText(i > 1 and tostring(i) or "")
                end
                if btn.Duration then
                    btn.Duration:SetText("1m")
                end

                pcall(M.SkinButton, M, btn, false)
            end

            for i, btn in ipairs(preview._ktDebuffButtons or {}) do
                btn:SetParent(preview)
                btn:SetSize(debuffSize, debuffSize)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", preview, "TOPLEFT", rightX + (i - 1) * (debuffSize + spacing), topY)
                btn:Show()

                btn.auraData = { dispelName = debuffTypes[i] or "Magic" }
                if btn.Icon then
                    btn.Icon:SetTexture(debuffIcons[i] or fallbackDebuffs[i])
                end
                if btn.Count then
                    btn.Count:SetText(i > 1 and tostring(i) or "")
                end
                if btn.Duration then
                    btn.Duration:SetText("12s")
                end

                pcall(M.SkinButton, M, btn, true)
            end
        end

        RefreshPreview()
        return preview, RefreshPreview
    end

    local _, RefreshBADPreview = EnsureLivePreview()
    local function RefreshBADAll()
        RefreshBAD()
        if RefreshBADPreview then RefreshBADPreview() end
    end

    y = y + math.max(140, math.max((tonumber(db.buffs and db.buffs.size) or 40), (tonumber(db.debuffs and db.debuffs.size) or 44)) + 110)

    if not (BeginOptionBlocks and AddOptionBlock and EndOptionBlocks) then
        return y
    end

    local cols = BeginOptionBlocks(sc, y + 10)

    AddOptionBlock(cols, "left", "General", function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Module", -by,
            function() return db.enable ~= false end,
            function(v) db.enable = v; Reload() end); by = by + h
        _, h = W:Dropdown(container, "Style", -by,
            { ["BLIZZARD"] = "Blizzard", ["KUI"] = "Modern KUI", ["SIMPLICITY"] = "Simplicity" },
            function() return db.style or "BLIZZARD" end,
            function(v) db.style = v; RefreshBADAll() end); by = by + h
        if (db.style or "BLIZZARD") ~= "BLIZZARD" then
            _, h = W:Dropdown(container, "Shape", -by,
                { ["NONE"] = "Square", ["CIRCLE"] = "Circle", ["CSQUARE"] = "Rounded Square", ["HEXAGON"] = "Hexagon", ["DIAMOND"] = "Diamond", ["SHIELD"] = "Shield" },
                function() return db.shape or "NONE" end,
                function(v) db.shape = v; RefreshBADAll() end); by = by + h
        end
        return by
    end)

    AddOptionBlock(cols, "left", "Duration Text", function(container)
        local by = 0
        _, h = W:Dropdown(container, "Font", -by, GetFontValues,
            function() return db.durationFont or "AAA_ITC_Avant_Garde" end,
            function(v) db.durationFont = v; RefreshBADAll() end); by = by + h
        _, h = W:Slider(container, "Size", -by,
            function() return db.durationFontSize or 11 end,
            function(v) db.durationFontSize = v; RefreshBADAll() end, 8, 24, 1); by = by + h
        _, h = W:Dropdown(container, "Outline", -by,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.durationFontOutline or "OUTLINE" end,
            function(v) db.durationFontOutline = v; RefreshBADAll() end); by = by + h
        _, h = W:Slider(container, "X Offset", -by,
            function() return db.durationXOffset or 0 end,
            function(v) db.durationXOffset = v; RefreshBADAll() end, -20, 20, 1); by = by + h
        _, h = W:Slider(container, "Y Offset", -by,
            function() return db.durationYOffset or -2 end,
            function(v) db.durationYOffset = v; RefreshBADAll() end, -20, 20, 1); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Buff Layout", function(container)
        local by = 0
        _, h = W:Slider(container, "Size", -by,
            function() return db.buffs.size or 40 end,
            function(v) db.buffs.size = v; RefreshBADAll() end, 16, 80, 1); by = by + h
        _, h = W:Slider(container, "Spacing", -by,
            function() return db.buffs.spacing or 2 end,
            function(v) db.buffs.spacing = v; RefreshBADAll() end, 0, 12, 1); by = by + h
        _, h = W:Slider(container, "Per Row", -by,
            function() return db.buffs.perRow or 12 end,
            function(v) db.buffs.perRow = v; RefreshBADAll() end, 1, 24, 1); by = by + h
        _, h = W:Dropdown(container, "Grow Direction", -by,
            { ["LEFT"] = "Left", ["RIGHT"] = "Right" },
            function() return db.buffs.growDir or "LEFT" end,
            function(v) db.buffs.growDir = v; RefreshBADAll() end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Count Text", function(container)
        local by = 0
        _, h = W:Dropdown(container, "Font", -by, GetFontValues,
            function() return db.countFont or "AAA_ITC_Avant_Garde" end,
            function(v) db.countFont = v; RefreshBADAll() end); by = by + h
        _, h = W:Slider(container, "Size", -by,
            function() return db.countFontSize or 12 end,
            function(v) db.countFontSize = v; RefreshBADAll() end, 8, 24, 1); by = by + h
        _, h = W:Dropdown(container, "Outline", -by,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.countFontOutline or "OUTLINE" end,
            function(v) db.countFontOutline = v; RefreshBADAll() end); by = by + h
        _, h = W:Slider(container, "X Offset", -by,
            function() return db.countXOffset or 2 end,
            function(v) db.countXOffset = v; RefreshBADAll() end, -20, 20, 1); by = by + h
        _, h = W:Slider(container, "Y Offset", -by,
            function() return db.countYOffset or 2 end,
            function(v) db.countYOffset = v; RefreshBADAll() end, -20, 20, 1); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Debuff Layout", function(container)
        local by = 0
        _, h = W:Slider(container, "Size", -by,
            function() return db.debuffs.size or 44 end,
            function(v) db.debuffs.size = v; RefreshBADAll() end, 16, 80, 1); by = by + h
        _, h = W:Slider(container, "Spacing", -by,
            function() return db.debuffs.spacing or 2 end,
            function(v) db.debuffs.spacing = v; RefreshBADAll() end, 0, 12, 1); by = by + h
        _, h = W:Slider(container, "Per Row", -by,
            function() return db.debuffs.perRow or 10 end,
            function(v) db.debuffs.perRow = v; RefreshBADAll() end, 1, 24, 1); by = by + h
        _, h = W:Dropdown(container, "Grow Direction", -by,
            { ["LEFT"] = "Left", ["RIGHT"] = "Right" },
            function() return db.debuffs.growDir or "LEFT" end,
            function(v) db.debuffs.growDir = v; RefreshBADAll() end); by = by + h
        return by
    end)

    return EndOptionBlocks(cols)
end)
