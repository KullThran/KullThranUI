local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

--[[
    ArmoryProgressPage.lua

    The Character panel's Progress page (ArmoryProgressBridge calls
    Page:Refresh). Top to bottom:
      rating   Mythic+ rating card: keystone, score in its rarity colour,
               best key, timed dungeons and this week's runs
      dungeons every season dungeon as a row over its art: best key, name,
               chests (stars) or a clock when over time, time and score
      vault    Great Vault: Dungeons / Raids / World, three slots each
               (unlocked slots show their reward level), weekly reset
      raids    one card per saved raid: difficulty pill, a segment per boss,
               then the bosses (portrait, killed check)
    Headers and icons follow the Armory's Visual Style (AR.Styles stats
    tokens, AR.StatStyle drawing); without them the page keeps a plain look.
    Data collection (Collect*) has no UI and is tested on its own.
]]

local Page = {}
KT.ArmoryProgressPage = Page

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local PAD, GAP = 4, 4
local MUTED = { 0.62, 0.62, 0.66 }
local GREEN = { 0.25, 0.9, 0.35 }
-- Raid difficulty colours by difficulty ID (LFR, Normal, Heroic, Mythic).
local DIFFICULTY_COLORS = {
    [17] = { 0, 0.44, 0.87 }, [14] = { 0.12, 1, 0 }, [15] = { 0.64, 0.21, 0.93 }, [16] = { 1, 0.5, 0 },
}
local RAID_DIFFICULTY_LABELS = {
    [14] = PLAYER_DIFFICULTY1 or "Normal",
    [15] = PLAYER_DIFFICULTY2 or "Heroic",
    [16] = PLAYER_DIFFICULTY6 or "Mythic",
    [17] = RAID_FINDER or "LFR",
}

local function LText(text)
    local L = KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

