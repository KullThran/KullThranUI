-- ============================================================================
-- ENHANCEMENTS - AFK SCREEN
-- ============================================================================
-- Pantalla de ausencia: al marcarse AFK se oculta
-- la interfaz, la camara gira despacio y aparece una barra inferior con el
-- personaje, la hermandad, el tiempo ausente y el modelo del jugador. Cualquier
-- tecla (o entrar en combate, una cola de grupo o un campo de batalla) la cierra.
-- ============================================================================
local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then return end

local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local UIParent = _G.UIParent
local floor = math.floor
local format = string.format

local CAMERA_SPEED = 0.035
local DEFAULT_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
-- White KUI logo, tinted with the active style accent (same art Unlock Mode uses).
local LOGO_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png"

-- Idle emotes for the model; facing/idle values keep it looking at the camera.
Mod.AFK_ANIMATIONS = {
    { key = "dance", label = "Dance", id = 69, facing = 6, wait = 30, duration = 300 },
    { key = "salute", label = "Salute", id = 113, facing = 6, wait = 30, duration = 5 },
    { key = "talk", label = "Talk", id = 60, facing = 6.2, wait = 15, duration = 10 },
    { key = "shy", label = "Shy", id = 83, facing = 6.2, wait = 30, duration = 10 },
    { key = "roar", label = "Roar", id = 74, facing = 6, wait = 30, duration = 5 },
    { key = "lean", label = "Lean", id = 1260, facing = 5.8, wait = 10, duration = 600 },
}
local WAVE = { id = 67, facing = 6, wait = 40, duration = 2.3 }

local DEFAULTS = {
    enabled = true,
    spin = true,
    showModel = true,
    animation = "dance",
    modelScale = 1,
    showChat = true,
    showLogo = true,
    logoSize = 140,
    logoAlpha = 0.9,
    showFaction = true,
    showGuild = true,
    showTimer = true,
    classColorName = true,
    fontSize = 20,
    barHeight = 10,
    barColor = { r = 0.02, g = 0.02, b = 0.03, a = 0.85 },
}

local function LText(text)
    local locale = KT.GetLocale and KT:GetLocale()
    return locale and locale[text] or text
end

local function IsSecret(value)
    return value ~= nil and _G.issecretvalue and _G.issecretvalue(value) == true
end

function Mod:GetAFKConfig()
    local db = self:GetDB()
    db.afk = type(db.afk) == "table" and db.afk or {}
    for key, value in pairs(DEFAULTS) do
        if db.afk[key] == nil then
            db.afk[key] = type(value) == "table" and { r = value.r, g = value.g, b = value.b, a = value.a } or value
        end
    end
    return db.afk
end

local function GetAnimation(key)
    for _, anim in ipairs(Mod.AFK_ANIMATIONS) do
        if anim.key == key then return anim end
    end
    return Mod.AFK_ANIMATIONS[1]
end

local state = { active = false, preview = false }
local ui

local function FontPath()
    if KT.ResolveFontPath then
        local ok, path = pcall(KT.ResolveFontPath, KT, nil, DEFAULT_FONT)
        if ok and path then return path end
    end
    return DEFAULT_FONT
end

local function SetFont(fs, size)
    if not pcall(fs.SetFont, fs, FontPath(), size, "OUTLINE") then
        pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end
end

local function AccentColor()
    local palette = KT.GetStylePalette and KT:GetStylePalette() or KT.STYLE_PALETTE
    local accent = palette and palette.accent
    return (accent and accent.r) or KT.C_R or 1, (accent and accent.g) or KT.C_G or 0, (accent and accent.b) or KT.C_B or 0.33
end

-- ----------------------------------------------------------------------------
-- Chat (whispers and guild only)
-- ----------------------------------------------------------------------------
local CHAT_EVENTS = { "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_GUILD" }

