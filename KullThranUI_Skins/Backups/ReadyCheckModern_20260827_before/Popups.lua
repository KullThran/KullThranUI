local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
local S = KT and KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local math_max = math.max
local select = select
local unpack = unpack or table.unpack
local issecretvalue = _G.issecretvalue
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned

local BLANK_TEX = "Interface\\Buttons\\WHITE8x8"
local FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local RefreshSurface

local function GetAccent(alpha)
    local color = S:GetAccentColor()
    return color[1], color[2], color[3], alpha or color[4] or 1
end

local function AlphaStripTextures(frame, deep, preserveNativeArt)
    if not frame then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    if frame.GetRegions then
        for i = 1, select("#", frame:GetRegions()) do
            local region = select(i, frame:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("Texture") and region.SetAlpha and not region._ktKuiPopupArt then
                local owner = region.GetParent and region:GetParent()
                local ownerName = owner and owner.GetName and owner:GetName() or ""
                local isItemIcon = owner and (owner.Icon == region or owner.icon == region or owner.ItemIcon == region)
                if isItemIcon or ownerName:find("Item", 1, true) or ownerName:find("Catalyst", 1, true) then
                    region:SetAlpha(1)
                    region:SetDrawLayer("ARTWORK", 2)
                else
                    region:SetAlpha(0)
                end
            end
        end
    end

    local named = { "NineSlice", "Border", "BorderFrame", "Background", "TopBorder", "BottomBorder", "LeftBorder", "RightBorder" }
    for _, key in ipairs(named) do
        local obj = frame[key]
        if obj and not obj._ktKuiPopupArt then
            if preserveNativeArt then
                AlphaStripTextures(obj, true, true)
            else
                if obj.SetAlpha then obj:SetAlpha(0) end
                AlphaStripTextures(obj, true, false)
            end
        end
    end

    if deep and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            AlphaStripTextures(child, true, preserveNativeArt)
        end
    end
end

local function IsQueueReadyDialog(frame)
    return frame == _G.LFGDungeonReadyPopup
        or frame == _G.PVPReadyDialog
        or frame == _G.LFGDungeonReadyDialog
end

local function PreserveQueueReadyArtwork(frame, depth)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    if frame.GetRegions then
        for i = 1, select('#', frame:GetRegions()) do
            local region = select(i, frame:GetRegions())
            if region and region.IsObjectType and region:IsObjectType('Texture')
                and region ~= frame._ktPopupBg then
                local width, height = region:GetSize()
                local hasArtwork = (region.GetTexture and region:GetTexture())
                    or (region.GetAtlas and region:GetAtlas())
                local nativeVisible = not region.IsShown or region:IsShown()
                -- Ready-dialog artwork is assembled from several adjacent pieces;
                -- retain every visible panel, but not thin NineSlice borders.
                if hasArtwork and nativeVisible and (width or 0) >= 44 and (height or 0) >= 44 then
                    region._ktKuiPopupArt = true
                    region:SetDesaturated(false)
                    region:SetVertexColor(0.68, 0.68, 0.70, 1)
                    region:SetAlpha(1)
                end
            end
        end
    end
    if (depth or 0) <= 0 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        PreserveQueueReadyArtwork(child, depth - 1)
    end
end

local function RefreshQueueReadyArtwork(frame)
    if not IsQueueReadyDialog(frame) then return end
    PreserveQueueReadyArtwork(frame, 4)
    RefreshSurface(frame)
end

local function StyleText(frame)
    if not (frame and frame.GetRegions) then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    for i = 1, select("#", frame:GetRegions()) do
        local region = select(i, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            local _, size = region:GetFont()
            size = (size and size > 0) and size or 12
            region:SetDrawLayer("OVERLAY", 7)
            region:SetFont(KT.FONT_PATH or FONT, size, "OUTLINE")
            region:SetTextColor(0.94, 0.94, 0.96, 1)
        end
    end
end

local function EnsureSurface(frame, opts)
    if not frame then return end
    opts = opts or {}

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = BLANK_TEX,
            edgeFile = BLANK_TEX,
            edgeSize = S.mult or 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
    end
    if not frame._ktPopupBg then
        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", opts.insetLeft or 0, opts.insetTop or 0)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", opts.insetRight or 0, opts.insetBottom or 0)
        bg:SetTexture(BLANK_TEX)
        bg._ktKuiPopupArt = true
        frame._ktPopupBg = bg
    end

    if not frame._ktPopupBorder then
        local border = {}
        border.top = frame:CreateTexture(nil, "BORDER", nil, 7); border.top._ktKuiPopupArt = true
        border.bottom = frame:CreateTexture(nil, "BORDER", nil, 7); border.bottom._ktKuiPopupArt = true
        border.left = frame:CreateTexture(nil, "BORDER", nil, 7); border.left._ktKuiPopupArt = true
        border.right = frame:CreateTexture(nil, "BORDER", nil, 7); border.right._ktKuiPopupArt = true
        frame._ktPopupBorder = border
    end

    frame._ktPopupInsets = opts
    RefreshSurface(frame)
    if not frame._ktWindowBackgroundRegistered then
        S:RegisterBlizzardWindowBackground(frame, function(surface)
            RefreshSurface(surface)
        end)
        frame._ktWindowBackgroundRegistered = true
    end
    return frame._ktPopupBg
end

RefreshSurface = function(frame)
    if not frame then return end
    local bg = frame._ktPopupBg
    local border = frame._ktPopupBorder
    if not (bg and border) then return end

    local opts = frame._ktPopupInsets or {}
    local left = opts.insetLeft or 0
    local top = opts.insetTop or 0
    local right = opts.insetRight or 0
    local bottom = opts.insetBottom or 0
    local ar, ag, ab = GetAccent()
    local mult = math_max(2, (S.mult or 1) * 2)

    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom)
    local windowColor = S:GetWindowBackgroundColor(false)
    local backgroundAlpha = math.min(windowColor[4] or 0.98, opts.alpha or 1)
    local bgR, bgG, bgB = windowColor[1], windowColor[2], windowColor[3]
    if opts.artworkShade then
        bgR, bgG, bgB = 0, 0, 0
    end
    -- Queue-ready artwork does not always cover the complete dialog. Keep an
    -- opaque neutral surface behind it so uncovered areas never show the
    -- 3D world or inherit the user's translucent window setting.
    if opts.solidBackground then
        backgroundAlpha = 1
    end
    bg:SetColorTexture(bgR, bgG, bgB, backgroundAlpha)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(bgR, bgG, bgB, backgroundAlpha)
    end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(ar, ag, ab, opts.borderAlpha or 0.90) end

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
        tex:SetTexture(BLANK_TEX)
        tex:SetColorTexture(ar, ag, ab, opts.borderAlpha or 0.90)
    end
