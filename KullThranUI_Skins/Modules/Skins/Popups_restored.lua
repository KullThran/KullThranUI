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
local function StylePopupButtons(root)
    local seen = {}
    local function GetButtonText(button)
        local text = button and button.GetText and button:GetText()
        if type(text) == "string" and text ~= "" then
            return text
        end

        local fs = button and button.GetFontString and button:GetFontString()
        text = fs and fs.GetText and fs:GetText()
        if type(text) == "string" and text ~= "" then
            return text
        end

        local namedText = button and button.Text
        text = namedText and namedText.GetText and namedText:GetText()
        if type(text) == "string" and text ~= "" then
            return text
        end
    end

    local function visit(frame)
        if not frame or seen[frame] then return end
        if frame.IsForbidden and frame:IsForbidden() then return end
        seen[frame] = true

        if frame.IsObjectType and frame:IsObjectType("Button") then
            if GetButtonText(frame) then
                StyleButton(frame, GetButtonRole(frame))
            end
        end

        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                visit(child)
            end
        end
    end

    for i = 1, 4 do
        local button = root and root["button" .. i]
        if button then StyleButton(button, GetButtonRole(button, i == 1 and "accept" or "decline")) end
    end
    visit(root)
end

local function IsReadableCheckedValue(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function IsPopupRoleChecked(button)
    if not button then return false end
    local check = button.checkButton or button.CheckButton or button

    for _, candidate in ipairs({ check, button }) do
        if candidate and candidate.GetChecked then
            local ok, checked = pcall(candidate.GetChecked, candidate)
            if ok and IsReadableCheckedValue(checked) and checked == true then
                return true
            end
        end
    end

    for _, candidate in ipairs({ check, button }) do
        if candidate then
            for _, key in ipairs({ 'checked', 'isChecked', 'selected', 'isSelected', 'active' }) do
                local value = candidate[key]
                if IsReadableCheckedValue(value) and value == true then
                    return true
                end
            end
        end
    end

    for _, texture in ipairs({
        button.SelectedTexture,
        button.selectedTexture,
        button.CheckedTexture,
        button.Check,
        check and check.GetCheckedTexture and check:GetCheckedTexture(),
    }) do
        if texture and texture.IsShown then
            local ok, shown = pcall(texture.IsShown, texture)
            if ok and IsReadableCheckedValue(shown) and shown == true then
                return true
            end
        end
    end

    return false
end

local function IsPopupRoleButton(button)
    if not (button and button.IsObjectType and button:IsObjectType('Button')) then
        return false
    end

    local name = button.GetName and button:GetName() or ''
    local parent = button.GetParent and button:GetParent()
    local parentName = parent and parent.GetName and parent:GetName() or ''
    local token = (tostring(name) .. ' ' .. tostring(parentName)):lower()
    local hasRole = token:find('rolebutton', 1, true) or token:find('role button', 1, true)
    local hasType = token:find('tank', 1, true)
        or token:find('heal', 1, true)
        or token:find('damage', 1, true)
        or token:find('dps', 1, true)

    return hasRole and hasType and true or false
end

local RefreshPopupRoleFeedback

local function EnsurePopupRoleFeedback(button, dialog)
    if not (button and dialog) then return end

    if not button._ktRoleSelectedGlow then
        local glow = button:CreateTexture(nil, 'OVERLAY', nil, 7)
        glow:SetTexture('Interface\\Buttons\\UI-ActionButton-Border')
        glow:SetBlendMode('ADD')
        glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -10, 10)
        glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 10, -10)
        glow._ktKuiPopupArt = true
        button._ktRoleSelectedGlow = glow

        local tint = button:CreateTexture(nil, 'OVERLAY', nil, 6)
        tint:SetTexture(BLANK_TEX)
        tint:SetAllPoints(button)
        tint:SetBlendMode('ADD')
        tint._ktKuiPopupArt = true
        button._ktRoleSelectedTint = tint
    end

    local function Refresh()
        local selected = IsPopupRoleChecked(button)
        local ar, ag, ab = GetAccent()
        button._ktRoleSelectedGlow:SetVertexColor(ar, ag, ab, 1)
        button._ktRoleSelectedTint:SetVertexColor(ar, ag, ab, 0.18)
        button._ktRoleSelectedGlow:SetShown(selected)
        button._ktRoleSelectedTint:SetShown(selected)
    end

    button._ktRefreshPopupRoleFeedback = Refresh

    if not button._ktPopupRoleFeedbackHooked then
        button._ktPopupRoleFeedbackHooked = true
        local check = button.checkButton or button.CheckButton or button
        if check and check.SetChecked then
            hooksecurefunc(check, 'SetChecked', function()
                C_Timer.After(0, function() RefreshPopupRoleFeedback(dialog) end)
            end)
        end
        if check and check.HookScript then
            check:HookScript('OnClick', function()
                C_Timer.After(0, function() RefreshPopupRoleFeedback(dialog) end)
            end)
        end
        button:HookScript('OnClick', function()
            C_Timer.After(0, function() RefreshPopupRoleFeedback(dialog) end)
        end)
        button:HookScript('OnShow', function()
            C_Timer.After(0, function() RefreshPopupRoleFeedback(dialog) end)
        end)
    end

    Refresh()
