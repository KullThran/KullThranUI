-- Custom aura engine, animations: one when the aura appears (fade in, zoom in), one that loops while it is shown
-- (pulse, flash, shake) and one when it goes (fade out, shrink). Built from the client's animation groups on the
-- aura's own frame, so a delegated slot inside it moves with it. A frame that cannot animate is shown and hidden at
-- once. Shared byte for byte between the Retail and Forever workspaces.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local Anim = {}
E.Anim = Anim

Anim.IN = 0.25
Anim.OUT = 0.3
Anim.LOOP = 0.5

local function Can(f)
    return type(f) == "table" and type(f.CreateAnimationGroup) == "function"
end

local function Alpha(group, from, to, duration, order)
    local a = group:CreateAnimation("Alpha")
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    a:SetDuration(duration)
    if order then a:SetOrder(order) end
    return a
end

local function Scale(group, from, to, duration, order)
    local a = group:CreateAnimation("Scale")
    if a.SetScaleFrom then
        a:SetScaleFrom(from, from)
        a:SetScaleTo(to, to)
    else
        a:SetScale(to / from, to / from)
    end
    a:SetDuration(duration)
    if order then a:SetOrder(order) end
    return a
end

local function Move(group, x, duration, order)
    local a = group:CreateAnimation("Translation")
    a:SetOffset(x, 0)
    a:SetDuration(duration)
    a:SetOrder(order)
    return a
end

-- The frame's groups, built once by kind.
local function Group(f, slot, kind, build)
    f.anims = f.anims or {}
    local current = f.anims[slot]
    if current and current.kind == kind then return current.group end
    if current then current.group:Stop() end
    local group = f:CreateAnimationGroup()
    build(group)
    f.anims[slot] = { kind = kind, group = group }
    return group
end

local BUILD = {
    start = {
        fade = function(g) Alpha(g, 0, 1, Anim.IN) end,
        zoom = function(g)
            Scale(g, 0.4, 1, Anim.IN)
            Alpha(g, 0, 1, Anim.IN)
        end,
    },
    main = {
        pulse = function(g)
            g:SetLooping("BOUNCE")
            Scale(g, 1, 1.15, Anim.LOOP)
        end,
        flash = function(g)
            g:SetLooping("BOUNCE")
            Alpha(g, 1, 0.3, Anim.LOOP)
        end,
        shake = function(g)
            g:SetLooping("REPEAT")
            Move(g, 4, 0.05, 1)
            Move(g, -8, 0.1, 2)
            Move(g, 4, 0.05, 3)
        end,
    },
    finish = {
        fade = function(g) Alpha(g, 1, 0, Anim.OUT) end,
        shrink = function(g)
            Scale(g, 1, 0.3, Anim.OUT)
            Alpha(g, 1, 0, Anim.OUT)
        end,
    },
}

local function Stop(f, slot)
    local entry = f.anims and f.anims[slot]
    if entry and entry.group:IsPlaying() then entry.group:Stop() end
end

local function Animations(record)
    return (record and record.animations) or {}
end

-- Whether the frame is playing its going animation; it is hidden when that ends.
function Anim.Finishing(f)
    return f.animFinishing == true
end

-- After the frame was shown for this pass: the appearing animation when it was hidden before, the loop while shown.
function Anim.Shown(f, record)
    local anims = Animations(record)
    local wasVisible = f.animVisible == true
    if f.animFinishing then
        Stop(f, "finish")
        f.animFinishing = nil
        wasVisible = false
    end
    f.animVisible = true
    if not Can(f) then return end

    if not wasVisible and anims.start then
        Group(f, "start", anims.start, BUILD.start[anims.start]):Play()
    end
    if anims.main then
        local group = Group(f, "main", anims.main, BUILD.main[anims.main])
        if not group:IsPlaying() then group:Play() end
    else
        Stop(f, "main")
    end
end

-- Hides the frame through `hide`: at once, or once the going animation has played. A pass that hides a frame that is
-- already going leaves it going.
function Anim.Hide(f, record, hide)
    if f.animFinishing then return end
    local anims = Animations(record)
    local visible = f.animVisible == true and f.IsShown and f:IsShown()
    f.animVisible = false
    Stop(f, "main")
    Stop(f, "start")
    if not (visible and anims.finish and Can(f)) then
        hide(f)
        return
    end
    local group = Group(f, "finish", anims.finish, BUILD.finish[anims.finish])
    f.animFinishing = true
    group:SetScript("OnFinished", function()
        f.animFinishing = nil
        if not f.animVisible then hide(f) end
    end)
    group:Play()
end

-- Stops everything at once (placing mode, a deleted aura): no animation is left running.
function Anim.Reset(f)
    for slot in pairs(f.anims or {}) do Stop(f, slot) end
    f.animFinishing, f.animVisible = nil, nil
end
