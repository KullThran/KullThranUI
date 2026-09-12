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
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, 340)
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
    KT:SetAccentTextColor(lblPrev, 1)

    local previewMap = CreateFrame("Frame", nil, prevContainer, "BackdropTemplate")
    previewMap:SetSize(210, 210)
    previewMap:SetPoint("CENTER", prevContainer, "CENTER", 0, 28)
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

    local previewCompass = previewOverlay:CreateTexture(nil, "BORDER")
    previewCompass:SetSize(26, 26)
    previewCompass:SetPoint("TOPLEFT", previewMap, "TOPLEFT", 6, -6)
    previewCompass:SetTexture("Interface\\Minimap\\Minimap-TrackingBorder")
    previewCompass:SetAlpha(0.65)

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

        previewMap:SetScale(previewScale)
        ApplyPreviewShape(db.shape or "SQUARE")

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
        previewFriends:SetText(LText("Friends") .. ": " .. onlineFriends)
        previewGuild:SetText(LText("Guild") .. ": |cff00ff00" .. onlineGuild .. "|r")

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

        previewZone:ClearAllPoints()
        previewZone:SetPoint("TOP", previewMap, "TOP", tonumber(db.zoneOffsetX) or 0, -16 + (tonumber(db.zoneOffsetY) or 0))
        previewLocation:ClearAllPoints()
        previewLocation:SetPoint("TOP", previewZone, "BOTTOM", tonumber(db.locationOffsetX) or 0, -1 + (tonumber(db.locationOffsetY) or 0))
        previewCoords:ClearAllPoints()
        previewCoords:SetPoint("TOPRIGHT", previewMap, "TOPRIGHT", -12 + (tonumber(db.coordsOffsetX) or 0), -12 + (tonumber(db.coordsOffsetY) or 0))
        previewClock:ClearAllPoints()
        previewClock:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 8 + (tonumber(db.clockOffsetX) or 0), 34 + (tonumber(db.clockOffsetY) or 0))
        previewPerf:ClearAllPoints()
        previewPerf:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 8 + (tonumber(db.performanceOffsetX) or 0), 20 + (tonumber(db.performanceOffsetY) or 0))
        previewFriends:ClearAllPoints()
        previewFriends:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 8 + (tonumber(db.friendsOffsetX) or 0), 8 + (tonumber(db.friendsOffsetY) or 0))
        previewGuild:ClearAllPoints()
        previewGuild:SetPoint("BOTTOMRIGHT", previewMap, "BOTTOMRIGHT", -8 + (tonumber(db.guildOffsetX) or 0), 8 + (tonumber(db.guildOffsetY) or 0))
    end

    previewRefresh()
    y = y + (prevContainer.GetHeight and prevContainer:GetHeight() or 300) + 20

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
        if KT.BuildMinimapStatsOptionsBlock then
            return KT:BuildMinimapStatsOptionsBlock(container, W, db, RefreshMM)
        end
        return 0
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
