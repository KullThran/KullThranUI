local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local LSM = LibStub("LibSharedMedia-3.0", true)

-- ============================================================================
-- 1. DEFAULTS (Valores iniciales de la Base de Datos)
-- ============================================================================

local DEFAULT_FONT_NAME = (KT.GetDefaultFontName and KT:GetDefaultFontName()) or KT.DEFAULT_FONT_NAME or "AAA_ITC_Avant_Garde"
local DEFAULT_BAR_NAME = "Melli Reforged"
local COLOR_PINK_R, COLOR_PINK_G, COLOR_PINK_B = 1, 0, 0.333

-- Keep the saved locale identifier aligned with every locale shipped by KUI.
-- WoW uses enGB/ptPT client identifiers even though KUI shares those catalogs
-- with enUS/ptBR respectively.
local CLIENT_LOCALE_DEFAULTS = {
    enUS = "enUS", enGB = "enUS",
    esES = "esES", esMX = "esES",
    deDE = "deDE", frFR = "frFR", itIT = "itIT",
    ptBR = "ptBR", ptPT = "ptBR", ruRU = "ruRU",
    koKR = "koKR", zhCN = "zhCN", zhTW = "zhTW",
}

local function GetDefaultLanguage()
    local clientLocale = GetLocale and GetLocale() or "enUS"
    return CLIENT_LOCALE_DEFAULTS[clientLocale] or "enUS"
end

