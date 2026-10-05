local root=arg[1] or "."
local kt={db={profile={}}}
local adapter
kt.VisualThemes={RegisterModule=function(self,key,value) assert(key=="unitframes");adapter=value end}
local env=setmetatable({LibStub=function() return {GetAddon=function() return kt end} end},{__index=_G})
local file=assert(io.open(root.."/KullThranUI/Modules/VisualThemes/Adapters/UnitFrames.lua"))
local source=file:read("*a");file:close()
local chunk=assert(loadstring(source));setfenv(chunk,env);chunk("test",{})
local units={"player","target","focus","pet","boss"}
local function assertHidden(p)
 assert(p.portraitStyle=="none","Retail KUI uses no portrait style")
 for _,key in ipairs(units) do assert(p[key].showPortrait==false,key.." portrait stays disabled") end
end
-- Fresh default and previously saved slots both follow the same rule.
local fresh={};adapter.seed(fresh,"kui","retail");adapter.validate(fresh,"kui","retail");assertHidden(fresh)
for _,style in ipairs({"circular","attached","detached","none"}) do
 local saved={portraitStyle=style}
 for _,key in ipairs(units) do saved[key]={showPortrait=true} end
 adapter.validate(saved,"kui","retail");assertHidden(saved)
end
local incomplete={};adapter.validate(incomplete,"kui","retail");assertHidden(incomplete)
-- Switch from each native theme to a restored KUI slot, then back again.
for _,theme in ipairs({"classic","forever","retail"}) do
 local p={};adapter.seed(p,theme,"retail");adapter.validate(p,theme,"retail")
 assert(p.player.showPortrait and p.target.showPortrait,"native themes retain portraits")
 adapter.validate(p,"kui","retail");assertHidden(p)
 adapter.seed(p,theme,"retail");adapter.validate(p,theme,"retail")
 assert(p.player.showPortrait and p.target.showPortrait,"native theme can restore portraits")
end
local forever={};adapter.seed(forever,"kui","forever");adapter.validate(forever,"kui","forever")
assert(forever.portraitStyle=="circular" and forever.player.showPortrait,"Forever KUI defaults are preserved")
print("kui_retail_portraits: defaults, saved slots and style transitions passed")
