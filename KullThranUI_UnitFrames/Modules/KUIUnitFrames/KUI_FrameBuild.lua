-- Builds the bars of a unit frame, the cast bar and bottom bar frames, and a few startup and layout blocks.
-- Same text on Retail and Forever. Everything per call comes from ctx; nothing runs per frame.

local _, ns = ...

local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"

-- Elements a frame gets back when group visibility returns it, in restore order.
local RETURNING_ELEMENTS = { "Health", "Power", "Portrait", "Buffs", "Debuffs", "HealthPrediction" }

-- Rest art that already carries our Show hook. The only state that outlives a call.
local hookedRestArt = {}

local FrameBuild = {}

-- Flat, untiled fill for a status bar.
local function applyFlatFill(bar)
    bar:SetStatusBarTexture(FLAT_TEXTURE)
    bar:GetStatusBarTexture():SetHorizTile(false)
end

-- A solid texture filling its parent, behind everything else on it.
local function addBackdrop(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(parent)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

-- The steps both health builders share before styling. Returns the bar's settings key.
local function prepareHealth(ctx, health, unit)
    local key = ctx.SettingsKeyFor(unit)
    applyFlatFill(health)
    health.bg = addBackdrop(health, 0, 0, 0, 0.5)
    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    health._kuiUnitKey = key
    ctx.SmoothBar(health)
    return key
end

-- Flat health bar of pet, target of target and focus target.
function FrameBuild.MiniHealthBar(ctx, frame, unit, settings, xOffset)
    local PP = ctx.PP
    local health = CreateFrame("StatusBar", nil, frame)
    PP.Point(health, "TOPLEFT", frame, "TOPLEFT", xOffset, 0)
    PP.Point(health, "RIGHT", frame, "RIGHT", 0, 0)
    PP.Height(health, settings.healthHeight)

    local key = prepareHealth(ctx, health, unit)

    -- The styling reads the unit's own table through the key, so the donor texture is lent to it
    -- for this one call. Unguarded: an error leaves the donor value in place.
    local ownTexture = settings.healthBarTexture
    settings.healthBarTexture = ctx.MiniDonorSettings().healthBarTexture
    ctx.StyleBarTexture(health, key)
    settings.healthBarTexture = ownTexture

    ctx.StyleBarAlpha(health, key)
    ctx.StyleBarDark(health)

    frame.Health = health
    return health
end

-- Health bar of player, target, focus and boss. The caller assigns frame.Health.
local function buildFullHealth(ctx, frame, unit, height, xOffset, settings, rightInset)
    local PP = ctx.PP
    xOffset = xOffset or 0
    rightInset = rightInset or 0

    local above = 0
    if (settings.powerPosition or "below") == "above" then
        above = settings.powerHeight or 0
    end

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetFrameStrata(frame:GetFrameStrata())
    health:SetFrameLevel(frame:GetFrameLevel() + 2)
    PP.Point(health, "TOPLEFT", frame, "TOPLEFT", xOffset, -above)
    PP.Point(health, "RIGHT", frame, "RIGHT", -rightInset, 0)
    PP.Height(health, height or settings.healthHeight)

    ns.FrameWidgets.HealthInsets(health).left = xOffset
    ns.FrameWidgets.HealthInsets(health).right = rightInset
    ns.FrameWidgets.HealthInsets(health).top = above

    local key = prepareHealth(ctx, health, unit)
    ctx.StyleBarTexture(health, key)
    ctx.StyleBarAlpha(health, key)
    ctx.StyleBarDark(health)
    return health
end
FrameBuild.FullHealthBar = buildFullHealth

-- Opening steps of the full, focus and boss styles.
function FrameBuild.FullBars(ctx, frame, unit, settings, width, height, xOffset, rightInset, withAbsorb)
    ctx.PP.Size(frame, width, height)
    frame.Health = buildFullHealth(ctx, frame, unit, settings.healthHeight, xOffset, settings, rightInset)
    frame.Power = ctx.BuildPowerBar(frame, unit, settings)
    if withAbsorb then
        ctx.BuildAbsorbBar(frame, unit, settings)
    end
end

-- Opening steps of target of target and focus target: one visible bar, plus a hidden power bar
-- that the stock theme art needs. The power builder sees the settings through a throwaway view.
function FrameBuild.SimpleBars(ctx, frame, unit, settings)
    ctx.PP.Size(frame, settings.frameWidth, settings.healthHeight)
    local health = FrameBuild.MiniHealthBar(ctx, frame, unit, settings, 0)

    local view = setmetatable({
        powerPosition = "none",
        powerHeight = settings.powerHeight or 6,
    }, { __index = settings })
    local power = ctx.BuildPowerBar(frame, unit, view)
    frame.Power = power
    power:Hide()
    return health
end

-- Opening steps of the pet style. A shown portrait takes a square of health height on the left.
function FrameBuild.PetBars(ctx, frame, unit, settings)
    local portraitShown = ctx.Kit.PortraitState(settings)
    local width, xOffset = settings.frameWidth, 0
    if portraitShown then
        width = settings.frameWidth + settings.healthHeight
        xOffset = settings.healthHeight
    end

    ctx.PP.Size(frame, width, settings.healthHeight)
    local health = FrameBuild.MiniHealthBar(ctx, frame, unit, settings, xOffset)
    frame.Power = ctx.BuildPowerBar(frame, unit, settings)
    return health, portraitShown
end

-- Cast bar holder and status bar.
function FrameBuild.CastbarFrame(ctx, frame, unit)
    local PP = ctx.PP
    local settings = ctx.SettingsFor(unit)
    local profile = ctx.GetProfile()
    local powerPosition = settings.powerPosition or "below"

    local width = settings.frameWidth
    if (profile.portraitStyle or "attached") == "attached" and settings.showPortrait ~= false then
        local stack = 0
        if settings.powerHeight and (powerPosition == "below" or powerPosition == "above") then
            stack = settings.powerHeight
        end
        local step = settings.healthHeight + stack + (settings.portraitSize or 0)
        if step < 8 then
            step = 8
        end
        width = width + step
    end

    local height = settings.castbarHeight or 14
    if unit == "player" then
        local playerProfile = profile.player
        local override = playerProfile and playerProfile.playerCastbarHeight or 0
        if override > 0 then
            height = override
        end
    end

    local holder = CreateFrame("Frame", nil, frame)
    PP.Size(holder, width, height)

    local anchor = powerPosition == "below" and frame.Power or frame.Health
    holder:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -(ns.FrameWidgets.HealthInsets(frame.Health).left or 0), 0)

    holder._bgTex = addBackdrop(holder, 0, 0, 0, 0.5)
    PP.CreateBorder(holder, 0, 0, 0, 1, 1, "OVERLAY", 0)

    local castbar = CreateFrame("StatusBar", nil, holder)
    castbar:SetAllPoints(holder)
    applyFlatFill(castbar)
    return holder, castbar
