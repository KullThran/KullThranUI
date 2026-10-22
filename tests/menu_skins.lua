local root=arg[1] or "."
local chunk=assert(loadfile(root.."/KullThranUI/MenuSkins.lua"))
local KT={C_R=0.1,C_G=0.1,C_B=0.1}
function KT:GetStylePalette()return {accent={r=0.8,g=0.2,b=0.4}}end
chunk("KullThranUI",{KT=KT})
local MS=assert(KT.MenuSkins,"MenuSkins registers on KT")

assert(MS:GetActive()=="kui","no VisualThemes -> kui")
KT.VisualThemes={GetRenderedTheme=function()return "forever" end}
assert(MS:GetActive()=="forever")
KT.VisualThemes.GetRenderedTheme=function()return "bogus" end
assert(MS:GetActive()=="kui","unknown id -> kui")
for _,id in ipairs({"kui","retail","forever","classic"})do assert(MS.skins[id],"skin "..id) end

KT.VisualThemes.GetRenderedTheme=function()return "kui" end
assert(select(1,MS:Accent())==0.8,"kui follows the user accent")
assert(select(1,MS:LightColor())==0.8,"kui light follows the accent")
KT.VisualThemes.GetRenderedTheme=function()return "forever" end
assert(select(1,MS:Accent())~=0.8,"forever has a fixed accent")
assert(select(1,MS:LightColor())~=0.8,"forever has a fixed light")

MS.skins.forever.colors.rowHover=nil
local r,g,b,a=MS:Color("rowHover")
assert(r and a,"missing token falls back to kui")
assert(MS:Token("logo")=="art","root tokens resolve")

MS.skins.kui.files={base="kui_base",light="kui_light"}
assert(MS:Files("classic").base==MS.TEXTURE_PATH.."kui_base","skin without art uses kui")
assert(MS:Files("classic").glow==nil)
MS.skins.kui.files=nil
assert(MS:Files("classic")==nil,"no art anywhere -> nil")

local seen
MS:RegisterRepaint(function()error("boom")end)
MS:RegisterRepaint(function(id)seen=id end)
MS:Repaint()
assert(seen=="forever","one failing listener does not stop the others")
print("menu_skins: registry, tokens, accent, files fallback and repaint passed")
