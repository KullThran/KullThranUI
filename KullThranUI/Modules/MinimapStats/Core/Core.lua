local _, MS = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local MinimapStats = KT:NewModule("MinimapStats", "AceEvent-3.0") -- Register as Module

local Defaults = {
    global = {
        General = {
            Enable = true,
            ClassColour = false,
            AccentColour = {128, 128, 255},
            Font = "Friz Quadrata TT",
            FontFlag = "OUTLINE",
            FrameStrata = "MEDIUM",
            FontShadow = {
                Colour = {0, 0, 0, 1},
                OffsetX = 0,
                OffsetY = 0,
            }
        },
        Time = {
            Enable = true,
            TimeZone = "Local",
            Format = "24H",
            UpdateInterval = 60.0,
            Colour = {255, 255, 255},
            Layout = {"BOTTOMLEFT", "BOTTOMLEFT", 3, 17, 18},
        },
        SystemStats = {
            Enable = true,
            Layout = {"BOTTOMLEFT", "BOTTOMLEFT", 3, 3, 12},
            UpdateInterval = 3.0,
            String = "%fps | %home",
            Colour = {255, 255, 255},
        },
        Location = {
            Enable = true,
            Layout = {"TOPLEFT", "TOPLEFT", 3, -3, 12},
            ColourBy = "REACTION",
            Colour = {255, 255, 255},
            SubZone = false,
        },
        InstanceDifficulty = {
            Enable = true,
            Layout = {"TOPLEFT", "TOPLEFT", 3, -17, 12},
            Colour = {255, 255, 255},
            Abbreviate = true,
            HideBlizzardInstanceBanner = true,
        },
        Coordinates = {
            Enable = true,
            Layout = {"TOPRIGHT", "TOPRIGHT", -3, -3, 12},
            ColourBy = "CUSTOM",
            Colour = {255, 255, 255},
            UpdateInterval = 1.0,
            Format = "SINGLE",
        },
        Tooltip = {
            Time = {
                Date = true,
                DateString = "%A, %B %d, %Y",
                AlternateTime = true,
                Lockouts = true,
            },
            SystemStats = {
                Vault = {
                    Enable = true,
                    Options = {
                        Raid = true,
                        MythicPlus = true,
                        World = true,
                    }
                }
            }
        }
    },
}

MS.Defaults = Defaults

local function EnsureNamespaceGlobal(dbObject, defaults)
    if not dbObject then return nil end

    local globalDefaults = defaults and defaults.global
    local sv = dbObject.sv
    if sv and not sv.global then
        sv.global = globalDefaults and CopyTable(globalDefaults) or {}
    end

    local globalDB = dbObject.global
    if not globalDB and sv then
        globalDB = sv.global or {}
        if globalDefaults then
            for key, value in pairs(globalDefaults) do
                if globalDB[key] == nil then
                    globalDB[key] = CopyTable(value)
                end
            end
        end
        rawset(dbObject, "global", globalDB)
    elseif globalDB and globalDefaults then
        for key, value in pairs(globalDefaults) do
            if globalDB[key] == nil then
                globalDB[key] = CopyTable(value)
            end
        end
    end

    return globalDB
end

function MinimapStats:OnInitialize()
    -- [KullThranUI] Use KT's DB with a namespace
    MS.db = KT.db:RegisterNamespace("MinimapStats", Defaults)
    EnsureNamespaceGlobal(MS.db, Defaults)
    self.MS = MS
end

function MinimapStats:OnEnable()
    local globalDB = EnsureNamespaceGlobal(MS.db, Defaults)
    if not globalDB or not globalDB.General or not globalDB.General.Enable then return end

    -- heistm: https://github.com/DaleHuntGB/MinimapStats/pull/3 - for the idea
    C_Timer.After(0.1, function()
        MS:SetupSlashCommands()
        if not MS:ShouldEnableRuntime() then
            MS:DisableRuntime("KullThranUI_Minimap")
            return
        end
        MS.runtimeDisabled = false
        MS:HookDetachedMinimapRefresh()
        MS:CreateTime()
        MS:CreateSystemStats()
        MS:CreateLocation()
        MS:CreateCoordinates()
        MS:CreateInstanceDifficulty()
        MS:AssignTooltipScripts()
    end)
end
