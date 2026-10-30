-- Autoattack countdowns driven by the client's native swing clock.
-- PLAYER_SWING supplies seconds until the next swing, including resets/haste.
local _, ns = ...
local KRB = ns.KRB
local KT = _G.KT or {}
local LSM = LibStub("LibSharedMedia-3.0", true)
local order = { "main", "off", "ranged" }
local labels = { main = SWING_TIMER_MAIN_HAND or MAINHANDSLOT or "Main Hand", off = SWING_TIMER_OFF_HAND or SECONDARYHANDSLOT or "Off Hand", ranged = SWING_TIMER_RANGED or RANGEDSLOT or "Ranged" }
local bars, clocks, previewClocks = {}, {}, {}
local nativeRestore, nativeRestoreProfile
local syncingNative = false
local speedCache = {}
local currentConfig
-- Match Resource Bars' theme materials without modifying other resource bars
-- or overwriting the user's manual swing color.
local appearances = {
    classic = { texture = "Blizzard", border = 1, art = "classic", color = { 0.86, 0.62, 0.16 }, bg = { 0.07, 0.06, 0.04 } },
    forever = { texture = "Melli Dark", border = 2, art = "default", color = { 0.82, 0.65, 0.23 }, bg = { 0.04, 0.04, 0.05 } },
    retail = { texture = "Blizzard Raid Bar", border = 0, art = "default", color = { 0.12, 0.48, 0.95 }, bg = { 0.03, 0.05, 0.08 } },
    kui = { texture = "Melli Reforged", border = 1, art = "default", color = { 0.86, 0.62, 0.16 }, bg = { 0.07, 0.07, 0.07 } },
}
local driver = CreateFrame("Frame")
local swingTypes = Enum and Enum.PlayerSwingType
local hands = swingTypes and {
    [swingTypes.MainHand] = "main", [swingTypes.OffHand] = "off", [swingTypes.Ranged] = "ranged",
} or {}

local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
        and not (C_UI and C_UI.IsSecret and C_UI.IsSecret(value))
end
local function Positive(value)
    return Readable(value) and type(value) == "number" and value > 0 and value < math.huge
