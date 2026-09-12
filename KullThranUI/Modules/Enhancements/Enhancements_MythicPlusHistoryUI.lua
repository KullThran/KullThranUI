local _, ns = ...
local KT = (ns and ns.KT) or _G.KT
local Mod = KT and KT:GetModule("Enhancements", true)
local H = Mod and Mod.MythicPlusHistory
if not H then return end

local LText = KT.LText or function(k) return k end
local function T(en, spanish) return LText(en) end

local function getFontPath()
    local config = H:Config()
    local profile = KT.db and KT.db.profile
    local key = config.font or (profile and profile.globalFont and profile.globalFont.font) or "Avant Garde"
    if KT.ResolveFontPath then return KT:ResolveFontPath(key) end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if key and LSM and LSM:Fetch("font", key) then
        return LSM:Fetch("font", key)
    end
    return "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
end

local function label(parent, size, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local config = H:Config()
    fs:SetFont(getFontPath(), math.max(8, size * (config.fontScale or 1)), config.fontOutline or "OUTLINE")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then fs:SetWidth(width) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    local color = config.textColor or {r=.93,g=.93,b=.93}
    fs:SetTextColor(color.r,color.g,color.b,color.a or 1)
    if not H.fontStrings then H.fontStrings = {} end
    table.insert(H.fontStrings, {fs = fs, size = size})
    return fs
end
local function number(v, decimals)
    return type(v) == "number" and string.format("%." .. (decimals or 0) .. "f", v) or "--"
end
local function compactDPS(value)
    if type(value) ~= "number" then return "--" end
    if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
    if value >= 1000 then return string.format("%.0fk", value / 1000) end
    return string.format("%.0f", value)
end
local function duration(seconds)
    if type(seconds) ~= "number" then return "--:--" end
    seconds = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end
local function when(timestamp)
    return timestamp and date("%d/%m %H:%M", timestamp) or "--"
end
local function runTitle(run)
    return (run.dungeon or ("Dungeon " .. (run.mapID or "?"))) .. "  +" .. number(run.level)
end
local function result(run)
    if run.onTime == nil then return T("RESULT UNAVAILABLE", "RESULTADO SIN DATOS") end
    return run.onTime and T("IN TIME", "EN TIEMPO") or T("OVER TIME", "FUERA DE TIEMPO")
end
local function accent()
    local p = KT.GetStylePalette and KT:GetStylePalette()
    local c = p and p.accent
    return c and c.r or 1, c and c.g or .72, c and c.b or .14
end
local function skin(frame)
    KT:ApplyTexturedSurface(frame)
    frame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    local r, g, b = accent()
    frame:SetBackdropBorderColor(r, g, b, 1)
end
local function button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, height or 25)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    b:SetBackdropColor(0,0,0,.25)
    b:SetBackdropBorderColor(.4,.37,.3,1)
    local textRegion = label(b, 10, 0, 0, width - 8)
    textRegion:ClearAllPoints()
    textRegion:SetPoint("CENTER")
    textRegion:SetJustifyH("CENTER")
    b:SetFontString(textRegion)
    b:SetText(text)
    return b
end
local function tooltipText(owner, title, body)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, .82, .2)
    GameTooltip:AddLine(body, .9,.9,.9, true)
    GameTooltip:Show()
end

