local addonName, ns = ...

local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local LSM = LibStub("LibSharedMedia-3.0", true)

-- ============================================================================
-- DEFINICIONES Y MEDIOS
-- ============================================================================

local DEFAULT_FONT_PATH = (KT.GetDefaultFontPath and KT:GetDefaultFontPath()) or KT.DEFAULT_FONT_PATH or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
-- Keep the legacy Melli entry available for existing profiles while new profiles
-- use the custom Melli Reforged texture by default.
-- statusbars can appear fully transparent for users (e.g. DragonRiding bar).
local MEDIA_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\"
local MY_BAR_FILE = "Melli.tga"
local CUSTOM_TEXTURE_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\"
local CUSTOM_STATUSBAR_TEXTURES = {
    ["Melli Reforged"] = "MelliReforged.tga",
}

local DEFAULT_FONT_NAME = (KT.GetDefaultFontName and KT:GetDefaultFontName()) or KT.DEFAULT_FONT_NAME or "AAA_ITC_Avant_Garde"
local DEFAULT_BAR_NAME = "Melli Reforged"
local FONT_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\font" .. string.char(92)
local BUNDLED_FONTS = {
    ["Aldo PC"] = "Aldo PC.ttf",
    ["Captureit"] = "Captureit.ttf",
    ["Due Punto Zero"] = "duepuntozero.ttf",
    ["Emblem"] = "Emblem.ttf",
    ["PF Ronda Seven"] = "pf_ronda_seven.ttf",
    ["PF Ronda Seven Bold"] = "pf_ronda_seven_bold.ttf",
    ["Plane"] = "PLANE___.TTF",
    ["SF New Republic"] = "SF New Republic.ttf",
    ["Swansea"] = "SWANSE__.TTF",
    ["Swansea Bold"] = "SWANSE_B.TTF",
    ["Tempesta Seven Condensed"] = "Tempesta Seven Condensed.ttf",
}

local COLOR_PINK_R, COLOR_PINK_G, COLOR_PINK_B = 1, 0, 0.333

