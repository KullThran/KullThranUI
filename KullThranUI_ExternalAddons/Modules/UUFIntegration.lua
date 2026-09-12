local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("UUFIntegration", "AceEvent-3.0")

local _G = _G
local C_AddOns = _G.C_AddOns
local InCombatLockdown = _G.InCombatLockdown
local pairs = pairs
local ipairs = ipairs

local function IsBlizzardEditModeActive()
    if KT and KT.IsBlizzardEditModeTransitionActive then
        return KT:IsBlizzardEditModeTransitionActive()
    end
    return false
end

function Mod:OnInitialize()
    if not KT.db.profile.uufIntegration then
        KT.db.profile.uufIntegration = { enable = true }
    end
    self.db = KT.db.profile.uufIntegration

    KT:RegisterChatCommand("ktuuf", function(msg)
        if msg == "reset" then
            self:ResetPositions()
        end
    end)
end

function Mod:OnEnable()
    local externalGroup = KT.db and KT.db.profile and KT.db.profile.externalAddons
    if externalGroup and externalGroup.enable == false then return end
    if not self.db.enable then return end

    if C_AddOns.IsAddOnLoaded("UnhaltedUnitFrames") then
        self:SetupUUF()
    else
        self:RegisterEvent("ADDON_LOADED")
    end
end

function Mod:ADDON_LOADED(_, addonName)
    if addonName == "UnhaltedUnitFrames" then
        self:SetupUUF()
        self:UnregisterEvent("ADDON_LOADED")
    end
end

function Mod:SetupUUF()
    if IsLoggedIn() then
        self:RegisterFrames()
    else
        self:RegisterEvent("PLAYER_LOGIN", "RegisterFrames")
    end
end

function Mod:RegisterFrames()
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "RegisterFrames")
        return
    end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("PLAYER_LOGIN")

    if not KT.RegisterUnlockElement then return end

    KT.db.profile.editMode = KT.db.profile.editMode or {}
    KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}

    local frames = {
        { name = "UUF_Player", label = "UUF Player", order = 10 },
        { name = "UUF_Target", label = "UUF Target", order = 20 },
        { name = "UUF_TargetTarget", label = "UUF ToT", order = 30 },
        { name = "UUF_Focus", label = "UUF Focus", order = 40 },
        { name = "UUF_Pet", label = "UUF Pet", order = 50 },
        { name = "UUF_Party", label = "UUF Party", order = 60, header = true },
        { name = "UUF_Boss", label = "UUF Boss", order = 70, header = true },
        { name = "UUF_Arena", label = "UUF Arena", order = 80, header = true },
    }

    for i = 1, 5 do
        frames[#frames + 1] = { name = "UUF_Boss" .. i, label = "UUF Boss " .. i, order = 90 + i }
        frames[#frames + 1] = { name = "UUF_Arena" .. i, label = "UUF Arena " .. i, order = 100 + i }
    end

    for _, info in ipairs(frames) do
        local frame = _G[info.name]
        if frame then
            local unlockKey = "uuf_" .. info.name:lower()

            KT.RegisterUnlockElement(unlockKey, {
                label = info.label,
                group = "Unhalted Unit Frames",
                order = info.order or 999,
                getFrame = function()
                    return frame
                end,
                getSize = function()
                    return frame:GetWidth(), frame:GetHeight()
                end,
                getScale = function()
                    return frame:GetScale()
                end,
                isHidden = function()
                    if not frame then return true end
                    if info.header then
                        return false
                    end
                    if frame.IsShown then
                        return not frame:IsShown()
                    end
                    return false
                end,
                loadPosition = function()
                    local saved = KT.db.profile.editMode.frames[unlockKey]
                    if saved and saved.point then
                        return saved
                    end
                    local point, _, relativePoint, x, y = frame:GetPoint()
                    if point then
                        return {
                            point = point,
                            relativePoint = relativePoint or point,
                            x = x or 0,
                            y = y or 0,
                            scale = frame:GetScale() or 1,
                        }
                    end
                    return nil
                end,
                savePosition = function(_, point, relativePoint, x, y, scale)
                    KT.db.profile.editMode.frames[unlockKey] = {
                        point = point,
                        relativePoint = relativePoint,
                        x = x,
                        y = y,
                        scale = scale or frame:GetScale() or 1,
                    }
                end,
                applyPosition = function()
                    if InCombatLockdown() or IsBlizzardEditModeActive() then return end
                    local saved = KT.db.profile.editMode.frames[unlockKey]
                    if not (saved and saved.point) then return end

                    frame:ClearAllPoints()
                    frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
                    frame:SetMovable(true)
                    frame:SetClampedToScreen(true)
                end,
            })
        end
    end
end

function Mod:ResetPositions()
    local frames = KT.db and KT.db.profile and KT.db.profile.editMode and KT.db.profile.editMode.frames
    if not frames then return end

    for key in pairs(frames) do
        if key:find("^uuf_") then
            frames[key] = nil
        end
    end
    self:RegisterFrames()
    print("|cFF00FFFF[KullThranUI]|r UUF positions reset.")
end