function KT:GenerateDefaults()
    local _, class = UnitClass("player")
    local cColor = C_ClassColor.GetClassColor(class) or {r=1, g=1, b=1}

    return {
        global = {
            changelog = {},
        },
        profile = {
            uiScale = 0.71,
            language = GetDefaultLanguage(),
             
            globalFont = {
                font = DEFAULT_FONT_NAME,
                inheritanceSource = DEFAULT_FONT_NAME,
                inheritanceVersion = 0,
            },
            
            skin = {
                enable = true,
                -- Five percentage points lighter than pure black for legibility.
                backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 1 },
                borderColor = { r = 1, g = 0.1843137294054031, b = 0.3921568989753723, a = 1 },
                headerColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 },
                accentColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = 0.3843137621879578, a = 1 },
                menuTextColor = { r = 0.98, g = 0.94, b = 0.96, a = 1 },
                menuSubtextColor = { r = 0.74, g = 0.74, b = 0.78, a = 1 },
                menuBackgroundTint = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = COLOR_PINK_B, a = 0.16 },
                stylePreset = "kui_crimson",
                menuIconColorMode = "accent",
                unlockModeColorMode = "accent",
                unlockModeColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = 0.3843137621879578, a = 1 },
                friendListColorMode = "accent",
                friendListColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = 0.3843137621879578, a = 1 },
                armoryColorMode = "accent",
                armoryColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = 0.3843137621879578, a = 1 },
                kullthranUIColorByClass = true,
                
                borderTheme = "CLASS", -- "KULLTHRAN", "CLASS", "CUSTOM"
                customBorderColor = { r = 1, g = 1, b = 1, a = 1 },
                
                blizzard = {
                    enable = true,
                    classicYellowAccent = false,
                    showWindowBorders = true,
                    damagemeter = false,
                    auctionhouse = true,
                    addonManager = true,
                    friends = true,
                    armory = true,
                    inspect = true,
                    gamemenu = true,
                    achievement = true,
                    alerts = true,
                    lfg = true,
                    guild = true,
                    encounterjournal = true,
                    quest = true,
                    gossip = true,
                    merchant = true,
                    mail = true,
                    worldmap = true,
                    professions = true,
                }
            },

            media = { font = DEFAULT_FONT_NAME },
            
            minimap = {
                shape = "SQUARE",
                scale = 1.2,
                borderSize = 1,
                borderColor = { r = 0, g = 0, b = 0, a = 1 },
                showFPS = true,
                showMS = true,
                showClock = true,
                showZone = true,
                showCoords = true,
                zoneFont = "AAA_ITC_Avant_Garde",
                zoneFontSize = 12,
                zoneFontOutline = "OUTLINE",
                zoneOffsetX = 0,
                zoneOffsetY = 0,
                statsFont = "AAA_ITC_Avant_Garde",
                statsFontSize = 11,
                statsFontOutline = "OUTLINE",
            },
            
            minimapButton = { enable = true, size = 28, spacing = 4, rows = 3, position = "LEFT" },
            tooltip = { enable = false, scoreType = "M+", showSpellID = true, showIcon = true, showTargetingPlayers = true, xOffset = -20, yOffset = 20, font = "AAA_ITC_Avant_Garde", fontSize = 12, fontOutline = "OUTLINE", textColor = { r = 1, g = 1, b = 1, a = 1 } },
            interruptsGlow = { enable = true, cdText = false, cdm = true },
            
            actionbars = {
                enable = true,
                buttonStyle = "BLIZZARD",
                buttonBackdropColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.5 },
                buttonSpacing = 2,
                buttonPadding = 2,
                hideHotkeys = false,
                showKeypressIndicator = true,
                hideMacroText = false,
                font = "AAA_ITC_Avant_Garde", fontSize = 16, fontOutline = "OUTLINE", fontColor = { r = 1, g = 1, b = 1, a = 1 },
                hotkeyFont = "AAA_ITC_Avant_Garde", hotkeyFontSize = 12, hotkeyFontOutline = "OUTLINE", hotkeyFontColor = { r = 1, g = 1, b = 1, a = 1 },
                macroFont = "AAA_ITC_Avant_Garde", macroFontSize = 12, macroFontOutline = "OUTLINE", macroFontColor = { r = 1, g = 1, b = 1, a = 1 },
                fadeBar1 = false, fadeBar2 = false, fadeBar3 = false, fadeBar4 = false, fadeBar5 = false, fadeBar6 = false, fadeBar7 = false, fadeBar8 = false, fadePet = false, fadeStance = false,
            },
            
            buffsAndDebuffs = {
                enable = true,
                style = "BLIZZARD",
                shape = "NONE",
                durationFont = "AAA_ITC_Avant_Garde", durationFontSize = 11, durationFontOutline = "OUTLINE", durationXOffset = 0, durationYOffset = -2,
                buffs = { size = 40, spacing = 2, perRow = 12, growDir = "LEFT" },
                debuffs = { size = 44, spacing = 2, perRow = 10, growDir = "LEFT" },
                countFont = "AAA_ITC_Avant_Garde", countFontSize = 12, countFontOutline = "OUTLINE", countXOffset = 2, countYOffset = 2,
            },
            
            dragonRiding = { enable = true, width = 250, height = 16, yOffset = -150, xOffset = 0, showSpeedText = true, texture = DEFAULT_BAR_NAME, font = "AAA_ITC_Avant_Garde", fontSize = 16, fontOutline = "OUTLINE" },
            castbar = { enable = true, width = 250, height = 30, scale = 1.0, frameStrata = "BACKGROUND", frameLevel = 10, texture = DEFAULT_BAR_NAME, color = { r = 1, g = 0, b = 0.3333, a = 1 }, colorMode = "THEME", classColor = false, textColor = { r = 1, g = 1, b = 1, a = 1 }, font = "AAA_ITC_Avant_Garde", fontSize = 16, fontOutline = "OUTLINE", showIcon = true, iconPosition = "LEFT", iconShape = "SQUARE" },
            
            armory = { enable = true, scale = 1.05, backgroundType = "CLASS", showPortrait = false, showIlvl = true, ilvlSize = 12, ilvlColorByRarity = true, ilvlColor = {r=1, g=1, b=1, a=1}, ilvlHeaderColor = {r=0.94, g=0.78, b=0.29, a=1}, showAvgIlvl = true, avgIlvlDecimals = true, avgIlvlColor = {r=0.7568627451, g=0, b=1, a=1}, showAvgIlvlPvP = true, avgIlvlPvPShowLabel = true, avgIlvlPvPDecimals = false, avgIlvlPvPFont = "AAA_ITC_Avant_Garde", avgIlvlPvPFontSize = 10, avgIlvlPvPOutline = "OUTLINE", avgIlvlPvPColor = {r=0, g=0.5, b=1, a=1}, avgIlvlPvPOffsetX = 0, avgIlvlPvPOffsetY = -2, showEnchant = true, enchantSize = 10, enchantFont = "AAA_ITC_Avant_Garde", enchantColor = {r=0, g=1, b=0.6156862745, a=1}, enhHeaderColor = {r=0.94, g=0.78, b=0.29, a=1}, enchantX = 0, enchantY = 2, colorStats = true, statFont = "AAA_ITC_Avant_Garde", scoreType = "M+", scoreFont = "AAA_ITC_Avant_Garde", statFontSize = 12, statSpacing = 2, secondaryStatDisplayMode = "percent", charNameFont = "AAA_ITC_Avant_Garde", charNameSize = 16, charNameOutline = "OUTLINE", charLevelFont = "AAA_ITC_Avant_Garde", charLevelSize = 12, charLevelOutline = "OUTLINE", headerFont = "AAA_ITC_Avant_Garde", headerOutline = "OUTLINE", itemLevelColor = {r=0.7568627451, g=0, b=1, a=1}, attrColor = {r=1, g=0.4823529412, b=0, a=1}, attrHeaderColor = {r=0.94, g=0.78, b=0.29, a=1}, enhColor = {r=0, g=1, b=0.6156862745, a=1}, strengthColor = {r=1, g=0.4823529412, b=0, a=1}, agilityColor = {r=1, g=0.4823529412, b=0, a=1}, intellectColor = {r=1, g=0.4823529412, b=0, a=1}, staminaColor = {r=1, g=0.4823529412, b=0, a=1}, armorColor = {r=1, g=0.4823529412, b=0, a=1}, critColor = {r=0, g=1, b=0.6156862745, a=1}, hasteColor = {r=0, g=1, b=0.6156862745, a=1}, masteryColor = {r=0, g=1, b=0.6156862745, a=1}, versatilityColor = {r=0, g=1, b=0.6156862745, a=1}, leechColor = {r=0, g=1, b=0.6156862745, a=1}, avoidanceColor = {r=0, g=1, b=0.6156862745, a=1}, speedColor = {r=0, g=1, b=0.6156862745, a=1}, dodgeColor = {r=0, g=1, b=0.6156862745, a=1}, parryColor = {r=0, g=1, b=0.6156862745, a=1}, blockColor = {r=0, g=1, b=0.6156862745, a=1}, showStrengthLabel = true, showAgilityLabel = true, showIntellectLabel = true, showStaminaLabel = true, showArmorLabel = true, showCritLabel = true, showHasteLabel = true, showMasteryLabel = true, showVersatilityLabel = true, showLeechLabel = true, showAvoidanceLabel = true, showSpeedLabel = true, showDodgeLabel = true, showParryLabel = true, showBlockLabel = true, separatorColor = {r=KT.C_R, g=KT.C_G, b=KT.C_B, a=1}, statsTexture = "KullThran Armory", statsColor = {r=1, g=1, b=1, a=1} },
            inspectArmory = { enable = true, scale = 1.25, backgroundType = "CLASS", modelZoom = 0, showIlvl = true, ilvlSize = 12, ilvlColorByRarity = true, ilvlColor = {r=1, g=1, b=1, a=1}, showAvgIlvl = true, avgIlvlDecimals = true, avgIlvlColor = {r=KT.C_R, g=KT.C_G, b=KT.C_B, a=1}, avgIlvlFont = "AAA_ITC_Avant_Garde", avgIlvlSize = 20, avgIlvlOutline = "OUTLINE", avgIlvlLabelFont = "AAA_ITC_Avant_Garde", avgIlvlLabelSize = 10, avgIlvlLabelOutline = "OUTLINE", avgIlvlLabelColor = {r=1, g=1, b=1, a=1}, showEnchant = true, enchantSize = 10, enchantFont = "AAA_ITC_Avant_Garde", enchantColor = {r=0, g=1, b=0.6156862745, a=1}, enchantX = 0, enchantY = 2, colorStats = true, statFont = "AAA_ITC_Avant_Garde", statFontSize = 12, attrColor = {r=1, g=0.82, b=0, a=1}, enhColor = {r=0, g=1, b=0.6156862745, a=1} },
            
            experienceBar = { enable = true, visible = true, disableAtMaxLevel = false, mode = "AUTO", width = 300, height = 10, x = 0, y = 0, texture = DEFAULT_BAR_NAME, font = "AAA_ITC_Avant_Garde", fontSize = 12, fontOutline = "OUTLINE", xpColor = {r=0,g=0.4,b=0.9,a=1}, restedColor = {r=1,g=0,b=1,a=1}, repColor = {r=0,g=0.8,b=0,a=1}, showText = true, showSessionData = false },
            chat = {
                enable = true,
                maxLines = 500,
                panelColor = { r = 0.05, g = 0.07, b = 0.09, a = 0.1 },
                highlightColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = COLOR_PINK_B },
                tabHighlightTexture = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\title_background_png.tga",
                tabConfigs = {
                    { id = "general", label = "General", prompt = "Say", command = "", filterMode = "GENERAL", channelMatch = "" },
                    { id = "combat", label = "Combat", prompt = "Combat Log", command = "", filterMode = "COMBAT", channelMatch = "" },
                    { id = "trade", label = "Trade", prompt = "Trade", command = "/1 ", filterMode = "CHANNEL", channelMatch = "" },
                    { id = "guild", label = "Guild", prompt = "Guild", command = "/g ", filterMode = "GUILD", channelMatch = "" },
                    { id = "group", label = "Group", prompt = "Group", command = "/p ", filterMode = "GROUP", channelMatch = "" },
                    { id = "whisper", label = "Whisp", prompt = "Whisper", command = "/w ", filterMode = "WHISPER", channelMatch = "" },
                },
                font = "AAA_ITC_Avant_Garde",
                fontSize = 12,
                fontOutline = "OUTLINE",
                classColorNames = true,
                fadeEnabled = true,
                fadeTimeVisible = 24,
                fadeDuration = 8,
                window = { visible = true, width = 500, height = 280, migratedLayoutV10 = true, migratedLayoutV11 = true, migratedLayoutV12 = true, migratedLayoutV13 = true, migratedLayoutV14 = true },
            },
            bags = {
                enable = true,
                watchedItems = {},
                viewMode = "category",
                panelColor = { r = 0.05, g = 0.07, b = 0.09, a = 0.94 },
                window = { visible = true, width = 760, height = 560, migratedLayoutV5 = true },
            },
            
            externalAddons = { enable = true },
            uufIntegration = { enable = true },
            editMode = { frames = {} },
            blizzframes = { fadeMicroMenu = false, fadeBags = false, fadeObjectiveTracker = false, fadeStatusBar = false, fadeQueueStatus = false, trackerFont = "AAA_ITC_Avant_Garde", trackerFontSizeHeaders = 16, trackerFontOutline = "OUTLINE", trackerColor = { r = KT.C_R, g = KT.C_G, b = KT.C_B, a = 1 } },
            objectiveTracker = {
                enable = true,
                font = DEFAULT_FONT_NAME,
                fontSize = 13,
                fontOutline = "OUTLINE",
                colorMode = "accent",
                customColor = { r = 1, g = 1, b = 1, a = 1 },
                bgAlpha = 0,
                hideInCombat = false,
                hideInArena = false,
                hideInDungeon = false,
                hideInRaid = false,
                fadeDelay = 0
            },
            installer = { showOnLogin = true }
        }
    }
