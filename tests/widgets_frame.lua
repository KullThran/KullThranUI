local root=arg[1] or "."
local W,MS,KT,region=dofile(root.."/tests/widgets_stub.lua")(root)
local function tok(n)return MS.skins.kui.colors[n] end
local function same(c,t)return c and math.abs(c[1]-t[1])<1e-6 and math.abs(c[4]-(t[4] or 1))<1e-6 end

-- Frame buttons (Close, Reload, Reset): the "steam" button, the primary one
-- with the accent ring; the gradient only travels on hover or press.
local host=region("Frame")
local sec=W:PillButton(host,"Reload UI",{width=120})
assert(sec.w==120 and sec.h==40,"frame buttons are 40 high")
assert(sec._steamKT and not sec._pillBgKT.shown and math.abs(sec._faceKT.color[1]-0.078)<1e-6,"the steam face replaces the plain pill")
assert(sec._ringKT.corners[1].vertex[1]<0.2 and not sec.scripts.OnUpdate,"at rest the ring is dark and still")
for _=1,40 do sec.scripts.OnEnter(sec);sec.scripts.OnUpdate(sec,0.1) end
local peak=0
for _=1,80 do sec.scripts.OnUpdate(sec,0.05);local v=sec._ringKT.corners[2].vertex;peak=math.max(peak,v[1]-v[3]) end
assert(peak>0.15,"the travelling light is the accent colour, not white")
sec.scripts.OnEnter(sec)
assert(sec.scripts.OnUpdate,"hover animates the ring")
local pri=W:PillButton(host,"Close",{primary=true})
assert(pri._selected and pri._ringKT.corners[1].vertex[1]>0.5,"the primary button keeps an accent ring")
local always=W:PillButton(host,"Reload UI",{ringAlways=true})
assert(always._ringKT.corners[1].vertex[1]>0.25 and not always.scripts.OnUpdate,"an always-on ring shows at rest without animating")
local plain=W:PillButton(host,"X",{steam=false})
assert(same(plain._pillBgKT.color,tok("controlBg")),"steam=false keeps the plain pill")

