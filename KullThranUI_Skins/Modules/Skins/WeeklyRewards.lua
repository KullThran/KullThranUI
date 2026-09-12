local KT = LibStub('AceAddon-3.0'):GetAddon('KullThranUI')
local S = KT:GetModule('Skins')
local _G = _G
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local math_max = math.max

local function SetTextureDesaturation(texture, amount)
    if not texture then return end
    amount = tonumber(amount) or 0
    if texture.SetDesaturation then
        pcall(texture.SetDesaturation, texture, amount)
    elseif texture.SetDesaturated then
        pcall(texture.SetDesaturated, texture, amount >= 0.5)
    end
end

local function SetArtworkTexture(texture, alpha, brightness, desaturation)
    if not texture then return end
    SetTextureDesaturation(texture, desaturation)
    if brightness and texture.SetVertexColor then
        texture:SetVertexColor(brightness, brightness, brightness, 1)
    end
    if texture.SetAlpha then
        texture:SetAlpha(alpha)
    end
end

local function SetMutedTexture(texture, alpha, brightness)
    SetArtworkTexture(texture, alpha, brightness, 1)
end

local function AnchorInset(texture, owner, inset)
    inset = inset or 0
    texture:ClearAllPoints()
    texture:SetPoint('TOPLEFT', owner, 'TOPLEFT', inset, -inset)
    texture:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -inset, inset)
end

-- Warm native artwork with a restrained highlight gives the cards the same
-- polished wood character as EllesmereUI without importing any external art.
local function ApplyWoodSatin(frame, options)
    if not (frame and frame.CreateTexture) then return end
    options = options or {}

    local data = S:GetFFD(frame)
    if not data.greatVaultWood then
        local wood = frame:CreateTexture(nil, 'BACKGROUND', nil, -7)
        local atlasApplied = wood.SetAtlas
            and pcall(wood.SetAtlas, wood, 'characterupdate_background')
        if not atlasApplied then
            wood:SetTexture('Interface\\Buttons\\WHITE8x8')
        end
        data.greatVaultWood = wood

        local warmth = frame:CreateTexture(nil, 'BACKGROUND', nil, -6)
        warmth:SetTexture('Interface\\Buttons\\WHITE8x8')
        data.greatVaultWarmth = warmth

        local sheen = frame:CreateTexture(nil, 'BORDER', nil, -8)
        sheen:SetTexture('Interface\\Buttons\\WHITE8x8')
        data.greatVaultSheen = sheen

        local topEdge = frame:CreateTexture(nil, 'BORDER', nil, -7)
        topEdge:SetTexture('Interface\\Buttons\\WHITE8x8')
        data.greatVaultTopEdge = topEdge
    end

    local inset = options.inset or 0
    local wood = data.greatVaultWood
    AnchorInset(wood, frame, inset)
    wood:SetVertexColor(0.82, 0.61, 0.34, 1)
    wood:SetAlpha(options.woodAlpha or 0.62)
    if options.completed then
        wood:SetTexCoord(0, 1, 0.5, 1)
    else
        wood:SetTexCoord(0, 1, 0, 0.5)
    end
    wood:Show()

    local warmth = data.greatVaultWarmth
    AnchorInset(warmth, frame, inset)
    warmth:SetColorTexture(0.34, 0.16, 0.045, options.warmthAlpha or 0.10)
    warmth:Show()

    local sheen = data.greatVaultSheen
    sheen:ClearAllPoints()
    sheen:SetPoint('TOPLEFT', frame, 'TOPLEFT', inset + 1, -(inset + 1))
    sheen:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -(inset + 1), -(inset + 1))
    sheen:SetHeight(math_max(4, (frame:GetHeight() - (inset * 2)) * 0.34))
    sheen:SetColorTexture(1, 0.79, 0.43, options.sheenAlpha or 0.09)
    sheen:Show()

    local topEdge = data.greatVaultTopEdge
    topEdge:ClearAllPoints()
    topEdge:SetPoint('TOPLEFT', frame, 'TOPLEFT', inset + 1, -(inset + 1))
    topEdge:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -(inset + 1), -(inset + 1))
    topEdge:SetHeight(1)
    topEdge:SetColorTexture(1, 0.76, 0.34, options.edgeAlpha or 0.24)
    topEdge:Show()
end

local function IsActivityCompleted(frame)
    local icon = frame and frame.CompletedIcon
    if not (icon and icon.IsShown) then return false end
    local ok, shown = pcall(icon.IsShown, icon)
    return ok and shown == true
end

local function StyleCategory(frame)
    if not frame then return end
    ApplyWoodSatin(frame, {
        inset = 1,
        woodAlpha = 0.42,
        warmthAlpha = 0.06,
        sheenAlpha = 0.06,
        edgeAlpha = 0.18,
    })
    SetArtworkTexture(frame.Background, 0.56, 0.92, 0.12)
    if frame.Border and frame.Border.SetAlpha then
        frame.Border:SetAlpha(0.88)
    end
    if frame.Name then
        S:HandleFont(frame.Name)
    end
end

