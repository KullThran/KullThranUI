local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local S = KT:GetModule("Skins", true)
if not S then return end

local BAR_TEXTURE = [[Interface\AddOns\KullThranUI\Libraries\texture\Melli.tga]]
-- Breath, fatigue and the other mirror timers get a striped bar so they read
-- apart from cast bars. Retail colors each timer type through its atlas, so the
-- neutral stripes are tinted with Blizzard's original MirrorTimerColors.
local MIRROR_BAR_TEXTURE = [[Interface\AddOns\KullThranUI\Libraries\WeakAuras_SharedMedia\Textures\Statusbar_Stripes.blp]]
local MIRROR_TIMER_COLORS = {
    EXHAUSTION = { r = 1.00, g = 0.90, b = 0.00 },
    BREATH = { r = 0.00, g = 0.50, b = 1.00 },
    DEATH = { r = 1.00, g = 0.70, b = 0.00 },
    FEIGNDEATH = { r = 1.00, g = 0.70, b = 0.00 },
}
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

local function IsMirrorTimer(timer)
    local name = timer and timer.GetName and timer:GetName()
    if type(name) == "string" and name:find("^MirrorTimer%d") then return true end
    local container = _G.MirrorTimerContainer
    return container ~= nil and timer.GetParent ~= nil and timer:GetParent() == container
end

local function GetMirrorTimerColor(timer, bar)
    local timerType = timer.timer
    local colors = _G.MirrorTimerColors
    local color = timerType and ((colors and colors[timerType]) or MIRROR_TIMER_COLORS[timerType])
    if color then return color end
    -- Unknown type: keep a color Blizzard already set, only replace plain white.
    local r, g, b = bar:GetStatusBarColor()
    if r and r > 0.95 and g > 0.95 and b > 0.95 then
        return MIRROR_TIMER_COLORS.DEATH
    end
end

local function ApplyBarTexture(bar)
    local timer = bar._ktTimerOwner
    local mirror = timer and IsMirrorTimer(timer)
    bar._ktSettingTimerTexture = true
    bar:SetStatusBarTexture(mirror and MIRROR_BAR_TEXTURE or BAR_TEXTURE)
    bar._ktSettingTimerTexture = nil
    if mirror then
        local color = GetMirrorTimerColor(timer, bar)
        if color then bar:SetStatusBarColor(color.r, color.g, color.b, 1) end
    end
end

local function SkinTimer(timer)
    if not SkinEnabled() or not timer or (timer.IsForbidden and timer:IsForbidden()) then return end
    local bar = FindStatusBar(timer)
    if not bar or (bar.IsForbidden and bar:IsForbidden()) then return end

    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    HideFrameTextures(timer, fill)
    HideFrameTextures(bar, fill)

    bar._ktTimerOwner = timer
    ApplyBarTexture(bar)
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
            -- Retail's MirrorTimer Setup swaps in a per-type atlas here.
            ApplyBarTexture(self)
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