end
local function DB() return _G._KRB_GetDB() end
-- Order is stored bottom-to-top, matching stackAbove and the live preview.
function ns.GetSwingOrder(db)
    if type(db.swing) ~= "table" then db.swing = {} end
    local saved = db.swing.order
    local result, seen = {}, {}
    if type(saved) == "table" then
        for _, hand in ipairs(saved) do
            if (hand == "main" or hand == "off" or hand == "ranged") and not seen[hand] then
                result[#result + 1], seen[hand] = hand, true
            end
        end
    end
    for _, hand in ipairs(order) do
        if not seen[hand] then result[#result + 1] = hand end
    end
    db.swing = db.swing or {}
    db.swing.order = result
    return result
end
function ns.MoveSwingHand(db, hand, target)
    local sorted = ns.GetSwingOrder(db)
    local from, to
    for i, key in ipairs(sorted) do
        if key == hand then from = i end
        if key == target then to = i end
    end
    if not from or not to or from == to then return false end
    table.remove(sorted, from)
    table.insert(sorted, to, hand)
    return true
end
function ns.BindSwingPreviewReorder(bar, hand, previewBars, db, changed)
    local hit = CreateFrame("Button", nil, bar)
    hit:SetAllPoints(bar)
    hit:EnableMouse(true)
    hit:SetFrameLevel(bar:GetFrameLevel() + 10)
    hit:RegisterForDrag("LeftButton")
    hit:SetScript("OnDragStart", function(self)
        self.dragging = true
        bar:SetAlpha(0.6)
    end)
    hit:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = nil
        bar:SetAlpha(1)
        local _, cursorY = GetCursorPosition()
        local target, distance
        for _, other in ipairs(previewBars) do
            if other:IsShown() then
                local _, y = other:GetCenter()
                if y then
                    local delta = math.abs(cursorY - y * other:GetEffectiveScale())
                    if not distance or delta < distance then
                        target, distance = other._swingPreviewHand, delta
                    end
                end
            end
        end
        if target and ns.MoveSwingHand(db, hand, target) then changed() end
    end)
    hit:SetScript("OnHide", function(self)
        self.dragging = nil
        bar:SetAlpha(1)
    end)
    bar._swingReorderHit = hit
    return hit
end
function ns.EnsureSwingDefaults(db)
    if type(db.swing) ~= "table" then db.swing = {} end
    for key, value in pairs({ enabled = false, main = true, off = true, ranged = true, useThemeAppearance = true,
        height = 18, textSize = 11, showLabel = true, showTime = true, fillMode = "elapsed",
        fillR = 0.86, fillG = 0.62, fillB = 0.16 }) do
        if db.swing[key] == nil then db.swing[key] = value end
    end
    for key, limits in pairs({ height = { 5, 50, 18 }, textSize = { 8, 24, 11 },
        fillR = { 0, 1, 0.86 }, fillG = { 0, 1, 0.62 }, fillB = { 0, 1, 0.16 } }) do
        local value = db.swing[key]
        if not Readable(value) or type(value) ~= "number" or value ~= value then value = limits[3] end
        db.swing[key] = math.max(limits[1], math.min(limits[2], value))
    end
    ns.GetSwingOrder(db)
    if db.swing.fillMode ~= "remaining" then db.swing.fillMode = "elapsed" end
    if db.swing.nativeCVarRestore ~= "0" and db.swing.nativeCVarRestore ~= "1" then
        db.swing.nativeCVarRestore = nil
    end
end

-- Do not register an unavailable event, or fall back to invented melee cycles.
ns.SwingTimersSupported = false
if swingTypes then
    local ok, registered = pcall(driver.RegisterEvent, driver, "PLAYER_SWING")
    ns.SwingTimersSupported = ok and registered ~= false
end

local function Preview() return (KRB._swingPreviewUntil or 0) > GetTime() end
local function EquippedSpeed(hand)
    if not UnitAttackSpeed then return nil end
    local ok, main, off, ranged = pcall(UnitAttackSpeed, "player")
    if not ok then return speedCache[hand] end
    local value = ({ main = main, off = off, ranged = ranged })[hand]
    if not Readable(value) then return speedCache[hand] end
    speedCache[hand] = Positive(value) and value or nil
    return speedCache[hand]
end
local function Available(hand)
    if Preview() then return true end
    if hand == "main" then return true end
    if hand == "off" and OffhandHasWeapon then
        local ok, weapon = pcall(OffhandHasWeapon)
        if ok and Readable(weapon) and weapon == false then return false end
    end
    -- Forever exposes ranged speed as UnitAttackSpeed's THIRD return value,
    -- exactly like Blizzard_SwingTimer. A shield/relic is not a ranged weapon.
    return Positive(EquippedSpeed(hand))
end

-- Use Blizzard's own visibility switch, rather than hiding/reparenting Edit
-- Mode frames or attaching Show hooks that taint native frame ownership.
-- Keep the original preference across /reload, profile changes and shutdown.
local function ReadNativeCVar()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return nil end
    local ok, value = pcall(C_CVar.GetCVar, "showSwingTimer")
    if ok and Readable(value) and (value == "0" or value == "1") then return value end
end
local function SetNativeCVar(value)
    syncingNative = true
    local ok, err = pcall(C_CVar.SetCVar, "showSwingTimer", value)
    syncingNative = false
    if ok and ReadNativeCVar() == value then
        ns.SwingNativeVisibilityError = nil
        return true
    end
    ns.SwingNativeVisibilityError = ok and "showSwingTimer did not change" or tostring(err)
    return false
end
local function RestoreNativeVisibility(cfg)
    local original = nativeRestore or (cfg and cfg.nativeCVarRestore)
    if original and ReadNativeCVar() and SetNativeCVar(original) then
        if nativeRestoreProfile then nativeRestoreProfile.nativeCVarRestore = nil end
        if cfg then cfg.nativeCVarRestore = nil end
        nativeRestore, nativeRestoreProfile = nil, nil
    end
end
local function ReplaceNativeVisibility(cfg)
    local current = ReadNativeCVar()
    if not current then return end
    if not nativeRestore then
        nativeRestore = cfg.nativeCVarRestore or current
        nativeRestoreProfile = cfg
    end
    cfg.nativeCVarRestore = nativeRestore
    if current ~= "0" then SetNativeCVar("0") end
end
local function SetSwingFont(text, size)
    local ok, result = pcall(text.SetFont, text, ns.GetResourceBarFont(), size, "OUTLINE")
    if not ok or result == false then
        text:SetFontObject("GameFontHighlightSmall")
    end
end

local function HasAtlas(name)
    local vt = KT.VisualThemes
    if vt and vt.GetStyleAtlasInfo then return vt:GetStyleAtlasInfo(name) ~= nil end
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end
local function ApplySwingAtlasArt(bar, theme, hand, db)
    local prefix = theme == "forever" and "ui-swingtimerbar-" or theme == "retail" and "ui-castingbar-"
    local frameAtlas = prefix and prefix .. "frame"
    local art = bar._swingArt
    if not (theme == "retail" or (frameAtlas and HasAtlas(frameAtlas))) then
        if art then for _, texture in pairs(art) do texture:Hide() end end
        bar._bg:Show()
        return
    end
    if not art then
        art = { background = bar:CreateTexture(nil, "BACKGROUND", nil, 1),
            border = bar:CreateTexture(nil, "OVERLAY", nil, 1),
            pip = bar:CreateTexture(nil, "OVERLAY", nil, 2),
            shadow = bar:CreateTexture(nil, "OVERLAY", nil, 3) }
        bar._swingArt = art
    end
    local reach = math.max(0, math.min(2, (db.general.anchorGap or 4) / 2))
    for _, key in ipairs({ "background", "border" }) do
        local texture = art[key]
        local atlas = prefix .. (key == "border" and "frame" or "background")
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, reach)
        texture:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -reach)
        texture:SetVertexColor(1, 1, 1, 1)
        if theme == "retail" then
            if key == "border" then
                -- Original Retail atlas member 14235, sheet 4505182 (512x256).
                -- Bypass Forever's replacement of the casting-bar frame atlas.
                texture:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\resourcebars\\UICastingBar-Retail.blp")
                texture:SetTexCoord(1 / 512, 215 / 512, 31 / 256, 47 / 256)
                texture:Show()
            else
                -- The casting background contains grey stripes resembling a
                -- full fill. Empty swing bars use the plain dark backdrop.
                texture:Hide()
            end
        elseif KT.VisualThemes and KT.VisualThemes.ApplyStyleAtlas
            and KT.VisualThemes:ApplyStyleAtlas(texture, atlas) then texture:Show()
        elseif HasAtlas(atlas) then texture:SetAtlas(atlas, false); texture:Show() else texture:Hide() end
    end
    bar._bg:SetShown(not art.background:IsShown())
    local fillAtlas = theme == "forever" and prefix .. "filling-" .. ({ main = "mainhand", off = "offhand", ranged = "ranged" })[hand]
        or prefix .. "filling-standard"
    if HasAtlas(fillAtlas) then
        -- Assign the atlas through the StatusBar, as Blizzard_SwingTimer does.
        -- Setting it directly on the fill texture bypasses the bar's clipping.
        local vt = KT.VisualThemes
        local info = vt and vt.GetStyleAtlasInfo and vt:GetStyleAtlasInfo(fillAtlas)
        bar:SetStatusBarTexture(info and info.packaged and info.file or fillAtlas)
        if info and info.packaged then
            bar:GetStatusBarTexture():SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
        end
        bar:SetStatusBarColor(1, 1, 1, 1)
    end
    art.pip:ClearAllPoints()
    art.pip:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    art.pip:SetSize(8, db.swing.height + 4)
    if KT.VisualThemes and KT.VisualThemes.ApplyStyleAtlas and KT.VisualThemes:ApplyStyleAtlas(art.pip, prefix .. "pip") then art.pip:Show()
    elseif HasAtlas(prefix .. "pip") then art.pip:SetAtlas(prefix .. "pip", false); art.pip:Show() else art.pip:Hide() end
    art.shadow:ClearAllPoints()
    art.shadow:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    art.shadow:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    art.shadow:SetWidth(math.min(bar:GetWidth() * 0.6, 171))
    local shadowAtlas = prefix .. "textshadow-left"
    if db.swing.showLabel and KT.VisualThemes and KT.VisualThemes.ApplyStyleAtlas and KT.VisualThemes:ApplyStyleAtlas(art.shadow, shadowAtlas) then art.shadow:Show()
    elseif db.swing.showLabel and HasAtlas(shadowAtlas) then art.shadow:SetAtlas(shadowAtlas, false); art.shadow:Show() else art.shadow:Hide() end
    bar._border:SetShown(false)
