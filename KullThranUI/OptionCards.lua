-- Option cards: a rail of icon cards on the left of an options page. Each card is
-- one section of the page and picking it rebuilds the page with that section's
-- options. While a rail is up the page's scroll area moves right to make room;
-- loading any other page puts it back. Used by the Nameplates, Unit Frames and
-- Party Frames pages. One text for both clients.
--
-- Page side:
--   local rail = KT.OptionCards.New({ pageId = "x", cards = { { id, label, icon } }, default = id })
--   rail:RegisterSearch()                 -- search results open the card holding the option
--   builder: if KT.OptionCards.Indexing() then build rail:Active() only and return
--            rail:EnterLayout(menu) before sizing anything on the page, rail:Show(menu) after
-- icon: a texture path, or { path, left, right, top, bottom } for a cell of an atlas.

local _, ns = ...
local KT = ns.KT

local OptionCards = KT.OptionCards or {}
KT.OptionCards = OptionCards

local ART = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\OptionCards\\"
local CARD_W, CARD_H, CARD_GAP = 94, 138, 6
local RAIL_W = CARD_W * 2 + CARD_GAP + 10
OptionCards.RAIL_W = RAIL_W
OptionCards.ART = ART

-- The menu has one scroll area, so one moved layout at a time: the rail that owns it,
-- the anchors it replaced, the full width and the x the area was moved to.
local moved
local hookedMenus = {}

local function AccentRGB()
    if KT.GetStyleAccentRGB then return KT:GetStyleAccentRGB() end
    return KT.C_R or 0.902, KT.C_G or 0.118, KT.C_B or 0.314
end

local function Localize(text)
    if type(text) ~= "string" then return text end
    local L = KT.GetLocale and KT:GetLocale()
    local value = L and L[text]
    if type(value) == "string" and value ~= "" then return value end
    return text
end

function OptionCards.Indexing()
    return KT.Options and KT.Options.indexingSearch and true or false
end

---------------------------------------------------------------------------
-- Page layout
---------------------------------------------------------------------------
local function LeftOffset(scrollFrame)
    local _, _, _, x = scrollFrame:GetPoint(1)
    return x or 0
end

function OptionCards.LeaveLayout(menu)
    if not (moved and menu and menu.scrollFrame) then return end
    local sf, sc = menu.scrollFrame, menu.scrollChild
    sf:ClearAllPoints()
    for _, p in ipairs(moved.points) do
        sf:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
    sc:SetWidth(moved.width)
    local owner = moved.owner
    moved = nil
    if owner and owner.frame then owner.frame:Hide() end
end

local function HookMenu(menu)
    if hookedMenus[menu] then return end
    hookedMenus[menu] = true
    -- Every page load (or category overview) sets its heading after dropping the pinned
    -- preview: the moved area goes back before the next page is built.
    hooksecurefunc(menu, "SetPageHeading", function()
        if moved and not menu._stickyPreviewFrame then OptionCards.LeaveLayout(menu) end
    end)
    -- Opening the window anchors the scroll area again without rebuilding the page.
    menu:HookScript("OnShow", function()
        C_Timer.After(0, function()
            local owner = moved and moved.owner
            if owner and ns.activePageId == owner.pageId and menu:IsShown() then
                owner:EnterLayout(menu)
            end
        end)
    end)
end

local function EnterLayout(menu, owner)
    local sf, sc = menu.scrollFrame, menu.scrollChild
    HookMenu(menu)
    -- Still where this rail left it: nothing to move, only the width to keep.
    if moved and math.abs(LeftOffset(sf) - moved.movedX) < 0.5 then
        if moved.owner ~= owner and moved.owner and moved.owner.frame then moved.owner.frame:Hide() end
        moved.owner = owner
        sc:SetWidth(moved.width - RAIL_W)
        return
    end
    local points = {}
    for i = 1, sf:GetNumPoints() do
        points[i] = { sf:GetPoint(i) }
    end
    local width = menu._ktCardsFullWidth or sc:GetWidth()
    menu._ktCardsFullWidth = width
    moved = { owner = owner, points = points, width = width, movedX = LeftOffset(sf) + RAIL_W }
    sf:ClearAllPoints()
    for _, p in ipairs(points) do
        local x = p[4]
        if p[1] == "TOPLEFT" or p[1] == "LEFT" or p[1] == "BOTTOMLEFT" then x = x + RAIL_W end
        sf:SetPoint(p[1], p[2], p[3], x, p[5])
    end
    sc:SetWidth(width - RAIL_W)
end

