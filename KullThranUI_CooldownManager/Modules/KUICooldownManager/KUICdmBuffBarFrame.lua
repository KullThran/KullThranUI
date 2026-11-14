-- Frames of one tracked buff bar and the application of its saved settings. Every size and anchor here is raw.
local _, ns = ...

local WHITE8 = "Interface\\Buttons\\WHITE8x8"
local SPARK_FILE = "Interface\\AddOns\\KullThranUI\\Modules\\Nameplates\\Media\\cast_spark.tga"

-- Label placement by position keyword.
local SLOTS = {
    center = { labelPoint = "CENTER", barPoint = "CENTER", x = 0, y = 0, justify = "CENTER" },
    top = { labelPoint = "BOTTOM", barPoint = "TOP", x = 0, y = 5, justify = "CENTER" },
    bottom = { labelPoint = "TOP", barPoint = "BOTTOM", x = 0, y = -5, justify = "CENTER" },
    left = { labelPoint = "LEFT", barPoint = "LEFT", x = 5, y = 0, justify = "LEFT" },
    right = { labelPoint = "RIGHT", barPoint = "RIGHT", x = -5, y = 0, justify = "RIGHT" },
}

-- Creates a frame covering its parent at the given level.
local function NewCoveringFrame(parent, level)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:SetFrameLevel(level)
    return frame
end

-- Font, size and flags of a label, with its shadow off.
local function SetLabelFont(ctx, label, size)
    label:SetFont(ctx.FontPath(), size, "OUTLINE")
    label:SetShadowOffset(0, 0)
end

-- A label on the text overlay, with its starting font and colour.
local function NewLabel(ctx, overlay)
    local label = overlay:CreateFontString(nil, "OVERLAY")
    SetLabelFont(ctx, label, 11)
    label:SetTextColor(1, 1, 1, 0.9)
    return label
end

-- Puts a label into a slot, shifted by the saved offsets, and leaves it with one anchor.
local function PlaceInSlot(label, statusBar, slot, x, y)
    label:ClearAllPoints()
    label:SetPoint(slot.labelPoint, statusBar, slot.barPoint, slot.x + (x or 0), slot.y + (y or 0))
end

local Frame = {}
ns.CdmBuffBarFrame = Frame

