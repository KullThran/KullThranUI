-- Modules/BuffsAndDebuffs/BuffsAndDebuffs.lua
local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("BuffsAndDebuffs", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)
local PP = KT and KT.PP
local AK = _G.KTAuraKit

local _G = _G
local CreateFrame = CreateFrame
local ipairs = ipairs
local floor = math.floor
local max = math.max
local min = math.min
local type = type
local wipe = wipe
local unpack = unpack or table.unpack
local C_Timer = C_Timer

local hooksecurefunc = hooksecurefunc
local InCombatLockdown = _G.InCombatLockdown
local issecretvalue = _G.issecretvalue
local canaccessvalue = _G.canaccessvalue

local function IsAccessibleValue(value)
    if value == nil then
        return true
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then
            return false
        end
    end
    if canaccessvalue then
        local ok, accessible = pcall(canaccessvalue, value)
        if not ok or not accessible then
            return false
        end
    end
    return true
end

local function IsAccessibleNumber(value)
    return IsAccessibleValue(value) and type(value) == 'number'
end

local function CaptureMethodValues(object, method, ...)
    if not (object and type(method) == 'function') then
        return nil
    end

    local values = { pcall(method, object, ...) }
    if not values[1] then
        return nil
    end
    table.remove(values, 1)
    for index = 1, #values do
        if not IsAccessibleValue(values[index]) then
            return nil
        end
    end
    return values
end

local SMP = "Interface\\AddOns\\KullThranUI\\Modules\\SimplicityTextures\\"
local SHAPE_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local SIMPLICITY_ICON_INSET = 2
local SIMPLICITY_CHROME_OUTSET = 3
local SHAPE_MASKS = {
    CIRCLE = SHAPE_MEDIA .. "circle_mask.tga",
    CSQUARE = SHAPE_MEDIA .. "csquare_mask.tga",
    HEXAGON = SHAPE_MEDIA .. "hexagon_mask.tga",
    DIAMOND = SHAPE_MEDIA .. "diamond_mask.tga",
    SHIELD = SHAPE_MEDIA .. "shield_mask.tga",
}

local SHAPE_BORDERS = {
    CIRCLE = SHAPE_MEDIA .. "circle_border.tga",
    CSQUARE = SHAPE_MEDIA .. "csquare_border.tga",
    HEXAGON = SHAPE_MEDIA .. "hexagon_border.tga",
    DIAMOND = SHAPE_MEDIA .. "diamond_border.tga",
    SHIELD = SHAPE_MEDIA .. "shield_border.tga",
}

local _auraCooldownPending = {}
local _auraCooldownTimerScheduled = false

local function FlushAuraCooldownShapes()
    _auraCooldownTimerScheduled = false
    for cooldown, button in pairs(_auraCooldownPending) do
        if cooldown and button and not (cooldown.IsForbidden and cooldown:IsForbidden()) then
            local shape = Mod.db and Mod.db.shape or "NONE"
            local maskPath = SHAPE_MASKS[shape]
            local masks = button.KT_ShapeMasks
            local mask = masks and masks[1]
            if maskPath and mask then
                if cooldown.RemoveMaskTexture then pcall(cooldown.RemoveMaskTexture, cooldown, mask) end
                if cooldown.AddMaskTexture then pcall(cooldown.AddMaskTexture, cooldown, mask) end
                if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, true) end
                if cooldown.SetUseCircularEdge then pcall(cooldown.SetUseCircularEdge, cooldown, shape ~= "CSQUARE") end
                if cooldown.SetSwipeTexture and cooldown.KT_KUISwipeTexture ~= maskPath then
                pcall(cooldown.SetSwipeTexture, cooldown, maskPath)
                cooldown.KT_KUISwipeTexture = maskPath
            end
            else
                if mask and cooldown.RemoveMaskTexture then pcall(cooldown.RemoveMaskTexture, cooldown, mask) end
                if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, false) end
                if cooldown.SetUseCircularEdge then pcall(cooldown.SetUseCircularEdge, cooldown, false) end
                if cooldown.SetSwipeTexture then pcall(cooldown.SetSwipeTexture, cooldown, "") end
            cooldown.KT_KUISwipeTexture = nil
            end
        end
    end
    wipe(_auraCooldownPending)
end

local function HookAuraCooldown(button)
    local cooldown = GetCooldownFrame(button)
    if not cooldown or cooldown.KT_KUIShapeCooldownHooked then
        return
    end

    cooldown.KT_KUIShapeCooldownHooked = true
    cooldown.KT_KUIShapeButton = button
    hooksecurefunc(cooldown, "SetCooldown", function()
        cooldown.KT_KUISwipeTexture = nil
        _auraCooldownPending[cooldown] = button
        if not _auraCooldownTimerScheduled then
            _auraCooldownTimerScheduled = true
            C_Timer.After(0, FlushAuraCooldownShapes)
        end
    end)
end
local CUSTOM_BUFF_STYLE_KEY = "ktbad:player-buffs"
local CUSTOM_BUFF_GROUP_KEY = "playerBuffs"
local CUSTOM_BUFF_MAX_COUNT = 40
local CUSTOM_DEBUFF_STYLE_KEY = "ktbad:player-debuffs"
local CUSTOM_DEBUFF_GROUP_KEY = "playerDebuffs"
local CUSTOM_DEBUFF_MAX_COUNT = 32
local CUSTOM_POSITION_MIGRATION_VERSION = 3
local DEFAULT_MINIMAP_HORIZONTAL_GAP = 40
local DEFAULT_BUFF_MINIMAP_TOP_OFFSET = 74
local DEFAULT_AURA_VERTICAL_GAP = 54

local DEFAULT_DB = {
    enable = true,
    style = "BLIZZARD",
    shape = "NONE",
    durationFont = "AAA_ITC_Avant_Garde",
    durationFontSize = 11,
    durationFontOutline = "OUTLINE",
    durationXOffset = 0,
    durationYOffset = -2,
    countFont = "AAA_ITC_Avant_Garde",
    countFontSize = 12,
    countFontOutline = "OUTLINE",
    countXOffset = 2,
    countYOffset = 2,
    buffs = { size = 40, spacing = 2, perRow = 12, growDir = "LEFT" },
    debuffs = { size = 44, spacing = 2, perRow = 10, growDir = "LEFT" },
}

local function CopyDefaults(dst, src)
    if type(dst) ~= "table" then
        dst = {}
    end

    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = CopyDefaults(dst[key], value)
        elseif dst[key] == nil then
            dst[key] = value
        end
    end

    return dst
end

local function ClampNumber(value, minValue, maxValue, fallback)
    local num = tonumber(value)
    if not num then
        num = tonumber(fallback)
    end
    if not num then
        num = minValue or maxValue or 0
    end
    if minValue ~= nil and num < minValue then
        num = minValue
    end
    if maxValue ~= nil and num > maxValue then
        num = maxValue
    end
    return num
end

local function PPPoint(frame, point, relativeTo, relativePoint, x, y)
    if not frame then
        return
    end
    if PP and PP.Point then
        PP.Point(frame, point, relativeTo, relativePoint, x, y)
    else
        frame:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    end
end

local function PPSize(frame, width, height)
    if not frame then
        return
    end
    if PP and PP.Size then
        PP.Size(frame, width, height)
    else
        frame:SetSize(width or 0, height or 0)
    end
end

local function ForEachChild(container, fn)
    if not container or type(fn) ~= "function" then
        return
    end

    if container.EnumerateChildren then
        for child in container:EnumerateChildren() do
            fn(child)
        end
        return
    end

    for _, child in ipairs({ container:GetChildren() }) do
        fn(child)
    end
end

local function GetCooldownFrame(button)
    if not button then
        return nil
    end
    if button.Cooldown then
        return button.Cooldown
    end
    if button.GetName then
        local name = button:GetName()
        if name then
            return _G[name .. "Cooldown"]
        end
    end
    return nil
end

local function IsEditModeActive()
    local frame = _G.EditModeManagerFrame
    return frame and frame.IsEditModeActive and frame:IsEditModeActive()
end

local function ShouldPreserveNativeAuraLayout(self)
    return self and self.db and (self.db.style or "BLIZZARD") == "BLIZZARD"
end

local function BuildAuraOrderMap(isDebuff)
    -- 12.1: raw player-aura enumeration by slot or index is forbidden once
    -- Blizzard marks the container secret. The visible AuraButton pool already
    -- carries a stable native ID, used by GetButtonAuraOrder below.
    return nil
end

local function GetButtonAuraOrder(button, orderMap)
    local auraData = button and button.auraData
    local auraInstanceID = auraData and auraData.auraInstanceID
    if auraInstanceID and orderMap and orderMap[auraInstanceID] then
        return orderMap[auraInstanceID]
    end

    if button and button.tempEnchantIndex then
        return -10 + button.tempEnchantIndex
    end

    return (button and button.GetID and button:GetID()) or 0
end

local function GetAuraColor(button, isDebuff)
    if not isDebuff then
        return 0, 0, 0
    end

    local auraData = button and button.auraData
    local dispelName = auraData and auraData.dispelName
    local color = dispelName and _G.DebuffTypeColor and _G.DebuffTypeColor[dispelName]
    if color then
        return color.r or 1, color.g or 0, color.b or 0
    end

    return 0.8, 0, 0
end

local function FetchFont(fontName)
    if LSM and LSM.Fetch then
        return LSM:Fetch("font", fontName or "AAA_ITC_Avant_Garde")
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function EnsureTextOverlayHost(button)
    if not button then
        return nil
    end

    local host = button.KT_TextOverlayHost
    if not host then
        host = CreateFrame("Frame", nil, button)
        host:SetAllPoints(button)
        if host.EnableMouse then
            host:EnableMouse(false)
        end
        button.KT_TextOverlayHost = host
    end

    host:Show()
    local level = (button.GetFrameLevel and button:GetFrameLevel() or 0) + 10
    local cooldown = GetCooldownFrame(button)
    if cooldown and cooldown.GetFrameLevel then
        level = max(level, (cooldown:GetFrameLevel() or 0) + 2)
    end
    host:SetFrameLevel(level)
    return host
end

local function CaptureRegionState(region)
    if not region then return nil end
    local state = {
        points = {},
    }
    local parent = CaptureMethodValues(region, region.GetParent)
    local shown = CaptureMethodValues(region, region.IsShown)
    local alpha = CaptureMethodValues(region, region.GetAlpha)
    state.parent = parent and parent[1] or nil
    state.shown = shown and shown[1] or nil
    state.alpha = alpha and alpha[1] or nil

    if region.GetNumPoints and region.GetPoint then
        local pointCount = CaptureMethodValues(region, region.GetNumPoints)
        pointCount = pointCount and pointCount[1] or nil
        if IsAccessibleNumber(pointCount) then
            for index = 1, pointCount do
                local point = CaptureMethodValues(region, region.GetPoint, index)
                if point then
                    state.points[#state.points + 1] = {
                        point = point[1],
                        relativeTo = point[2],
                        relativePoint = point[3],
                        x = point[4],
                        y = point[5],
                    }
                end
            end
        end
    end
    state.texCoord = CaptureMethodValues(region, region.GetTexCoord)
    state.drawLayer = CaptureMethodValues(region, region.GetDrawLayer)
    state.font = CaptureMethodValues(region, region.GetFont)
    return state
end

local function RestoreRegionState(region, state)
    if not (region and state) then return end
    if state.parent and region.SetParent and region:GetParent() ~= state.parent then
        region:SetParent(state.parent)
    end
    if region.ClearAllPoints and region.SetPoint and #state.points > 0 then
        region:ClearAllPoints()
        for _, point in ipairs(state.points) do
            region:SetPoint(point.point, point.relativeTo, point.relativePoint, point.x, point.y)
        end
    end
    if state.texCoord and region.SetTexCoord then region:SetTexCoord(unpack(state.texCoord)) end
    if state.drawLayer and region.SetDrawLayer then region:SetDrawLayer(unpack(state.drawLayer)) end
    if state.font and state.font[1] and region.SetFont then region:SetFont(unpack(state.font)) end
    if state.alpha ~= nil and region.SetAlpha then region:SetAlpha(state.alpha) end
    if state.shown ~= nil then
        if state.shown and region.Show then region:Show() elseif region.Hide then region:Hide() end
    end
