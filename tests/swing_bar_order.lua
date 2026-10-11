local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_ResourceBars/Modules/KUIResourceBars/KUIResourceBars_Swing.lua"));local source=f:read("*a");f:close()
local a=assert(source:find("function ns.GetSwingOrder",1,true))
local b=assert(source:find("function ns.EnsureSwingDefaults",a,true))
local ns={};local cursorY=0
local env=setmetatable({ns=ns,order={"main","off","ranged"},GetCursorPosition=function() return 0,cursorY end,
 CreateFrame=function()
  local hit={scripts={}}
  function hit:SetAllPoints(v) self.bar=v end
  function hit:EnableMouse(v) self.mouse=v end
  function hit:SetFrameLevel(v) self.level=v end
  function hit:RegisterForDrag(v) self.button=v end
  function hit:SetScript(k,v) self.scripts[k]=v end
  return hit
 end},{__index=_G})
local fn=assert(loadstring(source:sub(a,b-1)));setfenv(fn,env);fn()
local db={swing={order={"off","off","bad","main"}}}
assert(table.concat(ns.GetSwingOrder(db),",")=="off,main,ranged")
assert(not ns.MoveSwingHand(db,"bad","main"))
assert(not ns.MoveSwingHand(db,"main","main"))
db.swing.order=nil;assert(table.concat(ns.GetSwingOrder(db),",")=="main,off,ranged")
local bars={};local changed=0
for i,hand in ipairs({"main","off","ranged"}) do
 local bar={_swingPreviewHand=hand,shown=true,scale=2}
 function bar:GetFrameLevel() return 4 end
 function bar:SetAlpha(v) self.alpha=v end
 function bar:IsShown() return self.shown end
 function bar:GetCenter() return 20,self.y end
 function bar:GetEffectiveScale() return self.scale end
 bars[i]=bar
end
local function layout()
 local y=50
 for _,hand in ipairs(ns.GetSwingOrder(db)) do
  for _,bar in ipairs(bars) do if bar._swingPreviewHand==hand and bar.shown then bar.y=y;y=y+20 end end
 end
end
layout()
local function refresh() changed=changed+1;layout() end
for _,bar in ipairs(bars) do ns.BindSwingPreviewReorder(bar,bar._swingPreviewHand,bars,db,refresh) end
local function drag(bar,y)
 local hit=bar._swingReorderHit;assert(hit.button=="LeftButton" and hit.mouse)
 hit.scripts.OnDragStart(hit);assert(bar.alpha==.6)
 cursorY=y;hit.scripts.OnDragStop(hit);assert(bar.alpha==1 and not hit.dragging)
end
drag(bars[1],999)
assert(table.concat(db.swing.order,",")=="off,ranged,main" and changed==1,"drag above top moves the bar to top")
drag(bars[1],1)
assert(table.concat(db.swing.order,",")=="main,off,ranged" and changed==2,"drag below bottom moves the bar to bottom")
bars[2].shown=false;layout();drag(bars[1],bars[3].y*2)
assert(table.concat(db.swing.order,",")=="off,ranged,main" and changed==3,"hidden hands remain saved but are not drop targets")
local hit=bars[1]._swingReorderHit;hit.scripts.OnDragStart(hit);hit.scripts.OnHide(hit);hit.scripts.OnDragStop(hit)
assert(changed==3 and bars[1].alpha==1,"closing the preview cancels a pending drag")
local reloaded={swing={order={unpack(db.swing.order)}}}
assert(table.concat(ns.GetSwingOrder(reloaded),",")=="off,ranged,main","saved order survives reload")
assert(source:find("for _, hand in ipairs(ns.GetSwingOrder(db)) do",1,true),"live bars use the saved order")
print("PASS: swing order defaults, sanitization, scaled drag/drop, hidden bars, cancellation, persistence and live order")