end

RefreshPopupRoleFeedback = function(dialog)
    if not (dialog and dialog.GetChildren) then return end
    local seen = {}
    local explicitButtons = {
        _G.LFDRoleCheckPopupRoleButtonTank,
        _G.LFDRoleCheckPopupRoleButtonHealer,
        _G.LFDRoleCheckPopupRoleButtonDPS,
        _G.RolePollPopupRoleButtonTank,
        _G.RolePollPopupRoleButtonHealer,
        _G.RolePollPopupRoleButtonDPS,
        dialog.RoleButtonTank,
        dialog.RoleButtonHealer,
        dialog.RoleButtonDPS,
        dialog.TankButton,
        dialog.HealerButton,
        dialog.DPSButton,
        dialog.DamagerButton,
    }

    if dialog.RoleButtons then
        EnsurePopupRoleFeedback(dialog.RoleButtons.Tank, dialog)
        EnsurePopupRoleFeedback(dialog.RoleButtons.Healer, dialog)
        EnsurePopupRoleFeedback(dialog.RoleButtons.DPS, dialog)
        EnsurePopupRoleFeedback(dialog.RoleButtons.Damager, dialog)
    end

    -- The globals vary by client and may leave holes in this list.
    for _, button in pairs(explicitButtons) do
        if button then
            EnsurePopupRoleFeedback(button, dialog)
            seen[button] = true
        end
    end

    local function Visit(frame, depth)
        if not frame or seen[frame] or depth > 6 then return end
        seen[frame] = true
        if IsPopupRoleButton(frame) then
            EnsurePopupRoleFeedback(frame, dialog)
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                Visit(child, depth + 1)
            end
        end
    end

    Visit(dialog, 0)
end

local LFG_PROPOSAL_ROLE_ICONS = {
    TANK = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\Tank.png",
    HEALER = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\Healer.png",
    DAMAGER = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\DPS.png",
}

local cachedLFGProposalRole

local function IsReadableLFGRole(role)
    return type(role) == "string"
        and not (issecretvalue and issecretvalue(role))
        and LFG_PROPOSAL_ROLE_ICONS[role] ~= nil
end

local function GetCurrentLFGProposalRole()
    if not GetLFGProposal then return nil end

    local ok, proposalExists, proposalID, typeID, subtypeID, name, texture, role = pcall(GetLFGProposal)
    if not ok or not proposalExists or type(role) ~= "string" then return nil end
    if issecretvalue and issecretvalue(role) then return nil end
    if role == "NONE" then role = "DAMAGER" end
    return IsReadableLFGRole(role) and role or nil
end

local function GetRoleFromReadyFrame(frame)
    if not frame then return nil end

    for _, key in ipairs({ "role", "Role", "assignedRole", "AssignedRole" }) do
        local value = frame[key]
        if IsReadableLFGRole(value) then
            return value
        end
    end

    if UnitGroupRolesAssigned then
        local ok, value = pcall(UnitGroupRolesAssigned, "player")
        if ok and IsReadableLFGRole(value) then
            return value
        end
    end

    return nil
