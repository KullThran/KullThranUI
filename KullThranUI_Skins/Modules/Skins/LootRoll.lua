local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local pcall = pcall
local hooksecurefunc = hooksecurefunc
local type = type

-- Group loot rolls (Need / Greed / Pass) in KUI style: a compact dark panel, the item icon cropped with a border in
-- its quality colour, the roll buttons in a row on the right and the timer as a thin accent bar under the panel.
-- Blizzard keeps every handler: only textures, sizes and the positions inside the frame change. Where the frames
-- sit on screen is the core's job (LootRollGuard in Enhancements.lua).
local NUM_ROLL_FRAMES = 4
local WIDTH, HEIGHT = 300, 46
local ICON_SIZE, BUTTON_SIZE = 34, 26
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local function QualityColor(rollID)
    if rollID == nil or type(_G.GetLootRollItemInfo) ~= "function" then return nil end
    local ok, _, _, _, quality = pcall(_G.GetLootRollItemInfo, rollID)
    if not ok or type(quality) ~= "number" then return nil end
    local manager = _G.ColorManager
    local color = manager and manager.GetColorDataForItemQuality and manager.GetColorDataForItemQuality(quality)
    if not color and _G.ITEM_QUALITY_COLORS then color = _G.ITEM_QUALITY_COLORS[quality] end
    if color and color.r then return color.r, color.g, color.b end
    return nil
end

-- Runs after Blizzard's OnShow has filled the frame for its roll.
-- Blizzard puts the timer one level under the roll frame on every roll (GroupLootFrame_SetupItemDisplay) so its
-- toast art covers the bar's ends. The timer's backdrop keeps the level it got when it was made, so it ended up
-- over the bar and hid it. The bar and its backdrop are put back above the panel each time a roll is shown.
local function RaiseTimer(frame, timer)
    local level = frame:GetFrameLevel()
    timer:SetFrameLevel(level + 2)
    if timer.backdrop then timer.backdrop:SetFrameLevel(level + 1) end
    if timer.Background then timer.Background:SetDrawLayer("BACKGROUND", -1) end
    timer:SetAlpha(1)
    timer:Show()
end

local function PaintRoll(frame)
    local iconFrame = frame.IconFrame
    local backdrop = iconFrame and iconFrame.backdrop
    if backdrop then
        local r, g, b = QualityColor(frame.rollID)
        if r then
            backdrop:SetBackdropBorderColor(r, g, b, 1)
        else
            S:ApplyBorderColor(backdrop)
        end
    end
    local timer = frame.Timer
    if timer and timer.SetStatusBarColor then
        RaiseTimer(frame, timer)
        local accent = S:GetAccentColor()
        timer:SetStatusBarColor(accent[1], accent[2], accent[3], 1)
    end
end

local function SkinRollButton(button, anchorPoint, relativeTo, relativePoint, x)
    if not button then return end
    button:ClearAllPoints()
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPoint(anchorPoint, relativeTo, relativePoint, x, 0)
    S:CreateBackdrop(button)
end

local function SkinRollFrame(frame)
    if not frame or frame.KT_LootRollSkinned then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    frame.KT_LootRollSkinned = true

    frame:SetSize(WIDTH, HEIGHT)
    -- Toast art, quality-tinted border and the dialog panel's frame.
    S:StripTextures(frame, true)
    S:CreateBackdrop(frame)

    local iconFrame = frame.IconFrame
    if iconFrame then
        iconFrame:ClearAllPoints()
        iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
        iconFrame:SetPoint("LEFT", frame, "LEFT", 6, 0)
        if iconFrame.Border then S:Kill(iconFrame.Border) end
        local icon = iconFrame.Icon
        if icon then
            icon:ClearAllPoints()
            icon:SetAllPoints(iconFrame)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        S:CreateBackdrop(iconFrame)
        local count = iconFrame.Count
        if count then
            S:HandleFont(count)
            count:ClearAllPoints()
            count:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
        end
    end

    -- The button row hangs from the frame, not from the name (Blizzard anchors it to the name's right edge).
    local container = frame.LootButtonContainer
    local need = container and container.NeedButton
    if container then
        container:ClearAllPoints()
        container:SetAllPoints(frame)
        local pass, greed = container.PassButton, container.GreedButton
        SkinRollButton(pass, "RIGHT", frame, "RIGHT", -8)
        SkinRollButton(greed, "RIGHT", pass or frame, pass and "LEFT" or "RIGHT", -4)
        SkinRollButton(container.TransmogButton, "CENTER", greed or frame, "CENTER", 0)
        SkinRollButton(need, "RIGHT", greed or pass or frame, "LEFT", -4)
    end

    local name = frame.Name
    if name then
        S:HandleFont(name)
        name:ClearAllPoints()
        name:SetPoint("LEFT", iconFrame or frame, iconFrame and "RIGHT" or "LEFT", 8, 0)
        name:SetPoint("RIGHT", need or frame, need and "LEFT" or "RIGHT", -6, 0)
        name:SetHeight(30)
        name:SetJustifyH("LEFT")
        if name.SetWordWrap then name:SetWordWrap(false) end
    end

    local timer = frame.Timer
    if timer then
        timer:ClearAllPoints()
        timer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 1, -4)
        timer:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -1, -4)
        timer:SetHeight(6)
        timer:SetStatusBarTexture(BAR_TEXTURE)
        local bar = timer:GetStatusBarTexture()
        if bar then bar:SetDrawLayer("ARTWORK", 1) end
        if timer.Background then timer.Background:SetColorTexture(0, 0, 0, 0.6) end
        S:CreateBackdrop(timer, true)
        RaiseTimer(frame, timer)
    end

    frame:HookScript("OnShow", PaintRoll)
    S:RegisterBlizzardAccentRefresh(frame, PaintRoll)
    if frame:IsShown() then PaintRoll(frame) end
end

local setupHooked = false

local function SkinLootRolls()
    for index = 1, NUM_ROLL_FRAMES do
        SkinRollFrame(_G["GroupLootFrame" .. index])
    end
    -- The gamepad roll list sets frames up without showing them again, which also lowers the timer.
    if not setupHooked and type(_G.GroupLootFrame_SetupItemDisplay) == "function" then
        setupHooked = true
        hooksecurefunc("GroupLootFrame_SetupItemDisplay", function(frame)
            if frame and frame.KT_LootRollSkinned and frame.Timer then RaiseTimer(frame, frame.Timer) end
        end)
    end
    -- Slots depend on the frame height, which the skin just changed.
    local guard = KT.LootRollVisibilityGuard
    if guard and guard.PlaceFrames then guard:PlaceFrames() end
end

S:RegisterWindow("lootroll", { addon = "Blizzard_UIPanels_Game", name = "Blizzard_UIPanels_Game", label = "Group Loot Rolls", apply = SkinLootRolls })
