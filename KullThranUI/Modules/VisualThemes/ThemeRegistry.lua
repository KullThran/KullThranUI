local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local Registry = {}
local Order = {}

function KT.VisualThemes:RegisterModule(moduleKey, adapter)
    if type(moduleKey) ~= "string" or moduleKey == "" or type(adapter) ~= "table" then
        return
    end
    if not Registry[moduleKey] then
        Order[#Order + 1] = moduleKey
    end
    Registry[moduleKey] = adapter
end

function KT.VisualThemes:GetModuleAdapter(moduleKey)
    return Registry[moduleKey]
end

function KT.VisualThemes:GetAllAdapters()
    return Registry, Order
end
