local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:GetModule("PartyFrames", true)
if not Mod then return end
local Styles = {}
ns.PF_Styles = Styles
Styles.tabs = {
    { id = "kui", label = "KUI" }, { id = "retail", label = "Retail" },
    { id = "forever", label = "Forever" }, { id = "classic", label = "Classic" },
}
local valid = { kui = true, retail = true, forever = true, classic = true }
-- Blizzard PartyFrameTemplates.xml and Mainline PartyMemberFrame.lua.
-- Retail atlas pixels: UiTextureAtlasMember 17762 / UiTextureAtlas 2087.
-- Forever: party ornament in the bundled client sheet (120x49, bottom-left).
Styles.geometry = {
    retail = { w = 120, h = 53, artW = 120, artH = 49, artX = 1, artY = 2,
        portrait = { 7, 6, 37 }, health = { 45, 19, 70, 10 }, power = { 41, 30, 74, 7 }, name = { 46, 6, 66 } },
    forever = { w = 120, h = 53, artW = 120, artH = 49, artX = 1, artY = 2,
        portrait = { 7, 6, 37 }, health = { 45, 19, 70, 10 }, power = { 41, 30, 74, 7 }, name = { 46, 6, 66 } },
    classic = { w = 128, h = 53, artW = 128, artH = 64, artX = 0, artY = 2,
        portrait = { 7, 6, 37 }, health = { 47, 12, 70, 8 }, power = { 47, 21, 70, 8 }, name = { 47, 0, 70 } },
}
function Styles.Current()
    if Styles.pendingStyle and InCombatLockdown and InCombatLockdown() then return Styles.previousStyle end
    local choice = Mod.db and Mod.db.partyFrameStyle
    if valid[choice] then return choice end
    local vt = KT.VisualThemes
    local theme = vt and vt.GetRenderedTheme and vt:GetRenderedTheme()
    return valid[theme] and theme or "kui"
end
-- Each theme starts with its own overlay default and retains explicit changes.
local GetModeDB = Mod.GetModeDB
function Mod:GetModeDB(mode)
    local cfg = GetModeDB(self, mode)
    if mode == "party" and cfg then
        self.db.partyDispelOverlayByStyle = self.db.partyDispelOverlayByStyle or {}
        local key = Styles.Current()
        -- The native card art is built around the portrait: with the portrait
        -- off it would fall back to the KUI look. Turn it on while a native style
        -- is active and give KUI back its own setting afterwards.
        if key == "kui" then
            local before = self.db._pfPortraitBeforeNative
            if before then
                cfg.showPortrait, cfg.portraitStyle = before.show, before.style
                self.db._pfPortraitBeforeNative = nil
            end
        else
            if cfg.showPortrait ~= true or cfg.portraitStyle == "none" then
                if not self.db._pfPortraitBeforeNative then
                    self.db._pfPortraitBeforeNative = { show = cfg.showPortrait, style = cfg.portraitStyle }
                end
                cfg.showPortrait = true
                if cfg.portraitStyle == nil or cfg.portraitStyle == "none" then cfg.portraitStyle = "circular" end
            end
        end
        local saved = self.db.partyDispelOverlayByStyle
        if saved[key] == nil then saved[key] = key == "kui" end
        cfg.showDispelOverlay = saved[key]
        -- Independent defaults prevent repeated scaling or resizing KUI when
        -- selecting a native theme. Explicit size edits belong to that theme.
        local sizes = self.db.partyFrameSizesByStyle
        if not sizes then
            sizes = {}
            local width, height = tonumber(cfg.frameWidth) or 235, tonumber(cfg.frameHeight) or 41
            for _, style in ipairs(Styles.tabs) do
                local factor = style.id == "kui" and 1 or 1.25
                sizes[style.id] = { frameWidth = width * factor, frameHeight = height * factor }
            end
            self.db.partyFrameSizesByStyle = sizes
        end
        if not self.db.partyNativeSize25V2 then
            for _, native in ipairs({"classic", "retail", "forever"}) do
                local saved = sizes[native]
                if saved then
                    saved.frameWidth = saved.frameWidth * 1.25
                    saved.frameHeight = saved.frameHeight * 1.25
                end
            end
            self.db.partyNativeSize25V2 = true
        end
        local size = sizes[key]
        cfg.frameWidth, cfg.frameHeight = size.frameWidth, size.frameHeight
        if not self.db.partyHealthColorsByStyle then
            local colors = {}
            for _, style in ipairs(Styles.tabs) do
                local c = cfg.customHealthColor or { r = 0.10, g = 0.90, b = 0.10 }
                colors[style.id] = { colorByClass = cfg.colorByClass ~= false,
                    customHealthColor = { r = c.r, g = c.g, b = c.b } }
            end
            self.db.partyHealthColorsByStyle = colors
        end
        local color = self.db.partyHealthColorsByStyle[key]
        cfg.colorByClass, cfg.customHealthColor = color.colorByClass, color.customHealthColor
    end
    return cfg
