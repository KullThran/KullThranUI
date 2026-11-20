-- Runtime ownership of unit-frame widgets. The owner retains its record so
-- callbacks that capture the owner can be collected together on Lua 5.1.
-- oUF element fields remain on the frame itself; these records are not saved.
local _, ns = ...
local Widgets = {}
ns.FrameWidgets = Widgets

local function Record(owner)
    local record = owner._ktWidgets
    if not record then record = {}; owner._ktWidgets = record end
    return record
end

function Widgets.HealthInsets(health)
    local state = Record(health)
    local record = state.insets
    if not record then
        record = {}
        state.insets = record
    end
    return record
end

function Widgets.BindText(owner, bind, place)
    local state = Record(owner)
    local record = state.text
    if not record then record = {}; state.text = record end
    if bind then record.bind = bind end
    if place then record.place = place end
end

function Widgets.PositionText(owner, settings)
    local record = owner._ktWidgets and owner._ktWidgets.text
    if record and record.place then record.place(settings) end
end

function Widgets.RefreshText(owner, settings, rightDefault)
    local record = owner._ktWidgets and owner._ktWidgets.text
    if not record then return end
    if record.bind then
        record.bind(settings.leftTextContent or "name", settings.rightTextContent or rightDefault,
            settings.centerTextContent or "none")
    end
    if record.place then record.place(settings) end
end

function Widgets.TextOverlay(owner, overlay)
    if overlay then Record(owner).overlay = overlay end
    return owner._ktWidgets and owner._ktWidgets.overlay
end

function Widgets.RegisterPowerText(bar, text, update)
    Record(bar).power = { text = text, update = update }
end

function Widgets.PowerText(bar)
    local record = bar and bar._ktWidgets and bar._ktWidgets.power
    return record and record.text
end

function Widgets.RefreshPowerText(bar, settings)
    local record = bar._ktWidgets and bar._ktWidgets.power
    if record and record.update then record.update(settings) end
end

function Widgets.RegisterTextBar(bar, bind, place, icon)
    Record(bar).textBar = { bind = bind, place = place, icon = icon }
end

function Widgets.RefreshTextBar(bar, settings)
    local record = bar._ktWidgets and bar._ktWidgets.textBar
    if not record then return end
    if record.bind then
        record.bind(settings.btbLeftContent or "none", settings.btbRightContent or "none",
            settings.btbCenterContent or "none")
    end
    if record.place then
        record.place(settings)
        if record.icon then record.icon(settings) end
    end
end

-- Class resources have their own lifecycle; they are not entries in the unit registry.
Widgets.ClassResources = {}