end

local function CreateSwingBar(parent, name, hand, cfg)
    local bar
    bar = ns.CreateResourceStatusBar(parent, name)
    bar._text:ClearAllPoints()
    bar._text:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    bar._text:SetJustifyH("RIGHT")
    bar._label = bar._textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall", 7)
    bar._label:SetPoint("LEFT", bar, "LEFT", 6, 0)
    bar._label:SetPoint("RIGHT", bar, "RIGHT", -36, 0)
    bar._label:SetJustifyH("LEFT")
    SetSwingFont(bar._label, cfg.textSize)
    bar._label:SetText(labels[hand])
    bar._label:SetTextColor(1, 1, 1, 1)
    return bar
end
function ns.StyleSwingBar(bar, db, hand, width)
    local cfg = db.swing
    bar:SetSize(width, cfg.height)
    local theme = cfg.useThemeAppearance and (ns.GetResourceBarTheme and ns.GetResourceBarTheme() or "kui")
    local appearance = theme and appearances[theme] or nil
    local texture = LSM and LSM:Fetch("statusbar", appearance and appearance.texture or db.general.texture)
    bar:SetStatusBarTexture(texture or "Interface\\Buttons\\WHITE8x8")
    local color = appearance and appearance.color or { cfg.fillR, cfg.fillG, cfg.fillB }
    local bg = appearance and appearance.bg or { 0.07, 0.07, 0.07 }
    bar:SetStatusBarColor(color[1], color[2], color[3], 1)
    bar._bg:SetColorTexture(bg[1], bg[2], bg[3], db.general.bgA)
    local border = appearance and appearance.border or db.primary.borderSize or 1
    bar._border:SetSize(border); bar._border:SetShown(border > 0)
    SetSwingFont(bar._text, cfg.textSize)
    SetSwingFont(bar._label, cfg.textSize)
    bar._text:SetShown(cfg.showTime)
    bar._label:SetShown(cfg.showLabel)
    ns.ApplyResourceFrameArt(bar, db, appearance and appearance.art)
    ApplySwingAtlasArt(bar, theme, hand, db)
    bar._swingHasPip = bar._swingArt and bar._swingArt.pip:IsShown()
