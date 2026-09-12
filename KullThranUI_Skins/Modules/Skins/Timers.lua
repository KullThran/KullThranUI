local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local S = KT:GetModule("Skins", true)
if not S then return end

local BAR_TEXTURE = [[Interface\AddOns\KullThranUI\Libraries\texture\Melli.tga]]
local FONT = (KT.GetDefaultFontPath and KT:GetDefaultFontPath())
    or KT.DEFAULT_FONT_PATH
    or [[Interface\AddOns\KullThranUI\Libraries\font\AAA_ITC_Avant_Garde.ttf]]

local function SkinEnabled()
    return S.db and S.db.enable ~= false and S.db.timers ~= false
end

local function HideFrameTextures(frame, keep)
    if not (frame and frame.GetNumRegions and frame.GetRegions) then return end
    for index = 1, frame:GetNumRegions() do
        local region = select(index, frame:GetRegions())
        if region and region ~= keep and region.IsObjectType and region:IsObjectType("Texture") then
            region:SetAlpha(0)
        end
    end
end

local function FindStatusBar(timer)
    if not timer then return nil end
    if timer.IsObjectType and timer:IsObjectType("StatusBar") then return timer end

    local name = timer.GetName and timer:GetName()
    local bar = timer.StatusBar or timer.statusBar or timer.Bar or timer.bar
        or (name and (_G[name .. "StatusBar"] or _G[name .. "Bar"]))
    if bar and bar.SetStatusBarTexture then return bar end

    if timer.GetChildren then
        local children = { timer:GetChildren() }
        for index = 1, #children do
            local child = children[index]
            if child and child.IsObjectType and child:IsObjectType("StatusBar") then
                return child
            end
        end
    end
end

local function FindTimerText(timer, bar)
    local timerName = timer and timer.GetName and timer:GetName()
    local barName = bar and bar.GetName and bar:GetName()
    local text = (timer and (timer.Text or timer.text or timer.TimeText or timer.Label))
        or (bar and (bar.Text or bar.text or bar.TimeText or bar.Label))
        or (barName and _G[barName .. "Text"])
        or (timerName and (_G[timerName .. "Text"] or _G[timerName .. "StatusBarText"]))
    if text and text.IsObjectType and text:IsObjectType("FontString") then return text end

    for _, owner in ipairs({ bar, timer }) do
        if owner and owner.GetNumRegions and owner.GetRegions then
            for index = 1, owner:GetNumRegions() do
                local region = select(index, owner:GetRegions())
                if region and region.IsObjectType and region:IsObjectType("FontString") then
                    return region
                end
            end
        end
    end
end

local function SkinTimer(timer)
    if not SkinEnabled() or not timer or (timer.IsForbidden and timer:IsForbidden()) then return end
    local bar = FindStatusBar(timer)
    if not bar or (bar.IsForbidden and bar:IsForbidden()) then return end

    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    HideFrameTextures(timer, fill)
    HideFrameTextures(bar, fill)

    bar:SetStatusBarTexture(BAR_TEXTURE)
    fill = bar:GetStatusBarTexture()
    if fill then
        fill:SetAlpha(1)
        if fill.SetHorizTile then fill:SetHorizTile(false) end
        if fill.SetVertTile then fill:SetVertTile(false) end
    end

    if not bar._ktTimerBackdrop then
        local backdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        backdrop:SetFrameLevel(math.max(0, (bar:GetFrameLevel() or 1) - 1))
        backdrop:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        backdrop:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
        backdrop:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]],
            edgeSize = 1,
        })
        backdrop:SetBackdropColor(0.025, 0.025, 0.03, 0.96)
        bar._ktTimerBackdrop = backdrop
    end

    local accent = S:GetAccentColor()
    bar._ktTimerBackdrop:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
    bar._ktTimerBackdrop:Show()

    local text = FindTimerText(timer, bar)
    if text then
        local _, size = text:GetFont()
        text:SetFont(FONT, math.max(11, tonumber(size) or 11), "OUTLINE")
        text:SetTextColor(1, 1, 1, 1)
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
        text:SetDrawLayer("OVERLAY", 7)
    end

    if not bar._ktTimerTextureHooked and hooksecurefunc then
        bar._ktTimerTextureHooked = true
        hooksecurefunc(bar, "SetStatusBarTexture", function(self)
            if not SkinEnabled() or self._ktSettingTimerTexture then return end
            local texture = self:GetStatusBarTexture()
            local path = texture and texture.GetTexture and texture:GetTexture()
            if path ~= BAR_TEXTURE then
                self._ktSettingTimerTexture = true
                self:SetStatusBarTexture(BAR_TEXTURE)
                self._ktSettingTimerTexture = nil
            end
        end)
    end

    timer._ktTimerSkinned = true
end

local function SkinContainer(container)
    if not container then return end
    SkinTimer(container)
    if container.GetChildren then
        local children = { container:GetChildren() }
        for index = 1, #children do SkinTimer(children[index]) end
    end
    if not container._ktTimerShowHooked and container.HookScript then
        container._ktTimerShowHooked = true
        container:HookScript("OnShow", function()
            C_Timer.After(0, function() SkinContainer(container) end)
        end)
    end
end

local function ScanTimers()
    if not SkinEnabled() then return end
    SkinContainer(_G.TimerTracker)
    SkinContainer(_G.MirrorTimerContainer)

    for index = 1, 5 do
        SkinTimer(_G["TimerTrackerTimer" .. index])
        SkinTimer(_G["MirrorTimer" .. index])
    end
end

local function QueueTimerScan()
    if not C_Timer then return end
    C_Timer.After(0, ScanTimers)
    C_Timer.After(0.10, ScanTimers)
    C_Timer.After(0.50, ScanTimers)
end

local watcher = CreateFrame("Frame")
pcall(watcher.RegisterEvent, watcher, "PLAYER_ENTERING_WORLD")
pcall(watcher.RegisterEvent, watcher, "START_TIMER")
pcall(watcher.RegisterEvent, watcher, "MIRROR_TIMER_START")
pcall(watcher.RegisterEvent, watcher, "ADDON_LOADED")
watcher:SetScript("OnEvent", QueueTimerScan)

S.ScanKUITimers = ScanTimers
QueueTimerScan()
