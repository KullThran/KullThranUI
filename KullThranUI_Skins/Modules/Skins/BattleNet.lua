local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G

S.SkinFuncs["BattleNet"] = function()
    if not (S.db.enable and S.db.battlenet) then return end

    -- 1. NOTIFICACIONES (TOASTS)
    -- In WoW 11.0 (Midnight), skinning AlertFrames like BNToastFrame and TimeAlertFrame
    -- taints the UIParent layout path, which eventually taints ActionButton_UpdatePressAndHoldAction
    -- causing ADDON_ACTION_BLOCKED on MultiBars. Do not skin them.

    -- 2. VENTANA DE REPORTAR JUGADOR
    if _G.ReportFrame then
        local ReportFrame = _G.ReportFrame
        S:StripTextures(ReportFrame)
        S:CreateBackdrop(ReportFrame)
        S:HandleCloseButton(ReportFrame.CloseButton)
        
        if ReportFrame.ReportingMajorCategoryDropdown then
            S:HandleDropDownBox(ReportFrame.ReportingMajorCategoryDropdown)
        end
        
        if ReportFrame.ReportButton then
            S:HandleButton(ReportFrame.ReportButton)
        end
        
        if ReportFrame.Comment then
            S:HandleEditBox(ReportFrame.Comment)
        end
        
        -- Textos
        S:HandleFont(ReportFrame.Title)
    end

    -- 3. REPORTAR TRAMPAS (Dialog)
    if _G.ReportCheatingDialog then
        local Cheat = _G.ReportCheatingDialog
        S:StripTextures(Cheat)
        S:CreateBackdrop(Cheat)
        
        if _G.ReportCheatingDialogCommentFrame then
            S:StripTextures(_G.ReportCheatingDialogCommentFrame)
            if _G.ReportCheatingDialogCommentFrameEditBox then
                S:HandleEditBox(_G.ReportCheatingDialogCommentFrameEditBox)
            end
        end
        
        S:HandleButton(_G.ReportCheatingDialogReportButton)
        S:HandleButton(_G.ReportCheatingDialogCancelButton)
    end

    -- 4. INVITACIÓN DE BATTLETAG
    if _G.BattleTagInviteFrame then
        local Invite = _G.BattleTagInviteFrame
        S:StripTextures(Invite)
        S:CreateBackdrop(Invite)
        
        for _, child in pairs({Invite:GetChildren()}) do
            if child:IsObjectType('Button') then
                S:HandleButton(child)
            end
            if child:IsObjectType('FontString') then
                S:HandleFont(child)
            end
        end
    end
end