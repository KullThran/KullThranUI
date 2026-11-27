-- Internal loading for the embedded ForeverAuras engine. No separate addons are installed or required.
local hostName, ns = ...
local E = { modules = {}, version = "1.3.8", hostName = hostName }
ns.EmbeddedAuraEngine = E
local realAddOns, realCreateFrame = C_AddOns, CreateFrame
local coreName = "KUIAR_Engine"

-- The engine keeps its libraries in its own registry, not in the global LibStub:
-- another addon's copy of a library can neither replace nor break them.
-- Only the libraries made to be shared between addons go through the global one:
-- shared media, and the optional Masque, CustomNames and AceConsole.
local sharedLibraries = {
    ["LibSharedMedia-3.0"] = true, ["Masque"] = true, ["CustomNames"] = true, ["AceConsole-3.0"] = true,
}
local Stub = { libs = {}, minors = {}, minor = 2 }
E.LibStub = Stub
local function GlobalStub()
    local global = rawget(_G, "LibStub")
    if type(global) == "table" and global ~= Stub then return global end
end
function Stub:NewLibrary(major, minor)
    assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
    minor = assert(tonumber(string.match(tostring(minor), "%d+")), "Minor version must either be a number or contain a number.")
    local global = sharedLibraries[major] and GlobalStub()
    if global then return global:NewLibrary(major, minor) end
    local oldminor = self.minors[major]
    if oldminor and oldminor >= minor then return nil end
    self.minors[major], self.libs[major] = minor, self.libs[major] or {}
    return self.libs[major], oldminor
end
function Stub:GetLibrary(major, silent)
    local lib = self.libs[major]
    if lib then return lib, self.minors[major] end
    local global = sharedLibraries[major] and GlobalStub()
    if global then
        local shared, sharedMinor = global:GetLibrary(major, true)
        if shared then return shared, sharedMinor end
    end
    if not silent then error(("Cannot find a library instance of %q."):format(tostring(major)), 2) end
end
function Stub:IterateLibraries() return pairs(self.libs) end
setmetatable(Stub, { __call = Stub.GetLibrary })

-- Native APIs that return mixin-backed objects inspect the caller's fenv
-- directly. A metatable fallback to _G does not make these types visible.
-- Keep the actual client tables, rather than copies or substitute mixins.
local function RefreshNativeMixins(environment)
    for key, value in pairs(_G) do
        if type(key) == "string" and key:sub(-5) == "Mixin" and type(value) == "table" then
            rawset(environment, key, value)
        end
    end
end

-- Blizzard load-on-demand UI modules can introduce native mixins later.
-- Register before engine frames so their ADDON_LOADED handlers see the types.
local nativeTypesWatcher = realCreateFrame("Frame")
nativeTypesWatcher:RegisterEvent("ADDON_LOADED")
nativeTypesWatcher:SetScript("OnEvent", function()
    for _, module in pairs(E.modules) do RefreshNativeMixins(module.env) end
end)

local function Report(err)
    if geterrorhandler then geterrorhandler()(err) end
end

