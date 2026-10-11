local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_Armory/Modules/Armory/Armory.lua"))
local source = f:read("*a")
f:close()
local start = assert(source:find("function AR:OnInitialize()", 1, true))
local stop = assert(source:find("    if not KT.db.profile.armory then", start, true))
local initialization = source:sub(start, stop - 1) .. "end"
local panel = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUISettingsSurface.png"
local registered = {}
local env = setmetatable({
    AR = {}, PANEL_BG = panel,
    EnsurePaperDollStatTooltipLocales = function() end,
    LibStub = function()
        return {Register = function(_, kind, key, path)
            assert(kind == "background")
            assert(path == panel, "attempted registration of unavailable legacy texture: " .. path)
            registered[key] = path
        end}
    end,
}, {__index = _G})
local chunk = assert(loadstring(initialization))
setfenv(chunk, env)
chunk()
env.AR:OnInitialize()
assert(registered["KullThran Armory"] == panel)
assert(not registered["Blizzard Quest Log"])
env.LibStub = function() return nil end
env.AR:OnInitialize()
local asset = assert(io.open(root .. "/KullThranUI/Libraries/KUITextures/KUISettingsSurface.png", "rb"))
asset:close()
print("PASS: Armory registers its packaged background, avoids missing legacy media, and initializes without LSM")