end
function ns.CreateSwingPreviewBar(parent, db, hand)
    return CreateSwingBar(parent, nil, hand, db.swing)
end
function ns.PaintSwingPreviewBar(bar, db, index)
    local duration = index + 1
    local elapsed = GetTime() % duration
    local remaining = duration - elapsed
    bar:SetMinMaxValues(0, duration)
    local value = db.swing.fillMode == "remaining" and remaining or elapsed
    bar:SetValue(value)
    bar:GetStatusBarTexture():SetShown(value > 0)
    bar._text:SetFormattedText("%.1f", remaining)
    if bar._swingArt then bar._swingArt.pip:SetShown(bar._swingHasPip == true) end
end

function KRB:UpdateSwingVisibility(db)
    db = db or DB()
    local show = db.enabled ~= false and (not db.general.hideOOC or InCombatLockdown() or Preview())
    for _, bar in pairs(bars) do bar:SetAlpha(show and 1 or 0) end
end

local function Paint()
    local active, now = false, GetTime()
    for hand, bar in pairs(bars) do
        if bar:IsShown() then
            local clock = Preview() and previewClocks[hand] or clocks[hand]
            local remaining = clock and math.max(0, clock.expires - now) or 0
            if bar._swingArt then bar._swingArt.pip:SetShown(remaining > 0 and bar._swingHasPip == true) end
            bar:SetMinMaxValues(0, clock and clock.duration or 1)
            local cfg = currentConfig
            local value = cfg.fillMode == "remaining" and remaining
                or (remaining > 0 and clock.duration - remaining or 0)
            bar:SetValue(value)
            -- An idle timer must stay visually empty, including after reskinning
            -- a bar whose value was already zero before the atlas changed.
            bar:GetStatusBarTexture():SetShown(value > 0)
            local text = string.format("%.1f", remaining)
            if bar._lastSwingText ~= text then bar._text:SetText(text); bar._lastSwingText = text end
            if remaining > 0 then active = true end
        end
    end
    if not active and not Preview() then driver:SetScript("OnUpdate", nil) end
end
local function Wake()
    driver:SetScript("OnUpdate", function(_, elapsed)
        driver.elapsed = (driver.elapsed or 0) + elapsed
        if driver.elapsed < 0.03 then return end
        driver.elapsed = 0
        if KRB._swingPreviewUntil and not Preview() then
            KRB._swingPreviewUntil = nil
            for hand in pairs(previewClocks) do previewClocks[hand] = nil end
            KRB:BuildBars()
        end
        Paint()
    end)
    Paint()
end

function KRB:HideSwingBars()
    for _, bar in pairs(bars) do bar:Hide() end
    for hand in pairs(clocks) do clocks[hand] = nil end
    for hand in pairs(previewClocks) do previewClocks[hand] = nil end
    self._swingPreviewUntil = nil
    driver:SetScript("OnUpdate", nil)
    RestoreNativeVisibility(DB().swing)
end

