local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local EM = KT:NewModule("EditMode", "AceEvent-3.0", "AceHook-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

-- Cache WoW Globals
local _G = _G
local CreateFrame = CreateFrame
local EditModeManagerFrame = EditModeManagerFrame
local PlaySound = PlaySound
local SOUNDKIT = SOUNDKIT
local ipairs = ipairs
local pairs = pairs
local C_Timer = C_Timer
local type = type
local string = string
local wipe = wipe
local tostring = tostring

local function GetQueueStatusFrame()
    return _G.QueueStatusButton or _G.QueueStatusMinimapButton
end

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

local BACKDROP_BLIZZARD = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
}

EM.RegisteredFrames = {}
EM.RegisteredOverlays = {}
EM.BlizzardOverlayVisuals = {}
EM.BlizzardFrameVisuals = {}
EM.StyledOverlays = {}

local EDITMODE_R = KT.C_R or 0.85
local EDITMODE_G = KT.C_G or 0.15
local EDITMODE_B = KT.C_B or 0.15
local MOUSEOVER_SETTING_KEYS = {
    bar1 = { section = "actionbars", key = "fadeBar1" },
    bar2 = { section = "actionbars", key = "fadeBar2" },
    bar3 = { section = "actionbars", key = "fadeBar3" },
    bar4 = { section = "actionbars", key = "fadeBar4" },
    bar5 = { section = "actionbars", key = "fadeBar5" },
    bar6 = { section = "actionbars", key = "fadeBar6" },
    bar7 = { section = "actionbars", key = "fadeBar7" },
    bar8 = { section = "actionbars", key = "fadeBar8" },
    pet = { section = "actionbars", key = "fadePet" },
    stance = { section = "actionbars", key = "fadeStance" },
    bags = { section = "blizzframes", key = "fadeBags" },
    micro = { section = "blizzframes", key = "fadeMicroMenu" },
    tracker = { section = "blizzframes", key = "fadeObjectiveTracker" },
    status = { section = "blizzframes", key = "fadeStatusBar" },
    queue = { section = "blizzframes", key = "fadeQueueStatus" },
}

local function GetEditModeAccentColor()
    return KT.C_R or EDITMODE_R, KT.C_G or EDITMODE_G, KT.C_B or EDITMODE_B
end

local function EnsureHoverTooltip()
    if EM.HoverTooltip then
        return EM.HoverTooltip
    end

    local tooltip = CreateFrame("Frame", "KT_EditModeHoverTooltip", _G.UIParent, "BackdropTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetToplevel(true)
    tooltip:SetClampedToScreen(true)
    tooltip:SetSize(220, 48)
    tooltip:Hide()

    KT:AddBackdrop(tooltip, 0.04, 0.04, 0.06, 0.96)
    KT:AddBorder(tooltip, EDITMODE_R, EDITMODE_G, EDITMODE_B, 0.95)

    tooltip.Title = tooltip:CreateFontString(nil, "OVERLAY")
    tooltip.Title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    tooltip.Title:SetPoint("TOPLEFT", 10, -8)
    tooltip.Title:SetPoint("TOPRIGHT", -10, -8)
    tooltip.Title:SetJustifyH("LEFT")
    tooltip.Title:SetJustifyV("TOP")
    tooltip.Title:SetTextColor(1, 0.82, 0, 1)
    tooltip.Title:SetWordWrap(true)

    tooltip.Desc = tooltip:CreateFontString(nil, "OVERLAY")
    tooltip.Desc:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "")
    tooltip.Desc:SetPoint("TOPLEFT", tooltip.Title, "BOTTOMLEFT", 0, -4)
    tooltip.Desc:SetPoint("TOPRIGHT", tooltip.Title, "BOTTOMRIGHT", 0, -4)
    tooltip.Desc:SetJustifyH("LEFT")
    tooltip.Desc:SetJustifyV("TOP")
    tooltip.Desc:SetTextColor(1, 1, 1, 1)
    tooltip.Desc:SetWordWrap(true)

    EM.HoverTooltip = tooltip
    return tooltip
end

local function ShowHoverTooltip(owner, title, description)
    if not owner then
        return
    end

    local tooltip = EnsureHoverTooltip()
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 10)
    tooltip:SetWidth(220)
    tooltip.Title:SetText(title or "")
    tooltip.Desc:SetText(description or "")

    local height = 20 + tooltip.Title:GetStringHeight() + tooltip.Desc:GetStringHeight()
    tooltip:SetHeight(height > 48 and height or 48)
    tooltip:Show()
end

local function HideHoverTooltip()
    if EM.HoverTooltip then
        EM.HoverTooltip:Hide()
    end
end

local function GetMouseoverSetting(targetID)
    local info = MOUSEOVER_SETTING_KEYS[targetID]
    if not (info and KT.db and KT.db.profile) then
        return false
    end

    local section = KT.db.profile[info.section]
    if type(section) ~= "table" then
        return false
    end

    return section[info.key] == true
end

local function SetMouseoverSetting(targetID, value)
    local info = MOUSEOVER_SETTING_KEYS[targetID]
    if not (info and KT.db and KT.db.profile) then
        return
    end

    KT.db.profile[info.section] = KT.db.profile[info.section] or {}
    KT.db.profile[info.section][info.key] = value == true
end

-- Helper para llamadas seguras (Debug Intenso)
local function SafeCall(func, ...)
    local success, err = pcall(func, ...)
    if not success and KT.db and KT.db.profile.debugMode then
        print("|cFFFF0000[KT EditMode Error]|r", err)
    end
    return success
end

local function GetOverlayRegions(overlay)
    local ok, regions = pcall(function()
        return { overlay:GetRegions() }
    end)
    if ok and regions then
        return regions
    end
    return {}
end

local RestoreBlizzardFrameSelection
local HideBlizzardFrameSelection

