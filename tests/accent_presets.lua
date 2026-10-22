local root=arg[1] or "."
-- ThemeSelector.lua decides which accent preset card shows as selected.
local KT={STYLE_PRESETS={}}
local env=setmetatable({LibStub=function()return {GetAddon=function()return KT end} end},{__index=_G})
local fn=assert(loadfile(root.."/KullThranUI/Modules/VisualThemes/ThemeSelector.lua"))
setfenv(fn,env);fn("KullThranUI",{})
local active=assert(KT.IsAccentPresetActive,"ThemeSelector exposes KT.IsAccentPresetActive")

assert(active({stylePreset="frost_blue",borderTheme="KULLTHRAN"},"frost_blue"),"the chosen preset is lit")
assert(not active({stylePreset="frost_blue",borderTheme="KULLTHRAN"},"kui_crimson"),"other presets are not")
assert(active({borderTheme="KULLTHRAN"},"kui_crimson"),"no preset saved -> kui_crimson")
assert(not active({stylePreset="frost_blue",borderTheme="CLASS",kullthranUIColorByClass=true},"frost_blue"),"class colour lights no preset")
assert(not active({stylePreset="frost_blue",kullthranUIColorByClass=true},"frost_blue"),"class colour flag alone lights no preset")
assert(not active({stylePreset="frost_blue",borderTheme="CUSTOM"},"frost_blue"),"custom accent lights no preset")
assert(not active({stylePreset="custom",borderTheme="KULLTHRAN"},"kui_crimson"),"manual palette lights no preset")
assert(not active(nil,"kui_crimson"),"no skin -> nothing lit")

local f=assert(io.open(root.."/KullThranUI/Options.lua"));local src=f:read("*a");f:close()
assert(src:find("return KT.IsAccentPresetActive(KT.db.profile.skin, presetKey)",1,true),"the options grid uses the shared rule")
print("accent_presets: preset highlight follows class/custom accent passed")
