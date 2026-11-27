-- Draws the player's class resource on the current target's nameplate.
-- Costs nothing while the option is off: the watcher, pips and bars are made only when needed, and frames are kept.

local _, ns = ...

local M = {}
ns.NameplatesClassPower = M

local PIP_COUNT = 10
local THROTTLE = 0.1
local VENGEANCE_SPELL = 228477
local POWER_FOCUS = 2
local POWER_INSANITY = 13
local FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local PORTRAITS = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local MASK_TEXTURE = PORTRAITS .. "circle_mask.tga"
local RING_TEXTURE = PORTRAITS .. "circle_border.tga"
local KUI_COMBO_TEXTURE = PORTRAITS .. "kui_combo.png"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local ART_PATH = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\OptionCards\\"

-- Resources with their own piece: Enum.PowerType field, the client's atlases (the art the player
-- frame shows), and the local piece with its colour for a client that lacks them.
local RESOURCE_ART = {
    SoulShards = { ready = "Warlock-ReadyShard", empty = "Warlock-EmptyShard",
        file = "cp_shard.png", color = { 0.62, 0.38, 0.95 }, label = "Soul Shards", pips = 5 },
    HolyPower = { ready = "nameplates-holypower%d-on", empty = "nameplates-holypower%d-off",
        file = "cp_holy.png", color = { 1.00, 0.82, 0.28 }, label = "Holy Power", pips = 5 },
    Chi = { ready = "uf-chi-icon", empty = "uf-chi-bg",
        file = "cp_chi.png", color = { 0.35, 1.00, 0.72 }, label = "Chi", pips = 5 },
    Essence = { ready = "UF-Essence-Icon", empty = "UF-Essence-BG",
        file = "cp_essence.png", color = { 0.30, 0.85, 0.85 }, label = "Essence", pips = 5 },
    ArcaneCharges = { ready = "Mage-ArcaneCharge",
        file = "cp_arcane.png", color = { 0.45, 0.60, 1.00 }, label = "Arcane Charges", pips = 4 },
    Runes = { empty = "DK-Rune-CD",
        file = "cp_rune.png", color = { 0.35, 0.75, 1.00 }, label = "Runes", pips = 6 },
}
local RUNE_SPEC = {
    [250] = { "DK-Blood-Rune-Ready", 1.00, 0.22, 0.22 },
    [251] = { "DK-Frost-Rune-Ready", 0.35, 0.75, 1.00 },
    [252] = { "DK-Unholy-Rune-Ready", 0.40, 0.95, 0.40 },
}
local LookupSpecID

-- Classes with one resource: Enum.PowerType field, fallback pips. The class token is only ever used as a table key.
local SINGLE_RESOURCE = {
    ROGUE = { "ComboPoints", 5 },
    DRUID = { "ComboPoints", 5 },
    PALADIN = { "HolyPower", 5 },
    WARLOCK = { "SoulShards", 5 },
    MAGE = { "ArcaneCharges", 4 },
    EVOKER = { "Essence", 5 },
    DEATHKNIGHT = { "Runes", 6 },
}
-- Classes that depend on the spec: a resource name, or a field and fallback pips as above.
local SPEC_RESOURCE = {
    MONK = { [268] = "BREWMASTER_STAGGER", [269] = { "Chi", 5 } },
    DEMONHUNTER = { [581] = "SOUL_FRAGMENTS_VENGEANCE" },
    SHAMAN = { [263] = "MAELSTROM_WEAPON" },
    PRIEST = { [258] = "INSANITY_BAR" },
    HUNTER = { [253] = "FOCUS_BAR", [254] = "FOCUS_BAR", [255] = "TIP_OF_THE_SPEAR" },
    WARRIOR = { [72] = "WHIRLWIND_STACKS" },
}
local FORM_RULE = { DRUID = 1 }
local BAR_RESOURCE = { BREWMASTER_STAGGER = true, INSANITY_BAR = true, FOCUS_BAR = true }

local NATIVE_UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "PLAYER_SPECIALIZATION_CHANGED" }
local STRING_UNIT_EVENTS = { "UNIT_AURA", "PLAYER_SPECIALIZATION_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" }
local STRING_PLAIN_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_REGEN_ENABLED" }

local cfg               -- the main file's interface; getters are called through it when needed
local PP
local isForever
local powerTypes        -- Enum.PowerType
local comboType         -- its ComboPoints
local runeType          -- its Runes
local classColors
local defaultColor

local watcher
local fallbackPips
local formRule
local throttleSum = 0

