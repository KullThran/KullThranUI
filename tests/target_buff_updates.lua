local root=arg[1] or "."
local function read(path) local f=assert(io.open(root.."/"..path));local s=f:read("*a");f:close();return s end
local ns, queued, current, exists, combat = {}, {}, {}, true, true
local settings={maxBuffs=20,showBuffs=true}
local buffs={rendered={},updates=0}
function buffs:Show() end
-- Load the real oUF aura scanner/sorter/renderer, with only native UI APIs mocked.
local engine, engineEnable
local api={
    GetAuraSlots=function(unit,filter)
        assert(unit=="target" and filter=="HELPFUL")
        return nil,unpack(current)
    end,
    GetAuraDataBySlot=function(unit,id) return {auraInstanceID=id,icon=id} end,
    IsAuraFilteredOutByInstanceID=function() return false end,
    GetAuraDuration=function() return nil end,
    GetAuraApplicationDisplayCount=function() return "" end,
}
local auraTable=setmetatable({wipe=function(t) for k in pairs(t) do t[k]=nil end;return t end},{__index=table})
local scanner=assert(loadstring(read("KullThranUI/Libraries/oUF/elements/auras.lua")))
setfenv(scanner,setmetatable({C_UnitAuras=api,table=auraTable},{__index=_G}))
scanner("KUI",{oUF={AddElement=function(_,name,update,enable) assert(name=="Auras");engine=update;engineEnable=enable end}})
buffs.createdButtons=0;buffs.anchoredButtons=0;buffs.visibleButtons=0
buffs.SetPosition=function() end
function buffs:CreateButton()
    local button={Icon={SetTexture=function(self,id) self.texture=id end},Count={SetText=function() end}}
    function button:SetSize() end
    function button:EnableMouse() end
    function button:Show() self.shown=true end
    function button:Hide() self.shown=false end
    return button
