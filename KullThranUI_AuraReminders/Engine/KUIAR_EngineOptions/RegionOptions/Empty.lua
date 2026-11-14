-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class OptionsPrivate
local OptionsPrivate = select(2, ...)

local L = KUIAR_Runtime.L

local function createOptions(id, data)
  local options = {
    __title = L["Settings"],
    __order = 1,
    alpha = {
      type = "range",
      control = "KUIAR_RuntimeSpinBox",
      width = KUIAR_Runtime.normalWidth,
      name = L["Alpha"],
      order = 1,
      min = 0,
      max = 1,
      bigStep = 0.01,
      isPercent = true
    },

    thumbnailIcon = {
      type = "input",
      width = KUIAR_Runtime.doubleWidth - 0.15,
      name = L["Thumbnail Icon"],
      order = 2,
      get = function()
        return data.thumbnailIcon and tostring(data.thumbnailIcon) or ""
      end,
      set = function(info, v)
        data.thumbnailIcon = v
        KUIAR_Runtime.Add(data)
        KUIAR_Runtime.UpdateThumbnail(data)
      end
    },
    chooseIcon = {
      type = "execute",
      width = 0.15,
      name = L["Choose"],
      order = 3,
      func = function()
         OptionsPrivate.OpenIconPicker(data, { [data.id] = {"thumbnailIcon"} }, true)
       end,
       imageWidth = 24,
       imageHeight = 24,
       control = "KUIAR_RuntimeIcon",
       image = "Interface\\AddOns\\KullThranUI_AuraReminders\\Engine\\KUIAR_Engine\\Media\\Textures\\browse",
    },
  }

  return {
    empty = options,
    position = OptionsPrivate.commonOptions.PositionOptions(id, data),
  }

end

local function createThumbnail()
  ---@class frame: FrameScriptObject
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetWidth(32)
  frame:SetHeight(32)

  local border = frame:CreateTexture(nil, "OVERLAY")
  border:SetAllPoints(frame)
  border:SetTexture("Interface\\BUTTONS\\UI-Quickslot2.blp")
  border:SetTexCoord(0.2, 0.8, 0.2, 0.8)

  local icon = frame:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints(frame)
  frame.icon = icon

  return frame
end

local function modifyThumbnail(parent, frame, data)
  local success = OptionsPrivate.Private.SetTextureOrAtlas(frame.icon, data.thumbnailIcon)
  if success then
    frame.icon:Show()
  else
    frame.icon:Hide()
  end
end

-- Register new region type options with M33kAuras
OptionsPrivate.registerRegions = OptionsPrivate.registerRegions or {}
table.insert(OptionsPrivate.registerRegions, function()
  OptionsPrivate.Private.RegisterRegionOptions("empty", createOptions, createThumbnail, L["Empty Base Region"],
                                               createThumbnail, modifyThumbnail,
                                               L["Shows nothing, except sub elements"]);
end)

end)
