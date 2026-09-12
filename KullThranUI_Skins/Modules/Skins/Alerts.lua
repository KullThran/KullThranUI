local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame

-- Helper to force Alpha
local function ForceAlpha(frame, alpha)
    if alpha ~= 1 then
        frame:SetAlpha(1)
    end
end

local function SkinAchievementAlert(frame)
    frame:SetAlpha(1)
    if not frame.hooked then
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        frame.hooked = true
    end

    if not frame.backdrop then
        S:CreateBackdrop(frame)
        frame.backdrop:ClearAllPoints()
        if frame.Background then
            frame.backdrop:SetPoint("TOPLEFT", frame.Background, "TOPLEFT", -2, -6)
            frame.backdrop:SetPoint("BOTTOMRIGHT", frame.Background, "BOTTOMRIGHT", -2, 6)
        else
            frame.backdrop:SetAllPoints(frame)
        end
    end

    if frame.Background then frame.Background:SetTexture(nil) end
    if frame.glow then S:Kill(frame.glow) end
    if frame.shine then S:Kill(frame.shine) end
    if frame.GuildBanner then S:Kill(frame.GuildBanner) end
    if frame.GuildBorder then S:Kill(frame.GuildBorder) end

    if frame.Unlocked then
        S:HandleFont(frame.Unlocked)
        frame.Unlocked:SetTextColor(1, 1, 1)
    end
    if frame.Name then
        S:HandleFont(frame.Name)
    end

    local icon = frame.Icon
    if icon then
        if icon.Overlay then S:Kill(icon.Overlay) end
        local texture = icon.Texture
        if texture then
            texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            texture:ClearAllPoints()
            texture:SetPoint("LEFT", frame, 7, 0)
            if not icon.backdrop then
                S:CreateBackdrop(icon)
                icon.backdrop:ClearAllPoints()
                S:SetOutside(icon.backdrop, texture)
            end
        end
    end
end

local function SkinCriteriaAlert(frame)
    frame:SetAlpha(1)
    if not frame.hooked then
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        frame.hooked = true
    end

    if not frame.backdrop then
        S:CreateBackdrop(frame)
        frame.backdrop:ClearAllPoints()
        frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, -6)
        frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 6)
    end

    if frame.Unlocked then frame.Unlocked:SetTextColor(1, 1, 1) end
    if frame.Name then frame.Name:SetTextColor(1, 1, 0) end
    
    if frame.Background then S:Kill(frame.Background) end
    if frame.glow then S:Kill(frame.glow) end
    if frame.shine then S:Kill(frame.shine) end
    
    if frame.Icon then
        if frame.Icon.Bling then S:Kill(frame.Icon.Bling) end
        if frame.Icon.Overlay then S:Kill(frame.Icon.Overlay) end
        if frame.Icon.Texture then
            if not frame.Icon.TextureBackdrop then
                local b = CreateFrame("Frame", nil, frame)
                S:CreateBackdrop(b)
                b.backdrop:ClearAllPoints()
                b.backdrop:SetPoint("TOPLEFT", frame.Icon.Texture, "TOPLEFT", -3, 3)
                b.backdrop:SetPoint("BOTTOMRIGHT", frame.Icon.Texture, "BOTTOMRIGHT", 3, -2)
                frame.Icon.Texture:SetParent(b)
                frame.Icon.TextureBackdrop = b
            end
            frame.Icon.Texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
    end
end