local function Chat_OnEvent(self, event, message, sender)
    local chatType = event:sub(10)
    local info = _G.ChatTypeInfo and _G.ChatTypeInfo[chatType]
    local prefix = _G["CHAT_" .. chatType .. "_GET"] or "%s: "
    local ok, line = pcall(function()
        local name = sender
        if chatType ~= "BN_WHISPER" and _G.Ambiguate then name = _G.Ambiguate(sender, "short") end
        local link = chatType == "BN_WHISPER" and ("[" .. name .. "]")
            or format("|Hplayer:%s|h[%s]|h", sender, name)
        return format(prefix, link) .. message
    end)
    if ok and line then
        self:AddMessage(line, info and info.r or 1, info and info.g or 1, info and info.b or 1)
    end
end

local function Chat_OnMouseWheel(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
end

-- ----------------------------------------------------------------------------
-- Model animation loop: wave on entry, then the chosen emote with idle pauses
-- ----------------------------------------------------------------------------
local function PlayAnimation(model, anim)
    model.anim = anim
    model.startTime = GetTime()
    model.isIdle = nil
    pcall(model.SetFacing, model, anim.facing)
    pcall(model.SetAnimation, model, anim.id)
end

local function Model_OnUpdate(model)
    local anim = model.anim
    if not anim then return end
    local now = GetTime()
    if model.isIdle then
        if now - model.idleSince >= anim.wait then
            PlayAnimation(model, GetAnimation(Mod:GetAFKConfig().animation))
        end
    elseif now - model.startTime >= anim.duration then
        pcall(model.SetAnimation, model, 0)
        model.isIdle = true
        model.idleSince = now
    end
end

-- ----------------------------------------------------------------------------
-- Frames
-- ----------------------------------------------------------------------------
local function BuildUI()
    if ui then return ui end

    local f = CreateFrame("Frame", "KullThranUIAFKFrame")
    f:SetFrameStrata("FULLSCREEN")
    f:SetAllPoints(UIParent)
    f:EnableKeyboard(true)
    f:Hide()

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.line = bar:CreateTexture(nil, "BORDER")
    bar.line:SetPoint("TOPLEFT")
    bar.line:SetPoint("TOPRIGHT")
    bar.line:SetHeight(2)
    f.bar = bar

    bar.faction = bar:CreateTexture(nil, "ARTWORK")
    bar.faction:SetPoint("LEFT", bar, "LEFT", 8, 0)

    bar.name = bar:CreateFontString(nil, "OVERLAY")
    bar.guild = bar:CreateFontString(nil, "OVERLAY")
    bar.time = bar:CreateFontString(nil, "OVERLAY")
    for _, fs in ipairs({ bar.name, bar.guild, bar.time }) do
        SetFont(fs, 20)
        fs:SetJustifyH("LEFT")
    end

    -- Bottom-centre, rising out of the info bar. It lives on
    -- its own frame above the bar so the bar background never covers it.
    local logoFrame = CreateFrame("Frame", nil, f)
    logoFrame:SetAllPoints(f)
    logoFrame:SetFrameLevel(bar:GetFrameLevel() + 20)
    f.logo = logoFrame:CreateTexture(nil, "OVERLAY")
    f.logo:SetPoint("BOTTOM", bar, "BOTTOM", 0, 8)
    f.logo:SetTexture(LOGO_TEXTURE)

    -- Holder controls the model position; the model itself is oversized so
    -- animations never clip.
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetSize(150, 150)
    holder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -200, 220)
    local model = CreateFrame("PlayerModel", "KullThranUIAFKModel", holder)
    model:SetPoint("CENTER", holder)
    model:SetScript("OnUpdate", Model_OnUpdate)
    bar.model = model
    bar.modelHolder = holder

    local chat = CreateFrame("ScrollingMessageFrame", "KullThranUIAFKChat", f)
    chat:SetSize(500, 200)
    chat:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    SetFont(chat, 13)
    chat:SetJustifyH("LEFT")
    chat:SetMaxLines(500)
    chat:SetFading(false)
    chat:EnableMouseWheel(true)
    chat:SetScript("OnMouseWheel", Chat_OnMouseWheel)
    chat:SetScript("OnEvent", Chat_OnEvent)
    f.chat = chat

    f:SetScript("OnKeyDown", function(_, key)
        if key == "LALT" or key == "LSHIFT" or key == "RSHIFT" then return end
        if key == "PRINTSCREEN" and _G.Screenshot then
            _G.Screenshot()
            return
        end
        Mod:SetAFKScreen(false)
        -- Still flagged AFK: come back if nobody touches the game for a minute.
        if C_Timer then C_Timer.After(60, function() Mod:CheckAFKScreen() end) end
    end)

    ui = f
    return f