function KT:GenerateDefaults()
    return {
        profile = {
            uiScale = nil,
            autoResolutionScale = true,
            useBlizzardUIScale = false,
            uiScaleInitialized = false,
            language = "auto",
            
            globalFont = {
                font = DEFAULT_FONT_NAME,
                inheritanceSource = DEFAULT_FONT_NAME,
                inheritanceVersion = 0,
            },
            
            skin = {
                enable = true,
                backgroundColor = { r = 0, g = 0, b = 0, a = 1 },
                borderColor = { r = 1, g = 0.1843137294054031, b = 0.3921568989753723, a = 1 },
                headerColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 },
                accentColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = 0.3843137621879578, a = 1 },
                menuTextColor = { r = 0.98, g = 0.94, b = 0.96, a = 1 },
                menuSubtextColor = { r = 0.74, g = 0.74, b = 0.78, a = 1 },
                menuBackgroundTint = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = COLOR_PINK_B, a = 0.16 },
                stylePreset = "kui_crimson",
                menuIconColorMode = "accent",
                unlockModeColorMode = "accent",
                friendListColorMode = "accent",
                armoryColorMode = "accent",
                unlockModeColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = 0.3843137621879578, a = 1 },
                armoryColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = 0.3843137621879578, a = 1 },
                kullthranUIColorByClass = true,
                borderTheme = "CLASS",
                customBorderColor = { r = 1, g = 1, b = 1, a = 1 },
                blizzard = {
                    enable = true,
                    classicYellowAccent = false,
                    showWindowBorders = true,
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
                    battlenet = true,
                    quest = true,
                    gossip = true,
                    merchant = true,
                    worldmap = true,
                }
            },

            media = { font = DEFAULT_FONT_NAME },
            
            minimap = {
                enable = true,
                shape = "SQUARE",
                scale = 1.2,
                borderSize = 1,
                borderColor = { r = 0, g = 0, b = 0, a = 1 },
                showFPS = true,
                showMS = true,
                showClock = true,
                showZone = true,
                showCoords = true,
                zoneFont = DEFAULT_FONT_NAME,
                zoneFontSize = 12,
                zoneFontOutline = "OUTLINE",
                zoneOffsetX = 0,
                zoneOffsetY = 0,
                statsFont = DEFAULT_FONT_NAME,
                statsFontSize = 11,
                statsFontOutline = "OUTLINE",
            },
            
            minimapButton = {
                enable = true,
                size = 28,
                spacing = 4,
                cols = 4,
                position = "LEFT",
            },
            
            tooltip = {
                enable = true,
                scoreType = "M+",
                showSpellID = true,
                showIcon = true,
                font = DEFAULT_FONT_NAME,
                fontSize = 12,
                fontOutline = "OUTLINE",
                textColor = { r = 1, g = 1, b = 1, a = 1 },
            },
            
            interruptsGlow = {
                enable = true,
                cdText = false,
                cdm = true,
                slots = {},
                localCD = {},
            },
            
            partyTracker = {
                enable = true,
                scale = 1.0,
                iconSize = 24,
                spacing = 1,
                anchorPoint = "LEFT",
                growDirection = "LEFT",
                offsetX = 0,
                offsetY = 0,
                showBorder = true,
                showPlayer = false,
                fontSize = 12,
                font = DEFAULT_FONT_NAME,
                fontOutline = "OUTLINE",
                fontColor = { r = 1, g = 1, b = 1, a = 1 },
                zones = {
                    ['arena'] = true, ['pvp'] = true, ['party'] = true,
                    ['raid'] = false,  ['none'] = true
                },
                spells = {
                    [31224]=true,[118038]=true,[853]=true,[36554]=true,
                    [370553]=true,[187650]=true,[51052]=true,[20707]=true,
                    [204018]=true,[198589]=true,[5277]=true,[122278]=true,
                    [48707]=true,[116849]=true,[23920]=true,[196718]=true,
                    [871]=true,[80353]=true,[633]=true,[1022]=true,
                    [61336]=true,[115310]=true,[62618]=true,[450001]=true,
                    [6940]=true,[61999]=true,[102793]=true,[90355]=true,
                    [642]=true,[33206]=true,[108199]=true,[32612]=true,
                    [450101]=true,[2094]=true,[45438]=true,[450102]=true,
                    [11426]=true,[98008]=true,[55233]=true,[372760]=true,
                    [76577]=true,[116844]=true,[31884]=true,[450200]=true,
                    [48792]=true,[450201]=true,[108280]=true,[109304]=true,
                    [19577]=true,[47585]=true,[357170]=true,[107574]=true,
                    [20484]=true,[192058]=true,[2825]=true,[363916]=true,
                    [374227]=true,[97462]=true,[179057]=true,[106898]=true,
                    [10060]=true,[108416]=true,[740]=true,[122783]=true,
                    [186265]=true,[31821]=true,[104773]=true,[114052]=true,
                    [115203]=true,[53480]=true,[102342]=true,[359816]=true,
                    [73325]=true,[22812]=true,[119381]=true,[29166]=true,
                    [265202]=true,[450400]=true,[192077]=true,[235219]=true,
                    [47788]=true,[111771]=true,[450100]=true,[108271]=true,
                    [1856]=true,[363534]=true,[46968]=true,[20608]=true,
                },
            },
            
            actionbars = {
                enable = true,
                buttonStyle = "BLIZZARD",
                buttonBackdropColor = { r = 0.1019607931375504, g = 0.1019607931375504, b = 0.1019607931375504, a = 0.7343736886978149 },
                buttonSpacing = 0,
                buttonPadding = 0,
                hideHotkeys = false,
                hideMacroText = false,
                font = DEFAULT_FONT_NAME,
                fontSize = 20,
                fontOutline = "OUTLINE",
                fontColor = { r = 1, g = 1, b = 1, a = 1 },
                hotkeyFont = DEFAULT_FONT_NAME,
                hotkeyFontSize = 12,
                hotkeyFontOutline = "OUTLINE",
                hotkeyFontColor = { r = 1, g = 1, b = 1, a = 1 },
                macroFont = DEFAULT_FONT_NAME,
                macroFontSize = 12,
                macroFontOutline = "OUTLINE",
                macroFontColor = { r = 1, g = 1, b = 1, a = 1 },
                fadeBar1 = false, fadeBar2 = false, fadeBar3 = false,
                fadeBar4 = false, fadeBar5 = false, fadeBar6 = false,
                fadeBar7 = false, fadeBar8 = false, fadePet = false, fadeStance = false,
            },
            
            dragonRiding = {
                enable = true,
                width = 215,
                height = 25,
                yOffset = 92,
                xOffset = 0,
                texture = DEFAULT_BAR_NAME,
                showUnits = true,
                showSpeedText = true,
                font = DEFAULT_FONT_NAME,
                fontSize = 12,
                fontOutline = "OUTLINE",
            },
            
            castbar = {
                enable = true,
                width = 250,
                height = 20,
                scale = 1.0,
                frameStrata = "BACKGROUND",
                frameLevel = 10,
                texture = DEFAULT_BAR_NAME,
                color = { r = 1, g = 0, b = 0.3333, a = 1 },
                colorMode = "THEME",
                classColor = false,
                textColor = { r = 1, g = 1, b = 1, a = 1 },
                font = DEFAULT_FONT_NAME,
                fontSize = 16,
                fontOutline = "OUTLINE",
                showIcon = true,
                iconPosition = "LEFT",
                iconShape = "SQUARE",
            },
            
            experienceBar = {
                enable = true,
                visible = true,
                mode = "XP",
                disableAtMaxLevel = true,
                width = 567,
                height = 24,
                x = -0.9999198317527771,
                y = 15.00151443481445,
                point = "BOTTOM",
                xOffset = 0,
                yOffset = -20,
                anchorPoint = "TOP",
                relativePoint = "BOTTOM",
                texture = DEFAULT_BAR_NAME,
                font = DEFAULT_FONT_NAME,
                fontSize = 12,
                fontOutline = "OUTLINE",
                showText = true,
                showSessionData = true,
                xpColor    = { r = 0.33, g = 0.38, b = 1,   a = 1   },
                honorColor = { r = 1,    g = 0.2,  b = 0.2, a = 1   },
                repColor   = { r = 0,    g = 0.8,  b = 0,   a = 1   },
                restedColor= { r = 1,    g = 0.2,  b = 1,   a = 0.5 },
            },
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
                window = {
                    visible = true,
                    width = 500,
                    height = 280,
                    migratedLayoutV10 = true,
                    migratedLayoutV11 = true,
                    migratedLayoutV12 = true,
                    migratedLayoutV13 = true,
                    migratedLayoutV14 = true,
                    migratedLayoutV15 = true,
                },
            },
            bags = {
                enable = true,
                watchedItems = {},
                viewMode = "category",
                panelColor = { r = 0.05, g = 0.07, b = 0.09, a = 0.94 },
                window = {
                    visible = true,
                    width = 760,
                    height = 560,
                    migratedLayoutV5 = true,
                },
            },
            
            armory = {
                enable = true,
                scale = 1.05,
                backgroundType = "CLASS",
                showPortrait = false,
                showIlvl = true,
                ilvlSize = 12,
                ilvlFont = DEFAULT_FONT_NAME,
                ilvlOutline = "OUTLINE",
                ilvlColorByRarity = true,
                ilvlColor = {r=1, g=1, b=1, a=1},
                ilvlHeaderColor = {r=0.94, g=0.78, b=0.29, a=1},
                showAvgIlvl = true,
                avgIlvlDecimals = true,
                avgIlvlColor = {r=0.7568627451, g=0, b=1, a=1},
                avgIlvlFont = DEFAULT_FONT_NAME,
                avgIlvlFontSize = 19,
                avgIlvlOutline = "OUTLINE",
                showEnchant = true,
                enchantSize = 10,
                enchantFont = DEFAULT_FONT_NAME,
                enchantColor = {r=0, g=1, b=0.6156862745, a=1},
                enhHeaderColor = {r=0.94, g=0.78, b=0.29, a=1},
                enchantX = 0, enchantY = 0,
                colorStats = true,
                statFont = DEFAULT_FONT_NAME,
                scoreType = "M+",
                scoreFont = DEFAULT_FONT_NAME,
                scoreSize = 16,
                scoreOutline = "OUTLINE",
                statFontSize = 12,
                statSpacing = -5,
                secondaryStatDisplayMode = "percent",
                charNameFont = DEFAULT_FONT_NAME,
                charNameSize = 16,
                charNameOutline = "OUTLINE",
                charLevelFont = DEFAULT_FONT_NAME,
                charLevelSize = 12,
                charLevelOutline = "OUTLINE",
                headerFont = DEFAULT_FONT_NAME,
                headerOutline = "OUTLINE",
                itemLevelColor = {r=0.7568627451, g=0, b=1, a=1},
                attrColor = {r=1, g=0.4823529412, b=0, a=1},
                attrHeaderColor = {r=0.94, g=0.78, b=0.29, a=1},
                enhColor = {r=0, g=1, b=0.6156862745, a=1},
                strengthColor    = {r=1, g=0.4823529412, b=0, a=1},
                agilityColor     = {r=1, g=0.4823529412, b=0, a=1},
                intellectColor   = {r=1, g=0.4823529412, b=0, a=1},
                staminaColor     = {r=1, g=0.4823529412, b=0, a=1},
                armorColor       = {r=1, g=0.4823529412, b=0, a=1},
                critColor        = {r=0.20, g=0.66, b=0.90, a=1},
                hasteColor       = {r=0.20, g=0.66, b=0.90, a=1},
                masteryColor     = {r=0.20, g=0.66, b=0.90, a=1},
                versatilityColor = {r=0.20, g=0.66, b=0.90, a=1},
                leechColor       = {r=0.20, g=0.66, b=0.90, a=1},
                avoidanceColor   = {r=0.20, g=0.66, b=0.90, a=1},
                speedColor       = {r=0.20, g=0.66, b=0.90, a=1},
                dodgeColor       = {r=0.20, g=0.66, b=0.90, a=1},
                parryColor       = {r=0.20, g=0.66, b=0.90, a=1},
                blockColor       = {r=0.20, g=0.66, b=0.90, a=1},
                showStrengthLabel = true,
                showAgilityLabel = true,
                showIntellectLabel = true,
                showStaminaLabel = true,
                showArmorLabel = true,
                showCritLabel = true,
                showHasteLabel = true,
                showMasteryLabel = true,
                showVersatilityLabel = true,
                showLeechLabel = true,
                showAvoidanceLabel = true,
                showSpeedLabel = true,
                showDodgeLabel = true,
                showParryLabel = true,
                showBlockLabel = true,
                separatorColor   = {r=COLOR_PINK_R, g=COLOR_PINK_G, b=COLOR_PINK_B, a=1},
                statsTexture = "KullThran Armory",
                statsColor = {r=1, g=1, b=1, a=1},
            },
            
            inspectArmory = {
                enable = true,
                scale = 1.25,
                backgroundType = "CLASS",
                modelZoom = 0,
                showIlvl = true,
                ilvlSize = 12,
                ilvlFont = DEFAULT_FONT_NAME,
                ilvlOutline = "OUTLINE",
                ilvlColorByRarity = true,
                ilvlColor = {r=1, g=1, b=1, a=1},
                showAvgIlvl = true,
                avgIlvlDecimals = true,
                avgIlvlColor = {r=COLOR_PINK_R, g=COLOR_PINK_G, b=COLOR_PINK_B, a=1},
                avgIlvlFont = DEFAULT_FONT_NAME,
                avgIlvlSize = 20,
                avgIlvlOutline = "OUTLINE",
                avgIlvlLabelFont = DEFAULT_FONT_NAME,
                avgIlvlLabelSize = 10,
                avgIlvlLabelOutline = "OUTLINE",
                avgIlvlLabelColor = {r=1, g=1, b=1, a=1},
                showEnchant = true,
                enchantSize = 10,
                enchantFont = DEFAULT_FONT_NAME,
                enchantColor = {r=0, g=1, b=0, a=1},
                enchantX = 0, enchantY = 2,
                colorStats = true,
                statFont = DEFAULT_FONT_NAME,
                statFontSize = 12,
                attrColor = {r=1, g=0.82, b=0, a=1},
                enhColor = {r=0, g=1, b=0, a=1},
            },
            
            buffsAndDebuffs = {
                enable = true,
                style = "BLIZZARD",
                shape = "NONE",
                durationFont        = DEFAULT_FONT_NAME,
                durationFontSize    = 11,
                durationFontOutline = "OUTLINE",
                durationXOffset     = 0,
                durationYOffset     = -2,
                countFont        = DEFAULT_FONT_NAME,
                countFontSize    = 12,
                countFontOutline = "OUTLINE",
                countXOffset     = 2,
                countYOffset     = 2,
                buffs   = { size = 40, spacing = 2, perRow = 12, growDir = "LEFT" },
                debuffs = { size = 44, spacing = 2, perRow = 10, growDir = "LEFT" },
            },

            grid2Integration       = { enable = true },
            externalAddons         = { enable = true },
            uufIntegration         = { enable = true },
            editMode               = {
                frames = {},
                unlockGrid = "dimmed",
                unlockSnap = true,
                unlockDarkOverlays = true,
                unlockCoords = false,
            },
            
            blizzframes = {
                fadeMicroMenu = false,
                fadeBags = false,
                fadeObjectiveTracker = false,
                fadeStatusBar = false,
                fadeQueueStatus = false,
                trackerFont = DEFAULT_FONT_NAME,
                trackerFontSizeHeaders = 16,
                trackerFontOutline = "OUTLINE",
                trackerColor = { r = COLOR_PINK_R, g = COLOR_PINK_G, b = COLOR_PINK_B, a = 1 },
            },
            
            installer = {
                showOnLogin = true,
                suppressChangelogAutoPopup = false,
                lastVersion = "1.0",
                step = 1,
            },

            -- ================================================================
            -- COOLDOWN MANAGER DEFAULTS
            -- ================================================================
            cooldownManager = {
                _capturedOnce = false,
                reskinBorders   = true,
                utilityScale    = 1.0,
                buffBarScale    = 1.0,
                cooldownBarScale = 1.0,
                spec            = {},
                activeSpecKey   = "0",
                barGlows = {
                    enabled = true,
                    selectedBar = 1,
                    selectedButton = nil,
                    selectedAssignment = 1,
                    assignments = {},
                },
                trackedBuffBars = {
                    selectedBar = 1,
                    bars = {}
                },
                cdmBars = {
                    enabled = true,
                    hideBlizzard = true,
                    bars = {
                        {
                            key = "cooldowns", name = "Cooldowns", enabled = true,
                            barType = "cooldowns", displayMode = "ICON",
                            barScale = 1.0, iconSize = 42, numRows = 1, spacing = 2,
                            borderSize = 1, borderR = 0, borderG = 0, borderB = 0, borderA = 1,
                            borderClassColor = false,
                            bgR = 0.08, bgG = 0.08, bgB = 0.08, bgA = 0.6,
                            iconZoom = 0.08, iconShape = "none", growDirection = "RIGHT",
                            verticalOrientation = false, barBgEnabled = false, barBgAlpha = 1.0,
                            barBgR = 0, barBgG = 0, barBgB = 0,
                            showCooldownText = true, cooldownFontSize = 15,
                            showCharges = true, chargeFontSize = 11,
                            desaturateOnCD = true, swipeAlpha = 0.7,
                            borderThickness = "thin", activeStateAnim = "blizzard",
                            activeAnimClassColor = false, activeAnimR = 1.0, activeAnimG = 0.85, activeAnimB = 0.0,
                            anchorTo = "none", anchorPosition = "left",
                            anchorOffsetX = 0, anchorOffsetY = 0,
                            barVisibility = "always", housingHideEnabled = true,
                            hideBuffsWhenInactive = true,
                            showStackCount = true, stackCountSize = 11,
                            stackCountX = 0, stackCountY = 0,
                            stackCountR = 1, stackCountG = 1, stackCountB = 1,
                        },
                        {
                            key = "utility", name = "Utility", enabled = true,
                            barType = "utility", displayMode = "ICON",
                            barScale = 1.0, iconSize = 28, numRows = 1, spacing = 2,
                            borderSize = 1, borderR = 0, borderG = 0, borderB = 0, borderA = 1,
                            borderClassColor = false,
                            bgR = 0.08, bgG = 0.08, bgB = 0.08, bgA = 0.6,
                            iconZoom = 0.08, iconShape = "none", growDirection = "RIGHT",
                            verticalOrientation = false, barBgEnabled = false, barBgAlpha = 1.0,
                            barBgR = 0, barBgG = 0, barBgB = 0,
                            showCooldownText = true, cooldownFontSize = 15,
                            showCharges = true, chargeFontSize = 11,
                            desaturateOnCD = true, swipeAlpha = 0.7,
                            borderThickness = "thin", activeStateAnim = "blizzard",
                            activeAnimClassColor = false, activeAnimR = 1.0, activeAnimG = 0.85, activeAnimB = 0.0,
                            anchorTo = "none", anchorPosition = "left",
                            anchorOffsetX = 0, anchorOffsetY = 0,
                            barVisibility = "always", housingHideEnabled = true,
                            hideBuffsWhenInactive = true,
                            showStackCount = true, stackCountSize = 11,
                            stackCountX = 0, stackCountY = 0,
                            stackCountR = 1, stackCountG = 1, stackCountB = 1,
                        },
                        {
                            key = "buffs", name = "Buffs", enabled = true,
                            barType = "buffs", displayMode = "ICON",
                            barScale = 1.0, iconSize = 32, numRows = 1, spacing = 2,
                            borderSize = 1, borderR = 0, borderG = 0, borderB = 0, borderA = 1,
                            borderClassColor = false,
                            bgR = 0.08, bgG = 0.08, bgB = 0.08, bgA = 0.6,
                            iconZoom = 0.08, iconShape = "none", growDirection = "RIGHT",
                            verticalOrientation = false, barBgEnabled = false, barBgAlpha = 1.0,
                            barBgR = 0, barBgG = 0, barBgB = 0,
                            showCooldownText = true, cooldownFontSize = 15,
                            showCharges = true, chargeFontSize = 11,
                            desaturateOnCD = true, swipeAlpha = 0.7,
                            borderThickness = "thin", activeStateAnim = "blizzard",
                            activeAnimClassColor = false, activeAnimR = 1.0, activeAnimG = 0.85, activeAnimB = 0.0,
                            anchorTo = "none", anchorPosition = "left",
                            anchorOffsetX = 0, anchorOffsetY = 0,
                            barVisibility = "always", housingHideEnabled = true,
                            hideBuffsWhenInactive = true,
                            showStackCount = true, stackCountSize = 11,
                            stackCountX = 0, stackCountY = 0,
                            stackCountR = 1, stackCountG = 1, stackCountB = 1,
                        },
                    },
                },
                cdmBarPositions = {},
                tbbPositions = {},
                specProfiles = {},
                global = {
                    multiChargeSpells = {},
                },
            },
            progressBars = {
                trackedBuffBars = {
                    selectedBar = 1,
                    bars = {},
                },
                customAuraBars = {
                    selectedBar = 1,
                    bars = {},
                },
                catalog = {},
                tbbPositions = {},
            },
        }
    }
