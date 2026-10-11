local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Options.lua"))
local source=f:read("*a");f:close()
local first=assert(source:find("local function LayoutPreviewDispelFrame(",1,true))
local last=assert(source:find("local function SetPreviewDispelBorder(",first,true))
local layout=assert(loadstring(source:sub(first,last-1).."\nreturn LayoutPreviewDispelFrame"))()
local function frame(level)
    local value={level=level,strata="HIGH",points={}}
    function value:ClearAllPoints() self.points={};self.all=nil end
    function value:SetPoint(...) self.points[#self.points+1]={...} end
    function value:SetAllPoints(other) self.all=other end
    function value:GetFrameLevel() return self.level end
    function value:SetFrameLevel(v) self.level=v end
    function value:GetFrameStrata() return self.strata end
    function value:SetFrameStrata(v) self.strata=v end
    return value
end
local unit={health=frame(4),dispelBorderFrame=frame(16),overlayFrame=frame(9),statusIconFrame=frame(18)}
for _,case in ipairs({{"left",3,23,0},{"right",3,0,17},{"left",-30,0,0}}) do
    layout(unit,true,"circular",case[1],20,case[2])
    local host=unit.dispelBorderFrame
    assert(host.points[1][2]==unit.health and host.points[1][4]==case[3])
    assert(host.points[2][2]==unit.health and host.points[2][4]==-case[4])
    assert(host.strata==unit.health.strata)
    assert(host.level<unit.overlayFrame.level and host.level<unit.statusIconFrame.level,"dispel shading stays below text and status")
end
layout(unit,true,"attached","right",0,0)
assert(unit.dispelBorderFrame.points[1][4]==0 and unit.dispelBorderFrame.points[2][4]==0)
layout(unit,false,"circular","left",20,0)
assert(unit.dispelBorderFrame.all==unit and #unit.dispelBorderFrame.points==0,"portrait off restores full frame bounds")
assert(source:find('unit._portraitCircular = portraitShow and portraitStyle == "circular"',1,true))
assert(source:find('unit.health:SetPoint("BOTTOMRIGHT", unit, "BOTTOMRIGHT", -padding - portraitRightInset, padding)',1,true))
assert(source:find('local innerWidth = math.max(1, w - (padding * 2) - portraitLeftInset - portraitRightInset)',1,true))
assert(source:find('local width = unit.dispelBorderFrame:GetWidth() or 1',1,true))
print("party_portrait_preview: ok")
