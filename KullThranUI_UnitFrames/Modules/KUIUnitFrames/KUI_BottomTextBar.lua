-- What a unit frame's text bar holds once its shell exists: three tagged text slots and an optional class icon.
-- Everything runs from the style functions and layout refreshes; nothing here watches anything.

local _, ns = ...

local NONE = "none"
local FALLBACK_SIZE = 11
local SLOT_COUNT = 3

-- Saved keys and placement of each slot, built once so the apply functions build no strings or tables.
local SLOTS = {
    {
        field = "LeftText", point = "LEFT", pad = 5,
        content = "btbLeftContent", size = "btbLeftSize", x = "btbLeftX", y = "btbLeftY",
        classColor = "btbLeftClassColor", powerColor = "btbLeftPowerColor",
    },
    {
        field = "RightText", point = "RIGHT", pad = -5,
        content = "btbRightContent", size = "btbRightSize", x = "btbRightX", y = "btbRightY",
        classColor = "btbRightClassColor", powerColor = "btbRightPowerColor",
    },
    {
        field = "CenterText", point = "CENTER", pad = 0,
        content = "btbCenterContent", size = "btbCenterSize", x = "btbCenterX", y = "btbCenterY",
        classColor = "btbCenterClassColor", powerColor = "btbCenterPowerColor",
    },
}

-- Contents that show a power value, and so can take the power tint.
local POWER_CONTENT = { perpp = true, curpp = true, curhp_curpp = true, perhp_perpp = true }

local ICON_PLACES = {
    left = { point = "LEFT", pad = 3 },
    right = { point = "RIGHT", pad = -3 },
    center = { point = "CENTER", pad = 0 },
}

local function Create(ctx, frame, unit, settings, anchorFrame, xOffset, overrideWidth)
    local bar, overlay = ctx.Shell(frame, settings, anchorFrame, xOffset, overrideWidth)

    -- The font goes on first: the client refuses text on a font string that has none.
    local strings = {}
    for i = 1, SLOT_COUNT do
        local slot = SLOTS[i]
        local fs = overlay:CreateFontString(nil, "OVERLAY")
        ctx.SetFont(fs, settings[slot.size] or FALLBACK_SIZE)
        fs:SetTextColor(1, 1, 1)
        fs:SetWordWrap(false)
        bar[slot.field] = fs
        strings[i] = fs
    end

    -- Retags every slot, changed or not. The arguments shift down one place per slot.
    local function applyTags(left, right, center)
        for i = 1, SLOT_COUNT do
            local fs = strings[i]
            local tag = ctx.ContentToTag(left)
            if fs._curTag then
                frame:Untag(fs)
                fs._curTag = nil
            end
            if tag then
                frame:Tag(fs, tag)
                fs._curTag = tag
            end
            left, right, center = right, center, nil
        end
        if frame.UpdateTags then
            frame:UpdateTags()
        end
    end

    -- Font, anchor, visibility and colour of each slot, from the settings passed in.
    local function applyPositions(s)
        for i = 1, SLOT_COUNT do
            local slot = SLOTS[i]
            local fs = strings[i]
            local content = s[slot.content] or NONE
            ctx.SetFont(fs, s[slot.size] or FALLBACK_SIZE)
            fs:ClearAllPoints()
            if content == NONE then
                fs:Hide()
            else
                fs:SetJustifyH(slot.point)
                ctx.PP.Point(fs, slot.point, overlay, slot.point, slot.pad + (s[slot.x] or 0), s[slot.y] or 0)
                fs:Show()
            end
            ctx.ApplyClassColor(fs, unit, s[slot.classColor])
            if s[slot.powerColor] and POWER_CONTENT[content] then
                local powerType = UnitPowerType(unit)
                local color = PowerBarColor[powerType]
                if color then
                    fs:SetTextColor(color.r, color.g, color.b)
                end
            end
        end
    end

    applyTags(settings.btbLeftContent or NONE, settings.btbRightContent or NONE, settings.btbCenterContent or NONE)
    applyPositions(settings)

    -- The host hangs from the unit frame, not from the bar, and is reached only as the icon's parent.
    local host = CreateFrame("Frame", nil, frame)
    host:SetAllPoints(overlay)
    host:SetFrameLevel(frame:GetFrameLevel() + 2)
    local icon = host:CreateTexture(nil, "ARTWORK")
    icon:SetTexCoord(0, 1, 0, 1)
    icon:Hide()
    bar.ClassIcon = icon

    local function applyIcon(s)
        local style = s.btbClassIcon or NONE
        if style == NONE then
            icon:Hide()
            return
        end
        local token = ctx.ClassToken(unit)
        if not token or not ctx.ApplyClassIcon(icon, token, style) then
            icon:Hide()
            return
        end
        local size = s.btbClassIconSize or 14
        local place = ICON_PLACES[s.btbClassIconLocation] or ICON_PLACES.left
        ctx.PP.Size(icon, size, size)
        icon:ClearAllPoints()
        ctx.PP.Point(icon, place.point, overlay, place.point, place.pad + (s.btbClassIconX or 0), s.btbClassIconY or 0)
        icon:Show()
    end

    ns.FrameWidgets.RegisterTextBar(bar, applyTags, applyPositions, applyIcon)

    applyIcon(settings)

    return bar
end

ns.BottomTextBar = { Create = Create }