end

-- One white overlay font string on the cast bar, anchored at the given side.
local function addCastText(ctx, castbar, side, x, y)
    local text = castbar:CreateFontString(nil, "OVERLAY")
    ctx.SetFont(text, 11)
    text:SetTextColor(1, 1, 1)
    text:SetPoint(side, castbar, side, x, y)
    text:SetJustifyH(side)
    return text
end

-- Spell name and remaining time.
function FrameBuild.CastbarTexts(ctx, castbar)
    local text = addCastText(ctx, castbar, "LEFT", 5, 1)
    text:SetWordWrap(false)
    castbar.Text = text

    local time = addCastText(ctx, castbar, "RIGHT", -5, 0)
    castbar.Time = time
    return text, time
end

-- Icon box hanging off the holder, with the cropped spell texture inside.
function FrameBuild.CastbarIcon(ctx, holder, castbar)
    local PP = ctx.PP
    local box = CreateFrame("Frame", nil, holder)
    local side = holder:GetHeight() + 1
    box:SetSize(side, side)
    PP.Point(box, "TOPRIGHT", holder, "TOPLEFT", 1, 1)
    addBackdrop(box, 0, 0, 0, 1)
    PP.CreateBorder(box, 0, 0, 0, 1)

    local texture = box:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    castbar.Icon = texture
    castbar._iconFrame = box
    return box, texture
end

