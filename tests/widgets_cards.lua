local root=arg[1] or "."
local W,MS,KT,region=dofile(root.."/tests/widgets_stub.lua")(root)
local function tok(n)return MS.skins.kui.colors[n] end
local function same(c,t)return c and math.abs(c[1]-t[1])<1e-6 and math.abs(c[4]-(t[4] or 1))<1e-6 end

-- Rounded rectangles: nine slices of one disc texture, recoloured together.
local host=region("Frame")
local rr=W:RoundRect(host,"ARTWORK")
assert(#rr.pieces==9,"a rounded rect is nine slices")
assert(rr.pieces[1].texture:find("round_disc",1,true),"slices come from the disc texture")
rr:SetRadius(8);rr:SetColor(0.2,0.3,0.4,0.5)
assert(rr.pieces[5].vertex[1]==0.2 and rr.pieces[9].vertex[4]==0.5,"SetColor tints every slice")
assert(rr.pieces[1].w==8 and rr.pieces[1].h==8,"corners take the radius")

-- Inside an option block a section header is a sub-header, not a new card.
local block=region("Frame");block.w=450;block._ktBlockContent=true
local sub,hs=W:SectionHeader(block,"Display",-10)
assert(hs==36,"section header height unchanged")
assert(block._ktCard==nil,"no card inside an option block")
assert(sub._dividerKT and same(sub._dividerKT.color,tok("divider")),"sub-header divider uses the divider token")

-- Option-block style card: back plate, border, rounded front, header pill.
local card=region("Frame");card.w=440
W:StyleCard(card,{title="Interface scale"})
assert(card._backKT and card._borderKT and card._frontKT,"card has back plate, border and front")
assert(same(card._frontKT.color,tok("card")),"front uses the card token")
assert(same(card._backKT.color,tok("cardBack")),"back plate uses the cardBack token")
assert(card._pillKT and card._titleKT.text=="Interface scale","header has a pill and a normal-case title")
assert(card._pillMarkKT.texture:find("card_icons",1,true),"the pill shows an icon from the atlas")
assert(W:CardIconFor("Interface scale")=="claw","titles with no rule show the claw")
assert(W:CardIconFor("CAST BAR COLORS")=="palette" and W:CardIconFor("Party Frames")=="users","first matching rule wins")
assert(W:CardIconFor("Action Bar Art")=="brush" and W:CardIconFor("Live Preview & Drop Zone")=="device-desktop","rules match word prefixes")
local l,r,t,b=W:CardIconCoords("palette");assert(l==1/8 and r==2/8 and t==0 and b==1/8,"icon coords index the 8x8 atlas")
local inAtlas={};for _,n in ipairs(W.CARD_ICONS) do inAtlas[n]=true end
for _,rule in ipairs(W.CARD_ICON_RULES) do assert(inAtlas[rule[1]],"rule icon "..rule[1].." is in the atlas") end

-- Hover: the back plate lights with the accent and spreads, then settles back.
card._ktSetHover(true,true)
assert(card._backKT.color[1]==0.8,"hovered back plate takes the accent")
card._ktSetHover(false,true)
assert(same(card._backKT.color,tok("cardBack")),"back plate returns to rest")

-- On a plain page a section header opens such a card, hidden until rows join.
local page=region("Frame");page.w=920
local _,h=W:SectionHeader(page,"Display",-10);assert(h==36)
local pcard=assert(page._ktCard,"section header opens a card")
assert(not pcard.shown,"a card stays hidden until a row joins it")
local get,set=function()return true end,function()end
local t1,h1=W:Toggle(page,"A",-46,get,set);assert(h1==38,"toggle height unchanged")
local t2=W:Toggle(page,"B",-84,get,set)
assert(pcard.shown,"the card shows once it has rows")
local p=pcard.points[#pcard.points];assert(p[2]==t2,"card bottom follows the last row")

-- Rows are open: no stripes or dividers; hover lights a rounded pill.
assert(t2._rowDividerKT==nil,"no dividers between rows")
t1.scripts.OnEnter(t1)
assert(t1.hoverKT.shown and same(t1.hoverKT.color,tok("rowHover")),"hover shows a rounded pill")
t1.scripts.OnLeave(t1)
assert(not t1.hoverKT.shown,"pill hides on leave")

-- A dual row keeps one hover per half and a divider between them.
local row,hr=W:DualRow(page,-122,{type="toggle",text="L"},{type="toggle",text="R"})
assert(hr==38,"dual row height unchanged")
assert(row._dividerKT,"dual row has a centre divider")

-- Skin repaint recolours rounded shapes already on screen.
MS.skins.kui.colors.card={0.3,0.3,0.3,1}
MS:Repaint()
assert(card._frontKT.color[1]==0.3,"repaint applies new skin tokens")

local f=assert(io.open(root.."/KullThranUI/Options.lua"));local src=f:read("*a");f:close()
assert(src:find("KT.Widgets:StyleCard(frame, { title = title })",1,true),"option blocks use the layered card with their title")
assert(src:find("content._ktBlockContent = true",1,true),"block content is marked for sub-headers")
print("widgets_cards: rounded rects, layered cards, hover, open rows and repaint passed")
