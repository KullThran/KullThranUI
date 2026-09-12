-- ============================================================================
-- ENHANCEMENTS - COMBAT TIMER
-- ============================================================================
-- Cronometro de duracion del combate actual. Arranca en PLAYER_REGEN_DISABLED,
-- detiene y muestra el total al salir de combate (PLAYER_REGEN_ENABLED),
-- con un registro de mover para colocarlo en pantalla desde UnlockMode.
-- ============================================================================
local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then return end

local GetTime = _G.GetTime
local CreateFrame = _G.CreateFrame
local format = _G.format
local InCombatLockdown = _G.InCombatLockdown

local issecretvalue = _G.issecretvalue
local function IsSecretValue(value)
    if value == nil or not issecretvalue then
        return false
    end
    return issecretvalue(value) == true
end

local function LText(text)
    if type(text) ~= "string" then
        return text
    end
    local locale = KT.GetLocale and KT:GetLocale()
    return locale and locale[text] or text
end

local function GetConfig()
    return (KT.db.profile.enhancements and KT.db.profile.enhancements.combatTimer) or {}
end

local function FormatCombatTime(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local total = math.floor(seconds)
    local m = math.floor(total / 60)
    local s = total % 60
    return format("%d:%02d", m, s)
end

local state = {
    running = false,
    startedAt = nil,
    lastShown = nil,
    showUntil = nil,
}

local function UpdateFrameWidth(frame)
    local text = frame and frame.timerText
    if not (text and text.GetStringWidth) then return end

    -- The timer is text-only by default, so its frame (and Unlock Mode mover)
    -- should follow the rendered value instead of reserving a fixed 120 px.
    local width = tonumber(text:GetStringWidth())
    if width and width > 0 then
        frame:SetWidth(math.ceil(width))
    end
end

local function BuildUI()
    if Mod.combatTimerFrame then
        return Mod.combatTimerFrame
    end

    local f = CreateFrame("Frame", "KullThranUICombatTimer", UIParent, "BackdropTemplate")
    f:SetSize(1, 40)
    f:SetFrameStrata("LOW")
    f:SetFrameLevel(80)
    if KT.AddBackdrop then KT:AddBackdrop(f, 0.01, 0.01, 0.015, 0.78) end
    if KT.AddBorder then KT:AddBorder(f, 0.2, 0.2, 0.25, 0.9) end

    f.timerText = f:CreateFontString(nil, "OVERLAY")
    f.timerText:SetPoint("CENTER")
    f.timerText:SetJustifyH("CENTER")
    -- Always give the FontString a base font at creation: SetText before any
    -- style application throws "FontString:SetText(): Font not set".
    pcall(f.timerText.SetFont, f.timerText, "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    f.timerText:SetText("0:00")

    -- Visible at 0:00 when idle so the element can always be found/moved in
    -- Unlock Mode; the count starts on combat entry.
    f:Show()
    Mod.combatTimerFrame = f
    return f
end

local function ApplyStyle()
    local f = BuildUI()
    local config = GetConfig()
    local fs = f.timerText
    local font = "Fonts\\FRIZQT__.TTF"
    local size = tonumber(config.fontSize) or 22
    local flags = config.outline or "OUTLINE"
    local okFont = pcall(fs.SetFont, fs, font, size, flags)
    if not okFont or not fs.GetFont then
        pcall(fs.SetFont, fs, font, size, "OUTLINE")
    end

    UpdateFrameWidth(f)
    local color = config.color or { r = 1, g = 1, b = 1, a = 1 }
    fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    -- Fully remove the backdrop + border when the background toggle is off
    -- (SetBackdropColor alpha 0 was the intended route but the backdrop is a
    -- SetBackdrop texture, not f.backdrop).
    local showBg = config.showBackground == true
    local bg = config.backgroundColor or { r = 0.01, g = 0.01, b = 0.015, a = 0.78 }
    if f.SetBackdropColor then
        f:SetBackdropColor(bg.r or 0.01, bg.g or 0.01, bg.b or 0.015, showBg and (bg.a or 0.78) or 0)
    end
    if f._ktBackdropTexture then
        f._ktBackdropTexture:SetColorTexture(bg.r or 0.01, bg.g or 0.01, bg.b or 0.015, showBg and (bg.a or 0.78) or 0)
    end
    if f._ktBorderFrame then
        f._ktBorderFrame:SetShown(showBg)
    end
    local px = tonumber(config.scale) or 1
    f:SetScale(px)
end

function Mod:UpdateCombatTimerText(seconds)
    if IsSecretValue(seconds) then return end
    local fs = self.combatTimerFrame and self.combatTimerFrame.timerText
    if fs then
        local value = FormatCombatTime(seconds)
        if state.lastShown == value then return end
        -- SetText requires the FontString to have a valid font set; guard so a
        -- font never being applied cannot throw during refresh/init.
        local ok = pcall(fs.SetText, fs, value)
        if ok then
            state.lastShown = value
            UpdateFrameWidth(self.combatTimerFrame)
        end
    end
end

function Mod:ShowCombatTimer()
    local config = GetConfig()
    if config.enabled == false then return end
    BuildUI()
    ApplyStyle()
    self:ApplyCombatTimerPosition()
    self.combatTimerFrame:Show()
end

function Mod:HideCombatTimer()
    if self.combatTimerFrame then
        self.combatTimerFrame:Hide()
    end
end

function Mod:StartCombatTimer()
    BuildUI()
    ApplyStyle()
    self:ApplyCombatTimerPosition()
    state.running = true
    state.startedAt = GetTime()
    state.showUntil = nil
    self.combatTimerFrame:SetScript("OnUpdate", function()
        local current = GetTime()
        Mod:UpdateCombatTimerText(current - (state.startedAt or current))
    end)
    self.combatTimerFrame:Show()
    self:UpdateCombatTimerText(0)
end

function Mod:StopCombatTimer(showTotal)
    if not state.running then return end
    local total = GetTime() - (state.startedAt or GetTime())
    state.running = false
    if self.combatTimerFrame then
        self.combatTimerFrame:SetScript("OnUpdate", nil)
    end
    if showTotal ~= false then
        -- Keep the final total visible for a few seconds, then return to 0:00.
        self.combatTimerFrame:Show()
        self:UpdateCombatTimerText(total)
        state.showUntil = GetTime() + 3
        if not state._heldTimer then
            state._heldTimer = CreateFrame("Frame", nil, UIParent)
        end
        state._heldTimer:SetScript("OnUpdate", function(self, elapsed)
            if state.showUntil and GetTime() >= state.showUntil then
                if Mod.combatTimerFrame then
                    Mod:UpdateCombatTimerText(0)
                end
                state.showUntil = nil
                self:SetScript("OnUpdate", nil)
            end
        end)
    else
        self:UpdateCombatTimerText(0)
    end
end

function Mod:RegisterCombatTimerMover()
    if self.combatTimerMoverRegistered or not (KT and KT.RegisterMovableElements) then
        return
    end

    KT:RegisterMovableElements({
        {
            key = "ENH_COMBAT_TIMER",
            label = "Combat Timer",
            group = "Enhancements",
            getFrame = function() return Mod:GetCombatTimerFrame() end,
            getSize = function()
                local frame = Mod:GetCombatTimerFrame()
                if frame and frame.GetWidth then
                    return frame:GetWidth(), frame:GetHeight()
                end
                return 1, 40
            end,
            isHidden = function() return false end,
            loadPosition = function()
                local position = GetConfig().position
                return {
                    point = position and position.point or "CENTER",
                    relativePoint = position and position.relativePoint or "CENTER",
                    x = position and position.x or 0,
                    y = position and position.y or 150,
                }
            end,
            savePosition = function(_, point, relativePoint, x, y)
                GetConfig().position = {
                    point = point or "CENTER",
                    relativePoint = relativePoint or point or "CENTER",
                    x = x or 0,
                    y = y or 150,
                }
            end,
            applyPosition = function()
                Mod:ApplyCombatTimerPosition()
            end,
            applyPendingPosition = function(_, pos)
                local frame = Mod:GetCombatTimerFrame()
                frame:ClearAllPoints()
                frame:SetPoint(
                    pos and pos.point or "CENTER",
                    UIParent,
                    pos and pos.relativePoint or "CENTER",
                    pos and pos.x or 0,
                    pos and pos.y or 150
                )
            end,
        },
    })
    self.combatTimerMoverRegistered = true
end

function Mod:GetCombatTimerFrame()
    return BuildUI()
end

function Mod:ApplyCombatTimerPosition()
    local f = self:GetCombatTimerFrame()
    local config = GetConfig()
    local position = config.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 150 }
    f:ClearAllPoints()
    f:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER",
        tonumber(position.x) or 0, tonumber(position.y) or 150)
end

function Mod:RefreshCombatTimer()
    ApplyStyle()
    if state.running then
        if not self.combatTimerFrame then BuildUI() end
        self.combatTimerFrame:Show()
        self:UpdateCombatTimerText(GetTime() - (state.startedAt or GetTime()))
    end
end

function Mod:InitCombatTimer()
    BuildUI()
    ApplyStyle()
    self:ApplyCombatTimerPosition()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        state.running = true
        state.startedAt = GetTime()
        self.combatTimerFrame:SetScript("OnUpdate", function()
            local current = GetTime()
            Mod:UpdateCombatTimerText(current - (state.startedAt or current))
        end)
        self.combatTimerFrame:Show()
    end
end

local function OnClickHandler(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        Mod:StartCombatTimer()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Mod:StopCombatTimer()
    end
end

local function InstallHooks()
    if Mod._ktCombatTimerHooked then return end
    Mod._ktCombatTimerHooked = true
    local driver = CreateFrame("Frame", "KullThranUICombatTimerEvents", UIParent)
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:SetScript("OnEvent", OnClickHandler)
end

Mod._ktCombatTimerInit = function()
    local config = GetConfig()
    if config.enabled ~= false then
        InstallHooks()
        Mod:InitCombatTimer()
    end
end
