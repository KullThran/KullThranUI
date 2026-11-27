local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local C_Timer = C_Timer

-- AlertFrames run inside Blizzard's protected animation/queue code.  Executing
-- KullThranUI code synchronously in AlertSystem:setUpFunction() shares that
-- protected context: any cosmetic write dirties UIParent's layout path and
-- taints a later Blizzard ActionButton update (ADDON_ACTION_BLOCKED on
-- MultiBar SetAttribute / "SetCooldown secret values" errors).  Defer every
-- skin to a clean frame context, same as Popups/GameMenu/BattleNet alerts.
local function DeferAlertSkin(frame, func)
	if not (frame and func) then return end
	C_Timer.After(0, function()
		if frame.IsForbidden and frame:IsForbidden() then return end
		if frame.IsProtected and frame:IsProtected() then return end
		pcall(func, frame)
	end)
end

local function KillParts(owner, ...)
    for i = 1, select("#", ...) do
        local part = owner[select(i, ...)]
        if part then
            S:Kill(part)
        end
    end
end

local function CropIcon(icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- With no offsets the holder's backdrop takes the outside anchors.
local function NewIconHolder(frame, icon, left, top, right, bottom)
    local holder = CreateFrame("Frame", nil, frame)
    S:CreateBackdrop(holder)
    local backdrop = holder.backdrop
    backdrop:ClearAllPoints()
    if left then
        backdrop:SetPoint("TOPLEFT", icon, "TOPLEFT", left, top)
        backdrop:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", right, bottom)
    else
        S:SetOutside(backdrop, icon)
    end
    icon:SetParent(holder)
    return holder
end

local function EnsureIconHolder(frame, owner, field, icon, left, top, right, bottom)
    local holder = owner[field]
    if not holder then
        holder = NewIconHolder(frame, icon, left, top, right, bottom)
        owner[field] = holder
    end
    return holder
end

local function BackdropAroundHolder(frame, holder, pad)
    S:CreateBackdrop(frame)
    local backdrop = frame.backdrop
    backdrop:ClearAllPoints()
    local inner = holder and holder.backdrop
    if inner then
        backdrop:SetPoint("TOPLEFT", inner, "TOPLEFT", -pad, pad)
        backdrop:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 180, -pad)
    end
end

local function BackdropShiftedOn(frame, target)
    if frame.backdrop then return end
    S:CreateBackdrop(frame)
    local backdrop = frame.backdrop
    backdrop:ClearAllPoints()
    backdrop:SetPoint("TOPLEFT", target, "TOPLEFT", -2, -6)
    backdrop:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -2, 6)
end

local function SkinAchievementAlert(frame)
    local background = frame.Background
    if not frame.backdrop then
        if background then
            BackdropShiftedOn(frame, background)
        else
            S:CreateBackdrop(frame)
            frame.backdrop:ClearAllPoints()
            frame.backdrop:SetAllPoints(frame)
        end
    end

    if background then
        background:SetTexture(nil)
    end
    KillParts(frame, "glow", "shine", "GuildBanner", "GuildBorder")
    if frame.Unlocked then
        S:HandleFont(frame.Unlocked)
        frame.Unlocked:SetTextColor(1, 1, 1)
    end
    if frame.Name then
        S:HandleFont(frame.Name)
    end

    local icon = frame.Icon
    if icon then
        KillParts(icon, "Overlay")
        local texture = icon.Texture
        if texture then
            CropIcon(texture)
            texture:ClearAllPoints()
            texture:SetPoint("LEFT", frame, 7, 0)
            if not icon.backdrop then
                S:CreateBackdrop(icon)
                S:SetOutside(icon.backdrop, texture)
            end
        end
    end
end

local function SkinCriteriaAlert(frame)
    BackdropShiftedOn(frame, frame)
    if frame.Unlocked then
        frame.Unlocked:SetTextColor(1, 1, 1)
    end
    if frame.Name then
        frame.Name:SetTextColor(1, 1, 0)
    end
    KillParts(frame, "Background", "glow", "shine")

    local icon = frame.Icon
    if icon then
        KillParts(icon, "Bling", "Overlay")
        local texture = icon.Texture
        if texture then
            EnsureIconHolder(frame, icon, "TextureBackdrop", texture, -3, 3, 3, -2)
            CropIcon(texture)
        end
    end
end

local function SkinDungeonAlert(frame)
    BackdropShiftedOn(frame, frame)
    if frame.glowFrame then
        S:Kill(frame.glowFrame)
        KillParts(frame.glowFrame, "glow")
    end
    KillParts(frame, "shine", "raidArt", "heroicIcon", "dungeonArt",
        "dungeonArt1", "dungeonArt2", "dungeonArt3", "dungeonArt4")

    local texture = frame.dungeonTexture
    if texture then
        CropIcon(texture)
        texture:SetDrawLayer("OVERLAY")
        texture:ClearAllPoints()
        texture:SetPoint("LEFT", frame, 7, 0)
        EnsureIconHolder(frame, frame, "dungeonTextureBackdrop", texture)
    end