end

local function FindReadyRoleIconObject(root, depth, seen)
    if not root or (root.IsForbidden and root:IsForbidden()) then return nil end
    seen = seen or {}
    if seen[root] then return nil end
    seen[root] = true

    for _, key in ipairs({ "RoleIcon", "roleIcon", "AssignedRoleIcon", "RoleIconFrame", "RoleIconTexture" }) do
        local object = root[key]
        if object then
            return object
        end
    end

    local name = root.GetName and root:GetName()
    if type(name) == "string" and name:lower():find("roleicon", 1, true) then
        return root
    end

    if (depth or 0) >= 4 or not root.GetChildren then return nil end
    for _, child in ipairs({ root:GetChildren() }) do
        local object = FindReadyRoleIconObject(child, (depth or 0) + 1, seen)
        if object then
            return object
        end
    end

    return nil
end

local function GetReadyRoleIconObject(frame)
    if not frame then return nil end

    local object = FindReadyRoleIconObject(frame, 0)
    if object then return object end

    for _, name in ipairs({
        "LFGDungeonReadyDialogRoleIcon",
        "LFGDungeonReadyDialogRoleIconTexture",
        "LFGDungeonReadyPopupRoleIcon",
        "LFGDungeonReadyPopupRoleIconTexture",
    }) do
        object = _G[name]
        if object then return object end
    end

    return nil
end

local function SetReadyRoleIconObject(object, role)
    if not (object and IsReadableLFGRole(role)) then return false end
    if object.IsForbidden and object:IsForbidden() then return false end

    local texture = object
    if not texture.SetTexture then
        texture = object.Icon or object.Texture or object.texture
    end

    if texture and texture.SetTexture then
        texture._ktKuiPopupArt = true
        texture:SetTexture(LFG_PROPOSAL_ROLE_ICONS[role])
        texture:SetTexCoord(0, 1, 0, 1)
        if texture.SetDrawLayer then texture:SetDrawLayer("ARTWORK", 7) end
        if texture.SetAlpha then texture:SetAlpha(1) end
        if texture.Show then texture:Show() end
        if object.SetAlpha then object:SetAlpha(1) end
        if object.Show then object:Show() end
        return true
    end

    if not object.CreateTexture then return false end
    local icon = object._ktAssignedRoleIcon
    if not icon then
        icon = object:CreateTexture(nil, "ARTWORK", nil, 7)
        local width, height = object.GetSize and object:GetSize()
        width = tonumber(width) or 48
        height = tonumber(height) or width
        width = math.max(24, math.min(width, 64))
        height = math.max(24, math.min(height, 64))
        icon:SetSize(width, height)
        icon:SetPoint("CENTER")
        icon._ktKuiPopupArt = true
        object._ktAssignedRoleIcon = icon
    end
    icon:SetTexture(LFG_PROPOSAL_ROLE_ICONS[role])
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetAlpha(1)
    icon:Show()
    if object.SetAlpha then object:SetAlpha(1) end
    if object.Show then object:Show() end
    return true
end

local function RestoreLFGProposalRoleIcon(frame)
    if not frame then return end

    local role = GetCurrentLFGProposalRole() or GetRoleFromReadyFrame(frame) or cachedLFGProposalRole
    if role then
        cachedLFGProposalRole = role
    end

    local roleObject = GetReadyRoleIconObject(frame)
    if roleObject and role then
        SetReadyRoleIconObject(roleObject, role)
    end
end

local function RestoreAllLFGProposalRoleIcons()
    RestoreLFGProposalRoleIcon(_G.LFGDungeonReadyDialog)
    RestoreLFGProposalRoleIcon(_G.LFGDungeonReadyPopup)
end

