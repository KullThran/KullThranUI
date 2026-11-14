-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

local L = KUIAR_Runtime.L;

local function createOptions(parentData, data, index, subIndex)
  local options = {
    __title = L["Model %s"]:format(subIndex),
    __order = 1,
    model_visible = {
      type = "toggle",
      width = KUIAR_Runtime.doubleWidth,
      name = L["Show Model"],
      order = 9,
    },
    model_fileId = {
      type = "input",
      width = KUIAR_Runtime.doubleWidth - 0.15,
      name = L["Model"],
      order =  10.5,
    },
    chooseModel = {
      type = "execute",
      width = 0.15,
      name = L["Choose"],
      order =  11,
      func = function()
        OptionsPrivate.OpenModelPicker(parentData, {"subRegions", index});
      end,
      imageWidth = 24,
      imageHeight = 24,
      control = "KUIAR_RuntimeIcon",
      image = "Interface\\AddOns\\KullThranUI_AuraReminders\\Engine\\KUIAR_Engine\\Media\\Textures\\browse",
    },
    bar_model_attach = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Attach to Foreground"],
      order = 12,
      hidden = function() return parentData.regionType ~= "aurabar" end
    },
    bar_model_stretch = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Stretched by Foreground"],
      order = 12.1,
      hidden = function()
        return parentData.regionType ~= "aurabar" or not data.bar_model_attach
      end
    },
    bar_model_spacer ={
      type = "description",
      width = KUIAR_Runtime.normalWidth,
      name = "",
      order = 12.15,
      hidden = function()
        return parentData.regionType ~= "aurabar" or data.bar_model_attach
      end
    },
    extra_width = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Extra Width"],
      order = 12.2,
      softMin = -100,
      softMax = 500,
      step = 1,
      hidden = function() return data.bar_model_attach and parentData.regionType == "aurabar" end
    },
    extra_height = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Extra Height"],
      order = 12.3,
      softMin = -100,
      softMax = 500,
      step = 1,
      hidden = function() return data.bar_model_attach and parentData.regionType == "aurabar" end
    },
    model_alpha = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Alpha"],
      order = 13,
      min = 0,
      max = 1,
      bigStep = 0.1
    },
    api = {
      type = "toggle",
      name = L["Use SetTransform"],
      order = 14,
      width = KUIAR_Runtime.normalWidth,
    },
    model_z = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Z Offset"],
      softMin = -20,
      softMax = 20,
      step = .001,
      bigStep = 0.05,
      order = 20,
      hidden = function() return data.api end
    },
    model_x = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["X Offset"],
      softMin = -20,
      softMax = 20,
      step = .001,
      bigStep = 0.05,
      order = 30,
      hidden = function() return data.api end
    },
    model_y = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Y Offset"],
      softMin = -20,
      softMax = 20,
      step = .001,
      bigStep = 0.05,
      order = 40,
      hidden = function() return data.api end
    },
    rotation = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Rotation"],
      min = 0,
      max = 360,
      step = 1,
      bigStep = 3,
      order = 45,
      hidden = function() return data.api end
    },
    -- New Settings
    model_st_tx = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["X Offset"],
      softMin = -1000,
      softMax = 1000,
      step = 1,
      bigStep = 5,
      order = 20,
      hidden = function() return not data.api end
    },
    model_st_ty = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Y Offset"],
      softMin = -1000,
      softMax = 1000,
      step = 1,
      bigStep = 5,
      order = 21,
      hidden = function() return not data.api end
    },
    model_st_tz = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Z Offset"],
      softMin = -1000,
      softMax = 1000,
      step = 1,
      bigStep = 5,
      order = 22,
      hidden = function() return not data.api end
    },
    model_st_rx = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["X Rotation"],
      min = 0,
      max = 360,
      step = 1,
      bigStep = 3,
      order = 23,
      hidden = function() return not data.api end
    },
    model_st_ry = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Y Rotation"],
      min = 0,
      max = 360,
      step = 1,
      bigStep = 3,
      order = 24,
      hidden = function() return not data.api end
    },
    model_st_rz = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Z Rotation"],
      min = 0,
      max = 360,
      step = 1,
      bigStep = 3,
      order = 25,
      hidden = function() return not data.api end
    },
    model_st_us = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Scale"],
      min = 5,
      max = 1000,
      step = 0.1,
      bigStep = 5,
      order = 26,
      hidden = function() return not data.api end
    },
  }

  OptionsPrivate.AddUpDownDeleteDuplicate(options, parentData, index, "submodel")

  return options
end

KUIAR_Runtime.RegisterSubRegionOptions("submodel", createOptions, L["Shows a model"]);

end)