-- The display test's form half: only asked when a form rule exists.
local function FormRuleHolds()
    local getForm = GetShapeshiftFormID
    return type(getForm) == "function" and getForm() == formRule
end

-- The resource's own colour, following the spec for runes, or nothing. Accepts the Enum value.
local function ResourceColor(resource)
    if resource == nil or not powerTypes then return nil end
    for name, art in pairs(RESOURCE_ART) do
        if powerTypes[name] == resource then
            local color = art.color
            if name == "Runes" then
                local spec = RUNE_SPEC[LookupSpecID()]
                if spec then return spec[2], spec[3], spec[4] end
            end
            return color[1], color[2], color[3]
        end
    end
end

-- Returns the tint's three components, with no table.
local function ClassTint()
    if cfg.GetClassPowerClassColors() then
        local r, g, b = ResourceColor(M.resourceType)
        if r then return r, g, b end
        local _, token = UnitClass("player")
        local color = classColors[token] or defaultColor
        return color[1], color[2], color[3]
    end
    local color = cfg.GetClassPowerCustomColor()
    return color.r, color.g, color.b
end

local function SetClassPowerPipDecor(pip, show)
    if not pip then return end
    if show and not pip._border then
        local parent = pip._bg:GetParent()

        local border = parent:CreateTexture(nil, "OVERLAY", nil, 1)
        border:SetColorTexture(0, 0, 0, 1)
        border:SetPoint("TOPLEFT", pip, "TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", 1, -1)
        pip._border = border

        local shadow = parent:CreateTexture(nil, "OVERLAY", nil, 0)
        shadow:SetColorTexture(0, 0, 0, 0.5)
        shadow:SetPoint("TOPLEFT", pip, "TOPLEFT", -2, 1)
        shadow:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", 2, -3)
        pip._shadow = shadow
    end

    local shown = not not show
    local border = pip._border
    if border then border:SetShown(shown) end
    local shadow = pip._shadow
    if shadow then shadow:SetShown(shown) end
end

local function AtlasSize(name)
    local api = C_Texture
    local info = name and api and api.GetAtlasInfo and api.GetAtlasInfo(name)
    if info and info.width and info.height and info.height > 0 then return info.width, info.height end
end

-- The atlas of pip i, with its number filled in when the art differs per pip.
local function PipAtlas(pattern, i)
    return pattern and pattern:format(i)
end

-- The resource's piece and colour, or nil when it has none. Accepts the Enum value.
local function ResourceArt(resource)
    if resource == nil or not powerTypes then return nil end
    for name, art in pairs(RESOURCE_ART) do
        if powerTypes[name] == resource then
            local ready = art.ready
            if name == "Runes" then
                local spec = RUNE_SPEC[LookupSpecID()]
                if spec then ready = spec[1] end
            end
            local w, h = AtlasSize(PipAtlas(ready, 1))
            local r, g, b = ResourceColor(resource)
            return {
                ready = ready, empty = art.empty, file = art.file, label = art.label, pips = art.pips,
                aspect = w and w / h or 1,
            }, r, g, b
        end
    end
end

-- Paints a texture with pip i of a resource. A tint (a custom Fill Color) recolours the client's art.
local function PaintClassPowerArt(tex, art, i, lit, r, g, b, tinted)
    local atlas = PipAtlas(lit and art.ready or art.empty or art.ready, i)
    if AtlasSize(PipAtlas(art.ready, i)) and AtlasSize(atlas) then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetAtlas(atlas, false)
        tex:SetDesaturated(tinted and true or false)
        local dim = (not lit and not art.empty) and 0.3 or 1
        if tinted then
            tex:SetVertexColor(r * dim, g * dim, b * dim, 1)
        else
            tex:SetVertexColor(dim, dim, dim, 1)
        end
        return
    end
    tex:SetDesaturated(false)
    tex:SetTexture(ART_PATH .. art.file)
    tex:SetTexCoord(0, 1, 0, 1)
    if lit then
        tex:SetVertexColor(r, g, b, 1)
    else
        tex:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.9)
    end
end

local function ClassPowerPipLayout(isCombo, scale, gap, shape, hasArt)
    if hasArt then return 18 * hasArt * scale, 18 * scale, (gap + 2) * scale, false, false end
    local round = false
    if isCombo then
        if shape == nil then shape = cfg.GetClassPowerShape() end
        round = shape ~= "pip"
    end

    local getStyle = ns.NameplateStyle
    local look = getStyle and getStyle()
    local styled = look ~= nil and look ~= "kui"
    local wide = isForever or styled

    local width, height, spacing
    if round then
        width, height, spacing = 16, 16, gap + 4
    elseif isCombo and wide then
        width, height, spacing = 18, 7, gap + 4
    elseif not isCombo and wide then
        width, height, spacing = 11.2, 3, gap + 2
    else
        width, height, spacing = 8, 3, gap
    end

    local red = false
    if isCombo then red = isForever or styled end
    return width * scale, height * scale, spacing * scale, round, red