end
local function GetButtonRole(button, fallback)
    local text = button and button.GetText and button:GetText()
    text = text and text:lower() or ""
    if text:find("accept", 1, true) or text:find("reload", 1, true) or text:find("release", 1, true)
        or text:find("resurrect", 1, true) or text:find("yes", 1, true) or text:find("okay", 1, true)
        or text:find("ok", 1, true) then
        return "accept"
    end
    if text:find("decline", 1, true) or text:find("cancel", 1, true) or text:find("no", 1, true)
        or text:find("delete", 1, true) or text:find("abandon", 1, true) then
        return "decline"
    end
    return fallback or "neutral"
end

local function GetButtonColors(role, hover)
    local ar, ag, ab = GetAccent()
    local bgR, bgG, bgB = hover and 0.115 or 0.075, hover and 0.120 or 0.080, hover and 0.140 or 0.095
    local borderR, borderG, borderB = ar, ag, ab
    local textR, textG, textB = 1, 1, 1

    if role == "accept" then
        bgR, bgG, bgB = hover and 0.120 or 0.080, hover and 0.130 or 0.090, hover and 0.145 or 0.105
    elseif role == "decline" then
        bgR, bgG, bgB = hover and 0.125 or 0.085, hover and 0.090 or 0.065, hover and 0.095 or 0.070
    end

    return bgR, bgG, bgB, borderR, borderG, borderB, textR, textG, textB
