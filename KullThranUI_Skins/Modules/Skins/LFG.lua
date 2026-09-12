local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local next, select = next, select
local unpack, ipairs, pairs = unpack, ipairs, pairs
local hooksecurefunc = hooksecurefunc
local math_floor = math.floor
local string_format = string.format
local CreateFrame = CreateFrame
local C_Spell = C_Spell
local issecretvalue = _G.issecretvalue
local IsSpellKnown = IsSpellKnown
local UnitFactionGroup = UnitFactionGroup
local InCombatLockdown = InCombatLockdown

local UnitIsGroupLeader = UnitIsGroupLeader
local GetItemInfo = C_Item.GetItemInfo

local C_ChallengeMode_GetAffixInfo = C_ChallengeMode.GetAffixInfo
local C_ChallengeMode_GetMapUIInfo = C_ChallengeMode.GetMapUIInfo
local C_ChallengeMode_GetSlottedKeystoneInfo = C_ChallengeMode.GetSlottedKeystoneInfo

local AVANT_GARDE_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local COLOR_BG = {0.11, 0.11, 0.11, 1}

local function IsSecureLFGSafeMode()
    local _, _, _, interfaceVersion = _G.GetBuildInfo and _G.GetBuildInfo()
    interfaceVersion = tonumber(interfaceVersion) or 0
    -- [TAINT FIX] The premade group finder (LFGList) uses protected frames,
    -- secret values, and forbidden objects since 11.x. Skinning any part of
    -- it propagates taint through Blizzard's secure execution path, causing
    -- "Action blocked" errors during combat, role checks and ready checks.
    return interfaceVersion >= 110000
end

local function IsSecureLFGReadableTextFrame(frame)
    if not (frame and IsSecureLFGSafeMode()) then
        return false
    end

    local cur = frame
    local depth = 0
    while cur and depth < 10 do
        local name = cur.GetName and cur:GetName() or nil
        if name == "LFGListFrame"
            or name == "LFGListApplicationDialog"
            or name == "LFGListSearchPanel"
            or name == "LFGListApplicationViewer"
            or name == "PVEFrameLFGListFrame"
            or name == "PVEFrameGroupFinderFrame"
        then
            return true
        end
        cur = cur.GetParent and cur:GetParent() or nil
        depth = depth + 1
    end

    return false
end

local function SetAvantGarde(object, size, outline)
    if object and object.SetFont then
        object:SetFont(AVANT_GARDE_FONT, size or 12, outline or "OUTLINE")
        object:SetShadowOffset(0, 0)
    end
end

local function IsSafeCheckboxChecked(checkbox)
    if not checkbox then
        return false
    end

    local checkedTexture = checkbox.GetCheckedTexture and checkbox:GetCheckedTexture()
    if checkedTexture and checkedTexture.IsShown then
        local ok, shown = pcall(checkedTexture.IsShown, checkedTexture)
        if ok and shown ~= nil and not (issecretvalue and issecretvalue(shown)) then
            -- A skin may deliberately hide the native checked texture. A shown
            -- texture proves selection, but a hidden one does not prove the
            -- opposite; fall through to the checkbox's actual checked value.
            if shown == true then return true end
        end
    end

    if checkbox.GetChecked then
        local ok, checked = pcall(checkbox.GetChecked, checkbox)
        if ok and checked ~= nil and not (issecretvalue and issecretvalue(checked)) then
            return checked == true
        end
    end

    return false
end

local function EnsureWindowAccentBorder(frame)
    if not frame then return end
    if not frame.KT_AccentEdges then
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        overlay:SetFrameLevel(frame:GetFrameLevel() + 100)
        overlay:EnableMouse(false)
        frame.KT_AccentBorderFrame = overlay
        frame.KT_AccentEdges = {}
        for index = 1, 4 do
            local edge = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
            edge:SetTexture("Interface\\Buttons\\WHITE8x8")
            frame.KT_AccentEdges[index] = edge
        end
        local edges = frame.KT_AccentEdges
        edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        edges[1]:SetHeight(1)
        edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        edges[2]:SetHeight(1)
        edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(1)
        edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(1)
    end
    local function RefreshWindowBorder(target, enabled, color)
        for _, edge in ipairs(target.KT_AccentEdges or {}) do
            edge:SetVertexColor(color[1], color[2], color[3], 1)
            edge:SetShown(enabled)
        end
    end

    if not frame._ktAccentBorderRefreshRegistered then
        S:RegisterBlizzardWindowBorder(frame, RefreshWindowBorder)
        frame._ktAccentBorderRefreshRegistered = true
    else
        RefreshWindowBorder(frame, S:AreBlizzardWindowBordersEnabled(), S:GetAccentColor())
    end
end

local function EnsureRoleSelectionFeedback(button)
    if not button then return end
    local check = button.checkButton or button.CheckButton or button

    if not button.KT_RoleSelectionBorder then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        border:SetFrameLevel(button:GetFrameLevel() + 8)
        border:EnableMouse(false)
        button.KT_RoleSelectionBorder = border

        local glow = button:CreateTexture(nil, "OVERLAY", nil, 6)
        glow:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
        glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
        glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        glow:SetBlendMode("ADD")
        button.KT_RoleSelectionGlow = glow
    end

    local function RefreshRoleSelection()
        local checked = IsSafeCheckboxChecked(check)
        if not checked then
            for _, texture in ipairs({ button.SelectedTexture, button.selectedTexture, button.Check, button.CheckedTexture }) do
                if texture and texture.IsShown then
                    local ok, shown = pcall(texture.IsShown, texture)
                    if ok and shown == true and not (issecretvalue and issecretvalue(shown)) then
                        checked = true
                        break
                    end
                end
            end
        end
        local accent = S:GetAccentColor()
        local border = button.KT_RoleSelectionBorder
        local glow = button.KT_RoleSelectionGlow
        local icon = button.KT_RoleIcon or button.Icon or button.icon or button.background
        if checked then
            border:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
            border:SetAlpha(1)
            glow:SetVertexColor(accent[1], accent[2], accent[3], 0.28)
            glow:Show()
            if icon and icon.SetAlpha then icon:SetAlpha(1) end
            if icon and icon.SetDesaturated then icon:SetDesaturated(false) end
        else
            border:SetBackdropBorderColor(0.22, 0.22, 0.25, 0.9)
            border:SetAlpha(0.8)
            glow:Hide()
            if icon and icon.SetAlpha then icon:SetAlpha(0.72) end
        end
        border:Show()
    end

    button.KT_RefreshRoleSelection = RefreshRoleSelection
    if not button._ktRoleSelectionFeedbackHooked then
        button._ktRoleSelectionFeedbackHooked = true
        if check and check.SetChecked then hooksecurefunc(check, "SetChecked", RefreshRoleSelection) end
        if check and check.HookScript then check:HookScript("OnClick", RefreshRoleSelection) end
        button:HookScript("OnClick", function() C_Timer.After(0, RefreshRoleSelection) end)
        button:HookScript("OnShow", function() C_Timer.After(0, RefreshRoleSelection) end)
        S:RegisterBlizzardAccentRefresh(button, function()
            RefreshRoleSelection()
        end)
    end
    RefreshRoleSelection()
end

local function AddRoleFeedbackInTree(root, depth, seen)
    if not root or depth > 5 then return end
    seen = seen or {}
    if seen[root] then return end
    seen[root] = true
    if root.GetChildren then
        for _, child in ipairs({ root:GetChildren() }) do
            local name = child.GetName and child:GetName() or ""
            local lower = type(name) == "string" and name:lower() or ""
            local isRoleButton = lower:find("rolebutton", 1, true)
                or (lower:find("role", 1, true) and (
                    lower:find("tank", 1, true)
                    or lower:find("heal", 1, true)
                    or lower:find("damage", 1, true)
                    or lower:find("dps", 1, true)))
            if isRoleButton and child.IsObjectType and child:IsObjectType("Button") then
                EnsureRoleSelectionFeedback(child)
            end
            AddRoleFeedbackInTree(child, depth + 1, seen)
        end
    end
end

local function SkinCheckBoxKT(checkbox)
    if not checkbox then return end
    if checkbox.IsSkinnedKT then return end

    S:HandleCheckBox(checkbox)
    
    checkbox.InnerSquare = checkbox:CreateTexture(nil, "OVERLAY")
    local accent = S:GetAccentColor()
    checkbox.InnerSquare:SetColorTexture(accent[1], accent[2], accent[3], 1)
    checkbox.InnerSquare:SetPoint("TOPLEFT", 4, -4)
    checkbox.InnerSquare:SetPoint("BOTTOMRIGHT", -4, 4)
    checkbox.InnerSquare:Hide()
    S:RegisterBlizzardAccentRefresh(checkbox, function(self, color)
        if self.InnerSquare then
            self.InnerSquare:SetColorTexture(color[1], color[2], color[3], 1)
        end
    end)

    local function UpdateState(self)
        if IsSafeCheckboxChecked(self) then
            self.InnerSquare:Show()
        else
            self.InnerSquare:Hide()
        end
    end

    hooksecurefunc(checkbox, "SetChecked", UpdateState)
    checkbox:HookScript("OnClick", UpdateState)
    checkbox:HookScript("OnShow", UpdateState)
    
    UpdateState(checkbox)
    checkbox.IsSkinnedKT = true
end

local groupButtonIcons = {
    133076,
    133074,
    464820
}

local function EnsureCategorySeparators(button)
    if not button then return end

    local c = S.GetAccentColor and S:GetAccentColor() or { 1, 0, 0.333 }
    if not button._ktSepTop then
        local sepT = button:CreateTexture(nil, "OVERLAY")
        sepT:SetHeight(1)
        sepT:SetPoint("TOPLEFT", button, "TOPLEFT", 10, 0)
        sepT:SetPoint("TOPRIGHT", button, "TOPRIGHT", -10, 0)
        button._ktSepTop = sepT
    end
    button._ktSepTop:SetColorTexture(c[1], c[2], c[3], 0.8)

    if not button._ktSepBot then
        local sepB = button:CreateTexture(nil, "OVERLAY")
        sepB:SetHeight(1)
        sepB:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 10, 0)
        sepB:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -10, 0)
        button._ktSepBot = sepB
    end
    button._ktSepBot:SetColorTexture(c[1], c[2], c[3], 0.8)
    S:RegisterBlizzardAccentRefresh(button, function(self, color)
        if self._ktSepTop then self._ktSepTop:SetColorTexture(color[1], color[2], color[3], 0.8) end
        if self._ktSepBot then self._ktSepBot:SetColorTexture(color[1], color[2], color[3], 0.8) end
    end)
end

