-- Nameplates options: the side cards, the page layout that makes room for them and
-- the navigation from the live preview to an option. One text for both clients.

local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)

local Groups = {}
ns.OptionsGroups = Groups

local MEDIA = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\OptionCards\\"
local CARD_W, CARD_H, CARD_GAP = 94, 138, 6
local RAIL_W = CARD_W * 2 + CARD_GAP + 10
local DEFAULT_GROUP = "bars"

local CARDS = {
    { id = "style", label = "Style" },
    { id = "bars", label = "Bars" },
    { id = "text", label = "Text" },
    { id = "auras", label = "Auras" },
    { id = "cast", label = "Casting" },
    { id = "target", label = "Target & Focus" },
    { id = "colors", label = "Colors & Threat" },
    { id = "indicators", label = "Indicators" },
    { id = "friendly", label = "Friendly" },
    { id = "visibility", label = "Visibility" },
}

-- Which card holds the option behind each part of the enemy preview.
local KEY_GROUP = {
    enemyName = "text", healthText = "text", healthNumber = "text",
    healthBar = "bars",
    debuffIcon = "auras", buffIcon = "auras", ccIcon = "auras", raidMarker = "auras", classIcon = "auras",
    auraDuration = "auras", auraStack = "auras",
    castBar = "cast", castIcon = "cast", castName = "cast", castTarget = "cast",
    classResource = "indicators",
    targetArrows = "target",
}

local rail, savedLayout, glow
local cards = {}
local targets = {}

function Groups.Active()
    local active = KT._npOptionsActiveTab
    for _, card in ipairs(CARDS) do
        if card.id == active then return active end
    end
    KT._npOptionsActiveTab = DEFAULT_GROUP
    return DEFAULT_GROUP
end

---------------------------------------------------------------------------
-- Page layout: the scroll area moves right while the cards are up
---------------------------------------------------------------------------
function Groups.EnterLayout(menu)
    local sf, sc = menu.scrollFrame, menu.scrollChild
    if not menu._npLayoutHooked then
        menu._npLayoutHooked = true
        -- Reopening the menu on another page hides nothing that is still shown, so the
        -- preview's OnHide cannot be relied on: each page load passes through its heading.
        hooksecurefunc(menu, "SetPageHeading", function()
            if savedLayout and not menu._stickyPreviewFrame then Groups.LeaveLayout(menu) end
        end)
        -- Opening the menu re-anchors the scroll area without rebuilding the page.
        menu:HookScript("OnShow", function()
            C_Timer.After(0, function()
                if menu._stickyPreviewFrame and menu._stickyPreviewFrame == Groups.shell then
                    Groups.EnterLayout(menu)
                end
            end)
        end)
    end
    -- The menu may have re-anchored the area since: only a matching offset counts as moved.
    if savedLayout then
        local _, _, _, x = sf:GetPoint(1)
        if math.abs(x - savedLayout.movedX) < 0.5 then
            sc:SetWidth(savedLayout.width - RAIL_W)
            return
        end
    end
    local _, _, _, currentX = sf:GetPoint(1)
    local points = {}
    for i = 1, sf:GetNumPoints() do
        points[i] = { sf:GetPoint(i) }
    end
    savedLayout = { width = menu._npFullWidth or sc:GetWidth(), points = points, movedX = currentX + RAIL_W }
    menu._npFullWidth = savedLayout.width
    sf:ClearAllPoints()
    for _, p in ipairs(points) do
        local x = p[4]
        if p[1] == "TOPLEFT" or p[1] == "LEFT" or p[1] == "BOTTOMLEFT" then x = x + RAIL_W end
        sf:SetPoint(p[1], p[2], p[3], x, p[5])
    end
    sc:SetWidth(savedLayout.width - RAIL_W)
end