end

local function ApplyLayout()
    local f = BuildUI()
    local config = Mod:GetAFKConfig()
    local bar = f.bar
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local fontSize = tonumber(config.fontSize) or 20

    f:SetScale(UIParent:GetEffectiveScale())
    f:SetAllPoints(UIParent)

    local barHeight = floor(screenH * (tonumber(config.barHeight) or 10) / 100 + 0.5)
    bar:SetHeight(barHeight)
    local c = config.barColor or DEFAULTS.barColor
    bar.bg:SetColorTexture(c.r or 0, c.g or 0, c.b or 0, c.a or 0.85)
    bar.line:SetColorTexture(AccentColor())

    local faction = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    if faction ~= "Horde" and faction ~= "Alliance" then faction = "Panda" end
    local iconSize = barHeight * 1.3
    bar.faction:SetTexture(format("Interface\\Timer\\%s-Logo", faction))
    bar.faction:SetSize(iconSize, iconSize)
    bar.faction:SetShown(config.showFaction ~= false)

    for _, fs in ipairs({ bar.name, bar.guild, bar.time }) do SetFont(fs, fontSize) end
    bar.name:ClearAllPoints()
    if config.showFaction ~= false then
        bar.name:SetPoint("TOPLEFT", bar.faction, "TOPRIGHT", 0, -(iconSize - barHeight) / 2 - 8)
    else
        bar.name:SetPoint("TOPLEFT", bar, "TOPLEFT", 16, -8)
    end
    local name, realm = _G.UnitFullName and _G.UnitFullName("player")
    name = name or (_G.UnitName and _G.UnitName("player")) or ""
    realm = realm or (_G.GetRealmName and _G.GetRealmName()) or ""
    bar.name:SetText(realm ~= "" and (name .. "-" .. realm) or name)
    local _, class = _G.UnitClass("player")
    local cc = config.classColorName ~= false and class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
    if cc then bar.name:SetTextColor(cc.r, cc.g, cc.b) else bar.name:SetTextColor(1, 1, 1) end

    bar.guild:ClearAllPoints()
    bar.guild:SetPoint("TOPLEFT", bar.name, "BOTTOMLEFT", 0, -4)
    bar.guild:SetTextColor(0.7, 0.7, 0.7)
    bar.guild:SetShown(config.showGuild ~= false)
    bar.time:ClearAllPoints()
    bar.time:SetPoint("TOPLEFT", config.showGuild ~= false and bar.guild or bar.name, "BOTTOMLEFT", 0, -4)
    bar.time:SetTextColor(0.7, 0.7, 0.7)
    bar.time:SetShown(config.showTimer ~= false)

    local logoSize = tonumber(config.logoSize) or 140
    local accentR, accentG, accentB = AccentColor()
    f.logo:SetSize(logoSize, logoSize)
    f.logo:SetVertexColor(accentR, accentG, accentB, tonumber(config.logoAlpha) or 0.9)
    f.logo:SetShown(config.showLogo ~= false)

    local model = bar.model
    model:SetSize(screenW * 2, screenH * 2)
    pcall(model.SetCamDistanceScale, model, 4.5 / math.max(0.3, tonumber(config.modelScale) or 1))
    bar.modelHolder:SetShown(config.showModel ~= false)

    f.chat:SetShown(config.showChat ~= false)
end

local function UpdateTimer()
    if not (ui and state.startTime) then return end
    local elapsed = GetTime() - state.startTime
    ui.bar.time:SetText(format("%02d:%02d", floor(elapsed / 60), floor(elapsed % 60)))
end

local function UpdateGuild()
    if not ui then return end
    local guildName, rankName
    if _G.IsInGuild and _G.IsInGuild() and _G.GetGuildInfo then
        guildName, rankName = _G.GetGuildInfo("player")
    end
    if guildName then
        ui.bar.guild:SetText(rankName and (guildName .. "-" .. rankName) or guildName)
    else
        ui.bar.guild:SetText(LText("No Guild"))
    end
