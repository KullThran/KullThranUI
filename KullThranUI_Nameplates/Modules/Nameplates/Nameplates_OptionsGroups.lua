-- Nameplates options: the side cards, the page layout that makes room for them and
-- the navigation from the live preview to an option. One text for both clients.

local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)

local Groups = {}
ns.OptionsGroups = Groups

local MEDIA = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\OptionCards\\"
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

local glow
local targets = {}

function Groups.Active()
    local active = KT._npOptionsActiveTab
    for _, card in ipairs(CARDS) do
        if card.id == active then return active end
    end
    KT._npOptionsActiveTab = DEFAULT_GROUP
    return DEFAULT_GROUP
end

-- The options search builds every card: the card ids, the one shown and each
-- card's name.
function Groups.SearchViews()
    local ids, labels = {}, {}
    for _, card in ipairs(CARDS) do
        ids[#ids + 1] = card.id
        labels[card.id] = card.label
    end
    return ids, Groups.Active(), labels
end

function Groups.SetActive(id)
    KT._npOptionsActiveTab = id
end

-- Runs a build for the search index with its own navigation targets, so the
-- page on screen keeps the ones of its real frames.
function Groups.BuildDetached(fn)
    local saved = targets
    targets = {}
    local ok, result = pcall(fn)
    targets = saved
    if not ok then error(result, 0) end
    return result
end

---------------------------------------------------------------------------
-- The cards rail and the page layout: the shared option cards (KullThranUI/OptionCards.lua).
-- Card art: the icons here, the glow, stars and orb in the core.
---------------------------------------------------------------------------
local rail

local function Rail()
    if not rail and KT and KT.OptionCards then
        local list = {}
        for i, card in ipairs(CARDS) do
            list[i] = { id = card.id, label = card.label, icon = MEDIA .. card.id .. ".png" }
        end
        rail = KT.OptionCards.New({
            pageId = "nameplates",
            cards = list,
            default = DEFAULT_GROUP,
            getActive = function() return KT._npOptionsActiveTab end,
            setActive = function(id) KT._npOptionsActiveTab = id end,
        })
    end
    return rail
end

function Groups.EnterLayout(menu)
    local cards = Rail()
    if cards then cards:EnterLayout(menu) end
end

function Groups.LeaveLayout(menu)
    if KT and KT.OptionCards then KT.OptionCards.LeaveLayout(menu) end
end

function Groups.ShowRail(menu)
    local cards = Rail()
    if cards then cards:Show(menu) end
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
