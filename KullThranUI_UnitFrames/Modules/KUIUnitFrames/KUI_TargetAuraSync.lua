-- Coalesce target aura notifications and refresh after the client's aura cache updates.
local _, ns = ...
-- Native containers own restricted aura parsing; the host keeps theme anchors.
function ns.InstallNativeTargetBuffs(frame, unit)
    local AK, host = _G.KTAuraKit, frame.Buffs
    if not (AK and host) or host._ktNativeAuraContainer then return end
    local key = "kuiuf:buffs:" .. tostring(host)
    local size, gap = host.size or 18, host.spacing or 1
    AK.styles[key] = {
        width = size, height = size, texCoord = {0.07, 0.93, 0.07, 0.93},
        border = {0, 0, 0, 1, size = 1}, cooldownReverse = true,
        stackFontSize = 8, stackX = 1, stackY = -1, durationFontSize = 7, durationPoint = "CENTER", durationRelPoint = "CENTER", durationY = 0,
    }
    local container = AK.CreateContainer(host, unit, {
        point = {host.initialAnchor or "BOTTOMLEFT", host, host.initialAnchor or "BOTTOMLEFT"},
        groups = {{key = "targetBuffs", filter = {"HELPFUL"},
            maxFrameCount = host.num or 20, candidateFilters = {}, style = key,
            layout = {elementWidth = size, elementHeight = size,
                elementSpacing = gap, lineSpacing = gap},
        }},
    })
    host._ktNativeAuraContainer = container
    local layoutKey, maxCount
    host.ForceUpdate = function()
        local count = host.num or 20
        if maxCount ~= count then
            container:SetAuraGroupMaxFrameCount("targetBuffs", count)
            maxCount = count
        end
        -- Layout settings only change outside combat. Aura data never waits for it.
        if not InCombatLockdown() then
            local size, gap = host.size or 18, host.spacing or 1
            local style = AK.styles[key]
            -- The buttons cannot be resized now: keep their size in the row too, or they overlap.
            if size ~= style.width and AK.AurasRestricted and AK.AurasRestricted() then
                size = style.width
            end
            local anchor = host.initialAnchor or "BOTTOMLEFT"
            local width = host:GetWidth()
            local fingerprint = table.concat({size, gap, anchor,
                host.growthX or "RIGHT", host.growthY or "UP", width}, ":")
            if layoutKey ~= fingerprint then
                layoutKey = fingerprint
                container:ClearAllPoints()
                container:SetPoint(anchor, host, anchor)
                AK.SetContainerAnchor(container, anchor)
                AK.SetContainerRowWidth(container, width)
                local flow = AnchorUtil and AnchorUtil.FlowDirection
                if flow then
                    AK.SetContainerGrowth(container,
                        host.growthX == "LEFT" and flow.Left or flow.Right,
                        host.growthY == "DOWN" and flow.Down or flow.Up)
                end
                container:SetAuraGroupLayout("targetBuffs", {
                    elementWidth = size, elementHeight = size,
                    elementSpacing = gap, lineSpacing = gap,
                })
                style.width, style.height = size, size
                if AK.RestyleSoon then AK.RestyleSoon(key) end
            end
        end
        if count == 0 or not UnitExists(unit) then
            container:SetUnit("none")
            container:Hide()
        else
            container:SetUnit(unit)
            container:Show()
            container:UpdateAllAuras()
        end
    end
    if AK.OnRestrictionLift then AK.OnRestrictionLift(function() host:ForceUpdate() end) end
    host:ForceUpdate()
end
-- Player buffs: the same native icons (and time texts) as the target's. The container follows the
-- player's auras by itself; only layout left pending by combat has to be applied here.
function ns.InstallPlayerBuffs(frame)
    ns.InstallNativeTargetBuffs(frame, "player")
    local buffs = frame.Buffs
    if not (buffs and buffs._ktNativeAuraContainer) or buffs._ktPlayerSync then return end
    local sync = CreateFrame("Frame", nil, frame)
    sync:RegisterEvent("PLAYER_ENTERING_WORLD")
    sync:RegisterEvent("PLAYER_REGEN_ENABLED")
    sync:SetScript("OnEvent", function() buffs:ForceUpdate() end)
    buffs._ktPlayerSync = sync
end
function ns.InstallTargetAuraSync(frame, unit, syncDebuffs, getSettings)
    if frame._targetAuraSync then return end
    unit = unit or "target"
    ns.InstallNativeTargetBuffs(frame, unit)
    local pending = false
    local function QueueRefresh()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if not frame:IsShown() then return end
            local buffs = frame.Buffs
            if buffs then
                if not UnitExists(unit) then
                    for _, button in ipairs(buffs) do button:Hide() end
                    buffs.visibleButtons = 0
                    if buffs._ktNativeAuraContainer then buffs:ForceUpdate() end
                else
                    local settings = getSettings(unit) or {}
                    buffs.num = settings.showBuffs == false and 0 or (settings.maxBuffs or 20)
                    if not buffs._ktNativeAuraContainer and not frame:IsElementEnabled("Auras") then
                        frame:EnableElement("Auras")
                    end
                    buffs:Show()
                    if buffs.ForceUpdate then buffs:ForceUpdate() end
                end
            end
            syncDebuffs(frame, unit)
        end)
    end
    local sync = CreateFrame("Frame", nil, frame)
    sync:RegisterUnitEvent("UNIT_AURA", unit)
    sync:RegisterEvent("PLAYER_TARGET_CHANGED")
    sync:RegisterEvent("PLAYER_ENTERING_WORLD")
    sync:SetScript("OnEvent", function(_, event, eventUnit)
        if event == "UNIT_AURA" and eventUnit ~= unit then return end
        QueueRefresh()
    end)
    -- Installed by the spawn: a hook added from the style is lost to oUF's own OnShow.
    ns.FrameBuild.OnShow(frame, QueueRefresh)
    frame._targetAuraSync = sync
    QueueRefresh()
end
