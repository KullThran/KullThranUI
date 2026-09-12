-- Modules/ActionBars/ActionBars.lua (moved from Modules/ActionBars.lua)
local _, ns = ...
local KT = _G.KT
local Mod = KT:NewModule("ActionBars", "AceEvent-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

-- Cache globals
local _G = _G
local pairs, ipairs = pairs, ipairs
local wipe = wipe
local pcall = pcall
local hooksecurefunc = hooksecurefunc
local C_Timer = C_Timer
local RANGE_INDICATOR = _G.RANGE_INDICATOR
local UIFrameFadeIn, UIFrameFadeOut = UIFrameFadeIn, UIFrameFadeOut
local ActionButton_HideOverlayGlow = ActionButton_HideOverlayGlow
local ActionButton_ShowOverlayGlow = ActionButton_ShowOverlayGlow

local SMP = "Interface\\AddOns\\KullThranUI\\Modules\\SimplicityTextures\\"
local SHAPE_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"

local function IsSecureActionButtonSafeMode()
    -- Secret-value clients require the native action-button cooldown pipeline
    -- to remain completely unhooked. Feature detection also covers PTR/beta
    -- builds whose TOC number may not yet match the retail threshold.
    if type(_G.issecretvalue) == "function" or type(_G.canaccessvalue) == "function" then
        return true
    end
    local _, _, _, interfaceVersion = _G.GetBuildInfo and _G.GetBuildInfo()
    interfaceVersion = tonumber(interfaceVersion) or 0
    return interfaceVersion >= 120000
end

local function IsBlizzardActionButton(button)
    local name = button and button.GetName and button:GetName()
    if type(name) ~= "string" then return false end
    return name:find("^ActionButton%d+$") ~= nil
        or name:find("^MultiBarBottomLeftButton%d+$") ~= nil
        or name:find("^MultiBarBottomRightButton%d+$") ~= nil
        or name:find("^MultiBarRightButton%d+$") ~= nil
        or name:find("^MultiBarLeftButton%d+$") ~= nil
        or name:find("^MultiBar5Button%d+$") ~= nil
        or name:find("^MultiBar6Button%d+$") ~= nil
        or name:find("^MultiBar7Button%d+$") ~= nil
        or name:find("^PetActionButton%d+$") ~= nil
        or name:find("^StanceButton%d+$") ~= nil
end

local function CanMutateActionButtonCooldown(button)
    if not IsSecureActionButtonSafeMode() then
        return true
    end

    -- On secret-value clients Blizzard must be the only code that mutates the
    -- native cooldown widgets of secure action buttons. Even a visual-only
    -- change (mask, swipe texture, anchors, alpha or a Lua field) can make the
    -- later SetCooldown(secret, secret, secret) call run through a tainted
    -- object path.
    if IsBlizzardActionButton(button) then
        return false
    end

    if button and button.IsProtected then
        local ok, isProtected = pcall(button.IsProtected, button)
        if ok and isProtected then
            return false
        end
    end

    return true
end

-- Diccionarios de texturas para cada forma
local SHAPE_MASKS = {
    ["CIRCLE"]  = SHAPE_MEDIA .. "circle_mask.tga",
    ["CSQUARE"] = SHAPE_MEDIA .. "csquare_mask.tga",
    ["HEXAGON"] = SHAPE_MEDIA .. "hexagon_mask.tga",
    ["DIAMOND"] = SHAPE_MEDIA .. "diamond_mask.tga",
    ["SHIELD"]  = SHAPE_MEDIA .. "shield_mask.tga",
}

local SHAPE_BORDERS = {
    ["CIRCLE"]  = SHAPE_MEDIA .. "circle_border.tga",
    ["CSQUARE"] = SHAPE_MEDIA .. "csquare_border.tga",
    ["HEXAGON"] = SHAPE_MEDIA .. "hexagon_border.tga",
    ["DIAMOND"] = SHAPE_MEDIA .. "diamond_border.tga",
    ["SHIELD"]  = SHAPE_MEDIA .. "shield_border.tga",
}

-- ============================================================================
-- LÓGICA DE DETECCIÓN DE FORMA POR BARRA
-- ============================================================================
local function GetShapeForButton(name)
    if not name then return "NONE" end
    local db = KT.db.profile.actionbars
    if not db or db.buttonStyle == "BLIZZARD" then return "NONE" end

    local specific = "GLOBAL"
    if name:find("^ActionButton") then
        specific = db.shapeBar1
    elseif name:find("^MultiBarBottomLeft") then
        specific = db.shapeBar2
    elseif name:find("^MultiBarBottomRight") then
        specific = db.shapeBar3
    elseif name:find("^MultiBarRight") then
        specific = db.shapeBar4
    elseif name:find("^MultiBarLeft") then
        specific = db.shapeBar5
    elseif name:find("^MultiBar5") then
        specific = db.shapeBar6
    elseif name:find("^MultiBar6") then
        specific = db.shapeBar7
    elseif name:find("^MultiBar7") then
        specific = db.shapeBar8
    elseif name:find("^PetActionButton") then
        specific = db.shapePet
    elseif name:find("^StanceButton") then
        specific = db.shapeStance
    end

    if not specific or specific == "GLOBAL" then
        return db.buttonShape or "NONE"
    end
    return specific
end

-- ============================================================================
-- INIT & ENABLE
-- ============================================================================

function Mod:OnInitialize()
    if KT.db and KT.db.profile then
        if KT.db.profile.actionbars and KT.db.profile.actionbars.bars then
            KT.db.profile.actionbars = nil
        end
        if not KT.db.profile.actionbars then
            KT.db.profile.actionbars = {
                enable = true,
                buttonStyle = "BLIZZARD",
                buttonShape = "NONE",

                -- Per Bar shapes defaults
                shapeBar1 = "GLOBAL",
                shapeBar2 = "GLOBAL",
                shapeBar3 = "GLOBAL",
                shapeBar4 = "GLOBAL",
                shapeBar5 = "GLOBAL",
                shapeBar6 = "GLOBAL",
                shapeBar7 = "GLOBAL",
                shapeBar8 = "GLOBAL",
                shapePet = "GLOBAL",
                shapeStance = "GLOBAL",

                hideHotkeys = false,
                hideMacroText = false,
                font = "AAA_ITC_Avant_Garde",
                fontSize = 16,
                fontOutline = "OUTLINE",
                fontColor = { r = 1, g = 1, b = 1, a = 1 },

                fadeBar1 = false,
                fadeBar2 = false,
                fadeBar3 = false,
                fadeBar4 = false,
                fadeBar5 = false,
                fadeBar6 = false,
                fadeBar7 = false,
                fadeBar8 = false,
                fadePet = false,
                fadeStance = false,

                hotkeyFont = "KullThran Font",
                showKeypressIndicator = true,
                hotkeyFontSize = 12,
                hotkeyFontOutline = "OUTLINE",
                hotkeyFontColor = { r = 1, g = 1, b = 1, a = 1 },
                macroFont = "KullThran Font",
                macroFontSize = 12,
                macroFontOutline = "OUTLINE",
                macroFontColor = { r = 1, g = 1, b = 1, a = 1 },

                buttonSpacing = 0,
                buttonPadding = 0,
                buttonBackdropColor = { r = 0, g = 0, b = 0, a = 1 },
            }
        end
    end
end

function Mod:OnEnable()
    if not KT.db.profile.actionbars or not KT.db.profile.actionbars.enable then return end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("UPDATE_BINDINGS", "StyleAllBars")

    if _G.ActionButton_UpdateHotkeys then
        self:SecureHook("ActionButton_UpdateHotkeys", "UpdateHotkeys")
    end

    self:StyleAllBars()
    self:UpdateMouseoverState()

    if _G.ActionButton_ShowOverlayGlow then
        self:SecureHook("ActionButton_ShowOverlayGlow", "OnShowOverlayGlow")
    end
    if _G.ActionButton_UpdateOverlayGlow then
        self:SecureHook("ActionButton_UpdateOverlayGlow", "OnUpdateOverlayGlow")
    end
end

function Mod:OnPlayerEnteringWorld()
    C_Timer.After(1, function()
        self:StyleAllBars()
        self:UpdateMouseoverState()
        end)
end

-- ============================================================================
-- COOLDOWN BATCHING (Optimización de Rendimiento)
-- ============================================================================
local _cdPending = {}
local _cdPendingCount = 0
local _cdTimerScheduled = false
local function ConfigureCooldownSwipe(cooldown, shape, maskTex)
    if not cooldown then
        return
    end

    if cooldown.SetSwipeColor then
        pcall(cooldown.SetSwipeColor, cooldown, 0, 0, 0, 0.82)
    end
    if cooldown.SetDrawEdge then
        pcall(cooldown.SetDrawEdge, cooldown, false)
    end
    if cooldown.SetDrawBling then
        pcall(cooldown.SetDrawBling, cooldown, false)
    end
    if cooldown.SetDrawSwipe then
        pcall(cooldown.SetDrawSwipe, cooldown, true)
    end
    if cooldown.SetUseCircularEdge then
        pcall(cooldown.SetUseCircularEdge, cooldown, shape ~= "NONE")
    end

    local swipeTexture = maskTex or "Interface\\Buttons\\WHITE8x8"
    if cooldown.SetSwipeTexture then
        pcall(cooldown.SetSwipeTexture, cooldown, swipeTexture)
        cooldown.KT_KUISwipeTexture = swipeTexture
    end
end


local function _FlushCDPatch()
    _cdTimerScheduled = false

    for cdFrame, btn in pairs(_cdPending) do
        if cdFrame and not cdFrame:IsForbidden() then
            local shape = GetShapeForButton(btn:GetName())

            if shape ~= "NONE" and btn.KT_ShapeMask then
                if cdFrame.RemoveMaskTexture then pcall(cdFrame.RemoveMaskTexture, cdFrame, btn.KT_ShapeMask) end
                if cdFrame.AddMaskTexture then pcall(cdFrame.AddMaskTexture, cdFrame, btn.KT_ShapeMask) end

                if cdFrame.SetDrawSwipe then pcall(cdFrame.SetDrawSwipe, cdFrame, true) end
                if cdFrame.SetUseCircularEdge then pcall(cdFrame.SetUseCircularEdge, cdFrame, shape ~= "CSQUARE") end
                if cdFrame.SetSwipeTexture and SHAPE_MASKS[shape] and cdFrame.KT_KUISwipeTexture ~= SHAPE_MASKS[shape] then
                    pcall(cdFrame.SetSwipeTexture, cdFrame, SHAPE_MASKS[shape])
                    cdFrame.KT_KUISwipeTexture = SHAPE_MASKS[shape]
                end
            else
                if btn.KT_ShapeMask and cdFrame.RemoveMaskTexture then
                    pcall(cdFrame.RemoveMaskTexture, cdFrame, btn.KT_ShapeMask)
                end
                if cdFrame.SetDrawSwipe then pcall(cdFrame.SetDrawSwipe, cdFrame, false) end
                if cdFrame.SetUseCircularEdge then pcall(cdFrame.SetUseCircularEdge, cdFrame, false) end
                if cdFrame.SetSwipeTexture then pcall(cdFrame.SetSwipeTexture, cdFrame, "") end
                cdFrame.KT_KUISwipeTexture = nil
            end
            ConfigureCooldownSwipe(cdFrame, shape, shape ~= "NONE" and SHAPE_MASKS[shape] or nil)
        end
    end
    wipe(_cdPending)
    _cdPendingCount = 0
end

local function HookButtonCooldownEdge(btn)
    if not btn or btn.KT_CDHooked then return end
    -- Midnight can pass secret start/duration/modRate values to SetCooldown.
    -- Never hook that method or mutate the associated native widget on a
    -- Blizzard secure action button; the surrounding KUI skin remains safe.
    if not CanMutateActionButtonCooldown(btn) then
        return
    end

    local name = btn:GetName()
    local cooldown = btn.cooldown or _G[name .. "Cooldown"]
    local chargeCooldown = btn.chargeCooldown or _G[name .. "ChargeCooldown"]
    if not cooldown and not chargeCooldown then
        return
    end

    btn.KT_CDHooked = true
    btn.KT_CooldownFrame = cooldown
    btn.KT_ChargeCooldownFrame = chargeCooldown

    local function OnSetCooldown(cdFrame)
        if not cdFrame then
            return
        end
        if not _cdPending[cdFrame] then
            _cdPendingCount = _cdPendingCount + 1
        end
        cdFrame.KT_KUISwipeTexture = nil
        _cdPending[cdFrame] = btn
        if not _cdTimerScheduled then
            _cdTimerScheduled = true
            C_Timer.After(0, _FlushCDPatch)
        end
    end

    if cooldown and cooldown.SetCooldown then
        hooksecurefunc(cooldown, "SetCooldown", OnSetCooldown)
    end
    if chargeCooldown and chargeCooldown.SetCooldown then
        hooksecurefunc(chargeCooldown, "SetCooldown", OnSetCooldown)
    end
end
-- ============================================================================
-- UTILIDADES (Protegido contra Taint)
-- ============================================================================

local function StripBlizzardArt(btn)
    local name = btn:GetName()
    local icon = _G[name .. "Icon"] or btn.icon
    local border = _G[name .. "Border"] or btn.Border
    local floatBg = _G[name .. "FloatingBG"]

    local slotBg = _G[name .. "SlotBackground"] or btn.SlotBackground
    local slotArt = btn.SlotArt

    -- Hook Diferido para NormalTexture, Border y Backgrounds nativos.
    -- On secret-value clients the automatic border-strip helpers run while
    -- Blizzard repaints the button (Show/UpdateButtonArt), which taints the
    -- widget and re-triggers ADDON_ACTION_BLOCKED on SetShown plus the
    -- SetCooldown secret-value rejection. Keep only the initial static pass;
    -- never re-run mutations from Blizzard's own update callbacks.
    if not btn.KT_HookedNormal then
        local hideBorderFn = function()
            if btn and not btn:IsForbidden() then
                local nt = btn:GetNormalTexture()
                if nt then nt:SetAlpha(0) end
                if border then
                    border:SetTexture(nil)
                    border:Hide()
                    border:SetAlpha(0)
                end
                if slotBg then
                    slotBg:Hide()
                    slotBg:SetAlpha(0)
                    slotBg:SetTexture(nil)
                end
                if slotArt then
                    slotArt:Hide()
                    slotArt:SetAlpha(0)
                end
            end
        end
        if CanMutateActionButtonCooldown(btn) then
            btn:HookScript("OnShow", function() C_Timer.After(0, hideBorderFn) end)
            if btn.UpdateButtonArt then
                hooksecurefunc(btn, "UpdateButtonArt", hideBorderFn)
            end
        end
        C_Timer.After(0, hideBorderFn)
        btn.KT_HookedNormal = true
    end

    if floatBg then floatBg:Hide() end

    -- Desvincular máscara nativa circular de Blizzard antes de destruirla
    if btn.IconMask then
        if icon and icon.RemoveMaskTexture then
            pcall(icon.RemoveMaskTexture, icon, btn.IconMask)
        end
        btn.IconMask:Hide()
        btn.IconMask:SetTexture(nil)
    end
end

local function ResetButtonStyle(btn)
    if btn.KT_KUI_Backdrop then btn.KT_KUI_Backdrop:Hide() end
    if btn.KT_BG then btn.KT_BG:Hide() end
    if btn.KT_BorderLines then
        for i = 1, 4 do btn.KT_BorderLines[i]:Hide() end
    end
    if btn.KT_SMP_Normal then btn.KT_SMP_Normal:Hide() end
    if btn.KT_SMP_Gloss then btn.KT_SMP_Gloss:Hide() end
    if btn.KT_SMP_Disabled then btn.KT_SMP_Disabled:Hide() end
    if btn.KT_ShapeBorder then btn.KT_ShapeBorder:Hide() end
end

function Mod:ApplyProtectedSafeVisualStyle(btn)
    local db = KT.db.profile.actionbars
    local name = btn and btn.GetName and btn:GetName()
    if not (btn and db and name) then return end
    if db.buttonStyle == "BLIZZARD" then
        if btn.KT_BG then btn.KT_BG:Hide() end
        if btn.KT_ShapeBorder then btn.KT_ShapeBorder:Hide() end
        if btn.KT_BorderLines then
            for i = 1, 4 do btn.KT_BorderLines[i]:Hide() end
        end
        return
    end

    local shape = GetShapeForButton(name)
    local bgColor = db.buttonBackdropColor or { r = 0, g = 0, b = 0, a = 1 }
    local inset = (db.buttonStyle == "SIMPLICITY") and 3 or math.max(0, db.buttonSpacing or 0)
    local borderOffset = (db.buttonStyle == "SIMPLICITY") and 3 or 2

    if not btn.KT_BG then
        btn.KT_BG = btn:CreateTexture(nil, "BACKGROUND", nil, -5)
    end
    if db.buttonStyle == "SIMPLICITY" then
        btn.KT_BG:SetTexture(SMP .. "Backdrop")
        btn.KT_BG:SetVertexColor(0, 0, 0, 1)
    else
        btn.KT_BG:SetTexture("Interface\\Buttons\\WHITE8x8")
        btn.KT_BG:SetVertexColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    end
    btn.KT_BG:ClearAllPoints()
    btn.KT_BG:SetPoint("TOPLEFT", btn, "TOPLEFT", -inset, inset)
    btn.KT_BG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", inset, -inset)
    btn.KT_BG:Show()

    if not btn.KT_BorderLines then
        btn.KT_BorderLines = {}
        for i = 1, 4 do
            btn.KT_BorderLines[i] = btn:CreateTexture(nil, "OVERLAY", nil, 1)
            btn.KT_BorderLines[i]:SetColorTexture(0, 0, 0, 1)
        end
    end

    if shape == "NONE" then
        local bl = btn.KT_BorderLines
        bl[1]:ClearAllPoints(); bl[1]:SetPoint("TOPLEFT", btn.KT_BG, "TOPLEFT", 0, 0); bl[1]:SetPoint("TOPRIGHT", btn.KT_BG, "TOPRIGHT", 0, 0); bl[1]:SetHeight(1)
        bl[2]:ClearAllPoints(); bl[2]:SetPoint("BOTTOMLEFT", btn.KT_BG, "BOTTOMLEFT", 0, 0); bl[2]:SetPoint("BOTTOMRIGHT", btn.KT_BG, "BOTTOMRIGHT", 0, 0); bl[2]:SetHeight(1)
        bl[3]:ClearAllPoints(); bl[3]:SetPoint("TOPLEFT", btn.KT_BG, "TOPLEFT", 0, 0); bl[3]:SetPoint("BOTTOMLEFT", btn.KT_BG, "BOTTOMLEFT", 0, 0); bl[3]:SetWidth(1)
        bl[4]:ClearAllPoints(); bl[4]:SetPoint("TOPRIGHT", btn.KT_BG, "TOPRIGHT", 0, 0); bl[4]:SetPoint("BOTTOMRIGHT", btn.KT_BG, "BOTTOMRIGHT", 0, 0); bl[4]:SetWidth(1)
        for i = 1, 4 do bl[i]:Show() end
        if btn.KT_ShapeBorder then btn.KT_ShapeBorder:Hide() end
        return
    end

    for i = 1, 4 do
        if btn.KT_BorderLines[i] then
            btn.KT_BorderLines[i]:Hide()
        end
    end

    local borderTex = SHAPE_BORDERS[shape]
    if not borderTex then
        if btn.KT_ShapeBorder then btn.KT_ShapeBorder:Hide() end
        return
    end

    if not btn.KT_ShapeBorder then
        btn.KT_ShapeBorder = btn:CreateTexture(nil, "OVERLAY", nil, 0)
    end
    btn.KT_ShapeBorder:SetTexture(borderTex)
    btn.KT_ShapeBorder:SetVertexColor(0, 0, 0, 1)
    btn.KT_ShapeBorder:ClearAllPoints()
    btn.KT_ShapeBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -borderOffset, borderOffset)
    btn.KT_ShapeBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", borderOffset, -borderOffset)
    btn.KT_ShapeBorder:Show()