local function SkinDungeonCompletionAlert(frame)
    frame:SetAlpha(1)
    if not frame.hooked then
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        frame.hooked = true
    end

    if not frame.backdrop then
        S:CreateBackdrop(frame)
        frame.backdrop:ClearAllPoints()
        frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, -6)
        frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 6)
    end

    if frame.glowFrame then
        S:Kill(frame.glowFrame)
        if frame.glowFrame.glow then S:Kill(frame.glowFrame.glow) end
    end

    if frame.shine then S:Kill(frame.shine) end
    if frame.raidArt then S:Kill(frame.raidArt) end
    if frame.heroicIcon then S:Kill(frame.heroicIcon) end
    if frame.dungeonArt then S:Kill(frame.dungeonArt) end
    if frame.dungeonArt1 then S:Kill(frame.dungeonArt1) end
    if frame.dungeonArt2 then S:Kill(frame.dungeonArt2) end
    if frame.dungeonArt3 then S:Kill(frame.dungeonArt3) end
    if frame.dungeonArt4 then S:Kill(frame.dungeonArt4) end

    if frame.dungeonTexture then
        frame.dungeonTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        frame.dungeonTexture:SetDrawLayer("OVERLAY")
        frame.dungeonTexture:ClearAllPoints()
        frame.dungeonTexture:SetPoint("LEFT", frame, 7, 0)

        if not frame.dungeonTextureBackdrop then
            local b = CreateFrame("Frame", nil, frame)
            S:CreateBackdrop(b)
            b.backdrop:ClearAllPoints()
            S:SetOutside(b.backdrop, frame.dungeonTexture)
            frame.dungeonTexture:SetParent(b)
            frame.dungeonTextureBackdrop = b
        end
    end
end

local function SkinGuildChallengeAlert(frame)
    frame:SetAlpha(1)
    if not frame.hooked then
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        frame.hooked = true
    end

    if not frame.backdrop then
        S:CreateBackdrop(frame)
        frame.backdrop:ClearAllPoints()
        frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, -6)
        frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 6)
    end

    -- Background
    local region = select(2, frame:GetRegions())
    if region and region:IsObjectType("Texture") then
        if region:GetTexture() == "Interface\\GuildFrame\\GuildChallenges" then
            S:Kill(region)
        end
    end

    if frame.glow then S:Kill(frame.glow) end
    if frame.shine then S:Kill(frame.shine) end
    if frame.EmblemBorder then S:Kill(frame.EmblemBorder) end

    local EmblemIcon = frame.EmblemIcon
    if EmblemIcon and not EmblemIcon.Backdrop then
        local b = CreateFrame("Frame", nil, frame)
        S:CreateBackdrop(b)
        b.backdrop:ClearAllPoints()
        b.backdrop:SetPoint("TOPLEFT", EmblemIcon, "TOPLEFT", -3, 3)
        b.backdrop:SetPoint("BOTTOMRIGHT", EmblemIcon, "BOTTOMRIGHT", 3, -2)
        EmblemIcon:SetParent(b)
        EmblemIcon.Backdrop = b
    end
    
    if _G.SetLargeGuildTabardTextures then
        _G.SetLargeGuildTabardTextures("player", EmblemIcon)
    end
end

local function SkinHonorAwardedAlert(frame)
    frame:SetAlpha(1)
    if not frame.hooked then hooksecurefunc(frame, "SetAlpha", ForceAlpha); frame.hooked = true end

    if frame.Background then S:Kill(frame.Background) end
    if frame.IconBorder then S:Kill(frame.IconBorder) end

    if not frame.Icon.Backdrop then
        local b = CreateFrame("Frame", nil, frame)
        S:CreateBackdrop(b)
        b.backdrop:ClearAllPoints()
        S:SetOutside(b.backdrop, frame.Icon)
        frame.Icon:SetParent(b)
        frame.Icon.Backdrop = b
    end

    if not frame.backdrop then
        S:CreateBackdrop(frame)
        frame.backdrop:ClearAllPoints()
        if frame.Icon.Backdrop and frame.Icon.Backdrop.backdrop then
            frame.backdrop:SetPoint("TOPLEFT", frame.Icon.Backdrop.backdrop, "TOPLEFT", -4, 4)
            frame.backdrop:SetPoint("BOTTOMRIGHT", frame.Icon.Backdrop.backdrop, "BOTTOMRIGHT", 180, -4)
        end
    end
end