end
local SetConfigValue = Mod.SetConfigValue
if SetConfigValue then
    function Mod:SetConfigValue(mode, key, value)
        if mode == "party" and key == "showDispelOverlay" then
            self:GetModeDB(mode)
            self.db.partyDispelOverlayByStyle[Styles.Current()] = value == true
        end
        if mode == "party" and (key == "frameWidth" or key == "frameHeight") then
            self:GetModeDB(mode)
            self.db.partyFrameSizesByStyle[Styles.Current()][key] = value
        end
        if mode == "party" and (key == "colorByClass" or key == "customHealthColor") then
            Styles.GetHealthSettings(Styles.Current())[key] = value
        end
        return SetConfigValue(self, mode, key, value)
    end
end
function Styles.GetHealthSettings(key)
    Mod:GetModeDB("party")
    return Mod.db.partyHealthColorsByStyle[key or Styles.Current()]
end
function Styles.SetHealthColor(key, classColored, color)
    if not valid[key] then return end
    local settings = Styles.GetHealthSettings(key)
    settings.colorByClass = classColored == true
    if color then settings.customHealthColor = { r = color.r, g = color.g, b = color.b } end
    if key == Styles.Current() then
        Mod:GetModeDB("party")
        Mod:RefreshAll()
    end
end
function Styles.Select(key)
    if not valid[key] then return false end
    Mod:EnsureDB()
    local previous = Styles.Current()
    Mod.db.partyFrameStyle = key
    if InCombatLockdown and InCombatLockdown() then
        Styles.previousStyle, Styles.pendingStyle = previous, true
        Mod.pendingAll = true
        return true, "combat"
    end
    Styles.pendingStyle = nil
    Mod:RefreshAll() -- ApplyLayout defers protected work during combat.
    return true
end
function Styles.PreviewCardLevel(frame, key, fit)
    if not (frame.levelText and frame.portraitFrame) then return end
    frame.levelText:ClearAllPoints()
    if key == "kui" then
        frame.levelText:SetJustifyH("CENTER")
        frame.levelText:SetPoint("TOP", frame.portraitFrame, "TOP", 0, -2 * fit)
    else
        -- PlaceBadges centers the text; native cards need left-aligned digits.
        frame.levelText:SetJustifyH("LEFT")
        frame.levelText:SetPoint("BOTTOMLEFT", frame.portraitFrame, "BOTTOMLEFT", 2 * fit, 3 * fit)
    end
end
function Styles.Geometry(key, width, height)
    local g = Styles.geometry[key]
    if not g then return end
    local scale = math.min(width / g.w, height / g.h)
    return g, scale, (width - g.w * scale) * 0.5, (height - g.h * scale) * 0.5
end
function Styles.SetArt(texture, key)
    texture:SetVertexColor(1, 1, 1, 1)
    if key == "classic" then
        texture:SetTexture("Interface\\TargetingFrame\\UI-PartyFrame")
        texture:SetTexCoord(0, 1, 0, 1)
    elseif key == "forever" then
        texture:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\forever_unitframe.tga")
        texture:SetTexCoord(1 / 256, 121 / 256, 457 / 512, 506 / 512)
    else
        -- Explicit Retail sheet: Forever remaps this atlas name to bronze artwork.
        texture:SetTexture(4681512)
        texture:SetTexCoord(123 / 256, 243 / 256, 57 / 256, 106 / 256)
    end
end
local function Box(region, parent, x, y, w, h, s)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x * s, -y * s)
    region:SetSize(w * s, h * s)
end
local function Font(region, size)
    if not (region and region.GetFont) then return end
    local path, _, outline = region:GetFont()
    if path then region:SetFont(path, math.max(6, size), outline) end
