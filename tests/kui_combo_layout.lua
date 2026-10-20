local root = arg[1] or "."
local theme = "kui"
local KT = { VisualThemes = { GetRenderedTheme = function() return theme end } }
LibStub = function() return { GetAddon = function() return KT end } end
local ns = {}
assert(loadfile(root .. "/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_ThemeOrnaments.lua"))("test", ns)
local function region(x, y, w, h, scale)
    return {
        IsShown = function() return true end,
        GetCenter = function() return x, y end,
        GetWidth = function() return w end,
        GetHeight = function() return h end,
        GetEffectiveScale = function() return scale end,
        GetLeft = function() return x - w / 2 end, GetRight = function() return x + w / 2 end,
        GetTop = function() return y + h / 2 end, GetBottom = function() return y - h / 2 end,
    }
end
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    for _, side in ipairs({ -1, 1 }) do
        local portrait = region(200, 100, 46, 46, scale)
        local frame = region(200 + side * 110, 100, 260, 46, scale)
        frame.Health = region(200 + side * 110, 100, 220, 46, scale)
        frame._kuiLevelText = region(200, 140, 20, 12, scale)
        for count = 1, 10 do
            local row = ns.KUIOrnaments.LayoutRing(frame, portrait, count, 10, true)
            assert(#row == count, "all resource points remain available")
            -- KUI Style: points follow an arc around the portrait; they may not cross the
            -- health bar or the level number (a straight row is only the last resort).
            local barLeft, barRight = 200 + side * 110 - 110, 200 + side * 110 + 110
            local barBottom, barTop = 100 - 23, 100 + 23
            for i, point in ipairs(row) do
                local x, y = 200 + point[1], 100 + point[2]
                local dx = math.max(barLeft - x, 0, x - barRight)
                local dy = math.max(barBottom - y, 0, y - barTop)
                assert(math.sqrt(dx * dx + dy * dy) >= 5 - 0.001, "point clears the health bar")
                assert(math.sqrt((x - 200) ^ 2 + (y - 140) ^ 2) >= 8, "point clears level number")
                assert(not point.onlyFilled, "extra resource sockets stay visible")
                if i > 1 then
                    local px, py = row[i-1][1], row[i-1][2]
                    assert(math.sqrt((point[1] - px) ^ 2 + (point[2] - py) ^ 2) >= 7, "points cannot overlap")
                end
            end
            if count == 5 then
                local flat = true
                for i = 2, count do if row[i][2] ~= row[1][2] then flat = false end end
                assert(not flat, "KUI Style combo points surround the portrait in an arc, not a straight line")
            end
        end
        for _, stock in ipairs({ "classic", "forever", "retail" }) do
            theme = stock
            local row = ns.KUIOrnaments.LayoutRing(frame, portrait, 5, 10, true)
            assert(row[1][2] ~= row[5][2], "stock style keeps its portrait arc")
        end
        theme = "kui"
    end
end
print("kui_combo_layout: ok")