end

-- Combo point art per Combo Point Shape: a socket, with the gem on top while the point is lit.
-- Crops are (left, top, right, bottom) in pixels of the file.
--   retail : the client's uf-roguecp-bg-2x / -bg-dis-2x / -icon-red-2x (silver socket)
--   forever: the client's uf-roguecp-bg-c60-2x / -bg-dis-c60-2x / -icon-red-c60-2x (bronze socket)
--   circle : KUI Style's own socket and white gem (kui_combo.png, drawn in Photoshop), tinted.
-- By file and crop: SetAtlas would give the running client's variant, never the other one.
local COMBO_ART = {
    retail = { file = 4902602, w = 1024, h = 1024, on = { 593, 1, 633, 41 }, off = { 593, 127, 633, 167 },
        gem = { 549, 225, 577, 254 }, gemSize = 28 / 40 },
    -- The Retail client has no -c60 art: Forever's crops ship with the addon (socket, empty, gem).
    forever = { file = PORTRAITS .. "forever_combo_c60.png", w = 128, h = 64, on = { 0, 0, 44, 44 }, off = { 44, 0, 88, 44 },
        gem = { 88, 0, 116, 28 }, gemSize = 28 / 44 },
    circle = { file = KUI_COMBO_TEXTURE, w = 128, h = 64, on = { 0, 0, 64, 64 }, off = { 0, 0, 64, 64 },
        gem = { 64, 0, 128, 64 }, gemSize = 1, tinted = true },
}
M.COMBO_ART = COMBO_ART

local function SetCrop(tex, file, w, h, c)
    tex:SetTexture(file)
    tex:SetTexCoord(c[1] / w, c[3] / w, c[2] / h, c[4] / h)
end

local function ApplyClassPowerPipShape(pip, round, shape)
    if not pip then return end
    local getStyle = ns.NameplateStyle
    local look = getStyle and getStyle()
    local bg = pip._bg
    local mask = pip._circleMask
    local secretBar = pip._secretBar
    local barTexture
    if (round or mask) and secretBar and secretBar.GetStatusBarTexture then
        barTexture = secretBar:GetStatusBarTexture()
    end

    if round and shape == nil and cfg and cfg.GetClassPowerShape then shape = cfg.GetClassPowerShape() end
    local art = round and not secretBar and COMBO_ART[shape] or nil
    pip._comboArt = art
    if not art and pip._cpIcon then pip._cpIcon:Hide() end
    if art then
        if mask then
            mask:Hide()
            if bg and bg.RemoveMaskTexture then pcall(bg.RemoveMaskTexture, bg, mask) end
            if pip.RemoveMaskTexture then pcall(pip.RemoveMaskTexture, pip, mask) end
        end
        local ring = pip._circleBorder
        if not ring then
            ring = pip:GetParent():CreateTexture(nil, "OVERLAY", nil, 1)
            ring:SetAllPoints(pip)
            pip._circleBorder = ring
        end
        SetCrop(ring, art.file, art.w, art.h, art.off)
        ring:SetDrawLayer("OVERLAY", 1)
        ring:SetVertexColor(1, 1, 1, 1)
        ring:Show()
        local icon = pip._cpIcon
        if not icon then
            icon = pip:GetParent():CreateTexture(nil, "OVERLAY", nil, 5)
            pip._cpIcon = icon
        end
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", pip, "CENTER", 0, 0)
        icon:SetSize((pip:GetWidth() or 16) * art.gemSize, (pip:GetHeight() or 16) * art.gemSize)
        SetCrop(icon, art.file, art.w, art.h, art.gem)
        icon:SetVertexColor(1, 1, 1, 1)
        icon:Hide()
        pip:SetTexCoord(0, 1, 0, 1)
        SetClassPowerPipDecor(pip, false)
        return
    end

    if round then
        if not mask then
            mask = pip:GetParent():CreateMaskTexture()
            pip._circleMask = mask
        end
        mask:SetTexture(MASK_TEXTURE, MASK_WRAP, MASK_WRAP)
        mask:ClearAllPoints()
        mask:SetAllPoints(pip)
        mask:Show()

        -- Protected by handing method and arguments to pcall, so no closure is made.
        if bg then
            if bg.RemoveMaskTexture then pcall(bg.RemoveMaskTexture, bg, mask) end
            if bg.AddMaskTexture then pcall(bg.AddMaskTexture, bg, mask) end
        end
        if pip.RemoveMaskTexture then pcall(pip.RemoveMaskTexture, pip, mask) end
        if pip.AddMaskTexture then pcall(pip.AddMaskTexture, pip, mask) end
        if barTexture and barTexture.AddMaskTexture then
            pcall(barTexture.AddMaskTexture, barTexture, mask)
        end

        local ring = pip._circleBorder
        if not ring then
            ring = pip:GetParent():CreateTexture(nil, "OVERLAY", nil, 4)
            ring:SetAllPoints(pip)
            pip._circleBorder = ring
        end

        ring:SetTexture(RING_TEXTURE)
        ring:SetTexCoord(0, 1, 0, 1)
        ring:SetDrawLayer("OVERLAY", 4)
        ring:SetVertexColor(1, 0.82, 0.08, 1)
        pip:SetTexCoord(0, 1, 0, 1)
        ring:Show()
        SetClassPowerPipDecor(pip, false)
        return
    end

    if mask then
        mask:Hide()
        if bg and bg.RemoveMaskTexture then pcall(bg.RemoveMaskTexture, bg, mask) end
        if pip.RemoveMaskTexture then pcall(pip.RemoveMaskTexture, pip, mask) end
        if barTexture and barTexture.RemoveMaskTexture then
            pcall(barTexture.RemoveMaskTexture, barTexture, mask)
        end
    end
    local ring = pip._circleBorder
    if ring then ring:Hide() end
    pip:SetTexCoord(0, 1, 0, 1)
    SetClassPowerPipDecor(pip, isForever or (look ~= nil and look ~= "kui"))
