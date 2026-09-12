local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc
local next = next
local ipairs = ipairs
local type = type
local tonumber = tonumber
local math_max = math.max

local BLANK_TEX   = "Interface\\Buttons\\WHITE8x8"

local function NeutralBackdrop(frame, transparent)
    if not frame or frame.backdrop then return end
    S:CreateBackdrop(frame, transparent)
end

local function InnerBackdrop(frame)
    if not frame then return end
    S:ContentShade(frame)
end

local function HideDecos(frame)
    if not frame then return end
    for _, k in ipairs({
        "Background","Bg","BgTop","BgBottom","BgLeft","BgRight",
        "BgTopLeft","BgTopRight","BgBottomLeft","BgBottomRight",
        "TopBorder","BottomBorder","LeftBorder","RightBorder",
        "TopBorderLeft","TopBorderRight","BottomBorderLeft","BottomBorderRight",
        "TitleBg","TitleBgLeft","TitleBgRight",
        "NineSlice","Inset","InsetBg",
        "TopFiligree","BottomFiligree","FilligreeOverlay",
        "PortraitOverlay","TopTileStreaks","BotTileStreaks",
    }) do
        if frame[k] then
            if frame[k].SetAlpha then frame[k]:SetAlpha(0) end
            if frame[k].Hide     then frame[k]:Hide()     end
        end
    end
end

local function SkinIconButton(btn)
    if not btn or btn._ktIconSkinned then return end
    
    -- Limpieza no destructiva para mantener el icono
    if btn.NineSlice then btn.NineSlice:SetAlpha(0) end
    if btn.Border then btn.Border:SetAlpha(0) end
    
    if btn.SetHighlightTexture then
        btn:SetHighlightTexture(BLANK_TEX)
        local hl = btn:GetHighlightTexture()
        if hl then hl:SetVertexColor(1,1,1,0.15); hl:SetBlendMode("ADD") end
    end
    if btn.SetPushedTexture then
        btn:SetPushedTexture(BLANK_TEX)
        local push = btn:GetPushedTexture()
        if push then push:SetVertexColor(0,0,0,0.3) end
    end
    
    S:CreateBackdrop(btn)
    btn._ktIconSkinned = true
end

local function SkinScrollBar(sb)
    if sb then S:HandleScrollBar(sb) end
end

local function StyleTopPanel(frame)
    if not frame then return end

    S:CreateBackdrop(frame, true)
    if frame.backdrop then
        S:RegisterBlizzardWindowBackground(frame.backdrop)
        frame.backdrop:SetBackdropBorderColor(0.14, 0.14, 0.17, 1)
    end

    if not frame._ktWorldMapAccentLine then
        local line = frame:CreateTexture(nil, 'OVERLAY', nil, 7)
        line:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 1, 1)
        line:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -1, 1)
        line:SetHeight(1)
        frame._ktWorldMapAccentLine = line

        if S.RegisterBlizzardAccentRefresh then
            S:RegisterBlizzardAccentRefresh(line, function(texture, color)
                texture:SetColorTexture(color[1], color[2], color[3], 0.48)
            end)
        else
            local color = S:GetAccentColor()
            line:SetColorTexture(color[1], color[2], color[3], 0.48)
        end
    end
end