local function FormatReset(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    if days > 0 then return string.format("%dd %dh", days, hours) end
    return string.format("%dh %dm", hours, math.floor((seconds % 3600) / 60))
end

local function FormatClock(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function RGB(color, fallback)
    if type(color) == "table" then
        if color.r then return { color.r, color.g, color.b } end
        if color[1] then return { color[1], color[2], color[3] } end
    end
    return fallback
end

-------------------------------------------------------------------------------
--  Data
-------------------------------------------------------------------------------

-- Chests for a timed key: +3 within 60 % of the limit, +2 within 80 %.
function Page.Stars(duration, limit, overTime)
    duration, limit = tonumber(duration), tonumber(limit)
    if overTime or not duration or not limit or limit <= 0 or duration > limit then return 0 end
    local ratio = duration / limit
    if ratio <= 0.6 then return 3 end
    if ratio <= 0.8 then return 2 end
    return 1
end

function Page:CollectRating()
    local score = 0
    local summary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary
        and C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    if summary and summary.currentSeasonScore then
        score = summary.currentSeasonScore
    elseif C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
        score = C_ChallengeMode.GetOverallDungeonScore() or 0
    end
    local color = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor
        and C_ChallengeMode.GetDungeonScoreRarityColor(score)
    -- This week's completed keys (timed or not), as the vault counts them.
    local week = C_MythicPlus and C_MythicPlus.GetRunHistory and C_MythicPlus.GetRunHistory(false, false) or {}
    return { score = score, color = RGB(color, { 1, 1, 1 }), weekRuns = #week }
end

-- Every dungeon of the season with its best run, best score first.
function Page:CollectDungeons()
    local list = {}
    local maps = C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable() or {}
    for _, mapID in ipairs(maps) do
        local name, _, timeLimit, texture, background = C_ChallengeMode.GetMapUIInfo(mapID)
        local runs, overall
        if C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap then
            runs, overall = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapID)
        end
        local best
        for _, run in ipairs(runs or {}) do
            local level, better = tonumber(run.level) or 0, false
            if not best or level > best.level then
                better = true
            elseif level == best.level and not run.overTime and best.overTime then
                better = true
            end
            if better then
                best = { level = level, duration = run.durationSec, overTime = run.overTime and true or false }
            end
        end
        local score = tonumber(overall) or 0
        local scoreColor = C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor
            and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(score)
        local levelColor = best and C_ChallengeMode.GetKeystoneLevelRarityColor
            and C_ChallengeMode.GetKeystoneLevelRarityColor(best.level)
        list[#list + 1] = {
            mapID = mapID, name = name or ("#" .. tostring(mapID)), texture = texture, background = background,
            timeLimit = timeLimit, score = score,
            level = best and best.level or 0, duration = best and best.duration, overTime = best and best.overTime,
            stars = best and Page.Stars(best.duration, timeLimit, best.overTime) or 0,
            color = RGB(scoreColor, nil), levelColor = RGB(levelColor, nil),
        }
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.name < b.name
    end)
    return list
end

local VAULT_TRACKS = {
    { key = "dungeons", glyph = "keystone", type = "Activities", label = function() return DUNGEONS or "Dungeons" end,
        detail = function(a) local l = tonumber(a.level) or 0; return l > 0 and ("+" .. l) or nil end },
    { key = "raids", glyph = "raid", type = "Raid", label = function() return RAIDS or "Raids" end,
        detail = function(a) return RAID_DIFFICULTY_LABELS[a.level] end },
    { key = "world", glyph = "world", type = "World", label = function() return LText("World") end,
        detail = function(a)
            local l = tonumber(a.level) or 0
            return l > 0 and string.format(GREAT_VAULT_WORLD_TIER or "Tier %s", l) or nil
        end },
}

-- Great Vault rows (nil without the weekly rewards API) and the weekly reset.
function Page:CollectVault()
    if C_AddOns and C_AddOns.LoadAddOn and not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
    end
    local types = Enum and Enum.WeeklyRewardChestThresholdType
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities and types) then return nil end
    local tracks = {}
    for _, def in ipairs(VAULT_TRACKS) do
        local kind = types[def.type]
        if kind then
            local activities = C_WeeklyRewards.GetActivities(kind) or {}
            table.sort(activities, function(a, b) return (a.index or 0) < (b.index or 0) end)
            local track = { key = def.key, glyph = def.glyph, label = def.label(), slots = {}, done = 0 }
            for i = 1, math.min(3, #activities) do
                local a = activities[i]
                local progress, threshold = tonumber(a.progress) or 0, tonumber(a.threshold) or 0
                local done = threshold > 0 and progress >= threshold
                track.slots[i] = { done = done, progress = math.min(progress, threshold), threshold = threshold,
                    detail = done and def.detail(a) or nil }
                if done then track.done = track.done + 1 end
            end
            tracks[#tracks + 1] = track
        end
    end
    local reset = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    return tracks, reset
end

-- Saved raids this week with their bosses.
function Page:CollectRaids()
    local raids = {}
    -- No RequestRaidInfo here: its UPDATE_INSTANCE_INFO refreshes the page
    -- again. The Bridge asks when the pane opens.
    if not GetNumSavedInstances then return raids end
    for i = 1, GetNumSavedInstances() do
        local name, _, reset, difficultyID, locked, _, _, isRaid, _, difficultyName, total, killed = GetSavedInstanceInfo(i)
        if isRaid and locked then
            local raid = {
                name = name or (RAID or "Raid"), reset = reset, difficulty = difficultyName or "",
                color = DIFFICULTY_COLORS[difficultyID] or { 0.7, 0.7, 0.7 },
                total = tonumber(total) or 0, killed = tonumber(killed) or 0, bosses = {},
            }
            for e = 1, raid.total do
                local bossName, texture, isKilled = GetSavedInstanceEncounterInfo(i, e)
                if bossName then
                    raid.bosses[#raid.bosses + 1] = { name = bossName, texture = texture ~= 0 and texture or nil,
                        killed = isKilled and true or false }
                end
            end
            raids[#raids + 1] = raid
        end
    end
    return raids
end

-- Asks the server for Mythic+ data at most every 30 s: its
-- CHALLENGE_MODE_MAPS_UPDATE refreshes the page, which must not ask again.
local MAP_INFO_INTERVAL = 30
function Page:RequestMapInfo()
    if not (C_MythicPlus and C_MythicPlus.RequestMapInfo) then return false end
    local now = GetTime and GetTime() or 0
    if self.lastMapInfo and now - self.lastMapInfo < MAP_INFO_INTERVAL then return false end
    self.lastMapInfo = now
    C_MythicPlus.RequestMapInfo()
    return true
end

-------------------------------------------------------------------------------
--  Drawing helpers
-------------------------------------------------------------------------------
local ctx -- per refresh: content, tokens, statStyle, font, accent, bridge

local function Font(path)
    if KT.ResolveFontForLocale then return KT:ResolveFontForLocale(path, path) or path end
    return path
end

local function Text(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(DEFAULT_FONT, size or 10, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    -- Without flags the text takes the style's own (OUTLINE on Forever/Classic).
    fs._ktSize, fs._ktFlags = size or 10, flags
    return fs
end

-- Applies the style's font to a FontString (keeps its size).
local function Restyle(fs)
    fs:SetFont(ctx.font, fs._ktSize, fs._ktFlags or ctx.flags)
end

local function Color(fs, c, a)
    fs:SetTextColor(c[1], c[2], c[3], a or 1)
end

local function Border(frame, c, a)
    if KT.AddBorder then KT:AddBorder(frame, c[1], c[2], c[3], a or 1) end
end

-- Puts a progress glyph on a texture; hides it when the style has none.
local function Glyph(tex, name, tint)
    local ok = ctx.statStyle and ctx.statStyle.SetProgressGlyph
        and ctx.statStyle:SetProgressGlyph(tex, ctx.tokens, name)
    tex:SetShown(ok and true or false)
    if ok and tint then tex:SetVertexColor(tint[1], tint[2], tint[3]) end
    return ok
end

local function Pool(key, create)
    local pool = ctx.content._ktPage[key]
    if not pool then
        pool = { used = 0 }
        ctx.content._ktPage[key] = pool
    end
    pool.used = pool.used + 1
    local item = pool[pool.used]
    if not item then
        item = create()
        pool[pool.used] = item
    end
    item:Show()
    return item
end

local function ResetPools(store)
    for _, pool in pairs(store) do
        if type(pool) == "table" and pool.used then
            for i = 1, #pool do pool[i]:Hide() end
            pool.used = 0
        end
    end
end

local function Tooltip(frame, lines)
    frame.tooltipLines = lines
    if frame._ktTooltip then return end
    frame._ktTooltip = true
    frame:SetScript("OnEnter", function(self)
        if not (self.tooltipLines and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i, line in ipairs(self.tooltipLines) do
            if i == 1 then GameTooltip:SetText(line, 1, 1, 1) else GameTooltip:AddLine(line, 0.85, 0.85, 0.85, true) end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-------------------------------------------------------------------------------
--  Pieces
-------------------------------------------------------------------------------

-- Section header in the style's look (plate / tab / fade); click folds it.
local function Header(y, key, title)
    local h = Pool("headers", function()
        local f = CreateFrame("Button", nil, ctx.content)
        f:SetHeight(22)
        f.title = Text(f, 12, "OUTLINE")
        f.lineLeft = f:CreateTexture(nil, "ARTWORK")
        f.lineRight = f:CreateTexture(nil, "ARTWORK")
        f.lineLeft:SetHeight(1); f.lineRight:SetHeight(1)
        f.fold = Text(f, 10, "OUTLINE")
        f.fold:SetPoint("RIGHT", f, "RIGHT", -4, 0)
        f:SetScript("OnClick", function(self)
            if self.bridge and self.key then self.bridge:ToggleSection(self.key) end
        end)
        return f
    end)
    h.key, h.bridge = key, ctx.bridge
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", PAD, y)
    h:SetWidth(ctx.width - 2 * PAD)
    h.title:ClearAllPoints()
    h.title:SetPoint("CENTER", h, "CENTER", 0, 0)
    h.title:SetText(title)
    Restyle(h.title)
    -- StatStyle:Header may have cleared the shadow for another style.
    h.title:SetShadowOffset(1, -1)
    h.title:SetShadowColor(0, 0, 0, 0.9)
    h.lineLeft:ClearAllPoints(); h.lineRight:ClearAllPoints()
    h.lineLeft:SetPoint("LEFT", h, "LEFT", 4, 0); h.lineLeft:SetPoint("RIGHT", h.title, "LEFT", -6, 0)
    h.lineRight:SetPoint("LEFT", h.title, "RIGHT", 6, 0); h.lineRight:SetPoint("RIGHT", h, "RIGHT", -16, 0)
    local a = ctx.accent
    h.lineLeft:SetColorTexture(a[1], a[2], a[3], 0.45); h.lineRight:SetColorTexture(a[1], a[2], a[3], 0.45)
    h.lineLeft:Show(); h.lineRight:Show()
    local styled = ctx.statStyle and ctx.statStyle:Header(h, h.title, { h.lineLeft, h.lineRight }, ctx.tokens)
    if not styled then Color(h.title, a) end
    local collapsed = ctx.bridge and ctx.bridge:IsSectionCollapsed(key)
    h.fold:SetText(collapsed and "+" or "-")
    Color(h.fold, MUTED)
    -- A plate fills the row: the dimmed title alone shows the fold there.
    h.fold:SetShown(not (styled and ctx.tokens.header and ctx.tokens.header.kind == "plate"))
    h.title:SetAlpha(collapsed and 0.55 or 1)
    return y - 26, collapsed
end

-- A muted line with an icon on the right (weekly reset) or a centred note.
local function Note(y, text, glyph)
    local n = Pool("notes", function()
        local f = CreateFrame("Frame", nil, ctx.content)
        f:SetHeight(14)
        f.text = Text(f, 9)
        f.text:SetWordWrap(false)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(11, 11)
        return f
    end)
    n:ClearAllPoints()
    n:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", PAD, y)
    n:SetWidth(ctx.width - 2 * PAD)
    Restyle(n.text)
    n.text:SetText(text)
    Color(n.text, MUTED)
    n.text:ClearAllPoints()
    n.icon:ClearAllPoints()
    if glyph and Glyph(n.icon, glyph, ctx.glyphTint and MUTED) then
        n.text:SetPoint("RIGHT", n, "RIGHT", -2, 0)
        n.icon:SetPoint("RIGHT", n.text, "LEFT", -3, 0)
    elseif glyph then
        n.text:SetPoint("RIGHT", n, "RIGHT", -2, 0)
    else
        n.icon:Hide()
        n.text:SetPoint("LEFT", n, "LEFT", 2, 0)
        n.text:SetPoint("RIGHT", n, "RIGHT", -2, 0)
        n.text:SetJustifyH("CENTER")
    end
    return y - 16
end

local function RatingCard(y, rating, dungeons)
    local c = Pool("rating", function()
        local f = CreateFrame("Frame", nil, ctx.content, "BackdropTemplate")
        f:SetHeight(66)
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints()
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(34, 34)
        f.icon:SetPoint("LEFT", f, "LEFT", 10, 0)
        f.label = Text(f, 8)
        f.label:SetPoint("TOPLEFT", f, "TOPLEFT", 54, -7)
        f.score = Text(f, 20, "OUTLINE")
        f.score:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", -1, -2)
        f.best = Text(f, 9)
        f.best:SetPoint("TOPLEFT", f.score, "BOTTOMLEFT", 1, -3)
        f.best:SetPoint("RIGHT", f, "RIGHT", -6, 0)
        f.week = Text(f, 9)
        f.week:SetPoint("TOPLEFT", f.best, "BOTTOMLEFT", 0, -2)
        f.week:SetPoint("RIGHT", f, "RIGHT", -6, 0)
        for _, fs in ipairs({ f.label, f.best, f.week }) do
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
        end
        f.label:SetPoint("RIGHT", f, "RIGHT", -6, 0)
        return f
    end)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", PAD, y)
    c:SetWidth(ctx.width - 2 * PAD)
    local sc = rating.color
    c.bg:SetColorTexture(0, 0, 0, 0.4)
    Border(c, ctx.accent, 0.45)
    Glyph(c.icon, "keystone")
    for _, fs in ipairs({ c.label, c.score, c.best, c.week }) do Restyle(fs) end
    c.label:SetText(string.upper(DUNGEON_SCORE or LText("Mythic+ Rating")))
    Color(c.label, MUTED)
    c.score:SetText(rating.score > 0 and tostring(math.floor(rating.score + 0.5)) or "0")
    Color(c.score, sc)
    local bestLevel, timed = 0, 0
    for _, d in ipairs(dungeons) do
        if d.level > bestLevel then bestLevel = d.level end
        if d.level > 0 and not d.overTime then timed = timed + 1 end
    end
    local best = bestLevel > 0 and string.format(LText("Best +%d"), bestLevel) or ""
    if #dungeons > 0 then
        best = (best ~= "" and (best .. "  ·  ") or "") .. string.format(LText("%d/%d timed"), timed, #dungeons)
    end
    c.best:SetText(best)
    Color(c.best, { 0.86, 0.86, 0.9 })
    c.week:SetText(string.format(LText("This week: %d runs"), rating.weekRuns or 0))
    Color(c.week, MUTED)
    return y - 72
end

-- One season dungeon per row: the dungeon art fading out from the left, the
-- best key, the name, then chests (or a clock), the time and the score.
local ROW_H = 30
local function DungeonRow(y, d, index)
    local t = Pool("tiles", function()
        local f = CreateFrame("Button", nil, ctx.content)
        f:SetHeight(ROW_H)
        f.band = f:CreateTexture(nil, "BACKGROUND", nil, 0)
        f.band:SetAllPoints()
        f.art = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        f.art:SetPoint("TOPLEFT")
        f.art:SetPoint("BOTTOMLEFT")
        f.shade = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        f.shade:SetAllPoints(f.art)
        f.shade:SetTexture(WHITE)
        if f.shade.SetGradient and CreateColor then
            f.shade:SetGradient("HORIZONTAL", CreateColor(0.04, 0.04, 0.05, 0.35), CreateColor(0.04, 0.04, 0.05, 1))
        else
            f.shade:SetVertexColor(0.04, 0.04, 0.05, 0.7)
        end
        f.edge = f:CreateTexture(nil, "ARTWORK")
        f.edge:SetPoint("TOPLEFT"); f.edge:SetPoint("BOTTOMLEFT")
        f.edge:SetWidth(2)
        f.level = Text(f, 14, "OUTLINE")
        f.level:SetPoint("LEFT", f, "LEFT", 7, 0)
        f.name = Text(f, 10)
        f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 44, -4)
        f.name:SetPoint("RIGHT", f, "RIGHT", -6, 0)
        f.name:SetJustifyH("LEFT")
        f.name:SetWordWrap(false)
        f.time = Text(f, 8)
        f.score = Text(f, 9)
        f.score:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 4)
        f.marks = {}
        for i = 1, 3 do
            f.marks[i] = f:CreateTexture(nil, "ARTWORK")
            f.marks[i]:SetSize(10, 10)
            f.marks[i]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 44 + (i - 1) * 10, 3)
        end
        return f
    end)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", PAD, y)
    t:SetWidth(ctx.width - 2 * PAD)
    t.band:SetColorTexture(1, 1, 1, index % 2 == 1 and 0.04 or 0.015)
    t.art:SetWidth(math.min(120, (ctx.width - 2 * PAD) * 0.65))
    t.art:SetTexture(d.background or d.texture)
    if d.background then t.art:SetTexCoord(0, 0.7, 0.35, 0.6) else t.art:SetTexCoord(0.08, 0.92, 0.4, 0.6) end
    t.art:SetDesaturated(d.level == 0)
    t.art:SetAlpha(d.level == 0 and 0.35 or 0.8)
    for _, fs in ipairs({ t.level, t.name, t.time, t.score }) do Restyle(fs) end
    local ran = d.level > 0
    local lc = d.levelColor or d.color or ctx.accent
    local good = ran and not d.overTime
    local edge = good and (d.color or lc) or { 0.35, 0.35, 0.38 }
    t.edge:SetColorTexture(edge[1], edge[2], edge[3], ran and 1 or 0.5)
    t.level:SetText(ran and ("+" .. d.level) or "-")
    Color(t.level, good and lc or MUTED)
    t.name:SetText(d.name)
    Color(t.name, ran and { 0.95, 0.95, 0.97 } or { 0.6, 0.6, 0.63 })
    local shown = 0
    for i, mark in ipairs(t.marks) do
        local on = false
        if ran and d.overTime then
            on = i == 1 and Glyph(mark, "clock", ctx.glyphTint and MUTED)
        elseif i <= d.stars then
            on = Glyph(mark, "star", ctx.glyphTint and { 1, 0.82, 0.25 })
        end
        if on then shown = shown + 1 else mark:Hide() end
    end
    t.time:ClearAllPoints()
    t.time:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 44 + shown * 10 + (shown > 0 and 4 or 0), 4)
    t.time:SetText(ran and d.duration and FormatClock(d.duration) or "")
    Color(t.time, MUTED)
    t.score:SetText(d.score > 0 and tostring(math.floor(d.score + 0.5)) or "")
    Color(t.score, d.color or { 0.92, 0.92, 0.92 })
    local tip = { d.name }
    if ran then
        tip[#tip + 1] = string.format("+%d  ·  %s / %s", d.level, FormatClock(d.duration), FormatClock(d.timeLimit))
        tip[#tip + 1] = string.format("%s: %d", DUNGEON_SCORE or LText("Mythic+ Rating"), math.floor(d.score + 0.5))
    end
    Tooltip(t, tip)
    return y - ROW_H - 2
end

local function VaultTrack(y, track)
    local width = ctx.width - 2 * PAD
    local r = Pool("trackHeads", function()
        local f = CreateFrame("Frame", nil, ctx.content)
        f:SetHeight(16)
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(14, 14)
        f.icon:SetPoint("LEFT", f, "LEFT", 1, 0)
        f.label = Text(f, 10)
        f.count = Text(f, 9)
        f.count:SetPoint("RIGHT", f, "RIGHT", -2, 0)
        return f
    end)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", PAD, y)
    r:SetWidth(width)
    Restyle(r.label); Restyle(r.count)
    r.label:ClearAllPoints()
    if Glyph(r.icon, track.glyph) then
        r.label:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    else
        r.label:SetPoint("LEFT", r, "LEFT", 2, 0)
    end
    r.label:SetText(track.label)
    Color(r.label, { 0.94, 0.94, 0.96 })
    r.count:SetText(string.format("%d/3", track.done))
    Color(r.count, track.done >= 3 and GREEN or MUTED)
    y = y - 18
    local bw = (width - 2 * GAP) / 3
    local a = ctx.accent
    for i = 1, 3 do
        local slot = track.slots[i] or { done = false, progress = 0, threshold = 0 }
        local b = Pool("slots", function()
            local f = CreateFrame("Frame", nil, ctx.content, "BackdropTemplate")
            f:SetHeight(18)
            f.fill = f:CreateTexture(nil, "BACKGROUND")
            f.fill:SetAllPoints()
            f.bar = f:CreateTexture(nil, "ARTWORK")
            f.bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 2)
            f.bar:SetHeight(2)
            f.icon = f:CreateTexture(nil, "ARTWORK")
            f.icon:SetSize(11, 11)
            f.icon:SetPoint("LEFT", f, "LEFT", 4, 0)
            f.text = Text(f, 9)
            f.text:SetJustifyH("CENTER")
            f.text:SetWordWrap(false)
            return f
        end)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", PAD + (i - 1) * (bw + GAP), y)
        b:SetWidth(bw)
        Restyle(b.text)
        b.text:ClearAllPoints()
        if slot.done then
            b.fill:SetColorTexture(a[1] * 0.3, a[2] * 0.3, a[3] * 0.3, 0.9)
            Border(b, a, 0.9)
            b.bar:Hide()
            local icon = Glyph(b.icon, "vault")
            if icon then
                b.text:SetPoint("LEFT", b.icon, "RIGHT", 2, 0)
            else
                b.text:SetPoint("LEFT", b, "LEFT", 3, 0)
            end
            b.text:SetPoint("RIGHT", b, "RIGHT", -3, 0)
            b.text:SetText(slot.detail or "")
            Color(b.text, { 1, 1, 1 })
        else
            b.fill:SetColorTexture(0.07, 0.07, 0.08, 0.9)
            Border(b, { 0.3, 0.3, 0.33 }, 0.9)
            b.icon:Hide()
            b.text:SetPoint("LEFT", b, "LEFT", 3, 1)
            b.text:SetPoint("RIGHT", b, "RIGHT", -3, 1)
            b.text:SetText(slot.threshold > 0 and string.format("%d/%d", slot.progress, slot.threshold) or "")
            Color(b.text, MUTED)
            local frac = slot.threshold > 0 and slot.progress / slot.threshold or 0
            if frac > 0 then
                b.bar:SetColorTexture(a[1], a[2], a[3], 0.75)
                b.bar:SetWidth(math.max(2, (bw - 4) * frac))
                b.bar:Show()
            else
                b.bar:Hide()
            end
        end
    end
    return y - 24
end

local function RaidCard(y, raid)
    local width = ctx.width - 2 * PAD
    local c = Pool("raidCards", function()
        local f = CreateFrame("Frame", nil, ctx.content, "BackdropTemplate")
        f:SetHeight(32)
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints()
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(18, 18)
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -3)
        f.name = Text(f, 10)
        f.name:SetJustifyH("LEFT")
        f.name:SetWordWrap(false)
        f.pill = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.pill:SetHeight(12)
        f.pill:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        f.pill.bg = f.pill:CreateTexture(nil, "BACKGROUND")
        f.pill.bg:SetAllPoints()
        f.pill.text = Text(f.pill, 8)
        f.pill.text:SetPoint("CENTER", f.pill, "CENTER", 0, 0)
        f.name:SetPoint("RIGHT", f.pill, "LEFT", -4, 0)
        f.segments = {}
        return f
    end)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", PAD, y)
    c:SetWidth(width)
    local dc = raid.color
    c.bg:SetColorTexture(0, 0, 0, 0.4)
    Border(c, dc, 0.5)
    Restyle(c.name); Restyle(c.pill.text)
    c.name:ClearAllPoints()
    if Glyph(c.icon, "raid") then
        c.name:SetPoint("LEFT", c.icon, "RIGHT", 4, 0)
    else
        c.name:SetPoint("LEFT", c, "TOPLEFT", 6, -12)
    end
    c.name:SetPoint("RIGHT", c.pill, "LEFT", -4, 0)
    c.name:SetText(raid.name)
    Color(c.name, { 0.95, 0.95, 0.97 })
    c.pill.text:SetText(raid.difficulty)
    Color(c.pill.text, { 1, 1, 1 })
    c.pill:SetWidth((c.pill.text:GetStringWidth() or 30) + 12)
    c.pill.bg:SetColorTexture(dc[1] * 0.35, dc[2] * 0.35, dc[3] * 0.35, 0.95)
    Border(c.pill, dc, 1)
    local n = math.max(1, raid.total)
    local left = Glyph(c.icon, "raid") and 26 or 6
    local segW = (width - left - 4 - (n - 1) * 2) / n
    for i = 1, math.max(n, #c.segments) do
        local seg = c.segments[i]
        if not seg then
            seg = c:CreateTexture(nil, "ARTWORK")
            seg:SetHeight(4)
            c.segments[i] = seg
        end
        if i <= raid.total then
            seg:ClearAllPoints()
            seg:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", left + (i - 1) * (segW + 2), 5)
            seg:SetWidth(segW)
            if i <= raid.killed then seg:SetColorTexture(dc[1], dc[2], dc[3], 1) else seg:SetColorTexture(0.22, 0.22, 0.24, 1) end
            seg:Show()
        else
            seg:Hide()
        end
    end
    local tip = { raid.name, string.format("%s  %d/%d", raid.difficulty, raid.killed, raid.total),
        string.format(LText("Resets in %s"), FormatReset(raid.reset)) }
    c:EnableMouse(true)
    Tooltip(c, tip)
    y = y - 36
    for i, boss in ipairs(raid.bosses) do
        local r = Pool("bossRows", function()
            local f = CreateFrame("Frame", nil, ctx.content)
            f:SetHeight(17)
            f.band = f:CreateTexture(nil, "BACKGROUND")
            f.band:SetAllPoints()
            f.portrait = f:CreateTexture(nil, "ARTWORK")
            f.portrait:SetSize(14, 14)
            f.portrait:SetPoint("LEFT", f, "LEFT", 4, 0)
            f.name = Text(f, 9)
            f.name:SetPoint("LEFT", f.portrait, "RIGHT", 6, 0)
            f.name:SetPoint("RIGHT", f, "RIGHT", -20, 0)
            f.name:SetJustifyH("LEFT")
            f.name:SetWordWrap(false)
            f.mark = f:CreateTexture(nil, "ARTWORK")
            f.mark:SetSize(11, 11)
            f.mark:SetPoint("RIGHT", f, "RIGHT", -4, 0)
            f.dash = Text(f, 9)
            f.dash:SetPoint("RIGHT", f, "RIGHT", -5, 0)
            return f
        end)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", PAD, y)
        r:SetWidth(width)
        r.band:SetColorTexture(1, 1, 1, i % 2 == 1 and 0.035 or 0)
        if boss.texture then
            r.portrait:SetTexture(boss.texture)
            r.portrait:SetTexCoord(0.15, 0.85, 0.05, 0.75)
            r.portrait:SetDesaturated(not boss.killed)
            r.portrait:SetAlpha(boss.killed and 1 or 0.6)
            r.portrait:Show()
        else
            r.portrait:Hide()
        end
        Restyle(r.name); Restyle(r.dash)
        r.name:SetText(boss.name)
        Color(r.name, boss.killed and { 0.92, 0.92, 0.95 } or { 0.55, 0.55, 0.58 })
        if boss.killed then
            r.dash:Hide()
            if not Glyph(r.mark, "check", ctx.glyphTint and GREEN) then Color(r.name, GREEN) end
        else
            r.mark:Hide()
            r.dash:SetText("-"); r.dash:Show(); Color(r.dash, { 0.4, 0.4, 0.43 })
        end
        y = y - 17
    end
    return y - 8
end

-------------------------------------------------------------------------------
--  Refresh
-------------------------------------------------------------------------------

-- Draws the page into `content` (the Progress scroll child). getStyle()
-- returns the Armory's stats tokens and StatStyle (or nil); bridge supplies
-- IsSectionCollapsed / ToggleSection. Returns the content height.
function Page:Refresh(content, getStyle, bridge)
    content._ktPage = content._ktPage or {}
    local tokens, statStyle
    if getStyle then tokens, statStyle = getStyle() end
    local accent = { KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.33 }
    if tokens and statStyle and statStyle.ResolveColor then
        local source = (tokens.tabs and tokens.tabs.accent) or "accent"
        local r, g, b = statStyle.ResolveColor(source)
        if r then accent = { r, g, b } end
    end
    -- The scroll child takes its scroll frame's visible width (the scroll bar
    -- sits outside it), so nothing is cut on the right.
    local scroll = content.GetParent and content:GetParent()
    local visible = scroll and scroll.GetWidth and scroll:GetWidth()
    if visible and visible > 0 then content:SetWidth(visible) end
    local width = content:GetWidth()
    ctx = {
        content = content, tokens = tokens, statStyle = statStyle, bridge = bridge, accent = accent,
        width = (width and width > 0) and width or 190,
        font = Font((tokens and tokens.font) or DEFAULT_FONT), flags = tokens and tokens.flags or "",
        -- Only the tinted (KUI glass) atlas takes colours; the others keep their material.
        glyphTint = tokens and tokens.progress and tokens.progress.tint ~= nil,
    }
    ResetPools(content._ktPage)
    self:RequestMapInfo()

    local y = -6
    local rating, dungeons = self:CollectRating(), self:CollectDungeons()
    y = RatingCard(y, rating, dungeons)

    local collapsed
    y, collapsed = Header(y, "dungeons", DUNGEONS or "Dungeons")
    if not collapsed then
        if #dungeons == 0 then
            y = Note(y, LText("No Mythic+ runs this season"))
        else
            for i, d in ipairs(dungeons) do y = DungeonRow(y, d, i) end
        end
    end
    y = y - 6

    y, collapsed = Header(y, "vault", GREAT_VAULT_TITLE or "Great Vault")
    if not collapsed then
        local tracks, reset = self:CollectVault()
        if reset then y = Note(y, string.format(LText("Resets in %s"), FormatReset(reset)), "clock") end
        for _, track in ipairs(tracks or {}) do y = VaultTrack(y, track) end
    end
    y = y - 4

    y, collapsed = Header(y, "raids", RAIDS or "Raids")
    if not collapsed then
        local raids = self:CollectRaids()
        if #raids == 0 then y = Note(y, LText("No raid lockouts this week")) end
        for _, raid in ipairs(raids) do y = RaidCard(y, raid) end
    end

    local height = math.abs(y) + 12
    content:SetHeight(height)
    ctx = nil
    return height
end
