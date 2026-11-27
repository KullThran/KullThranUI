-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_Engine", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

function KUIAR_Runtime.IsDurationObject(duration)
  if type(duration) == "userdata" and duration.GetRemainingDuration then
    return true
  end
  return false
end

local typeToFormatter = {
  elapsed = "FormatElapsedDuration",
  remaining = "FormatRemainingDuration",
  total = "FormatTotalDuration",
}

local typeToGetter = {
  elapsed = "GetElapsedDuration",
  remaining = "GetRemainingDuration",
  total = "GetTotalDuration",
}

function KUIAR_Runtime.GetDurationObjectValue(duration, type, formatter)
  if formatter then
    return duration[typeToFormatter[type]](duration, formatter)
  else
    return duration[typeToGetter[type]](duration)
  end
end

end)
