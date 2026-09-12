local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then
    return
end

local Cursor = KT:GetModule("Cursor", true)
if not Cursor then
    return
end

local Opt = KT.Options or {}
local LText = Opt.LText or function(text) return text end

local function BuildChoiceMap(list)
    local map = {}
    for _, value in ipairs(list or {}) do
        map[value] = LText(value)
    end
    return map
end

local function CopyCursorValue(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, nestedValue in pairs(value) do
        out[key] = CopyCursorValue(nestedValue)
    end
    return out
end

local function ResetCursorDefaults(db)
    if type(db) ~= "table" then
        return
    end
    wipe(db)
    for key, value in pairs(Cursor:GetDefaults() or {}) do
        db[key] = CopyCursorValue(value)
    end
end

local activeCursorSection = "general"

local function ScrollToBlock(frame)
    if not (frame and KT and KT.SmoothScrollTo) then
        return
    end

    local sf = KT._scrollFrame or (KT.MenuPrincipal and KT.MenuPrincipal.scrollFrame)
    local child = sf and sf.GetScrollChild and sf:GetScrollChild()
    local sectionTop = frame.GetTop and frame:GetTop()
    local childTop = child and child.GetTop and child:GetTop()
    if sectionTop and childTop then
        KT.SmoothScrollTo(math.max(0, (childTop - sectionTop) - 40))
    end
end

local function SetPreviewTexture(tex, info)
    if not tex then
        return
    end

    if not info or not info.path then
        tex:Hide()
        return
    end

    tex:Show()
    if info.isAtlas then
        tex:SetAtlas(info.path)
    else
        tex:SetTexture(info.path)
    end
end

KT:RegisterPage("cursor", LText("Cursor"), 50, function(sc, W)
    local y, h = 0, 0
    local db = Cursor:GetDB()
    local updatePreview

    local function ApplyAndPreview()
        Cursor:ApplyToAddon()
        if updatePreview then
            updatePreview()
        end
    end

    local preview = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    preview:SetSize((sc:GetWidth() or 1) - 20, 170)
    preview:SetPoint("TOP", sc, "TOP", 0, -10)
    if KT.AddBackdrop then KT:AddBackdrop(preview, 0.06, 0.06, 0.08, 0.92) end
    if KT.AddBorder then KT:AddAccentBorder(preview, 0.7) end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(preview, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
    end

    local title = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", preview, "TOPLEFT", 10, -8)
    title:SetText(LText("LIVE PREVIEW (CURSOR)"))
    KT:SetAccentTextColor(title, 1)

    local previewCore = CreateFrame("Frame", nil, preview)
    previewCore:SetSize(120, 120)
    previewCore:SetPoint("CENTER", preview, "CENTER", 0, 8)

    -- Keep the simulated hardware cursor in its own, unscaled frame. Child
    -- frames render above the ring textures regardless of their draw layer.
    local cursorLayer = CreateFrame("Frame", nil, preview)
    cursorLayer:SetSize(1, 1)
    cursorLayer:SetPoint("CENTER", previewCore, "CENTER")
    cursorLayer:SetFrameLevel(previewCore:GetFrameLevel() + 50)
    local previewCursor = cursorLayer:CreateTexture(nil, "OVERLAY", nil, 7)
    previewCursor:SetPoint("TOPLEFT", cursorLayer, "CENTER")

    local ringLayers = {}
    for i = 1, 3 do
        local tex = previewCore:CreateTexture(nil, "ARTWORK", nil, i)
        tex:SetPoint("CENTER")
        ringLayers[i] = tex
    end

    local highContrastOuter = previewCore:CreateTexture(nil, "ARTWORK", nil, 4)
    highContrastOuter:SetPoint("CENTER")
    local highContrastInner = previewCore:CreateTexture(nil, "ARTWORK", nil, 5)
    highContrastInner:SetPoint("CENTER")

    local reticle = previewCore:CreateTexture(nil, "OVERLAY", nil, 6)
    reticle:SetPoint("CENTER")

    local trailPreview = CreateFrame("Frame", nil, preview)
    trailPreview:SetSize(180, 24)
    trailPreview:SetPoint("BOTTOM", preview, "BOTTOM", 0, 18)
    trailPreview.dots = trailPreview.dots or {}
    for i = 1, 7 do
        local dot = trailPreview:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(Cursor:GetMediaPaths().reticleDot)
        dot:SetPoint("LEFT", trailPreview, "LEFT", (i - 1) * 24, 0)
        trailPreview.dots[i] = dot
    end

    local help = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    help:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -10, 10)
    help:SetText(LText("Click elements to jump to their settings"))
    help:SetTextColor(0.78, 0.78, 0.82, 0.9)

    local function JumpToSection(sectionKey)
        activeCursorSection = sectionKey or "general"
        if KT and KT.RefreshPage then
            KT:RefreshPage()
        end
    end

    local function CreatePreviewHitbox(target, label, sectionKey)
        local btn = CreateFrame("Button", nil, preview)
        btn:SetAllPoints(target)
        btn:RegisterForClicks("LeftButtonDown")
        btn:SetFrameLevel((target.GetFrameLevel and target:GetFrameLevel() or preview:GetFrameLevel()) + 20)

        local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        border:SetAllPoints()
        if KT.AddBorder then KT:AddBorder(border, 1, 1, 1, 0.95) end
        border:Hide()

        local hint = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOM", btn, "TOP", 0, 4)
        hint:SetText(LText(label))
        hint:SetTextColor(1, 1, 1, 0.95)
        hint:Hide()

        btn:SetScript("OnEnter", function()
            border:Show()
            hint:Show()
        end)
        btn:SetScript("OnLeave", function()
            border:Hide()
            hint:Hide()
        end)
        btn:SetScript("OnMouseDown", function()
            JumpToSection(sectionKey)
        end)
    end

    CreatePreviewHitbox(previewCore, "Go to Rings", "rings")
    CreatePreviewHitbox(reticle, "Go to Reticle", "rings")
    CreatePreviewHitbox(trailPreview, "Go to Trail", "trail")

    updatePreview = function()
        local media = Cursor:GetMediaPaths()
        local reticleInfo = Cursor:GetReticleTextureInfo(db.reticle)
        local ringTexture = media.ring
        local baseSizes = { 48, 72, 96 }
        local slotKeys = { "innerRing", "mainRing", "outerRing" }

        local cursorScale = math.max(0.5, math.min(2.5, tonumber(db.scale) or 1))
        previewCursor:SetTexture(media.cursorPoint)
        previewCursor:SetSize(40, 40)
        previewCursor:SetVertexColor(1, 1, 1, 1)

        local function GetColorForSlot(config)
            if config == "Cast" then
                return Cursor:GetModeColor(db.castColorMode, db.castCustomColor, "cast")
            elseif config == "GCD" then
                return Cursor:GetModeColor(db.gcdColorMode, db.gcdCustomColor, "gcd")
            elseif config == "Health" then
                return Cursor:GetModeColor(db.healthColorMode, db.healthCustomColor, "health")
            elseif config == "Power" then
                return Cursor:GetModeColor(db.powerColorMode, db.powerCustomColor, "power")
            end

            return Cursor:GetModeColor(db.mainRingColorMode, db.mainRingCustomColor, "main")
        end

        highContrastOuter:Hide()
        highContrastInner:Hide()

        for i, key in ipairs(slotKeys) do
            local config = db[key]
            local tex = ringLayers[i]
            tex:Hide()

            if config ~= "None" then
                tex:SetTexture(ringTexture)
                tex:SetSize(baseSizes[i], baseSizes[i])

                if config == "High Contrast Ring" then
                    local outerSize = baseSizes[i] + ((db.highContrastOuterThickness or 2) * 2)
                    local innerSize = baseSizes[i] + ((db.highContrastInnerThickness or -4) * 2)
                    local orR, orG, orB = Cursor:GetModeColor(
                        db.highContrastOuterColorMode,
                        db.highContrastOuterColor,
                        "highContrastOuter"
                    )
                    local irR, irG, irB = Cursor:GetModeColor(
                        db.highContrastInnerColorMode,
                        db.highContrastInnerColor,
                        "highContrastInner"
                    )
                    highContrastOuter:SetTexture(ringTexture)
                    highContrastInner:SetTexture(ringTexture)
                    highContrastOuter:SetSize(outerSize, outerSize)
                    highContrastInner:SetSize(innerSize, innerSize)
                    highContrastOuter:SetVertexColor(orR, orG, orB, db.transparency or 1)
                    highContrastInner:SetVertexColor(irR, irG, irB, db.transparency or 1)
                    highContrastOuter:Show()
                    highContrastInner:Show()
                else
                    local r, g, b = GetColorForSlot(config)
                    tex:SetVertexColor(r, g, b, db.transparency or 1)
                    tex:Show()

                    if config == "Health and Power" then
                        tex:SetVertexColor(1, 1, 1, db.transparency or 1)
                    elseif config == "Main Ring + GCD" then
                        tex:SetVertexColor(Cursor:GetModeColor(db.mainRingColorMode, db.mainRingCustomColor, "main"))
                    elseif config == "Main Ring + Cast" then
                        tex:SetVertexColor(Cursor:GetModeColor(db.mainRingColorMode, db.mainRingCustomColor, "main"))
                    end
                end
            end
        end

        SetPreviewTexture(reticle, reticleInfo)
        if reticleInfo and reticleInfo.path then
            local r, g, b = Cursor:GetModeColor(db.reticleColorMode, db.reticleCustomColor, "reticle")
            local scale = (reticleInfo.scale or 1) * (db.reticleScale or 1.5) * 16
            reticle:SetSize(scale, scale)
            reticle:SetVertexColor(r, g, b, db.transparency or 1)
        end

        local trailR, trailG, trailB = Cursor:GetModeColor(db.trailColorMode, db.trailCustomColor, "trail")
        for index, dot in ipairs(trailPreview.dots) do
            local scale = math.max(8, math.floor(((db.trailScale or 1) * 10) + index))
            dot:SetSize(scale, scale)
            dot:SetAlpha(db.enableTrail and (0.25 + (index * 0.08)) or 0.12)
            dot:SetVertexColor(trailR, trailG, trailB, 1)
        end

        previewCore:SetScale(cursorScale)
        previewCore:SetAlpha(db.enable ~= false and 1 or 0.4)
        trailPreview:SetAlpha(db.enable ~= false and 1 or 0.4)
    end

    updatePreview()
    y = y + 190

    local sectionOrder = {
        { id = "general", label = "General" },
        { id = "rings", label = "Rings" },
        { id = "colors", label = "Colors" },
        { id = "combat", label = "Combat" },
        { id = "trail", label = "Trail" },
        { id = "effects", label = "Effects" },
    }

    local _, navHeight
    if W and W.SubTabBar then
        _, navHeight = W:SubTabBar(sc, -y, sectionOrder, activeCursorSection, JumpToSection)
    elseif KT and KT.AddOptionsSubTabBar then
        _, navHeight = KT.AddOptionsSubTabBar(sc, -y, sectionOrder, activeCursorSection, JumpToSection)
    end
    y = y + (navHeight or 0)
    _, h = W:Button(sc, LText("Restore Cursor Defaults"), -y, function()
        ResetCursorDefaults(db)
        ApplyAndPreview()
        if KT and KT.RefreshPage then
            KT:RefreshPage()
        end
    end)
    y = y + h

    local ringChoices = BuildChoiceMap(Cursor:GetRingOptions())
    local reticleChoices = BuildChoiceMap(Cursor:GetReticleOptions())
    local modifierChoices = BuildChoiceMap(Cursor:GetModifierOptions())
    local seasonalStyleChoices = BuildChoiceMap(Cursor:GetSeasonalStyleOptions())
    local seasonalParticleChoices = BuildChoiceMap(Cursor:GetSeasonalParticleOptions())
    local colorModeChoices = {
        default = LText("Default"),
        theme = LText("Color Theme"),
        class = LText("Class Color"),
        custom = LText("Custom Color"),
    }
    local powerColorModeChoices = {
        default = LText("Default"),
        theme = LText("Color Theme"),
        power = LText("Power Type"),
        custom = LText("Custom Color"),
    }
    local fillDrainChoices = {
        fill = LText("Fill"),
        drain = LText("Drain"),
    }
    local function AddColorModeSection(label, modeKey, colorKey, choices)
        local rowHeight
        _, rowHeight = W:Dropdown(sc, LText(label .. " Mode"), -y, choices or colorModeChoices,
            function() return db[modeKey] or "default" end,
            function(v) db[modeKey] = v; ApplyAndPreview() end)
        y = y + rowHeight
        _, rowHeight = W:ColorSwatch(sc, LText(label .. " Custom"), -y,
            function()
                local c = db[colorKey] or { r = 1, g = 1, b = 1 }
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                db[colorKey] = { r = r, g = g, b = b }
                ApplyAndPreview()
            end, false)
        y = y + rowHeight
    end

    if activeCursorSection == "general" then
        _, h = W:SectionHeader(sc, LText("General"), -y)
        y = y + h
        _, h = W:Toggle(sc, LText("Enable Module"), -y,
            function() return db.enable ~= false end,
            function(v) db.enable = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Toggle(sc, LText("Show Only In Combat"), -y,
            function() return db.showOnlyInCombat == true end,
            function(v) db.showOnlyInCombat = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Slider(sc, LText("Global Scale"), -y,
            function() return db.scale or 1 end,
            function(v) db.scale = v; ApplyAndPreview() end, 0.5, 2.5, 0.1)
        y = y + h
        _, h = W:Slider(sc, LText("Transparency"), -y,
            function() return db.transparency or 1 end,
            function(v) db.transparency = v; ApplyAndPreview() end, 0.1, 1.0, 0.05)
        y = y + h
    elseif activeCursorSection == "rings" then
        _, h = W:SectionHeader(sc, LText("Reticle & Rings"), -y)
        y = y + h
        _, h = W:Dropdown(sc, LText("Reticle"), -y, reticleChoices,
            function() return db.reticle or "Dot" end,
            function(v) db.reticle = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Slider(sc, LText("Reticle Size"), -y,
            function() return db.reticleScale or 1.5 end,
            function(v) db.reticleScale = v; ApplyAndPreview() end, 0.5, 3.0, 0.1)
        y = y + h
        _, h = W:Dropdown(sc, LText("Inner Ring"), -y, ringChoices,
            function() return db.innerRing or "GCD" end,
            function(v) db.innerRing = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Dropdown(sc, LText("Main Ring"), -y, ringChoices,
            function() return db.mainRing or "Main Ring" end,
            function(v) db.mainRing = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Dropdown(sc, LText("Outer Ring"), -y, ringChoices,
            function() return db.outerRing or "Cast" end,
            function(v) db.outerRing = v; ApplyAndPreview() end)
        y = y + h
    elseif activeCursorSection == "colors" then
        _, h = W:SectionHeader(sc, LText("Colors"), -y)
        y = y + h
        AddColorModeSection("Reticle", "reticleColorMode", "reticleCustomColor")
        AddColorModeSection("Main Ring", "mainRingColorMode", "mainRingCustomColor")
        AddColorModeSection("GCD", "gcdColorMode", "gcdCustomColor")
        AddColorModeSection("Cast", "castColorMode", "castCustomColor")
        AddColorModeSection("Health", "healthColorMode", "healthCustomColor")
        AddColorModeSection("Power", "powerColorMode", "powerCustomColor", powerColorModeChoices)
        AddColorModeSection("Trail", "trailColorMode", "trailCustomColor")
        AddColorModeSection("High Contrast Outer", "highContrastOuterColorMode", "highContrastOuterColor")
        AddColorModeSection("High Contrast Inner", "highContrastInnerColorMode", "highContrastInnerColor")
    elseif activeCursorSection == "combat" then
        _, h = W:SectionHeader(sc, LText("Cooldown & Combat"), -y)
        y = y + h
        _, h = W:Dropdown(sc, LText("GCD Fill / Drain"), -y, fillDrainChoices,
            function() return db.gcdFillDrain or "fill" end,
            function(v) db.gcdFillDrain = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Slider(sc, LText("GCD Start Position"), -y,
            function() return db.gcdRotation or 12 end,
            function(v) db.gcdRotation = v; ApplyAndPreview() end, 1, 12, 1)
        y = y + h
        _, h = W:Dropdown(sc, LText("Cast Fill / Drain"), -y, fillDrainChoices,
            function() return db.castFillDrain or "fill" end,
            function(v) db.castFillDrain = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Slider(sc, LText("Cast Start Position"), -y,
            function() return db.castRotation or 12 end,
            function(v) db.castRotation = v; ApplyAndPreview() end, 1, 12, 1)
        y = y + h
        _, h = W:Toggle(sc, LText("Lock Health Color"), -y,
            function() return db.healthColorLock == true end,
            function(v) db.healthColorLock = v; ApplyAndPreview() end)
        y = y + h
    elseif activeCursorSection == "trail" then
        _, h = W:SectionHeader(sc, LText("Trail & Modifiers"), -y)
        y = y + h
        _, h = W:Toggle(sc, LText("Enable Trail"), -y,
            function() return db.enableTrail == true end,
            function(v) db.enableTrail = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Slider(sc, LText("Trail Duration"), -y,
            function() return db.trailDuration or 0.5 end,
            function(v) db.trailDuration = v; ApplyAndPreview() end, 0.1, 2.0, 0.05)
        y = y + h
        _, h = W:Slider(sc, LText("Trail Density"), -y,
            function() return db.trailDensity or 0.005 end,
            function(v) db.trailDensity = v; ApplyAndPreview() end, 0.001, 0.03, 0.001)
        y = y + h
        _, h = W:Slider(sc, LText("Trail Scale"), -y,
            function() return db.trailScale or 1.0 end,
            function(v) db.trailScale = v; ApplyAndPreview() end, 0.5, 3.0, 0.1)
        y = y + h
        _, h = W:Slider(sc, LText("Minimum Movement"), -y,
            function() return db.trailMinMovement or 0.5 end,
            function(v) db.trailMinMovement = v; ApplyAndPreview() end, 0.1, 10.0, 0.1)
        y = y + h
        _, h = W:Dropdown(sc, LText("Shift Action"), -y, modifierChoices,
            function() return db.shiftAction or "None" end,
            function(v) db.shiftAction = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Dropdown(sc, LText("Ctrl Action"), -y, modifierChoices,
            function() return db.ctrlAction or "None" end,
            function(v) db.ctrlAction = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Dropdown(sc, LText("Alt Action"), -y, modifierChoices,
            function() return db.altAction or "None" end,
            function(v) db.altAction = v; ApplyAndPreview() end)
        y = y + h
    elseif activeCursorSection == "effects" then
        _, h = W:SectionHeader(sc, LText("Special Effects"), -y)
        y = y + h
        _, h = W:Toggle(sc, LText("Enable Click Animation"), -y,
            function() return db.enableClickAnimation ~= false end,
            function(v) db.enableClickAnimation = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Slider(sc, LText("Click Effect Size"), -y,
            function() return db.clickScale or 1 end,
            function(v) db.clickScale = v; ApplyAndPreview() end, 0.5, 2.5, 0.1)
        y = y + h
        _, h = W:Slider(sc, LText("High Contrast Outer Thickness"), -y,
            function() return db.highContrastOuterThickness or 2 end,
            function(v) db.highContrastOuterThickness = v; ApplyAndPreview() end, 0, 12, 1)
        y = y + h
        _, h = W:Slider(sc, LText("High Contrast Inner Thickness"), -y,
            function() return db.highContrastInnerThickness or -4 end,
            function(v) db.highContrastInnerThickness = v; ApplyAndPreview() end, -12, 4, 1)
        y = y + h
        _, h = W:Dropdown(sc, LText("Seasonal Style"), -y, seasonalStyleChoices,
            function() return db.seasonalEffectStyle or "Candy Cane" end,
            function(v) db.seasonalEffectStyle = v; ApplyAndPreview() end)
        y = y + h
        _, h = W:Dropdown(sc, LText("Seasonal Particles"), -y, seasonalParticleChoices,
            function() return db.seasonalParticleType or "Snowflakes" end,
            function(v) db.seasonalParticleType = v; ApplyAndPreview() end)
        y = y + h
    end

    return y
end)