end

-- ============================================================================
-- KUI STYLE
-- ============================================================================

function Mod:ApplyModernKUIStyle(btn)
    local name = btn:GetName()
    local icon = _G[name .. "Icon"]
    local canMutateCooldown = CanMutateActionButtonCooldown(btn)
    local cooldown = canMutateCooldown and (_G[name .. "Cooldown"] or btn.cooldown) or nil
    local chargeCd = canMutateCooldown and (_G[name .. "ChargeCooldown"] or btn.chargeCooldown) or nil
    local db = KT.db.profile.actionbars

    StripBlizzardArt(btn)

    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetDrawLayer("ARTWORK", -1)
    end

    local spacing = db.buttonSpacing or 0
    local padding = db.buttonPadding or 1

    -- Fondo KUI
    if not btn.KT_BG then
        btn.KT_BG = btn:CreateTexture(nil, "BACKGROUND", nil, -5)
        btn.KT_BG:SetTexture("Interface\\Buttons\\WHITE8x8")
    end
    local c = db.buttonBackdropColor
    btn.KT_BG:SetVertexColor(c.r, c.g, c.b, c.a)
    btn.KT_BG:ClearAllPoints()
    btn.KT_BG:SetPoint("TOPLEFT", btn, "TOPLEFT", spacing, -spacing)
    btn.KT_BG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -spacing, spacing)
    btn.KT_BG:Show()

    -- Bordes cuadrados KUI (Solo se muestran si Shape es "NONE")
    if not btn.KT_BorderLines then
        btn.KT_BorderLines = {}
        for i = 1, 4 do
            btn.KT_BorderLines[i] = btn:CreateTexture(nil, "OVERLAY", nil, 1)
            btn.KT_BorderLines[i]:SetColorTexture(0, 0, 0, 1)
        end
    end
    local bl = btn.KT_BorderLines
    bl[1]:SetPoint("TOPLEFT", btn.KT_BG, "TOPLEFT", 0, 0); bl[1]:SetPoint("TOPRIGHT", btn.KT_BG, "TOPRIGHT", 0, 0); bl
        [1]:SetHeight(1)
    bl[2]:SetPoint("BOTTOMLEFT", btn.KT_BG, "BOTTOMLEFT", 0, 0); bl[2]:SetPoint("BOTTOMRIGHT", btn.KT_BG, "BOTTOMRIGHT",
        0, 0); bl[2]:SetHeight(1)
    bl[3]:SetPoint("TOPLEFT", btn.KT_BG, "TOPLEFT", 0, 0); bl[3]:SetPoint("BOTTOMLEFT", btn.KT_BG, "BOTTOMLEFT", 0, 0); bl
        [3]:SetWidth(1)
    bl[4]:SetPoint("TOPRIGHT", btn.KT_BG, "TOPRIGHT", 0, 0); bl[4]:SetPoint("BOTTOMRIGHT", btn.KT_BG, "BOTTOMRIGHT", 0, 0); bl
        [4]:SetWidth(1)

    for i = 1, 4 do bl[i]:Show() end

    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", btn.KT_BG, "TOPLEFT", padding, -padding)
        icon:SetPoint("BOTTOMRIGHT", btn.KT_BG, "BOTTOMRIGHT", -padding, padding)
    end

    if cooldown and cooldown.ClearAllPoints and cooldown.SetAllPoints then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(icon or btn.KT_BG or btn)
    end
    if chargeCd and chargeCd.ClearAllPoints and chargeCd.SetAllPoints then
        chargeCd:ClearAllPoints()
        chargeCd:SetAllPoints(icon or btn.KT_BG or btn)
    end

    local pushed = btn:GetPushedTexture()
    if pushed then
        pushed:SetColorTexture(1, 1, 1, 0.2)
        pushed:SetBlendMode("BLEND")
        pushed:ClearAllPoints()
        pushed:SetAllPoints(icon or btn.KT_BG)
        btn:SetPushedTexture(pushed)
    end

    local checked = btn:GetCheckedTexture()
    if checked then
        checked:SetColorTexture(1, 0.9, 0, 0.2)
        checked:SetBlendMode("BLEND")
        checked:ClearAllPoints()
        checked:SetAllPoints(icon or btn.KT_BG)
        btn:SetCheckedTexture(checked)
    end

    if btn.SpellHighlightTexture then
        btn.SpellHighlightTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.SpellHighlightTexture:ClearAllPoints()
        btn.SpellHighlightTexture:SetAllPoints(icon or btn.KT_BG)
    end