end

-- A combo point drawn with COMBO_ART: lit shows the gem (tinted for KUI Style, red by
-- default) and the lit socket. Returns false when the pip has no such art.
local function StyleForeverComboPip(pip, lit, r, g, b)
    local art = pip and pip._comboArt
    if not art then return false end
    if pip._bg then pip._bg:Hide() end
    pip:SetColorTexture(0, 0, 0, 0)
    local ring = pip._circleBorder
    if ring then
        SetCrop(ring, art.file, art.w, art.h, lit and art.on or art.off)
        ring:Show()
    end
    local icon = pip._cpIcon
    if icon then
        if art.tinted then icon:SetVertexColor(r or 1, g or 0.05, b or 0.05, 1) end
        icon:SetShown(lit and true or false)
    end
    return true
end

-- A plate or preview pip showing the resource's piece instead of the flat fill.
local function StyleClassPowerArtPip(pip, art, i, lit, r, g, b, tinted)
    ApplyClassPowerPipShape(pip, false)
    SetClassPowerPipDecor(pip, false)
    pip._bg:Hide()
    PaintClassPowerArt(pip, art, i, lit, r, g, b, tinted)
end

-- Hides one pip's fill, background, ring and decoration; the secret bar is the caller's decision.
local function HidePipKeepBar(pip)
    pip:Hide()
    pip._bg:Hide()
    local ring = pip._circleBorder
    if ring then ring:Hide() end
    if pip._cpIcon then pip._cpIcon:Hide() end
    SetClassPowerPipDecor(pip, false)
end

-- The hide variant that leaves secret bars shown (B6).
local function HideAllPipsKeepBars(pips)
    for i = 1, PIP_COUNT do
        HidePipKeepBar(pips[i])
    end
end

local function HidePlate(plate)
    local pips = plate and plate._cpPips
    if not pips then return end
    for i = 1, PIP_COUNT do
        local pip = pips[i]
        HidePipKeepBar(pip)
        local secretBar = pip._secretBar
        if secretBar then secretBar:Hide() end
    end
    local bar = plate._cpBar
    if bar then bar:Hide() end
end

local function EnsurePips(plate)
    if plate._cpPips then return end
    local pips = {}
    for i = 1, PIP_COUNT do
        local bg = plate:CreateTexture(nil, "OVERLAY", nil, 2)
        bg:SetColorTexture(0.082, 0.082, 0.082, 1)
        bg:Hide()

        local fill = plate:CreateTexture(nil, "OVERLAY", nil, 3)
        fill:SetColorTexture(1, 1, 1, 1)
        PP.Size(fill, 8, 3)
        fill:Hide()
        fill._bg = bg

        pips[i] = fill
    end
    plate._cpPips = pips
