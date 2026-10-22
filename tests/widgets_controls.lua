local root=arg[1] or "."
local W,MS,KT,region,env=dofile(root.."/tests/widgets_stub.lua")(root)
local function tok(n)return MS.skins.kui.colors[n] end
local page=region("Frame");page.w=440

-- Toggle: rounded track and round knob; off = controlOff, on = accent.
local val=false
local t=W:Toggle(page,"X",0,function()return val end,function(v)val=v end)
assert(t._trackKT and t._knobKT,"toggle exposes track and knob")
assert(t._trackKT.w==34 and t._trackKT.h==18 and t._trackKT.radius==9,"34x18 pill track")
assert(t._knobKT.w==14 and t._knobKT.radius==7,"14px round knob")
assert(t._trackKT.color[1]==tok("controlOff")[1],"off track uses controlOff")
t.scripts.OnClick(t)
assert(val and t._trackKT.color[1]==0.8,"on track uses the accent")

-- Long translated labels are clipped, never wrapped over the control.
local long=string.rep("Überlange Beschriftung ",6)
local t2=W:Toggle(page,long,0,function()return false end,function()end)
assert(t2._label.w<=t2.w-68 and t2._label.wrap==false,"toggle label is one clipped line")

-- Dropdown: label left, rounded 210px box right, one clipped line each.
local d,hd=W:Dropdown(page,long,0,{a="A"},function()return "a" end,function()end)
assert(hd==50,"dropdown height unchanged")
assert(d._boxKT and d._boxKT.w==210,"dropdown box is 210 wide")
assert(d._boxRoundKT and d._boxRoundKT.color[1]==tok("controlBg")[1],"dropdown box is a rounded controlBg shape")
assert(d._labelKT.wrap==false and d._labelKT.w<=page.w-20-260+1,"dropdown label is clipped beside the box")
d:SetReservedRightSpace(40)
assert(d._labelKT.w<=page.w-20-40-260+1,"reserved space keeps the label clear of the box")

-- Slider: rounded track and fill, round thumb, value box that clamps.
local lastSet
local s,hs=W:Slider(page,"S",0,function()return 5 end,function(v)lastSet=v end,0,10,1)
assert(hs==54,"slider height unchanged")
assert(s._trackKT.color[1]==tok("controlTrack")[1] and s._trackKT.radius==2,"rounded skin track")
assert(s._fillKT and s._fillKT.color[1]==0.8,"slider fill uses the accent")
assert(s._thumbKT and s._thumbKT.texture:find("round_disc",1,true),"round thumb")
assert(s._valueBoxKT,"slider exposes its value box")
s._valueBoxKT:SetText("99")
s._valueBoxKT.scripts.OnEnterPressed(s._valueBoxKT)
assert(lastSet==10,"typed value is clamped to the maximum")

-- Colour swatch: 22px rounded swatch tinted with the value.
local c,hc=W:ColorSwatch(page,"C",0,function()return 1,0,0,1 end,function()end)
assert(hc==38,"swatch height unchanged")
assert(c._swatchKT and c._swatchKT.w==22,"22px swatch")
assert(c._swatchRoundKT and c._swatchRoundKT.color[1]==1,"swatch is a rounded shape in the chosen colour")

-- Input: rounded controlBg box.
local i,hi=W:Input(page,"I",0,function()return "x" end,function()end)
assert(hi==52,"input height unchanged")
assert(i._boxKT and i._boxRoundKT,"input box is rounded")

-- Narrow rows: the box shrinks and the label keeps a positive width.
local narrow=region("Frame");narrow.w=180
local dn=W:Dropdown(narrow,"Long label",0,{a="A"},function()return "a" end,function()end)
assert(dn._boxKT.w<=math.floor((180-20)*0.55) and dn._labelKT.w>=40,"narrow dropdown keeps both parts usable")
print("widgets_controls: rounded toggle, dropdown, slider, swatch, input and narrow rows passed")

-- Mode + colour row: an Accent/Custom pill switch and a swatch on one line.
local mode,picked="accent",nil
local m,hm=W:ModeColorRow(page,"Bags",0,
    function()return mode end,function(v)mode=v end,
    function()return 0.2,0.4,0.6,1 end,function(r,g,b)picked={r,g,b} end)
assert(hm==38,"mode colour row is one 38px row")
assert(m._modeAccentKT and m._modeCustomKT and m._swatchKT,"row has both pill options and a swatch")
assert(m._modeAccentKT._selected and not m._modeCustomKT._selected,"accent option shows as selected")
assert(m._swatchKT._dimmed,"swatch is dimmed while following the accent")
m._modeCustomKT.scripts.OnClick(m._modeCustomKT)
assert(mode=="custom" and m._modeCustomKT._selected and not m._swatchKT._dimmed,"choosing custom selects it and wakes the swatch")
print("widgets_controls: mode colour row passed")
