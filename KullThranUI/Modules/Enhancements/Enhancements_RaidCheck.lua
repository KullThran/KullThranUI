-------------------------------------------------------------------------------
--  Raid Check: consumables panel for ready checks.
--
--  Port of the Details! "Raid Check" plugin. When a ready check starts and you
--  lead the group (or assist, if allowed), a panel lists every member with the
--  food, flask, augment rune and pre-pot state, so you see who is missing what
--  before the pull. Click a report button to announce the missing names in
--  party / raid chat. /ktraidcheck toggles the panel by hand.
--
--  Buffs are read through C_UnitAuras with the classic UnitBuff fallback, so it
--  works on Retail and on the Forever client. Anything the client hides
--  (secret auras in combat) shows as "?" instead of "missing".
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then return end

local floor, max, min = math.floor, math.max, math.min
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local issecretvalue = _G.issecretvalue or function() return false end

local function LText(text)
    if type(text) == "string" and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then return L[text] end
    end
    return text
end

local function Config()
    local db = Mod.GetDB and Mod:GetDB() or nil
    local cfg
    if db then
        db.raidCheck = db.raidCheck or {}
        cfg = db.raidCheck
    else
        cfg = {}
    end
    local defaults = {
        enable = true, onReadyCheck = true, leaderOnly = true,
        checkFood = true, checkFlask = true, checkRune = true, checkPrePot = true,
        prePotHealers = false, prePotTanks = false,
        firstFourGroups = true, autoHide = 15, scale = 1,
    }
    for key, value in pairs(defaults) do
        if cfg[key] == nil then cfg[key] = value end
    end
    return cfg
end

-------------------------------------------------------------------------------
--  Consumable data
--  Details ships empty Midnight lists, so IDs are only a head start: food and
--  flasks are also recognised by the aura name ("Well Fed", "Flask of ...").
-------------------------------------------------------------------------------
local FLASK_IDS = {
    [431973] = true, [431972] = true, [431971] = true, [431974] = true, [432021] = true, [432473] = true,
    [46377] = true, [46376] = true, [54213] = true, [46379] = true, [53899] = true,
}
local FOOD_IDS = {
    [457173] = true, [457174] = true,
    [57367] = true, [57294] = true, [57365] = true, [57360] = true, [57358] = true, [57356] = true,
    [57334] = true, [57332] = true, [57329] = true, [57327] = true, [57325] = true, [57291] = true,
    [57288] = true, [57286] = true, [57139] = true, [57111] = true,
}
local RUNE_IDS = {
    [393438] = true, [453250] = true, [347901] = true, [367405] = true, [270058] = true,
    [317065] = true, [224001] = true, [1234969] = true,
}
local POTION_IDS = {
    [431419] = true, [431416] = true, [431914] = true, [431932] = true, [453205] = true, [453162] = true,
    [453283] = true, [431925] = true, [431941] = true, [431418] = true, [431422] = true, [431432] = true,
    [431424] = true, [460074] = true, [1238009] = true,
    [53762] = true, [53908] = true, [53909] = true, [53753] = true, [43185] = true, [53761] = true,
    [43186] = true,
}

local FLASK_WORDS = {
    enUS = { "flask", "phial" }, enGB = { "flask", "phial" },
    esES = { "frasco", "redoma" }, esMX = { "frasco", "redoma" },
    deDE = { "fläschchen", "phiole" }, frFR = { "flacon", "fiole" },
    itIT = { "matraccio", "fiala" }, ptBR = { "frasco", "ampola" },
    ruRU = { "настой", "склян" }, koKR = { "영약", "비약" },
    zhCN = { "合剂" }, zhTW = { "精鍊" },
}

local function SpellName(spellId)
    if _G.C_Spell and _G.C_Spell.GetSpellName then
        local ok, name = pcall(_G.C_Spell.GetSpellName, spellId)
        if ok and name then return name end
    end
    if _G.GetSpellInfo then
        local ok, name = pcall(_G.GetSpellInfo, spellId)
        if ok and type(name) == "string" then return name end
    end
end

