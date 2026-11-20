-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_Engine", function(...)
--[[ Manual override for the default font and font size until proper options are built ]]

KUIAR_Runtime.defaultFont = "Friz Quadrata TT"
KUIAR_Runtime.defaultFontSize = 12

end)