end

-- ============================================================================
-- SIMPLICITY STYLE
-- ============================================================================

function Mod:ApplySimplicityStyle(btn)
    local name = btn:GetName()
    local icon = _G[name .. "Icon"]
    local canMutateCooldown = CanMutateActionButtonCooldown(btn)
    local cooldown = canMutateCooldown and (_G[name .. "Cooldown"] or btn.cooldown) or nil
    local chargeCd = canMutateCooldown and (_G[name .. "ChargeCooldown"] or btn.chargeCooldown) or nil

    StripBlizzardArt(btn)

    local offset = 3

    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetDrawLayer("BACKGROUND", 1)
        icon:ClearAllPoints()
        icon:SetAllPoints(btn)
    end

    if cooldown and cooldown.ClearAllPoints and cooldown.SetAllPoints then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(icon or btn)
    end
    if chargeCd and chargeCd.ClearAllPoints and chargeCd.SetAllPoints then
        chargeCd:ClearAllPoints()
        chargeCd:SetAllPoints(icon or btn)
    end

    if not btn.KT_BG then
        btn.KT_BG = btn:CreateTexture(nil, "BACKGROUND", nil, -5)
    end
    btn.KT_BG:SetTexture(SMP .. "Backdrop")
    btn.KT_BG:SetVertexColor(0, 0, 0, 1)
    btn.KT_BG:ClearAllPoints()
    btn.KT_BG:SetPoint("TOPLEFT", btn, "TOPLEFT", -offset, offset)
    btn.KT_BG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", offset, -offset)
    btn.KT_BG:Show()

    if not btn.KT_SMP_Normal then
        local t = btn:CreateTexture(nil, "OVERLAY", nil, 0)
        t:SetVertexColor(0, 0, 0, 1)
        btn.KT_SMP_Normal = t
    end
    btn.KT_SMP_Normal:SetTexture(SMP .. "Normal")
    btn.KT_SMP_Normal:Show()
    btn.KT_SMP_Normal:ClearAllPoints()
    btn.KT_SMP_Normal:SetPoint("TOPLEFT", btn, "TOPLEFT", -offset, offset)
    btn.KT_SMP_Normal:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", offset, -offset)

    if btn.KT_SMP_Gloss then btn.KT_SMP_Gloss:Hide() end

    local pushed = btn:GetPushedTexture()
    if pushed then
        pushed:SetTexture(SMP .. "Overlay")
        pushed:SetVertexColor(1, 1, 1, 0.1)
        pushed:SetBlendMode("ADD")
        pushed:ClearAllPoints()
        pushed:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
        pushed:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
        btn:SetPushedTexture(pushed)
    end

    local checked = btn:GetCheckedTexture()
    if checked then
        checked:SetTexture(SMP .. "Border")
        checked:SetBlendMode("ADD")
        checked:SetVertexColor(1, 1, 1, 1)
        checked:ClearAllPoints()
        checked:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
        checked:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
        btn:SetCheckedTexture(checked)
    end

    local highlight = btn:GetHighlightTexture()
    if highlight then
        highlight:SetTexture(SMP .. "Overlay")
        highlight:SetBlendMode("ADD")
        highlight:SetVertexColor(1, 1, 1, 0.1)
        highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", -offset, offset)
        highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", offset, -offset)
        btn:SetHighlightTexture(highlight)
    end

    local flash = _G[name .. "Flash"]
    if flash then
        flash:SetTexture(SMP .. "Overlay")
        flash:SetBlendMode("ADD")
        flash:SetVertexColor(1, 0, 0, 0.2)
        flash:ClearAllPoints()
        flash:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
        flash:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    end

    if btn.SpellHighlightTexture then
        btn.SpellHighlightTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.SpellHighlightTexture:ClearAllPoints()
        btn.SpellHighlightTexture:SetAllPoints(btn)
    end

    if not btn.KT_SMP_Disabled then
        local t = btn:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetTexture(SMP .. "Normal")
        t:SetVertexColor(0.77, 0.12, 0.23, 1)
        t:SetBlendMode("BLEND")
        btn.KT_SMP_Disabled = t
    end
    btn.KT_SMP_Disabled:ClearAllPoints()
    btn.KT_SMP_Disabled:SetPoint("TOPLEFT", btn, "TOPLEFT", -offset, offset)
    btn.KT_SMP_Disabled:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", offset, -offset)