-- Sidebar entries: warm band and 3px accent bar while active, nothing at rest.
local btn=region("Button")
W:NavChip(btn,{inset=14,right=14,chip={w=28,h=24}})
assert(not btn._activeBandKT.shown and not btn._activeBarKT.shown,"rest shows no band")
W:NavChipState(btn,"active",false,true)
assert(btn._activeBarKT.shown and btn._activeBarKT.w==3 and btn._activeBarKT.color[1]==0.8,"active bar is 3px of accent")
assert(btn._activeBandKT.shown and btn._chipKT.color[1]>tok("controlBg")[1],"active band shows and the chip warms")
W:NavChipState(btn,"rest",true,true)
assert(btn._activeBandKT.shown and not btn._activeBarKT.shown and math.abs(btn._activeBandKT.color[1]-tok("rowHover")[1])<0.05 and btn._activeBandKT.color[3]>=tok("rowHover")[3],"hover is a neutral band, a shade lighter")
assert(not btn._navGlowOutKT.shown and math.abs(btn._chipKT.color[1]-tok("controlBg")[1])<1e-6,"hover has no halo and leaves the chip cold")
assert(btn._navGlowInKT.shown and btn._navGlowInKT.color[1]==0.8 and btn._navGlowInKT.color[4]<0.2,"hover draws a faint accent hairline")
local cx=btn._chipKT.box.points[1][4]
W:NavChipState(btn,"active",false)
assert(btn._navActiveP<1 and btn.scripts.OnUpdate,"the active state eases in")
btn.scripts.OnUpdate(btn,0.1);btn.scripts.OnUpdate(btn,0.1)
assert(btn._navActiveP==1 and btn._navHoverP==0 and not btn.scripts.OnUpdate,"easing settles and stops")
assert(btn._chipKT.box.points[1][4]<cx,"the chip slides back when the cursor leaves")
local card=region("Button")
W:NavChip(card,{inset=12,right=14,card="full",chip={w=54,h=38}})
assert(card._activeBandKT.shown and same(card._activeBandKT.color,tok("card")),"card rows show their front at rest")
assert(card._navGlowInKT.shown and same(card._navGlowInKT.color,tok("cardBorder")),"card rows have a rounded border")
assert(card._navBackKT and same(card._navBackKT.color,tok("cardBack")),"full card rows have a back plate")
W:NavChipState(card,"rest",true,true)
assert(card._navBackKT.color[1]==0.8,"hover lights the back plate with the accent, like the cards")
local flat=region("Button")
W:NavChip(flat,{card="flat"})
assert(flat._navBackKT==nil and flat._activeBandKT.shown,"flat card rows have no back plate")
-- Gradient rows: every colour is an accent shade, brighter when selected.
local grow=region("Button")
local glabel=grow:CreateFontString()
W:NavChip(grow,{inset=12,right=14,radius=11,card="gradient",chip={w=54,h=38}})
grow._navLabelKT=glabel
W:NavChipState(grow,"rest",false,true)
local restTop=grow._gRingKT.pieces[2].vertex
assert(restTop and restTop[1]>restTop[3] and restTop[1]<0.5,"the resting ring is a muted accent shade")
assert(glabel.textColor[1]>0.8 and glabel.textColor[2]<glabel.textColor[1],"the label is a light accent tint")
assert(not grow._gHovL.shown and not grow._activeBandKT.shown,"no sheen at rest")
W:NavChipState(grow,"rest",true,true)
assert(grow._gHovL.shown,"hover fades in the sheen")
W:NavChipState(grow,"active",false,true)
local selTop=grow._gRingKT.pieces[2].vertex
assert(selTop[1]>restTop[1] and grow._activeBarKT.shown and glabel.textColor[2]>0.95,"selected: bright accent ring, accent bar, white label")
assert(grow._navFade>0.15 and grow._navFade<=0.25,"gradient rows fade smoothly but quickly")
assert(restTop[1]<0.3,"the resting ring stays quiet")
assert(type(grow._chipKT.color[1])=="number","the chip gets a plain colour")
-- Shine rows: black face over a spinning two-tone accent ring, a streak
-- that sweeps once on hover, a brighter ring when selected.
local srow=region("Button")
local slabel=srow:CreateFontString()
W:NavChip(srow,{inset=6,right=8,radius=11,card="shine",chip={w=54,h=38}})
srow._navLabelKT=slabel
local host=srow._shineHostKT
assert(host and host._ringKT and host._faceKT,"the shine row builds a ring and a face below the button")
assert(host._ringR==6 and host._faceKT.radius==4,"shine rows have squarer, softened corners")
host.w,host.h=270,46
host.scripts.OnSizeChanged(host,270,46)
W:NavChipState(srow,"rest",false,true)
local function ringPeak()local m=0;for _,c in ipairs(host._ringKT.corners) do m=math.max(m,c.vertex[1]) end;return m end
local restPeak=ringPeak()
assert(restPeak>0.2 and restPeak<0.8,"at rest the ring is a calm accent gradient")
assert(host._faceKT.color[1]<0.1 and not host._streakKT.shown,"black face, no streak at rest")
assert(math.abs(slabel.textColor[1]-slabel.textColor[3])<0.05 and not host._fillKT.shown,"at rest the label is neutral and there is no wash")
W:NavChipState(srow,"rest",true)
host._clipKT.w=266
for _=1,10 do srow.scripts.OnUpdate(srow,0.1) end
assert(srow._shineRot>0 and srow.scripts.OnUpdate,"the ring spins while hovered")
assert(srow._shineSweep==nil and not host._streakKT.shown,"no streak sweeps across the row")
W:NavChipState(srow,"rest",false)
for _=1,8 do if srow.scripts.OnUpdate then srow.scripts.OnUpdate(srow,0.1) end end
assert(not srow.scripts.OnUpdate,"leaving stops every animation")
assert(math.abs(ringPeak()-restPeak)<1e-6,"after a spin the resting ring looks the same as every other row")
W:NavChipState(srow,"active",false,true)
assert(ringPeak()>restPeak and srow._activeBarKT.shown,"selected: brighter ring and accent bar")
assert(slabel.textColor[1]>slabel.textColor[3]+0.1,"selected: the label lights with the accent")
assert(host._fillKT.shown and host._fillKT.pieces[1].vertex[4]>0.1 and host._fillKT.pieces[1].vertex[4]<0.25 and host._fillKT.pieces[3].vertex[4]==0,"selected: an accent wash fades from left to right")
assert(not srow._chipKT.shown,"no box behind the icon")
local flatIcon=srow:CreateTexture();srow._navIconKT=flatIcon
W:NavChipState(srow,"rest",false,true)
assert(flatIcon.vertex[1]==0.8 and not (srow._iconGlowKT and srow._iconGlowKT.shown),"flat accent icon, no glow at rest")
W:NavChipState(srow,"active",false,true)
assert(srow._iconGlowKT.shown and srow._iconGlowKT.vertex[1]==0.8 and srow._iconGlowKT.vertex[4]>0.2 and srow._iconGlowKT.vertex[4]<0.4,"selected: a soft accent glow behind the icon")
assert(srow._iconGlowKT.texture:find("PortalRadial",1,true),"the glow is a soft radial")
srow._navIconKT=nil
local pill=region("Button")
W:NavChip(pill,{always=true})
assert(pill._activeBandKT.shown,"an always-on pill shows at rest")