function Groups.LeaveLayout(menu)
    if not savedLayout then return end
    local sf, sc = menu.scrollFrame, menu.scrollChild
    sf:ClearAllPoints()
    for _, p in ipairs(savedLayout.points) do
        sf:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
    sc:SetWidth(savedLayout.width)
    savedLayout = nil
    if rail then rail:Hide() end
end

---------------------------------------------------------------------------
-- Cards. Adapted from a space-themed CSS card: a dark rounded face, a soft glow
-- rising from the bottom on hover, faint stars and a pale orb behind the chosen
-- icon, all in the accent colour. Animation groups only: nothing runs per frame.
---------------------------------------------------------------------------
local function Fade(tex, group, anim, to)
    group:Stop()
    anim:SetFromAlpha(tex:GetAlpha())
    anim:SetToAlpha(to)
    group:Play()
end

local function NewFader(tex, duration)
    local group = tex:CreateAnimationGroup()
    group:SetToFinalAlpha(true)
    local anim = group:CreateAnimation("Alpha")
    anim:SetDuration(duration)
    anim:SetSmoothing("IN_OUT")
    return function(to) Fade(tex, group, anim, to) end
end

local function PaintCard(card, hovered)
    local on = card.id == Groups.Active()
    local r, g, b = ns.OptionsPreview.AccentRGB()
    card.icon:SetVertexColor(on and 1 or r, on and 1 or g, on and 1 or b, (on or hovered) and 1 or 0.8)
    card.orb:SetVertexColor(r, g, b)
    card.glow:SetVertexColor(r, g, b)
    card.stars:SetVertexColor(1, 1, 1)
    card.edge:SetColor(r, g, b, on and 1 or (hovered and 0.55 or 0.22))
    card.fadeGlow(on and 0.55 or (hovered and 0.42 or 0))
    card.fadeOrb(on and 0.95 or 0)
    card.fadeStars((on or hovered) and 0.8 or 0.18)
    if on then
        card.label:SetTextColor(1, 1, 1, 1)
    else
        card.label:SetTextColor(0.85, 0.83, 0.87, 1)
    end
    if hovered then
        if not card.drift:IsPlaying() then card.drift:Play() end
    elseif card.drift:IsPlaying() then
        card.drift:Stop()
    end
end

local function BuildCard(parent, info, index)
    local W = KT.Widgets
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(CARD_W, CARD_H)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", ((index - 1) % 2) * (CARD_W + CARD_GAP),
        -math.floor((index - 1) / 2) * (CARD_H + CARD_GAP))
    btn:SetClipsChildren(true)
    btn.id = info.id

    btn.edge = W:RoundRect(btn, "BACKGROUND", -6, 11)
    btn.edge:SetAllPoints(btn)
    local face = W:RoundRect(btn, "BACKGROUND", -5, 10)
    face:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    face:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    face:SetColor(0.075, 0.07, 0.075, 1)

    btn.glow = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    btn.glow:SetTexture(MEDIA .. "glow.png")
    btn.glow:SetBlendMode("ADD")
    btn.glow:SetSize(CARD_W * 1.9, CARD_H * 1.3)
    btn.glow:SetPoint("CENTER", btn, "BOTTOM", 0, 0)
    btn.glow:SetAlpha(0)
    btn.fadeGlow = NewFader(btn.glow, 0.3)

    btn.stars = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    btn.stars:SetTexture(MEDIA .. "stars.png")
    btn.stars:SetBlendMode("ADD")
    btn.stars:SetTexCoord(0, CARD_W / 256, (index % 5) * 0.08, (index % 5) * 0.08 + CARD_H / 256)
    btn.stars:SetAllPoints(btn)
    btn.stars:SetAlpha(0.18)
    btn.fadeStars = NewFader(btn.stars, 0.4)

    btn.orb = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    btn.orb:SetTexture(MEDIA .. "orb.png")
    btn.orb:SetBlendMode("ADD")
    btn.orb:SetSize(92, 92)
    btn.orb:SetPoint("CENTER", btn, "TOP", 0, -52)
    btn.orb:SetAlpha(0)
    btn.fadeOrb = NewFader(btn.orb, 0.3)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetTexture(MEDIA .. info.id .. ".png")
    btn.icon:SetSize(60, 60)
    btn.icon:SetPoint("CENTER", btn, "TOP", 0, -52)
    btn.drift = btn.icon:CreateAnimationGroup()
    btn.drift:SetLooping("BOUNCE")
    local move = btn.drift:CreateAnimation("Translation")
    move:SetOffset(0, 4)
    move:SetDuration(1.1)
    move:SetSmoothing("IN_OUT")

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont(KT.FONT_PATH, 13, "")
    btn.label:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 5, 10)
    btn.label:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -5, 10)
    btn.label:SetJustifyH("CENTER")
    btn.label:SetSpacing(2)
    btn.label:SetText(ns.OptionsPreview.LText(info.label))

    btn:SetScript("OnEnter", function(self) PaintCard(self, true) end)
    btn:SetScript("OnLeave", function(self) PaintCard(self, false) end)
    btn:SetScript("OnClick", function(self)
        if KT._npOptionsActiveTab == self.id then return end
        KT._npOptionsActiveTab = self.id
        KT:RefreshPage(false)
    end)
    return btn