end

-- ============================================================================
-- UTILIDADES
-- ============================================================================
-- ============================================================================

local function ApplyAuraUtilBigDefensiveSecureFix()
    -- Do not override AuraUtil.IsBigDefensive.
    -- Replacing Blizzard AuraUtil functions taints CompactUnitFrame and
    -- nameplate aura update paths, which then causes secret-value errors in
    -- Blizzard code (including outOfRange checks on CompactPartyFrameMember).
    return
end

local function ApplyCUnitAurasArgGuards()
    -- NOTE: Do not override C_UnitAuras.* APIs.
    -- Wrapping C_ APIs in Lua taints Blizzard nameplate code paths and can trigger
    -- "secret number" errors in Blizzard_TextStatusBar / nameplates.
    return
end

function KT:OnInitialize()
    -- The DB is loaded here, so recompute the localized font from the ACTIVE
    -- language (profile.language) rather than the CLIENT locale. On Western
    -- clients this picks the bundled CJK/OFL fonts for koKR/zhCN/zhTW.
    if KT.GetLocalizedFontPathSafe and KT.GetActiveLanguage then
        local activeLang = self:GetActiveLanguage()
        if activeLang then
            KT.LOCALIZED_FONT_PATH = KT.GetLocalizedFontPathSafe(activeLang)
        end
    end
    if LSM then
        LSM:Register("font",      DEFAULT_FONT_NAME, DEFAULT_FONT_PATH)
        for name, fileName in pairs(BUNDLED_FONTS) do
            LSM:Register("font", name, FONT_PATH .. fileName)
        end
        if KT.LOCALIZED_FONT_NAME and KT.LOCALIZED_FONT_PATH then
            LSM:Register("font", KT.LOCALIZED_FONT_NAME, KT.LOCALIZED_FONT_PATH)
        end
        -- Bundled OFL CJK fonts: guaranteed readable on any client locale.
        local bundledCJK = {
            { "Noto Sans KR", KT.BUNDLED_KO_FONT },
            { "Noto Sans SC", KT.BUNDLED_ZHCN_FONT },
            { "Noto Sans TC", KT.BUNDLED_ZHTW_FONT },
        }
        for _, entry in ipairs(bundledCJK) do
            if entry[1] and entry[2] then
                LSM:Register("font", entry[1], entry[2])
            end
        end
        -- Native Cyrillic greymatter ships with every client: expose it under the
        -- real display name so ruRU pickers resolve to it on any locale.
        LSM:Register("font", "Friz Quadrata TT (Cyrillic)", "Fonts\\FRIZQT___CYR.TTF")
        -- Non-Latin safety net: the bundled Latin-only faces (Avant Garde,
        -- Friz Quadrata, and every display font in BUNDLED_FONTS) cannot render
        -- koKR/zhCN/zhTW/ruRU text. Alias them to the active-language font so
        -- EVERY LSM:Fetch on those names resolves glyph-correct, no matter
        -- whether the caller goes through KT:ResolveFontPath or not.
        if KT.IsNonLatinLocale and KT:IsNonLatinLocale() and KT.LOCALIZED_FONT_PATH then
            local replace = { ["AAA_ITC_Avant_Garde"] = true }
            replace[DEFAULT_FONT_NAME] = true
            for name in pairs(BUNDLED_FONTS) do
                replace[name] = true
            end
            local activeLang = KT.GetActiveLanguage and KT:GetActiveLanguage()
            if activeLang and activeLang ~= "ruRU" then
                -- On ruRU the client-native FRIZQT___CYR renders Cyrillic, so
                -- keep Friz Quadrata TT as-is; alias it on CJK instead.
                replace["Friz Quadrata TT"] = true
                -- Russo One carries Latin + Cyrillic but no CJK glyphs.
                replace["Russo One"] = true
            end
            for name in pairs(replace) do
                LSM:Register("font", name, KT.LOCALIZED_FONT_PATH)
            end
        end
        LSM:Register("statusbar", "Melli", MEDIA_PATH .. MY_BAR_FILE)
        -- Convenience alias for unitframe backgrounds / darker variant.
        if LSM.Register then
            LSM:Register("statusbar", "Melli Dark", MEDIA_PATH .. "MelliDark.tga")
            for name, fileName in pairs(CUSTOM_STATUSBAR_TEXTURES) do
                LSM:Register("statusbar", name, CUSTOM_TEXTURE_PATH .. fileName)
            end
        end
    end

    self:InitializeCore()
    if self.NormalizeProfileFontsForLocale then
        self:NormalizeProfileFontsForLocale()
    end
    -- Force a font path refresh after DB loads so manual language overrides are correctly applied
    if self.RefreshFontPath then
        self:RefreshFontPath()
    end
    C_Timer.After(5.0, function() if KT and KT.EnforceUIScaleLock then KT:EnforceUIScaleLock() end end)

    if not self._uiScaleStartupWatcher then
        self._uiScaleStartupWatcher = CreateFrame("Frame")
        self._uiScaleStartupWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
        self._uiScaleStartupWatcher:SetScript("OnEvent", function()
            if KT and KT.EnforceUIScaleLock then
                KT:EnforceUIScaleLock()
                C_Timer.After(1.0, function() if KT and KT.EnforceUIScaleLock then KT:EnforceUIScaleLock() end end)
                C_Timer.After(3.0, function() if KT and KT.EnforceUIScaleLock then KT:EnforceUIScaleLock() end end)
            end
        end)
    end

    if self.SetupOptions then
        self:SetupOptions()
    else
        local L = self.GetLocale and self:GetLocale()
        self:Print((L and L["|cffFF0000ERROR:|r SetupOptions was not found."])
            or "|cffFF0000ERROR:|r SetupOptions was not found.")
    end

    -- Comandos de chat
    -- ToggleConfig ahora llama a KT:OpenMenu() definido en Options.lua
    self:RegisterChatCommand("ktfindcmd", function() FindSlashCommands() end)
    self:RegisterChatCommand("ktrefresh", function()
        local minimap = self:GetModule("Minimap", true)
        if minimap and minimap.Refresh then minimap:Refresh() end
        local armory = self:GetModule("Armory", true)
        if armory and armory.Refresh then armory:Refresh() end
        local L = self.GetLocale and self:GetLocale()
        self:Print((L and L["Modules refreshed"]) or "Modules refreshed")
    end)

    if self.PrintStartupMessages then
        self:PrintStartupMessages()
    end

    ApplyAuraUtilBigDefensiveSecureFix()
