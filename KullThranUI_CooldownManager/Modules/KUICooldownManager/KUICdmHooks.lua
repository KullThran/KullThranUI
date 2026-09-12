local _, ns = ...

local _hookedFrames = {}
local function ScheduleCDMHookUpdate()
    -- Targeted dirty ONLY. A general MarkDirty(reason) sets allBars, which
    -- rebuilt every CDM bar on every caller. These hooks fire on each
    -- SetAuraInstanceInfo/OnCooldownIDSet pool mutation (i.e. each combat action
    -- that updates auras), so a full-bar pass per keystroke was the source of the
    -- hundreds-of-ms spikes. The specific bar is marked by NativeCDMViewerChanged
    -- through the authoritative pool hooks; here we just request a coalesced tick.
    if ns.MarkDirtyTargeted then
        ns.MarkDirtyTargeted("hook")
    elseif ns.RequestCDMUpdate then
        ns.RequestCDMUpdate("hook")
    elseif ns.RequestUpdate then
        ns.RequestUpdate("hook")
    elseif ns.RunCDMUpdateIfIdle then
        ns.RunCDMUpdateIfIdle(false)
    end
end

function ns.HookViewerFrame(frame)
    if not frame or _hookedFrames[frame] then return end
    _hookedFrames[frame] = true

    if frame.SetAuraInstanceInfo then
        hooksecurefunc(frame, "SetAuraInstanceInfo", ScheduleCDMHookUpdate)
    end
    if frame.ClearAuraInstanceInfo then
        hooksecurefunc(frame, "ClearAuraInstanceInfo", ScheduleCDMHookUpdate)
    end
end

local function cooldownIDsEqual(a, b)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) == "table" then
        return a.spellID == b.spellID and a.itemID == b.itemID and a.mountID == b.mountID
    end
    return tostring(a) == tostring(b)
end

function ns.EnsureCooldownViewerHooks()
    if not ns._cdmPoolHookInstalled then
        local viewers = {
            _G.EssentialCooldownViewer,
            _G.UtilityCooldownViewer,
            _G.BuffIconCooldownViewer,
            _G.BuffBarCooldownViewer
        }
        for _, v in ipairs(viewers) do
            if v and v.itemFramePool then
                hooksecurefunc(v.itemFramePool, "Release", ScheduleCDMHookUpdate)
                hooksecurefunc(v.itemFramePool, "ReleaseAll", ScheduleCDMHookUpdate)
            end
        end
        ns._cdmPoolHookInstalled = true
    end
    local mixins = {
        _G.CooldownViewerBuffIconItemMixin,
        _G.CooldownViewerBuffBarItemMixin,
        _G.CooldownViewerEssentialItemMixin,
        _G.CooldownViewerUtilityItemMixin,
    }

    if not ns._cdmOnSetHookInstalled then
        for _, mixin in ipairs(mixins) do
            if mixin and mixin.OnCooldownIDSet then
                hooksecurefunc(mixin, "OnCooldownIDSet", function(itemFrame)
                    local cooldownID = itemFrame.cooldownID
                    local previousCooldownID = itemFrame._kuiLastTrackedCooldownID
                    itemFrame._kuiLastTrackedCooldownID = cooldownID
                    if previousCooldownID ~= nil and cooldownIDsEqual(previousCooldownID, cooldownID) then return end
                    ScheduleCDMHookUpdate()
                end)
            end
        end
        ns._cdmOnSetHookInstalled = true

    if not ns._kuiBoundingBoxHooked then
        local viewers = { _G.UtilityCooldownViewer, _G.EssentialCooldownViewer, _G.BuffIconCooldownViewer, _G.BuffBarCooldownViewer }
        for _, v in ipairs(viewers) do
            if v and v.UpdateSystemHighlightBoundingBox then
                hooksecurefunc(v, "UpdateSystemHighlightBoundingBox", function(self)
                    if self.Selection then
                        self.Selection:Hide()
                        self.Selection:SetAlpha(0)
                        self.Selection:SetScale(0.001)
                    end
                end)
                hooksecurefunc(v, "HighlightSystem", function(self)
                    if self.Selection then
                        self.Selection:Hide()
                        self.Selection:SetAlpha(0)
                        self.Selection:SetScale(0.001)
                    end
                end)
            end
        end
        ns._kuiBoundingBoxHooked = true
    end

    end

    if _G.CooldownViewerItemDataMixin then
        if _G.CooldownViewerItemDataMixin.SetCooldownID and not ns._cdmSetHookInstalled then
            hooksecurefunc(_G.CooldownViewerItemDataMixin, "SetCooldownID", function(itemFrame, cooldownID)
                local previousCooldownID = itemFrame and itemFrame._kuiLastTrackedCooldownID or nil
                itemFrame._kuiLastTrackedCooldownID = cooldownID
                if previousCooldownID ~= nil and cooldownIDsEqual(previousCooldownID, cooldownID) then return end
                ScheduleCDMHookUpdate()
            end)
            ns._cdmSetHookInstalled = true
        end
        if _G.CooldownViewerItemDataMixin.ClearCooldownID and not ns._cdmClearHookInstalled then
            hooksecurefunc(_G.CooldownViewerItemDataMixin, "ClearCooldownID", function(itemFrame)
                local previousCooldownID = itemFrame and itemFrame._kuiLastTrackedCooldownID or itemFrame and itemFrame.cooldownID or nil
                if itemFrame then itemFrame._kuiLastTrackedCooldownID = nil end
                if previousCooldownID == nil then return end
                ScheduleCDMHookUpdate()
            end)
            ns._cdmClearHookInstalled = true
        end
    end
    
    if EventRegistry and EventRegistry.RegisterCallback and not ns._cdmDataChangedHookInstalled then
        EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", ScheduleCDMHookUpdate, "KUI_CDM_Hooks")
        ns._cdmDataChangedHookInstalled = true
    end
end
