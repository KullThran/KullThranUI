local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local ipairs = ipairs
local pairs = pairs
local select = select
local unpack = unpack
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local C_Timer = C_Timer

local AVANT_GARDE_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local BLANK_TEX = "Interface\\Buttons\\WHITE8x8"
local EJ_LOOT_BACKDROPS = setmetatable({}, { __mode = "k" })
local EJ_LOOT_SKINNED = setmetatable({}, { __mode = "k" })

local EJ_BG       = { 0.030, 0.030, 0.038, 0.98 }
local EJ_PANEL    = { 0.055, 0.055, 0.068, 0.94 }
local EJ_SELECTED = { 0.105, 0.105, 0.125, 1.00 }
local EJ_EDGE     = { 0.220, 0.220, 0.255, 0.95 }

local function Accent()
    return S:GetAccentColor()
end

local function SetBackdrop(backdrop, background, border)
    if not backdrop then return end
    backdrop:SetBackdropColor(unpack(background or EJ_PANEL))
    backdrop:SetBackdropBorderColor(unpack(border or EJ_EDGE))
end

local function RegisterFlatWindowBackground(object, alpha)
    if not object then return end
    S:RegisterBlizzardWindowBackground(object, function(surface, color)
        if surface and surface.SetBackdropColor then
            surface:SetBackdropColor(color[1], color[2], color[3], alpha or color[4] or 1)
        end
    end)
end

local function SetNativeArtwork(texture, alpha, brightness, desaturation, preserveVisibility)
    if not texture or S:IsKuiSurfaceRegion(texture) then return end
    if texture.SetDesaturation then
        pcall(texture.SetDesaturation, texture, desaturation or 0)
    elseif texture.SetDesaturated then
        pcall(texture.SetDesaturated, texture, (desaturation or 0) >= 0.5)
    end
    if texture.SetVertexColor then
        texture:SetVertexColor(brightness or 1, brightness or 1, brightness or 1, 1)
    end
    if texture.SetAlpha then texture:SetAlpha(alpha or 1) end
    if not preserveVisibility and texture.Show then texture:Show() end
end

local function SuppressFrameArt(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(0) end
    if object.Hide then object:Hide() end
    if object.Show and not object._ktEJSuppressed then
        hooksecurefunc(object, "Show", function(self)
            if self:IsShown() then self:Hide() end
        end)
        object._ktEJSuppressed = true
    end
end

local function StyleEncounterJournalPortrait(journal)
    if not journal then return end
    local container = journal.PortraitContainer
    local portrait = journal.Portrait or journal.portrait or _G.EncounterJournalPortrait
        or (container and (container.Portrait or container.portrait))

    if container then
        container:SetAlpha(1)
        container:Show()
    end
    if not portrait then return end

    portrait:SetAlpha(1)
    portrait:Show()
    if container and container.GetRegions then
        for _, region in ipairs({ container:GetRegions() }) do
            if region ~= portrait and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end
    end
    if not portrait._ktEJPortraitSkinned then
        S:HandleIcon(portrait, true)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", journal, "TOPLEFT", 7, -5)
        portrait:SetSize(28, 28)
        portrait._ktEJPortraitSkinned = true
    end
    if portrait.backdrop then
        local color = Accent()
        portrait.backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    end
end

local function ModernPanel(frame, alpha)
    if not frame then return end
    if not frame.backdrop then S:CreateFlatBackdrop(frame, true) end
    if frame._ktEJPanelTexture then frame._ktEJPanelTexture:Hide() end
    if frame.backdrop then
        frame.backdrop:SetBackdropBorderColor(unpack(EJ_EDGE))
        if alpha == 0 then
            -- The navigation container must remain transparent; otherwise it
            -- creates an oversized textured strip behind the breadcrumbs.
            frame.backdrop:SetBackdropColor(0, 0, 0, 0)
        else
            -- The root owns the continuous KUI texture. Repeating it on every
            -- child panel crops the artwork into unrelated fragments; use only
            -- a light wash here so native Adventure Guide art remains visible.
            local shadeAlpha = math.min(0.14, math.max(0.06, (alpha or 0.72) * 0.14))
            frame.backdrop:SetBackdropColor(0, 0, 0, shadeAlpha)
        end
    end
end

local function SkinModernScrollStepper(button, pointsUp)
    if not button then return end
    if button.Texture then button.Texture:SetAlpha(0) end
    if button._ktEJArrow then return end

    local arrow = button:CreateTexture(nil, "OVERLAY", nil, 7)
    arrow:SetAtlas("common-dropdown-icon")
    arrow:SetSize(9, 9)
    arrow:SetPoint("CENTER")
    if pointsUp and arrow.SetRotation then arrow:SetRotation(3.14159265) end
    if arrow.SetDesaturated then arrow:SetDesaturated(true) end
    button._ktEJArrow = arrow

    local function Update(self)
        local enabled = not self.IsEnabled or self:IsEnabled()
        local over = enabled and self.IsMouseOver and self:IsMouseOver()
        if over then
            arrow:SetVertexColor(1, 1, 1, 1)
        elseif enabled then
            arrow:SetVertexColor(0.65, 0.65, 0.70, 0.95)
        else
            arrow:SetVertexColor(0.28, 0.28, 0.31, 0.70)
        end
    end
    button:HookScript("OnEnter", Update)
    button:HookScript("OnLeave", Update)
    button:HookScript("OnEnable", Update)
    button:HookScript("OnDisable", Update)
    Update(button)
end

local function SkinSuggestionNavButton(button, direction)
    if not button then return end
    S:HandleButton(button)

    -- HandleButton replaces Blizzard's state textures. On these two controls
    -- those textures are also the arrow glyph, so provide a permanent overlay.
    if not button._ktEJSuggestionArrow then
        local arrow = button:CreateFontString(nil, "OVERLAY", nil, 7)
        arrow:SetPoint("CENTER", button, "CENTER", 0, 1)
        arrow:SetFont(AVANT_GARDE_FONT, 20, "OUTLINE")
        arrow:SetText(direction == "previous" and "<" or ">")
        arrow:SetShadowOffset(0, 0)
        button._ktEJSuggestionArrow = arrow

        local function Update(self)
            local enabled = not self.IsEnabled or self:IsEnabled()
            local over = enabled and self.IsMouseOver and self:IsMouseOver()
            if over then
                arrow:SetTextColor(1, 0.88, 0.28, 1)
            elseif enabled then
                arrow:SetTextColor(1, 1, 1, 1)
            else
                arrow:SetTextColor(0.42, 0.42, 0.46, 0.85)
            end
            arrow:Show()
        end

        button:HookScript("OnEnter", Update)
        button:HookScript("OnLeave", Update)
        button:HookScript("OnEnable", Update)
        button:HookScript("OnDisable", Update)
        button:HookScript("OnShow", Update)
        button._ktEJSuggestionArrowUpdate = Update
    end

    if button.Texture then button.Texture:SetAlpha(0) end
    if button._ktEJSuggestionArrowUpdate then
        button._ktEJSuggestionArrowUpdate(button)
    end
end

local function StyleSuggestionCard(suggestion, index)
    if not suggestion then return end
    local background = suggestion.bg or suggestion.Background
    if background then
        SetNativeArtwork(background, 1, 0.56, 0, true)
    end
    ModernPanel(suggestion, 0.48)
    if suggestion.button then S:HandleButton(suggestion.button) end
    if index == 1 then
        SkinSuggestionNavButton(suggestion.prevButton, "previous")
        SkinSuggestionNavButton(suggestion.nextButton, "next")
    end
end

local function SkinModernScrollBar(scrollBar)
    if not scrollBar then return end
    S:HandleScrollBar(scrollBar)
    scrollBar:SetWidth(10)

    if not scrollBar._ktEJTrack then
        local track = scrollBar:CreateTexture(nil, "BACKGROUND", nil, 2)
        track:SetColorTexture(0.012, 0.012, 0.016, 0.96)
        track:SetPoint("TOP", scrollBar, "TOP", 0, -13)
        track:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 13)
        track:SetWidth(4)
        scrollBar._ktEJTrack = track
    end

    local thumb = scrollBar.Track and scrollBar.Track.Thumb
    if thumb then
        if thumb.backdrop then
            thumb.backdrop:ClearAllPoints()
            thumb.backdrop:SetPoint("TOPLEFT", thumb, "TOPLEFT", 1, -1)
            thumb.backdrop:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -1, 1)
            thumb.backdrop:SetBackdropColor(0.10, 0.10, 0.12, 1)
            thumb.backdrop:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)
        end
        if not thumb._ktEJFill then
            local fill = thumb:CreateTexture(nil, "ARTWORK", nil, 7)
            local color = Accent()
            fill:SetColorTexture(color[1], color[2], color[3], 0.90)
            fill:SetPoint("TOPLEFT", thumb, "TOPLEFT", 2, -2)
            fill:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)
            thumb._ktEJFill = fill
            thumb:HookScript("OnEnter", function(self) self._ktEJFill:SetAlpha(1) end)
            thumb:HookScript("OnLeave", function(self) self._ktEJFill:SetAlpha(0.90) end)
        end
    elseif scrollBar.ThumbTexture then
        local color = Accent()
        scrollBar.ThumbTexture:SetColorTexture(color[1], color[2], color[3], 0.90)
        scrollBar.ThumbTexture:SetWidth(6)
    end

    SkinModernScrollStepper(scrollBar.Back or scrollBar.ScrollUpButton or scrollBar.UpButton, true)
    SkinModernScrollStepper(scrollBar.Forward or scrollBar.ScrollDownButton or scrollBar.DownButton, false)
