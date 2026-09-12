local _, ns = ...
ns.KT = _G.KT
ns.KT_NS = _G.KT_NS

-- Stub file to avoid empty-file warnings while the active implementation
-- lives inside the main KullThranUI addon.
if _G.KT and _G.KT.GetModule and _G.KT:GetModule("Enhancements", true) then
    return
end