local wellFedName, flaskWords, eatingNames
local function InitNames()
    if wellFedName then return end
    wellFedName = (SpellName(19705) or "Well Fed"):lower()
    flaskWords = FLASK_WORDS[_G.GetLocale and _G.GetLocale() or "enUS"] or FLASK_WORDS.enUS
    eatingNames = {}
    for _, id in ipairs({ 257428, 430, 433, 192002, 167152 }) do
        local name = SpellName(id)
        if name then eatingNames[name:lower()] = true end
    end
end

-------------------------------------------------------------------------------
--  Aura reading
-------------------------------------------------------------------------------
-- Calls fn(name, icon, spellId) for every readable buff. Returns false when the
-- client hid some of them (secret values), so "missing" is not reported falsely.
local function ForEachBuff(unit, fn)
    local complete = true
    local byIndex = _G.C_UnitAuras and _G.C_UnitAuras.GetAuraDataByIndex
    for index = 1, 80 do
        local ok, name, icon, spellId = pcall(function()
            if byIndex then
                local data = byIndex(unit, index, "HELPFUL")
                if not data then return nil end
                return data.name, data.icon, data.spellId
            end
            local getBuff = _G.UnitBuff or _G.UnitAura
            if not getBuff then return nil end
            local n, ic, _, _, _, _, _, _, _, sid = getBuff(unit, index, "HELPFUL")
            return n, ic, sid
        end)
        if not ok then return false end
        if name == nil and spellId == nil then break end
        if issecretvalue(name) or issecretvalue(spellId) then
            complete = false
        else
            fn(name, icon, spellId)
        end
    end
    return complete
end

local function ScanUnit(unit)
    InitNames()
    local info = { food = nil, flask = nil, rune = nil, eating = false, potion = nil }
    local complete = ForEachBuff(unit, function(name, icon, spellId)
        local lname = type(name) == "string" and name:lower() or ""
        if spellId and FLASK_IDS[spellId] then
            info.flask = info.flask or { icon = icon, spellId = spellId }
        elseif lname ~= "" then
            for _, word in ipairs(flaskWords) do
                if lname:find(word, 1, true) then
                    info.flask = info.flask or { icon = icon, spellId = spellId }
                    break
                end
            end
        end
        if (spellId and FOOD_IDS[spellId]) or (lname ~= "" and lname:find(wellFedName, 1, true)) then
            info.food = info.food or { icon = icon, spellId = spellId }
        end
        if spellId and RUNE_IDS[spellId] then
            info.rune = info.rune or { icon = icon, spellId = spellId }
        end
        if spellId and POTION_IDS[spellId] then
            info.potion = info.potion or { icon = icon, spellId = spellId }
        end
        if lname ~= "" and eatingNames[lname] then info.eating = true end
    end)
    info.complete = complete
    return info
end

