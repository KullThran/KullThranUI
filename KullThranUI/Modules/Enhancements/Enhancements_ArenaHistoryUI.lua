local _, ns = ...
local KT = (ns and ns.KT) or _G.KT
local Mod = KT and KT:GetModule("Enhancements", true)
local A = Mod and Mod.ArenaHistory
if not A then return end

local LText = KT.LText or function(k) return k end
local function T(en) return LText(en) end

local ROWS_PER_TEAM = 6
local HISTORY_ROW_H = 26

local function fontPath()
    local config = A:Config()
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
    A.fontStrings = A.fontStrings or {}
    A.fontStrings[#A.fontStrings + 1] = { fs = fs, size = size }
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
    win = { "VICTORY", .35, .95, .32 }, loss = { "DEFEAT", 1, .35, .3 },
    draw = { "DRAW", .85, .85, .85 }, even = { "EVEN", .95, .82, .3 },
}
local function resultText(match)
    local r = RESULT[match.result or ""]
    if not r then return "|cffaaaaaa--|r", .7, .7, .7 end
    return T(r[1]), r[2], r[3], r[4]
end
function A:BracketText(match)
    if match.bracket == "shuffle" then return T("Solo Shuffle") end
    if match.bracket == "skirmish" then return T("Skirmish") end
    local size = match.size and match.size > 0 and match.size or 3
    if match.bracket == "rated" then return string.format(T("Rated %dv%d"), size, size) end
    return T("Arena") .. string.format(" %dv%d", size, size)
end

-- One table of up to six players: name, spec, damage, healing, KB, deaths, rating.
local COLUMNS = { { "Damage", 330, 70 }, { "Healing", 400, 70 }, { "KB", 470, 34 }, { "Deaths", 504, 46 }, { "Rating", 550, 60 } }
local function teamPanel(parent, x, y, width)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", x, y)
    panel:SetSize(width, 30 + ROWS_PER_TEAM * 24)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    panel:SetBackdropColor(0, 0, 0, .25)
    panel.title = label(panel, 11, 10, -8, 200)
    for _, col in ipairs(COLUMNS) do
        local h = label(panel, 9, col[2], -10, col[3], "RIGHT")
        h:SetText(T(col[1])); h:SetTextColor(.6, .6, .6)
    end
    panel.rows = {}
    for i = 1, ROWS_PER_TEAM do
        local row, ry = {}, -30 - (i - 1) * 24
        row.name = label(panel, 12, 10, ry, 160)
        row.spec = label(panel, 10, 172, ry - 1, 150)
        row.spec:SetTextColor(.7, .7, .7)
        row.cells = {}
        for c, col in ipairs(COLUMNS) do row.cells[c] = label(panel, 11, col[2], ry, col[3], "RIGHT") end
        panel.rows[i] = row
    end
    return panel
end
local function fillPanel(panel, title, players)
    panel.title:SetText(title)
    panel.title:SetTextColor(accent())
    for i, row in ipairs(panel.rows) do
        local p = players[i]
        local shown = p ~= nil
        row.name:SetShown(shown); row.spec:SetShown(shown)
        for _, cell in ipairs(row.cells) do cell:SetShown(shown) end
        if p then
            row.name:SetText(p.name or "?")
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class or ""]
            row.name:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
            row.spec:SetText(p.spec or "")
            row.cells[1]:SetText(compact(p.damage))
            row.cells[2]:SetText(compact(p.healing))
            row.cells[3]:SetText(num(p.kills))
            row.cells[4]:SetText(num(p.deaths))
            row.cells[5]:SetText(signed(p.ratingChange))
        end
    end
end

