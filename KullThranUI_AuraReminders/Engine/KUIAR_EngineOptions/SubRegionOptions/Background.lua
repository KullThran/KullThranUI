-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)
local L = KUIAR_Runtime.L;

do
  local function subCreateOptions(parentData, data, index, subIndex)
      local options = {
        __title = L["Background"],
        __order = 1,
        __up = function()
          for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
            OptionsPrivate.MoveSubRegionUp(child, index, "subbackground")
          end
          KUIAR_Runtime.ClearAndUpdateOptions(parentData.id)
        end,
        __down = function()
          for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
            OptionsPrivate.MoveSubRegionDown(child, index, "subbackground")
          end
          KUIAR_Runtime.ClearAndUpdateOptions(parentData.id)
        end,
        __notcollapsable = true
      }
      return options
    end

  KUIAR_Runtime.RegisterSubRegionOptions("subbackground", subCreateOptions, L["Background"]);
end

-- Foreground for aurabar

do
  local function subCreateOptions(parentData, data, index, subIndex)
    local options = {
      __title = L["Foreground"],
      __order = 1,
      __up = function()
        for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
          OptionsPrivate.MoveSubRegionUp(child, index, "subforeground")
        end
        KUIAR_Runtime.ClearAndUpdateOptions(parentData.id)
      end,
      __down = function()
        for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
          OptionsPrivate.MoveSubRegionDown(child, index, "subforeground")
        end
        KUIAR_Runtime.ClearAndUpdateOptions(parentData.id)
      end,
      __notcollapsable = true
    }
    return options
  end

  KUIAR_Runtime.RegisterSubRegionOptions("subforeground", subCreateOptions, L["Foreground"]);
end

end)