-- Segmented tabs: one track, the selected segment lit, clicks select.
local page=region("Frame");page.w=600
local picked
local tabs={{id="a",label="General"},{id="b",label="KUIMove"},{id="c",label="Profiles"}}
local bar,h=W:SegmentedTabs(page,tabs,"a",function(id)picked=id end,{width=600})
assert(h==34 and #bar._segmentsKT==3,"one row of three segments is 34 high")
local s1,s2=bar._segmentsKT[1],bar._segmentsKT[2]
assert(s1._bgKT.shown and not s2._bgKT.shown,"only the selected segment is lit")
assert(s2._textKT.textColor[1]==0.74,"other tabs are muted")
s2.scripts.OnClick(s2)
assert(picked=="b" and s2._bgKT.shown and not s1._bgKT.shown,"a click selects and reports the tab")
local many={}
for i=1,12 do many[i]={id="t"..i,label="Long tab name "..i} end
local wrapped,wh=W:SegmentedTabs(page,many,"t1",nil,{width=600})
assert(wh>34,"tabs wrap into rows when they do not fit")
local none=W:SegmentedTabs(page,many,"t1",nil,{width=600,single=true})
assert(none==nil,"single-row mode refuses tabs that need two rows")
print("widgets_frame: pill buttons, sidebar chips and segmented tabs passed")
-- Page tab bar ("steam" button): dark rounded face, 2px gradient ring that
-- only travels while hovered or pressed, soft halo, accent ring when selected.
local tbar=W:PageTabs(page,{{id="g",label="General"},{id="k",label="KUIMove"}},"g",function(id)picked=id end,{width=920})
local tg,tk=tbar._tabsKT[1],tbar._tabsKT[2]
assert(tg.h==40 and tg.w==455 and tk.points[1][4]==465,"40px tabs share the width with a 10px gap")
local six={{id="1",label="General"},{id="2",label="KUIMove"},{id="3",label="Disable Modules"},{id="4",label="Compatibility"},{id="5",label="Profiles"},{id="6",label="Fonts & Colors"}}
local sbar=W:PageTabs(page,six,"1",nil,{width=920})
assert(sbar,"the six General tabs fit the band")
local sumw=0;for _,t6 in ipairs(sbar._tabsKT) do sumw=sumw+t6.w end
assert(sumw+5*10==920 and sbar._tabsKT[3].w>sbar._tabsKT[2].w,"they fill the band, longer labels get wider tabs")
assert(math.abs(tk._faceKT.color[1]-0.078)<1e-6 and tk._faceKT.color[4]==1,"the face is #141414")
assert(tg._faceKT.color[1]>tk._faceKT.color[1] and tg._ringKT.corners[1].vertex[1]>0.5,"the selected tab has an accent ring and a warmed face")
assert(tk._ringKT.corners[2].vertex[1]<0.2 and not tk._haloInKT.shown,"at rest the ring is nearly black and there is no halo")
assert(not tk.scripts.OnUpdate,"nothing animates at rest")
tk.scripts.OnEnter(tk)
assert(tk.scripts.OnUpdate,"hover starts the animation")
for _=1,20 do tk.scripts.OnUpdate(tk,0.1) end
assert(tk._hoverP==1 and tk._phase>0,"the gradient travels while hovered")
local lit=false
for _=1,60 do tk.scripts.OnUpdate(tk,0.05); if tk._haloInKT.shown then lit=true end end
assert(lit,"the halo lights while the light passes")
tk.scripts.OnLeave(tk)
for _=1,5 do if tk.scripts.OnUpdate then tk.scripts.OnUpdate(tk,0.1) end end
assert(tk._hoverP==0 and not tk.scripts.OnUpdate and not tk._haloInKT.shown,"leaving fades it out and stops")
tk.scripts.OnMouseDown(tk)
assert(tk.scripts.OnUpdate,"pressing also animates")
tk.scripts.OnMouseUp(tk);tk.scripts.OnLeave(tk)
tk.scripts.OnClick(tk)
assert(picked=="k" and tk._selected and not tg._selected,"a click selects and reports the tab")
assert(W:PageTabs(page,many,"t1",nil,{width=300})==nil,"tabs that cannot fit even at a small font stay in the page")
print("widgets_frame: page tabs passed")
-- Module cards (category pages, gradient-border CSS in accent shades):
-- black-to-grey face, a 2px ring of accent shades that keeps travelling,
-- a soft accent halo; hover brightens ring and halo.
local clicked
local mc=W:ModuleCard(page,{width=296,height=200,icon="icon",title="General",description="Desc",onClick=function()clicked=true end})
assert(mc.w==296 and mc.h==200 and mc._ringKT and mc._faceKT.radius==8,"card with a ring round a rounded face")
assert(mc._faceKT.pieces[2].vertex[1]>mc._faceKT.pieces[8].vertex[1],"the face is lighter at the top, black at the bottom")
assert(mc._iconKT.vertex[1]==0.8 and mc._titleKT.text=="General" and mc._descKT.text=="Desc","accent icon, name and description")
local function corner() return mc._ringKT.corners[2].vertex[1] end
local c0=corner()
assert(c0>0 and mc.scripts.OnUpdate,"the ring is lit and always moving")
for _=1,30 do mc.scripts.OnUpdate(mc,0.1) end
assert(math.abs(corner()-c0)>1e-4,"the band travels along the ring")
local halo0=mc._haloInKT.color[4]
mc.scripts.OnEnter(mc)
for _=1,5 do mc.scripts.OnUpdate(mc,0.1) end
assert(mc._haloInKT.color[4]>halo0,"hover brightens the halo")
mc.scripts.OnLeave(mc)
for _=1,5 do mc.scripts.OnUpdate(mc,0.1) end
assert(math.abs(mc._haloInKT.color[4]-halo0)<1e-6,"and it settles back")
mc.scripts.OnClick(mc)
assert(clicked,"the card opens its module")
print("widgets_frame: module cards passed")

-- Category header (starfield CSS): accent radial glow, three star layers
-- drifting up at different speeds, texts fading up on open.
local hero=W:StarHero(page,{width=920,height=110,eyebrow="MODULE CATEGORY",title="General & Style",subtitle="Core"})
hero.w,hero.h=920,110
assert(#hero._starsKT>100 and hero._glowKT.texture:find("PortalRadial",1,true),"stars and a radial glow")
assert(hero._titleKT.text=="General & Style" and hero._textKT.alpha==0,"the texts start hidden for the intro")
local first,big
for _,s in ipairs(hero._starsKT) do if s.speed==9 and not first then first=s end; if s.speed==3 and not big then big=s end end
local y0,b0=first.tex.points[1][5],big.tex.points[1][5]
hero.scripts.OnUpdate(hero,0.6)
assert(hero._textKT.alpha>0 and hero._textKT.alpha<1,"the texts fade in")
hero.scripts.OnUpdate(hero,0.7)
assert(hero._textKT.alpha==1 and hero._textKT.points[1][5]==0,"after 1.2s the texts sit in place")
local function at(s)return -((s.y-hero._clock*s.speed)%110) end
assert(math.abs(first.tex.points[1][5]-at(first))<1e-6 and math.abs(big.tex.points[1][5]-at(big))<1e-6,"stars drift up and wrap round")
assert(first.speed>big.speed,"small stars drift faster than big ones")
print("widgets_frame: star hero passed")

-- Enhancements focus cards (spinning-border CSS): dark face, 4px ring of
-- wandering accent blobs, soft halo, ten points drifting down-right.
local picked2
local fc,fh=W:FocusCard(page,{width=198,title="Damage Meter",description="Combat rankings",icon="icon",active=false,onClick=function()picked2=true end})
assert(fc.w==198 and fh>=88 and fc._ringK==4 and fc._ringR==12,"198 wide, at least 88 high, 4px ring with 12px corners")
assert(#fc._pointsKT==4 and fc._iconKT.vertex[1]==0.8,"a few faint points and an accent icon by default")
local c0=fc._ringKT.corners[1].vertex[1]
local p1=fc._pointsKT[2]
fc.scripts.OnUpdate(fc,0.5)
local x1,y1=p1.tex.points[1][4],p1.tex.points[1][5]
fc.scripts.OnUpdate(fc,0.5)
assert(p1.tex.points[1][4]>x1 and p1.tex.points[1][5]<y1,"points drift down and to the right")
assert(math.abs(fc._ringKT.corners[1].vertex[1]-c0)>1e-4,"the ring colours wander")
local halo0=fc._haloInKT.color[4]
fc:SetActive(true)
assert(fc._haloInKT.color[4]>halo0,"the selected card glows brighter")
fc.scripts.OnClick(fc)
assert(picked2,"the card selects its view")
print("widgets_frame: focus cards passed")

-- Cut-corner button (Open Changelog): cut corners, drifting accent border,
-- dark face that draws back on hover over a deeply darkened gradient.
local clicked3
local cb=W:CutButton(page,"Open Changelog",{width=150,height=26,onClick=function()clicked3=true end})
assert(cb.w==150 and cb.h==26 and cb._borderKT.parts.tl.texture:find("cut_tri",1,true),"cut-corner shape")
assert(cb._textKT.text=="OPEN CHANGELOG","capital label")
local face0=cb._faceKT.parts.mid.w
local b0=cb._borderKT.parts.tl.vertex[1]
cb.scripts.OnUpdate(cb,1.3)
assert(math.abs(cb._borderKT.parts.tl.vertex[1]-b0)>1e-4,"the border band drifts")
cb.scripts.OnEnter(cb)
cb.scripts.OnUpdate(cb,0.1)
assert(cb._faceKT.parts.mid.w<face0,"hover draws the face back")
for _=1,5 do cb.scripts.OnUpdate(cb,0.1) end
assert(not cb._faceKT.parts.mid.shown,"the gradient fill is uncovered")
local f=cb._fillKT.parts.tl.vertex
assert(math.max(f[1],f[2],f[3])<0.4,"the uncovered fill stays deeply darkened")
assert(cb._textKT.textColor[1]==1 and cb._textKT.textColor[3]==1,"white label on hover")
cb.scripts.OnLeave(cb)
for _=1,8 do cb.scripts.OnUpdate(cb,0.1) end
assert(math.abs(cb._faceKT.parts.mid.w-face0)<1e-6,"the face comes back")
cb.scripts.OnClick(cb)
assert(clicked3,"it clicks")
print("widgets_frame: cut button passed")