local function ForEachOverlayRegionRecursive(root, callback)
    if not (root and callback) then
        return
    end

    local visitedFrames = {}
    local visitedRegions = {}

    local function Walk(frame)
        if not frame or visitedFrames[frame] then
            return
        end
        visitedFrames[frame] = true

        for _, region in ipairs(GetOverlayRegions(frame)) do
            if region and not visitedRegions[region] then
                visitedRegions[region] = true
                callback(region, frame)
            end
        end

        local ok, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if ok and children then
            for i = 1, #children do
                Walk(children[i])
            end
        end
    end

    Walk(root)
end

local function FindBlizzardFrameVisual(key)
    for i = 1, #EM.BlizzardFrameVisuals do
        local record = EM.BlizzardFrameVisuals[i]
        if record.key == key then
            return record
        end
    end
end

local function SafeGetFrameName(frame)
    if not frame or not frame.GetName then
        return nil
    end

    local ok, name = pcall(frame.GetName, frame)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end
end

local function SafeGetField(frame, field)
    if not frame then
        return nil
    end

    local ok, value = pcall(function()
        return frame[field]
    end)
    if ok then
        return value
    end
end

local function FrameNameMatches(name, candidates)
    if not name or not candidates then
        return false
    end

    for i = 1, #candidates do
        if candidates[i] == name then
            return true
        end
    end
    return false
end

local function StringMatchesAny(value, candidates)
    if type(value) ~= "string" or not candidates then
        return false
    end

    for i = 1, #candidates do
        if candidates[i] == value then
            return true
        end
    end
    return false
end

local function FindRegisteredSystemFrame(info)
    local registered = EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames
    if not registered or not info then
        return nil
    end

    local bestFrame, bestSelection, bestScore
    for _, systemFrame in pairs(registered) do
        if systemFrame then
            local frameName = SafeGetFrameName(systemFrame)
            local selectedFrame = SafeGetField(systemFrame, "selectedFrame")
            local selectedFrameName = SafeGetFrameName(selectedFrame)
            local selection = SafeGetField(systemFrame, "Selection")
            local systemNameString = SafeGetField(systemFrame, "systemNameString")
            local systemInfo = SafeGetField(systemFrame, "systemInfo")
            local systemInfoName = type(systemInfo) == "table" and systemInfo.name or nil
            local score

            if systemNameString == info.label or systemInfoName == info.label then
                score = 5
            elseif StringMatchesAny(systemNameString, info.systemLabels) or StringMatchesAny(systemInfoName, info.systemLabels) then
                score = 4
            elseif FrameNameMatches(selectedFrameName, info.systemNames) then
                score = 3
            elseif FrameNameMatches(frameName, info.systemNames) then
                score = 2
            elseif StringMatchesAny(frameName, info.systemLabels) or StringMatchesAny(selectedFrameName, info.systemLabels) then
                score = 1
            end

            if score and (not bestScore or score > bestScore) then
                bestScore = score
                bestFrame = systemFrame
                bestSelection = selection
            end
        end
    end

    return bestFrame, bestSelection
end