function A:CreateWindow()
    if self.window then return self.window end
    local f = CreateFrame("Frame", "KullThranUIArenaHistory", UIParent, "BackdropTemplate")
    self.window = f
    f:SetSize(1260, 640)
    f:SetPoint("CENTER")
    -- Above KullThranUIMenu (FULLSCREEN_DIALOG), as the Mythic+ history window.
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(10)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local height, width = UIParent:GetHeight(), UIParent:GetWidth()
    if height and width then
        f:SetScale(math.max(.5, math.min(1, (height - 35) / 640, (width - 35) / 1260)))
    end
    KT:ApplyTexturedSurface(f)
    f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropBorderColor(accent())
    f.title = label(f, 19, 22, -17, 900)
    f.title:SetText(T("Arena History"))
    local close = button(f, "X", 27)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() f:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = "KullThranUIArenaHistory"

    f.hero = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.hero:SetPoint("TOPLEFT", 18, -51)
    f.hero:SetSize(1224, 92)
    f.hero:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    f.hero:SetBackdropColor(0, 0, 0, .3)
    f.hero.kicker = label(f.hero, 10, 14, -10, 900)
    f.hero.name = label(f.hero, 24, 14, -28, 800)
    f.hero.status = label(f.hero, 20, 1000, -30, 210, "RIGHT")
    f.hero.facts = label(f.hero, 12, 14, -66, 1190)

    local panelW = 612
    f.ours = teamPanel(f, 18, -155, panelW)
    f.theirs = teamPanel(f, 18 + panelW, -155, panelW)

    label(f, 12, 22, -335, 600):SetText(T("PREVIOUS ARENAS  -  click to view the match"))
    local latest = button(f, T("Latest match"), 135)
    latest:SetPoint("TOPRIGHT", -22, -330)
    latest:SetScript("OnClick", function() A:Render() end)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -358)
    scroll:SetPoint("BOTTOMRIGHT", -42, 36)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1190, 1)
    scroll:SetScrollChild(child)
    f.history, f.historyRows = child, {}
    f.footer = label(f, 10, 22, -616, 1200)
    f.footer:SetText(T("Last 100 arenas per character. Data comes from Blizzard's end-of-match scoreboard; -- = unavailable."))
    return f
end

