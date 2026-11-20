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
  local pointAnchors = {}
  local areaAnchors = {}
  for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
    Mixin(pointAnchors, OptionsPrivate.Private.GetAnchorsForData(child, "point"))
    Mixin(areaAnchors, OptionsPrivate.Private.GetAnchorsForData(child, "area"))
  end

  local options = {
    __title = L["Circular Texture %s"]:format(subIndex),
    __order = 1,
    circularTextureVisible = {
      type = "toggle",
      width = KUIAR_Runtime.doubleWidth,
      name = L["Show Circular Texture"],
      order = 1,
    },
    circularTextureTexture = {
      type = "input",
      width = KUIAR_Runtime.doubleWidth - 0.15,
      name = L["Texture"],
      order = 2,
    },
    chooseTexture = {
      type = "execute",
      width = 0.15,
      name = L["Choose"],
      order = 3,
      func = function()
        local path = { "subRegions", index }
        local paths = {}
        for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
          paths[child.id] = path
        end
        OptionsPrivate.OpenTexturePicker(parentData, paths, {
          texture = "circularTextureTexture",
          color = "circularTextureColor",
          blendMode = "circularTextureBlendMode"
        }, OptionsPrivate.Private.texture_types, nil)
      end,
      imageWidth = 24,
      imageHeight = 24,
      control = "KUIAR_RuntimeIcon",
      image = "Interface\\AddOns\\KullThranUI_AuraReminders\\Engine\\KUIAR_Engine\\Media\\Textures\\browse",
    },
    circularTextureClockwise = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Clockwise"],
      order = 4,
    },
    circularTextureMirror = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Mirror"],
      order = 5,
    },
    circularTextureColor = {
      type = "color",
      width = KUIAR_Runtime.normalWidth,
      name = L["Color"],
      hasAlpha = true,
      order = 6
    },
    circularTextureDesaturate = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Desaturate"],
      order = 7,
    },
    circularTextureBlendMode = {
      type = "select",
      width = KUIAR_Runtime.normalWidth,
      name = L["Blend Mode"],
      order = 8,
      values = OptionsPrivate.Private.blend_types
    },
    circularTextureInverse = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Inverse"],
      order = 8.5,
    },
    circularTextureStartAngle = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      order = 9,
      name = L["Start Angle"],
      min = 0,
      max = 360,
      bigStep = 1,
    },
    circularTextureEndAngle = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      order = 10,
      name = L["End Angle"],
      min = 0,
      max = 360,
      bigStep = 1,
     },
     circularTextureCrop_x = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Crop X"],
      order = 11,
      min = 0,
      softMax = 2,
      bigStep = 0.01,
      isPercent = true,
    },
    circularTextureCrop_y = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Crop Y"],
      order = 12,
      min = 0,
      softMax = 2,
      bigStep = 0.01,
      isPercent = true,
    },
    -- Doesn't appear to work
    circularTextureRotation = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Texture Rotation"],
      desc = L["Uses Texture Coordinates to rotate the texture."],
      order = 13,
      min = 0,
      max = 360,
      bigStep = 1
    },
    -- Doesn't appear to work
    circularTextureAuraRotation = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Rotation"],
      order = 14,
      min = 0,
      max = 360,
      bigStep = 1
    },
  }

  OptionsPrivate.commonOptions.ProgressOptionsForSubElement(parentData, data, options, 16)
  OptionsPrivate.commonOptions.PositionOptionsForSubElement(data, options, 17, areaAnchors, pointAnchors)

  OptionsPrivate.AddUpDownDeleteDuplicate(options, parentData, index, "subcirculartexture")

  return options
end

  KUIAR_Runtime.RegisterSubRegionOptions("subcirculartexture", createOptions, L["Shows a Circular Progress Texture"]);

end)