end

-- Stagger, Insanity and Focus: one shared status bar under or over the plate.
local function PaintBar(plate, pips, resource, scale, yOffset, xOffset, bgColor, anchorPoint, relFrame, relPoint, sign)
    for i = 1, PIP_COUNT do
        local pip = pips[i]
        HidePipKeepBar(pip)
        local secretBar = pip._secretBar
        if secretBar then secretBar:Hide() end
    end

    local bar = plate._cpBar
    if not bar then
        bar = CreateFrame("StatusBar", nil, plate)
        bar:SetStatusBarTexture(FLAT_TEXTURE)
        bar:SetFrameLevel(plate:GetFrameLevel() + 5)
        bar:Hide()
        local backdrop = bar:CreateTexture(nil, "BACKGROUND")
        backdrop:SetAllPoints()
        backdrop:SetColorTexture(0.082, 0.082, 0.082, 1)
        bar._bg = backdrop
        plate._cpBar = bar
    end

    local isStagger = resource == "BREWMASTER_STAGGER"
    local checkSecret = issecretvalue
    local current, max, staggerSecret
    if isStagger then
        current = UnitStagger("player")
        max = UnitHealthMax("player")
        local currentSecret = checkSecret and checkSecret(current)
        local maxSecret = checkSecret and checkSecret(max)
        staggerSecret = currentSecret or maxSecret
        if not currentSecret then current = current or 0 end
        if not maxSecret and (max == nil or max <= 0) then max = 1 end
    else
        local powerType = resource == "INSANITY_BAR" and POWER_INSANITY or POWER_FOCUS
        current = UnitPower("player", powerType) or 0
        max = UnitPowerMax("player", powerType) or 100
        if checkSecret and checkSecret(max) then
            max = 100
        elseif max <= 0 then
            max = 100
        end
    end

    bar:ClearAllPoints()
    PP.Size(bar, 8 * scale * 6, 3 * scale)
    PP.Point(bar, anchorPoint, relFrame, relPoint, xOffset, sign * yOffset)
    bar:SetMinMaxValues(0, max)
    bar:SetValue(current)

    if not isStagger then
        local r, g, b = ClassTint()
        bar:SetStatusBarColor(r, g, b, 1)
    elseif staggerSecret then
        local r, g, b = ClassTint()
        bar:SetStatusBarColor(r, g, b)
    else
        local ratio = current / max
        if ratio >= 0.6 then
            bar:SetStatusBarColor(1.0, 0.2, 0.2)
        elseif ratio >= 0.3 then
            bar:SetStatusBarColor(1.0, 0.85, 0.2)
        else
            bar:SetStatusBarColor(0.2, 0.8, 0.2)
        end
    end

    bar._bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
    bar:Show()
end

