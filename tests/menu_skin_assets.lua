local root=arg[1] or "."
local KT={}
assert(loadfile(root.."/KullThranUI/MenuSkins.lua"))("KullThranUI",{KT=KT})
local MS=KT.MenuSkins
local dir=root.."/KullThranUI/Libraries/KUITextures/MenuSkins/"
local checked=0
for id,skin in pairs(MS.skins) do
    for layer,name in pairs(skin.files or {}) do
        local f=io.open(dir..name..".tga","rb")
        assert(f,id.."."..layer..": "..name..".tga exists")
        local b=f:read(18);f:close()
        assert(b and #b==18,name.." has a TGA header")
        local w=b:byte(13)+b:byte(14)*256
        local h=b:byte(15)+b:byte(16)*256
        assert(w==1440 and h==1060,name.." is 1440x1060 (got "..w.."x"..h..")")
        assert(b:byte(17)==32,name.." is 32-bit")
        assert(b:byte(3)==2,name.." is uncompressed truecolor")
        checked=checked+1
    end
end
assert(MS.skins.kui.files and MS.skins.kui.files.base and MS.skins.kui.files.light,"kui ships base and light")
for name,size in pairs({card_cut_edge=16,round_disc=64,card_icons=512}) do
    local f=assert(io.open(dir..name..".tga","rb"),name..".tga exists")
    local b=f:read(18);f:close()
    assert(b:byte(13)+b:byte(14)*256==size and b:byte(15)+b:byte(16)*256==size and b:byte(17)==32,name.." is a "..size.."px 32-bit TGA")
end
print("menu_skin_assets: "..checked.." skin textures are 1440x1060 32-bit TGA")