local function StyleQuestSearchBox(searchBox)
    if not searchBox then return end

    -- SearchBoxTemplate is made from three atlas textures. On the world map
    -- those regions can retain their original anchor while the real edit box
    -- is laid out in the quest header, leaving an empty ornamental shell under
    -- the breadcrumbs. Remove the native shell and use only the KUI surface.
    S:StripTextures(searchBox, true)
    for _, key in ipairs({ 'Left', 'Middle', 'Right', 'Background' }) do
        local texture = searchBox[key]
        if texture then
            if texture.SetTexture then texture:SetTexture(nil) end
            if texture.SetAlpha then texture:SetAlpha(0) end
            if texture.Hide then texture:Hide() end
        end
    end

    S:HandleEditBox(searchBox)
    StyleTopPanel(searchBox)

    -- Anchor the Modern KUI backdrop explicitly to the live EditBox after the
    -- inherited three-piece border has been removed.
    if searchBox.backdrop then
        searchBox.backdrop:ClearAllPoints()
        searchBox.backdrop:SetPoint('TOPLEFT', searchBox, 'TOPLEFT', -1, 1)
        searchBox.backdrop:SetPoint('BOTTOMRIGHT', searchBox, 'BOTTOMRIGHT', 1, -1)
        searchBox.backdrop:SetBackdropColor(0.035, 0.035, 0.045, 0.96)
        searchBox.backdrop:SetBackdropBorderColor(0.14, 0.14, 0.17, 1)
        searchBox.backdrop:Show()
        searchBox.backdrop:SetAlpha(1)
    end

    if searchBox.Instructions then
        S:HandleFont(searchBox.Instructions)
    end
end

local function StyleMapNavSeparators(navBar)
    if not (navBar and navBar.navList) then return end

    for index, button in ipairs(navBar.navList) do
        if button then
            button._ktNavSpacing = 12

            -- NavBar_CheckLength shows the selected artwork again every time
            -- the breadcrumb chain changes. Keep all native crumb chrome off;
            -- the KUI backdrop and accent separators replace it.
            for _, key in ipairs({ 'Left', 'arrowUp', 'arrowDown', 'selected' }) do
                local texture = button[key]
                if texture then
                    texture:SetAlpha(0)
                    texture:Hide()
                end
            end

            local previous = index > 1 and navBar.navList[index - 1] or nil
            local showSeparator = previous and previous:IsShown() and button:IsShown()

            if index > 1 and not button._ktWorldMapSeparator then
                local separator = button:CreateTexture(nil, 'OVERLAY', nil, 7)
                separator:SetSize(1, 16)
                separator:SetPoint('RIGHT', button, 'LEFT', -6, 0)
                button._ktWorldMapSeparator = separator

                if S.RegisterBlizzardAccentRefresh then
                    S:RegisterBlizzardAccentRefresh(separator, function(texture, color)
                        texture:SetColorTexture(color[1], color[2], color[3], 1)
                    end)
                else
                    local color = S:GetAccentColor()
                    separator:SetColorTexture(color[1], color[2], color[3], 1)
                end
            end

            if button._ktWorldMapSeparator then
                local color = S:GetAccentColor()
                button._ktWorldMapSeparator:SetColorTexture(color[1], color[2], color[3], 1)
            end

            if index > 1 and previous and previous:IsShown() and button:IsShown() then
                button:ClearAllPoints()
                button:SetPoint('LEFT', previous, 'RIGHT', 12, 0)
            end

            if button._ktWorldMapSeparator then
                button._ktWorldMapSeparator:SetShown(showSeparator and true or false)
            end
        end
    end
end

local MAP_NAV_CHROME = {
    'InsetBorderBottomLeft',
    'InsetBorderBottomRight',
    'InsetBorderBottom',
    'InsetBorderLeft',
    'InsetBorderRight',
}

local function HideMapNavChrome(navBar)
    if not navBar then return end

    -- Blizzard restores these atlas regions during navigation refreshes.
    -- All five ornamental inset textures live on the BORDER draw layer;
    -- disabling the layer prevents later Show/SetAtlas calls reviving them.
    if navBar.DisableDrawLayer then
        navBar:DisableDrawLayer('BORDER')
    end
    S:StripTextures(navBar, true)
    if navBar.overlay then
        S:StripTextures(navBar.overlay, true)
    end

    for _, key in ipairs(MAP_NAV_CHROME) do
        local texture = navBar[key]
        if texture then
            if texture.SetTexture then texture:SetTexture(nil) end
            if texture.SetAlpha then texture:SetAlpha(0) end
            if texture.Hide then texture:Hide() end
        end
    end

    if navBar.backdrop then
        navBar.backdrop:SetAlpha(0)
        navBar.backdrop:Hide()
    end