local function SkinLootWonAlert(frame)
    if not frame.hooked then
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        frame.hooked = true
    end

    frame:SetAlpha(1)
    if frame.Background then S:Kill(frame.Background) end

    local lootItem = frame.lootItem or frame
    if lootItem.Icon then
        lootItem.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        lootItem.Icon:SetDrawLayer("BORDER")
        if lootItem.IconBorder then S:Kill(lootItem.IconBorder) end
        if lootItem.SpecRing then lootItem.SpecRing:SetTexture(nil) end
        
        if not lootItem.IconBackdrop then
            local b = CreateFrame("Frame", nil, frame)
            S:CreateBackdrop(b)
            b.backdrop:ClearAllPoints()
            S:SetOutside(b.backdrop, lootItem.Icon)
            lootItem.Icon:SetParent(b)
            lootItem.IconBackdrop = b
        end
        
        if not frame.backdrop then
            S:CreateBackdrop(frame)
            frame.backdrop:ClearAllPoints()
            if lootItem.IconBackdrop and lootItem.IconBackdrop.backdrop then
                frame.backdrop:SetPoint("TOPLEFT", lootItem.IconBackdrop.backdrop, "TOPLEFT", -4, 4)
                frame.backdrop:SetPoint("BOTTOMRIGHT", lootItem.IconBackdrop.backdrop, "BOTTOMRIGHT", 180, -4)
            end
        end
    end

    if frame.glow then S:Kill(frame.glow) end
    if frame.shine then S:Kill(frame.shine) end
    if frame.BGAtlas then S:Kill(frame.BGAtlas) end
    if frame.PvPBackground then S:Kill(frame.PvPBackground) end
end

local function SkinMoneyWonAlert(frame)
    frame:SetAlpha(1)
    if not frame.hooked then
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        frame.hooked = true
    end

    if frame.Background then S:Kill(frame.Background) end
    frame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if frame.IconBorder then S:Kill(frame.IconBorder) end

    if not frame.Icon.Backdrop then
        local b = CreateFrame("Frame", nil, frame)
        S:CreateBackdrop(b)
        b.backdrop:ClearAllPoints()
        S:SetOutside(b.backdrop, frame.Icon)
        frame.Icon:SetParent(b)
        frame.Icon.Backdrop = b
    end

    if not frame.backdrop then
        S:CreateBackdrop(frame)
        frame.backdrop:ClearAllPoints()
        if frame.Icon.Backdrop and frame.Icon.Backdrop.backdrop then
            frame.backdrop:SetPoint("TOPLEFT", frame.Icon.Backdrop.backdrop, "TOPLEFT", -4, 4)
            frame.backdrop:SetPoint("BOTTOMRIGHT", frame.Icon.Backdrop.backdrop, "BOTTOMRIGHT", 180, -4)
        end
    end
end

local function SkinMiscAlerts(frame)
    frame:SetAlpha(1)
    if not frame.hooked then
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        frame.hooked = true
    end

    if frame.Background then S:Kill(frame.Background) end
    if frame.IconBorder then S:Kill(frame.IconBorder) end

    if frame.Icon then
        frame.Icon:SetMask("")
        frame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        frame.Icon:SetDrawLayer("BORDER", 5)
        
        if not frame.Icon.Backdrop then
            local b = CreateFrame("Frame", nil, frame)
            S:CreateBackdrop(b)
            b.backdrop:ClearAllPoints()
            b.backdrop:SetPoint("TOPLEFT", frame.Icon, "TOPLEFT", -2, 2)
            b.backdrop:SetPoint("BOTTOMRIGHT", frame.Icon, "BOTTOMRIGHT", 2, -2)
            frame.Icon:SetParent(b)
            frame.Icon.Backdrop = b
        end
        
        if not frame.backdrop then
            S:CreateBackdrop(frame)
            frame.backdrop:ClearAllPoints()
            if frame.Icon.Backdrop and frame.Icon.Backdrop.backdrop then
                frame.backdrop:SetPoint("TOPLEFT", frame.Icon.Backdrop.backdrop, "TOPLEFT", -8, 8)
                frame.backdrop:SetPoint("BOTTOMRIGHT", frame.Icon.Backdrop.backdrop, "BOTTOMRIGHT", 180, -8)
            end
        end
    end
end

