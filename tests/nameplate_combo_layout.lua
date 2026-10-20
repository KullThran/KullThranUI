local root=arg[1] or "."
local function read(p) local f=assert(io.open(root..p));local s=f:read("*a");f:close();return s end
local s=read("/KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua")
local opt=read("/KullThranUI_Nameplates/Modules/Nameplates/Nameplates_Options.lua")
local start=assert(s:find("ns._ComboGeom = ",1,true))
local last=assert(s:find("ns.ApplyClassPowerPipShape = ",start,true))
local style,shape="retail","circle"
local ns={NameplateStyle=function() return style end}
local env=setmetatable({ns=ns,CP_PIP_W=8,CP_PIP_H=3,GetClassPowerShape=function() return shape end},{__index=_G})
local chunk=assert(loadstring(s:sub(start,last-1)));setfenv(chunk,env);chunk()
local L=ns.ClassPowerPipLayout
-- Plates follow the Combo Point Shape cards: 16px circles, 18x7 pips, 6px apart at default gap.
local w,h,g,round,red=L(true,1,2);assert(w==16 and h==16 and g==6 and round and red)
shape="pip";w,h,g,round,red=L(true,1,2);assert(w==18 and h==7 and g==6 and not round and red)
w,h,g=L(true,1.5,2);assert(w==27 and h==10.5 and g==9)
-- Other resources and KUI Style keep their flat segments and own colours.
w,h,g,round,red=L(false,1,2);assert(math.abs(w-11.2)<1e-9 and h==3 and g==4 and not round and not red)
style="kui";w,h,g,round,red=L(true,1,2);assert(w==8 and h==3 and g==2 and not red)
shape="circle";w,h,g,round,red=L(true,1,2);assert(w==16 and round and not red)
-- The live preview draws through the same layout and shape helpers.
assert(opt:find("ns.ClassPowerPipLayout(isCombo, cpScale, cpGap)",1,true))
assert(opt:find("ns.ApplyClassPowerPipShape(pip, cpRound)",1,true))
print("nameplate_combo_layout: plate and preview share combo size, spacing, shape and colours")