end

-- ============================================================================
-- SHAPE MASKING (Universal)
-- ============================================================================

function Mod:ApplyShape(btn)
    local db = KT.db.profile.actionbars
    local name = btn:GetName()
    local shape = GetShapeForButton(name)

    local icon = _G[name .. "Icon"]
    local canMutateCooldown = CanMutateActionButtonCooldown(btn)
    local cooldown = canMutateCooldown and (btn.cooldown or _G[name .. "Cooldown"]) or nil
    local chargeCd = canMutateCooldown and (btn.chargeCooldown or _G[name .. "ChargeCooldown"]) or nil
    local flash = _G[name .. "Flash"]
    local pushed = btn:GetPushedTexture()
    local checked = btn:GetCheckedTexture()
    local highlight = btn:GetHighlightTexture()

    -- 1. Limpiar máscaras anteriores
    if btn.KT_ShapeMask then
        if icon and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, btn.KT_ShapeMask) end
        if cooldown and cooldown.RemoveMaskTexture then pcall(cooldown.RemoveMaskTexture, cooldown, btn.KT_ShapeMask) end
        if chargeCd and chargeCd.RemoveMaskTexture then pcall(chargeCd.RemoveMaskTexture, chargeCd, btn.KT_ShapeMask) end
        if flash and flash.RemoveMaskTexture then pcall(flash.RemoveMaskTexture, flash, btn.KT_ShapeMask) end
        if pushed and pushed.RemoveMaskTexture then pcall(pushed.RemoveMaskTexture, pushed, btn.KT_ShapeMask) end
        if checked and checked.RemoveMaskTexture then pcall(checked.RemoveMaskTexture, checked, btn.KT_ShapeMask) end
        if highlight and highlight.RemoveMaskTexture then pcall(highlight.RemoveMaskTexture, highlight, btn.KT_ShapeMask) end

        if btn.KT_ActionFlash and btn.KT_ActionFlash.texture and btn.KT_ActionFlash.texture.RemoveMaskTexture then
            pcall(btn.KT_ActionFlash.texture.RemoveMaskTexture, btn.KT_ActionFlash.texture, btn.KT_ShapeMask)
        end

        if btn.KT_BG and btn.KT_BG.RemoveMaskTexture then
            pcall(btn.KT_BG.RemoveMaskTexture, btn.KT_BG, btn.KT_ShapeMask)
        end
        btn.KT_ShapeMask:Hide()
        btn.KT_ShapeMaskPath = nil
    end

    -- 2. Restaurar a cuadrado si es NONE o BLIZZARD style
    if shape == "NONE" then
        if db.buttonStyle == "KUI" and btn.KT_BorderLines then
            for i = 1, 4 do btn.KT_BorderLines[i]:Show() end
        elseif db.buttonStyle == "SIMPLICITY" and btn.KT_SMP_Normal then
            btn.KT_SMP_Normal:SetTexture(SMP .. "Normal")
            if checked then checked:SetTexture(SMP .. "Border") end
            if btn.KT_SMP_Disabled then btn.KT_SMP_Disabled:SetTexture(SMP .. "Normal") end
        end
        ConfigureCooldownSwipe(cooldown, "NONE", nil)
        ConfigureCooldownSwipe(chargeCd, "NONE", nil)
        return
    end

    -- 3. Aplicar Texturas de Forma
    local maskTex = SHAPE_MASKS[shape]
    local borderTex = SHAPE_BORDERS[shape]
    if not maskTex then return end

    if not btn.KT_ShapeMask then
        btn.KT_ShapeMask = btn:CreateMaskTexture()
    end

    btn.KT_ShapeMask:SetTexture(maskTex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    btn.KT_ShapeMask:ClearAllPoints()
    btn.KT_ShapeMask:SetAllPoints(btn)
    btn.KT_ShapeMask:Show()

    local mask = btn.KT_ShapeMask

    if btn.KT_BorderLines then
        for i = 1, 4 do btn.KT_BorderLines[i]:Hide() end
    end
    if btn.KT_SMP_Normal then btn.KT_SMP_Normal:Hide() end

    -- Borde Custom de la forma
    if not btn.KT_ShapeBorder then
        btn.KT_ShapeBorder = btn:CreateTexture(nil, "OVERLAY", nil, 0)
    end
    btn.KT_ShapeBorder:SetTexture(borderTex)
    btn.KT_ShapeBorder:SetVertexColor(0, 0, 0, 1)
    btn.KT_ShapeBorder:ClearAllPoints()

    local offset = (db.buttonStyle == "SIMPLICITY") and 3 or 3
    btn.KT_ShapeBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -offset, offset)
    btn.KT_ShapeBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", offset, -offset)
    btn.KT_ShapeBorder:Show()

    -- Enmascarado Masivo (Con pcall anti-error)
    if icon and icon.AddMaskTexture then pcall(icon.AddMaskTexture, icon, mask) end
    if btn.KT_BG and btn.KT_BG.AddMaskTexture then pcall(btn.KT_BG.AddMaskTexture, btn.KT_BG, mask) end

    if flash and flash.AddMaskTexture then pcall(flash.AddMaskTexture, flash, mask) end
    if pushed and pushed.AddMaskTexture then pcall(pushed.AddMaskTexture, pushed, mask) end
    if highlight and highlight.AddMaskTexture then pcall(highlight.AddMaskTexture, highlight, mask) end

    if btn.KT_ActionFlash and btn.KT_ActionFlash.texture and btn.KT_ActionFlash.texture.AddMaskTexture then
        pcall(btn.KT_ActionFlash.texture.AddMaskTexture, btn.KT_ActionFlash.texture, mask)
    end

    if db.buttonStyle == "SIMPLICITY" then
        if checked and borderTex then
            checked:SetTexture(borderTex)
            checked:ClearAllPoints()
            checked:SetPoint("TOPLEFT", btn, "TOPLEFT", -offset, offset)
            checked:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", offset, -offset)
        end
        if btn.KT_SMP_Disabled and borderTex then btn.KT_SMP_Disabled:SetTexture(borderTex) end
    else
        if checked and checked.AddMaskTexture then pcall(checked.AddMaskTexture, checked, mask) end
    end

    if cooldown and cooldown.AddMaskTexture then
        pcall(cooldown.AddMaskTexture, cooldown, mask)
        if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, true) end
        if cooldown.SetUseCircularEdge then pcall(cooldown.SetUseCircularEdge, cooldown, shape ~= "CSQUARE") end
        if cooldown.SetSwipeTexture and cooldown.KT_KUISwipeTexture ~= maskTex then
            pcall(cooldown.SetSwipeTexture, cooldown, maskTex)
            cooldown.KT_KUISwipeTexture = maskTex
        end
    end
    if chargeCd and chargeCd.AddMaskTexture then
        pcall(chargeCd.AddMaskTexture, chargeCd, mask)
        if chargeCd.SetDrawSwipe then pcall(chargeCd.SetDrawSwipe, chargeCd, true) end
        if chargeCd.SetUseCircularEdge then pcall(chargeCd.SetUseCircularEdge, chargeCd, shape ~= "CSQUARE") end
        if chargeCd.SetSwipeTexture and chargeCd.KT_KUISwipeTexture ~= maskTex then
            pcall(chargeCd.SetSwipeTexture, chargeCd, maskTex)
            chargeCd.KT_KUISwipeTexture = maskTex
        end
    end

    ConfigureCooldownSwipe(cooldown, shape, maskTex)
    ConfigureCooldownSwipe(chargeCd, shape, maskTex)