end

local function SkinGuildChallengeAlert(frame)
    BackdropShiftedOn(frame, frame)

    local second = select(2, frame:GetRegions())
    if second and second:IsObjectType("Texture")
        and second:GetTexture() == "Interface\\GuildFrame\\GuildChallenges" then
        S:Kill(second)
    end
    KillParts(frame, "glow", "shine", "EmblemBorder")

    local emblem = frame.EmblemIcon
    if emblem then
        EnsureIconHolder(frame, emblem, "Backdrop", emblem, -3, 3, 3, -2)
    end
    if _G.SetLargeGuildTabardTextures then
        _G.SetLargeGuildTabardTextures("player", emblem)
    end
end

local function SkinHonorAlert(frame)
    KillParts(frame, "Background", "IconBorder")
    local icon = frame.Icon
    local holder = EnsureIconHolder(frame, icon, "Backdrop", icon)
    if not frame.backdrop then
        BackdropAroundHolder(frame, holder, 4)
    end
end

local function SkinLootAlert(frame)
    KillParts(frame, "Background")
    local item = frame.lootItem or frame
    local icon = item.Icon
    if icon then
        CropIcon(icon)
        icon:SetDrawLayer("BORDER")
        KillParts(item, "IconBorder")
        if item.SpecRing then
            item.SpecRing:SetTexture(nil)
        end
        local holder = EnsureIconHolder(frame, item, "IconBackdrop", icon)
        if not frame.backdrop then
            BackdropAroundHolder(frame, holder, 4)
        end
    end
    KillParts(frame, "glow", "shine", "BGAtlas", "PvPBackground")
end

local function SkinMoneyAlert(frame)
    KillParts(frame, "Background")
    local icon = frame.Icon
    CropIcon(icon)
    KillParts(frame, "IconBorder")
    local holder = EnsureIconHolder(frame, icon, "Backdrop", icon)
    if not frame.backdrop then
        BackdropAroundHolder(frame, holder, 4)
    end
end

local function SkinCollectibleAlert(frame)
    KillParts(frame, "Background", "IconBorder")
    local icon = frame.Icon
    if icon then
        icon:SetMask("")
        CropIcon(icon)
        icon:SetDrawLayer("BORDER", 5)
        local holder = EnsureIconHolder(frame, icon, "Backdrop", icon, -2, 2, 2, -2)
        if not frame.backdrop then
            BackdropAroundHolder(frame, holder, 8)
        end
    end
end

local function SkinAlerts()
    if not S:IsWindowEnabled("alerts") then return end

    local systems = {
        { "AchievementAlertSystem", SkinAchievementAlert },
        { "CriteriaAlertSystem", SkinCriteriaAlert },
        { "MonthlyActivityAlertSystem", SkinCriteriaAlert },
        { "DungeonCompletionAlertSystem", SkinDungeonAlert },
        { "GuildChallengeAlertSystem", SkinGuildChallengeAlert },
        { "HonorAwardedAlertSystem", SkinHonorAlert },
        { "LootAlertSystem", SkinLootAlert },
        { "MoneyWonAlertSystem", SkinMoneyAlert },
        { "NewPetAlertSystem", SkinCollectibleAlert },
        { "NewMountAlertSystem", SkinCollectibleAlert },
        { "NewToyAlertSystem", SkinCollectibleAlert },
        { "NewCosmeticAlertFrameSystem", SkinCollectibleAlert },
    }
    for i = 1, #systems do
        local system, skin = _G[systems[i][1]], systems[i][2]
        if system then
            hooksecurefunc(system, "setUpFunction", function(frame)
                DeferAlertSkin(frame, skin)
            end)
        end
    end

    local money = _G.BonusRollMoneyWonFrame
    if money then
        KillParts(money, "Background")
        CropIcon(money.Icon)
        KillParts(money, "IconBorder")
        BackdropAroundHolder(money, NewIconHolder(money, money.Icon), 4)
    end

    local loot = _G.BonusRollLootWonFrame
    if loot then
        KillParts(loot, "Background", "glow", "shine")
        local item = loot.lootItem or loot
        CropIcon(item.Icon)
        KillParts(item, "IconBorder")
        BackdropAroundHolder(loot, NewIconHolder(loot, item.Icon), 4)
    end
end

-- Inicializar cuando el módulo de Skins se active
S:RegisterWindow("alerts", { name = "AlertsOnEnable", label = "Alerts (Toasts)", apply = SkinAlerts })