---------------------------------------------------------------------------
-- Cards: a dark rounded face; the hovered one gets a soft accent glow from the
-- bottom and brighter stars, the chosen one a pale orb behind its icon. Alpha
-- animations only: nothing runs every frame.
---------------------------------------------------------------------------
local function Fader(texture, duration)
    local group = texture:CreateAnimationGroup()
    group:SetToFinalAlpha(true)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetDuration(duration)
    alpha:SetSmoothing("IN_OUT")
    return function(to)
        group:Stop()
        alpha:SetFromAlpha(texture:GetAlpha())
        alpha:SetToAlpha(to)
        group:Play()
    end
end

local function Paint(card, hovered)
    local chosen = card.id == card.rail:Active()
    local r, g, b = AccentRGB()
    if chosen then
        card.icon:SetVertexColor(1, 1, 1, 1)
        card.label:SetTextColor(1, 1, 1, 1)
    else
        card.icon:SetVertexColor(r, g, b, hovered and 1 or 0.8)
        card.label:SetTextColor(0.85, 0.83, 0.87, 1)
    end
    card.orb:SetVertexColor(r, g, b)
    card.glow:SetVertexColor(r, g, b)
    card.stars:SetVertexColor(1, 1, 1)
    card.edge:SetColor(r, g, b, chosen and 1 or (hovered and 0.55 or 0.22))
    card.fadeGlow(chosen and 0.55 or (hovered and 0.42 or 0))
    card.fadeOrb(chosen and 0.95 or 0)
    card.fadeStars((chosen or hovered) and 0.8 or 0.18)
    if hovered then
        if not card.float:IsPlaying() then card.float:Play() end
    elseif card.float:IsPlaying() then
        card.float:Stop()
    end
end

local function SetIcon(texture, icon)
    if type(icon) == "table" then
        texture:SetTexture(icon[1])
        texture:SetTexCoord(icon[2] or 0, icon[3] or 1, icon[4] or 0, icon[5] or 1)
    else
        texture:SetTexture(icon)
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function NewCard(rail, parent, info, index)
    local W = KT.Widgets
    local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", col * (CARD_W + CARD_GAP), -row * (CARD_H + CARD_GAP))
    card:SetClipsChildren(true)
    card.id, card.rail = info.id, rail

    card.edge = W:RoundRect(card, "BACKGROUND", -6, 11)
    card.edge:SetAllPoints(card)
    local face = W:RoundRect(card, "BACKGROUND", -5, 10)
    face:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    face:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
    face:SetColor(0.075, 0.07, 0.075, 1)

    card.glow = card:CreateTexture(nil, "BACKGROUND", nil, -3)
    card.glow:SetTexture(ART .. "glow.png")
    card.glow:SetBlendMode("ADD")
    card.glow:SetSize(CARD_W * 1.9, CARD_H * 1.3)
    card.glow:SetPoint("CENTER", card, "BOTTOM", 0, 0)
    card.glow:SetAlpha(0)
    card.fadeGlow = Fader(card.glow, 0.3)

    -- Each card shows its own patch of the star field.
    local starY = (index % 5) * 0.08
    card.stars = card:CreateTexture(nil, "BACKGROUND", nil, -2)
    card.stars:SetTexture(ART .. "stars.png")
    card.stars:SetBlendMode("ADD")
    card.stars:SetTexCoord(0, CARD_W / 256, starY, starY + CARD_H / 256)
    card.stars:SetAllPoints(card)
    card.stars:SetAlpha(0.18)
    card.fadeStars = Fader(card.stars, 0.4)

    card.orb = card:CreateTexture(nil, "BACKGROUND", nil, -1)
    card.orb:SetTexture(ART .. "orb.png")
    card.orb:SetBlendMode("ADD")
    card.orb:SetSize(92, 92)
    card.orb:SetPoint("CENTER", card, "TOP", 0, -52)
    card.orb:SetAlpha(0)
    card.fadeOrb = Fader(card.orb, 0.3)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    SetIcon(card.icon, info.icon)
    card.icon:SetSize(60, 60)
    card.icon:SetPoint("CENTER", card, "TOP", 0, -52)
    card.float = card.icon:CreateAnimationGroup()
    card.float:SetLooping("BOUNCE")
    local rise = card.float:CreateAnimation("Translation")
    rise:SetOffset(0, 4)
    rise:SetDuration(1.1)
    rise:SetSmoothing("IN_OUT")

    card.label = card:CreateFontString(nil, "OVERLAY")
    card.label:SetFont(KT.FONT_PATH, 13, "")
    card.label:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 5, 10)
    card.label:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -5, 10)
    card.label:SetJustifyH("CENTER")
    card.label:SetSpacing(2)
    card.label:SetText(Localize(info.label))

    card:SetScript("OnEnter", function(self) Paint(self, true) end)
    card:SetScript("OnLeave", function(self) Paint(self, false) end)
    card:SetScript("OnClick", function(self) self.rail:Select(self.id) end)
    return card