end

local function IsDarkTextColor(r, g, b)
    if r == nil or g == nil or b == nil then return false end
    return (r + g + b) < 0.36
end

local function ReplaceDarkInlineColor(hex)
    local rr = tonumber(hex:sub(1, 2), 16) or 255
    local gg = tonumber(hex:sub(3, 4), 16) or 255
    local bb = tonumber(hex:sub(5, 6), 16) or 255
    if (rr + gg + bb) < 600 then
        return "|cffffffff"
    end
    return "|cff" .. hex
end

local function ReplaceDarkHTMLColor(hex)
    local rr = tonumber(hex:sub(1, 2), 16) or 255
    local gg = tonumber(hex:sub(3, 4), 16) or 255
    local bb = tonumber(hex:sub(5, 6), 16) or 255
    if (rr + gg + bb) < 600 then
        return "#ffffff"
    end
    return "#" .. hex
end

local function ForceReadableQuestFont(fs, useGold)
    if not (fs and fs.SetTextColor) then return end

    if fs.SetAlpha then
        fs:SetAlpha(1)
    end
    if fs.SetDrawLayer then
        fs:SetDrawLayer("OVERLAY")
    end
    if fs.SetShadowColor then
        fs:SetShadowColor(0, 0, 0, 1)
        if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
    end

    if useGold then
        fs:SetTextColor(1, 0.82, 0, 1)
    else
        fs:SetTextColor(1, 1, 1, 1)
    end

    if hooksecurefunc and not fs._ktWorldMapReadableHooked then
        hooksecurefunc(fs, "SetTextColor", function(self)
            if self._ktWorldMapReadableGuard then return end
            self._ktWorldMapReadableGuard = true
            if useGold then
                self:SetTextColor(1, 0.82, 0, 1)
            else
                self:SetTextColor(1, 1, 1, 1)
            end
            if self.SetShadowColor then
                self:SetShadowColor(0, 0, 0, 1)
                if self.SetShadowOffset then self:SetShadowOffset(1, -1) end
            end
            self._ktWorldMapReadableGuard = nil
        end)
        if fs.SetShadowColor then
            hooksecurefunc(fs, "SetShadowColor", function(self, r, g, b, a)
                if self._ktWorldMapShadowGuard then return end
                if r ~= 0 or g ~= 0 or b ~= 0 or a ~= 1 then
                    self._ktWorldMapShadowGuard = true
                    self:SetShadowColor(0, 0, 0, 1)
                    if self.SetShadowOffset then self:SetShadowOffset(1, -1) end
                    self._ktWorldMapShadowGuard = nil
                end
            end)
        end
        if fs.SetFontObject then
            hooksecurefunc(fs, "SetFontObject", function(self)
                if self._ktWorldMapFontObjGuard then return end
                self._ktWorldMapFontObjGuard = true
                if self.SetShadowColor then self:SetShadowColor(0, 0, 0, 1) end
                if self.SetShadowOffset then self:SetShadowOffset(1, -1) end
                self._ktWorldMapFontObjGuard = nil
            end)
        end
        if fs.SetFont then
            hooksecurefunc(fs, "SetFont", function(self)
                if self._ktWorldMapFontGuard then return end
                self._ktWorldMapFontGuard = true
                if self.SetShadowColor then self:SetShadowColor(0, 0, 0, 1) end
                if self.SetShadowOffset then self:SetShadowOffset(1, -1) end
                self._ktWorldMapFontGuard = nil
            end)
        end
        if fs.SetAlpha then
            hooksecurefunc(fs, "SetAlpha", function(self, alpha)
                if self._ktWorldMapAlphaGuard then return end
                if type(alpha) == "number" and alpha < 1 then
                    self._ktWorldMapAlphaGuard = true
                    self:SetAlpha(1)
                    self._ktWorldMapAlphaGuard = nil
                end
            end)
        end
        fs._ktWorldMapReadableHooked = true
    end
