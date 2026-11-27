local _, ns = ...
local KT = (ns and ns.KT) or _G.KT
local Mod = KT and KT:GetModule("Enhancements", true)
local B = Mod and Mod.BattlegroundHistory
if not B then return end

local LText = KT.LText or function(k) return k end
local function T(en) return LText(en) end

local HISTORY_ROW_H = 26
local WIDTH, HEIGHT = 1260, 640

local function fontPath()
    local config = B:Config()
    local profile = KT.db and KT.db.profile
    local key = config.font or (profile and profile.globalFont and profile.globalFont.font) or "Avant Garde"
    if KT.ResolveFontPath then return KT:ResolveFontPath(key) end
    return "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
end
local function label(parent, size, x, y, width, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(fontPath(), size, "OUTLINE")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if KT.EnableTextFontFallback then KT:EnableTextFontFallback(fs, fontPath()) end
    if width then fs:SetWidth(width) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    fs:SetTextColor(.93, .93, .93)
    B.fontStrings = B.fontStrings or {}
    B.fontStrings[#B.fontStrings + 1] = { fs = fs, size = size }
    return fs
end
local function accent()
    local p = KT.GetStylePalette and KT:GetStylePalette()
    local c = p and p.accent
    return c and c.r or 1, c and c.g or .72, c and c.b or .14
end
local function button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, height or 25)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(0, 0, 0, .25)
    b:SetBackdropBorderColor(.4, .37, .3, 1)
    local fs = label(b, 10, 0, 0, width - 8, "CENTER")
    fs:ClearAllPoints(); fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(text)
    return b
end
local function panel(parent, x, y, width, height)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetPoint("TOPLEFT", x, y)
    p:SetSize(width, height)
    p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    p:SetBackdropColor(0, 0, 0, .25)
    return p
end

local function num(v) return type(v) == "number" and string.format("%.0f", v) or "--" end
local function signed(v)
    if type(v) ~= "number" then return "--" end
    if v > 0 then return "|cff33ff66+" .. v .. "|r" end
    if v < 0 then return "|cffff4444" .. v .. "|r" end
    return "|cffaaaaaa0|r"
end
local function compact(v)
    if type(v) ~= "number" then return "--" end
    if v >= 1e6 then return string.format("%.1fm", v / 1e6) end
    if v >= 1e3 then return string.format("%.0fk", v / 1e3) end
    return string.format("%.0f", v)
end
local function clockText(seconds)
    if type(seconds) ~= "number" then return "--:--" end
    seconds = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function when(stamp) return stamp and date("%d/%m %H:%M", stamp) or "--" end

local RESULT = {
    win = { "VICTORY", .35, .95, .32 }, loss = { "DEFEAT", 1, .35, .3 }, draw = { "DRAW", .85, .85, .85 },
}
local function resultText(match)
    local r = RESULT[match.result or ""]
    if not r then return "|cffaaaaaa--|r", .7, .7, .7 end
    return T(r[1]), r[2], r[3], r[4]
end
local FACTION_COLOR = { Horde = "|cffff5a4a", Alliance = "|cff4a9eff" }
local function factionText(name)
    if not name then return "--" end
    return (FACTION_COLOR[name] or "|cffffffff") .. T(name) .. "|r"
end
function B:KindText(match)
    if match.kind == "blitz" then return T("Battleground Blitz") end
    if match.kind == "rated" then return T("Rated battleground") end
    if match.kind == "brawl" then return T("Brawl") end
    return T("Battleground")
end

-- Filters: type (rated or not), result and map. They only change what is
-- listed and summarised; the saved history is never touched.
local FILTER_KINDS = { "all", "rated", "unrated" }
local FILTER_RESULTS = { "all", "win", "loss" }
local FILTER_TEXT = {
    all = "All", rated = "Rated", unrated = "Unrated", win = "Victories", loss = "Defeats",
}
function B:Filters()
    self.filters = self.filters or { kind = "all", result = "all" }
    return self.filters
end
function B:Filtered(matches)
    local filters, list = self:Filters(), {}
    for _, match in ipairs(matches) do
        local ok = true
        if filters.kind == "rated" and not match.rated then ok = false end
        if filters.kind == "unrated" and match.rated then ok = false end
        if filters.result ~= "all" and match.result ~= filters.result then ok = false end
        if filters.map and match.map ~= filters.map then ok = false end
        if ok then list[#list + 1] = match end
    end
    return list
end
function B:Summary(list)
    local wins, losses = 0, 0
    for _, match in ipairs(list) do
        if match.result == "win" then wins = wins + 1 elseif match.result == "loss" then losses = losses + 1 end
    end
    local decided = wins + losses
    return { total = #list, wins = wins, losses = losses, rate = decided > 0 and wins / decided * 100 or nil }
end
local function nextIn(values, current)
    for index, value in ipairs(values) do
        if value == current then return values[index % #values + 1] end
    end
    return values[1]
end
function B:CycleFilter(which)
    local filters = self:Filters()
    if which == "kind" then
        filters.kind = nextIn(FILTER_KINDS, filters.kind)
    elseif which == "result" then
        filters.result = nextIn(FILTER_RESULTS, filters.result)
    elseif which == "map" then
        local maps, seen = { false }, {}
        for _, match in ipairs(self.demoMatches or self:Matches()) do
            if match.map and not seen[match.map] then seen[match.map] = true; maps[#maps + 1] = match.map end
        end
        filters.map = nextIn(maps, filters.map or false) or nil
    end
    if self.window then self:Render(self.selectedID) end
end

local STAT_CELLS = {
    { "Killing Blows", "kills" }, { "Honorable Kills", "honorableKills" }, { "Deaths", "deaths" },
    { "Damage", "damage", true }, { "Healing", "healing", true }, { "Honor", "honor" },
}
local TEAM_ROWS = {
    { "Players", "players" }, { "Killing Blows", "kills" }, { "Honorable Kills", "honorableKills" },
    { "Deaths", "deaths" }, { "Damage", "damage", true }, { "Healing", "healing", true },
}
local function statsText(stats)
    local parts = {}
    for _, stat in ipairs(stats or {}) do parts[#parts + 1] = stat.name .. " |cffffffff" .. num(stat.value) .. "|r" end
    return #parts > 0 and table.concat(parts, "   ") or ""
end

function B:CreateWindow()
    if self.window then return self.window end
    local f = CreateFrame("Frame", "KullThranUIBattlegroundHistory", UIParent, "BackdropTemplate")
    self.window = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    -- Above KullThranUIMenu (FULLSCREEN_DIALOG), as the arena history window.
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(10)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local height, width = UIParent:GetHeight(), UIParent:GetWidth()
    if height and width then
        f:SetScale(math.max(.5, math.min(1, (height - 35) / HEIGHT, (width - 35) / WIDTH)))
    end
    KT:ApplyTexturedSurface(f)
    f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropBorderColor(accent())
    f.title = label(f, 19, 22, -17, 900)
    f.title:SetText(T("Battleground History"))
    local close = button(f, "X", 27)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() f:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = "KullThranUIBattlegroundHistory"
    if KT.TextFit then KT.TextFit:Watch("KullThranUIBattlegroundHistory") end

    f.hero = panel(f, 18, -51, 1224, 92)
    f.hero:SetBackdropColor(0, 0, 0, .3)
    f.hero.kicker = label(f.hero, 10, 14, -10, 900)
    f.hero.name = label(f.hero, 24, 14, -28, 800)
    f.hero.status = label(f.hero, 20, 1000, -30, 210, "RIGHT")
    f.hero.facts = label(f.hero, 12, 14, -66, 1190)

    -- The player's own line from the scoreboard.
    f.mine = panel(f, 18, -151, 600, 124)
    f.mine.title = label(f.mine, 11, 10, -8, 300)
    f.mine.title:SetText(T("YOUR SCORE"))
    f.mine.cells = {}
    for i, cell in ipairs(STAT_CELLS) do
        local x = 10 + (i - 1) * 98
        local h = label(f.mine, 9, x, -32, 94)
        h:SetText(T(cell[1])); h:SetTextColor(.6, .6, .6)
        f.mine.cells[i] = label(f.mine, 17, x, -48, 94)
    end
    f.mine.stats = label(f.mine, 11, 10, -84, 580)
    f.mine.rating = label(f.mine, 11, 10, -104, 580)

    -- Both teams side by side, summed from every scoreboard line.
    f.teams = panel(f, 624, -151, 618, 124)
    f.teams.head = { label(f.teams, 11, 170, -8, 210, "RIGHT"), label(f.teams, 11, 390, -8, 210, "RIGHT") }
    f.teams.rows = {}
    for i, row in ipairs(TEAM_ROWS) do
        local y = -26 - (i - 1) * 15
        local name = label(f.teams, 10, 10, y, 160)
        name:SetText(T(row[1])); name:SetTextColor(.6, .6, .6)
        f.teams.rows[i] = { label(f.teams, 11, 170, y, 210, "RIGHT"), label(f.teams, 11, 390, y, 210, "RIGHT") }
    end

    -- Summary and filters of the list below.
    f.summary = label(f, 13, 22, -290, 640)
    f.filterKind = button(f, "", 150)
    f.filterKind:SetPoint("TOPRIGHT", -342, -284)
    f.filterKind:SetScript("OnClick", function() B:CycleFilter("kind") end)
    f.filterResult = button(f, "", 150)
    f.filterResult:SetPoint("TOPRIGHT", -186, -284)
    f.filterResult:SetScript("OnClick", function() B:CycleFilter("result") end)
    f.filterMap = button(f, "", 160)
    f.filterMap:SetPoint("TOPRIGHT", -22, -284)
    f.filterMap:SetScript("OnClick", function() B:CycleFilter("map") end)

    label(f, 12, 22, -322, 600):SetText(T("BATTLEGROUNDS  -  click to view the match"))
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -342)
    scroll:SetPoint("BOTTOMRIGHT", -42, 36)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1190, 1)
    scroll:SetScrollChild(child)
    f.history, f.historyRows = child, {}
    f.footer = label(f, 10, 22, -616, 1200)
    f.footer:SetText(T("Last 100 battlegrounds per character. Data comes from Blizzard's end-of-match scoreboard; -- = unavailable."))
    return f
end

local function fillSelected(f, selected, kicker)
    f.hero.kicker:SetText(kicker .. "  |  " .. when(selected.completedAt) .. "  |  " .. B:KindText(selected))
    f.hero.name:SetText("|cffF5F5DC" .. (selected.map or T("Battleground")) .. "|r")
    local status, r, g, b = resultText(selected)
    f.hero.status:SetText(status)
    f.hero.status:SetTextColor(r, g, b)
    local facts = {
        T("Duration") .. " |cffffffff" .. clockText(selected.duration) .. "|r",
        T("Faction") .. " " .. factionText(selected.faction),
        selected.rated and T("Rated") or T("Unrated"),
    }
    f.hero.facts:SetText(table.concat(facts, "   |   "))

    local me = selected.player or {}
    for i, cell in ipairs(STAT_CELLS) do
        f.mine.cells[i]:SetText(cell[3] and compact(me[cell[2]]) or num(me[cell[2]]))
    end
    f.mine.stats:SetText(statsText(me.stats))
    if selected.rated or type(me.ratingChange) == "number" then
        f.mine.rating:SetText(T("Rating") .. " |cffFF9900" .. num(me.rating) .. "|r (" .. signed(me.ratingChange) .. ")")
    else
        f.mine.rating:SetText("")
    end

    local teams = selected.teams or {}
    local mine = selected.team == 1 and 2 or 1
    local order = { teams[mine] or {}, teams[3 - mine] or {} }
    f.teams.head[1]:SetText(T("YOUR TEAM") .. "  " .. factionText(order[1].faction))
    f.teams.head[2]:SetText(T("ENEMY TEAM") .. "  " .. factionText(order[2].faction))
    for i, row in ipairs(TEAM_ROWS) do
        for side = 1, 2 do
            local value = order[side][row[2]]
            f.teams.rows[i][side]:SetText(row[3] and compact(value) or num(value))
        end
    end
end

function B:Render(selectedID)
    local f = self:CreateWindow()
    local all = self.demoMatches or self:Matches()
    local filters = self:Filters()
    local matches = self:Filtered(all)
    local summary = self:Summary(matches)
    f.summary:SetText(string.format("%s |cffffffff%d|r   %s |cff33ff66%d|r   %s |cffff4444%d|r   %s |cffFF9900%s|r",
        T("Matches"), summary.total, T("Victories"), summary.wins, T("Defeats"), summary.losses,
        T("Win rate"), summary.rate and string.format("%.0f%%", summary.rate) or "--"))
    f.filterKind:SetText(T("Type") .. ": " .. T(FILTER_TEXT[filters.kind]))
    f.filterResult:SetText(T("Result") .. ": " .. T(FILTER_TEXT[filters.result]))
    f.filterMap:SetText(T("Map") .. ": " .. (filters.map or T("All")))

    local selected = matches[1]
    for _, match in ipairs(matches) do if match.id == selectedID then selected = match; break end end
    if not selected then
        f.hero.kicker:SetText(#all > 0 and T("NO MATCHES FOR THESE FILTERS") or T("NO BATTLEGROUNDS YET"))
        f.hero.name:SetText(#all > 0 and "" or T("Finish a battleground to start"))
        f.hero.status:SetText(""); f.hero.facts:SetText("")
        f.mine:Hide(); f.teams:Hide()
        for _, row in ipairs(f.historyRows) do row:Hide() end
        f.history:SetHeight(1)
        self.selectedID = nil
        return
    end
    self.selectedID = selected.id
    f.mine:Show(); f.teams:Show()
    local kicker = self.demoMatches and T("PREVIEW - NOT SAVED")
        or (selected == all[1] and T("LATEST MATCH") or T("SELECTED MATCH"))
    fillSelected(f, selected, kicker)

    for index, match in ipairs(matches) do
        local row = f.historyRows[index]
        if not row then
            row = CreateFrame("Button", nil, f.history, "BackdropTemplate")
            row:SetSize(1190, HISTORY_ROW_H - 2)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            row.date = label(row, 11, 10, -6, 110)
            row.map = label(row, 11, 125, -6, 280)
            row.kind = label(row, 11, 410, -6, 190)
            row.result = label(row, 11, 605, -6, 130)
            row.duration = label(row, 11, 740, -6, 70)
            row.faction = label(row, 11, 815, -6, 100)
            row.score = label(row, 11, 920, -6, 260)
            row:SetScript("OnClick", function(self) B:Render(self.matchID) end)
            f.historyRows[index] = row
        end
        row:SetPoint("TOPLEFT", 0, -(index - 1) * HISTORY_ROW_H)
        row.matchID = match.id
        row.date:SetText(when(match.completedAt))
        row.map:SetText(match.map or T("Battleground"))
        row.kind:SetText(self:KindText(match))
        local text, rr, rg, rb = resultText(match)
        row.result:SetText(text); row.result:SetTextColor(rr, rg, rb)
        row.duration:SetText(clockText(match.duration))
        row.faction:SetText(factionText(match.faction))
        local me = match.player or {}
        row.score:SetText(string.format("%s %s  %s %s  %s %s", T("KB"), num(me.kills), T("Deaths"), num(me.deaths),
            T("Damage"), compact(me.damage)))
        local isSelected = match.id == selected.id
        row:SetBackdropColor(0, 0, 0, isSelected and .7 or .35)
        local ar, ag, ab = accent()
        row:SetBackdropBorderColor(ar, ag, ab, isSelected and 1 or 0)
        row:Show()
    end
    for i = #matches + 1, #f.historyRows do f.historyRows[i]:Hide() end
    f.history:SetHeight(math.max(1, #matches * HISTORY_ROW_H))
end

function B:RefreshStyle()
    for _, entry in ipairs(self.fontStrings or {}) do
        entry.fs:SetFont(fontPath(), entry.size, "OUTLINE")
    end
    if self.window and self.window:IsShown() then self:Render(self.selectedID) end
end

function B:Show(id)
    if not self:Available() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    self.demoMatches = nil
    self:Render(id)
    self.window:Show()
end

function B:Preview()
    if not self:Available() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    -- Preview data stays in memory and never enters the saved history.
    local stamp = GetServerTime and GetServerTime() or time()
    local maps = {
        { "Warsong Gulch", { "Flag Captures", "Flag Returns" } }, { "Arathi Basin", { "Bases Assaulted", "Bases Defended" } },
        { "Alterac Valley", { "Graveyards Assaulted", "Towers Assaulted" } }, { "Eye of the Storm", { "Flag Captures" } },
    }
    local kinds = { "normal", "normal", "rated", "brawl", "normal", "blitz" }
    self.demoMatches = {}
    for i = 1, 10 do
        local map = maps[(i - 1) % #maps + 1]
        local kind = kinds[(i - 1) % #kinds + 1]
        local won = i % 3 ~= 0
        local team = i % 2
        local stats = {}
        for s, name in ipairs(map[2]) do stats[s] = { name = name, value = (i + s) % 4 } end
        local rated = kind == "rated" or kind == "blitz"
        local function side(index, players)
            return { faction = index == 0 and "Horde" or "Alliance", players = players, size = players,
                kills = 40 + i * 3 + index * 5, honorableKills = 180 + i * 7, deaths = 35 + i * 2 - index * 4,
                damage = 9.5e7 + i * 2.1e6, healing = 6.1e7 + index * 3e6, stats = {} }
        end
        local size = map[1] == "Alterac Valley" and 40 or 10
        self.demoMatches[i] = {
            id = "demo" .. i, completedAt = stamp - (i - 1) * 2100, map = map[1], kind = kind, rated = rated,
            duration = 600 + i * 83, result = won and "win" or "loss", team = team,
            faction = team == 0 and "Horde" or "Alliance",
            player = { kills = 4 + i % 5, honorableKills = 20 + i * 2, deaths = i % 4, damage = 8.2e6 + i * 4e5,
                healing = 1.1e6, honor = rated and 0 or 300 + i * 10, rating = rated and 1800 + i or nil,
                ratingChange = rated and (won and 18 or -15) or nil, stats = stats },
            teams = { side(0, size), side(1, size) },
        }
    end
    self:Render()
    self.window:Show()
end

function Mod:ShowBattlegroundHistory() B:Show() end
SLASH_KULLTHRANBGHISTORY1 = "/ktbgs"
SlashCmdList.KULLTHRANBGHISTORY = function(msg)
    if msg and msg:lower():match("^test") then B:Preview() else B:Show() end
end
