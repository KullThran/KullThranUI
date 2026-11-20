local addonName, ns = ...
ns.KT = _G.KT
ns.KT_NS = _G.KT_NS

if not ns.KT then return end

-- Register module
local Mod = ns.KT:NewModule("ObjectiveTracker", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
ns.Mod = Mod
