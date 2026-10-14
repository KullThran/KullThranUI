-- Classic Bar Text follows the Unit Frames Health Text and Text Size settings.
local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua"));local source=f:read("*a");f:close()
local a=assert(source:find("local function ContentToTag",1,true))
local b=assert(source:find("-- Estimate pixel width",a,true))
local c=assert(source:find("-- Classic Visual Style: Player and Target show",1,true))
local d=assert(source:find("local function ApplyClassicFrameArt",c,true))
local settings={healthDisplay="both",textSize=14}
local function FS()
 local fs={shown=false}
 function fs:SetFont(p,s,fl) self.size=s end
 function fs:SetWordWrap() end function fs:SetTextColor() end function fs:SetShadowColor() end
 function fs:SetShadowOffset() end function fs:ClearAllPoints() end function fs:SetPoint() end
 function fs:SetJustifyH() end function fs:SetText() end function fs:SetAlpha() end
 function fs:Show() self.shown=true end function fs:Hide() self.shown=false end
 return fs
end
local env=setmetatable({db={profile={target=settings}},
 ns={UsesModernNumbers=function() return false end,StockStyleToggle=function() return true end,
  BlizzardFont=function() return "font",10,"OUTLINE" end},
 KT={VisualThemes={GetUnitTextSizeFactor=function() return (settings.textSize or 14)/14 end}},
 CreateFrame=function() return {SetAllPoints=function() end,EnableMouse=function() end,SetFrameLevel=function() end,
  CreateFontString=function() return FS() end} end},{__index=_G})
local chunk=assert(loadstring(source:sub(a,b-1)..source:sub(c,d-1)));setfenv(chunk,env);chunk()
local bar={GetHeight=function() return 15.84 end,IsShown=function() return true end,GetFrameLevel=function() return 2 end}
local frame={Health=bar,Power=bar,GetFrameLevel=function() return 1 end,
 Tag=function(self,fs,tag) fs.tag=tag end,Untag=function(self,fs) fs.tag=nil end}
local function apply() env.ns.ApplyClassicStatusText(frame,"target",true);return frame._ktClassicStatus.fs end
local fs=apply();assert(fs.hp.tag=="[kui-classic-hpfull]" and fs.hp.shown,"default keeps the Classic text")
local base=fs.hp.size
settings.healthDisplay="perhp";fs=apply();assert(fs.hp.tag=="[perhp]%","Percent is honoured")
settings.healthDisplay="curhpshort";fs=apply();assert(fs.hp.tag=="[curhpshort]","Current (Abbrev) is honoured")
settings.healthDisplay="deficit";fs=apply();assert(fs.hp.tag=="[deficithp]")
settings.healthDisplay="none";fs=apply();assert(not fs.hp.shown and not fs.hp.tag,"None hides the health text")
assert(fs.pp.tag=="[kui-classic-ppfull]","power text is unchanged")
settings.healthDisplay="both";settings.textSize=21;fs=apply()
assert(math.abs(fs.hp.size-base*1.5)<1e-6 and fs.pp.size==base,"Text Size scales the health text only")
print("PASS: Classic Bar Text honours Health Text and Text Size")