end

local function RefreshCooldownSwipeShape(btn)
    if not btn or not btn.GetName then
        return
    end

    if not CanMutateActionButtonCooldown(btn) then
        return
    end

    local name = btn:GetName()
    local db = KT.db and KT.db.profile and KT.db.profile.actionbars
    if not db or db.buttonStyle == "BLIZZARD" then
        return
    end

    local shape = GetShapeForButton(name)
    local maskTex = SHAPE_MASKS[shape]
    local frames = {
        btn.cooldown or _G[name .. "Cooldown"],
        btn.chargeCooldown or _G[name .. "ChargeCooldown"],
    }

    for _, cooldown in ipairs(frames) do
        if cooldown then
            if maskTex and cooldown.SetSwipeTexture then
                pcall(cooldown.SetSwipeTexture, cooldown, maskTex)
            end
            ConfigureCooldownSwipe(cooldown, shape, maskTex)
        end
    end
end
function Mod:RefreshCooldownSwipeShapes()
    if self._ktSwipeRefreshPending then
        return
    end
    self._ktSwipeRefreshPending = true
    C_Timer.After(0, function()
        self._ktSwipeRefreshPending = nil
        for _, btn in ipairs(self:GetAllBlizzardButtons()) do
            pcall(RefreshCooldownSwipeShape, btn)
        end
    end)
