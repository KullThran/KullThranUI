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
                local style = AK.styles[key]
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
    host:ForceUpdate()
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
    frame:HookScript("OnShow", QueueRefresh)
    frame._targetAuraSync = sync
    QueueRefresh()
end
