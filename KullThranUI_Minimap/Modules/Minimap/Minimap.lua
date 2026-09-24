-- Modules/Minimap/Minimap.lua (moved from Modules/Minimap.lua)
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local Mod = KT:NewModule("Minimap", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)
local HBD = LibStub("HereBeDragons-2.0", true)

_G.KT_MINIMAP_MODULE = Mod

local _G = _G
local C_BattleNet = C_BattleNet
local C_FriendList = C_FriendList
local C_Map = C_Map
local CreateFrame = _G.CreateFrame
local Minimap = _G.Minimap
local MapUtil = _G.MapUtil
local UnitPosition = _G.UnitPosition
local CreateVector2D = _G.CreateVector2D
local format = string.format
local math_floor = math.floor
local tonumber = tonumber
local type = type
local debugstack = _G.debugstack
local GetTimePreciseSec = _G.GetTimePreciseSec or _G.GetTime
local UpdateAddOnMemoryUsage = _G.UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = _G.GetAddOnMemoryUsage
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local GetNumGuildMembers = _G.GetNumGuildMembers
local GetPlayerInfoByGUID = _G.GetPlayerInfoByGUID
local BNGetNumFriends = _G.BNGetNumFriends
local sort = table.sort
local lower = string.lower

local FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"
local CALENDAR_ICON = "Interface\\Icons\\INV_Misc_Note_01"
local MAIL_ATLAS = "UI-HUD-Minimap-Mail-Up"
local MAIL_ATLAS_HOVER = "UI-HUD-Minimap-Mail-Mouseover"
local DEFAULT_OFFSET_VERSION = 8
local MINIMAP_ADDON_NAME = "KullThranUI_Minimap"
local SOCIAL_TOOLTIP_WIDTH = 420
local SOCIAL_TOOLTIP_MAX_HEIGHT = 360
local SOCIAL_TOOLTIP_ROW_HEIGHT = 22
local SOCIAL_TOOLTIP_HEADER_HEIGHT = 52
local SOCIAL_TOOLTIP_FOOTER_HEIGHT = 24
local SOCIAL_TOOLTIP_MAX_ROWS = math_floor((SOCIAL_TOOLTIP_MAX_HEIGHT - SOCIAL_TOOLTIP_HEADER_HEIGHT - SOCIAL_TOOLTIP_FOOTER_HEIGHT) / SOCIAL_TOOLTIP_ROW_HEIGHT)