local function GetBlizzardVisualTargets()
    local minimap = _G.Minimap
    local extraAbilities = _G.ExtraActionBarFrame
        or _G.ExtraAbilityContainer
        or (_G.ExtraActionButton1 and _G.ExtraActionButton1:GetParent())
    local objectiveTracker = (_G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.BlocksFrame) or _G.ObjectiveTrackerFrame
    local vehicleLeave = _G.MainMenuBarVehicleLeaveButton
    local debuffFrame = (_G.DebuffFrame and _G.DebuffFrame.AuraContainer) or _G.DebuffFrame
    local arenaFrame = _G.ArenaFrame or _G.ArenaEnemyFramesContainer
    local possessBar = _G.PossessBarFrame or _G.PossessActionBar or _G.OverrideActionBar
    local statusBar1 = _G.MainStatusTrackingBarContainer or _G.StatusTrackingBarManager
    local statusBar2 = _G.SecondaryStatusTrackingBarContainer
    local talkingHead = _G.TalkingHeadFrame
    local bossAbilities = _G.EncounterTimeline or _G.EncounterBar
    local encounterBar = _G.EncounterBar
    local bossWarningCritical = _G.CriticalEncounterWarnings
    local bossWarningMedium = _G.MediumEncounterWarnings
    local durabilityFrame = _G.DurabilityFrame

    return {
        { key = "action_bar_1", label = "Action Bar 1", frames = { _G.MainActionBar or _G.MainMenuBar }, systemNames = { "MainActionBar", "MainMenuBar" } },
        { key = "action_bar_2", label = "Action Bar 2", frames = { _G.MultiBarBottomLeft }, systemNames = { "MultiBarBottomLeft" } },
        { key = "action_bar_3", label = "Action Bar 3", frames = { _G.MultiBarBottomRight }, systemNames = { "MultiBarBottomRight" } },
        { key = "action_bar_4", label = "Action Bar 4", frames = { _G.MultiBarRight }, systemNames = { "MultiBarRight" } },
        { key = "action_bar_5", label = "Action Bar 5", frames = { _G.MultiBarLeft }, systemNames = { "MultiBarLeft" } },
        { key = "action_bar_6", label = "Action Bar 6", frames = { _G.MultiBar5 }, systemNames = { "MultiBar5" } },
        { key = "action_bar_7", label = "Action Bar 7", frames = { _G.MultiBar6 }, systemNames = { "MultiBar6" } },
        { key = "action_bar_8", label = "Action Bar 8", frames = { _G.MultiBar7 }, systemNames = { "MultiBar7" } },
        { key = "pet_bar", label = "Pet Bar", frames = { _G.PetActionBar }, systemNames = { "PetActionBar" }, systemLabels = { "Pet Bar" } },
        { key = "stance_bar_1", label = "Stance Bar 1", frames = { _G.StanceBar }, systemNames = { "StanceBar" }, systemLabels = { "Stance Bar 1", "Stance Bar", "Shapeshift Bar" } },
        { key = "stance_bar_2", label = "Stance Bar 2", frames = { possessBar }, systemNames = { "PossessBarFrame", "PossessActionBar", "OverrideActionBar" }, systemLabels = { "Stance Bar 2", "Possess Bar", "Override Bar" } },
        { key = "buff_frame", label = "Buff Frame", frames = { _G.BuffFrame }, systemNames = { "BuffFrame" }, systemLabels = { "Buff Frame" } },
        { key = "debuff_frame", label = "Debuff Frame", frames = { debuffFrame, _G.DebuffFrame }, systemNames = { "DebuffFrame" }, systemLabels = { "Debuff Frame" } },
        { key = "extra_abilities", label = "Extra Abilities", frames = { extraAbilities, _G.ExtraActionBarFrame, _G.ExtraAbilityContainer, _G.ExtraActionButton1 }, systemNames = { "ExtraActionBarFrame", "ExtraAbilityContainer", "ExtraActionButton1" }, systemLabels = { "Extra Abilities", "Extra Ability" } },
        { key = "boss_abilities", label = "Boss Abilities", frames = { bossAbilities, _G.EncounterTimeline, _G.EncounterBar }, systemNames = { "EncounterTimeline", "EncounterBar" }, systemLabels = { "Boss Abilities", "Encounter Bar", "Boss Ability" } },
        { key = "encounter_bar", label = "Encounter Bar", frames = { encounterBar }, systemNames = { "EncounterBar" }, systemLabels = { "Encounter Bar" } },
        { key = "boss_warning_critical", label = "Boss Warning: Critical", frames = { bossWarningCritical }, systemNames = { "CriticalEncounterWarnings" }, systemLabels = { "Boss Warning: Critical", "Critical Encounter Warnings" } },
        { key = "boss_warning_medium", label = "Boss Warning: Medium", frames = { bossWarningMedium }, systemNames = { "MediumEncounterWarnings" }, systemLabels = { "Boss Warning: Medium", "Medium Encounter Warnings" } },
        { key = "objective_tracker", label = "Objective Tracker", frames = { objectiveTracker, _G.ObjectiveTrackerFrame }, systemNames = { "ObjectiveTrackerFrame" }, systemLabels = { "Objective Tracker" } },
        { key = "status_bar_1", label = "Status Bar 1", frames = { statusBar1, _G.StatusTrackingBarManager }, systemNames = { "MainStatusTrackingBarContainer", "StatusTrackingBarManager" }, systemLabels = { "Status Bar 1", "Status Bars" }, hideWhenExperienceBar = true },
        { key = "status_bar_2", label = "Status Bar 2", frames = { statusBar2 }, systemNames = { "SecondaryStatusTrackingBarContainer" }, systemLabels = { "Status Bar 2" }, hideWhenExperienceBar = true },
        { key = "micro_menu", label = "Micro Menu", frames = { _G.MicroMenuContainer or _G.MicroMenu }, systemNames = { "MicroMenuContainer", "MicroMenu" }, systemLabels = { "Micro Menu" } },
        { key = "bags", label = "Bags Bar", frames = { _G.MicroButtonAndBagsBar or (_G.BagsBar and _G.BagsBar:GetParent()), _G.BagsBar }, systemNames = { "MicroButtonAndBagsBar", "BagsBar" }, systemLabels = { "Bags Bar", "Backpack Button", "Backpack" } },
        { key = "queue_status", label = "LFG Eye", frames = { GetQueueStatusFrame() }, systemNames = { "QueueStatusButton", "QueueStatusMinimapButton" }, systemLabels = { "LFG Eye", "Queue Status" } },
        { key = "vehicle_exit", label = "Vehicle Exit Button", frames = { vehicleLeave, vehicleLeave and vehicleLeave:GetParent() }, systemNames = { "MainMenuBarVehicleLeaveButton" }, systemLabels = { "Vehicle Exit Button", "Vehicle Exit" } },
        { key = "durability", label = "Equipment Durability", frames = { durabilityFrame }, systemNames = { "DurabilityFrame" }, systemLabels = { "Equipment Durability", "Durability" } },
        { key = "talking_head", label = "Talking Head", frames = { talkingHead }, systemNames = { "TalkingHeadFrame" }, systemLabels = { "Talking Head" } },
        { key = "minimap", label = "Minimap", frames = { minimap }, systemNames = { "Minimap" }, systemLabels = { "Minimap" } },
        { key = "zone_button", label = "Zone Button", frames = { _G.KT_ZoneAbilityProxy, _G.ZoneAbilityFrame }, systemNames = { "KT_ZoneAbilityProxy", "ZoneAbilityFrame" }, systemLabels = { "Zone Button", "Zone Ability" } },
        -- Leave Blizzard's GameTooltip completely untouched. Touching it from
        -- EditMode can taint widget/tooltips paths in combat and world content.
    }
end

local function ResolveBlizzardVisualTarget(info)
    if not info or not info.frames then
        return nil, nil
    end

    if info.key == "minimap" and _G.Minimap then
        local systemFrame, selection = FindRegisteredSystemFrame(info)
        if systemFrame then
            return _G.Minimap, selection
        end
        return _G.Minimap, nil
    end

    local systemFrame, selection = FindRegisteredSystemFrame(info)
    if systemFrame then
        return systemFrame, selection
    end

    local fallback
    for i = 1, #info.frames do
        local frame = info.frames[i]
        if frame then
            local selection = frame.Selection
            if selection and selection.IsShown and selection:IsShown() then
                return frame, selection
            end
            if not fallback and frame.IsShown and frame:IsShown() then
                fallback = frame
            end
        end
    end

    if fallback then
        local selection = fallback.Selection
        if selection and selection.IsShown and selection:IsShown() then
            return fallback, selection
        end
        return fallback, nil
    end
end