local function StyleActivity(frame)
    if not (frame and frame.Threshold) then return end
    local completed = IsActivityCompleted(frame)
    ApplyWoodSatin(frame, {
        inset = 3,
        completed = completed,
        woodAlpha = completed and 0.74 or 0.60,
        warmthAlpha = completed and 0.13 or 0.08,
        sheenAlpha = completed and 0.15 or 0.10,
        edgeAlpha = completed and 0.34 or 0.22,
    })
    -- Retain the Blizzard reward swirl and card illustration above the wood.
    SetArtworkTexture(frame.Background, completed and 0.64 or 0.50, 0.96, 0.04)
    if frame.Border and frame.Border.SetAlpha then
        frame.Border:SetAlpha(0.90)
    end
    if frame.Threshold then S:HandleFont(frame.Threshold) end
    if frame.Progress then S:HandleFont(frame.Progress) end
end

local function StyleOverlay(overlay)
    if not overlay then return end
    ApplyWoodSatin(overlay, {
        inset = 2,
        woodAlpha = 0.46,
        warmthAlpha = 0.09,
        sheenAlpha = 0.08,
        edgeAlpha = 0.22,
    })
    SetArtworkTexture(overlay.Background, 0.30, 0.90, 0.12)
    if overlay.ModelScene and overlay.ModelScene.SetAlpha then
        overlay.ModelScene:SetAlpha(0.38)
    end
    if overlay.NineSlice and overlay.NineSlice.SetAlpha then
        overlay.NineSlice:SetAlpha(0)
    end
    if overlay.Title then S:HandleFont(overlay.Title) end
    if overlay.Text then S:HandleFont(overlay.Text) end
end

local function ApplyGreatVaultStyle(frame)
    if not frame then return end

    -- Preserve the vault scene, then warm the otherwise flat premium backdrop.
    ApplyWoodSatin(frame, {
        inset = 10,
        woodAlpha = 0.26,
        warmthAlpha = 0.05,
        sheenAlpha = 0.045,
        edgeAlpha = 0.14,
    })
    SetArtworkTexture(frame.Background or frame.BackgroundTile, 0.40, 0.92, 0.10)
    if frame.BorderShadow and frame.BorderShadow.SetAlpha then
        frame.BorderShadow:SetAlpha(0)
    end
    SetMutedTexture(frame.Divider1, 0.34, 0.72)
    SetMutedTexture(frame.Divider2, 0.34, 0.72)

    if frame.BorderContainer and frame.BorderContainer.SetAlpha then
        frame.BorderContainer:SetAlpha(0)
    end
    if frame.ModelScene and frame.ModelScene.SetAlpha then
        frame.ModelScene:SetAlpha(0.38)
    end

    if frame.HeaderFrame then
        if frame.HeaderFrame.Text then S:HandleFont(frame.HeaderFrame.Text) end
        SetMutedTexture(frame.HeaderFrame.HeaderDivider, 0.56, 0.82)
    end

    StyleCategory(frame.RaidFrame)
    StyleCategory(frame.MythicFrame)
    StyleCategory(frame.PVPFrame)
    StyleCategory(frame.WorldFrame)

    for _, activity in ipairs(frame.Activities or {}) do
        StyleActivity(activity)
    end

    if frame.SelectRewardButton then
        S:HandleButton(frame.SelectRewardButton)
        ApplyWoodSatin(frame.SelectRewardButton, {
            inset = 2,
            woodAlpha = 0.66,
            warmthAlpha = 0.10,
            sheenAlpha = 0.13,
            edgeAlpha = 0.30,
        })
        if frame.SelectRewardButton.Background then
            SetArtworkTexture(frame.SelectRewardButton.Background, 0.38, 0.96, 0.04)
        end
    end
    if frame.CloseButton then
        S:HandleCloseButton(frame.CloseButton)
    end

    StyleOverlay(frame.Overlay)

    local premiumData = S:GetFFD(frame)
    if premiumData and premiumData.atlasBorderFrame then
        local level = frame:GetFrameLevel() + 10
        if frame.CloseButton and frame.CloseButton.GetFrameLevel then
            level = math_max(level, frame.CloseButton:GetFrameLevel() + 2)
        end
        premiumData.atlasBorderFrame:SetFrameLevel(level)
    end
end

local function SkinWeeklyRewards()
    if not (S.db and S.db.enable and S.db.weeklyrewards ~= false) then return end

    local frame = _G.WeeklyRewardsFrame
    if not frame then return end

    S:SkinPremiumWindow(frame)
    ApplyGreatVaultStyle(frame)

    if not frame._ktGreatVaultSkinHooked then
        frame:HookScript('OnShow', function(self)
            ApplyGreatVaultStyle(self)
        end)

        if _G.WeeklyRewardsMixin and _G.WeeklyRewardsMixin.Refresh then
            hooksecurefunc(_G.WeeklyRewardsMixin, 'Refresh', function(self)
                if self == frame then
                    ApplyGreatVaultStyle(self)
                end
            end)
        end
        frame._ktGreatVaultSkinHooked = true
    end
end

S.SkinFuncs['Blizzard_WeeklyRewards'] = SkinWeeklyRewards
