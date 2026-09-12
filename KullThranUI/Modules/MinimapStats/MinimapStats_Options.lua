-- Modules/MinimapStats/MinimapStats_Options.lua
-- Adds the "Minimap Stats" block to the Minimap options page.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Opt = KT.Options or {}
local GetFontValues = Opt.GetFontValues

function KT:BuildMinimapStatsOptionsBlock(container, W, minimapDB, refreshFn)
    local y, h = 0, 0
    local db = minimapDB or (KT.db and KT.db.profile and KT.db.profile.minimap) or {}

    local function Refresh()
        if type(refreshFn) == "function" then
            refreshFn()
        end
    end

    _, h = W:Toggle(container, "Show FPS", -y,
        function() return db.showFPS ~= false end,
        function(v) db.showFPS = v; Refresh() end); y = y + h
    _, h = W:Toggle(container, "Show MS", -y,
        function() return db.showMS ~= false end,
        function(v) db.showMS = v; Refresh() end); y = y + h
    _, h = W:Toggle(container, "Show Clock", -y,
        function() return db.showClock ~= false end,
        function(v) db.showClock = v; Refresh() end); y = y + h

    _, h = W:SectionHeader(container, "Stats Font", -y); y = y + h
    _, h = W:Dropdown(container, "Font", -y, GetFontValues,
        function() return db.statsFont or "AAA_ITC_Avant_Garde" end,
        function(v) db.statsFont = v; Refresh() end, nil, "font"); y = y + h
    _, h = W:Slider(container, "Size", -y,
        function() return db.statsFontSize or 11 end,
        function(v) db.statsFontSize = v; Refresh() end, 8, 24, 1); y = y + h
    _, h = W:Dropdown(container, "Outline", -y,
        { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
        function() return db.statsFontOutline or "OUTLINE" end,
        function(v) db.statsFontOutline = v; Refresh() end); y = y + h

    return y
end

