-- Modules/MinimapButton/MinimapButton_Options.lua
-- Adds the "Minimap Buttons" block to the Minimap options page.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

function KT:BuildMinimapButtonOptionsBlock(container, W)
    local y, h = 0, 0

    local bdb = (KT.db and KT.db.profile and KT.db.profile.minimapButton) or {}
    if KT.db and KT.db.profile then
        KT.db.profile.minimapButton = bdb
    end

    bdb.enable = bdb.enable ~= false

    local function RefreshMB()
        local M = KT:GetModule("MinimapButton", true)
        if M and M.Refresh then
            M:Refresh()
        end
    end

    _, h = W:Toggle(container, "Enable Button Bag", -y,
        function() return bdb.enable ~= false end,
        function(v) bdb.enable = v; RefreshMB() end); y = y + h
    _, h = W:Slider(container, "Button Size", -y,
        function() return bdb.size or 28 end,
        function(v) bdb.size = v; RefreshMB() end, 16, 64, 1); y = y + h
    _, h = W:Slider(container, "Spacing", -y,
        function() return bdb.spacing or 4 end,
        function(v) bdb.spacing = v; RefreshMB() end, 0, 20, 1); y = y + h
    _, h = W:Slider(container, "Rows", -y,
        function() return bdb.rows or 3 end,
        function(v) bdb.rows = v; RefreshMB() end, 1, 10, 1); y = y + h
    _, h = W:Dropdown(container, "Position", -y,
        { ["LEFT"] = "Left", ["RIGHT"] = "Right", ["TOP"] = "Top", ["BOTTOM"] = "Bottom" },
        function() return bdb.position or "LEFT" end,
        function(v) bdb.position = v; RefreshMB() end); y = y + h

    return y
end