local function SkinAlerts()
    if not (S.db.enable and S.db.alerts) then return end

    -- Achievements
    if _G.AchievementAlertSystem then hooksecurefunc(_G.AchievementAlertSystem, "setUpFunction", SkinAchievementAlert) end
    if _G.CriteriaAlertSystem then hooksecurefunc(_G.CriteriaAlertSystem, "setUpFunction", SkinCriteriaAlert) end
    if _G.MonthlyActivityAlertSystem then hooksecurefunc(_G.MonthlyActivityAlertSystem, "setUpFunction", SkinCriteriaAlert) end

    -- Encounters
    if _G.DungeonCompletionAlertSystem then hooksecurefunc(_G.DungeonCompletionAlertSystem, "setUpFunction", SkinDungeonCompletionAlert) end
    if _G.GuildChallengeAlertSystem then hooksecurefunc(_G.GuildChallengeAlertSystem, "setUpFunction", SkinGuildChallengeAlert) end
    
    -- Honor
    if _G.HonorAwardedAlertSystem then hooksecurefunc(_G.HonorAwardedAlertSystem, "setUpFunction", SkinHonorAwardedAlert) end

    -- Loot
    if _G.LootAlertSystem then hooksecurefunc(_G.LootAlertSystem, "setUpFunction", SkinLootWonAlert) end
    if _G.MoneyWonAlertSystem then hooksecurefunc(_G.MoneyWonAlertSystem, "setUpFunction", SkinMoneyWonAlert) end
    
    -- Pets/Mounts/Toys
    if _G.NewPetAlertSystem then hooksecurefunc(_G.NewPetAlertSystem, "setUpFunction", SkinMiscAlerts) end
    if _G.NewMountAlertSystem then hooksecurefunc(_G.NewMountAlertSystem, "setUpFunction", SkinMiscAlerts) end
    if _G.NewToyAlertSystem then hooksecurefunc(_G.NewToyAlertSystem, "setUpFunction", SkinMiscAlerts) end
    if _G.NewCosmeticAlertFrameSystem then hooksecurefunc(_G.NewCosmeticAlertFrameSystem, "setUpFunction", SkinMiscAlerts) end

    -- Bonus Roll Money
    if _G.BonusRollMoneyWonFrame then
        local frame = _G.BonusRollMoneyWonFrame
        frame:SetAlpha(1)
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        if frame.Background then S:Kill(frame.Background) end
        frame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if frame.IconBorder then S:Kill(frame.IconBorder) end

        local b = CreateFrame("Frame", nil, frame)
        S:CreateBackdrop(b)
        b.backdrop:ClearAllPoints()
        S:SetOutside(b.backdrop, frame.Icon)
        frame.Icon:SetParent(b)

        S:CreateBackdrop(frame)
        frame.backdrop:ClearAllPoints()
        frame.backdrop:SetPoint("TOPLEFT", b.backdrop, "TOPLEFT", -4, 4)
        frame.backdrop:SetPoint("BOTTOMRIGHT", b.backdrop, "BOTTOMRIGHT", 180, -4)
    end

    -- Bonus Roll Loot
    if _G.BonusRollLootWonFrame then
        local frame = _G.BonusRollLootWonFrame
        frame:SetAlpha(1)
        hooksecurefunc(frame, "SetAlpha", ForceAlpha)
        if frame.Background then S:Kill(frame.Background) end
        if frame.glow then S:Kill(frame.glow) end
        if frame.shine then S:Kill(frame.shine) end

        local lootItem = frame.lootItem or frame
        lootItem.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if lootItem.IconBorder then S:Kill(lootItem.IconBorder) end

        local b = CreateFrame("Frame", nil, frame)
        S:CreateBackdrop(b)
        b.backdrop:ClearAllPoints()
        S:SetOutside(b.backdrop, lootItem.Icon)
        lootItem.Icon:SetParent(b)

        S:CreateBackdrop(frame)
        frame.backdrop:ClearAllPoints()
        frame.backdrop:SetPoint("TOPLEFT", b.backdrop, "TOPLEFT", -4, 4)
        frame.backdrop:SetPoint("BOTTOMRIGHT", b.backdrop, "BOTTOMRIGHT", 180, -4)
    end
end

-- Inicializar cuando el módulo de Skins se active
hooksecurefunc(S, "OnEnable", SkinAlerts)