end
local function EnsureButtonArt(button)
    if not button or button._ktPopupButtonBg then return end

    local bg = button:CreateTexture(nil, "ARTWORK", nil, -2)
    bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    bg:SetTexture(BLANK_TEX)
    bg._ktKuiPopupArt = true
    button._ktPopupButtonBg = bg

    local border = {}
    border.top = button:CreateTexture(nil, "OVERLAY", nil, 2); border.top._ktKuiPopupArt = true
    border.bottom = button:CreateTexture(nil, "OVERLAY", nil, 2); border.bottom._ktKuiPopupArt = true
    border.left = button:CreateTexture(nil, "OVERLAY", nil, 2); border.left._ktKuiPopupArt = true
    border.right = button:CreateTexture(nil, "OVERLAY", nil, 2); border.right._ktKuiPopupArt = true
    button._ktPopupButtonBorder = border
end

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

local function StyleReadyCheckConsumables(frame)
    frame = frame or _G.NSIReadyCheckConsumables
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end

    local r, g, b = GetAccent(1)
    if frame.SetBackdropBorderColor then
        pcall(frame.SetBackdropBorderColor, frame, r, g, b, 1)
    end

    local closeButton = frame.closeButton
    if closeButton and closeButton.SetBackdropBorderColor then
        pcall(closeButton.SetBackdropBorderColor, closeButton, r, g, b, 1)
    end

    if not frame._ktReadyCheckConsumablesOnShowHooked and frame.HookScript then
        frame:HookScript('OnShow', function(self)
            StyleReadyCheckConsumables(self)
        end)
        frame._ktReadyCheckConsumablesOnShowHooked = true
    end
end

local function StyleReadyCheckFrame(frame)
    StyleReadyCheckConsumables()
    if not (S.db and S.db.enable and S.db.popups) then return end
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end

    local showPrompt = ShouldShowReadyCheckPrompt(frame)
    EnsureReadyCheckSurface(frame, showPrompt)
    EnsureReadyCheckAccentBorder(frame, showPrompt)
    if not showPrompt then return end

    local closeButton = _G.ReadyCheckFrameCloseButton or frame.CloseButton
    if closeButton and not (closeButton.IsForbidden and closeButton:IsForbidden()) then
        pcall(closeButton.ClearAllPoints, closeButton)
        pcall(closeButton.SetPoint, closeButton, "BOTTOM", frame, "BOTTOM", 0, 8)
        local width = frame.GetWidth and frame:GetWidth() or 208
        pcall(closeButton.SetSize, closeButton, math.max(120, math.min(208, width - 24)), 22)
        StyleButton(closeButton, "neutral")
    end

    local function StyleChildText(child, depth)
        if not child or (depth or 0) > 5 then return end
        StyleText(child)
        if child.GetChildren then
            for _, grandChild in ipairs({ child:GetChildren() }) do
                StyleChildText(grandChild, (depth or 0) + 1)
            end
        end
    end
    StyleChildText(frame, 0)
end

local function LayoutReadyCheckFrame(frame)
    if not frame then return end
    StyleReadyCheckFrame(frame)
end
local STATIC_POPUPS = {
    "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
}

local NAMED_DIALOGS = {
    "RolePollPopup",
    "LFDRoleCheckPopup",
    "LFGInvitePopup",
    "LFGDungeonReadyPopup",
    "PVPReadyDialog",
    "DeathReleaseDialog",
    "ResurrectDialog",
    "RecruitAFriendFrameInvitePopup",
}

local function ReskinStaticPopup(frame)
    if not frame then return end
    SkinStaticPopup(frame)
    C_Timer.After(0, function() SkinStaticPopup(frame) end)
    C_Timer.After(0.03, function() SkinStaticPopup(frame) end)
    C_Timer.After(0.10, function() SkinStaticPopup(frame) end)
end

local function SkinAllStaticPopups()
    for _, name in ipairs(STATIC_POPUPS) do
        local frame = _G[name]
        if frame then
            ReskinStaticPopup(frame)
            if not frame._ktStaticPopupOnShowHooked then
                frame:HookScript("OnShow", ReskinStaticPopup)
                frame._ktStaticPopupOnShowHooked = true
            end
        end
    end
