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
function Styles.Clear(frame)
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
    end
    if frame._pfNativePowerText then frame._pfNativePowerText:Hide() end
    frame._pfNativeStyle = nil
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
function Styles.Apply(frame, cfg, mode, preview, allowCreate, styleOverride)
    local key = styleOverride or Styles.Current()
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
    host:Show()
    local base = frame:GetFrameLevel()
    frame.health:SetFrameLevel(base + 2)
    frame.power:SetFrameLevel(base + 2)
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
    if key == "classic" then
        frame.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        frame.power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    elseif key == "retail" then
        frame.health:SetStatusBarTexture(4681512)
        frame.health:GetStatusBarTexture():SetTexCoord(1 / 256, 71 / 256, 167 / 256, 177 / 256)
        frame.power:SetStatusBarTexture(4681512)
        frame.power:GetStatusBarTexture():SetTexCoord(1 / 256, 75 / 256, 191 / 256, 198 / 256)
    else
        frame.health:GetStatusBarTexture():SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health")
        frame.power:GetStatusBarTexture():SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana")
    end

    frame.power:SetShown(cfg.showPowerBar == true)
    local p = g.portrait
    local size = math.max(16, p[3] * s + (tonumber(cfg.portraitSize) or 0))
    Box(frame.portraitFrame, host, p[1] + (tonumber(cfg.portraitX) or 0) / s,
        p[2] - (tonumber(cfg.portraitY) or 0) / s, size / s, size / s, s)
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
        local inset = math.floor(size * 0.18 + 0.5)
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
    for _, text in ipairs({ value, status }) do
        text:ClearAllPoints(); text:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        text:SetSize(g.health[3] * s, g.health[4] * s)
        text:SetJustifyH("CENTER")
        Font(text, math.min(tonumber(cfg.healthTextFontSize) or 10, 8 * s))
    end
    if frame.absorb then
        frame.absorb:ClearAllPoints(); frame.absorb:SetAllPoints(frame.health)
        frame.absorb:SetFrameLevel(base + 3)
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
        frame.levelText:SetPoint("BOTTOM", frame.portraitFrame, "BOTTOM", (Mod.db and Mod.db.levelX or 0), -2 * s + (Mod.db and Mod.db.levelY or 0))
    end
    if frame.pvpIcon and (not Mod.db or not Mod.db.pvpAnchor or Mod.db.pvpAnchor == "AUTO") then
        frame.pvpIcon:ClearAllPoints()
        frame.pvpIcon:SetPoint("CENTER", frame.portraitFrame, "BOTTOMLEFT", 3 * s + (Mod.db and Mod.db.pvpX or 0), 3 * s + (Mod.db and Mod.db.pvpY or 0))
    end
    if not frame._pfNativePowerText then
        frame._pfNativePowerText = frame.overlayFrame:CreateFontString(nil, "OVERLAY")
    end
    local powerText = frame._pfNativePowerText
    local font, _, outline = value:GetFont()
    if font then powerText:SetFont(font, math.max(6, 7 * s), outline) end
    powerText:SetTextColor(1, 1, 1, 1)
    powerText:ClearAllPoints(); powerText:SetPoint("CENTER", frame.power, "CENTER", 0, 0)
    powerText:SetSize(g.power[3] * s, g.power[4] * s)
    frame._pfNativeStyle = key
    Styles.UpdatePowerText(frame, cfg, preview)
    if preview then Styles.PreviewIconLayers(frame) end
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

local UpdateFramePowerEvent = Mod.UpdateFramePowerEvent
if UpdateFramePowerEvent then
    function Mod:UpdateFramePowerEvent(frame, event)
        local result = UpdateFramePowerEvent(self, frame, event)
        if frame then Styles.UpdatePowerText(frame, self:GetModeDB(frame.mode or "party"), false) end
        return result
    end
end