end

-- ============================================================================
-- 2. UTILIDADES DE INTEGRACIÓN (Addons externos y perfiles)
-- ============================================================================

function KT:ForceSetProfile(addonName, profileName, altAddonName)
    local addon = LibStub("AceAddon-3.0"):GetAddon(addonName, true)
    if not addon and altAddonName then
        addon = LibStub("AceAddon-3.0"):GetAddon(altAddonName, true)
    end
    if not addon and addonName == "DandersFrames" then
        addon = LibStub("AceAddon-3.0"):GetAddon("DF", true)
    end
    
    if not addon and addonName == "BetterCooldownManager" then
        addon = LibStub("AceAddon-3.0"):GetAddon("BCM", true)
    end
    
    if not addon then
        if _G[addonName] and _G[addonName].db then addon = _G[addonName] end
        if not addon and altAddonName and _G[altAddonName] and _G[altAddonName].db then addon = _G[altAddonName] end
        if not addon and addonName == "DandersFrames" and _G.DF and _G.DF.db then addon = _G.DF end
    end
    
    if addon then
        if type(addon.SetProfile) == "function" then
            pcall(addon.SetProfile, addon, profileName)
        elseif addon.db then
            if addon.db.SetProfile then
                addon.db:SetProfile(profileName)
            else
                if addon.db.profile and type(addon.db.profile) == "table" and addon.db.keys then
                     addon.db:SetProfile(profileName)
                end
            end
            if addon.db.keys then
                addon.db.keys.profile = profileName
            end
        end
    end

    local dbNames
    if addonName == "DandersFrames" then
        dbNames = { "DandersFramesDB_v2", "DandersFramesCharDB" }
    else
        dbNames = { addonName .. "DB" }
        if altAddonName then table.insert(dbNames, altAddonName .. "DB") end
    end
    
    if addonName == "UnhaltedUnitFrames" then table.insert(dbNames, "UUFDB") end
    if addonName == "BetterCooldownManager" then 
        table.insert(dbNames, "BetterCooldownManagerDB")
        table.insert(dbNames, "BCMDB")
    end
    if addonName == "KullThranUI" then table.insert(dbNames, "KullThranDB") end
    
    local myName = UnitName("player")
    local myRealm = GetRealmName()
    local exactKey = myName .. " - " .. myRealm
    
    for _, dbName in ipairs(dbNames) do
        local db = _G[dbName]
        if not db then
            if addonName == "DandersFrames" and dbName == "DandersFramesDB_v2" then
                _G[dbName] = { profiles = {} }
            else
                _G[dbName] = { profileKeys = {} }
            end
            db = _G[dbName]
        end
        if db then
            if addonName == "DandersFrames" and dbName == "DandersFramesDB_v2" then
                db.currentProfile = profileName
                db.profiles = db.profiles or {}
            elseif addonName == "DandersFrames" and dbName == "DandersFramesCharDB" then
                db.currentProfile = profileName
            else
                if not db.profileKeys then db.profileKeys = {} end
                db.profileKeys[exactKey] = profileName
                for k, v in pairs(db.profileKeys) do
                    if type(k) == "string" and k:find("^" .. myName .. " %-") then
                        db.profileKeys[k] = profileName
                    end
                end
            end
        end
    end