-- Builds the seven frames of a bar, hidden, with their regions.
function Frame.CreateBar(ctx, parent, idx)
    local wrap = CreateFrame("Frame", "CDM_TBBWrap" .. idx, parent)
    wrap:SetFrameStrata("MEDIUM")
    wrap:SetFrameLevel(10)
    wrap:Hide()

    local statusBar = CreateFrame("StatusBar", "CDM_TBB" .. idx, wrap)
    statusBar:SetStatusBarTexture(WHITE8)
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0.65)
    if statusBar.EnableMouseClicks then statusBar:EnableMouseClicks(false) end
    wrap._bar = statusBar

    local background = statusBar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(statusBar)
    background:SetColorTexture(0, 0, 0, 0.4)
    wrap._bg = background

    local spark = statusBar:CreateTexture(nil, "OVERLAY", nil, 2)
    spark:SetTexture(SPARK_FILE)
    spark:SetBlendMode("ADD")
    spark:Hide()
    wrap._spark = spark

    -- Labels live on their own frame so they stay above the fill and the gradient.
    local textOverlay = NewCoveringFrame(statusBar, statusBar:GetFrameLevel() + 3)
    wrap._textOverlay = textOverlay

    local timerText = NewLabel(ctx, textOverlay)
    timerText:SetPoint("RIGHT", statusBar, "RIGHT", -4, 0)
    timerText:SetJustifyH("RIGHT")
    wrap._timerText = timerText

    local nameText = NewLabel(ctx, textOverlay)
    nameText:SetPoint("LEFT", statusBar, "LEFT", 4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    wrap._nameText = nameText

    local stacksText = NewLabel(ctx, textOverlay)
    stacksText:SetPoint("CENTER", statusBar, "CENTER", 0, 0)
    stacksText:Hide()
    wrap._stacksText = stacksText

    local icon = CreateFrame("Frame", nil, wrap)
    icon:SetSize(24, 24)
    icon:Hide()
    local iconTexture = icon:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints(icon)
    iconTexture:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    icon._tex = iconTexture
    wrap._icon = icon

    local wrapLevel = wrap:GetFrameLevel()

    local borderHost = NewCoveringFrame(wrap, wrapLevel + 5)
    borderHost:Hide()
    wrap._barBorder = borderHost

    local glowHost = NewCoveringFrame(wrap, wrapLevel + 6)
    glowHost:SetAlpha(0)
    glowHost:EnableMouse(false)
    wrap._pandemicGlowOverlay = glowHost

    local cooldown = CreateFrame("Cooldown", nil, statusBar, "CooldownFrameTemplate")
    cooldown:SetAllPoints(statusBar)
    cooldown:SetDrawSwipe(false)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawEdge(false)
    cooldown:SetAlpha(0)
    cooldown:Hide()
    wrap._cooldown = cooldown

    return wrap
end

-- Wrap size, status bar anchors and orientation. Returns the icon's corner, nil with no icon.
local function ApplyGeometry(bar, statusBar, cfg, width, height, vertical)
    local display = cfg.iconDisplay or "left"
    local hasIcon = display ~= "none"

    local longSide = hasIcon and (width + height) or width
    if vertical then
        bar:SetSize(height, longSide)
    else
        bar:SetSize(longSide, height)
    end

    statusBar:ClearAllPoints()
    local corner
    if hasIcon then
        local startSide = display == "left"
        local topLeftX, topLeftY, bottomRightX, bottomRightY = 0, 0, 0, 0
        if vertical then
            if startSide then
                bottomRightY, corner = height, "BOTTOMLEFT"
            else
                topLeftY, corner = -height, "TOPLEFT"
            end
        elseif startSide then
            topLeftX, corner = height, "TOPLEFT"
        else
            bottomRightX, corner = -height, "TOPRIGHT"
        end
        statusBar:SetPoint("TOPLEFT", bar, "TOPLEFT", topLeftX, topLeftY)
        statusBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", bottomRightX, bottomRightY)
    else
        statusBar:SetAllPoints(bar)
    end

    statusBar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    bar._lastVertical = cfg.verticalOrientation
    return corner
end

-- The clip follows the fill and cuts a bar-sized texture, so the gradient keeps in step with no per-update maths.
local function EnsureGradientClip(bar, statusBar)
    local clip = bar._gradClip
    if clip then return clip end

    clip = CreateFrame("Frame", nil, statusBar)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(statusBar:GetFrameLevel() + 1)
    bar._gradClip = clip

    local texture = clip:CreateTexture(nil, "ARTWORK", nil, 1)
    texture:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 0, 0)
    texture:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", 0, 0)
    bar._gradTex = texture
    return clip
end

-- Fill texture, colours and gradient. Returns what the spark should follow.
local function ApplyFill(ctx, bar, statusBar, cfg)
    local map = ctx.Textures
    local path = map and map[cfg.texture or "none"]
    if type(path) ~= "string" or path == "" then path = WHITE8 end

    if path ~= bar._lastTexPath then
        statusBar:SetStatusBarTexture(path)
        bar._lastTexPath = path
    end

    local r = cfg.fillR or ctx.FillDefaultR
    local g = cfg.fillG or ctx.FillDefaultG
    local b = cfg.fillB or ctx.FillDefaultB
    local a = cfg.fillA or 1
    bar._baseFillR, bar._baseFillG, bar._baseFillB, bar._baseFillA = r, g, b, a

    bar._bg:SetColorTexture(cfg.bgR or 0, cfg.bgG or 0, cfg.bgB or 0, cfg.bgA or 0.4)

    local fill = statusBar:GetStatusBarTexture()
    if not cfg.gradientEnabled then
        bar._gradientActive = nil
        if bar._gradClip then bar._gradClip:Hide() end
        fill:SetVertexColor(r, g, b, a)
        return fill
    end

    bar._gradientActive = true
    local clip = EnsureGradientClip(bar, statusBar)
    clip:ClearAllPoints()
    clip:SetAllPoints(fill)
    clip:Show()

    local texture = bar._gradTex
    texture:SetTexture(path)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetGradient(cfg.gradientDir or "HORIZONTAL", CreateColor(r, g, b, a),
        CreateColor(cfg.gradientR or 0.20, cfg.gradientG or 0.20, cfg.gradientB or 0.80, cfg.gradientA or 1))

    fill:SetVertexColor(1, 1, 1, 0)
    return clip
end