end

-- ============================================================================
-- CORE
-- ============================================================================

function Mod:StyleAllBars()
    if InCombatLockdown() then return end
    local db = KT.db.profile.actionbars
    if not db then return end
    local buttons = self:GetAllBlizzardButtons()
    for _, btn in ipairs(buttons) do
        self:StyleButton(btn)
    end
end

function Mod:StyleButton(btn)
    if not btn then return end
    local name = btn:GetName()
    if not name then return end
    local db = KT.db.profile.actionbars
    if not db then return end

    HookButtonCooldownEdge(btn)
    ResetButtonStyle(btn)

    if db.buttonStyle == "KUI" then
        self:ApplyModernKUIStyle(btn)
    elseif db.buttonStyle == "SIMPLICITY" then
        self:ApplySimplicityStyle(btn)
    end

    if _G.KullThranUI_ActionButtonEnhancements then
        _G.KullThranUI_ActionButtonEnhancements.EnhanceActionButton(btn)
    end

    self:ApplyShape(btn)

    local hkFont = (KT and KT.ResolveFontForLocale and KT:ResolveFontForLocale(db.hotkeyFont, "Fonts\\FRIZQT__.TTF")) or (LSM and db.hotkeyFont and LSM:Fetch("font", db.hotkeyFont)) or "Fonts\\FRIZQT__.TTF"
    local mFont  = (KT and KT.ResolveFontForLocale and KT:ResolveFontForLocale(db.macroFont, "Fonts\\FRIZQT__.TTF")) or (LSM and db.macroFont and LSM:Fetch("font", db.macroFont)) or "Fonts\\FRIZQT__.TTF"

    local hotkey = _G[name .. "HotKey"]
    if hotkey then
        if db.hideHotkeys then
            hotkey:Hide()
        else
            local text = hotkey:GetText()
            if text == RANGE_INDICATOR then
                hotkey:Hide()
            else
                hotkey:Show()
                hotkey:SetFont(hkFont, db.hotkeyFontSize, db.hotkeyFontOutline)
                hotkey:SetTextColor(db.hotkeyFontColor.r, db.hotkeyFontColor.g, db.hotkeyFontColor.b,
                    db.hotkeyFontColor.a)
                hotkey:ClearAllPoints()
                if db.buttonStyle == "SIMPLICITY" then
                    hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -3)
                else
                    hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -2)
                end
            end
        end
    end

    local macro = _G[name .. "Name"]
    if macro then
        if db.hideMacroText then
            macro:Hide()
        else
            macro:Show()
            macro:SetFont(mFont, db.macroFontSize, db.macroFontOutline)
            macro:SetTextColor(db.macroFontColor.r, db.macroFontColor.g, db.macroFontColor.b, db.macroFontColor.a)
            macro:ClearAllPoints()
            macro:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
        end
    end

    local cooldown = CanMutateActionButtonCooldown(btn) and _G[name .. "Cooldown"] or nil
    if cooldown then
        local font = (KT and KT.ResolveFontForLocale and KT:ResolveFontForLocale(db.font, "Fonts\\FRIZQT__.TTF")) or (LSM and db.font and LSM:Fetch("font", db.font)) or "Fonts\\FRIZQT__.TTF"
        for i = 1, cooldown:GetNumRegions() do
            local region = select(i, cooldown:GetRegions())
            if region and region:GetObjectType() == "FontString" then
                region:SetFont(font, db.fontSize, db.fontOutline)
                region:SetTextColor(db.fontColor.r, db.fontColor.g, db.fontColor.b, db.fontColor.a)
            end
        end
        cooldown:SetIgnoreParentAlpha(false)
        if btn:GetAlpha() < 0.1 then cooldown:SetAlpha(0) end
    end

    if btn.SpellHighlightTexture then
        btn.SpellHighlightTexture:SetIgnoreParentAlpha(false)
        btn.SpellHighlightTexture:SetParent(btn)
    end