end

function KT:OpenExternalAddon(name, slashCmds, aceApp, directFunc, manualSlashKey)
    local addonName = C_AddOns.GetAddOnInfo(name)
    if not addonName then return end
    
    local isLoaded = C_AddOns.IsAddOnLoaded(name)
    if not isLoaded then return end

    if self.MenuPrincipal and self.MenuPrincipal:IsShown() then 
        self.MenuPrincipal:Hide() 
    end

    local ACD = LibStub("AceConfigDialog-3.0", true)
    local ACR = LibStub("AceConfigRegistry-3.0", true)

    if aceApp and ACD and ACR then
        local registered = pcall(ACR.GetOptionsTable, ACR, aceApp)
        if registered then
            ACD:Open(aceApp)
            return
        end
    end

    if directFunc and type(_G[directFunc]) == "function" then
        pcall(_G[directFunc])
        return
    end

    if manualSlashKey then
        if SlashCmdList[manualSlashKey] then pcall(SlashCmdList[manualSlashKey], ""); return end
        if SlashCmdList[manualSlashKey:upper()] then pcall(SlashCmdList[manualSlashKey:upper()], ""); return end
    end

    if slashCmds then
        for _, cmd in ipairs(slashCmds) do
            local cleanCmd = cmd:gsub("^/", "")
            local upperCmd = cleanCmd:upper()
            if SlashCmdList[upperCmd] then pcall(SlashCmdList[upperCmd], ""); return end
            if SlashCmdList[cleanCmd] then pcall(SlashCmdList[cleanCmd], ""); return end
            
        end
    end

    if Settings and Settings.OpenToCategory then
        local category
        if Settings.GetCategory then category = Settings.GetCategory(name) end
        if not category then
            local categories = Settings.GetCategoryList and Settings.GetCategoryList()
            if categories then
                for _, cat in ipairs(categories) do
                    if cat.name == name then category = cat; break end
                end
            end
        end
        if category then pcall(Settings.OpenToCategory, category:GetID()); return end
    end

    if not Settings and InterfaceOptionsFrame_OpenToCategory then
        pcall(InterfaceOptionsFrame_OpenToCategory, name)
        pcall(InterfaceOptionsFrame_OpenToCategory, name)
        return
    end
