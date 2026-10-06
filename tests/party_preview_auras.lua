local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Options.lua"));local source=f:read("*a");f:close()
local first=assert(source:find("        local auraSize =",1,true))
local last=assert(source:find("        local canShowAuras =",first,true))
local chunk=source:sub(first,last-1).."\nreturn auraSize,missingSize,auraGap,debuffStartX,buffY,previewDebuffCount"
for _,fit in ipairs({0.5,1,1.25}) do
    for _,growth in ipairs({"RIGHT","LEFT"}) do
        local env=setmetatable({fit=fit,cfg={auraMaxDebuffs=5,debuffAnchor="CENTER",debuffGrowthH=growth,buffIconsOffsetY=0},
            i=1,w=200,ns={},configMode="party",isRaidMode=false,direction="VERTICAL",
            ANCHOR_VALUES={CENTER=true},FLOW_VALUES={RIGHT=true,LEFT=true,DOWN=true}},{__index=_G})
        local fn=assert(loadstring(chunk));setfenv(fn,env)
        local size,missing,gap,start,buffY,count=fn()
        assert(count==2,"preview lays out only displayed icons")
        local stride=math.max(size,math.floor(24*fit))+gap
        local finish=start+(growth=="LEFT" and -stride or stride)
        assert(math.abs(start+finish)<0.001,"two displayed debuffs are centered as a pair")
        assert(buffY==0,"buffs do not spill into the preceding party row")
        env.i=2
        size,missing,gap,start,buffY,count=fn()
        assert(count==1 and start==0,"single debuff remains centered")
        assert(missing<=math.floor(44*fit),"missing buff scales with the frame")
        env.cfg.debuffIconsOffsetX=12;env.cfg.buffIconsOffsetY=8
        size,missing,gap,start,buffY,count=fn()
        assert(start==math.floor(12*fit) and buffY==math.floor(8*fit),"configured offsets remain effective")
    end
end
local condition=assert(source:match("if (canShowAuras and cfg%.showDispelOverlay.-) then"))
local env=setmetatable({canShowAuras=true,cfg={showDispelOverlay=true},configMode="party",previewStyle="kui",ns={PF_TestNoDispelOverlay={[1]=true}},previewDispelShown=false},{__index=_G})
local fn=assert(loadstring("return "..condition));setfenv(fn,env)
local overlays=0
for i=1,5 do
    env.i=i
    if fn() then overlays=overlays+1;env.previewDispelShown=true end
end
assert(overlays==1,"KUI party preview shows at most one eligible debuff overlay")
env.cfg.showDispelOverlay=false;env.previewDispelShown=false;assert(not fn(),"disabled overlay stays hidden")
print("party_preview_auras: centered rows, scaled icons and configured offsets passed")

local runtime=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames.lua")):read("*a")
local a=assert(runtime:find("local function GetTestAuraState(",1,true))
local b=assert(runtime:find("local function LayoutAuraIconSet(",a,true))
local ns={}
local env=setmetatable({ns=ns,TEST_AURA_DEBUFFS={{spellID=1,dispelType="Magic",isBossDebuff=true}},
    AuraSpellIsVisible=function() return true end,
    TrackDispel=function(state,kind) state.dispelType=kind end,
    GetPlayerMissingBuffRule=function() return nil end},{__index=_G})
local get=assert(loadstring(runtime:sub(a,b-1).."\nreturn GetTestAuraState"));setfenv(get,env);get=get()
for _,mode in ipairs({"party","raid","raid40","arena","arenaEnemy"}) do
    for seed=1,10 do
        local total=0
        for index=1,40 do
            local state=get({index=index},mode,{showDispelOverlay=true},seed)
            if not state.suppressDispelOverlay and state.dispelType then total=total+1 end
            assert(#state.debuffs>0,"other members retain sample debuff icons")
        end
        assert(total<=1,"Party Test must never show multiple dispel overlays")
    end
end
ns.PF_TestNoDispelOverlay={[1]=true}
assert(get({index=1},"party",{showDispelOverlay=true},1).suppressDispelOverlay)
local _,gates=runtime:gsub("if db.showDispelOverlay ~= false and not state.suppressDispelOverlay then","")
assert(gates==2,"both normal and hidden-aura overlay branches respect sample suppression")
print("party_test_overlays: at most one overlay, debuff icons preserved")