function E.Define(name, metadata, deferred)
    local module = { name = name, metadata = metadata, deferred = deferred, queue = {}, frames = {}, handlers = {}, ns = {} }
    E.modules[name] = module
    local api = setmetatable({}, { __index = realAddOns })
    function api.GetAddOnMetadata(addon, field)
        local target = E.modules[addon]
        if target then return target.metadata[field] end
        return realAddOns.GetAddOnMetadata(addon, field)
    end
    function api.IsAddOnLoaded(addon)
        local target = E.modules[addon]
        if target then return target.loaded == true, target.loaded == true end
        return realAddOns.IsAddOnLoaded(addon)
    end
    function api.LoadAddOn(addon)
        if E.modules[addon] then return E.Load(addon) end
        return realAddOns.LoadAddOn(addon)
    end
    function api.EnableAddOn(addon, ...)
        -- Companion integrations are not installed by this embedded engine.
        if E.modules[addon] or addon == coreName .. "Companion" then return end
        return realAddOns.EnableAddOn(addon, ...)
    end
    function api.GetAddOnEnableState(addon, ...)
        if E.modules[addon] then return 2 end
        return realAddOns.GetAddOnEnableState(addon, ...)
    end
    function api.GetAddOnInfo(addon)
        local target = E.modules[addon]
        if target then
            return { name = addon, title = target.metadata.Title, notes = target.metadata.Notes,
                loadable = true, reason = nil, security = "INSECURE" }
        end
        return realAddOns.GetAddOnInfo(addon)
    end
    local function ModuleCreateFrame(...)
        local frame = realCreateFrame(...)
        local setScript = frame.SetScript
        local tracked = false
        frame.SetScript = function(self, script, handler)
            if script == "OnEvent" then
                if not tracked and handler then module.frames[#module.frames + 1] = self; tracked = true end
                module.handlers[self] = handler
                if handler then
                    return setScript(self, script, function(f, event, ...)
                        if event == "ADDON_LOADED" and ... == hostName then
                            return handler(f, event, name, select(2, ...))
                        end
                        return handler(f, event, ...)
                    end)
                end
            end
            return setScript(self, script, handler)
        end
        return frame
    end
    local profiler
    if C_AddOnProfiler then
        profiler = setmetatable({}, { __index = C_AddOnProfiler })
        if C_AddOnProfiler.GetAddOnMetric then
            profiler.GetAddOnMetric = function(addon, ...)
                return C_AddOnProfiler.GetAddOnMetric(E.modules[addon] and hostName or addon, ...)
            end
        end
    end
    module.env = setmetatable({ C_AddOns = api, CreateFrame = ModuleCreateFrame, LibStub = Stub,
        C_AddOnProfiler = profiler, AddonCompartmentFrame = false,
        GetAddOnMemoryUsage = GetAddOnMemoryUsage and function(addon)
            return GetAddOnMemoryUsage(E.modules[addon] and hostName or addon)
        end,
    }, {
        __index = _G, __newindex = _G,
    })
    RefreshNativeMixins(module.env)
    module.loaded = not deferred
end

function E.Register(name, chunk)
    local module = assert(E.modules[name], "Unknown embedded aura module: " .. name)
    setfenv(chunk, module.env)
    if module.deferred then
        module.queue[#module.queue + 1] = chunk
    else
        chunk(name, module.ns)
    end
end

function E.Load(name)
    local module = E.modules[name]
    if not module then return nil, "MISSING" end
    if module.failed then return nil, "CORRUPT" end
    if module.loaded then return true end
    if module.loading then return nil, "DEMAND_LOADED" end
    if InCombatLockdown and InCombatLockdown() then return nil, "IN_COMBAT" end
    module.loading = true
    local ok, err = xpcall(function()
        -- Dependencies are internal modules, not C_AddOns dependencies.
        for dependency in (module.metadata.Dependencies or ""):gmatch("[^,%s]+") do
            if E.modules[dependency] then
                local ready, reason = E.Load(dependency)
                if not ready then error(dependency .. ": " .. tostring(reason)) end
            end
        end
        RefreshNativeMixins(module.env)
        for _, chunk in ipairs(module.queue) do chunk(name, module.ns) end
        module.loaded = true
        -- Options and archive modules keep their original initialization event.
        -- Snapshot before dispatch: handlers can unregister themselves or create frames.
        local handlers = {}
        for _, frame in ipairs(module.frames) do
            local handler = module.handlers[frame]
            if handler and frame:IsEventRegistered("ADDON_LOADED") then handlers[#handlers + 1] = { frame, handler } end
        end
        for _, entry in ipairs(handlers) do entry[2](entry[1], "ADDON_LOADED", name) end
    end, function(message) return tostring(message) end)
    module.loading = nil
    if not ok then
        module.loaded, module.failed = false, err
        Report(err)
        return nil, "CORRUPT"
    end
    module.queue = nil
    return true
end

function E.API() return _G.KUIAR_Runtime end
function E.Core() return E.modules[coreName].ns end
function E.Options() return E.modules[coreName .. "Options"].ns end