function H:ShowEquipment(member)
    self.equipmentMember = member
    local f = self.equipmentWindow
    if not f then
        f = CreateFrame("Frame", "KullThranUIKeyHistoryEquipment", UIParent, "BackdropTemplate")
        self.equipmentWindow = f
        f:SetSize(450, 610)
        f:SetPoint("CENTER", UIParent, "CENTER", 290, 0)
        -- Same top strata as the history window, but a higher level to stay above it.
        f:SetFrameStrata("TOOLTIP")
        f:SetFrameLevel(20)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        skin(f)
        f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0,0,0, 0.95)
        
        f.title = label(f, 16, 18, -18, 382)
        f.note = label(f, 11, 18, -46, 410)
        f.note:SetWordWrap(true)
        local close = button(f, "X", 24)
        close:SetPoint("TOPRIGHT", -7, -7)
        close:SetScript("OnClick", function() f:Hide() end)
        f.items = {}
        for index, slot in ipairs(self.slots) do
            local row = button(f, "", 414, 29)
            row:SetPoint("TOPLEFT", 18, -99 - (index - 1) * 30)
            
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(21, 21)
            row.icon:SetPoint("LEFT", 4, 0)
            
            row.text = label(row, 11, 32, -7, 370)
            row:SetScript("OnEnter", function(self)
                if self.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link); GameTooltip:Show() end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.items[index] = row
        end
        UISpecialFrames[#UISpecialFrames + 1] = "KullThranUIKeyHistoryEquipment"
    end
    f.title:SetText(member.name or "?")
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class or ""]
    if c then f.title:SetTextColor(c.r, c.g, c.b) else f.title:SetTextColor(1, 1, 1) end
    f.note:SetText(T("Equipment snapshot: ", "Equipo registrado: ") .. when(member.gearCapturedAt)
        .. "\n" .. T("Captured slots: ", "Casillas capturadas: ") .. number(member.gearCount)
        .. "/16  |  " .. T("Missing slots are not reconstructed.", "No se reconstruyen casillas sin datos."))
    for index, slot in ipairs(self.slots) do
        local row = f.items[index]
        row.link = member.gear and member.gear[slot]
        
        local iconTex = 134400 -- fallback question mark
        if row.link then
            local itemID = row.link:match("item:(%d+)")
            if itemID then
                iconTex = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID) or GetItemIcon(itemID) or 134400
            end
        end
        local preview = member.previewGear and member.previewGear[slot]
        row.icon:SetTexture(preview and preview.icon or iconTex)
        
        row.text:SetText(preview and ("|cffa335ee" .. preview.name .. "|r  ?  iLvl " .. number(member.ilvl)) or row.link or (T("Slot ", "Casilla ") .. slot .. "  --"))
    end
    f:Show()
end

