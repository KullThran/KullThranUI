local function RefreshButtonArt(button, hover)

    local bg = button and button._ktPopupButtonBg

    local border = button and button._ktPopupButtonBorder

    if not (bg and border) then return end



    local role = button._ktPopupRole or GetButtonRole(button)

    local bgR, bgG, bgB, borderR, borderG, borderB, textR, textG, textB = GetButtonColors(role, hover)
    local enabled = not button.IsEnabled or button:IsEnabled()
    if not enabled then
        -- Blizzard disables Release Spirit while the encounter still owns the
        -- player corpse. Keep the KUI skin visibly disabled as well.
        bgR, bgG, bgB = 0.035, 0.038, 0.045
        borderR, borderG, borderB = 0.28, 0.29, 0.32
        textR, textG, textB = 0.48, 0.49, 0.53
    end

    local mult = math_max(2, (S.mult or 1) * 2)



    bg:SetAlpha(1)

    bg:SetDrawLayer("ARTWORK", -2)

    bg:SetColorTexture(bgR, bgG, bgB, enabled and 0.98 or 0.82)



    border.top:ClearAllPoints()

    border.top:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)

    border.top:SetPoint("TOPRIGHT", bg, "TOPRIGHT", 0, 0)

    border.top:SetHeight(mult)



    border.bottom:ClearAllPoints()

    border.bottom:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 0, 0)

    border.bottom:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 0)

    border.bottom:SetHeight(mult)



    border.left:ClearAllPoints()

    border.left:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, 0)

    border.left:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 0, 0)

    border.left:SetWidth(mult)



    border.right:ClearAllPoints()

    border.right:SetPoint("TOPRIGHT", bg, "TOPRIGHT", 0, 0)

    border.right:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, 0)

    border.right:SetWidth(mult)



    for _, tex in pairs(border) do

        tex:SetAlpha(1)

        tex:SetDrawLayer("OVERLAY", 7)

        tex:SetTexture(BLANK_TEX)

        tex:SetColorTexture(borderR, borderG, borderB, hover and 1 or 0.95)

    end



    local fs = button.GetFontString and button:GetFontString()

    if fs then fs:SetTextColor(textR, textG, textB, enabled and 1 or 0.72) end

end



local function StyleButton(button, role)

    if not button then return end

    if button.IsForbidden and button:IsForbidden() then return end



    button._ktPopupRole = role or GetButtonRole(button)

    AlphaStripTextures(button)

    EnsureButtonArt(button)



    if button.SetNormalTexture then button:SetNormalTexture(BLANK_TEX) end

    if button.SetPushedTexture then button:SetPushedTexture(BLANK_TEX) end

    if button.SetDisabledTexture then button:SetDisabledTexture(BLANK_TEX) end

    if button.SetHighlightTexture then button:SetHighlightTexture(BLANK_TEX) end

    if button.GetNormalTexture and button:GetNormalTexture() then button:GetNormalTexture():SetVertexColor(0.075, 0.080, 0.095, 0.98) end

    if button.GetPushedTexture and button:GetPushedTexture() then button:GetPushedTexture():SetVertexColor(0.055, 0.060, 0.070, 1) end

    if button.GetDisabledTexture and button:GetDisabledTexture() then button:GetDisabledTexture():SetVertexColor(0.040, 0.040, 0.045, 0.70) end

    if button.GetHighlightTexture and button:GetHighlightTexture() then local ar, ag, ab = GetAccent(); button:GetHighlightTexture():SetVertexColor(ar, ag, ab, 0.22) end



    local fs = button.GetFontString and button:GetFontString()

    if fs then

        fs:SetDrawLayer("OVERLAY", 7)

        fs:SetFont(KT.FONT_PATH or FONT, 12, "OUTLINE")

    end



    RefreshButtonArt(button, false)



    if not button._ktPopupEnabledHooks then
        if button.Enable then
            hooksecurefunc(button, "Enable", function()
                RefreshButtonArt(button, false)
            end)
        end
        if button.Disable then
            hooksecurefunc(button, "Disable", function()
                RefreshButtonArt(button, false)
            end)
        end
        if button.SetEnabled then
            hooksecurefunc(button, "SetEnabled", function()
                RefreshButtonArt(button, false)
            end)
        end
        -- StaticPopup can receive its final enabled state a frame after OnShow.
        -- Recheck while visible so the death button never relies on mouse-over
        -- to repaint after a boss encounter changes the release restriction.
        button:HookScript("OnUpdate", function(self)
            local enabled = not self.IsEnabled or self:IsEnabled()
            if enabled ~= self._ktPopupLastEnabled then
                self._ktPopupLastEnabled = enabled
                RefreshButtonArt(self, false)
            end
        end)
        button._ktPopupLastEnabled = nil
        button._ktPopupEnabledHooks = true
    end

    if not button._ktPopupSkinned then

        button:HookScript("OnEnter", function(self) RefreshButtonArt(self, true) end)

        button:HookScript("OnLeave", function(self) RefreshButtonArt(self, false) end)

        button._ktPopupSkinned = true

    end

end
