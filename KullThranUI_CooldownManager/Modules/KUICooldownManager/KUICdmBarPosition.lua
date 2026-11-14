-- Restores, converts, defaults and saves the position of a Cooldown Manager bar, relative to UIParent.
-- Every number here is raw: nothing is rounded or snapped, because the results are users' saved data.

local _, ns = ...

local Position = {}
ns.CdmBarPosition = Position

-- Where a bar with no anchor and no saved position rests.
local REST_SPOTS = {
    cooldowns = { point = "CENTER", y = -250 },
    utility = { point = "BOTTOM", y = 66 },
    buffs = { point = "BOTTOM", y = 15 },
}
local REST_OTHER = { point = "BOTTOM", y = 90 }

-- Anchors the bar from a saved position. A corner-to-corner TOPLEFT entry is rewritten in place as CENTER, once.
local function ApplyCentered(frame, pos)
    if not pos or not pos.point then return end

    frame:ClearAllPoints()
    local parent = UIParent
    local x, y = pos.x or 0, pos.y or 0

    if pos.point == "TOPLEFT" and pos.relPoint == "TOPLEFT" then
        local width, height = frame:GetWidth() or 0, frame:GetHeight() or 0
        local parentWidth, parentHeight = parent:GetSize()
        local ratio = parent:GetEffectiveScale() / frame:GetEffectiveScale()
        local newX = x + width / 2 - parentWidth * ratio / 2
        local newY = y - height / 2 + parentHeight * ratio / 2
        frame:SetPoint("CENTER", parent, "CENTER", newX, newY)
        pos.point, pos.relPoint, pos.x, pos.y = "CENTER", "CENTER", newX, newY
        return
    end

    frame:SetPoint(pos.point, parent, pos.relPoint or pos.point, x, y)
end
Position.ApplyCentered = ApplyCentered

-- Publishes the save function, which reads the profile only when it runs.
function Position.Install(ctx)
    ns.SaveCDMBarPosition = function(barKey, frame)
        if frame == nil then return end
        local centerX, centerY = frame:GetCenter()
        if centerX == nil then return end

        local parent = UIParent
        local barScale = frame:GetScale() or 1
        local parentWidth, parentHeight = parent:GetSize()
        local barEffective, parentEffective = frame:GetEffectiveScale(), parent:GetEffectiveScale()
        ctx.GetProfile().cdmBarPositions[barKey] = {
            point = "CENTER",
            relPoint = "CENTER",
            x = (centerX * barEffective / parentEffective - parentWidth / 2) / barScale,
            y = (centerY * barEffective / parentEffective - parentHeight / 2) / barScale,
        }
    end
end

-- The saved entry of a bar, when it counts as saved.
local function SavedEntry(profile, key)
    local entry = profile.cdmBarPositions[key]
    if entry and entry.point then return entry end
    return nil
end

-- Saved position, or the screen centre shifted by offsetY. The scale argument is unused.
function Position.PlaceSavedOrCentre(frame, p, key, scale, offsetY)
    local entry = SavedEntry(p, key)
    if entry then
        ApplyCentered(frame, entry)
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, offsetY)
end

-- Saved position, or the bar's rest spot. The scale argument is unused.
function Position.PlaceSavedOrRest(frame, p, key, scale)
    local entry = SavedEntry(p, key)
    if entry then
        ApplyCentered(frame, entry)
        return
    end
    local spot = REST_SPOTS[key] or REST_OTHER
    frame:ClearAllPoints()
    frame:SetPoint(spot.point, UIParent, spot.point, 0, spot.y)
end