local function ClampColorComponent(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function NormalizeBorderSettings(db)
    if type(db) ~= "table" then return end

    local size = math_floor((tonumber(db.borderSize) or 1) + 0.5)
    if size < 1 then size = 1 end
    if size > 8 then size = 8 end
    db.borderSize = size

    local color = type(db.borderColor) == "table" and db.borderColor or {}
    db.borderColor = {
        r = ClampColorComponent(color.r or color[1], 0),
        g = ClampColorComponent(color.g or color[2], 0),
        b = ClampColorComponent(color.b or color[3], 0),
        a = ClampColorComponent(color.a or color[4], 1),
    }
end


local isSquare = false
local holder
local bottomPanel
local zoneButton, coordsButton, clockButton, performanceButton, friendsButton, guildButton
local calendarButton, mailButton
local txtZone, txtLocation, txtCoords, txtClock, txtPerformance, txtFriends, txtGuild
local mapCoordCache = {}
local classTokenByName

local function GetAccentColor()
    if KT and KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        if r and g and b then return r, g, b end
    end
    return 1, 0.486275, 0.039216
end

local function ResolveClassToken(classFile, className, guid)
    if classFile and classFile ~= "" then return classFile end
    if guid and GetPlayerInfoByGUID then
        local _, token = GetPlayerInfoByGUID(guid)
        if token then return token end
    end
    if not className or className == "" then return nil end

    classTokenByName = classTokenByName or {}
    if not classTokenByName._built then
        local classAPI = _G.C_CreatureInfo
        if classAPI and classAPI.GetClassInfo then
            for classID = 1, 20 do
                local info = classAPI.GetClassInfo(classID)
                if info and info.className and info.classFile then
                    classTokenByName[info.className] = info.classFile
                end
            end
        end
        classTokenByName._built = true
    end
    return classTokenByName[className] or className:gsub("%s+", ""):upper()
end

local function GetClassColor(classToken)
    local colors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local color = colors and classToken and colors[classToken]
    if color then return color.r or 1, color.g or 1, color.b or 1 end
    return 0.82, 0.82, 0.86
end

local function SocialStatus(isAFK, isDND, isMobile)
    if isMobile then return _G.MOBILE or "Mobile", 0.35, 0.72, 1 end
    if isDND then return _G.DND or "DND", 1, 0.32, 0.32 end
    if isAFK then return _G.AFK or "AFK", 1, 0.76, 0.22 end
    return _G.FRIENDS_LIST_ONLINE or "Online", 0.28, 1, 0.42
end

local function MakeSocialEntry(name, level, classFile, className, zone, status, sr, sg, sb, guid)
    local classToken = ResolveClassToken(classFile, className, guid)
    local r, g, b = GetClassColor(classToken)
    return {
        name = (name and name ~= "") and name or _G.UNKNOWN,
        level = tonumber(level) or 0,
        zone = (zone and zone ~= "") and zone or "—",
        status = status or "",
        r = r, g = g, b = b,
        sr = sr or 0.28, sg = sg or 1, sb = sb or 0.42,
    }
end

local function CollectGuildEntries()
    local entries = {}
    if not (_G.IsInGuild and _G.IsInGuild()) then return entries end
    if _G.GuildRoster then _G.GuildRoster() end
    local total = GetNumGuildMembers and GetNumGuildMembers() or 0
    for index = 1, total do
        local name, _, _, level, className, zone, _, _, isOnline, status, classFile, _, _, isMobile, _, _, guid = GetGuildRosterInfo(index)
        if isOnline or isMobile then
            local statusText, sr, sg, sb = SocialStatus(status == true or status == 1, status == 2, isMobile)
            entries[#entries + 1] = MakeSocialEntry(name, level, classFile, className, zone, statusText, sr, sg, sb, guid)
        end
    end
    return entries
end

local function CollectFriendEntries()
    local entries, seen = {}, {}
    local friendCount = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or 0
    for index = 1, friendCount do
        local info = C_FriendList.GetFriendInfoByIndex and C_FriendList.GetFriendInfoByIndex(index)
        if info and info.connected then
            local key = lower(info.name or tostring(index))
            seen[key] = true
            local statusText, sr, sg, sb = SocialStatus(info.afk, info.dnd, false)
            entries[#entries + 1] = MakeSocialEntry(info.name, info.level, nil, info.className, info.area, statusText, sr, sg, sb, info.guid)
        end
    end

    local battleNetCount = BNGetNumFriends and BNGetNumFriends() or 0
    for index = 1, battleNetCount do
        local account = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(index)
        local game = account and account.gameAccountInfo
        if account and game and game.isOnline then
            local characterName = game.characterName
            local displayName = (characterName and characterName ~= "") and characterName or account.accountName or account.battleTag
            local key = lower(displayName or ("bnet" .. index))
            if not seen[key] then
                local statusText, sr, sg, sb = SocialStatus(account.isAFK, account.isDND, false)
                local zone = game.areaName or game.richPresence or game.clientProgram or "Battle.net"
                entries[#entries + 1] = MakeSocialEntry(displayName, game.characterLevel, nil, game.className, zone, statusText, sr, sg, sb, game.playerGuid)
                seen[key] = true
            end
        end
    end
    return entries
end

local function SortSocialEntries(entries)
    sort(entries, function(left, right)
        if left.level ~= right.level then return left.level > right.level end
        return lower(left.name or "") < lower(right.name or "")
    end)
end

local function EmitDebug(...)
    if KT and KT.Print then
        KT:Print(...)
        return
    end

    print(...)
end

local function PerfNowMS()
    return (GetTimePreciseSec and GetTimePreciseSec() or 0) * 1000
end

local function CountTableKeys(tbl)
    local count = 0
    if type(tbl) ~= "table" then
        return 0
    end
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Mod:_EnsurePerfState()
    if self._perfState then
        return self._perfState
    end

    self._perfState = {
        counts = {},
        totals = {},
        peaks = {},
        tickerTicks = 0,
        overlayButtonsCreated = 0,
        lastCapture = nil,
        capture = nil,
        overlaySignature = nil,
        lastDynamicOverlaySignature = nil,
    }
    return self._perfState
end

function Mod:_RecordPerfSample(key, elapsedMs)
    if not key then
        return
    end

    local state = self:_EnsurePerfState()
    state.counts[key] = (state.counts[key] or 0) + 1
    state.totals[key] = (state.totals[key] or 0) + elapsedMs
    if elapsedMs > (state.peaks[key] or 0) then
        state.peaks[key] = elapsedMs
    end

    local capture = state.capture
    if capture and capture.active then
        capture.counts[key] = (capture.counts[key] or 0) + 1
        capture.totals[key] = (capture.totals[key] or 0) + elapsedMs
        if elapsedMs > (capture.peaks[key] or 0) then
            capture.peaks[key] = elapsedMs
        end
    end
end

function Mod:_RecordPerfCaller(key)
    local state = self:_EnsurePerfState()
    local capture = state.capture
    if not (capture and capture.active and key and debugstack) then
        return
    end

    local stack = tostring(debugstack(3, 8, 8) or "")
    local tag

    if stack:find("UpdateDynamicStats", 1, true) then
        tag = "UpdateDynamicStats"
    elseif stack:find("RefreshAfterUIShow", 1, true) then
        tag = "RefreshAfterUIShow"
    elseif stack:find("RefreshMinimapOverlay", 1, true) then
        tag = "RefreshMinimapOverlay"
    elseif stack:find("Refresh", 1, true) then
        tag = "Refresh"
    elseif stack:find("ktminimapperf", 1, true) then
        tag = "ktminimapperf"
    else
        tag = stack:match("[^\n]+") or "unknown"
    end

    capture.callers = capture.callers or {}
    capture.callers[key] = capture.callers[key] or {}
    capture.callers[key][tag] = (capture.callers[key][tag] or 0) + 1
end

function Mod:_CaptureAddonMemoryKB()
    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
    end
    if GetAddOnMemoryUsage then
        return tonumber(GetAddOnMemoryUsage(MINIMAP_ADDON_NAME)) or 0
    end
    return 0
end

function Mod:_CollectLegacyMinimapStatsState()
    local runtime = {
        runtimeDisabled = false,
        shownFrames = 0,
        onUpdateFrames = 0,
        onEventFrames = 0,
    }
    local frames = {
        _G.MinimapStats_TimeFrame,
        _G.MinimapStats_SystemStatsFrame,
        _G.MinimapStats_LocationFrame,
        _G.MinimapStats_CoordinatesFrame,
        _G.MinimapStats_InstanceDifficultyFrame,
    }

    local minimapStatsModule = KT and KT.GetModule and KT:GetModule("MinimapStats", true)
    if minimapStatsModule and minimapStatsModule.MS then
        runtime.runtimeDisabled = minimapStatsModule.MS.runtimeDisabled and true or false
    end

    for _, frame in ipairs(frames) do
        if frame then
            if frame.IsShown and frame:IsShown() then
                runtime.shownFrames = runtime.shownFrames + 1
            end
            if frame.GetScript and frame:GetScript("OnUpdate") then
                runtime.onUpdateFrames = runtime.onUpdateFrames + 1
            end
            if frame.GetScript and frame:GetScript("OnEvent") then
                runtime.onEventFrames = runtime.onEventFrames + 1
            end
        end
    end

    return runtime
end

function Mod:GetPerfSnapshot()
    local state = self:_EnsurePerfState()
    return {
        tickerActive = self._dynamicStatsTicker and true or false,
        tickerTicks = state.tickerTicks or 0,
        overlayButtonsCreated = state.overlayButtonsCreated or 0,
        mapCoordCacheEntries = CountTableKeys(mapCoordCache),
        memoryKB = self:_CaptureAddonMemoryKB(),
        lastCapture = state.lastCapture,
        legacyMinimapStats = self:_CollectLegacyMinimapStatsState(),
    }
end

function Mod:StartPerfCapture(duration, onDone)
    duration = tonumber(duration) or 5
    duration = math.max(1, math.min(duration, 60))

    local state = self:_EnsurePerfState()
    if state.capture and state.capture.active then
        return false
    end

    local capture = {
        active = true,
        duration = duration,
        startedAt = GetTime(),
        startMemoryKB = self:_CaptureAddonMemoryKB(),
        startTickerTicks = state.tickerTicks or 0,
        startMapCoordCacheEntries = CountTableKeys(mapCoordCache),
        counts = {},
        totals = {},
        peaks = {},
        callers = {},
        onDone = onDone,
    }
    state.capture = capture

    C_Timer.After(duration, function()
        if state.capture ~= capture or not capture.active then
            return
        end

        local endMemoryKB = self:_CaptureAddonMemoryKB()
        local snapshot = {
            duration = duration,
            counts = capture.counts,
            totals = capture.totals,
            peaks = capture.peaks,
            callers = capture.callers,
            tickerTicks = (state.tickerTicks or 0) - (capture.startTickerTicks or 0),
            tickerActive = self._dynamicStatsTicker and true or false,
            overlayButtonsCreated = state.overlayButtonsCreated or 0,
            mapCoordCacheEntries = CountTableKeys(mapCoordCache),
            mapCoordCacheDelta = CountTableKeys(mapCoordCache) - (capture.startMapCoordCacheEntries or 0),
            memoryStartKB = capture.startMemoryKB or 0,
            memoryEndKB = endMemoryKB,
            memoryDeltaKB = endMemoryKB - (capture.startMemoryKB or 0),
            legacyMinimapStats = self:_CollectLegacyMinimapStatsState(),
        }

        capture.active = false
        state.capture = nil
        state.lastCapture = snapshot

        if capture.onDone then
            capture.onDone(snapshot)
        end
    end)

    return true
end

function Mod:DisableEmbeddedMinimapStatsRuntime()
    local minimapStatsModule = KT and KT.GetModule and KT:GetModule("MinimapStats", true)
    local runtime = minimapStatsModule and minimapStatsModule.MS
    if runtime and runtime.DisableRuntime then
        runtime:DisableRuntime("KullThranUI_Minimap")
    end
end

local function IsReasonableClusterSize(width, height)
    width = tonumber(width) or 0
    height = tonumber(height) or 0
    return width > 0 and height > 0 and width <= 600 and height <= 600
end

local function TryGetCoordsForMap(mapID)
    if not mapID then
        return nil
    end

    if UnitPosition and CreateVector2D and C_Map.GetWorldPosFromMapPos then
        local playerPos = CreateVector2D(0, 0)
        playerPos.x, playerPos.y = UnitPosition("player")
        if playerPos.x and playerPos.y then
            local mapData = mapCoordCache[mapID]
            if not mapData then
                local _, origin = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
                local _, opposite = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
                if origin and opposite then
                    opposite:Subtract(origin)
                    mapData = { origin = origin, size = opposite }
                    mapCoordCache[mapID] = mapData
                end
            end

            if mapData and mapData.origin and mapData.size and mapData.size.x ~= 0 and mapData.size.y ~= 0 then
                playerPos:Subtract(mapData.origin)
                local x = playerPos.y / mapData.size.y
                local y = playerPos.x / mapData.size.x
                if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    return format("%.1f, %.1f", x * 100, y * 100)
                end
            end
        end
    end

    if C_Map and C_Map.GetPlayerMapPosition then
        local playerPosition = C_Map.GetPlayerMapPosition(mapID, "player")
        if playerPosition then
            local x, y
            if playerPosition.GetXY then
                x, y = playerPosition:GetXY()
            else
                x, y = playerPosition.x, playerPosition.y
            end

            if x and y then
                return format("%.1f, %.1f", x * 100, y * 100)
            end
        end
    end

    return nil
end

local function DebugCoordSourceForMap(mapID)
    if not mapID then
        return "map=nil"
    end

    local parts = { "map=" .. tostring(mapID) }

    if UnitPosition and CreateVector2D and C_Map.GetWorldPosFromMapPos then
        local playerPos = CreateVector2D(0, 0)
        playerPos.x, playerPos.y = UnitPosition("player")
        if playerPos.x and playerPos.y then
            local _, origin = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
            local _, opposite = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
            if origin and opposite then
                opposite:Subtract(origin)
                local px = playerPos.x - origin.x
                local py = playerPos.y - origin.y
                local wx = opposite.x ~= 0 and (py / opposite.y) or nil
                local wy = opposite.y ~= 0 and (px / opposite.x) or nil
                parts[#parts + 1] = "world=" .. tostring(wx and format("%.3f", wx) or "nil") .. "," .. tostring(wy and format("%.3f", wy) or "nil")
            else
                parts[#parts + 1] = "world=nil"
            end
        else
            parts[#parts + 1] = "unitpos=nil"
        end
    end

    if C_Map and C_Map.GetPlayerMapPosition then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local x, y
            if pos.GetXY then
                x, y = pos:GetXY()
            else
                x, y = pos.x, pos.y
            end
            parts[#parts + 1] = "mappos=" .. tostring(x and format("%.3f", x) or "nil") .. "," .. tostring(y and format("%.3f", y) or "nil")
        else
            parts[#parts + 1] = "mappos=nil"
        end
    end

    return table.concat(parts, " | ")
end

local function Hook_GetMinimapShape()
    return isSquare and "SQUARE" or "ROUND"
end

local function FetchFont(fontKey)
    local fontPath = fontKey
    if LSM then
        local fetched = LSM:Fetch("font", fontKey)
        if fetched then
            fontPath = fetched
        end
    end

    if not fontPath or type(fontPath) ~= "string" or not fontPath:find("\\", 1, true) then
        return FONT_FALLBACK
    end

    return fontPath
end

local function FetchCoordsText()
    HBD = HBD or LibStub("HereBeDragons-2.0", true)
    if HBD and HBD.GetPlayerZonePosition then
        local x, y = HBD:GetPlayerZonePosition(true)
        if x and y then
            return format("%.1f, %.1f", x * 100, y * 100)
        end
    end

    if not C_Map then
        return ""
    end

    local candidateMapIDs = {}
    local seen = {}

    local function AddMapID(mapID)
        if mapID and not seen[mapID] then
            seen[mapID] = true
            candidateMapIDs[#candidateMapIDs + 1] = mapID
        end
    end

    if HBD and HBD.GetPlayerZone then
        AddMapID(HBD:GetPlayerZone())
    end
    if MapUtil and MapUtil.GetDisplayableMapForPlayer then
        AddMapID(MapUtil.GetDisplayableMapForPlayer())
    end
    if C_Map.GetBestMapForUnit then
        AddMapID(C_Map.GetBestMapForUnit("player"))
    end
    if C_Map.GetMapForUnit then
        AddMapID(C_Map.GetMapForUnit("player"))
    end

    local index = 1
    while candidateMapIDs[index] do
        local mapID = candidateMapIDs[index]
        local coordsText = TryGetCoordsForMap(mapID)
        if coordsText then
            return coordsText
        end

        if C_Map.GetMapInfo then
            local mapInfo = C_Map.GetMapInfo(mapID)
            if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID ~= 0 then
                AddMapID(mapInfo.parentMapID)
            end
        end
        index = index + 1
    end

    return ""
end

local function FetchZoneText()
    local zoneText = GetMinimapZoneText()
    if not zoneText or zoneText == "" then
        zoneText = GetSubZoneText and GetSubZoneText() or ""
    end
    if not zoneText or zoneText == "" then
        zoneText = GetRealZoneText and GetRealZoneText() or ""
    end
    if not zoneText or zoneText == "" then
        zoneText = GetZoneText and GetZoneText() or ""
    end

    return zoneText or ""
end

local function HookMinimapShowRefresh(frame)
    if not (frame and frame.HookScript) or frame._ktShowRefreshHooked then
        return
    end

    frame._ktShowRefreshHooked = true
    frame:HookScript("OnShow", function()
        if not Mod then
            return
        end
        Mod._ktRestoreQueued = Mod._ktRestoreQueued or false
        if Mod._ktRestoreQueued then
            return
        end
        Mod._ktRestoreQueued = true
        C_Timer.After(0, function()
            if Mod then
                Mod._ktRestoreQueued = false
            end
            if Mod and Mod.RestoreEditModeMinimapPosition then
                Mod:RestoreEditModeMinimapPosition()
            end
        end)
    end)
end

local function QueueCinematicMinimapRestore()
    if not Mod then
        return
    end

    Mod._ktCinematicRestoreToken = (Mod._ktCinematicRestoreToken or 0) + 1
    Mod._ktCinematicPositionRestoreActive = true
    local token = Mod._ktCinematicRestoreToken
    for _, delay in ipairs({ 0, 0.10, 0.35, 0.75 }) do
        C_Timer.After(delay, function()
            if not Mod or token ~= Mod._ktCinematicRestoreToken then
                return
            end

            -- The cinematic frame can still be visible for one frame after the
            -- stop event. Let its OnHide hook queue the actual restore instead.
            if (_G.CinematicFrame and _G.CinematicFrame:IsShown())
                or (_G.MovieFrame and _G.MovieFrame:IsShown()) then
                return
            end

            if Mod.RestoreEditModeMinimapPosition then
                Mod:RestoreEditModeMinimapPosition(true)
            end

            if delay == 0.75 then
                C_Timer.After(0.05, function()
                    if Mod and token == Mod._ktCinematicRestoreToken then
                        Mod._ktCinematicPositionRestoreActive = nil
                        if Mod.RememberClusterPosition then
                            Mod:RememberClusterPosition()
                        end
                    end
                end)
            end
        end)
    end
end

local function HookCinematicMinimapRestore(frame)
    if not (frame and frame.HookScript) or frame._ktMinimapRestoreHooked then
        return
    end

    frame._ktMinimapRestoreHooked = true
    frame:HookScript("OnHide", QueueCinematicMinimapRestore)
end

local function FetchClockText()
    local hour, minute = GetGameTime()
    if not hour or not minute then
        return ""
    end

    return format("%02d:%02d", hour, minute)
end

local function FetchPerformanceText(showFPS, showMS)
    local parts = {}
    local _, _, latencyHome = GetNetStats()

    if showFPS then
        parts[#parts + 1] = format("|cffd7f3ff%dFPS|r", math_floor(GetFramerate() or 0))
    end

    if showMS then
        parts[#parts + 1] = format("|cffffb347%dMS|r", math_floor(latencyHome or 0))
    end

    return table.concat(parts, " | ")
end

local function SafeHideFrame(frame, hiddenParent)
    if not frame then
        return
    end

    if frame.UnregisterAllEvents then
        frame:UnregisterAllEvents()
    end

    if frame.SetScript then
        frame:SetScript("OnUpdate", nil)
        frame:SetScript("OnEvent", nil)
    end

    if hiddenParent then
        frame:SetParent(hiddenParent)
    end

    frame:Hide()
end

local function HideTextureObject(object)
    if not object then
        return
    end

    if object.SetTexture then
        object:SetTexture(nil)
    end
    if object.SetAtlas then
        object:SetAtlas(nil, true)
    end
    if object.SetAlpha then
        object:SetAlpha(0)
    end
    if object.Hide then
        object:Hide()
    end
    if object.Show then
        object.Show = function() end
    end
end

local function NukeFrameVisuals(frame, hiddenParent)
    if not frame then
        return
    end

    if frame:GetParent() == hiddenParent and not frame:IsShown() then
        local pt, rel = frame:GetPoint(1)
        if pt == "TOPLEFT" and rel == hiddenParent then
            return
        end
    end

    SafeHideFrame(frame, hiddenParent)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", hiddenParent, "TOPLEFT", 0, 0)
    frame:SetAlpha(0)
    frame.Show = function() end

    if frame.GetNumRegions then
        for index = 1, frame:GetNumRegions() do
            local region = select(index, frame:GetRegions())
            if region then
                HideTextureObject(region)
            end
        end
    end
end

local function DumpFrameInfo(frame, label)
    if not frame then
        EmitDebug(label .. ": nil")
        return
    end

    local name = frame.GetName and frame:GetName() or "anonymous"
    local parent = frame.GetParent and frame:GetParent()
    local parentName = parent and parent.GetName and parent:GetName() or "nil"
    local shown = frame.IsShown and frame:IsShown()
    local alpha = frame.GetAlpha and frame:GetAlpha() or -1
    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    local scale = frame.GetScale and frame:GetScale() or 0
    local effectiveScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 0
    local point, relativeTo, relativePoint, x, y = frame.GetPoint and frame:GetPoint(1)
    local relativeName = relativeTo and relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)
    EmitDebug(string.format(
        "%s %s shown=%s alpha=%s parent=%s size=%.1fx%.1f scale=%.3f effectiveScale=%.3f point=%s rel=%s/%s x=%.1f y=%.1f",
        tostring(label),
        tostring(name),
        tostring(shown),
        tostring(alpha),
        tostring(parentName),
        tonumber(width) or 0,
        tonumber(height) or 0,
        tonumber(scale) or 0,
        tonumber(effectiveScale) or 0,
        tostring(point),
        tostring(relativeName),
        tostring(relativePoint),
        tonumber(x) or 0,
        tonumber(y) or 0
    ))
end

local function DumpDifficultyObject(frame, label, depth)
    if not frame or (depth or 0) > 2 then
        return
    end

    DumpFrameInfo(frame, label)

    if frame.IsObjectType and frame:IsObjectType("Texture") then
        local texture = frame.GetTexture and frame:GetTexture() or "nil"
        local atlas = frame.GetAtlas and frame:GetAtlas() or "nil"
        local red, green, blue, alpha = frame.GetVertexColor and frame:GetVertexColor()
        local left, right, top, bottom = frame.GetTexCoord and frame:GetTexCoord()
        EmitDebug(string.format(
            "%s texture=%s atlas=%s vertex=%.2f/%.2f/%.2f/%.2f uv=%.3f/%.3f/%.3f/%.3f",
            tostring(label),
            tostring(texture),
            tostring(atlas),
            tonumber(red) or -1,
            tonumber(green) or -1,
            tonumber(blue) or -1,
            tonumber(alpha) or -1,
            tonumber(left) or -1,
            tonumber(right) or -1,
            tonumber(top) or -1,
            tonumber(bottom) or -1
        ))
        return
    end

    if frame.GetRegions then
        for index = 1, select("#", frame:GetRegions()) do
            local region = select(index, frame:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                DumpDifficultyObject(region, label .. ".region" .. index, (depth or 0) + 1)
            end
        end
    end

    if frame.GetChildren then
        for index = 1, select("#", frame:GetChildren()) do
            local child = select(index, frame:GetChildren())
            if child then
                DumpDifficultyObject(child, label .. ".child" .. index, (depth or 0) + 1)
            end
        end
    end
end

function Mod:OnInitialize()
    KT.db.profile.minimap = KT.db.profile.minimap or {
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
        showFriends = true,
        showGuild = true,
        locationOffsetX = 0, locationOffsetY = 0,
        coordsOffsetX = 0, coordsOffsetY = 0,
        clockOffsetX = 0, clockOffsetY = 0,
        performanceOffsetX = 0, performanceOffsetY = 0,
        friendsOffsetX = 0, friendsOffsetY = 0,
        guildOffsetX = 0, guildOffsetY = 0,
        zoneFont = "Fonts\\FRIZQT__.TTF",
        zoneFontSize = 12,
        zoneFontOutline = "OUTLINE",
        zoneOffsetX = 0,
        zoneOffsetY = 0,
        statsFont = "Fonts\\FRIZQT__.TTF",
        statsFontSize = 11,
        statsFontOutline = "OUTLINE",
    }

    self.db = KT.db.profile.minimap
    self.db.enable = self.db.enable ~= false
    self.db.shape = self.db.shape or "SQUARE"
    self.db.scale = self.db.scale or 1.2
    NormalizeBorderSettings(self.db)
    self.db.showFPS = self.db.showFPS ~= false
    self.db.showMS = self.db.showMS ~= false
    self.db.showClock = self.db.showClock ~= false
    self.db.showZone = self.db.showZone ~= false
    self.db.showCoords = self.db.showCoords ~= false
    self.db.showFriends = self.db.showFriends ~= false
    self.db.showGuild = self.db.showGuild ~= false
    for _, key in ipairs({ "location", "coords", "clock", "performance", "friends", "guild" }) do
        self.db[key .. "OffsetX"] = tonumber(self.db[key .. "OffsetX"]) or 0
        self.db[key .. "OffsetY"] = tonumber(self.db[key .. "OffsetY"]) or 0
    end
    self.db.zoneFont = self.db.zoneFont or "Fonts\\FRIZQT__.TTF"
    self.db.zoneFontSize = self.db.zoneFontSize or 12
    self.db.zoneFontOutline = self.db.zoneFontOutline or "OUTLINE"
    self.db.zoneOffsetX = tonumber(self.db.zoneOffsetX) or 0
    self.db.zoneOffsetY = tonumber(self.db.zoneOffsetY) or 0
    self.db.statsFont = self.db.statsFont or "Fonts\\FRIZQT__.TTF"
    self.db.statsFontSize = self.db.statsFontSize or 11
    self.db.statsFontOutline = self.db.statsFontOutline or "OUTLINE"

    if not self.hooked then
        self._originalGetMinimapShape = _G.GetMinimapShape
        _G.GetMinimapShape = Hook_GetMinimapShape
        self.hooked = true
    end

    self.hiddenFrame = CreateFrame("Frame")
    self.hiddenFrame:Hide()
end

function Mod:OnEnable()
    if not self.db.enable then
        return
    end

    if KT.db and KT.db.RegisterCallback then
        KT.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileReset", "Refresh")
    end

    self:RegisterEvent("ZONE_CHANGED", "UpdateZone")
    self:RegisterEvent("ZONE_CHANGED_INDOORS", "UpdateZone")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateZone")
    self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", "Refresh")
    self:RegisterEvent("UPDATE_INSTANCE_INFO", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("FRIENDLIST_UPDATE", "UpdateSocialStats")
    self:RegisterEvent("BN_FRIEND_INFO_CHANGED", "UpdateSocialStats")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "UpdateSocialStats")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "UpdateSocialStats")
    self:RegisterEvent("UPDATE_PENDING_MAIL", "UpdateOverlayVisibility")
    self:RegisterEvent("CVAR_UPDATE", "OnCVarUpdate")
    self:RegisterEvent("CINEMATIC_START", "OnCinematicStart")
    self:RegisterEvent("PLAY_MOVIE", "OnCinematicStart")
    self:RegisterEvent("CINEMATIC_STOP", "OnCinematicStop")
    self:RegisterEvent("STOP_MOVIE", "OnCinematicStop")

    HookCinematicMinimapRestore(_G.CinematicFrame)
    HookCinematicMinimapRestore(_G.MovieFrame)

    local function runMinimapDebug()
        EmitDebug("|cFF00FFFF[KT Minimap Debug]|r dump")
        DumpFrameInfo(Minimap, "Minimap")
        DumpFrameInfo(_G.MinimapCluster, "MinimapCluster")
        DumpDifficultyObject(_G.MinimapCluster and _G.MinimapCluster.InstanceDifficulty, "MinimapCluster.InstanceDifficulty", 0)
        DumpFrameInfo(_G.KT_MinimapHolder_Main, "KT_MinimapHolder_Main")
        DumpFrameInfo(_G.KT_MinimapZoneText, "KT_MinimapZoneText")
        DumpFrameInfo(_G.KT_MinimapLocation, "KT_MinimapLocation")
        DumpFrameInfo(_G.KT_MinimapCoords, "KT_MinimapCoords")
        DumpFrameInfo(_G.KT_MinimapClock, "KT_MinimapClock")
        DumpFrameInfo(_G.KT_MinimapPerformance, "KT_MinimapPerformance")
        DumpFrameInfo(_G.KT_MinimapFriends, "KT_MinimapFriends")
        DumpFrameInfo(_G.KT_MinimapGuild, "KT_MinimapGuild")
        DumpFrameInfo(_G.KT_MinimapCalendar, "KT_MinimapCalendar")
        DumpFrameInfo(_G.KT_MinimapMail, "KT_MinimapMail")
        DumpFrameInfo(_G.KT_MinimapButtonBag, "KT_MinimapButtonBag")
        DumpFrameInfo(_G.KT_MinimapButtonBagToggle, "KT_MinimapButtonBagToggle")
        DumpFrameInfo(_G.GameTimeFrame, "GameTimeFrame")
        DumpFrameInfo(_G.TimeManagerClockButton, "TimeManagerClockButton")
        DumpFrameInfo(_G.MiniMapMailFrame, "MiniMapMailFrame")
        DumpDifficultyObject(_G.MiniMapInstanceDifficulty, "MiniMapInstanceDifficulty", 0)
        DumpDifficultyObject(_G.GuildInstanceDifficulty, "GuildInstanceDifficulty", 0)
        DumpDifficultyObject(_G.InstanceDifficultyHeadBanner, "InstanceDifficultyHeadBanner", 0)

        for _, child in ipairs({ Minimap:GetChildren() }) do
            if child and child.IsShown and child:IsShown() then
                local childName = child.GetName and child:GetName() or "anonymous"
                EmitDebug(string.format("Minimap child: %s %s alpha=%s", tostring(childName), tostring(child:GetObjectType()), tostring(child:GetAlpha())))
            end
        end
    end

    if KT and KT.RegisterChatCommand and not self._ktMinimapDebugCmdRegistered then
        KT:RegisterChatCommand("ktminimapdebug", runMinimapDebug)
        self._ktMinimapDebugCmdRegistered = true
    else
        _G.SLASH_KTMINIMAPDEBUG1 = "/ktminimapdebug"
        SlashCmdList.KTMINIMAPDEBUG = runMinimapDebug
    end

    _G.SLASH_KTCOORDSDEBUG1 = "/ktcoordsdebug"
    SlashCmdList.KTCOORDSDEBUG = function()
        local bestMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local mapForUnit = C_Map and C_Map.GetMapForUnit and C_Map.GetMapForUnit("player")
        local displayableMap = MapUtil and MapUtil.GetDisplayableMapForPlayer and MapUtil.GetDisplayableMapForPlayer()
        local hbdMap = HBD and HBD.GetPlayerZone and HBD:GetPlayerZone()
        local hbdX, hbdY = HBD and HBD.GetPlayerZonePosition and HBD:GetPlayerZonePosition(true)
        local unitX, unitY, unitZ, unitInstance = UnitPosition and UnitPosition("player")

        print("KT Coords Debug")
        print("showCoords=", tostring(self.db and self.db.showCoords))
        print("bestMap=", tostring(bestMap), "mapForUnit=", tostring(mapForUnit), "displayableMap=", tostring(displayableMap), "hbdMap=", tostring(hbdMap))
        print("unitPosition=", tostring(unitX), tostring(unitY), tostring(unitZ), tostring(unitInstance))
        print("hbdCoords=", tostring(hbdX), tostring(hbdY))
        print("fetchCoords=", tostring(FetchCoordsText()))
        print(DebugCoordSourceForMap(bestMap))
        if mapForUnit and mapForUnit ~= bestMap then
            print(DebugCoordSourceForMap(mapForUnit))
        end
        if displayableMap and displayableMap ~= bestMap and displayableMap ~= mapForUnit then
            print(DebugCoordSourceForMap(displayableMap))
        end
        if hbdMap and hbdMap ~= bestMap and hbdMap ~= mapForUnit and hbdMap ~= displayableMap then
            print(DebugCoordSourceForMap(hbdMap))
        end
    end

    self:DisableEmbeddedMinimapStatsRuntime()
    self:CreateLayout()

    if not self._ktClusterPositionHooked and _G.MinimapCluster and hooksecurefunc then
        self._ktClusterPositionHooked = true
        hooksecurefunc(_G.MinimapCluster, "SetPoint", function()
            if not Mod or Mod._ktRestoringClusterPosition or Mod._ktCinematicPositionRestoreActive then
                return
            end
            if Mod.RememberClusterPosition then
                Mod:RememberClusterPosition()
            end
        end)
    end

    HookMinimapShowRefresh(_G.MinimapCluster)
    HookMinimapShowRefresh(Minimap)

    if not self._ktClusterSizeHooked and _G.MinimapCluster and hooksecurefunc then
        self._ktClusterSizeHooked = true
        hooksecurefunc(_G.MinimapCluster, "SetSize", function(_, width, height)
            if not Mod or Mod._ktRestoringClusterSize then
                return
            end

            if IsReasonableClusterSize(width, height) then
                if Mod.RememberClusterSize then
                    C_Timer.After(0, function()
                        if Mod and Mod.RememberClusterSize then
                            Mod:RememberClusterSize()
                        end
                    end)
                end
                return
            end

            C_Timer.After(0, function()
                if Mod and Mod.RestoreClusterSize then
                    Mod:RestoreClusterSize(true)
                end
            end)
        end)
    end

    if not self._ktUIParentShowHooked and _G.UIParent and _G.UIParent.HookScript then
        self._ktUIParentShowHooked = true
        _G.UIParent:HookScript("OnShow", function()
            if not Mod then
                return
            end
            Mod._ktRestoreQueued = Mod._ktRestoreQueued or false
            if Mod._ktRestoreQueued then
                return
            end
            Mod._ktRestoreQueued = true
            C_Timer.After(0.1, function()
                if Mod then
                    Mod._ktRestoreQueued = false
                end
                if Mod and Mod.RestoreEditModeMinimapPosition then
                    Mod:RestoreEditModeMinimapPosition()
                end
            end)
        end)
    end

    self:Refresh()
end

function Mod:UpdateAll()
    self:Refresh()
end

local function StyleModernMinimapIcon(frame, icon, inset)
    if not frame then return end
    inset = tonumber(inset) or 3
    frame:SetSize(22, 22)

    if not frame._ktModernIconBackground then
        local background = frame:CreateTexture(nil, 'BACKGROUND')
        background:SetAllPoints()
        background:SetColorTexture(0.012, 0.012, 0.016, 0.96)
        frame._ktModernIconBackground = background

        frame._ktModernIconEdges = {}
        for index = 1, 4 do
            frame._ktModernIconEdges[index] = frame:CreateTexture(nil, 'BORDER')
        end
        frame._ktModernIconEdges[1]:SetPoint('TOPLEFT')
        frame._ktModernIconEdges[1]:SetPoint('TOPRIGHT')
        frame._ktModernIconEdges[1]:SetHeight(1)
        frame._ktModernIconEdges[2]:SetPoint('BOTTOMLEFT')
        frame._ktModernIconEdges[2]:SetPoint('BOTTOMRIGHT')
        frame._ktModernIconEdges[2]:SetHeight(1)
        frame._ktModernIconEdges[3]:SetPoint('TOPLEFT')
        frame._ktModernIconEdges[3]:SetPoint('BOTTOMLEFT')
        frame._ktModernIconEdges[3]:SetWidth(1)
        frame._ktModernIconEdges[4]:SetPoint('TOPRIGHT')
        frame._ktModernIconEdges[4]:SetPoint('BOTTOMRIGHT')
        frame._ktModernIconEdges[4]:SetWidth(1)

        local highlight = frame:CreateTexture(nil, 'HIGHLIGHT')
        highlight:SetPoint('TOPLEFT', 1, -1)
        highlight:SetPoint('BOTTOMRIGHT', -1, 1)
        highlight:SetColorTexture(1, 1, 1, 0.10)
        frame._ktModernIconHighlight = highlight
    end

    for _, edge in ipairs(frame._ktModernIconEdges or {}) do
        edge:Hide()
    end

    if icon then
        icon:SetDrawLayer('ARTWORK', 1)
        icon:ClearAllPoints()
        icon:SetPoint('TOPLEFT', frame, 'TOPLEFT', inset, -inset)
        icon:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -inset, inset)
        icon:SetVertexColor(1, 1, 1, 1)
        icon:Show()
    end
end

local function SetModernMailIcon(button, hovered)
    local icon = button and button.Icon
    if not icon then return end

    icon:ClearAllPoints()
    icon:SetSize(17, 13)
    icon:SetPoint('CENTER', button, 'CENTER', 1, -1)
    icon:SetAtlas(hovered and MAIL_ATLAS_HOVER or MAIL_ATLAS)
    icon:SetVertexColor(1, 1, 1, 1)
    icon:Show()
end

local function SetModernCalendarIcon(button, icon)
    if not button then return end
    if icon then icon:Hide() end

    if not button._ktCalendarPage then
        local page = button:CreateTexture(nil, 'ARTWORK', nil, 1)
        page:SetPoint('TOPLEFT', button, 'TOPLEFT', 4, -5)
        page:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -4, 3)
        page:SetColorTexture(0.88, 0.88, 0.88, 1)
        button._ktCalendarPage = page

        local header = button:CreateTexture(nil, 'ARTWORK', nil, 2)
        header:SetPoint('TOPLEFT', page, 'TOPLEFT', 0, 0)
        header:SetPoint('TOPRIGHT', page, 'TOPRIGHT', 0, 0)
        header:SetHeight(3)
        header:SetColorTexture(0.28, 0.28, 0.28, 1)
        button._ktCalendarHeader = header

        local ringLeft = button:CreateTexture(nil, 'OVERLAY', nil, 1)
        ringLeft:SetSize(1, 3)
        ringLeft:SetPoint('TOPLEFT', page, 'TOPLEFT', 2, 2)
        ringLeft:SetColorTexture(0.88, 0.88, 0.88, 1)
        button._ktCalendarRingLeft = ringLeft

        local ringRight = button:CreateTexture(nil, 'OVERLAY', nil, 1)
        ringRight:SetSize(1, 3)
        ringRight:SetPoint('TOPRIGHT', page, 'TOPRIGHT', -2, 2)
        ringRight:SetColorTexture(0.88, 0.88, 0.88, 1)
        button._ktCalendarRingRight = ringRight

        local dayText = button:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        dayText:SetPoint('CENTER', page, 'CENTER', 0, -1)
        dayText:SetTextColor(0.05, 0.05, 0.05, 1)
        button._ktCalendarDay = dayText
    end

    local calendarTime = _G.C_DateAndTime and _G.C_DateAndTime.GetCurrentCalendarTime and _G.C_DateAndTime.GetCurrentCalendarTime()
    button._ktCalendarDay:SetText(calendarTime and calendarTime.monthDay or '')
end

local function HasPendingMail()
    if _G.HasNewMail then
        local ok, hasMail = pcall(_G.HasNewMail)
        if ok then return hasMail and true or false end
    end
    return _G.MiniMapMailFrame and _G.MiniMapMailFrame:IsShown() and true or false
end

function Mod:CreateOverlayButton(name, width, height, anchorPoint, relativePoint, xOffset, yOffset, onClick)
    local perfState = self:_EnsurePerfState()
    perfState.overlayButtonsCreated = (perfState.overlayButtonsCreated or 0) + 1

    local button = CreateFrame("Button", name, holder)
    button:SetSize(width, height)
    button:SetPoint(anchorPoint, holder, relativePoint, xOffset, yOffset)
    button:SetFrameLevel(holder:GetFrameLevel() + 5)
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

function Mod:ApplyZoneAnchor()
    if not zoneButton or not Minimap then
        return
    end

    local targetX = self.db.zoneOffsetX or 0
    local targetY = self.db.zoneOffsetY or 0
    local pt, rel, rpt, x, y = zoneButton:GetPoint(1)
    if pt == "BOTTOM" and rel == Minimap and rpt == "TOP" and x == targetX and y == targetY then
        return
    end

    zoneButton:ClearAllPoints()
    zoneButton:SetPoint("BOTTOM", Minimap, "TOP", targetX, targetY)
end

function Mod:ApplyTrackingAnchor()
    if UIParent and not UIParent:IsShown() then
        return
    end

    local tracking = (_G.MinimapCluster and _G.MinimapCluster.Tracking) or _G.MiniMapTracking
    local anchor = holder or Minimap
    if not tracking or not Minimap or not anchor then
        return
    end

    local pt, rel, rpt, x, y = tracking:GetPoint(1)
    local currentParent = tracking:GetParent()
    if currentParent == anchor and pt == "TOPRIGHT" and rel == anchor and rpt == "TOPRIGHT" and x == -3 and y == -3 then
        return
    end

    if tracking._ktApplyingAnchor then
        return
    end
    tracking._ktApplyingAnchor = true

    tracking:SetParent(anchor)
    tracking:ClearAllPoints()
    tracking:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -3, -3)
    tracking:SetScale(1)
    tracking:SetAlpha(1)
    tracking:SetFrameStrata(anchor:GetFrameStrata() or "DIALOG")
    tracking:SetFrameLevel(anchor:GetFrameLevel() + 6)

    tracking:SetSize(22, 22)
    tracking:ClearAllPoints()
    tracking:SetPoint('TOPRIGHT', anchor, 'TOPLEFT', 0, -22)
    if tracking.Background then
        tracking.Background:Hide()
        if not tracking.Background._ktModernHideHooked then
            hooksecurefunc(tracking.Background, 'Show', function(background)
                background:Hide()
            end)
            tracking.Background._ktModernHideHooked = true
        end
    end
    local trackingButton = tracking.Button or tracking
    if trackingButton ~= tracking then
        trackingButton:SetSize(22, 22)
        trackingButton:ClearAllPoints()
        trackingButton:SetPoint('CENTER', tracking, 'CENTER', 0, 0)
        trackingButton:SetFrameLevel(tracking:GetFrameLevel() + 1)
    end
    local trackingIcon = trackingButton.GetNormalTexture and trackingButton:GetNormalTexture()
    StyleModernMinimapIcon(tracking, trackingIcon, 3)

    tracking._ktApplyingAnchor = false
end

function Mod:CreatePixelPerfectBorder()
    if not holder or holder.KT_PixelBorderFrame then return end

    local borderFrame = CreateFrame("Frame", nil, holder)
    borderFrame:SetAllPoints(holder)
    borderFrame:SetFrameStrata(holder:GetFrameStrata())
    borderFrame:SetFrameLevel(holder:GetFrameLevel() + 100)
    borderFrame:EnableMouse(false)
    holder.KT_PixelBorderFrame = borderFrame

    holder.KT_PixelBorderEdges = {}
    for index = 1, 4 do
        local edge = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetColorTexture(0, 0, 0, 1)
        holder.KT_PixelBorderEdges[index] = edge
    end

    -- Texture segments are used instead of Line objects because their height
    -- remains visually reliable and directly represents the configured pixels.
    holder.KT_PixelBorderSegments = {}
    for index = 1, 128 do
        local segment = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        segment:SetColorTexture(0, 0, 0, 1)
        if segment.SetSnapToPixelGrid then
            segment:SetSnapToPixelGrid(false)
            segment:SetTexelSnappingBias(0)
        end
        holder.KT_PixelBorderSegments[index] = segment
    end

    holder:HookScript("OnSizeChanged", function()
        if Mod and Mod.UpdatePixelPerfectBorder then
            Mod:UpdatePixelPerfectBorder()
        end
    end)
end

function Mod:UpdatePixelPerfectBorder()
    local borderFrame = holder and holder.KT_PixelBorderFrame
    local segments = holder and holder.KT_PixelBorderSegments
    local edges = holder and holder.KT_PixelBorderEdges
    if not (borderFrame and segments and edges) then return end

    NormalizeBorderSettings(self.db)
    local borderColor = self.db and self.db.borderColor or {}
    local red = borderColor.r or 0
    local green = borderColor.g or 0
    local blue = borderColor.b or 0
    local alpha = borderColor.a or 1
    local borderPixels = self.db and self.db.borderSize or 1

    borderFrame:SetFrameStrata(holder:GetFrameStrata())
    borderFrame:SetFrameLevel(holder:GetFrameLevel() + 100)
    borderFrame:Show()

    local effectiveScale = borderFrame.GetEffectiveScale and borderFrame:GetEffectiveScale() or 1
    if not effectiveScale or effectiveScale <= 0 then effectiveScale = 1 end
    local pixel = 1 / effectiveScale
    local thickness = borderPixels * pixel
    local width, height = borderFrame:GetWidth() or 0, borderFrame:GetHeight() or 0
    if width <= 0 or height <= 0 then return end

    for _, edge in ipairs(edges) do
        edge:ClearAllPoints()
        edge:SetColorTexture(red, green, blue, alpha)
        edge:Hide()
    end

    if isSquare then
        for _, segment in ipairs(segments) do segment:Hide() end

        edges[1]:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
        edges[1]:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
        edges[1]:SetHeight(thickness)

        edges[2]:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
        edges[2]:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
        edges[2]:SetHeight(thickness)

        edges[3]:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(thickness)

        edges[4]:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(thickness)

        for _, edge in ipairs(edges) do edge:Show() end
        return
    end

    local segmentCount = #segments
    local radiusX = math.max(pixel, (width * 0.5) - (thickness * 0.5))
    local radiusY = math.max(pixel, (height * 0.5) - (thickness * 0.5))
    local baseRadius = math.min(radiusX, radiusY)
    local segmentLength = (2 * baseRadius * math.sin(math.pi / segmentCount)) + math.max(pixel, thickness * 0.18)

    for index, segment in ipairs(segments) do
        local angle = ((index - 0.5) / segmentCount) * math.pi * 2
        segment:ClearAllPoints()
        segment:SetPoint("CENTER", borderFrame, "CENTER", math.cos(angle) * radiusX, math.sin(angle) * radiusY)
        segment:SetSize(segmentLength, thickness)
        segment:SetRotation(angle + (math.pi * 0.5))
        segment:SetColorTexture(red, green, blue, alpha)
        segment:Show()
    end
end
local function SetDifficultyTextureColor(frame, red, green, blue)
    if not frame then
        return
    end

    if frame.SetBackdropColor then
        frame:SetBackdropColor(red, green, blue, 1)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(red, green, blue, 1)
    end

    if frame.IsObjectType and frame:IsObjectType("Texture") then
        if frame.SetVertexColor then
            frame:SetVertexColor(red, green, blue, 1)
        end
        return
    end

    if frame.GetRegions then
        for index = 1, select("#", frame:GetRegions()) do
            local region = select(index, frame:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("Texture") and region.SetVertexColor then
                region:SetVertexColor(red, green, blue, 1)
            end
        end
    end

    if frame.GetChildren then
        for index = 1, select("#", frame:GetChildren()) do
            SetDifficultyTextureColor(select(index, frame:GetChildren()), red, green, blue)
        end
    end
end

local function GetDifficultyVisualColor()
    local _, _, difficultyID = GetInstanceInfo()
    local red, green, blue = 0.40, 0.80, 1.00 -- Normal: light blue

    if difficultyID and GetDifficultyInfo then
        local _, _, isHeroic, isChallengeMode, displayHeroic, displayMythic = GetDifficultyInfo(difficultyID)
        if isChallengeMode or displayMythic then
            red, green, blue = 0.65, 0.20, 0.90 -- Mythic: purple
        elseif isHeroic or displayHeroic then
            red, green, blue = 0.65, 0.08, 0.08 -- Heroic: dark red
        end
    end

    return red, green, blue
end
local function ApplyNativeDifficultyColor(frame)
    local red, green, blue = GetDifficultyVisualColor()
    SetDifficultyTextureColor(frame, red, green, blue)
end

local function RestoreNativeInstanceDifficulty()
    if not holder then
        return
    end

    local cluster = _G.MinimapCluster
    local modern = cluster and cluster.InstanceDifficulty
    local legacy = _G.MiniMapInstanceDifficulty
    local headBanner = _G.InstanceDifficultyHeadBanner
    local primary = modern

    local function IsDescendant(frame, ancestor)
        if not (frame and ancestor and frame.GetParent) then
            return false
        end

        local parent = frame:GetParent()
        while parent do
            if parent == ancestor then
                return true
            end
            parent = parent.GetParent and parent:GetParent()
        end
        return false
    end

    if not primary or (legacy and legacy.IsShown and legacy:IsShown() and primary.IsShown and not primary:IsShown()) then
        primary = legacy
    end

    local indicators = {}
    if primary then
        indicators[#indicators + 1] = primary
    end
    if headBanner and not IsDescendant(headBanner, primary) then
        indicators[#indicators + 1] = headBanner
    end

    for _, frame in ipairs(indicators) do
        if frame and frame.ClearAllPoints and frame.SetPoint then
            local isTexture = frame.IsObjectType and frame:IsObjectType("Texture")

            if frame.SetParent and frame:GetParent() ~= holder then
                frame:SetParent(holder)
            end

            frame:ClearAllPoints()
            frame:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -2, -2)

            if not isTexture and frame.SetSize then
                frame:SetSize(38, 46)
            end
            if frame.SetScale then
                frame:SetScale(1)
            end
            if frame.SetAlpha then
                frame:SetAlpha(1)
            end
            if not isTexture and frame.SetFrameStrata then
                frame:SetFrameStrata(holder:GetFrameStrata() or "MEDIUM")
            end
            if not isTexture and frame.SetFrameLevel then
                frame:SetFrameLevel(holder:GetFrameLevel() + 8)
            end

            ApplyNativeDifficultyColor(frame)
        end
    end
end

function Mod:CreateLayout()
    if holder or not Minimap then
        return
    end

    if _G.KT_MinimapHolder then
        _G.KT_MinimapHolder:Hide()
    end

    holder = CreateFrame("Frame", "KT_MinimapHolder_Main", _G.UIParent)
    holder:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    holder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
    holder:SetFrameStrata("MEDIUM")
    holder:SetFrameLevel(Minimap:GetFrameLevel() + 30)
    holder:EnableMouse(false)
    self:CreatePixelPerfectBorder()

    bottomPanel = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    bottomPanel:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", -1, -1)
    bottomPanel:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 1, -1)
    bottomPanel:SetHeight(40)
    bottomPanel:SetFrameLevel(holder:GetFrameLevel() + 1)
    bottomPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    bottomPanel:SetBackdropColor(0, 0, 0, 0)
    bottomPanel:SetBackdropBorderColor(0, 0, 0, 0)

    if Mod._dynamicStatsTicker and Mod._dynamicStatsTicker.Cancel then
        Mod._dynamicStatsTicker:Cancel()
    end
    Mod._dynamicStatsTicker = C_Timer.NewTicker(0.5, function()
        if holder and holder.IsShown and holder:IsShown() then
            local perfState = Mod:_EnsurePerfState()
            perfState.tickerTicks = (perfState.tickerTicks or 0) + 1
            Mod:UpdateDynamicStats()
        end
    end)

    zoneButton = CreateFrame("Button", "KT_MinimapZoneText", holder)
    zoneButton:SetWidth(170)
    zoneButton:SetHeight(16)
    zoneButton:SetFrameLevel(holder:GetFrameLevel() + 3)
    zoneButton:SetScript("OnClick", function()
        if _G.ToggleWorldMap then
            _G.ToggleWorldMap()
        end
    end)
    txtZone = zoneButton:CreateFontString(nil, "OVERLAY")
    txtZone:SetPoint("CENTER")
    txtZone:SetJustifyH("CENTER")
    txtZone:SetWordWrap(false)
    self:ApplyZoneAnchor()

    local locationButton = self:CreateOverlayButton("KT_MinimapLocation", 170, 14, "TOPLEFT", "TOPLEFT", 0, 0, function()
        if _G.ToggleWorldMap then
            _G.ToggleWorldMap()
        end
    end)
    locationButton:ClearAllPoints()
    locationButton:SetPoint("TOP", zoneButton, "BOTTOM", 0, -1)
    txtLocation = locationButton:CreateFontString(nil, "OVERLAY")
    txtLocation:SetPoint("CENTER")
    txtLocation:SetJustifyH("CENTER")
    txtLocation:SetWordWrap(false)

    coordsButton = CreateFrame("Button", "KT_MinimapCoords", holder)
    coordsButton:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -6, -4)
    coordsButton:SetWidth(80)
    coordsButton:SetHeight(16)
    coordsButton:SetFrameLevel(holder:GetFrameLevel() + 3)
    coordsButton:SetScript("OnClick", function()
        if _G.ToggleWorldMap then
            _G.ToggleWorldMap()
        end
    end)
    txtCoords = coordsButton:CreateFontString(nil, "OVERLAY")
    txtCoords:SetPoint("RIGHT")
    txtCoords:SetJustifyH("RIGHT")

    calendarButton = self:CreateOverlayButton("KT_MinimapCalendar", 16, 16, "TOPLEFT", "TOPLEFT", 2, -2, function()
        ToggleCalendar()
    end)
    calendarButton.Icon = calendarButton:CreateTexture(nil, "ARTWORK")
    calendarButton.Icon:SetAllPoints(calendarButton)
    calendarButton.Icon:SetTexture(CALENDAR_ICON)
    calendarButton.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    mailButton = self:CreateOverlayButton("KT_MinimapMail", 16, 16, "TOPLEFT", "TOPLEFT", 22, -2, function()
        if _G.MiniMapMailFrame and _G.MiniMapMailFrame:IsShown() then
            local onClick = _G.MiniMapMailFrame:GetScript("OnClick") or _G.MiniMapMailFrame:GetScript("OnMouseUp")
            if onClick then
                onClick(_G.MiniMapMailFrame, "LeftButton")
            end
        end
    end)
    mailButton.Icon = mailButton:CreateTexture(nil, "ARTWORK")

    calendarButton:ClearAllPoints()
    calendarButton:SetPoint('TOPRIGHT', holder, 'TOPLEFT', 0, 0)
    StyleModernMinimapIcon(calendarButton, nil, 3)
    SetModernCalendarIcon(calendarButton, calendarButton.Icon)
    calendarButton:SetScript('OnEnter', function(button)
        GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
        GameTooltip:SetText(_G.CALENDAR or 'Calendar')
        GameTooltip:Show()
    end)
    calendarButton:SetScript('OnLeave', function() GameTooltip:Hide() end)

    mailButton:ClearAllPoints()
    mailButton:SetPoint('TOPRIGHT', holder, 'TOPLEFT', 0, -44)
    StyleModernMinimapIcon(mailButton, mailButton.Icon, 3)
    SetModernMailIcon(mailButton, false)
    mailButton:SetScript('OnEnter', function(button)
        SetModernMailIcon(button, true)
        GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
        GameTooltip:SetText(_G.HAVE_MAIL or 'Mail')
        GameTooltip:Show()
    end)
    mailButton:SetScript('OnLeave', function(button)
        SetModernMailIcon(button, false)
        GameTooltip:Hide()
    end)

    clockButton = self:CreateOverlayButton("KT_MinimapClock", 84, 14, "BOTTOMLEFT", "BOTTOMLEFT", 4, 28, function()
        ToggleCalendar()
    end)
    txtClock = clockButton:CreateFontString(nil, "OVERLAY")
    txtClock:SetPoint("LEFT")
    txtClock:SetJustifyH("LEFT")

    performanceButton = self:CreateOverlayButton("KT_MinimapPerformance", 120, 14, "BOTTOMLEFT", "BOTTOMLEFT", 4, 16)
    txtPerformance = performanceButton:CreateFontString(nil, "OVERLAY")
    txtPerformance:SetPoint("LEFT")
    txtPerformance:SetJustifyH("LEFT")

    local function BindSocialHover(button, kind)
        if not button then return end
        button:EnableMouseWheel(true)
        button:SetScript("OnEnter", function(owner)
            Mod:ShowSocialTooltip(owner, kind)
        end)
        button:SetScript("OnLeave", function(owner)
            Mod:HideSocialTooltip(owner)
        end)
        button:SetScript("OnMouseWheel", function(owner, delta)
            Mod:ScrollSocialTooltip(owner, delta)
        end)
    end

    friendsButton = self:CreateOverlayButton("KT_MinimapFriends", 92, 14, "BOTTOMLEFT", "BOTTOMLEFT", 4, 3, function()
        if _G.ToggleFriendsFrame then
            _G.ToggleFriendsFrame(1)
        end
    end)
    txtFriends = friendsButton:CreateFontString(nil, "OVERLAY")
    txtFriends:SetPoint("LEFT")
    txtFriends:SetJustifyH("LEFT")
    txtFriends:SetTextColor(0, 0.7, 1)
    BindSocialHover(friendsButton, "friends")

    guildButton = self:CreateOverlayButton("KT_MinimapGuild", 92, 14, "BOTTOMRIGHT", "BOTTOMRIGHT", -4, 3, function()
        if _G.ToggleGuildFrame then
            _G.ToggleGuildFrame()
        end
    end)
    txtGuild = guildButton:CreateFontString(nil, "OVERLAY")
    txtGuild:SetPoint("RIGHT")
    txtGuild:SetJustifyH("RIGHT")
    txtGuild:SetTextColor(0.2, 1, 0.2)
    BindSocialHover(guildButton, "guild")

    local guildMinimapButton = self:CreateOverlayButton('KT_MinimapGuildIcon', 22, 22, 'BOTTOMRIGHT', 'BOTTOMLEFT', 0, 22, function()
        if _G.ToggleGuildFrame then
            _G.ToggleGuildFrame()
        end
    end)
    guildMinimapButton:ClearAllPoints()
    guildMinimapButton:SetPoint('BOTTOMRIGHT', holder, 'BOTTOMLEFT', 0, 22)
    guildMinimapButton.Icon = guildMinimapButton:CreateTexture(nil, 'ARTWORK')
    guildMinimapButton.Icon:SetTexture('Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\extra\\guildminimap.png')
    StyleModernMinimapIcon(guildMinimapButton, guildMinimapButton.Icon, 3)
    BindSocialHover(guildMinimapButton, "guild")
    self.guildMinimapButton = guildMinimapButton

    local friendsMinimapButton = self:CreateOverlayButton('KT_MinimapFriendsIcon', 22, 22, 'BOTTOMRIGHT', 'BOTTOMLEFT', 0, 44, function()
        if _G.ToggleFriendsFrame then
            _G.ToggleFriendsFrame(1)
        end
    end)
    friendsMinimapButton:ClearAllPoints()
    friendsMinimapButton:SetPoint('BOTTOMRIGHT', holder, 'BOTTOMLEFT', 0, 44)
    friendsMinimapButton.Icon = friendsMinimapButton:CreateTexture(nil, 'ARTWORK')
    friendsMinimapButton.Icon:SetTexture('Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\extra\\friendlistminimap.png')
    StyleModernMinimapIcon(friendsMinimapButton, friendsMinimapButton.Icon, 3)
    BindSocialHover(friendsMinimapButton, "friends")
    self.friendsMinimapButton = friendsMinimapButton

    local kuiSettingsButton = self:CreateOverlayButton('KT_MinimapKUISettings', 22, 22, 'BOTTOMRIGHT', 'BOTTOMLEFT', 0, 66, function()
        if KT and KT.ToggleConfig then
            pcall(KT.ToggleConfig, KT)
        end
    end)
    kuiSettingsButton:ClearAllPoints()
    kuiSettingsButton:SetPoint('BOTTOMRIGHT', holder, 'BOTTOMLEFT', 0, 66)
    kuiSettingsButton.Icon = kuiSettingsButton:CreateTexture(nil, 'ARTWORK')
    kuiSettingsButton.Icon:SetTexture('Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png')
    StyleModernMinimapIcon(kuiSettingsButton, kuiSettingsButton.Icon, 3)
    kuiSettingsButton:SetScript('OnEnter', function(button)
        GameTooltip:SetOwner(button, 'ANCHOR_RIGHT')
        GameTooltip:ClearLines()
        GameTooltip:AddLine(LText('KullThranUI'), 1, 1, 1)
        GameTooltip:AddLine(LText('Options'), 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    kuiSettingsButton:SetScript('OnLeave', function() GameTooltip:Hide() end)
    self.kuiSettingsButton = kuiSettingsButton

    self:UpdateSocialMinimapIconStyle()
    self:ApplyElementOffsets()
end

function Mod:ApplyElementOffsets()
    if not holder then return end
    local function Place(frame, point, relative, relativePoint, baseX, baseY, key)
        if not frame then return end
        frame:ClearAllPoints()
        frame:SetPoint(point, relative, relativePoint, baseX + (tonumber(self.db[key .. "OffsetX"]) or 0), baseY + (tonumber(self.db[key .. "OffsetY"]) or 0))
    end
    Place(_G.KT_MinimapLocation, "TOP", zoneButton or holder, zoneButton and "BOTTOM" or "TOP", 0, zoneButton and -1 or -20, "location")
    Place(coordsButton, "TOPRIGHT", holder, "TOPRIGHT", -6, -4, "coords")
    Place(clockButton, "BOTTOMLEFT", holder, "BOTTOMLEFT", 4, 28, "clock")
    Place(performanceButton, "BOTTOMLEFT", holder, "BOTTOMLEFT", 4, 16, "performance")
    Place(friendsButton, "BOTTOMLEFT", holder, "BOTTOMLEFT", 4, 3, "friends")
    Place(guildButton, "BOTTOMRIGHT", holder, "BOTTOMRIGHT", -4, 3, "guild")
end

function Mod:ApplyDefaultOffset()
    if not self.db then
        return
    end

    local appliedVersion = tonumber(self.db.defaultOffsetVersion) or 0
    if appliedVersion >= DEFAULT_OFFSET_VERSION then
        return
    end

    local cluster = _G.MinimapCluster
    if cluster and UIParent and cluster.GetPoint and cluster.ClearAllPoints and cluster.SetPoint then
        local point, relativeTo, relativePoint, offsetX, offsetY = cluster:GetPoint(1)
        local isDefaultTopRight = point == "TOPRIGHT"
            and relativePoint == "TOPRIGHT"
            and (relativeTo == UIParent or relativeTo == nil)

        -- Blizzard's corner position leaves no room for the 1.2 KUI minimap
        -- scale, so a new profile can start partially outside the screen. Only
        -- migrate the untouched default corner; user-positioned maps stay put.
        if isDefaultTopRight and (tonumber(offsetX) or 0) > -20 then
            if InCombatLockdown and InCombatLockdown() then
                return
            end

            local moved = pcall(function()
                cluster:ClearAllPoints()
                cluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, math.min(tonumber(offsetY) or -20, -20))
                if cluster.SetUserPlaced then
                    cluster:SetUserPlaced(true)
                end
            end)
            if not moved then
                return
            end
        end
    end

    self.db.defaultOffsetVersion = DEFAULT_OFFSET_VERSION
end

function Mod:RememberClusterPosition()
    local cluster = _G.MinimapCluster
    if not (cluster and cluster.GetPoint) then
        return
    end
    if self._ktRestoringClusterPosition or self._ktCinematicPositionRestoreActive then
        return
    end

    local point, relativeTo, relativePoint, offsetX, offsetY = cluster:GetPoint(1)
    if not point or not relativePoint then
        return
    end

    self._ktLastKnownClusterPosition = {
        point = point,
        relativeTo = relativeTo or UIParent,
        relativePoint = relativePoint,
        offsetX = tonumber(offsetX) or 0,
        offsetY = tonumber(offsetY) or 0,
    }
end

function Mod:RestoreConfiguredClusterPosition(force)
    if not force then
        return
    end

    local cluster = _G.MinimapCluster
    local saved = self._ktLastKnownClusterPosition
    if not (cluster and UIParent and saved and cluster.GetPoint and cluster.ClearAllPoints and cluster.SetPoint) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    self._ktRestoringClusterPosition = true
    local restored = pcall(function()
        cluster:ClearAllPoints()
        cluster:SetPoint(
            saved.point,
            saved.relativeTo or UIParent,
            saved.relativePoint,
            saved.offsetX,
            saved.offsetY
        )
        if cluster.SetUserPlaced then
            cluster:SetUserPlaced(true)
        end
    end)
    self._ktRestoringClusterPosition = nil

    if not restored then
        return
    end
end

function Mod:RestoreMinimapInteraction()
    local cluster = _G.MinimapCluster
    for _, frame in ipairs({ Minimap, cluster }) do
        if frame then
            if frame.EnableMouse then
                pcall(frame.EnableMouse, frame, true)
            end
            if frame.SetMouseClickEnabled then
                pcall(frame.SetMouseClickEnabled, frame, true)
            end
        end
    end

    if holder and holder.EnableMouse then
        holder:EnableMouse(false)
    end
end

function Mod:RememberClusterSize()
    local cluster = _G.MinimapCluster
    if not (cluster and cluster.GetWidth and cluster.GetHeight) then
        return
    end

    local width = tonumber(cluster:GetWidth()) or 0
    local height = tonumber(cluster:GetHeight()) or 0
    if not IsReasonableClusterSize(width, height) then
        return
    end

    self._expectedClusterSize = self._expectedClusterSize or {}
    self._expectedClusterSize.width = width
    self._expectedClusterSize.height = height
end

function Mod:RestoreClusterSize(force)
    local cluster = _G.MinimapCluster
    if not (cluster and cluster.GetWidth and cluster.GetHeight and cluster.SetSize) then
        return
    end

    local expected = self._expectedClusterSize
    if not expected or not expected.width or not expected.height then
        self:RememberClusterSize()
        return
    end

    local width = tonumber(cluster:GetWidth()) or 0
    local height = tonumber(cluster:GetHeight()) or 0
    local tooLarge = not IsReasonableClusterSize(width, height)
        or width > (expected.width * 1.5)
        or height > (expected.height * 1.5)

    if not force and not tooLarge then
        return
    end

    self._ktRestoringClusterSize = true
    cluster:SetSize(expected.width, expected.height)
    self._ktRestoringClusterSize = nil
end

function Mod:Refresh()
    if not KT.db or not KT.db.profile then
        return
    end

    KT.db.profile.minimap = KT.db.profile.minimap or {}
    self.db = KT.db.profile.minimap
    self.db.enable = self.db.enable ~= false
    NormalizeBorderSettings(self.db)

    if not self.db.enable or not Minimap then
        return
    end

    isSquare = self.db.shape == "SQUARE"

    self:CreateLayout()
    RestoreNativeInstanceDifficulty()
    self:ApplyMask()
    self:HandleBorders()
    self:ApplyZoneAnchor()
    self:ApplyTrackingAnchor()
    self:ApplyElementOffsets()

    Minimap:SetScale(self.db.scale or 1)
    self:ApplyDefaultOffset()
    self:RememberClusterPosition()
    self:RestoreMinimapInteraction()
    self:UpdatePixelPerfectBorder()

    self:UpdateFonts()
    self:UpdateZone()
    self:UpdateCoords()
    self:UpdatePerformance()
    self:UpdateSocialStats()
    self:UpdateIcons()
    self:DisableEmbeddedMinimapStatsRuntime()
    self:SuppressLegacyMinimapStats()
    C_Timer.After(0.2, function()
        if Mod and Mod.SuppressLegacyMinimapStats then
            Mod:SuppressLegacyMinimapStats()
        end
    end)
    self:UpdateOverlayVisibility(true)

    if Minimap.UpdateBlips then
        Minimap:UpdateBlips()
    end

    self:RestoreClusterSize()
    C_Timer.After(0, function()
        if Mod and Mod.RememberClusterSize then
            Mod:RememberClusterSize()
        end
    end)
end

function Mod:RefreshAfterUIShow()
    local now = GetTimePreciseSec and GetTimePreciseSec() or 0
    if self._ktLastRefreshAfterUIShowAt and (now - self._ktLastRefreshAfterUIShowAt) < 0.10 then
        return
    end
    self._ktLastRefreshAfterUIShowAt = now

    if self._ktRefreshingAfterUIShow then
        return
    end
    self._ktRefreshingAfterUIShow = true

    if not self.db or self.db.enable == false or not Minimap then
        self._ktRefreshingAfterUIShow = nil
        return
    end

    if UIParent and not UIParent:IsShown() then
        self._ktRefreshingAfterUIShow = nil
        return
    end

    if not holder then
        self:CreateLayout()
    end

    self:ApplyMask()
    self:HandleBorders()
    Minimap:SetScale(self.db.scale or 1)
    self:UpdatePixelPerfectBorder()
    self:RestoreMinimapInteraction()
    self:RestoreClusterSize()


    if holder then
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
        holder:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
    end

    self:ApplyZoneAnchor()
    self:ApplyTrackingAnchor()
    self:ApplyElementOffsets()
    self:UpdateFonts()
    self:UpdateZone()
    self:UpdateCoords()
    self:UpdatePerformance()
    self:UpdateSocialStats()
    self:UpdateIcons()
    self:DisableEmbeddedMinimapStatsRuntime()
    self:SuppressLegacyMinimapStats()
    self:UpdateOverlayVisibility(true)

    if Minimap.UpdateBlips then
        Minimap:UpdateBlips()
    end

    C_Timer.After(0, function()
        if Mod and Mod.RestoreClusterSize then
            Mod:RestoreClusterSize()
        end
        if Mod and Mod.RememberClusterSize then
            Mod:RememberClusterSize()
        end
    end)
    C_Timer.After(0.15, function()
        if Mod and Mod.RestoreClusterSize then
            Mod:RestoreClusterSize()
        end
    end)

    self._ktRefreshingAfterUIShow = nil
end

function Mod:RestoreEditModeMinimapPosition(force)
    local now = GetTimePreciseSec and GetTimePreciseSec() or 0
    if not force and self._ktLastRestoreEditModeAt and (now - self._ktLastRestoreEditModeAt) < 0.10 then
        return
    end
    self._ktLastRestoreEditModeAt = now

    if self._ktRestoringEditMode then
        return
    end
    self._ktRestoringEditMode = true

    local editMode = KT and KT.GetModule and KT:GetModule("EditMode", true)
    if editMode and editMode.RestoreAllPositions then
        pcall(editMode.RestoreAllPositions, editMode)
    end

    self:RestoreConfiguredClusterPosition(force)
    self:RestoreMinimapInteraction()

    if Mod and Mod.RefreshAfterUIShow then
        Mod:RefreshAfterUIShow()
    end

    self._ktRestoringEditMode = nil
end

function Mod:OnCinematicStart()
    self:RememberClusterPosition()
    self._ktCinematicPositionRestoreActive = true
end

function Mod:OnCinematicStop()
    self._ktCinematicPositionRestoreActive = true
    QueueCinematicMinimapRestore()
end

function Mod:OnCVarUpdate(_, name, value)
    if name ~= "SHOW_UI" or value == "0" then
        return
    end

    C_Timer.After(0, function()
        if Mod and Mod.RestoreEditModeMinimapPosition then
            Mod:RestoreEditModeMinimapPosition()
        end
    end)
    C_Timer.After(0.2, function()
        if Mod and Mod.RestoreEditModeMinimapPosition then
            Mod:RestoreEditModeMinimapPosition()
        end
    end)
end

function Mod:UpdateFonts()
    local zoneFont = FetchFont(self.db.zoneFont)
    local zoneSize = tonumber(self.db.zoneFontSize) or 12
    local zoneOutline = self.db.zoneFontOutline or "OUTLINE"
    if zoneOutline == "NONE" or zoneOutline == "" then zoneOutline = nil end
    local statsFont = FetchFont(self.db.statsFont)
    local statsSize = tonumber(self.db.statsFontSize) or 11
    local statsOutline = self.db.statsFontOutline or "OUTLINE"
    if statsOutline == "NONE" or statsOutline == "" then statsOutline = nil end

    if txtZone then
        txtZone:SetFont(zoneFont, zoneSize + 2, zoneOutline)
        txtZone:SetShadowColor(0, 0, 0, 1)
        txtZone:SetShadowOffset(1, -1)
    end
    if txtLocation then
        txtLocation:SetFont(zoneFont, math.max(zoneSize - 1, 10), zoneOutline)
        txtLocation:SetTextColor(0, 0.75, 1, 1)
        txtLocation:SetShadowOffset(0, 0)
    end
    if txtCoords then
        txtCoords:SetFont(statsFont, statsSize, statsOutline)
        txtCoords:SetTextColor(1, 1, 1, 1)
        txtCoords:SetShadowColor(0, 0, 0, 1)
        txtCoords:SetShadowOffset(1, -1)
    end
    if txtClock then
        txtClock:SetFont(statsFont, statsSize + 2, statsOutline)
        txtClock:SetTextColor(1, 1, 1, 1)
        txtClock:SetShadowOffset(0, 0)
    end
    if txtPerformance then
        txtPerformance:SetFont(statsFont, statsSize, statsOutline)
        txtPerformance:SetTextColor(1, 1, 1, 1)
        txtPerformance:SetShadowOffset(0, 0)
    end
    if txtFriends then
        txtFriends:SetFont(statsFont, statsSize + 1, statsOutline)
        txtFriends:SetTextColor(0, 0.7, 1, 1)
        txtFriends:SetShadowOffset(0, 0)
    end
    if txtGuild then
        txtGuild:SetFont(statsFont, statsSize + 1, statsOutline)
        txtGuild:SetTextColor(0.2, 1, 0.2, 1)
        txtGuild:SetShadowOffset(0, 0)
    end
end

function Mod:UpdateZone()
    if not txtZone then
        return
    end

    local minimapZone = FetchZoneText()
    local zone = (GetRealZoneText and GetRealZoneText()) or GetZoneText() or ""
    local pvp = (_G.GetZonePVPInfo and _G.GetZonePVPInfo()) or (C_PvP and C_PvP.GetZonePVPInfo and C_PvP.GetZonePVPInfo())
    local r, g, b = 1, 1, 1

    if pvp == "sanctuary" then
        r, g, b = 0.41, 0.8, 0.94
    elseif pvp == "arena" or pvp == "hostile" then
        r, g, b = 1, 0.1, 0.1
    elseif pvp == "friendly" then
        r, g, b = 0.1, 1, 0.1
    elseif pvp == "contested" then
        r, g, b = 1, 0.7, 0
    end

    txtZone:SetText(minimapZone)
    txtZone:SetTextColor(r, g, b)

    if txtLocation then
        txtLocation:SetText(zone)
    end
end

function Mod:UpdateCoords()
    local startMs = PerfNowMS()
    self:_RecordPerfCaller("UpdateCoords")
    if txtCoords then
        txtCoords:SetText(FetchCoordsText())
    end
    self:_RecordPerfSample("UpdateCoords", PerfNowMS() - startMs)
end

function Mod:UpdatePerformance()
    local startMs = PerfNowMS()
    self:_RecordPerfCaller("UpdatePerformance")
    if txtClock then
        txtClock:SetText(FetchClockText())
    end

    if txtPerformance then
        txtPerformance:SetText(FetchPerformanceText(self.db.showFPS, self.db.showMS))
    end
    self:_RecordPerfSample("UpdatePerformance", PerfNowMS() - startMs)
end

function Mod:UpdateDynamicStats()
    local startMs = PerfNowMS()
    self:UpdateCoords()
    self:UpdatePerformance()
    self:MaybeRefreshDynamicOverlayVisibility()
    self:_RecordPerfSample("UpdateDynamicStats", PerfNowMS() - startMs)
end

function Mod:MaybeRefreshDynamicOverlayVisibility()
    local coordsVisible = self.db.showCoords and txtCoords and txtCoords:GetText() and txtCoords:GetText() ~= ""
    local mailVisible = mailButton and HasPendingMail()
    local perfState = self:_EnsurePerfState()
    local signature = table.concat({
        coordsVisible and "1" or "0",
        mailVisible and "1" or "0",
    }, "|")

    if perfState.lastDynamicOverlaySignature ~= signature then
        perfState.lastDynamicOverlaySignature = signature
        self:UpdateOverlayVisibility(true)
    end
end

function Mod:EnsureSocialTooltip()
    if self.socialTooltip then return self.socialTooltip end

    local frame = CreateFrame("Frame", "KT_MinimapSocialTooltip", _G.UIParent, "BackdropTemplate")
    frame:SetWidth(SOCIAL_TOOLTIP_WIDTH)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(50)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:Hide()
    if KT.AddBackdrop then KT:AddBackdrop(frame, 0.012, 0.014, 0.02, 0.98) end

    local accentR, accentG, accentB = GetAccentColor()
    if KT.AddBorder then KT:AddBorder(frame, accentR, accentG, accentB, 1, 1) end

    local font = FetchFont(self.db and self.db.statsFont)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont(font, 14, "OUTLINE")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    frame.title:SetTextColor(accentR, accentG, accentB, 1)

    frame.count = frame:CreateFontString(nil, "OVERLAY")
    frame.count:SetFont(font, 10, "OUTLINE")
    frame.count:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.count:SetTextColor(0.68, 0.70, 0.76, 1)

    frame.footer = frame:CreateFontString(nil, "OVERLAY")
    frame.footer:SetFont(font, 9, "OUTLINE")
    frame.footer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 7)
    frame.footer:SetTextColor(0.58, 0.60, 0.66, 1)

    frame.rows = {}
    for index = 1, SOCIAL_TOOLTIP_MAX_ROWS do
        local row = CreateFrame("Frame", nil, frame)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -(SOCIAL_TOOLTIP_HEADER_HEIGHT + ((index - 1) * SOCIAL_TOOLTIP_ROW_HEIGHT)))
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(SOCIAL_TOOLTIP_HEADER_HEIGHT + ((index - 1) * SOCIAL_TOOLTIP_ROW_HEIGHT)))
        row:SetHeight(SOCIAL_TOOLTIP_ROW_HEIGHT - 1)

        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.035 or 0.015)

        row.level = row:CreateFontString(nil, "OVERLAY")
        row.level:SetFont(font, 10, "OUTLINE")
        row.level:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.level:SetWidth(34)
        row.level:SetJustifyH("RIGHT")
        row.level:SetTextColor(1, 0.78, 0.24, 1)

        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFont(font, 11, "OUTLINE")
        row.name:SetPoint("LEFT", row.level, "RIGHT", 8, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -190, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row.zone = row:CreateFontString(nil, "OVERLAY")
        row.zone:SetFont(font, 10, "OUTLINE")
        row.zone:SetPoint("RIGHT", row, "RIGHT", -61, 0)
        row.zone:SetWidth(124)
        row.zone:SetJustifyH("RIGHT")
        row.zone:SetWordWrap(false)
        row.zone:SetTextColor(0.70, 0.72, 0.78, 1)

        row.status = row:CreateFontString(nil, "OVERLAY")
        row.status:SetFont(font, 9, "OUTLINE")
        row.status:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row.status:SetWidth(52)
        row.status:SetJustifyH("RIGHT")
        row.status:SetWordWrap(false)

        frame.rows[index] = row
    end

    self.socialTooltip = frame
    return frame
end

function Mod:RefreshSocialTooltipRows()
    local frame = self.socialTooltip
    if not frame then return end

    local entries = frame.entries or {}
    local total = #entries
    local displayCount = math.max(1, math.min(total, SOCIAL_TOOLTIP_MAX_ROWS))
    local maxOffset = math.max(0, total - SOCIAL_TOOLTIP_MAX_ROWS)
    frame.offset = math.max(0, math.min(tonumber(frame.offset) or 0, maxOffset))
    frame:SetHeight(math.min(SOCIAL_TOOLTIP_MAX_HEIGHT, SOCIAL_TOOLTIP_HEADER_HEIGHT + (displayCount * SOCIAL_TOOLTIP_ROW_HEIGHT) + SOCIAL_TOOLTIP_FOOTER_HEIGHT))

    for index, row in ipairs(frame.rows) do
        local entry = entries[frame.offset + index]
        if entry then
            row.level:SetText(entry.level > 0 and entry.level or "—")
            row.name:SetText(entry.name)
            row.name:SetTextColor(entry.r, entry.g, entry.b, 1)
            row.zone:SetText(entry.zone)
            row.status:SetText(entry.status)
            row.status:SetTextColor(entry.sr, entry.sg, entry.sb, 1)
            row:Show()
        elseif total == 0 and index == 1 then
            row.level:SetText("")
            row.name:SetText(_G.NO_ONLINE_MEMBERS or "No connected players")
            row.name:SetTextColor(0.68, 0.70, 0.76, 1)
            row.zone:SetText("")
            row.status:SetText("")
            row:Show()
        else
            row:Hide()
        end
    end

    if total > SOCIAL_TOOLTIP_MAX_ROWS then
        local first = frame.offset + 1
        local last = math.min(total, frame.offset + SOCIAL_TOOLTIP_MAX_ROWS)
        frame.footer:SetText(format("%d–%d / %d  •  %s", first, last, total, _G.MOUSE_LABEL or "Mouse wheel"))
    else
        frame.footer:SetText("")
    end
end

function Mod:ShowSocialTooltip(owner, kind)
    if not owner then return end
    local frame = self:EnsureSocialTooltip()
    local entries = kind == "guild" and CollectGuildEntries() or CollectFriendEntries()
    SortSocialEntries(entries)

    frame.owner = owner
    frame.kind = kind
    frame.entries = entries
    frame.offset = 0
    local accentR, accentG, accentB = GetAccentColor()
    if KT.AddBorder then KT:AddBorder(frame, accentR, accentG, accentB, 1, 1) end
    frame.title:SetText(kind == "guild" and (_G.GUILD or "Guild") or (_G.FRIENDS or "Friends"))
    frame.title:SetTextColor(accentR, accentG, accentB, 1)
    frame.count:SetText(format("%d %s", #entries, lower(_G.FRIENDS_LIST_ONLINE or "online")))
    self:RefreshSocialTooltipRows()

    frame:ClearAllPoints()
    local ownerCenter = owner.GetCenter and owner:GetCenter()
    local screenCenter = (_G.UIParent:GetWidth() or 0) * 0.5
    if ownerCenter and ownerCenter < screenCenter then
        frame:SetPoint("TOPLEFT", owner, "TOPRIGHT", 8, 0)
    else
        frame:SetPoint("TOPRIGHT", owner, "TOPLEFT", -8, 0)
    end
    frame:Show()
end

function Mod:HideSocialTooltip(owner)
    local frame = self.socialTooltip
    if frame and (not owner or frame.owner == owner) then
        frame:Hide()
        frame.owner = nil
    end
end

function Mod:ScrollSocialTooltip(owner, delta)
    local frame = self.socialTooltip
    if not (frame and frame:IsShown() and frame.owner == owner and #frame.entries > SOCIAL_TOOLTIP_MAX_ROWS) then return end
    local maxOffset = math.max(0, #frame.entries - SOCIAL_TOOLTIP_MAX_ROWS)
    frame.offset = math.max(0, math.min(maxOffset, (frame.offset or 0) - delta))
    self:RefreshSocialTooltipRows()
end

function Mod:RefreshVisibleSocialTooltip()
    local frame = self.socialTooltip
    if frame and frame:IsShown() and frame.owner and frame.kind then
        local owner, kind = frame.owner, frame.kind
        self:ShowSocialTooltip(owner, kind)
    end
end

function Mod:UpdateSocialStats()
    if IsInGuild() and GuildRoster then
        GuildRoster()
    end

    if txtGuild then
        local _, online = GetNumGuildMembers()
        local guildCount = (IsInGuild() and online) and online or 0
        txtGuild:SetText(LText("Guild: ") .. guildCount)
    end

    if txtFriends then
        local wowOnline = (C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetNumOnlineFriends()) or 0
        local bnCount = BNGetNumFriends and BNGetNumFriends() or 0
        local bnOnline = 0

        for index = 1, bnCount do
            local info = C_BattleNet and C_BattleNet.GetFriendAccountInfo and C_BattleNet.GetFriendAccountInfo(index)
            if info and info.gameAccountInfo and info.gameAccountInfo.isOnline then
                bnOnline = bnOnline + 1
            end
        end

        txtFriends:SetText(LText("Friends: ") .. (wowOnline + bnOnline))
    end

    self:RefreshVisibleSocialTooltip()
end

function Mod:SuppressNativeMailIndicators(defer)
    if not self.hiddenFrame then return end

    local candidates = {}
    local seen = {}
    local function AddCandidate(frame)
        if not frame or frame == mailButton or seen[frame] then return end
        if frame.IsObjectType and not frame:IsObjectType('Frame') then return end
        seen[frame] = true
        candidates[#candidates + 1] = frame
    end

    local cluster = _G.MinimapCluster
    local indicatorFrame = cluster and cluster.IndicatorFrame
    AddCandidate(_G.MiniMapMailFrame)
    AddCandidate(cluster and cluster.MailFrame)
    AddCandidate(indicatorFrame and indicatorFrame.MailFrame)
    AddCandidate(indicatorFrame and indicatorFrame.MailButton)
    AddCandidate(Minimap and Minimap.MailFrame)

    local function FindNamedMailFrames(parent, depth)
        if not parent or depth <= 0 or not parent.GetChildren then return end
        for _, child in ipairs({ parent:GetChildren() }) do
            local name = child.GetName and child:GetName()
            if name and name:lower():find('mail', 1, true) then
                AddCandidate(child)
            else
                FindNamedMailFrames(child, depth - 1)
            end
        end
    end

    FindNamedMailFrames(cluster, 4)
    FindNamedMailFrames(Minimap, 3)

    for _, frame in ipairs(candidates) do
        NukeFrameVisuals(frame, self.hiddenFrame)
    end

    if defer and not self._ktMailSuppressPending then
        self._ktMailSuppressPending = true
        C_Timer.After(0, function()
            if Mod then
                Mod._ktMailSuppressPending = nil
                Mod:SuppressNativeMailIndicators(false)
            end
        end)
    end
end

function Mod:UpdateOverlayVisibility(force)
    self:SuppressNativeMailIndicators(true)
    local startMs = PerfNowMS()
    self:_RecordPerfCaller("UpdateOverlayVisibility")
    local hasTopLeft = self.db.showZone and txtZone and txtZone:GetText() and txtZone:GetText() ~= ""
    local hasTopRight = self.db.showCoords and txtCoords and txtCoords:GetText() and txtCoords:GetText() ~= ""
    local hasBottom = self.db.showClock or self.db.showFPS or self.db.showMS
    local mailVisible = mailButton and HasPendingMail()
    local signature = table.concat({
        hasTopLeft and "1" or "0",
        hasTopRight and "1" or "0",
        self.db.showClock and "1" or "0",
        (self.db.showFPS or self.db.showMS) and "1" or "0",
        mailVisible and "1" or "0",
        hasBottom and "1" or "0",
    }, "|")
    local perfState = self:_EnsurePerfState()

    if not force and perfState.overlaySignature == signature then
        self:_RecordPerfSample("UpdateOverlayVisibility", PerfNowMS() - startMs)
        return
    end
    perfState.overlaySignature = signature

    if zoneButton then
        zoneButton:SetShown(hasTopLeft)
    end
    if _G.KT_MinimapLocation then
        _G.KT_MinimapLocation:SetShown(hasTopLeft)
    end
    if coordsButton then
        coordsButton:SetShown(hasTopRight)
    end
    if clockButton then
        clockButton:SetShown(self.db.showClock)
    end
    if performanceButton then
        performanceButton:SetShown(self.db.showFPS or self.db.showMS)
    end
    if friendsButton then
        friendsButton:SetShown(self.db.showFriends ~= false)
    end
    if guildButton then
        guildButton:SetShown(self.db.showGuild ~= false)
    end
    if self.guildMinimapButton then
        self.guildMinimapButton:SetShown(self.db.showGuild ~= false)
    end
    if self.friendsMinimapButton then
        self.friendsMinimapButton:SetShown(self.db.showFriends ~= false)
    end
    if calendarButton then
        calendarButton:Show()
    end
    if mailButton then
        mailButton:SetShown(mailVisible)
    end
    if bottomPanel then
        bottomPanel:Hide()
    end
    self:_RecordPerfSample("UpdateOverlayVisibility", PerfNowMS() - startMs)
end

function Mod:UpdateSocialMinimapIconStyle()
    local r, g, b = 1, 0.486275, 0.039216
    if KT and KT.GetStyleAccentRGB then
        local accentR, accentG, accentB = KT:GetStyleAccentRGB()
        if accentR and accentG and accentB then
            r, g, b = accentR, accentG, accentB
        end
    end

    for _, button in ipairs({ self.guildMinimapButton, self.friendsMinimapButton, self.kuiSettingsButton }) do
        if button and button.Icon then
            button:SetSize(22, 22)
            StyleModernMinimapIcon(button, button.Icon, 3)
            button.Icon:SetVertexColor(r, g, b, 1)
        end
    end
end

function Mod:UpdateIcons()
    self:SuppressNativeMailIndicators(true)
    self:UpdateSocialMinimapIconStyle()
    if calendarButton then
        StyleModernMinimapIcon(calendarButton, nil, 3)
        SetModernCalendarIcon(calendarButton, calendarButton.Icon)
    end
    if mailButton then
        StyleModernMinimapIcon(mailButton, mailButton.Icon, 3)
        SetModernMailIcon(mailButton, false)
    end
    if _G.GameTimeFrame then
        NukeFrameVisuals(_G.GameTimeFrame, self.hiddenFrame)
        if not _G.GameTimeFrame._ktHideHooked then
            hooksecurefunc(_G.GameTimeFrame, "Show", function(frame)
                NukeFrameVisuals(frame, Mod.hiddenFrame)
            end)
            _G.GameTimeFrame._ktHideHooked = true
        end
    end

    if _G.TimeManagerClockButton then
        NukeFrameVisuals(_G.TimeManagerClockButton, self.hiddenFrame)
        if not _G.TimeManagerClockButton._ktHideHooked then
            hooksecurefunc(_G.TimeManagerClockButton, "Show", function(frame)
                NukeFrameVisuals(frame, Mod.hiddenFrame)
            end)
            _G.TimeManagerClockButton._ktHideHooked = true
        end
    end

    if _G.MiniMapMailFrame then
        NukeFrameVisuals(_G.MiniMapMailFrame, self.hiddenFrame)
        _G.MiniMapMailFrame:SetScale(0.01)
        _G.MiniMapMailFrame:SetAlpha(0.01)
    end

    for _, widget in ipairs({
        _G.GameTimeCalendarInvitesTexture,
        _G.GameTimeCalendarInvitesGlow,
        _G.GameTimeTexture,
        _G.GameTimeBackground,
        _G.GameTimeIcon,
        _G.GameTimeFrameFlash,
        _G.MiniMapMailBorder,
        _G.MiniMapMailIcon,
        _G.MiniMapMailFlash,
    }) do
        HideTextureObject(widget)
    end

    local tracking = (_G.MinimapCluster and _G.MinimapCluster.Tracking) or _G.MiniMapTracking
    if tracking then
        self:ApplyTrackingAnchor()
        if not tracking._ktAnchorHooked then
            hooksecurefunc(tracking, "Show", function()
                if Mod and Mod.ApplyTrackingAnchor then
                    Mod:ApplyTrackingAnchor()
                end
            end)
            tracking:HookScript("OnShow", function()
                if Mod and Mod.ApplyTrackingAnchor then
                    Mod:ApplyTrackingAnchor()
                end
            end)
            tracking._ktAnchorHooked = true
        end
    end
end

function Mod:ApplyMask()
    Minimap:Hide()
    Minimap:Show()

    if isSquare then
        Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
    else
        Minimap:SetMaskTexture(186178)
    end

    C_Timer.After(0.1, function()
        if isSquare then
            Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
        else
            Minimap:SetMaskTexture(186178)
        end
    end)
end

function Mod:HandleBorders()
    local cluster = _G.MinimapCluster

    if _G.MinimapBorder then
        _G.MinimapBorder:Hide()
    end
    if _G.MinimapBorderTop then
        _G.MinimapBorderTop:Hide()
    end
    if _G.MinimapBackdrop then
        _G.MinimapBackdrop:Hide()
    end
    if _G.MinimapNorthTag then
        _G.MinimapNorthTag:Hide()
    end
    if _G.MinimapCompassTexture then
        _G.MinimapCompassTexture:Hide()
    end
    if cluster and cluster.BorderTop then
        HideTextureObject(cluster.BorderTop)
    end

    if _G.MinimapZoneTextButton then
        NukeFrameVisuals(_G.MinimapZoneTextButton, self.hiddenFrame)
        _G.MinimapZoneTextButton:EnableMouse(false)
        _G.MinimapZoneTextButton:SetHitRectInsets(0, 0, 0, 0)
        _G.MinimapZoneTextButton:SetSize(1, 1)
        if not _G.MinimapZoneTextButton._ktHideHooked then
            hooksecurefunc(_G.MinimapZoneTextButton, "Show", function(frame)
                NukeFrameVisuals(frame, Mod.hiddenFrame)
                frame:EnableMouse(false)
                frame:SetSize(1, 1)
            end)
            _G.MinimapZoneTextButton._ktHideHooked = true
        end
    end
    if cluster and cluster.ZoneTextButton then
        NukeFrameVisuals(cluster.ZoneTextButton, self.hiddenFrame)
        cluster.ZoneTextButton:EnableMouse(false)
        cluster.ZoneTextButton:SetHitRectInsets(0, 0, 0, 0)
        cluster.ZoneTextButton:SetSize(1, 1)
        if not cluster.ZoneTextButton._ktHideHooked then
            hooksecurefunc(cluster.ZoneTextButton, "Show", function(frame)
                NukeFrameVisuals(frame, Mod.hiddenFrame)
                frame:EnableMouse(false)
                frame:SetSize(1, 1)
            end)
            cluster.ZoneTextButton._ktHideHooked = true
        end
    end

    if _G.MiniMapWorldMapButton then
        NukeFrameVisuals(_G.MiniMapWorldMapButton, self.hiddenFrame)
        _G.MiniMapWorldMapButton:EnableMouse(false)
        _G.MiniMapWorldMapButton:SetHitRectInsets(0, 0, 0, 0)
        _G.MiniMapWorldMapButton:SetSize(1, 1)
        if not _G.MiniMapWorldMapButton._ktHideHooked then
            hooksecurefunc(_G.MiniMapWorldMapButton, "Show", function(frame)
                NukeFrameVisuals(frame, Mod.hiddenFrame)
                frame:EnableMouse(false)
                frame:SetSize(1, 1)
            end)
            _G.MiniMapWorldMapButton._ktHideHooked = true
        end
    end

    if _G.TimeManagerClockButton then
        NukeFrameVisuals(_G.TimeManagerClockButton, self.hiddenFrame)
    end
    if _G.MinimapZoneText then
        _G.MinimapZoneText:Hide()
    end

end

function Mod:SuppressLegacyMinimapStats()
    local legacyFrames = {
        _G.MinimapStats_TimeFrame,
        _G.MinimapStats_SystemStatsFrame,
        _G.MinimapStats_LocationFrame,
        _G.MinimapStats_CoordinatesFrame,
        _G.MinimapStats_InstanceDifficultyFrame,
        _G.KT_MinimapCoordsWhite,
    }

    for _, frame in ipairs(legacyFrames) do
        SafeHideFrame(frame, self.hiddenFrame)
        if frame then
            frame.Show = function() end
            frame:SetAlpha(0)
        end
    end

end

function Mod:GetOptions()
    return {
        type = "group",
        name = "Minimap",
        order = 90,
        get = function(info)
            return self.db[info[#info]]
        end,
        set = function(info, value)
            self.db[info[#info]] = value
            self:Refresh()
        end,
        args = {
            header = {
                type = "header",
                name = "Minimap",
                order = 1,
            },
            showZone = {
                type = "toggle",
                name = "Mostrar texto de zona",
                order = 2,
            },
            zoneOffsetX = {
                type = "range",
                name = "Zona X",
                min = -300,
                max = 300,
                step = 1,
                order = 3,
            },
            zoneOffsetY = {
                type = "range",
                name = "Zona Y",
                min = -100,
                max = 100,
                step = 1,
                order = 4,
            },
        },
    }
end

function Mod:OnDisable()
    if self._dynamicStatsTicker and self._dynamicStatsTicker.Cancel then
        self._dynamicStatsTicker:Cancel()
    end
    self._dynamicStatsTicker = nil
end