end

function Mod:UpdateHotkeys(actionButtonType)
    local name = actionButtonType:GetName()
    local hotkey = _G[name .. "HotKey"]
    local db = KT.db.profile.actionbars
    if not db or not hotkey then return end
    if db.hideHotkeys then
        hotkey:Hide()
    else
        local text = hotkey:GetText()
        if text == RANGE_INDICATOR then hotkey:Hide() else hotkey:Show() end
    end
end

-- ============================================================================
-- FADING & VISIBILIDAD
-- ============================================================================

local function ApplyAlphaToButtonElements(button, alpha)
    if not button then return end
    if button.SetIgnoreParentAlpha then button:SetIgnoreParentAlpha(false) end
    local cd = CanMutateActionButtonCooldown(button)
        and (button.cooldown or _G[button:GetName() .. "Cooldown"]) or nil
    if cd then
        if alpha < 0.1 then
            cd:SetIgnoreParentAlpha(false)
            cd:SetAlpha(0)
            if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0) end
        else
            cd:SetIgnoreParentAlpha(false)
            cd:SetAlpha(1)
            if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.8) end
        end
    end
    if alpha < 0.1 then
        if ActionButton_HideOverlayGlow then ActionButton_HideOverlayGlow(button) end
        if button.SpellHighlightTexture then button.SpellHighlightTexture:SetAlpha(0) end
        if button.AutoCastShine then button.AutoCastShine:SetAlpha(0) end
        local LBG = LibStub("LibButtonGlow-1.0", true)
        if LBG then LBG.HideOverlayGlow(button) end
    else
        if button.SpellHighlightTexture then
            button.SpellHighlightTexture:SetAlpha(1)
            if _G.ActionButton_UpdateOverlayGlow then _G.ActionButton_UpdateOverlayGlow(button) end
        end
        if button.AutoCastShine then button.AutoCastShine:SetAlpha(1) end
    end
end

function Mod:OnShowOverlayGlow(button)
    if button and button:GetParent() and button:GetParent().KT_FadeEnabled then
        local parent = button:GetParent()
        local visuallyHidden = (parent:GetAlpha() or 1) < 0.1
        if visuallyHidden then
            if ActionButton_HideOverlayGlow then ActionButton_HideOverlayGlow(button) end
        end
    end
end

function Mod:OnUpdateOverlayGlow(button)
    if button and button:GetParent() and button:GetParent().KT_FadeEnabled then
        local parent = button:GetParent()
        local visuallyHidden = (parent:GetAlpha() or 1) < 0.1
        if visuallyHidden then
            if button.SpellHighlightTexture then button.SpellHighlightTexture:SetAlpha(0) end
        else
            if button.SpellHighlightTexture then button.SpellHighlightTexture:SetAlpha(1) end
        end
    end
end

local function IsAccessibleMouseValue(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return false end
    if _G.canaccessvalue and not _G.canaccessvalue(value) then return false end
    return true
end

local function GetMouseFocus()
    if _G.GetMouseFoci then
        local foci = _G.GetMouseFoci()
        if IsAccessibleMouseValue(foci) and type(foci) == "table" then
            local focus = foci[1]
            if IsAccessibleMouseValue(focus) then return focus end
        end
        return nil
    end
    local focus = _G.GetMouseFocus and _G.GetMouseFocus()
    return IsAccessibleMouseValue(focus) and focus or nil
end

local function IsMouseOverFrame(frame)
    local over = frame.IsMouseOver and frame:IsMouseOver()
    if IsAccessibleMouseValue(over) and over then return true end
    over = MouseIsOver and MouseIsOver(frame)
    if IsAccessibleMouseValue(over) and over then return true end
    local focus = GetMouseFocus()
    if not focus then return false end
    if focus == frame then return true end
    if not focus.GetParent then return false end
    local success, parent = pcall(focus.GetParent, focus)
    if not success then return false end
    while parent do
        if parent == frame then return true end
        if not parent.GetParent then break end
        success, parent = pcall(parent.GetParent, parent)
        if not success then break end
    end
    return false
end

local function GetButtonsForBar(frame)
    if not frame then return {} end
    local name = frame:GetName()
    local prefix = ""
    if name == "MainMenuBar" or name == "MainActionBar" then prefix = "ActionButton"
    elseif name == "MultiBarBottomLeft" then prefix = "MultiBarBottomLeftButton"
    elseif name == "MultiBarBottomRight" then prefix = "MultiBarBottomRightButton"
    elseif name == "MultiBarRight" then prefix = "MultiBarRightButton"
    elseif name == "MultiBarLeft" then prefix = "MultiBarLeftButton"
    elseif name == "MultiBar5" then prefix = "MultiBar5Button"
    elseif name == "MultiBar6" then prefix = "MultiBar6Button"
    elseif name == "MultiBar7" then prefix = "MultiBar7Button"
    elseif name == "PetActionBar" then prefix = "PetActionButton"
    elseif name == "StanceBar" then prefix = "StanceButton"
    end

    local buttons = {}
    if prefix ~= "" then
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then table.insert(buttons, btn) end
        end
    end
    return buttons
end

local function EnforceBarVisuals(frame, alphaTarget)
    if not frame then return end

    local inCombatSafeMode = IsSecureActionButtonSafeMode() and InCombatLockdown()
    local buttons = GetButtonsForBar(frame)

    for _, child in ipairs(buttons) do
        if child.SetIgnoreParentAlpha then child:SetIgnoreParentAlpha(false) end
        local cd = CanMutateActionButtonCooldown(child)
            and (child.cooldown or _G[child:GetName() .. "Cooldown"]) or nil
        if cd and cd.SetIgnoreParentAlpha then cd:SetIgnoreParentAlpha(false) end
        if child.SpellHighlightTexture and child.SpellHighlightTexture.SetIgnoreParentAlpha then
            child.SpellHighlightTexture:SetIgnoreParentAlpha(false)
        end

        if not inCombatSafeMode then
            ApplyAlphaToButtonElements(child, alphaTarget)
        end
    end
end

local function HandleFade(frame, enable)
    if not frame then return end
    if enable then
        if not frame:IsMouseEnabled() then
            frame:EnableMouse(true)
            frame.KT_MouseEnabled = true
        end
        if frame.KT_IsHovered == nil then
            frame.KT_IsHovered = IsMouseOverFrame(frame)
            frame:SetAlpha(frame.KT_IsHovered and 1 or 0)
            EnforceBarVisuals(frame, frame:GetAlpha())
        end
        if not frame.KT_FadeHooked then
            frame:HookScript("OnUpdate", function(self, elapsed)
                if not self.KT_FadeEnabled then return end
                self.KT_UpdateTimer = (self.KT_UpdateTimer or 0) + elapsed
                if self.KT_UpdateTimer < 0.05 then return end
                self.KT_UpdateTimer = 0

                local isOver = IsMouseOverFrame(self)
                local currentAlpha = self:GetAlpha()
                local targetAlpha = isOver and 1 or 0

                if self.KT_IsHovered ~= isOver then
                    self.KT_IsHovered = isOver
                end

                if math.abs(currentAlpha - targetAlpha) > 0.01 then
                    local step = isOver and 0.2 or -0.2
                    local newAlpha = currentAlpha + step
                    if newAlpha > 1 then newAlpha = 1 end
                    if newAlpha < 0 then newAlpha = 0 end
                    self:SetAlpha(newAlpha)

                    if newAlpha < 0.1 then
                        EnforceBarVisuals(self, 0)
                    elseif newAlpha > 0.9 then
                        EnforceBarVisuals(self, 1)
                    end
                end
            end)
            frame.KT_FadeHooked = true
        end
        frame.KT_FadeEnabled = true
    else
        if frame.KT_FadeEnabled then
            frame.KT_FadeEnabled = false
            frame:SetAlpha(1)
            EnforceBarVisuals(frame, 1)
            if frame.KT_MouseEnabled then
                frame:EnableMouse(false)
                frame.KT_MouseEnabled = nil
            end
            frame.KT_IsHovered = nil
        end
    end
end

function Mod:UpdateMouseoverState()
    local db = KT.db.profile.actionbars
    if not db then return end
    if _G.MainMenuBar then HandleFade(_G.MainMenuBar, db.fadeBar1) end
    if _G.MainActionBar then HandleFade(_G.MainActionBar, db.fadeBar1) end
    if _G.MultiBarBottomLeft then HandleFade(_G.MultiBarBottomLeft, db.fadeBar2) end
    if _G.MultiBarBottomRight then HandleFade(_G.MultiBarBottomRight, db.fadeBar3) end
    if _G.MultiBarRight then HandleFade(_G.MultiBarRight, db.fadeBar4) end
    if _G.MultiBarLeft then HandleFade(_G.MultiBarLeft, db.fadeBar5) end
    if _G.MultiBar5 then HandleFade(_G.MultiBar5, db.fadeBar6) end
    if _G.MultiBar6 then HandleFade(_G.MultiBar6, db.fadeBar7) end
    if _G.MultiBar7 then HandleFade(_G.MultiBar7, db.fadeBar8) end
    if _G.PetActionBar then HandleFade(_G.PetActionBar, db.fadePet) end
    if _G.StanceBar then HandleFade(_G.StanceBar, db.fadeStance) end
end

function Mod:GetAllBlizzardButtons()
    local buttons = {}
    local bars = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
        "MultiBar6Button", "MultiBar7Button", "PetActionButton", "StanceButton",
    }
    for _, prefix in ipairs(bars) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then table.insert(buttons, btn) end
        end
    end
    return buttons
