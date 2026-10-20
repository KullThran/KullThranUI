local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path)); local s = f:read("*a"); f:close(); return s
end
local source = read("KullThranUI/Modules/Enhancements/Enhancements_DamageMeter.lua")
local start = assert(source:find("local function GetDamageMeterBarTexture(cfg)", 1, true))
local stop = assert(source:find("local DAMAGE_METER_MEDIA", start, true))
local default = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
local custom = "Interface\\AddOns\\ExampleMedia\\MyBar.tga"
local media = { Fetch = function(_, kind, key, noDefault)
    assert(kind == "statusbar" and noDefault == true)
    if key == "Custom Media" then return custom end
    if key == "Empty" then return "" end
end }
local Mod = {}
local env = setmetatable({ Mod = Mod, BAR_TEXTURE = default,
    DAMAGE_METER_TEXTURE_PATHS = { [default] = true },
    LibStub = function(name, silent) assert(name == "LibSharedMedia-3.0" and silent); return media end,
}, { __index = _G })
local chunk = assert(loadstring(source:sub(start, stop - 1))); setfenv(chunk, env); chunk()
local resolve = Mod.ResolveDamageMeterBarTexture
assert(resolve(nil) == default and resolve({}) == default)
for _, value in ipairs({"", "Missing", "Empty", 42, false}) do
    assert(resolve({barTexture = value}) == default)
end
assert(resolve({barTexture = default}) == default)
assert(resolve({barTexture = custom}) == custom, "selector stores SharedMedia paths, not just fixed whitelist")
assert(resolve({barTexture = "Custom Media"}) == custom)
media = nil
assert(resolve({barTexture = "Custom Media"}) == default)
assert(resolve({barTexture = custom}) == custom, "saved path remains valid without SharedMedia")
-- Execute the real theme seeds: all native themes already share Blizzard.
local adapter
local KT = {VisualThemes = {RegisterModule = function(_, id, value) assert(id == "damagemeter"); adapter = value end}}
local adapterEnv = setmetatable({LibStub = function() return {GetAddon = function() return KT end} end}, {__index = _G})
chunk = assert(loadstring(read("KullThranUI/Modules/VisualThemes/Adapters/DamageMeter.lua")))
setfenv(chunk, adapterEnv); chunk()
for _, theme in ipairs({"classic", "retail", "forever", "kui"}) do
    local profile = {}; adapter.seed(profile, theme)
    local expected = theme == "kui" and default
        or theme == "classic" and "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\damagemeter\\BantoBar.tga"
        or "Interface\\TargetingFrame\\UI-StatusBar"
    assert(resolve(profile) == expected)
end
assert(source:find("row.bar:SetStatusBarTexture(barTexture)", 1, true))
local options = read("KullThranUI/Modules/Enhancements/Enhancements_Options.lua")
assert(options:find("Mod.ResolveDamageMeterBarTexture(cfg)", 1, true), "preview uses the live resolver")
print("PASS: Damage Meter fixed paths, external SharedMedia selections, invalid fallback and all four theme seeds")