-- Every other resource: one texture per cell, with a status bar per pip on the Vengeance secret path.
local function PaintPips(plate, pips, resource, scale, yOffset, xOffset, bgColor, anchorPoint, relFrame, relPoint, sign)
    local sharedBar = plate._cpBar
    if sharedBar then sharedBar:Hide() end

    local current, max
    local secretPath, tracked = false, false
    if resource == "SOUL_FRAGMENTS_VENGEANCE" then
        local spellApi = C_Spell
        local getCount = spellApi and spellApi.GetSpellCastCount
        -- Possibly secret: a falsy default (B9), then only ever passed to SetValue.
        current = getCount and getCount(VENGEANCE_SPELL) or 0
        max = 6
        secretPath = true
    elseif resource == "MAELSTROM_WEAPON" then
        current, max = KullThranUI.GetMaelstromWeapon()
        tracked = true
    elseif resource == "TIP_OF_THE_SPEAR" then
        current, max = KullThranUI:GetTipOfTheSpear()
        tracked = true
    elseif resource == "WHIRLWIND_STACKS" then
        current, max = KullThranUI:GetWhirlwindStacks()
        tracked = true
    elseif resource == runeType then
        max = UnitPowerMax("player", resource)
        if max == nil or max <= 0 then max = 6 end
        current = 0
        local getRune = GetRuneCooldown
        if getRune then
            for i = 1, max do
                local _, _, ready = getRune(i)
                if ready then current = current + 1 end
            end
        end
    else
        -- Not secret-aware: a secret raises at the max test or at the lit test (B5).
        local core = KullThranUI
        if resource == comboType and core and core.ReadComboPoints then
            current = core.ReadComboPoints(resource) or 0
        else
            current = UnitPower("player", resource) or 0
        end
        max = UnitPowerMax("player", resource) or fallbackPips
        if max <= 0 then max = fallbackPips end
    end

    if tracked and (max == nil or max <= 0) then
        HideAllPipsKeepBars(pips)
        return
    end
    -- A tracked count that is secret in combat fills through the status bars, as Vengeance does.
    if tracked then
        local checkSecret = issecretvalue
        if checkSecret and checkSecret(current) then
            secretPath = true
        else
            current = current or 0
        end
    end

    local art, artR, artG, artB, artTinted
    if cfg.GetClassPowerShape() ~= "pip" then
        art, artR, artG, artB = ResourceArt(resource)
        if art and not cfg.GetClassPowerClassColors() then
            artR, artG, artB = ClassTint()
            artTinted = true
        end
    end

    local width, height, gap, round, red = ClassPowerPipLayout(resource == comboType, scale, cfg.GetClassPowerGap(), nil, art and art.aspect)
    local stride = width + gap
    local half = ((max - 1) * stride + width) / 2

    local tintR, tintG, tintB = ClassTint()
    local empty = cfg.GetClassPowerEmptyColor()
    local groupPoint = anchorPoint == "BOTTOM" and "BOTTOMLEFT" or "TOPLEFT"
    local y = sign * yOffset

    local litR, litG, litB, dimR, dimG, dimB, backR, backG, backB
    if red then
        litR, litG, litB = 1.0, 0.05, 0.05
        dimR, dimG, dimB = 0.22, 0.02, 0.02
        backR, backG, backB = 0.22, 0.02, 0.02
    else
        litR, litG, litB = tintR, tintG, tintB
        dimR, dimG, dimB = empty.r, empty.g, empty.b
        backR, backG, backB = bgColor.r, bgColor.g, bgColor.b
    end
    local dimA, backA = empty.a, bgColor.a

    for i = 1, PIP_COUNT do
        local pip = pips[i]
        if i > max then
            HidePipKeepBar(pip)
            local secretBar = pip._secretBar
            if secretBar then secretBar:Hide() end
        else
            pip:ClearAllPoints()
            PP.Size(pip, width, height)
            ApplyClassPowerPipShape(pip, round)
            PP.Point(pip, groupPoint, relFrame, relPoint, (i - 1) * stride - half + xOffset, y)

            local bg = pip._bg
            bg:ClearAllPoints()
            bg:SetAllPoints(pip)
            bg:SetColorTexture(backR, backG, backB, backA)
            bg:Show()

            local secretBar = pip._secretBar
            if secretPath then
                if not secretBar then
                    secretBar = CreateFrame("StatusBar", nil, plate)
                    secretBar:SetStatusBarTexture(FLAT_TEXTURE)
                    secretBar:SetFrameLevel(plate:GetFrameLevel() + 5)
                    pip._secretBar = secretBar
                end
                secretBar:ClearAllPoints()
                secretBar:SetAllPoints(pip)
                secretBar:SetMinMaxValues(i - 1, i)
                secretBar:SetValue(current)
                secretBar:SetStatusBarColor(litR, litG, litB, 1)
                ApplyClassPowerPipShape(pip, round)
                secretBar:Show()
                pip:SetColorTexture(dimR, dimG, dimB, dimA)
            else
                if secretBar then secretBar:Hide() end
                local lit = i <= current
                if art then
                    StyleClassPowerArtPip(pip, art, i, lit, artR, artG, artB, artTinted)
                else
                    pip:SetDesaturated(false)
                    pip:SetVertexColor(1, 1, 1, 1)
                    if lit then
                        pip:SetColorTexture(litR, litG, litB, 1)
                    else
                        pip:SetColorTexture(dimR, dimG, dimB, dimA)
                    end
                    StyleForeverComboPip(pip, lit, litR, litG, litB)
                end
            end

            pip:Show()
        end
    end
end

local function UpdatePlate(plate)
    local pips = plate and plate._cpPips
    if not pips then return end

    local resource = M.resourceType
    if resource == nil or (formRule and not FormRuleHolds()) then
        HideAllPipsKeepBars(pips)
        local bar = plate._cpBar
        if bar then bar:Hide() end
        return
    end

    local scale = cfg.GetClassPowerScale()
    local yOffset = cfg.GetClassPowerYOffset()
    local xOffset = cfg.GetClassPowerXOffset()
    local position = cfg.GetClassPowerPos()
    local bgColor = cfg.GetClassPowerBgColor()

    local anchorPoint, relFrame, relPoint, sign
    if position == "top" then
        anchorPoint, relFrame, relPoint, sign = "BOTTOM", plate.health, "TOP", 1
    elseif plate.isCasting and plate.cast:IsShown() then
        anchorPoint, relFrame, relPoint, sign = "TOP", plate.cast, "BOTTOM", -1
    else
        anchorPoint, relFrame, relPoint, sign = "TOP", plate.health, "BOTTOM", -1
    end

    if BAR_RESOURCE[resource] then
        PaintBar(plate, pips, resource, scale, yOffset, xOffset, bgColor, anchorPoint, relFrame, relPoint, sign)
    else
        PaintPips(plate, pips, resource, scale, yOffset, xOffset, bgColor, anchorPoint, relFrame, relPoint, sign)
    end
