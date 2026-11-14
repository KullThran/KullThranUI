-- Re-derives the size of every part of a unit frame after a scale or layout change. Pixel rounding rounds each part on
-- its own, so the parts can add up to a pixel more than the frame; any part that overflows is trimmed to fit.

local _, ns = ...

local floor, max, abs = math.floor, math.max, math.abs

local MARGIN = 0.01

-- Trims a region to an allowance, with no call at all when it already fits.
local function TrimWidth(PP, region, allowed)
    if region:GetWidth() > allowed + MARGIN then
        PP.Width(region, allowed)
    end
end

local function TrimHeight(PP, region, allowed)
    if region:GetHeight() > allowed + MARGIN then
        PP.Height(region, allowed)
    end
end

local function Update(ctx, frame, unit)
    -- The frame is a protected button: in combat all that may happen is asking for a refresh later.
    if InCombatLockdown and InCombatLockdown() then
        ctx.QueueLayoutRefresh()
        return
    end
    if not frame then
        return
    end
    local settings = ctx.SettingsFor(unit)
    if not settings then
        return
    end

    local PP = ctx.PP
    if frame.unifiedBorder then
        PP.SetBorderSize(frame.unifiedBorder, settings.borderSize or 1)
    end
    -- Themed art has just set its own geometry.
    if frame._ktForeverLayoutActive or frame._ktClassicLayoutActive then
        return
    end

    -- The numbers everything below is measured against.
    local hh, fw = settings.healthHeight, settings.frameWidth

    local powerPos = settings.powerPosition or "below"
    local powerStacked = powerPos == "below" or powerPos == "above"
    local powerDetached = powerPos == "detached_top" or powerPos == "detached_bottom"
    local ph = settings.powerHeight or 6
    local mini = unit == "targettarget" or unit == "focustarget"

    local btbPos = settings.btbPosition or "bottom"
    local btbStacked = btbPos == "top" or btbPos == "bottom"
    local btbExtra = 0
    if settings.bottomTextBar and btbStacked then
        btbExtra = settings.bottomTextBarHeight or 16
    end

    local attached = (ctx.GetProfile().portraitStyle or "attached") == "attached"
    local attachedShown = attached and settings.showPortrait ~= false
    local side = settings.portraitSide or "right"
    if side == "top" and attached then
        side = "right"
    end

    local cpExtra = 0
    if unit == "player" and settings.classPowerStyle == "modern" and (settings.classPowerPosition or "top") == "above" then
        cpExtra = max(3, floor((settings.classPowerSize or 8) * 0.375))
    end

    local barArea = hh + cpExtra
    if powerStacked and not mini then
        barArea = barArea + ph
    end
    local frameH = barArea + btbExtra
    local step = max(8, barArea + (settings.portraitSize or 0))
    local frameW = fw
    if attachedShown then
        frameW = fw + step
    end

    -- The frame first: every trim uses what it reports afterwards.
    PP.Size(frame, frameW, frameH)
    local W, H = frame:GetWidth(), frame:GetHeight()

    -- Attached portrait.
    local portrait = frame.Portrait
    local backdrop = attachedShown and portrait and portrait.backdrop
    if backdrop then
        PP.Size(backdrop, step, step)
        TrimWidth(PP, backdrop, W - fw)
        TrimHeight(PP, backdrop, H)
    end

    -- Health, seated beside the portrait's trimmed width.
    local health = frame.Health
    if health then
        PP.Height(health, hh)
        if backdrop then
            local portraitW = backdrop:GetWidth()
            local left, right = 0, 0
            if side == "left" then
                left = portraitW
            elseif side == "right" then
                right = portraitW
            end
            health:ClearAllPoints()
            PP.Point(health, "TOPLEFT", frame, "TOPLEFT", left, -(ns.FrameWidgets.HealthInsets(health).top or 0))
            PP.Point(health, "RIGHT", frame, "RIGHT", -right, 0)
            -- Owner's rule: the height is applied again once the new anchors are set.
            PP.Height(health, hh)
            ns.FrameWidgets.HealthInsets(health).left = left
            ns.FrameWidgets.HealthInsets(health).right = right
        end
    end

    -- Power.
    local power = frame.Power
    if power and powerPos ~= "none" then
        local powerW = fw
        if powerDetached and (settings.powerWidth or 0) > 0 then
            powerW = settings.powerWidth
        end
        PP.Size(power, powerW, ph)
        if powerStacked and health then
            TrimHeight(PP, power, hh + ph - health:GetHeight())
            local healthW = health:GetWidth()
            if abs(power:GetWidth() - healthW) > MARGIN then
                PP.Width(power, healthW)
            end
        elseif not powerDetached then
            TrimWidth(PP, power, W)
        end
    end

    -- Text bar, measured against what the stack above it really took.
    local bar = frame.BottomTextBar
    if bar and settings.bottomTextBar and btbStacked then
        PP.Size(bar, frameW, settings.bottomTextBarHeight or 16)
        TrimWidth(PP, bar, W)
        local above = cpExtra
        if health then
            above = above + health:GetHeight()
        end
        if power and powerStacked then
            above = above + power:GetHeight()
        end
        TrimHeight(PP, bar, H - above)
    end

    -- Cast bar, through its holder.
    local castbar = frame.Castbar
    local holder = castbar and castbar:GetParent()
    if holder then
        TrimWidth(PP, holder, W)
        if holder._ppBorders then
            PP.SetBorderSize(holder, 1)
            castbar:ClearAllPoints()
            PP.Point(castbar, "TOPLEFT", holder, "TOPLEFT", 0, 0)
            PP.Point(castbar, "BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
        end
    end
end

ns.ScaleFit = { Update = Update }
