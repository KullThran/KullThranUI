local addonName, ns = ...

local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("UnitFrames", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
local oUF = ns.oUF or oUF
local Compat = ns.KUIUFCompat or {}
ns.KUIUFCompat = Compat
ns.UnitFrames = Mod

Compat.PP = Compat.PP or {}
local PP = Compat.PP

if not oUF then
    error("KUIUnitFrames: oUF library not found! Please install oUF to Libraries\\oUF\\ folder.")
    return
end

local db
local RefreshPlayerStatusIndicators
local SetupPlayerStatusIndicators

-- ─── Ruta base para los iconos de indicadores de estado ────────────
local KUI_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\"
local PVP_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\"

local function SafeUnitLevelText(unit)
    if not unit or type(UnitLevel) ~= "function" then return nil end
    local ok, level = pcall(UnitLevel, unit)
    if not ok or (KT.IsSecret and KT.IsSecret(level)) or type(level) ~= "number" or level <= 0 then return nil end
    return tostring(level)
end

local function SafeUnitPvPFaction(unit)
    if not unit or type(UnitIsPVP) ~= "function" or type(UnitFactionGroup) ~= "function" then return nil end
    local ok, active = pcall(UnitIsPVP, unit)
    if not ok or (KT.IsSecret and KT.IsSecret(active)) or active ~= true then return nil end
    ok, active = pcall(UnitFactionGroup, unit)
    if not ok or (KT.IsSecret and KT.IsSecret(active)) then return nil end
    return (active == "Horde" or active == "Alliance") and active or nil
end

local defaults = {
    profile = {
        enable = true,
        showCharacterLevel = false,
        showPvPIcon = false,
        levelFont = "AAA_ITC_Avant_Garde",
        levelFontSize = 11,
        levelFontOutline = "OUTLINE",
        levelColor = { r = 1, g = 0.82, b = 0.20, a = 1 },
        levelX = 2,
        levelY = 2,
        showPortrait = false,
        castbarOpacity = 1.0,
        castbarColor = nil,  -- Follows the active theme accent
        selectedFont = "AAA_ITC_Avant_Garde",
        use3DPortrait = false,
        portraitMode = "2d",
        portraitStyle = "attached",
        circularPortraitBorderUseCustomColor = false,
        circularPortraitBorderColor = nil,  -- Follows the active theme accent
        healthBarTexture = "Melli Reforged",
        healthBarOpacity = 90,
        powerBarOpacity = 100,
        darkTheme = false,
        -- NEW: separate player sub-table (migrated from shared playerTarget)
        player = {
            frameWidth = 230,
            frameScale = 100,
            healthHeight = 46,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            healthDisplay = "both",
            showBuffs = false,
            maxBuffs = 4,
            onlyPlayerDebuffs = true,
            maxDebuffs = 20,
            buffAnchor = "topleft",
            buffGrowth = "auto",
            debuffAnchor = "bottomleft",
            debuffGrowth = "auto",
            namePosition = "left",
            healthTextPosition = "right",
            leftTextContent = "name",
            rightTextContent = "both",
            leftTextSize = 14,
            leftTextX = 0,
            leftTextY = 0,
            rightTextSize = 14,
            rightTextX = 0,
            rightTextY = 0,
            leftTextClassColor = false,
            rightTextClassColor = false,
            centerTextContent = "none",
            centerTextSize = 14,
            centerTextX = 0,
            centerTextY = 0,
            centerTextClassColor = false,
            bottomTextBar = false,
            bottomTextBarHeight = 16,
            btbPosition = "bottom",
            btbWidth = 0,
            btbX = 0,
            btbY = 0,
            btbBgColor = { r = 0.2, g = 0.2, b = 0.2 },
            btbBgOpacity = 1.0,
            btbLeftContent = "none",
            btbLeftSize = 13,
            btbLeftX = 0,
            btbLeftY = 0,
            btbLeftClassColor = false,
            btbLeftPowerColor = false,
            btbRightContent = "none",
            btbRightSize = 13,
            btbRightX = 0,
            btbRightY = 0,
            btbRightClassColor = false,
            btbRightPowerColor = false,
            btbCenterContent = "none",
            btbCenterSize = 13,
            btbCenterX = 0,
            btbCenterY = 0,
            btbCenterClassColor = false,
            btbCenterPowerColor = false,
            btbClassIcon = "none",
            btbClassIconSize = 14,
            btbClassIconLocation = "left",
            btbClassIconX = 0,
            btbClassIconY = 0,
            showPortrait = false,
            portraitMode = "2d",
            classThemeStyle = "modern",
            portraitFacing = "normal",
            portraitSide = "left",
            portraitSize = 0,
            portraitX = 0,
            portraitY = 0,
            detachedPortraitShape = "portrait",
            detachedPortraitBorderColor = { r = 0, g = 0, b = 0 },
            detachedPortraitClassColor = true,
            detachedPortraitBorder = true,
            detachedPortraitBorderOpacity = 100,
            detachedPortraitBorderSize = 7,
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = 100,
            showPlayerAbsorb = true,
            absorbBarTexture = "Melli Dark Rough",
            absorbBarColor = { r = 0.11, g = 1.00, b = 0.62, a = 1.00 },
            showPlayerCastbar = false,
            showPlayerCastIcon = true,
            castbarHideWhenInactive = true,
            lockCastbarToFrame = true,
            playerCastbarX = 0,
            playerCastbarY = 0,
            playerCastbarWidth = 0,
            playerCastbarHeight = 0,
            castSpellNameSize = 13,
            castSpellNameColor = { r = 1, g = 1, b = 1 },
            castDurationSize = 13,
            castDurationColor = { r = 1, g = 1, b = 1 },
            castbarFillColor = nil, -- Follows the active theme accent when no custom color is set
            castbarClassColored = true,
            showClassPowerBar = false,
            lockClassPowerToFrame = true,
            classPowerStyle = "none",
            classPowerPosition = "top",
            classPowerBarX = 0,
            classPowerBarY = 0,
            classPowerSize = 8,
            classPowerSpacing = 2,
            classPowerClassColor = true,
            classPowerCustomColor = { r = 1, g = 0.82, b = 0 },
            classPowerBgColor = { r = 0.082, g = 0.082, b = 0.082, a = 1.0 },
            classPowerEmptyColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            textSize = 14,
            combatIndicatorStyle = "standard",
            combatIndicatorColor = "custom",
            combatIndicatorCustomColor = { r = 1, g = 1, b = 1 },
            combatIndicatorPosition = "healthbar",
            combatIndicatorSize = 22,
            combatIndicatorX = 0,
            combatIndicatorY = 0,
            showRestingStatus = false,
            showInRaid = true,
            showInParty = true,
            showSolo = true,
        },
        -- NEW: separate target sub-table (migrated from shared playerTarget)
        target = {
            frameWidth = 230,
            frameScale = 100,
            healthHeight = 46,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            castbarHeight = 14,
            showCastbar = true,
            showCastIcon = true,
            castbarHideWhenInactive = true,
            castSpellNameSize = 13,
            castSpellNameColor = { r = 1, g = 1, b = 1 },
            castDurationSize = 13,
            castDurationColor = { r = 1, g = 1, b = 1 },
            castbarFillColor = { r = 1, g = 0.82, b = 0 },
            castbarClassColored = false,
            healthDisplay = "both",
            showBuffs = true,
            showDebuffs = true,
            onlyPlayerDebuffs = false,
            portraitFacing = "flipped",
            buffAnchor = "topleft",
            buffGrowth = "auto",
            debuffAnchor = "bottomleft",
            debuffGrowth = "auto",
            maxBuffs = 20,
            maxDebuffs = 20,
            namePosition = "left",
            healthTextPosition = "right",
            leftTextContent = "name",
            rightTextContent = "both",
            leftTextSize = 14,
            leftTextX = 0,
            leftTextY = 0,
            rightTextSize = 14,
            rightTextX = 0,
            rightTextY = 0,
            leftTextClassColor = false,
            rightTextClassColor = false,
            centerTextContent = "none",
            centerTextSize = 14,
            centerTextX = 0,
            centerTextY = 0,
            centerTextClassColor = false,
            bottomTextBar = false,
            bottomTextBarHeight = 16,
            btbPosition = "bottom",
            btbWidth = 0,
            btbX = 0,
            btbY = 0,
            btbBgColor = { r = 0.2, g = 0.2, b = 0.2 },
            btbBgOpacity = 1.0,
            btbLeftContent = "none",
            btbLeftSize = 13,
            btbLeftX = 0,
            btbLeftY = 0,
            btbLeftClassColor = false,
            btbLeftPowerColor = false,
            btbRightContent = "none",
            btbRightSize = 13,
            btbRightX = 0,
            btbRightY = 0,
            btbRightClassColor = false,
            btbRightPowerColor = false,
            btbCenterContent = "none",
            btbCenterSize = 13,
            btbCenterX = 0,
            btbCenterY = 0,
            btbCenterClassColor = false,
            btbCenterPowerColor = false,
            btbClassIcon = "none",
            btbClassIconSize = 14,
            btbClassIconLocation = "left",
            btbClassIconX = 0,
            btbClassIconY = 0,
            showPortrait = false,
            portraitMode = "2d",
            classThemeStyle = "modern",
            portraitSide = "left",
            portraitSize = 0,
            portraitX = 0,
            portraitY = 0,
            detachedPortraitShape = "portrait",
            detachedPortraitBorderColor = { r = 0, g = 0, b = 0 },
            detachedPortraitClassColor = true,
            detachedPortraitBorder = true,
            detachedPortraitBorderOpacity = 100,
            detachedPortraitBorderSize = 7,
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = 100,
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            textSize = 14,
            showInRaid = true,
            showInParty = true,
            showSolo = true,
        },
        playerTarget = {
            frameWidth = 230,
            healthHeight = 46,
            powerHeight = 6,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            castbarHeight = 14,
            maxBuffs = 20,
            maxDebuffs = 20,
            healthDisplay = "both",
            showBuffs = true,
            onlyPlayerDebuffs = false,
            showPlayerAbsorb = true,
            showPlayerCastbar = false,
            showClassPowerBar = false,
            classPowerBarX = 0,
            classPowerBarY = 0,
            playerCastbarX = 0,
            playerCastbarY = 0,
            playerCastbarWidth = 0,
            playerCastbarHeight = 0,
        },
        totPet = {
            frameWidth = 101,
            healthHeight = 25,
            frameScale = 100,
            showPortrait = false,
            portraitMode = "2d",
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            textSize = 14,
            leftTextContent = "name",
            rightTextContent = "none",
            centerTextContent = "none",
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            powerPosition = "none",
        },
        pet = {
            frameWidth = 101,
            healthHeight = 25,
            frameScale = 100,
            showPortrait = false,
            portraitMode = "2d",
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            healthClassColored = true,
            textSize = 14,
            leftTextContent = "name",
            rightTextContent = "none",
            centerTextContent = "none",
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            powerPosition = "none",
        },
        focus = {
            frameWidth = 160,
            frameScale = 100,
            healthHeight = 34,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            castbarHeight = 14,
            showCastbar = true,
            showCastIcon = true,
            castbarHideWhenInactive = true,
            castSpellNameSize = 13,
            castSpellNameColor = { r = 1, g = 1, b = 1 },
            castDurationSize = 13,
            castDurationColor = { r = 1, g = 1, b = 1 },
            castbarFillColor = nil, -- Follows the active theme accent when no custom color is set
            castbarClassColored = false,
            healthDisplay = "perhp",
            leftTextContent = "name",
            rightTextContent = "perhp",
            leftTextSize = 14,
            leftTextX = 0,
            leftTextY = 0,
            rightTextSize = 14,
            rightTextX = 0,
            rightTextY = 0,
            leftTextClassColor = false,
            rightTextClassColor = false,
            centerTextContent = "none",
            centerTextSize = 14,
            centerTextX = 0,
            centerTextY = 0,
            centerTextClassColor = false,
            bottomTextBar = false,
            bottomTextBarHeight = 16,
            btbPosition = "bottom",
            btbWidth = 0,
            btbX = 0,
            btbY = 0,
            btbLeftContent = "none",
            btbLeftSize = 13,
            btbLeftX = 0,
            btbLeftY = 0,
            btbLeftClassColor = false,
            btbLeftPowerColor = false,
            btbRightContent = "none",
            btbRightSize = 13,
            btbRightX = 0,
            btbRightY = 0,
            btbRightClassColor = false,
            btbRightPowerColor = false,
            btbCenterContent = "none",
            btbCenterSize = 13,
            btbCenterX = 0,
            btbCenterY = 0,
            btbCenterClassColor = false,
            btbCenterPowerColor = false,
            btbClassIcon = "none",
            btbClassIconSize = 14,
            btbClassIconLocation = "left",
            btbClassIconX = 0,
            btbClassIconY = 0,
      showPortrait = false,
            portraitMode = "2d",
            classThemeStyle = "modern",
            portraitSide = "right",
            portraitSize = 0,
            portraitX = 0,
            portraitY = 0,
            detachedPortraitShape = "portrait",
            detachedPortraitBorderColor = { r = 0, g = 0, b = 0 },
            detachedPortraitClassColor = true,
            detachedPortraitBorder = true,
            detachedPortraitBorderOpacity = 100,
            detachedPortraitBorderSize = 7,
            btbBgColor = { r = 0.2, g = 0.2, b = 0.2 },
            btbBgOpacity = 1.0,
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = 100,
            onlyPlayerDebuffs = true,
            debuffAnchor = "bottomleft",
            debuffGrowth = "auto",
            maxDebuffs = 10,
            textSize = 14,
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            showInRaid = true,
            showInParty = true,
            showSolo = true,
        },
        boss = {
            frameWidth = 160,
            frameScale = 100,
            healthHeight = 34,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            castbarHeight = 14,
            healthDisplay = "perhp",
            showPortrait = false,
            portraitMode = "2d",
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = 100,
            textSize = 14,
            leftTextContent = "name",
            rightTextContent = "perhp",
            centerTextContent = "none",
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
        },
        enabledFrames = {
            player = true,
            target = true,
            focus = true,
            pet = true,
            targettarget = true,
            focustarget = false,
            boss = true,
        },
        positions = {
            player = { point = "CENTER", x = -300, y = -145 },
            target = { point = "CENTER", x = 280, y = -145 },
            focus = { point = "CENTER", x = -315, y = -257 },
            pet = { point = "CENTER", x = -372.5, y = -36.5 },
            targettarget = { point = "CENTER", x = 378, y = -42.5 },
            focustarget = { point = "CENTER", x = -364.5, y = -306.5 },
            boss = { point = "RIGHT", x = -326, y = 251 },
            playerCastbar = { point = "CENTER", x = 0, y = -250 },
            classPower = { point = "CENTER", x = 0, y = -220 },
        },
        bossSpacing = 60,
    }
}
local frames = {}

local function UnitFrameStrataObjectBlocked(frame)
    if not frame then
        return true
    end

    local ok, blocked = pcall(function()
        if type(frame.IsForbidden) == "function" and frame:IsForbidden() then
            return true
        end
        if type(frame.IsProtected) == "function" and frame:IsProtected() then
            return true
        end
        return false
    end)

    return not ok or blocked == true
end

local function SetUnitFrameTreeStrata(frame, seen)
    local frameType = type(frame)
    if (frameType ~= "table" and frameType ~= "userdata")
        or type(frame.SetFrameStrata) ~= "function" then
        return
    end

    seen = seen or {}
    if seen[frame] then return end
    seen[frame] = true

    -- Blizzard/secure descendants can become forbidden after another addon
    -- taints their frame tree. Never call protected methods on those objects.
    if UnitFrameStrataObjectBlocked(frame) then
        return
    end

    -- Skip portrait backdrops - they need MEDIUM strata to render above LOW frame
    if frame._isPortraitBackdrop then
        return
    end

    local ok = pcall(frame.SetFrameStrata, frame, "LOW")
    if not ok then
        return
    end

    if type(frame.GetChildren) == "function" then
        local childrenOK, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if childrenOK and children then
            for _, child in ipairs(children) do
                SetUnitFrameTreeStrata(child, seen)
            end
        end
    end
end
local function RefreshUnitFrameStrata()
    local seen = {}
    for key, frame in pairs(frames) do
        local frameType = type(frame)
        if type(key) == "string"
            and (frameType == "table" or frameType == "userdata")
            and type(frame.SetFrameStrata) == "function"
        then
            SetUnitFrameTreeStrata(frame, seen)
        end
    end
end

Compat.fontPaths = Compat.fontPaths or {
    ["AAA_ITC_Avant_Garde"] = KT.FONT_PATH,
    ["Avant Garde"] = KT.FONT_PATH,
    ["Expressway"] = KT.FONT_PATH,
    ["Aldo PC"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Aldo PC.ttf",
    ["Capture it"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Captureit.ttf",
    ["Duepuntozero"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\duepuntozero.ttf",
    ["Emblem"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Emblem.ttf",
    ["PF Ronda Seven"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\pf_ronda_seven.ttf",
    ["PF Ronda Seven Bold"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\pf_ronda_seven_bold.ttf",
    ["Planet Kosmos"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\PLANE___.TTF",
    ["SF New Republic"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\SF New Republic.ttf",
    ["Swansea Bold"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\SWANSE_B.TTF",
    ["Swansea"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\SWANSE__.TTF",
    ["Tempesta Seven"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Tempesta Seven Condensed.ttf",
}

Compat.LOCALE_FONT_FALLBACK = Compat.LOCALE_FONT_FALLBACK
    or ((GetLocale() == "koKR" or GetLocale() == "zhCN" or GetLocale() == "zhTW" or GetLocale() == "ruRU") and STANDARD_TEXT_FONT)
    or nil

if not Compat.GetFontPath then
    function Compat.GetFontPath(unitKey)
        local settings = db and db.profile and unitKey and db.profile[unitKey]
        local name = settings and settings.selectedFont
        local path = Compat.fontPaths[name]
        if not path and name then
            local LSM = LibStub("LibSharedMedia-3.0", true)
            path = LSM and LSM:Fetch("font", name, true)
        end
        return path or KT.FONT_PATH
    end
end

if not Compat.GetFontOutlineFlag then
    function Compat.GetFontOutlineFlag()
        return "OUTLINE"
    end
end

if not Compat.GetFontUseShadow then
    function Compat.GetFontUseShadow()
        return false
    end
end

if not PP.Scale then
    function PP.Scale(value)
        local scale = UIParent and UIParent:GetEffectiveScale() or 1
        return math.floor((value or 0) * scale + 0.5) / scale
    end

    function PP.Point(frame, point, relativeTo, relativePoint, x, y)
        frame:SetPoint(point, relativeTo, relativePoint, PP.Scale(x or 0), PP.Scale(y or 0))
    end

    function PP.Size(frame, width, height)
        frame:SetSize(PP.Scale(width or 0), PP.Scale(height or 0))
    end

    function PP.Width(frame, width)
        frame:SetWidth(PP.Scale(width or 0))
    end

    function PP.Height(frame, height)
        frame:SetHeight(PP.Scale(height or 0))
    end

    function PP.DisablePixelSnap(tex)
        if tex and tex.SetSnapToPixelGrid then
            tex:SetSnapToPixelGrid(false)
            tex:SetTexelSnappingBias(0)
        end
    end

    function PP.CreateBorder(frame, r, g, b, a, size, layer, sublevel)
        size = math.max(1, math.floor(size or 1))
        layer = layer or "OVERLAY"
        sublevel = sublevel or 0
        frame._ppBorders = frame._ppBorders or {}
        frame._ppBorderSize = size
        frame._ppBorderColor = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }

        if #frame._ppBorders == 0 then
            for i = 1, 4 do
                frame._ppBorders[i] = frame:CreateTexture(nil, layer, nil, sublevel)
            end
        end

        local edges = frame._ppBorders
        edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size)
        edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", size, size)
        edges[1]:SetHeight(size)

        edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -size, -size)
        edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
        edges[2]:SetHeight(size)

        edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size)
        edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -size, -size)
        edges[3]:SetWidth(size)

        edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", size, size)
        edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
        edges[4]:SetWidth(size)

        for i = 1, 4 do
            edges[i]:SetColorTexture(frame._ppBorderColor.r, frame._ppBorderColor.g, frame._ppBorderColor.b, frame._ppBorderColor.a)
            edges[i]:Show()
        end
    end

    function PP.SetBorderSize(frame, size)
        if frame and frame._ppBorderColor then
            PP.CreateBorder(frame, frame._ppBorderColor.r, frame._ppBorderColor.g, frame._ppBorderColor.b, frame._ppBorderColor.a, size)
        end
    end

    function PP.SetBorderColor(frame, r, g, b, a)
        if frame and frame._ppBorders then
            frame._ppBorderColor = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }
            for i = 1, #frame._ppBorders do
                frame._ppBorders[i]:SetColorTexture(frame._ppBorderColor.r, frame._ppBorderColor.g, frame._ppBorderColor.b, frame._ppBorderColor.a)
            end
        end
    end

    function PP.UpdateBorder(frame, size, r, g, b, a)
        PP.CreateBorder(frame, r, g, b, a, size)
    end
end

if not Compat.AppendSharedMediaTextures then
    function Compat.AppendSharedMediaTextures(textureNames, textureOrder, _, textureMap)
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if not LSM then return end
        local list = LSM:List("statusbar")
        if not list then return end
        for i = 1, #list do
            local name = list[i]
            if not textureMap[name] then
                textureMap[name] = LSM:Fetch("statusbar", name)
                textureNames[name] = name
                textureOrder[#textureOrder + 1] = name
            end
        end
    end
end

if not Compat.ApplyColorsToOUF then
    function Compat.ApplyColorsToOUF()
        if oUF and oUF.colors and CUSTOM_CLASS_COLORS then
            oUF.colors.class = CUSTOM_CLASS_COLORS
        end
    end
end

Compat.resourceState = Compat.resourceState or { maelstrom = 0, maelstromMax = 10, tip = 0, tipMax = 3, whirlwind = 0, whirlwindMax = 4 }

if not Compat.CopyDefaults then
    function Compat.CopyDefaults(dst, src)
        if type(dst) ~= "table" or type(src) ~= "table" then return dst end
        for key, value in pairs(src) do
            if dst[key] == nil then
                if type(value) == "table" then
                    dst[key] = {}
                    Compat.CopyDefaults(dst[key], value)
                else
                    dst[key] = value
                end
            elseif type(dst[key]) == "table" and type(value) == "table" then
                Compat.CopyDefaults(dst[key], value)
            end
        end
        return dst
    end
end

if not Compat.GetMaelstromWeapon then
    function Compat.GetMaelstromWeapon()
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(344179)
        local aura = name and AuraUtil and AuraUtil.FindAuraByName(name, "player", "HELPFUL")
        Compat.resourceState.maelstrom = aura and (aura.applications or aura.charges or 0) or 0
        return Compat.resourceState.maelstrom, Compat.resourceState.maelstromMax
    end
end

if not Compat.GetTipOfTheSpear then
    function Compat.GetTipOfTheSpear()
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(260286)
        local aura = name and AuraUtil and AuraUtil.FindAuraByName(name, "player", "HELPFUL")
        Compat.resourceState.tip = aura and (aura.applications or aura.charges or 0) or Compat.resourceState.tip or 0
        return Compat.resourceState.tip, Compat.resourceState.tipMax
    end
end

if not Compat.GetWhirlwindStacks then
    function Compat.GetWhirlwindStacks()
        return Compat.resourceState.whirlwind or 0, Compat.resourceState.whirlwindMax
    end
end

if not Compat.HandleTipOfTheSpear then
    function Compat.HandleTipOfTheSpear(event)
        if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
            Compat.resourceState.tip = 0
        else
            Compat.GetTipOfTheSpear()
        end
    end
end

if not Compat.HandleWhirlwindStacks then
    function Compat.HandleWhirlwindStacks(event, unit, _, spellID)
        if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_REGEN_ENABLED" then
            Compat.resourceState.whirlwind = 0
            return
        end
        if unit ~= "player" then return end
        if spellID == 1680 then
            Compat.resourceState.whirlwind = Compat.resourceState.whirlwindMax
        elseif Compat.resourceState.whirlwind and Compat.resourceState.whirlwind > 0 then
            Compat.resourceState.whirlwind = Compat.resourceState.whirlwind - 1
        end
    end
end

local function GetThemeAccentColor()
    if KT and KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        if r and g and b then
            return { r = r, g = g, b = b, a = 1 }
        end
    end

    local palette = KT and KT.GetStylePalette and KT:GetStylePalette()
    local accent = palette and palette.accent
    if accent then
        return {
            r = accent.r or 1,
            g = accent.g or 0,
            b = accent.b or 0.333,
            a = accent.a or 1,
        }
    end

    return { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.333, a = 1 }
end

local function GetCastbarColor()
    if db and db.profile and db.profile.castbarColor then
        return db.profile.castbarColor
    end
    return GetThemeAccentColor()
end
local MANA_COLOR = { r = 0.204, g = 0.349, b = 0.851 }

local function ResolveSafeClassToken(unit)
    local _, classToken
    if KT.SafeUnitClass then
        _, classToken = KT.SafeUnitClass(unit)
    else
        _, classToken = UnitClass(unit)
    end
    if classToken and KT.IsSecret and KT.IsSecret(classToken) then
        return nil
    end
    return classToken
end

local function ResolveCastbarFillColor(unit, settings)
    local fallback = GetCastbarColor()

    if settings and settings.castbarClassColored and unit and UnitExists(unit) then
        local classToken = ResolveSafeClassToken(unit)
        if classToken and RAID_CLASS_COLORS[classToken] then
            return RAID_CLASS_COLORS[classToken]
        end
    end

    if settings and settings.castbarFillColor then
        return settings.castbarFillColor
    end

    return fallback
end

local SOLID_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8" }

-- ─── Subsistema de resolución de fuentes ─────────────────────────
-- Gestiona la ruta de fuente global y per-unit con invalidación.
-- LOCALE_FONT_OVERRIDE fuerza una fuente del sistema para CJK/Cyrillic.
-- Resolve() regenera la caché; Get() la consume sin recalcular.
local LOCALE_FONT_OVERRIDE = Compat and Compat.LOCALE_FONT_FALLBACK
local DEFAULT_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local FONT_UNIT_KEYS = { "player", "target", "focus", "boss", "pet", "totPet" }

local fontCache = {
    global = LOCALE_FONT_OVERRIDE
        or (Compat and Compat.GetFontPath and Compat.GetFontPath("unitFrames"))
        or DEFAULT_FONT,
    perUnit = {},
}

local function ResolveFontPath()
    -- Locale override tiene prioridad absoluta: no hay fuente custom que
    -- renderice CJK/Cyrillic correctamente.
    local base = LOCALE_FONT_OVERRIDE
        or (Compat and Compat.GetFontPath and Compat.GetFontPath("player"))
        or DEFAULT_FONT
    fontCache.global = base
    for _, uKey in ipairs(FONT_UNIT_KEYS) do
        fontCache.perUnit[uKey] = LOCALE_FONT_OVERRIDE
            or (Compat and Compat.GetFontPath and Compat.GetFontPath(uKey))
            or base
    end
end

local function GetSelectedFont(unitKey)
    return (unitKey and fontCache.perUnit[unitKey]) or fontCache.global
end

local function GetUFUseShadow()
    return not Compat or not Compat.GetFontUseShadow or Compat.GetFontUseShadow()
end

local function SetFSFont(fs, size, flags)
  if not (fs and fs.SetFont) then return end
  local f = flags or (Compat and Compat.GetFontOutlineFlag and Compat.GetFontOutlineFlag()) or ""
  local fontPath = GetSelectedFont()
  fs:SetFont(fontPath, size or 12, f)
  if KT and KT.EnableTextFontFallback then
    KT:EnableTextFontFallback(fs, fontPath)
  end
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.9)
end

local function ApplyForeverLevelTextStyle(text, profile, frame)
    if not (text and text.SetFont) then return end
    profile = profile or {}
    local fontName = profile.levelFont or "AAA_ITC_Avant_Garde"
    local fontPath = Compat.fontPaths and Compat.fontPaths[fontName]
    if not fontPath then
        local lsm = LibStub("LibSharedMedia-3.0", true)
        fontPath = lsm and lsm:Fetch("font", fontName, true)
    end
    fontPath = fontPath or DEFAULT_FONT
    local size = math.max(6, math.min(48, tonumber(profile.levelFontSize) or 11))
    local outline = profile.levelFontOutline
    if outline == "NONE" then outline = "" end
    if type(outline) ~= "string" then outline = "OUTLINE" end
    text:SetFont(fontPath, size, outline)
    if KT and KT.EnableTextFontFallback then KT:EnableTextFontFallback(text, fontPath) end
    local color = profile.levelColor or { r = 1, g = 0.82, b = 0.20, a = 1 }
    text:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    if frame then
        text:ClearAllPoints()
        text:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", tonumber(profile.levelX) or 2, tonumber(profile.levelY) or 2)
    end
end

-- Disable WoW's automatic pixel snapping on a texture (prevents sub-pixel jitter)
local function UnsnapTex(tex)
    local PP = Compat and Compat.PP
    if PP then PP.DisablePixelSnap(tex)
    elseif tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0) end
end

-- Health bar texture overlay lookup
local TEXTURE_BASE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\textures\\"
local healthBarTextures = {
    ["none"]          = nil,
    ["Melli Reforged"] = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga",
    ["Melli"]         = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga",
    ["Melli Dark"]    = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
    ["Melli Dark Rough"] = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
    ["beautiful"]     = TEXTURE_BASE .. "beautiful.tga",
    ["plating"]       = TEXTURE_BASE .. "plating.tga",
    ["atrocity"]      = TEXTURE_BASE .. "atrocity.tga",
    ["divide"]        = TEXTURE_BASE .. "divide.tga",
    ["glass"]         = TEXTURE_BASE .. "glass.tga",
    ["gradient-lr"]   = TEXTURE_BASE .. "gradient-lr.tga",
    ["gradient-rl"]   = TEXTURE_BASE .. "gradient-rl.tga",
    ["gradient-bt"]   = TEXTURE_BASE .. "gradient-bt.tga",
    ["gradient-tb"]   = TEXTURE_BASE .. "gradient-tb.tga",
    ["matte"]         = TEXTURE_BASE .. "matte.tga",
    ["sheer"]         = TEXTURE_BASE .. "sheer.tga",
}
local healthBarTextureOrder = {
    "none", "Melli Reforged", "Melli", "Melli Dark", "Melli Dark Rough", "beautiful", "plating",
    "atrocity", "divide", "glass",
    "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
    "matte", "sheer",
}
local healthBarTextureNames = {
    ["none"]        = "None",
    ["Melli Reforged"] = "Melli Reforged",
    ["Melli"]       = "Melli",
    ["Melli Dark"]  = "Melli Dark",
    ["Melli Dark Rough"] = "Melli Dark Rough",
    ["beautiful"]   = "Beautiful",
    ["plating"]     = "Plating",
    ["atrocity"]    = "Atrocity",
    ["divide"]      = "Divide",
    ["glass"]       = "Glass",
    ["gradient-lr"] = "Gradient Right",
    ["gradient-rl"] = "Gradient Left",
    ["gradient-bt"] = "Gradient Up",
    ["gradient-tb"] = "Gradient Down",
    ["matte"]       = "Matte",
    ["sheer"]       = "Sheer",
}
ns.healthBarTextures = healthBarTextures
ns.healthBarTextureOrder = healthBarTextureOrder
ns.healthBarTextureNames = healthBarTextureNames

local DEFAULT_ABSORB_TEXTURE = "Melli Dark Rough"
local DEFAULT_ABSORB_COLOR = { r = 0.11, g = 1.00, b = 0.62, a = 1.00 }

local function ResolveSharedTexturePath(textureKey, fallbackKey)
    if textureKey == "none" then
        return nil
    end
    local path = healthBarTextures[textureKey]
    if path then
        return path
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    path = LSM and LSM:Fetch("statusbar", textureKey, true)
    if path then
        healthBarTextures[textureKey] = path
        return path
    end
    return healthBarTextures[fallbackKey]
end

local function ResolveAbsorbBarColor(settings)
    local color = settings and settings.absorbBarColor
    return
        (color and (color.r or color[1])) or DEFAULT_ABSORB_COLOR.r,
        (color and (color.g or color[2])) or DEFAULT_ABSORB_COLOR.g,
        (color and (color.b or color[3])) or DEFAULT_ABSORB_COLOR.b,
        (color and (color.a or color[4])) or DEFAULT_ABSORB_COLOR.a
end

local function ResolvePortraitClassToken(unit)
    local classToken = ResolveSafeClassToken(unit)
    if classToken then
        return classToken
    end
    return nil
end

local function ResolveActivePortraitMode(unit, settings)
    local mode = (settings and settings.portraitMode) or (db and db.profile and db.profile.portraitMode) or "2d"
    if mode == "3d" and db and db.profile and db.profile.portraitStyle == "circular" then
        return "2d"
    end
    if mode == "class" and not ResolvePortraitClassToken(unit) then
        -- Pets and non-player units do not always expose a class token.
        -- Fall back to the regular portrait so the slot never renders blank.
        return "2d"
    end
    return mode
end

-- ─── Subsistema de contexto de unidad ─────────────────────────────
-- Centraliza la resolución unitID → clave de perfil → tabla de settings.
-- Arquitectura: mapa estático pre-poblado en lugar de pattern matching o
-- lazy-init separados.  Cache invalidable desde ReloadFrames.
ns._UnitCtx = ns._UnitCtx or {}
local UCtx = ns._UnitCtx

-- Claves fijas: unidades especiales que no coinciden con su nombre en db.profile
local UNIT_KEY_FIXED = {
    targettarget = "totPet",
    focustarget  = "totPet",
    pet          = "pet",
}
for i = 1, 5 do UNIT_KEY_FIXED["boss" .. i] = "boss" end

-- Unidades con clave idéntica a su unitID en db.profile
local UNIT_KEY_IDENTITY = { player = true, target = true, focus = true }

-- Resolución de clave: determinístico por tabla, sin regex
function UCtx.ResolveKey(unit)
    if not unit then return nil end
    local fk = UNIT_KEY_FIXED[unit]
    if fk then return fk end
    if UNIT_KEY_IDENTITY[unit] and db.profile[unit] then return unit end
    if db.profile[unit] then return unit end
    return nil
end

-- Cache de settings: se puebla en primer acceso, se invalida con Invalidate()
local _settingsCache
function UCtx.ResolveSettings(unit)
    if not _settingsCache then
        _settingsCache = {}
        for uid, key in pairs(UNIT_KEY_FIXED) do
            _settingsCache[uid] = db.profile[key]
        end
        for uid in pairs(UNIT_KEY_IDENTITY) do
            if db.profile[uid] then
                _settingsCache[uid] = db.profile[uid]
            end
        end
    end
    return _settingsCache[unit] or db.profile.player
end

-- Donante para mini frames: cascada focus → target → player
function UCtx.ResolveMiniDonor()
    local ef = db.profile.enabledFrames
    if ef.focus ~= false and db.profile.focus then return db.profile.focus end
    if ef.target ~= false and db.profile.target then return db.profile.target end
    return db.profile.player
end

function UCtx.Invalidate()
    _settingsCache = nil
end

-- Aliases compatibles: mantienen la firma original para todos los call sites
local function UnitToSettingsKey(unit) return UCtx.ResolveKey(unit) end
local function GetSettingsForUnit(unit) return UCtx.ResolveSettings(unit) end
local function GetMiniDonorSettings() return UCtx.ResolveMiniDonor() end

local function ApplyHealthBarTexture(health, unitKey)
    if not health then return end
    local s = unitKey and db.profile[unitKey]
    local texKey = (s and s.healthBarTexture) or db.profile.healthBarTexture or "none"
    local path   = ResolveSharedTexturePath(texKey, "Melli Reforged")
    local bgPath = healthBarTextures["Melli Dark"]

    -- Apply texture directly to the StatusBar fill
    if path then
        health:SetStatusBarTexture(path)
    else
        health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    end
    local hFill = health:GetStatusBarTexture()
    if hFill then UnsnapTex(hFill) end
    if health.bg and bgPath then
        health.bg:SetTexture(bgPath)
        health.bg:SetVertexColor(1, 1, 1, 1)
    end

    -- Power bar: same texture
    local frame = health:GetParent()
    local power = frame and frame.Power
    if power then
        if path then
            power:SetStatusBarTexture(path)
        else
            power:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        end
        local pFill = power:GetStatusBarTexture()
        if pFill then UnsnapTex(pFill) end
        if power.bg and bgPath then
            power.bg:SetTexture(bgPath)
            power.bg:SetVertexColor(1, 1, 1, 1)
        end
    end
end

-------------------------------------------------------------------------------
--  Bar Fill Opacity — aplica alfa al fill y background de una StatusBar.
--  Unifica la lógica idéntica de health y power en un solo aplicador
--  parametrizado por clave de opacidad.
-------------------------------------------------------------------------------
local function ApplyBarFillAlpha(bar, unitKey, opacityKey, defaultVal)
    if not bar then return end
    local s = unitKey and db.profile[unitKey]
    local opacity = s and (s[opacityKey] or defaultVal) or defaultVal
    -- Retrocompatibilidad: perfiles antiguos guardaban 0-1 float en vez de 0-100
    if opacity <= 1.0 then opacity = opacity * 100 end
    local fillA = opacity / 100
    local fillTex = bar:GetStatusBarTexture()
    if fillTex then fillTex:SetAlpha(fillA) end
    if bar.bg then bar.bg:SetAlpha(fillA) end
end

-- Wrappers con firma legada para mantener las call-sites existentes
local function ApplyHealthBarAlpha(health, unitKey)
    ApplyBarFillAlpha(health, unitKey, "healthBarOpacity", 90)
end
local function ApplyPowerBarAlpha(power, unitKey)
    ApplyBarFillAlpha(power, unitKey, "powerBarOpacity", 100)
end

-------------------------------------------------------------------------------
--  Dark Mode ? flat dark health bar with gray background
-------------------------------------------------------------------------------
local DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B = 0x11/255, 0x11/255, 0x11/255  -- #111111
local DARK_HEALTH_A = 1.0
local DARK_BG_R, DARK_BG_G, DARK_BG_B = 0x4f/255, 0x4f/255, 0x4f/255  -- #4f4f4f

local function ApplyDarkTheme(health)
    if not health then return end
    local isDark = db and db.profile and db.profile.darkTheme
    if isDark then
        health.colorClass = false
        health.colorReaction = false
        health.colorTapped = false
        health.colorDisconnected = false
        health:SetStatusBarColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, DARK_HEALTH_A)
        local darkFillTex = health:GetStatusBarTexture()
        if darkFillTex then darkFillTex:SetAlpha(0.9) end
        if health.bg then
            -- Anchor bg to only cover the empty (missing-health) portion so the
            -- bar opacity fill shows the world behind it, not the bg color.
            health.bg:ClearAllPoints()
            health.bg:SetPoint("TOPLEFT", health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
            health.bg:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
            health.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
            health.bg:SetVertexColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 1)
            health.bg:SetAlpha(1)
        end
        -- PostUpdateColor: re-apply dark color after oUF tries to class-color,
        -- and re-anchor bg to track the fill edge.
        -- Alpha is NOT re-applied here ? SetStatusBarColor(r,g,b) with 3 args
        -- preserves existing texture alpha, so the alpha set by
        -- ApplyHealthBarAlpha persists through oUF recolors.
        health.PostUpdateColor = function(self)
            self:SetStatusBarColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, DARK_HEALTH_A)
            if self.bg then
                self.bg:ClearAllPoints()
                self.bg:SetPoint("TOPLEFT", self:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
                self.bg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
                self.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
            end
        end
    else
        health.colorClass = true
        health.colorReaction = true
        health.colorTapped = true
        health.colorDisconnected = true
        -- Check for custom fill/bg colors on this unit
        local unitKey = health._kuiUnitKey
        local unitSettings = unitKey and db.profile[unitKey]
        local customFill = unitSettings and unitSettings.customFillColor
        local customBg   = unitSettings and unitSettings.customBgColor
        if customFill then
            -- Custom fill overrides class coloring; skip if class color is enabled
            if not (unitSettings and unitSettings.healthClassColored) then
                health.colorClass = false
                health.colorReaction = false
                health.colorTapped = false
                health.colorDisconnected = false
                health:SetStatusBarColor(customFill.r, customFill.g, customFill.b)
            end
        end
        -- Tint bg to 20% of the class/reaction color, or use custom bg color.
        -- Alpha is NOT re-applied ? SetStatusBarColor(r,g,b) preserves
        -- existing texture alpha through oUF recolors.
        health.PostUpdateColor = function(self, unit, color)
            local uKey = self._kuiUnitKey
            local uSettings = uKey and db.profile[uKey]
            local cFill = uSettings and uSettings.customFillColor
            local cBg   = uSettings and uSettings.customBgColor
            local classColored = uSettings and uSettings.healthClassColored
            if uKey == "pet" and classColored then
                local _, cls = UnitClass("player")
                local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
                local c = cls and colors and colors[cls]
                if c then
                    self:SetStatusBarColor(c.r, c.g, c.b)
                    if self.bg then
                        self.bg:SetVertexColor(c.r * 0.2, c.g * 0.2, c.b * 0.2, 1)
                    end
                    return
                end
            end
            if cFill and not classColored then
                self:SetStatusBarColor(cFill.r, cFill.g, cFill.b)
            end
            if self.bg then
                self.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                if cBg then
                    self.bg:SetVertexColor(cBg.r, cBg.g, cBg.b, 1)
                elseif cFill and not classColored then
                    self.bg:SetVertexColor(cFill.r * 0.2, cFill.g * 0.2, cFill.b * 0.2, 1)
                elseif unit then
                    local _, rawClass = UnitClass(unit)
                    if issecretvalue and issecretvalue(rawClass) then
                        -- The fill can consume Blizzard's protected RGB
                        -- directly, but the darkened background cannot perform
                        -- arithmetic on it. Keep a neutral background here.
                        self.bg:SetVertexColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, 1)
                    elseif color and color.GetRGB then
                        local r, g, b = color:GetRGB()
                        self.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 1)
                    else
                        self.bg:SetVertexColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, 1)
                    end
                elseif color and color.GetRGB then
                    local r, g, b = color:GetRGB()
                    self.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 1)
                else
                    -- No color source available (e.g. no target) -- use default bg
                    self.bg:SetVertexColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, 1)
                end
            end
        end
        if health.bg then
            -- Restore bg to cover the full bar area
            health.bg:ClearAllPoints()
            PP.Point(health.bg, "TOPLEFT", health, "TOPLEFT", 0, 0)
            PP.Point(health.bg, "BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
            if customBg then
                health.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                health.bg:SetVertexColor(customBg.r, customBg.g, customBg.b, 1)
            elseif customFill then
                health.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                health.bg:SetVertexColor(customFill.r * 0.2, customFill.g * 0.2, customFill.b * 0.2, 1)
            else
                -- No custom colors set -- use default dark bg (#111)
                health.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                health.bg:SetVertexColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, 1)
            end
        end
    end
end
ns.ApplyDarkTheme = ApplyDarkTheme

-- Smart power text: percent for mana-centric specs, raw values for the rest.
-- Shared by both oUF tags and the resource bar renderer.
local SMART_POWER_PERCENT_TAG = "kui-powpct"
local SMART_POWER_CURRENT_TAG = "kui-powcur"
local SMART_POWER_TAG_EVENTS = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER"

local function ShouldUseSmartPowerPercent()
    local _, cls = UnitClass("player")
    if not cls then return false end
    if cls == "DRUID" then
        local form = GetShapeshiftForm()
        return form == nil or form == 0 or form == 3
    end
    if cls == "PRIEST" or cls == "SHAMAN" or cls == "MONK" then
        return true
    end
    -- Paladin: only Holy
    if cls == "PALADIN" then
        local spec = GetSpecialization()
        return spec == 1  -- Holy
    end
    -- Mage: only Arcane
    if cls == "MAGE" then
        local spec = GetSpecialization()
        return spec == 1  -- Arcane
    end
    -- Evoker: only Preservation
    if cls == "EVOKER" then
        local spec = GetSpecialization()
        return spec == 2  -- Preservation
    end
    return false
end
ns.ShouldUseSmartPowerPercent = ShouldUseSmartPowerPercent
Compat.IsSmartPowerPercent = ShouldUseSmartPowerPercent

-- Health text helpers (safe vs "secret" taint)
local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function SafeBoolCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then return nil end
    return value == true
end
local function SafeToString(v)
    if IsSecret(v) then return "<secret>" end
    local ok, s = pcall(tostring, v)
    if not ok or s == nil then return "<tostring error>" end
    if IsSecret(s) then return "<secret>" end
    return s
end

local function DebugHP(unit, data)
    if not _G.KUI_UF_HPDEBUG then return end
    _G.KUI_UF_HPDEBUG_LOG = _G.KUI_UF_HPDEBUG_LOG or {}
    _G.KUI_UF_HPDEBUG_LAST = _G.KUI_UF_HPDEBUG_LAST or {}
    local now = GetTime and GetTime() or 0
    local last = _G.KUI_UF_HPDEBUG_LAST[unit] or 0
    if now - last < 0.5 then return end
    _G.KUI_UF_HPDEBUG_LAST[unit] = now

    local line = string.format("|cff00ffff[ktufhpdebug]|r %s", data)
    local log = _G.KUI_UF_HPDEBUG_LOG
    log[#log + 1] = line
    if #log > 200 then table.remove(log, 1) end
    UFHPPrint(line)
end

local function UFHPPrint(msg)
    msg = SafeToString(msg)
    if KT and KT.Print then
        KT:Print(msg)
    elseif _G.DEFAULT_CHAT_FRAME then
        _G.DEFAULT_CHAT_FRAME:AddMessage(msg)
    else
        print(msg)
    end
    if _G.UIErrorsFrame and _G.UIErrorsFrame.AddMessage then
        _G.UIErrorsFrame:AddMessage(msg, 0.2, 1.0, 1.0)
    end
    if _G.RaidNotice_AddMessage and _G.RaidWarningFrame then
        _G.RaidNotice_AddMessage(_G.RaidWarningFrame, msg, _G.ChatTypeInfo and _G.ChatTypeInfo["RAID_WARNING"] or nil)
    end
end

local FormatShortValue

local function RegisterUFHPDebugSlash()
    _G.SLASH_KTUFHPDEBUG1 = "/ktufhpdebug"
    _G.SLASH_KTUFHPDEBUG2 = "/ktufhpdbg"
    SlashCmdList["KTUFHPDEBUG"] = function(msg)
        msg = msg and msg:lower() or ""
        if msg == "state" then
            local prof = db and db.profile
            local s = prof and prof.player
            UFHPPrint(string.format(
                "|cff00ffff[ktufhpdebug]|r db.player healthDisplay=%s left=%s right=%s center=%s",
                SafeToString(s and s.healthDisplay),
                SafeToString(s and s.leftTextContent),
                SafeToString(s and s.rightTextContent),
                SafeToString(s and s.centerTextContent)
            ))
            if frames and frames.player then
                local f = frames.player
                UFHPPrint(string.format(
                    "|cff00ffff[ktufhpdebug]|r tag left=%s right=%s center=%s",
                    SafeToString(f.LeftText and f.LeftText._curTag),
                    SafeToString(f.RightText and f.RightText._curTag),
                    SafeToString(f.CenterText and f.CenterText._curTag)
                ))
            end
            UFHPPrint(string.format(
                "|cff00ffff[ktufhpdebug]|r curhp=%s short=%s perhp=%s",
                SafeToString(UnitHealth("player")),
                SafeToString(FormatShortValue(UnitHealth("player"))),
                SafeToString(UnitHealthPercent and UnitHealthPercent("player", true, CurveConstants.ScaleTo100) or "nil")
            ))
            return
        end
        if msg == "dump" then
            local log = _G.KUI_UF_HPDEBUG_LOG or {}
            for i = math.max(1, #log - 50), #log do
                UFHPPrint(log[i])
            end
            return
        elseif msg == "clear" then
            _G.KUI_UF_HPDEBUG_LOG = {}
            UFHPPrint("|cff00ffff[ktufhpdebug]|r log cleared.")
            return
        end
        _G.KUI_UF_HPDEBUG = not _G.KUI_UF_HPDEBUG
        UFHPPrint("|cff00ffff[ktufhpdebug]|r " .. (_G.KUI_UF_HPDEBUG and "ENABLED" or "DISABLED"))
    end
end

RegisterUFHPDebugSlash()

local function NormalizeNumberString(s)
    if s == nil then return nil end
    if IsSecret(s) then return nil end

    local ok, t = pcall(string.gsub, s, "[,%s]", "")
    if not ok or not t or IsSecret(t) then return nil end
    local n = tonumber(t)
    if n then return n end

    ok, t = pcall(string.gsub, t, "[^%d%.%-]", "")
    if not ok or not t or IsSecret(t) then return nil end
    n = tonumber(t)
    if n then return n end

    ok, t = pcall(string.gsub, t, "%D", "")
    if not ok or not t or IsSecret(t) then return nil end
    if t == "" then return nil end
    return tonumber(t)
end

local function CoerceNumber(v)
    if type(v) == "string" then
        if IsSecret(v) then return nil end
        return NormalizeNumberString(v)
    end
    if type(v) == "number" then
        if IsSecret(v) then return nil end
        return v
    end
    return nil
end

local function ManualShort(n)
    local floor = math.floor
    if n >= 1e6 then
        local v = n / 1e6
        if v == floor(v) then return string.format("%dM", v) end
        return string.format("%.1fM", v)
    end
    if n >= 1e3 then
        local v = n / 1e3
        if v == floor(v) then return string.format("%dK", v) end
        return string.format("%.1fK", v)
    end
    return tostring(floor(n))
end

FormatShortValue = function(val)
    -- Fast path: numeric
    local n = CoerceNumber(val)
    if n then return ManualShort(n) end

    -- Secret path: only safe calls
    if IsSecret(val) then
        if AbbreviateLargeNumbers then
            local ok, res = pcall(AbbreviateLargeNumbers, val)
            if ok and res ~= nil then
                local rn = NormalizeNumberString(res)
                if rn then return ManualShort(rn) end
                return res
            end
        end
        local ok, s = pcall(tostring, val)
        if ok and s ~= nil then return s end
        return ""
    end

    -- Non-secret string path: normalize and abbreviate
    local rn = NormalizeNumberString(val)
    if rn then return ManualShort(rn) end
    return tostring(val)
end

do
  -- (helper functions moved below)
  local function LooksAbbreviated(s)
    if type(s) ~= "string" then return false end
    if s:find("[KkMmBbTt]") then return true end
    -- Any non-digit letters/symbols beyond separators implies abbreviation in locales (e.g., "mil").
    if s:find("[^%d%.,%s]") then return true end
    return false
  end

  local tagName = "curhpshort"
  local function AbbrevHP(unit)
    if not unit or not UnitExists(unit) then return "" end
    if not UnitIsConnected(unit) then return "OFFLINE" end
    if UnitIsDeadOrGhost(unit) then return "DEAD" end
    local hp = UnitHealth(unit)
    -- Normal path: non-secret values use the Blizzard abbreviator.
    if not IsSecret(hp) then
        local nHp = CoerceNumber(hp)
        if AbbreviateLargeNumbers then
            local res = AbbreviateLargeNumbers(hp)
            if IsSecret(res) then
                if nHp then return ManualShort(nHp) end
                return res
            end
            if not LooksAbbreviated(res) and nHp then
                return ManualShort(nHp)
            end
            return res
        end
        if nHp then return ManualShort(nHp) end
        return tostring(hp or "")
    end

    -- Secret path: rebuild from max + percent if possible.
    local maxHP = UnitHealthMax(unit)
    local pct = UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants.ScaleTo100) or nil
    local nMax = CoerceNumber(maxHP)
    local nPct = CoerceNumber(pct)
    if nMax and nPct then
        return ManualShort(nMax * nPct / 100)
    end

    -- Last resort: return Blizzard result without inspecting it.
    if AbbreviateLargeNumbers then
        return AbbreviateLargeNumbers(hp)
    end
    return ""
  end

  oUF.Tags.Methods[tagName] = AbbrevHP
  oUF.Tags.Events[tagName] = "UNIT_HEALTH UNIT_MAXHEALTH"
end

do
  local tagName = "deficithp"
  local function DeficitHP(unit)
    if not unit or not UnitExists(unit) then return "" end
    if not UnitIsConnected(unit) then return "OFFLINE" end
    if UnitIsDeadOrGhost(unit) then return "DEAD" end
    local hp = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)
    local nHp = CoerceNumber(hp)
    local nMax = CoerceNumber(maxHP)
    if (not nHp or not nMax) and UnitHealthPercent then
      local pct = CoerceNumber(UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
      if pct and nMax then
        nHp = nMax * pct / 100
      end
    end
    if not nHp or not nMax or nMax == 0 then return "" end
    local deficit = nMax - nHp
    if deficit <= 0 then return "" end
    return FormatShortValue(deficit)
  end

  oUF.Tags.Methods[tagName] = DeficitHP
  oUF.Tags.Events[tagName] = "UNIT_HEALTH UNIT_MAXHEALTH"
end

do
  oUF.Tags.Methods["perhpnosign"] = function(unit)
    if not unit or not UnitExists(unit) then return "" end
    if not UnitIsConnected(unit) then return "OFFLINE" end
    if UnitIsDeadOrGhost(unit) then return "DEAD" end
    local pct = UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    pct = CoerceNumber(pct)
    if pct then
      return tostring(math.floor(pct + 0.5))
    end
    local hp = CoerceNumber(UnitHealth(unit))
    local maxHP = CoerceNumber(UnitHealthMax(unit))
    if not hp or not maxHP or maxHP == 0 then return "0" end
    return tostring(math.floor(hp / maxHP * 100 + 0.5))
  end
  oUF.Tags.Events["perhpnosign"] = "UNIT_HEALTH UNIT_MAXHEALTH"
end

local POWER_PERCENT_TAG_METHOD = [[function(u)
    local pType = UnitPowerType(u)
    return string.format('%d', UnitPowerPercent(u, pType, true, CurveConstants.ScaleTo100))
end]]
oUF.Tags.Methods[SMART_POWER_PERCENT_TAG] = POWER_PERCENT_TAG_METHOD
oUF.Tags.Events[SMART_POWER_PERCENT_TAG] = SMART_POWER_TAG_EVENTS

local POWER_CURRENT_TAG_METHOD = [[function(u)
    local pType = UnitPowerType(u)
    return AbbreviateLargeNumbers(UnitPower(u, pType))
end]]
oUF.Tags.Methods[SMART_POWER_CURRENT_TAG] = POWER_CURRENT_TAG_METHOD
oUF.Tags.Events[SMART_POWER_CURRENT_TAG] = SMART_POWER_TAG_EVENTS

local optionsFrame
local optionsCategoryID
_G.KUIUF_StylesRegistered = _G.KUIUF_StylesRegistered or false

-- GetSettingsForUnit ahora es alias de UCtx.ResolveSettings (definido arriba)

local function NormalizeCombatIndicatorStyle(style)
    if style == "none" then
        return "none"
    end

    return "standard"
end

-- GetMiniDonorSettings ahora es alias de UCtx.ResolveMiniDonor (definido arriba)

-- Resolve buff anchor + growth direction into oUF aura properties
-- Returns: anchorPoint (on frame), initialAnchor, growthX, growthY, offsetX, offsetY
-- Tabla combinada: cada ancla define su initialAnchor, dirección de crecimiento
-- automático, punto de fijación al frame padre y sentido de offset.
local BUFF_LAYOUT_DATA = {
    topleft     = { ia = "BOTTOMLEFT",  ax = "RIGHT", ay = "UP",   fp = "TOPLEFT",     ox = 0,  oy = 1  },
    topright    = { ia = "BOTTOMRIGHT", ax = "LEFT",  ay = "UP",   fp = "TOPRIGHT",    ox = 0,  oy = 1  },
    bottomleft  = { ia = "TOPLEFT",     ax = "RIGHT", ay = "DOWN", fp = "BOTTOMLEFT",  ox = 0,  oy = -1 },
    bottomright = { ia = "TOPRIGHT",    ax = "LEFT",  ay = "DOWN", fp = "BOTTOMRIGHT", ox = 0,  oy = -1 },
    left        = { ia = "BOTTOMRIGHT", ax = "LEFT",  ay = "DOWN", fp = "LEFT",        ox = -1, oy = 0  },
    right       = { ia = "BOTTOMLEFT",  ax = "RIGHT", ay = "DOWN", fp = "RIGHT",       ox = 1,  oy = 0  },
}
-- Mapeo de growth explícito → (gx, gy)
local GROWTH_OVERRIDES = {
    right = { "RIGHT", "UP"   },
    left  = { "LEFT",  "UP"   },
    up    = { "RIGHT", "UP"   },
    down  = { "RIGHT", "DOWN" },
}

local function ResolveBuffLayout(anchor, growth)
    local d = BUFF_LAYOUT_DATA[anchor or "topleft"] or BUFF_LAYOUT_DATA.topleft
    local gx, gy
    if growth and growth ~= "auto" then
        local ov = GROWTH_OVERRIDES[growth]
        gx, gy = ov and ov[1] or "RIGHT", ov and ov[2] or "UP"
    else
        gx, gy = d.ax, d.ay
    end
    return d.fp, d.ia, gx, gy, d.ox, d.oy
end

-- ─── Resolución de tags de vida ──────────────────────────────────
-- Tabla display → tag oUF (compartida por player, target, focus, boss).
-- Una sola función ResolveHealthTag reemplaza las antiguas 3 funciones
-- individuales, consultando HEALTH_TAG_CONTEXT para defaults por unidad.
local HEALTH_DISPLAY_TAGS = {
    curhpshort = "[curhpshort]",
    perhp      = "[perhp]%",
    both       = "[curhpshort] | [perhp]%",
}
local HEALTH_TAG_CONTEXT = {
    player = { key = "player", default = "both"  },
    target = { key = "target", default = "both"  },
    focus  = { key = "focus",  default = "perhp" },
    boss   = { key = "boss",   default = "perhp" },
}
local function ResolveHealthTag(unit)
    local ctx = HEALTH_TAG_CONTEXT[unit] or HEALTH_TAG_CONTEXT.player
    local tbl = db.profile[ctx.key]
    local display = (tbl and tbl.healthDisplay) or ctx.default
    return HEALTH_DISPLAY_TAGS[display] or HEALTH_DISPLAY_TAGS[ctx.default]
end

-- Resolve a leftTextContent / rightTextContent value to an oUF tag string.
-- content: "name", "both", "curhpshort", "curhp", "curhp_perhp", "perhp", "perhpnosign", "perhpnum", "deficit", "none"
local function ContentToTag(content)
    if content == "name" then return "[name]"
    elseif content == "level" then return "[level]"
    elseif content == "both" then return "[curhpshort] | [perhp]%"
    elseif content == "curhp_perhp" then return "[curhp] | [perhp]%"
    elseif content == "perhpnum" then return "[perhp]% | [curhpshort]"
    elseif content == "curhpshort" then return "[curhpshort]"
    elseif content == "curhp" then return "[curhp]"
    elseif content == "perhp" then return "[perhp]%"
    elseif content == "perhpnosign" then return "[perhpnosign]"
    elseif content == "deficit" then return "[deficithp]"
    elseif content == "perpp" then return "[perpp]%"
    elseif content == "curpp" then return "[curpp]"
    elseif content == "curhp_curpp" then return "[curhpshort] | [curpp]"
    elseif content == "perhp_perpp" then return "[perhp]% | [perpp]%"
    else return nil end
end

-- Estimate pixel width of a text content type for name truncation.
-- Flat pixel assumptions matching the nameplate system.
local UF_TEXT_PADDING = 10
local ufTextWidths = {
    level       = 28,
    both        = 75,  -- "132 K | 86%"
    curhp_perhp = 90,  -- "132000 | 86%"
    perhpnum    = 75,  -- "86% | 132 K"
    curhpshort  = 38,  -- "132 K"
    curhp       = 60,  -- "132000"
    perhp       = 38,  -- "86%"
    perhpnosign = 30,  -- "86"
    deficit     = 38,  -- "12 K"
    perpp       = 38,  -- "86%"
    curpp       = 38,  -- "132"
    curhp_curpp = 75,  -- "132 K | 132"
    perhp_perpp = 75,  -- "86% | 86%"
}
local function EstimateUFTextWidth(content)
    return (ufTextWidths[content] or 0) + UF_TEXT_PADDING
end

-- Apply class color to a FontString based on the unit
local function ApplyClassColor(fs, unit, useClassColor)
    if not fs then return end
    if useClassColor then
        local class = ResolveSafeClassToken(unit)
        if class then
            local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
            if c then fs:SetTextColor(c.r, c.g, c.b); return end
        end
    end
    fs:SetTextColor(1, 1, 1)
end

local UF_ICONS_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local BLIZZ_CLASS_ICON_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_FULL_COORDS = CLASS_ICON_TCOORDS or {
    WARRIOR     = { 0,     0.25,  0,     0.25  },
    MAGE        = { 0.25,  0.496, 0,     0.25  },
    ROGUE       = { 0.496, 0.742, 0,     0.25  },
    DRUID       = { 0.742, 0.988, 0,     0.25  },
    HUNTER      = { 0,     0.25,  0.25,  0.496 },
    SHAMAN      = { 0.25,  0.496, 0.25,  0.496 },
    PRIEST      = { 0.496, 0.742, 0.25,  0.496 },
    WARLOCK     = { 0.742, 0.988, 0.25,  0.496 },
    PALADIN     = { 0,     0.25,  0.496, 0.742 },
    DEATHKNIGHT = { 0.25,  0.496, 0.496, 0.742 },
    MONK        = { 0.496, 0.742, 0.496, 0.742 },
    DEMONHUNTER = { 0.742, 0.988, 0.496, 0.742 },
    EVOKER      = { 0,     0.25,  0.742, 0.988 },
}

-- Helper: apply class icon from sprite sheet
local function ApplyClassIconTexture(tex, classToken, style)
    local coords = CLASS_FULL_COORDS[classToken]
    if not coords then return false end
    tex:SetTexture(BLIZZ_CLASS_ICON_TEXTURE)
    tex._classCoords = { coords[1], coords[2], coords[3], coords[4] }
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    return true
end

local function GetDefaultPortraitFacing(unit)
    if unit == "target" then
        return "flipped"
    end
    return "normal"
end

local function GetPortraitFacing(unit, settings)
    if settings and settings.portraitFacing then
        return settings.portraitFacing
    end
    return GetDefaultPortraitFacing(unit)
end

local function ApplyPortraitFacing(tex, unit, settings, fullTexture)
    if not tex then return end

    local facing = GetPortraitFacing(unit, settings)
    if fullTexture and tex._classCoords then
        local c = tex._classCoords
        if facing == "flipped" then
            tex:SetTexCoord(c[2], c[1], c[3], c[4])
        else
            tex:SetTexCoord(c[1], c[2], c[3], c[4])
        end
    elseif fullTexture or (db and db.profile and db.profile.portraitStyle == "circular") then
        if facing == "flipped" then
            tex:SetTexCoord(1, 0, 0, 1)
        else
            tex:SetTexCoord(0, 1, 0, 1)
        end
    elseif facing == "flipped" then
        tex:SetTexCoord(0.85, 0.15, 0.15, 0.85)
    else
        tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    end
end


-- Portrait mask and border paths for detached portrait shapes
local PORTRAIT_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local PORTRAIT_MASKS = {
    portrait = PORTRAIT_MEDIA .. "portrait_mask.tga",
    circle   = PORTRAIT_MEDIA .. "circle_mask.tga",
    square   = PORTRAIT_MEDIA .. "square_mask.tga",
    csquare  = PORTRAIT_MEDIA .. "csquare_mask.tga",
    diamond  = PORTRAIT_MEDIA .. "diamond_mask.tga",
    hexagon  = PORTRAIT_MEDIA .. "hexagon_mask.tga",
    shield   = PORTRAIT_MEDIA .. "shield_mask.tga",
}
local PORTRAIT_BORDERS = {
    portrait = PORTRAIT_MEDIA .. "portrait_border.tga",
    circle   = PORTRAIT_MEDIA .. "circle_border.tga",
    square   = PORTRAIT_MEDIA .. "square_border.tga",
    csquare  = PORTRAIT_MEDIA .. "csquare_border.tga",
    diamond  = PORTRAIT_MEDIA .. "diamond_border.tga",
    hexagon  = PORTRAIT_MEDIA .. "hexagon_border.tga",
    shield   = PORTRAIT_MEDIA .. "shield_border.tga",
}

-- Top pixel inset for each mask shape (px from edge to visible portrait area in 128px mask)
local MASK_INSETS = {
    circle   = 17,
    csquare  = 17,
    diamond  = 14,
    hexagon  = 17,
    portrait = 17,
    shield   = 13,
    square   = 17,
}

local function AnchorCircularPortrait(backdrop, uSettings, unitToken)
    if not (backdrop and backdrop:GetParent()) then return end

    local frame = backdrop:GetParent()
    local health = frame.Health
    if not health then return end

    local side = (uSettings and uSettings.portraitSide) or backdrop._portraitSide
        or ((unitToken == "player" or unitToken == "pet") and "left" or "right")
    local xOffset = (uSettings and uSettings.portraitX) or 0
    local yOffset = (uSettings and uSettings.portraitY) or 0
    local overlap = math.max(0, (backdrop:GetWidth() or 0) * 0.5)

    backdrop:ClearAllPoints()
    if side == "top" then
        backdrop:SetPoint("BOTTOM", health, "TOP", xOffset, yOffset)
    elseif side == "left" then
        backdrop:SetPoint("RIGHT", health, "LEFT", overlap + xOffset, yOffset)
    else
        backdrop:SetPoint("LEFT", health, "RIGHT", -overlap + xOffset, yOffset)
    end
    backdrop:SetFrameLevel(frame:GetFrameLevel() + 2)
end

local function ResolveCircularPortraitColor(frame, uSettings, unitToken)
    local profile = db and db.profile
    if profile and profile.circularPortraitBorderUseCustomColor == true then
        local color = profile.circularPortraitBorderColor
        if type(color) == "table" then
            return color.r or 1, color.g or 1, color.b or 1
        end
    end

    if db and db.profile and db.profile.darkTheme then
        return DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B
    end

    local customFill = uSettings and uSettings.customFillColor
    local classColored = uSettings and uSettings.healthClassColored ~= false
    if customFill and not classColored then
        return customFill.r or 1, customFill.g or 1, customFill.b or 1
    end

    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local function ClassColor(token)
        local classToken = ResolveSafeClassToken(token)
        local color = classToken and colors and colors[classToken]
        if color then return color.r, color.g, color.b end
    end

    if classColored and unitToken == "pet" then
        local r, g, b = ClassColor("player")
        if r then return r, g, b end
    end

    if classColored and unitToken and UnitExists(unitToken) then
        if UnitIsPlayer(unitToken) then
            local r, g, b = ClassColor(unitToken)
            if r then return r, g, b end
        elseif UnitIsTapDenied and UnitIsTapDenied(unitToken) then
            return 0.6, 0.6, 0.6
        else
            local reaction = UnitReaction(unitToken, "player")
            local color = reaction and FACTION_BAR_COLORS[reaction]
            if color then return color.r, color.g, color.b end
        end
    end

    if frame and frame.Health then
        local texture = frame.Health:GetStatusBarTexture()
        if texture and texture.GetVertexColor then
            local r, g, b = texture:GetVertexColor()
            if r then return r, g, b end
        end
        return frame.Health:GetStatusBarColor()
    end

    return 1, 1, 1
end

-- Apply detached portrait shape (mask + border overlay) to a portrait backdrop.
-- Creates mask/border textures on first call, then updates them.
-- backdrop: the portrait backdrop frame
-- uSettings: per-unit DB table
-- unitToken: the unit this portrait belongs to (e.g. "player", "target")
local function ApplyDetachedPortraitShape(backdrop, uSettings, unitToken)
    local portraitStyle = db.profile.portraitStyle or "attached"
    local isDetached = portraitStyle == "detached"
    local isCircular = portraitStyle == "circular"
    local usesShape = isDetached or isCircular

    -- Rama rápida: sin modo desacoplado, solo limpiar máscara y restaurar posiciones
    if not usesShape then
        if backdrop._shapeMask then
            local texs = { backdrop._2d, backdrop._class, backdrop._bg }
            for _, tex in ipairs(texs) do
                if tex then tex:RemoveMaskTexture(backdrop._shapeMask) end
            end
            backdrop._shapeMask:Hide()
        end
        if backdrop._shapeBorderTex then backdrop._shapeBorderTex:Hide() end
        if backdrop._sqBorderTexs then
            for _, t in ipairs(backdrop._sqBorderTexs) do t:Hide() end
        end
        -- Restaurar posiciones por defecto para 2d, class e 3d
        local bh2 = backdrop:GetHeight()
        if bh2 < 1 then bh2 = 46 end
        local classInset = math.floor(bh2 * 0.08)
        local resetTargets = {
            { tex = backdrop._2d,    tl = { 0, 0 },           br = { 0, 0 } },
            { tex = backdrop._class, tl = { classInset, -classInset }, br = { -classInset, classInset } },
            { tex = backdrop._3d,    tl = { 0, 0 },           br = { 0, 0 } },
        }
        for _, r in ipairs(resetTargets) do
            if r.tex then
                r.tex:ClearAllPoints()
                PP.Point(r.tex, "TOPLEFT",     backdrop, "TOPLEFT",     r.tl[1], r.tl[2])
                PP.Point(r.tex, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", r.br[1], r.br[2])
            end
        end
        return
    end
    -- === Modo desacoplado: extraer configuración y resolver color del borde ===
    local shape = isCircular and "circle" or ((uSettings and uSettings.detachedPortraitShape) or "portrait")
    local borderOpacity = ((uSettings and uSettings.detachedPortraitBorderOpacity) or 100) / 100
    local rawBorderSize = (uSettings and uSettings.detachedPortraitBorderSize) or 7
    local bExp = 7 - rawBorderSize
    local showBorder = isCircular or not (uSettings and uSettings.detachedPortraitBorder == false)

    -- Color del borde: resolver según classColor > unit > manual > fallback
    local bc = (uSettings and uSettings.detachedPortraitBorderColor) or { r = 0, g = 0, b = 0 }
    local bR, bG, bB = bc.r, bc.g, bc.b
    local owner = backdrop:GetParent()
    if isCircular and owner and owner.Health then
        bR, bG, bB = ResolveCircularPortraitColor(owner, uSettings, unitToken)
    elseif (uSettings and uSettings.detachedPortraitClassColor) then
        local function classRGB(tok)
            local ct = ResolveSafeClassToken(tok)
            local c = ct and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[ct]
            return c and c.r, c and c.g, c and c.b
        end
        local isDark = db and db.profile and db.profile.darkTheme
        local r, g, b
        if isDark then
            r, g, b = classRGB("player")
        elseif unitToken and UnitExists(unitToken) then
            if UnitIsPlayer(unitToken) then
                r, g, b = classRGB(unitToken)
            elseif UnitIsTapDenied and UnitIsTapDenied(unitToken) then
                r, g, b = 0.6, 0.6, 0.6
            else
                local reaction = UnitReaction(unitToken, "player")
                local c = reaction and FACTION_BAR_COLORS[reaction]
                if c then r, g, b = c.r, c.g, c.b end
            end
        end
        if not r then r, g, b = classRGB("player") end
        if r then bR, bG, bB = r, g, b end
    end

    -- === MASK ===
    local maskPath = PORTRAIT_MASKS[shape]
    if maskPath then
        if not backdrop._shapeMask then
            backdrop._shapeMask = backdrop:CreateMaskTexture()
        end
        -- Inset mask by 1px when border is visible so scaling can't make the
        -- mask edge poke out from behind the border art
        backdrop._shapeMask:ClearAllPoints()
        if rawBorderSize >= 1 then
            PP.Point(backdrop._shapeMask, "TOPLEFT", backdrop, "TOPLEFT", 1, -1)
            PP.Point(backdrop._shapeMask, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, 1)
        else
            backdrop._shapeMask:SetAllPoints(backdrop)
        end
        backdrop._shapeMask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        backdrop._shapeMask:Show()
        if backdrop._2d then backdrop._2d:AddMaskTexture(backdrop._shapeMask) end
        if backdrop._class then backdrop._class:AddMaskTexture(backdrop._shapeMask) end
        if backdrop._bg then backdrop._bg:AddMaskTexture(backdrop._shapeMask) end
    end

    -- Hide legacy square border textures if they exist
    if backdrop._sqBorderTexs then
        for _, t in ipairs(backdrop._sqBorderTexs) do t:Hide() end
    end

    -- === TGA BORDER OVERLAY ===
    if not backdrop._shapeBorderTex then
        backdrop._shapeBorderTex = backdrop:CreateTexture(nil, "OVERLAY")
    end
    backdrop._shapeBorderTex:ClearAllPoints()
    PP.Point(backdrop._shapeBorderTex, "TOPLEFT", backdrop, "TOPLEFT", -bExp, bExp)
    PP.Point(backdrop._shapeBorderTex, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", bExp, -bExp)
    -- The portrait is masked, but the border must remain unmasked so its full
    -- thickness stays visible around the circle.
    if backdrop._shapeMask then
        pcall(backdrop._shapeBorderTex.RemoveMaskTexture, backdrop._shapeBorderTex, backdrop._shapeMask)
    end
    if showBorder then
        local borderPath = PORTRAIT_BORDERS[shape]
        if borderPath then
            backdrop._shapeBorderTex:SetTexture(borderPath)
            backdrop._shapeBorderTex:SetVertexColor(bR, bG, bB, borderOpacity)
            backdrop._shapeBorderTex:Show()
        else
            backdrop._shapeBorderTex:Hide()
        end
    else
        backdrop._shapeBorderTex:Hide()
    end

    -- === Content positioning within mask ===
    -- Scale portrait so its visible area fills the mask opening.
    -- MASK_INSETS[shape] = px from mask edge to visible area (in 128px mask).
    -- Content expands to fill mask; border size no longer affects content.
    local insetPx = MASK_INSETS[shape] or 17
    local bw = backdrop:GetWidth()
    local bh2 = backdrop:GetHeight()
    if bw < 1 then bw = 46 end
    if bh2 < 1 then bh2 = 46 end
    local visRatio = (128 - 2 * insetPx) / 128
    local cScale = isCircular and 1 or (1 / visRatio)
    -- Apply user art scale (100 = default, stored as percentage)
    local artScale = ((uSettings and uSettings.portraitArtScale) or 100) / 100
    cScale = cScale * artScale
    local expand = (cScale - 1) * 0.5
    local oL = -(expand * bw)
    local oR =  (expand * bw)
    local oT =  (expand * bh2)
    local oB = -(expand * bh2)
    if backdrop._2d then
        backdrop._2d:ClearAllPoints()
        PP.Point(backdrop._2d, "TOPLEFT", backdrop, "TOPLEFT", oL, oT)
        PP.Point(backdrop._2d, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", oR, oB)
    end
    if backdrop._class then
        backdrop._class:ClearAllPoints()
        local classInset = math.floor(bh2 * 0.08)
        PP.Point(backdrop._class, "TOPLEFT", backdrop, "TOPLEFT", classInset + oL, -classInset + oT)
        PP.Point(backdrop._class, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -classInset + oR, classInset + oB)
    end
    if backdrop._3d then
        -- 3D models ignore SetClipsChildren, so keep them within the backdrop
        -- bounds. Art scale is not applied to 3D (camera zoom is fixed).
        backdrop._3d:ClearAllPoints()
        PP.Point(backdrop._3d, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        PP.Point(backdrop._3d, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    end

    if isCircular then
        AnchorCircularPortrait(backdrop, uSettings, unitToken)
        C_Timer.After(0, function()
            if backdrop and db and db.profile and db.profile.portraitStyle == "circular" then
                AnchorCircularPortrait(backdrop, uSettings, unitToken)
            end
        end)
    end
end

local function UpdateCircularPortraitBorder(frame)
    if not (frame and frame.Health and frame.Portrait and frame.Portrait.backdrop) then return end
    if not (db and db.profile and db.profile.portraitStyle == "circular") then return end

    local border = frame.Portrait.backdrop._shapeBorderTex
    if border then
        local unitKey = UnitToSettingsKey(frame.unit)
        local settings = unitKey and db.profile[unitKey]
        local r, g, b = ResolveCircularPortraitColor(frame, settings, frame.unit)
        local opacity = ((settings and settings.detachedPortraitBorderOpacity) or 100) / 100
        border:SetVertexColor(r, g, b, opacity)
        border:Show()
    end
end

-- ─── Bottom Text Bar: subsistema table-driven ─────────────────────
-- Slots de texto (izq/der/centro) definidos como descriptores para
-- iterar en creación/tags/posicionamiento en lugar de código manual.
local BTB_TEXT_SLOTS = {
    { id = "Left",   justify = "LEFT",   anchor = "LEFT",   xBase = 5  },
    { id = "Right",  justify = "RIGHT",  anchor = "RIGHT",  xBase = -5 },
    { id = "Center", justify = "CENTER", anchor = "CENTER", xBase = 0  },
}

-- Posiciones de icono de clase en el BTB
local BTB_ICON_ANCHORS = {
    center = { pt = "CENTER", ref = "CENTER", dx = 0  },
    right  = { pt = "RIGHT",  ref = "RIGHT",  dx = -3 },
    left   = { pt = "LEFT",   ref = "LEFT",   dx = 3  },
}

-- Resolver color de power para texto BTB cuando el contenido es power-related
local function ResolveBTBPowerTint(fs, contentKey, usePowerColor, unit)
    if not fs or not usePowerColor then return end
    if contentKey == "perpp" or contentKey == "curpp"
    or contentKey == "curhp_curpp" or contentKey == "perhp_perpp" then
        local pType = UnitPowerType(unit)
        local info = PowerBarColor[pType]
        if info then fs:SetTextColor(info.r, info.g, info.b) end
    end
end

local function CreateBottomTextBar(frame, unit, settings, anchorFrame, xOffset, overrideWidth)
    local btbH = settings.bottomTextBarHeight or 16
    local btbPos = settings.btbPosition or "bottom"
    local isDetached = (btbPos == "detached_top" or btbPos == "detached_bottom")
    local btbW = isDetached and (settings.btbWidth or 0) or 0
    local totalWidth = (btbW > 0 and isDetached) and btbW or (overrideWidth or settings.frameWidth)

    local btb = CreateFrame("Frame", nil, frame)
    PP.Size(btb, totalWidth, btbH)

    -- Anclar BTB según la posición configurada
    if btbPos == "top" then
        PP.Point(btb, "BOTTOMLEFT", frame.Health or anchorFrame, "TOPLEFT", xOffset or 0, 0)
    elseif btbPos == "detached_top" then
        btb:SetPoint("BOTTOM", frame, "TOP", settings.btbX or 0, 15 + (settings.btbY or 0))
    elseif btbPos == "detached_bottom" then
        btb:SetPoint("TOP", frame, "BOTTOM", settings.btbX or 0, -15 + (settings.btbY or 0))
    else
        PP.Point(btb, "TOPLEFT", anchorFrame, "BOTTOMLEFT", xOffset or 0, 0)
    end

    -- Fondo del BTB
    local bgc = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
    local bg = btb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(bgc.r, bgc.g, bgc.b, settings.btbBgOpacity or 1.0)
    btb.bg = bg

    -- Overlay de texto: 3 slots creados desde BTB_TEXT_SLOTS
    local textOvr = CreateFrame("Frame", nil, btb)
    textOvr:SetAllPoints()
    textOvr:SetFrameLevel(btb:GetFrameLevel() + 2)
    btb._textOverlay = textOvr

    local slotFS = {}
    for _, slot in ipairs(BTB_TEXT_SLOTS) do
        local fs = textOvr:CreateFontString(nil, "OVERLAY")
        SetFSFont(fs, settings["btb" .. slot.id .. "Size"] or 11)
        fs:SetWordWrap(false)
        fs:SetTextColor(1, 1, 1)
        btb[slot.id .. "Text"] = fs
        slotFS[slot.id] = fs
    end

    -- Aplicar oUF tags a los 3 slots iterando descriptores
    local function ApplyBTBTextTags(lc, rc, cc)
        local vals = { Left = lc, Right = rc, Center = cc }
        for _, slot in ipairs(BTB_TEXT_SLOTS) do
            local fs = slotFS[slot.id]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(vals[slot.id])
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end

    -- Posicionar y estilizar texto desde configuración, iterando slots
    local function ApplyBTBTextPositions(s)
        for _, slot in ipairs(BTB_TEXT_SLOTS) do
            local fs = slotFS[slot.id]
            local content = s["btb" .. slot.id .. "Content"] or "none"
            SetFSFont(fs, s["btb" .. slot.id .. "Size"] or 11)
            fs:ClearAllPoints()
            if content ~= "none" then
                fs:SetJustifyH(slot.justify)
                PP.Point(fs, slot.anchor, textOvr, slot.anchor,
                    slot.xBase + (s["btb" .. slot.id .. "X"] or 0),
                    s["btb" .. slot.id .. "Y"] or 0)
                fs:Show()
            else
                fs:Hide()
            end
            -- Color de clase y de poder aplicados por slot
            ApplyClassColor(fs, unit, s["btb" .. slot.id .. "ClassColor"])
            ResolveBTBPowerTint(fs, content,
                s["btb" .. slot.id .. "PowerColor"], unit)
        end
    end

    ApplyBTBTextTags(
        settings.btbLeftContent or "none",
        settings.btbRightContent or "none",
        settings.btbCenterContent or "none"
    )
    ApplyBTBTextPositions(settings)
    btb._applyBTBTextTags = ApplyBTBTextTags
    btb._applyBTBTextPositions = ApplyBTBTextPositions

    -- Icono de clase sobre el BTB (overlay de alto nivel)
    local classIconHolder = CreateFrame("Frame", nil, frame)
    classIconHolder:SetAllPoints(textOvr)
    classIconHolder:SetFrameLevel(frame:GetFrameLevel() + 2)
    local classIconTex = classIconHolder:CreateTexture(nil, "ARTWORK")
    classIconTex:SetTexCoord(0, 1, 0, 1)
    classIconTex:Hide()
    btb.ClassIcon = classIconTex

    local function ApplyBTBClassIcon(s)
        local style = s.btbClassIcon or "none"
        if style == "none" then classIconTex:Hide(); return end
        local classToken = ResolveSafeClassToken(unit)
        if not classToken or not ApplyClassIconTexture(classIconTex, classToken, style) then
            classIconTex:Hide(); return
        end
        PP.Size(classIconTex, s.btbClassIconSize or 14, s.btbClassIconSize or 14)
        classIconTex:ClearAllPoints()
        local a = BTB_ICON_ANCHORS[s.btbClassIconLocation or "left"]
            or BTB_ICON_ANCHORS.left
        PP.Point(classIconTex, a.pt, textOvr, a.ref,
            a.dx + (s.btbClassIconX or 0), s.btbClassIconY or 0)
        classIconTex:Show()
    end

    ApplyBTBClassIcon(settings)
    btb._applyBTBClassIcon = ApplyBTBClassIcon

    return btb
end

-- SetFrameMovable removed — positioning is now handled by Unlock Mode

local function ApplyFramePosition(frame, unit)
    if not frame or not db.profile.positions[unit] then return end
    local pos = db.profile.positions[unit]
    frame:ClearAllPoints()
    
    -- Calculate dynamic X position for target frame to prevent CDM overlap
    local x = pos.x
    if unit == "target" and pos.point == "CENTER" then
        -- Check if target portrait is visible
        local portraitStyle = db.profile.portraitStyle or "attached"
        local targetSettings = db.profile.target or {}
        local targetPortraitVisible = portraitStyle ~= "none" and targetSettings.showPortrait ~= false
        
        -- Check if player portrait is on the right side (extends player frame rightward)
        local playerSettings = db.profile.player or {}
        local playerPortraitRight = (playerSettings.portraitSide or "left") == "right" and
                                    portraitStyle ~= "none" and
                                    playerSettings.showPortrait ~= false
        
        -- If either condition is true, add extra offset to prevent overlap
        if targetPortraitVisible or playerPortraitRight then
            -- Base position after migration is 280
            -- Calculate additional offset based on portrait configuration
            local basePos = 280
            local additionalOffset = 20  -- Base margin to prevent overlap
            
            if portraitStyle == "circular" then
                additionalOffset = additionalOffset + 10  -- Extra space for circular portraits
            elseif portraitStyle == "attached" then
                additionalOffset = additionalOffset + 5   -- Moderate space for attached portraits
            end
            
            -- Only apply offset if we're at or near the default position
            if x >= 270 and x <= 290 then
                x = basePos + additionalOffset
            end
        end
    end
    
    frame:SetPoint(pos.point, UIParent, pos.point, x, pos.y)
end

-- Recalculate all element sizes after frame scale changes so everything remains
-- pixel-perfect within the border.  PixelUtil rounds each element independently,
-- which can cause their sum to exceed the frame's snapped total by 1px at certain
-- scales.  After re-snapping each element we check for overflow and trim the last
-- element in the stack so everything fits exactly inside the border.
local function UpdateBordersForScale(frame, unit)
    if not frame then return end
    local settings = GetSettingsForUnit(unit)
    if not settings then return end
    local borderSize = settings.borderSize or 1

    -- 1) Main frame border textures
    if frame.unifiedBorder then
        PP.SetBorderSize(frame.unifiedBorder, borderSize)
    end

    -- 2) Gather layout info
    local ppPos = settings.powerPosition or "below"
    local ppIsAtt = (ppPos == "below" or ppPos == "above")
    local ppIsDet = (ppPos == "detached_top" or ppPos == "detached_bottom")
    local ph = settings.powerHeight or 6
    -- Simple frames (pet/tot/focustarget) have no power bar ? skip power height
    local isMini = (unit == "pet" or unit == "targettarget" or unit == "focustarget")
    local powerH = (ppIsAtt and not isMini) and ph or 0

    local btbPos = settings.btbPosition or "bottom"
    local btbIsAtt = (btbPos == "top" or btbPos == "bottom")
    local btbH = (settings.bottomTextBar and btbIsAtt) and (settings.bottomTextBarHeight or 16) or 0

    local showPortrait = settings.showPortrait ~= false
    local isAttached = (db.profile.portraitStyle or "attached") == "attached"
    local pSide = settings.portraitSide or "right"
    local effectiveSide = pSide
    if isAttached and pSide == "top" then effectiveSide = "right" end

    -- Class power above adds height (player only)
    local cpAboveH = 0
    if unit == "player" then
        local cpSt = settings.classPowerStyle or "none"
        local cpPo = (cpSt == "modern") and (settings.classPowerPosition or "top") or "none"
        if cpSt == "modern" and cpPo == "above" then
            local cpSizeAdj = settings.classPowerSize or 8
            cpAboveH = math.max(3, math.floor(cpSizeAdj * 0.375))
        end
    end

    local barHeight = settings.healthHeight + powerH + cpAboveH
    local expectedFrameH = barHeight + btbH
    local pSizeAdj = settings.portraitSize or 0
    if not isAttached then pSizeAdj = pSizeAdj + 10 end
    local adjPortraitH = barHeight + pSizeAdj
    if adjPortraitH < 8 then adjPortraitH = 8 end

    local expectedFrameW
    if not showPortrait or not isAttached then
        expectedFrameW = settings.frameWidth
    else
        expectedFrameW = adjPortraitH + settings.frameWidth
    end

    -- 3) Re-snap the frame itself
    PP.Size(frame, expectedFrameW, expectedFrameH)
    local snappedFrameW = frame:GetWidth()
    local snappedFrameH = frame:GetHeight()

    -- 4) Re-snap portrait and health bar (width axis)
    local healthTargetW = settings.frameWidth
    if frame.Portrait and frame.Portrait.backdrop and showPortrait and isAttached then
        PP.Size(frame.Portrait.backdrop, adjPortraitH, adjPortraitH)
        local snappedPortW = frame.Portrait.backdrop:GetWidth()
        local snappedPortH = frame.Portrait.backdrop:GetHeight()
        -- Trim portrait width if it + health would exceed frame
        if snappedPortW + healthTargetW > snappedFrameW + 0.01 then
            PP.Width(frame.Portrait.backdrop, snappedFrameW - healthTargetW)
            snappedPortW = frame.Portrait.backdrop:GetWidth()
        end
        -- Trim portrait height to frame height if it overflows
        if snappedPortH > snappedFrameH + 0.01 then
            PP.Height(frame.Portrait.backdrop, snappedFrameH)
        end
    end

    -- 5) Re-snap health bar height and re-anchor to snapped portrait width
    if frame.Health then
        PP.Height(frame.Health, settings.healthHeight)
        -- Re-anchor health bar so it's flush against the snapped portrait edge
        if showPortrait and isAttached and frame.Portrait and frame.Portrait.backdrop then
            local snappedPortW = frame.Portrait.backdrop:GetWidth()
            local newXOff = (effectiveSide == "left") and snappedPortW or 0
            local newRightInset = (effectiveSide == "right") and snappedPortW or 0
            local topOff = frame.Health._topOffset or 0
            frame.Health:ClearAllPoints()
            PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", newXOff, -topOff)
            PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -newRightInset, 0)
            PP.Height(frame.Health, settings.healthHeight)
            frame.Health._xOffset = newXOff
            frame.Health._rightInset = newRightInset
        end
    end

    -- 6) Re-snap power bar
    if frame.Power and ppPos ~= "none" then
        local pw = settings.frameWidth
        if ppIsDet and (settings.powerWidth or 0) > 0 then
            pw = settings.powerWidth
        end
        PP.Size(frame.Power, pw, ph)
        if ppIsAtt and frame.Health then
            -- Height: ensure health + power don't exceed the bar area
            local snappedHealthH = frame.Health:GetHeight()
            local snappedPowerH = frame.Power:GetHeight()
            local expectedBarH = settings.healthHeight + ph
            if snappedHealthH + snappedPowerH > expectedBarH + 0.01 then
                PP.Height(frame.Power, snappedPowerH - (snappedHealthH + snappedPowerH - expectedBarH))
            end
            -- Width: match health bar width exactly
            local snappedHealthW = frame.Health:GetWidth()
            local snappedPowerW = frame.Power:GetWidth()
            if math.abs(snappedPowerW - snappedHealthW) > 0.01 then
                PP.Width(frame.Power, snappedHealthW)
            end
        elseif not ppIsDet then
            -- Non-attached non-detached shouldn't happen, but trim width to frame
            local snappedPowerW = frame.Power:GetWidth()
            if snappedPowerW > snappedFrameW + 0.01 then
                PP.Width(frame.Power, snappedFrameW)
            end
        end
    end

    -- 7) Re-snap BTB
    if frame.BottomTextBar and settings.bottomTextBar and btbIsAtt then
        PP.Size(frame.BottomTextBar, expectedFrameW, settings.bottomTextBarHeight or 16)
        local snappedBtbW = frame.BottomTextBar:GetWidth()
        local snappedBtbH = frame.BottomTextBar:GetHeight()
        -- Width: trim to frame width
        if snappedBtbW > snappedFrameW + 0.01 then
            PP.Width(frame.BottomTextBar, snappedFrameW)
        end
        -- Height: ensure full stack fits within frame height
        local usedH = cpAboveH
        if frame.Health then usedH = usedH + frame.Health:GetHeight() end
        if frame.Power and ppIsAtt then usedH = usedH + frame.Power:GetHeight() end
        if usedH + snappedBtbH > snappedFrameH + 0.01 then
            PP.Height(frame.BottomTextBar, snappedBtbH - (usedH + snappedBtbH - snappedFrameH))
        end
    end

    -- 8) Castbar: re-snap background width + border textures
    if frame.Castbar then
        local castbarBg = frame.Castbar:GetParent()
        if castbarBg then
            -- Trim castbar bg width to match frame width
            local cbW = castbarBg:GetWidth()
            if cbW > snappedFrameW + 0.01 then
                PP.Width(castbarBg, snappedFrameW)
            end
            -- Re-snap border textures
            if castbarBg._ppBorders then
                PP.SetBorderSize(castbarBg, 1)
                frame.Castbar:ClearAllPoints()
                PP.Point(frame.Castbar, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
                PP.Point(frame.Castbar, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
            end
        end
    end
end

-- Snap a requested frame scale to the nearest pixel-perfect value.
-- 768 / physicalHeight gives the scale where
-- 1 logical pixel = 1 physical pixel.  We snap the frame scale so that the
-- combined effective scale (UIParent ES * frameScale) is a multiple of that
-- base pixel size, ensuring all PixelUtil sizes land on exact physical pixels.
local function SnapScaleToPixel(requestedScale)
    local _, physH = GetPhysicalScreenSize()
    if not physH or physH == 0 then return requestedScale end
    local pixelSize = 768 / physH  -- 1 physical pixel in UI points
    local parentES = UIParent:GetEffectiveScale()
    if parentES == 0 then return requestedScale end
    -- The combined effective scale
    local rawES = parentES * requestedScale
    -- Snap to nearest multiple of pixelSize
    local snapped = math.floor(rawES / pixelSize + 0.5) * pixelSize
    if snapped < pixelSize then snapped = pixelSize end
    return snapped / parentES
end

-- Smoothly animate frame scale from center point.
-- Apply scale immediately on init, then animate later changes while keeping the
-- visual center anchored to the saved point.
local SCALE_ANIM_DURATION = 0.18
local function ApplyFrameScaleCentered(frame, unit, newScale, animate)
    if not frame then return end
    local oldScale = frame._kuiCurrentScale or frame:GetScale()

    if frame._kuiScaleAnimating then
        frame._kuiCurrentScale = frame:GetScale()
        oldScale = frame._kuiCurrentScale
        frame:SetScript("OnUpdate", frame._kuiPrevOnUpdate)
        frame._kuiScaleAnimating = nil
        frame._kuiPrevOnUpdate = nil
    end

    -- Compute the new anchor offset needed to keep the visual center fixed
    -- when scale changes from s1 to s2.
    -- WoW multiplies SetPoint offsets by the frame's scale to get screen position.
    -- For anchor "TOPLEFT" with offset (ox, oy):
    --   screen_left = ox * scale,  screen_top = oy * scale
    --   screen_center_x = ox * scale + width * scale / 2
    -- To keep center fixed: newOx * s2 + w*s2/2 = ox * s1 + w*s1/2
    --   newOx = ox * s1/s2 + w * (s1 - s2) / (2 * s2)
    local function ComputeNewOffset(frm, s1, s2, unitKey)
        if not db.profile.positions[unitKey] then return nil end
        local pos = db.profile.positions[unitKey]
        local ox, oy = pos.x, pos.y
        local w = frm:GetWidth()
        local h = frm:GetHeight()
        local ratio = s1 / s2
        local pt = pos.point

        local newOx, newOy = ox * ratio, oy * ratio

        -- Horizontal center compensation
        local halfWDelta = w * (s1 - s2) / (2 * s2)
        if pt == "TOPLEFT" or pt == "LEFT" or pt == "BOTTOMLEFT" then
            newOx = newOx + halfWDelta
        elseif pt == "TOPRIGHT" or pt == "RIGHT" or pt == "BOTTOMRIGHT" then
            newOx = newOx - halfWDelta
        end
        -- TOP/BOTTOM/CENTER horizontal anchors are already centered, no x adjustment

        -- Vertical center compensation
        local halfHDelta = h * (s1 - s2) / (2 * s2)
        if pt == "TOPLEFT" or pt == "TOP" or pt == "TOPRIGHT" then
            newOy = newOy - halfHDelta
        elseif pt == "BOTTOMLEFT" or pt == "BOTTOM" or pt == "BOTTOMRIGHT" then
            newOy = newOy + halfHDelta
        end
        -- LEFT/RIGHT/CENTER vertical anchors are already centered, no y adjustment

        return newOx, newOy
    end

    local function ApplyScaleAndReposition(frm, sc, unitKey)
        local prevScale = frm:GetScale()
        if math.abs(sc - prevScale) < 0.0001 then return end
        local newOx, newOy = ComputeNewOffset(frm, prevScale, sc, unitKey)
        frm:SetScale(sc)
        if newOx and db.profile.positions[unitKey] then
            local pos = db.profile.positions[unitKey]
            pos.x = newOx
            pos.y = newOy
            frm:ClearAllPoints()
            frm:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        end
    end

    if not animate or math.abs(newScale - oldScale) < 0.001 then
        if animate and math.abs(newScale - oldScale) < 0.0001 then
            return
        end
        -- On init (animate=false), just apply scale and re-anchor from saved
        -- position without recomputing offsets. The saved position is already
        -- correct for the saved scale; recomputing would displace the frame.
        if not animate then
            frame:SetScale(newScale)
            ApplyFramePosition(frame, unit)
        else
            ApplyScaleAndReposition(frame, newScale, unit)
        end
        frame._kuiCurrentScale = newScale
        UpdateBordersForScale(frame, unit)
        return
    end

    local elapsed = 0
    local startScale = oldScale
    local endScale = newScale
    frame._kuiPrevOnUpdate = frame:GetScript("OnUpdate")
    frame._kuiScaleAnimating = true

    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = elapsed / SCALE_ANIM_DURATION
        if t >= 1 then t = 1 end
        local eased = 1 - (1 - t) * (1 - t)
        local curScale = startScale + (endScale - startScale) * eased
        ApplyScaleAndReposition(self, curScale, unit)

        if t >= 1 then
            self._kuiCurrentScale = endScale
            self:SetScript("OnUpdate", self._kuiPrevOnUpdate)
            self._kuiScaleAnimating = nil
            self._kuiPrevOnUpdate = nil
            UpdateBordersForScale(self, unit)
        end
    end)
end

-- ToggleLock removed — positioning is now handled by Unlock Mode

-- fakeFrames / CreateFakeFrame / ShowFakeFrames / HideFakeFrames removed
-- Positioning is now handled exclusively by Unlock Mode

local function GetFrameDimensions(unit)
    local settings = GetSettingsForUnit(unit)
    local pStyle = db.profile.portraitStyle or "attached"
    local showPortrait = pStyle ~= "none" and settings.showPortrait ~= false
    local isAttached = pStyle == "attached"

    -- Unidades simplificadas: sin poder ni BTB
    if unit == "pet" or unit == "targettarget" or unit == "focustarget" then
        return settings.frameWidth, settings.healthHeight
    end

    local powerPos = settings.powerPosition or "below"
    local powerIsAtt = (powerPos == "below" or powerPos == "above")
    local pSizeAdj = (settings.portraitSize or 0) + (isAttached and 0 or 10)

    -- Cálculo común de barH (vida + poder adosado)
    local powerH = powerIsAtt and (settings.powerHeight or 6) or 0
    local barH = settings.healthHeight + powerH

    -- BTB solo afecta unidades principales (no boss)
    local btbPos = settings.btbPosition or "bottom"
    local btbIsAtt = (btbPos == "top" or btbPos == "bottom")
    local btbH = 0
    if unit == "player" or unit == "target" or unit == "focus" then
        btbH = (settings.bottomTextBar and btbIsAtt) and (settings.bottomTextBarHeight or 16) or 0
    end

    -- Ancho: portrait adosado → extender por su tamaño ajustado
    local adjPH = math.max(barH + pSizeAdj, 8)
    local w = (showPortrait and isAttached) and (adjPH + settings.frameWidth) or settings.frameWidth

    -- Player/target: ajustar lado del retrato
    if unit == "player" or unit == "target" then
        local pSide = settings.portraitSide or (unit == "player" and "left" or "right")
        if isAttached and pSide == "top" then pSide = (unit == "player") and "left" or "right" end
    end

    return w, barH + btbH
end

-- ShowFakeFrames / HideFakeFrames removed — Unlock Mode handles all positioning

local function CreateHealthBar(frame, unit, height, xOffset, settings, rightInset)
    xOffset     = xOffset or 0
    rightInset  = rightInset or 0
    height      = height or settings.healthHeight

    -- Desplazamiento vertical si el poder está encima de la vida
    local ppPos = settings.powerPosition or "below"
    local aboveOff = ppPos == "above" and (settings.powerHeight or 0) or 0

    local settingsKey = UnitToSettingsKey(unit)
    local strata = frame:GetFrameStrata()
    local level  = frame:GetFrameLevel() + 2

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetFrameStrata(strata)
    health:SetFrameLevel(level)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    health:GetStatusBarTexture():SetHorizTile(false)

    -- Anclaje en dos puntos: el ancho se deriva del padre,
    -- inmune a errores de redondeo de pixel-snapping
    PP.Point(health, "TOPLEFT", frame, "TOPLEFT", xOffset, -aboveOff)
    PP.Point(health, "RIGHT", frame, "RIGHT", -rightInset, 0)
    PP.Height(health, height)

    -- Guardar offsets para reposicionamiento posterior (class power, SnapLayout)
    health._xOffset     = xOffset
    health._rightInset  = rightInset
    health._topOffset   = aboveOff
    health._kuiUnitKey  = settingsKey

    -- Flags de color para oUF
    health.colorClass        = true
    health.colorReaction     = true
    health.colorTapped       = true
    health.colorDisconnected = true

    -- Fondo semitransparente
    local bg = health:CreateTexture(nil, "BACKGROUND")
    PP.Point(bg, "TOPLEFT", health)
    PP.Point(bg, "BOTTOMRIGHT", health)
    bg:SetColorTexture(0, 0, 0, 0.5)
    health.bg = bg

    -- Aplicar textura, opacidad y tema oscuro
    ApplyHealthBarTexture(health, settingsKey)
    ApplyHealthBarAlpha(health, settingsKey)
    ApplyDarkTheme(health)

    return health
end

-- Textura fija del escudo de absorción
local function ApplyAbsorbBarStyle(frame, settings)
    local shield = frame and frame.HealthPrediction and frame.HealthPrediction.damageAbsorb
    if not shield then
        return
    end

    local texKey = settings and settings.absorbBarTexture or DEFAULT_ABSORB_TEXTURE
    local texturePath = ResolveSharedTexturePath(texKey, DEFAULT_ABSORB_TEXTURE)
    if texturePath then
        shield:SetStatusBarTexture(texturePath)
    else
        shield:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    end

    local fill = shield:GetStatusBarTexture()
    if fill then
        UnsnapTex(fill)
    end

    local r, g, b, a = ResolveAbsorbBarColor(settings)
    shield:SetStatusBarColor(r, g, b, a)
end

local function CreateAbsorbBar(frame, unit, settings)
    local hpBar = frame.Health
    if not hpBar then return end

    -- Habilitar recorte para que el escudo no sobresalga del health bar
    hpBar:SetClipsChildren(true)

    -- Referencia al fill de vida para anclar el shield por la derecha
    local fillRef = hpBar:GetStatusBarTexture()

    local shield = CreateFrame("StatusBar", nil, hpBar)
    shield:SetReverseFill(true)
    shield:SetPoint("TOPRIGHT", fillRef, "TOPRIGHT", 0, 0)
    shield:SetPoint("BOTTOMRIGHT", fillRef, "BOTTOMRIGHT", 0, 0)
    shield:SetWidth(settings.frameWidth)
    shield:SetHeight(settings.healthHeight)
    shield:Show()

    -- Registrar como predicción de absorción para oUF
    frame.HealthPrediction = {
        damageAbsorb          = shield,
        damageAbsorbClampMode = 2,
    }
    ApplyAbsorbBarStyle(frame, settings)
    return shield
end

-- ─── Tabla de anclaje para posición del texto de poder ──────────────
local PP_TEXT_ANCHORS = {
    left   = { justify = "LEFT",   pt = "LEFT",   ref = "LEFT",   dx = 2  },
    right  = { justify = "RIGHT",  pt = "RIGHT",  ref = "RIGHT",  dx = -2 },
    center = { justify = "CENTER", pt = "CENTER", ref = "CENTER", dx = 0  },
}

-- Resolver tag de oUF para el texto de poder según formato
local function BuildPowerTag(fmt, pctSuffix)
    if fmt == "curpp" then
        return "[" .. SMART_POWER_CURRENT_TAG .. "]"
    elseif fmt == "both" then
        return "[" .. SMART_POWER_CURRENT_TAG .. "] | ["
            .. SMART_POWER_PERCENT_TAG .. "]" .. pctSuffix
    elseif fmt == "smart" then
        if ShouldUseSmartPowerPercent() then
            return "[" .. SMART_POWER_PERCENT_TAG .. "]" .. pctSuffix
        end
        return "[" .. SMART_POWER_CURRENT_TAG .. "]"
    end
    -- "perpp" por defecto
    return "[" .. SMART_POWER_PERCENT_TAG .. "]" .. pctSuffix
end

local function CreatePowerBar(frame, unit, settings)
    local powerPos = settings.powerPosition or "below"
    local isDetached = (powerPos == "detached_top" or powerPos == "detached_bottom")

    -- Calcular ancho: usa powerWidth si está separado, si no frameWidth
    local pw = settings.frameWidth
    if isDetached and (settings.powerWidth or 0) > 0 then
        pw = settings.powerWidth
    end

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetFrameStrata(frame:GetFrameStrata())
    power:SetFrameLevel(frame:GetFrameLevel() + 3)
    PP.Size(power, pw, settings.powerHeight)

    -- Anclar power bar según posición configurada
    if powerPos == "none" then
        power:Hide()
    elseif powerPos == "above" then
        PP.Point(power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
        PP.Point(power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
    elseif powerPos == "detached_top" then
        power:SetPoint("BOTTOM", frame.Health, "TOP",
            settings.powerX or 0, 15 + (settings.powerY or 0))
    elseif powerPos == "detached_bottom" then
        power:SetPoint("TOP", frame.Health, "BOTTOM",
            settings.powerX or 0, -15 + (settings.powerY or 0))
    else
        PP.Point(power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
        PP.Point(power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
    end

    -- Textura de relleno y fondo
    power:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    power:GetStatusBarTexture():SetHorizTile(false)
    do
        local pFill = power:GetStatusBarTexture()
        if pFill then UnsnapTex(pFill) end
    end

    local bgColor = settings.customPowerBgColor
        or { r = 17/255, g = 17/255, b = 17/255 }
    local bg = power:CreateTexture(nil, "BACKGROUND")
    PP.Point(bg, "TOPLEFT", power, "TOPLEFT", 0, 0)
    PP.Point(bg, "BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 1)
    UnsnapTex(bg)
    power.bg = bg

    -- Color de relleno: por tipo de poder o color fijo personalizado
    local usePowerColor = settings.powerPercentPowerColor ~= false
    if usePowerColor then
        power.colorPower = true
    else
        power.colorPower = false
        local customFill = settings.customPowerFillColor
        if customFill then
            power:SetStatusBarColor(customFill.r, customFill.g, customFill.b)
            power.PostUpdateColor = function(self)
                local s2 = GetSettingsForUnit(unit)
                local cf = s2 and s2.customPowerFillColor
                if cf then self:SetStatusBarColor(cf.r, cf.g, cf.b) end
            end
        else
            power:SetStatusBarColor(0, 0, 1)
            power.PostUpdateColor = function(self)
                self:SetStatusBarColor(0, 0, 1)
            end
        end
    end

    -- Fondo personalizado (puede sobreescribir el default)
    if settings.customPowerBgColor then
        bg:SetColorTexture(settings.customPowerBgColor.r,
            settings.customPowerBgColor.g, settings.customPowerBgColor.b, 1)
    end

    -- Overlay y texto de porcentaje de poder
    local ppTextOvr = CreateFrame("Frame", nil, power)
    ppTextOvr:SetAllPoints(power)
    ppTextOvr:SetFrameLevel(frame:GetFrameLevel() + 11)
    local ppFS = ppTextOvr:CreateFontString(nil, "OVERLAY")
    SetFSFont(ppFS, settings.powerPercentSize or 9)
    ppFS:Hide()
    power._ppFS = ppFS
    power._ppTextOvr = ppTextOvr

    -- Aplicar texto de porcentaje con posición y formato configurables
    local function ApplyPowerPercentText(s)
        local pos = s.powerPercentText or "none"
        SetFSFont(ppFS, s.powerPercentSize or 9)
        ppFS:ClearAllPoints()

        if pos == "none" then
            ppFS:Hide()
            if ppFS._curTag then frame:Untag(ppFS); ppFS._curTag = nil end
            return
        end

        -- Posicionar con la tabla de anclas
        local anchor = PP_TEXT_ANCHORS[pos] or PP_TEXT_ANCHORS.center
        ppFS:SetJustifyH(anchor.justify)
        PP.Point(ppFS, anchor.pt, ppTextOvr, anchor.ref,
            anchor.dx + (s.powerPercentX or 0), s.powerPercentY or 0)

        -- Tag de oUF según formato elegido
        if ppFS._curTag then frame:Untag(ppFS); ppFS._curTag = nil end
        local showPct = s.powerShowPercent ~= false
        local pctSuffix = showPct and "%" or ""
        local tag = BuildPowerTag(s.powerTextFormat or "perpp", pctSuffix)
        frame:Tag(ppFS, tag); ppFS._curTag = tag
        if frame.UpdateTags then frame:UpdateTags() end

        -- Color: tipo de poder > color custom > blanco
        if s.powerPercentTextPowerColor then
            local pType = UnitPowerType(unit)
            local info = PowerBarColor[pType]
            if info then ppFS:SetTextColor(info.r, info.g, info.b)
            else ppFS:SetTextColor(1, 1, 1) end
        elseif s.powerTextColor then
            local tc = s.powerTextColor
            ppFS:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1)
        else
            ppFS:SetTextColor(1, 1, 1)
        end
        ppFS:Show()
    end

    ApplyPowerPercentText(settings)
    power._applyPowerPercentText = ApplyPowerPercentText

    ApplyPowerBarAlpha(power, UnitToSettingsKey(unit))

    -- Hide power bar for enemy NPCs that don't use power (melee mobs, etc.)
    -- Show power for: player, friendly units, enemy players, bosses, minibosses, casters
    power._grayedOut = false
    power.PostUpdate = function(self, u, cur, min, max)
        local s = GetSettingsForUnit(u)
        if not s then return end

        local pp = s.powerPosition or "below"
        if pp == "none" or pp == "detached_top" or pp == "detached_bottom" then return end

        -- Classification check: gray out power bar for generic melee NPCs
        local ok, shouldGray = pcall(function()
            if u == "player" or not UnitExists(u) then return false end
            if not UnitCanAttack("player", u) or UnitIsPlayer(u) then return false end
            local cls = UnitClassification(u)
            if cls == "worldboss" then return false end
            local isElite = (cls == "elite" or cls == "rareelite")
            local lvl = UnitLevel(u)
            local pLvl = UnitLevel("player")
            if isElite and (lvl == -1 or (pLvl and lvl >= pLvl + 1)) then return false end
            if UnitClassBase and UnitClassBase(u) == "PALADIN" then return false end
            return true
        end)
        if not ok then return end

        if shouldGray and not self._grayedOut then
            self._grayedOut = true
            if self.bg then
                self.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
                self.bg:SetAlpha(1)
            end
        elseif not shouldGray and self._grayedOut then
            self._grayedOut = false
            local customBg = s.customPowerBgColor
            if customBg then
                if self.bg then self.bg:SetColorTexture(customBg.r, customBg.g, customBg.b, 1) end
            else
                if self.bg then self.bg:SetColorTexture(17/255, 17/255, 17/255, 1) end
            end
            -- Restore bg alpha from unified opacity setting
            if self.bg then
                local opacity = s and (s.powerBarOpacity or 100) or 100
                self.bg:SetAlpha(opacity / 100)
            end
        end
    end

    -- Shadow Priest: show Mana on the power bar
    -- (Insanity is shown as class resource on Resource Bars)
    if unit == "player" then
        local _, classFile = UnitClass("player")
        if classFile == "PRIEST" then
            power.displayAltPower = true
            power.GetDisplayPower = function(self, u)
                local spec = GetSpecialization and GetSpecialization()
                if classFile == "PRIEST" and spec == 3 then -- Shadow
                    return 0 -- Enum.PowerType.Mana
                end
                return nil
            end
        end
    end

    return power
end

local function CreatePortrait(frame, side, frameHeight, unit)
    local portraitHeight = frameHeight or 46
    local portraitStyle = db.profile.portraitStyle or "attached"
    local isAttached = portraitStyle == "attached"
    local isCircular = portraitStyle == "circular"

    -- Check if portrait is hidden via portraitStyle == "none"
    if (db.profile.portraitStyle or "attached") == "none" then
        return nil
    end

    -- Per-unit size/offset adjustments
    local uKey = UnitToSettingsKey(unit)
    local uSettings = uKey and db.profile[uKey]
    local pSizeAdj = (uSettings and uSettings.portraitSize) or 0
    local pXOff = (uSettings and uSettings.portraitX) or 0
    local pYOff = (uSettings and uSettings.portraitY) or 0
    local baseHeight = portraitHeight
    if not isAttached then
        pSizeAdj = pSizeAdj + 10
        if not isCircular then pYOff = pYOff + 5 end
    end
    local adjustedHeight = baseHeight + pSizeAdj
    if adjustedHeight < 8 then adjustedHeight = 8 end

    -- For attached, "top" falls back to default side
    local effectiveSide = side
    if isAttached and side == "top" then
        effectiveSide = (unit == "player") and "left" or "right"
    end

    local backdrop = CreateFrame("Frame", nil, frame)
    backdrop._isPortraitBackdrop = true  -- Flag to exclude from strata reset
    backdrop:SetFrameStrata("MEDIUM")  -- Above frame's LOW strata to render on top
    backdrop:SetFrameLevel(50)  -- High level to be above all frame elements
    backdrop:EnableMouse(false)  -- Allow clicks to pass through to unit frame
    PP.Size(backdrop, adjustedHeight, adjustedHeight)
    backdrop:SetClipsChildren(true)
    backdrop._portraitSide = side
    backdrop._unitToken = unit

    local bgTex = backdrop:CreateTexture(nil, "BACKGROUND")
    PP.Point(bgTex, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    PP.Point(bgTex, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    bgTex:SetColorTexture(0.1, 0.1, 0.1, 1)
    backdrop._bg = bgTex

    if isAttached then
        if effectiveSide == "left" then
            PP.Point(backdrop, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        else
            PP.Point(backdrop, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        end
    elseif isCircular then
        AnchorCircularPortrait(backdrop, uSettings, unit)
    else
        -- Detached: float outside the health bar edge
        if effectiveSide == "top" then
            backdrop:SetPoint("BOTTOM", frame.Health or frame, "TOP", pXOff, 15 + pYOff)
        elseif effectiveSide == "left" then
            backdrop:SetPoint("TOPRIGHT", frame.Health or frame, "TOPLEFT", -15 + pXOff, pYOff)
        else
            backdrop:SetPoint("TOPLEFT", frame.Health or frame, "TOPRIGHT", 15 + pXOff, pYOff)
        end
        -- Detached portrait already has MEDIUM strata and high frame level
    end

    -- Create 2D and class theme textures eagerly; 3D PlayerModel is deferred
    -- until actually needed (mode == "3d") to avoid GPU/memory cost when unused.
    local model3D = nil  -- lazy-created only when mode is "3d"

    local function EnsureModel3D()
        if model3D then return model3D end
        model3D = CreateFrame("PlayerModel", nil, backdrop)
        PP.Point(model3D, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        PP.Point(model3D, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        model3D:SetCamera(0)
        model3D:Hide()
        backdrop._3d = model3D
        return model3D
    end
    backdrop._ensureModel3D = EnsureModel3D

    local tex2D = backdrop:CreateTexture(nil, "ARTWORK")
    PP.Point(tex2D, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    PP.Point(tex2D, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    ApplyPortraitFacing(tex2D, unit, uSettings)
    tex2D:Hide()

    -- Class theme icon (static texture, no oUF element needed)
    local texClass = backdrop:CreateTexture(nil, "ARTWORK")
    local classInset = math.floor(portraitHeight * 0.08)
    PP.Point(texClass, "TOPLEFT", backdrop, "TOPLEFT", classInset, -classInset)
    PP.Point(texClass, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -classInset, classInset)
    texClass:SetAlpha(0.8)
    local classToken = ResolvePortraitClassToken(unit)
    local classStyle = (uSettings and uSettings.classThemeStyle) or "modern"
    ApplyClassIconTexture(texClass, classToken or "WARRIOR", classStyle)
    ApplyPortraitFacing(texClass, unit, uSettings, true)
    texClass:Hide()

    backdrop._3d = model3D
    backdrop._2d = tex2D
    backdrop._class = texClass

    local mode
    do
        mode = ResolveActivePortraitMode(unit, uSettings)
        -- Legacy: if portraitMode is still "none" from old DB, hide portrait
        if mode == "none" then
            backdrop:Hide()
            return nil
        end
    end
    local active
    if mode == "class" then
        texClass:Show()
        -- Use tex2D as the oUF element (hidden) so oUF doesn't overwrite texClass
        tex2D:Hide()
        active = tex2D
        active.is2D = true
        active.isClass = true
    elseif mode == "2d" then
        tex2D:Show()
        active = tex2D
        active.is2D = true
    else
        local m3d = EnsureModel3D()
        m3d:Show()
        active = m3d
        active.is2D = false
    end
    active.backdrop = backdrop

    -- Re-apply pixel snap disable and re-anchor after oUF updates the portrait texture
    -- (SetPortraitTexture can reset snapping properties and anchor points)
    tex2D.PostUpdate = function(self)
        UnsnapTex(self)
        ApplyPortraitFacing(self, unit, uSettings)
        self:ClearAllPoints()
        -- When detached, ApplyDetachedPortraitShape sets expanded offsets for mask fill.
        -- Re-apply those offsets instead of resetting to default.
        local currentStyle = db.profile.portraitStyle or "attached"
        local isDetNow = currentStyle == "detached" or currentStyle == "circular"
        if isDetNow and backdrop then
            local uKey2 = UnitToSettingsKey(unit)
            local uS2 = uKey2 and db.profile[uKey2]
            local shape2 = (uS2 and uS2.detachedPortraitShape) or "portrait"
            local insetPx2 = MASK_INSETS[shape2] or 17
            local bw2 = backdrop:GetWidth()
            local bh3 = backdrop:GetHeight()
            if bw2 < 1 then bw2 = 46 end
            if bh3 < 1 then bh3 = 46 end
            local visR2 = (128 - 2 * insetPx2) / 128
            local cS2 = currentStyle == "circular" and 1 or (1 / visR2)
            local artS2 = ((uS2 and uS2.portraitArtScale) or 100) / 100
            cS2 = cS2 * artS2
            local exp2 = (cS2 - 1) * 0.5
            PP.Point(self, "TOPLEFT", backdrop, "TOPLEFT", -(exp2 * bw2), exp2 * bh3)
            PP.Point(self, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", exp2 * bw2, -(exp2 * bh3))
        else
            PP.Point(self, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
            PP.Point(self, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        end
    end

    -- Apply detached portrait shape (mask + border) on creation
    ApplyDetachedPortraitShape(backdrop, uSettings, unit)
    if frame.Health then
        frame.Health.PostUpdate = function(self)
            UpdateCircularPortraitBorder(self.__owner or frame)
        end
        UpdateCircularPortraitBorder(frame)
    end

    return active
end

local function CreateCastBar(frame, unit, settings)
    local castbarBg = CreateFrame("Frame", nil, frame)
    local totalWidth = 0
    local settings = GetSettingsForUnit(unit)
    local isAttached = (db.profile.portraitStyle or "attached") == "attached"
    local showPortraitCB = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    local powerHeightTotal = 0
    local ppPos = settings.powerPosition or "below"
    local ppIsAtt = (ppPos == "below" or ppPos == "above")
    if settings.powerHeight and ppIsAtt then
        powerHeightTotal = settings.powerHeight
    end
    local playerTargetHeight = settings.healthHeight + powerHeightTotal
    local pSizeAdj = settings.portraitSize or 0
    local adjPH = playerTargetHeight + pSizeAdj
    if adjPH < 8 then adjPH = 8 end
    local castBarOffset = 0
    if not isAttached then pSizeAdj = pSizeAdj + 10 end
    if not showPortraitCB or not isAttached then
        totalWidth = settings.frameWidth
    else
        local pSide = settings.portraitSide or (unit == "player" and "left" or "right")
        local eSide = pSide
        if pSide == "top" then eSide = (unit == "player") and "left" or "right" end
        totalWidth = adjPH + settings.frameWidth
        if eSide == "left" then
            castBarOffset = -(adjPH / 2)
        else
            castBarOffset = adjPH / 2
        end
    end
    PP.Size(castbarBg, totalWidth, settings.castbarHeight or 14)

    local ppPos2 = settings.powerPosition or "below"
    local anchorFrame = (ppPos2 == "below" and frame.Power) or frame.Health
    local pcbX = 0
    local pcbY = 0
    if unit == "player" then
        local owH = db.profile.player.playerCastbarHeight or 0
        if owH > 0 then
            PP.Size(castbarBg, totalWidth, owH)
        else
            PP.Size(castbarBg, totalWidth, settings.castbarHeight or 14)
        end
        -- Player castbar is always locked to frame ? anchor from left edge of frame
        local healthOff = (frame.Health and frame.Health._xOffset) or 0
        castbarBg:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", -healthOff, 0)
    else
        local healthOff = (frame.Health and frame.Health._xOffset) or 0
        castbarBg:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", -healthOff + pcbX, pcbY)
    end

    local bgTex = castbarBg:CreateTexture(nil, "BACKGROUND")
    PP.Point(bgTex, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
    PP.Point(bgTex, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
    bgTex:SetColorTexture(0, 0, 0, 0.5)

    -- Castbar borders (3 edges: left, right, bottom ? top is shared with the frame above)
    PP.CreateBorder(castbarBg, 0, 0, 0, 1, 1, "OVERLAY", 0)

    local castbar = CreateFrame("StatusBar", nil, castbarBg)
    PP.Point(castbar, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
    PP.Point(castbar, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
    castbar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    castbar:GetStatusBarTexture():SetHorizTile(false)


    local text = castbar:CreateFontString(nil, "OVERLAY")
    SetFSFont(text, 11)
    text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(1, 1, 1)
    castbar.Text = text

    local time = castbar:CreateFontString(nil, "OVERLAY")
    SetFSFont(time, 11)
    time:SetPoint("RIGHT", castbar, "RIGHT", -5, 0)
    time:SetJustifyH("RIGHT")
    time:SetTextColor(1, 1, 1)
    castbar.Time = time

    local shield = castbar:CreateTexture(nil, "OVERLAY")
    shield:SetSize(1, 1)
    shield:SetAlpha(0)
    shield:Hide()
    castbar.Shield = shield

    local castTintLayer = castbar:CreateTexture(nil, "ARTWORK", nil, 1)
    castTintLayer:SetPoint("TOPLEFT", castbar:GetStatusBarTexture(), "TOPLEFT")
    castTintLayer:SetPoint("BOTTOMRIGHT", castbar:GetStatusBarTexture(), "BOTTOMRIGHT")
    castTintLayer:SetTexture("Interface\\Buttons\\WHITE8X8")
    local c = GetCastbarColor()
    castTintLayer:SetVertexColor(c.r, c.g, c.b)
    castTintLayer:SetAlpha(0)
    castbar.castTintLayer = castTintLayer

    local shieldedTint = castbar:CreateTexture(nil, "ARTWORK", nil, 2)
    shieldedTint:SetPoint("TOPLEFT", castbar:GetStatusBarTexture(), "TOPLEFT")
    shieldedTint:SetPoint("BOTTOMRIGHT", castbar:GetStatusBarTexture(), "BOTTOMRIGHT")
    shieldedTint:SetTexture("Interface\\Buttons\\WHITE8X8")
    shieldedTint:SetVertexColor(0.5, 0.5, 0.5)
    shieldedTint:SetAlpha(0)
    castbar._shieldedTint = shieldedTint

    castbar.PostCastStart = function(self)
        if self.castTintLayer then
            self.castTintLayer:SetAlpha(1)
            local uSettings = self._eufSettings
            local ownerUnit = self.__owner and self.__owner.unit
            local cc = ResolveCastbarFillColor(ownerUnit, uSettings)
            self.castTintLayer:SetVertexColor(cc.r, cc.g, cc.b)
            if self._shieldedTint then
                self._shieldedTint:SetAlphaFromBoolean(self.notInterruptible, 1, 0)
            end
        end
    end
    castbar.PostChannelStart = castbar.PostCastStart

    castbar.PostCastInterruptible = castbar.PostCastStart

    castbar.CustomTimeText = function(self, durationObject)
        if durationObject then
            local duration = durationObject:GetRemainingDuration()
            if self.delay and self.delay ~= 0 then
                self.Time:SetFormattedText('%.1f|cffff0000%s%.2f|r', duration, self.channeling and '-' or '+', self.delay)
            else
                self.Time:SetFormattedText('%.1f', duration)
            end
        end
    end
    castbar.CustomDelayText = castbar.CustomTimeText

    -- Cast spell icon (oUF sets castbar.Icon texture automatically)
    local cbH = castbarBg:GetHeight()
    local iconSize = cbH + 1
    local iconFrame = CreateFrame("Frame", nil, castbarBg)
    iconFrame:SetSize(iconSize, iconSize)
    PP.Point(iconFrame, "TOPRIGHT", castbarBg, "TOPLEFT", 1, 1)
    local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBg:SetAllPoints()
    iconBg:SetColorTexture(0, 0, 0, 1)
    -- 1px black border via unified PP system
    PP.CreateBorder(iconFrame, 0, 0, 0, 1)
    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = iconTex
    castbar._iconFrame = iconFrame

    local function UpdateIconLayout()
        local s = GetSettingsForUnit(unit)
        local showIconSetting
        if unit == "player" then
            showIconSetting = s and s.showPlayerCastIcon ~= false
        else
            showIconSetting = s and s.showCastIcon ~= false
        end

        local cbH2 = castbarBg:GetHeight() or settings.castbarHeight or 14
        castbar:ClearAllPoints()
        iconFrame:ClearAllPoints()
        text:ClearAllPoints()

        if unit == "target" and showIconSetting then
            iconFrame:SetSize(math.max(cbH2 - 1, 10), math.max(cbH2 - 1, 10))
            PP.Point(iconFrame, "TOPRIGHT", castbarBg, "TOPRIGHT", 0, 0)
            PP.Point(castbar, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
            PP.Point(castbar, "BOTTOMRIGHT", iconFrame, "BOTTOMLEFT", -2, 0)
            text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
            text:SetPoint("RIGHT", castbar, "RIGHT", -18, 1)
        elseif unit ~= "player" and showIconSetting then
            iconFrame:SetSize(math.max(cbH2 - 1, 10), math.max(cbH2 - 1, 10))
            PP.Point(iconFrame, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
            PP.Point(castbar, "TOPLEFT", iconFrame, "TOPRIGHT", 2, 0)
            PP.Point(castbar, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
            text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
            text:SetPoint("RIGHT", castbar, "RIGHT", -5, 1)
        else
            iconFrame:SetSize(cbH2 + 1, cbH2 + 1)
            PP.Point(iconFrame, "TOPRIGHT", castbarBg, "TOPLEFT", 1, 1)
            PP.Point(castbar, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
            PP.Point(castbar, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
            text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
            text:SetPoint("RIGHT", castbar, "RIGHT", -5, 1)
        end
    end
    castbar._updateIconLayout = UpdateIconLayout
    UpdateIconLayout()

    return castbar
end

local function UnitHasActiveCast(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    return UnitCastingInfo(unit) ~= nil or UnitChannelInfo(unit) ~= nil
end

local function SetupShowOnCastBar(frame, unit)
    local castbar = frame.Castbar
    local castbarBg = castbar:GetParent()
    local iconFrame = castbar._iconFrame

    -- Read per-unit "hide while not casting" setting.
    -- When true, the castbar bg hides when nothing is being cast (player/focus default).
    -- When false, the castbar bg stays visible as part of the frame layout (target default).
    local settings = GetSettingsForUnit(unit)
    local hideWhenInactive = true
    if settings then
        local v = settings.castbarHideWhenInactive
        if v == nil then
            -- Legacy fallback: target always showed bg, others hid it
            hideWhenInactive = (unit ~= "target")
        else
            hideWhenInactive = v
        end
    end
    local function SyncCastbarInactiveVisibility()
        local activeCast = UnitHasActiveCast(unit)
        local showBg = activeCast or not hideWhenInactive
        local s = db and db.profile and GetSettingsForUnit(unit)
        local showIcon

        if unit == "player" then
            showIcon = s and s.showPlayerCastIcon ~= false
        else
            showIcon = not s or s.showCastIcon ~= false
        end

        if activeCast then
            castbar:Show()
        else
            castbar:Hide()
        end

        if iconFrame then
            if activeCast and showIcon then
                iconFrame:Show()
            else
                iconFrame:Hide()
            end
        end

        if castbarBg then
            if showBg then
                castbarBg:Show()
            else
                castbarBg:Hide()
            end
        end
    end

    SyncCastbarInactiveVisibility()
    castbar._syncInactiveVisibility = SyncCastbarInactiveVisibility

    local savedCastHook = castbar.PostCastStart

    castbar.PostCastStart = function(self, ...)
        local bg = self:GetParent()
        if bg then bg:Show() end
        self:Show()
        if self._iconFrame then
            -- Respect per-unit showCastIcon / showPlayerCastIcon setting
            local s = db and db.profile and GetSettingsForUnit(unit)
            local showIcon
            if unit == "player" then
                showIcon = (s and s.showPlayerCastIcon ~= false)
            else
                showIcon = (not s or s.showCastIcon ~= false)
            end
            if showIcon then
                self._iconFrame:Show()
            else
                self._iconFrame:Hide()
            end
        end
        if savedCastHook then savedCastHook(self, ...) end
    end
    castbar.PostChannelStart = castbar.PostCastStart
    castbar.PostCastInterruptible = savedCastHook

    local function dismissCastBar(self)
        self:Hide()
        if self._iconFrame then self._iconFrame:Hide() end
        if self.Icon then self.Icon:SetTexture(nil) end
        if self.Text then self.Text:SetText() end
        if self.Time then self.Time:SetText() end
        if self.castTintLayer then self.castTintLayer:SetAlpha(0) end
        if self._shieldedTint then self._shieldedTint:SetAlpha(0) end
        if hideWhenInactive then
            local bg = self:GetParent()
            if bg then bg:Hide() end
        end
    end
    castbar.PostCastStop = dismissCastBar
    castbar.PostChannelStop = dismissCastBar
    castbar.PostCastInterrupted = dismissCastBar
    castbar.PostCastFail = dismissCastBar
end


-- ─── Borders de unit frames: creación separada de apariencia ──────
-- Fase 1: BuildBorderFrame - crea la estructura sin apariencia
-- Fase 2: ApplyBorderAppearance - configura grosor/color desde settings
-- Los hooks de hover comparten resolución de settings vía tabla estática.

-- Detección de mini frames por tabla (sin pattern matching repetido)
local MINI_FRAME_UNITS = {
    pet = true, targettarget = true, focustarget = true,
    boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
}

-- Resolver settings de borde según si el frame es mini o principal
local function ResolveBorderSettings(unit)
    local u = unit or "player"
    if MINI_FRAME_UNITS[u] then return GetMiniDonorSettings() end
    return GetSettingsForUnit(u)
end

local function FrameBorderEnter(self)
    if not (self.unifiedBorder and self.unifiedBorder._ppBorders) then return end
    local s = ResolveBorderSettings(self.unit)
    local hc = s.highlightColor or { r = 1, g = 1, b = 1 }
    PP.SetBorderColor(self.unifiedBorder, hc.r, hc.g, hc.b, 1)
end

local function FrameBorderLeave(self)
    if not (self.unifiedBorder and self.unifiedBorder._ppBorders) then return end
    local s = ResolveBorderSettings(self.unit)
    local bc = s.borderColor or { r = 0, g = 0, b = 0 }
    PP.SetBorderColor(self.unifiedBorder, bc.r, bc.g, bc.b, 1)
end

-- Fase 1: solo crea el frame contenedor de borde (sin apariencia)
local function BuildBorderFrame(frame)
    local border = CreateFrame("Frame", nil, frame)
    PP.Point(border, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    PP.Point(border, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.unifiedBorder = border
    return border
end

-- Fase 2: aplica grosor y color al borde existente
local function ApplyBorderAppearance(frame, unit)
    local border = frame.unifiedBorder
    if not border then return end
    local s = ResolveBorderSettings(unit)
    local size = s.borderSize or 1
    local bc = s.borderColor or { r = 0, g = 0, b = 0 }
    PP.CreateBorder(border, bc.r, bc.g, bc.b, 1, size)
    if size == 0 then border:Hide() end
end

-- Función compuesta: mantiene la firma original para los 5 call sites
local function CreateUnifiedBorder(frame, unit)
    BuildBorderFrame(frame)
    ApplyBorderAppearance(frame, unit)
    frame:HookScript("OnEnter", FrameBorderEnter)
    frame:HookScript("OnLeave", FrameBorderLeave)
    return frame.unifiedBorder
end

local function Clamp01(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ResetReusableTexture(texture, alpha)
    if not texture then return end
    if texture.SetTexture then texture:SetTexture("Interface\\Buttons\\WHITE8X8") end
    if texture.SetTexCoord then texture:SetTexCoord(0, 1, 0, 1) end
    if texture.SetBlendMode then texture:SetBlendMode("BLEND") end
    if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, alpha == nil and 1 or alpha) end
end

local function HideDispelTexture(texture)
    if not texture then return end
    ResetReusableTexture(texture, 0)
    texture:Hide()
end

local function HideDispelFrameBorder(border)
    if not border then return end
    for i = 1, 4 do
        if border[i] then border[i]:Hide() end
    end
    HideDispelTexture(border.gradientTop)
    HideDispelTexture(border.gradientBottom)
    HideDispelTexture(border.gradientLeft)
    HideDispelTexture(border.gradientRight)
end

local function SetDispelFrameBorder(frame, color, alpha, thickness, gradientAlpha, gradientSize)
    local border = frame and frame.dispelBorder
    if not border then return end
    if not color then
        HideDispelFrameBorder(border)
        return
    end
    
    thickness = math.max(1, math.min(4, tonumber(thickness) or 2))
    alpha = math.max(0, math.min(1, tonumber(alpha) or 0.8))
    gradientAlpha = math.max(0, math.min(1, tonumber(gradientAlpha) or 0.32))
    gradientSize = math.max(0.12, math.min(0.60, tonumber(gradientSize) or 0.35))
    
    local function SafeSetColor(tex, colorObj, overrideAlpha)
        if colorObj.GetRGBA then
            tex:SetVertexColor(colorObj:GetRGBA())
        else
            tex:SetVertexColor(colorObj.r or 1, colorObj.g or 1, colorObj.b or 1, overrideAlpha or colorObj.a or 1)
        end
    end
    
    border[1]:SetHeight(thickness)
    border[2]:SetHeight(thickness)
    border[3]:SetWidth(thickness)
    border[4]:SetWidth(thickness)
    for i = 1, 4 do
        border[i]:SetTexture("Interface\\Buttons\\WHITE8X8")
        SafeSetColor(border[i], color, alpha)
        border[i]:Show()
    end
    
    local width = frame:GetWidth() or 1
    local height = frame:GetHeight() or 1
    local edgeH = math.max(thickness + 3, math.floor(height * gradientSize))
    local edgeW = math.max(thickness + 3, math.floor(width * gradientSize))
    local fadeAlpha = math.min(gradientAlpha, alpha * 0.8)
    
    if border.gradientTop then
        border.gradientTop:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_V")
        border.gradientTop:SetHeight(edgeH)
        SafeSetColor(border.gradientTop, color, fadeAlpha)
        border.gradientTop:SetBlendMode("BLEND")
        border.gradientTop:Show()
    end
    if border.gradientBottom then
        border.gradientBottom:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_V_Rev")
        border.gradientBottom:SetHeight(edgeH)
        SafeSetColor(border.gradientBottom, color, fadeAlpha)
        border.gradientBottom:SetBlendMode("BLEND")
        border.gradientBottom:Show()
    end
    if border.gradientLeft then
        border.gradientLeft:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_H")
        border.gradientLeft:SetWidth(edgeW)
        SafeSetColor(border.gradientLeft, color, fadeAlpha)
        border.gradientLeft:SetBlendMode("BLEND")
        border.gradientLeft:Show()
    end
    if border.gradientRight then
        border.gradientRight:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_H_Rev")
        border.gradientRight:SetWidth(edgeW)
        SafeSetColor(border.gradientRight, color, fadeAlpha)
        border.gradientRight:SetBlendMode("BLEND")
        border.gradientRight:Show()
    end
end

local function CreateDispelFrameBorder(parent)
    local border = {}
    for i = 1, 4 do
        border[i] = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        border[i]:SetColorTexture(0, 0, 0, 0)
        border[i]:Hide()
    end
    border[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border[1]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border[2]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border[2]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border[3]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border[3]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border[4]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border[4]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientTop = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientTop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.gradientTop:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.gradientTop:Hide()
    border.gradientBottom = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientBottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.gradientBottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientBottom:Hide()
    border.gradientLeft = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.gradientLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.gradientLeft:Hide()
    border.gradientRight = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.gradientRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientRight:Hide()
    return border
end

local function UpdateUnitDispelBorderEvent(self, event, unit)
    local frame = self:GetParent()
    if not frame or unit ~= frame.unit then return end
    if unit ~= "player" then
        SetDispelFrameBorder(frame, nil)
        return
    end

    -- Honour the "Dispel Overlay" toggle. Without this the player frame redraws
    -- its dispel border on every UNIT_AURA even when the user switched it off.
    local settings = GetSettingsForUnit and GetSettingsForUnit(unit)
        or frame.db or (GetMod and GetMod().db) or {}
    if settings and settings.dispelOverlay == false then
        SetDispelFrameBorder(frame, nil)
        return
    end

    local borderColor = nil
    -- Raw aura records cannot be inspected while PvP secrecy is active.
    -- The generic overlay remains available out of restricted contexts;
    -- per-aura dispel coloring is owned by AuraContainer buttons in 12.1.
    local restricted = _G.KTAuraKit and _G.KTAuraKit.AurasRestricted
        and _G.KTAuraKit.AurasRestricted()
    if not restricted and C_UnitAuras and C_UnitAuras.GetAuraSlots then
        local ok, cont, slot1 = pcall(C_UnitAuras.GetAuraSlots, unit, "HARMFUL|RAID_PLAYER_DISPELLABLE", 1)
        if ok and slot1 then
            borderColor = { r = 0.6, g = 0.2, b = 0.8, a = 0.8 }
        end
    end

    SetDispelFrameBorder(frame, borderColor, 0.8, 2, 0.32, 0.35)
end

local function CreateUnitDispelBorder(frame)
    if not frame.dispelBorderFrame then
        local f = CreateFrame("Frame", nil, frame)
        f:SetAllPoints(frame)
        local hl = frame.Health and frame.Health:GetFrameLevel() or frame:GetFrameLevel()
        f:SetFrameLevel(hl + 20)
        frame.dispelBorderFrame = f
        frame.dispelBorder = CreateDispelFrameBorder(f)
        
        f:RegisterEvent("UNIT_AURA")
        f:SetScript("OnEvent", UpdateUnitDispelBorderEvent)
        UpdateUnitDispelBorderEvent(f, "UNIT_AURA", frame.unit)
    end
end

local function SyncTargetAuraContainer(frame, unit)
    local container = frame and frame.KTDebuffs
    if not container then return end

    -- AuraContainer keeps its own unit binding. Explicitly unbind it when the
    -- target disappears so recycled buttons cannot survive into the next
    -- target. The native container remains the only aura data source.
    if not UnitExists(unit) then
        container:SetUnit("none")
        container:Hide()
        return
    end

    container:SetUnit(unit)
    container:Show()
    container:UpdateAllAuras()
end

local function ApplyTargetAuraSettings(frame, settings)
    local container = frame and frame.KTDebuffs
    if not container then return end

    if settings.showDebuffs == false then
        container:Hide()
        return
    end

    local dfp, dia, dgx, dgy, dox, doy = ResolveBuffLayout(
        settings.debuffAnchor or "bottomleft",
        settings.debuffGrowth or "auto"
    )
    local cbOffset = 0
    if settings.showCastbar ~= false then
        local cbH = settings.castbarHeight or 14
        if cbH <= 0 then cbH = 14 end
        local anchor = settings.debuffAnchor or "bottomleft"
        if anchor == "bottomleft" or anchor == "bottomright" then
            cbOffset = -cbH
        end
    end

    container:ClearAllPoints()
    container:SetPoint(dia, frame, dfp, dox, doy + cbOffset)
    local AK = _G.KTAuraKit
    if AK then AK.SetContainerAnchor(container, dia) end
    local flow = AnchorUtil and AnchorUtil.FlowDirection
    if flow and AK then
        local h = dgx == "LEFT" and flow.Left or flow.Right
        local v = dgy == "DOWN" and flow.Down or flow.Up
        AK.SetContainerGrowth(container, h, v)
    end
    if container.SetAuraGroupLayout then
        container:SetAuraGroupLayout("targetDebuffs", {
            elementWidth = 22, elementHeight = 22,
            elementSpacing = 1, lineSpacing = 1,
        })
    end
    container:Show()
    SyncTargetAuraContainer(frame, frame.unit or "target")
end

local function CreateUnitDispelSlots(frame, unit)
    if frame._ktDispelSlotsCreated then return end
    local auraKit = _G.KTAuraKit
    if not (auraKit and frame.Health) then return end

    local prefix = 'kuiuf:dispel:' .. tostring(frame)
    local settings = frame.db or (GetMod and GetMod().db) or {}
    auraKit.ConfigureDispelSlotStyles(prefix, frame.Health, {
        alpha = 1,
        thickness = 2,
        colors = settings,
    })
    local container = auraKit.CreateContainer(frame, unit, {
        point = { 'CENTER', frame, 'CENTER' },
        slots = auraKit.BuildDispelSlotSpecs(prefix),
    })
    container:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.KTDispelSlots = container
    frame._ktDispelPrefix = prefix
    frame._ktDispelSlotsCreated = true
end

local function CreateTargetAuras(frame, unit)
    if frame._targetAurasCreated then
        SyncTargetAuraContainer(frame, unit or "target")
        return
    end
    frame._targetAurasCreated = true
    local function SetupAuraIcon(_, button)
        if not button then return end

        if button.Icon then
            button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        if button.Cooldown then
            button.Cooldown:SetDrawEdge(false)
            button.Cooldown:SetReverse(true)
            button.Cooldown:SetHideCountdownNumbers(true)
        end

        if not button.Border then
            button.Border = CreateFrame("Frame", nil, button)
            button.Border:SetAllPoints()
            button.Border:SetFrameLevel(button:GetFrameLevel() + 1)
            PP.CreateBorder(button.Border, 0, 0, 0, 1)
        end
    end

    local auraSize = 22
    local gap = 1
    local perRow = 7
    local containerWidth = frame:GetWidth()

    local settings = GetSettingsForUnit(unit or 'target')

    local showBuffs = true
    if settings and settings.showBuffs == false then
        showBuffs = false
    end

    -- Compute castbar offset for bottom-anchored auras so they sit below the cast bar
    local cbOffset = 0
    if settings.showCastbar then
        local cbH = settings.castbarHeight or 14
        if cbH <= 0 then cbH = 14 end
        cbOffset = -cbH
    end

    local buffs = CreateFrame("Frame", nil, frame)
    local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
        settings and settings.buffAnchor,
        settings and settings.buffGrowth
    )
    local buffCbOff = 0
    local bAnc = settings.buffAnchor or "topleft"
    if bAnc == "bottomleft" or bAnc == "bottomright" then
        buffCbOff = cbOffset
    end
    buffs:SetPoint(bia, frame, bfp, box * gap, boy * gap + buffCbOff)
    buffs:SetSize(containerWidth, auraSize)
    buffs.size = auraSize
    buffs.spacing = gap
    buffs.num = 4
    buffs["size-x"] = perRow
    buffs.initialAnchor = bia
    buffs.growthX = bgx
    buffs.growthY = bgy
    buffs.filter = "HELPFUL"
    buffs.PostCreateButton = SetupAuraIcon
    if not showBuffs then
        buffs:Hide()
        buffs.num = 0
    end
    -- Set frame level higher to appear above power bar border
    buffs:SetFrameLevel(frame:GetFrameLevel() + 15)
    frame.Buffs = buffs

    local maxDebuffs = (settings and settings.maxDebuffs) or 28
    local dfp, dia, dgx, dgy, dox, doy = ResolveBuffLayout(
        settings and settings.debuffAnchor or "bottomleft",
        settings and settings.debuffGrowth or "auto"
    )
    local debuffCbOff = 0
    local dAnc = settings.debuffAnchor or "bottomleft"
    if dAnc == "bottomleft" or dAnc == "bottomright" then
        debuffCbOff = cbOffset
    end

    -- oUF's legacy aura reader does not consistently return NPC target auras
    -- on the modern client. Use the same AuraContainer path as Nameplates so
    -- player-applied harmful auras work for mobs and enemy NPCs as well.
    local AK = _G.KTAuraKit
    if AK then
        AK.styles["kuiuf:target-debuffs"] = {
            width = auraSize, height = auraSize,
            texCoord = { 0.07, 0.93, 0.07, 0.93 },
            border = { 0, 0, 0, 1, size = 1 },
            cooldownReverse = true,
            dispelBorder = settings.debuffDispelBorder ~= false,
            dispelBorderPx = tonumber(settings.debuffDispelBorderSize) or 2,
        }
        local debuffs = AK.CreateContainer(frame, unit, {
            point = { "CENTER", frame, "CENTER" },
            groups = {{
                key = "targetDebuffs",
                filter = settings and settings.onlyPlayerDebuffs
                    and { "HARMFUL", "PLAYER" } or { "HARMFUL" },
                maxFrameCount = maxDebuffs,
                candidateFilters = {},
                style = "kuiuf:target-debuffs",
                layout = {
                    elementWidth = auraSize, elementHeight = auraSize,
                    elementSpacing = gap, lineSpacing = gap,
                },
            }},
        })
        debuffs:ClearAllPoints()
        debuffs:SetPoint(dia, frame, dfp, dox * gap, doy * gap + debuffCbOff)
        AK.SetContainerAnchor(debuffs, dia)
        local flow = AnchorUtil and AnchorUtil.FlowDirection
        if flow then
            local h = dgx == "LEFT" and flow.Left or flow.Right
            local v = dgy == "DOWN" and flow.Down or flow.Up
            AK.SetContainerGrowth(debuffs, h, v)
        end
        debuffs:SetFrameLevel(frame:GetFrameLevel() + 15)
        frame.KTDebuffs = debuffs

        local sync = CreateFrame("Frame", nil, frame)
        sync:RegisterUnitEvent("UNIT_AURA", unit)
        sync:RegisterEvent("PLAYER_TARGET_CHANGED")
        sync:RegisterEvent("PLAYER_ENTERING_WORLD")
        sync:SetScript("OnEvent", function()
            SyncTargetAuraContainer(frame, unit)
        end)
        frame._targetAuraSync = sync
        SyncTargetAuraContainer(frame, unit)
    else
        local debuffs = CreateFrame("Frame", nil, frame)
        debuffs:SetPoint(dia, frame, dfp, dox * gap, doy * gap + debuffCbOff)
        debuffs:SetSize(containerWidth, auraSize)
        debuffs.size = auraSize
        debuffs.spacing = gap
        debuffs.num = maxDebuffs
        debuffs["size-x"] = perRow
        debuffs.initialAnchor = dia
        debuffs.growthX = dgx
        debuffs.growthY = dgy
        debuffs.filter = "HARMFUL"
        debuffs.PostCreateButton = SetupAuraIcon
        if settings and settings.onlyPlayerDebuffs then
            debuffs.onlyShowPlayer = true
        end
        debuffs:SetFrameLevel(frame:GetFrameLevel() + 15)
        frame.Debuffs = debuffs
    end
end

-- ─── Fábrica de posicionamiento de texto ─────────────────────────
-- Genera un closure ApplyTextPositions parametrizado por modo:
--   fullMode=true  → PP.Point, SetFSFont, offsets XY, class color
--                     (player, target, focus — barras con textOverlay)
--   fullMode=false → SetPoint directo, sin fuente/offset/color
--                     (simple, pet, boss — barras compactas)
-- defs: {leftDefault, rightDefault, centerDefault}
local function BuildTextPositioner(leftFS, rightFS, centerFS, unitID, anchor, defs, fullMode)
    local function GetCircularTextInsets(settings)
        if not (db and db.profile and db.profile.portraitStyle == "circular")
            or settings.showPortrait == false
        then
            return 5, 5
        end

        local side = settings.portraitSide
            or ((unitID == "player" or unitID == "pet") and "left" or "right")
        local powerPosition = settings.powerPosition or "none"
        local powerHeight = (powerPosition == "above" or powerPosition == "below")
            and (settings.powerHeight or 0) or 0
        local diameter = math.max(
            8,
            (settings.healthHeight or 20) + powerHeight + (settings.portraitSize or 0) + 10
        )
        local inset = (diameter * 0.5) + 5
        return side == "left" and inset or 5, side == "right" and inset or 5
    end

    if fullMode then
        return function(s)
            local lc  = s.leftTextContent   or defs[1]
            local rc  = s.rightTextContent  or defs[2]
            local cc  = s.centerTextContent or defs[3]
            local lsz = s.leftTextSize   or s.textSize or 12
            local rsz = s.rightTextSize  or s.textSize or 12
            local csz = s.centerTextSize or s.textSize or 12
            local lxo = s.leftTextX or 0;   local lyo = s.leftTextY or 0
            local rxo = s.rightTextX or 0;  local ryo = s.rightTextY or 0
            local cxo = s.centerTextX or 0; local cyo = s.centerTextY or 0
            local barW = s.frameWidth or 181
            local leftInset, rightInset = GetCircularTextInsets(s)

            if cc ~= "none" then
                leftFS:Hide(); rightFS:Hide()
                SetFSFont(centerFS, csz)
                centerFS:ClearAllPoints()
                centerFS:SetJustifyH("CENTER")
                PP.Point(centerFS, "CENTER", anchor, "CENTER", cxo, cyo)
                centerFS:SetWidth(0)
                centerFS:Show()
                ApplyClassColor(centerFS, unitID, s.centerTextClassColor)
            else
                centerFS:Hide()
                SetFSFont(leftFS, lsz)
                leftFS:ClearAllPoints()
                if lc ~= "none" then
                    leftFS:SetJustifyH("LEFT")
                    PP.Point(leftFS, "LEFT", anchor, "LEFT", leftInset + lxo, lyo)
                    if rc ~= "none" then
                        PP.Width(leftFS, math.max(barW - EstimateUFTextWidth(rc) - leftInset - rightInset, 20))
                    else leftFS:SetWidth(0) end
                    leftFS:Show()
                    ApplyClassColor(leftFS, unitID, s.leftTextClassColor)
                else leftFS:Hide() end

                SetFSFont(rightFS, rsz)
                rightFS:ClearAllPoints()
                if rc ~= "none" then
                    rightFS:SetJustifyH("RIGHT")
                    PP.Point(rightFS, "RIGHT", anchor, "RIGHT", -rightInset + rxo, ryo)
                    if lc ~= "none" then
                        PP.Width(rightFS, math.max(barW - EstimateUFTextWidth(lc) - leftInset - rightInset, 20))
                    else rightFS:SetWidth(0) end
                    rightFS:Show()
                    ApplyClassColor(rightFS, unitID, s.rightTextClassColor)
                else rightFS:Hide() end
            end
        end
    else
        -- Modo compacto: sin fuentes, sin offsets, sin class color
        return function(s)
            local lc   = s.leftTextContent   or defs[1]
            local rc   = s.rightTextContent  or defs[2]
            local cc   = s.centerTextContent or defs[3]
            local barW = s.frameWidth or 100
            local leftInset, rightInset = GetCircularTextInsets(s)

            if cc ~= "none" then
                centerFS:ClearAllPoints()
                centerFS:SetPoint("CENTER", anchor, "CENTER", 0, 0)
                centerFS:SetWidth(0)
                centerFS:Show()
                leftFS:Hide(); rightFS:Hide()
            else
                centerFS:Hide()
                if lc ~= "none" then
                    leftFS:ClearAllPoints()
                    leftFS:SetPoint("LEFT", anchor, "LEFT", leftInset, 0)
                    leftFS:SetJustifyH("LEFT")
                    if rc ~= "none" then
                        PP.Width(leftFS, math.max(barW - EstimateUFTextWidth(rc) - 10, 20))
                    else leftFS:SetWidth(0) end
                    leftFS:Show()
                else leftFS:Hide() end
                if rc ~= "none" then
                    rightFS:ClearAllPoints()
                    rightFS:SetPoint("RIGHT", anchor, "RIGHT", -rightInset, 0)
                    rightFS:SetJustifyH("RIGHT")
                    if lc ~= "none" then
                        PP.Width(rightFS, math.max(barW - EstimateUFTextWidth(lc) - 10, 20))
                    else rightFS:SetWidth(0) end
                    rightFS:Show()
                else rightFS:Hide() end
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Indicadores de estado para cualquier unit frame (Leader, Assistant,
--  Resurrect, Summon, RaidTarget, y overlay AFK/Dead/Ghost/Offline).
--  Usa los iconos personalizados de KUI_ICON_PATH.
-------------------------------------------------------------------------------
local function SetupUnitIndicators(frame, unit)
    if not frame or not frame.Health then return end
    local health = frame.Health
    local settings = GetSettingsForUnit(unit)

    -- Frame overlay de alto nivel para que los iconos queden por encima
    if not frame._kuiIndicatorOverlay then
        local ovr = CreateFrame("Frame", nil, frame)
        ovr:SetAllPoints(frame)
        ovr:SetFrameStrata(frame:GetFrameStrata())
        ovr:SetFrameLevel(frame:GetFrameLevel() + 2)
        frame._kuiIndicatorOverlay = ovr
    end
    local iOvr = frame._kuiIndicatorOverlay

    if not frame._kuiLevelText then
        local levelText = iOvr:CreateFontString(nil, "OVERLAY")
        ApplyForeverLevelTextStyle(levelText, db and db.profile, frame)
        levelText:SetJustifyH("LEFT")
        levelText:SetWordWrap(false)
        levelText:SetWidth(38)
        levelText:SetHeight(14)
        levelText:Hide()
        frame._kuiLevelText = levelText
    end
    if not frame._kuiPvPIcon then
        local pvp = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        pvp:SetSize(16, 16)
        pvp:Hide()
        frame._kuiPvPIcon = pvp
    end

    local function RefreshForeverMetadata()
        local u = frame.unit or (frame.GetAttribute and frame:GetAttribute("unit")) or unit
        local profile = db and db.profile
        local anchor = (frame.Portrait and (frame.Portrait.backdrop or frame.Portrait)) or frame
        local showLevel = profile and profile.showCharacterLevel == true
        ApplyForeverLevelTextStyle(frame._kuiLevelText, profile, anchor)
        if u == "target" then
            frame._kuiLevelText:ClearAllPoints()
            frame._kuiLevelText:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -(tonumber(profile and profile.levelX) or 2), tonumber(profile and profile.levelY) or 2)
            frame._kuiPvPIcon:ClearAllPoints()
            frame._kuiPvPIcon:SetPoint("LEFT", anchor, "RIGHT", 2, 1)
        else
            frame._kuiPvPIcon:ClearAllPoints()
            frame._kuiPvPIcon:SetPoint("RIGHT", anchor, "LEFT", -2, 1)
        end
        local levelText = showLevel and SafeUnitLevelText(u) or nil
        if levelText then
            frame._kuiLevelText:SetText(levelText)
            frame._kuiLevelText:Show()
        else
            frame._kuiLevelText:SetText("")
            frame._kuiLevelText:Hide()
        end
        local faction = profile and profile.showPvPIcon == true and (u == "player" or u == "target") and SafeUnitPvPFaction(u) or nil
        if faction then
            frame._kuiPvPIcon:SetTexture(PVP_ICON_PATH .. faction .. ".png")
            frame._kuiPvPIcon:SetTexCoord(0, 1, 0, 1)
            frame._kuiPvPIcon:Show()
        else
            frame._kuiPvPIcon:Hide()
        end
    end
    frame._kuiMetadataRefresh = RefreshForeverMetadata

    -- ── Leader ──────────────────────────────────────────────────
    if not frame.LeaderIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(KUI_ICON_PATH .. "Leader.png")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(14, 14)
        tex:SetPoint("TOPLEFT", health, "TOPLEFT", -2, 10)
        tex:Hide()
        if unit ~= "player" then
            frame.LeaderIndicator = tex
        end
    end

    -- ── Assistant ───────────────────────────────────────────────
    if not frame.AssistantIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(KUI_ICON_PATH .. "Assistant.png")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(14, 14)
        tex:SetPoint("TOPLEFT", health, "TOPLEFT", -2, 10)
        tex:Hide()
        if unit ~= "player" then
            frame.AssistantIndicator = tex
        end
    end

    -- ── Resurrect ──────────────────────────────────────────────
    if not frame.ResurrectIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(KUI_ICON_PATH .. "Resurrect.png")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(20, 20)
        tex:SetPoint("CENTER", health, "CENTER", 0, 0)
        tex:Hide()
        frame.ResurrectIndicator = tex
    end

    -- ── Summon ─────────────────────────────────────────────────
    if not frame.SummonIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(KUI_ICON_PATH .. "Summon.png")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(20, 20)
        tex:SetPoint("CENTER", health, "CENTER", 0, 0)
        tex:Hide()
        frame.SummonIndicator = tex
    end

    -- ── Raid Target (marcas estándar de Blizzard, no icono custom) ──
    if not frame.RaidTargetIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        tex:SetSize(18, 18)
        -- Mirror the combat indicator below the bar. This keeps the raid marker
        -- away from the resting/status icons that occupy the upper-left corner.
        tex:SetPoint("TOP", health, "BOTTOM", 0, -2)
        tex:Hide()
        frame.RaidTargetIndicator = tex
    end

    -- ── Status Overlay: AFK / Dead / Ghost / Offline ───────────
    -- Implementado como textura + texto sobre un frame de alto nivel.
    -- Solo se muestra uno a la vez (prioridad: Offline > Dead > Ghost > AFK).
    if not frame._kuiStatusOverlay then
        local ovr = CreateFrame("Frame", nil, iOvr)
        ovr:SetAllPoints(health)
        ovr:SetFrameLevel(iOvr:GetFrameLevel() + 2)
        ovr:Hide()

        local icon = ovr:CreateTexture(nil, "OVERLAY", nil, 7)
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER", ovr, "CENTER", 0, 0)
        ovr._icon = icon

        frame._kuiStatusOverlay = ovr
    end

    -- Determinar y mostrar el estado adecuado de la unidad
    local function RefreshStatusOverlay()
        local ovr = frame._kuiStatusOverlay
        if not ovr then return end
        local u = frame.unit or frame:GetAttribute("unit") or unit
        if not u or not UnitExists(u) then ovr:Hide(); return end

        local iconPath, text
        local isConnected = SafeBoolCall(UnitIsConnected, u)
        local isDeadOrGhost = SafeBoolCall(UnitIsDeadOrGhost, u)
        local isGhost = isDeadOrGhost and SafeBoolCall(UnitIsGhost, u)
        local isAFK = SafeBoolCall(UnitIsAFK, u)

        if isConnected == false then
            iconPath = KUI_ICON_PATH .. "Offline.png"
            text = "Offline"
        elseif isDeadOrGhost == true then
            if isGhost == true then
                iconPath = KUI_ICON_PATH .. "Ghost.png"
                text = "Ghost"
            else
                iconPath = KUI_ICON_PATH .. "Dead.png"
                text = "Dead"
            end
        elseif isAFK == true then
            iconPath = KUI_ICON_PATH .. "AFK.png"
            text = "AFK"
        end

        if iconPath then
            if text == "AFK" then
                ovr._icon:SetSize(32, 16)
            else
                ovr._icon:SetSize(18, 18)
            end
            ovr._icon:SetTexture(iconPath)
            ovr._icon:SetTexCoord(0, 1, 0, 1)
            ovr:Show()
        else
            ovr:Hide()
        end
    end

    frame._refreshStatusOverlay = RefreshStatusOverlay

    -- Registrar eventos solo una vez por frame
    if not frame._kuiStatusEvents then
        frame._kuiStatusEvents = true
        local evts = {
            "PLAYER_FLAGS_CHANGED", "UNIT_FLAGS",
            "UNIT_HEALTH", "UNIT_CONNECTION",
            "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE",
            "UNIT_LEVEL", "UNIT_FACTION", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        }
        for _, ev in ipairs(evts) do
            frame:RegisterEvent(ev, function()
                RefreshStatusOverlay()
                RefreshForeverMetadata()
            end, true)
        end
    end
    RefreshStatusOverlay()
    RefreshForeverMetadata()
end

local function StyleFullFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    local powerPos = settings.powerPosition or "below"
    local powerIsAtt = (powerPos == "below" or powerPos == "above")
    local powerExtra = powerIsAtt and settings.powerHeight or 0
    local playerTargetHeight = settings.healthHeight + powerExtra
    local btbPos = settings.btbPosition or "bottom"
    local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
    local btbExtra = (settings.bottomTextBar and btbIsAttached) and (settings.bottomTextBarHeight or 16) or 0
    local targetFrameHeight = playerTargetHeight + btbExtra
    local totalWidth = 0
    local portraitHeight = playerTargetHeight
    local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    local isAttached = (db.profile.portraitStyle or "attached") == "attached"

    if unit == "player" then
        local pSide = settings.portraitSide or "left"
        -- For attached, "top" falls back to default side
        local effectiveSide = pSide
        if isAttached and pSide == "top" then effectiveSide = "left" end
        -- Class power "above" adds height above health bar ("top" floats outside)
        local cpAboveH = 0
        local cpSt = settings.classPowerStyle or "none"
        local cpPo = (cpSt == "modern") and (settings.classPowerPosition or "top") or "none"
        if cpSt == "modern" and cpPo == "above" then
            local cpSizeAdj = settings.classPowerSize or 8
            local cpPipH = math.max(3, math.floor(cpSizeAdj * 0.375))
            cpAboveH = cpPipH
        end
        local playerHeightWithCp = playerTargetHeight + cpAboveH
        -- Apply portrait size adjustment
        local pSizeAdj = settings.portraitSize or 0
        local adjPortraitH = playerHeightWithCp + pSizeAdj
        if adjPortraitH < 8 then adjPortraitH = 8 end
        if not isAttached then pSizeAdj = pSizeAdj + 10 end
        if not showPortrait then
            totalWidth = settings.frameWidth
            portraitHeight = 0
        elseif isAttached then
            totalWidth = adjPortraitH + settings.frameWidth
        else
            -- Detached: portrait doesn't contribute to frame width
            totalWidth = settings.frameWidth
            portraitHeight = 0
        end
        -- Health bar xOffset: only offset when portrait is attached on the left
        local healthXOffset = (showPortrait and isAttached and effectiveSide == "left") and adjPortraitH or 0
        local healthRightInset = (showPortrait and isAttached and effectiveSide == "right") and adjPortraitH or 0
        PP.Size(frame, totalWidth, playerHeightWithCp + btbExtra)
        frame.Health = CreateHealthBar(frame, unit, settings.healthHeight, healthXOffset, settings, healthRightInset)
        frame.Power = CreatePowerBar(frame, unit, settings)
        -- Always create absorb bar; oUF element disabled later if not wanted
        CreateAbsorbBar(frame, unit, settings)
        -- Always create portrait; hide backdrop when disabled
        frame.Portrait = CreatePortrait(frame, pSide, playerHeightWithCp, unit)
        frame._portraitSide = pSide
        if frame.Portrait and not showPortrait then
            frame.Portrait.backdrop:Hide()
        end
        -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
        if frame.Portrait and frame.Portrait.backdrop and showPortrait and isAttached and frame.Health then
            local snappedPortW = frame.Portrait.backdrop:GetWidth()
            local newXOff = (effectiveSide == "left") and snappedPortW or 0
            local newRI = (effectiveSide == "right") and snappedPortW or 0
            local powerAboveOff = (powerPos == "above") and settings.powerHeight or 0
            local topOff = cpAboveH + powerAboveOff
            frame.Health:ClearAllPoints()
            PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", newXOff, -topOff)
            PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -newRI, 0)
            PP.Height(frame.Health, settings.healthHeight)
            frame.Health._xOffset = newXOff
            frame.Health._rightInset = newRI
            frame.Health._topOffset = topOff
        end

        -- Always create castbar; oUF element disabled later if not wanted
        frame.Castbar = CreateCastBar(frame, unit, settings)
        SetupShowOnCastBar(frame, "player")

        -- Always create player buffs; oUF element disabled later if not wanted
        do
            local auraSize = 22
            local gap = 1
            local perRow = 7
            local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
                settings.buffAnchor, settings.buffGrowth
            )
            -- Offset bottom-anchored buffs below castbar when locked to frame
            local buffCbOffset = 0
            if (settings.buffAnchor == "bottomleft" or settings.buffAnchor == "bottomright"
                or settings.buffAnchor == "left" or settings.buffAnchor == "right")
                and settings.showPlayerCastbar then
                local cbH = settings.playerCastbarHeight or 0
                if cbH <= 0 then cbH = 14 end
                buffCbOffset = -cbH
            end
            local buffs = CreateFrame("Frame", nil, frame)
            buffs:SetPoint(bia, frame, bfp, box * gap, boy * gap + buffCbOffset)
            buffs:SetSize(frame:GetWidth(), auraSize)
            buffs.size = auraSize
            buffs.spacing = gap
            buffs.num = settings.maxBuffs or 4
            buffs["size-x"] = perRow
            buffs.initialAnchor = bia
            buffs.growthX = bgx
            buffs.growthY = bgy
            buffs.filter = "HELPFUL"
            buffs.PostCreateButton = function(_, button)
                if not button then return end
                if button.Icon then button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
                if button.Cooldown then
                    button.Cooldown:SetDrawEdge(false)
                    button.Cooldown:SetReverse(true)
                    button.Cooldown:SetHideCountdownNumbers(true)
                end
                if not button.Border then
                    button.Border = CreateFrame("Frame", nil, button)
                    button.Border:SetAllPoints()
                    button.Border:SetFrameLevel(button:GetFrameLevel() + 1)
                    PP.CreateBorder(button.Border, 0, 0, 0, 1)
                end
            end
            frame.Buffs = buffs
            CreateUnitDispelSlots(frame, unit)
        end
    elseif unit == "target" then
        local pSide = settings.portraitSide or "right"
        -- For attached, "top" falls back to default side
        local effectiveSide = pSide
        if isAttached and pSide == "top" then effectiveSide = "right" end
        local pSizeAdj = settings.portraitSize or 0
        local adjPortraitH = playerTargetHeight + pSizeAdj
        if not isAttached then pSizeAdj = pSizeAdj + 10 end
        if adjPortraitH < 8 then adjPortraitH = 8 end
        if not showPortrait then
            totalWidth = settings.frameWidth
        elseif isAttached then
            totalWidth = adjPortraitH + settings.frameWidth
        else
            totalWidth = settings.frameWidth
        end
        local healthXOffset = (showPortrait and isAttached and effectiveSide == "left") and adjPortraitH or 0
        local healthRightInset = (showPortrait and isAttached and effectiveSide == "right") and adjPortraitH or 0
        PP.Size(frame, totalWidth, targetFrameHeight)
        frame.Health = CreateHealthBar(frame, unit, settings.healthHeight, healthXOffset, settings, healthRightInset)
        frame.Power = CreatePowerBar(frame, unit, settings)
        CreateAbsorbBar(frame, unit, settings)
        frame.Castbar = CreateCastBar(frame, unit, settings)
        SetupShowOnCastBar(frame, unit)
        frame.Portrait = CreatePortrait(frame, pSide, playerTargetHeight, unit)
        frame._portraitSide = pSide
        if frame.Portrait and not showPortrait then
            frame.Portrait.backdrop:Hide()
        end
        -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
        if frame.Portrait and frame.Portrait.backdrop and showPortrait and isAttached and frame.Health then
            local snappedPortW = frame.Portrait.backdrop:GetWidth()
            local newXOff = (effectiveSide == "left") and snappedPortW or 0
            local newRI = (effectiveSide == "right") and snappedPortW or 0
            local powerAboveOff = (powerPos == "above") and settings.powerHeight or 0
            frame.Health:ClearAllPoints()
            PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", newXOff, -powerAboveOff)
            PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -newRI, 0)
            PP.Height(frame.Health, settings.healthHeight)
            frame.Health._xOffset = newXOff
            frame.Health._rightInset = newRI
            frame.Health._topOffset = powerAboveOff
        end

        CreateTargetAuras(frame, unit)
    end

    -- Target frames do not receive a frame-wide dispel overlay.
    -- Their debuff icons retain the useful per-aura styling.
    if unit ~= 'target' then
        CreateUnitDispelBorder(frame)
    end
    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame -- sits above the StatusBar for clean text rendering.
    local textOverlay = CreateFrame("Frame", nil, frame.Health)
    textOverlay:SetAllPoints(frame.Health)
    textOverlay:SetFrameLevel(frame.Health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "both"
    local centerContent = settings.centerTextContent or "none"

    -- Crear FontStrings con sus tamaños individuales mediante iteración
    local textDefs = {
        { key = "LeftText",   size = settings.leftTextSize   or settings.textSize or 12 },
        { key = "RightText",  size = settings.rightTextSize  or settings.textSize or 12 },
        { key = "CenterText", size = settings.centerTextSize or settings.textSize or 12 },
    }
    for _, def in ipairs(textDefs) do
        local fs = textOverlay:CreateFontString(nil, "OVERLAY")
        SetFSFont(fs, def.size)
        fs:SetWordWrap(false)
        fs:SetTextColor(1, 1, 1)
        frame[def.key] = fs
    end
    local leftText, rightText, centerText = frame.LeftText, frame.RightText, frame.CenterText

    -- Alias de compatibilidad
    frame.NameText = leftText
    frame.HealthValue = rightText

    -- Aplicar tags oUF según contenido; iterar pares FontString-contenido
    local function ApplyTextTags(lc, rc, cc)
        local tagPairs = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, pair in ipairs(tagPairs) do
            local fs, content = pair[1], pair[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo full
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, textOverlay,
        {"name", "both", "none"}, true)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Bottom Text Bar
    if settings.bottomTextBar then
        local anchorFrame = (powerIsAtt and frame.Power) or frame.Health
        local btbPos = settings.btbPosition or "bottom"
        local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
        -- BTB spans full frame width; offset left when portrait is attached on the left
        local btbXOff = 0
        if btbIsAttached and showPortrait and isAttached then
            local pSide = settings.portraitSide or (unit == "player" and "left" or "right")
            local eSide = pSide
            if pSide == "top" then eSide = (unit == "player") and "left" or "right" end
            if eSide == "left" then
                local ppPos2 = settings.powerPosition or "below"
                local ppIsAtt2 = (ppPos2 == "below" or ppPos2 == "above")
                local barH = settings.healthHeight + (ppIsAtt2 and (settings.powerHeight or 6) or 0)
                local adj = barH + (settings.portraitSize or 0)
                if adj < 8 then adj = 8 end
                btbXOff = -adj
            end
        end
        frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, anchorFrame, btbXOff, totalWidth)
        frame._btb = frame.BottomTextBar
        -- Re-anchor cast bar below BTB only when BTB is attached at bottom
        if btbPos == "bottom" and frame.Castbar then
            local castbarBg = frame.Castbar:GetParent()
            if castbarBg and castbarBg:GetParent() == frame then
                castbarBg:ClearAllPoints()
                castbarBg:SetPoint("TOP", frame.BottomTextBar, "BOTTOM", 0, 0)
            end
        end
    end

    if unit == "player" then
        SetupPlayerStatusIndicators(frame, settings)
    end

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end

SetupPlayerStatusIndicators = function(frame, settings)
    if not frame or not frame.Health then return end

    -- Reutilizar el overlay de indicadores de alto strata
    if not frame._kuiIndicatorOverlay then
        local ovr = CreateFrame("Frame", nil, frame)
        ovr:SetAllPoints(frame)
        ovr:SetFrameStrata(frame:GetFrameStrata())
        ovr:SetFrameLevel(frame:GetFrameLevel() + 2)
        frame._kuiIndicatorOverlay = ovr
    end
    local iOvr = frame._kuiIndicatorOverlay

    if not frame.CombatIndicator then
        local combat = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        combat:Hide()
        frame.CombatIndicator = combat
    elseif frame.CombatIndicator:GetParent() ~= iOvr then
        frame.CombatIndicator:SetParent(iOvr)
    end

    if not frame.RestingIndicator then
        local resting = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        resting:Hide()
        resting:SetTexture(KUI_ICON_PATH .. "Zzz.png")
        resting:SetTexCoord(0, 1, 0, 1)
        frame.RestingIndicator = resting
        -- PostUpdate: oUF resetea la textura; forzamos la nuestra
        frame.RestingIndicator.PostUpdate = function(self, isResting)
            self:SetTexture(KUI_ICON_PATH .. "Zzz.png")
            self:SetTexCoord(0, 1, 0, 1)
        end
    end

    local function UpdateCombatIndicatorVisuals(s)
        local combat = frame.CombatIndicator
        if not combat then return end

        if combat:IsObjectType("Texture") then
            combat:SetTexture(KUI_ICON_PATH .. "Combat.png")
            combat:SetTexCoord(0, 1, 0, 1)
        end

        local colorMode = s.combatIndicatorColor or "custom"
        if colorMode == "class" then
            local _, class = UnitClass("player")
            local c = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or { r = 1, g = 1, b = 1 }
            combat:SetVertexColor(c.r, c.g, c.b, 1)
        else
            local c = s.combatIndicatorCustomColor or { r = 1, g = 1, b = 1 }
            combat:SetVertexColor(c.r, c.g, c.b, 1)
        end
    end

    local function UpdateCombatIndicatorLayout(s)
        local combat = frame.CombatIndicator
        if not combat then return end

        local sz = s.combatIndicatorSize or 22
        local ox = s.combatIndicatorX or 0
        local oy = s.combatIndicatorY or 0
        local pos = s.combatIndicatorPosition or "healthbar"

        local anchor = frame
        if pos == "healthbar" and frame.Health then
            anchor = frame.Health
        elseif pos == "textbar" and frame._btb then
            anchor = frame._btb
        elseif pos == "portrait" and frame.Portrait then
            anchor = frame.Portrait.backdrop or frame.Portrait
        end

        combat:SetSize(sz, sz)
        combat:ClearAllPoints()
        local baseY = (pos == "healthbar") and 26 or 10
        combat:SetPoint("CENTER", anchor, "CENTER", ox, oy + baseY)
        combat:SetDrawLayer("OVERLAY", 7)
        UpdateCombatIndicatorVisuals(s)
    end

    local function UpdateRestingIndicatorLayout()
        local resting = frame.RestingIndicator
        if not resting then return end

        resting:SetSize(16, 16)
        resting:ClearAllPoints()
        resting:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", 3, 8)
        resting:SetDrawLayer("OVERLAY", 7)
    end

    frame._updateCombatIndicatorLayout = UpdateCombatIndicatorLayout
    frame._updateCombatIndicatorVisuals = UpdateCombatIndicatorVisuals
    frame._updateRestingIndicatorLayout = UpdateRestingIndicatorLayout

    UpdateCombatIndicatorLayout(settings)
    UpdateRestingIndicatorLayout()

    if not frame._ktCombatIndicatorEvents then
        frame._ktCombatIndicatorEvents = true
        frame:RegisterEvent("PLAYER_REGEN_DISABLED", function()
            if frame.CombatIndicator and frame.CombatIndicator.ForceUpdate then
                frame.CombatIndicator:ForceUpdate()
            end
        end, true)
        frame:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            if frame.CombatIndicator and frame.CombatIndicator.ForceUpdate then
                frame.CombatIndicator:ForceUpdate()
            end
        end, true)
    end
end


local function StyleFocusFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    local fPpPos = settings.powerPosition or "below"
    local fPpIsAtt = (fPpPos == "below" or fPpPos == "above")
    local powerHeight = fPpIsAtt and (settings.powerHeight or 6) or 0
    local focusBarHeight = settings.healthHeight + powerHeight
    local btbPos = settings.btbPosition or "bottom"
    local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
    local btbExtra = (settings.bottomTextBar and btbIsAttached) and (settings.bottomTextBarHeight or 16) or 0
    local focusFrameHeight = focusBarHeight + btbExtra + (settings.castbarHeight or 14)
    local totalWidth = 0
    local portraitHeight = 0
    local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    local isAttached = (db.profile.portraitStyle or "attached") == "attached"
    local pSide = settings.portraitSide or "right"
    -- For attached, "top" falls back to default side
    local effectiveSide = pSide
    if isAttached and pSide == "top" then effectiveSide = "right" end
    local pSizeAdj = settings.portraitSize or 0
    if not isAttached then pSizeAdj = pSizeAdj + 10 end
    local adjPortraitH = focusBarHeight + pSizeAdj
    if adjPortraitH < 8 then adjPortraitH = 8 end

    if not showPortrait then
        totalWidth = settings.frameWidth
    elseif isAttached then
        totalWidth = adjPortraitH + settings.frameWidth
    else
        totalWidth = settings.frameWidth
    end

    PP.Size(frame, totalWidth, focusFrameHeight)
    local healthXOffset = (showPortrait and isAttached and effectiveSide == "left") and adjPortraitH or 0
    local healthRightInset = (showPortrait and isAttached and effectiveSide == "right") and adjPortraitH or 0
    frame.Health = CreateHealthBar(frame, unit, settings.healthHeight, healthXOffset, settings, healthRightInset)
    frame.Power = CreatePowerBar(frame, unit, settings)
    frame.Castbar = CreateCastBar(frame, unit, settings)
    -- Always create portrait; hide backdrop when disabled
    frame.Portrait = CreatePortrait(frame, pSide, focusBarHeight, unit)
    frame._portraitSide = pSide
    if frame.Portrait and not showPortrait then
        frame.Portrait.backdrop:Hide()
    end
    -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
    if frame.Portrait and frame.Portrait.backdrop and showPortrait and isAttached and frame.Health then
        local snappedPortW = frame.Portrait.backdrop:GetWidth()
        local newXOff = (effectiveSide == "left") and snappedPortW or 0
        local newRI = (effectiveSide == "right") and snappedPortW or 0
        local powerAboveOff = (fPpPos == "above") and (settings.powerHeight or 6) or 0
        frame.Health:ClearAllPoints()
        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", newXOff, -powerAboveOff)
        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -newRI, 0)
        PP.Height(frame.Health, settings.healthHeight)
        frame.Health._xOffset = newXOff
        frame.Health._rightInset = newRI
        frame.Health._topOffset = powerAboveOff
    end

    PP.Size(frame, totalWidth, focusBarHeight)

    SetupShowOnCastBar(frame, "focus")

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame -- sits above the StatusBar for clean text rendering.
    local textOverlay = CreateFrame("Frame", nil, frame.Health)
    textOverlay:SetAllPoints(frame.Health)
    textOverlay:SetFrameLevel(frame.Health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "perhp"
    local centerContent = settings.centerTextContent or "none"
    local lts = settings.leftTextSize or settings.textSize or 12
    local rts = settings.rightTextSize or settings.textSize or 12
    local cts = settings.centerTextSize or settings.textSize or 12

    local leftText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(leftText, lts)
    leftText:SetWordWrap(false)
    leftText:SetTextColor(1, 1, 1)
    frame.LeftText = leftText

    local rightText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(rightText, rts)
    rightText:SetWordWrap(false)
    rightText:SetTextColor(1, 1, 1)
    frame.RightText = rightText

    local centerText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(centerText, cts)
    centerText:SetWordWrap(false)
    centerText:SetTextColor(1, 1, 1)
    frame.CenterText = centerText

    -- Backward compat aliases
    frame.NameText = leftText
    frame.HealthValue = rightText

    -- Apply tags based on content
    local function ApplyTextTags(lc, rc, cc)
        local tagPairs = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, pair in ipairs(tagPairs) do
            local fs, content = pair[1], pair[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo full
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, textOverlay,
        {"name", "perhp", "none"}, true)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Bottom Text Bar
    if settings.bottomTextBar then
        local anchorFrame = (fPpIsAtt and frame.Power) or frame.Health
        local btbPos = settings.btbPosition or "bottom"
        local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
        -- BTB spans full frame width; offset left when portrait is attached on the left
        local btbXOff = 0
        if btbIsAttached and showPortrait and isAttached and effectiveSide == "left" then
            btbXOff = -adjPortraitH
        end
        frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, anchorFrame, btbXOff, totalWidth)
        frame._btb = frame.BottomTextBar
        -- Re-anchor cast bar below BTB only when BTB is attached at bottom
        if btbPos == "bottom" and frame.Castbar then
            local castbarBg = frame.Castbar:GetParent()
            if castbarBg and castbarBg:GetParent() == frame then
                castbarBg:ClearAllPoints()
                castbarBg:SetPoint("TOP", frame.BottomTextBar, "BOTTOM", 0, 0)
            end
        end
    end

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end

local function StyleSimpleFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    PP.Size(frame, settings.frameWidth, settings.healthHeight)

    local health = CreateFrame("StatusBar", nil, frame)
    PP.Point(health, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    PP.Point(health, "RIGHT", frame, "RIGHT", 0, 0)
    PP.Height(health, settings.healthHeight)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    health:GetStatusBarTexture():SetHorizTile(false)

    local bg = health:CreateTexture(nil, "BACKGROUND")
    PP.Point(bg, "TOPLEFT", health, "TOPLEFT", 0, 0)
    PP.Point(bg, "BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.5)
    health.bg = bg

    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    health._kuiUnitKey = UnitToSettingsKey(unit)

    -- Inherit health bar texture from donor frame (focus > target > player)
    local donor = GetMiniDonorSettings()
    local unitKey = UnitToSettingsKey(unit)
    local origTex = settings.healthBarTexture
    settings.healthBarTexture = donor.healthBarTexture
    ApplyHealthBarTexture(health, unitKey)
    settings.healthBarTexture = origTex
    ApplyHealthBarAlpha(health, unitKey)
    ApplyDarkTheme(health)

    frame.Health = health
    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame
    local textOverlay = CreateFrame("Frame", nil, health)
    textOverlay:SetAllPoints(health)
    textOverlay:SetFrameLevel(health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    local ts = settings.textSize or 12
    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "none"
    local centerContent = settings.centerTextContent or "none"

    local leftText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(leftText, ts)
    leftText:SetWordWrap(false)
    leftText:SetTextColor(1, 1, 1)
    frame.LeftText = leftText

    local rightText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(rightText, ts)
    rightText:SetWordWrap(false)
    rightText:SetTextColor(1, 1, 1)
    frame.RightText = rightText

    local centerText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(centerText, ts)
    centerText:SetWordWrap(false)
    centerText:SetTextColor(1, 1, 1)
    frame.CenterText = centerText

    -- Backward compat aliases
    frame.NameText = leftText
    frame.HealthValue = rightText

    local function ApplyTextTags(lc, rc, cc)
        local tagPairs = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, pair in ipairs(tagPairs) do
            local fs, content = pair[1], pair[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo compacto
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, health,
        {"name", "none", "none"}, false)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end


local function StylePetFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    local totalWidth = settings.frameWidth
    local portraitOffset = 0

    if showPortrait then
        totalWidth = settings.healthHeight + settings.frameWidth
        portraitOffset = settings.healthHeight
    end

    PP.Size(frame, totalWidth, settings.healthHeight)

    local health = CreateFrame("StatusBar", nil, frame)
    PP.Point(health, "TOPLEFT", frame, "TOPLEFT", portraitOffset, 0)
    PP.Point(health, "RIGHT", frame, "RIGHT", 0, 0)
    PP.Height(health, settings.healthHeight)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    health:GetStatusBarTexture():SetHorizTile(false)

    local bg = health:CreateTexture(nil, "BACKGROUND")
    PP.Point(bg, "TOPLEFT", health, "TOPLEFT", 0, 0)
    PP.Point(bg, "BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.5)
    health.bg = bg

    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    health._kuiUnitKey = UnitToSettingsKey(unit)

    -- Inherit health bar texture from donor frame (focus > target > player)
    local donor = GetMiniDonorSettings()
    local unitKey = UnitToSettingsKey(unit)
    local origTex = settings.healthBarTexture
    settings.healthBarTexture = donor.healthBarTexture
    ApplyHealthBarTexture(health, unitKey)
    settings.healthBarTexture = origTex
    ApplyHealthBarAlpha(health, unitKey)
    ApplyDarkTheme(health)

    frame.Health = health

    -- Always create portrait; hide backdrop when disabled
    frame.Portrait = CreatePortrait(frame, "left", settings.healthHeight, unit)
    frame._portraitSide = "left"
    if frame.Portrait and not showPortrait then        frame.Portrait.backdrop:Hide()
    end
    -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
    if frame.Portrait and frame.Portrait.backdrop and showPortrait then
        local snappedPortW = frame.Portrait.backdrop:GetWidth()
        health:ClearAllPoints()
        PP.Point(health, "TOPLEFT", frame, "TOPLEFT", snappedPortW, 0)
        PP.Point(health, "RIGHT", frame, "RIGHT", 0, 0)
        PP.Height(health, settings.healthHeight)
        health._xOffset = snappedPortW
        health._rightInset = 0
        health._topOffset = 0
    end

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame
    local textOverlay = CreateFrame("Frame", nil, health)
    textOverlay:SetAllPoints(health)
    textOverlay:SetFrameLevel(health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    local ts = settings.textSize or 12
    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "none"
    local centerContent = settings.centerTextContent or "none"

    local leftText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(leftText, ts)
    leftText:SetWordWrap(false)
    leftText:SetTextColor(1, 1, 1)
    frame.LeftText = leftText

    local rightText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(rightText, ts)
    rightText:SetWordWrap(false)
    rightText:SetTextColor(1, 1, 1)
    frame.RightText = rightText

    local centerText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(centerText, ts)
    centerText:SetWordWrap(false)
    centerText:SetTextColor(1, 1, 1)
    frame.CenterText = centerText

    frame.NameText = leftText
    frame.HealthValue = rightText

    local function ApplyTextTags(lc, rc, cc)
        local tagPairs = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, pair in ipairs(tagPairs) do
            local fs, content = pair[1], pair[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo compacto
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, health,
        {"name", "none", "none"}, false)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end


local function StyleBossFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    local bPpPos = settings.powerPosition or "below"
    local bPpIsAtt = (bPpPos == "below" or bPpPos == "above")
    local powerHeight = bPpIsAtt and (settings.powerHeight or 6) or 0
    local bossBarHeight = settings.healthHeight + powerHeight
    local totalWidth = 0
    local portraitHeight = 0
    local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    if not showPortrait then
        totalWidth = settings.frameWidth
    else
        totalWidth = bossBarHeight + settings.frameWidth
    end

    PP.Size(frame, totalWidth, bossBarHeight)
    local healthRightInset = showPortrait and bossBarHeight or 0
    frame.Health = CreateHealthBar(frame, unit, settings.healthHeight, portraitHeight, settings, healthRightInset)
    frame.Power = CreatePowerBar(frame, unit, settings)
    -- Always create portrait; hide backdrop when disabled
    frame.Portrait = CreatePortrait(frame, "right", bossBarHeight, unit)
    frame._portraitSide = "right"
    if frame.Portrait and not showPortrait then
        frame.Portrait.backdrop:Hide()
    end
    -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
    if frame.Portrait and frame.Portrait.backdrop and showPortrait and frame.Health then
        local snappedPortW = frame.Portrait.backdrop:GetWidth()
        local powerAboveOff = (bPpPos == "above") and (settings.powerHeight or 6) or 0
        frame.Health:ClearAllPoints()
        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", 0, -powerAboveOff)
        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -snappedPortW, 0)
        PP.Height(frame.Health, settings.healthHeight)
        frame.Health._xOffset = 0
        frame.Health._rightInset = snappedPortW
        frame.Health._topOffset = powerAboveOff
    end

    PP.Size(frame, totalWidth, bossBarHeight)

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame
    local textOverlay = CreateFrame("Frame", nil, frame.Health)
    textOverlay:SetAllPoints(frame.Health)
    textOverlay:SetFrameLevel(frame.Health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    -- Crear los tres FontStrings de texto con un bucle
    local bts = settings.textSize or 12
    local textSlots = { "LeftText", "RightText", "CenterText" }
    for _, slot in ipairs(textSlots) do
        local fs = textOverlay:CreateFontString(nil, "OVERLAY")
        SetFSFont(fs, bts)
        fs:SetWordWrap(false)
        fs:SetTextColor(1, 1, 1)
        frame[slot] = fs
    end
    local leftText, rightText, centerText = frame.LeftText, frame.RightText, frame.CenterText

    frame.NameText = leftText
    frame.HealthValue = rightText

    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "perhp"
    local centerContent = settings.centerTextContent or "none"

    local function ApplyTextTags(lc, rc, cc)
        -- Iterar los tres pares (fontstring, contenido) para untag/tag
        local slots = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, entry in ipairs(slots) do
            local fs, content = entry[1], entry[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo compacto
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, frame.Health,
        {"name", "perhp", "none"}, false)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end


local function RegisterStylesOnce()
    if _G.KUIUF_StylesRegistered then
        return
    end
    _G.KUIUF_StylesRegistered = true

    oUF:RegisterStyle("KUIPlayer", function(frame, unit)
        StyleFullFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUITarget", function(frame, unit)
        StyleFullFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUIFocus", function(frame, unit)
        StyleFocusFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUIPet", function(frame, unit)
        StylePetFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUITargetTarget", function(frame, unit)
        StyleSimpleFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUIFocusTarget", function(frame, unit)
        StyleSimpleFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUIBoss", function(frame, unit)
        StyleBossFrame(frame, unit)
    end)
end


-- Swap portrait mode (3D / 2D / class theme) without recreating frames.
-- All three objects already exist on the backdrop; we just show/hide and reassign frame.Portrait.
-- Swap portrait mode (3D / 2D / class theme) without recreating frames.
-- 2D and class textures exist on the backdrop; 3D PlayerModel is lazy-created on first use.
local function SwapPortraitMode(frame)
    local portrait = frame.Portrait
    if not portrait or not portrait.backdrop then return end
    local bd = portrait.backdrop
    if not bd._2d then return end

    local wantMode
    do
        local unit2 = frame.unit or frame:GetAttribute("unit")
        local uKey = UnitToSettingsKey(unit2)
        local s = uKey and db.profile[uKey]
        wantMode = ResolveActivePortraitMode(unit2, s)
    end
    local unit = frame.unit or frame:GetAttribute("unit")

    local curMode
    if portrait.isClass then curMode = "class"
    elseif portrait.is2D then curMode = "2d"
    else curMode = "3d" end

    if wantMode == curMode then return end

    -- Disable the oUF element so it unregisters events for the old object
    if frame:IsElementEnabled("Portrait") then
        frame:DisableElement("Portrait")
    end

    -- Hide all
    if bd._3d then bd._3d:ClearModel(); bd._3d:Hide() end
    bd._2d:Hide()
    if bd._class then bd._class:Hide() end

    if wantMode == "class" and bd._class then
        -- Re-apply class art style texture (may have changed since creation)
        local uKey2 = UnitToSettingsKey(unit)
        local s2 = uKey2 and db.profile[uKey2]
        local classStyle = (s2 and s2.classThemeStyle) or "modern"
        local ct = ResolvePortraitClassToken(unit)
        if not ct then
            wantMode = "2d"
        else
            ApplyClassIconTexture(bd._class, ct or "WARRIOR", classStyle)
            ApplyPortraitFacing(bd._class, unit, s2, true)
            bd._class:Show()
            -- Keep tex2D as the oUF element (hidden) so oUF doesn't overwrite texClass
            bd._2d:Hide()
            bd._2d.backdrop = bd
            bd._2d.is2D = true
            bd._2d.isClass = true
            frame.Portrait = bd._2d
            -- Class theme is static -- no oUF element needed, skip re-enable
            return
        end
    end

    if wantMode == "3d" then
        -- Lazily create the PlayerModel on first switch to 3D
        if bd._ensureModel3D then bd._ensureModel3D() end
        if not bd._3d then return end
        bd._3d:Show()
        bd._3d.backdrop = bd
        bd._3d.is2D = false
        bd._3d.isClass = nil
        frame.Portrait = bd._3d
    else
        bd._2d:Show()
        bd._2d.backdrop = bd
        bd._2d.is2D = true
        bd._2d.isClass = nil
        frame.Portrait = bd._2d
    end

    -- Re-enable the oUF element with the new object and force an update
    frame:EnableElement("Portrait")
    frame.Portrait:ForceUpdate()
end

-------------------------------------------------------------------------------
--  Custom Class Power Display (Bars / Circles styles)
-------------------------------------------------------------------------------
local CLASS_POWER_TYPES = {
    ROGUE       = Enum.PowerType.ComboPoints,
    DRUID       = Enum.PowerType.ComboPoints,
    MAGE        = { [62]  = { Enum.PowerType.ArcaneCharges, 4 } }, -- Arcane only
    WARLOCK     = Enum.PowerType.SoulShards,
    PALADIN     = Enum.PowerType.HolyPower,
    MONK        = { [269] = { Enum.PowerType.Chi, 5 } },
    EVOKER      = Enum.PowerType.Essence,
    DEATHKNIGHT = Enum.PowerType.Runes,
    -- Spec-specific custom resources (resolved at creation time)
    DEMONHUNTER = { [581] = { "SOUL_FRAGMENTS_VENGEANCE", 6 } },
    SHAMAN      = { [263] = { "MAELSTROM_WEAPON", 10 } },
    HUNTER      = { [255] = { "TIP_OF_THE_SPEAR", 3 } },
    WARRIOR     = { [72]  = { "WHIRLWIND_STACKS", 4 } },
}

local function DestroyCustomClassPower()
    if frames._customClassPower then
        frames._customClassPower:Hide()
        -- Unregister events on all children to prevent leaks
        local kids = { frames._customClassPower:GetChildren() }
        for _, child in ipairs(kids) do
            child:UnregisterAllEvents()
            child:SetScript("OnEvent", nil)
            child:Hide()
        end
        frames._customClassPower:SetParent(nil)
        frames._customClassPower = nil
    end
end

-- Colores de pip estilo moderno por clase (coincidos con nameplates)
local MODERN_PIP_COLORS = {
    ROGUE={1.00,0.96,0.41}, DRUID={1.00,0.49,0.04}, PALADIN={0.96,0.55,0.73},
    MONK={0.00,1.00,0.60}, WARLOCK={0.58,0.51,0.79}, MAGE={0.25,0.78,0.92},
    EVOKER={0.20,0.58,0.50}, DEATHKNIGHT={0.77,0.12,0.23},
    DEMONHUNTER={0.34,0.06,0.46}, SHAMAN={0.00,0.44,0.87},
    HUNTER={0.67,0.83,0.45}, WARRIOR={0.78,0.61,0.43},
}

-- Resolver recurso de clase: devuelve powerType, maxPower, isCustom o nil
local function ResolveClassResource(playerClass)
    local entry = CLASS_POWER_TYPES[playerClass]
    if not entry then return nil end

    local powerType, customMax, isCustom
    if type(entry) ~= "table" then
        -- PowerType numérico directo (ComboPoints, SoulShards, etc.)
        powerType, isCustom = entry, false
    else
        -- Tabla con specIDs: resolver según especialización activa
        local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization()
        local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)
        local specEntry = specID and entry[specID]
        if not specEntry then return nil end

        if type(specEntry) == "table" and type(specEntry[1]) == "string" then
            powerType, customMax, isCustom = specEntry[1], specEntry[2], true
        elseif type(specEntry) == "table" then
            powerType, customMax, isCustom = specEntry[1], specEntry[2], false
        else
            powerType, isCustom = specEntry, false
        end
    end

    -- Resolver maxPower según tipo de recurso
    local maxPower
    if isCustom then
        if powerType == "MAELSTROM_WEAPON" and Compat and Compat.GetMaelstromWeapon then
            local _, mMax = Compat.GetMaelstromWeapon()
            maxPower = (mMax and mMax > 0) and mMax or customMax
        else
            maxPower = (powerType == "SOUL_FRAGMENTS_VENGEANCE" and 6)
                or customMax or 5
        end
    else
        maxPower = UnitPowerMax("player", powerType) or 5
        if maxPower <= 0 then maxPower = 5 end
    end

    return powerType, maxPower, isCustom
end

-- Resolver color RGB de los pips según configuración del jugador
local function ResolvePipColor(playerClass, isModern)
    local useClassColor = db.profile.player.classPowerClassColor ~= false
    if not useClassColor then
        local cc = db.profile.player.classPowerCustomColor
            or { r = 1, g = 0.82, b = 0 }
        return cc.r, cc.g, cc.b
    end
    if isModern then
        local mc = MODERN_PIP_COLORS[playerClass] or {1.00, 0.84, 0.30}
        return mc[1], mc[2], mc[3]
    end
    local classColor = RAID_CLASS_COLORS[playerClass] or { r = 1, g = 1, b = 1 }
    return classColor.r, classColor.g, classColor.b
end

local function CreateCustomClassPower(playerFrame, style)
    local _, playerClass = UnitClass("player")

    -- Usar helper externo para resolver recurso + maxPower
    local powerType, maxPower, isCustom = ResolveClassResource(playerClass)
    if not powerType then return nil end

    local isModern = (style == "modern")
    local isCircle = (style == "circles")

    -- Dimensiones de cada pip según estilo
    local sizeAdj = db.profile.player.classPowerSize or 8
    local spacingAdj = db.profile.player.classPowerSpacing or 2
    local pipSize, pipH
    if isModern then
        pipSize = sizeAdj
        pipH = math.max(3, math.floor(sizeAdj * 0.375))
    elseif isCircle then
        pipSize = sizeAdj + 6
        pipH = sizeAdj + 6
    else
        pipSize = sizeAdj + 12
        pipH = sizeAdj
    end
    local gap = spacingAdj
    local pad = isModern and 0 or 4
    -- Ajustar a píxeles físicos
    pipSize = PP.Scale(pipSize)
    pipH    = PP.Scale(pipH)
    gap     = PP.Scale(gap)
    pad     = PP.Scale(pad)
    local totalW = maxPower * pipSize + (maxPower - 1) * gap + pad
    local totalH = pipH + pad

    -- Contenedor principal
    local container = CreateFrame("Frame", nil, UIParent)
    PP.Size(container, totalW, totalH)
    container:SetFrameStrata("LOW")
    container:SetFrameLevel(10)

    -- Fondo detrás de todos los pips
    local bgCol = db.profile.player.classPowerBgColor
        or { r = 0.082, g = 0.082, b = 0.082, a = 1.0 }
    local containerBg = container:CreateTexture(nil, "BACKGROUND")
    containerBg:SetAllPoints()
    containerBg:SetColorTexture(bgCol.r, bgCol.g, bgCol.b, bgCol.a)
    container._bg = containerBg

    -- Color de pip vacío
    local emptyCol = db.profile.player.classPowerEmptyColor
        or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }

    if not isModern then
        MakeBorder(container, 0, 0, 0, 0.8)
    end

    -- Borde inferior de 1px para posición "above" (se muestra sólo allí)
    local cpBdrOverlay = CreateFrame("Frame", nil, container)
    cpBdrOverlay:SetAllPoints()
    cpBdrOverlay:SetFrameLevel(container:GetFrameLevel() + 2)
    local cpBottomBdr = cpBdrOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    cpBottomBdr:SetHeight(1)
    PP.Point(cpBottomBdr, "BOTTOMLEFT", cpBdrOverlay, "BOTTOMLEFT", 0, 0)
    PP.Point(cpBottomBdr, "BOTTOMRIGHT", cpBdrOverlay, "BOTTOMRIGHT", 0, 0)
    cpBdrOverlay:Hide()
    container._bottomBdr = cpBottomBdr
    container._bottomBdrFrame = cpBdrOverlay

    -- Color de relleno resuelto por helper externo (clase/moderno/custom)
    local cr, cg, cb = ResolvePipColor(playerClass, isModern)

    -- Descriptor de textura según estilo (círculos vs barras)
    local pipTexPath = isCircle and "Interface\\COMMON\\Indicator-Gray" or nil

    local function MakePip(parent, index)
        local pip = CreateFrame("Frame", nil, parent)
        PP.Size(pip, pipSize, pipH)
        PP.Point(pip, "LEFT", parent, "LEFT",
            (index - 1) * (pipSize + gap) + pad / 2, 0)

        -- Capa vacía (visible cuando el recurso no está lleno)
        local pipEmpty = pip:CreateTexture(nil, "ARTWORK", nil, 0)
        pipEmpty:SetAllPoints()
        if pipTexPath then
            pipEmpty:SetTexture(pipTexPath)
            pipEmpty:SetVertexColor(emptyCol.r, emptyCol.g, emptyCol.b, emptyCol.a)
        else
            pipEmpty:SetColorTexture(emptyCol.r, emptyCol.g, emptyCol.b, emptyCol.a)
        end

        -- Capa de relleno (encima de la vacía)
        local pipFill = pip:CreateTexture(nil, "ARTWORK", nil, 1)
        pipFill:SetAllPoints()
        if pipTexPath then
            pipFill:SetTexture(pipTexPath)
            pipFill:SetVertexColor(cr, cg, cb, 1)
        else
            pipFill:SetColorTexture(cr, cg, cb, 1)
        end

        pip._fill = pipFill
        pip._empty = pipEmpty
        return pip
    end

    local pips = {}
    for i = 1, maxPower do
        pips[i] = MakePip(container, i)
    end

    -- Update function
    local isSecretResource = (powerType == "SOUL_FRAGMENTS_VENGEANCE")
    local function UpdatePips()
        local cur, max
        if isCustom then
            -- Custom resource: use Compat tracker functions
            if powerType == "SOUL_FRAGMENTS_VENGEANCE" then
                cur = C_Spell and C_Spell.GetSpellCastCount and C_Spell.GetSpellCastCount(228477) or 0
                max = 6
            elseif powerType == "MAELSTROM_WEAPON" and Compat and Compat.GetMaelstromWeapon then
                cur, max = Compat.GetMaelstromWeapon()
            elseif powerType == "TIP_OF_THE_SPEAR" and Compat and Compat.GetTipOfTheSpear then
                cur, max = Compat.GetTipOfTheSpear()
            elseif powerType == "WHIRLWIND_STACKS" and Compat and Compat.GetWhirlwindStacks then
                cur, max = Compat.GetWhirlwindStacks()
            else
                cur, max = 0, maxPower
            end
            if not max or max <= 0 then max = maxPower end
        else
            cur = UnitPower("player", powerType) or 0
            max = UnitPowerMax("player", powerType) or maxPower

            -- Handle runes specially (count available runes)
            if powerType == Enum.PowerType.Runes then
                cur = 0
                for i = 1, max do
                    local start, duration, ready = GetRuneCooldown(i)
                    if ready then cur = cur + 1 end
                end
            end
        end

        -- Rebuild pips if max changed
        if max ~= #pips and max > 0 then
            for _, p in ipairs(pips) do p:Hide() end
            local newTotalW = max * pipSize + (max - 1) * gap + pad
            container:SetWidth(newTotalW)
            for i = 1, max do
                if not pips[i] then
                    pips[i] = MakePip(container, i)
                end
                local x = (i - 1) * (pipSize + gap) + pad / 2
                pips[i]:ClearAllPoints()
                PP.Point(pips[i], "TOPLEFT", container, "TOPLEFT", x, 0)
                PP.Size(pips[i], pipSize, pipH)
                pips[i]:Show()
            end
        end

        if isSecretResource then
            -- Secret-value path: use StatusBar overlays per pip
            for i = 1, #pips do
                if pips[i] then
                    if not pips[i]._secretBar then
                        local sb = CreateFrame("StatusBar", nil, pips[i])
                        sb:SetAllPoints(pips[i]._fill or pips[i])
                        sb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                        sb:SetStatusBarColor(cr, cg, cb, 1)
                        sb:SetFrameLevel(pips[i]:GetFrameLevel() + 1)
                        pips[i]._secretBar = sb
                    end
                    pips[i]._secretBar:SetMinMaxValues(i - 1, i)
                    pips[i]._secretBar:SetValue(cur)
                    pips[i]._secretBar:SetStatusBarColor(cr, cg, cb, 1)
                    pips[i]._secretBar:Show()
                    -- Hide normal fill; StatusBar replaces it
                    if pips[i]._fill then pips[i]._fill:Hide() end
                end
            end
        else
            -- Clean-value path
            for i = 1, #pips do
                if pips[i] then
                    if pips[i]._secretBar then pips[i]._secretBar:Hide() end
                    if pips[i]._fill then
                        if i <= cur then
                            pips[i]._fill:Show()
                        else
                            pips[i]._fill:Hide()
                        end
                    end
                end
            end
        end
    end

    -- Event driver
    local eventFrame = CreateFrame("Frame", nil, container)
    if isCustom then
        -- Per-resource event registration: only register what each resource
        -- actually needs to avoid unnecessary event traffic.
        local needsOnUpdate = (powerType ~= "MAELSTROM_WEAPON")
        local needsAura     = (powerType == "MAELSTROM_WEAPON")
        local needsCasts    = (powerType == "TIP_OF_THE_SPEAR" or powerType == "WHIRLWIND_STACKS")

        if needsOnUpdate then
            local elapsed = 0
            eventFrame:SetScript("OnUpdate", function(_, dt)
                elapsed = elapsed + dt
                if elapsed < 0.1 then return end
                elapsed = 0
                UpdatePips()
            end)
        end

        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

        if needsAura then
            eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
        end
        if needsCasts then
            eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            eventFrame:RegisterEvent("PLAYER_DEAD")
            eventFrame:RegisterEvent("PLAYER_ALIVE")
        end
        if powerType == "WHIRLWIND_STACKS" then
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end

        eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_SPECIALIZATION_CHANGED" then
                DestroyCustomClassPower()
                frames._classPowerBar = nil
                C_Timer.After(0.1, function()
                    if ns.ReloadFrames then ns.ReloadFrames() end
                end)
                return
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                if not _G._ERB_AceDB and Compat then
                    local unit, castGUID, spellID = ...
                    if unit == "player" then
                        if Compat.HandleTipOfTheSpear then
                            Compat.HandleTipOfTheSpear(event, unit, castGUID, spellID)
                        end
                        if Compat.HandleWhirlwindStacks then
                            Compat.HandleWhirlwindStacks(event, unit, castGUID, spellID)
                        end
                    end
                end
            elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
                if not _G._ERB_AceDB and Compat then
                    if Compat.HandleTipOfTheSpear then
                        Compat.HandleTipOfTheSpear(event)
                    end
                    if Compat.HandleWhirlwindStacks then
                        Compat.HandleWhirlwindStacks(event)
                    end
                end
            elseif event == "PLAYER_REGEN_ENABLED" then
                if not _G._ERB_AceDB and Compat and Compat.HandleWhirlwindStacks then
                    Compat.HandleWhirlwindStacks(event)
                end
            end
            UpdatePips()
        end)
    else
        eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        if powerType == Enum.PowerType.Runes then
            eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
        end
        eventFrame:SetScript("OnEvent", function(_, event, unit)
            if event == "PLAYER_ENTERING_WORLD" or event == "RUNE_POWER_UPDATE"
               or (unit == "player") then
                UpdatePips()
            end
        end)
    end

    UpdatePips()
    container._updatePips = UpdatePips
    container._pips = pips
    container._pipSize = pipSize
    container._pipH = pipH
    container._gap = gap
    container._pad = pad

    -- Reposition pips to fill a given width (for "above" position)
    -- Uses Snap() to round all positions to physical pixel boundaries
    -- so gaps between pips are guaranteed identical.
    container._repositionForWidth = function(targetW)
        local n = #pips
        if n <= 0 then return end
        local efs = container:GetEffectiveScale()
        if efs <= 0 then efs = 1 end
        local function Snap(v) return math.floor(v * efs + 0.5) / efs end
        local intW = math.floor(targetW)
        local gapPx = Snap(gap)
        local totalGapW = (n - 1) * gapPx
        local totalPipW = intW - totalGapW
        local basePipW = totalPipW / n
        for i = 1, n do
            local leftEdge = Snap((i - 1) * (basePipW + gapPx))
            local rightEdge = Snap((i - 1) * (basePipW + gapPx) + basePipW)
            local w = rightEdge - leftEdge
            pips[i]:ClearAllPoints()
            pips[i]:SetSize(w, pipH)
            pips[i]:SetPoint("TOPLEFT", container, "TOPLEFT", leftEdge, 0)
        end
        container:SetWidth(intW)
        container:SetHeight(pipH)
    end

    return container
end

local function ReloadFrames()
    if InCombatLockdown() then
        return
    end

    ResolveFontPath()

    -- Invalidar cache del subsistema de contexto de unidad
    ns._UnitCtx.Invalidate()

    -- Normalize opacity values: old profiles stored 0-1 floats, new format is 0-100 integers
    do
        local prof = db.profile
        local UNITS = { "player", "target", "focus", "boss", "pet", "totPet" }
        if prof.healthBarOpacity and prof.healthBarOpacity <= 1.0 then
            prof.healthBarOpacity = math.floor(prof.healthBarOpacity * 100 + 0.5)
        end
        if prof.powerBarOpacity and prof.powerBarOpacity <= 1.0 then
            prof.powerBarOpacity = math.floor(prof.powerBarOpacity * 100 + 0.5)
        end
        for _, uKey in ipairs(UNITS) do
            local s = prof[uKey]
            if s then
                if s.healthBarOpacity and s.healthBarOpacity <= 1.0 then
                    s.healthBarOpacity = math.floor(s.healthBarOpacity * 100 + 0.5)
                end
                if s.powerBarOpacity and s.powerBarOpacity <= 1.0 then
                    s.powerBarOpacity = math.floor(s.powerBarOpacity * 100 + 0.5)
                end
            end
        end
    end

    local profile = db.profile
    local castbarColor = GetCastbarColor()
    local castbarOpacity = profile.castbarOpacity
    local enabled = profile.enabledFrames

    -- Uses global font
    local donorFontPath = Compat and Compat.GetFontPath and Compat.GetFontPath("unitFrames")
        or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"

    -- Live enable/disable frames without reload
    local function ToggleFrame(unit, frame)
        if not frame then return end
        local unitKey = unit:match("^boss%d$") and "boss" or unit
        local isEnabled = enabled[unitKey] ~= false
        -- Check group visibility for player/target/focus
        if isEnabled and (unitKey == "player" or unitKey == "target" or unitKey == "focus") then
            local s = profile[unitKey]
            if s then
                local inRaid = IsInRaid()
                local inParty = not inRaid and IsInGroup()
                local solo = not inRaid and not inParty
                local vis = (inRaid and (s.showInRaid ~= false))
                    or (inParty and (s.showInParty ~= false))
                    or (solo and (s.showSolo ~= false))
                if not vis then isEnabled = false end
            end
        end
        if isEnabled then
            -- Always set unit attribute and show frame when enabled
            frame:SetAttribute("unit", unit)
            if not frame:IsShown() then
                frame:Show()
            end
            -- Re-enable core oUF elements; per-feature elements (Portrait,
            -- Buffs, HealthPrediction) are handled by the per-unit sections below
            for _, elem in ipairs({"Health", "Power", "Debuffs"}) do
                if frame[elem] and not frame:IsElementEnabled(elem) then
                    frame:EnableElement(elem)
                end
            end
            frame:UpdateAllElements("ToggleFrame")
            if unitKey == "player" then
                RefreshPlayerStatusIndicators()
            end
        else
            if frame:IsShown() then
                -- Disable all oUF elements for zero performance impact
                for _, elem in ipairs({"Health", "Power", "Portrait", "Castbar", "Buffs", "Debuffs", "HealthPrediction", "CombatIndicator", "RestingIndicator", "LeaderIndicator", "AssistantIndicator", "ResurrectIndicator", "SummonIndicator", "RaidTargetIndicator"}) do
                    if frame[elem] and frame:IsElementEnabled(elem) then
                        frame:DisableElement(elem)
                    end
                end
                frame:SetAttribute("unit", nil)
                frame:Hide()
            end
        end
    end

    for unit, frame in pairs(frames) do
        if type(unit) == "string" and unit:sub(1,1) ~= "_" then
            ToggleFrame(unit, frame)
        end
    end

    for unit, frame in pairs(frames) do
        if type(unit) == "string" and unit:sub(1,1) ~= "_" and frame then
            local unitKey = unit:match("^boss%d$") and "boss" or unit
            if enabled[unitKey] == false then
                -- skip disabled frames
            else
            local settings = GetSettingsForUnit(unit)
            local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false

            -- Swap 2D/3D portrait mode if changed (no reload needed)
            if frame.Portrait then
                SwapPortraitMode(frame)
            end

            -- Refresh class art style texture (may have changed without mode change)
            if frame.Portrait and frame.Portrait.backdrop and frame.Portrait.backdrop._class then
                local uKey = UnitToSettingsKey(unit) or unit
                local uSettings = uKey and db.profile[uKey]
                local isClassMode = ResolveActivePortraitMode(unit, uSettings) == "class"
                if isClassMode then
                    local classStyle = (uSettings and uSettings.classThemeStyle) or "modern"
                    local ct = ResolvePortraitClassToken(unit)
                    if ct then
                        ApplyClassIconTexture(frame.Portrait.backdrop._class, ct, classStyle)
                        ApplyPortraitFacing(frame.Portrait.backdrop._class, unit, uSettings, true)
                        if frame.Portrait.backdrop._2d and frame.Portrait.backdrop._2d.PostUpdate then
                            frame.Portrait.backdrop._2d:PostUpdate()
                        end
                    elseif frame.Portrait.backdrop._class then
                        frame.Portrait.backdrop._class:Hide()
                    end
                end
            end

            -- Show/hide portrait live (no reload needed)
            if frame.Portrait and frame.Portrait.backdrop then
                local uKey = UnitToSettingsKey(unit) or unit
                local uSettings = uKey and db.profile[uKey]
                local isClassMode = ResolveActivePortraitMode(unit, uSettings) == "class"
                if showPortrait then
                    frame.Portrait.backdrop:Show()
                    if isClassMode then
                        -- Class theme uses a static texture and does not need portrait events.
                        if frame:IsElementEnabled("Portrait") then
                            frame:DisableElement("Portrait")
                        end
                    elseif not frame:IsElementEnabled("Portrait") then
                        frame:EnableElement("Portrait")
                        frame.Portrait:ForceUpdate()
                    end
                else
                    frame.Portrait.backdrop:Hide()
                    if frame:IsElementEnabled("Portrait") then
                        frame:DisableElement("Portrait")
                    end
                end
                -- Live-update detached portrait shape/mask/border
                ApplyDetachedPortraitShape(frame.Portrait.backdrop, uSettings, unit)
                -- Portrait strata and level set at creation (MEDIUM/50) - always above LOW frame
            end

            if unit == "player" and frame.HealthPrediction then
                ApplyAbsorbBarStyle(frame, settings)
            end

            if unit == "player" or unit == "target" then
                local ppPos = settings.powerPosition or "below"
                local ppIsAtt = (ppPos == "below" or ppPos == "above")
                local ppExtra = ppIsAtt and settings.powerHeight or 0
                local playerTargetHeight = settings.healthHeight + ppExtra
                -- Class power "above" adds height above health bar (player only, "top" floats outside)
                local cpAboveH = 0
                if unit == "player" then
                    local cpSt = settings.classPowerStyle or "none"
                    local cpPo = (cpSt == "modern") and (settings.classPowerPosition or "top") or "none"
                    if cpSt == "modern" and cpPo == "above" then
                        local cpSizeAdj = settings.classPowerSize or 8
                        local cpPipH = math.max(3, math.floor(cpSizeAdj * 0.375))
                        cpAboveH = cpPipH
                    end
                end
                local playerTargetHeightWithCp = playerTargetHeight + cpAboveH
                local btbPos = settings.btbPosition or "bottom"
                local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
                local btbExtra = (settings.bottomTextBar and btbIsAttached) and (settings.bottomTextBarHeight or 16) or 0
                local targetFrameHeight = playerTargetHeight + btbExtra
                local portraitHeight = 0
                local totalWidth = 0
                local isAttached = (db.profile.portraitStyle or "attached") == "attached"
                local pSizeAdj = settings.portraitSize or 0
                local pXOff = settings.portraitX or 0
                local pYOff = settings.portraitY or 0
                if not isAttached then pSizeAdj = pSizeAdj + 10; pYOff = pYOff + 5 end

                if unit == "player" then
                    local pSide = settings.portraitSide or "left"
                    local effectiveSide = pSide
                    if isAttached and pSide == "top" then effectiveSide = "left" end
                    local adjPortraitH = playerTargetHeightWithCp + pSizeAdj
                    if adjPortraitH < 8 then adjPortraitH = 8 end
                    if not showPortrait then
                        totalWidth = settings.frameWidth
                        portraitHeight = 0
                    elseif isAttached then
                        totalWidth = adjPortraitH + settings.frameWidth
                        portraitHeight = adjPortraitH
                    else
                        totalWidth = settings.frameWidth
                        portraitHeight = 0
                    end
                    -- Health bar xOffset: only offset when portrait is attached on the left
                    local healthXOffset = 0
                    local healthRightInset = 0
                    if showPortrait and isAttached and effectiveSide == "left" then
                        healthXOffset = portraitHeight
                    elseif showPortrait and isAttached and effectiveSide == "right" then
                        healthRightInset = portraitHeight
                    end

                    PP.Size(frame, totalWidth, playerTargetHeightWithCp + btbExtra)

                    if frame.Portrait and frame.Portrait.backdrop then
                        PP.Size(frame.Portrait.backdrop, adjPortraitH, adjPortraitH)
                        -- Reposition portrait for attached/detached
                        frame.Portrait.backdrop:ClearAllPoints()
                        local pBtbTopOff = (btbPos == "top" and settings.bottomTextBar) and (settings.bottomTextBarHeight or 16) or 0
                        if isAttached then
                            if effectiveSide == "left" then
                                PP.Point(frame.Portrait.backdrop, "TOPLEFT", frame, "TOPLEFT", 0, -pBtbTopOff)
                            else
                                PP.Point(frame.Portrait.backdrop, "TOPRIGHT", frame, "TOPRIGHT", 0, -pBtbTopOff)
                            end
                        else
                            if effectiveSide == "top" then
                                frame.Portrait.backdrop:SetPoint("BOTTOM", frame.Health or frame, "TOP", pXOff, 15 + pYOff)
                            elseif effectiveSide == "left" then
                                frame.Portrait.backdrop:SetPoint("TOPRIGHT", frame.Health or frame, "TOPLEFT", -15 + pXOff, pYOff)
                            else
                                frame.Portrait.backdrop:SetPoint("TOPLEFT", frame.Health or frame, "TOPRIGHT", 15 + pXOff, pYOff)
                            end
                        end
                        if frame.Portrait.backdrop._2d then
                            UnsnapTex(frame.Portrait.backdrop._2d)
                        end
                        if frame:IsElementEnabled("Portrait") and frame.Portrait.ForceUpdate then
                            frame.Portrait:ForceUpdate()
                        end
                    end
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        -- Use portrait's actual snapped width for flush alignment
                        if showPortrait and isAttached and frame.Portrait and frame.Portrait.backdrop then
                            local snappedPortW = frame.Portrait.backdrop:GetWidth()
                            healthXOffset = (effectiveSide == "left") and snappedPortW or 0
                            healthRightInset = (effectiveSide == "right") and snappedPortW or 0
                        end
                        frame.Health._xOffset = healthXOffset
                        frame.Health._rightInset = healthRightInset
                        local powerAboveOff = (ppPos == "above") and settings.powerHeight or 0
                        local hTopOff = cpAboveH + powerAboveOff + (btbPos == "top" and settings.bottomTextBar and (settings.bottomTextBarHeight or 16) or 0)
                        frame.Health._topOffset = hTopOff
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", healthXOffset, -hTopOff)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -healthRightInset, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                    end
                    if frame.Power then
                        local pw = settings.frameWidth
                        local ppIsDetached = (ppPos == "detached_top" or ppPos == "detached_bottom")
                        if ppIsDetached and (settings.powerWidth or 0) > 0 then
                            pw = settings.powerWidth
                        end
                        PP.Size(frame.Power, pw, settings.powerHeight)
                        frame.Power:ClearAllPoints()
                        if ppPos == "none" then
                            frame.Power:Hide()
                        elseif ppPos == "above" then
                            PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                            PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                            frame.Power:Show()
                        elseif ppPos == "detached_top" then
                            frame.Power:SetPoint("BOTTOM", frame.Health, "TOP", settings.powerX or 0, 15 + (settings.powerY or 0))
                            frame.Power:Show()
                        elseif ppPos == "detached_bottom" then
                            frame.Power:SetPoint("TOP", frame.Health, "BOTTOM", settings.powerX or 0, -15 + (settings.powerY or 0))
                            frame.Power:Show()
                        else
                            PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                            PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                            frame.Power:Show()
                        end
                        if frame.Power._applyPowerPercentText then frame.Power._applyPowerPercentText(settings) end

                        -- Gray out power bar background for generic melee NPCs
                        if ppPos ~= "none" and (ppPos == "below" or ppPos == "above") then
                            local shouldGray = false
                            if unit ~= "player" and UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsPlayer(unit) then
                                local cls = UnitClassification(unit)
                                local isBoss = (cls == "worldboss")
                                local isElite = (cls == "elite" or cls == "rareelite")
                                local lvl = UnitLevel(unit)
                                local pLvl = UnitLevel("player")
                                local isMB = isElite and (lvl == -1 or (pLvl and lvl >= pLvl + 1))
                                local isCst = (UnitClassBase and UnitClassBase(unit) == "PALADIN")
                                if not isBoss and not isMB and not isCst then shouldGray = true end
                            end
                            if shouldGray then
                                frame.Power._grayedOut = true
                                if frame.Power.bg then
                                    frame.Power.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
                                    frame.Power.bg:SetAlpha(1)
                                end
                            else
                                frame.Power._grayedOut = false
                            end
                        end
                    end
                    if frame.Castbar then
                        local castbarBg = frame.Castbar:GetParent()
                        if settings.showPlayerCastbar then
                            if not frame:IsElementEnabled("Castbar") then
                                frame:EnableElement("Castbar")
                            end
                            if castbarBg then
                                local castBarOffset = 0
                                if showPortrait and isAttached then
                                    castBarOffset = (effectiveSide == "left") and -(adjPortraitH / 2) or (adjPortraitH / 2)
                                end
                                local cbW = totalWidth
                                local cbH = settings.castbarHeight or 14
                                local owH = settings.playerCastbarHeight or 0
                                if owH > 0 then cbH = owH end
                                castbarBg:SetSize(cbW, cbH)
                                if frame.Castbar._iconFrame then
                                    frame.Castbar._iconFrame:SetSize(cbH + 1, cbH + 1)
                                    if frame.Castbar._updateIconLayout then frame.Castbar._updateIconLayout() end
                                end
                                castbarBg:ClearAllPoints()
                                local pBtbPos = settings.btbPosition or "bottom"
                                local pBtbVisible = (settings.bottomTextBar and pBtbPos == "bottom" and frame.BottomTextBar and frame.BottomTextBar:IsShown())
                                local anchorFrame = pBtbVisible and frame.BottomTextBar or (ppIsAtt and frame.Power) or frame.Health
                                local pCbXOff = pBtbVisible and 0 or castBarOffset
                                -- Player castbar is always locked to frame ? no x/y offsets
                                castbarBg:SetPoint("TOP", anchorFrame, "BOTTOM", pCbXOff, 0)
                                if frame.Castbar._syncInactiveVisibility then
                                    frame.Castbar._syncInactiveVisibility()
                                end
                            end
                            -- Store per-unit settings for PostCastStart
                            frame.Castbar._eufSettings = settings
                            local pCbColor = ResolveCastbarFillColor("player", settings)
                            frame.Castbar:SetStatusBarColor(pCbColor.r, pCbColor.g, pCbColor.b, castbarOpacity)
                            -- Apply cast bar text settings
                            if frame.Castbar.Text then
                                local snSz = settings.castSpellNameSize or 11
                                SetFSFont(frame.Castbar.Text, snSz)
                                local snC = settings.castSpellNameColor or { r=1, g=1, b=1 }
                                frame.Castbar.Text:SetTextColor(snC.r, snC.g, snC.b)
                            end
                            if frame.Castbar.Time then
                                local dtSz = settings.castDurationSize or 11
                                SetFSFont(frame.Castbar.Time, dtSz)
                                local dtC = settings.castDurationColor or { r=1, g=1, b=1 }
                                frame.Castbar.Time:SetTextColor(dtC.r, dtC.g, dtC.b)
                            end
                        else
                            if frame:IsElementEnabled("Castbar") then
                                frame:DisableElement("Castbar")
                            end
                            frame.Castbar:Hide()
                            if castbarBg then castbarBg:Hide() end
                        end
                    end

                    -- Live toggle player absorbs
                    if frame.HealthPrediction then
                        if settings.showPlayerAbsorb then
                            if not frame:IsElementEnabled("HealthPrediction") then
                                frame:EnableElement("HealthPrediction")
                            end
                            if frame.HealthPrediction.damageAbsorb then
                                frame.HealthPrediction.damageAbsorb:Show()
                            end
                            if frame.HealthPrediction.ForceUpdate then
                                frame.HealthPrediction:ForceUpdate()
                            elseif frame.UpdateAllElements then
                                frame:UpdateAllElements("ReloadFrames")
                            end
                        else
                            if frame:IsElementEnabled("HealthPrediction") then
                                frame:DisableElement("HealthPrediction")
                            end
                            if frame.HealthPrediction.damageAbsorb then
                                frame.HealthPrediction.damageAbsorb:Hide()
                            end
                        end
                    end

                    -- Live toggle player buffs
                    if frame.Buffs then
                        if settings.showBuffs then
                            if not frame:IsElementEnabled("Buffs") then
                                frame:EnableElement("Buffs")
                            end
                            frame.Buffs:Show()
                            frame.Buffs.num = settings.maxBuffs or 4
                            -- Reposition buffs based on anchor/growth settings
                            local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
                                settings.buffAnchor, settings.buffGrowth
                            )
                            -- Offset bottom-anchored buffs below castbar when locked to frame
                            local buffCbOff = 0
                            if (settings.buffAnchor == "bottomleft" or settings.buffAnchor == "bottomright"
                                or settings.buffAnchor == "left" or settings.buffAnchor == "right")
                                and settings.showPlayerCastbar then
                                local cbH = settings.playerCastbarHeight or 0
                                if cbH <= 0 then cbH = 14 end
                                buffCbOff = -cbH
                            end
                            -- Only reanchor + ForceUpdate when layout actually changed
                            local buffKey = (bia or "") .. (bfp or "") .. (box or 0) .. (boy or 0) .. buffCbOff .. (bgx or 0) .. (bgy or 0) .. (settings.maxBuffs or 4)
                            if frame.Buffs._lastBuffKey ~= buffKey then
                                frame.Buffs._lastBuffKey = buffKey
                                frame.Buffs:ClearAllPoints()
                                frame.Buffs:SetPoint(bia, frame, bfp, box * 1, boy * 1 + buffCbOff)
                                frame.Buffs.initialAnchor = bia
                                frame.Buffs.growthX = bgx
                                frame.Buffs.growthY = bgy
                                if frame.Buffs.ForceUpdate then
                                    frame.Buffs:ForceUpdate()
                                end
                            end
                        else
                            if frame:IsElementEnabled("Buffs") then
                                frame:DisableElement("Buffs")
                            end
                            frame.Buffs:Hide()
                            frame.Buffs.num = 0
                        end
                    end

                    -- Reposition name and health text (player)
                    if frame._applyTextTags then
                        frame._applyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "both", settings.centerTextContent or "none")
                    end
                    if frame._applyTextPositions then
                        frame._applyTextPositions(settings)
                    end

                    -- Bottom Text Bar update (player)
                    if settings.bottomTextBar then
                        local btbPos2 = settings.btbPosition or "bottom"
                        local btbIsAtt = (btbPos2 == "top" or btbPos2 == "bottom")
                        local btbIsDetached = not btbIsAtt
                        local btbW2 = btbIsDetached and (settings.btbWidth or 0) or 0
                        local btbTW = (btbW2 > 0 and btbIsDetached) and btbW2 or totalWidth
                        -- Compute BTB xOffset for left-side portrait (attached only)
                        local btbXOff = 0
                        if btbIsAtt and showPortrait and isAttached and effectiveSide == "left" then
                            btbXOff = -adjPortraitH
                        end
                        local ppBtbAnchor = (ppIsAtt and frame.Power) or frame.Health
                        if not frame.BottomTextBar then
                            frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, ppBtbAnchor, btbXOff, totalWidth)
                            frame._btb = frame.BottomTextBar
                        else
                            local btb = frame.BottomTextBar
                            PP.Size(btb, btbTW, settings.bottomTextBarHeight or 16)
                            btb:ClearAllPoints()
                            if btbPos2 == "top" then
                                PP.Point(btb, "BOTTOMLEFT", frame.Health or frame, "TOPLEFT", btbXOff, 0)
                            elseif btbPos2 == "detached_top" then
                                btb:SetPoint("BOTTOM", frame, "TOP", settings.btbX or 0, 15 + (settings.btbY or 0))
                            elseif btbPos2 == "detached_bottom" then
                                btb:SetPoint("TOP", frame, "BOTTOM", settings.btbX or 0, -15 + (settings.btbY or 0))
                            else
                                PP.Point(btb, "TOPLEFT", ppBtbAnchor, "BOTTOMLEFT", btbXOff, 0)
                            end
                            -- Update BTB bg color
                            if btb.bg then
                                local bgc = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
                                local bga = settings.btbBgOpacity or 1.0
                                btb.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, bga)
                            end
                            if btb._applyBTBTextTags then
                                btb._applyBTBTextTags(settings.btbLeftContent or "none", settings.btbRightContent or "none", settings.btbCenterContent or "none")
                            end
                            if btb._applyBTBTextPositions then
                                btb._applyBTBTextPositions(settings)
                if btb._applyBTBClassIcon then btb._applyBTBClassIcon(settings) end
                            end
                            btb:Show()
                        end
                    elseif frame.BottomTextBar then
                        frame.BottomTextBar:Hide()
                    end

                    if frame.KTDispelSlots then
                        frame.KTDispelSlots:SetShown(settings.dispelOverlay ~= false)
                        if _G.KTAuraKit and frame._ktDispelPrefix then
                            _G.KTAuraKit.ConfigureDispelSlotStyles(frame._ktDispelPrefix, frame.Health, {
                                alpha = 1,
                                thickness = 2,
                                colors = settings,
                            })
                        end
                    end
                    if frame.dispelBorderFrame then
                        frame.dispelBorderFrame:SetShown(settings.dispelOverlay ~= false)
                    end

                    UpdateBordersForScale(frame, unit)

                elseif unit == "target" then
                    local pSide = settings.portraitSide or "right"
                    local effectiveSide = pSide
                    if isAttached and pSide == "top" then effectiveSide = "right" end
                    local adjPortraitH = playerTargetHeight + pSizeAdj
                    if adjPortraitH < 8 then adjPortraitH = 8 end
                    if not showPortrait then
                        totalWidth = settings.frameWidth
                        portraitHeight = 0
                    elseif isAttached then
                        totalWidth = adjPortraitH + settings.frameWidth
                        portraitHeight = adjPortraitH
                    else
                        totalWidth = settings.frameWidth
                        portraitHeight = 0
                    end
                    -- Health bar xOffset: only offset when portrait is attached on the left
                    local healthXOffset = 0
                    local healthRightInset = 0
                    if showPortrait and isAttached and effectiveSide == "left" then
                        healthXOffset = portraitHeight
                    elseif showPortrait and isAttached and effectiveSide == "right" then
                        healthRightInset = portraitHeight
                    end

                    PP.Size(frame, totalWidth, targetFrameHeight)

                    if frame.Portrait and frame.Portrait.backdrop then
                        PP.Size(frame.Portrait.backdrop, adjPortraitH, adjPortraitH)
                        frame.Portrait.backdrop:ClearAllPoints()
                        local btbTopOff = (btbPos == "top" and settings.bottomTextBar) and (settings.bottomTextBarHeight or 16) or 0
                        if isAttached then
                            if effectiveSide == "left" then
                                PP.Point(frame.Portrait.backdrop, "TOPLEFT", frame, "TOPLEFT", 0, -btbTopOff)
                            else
                                PP.Point(frame.Portrait.backdrop, "TOPRIGHT", frame, "TOPRIGHT", 0, -btbTopOff)
                            end
                        else
                            if effectiveSide == "top" then
                                frame.Portrait.backdrop:SetPoint("BOTTOM", frame.Health or frame, "TOP", pXOff, 15 + pYOff)
                            elseif effectiveSide == "left" then
                                frame.Portrait.backdrop:SetPoint("TOPRIGHT", frame.Health or frame, "TOPLEFT", -15 + pXOff, pYOff)
                            else
                                frame.Portrait.backdrop:SetPoint("TOPLEFT", frame.Health or frame, "TOPRIGHT", 15 + pXOff, pYOff)
                            end
                        end
                        if frame.Portrait.backdrop._2d then
                            UnsnapTex(frame.Portrait.backdrop._2d)
                        end
                        if frame:IsElementEnabled("Portrait") and frame.Portrait.ForceUpdate then
                            frame.Portrait:ForceUpdate()
                        end
                    end
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        -- Use portrait's actual snapped width for flush alignment
                        if showPortrait and isAttached and frame.Portrait and frame.Portrait.backdrop then
                            local snappedPortW = frame.Portrait.backdrop:GetWidth()
                            healthXOffset = (effectiveSide == "left") and snappedPortW or 0
                            healthRightInset = (effectiveSide == "right") and snappedPortW or 0
                        end
                        local tBtbTopOff = (btbPos == "top" and settings.bottomTextBar and (settings.bottomTextBarHeight or 16) or 0)
                        local tPowerAboveOff = (ppPos == "above") and settings.powerHeight or 0
                        local tTopOff = tBtbTopOff + tPowerAboveOff
                        frame.Health._xOffset = healthXOffset
                        frame.Health._rightInset = healthRightInset
                        frame.Health._topOffset = tTopOff
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", healthXOffset, -tTopOff)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -healthRightInset, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                    end
                    if frame.Power then
                        local pw2 = settings.frameWidth
                        local ppIsDetached2 = (ppPos == "detached_top" or ppPos == "detached_bottom")
                        if ppIsDetached2 and (settings.powerWidth or 0) > 0 then
                            pw2 = settings.powerWidth
                        end
                        PP.Size(frame.Power, pw2, settings.powerHeight)
                        frame.Power:ClearAllPoints()
                        if ppPos == "none" then
                            frame.Power:Hide()
                        elseif ppPos == "above" then
                            PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                            PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                            frame.Power:Show()
                        elseif ppPos == "detached_top" then
                            frame.Power:SetPoint("BOTTOM", frame.Health, "TOP", settings.powerX or 0, 15 + (settings.powerY or 0))
                            frame.Power:Show()
                        elseif ppPos == "detached_bottom" then
                            frame.Power:SetPoint("TOP", frame.Health, "BOTTOM", settings.powerX or 0, -15 + (settings.powerY or 0))
                            frame.Power:Show()
                        else
                            PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                            PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                            frame.Power:Show()
                        end
                        if frame.Power._applyPowerPercentText then frame.Power._applyPowerPercentText(settings) end

                        -- Gray out power bar background for generic melee NPCs
                        if ppPos ~= "none" and (ppPos == "below" or ppPos == "above") then
                            local shouldGray = false
                            if unit ~= "player" and UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsPlayer(unit) then
                                local cls = UnitClassification(unit)
                                local isBoss = (cls == "worldboss")
                                local isElite = (cls == "elite" or cls == "rareelite")
                                local lvl = UnitLevel(unit)
                                local pLvl = UnitLevel("player")
                                local isMB = isElite and (lvl == -1 or (pLvl and lvl >= pLvl + 1))
                                local isCst = (UnitClassBase and UnitClassBase(unit) == "PALADIN")
                                if not isBoss and not isMB and not isCst then shouldGray = true end
                            end
                            if shouldGray then
                                frame.Power._grayedOut = true
                                if frame.Power.bg then
                                    frame.Power.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
                                    frame.Power.bg:SetAlpha(1)
                                end
                            else
                                frame.Power._grayedOut = false
                            end
                        end
                    end

                    -- Reposition name and health text
                    if frame._applyTextTags then
                        frame._applyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "both", settings.centerTextContent or "none")
                    end
                    if frame._applyTextPositions then
                        frame._applyTextPositions(settings)
                    end

                    -- Bottom Text Bar update (target) ? must come before castbar so castbar can anchor to it
                    local tPpBtbAnchor = (ppIsAtt and frame.Power) or frame.Health
                    if settings.bottomTextBar then
                        local btbPos2 = settings.btbPosition or "bottom"
                        local btbIsAtt = (btbPos2 == "top" or btbPos2 == "bottom")
                        local btbIsDetached = not btbIsAtt
                        local btbW2 = btbIsDetached and (settings.btbWidth or 0) or 0
                        local btbTW = (btbW2 > 0 and btbIsDetached) and btbW2 or totalWidth
                        local btbXOff = 0
                        if btbIsAtt and showPortrait and isAttached and effectiveSide == "left" then
                            btbXOff = -adjPortraitH
                        end
                        if not frame.BottomTextBar then
                            frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, tPpBtbAnchor, btbXOff, totalWidth)
                            frame._btb = frame.BottomTextBar
                        else
                            local btb = frame.BottomTextBar
                            PP.Size(btb, btbTW, settings.bottomTextBarHeight or 16)
                            btb:ClearAllPoints()
                            if btbPos2 == "top" then
                                PP.Point(btb, "BOTTOMLEFT", frame.Health or frame, "TOPLEFT", btbXOff, 0)
                            elseif btbPos2 == "detached_top" then
                                btb:SetPoint("BOTTOM", frame, "TOP", settings.btbX or 0, 15 + (settings.btbY or 0))
                            elseif btbPos2 == "detached_bottom" then
                                btb:SetPoint("TOP", frame, "BOTTOM", settings.btbX or 0, -15 + (settings.btbY or 0))
                            else
                                PP.Point(btb, "TOPLEFT", tPpBtbAnchor, "BOTTOMLEFT", btbXOff, 0)
                            end
                            if btb.bg then
                                local bgc = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
                                local bga = settings.btbBgOpacity or 1.0
                                btb.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, bga)
                            end
                            if btb._applyBTBTextTags then
                                btb._applyBTBTextTags(settings.btbLeftContent or "none", settings.btbRightContent or "none", settings.btbCenterContent or "none")
                            end
                            if btb._applyBTBTextPositions then
                                btb._applyBTBTextPositions(settings)
                                if btb._applyBTBClassIcon then btb._applyBTBClassIcon(settings) end
                            end
                            btb:Show()
                        end
                    elseif frame.BottomTextBar then
                        frame.BottomTextBar:Hide()
                    end

                    -- Castbar (target) ? anchors to BTB when BTB is bottom, otherwise to power/health
                    if frame.Castbar then
                        local castbarBg = frame.Castbar:GetParent()
                        if castbarBg then
                            if settings.showCastbar ~= false then
                                if not frame:IsElementEnabled("Castbar") then
                                    frame:EnableElement("Castbar")
                                end
                                local castBarOffset = 0
                                if showPortrait and isAttached then
                                    castBarOffset = (effectiveSide == "left") and -(adjPortraitH / 2) or (adjPortraitH / 2)
                                end
                                castbarBg:SetSize(totalWidth, settings.castbarHeight or 14)
                                if frame.Castbar._iconFrame then
                                    local cbH = settings.castbarHeight or 14
                                    frame.Castbar._iconFrame:SetSize(cbH + 1, cbH + 1)
                                    if frame.Castbar._updateIconLayout then frame.Castbar._updateIconLayout() end
                                end
                                castbarBg:ClearAllPoints()
                                local tBtbPos = settings.btbPosition or "bottom"
                                local btbVisible = (settings.bottomTextBar and tBtbPos == "bottom" and frame.BottomTextBar and frame.BottomTextBar:IsShown())
                                local cbAnchor = btbVisible and frame.BottomTextBar or tPpBtbAnchor
                                local cbXOff = btbVisible and 0 or castBarOffset
                                castbarBg:SetPoint("TOP", cbAnchor, "BOTTOM", cbXOff, 0)
                                if frame.Castbar._syncInactiveVisibility then
                                    frame.Castbar._syncInactiveVisibility()
                                end
                            else
                                if frame:IsElementEnabled("Castbar") then
                                    frame:DisableElement("Castbar")
                                end
                                frame.Castbar:Hide()
                                castbarBg:Hide()
                            end
                        end
                        -- Store per-unit settings for PostCastStart
                        frame.Castbar._eufSettings = settings
                        local tCbColor = ResolveCastbarFillColor("target", settings)
                        frame.Castbar:SetStatusBarColor(tCbColor.r, tCbColor.g, tCbColor.b, castbarOpacity)
                        -- Apply cast bar text settings
                        if frame.Castbar.Text then
                            local snSz = settings.castSpellNameSize or 11
                            SetFSFont(frame.Castbar.Text, snSz)
                            local snC = settings.castSpellNameColor or { r=1, g=1, b=1 }
                            frame.Castbar.Text:SetTextColor(snC.r, snC.g, snC.b)
                        end
                        if frame.Castbar.Time then
                            local dtSz = settings.castDurationSize or 11
                            SetFSFont(frame.Castbar.Time, dtSz)
                            local dtC = settings.castDurationColor or { r=1, g=1, b=1 }
                            frame.Castbar.Time:SetTextColor(dtC.r, dtC.g, dtC.b)
                        end
                    end

                    -- Buffs
                    if frame.Buffs then
                        local showBuffs = settings.showBuffs ~= false
                        if showBuffs then
                            if not frame:IsElementEnabled("Buffs") then
                                frame:EnableElement("Buffs")
                            end
                            frame.Buffs:Show()
                            frame.Buffs.num = settings.maxBuffs or 20
                            local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
                                settings.buffAnchor, settings.buffGrowth
                            )
                            local liveCbOff = 0
                            if settings.showCastbar ~= false then
                                local bAnc = settings.buffAnchor or "topleft"
                                if bAnc == "bottomleft" or bAnc == "bottomright" then
                                    local cbH = settings.castbarHeight or 14
                                    if cbH <= 0 then cbH = 14 end
                                    liveCbOff = -cbH
                                end
                            end
                            local buffKey = (bia or "") .. (bfp or "") .. (box or 0) .. (boy or 0) .. (bgx or 0) .. (bgy or 0) .. (settings.maxBuffs or 20) .. liveCbOff
                            if frame.Buffs._lastBuffKey ~= buffKey then
                                frame.Buffs._lastBuffKey = buffKey
                                frame.Buffs:ClearAllPoints()
                                frame.Buffs:SetPoint(bia, frame, bfp, box * 1, boy * 1 + liveCbOff)
                                frame.Buffs.initialAnchor = bia
                                frame.Buffs.growthX = bgx
                                frame.Buffs.growthY = bgy
                                if frame.Buffs.ForceUpdate then
                                    frame.Buffs:ForceUpdate()
                                end
                            end
                        else
                            if frame:IsElementEnabled("Buffs") then
                                frame:DisableElement("Buffs")
                            end
                            frame.Buffs:Hide()
                            frame.Buffs.num = 0
                        end
                    end

                    -- Debuffs
                    if frame.KTDebuffs then
                        ApplyTargetAuraSettings(frame, settings)
                    elseif frame.Debuffs then
                        frame.Debuffs.num = settings.maxDebuffs or 20
                        frame.Debuffs.onlyShowPlayer = settings.onlyPlayerDebuffs and true or nil
                        local dfp, dia, dgx, dgy, dox, doy = ResolveBuffLayout(
                            settings.debuffAnchor or "bottomleft",
                            settings.debuffGrowth or "auto"
                        )
                        local liveDbCbOff = 0
                        if settings.showCastbar ~= false then
                            local dAnc = settings.debuffAnchor or "bottomleft"
                            if dAnc == "bottomleft" or dAnc == "bottomright" then
                                local cbH = settings.castbarHeight or 14
                                if cbH <= 0 then cbH = 14 end
                                liveDbCbOff = -cbH
                            end
                        end
                        local debuffKey = (dia or "") .. (dfp or "") .. (dox or 0) .. (doy or 0) .. (dgx or 0) .. (dgy or 0) .. (settings.maxDebuffs or 20) .. liveDbCbOff .. (settings.onlyPlayerDebuffs and "1" or "0")
                        if frame.Debuffs._lastDebuffKey ~= debuffKey then
                            frame.Debuffs._lastDebuffKey = debuffKey
                            frame.Debuffs:ClearAllPoints()
                            frame.Debuffs:SetPoint(dia, frame, dfp, dox * 1, doy * 1 + liveDbCbOff)
                            frame.Debuffs.initialAnchor = dia
                            frame.Debuffs.growthX = dgx
                            frame.Debuffs.growthY = dgy
                            if frame.Debuffs.ForceUpdate then
                                frame.Debuffs:ForceUpdate()
                            end
                        end
                    end

                    UpdateBordersForScale(frame, unit)
                end

                -- (health tag re-tagging now handled by _applyTextTags above)

            elseif unit == "focus" then
                local fPpPos = settings.powerPosition or "below"
                local fPpIsAtt = (fPpPos == "below" or fPpPos == "above")
                local powerHeight = fPpIsAtt and (settings.powerHeight or 6) or 0
                local focusBarHeight = settings.healthHeight + powerHeight
                local fBtbPos = settings.btbPosition or "bottom"
                local fBtbIsAtt = (fBtbPos == "top" or fBtbPos == "bottom")
                local fBtbExtra = (settings.bottomTextBar and fBtbIsAtt) and (settings.bottomTextBarHeight or 16) or 0
                local totalWidth = 0
                local isAttached = (db.profile.portraitStyle or "attached") == "attached"
                local pSide = settings.portraitSide or "right"
                local effectiveSide = pSide
                if isAttached and pSide == "top" then effectiveSide = "right" end
                local pSizeAdj = settings.portraitSize or 0
                if not isAttached then pSizeAdj = pSizeAdj + 10 end
                local pXOff = settings.portraitX or 0
                local pYOff = settings.portraitY or 0
                if not isAttached then pYOff = pYOff + 5 end
                local adjPortraitH = focusBarHeight + pSizeAdj
                if adjPortraitH < 8 then adjPortraitH = 8 end

                if not showPortrait then
                    totalWidth = settings.frameWidth
                elseif isAttached then
                    totalWidth = adjPortraitH + settings.frameWidth
                else
                    totalWidth = settings.frameWidth
                end

                PP.Size(frame, totalWidth, focusBarHeight + fBtbExtra)

                if frame.Portrait and frame.Portrait.backdrop then
                    PP.Size(frame.Portrait.backdrop, adjPortraitH, adjPortraitH)
                    -- Trim portrait to stay within frame bounds
                    if showPortrait and isAttached then
                        local frameW = frame:GetWidth()
                        local frameH = frame:GetHeight()
                        local portW = frame.Portrait.backdrop:GetWidth()
                        local portH = frame.Portrait.backdrop:GetHeight()
                        if portW + settings.frameWidth > frameW + 0.01 then
                            PP.Width(frame.Portrait.backdrop, frameW - settings.frameWidth)
                        end
                        if portH > frameH + 0.01 then
                            PP.Height(frame.Portrait.backdrop, frameH)
                        end
                    end
                    -- Reposition portrait for attached/detached
                    frame.Portrait.backdrop:ClearAllPoints()
                    local fBtbTopOff = (fBtbPos == "top" and settings.bottomTextBar) and (settings.bottomTextBarHeight or 16) or 0
                    if isAttached then
                        if effectiveSide == "left" then
                            PP.Point(frame.Portrait.backdrop, "TOPLEFT", frame, "TOPLEFT", 0, -fBtbTopOff)
                        else
                            PP.Point(frame.Portrait.backdrop, "TOPRIGHT", frame, "TOPRIGHT", 0, -fBtbTopOff)
                        end
                    else
                        if effectiveSide == "top" then
                            frame.Portrait.backdrop:SetPoint("BOTTOM", frame.Health or frame, "TOP", pXOff, 15 + pYOff)
                        elseif effectiveSide == "left" then
                            frame.Portrait.backdrop:SetPoint("TOPRIGHT", frame.Health or frame, "TOPLEFT", -15 + pXOff, pYOff)
                        else
                            frame.Portrait.backdrop:SetPoint("TOPLEFT", frame.Health or frame, "TOPRIGHT", 15 + pXOff, pYOff)
                        end
                    end
                    -- Re-apply pixel snap disable after resize
                    if frame.Portrait.backdrop._2d then
                        UnsnapTex(frame.Portrait.backdrop._2d)
                    end
                    if frame:IsElementEnabled("Portrait") and frame.Portrait.ForceUpdate then
                        frame.Portrait:ForceUpdate()
                    end
                end
                if frame.Health then
                    frame.Health:ClearAllPoints()
                    local focusHealthXOff = (showPortrait and isAttached and effectiveSide == "left") and adjPortraitH or 0
                    local focusHealthRightInset = (showPortrait and isAttached and effectiveSide == "right") and adjPortraitH or 0
                    -- Use portrait's actual snapped width for flush alignment
                    if showPortrait and isAttached and frame.Portrait and frame.Portrait.backdrop then
                        local snappedPortW = frame.Portrait.backdrop:GetWidth()
                        focusHealthXOff = (effectiveSide == "left") and snappedPortW or 0
                        focusHealthRightInset = (effectiveSide == "right") and snappedPortW or 0
                    end
                    local fHTopOff = (fBtbPos == "top" and settings.bottomTextBar and (settings.bottomTextBarHeight or 16) or 0)
                    local fPowerAboveOff = (fPpPos == "above") and (settings.powerHeight or 6) or 0
                    fHTopOff = fHTopOff + fPowerAboveOff
                    frame.Health._xOffset = focusHealthXOff
                    frame.Health._rightInset = focusHealthRightInset
                    frame.Health._topOffset = fHTopOff
                    PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", focusHealthXOff, -fHTopOff)
                    PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -focusHealthRightInset, 0)
                    PP.Height(frame.Health, settings.healthHeight)
                end
                if frame.Power then
                    local fpw = settings.frameWidth
                    local fPpIsDet = (fPpPos == "detached_top" or fPpPos == "detached_bottom")
                    if fPpIsDet and (settings.powerWidth or 0) > 0 then
                        fpw = settings.powerWidth
                    end
                    PP.Size(frame.Power, fpw, settings.powerHeight or 6)
                    frame.Power:ClearAllPoints()
                    if fPpPos == "none" then
                        frame.Power:Hide()
                    elseif fPpPos == "above" then
                        PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                        PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                        frame.Power:Show()
                    elseif fPpPos == "detached_top" then
                        frame.Power:SetPoint("BOTTOM", frame.Health, "TOP", settings.powerX or 0, 15 + (settings.powerY or 0))
                        frame.Power:Show()
                    elseif fPpPos == "detached_bottom" then
                        frame.Power:SetPoint("TOP", frame.Health, "BOTTOM", settings.powerX or 0, -15 + (settings.powerY or 0))
                        frame.Power:Show()
                    else
                        PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                        PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                        frame.Power:Show()
                    end
                    if frame.Power._applyPowerPercentText then frame.Power._applyPowerPercentText(settings) end
                end
                if frame._applyTextTags then
                    frame._applyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "perhp", settings.centerTextContent or "none")
                end
                if frame._applyTextPositions then
                    frame._applyTextPositions(settings)
                end

                -- Bottom Text Bar update (focus) ? must come before castbar so castbar can anchor to it
                local fPpBtbAnchor = (fPpIsAtt and frame.Power) or frame.Health
                if settings.bottomTextBar then
                    local btbPos2 = settings.btbPosition or "bottom"
                    local btbIsAtt2 = (btbPos2 == "top" or btbPos2 == "bottom")
                    local btbIsDet2 = not btbIsAtt2
                    local btbW2 = btbIsDet2 and (settings.btbWidth or 0) or 0
                    local btbTW = (btbW2 > 0 and btbIsDet2) and btbW2 or totalWidth
                    local btbXOff = 0
                    if btbIsAtt2 and showPortrait and isAttached and effectiveSide == "left" then
                        btbXOff = -adjPortraitH
                    end
                    if not frame.BottomTextBar then
                        frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, fPpBtbAnchor, btbXOff, totalWidth)
                        frame._btb = frame.BottomTextBar
                    else
                        local btb = frame.BottomTextBar
                        PP.Size(btb, btbTW, settings.bottomTextBarHeight or 16)
                        btb:ClearAllPoints()
                        if btbPos2 == "top" then
                            PP.Point(btb, "BOTTOMLEFT", frame.Health or frame, "TOPLEFT", btbXOff, 0)
                        elseif btbPos2 == "detached_top" then
                            btb:SetPoint("BOTTOM", frame, "TOP", settings.btbX or 0, 15 + (settings.btbY or 0))
                        elseif btbPos2 == "detached_bottom" then
                            btb:SetPoint("TOP", frame, "BOTTOM", settings.btbX or 0, -15 + (settings.btbY or 0))
                        else
                            PP.Point(btb, "TOPLEFT", fPpBtbAnchor, "BOTTOMLEFT", btbXOff, 0)
                        end
                        if btb.bg then
                            local bgc = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
                            local bga = settings.btbBgOpacity or 1.0
                            btb.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, bga)
                        end
                        if btb._applyBTBTextTags then
                            btb._applyBTBTextTags(settings.btbLeftContent or "none", settings.btbRightContent or "none", settings.btbCenterContent or "none")
                        end
                        if btb._applyBTBTextPositions then
                            btb._applyBTBTextPositions(settings)
                            if btb._applyBTBClassIcon then btb._applyBTBClassIcon(settings) end
                        end
                        btb:Show()
                    end
                elseif frame.BottomTextBar then
                    frame.BottomTextBar:Hide()
                end

                -- Castbar (focus) ? anchors to BTB when BTB is bottom, otherwise to power/health
                if frame.Castbar then
                    local castbarBg = frame.Castbar:GetParent()
                    if castbarBg then
                        if settings.showCastbar ~= false then
                            if not frame:IsElementEnabled("Castbar") then
                                frame:EnableElement("Castbar")
                            end
                            local castBarOffset = 0
                            if showPortrait and isAttached then
                                castBarOffset = (effectiveSide == "left") and -(adjPortraitH / 2) or (adjPortraitH / 2)
                            end
                            castbarBg:SetSize(totalWidth, settings.castbarHeight or 14)
                            if frame.Castbar._iconFrame then
                                local cbH = settings.castbarHeight or 14
                                frame.Castbar._iconFrame:SetSize(cbH + 1, cbH + 1)
                                if frame.Castbar._updateIconLayout then frame.Castbar._updateIconLayout() end
                            end
                            castbarBg:ClearAllPoints()
                            local fBtbPos2 = settings.btbPosition or "bottom"
                            local btbVisible = (settings.bottomTextBar and fBtbPos2 == "bottom" and frame.BottomTextBar and frame.BottomTextBar:IsShown())
                            local cbAnchor = btbVisible and frame.BottomTextBar or fPpBtbAnchor
                            local cbXOff = btbVisible and 0 or castBarOffset
                            castbarBg:SetPoint("TOP", cbAnchor, "BOTTOM", cbXOff, 0)
                            if frame.Castbar._syncInactiveVisibility then
                                frame.Castbar._syncInactiveVisibility()
                            end
                        else
                            if frame:IsElementEnabled("Castbar") then
                                frame:DisableElement("Castbar")
                            end
                            frame.Castbar:Hide()
                            castbarBg:Hide()
                        end
                    end
                    -- Store per-unit settings for PostCastStart
                    frame.Castbar._eufSettings = settings
                    local fCbColor = ResolveCastbarFillColor("focus", settings)
                    frame.Castbar:SetStatusBarColor(fCbColor.r, fCbColor.g, fCbColor.b, castbarOpacity)
                    -- Apply cast bar text settings
                    if frame.Castbar.Text then
                        local snSz = settings.castSpellNameSize or 11
                        SetFSFont(frame.Castbar.Text, snSz)
                        local snC = settings.castSpellNameColor or { r=1, g=1, b=1 }
                        frame.Castbar.Text:SetTextColor(snC.r, snC.g, snC.b)
                    end
                    if frame.Castbar.Time then
                        local dtSz = settings.castDurationSize or 11
                        SetFSFont(frame.Castbar.Time, dtSz)
                        local dtC = settings.castDurationColor or { r=1, g=1, b=1 }
                        frame.Castbar.Time:SetTextColor(dtC.r, dtC.g, dtC.b)
                    end
                end

                UpdateBordersForScale(frame, unit)

            elseif unit == "pet" or unit == "targettarget" or unit == "focustarget" then
                if unit == "pet" then
                    local showPetPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
                    local petW = settings.frameWidth
                    if showPetPortrait then
                        petW = settings.healthHeight + settings.frameWidth
                    end
                    PP.Size(frame, petW, settings.healthHeight)
                    if frame.Portrait and frame.Portrait.backdrop then
                        PP.Size(frame.Portrait.backdrop, settings.healthHeight, settings.healthHeight)
                    end
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        -- Use portrait's actual snapped width for flush alignment
                        local petPortOff = 0
                        if showPetPortrait and frame.Portrait and frame.Portrait.backdrop then
                            petPortOff = frame.Portrait.backdrop:GetWidth()
                        elseif showPetPortrait then
                            petPortOff = settings.healthHeight
                        end
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", petPortOff, 0)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", 0, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                        frame.Health._xOffset = petPortOff
                        frame.Health._rightInset = 0
                        frame.Health._topOffset = 0
                    end
                else
                    PP.Size(frame, settings.frameWidth, settings.healthHeight)
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", 0, 0)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", 0, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                    end
                end

                UpdateBordersForScale(frame, unit)

            elseif unit:match("^boss%d$") then
                local bPpPos = settings.powerPosition or "below"
                local bPpIsAtt = (bPpPos == "below" or bPpPos == "above")
                local powerHeight = bPpIsAtt and (settings.powerHeight or 6) or 0
                local bossBarHeight = settings.healthHeight + powerHeight
                local totalWidth = 0

                if not showPortrait then
                    totalWidth = settings.frameWidth
                else
                    totalWidth = bossBarHeight + settings.frameWidth
                end

                PP.Size(frame, totalWidth, bossBarHeight)

                if frame.Portrait and frame.Portrait.backdrop then
                    PP.Size(frame.Portrait.backdrop, bossBarHeight, bossBarHeight)
                end
                if frame.Health then
                    frame.Health:ClearAllPoints()
                    -- Use portrait's actual snapped width for flush alignment
                    local bossRightInset = 0
                    if showPortrait then
                        if frame.Portrait and frame.Portrait.backdrop then
                            bossRightInset = frame.Portrait.backdrop:GetWidth()
                        else
                            bossRightInset = bossBarHeight
                        end
                    end
                    local bPowerAboveOff = (bPpPos == "above") and (settings.powerHeight or 6) or 0
                    PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", 0, -bPowerAboveOff)
                    PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -bossRightInset, 0)
                    PP.Height(frame.Health, settings.healthHeight)
                    frame.Health._xOffset = 0
                    frame.Health._rightInset = bossRightInset
                    frame.Health._topOffset = bPowerAboveOff
                end
                if frame.Power then
                    local bpw = settings.frameWidth
                    local bPpIsDet = (bPpPos == "detached_top" or bPpPos == "detached_bottom")
                    if bPpIsDet and (settings.powerWidth or 0) > 0 then
                        bpw = settings.powerWidth
                    end
                    frame.Power:SetSize(bpw, settings.powerHeight or 6)
                    frame.Power:ClearAllPoints()
                    if bPpPos == "none" then
                        frame.Power:Hide()
                    elseif bPpPos == "above" then
                        PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                        PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                        frame.Power:Show()
                    elseif bPpPos == "detached_top" then
                        frame.Power:SetPoint("BOTTOM", frame.Health, "TOP", settings.powerX or 0, 15 + (settings.powerY or 0))
                        frame.Power:Show()
                    elseif bPpPos == "detached_bottom" then
                        frame.Power:SetPoint("TOP", frame.Health, "BOTTOM", settings.powerX or 0, -15 + (settings.powerY or 0))
                        frame.Power:Show()
                    else
                        PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                        PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                        frame.Power:Show()
                    end
                    if frame.Power._applyPowerPercentText then frame.Power._applyPowerPercentText(settings) end

                    -- Gray out power bar background for generic melee NPCs
                    if bPpPos ~= "none" and (bPpPos == "below" or bPpPos == "above") then
                        local shouldGray = false
                        if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsPlayer(unit) then
                            local cls = UnitClassification(unit)
                            local isBoss = (cls == "worldboss")
                            local isElite = (cls == "elite" or cls == "rareelite")
                            local lvl = UnitLevel(unit)
                            local pLvl = UnitLevel("player")
                            local isMB = isElite and (lvl == -1 or (pLvl and lvl >= pLvl + 1))
                            local isCst = (UnitClassBase and UnitClassBase(unit) == "PALADIN")
                            if not isBoss and not isMB and not isCst then shouldGray = true end
                        end
                        if shouldGray then
                            frame.Power._grayedOut = true
                            if frame.Power.bg then
                                frame.Power.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
                                frame.Power.bg:SetAlpha(1)
                            end
                        else
                            frame.Power._grayedOut = false
                        end
                    end
                end

                UpdateBordersForScale(frame, unit)
            end

            -- Determine if this is a mini frame that inherits border/texture/font
            local isMiniFrame = (unit == "pet" or unit == "targettarget" or unit == "focustarget" or unit:match("^boss%d$"))
            local donorSettings = isMiniFrame and GetMiniDonorSettings() or settings

            -- Apply health bar texture overlay (use donor for mini frames)
            if isMiniFrame then
                -- Override texture settings from donor
                local uKey = UnitToSettingsKey(unit)
                local origTex = settings.healthBarTexture
                settings.healthBarTexture = donorSettings.healthBarTexture
                ApplyHealthBarTexture(frame.Health, uKey)
                settings.healthBarTexture = origTex
                ApplyHealthBarAlpha(frame.Health, uKey)
            else
                ApplyHealthBarTexture(frame.Health, UnitToSettingsKey(unit))
                ApplyHealthBarAlpha(frame.Health, UnitToSettingsKey(unit))
            end
            ApplyDarkTheme(frame.Health)
            if frame.Health.ForceUpdate then
                frame.Health:ForceUpdate()
            end

            -- Apply power bar opacity
            if frame.Power then
                ApplyPowerBarAlpha(frame.Power, UnitToSettingsKey(unit))

                -- Re-apply power bar fill color based on powerPercentPowerColor toggle
                local usePowerColor = settings.powerPercentPowerColor ~= false
                if usePowerColor then
                    frame.Power.colorPower = true
                    frame.Power.PostUpdateColor = nil
                else
                    local customFill = settings.customPowerFillColor
                    frame.Power.colorPower = false
                    if customFill then
                        frame.Power:SetStatusBarColor(customFill.r, customFill.g, customFill.b)
                        frame.Power.PostUpdateColor = function(self)
                            local s2 = GetSettingsForUnit(unit)
                            local cf = s2 and s2.customPowerFillColor
                            if cf then self:SetStatusBarColor(cf.r, cf.g, cf.b) end
                        end
                    else
                        frame.Power:SetStatusBarColor(0, 0, 1)
                        frame.Power.PostUpdateColor = function(self)
                            self:SetStatusBarColor(0, 0, 1)
                        end
                    end
                end
                local customBg = settings.customPowerBgColor
                if customBg and frame.Power.bg then
                    frame.Power.bg:SetColorTexture(customBg.r, customBg.g, customBg.b, 1)
                elseif frame.Power.bg then
                    frame.Power.bg:SetColorTexture(17/255, 17/255, 17/255, 1)
                end
                if frame.Power.ForceUpdate then frame.Power:ForceUpdate() end
            end

            if frame.unifiedBorder then
                frame.unifiedBorder:ClearAllPoints()
                local bs = donorSettings.borderSize or 1
                local bc = donorSettings.borderColor or { r = 0, g = 0, b = 0 }
                if bs == 0 then
                    frame.unifiedBorder:Hide()
                else
                    PP.Point(frame.unifiedBorder, "TOPLEFT", frame, "TOPLEFT", 0, 0)
                    PP.Point(frame.unifiedBorder, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                    PP.UpdateBorder(frame.unifiedBorder, bs, bc.r, bc.g, bc.b, 1)
                    frame.unifiedBorder:Show()
                end
            end

            -- Helper: set font on a FontString, using donor font for mini frames
            local function SetMiniFont(fs, sz)
                if not fs or not fs.SetFont then return end
                if isMiniFrame then
                    local f = (Compat and Compat.GetFontOutlineFlag and Compat.GetFontOutlineFlag()) or ""
                    fs:SetFont(donorFontPath, sz or 12, f)
                    if KT and KT.EnableTextFontFallback then
                        KT:EnableTextFontFallback(fs, donorFontPath)
                    end
                    if f == "" then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
                    else fs:SetShadowOffset(0, 0) end
                else
                    SetFSFont(fs, sz)
                end
            end

            if frame.NameText then
                local s = isMiniFrame and donorSettings or GetSettingsForUnit(unit)
                local rts = s.leftTextSize or s.textSize or 12
                SetMiniFont(frame.NameText, rts)
                frame.NameText:SetWordWrap(false)
            end
            if frame.HealthValue then
                local s = isMiniFrame and donorSettings or GetSettingsForUnit(unit)
                local rts = s.rightTextSize or s.textSize or 12
                SetMiniFont(frame.HealthValue, rts)
                frame.HealthValue:SetWordWrap(false)
            end
            if frame.CenterText then
                local s = isMiniFrame and donorSettings or GetSettingsForUnit(unit)
                local cts = s.centerTextSize or s.textSize or 12
                SetMiniFont(frame.CenterText, cts)
                frame.CenterText:SetWordWrap(false)
            end

            -- Apply text tags and positions for mini frames
            if isMiniFrame and frame._applyTextTags then
                frame._applyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "none", settings.centerTextContent or "none")
            end
            if isMiniFrame and frame._applyTextPositions then
                frame._applyTextPositions(settings)
            end

            if frame.Castbar then
                if frame.Castbar.Text then
                    SetFSFont(frame.Castbar.Text, 11)
                end
                if frame.Castbar.Time then
                    SetFSFont(frame.Castbar.Time, 11)
                end
            end
            end -- else (enabled frame processing)
        end
    end

    -- Apply frame scale for all units after layout (centered, animated)
    for unit, frame in pairs(frames) do
        if type(unit) == "string" and unit:sub(1,1) ~= "_" and frame then
            local s = GetSettingsForUnit(unit)
            local sc = (s and s.frameScale) or 100
            ApplyFrameScaleCentered(frame, unit, sc / 100, true)
        end
    end

    RefreshPlayerStatusIndicators()
    RefreshUnitFrameStrata()
end

local function UpdateBlizzardRestTargets(shouldShow)
    local blizzardRestTargets = {
        _G.PlayerRestIcon,
        _G.PlayerRestLoop,
        _G.PlayerRestGlow,
        _G.PlayerFrame and _G.PlayerFrame.PlayerRestIcon,
        _G.PlayerFrame and _G.PlayerFrame.PlayerRestLoop,
        _G.PlayerFrame and _G.PlayerFrame.PlayerRestGlow,
    }

    for i = 1, #blizzardRestTargets do
        local target = blizzardRestTargets[i]
        if target then
            if shouldShow then
                if target.SetAlpha then target:SetAlpha(1) end
                if target.Show then target:Show() end
            else
                if target.SetAlpha then target:SetAlpha(0) end
                if target.Hide then target:Hide() end
            end

            if not target._ktRestHideHooked and hooksecurefunc and target.Show then
                target._ktRestHideHooked = true
                hooksecurefunc(target, "Show", function(self)
                    if not IsResting() then
                        if self.SetAlpha then self:SetAlpha(0) end
                        self:Hide()
                    end
                end)
            end
        end
    end
end

RefreshPlayerStatusIndicators = function()
    local frame = frames and frames.player
    local playerDB = db and db.profile and db.profile.player
    if not frame or not playerDB then return end

    local combatStyle = NormalizeCombatIndicatorStyle(playerDB.combatIndicatorStyle)
    if frame._updateCombatIndicatorLayout then
        frame._updateCombatIndicatorLayout(playerDB)
    end
    if frame._updateCombatIndicatorVisuals then
        frame._updateCombatIndicatorVisuals(playerDB)
    end

    if frame.CombatIndicator then
        if combatStyle == "none" then
            if frame:IsElementEnabled("CombatIndicator") then
                frame:DisableElement("CombatIndicator")
            end
            frame.CombatIndicator:Hide()
        else
            if not frame:IsElementEnabled("CombatIndicator") then
                frame:EnableElement("CombatIndicator")
            end
            if frame.CombatIndicator.ForceUpdate then
                frame.CombatIndicator:ForceUpdate()
            end
        end
    end

    if frame._updateRestingIndicatorLayout then
        frame._updateRestingIndicatorLayout(playerDB)
    end

    if frame.RestingIndicator then
        if not frame:IsElementEnabled("RestingIndicator") then
            frame:EnableElement("RestingIndicator")
        end
        if frame.RestingIndicator.ForceUpdate then
            frame.RestingIndicator:ForceUpdate()
        end
    end

    UpdateBlizzardRestTargets(IsResting())
    
    -- Recalculate target frame position based on portrait configuration
    if frames.target then
        ApplyFramePosition(frames.target, "target")
    end
end

function Mod:UpdateRestingIndicator()
    RefreshPlayerStatusIndicators()
end

function InitializeFrames()
    if oUF and oUF.colors and oUF.colors.power then
        local manaColor = { r = MANA_COLOR.r, g = MANA_COLOR.g, b = MANA_COLOR.b }
        manaColor.GetRGB = function(self) return self.r, self.g, self.b end
        oUF.colors.power[0] = manaColor
    end

    if oUF.Tags and oUF.Tags.SetEventUpdateTimer then
        oUF.Tags:SetEventUpdateTimer(0.25)
    end

    local classPowerStyle = db.profile.player.classPowerStyle or "none"
    local savedClassPowerBar = nil
    if classPowerStyle == "blizzard" then
        if PlayerFrame and PlayerFrame.classPowerBar then
            savedClassPowerBar = PlayerFrame.classPowerBar
            PlayerFrame.classPowerBar = nil
            savedClassPowerBar:SetParent(UIParent)
        end
    end

    local enabled = db.profile.enabledFrames

    RegisterStylesOnce()

    local function SetupUnitMenu(frame, unit)
        frame:RegisterForClicks("AnyUp")
        frame:SetAttribute("*type1", "target")  -- Left-click targets the unit
        frame:SetAttribute("*type2", "togglemenu")  -- Right-click opens context menu
        
        -- Use PreClick to intercept Shift+Left-click BEFORE secure handler
        frame:HookScript("PreClick", function(self, button, down)
            if button == "LeftButton" and IsShiftKeyDown() and not InCombatLockdown() then
                if KT and KT.OpenMainMenu then
                    KT:OpenMainMenu()
                    C_Timer.After(0.1, function()
                        if KT.MenuPrincipal and KT.MenuPrincipal.NavigateToPage then
                            KT.MenuPrincipal:NavigateToPage("unitframes")
                        end
                    end)
                end
            end
        end)
        
        frame:HookScript("OnEnter", UnitFrame_OnEnter)
        frame:HookScript("OnLeave", UnitFrame_OnLeave)
    end

    -- Apply frame scale from per-unit settings
    local function ApplyFrameScale(frame, unit)
        if not frame then return end
        local settings = GetSettingsForUnit(unit)
        local scale = (settings and settings.frameScale) or 100
        ApplyFrameScaleCentered(frame, unit, scale / 100, false)
    end

    -- Always spawn all frames; hide disabled ones for zero performance impact
    oUF:SetActiveStyle("KUIPlayer")
    frames.player = oUF:Spawn("player", "KullThranUI_UF_Player")
    ApplyFramePosition(frames.player, "player")
    ApplyFrameScale(frames.player, "player")
    SetupUnitMenu(frames.player, "player")

    if enabled.player == false then
        frames.player:Hide()
        frames.player:SetAttribute("unit", nil)
    end

    RefreshPlayerStatusIndicators()

    -- The standalone CastBar module owns suppression of Blizzard's player cast bars.
    -- oUF also checks that module state before replacing the default bar.

    -- ─── ClassPower resize: medición separada de aplicación ─────────
    -- Fase 1 (MeasureClassPowerLayout): calcula dimensiones sin mutar frames
    -- Fase 2 (CommitClassPowerLayout): aplica el layout calculado al frame

    -- Fase 1: devuelve tabla con todas las dimensiones necesarias
    local function MeasureClassPowerLayout(cpAboveH)
        local settings = GetSettingsForUnit("player")
        local ppPos = settings.powerPosition or "below"
        local ppIsAtt = (ppPos == "below" or ppPos == "above")
        local ppExtra = ppIsAtt and settings.powerHeight or 0
        local baseH = settings.healthHeight + ppExtra
        local btbPos2 = settings.btbPosition or "bottom"
        local btbIsAtt = (btbPos2 == "top" or btbPos2 == "bottom")
        local btbExtra = (settings.bottomTextBar and btbIsAtt)
            and (settings.bottomTextBarHeight or 16) or 0

        local showPortrait = (db.profile.portraitStyle or "attached") ~= "none"
            and settings.showPortrait ~= false
        local isAttached = (db.profile.portraitStyle or "attached") == "attached"
        local pSizeAdj = settings.portraitSize or 0
        if not isAttached then pSizeAdj = pSizeAdj + 10 end
        local adjPH = baseH + cpAboveH + pSizeAdj
        if adjPH < 8 then adjPH = 8 end

        local pSide = settings.portraitSide or "left"
        local effSide = pSide
        if isAttached and pSide == "top" then effSide = "left" end

        local totalW, pW = settings.frameWidth, 0
        if showPortrait and isAttached then
            pW = adjPH
            totalW = pW + settings.frameWidth
        end

        return {
            totalW = totalW,   totalH = baseH + cpAboveH + btbExtra,
            pW     = pW,       adjPH  = adjPH,
            show   = showPortrait, att = isAttached, side = effSide,
        }
    end

    -- Fase 2: aplica las dimensiones al player frame
    local function CommitClassPowerLayout(lay)
        local f = frames.player
        if not f then return end
        PP.Size(f, lay.totalW, lay.totalH)

        -- Actualizar offsets del health bar según posición del retrato
        if f.Health then
            f.Health._xOffset    = (lay.show and lay.att and lay.side == "left")  and lay.pW or 0
            f.Health._rightInset = (lay.show and lay.att and lay.side == "right") and lay.pW or 0
        end

        -- Reposicionar retrato si es visible y attached
        local port = f.Portrait
        if port and port.backdrop and lay.show then
            PP.Size(port.backdrop, lay.adjPH, lay.adjPH)
            port.backdrop:ClearAllPoints()
            if lay.att then
                local anchor = lay.side == "left" and "TOPLEFT" or "TOPRIGHT"
                PP.Point(port.backdrop, anchor, f, anchor, 0, 0)
            end
            if port.backdrop._2d then UnsnapTex(port.backdrop._2d) end
            if f:IsElementEnabled("Portrait") and port.ForceUpdate then
                port:ForceUpdate()
            end
        end
    end

    -- Wrapper que mantiene la firma original para los 5 call sites
    local function ResizeFrameForClassPower(cpAboveH)
        if not frames.player then return end
        CommitClassPowerLayout(MeasureClassPowerLayout(cpAboveH))
    end

    local function PositionClassPowerBar(bar)
        if not bar or not frames.player then return end
        bar:ClearAllPoints()
        local style = db.profile.player.classPowerStyle or "none"
        local position = db.profile.player.classPowerPosition or "top"
        local offsetX = db.profile.player.classPowerBarX or 0
        local offsetY = db.profile.player.classPowerBarY or 0

        -- Stop castbar watcher by default; only re-enabled in the "bottom" branch
        if bar._castbarWatcher then
            bar._castbarWatcher:SetScript("OnUpdate", nil)
            bar._castbarWatcher:Hide()
        end

        if style == "modern" and position == "above" then
            -- Above health bar, inside the frame ? pips stretch to fill health bar width
            -- Bottom of pips flush with top of health bar, top of pips flush with top of border
            bar:SetParent(frames.player)
            local anchorFrame = frames.player.Health
            local pipH = bar._pipH or 3
            -- Resize frame/portrait BEFORE anchoring health bar so _xOffset is correct
            ResizeFrameForClassPower(pipH)
            local btbOff = 0
            local btbPos2 = db.profile.player.btbPosition or "bottom"
            if btbPos2 == "top" and db.profile.player.bottomTextBar then
                btbOff = db.profile.player.bottomTextBarHeight or 16
            end
            local cpPush = pipH + btbOff
            anchorFrame:ClearAllPoints()
            PP.Point(anchorFrame, "TOPLEFT", frames.player, "TOPLEFT", anchorFrame._xOffset or 0, -cpPush)
            PP.Point(anchorFrame, "RIGHT", frames.player, "RIGHT", -(anchorFrame._rightInset or 0), 0)
            PP.Point(bar, "BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 0)
            PP.Point(bar, "BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 0)
            local fw = db.profile.player.frameWidth or 181
            if bar._repositionForWidth then
                bar._repositionForWidth(fw)
            end
            -- Show 1px bottom border matching frame border color
            if bar._bottomBdrFrame then
                local bdrC = db.profile.player.borderColor or { r = 0, g = 0, b = 0 }
                bar._bottomBdr:SetColorTexture(bdrC.r, bdrC.g, bdrC.b, 1)
                bar._bottomBdrFrame:Show()
            end
        elseif style == "modern" and position == "top" then
            -- "top" floats above the frame (like "bottom" floats below) ? does NOT become part of the frame
            bar:SetParent(frames.player)
            ResizeFrameForClassPower(0)
            -- Reset health bar to normal position
            if frames.player.Health then
                local btbOff = 0
                local btbPos2 = db.profile.player.btbPosition or "bottom"
                if btbPos2 == "top" and db.profile.player.bottomTextBar then
                    btbOff = db.profile.player.bottomTextBarHeight or 16
                end
                frames.player.Health:ClearAllPoints()
                PP.Point(frames.player.Health, "TOPLEFT", frames.player, "TOPLEFT", frames.player.Health._xOffset or 0, -btbOff)
                PP.Point(frames.player.Health, "RIGHT", frames.player, "RIGHT", -(frames.player.Health._rightInset or 0), 0)
            end
            -- Center on health bar (ignores portrait)
            PP.Point(bar, "BOTTOM", frames.player.Health, "TOP", offsetX, offsetY)
            if bar._bottomBdrFrame then bar._bottomBdrFrame:Hide() end
        elseif not db.profile.player.lockClassPowerToFrame then
            -- Reset health bar to normal position
            if frames.player.Health then
                local btbOff = 0
                local btbPos2 = db.profile.player.btbPosition or "bottom"
                if btbPos2 == "top" and db.profile.player.bottomTextBar then
                    btbOff = db.profile.player.bottomTextBarHeight or 16
                end
                frames.player.Health:ClearAllPoints()
                PP.Point(frames.player.Health, "TOPLEFT", frames.player, "TOPLEFT", frames.player.Health._xOffset or 0, -btbOff)
                PP.Point(frames.player.Health, "RIGHT", frames.player, "RIGHT", -(frames.player.Health._rightInset or 0), 0)
            end
            bar:SetParent(UIParent)
            local pos = db.profile.positions.classPower
            if pos then
                PP.Point(bar, pos.point, UIParent, pos.point, pos.x, pos.y)
            else
                PP.Point(bar, "CENTER", UIParent, "CENTER", 0, -220)
            end
            ResizeFrameForClassPower(0)
            if bar._bottomBdrFrame then bar._bottomBdrFrame:Hide() end
        else
            -- Reset health bar to normal position
            if frames.player.Health then
                local btbOff = 0
                local btbPos2 = db.profile.player.btbPosition or "bottom"
                if btbPos2 == "top" and db.profile.player.bottomTextBar then
                    btbOff = db.profile.player.bottomTextBarHeight or 16
                end
                frames.player.Health:ClearAllPoints()
                PP.Point(frames.player.Health, "TOPLEFT", frames.player, "TOPLEFT", frames.player.Health._xOffset or 0, -btbOff)
                PP.Point(frames.player.Health, "RIGHT", frames.player, "RIGHT", -(frames.player.Health._rightInset or 0), 0)
            end
            -- "bottom" position ? flush with bottom of frame; shifts below castbar when visible (unless user set Y offset)
            bar:SetParent(frames.player)
            if bar._bottomBdrFrame then bar._bottomBdrFrame:Hide() end
            local function AnchorBottom()
                bar:ClearAllPoints()
                local baseY = -1 + offsetY
                if offsetY == 0 then
                    local castbarBg = frames.player.Castbar and frames.player.Castbar:GetParent()
                    local castVisible = castbarBg and castbarBg:IsShown() and db.profile.player.showPlayerCastbar
                    if castVisible then
                        baseY = -1 - castbarBg:GetHeight()
                    end
                end
                PP.Point(bar, "TOP", frames.player, "BOTTOM", offsetX, baseY)
            end
            AnchorBottom()
            -- Only run the castbar watcher if the player castbar is enabled
            if db.profile.player.showPlayerCastbar then
                if not bar._castbarWatcher then
                    bar._castbarWatcher = CreateFrame("Frame", nil, bar)
                end
                -- To save CPU, we use HookScript on the Castbar instead of OnUpdate
                local castbarBg = frames.player.Castbar and frames.player.Castbar:GetParent()
                if castbarBg and not castbarBg._kuiPowerAnchored then
                    castbarBg._kuiPowerAnchored = true
                    castbarBg:HookScript("OnShow", function()
                        if db.profile.player.showPlayerCastbar then
                            bar._lastCastVis = true
                            AnchorBottom()
                        end
                    end)
                    castbarBg:HookScript("OnHide", function()
                        if db.profile.player.showPlayerCastbar then
                            bar._lastCastVis = false
                            AnchorBottom()
                        end
                    end)
                end
                -- Initial state
                if castbarBg then
                    bar._lastCastVis = castbarBg:IsShown() and db.profile.player.showPlayerCastbar
                    AnchorBottom()
                end
            end
            ResizeFrameForClassPower(0)
        end
        bar:SetFrameStrata(frames.player:GetFrameStrata())
        bar:SetFrameLevel(frames.player:GetFrameLevel() + 5)
        bar:Show()
    end

    if classPowerStyle ~= "none" and frames.player then
        if classPowerStyle == "blizzard" then
            if savedClassPowerBar then
                PositionClassPowerBar(savedClassPowerBar)
                frames._classPowerBar = savedClassPowerBar
            end
        else
            -- Modern custom style
            DestroyCustomClassPower()
            local custom = CreateCustomClassPower(frames.player, classPowerStyle)
            if custom then
                frames._customClassPower = custom
                frames._classPowerBar = custom
                PositionClassPowerBar(custom)
            end
        end
    end

    -- Live toggle for class power bar (no reload needed)
    -- Called with the style string: "none", "modern", or "blizzard"
    frames._toggleClassPower = function(style)
        style = style or db.profile.player.classPowerStyle or "none"
        -- Also keep showClassPowerBar in sync for backward compat
        db.profile.player.showClassPowerBar = (style ~= "none")
        db.profile.player.classPowerStyle = style

        -- Clean up existing
        if frames._customClassPower then
            DestroyCustomClassPower()
            frames._classPowerBar = nil
        elseif frames._classPowerBar then
            frames._classPowerBar:Hide()
            frames._classPowerBar:ClearAllPoints()
            frames._classPowerBar:SetParent(PlayerFrame or UIParent)
            if PlayerFrame then
                PlayerFrame.classPowerBar = frames._classPowerBar
            end
            frames._classPowerBar = nil
        end

        if style == "none" then
            -- Reset health bar to normal position
            if frames.player and frames.player.Health then
                local btbOff = 0
                local btbPos2 = db.profile.player.btbPosition or "bottom"
                if btbPos2 == "top" and db.profile.player.bottomTextBar then
                    btbOff = db.profile.player.bottomTextBarHeight or 16
                end
                frames.player.Health:ClearAllPoints()
                PP.Point(frames.player.Health, "TOPLEFT", frames.player, "TOPLEFT", frames.player.Health._xOffset or 0, -btbOff)
                PP.Point(frames.player.Health, "RIGHT", frames.player, "RIGHT", -(frames.player.Health._rightInset or 0), 0)
            end
            ResizeFrameForClassPower(0)
            return
        end

        if style == "blizzard" then
            if PlayerFrame and PlayerFrame.classPowerBar then
                local cpb = PlayerFrame.classPowerBar
                PlayerFrame.classPowerBar = nil
                cpb:SetParent(UIParent)
                frames._classPowerBar = cpb
            end
            if frames._classPowerBar and frames.player then
                PositionClassPowerBar(frames._classPowerBar)
            end
        else
            -- Modern
            local custom = CreateCustomClassPower(frames.player, style)
            if custom then
                frames._customClassPower = custom
                frames._classPowerBar = custom
                PositionClassPowerBar(custom)
            end
        end
    end

    oUF:SetActiveStyle("KUITarget")
    frames.target = oUF:Spawn("target", "KullThranUI_UF_Target")
    ApplyFramePosition(frames.target, "target")
    ApplyFrameScale(frames.target, "target")
    SetupUnitMenu(frames.target, "target")
    if enabled.target == false then
        frames.target:Hide()
        frames.target:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUIFocus")
    frames.focus = oUF:Spawn("focus", "KullThranUI_UF_Focus")
    ApplyFramePosition(frames.focus, "focus")
    ApplyFrameScale(frames.focus, "focus")
    SetupUnitMenu(frames.focus, "focus")
    if enabled.focus == false then
        frames.focus:Hide()
        frames.focus:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUIPet")
    frames.pet = oUF:Spawn("pet", "KullThranUI_UF_Pet")
    ApplyFramePosition(frames.pet, "pet")
    SetupUnitMenu(frames.pet, "pet")
    if enabled.pet == false then
        frames.pet:Hide()
        frames.pet:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUITargetTarget")
    frames.targettarget = oUF:Spawn("targettarget", "KullThranUI_UF_TargetTarget")
    ApplyFramePosition(frames.targettarget, "targettarget")
    SetupUnitMenu(frames.targettarget, "targettarget")
    if enabled.targettarget == false then
        frames.targettarget:Hide()
        frames.targettarget:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUIFocusTarget")
    frames.focustarget = oUF:Spawn("focustarget", "KullThranUI_UF_FocusTarget")
    ApplyFramePosition(frames.focustarget, "focustarget")
    SetupUnitMenu(frames.focustarget, "focustarget")
    if enabled.focustarget == false then
        frames.focustarget:Hide()
        frames.focustarget:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUIBoss")
    local bossPos = db.profile.positions.boss
    local spacing = db.profile.bossSpacing or 60
    for i = 1, 5 do
        local bossUnit = "boss" .. i
        local bossFrame = oUF:Spawn(bossUnit, "KullThranUI_UF_Boss" .. i)
        frames[bossUnit] = bossFrame

        if bossPos then
            bossFrame:ClearAllPoints()
            bossFrame:SetPoint(bossPos.point, UIParent, bossPos.point, bossPos.x, bossPos.y - ((i - 1) * spacing))
        end

        SetupUnitMenu(bossFrame, bossUnit)

        if enabled.boss == false then
            bossFrame:Hide()
            bossFrame:SetAttribute("unit", nil)
        end
    end

    for i = 1, 5 do
        local blizzBoss = _G["Boss" .. i .. "TargetFrame"]
        if blizzBoss then
            blizzBoss:UnregisterAllEvents()
            blizzBoss:Hide()
        end
    end

    -- Disable oUF elements for frames where features are initially off.
    -- Portrait backdrop is already hidden by style functions, but oUF
    -- auto-enables the element at spawn time since frame.Portrait is always set.
    for unit, frame in pairs(frames) do
        if type(frame) ~= "table" or not frame.Portrait then -- skip non-frame entries
        elseif frame.Portrait.backdrop then
            local settings = GetSettingsForUnit(unit)
            if settings.showPortrait == false or (db.profile.portraitStyle or "attached") == "none" then
                if frame:IsElementEnabled("Portrait") then
                    frame:DisableElement("Portrait")
                end
            elseif ResolveActivePortraitMode(unit, settings) == "class" then
                -- Class theme uses a static texture and does not need the oUF Portrait element.
                if frame:IsElementEnabled("Portrait") then
                    frame:DisableElement("Portrait")
                end
            end
        end
    end

    -- Player absorbs: disable oUF element if not wanted (bar is always created)
    if frames.player and frames.player.HealthPrediction then
        if not db.profile.player.showPlayerAbsorb then
            if frames.player:IsElementEnabled("HealthPrediction") then
                frames.player:DisableElement("HealthPrediction")
            end
            if frames.player.HealthPrediction.damageAbsorb then
                frames.player.HealthPrediction.damageAbsorb:Hide()
            end
        end
    end

    -- Player buffs: disable oUF element if not wanted (frame is always created)
    if frames.player and frames.player.Buffs then
        if not db.profile.player.showBuffs then
            if frames.player:IsElementEnabled("Buffs") then
                frames.player:DisableElement("Buffs")
            end
            frames.player.Buffs:Hide()
        end
    end

    -- Player castbar: disable oUF element if not wanted (always created now)
    if frames.player and frames.player.Castbar then
        if not db.profile.player.showPlayerCastbar then
            if frames.player:IsElementEnabled("Castbar") then
                frames.player:DisableElement("Castbar")
            end
            frames.player.Castbar:Hide()
            local castbarBg = frames.player.Castbar:GetParent()
            if castbarBg then castbarBg:Hide() end
        elseif db.profile.player.showPlayerCastIcon == false and frames.player.Castbar._iconFrame then
            frames.player.Castbar._iconFrame:Hide()
        end
    end

    -- Target castbar: disable oUF element if not wanted
    if frames.target and frames.target.Castbar then
        if db.profile.target.showCastbar == false then
            if frames.target:IsElementEnabled("Castbar") then
                frames.target:DisableElement("Castbar")
            end
            frames.target.Castbar:Hide()
            local castbarBg = frames.target.Castbar:GetParent()
            if castbarBg then castbarBg:Hide() end
        elseif db.profile.target.showCastIcon == false and frames.target.Castbar._iconFrame then
            frames.target.Castbar._iconFrame:Hide()
        end
    end

    -- Focus castbar: disable oUF element if not wanted
    if frames.focus and frames.focus.Castbar then
        if db.profile.focus.showCastbar == false then
            if frames.focus:IsElementEnabled("Castbar") then
                frames.focus:DisableElement("Castbar")
            end
            frames.focus.Castbar:Hide()
            local castbarBg = frames.focus.Castbar:GetParent()
            if castbarBg then castbarBg:Hide() end
        elseif db.profile.focus.showCastIcon == false and frames.focus.Castbar._iconFrame then
            frames.focus.Castbar._iconFrame:Hide()
        end
    end

    ---------------------------------------------------------------------------
    --  Group visibility: show/hide player/target/focus based on group state
    ---------------------------------------------------------------------------
    local function UpdateFrameVisibility()
        if InCombatLockdown() then return end
        local enabled2 = db.profile.enabledFrames
        local inRaid = IsInRaid()
        local inParty = not inRaid and IsInGroup()
        local solo = not inRaid and not inParty
        for _, unitKey in ipairs({"player", "target", "focus"}) do
            local s = db.profile[unitKey]
            local frame = frames[unitKey]
            if frame and enabled2[unitKey] ~= false and s then
                local shouldShow = (inRaid and (s.showInRaid ~= false))
                    or (inParty and (s.showInParty ~= false))
                    or (solo and (s.showSolo ~= false))
                if shouldShow then
                    if not frame:IsShown() and UnitExists(unitKey) then
                        frame:SetAttribute("unit", unitKey)
                        -- Re-enable oUF elements that were disabled on hide.
                        -- Castbar is handled separately below to respect the
                        -- user's show/hide setting ? never blindly re-enable it.
                        for _, elem in ipairs({"Health", "Power", "Portrait", "Buffs", "Debuffs", "HealthPrediction"}) do
                            if frame[elem] and not frame:IsElementEnabled(elem) then
                                frame:EnableElement(elem)
                            end
                        end
                        -- Restore castbar state based on saved setting
                        if frame.Castbar then
                            local wantsCastbar
                            if unitKey == "player" then
                                wantsCastbar = s.showPlayerCastbar
                            else
                                wantsCastbar = s.showCastbar ~= false
                            end
                            if wantsCastbar then
                                if not frame:IsElementEnabled("Castbar") then
                                    frame:EnableElement("Castbar")
                                end
                            else
                                if frame:IsElementEnabled("Castbar") then
                                    frame:DisableElement("Castbar")
                                end
                                frame.Castbar:Hide()
                                local castbarBg = frame.Castbar:GetParent()
                                if castbarBg then castbarBg:Hide() end
                            end
                        end
                        frame:Show()
                        frame:UpdateAllElements("GroupVisibility")
                        if unitKey == "player" then
                            RefreshPlayerStatusIndicators()
                        end
                    end
                else
                    if frame:IsShown() then
                        -- Disable oUF elements before hiding to prevent a
                        -- single-frame flash when the unit attribute is cleared
                        for _, elem in ipairs({"Health", "Power", "Portrait", "Castbar", "Buffs", "Debuffs", "HealthPrediction", "CombatIndicator", "RestingIndicator", "LeaderIndicator", "AssistantIndicator", "ResurrectIndicator", "SummonIndicator", "RaidTargetIndicator"}) do
                            if frame[elem] and frame:IsElementEnabled(elem) then
                                frame:DisableElement(elem)
                            end
                        end
                        frame:Hide()
                        frame:SetAttribute("unit", nil)
                    end
                end
            end
        end
    end
    ns.UpdateFrameVisibility = UpdateFrameVisibility

    if not frames._visFrame then
        frames._visFrame = CreateFrame("Frame")
        frames._visFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        frames._visFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    frames._visFrame:SetScript("OnEvent", UpdateFrameVisibility)
    UpdateFrameVisibility()

    ---------------------------------------------------------------------------
    --  Portrait border color: update when target/focus unit changes
    --  so "class color" mode reflects the new unit's color.
    ---------------------------------------------------------------------------
    if not frames._portraitBorderUpdater then
        frames._portraitBorderUpdater = CreateFrame("Frame")
        frames._portraitBorderUpdater:RegisterEvent("PLAYER_TARGET_CHANGED")
        frames._portraitBorderUpdater:RegisterEvent("PLAYER_FOCUS_CHANGED")
        frames._portraitBorderUpdater:RegisterEvent("UNIT_TARGET")
        frames._portraitBorderUpdater:RegisterEvent("UNIT_PET")
    end
    frames._portraitBorderUpdater:SetScript("OnEvent", function(_, event, unit)
        local unitKeys
        if event == "PLAYER_TARGET_CHANGED" then
            unitKeys = { "target", "targettarget" }
        elseif event == "PLAYER_FOCUS_CHANGED" then
            unitKeys = { "focus", "focustarget" }
        elseif event == "UNIT_PET" and unit == "player" then
            unitKeys = { "pet" }
        elseif event == "UNIT_TARGET" and unit == "target" then
            unitKeys = { "targettarget" }
        elseif event == "UNIT_TARGET" and unit == "focus" then
            unitKeys = { "focustarget" }
        else
            return
        end

        for _, unitKey in ipairs(unitKeys) do
            local frame = frames[unitKey]
            if frame and frame.Portrait then
                local backdrop = frame.Portrait.backdrop
                if backdrop then
                    local settingsKey = UnitToSettingsKey(unitKey) or unitKey
                    local uSettings = settingsKey and db.profile[settingsKey]
                    if db.profile.portraitStyle == "circular"
                        or (uSettings and uSettings.detachedPortraitClassColor)
                    then
                        ApplyDetachedPortraitShape(backdrop, uSettings, unitKey)
                    end
                    SwapPortraitMode(frame)
                    if frame:IsElementEnabled("Portrait") and frame.Portrait and frame.Portrait.ForceUpdate then
                        frame.Portrait:ForceUpdate()
                    end
                end
            end
        end
    end)

    -- Deferred normalization: some late-login updates can re-anchor power bars
    -- after frame construction. Re-apply two-point attached anchors once more.
    C_Timer.After(0, function()
        for _, unitKey in ipairs({"player", "target", "focus"}) do
            local frame = frames[unitKey]
            if frame and frame.Power and frame.Health then
                local s = GetSettingsForUnit(unitKey)
                if s then
                    local ppPos = s.powerPosition or "below"
                    if ppPos == "below" or ppPos == "above" then
                        frame.Power:ClearAllPoints()
                        if ppPos == "above" then
                            PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                            PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                        else
                            PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                            PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                        end
                    end
                end
            end
        end
        for i = 1, 5 do
            local bf = frames["boss" .. i]
            if bf and bf.Power and bf.Health then
                local s = GetSettingsForUnit("boss")
                if s then
                    local ppPos = s.powerPosition or "below"
                    if ppPos == "below" or ppPos == "above" then
                        bf.Power:ClearAllPoints()
                        if ppPos == "above" then
                            PP.Point(bf.Power, "BOTTOMLEFT", bf.Health, "TOPLEFT", 0, 0)
                            PP.Point(bf.Power, "BOTTOMRIGHT", bf.Health, "TOPRIGHT", 0, 0)
                        else
                            PP.Point(bf.Power, "TOPLEFT", bf.Health, "BOTTOMLEFT", 0, 0)
                            PP.Point(bf.Power, "TOPRIGHT", bf.Health, "BOTTOMRIGHT", 0, 0)
                        end
                    end
                end
            end
        end
    end)

    -- Keep every UnitFrame child, including indicator and text overlays, below
    -- Blizzard's MEDIUM/DIALOG windows while preserving their internal levels.
    RefreshUnitFrameStrata()

    if InCombatLockdown() then
        ns._suppressAutoPlayerFrameAnchor = true
        ns._playerFrameAnchorPending = false
    else
        ns._suppressAutoPlayerFrameAnchor = nil
    end

    if ns.AnchorPlayerFrameToCDM and not ns._suppressAutoPlayerFrameAnchor then
        if ns.RequestAnchorPlayerFrameToCDM then
            C_Timer.After(0, function() ns.RequestAnchorPlayerFrameToCDM() end)
            C_Timer.After(0.5, function() ns.RequestAnchorPlayerFrameToCDM() end)
            C_Timer.After(1.5, function() ns.RequestAnchorPlayerFrameToCDM() end)
        else
            C_Timer.After(0, function() ns.AnchorPlayerFrameToCDM() end)
            C_Timer.After(0.5, function() ns.AnchorPlayerFrameToCDM() end)
            C_Timer.After(1.5, function() ns.AnchorPlayerFrameToCDM() end)
        end
    end
end

local function RegisterUnitFramesWithEditMode()
    if not (KT and KT.RegisterUnlockElement and db and db.profile) then return end
    local unlockOrders = {
        player = 10,
        target = 20,
        focus = 30,
        pet = 40,
        targettarget = 50,
        focustarget = 60,
        boss = 70,
        playerCastbar = 80,
        classPower = 90,
    }

    local function SavePoint(frame, key)
        local point, _, relPoint, x, y = frame:GetPoint()
        db.profile.positions[key] = {
            point = point or relPoint or "CENTER",
            x = x or 0,
            y = y or 0,
            scale = frame.GetScale and frame:GetScale() or 1,
        }
    end

    local function Register(frame, label, key, onStop)
        if not frame then return end
        local unlockKey = "unitframes_" .. key

        KT.RegisterUnlockElement(unlockKey, {
            label = (label:gsub("^Unit Frames:%s*", "")),
            group = "Unit Frames",
            order = unlockOrders[key] or 999,
            getFrame = function()
                return frame
            end,
            getSize = function()
                return frame:GetWidth(), frame:GetHeight()
            end,
            getScale = function()
                return frame:GetScale()
            end,
            setScale = function(_, scale)
                if scale and ApplyFrameScale then
                    ApplyFrameScale(frame, key, scale, false)
                end
            end,
            loadPosition = function()
                local saved = KT.db.profile.editMode
                    and KT.db.profile.editMode.frames
                    and KT.db.profile.editMode.frames[unlockKey]
                if saved and saved.point then
                    return saved
                end
                local native = db.profile.positions[key]
                if native and native.point then
                    return {
                        point = native.point,
                        relativePoint = native.point,
                        x = native.x or 0,
                        y = native.y or 0,
                        scale = native.scale or frame:GetScale() or 1,
                    }
                end
                return nil
            end,
            savePosition = function(_, pt, rpt, x, y, scale)
                KT.db.profile.editMode.frames[unlockKey] = {
                    point = pt,
                    relativePoint = rpt,
                    x = x,
                    y = y,
                    scale = scale or frame:GetScale() or 1,
                }
                db.profile.positions[key] = {
                    point = pt or rpt or "CENTER",
                    x = x or 0,
                    y = y or 0,
                    scale = scale or frame:GetScale() or 1,
                }
                SavePoint(frame, key)
                if onStop then onStop() end
            end,
            applyPosition = function()
                local saved = KT.db.profile.editMode
                    and KT.db.profile.editMode.frames
                    and KT.db.profile.editMode.frames[unlockKey]
                if saved and saved.point then
                    db.profile.positions[key] = {
                        point = saved.point,
                        x = saved.x or 0,
                        y = saved.y or 0,
                        scale = saved.scale or frame:GetScale() or 1,
                    }
                end
                local targetPos = db.profile.positions[key]
                if targetPos and targetPos.scale and ApplyFrameScale then
                    ApplyFrameScale(frame, key, targetPos.scale, false)
                end
                ApplyFramePosition(frame, key)
                if onStop then onStop() end
            end,
        })
    end

    Register(frames.player, "Unit Frames: Player", "player")
    Register(frames.target, "Unit Frames: Target", "target")
    Register(frames.focus, "Unit Frames: Focus", "focus")
    Register(frames.pet, "Unit Frames: Pet", "pet")
    Register(frames.targettarget, "Unit Frames: Target of Target", "targettarget")
    Register(frames.focustarget, "Unit Frames: Focus Target", "focustarget")
    Register(frames.boss1, "Unit Frames: Boss", "boss", function()
        local pos = db.profile.positions.boss
        local spacing = db.profile.bossSpacing or 60
        for i = 1, 5 do
            local frame = frames["boss" .. i]
            if frame and pos then
                frame:ClearAllPoints()
                frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y - ((i - 1) * spacing))
            end
        end
    end)

    if frames.player and frames.player.Castbar and not db.profile.player.lockCastbarToFrame then
        Register(frames.player.Castbar:GetParent(), "Unit Frames: Player Castbar", "playerCastbar")
    end
    if frames._classPowerBar and not db.profile.player.lockClassPowerToFrame then
        Register(frames._classPowerBar, "Unit Frames: Class Power", "classPower")
    end
end

local function SetupOptionsPanel()
    ns.db = db
    ns.frames = frames
    ns.ApplyFramePosition = ApplyFramePosition
    ns.ApplyFrameScale = ApplyFrameScale
    ns.SnapScaleToPixel = SnapScaleToPixel
    ns.GetFrameDimensions = GetFrameDimensions
    ns.ResolveFontPath = ResolveFontPath

    if not ns._ufReloadThrottle then
        ns._ufReloadThrottle = CreateFrame("Frame")
        ns._ufReloadThrottle:Hide()
        ns._ufReloadThrottle:SetScript("OnUpdate", function(self)
            self:Hide()
            ns._ufReloadPending = false
            ReloadFrames()
        end)
    end

    ns.ReloadFrames = function()
        if not ns._ufReloadPending then
            ns._ufReloadPending = true
            ns._ufReloadThrottle:Show()
        end
    end

    Mod.Reload = ns.ReloadFrames
    RegisterUnitFramesWithEditMode()
end

StaticPopupDialogs["KULLTHRANUI_UF_RESET_DEFAULTS"] = {
    text = "Reset all KullThranUI Unit Frames settings to defaults? This cannot be undone.",
    button1 = "Reset & Reload",
    button2 = "Cancel",
    OnAccept = function()
        if KT and KT.db and KT.db.profile then
            KT.db.profile.unitFrames = {}
            Compat.CopyDefaults(KT.db.profile.unitFrames, defaults.profile)
        end
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function MigratePlayerTarget()
    local p = db.profile
    if p._playerTargetMigrated then return end
    local old = p.playerTarget
    if not old then
        p._playerTargetMigrated = true
        return
    end
    local oldDef = defaults.profile.playerTarget

    p.player = p.player or {}
    p.player.frameWidth = old.frameWidth or oldDef.frameWidth
    p.player.healthHeight = old.healthHeight or oldDef.healthHeight
    p.player.powerHeight = old.powerHeight or oldDef.powerHeight
    p.player.healthDisplay = old.healthDisplay or oldDef.healthDisplay
    if old.showPlayerAbsorb == nil then
        p.player.showPlayerAbsorb = true
    else
        p.player.showPlayerAbsorb = old.showPlayerAbsorb
    end
    p.player.showPlayerCastbar = old.showPlayerCastbar or false
    p.player.showClassPowerBar = old.showClassPowerBar or false
    p.player.playerCastbarX = old.playerCastbarX or 0
    p.player.playerCastbarY = old.playerCastbarY or 0
    p.player.playerCastbarWidth = old.playerCastbarWidth or 0
    p.player.playerCastbarHeight = old.playerCastbarHeight or 0
    p.player.classPowerBarX = old.classPowerBarX or 0
    p.player.classPowerBarY = old.classPowerBarY or 0
    p.player.showPortrait = p.showPortrait

    p.target = p.target or {}
    p.target.frameWidth = old.frameWidth or oldDef.frameWidth
    p.target.healthHeight = old.healthHeight or oldDef.healthHeight
    p.target.powerHeight = old.powerHeight or oldDef.powerHeight
    p.target.castbarHeight = old.castbarHeight or oldDef.castbarHeight
    p.target.healthDisplay = old.healthDisplay or oldDef.healthDisplay
    p.target.showBuffs = old.showBuffs
    if p.target.showBuffs == nil then p.target.showBuffs = true end
    p.target.onlyPlayerDebuffs = old.onlyPlayerDebuffs or false
    p.target.showPortrait = p.showPortrait
    p._playerTargetMigrated = true
end

local function ClampImportedNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then return fallback end
    if value < minValue or value > maxValue then
        return fallback
    end
    return value
end

local function NormalizeImportedFont(value)
    if type(value) ~= "string" or value == "" then
        return "AAA_ITC_Avant_Garde"
    end
    if Compat.fontPaths[value] then
        return value
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM:Fetch("font", value, true) then
        return value
    end
    return "AAA_ITC_Avant_Garde"
end

local function NormalizeImportedTexture(value)
    if type(value) ~= "string" or value == "" then
        return "Melli Reforged"
    end
    if healthBarTextures[value] ~= nil or value == "none" then
        return value
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM:Fetch("statusbar", value, true) then
        return value
    end
    return "Melli Reforged"
end

local function NormalizeImportedColor(value, fallback)
    if type(value) ~= "table" then
        return CopyTable(fallback)
    end

    return {
        r = ClampImportedNumber(value.r or value[1], 0, 1, fallback.r),
        g = ClampImportedNumber(value.g or value[2], 0, 1, fallback.g),
        b = ClampImportedNumber(value.b or value[3], 0, 1, fallback.b),
        a = ClampImportedNumber(value.a or value[4], 0, 1, fallback.a or 1),
    }
end

local function SanitizeImportedLayout()
    local profile = db.profile
    if not profile then return end

    local defaultPositions = defaults.profile.positions or {}
    profile.positions = profile.positions or {}
    for unit, defaultPos in pairs(defaultPositions) do
        local pos = profile.positions[unit]
        if type(pos) ~= "table" then
            profile.positions[unit] = CopyTable(defaultPos)
        else
            if type(pos.point) ~= "string" then
                pos.point = defaultPos.point
            end
            pos.x = ClampImportedNumber(pos.x, -4000, 4000, defaultPos.x)
            pos.y = ClampImportedNumber(pos.y, -4000, 4000, defaultPos.y)
        end
    end

    local units = { "player", "target", "focus", "boss", "pet", "totPet" }
    for i = 1, #units do
        local unit = units[i]
        local settings = profile[unit]
        local unitDefaults = defaults.profile[unit]
        if settings and unitDefaults then
            settings.frameWidth = ClampImportedNumber(settings.frameWidth, 40, 800, unitDefaults.frameWidth)
            settings.frameScale = ClampImportedNumber(settings.frameScale, 25, 300, unitDefaults.frameScale or 100)
            settings.healthHeight = ClampImportedNumber(settings.healthHeight, 8, 200, unitDefaults.healthHeight)
            settings.powerHeight = ClampImportedNumber(settings.powerHeight, 0, 80, unitDefaults.powerHeight or 0)
            settings.portraitSize = ClampImportedNumber(settings.portraitSize, -40, 300, unitDefaults.portraitSize or 0)
            settings.portraitX = ClampImportedNumber(settings.portraitX, -250, 250, unitDefaults.portraitX or 0)
            settings.portraitY = ClampImportedNumber(settings.portraitY, -250, 250, unitDefaults.portraitY or 0)
            settings.selectedFont = NormalizeImportedFont(settings.selectedFont or unitDefaults.selectedFont)
            settings.healthBarTexture = NormalizeImportedTexture(settings.healthBarTexture or unitDefaults.healthBarTexture)
            settings.healthBarOpacity = ClampImportedNumber(settings.healthBarOpacity, 1, 100, unitDefaults.healthBarOpacity or 90)
            settings.powerBarOpacity = ClampImportedNumber(settings.powerBarOpacity, 1, 100, unitDefaults.powerBarOpacity or 100)
            if unit == "player" then
                settings.absorbBarTexture = NormalizeImportedTexture(settings.absorbBarTexture or unitDefaults.absorbBarTexture or DEFAULT_ABSORB_TEXTURE)
                settings.absorbBarColor = NormalizeImportedColor(settings.absorbBarColor, unitDefaults.absorbBarColor or DEFAULT_ABSORB_COLOR)
            end
        end
    end

    profile.selectedFont = NormalizeImportedFont(profile.selectedFont)
    profile.healthBarTexture = NormalizeImportedTexture(profile.healthBarTexture)
    if profile.portraitStyle ~= "attached"
        and profile.portraitStyle ~= "detached"
        and profile.portraitStyle ~= "circular"
        and profile.portraitStyle ~= "none"
    then
        profile.portraitStyle = defaults.profile.portraitStyle
    end
end

local function ApplyUpdatedDefaultPreset()
    local profile = db.profile
    if not profile or profile._defaultPreset20260323 then return end
    local function sameColor(a, r, g, b)
        return a
            and math.abs((a.r or 0) - r) < 0.001
            and math.abs((a.g or 0) - g) < 0.001
            and math.abs((a.b or 0) - b) < 0.001
    end

    local function bumpTextSizes(settings)
        if not settings then return end
        if settings.leftTextSize == 12 then settings.leftTextSize = 14 end
        if settings.rightTextSize == 12 then settings.rightTextSize = 14 end
        if settings.centerTextSize == 12 then settings.centerTextSize = 14 end
        if settings.textSize == 12 then settings.textSize = 14 end
        if settings.powerPercentSize == 9 then settings.powerPercentSize = 11 end
        if settings.castSpellNameSize == 11 then settings.castSpellNameSize = 13 end
        if settings.castDurationSize == 11 then settings.castDurationSize = 13 end
        if settings.btbLeftSize == 11 then settings.btbLeftSize = 13 end
        if settings.btbRightSize == 11 then settings.btbRightSize = 13 end
        if settings.btbCenterSize == 11 then settings.btbCenterSize = 13 end
    end

    for _, unit in ipairs({ "player", "target", "focus", "boss", "pet", "totPet" }) do
        bumpTextSizes(profile[unit])
    end

    if profile.player and (profile.player.frameWidth == 181 or profile.player.frameWidth == 185 or profile.player.frameWidth == 187) then
        profile.player.frameWidth = 230
    end
    if profile.target and (profile.target.frameWidth == 181 or profile.target.frameWidth == 185 or profile.target.frameWidth == 187) then
        profile.target.frameWidth = 230
    end
    if profile.target and profile.target.castbarHideWhenInactive == false then
        profile.target.castbarHideWhenInactive = true
    end
    if profile.target then
        local targetCb = profile.target.castbarFillColor
        local isLegacyGreen = sameColor(targetCb, 0.114, 0.655, 0.514)
        local isKtRed = sameColor(targetCb, KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333)
        if targetCb == nil or isLegacyGreen or isKtRed then
            profile.target.castbarFillColor = { r = 1, g = 0.82, b = 0 }
            profile.target.castbarClassColored = false
        end
    end

    local positions = profile.positions or {}
    local playerPos = positions.player
    if playerPos and playerPos.point == "CENTER" and playerPos.x == -317 and playerPos.y == -193.5 then
        playerPos.x = -300
        playerPos.y = -145
    elseif playerPos and playerPos.point == "CENTER" and playerPos.x == -292 and playerPos.y == -176 then
        playerPos.x = -300
        playerPos.y = -145
    elseif playerPos and playerPos.point == "CENTER" and playerPos.x == -245 and playerPos.y == -176 then
        playerPos.x = -300
        playerPos.y = -145
    end

    local targetPos = positions.target
    if targetPos and targetPos.point == "CENTER" and targetPos.x == 317 and targetPos.y == -201 then
        targetPos.x = 300
        targetPos.y = -145
    elseif targetPos and targetPos.point == "CENTER" and targetPos.x == 292 and targetPos.y == -176 then
        targetPos.x = 300
        targetPos.y = -145
    elseif targetPos and targetPos.point == "CENTER" and targetPos.x == 245 and targetPos.y == -176 then
        targetPos.x = 300
        targetPos.y = -145
    end

    local focusPos = positions.focus
    if focusPos and focusPos.point == "CENTER" and (
        (focusPos.x == 0 and focusPos.y == -285)
        or (focusPos.x == -300 and focusPos.y == -205)
        or (focusPos.x == -323 and focusPos.y == -347)
        or (focusPos.x == -267.5 and focusPos.y == -347)
        or (focusPos.x == -287.5 and focusPos.y == -347)
        or ((focusPos.x == -320 and (focusPos.y == -175 or focusPos.y == -252 or focusPos.y == -272))
            or (focusPos.x == -323 and (focusPos.y == -272 or focusPos.y == -307 or focusPos.y == -327)))
    ) then
        focusPos.x = -315
        focusPos.y = -347
    end

    local petPos = positions.pet
    if petPos and petPos.point == "CENTER"
        and ((petPos.x == -300 and petPos.y == -260)
            or (petPos.x == -369.5 and (petPos.y == -96.5 or petPos.y == -106.5))
            or (petPos.x == -372.5 and (petPos.y == -116.5 or petPos.y == -131.5 or petPos.y == -141.5))) then
        petPos.x = -372.5
        petPos.y = -146.5
    end

    local focusTargetPos = positions.focustarget
    if focusTargetPos and focusTargetPos.point == "CENTER" and
        ((focusTargetPos.x == 50 and focusTargetPos.y == -261)
            or (focusTargetPos.x == -369.5 and (focusTargetPos.y == -301.5 or focusTargetPos.y == -321.5))
            or (focusTargetPos.x == -372.5 and (focusTargetPos.y == -321.5 or focusTargetPos.y == -356.5 or focusTargetPos.y == -376.5))
            or (focusTargetPos.x == -372.5 and focusTargetPos.y == -396.5)
            or (focusTargetPos.x == -317 and focusTargetPos.y == -396.5)
            or (focusTargetPos.x == -337 and focusTargetPos.y == -396.5)) then
        focusTargetPos.x = -364.5
        focusTargetPos.y = -396.5
    end

    local targetTargetPos = positions.targettarget
    if targetTargetPos and targetTargetPos.point == "CENTER" and targetTargetPos.x == 383 and targetTargetPos.y == -152.5 then
        targetTargetPos.x = 378
    end

    if profile.pet and profile.pet.healthClassColored == nil then
        profile.pet.healthClassColored = true
    end

    if profile.focus and (profile.focus.portraitSide == nil or profile.focus.portraitSide == "right") then
        profile.focus.portraitSide = "left"
    end

    profile._defaultPreset20260311 = true
    profile._defaultPreset20260312 = true
    profile._defaultPreset20260313 = true
    profile._defaultPreset20260314 = true
    profile._defaultPreset20260315 = true
    profile._defaultPreset20260316 = true
    profile._defaultPreset20260317 = true
    profile._defaultPreset20260318 = true
    profile._defaultPreset20260319 = true
    profile._defaultPreset20260320 = true
    profile._defaultPreset20260321 = true
    profile._defaultPreset20260322 = true
    profile._defaultPreset20260323 = true
end

local function MigrateLegacyCrimsonAccent()
    local profile = db.profile
    if not profile or profile._legacyCrimsonAccentMigrated20260818 then return end

    local function IsLegacyCrimson(color)
        return color
            and math.abs((color.r or 0) - 1) < 0.001
            and math.abs(color.g or 0) < 0.001
            and math.abs((color.b or 0) - 0.333) < 0.001
    end

    if IsLegacyCrimson(profile.castbarColor) then
        profile.castbarColor = nil
    end
    if IsLegacyCrimson(profile.circularPortraitBorderColor) then
        profile.circularPortraitBorderColor = nil
    end

    for _, unit in ipairs({ "player", "focus", "boss", "pet", "totPet" }) do
        local settings = profile[unit]
        if settings and IsLegacyCrimson(settings.castbarFillColor) then
            settings.castbarFillColor = nil
        end
    end

    profile._legacyCrimsonAccentMigrated20260818 = true
end

local function ApplyTargetCastbarYellowDefault()
    local profile = db.profile
    if not profile or profile._targetCastbarYellow20260803 then return end

    local target = profile.target
    local color = target and target.castbarFillColor
    local function sameColor(r, g, b)
        return color
            and math.abs((color.r or 0) - r) < 0.001
            and math.abs((color.g or 0) - g) < 0.001
            and math.abs((color.b or 0) - b) < 0.001
    end

    -- Only migrate the exact class-colored state produced by the old default
    -- migration. Explicit custom colors and non-class-colored choices remain.
    if target and target.castbarClassColored == true
        and (sameColor(0.114, 0.655, 0.514)
            or sameColor(KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333)) then
        target.castbarFillColor = { r = 1, g = 0.82, b = 0 }
        target.castbarClassColored = false
    end

    profile._targetCastbarYellow20260803 = true
end

local function ApplyReferenceLayoutDefaults()
    local profile = db.profile
    if not profile or profile._referenceLayout20260801 then return end

    local positions = profile.positions or {}
    local replacements = {
        focus = { oldX = -315, oldY = -347, x = -315, y = -257 },
        pet = { oldX = -372.5, oldY = -146.5, x = -372.5, y = -36.5 },
        target = { oldX = 300, oldY = -145, x = 280, y = -145 },  -- Base position adjusted; ApplyFramePosition adds dynamic offset based on portrait config
        targettarget = { oldX = 378, oldY = -152.5, x = 378, y = -42.5 },
        focustarget = { oldX = -364.5, oldY = -396.5, x = -364.5, y = -306.5 },
    }

    for key, replacement in pairs(replacements) do
        local pos = positions[key]
        if pos and pos.point == "CENTER" and pos.x == replacement.oldX and pos.y == replacement.oldY then
            pos.x = replacement.x
            pos.y = replacement.y
        end

        local unlockKey = "unitframes_" .. key
        local editPos = KT.db.profile.editMode
            and KT.db.profile.editMode.frames
            and KT.db.profile.editMode.frames[unlockKey]
        if editPos and editPos.point == "CENTER"
            and editPos.x == replacement.oldX and editPos.y == replacement.oldY then
            editPos.x = replacement.x
            editPos.y = replacement.y
        end
    end

    profile._referenceLayout20260801 = true
end

local function ApplyDebuffDefaultsMigration()
    local profile = db.profile
    if not profile or profile._debuffDefaults20260815 then return end

    -- Ensure player has maxDebuffs and onlyPlayerDebuffs
    local player = profile.player
    if player then
        if player.maxDebuffs == nil then
            player.maxDebuffs = 20
        end
        if player.onlyPlayerDebuffs == nil then
            player.onlyPlayerDebuffs = true
        end
    end

    -- Ensure target has maxDebuffs and showDebuffs enabled by default
    local target = profile.target
    if target then
        if target.maxDebuffs == nil then
            target.maxDebuffs = 20
        end
        if target.showDebuffs == nil then
            target.showDebuffs = true
        end
    end

    -- Adjust target x position as base for dynamic calculation
    -- ApplyFramePosition will add additional offset if portrait is active
    local positions = profile.positions or {}
    local targetPos = positions.target
    if targetPos and targetPos.point == "CENTER" and targetPos.x == 300 and targetPos.y == -145 then
        targetPos.x = 280
    end

    -- Also update unlock mode position if it matches
    if KT and KT.db and KT.db.profile and KT.db.profile.editMode and KT.db.profile.editMode.frames then
        local editPos = KT.db.profile.editMode.frames["unitframes_target"]
        if editPos and editPos.point == "CENTER" and editPos.x == 300 and editPos.y == -145 then
            editPos.x = 280
        end
    end

    profile._debuffDefaults20260815 = true
end

function Mod:BindDatabase()
    if not (KT and KT.db and KT.db.profile) then return end
    KT.db.profile.unitFrames = KT.db.profile.unitFrames or {}
    Compat.CopyDefaults(KT.db.profile.unitFrames, defaults.profile)
    db = { profile = KT.db.profile.unitFrames }
    self.db = db.profile
    if not self.db._kuiForeverLevelPvpOptionsReset then
        self.db.showCharacterLevel = false
        self.db.showPvPIcon = false
        self.db._kuiForeverLevelPvpOptionsReset = true
    end
    self.db.enable = self.db.enable ~= false
end

function Mod:OnInitialize()
    self:BindDatabase()
    self:SetEnabledState(self.db.enable ~= false)
    MigratePlayerTarget()
    SanitizeImportedLayout()
    MigrateLegacyCrimsonAccent()
    ApplyUpdatedDefaultPreset()
    ApplyTargetCastbarYellowDefault()
    ApplyReferenceLayoutDefaults()
    ApplyDebuffDefaultsMigration()
    if RegisterUFHPDebugSlash then
        C_Timer.After(0, RegisterUFHPDebugSlash)
    end
    if KT and KT.RegisterChatCommand then
        KT:RegisterChatCommand("ktufhpdebug", function(msg) SlashCmdList.KTUFHPDEBUG(msg) end)
        KT:RegisterChatCommand("ktufhpdbg", function(msg) SlashCmdList.KTUFHPDEBUG(msg) end)
    end

    do
        local prof = db.profile
        if prof.use3DPortrait ~= nil then
            if prof.use3DPortrait == true then
                prof.portraitMode = "3d"
            elseif prof.use3DPortrait == false and not prof.portraitMode then
                prof.portraitMode = "2d"
            end
            prof.use3DPortrait = nil
        end
    end

    do
        local prof = db.profile
        local units = { "player", "target", "focus", "boss", "pet", "totPet" }
        local globalPM = prof.portraitMode
        local globalFont = prof.selectedFont
        local globalTex = prof.healthBarTexture
        if globalPM ~= nil or globalFont ~= nil or globalTex ~= nil then
            for i = 1, #units do
                local s = prof[units[i]]
                if s then
                    if s.portraitMode == nil then
                        s.portraitMode = (s.showPortrait == false) and "none" or (globalPM or "2d")
                    end
                    if s.selectedFont == nil then s.selectedFont = globalFont or "AAA_ITC_Avant_Garde" end
                    if s.healthBarTexture == nil then s.healthBarTexture = globalTex or "Melli Reforged" end
                end
            end
            prof.portraitMode = nil
            prof.selectedFont = nil
            prof.healthBarTexture = nil
            prof.healthBarTextureOpacity = nil
        end
    end

    ResolveFontPath()
    Compat.AppendSharedMediaTextures(healthBarTextureNames, healthBarTextureOrder, nil, healthBarTextures)

    do
        local prof = db.profile
        local oldKeys = { gradient = true, grunge = true, stripe = true }
        local units = { "player", "target", "focus", "boss", "pet", "totPet" }
        for i = 1, #units do
            local s = prof[units[i]]
            if s and s.healthBarTexture and oldKeys[s.healthBarTexture] then
                s.healthBarTexture = "none"
            end
            if s and s.healthBarOpacity and s.healthBarOpacity <= 1.0 then
                s.healthBarOpacity = math.floor(s.healthBarOpacity * 100 + 0.5)
            end
            if s and s.powerBarOpacity and s.powerBarOpacity <= 1.0 then
                s.powerBarOpacity = math.floor(s.powerBarOpacity * 100 + 0.5)
            end
        end
        if prof.healthBarOpacity and prof.healthBarOpacity <= 1.0 then
            prof.healthBarOpacity = math.floor(prof.healthBarOpacity * 100 + 0.5)
        end
        if prof.powerBarOpacity and prof.powerBarOpacity <= 1.0 then
            prof.powerBarOpacity = math.floor(prof.powerBarOpacity * 100 + 0.5)
        end
    end

    do
        local prof = db.profile
        local units = { "player", "target", "focus" }
        for i = 1, #units do
            local s = prof[units[i]]
            if s and s.leftTextContent == nil and (s.namePosition or s.healthTextPosition) then
                local np = s.namePosition or "left"
                local hp = s.healthTextPosition or "right"
                local hd = s.healthDisplay or (units[i] == "focus" and "perhp" or "both")
                if np == "left" then
                    s.leftTextContent = "name"
                    s.rightTextContent = (hp == "right") and hd or "none"
                elseif np == "right" then
                    s.rightTextContent = "name"
                    s.leftTextContent = (hp == "left") and hd or "none"
                else
                    s.leftTextContent = (hp == "left") and hd or "none"
                    s.rightTextContent = (hp == "right") and hd or "none"
                end
                local ts = s.textSize or 12
                if s.leftTextSize == nil then s.leftTextSize = ts end
                if s.rightTextSize == nil then s.rightTextSize = ts end
                if s.leftTextX == nil then s.leftTextX = 0 end
                if s.leftTextY == nil then s.leftTextY = 0 end
                if s.rightTextX == nil then s.rightTextX = 0 end
                if s.rightTextY == nil then s.rightTextY = 0 end
            end
        end
    end

    do
        local s = db.profile.player
        if s then
            if s.showPlayerAbsorb == nil or s.showPlayerAbsorb == false then
                s.showPlayerAbsorb = true
            end
            s.absorbBarTexture = NormalizeImportedTexture(s.absorbBarTexture or defaults.profile.player.absorbBarTexture or DEFAULT_ABSORB_TEXTURE)
            s.absorbBarColor = NormalizeImportedColor(s.absorbBarColor, defaults.profile.player.absorbBarColor or DEFAULT_ABSORB_COLOR)
            if s.classPowerStyle == "bars" or s.classPowerStyle == "circles" then
                s.classPowerStyle = "modern"
            end
            if s.showClassPowerBar and (s.classPowerStyle == "none" or s.classPowerStyle == nil) then
                s.classPowerStyle = "blizzard"
            end
            if s.classPowerStyle and s.classPowerStyle ~= "none" then
                s.showClassPowerBar = true
            end
        end
    end

    do
        local prof = db.profile
        local units = { "player", "target", "focus", "boss", "pet", "totPet" }
        local anyNone = false
        for i = 1, #units do
            local s = prof[units[i]]
            if s and s.portraitMode == "none" then
                anyNone = true
                break
            end
        end
        if anyNone then
            prof.portraitStyle = "none"
            for i = 1, #units do
                local s = prof[units[i]]
                if s and s.portraitMode == "none" then
                    s.portraitMode = "2d"
                    s.showPortrait = false
                end
            end
        end
    end

    do
        local prof = db.profile
        local units = { "player", "target", "focus", "boss" }
        for i = 1, #units do
            local s = prof[units[i]]
            if s and s.powerPercentTextPowerColor == nil and s.powerPercentPowerColor ~= nil then
                s.powerPercentTextPowerColor = s.powerPercentPowerColor
            end
        end
        local old = prof.playerTarget
        if old and old.powerPercentTextPowerColor == nil and old.powerPercentPowerColor ~= nil then
            old.powerPercentTextPowerColor = old.powerPercentPowerColor
        end
    end
end

function Mod:Refresh()
    self:BindDatabase()
    if self.db.enable == false then
        return
    end
    SetupOptionsPanel()
    if frames.player and ns.ReloadFrames then
        ns.ReloadFrames()
    end
end

function Mod:OnEnable()
    self:BindDatabase()
    InitializeFrames()
    SetupOptionsPanel()
    Compat.ApplyColorsToOUF()

    if KT.db and not self._dbCallbacksRegistered then
        KT.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileReset", "Refresh")
        self._dbCallbacksRegistered = true
    end
end