end

local function TopPush(plate)
    if not cfg.GetShowClassPower() then return 0 end
    local resource = M.resourceType
    if resource == nil then return 0 end
    if formRule and not FormRuleHolds() then return 0 end
    if cfg.GetClassPowerPos() ~= "top" then return 0 end
    if not plate then return 0 end
    local unit = plate.unit
    if not unit then return 0 end
    if not UnitIsUnit(unit, "target") then return 0 end

    local scale = cfg.GetClassPowerScale()
    local height
    if BAR_RESOURCE[resource] then
        height = 3 * scale
    else
        local _
        local art = cfg.GetClassPowerShape() ~= "pip" and ResourceArt(resource)
        _, height = ClassPowerPipLayout(resource == comboType, scale, cfg.GetClassPowerGap(), nil, art and art.aspect)
    end
    return height + cfg.GetClassPowerYOffset()
end

-- One pass over the plates: the target is painted and the rest hidden. A full refresh also re-anchors.
local function Refresh(full)
    local display = not formRule or FormRuleHolds()
    for _, plate in pairs(ns.plates) do
        local unit = plate.unit
        if display and unit and UnitIsUnit(unit, "target") then
            EnsurePips(plate)
            UpdatePlate(plate)
        else
            HidePlate(plate)
        end
        if full and unit then
            plate:RefreshNamePosition()
            plate:UpdateRaidIcon()
        end
    end
end

local function RefreshFull()
    Refresh(true)
end

local function TurnOff()
    if not watcher then return end
    watcher:SetScript("OnUpdate", nil)
    watcher:SetScript("OnEvent", nil)
    watcher:UnregisterAllEvents()
    watcher:Hide()

    M.resourceType = nil
    watcher = nil
    formRule = nil

    for _, plate in pairs(ns.plates) do
        HidePlate(plate)
        if plate.unit then
            plate:UpdateRaidIcon()
            plate:RefreshNamePosition()
        end
    end
end

local ApplyClassPowerSetting

-- A new spec may have another resource, or none: resolve it again.
local function OnSpecChanged()
    TurnOff()
    ApplyClassPowerSetting()
end