local function HandleGoldIcon(button)
    local Button = _G[button]
    if not Button or Button.backdrop then return end

    local count = _G[button..'Count']
    local nameFrame = _G[button..'NameFrame']
    local iconTexture = _G[button..'IconTexture']

    S:CreateBackdrop(Button)
    Button.backdrop:ClearAllPoints()
    Button.backdrop:SetPoint('LEFT', 1, 0)
    Button.backdrop:SetSize(42, 42)

    if iconTexture then
        iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconTexture:SetDrawLayer('OVERLAY')
        iconTexture:SetParent(Button.backdrop)
        S:SetInside(iconTexture, Button.backdrop)
    end

    if count then
        count:SetParent(Button.backdrop)
        count:SetDrawLayer('OVERLAY')
        SetAvantGarde(count, 12, "OUTLINE")
    end

    if nameFrame then
        nameFrame:SetTexture(nil)
        nameFrame:SetSize(118, 39)
    end
end

local function SkinItemButton(frame, _, index)
    local parentName = frame:GetName()
    local item = _G[parentName..'Item'..index]
    if item and not item.backdrop then
        S:CreateBackdrop(item)
        item.backdrop:ClearAllPoints()
        item.backdrop:SetPoint('LEFT', 1, 0)
        item.backdrop:SetSize(42, 42)

        if item.Icon then
            item.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            item.Icon:SetDrawLayer('OVERLAY')
            item.Icon:SetParent(item.backdrop)
            S:SetInside(item.Icon, item.backdrop)
        end

        if item.Count then
            item.Count:SetDrawLayer('OVERLAY')
            item.Count:SetParent(item.backdrop)
            SetAvantGarde(item.Count, 12, "OUTLINE")
        end

        if item.NameFrame then
            item.NameFrame:SetTexture(nil)
            item.NameFrame:SetSize(118, 39)
        end

        if item.shortageBorder then
            item.shortageBorder:SetTexture(nil)
        end
        
        if item.Name then SetAvantGarde(item.Name, 12) end

        if item.roleIcon1 then item.roleIcon1:SetParent(item.backdrop) end
        if item.roleIcon2 then item.roleIcon2:SetParent(item.backdrop) end

        if item.IconBorder then
            item.IconBorder:SetAlpha(0)
        end
    end
end

local mapIDtoSpellID = {
    [2] = 131204, [165] = 159899, [168] = 159901, [198] = 424163, [199] = 424153,
    [200] = 393764, [206] = 410078, [210] = 393766, [244] = 424187, [245] = 410071,
    [248] = 424167, [251] = 410074, [370] = 373274, [375] = 354464, [376] = 354462,
    [378] = 354465, [382] = 354467, [391] = 367416, [392] = 367416, [399] = 393256,
    [400] = 393262, [401] = 393279, [402] = 393273, [403] = 393222, [404] = 393276,
    [405] = 393267, [406] = 393283, [438] = 410080, [456] = 424142, [463] = 424197,
    [464] = 424197, [499] = 445444, [500] = 445443, [501] = 445269, [502] = 445416,
    [503] = 445417, [504] = 445441, [505] = 445414, [506] = 445440, [507] = 445424,
    [525] = 1216786, [542] = 1237215,
}

local mapIDtoName = {
    [2] = "Jade Snek", [165] = "Free Key", [168] = "Everbloom", [198] = "DHT",
    [199] = "BRH", [200] = "HoV", [206] = "NL", [210] = "CoS", [244] = "AD",
    [245] = "FH", [247] = "ML", [248] = "Waycrest", [251] = "UR", [353] = "Siege",
    [370] = "Mechagon", [375] = "Mists", [376] = "Kyrian Weapon", [378] = "HoA",
    [382] = "ToP", [391] = "Tazavesh", [392] = "Tazavesh", [399] = "RLP",
    [400] = "NO", [401] = "AV", [402] = "AA", [403] = "Uldaman", [404] = "Neltharus",
    [405] = "Brokeback", [406] = "HoI", [438] = "Vortex", [456] = "THOT",
    [463] = "DOTI", [464] = "DOTI", [499] = "Priory", [500] = "Rookery",
    [501] = "SV", [502] = "Threads", [503] = "Ara Ara", [504] = "DFC",
    [505] = "Dawnbreaker", [506] = "Meadery", [507] = "GB", [525] = "Flood",
    [542] = "Eco Dome",
}

local function GetSpecialMapSpell(mapID)
    local playerFaction = UnitFactionGroup("player")
    if mapID == 353 then
        return (playerFaction == "Alliance") and 445418 or 464256
    elseif mapID == 247 then
        return (playerFaction == "Alliance") and 467553 or 467555
    end
    return -1
end

local teleportButtons = {}

local function UpdateTeleportCooldowns()
    if InCombatLockdown() then return end -- teleports cannot be used in combat
    for _, button in pairs(teleportButtons) do
        if button:IsShown() then
            local start, duration = C_Spell.GetSpellCooldown(button.spellID)
            if duration and duration > 0 then
                button.cd:SetCooldown(start, duration)
            else
                button.cd:Hide()
            end
        end
    end
end

local function CreateTeleportButton(mapID, spellID, parent, index)
    local name = "KT_TeleportBtn" .. mapID
    local button = teleportButtons[mapID] or CreateFrame("Button", name, parent)
    
    if not teleportButtons[mapID] then
        button:SetSize(30, 30)
        button:RegisterForClicks("AnyUp")
        button:HookScript("OnClick", function(self)
            if InCombatLockdown() then return end
            if self.spellID and C_Spell and C_Spell.CastSpellByID then
                C_Spell.CastSpellByID(self.spellID)
            end
        end)
        
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        S:HandleIcon(icon)
        button.icon = icon
        
        button.cd = CreateFrame("Cooldown", name .. "CD", button, "CooldownFrameTemplate")
        button.cd:SetAllPoints()
        
        button.text = button:CreateFontString(nil, "OVERLAY")
        SetAvantGarde(button.text, 10, "OUTLINE")
        button.text:SetPoint("LEFT", button, "RIGHT", 5, 0)
        
        S:CreateBackdrop(button)
        teleportButtons[mapID] = button
    end
    
    button.spellID = spellID
    button.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    button.text:SetText(mapIDtoName[mapID] or "")
    
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", parent, "TOPRIGHT", 10, -(index * 34))
    
    return button
end

local function UpdateTeleportButtons()
    if InCombatLockdown() then return end
    
    local ChallengesFrame = _G.ChallengesFrame
    if not ChallengesFrame or not ChallengesFrame:IsShown() then return end
    
    local maps = C_ChallengeMode.GetMapTable()
    local shownCount = 0
    
    for _, btn in pairs(teleportButtons) do btn:Hide() end
    
    for _, mapID in ipairs(maps) do
        local spellID = mapIDtoSpellID[mapID] or GetSpecialMapSpell(mapID)
        if spellID and spellID > 0 and IsSpellKnown(spellID) then
            local btn = CreateTeleportButton(mapID, spellID, ChallengesFrame, shownCount)
            btn:Show()
            shownCount = shownCount + 1
        end
    end
    UpdateTeleportCooldowns()
end

local function LFDQueueFrameSpecificUpdateChild(child)
    if not child.IsSkinned then
        if child.enableButton then SkinCheckBoxKT(child.enableButton) end
        if child.name then SetAvantGarde(child.name, 12) end
        if child.level then SetAvantGarde(child.level, 12) end
        child.IsSkinned = true
    end
end

local function LFDQueueFrameSpecificUpdate(frame)
    frame:ForEachFrame(LFDQueueFrameSpecificUpdateChild)
end

local ROLE_ICONS = {
    TANK    = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\Tank.png",
    HEALER  = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\Healer.png",
    DAMAGER = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\DPS.png",
    LEADER  = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\Leader.png",  -- Added for completeness
}

local function RestoreLFGInviteRoleIcon(popup)
    if not popup then return end

    local roleIcon = popup.RoleIcon
    if roleIcon then
        if roleIcon.SetAlpha then roleIcon:SetAlpha(1) end
        if roleIcon.Show then roleIcon:Show() end

        -- Some client builds expose the actual texture below RoleIcon.
        local texture = roleIcon.Icon or roleIcon.Texture or popup.RoleIconTexture
        if texture then
            if texture.SetAlpha then texture:SetAlpha(1) end
            if texture.Show then texture:Show() end
        end
    end
end

local function IsLFGRoleCheckButton(button)
    if not button then
        return false
    end

    local name = button.GetName and button:GetName() or ""
    local parent = button.GetParent and button:GetParent()
    local parentName = parent and parent.GetName and parent:GetName() or ""

    return (type(name) == "string" and name:find("RoleButton"))
        or (type(parentName) == "string" and parentName:find("RoleButton"))
end

local function SuppressTexture(tex)
    if not tex then return end
    if tex.SetTexture then tex:SetTexture(nil) end
    if tex.SetAlpha then tex:SetAlpha(0) end
    if tex.Hide then tex:Hide() end
    if not tex._ktSuppressedShowHook and hooksecurefunc then
        tex._ktSuppressedShowHook = true
        -- [TAINT FIX] Midnight 12.x: Never call Hide() inside a Show hook.
        -- Hide() in a hooksecurefunc("Show") propagates taint through the
        -- secure Show/Hide state machine. SetAlpha(0) alone is sufficient.
        hooksecurefunc(tex, "Show", function(self)
            if self.SetAlpha then self:SetAlpha(0) end
        end)
    end
end

local function SuppressTextureRegions(frame, sizeLimit)
    if not frame or not frame.GetRegions then
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local shouldSuppress = true
            if sizeLimit then
                local w = region.GetWidth and region:GetWidth() or 0
                local h = region.GetHeight and region:GetHeight() or 0
                shouldSuppress = not (w > sizeLimit or h > sizeLimit)
            end
            if shouldSuppress then
                SuppressTexture(region)
            end
        end
    end
end

local function HideNativeRoleCheckTextures(check)
    if not check then return end

    if check.SetNormalTexture then check:SetNormalTexture("") end
    if check.SetPushedTexture then check:SetPushedTexture("") end
    if check.SetHighlightTexture then check:SetHighlightTexture("") end
    if check.SetCheckedTexture then check:SetCheckedTexture("") end
    if check.SetDisabledCheckedTexture then check:SetDisabledCheckedTexture("") end

    SuppressTexture(check.GetNormalTexture and check:GetNormalTexture())
    SuppressTexture(check.GetPushedTexture and check:GetPushedTexture())
    SuppressTexture(check.GetHighlightTexture and check:GetHighlightTexture())
    SuppressTexture(check.GetCheckedTexture and check:GetCheckedTexture())
    SuppressTexture(check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture())
    SuppressTextureRegions(check, 32)

    for _, child in ipairs({ check:GetChildren() }) do
        SuppressTextureRegions(child, 32)
    end

    if check.SetAlpha then
        check:SetAlpha(0.01)
    end
    if not check._ktRoleAlphaHooked then
        check._ktRoleAlphaHooked = true
        check:HookScript("OnShow", function(self)
            if self.SetAlpha then
                self:SetAlpha(0.01)
            end
        end)
    end
end

