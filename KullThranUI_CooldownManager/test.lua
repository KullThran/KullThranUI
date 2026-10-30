local tbbData = {
    groupGrowDirection = "RIGHT",
    groupSpacing = 2,
    bars = {
        { enabled = true, grouped = true, width = 24, height = 24, iconDisplay = "only" },
        { enabled = true, grouped = true, width = 24, height = 24, iconDisplay = "only" }
    }
}
local isGrouped = true
local ns = {
    GetTrackedBuffBars = function() return tbbData end,
    TBBBarGrouped = function(c) return c.grouped ~= false end
}
local cBars = tbbData.bars
local growDir = (tbbData.groupGrowDirection or "DOWN"):upper()
local spacing = tbbData.groupSpacing or 2
local gW, gH = 0, 0
local count = 0
for j, c in ipairs(cBars) do
    if c.enabled ~= false and ns.TBBBarGrouped(c) then
        count = count + 1
        local w = c.width or 200
        local h = c.height or 24
        local isVert = c.verticalOrientation
        local hasIcon = (c.iconDisplay or "none") ~= "none"
        local bw = isVert and h or (hasIcon and (w + h) or w)
        local bh = isVert and (hasIcon and (w + h) or w) or h
        if growDir == "DOWN" or growDir == "UP" then
            gW = math.max(gW, bw)
            gH = gH + bh
        else
            gW = gW + bw
            gH = math.max(gH, bh)
        end
    end
end
if count > 1 then
    if growDir == "DOWN" or growDir == "UP" then
        gH = gH + spacing * (count - 1)
    else
        gW = gW + spacing * (count - 1)
    end
end
print(gW, gH)