end

local function CaptureNativeAuraState(button)
    if not button or button.KT_NativeAuraState then return end
    local size = CaptureMethodValues(button, button.GetSize)
    local width, height = size and size[1], size and size[2]
    local state = { width = width, height = height, regions = {} }
    state.icon = CaptureRegionState(button.Icon)
    state.cooldown = CaptureRegionState(GetCooldownFrame(button))
    state.count = CaptureRegionState(button.Count)
    state.duration = CaptureRegionState(button.Duration)
    for _, key in ipairs({ "Border", "DebuffBorder", "TempEnchantBorder", "Symbol", "Stealable" }) do
        state.regions[key] = CaptureRegionState(button[key])
    end
    state.normal = CaptureRegionState(button.GetNormalTexture and button:GetNormalTexture())
    button.KT_NativeAuraState = state
    if IsAccessibleNumber(width) and width > 0 and IsAccessibleNumber(height) and height > 0 then
        button.KT_NativeWidth, button.KT_NativeHeight = width, height
    end
end

local function CanSafelySkinAuraButton(button)
    if not button then
        return false
    end

    local size = CaptureMethodValues(button, button.GetSize)
    if not (size and IsAccessibleNumber(size[1]) and IsAccessibleNumber(size[2])) then
        return false
    end

    local regions = {
        button.Icon,
        GetCooldownFrame(button),
        button.Count,
        button.Duration,
        button.Border,
        button.DebuffBorder,
        button.TempEnchantBorder,
        button.Symbol,
        button.Stealable,
        button.GetNormalTexture and button:GetNormalTexture(),
    }

    for _, region in pairs(regions) do
        if region and region.GetNumPoints then
            local pointCount = CaptureMethodValues(region, region.GetNumPoints)
            if not (pointCount and IsAccessibleNumber(pointCount[1])) then
                return false
            end
        end
    end

    return true
end

local function RestoreNativeAuraState(button)
    local state = button and button.KT_NativeAuraState
    if not state then return end
    RestoreRegionState(button.Icon, state.icon)
    RestoreRegionState(GetCooldownFrame(button), state.cooldown)
    RestoreRegionState(button.Count, state.count)
    RestoreRegionState(button.Duration, state.duration)
    for key, regionState in pairs(state.regions) do RestoreRegionState(button[key], regionState) end
    RestoreRegionState(button.GetNormalTexture and button:GetNormalTexture(), state.normal)
    if button.KT_TextOverlayHost then button.KT_TextOverlayHost:Hide() end
end

local function PromoteAuraText(button, textObj)
    if not button or not textObj or type(textObj.SetParent) ~= "function" then
        return
    end

    local host = EnsureTextOverlayHost(button)
    if not host then
        return
    end

    if textObj.GetParent and textObj:GetParent() ~= host then
        textObj:SetParent(host)
    end

    if textObj.SetDrawLayer then
        textObj:SetDrawLayer("OVERLAY", 7)
    end
end

local function SetRegionVisible(region, visible)
    if not region then
        return
    end

    if region.SetAlpha then
        region:SetAlpha(visible and 1 or 0)
    end
    if visible then
        if region.Show then
            region:Show()
        end
    else
        if region.Hide then
            region:Hide()
        end
    end
end

local function SetNativeAuraChromeVisible(button, visible)
    if not button then
        return
    end

    SetRegionVisible(button.Border, visible)
    SetRegionVisible(button.DebuffBorder, visible)
    SetRegionVisible(button.TempEnchantBorder, visible)
    SetRegionVisible(button.Symbol, visible)
    SetRegionVisible(button.Stealable, visible)

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    SetRegionVisible(normal, visible)
end

