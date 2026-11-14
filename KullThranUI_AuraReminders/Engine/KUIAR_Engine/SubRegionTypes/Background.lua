-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_Engine", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end
---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)
local L = KUIAR_Runtime.L;

do
  local function subSupports(regionType)
    return regionType ~= "group" and regionType ~= "dynamicgroup"
  end

  local function noop()
  end

  local function subSetFrameLevel(self, level)
    self.parent:SetFrameLevel(level)
  end

  local function subCreate()
    return { Update = noop, SetFrameLevel = subSetFrameLevel}
  end

  local function subModify(parent, region)
    region.parent = parent
  end

  KUIAR_Runtime.RegisterSubRegionType("subbackground", L["Background"], subSupports, subCreate, subModify,
                                  noop, noop, {}, nil, {}, false)
end

-- Foreground for aurabar

do
  local function subSupports(regionType)
    return regionType == "aurabar"
  end

  local function noop()
  end

  local function subSetFrameLevel(self, level)
    if self.parent.bar then
      self.parent.bar:SetFrameLevel(level)
    end
    if self.parent.iconFrame then
      self.parent.iconFrame:SetFrameLevel(level)
    end
  end

  local function subCreate()
    return { Update = noop, SetFrameLevel = subSetFrameLevel}
  end

  local function subModify(parent, region)
    region.parent = parent
  end

  KUIAR_Runtime.RegisterSubRegionType("subforeground", L["Foreground"], subSupports, subCreate, subModify,
                                  noop, noop, {}, nil, {}, false)
end

end)