-- Bottom text bar frame and the overlay its texts live on.
function FrameBuild.BottomTextBarShell(ctx, frame, settings, anchorFrame, xOffset, overrideWidth)
    local PP = ctx.PP
    local placement = settings.btbPosition or "bottom"
    local detachedTop = placement == "detached_top"
    local detachedBottom = placement == "detached_bottom"

    local width = overrideWidth or settings.frameWidth
    if (detachedTop or detachedBottom) and (settings.btbWidth or 0) > 0 then
        width = settings.btbWidth
    end

    local bar = CreateFrame("Frame", nil, frame)
    PP.Size(bar, width, settings.bottomTextBarHeight or 16)

    -- Detached bars use the saved shift and stay raw; docked bars use xOffset and are snapped.
    local shiftX, shiftY = settings.btbX or 0, settings.btbY or 0
    if detachedTop then
        bar:SetPoint("BOTTOM", frame, "TOP", shiftX, 15 + shiftY)
    elseif detachedBottom then
        bar:SetPoint("TOP", frame, "BOTTOM", shiftX, -15 + shiftY)
    elseif placement == "top" then
        PP.Point(bar, "BOTTOMLEFT", frame.Health or anchorFrame, "TOPLEFT", xOffset or 0, 0)
    else
        PP.Point(bar, "TOPLEFT", anchorFrame, "BOTTOMLEFT", xOffset or 0, 0)
    end

    local r, g, b = 0.2, 0.2, 0.2
    local colour = settings.btbBgColor
    if colour then
        r, g, b = colour.r, colour.g, colour.b
    end
    bar.bg = addBackdrop(bar, r, g, b, settings.btbBgOpacity or 1)

    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints(bar)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 2)
    bar._textOverlay = overlay
    return bar, overlay
end

-- Boss frame size. The portrait backdrop is squared whether the portrait shows or not.
function FrameBuild.BossSize(ctx, frame, settings, showPortrait)
    local PP = ctx.PP
    local barHeight = settings.healthHeight + ctx.Kit.PowerStack(settings, 6)
    local width = settings.frameWidth
    if showPortrait then
        width = width + barHeight
    end
    PP.Size(frame, width, barHeight)

    local portrait = frame.Portrait
    local backdrop = portrait and portrait.backdrop
    if backdrop then
        PP.Size(backdrop, barHeight, barHeight)
    end
    return barHeight, width
end

-- Secure hook on Show of Blizzard's rest art. Shared by all targets, so a fire allocates nothing.
local function onRestArtShown(target)
    if not IsResting() then
        if target.SetAlpha then
            target:SetAlpha(0)
        end
        target:Hide()
    end
end

-- How far the walk over the six rest slots reaches: the bisection the Lua length operator does,
-- written out, so a hole can end the walk before a later filled slot.
local function restWalkLimit(slots)
    if slots[6] ~= nil then
        return 6
    end
    local low, high = 0, 6
    while high - low > 1 do
        local middle = math.floor((low + high) / 2)
        if slots[middle] ~= nil then
            low = middle
        else
            high = middle
        end
    end
    return low
end

-- Shows or hides Blizzard's rest art and hooks each target once. The first Show precedes the hook.
function FrameBuild.RestTargets(ctx, shouldShow)
    local playerFrame = PlayerFrame
    local slots = {
        PlayerRestIcon,
        PlayerRestLoop,
        PlayerRestGlow,
        playerFrame and playerFrame.PlayerRestIcon,
        playerFrame and playerFrame.PlayerRestLoop,
        playerFrame and playerFrame.PlayerRestGlow,
    }
    local secureHook = hooksecurefunc

    for i = 1, restWalkLimit(slots) do
        local target = slots[i]
        if target then
            if shouldShow then
                if target.SetAlpha then target:SetAlpha(1) end
                if target.Show then target:Show() end
            else
                if target.SetAlpha then target:SetAlpha(0) end
                if target.Hide then target:Hide() end
            end
            if secureHook and target.Show and not hookedRestArt[target] then
                hookedRestArt[target] = true
                secureHook(target, "Show", onRestArtShown)
            end
        end
    end
end

