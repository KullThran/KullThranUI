-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineTemplates", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end

if (GAME_LOCALE or GetLocale()) ~= "deDE" then
  return
end

local L = KUIAR_Runtime.L

-- Upstream CurseForge localization directive, not used here: localization(locale="deDE", format="lua_additive_table", namespace="M33kAuras / Templates")@

end)