-------------------------------------------------------------------------------
--  Roster
-------------------------------------------------------------------------------
local function GroupUnits()
    local units = {}
    if not (_G.IsInGroup and _G.IsInGroup()) then return units end
    local cfg = Config()
    local _, _, difficulty = _G.GetInstanceInfo()
    local limit4 = cfg.firstFourGroups and difficulty == 16

    if _G.IsInRaid() then
        for i = 1, _G.GetNumGroupMembers() do
            local _, _, subgroup = _G.GetRaidRosterInfo(i)
            if not (limit4 and subgroup and subgroup > 4) then
                units[#units + 1] = "raid" .. i
            end
        end
    else
        units[1] = "player"
        for i = 1, _G.GetNumGroupMembers() - 1 do
            units[#units + 1] = "party" .. i
        end
    end
    return units
end

local function UnitDisplayName(unit)
    local name = _G.UnitName(unit)
    if issecretvalue(name) then return "?" end
    return name or _G.UNKNOWN or "?"
end

local prepotByGuid = {}

local function BuildRoster()
    local rows = {}
    for _, unit in ipairs(GroupUnits()) do
        if _G.UnitExists(unit) then
            local guid = _G.UnitGUID(unit)
            local _, class = _G.UnitClass(unit)
            local connected = _G.UnitIsConnected(unit) ~= false
            local info = connected and ScanUnit(unit) or { complete = true }
            local role = _G.UnitGroupRolesAssigned and _G.UnitGroupRolesAssigned(unit) or "NONE"
            local score
            if _G.C_PlayerInfo and _G.C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
                local ok, summary = pcall(_G.C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
                if ok and type(summary) == "table" and summary.currentSeasonScore
                    and not issecretvalue(summary.currentSeasonScore) and summary.currentSeasonScore > 0 then
                    score = summary.currentSeasonScore
                end
            end
            rows[#rows + 1] = {
                unit = unit, name = UnitDisplayName(unit), class = class, role = role,
                guid = guid, connected = connected, info = info, score = score,
                prepot = guid and prepotByGuid[guid] or nil,
            }
        end
    end
    table.sort(rows, function(a, b)
        if (a.class or "") ~= (b.class or "") then return (a.class or "") < (b.class or "") end
        return a.name < b.name
    end)
    return rows
end

-------------------------------------------------------------------------------
--  Missing lists and reports
-------------------------------------------------------------------------------
local function WantsPrePot(row)
    local cfg = Config()
    if row.role == "HEALER" then return cfg.prePotHealers end
    if row.role == "TANK" then return cfg.prePotTanks end
    return true
end

local function Missing(rows, kind)
    local names = {}
    for _, row in ipairs(rows) do
        if row.connected and row.info.complete then
            local missing
            if kind == "foodflask" then
                missing = not row.info.food or not row.info.flask
            elseif kind == "rune" then
                missing = not row.info.rune
            elseif kind == "prepot" then
                missing = WantsPrePot(row) and not row.prepot
            end
            if missing then names[#names + 1] = row.name end
        end
    end
    return names
end

local function SendReport(prefix, names)
    if #names == 0 then
        KT:Print(LText("Nobody is missing this."))
        return
    end
    local channel = "PARTY"
    if _G.IsInRaid() then channel = "RAID" end
    if _G.IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE or 2) then channel = "INSTANCE_CHAT" end
    local line = prefix
    for _, name in ipairs(names) do
        if #line + #name + 1 > 240 then
            _G.SendChatMessage(line, channel)
            line = prefix
        end
        line = line .. " " .. name
    end
    _G.SendChatMessage(line, channel)
end

-------------------------------------------------------------------------------
--  Panel
-------------------------------------------------------------------------------
local ROW_H, MAX_ROWS = 18, 40
local TEX_OK = [[Interface\RaidFrame\ReadyCheck-Ready]]
local TEX_BAD = [[Interface\RaidFrame\ReadyCheck-NotReady]]
local TEX_WAIT = [[Interface\RaidFrame\ReadyCheck-Waiting]]

local panel, rowFrames, refreshTicker, hideToken

local function HeaderIcon(path, label)
    return "|T" .. path .. ":14:14:0:0:64:64:5:59:5:59|t " .. label
end

local function ColumnList()
    local cfg = Config()
    local cols = {}
    if cfg.checkFood then cols[#cols + 1] = { key = "food", label = HeaderIcon([[Interface\Icons\INV_Misc_Food_15]], LText("Food")) } end
    if cfg.checkFlask then cols[#cols + 1] = { key = "flask", label = HeaderIcon([[Interface\Icons\Trade_Alchemy]], LText("Flask")) } end
    if cfg.checkRune then cols[#cols + 1] = { key = "rune", label = HeaderIcon([[Interface\Icons\INV_Misc_Rune_01]], LText("Rune")) } end
    if cfg.checkPrePot then cols[#cols + 1] = { key = "prepot", label = HeaderIcon([[Interface\Icons\INV_Potion_54]], LText("Pre-Pot")) } end
    if _G.C_PlayerInfo and _G.C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        cols[#cols + 1] = { key = "score", label = LText("M+ Score") }
    end
    return cols
end

local NAME_W, COL_W = 150, 76

local function StateTexture(row, key)
    if not row.connected then return nil end
    local info = row.info
    local entry
    if key == "prepot" then
        if not WantsPrePot(row) then return nil end
        entry = row.prepot
    else
        entry = info[key]
    end
    if entry then return entry.icon or TEX_OK, entry.icon ~= nil end
    if key == "food" and info.eating then return TEX_WAIT end
    if not info.complete then return TEX_WAIT end
    return TEX_BAD
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, panel.list)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", panel.list, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT", panel.list, "RIGHT", 0, 0)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetWidth(NAME_W - 8)
    row.name:SetJustifyH("LEFT")
    row.cells = {}
    return row
end

local function GetCell(row, slot)
    local cell = row.cells[slot]
    if not cell then
        cell = {}
        cell.icon = row:CreateTexture(nil, "OVERLAY")
        cell.icon:SetSize(14, 14)
        cell.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.cells[slot] = cell
    end
    return cell
end

local function Refresh()
    if not panel or not panel:IsShown() then return end
    local cols = ColumnList()
    local rows = BuildRoster()
    local shown = min(#rows, MAX_ROWS)

    panel:SetWidth(NAME_W + #cols * COL_W + 24)
    for i, col in ipairs(cols) do
        local header = panel.headers[i]
        if not header then
            header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            panel.headers[i] = header
        end
        header:ClearAllPoints()
        header:SetPoint("TOP", panel.list, "TOPLEFT", NAME_W + (i - 0.5) * COL_W, 16)
        header:SetText(col.label)
        header:Show()
    end
    for i = #cols + 1, #panel.headers do panel.headers[i]:Hide() end

    local missingCount = 0
    for i = 1, MAX_ROWS do
        local row = rowFrames[i] or CreateRow(i)
        rowFrames[i] = row
        local data = rows[i]
        if data and i <= shown then
            row:Show()
            local color = _G.RAID_CLASS_COLORS and data.class and _G.RAID_CLASS_COLORS[data.class]
            if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(1, 1, 1) end
            row.name:SetText(data.connected and data.name or (data.name .. " |cff888888(offline)|r"))
            row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
            for slot, col in ipairs(cols) do
                local cell = GetCell(row, slot)
                cell.icon:ClearAllPoints()
                cell.icon:SetPoint("CENTER", row, "LEFT", NAME_W + (slot - 0.5) * COL_W, 0)
                cell.text:ClearAllPoints()
                cell.text:SetPoint("CENTER", cell.icon, "CENTER", 0, 0)
                cell.icon:Hide()
                cell.text:SetText("")
                if col.key == "score" then
                    if data.score then cell.text:SetText(tostring(floor(data.score))) end
                else
                    local texture, isAura = StateTexture(data, col.key)
                    if texture then
                        cell.icon:SetTexture(texture)
                        if isAura then cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else cell.icon:SetTexCoord(0, 1, 0, 1) end
                        cell.icon:Show()
                        if texture == TEX_BAD then missingCount = missingCount + 1 end
                    end
                end
            end
            for slot = #cols + 1, #row.cells do
                row.cells[slot].icon:Hide()
                row.cells[slot].text:SetText("")
            end
        else
            row:Hide()
        end
    end

    panel.list:SetHeight(max(1, shown * ROW_H))
    panel:SetHeight(shown * ROW_H + 96)
    if #rows == 0 then
        panel.summary:SetText(LText("You are not in a group."))
    elseif missingCount == 0 then
        panel.summary:SetText("|cff55ff55" .. LText("Everyone is ready.") .. "|r")
    else
        panel.summary:SetText("|cffff5555" .. string.format(LText("%d missing consumables"), missingCount) .. "|r")
    end
    panel.rosterCache = rows
end

local function StopTicker()
    if refreshTicker then refreshTicker:Cancel() refreshTicker = nil end
end

local function Hide()
    hideToken = nil
    StopTicker()
    if panel then panel:Hide() end
end

local function MakeButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(100, 20)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function BuildPanel()
    if panel then return panel end
    panel = CreateFrame("Frame", "KullThranUIRaidCheckFrame", _G.UIParent, "BackdropTemplate")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 120)
    KT:AddBackdrop(panel, 0.025, 0.03, 0.045, 0.96)
    KT:AddBorder(panel, 0.4, 0.6, 1, 0.5)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 10, -8)
    panel.title:SetText(LText("Raid Check"))

    panel.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.summary:SetPoint("TOPRIGHT", -28, -10)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", Hide)

    panel.list = CreateFrame("Frame", nil, panel)
    panel.list:SetPoint("TOPLEFT", 10, -48)
    panel.list:SetPoint("RIGHT", -10, 0)
    panel.headers = {}
    rowFrames = {}

    local function report(kind, prefix)
        return function()
            SendReport(prefix, Missing(BuildRoster(), kind))
        end
    end
    panel.btnFood = MakeButton(panel, LText("Report Food/Flask"), report("foodflask", "KullThranUI: No Flask or Food:"))
    panel.btnFood:SetSize(120, 20)
    panel.btnPot = MakeButton(panel, LText("Report Pre-Pot"), report("prepot", "KullThranUI: No Pre-Pot:"))
    panel.btnPot:SetSize(110, 20)
    panel.btnRune = MakeButton(panel, LText("Report Rune"), report("rune", "KullThranUI: No Rune:"))
    panel.btnRune:SetSize(100, 20)
    panel.btnFood:SetPoint("BOTTOMLEFT", 10, 10)
    panel.btnPot:SetPoint("LEFT", panel.btnFood, "RIGHT", 4, 0)
    panel.btnRune:SetPoint("LEFT", panel.btnPot, "RIGHT", 4, 0)

    panel:Hide()
    return panel
end

local function Show()
    BuildPanel()
    local cfg = Config()
    panel:SetScale(max(0.6, min(1.6, cfg.scale or 1)))
    panel.btnPot:SetShown(cfg.checkPrePot)
    panel.btnRune:SetShown(cfg.checkRune)
    panel:Show()
    Refresh()
    StopTicker()
    if C_Timer and C_Timer.NewTicker then
        refreshTicker = C_Timer.NewTicker(1, Refresh)
    end
end

local function Toggle()
    if panel and panel:IsShown() then Hide() else Show() end
end

-------------------------------------------------------------------------------
--  Triggers
-------------------------------------------------------------------------------
local function CanTrigger()
    local cfg = Config()
    if not cfg.enable or not cfg.onReadyCheck then return false end
    if Mod.GetDB and Mod:GetDB().enable == false then return false end
    if not _G.IsInGroup() then return false end
    if _G.UnitIsGroupLeader("player") then return true end
    return not cfg.leaderOnly and _G.UnitIsGroupAssistant("player") == true
end

local function ScanPrePots()
    for _, unit in ipairs(GroupUnits()) do
        local guid = _G.UnitExists(unit) and _G.UnitGUID(unit)
        if guid and not issecretvalue(guid) then
            local info = ScanUnit(unit)
            if info.potion and not prepotByGuid[guid] then prepotByGuid[guid] = info.potion end
        end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "READY_CHECK", "READY_CHECK_FINISHED", "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "READY_CHECK" then
        hideToken = nil
        if CanTrigger() then Show() end
    elseif event == "READY_CHECK_FINISHED" then
        if panel and panel:IsShown() then
            local token = {}
            hideToken = token
            C_Timer.After(max(1, Config().autoHide or 15), function()
                if hideToken == token then Hide() end
            end)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if not Config().enable or not _G.IsInGroup() then return end
        wipe(prepotByGuid)
        -- Auras can be hidden once the pull is under way: read what we can, now and a beat later.
        pcall(ScanPrePots)
        C_Timer.After(2, function() pcall(ScanPrePots) end)
    elseif event == "GROUP_ROSTER_UPDATE" then
        if panel and panel:IsShown() and not _G.IsInGroup() then Hide() end
    end
end)

_G.SLASH_KTRAIDCHECK1 = "/ktraidcheck"
_G.SLASH_KTRAIDCHECK2 = "/ktrc"
_G.SlashCmdList.KTRAIDCHECK = function()
    if not Config().enable then
        KT:Print(LText("Raid Check is disabled in Enhancements."))
        return
    end
    Toggle()
end

Mod.RaidCheck = { Config = Config, Show = Show, Hide = Hide, Toggle = Toggle, Refresh = Refresh }
