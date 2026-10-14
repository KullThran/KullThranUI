-- PerfMonitor: CPU / memory per KullThranUI module, in a floating window.
-- /kperf or /kuiperf (see Mod:OnEnable).
--
-- Rules so that measuring does not change what is measured:
--   * No hooks, no registered events, no permanent OnUpdate: the only thing that
--     runs is one C_Timer ticker while the window is visible (cancelled on close).
--   * CPU comes from C_AddOnProfiler (the client's own counters; no reload and no
--     scriptProfile). Without it, it falls back to GetAddOnCPUUsage.
--   * Memory (UpdateAddOnMemoryUsage walks all Lua memory) is refreshed every
--     MEM_EVERY samples, never on every tick.
--   * Because this lives in the core addon, its own cost would be billed to the
--     "Core" row. It is measured directly (GetTimePreciseSec), shown in the footer,
--     and subtracted from that row.
-- Snapshots live in KT.db.global.perfSnapshots (the core's own SavedVariables).

local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Perf = KT:NewModule("PerfMonitor")
KT.PerfMonitor = Perf

local _G = _G
local floor, max, min = math.floor, math.max, math.min
local format, sort, wipe = string.format, table.sort, wipe
local pairs, ipairs, type, pcall, tostring = pairs, ipairs, type, pcall, tostring
local GetTimePreciseSec = _G.GetTimePreciseSec

local SAMPLE_INTERVAL = 1     -- seconds between CPU samples
local MEM_EVERY = 5           -- one in N samples refreshes memory
local ROWS = 18
local ROW_H = 18

local PREFIX = "KullThranUI"
local COLOR = { 0.96, 0.26, 0.36 }
local SUITE_ID = "KUI"        -- kept in row ids so older snapshots stay comparable

local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

-- Resolved at access time so a locale change is picked up.
local TEXT = {
    title = "Perf Monitor", modules = "Modules", compare = "vs Snapshot", module = "Module",
    now = "Now", avg = "Avg", peak = "Peak", mem = "Mem", delta = "Delta",
    reset = "Reset", freeze = "Freeze", unfreeze = "Resume", snap = "Snapshot",
    base = "Base", memCmp = "Mem now/base", own = "own", samples = "samples",
    frozen = "frozen", legacy = "legacy mode",
}
local L = setmetatable({}, { __index = function(_, key) return LText(TEXT[key] or key) end })

---------------------------------------------------------------------------
-- Data access
---------------------------------------------------------------------------
local Profiler = _G.C_AddOnProfiler
local AddOns = _G.C_AddOns
local M = Enum and Enum.AddOnProfilerMetric

local function ProfilerOK()
    if not (Profiler and M and Profiler.GetAddOnMetric) then return false end
    if Profiler.IsEnabled then
        local ok, enabled = pcall(Profiler.IsEnabled)
        if ok and not enabled then return false end
    end
    return true
end

local function Metric(name, which)
    if not which then return nil end
    local ok, v = pcall(Profiler.GetAddOnMetric, name, which)
    if ok and type(v) == "number" then return v end
    return nil
end

local function IsLoaded(name)
    if AddOns and AddOns.IsAddOnLoaded then return AddOns.IsAddOnLoaded(name) end
    return _G.IsAddOnLoaded and _G.IsAddOnLoaded(name)
end

local function AddOnName(i)
    if AddOns and AddOns.GetAddOnInfo then
        local a = AddOns.GetAddOnInfo(i)
        if type(a) == "table" then return a.name end
        return a
    end
    return (_G.GetAddOnInfo(i))
end

local function NumAddOns()
    if AddOns and AddOns.GetNumAddOns then return AddOns.GetNumAddOns() end
    return _G.GetNumAddOns()
end

local function LegacyCPU(name)
    local f = (AddOns and AddOns.GetAddOnCPUUsage) or _G.GetAddOnCPUUsage
    return f and f(name) or 0
end

local function MemKB(name)
    local f = (AddOns and AddOns.GetAddOnMemoryUsage) or _G.GetAddOnMemoryUsage
    return f and f(name) or 0
end

local function Say(msg)
    local text = "|cff66ccffKUI Perf|r " .. tostring(msg)
    if KT.Print then KT:Print(text) else print(text) end
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
Perf.addons, Perf.data = {}, {}
Perf.samples, Perf.frozen, Perf.tab, Perf.scroll = 0, false, "modules", 0

-- Snapshots persist in the core's AceDB (global scope).
local function Snapshots(create)
    local g = KT.db and KT.db.global
    if not g then return nil end
    if create then g.perfSnapshots = g.perfSnapshots or {} end
    return g.perfSnapshots
end

local function ModuleKey(name)
    local rest = name:sub(#PREFIX + 1):gsub("^_", "")
    return rest == "" and "Core" or rest
end

-- Loaded KullThranUI addons (rebuilt every time the window opens).
function Perf:Scan()
    wipe(self.addons)
    for i = 1, NumAddOns() do
        local name = AddOnName(i)
        if name and name:sub(1, #PREFIX) == PREFIX and IsLoaded(name) then
            self.addons[#self.addons + 1] = { name = name, key = ModuleKey(name) }
        end
    end
end

local function Row(self, key)
    local id = SUITE_ID .. ":" .. key
    local r = self.data[id]
    if not r then
        r = { suite = SUITE_ID, key = key, now = 0, sum = 0, n = 0, peak = 0, over1 = 0, mem = 0 }
        self.data[id] = r
    end
    return r
end

function Perf:Reset()
    wipe(self.data)
    self.samples = 0
    self.selfNow, self.selfMem = 0, nil
end

function Perf:Sample()
    if self.frozen then return end
    self.samples = self.samples + 1
    local useProfiler = ProfilerOK()
    self.usingProfiler = useProfiler
    local doMem = (self.samples % MEM_EVERY == 1)
    if doMem and _G.UpdateAddOnMemoryUsage then _G.UpdateAddOnMemoryUsage() end
    if not useProfiler and _G.UpdateAddOnCPUUsage then _G.UpdateAddOnCPUUsage() end

    local acc = {}
    for _, a in ipairs(self.addons) do
        local now, peak, over1
        if useProfiler then
            now = Metric(a.name, M.RecentAverageTime)
            peak = Metric(a.name, M.PeakTime)
            over1 = Metric(a.name, M.CountTimeOver1Ms)
        else
            local total = LegacyCPU(a.name)
            self.legacy = self.legacy or {}
            local prev = self.legacy[a.name]
            self.legacy[a.name] = total
            now = prev and (total - prev) / SAMPLE_INTERVAL / max(_G.GetFramerate and _G.GetFramerate() or 60, 1) or 0
        end
        local t = acc[a.key]
        if not t then
            t = { key = a.key, now = 0, peak = 0, over1 = 0, mem = 0, hasMem = false }
            acc[a.key] = t
        end
        t.now = t.now + (now or 0)
        t.peak = max(t.peak, peak or 0)
        t.over1 = t.over1 + (over1 or 0)
        if doMem then t.mem = t.mem + MemKB(a.name); t.hasMem = true end
    end

    -- The monitor's own work is billed to the core addon: take it out of "Core".
    local core = acc.Core
    if core and self.selfNow then core.now = max(0, core.now - self.selfNow) end

    for _, t in pairs(acc) do
        local r = Row(self, t.key)
        r.now = t.now
        r.sum = r.sum + t.now
        r.n = r.n + 1
        r.peak = max(r.peak, t.peak)
        r.over1 = t.over1
        if t.hasMem then r.mem = t.mem end
    end
end

---------------------------------------------------------------------------
-- Queries (sorted lists) for the UI and the reports
---------------------------------------------------------------------------
local function Avg(r) return r.n > 0 and r.sum / r.n or 0 end

function Perf:ModuleList()
    local list = {}
    for _, r in pairs(self.data) do list[#list + 1] = r end
    sort(list, function(a, b)
        if a.now ~= b.now then return a.now > b.now end
        return a.key < b.key
    end)
    return list
end

-- Reference snapshot: the one chosen with /kperf cmp <name>, else the newest.
function Perf:Baseline()
    local snaps = Snapshots()
    if not snaps then return nil end
    if self.baselineName and snaps[self.baselineName] then
        return snaps[self.baselineName], self.baselineName
    end
    local bestName, best
    for name, snap in pairs(snaps) do
        if not best or (snap.time or "") > (best.time or "") then bestName, best = name, snap end
    end
    return best, bestName
end

function Perf:CompareList()
    local base = self:Baseline()
    local rows = base and base.rows or {}
    local keys, seen = {}, {}
    for id, r in pairs(self.data) do
        seen[id] = true
        keys[#keys + 1] = { key = r.key, cur = r, base = rows[id] }
    end
    for id, b in pairs(rows) do
        if not seen[id] then keys[#keys + 1] = { key = id:match(":(.+)$") or id, base = b } end
    end
    local function top(p) return max(p.cur and Avg(p.cur) or 0, p.base and p.base.avg or 0) end
    sort(keys, function(a, b)
        local at, bt = top(a), top(b)
        if at ~= bt then return at > bt end
        return a.key < b.key
    end)
    return keys
end

function Perf:Totals()
    local t = { now = 0, avg = 0, mem = 0 }
    for _, r in pairs(self.data) do
        t.now = t.now + r.now
        t.avg = t.avg + Avg(r)
        t.mem = t.mem + r.mem
    end
    return t
end

local function FmtMs(v) return format(v >= 10 and "%.1f" or "%.3f", v) end
local function FmtMem(kb)
    if not kb or kb <= 0 then return "-" end
    if kb >= 1024 then return format("%.1f MB", kb / 1024) end
    return format("%.0f KB", kb)
end

---------------------------------------------------------------------------
-- Text reports (chat / CSV). Column names stay in English on purpose.
---------------------------------------------------------------------------
function Perf:Report()
    local lines = {}
    local _, baseName = self:Baseline()
    lines[#lines + 1] = format("KUI Perf | samples=%d | source=%s | FPS=%.0f | base=%s", self.samples,
        self.usingProfiler and "C_AddOnProfiler" or "legacy", _G.GetFramerate and _G.GetFramerate() or 0,
        tostring(baseName))
    lines[#lines + 1] = "module;avg_ms;peak_ms;mem_KB;base_avg_ms;diff_pct"
    for _, p in ipairs(self:CompareList()) do
        local c, b = p.cur, p.base
        local ca, ba = c and Avg(c) or 0, b and b.avg or 0
        lines[#lines + 1] = format("%s;%.4f;%.3f;%.0f;%.4f;%s", p.key, ca, c and c.peak or 0, c and c.mem or 0, ba,
            (b and ba > 0) and format("%+.1f", (ca - ba) / ba * 100) or "")
    end
    local t = self:Totals()
    lines[#lines + 1] = format("TOTAL;%.4f;;%.0f;;", t.avg, t.mem)
    return lines
end

function Perf:SnapCount()
    local n = 0
    for _ in pairs(Snapshots() or {}) do n = n + 1 end
    return n
end

function Perf:SaveSnapshot(name)
    local snaps = Snapshots(true)
    if not snaps then return nil end
    local snap = { time = _G.date and _G.date("%Y-%m-%d %H:%M:%S") or "", samples = self.samples, rows = {} }
    for id, r in pairs(self.data) do
        snap.rows[id] = { avg = Avg(r), peak = r.peak, mem = r.mem }
    end
    snaps[name] = snap
    return snap
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8x8"
local COLX = { module = 10, a = 190, b = 255, c = 320, d = 380 }

local function MakeText(parent, size, justify, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, "")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(r or 0.92, g or 0.92, b or 0.95)
    return fs
end

local function MakeButton(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 20)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(0.12, 0.12, 0.15, 1)
    b:SetBackdropBorderColor(0.3, 0.3, 0.36, 1)
    b.text = MakeText(b, 11, "CENTER")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.25, 1) end)
    b:SetScript("OnLeave", function(s) s:SetBackdropColor(0.12, 0.12, 0.15, 1) end)
    b:SetScript("OnClick", onClick)
    return b
end

function Perf:BuildUI()
    if self.frame then return end
    local f = CreateFrame("Frame", "KullThranUI_PerfFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 70 + ROWS * ROW_H + 62)
    f:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(0.04, 0.04, 0.05, 0.94)
    f:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
    f:Hide()
    table.insert(_G.UISpecialFrames, "KullThranUI_PerfFrame")
    self.frame = f

    local title = MakeText(f, 13, "LEFT", 1, 1, 1)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(L.title)
    self.sub = MakeText(f, 10, "RIGHT", 0.6, 0.6, 0.65)
    self.sub:SetPoint("TOPRIGHT", -30, -10)

    local close = MakeButton(f, "x", 20, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -6, -6)

    self.tabModules = MakeButton(f, L.modules, 80, function() Perf.tab = "modules"; Perf.scroll = 0; Perf:Refresh() end)
    self.tabModules:SetPoint("TOPLEFT", 10, -30)
    self.tabCompare = MakeButton(f, L.compare, 90, function() Perf.tab = "compare"; Perf.scroll = 0; Perf:Refresh() end)
    self.tabCompare:SetPoint("LEFT", self.tabModules, "RIGHT", 4, 0)

    self.heads = {}
    for i = 1, 5 do
        self.heads[i] = MakeText(f, 10, i == 1 and "LEFT" or "RIGHT", 0.6, 0.6, 0.66)
    end
    local hy = -56
    self.heads[1]:SetPoint("TOPLEFT", COLX.module, hy)
    self.heads[2]:SetPoint("TOPRIGHT", f, "TOPLEFT", COLX.a + 55, hy)
    self.heads[3]:SetPoint("TOPRIGHT", f, "TOPLEFT", COLX.b + 55, hy)
    self.heads[4]:SetPoint("TOPRIGHT", f, "TOPLEFT", COLX.c + 55, hy)
    self.heads[5]:SetPoint("TOPRIGHT", f, "TOPLEFT", COLX.d + 75, hy)

    -- Fixed row pool: no frames are created on refresh.
    self.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(480, ROW_H)
        r:SetPoint("TOPLEFT", 10, -70 - (i - 1) * ROW_H)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
        r.name = MakeText(r, 11, "LEFT"); r.name:SetPoint("LEFT", 0, 0)
        r.c1 = MakeText(r, 11, "RIGHT"); r.c1:SetPoint("RIGHT", r, "LEFT", COLX.a + 45, 0)
        r.c2 = MakeText(r, 11, "RIGHT"); r.c2:SetPoint("RIGHT", r, "LEFT", COLX.b + 45, 0)
        r.c3 = MakeText(r, 11, "RIGHT"); r.c3:SetPoint("RIGHT", r, "LEFT", COLX.c + 45, 0)
        r.c4 = MakeText(r, 11, "RIGHT"); r.c4:SetPoint("RIGHT", r, "LEFT", COLX.d + 65, 0)
        r.bar = r:CreateTexture(nil, "ARTWORK")
        r.bar:SetHeight(2)
        r.bar:SetPoint("BOTTOMLEFT", 0, 1)
        self.rows[i] = r
    end

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        Perf.scroll = max(0, Perf.scroll - delta * 3)
        Perf:Refresh()
    end)

    self.foot = MakeText(f, 11, "LEFT", 0.85, 0.85, 0.9)
    self.foot:SetPoint("BOTTOMLEFT", 10, 34)
    self.foot:SetWidth(480)
    self.foot:SetJustifyV("TOP")
    self.foot:SetHeight(26)

    local b1 = MakeButton(f, L.reset, 80, function() Perf:Reset(); Perf:Refresh() end)
    b1:SetPoint("BOTTOMLEFT", 10, 8)
    self.freezeBtn = MakeButton(f, L.freeze, 80, function()
        Perf.frozen = not Perf.frozen
        Perf.freezeBtn.text:SetText(Perf.frozen and L.unfreeze or L.freeze)
        Perf:Refresh()
    end)
    self.freezeBtn:SetPoint("LEFT", b1, "RIGHT", 4, 0)
    local b3 = MakeButton(f, L.snap, 80, function()
        local n = "snap" .. (Perf:SnapCount() + 1)
        Perf:SaveSnapshot(n)
        Say(format(LText("Snapshot saved: %s"), n))
    end)
    b3:SetPoint("LEFT", self.freezeBtn, "RIGHT", 4, 0)
    local b4 = MakeButton(f, "CSV", 50, function() Perf:ShowCSV() end)
    b4:SetPoint("LEFT", b3, "RIGHT", 4, 0)

    f:SetScript("OnShow", function() Perf:Start() end)
    f:SetScript("OnHide", function() Perf:Stop() end)
end

function Perf:ShowCSV()
    if not self.csv then
        local c = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        c:SetSize(480, 200)
        c:SetPoint("TOP", self.frame, "BOTTOM", 0, -4)
        c:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        c:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
        c:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
        local sf = CreateFrame("ScrollFrame", nil, c, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 6, -6)
        sf:SetPoint("BOTTOMRIGHT", -26, 6)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject(_G.ChatFontNormal)
        eb:SetWidth(440)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() c:Hide() end)
        sf:SetScrollChild(eb)
        c.edit = eb
        self.csv = c
    end
    self.csv.edit:SetText(table.concat(self:Report(), "\n"))
    self.csv:Show()
    self.csv.edit:HighlightText()
    self.csv.edit:SetFocus()
end

function Perf:Refresh()
    local f = self.frame
    if not (f and f:IsShown()) then return end

    local cmp = (self.tab == "compare")
    self.tabModules:SetBackdropBorderColor(cmp and 0.3 or 0.96, cmp and 0.3 or 0.26, cmp and 0.36 or 0.36, 1)
    self.tabCompare:SetBackdropBorderColor(cmp and 0.96 or 0.3, cmp and 0.26 or 0.3, cmp and 0.36 or 0.36, 1)

    if cmp then
        local _, baseName = self:Baseline()
        self.heads[1]:SetText(L.module)
        self.heads[2]:SetText(L.avg .. " ms")
        self.heads[3]:SetText(L.base .. (baseName and (" (" .. baseName .. ")") or ""))
        self.heads[4]:SetText(L.delta)
        self.heads[5]:SetText(L.memCmp)
    else
        self.heads[1]:SetText(L.module)
        self.heads[2]:SetText(L.now .. " ms")
        self.heads[3]:SetText(L.avg .. " ms")
        self.heads[4]:SetText(L.peak)
        self.heads[5]:SetText(L.mem .. "  >1ms")
    end

    local list = cmp and self:CompareList() or self:ModuleList()
    self.scroll = min(self.scroll, max(0, #list - ROWS))
    local top = 0
    for _, item in ipairs(list) do
        local v = cmp and max(item.cur and Avg(item.cur) or 0, item.base and item.base.avg or 0) or item.now
        top = max(top, v)
    end

    for i = 1, ROWS do
        local row, item = self.rows[i], list[self.scroll + i]
        if not item then
            row:Hide()
        else
            row:Show()
            if cmp then
                local c, bs = item.cur, item.base
                local ca, ba = c and Avg(c) or 0, bs and bs.avg or 0
                row.name:SetText(item.key)
                row.name:SetTextColor(0.92, 0.92, 0.95)
                row.c1:SetText(c and FmtMs(ca) or "-")
                row.c1:SetTextColor(unpack(COLOR))
                row.c2:SetText(bs and FmtMs(ba) or "-")
                row.c2:SetTextColor(0.7, 0.7, 0.75)
                if c and bs and ba > 0 then
                    local d = (ca - ba) / ba * 100
                    row.c3:SetText(format("%+.0f%%", d))
                    if d > 10 then row.c3:SetTextColor(1, 0.4, 0.4)
                    elseif d < -10 then row.c3:SetTextColor(0.4, 1, 0.5)
                    else row.c3:SetTextColor(0.8, 0.8, 0.8) end
                else
                    row.c3:SetText("-"); row.c3:SetTextColor(0.6, 0.6, 0.6)
                end
                row.c4:SetText((c and FmtMem(c.mem) or "-") .. " / " .. (bs and FmtMem(bs.mem) or "-"))
                row.c4:SetTextColor(0.8, 0.8, 0.85)
                row.bar:SetWidth(max(1, 470 * (top > 0 and max(ca, ba) / top or 0)))
            else
                row.name:SetText(item.key)
                row.name:SetTextColor(unpack(COLOR))
                row.c1:SetText(FmtMs(item.now))
                row.c2:SetText(FmtMs(Avg(item)))
                row.c3:SetText(FmtMs(item.peak))
                row.c4:SetText(FmtMem(item.mem) .. "  " .. format("%d", item.over1))
                for _, c in ipairs({ row.c1, row.c2, row.c3, row.c4 }) do c:SetTextColor(0.9, 0.9, 0.93) end
                row.bar:SetWidth(max(1, 470 * (top > 0 and item.now / top or 0)))
            end
            row.bar:SetColorTexture(unpack(COLOR))
            row.bar:SetAlpha(0.6)
        end
    end

    local t = self:Totals()
    local _, _, home, world = _G.GetNetStats()
    self.foot:SetText(format(
        "|cfff54259KUI|r %s ms (%s %s)  %s\nFPS %.0f  |  %d/%d ms  |  %s %s ms",
        FmtMs(t.now), L.avg, FmtMs(t.avg), FmtMem(t.mem),
        _G.GetFramerate(), home or 0, world or 0, L.own, FmtMs(self.selfNow or 0)))
    self.sub:SetText(format("%d %s%s%s", self.samples, L.samples,
        self.frozen and (" | " .. L.frozen) or "", self.usingProfiler == false and (" | " .. L.legacy) or ""))
end

-- One tick: sample + paint, timing itself so the monitor's cost is known.
function Perf:Tick()
    local t0 = GetTimePreciseSec and GetTimePreciseSec()
    self:Sample()
    self:Refresh()
    if t0 then
        local ms = (GetTimePreciseSec() - t0) * 1000
        -- ms of work per second of wall time, expressed per rendered frame.
        local perFrame = ms / max(1, (_G.GetFramerate and _G.GetFramerate() or 60) * SAMPLE_INTERVAL)
        self.selfNow = self.selfNow and (self.selfNow * 0.7 + perFrame * 0.3) or perFrame
    end
end

function Perf:Start()
    self:Scan()
    if self.ticker then self.ticker:Cancel() end
    self:Tick()
    self.ticker = C_Timer.NewTicker(SAMPLE_INTERVAL, function() Perf:Tick() end)
end

function Perf:Stop()
    if self.ticker then self.ticker:Cancel(); self.ticker = nil end
end

function Perf:Toggle()
    self:BuildUI()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

---------------------------------------------------------------------------
-- Commands: /kperf  /kuiperf
---------------------------------------------------------------------------
function Perf:HandleCommand(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "toggle" then
        self:Toggle()
    elseif cmd == "reset" then
        self:Reset(); Say(LText("Counters reset")); self:Refresh()
    elseif cmd == "report" then
        if self.samples == 0 then self:Scan(); self:Sample() end
        for _, line in ipairs(self:Report()) do print(line) end
    elseif cmd == "csv" then
        self:BuildUI(); self.frame:Show(); self:ShowCSV()
    elseif cmd == "snap" then
        local name = rest ~= "" and rest or ("snap" .. (self:SnapCount() + 1))
        if self.samples == 0 then self:Scan(); self:Sample() end
        self:SaveSnapshot(name); Say(format(LText("Snapshot saved: %s"), name))
    elseif cmd == "cmp" then
        local snaps = Snapshots()
        if rest ~= "" and snaps and snaps[rest] then
            self.baselineName = rest
            Say(format(LText("Comparison base: %s"), rest)); self:Refresh()
        else
            local names = {}
            for k in pairs(snaps or {}) do names[#names + 1] = k end
            sort(names)
            Say(format(LText("Snapshots: %s"), #names > 0 and table.concat(names, ", ") or LText("none")))
        end
    elseif cmd == "on" or cmd == "off" then
        if _G.SetCVar then
            _G.SetCVar("addonProfilerEnabled", cmd == "on" and "1" or "0")
            Say(format(LText("Addon profiler: %s"), cmd))
        end
    else
        Say(LText("Usage: /kperf [toggle|reset|report|csv|snap <name>|cmp <name>|on|off]"))
    end
end

function Perf:OnEnable()
    local handler = function(input) Perf:HandleCommand(input) end
    KT:RegisterChatCommand("kperf", handler)
    KT:RegisterChatCommand("kuiperf", handler)
end