function H:CreateWindow()
    if self.window then return self.window end
    local f = CreateFrame("Frame", "KullThranUIMythicPlusHistory", UIParent, "BackdropTemplate")
    self.window = f
    f:SetSize(950, 680)
    f:SetPoint("CENTER")
    -- Above KullThranUIMenu (FULLSCREEN_DIALOG) so the history window is never hidden behind Options.
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(10)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local available, width = UIParent:GetHeight(), UIParent:GetWidth()
    if available and width then
        f:SetScale(math.max(.5, math.min(1, (available - 35) / 680, (width - 35) / 950)))
    end
    skin(f)
    f.title = label(f, 19, 22, -17, 820)
    f.title:SetText(T("Mythic+ History", "Historial de miticas+"))
    local close = button(f, "X", 27)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnHide", function() if H.equipmentWindow then H.equipmentWindow:Hide() end end)
    UISpecialFrames[#UISpecialFrames + 1] = "KullThranUIMythicPlusHistory"

    f.hero = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.hero:SetPoint("TOPLEFT", 18, -51)
    f.hero:SetSize(914, 112)
    f.hero:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
    f.hero:SetBackdropColor(0,0,0,.2)
    
    f.hero.bg = f.hero:CreateTexture(nil, "BACKGROUND")
    f.hero.bg:SetPoint("TOPRIGHT", -1, -1)
    f.hero.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    f.hero.bg:SetWidth(400)
    f.hero.bg:SetAlpha(0.6)
    
    local gradient = f.hero:CreateTexture(nil, "BACKGROUND", nil, 1)
    gradient:SetPoint("TOPLEFT", f.hero.bg, "TOPLEFT")
    gradient:SetPoint("BOTTOMLEFT", f.hero.bg, "BOTTOMLEFT")
    gradient:SetWidth(200)
    gradient:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    gradient:SetGradient("HORIZONTAL", CreateColor(0,0,0,1), CreateColor(0,0,0,0))
    
    f.hero.kicker = label(f.hero, 10, 14, -10, 850)
    f.hero.name = label(f.hero, 24, 14, -28, 700)
    f.hero.status = label(f.hero, 14, 710, -34, 192)
    f.hero.factsTime = label(f.hero, 12, 14, -66, nil)
    f.hero.factsMargin = label(f.hero, 12, 0, -66, nil)
    f.hero.factsDeaths = label(f.hero, 12, 0, -66, nil)
    f.hero.factsUpgrade = label(f.hero, 12, 0, -66, nil)
    f.hero.factsScore = label(f.hero, 12, 0, -66, nil)
    
    f.hero.factsMargin:ClearAllPoints()
    f.hero.factsMargin:SetPoint("LEFT", f.hero.factsTime, "RIGHT", 10, 0)
    
    f.hero.factsDeaths:ClearAllPoints()
    f.hero.factsDeaths:SetPoint("LEFT", f.hero.factsMargin, "RIGHT", 10, 0)
    
    f.hero.factsUpgrade:ClearAllPoints()
    f.hero.factsUpgrade:SetPoint("LEFT", f.hero.factsDeaths, "RIGHT", 10, 0)
    
    f.hero.factsScore:ClearAllPoints()
    f.hero.factsScore:SetPoint("LEFT", f.hero.factsUpgrade, "RIGHT", 10, 0)
    
    f.hero.deathsTooltipFrame = CreateFrame("Button", nil, f.hero)
    f.hero.deathsTooltipFrame:SetAllPoints(f.hero.factsDeaths)

    f.hero.affixes = label(f.hero, 11, 14, -88, 884)

    f.selected = label(f, 14, 22, -180, 745)
    local latest = button(f, T("Latest key", "Ultima key"), 135)
    latest:SetPoint("TOPRIGHT", -22, -174)
    latest:SetScript("OnClick", function() H:Render() end)
    
    f.members = {}
    local cardWidth = 175
    local cardHeight = 190
    local spacing = 7
    local startX = 22
    for i = 1, 5 do
        local card = CreateFrame("Frame", nil, f, "BackdropTemplate")
        card:SetSize(cardWidth, cardHeight)
        card:SetPoint("TOPLEFT", startX + (i-1)*(cardWidth+spacing), -205)
        card:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
        card:SetBackdropColor(0,0,0,.2)
        
        card.bg = card:CreateTexture(nil, "BACKGROUND")
        card.bg:SetAllPoints()
        card.bg:SetAlpha(0.30)
        
        card.nameBar = card:CreateTexture(nil, "ARTWORK")
        card.nameBar:SetPoint("TOPLEFT", 0, -3)
        card.nameBar:SetPoint("TOPRIGHT", 0, -3)
        card.nameBar:SetHeight(23)
        card.nameBar:SetTexture("Interface\\Buttons\\WHITE8x8")
        card.nameBar:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, .85), CreateColor(0, 0, 0, .25))

        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(40, 40)
        card.icon:SetPoint("BOTTOMRIGHT", -5, 65)
        card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        card.roleIcon = card:CreateTexture(nil, "ARTWORK")
        card.roleIcon:SetSize(28, 28)
        card.roleIcon:SetPoint("BOTTOMLEFT", 8, 65)
        
        card.name = label(card, 14, 5, -8, cardWidth-10)
        card.name:SetJustifyH("CENTER")
        
        card.spec = label(card, 10, 5, -28, cardWidth-10)
        card.spec:SetJustifyH("CENTER")
        
        card.ilvl = label(card, 12, 5, -55, cardWidth-10)
        card.ilvl:SetJustifyH("CENTER")
        
        card.rating = label(card, 11, 5, -75, cardWidth-10)
        card.rating:SetJustifyH("CENTER")
        
        card.rio = label(card, 12, 5, -95, cardWidth-10)
        card.rio:SetJustifyH("CENTER")
        
        card.dmgBar = card:CreateTexture(nil, "BACKGROUND", nil, 2)
        card.dmgBar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 5)
        card.dmgBar:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 5)
        card.dmgBar:SetHeight(20)
        card.dmgBar:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        card.dmgBar:SetGradient("HORIZONTAL", CreateColor(0,0,0,0.8), CreateColor(0,0,0,0))
        
        card.medal = card:CreateTexture(nil, "ARTWORK")
        card.medal:SetSize(16, 16)
        card.medal:SetPoint("LEFT", card.dmgBar, "LEFT", 4, 0)
        
        card.dmgText = label(card, 9, 25, 0, 82)
        card.dmgText:ClearAllPoints()
        card.dmgText:SetPoint("LEFT", card.medal, "RIGHT", 2, 0)
        card.dmgText:SetText(T("Most Damage", "Más daño"))
        card.dmgText:SetTextColor(1, 0.82, 0)
        
        card.dpsText = label(card, 10, 0, 0, 43)
        card.dpsText:ClearAllPoints()
        card.dpsText:SetPoint("RIGHT", card.dmgBar, "RIGHT", -4, 0)
        card.dpsText:SetJustifyH("RIGHT")

        card.gear = button(card, T("View Gear", "Ver Equipo"), cardWidth - 20, 24)
        card.gear:SetPoint("BOTTOM", 0, 30)
        card.gear:SetScript("OnClick",function() if card.member then H:ShowEquipment(card.member) end end)
        
        card:SetScript("OnMouseUp", function(self, btn)
            if btn == "RightButton" and self.member and RaiderIO and RaiderIO.util and RaiderIO.util.ShowCopyRaiderIOProfilePopup then
                local n = self.member.name
                local r = self.member.realm
                if n then RaiderIO.util:ShowCopyRaiderIOProfilePopup(n, r, "eu") end
            end
        end)
        card:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(T("Right-click to copy RaiderIO URL", "Click derecho para copiar URL de RaiderIO"), 1, 1, 1)
            if self.member and self.member.damageTotal then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(T("Damage Done: ", "Daño realizado: ") .. "|cffFFFFFF" .. number(self.member.damageTotal) .. "|r", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        card:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
        
        f.members[i] = card
    end
    f.missingParty = label(f,13,22,-375,906)
    f.missingParty:SetWordWrap(true)
    f.missingParty:SetText(T("Imported from Blizzard. Historical party, specs, equipment and individual ratings are not provided. New keys recorded by KUI include the data it can capture.",
        "Importada de Blizzard. No proporciona el grupo, specs, equipo ni puntuaciones individuales de esta key. Las nuevas keys registradas por KUI incluyen los datos que pueda capturar."))
    f.missingParty:Hide()
    f.note = label(f,10,22,-410,906)
    f.note:SetText(T("Blizzard: start > finish. RIO: addon snapshot. Map: best score before this key. -- = unavailable.",
        "Blizzard: inicio > final. RIO: datos del addon. Mapa: mejor puntuacion anterior a esta key. -- = sin datos."))
    label(f,12,22,-435,880):SetText(T("PREVIOUS KEYS  -  click to view the party", "KEYS ANTERIORES  -  pulsa para ver el grupo"))
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",22,-455)
    scroll:SetPoint("BOTTOMRIGHT",-42,36)
    local child = CreateFrame("Frame",nil,scroll)
    child:SetSize(880,1)
    scroll:SetScrollChild(child)
    f.history, f.historyRows = child, {}
    f.footer = label(f,10,22,-656,900)
    return f
end

function H:Render(selectedID, demo)
    local f = self:CreateWindow()
    local style = self:Config()
    local startColor = style.nameGradientStart or {r=0,g=0,b=0,a=.85}
    local endColor = style.nameGradientEnd or {r=0,g=0,b=0,a=.25}
    for _, card in ipairs(f.members) do
        card.nameBar:SetGradient("HORIZONTAL", CreateColor(startColor.r,startColor.g,startColor.b,startColor.a or .85), CreateColor(endColor.r,endColor.g,endColor.b,endColor.a or .25))
    end
    local runs = demo or self.demoRuns or self:Runs()
    local latest = runs[1]
    f.footer:SetText(T("Last 50 keys per character. Imports available Blizzard history; detailed party capture starts when enabled.",
        "Ultimas 50 keys por personaje. Importa el historial disponible de Blizzard; grupo detallado desde que se activa."))
    if not latest then
        f.hero.kicker:SetText(T("NO RUNS YET", "AUN NO HAY KEYS"))
        f.hero.name:SetText(T("Complete a Mythic+ to start", "Completa una mitica+ para empezar"))
        f.hero.status:SetText(""); f.hero.affixes:SetText("")
        f.hero.bg:SetTexture(nil)
        for _, key in ipairs({"factsTime", "factsMargin", "factsDeaths", "factsUpgrade", "factsScore"}) do f.hero[key]:SetText("") end
        f.selected:SetText("")
        f.missingParty:Hide()
        for _, row in ipairs(f.members) do row:Hide() end
        for _, row in ipairs(f.historyCards or {}) do row:Hide() end
        f.history:SetHeight(1)
        return
    end
    local selected = latest
    for _, run in ipairs(runs) do if run.id == selectedID then selected = run; break end end
    self.selectedID = selected.id
    latest = selected
    f.hero.kicker:SetText((self.demoRuns and T("PREVIEW - NOT SAVED", "VISTA PREVIA - NO SE GUARDA") or (selected == runs[1] and T("LATEST KEY", "ULTIMA KEY") or T("SELECTED KEY", "KEY SELECCIONADA")))
        .. "  |  " .. when(latest.completedAt)
        .. (latest.source == "blizzard" and T("  |  IMPORTED FROM BLIZZARD", "  |  IMPORTADA DE BLIZZARD") or ""))
    
    local heroTitleStr = "|cffF5F5DC" .. (latest.dungeon or ("Dungeon " .. (latest.mapID or "?"))) .. "|r  |cffFF9900+" .. number(latest.level) .. "|r"
    f.hero.name:SetText(heroTitleStr)
    f.hero.status:SetText(result(latest))
    f.hero.status:SetTextColor(latest.onTime and .35 or 1, latest.onTime and .95 or .4, .32)
    
    if latest.previewTexture then
        f.hero.bg:SetTexture(latest.previewTexture)
        f.hero.bg:SetTexCoord(0.05, 0.95, 0.15, 0.85)
    elseif latest.mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, _, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(latest.mapID)
        local tex = (backgroundTexture and backgroundTexture > 0) and backgroundTexture or texture
        if tex then
            f.hero.bg:SetTexture(tex)
            f.hero.bg:SetTexCoord(0.05, 0.95, 0.15, 0.85)
        else
            f.hero.bg:SetTexture(nil)
        end
    else
        f.hero.bg:SetTexture(nil)
    end
    
    local delta = latest.newScore and latest.oldScore and latest.newScore-latest.oldScore
    local margin = latest.timeLimit and latest.durationMS and latest.timeLimit-latest.durationMS/1000
    local timeColor = latest.onTime and "|cff00FF00" or (latest.onTime == false and "|cffFF3333" or "|cffFFFFFF")
    local timeText = T("Time ", "Tiempo ") .. timeColor .. duration(latest.durationMS/1000) .. " / " .. duration(latest.timeLimit) .. "|r"
    local margin = latest.timeLimit and latest.durationMS and latest.timeLimit-latest.durationMS/1000
    local marginText = margin and ((margin >= 0 and "|cff00FF00+|r" or "|cffFF0000-|r") .. "|cffFFFFFF" .. duration(math.abs(margin)) .. "|r") or "--"
    local deathsText = T("Deaths ", "Muertes ") .. "|cffFF3333" .. number(latest.deaths) .. "|r"
    local upgradeText = T("Upgrade ", "Mejora ") .. "|cff00FFCC+" .. number(latest.upgrades) .. "|r"
    
    local scoreText = ""
    if latest.source == "blizzard" then
        scoreText = T("Key score ", "Puntos de la key ") .. "|cffFF9900" .. number(latest.runScore,1) .. "|r"
    else
        scoreText = T("Score ", "Puntos ") .. "|cffFF9900" .. number(latest.oldScore) .. " > " .. number(latest.newScore) .. "|r"
    end
    local delta = type(latest.newScore) == "number" and type(latest.oldScore) == "number" and latest.newScore - latest.oldScore
    
    f.hero.factsTime:SetText(timeText)
    f.hero.factsMargin:SetText("   |   " .. marginText)
    f.hero.factsDeaths:SetText("   |   " .. deathsText)
    f.hero.factsUpgrade:SetText("   |   " .. upgradeText)
    f.hero.factsScore:SetText("   |   " .. scoreText .. (delta and (" (|cff00FF00" .. string.format("%+.1f",delta) .. "|r)") or ""))
    
    f.hero.deathsTooltipFrame:SetScript("OnEnter", function(self)
        if latest.penalty then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(T("Death Penalty", "Penalización de muertes"))
            GameTooltip:AddLine("|cffFF3333" .. duration(latest.penalty) .. "|r", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    f.hero.deathsTooltipFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    local affixes = {}
    for _, id in ipairs(latest.affixes or {}) do
        local name = C_ChallengeMode.GetAffixInfo and C_ChallengeMode.GetAffixInfo(id)
        affixes[#affixes+1] = name or tostring(id)
    end
    f.hero.affixes:SetText(T("Affixes: ", "Afijos: ") .. "|cffFFFFFF" .. (#affixes>0 and table.concat(affixes," / ") or "--") .. "|r")
    
    local selectedTitle = "|cffF5F5DC" .. (selected.dungeon or ("Dungeon " .. (selected.mapID or "?"))) .. "|r |cffFF9900+" .. number(selected.level) .. "|r"
    local timeColor = selected.onTime and "|cff00FF00" or "|cffFF3333"
    f.selected:SetText(selectedTitle .. "  |cff666666|||r  " .. timeColor .. duration(selected.durationMS/1000) .. "|r  |cff666666|||r  |cffAAAAAA" .. when(selected.completedAt) .. "|r")
    f.missingParty:SetShown(selected.source == "blizzard" and #(selected.members or {}) < 5)
    
    local sortedMembers = {}
    for _, m in ipairs(selected.members or {}) do
        table.insert(sortedMembers, m)
    end
    table.sort(sortedMembers, function(a, b)
        local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3, DPS = 3 }
        local aRole = roleOrder[a.role or ""] or 4
        local bRole = roleOrder[b.role or ""] or 4
        if aRole ~= bRole then return aRole < bRole end
        return (a.name or "") < (b.name or "")
    end)
    
    for index,card in ipairs(f.members) do
        local m = sortedMembers[index]
        card.member = m
        card:SetShown(m ~= nil)
        if m then
            card.name:SetText((m.name or "?") .. (m.realm and ("-" .. m.realm) or ""))
            local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class or ""]
            card.name:SetTextColor(c and c.r or 1,c and c.g or 1,c and c.b or 1)
            local _, spec, _, icon, role
            if m.specID and GetSpecializationInfoByID then _,spec,_,icon,role = GetSpecializationInfoByID(m.specID) end
            card.icon:SetTexture(icon or 134400)
            
            local activeUnit
            if m.guid then
                if UnitGUID("player") == m.guid then activeUnit = "player" end
                if not activeUnit then
                    for i = 1, 4 do if UnitGUID("party"..i) == m.guid then activeUnit = "party"..i; break end end
                end
                if not activeUnit then
                    for i = 1, 40 do if UnitGUID("raid"..i) == m.guid then activeUnit = "raid"..i; break end end
                end
            end

            if m.previewPortrait then
                card.bg:SetTexture(m.previewPortrait)
                card.bg:SetTexCoord(.08, .92, .08, .92)
            elseif activeUnit then
                SetPortraitTexture(card.bg, activeUnit)
                card.bg:SetTexCoord(0.15, 0.85, 0.15, 0.85)
            elseif m.class then
                card.bg:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
                local coords = CLASS_ICON_TCOORDS[m.class]
                if coords then 
                    card.bg:SetTexCoord(unpack(coords)) 
                else
                    card.bg:SetTexCoord(0, 1, 0, 1)
                end
            else
                card.bg:SetTexture(134400)
                card.bg:SetTexCoord(0, 1, 0, 1)
            end
            
            local roleStr = (m.role or role or "--"):gsub("DAMAGER", "DPS")
            local tex, l, r, t, b = nil, 0, 1, 0, 1
            local rRole = m.role or role
            if rRole == "TANK" then
                tex = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\Tank.png"
            elseif rRole == "HEALER" then
                tex = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\Healer.png"
            elseif rRole == "DAMAGER" or rRole == "DPS" then
                tex = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\DPS.png"
            end
            if tex then
                card.roleIcon:SetTexture(tex)
                card.roleIcon:SetTexCoord(l, r, t, b)
            else
                card.roleIcon:SetTexture(nil)
            end

            card.spec:SetText((spec or T("Spec unavailable","Spec sin datos")) .. " | " .. roleStr)
            card.ilvl:SetText("iLvl: |cffFFFFFF" .. number(m.ilvl,1) .. "|r")
            card.rating:SetText(T("Map: ","Mapa: ") .. "|cffFF9900" .. number(m.mapScore,1) .. "|r")
            
            card.rio:SetText("RIO: |cffFFFFFF" .. number(m.rio) .. "|r")
            card.gear:SetText(T("View Gear ", "Ver Equipo ") .. number(m.gearCount) .. "/16")
            
            if m.damageRank and m.damageRank >= 1 and m.damageRank <= 3 then
                local colors = { {1, .76, .18}, {.82, .87, .94}, {.80, .46, .24} }
                local c = colors[m.damageRank]
                local custom = style[({"goldColor","silverColor","bronzeColor"})[m.damageRank]]
                if custom then c = {custom.r,custom.g,custom.b} end
                card.dmgBar:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], custom and custom.a or .85), CreateColor(c[1] * .25, c[2] * .25, c[3] * .25, .25))
                card.dmgText:SetTextColor(1, 1, 1)
                card.dpsText:SetText(compactDPS(m.damageDPS))
                card.dpsText:Show()
                card.dmgBar:Show()
                card.medal:Show()
                card.dmgText:SetShown(m.damageRank == 1)
                if m.damageRank == 1 then
                    card.medal:SetTexture("Interface\\Challenges\\ChallengeMode_Medal_Gold")
                elseif m.damageRank == 2 then
                    card.medal:SetTexture("Interface\\Challenges\\ChallengeMode_Medal_Silver")
                else
                    card.medal:SetTexture("Interface\\Challenges\\ChallengeMode_Medal_Bronze")
                end
            else
                card.dpsText:Hide()
                card.dmgBar:Hide()
                card.medal:Hide()
                card.dmgText:Hide()
            end
        end
    end
    f.historyCards = f.historyCards or {}
    for index=1,#runs-1 do
        local run = runs[index+1]
        local card = f.historyCards[index]
        if not card then
            card = CreateFrame("Button", nil, f.history, "BackdropTemplate")
            card:SetSize(140, 140)
            card:SetBackdrop(f.hero:GetBackdrop())
            card:SetBackdropColor(0,0,0,.5)
            card:SetBackdropBorderColor(0,0,0,1)
            
            card.bg = card:CreateTexture(nil, "BACKGROUND")
            card.bg:SetAllPoints()
            card.bg:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            card.bg:SetAlpha(0.2)
            
            card.lvlText = label(card,20,5,-5,130)
            card.lvlText:SetJustifyH("CENTER")
            card.lvlText:SetTextColor(1,0.8,0)
            
            card.nameText = label(card,12,5,-35,130)
            card.nameText:SetJustifyH("CENTER")
            card.nameText:SetJustifyV("MIDDLE")
            card.nameText:SetHeight(35)
            card.nameText:SetWordWrap(true)
            
            card.resText = label(card,12,5,-75,130)
            card.resText:SetJustifyH("CENTER")
            
            card.timeText = label(card,11,5,-95,130)
            card.timeText:SetJustifyH("CENTER")
            
            card.dateText = label(card,10,5,-115,130)
            card.dateText:SetJustifyH("CENTER")
            card.dateText:SetTextColor(0.6,0.6,0.6)
            
            card:SetScript("OnClick",function(self) H:Render(self.runID) end)
            f.historyCards[index] = card
        end
        card.runID = run.id
        
        local i = index - 1
        local col = i % 6
        local rowIdx = math.floor(i / 6)
        card:SetPoint("TOPLEFT", col * 148, -rowIdx * 148)
        
        local name, _, _, texture, bgTexture = C_ChallengeMode.GetMapUIInfo(run.mapID or 0)
        local tex = run.previewTexture or ((bgTexture and bgTexture > 0) and bgTexture or texture) or 134400
        card.bg:SetTexture(tex)
        
        card.lvlText:SetText("+" .. (run.level or "?"))
        card.nameText:SetText(name or run.dungeon or "?")
        
        local res = run.onTime and "|cff00FF00" .. T("IN TIME", "EN TIEMPO") .. "|r" or "|cffFF0000" .. T("OVER TIME", "FUERA DE TIEMPO") .. "|r"
        if run.onTime == nil then res = "|cffAAAAAA" .. T("N/A", "N/A") .. "|r" end
        card.resText:SetText(res)
        
        card.timeText:SetText(duration(run.durationMS/1000) .. " / " .. duration(run.timeLimit))
        card.dateText:SetText(when(run.completedAt) .. (run.source == "blizzard" and " [I]" or ""))
        
        card:SetBackdropColor(0,0,0,run.id==selected.id and .8 or .5)
        card:SetBackdropBorderColor(1,0.8,0,run.id==selected.id and 1 or 0)
        card.bg:SetAlpha(run.id==selected.id and 0.4 or 0.2)
        card:Show()
    end
    for i=math.max(1,#runs),#f.historyCards do f.historyCards[i]:Hide() end
    local numRows = math.ceil((#runs-1)/6)
    f.history:SetHeight(math.max(1,numRows*148))
end
function H:RefreshStyle()
    local config = self:Config()
    local color = config.textColor or {r=.93,g=.93,b=.93}
    for _, entry in ipairs(self.fontStrings or {}) do
        entry.fs:SetFont(getFontPath(), math.max(8, entry.size * (config.fontScale or 1)), config.fontOutline or "OUTLINE")
        entry.fs:SetTextColor(color.r,color.g,color.b,color.a or 1)
    end
    if self.window and self.window:IsShown() then self:Render(self.selectedID) end
    if self.equipmentWindow and self.equipmentWindow:IsShown() and self.equipmentMember then self:ShowEquipment(self.equipmentMember) end
end
function H:Show(id)
    if InCombatLockdown and InCombatLockdown() then return end
    self.demoRuns = nil
    self:RequestHistory()
    self:Render(id)
    self.window:Show()
end
function H:Preview()
    if InCombatLockdown and InCombatLockdown() then return end
    local stamp = GetServerTime()
    self.demoRuns = {}
    -- Preview data stays in memory and never enters the saved history.
    local maps = C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable() or {375, 376, 377, 378}
    if #maps == 0 then maps = {375, 376, 377, 378} end
    -- Class, specialization and portrait travel together when rotating the party.
    local tanks = {
        {"Baine", "WARRIOR", 73, "TANK", "Tauren", "Male"},
        {"Darion", "DEATHKNIGHT", 250, "TANK", "Human", "Male"},
        {"Muradin", "WARRIOR", 73, "TANK", "Dwarf", "Male"},
        {"Liadrin", "PALADIN", 66, "TANK", "BloodElf", "Female"},
        {"Malfurion", "DRUID", 104, "TANK", "NightElf", "Male"},
        {"Chen", "MONK", 268, "TANK", "Pandaren", "Male"},
    }
    local healers = {
        {"Anduin", "PALADIN", 65, "HEALER", "Human", "Male"},
        {"Velen", "PRIEST", 257, "HEALER", "Draenei", "Male"},
        {"Nobundo", "SHAMAN", 264, "HEALER", "Draenei", "Male"},
        {"Broll", "DRUID", 105, "HEALER", "NightElf", "Male"},
        {"Lili", "MONK", 270, "HEALER", "Pandaren", "Female"},
    }
    local damageDealers = {
        {"Thrall", "SHAMAN", 262, "DPS", "Orc", "Male"},
        {"Jaina", "MAGE", 63, "DPS", "Human", "Female"},
        {"Valeera", "ROGUE", 261, "DPS", "BloodElf", "Female"},
        {"Rexxar", "HUNTER", 253, "DPS", "Orc", "Male"},
        {"Guldan", "WARLOCK", 267, "DPS", "Orc", "Male"},
        {"Illidan", "DEMONHUNTER", 577, "DPS", "NightElf", "Male"},
        {"Tyrande", "PRIEST", 258, "DPS", "NightElf", "Female"},
        {"Taran", "MONK", 269, "DPS", "Pandaren", "Male"},
        {"Arthas", "DEATHKNIGHT", 251, "DPS", "Human", "Male"},
    }
    for i=1,9 do
        local mapID = maps[(i-1) % #maps + 1]
        local name, _, limit, texture, background = C_ChallengeMode.GetMapUIInfo(mapID)
        limit = limit or 1800
        local seconds = math.floor(limit * (i == 3 and 1.08 or (.72 + i * .018)))
        local run = {
            id="demo"..i, mapID=mapID, dungeon=name or ("Dungeon " .. mapID), level=13-i%5,
            previewTexture=(background and background > 0 and background) or texture or 522336,
            durationMS=seconds*1000, timeLimit=limit, onTime=seconds<=limit,
            completedAt=stamp-(i-1)*7200, deaths=i, penalty=i*15,
            upgrades=seconds>limit and 0 or (seconds<=limit*.8 and 2 or 1),
            oldScore=2800-i*12,newScore=2800-i*12+(seconds<=limit and 10 or 0),
            affixes={9},members={},
        }
        local roster = {
            damageDealers[(i-1) % #damageDealers + 1],
            damageDealers[i % #damageDealers + 1],
            tanks[(i-1) % #tanks + 1],
            healers[(i-1) % #healers + 1],
            damageDealers[(i+1) % #damageDealers + 1],
        }
        for j, data in ipairs(roster) do
            local rank = j==3 and 4 or j==4 and 5 or ((j==5 and 2 or j-1) + i-1) % 3 + 1
            run.members[j] = {
                name=data[1], class=data[2], specID=data[3], role=data[4],
                previewPortrait="Interface\\Icons\\Achievement_Character_" .. data[5] .. "_" .. data[6],
                ilvl=610+j-i, rating=2800+j*15-i*12, rio=2780+j*17-i*10, mapScore=310+j*2-i*3,
                damageRank=rank<=3 and rank or nil,
                damageDPS=({231000, 212000, 194000, 98000, 32000})[rank]+(i-1)*1700,
                damageTotal=(({231000, 212000, 194000, 98000, 32000})[rank]+(i-1)*1700)*seconds,
                gearCount=16, gear={}, previewGear={}, gearCapturedAt=run.completedAt,
            }
        end
        local gearNames = {"Helm", "Amulet", "Shoulders", "Chest", "Belt", "Legguards", "Boots", "Bracers", "Gloves", "Ring", "Signet", "Trinket", "Charm", "Cloak", "Weapon", "Off-hand"}
        local gearIcons = {133071, 133280, 135041, 132720, 132505, 134589, 132536, 132606, 132939, 133345, 133345, 134400, 134400, 133770, 135328, 134955}
        for _, member in ipairs(run.members) do
            for slotIndex, slot in ipairs(self.slots) do
                member.previewGear[slot] = {name="[Preview] " .. gearNames[slotIndex], icon=gearIcons[slotIndex]}
            end
        end
        self.demoRuns[i] = run
    end
    self:Render()
    self.window:Show()
end
function Mod:ShowMythicPlusHistory() H:Show() end
SLASH_KULLTHRANKEYHISTORY1 = "/ktkeys"
SlashCmdList.KULLTHRANKEYHISTORY = function(msg)
    if msg and msg:lower():match("^test") then H:Preview() else H:Show() end
end