function A:Render(selectedID)
    local f = self:CreateWindow()
    local matches = self.demoMatches or self:Matches()
    local selected = matches[1]
    for _, match in ipairs(matches) do if match.id == selectedID then selected = match; break end end
    if not selected then
        f.hero.kicker:SetText(T("NO ARENAS YET"))
        f.hero.name:SetText(T("Finish an arena to start"))
        f.hero.status:SetText(""); f.hero.facts:SetText("")
        f.ours:Hide(); f.theirs:Hide()
        for _, row in ipairs(f.historyRows) do row:Hide() end
        f.history:SetHeight(1)
        return
    end
    self.selectedID = selected.id
    f.ours:Show()

    local kicker = self.demoMatches and T("PREVIEW - NOT SAVED")
        or (selected == matches[1] and T("LATEST MATCH") or T("SELECTED MATCH"))
    f.hero.kicker:SetText(kicker .. "  |  " .. when(selected.completedAt) .. "  |  " .. self:BracketText(selected))
    f.hero.name:SetText("|cffF5F5DC" .. (selected.map or T("Arena")) .. "|r")
    local status, r, g, b = resultText(selected)
    f.hero.status:SetText(status)
    f.hero.status:SetTextColor(r, g, b)
    local facts = { T("Duration") .. " |cffffffff" .. clockText(selected.duration) .. "|r" }
    if selected.bracket == "shuffle" then
        facts[#facts + 1] = T("Rounds won") .. " |cffffffff" .. num(selected.rounds) .. "/6|r"
    end
    if selected.rated or type(selected.rating) == "number" then
        local after = type(selected.rating) == "number" and type(selected.ratingChange) == "number"
            and selected.rating + selected.ratingChange
        facts[#facts + 1] = T("Rating") .. " |cffFF9900" .. num(selected.rating) .. " > " .. num(after) .. "|r ("
            .. signed(selected.ratingChange) .. ")"
        facts[#facts + 1] = T("MMR") .. " |cffffffff" .. num(selected.mmrBefore) .. " > " .. num(selected.mmrAfter) .. "|r"
    end
    f.hero.facts:SetText(table.concat(facts, "   |   "))

    -- Solo Shuffle teams change every round: show the whole lobby together.
    local ours, theirs = {}, {}
    for _, p in ipairs(selected.players or {}) do
        if selected.bracket == "shuffle" or p.team == selected.team then ours[#ours + 1] = p else theirs[#theirs + 1] = p end
    end
    local byDamage = function(x, y) return (x.damage or 0) > (y.damage or 0) end
    table.sort(ours, byDamage); table.sort(theirs, byDamage)
    if selected.bracket == "shuffle" then
        fillPanel(f.ours, T("LOBBY"), ours)
        f.theirs:Hide()
    else
        fillPanel(f.ours, T("YOUR TEAM"), ours)
        fillPanel(f.theirs, T("ENEMY TEAM"), theirs)
        f.theirs:Show()
    end

    for index = 2, #matches do
        local match = matches[index]
        local row = f.historyRows[index - 1]
        if not row then
            row = CreateFrame("Button", nil, f.history, "BackdropTemplate")
            row:SetSize(1190, HISTORY_ROW_H - 2)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            row.date = label(row, 11, 10, -6, 110)
            row.map = label(row, 11, 125, -6, 330)
            row.bracket = label(row, 11, 460, -6, 200)
            row.result = label(row, 11, 670, -6, 160)
            row.rating = label(row, 11, 840, -6, 160)
            row:SetScript("OnClick", function(self) A:Render(self.matchID) end)
            f.historyRows[index - 1] = row
        end
        row:SetPoint("TOPLEFT", 0, -(index - 2) * HISTORY_ROW_H)
        row.matchID = match.id
        row.date:SetText(when(match.completedAt))
        row.map:SetText(match.map or T("Arena"))
        row.bracket:SetText(self:BracketText(match))
        local text, rr, rg, rb = resultText(match)
        row.result:SetText(text); row.result:SetTextColor(rr, rg, rb)
        row.rating:SetText(signed(match.ratingChange))
        local isSelected = match.id == selected.id
        row:SetBackdropColor(0, 0, 0, isSelected and .7 or .35)
        local ar, ag, ab = accent()
        row:SetBackdropBorderColor(ar, ag, ab, isSelected and 1 or 0)
        row:Show()
    end
    for i = math.max(1, #matches), #f.historyRows do f.historyRows[i]:Hide() end
    f.history:SetHeight(math.max(1, (#matches - 1) * HISTORY_ROW_H))
end

function A:RefreshStyle()
    for _, entry in ipairs(self.fontStrings or {}) do
        entry.fs:SetFont(fontPath(), entry.size, "OUTLINE")
    end
    if self.window and self.window:IsShown() then self:Render(self.selectedID) end
end

local function Unavailable()
    KT:Print(T("Arenas are not available on the WoW Forever client, so Arena History is disabled there."))
end

function A:Show(id)
    if not self:Available() then Unavailable(); return end
    if InCombatLockdown and InCombatLockdown() then return end
    self.demoMatches = nil
    self:Render(id)
    self.window:Show()
end

function A:Preview()
    if not self:Available() then Unavailable(); return end
    if InCombatLockdown and InCombatLockdown() then return end
    -- Preview data stays in memory and never enters the saved history.
    local stamp = GetServerTime and GetServerTime() or time()
    local roster = {
        { "Valeera", "ROGUE", "Subtlety" }, { "Jaina", "MAGE", "Frost" }, { "Anduin", "PRIEST", "Discipline" },
        { "Thrall", "SHAMAN", "Enhancement" }, { "Rexxar", "HUNTER", "Marksmanship" }, { "Lili", "MONK", "Mistweaver" },
    }
    local maps = { "Nagrand Arena", "Blade's Edge Arena", "Dalaran Sewers", "Ruins of Lordaeron", "Mugambala", "Enigma Crucible" }
    local brackets = { { "rated", 3 }, { "shuffle", 3 }, { "rated", 2 }, { "skirmish", 3 }, { "rated", 3 }, { "shuffle", 3 } }
    self.demoMatches = {}
    for i = 1, 8 do
        local bracket, size = brackets[(i - 1) % #brackets + 1][1], brackets[(i - 1) % #brackets + 1][2]
        local won = i % 3 ~= 0
        local change = bracket == "skirmish" and 0 or (won and 14 + i or -(9 + i))
        local match = {
            id = "demo" .. i, completedAt = stamp - (i - 1) * 1500, map = maps[(i - 1) % #maps + 1],
            bracket = bracket, rated = bracket ~= "skirmish", size = size, duration = 140 + i * 37,
            team = 0, rating = 2100 - i * 9, ratingChange = change,
            mmrBefore = 2150 - i * 8, mmrAfter = 2150 - i * 8 + change, players = {},
        }
        if bracket == "shuffle" then
            match.rounds = won and 4 or 2
            match.result = won and "win" or "loss"
        else
            match.result = won and "win" or "loss"
        end
        local count = bracket == "shuffle" and 6 or size * 2
        for j = 1, count do
            local data = roster[(j + i - 2) % #roster + 1]
            local mine = bracket == "shuffle" or j <= size
            match.players[j] = {
                name = data[1], class = data[2], spec = data[3], team = mine and 0 or 1,
                damage = 2.4e6 - j * 1.9e5 + i * 4e4, healing = (data[3] == "Discipline" or data[3] == "Mistweaver") and 2.1e6 or 1.4e5,
                kills = (j % 3 == 0) and 1 or 0, deaths = mine and (won and 0 or 1) or (won and 1 or 0),
                ratingChange = mine and change or -change,
            }
        end
        self.demoMatches[i] = match
    end
    self:Render()
    self.window:Show()
end

function Mod:ShowArenaHistory() A:Show() end
SLASH_KULLTHRANARENAHISTORY1 = "/ktarenas"
SlashCmdList.KULLTHRANARENAHISTORY = function(msg)
    if msg and msg:lower():match("^test") then A:Preview() else A:Show() end
end