end
local function BarMask(bar, host, key, s, isPower)
    local fill = bar:GetStatusBarTexture()
    local mask = bar._pfNativeMask
    if key == "classic" then
        if mask then
            if fill and fill.RemoveMaskTexture then fill:RemoveMaskTexture(mask) end
            if bar.bg and bar.bg.RemoveMaskTexture then bar.bg:RemoveMaskTexture(mask) end
            mask:Hide()
            bar._pfNativeFill, bar._pfNativeBGMasked = nil, nil
        end
        return
    end
    if not mask then mask = host:CreateMaskTexture(); bar._pfNativeMask = mask end
    mask:SetTexture(isPower and 4737298 or 4737301, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    -- Native masks are 128x16, offset relative to the complete party frame.
    Box(mask, host, isPower and 14 or 16, isPower and 26 or 16, 128, 16, s)
    mask:Show()
    if fill and bar._pfNativeFill ~= fill then
        if bar._pfNativeFill then bar._pfNativeFill:RemoveMaskTexture(mask) end
        fill:AddMaskTexture(mask)
        bar._pfNativeFill = fill
    end
    if bar.bg and not bar._pfNativeBGMasked then
        bar.bg:AddMaskTexture(mask)
        bar._pfNativeBGMasked = true
    end
end
-- Highlight only the opaque atlas pixels, not the secure button's layout box.
function Styles.ConfigureHover(frame, key, host, g, scale)
    local hover = frame.hover
    if not hover then return end
    hover:ClearAllPoints()
    if host and g then
        Styles.SetArt(hover, key)
        Box(hover, host, g.artX, g.artY, g.artW, g.artH, scale)
        hover:SetBlendMode("ADD")
        hover:SetVertexColor(1, 1, 1, 0.16)
    else
        hover:SetAllPoints(frame)
        hover:SetBlendMode("BLEND")
        hover:SetColorTexture(1, 1, 1, 0.08)
    end
end
function Styles.Clear(frame)
    Styles.ConfigureHover(frame, "kui")
    if frame._pfNativeArt then frame._pfNativeArt:Hide() end
    for _, bar in ipairs({ frame.health, frame.power }) do
        local mask = bar and bar._pfNativeMask
        if mask then
            local fill = bar:GetStatusBarTexture()
            if fill and fill.RemoveMaskTexture then fill:RemoveMaskTexture(mask) end
            if bar.bg and bar.bg.RemoveMaskTexture then bar.bg:RemoveMaskTexture(mask) end
            mask:Hide()
            bar._pfNativeFill, bar._pfNativeBGMasked = nil, nil
        end
    end
    if frame.absorb and frame.health._pfNativeMask then
        local fill = frame.absorb:GetStatusBarTexture()
        if fill then fill:RemoveMaskTexture(frame.health._pfNativeMask) end
        frame.absorb._pfNativeFill = nil
    end
    if frame.bgKT then frame.bgKT:Show() end
    if frame.SetBackdropColor and frame._ktBackdropColor then
        local c = frame._ktBackdropColor
        frame:SetBackdropColor(c.r, c.g, c.b, c.a)
    end
    if frame.borderKT then frame.borderKT:Show() end
    if frame.portraitBorderFrame then frame.portraitBorderFrame:Show() end
    local name = frame.nameText or frame.name
    if name then name:SetTextColor(1, 1, 1, 1) end
    if frame._pfNativePortraitMask then
        for _, texture in ipairs({ frame.portrait, frame.portraitBG, frame.portraitClass }) do
            texture:RemoveMaskTexture(frame._pfNativePortraitMask)
        end
        frame._pfNativePortraitMask:Hide()
        frame._pfNativePortraitMaskApplied = nil
        -- Undo the native outset so the KUI portrait fills its own slot again.
        for _, texture in ipairs({ frame.portrait, frame.portraitBG }) do
            texture:ClearAllPoints()
            texture:SetAllPoints(frame.portraitFrame)
        end
        if frame.portraitClass then
            frame.portraitClass:ClearAllPoints()
            frame.portraitClass:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", 2, -2)
            frame.portraitClass:SetPoint("BOTTOMRIGHT", frame.portraitFrame, "BOTTOMRIGHT", -2, 2)
        end
        if frame.portraitModel and ns.PF_Portrait.AnchorModel and ns.PF_Portrait.GetMetrics then
            ns.PF_Portrait.AnchorModel(frame, ns.PF_Portrait.GetMetrics(Mod.db, frame:GetHeight()))
        end
    end
    if frame._pfNativePowerText then frame._pfNativePowerText:Hide() end
    local wasNative = frame._pfNativeStyle
    frame._pfNativeStyle = nil
    if wasNative and frame.ktAuraContainers and frame._ktAuraBuildDB and ns.PF_UpdateAuraContainers then
        ns.PF_UpdateAuraContainers(frame, frame._ktAuraBuildDB)
    end
end
function Styles.UpdatePowerText(frame, cfg, preview)
    local powerText = frame and frame._pfNativePowerText
    if not (powerText and frame._pfNativeStyle) then return end
    if preview or frame.fakeUnit then
        local current = frame.power:GetValue()
        local _, maximum = frame.power:GetMinMaxValues()
        powerText:SetFormattedText("%d / %d", current or 0, maximum or 100)
    elseif frame.unit and UnitPower and UnitPowerMax then
        powerText:SetFormattedText("%s / %s", UnitPower(frame.unit), UnitPowerMax(frame.unit))
    else
        powerText:SetText("")
    end
    powerText:SetShown(cfg.showPowerBar == true and frame.power:IsShown())
end
function Styles.PreviewIconLayers(frame)
    local host = frame.auraFrame
    if not host then return end
    local level = math.max(frame.health:GetFrameLevel(), frame.power:GetFrameLevel(),
        frame.portraitFrame and frame.portraitFrame:GetFrameLevel() or 0,
        frame.ringFrame and frame.ringFrame:GetFrameLevel() or 0) + 10
    host:SetFrameLevel(level)
    for _, pool in ipairs({ frame.buffIcons or {}, frame.debuffIcons or {}, { frame.ccIcon, frame.missingBuffIcon } }) do
        for _, icon in ipairs(pool) do
            -- Moving the host does not reliably reset previously assigned child levels.
            icon:SetFrameLevel(level + 1)
        end
    end
end
-- Generic status anchors use the large KUI button, not the native bar opening.
function Styles.LayoutStatusIndicators(frame, g, scale)
    local icon = frame.statusIcon
    local status = frame.statusText or frame.status
    local value = frame.valueText or frame.value
    if icon and status and value then
        local size = math.min(10, g.health[4]) * scale
        local gap = 2 * scale
        local hasLabel = status:IsShown()
        local active = icon:IsShown()
        -- AFK is a wide texture; its health value remains visible beside it.
        local iconWidth = (active and not hasLabel) and size * 2 or size
        local text = hasLabel and status or value
        local textWidth = math.max(1, math.min(40 * scale, g.health[3] * scale - iconWidth - gap))
        -- Native styles keep the state icon on the portrait; only the label
        -- (Dead, Offline) stays on the health bar.
        local portrait = frame.portraitFrame
        local onPortrait = portrait and portrait.GetWidth and portrait:GetWidth() > 0
        if onPortrait then
            local pw = portrait:GetWidth()
            size = math.max(10, pw * 0.5)
            iconWidth = (active and not hasLabel) and math.min(size * 2, pw * 0.9) or size
            textWidth = math.max(1, math.min(g.health[3] * scale, 90 * scale))
        end
        if active then
            text:ClearAllPoints()
            text:SetPoint("CENTER", frame.health, "CENTER", onPortrait and 0 or (iconWidth + gap) * 0.5, 0)
            text:SetSize(textWidth, g.health[4] * scale)
            text:SetJustifyH("CENTER")
        end
        icon:ClearAllPoints()
        icon:SetSize(iconWidth, size)
        icon:SetTexCoord(0, 1, 0, 1)
        if onPortrait then
            icon:SetPoint("CENTER", portrait, "CENTER", 0, 0)
        else
            icon:SetPoint("RIGHT", text, "LEFT", -gap, 0)
        end
        if frame.statusIconFrame then
            local level = frame.health:GetFrameLevel() + 2
            if onPortrait and portrait.GetFrameLevel then
                level = math.max(level, portrait:GetFrameLevel() + 8)
            end
            frame.statusIconFrame:SetFrameLevel(level)
        end
    end
    if frame.readyCheckIcon then
        -- The ready check has its own slot beside the bars, away from the portrait.
        frame.readyCheckIcon:ClearAllPoints()
        frame.readyCheckIcon:SetScale(1)
        frame.readyCheckIcon:SetSize(12 * scale, 12 * scale)
        frame.readyCheckIcon:SetPoint("LEFT", frame.health, "RIGHT", 3 * scale, 0)
    end
end
function Styles.ApplyReadableFills(frame, key)
    key = key or frame._pfNativeStyle or Styles.Current()
    if key == "kui" then return end
    local modern = key == "retail" or key == "forever"
    for _, bar in ipairs({frame.health, frame.power}) do
        local atlas = modern and (bar == frame.health
            and "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status"
            or "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana-Status")
        -- Neutral native variants preserve the actual Party gradient and ends
        -- while allowing custom/class colours without multiplying green/blue.
        bar:SetStatusBarTexture(atlas or "Interface\\TargetingFrame\\UI-StatusBar")
        local fill = bar:GetStatusBarTexture()
        if not modern then fill:SetTexCoord(0, 1, 0, 1) end
        if fill.SetDesaturated then fill:SetDesaturated(false) end
        local r, g, b = bar:GetStatusBarColor()
        if bar == frame.power then
            local token
            if frame.unit and not frame.fakeUnit and UnitPowerType then
                local ok, _, value = pcall(UnitPowerType, frame.unit)
                if ok and not (issecretvalue and issecretvalue(value)) then token = value end
            end
            local resources = { MANA = "Mana", RAGE = "Rage", ENERGY = "Energy", FOCUS = "Focus", RUNIC_POWER = "RunicPower" }
            local resource = resources[token or "MANA"]
            if modern and resource then
                bar:SetStatusBarTexture("UI-HUD-UnitFrame-Party-PortraitOn-Bar-" .. resource)
                r, g, b = 1, 1, 1 -- colour is already in the native resource pixels
            elseif PowerBarColor and PowerBarColor[token] then
                local c = PowerBarColor[token]; r, g, b = c.r, c.g, c.b
            end
        end
        bar:SetStatusBarColor(r, g, b, 1)
    end
end
function Styles.LayoutPvP(frame, opts, g, scale, preview)
    if not frame or not frame.pvpIcon or not frame.portraitFrame then return end
    if frame.mode and frame.mode ~= "party" then return end
    g, scale = g or frame._pfNativeGeometry, scale or frame._pfNativeScale
    if not g or not scale then return end
    opts = opts or Mod.db or {}
    if opts.pvpAnchor and opts.pvpAnchor ~= "AUTO" then return end
    -- Live secure child-frame anchors stay installed throughout combat.
    if not preview and InCombatLockdown and InCombatLockdown() then return end
    frame.pvpIcon:ClearAllPoints()
    frame.pvpIcon:SetPoint("CENTER", frame.portraitFrame, "BOTTOMLEFT",
        3 * scale + (frame._pfNativePad or 0) - (frame._pfNativeShift or 0) + (tonumber(opts.pvpX) or 0),
        3 * scale + (frame._pfNativePad or 0) + (tonumber(opts.pvpY) or 0))
end
function Styles.HideNativePartyReminder(frame, mode, key)
    if mode == "party" and (key == "classic" or key == "retail" or key == "forever") then
        if frame.missingBuffIcon then frame.missingBuffIcon:Hide() end
    end
end
-- FontString/texture updates are safe during combat; secure child-frame geometry
-- must remain the layout installed by PositionFrame before lockdown.
function Styles.UpdateHealthText(frame, cfg, g, s)
    if not frame or (frame.mode and frame.mode ~= "party") then return end
    g, s = g or frame._pfNativeGeometry, s or frame._pfNativeScale
    if not g or not s or (not frame._pfNativeStyle and not frame._pfNativeArt) then return end
    for _, text in ipairs({ frame.valueText or frame.value, frame.statusText or frame.status }) do
        text:ClearAllPoints()
        text:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        text:SetSize(g.health[3] * s, g.health[4] * s)
        text:SetJustifyH("CENTER")
        Font(text, math.min(tonumber(cfg.healthTextFontSize) or 10, 8 * s))
    end
    Styles.LayoutStatusIndicators(frame, g, s)
end
function Styles.UpdateNativeVisual(frame, cfg, preview, g, s, key)
    Styles.ApplyReadableFills(frame, key)
    Styles.UpdateHealthText(frame, cfg, g, s)
    Styles.UpdatePowerText(frame, cfg, preview)
end
function Styles.Apply(frame, cfg, mode, preview, allowCreate, styleOverride)
    local key = styleOverride or Styles.Current()
    Styles.HideNativePartyReminder(frame, mode, key)
    if not preview and mode == "party" and key ~= "kui" and cfg.showPortrait == true
        and cfg.portraitStyle ~= "none" and InCombatLockdown and InCombatLockdown() then
        if frame._pfNativeStyle and frame._pfNativeGeometry then
            Styles.UpdateNativeVisual(frame, cfg, false, frame._pfNativeGeometry, frame._pfNativeScale)
        end
        return
    end
    if preview and mode == "party" and key ~= "kui" then
        -- Native theme previews show the frame art without sample icon clutter.
        for _, pool in ipairs({ frame.buffIcons or {}, frame.debuffIcons or {} }) do
            for _, icon in ipairs(pool) do icon:Hide() end
        end
        for _, field in ipairs({ "ccIcon", "missingBuffIcon", "roleIcon", "leaderIcon",
            "raidTargetIcon", "readyCheckIcon", "statusIcon", "pvpIcon" }) do
            if frame[field] then frame[field]:Hide() end
        end
    end
    if key == "kui" then
        local base = frame:GetFrameLevel()
        -- The circular portrait overlaps the bars: keep its full face and ring visible.
        frame.health:SetFrameLevel(base + 2)
        frame.power:SetFrameLevel(base + 2)
        if frame.absorb then frame.absorb:SetFrameLevel(base + 3) end
        local portraitLevel = math.max(base + 4,
            frame.dispelBorderFrame and frame.dispelBorderFrame:GetFrameLevel() + 1 or 0)
        frame.portraitFrame:SetFrameLevel(portraitLevel)
        if frame.portraitFrame.SetFrameStrata and frame.health.GetFrameStrata then
            frame.portraitFrame:SetFrameStrata(frame.health:GetFrameStrata())
        end
        if frame.portraitModel then frame.portraitModel:SetFrameLevel(portraitLevel + 1) end
        if frame.portraitBorderFrame then frame.portraitBorderFrame:SetFrameLevel(portraitLevel + 3) end
        if frame.model3D then frame.model3D:SetFrameLevel(portraitLevel + 1) end
        if frame.ringFrame then frame.ringFrame:SetFrameLevel(portraitLevel + 3) end
        if frame.overlayFrame then frame.overlayFrame:SetFrameLevel(portraitLevel + 4) end
        if preview then Styles.PreviewIconLayers(frame)
        elseif frame.auraFrame then frame.auraFrame:SetFrameLevel(portraitLevel + 6) end
    end
    if mode ~= "party" or key == "kui" or cfg.showPortrait ~= true or cfg.portraitStyle == "none" then
        if frame._pfNativeStyle then Styles.Clear(frame) end
        return
    end
    local g, s, x, y = Styles.Geometry(key, frame:GetWidth(), frame:GetHeight())
    if not g then return end
    local host = frame._pfNativeArt
    if not host then
        if not allowCreate then return end
        host = CreateFrame("Frame", nil, frame)
        host:EnableMouse(false)
        host.texture = host:CreateTexture(nil, "OVERLAY")
        frame._pfNativeArt = host
    end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    host:SetSize(g.w * s, g.h * s)
    Styles.SetArt(host.texture, key)
    Box(host.texture, host, g.artX, g.artY, g.artW, g.artH, s)
    Styles.ConfigureHover(frame, key, host, g, s)
    host:Show()
    local base = frame:GetFrameLevel()
    frame.health:SetFrameLevel(base + 5)
    frame.power:SetFrameLevel(base + 5)
    frame.portraitFrame:SetFrameLevel(base + 1)
    if frame.portraitModel then frame.portraitModel:SetFrameLevel(base + 2) end
    if frame.model3D then frame.model3D:SetFrameLevel(base + 2) end
    host:SetFrameLevel(base + 4)
    if frame.overlayFrame then frame.overlayFrame:SetFrameLevel(base + 6) end
    if frame.auraFrame then frame.auraFrame:SetFrameLevel(base + 8) end
    if frame.portraitBorder then frame.portraitBorder:Hide() end
    if frame.portraitBorderFrame then frame.portraitBorderFrame:Hide() end
    if frame.ringTexture then frame.ringTexture:Hide() end
    if frame.borderKT then frame.borderKT:Hide() end
    if frame.bgKT then frame.bgKT:Hide() end
    if frame.SetBackdropColor then frame:SetBackdropColor(0, 0, 0, 0) end
    Box(frame.health, host, g.health[1], g.health[2], g.health[3], g.health[4], s)
    Box(frame.power, host, g.power[1], g.power[2], g.power[3], g.power[4], s)
    -- Atlas fills already contain green/blue pixels. Tinting them by class or
    -- resource multiplies incompatible channels and can make bars almost black.
    -- Keep the native art/masks, with a neutral luminance fill beneath the text.
    Styles.ApplyReadableFills(frame, key)

    frame.power:SetShown(cfg.showPowerBar == true)
    local p = g.portrait
    local size = math.max(16, p[3] * s + (tonumber(cfg.portraitSize) or 0))
    -- The ring opening is wider than the portrait slot and the portrait frame
    -- clips its children, so the frame itself grows to the opening (same centre).
    local pad = size * 0.095
    local shift = size * 0.03 -- the opening sits slightly right of the slot centre
    frame._pfNativePad, frame._pfNativeShift = pad, shift
    Box(frame.portraitFrame, host, p[1] + (tonumber(cfg.portraitX) or 0) / s - pad / s + shift / s,
        p[2] - (tonumber(cfg.portraitY) or 0) / s - pad / s, (size + 2 * pad) / s, (size + 2 * pad) / s, s)
    local portraitMask = frame._pfNativePortraitMask
    if not portraitMask then
        portraitMask = frame.portraitFrame:CreateMaskTexture()
        portraitMask:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_mask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        portraitMask:SetAllPoints(frame.portraitFrame)
        frame._pfNativePortraitMask = portraitMask
    end
    if not frame._pfNativePortraitMaskApplied then
        for _, texture in ipairs({ frame.portrait, frame.portraitBG, frame.portraitClass }) do texture:AddMaskTexture(portraitMask) end
        frame._pfNativePortraitMaskApplied = true
    end
    portraitMask:Show()
    local model = frame.portraitModel or frame.model3D
    if model then
        -- The ring frame draws above the model and covers its square corners, so
        -- the model can fill the circle instead of leaving a visible gap.
        local inset = math.floor(size * 0.13 + 0.5)
        model:ClearAllPoints()
        model:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", inset, -inset)
        model:SetPoint("BOTTOMRIGHT", frame.portraitFrame, "BOTTOMRIGHT", -inset, inset)
    end
    BarMask(frame.health, host, key, s, false)
    BarMask(frame.power, host, key, s, true)
    local name = frame.nameText or frame.name
    local value = frame.valueText or frame.value
    local status = frame.statusText or frame.status
    Box(name, host, g.name[1], g.name[2], g.name[3], 11, s)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1, 0.82, 0.15, 1)
    Font(name, math.min(tonumber(cfg.nameFontSize) or 11, 10 * s))
    Styles.UpdateNativeVisual(frame, cfg, preview, g, s, key)
    if frame.absorb then
        frame.absorb:ClearAllPoints(); frame.absorb:SetAllPoints(frame.health)
        frame.absorb:SetFrameLevel(base + 6)
        local fill = frame.absorb:GetStatusBarTexture()
        local mask = frame.health._pfNativeMask
        if fill and mask then
            if key == "classic" then
                fill:RemoveMaskTexture(mask)
                frame.absorb._pfNativeFill = nil
            elseif frame.absorb._pfNativeFill ~= fill then
                fill:AddMaskTexture(mask)
                frame.absorb._pfNativeFill = fill
            end
        end
    end
    if frame.leaderIcon then
        frame.leaderIcon:ClearAllPoints()
        frame.leaderIcon:SetPoint("BOTTOMLEFT", name, "TOPLEFT", 0, 1)
    end
    if frame.roleIcon then
        frame.roleIcon:ClearAllPoints()
        frame.roleIcon:SetPoint("TOPRIGHT", host, "TOPRIGHT", -3 * s, -3 * s)
        frame.roleIcon:SetSize(10 * s, 10 * s)
    end
    if frame.levelText and (not Mod.db or not Mod.db.levelAnchor or Mod.db.levelAnchor == "AUTO") then
        frame.levelText:ClearAllPoints()
        frame.levelText:SetPoint("BOTTOM", frame.portraitFrame, "BOTTOM", (Mod.db and Mod.db.levelX or 0) - (frame._pfNativeShift or 0), -2 * s + (frame._pfNativePad or 0) + (Mod.db and Mod.db.levelY or 0))
    end
    Styles.LayoutPvP(frame, Mod.db, g, s, preview)
    if not frame._pfNativePowerText then
        frame._pfNativePowerText = frame.overlayFrame:CreateFontString(nil, "OVERLAY")
    end
    local powerText = frame._pfNativePowerText
    local font, _, outline = value:GetFont()
    if font then powerText:SetFont(font, math.max(6, 7 * s), outline) end
    powerText:SetTextColor(1, 1, 1, 1)
    powerText:ClearAllPoints(); powerText:SetPoint("CENTER", frame.power, "CENTER", 0, 0)
    powerText:SetSize(g.power[3] * s, g.power[4] * s)
    local wasNative = frame._pfNativeStyle
    frame._pfNativeStyle = key
    frame._pfNativeGeometry, frame._pfNativeScale = g, s
    if not wasNative and frame.ktAuraContainers and ns.PF_UpdateAuraContainers then
        ns.PF_UpdateAuraContainers(frame, cfg)
    end
    Styles.UpdatePowerText(frame, cfg, preview)
    if preview then Styles.PreviewIconLayers(frame) end
