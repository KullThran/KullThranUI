local _, MS = ...
local C_AddOns = _G.C_AddOns
local IsAddOnLoaded = _G.IsAddOnLoaded
local MINIMAP_ADDON_NAME = "KullThranUI_Minimap"

-- [KullThranUI Integration]
-- MS is now the shared namespace 'ns' of KullThranUI. 
-- We isolate MinimapStats functions to avoid collisions if necessary, but for now we attach to MS/ns.

MSG = MSG or {} -- Global for GUI access if needed
MS.AddOnName = "MinimapStats" -- Hardcoded as it's now a module
MS.Version = "5.1.0"
MS.Author = "UnhaltedGB"
MS.LSM = LibStub("LibSharedMedia-3.0")
local _, class = UnitClass("player")
local color = class and RAID_CLASS_COLORS[class]
if not color then color = { r = 1, g = 1, b = 1 } end -- Fallback to white
MS.CLASS_COLOUR = {color.r * 255, color.g * 255, color.b * 255}

local KT = _G.KT
MS.ResolveFont = function(name)
    if KT and KT.ResolveFontPath then
        return KT:ResolveFontPath(name) or MS.LSM:Fetch("font", name)
    end
    return MS.LSM:Fetch("font", name) or name
end

MS.InfoButton = "|A:glueannouncementpopup-icon-info:16:16|a "
MS.LEFT_CLICK_BUTTON = "|A:newplayertutorial-icon-mouse-leftbutton:20.7:15.6|a"
MS.RIGHT_CLICK_BUTTON = "|A:newplayertutorial-icon-mouse-rightbutton:20.7:15.6|a"
MS.MIDDLE_CLICK_BUTTON = "|A:newplayertutorial-icon-mouse-middlebutton:20.7:15.6|a"
MS.TestInstanceDifficulty = false

local OptionsToDB = {
    ["General"] = "General",
    ["Time"] = "Time",
    ["System Stats"] = "SystemStats",
    ["Location"] = "Location",
    ["Instance Difficulty"] = "InstanceDifficulty",
    ["Coordinates"] = "Coordinates",
    ["Tooltip"] = "Tooltip",
}

local function GetFrameRectInUIParent(frame)
    if not (frame and frame.GetLeft and frame.GetRight and frame.GetTop and frame.GetBottom) then
        return nil
    end

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local top = frame:GetTop()
    local bottom = frame:GetBottom()
    if not (left and right and top and bottom) then
        return nil
    end

    local uiParent = _G.UIParent
    local uiScale = uiParent and uiParent.GetEffectiveScale and uiParent:GetEffectiveScale() or 1
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local scaleRatio = frameScale / uiScale

    return left * scaleRatio, right * scaleRatio, top * scaleRatio, bottom * scaleRatio
end

local function GetRectPoint(point, left, right, top, bottom)
    local centerX = (left + right) * 0.5
    local centerY = (top + bottom) * 0.5

    if point == "TOPLEFT" then
        return left, top
    elseif point == "TOP" then
        return centerX, top
    elseif point == "TOPRIGHT" then
        return right, top
    elseif point == "LEFT" then
        return left, centerY
    elseif point == "RIGHT" then
        return right, centerY
    elseif point == "BOTTOMLEFT" then
        return left, bottom
    elseif point == "BOTTOM" then
        return centerX, bottom
    elseif point == "BOTTOMRIGHT" then
        return right, bottom
    end

    return centerX, centerY
end

function MS:Print(MSG)
    print(MS.AddOnName .. ":|r " .. MSG)
end

function MS:SetJustification(anchorFrom)
    if anchorFrom == "TOPLEFT" or anchorFrom == "LEFT" or anchorFrom == "BOTTOMLEFT" then
        return "LEFT"
    elseif anchorFrom == "TOPRIGHT" or anchorFrom == "RIGHT" or anchorFrom == "BOTTOMRIGHT" then
        return "RIGHT"
    else
        return "CENTER"
    end