end

local function CameraSpin(on)
    if on then
        if _G.MoveViewLeftStart then _G.MoveViewLeftStart(CAMERA_SPEED) end
    elseif _G.MoveViewLeftStop then
        _G.MoveViewLeftStop()
    end
end

function Mod:SetAFKScreen(show, preview)
    local config = self:GetAFKConfig()
    if show then
        if state.active or InCombatLockdown() then return end
        local f = BuildUI()
        ApplyLayout()
        state.active, state.preview = true, preview == true
        state.spinning = config.spin ~= false
        if state.spinning then CameraSpin(true) end
        if not preview and _G.CloseAllWindows then pcall(_G.CloseAllWindows) end

        f:Show()
        UIParent:Hide()
        UpdateGuild()
        state.startTime = GetTime()
        UpdateTimer()
        state.ticker = C_Timer and C_Timer.NewTicker(1, UpdateTimer)

        if config.showModel ~= false then
            local model = f.bar.model
            model:SetUnit("player")
            PlayAnimation(model, WAVE)
        end
        if config.showChat ~= false then
            for _, event in ipairs(CHAT_EVENTS) do pcall(f.chat.RegisterEvent, f.chat, event) end
        end
    elseif state.active then
        state.active, state.preview = false, false
        if state.spinning then CameraSpin(false) end
        state.spinning = nil
        if state.ticker then state.ticker:Cancel(); state.ticker = nil end
        if ui then
            ui.chat:UnregisterAllEvents()
            ui.chat:Clear()
            ui.bar.model.anim = nil
            ui:Hide()
        end
        UIParent:Show()
    end
end

function Mod:PreviewAFKScreen()
    self:SetAFKScreen(true, true)
end

local function IsBlocked()
    if InCombatLockdown() then return true end
    if _G.CinematicFrame and _G.CinematicFrame:IsShown() then return true end
    if _G.MovieFrame and _G.MovieFrame:IsShown() then return true end
    if _G.C_PetBattles and _G.C_PetBattles.IsInBattle and _G.C_PetBattles.IsInBattle() then return true end
    return false
end

function Mod:CheckAFKScreen()
    local config = self:GetAFKConfig()
    if self:GetDB().enable == false or config.enabled == false then return end
    if state.preview then return end
    local afk = _G.UnitIsAFK and _G.UnitIsAFK("player")
    if IsSecret(afk) then return end
    if afk and not IsBlocked() then
        if _G.UnitCastingInfo and _G.UnitCastingInfo("player") then
            -- Crafting or similar: check again later instead of interrupting the view.
            if C_Timer then C_Timer.After(30, function() Mod:CheckAFKScreen() end) end
            return
        end
        self:SetAFKScreen(true)
    elseif not afk then
        self:SetAFKScreen(false)
    end
end

local driver = CreateFrame("Frame")
-- Combat always closes the screen, previews included, so the UI is never left hidden in combat.
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_FLAGS_CHANGED" then
        if arg1 == "player" then Mod:CheckAFKScreen() end
    elseif event == "UPDATE_BATTLEFIELD_STATUS" then
        if _G.GetBattlefieldStatus and _G.GetBattlefieldStatus(arg1) == "confirm" then Mod:SetAFKScreen(false) end
    else -- PLAYER_REGEN_DISABLED, LFG_PROPOSAL_SHOW
        Mod:SetAFKScreen(false)
    end
end)

function Mod:RefreshAFKScreen()
    local config = self:GetAFKConfig()
    local enabled = self:GetDB().enable ~= false and config.enabled ~= false
    for _, event in ipairs({ "PLAYER_FLAGS_CHANGED", "LFG_PROPOSAL_SHOW", "UPDATE_BATTLEFIELD_STATUS" }) do
        if enabled then pcall(driver.RegisterEvent, driver, event) else driver:UnregisterEvent(event) end
    end
    if not enabled and not state.preview then
        self:SetAFKScreen(false)
    elseif state.active then
        ApplyLayout()
    end
end

_G.hooksecurefunc(Mod, "RefreshSettings", function(self) self:RefreshAFKScreen() end)
