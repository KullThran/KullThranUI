-- CDM native hosting: when Blizzard re-acquires a viewer item frame, KUI blanks it (alpha 0)
-- until the claim pass restores it. The restore goes through SyncNativeCDMBarAlpha, which
-- skips the work when the container alpha did not change. If the frame was already claimed
-- and the composition is unchanged (pool churn at combat start), nothing else restores it
-- and the row stays invisible for seconds, until a periodic Layout invalidates the cache.
-- The acquire hook must therefore invalidate that cache.
local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_CooldownManager/Modules/KUICooldownManager/KUICooldownManager.lua"))
local source = f:read("*a"); f:close()

local function slice(from, to)
    local a = assert(source:find(from, 1, true), "missing: " .. from)
    local b = assert(source:find(to, a, true), "missing: " .. to)
    return source:sub(a, b - 1)
end

local alphaIcon = { alpha = 1 }
function alphaIcon:SetAlpha(v) self.alpha = v end
local container = { shown = true, alpha = 1 }
function container:IsShown() return self.shown end
function container:GetAlpha() return self.alpha end

local acquireHook
local env = setmetatable({
    ns = {
        _nativeCDMFrameData = { [alphaIcon] = {} },
        NativeCDMHostingEnabled = function() return true end,
        NativeCDMViewerChanged = function() end,
        WakeTrackedBuffBars = function() end,
    },
    cdmBarFrames = { buffs = container },
    cdmBarIcons = { buffs = { alphaIcon } },
    GetHostedBarKeyForViewer = function() return "buffs" end,
    hooksecurefunc = function(_, method, fn) if method == "OnAcquireItemFrame" then acquireHook = fn end end,
    ipairs = ipairs,
}, { __index = _G })

local function run(code)
    local fn = assert(loadstring(code)); setfenv(fn, env); fn()
end

-- Real SyncNativeCDMBarAlpha (with its cache).
run(slice("function ns.SyncNativeCDMBarAlpha(barKey)", "\nfunction ns.SetCDMIconLayoutPoint"))
-- Real acquire hook, installed on a fake buff viewer.
env.viewer = { OnAcquireItemFrame = function() end }
env.hookState = { acquire = {} }
env.isTrackedBarViewer = false
env.sourceViewerName = "BuffIconCooldownViewer"
run(slice('if viewer.OnAcquireItemFrame and not hookState.acquire[viewer] then', 'if viewer.Layout and not hookState.layout[viewer] then'))
assert(acquireHook, "acquire hook installed")

-- Steady state: row claimed and visible, cache primed.
env.ns.SyncNativeCDMBarAlpha("buffs")
assert(alphaIcon.alpha == 1 and container._kuiNativeAlpha == 1)

-- Blizzard re-acquires the already-claimed frame (pool churn): KUI blanks it ...
acquireHook(nil, alphaIcon)
assert(alphaIcon.alpha == 0, "acquire blanks the frame until it is claimed")

-- ... and the claim pass (composition unchanged, container alpha unchanged) must bring it back.
env.ns.SyncNativeCDMBarAlpha("buffs")
assert(alphaIcon.alpha == 1, "claim pass restores the blanked icon even when the container alpha is unchanged")

-- The cache still avoids needless work in steady state.
local writes = 0
function alphaIcon:SetAlpha(v) writes = writes + 1; self.alpha = v end
env.ns.SyncNativeCDMBarAlpha("buffs")
env.ns.SyncNativeCDMBarAlpha("buffs")
assert(writes == 0, "no SetAlpha churn when nothing was blanked")

print("cdm_acquire_alpha_restore: ok")