end

function MS:GetMinimapReferenceFrame()
    return _G.Minimap or _G.MinimapCluster or _G.KT_MinimapHolder_Main
end

function MS:IsExternalMinimapAddonLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(MINIMAP_ADDON_NAME)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(MINIMAP_ADDON_NAME)
    end
    return false
end

function MS:ShouldEnableRuntime()
    return not self:IsExternalMinimapAddonLoaded()
end

function MS:DisableRuntime(reason)
    self.runtimeDisabled = true
    self.runtimeDisabledReason = reason or MINIMAP_ADDON_NAME

    local runtimeFrames = {
        _G.MinimapStats_TimeFrame,
        _G.MinimapStats_SystemStatsFrame,
        _G.MinimapStats_LocationFrame,
        _G.MinimapStats_CoordinatesFrame,
        _G.MinimapStats_InstanceDifficultyFrame,
    }

    for _, frame in ipairs(runtimeFrames) do
        if frame then
            if frame.UnregisterAllEvents then
                frame:UnregisterAllEvents()
            end
            if frame.SetScript then
                frame:SetScript("OnUpdate", nil)
                frame:SetScript("OnEvent", nil)
                frame:SetScript("OnMouseDown", nil)
                frame:SetScript("OnEnter", nil)
                frame:SetScript("OnLeave", nil)
            end
            frame:Hide()
        end
    end

    self:HideTooltipFrame()
end

function MS:GetTooltipFrame(key)
    self._tooltipFrames = self._tooltipFrames or {}

    local tooltipKey = key or "Default"
    if self._tooltipFrames[tooltipKey] then
        return self._tooltipFrames[tooltipKey]
    end

    local tooltipName = "KullThranUI_MinimapStatsTooltip_" .. tooltipKey
    local tooltip = CreateFrame("GameTooltip", tooltipName, _G.UIParent, "GameTooltipTemplate")
    tooltip:SetClampedToScreen(true)
    tooltip:SetFrameStrata("TOOLTIP")

    self._tooltipFrames[tooltipKey] = tooltip
    return tooltip
end

function MS:HideTooltipFrame(key)
    if not self._tooltipFrames then
        return
    end

    if key ~= nil then
        local tooltip = self._tooltipFrames[key]
        if tooltip and tooltip.Hide then
            tooltip:Hide()
        end
        return
    end

    for _, tooltip in pairs(self._tooltipFrames) do
        if tooltip and tooltip.Hide then
            tooltip:Hide()
        end
    end
end

function MS:ApplyDetachedMinimapLayout(frame, layout)
    if not (frame and layout and frame.ClearAllPoints and frame.SetPoint) then
        return
    end

    local anchorPoint = layout[1] or "CENTER"
    local relativePoint = layout[2] or anchorPoint
    local xOffset = layout[3] or 0
    local yOffset = layout[4] or 0
    local minimapFrame = self:GetMinimapReferenceFrame()
    local left, right, top, bottom = GetFrameRectInUIParent(minimapFrame)

    frame:ClearAllPoints()
    if not left then
        frame:SetPoint(anchorPoint, _G.UIParent, relativePoint, xOffset, yOffset)
        return
    end

    local anchorX, anchorY = GetRectPoint(relativePoint, left, right, top, bottom)
    frame:SetPoint(anchorPoint, _G.UIParent, "BOTTOMLEFT", anchorX + xOffset, anchorY + yOffset)
end

function MS:HookDetachedMinimapRefresh()
    local uiParent = _G.UIParent
    if self._detachedMinimapRefreshHooked or not (uiParent and uiParent.HookScript) then
        return
    end

    self._detachedMinimapRefreshHooked = true
    uiParent:HookScript("OnShow", function()
        if MS.runtimeDisabled then
            return
        end
        local timer = _G.C_Timer
        if timer and timer.After then
            timer.After(0, function()
                if MS and MS.UpdateAll and not MS.runtimeDisabled then
                    MS:UpdateAll()
                end
            end)
            timer.After(0.1, function()
                if MS and MS.UpdateAll and not MS.runtimeDisabled then
                    MS:UpdateAll()
                end
            end)
        elseif MS and MS.UpdateAll and not MS.runtimeDisabled then
            MS:UpdateAll()
        end
    end)