local function OnNativeEvent(_, event)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        OnSpecChanged()
        return
    end
    Refresh(event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM")
end

local function OnStringEvent(_, event, unit, castGUID, spellID)
    if event == "PLAYER_TARGET_CHANGED" then
        Refresh(true)
        return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        OnSpecChanged()
        return
    end

    local core = KullThranUI
    if core then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit == "player" then
                if core.HandleTipOfTheSpear then core:HandleTipOfTheSpear(event, unit, castGUID, spellID) end
                if core.HandleWhirlwindStacks then core:HandleWhirlwindStacks(event, unit, castGUID, spellID) end
            end
        elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
            if core.HandleTipOfTheSpear then core:HandleTipOfTheSpear(event) end
            if core.HandleWhirlwindStacks then core:HandleWhirlwindStacks(event) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if core.HandleWhirlwindStacks then core:HandleWhirlwindStacks(event) end
        end
    end
    Refresh(false)
end

local function OnStringUpdate(_, elapsed)
    throttleSum = throttleSum + elapsed
    if throttleSum >= THROTTLE then
        throttleSum = 0
        Refresh(false)
    end
end

-- The player's spec ID, or nil. Each function may be missing; the index never reaches the info function as nil.
LookupSpecID = function()
    local specApi = C_SpecializationInfo
    local getIndex = specApi and specApi.GetSpecialization
    local index = getIndex and getIndex()
    if not index then
        getIndex = GetSpecialization
        index = getIndex and getIndex()
    end
    if not index then return nil end

    local getInfo = specApi and specApi.GetSpecializationInfo
    if not getInfo then getInfo = GetSpecializationInfo end
    if not getInfo then return nil end
    return (getInfo(index))
end

-- Returns the resource and its fallback pips, or nil. A missing Enum field means no resource.
local function ResolveResource(class)
    local entry = SINGLE_RESOURCE[class]
    if not entry then
        local specs = SPEC_RESOURCE[class]
        if not specs then return nil end
        local specID = LookupSpecID()
        if specID == nil then return nil end
        entry = specs[specID]
        if type(entry) ~= "table" then return entry end
    end
    return powerTypes and powerTypes[entry[1]], entry[2]
end

local function RegisterAll(frame, list, unit)
    for i = 1, #list do
        if unit then
            frame:RegisterUnitEvent(list[i], unit)
        else
            frame:RegisterEvent(list[i])
        end
    end
end

local function TurnOn()
    if watcher then return end

    local _, class = UnitClass("player")
    local resource, fallback = ResolveResource(class)
    if resource == nil then
        -- Nothing to draw, but learning a spec that has a resource must not need a reload.
        local frame = CreateFrame("Frame")
        frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
        frame:SetScript("OnEvent", OnSpecChanged)
        watcher = frame
        return
    end

    M.resourceType = resource
    fallbackPips = fallback
    formRule = FORM_RULE[class]

    local frame = CreateFrame("Frame")
    if type(resource) == "string" then
        RegisterAll(frame, STRING_UNIT_EVENTS, "player")
        RegisterAll(frame, STRING_PLAIN_EVENTS)
        if resource == "BREWMASTER_STAGGER" then
            frame:RegisterUnitEvent("UNIT_HEALTH", "player")
            frame:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
        end
        throttleSum = 0
        frame:SetScript("OnEvent", OnStringEvent)
        frame:SetScript("OnUpdate", OnStringUpdate)
    else
        RegisterAll(frame, NATIVE_UNIT_EVENTS, "player")
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        if formRule then frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM") end
        if resource == runeType then frame:RegisterEvent("RUNE_POWER_UPDATE") end
        local core = KullThranUI
        if resource == comboType and core and core.RegisterComboTargetEvents then
            core.RegisterComboTargetEvents(frame)
        end
        frame:SetScript("OnEvent", OnNativeEvent)
    end
    watcher = frame

    Refresh(true)
end

ApplyClassPowerSetting = function()
    if cfg.GetShowClassPower() then
        TurnOn()
    else
        TurnOff()
    end
end

function M.Setup(ctx)
    if type(ctx) ~= "table" then
        error("NameplatesClassPower.Setup: ctx is required", 2)
    end
    local client = ctx.client
    if client ~= "retail" and client ~= "forever" then
        error("NameplatesClassPower.Setup: ctx.client must be retail or forever", 2)
    end

    cfg = ctx
    PP = ctx.PP
    isForever = client == "forever"
    powerTypes = Enum and Enum.PowerType
    comboType = powerTypes and powerTypes.ComboPoints
    runeType = powerTypes and powerTypes.Runes or nil

    -- A copy made once, so later changes of the client's table do not reach it.
    classColors = {}
    local source = RAID_CLASS_COLORS
    if source then
        for key, color in pairs(source) do
            if type(color) == "table" and color.r then
                classColors[key] = { color.r, color.g, color.b }
            end
        end
    end
    defaultColor = { 1.00, 0.84, 0.30 }

    ns.CP_CLASS_COLORS = classColors
    ns.CP_DEFAULT_COLOR = defaultColor
    ns.ClassPowerPipLayout = ClassPowerPipLayout
    ns.ApplyClassPowerPipShape = ApplyClassPowerPipShape
    ns.SetClassPowerPipDecor = SetClassPowerPipDecor
    ns.StyleForeverComboPip = StyleForeverComboPip
    ns.ClassPowerResourceArt = ResourceArt
    ns.ClassPowerResourceColor = ResourceColor
    -- The colour "use the class colour" gives right now: the resource's for this spec, else the class's.
    ns.PlayerClassPowerColor = function()
        local _, class = UnitClass("player")
        return ResourceColor((ResolveResource(class)))
    end
    ns.StyleClassPowerArtPip = StyleClassPowerArtPip
    ns.PaintClassPowerArt = PaintClassPowerArt
    ns.PlayerClassPowerArt = function()
        local _, class = UnitClass("player")
        return ResourceArt((ResolveResource(class)))
    end
    ns.ApplyClassPowerSetting = ApplyClassPowerSetting
    ns.RefreshClassPower = RefreshFull

    M.UpdatePlate = UpdatePlate
    M.HidePlate = HidePlate
    M.EnsurePips = EnsurePips
    M.TopPush = TopPush
end