end

local function EnsureReadableFont(fs, size, r, g, b)
    if not fs then return end
    if fs.SetFont then
        fs:SetFont(AVANT_GARDE_FONT, size or 12, "OUTLINE")
        fs:SetShadowOffset(0, 0)
    end
    local colorR, colorG, colorB = r or 1, g or 1, b or 1
    if fs.SetTextColor then
        fs:SetTextColor(colorR, colorG, colorB, 1)
    end

    -- [FIX] Persistir formateo: como en spellbook, instalar hooks para que
    -- Blizzard no pueda resetear colores oscuros al actualizar texto dinámicamente
    -- en la Guía de Aventura (overview, bosses, loot, etc.).
    if not fs._ktEJFontHooked then
        fs._ktEJFontHooked = true

        if hooksecurefunc then
            hooksecurefunc(fs, "SetTextColor", function(self, newR, newG, newB, newA)
                if self._ktEJTextColorGuard then return end
                local sum = (newR or 0) + (newG or 0) + (newB or 0)
                if sum < 0.55 then
                    self._ktEJTextColorGuard = true
                    self:SetTextColor(colorR, colorG, colorB, newA or 1)
                    self._ktEJTextColorGuard = nil
                end
            end)

            if fs.SetShadowColor then
                hooksecurefunc(fs, "SetShadowColor", function(self, sr, sg, sb, sa)
                    if self._ktEJShadowGuard then return end
                    if sr ~= 0 or sg ~= 0 or sb ~= 0 or (sa or 1) ~= 1 then
                        self._ktEJShadowGuard = true
                        self:SetShadowColor(0, 0, 0, 1)
                        if self.SetShadowOffset then self:SetShadowOffset(0, 0) end
                        self._ktEJShadowGuard = nil
                    end
                end)
            end

            if fs.SetAlpha then
                hooksecurefunc(fs, "SetAlpha", function(self, alpha)
                    if self._ktEJAlphaGuard then return end
                    if type(alpha) == "number" and alpha < 0.5 then
                        self._ktEJAlphaGuard = true
                        self:SetAlpha(1)
                        self._ktEJAlphaGuard = nil
                    end
                end)
            end
        end
    end
end

--- Force a single icon texture to OVERLAY,7 and make it visible.
local function RaiseIcon(icon)
    if not icon then return end
    icon:SetDrawLayer("OVERLAY", 7)
    icon:SetAlpha(1)
    if icon.Show then icon:Show() end
end

--- Raise the draw layer of every *already-visible* icon texture on a frame.
--- Skips highlight / pushed / disabled special textures and hidden textures.
local function RaiseVisibleIcons(frame)
    if not (frame and frame.GetNumRegions) then return end
    local hl      = frame.GetHighlightTexture and frame:GetHighlightTexture()
    local pushed  = frame.GetPushedTexture    and frame:GetPushedTexture()
    local disable = frame.GetDisabledTexture  and frame:GetDisabledTexture()
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture")
            and region ~= hl and region ~= pushed and region ~= disable
            and region:GetAlpha() > 0 then
            region:SetDrawLayer("OVERLAY", 7)
        end
    end
end

-- Generic helper for scroll frames that use GetChildren (non-pooled)
local function SkinScrollChildrenButtons(scrollFrame, markerField, applyFn)
    if not scrollFrame or type(applyFn) ~= "function" then return end

    local function SkinNow(self)
        for _, child in ipairs({ self:GetChildren() }) do
            if child and child:IsObjectType("Button") and not child[markerField] then
                applyFn(child)
                child[markerField] = true
            end
        end
    end

    SkinNow(scrollFrame)

    if type(scrollFrame.Update) == "function" then
        hooksecurefunc(scrollFrame, "Update", SkinNow)
    end
end

local function ForEachScrollBoxFrame(scrollBox, callback, marker)
    if not (scrollBox and type(callback) == "function") then return end

    local function Update(self)
        if self.ForEachFrame then
            self:ForEachFrame(callback)
        end
    end

    Update(scrollBox)
    marker = marker or "_ktEJFramesHooked"
    if not scrollBox[marker] and type(scrollBox.Update) == "function" then
        hooksecurefunc(scrollBox, "Update", Update)
        scrollBox[marker] = true
    end
end

local function IsRowSelected(frame)
    if not frame then return false end
    if frame.selected == true or frame.isSelected == true or frame.Selected == true then return true end
    for _, key in ipairs({ "SelectedTexture", "Selection", "Selected", "selected" }) do
        local region = frame[key]
        local kind = type(region)
        if (kind == "table" or kind == "userdata") and region.IsShown and region:IsShown() then return true end
    end
    return false
end

local function FindRowText(frame)
    if not frame then return end
    for _, key in ipairs({ "Name", "name", "Label", "label", "Title", "title", "Text" }) do
        local value = frame[key]
        local kind = type(value)
        if (kind == "table" or kind == "userdata") and value.SetTextColor then return value end
    end
    local value = frame.GetFontString and frame:GetFontString()
    if value and value.SetTextColor then return value end
end

local function UpdateModernListRow(frame)
    if not (frame and frame.backdrop) then return end
    local selected = IsRowSelected(frame)
    local over = frame.IsMouseOver and frame:IsMouseOver()
    local color = Accent()

    if selected then
        frame.backdrop:SetBackdropColor(unpack(EJ_SELECTED))
        frame.backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        if frame._ktEJSelectionMarker then
            frame._ktEJSelectionMarker:SetColorTexture(color[1], color[2], color[3], 1)
            frame._ktEJSelectionMarker:Show()
        end
    elseif over then
        frame.backdrop:SetBackdropColor(0.085, 0.085, 0.105, 0.96)
        frame.backdrop:SetBackdropBorderColor(0.68, 0.68, 0.74, 0.85)
        if frame._ktEJSelectionMarker then frame._ktEJSelectionMarker:Hide() end
    else
        frame.backdrop:SetBackdropColor(0.040, 0.040, 0.050, 0.90)
        frame.backdrop:SetBackdropBorderColor(0.10, 0.10, 0.12, 1)
        if frame._ktEJSelectionMarker then frame._ktEJSelectionMarker:Hide() end
    end

    local rowText = FindRowText(frame)
    if rowText and rowText.SetTextColor then rowText:SetTextColor(1, 1, 1, 1) end
end

local function SkinModernListRow(frame)
    if not (frame and frame.IsObjectType and frame:IsObjectType("Button")) then return end
    if not frame._ktEJModernRow then
        S:CreateBackdrop(frame, true)
        if frame.backdrop then
            frame.backdrop:ClearAllPoints()
            frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
            frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        end

        local marker = frame:CreateTexture(nil, "OVERLAY", nil, 6)
        marker:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -2)
        marker:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 2)
        marker:SetWidth(2)
        marker:Hide()
        frame._ktEJSelectionMarker = marker

        local highlight = frame.GetHighlightTexture and frame:GetHighlightTexture()
        if highlight then
            highlight:SetColorTexture(1, 1, 1, 0.06)
            highlight:SetAllPoints(frame)
        end

        local rowText = FindRowText(frame)
        if rowText then EnsureReadableFont(rowText, 11, 1, 1, 1) end
        frame:HookScript("OnEnter", UpdateModernListRow)
        frame:HookScript("OnLeave", UpdateModernListRow)
        frame:HookScript("OnShow", UpdateModernListRow)
        frame:HookScript("OnClick", function(self)
            if C_Timer then C_Timer.After(0, function() UpdateModernListRow(self) end) end
        end)
        frame._ktEJModernRow = true
    end
    UpdateModernListRow(frame)
end

-- =============================================================
-- BOSS BUTTON (encounter info bosses panel)
-- =============================================================
local function BossesScrollUpdateChild(child)
    if not child.IsSkinned then
        local creature = child.creature
        S:StripTextures(child)
        S:CreateBackdrop(child, true)
        SetBackdrop(child.backdrop, { 0.045, 0.045, 0.055, 0.88 }, { 0, 0, 0, 1 })
        local highlight = child.GetHighlightTexture and child:GetHighlightTexture()
        if highlight then highlight:SetColorTexture(1, 1, 1, 0.07) end
        if child.text then
            EnsureReadableFont(child.text, 12, 1, 1, 1)
            child.text:SetDrawLayer("OVERLAY", 7)
            if not child.text._ktColorLocked then
                hooksecurefunc(child.text, "SetTextColor", function(self, r, g, b)
                    if r ~= 1 or g ~= 1 or b ~= 1 then
                        self:SetTextColor(1, 1, 1)
                    end
                end)
                child.text._ktColorLocked = true
            end
        end
        if creature then
            creature:ClearAllPoints()
            creature:SetPoint("TOPLEFT", 0, -4)
            RaiseIcon(creature)
        end
        child:HookScript("OnEnter", function(self)
            if self.backdrop then self.backdrop:SetBackdropBorderColor(1, 1, 1, 0.65) end
        end)
        child:HookScript("OnLeave", function(self)
            if self.backdrop then self.backdrop:SetBackdropBorderColor(0, 0, 0, 1) end
        end)
        child.IsSkinned = true
    end