end
local function SkinAllNamedDialogs()
    for _, name in ipairs(NAMED_DIALOGS) do
        local frame = _G[name]
        if frame then
            SkinNamedDialog(frame)
            if not frame._ktPopupOnShowHooked then
                frame:HookScript("OnShow", SkinNamedDialog)
                frame._ktPopupOnShowHooked = true
            end
        end
    end
end

local function SkinPopups()
    if not (S.db and S.db.enable and S.db.popups) then return end

    SkinAllStaticPopups()
    SkinAllNamedDialogs()
    RestoreAllLFGProposalRoleIcons()

    for _, frame in ipairs({ _G.LFGDungeonReadyDialog, _G.LFGDungeonReadyPopup }) do
        if frame and not frame._ktLFGRoleIconOnShowHooked then
            frame:HookScript("OnShow", function(self)
                RestoreLFGProposalRoleIcon(self)
                C_Timer.After(0, function() RestoreLFGProposalRoleIcon(self) end)
                C_Timer.After(0.05, function() RestoreLFGProposalRoleIcon(self) end)
                C_Timer.After(0.20, function() RestoreLFGProposalRoleIcon(self) end)
            end)
            frame._ktLFGRoleIconOnShowHooked = true
        end
    end

    local readyCheckFrame = _G.ReadyCheckFrame
    StyleReadyCheckFrame(readyCheckFrame)
    if readyCheckFrame and not readyCheckFrame._ktReadyCheckOnShowHooked then
        readyCheckFrame:HookScript("OnShow", function()
            C_Timer.After(0, function() StyleReadyCheckFrame(readyCheckFrame) end)
            C_Timer.After(0.05, function() StyleReadyCheckFrame(readyCheckFrame) end)
            C_Timer.After(0.20, function() StyleReadyCheckFrame(readyCheckFrame) end)
        end)
        readyCheckFrame._ktReadyCheckOnShowHooked = true
    end

    if not S._ktStaticPopupHooked then
        hooksecurefunc("StaticPopup_Show", function()
            C_Timer.After(0, SkinAllStaticPopups)
            C_Timer.After(0.03, SkinAllStaticPopups)
            C_Timer.After(0.10, SkinAllStaticPopups)
        end)
        if _G.StaticPopupSpecial_Show then
            hooksecurefunc("StaticPopupSpecial_Show", function(frame)
                C_Timer.After(0, function()
                    if frame then SkinNamedDialog(frame) end
                end)
            end)
        end
        S._ktStaticPopupHooked = true
    end

    if not S._ktPopupEventFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:RegisterEvent("GROUP_ROSTER_UPDATE")
        f:RegisterEvent("LFG_ROLE_CHECK_SHOW")
        f:RegisterEvent("LFG_PROPOSAL_SHOW")
        f:RegisterEvent("LFG_PROPOSAL_UPDATE")
        f:RegisterEvent("READY_CHECK")
        f:SetScript("OnEvent", function(_, event)
            if event == "READY_CHECK" then
                C_Timer.After(0, function() StyleReadyCheckFrame(_G.ReadyCheckFrame) end)
                C_Timer.After(0.05, function() StyleReadyCheckFrame(_G.ReadyCheckFrame) end)
                C_Timer.After(0.20, function() StyleReadyCheckFrame(_G.ReadyCheckFrame) end)
            elseif event == "LFG_PROPOSAL_SHOW" or event == "LFG_PROPOSAL_UPDATE" then
                C_Timer.After(0, function()
                    SkinAllNamedDialogs()
                    RestoreAllLFGProposalRoleIcons()
                end)
                C_Timer.After(0.05, RestoreAllLFGProposalRoleIcons)
                C_Timer.After(0.20, RestoreAllLFGProposalRoleIcons)
            else
                C_Timer.After(0, function()
                    SkinAllNamedDialogs()
                    RestoreAllLFGProposalRoleIcons()
                end)
            end
        end)
        S._ktPopupEventFrame = f
    end
end

S:AddCallback("Popups", SkinPopups)