end

function Groups.ShowRail(menu)
    local sf = menu.scrollFrame
    if not rail then
        rail = CreateFrame("Frame", nil, menu)
        rail:SetSize(RAIL_W - 10, (CARD_H + CARD_GAP) * 5)
        for i, info in ipairs(CARDS) do
            cards[i] = BuildCard(rail, info, i)
        end
    end
    rail:ClearAllPoints()
    rail:SetPoint("TOPLEFT", sf, "TOPLEFT", -RAIL_W, 0)
    rail:SetFrameStrata(menu:GetFrameStrata())
    rail:SetFrameLevel(math.min((sf:GetFrameLevel() or 1) + 205, 9000))
    rail:Show()
    for _, card in ipairs(cards) do PaintCard(card, false) end
end

---------------------------------------------------------------------------
-- Navigation from the preview: open the card, scroll to the section, mark the option
---------------------------------------------------------------------------
function Groups.ResetTargets()
    wipe(targets)
end

-- target is a frame or a function returning one; open replaces the highlight with an action.
function Groups.Register(key, header, target, open)
    targets[key] = { header = header, target = target, open = open }
end

local function ScrollToHeader(header)
    if not header or header:GetNumPoints() < 1 then return false end
    local _, _, _, _, hy = header:GetPoint(1)
    KT.SmoothScrollTo(math.max(0, math.abs(hy) - 40))
    return true
end

local function PlayGlow(target)
    if not glow then
        glow = CreateFrame("Frame")
        local r, g, b = ns.OptionsPreview.AccentRGB()
        KT.PP.CreateBorder(glow, r, g, b, 1, 2)
    end
    glow:SetParent(target)
    glow:ClearAllPoints()
    glow:SetAllPoints(target)
    glow:SetFrameLevel(target:GetFrameLevel() + 5)
    glow:SetAlpha(1)
    glow:Show()
    local clock = 0
    glow:SetScript("OnUpdate", function(self, dt)
        clock = clock + dt
        if clock >= 0.75 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
            return
        end
        self:SetAlpha(1 - clock / 0.75)
    end)
end

local function GoToTarget(key)
    local entry = targets[key]
    if not entry or not ScrollToHeader(entry.header) then return end
    C_Timer.After(0.15, function()
        if entry.open then
            entry.open()
            return
        end
        local target = entry.target
        if type(target) == "function" then target = target() end
        if target then PlayGlow(target) end
    end)
end

function Groups.Navigate(key)
    local group = KEY_GROUP[key]
    if not group then return end
    if group == Groups.Active() then
        GoToTarget(key)
        return
    end
    KT._npOptionsActiveTab = group
    KT:RefreshPage(false)
    C_Timer.After(0, function() GoToTarget(key) end)
end