end

function MS:SetupSlashCommands()
    SLASH_MINIMAPSTATS1 = "/ms"
    SLASH_MINIMAPSTATS2 = "/minimapstats"
    SlashCmdList["MINIMAPSTATS"] = function(msg)
        if msg == "" or msg == "gui" or msg == "options" then
            MS:CreateGUI()
        elseif msg == "time" then
            MS:CreateGUI("Time")
        elseif msg == "system" or msg == "systemstats" or msg == "s" then
            MS:CreateGUI("SystemStats")
        elseif msg == "location" or msg == "loc" or msg == "l" then
            MS:CreateGUI("Location")
        elseif msg == "instance" or msg == "instancedifficulty" or msg == "i"  or msg == "id" then
            MS:CreateGUI("InstanceDifficulty")
        elseif msg == "coordinates" or msg == "coord" or msg == "c" then
            MS:CreateGUI("Coordinates")
        elseif msg == "reset" then
            MS:Reset("All")
        elseif msg == "share" then
            MS:CreateGUI("Share")
        end
    end
    MS:Print("'|cFF8080FF/ms|r' for in-game configuration.")
end

function MS:Reset(valueToReset)
    local dbValue = OptionsToDB[valueToReset]
    if valueToReset == "All" then
        for key, _ in pairs(MS.db.global) do MS.db.global[key] = CopyTable(MS.Defaults.global[key]) end
    elseif MS.db.global[dbValue] then
        MS.db.global[dbValue] = CopyTable(MS.Defaults.global[dbValue])
    end
    MS:Print("Reset " .. (valueToReset == "All" and "All Settings." or valueToReset .. " Settings."))
    MS:UpdateAll()
    if MS.GUIContainer then MS:RedrawGUI() end
end

function MS:FetchReactionColour()
    local ReactionColour
    local PVPZone = C_PvP.GetZonePVPInfo()
    if PVPZone == 'arena' then
        ReactionColour = {0.84 * 255, 0.03 * 255, 0.03 * 255}
    elseif PVPZone == 'friendly' then
        ReactionColour = {0.05 * 255, 0.85 * 255, 0.03 * 255}
    elseif PVPZone == 'contested' then
        ReactionColour = {0.9 * 255, 0.85 * 255, 0.05 * 255}
    elseif PVPZone == 'hostile' then
        ReactionColour = {0.84 * 255, 0.03 * 255, 0.03 * 255}
    elseif PVPZone == 'sanctuary' then
        ReactionColour = {0.035 * 255, 0.58 * 255, 0.84 * 255}
    elseif PVPZone == 'combat' then
        ReactionColour = {0.84 * 255, 0.03 * 255, 0.03 * 255}
    else
        ReactionColour = {0.9 * 255, 0.85 * 255, 0.05 * 255}
    end
    return ReactionColour
end

function MS:UpdateAll()
    MS:UpdateTime()
    MS:UpdateSystemStats()
    MS:UpdateLocation()
    MS:UpdateInstanceDifficulty()
    MS:UpdateCoordinates()
end

function MS:ReloadPrompt(text, onAcceptText, onCancelText, onAcceptFn, onCancelFn)
    StaticPopupDialogs["MINIMAPSTATS_RELOAD"] = {
        text = text or "Reload Required to Apply Changes. Reload Now?",
        button1 = onAcceptText or "Yes, reload now!",
        button2 = onCancelText or "No, I will do it later.",
        OnAccept = onAcceptFn or function() ReloadUI() end,
        OnCancel = onCancelFn or function() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("MINIMAPSTATS_RELOAD")
end