local function SkinStaticPopup(frame)
    if not (S.db and S.db.enable and S.db.popups) then return end
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end

    AlphaStripTextures(frame, true)
    EnsureSurface(frame, { insetLeft = 1, insetTop = -1, insetRight = -1, insetBottom = 1 })
    RefreshSurface(frame)
    StyleText(frame)

    if frame.text then
        frame.text:SetDrawLayer("OVERLAY", 7)
        frame.text:SetFont(KT.FONT_PATH or FONT, 13, "OUTLINE")
        frame.text:SetTextColor(0.98, 0.98, 1, 1)
    end
    if frame.SubText then
        frame.SubText:SetDrawLayer("OVERLAY", 7)
        frame.SubText:SetFont(KT.FONT_PATH or FONT, 11, "OUTLINE")
        frame.SubText:SetTextColor(0.72, 0.74, 0.78, 1)
    end

    StylePopupButtons(frame)

    if frame.EditBox then
        S:StripTextures(frame.EditBox)
        S:CreateBackdrop(frame.EditBox)
        if frame.EditBox.backdrop then
            frame.EditBox.backdrop:SetBackdropColor(0.14, 0.145, 0.16, 0.98)
            frame.EditBox.backdrop:SetBackdropBorderColor(GetAccent(0.72))
        end
    end
end

local function NormalizePopupRole(role)
    if role == "DPS" then return "DAMAGER" end
    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
end

local function GetRoleCheckPopupRole(frame)
    if not frame then return nil end

    local buttons = {
        { frame.RoleButtonTank, "TANK" },
        { frame.TankButton, "TANK" },
        { frame.RoleButtonHealer, "HEALER" },
        { frame.HealerButton, "HEALER" },
        { frame.RoleButtonDPS, "DAMAGER" },
        { frame.DPSButton, "DAMAGER" },
        { frame.DamagerButton, "DAMAGER" },
        { _G.RolePollPopupRoleButtonTank, "TANK" },
        { _G.RolePollPopupRoleButtonHealer, "HEALER" },
        { _G.RolePollPopupRoleButtonDPS, "DAMAGER" },
        { _G.LFGInvitePopupRoleButtonTank, "TANK" },
        { _G.LFGInvitePopupRoleButtonHealer, "HEALER" },
        { _G.LFGInvitePopupRoleButtonDPS, "DAMAGER" },
        { _G.LFDRoleCheckPopupRoleButtonTank, "TANK" },
        { _G.LFDRoleCheckPopupRoleButtonHealer, "HEALER" },
        { _G.LFDRoleCheckPopupRoleButtonDPS, "DAMAGER" },
    }

    for _, data in ipairs(buttons) do
        if data[1] and IsPopupRoleChecked(data[1]) then
            return data[2]
        end
    end

    if _G.GetLFGRoles then
        local ok, tank, healer, damager = pcall(_G.GetLFGRoles)
        if ok then
            if tank == true then return "TANK" end
            if healer == true then return "HEALER" end
            if damager == true then return "DAMAGER" end
        end
    end

    if UnitGroupRolesAssigned then
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        if ok then return NormalizePopupRole(role) end
    end
end

local function FindPopupRoleText(frame, depth, seen)
    if not frame or (depth or 0) > 5 then return nil end
    seen = seen or {}
    if seen[frame] then return nil end
    seen[frame] = true

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("FontString") and region.GetText then
                local ok, text = pcall(region.GetText, region)
                text = ok and type(text) == "string" and text:lower() or ""
                if text == "damage" or text == "dps" or text == "healer" or text == "tank"
                    or text:find("damage", 1, true) or text:find("healer", 1, true) then
                    return region
                end
            end
        end
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            local result = FindPopupRoleText(child, (depth or 0) + 1, seen)
            if result then return result end
        end
    end
end

