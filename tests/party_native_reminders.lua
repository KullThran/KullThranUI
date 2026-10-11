local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Styles.lua"))
local source=f:read("*a"); f:close()
local Styles={}
local current="kui"
function Styles.Current() return current end
local Mod={}
function Mod:UpdateFrameAuras(frame, event)
 if frame then frame.missingBuffIcon.shown=true; frame.buffsUpdated=event end
 return "updated"
end
local env=setmetatable({Styles=Styles,Mod=Mod},{__index=_G})
local function loadSection(first,last)
 local a=assert(source:find(first,1,true))
 local b=assert(source:find(last,a,true))
 local chunk=assert(loadstring(source:sub(a,b-1))); setfenv(chunk,env); chunk()
end
loadSection("function Styles.HideNativePartyReminder", "function Styles.Apply(frame,")
loadSection("local UpdateFrameAuras = Mod.UpdateFrameAuras", "local UpdateFramePowerEvent =")
local icon={shown=true}
function icon:Hide() self.shown=false end
local frame={mode="party",missingBuffIcon=icon}
for _,style in ipairs({"classic","retail","forever"}) do
 current=style
 for _,event in ipairs({"UNIT_AURA","GROUP_ROSTER_UPDATE","TEST"}) do
  assert(Mod:UpdateFrameAuras(frame,event)=="updated")
  assert(not icon.shown, "aura event re-shows native party reminder")
  assert(frame.buffsUpdated==event, "normal aura refresh was skipped")
 end
 -- Preview style override and layout without portraits share the policy.
 icon.shown=true; Styles.HideNativePartyReminder(frame,"party",style)
 assert(not icon.shown)
end
current="kui"
Mod:UpdateFrameAuras(frame,"UNIT_AURA")
assert(icon.shown,"switching back to KUI must retain reminders")
for _,mode in ipairs({"raid","arena","arenaEnemy"}) do
 current="retail"; frame.mode=mode
 Mod:UpdateFrameAuras(frame,"UNIT_AURA")
 assert(icon.shown,"non-party mode must retain reminders")
end
Mod:UpdateFrameAuras(nil,"UNIT_AURA")
local applyStart=assert(source:find("function Styles.Apply(frame,",1,true))
local apply=source:sub(applyStart)
assert(apply:find("Styles.HideNativePartyReminder(frame, mode, key)",1,true))
print("PASS: native party reminders stay hidden across aura events; KUI, raid, arena and normal auras preserved")