end
-- Generic portrait refreshes must not replace native AUTO badge anchors.
local PlaceBadges = ns.PF_Portrait.PlaceBadges
if PlaceBadges then
    ns.PF_Portrait.PlaceBadges = function(frame, opts)
        if frame and frame.mode == "party" and frame._pfNativeStyle and Styles.Current() ~= "kui"
            and (not opts or not opts.pvpAnchor or opts.pvpAnchor == "AUTO") then
            local nativeOpts = {}
            for k, v in pairs(opts or {}) do nativeOpts[k] = v end
            nativeOpts.pvpAnchor = "NATIVE"
            PlaceBadges(frame, nativeOpts)
            Styles.LayoutPvP(frame, opts)
        else
            PlaceBadges(frame, opts)
        end
    end
end
-- Both paths use the same skin, including fake units and early-return status states.
-- Live KUI frames must preserve the same complete portrait as their preview.
ns.PF_Portrait.IsBelowHealth = function() return false end
local PositionFrame = Mod.PositionFrame
function Mod:PositionFrame(frame, parent, index, count, mode, visibleCount, layoutKind)
    local result = PositionFrame(self, frame, parent, index, count, mode, visibleCount, layoutKind)
    Styles.Apply(frame, self:GetModeDB(mode or "party"), mode or "party", false, true)
    return result
end
local UpdateFrameVisual = Mod.UpdateFrameVisual
function Mod:UpdateFrameVisual(frame, ...)
    local result = UpdateFrameVisual(self, frame, ...)
    if frame then Styles.Apply(frame, self:GetModeDB(frame.mode or "party"), frame.mode or "party", false, false) end
    return result
end

-- Aura events can update reminders without a full visual refresh.
local UpdateFrameAuras = Mod.UpdateFrameAuras
function Mod:UpdateFrameAuras(frame, ...)
    local result = UpdateFrameAuras(self, frame, ...)
    if frame then Styles.HideNativePartyReminder(frame, frame.mode or "party", Styles.Current()) end
    return result
end

local UpdateFramePowerEvent = Mod.UpdateFramePowerEvent
if UpdateFramePowerEvent then
    function Mod:UpdateFramePowerEvent(frame, event)
        local result = UpdateFramePowerEvent(self, frame, event)
        if frame then
            if frame.mode == "party" and frame._pfNativeStyle and event == "UNIT_DISPLAYPOWER" then Styles.ApplyReadableFills(frame) end
            Styles.UpdatePowerText(frame, self:GetModeDB(frame.mode or "party"), false)
        end
        return result
    end
end
