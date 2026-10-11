local _, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end
-- Observe native loot without replacing handlers, anchors or visibility.
local Debug = { enabled = true, hooked = setmetatable({}, { __mode = "k" }), rolls = {}, limit = 160 }
KT.LootDebug = Debug
local function Loc(text)
    local L = KT.GetLocale and KT:GetLocale()
    return (L and L[text]) or text
end
local function Safe(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return "<secret>" end
    return tostring(value)
end
function Debug:Store()
    if KT.db and KT.db.global then
        KT.db.global.lootVisibilityDebug = KT.db.global.lootVisibilityDebug or {}
        return KT.db.global.lootVisibilityDebug
    end
    self.session = self.session or {}
    return self.session
end
function Debug:Record(action, detail, stack)
    if not self.enabled then return end
    local entries = self:Store()
    entries[#entries + 1] = { time = _G.GetTime and _G.GetTime() or 0, action = action,
        detail = detail or "", stack = stack or "" }
    while #entries > self.limit do table.remove(entries, 1) end
    if action:match("^Hide ") or action == "OnHide"
        or (action:match("^SetShown ") and detail:match("^arg=false"))
        or (action:match("^SetAlpha ") and detail:match("^arg=0 |")) then
        entries.lastHides = entries.lastHides or {}
        entries.lastHides[#entries.lastHides + 1] = entries[#entries]
        while #entries.lastHides > 12 do table.remove(entries.lastHides, 1) end
    end
end
function Debug:Read(frame, method)
    if not frame or type(frame[method]) ~= "function" then return "-" end
    local ok, value = pcall(frame[method], frame)
    return ok and Safe(value) or "<error>"
end
function Debug:Describe(frame)
    local parts, seen = {}, {}
    for depth = 1, 6 do
        if not frame or seen[frame] then break end
        seen[frame] = true
        if frame.IsForbidden and frame:IsForbidden() then parts[#parts + 1] = "<forbidden>"; break end
        local name = self:Read(frame, "GetName")
        if name == "nil" then name = "<unnamed>" end
        local position = ""
        if frame.GetPoint then
            local ok, point, relative, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
            if ok then position = " pos=" .. Safe(point) .. "/" .. Safe(relativePoint) .. ":" .. Safe(x) .. "," .. Safe(y) end
        end
        parts[#parts + 1] = name .. " shown=" .. self:Read(frame, "IsShown")
            .. " visible=" .. self:Read(frame, "IsVisible") .. " alpha=" .. self:Read(frame, "GetAlpha")
            .. " scale=" .. self:Read(frame, "GetEffectiveScale") .. position
        local ok, parent = pcall(function() return frame.GetParent and frame:GetParent() end)
        frame = ok and parent or nil
    end
    return table.concat(parts, " <- ")
end
function Debug:Snapshot(reason, force)
    if not self.enabled then return end
    local parts = { "combat=" .. Safe(_G.InCombatLockdown and _G.InCombatLockdown()) }
    for _, name in ipairs({ "AlertFrame", "GroupLootContainer", "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4" }) do
        local frame = _G[name]
        if frame then parts[#parts + 1] = self:Describe(frame) else parts[#parts + 1] = name .. "=<missing>" end
    end
    local timing = {}
    for id in pairs(self.rolls) do
        local left = "-"
        if _G.GetLootRollTimeLeft then
            local ok, value = pcall(_G.GetLootRollTimeLeft, id)
            if ok then left = Safe(value) end
        end
        parts[#parts + 1] = "roll=" .. Safe(id)
        timing[#timing + 1] = "roll=" .. Safe(id) .. " remaining=" .. left
    end
    local signature = table.concat(parts, " | ")
    if force or self.lastSnapshot ~= signature then
        self.lastSnapshot = signature
        self:Record(reason, signature .. " | " .. table.concat(timing, "; "))
    end
end
function Debug:HookFrame(frame)
    if not frame or self.hooked[frame] then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    self.hooked[frame] = true
    if _G.hooksecurefunc then
        for _, method in ipairs({ "Hide", "SetShown", "SetAlpha", "SetParent" }) do
            if type(frame[method]) == "function" then
                _G.hooksecurefunc(frame, method, function(_, value)
                    if not self.enabled then return end
                    local stack = _G.debugstack and _G.debugstack(3, 14, 0) or ""
                    self:Record(method .. " " .. self:Read(frame, "GetName"), "arg=" .. Safe(value) .. " | " .. self:Describe(frame), stack)
                end)
            end
        end
    end
    if frame.HookScript then
        frame:HookScript("OnHide", function()
            if not self.enabled then return end
            self:Record("OnHide", self:Describe(frame), _G.debugstack and _G.debugstack(3, 14, 0) or "")
        end)
        frame:HookScript("OnShow", function() self:Record("OnShow", self:Describe(frame)) end)
    end
end
function Debug:Install()
    for _, name in ipairs({ "AlertFrame", "GroupLootContainer", "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4" }) do self:HookFrame(_G[name]) end
    local alert = _G.AlertFrame
    if alert then self:HookFrame(alert.fullscreenFrame) end
    local container = _G.GroupLootContainer
    if container and type(container.rollFrames) == "table" then
        for _, frame in pairs(container.rollFrames) do self:HookFrame(frame) end
    end
    self.functions = self.functions or {}
    if not _G.hooksecurefunc then return end
    for _, name in ipairs({ "GroupLootContainer_AddRoll", "GroupLootContainer_AddFrame", "GroupLootContainer_RemoveFrame", "GroupLootContainer_Update", "RollOnLoot" }) do
        if not self.functions[name] and type(_G[name]) == "function" then
            self.functions[name] = true
            _G.hooksecurefunc(name, function(a, b, c)
                if not self.enabled then return end
                if name ~= "GroupLootContainer_Update" then
                    self:Record(name, "a=" .. Safe(a) .. " b=" .. Safe(b) .. " c=" .. Safe(c), _G.debugstack and _G.debugstack(3, 14, 0) or "")
                end
                self:Install()
                self:Snapshot(name, false)
            end)
        end
    end
end
function Debug:Watch()
    if self.ticker or not (_G.C_Timer and _G.C_Timer.NewTicker) then return end
    self.watchUntil = (_G.GetTime and _G.GetTime() or 0) + 180
    self.ticker = _G.C_Timer.NewTicker(0.25, function()
        self:Install()
        self:Snapshot("visibility change", false)
        if not self.enabled or not next(self.rolls) or _G.GetTime() >= self.watchUntil then
            self.ticker:Cancel(); self.ticker = nil
        end
    end)
end
function Debug:Command(message)
    local command = (message or ""):lower():match("^%s*(%S+)") or "status"
    if command == "on" then self.enabled = true; self:Install()
    elseif command == "off" then self.enabled = false
    elseif command == "clear" then local entries = self:Store(); for i = #entries, 1, -1 do entries[i] = nil end; entries.lastHides = nil
    elseif command == "dump" then
        local entries = self:Store()
        KT:Print(Loc("Last hide calls (retained independently of timer updates):"))
        for _, entry in ipairs(entries.lastHides or {}) do
            KT:Print(string.format("Loot %.2f %s: %s", entry.time, entry.action, entry.detail))
            if entry.stack ~= "" then KT:Print(entry.stack:gsub("\n", " | ")) end
        end
        KT:Print(Loc("Latest loot events:"))
        for i = math.max(1, #entries - 19), #entries do
            local entry = entries[i]
            KT:Print(string.format("Loot %.2f %s: %s", entry.time, entry.action, entry.detail))
            if entry.stack ~= "" then KT:Print(entry.stack:gsub("\n", " | ")) end
        end
        return
    end
    self:Install(); self:Snapshot("manual snapshot", true)
    KT:Print(string.format(Loc("Loot debug %s; %d records. /ktlootdebug dump | on | off | clear"), self.enabled and Loc("ON") or Loc("OFF"), #self:Store()))
    KT:Print(self.lastSnapshot or Loc("No snapshot"))
end
Debug.events = CreateFrame("Frame")
for _, event in ipairs({ "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do Debug.events:RegisterEvent(event) end
Debug.events:SetScript("OnEvent", function(_, event, rollID, duration)
    Debug:Install()
    if not Debug.enabled then return end
    if event == "START_LOOT_ROLL" then
        Debug.rolls[rollID] = true; Debug:Watch()
    elseif event == "CANCEL_LOOT_ROLL" then Debug.rolls[rollID] = nil
    elseif event == "CANCEL_ALL_LOOT_ROLLS" then for id in pairs(Debug.rolls) do Debug.rolls[id] = nil end end
    if event ~= "ADDON_LOADED" then
        Debug:Record(event, "id=" .. Safe(rollID) .. " duration=" .. Safe(duration))
        Debug:Snapshot(event, true)
        _G.C_Timer.After(0, function() Debug:Install(); Debug:Snapshot(event .. " deferred", true) end)
    end
end)
if KT.RegisterChatCommand then KT:RegisterChatCommand("ktlootdebug", function(message) Debug:Command(message) end) end
Debug:Install()