end

-- ============================================================================
-- 3. SETUP BÁSICO (Popups y Comandos)
-- ============================================================================

function KT:SetupOptions()
    local L = self:GetLocale()

    StaticPopupDialogs["KULLTHRANUI_RELOAD"] = {
        text = L and L["RELOAD_TEXT"] or "You must reload your UI to apply these changes.",
        button1 = L and L["RELOAD_BTN1"] or "Reload",
        button2 = L and L["RELOAD_BTN2"] or "Cancel",
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }

    StaticPopupDialogs["KULLTHRANUI_RESET_CONFIRM"] = {
        text = L and L["RESET_CONFIRM_TEXT"] or "Are you sure you want to reset the profile?",
        button1 = L and L["Next"] or "Next",
        button2 = L and L["Cancel"] or "Cancel",
        OnAccept = function() 
            StaticPopup_Show("KULLTHRANUI_RESET_CONFIRM_2")
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }

    StaticPopupDialogs["KULLTHRANUI_RESET_CONFIRM_2"] = {
        text = L and L["RESET_CONFIRM_TEXT_2"] or "ARE YOU ABSOLUTELY SURE? This action cannot be undone.",
        button1 = L and L["RELOAD_BTN1"] or "Accept",
        button2 = L and L["Cancel"] or "Cancel",
        OnAccept = function() 
            KT.db:ResetProfile()
            if ns.ProfileData and ns.ProfileData.Layouts and ns.Handlers and ns.Handlers.Layout then
                local _, height = GetPhysicalScreenSize()
                local layout = "1080p"
                if height >= 2160 then layout = "4K"
                elseif height >= 1440 then layout = "2K" end
                if ns.ProfileData.Layouts[layout] then ns.Handlers.Layout(KT.db:GetCurrentProfile(), ns.ProfileData.Layouts[layout]) end
            end
            ReloadUI() 
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }

    -- Comandos de Debugging
    self:RegisterChatCommand("ktdebug", function() self:Print("DB Loaded: " .. (self.db and "Yes" or "No")) end)
    self:RegisterChatCommand("ktframe", function()
        local frame
        if _G.GetMouseFoci then
            local ok, foci = pcall(_G.GetMouseFoci)
            if ok and (not _G.canaccessvalue or _G.canaccessvalue(foci)) and type(foci) == "table" then
                frame = foci[1]
                if _G.canaccessvalue and not _G.canaccessvalue(frame) then frame = nil end
            end
        else
            local ok, focus = pcall(_G.GetMouseFocus)
            if ok and (not _G.canaccessvalue or _G.canaccessvalue(focus)) then frame = focus end
        end
        
        if frame then
            local name = frame:GetName() or tostring(frame)
            self:Print("|cff00FFFFFrame:|r " .. name)
            self:Print("Parent: " .. (frame:GetParent() and (frame:GetParent():GetName() or tostring(frame:GetParent())) or "nil"))
            self:Print("Size: " .. math.floor(frame:GetWidth()) .. "x" .. math.floor(frame:GetHeight()))
        else
            self:Print("No frame under mouse.")
        end
    end)
end
