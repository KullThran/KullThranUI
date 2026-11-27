local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local LSM = LibStub("LibSharedMedia-3.0", true)
local trackedFonts = setmetatable({}, {__mode="k"})

-- Areas without their own typography settings use their module's profile table.
function KT:GetAreaFontPath(area)
    local profile = self.db and self.db.profile or {}
    local config = profile[area] or {}
    local value = config.font or (profile.globalFont and profile.globalFont.font) or self.DEFAULT_FONT_NAME
    if self.ResolveFontPath then return self:ResolveFontPath(value) end
    return (LSM and LSM:Fetch("font", value, true)) or self.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end
function KT:StyleAreaFont(fs, area, size, flags)
    trackedFonts[fs] = {area=area, size=size, flags=flags}
    local config = self.db.profile[area] or {}
    fs:SetFont(self:GetAreaFontPath(area), math.max(8, size * (config.fontScale or 1)), config.fontOutline or flags or "OUTLINE")
end
function KT:RefreshAreaFonts()
    for fs, info in pairs(trackedFonts) do
        self:StyleAreaFont(fs, info.area, info.size, info.flags)
    end
end

function KT:BuildExtendedFontsColors(sc, W, y)
    local Opt = self.Options
    local profile = self.db.profile
    local globalFont = profile.globalFont
    local inherit = "__KUI_GLOBAL_FONT__"
    local cols = Opt.BeginOptionBlocks(sc, y, {gap=14, columnGap=16})
    local nextColumn = "left"
    local locale = self.GetLocale and self:GetLocale()
    local function T(text)
        return (locale and locale[text]) or text
    end
    local function TF(pattern, ...)
        return string.format(T(pattern), ...)
    end
    local function Refresh()
        local mod = KT:GetModule("GlobalFont", true)
        if mod then mod:QueueConsumerRefresh() end
    end
    local function FontValues()
        local values = Opt.GetFontValues()
        values[inherit] = "Use Global Font"
        return values
    end
    local function FontPath(value)
        if value == inherit then value = globalFont.font end
        return KT.ResolveFontPath and KT:ResolveFontPath(value) or value
    end
    local function Block(title, db, fields, changed)
        if not db then return end
        local column = nextColumn
        nextColumn = column == "left" and "right" or "left"
        Opt.AddOptionBlock(cols, column, title, function(parent)
            local by = 0
            for _, entry in ipairs(fields) do
                local kind, label, key, fallback = entry[1], entry[2], entry[3], entry[4]
                local function Save(value)
                    db[key] = value
                    if changed then changed(key, value) end
                    Refresh()
                end
                local h
                if kind == "font" then
                    _, h = W:Dropdown(parent, label, -by, FontValues,
                        function()
                            local value = db[key]
                            if not value or FontPath(value) == FontPath(globalFont.font) then return inherit end
                            return (Opt.ResolveRegisteredFontName and Opt.ResolveRegisteredFontName(value)) or value
                        end,
                        function(value) Save(value == inherit and globalFont.font or value) end, nil, FontPath)
                elseif kind == "size" or kind == "scale" then
                    _, h = W:Slider(parent, label, -by, function() return db[key] or fallback end, Save,
                        kind == "scale" and .75 or 8, kind == "scale" and 1.5 or 48, kind == "scale" and .05 or 1)
                elseif kind == "outline" then
                    _, h = W:Dropdown(parent, label, -by,
                        {none="No Outline", OUTLINE="Outline", THICKOUTLINE="Thick Outline"},
                        function() local v=db[key]; if v=="" then return "none" end; return v or "OUTLINE" end,
                        function(value) Save(value == "none" and "" or value) end)
                elseif kind == "toggle" then
                    _, h = W:Toggle(parent, label, -by, function() if db[key]==nil then return fallback end; return db[key] end, Save)
                elseif kind == "fill" then
                    _, h = W:ColorSwatch(parent, label, -by,
                        function() return db.fillR or 1,db.fillG or 1,db.fillB or 1,db.fillA or 1 end,
                        function(r,g,b,a) db.fillR,db.fillG,db.fillB,db.fillA=r,g,b,a; db.colorMode="custom"; db.classColor=false; Refresh() end,true)
                elseif kind == "color" then
                    _, h = W:ColorSwatch(parent, label, -by,
                        function() local c=db[key] or fallback or {r=1,g=1,b=1,a=1}; return c.r,c.g,c.b,c.a or 1 end,
                        function(r,g,b,a) Save({r=r,g=g,b=b,a=a or 1}) end, true)
                end
                by = by + (h or 0)
            end
            return by
        end)
    end
    local function F(label, key) return {"font",label,key or "font"} end
    local function S(label, key, value) return {"size",label,key or "fontSize",value or 12} end
    local function O(label, key) return {"outline",label or "Outline",key or "fontOutline"} end
    local function C(label, key, color) return {"color",label,key,color} end
    local enhancements = KT:GetModule("Enhancements", true)
    local db = enhancements and enhancements:GetDB() or profile.enhancements
    if db then
        db.mplusHistory = db.mplusHistory or {}
        local history = enhancements and enhancements.MythicPlusHistory
        local historyDB = history and history:Config() or db.mplusHistory
        Block("Mythic+ History", historyDB, {
            F("History Font"), {"scale","Text Scale","fontScale",1}, O(), C("Text Color","textColor"),
            C("Name Background Start","nameGradientStart",{r=0,g=0,b=0,a=.85}),
            C("Name Background End","nameGradientEnd",{r=0,g=0,b=0,a=.25}),
            C("Gold","goldColor",{r=1,g=.76,b=.18,a=.85}),
            C("Silver","silverColor",{r=.82,g=.87,b=.94,a=.85}),
            C("Bronze","bronzeColor",{r=.8,g=.46,b=.24,a=.85}),
        })
        db.mplusTracker = db.mplusTracker or {}
        Block("Mythic+ Timer Typography", db.mplusTracker, {
            F("Tracker Font","globalFont"), F("Timer Font","timerFont"), S("Timer Size","timerFontSize",26), O("Timer Outline","timerFontFlags"),
            F("Key Font","keyFont"), S("Key Size","keyFontSize",16), O("Key Outline","keyFontFlags"),
            F("Key Details Font","keyDetailsFont"), S("Key Details Size","keyDetailsFontSize",13), O("Key Details Outline","keyDetailsFontFlags"),
            F("Forces Font","forcesFont"), S("Forces Size","forcesFontSize",13), O("Forces Outline","forcesFontFlags"),
            F("Deaths Font","deathsFont"), S("Deaths Size","deathsFontSize",15), O("Deaths Outline","deathsFontFlags"),
            F("Objectives Font","objectivesFont"), S("Objectives Size","objectivesFontSize",12), O("Objectives Outline","objectivesFontFlags"),
            F("Chest +3 Font","bar1Font"), F("Chest +2 Font","bar2Font"), F("Chest +1 Font","bar3Font"),
        })
        local colors = {}
        for _, field in ipairs({{"Background","backgroundColor"},{"Key Level","keyColor"},{"Key Details","keyDetailsColor"},{"Timer Running","timerRunningColor"},{"Timer Success","timerSuccessColor"},{"Timer Expired","timerExpiredColor"},{"Deaths","deathsColor"},{"Forces Text","forcesColor"},{"Forces Bar","forcesBarColor"},{"Forces Glow","forcesGlowColor"},{"Chest +3","bar1Color"},{"Chest +2","bar2Color"},{"Chest +1","bar3Color"},{"Objectives","objectivesColor"},{"Completed Objectives","completedObjectivesColor"}}) do colors[#colors+1]=C(field[1],field[2]) end
        Block("Mythic+ Timer Colors", db.mplusTracker, colors)
        db.damageMeter = db.damageMeter or {}
        local meterFields = {F("Damage Meter Font"),S("Row Font Size","fontSize",12),S("Header Font Size","headerFontSize",12),O(),C("Text Color","textColor"),C("Background Color","backgroundColor",{r=.012,g=.014,b=.02,a=.94}),{"toggle","Class Colored Bars","classColors",true}}
        Block("Damage Meter", db.damageMeter, meterFields)
        for i, window in ipairs(db.damageMeter.windows or {}) do
            Block(TF("Damage Meter - %s", window.name or tostring(i + 1)), window, meterFields)
        end
        db.combatTimer = db.combatTimer or {}
        Block("Combat Timer",db.combatTimer,{F("Font"),S("Font Size","fontSize",22),O("Outline","outline"),C("Text Color","color"),C("Background","backgroundColor")})
        db.combatText = db.combatText or {}
        Block("Combat Status Text",db.combatText,{F("Font"),S("Font Size","fontSize",32),O("Outline","outline"),C("Enter Combat","enterColor"),C("Leave Combat","leaveColor"),C("Background","backgroundColor")})
    end
    for _, area in ipairs({{"Bags","bags"},{"Friend List","friendListTypography"},{"Cooldown Manager","cooldownManager"},{"Resource Bars","resourceBars"}}) do
        profile[area[2]] = profile[area[2]] or {}
        Block(TF("%s Typography", T(area[1])),profile[area[2]],{F("Font"),{"scale","Text Scale","fontScale",1},O()})
    end
    Block("Teleport Menu Typography",profile.teleportMenu,{F("Font"),S("Font Size"),O()})
    local units = profile.unitFrames or {}
    for _, unitInfo in ipairs({{"player","Player"},{"target","Target"},{"targettarget","Target of Target"},{"focus","Focus"},{"pet","Pet"},{"boss","Boss"}}) do
        local unit, unitLabel = unitInfo[1], unitInfo[2]
        Block(TF("Unit Frames - %s", T(unitLabel)),units[unit],{F("Font","selectedFont"),S("Left Text Size","leftTextSize",14),S("Right Text Size","rightTextSize",14),S("Center Text Size","centerTextSize",14),C("Health Fill","customFillColor",{r=.22,g=.55,b=.95,a=1}),C("Health Background","customBgColor",{r=.08,g=.08,b=.08,a=1})},function(key)
            if key == "customFillColor" then units[unit].healthClassColored = false end
        end)
    end
    local party = KT:GetModule("PartyFrames",true)
    if party and party.GetModeDB then
        for _, modeInfo in ipairs({{"party","Party"},{"raid","Raid"},{"raid40","Raid 40"},{"arena","Arena"}}) do
            local mode, modeLabel = modeInfo[1], modeInfo[2]
            Block(TF("Party Frames - %s", T(modeLabel)),party:GetModeDB(mode),{F("Font","textFont"),S("Name Size","nameFontSize",15),S("Health Size","healthTextFontSize",12),O("Outline","textOutline")})
        end
    end
    if _G.KullThranUINameplatesDB then
        local fields = {F("Font"),O()}
        for _, slot in ipairs({"Top","Left","Right","Center"}) do
            fields[#fields+1]=S(slot .. " Text Size","textSlot" .. slot .. "Size",12)
            fields[#fields+1]=C(slot .. " Text Color","textSlot" .. slot .. "Color")
        end
        Block("Nameplates Typography",_G.KullThranUINameplatesDB,fields)
    end
    for _, sectionInfo in ipairs({{"health","Health"},{"primary","Primary"},{"secondary","Secondary"}}) do
        local section, sectionLabel = sectionInfo[1], sectionInfo[2]
        Block(TF("Resource Bars - %s", T(sectionLabel)),(profile.resourceBars or {})[section],{S("Text Size","textSize",13),{"fill","Custom Fill Color"}})
    end
    local sizes = {
        {"Objective Tracker","objectiveTracker","fontSize","fontOutline",13},
        {"Minimap Zone","minimap","zoneFontSize","zoneFontOutline",12},
        {"Minimap Statistics","minimap","statsFontSize","statsFontOutline",11},
        {"Tooltip","tooltip","fontSize","fontOutline",12},
        {"Cast Bar","castbar","fontSize","fontOutline",12},
        {"Dragon Riding","dragonRiding","fontSize","fontOutline",12},
        {"Experience Bar","experienceBar","fontSize","fontOutline",12},
        {"Chat","chat","fontSize","fontOutline",12},
        {"Action Count","actionbars","fontSize","fontOutline",20},
        {"Action Hotkeys","actionbars","hotkeyFontSize","hotkeyFontOutline",12},
        {"Action Macro Text","actionbars","macroFontSize","macroFontOutline",12},
        {"Buff Duration","buffsAndDebuffs","durationFontSize","durationFontOutline",11},
        {"Buff Count","buffsAndDebuffs","countFontSize","countFontOutline",12},
        {"Armory Item Level","armory","ilvlSize","ilvlOutline",12},
        {"Armory Average Level","armory","avgIlvlFontSize","avgIlvlOutline",19},
        {"Armory Name","armory","charNameSize","charNameOutline",16},
        {"Armory Level","armory","charLevelSize","charLevelOutline",12},
        {"Armory Score","armory","scoreSize","scoreOutline",16},
        {"Inspect Item Level","inspectArmory","ilvlSize","ilvlOutline",12},
        {"Inspect Average Level","inspectArmory","avgIlvlSize","avgIlvlOutline",19},
    }
    for _, entry in ipairs(sizes) do Block(TF("%s Text", T(entry[1])),profile[entry[2]],{S("Font Size",entry[3],entry[5]),O("Outline",entry[4])}) end
    Block("Armory Additional Text",profile.armory,{S("Enchant Size","enchantSize",10),S("Statistics Size","statFontSize",12),O("Header Outline","headerOutline")})
    Block("Inspect Additional Text",profile.inspectArmory,{S("Enchant Size","enchantSize",10),S("Statistics Size","statFontSize",12),S("Average Level Label Size","avgIlvlLabelSize",10),O("Average Level Label Outline","avgIlvlLabelOutline")})
    return Opt.EndOptionBlocks(cols)
end