end
local frame={Buffs=buffs,unit="target",shown=true,enabled=false}
function buffs:ForceUpdate()
    self.updates=self.updates+1
    engine(frame,"ForceUpdate","target")
    self.rendered={}
    for _,button in ipairs(self) do
        if button.shown then self.rendered[#self.rendered+1]=button.Icon.texture end
    end
end
function frame:IsShown() return self.shown end
function frame:IsElementEnabled(name) assert(name=="Auras");return self.enabled end
function frame:EnableElement(name) assert(name=="Auras");self.enabled=true end
function frame:HookScript(k,fn) self[k]=fn end
local sync
local env=setmetatable({C_Timer={After=function(_,fn) queued[#queued+1]=fn end},
    UnitExists=function(unit) assert(unit=="target");return exists end,
    InCombatLockdown=function() return combat end,
    CreateFrame=function()
        sync={events={}}
        function sync:RegisterUnitEvent(event,unit) self.events[event]=unit end
        function sync:RegisterEvent(event) self.events[event]=true end
        function sync:SetScript(k,fn) self[k]=fn end
        return sync
    end}, {__index=_G})
local fn=assert(loadstring(read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_TargetAuraSync.lua")))
setfenv(fn,env);fn("KUI",ns)
local debuffs=0
ns.InstallTargetAuraSync(frame,"target",function() debuffs=debuffs+1 end,function() return settings end)
local function drain() local q=queued;queued={};for _,f in ipairs(q) do f() end end
drain();assert(frame.enabled and sync.events.UNIT_AURA=="target")
-- A buff may become queryable only after UNIT_AURA dispatch. Refresh next frame in combat.
sync.OnEvent(sync,"UNIT_AURA","target")
current={101,102,103,104,105,106};drain()
assert(#buffs.rendered==6 and buffs.rendered[6]==106,"buff must appear without another target click")
local before=buffs.updates
sync.OnEvent(sync,"UNIT_AURA","target");sync.OnEvent(sync,"UNIT_AURA","target")
assert(#queued==1,"aura bursts must be coalesced")
current={101,103};drain();assert(#buffs.rendered==2 and buffs.updates==before+1)
sync.OnEvent(sync,"UNIT_AURA","player");assert(#queued==0,"unrelated units must not refresh target")
-- Switching targets consumes the current target's snapshot, without retaining old icons.
sync.OnEvent(sync,"PLAYER_TARGET_CHANGED");current={201};drain();assert(buffs.rendered[1]==201)
frame.shown=false;current={301};sync.OnEvent(sync,"UNIT_AURA","target");drain()
frame.shown=true;frame.OnShow();drain();assert(buffs.rendered[1]==301)
local hidden=0;local originalHide=buffs[1].Hide;buffs[1].Hide=function(self) hidden=hidden+1;originalHide(self) end;exists=false
sync.OnEvent(sync,"PLAYER_TARGET_CHANGED");drain();assert(hidden==1 and buffs.visibleButtons==0)
exists=true;settings.maxBuffs=1;current={401,402};sync.OnEvent(sync,"UNIT_AURA","target");drain()
assert(#buffs.rendered==1 and buffs.num==1,"configured maximum must be respected")
assert(combat and debuffs>0)
local source=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")
assert(source:find('buffs.num = (settings and settings.maxBuffs) or 20',1,true))
assert(source:find('ns.InstallTargetAuraSync(frame, unit, SyncTargetAuraContainer, GetSettingsForUnit)',1,true))
print("target buff event refresh checks passed, including combat")

-- Restricted-client path: buffs must belong to AuraContainer, not the Lua scanner.
local native, nativeSpec
local host={num=20,size=18,spacing=2,initialAnchor="BOTTOMLEFT",growthX="RIGHT",growthY="UP"}
function host:GetWidth() return 160 end
function host:Show() end
local nativeFrame={Buffs=host,unit="target"}
function nativeFrame:IsShown() return true end
function nativeFrame:HookScript(key,fn) self[key]=fn end
function nativeFrame:EnableElement() error("native buffs must not enable the Lua scanner") end
function nativeFrame:RegisterEvent() end
local layouts=0
local AK={styles={},
    SetContainerAnchor=function() layouts=layouts+1;assert(not combat) end,
    SetContainerRowWidth=function() assert(not combat) end,
    SetContainerGrowth=function() assert(not combat) end,
    CreateContainer=function(parent,unit,spec)
        assert(parent==host and unit=="target")
        nativeSpec=spec
        native={unit=unit}
        function native:SetAuraGroupMaxFrameCount(key,count)
            assert(key=="targetBuffs");self.count=count
        end
        function native:ClearAllPoints() assert(not combat) end
        function native:SetPoint() assert(not combat) end
        function native:SetAuraGroupLayout() assert(not combat) end
        function native:SetUnit(unit) self.unit=unit end
        function native:Show() self.shown=true end
        function native:Hide() self.shown=false;self.rendered={} end
        function native:UpdateAllAuras()
            self.rendered={}
            for i=1,math.min(self.count,#current) do self.rendered[i]=current[i] end
        end
        return native
    end,
}
env._G={KTAuraKit=AK}
combat=false;current={601};exists=true;settings.maxBuffs=20
ns.InstallTargetAuraSync(nativeFrame,"target",function() end,function() return settings end)
drain()
assert(nativeSpec.groups[1].filter[1]=="HELPFUL" and layouts==1)
local forceUpdate=host.ForceUpdate
assert(engineEnable(nativeFrame) and host.ForceUpdate==forceUpdate,
    "oUF must leave native ownership and ForceUpdate intact")
api.GetAuraSlots=function() error("restricted Lua aura query") end
combat=true;current={701,702}
engine(nativeFrame,"PLAYER_TARGET_CHANGED","target")
sync.OnEvent(sync,"PLAYER_TARGET_CHANGED");drain()
assert(native.shown and native.rendered[2]==702 and layouts==1,
    "combat allied target must use native auras without geometry changes")
settings.maxBuffs=1;sync.OnEvent(sync,"UNIT_AURA","target");drain()
assert(native.count==1 and #native.rendered==1)
settings.showBuffs=false;sync.OnEvent(sync,"UNIT_AURA","target");drain()
assert(not native.shown and native.unit=="none")
settings.showBuffs=true;exists=false
sync.OnEvent(sync,"PLAYER_TARGET_CHANGED");drain()
assert(not native.shown and native.unit=="none")
assert(not sync.OnUpdate,"native aura events replace combat polling")
print("PASS: native target buffs bypass restricted Lua scans in combat")