end

local function RefreshWorldMapQuestText(frame)
    if not frame then return end

    local seen = {}

    local function ApplyToFontString(fs)
        if not fs then return end
        local objType = fs.GetObjectType and fs:GetObjectType()
        if objType ~= "FontString" and objType ~= "SimpleHTML" then return end

        local text = fs.GetText and fs:GetText()
        local lower = type(text) == "string" and text:lower() or ""
        local name = fs.GetName and fs:GetName()
        local _, size = fs.GetFont and fs:GetFont()
        local useGold =
            lower:find("quest", 1, true) or
            lower:find("objectives", 1, true) or
            lower:find("rewards", 1, true) or
            lower:find("description", 1, true) or
            (type(name) == "string" and (
                name:find("Title", 1, true) or
                name:find("Header", 1, true) or
                name:find("QuestName", 1, true) or
                name:find("QuestTitle", 1, true)
            )) or
            ((size or 0) >= 15)

        if type(text) == "string" and text ~= "" and fs.SetText then
            local cleaned = text
            local count = 0
            cleaned, count = cleaned:gsub("|c[fF][fF](%x%x%x%x%x%x)", ReplaceDarkInlineColor)
            local htmlCount = 0
            cleaned, htmlCount = cleaned:gsub("#(%x%x%x%x%x%x)", ReplaceDarkHTMLColor)
            if (count + htmlCount) > 0 and cleaned ~= text then
                fs:SetText(cleaned)
                text = cleaned
                lower = cleaned:lower()
            end
        end

        local forceReadable = useGold
            or (type(text) == "string" and text ~= "")
            or lower:find("/", 1, true)
            or lower:find(":", 1, true)
            or lower:find("recover", 1, true)
        if not forceReadable and fs.GetTextColor then
            local r, g, b = fs:GetTextColor()
            forceReadable = IsDarkTextColor(r, g, b)
        end

        if forceReadable then
            ForceReadableQuestFont(fs, useGold and true or false)
        end
    end

    local function Visit(obj, depth)
        if not obj or seen[obj] or depth > 8 then return end
        seen[obj] = true

        local objType = obj.GetObjectType and obj:GetObjectType()
        if objType == "FontString" or objType == "SimpleHTML" then
            ApplyToFontString(obj)
            return
        end

        if obj.GetScrollChild then
            Visit(obj:GetScrollChild(), depth + 1)
        end
        if obj.GetRegions then
            for _, region in ipairs({ obj:GetRegions() }) do
                Visit(region, depth + 1)
            end
        end
        if obj.GetChildren then
            for _, child in ipairs({ obj:GetChildren() }) do
                Visit(child, depth + 1)
            end
        end
    end

    Visit(frame, 0)

    local namedFields = {
        "QuestName", "TitleText", "QuestTitle", "TitleHeader", "DescriptionHeader", "ObjectivesHeader",
        "DescriptionText", "ObjectivesText", "ObjectiveText", "RewardsText", "RewardText", "ObjectiveHeader"
    }
    for _, key in ipairs(namedFields) do
        local field = frame[key]
        if field then
            local useGold = key:find("Title", 1, true) or key:find("Header", 1, true)
            ForceReadableQuestFont(field, useGold and true or false)
        end
    end

    if frame.ScrollFrame then
        Visit(frame.ScrollFrame, 0)
    end
    if frame.RewardsFrame then
        Visit(frame.RewardsFrame, 0)
    end
    if frame.RewardsFrameContainer then
        Visit(frame.RewardsFrameContainer, 0)
    end
end

