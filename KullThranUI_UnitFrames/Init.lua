local _, ns = ...

ns.KT = _G.KT
ns.KT_NS = _G.KT_NS

-- oUF is embedded and loaded by the core addon (KullThranUI). When UnitFrames is split into
-- its own addon, its local namespace differs, so we bridge the reference here.
local coreNS = _G.KT_NS or _G.KullThranUI_NS
if coreNS and coreNS.oUF then
    ns.oUF = coreNS.oUF
end