end

local function GetOrCreateTrinketUsableGlow(button)
    Mod._trinketUsableGlows = Mod._trinketUsableGlows or {}
    local glow = Mod._trinketUsableGlows[button]
    if glow then return glow end
    glow = CreateFrame("Frame", nil, UIParent)
    glow:SetFrameStrata("HIGH")
    glow:SetFrameLevel(100)
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
    glow:EnableMouse(false)
    glow.edges = {}
    for index = 1, 4 do
        local edge = glow:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(1, 0.82, 0.08, 0.95)
        edge:SetBlendMode("ADD")
        glow.edges[index] = edge
    end
    glow.edges[1]:SetPoint("TOPLEFT")
    glow.edges[1]:SetPoint("TOPRIGHT")
    glow.edges[1]:SetHeight(3)
    glow.edges[2]:SetPoint("BOTTOMLEFT")
    glow.edges[2]:SetPoint("BOTTOMRIGHT")
    glow.edges[2]:SetHeight(3)
    glow.edges[3]:SetPoint("TOPLEFT")
    glow.edges[3]:SetPoint("BOTTOMLEFT")
    glow.edges[3]:SetWidth(3)
    glow.edges[4]:SetPoint("TOPRIGHT")
    glow.edges[4]:SetPoint("BOTTOMRIGHT")
    glow.edges[4]:SetWidth(3)
    glow:SetAlpha(0)
    Mod._trinketUsableGlows[button] = glow
    return glow
end

function Mod:UpdateEquippedTrinketGlows()
    local buttons = self:GetAllBlizzardButtons()
    self._equippedTrinketButtons = self._equippedTrinketButtons or {}

    -- Action identity can become secret in restricted combat. Resolve and cache
    -- the equipped trinket slots only while the values are public.
    if not (InCombatLockdown and InCombatLockdown()) then
        local slot13 = _G.GetInventoryItemID and _G.GetInventoryItemID("player", 13)
        local slot14 = _G.GetInventoryItemID and _G.GetInventoryItemID("player", 14)
        for _, button in ipairs(buttons) do
            local action = button.action
            local actionType, itemID
            if action and _G.GetActionInfo then
                actionType, itemID = _G.GetActionInfo(action)
            end
            self._equippedTrinketButtons[button] = actionType == "item" and itemID
                and (itemID == slot13 or itemID == slot14) or nil
        end
    end

    for _, button in ipairs(buttons) do
        local action = button.action
        local isEquippedTrinket = self._equippedTrinketButtons[button] == true
        local glow = self._trinketUsableGlows and self._trinketUsableGlows[button]
        if isEquippedTrinket then
            glow = glow or GetOrCreateTrinketUsableGlow(button)
            local cooldown = button.cooldown or (button.GetName and _G[button:GetName() .. "Cooldown"])
            if cooldown and cooldown.IsShown and cooldown:IsShown() then
                glow:SetAlpha(0)
            else
                local usable = _G.IsUsableAction and _G.IsUsableAction(action)
                if glow.SetAlphaFromBoolean then
                    glow:SetAlphaFromBoolean(usable, 1, 0)
                elseif not _G.issecretvalue or not _G.issecretvalue(usable) then
                    glow:SetAlpha(usable and 1 or 0)
                end
            end
        elseif glow then
            glow:SetAlpha(0)
        end
    end
end

function Mod:ToggleHideHotkeys(enabled)
    local db = KT.db.profile.actionbars
    if not db then return end
    db.hideHotkeys = enabled
    self:StyleAllBars()
end

function Mod:ToggleHideMacroText(enabled)
    local db = KT.db.profile.actionbars
    if not db then return end
    db.hideMacroText = enabled
    self:StyleAllBars()
end
