local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

-- One registry for every skinned Blizzard window: the options toggle and the
-- callback that skins it. The on/off check lives here, so skin files only
-- describe the window; a window that is off does nothing.
S.windowRegistry = S.windowRegistry or {}
local registeredKeys = {}

function S:IsWindowEnabled(key)
    local db = self.db
    return (db and db.enable and db[key] ~= false) and true or false
end

-- spec: { addon = "Blizzard_X" | nil, label = "Options text", name = "Callback"
-- | nil, apply = function() | nil }. Several windows may share a key (one
-- switch); the first label wins. Without apply it only adds the option.
function S:RegisterWindow(key, spec)
    if not registeredKeys[key] then
        registeredKeys[key] = true
        self.windowRegistry[#self.windowRegistry + 1] = { key = key, label = spec.label or key }
    end
    if not spec.apply then return end

    local function apply()
        if S:IsWindowEnabled(key) then return spec.apply() end
    end
    local name = spec.name or key
    if spec.addon then
        self:AddCallbackForAddon(spec.addon, name, apply)
    else
        self:AddCallback(name, apply)
    end
end