end

-- =============================================================
-- LOOT ITEM (loot container)
-- =============================================================
local function LootContainerUpdateChild(child)
    if not child then return end

    if child.bossTexture then child.bossTexture:SetAlpha(0) end
    if child.bosslessTexture then child.bosslessTexture:SetAlpha(0) end

    if child.name and child.icon then
        child.icon:SetSize(32, 32)
        child.icon:ClearAllPoints()
        child.icon:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -4)
        S:HandleIcon(child.icon, false)
        RaiseIcon(child.icon)

        child.name:ClearAllPoints()
        child.name:SetPoint("TOPLEFT", child.icon, "TOPRIGHT", 6, -2)
        EnsureReadableFont(child.name, 11, 1, 1, 1)

        local backdrop = EJ_LOOT_BACKDROPS[child]
        if not backdrop then
            backdrop = CreateFrame("Frame", nil, child, "BackdropTemplate")
            backdrop:SetFrameLevel(math.max(1, child:GetFrameLevel() - 1))
            backdrop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = S.mult or 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
            backdrop:SetBackdropColor(0.09, 0.09, 0.09, 0.97)
            backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
            EJ_LOOT_BACKDROPS[child] = backdrop
        end
        backdrop:ClearAllPoints()
        backdrop:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        backdrop:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", 0, 1)
    end

    if child.boss then EnsureReadableFont(child.boss, 10, 1, 1, 1) end
    if child.slot then EnsureReadableFont(child.slot, 10, 0.8, 0.8, 0.8) end
    if child.armorType then EnsureReadableFont(child.armorType, 10, 0.8, 0.8, 0.8) end

    EJ_LOOT_SKINNED[child] = true
end

-- =============================================================
-- INSTANCE SELECT BUTTON (keep dungeon artwork, add thin border)
-- =============================================================
local function InstanceSelectUpdateChild(child)
    if not child.IsSkinned then
        S:CreateBackdrop(child, true)
        SetBackdrop(child.backdrop, { 0.035, 0.035, 0.045, 0.70 }, EJ_EDGE)
        local hl = child.GetHighlightTexture and child:GetHighlightTexture()
        if hl then
            hl:SetColorTexture(1, 1, 1, 0.10)
            hl:SetAlpha(1)
        end

        local bgImage = child.bgImage
        if bgImage then
            if bgImage.IsObjectType and bgImage:IsObjectType("Frame") then
                if not bgImage.backdrop then
                    S:CreateBackdrop(bgImage)
                end
                if bgImage.backdrop then
                    bgImage.backdrop:SetPoint("TOPLEFT",     bgImage, "TOPLEFT",     3, -3)
                    bgImage.backdrop:SetPoint("BOTTOMRIGHT", bgImage, "BOTTOMRIGHT", -4, 2)
                end
            elseif not bgImage._ktBorder then
                local border = CreateFrame("Frame", nil, child, "BackdropTemplate")
                border:SetFrameLevel(child:GetFrameLevel() + 1)
                border:SetPoint("TOPLEFT",     bgImage, "TOPLEFT",     3, -3)
                border:SetPoint("BOTTOMRIGHT", bgImage, "BOTTOMRIGHT", -4, 2)
                S:CreateBackdrop(border, true)
                if border.backdrop then
                    border.backdrop:SetBackdropColor(0, 0, 0, 0)
                end
                bgImage._ktBorder = border
            end
        end

        -- Raise all visible icon textures above any backdrop
        RaiseVisibleIcons(child)

        if child.name        then EnsureReadableFont(child.name,        12, 1, 1, 1)       end
        if child.description then EnsureReadableFont(child.description, 10, 0.8, 0.8, 0.8) end

        child:HookScript("OnEnter", function(self)
            if self.backdrop then self.backdrop:SetBackdropBorderColor(1, 1, 1, 0.82) end
        end)
        child:HookScript("OnLeave", function(self)
            if self.backdrop then self.backdrop:SetBackdropBorderColor(unpack(EJ_EDGE)) end
        end)

        child.IsSkinned = true
    end
end

local function InstanceSelectScrollUpdate(frame)
    frame:ForEachFrame(InstanceSelectUpdateChild)
end

local function SkinJourneyCard(child)
    if not child then return end

    -- JourneysList also recycles category headings and dividers. They should
    -- remain separators instead of receiving a button-shaped panel.
    if not (child.IsObjectType and child:IsObjectType("Button")) then
        if child.CategoryName then EnsureReadableFont(child.CategoryName, 13, 1, 1, 1) end
        if child.CategoryDivider then
            local color = Accent()
            child.CategoryDivider:SetVertexColor(color[1], color[2], color[3], 0.48)
        end
        child._ktEJJourneyCard = true
        return
    end

    if child.NormalTexture then
        SetNativeArtwork(child.NormalTexture, 1, 0.52, 0, true)
    end
    if child.PushedTexture then
        SetNativeArtwork(child.PushedTexture, 1, 0.64, 0, true)
    end
    if not child._ktEJJourneyCard then S:CreateBackdrop(child, true) end
    SetBackdrop(child.backdrop, { 0.040, 0.040, 0.052, 0.88 }, EJ_EDGE)
    for _, key in ipairs({
        "RenownCardFactionName", "RenownCardFactionLevel", "JourneyCardName",
        "JourneyCardLevel", "CategoryName", "HighlightTitle", "HighlightLevel",
        "HighlightDescription",
    }) do
        if child[key] then EnsureReadableFont(child[key], nil, 1, 1, 1) end
    end
    local icon = child.JourneyIcon or (child.IconFrame and child.IconFrame.Icon)
    if icon then S:HandleIcon(icon, true); RaiseIcon(icon) end
    if child.JourneyCardProgressBar then S:HandleStatusBar(child.JourneyCardProgressBar) end
    if not child._ktEJJourneyCard then
        child:HookScript("OnEnter", function(self)
            if self.backdrop then self.backdrop:SetBackdropBorderColor(1, 1, 1, 0.78) end
        end)
        child:HookScript("OnLeave", function(self)
            if self.backdrop then self.backdrop:SetBackdropBorderColor(unpack(EJ_EDGE)) end
        end)
    end
    child._ktEJJourneyCard = true
end

local function SkinMonthlyActivityRow(child)
    if not child then return end
    SkinModernListRow(child)
    if not child._ktEJMonthlyDetails then
        if child.NormalTexture then
            SetNativeArtwork(child.NormalTexture, 1, 0.52, 0, true)
        end
        child._ktEJMonthlyDetails = true
    end
    if child.TextContainer then
        EnsureReadableFont(child.TextContainer.NameText, 11, 1, 1, 1)
        EnsureReadableFont(child.TextContainer.ConditionsText, 10, 0.76, 0.76, 0.80)
    end
    if child.Points then EnsureReadableFont(child.Points, 11, 1, 1, 1) end
end

local function SkinMonthlyFilterRow(child)
    if not child then return end
    SkinModernListRow(child)
    if child.Label then EnsureReadableFont(child.Label, 11, 1, 1, 1) end
    if child.Texture and not child._ktEJFilterIcon then
        child.Texture:SetSize(18, 18)
        S:HandleIcon(child.Texture, true)
        RaiseIcon(child.Texture)
        child._ktEJFilterIcon = true
    end
end

local function SkinLootJournalRow(child)
    if not child then return end
    SkinModernListRow(child)
    if not child._ktEJLootDetails then
        if child.Background then
            SetNativeArtwork(child.Background, 1, 0.52, 0, true)
        end
        if child.BackgroundOverlay then
            SetNativeArtwork(child.BackgroundOverlay, 0.42, 0.68, 0, true)
        end
        if child.Icon then
            S:HandleIcon(child.Icon, true)
            RaiseIcon(child.Icon)
        end
        child._ktEJLootDetails = true
    end
    EnsureReadableFont(child.Name, 11, 1, 1, 1)
    EnsureReadableFont(child.SpecName, 10, 0.76, 0.76, 0.80)
end

local function SkinItemSetRow(child)
    if not child then return end
    SkinModernListRow(child)
    EnsureReadableFont(FindRowText(child), 11, 1, 1, 1)
    local detail = child.Label
    local detailKind = type(detail)
    if not ((detailKind == "table" or detailKind == "userdata") and detail.SetTextColor) then
        detail = child.Description
        detailKind = type(detail)
    end
    if (detailKind == "table" or detailKind == "userdata") and detail.SetTextColor then
        EnsureReadableFont(detail, 10, 0.76, 0.76, 0.80)
    end
    local icon = child.Icon or child.icon
    if icon and not child._ktEJItemSetIcon then
        S:HandleIcon(icon, true)
        RaiseIcon(icon)
        child._ktEJItemSetIcon = true
    end
end