end

local function RefreshGameMenuLayout()
    if _G.GameMenuFrame then
        C_Timer.After(0, function()
            local escapeMenu = KT.GetModule and KT:GetModule("EscapeMenu", true)
            if escapeMenu and escapeMenu.RequestRefresh then
                pcall(escapeMenu.RequestRefresh, escapeMenu)
            end
        end)
    end
end

local function QueuePendingUIScaleApply(self, scale)
    if not self then return end
    self._pendingUIScale = scale

    if not self._pendingUIScaleEvent then
        self._pendingUIScaleEvent = CreateFrame("Frame")
        self._pendingUIScaleEvent:SetScript("OnEvent", function(frame, event)
            if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
                if KT and not (InCombatLockdown and InCombatLockdown()) then
                    frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
                    KT:ApplyUIScale()
                end
            end
        end)
    end

    self._pendingUIScaleEvent:RegisterEvent("PLAYER_REGEN_ENABLED")
    self._pendingUIScaleEvent:RegisterEvent("PLAYER_ENTERING_WORLD")
end

local function SyncUIScaleCVar(scale)
    scale = tonumber(scale)
    if not (scale and scale > 0) then return end
    if not (C_CVar and C_CVar.SetCVar) then return end
    if not (IsLoggedIn and IsLoggedIn()) then
        if KT then
            KT._pendingUIScaleCVar = scale
            QueuePendingUIScaleApply(KT, scale)
        end
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        if KT then
            KT._pendingUIScaleCVar = scale
            QueuePendingUIScaleApply(KT, scale)
        end
        return
    end

    local scaleStr = tostring(scale)
    if C_CVar.GetCVar then
        local currentUse = tostring(C_CVar.GetCVar("useUiScale") or "")
        local currentScale = tostring(C_CVar.GetCVar("uiScale") or "")
        if currentUse == "1" and currentScale == scaleStr then
            if KT then
                KT._pendingUIScaleCVar = nil
            end
            return
        end
    end

    KT._applyingCVar = true
    C_CVar.SetCVar("useUiScale", 1)
    C_CVar.SetCVar("uiScale", scaleStr)
    KT._pendingUIScaleCVar = nil
    KT._applyingCVar = nil
