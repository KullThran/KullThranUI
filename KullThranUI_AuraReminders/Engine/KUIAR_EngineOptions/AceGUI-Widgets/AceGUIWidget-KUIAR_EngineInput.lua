-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end

local Type, Version = "KUIAR_RuntimeInput", 2
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local eventCallbacks = {
  OnEditFocusGained = "OnEditFocusGained",
  OnEditFocusLost = "OnEditFocusLost",
  OnEnterPressed = "OnEnterPressed",
  OnShow = "OnShow"
}

local function EventHandler(frame, event)
  local self = frame.obj
  local option = self.userdata.option
  if option and option.callbacks and option.callbacks[event] then
    option.callbacks[event](self)
  end
end

local function Constructor()
  local widget = AceGUI:Create("EditBox")
  widget.type = Type

  for event, callback in pairs(eventCallbacks) do
    widget.editbox:HookScript(event, function(frame) EventHandler(frame, callback) end)
  end

  return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

end)