end

---------------------------------------------------------------------------
-- Rail
---------------------------------------------------------------------------
local Rail = {}
Rail.__index = Rail

function OptionCards.New(spec)
    assert(type(spec) == "table" and type(spec.cards) == "table" and spec.cards[1], "OptionCards.New: cards")
    local rail = setmetatable({
        pageId = spec.pageId,
        cards = spec.cards,
        default = spec.default or spec.cards[1].id,
        onSelect = spec.onSelect,
        getActive = spec.getActive,
        setActive = spec.setActive,
        buttons = {},
    }, Rail)
    return rail
end

function Rail:Has(id)
    for _, info in ipairs(self.cards) do
        if info.id == id then return true end
    end
    return false
end

function Rail:Active()
    local id
    if self.getActive then id = self.getActive() else id = self.active end
    if id ~= nil and self:Has(id) then return id end
    self:SetActive(self.default)
    return self.default
end

function Rail:SetActive(id)
    if not self:Has(id) then return end
    if self.setActive then self.setActive(id) else self.active = id end
end

-- Card ids, the one shown and each card's title, as the options search wants them.
function Rail:SearchViews()
    local ids, labels = {}, {}
    for _, info in ipairs(self.cards) do
        ids[#ids + 1] = info.id
        labels[info.id] = info.label
    end
    return ids, self:Active(), labels
end

function Rail:RegisterSearch()
    if not (KT.OptionsSearch and KT.OptionsSearch.RegisterViews and self.pageId) then return end
    KT.OptionsSearch.RegisterViews(self.pageId,
        function() return self:SearchViews() end,
        function(id) self:SetActive(id) end)
end

-- A click: the page rebuilds from the top with the chosen card.
function Rail:Select(id)
    local previous = self:Active()
    if id == previous or not self:Has(id) then return end
    self:SetActive(id)
    if self.onSelect then self.onSelect(id, previous) end
    if KT.RefreshPage then KT:RefreshPage(false) end
end

function Rail:EnterLayout(menu)
    if not (menu and menu.scrollFrame and menu.scrollChild) then return end
    EnterLayout(menu, self)
end

function Rail:Repaint()
    for _, card in ipairs(self.buttons) do Paint(card, card:IsMouseOver()) end
end

-- The rail sits outside the scroll area. It shrinks to fit the area's height (five
-- rows are taller than the window once a page tab bar is up), and the mouse wheel
-- over it scrolls the page, as it does over the options themselves.
local function RailHeight(rows)
    return rows * CARD_H + (rows - 1) * CARD_GAP
end

local function PlaceRail(rail)
    local frame, sf = rail.frame, rail.scrollFrame
    if not (frame and sf) then return end
    local natural = RailHeight(math.ceil(#rail.cards / 2))
    local available = sf:GetHeight() or 0
    local scale = 1
    if available > 0 and available < natural then scale = math.max(0.5, available / natural) end
    frame:SetScale(scale)
    frame:ClearAllPoints()
    -- Offsets are in the rail's own (scaled) units: keep its left edge RAIL_W from the area.
    frame:SetPoint("TOPLEFT", sf, "TOPLEFT", -RAIL_W / scale, 0)
end

function Rail:Show(menu)
    if not (menu and menu.scrollFrame) then return end
    self:EnterLayout(menu)
    local sf = menu.scrollFrame
    self.scrollFrame = sf
    if not self.frame then
        local rows = math.ceil(#self.cards / 2)
        self.frame = CreateFrame("Frame", nil, menu)
        self.frame:SetSize(RAIL_W - 10, RailHeight(rows))
        for index, info in ipairs(self.cards) do
            self.buttons[index] = NewCard(self, self.frame, info, index)
        end
        self.frame:EnableMouseWheel(true)
        self.frame:SetScript("OnMouseWheel", function(_, delta)
            local area = self.scrollFrame
            local handler = area and area:GetScript("OnMouseWheel")
            if handler then handler(area, delta) end
        end)
    end
    if not hookedMenus[sf] then
        hookedMenus[sf] = true
        sf:HookScript("OnSizeChanged", function()
            local owner = moved and moved.owner
            if owner and owner.frame and owner.frame:IsShown() then PlaceRail(owner) end
        end)
    end
    local frame = self.frame
    PlaceRail(self)
    frame:SetFrameStrata(menu:GetFrameStrata())
    frame:SetFrameLevel(math.min((sf:GetFrameLevel() or 1) + 205, 9000))
    frame:Show()
    self:Repaint()
end

function Rail:Hide()
    if self.frame then self.frame:Hide() end
end