-- Timer, name and stack labels. Text is not set here, and the stack label's visibility is left to the stack code.
local function ApplyLabels(ctx, bar, statusBar, cfg, width, vertical)
    local timerText = bar._timerText
    local timerPosition = cfg.timerPosition
    if timerPosition == nil then
        timerPosition = cfg.showTimer and "right" or "none"
    end
    if timerPosition == "none" then
        timerText:Hide()
    else
        timerText:Show()
        SetLabelFont(ctx, timerText, cfg.timerSize or 11)
        if vertical then
            timerText:ClearAllPoints()
            timerText:SetPoint("TOP", statusBar, "TOP", cfg.timerX or 0, -8 + (cfg.timerY or 0))
            timerText:SetJustifyH("CENTER")
        else
            local slot = SLOTS[timerPosition] or SLOTS.right
            PlaceInSlot(timerText, statusBar, slot, cfg.timerX, cfg.timerY)
            timerText:SetJustifyH(slot.justify)
        end
    end

    local nameText = bar._nameText
    local namePosition = cfg.namePosition
    if namePosition == nil then
        namePosition = cfg.showName == false and "none" or "left"
    end
    if namePosition == "none" or vertical then
        nameText:Hide()
    else
        nameText:Show()
        SetLabelFont(ctx, nameText, cfg.nameSize or 11)
        local slot = SLOTS[namePosition] or SLOTS.left
        PlaceInSlot(nameText, statusBar, slot, cfg.nameX, cfg.nameY)
        nameText:SetJustifyH(slot.justify)
        nameText:SetWidth(timerPosition ~= "none" and (width - 12 - 45) or (width - 12))
    end

    local stacksText = bar._stacksText
    local stacksPosition = cfg.stacksPosition or "center"
    if stacksPosition == "none" then
        stacksText:Hide()
        bar._stacksHidden = true
    else
        bar._stacksHidden = nil
        SetLabelFont(ctx, stacksText, cfg.stacksSize or 11)
        PlaceInSlot(stacksText, statusBar, SLOTS[stacksPosition] or SLOTS.center, cfg.stacksX, cfg.stacksY)
    end
end

-- Border on its host frame, through the two border functions of PP.
local function ApplyBorder(ctx, bar, cfg)
    local host = bar._barBorder
    local thickness = cfg.borderSize or 0
    if thickness <= 0 then
        host:Hide()
        return
    end

    local pp = ctx.PP
    if not pp then return end

    local r, g, b = cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0
    if host._ppBorders then
        pp.UpdateBorder(host, thickness, r, g, b, 1)
    else
        pp.CreateBorder(host, r, g, b, 1, thickness)
    end
    host:Show()
end

-- Applies one bar's saved settings to its frames. Never shows or hides the wrap.
function Frame.ApplySettings(ctx, bar, cfg)
    if not bar or not cfg or not bar._bar then return end

    local statusBar = bar._bar
    local width = cfg.width or 200
    local height = cfg.height or 18
    local vertical = cfg.verticalOrientation and true or false

    local iconCorner = ApplyGeometry(bar, statusBar, cfg, width, height, vertical)
    local sparkTarget = ApplyFill(ctx, bar, statusBar, cfg)

    -- Once the bar is ready the fade script moves the alpha to the target.
    local opacity = cfg.opacity or 1
    bar._opacityTarget = opacity
    if not bar._tbbReady then bar:SetAlpha(opacity) end

    ApplyLabels(ctx, bar, statusBar, cfg, width, vertical)

    local spark = bar._spark
    if cfg.showSpark then
        spark:SetSize(8, height)
        spark:SetRotation(0)
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", sparkTarget, vertical and "TOP" or "RIGHT", 0, 0)
        spark:Show()
    else
        spark:Hide()
    end

    local icon = bar._icon
    if iconCorner then
        icon:SetSize(height, height)
        icon:ClearAllPoints()
        icon:SetPoint(iconCorner, bar, iconCorner, 0, 0)
        icon:Show()
    else
        icon:Hide()
    end

    ApplyBorder(ctx, bar, cfg)

    -- Marks run last, on the final texture and size. The dirty mark lets the timers place ticks once a size exists.
    if not bar._threshTicks then bar._threshTicks = {} end
    if not bar._tickOverlay then
        bar._tickOverlay = NewCoveringFrame(statusBar, statusBar:GetFrameLevel() + 3)
    end
    local marks = ctx.Marks
    marks.RefreshThresholdOverlay(ctx, bar, cfg)
    marks.UpdateTickMarks(ctx, statusBar, cfg, bar._threshTicks, cfg.verticalOrientation, bar._tickOverlay)
    bar._ticksDirty = true
end
