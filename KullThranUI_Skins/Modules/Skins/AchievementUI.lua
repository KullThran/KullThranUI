local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc
local CreateColor = CreateColor
local pairs, next = pairs, next
local GetAchievementNumCriteria = GetAchievementNumCriteria
local GetAchievementCriteriaInfo = GetAchievementCriteriaInfo
local bit = bit

local function SetNativeArtwork(texture, alpha, brightness, desaturation)
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
    if texture.Show then texture:Show() end
end

local function ApplyAchievementPanelSatin(frame, options)
    if frame and S.ApplySatinSurface then
        S:ApplySatinSurface(frame, options or {
            inset = 1, baseAlpha = 0.11, sheenAlpha = 0.04, edgeAlpha = 0.09,
        })
    end
end

-- Helper for StatusBars
local function SkinStatusBar(bar)
    if not bar then return end
    S:StripTextures(bar)
    S:CreateBackdrop(bar)
    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        bar:GetStatusBarTexture():SetGradient("VERTICAL", CreateColor(0, 0.4, 0, 1), CreateColor(0, 0.6, 0, 1))
    end
end

local function HandleSummaryBar(frame)
    if not frame then return end
    S:StripTextures(frame)
    local bar = frame.StatusBar
    if bar then
        SkinStatusBar(bar)
        if bar.Title then 
            S:HandleFont(bar.Title)
            bar.Title:SetTextColor(1, 1, 1)
            bar.Title:ClearAllPoints()
            bar.Title:SetPoint("LEFT", bar, "LEFT", 6, 1)
            bar.Title:SetJustifyH("LEFT")
        end
        if bar.Text then 
            S:HandleFont(bar.Text)
            bar.Text:ClearAllPoints()
            bar.Text:SetPoint("RIGHT", bar, "RIGHT", -5, 1)
            bar.Text:SetJustifyH("RIGHT")
        end
    end
end

local function SetupButtonHighlight(button, backdrop)
    if not button then return end
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    local hl = button:GetHighlightTexture()
    if hl then
        hl:SetVertexColor(1, 1, 1, 0.2)
        hl:SetBlendMode("ADD")
        if backdrop then
            S:SetInside(hl, backdrop)
        else
            S:SetInside(hl, button)
        end
    end
end

local function UpdateAccountString(button)
    if button.DateCompleted and button.DateCompleted:IsShown() then
        if button.accountWide then
            button.Label:SetTextColor(0, 0.6, 1)
        else
            button.Label:SetTextColor(0.9, 0.9, 0.9)
        end
    elseif button.accountWide then
        button.Label:SetTextColor(0, 0.3, 0.5)
    else
        button.Label:SetTextColor(0.65, 0.65, 0.65)
    end
end

local function SkinAchievementButton(button)
    if not button.isSkinned then
        S:StripTextures(button, true)
        if button.Background then button.Background:SetAlpha(0) end
        if button.Highlight then button.Highlight:SetAlpha(0) end
        if button.Icon and button.Icon.frame then button.Icon.frame:Hide() end
        
        if button.Description then
            S:HandleFont(button.Description)
        end
        
        if button.Label then S:HandleFont(button.Label) end
        if button.Reward then S:HandleFont(button.Reward) end
        if button.DateCompleted then S:HandleFont(button.DateCompleted) end
        if button.HiddenDescription then S:HandleFont(button.HiddenDescription) end

        S:CreateBackdrop(button)
        button.backdrop:SetBackdropColor(0, 0, 0, 0.16)
        button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        button.backdrop:SetPoint("TOPLEFT", 2, -2)
        button.backdrop:SetPoint("BOTTOMRIGHT", -2, 2)

        if button.Icon and button.Icon.texture then
            S:HandleIcon(button.Icon.texture)
        end

        if button.Tracked then
            S:HandleCheckBox(button.Tracked)
            button.Tracked:SetSize(20, 20)
        end
        
        if button.Check then button.Check:SetAlpha(0) end

        if button.UpdatePlusMinusTexture then
             hooksecurefunc(button, "UpdatePlusMinusTexture", UpdateAccountString)
        end

        button.isSkinned = true
    end

    -- [FIX] Forzar color de descripción en cada actualización (evita texto negro)
    if button.Description then button.Description:SetTextColor(0.9, 0.9, 0.9) end
    if button.HiddenDescription then button.HiddenDescription:SetTextColor(0.9, 0.9, 0.9) end
end

