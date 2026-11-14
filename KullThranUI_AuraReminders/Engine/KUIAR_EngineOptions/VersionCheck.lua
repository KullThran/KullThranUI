-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

local L = KUIAR_Runtime.L

local optionsVersion = "@project-version@"
--@debug@
optionsVersion = "Dev"
--@end-debug@

if optionsVersion ~= KUIAR_Runtime.versionString then
  local message = string.format(L["The KUIAR_Runtime Options Addon version %s doesn't match the KUIAR_Runtime version %s. If you updated the addon while the game was running, try restarting World of Warcraft. Otherwise try reinstalling KUIAR_Runtime"],
                    optionsVersion, KUIAR_Runtime.versionString)
  ---@diagnostic disable-next-line: duplicate-set-field
  KUIAR_Runtime.IsLibsOk = function() return false end
  ---@diagnostic disable-next-line: duplicate-set-field
  KUIAR_Runtime.ToggleOptions = function()
       KUIAR_Runtime.prettyPrint(message)
  end

end

end)