-- =============================================================
-- BOTTOM TAB (flat Collections-style text tabs)
-- =============================================================
local function SuppressBottomTabChrome(tab)
    if not tab then return end
    if tab.GetRegions then
        for _, region in ipairs({ tab:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
    for _, key in ipairs({
        "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
        "SelectedTexture", "HighlightTexture", "Glow", "Shadow", "TabBg",
        "ActiveLeft", "ActiveMiddle", "ActiveRight",
    }) do
        local texture = tab[key]
        if texture and texture.SetAlpha then texture:SetAlpha(0) end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        if tab[getter] then
            local texture = tab[getter](tab)
            if texture and texture.SetAlpha then texture:SetAlpha(0) end
        end
    end
end

local function SetBottomTabBorderColor(tab, r, g, b, a)
    if not (tab and tab._ktEJBorderTextures) then return end
    for _, texture in ipairs(tab._ktEJBorderTextures) do
        texture:SetColorTexture(r, g, b, a)
    end
end

local function UpdateBottomTab(tab, journal)
    if not (tab and tab.backdrop and journal) then return end
    SuppressBottomTabChrome(tab)
    if tab._ktEJBorder then
        tab._ktEJBorder:SetFrameLevel(tab:GetFrameLevel() + 5)
    end
    local selected = journal.selectedTab == tab:GetID()
    tab.KT_Selected = selected
    if selected then
        local color = Accent()
        tab.backdrop:SetBackdropColor(unpack(EJ_SELECTED))
        tab.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
        SetBottomTabBorderColor(tab, color[1], color[2], color[3], 1)
    elseif tab.IsMouseOver and tab:IsMouseOver() then
        tab.backdrop:SetBackdropColor(0.10, 0.10, 0.12, 0.98)
        tab.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
        SetBottomTabBorderColor(tab, 0.86, 0.86, 0.92, 1)
    else
        tab.backdrop:SetBackdropColor(0.040, 0.040, 0.050, 0.96)
        tab.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
        SetBottomTabBorderColor(tab, 0.20, 0.20, 0.24, 1)
    end
    if tab._ktEJText then tab._ktEJText:SetTextColor(1, 1, 1, 1) end
end

local function SkinBottomTab(tab, journal)
    if not tab then return end
    if not tab._ktSkinned then
        S:StripTextures(tab)
        S:CreateBackdrop(tab, true)
        if tab.backdrop then
            tab.backdrop:ClearAllPoints()
            tab.backdrop:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
            tab.backdrop:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
        end

        local border = CreateFrame("Frame", nil, tab)
        border:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
        border:SetFrameLevel(tab:GetFrameLevel() + 5)
        tab._ktEJBorder = border
        tab._ktEJBorderTextures = {}

        local top = border:CreateTexture(nil, "OVERLAY", nil, 7)
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        top:SetHeight(1)
        local bottom = border:CreateTexture(nil, "OVERLAY", nil, 7)
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(1)
        local left = border:CreateTexture(nil, "OVERLAY", nil, 7)
        left:SetPoint("TOPLEFT")
        left:SetPoint("BOTTOMLEFT")
        left:SetWidth(1)
        local right = border:CreateTexture(nil, "OVERLAY", nil, 7)
        right:SetPoint("TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT")
        right:SetWidth(1)
        tab._ktEJBorderTextures = { top, bottom, left, right }
        SetBottomTabBorderColor(tab, 0.20, 0.20, 0.24, 1)

        local text = FindRowText(tab)
        if text then
            text:SetParent(tab)
            text:SetDrawLayer("OVERLAY", 7)
            EnsureReadableFont(text, 11, 1, 1, 1)
            text:ClearAllPoints()
            text:SetPoint("CENTER", tab, "CENTER", 0, 1)
            tab._ktEJText = text
            local textWidth = text:GetStringWidth()
            if textWidth and textWidth > 0 then
                tab:SetWidth(math.max(72, math.min(128, textWidth + 22)))
            end
        end

        tab:HookScript("OnEnter", function(self) UpdateBottomTab(self, journal) end)
        tab:HookScript("OnLeave", function(self) UpdateBottomTab(self, journal) end)
        tab:HookScript("OnClick", function(self)
            if C_Timer then C_Timer.After(0, function() UpdateBottomTab(self, journal) end) end
        end)
        tab._ktSkinned = true
    end
    UpdateBottomTab(tab, journal)
end

local function ReassertEncounterJournalShell(journal)
    if not journal then return end
    for _, art in ipairs({
        journal.BgNineSlice, journal.NineSlice, journal.Bg,
        journal.TitleBg, journal.TopTileStreaks,
    }) do
        SuppressFrameArt(art)
    end
    StyleEncounterJournalPortrait(journal)
    if journal.SetTitle then
        journal:SetTitle(_G.ADVENTURE_JOURNAL or "Adventure Guide")
    elseif journal.TitleText then
        journal.TitleText:SetText(_G.ADVENTURE_JOURNAL or "Adventure Guide")
    end
    if journal._ktModernShellBorder then journal._ktModernShellBorder:Show() end
    if journal._ktModernHeaderDivider then journal._ktModernHeaderDivider:Show() end
end

local function ReassertInstanceSelectArt(instanceSelect)
    if not instanceSelect then return end
    if instanceSelect.bg then
        SetNativeArtwork(instanceSelect.bg, 1, 0.52, 0, true)
    end
    if instanceSelect.evergreenBg then
        SetNativeArtwork(instanceSelect.evergreenBg, 1, 0.52, 0, true)
    end
end

local function ReassertMonthlyArt(activities)
    if not activities then return end
    if activities.Bg then
        SetNativeArtwork(activities.Bg, 1, 0.52, 0, true)
    end
    SuppressFrameArt(activities.NineSlice)
    SuppressFrameArt(activities.BgNineSlice)
    local theme = activities.ThemeContainer
    if theme then
        theme:SetAlpha(1)
        theme:Show()
        if theme.GetRegions then
            for _, region in ipairs({ theme:GetRegions() }) do
                if region and region.IsObjectType and region:IsObjectType("Texture") then
                    SetNativeArtwork(region, 1, 0.56, 0, true)
                end
            end
        end
    end
    for _, decoration in ipairs({ activities.DividerVertical, activities.ShadowLeft, activities.ShadowRight }) do
        if decoration then decoration:SetAlpha(0) end
    end

    if activities.HeaderContainer then
        EnsureReadableFont(activities.HeaderContainer.Title, 16, 1, 1, 1)
        EnsureReadableFont(activities.HeaderContainer.Month, 13, 1, 0.82, 0.18)
        EnsureReadableFont(activities.HeaderContainer.TimeLeft, 11, 0.90, 0.90, 0.92)
    end
end

local function GetJournalSectionTitle(journal)
    local id = journal and journal.selectedTab
    if not id then return "" end
    if journal.suggestTab and id == journal.suggestTab:GetID() then return _G.AJ_SUGGESTED_CONTENT_TAB or "Suggested Content" end
    if journal.TutorialsTab and id == journal.TutorialsTab:GetID() then return _G.EJ_TUTORIALS or "Tutorials" end
    if journal.LootJournalTab and id == journal.LootJournalTab:GetID() then return _G.LOOT_JOURNAL_ITEM_SETS or "Item Sets" end
    return ""
end

local function ReassertSectionHeader(journal, navBar, searchBox)
    if not journal then return end
    if not journal._ktEJSectionHeader then
        local header = CreateFrame("Frame", nil, journal, "BackdropTemplate")
        header:SetPoint("TOPLEFT", journal, "TOPLEFT", 5, -25)
        header:SetPoint("TOPRIGHT", journal, "TOPRIGHT", -5, -25)
        header:SetHeight(35)
        header:SetFrameLevel(journal:GetFrameLevel() + 1)
        header:SetBackdrop({ bgFile = BLANK_TEX, edgeFile = BLANK_TEX, edgeSize = S.mult or 1 })
        RegisterFlatWindowBackground(header, 0.94)
        header:SetBackdropBorderColor(unpack(EJ_EDGE))


        local title = header:CreateFontString(nil, "OVERLAY", nil, 7)
        title:SetPoint("LEFT", header, "LEFT", 13, 0)
        title:SetFont(AVANT_GARDE_FONT, 13, "OUTLINE")
        title:SetTextColor(1, 1, 1, 1)
        header.Title = title
        journal._ktEJSectionHeader = header
    end

    local header = journal._ktEJSectionHeader
    local monthly = journal.MonthlyActivitiesTab and journal.selectedTab == journal.MonthlyActivitiesTab:GetID()
    header:SetShown(not monthly)
    if monthly then return end

    local sectionTitle = GetJournalSectionTitle(journal)
    header.Title:SetText(sectionTitle)
    header.Title:SetShown(sectionTitle ~= "")

    if navBar then
        navBar:ClearAllPoints()
        navBar:SetPoint("TOPLEFT", journal, "TOPLEFT", 10, -25)
        navBar:SetSize(540, 34)
        if navBar.overlay then navBar.overlay:Hide() end
        if navBar.backdrop then navBar.backdrop:SetAlpha(0) end
        if navBar._ktEJPanelTexture then navBar._ktEJPanelTexture:SetAlpha(0) end

        -- HandleNavBarButtons is intentionally a dot call: the NavBar itself
        -- is the helper's self argument. A colon call silently skipped it.
        S.HandleNavBarButtons(navBar)
        if navBar.navList then
            for _, button in ipairs(navBar.navList) do
                for _, key in ipairs({ "Left", "arrowUp", "arrowDown", "selected" }) do
                    local texture = button and button[key]
                    if texture and texture.SetAlpha then texture:SetAlpha(0) end
                end
            end
        end
        if navBar.homeButton then
            navBar.homeButton:SetHeight(26)
        end
    end

    if searchBox and searchBox:IsShown() then
        searchBox:ClearAllPoints()
        searchBox:SetPoint("RIGHT", header, "RIGHT", -10, 0)
        searchBox:SetSize(205, 22)
    end
end

local function LayoutBottomTabs(journal, tabs)
    if not (journal and tabs) then return end
    local previous, first
    local seen = {}
    for _, tab in ipairs(tabs) do
        if tab and not seen[tab] and tab:IsShown() then
            seen[tab] = true
            tab:ClearAllPoints()
            tab:SetHeight(30)
            if previous then
                tab:SetPoint("LEFT", previous, "RIGHT", 4, 0)
            else
                tab:SetPoint("TOPLEFT", journal, "BOTTOMLEFT", 11, 2)
                first = tab
            end
            previous = tab
        end
    end

    if first and previous then
        if not journal._ktEJTabRail then
            local rail = CreateFrame("Frame", nil, journal, "BackdropTemplate")
            rail:SetBackdrop({ bgFile = BLANK_TEX })
            RegisterFlatWindowBackground(rail, 0.90)
            journal._ktEJTabRail = rail
        end
        local rail = journal._ktEJTabRail
        rail:SetFrameLevel(math.max(0, first:GetFrameLevel() - 2))
        rail:ClearAllPoints()
        rail:SetPoint("TOPLEFT", first, "TOPLEFT", -3, 2)
        rail:SetPoint("BOTTOMRIGHT", previous, "BOTTOMRIGHT", 3, -2)
        rail:Show()
    end
end

local function StyleTutorialsFrame(frame)
    if not frame then return end
    ModernPanel(frame, 0.84)
    local contents = frame.Contents
    if not contents then return end
    ModernPanel(contents, 0.72)

    for _, region in ipairs({ contents:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture")
            and region ~= contents.Divider and not region._ktTutorialDecoration
            and not S:IsKuiSurfaceRegion(region) then
            local atlas = region.GetAtlas and region:GetAtlas()
            if atlas == "adventureguide-tutorial-rpe" then
                region:SetDesaturated(false)
                region:SetVertexColor(0.74, 0.74, 0.78, 1)
                region:SetAlpha(1)
                contents._ktTutorialArtwork = region
            else
                region:SetDesaturated(false)
                region:SetVertexColor(0.56, 0.56, 0.60, 1)
                region:SetAlpha(1)
            end
        end
    end

    if contents.Header then
        EnsureReadableFont(contents.Header, 22, 1, 1, 1)
    end
    if contents.Description then
        EnsureReadableFont(contents.Description, 13, 0.88, 0.88, 0.92)
    end
    if contents.Divider then
        local color = Accent()
        contents.Divider:SetColorTexture(color[1], color[2], color[3], 0.62)
        contents.Divider:SetHeight(1)
    end
    if contents.StartButton then
        S:HandleButton(contents.StartButton)
        if contents.StartButton.backdrop then
            contents.StartButton.backdrop:SetBackdropColor(0.055, 0.055, 0.068, 0.98)
            contents.StartButton.backdrop:SetBackdropBorderColor(0.34, 0.34, 0.40, 1)
        end
        if not contents.StartButton._ktTutorialBorder then
            local border = CreateFrame("Frame", nil, contents.StartButton, "BackdropTemplate")
            border:SetAllPoints(contents.StartButton)
            border:SetFrameLevel(contents.StartButton:GetFrameLevel() + 3)
            border:SetBackdrop({ edgeFile = BLANK_TEX, edgeSize = S.mult or 1 })
            border:SetBackdropBorderColor(0.46, 0.46, 0.54, 1)
            contents.StartButton._ktTutorialBorder = border

            contents.StartButton:HookScript("OnEnter", function(self)
                if self._ktTutorialBorder then
                    self._ktTutorialBorder:SetBackdropBorderColor(0.92, 0.92, 0.96, 1)
                end
            end)
            contents.StartButton:HookScript("OnLeave", function(self)
                if self.backdrop then
                    self.backdrop:SetBackdropBorderColor(0.34, 0.34, 0.40, 1)
                end
                if self._ktTutorialBorder then
                    self._ktTutorialBorder:SetBackdropBorderColor(0.46, 0.46, 0.54, 1)
                end
            end)
        end
    end
end

-- =============================================================
-- ENCOUNTER INFO TAB (overviewTab, lootTab, bossTab, modelTab)
-- =============================================================
local function UpdateInfoTab(tab)
    if not (tab and tab.backdrop) then return end
    local selectedRegion = tab.selected
    local selectedKind = type(selectedRegion)
    local selected = (selectedKind == "table" or selectedKind == "userdata")
        and selectedRegion.IsShown and selectedRegion:IsShown()
    if selected then
        local color = Accent()
        tab.backdrop:SetBackdropColor(unpack(EJ_SELECTED))
        tab.backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    elseif tab.IsMouseOver and tab:IsMouseOver() then
        tab.backdrop:SetBackdropColor(0.10, 0.10, 0.12, 0.98)
        tab.backdrop:SetBackdropBorderColor(1, 1, 1, 0.72)
    else
        tab.backdrop:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
        tab.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
    end
    if tab._ktEJIcon then
        tab._ktEJIcon:SetAlpha(selected and 1 or 0.74)
        if tab._ktEJIcon.SetDesaturated then tab._ktEJIcon:SetDesaturated(not selected) end
    end
end

local function SkinInfoTab(tab)
    if not tab or tab._ktSkinned then return end

    -- Find icon: named field -> first non-special, non-background texture
    local icon = tab.unselected or tab.Icon or tab.icon
    if not icon and tab.GetNumRegions then
        local hl_tex      = tab.GetHighlightTexture and tab:GetHighlightTexture()
        local pushed_tex  = tab.GetPushedTexture    and tab:GetPushedTexture()
        local disable_tex = tab.GetDisabledTexture  and tab:GetDisabledTexture()
        for i = 1, tab:GetNumRegions() do
            local region = select(i, tab:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("Texture")
                and region ~= hl_tex and region ~= pushed_tex and region ~= disable_tex then
                local atlas = region.GetAtlas and region:GetAtlas()
                local tex   = region.GetTexture and region:GetTexture()
                -- Skip chrome/background textures, keep actual icons
                if atlas or (tex and not tostring(tex):find("UI%-EJ%-")) then
                    icon = region
                    break
                end
            end
        end
    end

    -- Selectively hide chrome textures but NOT the icon
    if tab.GetNumRegions then
        local hl_tex      = tab.GetHighlightTexture and tab:GetHighlightTexture()
        local pushed_tex  = tab.GetPushedTexture    and tab:GetPushedTexture()
        local disable_tex = tab.GetDisabledTexture  and tab:GetDisabledTexture()
        for i = 1, tab:GetNumRegions() do
            local region = select(i, tab:GetRegions())
            if region and region ~= icon and region ~= hl_tex
                and region ~= pushed_tex and region ~= disable_tex
                and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end
    end

    S:CreateBackdrop(tab, true)

    if tab.backdrop then
        S:SetInside(tab.backdrop, tab, 2)
        tab.backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    end

    -- Clone the native icon. Blizzard hides/shows the selected and unselected
    -- regions when changing tabs, so using either region directly makes the
    -- icon disappear in one of the two states.
    if icon then
        local sourceIcon = icon
        local displayIcon = tab:CreateTexture(nil, "OVERLAY", nil, 7)
        local atlas = sourceIcon.GetAtlas and sourceIcon:GetAtlas()
        if atlas then
            displayIcon:SetAtlas(atlas)
        elseif sourceIcon.GetTexture then
            displayIcon:SetTexture(sourceIcon:GetTexture())
            if sourceIcon.GetTexCoord then displayIcon:SetTexCoord(sourceIcon:GetTexCoord()) end
        end
        sourceIcon:SetAlpha(0)
        displayIcon:SetPoint("TOP", tab, "TOP", 0, -4)
        displayIcon:SetSize(36, 36)
        icon = displayIcon
        tab._ktEJIcon = displayIcon
    end

    local label = FindRowText(tab)
    if label then
        label:SetParent(tab)
        label:SetDrawLayer("OVERLAY", 7)
        EnsureReadableFont(label, 11, 1, 1, 1)
        label:ClearAllPoints()
        if icon then
            label:SetPoint("TOP", icon, "BOTTOM", 0, -2)
        else
            label:SetPoint("CENTER", tab, "CENTER", 0, 1)
        end
    end

    local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
    if hl and tab.backdrop then
        local color = Accent()
        hl:SetColorTexture(color[1], color[2], color[3], 0.16)
        S:SetInside(hl, tab.backdrop)
    end

    tab:HookScript("OnEnter", UpdateInfoTab)
    tab:HookScript("OnLeave", UpdateInfoTab)
    local selectedRegion = tab.selected
    local selectedKind = type(selectedRegion)
    if (selectedKind == "table" or selectedKind == "userdata") and not tab._ktEJSelectionHooked then
        if type(selectedRegion.Show) == "function" then
            hooksecurefunc(selectedRegion, "Show", function() UpdateInfoTab(tab) end)
        end
        if type(selectedRegion.Hide) == "function" then
            hooksecurefunc(selectedRegion, "Hide", function() UpdateInfoTab(tab) end)
        end
        tab._ktEJSelectionHooked = true
    end

    tab._ktSkinned = true
    UpdateInfoTab(tab)
end

-- =============================================================
-- MAIN SKIN FUNCTION
-- =============================================================
local _ejHooked = false

local function SkinEncounterJournal()
    if not (S.db.enable and S.db.encounterjournal) then return end

    local EJ = _G.EncounterJournal
    if not EJ then return end

    -- ===== Main frame: native Adventure Guide artwork over the KUI shell =====
    S:SkinPremiumWindow(EJ)
    local shellData = S:GetFFD(EJ)
    if shellData.atlasBorderFrame then shellData.atlasBorderFrame:Hide() end
    if S.ApplyKuiSurface then
        S:ApplyKuiSurface(EJ)
    end
    if shellData.topBar then
        shellData.topBar:SetColorTexture(0, 0, 0, 0.35)
        shellData.topBar:SetHeight(24)
    end
    ReassertEncounterJournalShell(EJ)
    if not EJ._ktModernShellBorder then
        local border = CreateFrame("Frame", nil, EJ, "BackdropTemplate")
        border:SetAllPoints(EJ)
        border:SetFrameLevel(EJ:GetFrameLevel() + 20)
        border:SetBackdrop({ edgeFile = BLANK_TEX, edgeSize = S.mult or 1 })
        local color = Accent()
        border:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        EJ._ktModernShellBorder = border
        S:RegisterBlizzardWindowBorder(border, function(self, enabled, accent)
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], accent[4] or 1)
            self:SetAlpha(enabled and 1 or 0)
        end)

        local divider = EJ:CreateTexture(nil, "ARTWORK", nil, 6)
        divider:SetColorTexture(color[1], color[2], color[3], 0.90)
        divider:SetPoint("TOPLEFT", EJ, "TOPLEFT", 1, -24)
        divider:SetPoint("TOPRIGHT", EJ, "TOPRIGHT", -1, -24)
        divider:SetHeight(1)
        EJ._ktModernHeaderDivider = divider
    end
    if EJ.CloseButton then
        S:HandleCloseButton(EJ.CloseButton)
    end
    if EJ.TitleText then
        EnsureReadableFont(EJ.TitleText, 14, 1, 0.82, 0.18)
    end

    -- The NavBar spans almost the full width. A backdrop on that container
    -- creates the oversized empty "Home" strip seen on the landing pages;
    -- only the breadcrumb buttons themselves should look interactive.
    local NavBar = EJ.NavBar or EJ.navBar or _G.EncounterJournalNavBar
    if NavBar then
        S:StripTextures(NavBar)
        ModernPanel(NavBar, 0)
        if NavBar.backdrop then NavBar.backdrop:SetAlpha(0) end
        if NavBar._ktEJPanelTexture then NavBar._ktEJPanelTexture:SetAlpha(0) end
        S.HandleNavBarButtons(NavBar)
        if NavBar.homeButton then
            S:HandleButton(NavBar.homeButton)
        end
        if NavBar.overflow then
            S:HandleButton(NavBar.overflow)
        end
    end

    -- SearchBox
    local SearchBox = EJ.SearchBox or EJ.searchBox or _G.EncounterJournalSearchBox
    if SearchBox then
        S:HandleEditBox(SearchBox)
        local d = S:GetFFD(SearchBox)
        if d.origP == nil then
            local p, rel, rp, x, y = SearchBox:GetPoint(1)
            if p then
                d.origP, d.origRel, d.origRP = p, rel, rp
                d.origX, d.origY = x or 0, y or 0
                SearchBox:ClearAllPoints()
                SearchBox:SetPoint(d.origP, d.origRel, d.origRP, d.origX, d.origY - 2)
            end
        end
    end
    ReassertSectionHeader(EJ, NavBar, SearchBox)

    -- Inset
    local Inset = EJ.Inset or EJ.inset or _G.EncounterJournalInset
    if Inset then
        S:StripTextures(Inset)
        ModernPanel(Inset, 0.82)
    end

    -- ===== Bottom / side tabs =====
    local tabs, tabSeen = {}, {}
    local function AddBottomTab(tab)
        if tab and not tabSeen[tab] then
            tabSeen[tab] = true
            tabs[#tabs + 1] = tab
        end
    end
    AddBottomTab(EJ.JourneysTab or _G.EncounterJournalJourneysTab)
    AddBottomTab(EJ.MonthlyActivitiesTab or _G.EncounterJournalTravelerTab or _G.EncounterJournalMonthlyActivitiesTab)
    AddBottomTab(EJ.suggestTab or _G.EncounterJournalSuggestTab)
    AddBottomTab(EJ.dungeonsTab or _G.EncounterJournalDungeonTab)
    AddBottomTab(EJ.raidsTab or _G.EncounterJournalRaidTab)
    AddBottomTab(EJ.LootJournalTab or _G.EncounterJournalLootJournalTab)
    AddBottomTab(EJ.DelvesTab or _G.EncounterJournalDelvesTab)
    AddBottomTab(EJ.ItemSetsTab or _G.EncounterJournalItemSetsTab)
    AddBottomTab(EJ.TutorialsTab or _G.EncounterJournalTutorialsTab)
    for _, tab in ipairs(tabs) do SkinBottomTab(tab, EJ) end
    LayoutBottomTabs(EJ, tabs)

    -- JourneysPanel
    local JourneysPanel = _G.EncounterJournalJourneysPanel or EJ.JourneysFrame
    if JourneysPanel then
        ModernPanel(JourneysPanel, 0.78)
        if JourneysPanel.BorderFrame then
            S:StripTextures(JourneysPanel.BorderFrame)
            JourneysPanel.BorderFrame:SetAlpha(0)
        end
        if JourneysPanel.ScrollBox then
            if JourneysPanel.ScrollBox.ScrollBar then
                SkinModernScrollBar(JourneysPanel.ScrollBox.ScrollBar)
            end
            SkinScrollChildrenButtons(JourneysPanel.ScrollBox, "_ktJourneyButtonSkinned", function(child)
                -- Journey entries carry their own native card artwork.  The generic
                -- button skin replaces those state textures, so style the card in
                -- place and leave Blizzard's Normal/Pushed art intact.
                SkinJourneyCard(child)
                if child.Title       then EnsureReadableFont(child.Title,       12, 1, 1, 1) end
                if child.Description then EnsureReadableFont(child.Description, 10, 1, 1, 1) end
                if child.JourneyIcon then
                    S:HandleIcon(child.JourneyIcon, true)
                    RaiseIcon(child.JourneyIcon)
                end
                if child.ObjectiveIcon then
                    S:HandleIcon(child.ObjectiveIcon, true)
                    RaiseIcon(child.ObjectiveIcon)
                end
            end)
        end
        if JourneysPanel.ProgressFrame and JourneysPanel.ProgressFrame.ScrollBar then
            SkinModernScrollBar(JourneysPanel.ProgressFrame.ScrollBar)
        end
        if JourneysPanel.ScrollBar then SkinModernScrollBar(JourneysPanel.ScrollBar) end
        ForEachScrollBoxFrame(JourneysPanel.JourneysList, SkinJourneyCard, "_ktEJJourneyCardsHooked")
        if JourneysPanel.JourneyProgress then
            local progress = JourneysPanel.JourneyProgress
            EnsureReadableFont(progress.JourneyName, 17, 1, 1, 1)
            if progress.DelveRewardProgressBar then S:HandleStatusBar(progress.DelveRewardProgressBar) end
            if progress.OverviewBtn then S:HandleButton(progress.OverviewBtn) end
        end
        if JourneysPanel.JourneyOverview then
            local overview = JourneysPanel.JourneyOverview
            EnsureReadableFont(overview.JourneyName, 17, 1, 1, 1)
            EnsureReadableFont(overview.JourneyDescription, 11, 0.88, 0.88, 0.90)
            EnsureReadableFont(overview.HighlightLabel, 11, 1, 0.82, 0.18)
            if overview.OverviewBtn then S:HandleButton(overview.OverviewBtn) end
        end
    end

    -- Instance Select: native dungeon artwork preserved at full opacity
    local InstanceSelect = _G.EncounterJournalInstanceSelect
    if InstanceSelect then
        ModernPanel(InstanceSelect, 0.72)
        ReassertInstanceSelectArt(InstanceSelect)
        if not InstanceSelect._ktEJArtHooked then
            InstanceSelect:HookScript("OnShow", function(self)
                if C_Timer then C_Timer.After(0, function() ReassertInstanceSelectArt(self) end) end
            end)
            InstanceSelect._ktEJArtHooked = true
        end
        if InstanceSelect.Title then EnsureReadableFont(InstanceSelect.Title, 16, 1, 1, 1) end

        if InstanceSelect.TierDropDown      then S:HandleDropDownBox(InstanceSelect.TierDropDown)      end
        if InstanceSelect.ExpansionDropdown then S:HandleDropDownBox(InstanceSelect.ExpansionDropdown) end
        if InstanceSelect.ScrollBar   then SkinModernScrollBar(InstanceSelect.ScrollBar) end
        ForEachScrollBoxFrame(InstanceSelect.ScrollBox, InstanceSelectUpdateChild, "_ktEJInstanceRowsHooked")
    end

    -- Encounter Frame: main info panel
    local EncounterFrame = _G.EncounterJournalEncounterFrame
    if EncounterFrame then
        local Info = EncounterFrame.Info or EncounterFrame.info
        if Info then
            ModernPanel(Info, 0.82)
            if Info.bg then
                SetNativeArtwork(Info.bg, 1, 0.52, 0, true)
            end
            -- Keep the native encounter artwork opaque and color-dimmed, using
            -- the same treatment as the Spellbook pages.
            if Info.leftShadow then Info.leftShadow:SetAlpha(0) end
            if Info.rightShadow then Info.rightShadow:SetAlpha(0) end
            for _, tab in ipairs({ Info.overviewTab, Info.lootTab, Info.bossTab, Info.modelTab }) do
                SkinInfoTab(tab)
            end

            -- Scroll bars (handle both naming conventions)
            if Info.BossesScrollBar   then SkinModernScrollBar(Info.BossesScrollBar)   end
            if Info.OverviewScrollBar then SkinModernScrollBar(Info.OverviewScrollBar) end
            if Info.DetailsScrollBar  then SkinModernScrollBar(Info.DetailsScrollBar)  end
            if Info.overviewScroll and Info.overviewScroll.ScrollBar then
                SkinModernScrollBar(Info.overviewScroll.ScrollBar)
            end
            if Info.detailsScroll and Info.detailsScroll.ScrollBar then
                SkinModernScrollBar(Info.detailsScroll.ScrollBar)
            end

            -- Difficulty / filter dropdowns
            if Info.Difficulty  then S:HandleDropDownBox(Info.Difficulty)  end
            if Info.difficulty  then S:HandleDropDownBox(Info.difficulty)  end
            if Info.LootContainer then
                if Info.LootContainer.Filter     then S:HandleDropDownBox(Info.LootContainer.Filter)     end
                if Info.LootContainer.SlotFilter then S:HandleDropDownBox(Info.LootContainer.SlotFilter) end
                if Info.LootContainer.filter     then S:HandleDropDownBox(Info.LootContainer.filter)     end
                if Info.LootContainer.slotFilter then S:HandleDropDownBox(Info.LootContainer.slotFilter) end
                if Info.LootContainer.ScrollBar  then SkinModernScrollBar(Info.LootContainer.ScrollBar)    end
                ModernPanel(Info.LootContainer, 0.84)
            end

            -- Info panel text: headers gold, body warm white
            for _, region in ipairs({ Info:GetRegions() }) do
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    local _, fontSize = region:GetFont()
                    if (fontSize or 0) >= 15 then
                        EnsureReadableFont(region, fontSize, 1, 0.82, 0.18)
                    else
                        EnsureReadableFont(region, nil, 0.94, 0.90, 0.82)
                    end
                end
            end
        end

        -- Named global text
        if _G.EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildTitle then
            EnsureReadableFont(_G.EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildTitle, 16, 1, 0.82, 0.18)
        end
        if _G.EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildLoreDescription then
            EnsureReadableFont(_G.EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildLoreDescription, nil, 0.94, 0.90, 0.82)
        end
        if _G.EncounterJournalEncounterFrameInfoDetailsScrollFrameScrollChildDescription then
            EnsureReadableFont(_G.EncounterJournalEncounterFrameInfoDetailsScrollFrameScrollChildDescription, nil, 0.94, 0.90, 0.82)
        end
    end

    -- InstanceFrame: keep native lore artwork opaque and color-dimmed.
    -- Same treatment for dungeons and raids.
    if _G.EncounterJournalEncounterFrameInstanceFrame then
        local instFrame = _G.EncounterJournalEncounterFrameInstanceFrame
        ModernPanel(instFrame, 0.35)
        if instFrame._ktEJPanelTexture then
            instFrame._ktEJPanelTexture:SetAlpha(0)
        end
        if instFrame.loreBG then
            instFrame.loreBG:SetDrawLayer("ARTWORK", 0)
            SetNativeArtwork(instFrame.loreBG, 1, 0.52, 0, true)
        end
        if instFrame.titleBG then
            SetNativeArtwork(instFrame.titleBG, 1, 0.56, 0, true)
        end
        if instFrame.LoreScrollBar then SkinModernScrollBar(instFrame.LoreScrollBar) end
        if instFrame.MapButton then
            S:HandleButton(instFrame.MapButton)
        end
    end

    -- Filter toggle buttons
    if _G.EncounterJournalEncounterFrameInfoFilterToggle then
        S:HandleButton(_G.EncounterJournalEncounterFrameInfoFilterToggle)
    end
    if _G.EncounterJournalEncounterFrameInfoSlotFilterToggle then
        S:HandleButton(_G.EncounterJournalEncounterFrameInfoSlotFilterToggle)
    end

    -- Search results
    if _G.EncounterJournalSearchResults then
        local SearchResultsFrame = _G.EncounterJournalSearchResults
        if not SearchResultsFrame.backdrop then
            S:CreateBackdrop(SearchResultsFrame, true)
        end
        SetBackdrop(SearchResultsFrame.backdrop, EJ_BG, EJ_EDGE)
        S:RegisterBlizzardWindowBackground(SearchResultsFrame.backdrop)
        if SearchResultsFrame.ScrollBar then
            SkinModernScrollBar(SearchResultsFrame.ScrollBar)
        end
        ForEachScrollBoxFrame(SearchResultsFrame.ScrollBox, function(child)
            SkinModernListRow(child)
            if child.name then EnsureReadableFont(child.name, 11, 1, 1, 1) end
            if child.type then EnsureReadableFont(child.type, 10, 0.76, 0.76, 0.80) end
            if child.icon and not child._ktEJSearchIcon then
                S:HandleIcon(child.icon, true)
                RaiseIcon(child.icon)
                child._ktEJSearchIcon = true
            end
        end, "_ktEJSearchRowsHooked")
        SkinScrollChildrenButtons(SearchResultsFrame.ScrollFrame or SearchResultsFrame.ScrollBox, "_ktSearchResultSkinned", function(child)
            SkinModernListRow(child)
            if child.name then EnsureReadableFont(child.name, 11, 1, 1, 1) end
            if child.type then EnsureReadableFont(child.type, 10, 0.8, 0.8, 0.8) end
            if child.icon then
                S:HandleIcon(child.icon, true)
                RaiseIcon(child.icon)
            end
        end)
    end

    if _G.EncounterJournalSearchResultsCloseButton then
        S:HandleCloseButton(_G.EncounterJournalSearchResultsCloseButton)
    end

    if _G.EncounterJournalSearchBox and _G.EncounterJournalSearchBox.searchPreviewContainer then
        -- Keep the native search-preview art; only add the same restrained panel
        -- treatment used elsewhere in the guide.
        ModernPanel(_G.EncounterJournalSearchBox.searchPreviewContainer, 0.68)
    end

    -- Monthly Activities
    if _G.EncounterJournalMonthlyActivitiesFrame then
        local Activities = _G.EncounterJournalMonthlyActivitiesFrame
        ModernPanel(Activities, 0.78)
        ReassertMonthlyArt(Activities)
        if not Activities._ktEJArtHooked then
            Activities:HookScript("OnShow", function(self)
                if C_Timer then C_Timer.After(0, function() ReassertMonthlyArt(self) end) end
            end)
            if Activities.ThemeContainer then
                Activities.ThemeContainer:HookScript("OnShow", function()
                    if C_Timer then C_Timer.After(0, function() ReassertMonthlyArt(Activities) end) end
                end)
            end
            Activities._ktEJArtHooked = true
        end
        if Activities.FilterList then
            ModernPanel(Activities.FilterList, 0.86)
            if Activities.FilterList.Bg then Activities.FilterList.Bg:SetAlpha(0) end
            ForEachScrollBoxFrame(Activities.FilterList.ScrollBox, SkinMonthlyFilterRow, "_ktEJFilterRowsHooked")
        end
        if Activities.Divider then
            local color = Accent()
            Activities.Divider:SetVertexColor(color[1], color[2], color[3], 0.38)
            Activities.Divider:SetAlpha(0.50)
        end
        -- ThresholdBar and BonusThresholdBar deliberately stay untouched: their
        -- native track, fill and reward-threshold artwork belongs to this theme.
        if Activities.HeaderContainer then
            EnsureReadableFont(Activities.HeaderContainer.Title, 16, 1, 1, 1)
            EnsureReadableFont(Activities.HeaderContainer.Month, 13, 1, 0.82, 0.18)
            EnsureReadableFont(Activities.HeaderContainer.TimeLeft, 11, 0.90, 0.90, 0.92)
        end
        if Activities.ScrollBar then SkinModernScrollBar(Activities.ScrollBar) end
        ForEachScrollBoxFrame(Activities.ScrollBox, SkinMonthlyActivityRow, "_ktEJActivityRowsHooked")
        if Activities.FilterList and Activities.FilterList.ScrollBar then
            SkinModernScrollBar(Activities.FilterList.ScrollBar)
        end
    end

    -- Loot Journal
    if EJ.LootJournal then
        ModernPanel(EJ.LootJournal, 0.82)
        if EJ.LootJournal.ScrollBar then SkinModernScrollBar(EJ.LootJournal.ScrollBar) end
        if EJ.LootJournal.ClassDropdown then S:HandleDropDownBox(EJ.LootJournal.ClassDropdown) end
        if EJ.LootJournal.RuneforgePowerDropdown then S:HandleDropDownBox(EJ.LootJournal.RuneforgePowerDropdown) end
        ForEachScrollBoxFrame(EJ.LootJournal.ScrollBox, SkinLootJournalRow, "_ktEJLootRowsHooked")
    end
    if EJ.LootJournalViewDropdown then S:HandleDropDownBox(EJ.LootJournalViewDropdown) end

    -- Item Sets
    if EJ.LootJournalItems and EJ.LootJournalItems.ItemSetsFrame then
        local ItemSetsFrame = EJ.LootJournalItems.ItemSetsFrame
        ModernPanel(ItemSetsFrame, 0.82)
        if ItemSetsFrame.ScrollBar    then SkinModernScrollBar(ItemSetsFrame.ScrollBar)       end
        if ItemSetsFrame.ClassDropdown then S:HandleDropDownBox(ItemSetsFrame.ClassDropdown) end
        ForEachScrollBoxFrame(ItemSetsFrame.ScrollBox, SkinItemSetRow, "_ktEJItemSetRowsHooked")
    end

    -- Suggest Frame: only skin nav buttons; leave suggestion cards untouched to preserve icons
    local suggestFrame = EJ.suggestFrame
    if suggestFrame then
        ModernPanel(suggestFrame, 0.58)
        for i = 1, 3 do
            local suggestion = suggestFrame["Suggestion"..i]
            StyleSuggestionCard(suggestion, i)
        end
    end

    -- Tutorials frame
    if EJ.TutorialsFrame then
        StyleTutorialsFrame(EJ.TutorialsFrame)
    end
    
    -- DEBOUNCED LAYOUT REFRESH
    if not _ejHooked then
        _ejHooked = true
        local refresh = S:Debounce(function()
            if not EJ:IsVisible() then return end

            -- Several EJ mixins restore their atlas chrome during OnShow or a
            -- tab transition. Reassert the shell without touching content art.
            ReassertEncounterJournalShell(EJ)
            ReassertSectionHeader(EJ, NavBar, SearchBox)

            for _, tab in ipairs(tabs) do
                UpdateBottomTab(tab, EJ)
            end
            LayoutBottomTabs(EJ, tabs)
            
            if EJ.instanceSelect then
                ReassertInstanceSelectArt(EJ.instanceSelect)
                if EJ.instanceSelect.Title then
                    local id = EJ.selectedTab
                    local showTitle = (EJ.dungeonsTab and id == EJ.dungeonsTab:GetID())
                        or (EJ.raidsTab and id == EJ.raidsTab:GetID())
                    EJ.instanceSelect.Title:SetShown(showTitle and true or false)
                end
                local scrollBox = EJ.instanceSelect.ScrollBox or EJ.instanceSelect.ScrollFrame
                if scrollBox and scrollBox.ForEachFrame then
                    scrollBox:ForEachFrame(InstanceSelectUpdateChild)
                end
            end

            local journeys = EJ.JourneysFrame or _G.EncounterJournalJourneysPanel
            if journeys then
                if journeys.BorderFrame then journeys.BorderFrame:SetAlpha(0) end
                ForEachScrollBoxFrame(journeys.JourneysList, SkinJourneyCard, "_ktEJJourneyCardsHooked")
            end

            local activities = EJ.MonthlyActivitiesFrame or _G.EncounterJournalMonthlyActivitiesFrame
            if activities then
                ReassertMonthlyArt(activities)
                ForEachScrollBoxFrame(activities.ScrollBox, SkinMonthlyActivityRow, "_ktEJActivityRowsHooked")
                if activities.FilterList then
                    ForEachScrollBoxFrame(activities.FilterList.ScrollBox, SkinMonthlyFilterRow, "_ktEJFilterRowsHooked")
                end
            end

            if EJ.suggestFrame then
                for i = 1, 3 do
                    local suggestion = EJ.suggestFrame["Suggestion"..i]
                    StyleSuggestionCard(suggestion, i)
                end
            end
            if EJ.TutorialsFrame then StyleTutorialsFrame(EJ.TutorialsFrame) end

            if EJ.LootJournal then
                ForEachScrollBoxFrame(EJ.LootJournal.ScrollBox, SkinLootJournalRow, "_ktEJLootRowsHooked")
            end
            if EJ.LootJournalItems and EJ.LootJournalItems.ItemSetsFrame then
                ForEachScrollBoxFrame(EJ.LootJournalItems.ItemSetsFrame.ScrollBox, SkinItemSetRow, "_ktEJItemSetRowsHooked")
            end
            
            local Info = EJ.encounter and (EJ.encounter.info or EJ.encounter.Info)
            if Info then
                for _, tab in ipairs({ Info.overviewTab, Info.lootTab, Info.bossTab, Info.modelTab }) do
                    UpdateInfoTab(tab)
                end
                local bossScrollBox = Info.BossesScrollBox or (Info.bossesScroll and Info.bossesScroll.ScrollBox)
                if bossScrollBox and bossScrollBox.ForEachFrame then
                    bossScrollBox:ForEachFrame(BossesScrollUpdateChild)
                end
                
                if Info.LootContainer then
                    local lootScrollBox = Info.LootContainer.ScrollBox
                    if lootScrollBox and lootScrollBox.ForEachFrame then
                        lootScrollBox:ForEachFrame(LootContainerUpdateChild)
                    end
                end
                
                if Info.overviewScroll and Info.overviewScroll.child and Info.overviewScroll.child.header then
                    if Info.overviewScroll.child.header.SetAlpha then
                        Info.overviewScroll.child.header:SetAlpha(0)
                    end
                end

                -- [FIX] Re-procesar textos del panel de información (overview, bosses, detalles)
                -- cada vez que se refresca, ya que Blizzard recrea FontStrings al cambiar de
                -- dungeons/boss. Aplicar colores legibles con hooks persistentes.
                local function ReprocessInfoText(frame, depth)
                    if not frame or depth > 6 then return end
                    if frame.ForegroundTextContainer then
                        local ftc = frame.ForegroundTextContainer
                        for _, child in ipairs({ ftc:GetChildren() }) do
                            if child and child.GetObjectType and child:GetObjectType() == "FontString" then
                                local _, fontSize = child:GetFont()
                                if (fontSize or 0) >= 15 then
                                    EnsureReadableFont(child, fontSize, 1, 0.82, 0.18)
                                else
                                    EnsureReadableFont(child, nil, 0.94, 0.90, 0.82)
                                end
                            end
                        end
                    end
                    if frame.GetRegions then
                        for _, region in ipairs({ frame:GetRegions() }) do
                            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                                local _, fontSize = region:GetFont()
                                if (fontSize or 0) >= 15 then
                                    EnsureReadableFont(region, fontSize, 1, 0.82, 0.18)
                                else
                                    EnsureReadableFont(region, nil, 0.94, 0.90, 0.82)
                                end
                            end
                        end
                    end
                    if frame.GetChildren then
                        for _, child in ipairs({ frame:GetChildren() }) do
                            if child and child.IsObjectType and child:IsObjectType("ScrollFrame") then
                                local sf = child.ScrollFrame or child
                                if sf.GetScrollChild then
                                    ReprocessInfoText(sf:GetScrollChild(), depth + 1)
                                end
                            end
                            ReprocessInfoText(child, depth + 1)
                        end
                    end
                end
                ReprocessInfoText(Info, 0)

                -- Re-procesar textos nombrados específicos del overview/boss
                for _, key in ipairs({
                    "EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildTitle",
                    "EncounterJournalEncounterFrameInfoOverviewScrollFrameScrollChildLoreDescription",
                    "EncounterJournalEncounterFrameInfoDetailsScrollFrameScrollChildDescription",
                    "EncounterJournalEncounterFrameInfoBossTitle",
                    "EncounterJournalEncounterFrameInfoBossDescriptionText",
                }) do
                    local fs = _G[key]
                    if fs then
                        EnsureReadableFont(fs, nil, 0.94, 0.90, 0.82)
                    end
                end
            end
            
            -- S:FadeRegions(EJ)  -- REMOVED: this destroys native art like Renowns!
        end)
        
        for _, fn in ipairs({ 
            "EncounterJournal_DisplayInstance", 
            "EncounterJournal_DisplayEncounter",
            "EncounterJournal_SetUpOverview", 
            "EncounterJournal_ToggleHeaders",
            "EncounterJournal_SetTab", 
            "EJ_ContentTab_Select"
        }) do
            if type(_G[fn]) == "function" then 
                hooksecurefunc(fn, refresh) 
            end
        end
        
        EJ:HookScript("OnShow", function()
            refresh()
        end)
    end
end

S.SkinFuncs["Blizzard_EncounterJournal"] = SkinEncounterJournal