S.SkinFuncs["Blizzard_AchievementUI"] = function()
    if not (S.db.enable and S.db.achievement) then return end

    -- [FIX] Blizzard Bug: AchievementFrameComparison_UpdateStatusBars crashes if id is "summary"
    -- Use hooksecurefunc to avoid tainting Blizzard protected code (Midnight 12.x requirement)
    if _G.AchievementFrameComparison_UpdateStatusBars then
        hooksecurefunc("AchievementFrameComparison_UpdateStatusBars", function(id)
            if id == "summary" then return end
        end)
    end

    local AchievementFrame = _G.AchievementFrame
    S:HandlePortraitFrame(AchievementFrame)
    ApplyAchievementPanelSatin(AchievementFrame, {
        inset = 10, baseAlpha = 0.17, sheenAlpha = 0.055, edgeAlpha = 0.12,
    })
    if S.ApplyKuiSurface then
        S:ApplyKuiSurface(AchievementFrame)
    end

    -- The castle hall art is a child frame that covers the whole shell and
    -- hides the KUI surface; remove it so the texture shows through. The frame
    -- name differs across builds, so also scan direct children.
    local function KillAchievementHall()
        local af = _G.AchievementFrame
        if not af then return end
        if af.Background then S:Kill(af.Background) end
        local bg = _G.AchievementFrameBackground
        if bg then S:Kill(bg) end
        if af.GetChildren then
            for _, child in ipairs({ af:GetChildren() }) do
                local name = child.GetName and child:GetName() or ""
                if type(name) == "string" and name:find("Background") then
                    S:Kill(child)
                end
            end
        end
    end
    KillAchievementHall()
    if not AchievementFrame._ktHallKilled then
        AchievementFrame:HookScript("OnShow", KillAchievementHall)
        AchievementFrame._ktHallKilled = true
    end

    -- Keep the large native artwork visible under the neutral satin surface.
    for i = 1, AchievementFrame:GetNumRegions() do
        local r = select(i, AchievementFrame:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") then
            local drawLayer = r.GetDrawLayer and r:GetDrawLayer()
            if drawLayer == "BACKGROUND" then
                SetNativeArtwork(r, 0.10, 0.74, 0.10)
            elseif drawLayer == "BORDER" then
                SetNativeArtwork(r, 0.12, 0.66, 0.16)
            end
        end
    end

    if AchievementFrame.Header then
        -- Header engraving remains visible but stays behind the content.
        for i = 1, AchievementFrame.Header:GetNumRegions() do
            local r = select(i, AchievementFrame.Header:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                SetNativeArtwork(r, 0.12, 0.72, 0.12)
            end
        end
        if AchievementFrame.Header.Title then AchievementFrame.Header.Title:Hide() end
        if AchievementFrame.Header.Points then 
            AchievementFrame.Header.Points:ClearAllPoints()
            AchievementFrame.Header.Points:SetPoint("TOP", AchievementFrame, "TOP", 0, -5) 
            S:HandleFont(AchievementFrame.Header.Points)
        end
    end

    if AchievementFrame.SearchBox then
        S:HandleEditBox(AchievementFrame.SearchBox)
        AchievementFrame.SearchBox:ClearAllPoints()
        AchievementFrame.SearchBox:SetPoint("TOPRIGHT", AchievementFrame, "TOPRIGHT", -25, -25)
    end

    if _G.AchievementFrameFilterDropdown then
        S:HandleDropDownBox(_G.AchievementFrameFilterDropdown)
        _G.AchievementFrameFilterDropdown:ClearAllPoints()
        _G.AchievementFrameFilterDropdown:SetPoint("RIGHT", AchievementFrame.SearchBox, "LEFT", -5, 0)
    end

    for i = 1, 3 do
        local tab = _G["AchievementFrameTab"..i]
        if tab then S:HandleTab(tab) end
    end

    -- Categories
    if _G.AchievementFrameCategories then
        ApplyAchievementPanelSatin(_G.AchievementFrameCategories)
        if S.ApplyKuiSurface then
            S:ApplyKuiSurface(_G.AchievementFrameCategories)
        end
        for i = 1, _G.AchievementFrameCategories:GetNumRegions() do
            local r = select(i, _G.AchievementFrameCategories:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                SetNativeArtwork(r, 0.10, 0.70, 0.12)
            end
        end
        if _G.AchievementFrameCategories.ScrollBar then
            S:HandleScrollBar(_G.AchievementFrameCategories.ScrollBar)
        end
        
        if _G.AchievementFrameCategories.ScrollBox then
            hooksecurefunc(_G.AchievementFrameCategories.ScrollBox, "Update", function(self)
                self:ForEachFrame(function(child)
                    local button = child.Button
                    if button and not button.isSkinned then
                        S:StripTextures(button)
                        S:CreateBackdrop(button)
                        button.backdrop:SetBackdropColor(0, 0, 0, 0.16)
                        button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
                        button.backdrop:SetPoint("TOPLEFT", 0, -1)
                        button.backdrop:SetPoint("BOTTOMRIGHT", 0, 1)
                        SetupButtonHighlight(button, button.backdrop)
                        if button.Label then S:HandleFont(button.Label) end
                        button.isSkinned = true
                    end
                end)
            end)
        end
    end

    -- Achievements
    if _G.AchievementFrameAchievements then
        ApplyAchievementPanelSatin(_G.AchievementFrameAchievements)
        if S.ApplyKuiSurface then
            S:ApplyKuiSurface(_G.AchievementFrameAchievements)
        end
        for i = 1, _G.AchievementFrameAchievements:GetNumRegions() do
            local r = select(i, _G.AchievementFrameAchievements:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                SetNativeArtwork(r, 0.10, 0.70, 0.12)
            end
        end
        if _G.AchievementFrameAchievements.ScrollBar then
            S:HandleScrollBar(_G.AchievementFrameAchievements.ScrollBar)
        end
        
        if _G.AchievementFrameAchievements.ScrollBox then
            hooksecurefunc(_G.AchievementFrameAchievements.ScrollBox, "Update", function(self)
                self:ForEachFrame(SkinAchievementButton)
            end)
        end
    end

    -- Summary
    if _G.AchievementFrameSummary then
        ApplyAchievementPanelSatin(_G.AchievementFrameSummary)
        if S.ApplyKuiSurface then
            S:ApplyKuiSurface(_G.AchievementFrameSummary)
        end
        for i = 1, _G.AchievementFrameSummary:GetNumRegions() do
            local r = select(i, _G.AchievementFrameSummary:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                SetNativeArtwork(r, 0.10, 0.72, 0.10)
            end
        end
        
        if _G.AchievementFrameSummaryCategoriesHeaderTitle then
            S:HandleFont(_G.AchievementFrameSummaryCategoriesHeaderTitle)
            _G.AchievementFrameSummaryCategoriesHeaderTitle:SetTextColor(1, 1, 1)
        end
        if _G.AchievementFrameSummaryAchievementsHeaderTitle then
            S:HandleFont(_G.AchievementFrameSummaryAchievementsHeaderTitle)
            _G.AchievementFrameSummaryAchievementsHeaderTitle:SetTextColor(1, 1, 1)
        end

        for i = 1, 12 do
            local name = "AchievementFrameSummaryCategoriesCategory"..i
            local bu = _G[name]
            if bu then
                SkinStatusBar(bu)
                if bu.Label then 
                    S:HandleFont(bu.Label)
                    bu.Label:SetTextColor(1, 1, 1) 
                    bu.Label:ClearAllPoints()
                    bu.Label:SetPoint("LEFT", bu, "LEFT", 6, 1)
                    bu.Label:SetJustifyH("LEFT")
                end
                if bu.Text then 
                    S:HandleFont(bu.Text)
                    bu.Text:ClearAllPoints()
                    bu.Text:SetPoint("RIGHT", bu, "RIGHT", -5, 1)
                    bu.Text:SetJustifyH("RIGHT")
                end
                if _G[name.."ButtonHighlight"] then _G[name.."ButtonHighlight"]:SetAlpha(0) end
            end
        end
        if _G.AchievementFrameSummaryCategoriesStatusBar then
            SkinStatusBar(_G.AchievementFrameSummaryCategoriesStatusBar)
            local bar = _G.AchievementFrameSummaryCategoriesStatusBar
            if bar.Title then 
                S:HandleFont(bar.Title)
                bar.Title:ClearAllPoints()
                bar.Title:SetPoint("LEFT", bar, "LEFT", 6, 1)
            end
            if bar.Text then 
                S:HandleFont(bar.Text)
                bar.Text:ClearAllPoints()
                bar.Text:SetPoint("RIGHT", bar, "RIGHT", -5, 1)
            end
        end

        hooksecurefunc("AchievementFrameSummary_UpdateAchievements", function()
            for i = 1, _G.ACHIEVEMENTUI_MAX_SUMMARY_ACHIEVEMENTS or 4 do
                local button = _G["AchievementFrameSummaryAchievement"..i]
                if button then
                    if not button.isSkinned then
                        S:StripTextures(button, true)
                        S:CreateBackdrop(button)
                        button.backdrop:SetBackdropColor(0, 0, 0, 0.16)
                        button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
                        button.backdrop:SetPoint("TOPLEFT", 2, -2)
                        button.backdrop:SetPoint("BOTTOMRIGHT", -2, 2)
                        
                        if button.Icon then
                            if button.Icon.frame then button.Icon.frame:Hide() end
                            if button.Icon.texture then 
                                S:HandleIcon(button.Icon.texture)
                            end
                        end
                        
                        if button.Label then S:HandleFont(button.Label) end
                        if button.Description then S:HandleFont(button.Description) end
                        if button.DateCompleted then S:HandleFont(button.DateCompleted) end
                        
                        button.isSkinned = true
                    end
                    
                    if button.Label then button.Label:SetTextColor(1, 1, 1) end
                    if button.Description then button.Description:SetTextColor(0.9, 0.9, 0.9) end
                end
            end
        end)
    end
    
    -- Stats
    if _G.AchievementFrameStats then
        ApplyAchievementPanelSatin(_G.AchievementFrameStats)
        if S.ApplyKuiSurface then
            S:ApplyKuiSurface(_G.AchievementFrameStats)
        end
        for i = 1, _G.AchievementFrameStats:GetNumRegions() do
            local r = select(i, _G.AchievementFrameStats:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                SetNativeArtwork(r, 0.10, 0.70, 0.12)
            end
        end
        if _G.AchievementFrameStats.ScrollBar then
            S:HandleScrollBar(_G.AchievementFrameStats.ScrollBar)
        end
        if _G.AchievementFrameStats.ScrollBox then
             hooksecurefunc(_G.AchievementFrameStats.ScrollBox, "Update", function(self)
                self:ForEachFrame(function(child)
                    if not child.isSkinned then
                        S:StripTextures(child)
                        S:CreateBackdrop(child)
                        child.backdrop:SetBackdropColor(0, 0, 0, 0.16)
                        child.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
                        child.backdrop:SetPoint("TOPLEFT", 2, -S.mult)
                        child.backdrop:SetPoint("BOTTOMRIGHT", 4, S.mult)
                        SetupButtonHighlight(child, child.backdrop)
                        if child.Text then S:HandleFont(child.Text) end
                        if child.Value then S:HandleFont(child.Value) end
                        child.isSkinned = true
                    end
                end)
            end)
        end
    end
    
    -- Comparison
    if _G.AchievementFrameComparison then
        local Comparison = _G.AchievementFrameComparison
        ApplyAchievementPanelSatin(Comparison)
        if S.ApplyKuiSurface then
            S:ApplyKuiSurface(Comparison)
        end
        for i = 1, Comparison:GetNumRegions() do
            local r = select(i, Comparison:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                SetNativeArtwork(r, 0.10, 0.70, 0.12)
            end
        end
        if Comparison.Summary then
            HandleSummaryBar(Comparison.Summary.Player)
            HandleSummaryBar(Comparison.Summary.Friend)
        end
        if Comparison.AchievementContainer and Comparison.AchievementContainer.ScrollBar then
            S:HandleScrollBar(Comparison.AchievementContainer.ScrollBar)
        end
        if Comparison.StatContainer and Comparison.StatContainer.ScrollBar then
            S:HandleScrollBar(Comparison.StatContainer.ScrollBar)
        end
        if _G.AchievementFrameComparisonHeader then
             S:StripTextures(_G.AchievementFrameComparisonHeader)
             S:CreateBackdrop(_G.AchievementFrameComparisonHeader)
             _G.AchievementFrameComparisonHeader.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
             _G.AchievementFrameComparisonHeader.backdrop:SetPoint("TOPLEFT", 20, -20)
             _G.AchievementFrameComparisonHeader.backdrop:SetPoint("BOTTOMRIGHT", -28, -5)
        end
    end

    -- [FIX] Criteria Text Color (Black text issue)
    hooksecurefunc("AchievementObjectives_DisplayCriteria", function(objectivesFrame, id)
        if not objectivesFrame or not objectivesFrame.GetCriteria then return end
        local numCriteria = GetAchievementNumCriteria(id)
        local textStrings = 0
        
        for i = 1, numCriteria do
            local _, criteriaType, completed, _, _, _, flags, assetID = GetAchievementCriteriaInfo(id, i)
            
            if criteriaType == _G.CRITERIA_TYPE_ACHIEVEMENT and assetID then
                -- Meta achievement
            elseif bit.band(flags, _G.EVALUATION_TREE_FLAG_PROGRESS_BAR) == _G.EVALUATION_TREE_FLAG_PROGRESS_BAR then
                -- Progress bar
            else
                -- Text criteria
                textStrings = textStrings + 1
                local criteria = objectivesFrame:GetCriteria(textStrings)
                if criteria and criteria.Name then
                    S:HandleFont(criteria.Name)
                    if completed then
                        criteria.Name:SetTextColor(0, 1, 0) -- Green
                    else
                        criteria.Name:SetTextColor(0.6, 0.6, 0.6) -- Grey
                    end
                end
            end
        end
    end)
end