local function HideNativeRoleButtonDecorations(button, check)
    if not button or button._ktRoleDecorHidden then
        return
    end

    local keep = {}
    local function Keep(obj)
        if obj then
            keep[obj] = true
        end
    end

    Keep(button.KT_RoleIcon)
    Keep(button.incentiveIcon)
    Keep(check)
    Keep(check and check.GetNormalTexture and check:GetNormalTexture())
    Keep(check and check.GetPushedTexture and check:GetPushedTexture())
    Keep(check and check.GetHighlightTexture and check:GetHighlightTexture())
    Keep(check and check.GetCheckedTexture and check:GetCheckedTexture())
    Keep(check and check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture())

    for _, region in ipairs({ button:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") and not keep[region] then
            local w = region.GetWidth and region:GetWidth() or 0
            local h = region.GetHeight and region:GetHeight() or 0
            if w > 0 and h > 0 and w <= 22 and h <= 22 then
                SuppressTexture(region)
            end
        end
    end

    if button.lockedIndicator then
        SuppressTextureRegions(button.lockedIndicator, 24)
    end
    if button.alert then
        SuppressTextureRegions(button.alert, 24)
    end

    button._ktRoleDecorHidden = true
end

local function SkinRoleButton(button, role)
    if not button then return end
    local check = button.checkButton or button.CheckButton or button

    if role and ROLE_ICONS[role] and not button.KT_RoleIcon then
        local icon = button:CreateTexture(nil, "ARTWORK", nil, 2)
        icon:SetTexture(ROLE_ICONS[role])
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon._ktKuiPopupArt = true
        button.KT_RoleIcon = icon
    elseif role and ROLE_ICONS[role] and button.KT_RoleIcon then
        button.KT_RoleIcon:SetTexture(ROLE_ICONS[role])
        button.KT_RoleIcon._ktKuiPopupArt = true
    end

    HideNativeRoleCheckTextures(check)
    HideNativeRoleButtonDecorations(button, check)

    if not button.KT_RoleCheckBorder then
        button.KT_RoleCheckBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.KT_RoleCheckBorder:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        button.KT_RoleCheckBorder:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        local accent = S:GetAccentColor()
        button.KT_RoleCheckBorder:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        button.KT_RoleCheckBorder:SetFrameLevel((check.GetFrameLevel and check:GetFrameLevel()) or button:GetFrameLevel() + 5)
        button.KT_RoleCheckBorder:EnableMouse(false)
    end

    button.KT_RoleCheckBorder:ClearAllPoints()
    button.KT_RoleCheckBorder:SetPoint("CENTER", button.KT_RoleIcon or button, "BOTTOMRIGHT", -6, 6)
    button.KT_RoleCheckBorder:SetSize(12, 12)

    if not button.KT_RoleCheckFill then
        local fill = button.KT_RoleCheckBorder:CreateTexture(nil, "OVERLAY")
        fill:SetTexture("Interface\\Buttons\\WHITE8x8")
        local accent = S:GetAccentColor()
        fill:SetVertexColor(accent[1], accent[2], accent[3], 1)
        fill:SetPoint("TOPLEFT", button.KT_RoleCheckBorder, "TOPLEFT", 3, -3)
        fill:SetPoint("BOTTOMRIGHT", button.KT_RoleCheckBorder, "BOTTOMRIGHT", -3, 3)
        fill._ktKuiPopupArt = true
        button.KT_RoleCheckFill = fill
    end
    S:RegisterBlizzardAccentRefresh(button, function(self, color)
        if self.KT_RoleCheckBorder then
            self.KT_RoleCheckBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        end
        if self.KT_RoleCheckFill then
            self.KT_RoleCheckFill:SetVertexColor(color[1], color[2], color[3], 1)
        end
    end)

    local function UpdateRoleState()
        local checked = IsSafeCheckboxChecked(check)
        if button.KT_RoleCheckFill then
            if checked then
                button.KT_RoleCheckFill:Show()
            else
                button.KT_RoleCheckFill:Hide()
            end
        end
        if button.KT_RoleCheckBorder then
            button.KT_RoleCheckBorder:SetAlpha((check.IsEnabled and check:IsEnabled()) and 1 or 0.65)
            button.KT_RoleCheckBorder:Show()
        end
        if check and check.SetAlpha then
            check:SetAlpha(0.01)
        end
    end

    if not button._ktRoleStateHooked then
        button._ktRoleStateHooked = true
        if check.SetChecked then
            hooksecurefunc(check, "SetChecked", UpdateRoleState)
        end
        if check.SetEnabled then
            hooksecurefunc(check, "SetEnabled", UpdateRoleState)
        end
        check:HookScript("OnShow", UpdateRoleState)
        button:HookScript("OnShow", UpdateRoleState)
    end

    UpdateRoleState()
end

local function EnsureTextureVisible(tex, layer)
    if not tex then return end
    if tex.SetAlpha then tex:SetAlpha(1) end
    if tex.SetDrawLayer then tex:SetDrawLayer(layer or "ARTWORK") end
    if tex.SetDesaturated then tex:SetDesaturated(false) end
    if tex.SetVertexColor then tex:SetVertexColor(1, 1, 1, 1) end
    if tex.Show then tex:Show() end
end

local function EnsureReadableFont(fs, size, r, g, b)
    if not fs or not fs.SetTextColor then return end
    SetAvantGarde(fs, size or 12, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
end

local function StyleButtonFont(button, size)
    if not button then return end
    local fs = button.Text or (button.GetFontString and button:GetFontString())
    if not fs then return end
    SetAvantGarde(fs, size or 12, "OUTLINE")
    if fs.GetTextColor then
        local r, g, b = fs:GetTextColor()
        if r and g and b and (r + g + b) < 0.5 then
            fs:SetTextColor(1, 1, 1)
        end
    end
end

local function KeepAccentButtonBorder(button)
    if not button then return end

    if not button.KT_FullAccentEdges then
        local edges = {}
        for index = 1, 4 do
            edges[index] = button:CreateTexture(nil, "OVERLAY", nil, 7)
            edges[index]:SetTexture("Interface\\Buttons\\WHITE8x8")
        end
        edges[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        edges[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        edges[1]:SetHeight(1)
        edges[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        edges[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        edges[2]:SetHeight(1)
        edges[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(1)
        edges[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(1)
        button.KT_FullAccentEdges = edges
    end

    local function RefreshAccentBorder(self)
        if not self then return end
        local accent = S:GetAccentColor()
        if self.backdrop and self.backdrop.SetBackdropBorderColor then
            self.backdrop:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        end
        for _, edge in ipairs(self.KT_FullAccentEdges or {}) do
            edge:SetVertexColor(accent[1], accent[2], accent[3], 1)
            edge:Show()
        end
    end

    RefreshAccentBorder(button)
    S:RegisterBlizzardAccentRefresh(button, function(self, color)
        if self.backdrop and self.backdrop.SetBackdropBorderColor then
            self.backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        end
        for _, edge in ipairs(self.KT_FullAccentEdges or {}) do
            edge:SetVertexColor(color[1], color[2], color[3], 1)
            edge:Show()
        end
    end)
    if not button._ktPersistentAccentBorder then
        button:HookScript("OnShow", RefreshAccentBorder)
        button:HookScript("OnEnter", RefreshAccentBorder)
        button:HookScript("OnLeave", RefreshAccentBorder)
        button:HookScript("OnEnable", RefreshAccentBorder)
        button:HookScript("OnDisable", RefreshAccentBorder)
        button._ktPersistentAccentBorder = true
    end
end

local function ApplyListSelectionVisual(button, selected)
    if not (button and button.backdrop) then return end
    local accent = S:GetAccentColor()
    if not button.KT_SelectedOverlay then
        local overlay = button:CreateTexture(nil, "ARTWORK", nil, 1)
        overlay:SetPoint("TOPLEFT", button.backdrop, "TOPLEFT", 1, -1)
        overlay:SetPoint("BOTTOMRIGHT", button.backdrop, "BOTTOMRIGHT", -1, 1)
        overlay._ktKeepSelectionColor = true
        button.KT_SelectedOverlay = overlay

        local marker = button:CreateTexture(nil, "OVERLAY", nil, 7)
        marker:SetPoint("TOPLEFT", button.backdrop, "TOPLEFT", 1, -1)
        marker:SetPoint("BOTTOMLEFT", button.backdrop, "BOTTOMLEFT", 1, 1)
        marker:SetWidth(3)
        marker._ktKeepSelectionColor = true
        button.KT_SelectionMarker = marker

        local edges = {}
        for index = 1, 4 do
            local edge = button:CreateTexture(nil, "OVERLAY", nil, 7)
            edge:SetTexture("Interface\\Buttons\\WHITE8x8")
            edge._ktKeepSelectionColor = true
            edges[index] = edge
        end
        edges[1]:SetPoint("TOPLEFT", button.backdrop, "TOPLEFT", 0, 0)
        edges[1]:SetPoint("TOPRIGHT", button.backdrop, "TOPRIGHT", 0, 0)
        edges[1]:SetHeight(1)
        edges[2]:SetPoint("BOTTOMLEFT", button.backdrop, "BOTTOMLEFT", 0, 0)
        edges[2]:SetPoint("BOTTOMRIGHT", button.backdrop, "BOTTOMRIGHT", 0, 0)
        edges[2]:SetHeight(1)
        edges[3]:SetPoint("TOPLEFT", button.backdrop, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMLEFT", button.backdrop, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(1)
        edges[4]:SetPoint("TOPRIGHT", button.backdrop, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMRIGHT", button.backdrop, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(1)
        button.KT_SelectionEdges = edges
    end

    if not button._ktSelectionAccentRefreshRegistered then
        S:RegisterBlizzardAccentRefresh(button, function(self)
            ApplyListSelectionVisual(self, self.KT_Selected)
        end)
        button._ktSelectionAccentRefreshRegistered = true
    end

    button.KT_Selected = selected == true
    button.KT_SelectedOverlay:SetColorTexture(accent[1], accent[2], accent[3], 0.42)
    button.KT_SelectionMarker:SetColorTexture(accent[1], accent[2], accent[3], 1)
    for _, edge in ipairs(button.KT_SelectionEdges or {}) do
        edge:SetVertexColor(accent[1], accent[2], accent[3], 1)
        edge:SetShown(button.KT_Selected)
    end
    local normalTexture = button.GetNormalTexture and button:GetNormalTexture()
    if normalTexture then
        normalTexture._ktKeepSelectionColor = true
        if button.KT_Selected then
            normalTexture:SetVertexColor(accent[1] * 0.42, accent[2] * 0.34, accent[3] * 0.24, 0.98)
        else
            normalTexture:SetVertexColor(0.075, 0.075, 0.085, 0.94)
        end
    end
    button.KT_SelectedOverlay:SetShown(button.KT_Selected)
    button.KT_SelectionMarker:SetShown(button.KT_Selected)
    if button.KT_Selected then
        if not button._ktBaseLevel then button._ktBaseLevel = button:GetFrameLevel() end
        local newLevel = button._ktBaseLevel + 5
        button:SetFrameLevel(newLevel)
        if button.backdrop then button.backdrop:SetFrameLevel(newLevel - 1) end
        button.backdrop:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        button.backdrop:SetBackdropColor(accent[1] * 0.24, accent[2] * 0.18, accent[3] * 0.12, 0.98)
    else
        if button._ktBaseLevel then 
            button:SetFrameLevel(button._ktBaseLevel)
            if button.backdrop then button.backdrop:SetFrameLevel(button._ktBaseLevel - 1) end
        end
        button.backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
        button.backdrop:SetBackdropColor(0.035, 0.035, 0.045, 0.94)
    end

    local text = button.Name or button.Title or button.Text or (button.GetFontString and button:GetFontString())
    if text and text.SetTextColor then
        text:SetTextColor(1, 1, 1, 1)
        if text.SetDrawLayer then text:SetDrawLayer("OVERLAY", 7) end
    end
    local icon = button.Icon or button.icon
    if icon and icon.SetDrawLayer then icon:SetDrawLayer("OVERLAY", 6) end
end

local function IsNativeSelectionShown(button)
    local texture = button and (button.SelectedTexture or button.selectedTexture)
    if not (texture and texture.IsShown) then return false end
    local ok, shown = pcall(texture.IsShown, texture)
    return ok and shown == true and not (issecretvalue and issecretvalue(shown))
end

local function SkinPVPActivityGroup(buttons)
    local function RefreshGroup()
        for _, button in pairs(buttons) do
            if button then
                ApplyListSelectionVisual(button, IsNativeSelectionShown(button))
            end
        end
    end

    for _, button in pairs(buttons) do
        if button and not button._ktPVPActivitySkinned then
            local selectedTexture = button.SelectedTexture or button.selectedTexture
            S:HandleButton(button)
            if selectedTexture then
                selectedTexture:SetAlpha(0)
                selectedTexture._ktKeepSelectionColor = true
                for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
                    if type(selectedTexture[method]) == "function" then
                        hooksecurefunc(selectedTexture, method, function()
                            C_Timer.After(0, RefreshGroup)
                        end)
                    end
                end
            end

            local title = button.Title or button.Name or button.Text or (button.GetFontString and button:GetFontString())
            if title then SetAvantGarde(title, 14, "OUTLINE") end
            for _, label in ipairs({ title, button.TeamSizeText, button.TeamTypeText, button.LevelRequirement }) do
                if label and label.SetTextColor then
                    label:SetTextColor(1, 1, 1, 1)
                    if label.SetDrawLayer then label:SetDrawLayer("OVERLAY", 7) end
                end
            end
            button:HookScript("OnClick", function() C_Timer.After(0, RefreshGroup) end)
            button:HookScript("OnShow", function() C_Timer.After(0, RefreshGroup) end)
            button._ktPVPActivitySkinned = true
        end
    end

    RefreshGroup()
end

local function EnablePVPRoleSelectionFeedback(button)
    if not button or button._ktStrongPVPRoleFeedback then return end
    local check = button.checkButton or button.CheckButton or button

    -- PvP role templates still draw Blizzard's small yellow checked marker.
    -- Suppress that artwork only; GetChecked() remains the source of truth.
    if check ~= button then
        HideNativeRoleCheckTextures(check)
    else
        SuppressTexture(check.GetCheckedTexture and check:GetCheckedTexture())
        SuppressTexture(check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture())
    end

    local ring = button:CreateTexture(nil, "OVERLAY", nil, 7)
    ring:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 6)
    ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 6, -6)
    ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    ring:SetBlendMode("ADD")
    ring._ktKeepSelectionColor = true
    ring:Hide()
    button.KT_PVPRoleRing = ring

    local function RefreshRole()
        local selected = IsSafeCheckboxChecked(check)
        local accent = S:GetAccentColor()
        local icon = button.KT_RoleIcon or button.Icon or button.icon or button.background
        if selected then
            ring:SetVertexColor(accent[1], accent[2], accent[3], 1)
            ring:Show()
            if icon and icon.SetAlpha then icon:SetAlpha(1) end
            if icon and icon.SetDesaturated then icon:SetDesaturated(false) end
        else
            ring:Hide()
            if icon and icon.SetAlpha then icon:SetAlpha(0.72) end
        end
    end

    button.KT_RefreshPVPRoleSelection = RefreshRole
    if check.SetChecked then hooksecurefunc(check, "SetChecked", RefreshRole) end
    button:HookScript("OnClick", function() C_Timer.After(0, RefreshRole) end)
    button:HookScript("OnShow", function() C_Timer.After(0, RefreshRole) end)
    S:RegisterBlizzardAccentRefresh(button, function() RefreshRole() end)
    button._ktStrongPVPRoleFeedback = true
    RefreshRole()
end
local function SkinPVPRoleList(roleList)
    if not roleList then return end
    local buttons = {
        roleList.TankIcon or (roleList.RoleIcons and roleList.RoleIcons[1]),
        roleList.HealerIcon or (roleList.RoleIcons and roleList.RoleIcons[2]),
        roleList.DPSIcon or (roleList.RoleIcons and roleList.RoleIcons[3]),
    }
    for _, button in ipairs(buttons) do
        EnablePVPRoleSelectionFeedback(button)
    end
end

local function ReplaceDarkInlineColor(hex)
    local rr = tonumber(hex:sub(1, 2), 16) or 255
    local gg = tonumber(hex:sub(3, 4), 16) or 255
    local bb = tonumber(hex:sub(5, 6), 16) or 255
    if (rr + gg + bb) < 350 then
        return "|cffffffff"
    end
    return "|cff" .. hex
end

local function FixInlineDarkColor(fs)
    if not fs or not fs.GetText or not fs.SetText then return end
    local text = fs:GetText()
    if type(text) ~= "string" or text == "" then return end
    local cleaned, count = text:gsub("|c[fF][fF](%x%x%x%x%x%x)", ReplaceDarkInlineColor)
    if count > 0 and cleaned ~= text then
        fs:SetText(cleaned)
    end
end

local function IsDarkFontColor(fs)
    if not fs or not fs.GetTextColor then return false end
    local r, g, b = fs:GetTextColor()
    if r == nil or g == nil or b == nil then return false end
    return (r + g + b) < 0.36
end

local function FixReadableLFGFont(fs, size, preferGold)
    if not fs or not fs.SetTextColor then return end
    if fs.IsForbidden and fs:IsForbidden() then return end

    local currentText = fs.GetText and fs:GetText()
    if type(currentText) == "string" and currentText ~= "" then
        FixInlineDarkColor(fs)
    end

    SetAvantGarde(fs, size or 12, "OUTLINE")
    if fs.SetAlpha then
        fs:SetAlpha(1)
    end
    if fs.Show then
        fs:Show()
    end
    if fs.SetDrawLayer then
        fs:SetDrawLayer("OVERLAY")
    end

    if preferGold then
        fs:SetTextColor(1, 0.82, 0.10, 1)
    else
        fs:SetTextColor(1, 1, 1, 1)
    end

    if hooksecurefunc and not fs._ktReadableHooked then
        hooksecurefunc(fs, "SetTextColor", function(self, r, g, b, a)
            if self._ktReadableGuard then return end
            if r == nil or g == nil or b == nil or (r + g + b) < 0.5 or ((a or 1) < 0.5) then
                self._ktReadableGuard = true
                if preferGold then
                    self:SetTextColor(1, 0.82, 0.10, 1)
                else
                    self:SetTextColor(1, 1, 1, 1)
                end
                self._ktReadableGuard = nil
            end
        end)
        if fs.SetAlpha then
            hooksecurefunc(fs, "SetAlpha", function(self, alpha)
                if self._ktReadableAlphaGuard then return end
                if type(alpha) == "number" and alpha < 0.5 then
                    self._ktReadableAlphaGuard = true
                    self:SetAlpha(1)
                    self._ktReadableAlphaGuard = nil
                end
            end)
        end
        fs._ktReadableHooked = true
    end
end

local function RefreshLFGReadableText(root)
    if not root then return end

    local seen = {}
    local function refreshNode(node, depth)
        if not node or seen[node] or depth > 4 then
            return
        end
        seen[node] = true

        if node.GetObjectType and node:GetObjectType() == "FontString" then
            local parent = node.GetParent and node:GetParent() or nil
            if IsSecureLFGReadableTextFrame(parent) then
                local text = node.GetText and node:GetText()
                if type(text) == "string" and text ~= "" then
                    local lower = text:lower()
                    local preferGold = lower:find("choose", 1, true)
                        or lower:find("roles", 1, true)
                        or lower:find("group leader", 1, true)
                    FixReadableLFGFont(node, 12, preferGold)
                end
            end
            return
        end

        if node.GetRegions then
            for _, region in ipairs({ node:GetRegions() }) do
                refreshNode(region, depth + 1)
            end
        end
        if node.GetChildren then
            for _, child in ipairs({ node:GetChildren() }) do
                refreshNode(child, depth + 1)
            end
        end
    end

    refreshNode(root, 0)
end

local function GetButtonFontString(button)
    if not button then
        return nil
    end

    return button.Text
        or button.Label
        or (button.GetFontString and button:GetFontString())
        or nil
end

local function ForceReadableLFGButton(button, size, fallbackText)
    if not button then
        return
    end

    local fs = GetButtonFontString(button)
    if not fs then
        return
    end

    local text = fs.GetText and fs:GetText() or nil
    if (text == nil or text == "") and fallbackText and fs.SetText then
        fs:SetText(fallbackText)
    end

    FixReadableLFGFont(fs, size or 14, false)

    if not button._ktReadableButtonHooked and button.HookScript then
        local function refresh()
            local buttonText = fs.GetText and fs:GetText() or nil
            if (buttonText == nil or buttonText == "") and fallbackText and fs.SetText then
                fs:SetText(fallbackText)
            end
            FixReadableLFGFont(fs, size or 14, false)
        end

        button:HookScript("OnShow", refresh)
        button:HookScript("OnEnable", refresh)
        button:HookScript("OnDisable", refresh)
        button._ktReadableButtonHooked = true
    end
end

local function PreserveLFGActionButton(button, size, fallbackText)
    if not button then
        return
    end

    StyleButtonFont(button, size)
    ForceReadableLFGButton(button, size, fallbackText)

    local parent = button.GetParent and button:GetParent() or nil
    if parent and parent.GetFrameLevel and button.SetFrameLevel then
        button:SetFrameLevel(parent:GetFrameLevel() + 5)
    end

    if button.Left then button.Left:Show() end
    if button.Middle then button.Middle:Show() end
    if button.Right then button.Right:Show() end
    if button.LeftDisabled then button.LeftDisabled:Show() end
    if button.MiddleDisabled then button.MiddleDisabled:Show() end
    if button.RightDisabled then button.RightDisabled:Show() end
end
local function SkinSecureLFGReadableText()
    if not (S.db.enable and S.db.lfg) then return end

    EnsureWindowAccentBorder(_G.PVEFrame)
    -- Only clear the outer shell's artwork; leave secure LFG controls alone.
    if _G.PVEFrame then S:FadeRegions(_G.PVEFrame) end
    if S.ApplyKuiSurface then
        S:ApplyKuiSurface(_G.PVEFrame)
    end

    local dialog = _G.LFGListApplicationDialog
    if dialog and not dialog._ktReadableTextHooked then
        local function refreshDialog()
            RefreshLFGReadableText(dialog)
            ForceReadableLFGButton(dialog.SignUpButton, 14, _G.SIGN_UP or "Sign Up")
            ForceReadableLFGButton(dialog.CancelButton, 14, _G.CANCEL or "Cancel")
        end

        if dialog.HookScript then
            dialog:HookScript("OnShow", function(self)
                refreshDialog()
                C_Timer.After(0, function()
                    if self and self.IsShown and self:IsShown() then
                        refreshDialog()
                    end
                end)
                C_Timer.After(0.05, function()
                    if self and self.IsShown and self:IsShown() then
                        refreshDialog()
                    end
                end)
            end)
        end

        dialog._ktReadableTextHooked = true
        refreshDialog()
    end
end

-- =============================================================
-- SKIN LFG
-- =============================================================
local function DarkenNativeArtwork(texture, alpha, preserveHidden)
    if not texture or not texture.IsObjectType or not texture:IsObjectType("Texture") then return end
    if S:IsKuiSurfaceRegion(texture) then return end
    if texture.IsForbidden and texture:IsForbidden() then return end
    if texture._ktKeepSelectionColor or texture._ktKuiPopupArt then return end

    if preserveHidden and texture.IsShown and not texture:IsShown() then return end
    if not preserveHidden then texture:Show() end
    texture:SetDesaturated(false)
    texture:SetVertexColor(0.42, 0.42, 0.46, 1)
    texture:SetAlpha(alpha or 0.12)
end

local function DarkenLargeNativeArtwork(frame, depth)
    if not frame or not frame.GetRegions or (frame.IsForbidden and frame:IsForbidden()) then return end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local width, height = region:GetSize()
            local hasArtwork = (region.GetTexture and region:GetTexture()) or (region.GetAtlas and region:GetAtlas())
            if hasArtwork and (width or 0) >= 88 and (height or 0) >= 36 then
                DarkenNativeArtwork(region, 0.12, true)
            end
        end
    end

    if (depth or 0) <= 0 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        DarkenLargeNativeArtwork(child, depth - 1)
    end
end

local function RefreshLFGNativeArtwork()
    DarkenNativeArtwork(_G.PVEFrameBg, 0.12)
    DarkenNativeArtwork(_G.LFDQueueFrameBackground, 0.14)
    DarkenLargeNativeArtwork(_G.LFDQueueFrame, 3)
    DarkenLargeNativeArtwork(_G.RaidFinderQueueFrame, 3)
    DarkenLargeNativeArtwork(_G.PVPQueueFrame, 3)
    DarkenNativeArtwork(_G.HonorFrame and _G.HonorFrame.WorldBattlesTexture, 0.14)
    DarkenNativeArtwork(_G.ConquestFrame and _G.ConquestFrame.RatedBGTexture, 0.14)
end

local function KeepLFGBackdropBehindContent(frame)
    if not (frame and frame.backdrop and frame.GetFrameLevel) then return end

    -- CreateBackdrop historically clamps its child to level 1. These proposal
    -- frames can also be level 1, making the newly-created opaque child render
    -- over direct role/member regions. Guarantee a full frame-level gap.
    local frameLevel = frame:GetFrameLevel() or 0
    if frameLevel < 2 and frame.SetFrameLevel then
        frame:SetFrameLevel(2)
        frameLevel = 2
    end
    frame.backdrop:SetFrameLevel(frameLevel - 1)
    if frame.backdrop.EnableMouse then frame.backdrop:EnableMouse(false) end
end

local function SkinLFG()
    if not (S.db.enable and S.db.lfg) then return end

    local secureLFGSafeMode = IsSecureLFGSafeMode()
    if secureLFGSafeMode then return end
    local PVEFrame = _G.PVEFrame
    S:HandlePortraitFrame(PVEFrame)
    
    if _G.PVEFrameLeftInset then
        S:StripTextures(_G.PVEFrameLeftInset)
        S:ContentShade(_G.PVEFrameLeftInset)
    end

    if _G.PVEFrameCloseButton then
        S:HandleCloseButton(_G.PVEFrameCloseButton)
        _G.PVEFrameCloseButton:SetFrameLevel(PVEFrame:GetFrameLevel() + 5)
    end

    DarkenNativeArtwork(_G.PVEFrameBg, 0.12)
    if PVEFrame.shadows then S:Kill(PVEFrame.shadows) end

    S:HandleButton(_G.LFDQueueFramePartyBackfillBackfillButton)
    StyleButtonFont(_G.LFDQueueFramePartyBackfillBackfillButton)
    S:HandleButton(_G.LFDQueueFramePartyBackfillNoBackfillButton)
    StyleButtonFont(_G.LFDQueueFramePartyBackfillNoBackfillButton)

    if _G.LFGDungeonReadyStatus then
        -- Keep the role/member status textures. They are direct regions of
        -- this frame on current Retail builds, so StripTextures() turns the
        -- ready-status view into an empty black block.
        if _G.LFGDungeonReadyStatus.NineSlice then
            S:StripTextures(_G.LFGDungeonReadyStatus.NineSlice)
        end
        S:CreateBackdrop(_G.LFGDungeonReadyStatus)
        KeepLFGBackdropBehindContent(_G.LFGDungeonReadyStatus)
        if _G.LFGDungeonReadyStatus.backdrop then
            _G.LFGDungeonReadyStatus.backdrop:SetBackdropColor(0.02, 0.02, 0.025, 1)
            local accent = S:GetAccentColor()
            local ar, ag, ab = accent[1] or 1, accent[2] or 0, accent[3] or 0.333
            _G.LFGDungeonReadyStatus.backdrop:SetBackdropBorderColor(ar, ag, ab, 0.90)
            S:RegisterBlizzardAccentRefresh(_G.LFGDungeonReadyStatus.backdrop, function(backdrop, color)
                backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 0.90)
            end)
        end
        if _G.LFGDungeonReadyStatus.SetBackdrop then
            _G.LFGDungeonReadyStatus:SetBackdrop(nil)
        end
    end

    S:HandleCloseButton(_G.LFGDungeonReadyDialogCloseButton)
    if _G.LFGDungeonReadyDialog then
        EnsureWindowAccentBorder(_G.LFGDungeonReadyDialog)
        -- Preserve the instance artwork shown by dungeon/raid proposals. The
        -- opaque backdrop fills the areas the native artwork does not cover.
        DarkenLargeNativeArtwork(_G.LFGDungeonReadyDialog, 4)
        S:CreateBackdrop(_G.LFGDungeonReadyDialog)
        KeepLFGBackdropBehindContent(_G.LFGDungeonReadyDialog)
        if _G.LFGDungeonReadyDialog.backdrop then
            _G.LFGDungeonReadyDialog.backdrop:SetBackdropColor(0.02, 0.02, 0.025, 1)
        end
        if _G.LFGDungeonReadyDialog.SetBackdrop then
            _G.LFGDungeonReadyDialog:SetBackdrop(nil)
        end
        S:HandleButton(_G.LFGDungeonReadyDialogEnterDungeonButton)
        StyleButtonFont(_G.LFGDungeonReadyDialogEnterDungeonButton, 14)
        S:HandleButton(_G.LFGDungeonReadyDialogLeaveQueueButton)
        StyleButtonFont(_G.LFGDungeonReadyDialogLeaveQueueButton, 14)
        if _G.LFGDungeonReadyDialog.label then SetAvantGarde(_G.LFGDungeonReadyDialog.label, 14) end
    end

    RefreshLFGNativeArtwork()

    RefreshLFGReadableText(_G.LFDQueueFrameRandomScrollFrameChildFrame)
    RefreshLFGReadableText(PVEFrame)
    if _G.LFDQueueFrame and not _G.LFDQueueFrame._ktReadableTextHooked then
        _G.LFDQueueFrame:HookScript("OnShow", function(self)
            RefreshLFGReadableText(_G.LFDQueueFrameRandomScrollFrameChildFrame)
            RefreshLFGReadableText(self)
            RefreshLFGReadableText(PVEFrame)
            C_Timer.After(0, RefreshLFGNativeArtwork)
        end)
        _G.LFDQueueFrame._ktReadableTextHooked = true
    end

    if PVEFrame and not PVEFrame._ktReadableTextHooked then
        PVEFrame:HookScript("OnShow", function(self)
            RefreshLFGReadableText(self)
            if self.LFGListFrame then RefreshLFGReadableText(self.LFGListFrame) end
        end)
        PVEFrame._ktReadableTextHooked = true
    end
    
    EnsureTextureVisible(_G.LFDQueueFrameRoleButtonTankIncentiveIcon, "OVERLAY")
    EnsureTextureVisible(_G.LFDQueueFrameRoleButtonHealerIncentiveIcon, "OVERLAY")
    EnsureTextureVisible(_G.LFDQueueFrameRoleButtonDPSIncentiveIcon, "OVERLAY")
    
    if _G.LFDQueueFrameRoleButtonTank and _G.LFDQueueFrameRoleButtonTank.shortageBorder then S:Kill(_G.LFDQueueFrameRoleButtonTank.shortageBorder) end
    if _G.LFDQueueFrameRoleButtonDPS and _G.LFDQueueFrameRoleButtonDPS.shortageBorder then S:Kill(_G.LFDQueueFrameRoleButtonDPS.shortageBorder) end
    if _G.LFDQueueFrameRoleButtonHealer and _G.LFDQueueFrameRoleButtonHealer.shortageBorder then S:Kill(_G.LFDQueueFrameRoleButtonHealer.shortageBorder) end

    S:HandleButton(_G.LFGDungeonReadyStatusCloseButton)

    if _G.RolePollPopup then
        local roleIcon = _G.RolePollPopup.RoleIcon
        S:StripTextures(_G.RolePollPopup)
        if roleIcon then roleIcon:SetAlpha(1) end
        S:CreateBackdrop(_G.RolePollPopup)
        S:HandleButton(_G.RolePollPopupAcceptButton)
        StyleButtonFont(_G.RolePollPopupAcceptButton)
        S:HandleButton(_G.RolePollPopupCloseButton)
        StyleButtonFont(_G.RolePollPopupCloseButton)
    end

    local roleButtons = {
        { _G.LFDQueueFrameRoleButtonHealer,              "HEALER"  },
        { _G.LFDQueueFrameRoleButtonDPS,                 "DAMAGER" },
        { _G.LFDQueueFrameRoleButtonLeader,              "LEADER"  },
        { _G.LFDQueueFrameRoleButtonTank,                "TANK"    },
        { _G.RaidFinderQueueFrameRoleButtonHealer,       "HEALER"  },
        { _G.RaidFinderQueueFrameRoleButtonDPS,          "DAMAGER" },
        { _G.RaidFinderQueueFrameRoleButtonLeader,       "LEADER"  },
        { _G.RaidFinderQueueFrameRoleButtonTank,         "TANK"    },
        { _G.LFGInvitePopupRoleButtonTank,               "TANK"    },
        { _G.LFGInvitePopupRoleButtonHealer,             "HEALER"  },
        { _G.LFGInvitePopupRoleButtonDPS,                "DAMAGER" },
        { _G.RolePollPopupRoleButtonTank,                "TANK"    },
        { _G.RolePollPopupRoleButtonHealer,              "HEALER"  },
        { _G.RolePollPopupRoleButtonDPS,                 "DAMAGER" },
    }

    if not secureLFGSafeMode and _G.LFGListApplicationDialog then
        roleButtons[#roleButtons + 1] = { _G.LFGListApplicationDialog.TankButton, "TANK" }
        roleButtons[#roleButtons + 1] = { _G.LFGListApplicationDialog.HealerButton, "HEALER" }
        roleButtons[#roleButtons + 1] = { _G.LFGListApplicationDialog.DamagerButton, "DAMAGER" }
    end

    for _, data in pairs(roleButtons) do
        local roleButton, role = data[1], data[2]
        if roleButton then
            local checkButton = roleButton.checkButton or roleButton.CheckButton
            if checkButton then
                checkButton:SetSize(18, 18)
                -- SkinRoleButton handles S:HandleCheckBox + icon setup in correct order
                SkinRoleButton(roleButton, role)
                if checkButton.backdrop then
                    S:SetInside(checkButton.backdrop, checkButton)
                end
            else
                SkinRoleButton(roleButton, role)
            end
        end
    end

    hooksecurefunc('SetCheckButtonIsRadio', function(button)
        if InCombatLockdown() then return end
        if IsLFGRoleCheckButton(button) then return end
        if button.IsProtected and button:IsProtected() then return end
        if button.IsForbidden and button:IsForbidden() then return end
        if not button.IsSkinned then SkinCheckBoxKT(button) end
    end)

    -- Reposition ApplicationDialog checkbuttons (styling already done in main roleButtons loop)
    if not secureLFGSafeMode and _G.LFGListApplicationDialog then
        local reposButtons = {
            _G.LFGListApplicationDialog.TankButton,
            _G.LFGListApplicationDialog.HealerButton,
            _G.LFGListApplicationDialog.DamagerButton,
        }
        for _, roleButton in ipairs(reposButtons) do
            if roleButton then
                local checkButton = roleButton.CheckButton
                if checkButton then
                    checkButton:ClearAllPoints()
                    checkButton:SetPoint('BOTTOMLEFT', 0, 0)
                end
            end
        end
    end

    hooksecurefunc('LFG_DisableRoleButton', function(button)
        if InCombatLockdown() then return end
        if button.checkButton then
            local isChecked = IsSafeCheckboxChecked(button.checkButton)
            button.checkButton:SetAlpha(0.01)
            button.checkButton:SetEnabled(false)
            if button.KT_RoleCheckBorder then
                button.KT_RoleCheckBorder:SetAlpha(isChecked and 1 or 0.65)
            end
        end
        if button.background then 
            button.background:Show()
            button.background:SetDesaturated(false)
        end
        if button.incentiveIcon then 
            button.incentiveIcon:SetAlpha(0.55)
        end
    end)

    hooksecurefunc('LFG_EnableRoleButton', function(button)
        if InCombatLockdown() then return end
        if button.checkButton then 
            button.checkButton:SetAlpha(0.01)
            button.checkButton:SetEnabled(true)
            if button.KT_RoleCheckBorder then
                button.KT_RoleCheckBorder:SetAlpha(1)
            end
        end
        if button.background then 
            button.background:Show()
            button.background:SetDesaturated(false)
        end
        if button.incentiveIcon then 
            button.incentiveIcon:SetAlpha(1)
            EnsureTextureVisible(button.incentiveIcon, "OVERLAY") 
        end
    end)

    hooksecurefunc('LFG_PermanentlyDisableRoleButton', function(button)
        if InCombatLockdown() then return end
        if button.checkButton then
            button.checkButton:SetAlpha(0.01)
            button.checkButton:SetEnabled(false)
            if button.KT_RoleCheckBorder then
                button.KT_RoleCheckBorder:SetAlpha(0.5)
            end
        end
        if button.background then
            button.background:Show()
            button.background:SetDesaturated(true)
        end
        if button.incentiveIcon then 
            button.incentiveIcon:SetAlpha(0.4)
        end
    end)

    if _G.GroupFinderFrame then
        local function RefreshGroupFinderSelection(selectedButton)
            local accent = S:GetAccentColor()
            local i = 1
            local current = _G.GroupFinderFrame["groupButton"..i]
            while current do
                current.KT_Selected = current == selectedButton
                if current._ktSepTop then current._ktSepTop:SetShown(not current.KT_Selected) end
                if current._ktSepBot then current._ktSepBot:SetShown(not current.KT_Selected) end
                ApplyListSelectionVisual(current, current.KT_Selected)
                i = i + 1
                current = _G.GroupFinderFrame["groupButton"..i]
            end
        end
        S:RegisterBlizzardAccentRefresh(_G.GroupFinderFrame, function(frame)
            RefreshGroupFinderSelection(frame.KT_SelectedGroupButton)
        end)

        local index = 1
        local button = _G.GroupFinderFrame['groupButton'..index]
        while button do
            EnsureCategorySeparators(button)
            if button.ring then button.ring:Hide() end
            DarkenNativeArtwork(button.bg or button.Bg or button.background, 0.72)
            
            if button.SelectedTexture then
                local wasSelected = button.SelectedTexture:IsShown()
                button.SelectedTexture:SetAlpha(0)
                if wasSelected then _G.GroupFinderFrame.KT_SelectedGroupButton = button end
            end

            S:HandleButton(button)
            ApplyListSelectionVisual(button, _G.GroupFinderFrame.KT_SelectedGroupButton == button)

            hooksecurefunc(button, "LockHighlight", function(self)
                _G.GroupFinderFrame.KT_SelectedGroupButton = self
                RefreshGroupFinderSelection(self)
                if self._ktSepTop then self._ktSepTop:Hide() end
                if self._ktSepBot then self._ktSepBot:Hide() end
                if self.backdrop then
                    ApplyListSelectionVisual(self, true)
                end
            end)
            hooksecurefunc(button, "UnlockHighlight", function(self)
                if self.backdrop and not self.KT_Selected then
                    if self._ktSepTop then self._ktSepTop:Show() end
                    if self._ktSepBot then self._ktSepBot:Show() end
                    ApplyListSelectionVisual(self, false)
                end
            end)
            button:HookScript("OnClick", function(self)
                _G.GroupFinderFrame.KT_SelectedGroupButton = self
                RefreshGroupFinderSelection(self)
            end)

            for i = 1, button:GetNumRegions() do
                local region = select(i, button:GetRegions())
                if region:IsObjectType("MaskTexture") then region:Hide() end
            end

            local texture = groupButtonIcons[index]
            if texture and button.icon then button.icon:SetTexture(texture) end
            if button.Name then
                SetAvantGarde(button.Name, 14, "OUTLINE")
                button.Name:SetTextColor(1, 1, 1, 1)
            end

            if button.icon then
                S:HandleIcon(button.icon, true)
                button.icon:SetSize(45, 45)
                if button.icon.backdrop then
                    button.icon.backdrop:ClearAllPoints()
                    button.icon.backdrop:SetPoint("LEFT", button, "LEFT", 10, 0)
                    button.icon.backdrop:SetSize(45, 45)
                    S:SetInside(button.icon, button.icon.backdrop)
                else
                    button.icon:ClearAllPoints()
                    button.icon:SetPoint("LEFT", button, "LEFT", 10, 0)
                end
                button.icon:Show()
                button.icon:SetAlpha(1)
            end

            index = index + 1
            button = _G.GroupFinderFrame['groupButton'..index]
        end
    end

    for i = 1, 4 do
        local tab = _G['PVEFrameTab'..i]
        if tab then
            S:HandleTab(tab)
            if tab.Text then SetAvantGarde(tab.Text, 12) end
        end
    end

    S:HandleButton(_G.LFDQueueFrameFindGroupButton)
    StyleButtonFont(_G.LFDQueueFrameFindGroupButton, 14)
    KeepAccentButtonBorder(_G.LFDQueueFrameFindGroupButton)
    if _G.LFDQueueFrameRandomScrollFrame and _G.LFDQueueFrameRandomScrollFrame.ScrollBar then
        S:HandleScrollBar(_G.LFDQueueFrameRandomScrollFrame.ScrollBar)
    end

    if _G.LFDParentFrame then S:StripTextures(_G.LFDParentFrame) end
    if _G.LFDParentFrameInset then S:StripTextures(_G.LFDParentFrameInset) end

    HandleGoldIcon('LFDQueueFrameRandomScrollFrameChildFrameMoneyReward')

    hooksecurefunc('LFGDungeonListButton_SetDungeon', function(button)
        if button and button.expandOrCollapseButton and button.expandOrCollapseButton:IsShown() then
            if button.isCollapsed then
                button.expandOrCollapseButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
            else
                button.expandOrCollapseButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
            end
        end
    end)

    if _G.LFDQueueFrameTypeDropdown then
        S:HandleDropDownBox(_G.LFDQueueFrameTypeDropdown, 200)
    end

    if _G.RaidFinderFrame then S:StripTextures(_G.RaidFinderFrame) end
    if _G.RaidFinderFrameRoleInset then S:StripTextures(_G.RaidFinderFrameRoleInset) end
    DarkenLargeNativeArtwork(_G.RaidFinderQueueFrame, 3)

    if _G.RaidFinderQueueFrameSelectionDropdown then
        S:HandleDropDownBox(_G.RaidFinderQueueFrameSelectionDropdown, 200)
    end

    if _G.RaidFinderQueueFrameScrollFrame and _G.RaidFinderQueueFrameScrollFrame.ScrollBar then
        S:HandleScrollBar(_G.RaidFinderQueueFrameScrollFrame.ScrollBar)
    end
    HandleGoldIcon('RaidFinderQueueFrameScrollFrameChildFrameMoneyReward')
    RefreshLFGReadableText(_G.RaidFinderQueueFrameScrollFrameChildFrame)
    if _G.RaidFinderQueueFrame and not _G.RaidFinderQueueFrame._ktReadableTextHooked then
        _G.RaidFinderQueueFrame:HookScript("OnShow", function(self)
            RefreshLFGReadableText(_G.RaidFinderQueueFrameScrollFrameChildFrame)
            RefreshLFGReadableText(self)
        end)
        _G.RaidFinderQueueFrame._ktReadableTextHooked = true
    end

    if _G.RaidFinderFrameFindRaidButton then
        S:StripTextures(_G.RaidFinderFrameFindRaidButton)
        S:HandleButton(_G.RaidFinderFrameFindRaidButton)
        StyleButtonFont(_G.RaidFinderFrameFindRaidButton, 14)
        KeepAccentButtonBorder(_G.RaidFinderFrameFindRaidButton)
    end

    hooksecurefunc('LFGRewardsFrame_SetItemButton', SkinItemButton)

    if _G.LFGInvitePopup then
        S:StripTextures(_G.LFGInvitePopup)
        RestoreLFGInviteRoleIcon(_G.LFGInvitePopup)
        if not _G.LFGInvitePopup._ktRoleIconHooked then
            _G.LFGInvitePopup:HookScript("OnShow", function(self)
                RestoreLFGInviteRoleIcon(self)
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() RestoreLFGInviteRoleIcon(self) end)
                end
            end)
            _G.LFGInvitePopup._ktRoleIconHooked = true
        end
        S:CreateBackdrop(_G.LFGInvitePopup, true)
        S:HandleButton(_G.LFGInvitePopupAcceptButton)
        StyleButtonFont(_G.LFGInvitePopupAcceptButton)
        S:HandleButton(_G.LFGInvitePopupDeclineButton)
        StyleButtonFont(_G.LFGInvitePopupDeclineButton)
    end

    if _G.LFDQueueFrameSpecific and _G.LFDQueueFrameSpecific.ScrollBox then
        hooksecurefunc(_G.LFDQueueFrameSpecific.ScrollBox, 'Update', LFDQueueFrameSpecificUpdate)
    end

    local LFGListFrame = _G.LFGListFrame
    if secureLFGSafeMode and LFGListFrame then
        -- Retail 12.x uses secret values throughout the modern premade-group
        -- browser and applicant viewer. Touching any part of the LFGList tree
        -- can taint Blizzard's applicant sorting / viewer updates, so leave
        -- the whole subtree unskinned there.
        return
    end
    if LFGListFrame and not secureLFGSafeMode then
        if LFGListFrame.CategorySelection and LFGListFrame.CategorySelection.Inset then
            S:StripTextures(LFGListFrame.CategorySelection.Inset)
        end
        if LFGListFrame.CategorySelection and LFGListFrame.CategorySelection.StartGroupButton then
            PreserveLFGActionButton(LFGListFrame.CategorySelection.StartGroupButton, 14)
            LFGListFrame.CategorySelection.StartGroupButton:ClearAllPoints()
            LFGListFrame.CategorySelection.StartGroupButton:SetPoint('BOTTOMLEFT', -1, 3)
        end
        if LFGListFrame.CategorySelection and LFGListFrame.CategorySelection.FindGroupButton then
            PreserveLFGActionButton(LFGListFrame.CategorySelection.FindGroupButton, 14)
            LFGListFrame.CategorySelection.FindGroupButton:ClearAllPoints()
            LFGListFrame.CategorySelection.FindGroupButton:SetPoint('BOTTOMRIGHT', -6, 3)
        end

        local EntryCreation = LFGListFrame.EntryCreation
        if EntryCreation then
            if EntryCreation.Inset then S:StripTextures(EntryCreation.Inset) end
            PreserveLFGActionButton(EntryCreation.CancelButton, 12, _G.CANCEL or "Cancel")
            PreserveLFGActionButton(EntryCreation.ListGroupButton, 14)
            -- [TAINT FIX] Midnight 12.x: several EntryCreation fields are secret values.
            -- Do not skin any EntryCreation editboxes/checkboxes to avoid tainting
            -- activeEntryInfo fields (name/comment/privateGroup/voiceChat/etc).
            if EntryCreation.GroupDropdown then S:HandleDropDownBox(EntryCreation.GroupDropdown) end
            if EntryCreation.ActivityDropdown then S:HandleDropDownBox(EntryCreation.ActivityDropdown, 120) end
            if EntryCreation.PlayStyleDropdown then S:HandleDropDownBox(EntryCreation.PlayStyleDropdown) end
            if EntryCreation.Label then SetAvantGarde(EntryCreation.Label, 12) end
        end

        if _G.LFGListApplicationDialog then
            S:StripTextures(_G.LFGListApplicationDialog)
            S:CreateBackdrop(_G.LFGListApplicationDialog, true)
            PreserveLFGActionButton(_G.LFGListApplicationDialog.SignUpButton, 14, _G.SIGN_UP or "Sign Up")
            PreserveLFGActionButton(_G.LFGListApplicationDialog.CancelButton, 12, _G.CANCEL or "Cancel")
        end
        -- [TAINT FIX] LFGListApplicationDialogDescription carries secret values in 12.x.
        -- Keep the application dialog description editbox untouched.

        local SearchPanel = LFGListFrame.SearchPanel
        if SearchPanel then
            S:HandleEditBox(SearchPanel.SearchBox)
            PreserveLFGActionButton(SearchPanel.BackButton, 12, _G.BACK or "Back")
            PreserveLFGActionButton(SearchPanel.SignUpButton, 14, _G.SIGN_UP or "Sign Up")
            if SearchPanel.ResultsInset then S:StripTextures(SearchPanel.ResultsInset) end
            if SearchPanel.ScrollBar then S:HandleScrollBar(SearchPanel.ScrollBar) end
            if SearchPanel.FilterButton then
                S:HandleButton(SearchPanel.FilterButton)
                StyleButtonFont(SearchPanel.FilterButton)
                if SearchPanel.FilterButton.ResetButton then
                    S:HandleCloseButton(SearchPanel.FilterButton.ResetButton)
                end
            end
            if SearchPanel.RefreshButton then
                S:HandleButton(SearchPanel.RefreshButton)
                if SearchPanel.RefreshButton.Icon then
                    SearchPanel.RefreshButton.Icon:SetAlpha(1)
                    SearchPanel.RefreshButton.Icon:SetDrawLayer("OVERLAY")
                end
            end
            PreserveLFGActionButton(SearchPanel.BackToGroupButton, 12)
            -- Search results, autocomplete, and their tooltips now carry
            -- secret values in current retail builds. Leave those dynamic
            -- widgets visually untouched to avoid tainting Blizzard's search UI.
        end

        local ApplicationViewer = LFGListFrame.ApplicationViewer
        if ApplicationViewer then
            -- TAINT FIX: applicant viewer info is backed by secret values on
            -- current retail. Leave the whole viewer completely untouched.
        end
        hooksecurefunc('LFGListCategorySelection_AddButton', function(btn, btnIndex, categoryID, filters)
            local button = btn.CategoryButtons[btnIndex]
            if button then
                if not button.IsSkinned then
                    S:CreateBackdrop(button)
                    if button.backdrop then
                        button.backdrop:ClearAllPoints()
                        button.backdrop:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
                        button.backdrop:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
                        button.backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.72)
                        button.backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
                    end
                    if button.Icon then
                        button.Icon:SetDrawLayer('ARTWORK', 5)
                        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        if button.backdrop then S:SetInside(button.Icon, button.backdrop) end
                    end
                    if button.Cover and button.Cover.SetAlpha then button.Cover:SetAlpha(0) end
                    if button.HighlightTexture then
                        button.HighlightTexture:SetColorTexture(1, 1, 1, 0.06)
                        if button.backdrop then S:SetInside(button.HighlightTexture, button.backdrop) end
                    end
                    if button.Label then
                        SetAvantGarde(button.Label, 14, "OUTLINE")
                        button.Label:SetTextColor(1, 1, 1, 1)
                    end
                    button.IsSkinned = true
                end
                if button.SelectedTexture then
                    button.SelectedTexture:SetAlpha(0)
                    if button.SelectedTexture.Hide then button.SelectedTexture:Hide() end
                end
                local selected = btn.selectedCategory == categoryID and btn.selectedFilters == filters
                ApplyListSelectionVisual(button, selected)
            end
        end)
    end
end

-- =============================================================
-- SKIN CHALLENGES
-- =============================================================
local function SkinChallenges()
    if not (S.db.enable and S.db.lfg) then return end

    local ChallengesFrame = _G.ChallengesFrame
    if not ChallengesFrame then return end
    if _G.ChallengesFrameInset then S:StripTextures(_G.ChallengesFrameInset) end

    local function FixAffixTexture(self)
        if self.Portrait then
            self.Portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            if self.Border then self.Border:Hide() end
            if self.Percent then SetAvantGarde(self.Percent, 14, "OUTLINE") end
            for i = 1, self:GetNumRegions() do
                local region = select(i, self:GetRegions())
                if region:IsObjectType("MaskTexture") then region:Hide() end
            end
            S:HandleIcon(self.Portrait, true)
        end
    end

    local KeyStoneFrame = _G.ChallengesKeystoneFrame
    if KeyStoneFrame then
        S:CreateBackdrop(KeyStoneFrame, true)
        S:HandleButton(KeyStoneFrame.StartButton)
        S:HandleButton(KeyStoneFrame.CloseButton)
        if KeyStoneFrame.DungeonName then SetAvantGarde(KeyStoneFrame.DungeonName, 22, "OUTLINE") end
        if KeyStoneFrame.TimeLimit then SetAvantGarde(KeyStoneFrame.TimeLimit, 14, "OUTLINE") end
        if KeyStoneFrame.RunInfo and KeyStoneFrame.RunInfo.Level then SetAvantGarde(KeyStoneFrame.RunInfo.Level, 24, "OUTLINE") end
        if KeyStoneFrame.KeystoneSlot and KeyStoneFrame.KeystoneSlot.Texture then
            S:HandleIcon(KeyStoneFrame.KeystoneSlot.Texture, true)
        end
        if not KeyStoneFrame.KeystoneSlot.LevelText then
            KeyStoneFrame.KeystoneSlot.LevelText = KeyStoneFrame.KeystoneSlot:CreateFontString(nil, "OVERLAY")
            SetAvantGarde(KeyStoneFrame.KeystoneSlot.LevelText, 26, "OUTLINE")
            KeyStoneFrame.KeystoneSlot.LevelText:SetPoint("CENTER", 0, 5)
            KeyStoneFrame.KeystoneSlot.LevelText:SetTextColor(1, 1, 1)
        end
        if not KeyStoneFrame.KeystoneSlot.TimeText then
            KeyStoneFrame.KeystoneSlot.TimeText = KeyStoneFrame.KeystoneSlot:CreateFontString(nil, "OVERLAY")
            SetAvantGarde(KeyStoneFrame.KeystoneSlot.TimeText, 14, "OUTLINE")
            KeyStoneFrame.KeystoneSlot.TimeText:SetPoint("TOP", KeyStoneFrame.KeystoneSlot.LevelText, "BOTTOM", 0, -2)
            KeyStoneFrame.KeystoneSlot.TimeText:SetTextColor(1, 0.8, 0)
        end
        hooksecurefunc(KeyStoneFrame, 'OnKeystoneSlotted', function(self)
            local MapID, _, PowerLevel = C_ChallengeMode_GetSlottedKeystoneInfo()
            if MapID then
                local Name, _, timeLimit = C_ChallengeMode_GetMapUIInfo(MapID)
                if Name and PowerLevel then
                    self.DungeonName:SetText(Name..' |cffffffff-|r ('..PowerLevel..')')
                end
                if PowerLevel then self.KeystoneSlot.LevelText:SetText("+"..PowerLevel) end
                if timeLimit then
                    local mins = math_floor(timeLimit / 60)
                    local secs = timeLimit % 60
                    self.KeystoneSlot.TimeText:SetText(string_format("%d:%02d", mins, secs))
                end
            end
            if self.Affixes then
                for _, frame in ipairs(self.Affixes) do FixAffixTexture(frame) end
            end
        end)
        hooksecurefunc(KeyStoneFrame, 'Reset', function(self)
            if self.KeystoneSlot.LevelText then self.KeystoneSlot.LevelText:SetText("") end
            if self.KeystoneSlot.TimeText then self.KeystoneSlot.TimeText:SetText("") end
        end)
    end

    hooksecurefunc(ChallengesFrame, 'Update', function(frame)
        for _, child in ipairs(frame.DungeonIcons or {}) do
            if not child.backdrop then
                S:CreateBackdrop(child)
            end
            if child.backdrop then
                child.backdrop:SetPoint("TOPLEFT", 1, -1)
                child.backdrop:SetPoint("BOTTOMRIGHT", -1, 1)
                child.backdrop:SetBackdropColor(unpack(COLOR_BG))
            end

            if not child.isSkinned then
                for i = 1, child:GetNumRegions() do
                    local region = select(i, child:GetRegions())
                    if region and region.IsObjectType and region:IsObjectType("Texture") then
                        local texture = region:GetTexture()
                        if texture and type(texture) == "string" and
                           (string.find(texture, "Border") or string.find(texture, "Background")) then
                            region:SetAlpha(0)
                        elseif child.backdrop then
                            region:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                            region:SetDrawLayer("BORDER", 1)
                            S:SetInside(region, child.backdrop)
                        end
                    end
                end
                if child.Icon then
                    S:HandleIcon(child.Icon, true)
                end
                if child.Score then
                    child.Score:SetTextColor(1, 1, 1)
                end
                if child.Level then
                    child.Level:SetTextColor(1, 0.8, 0)
                end
                child.isSkinned = true
            end
        end
    end)    ChallengesFrame:HookScript("OnShow", UpdateTeleportButtons)
    local f = CreateFrame("Frame")
    f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    f:SetScript("OnEvent", UpdateTeleportCooldowns)
end

-- =============================================================
-- SKIN PVP
-- =============================================================
local function SkinPVP()
    if not (S.db.enable and S.db.lfg) then return end

    local PVPQueueFrame = _G.PVPQueueFrame
    if not PVPQueueFrame then return end

    EnsureWindowAccentBorder(_G.PVEFrame)
    AddRoleFeedbackInTree(PVPQueueFrame, 0)

    DarkenLargeNativeArtwork(PVPQueueFrame, 3)
    DarkenLargeNativeArtwork(PVPQueueFrame.HonorInset, 2)

    local function RefreshReadableTexts(root)
        if not root then return end

        for _, region in ipairs({ root:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                local text = region.GetText and region:GetText()
                if text and text ~= "" then
                    SetAvantGarde(region, 14, "OUTLINE")
                    local lower = text:lower()
                    if lower:find("season", 1, true) or lower:find("reward", 1, true) or lower:find("conquest", 1, true) then
                        region:SetTextColor(1, 0.82, 0.10, 1)
                    elseif lower:find("new", 1, true) or lower:find("player vs", 1, true) then
                        region:SetTextColor(1, 1, 1, 1)
                    else
                        region:SetTextColor(1, 1, 1, 1)
                    end
                end
            end
        end
    end

    local function RefreshPVPCategorySelection(selectedButton)
        if selectedButton then
            PVPQueueFrame.KT_SelectedCategoryButton = selectedButton
        end
        local selected = PVPQueueFrame.KT_SelectedCategoryButton
        local i = 1
        local category = PVPQueueFrame["CategoryButton"..i]
        while category do
            category.KT_Selected = category == selected
            ApplyListSelectionVisual(category, category.KT_Selected)
            i = i + 1
            category = PVPQueueFrame["CategoryButton"..i]
        end
    end

    local function SkinCategoryButton(button)
        if not button then return end
        if button._ktPVPCategorySkinned then
            ApplyListSelectionVisual(button, button.KT_Selected)
            return
        end

        EnsureCategorySeparators(button)
        if button.Ring then button.Ring:Hide() end
        DarkenNativeArtwork(button.bg or button.Bg or button.background, 0.72)

        local selectedTexture = button.SelectedTexture or button.selectedTexture
        if selectedTexture then
            if IsNativeSelectionShown(button) then
                PVPQueueFrame.KT_SelectedCategoryButton = button
            end
            selectedTexture:SetAlpha(0)
            selectedTexture._ktKeepSelectionColor = true
            if type(selectedTexture.Show) == "function" then
                hooksecurefunc(selectedTexture, "Show", function()
                    C_Timer.After(0, function() RefreshPVPCategorySelection(button) end)
                end)
            end
        end

        S:HandleButton(button)
        ApplyListSelectionVisual(button, PVPQueueFrame.KT_SelectedCategoryButton == button)

        hooksecurefunc(button, "LockHighlight", function(self)
            RefreshPVPCategorySelection(self)
        end)
        hooksecurefunc(button, "UnlockHighlight", function(self)
            if not self.KT_Selected then ApplyListSelectionVisual(self, false) end
        end)
        button:HookScript("OnClick", function(self)
            C_Timer.After(0, function() RefreshPVPCategorySelection(self) end)
        end)
        button:HookScript("OnShow", function(self)
            C_Timer.After(0, function()
                if IsNativeSelectionShown(self) then
                    RefreshPVPCategorySelection(self)
                else
                    RefreshPVPCategorySelection()
                end
            end)
        end)

        if button.Name then
            SetAvantGarde(button.Name, 14, "OUTLINE")
            button.Name:SetTextColor(1, 1, 1, 1)
        end

        if button.Icon then
            button.Icon:SetSize(40, 40)
            button.Icon:ClearAllPoints()
            button.Icon:SetPoint("LEFT", 10, 0)
            S:HandleIcon(button.Icon, true)
            button.Icon:Show()
            button.Icon:SetAlpha(1)
        end

        button._ktPVPCategorySkinned = true
    end

    local categoryIndex = 1
    local categoryButton = PVPQueueFrame["CategoryButton"..categoryIndex]
    while categoryButton do
        SkinCategoryButton(categoryButton)
        categoryIndex = categoryIndex + 1
        categoryButton = PVPQueueFrame["CategoryButton"..categoryIndex]
    end
    RefreshPVPCategorySelection(PVPQueueFrame.KT_SelectedCategoryButton)

    local HonorFrame = _G.HonorFrame
    if HonorFrame then
        AddRoleFeedbackInTree(HonorFrame, 0)
        SkinPVPRoleList(HonorFrame.RoleList)
        if HonorFrame.BonusFrame then
            SkinPVPActivityGroup({
                HonorFrame.BonusFrame.RandomBGButton,
                HonorFrame.BonusFrame.RandomEpicBGButton,
                HonorFrame.BonusFrame.Arena1Button,
                HonorFrame.BonusFrame.BrawlButton,
                HonorFrame.BonusFrame.BrawlButton2,
            })
        end
        DarkenLargeNativeArtwork(HonorFrame.Inset, 2)
        DarkenNativeArtwork(HonorFrame.WorldBattlesTexture, 0.72)
        if HonorFrame.HonorBar then
            S:StripTextures(HonorFrame.HonorBar)
            S:CreateBackdrop(HonorFrame.HonorBar)
            S:HandleStatusBar(HonorFrame.HonorBar)
        end
        if HonorFrame.QueueButton then
            S:HandleButton(HonorFrame.QueueButton)
            if HonorFrame.QueueButton.Text then SetAvantGarde(HonorFrame.QueueButton.Text, 14, "OUTLINE") end
            KeepAccentButtonBorder(HonorFrame.QueueButton)
        end
        if HonorFrame.TypeDropdown then 
            S:HandleDropDownBox(HonorFrame.TypeDropdown, 200) 
        end
        if HonorFrame.SpecificScrollBox then S:StripTextures(HonorFrame.SpecificScrollBox) end
        if HonorFrame.LevelLabel then SetAvantGarde(HonorFrame.LevelLabel, 12) end
        if HonorFrame.Level then SetAvantGarde(HonorFrame.Level, 18, "OUTLINE") end
        if HonorFrame.CurrentConquest then SetAvantGarde(HonorFrame.CurrentConquest, 12) end
        RefreshReadableTexts(HonorFrame)
        if not HonorFrame._ktReadableTextHooked and HonorFrame.HookScript then
            HonorFrame:HookScript("OnShow", function(frame)
                RefreshReadableTexts(frame)
                C_Timer.After(0, RefreshLFGNativeArtwork)
            end)
            HonorFrame._ktReadableTextHooked = true
        end
    end

    local ConquestFrame = _G.ConquestFrame
    if ConquestFrame then
        SkinPVPRoleList(ConquestFrame.RoleList)
        SkinPVPActivityGroup({
            ConquestFrame.RatedSoloShuffle,
            ConquestFrame.RatedBGBlitz,
            ConquestFrame.Arena2v2,
            ConquestFrame.Arena3v3,
            ConquestFrame.RatedBG,
        })
        DarkenLargeNativeArtwork(ConquestFrame.Inset, 2)
        DarkenNativeArtwork(ConquestFrame.RatedBGTexture, 0.72)
        if ConquestFrame.JoinButton then
            S:HandleButton(ConquestFrame.JoinButton)
            if ConquestFrame.JoinButton.Text then SetAvantGarde(ConquestFrame.JoinButton.Text, 14, "OUTLINE") end
            KeepAccentButtonBorder(ConquestFrame.JoinButton)
        end
        RefreshReadableTexts(ConquestFrame)
        if not ConquestFrame._ktReadableTextHooked and ConquestFrame.HookScript then
            ConquestFrame:HookScript("OnShow", function(frame)
                RefreshReadableTexts(frame)
                C_Timer.After(0, RefreshLFGNativeArtwork)
            end)
            ConquestFrame._ktReadableTextHooked = true
        end
    end

    local TrainingGroundFrame = _G.TrainingGroundsFrame
    if TrainingGroundFrame then
        SkinPVPRoleList(TrainingGroundFrame.RoleList)
        local bonusTraining = TrainingGroundFrame.BonusTrainingGroundList
        if bonusTraining then
            SkinPVPActivityGroup({ bonusTraining.RandomTrainingGroundButton })
        end
    end
end

S.SkinFuncs["Blizzard_ChallengesUI"] = SkinChallenges
S.SkinFuncs["Blizzard_PVPUI"] = SkinPVP
if not IsSecureLFGSafeMode() then
    S.SkinFuncs["Blizzard_GroupFinder"] = SkinLFG
else
    -- Retail safe mode: only repair readable text on the application dialog.
    -- Avoid full skinning of protected Group Finder frames to prevent taint.
    S.SkinFuncs["Blizzard_GroupFinder"] = SkinSecureLFGReadableText
end