local function GetShapeMaskTargets(button)
    local targets = {}
    if button and button.Icon then
        targets[#targets + 1] = button.Icon
    end

    local cooldown = GetCooldownFrame(button)
    if cooldown then
        targets[#targets + 1] = cooldown
    end

    return targets
end

local function ClearShapeMasks(button)
    if not button then
        return
    end

    local cooldown = GetCooldownFrame(button)
    local function ClearCooldownSwipe()
        if cooldown then
            if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, false) end
            if cooldown.SetSwipeTexture then pcall(cooldown.SetSwipeTexture, cooldown, "") end
            cooldown.KT_KUISwipeTexture = nil
            if cooldown.SetUseCircularEdge then pcall(cooldown.SetUseCircularEdge, cooldown, false) end
        end
    end

    if not button.KT_ShapeMasks then
        ClearCooldownSwipe()
        return
    end

    local targets = GetShapeMaskTargets(button)
    for _, mask in ipairs(button.KT_ShapeMasks) do
        for _, target in ipairs(targets) do
            if target and target.RemoveMaskTexture then
                pcall(target.RemoveMaskTexture, target, mask)
            end
        end
        mask:Hide()
    end
    wipe(button.KT_ShapeMasks)
    button.KT_ShapeMaskPath = nil
    ClearCooldownSwipe()
end

local function DetachBuiltInMasks(button)
    local icon = button and button.Icon
    if not icon or not icon.RemoveMaskTexture then
        return
    end

    for _, mask in ipairs({ button.IconMask, button.iconMask }) do
        if mask then
            pcall(icon.RemoveMaskTexture, icon, mask)
            mask:Hide()
        end
    end
end

local function RestoreBuiltInMasks(button)
    local icon = button and button.Icon
    if not icon then
        return
    end

    for _, mask in ipairs({ button.IconMask, button.iconMask }) do
        if mask then
            if icon.RemoveMaskTexture then
                pcall(icon.RemoveMaskTexture, icon, mask)
            end
            if icon.AddMaskTexture then
                pcall(icon.AddMaskTexture, icon, mask)
            end
            mask:Show()
        end
    end
end

local function ApplyShapeMask(button, shape)
    local maskPath = shape and SHAPE_MASKS[shape]
    if not button or not maskPath or not button.CreateMaskTexture then
        return
    end

    local targets = GetShapeMaskTargets(button)
    local cooldown = GetCooldownFrame(button)
    local function RefreshCooldownSwipe()
        if cooldown then
            if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, true) end
            if cooldown.SetUseCircularEdge then pcall(cooldown.SetUseCircularEdge, cooldown, shape ~= "CSQUARE") end
            if cooldown.SetSwipeTexture and cooldown.KT_KUISwipeTexture ~= maskPath then
                pcall(cooldown.SetSwipeTexture, cooldown, maskPath)
                cooldown.KT_KUISwipeTexture = maskPath
            end
        end
    end
    if #targets == 0 then
        return
    end

    button.KT_ShapeMasks = button.KT_ShapeMasks or {}

    if #button.KT_ShapeMasks > 0 then
        for _, mask in ipairs(button.KT_ShapeMasks) do
            if button.KT_ShapeMaskPath ~= maskPath then
                mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                button.KT_ShapeMaskPath = maskPath
            end
            mask:ClearAllPoints()
            mask:SetAllPoints(button.Icon or button)
            mask:Show()
        end
        RefreshCooldownSwipe()
        return
    end

    local mask = button:CreateMaskTexture()
    mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    button.KT_ShapeMaskPath = maskPath
    mask:SetAllPoints(button.Icon or button)

    local applied = false
    for _, target in ipairs(targets) do
        if target and target.AddMaskTexture and pcall(target.AddMaskTexture, target, mask) then
            applied = true
        end
    end

    if applied then
        button.KT_ShapeMasks[#button.KT_ShapeMasks + 1] = mask
        RefreshCooldownSwipe()
    else
        mask:Hide()
    end
end

local function HideShapeBorder(button)
    if button and button.KT_ShapeBorder then
        button.KT_ShapeBorder:Hide()
    end
end

local function HideCustomChrome(button)
    if not button then
        return
    end

    if button.KT_Backdrop then
        button.KT_Backdrop:Hide()
    end
    if button.KT_SMP_Backdrop then
        button.KT_SMP_Backdrop:Hide()
    end
    if button.KT_SMP_Normal then
        button.KT_SMP_Normal:Hide()
    end
    if button.KT_SMP_Border then
        button.KT_SMP_Border:Hide()
    end
    HideShapeBorder(button)
end

function Mod:ApplyButtonTextLayout(button)
    if not (button and self.db) then
        return
    end

    if button.Count then
        PromoteAuraText(button, button.Count)
        button.Count:ClearAllPoints()
        PPPoint(button.Count, "TOPRIGHT", button, "TOPRIGHT", self.db.countXOffset or 2, self.db.countYOffset or 2)
        button.Count:SetFont(
            FetchFont(self.db.countFont),
            self.db.countFontSize or 12,
            self.db.countFontOutline or "OUTLINE"
        )
    end

    if button.Duration then
        PromoteAuraText(button, button.Duration)
        button.Duration:ClearAllPoints()
        PPPoint(button.Duration, "TOP", button, "BOTTOM", self.db.durationXOffset or 0, self.db.durationYOffset or -2)
        button.Duration:SetFont(
            FetchFont(self.db.durationFont),
            self.db.durationFontSize or 11,
            self.db.durationFontOutline or "OUTLINE"
        )
    end
end

function Mod:ApplyKUIStyle(button)
    if not button.KT_Backdrop then
        -- BackdropTemplate recalculates UVs from GetSize(). Aura buttons can
        -- expose secret dimensions in restricted combat, which makes
        -- SharedXML/Backdrop.lua perform forbidden arithmetic. Build the same
        -- one-pixel chrome from anchored textures; no Lua size read is needed.
        local bd = CreateFrame("Frame", nil, button)
        bd:SetFrameLevel(max(0, (button:GetFrameLevel() or 1) - 1))

        local bg = bd:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(bd)
        bg:SetColorTexture(0, 0, 0, 0.5)
        bd.KT_Background = bg

        local edges = {}
        for i = 1, 4 do
            local edge = bd:CreateTexture(nil, "BORDER")
            edge:SetColorTexture(0, 0, 0, 1)
            edges[i] = edge
        end
        edges[1]:SetPoint("TOPLEFT", bd, "TOPLEFT", 0, 0)
        edges[1]:SetPoint("TOPRIGHT", bd, "TOPRIGHT", 0, 0)
        edges[1]:SetHeight(1)
        edges[2]:SetPoint("BOTTOMLEFT", bd, "BOTTOMLEFT", 0, 0)
        edges[2]:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", 0, 0)
        edges[2]:SetHeight(1)
        edges[3]:SetPoint("TOPLEFT", bd, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMLEFT", bd, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(1)
        edges[4]:SetPoint("TOPRIGHT", bd, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(1)
        bd.KT_Edges = edges
        function bd:SetBorderColor(r, g, b, a)
            for i = 1, 4 do
                self.KT_Edges[i]:SetColorTexture(r, g, b, a)
            end
        end
        button.KT_Backdrop = bd
    end

    button.KT_Backdrop:ClearAllPoints()
    PPPoint(button.KT_Backdrop, "TOPLEFT", button.Icon or button, "TOPLEFT", -1, 1)
    PPPoint(button.KT_Backdrop, "BOTTOMRIGHT", button.Icon or button, "BOTTOMRIGHT", 1, -1)
    button.KT_Backdrop:Show()

    if button.KT_SMP_Backdrop then
        button.KT_SMP_Backdrop:Hide()
    end
    if button.KT_SMP_Normal then
        button.KT_SMP_Normal:Hide()
    end
    if button.KT_SMP_Border then
        button.KT_SMP_Border:Hide()
    end
end

function Mod:ApplySimplicityStyle(button)
    local icon = button.Icon or button
    local offset = SIMPLICITY_CHROME_OUTSET

    if not button.KT_SMP_Backdrop then
        local tex = button:CreateTexture(nil, "BACKGROUND", nil, -5)
        tex:SetTexture(SMP .. "Backdrop.tga")
        tex:SetBlendMode("BLEND")
        button.KT_SMP_Backdrop = tex
    end
    button.KT_SMP_Backdrop:ClearAllPoints()
    PPPoint(button.KT_SMP_Backdrop, "TOPLEFT", icon, "TOPLEFT", -offset, offset)
    PPPoint(button.KT_SMP_Backdrop, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
    button.KT_SMP_Backdrop:SetVertexColor(1, 1, 1, 1)
    button.KT_SMP_Backdrop:Show()

    if not button.KT_SMP_Normal then
        local tex = button:CreateTexture(nil, "OVERLAY", nil, 0)
        tex:SetTexture(SMP .. "Normal.tga")
        tex:SetBlendMode("BLEND")
        button.KT_SMP_Normal = tex
    end
    button.KT_SMP_Normal:ClearAllPoints()
    PPPoint(button.KT_SMP_Normal, "TOPLEFT", icon, "TOPLEFT", -offset, offset)
    PPPoint(button.KT_SMP_Normal, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
    button.KT_SMP_Normal:SetVertexColor(0.125, 0.125, 0.125, 1)
    button.KT_SMP_Normal:Show()

    if not button.KT_SMP_Border then
        local tex = button:CreateTexture(nil, "OVERLAY", nil, 1)
        tex:SetTexture(SMP .. "Border.tga")
        tex:SetBlendMode("ADD")
        button.KT_SMP_Border = tex
    end
    button.KT_SMP_Border:ClearAllPoints()
    PPPoint(button.KT_SMP_Border, "TOPLEFT", icon, "TOPLEFT", -offset, offset)
    PPPoint(button.KT_SMP_Border, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
    button.KT_SMP_Border:SetVertexColor(1, 1, 1, 0.1)
    button.KT_SMP_Border:Show()

    for _, texture in ipairs({ button.KT_SMP_Backdrop, button.KT_SMP_Normal, button.KT_SMP_Border }) do
        if PP and PP.DisablePixelSnap then
            PP.DisablePixelSnap(texture)
        end
    end

    if button.KT_Backdrop then
        button.KT_Backdrop:Hide()
    end
end
function Mod:ApplyShapeBorder(button, shape)
    local borderTex = shape and SHAPE_BORDERS[shape]
    if not borderTex then
        HideShapeBorder(button)
        return
    end

    if not button.KT_ShapeBorder then
        button.KT_ShapeBorder = button:CreateTexture(nil, "OVERLAY", nil, 1)
    end

    button.KT_ShapeBorder:SetTexture(borderTex)
    button.KT_ShapeBorder:ClearAllPoints()
    PPPoint(button.KT_ShapeBorder, "TOPLEFT", button.Icon or button, "TOPLEFT", -1, 1)
    PPPoint(button.KT_ShapeBorder, "BOTTOMRIGHT", button.Icon or button, "BOTTOMRIGHT", 1, -1)
    button.KT_ShapeBorder:Show()
    if PP and PP.DisablePixelSnap then
        PP.DisablePixelSnap(button.KT_ShapeBorder)
    end

    if button.KT_Backdrop then
        button.KT_Backdrop:Hide()
    end
    if button.KT_SMP_Backdrop then
        button.KT_SMP_Backdrop:Hide()
    end
    if button.KT_SMP_Normal then
        button.KT_SMP_Normal:Hide()
    end
    if button.KT_SMP_Border then
        button.KT_SMP_Border:Hide()
    end
end

function Mod:UpdateAuraColors(button, isDebuff)
    local r, g, b = GetAuraColor(button, isDebuff)

    if self.db.style == "BLIZZARD" then
        if button.DebuffBorder then
            button.DebuffBorder:SetVertexColor(r, g, b, 1)
        elseif button.Border then
            button.Border:SetVertexColor(r, g, b, 1)
        end
        return
    end

    if (self.db.shape or "NONE") ~= "NONE" and button.KT_ShapeBorder then
        button.KT_ShapeBorder:SetVertexColor(r, g, b, 1)
    elseif self.db.style == "KUI" and button.KT_Backdrop then
        button.KT_Backdrop:SetBorderColor(r, g, b, 1)
    elseif self.db.style == "SIMPLICITY" then
        if button.KT_SMP_Normal then
            button.KT_SMP_Normal:SetVertexColor(0.125, 0.125, 0.125, 1)
        end
        if button.KT_SMP_Border then
            button.KT_SMP_Border:SetVertexColor(1, 1, 1, 0.1)
        end
    end
end

function Mod:ApplyBlizzardStyle(button, isDebuff)
    local icon = button.Icon
    local cooldown = GetCooldownFrame(button)

    ClearShapeMasks(button)
    button.KT_AppliedShape = nil
    RestoreBuiltInMasks(button)
    HideCustomChrome(button)
    SetNativeAuraChromeVisible(button, true)

    icon:ClearAllPoints()
    icon:SetAllPoints(button)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetDrawLayer("ARTWORK", 0)
    icon:SetVertexColor(1, 1, 1, 1)
    icon:SetAlpha(1)
    if icon.SetDesaturated then
        icon:SetDesaturated(false)
    end

    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(button)
    end

    self:UpdateAuraColors(button, isDebuff)
    -- Custom styles reparent and crop several native regions. Restore the exact
    -- Blizzard state captured before KUI touched the button instead of guessing
    -- Blizzard's current template geometry.
    RestoreNativeAuraState(button)
end

function Mod:ApplyCustomStyle(button, isDebuff)
    local icon = button.Icon
    local cooldown = GetCooldownFrame(button)
    local style = self.db.style
    local shape = self.db.shape or "NONE"

    if button.KT_AppliedShape ~= shape then
        ClearShapeMasks(button)
        button.KT_AppliedShape = shape
    end
    DetachBuiltInMasks(button)
    SetNativeAuraChromeVisible(button, false)

    icon:ClearAllPoints()
    if style == "KUI" then
        PPPoint(icon, "TOPLEFT", button, "TOPLEFT", 1, -1)
        PPPoint(icon, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    else
        PPPoint(icon, "TOPLEFT", button, "TOPLEFT", SIMPLICITY_ICON_INSET, -SIMPLICITY_ICON_INSET)
        PPPoint(icon, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -SIMPLICITY_ICON_INSET, SIMPLICITY_ICON_INSET)
    end

    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetDrawLayer("ARTWORK", 0)
    icon:SetVertexColor(1, 1, 1, 1)
    icon:SetAlpha(1)
    if icon.SetDesaturated then
        icon:SetDesaturated(false)
    end

    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(icon)
    end

    if style == "KUI" then
        self:ApplyKUIStyle(button)
    elseif style == "SIMPLICITY" then
        self:ApplySimplicityStyle(button)
    end

    if shape ~= "NONE" then
        ApplyShapeMask(button, shape)
        self:ApplyShapeBorder(button, shape)
    else
        HideShapeBorder(button)
    end

    self:UpdateAuraColors(button, isDebuff)
end

function Mod:SkinButton(button, isDebuff)
    if not (button and button.Icon and self.db) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if not CanSafelySkinAuraButton(button) then
        return
    end

    if button.KT_IsSkinning then return end
    button.KT_IsSkinning = true
    CaptureNativeAuraState(button)

    if not button.KT_AlphaBlinkFixed then
        button.KT_AlphaBlinkFixed = true
        hooksecurefunc(button, "SetAlpha", function(self, a)
            if self.KT_SettingAlpha then return end
            if InCombatLockdown and InCombatLockdown() then return end
            if type(a) == "number" and a < 1 and a > 0 and self:IsShown() and Mod.db and Mod.db.style ~= "BLIZZARD" then
                self.KT_SettingAlpha = true
                self:SetAlpha(1)
                self.KT_SettingAlpha = false
            end
        end)
    end

    if not button.KT_TexCoordFixed and button.Icon then
        button.KT_TexCoordFixed = true
        hooksecurefunc(button.Icon, "SetTexCoord", function(self, left, right, top, bottom)
            if self.KT_SettingTexCoord then return end
            if InCombatLockdown and InCombatLockdown() then return end
            if Mod.db and Mod.db.style ~= "BLIZZARD" then
                self.KT_SettingTexCoord = true
                self:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                self.KT_SettingTexCoord = false
            end
        end)
    end

    if not button.KT_UpdateHooked and type(button.Update) == "function" then
        button.KT_UpdateHooked = true
        hooksecurefunc(button, "Update", function(self)
            if Mod.db and Mod.db.style ~= "BLIZZARD" then
                Mod:SkinButton(self, self.KT_IsDebuff)
            end
        end)
    end

    if not button.KT_ShowHooked and button.HookScript then
        button.KT_ShowHooked = true
        button:HookScript("OnShow", function()
            if Mod and Mod.db and Mod.db.style ~= "BLIZZARD" then
                Mod:ScheduleScan(0.01)
            end
        end)
    end

    if not button.KT_NativeChromeHooked then
        button.KT_NativeChromeHooked = true
        local nativeRegions = {
            button.Border,
            button.DebuffBorder,
            button.TempEnchantBorder,
            button.Symbol,
            button.Stealable,
            button.GetNormalTexture and button:GetNormalTexture(),
        }
        for _, region in ipairs(nativeRegions) do
            if region and type(region.Show) == "function" and not region.KT_BAD_ShowHooked then
                region.KT_BAD_ShowHooked = true
                pcall(hooksecurefunc, region, "Show", function()
                    if Mod and Mod.db and Mod.db.style ~= "BLIZZARD" then
                        Mod:ScheduleScan(0.01)
                    end
                end)
            end
        end
    end

    local layout = isDebuff and self.db.debuffs or self.db.buffs
    local targetSize = ClampNumber(layout and layout.size, 16, 80, isDebuff and 44 or 40)

    button.KT_IsDebuff = isDebuff
    HookAuraCooldown(button)

    if self.db.style == "BLIZZARD" and button.KT_NativeWidth then
        PPSize(button, button.KT_NativeWidth, button.KT_NativeHeight)
    elseif not IsEditModeActive() and not ShouldPreserveNativeAuraLayout(self) then
        -- Aura button dimensions can be secret in restricted combat. Never
        -- compare them in Lua; SetSize accepts the clean configured size and
        -- is harmless when it already matches.
        if not (InCombatLockdown and InCombatLockdown()) then
            PPSize(button, targetSize, targetSize)
        end
    end

    if self.db.style == "BLIZZARD" then
        self:ApplyBlizzardStyle(button, isDebuff)
    else
        self:ApplyButtonTextLayout(button)
        self:ApplyCustomStyle(button, isDebuff)
    end

    button.KT_IsSkinning = false
end

function Mod:GetVisibleAuraButtons(container, isDebuff)
    local visible = {}
    if not container then
        return visible
    end

    ForEachChild(container, function(button)
        if button and button.Icon and button.IsShown and button:IsShown() then
            -- Verify it's an active aura and not an empty pooled frame or collapse arrow
            if button.auraInstanceID or button.tempEnchantIndex or (button.auraData and button.auraData.auraInstanceID) then
                visible[#visible + 1] = button
            elseif button:GetID() and button:GetID() > 0 and button:GetName() and button:GetName():match("BuffButton") then
                -- Pre-DF compatibility fallback
                visible[#visible + 1] = button
            end
        end
    end)

    local auraOrder = BuildAuraOrderMap(isDebuff)
    table.sort(visible, function(a, b)
        local aID = GetButtonAuraOrder(a, auraOrder)
        local bID = GetButtonAuraOrder(b, auraOrder)
        if aID == bID then
            return tostring(a) < tostring(b)
        end
        return aID < bID
    end)

    return visible
end

function Mod:LayoutContainer(container, layout, isDebuff)
    if not container then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    if ShouldPreserveNativeAuraLayout(self) then
        return
    end

    local visible = self:GetVisibleAuraButtons(container, isDebuff)
    if #visible == 0 then
        container:SetSize(1, 1)
        return
    end

    if IsEditModeActive() then
        return
    end

    local size = ClampNumber(layout and layout.size, 16, 80, isDebuff and 44 or 40)
    local spacing = ClampNumber(layout and layout.spacing, 0, 24, 2)
    local perRow = ClampNumber(layout and layout.perRow, 1, 24, isDebuff and 10 or 12)
    local growDir = (layout and layout.growDir) or "LEFT"

    local columns = perRow
    local rows = floor((max(1, #visible) + perRow - 1) / perRow)
    container:SetSize(
        columns * size + max(0, columns - 1) * spacing,
        rows * size + max(0, rows - 1) * spacing
    )

    local anchorPoint = growDir == "RIGHT" and "TOPLEFT" or "TOPRIGHT"
    local xDir = growDir == "RIGHT" and 1 or -1

    for index, button in ipairs(visible) do
        local idx = index - 1
        local col = idx % perRow
        local row = floor(idx / perRow)
        local xOffset = col * (size + spacing) * xDir
        local yOffset = -(row * (size + spacing))

        PPSize(button, size, size)
        button:ClearAllPoints()
        button:SetPoint(anchorPoint, container, anchorPoint, xOffset, yOffset)
    end
end

local function ApplyCustomBuffAuraKitExtras(button, data, style)
    local icon = data and data.icon
    if not (button and data and icon and style) then
        return
    end

    -- This host is created during AuraKit's unrestricted initializer. Future
    -- restyles only anchor owned regions to it, never back to the aura button.
    if not data.KT_BuffIconHost then
        local host = CreateFrame("Frame", nil, button)
        host:SetAllPoints(button)
        host:SetFrameLevel(button:GetFrameLevel())
        host:EnableMouse(false)
        data.KT_BuffIconHost = host
    end
    local host = data.KT_BuffIconHost

    if not data.KT_BuffBackground then
        local texture = button:CreateTexture(nil, "BACKGROUND", nil, -5)
        texture:SetBlendMode("BLEND")
        data.KT_BuffBackground = texture
    end
    if not data.KT_BuffSimplicityNormal then
        local texture = button:CreateTexture(nil, "OVERLAY", nil, 0)
        texture:SetBlendMode("BLEND")
        data.KT_BuffSimplicityNormal = texture
    end
    if not data.KT_BuffSimplicityBorder then
        local texture = button:CreateTexture(nil, "OVERLAY", nil, 1)
        texture:SetBlendMode("ADD")
        data.KT_BuffSimplicityBorder = texture
    end
    if not data.KT_BuffShapeBorder then
        data.KT_BuffShapeBorder = button:CreateTexture(nil, "OVERLAY", nil, 2)
        data.KT_BuffShapeBorder:SetAllPoints(host)
    end

    for _, texture in ipairs({
        data.KT_BuffBackground,
        data.KT_BuffSimplicityNormal,
        data.KT_BuffSimplicityBorder,
        data.KT_BuffShapeBorder,
    }) do
        if PP and PP.DisablePixelSnap then
            PP.DisablePixelSnap(texture)
        end
    end

    local variant = style.KT_Variant or "BLIZZARD"
    local iconInset = 0
    if variant == "KUI" then
        iconInset = 1
    elseif variant == "SIMPLICITY" then
        iconInset = SIMPLICITY_ICON_INSET
    end

    icon:ClearAllPoints()
    PPPoint(icon, "TOPLEFT", host, "TOPLEFT", iconInset, -iconInset)
    PPPoint(icon, "BOTTOMRIGHT", host, "BOTTOMRIGHT", -iconInset, iconInset)
    if data.cooldown then
        data.cooldown:ClearAllPoints()
        data.cooldown:SetAllPoints(icon)
    end

    data.KT_BuffBackground:ClearAllPoints()
    data.KT_BuffSimplicityNormal:ClearAllPoints()
    data.KT_BuffSimplicityBorder:ClearAllPoints()

    if variant == "KUI" then
        data.KT_BuffBackground:SetAllPoints(host)
        data.KT_BuffBackground:SetColorTexture(0, 0, 0, 0.5)
        data.KT_BuffBackground:Show()
        data.KT_BuffSimplicityNormal:Hide()
        data.KT_BuffSimplicityBorder:Hide()
    elseif variant == "SIMPLICITY" then
        local offset = SIMPLICITY_CHROME_OUTSET

        data.KT_BuffBackground:SetTexture(SMP .. "Backdrop.tga")
        data.KT_BuffBackground:SetVertexColor(1, 1, 1, 1)
        PPPoint(data.KT_BuffBackground, "TOPLEFT", icon, "TOPLEFT", -offset, offset)
        PPPoint(data.KT_BuffBackground, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
        data.KT_BuffBackground:Show()

        data.KT_BuffSimplicityNormal:SetTexture(SMP .. "Normal.tga")
        data.KT_BuffSimplicityNormal:SetVertexColor(0.125, 0.125, 0.125, 1)
        PPPoint(data.KT_BuffSimplicityNormal, "TOPLEFT", icon, "TOPLEFT", -offset, offset)
        PPPoint(data.KT_BuffSimplicityNormal, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
        data.KT_BuffSimplicityNormal:Show()

        data.KT_BuffSimplicityBorder:SetTexture(SMP .. "Border.tga")
        data.KT_BuffSimplicityBorder:SetVertexColor(1, 1, 1, 0.1)
        PPPoint(data.KT_BuffSimplicityBorder, "TOPLEFT", icon, "TOPLEFT", -offset, offset)
        PPPoint(data.KT_BuffSimplicityBorder, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
        data.KT_BuffSimplicityBorder:Show()
    else
        data.KT_BuffBackground:Hide()
        data.KT_BuffSimplicityNormal:Hide()
        data.KT_BuffSimplicityBorder:Hide()
    end

    local shape = style.KT_Shape or "NONE"
    local maskPath = SHAPE_MASKS[shape]
    if maskPath then
        if not data.KT_BuffShapeMask then
            data.KT_BuffShapeMask = button:CreateMaskTexture()
            data.KT_BuffShapeMask:SetAllPoints(icon)
        end
        if data.KT_BuffShapeMaskPath ~= maskPath then
            data.KT_BuffShapeMask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            data.KT_BuffShapeMaskPath = maskPath
        end
        data.KT_BuffShapeMask:Show()
        data.KT_BuffShapeMaskTargets = data.KT_BuffShapeMaskTargets or {}
        for _, target in ipairs({ icon, data.cooldown }) do
            if target and target.AddMaskTexture and not data.KT_BuffShapeMaskTargets[target] then
                if pcall(target.AddMaskTexture, target, data.KT_BuffShapeMask) then
                    data.KT_BuffShapeMaskTargets[target] = true
                end
            end
        end

        -- Shape chrome replaces the square KUI/Simplicity chrome.
        data.KT_BuffBackground:Hide()
        data.KT_BuffSimplicityNormal:Hide()
        data.KT_BuffSimplicityBorder:Hide()
        data.KT_BuffShapeBorder:SetTexture(SHAPE_BORDERS[shape])
        data.KT_BuffShapeBorder:SetVertexColor(0, 0, 0, 1)
        data.KT_BuffShapeBorder:Show()
        if data.cooldown then
            if data.cooldown.SetDrawSwipe then pcall(data.cooldown.SetDrawSwipe, data.cooldown, true) end
            if data.cooldown.SetUseCircularEdge then pcall(data.cooldown.SetUseCircularEdge, data.cooldown, shape ~= "CSQUARE") end
            if data.cooldown.SetSwipeTexture and data.cooldown.KT_KUISwipeTexture ~= maskPath then
                pcall(data.cooldown.SetSwipeTexture, data.cooldown, maskPath)
                data.cooldown.KT_KUISwipeTexture = maskPath
            end
        end
    else
        if data.KT_BuffShapeMask and data.KT_BuffShapeMaskTargets then
            for target in pairs(data.KT_BuffShapeMaskTargets) do
                if target and target.RemoveMaskTexture then
                    pcall(target.RemoveMaskTexture, target, data.KT_BuffShapeMask)
                end
            end
            wipe(data.KT_BuffShapeMaskTargets)
        end
        if data.KT_BuffShapeMask then data.KT_BuffShapeMask:Hide() end
        data.KT_BuffShapeMaskPath = nil
        if data.cooldown then
            if data.cooldown.SetDrawSwipe then pcall(data.cooldown.SetDrawSwipe, data.cooldown, false) end
            if data.cooldown.SetSwipeTexture then pcall(data.cooldown.SetSwipeTexture, data.cooldown, "") end
            data.cooldown.KT_KUISwipeTexture = nil
            if data.cooldown.SetUseCircularEdge then pcall(data.cooldown.SetUseCircularEdge, data.cooldown, false) end
        end
        data.KT_BuffShapeBorder:Hide()
    end
end
local WEAPON_ENCHANT_SLOTS = {
    INVSLOT_MAINHAND or 16,
    INVSLOT_OFFHAND or 17,
    INVSLOT_RANGED or 18,
}

local function FormatWeaponEnchantRemaining(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "" end
    if seconds >= 3600 then return string.format("%dh", floor(seconds / 3600 + 0.5)) end
    if seconds >= 60 then return string.format("%dm", floor(seconds / 60 + 0.5)) end
    return tostring(max(0, floor(seconds + 0.5)))
end

local function WeaponEnchantOnEnter(button)
    if not button.KT_WeaponSlot then return end
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetInventoryItem("player", button.KT_WeaponSlot)
end

local function WeaponEnchantOnLeave()
    GameTooltip:Hide()
end

function Mod:EnsureWeaponEnchantButtons()
    if self.weaponEnchantButtons then
        return self.weaponEnchantButtons
    end
    if InCombatLockdown and InCombatLockdown() then
        return nil
    end

    local anchor = self:EnsureCustomBuffAnchor()
    local buttons = {}
    for index, slot in ipairs(WEAPON_ENCHANT_SLOTS) do
        local button = CreateFrame("Button", nil, anchor, "SecureActionButtonTemplate")
        button:SetAttribute("type2", "cancelaura")
        button:SetAttribute("target-slot2", slot)
        button:RegisterForClicks("RightButtonDown", "RightButtonUp")
        button.KT_WeaponSlot = slot

        button.Icon = button:CreateTexture(nil, "ARTWORK")
        button.Icon:SetAllPoints(button)
        button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.Cooldown:SetAllPoints(button)
        button.Cooldown:SetHideCountdownNumbers(true)

        button.TextHost = CreateFrame("Frame", nil, button)
        button.TextHost:SetAllPoints(button)
        button.TextHost:SetFrameLevel(button.Cooldown:GetFrameLevel() + 5)
        button.Duration = button.TextHost:CreateFontString(nil, "OVERLAY")
        button.Count = button.TextHost:CreateFontString(nil, "OVERLAY")
        -- FontStrings throw on SetText until a valid font has been assigned.
        -- Give every pre-warmed slot a base font before any enchant scan.
        local baseFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        button.Duration:SetFont(baseFont, 11, "OUTLINE")
        button.Count:SetFont(baseFont, 12, "OUTLINE")
        button.KT_AuraKitData = { icon = button.Icon, cooldown = button.Cooldown }

        button:SetScript("OnEnter", WeaponEnchantOnEnter)
        button:SetScript("OnLeave", WeaponEnchantOnLeave)
        button:Show()
        button:SetAlpha(0)
        button:EnableMouse(false)
        buttons[index] = button
    end
    self.weaponEnchantButtons = buttons
    return buttons
end

function Mod:ApplyWeaponEnchantStyle(button)
    local style = AK and AK.styles and AK.styles[CUSTOM_BUFF_STYLE_KEY]
    if not (button and style) then
        return
    end

    local size = style.width or DEFAULT_DB.buffs.size
    button:SetSize(size, style.height or size)
    local texCoord = style.texCoord
    if texCoord then
        button.Icon:SetTexCoord(texCoord[1], texCoord[2], texCoord[3], texCoord[4])
    else
        button.Icon:SetTexCoord(0, 1, 0, 1)
    end
    button.Cooldown:SetReverse(style.cooldownReverse ~= false)
    button.Cooldown:SetDrawEdge(style.cooldownDrawEdge == true)

    local fallbackFont = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    button.Duration:SetFont(style.durationFont or fallbackFont,
        style.durationFontSize or 11, style.durationFontFlags or "OUTLINE")
    if not button.Duration:GetFont() then
        button.Duration:SetFont(fallbackFont, style.durationFontSize or 11,
            style.durationFontFlags or "OUTLINE")
    end
    button.Duration:ClearAllPoints()
    button.Duration:SetPoint(style.durationPoint or "TOP", button,
        style.durationRelPoint or "BOTTOM", style.durationX or 0, style.durationY or -2)

    button.Count:SetFont(style.stackFont or fallbackFont,
        style.stackFontSize or 12, style.stackFontFlags or "OUTLINE")
    if not button.Count:GetFont() then
        button.Count:SetFont(fallbackFont, style.stackFontSize or 12,
            style.stackFontFlags or "OUTLINE")
    end
    button.Count:ClearAllPoints()
    local stackPoint = style.stackPoint or "TOPRIGHT"
    button.Count:SetPoint(stackPoint, button, stackPoint, style.stackX or 2, style.stackY or 2)

    if not button.KT_BorderHost then
        button.KT_BorderHost = CreateFrame("Frame", nil, button)
        button.KT_BorderHost:SetAllPoints(button)
        button.KT_BorderHost:SetFrameLevel(button.Cooldown:GetFrameLevel() + 1)
    end
    if style.border and PP then
        if not button.KT_BorderMade then
            PP.CreateBorder(button.KT_BorderHost,
                style.border[1] or 0, style.border[2] or 0,
                style.border[3] or 0, style.border[4] or 1,
                style.border.size or 1)
            button.KT_BorderMade = true
        else
            PP.UpdateBorder(button.KT_BorderHost, style.border.size or 1,
                style.border[1] or 0, style.border[2] or 0,
                style.border[3] or 0, style.border[4] or 1)
        end
        button.KT_BorderHost:Show()
    elseif button.KT_BorderHost then
        button.KT_BorderHost:Hide()
    end

    ApplyCustomBuffAuraKitExtras(button, button.KT_AuraKitData, style)
end

function Mod:ReadWeaponEnchants()
    local infos, count = {}, 0
    local getter = C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo
    if not getter then
        self._weaponEnchantInfos = infos
        self._weaponEnchantCount = 0
        return infos, 0
    end

    for index, slot in ipairs(WEAPON_ENCHANT_SLOTS) do
        local ok, info = pcall(getter, slot)
        info = ok and info or nil
        if info and info.hasExpirationTime then
            count = count + 1
            infos[index] = info
        end
    end
    self._weaponEnchantInfos = infos
    self._weaponEnchantCount = count
    return infos, count
end

function Mod:UpdateWeaponEnchantText()
    local now = GetTime()
    local anyVisible = false
    for _, button in ipairs(self.weaponEnchantButtons or {}) do
        if button:GetAlpha() > 0 then
            anyVisible = true
            button.Duration:SetText(FormatWeaponEnchantRemaining((button.KT_Expiration or 0) - now))
        end
    end
    if not anyVisible and self._weaponEnchantTicker then
        self._weaponEnchantTicker:Cancel()
        self._weaponEnchantTicker = nil
    end
end

function Mod:RefreshWeaponEnchantButtons(contentOnly)
    local infos, count = self:ReadWeaponEnchants()
    local buttons = self.weaponEnchantButtons
    local inCombat = InCombatLockdown and InCombatLockdown()
    if not buttons then
        if inCombat then return count end
        buttons = self:EnsureWeaponEnchantButtons()
    end
    if not buttons then
        return count
    end

    -- Style every pre-warmed slot before SetText, including inactive slots.
    if not inCombat and not contentOnly then
        for _, button in ipairs(buttons) do
            self:ApplyWeaponEnchantStyle(button)
        end
    end

    local packedIndex = 0
    local usedCells = {}
    for index, button in ipairs(buttons) do
        local info = infos[index]
        if info then
            packedIndex = packedIndex + 1
            local remaining = max(0, (tonumber(info.remainingTimeMs) or 0) / 1000)
            button.Icon:SetTexture(GetInventoryItemTexture("player", WEAPON_ENCHANT_SLOTS[index]))
            button.Cooldown:SetCooldown(GetTime(), remaining)
            button.KT_Expiration = GetTime() + remaining
            local charges = tonumber(info.chargesRemaining) or 0
            button.Count:SetText(charges > 1 and tostring(charges) or "")

            if not inCombat and not contentOnly then
                local layout = self.db.buffs or DEFAULT_DB.buffs
                local size = ClampNumber(layout.size, 16, 80, DEFAULT_DB.buffs.size)
                local spacing = ClampNumber(layout.spacing, 0, 24, DEFAULT_DB.buffs.spacing)
                local growDir = layout.growDir or "LEFT"
                local anchorPoint = growDir == "RIGHT" and "TOPLEFT" or "TOPRIGHT"
                local direction = growDir == "RIGHT" and 1 or -1
                -- Keep Blizzard's ordering: main hand is the enchant nearest
                -- the shifted engine aura run, not the outermost icon.
                local cell = count - packedIndex
                button:ClearAllPoints()
                button:SetPoint(anchorPoint, self.customBuffAnchor, anchorPoint,
                    direction * cell * (size + spacing), 0)
                button.KT_WeaponCell = cell
                button.KT_WeaponLayoutActive = true
                button:EnableMouse(true)
            end

            -- Secure buttons cannot move in combat. Only reuse a cell that
            -- belonged to this same active slot in the last OOC layout, and
            -- never let two changed slots paint into the same frozen cell.
            local cell = button.KT_WeaponCell
            local hasSafeCell = not inCombat or (button.KT_WeaponLayoutActive == true
                and cell ~= nil and not usedCells[cell])
            if inCombat and hasSafeCell then usedCells[cell] = true end
            button:SetAlpha(hasSafeCell and 1 or 0)
        else
            button:SetAlpha(0)
            button.KT_Expiration = nil
            button.Duration:SetText("")
            button.Count:SetText("")
            if not inCombat then
                button:EnableMouse(false)
                button.KT_WeaponCell = nil
                button.KT_WeaponLayoutActive = false
            end
        end
    end
    if not inCombat and not contentOnly then
        self._weaponEnchantLayoutCount = count
    end

    if count > 0 and not self._weaponEnchantTicker and C_Timer and C_Timer.NewTicker then
        self._weaponEnchantTicker = C_Timer.NewTicker(0.5, function()
            if Mod and Mod.UpdateWeaponEnchantText then
                Mod:UpdateWeaponEnchantText()
            end
        end)
    elseif count == 0 and self._weaponEnchantTicker then
        self._weaponEnchantTicker:Cancel()
        self._weaponEnchantTicker = nil
    end
    self:UpdateWeaponEnchantText()
    return count
end

function Mod:HandleWeaponEnchantEvent()
    local previous = self._weaponEnchantCount or 0
    local inCombat = InCombatLockdown and InCombatLockdown()
    local count = self:RefreshWeaponEnchantButtons(inCombat)
    if count ~= previous then
        self._customBuffLayoutDirty = true
    end
    if not inCombat then
        self:ApplyCustomBuffLayout()
    end
end
function Mod:ConfigureCustomBuffStyle()
    if not (AK and self.db) then
        return
    end

    local layout = self.db.buffs or DEFAULT_DB.buffs
    local size = ClampNumber(layout.size, 16, 80, DEFAULT_DB.buffs.size)
    local variant = self.db.style or "BLIZZARD"
    local shape = variant ~= "BLIZZARD" and (self.db.shape or "NONE") or "NONE"
    local border
    if variant == "KUI" and shape == "NONE" then
        border = { 0, 0, 0, 1, size = 1 }
    end

    AK.styles[CUSTOM_BUFF_STYLE_KEY] = {
        width = size,
        height = size,
        texCoord = variant == "BLIZZARD" and { 0, 1, 0, 1 } or { 0.08, 0.92, 0.08, 0.92 },
        border = border,
        cooldownReverse = true,
        cooldownDrawEdge = false,
        -- Distinguish short durations from application counts when both values match.
        durationShowSeconds = true,
        noTooltips = false,
        cancelButtons = "RightButtonUp",
        durationFont = FetchFont(self.db.durationFont),
        durationFontSize = ClampNumber(self.db.durationFontSize, 8, 24, 11),
        durationFontFlags = self.db.durationFontOutline or "OUTLINE",
        durationPoint = "TOP",
        durationRelPoint = "BOTTOM",
        durationX = ClampNumber(self.db.durationXOffset, -20, 20, 0),
        durationY = ClampNumber(self.db.durationYOffset, -20, 20, -2),
        stackFont = FetchFont(self.db.countFont),
        stackFontSize = ClampNumber(self.db.countFontSize, 8, 24, 12),
        stackFontFlags = self.db.countFontOutline or "OUTLINE",
        stackPoint = "TOPRIGHT",
        stackX = ClampNumber(self.db.countXOffset, -20, 20, 2),
        stackY = ClampNumber(self.db.countYOffset, -20, 20, 2),
        KT_Variant = variant,
        KT_Shape = shape,
        applyExtra = ApplyCustomBuffAuraKitExtras,
    }
end

local function BuildDefaultAuraPosition(db, isDebuff)
    if not (_G.Minimap and UIParent) then
        return nil
    end

    local yOffset = DEFAULT_BUFF_MINIMAP_TOP_OFFSET
    if isDebuff then
        local buffLayout = db and db.buffs or DEFAULT_DB.buffs
        local buffSize = ClampNumber(buffLayout and buffLayout.size, 16, 80, DEFAULT_DB.buffs.size)
        yOffset = yOffset + buffSize + DEFAULT_AURA_VERTICAL_GAP
    end

    return {
        point = "TOPRIGHT",
        relativeTo = "Minimap",
        relativePoint = "TOPLEFT",
        xOfs = -DEFAULT_MINIMAP_HORIZONTAL_GAP,
        yOfs = -yOffset,
        anchorMode = "manual",
        automaticPosition = true,
        seededFromDefault = true,
    }
end

local function IsLegacyAutomaticPosition(saved, migrationVersion, isDebuff)
    if not saved then
        return true
    end
    if saved.automaticPosition ~= nil then
        return saved.automaticPosition == true
    end
    if saved.seededFromDefault == true or saved.seededFromEditMode == true then
        return true
    end
    -- Debuff positions written before v2 had no origin marker. Only those old
    -- entries are migrated; newer Unlock Mode positions remain untouched.
    return isDebuff and migrationVersion < 2
end

function Mod:EnsureDefaultBuffPosition()
    if not (self.db and UIParent) then
        return false
    end

    local saved = self.db.buffPos
    local migrationVersion = tonumber(self.db.customBuffPositionMigrationVersion) or 0
    local needsDefault = not saved or (migrationVersion < CUSTOM_POSITION_MIGRATION_VERSION
        and IsLegacyAutomaticPosition(saved, migrationVersion, false))

    if saved and not needsDefault then
        self.db.customBuffPositionMigrated = true
        self.db.customBuffPositionMigrationVersion = CUSTOM_POSITION_MIGRATION_VERSION
        return true
    end
    if saved and migrationVersion >= CUSTOM_POSITION_MIGRATION_VERSION then
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    local position = BuildDefaultAuraPosition(self.db, false)
    if not position then
        return false
    end
    self.db.buffPos = position
    self.db.customBuffPositionMigrated = true
    self.db.customBuffPositionMigrationVersion = CUSTOM_POSITION_MIGRATION_VERSION
    self._customBuffPositionHash = nil
    return true
end
function Mod:EnsureCustomBuffAnchor()
    local anchor = self.customBuffAnchor or _G.KT_CustomBuffContainer
    if not anchor then
        anchor = CreateFrame("Frame", "KT_CustomBuffContainer", UIParent)
        if anchor.SetClipsChildren then anchor:SetClipsChildren(false) end
        anchor:EnableMouse(false)
    end
    self.customBuffAnchor = anchor
    return anchor
end

function Mod:ApplyCustomBuffPosition()
    local anchor = self:EnsureCustomBuffAnchor()
    if not (anchor and self.db) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self._customBuffPositionDirty = true
        return
    end

    local saved = self.db.buffPos
    if saved and saved.automaticPosition == true then
        saved = BuildDefaultAuraPosition(self.db, false) or saved
        self.db.buffPos = saved
    elseif not saved then
        saved = BuildDefaultAuraPosition(self.db, false)
        self.db.buffPos = saved
    end
    if not saved then
        self._customBuffPositionDirty = true
        return
    end

    local relativeTo = (saved.relativeTo and _G[saved.relativeTo]) or UIParent
    local positionHash = table.concat({
        tostring(saved.point or "TOPRIGHT"),
        tostring(saved.relativeTo or "UIParent"),
        tostring(saved.relativePoint or "TOPLEFT"),
        tostring(saved.xOfs or 0),
        tostring(saved.yOfs or 0),
    }, ":")
    if self._customBuffPositionHash == positionHash and not self._customBuffPositionDirty then
        return
    end

    anchor:ClearAllPoints()
    anchor:SetPoint(saved.point or "TOPRIGHT", relativeTo,
        saved.relativePoint or saved.point or "TOPLEFT", saved.xOfs or 0, saved.yOfs or 0)
    self._customBuffPositionHash = positionHash
    self._customBuffPositionDirty = false
end
local function ResolveBuffFlow(growDir)
    local flow = AnchorUtil and AnchorUtil.FlowDirection
    if not flow then
        return nil, nil, growDir == "RIGHT" and "TOPLEFT" or "TOPRIGHT"
    end
    if growDir == "RIGHT" then
        return flow.Right, flow.Down, "TOPLEFT"
    end
    return flow.Left, flow.Down, "TOPRIGHT"
end

function Mod:ApplyCustomBuffLayout()
    local container = self.customBuffContainer
    local anchor = self.customBuffAnchor
    if not (AK and container and anchor and self.db) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self._customBuffLayoutDirty = true
        return
    end

    self:ConfigureCustomBuffStyle()
    local enchantCount = self:RefreshWeaponEnchantButtons(false) or 0
    local layout = self.db.buffs or DEFAULT_DB.buffs
    local size = ClampNumber(layout.size, 16, 80, DEFAULT_DB.buffs.size)
    local spacing = ClampNumber(layout.spacing, 0, 24, DEFAULT_DB.buffs.spacing)
    local perRow = ClampNumber(layout.perRow, 1, 24, DEFAULT_DB.buffs.perRow)
    local growDir = layout.growDir or "LEFT"
    local rowWidth = perRow * size + max(0, perRow - 1) * spacing
    local growthH, growthV, anchorPoint = ResolveBuffFlow(growDir)
    local layoutHash = table.concat({
        tostring(size), tostring(spacing), tostring(perRow), tostring(growDir),
        tostring(self.db.style), tostring(self.db.shape),
        tostring(self.db.durationFont), tostring(self.db.durationFontSize),
        tostring(self.db.durationFontOutline), tostring(self.db.durationXOffset),
        tostring(self.db.durationYOffset), tostring(self.db.countFont),
        tostring(self.db.countFontSize), tostring(self.db.countFontOutline),
        tostring(self.db.countXOffset), tostring(self.db.countYOffset),
        tostring(enchantCount),
    }, ":")
    if self._customBuffLayoutHash == layoutHash and not self._customBuffLayoutDirty then
        return
    end

    local enchantShift = enchantCount * (size + spacing)
    local direction = growDir == "RIGHT" and 1 or -1
    anchor:SetSize(rowWidth + enchantShift, size)
    container:ClearAllPoints()
    container:SetPoint(anchorPoint, anchor, anchorPoint, direction * enchantShift, 0)
    AK.SetContainerAnchor(container, anchorPoint)
    AK.SetContainerAxis(container, false)
    if growthH and growthV then
        AK.SetContainerGrowth(container, growthH, growthV)
    end
    AK.SetContainerPadding(container, 0, 0, 0, 0)
    AK.SetContainerRowWidth(container, rowWidth)
    container:SetAuraGroupLayout(CUSTOM_BUFF_GROUP_KEY, {
        elementWidth = size,
        elementHeight = size,
        elementSpacing = spacing,
        lineSpacing = spacing,
    })
    container:SetAuraGroupMaxFrameCount(CUSTOM_BUFF_GROUP_KEY, CUSTOM_BUFF_MAX_COUNT)
    container:Show()
    if AK.RestyleSoon then
        AK.RestyleSoon(CUSTOM_BUFF_STYLE_KEY)
    else
        AK.Restyle(CUSTOM_BUFF_STYLE_KEY)
    end
    self._customBuffLayoutHash = layoutHash
    self._customBuffLayoutDirty = false
end

function Mod:SetBlizzardBuffFrameHidden(hidden)
    local frame = _G.BuffFrame
    self._hideBlizzardBuffFrame = hidden and true or false
    if not frame then
        return
    end

    if not self._blizzardBuffShowHooked and hooksecurefunc then
        self._blizzardBuffShowHooked = true
        hooksecurefunc(frame, "Show", function(nativeFrame)
            if Mod and Mod._hideBlizzardBuffFrame then
                nativeFrame:Hide()
            end
        end)
    end

    if hidden then
        frame:Hide()
    else
        frame:Show()
    end
end

function Mod:EnsureCustomBuffs()
    if not (AK and self.db and self.db.enable ~= false) then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        -- The engine owns content updates in combat. Do not touch visibility,
        -- geometry, unit binding or restricted aura-button descendants here.
        return self.customBuffContainer ~= nil and self._customBuffBound == true
    end

    local positionReady = self:EnsureDefaultBuffPosition()
    if not positionReady then
        -- Wait until the minimap anchor exists; the bounded startup pass will
        -- retry without exposing a temporary position elsewhere on screen.
        self._customBuffPositionDirty = true
        if self.customBuffAnchor then self.customBuffAnchor:Hide() end
        if self.customBuffContainer then self.customBuffContainer:Hide() end
        self:SetBlizzardBuffFrameHidden(false)
        return false
    end

    local anchor = self:EnsureCustomBuffAnchor()
    self:ApplyCustomBuffPosition()
    self:ConfigureCustomBuffStyle()

    if self.customBuffContainer then
        if not self._customBuffBound then
            self.customBuffContainer:SetUnit("player")
            self.customBuffContainer:UpdateAllAuras()
            self._customBuffBound = true
        end
        anchor:Show()
        self.customBuffContainer:Show()
        self:ApplyCustomBuffLayout()
        self:SetBlizzardBuffFrameHidden(true)
        return true
    end

    if self._customBuffCreatePending then
        return false
    end
    self._customBuffCreatePending = true

    local layout = self.db.buffs or DEFAULT_DB.buffs
    local size = ClampNumber(layout.size, 16, 80, DEFAULT_DB.buffs.size)
    local spacing = ClampNumber(layout.spacing, 0, 24, DEFAULT_DB.buffs.spacing)
    local perRow = ClampNumber(layout.perRow, 1, 24, DEFAULT_DB.buffs.perRow)
    local growDir = layout.growDir or "LEFT"
    local growthH, growthV, anchorPoint = ResolveBuffFlow(growDir)
    local rowWidth = perRow * size + max(0, perRow - 1) * spacing

    AK.RequestContainer(anchor, "player", {
        point = { anchorPoint, anchor, anchorPoint, 0, 0 },
        layout = {
            anchorPoint = anchorPoint,
            growthH = growthH,
            growthV = growthV,
            padding = { 0, 0, 0, 0 },
            rowWidth = rowWidth,
        },
        groups = {{
            key = CUSTOM_BUFF_GROUP_KEY,
            filter = { "HELPFUL" },
            maxFrameCount = CUSTOM_BUFF_MAX_COUNT,
            style = CUSTOM_BUFF_STYLE_KEY,
            layout = {
                elementWidth = size,
                elementHeight = size,
                elementSpacing = spacing,
                lineSpacing = spacing,
            },
        }},
    }, function(container)
        Mod._customBuffCreatePending = false
        if not container then
            return
        end
        Mod.customBuffContainer = container
        Mod._customBuffBound = true
        container:SetFrameLevel((anchor:GetFrameLevel() or 0) + 1)
        if Mod.db and Mod.db.enable ~= false
            and (not Mod.IsEnabled or Mod:IsEnabled()) then
            anchor:Show()
            container:Show()
            Mod:ApplyCustomBuffLayout()
            Mod:SetBlizzardBuffFrameHidden(true)
        else
            container:SetUnit("none")
            container:Hide()
        end
    end)
    return self.customBuffContainer ~= nil
end
function Mod:ConfigureCustomDebuffStyle()
    if not (AK and self.db) then
        return
    end

    local layout = self.db.debuffs or DEFAULT_DB.debuffs
    local size = ClampNumber(layout.size, 16, 80, DEFAULT_DB.debuffs.size)
    local variant = self.db.style or "BLIZZARD"
    local shape = variant ~= "BLIZZARD" and (self.db.shape or "NONE") or "NONE"
    local border
    if variant == "KUI" and shape == "NONE" then
        border = { 0, 0, 0, 1, size = 1 }
    end

    AK.styles[CUSTOM_DEBUFF_STYLE_KEY] = {
        width = size,
        height = size,
        texCoord = variant == "BLIZZARD" and { 0, 1, 0, 1 } or { 0.08, 0.92, 0.08, 0.92 },
        border = border,
        dispelBorder = true,
        dispelBorderPx = 2,
        dispelBorderIndependent = true,
        dispelTexture = SHAPE_BORDERS[shape]
            or "Interface\\AddOns\\KullThranUI\\media\\textures\\square-ring.png",
        cooldownReverse = true,
        cooldownDrawEdge = false,
        -- Distinguish short durations from application counts when both values match.
        durationShowSeconds = true,
        noTooltips = false,
        durationFont = FetchFont(self.db.durationFont),
        durationFontSize = ClampNumber(self.db.durationFontSize, 8, 24, 11),
        durationFontFlags = self.db.durationFontOutline or "OUTLINE",
        durationPoint = "TOP",
        durationRelPoint = "BOTTOM",
        durationX = ClampNumber(self.db.durationXOffset, -20, 20, 0),
        durationY = ClampNumber(self.db.durationYOffset, -20, 20, -2),
        stackFont = FetchFont(self.db.countFont),
        stackFontSize = ClampNumber(self.db.countFontSize, 8, 24, 12),
        stackFontFlags = self.db.countFontOutline or "OUTLINE",
        stackPoint = "TOPRIGHT",
        stackX = ClampNumber(self.db.countXOffset, -20, 20, 2),
        stackY = ClampNumber(self.db.countYOffset, -20, 20, 2),
        KT_Variant = variant,
        KT_Shape = shape,
        applyExtra = ApplyCustomBuffAuraKitExtras,
    }
end

function Mod:EnsureDefaultDebuffPosition()
    if not (self.db and UIParent) then
        return false
    end

    local saved = self.db.debuffPos
    local migrationVersion = tonumber(self.db.customDebuffPositionMigrationVersion) or 0
    local needsDefault = not saved or (migrationVersion < CUSTOM_POSITION_MIGRATION_VERSION
        and IsLegacyAutomaticPosition(saved, migrationVersion, true))

    if saved and not needsDefault then
        self.db.customDebuffPositionMigrated = true
        self.db.customDebuffPositionMigrationVersion = CUSTOM_POSITION_MIGRATION_VERSION
        return true
    end
    if saved and migrationVersion >= CUSTOM_POSITION_MIGRATION_VERSION then
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    local position = BuildDefaultAuraPosition(self.db, true)
    if not position then
        return false
    end
    self.db.debuffPos = position
    self.db.customDebuffPositionMigrated = true
    self.db.customDebuffPositionMigrationVersion = CUSTOM_POSITION_MIGRATION_VERSION
    self._customDebuffPositionHash = nil
    return true
end
function Mod:EnsureCustomDebuffAnchor()
    local anchor = self.customDebuffAnchor or _G.KT_CustomDebuffContainer
    if not anchor then
        anchor = CreateFrame("Frame", "KT_CustomDebuffContainer", UIParent)
        if anchor.SetClipsChildren then anchor:SetClipsChildren(false) end
        anchor:EnableMouse(false)
    end
    self.customDebuffAnchor = anchor
    return anchor
end

function Mod:ApplyCustomDebuffPosition()
    local anchor = self:EnsureCustomDebuffAnchor()
    if not (anchor and self.db) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self._customDebuffPositionDirty = true
        return
    end

    local saved = self.db.debuffPos
    if saved and saved.automaticPosition == true then
        saved = BuildDefaultAuraPosition(self.db, true) or saved
        self.db.debuffPos = saved
    elseif not saved then
        saved = BuildDefaultAuraPosition(self.db, true)
        self.db.debuffPos = saved
    end
    if not saved then
        self._customDebuffPositionDirty = true
        return
    end

    local relativeTo = (saved.relativeTo and _G[saved.relativeTo]) or UIParent
    local positionHash = table.concat({
        tostring(saved.point or "TOPRIGHT"),
        tostring(saved.relativeTo or "UIParent"),
        tostring(saved.relativePoint or "TOPLEFT"),
        tostring(saved.xOfs or 0),
        tostring(saved.yOfs or 0),
    }, ":")
    if self._customDebuffPositionHash == positionHash and not self._customDebuffPositionDirty then
        return
    end

    anchor:ClearAllPoints()
    anchor:SetPoint(saved.point or "TOPRIGHT", relativeTo,
        saved.relativePoint or saved.point or "TOPLEFT", saved.xOfs or 0, saved.yOfs or 0)
    self._customDebuffPositionHash = positionHash
    self._customDebuffPositionDirty = false
end
function Mod:ApplyCustomDebuffLayout()
    local container = self.customDebuffAuraContainer
    local anchor = self.customDebuffAnchor
    if not (AK and container and anchor and self.db) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self._customDebuffLayoutDirty = true
        return
    end

    self:ConfigureCustomDebuffStyle()
    local layout = self.db.debuffs or DEFAULT_DB.debuffs
    local size = ClampNumber(layout.size, 16, 80, DEFAULT_DB.debuffs.size)
    local spacing = ClampNumber(layout.spacing, 0, 24, DEFAULT_DB.debuffs.spacing)
    local perRow = ClampNumber(layout.perRow, 1, 24, DEFAULT_DB.debuffs.perRow)
    local growDir = layout.growDir or "LEFT"
    local rowWidth = perRow * size + max(0, perRow - 1) * spacing
    local growthH, growthV, anchorPoint = ResolveBuffFlow(growDir)
    local layoutHash = table.concat({
        tostring(size), tostring(spacing), tostring(perRow), tostring(growDir),
        tostring(self.db.style), tostring(self.db.shape),
        tostring(self.db.durationFont), tostring(self.db.durationFontSize),
        tostring(self.db.durationFontOutline), tostring(self.db.durationXOffset),
        tostring(self.db.durationYOffset), tostring(self.db.countFont),
        tostring(self.db.countFontSize), tostring(self.db.countFontOutline),
        tostring(self.db.countXOffset), tostring(self.db.countYOffset),
    }, ":")
    if self._customDebuffLayoutHash == layoutHash and not self._customDebuffLayoutDirty then
        return
    end

    anchor:SetSize(rowWidth, size)
    container:ClearAllPoints()
    container:SetPoint(anchorPoint, anchor, anchorPoint, 0, 0)
    AK.SetContainerAnchor(container, anchorPoint)
    AK.SetContainerAxis(container, false)
    if growthH and growthV then
        AK.SetContainerGrowth(container, growthH, growthV)
    end
    AK.SetContainerPadding(container, 0, 0, 0, 0)
    AK.SetContainerRowWidth(container, rowWidth)
    container:SetAuraGroupLayout(CUSTOM_DEBUFF_GROUP_KEY, {
        elementWidth = size,
        elementHeight = size,
        elementSpacing = spacing,
        lineSpacing = spacing,
    })
    container:SetAuraGroupMaxFrameCount(CUSTOM_DEBUFF_GROUP_KEY, CUSTOM_DEBUFF_MAX_COUNT)
    container:Show()
    if AK.RestyleSoon then
        AK.RestyleSoon(CUSTOM_DEBUFF_STYLE_KEY)
    else
        AK.Restyle(CUSTOM_DEBUFF_STYLE_KEY)
    end
    self._customDebuffLayoutHash = layoutHash
    self._customDebuffLayoutDirty = false
end

function Mod:SetBlizzardDebuffFrameHidden(hidden)
    local frame = _G.DebuffFrame
    self._hideBlizzardDebuffFrame = hidden and true or false
    if not frame then
        return
    end

    if not self._blizzardDebuffShowHooked and hooksecurefunc then
        self._blizzardDebuffShowHooked = true
        hooksecurefunc(frame, "Show", function(nativeFrame)
            if Mod and Mod._hideBlizzardDebuffFrame then
                nativeFrame:Hide()
            end
        end)
    end

    if hidden then
        frame:Hide()
    else
        frame:Show()
    end
end

function Mod:EnsureCustomDebuffs()
    if not (AK and self.db and self.db.enable ~= false) then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return self.customDebuffAuraContainer ~= nil and self._customDebuffBound == true
    end

    local positionReady = self:EnsureDefaultDebuffPosition()
    if not positionReady then
        self._customDebuffPositionDirty = true
        if self.customDebuffAnchor then self.customDebuffAnchor:Hide() end
        if self.customDebuffAuraContainer then self.customDebuffAuraContainer:Hide() end
        self:SetBlizzardDebuffFrameHidden(false)
        return false
    end

    local anchor = self:EnsureCustomDebuffAnchor()
    self:ApplyCustomDebuffPosition()
    self:ConfigureCustomDebuffStyle()

    if self.customDebuffAuraContainer then
        if not self._customDebuffBound then
            self.customDebuffAuraContainer:SetUnit("player")
            self.customDebuffAuraContainer:UpdateAllAuras()
            self._customDebuffBound = true
        end
        anchor:Show()
        self.customDebuffAuraContainer:Show()
        self:ApplyCustomDebuffLayout()
        self:SetBlizzardDebuffFrameHidden(true)
        return true
    end

    if self._customDebuffCreatePending then
        return false
    end
    self._customDebuffCreatePending = true

    local layout = self.db.debuffs or DEFAULT_DB.debuffs
    local size = ClampNumber(layout.size, 16, 80, DEFAULT_DB.debuffs.size)
    local spacing = ClampNumber(layout.spacing, 0, 24, DEFAULT_DB.debuffs.spacing)
    local perRow = ClampNumber(layout.perRow, 1, 24, DEFAULT_DB.debuffs.perRow)
    local growDir = layout.growDir or "LEFT"
    local growthH, growthV, anchorPoint = ResolveBuffFlow(growDir)
    local rowWidth = perRow * size + max(0, perRow - 1) * spacing

    AK.RequestContainer(anchor, "player", {
        point = { anchorPoint, anchor, anchorPoint, 0, 0 },
        layout = {
            anchorPoint = anchorPoint,
            growthH = growthH,
            growthV = growthV,
            padding = { 0, 0, 0, 0 },
            rowWidth = rowWidth,
        },
        groups = {{
            key = CUSTOM_DEBUFF_GROUP_KEY,
            filter = { "HARMFUL" },
            maxFrameCount = CUSTOM_DEBUFF_MAX_COUNT,
            style = CUSTOM_DEBUFF_STYLE_KEY,
            layout = {
                elementWidth = size,
                elementHeight = size,
                elementSpacing = spacing,
                lineSpacing = spacing,
            },
        }},
    }, function(container)
        Mod._customDebuffCreatePending = false
        if not container then
            return
        end
        Mod.customDebuffAuraContainer = container
        Mod._customDebuffBound = true
        container:SetFrameLevel((anchor:GetFrameLevel() or 0) + 1)
        if Mod.db and Mod.db.enable ~= false
            and (not Mod.IsEnabled or Mod:IsEnabled()) then
            anchor:Show()
            container:Show()
            Mod:ApplyCustomDebuffLayout()
            Mod:SetBlizzardDebuffFrameHidden(true)
        else
            container:SetUnit("none")
            container:Hide()
        end
    end)
    return self.customDebuffAuraContainer ~= nil
end
function Mod:UpdateCustomDebuffs()
    return self:EnsureCustomDebuffs()
end
function Mod:ScanAuras()
    if not (self.db and self.db.enable ~= false) then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    -- Both containers are engine-owned. This pass only finishes deferred
    -- construction/configuration; aura changes never invoke Lua layout work.
    self:EnsureCustomBuffs()
    self:EnsureCustomDebuffs()
end
function Mod:HandleImmediateRefresh()
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local buffsReady = self:EnsureCustomBuffs()
    local debuffsReady = self:EnsureCustomDebuffs()
    if self._customBuffPositionDirty then self:ApplyCustomBuffPosition() end
    if self._customBuffLayoutDirty then self:ApplyCustomBuffLayout() end
    if self._customDebuffPositionDirty then self:ApplyCustomDebuffPosition() end
    if self._customDebuffLayoutDirty then self:ApplyCustomDebuffLayout() end

    -- Retry only while Blizzard/AuraKit have not finished constructing a
    -- container. Once both exist, the engine owns all future aura updates.
    if not buffsReady or not debuffsReady then
        self:ScheduleReskinBurst()
    end
end

function Mod:ScheduleScan(delay)
    if not (self.db and self.db.enable ~= false) then
        return
    end
    -- Engine containers update themselves in combat. Avoid creating a timer
    -- whose configuration pass is intentionally forbidden during lockdown.
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    delay = ClampNumber(delay, 0, 10, 0)
    local coalesced = delay <= 0.05
    if coalesced and self._scanQueued then return end
    if coalesced then self._scanQueued = true end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            if coalesced then self._scanQueued = false end
            if Mod and Mod.ScanAuras then
                Mod:ScanAuras()
            end
        end)
    end
end

function Mod:ScheduleReskinBurst()
    -- Startup can race the module/profile initialization chain. These bounded
    -- retries only finish custom-container construction; no aura event uses them.
    self:ScheduleScan(0.03)
    self:ScheduleScan(0.20)
    self:ScheduleScan(0.60)
    self:ScheduleScan(1.20)
    self:ScheduleScan(2.50)
end

function Mod:RunAuraDebugSnapshots()
    local function FrameSummary(label, frame)
        if not frame then
            KT:Print("|cff66ccff[ktbaddebug]|r " .. label .. "=nil")
            return
        end
        local shown = CaptureMethodValues(frame, frame.IsShown)
        local children = CaptureMethodValues(frame, frame.GetNumChildren)
        local point = CaptureMethodValues(frame, frame.GetPoint, 1)
        KT:Print("|cff66ccff[ktbaddebug]|r " .. label
            .. " shown=" .. tostring(shown and shown[1])
            .. " children=" .. tostring(children and children[1])
            .. " point=" .. tostring(point and point[1])
            .. " x=" .. tostring(point and point[4])
            .. " y=" .. tostring(point and point[5]))
    end

    KT:Print("|cff66ccff[ktbaddebug]|r backend=CustomAuraContainer"
        .. " style=" .. tostring(self.db and self.db.style)
        .. " combat=" .. tostring(InCombatLockdown and InCombatLockdown())
        .. " buffBound=" .. tostring(self._customBuffBound == true)
        .. " debuffBound=" .. tostring(self._customDebuffBound == true))
    KT:Print("|cff66ccff[ktbaddebug]|r nativeBuffHidden="
        .. tostring(self._hideBlizzardBuffFrame == true)
        .. " nativeDebuffHidden=" .. tostring(self._hideBlizzardDebuffFrame == true)
        .. " buffSeeded=" .. tostring(self.db and self.db.customBuffPositionMigrated == true)
        .. " debuffSeeded=" .. tostring(self.db and self.db.customDebuffPositionMigrated == true)
        .. " weaponEnchants=" .. tostring(self._weaponEnchantCount or 0))
    local buffPos = self.db and self.db.buffPos
    KT:Print("|cff66ccff[ktbaddebug]|r buffMigrationV="
        .. tostring(self.db and self.db.customBuffPositionMigrationVersion or 0)
        .. " buffPos=" .. tostring(buffPos and buffPos.point)
        .. " x=" .. tostring(buffPos and buffPos.xOfs)
        .. " y=" .. tostring(buffPos and buffPos.yOfs)
        .. " relativeTo=" .. tostring(buffPos and buffPos.relativeTo or "UIParent")
        .. " automatic=" .. tostring(buffPos and buffPos.automaticPosition == true))
    local debuffPos = self.db and self.db.debuffPos
    KT:Print("|cff66ccff[ktbaddebug]|r debuffMigrationV="
        .. tostring(self.db and self.db.customDebuffPositionMigrationVersion or 0)
        .. " debuffPos=" .. tostring(debuffPos and debuffPos.point)
        .. " x=" .. tostring(debuffPos and debuffPos.xOfs)
        .. " y=" .. tostring(debuffPos and debuffPos.yOfs)
        .. " relativeTo=" .. tostring(debuffPos and debuffPos.relativeTo or "UIParent")
        .. " automatic=" .. tostring(debuffPos and debuffPos.automaticPosition == true))
    FrameSummary("customBuffAnchor", self.customBuffAnchor)
    FrameSummary("customBuffAuras", self.customBuffContainer)
    FrameSummary("customDebuffAnchor", self.customDebuffAnchor)
    FrameSummary("customDebuffAuras", self.customDebuffAuraContainer)
end
local function EnsureDB()
    KT.db.profile.buffsAndDebuffs = CopyDefaults(KT.db.profile.buffsAndDebuffs, DEFAULT_DB)
    local db = KT.db.profile.buffsAndDebuffs

    -- Older profiles stored the effective default as absolute UIParent
    -- coordinates. Those coordinates do not follow the buff block when the
    -- resolution or UI scale changes and are the source of the overlap. Only
    -- positions explicitly saved by the current mover format remain absolute.
    if db.debuffPos and db.debuffPos.anchorMode ~= 'manual' then
        db.debuffPos = nil
    end

    return db
end

function Mod:OnInitialize()
    self.db = EnsureDB()
end

Mod.UnlockElements = {
    {
        key = "KT_CUSTOM_BUFFS",
        label = "Buffs",
        group = "Auras",
        isHidden = function() return not (Mod and Mod.db and Mod.db.enable ~= false) end,
        getFrame = function() return _G.KT_CustomBuffContainer end,
        getSize = function()
            local db = Mod and Mod.db
            local layout = db and db.buffs or DEFAULT_DB.buffs
            local size = ClampNumber(layout and layout.size, 16, 80, DEFAULT_DB.buffs.size)
            local spacing = ClampNumber(layout and layout.spacing, 0, 24, DEFAULT_DB.buffs.spacing)
            local perRow = ClampNumber(layout and layout.perRow, 1, 24, DEFAULT_DB.buffs.perRow)
            local enchants = Mod and Mod._weaponEnchantLayoutCount or 0
            local cells = perRow + enchants
            return cells * size + max(0, cells - 1) * spacing, size
        end,
        loadPosition = function()
            if Mod and Mod.ApplyCustomBuffPosition then
                Mod:ApplyCustomBuffPosition()
            end
            local pos = Mod and Mod.db and Mod.db.buffPos
            if pos then
                return {
                    point = pos.point,
                    relativeTo = (pos.relativeTo and _G[pos.relativeTo]) or UIParent,
                    relativePoint = pos.relativePoint,
                    x = pos.xOfs,
                    y = pos.yOfs,
                }
            end
        end,
        savePosition = function(_, point, relativePoint, xOfs, yOfs)
            if Mod and Mod.db then
                Mod.db.buffPos = {
                    point = point or "TOPRIGHT",
                    relativePoint = relativePoint or point or "TOPRIGHT",
                    xOfs = xOfs or 0,
                    yOfs = yOfs or 0,
                    anchorMode = "manual",
                    automaticPosition = false,
                    seededFromDefault = false,
                    seededFromEditMode = false,
                }
                Mod.db.customBuffPositionMigrated = true
                Mod.db.customBuffPositionMigrationVersion = CUSTOM_POSITION_MIGRATION_VERSION
                Mod._customBuffPositionHash = nil
                Mod._customBuffPositionDirty = false
            end
        end,
    },
    {
        key = "KT_CUSTOM_DEBUFFS",
        label = "Debuffs",
        group = "Auras",
        isHidden = function() return not (Mod and Mod.db and Mod.db.enable ~= false) end,
        getFrame = function() return _G.KT_CustomDebuffContainer end,
        getSize = function()
            local db = Mod and Mod.db
            local layout = db and db.debuffs or DEFAULT_DB.debuffs
            local size = ClampNumber(layout and layout.size, 16, 80, DEFAULT_DB.debuffs.size)
            local spacing = ClampNumber(layout and layout.spacing, 0, 24, DEFAULT_DB.debuffs.spacing)
            local perRow = ClampNumber(layout and layout.perRow, 1, 24, DEFAULT_DB.debuffs.perRow)
            return perRow * size + max(0, perRow - 1) * spacing, size
        end,
        loadPosition = function()
            if Mod and Mod.ApplyCustomDebuffPosition then
                Mod:ApplyCustomDebuffPosition()
            end
            local pos = Mod and Mod.db and Mod.db.debuffPos
            if pos then
                return {
                    point = pos.point,
                    relativeTo = (pos.relativeTo and _G[pos.relativeTo]) or UIParent,
                    relativePoint = pos.relativePoint,
                    x = pos.xOfs,
                    y = pos.yOfs,
                }
            end
        end,
        savePosition = function(_, point, relativePoint, xOfs, yOfs)
            if Mod and Mod.db then
                Mod.db.debuffPos = {
                    point = point or "TOPRIGHT",
                    relativePoint = relativePoint or point or "TOPRIGHT",
                    xOfs = xOfs or 0,
                    yOfs = yOfs or 0,
                    anchorMode = "manual",
                    automaticPosition = false,
                    seededFromDefault = false,
                    seededFromEditMode = false,
                }
                Mod.db.customDebuffPositionMigrated = true
                Mod.db.customDebuffPositionMigrationVersion = CUSTOM_POSITION_MIGRATION_VERSION
                Mod._customDebuffPositionHash = nil
                Mod._customDebuffPositionDirty = false
            end
        end,
    }
}

function Mod:OnEnable()
    if KT and KT.RegisterMovableElements then
        KT:RegisterMovableElements(self.UnlockElements)
    end
    self.db = EnsureDB()
    if self.db.enable == false then
        return
    end

    if KT.db then
        KT.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileReset", "Refresh")
    end


    -- Seed both custom rows from the same minimap-relative reference before
    -- hiding the native frames. Startup retries cover late minimap creation.
    local buffsReady = self:EnsureCustomBuffs()
    local debuffsReady = self:EnsureCustomDebuffs()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleImmediateRefresh")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "HandleImmediateRefresh")
    self:RegisterEvent('PLAYER_REGEN_ENABLED', 'HandleImmediateRefresh')
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", "HandleImmediateRefresh")
    self:RegisterEvent("WEAPON_ENCHANT_CHANGED", "HandleWeaponEnchantEvent")
    self:RegisterEvent("WEAPON_SLOT_CHANGED", "HandleWeaponEnchantEvent")

    if not buffsReady or not debuffsReady then
        self:ScheduleReskinBurst()
    end
end

function Mod:Refresh()
    self.db = EnsureDB()
    if not (InCombatLockdown and InCombatLockdown()) then
        self:EnsureCustomBuffs()
        self:EnsureCustomDebuffs()
        self:ApplyCustomBuffPosition()
        self:ApplyCustomBuffLayout()
        self:ApplyCustomDebuffPosition()
        self:ApplyCustomDebuffLayout()
    else
        self._customBuffPositionDirty = true
        self._customBuffLayoutDirty = true
        self._customDebuffPositionDirty = true
        self._customDebuffLayoutDirty = true
    end
    self:ScheduleScan(0)
end

function Mod:UpdateAll()
    self.db = EnsureDB()
    if not (InCombatLockdown and InCombatLockdown()) then
        self:EnsureCustomBuffs()
        self:EnsureCustomDebuffs()
        self:ApplyCustomBuffPosition()
        self:ApplyCustomBuffLayout()
        self:ApplyCustomDebuffPosition()
        self:ApplyCustomDebuffLayout()
    else
        self._customBuffPositionDirty = true
        self._customBuffLayoutDirty = true
        self._customDebuffPositionDirty = true
        self._customDebuffLayoutDirty = true
    end
    self:ScheduleScan(0)
end

function Mod:UpdateHeaders()
    self:ScheduleScan(0)
end

function Mod:OnDisable()
    if self._scheduledScan and self._scheduledScan.Cancel then
        self._scheduledScan:Cancel()
    end
    self._scheduledScan = nil
    if self._weaponEnchantTicker then
        self._weaponEnchantTicker:Cancel()
        self._weaponEnchantTicker = nil
    end
    for _, button in ipairs(self.weaponEnchantButtons or {}) do
        button:SetAlpha(0)
    end
    self._customBuffCreatePending = false
    self._customBuffBound = false
    self._customDebuffCreatePending = false
    self._customDebuffBound = false
    if InCombatLockdown and InCombatLockdown() then
        -- Alpha changes above are legal; every protected visibility, unit and
        -- ancestor operation waits for reload/reenable outside lockdown.
        self._hideBlizzardBuffFrame = false
        self._hideBlizzardDebuffFrame = false
        return
    end
    if self.customBuffContainer then
        self.customBuffContainer:SetUnit("none")
        self.customBuffContainer:Hide()
    end
    if self.customDebuffAuraContainer then
        self.customDebuffAuraContainer:SetUnit("none")
        self.customDebuffAuraContainer:Hide()
    end
    if self.customBuffAnchor then
        self.customBuffAnchor:Hide()
    end
    if self.customDebuffAnchor then
        self.customDebuffAnchor:Hide()
    end
    self:SetBlizzardBuffFrameHidden(false)
    self:SetBlizzardDebuffFrameHidden(false)
end
