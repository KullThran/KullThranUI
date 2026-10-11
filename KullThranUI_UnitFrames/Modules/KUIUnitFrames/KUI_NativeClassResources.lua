-- Keep Blizzard's resource art, state and animations under the custom player frame.
local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Native = { records = {} }
ns.NativeClassResources = Native

function Native:IsSupported()
    -- The visual style is independent of the workspace/client flavor.
    -- Reuse whichever native resource frame this client actually provides.
    local bar = self:GetBar()
    return bar ~= nil and type(bar.SetParent) == "function"
        and type(bar.SetPoint) == "function"
end

function Native:ApplyDefaults(profile)
    if not self:IsSupported() then return end
    local themes = KT.VisualThemes
    local theme = themes and themes.GetRenderedTheme and themes:GetRenderedTheme()
    if theme ~= "retail" and theme ~= "forever" then return end
    local migration = theme == "forever" and "_ktForeverNativeResourcesV1" or "_ktRetailNativeResourcesV1"
    if profile[migration] then return end
    local settings = profile.player
    if settings.classPowerStyle == nil or settings.classPowerStyle == "none" then
        settings.showClassPowerBar = true
        settings.classPowerStyle = "blizzard"
        settings.classPowerPosition = "bottom"
    end
    profile[migration] = true
end

function Native:GetBar()
    local _, class = UnitClass("player")
    if class == "PALADIN" then return _G.PaladinPowerBarFrame end
    if class == "DEATHKNIGHT" then return _G.RuneFrame end
    if class == "EVOKER" then return _G.EssencePlayerFrame end
    if class == "DEMONHUNTER" then return _G.DemonHunterSoulFragmentsBar end
end

function Native:Prepare()
    if not self:IsSupported() then return end
    local bar = self:GetBar()
    if bar then
        -- oUF must leave the native resource's event subscriptions intact.
        bar._ktNativeResourceOwned = true
        bar.unit = "player"
        if not self.records[bar] then
            self.records[bar] = { scale = bar:GetScale() }
            bar.ignoreFramePositionManager = true
            if bar.layoutParent and bar.layoutParent.RemoveManagedFrame then
                bar.layoutParent:RemoveManagedFrame(bar)
            end
        end
    end
end

function Native:Anchor(bar)
    if self.anchoring or not self.active or self.bar ~= bar then return end
    if InCombatLockdown() then self.pending = true; return end
    local frame, profile = self.frame, self.profile
    if not (frame and profile) then return end
    self.anchoring = true
    bar:ClearAllPoints()
    local settings = profile.player
    if settings.lockClassPowerToFrame == false then
        bar:SetParent(UIParent)
        local pos = profile.positions and profile.positions.classPower or {}
        bar:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or -220)
        bar:SetScale(frame:GetScale())
    else
        bar:SetParent(frame)
        bar:SetScale(self.records[bar].scale or 1)
        -- The stock art is wider than some bars: retain the resource's own size.
        bar:SetPoint("TOP", frame.Power or frame.Health or frame, "BOTTOM",
            settings.classPowerBarX or 0, -4 + (settings.classPowerBarY or 0))
    end
    bar:SetFrameStrata(frame:GetFrameStrata())
    bar:SetFrameLevel(frame:GetFrameLevel() + 5)
    self.anchoring = false
end

function Native:Refresh()
    if not self.active then return end
    if InCombatLockdown() then self.pending = true; return end
    local bar = self.bar
    if bar.EvaluateUnit then
        bar:EvaluateUnit() -- Devourer owns spec, aura and transformation visibility.
        bar:SetShown(bar:IsBarEnabled())
    elseif bar.Setup then
        bar:Setup() -- Includes level, vehicle and personal-resource-display rules.
    elseif bar.UpdateRunes then
        bar:UpdateRunes(true)
        bar:SetShown(not (UnitHasVehicleUI and UnitHasVehicleUI("player")))
    end
    self:Anchor(bar)
    self.pending = false
end

function Native:Deactivate()
    self.active = false
    local bar = self.bar or (self:IsSupported() and self:GetBar())
    if bar then
        if not self.hidden then self.hidden = CreateFrame("Frame", nil, UIParent); self.hidden:Hide() end
        bar:SetParent(self.hidden)
        bar:Hide()
    end
    self.bar = nil
end

function Native:Activate(frame, profile)
    if not self:IsSupported() then return end
    if InCombatLockdown() then self.pending = true; return end
    self:Prepare()
    local bar = self:GetBar()
    if not bar then return end
    self.frame, self.profile, self.bar, self.active = frame, profile, bar, true
    if not self.records[bar].hooked then
        self.records[bar].hooked = true
        hooksecurefunc(bar, "SetPoint", function() self:Anchor(bar) end)
        hooksecurefunc(bar, "SetParent", function() self:Anchor(bar) end)
        bar:HookScript("OnShow", function() self:Anchor(bar) end)
    end
    self:Anchor(bar)
    self:Refresh()
    if not self.events then
        self.events = CreateFrame("Frame")
        for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED",
            "PLAYER_TALENT_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_REGEN_ENABLED"}) do
            self.events:RegisterEvent(event)
        end
        self.events:SetScript("OnEvent", function()
            if self.active then
                C_Timer.After(0, function() self:Refresh() end)
            end
        end)
    end
    return bar
end
