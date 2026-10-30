-- Modules/Minimap/Minimap_Options.lua
-- Registers the "Minimap" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks
local GetFontValues = Opt.GetFontValues
local PREVIEW_CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local cachedNativeMinimapPreview
local nativeMinimapPreviewUnavailable = false

local function IsSafePreviewValue(value, expectedType)
    if issecretvalue and issecretvalue(value) then return false end
    return expectedType == nil or type(value) == expectedType
end

local function RefreshMM()
    local M = KT:GetModule("Minimap", true)
    if M and M.Refresh then
        M:Refresh()
    end
end

KT:RegisterPage("minimap", "Minimap", 40, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.minimap
    if not db then
        KT.db.profile.minimap = KT.db.profile.minimap or {}
        db = KT.db.profile.minimap
    end

    db.enable = db.enable ~= false
    db.borderSize = math.max(1, math.min(8, math.floor((tonumber(db.borderSize) or 1) + 0.5)))
    local savedBorderColor = type(db.borderColor) == "table" and db.borderColor or {}
    db.borderColor = {
        r = tonumber(savedBorderColor.r or savedBorderColor[1]) or 0,
        g = tonumber(savedBorderColor.g or savedBorderColor[2]) or 0,
        b = tonumber(savedBorderColor.b or savedBorderColor[3]) or 0,
        a = tonumber(savedBorderColor.a or savedBorderColor[4]) or 1,
    }

    -- Live Preview (as in the last functional version): fake minimap typography & stats.
    local previewRefresh = function() end

    local function RefreshMM()
        local M = KT:GetModule("Minimap", true)
        if M and M.Refresh then
            M:Refresh()
        end
        previewRefresh()
    end

    local function UpdateMM()
        local M = KT:GetModule("Minimap", true)
        if M and M.UpdateAll then
            M:UpdateAll()
        elseif M and M.Refresh then
            M:Refresh()
        end
        previewRefresh()
    end

    local function FetchPreviewFont(fontKey)
        local fontPath = fontKey

        if LSM and fontKey then
            local fetched = LSM:Fetch("font", fontKey)
            if fetched then
                fontPath = fetched
            end
        end

        if type(fontPath) ~= "string" or not fontPath:find("\\", 1, true) then
            return "Fonts\\FRIZQT__.TTF"
        end

        return fontPath
    end

    local prevContainer = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    -- The map is scaled down when the zone name, a round ring and the shape
    -- buttons would not fit (see previewRefresh), so the box stays compact.
    local PREVIEW_HEIGHT = 340
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, PREVIEW_HEIGHT)
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    prevContainer:SetClipsChildren(true)
    if KT.AddBackdrop then
        KT:AddBackdrop(prevContainer, 0.05, 0.05, 0.05, 0.35)
    end
    if KT.AddBorder then
        KT:AddBorder(prevContainer, 0, 0, 0, 1)
    end
    if prevContainer.bgKT then
        prevContainer.bgKT:SetColorTexture(0.03, 0.03, 0.03, 0.28)
    end

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 8, -6)
    lblPrev:SetText(LText("LIVE PREVIEW"))
    -- Glass card border (Widgets.lua W:PreviewCard).
    if KT.Widgets and KT.Widgets.PreviewCard then KT.Widgets:PreviewCard(prevContainer) end
    KT:SetAccentTextColor(lblPrev, 1)

    local previewMap = CreateFrame("Frame", nil, prevContainer, "BackdropTemplate")
    -- The live minimap's size (198 px, the preview applies the scale).
    previewMap:SetSize(198, 198)
    previewMap:SetPoint("CENTER", prevContainer, "CENTER", 0, -12)
    if KT.AddBackdrop then
        KT:AddBackdrop(previewMap, 0.02, 0.03, 0.04, 0.7)
    end
    if KT.AddBorder then
        KT:AddBorder(previewMap, db.borderColor.r, db.borderColor.g, db.borderColor.b, db.borderColor.a, db.borderSize)
    end
    if previewMap.bgKT then
        previewMap.bgKT:SetColorTexture(0.03, 0.05, 0.08, 0.88)
    end

    local previewTexture = previewMap:CreateTexture(nil, "BACKGROUND")
    previewTexture:SetAllPoints()
    previewTexture:SetColorTexture(0.015, 0.02, 0.025, 1)

    -- Render a static map texture for the preview.
    -- Modern WoW clients reject CreateFrame("Minimap") and will throw a LUA_WARNING,
    -- so we use a static fallback directly instead of attempting to create one.
    local previewNativeMap = nil

    if previewNativeMap then
        -- This block is kept in case we ever find a safe way to inject a live map preview,
        -- but currently it's unreachable to prevent LUA_WARNINGs.
        previewNativeMap:SetParent(previewMap)
        previewNativeMap:ClearAllPoints()
        previewNativeMap:SetPoint("TOPLEFT", previewMap, "TOPLEFT", 1, -1)
        previewNativeMap:SetPoint("BOTTOMRIGHT", previewMap, "BOTTOMRIGHT", -1, 1)
        previewNativeMap:SetFrameLevel(previewMap:GetFrameLevel() + 1)
        previewNativeMap:EnableMouse(false)
        if previewNativeMap.SetZoom and Minimap and Minimap.GetZoom then
            pcall(previewNativeMap.SetZoom, previewNativeMap, Minimap:GetZoom())
        end
        previewNativeMap:Show()
    else
        -- Defensive fallback for clients that reject additional Minimap frames.
        -- Fetch a central piece of the faction's capital city map (Stormwind / Orgrimmar)
        -- We avoid tile 1 because it's usually just the decorative border/ocean.
        local faction = UnitFactionGroup("player")
        local mapID = (faction == "Horde") and 85 or 84
        local textures = C_Map and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID, 1)
        
        local tileIndex = (textures and #textures >= 6) and 6 or 1
        
        if textures and textures[tileIndex] then
            previewTexture:SetTexture(textures[tileIndex])
            previewTexture:SetVertexColor(0.6, 0.65, 0.7, 1)
            -- Crop the texture slightly to make it feel more "zoomed in" like a minimap
            previewTexture:SetTexCoord(0.2, 0.8, 0.2, 0.8)
        else
            previewTexture:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
            previewTexture:SetVertexColor(0.45, 0.48, 0.50, 1)
        end
    end
    local previewOverlay = CreateFrame("Frame", nil, previewMap)
    previewOverlay:SetAllPoints(previewMap)
    previewOverlay:SetFrameLevel(previewMap:GetFrameLevel() + 6)
    previewOverlay:EnableMouse(false)

    local previewShade = previewOverlay:CreateTexture(nil, "BACKGROUND")
    previewShade:SetPoint("TOPLEFT", 1, -1)
    previewShade:SetPoint("BOTTOMRIGHT", -1, 1)
    previewShade:SetColorTexture(0, 0, 0, 0.10)

    local previewRoundMask = previewMap:CreateMaskTexture()
    previewRoundMask:SetTexture(PREVIEW_CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    previewRoundMask:SetAllPoints(previewMap)
    previewTexture:AddMaskTexture(previewRoundMask)
    previewShade:AddMaskTexture(previewRoundMask)
    previewRoundMask:Hide()

    -- Real preview: the art of the zone the player is standing in, centred on the
    -- player and masked like the live minimap (round or square).
    local function BuildPlayerMapTiles()
        if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition
            and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return end
        local mapOK, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if not mapOK or not IsSafePreviewValue(mapID, "number") then return end
        local posOK, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        if not posOK or not position then return end
        local xyOK, px, py = pcall(function() return position:GetXY() end)
        if not xyOK or not IsSafePreviewValue(px, "number") or not IsSafePreviewValue(py, "number") then return end
        local layersOK, layers = pcall(C_Map.GetMapArtLayers, mapID)
        local layer = layersOK and layers and layers[1]
        local texOK, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
        if not (layer and texOK and textures and #textures > 0) then return end
        local tileW, tileH = tonumber(layer.tileWidth) or 0, tonumber(layer.tileHeight) or 0
        local layerW, layerH = tonumber(layer.layerWidth) or 0, tonumber(layer.layerHeight) or 0
        if tileW <= 0 or tileH <= 0 or layerW <= 0 or layerH <= 0 then return end
        local cols = math.ceil(layerW / tileW)
        local size = previewMap:GetWidth()
        local scale = size / (layerW * 0.12) -- the preview shows ~12% of the zone
        local tw, th = tileW * scale, tileH * scale
        local cx, cy = px * layerW * scale, py * layerH * scale
        local built = 0
        for index, file in ipairs(textures) do
            local col = (index - 1) % cols
            local row = math.floor((index - 1) / cols)
            local x0 = size / 2 + col * tw - cx
            local y0 = size / 2 + row * th - cy
            local x1, y1 = x0 + tw, y0 + th
            if x1 > 0 and x0 < size and y1 > 0 and y0 < size then
                local l, top = math.max(0, x0), math.max(0, y0)
                local r, bottom = math.min(size, x1), math.min(size, y1)
                local tile = previewMap:CreateTexture(nil, "BACKGROUND", nil, 1)
                tile:SetTexture(file)
                tile:SetTexCoord((l - x0) / tw, (r - x0) / tw, (top - y0) / th, (bottom - y0) / th)
                tile:SetPoint("TOPLEFT", previewMap, "TOPLEFT", l, -top)
                tile:SetSize(r - l, bottom - top)
                tile:AddMaskTexture(previewRoundMask)
                built = built + 1
            end
        end
        if built == 0 then return end
        previewTexture:SetColorTexture(0.02, 0.03, 0.04, 1)
        local arrow = previewMap:CreateTexture(nil, "ARTWORK", nil, 3)
        arrow:SetTexture("Interface\\Minimap\\ROTATING-MINIMAPARROW")
        arrow:SetSize(24, 24)
        arrow:SetPoint("CENTER", previewMap, "CENTER", 0, 0)
        return true
    end
    pcall(BuildPlayerMapTiles)

    local previewCircleSegments = {}
    for index = 1, 128 do
        local segment = previewOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
        segment:SetColorTexture(db.borderColor.r, db.borderColor.g, db.borderColor.b, db.borderColor.a)
        if segment.SetSnapToPixelGrid then
            segment:SetSnapToPixelGrid(false)
            segment:SetTexelSnappingBias(0)
        end
        previewCircleSegments[index] = segment
    end

    local previewRingFrame = CreateFrame("Frame", nil, previewMap)
    previewRingFrame:SetAllPoints(previewMap)
    -- Ring and square frame (+3/+4) sit under the zone plate (+5) and under the
    -- texts and buttons on previewOverlay (+6), as on the live minimap.
    previewRingFrame:SetFrameLevel(previewMap:GetFrameLevel() + 3)
    previewRingFrame:EnableMouse(false)
    -- The chosen style's square frame and zone plate (SquareMinimap.lua).
    local previewDecor = CreateFrame("Frame", nil, previewRingFrame, "BackdropTemplate")
    previewDecor:EnableMouse(false)
    previewDecor:Hide()
    local previewZonePlate = CreateFrame("Frame", nil, previewMap, "BackdropTemplate")
    previewZonePlate:EnableMouse(false)
    previewZonePlate:SetFrameLevel(previewMap:GetFrameLevel() + 5)
    previewZonePlate:Hide()
    local previewRing = CreateFrame("Frame", nil, previewRingFrame)
    previewRing:EnableMouse(false)
    local previewRingTex = previewRing:CreateTexture(nil, "ARTWORK")
    previewRingTex:SetAllPoints(previewRing)
    previewRing:Hide()

    local previewCompass = previewOverlay:CreateTexture(nil, "BORDER")
    previewCompass:SetSize(26, 26)
    previewCompass:SetPoint("TOPLEFT", previewMap, "TOPLEFT", 6, -6)
    previewCompass:SetTexture("Interface\\Minimap\\Minimap-TrackingBorder")
    previewCompass:SetAlpha(0.65)
    previewCompass:Hide() -- the live minimap has no such ring: keep the preview faithful

    local previewZone = previewOverlay:CreateFontString(nil, "OVERLAY")
    previewZone:SetPoint("BOTTOM", previewMap, "TOP", 0, 4)
    previewZone:SetJustifyH("CENTER")

    local previewLocation = previewOverlay:CreateFontString(nil, "OVERLAY")
    previewLocation:SetPoint("TOP", previewZone, "BOTTOM", 0, -1)
    previewLocation:SetJustifyH("CENTER")

    local previewCoords = previewOverlay:CreateFontString(nil, "OVERLAY")
    previewCoords:SetPoint("TOPRIGHT", previewMap, "TOPRIGHT", -6, -4)
    previewCoords:SetJustifyH("RIGHT")

    local previewClock = previewOverlay:CreateFontString(nil, "OVERLAY")
    previewClock:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 4, 28)
    previewClock:SetJustifyH("LEFT")

    local previewPerf = previewOverlay:CreateFontString(nil, "OVERLAY")
    previewPerf:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 4, 16)
    previewPerf:SetJustifyH("LEFT")

    local previewFriends = previewOverlay:CreateFontString(nil, "OVERLAY")
    previewFriends:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 4, 3)
    previewFriends:SetJustifyH("LEFT")

    local previewGuild = previewOverlay:CreateFontString(nil, "OVERLAY")
    previewGuild:SetPoint("BOTTOMRIGHT", previewMap, "BOTTOMRIGHT", -4, 3)
    previewGuild:SetJustifyH("RIGHT")


    -- The minimap's buttons, drawn by the minimap's own code (Minimap.lua and
    -- SquareMinimap.lua) at the live positions: Calendar, Tracking and Mail down
    -- the left of the top edge; Teleport, Guild, Friends and KUI options stacked
    -- on the side chosen in the options. Teleport keeps its own icon colours.
    local ICON_DIR = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\extra\\"
    local SIDE_ICONS = {
        { key = "Teleport", portal = ICON_DIR .. "PortalMinimapIconCustom.png" },
        { key = "Guild", file = ICON_DIR .. "guildminimap.png" },
        { key = "Friends", file = ICON_DIR .. "friendlistminimap.png" },
        { key = "KUISettings", file = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png" },
    }
    local CORNER_ICONS = { "calendar", "tracking", "mail" }
    local TRACKING_ATLAS = "ui-hud-minimap-tracking-up"
    local SIDE_STEP = 22
    local function PreviewButton()
        local button = CreateFrame("Button", nil, previewOverlay)
        button:SetSize(SIDE_STEP, SIDE_STEP)
        button:EnableMouse(false)
        return button
    end
    local previewSideIcons, previewCornerIcons = {}, {}
    for index, def in ipairs(SIDE_ICONS) do
        local button = PreviewButton()
        button.key = def.key
        if def.portal then
            button.isPortal = true
            button._ktPortalIcon = button:CreateTexture(nil, "ARTWORK", nil, 1)
            button._ktPortalIcon:SetTexture(def.portal)
        else
            button.Icon = button:CreateTexture(nil, "ARTWORK")
            button.Icon:SetTexture(def.file)
        end
        previewSideIcons[index] = button
    end
    for index, kind in ipairs(CORNER_ICONS) do
        local button = PreviewButton()
        button.kind = kind
        button.Icon = button:CreateTexture(nil, "ARTWORK")
        previewCornerIcons[index] = button
    end

    local function LayoutPreviewSideIcons()
        local M = KT:GetModule("Minimap", true)
        local style = M and M.StyleModernMinimapIcon
        local r, g, b = 1, 0.486, 0.039
        if KT.GetStyleAccentRGB then
            local ar, ag, ab = KT:GetStyleAccentRGB()
            if ar and ag and ab then r, g, b = ar, ag, ab end
        end

        for index, button in ipairs(previewCornerIcons) do
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", previewMap, "TOPLEFT", 0, -(index - 1) * SIDE_STEP)
            if style then
                if button.kind == "calendar" then
                    style(button, nil, 3)
                    M.SetModernCalendarIcon(button, button.Icon)
                elseif button.kind == "mail" then
                    style(button, button.Icon, 3)
                    M.SetModernMailIcon(button, false)
                else
                    style(button, button.Icon, 3)
                    local hasAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(TRACKING_ATLAS)
                    if hasAtlas then
                        button.Icon:SetAtlas(TRACKING_ATLAS)
                    else
                        button.Icon:SetTexture("Interface\\Minimap\\Tracking\\None")
                    end
                end
                if M.DecorateSideButton then M:DecorateSideButton(button, false, true) end
            end
        end

        local position = db.iconPosition
        local shown = 0
        for _, button in ipairs(previewSideIcons) do
            local visible = db["show" .. button.key .. "Icon"] ~= false
            button:SetShown(visible)
            if style then
                if button.isPortal then
                    -- The Teleport Menu look: its own icon, never recoloured.
                    style(button, nil, 3)
                    button._ktPortalIcon:ClearAllPoints()
                    button._ktPortalIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
                    button._ktPortalIcon:SetSize(16, 16)
                    button._ktPortalIcon:SetVertexColor(1, 1, 1, 1)
                else
                    style(button, button.Icon, 3)
                    button.Icon:SetVertexColor(r, g, b, 1)
                end
                if M.DecorateSideButton then M:DecorateSideButton(button, button.isPortal) end
            end
            if visible then
                local offset = shown * SIDE_STEP
                button:ClearAllPoints()
                if position == "RIGHT" then
                    button:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMRIGHT", 0, offset)
                elseif position == "TOP" then
                    button:SetPoint("BOTTOMLEFT", previewMap, "TOPLEFT", offset, 0)
                elseif position == "BOTTOM" then
                    button:SetPoint("TOPLEFT", previewMap, "BOTTOMLEFT", offset, 0)
                else
                    button:SetPoint("BOTTOMRIGHT", previewMap, "BOTTOMLEFT", 0, offset)
                end
                shown = shown + 1
            end
        end
    end

    local shapePicker = CreateFrame("Frame", nil, prevContainer)
    shapePicker:SetSize(360, 34)
    shapePicker:SetPoint("BOTTOM", prevContainer, "BOTTOM", 0, 16)

    local shapeButtons = {}

    local function ApplyPreviewBorder()
        local color = type(db.borderColor) == "table" and db.borderColor or {}
        local size = math.max(1, math.min(8, math.floor((tonumber(db.borderSize) or 1) + 0.5)))
        local red = tonumber(color.r or color[1]) or 0
        local green = tonumber(color.g or color[2]) or 0
        local blue = tonumber(color.b or color[3]) or 0
        local alpha = tonumber(color.a or color[4]) or 1

        if KT.AddBorder then
            KT:AddBorder(previewMap, red, green, blue, alpha, size)
        end

        local segmentCount = #previewCircleSegments
        local thickness = size
        local radiusX = math.max(1, (previewMap:GetWidth() * 0.5) - (thickness * 0.5))
        local radiusY = math.max(1, (previewMap:GetHeight() * 0.5) - (thickness * 0.5))
        local baseRadius = math.min(radiusX, radiusY)
        local segmentLength = (2 * baseRadius * math.sin(math.pi / segmentCount)) + math.max(1, thickness * 0.18)
        for index, segment in ipairs(previewCircleSegments) do
            local angle = ((index - 0.5) / segmentCount) * math.pi * 2
            segment:ClearAllPoints()
            segment:SetPoint("CENTER", previewMap, "CENTER", math.cos(angle) * radiusX, math.sin(angle) * radiusY)
            segment:SetSize(segmentLength, thickness)
            segment:SetRotation(angle + (math.pi * 0.5))
            segment:SetColorTexture(red, green, blue, alpha)
        end
    end

    local function ApplyPreviewShape(shape)
        local selected = (shape or "SQUARE"):upper()
        ApplyPreviewBorder()
        -- A round minimap has no square backing.
        if previewMap.SetBackdropColor then previewMap:SetBackdropColor(0.02, 0.03, 0.04, selected == "ROUND" and 0 or 0.7) end
        if previewMap.bgKT then previewMap.bgKT:SetShown(selected ~= "ROUND") end
        if selected == "ROUND" then
            previewRoundMask:Show()
            if previewNativeMap and previewNativeMap.SetMaskTexture then
                pcall(previewNativeMap.SetMaskTexture, previewNativeMap, 186178)
            end
            for _, segment in ipairs(previewCircleSegments) do segment:Show() end
            if previewMap.borderKT then
                previewMap.borderKT:Hide()
            end
        else
            previewRoundMask:Hide()
            if previewNativeMap and previewNativeMap.SetMaskTexture then
                pcall(previewNativeMap.SetMaskTexture, previewNativeMap, "Interface\\Buttons\\WHITE8X8")
            end
            for _, segment in ipairs(previewCircleSegments) do segment:Hide() end
            if previewMap.borderKT then
                previewMap.borderKT:Show()
            end
        end

        -- decorative ring of the effective style (own choice or the visual style's)
        previewRing:Hide()
        previewRoundMask:ClearAllPoints()
        previewRoundMask:SetAllPoints(previewMap)
        local minimapModule = KT:GetModule("Minimap", true)
        previewDecor:Hide()
        if selected == "SQUARE" and minimapModule and minimapModule.DrawSquareThemeFrame
            and minimapModule:DrawSquareThemeFrame(previewDecor, previewMap, minimapModule:GetDecorStyleKey()) then
            -- The style's frame replaces the flat border.
            if previewMap.borderKT then previewMap.borderKT:Hide() end
            previewDecor:Show()
        end
        if selected == "ROUND" then
            local key = db.ringStyle
            if key ~= "none" and key ~= "forever" and key ~= "retail" and key ~= "classic" then
                if minimapModule and minimapModule.GetRingStyleKey then
                    key = minimapModule:GetRingStyleKey()
                else
                    local VT = KT.VisualThemes
                    local theme = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
                    key = ({ forever = "forever", retail = "retail", classic = "classic" })[theme] or "none"
                end
            end
            for _, d in ipairs(KT.MinimapRingStyles or {}) do
                if d.key == key and key ~= "none" then
                    -- As on the live minimap: the map fills the preview and the
                    -- ring sits around it, reaching past its edges.
                    if KT.DrawMinimapRing(d, previewRing, previewRingTex, previewMap, previewMap:GetWidth()) then
                        previewRing:Show()
                        for _, segment in ipairs(previewCircleSegments) do segment:Hide() end
                    end
                end
            end
        end

        for _, btn in ipairs(shapeButtons) do
            if btn.shapeValue == selected then
                KT:SetAccentBackdropBorder(btn, 1)
                btn:SetBackdropColor(0.12, 0.12, 0.12, 1)
            else
                btn:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
                btn:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
            end
        end
    end

    local function CreateShapeButton(label, shape, xOffset)
        local btn = CreateFrame("Button", nil, shapePicker, "BackdropTemplate")
        btn:SetSize(160, 30)
        btn:SetPoint("LEFT", shapePicker, "LEFT", xOffset, 0)
        btn.shapeValue = shape
        if KT.AddBackdrop then
            KT:AddBackdrop(btn, 0.05, 0.05, 0.05, 0.92)
        end
        if KT.AddBorder then
            KT:AddBorder(btn, 0.15, 0.15, 0.15, 1)
        end

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        txt:SetPoint("CENTER")
        txt:SetText(label)
        txt:SetTextColor(0.92, 0.92, 0.92)

        btn:SetScript("OnClick", function()
            db.shape = shape
            RefreshMM()
        end)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.1, 1)
            KT:SetAccentBackdropBorder(self, 1)
        end)
        btn:SetScript("OnLeave", function()
            ApplyPreviewShape(db.shape or "SQUARE")
        end)

        shapeButtons[#shapeButtons + 1] = btn
        return btn
    end

    CreateShapeButton("Square Minimap", "SQUARE", 10)
    CreateShapeButton("Round Minimap", "ROUND", 190)

    local function SetPreviewFont(fontString, fontPath, size, outline, hasShadow)
        local f = FetchPreviewFont(fontPath)
        fontString:SetFont(f, size, outline)
        if hasShadow then
            fontString:SetShadowOffset(1, -1)
            fontString:SetShadowColor(0, 0, 0, 1)
        else
            fontString:SetShadowOffset(0, 0)
        end
    end

    previewRefresh = function()
        local zoneFont = db.zoneFont or "Fonts\\FRIZQT__.TTF"
        local zoneSize = db.zoneFontSize or 12
        local zoneOutline = db.zoneFontOutline or "OUTLINE"
        local statsFont = db.statsFont or "Fonts\\FRIZQT__.TTF"
        local statsSize = db.statsFontSize or 11
        local statsOutline = db.statsFontOutline or "OUTLINE"
        local previewScale = math.max(0.75, math.min(db.scale or 1, 1.35))

        ApplyPreviewShape(db.shape or "SQUARE")
        -- Room above the map for the label row, the zone name (and its plate)
        -- and the lift over a round style's ring, and below it for the ring
        -- reaching past the map and the shape buttons; offsets in map scale.
        local fitModule = KT:GetModule("Minimap", true)
        local fitLift = fitModule and fitModule.GetZoneLift and fitModule:GetZoneLift(198) or 0
        local aboveMap = math.max(0, fitLift + (tonumber(db.zoneOffsetY) or 0) + 24)
        -- A style's square frame reaches up to 18 px past the map.
        local belowMap = previewDecor:IsShown() and 18 or 0
        if previewRing:IsShown() then
            local _, _, _, _, ringDY = previewRing:GetPoint(1)
            belowMap = math.max(0, (previewRing:GetHeight() or 0) / 2 - (ringDY or 0) - 99)
        end
        local LABEL_ROW, PICKER_ROOM = 28, 16 + 34 + 8
        local fitScale = (PREVIEW_HEIGHT - LABEL_ROW - PICKER_ROOM) / (aboveMap + 198 + belowMap)
        previewScale = math.max(0.5, math.min(previewScale, fitScale))
        previewMap:SetScale(previewScale)
        previewMap:ClearAllPoints()
        previewMap:SetPoint("TOP", prevContainer, "TOP", 0, -(LABEL_ROW / previewScale + aboveMap))

        SetPreviewFont(previewZone, zoneFont, zoneSize + 2, zoneOutline, true)
        SetPreviewFont(previewLocation, zoneFont, math.max(zoneSize - 1, 10), zoneOutline, false)
        SetPreviewFont(previewCoords, statsFont, statsSize, statsOutline, true)
        SetPreviewFont(previewClock, statsFont, statsSize + 2, statsOutline, false)
        SetPreviewFont(previewPerf, statsFont, statsSize, statsOutline, false)
        SetPreviewFont(previewFriends, statsFont, statsSize + 1, statsOutline, false)
        SetPreviewFont(previewGuild, statsFont, statsSize + 1, statsOutline, false)

        local zoneText, subZoneText = LText("Current Zone"), ""
        local zoneOK, liveZone = pcall(GetMinimapZoneText)
        if zoneOK and IsSafePreviewValue(liveZone, "string") and liveZone ~= "" then zoneText = liveZone end
        local subZoneOK, liveSubZone = pcall(GetZoneText)
        if subZoneOK and IsSafePreviewValue(liveSubZone, "string") then subZoneText = liveSubZone end
        previewZone:SetText(zoneText)
        previewLocation:SetText(subZoneText)

        local coordinateText = "--, --"
        if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
            local mapOK, mapID = pcall(C_Map.GetBestMapForUnit, "player")
            if mapOK and IsSafePreviewValue(mapID, "number") then
                local positionOK, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
                if positionOK and position and IsSafePreviewValue(position) then
                    local xyOK, x, y = pcall(function() return position:GetXY() end)
                    if xyOK and IsSafePreviewValue(x, "number") and IsSafePreviewValue(y, "number") then
                        coordinateText = string.format("%.1f, %.1f", x * 100, y * 100)
                    end
                end
            end
        end
        previewCoords:SetText(coordinateText)
        previewClock:SetText(date("%H:%M"))

        local perfParts = {}
        if db.showFPS then
            local fpsOK, fps = pcall(GetFramerate)
            if fpsOK and IsSafePreviewValue(fps, "number") then
                perfParts[#perfParts + 1] = string.format("|cffd7f3ff%dFPS|r", math.floor(fps + 0.5))
            end
        end
        if db.showMS then
            local netOK, _, _, homeMS, worldMS = pcall(GetNetStats)
            local latency = IsSafePreviewValue(worldMS, "number") and worldMS or homeMS
            if netOK and IsSafePreviewValue(latency, "number") then
                perfParts[#perfParts + 1] = string.format("|cffffb347%dMS|r", math.floor(latency + 0.5))
            end
        end
        previewPerf:SetText(table.concat(perfParts, " | "))

        local onlineFriends = 0
        if C_FriendList and C_FriendList.GetNumOnlineFriends then
            local friendsOK, count = pcall(C_FriendList.GetNumOnlineFriends)
            if friendsOK and IsSafePreviewValue(count, "number") then onlineFriends = count end
        end
        local onlineGuild = 0
        if GetNumGuildMembers then
            local guildOK, _, count = pcall(GetNumGuildMembers)
            if guildOK and IsSafePreviewValue(count, "number") then onlineGuild = count end
        end
        previewFriends:SetText(string.format(LText("Friends: %s"), tostring(onlineFriends)))
        previewGuild:SetText(string.format(LText("Guild: %s"), "|cff00ff00" .. tostring(onlineGuild) .. "|r"))

        local zR, zG, zB = 1, 1, 1
        local pvpOK, pvpType = pcall(GetZonePVPInfo)
        if pvpOK then
            if pvpType == "sanctuary" then zR, zG, zB = 0.41, 0.8, 0.94
            elseif pvpType == "arena" then zR, zG, zB = 1, 0.1, 0.1
            elseif pvpType == "friendly" then zR, zG, zB = 0.1, 1, 0.1
            elseif pvpType == "hostile" then zR, zG, zB = 1, 0.1, 0.1
            elseif pvpType == "contested" then zR, zG, zB = 1, 0.7, 0 end
        end
        previewZone:SetTextColor(zR, zG, zB)
        previewLocation:SetTextColor(0, 0.75, 1)
        previewCoords:SetTextColor(1, 1, 1)
        previewClock:SetTextColor(1, 1, 1)
        previewFriends:SetTextColor(0, 0.7, 1)
        previewGuild:SetTextColor(0.2, 1, 0.2)

        if db.showZone ~= false then
            previewZone:Show()
            previewLocation:Show()
        else
            previewZone:Hide()
            previewLocation:Hide()
        end

        if db.showCoords ~= false then
            previewCoords:Show()
        else
            previewCoords:Hide()
        end

        if db.showClock ~= false then
            previewClock:Show()
        else
            previewClock:Hide()
        end

        if db.showFPS ~= false or db.showMS ~= false then
            previewPerf:Show()
        else
            previewPerf:Hide()
        end
        previewFriends:SetShown(db.showFriends ~= false)
        previewGuild:SetShown(db.showGuild ~= false)

        -- Same anchors as the live minimap (ApplyZoneAnchor / ApplyElementOffsets):
        -- the zone name above the map, lifted over a round style's ring.
        local liveMinimap = KT:GetModule("Minimap", true)
        local zoneLift = liveMinimap and liveMinimap.GetZoneLift and liveMinimap:GetZoneLift(previewMap:GetWidth()) or 0
        previewZone:ClearAllPoints()
        previewZone:SetPoint("BOTTOM", previewMap, "TOP", tonumber(db.zoneOffsetX) or 0, (tonumber(db.zoneOffsetY) or 0) + zoneLift)
        -- Zone plate of the style: square shape always, round shape for the Visual Styles.
        previewZonePlate:Hide()
        local minimapModule = KT:GetModule("Minimap", true)
        if db.showZone ~= false and minimapModule and minimapModule.DrawZonePlate then
            local styleKey = minimapModule:GetDecorStyleKey()
            if (db.shape or "SQUARE") == "SQUARE" or styleKey ~= "kui" then
                previewZonePlate:ClearAllPoints()
                previewZonePlate:SetPoint("CENTER", previewZone, "CENTER", 0, 0)
                minimapModule:DrawZonePlate(previewZonePlate, styleKey, previewZone:GetStringWidth())
            end
        end
        previewLocation:ClearAllPoints()
        previewLocation:SetPoint("TOP", previewZone, "BOTTOM", tonumber(db.locationOffsetX) or 0, -1 + (tonumber(db.locationOffsetY) or 0))
        previewCoords:ClearAllPoints()
        previewCoords:SetPoint("TOPRIGHT", previewMap, "TOPRIGHT", -6 + (tonumber(db.coordsOffsetX) or 0), -4 + (tonumber(db.coordsOffsetY) or 0))
        previewClock:ClearAllPoints()
        previewClock:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 4 + (tonumber(db.clockOffsetX) or 0), 28 + (tonumber(db.clockOffsetY) or 0))
        previewPerf:ClearAllPoints()
        previewPerf:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 4 + (tonumber(db.performanceOffsetX) or 0), 16 + (tonumber(db.performanceOffsetY) or 0))
        previewFriends:ClearAllPoints()
        previewFriends:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 4 + (tonumber(db.friendsOffsetX) or 0), 3 + (tonumber(db.friendsOffsetY) or 0))
        previewGuild:ClearAllPoints()
        previewGuild:SetPoint("BOTTOMRIGHT", previewMap, "BOTTOMRIGHT", -4 + (tonumber(db.guildOffsetX) or 0), 3 + (tonumber(db.guildOffsetY) or 0))
        LayoutPreviewSideIcons()
    end

    previewRefresh()
    y = y + (prevContainer.GetHeight and prevContainer:GetHeight() or 300) + 20

    -- Minimap Style cards (like Armory / Bags): picking one clears a forced
    -- square or ring style so the card shows in the preview and in game.
    local ringTilesPaint
    if KT.VisualThemes and KT.VisualThemes.AddStyleCards then
        y = KT.VisualThemes:AddStyleCards(sc, y, LText("Minimap Style"), db, function()
            db.squareStyle, db.ringStyle = nil, nil
            if ringTilesPaint then ringTilesPaint() end
            local M = KT:GetModule("Minimap", true)
            if M and M.UpdateThemeDecor then M:UpdateThemeDecor() end
            RefreshMM()
        end)
    end

    if not (BeginOptionBlocks and AddOptionBlock and EndOptionBlocks) then
        return y
    end

    local cols = BeginOptionBlocks(sc, y + 10)

    AddOptionBlock(cols, "left", "Minimap", function(container)
            local by = 0
            _, h = W:Toggle(container, "Enable Module", -by,
                function() return db.enable ~= false end,
                function(v) db.enable = v; Reload() end); by = by + h

            _, h = W:Dropdown(container, "Shape", -by,
                { ["SQUARE"] = "Square", ["ROUND"] = "Round" },
                function() return db.shape or "SQUARE" end,
                function(v) db.shape = v; RefreshMM() end); by = by + h

            -- Ring style picker: visual tiles (Auto + one per style), like the Elite/Rare portrait picker
            do
                local ringHolder = CreateFrame("Frame", nil, container)
                ringHolder:SetPoint("TOPLEFT", 10, -by)
                ringHolder:SetSize(290, 214)
                local lbl = ringHolder:CreateFontString(nil, "OVERLAY")
                lbl:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                lbl:SetPoint("TOPLEFT", 0, 0)
                lbl:SetText(LText("Minimap Frame Style"))
                local MASK = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_mask.tga"
                local tiles = {}
                local function Current()
                    local k = db.ringStyle
                    if k == "none" or k == "forever" or k == "retail" or k == "classic" then return k end
                    return "auto"
                end
                -- Glow tiles (ThemeWindowFrame.lua), each in its style's colours;
                -- Auto takes the Minimap Style it follows.
                local VT = KT.VisualThemes
                local function Paint()
                    local cur = Current()
                    local M = KT:GetModule("Minimap", true)
                    for key, btn in pairs(tiles) do
                        local styleKey = key
                        if key == "auto" then styleKey = M and M.GetModuleStyleKey and M:GetModuleStyleKey() or "kui" end
                        if VT and VT.PaintGlowTile then
                            local left, right = VT:GlowTileColors(styleKey)
                            VT:PaintGlowTile(btn, left, right, key == cur)
                        end
                    end
                end
                local defs = { { key = "auto", label = "Auto" } }
                for _, d in ipairs(KT.MinimapRingStyles or {}) do defs[#defs + 1] = d end
                for index, def in ipairs(defs) do
                    local btn = CreateFrame("Button", nil, ringHolder, "BackdropTemplate")
                    btn:SetSize(90, 92)
                    local col, row = (index - 1) % 3, math.floor((index - 1) / 3)
                    btn:SetPoint("TOPLEFT", col * 96, -22 - row * 98)
                    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
                    local D = 46
                    if def.key ~= "auto" then
                        local disc = btn:CreateTexture(nil, "BACKGROUND")
                        disc:SetSize(D, D)
                        disc:SetPoint("TOP", 0, -12)
                        disc:SetTexture(MASK)
                        disc:SetVertexColor(0.26, 0.33, 0.18, 1)
                        if def.key == "none" then
                            disc:SetTexture("Interface\\Buttons\\WHITE8X8")
                            disc:SetVertexColor(0.26, 0.33, 0.18, 1)
                            local e = btn:CreateTexture(nil, "OVERLAY")
                            e:SetColorTexture(0, 0, 0, 1)
                            e:SetPoint("TOPLEFT", disc, -1, 1); e:SetPoint("BOTTOMRIGHT", disc, 1, -1)
                            e:SetDrawLayer("BORDER")
                        else
                            local rg = CreateFrame("Frame", nil, btn)
                            rg:SetFrameLevel(btn:GetFrameLevel() + 2)
                            local t = rg:CreateTexture(nil, "ARTWORK")
                            t:SetAllPoints(rg)
                            KT.DrawMinimapRing(def, rg, t, disc, D)
                        end
                    end
                    local fs = btn:CreateFontString(nil, "OVERLAY")
                    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
                    fs:SetPoint("BOTTOM", 0, 6)
                    fs:SetText(LText(def.label))
                    if VT and VT.SkinGlowTile then VT:SkinGlowTile(btn, fs) end
                    if def.key == "auto" then
                        local sub = btn:CreateFontString(nil, "OVERLAY")
                        sub:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
                        sub:SetPoint("CENTER", 0, 8)
                        sub:SetText(LText("follows the\nvisual style"))
                    end
                    btn:SetScript("OnClick", function()
                        if def.key == "auto" then
                            db.ringStyle = nil
                        else
                            db.ringStyle = def.key
                            if def.key ~= "none" then db.shape = "ROUND" end -- the ring art is circular
                        end
                        Paint()
                        RefreshMM()
                    end)
                    tiles[def.key] = btn
                end
                Paint()
                ringTilesPaint = Paint
                by = by + 226 -- room for the tile glow (ThemeWindowFrame.lua)
            end

            _, h = W:Slider(container, "Scale", -by,
                function() return db.scale or 1.2 end,
                function(v) db.scale = v; RefreshMM() end, 0.5, 2.0, 0.01); by = by + h

            _, h = W:Slider(container, "Border Size", -by,
                function() return db.borderSize or 1 end,
                function(v) db.borderSize = v; RefreshMM() end, 1, 8, 1); by = by + h

            _, h = W:ColorSwatch(container, "Border Color", -by,
                function()
                    local color = db.borderColor or {}
                    return color.r or 0, color.g or 0, color.b or 0, color.a or 1
                end,
                function(r, g, b, a)
                    db.borderColor = { r = r, g = g, b = b, a = a or 1 }
                    RefreshMM()
                end, true); by = by + h

            _, h = W:Toggle(container, "Show Zone Text", -by,
                function() return db.showZone ~= false end,
                function(v) db.showZone = v; RefreshMM() end); by = by + h
            _, h = W:Toggle(container, "Show Coords", -by,
                function() return db.showCoords ~= false end,
                function(v) db.showCoords = v; RefreshMM() end); by = by + h
            _, h = W:Toggle(container, "Show Friends", -by,
                function() return db.showFriends ~= false end,
                function(v) db.showFriends = v; RefreshMM() end); by = by + h
            _, h = W:Toggle(container, "Show Guild", -by,
                function() return db.showGuild ~= false end,
                function(v) db.showGuild = v; RefreshMM() end); by = by + h

            _, h = W:SectionHeader(container, "Side Icons", -by); by = by + h
            _, h = W:Dropdown(container, "Icon Position", -by,
                { LEFT = "Left", RIGHT = "Right", TOP = "Top", BOTTOM = "Bottom" },
                function() return db.iconPosition or "LEFT" end,
                function(v) db.iconPosition = v; RefreshMM() end,
                { "LEFT", "RIGHT", "TOP", "BOTTOM" }); by = by + h
            _, h = W:Toggle(container, "Show Teleport Menu Icon", -by,
                function() return db.showTeleportIcon ~= false end,
                function(v) db.showTeleportIcon = v; RefreshMM() end); by = by + h
            _, h = W:Toggle(container, "Show Friends Icon", -by,
                function() return db.showFriendsIcon ~= false end,
                function(v) db.showFriendsIcon = v; RefreshMM() end); by = by + h
            _, h = W:Toggle(container, "Show Guild Icon", -by,
                function() return db.showGuildIcon ~= false end,
                function(v) db.showGuildIcon = v; RefreshMM() end); by = by + h
            _, h = W:Toggle(container, "Show KUI Options Icon", -by,
                function() return db.showKUISettingsIcon ~= false end,
                function(v) db.showKUISettingsIcon = v; RefreshMM() end); by = by + h

            _, h = W:SectionHeader(container, "Zone Font", -by); by = by + h
            _, h = W:Dropdown(container, "Font", -by, GetFontValues,
                function() return db.zoneFont or "AAA_ITC_Avant_Garde" end,
                function(v) db.zoneFont = v; UpdateMM() end); by = by + h
            _, h = W:Slider(container, "Size", -by,
                function() return db.zoneFontSize or 12 end,
                function(v) db.zoneFontSize = v; UpdateMM() end, 8, 24, 1); by = by + h
            _, h = W:Dropdown(container, "Outline", -by,
                { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
                function() return db.zoneFontOutline or "OUTLINE" end,
                function(v) db.zoneFontOutline = v; UpdateMM() end); by = by + h

            return by
    end)

    AddOptionBlock(cols, "right", "Minimap Stats", function(container)
        local by = 0
        _, h = W:Toggle(container, "Show FPS", -by,
            function() return db.showFPS ~= false end,
            function(v) db.showFPS = v; RefreshMM() end); by = by + h
        _, h = W:Toggle(container, "Show MS", -by,
            function() return db.showMS ~= false end,
            function(v) db.showMS = v; RefreshMM() end); by = by + h
        _, h = W:Toggle(container, "Show Clock", -by,
            function() return db.showClock ~= false end,
            function(v) db.showClock = v; RefreshMM() end); by = by + h

        _, h = W:SectionHeader(container, "Stats Font", -by); by = by + h
        _, h = W:Dropdown(container, "Font", -by, GetFontValues,
            function() return db.statsFont or "AAA_ITC_Avant_Garde" end,
            function(v) db.statsFont = v; RefreshMM() end, nil, "font"); by = by + h
        _, h = W:Slider(container, "Size", -by,
            function() return db.statsFontSize or 11 end,
            function(v) db.statsFontSize = v; RefreshMM() end, 8, 24, 1); by = by + h
        _, h = W:Dropdown(container, "Outline", -by,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.statsFontOutline or "OUTLINE" end,
            function(v) db.statsFontOutline = v; RefreshMM() end); by = by + h

        return by
    end)

    AddOptionBlock(cols, "left", "Minimap Buttons", function(container)
        if KT.BuildMinimapButtonOptionsBlock then
            return KT:BuildMinimapButtonOptionsBlock(container, W)
        end
        return 0
    end)

    AddOptionBlock(cols, "right", "Element Positions", function(container)
        local by = 0
        local function AddPosition(label, key)
            _, h = W:SectionHeader(container, label, -by); by = by + h
            _, h = W:Slider(container, "X Offset", -by,
                function() return tonumber(db[key .. "OffsetX"]) or 0 end,
                function(v) db[key .. "OffsetX"] = v; RefreshMM() end, -120, 120, 1); by = by + h
            _, h = W:Slider(container, "Y Offset", -by,
                function() return tonumber(db[key .. "OffsetY"]) or 0 end,
                function(v) db[key .. "OffsetY"] = v; RefreshMM() end, -120, 120, 1); by = by + h
        end
        AddPosition("Zone", "zone")
        AddPosition("Location", "location")
        AddPosition("Coordinates", "coords")
        AddPosition("Clock", "clock")
        AddPosition("FPS / MS", "performance")
        AddPosition("Friends", "friends")
        AddPosition("Guild", "guild")
        return by
    end)

    y = EndOptionBlocks(cols)

    return y
end)
