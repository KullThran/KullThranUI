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

-- Every class bar the client hangs under its player frame. Each one decides its own visibility by
-- spec or form (Arcane, Windwalker, Cat Form) when Refresh runs its Setup.
local BAR_BY_CLASS = {
    PALADIN = "PaladinPowerBarFrame",
    DEATHKNIGHT = "RuneFrame",
    EVOKER = "EssencePlayerFrame",
    DEMONHUNTER = "DemonHunterSoulFragmentsBar",
    WARLOCK = "WarlockPowerFrame",
    MAGE = "MageArcaneChargesFrame",
    MONK = "MonkHarmonyBarFrame",
    ROGUE = "RogueComboPointBarFrame",
    DRUID = "DruidComboPointBarFrame",
}

-- Forever's orbs and Classic's tray already draw combo points under the frame.
function Native:YieldsToComboDisplay()
    local _, class = UnitClass("player")
    if class ~= "ROGUE" and class ~= "DRUID" then return false end
    local combo = ns.ComboUnderFrame
    return combo ~= nil and combo.GetBarStyle("player") ~= "off"
end

function Native:GetClassBar()
    local _, class = UnitClass("player")
    local name = BAR_BY_CLASS[class]
    return name and _G[name]
end

function Native:GetBar()
    if self:YieldsToComboDisplay() then return nil end
    return self:GetClassBar()
end

function Native:Prepare()
    -- Marked even while yielding: a later style change may hand the bar back.
    local bar = self:GetClassBar()
    if bar and type(bar.SetParent) == "function" then
        -- oUF must leave the native resource's event subscriptions intact.
        bar._ktNativeResourceOwned = true
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
        -- Not UIParent itself: the bar looks up its unit on its parent's parent.
        if not self.freeHolder then
            self.freeHolder = CreateFrame("Frame", nil, UIParent)
            self.freeHolder:SetAllPoints(UIParent)
        end
        bar:SetParent(self.freeHolder)
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
    self:SeatCastbar(bar)
    self.anchoring = false
end

-- The stock styles seat the cast bar right under the power bar, where the resource hangs. It moves below
-- the resource here, out of combat, because a cast starts in combat when nothing may be re-anchored.
function Native:SeatCastbar(bar)
    local frame, settings = self.frame, self.profile.player
    local castbar = frame.Castbar
    local holder = castbar and castbar:GetParent()
    if not holder or holder == frame or not frame.Power then return end
    local themes = KT.VisualThemes
    local theme = themes and themes.GetRenderedTheme and themes:GetRenderedTheme()
    if theme == nil or theme == "kui" then return end
    if bar and bar:IsShown() and settings.lockClassPowerToFrame ~= false and settings.lockCastbarToFrame ~= false then
        holder:ClearAllPoints()
        holder:SetPoint("TOP", bar, "BOTTOM", -(settings.classPowerBarX or 0), -2)
        self.castbarMoved = true
    elseif self.castbarMoved then
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, -4)
        self.castbarMoved = false
    end
end

function Native:Refresh()
    if not self.active then return end
    if InCombatLockdown() then self.pending = true; return end
    local bar = self.bar
    -- Never bar:Setup() or bar:EvaluateUnit() from here: they write PlayerFrame.classPowerBar and
    -- PlayerFrame.activeAlternatePowerBar, and Blizzard's player art reads those on its way to the
    -- buff frame, which then fails on secret auras. The bars run both on their own events.
    if bar.IsBarEnabled then
        bar:SetShown(bar:IsBarEnabled()) -- Devourer owns spec, aura and transformation visibility.
    elseif bar.Setup then
        bar:SetAlpha((UnitHasVehicleUI and UnitHasVehicleUI("player")) and 0 or 1)
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
        -- The hidden parent is enough, and the bar keeps the state Blizzard gave it for reactivation.
        bar:SetParent(self.hidden)
    end
    if self.frame and self.profile and not InCombatLockdown() then self:SeatCastbar(nil) end
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
