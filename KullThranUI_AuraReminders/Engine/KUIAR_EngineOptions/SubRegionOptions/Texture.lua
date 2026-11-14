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
    __title = L["Texture %s"]:format(subIndex),
    __order = 1,
    textureVisible = {
      type = "toggle",
      width = KUIAR_Runtime.doubleWidth,
      name = L["Show Texture"],
      order = 1,
    },
    textureTexture = {
      type = "input",
      width = KUIAR_Runtime.doubleWidth - 0.15,
      name = L["Texture"],
      order = 2,
    },
    chooseTexture = {
      type = "execute",
      width = 0.15,
      name = L["Choose"],
      order = 2.1,
      func = function()
        local path = { "subRegions", index }
        local paths = {}
        for child in OptionsPrivate.Private.TraverseLeafsOrAura(parentData) do
          paths[child.id] = path
        end
        OptionsPrivate.OpenTexturePicker(parentData, paths, {
          texture = "textureTexture",
          color = "textureColor",
          mirror = "textureMirror",
          blendMode = "textureBlendMode"
        }, OptionsPrivate.Private.texture_types)
      end,
      imageWidth = 24,
      imageHeight = 24,
      control = "KUIAR_RuntimeIcon",
      image = "Interface\\AddOns\\KullThranUI_AuraReminders\\Engine\\KUIAR_Engine\\Media\\Textures\\browse",
    },
    textureColor = {
      type = "color",
      width = KUIAR_Runtime.normalWidth,
      name = L["Color"],
      hasAlpha = true,
      order = 3
    },
    textureDesaturate = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Desaturate"],
      order = 4,
    },
    textureBlendMode = {
      type = "select",
      width = KUIAR_Runtime.normalWidth,
      name = L["Blend Mode"],
      order = 11,
      values = OptionsPrivate.Private.blend_types
    },
    textureMirror = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Mirror"],
      order = 12
    },

    textureRotate = {
      type = "toggle",
      width = KUIAR_Runtime.normalWidth,
      name = L["Allow Full Rotation"],
      order = 13,
      hidden = data and OptionsPrivate.Private.TextureBase.IsAtlas(data.texture)
    },
    textureRotation = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Rotation"],
      min = 0,
      max = 360,
      step = 1,
      bigStep = 3,
      order = 14,
    },
  }

  OptionsPrivate.commonOptions.PositionOptionsForSubElement(data, options, 15, areaAnchors, pointAnchors)
  OptionsPrivate.AddUpDownDeleteDuplicate(options, parentData, index, "subtexture")

  return options
end

  KUIAR_Runtime.RegisterSubRegionOptions("subtexture", createOptions, L["Shows a Texture"]);

end)