end

function KT:GetBlizzardUIScale()
    local scale
    if C_CVar and C_CVar.GetCVar then
        scale = tonumber(C_CVar.GetCVar("uiScale") or "1")
        if not scale or scale <= 0 then
            scale = nil
        end
    end

    if not scale and _G.UIParent and _G.UIParent.GetScale then
        scale = _G.UIParent:GetScale()
    end

    return scale
end

function KT:SetBlizzardUIScale(scale)
    scale = tonumber(scale)
    if not scale or scale <= 0 then return end

    if self.db and self.db.profile then
        self.db.profile.uiScale = scale
        self.db.profile.autoResolutionScale = false
    end

    self._pendingBlizzardScale = scale
    self:ApplyUIScale()
end

function KT:_ApplyScaleValue(scale)
    if not (scale and scale > 0) then return end

    if (InCombatLockdown and InCombatLockdown()) or not (IsLoggedIn and IsLoggedIn()) then
        QueuePendingUIScaleApply(self, scale)
        return
    end

    -- Only touch Blizzard's CVar when the user explicitly chose Blizzard UI Scale.
    if self.db and self.db.profile and self.db.profile.useBlizzardUIScale then
        SyncUIScaleCVar(scale)
    end

    self._applyingUIScale = true
    _G.UIParent:SetScale(scale)
    self._applyingUIScale = nil
    self._pendingUIScale = nil
    if self._pendingUIScaleEvent then
        self._pendingUIScaleEvent:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self._pendingUIScaleEvent:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
    RefreshGameMenuLayout()