local function RestoreRoleCheckPopupIcon(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end

    local role = GetRoleCheckPopupRole(frame)
    if not role then
        local roleText = FindPopupRoleText(frame, 0)
        local ok, text = roleText and pcall(roleText.GetText, roleText)
        text = ok and type(text) == "string" and text:lower() or ""
        if text:find("damage", 1, true) or text == "dps" then
            role = "DAMAGER"
        elseif text:find("heal", 1, true) then
            role = "HEALER"
        elseif text:find("tank", 1, true) then
            role = "TANK"
        end
    end

    local object = frame.RoleIcon or frame.roleIcon or frame.RoleIconTexture
    local texture = object

    if object and not object.SetTexture then
        texture = object.Icon or object.Texture or object.texture
    end

    if not texture and object and object.CreateTexture then
        texture = object._ktAssignedRoleIcon
        if not texture then
            texture = object:CreateTexture(nil, "ARTWORK", nil, 7)
            texture:SetSize(24, 24)
            texture:SetPoint("CENTER")
            object._ktAssignedRoleIcon = texture
        end
    end

    if not texture then
        texture = frame._ktAssignedRoleIcon
        if not texture then
            texture = frame:CreateTexture(nil, "ARTWORK", nil, 7)
            texture:SetSize(24, 24)
            local roleText = FindPopupRoleText(frame, 0)
            if roleText then
                texture:SetPoint("RIGHT", roleText, "LEFT", -8, 0)
            else
                texture:SetPoint("CENTER", frame, "CENTER", -45, -34)
            end
            frame._ktAssignedRoleIcon = texture
        end
    end

    if role and texture and texture.SetTexture then
        texture:SetTexture(LFG_PROPOSAL_ROLE_ICONS[role])
        texture:SetTexCoord(0, 1, 0, 1)
    end

    if texture then
        texture._ktKuiPopupArt = true
        if texture.SetDrawLayer then texture:SetDrawLayer("ARTWORK", 7) end
        if texture.SetAlpha then texture:SetAlpha(1) end
        if texture.Show then texture:Show() end
    end
    if object and object ~= texture then
        if object.SetAlpha then object:SetAlpha(1) end
        if object.Show then object:Show() end
    end
end
local function SkinNamedDialog(frame)
    if not (S.db and S.db.enable and S.db.popups) then return end
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    local preserveArtwork = IsQueueReadyDialog(frame)
    if preserveArtwork then
        PreserveQueueReadyArtwork(frame, 4)
    end
    AlphaStripTextures(frame, false, preserveArtwork)
    EnsureSurface(frame, {
        insetLeft = 0,
        insetTop = 0,
        insetRight = 0,
        insetBottom = 0,
        alpha = preserveArtwork and 1 or nil,
        artworkShade = preserveArtwork,
        solidBackground = preserveArtwork,
    })
    RefreshSurface(frame)
    if preserveArtwork then
        RefreshQueueReadyArtwork(frame)
        C_Timer.After(0, function() RefreshQueueReadyArtwork(frame) end)
        C_Timer.After(0.05, function() RefreshQueueReadyArtwork(frame) end)
        C_Timer.After(0.20, function() RefreshQueueReadyArtwork(frame) end)
    end
    StyleText(frame)
    StylePopupButtons(frame)
    RestoreRoleCheckPopupIcon(frame)
    RefreshPopupRoleFeedback(frame)
    C_Timer.After(0, function() RefreshPopupRoleFeedback(frame) end)
    C_Timer.After(0, function() RestoreRoleCheckPopupIcon(frame) end)
    C_Timer.After(0.05, function() RestoreRoleCheckPopupIcon(frame) end)
    C_Timer.After(0.20, function() RestoreRoleCheckPopupIcon(frame) end)
    C_Timer.After(0.05, function() RefreshPopupRoleFeedback(frame) end)
    if preserveArtwork then
        RestoreLFGProposalRoleIcon(frame)
        C_Timer.After(0, function() RestoreLFGProposalRoleIcon(frame) end)
        C_Timer.After(0.05, function() RestoreLFGProposalRoleIcon(frame) end)
        C_Timer.After(0.20, function() RestoreLFGProposalRoleIcon(frame) end)
    end

    local function StyleChildText(child)
        if not child then return end
        StyleText(child)
        if child.GetChildren then
            for _, grandChild in ipairs({ child:GetChildren() }) do
                StyleChildText(grandChild)
            end
        end
    end
    StyleChildText(frame)
end

local function EnsureReadyCheckAccentBorder(frame, shown)
    if not frame then return end

    local border = frame._ktReadyCheckAccentBorder
    if shown == false then
        if border then
            for _, edge in ipairs(border) do
                edge:Hide()
            end
        end
        return
    end

    if not border then
        border = {}
        for i = 1, 4 do
            border[i] = frame:CreateTexture(nil, "OVERLAY")
        end
        border[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        border[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        border[1]:SetHeight(2)
        border[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        border[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        border[2]:SetHeight(2)
        border[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        border[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        border[3]:SetWidth(2)
        border[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        border[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        border[4]:SetWidth(2)
        frame._ktReadyCheckAccentBorder = border
    end

    local r, g, b = GetAccent(1)
    for _, edge in ipairs(border) do
        edge:SetColorTexture(r, g, b, 1)
        edge:Show()
    end
end

local function EnsureReadyCheckSurface(frame, shown)
    if not frame then return end

    local background = frame._ktReadyCheckBackground
    if shown == false then
        if background then background:Hide() end
        return
    end

    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(frame)
        background._ktKuiPopupArt = true
        frame._ktReadyCheckBackground = background
    end
    -- ReadyCheckFrame is shared by the incoming and self-started routes. The
    -- self-started route can arrive without Blizzard's normal backdrop, so
    -- keep the complete surface on the same KUI window color instead of
    -- leaving the lower panel as an opaque black rectangle.
    local windowColor = S:GetWindowBackgroundColor(false)
    background:SetColorTexture(
        windowColor[1] or 0.05,
        windowColor[2] or 0.05,
        windowColor[3] or 0.05,
        windowColor[4] or 0.98
    )
    background:Show()

    if frame.SetFrameStrata then
        pcall(frame.SetFrameStrata, frame, "DIALOG")
    end
end

local function ShouldShowReadyCheckPrompt(frame)
    if not frame then return false end

    local initiator = frame.initiator
    if initiator and UnitIsUnit then
        local ok, isPlayer = pcall(UnitIsUnit, "player", initiator)
        if ok and not (issecretvalue and issecretvalue(isPlayer)) then
            return not isPlayer
        end
    end

    local listener = _G.ReadyCheckListenerFrame or frame.ListenerFrame or frame.Listener
    if listener and listener.IsShown then
        return listener:IsShown()
    end

    return false
end

local function GetReadyCheckPortrait(frame)
    return _G.ReadyCheckPortrait
        or _G.ReadyCheckFramePortrait
        or (frame and (frame.portrait or frame.Portrait))
end

local function GetReadyCheckPrimaryText(frame)
    return _G.ReadyCheckFrameText
        or (frame and (frame.Text or frame.text or frame.Message or frame.message))
end

local function EnsureReadyCheckPortrait(frame)
    local portrait = GetReadyCheckPortrait(frame)
    if not (frame and portrait) then return end

    local blizzardFrames = KT:GetModule("BlizzardFrames", true)
    if blizzardFrames and blizzardFrames.RefreshReadyCheckPortrait then
        blizzardFrames:RefreshReadyCheckPortrait(frame.initiator or frame.unit or frame.displayedUnit)
    end

    pcall(portrait.ClearAllPoints, portrait)
    pcall(portrait.SetPoint, portrait, "TOPLEFT", frame, "TOPLEFT", 16, -18)
    pcall(portrait.SetSize, portrait, 44, 44)
    if portrait.SetDrawLayer then
        pcall(portrait.SetDrawLayer, portrait, "ARTWORK", 7)
    end
    if portrait.SetTexCoord then
        pcall(portrait.SetTexCoord, portrait, 0.1, 0.9, 0.1, 0.9)
    end
    if portrait.SetAlpha then portrait:SetAlpha(1) end
    if portrait.Show then portrait:Show() end
    portrait._ktKuiPopupArt = true

    local background = frame._ktReadyCheckPortraitBackground
    if not background then
        background = frame:CreateTexture(nil, "ARTWORK", nil, 5)
        background:SetTexture(BLANK_TEX)
        background._ktKuiPopupArt = true
        frame._ktReadyCheckPortraitBackground = background
    end
    background:ClearAllPoints()
    background:SetPoint("TOPLEFT", portrait, "TOPLEFT", -2, 2)
    background:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", 2, -2)
    background:SetColorTexture(0.025, 0.028, 0.035, 1)
    background:Show()

    local border = frame._ktReadyCheckPortraitBorder
    if not border then
        border = {}
        for index = 1, 4 do
            border[index] = frame:CreateTexture(nil, "OVERLAY", nil, 7)
            border[index]:SetTexture(BLANK_TEX)
            border[index]._ktKuiPopupArt = true