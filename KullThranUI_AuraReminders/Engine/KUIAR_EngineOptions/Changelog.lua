-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)


end)