local function SkinWorldMap()
    if S.db and not (S.db.enable and S.db.worldmap ~= false) then return end
    local WorldMapFrame = _G.WorldMapFrame
    if not WorldMapFrame then return end

    S:SkinPremiumWindow(WorldMapFrame)
    if S.ApplyKuiSurface then
        S:ApplyKuiSurface(WorldMapFrame)
    end
    
    if WorldMapFrame.TitleText then
        WorldMapFrame.TitleText:SetDrawLayer("OVERLAY", 7)
        local fs = WorldMapFrame.TitleText
        if fs.SetFont then fs:SetFont("Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf", 14, "OUTLINE") end
        if fs.SetTextColor then fs:SetTextColor(1, 0.82, 0.18, 1) end
    end

    if WorldMapFrame.overlayFrames then
        for _, overlay in ipairs(WorldMapFrame.overlayFrames) do
            overlay:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
        end
    end
    
    hooksecurefunc(WorldMapFrame, "AddOverlayFrame", function(self, templateName, templateType, anchorPoint, relativeTo, relativePoint, offsetX, offsetY)
        if self.overlayFrames and self.overlayFrames[#self.overlayFrames] then
            self.overlayFrames[#self.overlayFrames]:SetFrameLevel(self:GetFrameLevel() + 10)
        end
    end)

    local MapBorderFrame = WorldMapFrame.BorderFrame
    if MapBorderFrame then
        S:StripTextures(MapBorderFrame)
        HideDecos(MapBorderFrame)
        MapBorderFrame:SetFrameStrata(WorldMapFrame:GetFrameStrata())
        if MapBorderFrame.CloseButton then S:HandleCloseButton(MapBorderFrame.CloseButton) end
        for _, k in ipairs({ "ZoomInButton","ZoomOutButton","TrackingOptionsButton","FloorNavigationFrame" }) do
            if MapBorderFrame[k] then SkinIconButton(MapBorderFrame[k]) end
        end
        if MapBorderFrame.MaximizeMinimizeFrame then
            local mmf = MapBorderFrame.MaximizeMinimizeFrame
            S:StripTextures(mmf)
            if mmf.MaximizeButton then SkinIconButton(mmf.MaximizeButton) end
            if mmf.MinimizeButton then SkinIconButton(mmf.MinimizeButton) end
        end
        if MapBorderFrame.Tutorial then MapBorderFrame.Tutorial:Hide() end
    end

    local MapNavBar = WorldMapFrame.NavBar
    if MapNavBar then
        HideMapNavChrome(MapNavBar)
        MapNavBar:SetPoint("TOPLEFT", 1, -40)
        if MapNavBar.homeButton then
            S:HandleButton(MapNavBar.homeButton)
            if MapNavBar.homeButton.text then S:HandleFont(MapNavBar.homeButton.text) end
        end
        -- Dot call is intentional: HandleNavBarButtons expects the NavBar as
        -- its self argument. A colon call silently skipped the existing crumbs.
        S.HandleNavBarButtons(MapNavBar)
        StyleMapNavSeparators(MapNavBar)
        hooksecurefunc(MapNavBar, "Refresh", function(self)
            HideMapNavChrome(self)
            S.HandleNavBarButtons(self)
            StyleMapNavSeparators(self)
        end)
    end

    local QuestMapFrame = _G.QuestMapFrame
    if not QuestMapFrame then return end

    -- QuestMapFrame and the dynamically-added overlay frames sit above the
    -- shared premium border.  Keep the one-pixel window outline above those
    -- children so the expanded quest log cannot cover the right edge.
    local premiumData = S:GetFFD(WorldMapFrame)
    if not premiumData.worldMapRightEdge then
        local rightEdge = premiumData.atlasBorderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        rightEdge:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -1, -1)
        rightEdge:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -1, 1)
        rightEdge:SetWidth(1)
        premiumData.worldMapRightEdge = rightEdge

        S:RegisterBlizzardWindowBorder(rightEdge, function(self, enabled, color)
            self:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
            self:SetAlpha(enabled and 1 or 0)
        end)
    end

    local function RaiseWorldMapOuterBorder()
        local border = premiumData.atlasBorderFrame
        if not border then return end

        local level = WorldMapFrame:GetFrameLevel() + 1000
        if QuestMapFrame.GetFrameLevel then
            level = math_max(level, QuestMapFrame:GetFrameLevel() + 10)
        end
        for _, overlay in ipairs(WorldMapFrame.overlayFrames or {}) do
            if overlay and overlay.GetFrameLevel then
                level = math_max(level, overlay:GetFrameLevel() + 10)
            end
        end

        border:ClearAllPoints()
        border:SetAllPoints(WorldMapFrame)
        border:SetFrameLevel(level)
    end

    RaiseWorldMapOuterBorder()
    if not WorldMapFrame._ktOuterBorderRaiseHooked then
        WorldMapFrame:HookScript("OnShow", RaiseWorldMapOuterBorder)
        WorldMapFrame:HookScript("OnSizeChanged", RaiseWorldMapOuterBorder)
        QuestMapFrame:HookScript("OnShow", RaiseWorldMapOuterBorder)
        WorldMapFrame._ktOuterBorderRaiseHooked = true
    end

    S:StripTextures(QuestMapFrame)
    HideDecos(QuestMapFrame)
    -- Texture the quest sidebar, never the map canvas, tiles or pins.
    S:ApplyKuiSurface(QuestMapFrame)

    if QuestMapFrame.VerticalSeparator then QuestMapFrame.VerticalSeparator:Hide() end

    local DetailsFrame = QuestMapFrame.DetailsFrame
    if DetailsFrame then
        S:StripTextures(DetailsFrame)
        HideDecos(DetailsFrame)
        S:ContentShade(DetailsFrame)
        if DetailsFrame.backdrop then
            DetailsFrame.backdrop:SetPoint("TOPLEFT", -3, 5)
            DetailsFrame.backdrop:SetPoint("BOTTOMRIGHT", 3, -3)
            DetailsFrame.backdrop:SetBackdropColor(0, 0, 0, 0.12)
            DetailsFrame.backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
        end
        if DetailsFrame.BackFrame then
            S:StripTextures(DetailsFrame.BackFrame)
            if DetailsFrame.BackFrame.BackButton then S:HandleButton(DetailsFrame.BackFrame.BackButton) end
        end
        if DetailsFrame.AbandonButton then S:HandleButton(DetailsFrame.AbandonButton) end
        if DetailsFrame.ShareButton   then S:StripTextures(DetailsFrame.ShareButton); S:HandleButton(DetailsFrame.ShareButton) end
        if DetailsFrame.TrackButton   then S:HandleButton(DetailsFrame.TrackButton); DetailsFrame.TrackButton:SetWidth(95) end
        if DetailsFrame.RewardsFrameContainer and DetailsFrame.RewardsFrameContainer.RewardsFrame then
            S:StripTextures(DetailsFrame.RewardsFrameContainer.RewardsFrame)
            S:CreateBackdrop(DetailsFrame.RewardsFrameContainer.RewardsFrame)
            if DetailsFrame.RewardsFrameContainer.RewardsFrame.backdrop then
                DetailsFrame.RewardsFrameContainer.RewardsFrame.backdrop:SetPoint("TOPLEFT", -5, 5)
                DetailsFrame.RewardsFrameContainer.RewardsFrame.backdrop:SetPoint("BOTTOMRIGHT", 5, -5)
                DetailsFrame.RewardsFrameContainer.RewardsFrame.backdrop:SetBackdropColor(0, 0, 0, 0.12)
                DetailsFrame.RewardsFrameContainer.RewardsFrame.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
            end
        end
        if QuestMapFrame.Background    then QuestMapFrame.Background:SetAlpha(0) end
        if DetailsFrame.SealMaterialBG then DetailsFrame.SealMaterialBG:SetAlpha(0) end
        RefreshWorldMapQuestText(DetailsFrame)
        if not QuestMapFrame._ktQuestDetailsReadableHooked and _G.QuestMapFrame_ShowQuestDetails then
            hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
                if QuestMapFrame.DetailsFrame then
                    RefreshWorldMapQuestText(QuestMapFrame.DetailsFrame)
                end
            end)
            QuestMapFrame._ktQuestDetailsReadableHooked = true
        end
    end

    if QuestMapFrame.QuestsFrame and QuestMapFrame.QuestsFrame.CampaignOverview then
        local CO = QuestMapFrame.QuestsFrame.CampaignOverview
        if CO.BorderFrame then CO.BorderFrame:SetAlpha(0) end
        HideDecos(CO)
        InnerBackdrop(CO)
        if CO.backdrop then CO.backdrop:SetBackdropColor(0, 0, 0, 0.12) end
        if CO.ScrollFrame and CO.ScrollFrame.ScrollBar then SkinScrollBar(CO.ScrollFrame.ScrollBar) end
    end

    local QuestScrollFrame = _G.QuestScrollFrame
    if QuestScrollFrame then
        S:StripTextures(QuestScrollFrame)
        HideDecos(QuestScrollFrame)
        S:ContentShade(QuestScrollFrame)
        -- Backdrop removed in favor of ContentShade
        
        for _, k in ipairs({"Edge","BorderFrame","Center"}) do
            if QuestScrollFrame[k] then QuestScrollFrame[k]:SetAlpha(0) end
        end
        if QuestScrollFrame.Contents and QuestScrollFrame.Contents.Separator then
            QuestScrollFrame.Contents.Separator:SetAlpha(0)
        end
        if QuestScrollFrame.SearchBox then
            StyleQuestSearchBox(QuestScrollFrame.SearchBox)
        end
        if QuestScrollFrame.ScrollBar then
            SkinScrollBar(QuestScrollFrame.ScrollBar)
            QuestScrollFrame.ScrollBar:SetPoint("TOPLEFT", _G.QuestDetailFrame or QuestScrollFrame, "TOPRIGHT", 4, -15)
        end
    end

    RefreshWorldMapQuestText(QuestMapFrame)

    if QuestMapFrame.MapLegend and QuestMapFrame.MapLegend.ScrollFrame then
        if QuestMapFrame.MapLegend.BorderFrame then QuestMapFrame.MapLegend.BorderFrame:SetAlpha(0) end
        local ls = QuestMapFrame.MapLegend.ScrollFrame
        -- S:StripTextures(ls)
        HideDecos(ls)
        InnerBackdrop(ls)
        if ls.backdrop then ls.backdrop:SetBackdropColor(0, 0, 0, 0.12) end
        SkinScrollBar(ls.ScrollBar)
    end

    local tabs = { QuestMapFrame.QuestsTab, QuestMapFrame.EventsTab, QuestMapFrame.MapLegendTab }
    for i, tab in next, tabs do
        if tab then
            if tab.Background then tab.Background:SetAlpha(0) end
            S:StripTextures(tab)
            HideDecos(tab)
            NeutralBackdrop(tab)
            tab:SetSize(30, 40)
            if i == 1 then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", QuestMapFrame, "TOPRIGHT", 10, -10)
            end
            if tab.Icon then
                tab.Icon:ClearAllPoints()
                tab.Icon:SetPoint("CENTER")
                tab.Icon:SetDrawLayer("ARTWORK", 5)
                tab.Icon:SetAlpha(1)
                tab.Icon:Show()
            end
            if tab.SelectedTexture then
                tab.SelectedTexture:SetDrawLayer("ARTWORK", 4)
                tab.SelectedTexture:SetAllPoints()
            end
            for _, region in next, { tab:GetRegions() } do
                if region.IsObjectType and region:IsObjectType("Texture") then
                    local atlas = region.GetAtlas and region:GetAtlas()
                    if atlas and atlas:find("Glow") then
                        region:SetColorTexture(1,1,1,0.15)
                        region:SetAllPoints()
                    end
                end
            end
        end
    end
end

S.SkinFuncs["Blizzard_WorldMap"] = SkinWorldMap