function KRB:BuildSwingBars(db, width, stackAbove)
    local cfg = db.swing
    currentConfig = cfg
    local preview = Preview()
    if db.enabled == false or (not cfg.enabled and not preview)
        or (not ns.SwingTimersSupported and not preview) then
        self:HideSwingBars(); return
    end
    local hasReplacement = false
    for _, hand in ipairs(ns.GetSwingOrder(db)) do
        if cfg[hand] and Available(hand) then
            hasReplacement = true
            local bar = bars[hand]
            if not bar then
                bar = CreateSwingBar(UIParent, "KUI_SwingBar_" .. hand, hand, cfg)
                bars[hand] = bar
            end
            bar:SetSize(width, cfg.height)
            stackAbove(bar)
            ns.StyleSwingBar(bar, db, hand, width)
            bar:Show()
        elseif bars[hand] then bars[hand]:Hide() end
    end
    -- Claim the native display only AFTER successful bar construction. Preview
    -- alone never disables Blizzard, and selecting no bars releases ownership.
    if not preview then
        if hasReplacement and cfg.enabled and ns.SwingTimersSupported then
            ReplaceNativeVisibility(cfg)
        else
            RestoreNativeVisibility(cfg)
        end
    end
    self:UpdateSwingVisibility(db)
    Wake()
end

function KRB:TestSwingBars()
    local db = DB()
    if db.enabled == false then return end
    self._swingPreviewUntil = GetTime() + 6
    for index, hand in ipairs(order) do
        previewClocks[hand] = { duration = index + 1, expires = GetTime() + index + 1 }
    end
    self:BuildBars()
end

local function ResetEquippedClocks(onlyHand)
    local now = GetTime()
    for hand in pairs(clocks) do
        if not onlyHand or hand == onlyHand then
            local speed = EquippedSpeed(hand)
            if Available(hand) and Positive(speed) then
                clocks[hand] = { duration = speed, expires = now + speed }
            else
                clocks[hand] = nil
            end
        end
    end
end

local rebuildPending = false
local function RebuildSoon()
    if rebuildPending then return end
    rebuildPending = true
    C_Timer.After(0, function() rebuildPending = false; KRB:BuildBars() end)
end

driver:SetScript("OnEvent", function(_, event, duration, swingType)
    local db = DB()
    if event == "PLAYER_LOGOUT" then
        RestoreNativeVisibility(db.swing)
        return
    elseif event == "CVAR_UPDATE" then
        if not syncingNative and Readable(duration) and type(duration) == "string"
            and duration:lower() == "showswingtimer" and nativeRestore then
            ReplaceNativeVisibility(db.swing)
        end
        return
    elseif event == "UNIT_ATTACK_SPEED" and duration ~= "player" then return end
    if event == "PLAYER_SWING" then
        if db.enabled == false or not db.swing.enabled then return end
        if not Readable(swingType) or not Positive(duration) then return end
        local hand = hands[swingType]
        if not hand or not db.swing[hand] then return end
        -- Preserve each hand's clock independently. Do not extrapolate another
        -- cycle when a timer expires; the next native swing starts it again.
        speedCache[hand] = duration
        clocks[hand] = { duration = duration, expires = GetTime() + duration }
        if not bars[hand] or not bars[hand]:IsShown() then RebuildSoon() end
        Wake()
    else
        if event == "PLAYER_EQUIPMENT_CHANGED" and duration ~= 16 and duration ~= 17 and duration ~= 18 then return end
        if db.enabled == false or not db.swing.enabled then return end
        if event == "WEAPON_SLOT_CHANGED" then
            -- Matches native ResetSwingTimerForEquippedWeapon: reset only
            -- clocks already running, never start a cycle from an equip event.
            ResetEquippedClocks()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            local hand = ({ [16] = "main", [17] = "off", [18] = "ranged" })[duration]
            speedCache[hand] = nil
            ResetEquippedClocks(hand)
        elseif event ~= "UNIT_ATTACK_SPEED" and event ~= "PLAYER_REGEN_ENABLED" then
            for hand in pairs(clocks) do clocks[hand] = nil end
            for hand in pairs(speedCache) do speedCache[hand] = nil end
            KRB._swingPreviewUntil = nil
        end
        RebuildSoon()
    end
end)
if ns.SwingTimersSupported then
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_SHAPESHIFT_FORM", "WEAPON_SLOT_CHANGED", "UNIT_ATTACK_SPEED", "CVAR_UPDATE", "PLAYER_LOGOUT", "PLAYER_REGEN_ENABLED" }) do
        pcall(driver.RegisterEvent, driver, event)
    end
end

function KRB:OnDisable()
    self:HideSwingBars()
end
