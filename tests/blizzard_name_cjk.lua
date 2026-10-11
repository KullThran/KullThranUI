local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI/Modules/VisualThemes/ThemeClientAssets.lua")); local src=f:read("*a"); f:close()
local a=assert(src:find("-- GameFontNormalSmall is a font FAMILY",1,true))
local b=assert(src:find("local function ResolveStockScale",a,true))
local families={}
local KT={VisualThemes={},db={profile={unitFrames={}}}}
function KT:DetectCJKScript(t)
 if type(t)~="string" or t=="" then return nil end
 if t:find("\227\129[\129-\191]") or t:find("\227\130[\128-\191]") then return "kana" end
 if t:find("\234[\176-\191]") or t:find("\237[\128-\158]") then return "hangul" end
 if t:find("[\228-\233][\128-\191][\128-\191]") then return "han" end
end
function KT:IsCJKCapableFont(p) return p:find("2002",1,true)~=nil end
function KT:GetCJKFontForScript() return "Fonts\\2002.TTF" end
local env=setmetatable({KT=KT,
 GameFontNormalSmall={GetFont=function() return "Fonts\\FRIZQT__.TTF",10,"" end},
 CreateFontFamily=function(name,members) local o={name=name,members=members}; families[#families+1]=o; return o end,
 hooksecurefunc=function(obj,m,hook) local orig=obj[m]; obj[m]=function(self,...) orig(self,...); hook(self,...) end end},{__index=_G})
env._G=env
local chunk=assert(loadstring(src:sub(a,b-1))); setfenv(chunk,env); chunk()
local fs={text="Arthas"}
function fs:SetFont(p,s,fl) self.path,self.size,self.flags,self.fontObject=p,s,fl,nil end
function fs:GetFont() return self.path,self.size,self.flags end
function fs:SetFontObject(o) self.fontObject=o end
function fs:SetTextColor(r,g,bb) self.color={r,g,bb} end
function fs:SetText(t) self.text=t end
function fs:GetText() return self.text end
function fs:GetStringWidth() return 50 end
KT.VisualThemes:ApplyBlizzardNameText(fs,1)
local fam=assert(fs.fontObject,"the name uses a font family")
local byAlpha={}; for _,m in ipairs(fam.members) do byAlpha[m.alphabet]=m.file end
assert(byAlpha.roman=="Fonts\\FRIZQT__.TTF" and byAlpha.korean=="Fonts\\2002.TTF" and byAlpha.simplifiedchinese and byAlpha.traditionalchinese)
assert(fs.color[1]==1 and fs.color[2]==0.82)
fs:SetText("\234\180\128\236\152\129") -- hangul
fs:SetFont("Fonts\\FRIZQT__.TTF",8,"")   -- width fit shrinks with the roman path
assert(fs.fontObject and fs.fontObject.members[1].height==8,"the width fit keeps the CJK family")
fs:SetText("\227\129\130\227\129\132")   -- kana
assert(fs.path=="Fonts\\2002.TTF" and not fs.fontObject,"kana names use the 2002 face")
fs:SetText("Thrall")
assert(fs.fontObject and fs.path=="Fonts\\FRIZQT__.TTF","Latin names go back to the family")
env.CreateFontFamily=nil
local fs2=setmetatable({text="\228\184\173\230\150\135"},{__index=fs}); fs2._ktBlizzNameHooked=true
KT.VisualThemes:ApplyBlizzardNameText(fs2,1)
assert(fs2.path=="Fonts\\2002.TTF","without font families a readable CJK name still gets a CJK face")
print("blizzard_name_cjk ok")