end

function KT:EnforceUIScaleLock()
    if not (self and self.db and self.db.profile and _G.UIParent) then return end
    if self.db.profile.useBlizzardUIScale then return end

    local desired = tonumber(self.db.profile.uiScale)
    local auto = (self.db.profile.autoResolutionScale ~= false)
    if auto or not desired then
        local _, height = GetPhysicalScreenSize()
        if height and height >= 2160 then
            desired = 0.35
        elseif height and height >= 1440 then
            desired = 0.53
        else
            desired = 0.71
        end
        self.db.profile.uiScale = desired
    end

    if not (desired and desired > 0) then return end

    local current = _G.UIParent.GetScale and _G.UIParent:GetScale() or nil
    if not current or math.abs(current - desired) > 0.001 then
        self:_ApplyScaleValue(desired)
    end

    self._scaleLockValue = desired
end

function KT:ApplyUIScale()
    if self._suppressApplyUIScale then return end
    if not (self.db and self.db.profile and _G.UIParent) then return end

    if self._applyScaleInProgress then return end
    self._applyScaleInProgress = true

    if self.db.profile.uiScaleInitialized ~= true then
        self.db.profile.uiScaleInitialized = true
    end

    if self.db.profile.useBlizzardUIScale == nil then
        self.db.profile.useBlizzardUIScale = true
    end

    if self.db.profile.useBlizzardUIScale then
        if not self._blizzardScaleWatcher then
            self._blizzardScaleWatcher = CreateFrame("Frame")
            self._blizzardScaleWatcher:SetScript("OnEvent", function(_, event, arg1)
                if KT and (KT._applyingUIScale or KT._applyingCVar or KT._applyScaleInProgress) then return end
                if event == "CVAR_UPDATE" then
                    local cvar = type(arg1) == "string" and arg1:lower() or ""
                    if cvar ~= "uiscale" and cvar ~= "useuiscale" then
                        return
                    end
                end
                if KT and KT.db and KT.db.profile and KT.db.profile.useBlizzardUIScale then
                    KT:ApplyUIScale()
                end
            end)
        end
        self._blizzardScaleWatcher:RegisterEvent("UI_SCALE_CHANGED")
        self._blizzardScaleWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
        self._blizzardScaleWatcher:RegisterEvent("CVAR_UPDATE")

        local scale = self._pendingBlizzardScale or self:GetBlizzardUIScale()
        self._pendingBlizzardScale = nil

        if not scale then
            scale = tonumber(self.db.profile.uiScale) or 1
        end

        if scale and scale > 0 then
            self.db.profile.uiScale = scale
            self:_ApplyScaleValue(scale)
        end
        self._applyScaleInProgress = nil
        return
    end

    if self._blizzardScaleWatcher then
        self._blizzardScaleWatcher:UnregisterEvent("UI_SCALE_CHANGED")
        self._blizzardScaleWatcher:UnregisterEvent("DISPLAY_SIZE_CHANGED")
        self._blizzardScaleWatcher:UnregisterEvent("CVAR_UPDATE")
    end

    local scale = tonumber(self.db.profile.uiScale)
    local auto = (self.db.profile.autoResolutionScale ~= false)
    if auto or not scale then
        local _, height = GetPhysicalScreenSize()
        if height and height >= 2160 then
            scale = 0.35
        elseif height and height >= 1440 then
            scale = 0.53
        else
            scale = 0.71
        end
        self.db.profile.uiScale = scale
    end

    self:_ApplyScaleValue(scale)
    self._applyScaleInProgress = nil
end

function KT:Debug()
    self:Print("DB Loaded: " .. (self.db and "Yes" or "No"))
end

-- ============================================================================
-- TOGGLE CONFIG: ahora delega al nuevo sistema de menú (Options.lua)
-- ============================================================================
function KT:ToggleConfig()
    self._suppressApplyUIScale = true
    KT:OpenMenu()
    C_Timer.After(0, function() KT._suppressApplyUIScale = false end)
end