local function CreateBlizzardFrameVisual(key, anchor, labelText)
    local visual = CreateFrame("Frame", nil, _G.UIParent)
    visual:EnableMouse(false)
    visual:SetFrameStrata("FULLSCREEN_DIALOG")
    visual:SetToplevel(true)

    local colorR, colorG, colorB = GetEditModeAccentColor()

    local bg = visual:CreateTexture(nil, "ARTWORK", nil, 0)
    bg:SetAllPoints()
    bg:SetColorTexture(0.02, 0.02, 0.02, 0.42)
    visual.Bg = bg

    local tint = visual:CreateTexture(nil, "OVERLAY", nil, 0)
    tint:SetAllPoints()
    tint:SetColorTexture(colorR, colorG, colorB, 0.34)
    visual.Tint = tint

    local label = visual:CreateFontString(nil, "OVERLAY")
    label:SetFont(KT.FONT_PATH, 12, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetTextColor(1, 1, 1, 1)
    label:SetText(labelText or "")
    visual.Label = label

    local border = CreateFrame("Frame", nil, visual)
    border:SetAllPoints()
    border:SetFrameStrata("DIALOG")
    KT:AddBorder(border, colorR, colorG, colorB, 1)
    visual.Border = border
    visual:Hide()

    local record = {
        key = key,
        target = nil,
        anchor = anchor,
        nativeSelection = nil,
        nativeSelectionAlpha = nil,
        hiddenRegions = {},
        nativeHidden = false,
        targetHidden = false,
        visual = visual,
    }
    EM.BlizzardFrameVisuals[#EM.BlizzardFrameVisuals + 1] = record
    return record
end

local function UpdateBlizzardFrameVisualColors(record)
    if not (record and record.visual) then
        return
    end

    local colorR, colorG, colorB = GetEditModeAccentColor()
    local visual = record.visual

    if visual.Tint then
        visual.Tint:SetColorTexture(colorR, colorG, colorB, 0.34)
    end

    if visual.Border then
        KT:AddBorder(visual.Border, colorR, colorG, colorB, 1)
    end
end

local function RememberBlizzardSelectionRegionState(record, region)
    if not (record and region) then
        return nil
    end

    for i = 1, #record.hiddenRegions do
        local entry = record.hiddenRegions[i]
        if entry and entry.region == region then
            return entry
        end
    end

    local entry = {
        region = region,
        alpha = region.GetAlpha and region:GetAlpha() or nil,
    }

    if region.GetVertexColor then
        local ok, r, g, b, a = pcall(region.GetVertexColor, region)
        if ok then
            entry.r = r
            entry.g = g
            entry.b = b
            entry.a = a
        end
    end

    record.hiddenRegions[#record.hiddenRegions + 1] = entry
    return entry
end

local function TintBlizzardFrameSelection(record)
    local selection = record and record.nativeSelection
    if not selection then
        return
    end

    local colorR, colorG, colorB = GetEditModeAccentColor()
    if selection.SetBackdropColor then
        pcall(selection.SetBackdropColor, selection, colorR, colorG, colorB, 0.10)
    end
    if selection.SetBackdropBorderColor then
        pcall(selection.SetBackdropBorderColor, selection, colorR, colorG, colorB, 0.95)
    end
    if selection.Label and selection.Label.SetTextColor then
        selection.Label:SetTextColor(1, 1, 1, 1)
    end
end

local function EnsureNativeSelectionHooks(record)
    local selection = record and record.nativeSelection
    if not selection or selection._ktBlizzardSelectionHooked then
        return
    end

    selection._ktBlizzardSelectionHooked = true

    local function Reapply()
        local activeRecord = selection._ktBlizzardSelectionRecord
        if not (EM and activeRecord and EditModeManagerFrame and EditModeManagerFrame:IsShown()) then
            return
        end

        if activeRecord.nativeHidden then
            activeRecord.nativeHidden = false
        end
        if activeRecord.keepNativeSelection then
            RestoreBlizzardFrameSelection(activeRecord)
            TintBlizzardFrameSelection(activeRecord)
        else
            HideBlizzardFrameSelection(activeRecord)
        end
        UpdateBlizzardFrameVisualColors(activeRecord)
    end

    if selection.ShowHighlighted then
        hooksecurefunc(selection, "ShowHighlighted", Reapply)
    end
    if selection.ShowSelected then
        hooksecurefunc(selection, "ShowSelected", Reapply)
    end
    hooksecurefunc(selection, "Show", Reapply)
end

RestoreBlizzardFrameSelection = function(record)
    if not record then
        return
    end

    if record.nativeSelection and record.nativeSelection.SetAlpha and record.nativeSelectionAlpha ~= nil then
        record.nativeSelection:SetAlpha(record.nativeSelectionAlpha)
        record.nativeSelectionAlpha = nil
    end

    if not record.hiddenRegions or #record.hiddenRegions == 0 then
        record.nativeHidden = false
        return
    end

    for i = 1, #record.hiddenRegions do
        local entry = record.hiddenRegions[i]
        local region = entry and entry.region
        if region then
            if entry.r ~= nil and region.SetVertexColor then
                region:SetVertexColor(entry.r, entry.g, entry.b, entry.a or 1)
            end
            if entry.alpha ~= nil and region.SetAlpha then
                region:SetAlpha(entry.alpha)
            end
        end
    end
    wipe(record.hiddenRegions)
    record.nativeHidden = false
end

local function RestoreBlizzardFrameTarget(record)
    if not record or not record.targetHidden or not record.target or not record.target.SetAlpha then
        return
    end

    record.target:SetAlpha(1)
    record.targetHidden = false
end

local function HideBlizzardFrameTarget(record)
    if not record or record.targetHidden or not record.target or not record.target.SetAlpha then
        return
    end

    record.target:SetAlpha(0)
    record.targetHidden = true
end

HideBlizzardFrameSelection = function(record)
    local selection = record and record.nativeSelection
    if not selection or record.nativeHidden then
        return
    end

    TintBlizzardFrameSelection(record)

    if selection.GetAlpha and selection.SetAlpha and record.nativeSelectionAlpha == nil then
        record.nativeSelectionAlpha = selection:GetAlpha()
        selection:SetAlpha(0.01)
    end

    record.nativeHidden = true
end

local function EnsureBlizzardFrameVisual(info, target, anchor)
    local record = FindBlizzardFrameVisual(info.key)
    if record then
        if record.nativeSelection ~= anchor then
            RestoreBlizzardFrameSelection(record)
            record.nativeSelection = anchor
        end
        record.target = target
        record.anchor = anchor or target
        if record.visual and record.visual.Label and info.label then
            record.visual.Label:SetText(info.label)
        end
        return record
    end

    record = CreateBlizzardFrameVisual(info.key, anchor or target, info.label)
    record.target = target
    record.anchor = anchor or target
    record.nativeSelection = anchor
    return record
end

local function StyleSelectionOverlay(overlay, nativeOnly)
    if not overlay then return end
    if nativeOnly then
        return
    end

    local state = EM.StyledOverlays[overlay]
    if not state then
        state = {
            regions = {},
            nativeOnly = nativeOnly and true or false,
        }
        EM.StyledOverlays[overlay] = state
    else
        state.nativeOnly = nativeOnly and true or false
    end

    for _, region in ipairs(GetOverlayRegions(overlay)) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if region ~= overlay.KT_BackgroundTint and region ~= overlay.KT_HoverTint then
                if not nativeOnly and not state.regions[region] then
                    local r, g, b, a = 1, 1, 1, 1
                    if region.GetVertexColor then
                        local okColor, cr, cg, cb, ca = pcall(region.GetVertexColor, region)
                        if okColor then
                            r, g, b, a = cr, cg, cb, ca
                        end
                    end
                    state.regions[region] = {
                        r = r, g = g, b = b, a = a,
                        alpha = region.GetAlpha and region:GetAlpha() or 1,
                    }
                end
                if not nativeOnly and region.GetAlpha and region.SetAlpha then
                    local alpha = region:GetAlpha() or 1
                    if not alpha or alpha <= 0 then
                        alpha = 1
                    end
                    region:SetAlpha(alpha)
                end
                if region.SetVertexColor then
                    region:SetVertexColor(EDITMODE_R, EDITMODE_G, EDITMODE_B, 1)
                end
            end
        end
    end

    if not overlay.KT_BackgroundTint then
        local bg = overlay:CreateTexture(nil, "BACKGROUND", nil, 0)
        bg:SetAllPoints()
        bg:SetColorTexture(EDITMODE_R, EDITMODE_G, EDITMODE_B, 0.10)
        overlay.KT_BackgroundTint = bg
    end

    if not overlay.KT_HoverTint then
        local hover = overlay:CreateTexture(nil, "HIGHLIGHT", nil, 1)
        hover:SetAllPoints()
        hover:SetColorTexture(EDITMODE_R, EDITMODE_G, EDITMODE_B, 0.16)
        hover:Hide()
        overlay.KT_HoverTint = hover
    end

    if not overlay.KT_BorderFrame then
        local border = CreateFrame("Frame", nil, overlay)
        border:SetAllPoints()
        border:SetFrameLevel(overlay:GetFrameLevel() + 10)
        KT:AddBorder(border, EDITMODE_R, EDITMODE_G, EDITMODE_B, 1)
        overlay.KT_BorderFrame = border
    else
        KT:AddBorder(overlay.KT_BorderFrame, EDITMODE_R, EDITMODE_G, EDITMODE_B, 1)
    end
    if overlay.KT_BackgroundTint then overlay.KT_BackgroundTint:Show() end
    if overlay.KT_BorderFrame then overlay.KT_BorderFrame:Show() end
end

local function RestoreSelectionOverlay(overlay)
    if not overlay then return end
    local state = EM.StyledOverlays[overlay]
    if not state then
        return
    end

    for _, region in ipairs(GetOverlayRegions(overlay)) do
        local original = region and state.regions and state.regions[region]
        if original then
            if region.SetVertexColor then
                region:SetVertexColor(original.r or 1, original.g or 1, original.b or 1, original.a or 1)
            end
            if region.SetAlpha then
                region:SetAlpha(original.alpha or 1)
            end
        end
    end

    if overlay.KT_BackgroundTint then overlay.KT_BackgroundTint:Hide() end
    if overlay.KT_HoverTint then overlay.KT_HoverTint:Hide() end
    if overlay.KT_BorderFrame then overlay.KT_BorderFrame:Hide() end
end

function EM:DebugDumpRegisteredSystems(filterText)
    local registered = EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames
    if not registered then
        if KT and KT.Print then
            KT:Print("|cFFFF0000[KT EditMode Debug]|r No registeredSystemFrames available.")
        end
        return
    end

    local filter = type(filterText) == "string" and filterText ~= "" and string.lower(filterText) or nil
    if KT and KT.Print then
        KT:Print("|cFF00FFFF[KT EditMode Debug]|r Registered Blizzard systems:")
    end

    local count = 0
    for _, systemFrame in pairs(registered) do
        if systemFrame then
            local frameName = SafeGetFrameName(systemFrame) or tostring(systemFrame)
            local selectedFrame = SafeGetField(systemFrame, "selectedFrame")
            local selectedFrameName = SafeGetFrameName(selectedFrame) or tostring(selectedFrame)
            local selection = SafeGetField(systemFrame, "Selection")
            local selectionName = SafeGetFrameName(selection) or tostring(selection)
            local systemNameString = SafeGetField(systemFrame, "systemNameString")
            local systemInfo = SafeGetField(systemFrame, "systemInfo")
            local systemInfoName = type(systemInfo) == "table" and systemInfo.name or nil
            local okSystem, systemID = pcall(function() return systemFrame:GetSystem() end)
            local okIndex, systemIndex = pcall(function() return systemFrame:GetSystemIndex() end)

            local line = string.format(
                "frame=%s | selected=%s | selection=%s | system=%s | index=%s | systemNameString=%s | systemInfo.name=%s",
                tostring(frameName),
                tostring(selectedFrameName),
                tostring(selectionName),
                okSystem and tostring(systemID) or "nil",
                okIndex and tostring(systemIndex) or "nil",
                tostring(systemNameString),
                tostring(systemInfoName)
            )

            if not filter or string.find(string.lower(line), filter, 1, true) then
                if KT and KT.Print then
                    KT:Print("|cFF00FFFF[KT EditMode Debug]|r " .. line)
                end
                count = count + 1
            end
        end
    end

    if KT and KT.Print then
        KT:Print("|cFF00FFFF[KT EditMode Debug]|r Resolved KUI targets:")
    end
    for _, info in ipairs(GetBlizzardVisualTargets()) do
        local target, selection = ResolveBlizzardVisualTarget(info)
        local line = string.format(
            "key=%s | label=%s | target=%s | selection=%s",
            tostring(info.key),
            tostring(info.label),
            tostring(SafeGetFrameName(target) or target),
            tostring(SafeGetFrameName(selection) or selection)
        )
        if not filter or string.find(string.lower(line), filter, 1, true) then
            if KT and KT.Print then
                KT:Print("|cFF00FFFF[KT EditMode Debug]|r " .. line)
            end
        end
    end

    if count == 0 and filter then
        if KT and KT.Print then
            KT:Print("|cFF00FFFF[KT EditMode Debug]|r No matches for filter: " .. filter)
        end
    end
end

function EM:ReskinBlizzardEditModeOverlays()
    return
end

function EM:RestoreSelectionOverlays()
    return
end

function EM:OnInitialize()
    if KT.db and KT.db.profile then
        if not KT.db.profile.editMode then KT.db.profile.editMode = {} end
        self.db = KT.db.profile.editMode
        if not self.db.frames then self.db.frames = {} end
    end
end

function EM:OnEnable()
    local function runEditDebug(msg)
        local mod = KT:GetModule("EditMode", true)
        if mod and mod.DebugDumpRegisteredSystems then
            if KT and KT.Print then
                KT:Print("|cFF00FFFF[KT EditMode Debug]|r ejecutando dump" .. ((msg and msg ~= "") and (": " .. msg) or "."))
            end
            mod:DebugDumpRegisteredSystems(msg)
        end
    end

    if KT and KT.RegisterChatCommand and not self._ktEditDebugCmdRegistered then
        KT:RegisterChatCommand("kteditdebug", runEditDebug)
        KT:RegisterChatCommand("ktemdebug", runEditDebug)
        self._ktEditDebugCmdRegistered = true
    else
        SLASH_KTEDITDEBUG1 = "/kteditdebug"
        SLASH_KTEDITDEBUG2 = "/ktemdebug"
        SlashCmdList["KTEDITDEBUG"] = runEditDebug
    end

    -- Leave Blizzard's native HUD Edit Mode entirely untouched to avoid
    -- taint paths on sensitive systems like Blizzard_DamageMeter.
    self:RestoreAllPositions()
    
    if KT.db then
        KT.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileReset", "Refresh")
    end
end

function EM:GetOrCreateExtraOptionsFrame()
    if self.ExtraFrame then return self.ExtraFrame end

    local f = CreateFrame("Frame", "KullThranUI_EditModeExtra", _G.EditModeSystemSettingsDialog, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_BLIZZARD)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(_G.EditModeSystemSettingsDialog:GetFrameLevel() + 20)
    
    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.Title:SetPoint("TOP", 0, -12)
    f.Title:SetText(LText("KullThranUI Options"))

    f.FadeCheckbox = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
    f.FadeCheckbox:SetPoint("TOPLEFT", 20, -30)
    f.FadeCheckbox.Text:SetText(LText("Fade on Mouseover"))
    f.FadeCheckbox:SetScript("OnClick", function(btn)
        local isChecked = btn:GetChecked()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        SetMouseoverSetting(f.targetID, isChecked)
        
        local AB = KT:GetModule("ActionBars", true)
        if AB then AB:UpdateMouseoverState() end
        local BF = KT:GetModule("BlizzardFrames")
        if BF then BF:UpdateMouseoverState() end
    end)

    local fontGroup = CreateFrame("Frame", nil, f)
    fontGroup:SetPoint("TOPLEFT", f.FadeCheckbox, "BOTTOMLEFT", 0, -5)
    fontGroup:SetSize(180, 160)
    f.FontGroup = fontGroup

    local WIDGET_WIDTH = 160 
    local dropdown = AceGUI:Create("Dropdown")
    dropdown.frame:SetParent(fontGroup)
    dropdown.frame:SetPoint("TOPLEFT", 0, 0)
    dropdown:SetLabel(LText("Global Font"))
    dropdown:SetWidth(WIDGET_WIDTH)
    
    local fonts = LSM:List("font")
    local fontList = {}
    for _, font in ipairs(fonts) do fontList[font] = font end
    dropdown:SetList(fontList)
    
    dropdown:SetCallback("OnValueChanged", function(widget, event, key)
        KT.db.profile.blizzframes.trackerFont = key
        local BF = KT:GetModule("BlizzardFrames")
        if BF then BF:UpdateTrackerStyling() end
    end)
    f.FontDropdown = dropdown

    local slider = AceGUI:Create("Slider")
    slider.frame:SetParent(fontGroup)
    slider.frame:SetPoint("TOPLEFT", 0, -50)
    slider:SetLabel(LText("Header Size (Titles)"))
    slider:SetWidth(WIDGET_WIDTH)
    slider:SetSliderValues(8, 32, 1)
    
    slider:SetCallback("OnValueChanged", function(widget, event, value)
        KT.db.profile.blizzframes.trackerFontSizeHeaders = value
        local BF = KT:GetModule("BlizzardFrames")
        if BF then BF:UpdateTrackerStyling() end
    end)
    f.SizeSlider = slider
    
    local colorPicker = AceGUI:Create("ColorPicker")
    colorPicker.frame:SetParent(fontGroup)
    colorPicker.frame:SetPoint("TOPLEFT", 0, -90)
    colorPicker:SetLabel(LText("Global Text Color"))
    colorPicker:SetHasAlpha(true)
    colorPicker:SetWidth(WIDGET_WIDTH)
    
    colorPicker:SetCallback("OnValueConfirmed", function(widget, event, r, g, b, a)
        KT.db.profile.blizzframes.trackerColor = {r=r, g=g, b=b, a=a}
        local BF = KT:GetModule("BlizzardFrames")
        if BF then BF:UpdateTrackerStyling() end
    end)
    f.ColorPicker = colorPicker

    self.ExtraFrame = f
    return f
end

function EM:OnUpdateSettingsDialog(dialog, systemFrame)
    local attached = systemFrame or dialog.attachedTo
    if not attached then 
        if self.ExtraFrame then self.ExtraFrame:Hide() end
        return 
    end

    local name = attached:GetName()
    
    -- [FIX DEFINITIVO] Detección de Barras
    local isBar1 = (name == "MainActionBar" or name == "MainMenuBar") -- Aquí estaba la clave
    local isBar2 = (attached == _G.MultiBarBottomLeft)
    local isBar3 = (attached == _G.MultiBarBottomRight)
    local isBar4 = (attached == _G.MultiBarRight)
    local isBar5 = (attached == _G.MultiBarLeft)
    local isBar6 = (attached == _G.MultiBar5)
    local isBar7 = (attached == _G.MultiBar6)
    local isBar8 = (attached == _G.MultiBar7)
    local isPet = (attached == _G.PetActionBar)
    local isStance = (attached == _G.StanceBar)
    
    local isBags = (attached == _G.BagsBar or attached == _G.MicroButtonAndBagsBar or (_G.BagsBar and attached == _G.BagsBar:GetParent()))
    local isMicro = (attached == _G.MicroMenuContainer or attached == _G.MicroMenu)
    local isTracker = (attached == _G.ObjectiveTrackerFrame)
    local isStatus = (attached == _G.StatusTrackingBarManager)
    local isQueue = (attached == GetQueueStatusFrame())

    -- Fallback por si los nombres de frames globales cambian, intentar leer System Index
    if attached.GetSystem and attached:GetSystem() == 1 and attached.GetSystemIndex then -- 1 = ActionBar
        local idx = attached:GetSystemIndex()
        if idx == 1 then isBar1 = true
        elseif idx == 2 then isBar2 = true
        elseif idx == 3 then isBar3 = true
        elseif idx == 4 then isBar4 = true
        elseif idx == 5 then isBar5 = true
        elseif idx == 6 then isBar6 = true
        elseif idx == 7 then isBar7 = true
        elseif idx == 8 then isBar8 = true
        end
    end

    local isSimpleFade = isBags or isMicro or isBar1 or isBar2 or isBar3 or isBar4 or isBar5 or isBar6 or isBar7 or isBar8 or isPet or isStance or isStatus or isQueue
    
    if not isSimpleFade and not isTracker then
        if self.ExtraFrame then self.ExtraFrame:Hide() end
        return
    end

    local frame = self:GetOrCreateExtraOptionsFrame()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", 0, 5) 
    frame:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", 0, 5)
    
    local isChecked = false
    
    if isSimpleFade then
        frame.FontGroup:Hide()
        frame:SetHeight(70)

        if isBags then frame.targetID = "bags"
        elseif isMicro then frame.targetID = "micro"
        elseif isBar1 then frame.targetID = "bar1"
        elseif isBar2 then frame.targetID = "bar2"
        elseif isBar3 then frame.targetID = "bar3"
        elseif isBar4 then frame.targetID = "bar4"
        elseif isBar5 then frame.targetID = "bar5"
        elseif isBar6 then frame.targetID = "bar6"
        elseif isBar7 then frame.targetID = "bar7"
        elseif isBar8 then frame.targetID = "bar8"
        elseif isPet then frame.targetID = "pet"
        elseif isStance then frame.targetID = "stance"
        elseif isStatus then frame.targetID = "status"
        elseif isQueue then frame.targetID = "queue" end

        isChecked = GetMouseoverSetting(frame.targetID)
        
    elseif isTracker then
        frame.targetID = "tracker"
        isChecked = GetMouseoverSetting(frame.targetID)
        frame.FontGroup:Show()
        frame.FontDropdown:SetValue(KT.db.profile.blizzframes.trackerFont or "Friz Quadrata TT")
        frame.SizeSlider:SetValue(KT.db.profile.blizzframes.trackerFontSizeHeaders or 16)
        local c = KT.db.profile.blizzframes.trackerColor or {r=1,g=1,b=1,a=1}
        frame.ColorPicker:SetColor(c.r, c.g, c.b, c.a)
        frame:SetHeight(230)
    end
    
    frame.FadeCheckbox:SetChecked(isChecked)
    frame:Show()
end

function EM:RegisterFrame(frame, name, dbKey, options)
    -- (El resto del código de registro de frames custom se mantiene igual)
    if not frame or self.RegisteredFrames[frame] then return end
    
    local internalName = dbKey or name
    options = options or {}
    
    local hiddenParent = CreateFrame("Frame")
    hiddenParent:Hide()
    local overlay = CreateFrame("Frame", nil, hiddenParent, "EditModeSystemSelectionTemplate")
    StyleSelectionOverlay(overlay)
    self.RegisteredOverlays[#self.RegisteredOverlays + 1] = overlay
    
    overlay.parentFrame = frame
    overlay.system = "KullThranUI"
    overlay.systemInfo = { name = name, internalName = internalName, options = options }

    function overlay:GetSettings() return {} end
    function overlay:IsLayoutFrame() return false end
    function overlay:UpdateSystemNode() end
    
    overlay:EnableMouse(true)
    overlay:SetScript("OnEnter", function(self)
        if self.KT_HoverTint then self.KT_HoverTint:Show() end
        ShowHoverTooltip(self, name, LText("Click: Move"))
    end)
    overlay:SetScript("OnLeave", function(self)
        if self.KT_HoverTint then self.KT_HoverTint:Hide() end
        HideHoverTooltip()
    end)
    overlay:HookScript("OnHide", HideHoverTooltip)
    overlay:Hide()
    overlay:SetParent(frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 100)
    if options.overlayStrata then
        SafeCall(overlay.SetFrameStrata, overlay, options.overlayStrata)
    end
    if options.overlayLevel then
        SafeCall(overlay.SetFrameLevel, overlay, options.overlayLevel)
    end
    if options.overlayTopLevel then
        SafeCall(overlay.SetToplevel, overlay, true)
    end

    overlay:SetScript("OnMouseDown", function(s, button)
        if button == "RightButton" then return end
        -- [FIX] Removed SelectSystem call to prevent Taint (Blocked Action)
    end)
    
    overlay:SetScript("OnMouseUp", function(s, button)
        if button == "RightButton" and options.onRightClick then
            options.onRightClick()
        end
    end)
    
    overlay:SetScript("OnDragStart", function(s)
        if EditModeManagerFrame:IsEditModeActive() then
            if options.onDragStart then options.onDragStart() end
            -- Some Blizzard-managed frames (e.g. MinimapCluster) will be snapped back by
            -- UIParent_ManageFramePositions unless marked as user-placed.
            if options.userPlaced and frame.SetUserPlaced then
                SafeCall(frame.SetUserPlaced, frame, true)
            end
            -- [FIX] Proteger llamadas de movimiento
            if not frame:IsMovable() then SafeCall(frame.SetMovable, frame, true) end
            if frame:IsMovable() then
                SafeCall(frame.StartMoving, frame)
                s.isMoving = true
            end
        end
    end)
    overlay:SetScript("OnDragStop", function(s)
        if s.isMoving then
            SafeCall(frame.StopMovingOrSizing, frame)
            s.isMoving = false
            if options.userPlaced and frame.SetUserPlaced then
                SafeCall(frame.SetUserPlaced, frame, true)
            end
            if options.onDragStop then options.onDragStop() end
            local currentName = self.RegisteredFrames[frame] and self.RegisteredFrames[frame].internalName or internalName
            self:SavePosition(frame, currentName)
            -- [FIX] Removed OnSystemPositionChanged call to prevent Taint
        end
    end)

    self.RegisteredFrames[frame] = {
        name = name,
        internalName = internalName,
        overlay = overlay,
        options = options,
    }
    
    if not self.db then if KT.db then self.db = KT.db.profile.editMode end end
    if self.db and self.db.frames then
        if KT and KT.SanitizeEditModeFramesDB then
            KT:SanitizeEditModeFramesDB(self.db.frames)
        end
        local saved = self.db.frames[internalName]
        if not (KT and KT.IsManagedMinimapKey and KT:IsManagedMinimapKey(internalName)) and saved and saved.point then
            SafeCall(frame.ClearAllPoints, frame)
            SafeCall(frame.SetPoint, frame, saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
            if options.userPlaced and frame.SetUserPlaced then
                SafeCall(frame.SetUserPlaced, frame, true)
            end
        end
    end
end

function EM:Refresh()
    if KT.db and KT.db.profile then
        if not KT.db.profile.editMode then KT.db.profile.editMode = {} end
        self.db = KT.db.profile.editMode
        if not self.db.frames then self.db.frames = {} end
    end
    self:RestoreAllPositions()
end

function EM:OnEnterEditMode()
    for frame, data in pairs(self.RegisteredFrames) do
        if data.options.onEnter then data.options.onEnter() end
        if frame:IsShown() then
            data.overlay:Show()
            SafeCall(frame.SetMovable, frame, true)
            if data.options.resizable then SafeCall(frame.SetResizable, frame, true) end
        end
    end

    if C_Timer and KT.db and KT.db.profile and KT.db.profile.debugMode then
        C_Timer.After(0.3, function()
            if self and self.DebugDumpRegisteredSystems and EditModeManagerFrame and EditModeManagerFrame:IsShown() then
                self:DebugDumpRegisteredSystems()
            end
        end)
    end
end

function EM:OnExitEditMode()
    for frame, data in pairs(self.RegisteredFrames) do
        if data.options.onExit then data.options.onExit() end
        data.overlay:Hide()
        SafeCall(frame.SetMovable, frame, false)
        SafeCall(frame.SetResizable, frame, false)
    end
    if self.ExtraFrame then self.ExtraFrame:Hide() end
end

function EM:SavePosition(frame, internalName)
    if KT and KT.IsManagedMinimapKey and KT:IsManagedMinimapKey(internalName) then
        if self.db and self.db.frames then
            self.db.frames[internalName] = nil
        end
        return
    end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    if not self.db.frames[internalName] then self.db.frames[internalName] = {} end
    self.db.frames[internalName].point = point
    self.db.frames[internalName].relativePoint = relativePoint
    self.db.frames[internalName].x = x
    self.db.frames[internalName].y = y
end

function EM:RestoreAllPositions()
    if not self.db or not self.db.frames then return end
    if KT and KT.SanitizeEditModeFramesDB then
        KT:SanitizeEditModeFramesDB(self.db.frames)
    end
    for frame, data in pairs(self.RegisteredFrames) do
        if not (KT and KT.IsManagedMinimapKey and KT:IsManagedMinimapKey(data.internalName)) then
            local saved = self.db.frames[data.internalName]
            if saved and saved.point then
                SafeCall(frame.ClearAllPoints, frame)
                SafeCall(frame.SetPoint, frame, saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
                if data.options and data.options.userPlaced and frame.SetUserPlaced then
                    SafeCall(frame.SetUserPlaced, frame, true)
                end
            end
        end
    end
end
