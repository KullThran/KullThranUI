local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local body = assert(source:match("function Mod:RegisterUnlockElements%(%)%s*(.-)self.elementsRegistered = true%s*end"))
local configs = { raid = { enabled=true }, raid40 = { enabled=true } }
local function container()
    return { shown=false, IsShown=function(self) return self.shown end, GetSize=function() return 1,1 end }
end
local mod = { db={enabled=true}, containers={}, ownGroupContainers={} }
for _,mode in ipairs({"party","raid","raid40","arena","arenaEnemy","boss"}) do mod.containers[mode]=container() end
for _,mode in ipairs({"raid","raid40"}) do mod.ownGroupContainers[mode]=container() end
function mod:GetModeDB(mode) return configs[mode] end
function mod:GetOwnGroupPositionKey(mode) return mode .. "OwnGroup" end
function mod:GetContainerSize(mode) return mode=="raid40" and 1000 or 500, 300 end
function mod:GetOwnGroupContainerSize() return 125, 300 end
function mod:LoadPosition(mode) return {point="TOPLEFT", relativePoint="TOPLEFT",x=42,y=-10,mode=mode} end
function mod:SavePosition(...) self.saved={...} end
function mod:ApplyPosition(mode) self.applied=mode end
function mod:ApplyOwnGroupPosition(mode) self.appliedOwn=mode end
local kt = {}
function kt:RegisterMovableElements(elements)
    self.elements={}
    for _,element in ipairs(elements) do self.elements[element.key]=element end
end
local env=setmetatable({KT=kt,Mod=mod,MODE_ORDER={"party","raid","raid40","arena","arenaEnemy","boss"},
    IsRaidMode=function(mode) return mode=="raid" or mode=="raid40" end},{__index=_G})
local chunk=assert(loadstring("return function(self) " .. body .. " self.elementsRegistered=true end"))
setfenv(chunk,env); local register=chunk();register(mod)
for _,mode in ipairs({"raid","raid40"}) do
    local element=assert(kt.elements["PARTYFRAMES_" .. mode:upper()])
    assert(element.isHidden(),"hidden outside Unlock Mode")
    kt._unlockActive=true
    assert(not element.isHidden(),"raid mover should be available without a raid")
    local width,height=element.getSize()
    assert(width>1 and height==300,"hidden containers need configured layout dimensions")
    assert(element.loadPosition().mode==mode)
    element.savePosition(nil,"CENTER","CENTER",100,200,1)
    assert(mod.saved[1]==mode,"save to the original raid layout")
    element.applyPosition(); assert(mod.applied==mode)
    configs[mode].enabled=false; assert(element.isHidden());configs[mode].enabled=true
    local own=assert(kt.elements["PARTYFRAMES_" .. mode:upper() .. "_OWN_GROUP"])
    assert(own.isHidden(),"do not show unused own-group mover")
    configs[mode].raidPopOutOwnGroup=true
    assert(not own.isHidden())
    configs[mode].raidUseGroups=false;assert(own.isHidden());configs[mode].raidUseGroups=true
    mod.db.enabled=false;assert(element.isHidden() and own.isHidden());mod.db.enabled=true
    kt._unlockActive=nil
    assert(element.isHidden())
    mod.containers[mode].shown=true;assert(not element.isHidden())
end
assert(kt.elements.PARTYFRAMES_RAID40.label=="Party Frames - Raid 40")
assert(kt.elements.PARTYFRAMES_BOSS.label=="Party Frames - Boss")
print("party_unlock_layout: PASS")