-- Spawns one unit and sets it up. A disabled unit still gets its position and menu.
function FrameBuild.SpawnUnit(ctx, style, unit, globalName, applyScale)
    local oUF = ctx.oUF
    oUF:SetActiveStyle(style)
    local frame = oUF:Spawn(unit, globalName)
    ctx.frames[unit] = frame
    ctx.PlaceFrame(frame, unit)
    if applyScale then
        ctx.ScaleFrame(frame, unit)
    end
    ctx.AttachMenu(frame, unit)

    local enabled = ctx.GetProfile().enabledFrames
    if enabled and enabled[unit] == false then
        frame:Hide()
        frame:SetAttribute("unit", nil)
    end
    return frame
end

local function silenceFrame(bossFrame)
    if bossFrame then
        bossFrame:UnregisterAllEvents()
        bossFrame:Hide()
    end
end

-- Turns off Blizzard's five boss frames.
function FrameBuild.SilenceBlizzardBossFrames()
    silenceFrame(Boss1TargetFrame)
    silenceFrame(Boss2TargetFrame)
    silenceFrame(Boss3TargetFrame)
    silenceFrame(Boss4TargetFrame)
    silenceFrame(Boss5TargetFrame)
end

-- oUF turned the Portrait element on at spawn; switch it off where no live portrait is wanted.
function FrameBuild.DisableUnwantedPortraits(ctx)
    local style = ctx.GetProfile().portraitStyle or "attached"
    for key, frame in pairs(ctx.frames) do
        if type(frame) == "table" and frame.Portrait and frame.Portrait.backdrop then
            local s = ctx.SettingsFor(key)
            if s.showPortrait == false or style == "none" or ctx.PortraitMode(key, s) == "class" then
                ctx.Kit.SwitchElement(frame, "Portrait", false)
            end
        end
    end
end

-- Whether the user's settings allow this element on a frame that group visibility brought back.
local function ReturningElementWanted(ctx, name, unitKey, settings)
    if name == "Portrait" then
        local style = ctx.GetProfile().portraitStyle or "attached"
        return settings.showPortrait ~= false and style ~= "none"
            and ctx.PortraitMode(unitKey, settings) ~= "class"
    elseif name == "Buffs" then
        if unitKey == "player" then
            return settings.showBuffs and true or false
        end
        return settings.showBuffs ~= false
    elseif name == "HealthPrediction" and unitKey == "player" then
        return settings.showPlayerAbsorb and true or false
    end
    return true
end

-- Re-enables elements on a frame group visibility brought back, then settles its cast bar.
function FrameBuild.RestoreGroupElements(ctx, frame, unitKey, settings)
    for i = 1, #RETURNING_ELEMENTS do
        local name = RETURNING_ELEMENTS[i]
        if frame[name] and not frame:IsElementEnabled(name)
            and ReturningElementWanted(ctx, name, unitKey, settings) then
            frame:EnableElement(name)
        end
    end

    local castbar = frame.Castbar
    if not castbar then
        return
    end

    local wanted
    if unitKey == "player" then
        wanted = settings.showPlayerCastbar
    else
        wanted = settings.showCastbar ~= false
    end

    local isOn = frame:IsElementEnabled("Castbar")
    if wanted then
        if not isOn then
            frame:EnableElement("Castbar")
        end
    else
        if isOn then
            frame:DisableElement("Castbar")
        end
        castbar:Hide()
        local parent = castbar:GetParent()
        if parent then
            parent:Hide()
        end
    end
end

-- Event frame of group visibility: created once, handler replaced on every install.
function FrameBuild.InstallVisibilityDriver(ctx, handler)
    local frames = ctx.frames
    local driver = frames._visFrame
    if not driver then
        driver = CreateFrame("Frame")
        frames._visFrame = driver
        driver:RegisterEvent("GROUP_ROSTER_UPDATE")
        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    driver:SetScript("OnEvent", handler)
end

-- Sizes then offsets of the left, right and centre texts, fallbacks applied. Nine values.
function FrameBuild.TextSlotMetrics(settings)
    local shared = settings.textSize or 12
    return settings.leftTextSize or shared,
        settings.rightTextSize or shared,
        settings.centerTextSize or shared,
        settings.leftTextX or 0,
        settings.leftTextY or 0,
        settings.rightTextX or 0,
        settings.rightTextY or 0,
        settings.centerTextX or 0,
        settings.centerTextY or 0
end

ns.FrameBuild = FrameBuild
