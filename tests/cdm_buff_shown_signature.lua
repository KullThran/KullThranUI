-- CDM buffs row: a buff icon can become shown without any pool change (Blizzard already has the
-- frame acquired). The mirror only includes buff frames that are live at snapshot time, and the
-- pool signature ignores shown state, so such a buff stayed invisible until combat churned the
-- pool. A buffs pass must compare the shown set and refresh the mirror when it changed.
local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_CooldownManager/Modules/KUICooldownManager/KUICooldownManager.lua"))
local source = f:read("*a"); f:close()

local a = assert(source:find("function ns.GetBuffViewerShownSignature()", 1, true), "shown-set signature exists")
local b = assert(source:find("\nfunction ", a + 10, true))
local chunk = source:sub(a, b - 1)

local function Child(cdID, shown)
    local c = { cooldownID = cdID, shown = shown }
    function c:IsShown() return self.shown end
    return c
end
local pool = { active = {} }
function pool:EnumerateActive()
    local i = 0
    return function() i = i + 1; return self.active[i] end
end
local env = setmetatable({ ns = {}, _G = nil, pcall = pcall, tostring = tostring, table = table, ipairs = ipairs,
    BuffIconCooldownViewerPool = pool }, { __index = _G })
env._G = env
env.BuffIconCooldownViewer = { itemFramePool = pool }
setfenv(assert(loadstring(chunk, "sig")), env)()
local sig = env.ns.GetBuffViewerShownSignature

-- Two buffs live, a third frame already acquired but hidden (inactive buff).
local c1, c2, c3 = Child(101, true), Child(102, true), Child(103, false)
pool.active = { c1, c2, c3 }
local before = sig()
assert(before == sig(), "stable while nothing changes")

-- The hidden frame becomes active WITHOUT any pool change: the signature must change.
c3.shown = true
assert(sig() ~= before, "a pooled frame turning shown changes the signature")

-- Order of enumeration must not matter.
local shownAll = sig()
pool.active = { c3, c1, c2 }
assert(sig() == shownAll, "enumeration order does not change the signature")

-- A buff ending changes it again; a missing viewer is harmless.
c2.shown = false
assert(sig() ~= shownAll)
env.BuffIconCooldownViewer = nil
assert(sig() == "", "no viewer -> empty signature")

-- Wiring: the buffs pass compares it before trusting the mirror, and re-baselines after a rebuild.
local pass = source:match("local shouldRefreshViewerSnapshot = .-if shouldRefreshViewerSnapshot then")
assert(pass, "found the snapshot decision")
assert(pass:find("dirtyBars.buffs", 1, true) and pass:find("GetBuffViewerShownSignature", 1, true)
    and pass:find("buffShownSignature", 1, true), "buffs pass compares the shown set")
assert(source:find("CDMRT.buffShownSignature = ns.GetBuffViewerShownSignature", 1, true), "baseline refreshed after a snapshot rebuild")

print("cdm_buff_shown_signature: ok")
