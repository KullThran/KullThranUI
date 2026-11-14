-- Modules/Skins/Skins_Options.lua
-- Registers the "Skins" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local S = KT:GetModule("Skins", true)

KT:RegisterPage("skins", "Skins", 20, function(sc, W)
    local _, y, h = nil, 0, 0
    local db = KT.db.profile.skin
    local Opt = KT.Options or Opt

    -- Two cards side by side, like the other pages: the skin itself and the
    -- Blizzard-wide options; the per-window toggles follow in one card.
    local cols = Opt.BeginOptionBlocks(sc, y)
    Opt.AddOptionBlock(cols, "left", "Window Style", function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Skins", -by, function() return db.enable end, function(v) db.enable = v; Reload() end); by = by + h
        _, h = W:ColorSwatch(container, "Window Background", -by,
            function()
                local c = db.blizzard.windowBackgroundColor or { r=0.05, g=0.05, b=0.05, a=0.98 }
                return c.r,c.g,c.b,c.a
            end,
            function(r,g,b,a)
                db.blizzard.windowBackgroundColor = { r=r, g=g, b=b, a=a or 0.98 }
                if S and S.RefreshBlizzardWindowBackgrounds then
                    S:RefreshBlizzardWindowBackgrounds()
                end
            end, true); by = by + h
        return by
    end)
    Opt.AddOptionBlock(cols, "right", "Blizzard Modules", function(container)
        local by = 0
        _, h = W:Toggle(container, "Style Blizzard Frames", -by, function() return db.blizzard.enable end, function(v) db.blizzard.enable = v; Reload() end); by = by + h
        _, h = W:Toggle(container, "Show Blizzard window borders", -by,
            function() return db.blizzard.showWindowBorders ~= false end,
            function(v)
                db.blizzard.showWindowBorders = v and true or false
                if S and S.RefreshBlizzardWindowBorders then S:RefreshBlizzardWindowBorders() end
            end); by = by + h
        -- Each side melts from the accent at the corners to black in its middle.
        _, h = W:Toggle(container, "Gradient window borders", -by,
            function() return db.blizzard.gradientWindowBorders ~= false end,
            function(v)
                db.blizzard.gradientWindowBorders = v and true or false
                if S and S.RefreshBlizzardWindowBorders then S:RefreshBlizzardWindowBorders() end
            end); by = by + h
        _, h = W:Toggle(container, "Classic yellow for Blizzard frames", -by,
            function() return db.blizzard.classicYellowAccent == true end,
            function(v)
                db.blizzard.classicYellowAccent = v and true or false
                if S and S.RefreshBlizzardTheme then S:RefreshBlizzardTheme() end
            end); by = by + h
        return by
    end)
    y = Opt.EndOptionBlocks(cols)

    -- One toggle per registered window (S:RegisterWindow), sorted by name.
    local blizzToggles = {}
    for _, entry in ipairs(S and S.windowRegistry or {}) do
        blizzToggles[#blizzToggles + 1] = { key = entry.key, label = LText(entry.label) }
    end
    table.sort(blizzToggles, function(a, b) return a.label < b.label end)

    -- Every skinned window in one full-width card, two per row; the page
    -- itself scrolls, so the list needs no scroll frame of its own.
    local listFrame, list = Opt.CreateOptionBlock(sc, "Skinned Windows", 10, -y, sc:GetWidth() - 22)
    local function ToggleData(t)
        if not t then return nil end
        local k = t.key
        return {
            type = "toggle",
            text = t.label,
            getValue = function() return db.blizzard[k] end,
            setValue = function(v) db.blizzard[k] = v; Reload() end,
        }
    end
    local iy = 0
    for i = 1, #blizzToggles, 2 do
        _, h = W:DualRow(list, -iy, ToggleData(blizzToggles[i]), ToggleData(blizzToggles[i + 1]))
        iy = iy + h
    end
    y = y + Opt.FinalizeOptionBlock(listFrame, list, iy) + 10

    return y
end)
