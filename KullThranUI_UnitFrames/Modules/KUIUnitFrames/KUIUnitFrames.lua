local addonName, ns = ...

local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("UnitFrames", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
local oUF = ns.oUF or oUF
local Compat = ns.KUIUFCompat or {}
ns.KUIUFCompat = Compat
ns.UnitFrames = Mod

Compat.PP = Compat.PP or {}
local PP = Compat.PP

if not oUF then
    error("KUIUnitFrames: oUF library not found! Please install oUF to Libraries\\oUF\\ folder.")
    return
end

local db
local RefreshPlayerStatusIndicators
local SetupPlayerStatusIndicators

-- â”€â”€â”€ Ruta base para los iconos de indicadores de estado â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local KUI_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\"
local PVP_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\"

local CLASSIFICATION_TEXTURES = {
    elite = KUI_ICON_PATH .. "ELITE.png",
    worldboss = KUI_ICON_PATH .. "ELITE.png",
    rareelite = KUI_ICON_PATH .. "RARE.png",
    rare = KUI_ICON_PATH .. "RARE.png",
}
local CLASSIFICATION_NAMEPLATE_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\Nemapltes-RareEliteIcons\\Untitled - 18 de agosto de 2026 a las 22.39.01.png"
local CLASSIFICATION_NO_PORTRAIT_TEXTURES = {
    elite = CLASSIFICATION_NAMEPLATE_ICON_PATH,
    worldboss = CLASSIFICATION_NAMEPLATE_ICON_PATH,
    rareelite = CLASSIFICATION_NAMEPLATE_ICON_PATH,
    rare = CLASSIFICATION_NAMEPLATE_ICON_PATH,
}
ns.CLASSIFICATION_NO_PORTRAIT_STYLES = {
    nameplate = CLASSIFICATION_NO_PORTRAIT_TEXTURES,
    unitframes = CLASSIFICATION_TEXTURES,
}
local CLASSIFICATION_NO_PORTRAIT_SIZE = 52
local CLASSIFICATION_PORTRAIT_SCALE = 1.18
-- ELITE.png and RARE.png are square 512x512 textures.
local CLASSIFICATION_TEXTURE_ASPECT = 1
-- The modern Rare/Elite PNGs: their opening is slightly oval (radius ~0.28
-- of the texture vertically, ~0.31 horizontally) and centred left of and
-- below the texture centre. Measured in game around the Forever ring.
ns.ModernClassificationRing = {
    centerX = 0.03,
    centerY = 0.03,
    holeRadius = 0.298,
}
-- Blizzard Classic's own Rare/Elite frame sheets (same 256x128 layout as
-- UI-TargetingFrame, so they replace it 1:1 in the Classic style). Outside Classic
-- the player can show a crop of the portrait side as an overlay ring; the crop
-- numbers are in 232x100 art pixels of the TARGET orientation (portrait on the right)
-- and are tunable. {unverified in game}
ns.ClassicRing = {
    base = "Interface\\TargetingFrame\\UI-TargetingFrame",
    sheets = {
        elite = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite",
        rare = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare",
        rareelite = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare-Elite",
    },
    -- The same sheets with only the dragon left: each Blizzard sheet also
    -- carries the whole normal frame (portrait ring, level circle, bar
    -- panel), which must not show over a KUI/Forever/Retail frame. Same
    -- 256x128 layout, so the crop numbers below apply unchanged.
    dragons = {
        elite = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\classic_dragon_elite.blp",
        rare = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\classic_dragon_rare.blp",
        rareelite = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\classic_dragon_rareelite.blp",
    },
    cropW = 120, cropH = 100,          -- crop size (art px): wide enough for the dragon's head and tail
    -- Centre of the sheet's portrait opening inside the PLAYER (mirrored) crop,
    -- measured on the Blizzard sheets (the stock portrait sits at 74, 44).
    portraitCX = 74.5, portraitCY = 45.5,
    uLeft = 1, uRight = 0.53125, vTop = 0, vBottom = 0.78125, -- player (mirrored) texcoords
    -- Outside Classic the dragon's inner edge (~35 art px from the centre of
    -- the 64px Classic portrait) sits on ns.ClassificationRingReach.
    innerRadius = 35,
}
function ns.ClassicRing.KindForClassification(c)
    if c == "elite" or c == "worldboss" then return "elite" end
    if c == "rareelite" then return "rareelite" end
    if c == "rare" then return "rare" end
    return nil
end
-- Art px -> screen px for the dragon crop around `backdrop` (see ClassificationRingReach).
function ns.ClassicRing.ArtScale(backdrop, reach)
    local size = backdrop:GetHeight() or 0
    if size < 1 then size = backdrop:GetWidth() or 0 end
    if size < 1 then size = 46 end
    return size * reach / ns.ClassicRing.innerRadius
end
local OVERLAY_ANCHORS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
local function IsForeverSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function SafeUnitPvPFaction(unit)
    if not unit or type(UnitIsPVP) ~= "function" or type(UnitFactionGroup) ~= "function" then
        return nil
    end
    local ok, enabled = pcall(UnitIsPVP, unit)
    if not ok or IsForeverSecretValue(enabled) or (enabled ~= true and enabled ~= 1) then
        return nil
    end
    ok, enabled = pcall(UnitFactionGroup, unit)
    if not ok or IsForeverSecretValue(enabled) then return nil end
    if enabled == "Horde" or enabled == "Alliance" then return enabled end
    return nil
end


local function SafeUnitLevelText(unit)
    if not unit then return nil end
    if type(UnitExists) == "function" then
        local ok, exists = pcall(UnitExists, unit)
        if not ok or exists == false then return nil end
    end

    local level
    local levelAPIRan = false

    -- Forever exposes the effective level through the same API used by oUF.
    -- Prefer it because UnitLevel may return an unknown/legacy sentinel.
    if type(UnitEffectiveLevel) == "function" then
        local ok, value = pcall(UnitEffectiveLevel, unit)
        if ok and not IsForeverSecretValue(value) then
            levelAPIRan = true
            if type(value) == "number" then level = value end
        end
    end
    if (type(level) ~= "number" or level <= 0) and type(UnitLevel) == "function" then
        local ok, value = pcall(UnitLevel, unit)
        if ok and not IsForeverSecretValue(value) then
            levelAPIRan = true
            if type(value) == "number" then level = value end
        end
    end

    if type(level) == "number" and level > 0 then return tostring(level) end
    -- Keep the target indicator visible when the unit exists but Forever cannot
    -- disclose a numeric level; this matches oUF's "??" level-tag behavior.
    if levelAPIRan then return "??" end
    return nil
end

-------------------------------------------------------------------------------
--  Blizzard look for the stock-art styles (Classic / Forever / Retail).
--  Kept on ns so this chunk does not take more file-level locals.
-------------------------------------------------------------------------------
function ns.RenderedStyle()
    local VT = KT.VisualThemes
    return (VT and VT.GetRenderedTheme and VT:GetRenderedTheme()) or "kui"
end

function ns.IsStockStyle(theme)
    theme = theme or ns.RenderedStyle()
    return theme == "classic" or theme == "forever" or theme == "retail"
end

-- Unset toggles follow the style: on for Classic/Forever/Retail, off for KUI Style.
function ns.StockStyleToggle(profile, key, theme)
    local v = profile and profile[key]
    if v ~= nil then return v ~= false end
    return ns.IsStockStyle(theme)
end

-- Font of a Blizzard font object (path, size, flags), or the given fallback.
function ns.BlizzardFont(objectName, fbPath, fbSize, fbFlags)
    local vt = KT.VisualThemes
    if vt and vt.GetNativeStockFont then
        return vt:GetNativeStockFont(objectName, fbPath, fbSize, fbFlags)
    end
    local obj = _G[objectName]
    if obj and obj.GetFont then
        local ok, path, size, flags = pcall(obj.GetFont, obj)
        if ok and type(path) == "string" and type(size) == "number" and size > 0 then
            return path, size, flags or ""
        end
    end
    return fbPath, fbSize, fbFlags
end

function ns.SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not IsForeverSecretValue(value) then return value end
    return nil
end

-- Level number color, following Blizzard's PlayerFrame/TargetFrame rules:
-- the player in yellow (green while level-scaled on modern clients), units
-- that cannot be attacked in yellow, attackable units by difficulty
-- (grey / green / yellow / orange / red).
function ns.BlizzardLevelColor(unit, theme)
    if unit == "player" and (theme == "forever" or theme == "retail") then return 1, 1, 1 end
    local nr, ng, nb = 1, 0.82, 0
    local nonAttack = _G.UNIT_LEVEL_NON_ATTACKABLE
    if theme == "classic" and type(nonAttack) == "table" and nonAttack.r then
        nr, ng, nb = nonAttack.r, nonAttack.g, nonAttack.b
    end
    if not unit then return nr, ng, nb end
    if ns.SafeCall(UnitIsUnit, unit, "player") then
        if theme ~= "classic" then
            local level, effective = ns.SafeCall(UnitLevel, unit), ns.SafeCall(UnitEffectiveLevel, unit)
            if type(level) == "number" and type(effective) == "number" and level ~= effective then
                return 0.1, 1.0, 0.1
            end
        end
        return nr, ng, nb
    end
    if not ns.SafeCall(UnitCanAttack, "player", unit) then return nr, ng, nb end
    local color
    if theme ~= "classic" and C_PlayerInfo and type(GetDifficultyColor) == "function" then
        local difficulty = ns.SafeCall(C_PlayerInfo.GetContentDifficultyCreatureForPlayer, unit)
        if difficulty ~= nil then color = ns.SafeCall(GetDifficultyColor, difficulty) end
    end
    if type(color) ~= "table" then
        local level = (theme ~= "classic" and ns.SafeCall(UnitEffectiveLevel, unit)) or ns.SafeCall(UnitLevel, unit)
        if type(level) == "number" and level > 0 then
            color = ns.SafeCall(GetCreatureDifficultyColor or GetQuestDifficultyColor, level)
        elseif type(level) == "number" then
            -- Level hidden ("??"): far above the player.
            return 1, 0.1, 0.1
        end
    end
    if type(color) == "table" and color.r then return color.r, color.g, color.b end
    return nr, ng, nb
end

function ns.CenterStockLevelText(text, circle, theme)
    if theme ~= "forever" and theme ~= "retail" then return false end
    if not (text and circle) then return false end
    text:ClearAllPoints()
    text:SetPoint("CENTER", circle, "CENTER", 0, 0)
    text:SetSize(circle:GetWidth(), circle:GetHeight())
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    return true
end

function ns.ApplyGroupLeaderStyle(frame, tex, unit, theme, portrait, scale, guide)
    if not (frame and tex) then return false end
    tex:ClearAllPoints()
    if theme ~= "classic" and theme ~= "forever" and theme ~= "retail" then
        tex:SetSize(14, 14)
        tex:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", -2, 10)
        if unit == "player" then tex:Hide() end
        return false
    end
    scale = scale or 1
    local atlas = guide and "UI-HUD-UnitFrame-Player-Group-GuideIcon"
        or "UI-HUD-UnitFrame-Player-Group-LeaderIcon"
    local info = theme ~= "classic" and C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo(atlas)
    if info and tex.SetAtlas then
        tex:SetAtlas(atlas, false)
        tex:SetSize((info.width or 16) * scale, (info.height or 16) * scale)
    else
        tex:SetTexture(guide and "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
            or "Interface\\GroupFrame\\UI-Group-LeaderIcon")
        if guide then tex:SetTexCoord(0, 0.296875, 0.015625, 0.3125)
        else tex:SetTexCoord(0, 1, 0, 1) end
        tex:SetSize(16 * scale, 16 * scale)
    end
    local right = unit == "target" or unit == "focus" or tostring(unit):match("^boss")
    if portrait and portrait:IsShown() then
        -- Native crown offsets relative to the portrait, so detached/moved
        -- portraits and classification art keep the same attachment point.
        if theme == "classic" then
            local edge = right and "TOPRIGHT" or "TOPLEFT"
            tex:SetPoint(edge, portrait, edge, (right and -4 or 4) * scale, 2 * scale)
        elseif right then
            tex:SetPoint("TOPRIGHT", portrait, "TOPLEFT", -1 * scale, 11 * scale)
        else
            tex:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 2 * scale, 9 * scale)
        end
    else
        local edge = right and "TOPRIGHT" or "TOPLEFT"
        tex:SetPoint("BOTTOM" .. (right and "RIGHT" or "LEFT"), frame.Health, edge,
            (right and -2 or 2) * scale, 16 * scale)
    end
    return true
end

function ns.RefreshGroupLeaderStyle(frame, unit, guide)
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    local scale = (frame.GetWidth and frame:GetWidth() or 232) / 232
    if scale <= 0 then scale = 1 end
    return ns.ApplyGroupLeaderStyle(frame, frame.LeaderIndicator, unit, theme,
        frame.Portrait and frame.Portrait.backdrop, scale, guide)
end

function ns.UnitInCombat(unit)
    return ns.SafeCall(UnitAffectingCombat, unit) and true or false
end

-- Blizzard's combat (crossed swords) icon for a level circle.
function ns.ApplyBlizzardCombatIcon(tex, theme, size)
    if theme ~= "classic" and C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo("UI-HUD-UnitFrame-Player-CombatIcon") then
        tex:SetAtlas("UI-HUD-UnitFrame-Player-CombatIcon", false)
        tex:SetSize(size * 0.7, size * 0.7)
    else
        tex:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
        tex:SetTexCoord(0.5, 1, 0, 0.484375)
        tex:SetSize(size, size)
    end
end

-- Enemies without mana (rage, energy or no power at all) get an empty power
-- bar background instead of a filled one. A custom background color set by
-- the user is kept.
-- In combat an enemy's power capacity is secret, so it cannot be read. What was
-- known when the unit was selected (out of combat) is remembered per target
-- selection: a resource-less NPC must not start painting a full white bar
-- once its fight begins.
ns.powerTargetSerial = 0
do
    local serialFrame = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGET", "UNIT_PET" }) do
        serialFrame:RegisterEvent(e)
    end
    serialFrame:SetScript("OnEvent", function() ns.powerTargetSerial = ns.powerTargetSerial + 1 end)
end
function ns.UpdatePowerBackground(power, unit, settings)
    if not power then return end
    local fill = power.GetStatusBarTexture and power:GetStatusBarTexture()
    local maxPower = unit and ns.SafeCall(UnitPowerMax, unit)
    -- A zero-capacity NPC has no resource. A 0..0 StatusBar can still paint
    -- its full white texture, so suppress the fill as well as the background.
    -- Never inspect secret power values; let oUF render those normally.
    local empty = false
    if unit ~= "player" and type(maxPower) == "number" then
        if not (issecretvalue and issecretvalue(maxPower)) then
            empty = maxPower <= 0
            power._ktEmptyKnown, power._ktEmptySerial = empty, ns.powerTargetSerial
        elseif power._ktEmptySerial == ns.powerTargetSerial then
            empty = power._ktEmptyKnown == true
        end
    end
    local opacity = settings and settings.powerBarOpacity or 100
    if opacity > 1 then opacity = opacity / 100 end
    local bgColor = settings and settings.customPowerBgColor
        or { r = 17/255, g = 17/255, b = 17/255 }
    if power.bg then
        power.bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 1)
        power.bg:SetAlpha(empty and 0 or opacity)
    end
    if fill then fill:SetAlpha(empty and 0 or opacity) end
    power._ktEmptyBg = empty or nil
end

-- The native boss sheet's circular opening is centred at (72,80) with
-- diameter 116 in its 2x pixels. Atlas padding changes the outer box, not
-- this aperture. Mirroring must move the aperture along with the image.
ns.NATIVE_PLAYER_DRAGON_SCALE = 0.88
-- Every Rare/Elite ring (ours, Blizzard's native dragon, the Classic dragon)
-- goes AROUND the style's own portrait border instead of replacing it, as
-- the native dragon overlay does: the ring's opening sits on the outer edge
-- of that border, given as a fraction of the portrait box height. KUI's
-- circle border reaches 54/128; Forever/Retail's stock ring 0.47 (measured in
-- game); Classic's ring ~36/64. The Classic dragon's spiky inner edge reads
-- best a little further out on the stock ring (0.52, accepted in game).
function ns.ClassificationRingReach(renderedTheme, classicKit, classicDragon)
    if renderedTheme == "classic" or classicKit then return 36 / 64 end
    if renderedTheme == "forever" or renderedTheme == "retail" then
        return classicDragon and 0.52 or 0.47
    end
    return 54 / 128
end
-- Vertical centre of the native boss atlas's opening, in its 1x pixels: the
-- dragon sat ~5px low around the Forever ring with the drawn centre (40).
ns.NATIVE_APERTURE_Y = 43
-- KUI Style has no frame of its own, only the thin class-coloured circle. The
-- native dragon's body curls ~12px away from it on the portrait side while its
-- head and tail touch it, so it is scaled down and nudged toward the circle
-- (fractions of the circle's outer radius; measured against the ring art).
ns.NATIVE_KUI_FIT = { scale = 0.88, dx = 0.235, dy = 0.12 }
-- The modern ELITE/RARE.png ring: its body ran ~3px over the circle on the
-- lower left and left ~1px clear on the upper right (in game), so around the
-- circle it is nudged toward the lower left (fractions of the ring width,
-- toward the portrait's far side for Target).
ns.KUI_MODERN_RING_FIT = 1.0
ns.KUI_MODERN_RING_NUDGE = { dx = 0.019, dy = -0.019 }
-- Classic's ring is as thin as KUI's circle: the modern ring sat ~3px right and
-- ~2px high of it (in game), the native dragon curls away from it the same way.
ns.CLASSIC_MODERN_RING_NUDGE = { dx = 0.021, dy = -0.014 }
function ns.ModernRingReach(renderedTheme, classicKit)
    local reach = ns.ClassificationRingReach(renderedTheme, classicKit)
    if renderedTheme == "kui" then reach = reach * ns.KUI_MODERN_RING_FIT end
    return reach
end
function ns.ModernRingNudge(renderedTheme)
    local n = (renderedTheme == "kui" and ns.KUI_MODERN_RING_NUDGE)
        or (renderedTheme == "classic" and ns.CLASSIC_MODERN_RING_NUDGE) or nil
    return n and n.dx or 0, n and n.dy or 0
end
function ns.NativeRingFit(renderedTheme)
    if renderedTheme == "kui" or renderedTheme == "classic" then return ns.NATIVE_KUI_FIT end
    return nil
end
ns.NATIVE_CLASSIFICATION = {
    elite = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold" },
    rare = { atlas = "ui-hud-unitframe-target-portraiton-boss-rare-silver" },
    worldboss = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged" },
}

function ns.NativeClassificationKind(classification)
    if classification == "worldboss" or classification == "elite" then return classification end
    if classification == "rare" or classification == "rareelite" then return "rare" end
    return nil
end

function ns.HasNativeClassificationArt(kind)
    local def = kind and ns.NATIVE_CLASSIFICATION[kind]
    return def and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(def.atlas) and true or false
end

-- Draws (or hides, kind = nil) the native overlay around `portrait`. Mirrored
-- when the portrait sits on the left of its frame. Lives just under `above`
-- so the level and PvP badges stay on top.
function ns.ShowNativeClassificationRing(frame, portrait, kind, mirror, above)
    local tex = frame._kuiNativeClassRing
    local def = kind and ns.NATIVE_CLASSIFICATION[kind]
    local info = def and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(def.atlas)
    if not (info and portrait) then
        if tex then tex:Hide() end
        return false
    end
    local host = frame._kuiNativeClassHost
    if not tex then
        host = CreateFrame("Frame", nil, frame)
        host:SetAllPoints(frame)
        host:EnableMouse(false)
        frame._kuiNativeClassHost = host
        tex = host:CreateTexture(nil, "OVERLAY", nil, 6)
        frame._kuiNativeClassRing = tex
    end
    if above then
        host:SetFrameStrata(above:GetFrameStrata())
        host:SetFrameLevel(math.max(1, above:GetFrameLevel() - 1))
    end
    local portraitSize = portrait:GetHeight()
    if not portraitSize or portraitSize <= 0 then portraitSize = portrait:GetWidth() end
    if not portraitSize or portraitSize <= 0 then portraitSize = 58 end
    -- The aperture (radius 29 at k = 1) sits on the outer edge of the style's
    -- own portrait border (see ns.ClassificationRingReach).
    local fit = frame._ktClassRingFit
    local k = portraitSize * (frame._ktClassRingReach or 0.5) / 29 * (fit and fit.scale or 1)
    local width = (info.width or 80) * k
    local height = (info.height or 80) * k

    -- SetAtlas followed by SetTexCoord crops inside the atlas region. Paint the
    -- atlas file directly so horizontal mirroring keeps the complete dragon.
    local atlasFile = info.file or info.filename
    if atlasFile and info.leftTexCoord and info.rightTexCoord
        and info.topTexCoord and info.bottomTexCoord then
        local left, right = info.leftTexCoord, info.rightTexCoord
        if mirror then left, right = right, left end
        tex:SetTexture(atlasFile)
        tex:SetTexCoord(left, right, info.topTexCoord, info.bottomTexCoord)
    else
        -- Defensive fallback for clients exposing atlas dimensions but not the
        -- backing-file coordinates.
        tex:SetAtlas(def.atlas, false)
        if mirror then
            local ulx, uly, llx, lly, urx, ury, lrx, lry = tex:GetTexCoord()
            tex:SetTexCoord(urx, ury, lrx, lry, ulx, uly, llx, lly)
        end
    end
    tex:SetSize(width, height)
    tex:ClearAllPoints()
    local apertureX = 36 * k
    local offsetX = width / 2 - apertureX
    local shiftX, shiftY = 0, 0
    if fit then
        -- Toward the portrait: right for the left-hand Player, left for Target.
        local outer = portraitSize * (frame._ktClassRingReach or 0.5)
        shiftX = (mirror and 1 or -1) * fit.dx * outer
        shiftY = fit.dy * outer
    end
    tex:SetPoint("CENTER", portrait, "CENTER", (mirror and -offsetX or offsetX) + shiftX,
        ns.NATIVE_APERTURE_Y * k - height / 2 + shiftY)
    tex:Show()
    return true
end

-- A small 2px viewport inset keeps model tips below the native rim without
-- shrinking the portrait to an inscribed square (which leaves a crescent).
function ns.SeatNativePortraitModel(backdrop)
    local model = backdrop and backdrop._3d
    if not model then return end
    local scale = backdrop._ktNativeClassificationScale or 1
    local inset = backdrop:GetHeight() * ((1 - scale) / 2 + 2 / 58 * scale)
    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", backdrop, "TOPLEFT", inset, -inset)
    model:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -inset, inset)
end

-- Keep the modern Player dragon's opening across later generic shape
-- refreshes (attached/circular/detached); those must not replace this mask.
function ns.SeatNativePlayerPortrait(backdrop)
    if not backdrop then return end
    local mask = backdrop._shapeMask
    if not mask then
        mask = backdrop:CreateMaskTexture()
        backdrop._shapeMask = mask
    end
    local inset = backdrop:GetHeight() * (1 - (backdrop._ktNativeClassificationScale or 1)) / 2
    mask:SetAtlas("CircleMask", false)
    mask:SetTexCoord(0, 1, 0, 1)
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", backdrop, "TOPLEFT", inset, -inset)
    mask:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -inset, inset)
    mask:Show()
    backdrop._ktStockPortraitMaskExpand = -inset
    for _, key in ipairs({"_2d", "_class", "_bg"}) do
        local region = backdrop[key]
        if region and region.AddMaskTexture then
            if region.RemoveMaskTexture then region:RemoveMaskTexture(mask) end
            region:AddMaskTexture(mask)
        end
    end
    if backdrop._shapeBorderTex then backdrop._shapeBorderTex:Hide() end
    if backdrop._sqBorderTexs then
        for _, border in ipairs(backdrop._sqBorderTexs) do border:Hide() end
    end
    ns.SeatNativePortraitModel(backdrop)
end

function ns.NativeClassificationHeadReach(kind)
    local def = kind and ns.NATIVE_CLASSIFICATION[kind]
    local info = def and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(def.atlas)
    if not (info and info.width) then return nil end
    return 36 -- distance from the opening centre to the sheet's head-side edge
end

-- Player stock geometry: portrait centre (54,49), radius 30;
-- the power bar ends at y=71 and starts at x=85. Extend to the circle's
-- edge at that bottom row, with 2px underneath the foreground portrait.
function ns.NativePlayerBarExtension(portraitHeight)
    local scale = portraitHeight / 60
    local radius = 30 * ns.NATIVE_PLAYER_DRAGON_SCALE
    local reach = math.sqrt(math.max(0, radius * radius - 27 * 27))
    return (28 - reach + 2) * scale
end

-- One time per profile: the Blizzard level and name text become the default
-- of the Classic/Forever/Retail styles, except where the player already
-- customised the level text or the name text by hand.
function ns.MigrateBlizzardTextDefaults(profile)
    if type(profile) ~= "table" or profile._blizzardTextDefaults20261003 then return end
    local function near(a, b) return math.abs((tonumber(a) or 0) - b) < 0.01 end
    if profile.levelBlizzardStyle == nil then
        local c = profile.levelColor
        local customLevel = (profile.levelFont ~= nil and profile.levelFont ~= "AAA_ITC_Avant_Garde")
            or (profile.levelFontSize ~= nil and tonumber(profile.levelFontSize) ~= 11)
            or (profile.levelFontOutline ~= nil and profile.levelFontOutline ~= "OUTLINE")
            or (type(c) == "table" and not (near(c.r, 1) and near(c.g, 0.82) and near(c.b, 0.20)))
        if customLevel then profile.levelBlizzardStyle = false end
    end
    if profile.blizzardNameStyle == nil then
        for _, key in ipairs({ "player", "target", "focus" }) do
            local u = profile[key]
            if type(u) == "table" and (u.leftTextClassColor == true or u.centerTextClassColor == true
                or (u.leftTextSize ~= nil and tonumber(u.leftTextSize) ~= 14)) then
                profile.blizzardNameStyle = false
                break
            end
        end
    end
    profile._blizzardTextDefaults20261003 = true
end

-- The Target always shows its buffs, above the frame, in every style.
function ns.EnforceTargetBuffs(profile)
    local t = profile and profile.target
    if type(t) ~= "table" then return end
    t.showBuffs = true
    if t.buffAnchor ~= "topleft" and t.buffAnchor ~= "topright" then
        t.buffAnchor = (t.buffAnchor == "bottomright" or t.buffAnchor == "right") and "topright" or "topleft"
    end
    if t.buffGrowth == "down" then t.buffGrowth = "auto" end
    if tonumber(t.maxBuffs) and t.maxBuffs < 1 then t.maxBuffs = 20 end
end

-- Curse / Poison / Bleed / Magic overlays: on by default only in KUI Style.
function ns.IsDispelOverlayOn(settings)
    local v = settings and settings.dispelOverlay
    if v ~= nil then return v ~= false end
    return ns.RenderedStyle() == "kui"
end

-- Theme accent for small ornaments (PvP circle border, combo pips):
-- Forever bronze, Retail yellow, Classic white (pips) / yellow (PvP circle).
-- Classic style: cast bars look like Classic's unit-frame bars (Blizzard StatusBar texture,
-- Classic cast yellow) and their text is capped to the slim bar so it never clips.
ns.CLASSIC_CAST_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
function ns.ApplyClassicCastbarLook(frame)
    local cb = frame and frame.Castbar
    if not (cb and cb.SetStatusBarTexture) then return end
    local VT = KT.VisualThemes
    local isClassic = VT and VT.GetRenderedTheme and VT:GetRenderedTheme() == "classic"
    if isClassic then
        local tex = ns.CLASSIC_CAST_TEXTURE
        cb:SetStatusBarTexture(tex)
        local sbt = cb:GetStatusBarTexture()
        if sbt and sbt.SetHorizTile then sbt:SetHorizTile(false) end
        if cb.castTintLayer then cb.castTintLayer:SetTexture(tex) end
        local _, _, _, a = cb:GetStatusBarColor()
        cb:SetStatusBarColor(1.0, 0.70, 0.0, a or 1)
        cb._ktClassicLook = true
        local bg = cb:GetParent()
        local h = bg and bg.GetHeight and bg:GetHeight()
        if h and h > 0 then
            cb._ktClassicTextCap = math.max(7, h * 0.55)
            for _, fs in ipairs({ cb.Text, cb.Time }) do
                if fs and fs.GetFont and fs.SetFont then
                    -- Any later SetFont (settings pass, font refresh) is re-capped, so the
                    -- text can never grow taller than the slim Classic bar again.
                    if not fs._ktCapHook then
                        fs._ktCapHook = true
                        hooksecurefunc(fs, "SetFont", function(self, path, size, flags)
                            local cap = cb._ktClassicLook and cb._ktClassicTextCap
                            if cap and type(size) == "number" and size > cap and not self._ktCapBusy then
                                self._ktCapBusy = true
                                self:SetFont(path, cap, flags)
                                self._ktCapBusy = nil
                            end
                        end)
                    end
                    local path, size, flags = fs:GetFont()
                    if path and size and size > cb._ktClassicTextCap then
                        fs._ktCapBusy = true
                        fs:SetFont(path, cb._ktClassicTextCap, flags)
                        fs._ktCapBusy = nil
                    end
                end
            end
            -- The spell icon was tiny and sat under the frame art: enlarge it and lift it above.
            local icon = cb._iconFrame
            if icon and icon.SetSize then
                if cb._updateIconLayout then cb._updateIconLayout() end
                local ov = frame._kuiIndicatorOverlay
                if ov then
                    icon:SetFrameStrata(ov:GetFrameStrata())
                    icon:SetFrameLevel(ov:GetFrameLevel() + 3)
                end
            end
        end
    elseif cb._ktClassicLook then
        cb._ktClassicLook = nil
        local bg2 = cb:GetParent()
        if cb._iconFrame and bg2 then
            cb._iconFrame:SetFrameStrata(bg2:GetFrameStrata())
            cb._iconFrame:SetFrameLevel(bg2:GetFrameLevel() + 1)
        end
        cb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        local sbt = cb:GetStatusBarTexture()
        if sbt and sbt.SetHorizTile then sbt:SetHorizTile(false) end
        if cb.castTintLayer then cb.castTintLayer:SetTexture("Interface\\Buttons\\WHITE8X8") end
    end
end

function ns.GetThemeOrnamentColor(theme, classicColor)
    if theme == "forever" then return 0.80, 0.56, 0.24 end
    if theme == "retail" then return 0.96, 0.76, 0.22 end -- gold, not yellow
    if classicColor then return classicColor[1], classicColor[2], classicColor[3] end
    return 1, 1, 1
end

local function SafeUnitClassification(unit)
    if not unit or type(UnitClassification) ~= "function" then return nil end
    local ok, classification = pcall(function()
        return UnitClassification(unit)
    end)
    if not ok then return nil end
    return classification
end

local function SafeUnitClassificationTexture(unit)
    local classification = SafeUnitClassification(unit)
    return CLASSIFICATION_TEXTURES[classification]
end

local function SafeUnitClassificationNoPortraitTexture(unit, profile)
    local classification = SafeUnitClassification(unit)
    local style = profile and profile.classificationNoPortraitStyle or "nameplate"
    local textures = ns.CLASSIFICATION_NO_PORTRAIT_STYLES[style] or CLASSIFICATION_NO_PORTRAIT_TEXTURES
    return textures[classification]
end

local defaults = {
    profile = {
        enable = true,
        showCharacterLevel = true,
        showClassification = true,
        classificationNoPortraitStyle = "nameplate",
        classificationNoPortraitSize = 52,
        classificationNoPortraitAnchor = "TOPRIGHT",
        classificationNoPortraitX = -8,
        classificationNoPortraitY = 0,
        showPvPIcon = true,
        -- showPvPCircle is deliberately NOT defaulted here. Root cause of
        -- "circle still shows on kui": this blanket AceDB default ran via
        -- Compat.CopyDefaults inside BindDatabase(), called BEFORE
        -- KT:MigrateKuiPvPCircleDefault() in OnInitialize() -- by the time
        -- the migration checked `profile.showPvPCircle == nil` it was
        -- already backfilled to true, so the migration silently no-op'd
        -- and burned its one-shot guard flag forever. This field is
        -- theme-dependent (true for Classic/Forever/Retail, false for
        -- kui), unlike smoothBars below, so it must never get a single
        -- cross-theme default -- it's set explicitly per theme by
        -- Adapters/UnitFrames.lua's seed(), falls back to the live
        -- renderedTheme check at render time when nil, and existing kui
        -- profiles are repaired by the migration below.
        -- Smooth health/power bar value changes, on by default in every style.
        smoothBars = true,
        -- "none" | "elite" | "rare": custom rare/elite border on the Player portrait.
        playerClassificationBorder = "none",
        levelFont = "AAA_ITC_Avant_Garde",
        levelFontSize = 11,
        levelFontOutline = "OUTLINE",
        levelColor = { r = 1, g = 0.82, b = 0.20, a = 1 },
        levelX = 2,
        levelY = 2,
        levelAnchor = "AUTO",
        pvpAnchor = "AUTO",
        pvpX = 2,
        pvpY = 1,
        showPortrait = false,
        castbarOpacity = 1.0,
        castbarColor = nil,  -- Follows the active theme accent
        selectedFont = "AAA_ITC_Avant_Garde",
        use3DPortrait = false,
        portraitMode = "2d",
        portraitStyle = "circular",
        circularPortraitBorderUseCustomColor = true,
        circularPortraitBorderColor = nil,  -- Follows the active theme accent
        healthBarTexture = "Melli Reforged",
        healthBarOpacity = 90,
        powerBarOpacity = 100,
        darkTheme = false,
        frameArtKit = "default",  -- Set to "classic" by the VisualThemes classic theme
        -- NEW: separate player sub-table (migrated from shared playerTarget)
        player = {
            frameWidth = 230,
            frameScale = 100,
            healthHeight = 46,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            healthDisplay = "both",
            showBuffs = false,
            maxBuffs = 4,
            onlyPlayerDebuffs = true,
            maxDebuffs = 20,
            buffAnchor = "topleft",
            buffGrowth = "auto",
            debuffAnchor = "bottomleft",
            debuffGrowth = "auto",
            namePosition = "left",
            healthTextPosition = "right",
            leftTextContent = "name",
            rightTextContent = "both",
            leftTextSize = 14,
            leftTextX = 0,
            leftTextY = 0,
            rightTextSize = 14,
            rightTextX = 0,
            rightTextY = 0,
            leftTextClassColor = false,
            rightTextClassColor = false,
            centerTextContent = "none",
            centerTextSize = 14,
            centerTextX = 0,
            centerTextY = 0,
            centerTextClassColor = false,
            bottomTextBar = false,
            bottomTextBarHeight = 16,
            btbPosition = "bottom",
            btbWidth = 0,
            btbX = 0,
            btbY = 0,
            btbBgColor = { r = 0.2, g = 0.2, b = 0.2 },
            btbBgOpacity = 1.0,
            btbLeftContent = "none",
            btbLeftSize = 13,
            btbLeftX = 0,
            btbLeftY = 0,
            btbLeftClassColor = false,
            btbLeftPowerColor = false,
            btbRightContent = "none",
            btbRightSize = 13,
            btbRightX = 0,
            btbRightY = 0,
            btbRightClassColor = false,
            btbRightPowerColor = false,
            btbCenterContent = "none",
            btbCenterSize = 13,
            btbCenterX = 0,
            btbCenterY = 0,
            btbCenterClassColor = false,
            btbCenterPowerColor = false,
            btbClassIcon = "none",
            btbClassIconSize = 14,
            btbClassIconLocation = "left",
            btbClassIconX = 0,
            btbClassIconY = 0,
            showPortrait = false,
            portraitMode = "2d",
            classThemeStyle = "modern",
            portraitFacing = "flipped",
            portraitSide = "left",
            portraitSize = 0,
            portraitX = 0,
            portraitY = 0,
            detachedPortraitShape = "portrait",
            detachedPortraitBorderColor = { r = 0, g = 0, b = 0 },
            detachedPortraitClassColor = true,
            detachedPortraitBorder = true,
            detachedPortraitBorderOpacity = 100,
            detachedPortraitBorderSize = 7,
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = 100,
            showPlayerAbsorb = true,
            absorbBarTexture = "Melli Dark Rough",
            absorbBarColor = { r = 0.11, g = 1.00, b = 0.62, a = 1.00 },
            showPlayerCastbar = false,
            showPlayerCastIcon = true,
            castbarHideWhenInactive = true,
            lockCastbarToFrame = true,
            playerCastbarX = 0,
            playerCastbarY = 0,
            playerCastbarWidth = 0,
            playerCastbarHeight = 0,
            castSpellNameSize = 13,
            castSpellNameColor = { r = 1, g = 1, b = 1 },
            castDurationSize = 13,
            castDurationColor = { r = 1, g = 1, b = 1 },
            castbarFillColor = nil, -- Follows the active theme accent when no custom color is set
            castbarClassColored = true,
            showClassPowerBar = false,
            lockClassPowerToFrame = true,
            classPowerStyle = "none",
            classPowerPosition = "top",
            classPowerBarX = 0,
            classPowerBarY = 0,
            classPowerSize = 8,
            classPowerSpacing = 2,
            classPowerClassColor = true,
            classPowerCustomColor = { r = 1, g = 0.82, b = 0 },
            classPowerBgColor = { r = 0.082, g = 0.082, b = 0.082, a = 1.0 },
            classPowerEmptyColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            textSize = 14,
            combatIndicatorStyle = "standard",
            combatIndicatorColor = "custom",
            combatIndicatorCustomColor = { r = 1, g = 1, b = 1 },
            combatIndicatorPosition = "healthbar",
            combatIndicatorSize = 22,
            combatIndicatorX = 0,
            combatIndicatorY = 0,
            showRestingStatus = false,
            showInRaid = true,
            showInParty = true,
            showSolo = true,
        },
        -- NEW: separate target sub-table (migrated from shared playerTarget)
        target = {
            frameWidth = 230,
            frameScale = 100,
            healthHeight = 46,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            castbarHeight = 14,
            showCastbar = true,
            showCastIcon = true,
            castbarHideWhenInactive = true,
            castSpellNameSize = 13,
            castSpellNameColor = { r = 1, g = 1, b = 1 },
            castDurationSize = 13,
            castDurationColor = { r = 1, g = 1, b = 1 },
            castbarFillColor = { r = 1, g = 0.82, b = 0 },
            castbarClassColored = false,
            healthDisplay = "both",
            showBuffs = true,
            showDebuffs = true,
            onlyPlayerDebuffs = false,
            portraitFacing = "normal",
            buffAnchor = "topleft",
            buffGrowth = "auto",
            debuffAnchor = "bottomleft",
            debuffGrowth = "auto",
            maxBuffs = 20,
            maxDebuffs = 20,
            namePosition = "left",
            healthTextPosition = "right",
            leftTextContent = "name",
            rightTextContent = "both",
            leftTextSize = 14,
            leftTextX = 0,
            leftTextY = 0,
            rightTextSize = 14,
            rightTextX = 0,
            rightTextY = 0,
            leftTextClassColor = false,
            rightTextClassColor = false,
            centerTextContent = "none",
            centerTextSize = 14,
            centerTextX = 0,
            centerTextY = 0,
            centerTextClassColor = false,
            bottomTextBar = false,
            bottomTextBarHeight = 16,
            btbPosition = "bottom",
            btbWidth = 0,
            btbX = 0,
            btbY = 0,
            btbBgColor = { r = 0.2, g = 0.2, b = 0.2 },
            btbBgOpacity = 1.0,
            btbLeftContent = "none",
            btbLeftSize = 13,
            btbLeftX = 0,
            btbLeftY = 0,
            btbLeftClassColor = false,
            btbLeftPowerColor = false,
            btbRightContent = "none",
            btbRightSize = 13,
            btbRightX = 0,
            btbRightY = 0,
            btbRightClassColor = false,
            btbRightPowerColor = false,
            btbCenterContent = "none",
            btbCenterSize = 13,
            btbCenterX = 0,
            btbCenterY = 0,
            btbCenterClassColor = false,
            btbCenterPowerColor = false,
            btbClassIcon = "none",
            btbClassIconSize = 14,
            btbClassIconLocation = "left",
            btbClassIconX = 0,
            btbClassIconY = 0,
            showPortrait = false,
            portraitMode = "2d",
            classThemeStyle = "modern",
            portraitSide = "right",
            portraitSize = 0,
            portraitX = 0,
            portraitY = 0,
            detachedPortraitShape = "portrait",
            detachedPortraitBorderColor = { r = 0, g = 0, b = 0 },
            detachedPortraitClassColor = true,
            detachedPortraitBorder = true,
            detachedPortraitBorderOpacity = 100,
            detachedPortraitBorderSize = 7,
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = 100,
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            textSize = 14,
            showInRaid = true,
            showInParty = true,
            showSolo = true,
        },
        playerTarget = {
            frameWidth = 230,
            healthHeight = 46,
            powerHeight = 6,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            castbarHeight = 14,
            maxBuffs = 20,
            maxDebuffs = 20,
            healthDisplay = "both",
            showBuffs = true,
            onlyPlayerDebuffs = false,
            showPlayerAbsorb = true,
            showPlayerCastbar = false,
            showClassPowerBar = false,
            classPowerBarX = 0,
            classPowerBarY = 0,
            playerCastbarX = 0,
            playerCastbarY = 0,
            playerCastbarWidth = 0,
            playerCastbarHeight = 0,
        },
        totPet = {
            frameWidth = 101,
            healthHeight = 25,
            frameScale = 100,
            showPortrait = false,
            portraitMode = "2d",
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            textSize = 14,
            leftTextContent = "name",
            rightTextContent = "none",
            centerTextContent = "none",
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            powerPosition = "none",
        },
        pet = {
            frameWidth = 101,
            healthHeight = 25,
            frameScale = 100,
            showPortrait = false,
            portraitMode = "2d",
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            healthClassColored = true,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            textSize = 14,
            leftTextContent = "name",
            rightTextContent = "none",
            centerTextContent = "none",
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
        },
        focus = {
            frameWidth = 160,
            frameScale = 100,
            healthHeight = 34,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            castbarHeight = 14,
            showCastbar = true,
            showCastIcon = true,
            castbarHideWhenInactive = true,
            castSpellNameSize = 13,
            castSpellNameColor = { r = 1, g = 1, b = 1 },
            castDurationSize = 13,
            castDurationColor = { r = 1, g = 1, b = 1 },
            castbarFillColor = nil, -- Follows the active theme accent when no custom color is set
            castbarClassColored = false,
            healthDisplay = "perhp",
            leftTextContent = "name",
            rightTextContent = "perhp",
            leftTextSize = 14,
            leftTextX = 0,
            leftTextY = 0,
            rightTextSize = 14,
            rightTextX = 0,
            rightTextY = 0,
            leftTextClassColor = false,
            rightTextClassColor = false,
            centerTextContent = "none",
            centerTextSize = 14,
            centerTextX = 0,
            centerTextY = 0,
            centerTextClassColor = false,
            bottomTextBar = false,
            bottomTextBarHeight = 16,
            btbPosition = "bottom",
            btbWidth = 0,
            btbX = 0,
            btbY = 0,
            btbLeftContent = "none",
            btbLeftSize = 13,
            btbLeftX = 0,
            btbLeftY = 0,
            btbLeftClassColor = false,
            btbLeftPowerColor = false,
            btbRightContent = "none",
            btbRightSize = 13,
            btbRightX = 0,
            btbRightY = 0,
            btbRightClassColor = false,
            btbRightPowerColor = false,
            btbCenterContent = "none",
            btbCenterSize = 13,
            btbCenterX = 0,
            btbCenterY = 0,
            btbCenterClassColor = false,
            btbCenterPowerColor = false,
            btbClassIcon = "none",
            btbClassIconSize = 14,
            btbClassIconLocation = "left",
            btbClassIconX = 0,
            btbClassIconY = 0,
      showPortrait = false,
            portraitMode = "2d",
            classThemeStyle = "modern",
            portraitSide = "right",
            portraitSize = 0,
            portraitX = 0,
            portraitY = 0,
            detachedPortraitShape = "portrait",
            detachedPortraitBorderColor = { r = 0, g = 0, b = 0 },
            detachedPortraitClassColor = true,
            detachedPortraitBorder = true,
            detachedPortraitBorderOpacity = 100,
            detachedPortraitBorderSize = 7,
            btbBgColor = { r = 0.2, g = 0.2, b = 0.2 },
            btbBgOpacity = 1.0,
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = 100,
            onlyPlayerDebuffs = true,
            debuffAnchor = "bottomleft",
            debuffGrowth = "auto",
            maxDebuffs = 10,
            textSize = 14,
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
            showInRaid = true,
            showInParty = true,
            showSolo = true,
        },
        boss = {
            frameWidth = 160,
            frameScale = 100,
            healthHeight = 34,
            powerHeight = 6,
            powerPosition = "below",
            powerWidth = 0,
            powerX = 0,
            powerY = -4,
            powerPercentText = "none",
            powerTextFormat = "perpp",
            powerShowPercent = true,
            powerPercentSize = 11,
            powerPercentX = 0,
            powerPercentY = 0,
            powerPercentPowerColor = true,
            powerPercentTextPowerColor = false,
            healthClassColored = true,
            castbarHeight = 14,
            healthDisplay = "perhp",
            showPortrait = false,
            portraitMode = "2d",
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = 100,
            textSize = 14,
            leftTextContent = "name",
            rightTextContent = "perhp",
            centerTextContent = "none",
            borderSize = 1,
            borderColor = { r = 0, g = 0, b = 0 },
            highlightColor = { r = 1, g = 1, b = 1 },
        },
        enabledFrames = {
            player = true,
            target = true,
            focus = true,
            pet = true,
            targettarget = true,
            focustarget = false,
            boss = true,
        },
        positions = {
            player = { point = "CENTER", x = -300, y = -145 },
            target = { point = "CENTER", x = 280, y = -145 },
            focus = { point = "TOPLEFT", x = 952.8616333007812, y = -1066.000396728516 },
            pet = { point = "TOPLEFT", x = 953.8617553710938, y = -869.2078247070312 },
            targettarget = { point = "TOPLEFT", x = 1521.352294921875, y = -844.6795654296875 },
            focustarget = { point = "TOPLEFT", x = 952.7691650390625, y = -1124.056945800781 },
            boss = { point = "RIGHT", x = -326, y = 251 },
            playerCastbar = { point = "CENTER", x = 0, y = -250 },
            classPower = { point = "CENTER", x = 0, y = -220 },
        },
        bossSpacing = 60,
    }
}
local frames = {}

local function UnitFrameStrataObjectBlocked(frame)
    if not frame then
        return true
    end

    local ok, blocked = pcall(function()
        if type(frame.IsForbidden) == "function" and frame:IsForbidden() then
            return true
        end
        if type(frame.IsProtected) == "function" and frame:IsProtected() then
            return true
        end
        return false
    end)

    return not ok or blocked == true
end

-- Indicator overlays (level, PvP, combo ring...) stay in the unit frame's
-- LOW strata and sit above the portrait by frame level, so the world map and
-- other windows still cover them.
function ns.ApplyOverlayStrata(overlay, owner)
    if not (overlay and overlay.SetFrameStrata) then return end
    owner = owner or overlay:GetParent()
    local bd = owner and owner.Portrait and owner.Portrait.backdrop
    local function Apply(f, depth)
        pcall(f.SetFrameStrata, f, "LOW")
        if depth < 4 and f.GetChildren then
            for _, child in ipairs({ f:GetChildren() }) do Apply(child, depth + 1) end
        end
    end
    Apply(overlay, 0)
    local floor = ((bd and bd.GetFrameLevel and bd:GetFrameLevel()) or 0) + 10
    if (overlay:GetFrameLevel() or 0) < floor then pcall(overlay.SetFrameLevel, overlay, floor) end
end

local function SetUnitFrameTreeStrata(frame, seen)
    local frameType = type(frame)
    if (frameType ~= "table" and frameType ~= "userdata")
        or type(frame.SetFrameStrata) ~= "function" then
        return
    end

    seen = seen or {}
    if seen[frame] then return end
    seen[frame] = true

    -- Blizzard/secure descendants can become forbidden after another addon
    -- taints their frame tree. Never call protected methods on those objects.
    if UnitFrameStrataObjectBlocked(frame) then
        return
    end

    -- Portrait backdrops keep their own level; metadata overlays stay above them.
    if frame._isPortraitBackdrop then
        return
    end
    if frame._kuiAbovePortraitOverlay then
        ns.ApplyOverlayStrata(frame)
        return
    end

    local ok = pcall(frame.SetFrameStrata, frame, "LOW")
    if not ok then
        return
    end

    if type(frame.GetChildren) == "function" then
        local childrenOK, children = pcall(function()
            return { frame:GetChildren() }
        end)
        if childrenOK and children then
            for _, child in ipairs(children) do
                SetUnitFrameTreeStrata(child, seen)
            end
        end
    end
end
local function RefreshUnitFrameStrata()
    local seen = {}
    for key, frame in pairs(frames) do
        local frameType = type(frame)
        if type(key) == "string"
            and (frameType == "table" or frameType == "userdata")
            and type(frame.SetFrameStrata) == "function"
        then
            SetUnitFrameTreeStrata(frame, seen)
        end
    end
end

Compat.fontPaths = Compat.fontPaths or {
    ["AAA_ITC_Avant_Garde"] = KT.FONT_PATH,
    ["Avant Garde"] = KT.FONT_PATH,
    ["Expressway"] = KT.FONT_PATH,
    ["Aldo PC"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Aldo PC.ttf",
    ["Capture it"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Captureit.ttf",
    ["Duepuntozero"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\duepuntozero.ttf",
    ["Emblem"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Emblem.ttf",
    ["PF Ronda Seven"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\pf_ronda_seven.ttf",
    ["PF Ronda Seven Bold"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\pf_ronda_seven_bold.ttf",
    ["Planet Kosmos"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\PLANE___.TTF",
    ["SF New Republic"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\SF New Republic.ttf",
    ["Swansea Bold"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\SWANSE_B.TTF",
    ["Swansea"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\SWANSE__.TTF",
    ["Tempesta Seven"] = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\Tempesta Seven Condensed.ttf",
}

Compat.LOCALE_FONT_FALLBACK = Compat.LOCALE_FONT_FALLBACK
    or ((GetLocale() == "koKR" or GetLocale() == "zhCN" or GetLocale() == "zhTW" or GetLocale() == "ruRU") and STANDARD_TEXT_FONT)
    or nil

if not Compat.GetFontPath then
    function Compat.GetFontPath(unitKey)
        local settings = db and db.profile and unitKey and db.profile[unitKey]
        local name = settings and settings.selectedFont
        local path = Compat.fontPaths[name]
        if not path and name then
            local LSM = LibStub("LibSharedMedia-3.0", true)
            path = LSM and LSM:Fetch("font", name, true)
        end
        return path or KT.FONT_PATH
    end
end

if not Compat.GetFontOutlineFlag then
    function Compat.GetFontOutlineFlag()
        return "OUTLINE"
    end
end

if not Compat.GetFontUseShadow then
    function Compat.GetFontUseShadow()
        return false
    end
end

if not PP.Scale then
    function PP.Scale(value)
        local scale = UIParent and UIParent:GetEffectiveScale() or 1
        return math.floor((value or 0) * scale + 0.5) / scale
    end

    function PP.Point(frame, point, relativeTo, relativePoint, x, y)
        frame:SetPoint(point, relativeTo, relativePoint, PP.Scale(x or 0), PP.Scale(y or 0))
    end

    function PP.Size(frame, width, height)
        frame:SetSize(PP.Scale(width or 0), PP.Scale(height or 0))
    end

    function PP.Width(frame, width)
        frame:SetWidth(PP.Scale(width or 0))
    end

    function PP.Height(frame, height)
        frame:SetHeight(PP.Scale(height or 0))
    end

    function PP.DisablePixelSnap(tex)
        if tex and tex.SetSnapToPixelGrid then
            tex:SetSnapToPixelGrid(false)
            tex:SetTexelSnappingBias(0)
        end
    end

    function PP.CreateBorder(frame, r, g, b, a, size, layer, sublevel)
        size = math.max(1, math.floor(size or 1))
        layer = layer or "OVERLAY"
        sublevel = sublevel or 0
        frame._ppBorders = frame._ppBorders or {}
        frame._ppBorderSize = size
        frame._ppBorderColor = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }

        if #frame._ppBorders == 0 then
            for i = 1, 4 do
                frame._ppBorders[i] = frame:CreateTexture(nil, layer, nil, sublevel)
            end
        end

        local edges = frame._ppBorders
        edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size)
        edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", size, size)
        edges[1]:SetHeight(size)

        edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -size, -size)
        edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
        edges[2]:SetHeight(size)

        edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size)
        edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -size, -size)
        edges[3]:SetWidth(size)

        edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", size, size)
        edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
        edges[4]:SetWidth(size)

        for i = 1, 4 do
            edges[i]:SetColorTexture(frame._ppBorderColor.r, frame._ppBorderColor.g, frame._ppBorderColor.b, frame._ppBorderColor.a)
            edges[i]:Show()
        end
        if frame._ppHideEdge and edges[frame._ppHideEdge] then edges[frame._ppHideEdge]:Hide() end
    end

    -- Hides one side edge (3 = left, 4 = right) so the frame border does not cut
    -- across a circular portrait that overlaps it. The choice survives border
    -- refreshes until it is cleared.
    function PP.SetHiddenEdge(frame, edge)
        if not (frame and frame._ppBorders) then return end
        frame._ppHideEdge = edge
        for i = 3, 4 do
            if frame._ppBorders[i] then frame._ppBorders[i]:SetShown(i ~= edge) end
        end
    end

    function PP.SetBorderSize(frame, size)
        if frame and frame._ppBorderColor then
            PP.CreateBorder(frame, frame._ppBorderColor.r, frame._ppBorderColor.g, frame._ppBorderColor.b, frame._ppBorderColor.a, size)
        end
    end

    function PP.SetBorderColor(frame, r, g, b, a)
        if frame and frame._ppBorders then
            frame._ppBorderColor = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }
            for i = 1, #frame._ppBorders do
                frame._ppBorders[i]:SetColorTexture(frame._ppBorderColor.r, frame._ppBorderColor.g, frame._ppBorderColor.b, frame._ppBorderColor.a)
            end
        end
    end

    function PP.UpdateBorder(frame, size, r, g, b, a)
        PP.CreateBorder(frame, r, g, b, a, size)
    end
end

if not Compat.AppendSharedMediaTextures then
    function Compat.AppendSharedMediaTextures(textureNames, textureOrder, _, textureMap)
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if not LSM then return end
        local list = LSM:List("statusbar")
        if not list then return end
        for i = 1, #list do
            local name = list[i]
            if not textureMap[name] then
                textureMap[name] = LSM:Fetch("statusbar", name)
                textureNames[name] = name
                textureOrder[#textureOrder + 1] = name
            end
        end
    end
end

if not Compat.ApplyColorsToOUF then
    function Compat.ApplyColorsToOUF()
        if oUF and oUF.colors and CUSTOM_CLASS_COLORS then
            oUF.colors.class = CUSTOM_CLASS_COLORS
        end
    end
end

Compat.resourceState = Compat.resourceState or { maelstrom = 0, maelstromMax = 10, tip = 0, tipMax = 3, whirlwind = 0, whirlwindMax = 4 }

if not Compat.CopyDefaults then
    function Compat.CopyDefaults(dst, src)
        if type(dst) ~= "table" or type(src) ~= "table" then return dst end
        for key, value in pairs(src) do
            if dst[key] == nil then
                if type(value) == "table" then
                    dst[key] = {}
                    Compat.CopyDefaults(dst[key], value)
                else
                    dst[key] = value
                end
            elseif type(dst[key]) == "table" and type(value) == "table" then
                Compat.CopyDefaults(dst[key], value)
            end
        end
        return dst
    end
end

if not Compat.GetMaelstromWeapon then
    function Compat.GetMaelstromWeapon()
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(344179)
        local aura = name and AuraUtil and AuraUtil.FindAuraByName(name, "player", "HELPFUL")
        Compat.resourceState.maelstrom = aura and (aura.applications or aura.charges or 0) or 0
        return Compat.resourceState.maelstrom, Compat.resourceState.maelstromMax
    end
end

if not Compat.GetTipOfTheSpear then
    function Compat.GetTipOfTheSpear()
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(260286)
        local aura = name and AuraUtil and AuraUtil.FindAuraByName(name, "player", "HELPFUL")
        Compat.resourceState.tip = aura and (aura.applications or aura.charges or 0) or Compat.resourceState.tip or 0
        return Compat.resourceState.tip, Compat.resourceState.tipMax
    end
end

if not Compat.GetWhirlwindStacks then
    function Compat.GetWhirlwindStacks()
        return Compat.resourceState.whirlwind or 0, Compat.resourceState.whirlwindMax
    end
end

if not Compat.HandleTipOfTheSpear then
    function Compat.HandleTipOfTheSpear(event)
        if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
            Compat.resourceState.tip = 0
        else
            Compat.GetTipOfTheSpear()
        end
    end
end

if not Compat.HandleWhirlwindStacks then
    function Compat.HandleWhirlwindStacks(event, unit, _, spellID)
        if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_REGEN_ENABLED" then
            Compat.resourceState.whirlwind = 0
            return
        end
        if unit ~= "player" then return end
        if spellID == 1680 then
            Compat.resourceState.whirlwind = Compat.resourceState.whirlwindMax
        elseif Compat.resourceState.whirlwind and Compat.resourceState.whirlwind > 0 then
            Compat.resourceState.whirlwind = Compat.resourceState.whirlwind - 1
        end
    end
end

local function GetThemeAccentColor()
    -- Forever has a fixed "chrome" identity (bronze), same as the Damage
    -- Meter's own header/border accent (ThemeEngine.lua's
    -- DAMAGE_METER_CHROME_COLORS): UnitFrames match that bronze, not
    -- whatever the user's own configurable skin.accentColor happens to be
    -- (default red), the same way Classic/Retail already get a fixed gold
    -- identity there.
    if KT.VisualThemes and KT.VisualThemes.GetRenderedTheme and KT.VisualThemes.GetDamageMeterAccentColor
        and KT.VisualThemes:GetRenderedTheme() == "forever" then
        local r, g, b = KT.VisualThemes:GetDamageMeterAccentColor()
        if r and g and b then
            return { r = r, g = g, b = b, a = 1 }
        end
    end

    if KT and KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        if r and g and b then
            return { r = r, g = g, b = b, a = 1 }
        end
    end

    local palette = KT and KT.GetStylePalette and KT:GetStylePalette()
    local accent = palette and palette.accent
    if accent then
        return {
            r = accent.r or 1,
            g = accent.g or 0,
            b = accent.b or 0.333,
            a = accent.a or 1,
        }
    end

    return { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.333, a = 1 }
end

local function GetCastbarColor()
    if db and db.profile and db.profile.castbarColor then
        return db.profile.castbarColor
    end
    return GetThemeAccentColor()
end
local MANA_COLOR = { r = 0.204, g = 0.349, b = 0.851 }

local function ResolveSafeClassToken(unit)
    local _, classToken
    if KT.SafeUnitClass then
        _, classToken = KT.SafeUnitClass(unit)
    else
        _, classToken = UnitClass(unit)
    end
    if classToken and KT.IsSecret and KT.IsSecret(classToken) then
        return nil
    end
    return classToken
end

local function ResolveCastbarFillColor(unit, settings)
    local fallback = GetCastbarColor()

    if settings and settings.castbarClassColored and unit and UnitExists(unit) then
        local classToken = ResolveSafeClassToken(unit)
        if classToken and RAID_CLASS_COLORS[classToken] then
            return RAID_CLASS_COLORS[classToken]
        end
    end

    if settings and settings.castbarFillColor then
        return settings.castbarFillColor
    end

    return fallback
end

local SOLID_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8" }

-- â”€â”€â”€ Subsistema de resoluciÃ³n de fuentes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Gestiona la ruta de fuente global y per-unit con invalidaciÃ³n.
-- LOCALE_FONT_OVERRIDE fuerza una fuente del sistema para CJK/Cyrillic.
-- Resolve() regenera la cachÃ©; Get() la consume sin recalcular.
local LOCALE_FONT_OVERRIDE = Compat and Compat.LOCALE_FONT_FALLBACK
local DEFAULT_FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local FONT_UNIT_KEYS = { "player", "target", "focus", "boss", "pet", "totPet" }

local fontCache = {
    global = LOCALE_FONT_OVERRIDE
        or (Compat and Compat.GetFontPath and Compat.GetFontPath("unitFrames"))
        or DEFAULT_FONT,
    perUnit = {},
}

local function ResolveFontPath()
    -- Locale override tiene prioridad absoluta: no hay fuente custom que
    -- renderice CJK/Cyrillic correctamente.
    local base = LOCALE_FONT_OVERRIDE
        or (Compat and Compat.GetFontPath and Compat.GetFontPath("player"))
        or DEFAULT_FONT
    fontCache.global = base
    for _, uKey in ipairs(FONT_UNIT_KEYS) do
        fontCache.perUnit[uKey] = LOCALE_FONT_OVERRIDE
            or (Compat and Compat.GetFontPath and Compat.GetFontPath(uKey))
            or base
    end
end

local function GetSelectedFont(unitKey)
    return (unitKey and fontCache.perUnit[unitKey]) or fontCache.global
end

local function GetUFUseShadow()
    return not Compat or not Compat.GetFontUseShadow or Compat.GetFontUseShadow()
end

local function SetFSFont(fs, size, flags)
  if not (fs and fs.SetFont) then return end
  if fs._ktBlizzBar and ns.UsesModernNumbers and ns.UsesModernNumbers() then
      local style = fs._ktBlizzBar
      fs:SetFont(style.path, style.size, style.flags)
      return
  end
  local f = flags or (Compat and Compat.GetFontOutlineFlag and Compat.GetFontOutlineFlag()) or ""
  local fontPath = GetSelectedFont()
  fs:SetFont(fontPath, size or 12, f)
  if KT and KT.EnableTextFontFallback then
    KT:EnableTextFontFallback(fs, fontPath)
  end
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.9)
end

-- Disable WoW's automatic pixel snapping on a texture (prevents sub-pixel jitter)
local function ApplyForeverLevelTextStyle(text, profile, frame)
    if not (text and text.SetFont) then return end
    profile = profile or {}
    local fontName = profile.levelFont or "AAA_ITC_Avant_Garde"
    local fontPath = Compat.fontPaths and Compat.fontPaths[fontName]
    if not fontPath then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        fontPath = LSM and LSM:Fetch("font", fontName, true)
    end
    fontPath = fontPath or DEFAULT_FONT
    local size = math.max(6, math.min(48, tonumber(profile.levelFontSize) or 11))
    local outline = profile.levelFontOutline
    if outline == "NONE" then outline = "" end
    if type(outline) ~= "string" then outline = "OUTLINE" end
    text:SetFont(fontPath, size, outline)
    if KT and KT.EnableTextFontFallback then
        KT:EnableTextFontFallback(text, fontPath)
    end
    local color = profile.levelColor or { r = 1, g = 0.82, b = 0.20, a = 1 }
    text:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    if frame then
        text:ClearAllPoints()
        local anchor = profile.levelAnchor
        if OVERLAY_ANCHORS[anchor] then
            text:SetPoint(anchor, frame, anchor,
                tonumber(profile.levelX) or 2, tonumber(profile.levelY) or 2)
        else
            text:SetPoint("BOTTOMLEFT", frame, "TOPLEFT",
                tonumber(profile.levelX) or 2, tonumber(profile.levelY) or 2)
        end
    end
end

local function UnsnapTex(tex)
    local PP = Compat and Compat.PP
    if PP then PP.DisablePixelSnap(tex)
    elseif tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0) end
end

-- Health bar texture overlay lookup
local TEXTURE_BASE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\textures\\"
local healthBarTextures = {
    ["none"]          = nil,
    ["Melli Reforged"] = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga",
    ["Melli"]         = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga",
    ["Melli Dark"]    = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
    ["Melli Dark Rough"] = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
    ["beautiful"]     = TEXTURE_BASE .. "beautiful.tga",
    ["plating"]       = TEXTURE_BASE .. "plating.tga",
    ["atrocity"]      = TEXTURE_BASE .. "atrocity.tga",
    ["divide"]        = TEXTURE_BASE .. "divide.tga",
    ["glass"]         = TEXTURE_BASE .. "glass.tga",
    ["gradient-lr"]   = TEXTURE_BASE .. "gradient-lr.tga",
    ["gradient-rl"]   = TEXTURE_BASE .. "gradient-rl.tga",
    ["gradient-bt"]   = TEXTURE_BASE .. "gradient-bt.tga",
    ["gradient-tb"]   = TEXTURE_BASE .. "gradient-tb.tga",
    ["matte"]         = TEXTURE_BASE .. "matte.tga",
    ["sheer"]         = TEXTURE_BASE .. "sheer.tga",
}
local healthBarTextureOrder = {
    "none", "Melli Reforged", "Melli", "Melli Dark", "Melli Dark Rough", "beautiful", "plating",
    "atrocity", "divide", "glass",
    "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
    "matte", "sheer",
}
local healthBarTextureNames = {
    ["none"]        = "None",
    ["Melli Reforged"] = "Melli Reforged",
    ["Melli"]       = "Melli",
    ["Melli Dark"]  = "Melli Dark",
    ["Melli Dark Rough"] = "Melli Dark Rough",
    ["beautiful"]   = "Beautiful",
    ["plating"]     = "Plating",
    ["atrocity"]    = "Atrocity",
    ["divide"]      = "Divide",
    ["glass"]       = "Glass",
    ["gradient-lr"] = "Gradient Right",
    ["gradient-rl"] = "Gradient Left",
    ["gradient-bt"] = "Gradient Up",
    ["gradient-tb"] = "Gradient Down",
    ["matte"]       = "Matte",
    ["sheer"]       = "Sheer",
}
ns.healthBarTextures = healthBarTextures
ns.healthBarTextureOrder = healthBarTextureOrder
ns.healthBarTextureNames = healthBarTextureNames

local DEFAULT_ABSORB_TEXTURE = "Melli Dark Rough"
local DEFAULT_ABSORB_COLOR = { r = 0.11, g = 1.00, b = 0.62, a = 1.00 }

local function ResolveSharedTexturePath(textureKey, fallbackKey)
    if textureKey == "none" then
        return nil
    end
    local path = healthBarTextures[textureKey]
    if path then
        return path
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    path = LSM and LSM:Fetch("statusbar", textureKey, true)
    if path then
        healthBarTextures[textureKey] = path
        return path
    end
    return healthBarTextures[fallbackKey]
end

local function ResolveAbsorbBarColor(settings)
    local color = settings and settings.absorbBarColor
    return
        (color and (color.r or color[1])) or DEFAULT_ABSORB_COLOR.r,
        (color and (color.g or color[2])) or DEFAULT_ABSORB_COLOR.g,
        (color and (color.b or color[3])) or DEFAULT_ABSORB_COLOR.b,
        (color and (color.a or color[4])) or DEFAULT_ABSORB_COLOR.a
end

local function ResolvePortraitClassToken(unit)
    local classToken = ResolveSafeClassToken(unit)
    if classToken then
        return classToken
    end
    return nil
end

function ns.EnableTarget3D(profile)
    if not profile or profile._ktTarget3DInitialized then return end
    if profile.player and profile.player.portraitMode == "3d" and profile.target
        and profile.target.portraitMode == "2d" then
        profile.target.portraitMode = "3d"
        profile._ktTarget3DInitialized = true
    end
end

local function ResolveActivePortraitMode(unit, settings)
    local mode = (settings and settings.portraitMode) or (db and db.profile and db.profile.portraitMode) or "2d"
    if mode == "class" and not ResolvePortraitClassToken(unit) then
        -- Pets and non-player units do not always expose a class token.
        -- Fall back to the regular portrait so the slot never renders blank.
        return "2d"
    end
    return mode
end

-- â”€â”€â”€ Subsistema de contexto de unidad â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Centraliza la resoluciÃ³n unitID â†’ clave de perfil â†’ tabla de settings.
-- Arquitectura: mapa estÃ¡tico pre-poblado en lugar de pattern matching o
-- lazy-init separados.  Cache invalidable desde ReloadFrames.
ns._UnitCtx = ns._UnitCtx or {}
local UCtx = ns._UnitCtx

-- Claves fijas: unidades especiales que no coinciden con su nombre en db.profile
local UNIT_KEY_FIXED = {
    targettarget = "totPet",
    focustarget  = "totPet",
    pet          = "pet",
}
for i = 1, 5 do UNIT_KEY_FIXED["boss" .. i] = "boss" end

-- Unidades con clave idÃ©ntica a su unitID en db.profile
local UNIT_KEY_IDENTITY = { player = true, target = true, focus = true }

-- ResoluciÃ³n de clave: determinÃ­stico por tabla, sin regex
function UCtx.ResolveKey(unit)
    if not unit then return nil end
    local fk = UNIT_KEY_FIXED[unit]
    if fk then return fk end
    if UNIT_KEY_IDENTITY[unit] and db.profile[unit] then return unit end
    if db.profile[unit] then return unit end
    return nil
end

-- Cache de settings: se puebla en primer acceso, se invalida con Invalidate()
local _settingsCache
function UCtx.ResolveSettings(unit)
    if not _settingsCache then
        _settingsCache = {}
        for uid, key in pairs(UNIT_KEY_FIXED) do
            _settingsCache[uid] = db.profile[key]
        end
        for uid in pairs(UNIT_KEY_IDENTITY) do
            if db.profile[uid] then
                _settingsCache[uid] = db.profile[uid]
            end
        end
    end
    return _settingsCache[unit] or db.profile.player
end

-- Donante para mini frames: cascada focus â†’ target â†’ player
function UCtx.ResolveMiniDonor()
    local ef = db.profile.enabledFrames
    if ef.focus ~= false and db.profile.focus then return db.profile.focus end
    if ef.target ~= false and db.profile.target then return db.profile.target end
    return db.profile.player
end

function UCtx.Invalidate()
    _settingsCache = nil
end

-- Aliases compatibles: mantienen la firma original para todos los call sites
local function UnitToSettingsKey(unit) return UCtx.ResolveKey(unit) end
local function GetSettingsForUnit(unit) return UCtx.ResolveSettings(unit) end
local function GetMiniDonorSettings() return UCtx.ResolveMiniDonor() end

-- Forever/Retail: use Blizzard's own pre-coloured bar atlases as the fill of the
-- Player/Target health and power bars (Blizzard client atlases
-- are used). Only when the user kept the default texture AND the default health
-- colour; every atlas is validated with GetAtlasInfo and falls back to the flat fill.
-- The atlas is already coloured, so the bar's vertex colour is forced back to white.
ns.AtlasFill = {}
ns.AtlasFill.POWER = {
    MANA = "Mana", RAGE = "Rage", FOCUS = "Focus", ENERGY = "Energy",
    RUNIC_POWER = "RunicPower", LUNAR_POWER = "AstralPower", MAELSTROM = "Maelstrom",
    INSANITY = "Insanity", FURY = "Fury", PAIN = "Pain",
}
function ns.AtlasFill.Exists(name)
    return name and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) and true or false
end
function ns.AtlasFill.SeatMask(bar)
    local m, fill = bar._ktForeverMask, bar:GetStatusBarTexture()
    if m and m.IsShown and not m:IsShown() then return end   -- mask deliberately dropped (Rare/Elite power bar)
    if m and fill and fill.AddMaskTexture then
        pcall(fill.RemoveMaskTexture, fill, m)
        pcall(fill.AddMaskTexture, fill, m)
    end
end
function ns.AtlasFill.KeepWhite(bar)
    if bar._kuiWhiteHook then return end
    bar._kuiWhiteHook = true
    hooksecurefunc(bar, "SetStatusBarColor", function(self)
        if self._kuiAtlasFill then
            local f = self:GetStatusBarTexture()
            if f then f:SetVertexColor(1, 1, 1, 1) end
        end
    end)
end
-- Theme default greens (Classic 0.10/0.90/0.10, Forever/Retail 0.57/1/0.235): only these are
-- "the theme default", a colour the user picked is never overridden.
function ns.AtlasFill.IsDefaultGreen(c)
    if type(c) ~= "table" or type(c.r) ~= "number" then return false end
    local function near(a, b) return math.abs(a - b) < 0.02 end
    return (near(c.r, 0.57) and near(c.g, 1.0) and near(c.b, 0.235))
        or (near(c.r, 0.10) and near(c.g, 0.90) and near(c.b, 0.10))
end
-- Hostile units must not wear the friendly green: class colour for enemy players, reaction
-- colour (tapped = grey) for NPCs.
function ns.AtlasFill.EnemyColor(unit)
    if not unit or not UnitExists(unit) then return end
    local ok, can = pcall(UnitCanAttack, "player", unit)
    if not ok or (issecretvalue and issecretvalue(can)) or not can then return end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if okP and isPlayer and not (issecretvalue and issecretvalue(isPlayer)) then
        local _, cls = UnitClass(unit)
        if cls and not (issecretvalue and issecretvalue(cls)) then
            local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[cls]
            if c then return c.r, c.g, c.b end
        end
        return
    end
    if UnitIsTapDenied and UnitIsTapDenied(unit) then return 0.6, 0.6, 0.6 end
    local reaction = UnitReaction(unit, "player")
    if reaction and not (issecretvalue and issecretvalue(reaction)) then
        local c = FACTION_BAR_COLORS[reaction]
        if c then return c.r, c.g, c.b end
    end
end
function ns.AtlasFill.Apply(health, power, unitKey, settings)
    local AtlasExists, SeatForeverMask, KeepWhite, POWER_ATLAS_SUFFIX = ns.AtlasFill.Exists, ns.AtlasFill.SeatMask, ns.AtlasFill.KeepWhite, ns.AtlasFill.POWER
    local side = (unitKey == "target") and "Target" or "Player"
    local c = settings and settings.customFillColor
    local defaultColor = settings and settings.healthClassColored == false and type(c) == "table"
        and math.abs((c.r or 0) - 0.57) < 0.02 and math.abs((c.g or 0) - 1.0) < 0.02
        and math.abs((c.b or 0) - 0.235) < 0.02
    local hAtlas = "UI-HUD-UnitFrame-" .. side .. "-PortraitOn-Bar-Health"
    if health then
        if defaultColor and not health._kuiEnemyTint and AtlasExists(hAtlas) then
            health:SetStatusBarTexture(hAtlas)
            health._kuiAtlasFill = true
            KeepWhite(health)
            SeatForeverMask(health)
            local f = health:GetStatusBarTexture()
            if f then f:SetVertexColor(1, 1, 1, 1) end
        else
            health._kuiAtlasFill = nil
        end
    end
    -- Power uses the configured shared status-bar texture and oUF's resource
    -- tint. Decorative pre-coloured atlases must not force this bar white or
    -- freeze its texture to the resource of a previously selected target.
    if power then power._kuiAtlasFill = nil end
end

local function ApplyHealthBarTexture(health, unitKey)
    if not health then return end
    local s = unitKey and db.profile[unitKey]
    local texKey = (s and s.healthBarTexture) or db.profile.healthBarTexture or "none"
    local path   = ResolveSharedTexturePath(texKey, "Melli Reforged")
    local bgPath = healthBarTextures["Melli Dark"]

    -- Forever/Retail: Blizzard's bars are a flat colour with a glossy tube
    -- highlight (KUI_BarGloss), not the patterned default LSM texture. Only
    -- when the user kept the default texture.
    if (unitKey == "player" or unitKey == "target")
        and (texKey == "Melli Reforged" or texKey == "none")
        and ns.BarGloss and ns.BarGloss.IsBlizzardStyle and ns.BarGloss.IsBlizzardStyle() then
        path = nil
    end

    -- Apply texture directly to the StatusBar fill
    if path then
        health:SetStatusBarTexture(path)
    else
        health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    end
    local hFill = health:GetStatusBarTexture()
    if hFill then UnsnapTex(hFill) end
    if health.bg and bgPath then
        health.bg:SetTexture(bgPath)
        health.bg:SetVertexColor(1, 1, 1, 1)
    end

    -- Power bar: same texture
    local frame = health:GetParent()
    local power = frame and frame.Power
    if power then
        if path then
            power:SetStatusBarTexture(path)
        else
            power:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        end
        local pFill = power:GetStatusBarTexture()
        if pFill then UnsnapTex(pFill) end
        -- Texture refreshes must preserve the dark background and the
        -- no-resource state; the health background's pale texture is not
        -- suitable for the empty resource track.
        ns.UpdatePowerBackground(power, frame.unit or unitKey, s)
    end

    if (unitKey == "player" or unitKey == "target")
        and (texKey == "Melli Reforged" or texKey == "none")
        and ns.BarGloss and ns.BarGloss.IsBlizzardStyle and ns.BarGloss.IsBlizzardStyle() then
        pcall(ns.AtlasFill.Apply, health, power, unitKey, s)
    else
        health._kuiAtlasFill = nil
        if power then power._kuiAtlasFill = nil end
    end
end

-------------------------------------------------------------------------------
--  Bar Fill Opacity â€” aplica alfa al fill y background de una StatusBar.
--  Unifica la lÃ³gica idÃ©ntica de health y power en un solo aplicador
--  parametrizado por clave de opacidad.
-------------------------------------------------------------------------------
local function ApplyBarFillAlpha(bar, unitKey, opacityKey, defaultVal)
    if not bar then return end
    local s = unitKey and db.profile[unitKey]
    local opacity = s and (s[opacityKey] or defaultVal) or defaultVal
    -- Retrocompatibilidad: perfiles antiguos guardaban 0-1 float en vez de 0-100
    if opacity <= 1.0 then opacity = opacity * 100 end
    local fillA = opacity / 100
    local fillTex = bar:GetStatusBarTexture()
    if fillTex then fillTex:SetAlpha(fillA) end
    if bar.bg then bar.bg:SetAlpha(fillA) end
end

-- Wrappers con firma legada para mantener las call-sites existentes
local function ApplyHealthBarAlpha(health, unitKey)
    ApplyBarFillAlpha(health, unitKey, "healthBarOpacity", 90)
end
local function ApplyPowerBarAlpha(power, unitKey)
    local owner = power and power.GetParent and power:GetParent()
    ns.UpdatePowerBackground(power, owner and owner.unit or unitKey,
        unitKey and db.profile[unitKey])
end

-------------------------------------------------------------------------------
--  Dark Mode ? flat dark health bar with gray background
-------------------------------------------------------------------------------
local DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B = 0x11/255, 0x11/255, 0x11/255  -- #111111
local DARK_HEALTH_A = 1.0
local DARK_BG_R, DARK_BG_G, DARK_BG_B = 0x4f/255, 0x4f/255, 0x4f/255  -- #4f4f4f

local function ApplyDarkTheme(health)
    if not health then return end
    local isDark = db and db.profile and db.profile.darkTheme
    if isDark then
        health.colorClass = false
        health.colorReaction = false
        health.colorTapped = false
        health.colorDisconnected = false
        health:SetStatusBarColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, DARK_HEALTH_A)
        local darkFillTex = health:GetStatusBarTexture()
        if darkFillTex then darkFillTex:SetAlpha(0.9) end
        if health.bg then
            -- Anchor bg to only cover the empty (missing-health) portion so the
            -- bar opacity fill shows the world behind it, not the bg color.
            health.bg:ClearAllPoints()
            health.bg:SetPoint("TOPLEFT", health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
            health.bg:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
            health.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
            health.bg:SetVertexColor(DARK_BG_R, DARK_BG_G, DARK_BG_B, 1)
            health.bg:SetAlpha(1)
        end
        -- PostUpdateColor: re-apply dark color after oUF tries to class-color,
        -- and re-anchor bg to track the fill edge.
        -- Alpha is NOT re-applied here ? SetStatusBarColor(r,g,b) with 3 args
        -- preserves existing texture alpha, so the alpha set by
        -- ApplyHealthBarAlpha persists through oUF recolors.
        health.PostUpdateColor = function(self)
            self:SetStatusBarColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, DARK_HEALTH_A)
            if self.bg then
                self.bg:ClearAllPoints()
                self.bg:SetPoint("TOPLEFT", self:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
                self.bg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
                self.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
            end
        end
    else
        health.colorClass = true
        health.colorReaction = true
        health.colorTapped = true
        health.colorDisconnected = true
        -- Check for custom fill/bg colors on this unit
        local unitKey = health._kuiUnitKey
        local unitSettings = unitKey and db.profile[unitKey]
        -- A customFillColor table missing its r/g/b fields (whatever its
        -- origin) would reach unguarded arithmetic below
        -- (`customFill.r * 0.2`) and crash EnableAddon for the whole addon.
        -- Validate at this boundary instead of trusting it's always a
        -- complete color.
        local rawCustomFill = unitSettings and unitSettings.customFillColor
        local customFill = (type(rawCustomFill) == "table" and type(rawCustomFill.r) == "number")
            and rawCustomFill or nil
        local rawCustomBg = unitSettings and unitSettings.customBgColor
        local customBg = (type(rawCustomBg) == "table" and type(rawCustomBg.r) == "number")
            and rawCustomBg or nil
        if customFill then
            -- Custom fill overrides class coloring; skip if class color is enabled
            if not (unitSettings and unitSettings.healthClassColored) then
                health.colorClass = false
                health.colorReaction = false
                health.colorTapped = false
                health.colorDisconnected = false
                health:SetStatusBarColor(customFill.r, customFill.g, customFill.b)
            end
        end
        -- Tint bg to 20% of the class/reaction color, or use custom bg color.
        -- Alpha is NOT re-applied ? SetStatusBarColor(r,g,b) preserves
        -- existing texture alpha through oUF recolors.
        health.PostUpdateColor = function(self, unit, color)
            local uKey = self._kuiUnitKey
            local uSettings = uKey and db.profile[uKey]
            local rawFill = uSettings and uSettings.customFillColor
            local cFill = (type(rawFill) == "table" and type(rawFill.r) == "number") and rawFill or nil
            local rawBg = uSettings and uSettings.customBgColor
            local cBg = (type(rawBg) == "table" and type(rawBg.r) == "number") and rawBg or nil
            local classColored = uSettings and uSettings.healthClassColored
            if uKey == "pet" and classColored then
                local _, cls = UnitClass("player")
                local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
                local c = cls and colors and colors[cls]
                if c then
                    self:SetStatusBarColor(c.r, c.g, c.b)
                    if self.bg then
                        self.bg:SetVertexColor(c.r * 0.2, c.g * 0.2, c.b * 0.2, 1)
                    end
                    return
                end
            end
            -- hostile target/focus: reaction/class colour instead of the theme's friendly green
            local er, eg, eb
            if (uKey == "target" or uKey == "focus") and cFill and not classColored
                and ns.AtlasFill.IsDefaultGreen(cFill) and ns.BarGloss and ns.BarGloss.IsStyledLook
                and ns.BarGloss.IsStyledLook() then
                er, eg, eb = ns.AtlasFill.EnemyColor(unit)
            end
            if (self._kuiEnemyTint and true or false) ~= (er ~= nil) then
                self._kuiEnemyTint = (er ~= nil) or nil
                pcall(ApplyHealthBarTexture, self, uKey)   -- atlas fill is green: swap to flat fill and back
            end
            if er then
                self:SetStatusBarColor(er, eg, eb)
                if self.bg then
                    self.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                    self.bg:SetVertexColor(er * 0.2, eg * 0.2, eb * 0.2, 1)
                end
                return
            end
            if cFill and not classColored then
                self:SetStatusBarColor(cFill.r, cFill.g, cFill.b)
            end
            if self.bg then
                self.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                if cBg then
                    self.bg:SetVertexColor(cBg.r, cBg.g, cBg.b, 1)
                elseif cFill and not classColored then
                    self.bg:SetVertexColor(cFill.r * 0.2, cFill.g * 0.2, cFill.b * 0.2, 1)
                elseif unit then
                    local _, rawClass = UnitClass(unit)
                    if issecretvalue and issecretvalue(rawClass) then
                        -- The fill can consume Blizzard's protected RGB
                        -- directly, but the darkened background cannot perform
                        -- arithmetic on it. Keep a neutral background here.
                        self.bg:SetVertexColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, 1)
                    elseif color and color.GetRGB then
                        local r, g, b = color:GetRGB()
                        self.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 1)
                    else
                        self.bg:SetVertexColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, 1)
                    end
                elseif color and color.GetRGB then
                    local r, g, b = color:GetRGB()
                    self.bg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 1)
                else
                    -- No color source available (e.g. no target) -- use default bg
                    self.bg:SetVertexColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, 1)
                end
            end
        end
        if health.bg then
            -- Restore bg to cover the full bar area
            health.bg:ClearAllPoints()
            PP.Point(health.bg, "TOPLEFT", health, "TOPLEFT", 0, 0)
            PP.Point(health.bg, "BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
            if customBg then
                health.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                health.bg:SetVertexColor(customBg.r, customBg.g, customBg.b, 1)
            elseif customFill then
                health.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                health.bg:SetVertexColor(customFill.r * 0.2, customFill.g * 0.2, customFill.b * 0.2, 1)
            else
                -- No custom colors set -- use default dark bg (#111)
                health.bg:SetTexture(healthBarTextures["Melli Dark"] or "Interface\\Buttons\\WHITE8X8")
                health.bg:SetVertexColor(DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B, 1)
            end
        end
    end
end
ns.ApplyDarkTheme = ApplyDarkTheme

-- Smart power text: percent for mana-centric specs, raw values for the rest.
-- Shared by both oUF tags and the resource bar renderer.
local SMART_POWER_PERCENT_TAG = "kui-powpct"
local SMART_POWER_CURRENT_TAG = "kui-powcur"
local SMART_POWER_TAG_EVENTS = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER"

local function ShouldUseSmartPowerPercent()
    local _, cls = UnitClass("player")
    if not cls then return false end
    if cls == "DRUID" then
        local form = GetShapeshiftForm()
        return form == nil or form == 0 or form == 3
    end
    if cls == "PRIEST" or cls == "SHAMAN" or cls == "MONK" then
        return true
    end
    -- Paladin: only Holy
    if cls == "PALADIN" then
        local spec = GetSpecialization()
        return spec == 1  -- Holy
    end
    -- Mage: only Arcane
    if cls == "MAGE" then
        local spec = GetSpecialization()
        return spec == 1  -- Arcane
    end
    -- Evoker: only Preservation
    if cls == "EVOKER" then
        local spec = GetSpecialization()
        return spec == 2  -- Preservation
    end
    return false
end
ns.ShouldUseSmartPowerPercent = ShouldUseSmartPowerPercent
Compat.IsSmartPowerPercent = ShouldUseSmartPowerPercent

-- Health text helpers (safe vs "secret" taint)
local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function SafeBoolCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then return nil end
    return value == true
end
local function SafeToString(v)
    if IsSecret(v) then return "<secret>" end
    local ok, s = pcall(tostring, v)
    if not ok or s == nil then return "<tostring error>" end
    if IsSecret(s) then return "<secret>" end
    return s
end

local function DebugHP(unit, data)
    if not _G.KUI_UF_HPDEBUG then return end
    _G.KUI_UF_HPDEBUG_LOG = _G.KUI_UF_HPDEBUG_LOG or {}
    _G.KUI_UF_HPDEBUG_LAST = _G.KUI_UF_HPDEBUG_LAST or {}
    local now = GetTime and GetTime() or 0
    local last = _G.KUI_UF_HPDEBUG_LAST[unit] or 0
    if now - last < 0.5 then return end
    _G.KUI_UF_HPDEBUG_LAST[unit] = now

    local line = string.format("|cff00ffff[ktufhpdebug]|r %s", data)
    local log = _G.KUI_UF_HPDEBUG_LOG
    log[#log + 1] = line
    if #log > 200 then table.remove(log, 1) end
    UFHPPrint(line)
end

local function UFHPPrint(msg)
    msg = SafeToString(msg)
    if KT and KT.Print then
        KT:Print(msg)
    elseif _G.DEFAULT_CHAT_FRAME then
        _G.DEFAULT_CHAT_FRAME:AddMessage(msg)
    else
        print(msg)
    end
    if _G.UIErrorsFrame and _G.UIErrorsFrame.AddMessage then
        _G.UIErrorsFrame:AddMessage(msg, 0.2, 1.0, 1.0)
    end
    if _G.RaidNotice_AddMessage and _G.RaidWarningFrame then
        _G.RaidNotice_AddMessage(_G.RaidWarningFrame, msg, _G.ChatTypeInfo and _G.ChatTypeInfo["RAID_WARNING"] or nil)
    end
end

local FormatShortValue

local function RegisterUFHPDebugSlash()
    _G.SLASH_KTUFHPDEBUG1 = "/ktufhpdebug"
    _G.SLASH_KTUFHPDEBUG2 = "/ktufhpdbg"
    SlashCmdList["KTUFHPDEBUG"] = function(msg)
        msg = msg and msg:lower() or ""
        if msg == "state" then
            local prof = db and db.profile
            local s = prof and prof.player
            UFHPPrint(string.format(
                "|cff00ffff[ktufhpdebug]|r db.player healthDisplay=%s left=%s right=%s center=%s",
                SafeToString(s and s.healthDisplay),
                SafeToString(s and s.leftTextContent),
                SafeToString(s and s.rightTextContent),
                SafeToString(s and s.centerTextContent)
            ))
            if frames and frames.player then
                local f = frames.player
                UFHPPrint(string.format(
                    "|cff00ffff[ktufhpdebug]|r tag left=%s right=%s center=%s",
                    SafeToString(f.LeftText and f.LeftText._curTag),
                    SafeToString(f.RightText and f.RightText._curTag),
                    SafeToString(f.CenterText and f.CenterText._curTag)
                ))
            end
            UFHPPrint(string.format(
                "|cff00ffff[ktufhpdebug]|r curhp=%s short=%s perhp=%s",
                SafeToString(UnitHealth("player")),
                SafeToString(FormatShortValue(UnitHealth("player"))),
                SafeToString(UnitHealthPercent and UnitHealthPercent("player", true, CurveConstants.ScaleTo100) or "nil")
            ))
            return
        end
        if msg == "dump" then
            local log = _G.KUI_UF_HPDEBUG_LOG or {}
            for i = math.max(1, #log - 50), #log do
                UFHPPrint(log[i])
            end
            return
        elseif msg == "clear" then
            _G.KUI_UF_HPDEBUG_LOG = {}
            UFHPPrint("|cff00ffff[ktufhpdebug]|r log cleared.")
            return
        end
        _G.KUI_UF_HPDEBUG = not _G.KUI_UF_HPDEBUG
        UFHPPrint("|cff00ffff[ktufhpdebug]|r " .. (_G.KUI_UF_HPDEBUG and "ENABLED" or "DISABLED"))
    end
end

RegisterUFHPDebugSlash()

local function NormalizeNumberString(s)
    if s == nil then return nil end
    if IsSecret(s) then return nil end

    local ok, t = pcall(string.gsub, s, "[,%s]", "")
    if not ok or not t or IsSecret(t) then return nil end
    local n = tonumber(t)
    if n then return n end

    ok, t = pcall(string.gsub, t, "[^%d%.%-]", "")
    if not ok or not t or IsSecret(t) then return nil end
    n = tonumber(t)
    if n then return n end

    ok, t = pcall(string.gsub, t, "%D", "")
    if not ok or not t or IsSecret(t) then return nil end
    if t == "" then return nil end
    return tonumber(t)
end

local function CoerceNumber(v)
    if type(v) == "string" then
        if IsSecret(v) then return nil end
        return NormalizeNumberString(v)
    end
    if type(v) == "number" then
        if IsSecret(v) then return nil end
        return v
    end
    return nil
end

local function ManualShort(n)
    local floor = math.floor
    if n >= 1e6 then
        local v = n / 1e6
        if v == floor(v) then return string.format("%dM", v) end
        return string.format("%.1fM", v)
    end
    if n >= 1e3 then
        local v = n / 1e3
        if v == floor(v) then return string.format("%dK", v) end
        return string.format("%.1fK", v)
    end
    return tostring(floor(n))
end

FormatShortValue = function(val)
    -- Fast path: numeric
    local n = CoerceNumber(val)
    if n then return ManualShort(n) end

    -- Secret path: only safe calls
    if IsSecret(val) then
        if AbbreviateLargeNumbers then
            local ok, res = pcall(AbbreviateLargeNumbers, val)
            if ok and res ~= nil then
                local rn = NormalizeNumberString(res)
                if rn then return ManualShort(rn) end
                return res
            end
        end
        local ok, s = pcall(tostring, val)
        if ok and s ~= nil then return s end
        return ""
    end

    -- Non-secret string path: normalize and abbreviate
    local rn = NormalizeNumberString(val)
    if rn then return ManualShort(rn) end
    return tostring(val)
end

do
  -- (helper functions moved below)
  local function LooksAbbreviated(s)
    if type(s) ~= "string" then return false end
    if s:find("[KkMmBbTt]") then return true end
    -- Any non-digit letters/symbols beyond separators implies abbreviation in locales (e.g., "mil").
    if s:find("[^%d%.,%s]") then return true end
    return false
  end

  local tagName = "curhpshort"
  local function AbbrevHP(unit)
    if not unit or not UnitExists(unit) then return "" end
    if not UnitIsConnected(unit) then return "OFFLINE" end
    if UnitIsDeadOrGhost(unit) then return "DEAD" end
    local hp = UnitHealth(unit)
    -- Normal path: non-secret values use the Blizzard abbreviator.
    if not IsSecret(hp) then
        local nHp = CoerceNumber(hp)
        if AbbreviateLargeNumbers then
            local res = AbbreviateLargeNumbers(hp)
            if IsSecret(res) then
                if nHp then return ManualShort(nHp) end
                return res
            end
            if not LooksAbbreviated(res) and nHp then
                return ManualShort(nHp)
            end
            return res
        end
        if nHp then return ManualShort(nHp) end
        return tostring(hp or "")
    end

    -- Secret path: rebuild from max + percent if possible.
    local maxHP = UnitHealthMax(unit)
    local pct = UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants.ScaleTo100) or nil
    local nMax = CoerceNumber(maxHP)
    local nPct = CoerceNumber(pct)
    if nMax and nPct then
        return ManualShort(nMax * nPct / 100)
    end

    -- Last resort: return Blizzard result without inspecting it.
    if AbbreviateLargeNumbers then
        return AbbreviateLargeNumbers(hp)
    end
    return ""
  end

  oUF.Tags.Methods[tagName] = AbbrevHP
  oUF.Tags.Events[tagName] = "UNIT_HEALTH UNIT_MAXHEALTH"
end

do
  local tagName = "deficithp"
  local function DeficitHP(unit)
    if not unit or not UnitExists(unit) then return "" end
    if not UnitIsConnected(unit) then return "OFFLINE" end
    if UnitIsDeadOrGhost(unit) then return "DEAD" end
    local hp = UnitHealth(unit)
    local maxHP = UnitHealthMax(unit)
    local nHp = CoerceNumber(hp)
    local nMax = CoerceNumber(maxHP)
    if (not nHp or not nMax) and UnitHealthPercent then
      local pct = CoerceNumber(UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
      if pct and nMax then
        nHp = nMax * pct / 100
      end
    end
    if not nHp or not nMax or nMax == 0 then return "" end
    local deficit = nMax - nHp
    if deficit <= 0 then return "" end
    return FormatShortValue(deficit)
  end

  oUF.Tags.Methods[tagName] = DeficitHP
  oUF.Tags.Events[tagName] = "UNIT_HEALTH UNIT_MAXHEALTH"
end

do
  oUF.Tags.Methods["perhpnosign"] = function(unit)
    if not unit or not UnitExists(unit) then return "" end
    if not UnitIsConnected(unit) then return "OFFLINE" end
    if UnitIsDeadOrGhost(unit) then return "DEAD" end
    local pct = UnitHealthPercent and UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    pct = CoerceNumber(pct)
    if pct then
      return tostring(math.floor(pct + 0.5))
    end
    local hp = CoerceNumber(UnitHealth(unit))
    local maxHP = CoerceNumber(UnitHealthMax(unit))
    if not hp or not maxHP or maxHP == 0 then return "0" end
    return tostring(math.floor(hp / maxHP * 100 + 0.5))
  end
  oUF.Tags.Events["perhpnosign"] = "UNIT_HEALTH UNIT_MAXHEALTH"
end

function ns.UsesModernNumbers()
    local vt = KT.VisualThemes
    local theme = vt and vt.GetRenderedTheme and vt:GetRenderedTheme()
    return theme == "retail" or theme == "forever"
end
oUF.Tags.Methods["kui-hpfull"] = function(unit)
    local value = UnitHealth(unit)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end
oUF.Tags.Events["kui-hpfull"] = "UNIT_HEALTH UNIT_MAXHEALTH"
oUF.Tags.Methods["kui-ppfull"] = function(unit)
    local value = UnitPower(unit, UnitPowerType(unit))
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end
oUF.Tags.Events["kui-ppfull"] = SMART_POWER_TAG_EVENTS

do
    -- Classic Visual Style status text, as the old Blizzard frames showed it:
    -- full values ("516/553"), and abbreviated only when they grow too long
    -- for the 119px stock bar (modern health pools).
    local function ClassicStatusValue(v)
        local n = CoerceNumber(v)
        if n then
            if n < 100000 then return tostring(math.floor(n + 0.5)) end
            return ManualShort(n)
        end
        if AbbreviateLargeNumbers then
            local ok, res = pcall(AbbreviateLargeNumbers, v)
            if ok and res ~= nil then return res end
        end
        return ""
    end
    local function ClassicStatusState(u)
        if not u or not UnitExists(u) then return "" end
        if not UnitIsConnected(u) then return PLAYER_OFFLINE or "Offline" end
        if UnitIsDeadOrGhost(u) then return DEAD or "Dead" end
    end
    local function ClassicHealthPercent(u)
        return string.format("%d%%", UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
    end
    local function ClassicPowerPercent(u, pType)
        return string.format("%d%%", UnitPowerPercent(u, pType, true, CurveConstants.ScaleTo100))
    end
    oUF.Tags.Methods["kui-classic-hp"] = function(u)
        local state = ClassicStatusState(u)
        if state then return state end
        return string.format("%s/%s", ClassicStatusValue(UnitHealth(u)), ClassicStatusValue(UnitHealthMax(u)))
    end
    oUF.Tags.Events["kui-classic-hp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"
    oUF.Tags.Methods["kui-classic-hppct"] = function(u)
        if ClassicStatusState(u) then return "" end
        return ClassicHealthPercent(u)
    end
    oUF.Tags.Events["kui-classic-hppct"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"
    oUF.Tags.Methods["kui-classic-hpfull"] = function(u)
        local state = ClassicStatusState(u)
        if state then return state end
        return string.format("%s/%s (%s)", ClassicStatusValue(UnitHealth(u)),
            ClassicStatusValue(UnitHealthMax(u)), ClassicHealthPercent(u))
    end
    oUF.Tags.Events["kui-classic-hpfull"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"
    oUF.Tags.Methods["kui-classic-pp"] = function(u)
        if ClassicStatusState(u) then return "" end
        local pType = UnitPowerType(u)
        return string.format("%s/%s", ClassicStatusValue(UnitPower(u, pType)), ClassicStatusValue(UnitPowerMax(u, pType)))
    end
    oUF.Tags.Events["kui-classic-pp"] = SMART_POWER_TAG_EVENTS .. " UNIT_HEALTH UNIT_CONNECTION"
    oUF.Tags.Methods["kui-classic-pppct"] = function(u)
        if ClassicStatusState(u) then return "" end
        return ClassicPowerPercent(u, UnitPowerType(u))
    end
    oUF.Tags.Events["kui-classic-pppct"] = SMART_POWER_TAG_EVENTS .. " UNIT_HEALTH UNIT_CONNECTION"
    oUF.Tags.Methods["kui-classic-ppfull"] = function(u)
        if ClassicStatusState(u) then return "" end
        local pType = UnitPowerType(u)
        return string.format("%s/%s (%s)", ClassicStatusValue(UnitPower(u, pType)),
            ClassicStatusValue(UnitPowerMax(u, pType)), ClassicPowerPercent(u, pType))
    end
    oUF.Tags.Events["kui-classic-ppfull"] = SMART_POWER_TAG_EVENTS .. " UNIT_HEALTH UNIT_CONNECTION"
end

local POWER_PERCENT_TAG_METHOD = [[function(u)
    local pType = UnitPowerType(u)
    return string.format('%d', UnitPowerPercent(u, pType, true, CurveConstants.ScaleTo100))
end]]
oUF.Tags.Methods[SMART_POWER_PERCENT_TAG] = POWER_PERCENT_TAG_METHOD
oUF.Tags.Events[SMART_POWER_PERCENT_TAG] = SMART_POWER_TAG_EVENTS

local POWER_CURRENT_TAG_METHOD = [[function(u)
    local pType = UnitPowerType(u)
    return AbbreviateLargeNumbers(UnitPower(u, pType))
end]]
oUF.Tags.Methods[SMART_POWER_CURRENT_TAG] = POWER_CURRENT_TAG_METHOD
oUF.Tags.Events[SMART_POWER_CURRENT_TAG] = SMART_POWER_TAG_EVENTS

local optionsFrame
local optionsCategoryID
_G.KUIUF_StylesRegistered = _G.KUIUF_StylesRegistered or false

-- GetSettingsForUnit ahora es alias de UCtx.ResolveSettings (definido arriba)

local function NormalizeCombatIndicatorStyle(style)
    if style == "none" then
        return "none"
    end

    return "standard"
end

-- GetMiniDonorSettings ahora es alias de UCtx.ResolveMiniDonor (definido arriba)

-- Resolve buff anchor + growth direction into oUF aura properties
-- Returns: anchorPoint (on frame), initialAnchor, growthX, growthY, offsetX, offsetY
-- Tabla combinada: cada ancla define su initialAnchor, direcciÃ³n de crecimiento
-- automÃ¡tico, punto de fijaciÃ³n al frame padre y sentido de offset.
local BUFF_LAYOUT_DATA = {
    topleft     = { ia = "BOTTOMLEFT",  ax = "RIGHT", ay = "UP",   fp = "TOPLEFT",     ox = 0,  oy = 1  },
    topright    = { ia = "BOTTOMRIGHT", ax = "LEFT",  ay = "UP",   fp = "TOPRIGHT",    ox = 0,  oy = 1  },
    bottomleft  = { ia = "TOPLEFT",     ax = "RIGHT", ay = "DOWN", fp = "BOTTOMLEFT",  ox = 0,  oy = -1 },
    bottomright = { ia = "TOPRIGHT",    ax = "LEFT",  ay = "DOWN", fp = "BOTTOMRIGHT", ox = 0,  oy = -1 },
    left        = { ia = "BOTTOMRIGHT", ax = "LEFT",  ay = "DOWN", fp = "LEFT",        ox = -1, oy = 0  },
    right       = { ia = "BOTTOMLEFT",  ax = "RIGHT", ay = "DOWN", fp = "RIGHT",       ox = 1,  oy = 0  },
}
-- Mapeo de growth explÃ­cito â†’ (gx, gy)
local GROWTH_OVERRIDES = {
    right = { "RIGHT", "UP"   },
    left  = { "LEFT",  "UP"   },
    up    = { "RIGHT", "UP"   },
    down  = { "RIGHT", "DOWN" },
}

local function ResolveBuffLayout(anchor, growth)
    local d = BUFF_LAYOUT_DATA[anchor or "topleft"] or BUFF_LAYOUT_DATA.topleft
    local gx, gy
    if growth and growth ~= "auto" then
        local ov = GROWTH_OVERRIDES[growth]
        gx, gy = ov and ov[1] or "RIGHT", ov and ov[2] or "UP"
    else
        gx, gy = d.ax, d.ay
    end
    return d.fp, d.ia, gx, gy, d.ox, d.oy
end

-- KUI's generic frame has no stock-art name tab to clear, but its aura row
-- sat a little too close to the top edge on both player and target. Keep the
-- adjustment theme-specific so Classic/Forever/Retail retain their dedicated
-- stock-art geometry. This is a KT method instead of a chunk-local helper
-- because this large Lua 5.1 file already sits at the 200-local limit.
-- Classic/Forever/Retail looks pull bottom debuffs 4px closer to the frame;
-- KUI Style keeps the Retail spacing.
function KT:GetStyledDebuffLift()
    local VT = self.VisualThemes
    local th = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
    return (th == "classic" or th == "forever" or th == "retail") and 4 or 0
end

function KT:GetKUIStyleBuffYOffset(unit)
    if unit ~= "player" and unit ~= "target" then return 0 end
    local VT = self.VisualThemes
    local renderedTheme = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
    -- KUI Style keeps the Retail aura position (no extra lift).
    return 0
end

-- â”€â”€â”€ ResoluciÃ³n de tags de vida â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Tabla display â†’ tag oUF (compartida por player, target, focus, boss).
-- Una sola funciÃ³n ResolveHealthTag reemplaza las antiguas 3 funciones
-- individuales, consultando HEALTH_TAG_CONTEXT para defaults por unidad.
-- Aura rows belong to the visible health bar, not to the outer unit-frame
-- box. This matters for every portrait style and especially for stock art,
-- where the frame includes large transparent/chrome areas around Health.
function KT:ResolveUFAuraBarGeometry(frame)
    local VT = self.VisualThemes
    local th = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
    if th ~= "classic" and th ~= "forever" and th ~= "retail" then
        -- KUI Style keeps the Retail layout: auras anchored to the whole frame,
        -- 22px icons, 7 per row.
        local fw = frame and frame.GetWidth and frame:GetWidth() or 0
        return frame, fw, 22, 1, 7
    end
    local bar = frame and (frame.Health or frame)
    local width = bar and bar.GetWidth and bar:GetWidth() or 0
    if width <= 0 then width = frame and frame.GetWidth and frame:GetWidth() or 22 end

    local gap = 1
    -- Fixed 22, as before this function existed (commit caf2205 replaced
    -- several separate "local auraSize = 22" call sites). Tying icon size to
    -- the live Health bar's own height was meant for Forever's stock art,
    -- which already computes its own icon size independently in
    -- ThemeClientAssets.lua (geom.health.h * scale) and never calls this
    -- function at all -- so the only real effect was the generic/kui
    -- path's icons silently growing to match Health's full height (46px by
    -- default for player/target), not the small, fixed size they'd always
    -- had before.
    local auraSize = 22
    local perRow = math.max(1, math.floor((width + gap) / (auraSize + gap)))
    return bar or frame, width, auraSize, gap, perRow
end

function KT:ApplyLegacyUFAuraBarGeometry(container, frame, framePoint, initialAnchor,
        growthX, growthY, offsetX, offsetY)
    if not (container and frame) then return end
    local bar, width, auraSize, gap, perRow = KT:ResolveUFAuraBarGeometry(frame)
    container:ClearAllPoints()
    container:SetPoint(initialAnchor, bar, framePoint,
        (offsetX or 0) * gap, (offsetY or 0) * gap)
    container:SetSize(width, auraSize)
    container.size = auraSize
    container.spacing = gap
    container["size-x"] = perRow
    container.initialAnchor = initialAnchor
    container.growthX = growthX
    container.growthY = growthY
    return width, auraSize, gap, perRow
end
local HEALTH_DISPLAY_TAGS = {
    curhpshort = "[curhpshort]",
    perhp      = "[perhp]%",
    both       = "[curhpshort] | [perhp]%",
}
local HEALTH_TAG_CONTEXT = {
    player = { key = "player", default = "both"  },
    target = { key = "target", default = "both"  },
    focus  = { key = "focus",  default = "perhp" },
    boss   = { key = "boss",   default = "perhp" },
}
local function ResolveHealthTag(unit)
    local ctx = HEALTH_TAG_CONTEXT[unit] or HEALTH_TAG_CONTEXT.player
    local tbl = db.profile[ctx.key]
    local display = (tbl and tbl.healthDisplay) or ctx.default
    return HEALTH_DISPLAY_TAGS[display] or HEALTH_DISPLAY_TAGS[ctx.default]
end

-- Resolve a leftTextContent / rightTextContent value to an oUF tag string.
-- content: "name", "both", "curhpshort", "curhp", "curhp_perhp", "perhp", "perhpnosign", "perhpnum", "deficit", "none"
local function ContentToTag(content)
    if content == "name" then return "[name]"
    elseif content == "both" then return "[curhpshort] | [perhp]%"
    elseif content == "curhp_perhp" then return "[curhp] | [perhp]%"
    elseif content == "perhpnum" then return "[perhp]% | [curhpshort]"
    elseif content == "curhpshort" then return "[curhpshort]"
    elseif content == "curhp" then return ns.UsesModernNumbers() and "[kui-hpfull]" or "[curhp]"
    elseif content == "perhp" then return "[perhp]%"
    elseif content == "perhpnosign" then return "[perhpnosign]"
    elseif content == "deficit" then return "[deficithp]"
    elseif content == "perpp" then return "[perpp]%"
    elseif content == "curpp" then return "[curpp]"
    elseif content == "curhp_curpp" then return "[curhpshort] | [curpp]"
    elseif content == "perhp_perpp" then return "[perhp]% | [perpp]%"
    else return nil end
end

-- Estimate pixel width of a text content type for name truncation.
-- Flat pixel assumptions matching the nameplate system.
local UF_TEXT_PADDING = 10
local ufTextWidths = {
    both        = 75,  -- "132 K | 86%"
    curhp_perhp = 90,  -- "132000 | 86%"
    perhpnum    = 75,  -- "86% | 132 K"
    curhpshort  = 38,  -- "132 K"
    curhp       = 60,  -- "132000"
    perhp       = 38,  -- "86%"
    perhpnosign = 30,  -- "86"
    deficit     = 38,  -- "12 K"
    perpp       = 38,  -- "86%"
    curpp       = 38,  -- "132"
    curhp_curpp = 75,  -- "132 K | 132"
    perhp_perpp = 75,  -- "86% | 86%"
}
local function EstimateUFTextWidth(content)
    return (ufTextWidths[content] or 0) + UF_TEXT_PADDING
end

-- Apply class color to a FontString based on the unit
local function ApplyClassColor(fs, unit, useClassColor)
    if not fs then return end
    if useClassColor then
        local class = ResolveSafeClassToken(unit)
        if class then
            local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
            if c then fs:SetTextColor(c.r, c.g, c.b); return end
        end
    end
    fs:SetTextColor(1, 1, 1)
end

local UF_ICONS_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local BLIZZ_CLASS_ICON_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_FULL_COORDS = CLASS_ICON_TCOORDS or {
    WARRIOR     = { 0,     0.25,  0,     0.25  },
    MAGE        = { 0.25,  0.496, 0,     0.25  },
    ROGUE       = { 0.496, 0.742, 0,     0.25  },
    DRUID       = { 0.742, 0.988, 0,     0.25  },
    HUNTER      = { 0,     0.25,  0.25,  0.496 },
    SHAMAN      = { 0.25,  0.496, 0.25,  0.496 },
    PRIEST      = { 0.496, 0.742, 0.25,  0.496 },
    WARLOCK     = { 0.742, 0.988, 0.25,  0.496 },
    PALADIN     = { 0,     0.25,  0.496, 0.742 },
    DEATHKNIGHT = { 0.25,  0.496, 0.496, 0.742 },
    MONK        = { 0.496, 0.742, 0.496, 0.742 },
    DEMONHUNTER = { 0.742, 0.988, 0.496, 0.742 },
    EVOKER      = { 0,     0.25,  0.742, 0.988 },
}

-- Helper: apply class icon from sprite sheet
local function ApplyClassIconTexture(tex, classToken, style)
    local coords = CLASS_FULL_COORDS[classToken]
    if not coords then return false end
    tex:SetTexture(BLIZZ_CLASS_ICON_TEXTURE)
    tex._classCoords = { coords[1], coords[2], coords[3], coords[4] }
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    return true
end

-- Shared portrait camera is loaded by the core for Unit and Party Frames.
local function GetDefaultPortraitFacing(unit)
    -- Player and target still face each other ("look inward" toward their
    -- own frame content), but swapped from the previous defaults: player
    -- now faces the direction target used to, and vice versa. Other units
    -- (focus/pet/boss) keep their previous "normal" default, unaffected by
    -- this swap.
    if unit == "player" then
        return "flipped"
    end
    if unit == "target" then
        return "normal"
    end
    return "normal"
end

local function GetPortraitFacing(unit, settings)
    -- Explicit per-unit choice (Unit Frames > Portrait Facing), valid in every
    -- style. "auto"/nil keeps the style-specific automatic behaviour below.
    local mode = settings and settings.portraitFacingMode
    if mode == "normal" or mode == "flipped" then
        return mode
    end
    local facing = (settings and settings.portraitFacing) or GetDefaultPortraitFacing(unit)

    -- The Classic/Forever stock boxes mirror player/target around the
    -- central gameplay area. Keep ordinary portraits facing inward toward
    -- their bars; a live player shapeshift keeps the client's already-
    -- correct druid-form direction instead of flipping it a second time.
    -- This applies to both real-stock themes, not just Classic: Forever's
    -- 2D portrait is already correctly oriented for the current shapeshift
    -- by the client itself, so forcing our facing on top of it is wrong
    -- (and inconsistent with the non-shapeshifted case) while shapeshifted.
    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    local classicKit = db and db.profile and db.profile.frameArtKit == "classic"
    -- KUI joins this rule: its default profile stores portraitFacing (player "flipped",
    -- target "normal") for everyone, which made the shapeshift-aware branch below dead code
    -- and left humanoid portraits looking outward.
    if (renderedTheme == "classic" or renderedTheme == "forever" or renderedTheme == "retail" or renderedTheme == "kui" or classicKit)
        and (unit == "player" or unit == "target") then
        if unit == "target" then
            -- Target must always be the MIRROR IMAGE of player's own
            -- resolved facing, never a fixed constant -- a hardcoded
            -- "flipped" here breaks the moment player ALSO needs "flipped"
            -- (shapeshifted), since two frames returning the same value
            -- render IDENTICALLY instead of as mirror images. Both portraits
            -- come from the same underlying capture convention regardless
            -- of shapeshift state, so deriving target from player's own
            -- answer -- instead of assuming what player currently resolves
            -- to -- keeps them opposite in every case.
            local playerFacing = GetPortraitFacing("player", GetSettingsForUnit("player"))
            return (playerFacing == "flipped") and "normal" or "flipped"
        else
            -- Player, NOT shapeshifted: the normal 3D portrait already faces
            -- inward and needs no override flip.
            local shapeshifted = false
            if type(GetShapeshiftForm) == "function" then
                local ok, form = pcall(GetShapeshiftForm)
                shapeshifted = ok and type(form) == "number" and form > 0
            end
            if shapeshifted then
                -- Player, shapeshifted: a side-by-side comparison (same
                -- build, same "normal" value) showed the humanoid case
                -- correct and the shapeshift-form case still wrong --
                -- proof the two portrait kinds don't share one orientation
                -- convention. Shapeshift icons are 2D art with their own
                -- baked facing, opposite of the 3D portrait's. Flip only
                -- this case.
                return "flipped"
            end
            return "normal"
        end
    end

    -- kui style used to always use the fixed default above
    -- (GetDefaultPortraitFacing's "flipped" for player) regardless of
    -- shapeshift state -- right by coincidence for a shapeshifted Druid
    -- (the 2D form icon's baked facing is the opposite of the normal 3D
    -- portrait's) but wrong for every ordinary humanoid portrait. Same
    -- shapeshift-aware check the stock themes above already use, applied
    -- here too -- but only when the user hasn't picked an explicit facing
    -- of their own (settings.portraitFacing), since that deliberate choice
    -- always wins.
    if unit == "player" and not (settings and settings.portraitFacing) then
        local shapeshifted = false
        if type(GetShapeshiftForm) == "function" then
            local ok, form = pcall(GetShapeshiftForm)
            shapeshifted = ok and type(form) == "number" and form > 0
        end
        return shapeshifted and "flipped" or "normal"
    end

    return facing
end

-- Classification artwork is directional. Its dragon head must face inward,
-- toward the health bar, independently of the model/texture facing inside
-- the portrait. Basing this on GetPortraitFacing makes both default frames
-- point outward (player on the left, target on the right).
local function GetClassificationTextureFlipped(unit, settings)
    local side = settings and settings.portraitSide
    if side ~= "left" and side ~= "right" then
        side = (unit == "player" or unit == "pet") and "left" or "right"
    end
    -- The source PNG points left. Mirror it when the portrait is on the left
    -- so the head points right, into the bars.
    return side == "left"
end

-- Debug export of the live facing/flip formula inputs (shapeshift state,
-- classification, resolved settings) and return values. Exported on KT
-- itself (not the local `ns`) -- ThemeClientAssets.lua lives in a SEPARATE
-- addon/TOC with its own private `ns` upvalue from a different `...`; KT is
-- the one object LibStub hands back identically to every KullThranUI
-- sub-addon that asks for it.
function KT.ResolvePortraitFacing(unit)
    local ok, facing = pcall(GetPortraitFacing, unit, GetSettingsForUnit(unit))
    return ok and facing or nil
end

function KT.KTDebugFacingState(unit)
    local settings = GetSettingsForUnit(unit)
    local ok1, facing = pcall(GetPortraitFacing, unit, settings)
    local ok2, classFlipped = pcall(GetClassificationTextureFlipped, unit, settings)
    local shapeshiftForm
    if unit == "player" and type(GetShapeshiftForm) == "function" then
        local ok, form = pcall(GetShapeshiftForm)
        shapeshiftForm = ok and form or "pcall-failed"
    end
    local classification = SafeUnitClassification(unit)
    return {
        facing = ok1 and facing or "ERROR:" .. tostring(facing),
        classFlipped = ok2 and classFlipped or "ERROR:" .. tostring(classFlipped),
        shapeshiftForm = shapeshiftForm,
        classification = classification,
        renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
            and KT.VisualThemes:GetRenderedTheme(),
        frameArtKit = db and db.profile and db.profile.frameArtKit,
    }
end

function KT.DebugPortrait3DState(unit)
    local debug = KT.Portrait3DDebug
    local frame = frames[unit]
    local settings = GetSettingsForUnit(unit) or {}
    local portrait = frame and frame.Portrait
    local backdrop = portrait and portrait.backdrop
    local model = backdrop and backdrop._3d
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    local lines = {
        unit .. " savedMode=" .. debug.Value(settings.portraitMode)
            .. " resolvedMode=" .. debug.Value(ResolveActivePortraitMode(unit, settings))
            .. " showPortrait=" .. debug.Value(settings.showPortrait)
            .. " style=" .. debug.Value(db and db.profile and db.profile.portraitStyle)
            .. " theme=" .. debug.Value(theme),
        "settings facing=" .. debug.Value(settings.portraitFacingMode)
            .. " side=" .. debug.Value(settings.portraitSide)
            .. " rotation=" .. debug.Value(settings.portrait3DRotation)
            .. " zoom=" .. debug.Value(settings.portrait3DZoom)
            .. " x=" .. debug.Value(settings.portrait3DX)
            .. " y=" .. debug.Value(settings.portrait3DY),
        "frame=" .. debug.Call(frame, "GetName")
            .. " unit=" .. debug.Value(frame and frame.unit)
            .. " elementEnabled=" .. debug.Call(frame, "IsElementEnabled", "Portrait")
            .. " activeObject=" .. debug.Call(portrait, "GetObjectType")
            .. " activeIs3D=" .. tostring(model ~= nil and portrait == model),
        "3D " .. debug.Model(model),
        "backdrop shown=" .. debug.Call(backdrop, "IsShown")
            .. " visible=" .. debug.Call(backdrop, "IsVisible")
            .. " size=" .. debug.Call(backdrop, "GetSize")
            .. " level=" .. debug.Call(backdrop, "GetFrameLevel")
            .. " clipsChildren=" .. debug.Call(backdrop, "DoesClipChildren"),
    }
    lines[#lines + 1] = "text settings left=" .. debug.Value(settings.leftTextContent)
        .. " right=" .. debug.Value(settings.rightTextContent)
        .. " center=" .. debug.Value(settings.centerTextContent)
        .. " resource=" .. debug.Value(settings.powerTextFormat)
        .. " resourcePosition=" .. debug.Value(settings.powerPercentText)
    for _, key in ipairs({ "LeftText", "RightText", "CenterText", "_kuiLevelText" }) do
        local fs = frame and frame[key]
        lines[#lines + 1] = key .. " font=" .. debug.Call(fs, "GetFont")
            .. " shown=" .. debug.Call(fs, "IsShown")
            .. " tag=" .. debug.Value(fs and fs._curTag)
    end
    if model then
        local applied = model._ktPortraitCameraApplied or {}
        lines[#lines + 1] = "last camera unit=" .. debug.Value(model._camUnit)
            .. " yaw=" .. debug.Value(applied.yaw) .. " zoom=" .. debug.Value(applied.zoom)
            .. " x=" .. debug.Value(applied.x) .. " y=" .. debug.Value(applied.y)
    end
    for _, key in ipairs({"_ktClassicArtHost", "_ktForeverArtHost", "_ktClassicPortraitFill", "Health", "Power"}) do
        local region = frame and frame[key]
        lines[#lines + 1] = key .. " shown=" .. debug.Call(region, "IsShown")
            .. " level=" .. debug.Call(region, "GetFrameLevel")
    end
    local art = frame and frame._ktStockArtSelection or {}
    lines[#lines + 1] = "art theme=" .. debug.Value(art.theme) .. " source=" .. debug.Value(art.source)
        .. " atlas=" .. debug.Value(art.atlas) .. " file=" .. debug.Value(art.file)
        .. " size=" .. debug.Value(art.width) .. "," .. debug.Value(art.height)
    if model then
        lines[#lines + 1] = "camera requested viewShift=" .. debug.Value(model._ktPortraitCameraApplied and model._ktPortraitCameraApplied.viewShift)
    end
    return lines
end
function KT.DebugSetPortraitCamera(unit, angle, shift)
    local frame = frames[unit]
    local model = frame and frame.Portrait and frame.Portrait.backdrop and frame.Portrait.backdrop._3d
    if not model then return false end
    if angle == nil then
        model._ktPortraitDebugLook = nil
        if model.ForceUpdate then model:ForceUpdate() end
    else
        model._ktPortraitDebugLook = { yaw = math.rad(angle), viewShift = shift or 0 }
        local applied = model._ktPortraitCameraApplied or {}
        KT.ApplyPortrait3DCamera(model, model._ktPortraitDebugLook.yaw, applied.zoom or 1.25,
            applied.x or 0, applied.y or 0, model._ktPortraitDebugLook.viewShift)
    end
    return true
end

local function ApplyPortraitFacing(tex, unit, settings, fullTexture)
    if not tex then return end

    local facing = GetPortraitFacing(unit, settings)
    if fullTexture and tex._classCoords then
        local c = tex._classCoords
        if facing == "flipped" then
            tex:SetTexCoord(c[2], c[1], c[3], c[4])
        else
            tex:SetTexCoord(c[1], c[2], c[3], c[4])
        end
    elseif fullTexture or (db and db.profile and db.profile.portraitStyle == "circular") then
        if facing == "flipped" then
            tex:SetTexCoord(1, 0, 0, 1)
        else
            tex:SetTexCoord(0, 1, 0, 1)
        end
    elseif facing == "flipped" then
        tex:SetTexCoord(0.85, 0.15, 0.15, 0.85)
    else
        tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    end
end


-- Re-resolve class token + sprite coords + facing for the class-art portrait.
-- Needed on every unit change (PLAYER_TARGET_CHANGED etc): the class texture is
-- static and was only refreshed on creation / full reload, so it kept the
-- previous unit's class (e.g. own rogue icon) after retargeting.
ns.RefreshClassPortrait = function(unit, backdrop)
    if not (backdrop and backdrop._class) then return end
    local uKey = UnitToSettingsKey(unit) or unit
    local uSettings = uKey and db and db.profile and db.profile[uKey]
    if ResolveActivePortraitMode(unit, uSettings) ~= "class" then return end
    local ct = ResolvePortraitClassToken(unit)
    if not ct then backdrop._class:Hide(); return end
    ApplyClassIconTexture(backdrop._class, ct, (uSettings and uSettings.classThemeStyle) or "modern")
    ApplyPortraitFacing(backdrop._class, unit, uSettings, true)
    backdrop._class:Show()
end


-- Portrait mask and border paths for detached portrait shapes
local PORTRAIT_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local PORTRAIT_MASKS = {
    portrait = PORTRAIT_MEDIA .. "portrait_mask.tga",
    circle   = PORTRAIT_MEDIA .. "circle_mask.tga",
    square   = PORTRAIT_MEDIA .. "square_mask.tga",
    csquare  = PORTRAIT_MEDIA .. "csquare_mask.tga",
    diamond  = PORTRAIT_MEDIA .. "diamond_mask.tga",
    hexagon  = PORTRAIT_MEDIA .. "hexagon_mask.tga",
    shield   = PORTRAIT_MEDIA .. "shield_mask.tga",
}
local PORTRAIT_BORDERS = {
    portrait = PORTRAIT_MEDIA .. "portrait_border.tga",
    circle   = PORTRAIT_MEDIA .. "circle_border.tga",
    square   = PORTRAIT_MEDIA .. "square_border.tga",
    csquare  = PORTRAIT_MEDIA .. "csquare_border.tga",
    diamond  = PORTRAIT_MEDIA .. "diamond_border.tga",
    hexagon  = PORTRAIT_MEDIA .. "hexagon_border.tga",
    shield   = PORTRAIT_MEDIA .. "shield_border.tga",
}

-- Top pixel inset for each mask shape (px from edge to visible portrait area in 128px mask)
local MASK_INSETS = {
    circle   = 17,
    csquare  = 17,
    diamond  = 14,
    hexagon  = 17,
    portrait = 17,
    shield   = 13,
    square   = 17,
}

function KT:FitStockUFPortraitMask(backdrop)
    if not (backdrop and backdrop._ktStockPortraitAnchor and backdrop._shapeMask) then return end
    local expand = backdrop._ktStockPortraitMaskExpand or 0
    backdrop._shapeMask:ClearAllPoints()
    backdrop._shapeMask:SetPoint("TOPLEFT", backdrop, "TOPLEFT", -expand, expand)
    backdrop._shapeMask:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", expand, -expand)
    backdrop._shapeMask:Show()
    -- SetPortraitTexture/shape updates can replace the active portrait region
    -- without preserving its mask membership. Re-seat it on every stock pass
    -- so a druid form can never expose square texture corners outside the
    -- circular portrait opening.
    for _, tex in ipairs({ backdrop._2d, backdrop._class, backdrop._bg }) do
        if tex and tex.AddMaskTexture then
            if tex.RemoveMaskTexture then
                pcall(tex.RemoveMaskTexture, tex, backdrop._shapeMask)
            end
            pcall(tex.AddMaskTexture, tex, backdrop._shapeMask)
        end
    end
end
local function AnchorCircularPortrait(backdrop, uSettings, unitToken)
    if not (backdrop and backdrop:GetParent()) then return end
    -- Classic/Forever/Retail stock renderers own this anchor while active.
    -- Generic KUI circular updates can still run later in the same refresh;
    -- they must never move a stock portrait back beside the health bar.
    if backdrop._ktStockPortraitAnchor then return end

    local frame = backdrop:GetParent()
    local health = frame.Health
    if not health then return end

    local side = (uSettings and uSettings.portraitSide) or backdrop._portraitSide
        or ((unitToken == "player" or unitToken == "pet") and "left" or "right")
    local xOffset = (uSettings and uSettings.portraitX) or 0
    local yOffset = (uSettings and uSettings.portraitY) or 0
    local overlap = math.max(0, (backdrop:GetWidth() or 0) * 0.5)

    backdrop:ClearAllPoints()
    if side == "top" then
        backdrop:SetPoint("BOTTOM", health, "TOP", xOffset, yOffset)
    elseif side == "left" then
        backdrop:SetPoint("RIGHT", health, "LEFT", overlap + xOffset, yOffset)
    else
        backdrop:SetPoint("LEFT", health, "RIGHT", -overlap + xOffset, yOffset)
    end
    -- Health also uses frame level +2. Sharing its exact level leaves draw
    -- order undefined and can put the bar over the portrait in KUI Style.
    -- Preserve the high portrait level established at creation and guarantee
    -- that it remains above Health after every re-anchor/refresh.
    local healthLevel = health:GetFrameLevel() or (frame:GetFrameLevel() + 2)
    backdrop:SetFrameLevel(math.max(50, frame:GetFrameLevel() + 20, healthLevel + 1))
    -- Keep the 3D model under the ring frame after the level change.
    if backdrop._3d then backdrop._3d:SetFrameLevel(backdrop:GetFrameLevel() + 1) end
    if backdrop._shapeBorderFrame then backdrop._shapeBorderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 3) end
    PP.SetHiddenEdge(frame.unifiedBorder, (side == "left" and 3) or (side == "right" and 4) or nil)
    -- The power bar always sits below the circular portrait.
    if frame.Power then frame.Power:SetFrameLevel(frame:GetFrameLevel() + 1) end
end

local function ResolveCircularPortraitColor(frame, uSettings, unitToken)
    local profile = db and db.profile
    if profile and profile.circularPortraitBorderUseCustomColor == true then
        local color = profile.circularPortraitBorderColor
        if type(color) == "table" then
            return color.r or 1, color.g or 1, color.b or 1
        end
    end

    if db and db.profile and db.profile.darkTheme then
        return DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B
    end

    local customFill = uSettings and uSettings.customFillColor
    local classColored = uSettings and uSettings.healthClassColored ~= false
    if customFill and not classColored then
        return customFill.r or 1, customFill.g or 1, customFill.b or 1
    end

    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local function ClassColor(token)
        local classToken = ResolveSafeClassToken(token)
        local color = classToken and colors and colors[classToken]
        if color then return color.r, color.g, color.b end
    end

    if classColored and unitToken == "pet" then
        local r, g, b = ClassColor("player")
        if r then return r, g, b end
    end

    if classColored and unitToken and UnitExists(unitToken) then
        if UnitIsPlayer(unitToken) then
            local r, g, b = ClassColor(unitToken)
            if r then return r, g, b end
        elseif UnitIsTapDenied and UnitIsTapDenied(unitToken) then
            return 0.6, 0.6, 0.6
        else
            local reaction = UnitReaction(unitToken, "player")
            local color = reaction and FACTION_BAR_COLORS[reaction]
            if color then return color.r, color.g, color.b end
        end
    end

    if frame and frame.Health then
        local texture = frame.Health:GetStatusBarTexture()
        if texture and texture.GetVertexColor then
            local r, g, b = texture:GetVertexColor()
            if r then return r, g, b end
        end
        return frame.Health:GetStatusBarColor()
    end

    return 1, 1, 1
end

-- Apply detached portrait shape (mask + border overlay) to a portrait backdrop.
-- Creates mask/border textures on first call, then updates them.
-- backdrop: the portrait backdrop frame
-- uSettings: per-unit DB table
-- unitToken: the unit this portrait belongs to (e.g. "player", "target")
local function ApplyDetachedPortraitShape(backdrop, uSettings, unitToken)
    if unitToken == "player" and backdrop._ktNativeClassificationActive then
        ns.SeatNativePlayerPortrait(backdrop)
        return
    end
    -- Stock frame sheets already own the portrait rim. Metadata refreshes
    -- must not repaint the detached KUI border over their Rare/Elite art.
    if backdrop._ktStockPortraitAnchor then
        KT:FitStockUFPortraitMask(backdrop)
        if backdrop._shapeBorderTex then backdrop._shapeBorderTex:Hide() end
        if backdrop._sqBorderTexs then
            for _, texture in ipairs(backdrop._sqBorderTexs) do texture:Hide() end
        end
        return
    end
    local portraitStyle = db.profile.portraitStyle or "attached"
    local isDetached = portraitStyle == "detached"
    local isCircular = portraitStyle == "circular"
    local usesShape = isDetached or isCircular

    -- Rama rÃ¡pida: sin modo desacoplado, solo limpiar mÃ¡scara y restaurar posiciones
    if not usesShape then
        if backdrop._shapeMask then
            local texs = { backdrop._2d, backdrop._class, backdrop._bg }
            for _, tex in ipairs(texs) do
                if tex then tex:RemoveMaskTexture(backdrop._shapeMask) end
            end
            backdrop._shapeMask:Hide()
        end
        if backdrop._shapeBorderTex then backdrop._shapeBorderTex:Hide() end
        if backdrop._sqBorderTexs then
            for _, t in ipairs(backdrop._sqBorderTexs) do t:Hide() end
        end
        -- Restaurar posiciones por defecto para 2d, class e 3d
        local bh2 = backdrop:GetHeight()
        if bh2 < 1 then bh2 = 46 end
        local classInset = math.floor(bh2 * 0.08)
        local resetTargets = {
            { tex = backdrop._2d,    tl = { 0, 0 },           br = { 0, 0 } },
            { tex = backdrop._class, tl = { classInset, -classInset }, br = { -classInset, classInset } },
            { tex = backdrop._3d,    tl = { 0, 0 },           br = { 0, 0 } },
        }
        for _, r in ipairs(resetTargets) do
            if r.tex then
                r.tex:ClearAllPoints()
                PP.Point(r.tex, "TOPLEFT",     backdrop, "TOPLEFT",     r.tl[1], r.tl[2])
                PP.Point(r.tex, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", r.br[1], r.br[2])
            end
        end
        return
    end
    -- === Modo desacoplado: extraer configuraciÃ³n y resolver color del borde ===
    local shape = isCircular and "circle" or ((uSettings and uSettings.detachedPortraitShape) or "portrait")
    local borderOpacity = ((uSettings and uSettings.detachedPortraitBorderOpacity) or 100) / 100
    local rawBorderSize = (uSettings and uSettings.detachedPortraitBorderSize) or 7
    local bExp = 7 - rawBorderSize
    -- Stock art already draws its own portrait ring. Keeping KUI's shape
    -- border here produces a second colored circle over the Classic frame.
    local showBorder = not backdrop._ktStockPortraitAnchor
        and (isCircular or not (uSettings and uSettings.detachedPortraitBorder == false))

    -- Color del borde: resolver segÃºn classColor > unit > manual > fallback
    local bc = (uSettings and uSettings.detachedPortraitBorderColor) or { r = 0, g = 0, b = 0 }
    local bR, bG, bB = bc.r, bc.g, bc.b
    local owner = backdrop:GetParent()
    if isCircular and owner and owner.Health then
        bR, bG, bB = ResolveCircularPortraitColor(owner, uSettings, unitToken)
    elseif (uSettings and uSettings.detachedPortraitClassColor) then
        local function classRGB(tok)
            local ct = ResolveSafeClassToken(tok)
            local c = ct and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[ct]
            return c and c.r, c and c.g, c and c.b
        end
        local isDark = db and db.profile and db.profile.darkTheme
        local r, g, b
        if isDark then
            r, g, b = classRGB("player")
        elseif unitToken and UnitExists(unitToken) then
            if UnitIsPlayer(unitToken) then
                r, g, b = classRGB(unitToken)
            elseif UnitIsTapDenied and UnitIsTapDenied(unitToken) then
                r, g, b = 0.6, 0.6, 0.6
            else
                local reaction = UnitReaction(unitToken, "player")
                local c = reaction and FACTION_BAR_COLORS[reaction]
                if c then r, g, b = c.r, c.g, c.b end
            end
        end
        if not r then r, g, b = classRGB("player") end
        if r then bR, bG, bB = r, g, b end
    end

    -- === MASK ===
    local maskPath = PORTRAIT_MASKS[shape]
    if maskPath then
        if not backdrop._shapeMask then
            backdrop._shapeMask = backdrop:CreateMaskTexture()
        end
        -- Inset mask by 1px when border is visible so scaling can't make the
        -- mask edge poke out from behind the border art
        backdrop._shapeMask:ClearAllPoints()
        if rawBorderSize >= 1 then
            PP.Point(backdrop._shapeMask, "TOPLEFT", backdrop, "TOPLEFT", 1, -1)
            PP.Point(backdrop._shapeMask, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, 1)
        else
            backdrop._shapeMask:SetAllPoints(backdrop)
        end
        backdrop._shapeMask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        backdrop._shapeMask:Show()
        if backdrop._2d then backdrop._2d:AddMaskTexture(backdrop._shapeMask) end
        if backdrop._class then backdrop._class:AddMaskTexture(backdrop._shapeMask) end
        if backdrop._bg then backdrop._bg:AddMaskTexture(backdrop._shapeMask) end
    end

    -- Hide legacy square border textures if they exist
    if backdrop._sqBorderTexs then
        for _, t in ipairs(backdrop._sqBorderTexs) do t:Hide() end
    end

    -- === TGA BORDER OVERLAY ===
    if not backdrop._shapeBorderTex then
        -- The ring lives on its own frame above the portrait so it also
        -- covers 3D models, which draw above every texture of the backdrop.
        local ringFrame = CreateFrame("Frame", nil, backdrop)
        ringFrame:SetAllPoints(backdrop)
        backdrop._shapeBorderFrame = ringFrame
        backdrop._shapeBorderTex = ringFrame:CreateTexture(nil, "OVERLAY")
    end
    backdrop._shapeBorderTex:ClearAllPoints()
    PP.Point(backdrop._shapeBorderTex, "TOPLEFT", backdrop, "TOPLEFT", -bExp, bExp)
    PP.Point(backdrop._shapeBorderTex, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", bExp, -bExp)
    -- The portrait is masked, but the border must remain unmasked so its full
    -- thickness stays visible around the circle.
    if backdrop._shapeMask then
        pcall(backdrop._shapeBorderTex.RemoveMaskTexture, backdrop._shapeBorderTex, backdrop._shapeMask)
    end
    if showBorder then
        local borderPath = PORTRAIT_BORDERS[shape]
        if borderPath then
            backdrop._shapeBorderTex:SetTexture(borderPath)
            backdrop._shapeBorderTex:SetVertexColor(bR, bG, bB, borderOpacity)
            backdrop._shapeBorderTex:Show()
        else
            backdrop._shapeBorderTex:Hide()
        end
    else
        backdrop._shapeBorderTex:Hide()
    end

    -- === Content positioning within mask ===
    -- Scale portrait so its visible area fills the mask opening.
    -- MASK_INSETS[shape] = px from mask edge to visible area (in 128px mask).
    -- Content expands to fill mask; border size no longer affects content.
    local insetPx = MASK_INSETS[shape] or 17
    local bw = backdrop:GetWidth()
    local bh2 = backdrop:GetHeight()
    if bw < 1 then bw = 46 end
    if bh2 < 1 then bh2 = 46 end
    local visRatio = (128 - 2 * insetPx) / 128
    -- Circular style normally skips this zoom (cScale=1): KUI's own
    -- decorative circular_border.tga is drawn at a size that already
    -- matches an unzoomed portrait, so zooming would push the content past
    -- where that border expects it. Classic/Forever/Retail's REAL stock
    -- rendering (backdrop._ktStockPortraitAnchor) uses a completely
    -- different ring asset that expects a snugly-filled portrait, same as
    -- every non-circular shape -- without this zoom, the portrait renders
    -- small and centered with a wide dark dead-space margin all around it
    -- before reaching the ring, unlike the reference stock Classic frame
    -- where the portrait fills the opening edge-to-edge. _2d/_class's own
    -- bounding box (backdrop) stays exactly at the real stock geometry
    -- either way -- only their content zooms to fill it, it doesn't change
    -- what box they're clipped to.
    local cScale = (isCircular and not backdrop._ktStockPortraitAnchor) and 1 or (1 / visRatio)
    -- Apply user art scale (100 = default, stored as percentage)
    local artScale = ((uSettings and uSettings.portraitArtScale) or 100) / 100
    cScale = cScale * artScale
    local expand = (cScale - 1) * 0.5
    local oL = -(expand * bw)
    local oR =  (expand * bw)
    local oT =  (expand * bh2)
    local oB = -(expand * bh2)
    if backdrop._2d then
        backdrop._2d:ClearAllPoints()
        PP.Point(backdrop._2d, "TOPLEFT", backdrop, "TOPLEFT", oL, oT)
        PP.Point(backdrop._2d, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", oR, oB)
    end
    if backdrop._class then
        backdrop._class:ClearAllPoints()
        local classInset = math.floor(bh2 * 0.08)
        PP.Point(backdrop._class, "TOPLEFT", backdrop, "TOPLEFT", classInset + oL, -classInset + oT)
        PP.Point(backdrop._class, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -classInset + oR, classInset + oB)
    end
    if backdrop._3d then
        -- 3D models ignore SetClipsChildren and masks, so keep them within the
        -- backdrop bounds. A circular portrait shrinks the model so its
        -- corners end under the ring, which is drawn above it. Art scale is
        -- not applied to 3D (camera zoom is fixed).
        local ringSize = bh2 + 2 * bExp
        local nativeScale = backdrop._ktNativeClassificationScale or 1
        local modelInset = backdrop._ktNativeClassificationActive
            and (bh2 * ((1 - nativeScale) / 2 + 2 / 58 * nativeScale))
            or (isCircular and math.max(0, math.floor(bh2 * 0.5 - ringSize * 0.30 + 0.5)) or 0)
        backdrop._3d:SetFrameLevel(backdrop:GetFrameLevel() + 1)
        if backdrop._shapeBorderFrame then
            backdrop._shapeBorderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 3)
        end
        backdrop._3d:ClearAllPoints()
        PP.Point(backdrop._3d, "TOPLEFT", backdrop, "TOPLEFT", modelInset, -modelInset)
        PP.Point(backdrop._3d, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -modelInset, modelInset)
    end

    if backdrop._ktStockPortraitAnchor then
        KT:FitStockUFPortraitMask(backdrop)
    end

    if isCircular and not backdrop._ktStockPortraitAnchor then
        AnchorCircularPortrait(backdrop, uSettings, unitToken)
        C_Timer.After(0, function()
            if backdrop and not backdrop._ktStockPortraitAnchor
                and db and db.profile and db.profile.portraitStyle == "circular"
            then
                AnchorCircularPortrait(backdrop, uSettings, unitToken)
            end
        end)
    end
end

local function UpdateCircularPortraitBorder(frame)
    if not (frame and frame.Health and frame.Portrait and frame.Portrait.backdrop) then return end
    if not (db and db.profile and db.profile.portraitStyle == "circular") then return end

    local backdrop = frame.Portrait.backdrop
    if backdrop._ktStockPortraitAnchor then
        KT:FitStockUFPortraitMask(backdrop)
        if backdrop._shapeBorderTex then backdrop._shapeBorderTex:Hide() end
        return
    end

    local border = backdrop._shapeBorderTex
    if border then
        -- The elite/rare ring replaces the generic portrait border. Keeping
        -- both visible makes one unit look like two classifications at once.
        if frame._kuiClassificationIndicator and frame._kuiClassificationIndicator:IsShown() then
            border:Hide()
            return
        end
        local unitKey = UnitToSettingsKey(frame.unit)
        local settings = unitKey and db.profile[unitKey]
        local r, g, b = ResolveCircularPortraitColor(frame, settings, frame.unit)
        local opacity = ((settings and settings.detachedPortraitBorderOpacity) or 100) / 100
        border:SetVertexColor(r, g, b, opacity)
        border:Show()
    end
end

-- â”€â”€â”€ Bottom Text Bar: subsistema table-driven â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Slots de texto (izq/der/centro) definidos como descriptores para
-- iterar en creaciÃ³n/tags/posicionamiento en lugar de cÃ³digo manual.
local BTB_TEXT_SLOTS = {
    { id = "Left",   justify = "LEFT",   anchor = "LEFT",   xBase = 5  },
    { id = "Right",  justify = "RIGHT",  anchor = "RIGHT",  xBase = -5 },
    { id = "Center", justify = "CENTER", anchor = "CENTER", xBase = 0  },
}

-- Posiciones de icono de clase en el BTB
local BTB_ICON_ANCHORS = {
    center = { pt = "CENTER", ref = "CENTER", dx = 0  },
    right  = { pt = "RIGHT",  ref = "RIGHT",  dx = -3 },
    left   = { pt = "LEFT",   ref = "LEFT",   dx = 3  },
}

-- Resolver color de power para texto BTB cuando el contenido es power-related
local function ResolveBTBPowerTint(fs, contentKey, usePowerColor, unit)
    if not fs or not usePowerColor then return end
    if contentKey == "perpp" or contentKey == "curpp"
    or contentKey == "curhp_curpp" or contentKey == "perhp_perpp" then
        local pType = UnitPowerType(unit)
        local info = PowerBarColor[pType]
        if info then fs:SetTextColor(info.r, info.g, info.b) end
    end
end

local function CreateBottomTextBar(frame, unit, settings, anchorFrame, xOffset, overrideWidth)
    local btbH = settings.bottomTextBarHeight or 16
    local btbPos = settings.btbPosition or "bottom"
    local isDetached = (btbPos == "detached_top" or btbPos == "detached_bottom")
    local btbW = isDetached and (settings.btbWidth or 0) or 0
    local totalWidth = (btbW > 0 and isDetached) and btbW or (overrideWidth or settings.frameWidth)

    local btb = CreateFrame("Frame", nil, frame)
    PP.Size(btb, totalWidth, btbH)

    -- Anclar BTB segÃºn la posiciÃ³n configurada
    if btbPos == "top" then
        PP.Point(btb, "BOTTOMLEFT", frame.Health or anchorFrame, "TOPLEFT", xOffset or 0, 0)
    elseif btbPos == "detached_top" then
        btb:SetPoint("BOTTOM", frame, "TOP", settings.btbX or 0, 15 + (settings.btbY or 0))
    elseif btbPos == "detached_bottom" then
        btb:SetPoint("TOP", frame, "BOTTOM", settings.btbX or 0, -15 + (settings.btbY or 0))
    else
        PP.Point(btb, "TOPLEFT", anchorFrame, "BOTTOMLEFT", xOffset or 0, 0)
    end

    -- Fondo del BTB
    local bgc = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
    local bg = btb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(bgc.r, bgc.g, bgc.b, settings.btbBgOpacity or 1.0)
    btb.bg = bg

    -- Overlay de texto: 3 slots creados desde BTB_TEXT_SLOTS
    local textOvr = CreateFrame("Frame", nil, btb)
    textOvr:SetAllPoints()
    textOvr:SetFrameLevel(btb:GetFrameLevel() + 2)
    btb._textOverlay = textOvr

    local slotFS = {}
    for _, slot in ipairs(BTB_TEXT_SLOTS) do
        local fs = textOvr:CreateFontString(nil, "OVERLAY")
        SetFSFont(fs, settings["btb" .. slot.id .. "Size"] or 11)
        fs:SetWordWrap(false)
        fs:SetTextColor(1, 1, 1)
        btb[slot.id .. "Text"] = fs
        slotFS[slot.id] = fs
    end

    -- Aplicar oUF tags a los 3 slots iterando descriptores
    local function ApplyBTBTextTags(lc, rc, cc)
        local vals = { Left = lc, Right = rc, Center = cc }
        for _, slot in ipairs(BTB_TEXT_SLOTS) do
            local fs = slotFS[slot.id]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(vals[slot.id])
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end

    -- Posicionar y estilizar texto desde configuraciÃ³n, iterando slots
    local function ApplyBTBTextPositions(s)
        for _, slot in ipairs(BTB_TEXT_SLOTS) do
            local fs = slotFS[slot.id]
            local content = s["btb" .. slot.id .. "Content"] or "none"
            SetFSFont(fs, s["btb" .. slot.id .. "Size"] or 11)
            fs:ClearAllPoints()
            if content ~= "none" then
                fs:SetJustifyH(slot.justify)
                PP.Point(fs, slot.anchor, textOvr, slot.anchor,
                    slot.xBase + (s["btb" .. slot.id .. "X"] or 0),
                    s["btb" .. slot.id .. "Y"] or 0)
                fs:Show()
            else
                fs:Hide()
            end
            -- Color de clase y de poder aplicados por slot
            ApplyClassColor(fs, unit, s["btb" .. slot.id .. "ClassColor"])
            ResolveBTBPowerTint(fs, content,
                s["btb" .. slot.id .. "PowerColor"], unit)
        end
    end

    ApplyBTBTextTags(
        settings.btbLeftContent or "none",
        settings.btbRightContent or "none",
        settings.btbCenterContent or "none"
    )
    ApplyBTBTextPositions(settings)
    btb._applyBTBTextTags = ApplyBTBTextTags
    btb._applyBTBTextPositions = ApplyBTBTextPositions

    -- Icono de clase sobre el BTB (overlay de alto nivel)
    local classIconHolder = CreateFrame("Frame", nil, frame)
    classIconHolder:SetAllPoints(textOvr)
    classIconHolder:SetFrameLevel(frame:GetFrameLevel() + 2)
    local classIconTex = classIconHolder:CreateTexture(nil, "ARTWORK")
    classIconTex:SetTexCoord(0, 1, 0, 1)
    classIconTex:Hide()
    btb.ClassIcon = classIconTex

    local function ApplyBTBClassIcon(s)
        local style = s.btbClassIcon or "none"
        if style == "none" then classIconTex:Hide(); return end
        local classToken = ResolveSafeClassToken(unit)
        if not classToken or not ApplyClassIconTexture(classIconTex, classToken, style) then
            classIconTex:Hide(); return
        end
        PP.Size(classIconTex, s.btbClassIconSize or 14, s.btbClassIconSize or 14)
        classIconTex:ClearAllPoints()
        local a = BTB_ICON_ANCHORS[s.btbClassIconLocation or "left"]
            or BTB_ICON_ANCHORS.left
        PP.Point(classIconTex, a.pt, textOvr, a.ref,
            a.dx + (s.btbClassIconX or 0), s.btbClassIconY or 0)
        classIconTex:Show()
    end

    ApplyBTBClassIcon(settings)
    btb._applyBTBClassIcon = ApplyBTBClassIcon

    return btb
end

-- SetFrameMovable removed â€” positioning is now handled by Unlock Mode

local function ApplyFramePosition(frame, unit)
    if not frame or not db.profile.positions[unit] then return end
    local pos = db.profile.positions[unit]
    frame:ClearAllPoints()
    
    -- Calculate dynamic X position for target frame to prevent CDM overlap
    local x = pos.x
    if unit == "target" and pos.point == "CENTER" then
        -- Check if target portrait is visible
        local portraitStyle = db.profile.portraitStyle or "attached"
        local targetSettings = db.profile.target or {}
        local targetPortraitVisible = portraitStyle ~= "none" and targetSettings.showPortrait ~= false
        
        -- Check if player portrait is on the right side (extends player frame rightward)
        local playerSettings = db.profile.player or {}
        local playerPortraitRight = (playerSettings.portraitSide or "left") == "right" and
                                    portraitStyle ~= "none" and
                                    playerSettings.showPortrait ~= false
        
        -- If either condition is true, add extra offset to prevent overlap
        if targetPortraitVisible or playerPortraitRight then
            -- Base position after migration is 280
            -- Calculate additional offset based on portrait configuration
            local basePos = 280
            local additionalOffset = 20  -- Base margin to prevent overlap

            if portraitStyle == "circular" then
                additionalOffset = additionalOffset + 10  -- Extra space for circular portraits
            elseif portraitStyle == "attached" then
                additionalOffset = additionalOffset + 5   -- Moderate space for attached portraits
            end

            -- This margin was tuned against the module's OLD 100% default
            -- frame scale. frame.Buffs anchors to frame.Health and the whole
            -- target frame now gets a real SetScale() centered on itself
            -- (ApplyFrameScaleCentered) driven by frameScale -- now 132 by
            -- default (PLAYER_TARGET_FRAME_SCALE in
            -- Adapters/UnitFrames.lua). Scaling around the center pushes the
            -- outermost elements (buffs, furthest from center) outward the
            -- most, straight toward CDM, while this margin stayed fixed, so
            -- buffs crept almost into CDM. Scale the margin with the same
            -- factor so clearance keeps pace with frame size.
            if ns.BarGloss and ns.BarGloss.IsStyledLook and ns.BarGloss.IsStyledLook() then
                local targetScale = (targetSettings.frameScale or 100) / 100
                additionalOffset = additionalOffset * targetScale
            end

            -- Only apply offset if we're at or near the default position
            if x >= 270 and x <= 290 then
                x = basePos + additionalOffset
            end
        end
    end
    
    frame:SetPoint(pos.point, UIParent, pos.point, x, pos.y)
end

-- Recalculate all element sizes after frame scale changes so everything remains
-- pixel-perfect within the border.  PixelUtil rounds each element independently,
-- which can cause their sum to exceed the frame's snapped total by 1px at certain
-- scales.  After re-snapping each element we check for overflow and trim the last
-- element in the stack so everything fits exactly inside the border.
local function UpdateBordersForScale(frame, unit)
    if not frame then return end
    local settings = GetSettingsForUnit(unit)
    if not settings then return end
    local borderSize = settings.borderSize or 1

    -- 1) Main frame border textures
    if frame.unifiedBorder then
        PP.SetBorderSize(frame.unifiedBorder, borderSize)
    end

    -- Forever/Classic real stock geometry (ApplyClassicFrameArt, called from
    -- CreateUnifiedBorder immediately before this function runs at every
    -- call site) already sized frame/portrait/health/power correctly. Steps
    -- 2-8 below assume KUI's NORMAL (unthemed) layout model and unconditionally
    -- re-derive those same sizes from it: Health's width would match the
    -- full frame width (this function's own TOPLEFT+RIGHT dual anchor, which
    -- derives size from the frame's edges) instead of the real ~123px
    -- bar-track width, despite _ktForeverLayoutActive being true, silently
    -- undoing the real geometry every time it ran after it.
    if frame._ktForeverLayoutActive or frame._ktClassicLayoutActive then
        return
    end

    -- 2) Gather layout info
    local ppPos = settings.powerPosition or "below"
    local ppIsAtt = (ppPos == "below" or ppPos == "above")
    local ppIsDet = (ppPos == "detached_top" or ppPos == "detached_bottom")
    local ph = settings.powerHeight or 6
    -- Simple frames (pet/tot/focustarget) have no power bar ? skip power height
    local isMini = (unit == "targettarget" or unit == "focustarget")
    local powerH = (ppIsAtt and not isMini) and ph or 0

    local btbPos = settings.btbPosition or "bottom"
    local btbIsAtt = (btbPos == "top" or btbPos == "bottom")
    local btbH = (settings.bottomTextBar and btbIsAtt) and (settings.bottomTextBarHeight or 16) or 0

    local showPortrait = settings.showPortrait ~= false
    local isAttached = (db.profile.portraitStyle or "attached") == "attached"
    local pSide = settings.portraitSide or "right"
    local effectiveSide = pSide
    if isAttached and pSide == "top" then effectiveSide = "right" end

    -- Class power above adds height (player only)
    local cpAboveH = 0
    if unit == "player" then
        local cpSt = settings.classPowerStyle or "none"
        local cpPo = (cpSt == "modern") and (settings.classPowerPosition or "top") or "none"
        if cpSt == "modern" and cpPo == "above" then
            local cpSizeAdj = settings.classPowerSize or 8
            cpAboveH = math.max(3, math.floor(cpSizeAdj * 0.375))
        end
    end

    local barHeight = settings.healthHeight + powerH + cpAboveH
    local expectedFrameH = barHeight + btbH
    local pSizeAdj = settings.portraitSize or 0
    if not isAttached then pSizeAdj = pSizeAdj + 10 end
    local adjPortraitH = barHeight + pSizeAdj
    if adjPortraitH < 8 then adjPortraitH = 8 end

    local expectedFrameW
    if not showPortrait or not isAttached then
        expectedFrameW = settings.frameWidth
    else
        expectedFrameW = adjPortraitH + settings.frameWidth
    end

    -- 3) Re-snap the frame itself
    PP.Size(frame, expectedFrameW, expectedFrameH)
    local snappedFrameW = frame:GetWidth()
    local snappedFrameH = frame:GetHeight()

    -- 4) Re-snap portrait and health bar (width axis)
    local healthTargetW = settings.frameWidth
    if frame.Portrait and frame.Portrait.backdrop and showPortrait and isAttached then
        PP.Size(frame.Portrait.backdrop, adjPortraitH, adjPortraitH)
        local snappedPortW = frame.Portrait.backdrop:GetWidth()
        local snappedPortH = frame.Portrait.backdrop:GetHeight()
        -- Trim portrait width if it + health would exceed frame
        if snappedPortW + healthTargetW > snappedFrameW + 0.01 then
            PP.Width(frame.Portrait.backdrop, snappedFrameW - healthTargetW)
            snappedPortW = frame.Portrait.backdrop:GetWidth()
        end
        -- Trim portrait height to frame height if it overflows
        if snappedPortH > snappedFrameH + 0.01 then
            PP.Height(frame.Portrait.backdrop, snappedFrameH)
        end
    end

    -- 5) Re-snap health bar height and re-anchor to snapped portrait width
    if frame.Health then
        PP.Height(frame.Health, settings.healthHeight)
        -- Re-anchor health bar so it's flush against the snapped portrait edge
        if showPortrait and isAttached and frame.Portrait and frame.Portrait.backdrop then
            local snappedPortW = frame.Portrait.backdrop:GetWidth()
            local newXOff = (effectiveSide == "left") and snappedPortW or 0
            local newRightInset = (effectiveSide == "right") and snappedPortW or 0
            local topOff = frame.Health._topOffset or 0
            frame.Health:ClearAllPoints()
            PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", newXOff, -topOff)
            PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -newRightInset, 0)
            PP.Height(frame.Health, settings.healthHeight)
            frame.Health._xOffset = newXOff
            frame.Health._rightInset = newRightInset
        end
    end

    -- 6) Re-snap power bar
    if frame.Power and ppPos ~= "none" then
        local pw = settings.frameWidth
        if ppIsDet and (settings.powerWidth or 0) > 0 then
            pw = settings.powerWidth
        end
        PP.Size(frame.Power, pw, ph)
        if ppIsAtt and frame.Health then
            -- Height: ensure health + power don't exceed the bar area
            local snappedHealthH = frame.Health:GetHeight()
            local snappedPowerH = frame.Power:GetHeight()
            local expectedBarH = settings.healthHeight + ph
            if snappedHealthH + snappedPowerH > expectedBarH + 0.01 then
                PP.Height(frame.Power, snappedPowerH - (snappedHealthH + snappedPowerH - expectedBarH))
            end
            -- Width: match health bar width exactly
            local snappedHealthW = frame.Health:GetWidth()
            local snappedPowerW = frame.Power:GetWidth()
            if math.abs(snappedPowerW - snappedHealthW) > 0.01 then
                PP.Width(frame.Power, snappedHealthW)
            end
        elseif not ppIsDet then
            -- Non-attached non-detached shouldn't happen, but trim width to frame
            local snappedPowerW = frame.Power:GetWidth()
            if snappedPowerW > snappedFrameW + 0.01 then
                PP.Width(frame.Power, snappedFrameW)
            end
        end
    end

    -- 7) Re-snap BTB
    if frame.BottomTextBar and settings.bottomTextBar and btbIsAtt then
        PP.Size(frame.BottomTextBar, expectedFrameW, settings.bottomTextBarHeight or 16)
        local snappedBtbW = frame.BottomTextBar:GetWidth()
        local snappedBtbH = frame.BottomTextBar:GetHeight()
        -- Width: trim to frame width
        if snappedBtbW > snappedFrameW + 0.01 then
            PP.Width(frame.BottomTextBar, snappedFrameW)
        end
        -- Height: ensure full stack fits within frame height
        local usedH = cpAboveH
        if frame.Health then usedH = usedH + frame.Health:GetHeight() end
        if frame.Power and ppIsAtt then usedH = usedH + frame.Power:GetHeight() end
        if usedH + snappedBtbH > snappedFrameH + 0.01 then
            PP.Height(frame.BottomTextBar, snappedBtbH - (usedH + snappedBtbH - snappedFrameH))
        end
    end

    -- 8) Castbar: re-snap background width + border textures
    if frame.Castbar then
        local castbarBg = frame.Castbar:GetParent()
        if castbarBg then
            -- Trim castbar bg width to match frame width
            local cbW = castbarBg:GetWidth()
            if cbW > snappedFrameW + 0.01 then
                PP.Width(castbarBg, snappedFrameW)
            end
            -- Re-snap border textures
            if castbarBg._ppBorders then
                PP.SetBorderSize(castbarBg, 1)
                frame.Castbar:ClearAllPoints()
                PP.Point(frame.Castbar, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
                PP.Point(frame.Castbar, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
            end
        end
    end
end

-- Snap a requested frame scale to the nearest pixel-perfect value.
-- 768 / physicalHeight gives the scale where
-- 1 logical pixel = 1 physical pixel.  We snap the frame scale so that the
-- combined effective scale (UIParent ES * frameScale) is a multiple of that
-- base pixel size, ensuring all PixelUtil sizes land on exact physical pixels.
local function SnapScaleToPixel(requestedScale)
    local _, physH = GetPhysicalScreenSize()
    if not physH or physH == 0 then return requestedScale end
    local pixelSize = 768 / physH  -- 1 physical pixel in UI points
    local parentES = UIParent:GetEffectiveScale()
    if parentES == 0 then return requestedScale end
    -- The combined effective scale
    local rawES = parentES * requestedScale
    -- Snap to nearest multiple of pixelSize
    local snapped = math.floor(rawES / pixelSize + 0.5) * pixelSize
    if snapped < pixelSize then snapped = pixelSize end
    return snapped / parentES
end

-- Smoothly animate frame scale from center point.
-- Apply scale immediately on init, then animate later changes while keeping the
-- visual center anchored to the saved point.
local SCALE_ANIM_DURATION = 0.18
local function ApplyFrameScaleCentered(frame, unit, newScale, animate)
    if not frame then return end
    local oldScale = frame._kuiCurrentScale or frame:GetScale()

    if frame._kuiScaleAnimating then
        frame._kuiCurrentScale = frame:GetScale()
        oldScale = frame._kuiCurrentScale
        frame:SetScript("OnUpdate", frame._kuiPrevOnUpdate)
        frame._kuiScaleAnimating = nil
        frame._kuiPrevOnUpdate = nil
    end

    -- Compute the new anchor offset needed to keep the visual center fixed
    -- when scale changes from s1 to s2.
    -- WoW multiplies SetPoint offsets by the frame's scale to get screen position.
    -- For anchor "TOPLEFT" with offset (ox, oy):
    --   screen_left = ox * scale,  screen_top = oy * scale
    --   screen_center_x = ox * scale + width * scale / 2
    -- To keep center fixed: newOx * s2 + w*s2/2 = ox * s1 + w*s1/2
    --   newOx = ox * s1/s2 + w * (s1 - s2) / (2 * s2)
    local function ComputeNewOffset(frm, s1, s2, unitKey)
        if not db.profile.positions[unitKey] then return nil end
        local pos = db.profile.positions[unitKey]
        local ox, oy = pos.x, pos.y
        local w = frm:GetWidth()
        local h = frm:GetHeight()
        local ratio = s1 / s2
        local pt = pos.point

        local newOx, newOy = ox * ratio, oy * ratio

        -- Horizontal center compensation
        local halfWDelta = w * (s1 - s2) / (2 * s2)
        if pt == "TOPLEFT" or pt == "LEFT" or pt == "BOTTOMLEFT" then
            newOx = newOx + halfWDelta
        elseif pt == "TOPRIGHT" or pt == "RIGHT" or pt == "BOTTOMRIGHT" then
            newOx = newOx - halfWDelta
        end
        -- TOP/BOTTOM/CENTER horizontal anchors are already centered, no x adjustment

        -- Vertical center compensation
        local halfHDelta = h * (s1 - s2) / (2 * s2)
        if pt == "TOPLEFT" or pt == "TOP" or pt == "TOPRIGHT" then
            newOy = newOy - halfHDelta
        elseif pt == "BOTTOMLEFT" or pt == "BOTTOM" or pt == "BOTTOMRIGHT" then
            newOy = newOy + halfHDelta
        end
        -- LEFT/RIGHT/CENTER vertical anchors are already centered, no y adjustment

        return newOx, newOy
    end

    local function ApplyScaleAndReposition(frm, sc, unitKey)
        local prevScale = frm:GetScale()
        if math.abs(sc - prevScale) < 0.0001 then return end
        local newOx, newOy = ComputeNewOffset(frm, prevScale, sc, unitKey)
        frm:SetScale(sc)
        if newOx and db.profile.positions[unitKey] then
            local pos = db.profile.positions[unitKey]
            pos.x = newOx
            pos.y = newOy
            frm:ClearAllPoints()
            frm:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        end
    end

    if not animate or math.abs(newScale - oldScale) < 0.001 then
        if animate and math.abs(newScale - oldScale) < 0.0001 then
            return
        end
        -- On init (animate=false), just apply scale and re-anchor from saved
        -- position without recomputing offsets. The saved position is already
        -- correct for the saved scale; recomputing would displace the frame.
        if not animate then
            frame:SetScale(newScale)
            ApplyFramePosition(frame, unit)
        else
            ApplyScaleAndReposition(frame, newScale, unit)
        end
        frame._kuiCurrentScale = newScale
        UpdateBordersForScale(frame, unit)
        return
    end

    local elapsed = 0
    local startScale = oldScale
    local endScale = newScale
    frame._kuiPrevOnUpdate = frame:GetScript("OnUpdate")
    frame._kuiScaleAnimating = true

    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = elapsed / SCALE_ANIM_DURATION
        if t >= 1 then t = 1 end
        local eased = 1 - (1 - t) * (1 - t)
        local curScale = startScale + (endScale - startScale) * eased
        ApplyScaleAndReposition(self, curScale, unit)

        if t >= 1 then
            self._kuiCurrentScale = endScale
            self:SetScript("OnUpdate", self._kuiPrevOnUpdate)
            self._kuiScaleAnimating = nil
            self._kuiPrevOnUpdate = nil
            UpdateBordersForScale(self, unit)
        end
    end)
end

-- ToggleLock removed â€” positioning is now handled by Unlock Mode

-- fakeFrames / CreateFakeFrame / ShowFakeFrames / HideFakeFrames removed
-- Positioning is now handled exclusively by Unlock Mode

local function GetFrameDimensions(unit)
    local settings = GetSettingsForUnit(unit)
    local pStyle = db.profile.portraitStyle or "attached"
    local showPortrait = pStyle ~= "none" and settings.showPortrait ~= false
    local isAttached = pStyle == "attached"

    -- Unidades simplificadas: sin poder ni BTB
    if unit == "pet" or unit == "targettarget" or unit == "focustarget" then
        return settings.frameWidth, settings.healthHeight
    end

    local powerPos = settings.powerPosition or "below"
    local powerIsAtt = (powerPos == "below" or powerPos == "above")
    local pSizeAdj = (settings.portraitSize or 0) + (isAttached and 0 or 10)

    -- CÃ¡lculo comÃºn de barH (vida + poder adosado)
    local powerH = powerIsAtt and (settings.powerHeight or 6) or 0
    local barH = settings.healthHeight + powerH

    -- BTB solo afecta unidades principales (no boss)
    local btbPos = settings.btbPosition or "bottom"
    local btbIsAtt = (btbPos == "top" or btbPos == "bottom")
    local btbH = 0
    if unit == "player" or unit == "target" or unit == "focus" then
        btbH = (settings.bottomTextBar and btbIsAtt) and (settings.bottomTextBarHeight or 16) or 0
    end

    -- Ancho: portrait adosado â†’ extender por su tamaÃ±o ajustado
    local adjPH = math.max(barH + pSizeAdj, 8)
    local w = (showPortrait and isAttached) and (adjPH + settings.frameWidth) or settings.frameWidth

    -- Player/target: ajustar lado del retrato
    if unit == "player" or unit == "target" then
        local pSide = settings.portraitSide or (unit == "player" and "left" or "right")
        if isAttached and pSide == "top" then pSide = (unit == "player") and "left" or "right" end
    end

    return w, barH + btbH
end

-- ShowFakeFrames / HideFakeFrames removed â€” Unlock Mode handles all positioning

-- "Smooth" option, on by default for every profile/style, that animates
-- health/power bar value changes instead of jumping instantly. Wraps the
-- bar's own SetValue so it works regardless of who calls it (oUF's
-- built-in Health/Power elements included) -- the wrapper reads
-- db.profile.smoothBars on every call, so toggling the setting takes
-- effect immediately without needing to recreate the bar.
function KT:ComputeSmoothStep(self, value)
    value = tonumber(value) or 0
    local current = tonumber(self:GetValue()) or value
    return value, current, math.abs(current - value) < 0.01
end

-- Driven by OnUpdate, not C_Timer.NewTicker(0.016, ...): a ticker that
-- advances its internal "elapsed" by a fixed 0.016 every call regardless
-- of how much real wall-clock time actually passed drifts and stutters --
-- C_Timer tickers are scheduled relative to game ticks and are not
-- guaranteed to fire at a precise, consistent sub-frame interval. An
-- OnUpdate script on the bar itself receives the REAL elapsed time for
-- that exact frame as its argument, which is the standard, reliable WoW
-- technique for frame-accurate animation (matches the display's own
-- refresh rate instead of a guessed fixed step).
function KT:ApplySmoothBar(bar)
    if not bar or bar._ktSmoothApplied then return end
    bar._ktSmoothApplied = true
    local realSetValue = bar.SetValue
    bar.SetValue = function(self, value, ...)
        if bar._ktSmoothBlocked or not (db and db.profile and db.profile.smoothBars ~= false) then
            -- Smoothing off (default): plain SetValue. Only stop our own tween,
            -- never an OnUpdate script someone else installed on the bar.
            if self._ktSmoothTarget ~= nil then
                self._ktSmoothTarget = nil
                self:SetScript("OnUpdate", nil)
            end
            realSetValue(self, value, ...)
            return
        end
        -- Preferred path: the client's own StatusBar interpolation. It is
        -- frame-accurate and, unlike the Lua tween below, also works with
        -- "secret" values (which forbid arithmetic and used to force an
        -- instant, choppy jump). Only used when the client exposes the enum.
        local interp = Enum and Enum.StatusBarInterpolation
            and (Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Linear)
        if interp and not bar._ktNativeSmoothFailed then
            self:SetScript("OnUpdate", nil)
            if pcall(realSetValue, self, value, interp) then
                return
            end
            bar._ktNativeSmoothFailed = true
        end
        -- Some power values (certain class resources) arrive as WoW's
        -- "secret" values, which forbid arithmetic entirely ("a secret
        -- number value, while execution tainted") -- tonumber() and type()
        -- both happily pass a secret number through as a normal number, so
        -- the only way to detect it is to let the arithmetic itself fail
        -- inside a pcall. It fails identically on every future call for
        -- this bar, so block smoothing on it permanently instead of
        -- erroring on every value update.
        local ok, value2, current, closeEnough = pcall(KT.ComputeSmoothStep, KT, self, value)
        if not ok then
            bar._ktSmoothBlocked = true
            self:SetScript("OnUpdate", nil)
            realSetValue(self, value)
            return
        end
        self._ktSmoothTarget = value2
        if closeEnough then
            self:SetScript("OnUpdate", nil)
            realSetValue(self, value2)
            return
        end
        self._ktSmoothStart = current
        self._ktSmoothElapsed = 0
        self:SetScript("OnUpdate", function(selfBar, elapsedTime)
            selfBar._ktSmoothElapsed = selfBar._ktSmoothElapsed + elapsedTime
            local t = math.min(selfBar._ktSmoothElapsed / 0.25, 1)
            local eased = 1 - (1 - t) * (1 - t)
            realSetValue(selfBar, selfBar._ktSmoothStart
                + (selfBar._ktSmoothTarget - selfBar._ktSmoothStart) * eased)
            if t >= 1 then
                selfBar:SetScript("OnUpdate", nil)
            end
        end)
    end
end

local function CreateHealthBar(frame, unit, height, xOffset, settings, rightInset)
    xOffset     = xOffset or 0
    rightInset  = rightInset or 0
    height      = height or settings.healthHeight

    -- Desplazamiento vertical si el poder estÃ¡ encima de la vida
    local ppPos = settings.powerPosition or "below"
    local aboveOff = ppPos == "above" and (settings.powerHeight or 0) or 0

    local settingsKey = UnitToSettingsKey(unit)
    local strata = frame:GetFrameStrata()
    local level  = frame:GetFrameLevel() + 2

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetFrameStrata(strata)
    health:SetFrameLevel(level)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    health:GetStatusBarTexture():SetHorizTile(false)

    -- Anclaje en dos puntos: el ancho se deriva del padre,
    -- inmune a errores de redondeo de pixel-snapping
    PP.Point(health, "TOPLEFT", frame, "TOPLEFT", xOffset, -aboveOff)
    PP.Point(health, "RIGHT", frame, "RIGHT", -rightInset, 0)
    PP.Height(health, height)

    -- Guardar offsets para reposicionamiento posterior (class power, SnapLayout)
    health._xOffset     = xOffset
    health._rightInset  = rightInset
    health._topOffset   = aboveOff
    health._kuiUnitKey  = settingsKey

    -- Flags de color para oUF
    health.colorClass        = true
    health.colorReaction     = true
    health.colorTapped       = true
    health.colorDisconnected = true

    -- Fondo semitransparente
    local bg = health:CreateTexture(nil, "BACKGROUND")
    PP.Point(bg, "TOPLEFT", health)
    PP.Point(bg, "BOTTOMRIGHT", health)
    bg:SetColorTexture(0, 0, 0, 0.5)
    health.bg = bg

    -- Aplicar textura, opacidad y tema oscuro
    ApplyHealthBarTexture(health, settingsKey)
    ApplyHealthBarAlpha(health, settingsKey)
    ApplyDarkTheme(health)
    KT:ApplySmoothBar(health)

    return health
end

-- Textura fija del escudo de absorciÃ³n
local function ApplyAbsorbBarStyle(frame, settings)
    local shield = frame and frame.HealthPrediction and frame.HealthPrediction.damageAbsorb
    if not shield then
        return
    end

    local texKey = settings and settings.absorbBarTexture or DEFAULT_ABSORB_TEXTURE
    local texturePath = ResolveSharedTexturePath(texKey, DEFAULT_ABSORB_TEXTURE)
    if texturePath then
        shield:SetStatusBarTexture(texturePath)
    else
        shield:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    end

    local fill = shield:GetStatusBarTexture()
    if fill then
        UnsnapTex(fill)
    end

    local r, g, b, a = ResolveAbsorbBarColor(settings)
    shield:SetStatusBarColor(r, g, b, a)
end

local function CreateAbsorbBar(frame, unit, settings)
    local hpBar = frame.Health
    if not hpBar then return end

    -- Habilitar recorte para que el escudo no sobresalga del health bar
    hpBar:SetClipsChildren(true)

    -- Referencia al fill de vida para anclar el shield por la derecha
    local fillRef = hpBar:GetStatusBarTexture()

    local shield = CreateFrame("StatusBar", nil, hpBar)
    shield:SetReverseFill(true)
    shield:SetPoint("TOPRIGHT", fillRef, "TOPRIGHT", 0, 0)
    shield:SetPoint("BOTTOMRIGHT", fillRef, "BOTTOMRIGHT", 0, 0)
    shield:SetWidth(settings.frameWidth)
    shield:SetHeight(settings.healthHeight)
    shield:Show()

    -- Registrar como predicciÃ³n de absorciÃ³n para oUF
    frame.HealthPrediction = {
        damageAbsorb          = shield,
        damageAbsorbClampMode = 2,
    }
    ApplyAbsorbBarStyle(frame, settings)
    return shield
end

-- â”€â”€â”€ Tabla de anclaje para posiciÃ³n del texto de poder â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local PP_TEXT_ANCHORS = {
    left   = { justify = "LEFT",   pt = "LEFT",   ref = "LEFT",   dx = 2  },
    right  = { justify = "RIGHT",  pt = "RIGHT",  ref = "RIGHT",  dx = -2 },
    center = { justify = "CENTER", pt = "CENTER", ref = "CENTER", dx = 0  },
}

-- Resolver tag de oUF para el texto de poder segÃºn formato
local function BuildPowerTag(fmt, pctSuffix)
    if fmt == "curpp" then
        if ns.UsesModernNumbers() then return "[kui-ppfull]" end
        return "[" .. SMART_POWER_CURRENT_TAG .. "]"
    elseif fmt == "both" then
        return "[" .. SMART_POWER_CURRENT_TAG .. "] | ["
            .. SMART_POWER_PERCENT_TAG .. "]" .. pctSuffix
    elseif fmt == "smart" then
        if ShouldUseSmartPowerPercent() then
            return "[" .. SMART_POWER_PERCENT_TAG .. "]" .. pctSuffix
        end
        return "[" .. SMART_POWER_CURRENT_TAG .. "]"
    end
    -- "perpp" por defecto
    return "[" .. SMART_POWER_PERCENT_TAG .. "]" .. pctSuffix
end

-- oUF's Power colour step indexes its colour tables with the unit's power token and
-- type. In combat those can be secret for an enemy, which aborts the step and
-- leaves the white fill texture uncoloured (a full white bar on enemies that are
-- recharging rage or have no resource). Same rules as oUF, guarded against
-- secrets, and never leaving the default white fill.
function ns.PowerSafeUpdateColor(self, event, unit)
    if self.unit ~= unit then return end
    local element = self.Power
    if element.__texture then element:SetStatusBarTexture(element.__texture) end
    local tex = element:GetStatusBarTexture()
    if not tex then return end
    local function secret(v) return issecretvalue and issecretvalue(v) end
    local color, r, g, b
    if element.colorPower then
        if element.displayType and not secret(element.displayType) then
            color = self.colors.power[element.displayType]
        end
        if not color then
            local ok, pType, pToken, altR, altG, altB = pcall(UnitPowerType, unit)
            if ok then
                if pToken and not secret(pToken) then color = self.colors.power[pToken] end
                if not color and type(altR) == "number" and not secret(altR) then
                    r, g, b = altR, altG, altB
                    if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
                elseif not color and pType and not secret(pType) then
                    color = self.colors.power[pType]
                end
            end
            if not color and not r then color = self.colors.power.MANA end
        end
        if r then
            tex:SetVertexColor(r, g, b)
        elseif color then
            tex:SetVertexColor(color:GetRGB())
        end
    end
    if element.PostUpdateColor then element:PostUpdateColor(unit, color, r, g, b) end
end

local function CreatePowerBar(frame, unit, settings)
    local powerPos = settings.powerPosition or "below"
    local isDetached = (powerPos == "detached_top" or powerPos == "detached_bottom")

    -- Calcular ancho: usa powerWidth si estÃ¡ separado, si no frameWidth
    local pw = settings.frameWidth
    if isDetached and (settings.powerWidth or 0) > 0 then
        pw = settings.powerWidth
    end

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetFrameStrata(frame:GetFrameStrata())
    power:SetFrameLevel(frame:GetFrameLevel() + 3)
    PP.Size(power, pw, settings.powerHeight)

    -- Anclar power bar segÃºn posiciÃ³n configurada
    if powerPos == "none" then
        power:Hide()
    elseif powerPos == "above" then
        PP.Point(power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
        PP.Point(power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
    elseif powerPos == "detached_top" then
        power:SetPoint("BOTTOM", frame.Health, "TOP",
            settings.powerX or 0, 15 + (settings.powerY or 0))
    elseif powerPos == "detached_bottom" then
        power:SetPoint("TOP", frame.Health, "BOTTOM",
            settings.powerX or 0, -15 + (settings.powerY or 0))
    else
        PP.Point(power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
        PP.Point(power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
    end

    power.UpdateColor = ns.PowerSafeUpdateColor

    -- Textura de relleno y fondo
    power:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    power:GetStatusBarTexture():SetHorizTile(false)
    do
        local pFill = power:GetStatusBarTexture()
        if pFill then UnsnapTex(pFill) end
    end

    local bgColor = settings.customPowerBgColor
        or { r = 17/255, g = 17/255, b = 17/255 }
    local bg = power:CreateTexture(nil, "BACKGROUND")
    PP.Point(bg, "TOPLEFT", power, "TOPLEFT", 0, 0)
    PP.Point(bg, "BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, 1)
    UnsnapTex(bg)
    power.bg = bg

    -- Color de relleno: por tipo de poder o color fijo personalizado
    local usePowerColor = settings.powerPercentPowerColor ~= false
    if usePowerColor then
        power.colorPower = true
    else
        power.colorPower = false
        local customFill = settings.customPowerFillColor
        if customFill then
            power:SetStatusBarColor(customFill.r, customFill.g, customFill.b)
            power.PostUpdateColor = function(self)
                local s2 = GetSettingsForUnit(unit)
                local cf = s2 and s2.customPowerFillColor
                if cf then self:SetStatusBarColor(cf.r, cf.g, cf.b) end
            end
        else
            power:SetStatusBarColor(0, 0, 1)
            power.PostUpdateColor = function(self)
                self:SetStatusBarColor(0, 0, 1)
            end
        end
    end

    -- Fondo personalizado (puede sobreescribir el default)
    if settings.customPowerBgColor then
        bg:SetColorTexture(settings.customPowerBgColor.r,
            settings.customPowerBgColor.g, settings.customPowerBgColor.b, 1)
    end

    -- Overlay y texto de porcentaje de poder
    local ppTextOvr = CreateFrame("Frame", nil, power)
    ppTextOvr:SetAllPoints(power)
    ppTextOvr:SetFrameLevel(frame:GetFrameLevel() + 11)
    local ppFS = ppTextOvr:CreateFontString(nil, "OVERLAY")
    SetFSFont(ppFS, settings.powerPercentSize or 9)
    ppFS:Hide()
    power._ppFS = ppFS
    power._ppTextOvr = ppTextOvr

    -- Aplicar texto de porcentaje con posiciÃ³n y formato configurables
    local function ApplyPowerPercentText(s)
        local pos = s.powerPercentText or "none"
        SetFSFont(ppFS, s.powerPercentSize or 9)
        ppFS:ClearAllPoints()

        if pos == "none" then
            ppFS:Hide()
            if ppFS._curTag then frame:Untag(ppFS); ppFS._curTag = nil end
            return
        end

        -- Posicionar con la tabla de anclas
        local anchor = PP_TEXT_ANCHORS[pos] or PP_TEXT_ANCHORS.center
        ppFS:SetJustifyH(anchor.justify)
        PP.Point(ppFS, anchor.pt, ppTextOvr, anchor.ref,
            anchor.dx + (s.powerPercentX or 0), s.powerPercentY or 0)

        -- Tag de oUF segÃºn formato elegido
        if ppFS._curTag then frame:Untag(ppFS); ppFS._curTag = nil end
        local showPct = s.powerShowPercent ~= false
        local pctSuffix = showPct and "%" or ""
        local tag = BuildPowerTag(s.powerTextFormat or "perpp", pctSuffix)
        frame:Tag(ppFS, tag); ppFS._curTag = tag
        if frame.UpdateTags then frame:UpdateTags() end

        -- Color: tipo de poder > color custom > blanco
        if s.powerPercentTextPowerColor then
            local pType = UnitPowerType(unit)
            local info = PowerBarColor[pType]
            if info then ppFS:SetTextColor(info.r, info.g, info.b)
            else ppFS:SetTextColor(1, 1, 1) end
        elseif s.powerTextColor then
            local tc = s.powerTextColor
            ppFS:SetTextColor(tc.r, tc.g, tc.b, tc.a or 1)
        else
            ppFS:SetTextColor(1, 1, 1)
        end
        ppFS:Show()
    end

    ApplyPowerPercentText(settings)
    power._applyPowerPercentText = ApplyPowerPercentText

    ApplyPowerBarAlpha(power, UnitToSettingsKey(unit))

    power.PostUpdate = function(self, u)
        ns.UpdatePowerBackground(self, u, GetSettingsForUnit(u))
    end

    -- Shadow Priest: show Mana on the power bar
    -- (Insanity is shown as class resource on Resource Bars)
    if unit == "player" then
        local _, classFile = UnitClass("player")
        if classFile == "PRIEST" then
            power.displayAltPower = true
            power.GetDisplayPower = function(self, u)
                local spec = GetSpecialization and GetSpecialization()
                if classFile == "PRIEST" and spec == 3 then -- Shadow
                    return 0 -- Enum.PowerType.Mana
                end
                return nil
            end
        end
    end

    KT:ApplySmoothBar(power)
    return power
end

local function CreatePortrait(frame, side, frameHeight, unit)
    local portraitHeight = frameHeight or 46
    local portraitStyle = db.profile.portraitStyle or "attached"
    local isAttached = portraitStyle == "attached"
    local isCircular = portraitStyle == "circular"

    -- Check if portrait is hidden via portraitStyle == "none"
    if (db.profile.portraitStyle or "attached") == "none" then
        return nil
    end

    -- Per-unit size/offset adjustments
    local uKey = UnitToSettingsKey(unit)
    local uSettings = uKey and db.profile[uKey]
    local pSizeAdj = (uSettings and uSettings.portraitSize) or 0
    local pXOff = (uSettings and uSettings.portraitX) or 0
    local pYOff = (uSettings and uSettings.portraitY) or 0
    local baseHeight = portraitHeight
    if not isAttached then
        pSizeAdj = pSizeAdj + 10
        if not isCircular then pYOff = pYOff + 5 end
    end
    local adjustedHeight = baseHeight + pSizeAdj
    if adjustedHeight < 8 then adjustedHeight = 8 end

    -- For attached, "top" falls back to default side
    local effectiveSide = side
    if isAttached and side == "top" then
        effectiveSide = (unit == "player") and "left" or "right"
    end

    local backdrop = CreateFrame("Frame", nil, frame)
    backdrop._isPortraitBackdrop = true  -- Flag to exclude from strata reset
    -- Same LOW strata as the frame (MEDIUM drew it over the world map and
    -- other windows); a high frame level keeps it above the bars.
    backdrop:SetFrameStrata("LOW")
    backdrop:SetFrameLevel(math.max(50, (frame:GetFrameLevel() or 0) + 20))
    backdrop:EnableMouse(false)  -- Allow clicks to pass through to unit frame
    PP.Size(backdrop, adjustedHeight, adjustedHeight)
    backdrop:SetClipsChildren(true)
    backdrop._portraitSide = side
    backdrop._unitToken = unit

    local bgTex = backdrop:CreateTexture(nil, "BACKGROUND")
    PP.Point(bgTex, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    PP.Point(bgTex, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    bgTex:SetColorTexture(0.1, 0.1, 0.1, 1)
    backdrop._bg = bgTex

    if isAttached then
        if effectiveSide == "left" then
            PP.Point(backdrop, "TOPLEFT", frame, "TOPLEFT", 0, 0)
        else
            PP.Point(backdrop, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        end
    elseif isCircular then
        AnchorCircularPortrait(backdrop, uSettings, unit)
    else
        -- Detached: float outside the health bar edge
        if effectiveSide == "top" then
            backdrop:SetPoint("BOTTOM", frame.Health or frame, "TOP", pXOff, 15 + pYOff)
        elseif effectiveSide == "left" then
            backdrop:SetPoint("TOPRIGHT", frame.Health or frame, "TOPLEFT", -15 + pXOff, pYOff)
        else
            backdrop:SetPoint("TOPLEFT", frame.Health or frame, "TOPRIGHT", 15 + pXOff, pYOff)
        end
        -- Detached portrait already has a high frame level
    end

    -- Create 2D and class theme textures eagerly; 3D PlayerModel is deferred
    -- until actually needed (mode == "3d") to avoid GPU/memory cost when unused.
    local model3D = nil  -- lazy-created only when mode is "3d"

    local function EnsureModel3D()
        if model3D then return model3D end
        model3D = CreateFrame("PlayerModel", nil, backdrop)
        PP.Point(model3D, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        PP.Point(model3D, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        model3D:SetCamera(0)
        if model3D.SetKeepModelOnHide then model3D:SetKeepModelOnHide(true) end
        model3D:Hide()
        -- The portrait element resets the camera on every model change, so the
        -- user's zoom, rotation and offsets are applied after each update.
        -- The defaults leave the camera untouched.
        local function applyLook(self, updatedUnit)
            if not (UnitIsConnected(updatedUnit) and UnitIsVisible(updatedUnit)) then return end
            local key = UnitToSettingsKey(updatedUnit)
            local s3 = key and db.profile[key]
            local zoom = math.max(0.25, ((s3 and s3.portrait3DZoom) or 125) / 100)
            local backdropFrame = self:GetParent()
            local rot, formZoom, formShift, viewShift = KT.Portrait3DYaw(updatedUnit, (s3 and s3.portraitSide) or (backdropFrame and backdropFrame._portraitSide),
                s3 and s3.portraitFacingMode,
                false,
                s3 and s3.portrait3DRotation, self)
            local offX = ((s3 and s3.portrait3DX) or 0) / 100
            local offY = ((s3 and s3.portrait3DY) or 0) / 100
            KT.ApplyPortrait3DCamera(self, rot, zoom * formZoom, offX + formShift, offY, viewShift)
        end
        -- The model loads after SetUnit returns and starts from its own camera,
        -- so the look is applied again once it has loaded.
        model3D.PostUpdate = function(self, updatedUnit)
            updatedUnit = frame.unit or unit
            self._camUnit = updatedUnit
            if KT.Portrait3DDebug then KT.Portrait3DDebug.Record(self, "PostUpdate", updatedUnit) end
            applyLook(self, updatedUnit)
        end
        model3D:SetScript("OnModelLoaded", function(self)
            if KT.Portrait3DDebug then KT.Portrait3DDebug.Record(self, "OnModelLoaded", self._camUnit) end
            if self._camUnit then applyLook(self, self._camUnit) end
        end)
        model3D:SetScript("OnShow", function(self)
            if self.__owner and self.__owner.Portrait == self and self.ForceUpdate then
                self:ForceUpdate()
            end
        end)
        backdrop._3d = model3D
        return model3D
    end
    backdrop._ensureModel3D = EnsureModel3D

    local tex2D = backdrop:CreateTexture(nil, "ARTWORK")
    PP.Point(tex2D, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    PP.Point(tex2D, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    ApplyPortraitFacing(tex2D, unit, uSettings)
    tex2D:Hide()

    -- Class theme icon (static texture, no oUF element needed)
    local texClass = backdrop:CreateTexture(nil, "ARTWORK")
    local classInset = math.floor(portraitHeight * 0.08)
    PP.Point(texClass, "TOPLEFT", backdrop, "TOPLEFT", classInset, -classInset)
    PP.Point(texClass, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -classInset, classInset)
    texClass:SetAlpha(0.8)
    local classToken = ResolvePortraitClassToken(unit)
    local classStyle = (uSettings and uSettings.classThemeStyle) or "modern"
    ApplyClassIconTexture(texClass, classToken or "WARRIOR", classStyle)
    ApplyPortraitFacing(texClass, unit, uSettings, true)
    texClass:Hide()

    backdrop._3d = model3D
    backdrop._2d = tex2D
    backdrop._class = texClass

    local mode
    do
        mode = ResolveActivePortraitMode(unit, uSettings)
        -- Legacy: if portraitMode is still "none" from old DB, hide portrait
        if mode == "none" then
            backdrop:Hide()
            return nil
        end
    end
    local active
    if mode == "class" then
        texClass:Show()
        -- Use tex2D as the oUF element (hidden) so oUF doesn't overwrite texClass
        tex2D:Hide()
        active = tex2D
        active.is2D = true
        active.isClass = true
    elseif mode == "2d" then
        tex2D:Show()
        active = tex2D
        active.is2D = true
    else
        local m3d = EnsureModel3D()
        m3d:Show()
        active = m3d
        active.is2D = false
    end
    active.backdrop = backdrop

    -- Re-apply pixel snap disable and re-anchor after oUF updates the portrait texture
    -- (SetPortraitTexture can reset snapping properties and anchor points)
    tex2D.PostUpdate = function(self)
        UnsnapTex(self)
        ApplyPortraitFacing(self, unit, uSettings)
        if self.isClass and ns.RefreshClassPortrait then ns.RefreshClassPortrait(unit, backdrop) end
        self:ClearAllPoints()
        -- When detached, ApplyDetachedPortraitShape sets expanded offsets for mask fill.
        -- Re-apply those offsets instead of resetting to default.
        local currentStyle = db.profile.portraitStyle or "attached"
        local isDetNow = currentStyle == "detached" or currentStyle == "circular"
        if isDetNow and backdrop then
            local uKey2 = UnitToSettingsKey(unit)
            local uS2 = uKey2 and db.profile[uKey2]
            local shape2 = (uS2 and uS2.detachedPortraitShape) or "portrait"
            local insetPx2 = MASK_INSETS[shape2] or 17
            local bw2 = backdrop:GetWidth()
            local bh3 = backdrop:GetHeight()
            if bw2 < 1 then bw2 = 46 end
            if bh3 < 1 then bh3 = 46 end
            local visR2 = (128 - 2 * insetPx2) / 128
            local cS2 = currentStyle == "circular" and 1 or (1 / visR2)
            local artS2 = ((uS2 and uS2.portraitArtScale) or 100) / 100
            cS2 = cS2 * artS2
            local exp2 = (cS2 - 1) * 0.5
            PP.Point(self, "TOPLEFT", backdrop, "TOPLEFT", -(exp2 * bw2), exp2 * bh3)
            PP.Point(self, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", exp2 * bw2, -(exp2 * bh3))
        else
            PP.Point(self, "TOPLEFT", backdrop, "TOPLEFT", 0, 0)
            PP.Point(self, "BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        end
        if backdrop._ktStockPortraitAnchor then
            KT:FitStockUFPortraitMask(backdrop)
            if not frame._kuiClassificationPortraitActive then
                backdrop:SetClipsChildren(true)
            end
        end
    end

    -- Apply detached portrait shape (mask + border) on creation
    ApplyDetachedPortraitShape(backdrop, uSettings, unit)
    if frame.Health then
        frame.Health.PostUpdate = function(self)
            UpdateCircularPortraitBorder(self.__owner or frame)
        end
        UpdateCircularPortraitBorder(frame)
    end

    return active
end

local function CreateCastBar(frame, unit, settings)
    local castbarBg = CreateFrame("Frame", nil, frame)
    local totalWidth = 0
    local settings = GetSettingsForUnit(unit)
    local isAttached = (db.profile.portraitStyle or "attached") == "attached"
    local showPortraitCB = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    local powerHeightTotal = 0
    local ppPos = settings.powerPosition or "below"
    local ppIsAtt = (ppPos == "below" or ppPos == "above")
    if settings.powerHeight and ppIsAtt then
        powerHeightTotal = settings.powerHeight
    end
    local playerTargetHeight = settings.healthHeight + powerHeightTotal
    local pSizeAdj = settings.portraitSize or 0
    local adjPH = playerTargetHeight + pSizeAdj
    if adjPH < 8 then adjPH = 8 end
    local castBarOffset = 0
    if not isAttached then pSizeAdj = pSizeAdj + 10 end
    if not showPortraitCB or not isAttached then
        totalWidth = settings.frameWidth
    else
        local pSide = settings.portraitSide or (unit == "player" and "left" or "right")
        local eSide = pSide
        if pSide == "top" then eSide = (unit == "player") and "left" or "right" end
        totalWidth = adjPH + settings.frameWidth
        if eSide == "left" then
            castBarOffset = -(adjPH / 2)
        else
            castBarOffset = adjPH / 2
        end
    end
    PP.Size(castbarBg, totalWidth, settings.castbarHeight or 14)

    local ppPos2 = settings.powerPosition or "below"
    local anchorFrame = (ppPos2 == "below" and frame.Power) or frame.Health
    local pcbX = 0
    local pcbY = 0
    if unit == "player" then
        local owH = db.profile.player.playerCastbarHeight or 0
        if owH > 0 then
            PP.Size(castbarBg, totalWidth, owH)
        else
            PP.Size(castbarBg, totalWidth, settings.castbarHeight or 14)
        end
        -- Player castbar is always locked to frame ? anchor from left edge of frame
        local healthOff = (frame.Health and frame.Health._xOffset) or 0
        castbarBg:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", -healthOff, 0)
    else
        local healthOff = (frame.Health and frame.Health._xOffset) or 0
        castbarBg:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", -healthOff + pcbX, pcbY)
    end

    local bgTex = castbarBg:CreateTexture(nil, "BACKGROUND")
    PP.Point(bgTex, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
    PP.Point(bgTex, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
    bgTex:SetColorTexture(0, 0, 0, 0.5)
    -- Exposed so ThemeClientAssets.lua's SeatStockCastbar can recolor it for
    -- Classic's own bronze accent on every real-stock apply pass (this
    -- creation-time code only runs once, before the theme's own flags are
    -- set, so it can't reliably theme-check itself here).
    castbarBg._bgTex = bgTex

    -- Castbar borders (3 edges: left, right, bottom ? top is shared with the frame above)
    PP.CreateBorder(castbarBg, 0, 0, 0, 1, 1, "OVERLAY", 0)

    local castbar = CreateFrame("StatusBar", nil, castbarBg)
    PP.Point(castbar, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
    PP.Point(castbar, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
    castbar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    castbar:GetStatusBarTexture():SetHorizTile(false)


    local text = castbar:CreateFontString(nil, "OVERLAY")
    SetFSFont(text, 11)
    text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetTextColor(1, 1, 1)
    castbar.Text = text

    local time = castbar:CreateFontString(nil, "OVERLAY")
    SetFSFont(time, 11)
    time:SetPoint("RIGHT", castbar, "RIGHT", -5, 0)
    time:SetJustifyH("RIGHT")
    time:SetTextColor(1, 1, 1)
    castbar.Time = time

    local shield = castbar:CreateTexture(nil, "OVERLAY")
    shield:SetSize(1, 1)
    shield:SetAlpha(0)
    shield:Hide()
    castbar.Shield = shield

    local castTintLayer = castbar:CreateTexture(nil, "ARTWORK", nil, 1)
    castTintLayer:SetPoint("TOPLEFT", castbar:GetStatusBarTexture(), "TOPLEFT")
    castTintLayer:SetPoint("BOTTOMRIGHT", castbar:GetStatusBarTexture(), "BOTTOMRIGHT")
    castTintLayer:SetTexture("Interface\\Buttons\\WHITE8X8")
    local c = GetCastbarColor()
    castTintLayer:SetVertexColor(c.r, c.g, c.b)
    castTintLayer:SetAlpha(0)
    castbar.castTintLayer = castTintLayer

    local shieldedTint = castbar:CreateTexture(nil, "ARTWORK", nil, 2)
    shieldedTint:SetPoint("TOPLEFT", castbar:GetStatusBarTexture(), "TOPLEFT")
    shieldedTint:SetPoint("BOTTOMRIGHT", castbar:GetStatusBarTexture(), "BOTTOMRIGHT")
    shieldedTint:SetTexture("Interface\\Buttons\\WHITE8X8")
    shieldedTint:SetVertexColor(0.5, 0.5, 0.5)
    shieldedTint:SetAlpha(0)
    castbar._shieldedTint = shieldedTint

    castbar.PostCastStart = function(self)
        if self.castTintLayer then
            self.castTintLayer:SetAlpha(1)
            local uSettings = self._eufSettings
            local ownerUnit = self.__owner and self.__owner.unit
            local cc = ResolveCastbarFillColor(ownerUnit, uSettings)
            if self._ktClassicLook then cc = { r = 1.0, g = 0.70, b = 0.0 } end
            self.castTintLayer:SetVertexColor(cc.r, cc.g, cc.b)
            if self._shieldedTint then
                self._shieldedTint:SetAlphaFromBoolean(self.notInterruptible, 1, 0)
            end
        end
    end
    castbar.PostChannelStart = castbar.PostCastStart

    castbar.PostCastInterruptible = castbar.PostCastStart

    castbar.CustomTimeText = function(self, durationObject)
        if durationObject then
            local duration = durationObject:GetRemainingDuration()
            if self.delay and self.delay ~= 0 then
                self.Time:SetFormattedText('%.1f|cffff0000%s%.2f|r', duration, self.channeling and '-' or '+', self.delay)
            else
                self.Time:SetFormattedText('%.1f', duration)
            end
        end
    end
    castbar.CustomDelayText = castbar.CustomTimeText

    -- Cast spell icon (oUF sets castbar.Icon texture automatically)
    local cbH = castbarBg:GetHeight()
    local iconSize = cbH + 1
    local iconFrame = CreateFrame("Frame", nil, castbarBg)
    iconFrame:SetSize(iconSize, iconSize)
    PP.Point(iconFrame, "TOPRIGHT", castbarBg, "TOPLEFT", 1, 1)
    local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBg:SetAllPoints()
    iconBg:SetColorTexture(0, 0, 0, 1)
    -- 1px black border via unified PP system
    PP.CreateBorder(iconFrame, 0, 0, 0, 1)
    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = iconTex
    castbar._iconFrame = iconFrame

    local function UpdateIconLayout()
        local s = GetSettingsForUnit(unit)
        local showIconSetting
        if unit == "player" then
            showIconSetting = s and s.showPlayerCastIcon ~= false
        else
            showIconSetting = s and s.showCastIcon ~= false
        end

        local cbH2 = castbarBg:GetHeight() or settings.castbarHeight or 14
        castbar:ClearAllPoints()
        iconFrame:ClearAllPoints()
        text:ClearAllPoints()

        if unit == "target" and showIconSetting then
            iconFrame:SetSize(math.max(cbH2 - 1, 10), math.max(cbH2 - 1, 10))
            PP.Point(iconFrame, "TOPRIGHT", castbarBg, "TOPRIGHT", 0, 0)
            PP.Point(castbar, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
            PP.Point(castbar, "BOTTOMRIGHT", iconFrame, "BOTTOMLEFT", -2, 0)
            text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
            text:SetPoint("RIGHT", castbar, "RIGHT", -18, 1)
        elseif (unit ~= "player" or (KT.VisualThemes and KT.VisualThemes.GetRenderedTheme and KT.VisualThemes:GetRenderedTheme() ~= "kui")) and showIconSetting then
            iconFrame:SetSize(math.max(cbH2 - 1, 10), math.max(cbH2 - 1, 10))
            PP.Point(iconFrame, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
            PP.Point(castbar, "TOPLEFT", iconFrame, "TOPRIGHT", 2, 0)
            PP.Point(castbar, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
            text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
            text:SetPoint("RIGHT", castbar, "RIGHT", -5, 1)
        else
            iconFrame:SetSize(cbH2 + 1, cbH2 + 1)
            PP.Point(iconFrame, "TOPRIGHT", castbarBg, "TOPLEFT", 1, 1)
            PP.Point(castbar, "TOPLEFT", castbarBg, "TOPLEFT", 0, 0)
            PP.Point(castbar, "BOTTOMRIGHT", castbarBg, "BOTTOMRIGHT", 0, 0)
            text:SetPoint("LEFT", castbar, "LEFT", 5, 1)
            text:SetPoint("RIGHT", castbar, "RIGHT", -5, 1)
        end
    end
    castbar._updateIconLayout = UpdateIconLayout
    UpdateIconLayout()

    return castbar
end

local function UnitHasActiveCast(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    return UnitCastingInfo(unit) ~= nil or UnitChannelInfo(unit) ~= nil
end

local function SetupShowOnCastBar(frame, unit)
    local castbar = frame.Castbar
    local castbarBg = castbar:GetParent()
    local iconFrame = castbar._iconFrame

    -- Read per-unit "hide while not casting" setting.
    -- When true, the castbar bg hides when nothing is being cast (player/focus default).
    -- When false, the castbar bg stays visible as part of the frame layout (target default).
    local settings = GetSettingsForUnit(unit)
    local hideWhenInactive = true
    if settings then
        local v = settings.castbarHideWhenInactive
        if v == nil then
            -- Legacy fallback: target always showed bg, others hid it
            hideWhenInactive = (unit ~= "target")
        else
            hideWhenInactive = v
        end
    end

    local function IsCastbarEnabled()
        local s = db and db.profile and GetSettingsForUnit(unit)
        if not s then return true end
        if unit == "player" then
            return s.showPlayerCastbar ~= false
        end
        return s.showCastbar ~= false
    end

    local function ShowCastbarIcon()
        if not iconFrame then return end

        local s = db and db.profile and GetSettingsForUnit(unit)
        local showIcon
        if unit == "player" then
            showIcon = s and s.showPlayerCastIcon ~= false
        else
            showIcon = not s or s.showCastIcon ~= false
        end

        if IsCastbarEnabled() and showIcon then
            iconFrame:Show()
        else
            iconFrame:Hide()
        end
    end

    local function SyncCastbarInactiveVisibility()
        local castbarEnabled = IsCastbarEnabled()
        local activeCast = castbarEnabled and UnitHasActiveCast(unit)
        local showBg = castbarEnabled and (activeCast or not hideWhenInactive)

        if activeCast then
            castbar:Show()
        else
            castbar:Hide()
        end

        if iconFrame then
            if activeCast then
                ShowCastbarIcon()
            else
                -- The icon is a separate frame from oUF's castbar. Always hide it
                -- when the unit no longer has an active cast.
                iconFrame:Hide()
            end
        end

        if castbarBg then
            if showBg then
                castbarBg:Show()
            else
                castbarBg:Hide()
            end
        end
    end

    local function dismissCastBar(self)
        self:Hide()
        if self._iconFrame then
            self._iconFrame:Hide()
        end
        if hideWhenInactive then
            local bg = self:GetParent()
            if bg then bg:Hide() end
        end
    end

    SyncCastbarInactiveVisibility()
    castbar._syncInactiveVisibility = SyncCastbarInactiveVisibility

    local savedCastHook = castbar.PostCastStart
    local savedInterruptibleHook = castbar.PostCastInterruptible

    local function showCastBar(self, ...)
        if not IsCastbarEnabled() then
            dismissCastBar(self)
            return
        end

        local bg = self:GetParent()
        if bg then bg:Show() end
        self:Show()
        ShowCastbarIcon()
        if savedCastHook then savedCastHook(self, ...) end
    end

    castbar.PostCastStart = showCastBar
    castbar.PostChannelStart = showCastBar
    castbar.PostCastInterruptible = savedInterruptibleHook or savedCastHook

    -- oUF uses PostCastInterrupted for interruption events that carry an
    -- interrupter GUID. Keep the separate icon in sync for that path as well.
    castbar.PostCastInterrupted = dismissCastBar
    castbar.PostCastStop = dismissCastBar
    castbar.PostChannelStop = dismissCastBar
    castbar.PostCastFail = dismissCastBar

    -- The icon lives outside oUF's Castbar element, so also reconcile it from
    -- the unit spellcast events. This covers target changes and interrupted or
    -- failed casts where the oUF callback can be skipped due to a castID/state
    -- mismatch on Forever.
    local stateWatcher = castbar._castStateWatcher
    if not stateWatcher then
        stateWatcher = CreateFrame("Frame", nil, frame)
        castbar._castStateWatcher = stateWatcher
    end

    local function ScheduleCastbarSync()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, SyncCastbarInactiveVisibility)
        else
            SyncCastbarInactiveVisibility()
        end
    end

    stateWatcher:SetScript("OnEvent", ScheduleCastbarSync)
    stateWatcher:RegisterUnitEvent("UNIT_SPELLCAST_START", unit)
    stateWatcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", unit)
    stateWatcher:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", unit)
    stateWatcher:RegisterUnitEvent("UNIT_SPELLCAST_STOP", unit)
    stateWatcher:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", unit)
    stateWatcher:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", unit)
    stateWatcher:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", unit)
    stateWatcher:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
    if unit == "target" then
        stateWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    elseif unit == "focus" then
        stateWatcher:RegisterEvent("PLAYER_FOCUS_CHANGED")
    end
end

-- â”€â”€â”€ Borders de unit frames: creaciÃ³n separada de apariencia â”€â”€â”€â”€â”€â”€
-- Paso 1: BuildBorderFrame - crea la estructura sin apariencia
-- Paso 2: ApplyBorderAppearance - configura grosor/color desde settings
-- Los hooks de hover comparten resoluciÃ³n de settings vÃ­a tabla estÃ¡tica.

-- DetecciÃ³n de mini frames por tabla (sin pattern matching repetido)
local MINI_FRAME_UNITS = {
    pet = true, targettarget = true, focustarget = true,
    boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
}

-- Resolver settings de borde segÃºn si el frame es mini o principal
local function ResolveBorderSettings(unit)
    local u = unit or "player"
    if MINI_FRAME_UNITS[u] then return GetMiniDonorSettings() end
    return GetSettingsForUnit(u)
end

local function FrameBorderEnter(self)
    if not (self.unifiedBorder and self.unifiedBorder._ppBorders) then return end
    local s = ResolveBorderSettings(self.unit)
    local hc = s.highlightColor or { r = 1, g = 1, b = 1 }
    PP.SetBorderColor(self.unifiedBorder, hc.r, hc.g, hc.b, 1)
end

local function FrameBorderLeave(self)
    if not (self.unifiedBorder and self.unifiedBorder._ppBorders) then return end
    local s = ResolveBorderSettings(self.unit)
    local bc = s.borderColor or { r = 0, g = 0, b = 0 }
    PP.SetBorderColor(self.unifiedBorder, bc.r, bc.g, bc.b, 1)
end

-- Paso 1: solo crea el frame contenedor de borde (sin apariencia)
local function BuildBorderFrame(frame)
    local border = CreateFrame("Frame", nil, frame)
    PP.Point(border, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    PP.Point(border, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.unifiedBorder = border
    return border
end

-- Paso 2: aplica grosor y color al borde existente
local function ApplyBorderAppearance(frame, unit)
    local border = frame.unifiedBorder
    if not border then return end
    local s = ResolveBorderSettings(unit)
    local size = s.borderSize or 1
    local bc = s.borderColor or { r = 0, g = 0, b = 0 }
    PP.CreateBorder(border, bc.r, bc.g, bc.b, 1, size)
    if size == 0 then border:Hide() end
end

-- VisualThemes: the provisional 8-piece Classic border remains a
-- fallback for units without verified full-frame geometry. Player/target use
-- their real Classic or Forever stock box below; those kits replace both the
-- fallback and KUI's generic unified border.
function KT:FitStockUFTextToWidth(fontString, maxWidth)
    if not (fontString and fontString.GetStringWidth and fontString.GetFont and fontString.SetFont) then return end
    local path, currentSize, flags = fontString:GetFont()
    if not path or not currentSize then return end
    -- Cache the ORIGINAL font size once, and always re-measure from THAT
    -- size, never from whatever size the last call left behind. Clicking a
    -- target fires ApplyClassicFrameArt (and this function through it)
    -- more than once in the same refresh; without resetting to a fixed
    -- base first, each call would shrink an already-shrunk font further,
    -- so the text would keep getting smaller and never recover.
    local base = fontString._ktStockFitBaseFontSize
    if not base then
        base = currentSize
        fontString._ktStockFitBaseFontSize = base
    end
    fontString:SetFont(path, base, flags)
    local textWidth = fontString:GetStringWidth()
    -- A FontString showing text derived from a secure/protected context (e.g.
    -- certain unit names) can return a tainted "secret" number here -- Blizzard's
    -- own security model forbids comparing it with plain Lua operators
    -- ("attempt to compare ... a secret number value").
    if IsForeverSecretValue(textWidth) then return end
    if not textWidth or textWidth <= 0 or textWidth <= maxWidth then return end
    fontString:SetFont(path, math.max(6, base * (maxWidth / textWidth)), flags)
end
function KT:ApplyStockUFHealthTextGeometry(frame, unit)
    local health = frame and frame.Health
    if not health then return end

    local settings = GetSettingsForUnit(unit)
    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "both"
    local centerContent = settings.centerTextContent or "none"
    if ns.UsesModernNumbers() and (unit == "player" or unit == "target") then
        local width = math.max(1, (health.GetWidth and health:GetWidth() or 0) * 0.5 - 4)
        for _, slot in ipairs({ { frame.LeftText, "LEFT", 3 }, { frame.RightText, "RIGHT", -3 } }) do
            local fs = slot[1]
            if fs then
                if fs.SetParent and frame._textOverlay then fs:SetParent(frame._textOverlay) end
                if fs.SetAlpha then fs:SetAlpha(1) end
                fs:ClearAllPoints()
                fs:SetPoint(slot[2], health, slot[2], slot[3], 0)
                fs:SetWidth(width)
                fs:SetJustifyH(slot[2])
                fs:Show()
            end
        end
        return
    end
    local width = math.max(1, (health.GetWidth and health:GetWidth() or 0) - 4)

    if centerContent ~= "none" then
        -- "name" is excluded here too (matching LeftText below): whichever
        -- slot actually holds the name has already been moved to the real
        -- name tab (ApplyForeverUnitFrameArt/ApplyClassicUnitFrameArt, via
        -- frame._ktStockNameText) -- repositioning it back onto the bar
        -- here would silently undo that and leave the tab empty.
        if frame.CenterText and centerContent ~= "name" then
            frame.CenterText:ClearAllPoints()
            frame.CenterText:SetPoint("CENTER", health, "CENTER", 0, 0)
            frame.CenterText:SetWidth(width)
            frame.CenterText:SetJustifyH("CENTER")
            KT:FitStockUFTextToWidth(frame.CenterText, width)
        end
        return
    end

    if frame.LeftText and leftContent ~= "none" and leftContent ~= "name" then
        frame.LeftText:ClearAllPoints()
        frame.LeftText:SetPoint("LEFT", health, "LEFT", 2, 0)
        frame.LeftText:SetWidth(width)
        frame.LeftText:SetJustifyH("LEFT")
        KT:FitStockUFTextToWidth(frame.LeftText, width)
    end
    if frame.RightText and rightContent ~= "none" and rightContent ~= "name" then
        -- The value/status text (health percent, or whatever oUF status
        -- tag like "AFK" currently occupies this same FontString) reads
        -- centered on the real Blizzard bar, not right-aligned near its
        -- edge.
        frame.RightText:ClearAllPoints()
        frame.RightText:SetPoint("CENTER", health, "CENTER", 0, 0)
        frame.RightText:SetWidth(width)
        frame.RightText:SetJustifyH("CENTER")
        KT:FitStockUFTextToWidth(frame.RightText, width)
    end
end
-- Classic Visual Style: Player and Target show "664/707 (93%)" centred
-- inside each bar, keeping the percentage within the stock frame. Pet:
-- "707/707" with no percent. The profile's own text slots are kept for the
-- other styles; here they are only hidden (the name slot stays as is).
do
    local CLASSIC_STATUS_LAYOUT = {
        player = { hp = "kui-classic-hpfull", pp = "kui-classic-ppfull" },
        target = { hp = "kui-classic-hpfull", pp = "kui-classic-ppfull" },
        pet    = { hp = "kui-classic-hp", pp = "kui-classic-pp" },
    }
    local CLASSIC_STATUS_TEXT_RATIO = 0.85

    local function SetClassicStatusHidden(fs, hidden)
        if type(fs) ~= "table" or not fs.SetAlpha then return end
        if hidden then
            fs._ktClassicStatusHidden = true
            if not fs._ktClassicStatusHook and hooksecurefunc then
                fs._ktClassicStatusHook = true
                hooksecurefunc(fs, "SetAlpha", function(self, a)
                    if self._ktClassicStatusHidden and a ~= 0 and not self._ktClassicStatusBusy then
                        self._ktClassicStatusBusy = true
                        self:SetAlpha(0)
                        self._ktClassicStatusBusy = nil
                    end
                end)
            end
            fs:SetAlpha(0)
        elseif fs._ktClassicStatusHidden then
            fs._ktClassicStatusHidden = nil
            fs:SetAlpha(1)
        end
    end

    function ns.ApplyClassicStatusText(frame, unit, active)
        local layout = CLASSIC_STATUS_LAYOUT[unit]
        if active then
            local profile = db and db.profile
            active = layout ~= nil and frame.Health ~= nil
                and ns.StockStyleToggle(profile, "classicStatusText", "classic")
        end
        local nameText = frame._ktStockNameText or frame.LeftText
        for _, fs in ipairs({ frame.LeftText, frame.RightText, frame.CenterText }) do
            SetClassicStatusHidden(fs, active and fs ~= nameText)
        end
        SetClassicStatusHidden(frame.Power and frame.Power._ppFS, active)

        local texts = frame._ktClassicStatus
        if not active then
            if texts then
                for _, fs in pairs(texts.fs) do
                    if fs._curTag then frame:Untag(fs); fs._curTag = nil end
                    fs:SetText("")
                    fs:Hide()
                end
            end
            return
        end

        if not texts then
            local holder = CreateFrame("Frame", nil, frame)
            holder:SetAllPoints(frame)
            holder:EnableMouse(false)
            texts = { holder = holder, fs = {} }
            for _, key in ipairs({ "hp", "hpPct", "pp", "ppPct" }) do
                local fs = holder:CreateFontString(nil, "OVERLAY")
                -- A FontString needs a font before any SetText, even an empty one.
                fs:SetFont(ns.BlizzardFont("TextStatusBarText", "Fonts\\FRIZQT__.TTF", 10, "OUTLINE"))
                fs:SetWordWrap(false)
                texts.fs[key] = fs
            end
            frame._ktClassicStatus = texts
        end
        -- Above the bars and the stock art, and never inside Health's clip.
        local level = frame:GetFrameLevel()
        for _, region in ipairs({ frame.Health, frame.Power, frame._ktClassicArtHost, frame._ktPetArtHost }) do
            if region and region.GetFrameLevel then level = math.max(level, region:GetFrameLevel()) end
        end
        texts.holder:SetFrameLevel(level + 2)

        local path, size, flags = ns.BlizzardFont("TextStatusBarText", "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        local bars = { hp = frame.Health, hpPct = frame.Health, pp = frame.Power, ppPct = frame.Power }
        for key, fs in pairs(texts.fs) do
            local tag = layout[key]
            local bar = bars[key]
            if tag and bar and not (bar.IsShown and not bar:IsShown()) then
                local barH = bar.GetHeight and bar:GetHeight() or 12
                fs:SetFont(path, math.max(6, math.min(size, barH * CLASSIC_STATUS_TEXT_RATIO)), flags)
                fs:SetTextColor(1, 1, 1, 1)
                fs:SetShadowColor(0, 0, 0, 1)
                fs:SetShadowOffset(1, -1)
                fs:ClearAllPoints()
                if key == "hpPct" or key == "ppPct" then
                    fs:SetPoint("LEFT", bar, "RIGHT", 4, 0)
                    fs:SetJustifyH("LEFT")
                else
                    fs:SetPoint("CENTER", bar, "CENTER", 0, 0)
                    fs:SetJustifyH("CENTER")
                end
                if fs._curTag ~= "[" .. tag .. "]" then
                    if fs._curTag then frame:Untag(fs) end
                    fs._curTag = "[" .. tag .. "]"
                    frame:Tag(fs, fs._curTag)
                end
                fs:Show()
            else
                if fs._curTag then frame:Untag(fs); fs._curTag = nil end
                fs:SetText("")
                fs:Hide()
            end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
end

local function ApplyClassicFrameArt(frame, unit)
    if not frame then return end
    local VT = KT.VisualThemes
    local renderedTheme = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
    local classicKit = db and db.profile and db.profile.frameArtKit == "classic"
    local classicActive = renderedTheme == "classic" or classicKit
    if VT and VT.CreateClassicBorder and VT.SeatClassicBorder and VT.ShowClassicBorder then
        local wantClassic = classicActive
        if wantClassic then
            frame.classicBorder = frame.classicBorder or VT:CreateClassicBorder(frame)
            if frame.classicBorder then
                VT:SeatClassicBorder(frame.classicBorder, frame, 1)
                VT:ShowClassicBorder(frame.classicBorder, true)
            end
        elseif frame.classicBorder then
            VT:ShowClassicBorder(frame.classicBorder, false)
        end
    end

    -- Real per-client art. Player/target Classic and Forever both use a
    -- stable stock-layout box; other Classic units retain portrait-only art,
    -- while non-Forever units deliberately receive no guessed Forever box.
    local portraitRegion = (frame.Portrait and frame.Portrait.backdrop) or frame

    -- Which FontString actually holds "name" content is a per-profile
    -- choice (leftTextContent/rightTextContent/centerTextContent), not
    -- always frame.LeftText -- a profile with a different assignment would
    -- leave the name tab empty because nothing was ever moved there.
    -- ThemeClientAssets.lua has no access to `settings`, so this is
    -- resolved here and handed to it via frame._ktStockNameText (nil when
    -- no slot is set to "name", which the caller already handles as "leave
    -- LeftText untouched" for backward compatibility).
    do
        local textSettings = GetSettingsForUnit(unit)
        local leftContent = textSettings.leftTextContent or "name"
        local rightContent = textSettings.rightTextContent or "both"
        local centerContent = textSettings.centerTextContent or "none"
        if centerContent == "name" then
            frame._ktStockNameText = frame.CenterText
        elseif rightContent == "name" then
            frame._ktStockNameText = frame.RightText
        elseif leftContent == "name" then
            frame._ktStockNameText = frame.LeftText
        else
            frame._ktStockNameText = nil
        end
    end

    -- Pet frame: its own small stock box (Classic sheet / Forever-Retail mini
    -- atlas). Shape and texture are theme-owned; size, colours, fonts and
    -- texts stay editable.
    if unit == "pet" and VT and VT.ApplyPetFrameArt and VT.ClearPetFrameArt then
        local petKind = classicActive and "classic"
            or ((renderedTheme == "forever" or renderedTheme == "retail") and "forever" or nil)
        local petSettings = GetSettingsForUnit(unit)
        local petScale = (tonumber(petSettings.frameWidth) or 101) / 101
        if petKind and frame.Portrait and frame.Portrait.backdrop and VT:ApplyPetFrameArt(frame, portraitRegion, petKind, { scale = petScale }) then
            if frame.classicBorder and VT.ShowClassicBorder then VT:ShowClassicBorder(frame.classicBorder, false) end
            if frame.unifiedBorder then frame.unifiedBorder:Hide() end
            KT:ApplyStockUFHealthTextGeometry(frame, unit)
            ns.ApplyClassicStatusText(frame, unit, petKind == "classic")
            return
        end
        if frame._ktPetSaved then
            VT:ClearPetFrameArt(frame)
            if frame.Power and petSettings.powerHeight then PP.Height(frame.Power, petSettings.powerHeight) end
            if frame._applyTextPositions then frame._applyTextPositions(petSettings) end
        end
    end

    local usingClassicRealArt = false
    if VT and VT.ApplyClassicUnitFrameArt and VT.ClearClassicUnitFrameArt then
        if classicActive then
            usingClassicRealArt = VT:ApplyClassicUnitFrameArt(frame, portraitRegion, unit) and true or false
        else
            VT:ClearClassicUnitFrameArt(frame)
        end
    end
    local usingForeverRealArt = false
    if VT and VT.ApplyForeverUnitFrameArt and VT.ClearForeverUnitFrameArt then
        -- Retail reuses this same real-stock-geometry renderer -- same
        -- atlas name, same box -- rather than the bare fixed-accent-color
        -- ceiling. The atlas itself renders gold instead of bronze on a
        -- genuine Retail client with no extra handling needed.
        if (renderedTheme == "forever" or renderedTheme == "retail") and not classicActive then
            usingForeverRealArt = VT:ApplyForeverUnitFrameArt(frame, portraitRegion, unit) and true or false
        else
            VT:ClearForeverUnitFrameArt(frame)
        end
    end

    -- A verified full-frame kit already provides the complete frame chrome.
    -- Hide both KUI's generic border and Classic's provisional 8-piece
    -- fallback only for player/target, where real stock geometry was applied.
    local usingThemedRealArt = usingClassicRealArt or usingForeverRealArt
    if usingClassicRealArt and frame.classicBorder
        and VT and VT.ShowClassicBorder then
        VT:ShowClassicBorder(frame.classicBorder, false)
    end
    if usingThemedRealArt and frame.unifiedBorder then
        frame.unifiedBorder:Hide()
    end
    if usingThemedRealArt then
        KT:ApplyStockUFHealthTextGeometry(frame, unit)
    end
    ns.ApplyClassicStatusText(frame, unit, usingClassicRealArt)
    -- The real stock layouts own their aura placement. Forever moves buffs
    -- into its name/buffs tab, while Classic places them above the opaque
    -- frame texture. Skip the generic refresh so it cannot undo either
    -- layout. Retail and other unit types keep the normal anchor behavior.
    if frame._refreshAuraBarGeometry and not usingForeverRealArt and not usingClassicRealArt then
        frame._refreshAuraBarGeometry()
    end
end

-- FunciÃ³n compuesta: mantiene la firma original para los 5 call sites
local function CreateUnifiedBorder(frame, unit)
    if not frame then return end
    BuildBorderFrame(frame)
    ApplyBorderAppearance(frame, unit)
    ApplyClassicFrameArt(frame, unit)
    frame:HookScript("OnEnter", FrameBorderEnter)
    frame:HookScript("OnLeave", FrameBorderLeave)
    return frame.unifiedBorder
end

local function Clamp01(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ResetReusableTexture(texture, alpha)
    if not texture then return end
    if texture.SetTexture then texture:SetTexture("Interface\\Buttons\\WHITE8X8") end
    if texture.SetTexCoord then texture:SetTexCoord(0, 1, 0, 1) end
    if texture.SetBlendMode then texture:SetBlendMode("BLEND") end
    if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, alpha == nil and 1 or alpha) end
end

local function HideDispelTexture(texture)
    if not texture then return end
    ResetReusableTexture(texture, 0)
    texture:Hide()
end

local function HideDispelFrameBorder(border)
    if not border then return end
    for i = 1, 4 do
        if border[i] then border[i]:Hide() end
    end
    HideDispelTexture(border.gradientTop)
    HideDispelTexture(border.gradientBottom)
    HideDispelTexture(border.gradientLeft)
    HideDispelTexture(border.gradientRight)
end

local function SetDispelFrameBorder(frame, color, alpha, thickness, gradientAlpha, gradientSize)
    local border = frame and frame.dispelBorder
    if not border then return end
    if not color then
        HideDispelFrameBorder(border)
        return
    end
    
    thickness = math.max(1, math.min(4, tonumber(thickness) or 2))
    alpha = math.max(0, math.min(1, tonumber(alpha) or 0.8))
    gradientAlpha = math.max(0, math.min(1, tonumber(gradientAlpha) or 0.32))
    gradientSize = math.max(0.12, math.min(0.60, tonumber(gradientSize) or 0.35))
    
    local function SafeSetColor(tex, colorObj, overrideAlpha)
        if colorObj.GetRGBA then
            tex:SetVertexColor(colorObj:GetRGBA())
        else
            tex:SetVertexColor(colorObj.r or 1, colorObj.g or 1, colorObj.b or 1, overrideAlpha or colorObj.a or 1)
        end
    end
    
    border[1]:SetHeight(thickness)
    border[2]:SetHeight(thickness)
    border[3]:SetWidth(thickness)
    border[4]:SetWidth(thickness)
    for i = 1, 4 do
        border[i]:SetTexture("Interface\\Buttons\\WHITE8X8")
        SafeSetColor(border[i], color, alpha)
        border[i]:Show()
    end
    
    local width = frame:GetWidth() or 1
    local height = frame:GetHeight() or 1
    local edgeH = math.max(thickness + 3, math.floor(height * gradientSize))
    local edgeW = math.max(thickness + 3, math.floor(width * gradientSize))
    local fadeAlpha = math.min(gradientAlpha, alpha * 0.8)
    
    if border.gradientTop then
        border.gradientTop:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_V")
        border.gradientTop:SetHeight(edgeH)
        SafeSetColor(border.gradientTop, color, fadeAlpha)
        border.gradientTop:SetBlendMode("BLEND")
        border.gradientTop:Show()
    end
    if border.gradientBottom then
        border.gradientBottom:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_V_Rev")
        border.gradientBottom:SetHeight(edgeH)
        SafeSetColor(border.gradientBottom, color, fadeAlpha)
        border.gradientBottom:SetBlendMode("BLEND")
        border.gradientBottom:Show()
    end
    if border.gradientLeft then
        border.gradientLeft:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_H")
        border.gradientLeft:SetWidth(edgeW)
        SafeSetColor(border.gradientLeft, color, fadeAlpha)
        border.gradientLeft:SetBlendMode("BLEND")
        border.gradientLeft:Show()
    end
    if border.gradientRight then
        border.gradientRight:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_H_Rev")
        border.gradientRight:SetWidth(edgeW)
        SafeSetColor(border.gradientRight, color, fadeAlpha)
        border.gradientRight:SetBlendMode("BLEND")
        border.gradientRight:Show()
    end
end

local function CreateDispelFrameBorder(parent)
    local border = {}
    for i = 1, 4 do
        border[i] = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        border[i]:SetColorTexture(0, 0, 0, 0)
        border[i]:Hide()
    end
    border[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border[1]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border[2]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border[2]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border[3]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border[3]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border[4]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border[4]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientTop = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientTop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.gradientTop:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.gradientTop:Hide()
    border.gradientBottom = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientBottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.gradientBottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientBottom:Hide()
    border.gradientLeft = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.gradientLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.gradientLeft:Hide()
    border.gradientRight = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.gradientRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientRight:Hide()
    return border
end

local function UpdateUnitDispelBorderEvent(self, event, unit)
    local frame = self:GetParent()
    if not frame or unit ~= frame.unit then return end
    if unit ~= "player" then
        SetDispelFrameBorder(frame, nil)
        return
    end

    -- Honour the "Dispel Overlay" toggle. Without this the player frame redraws
    -- its dispel border on every UNIT_AURA even when the user switched it off.
    local settings = GetSettingsForUnit and GetSettingsForUnit(unit)
        or frame.db or (GetMod and GetMod().db) or {}
    if not ns.IsDispelOverlayOn(settings) then
        SetDispelFrameBorder(frame, nil)
        return
    end

    local borderColor = nil
    -- Raw aura records cannot be inspected while PvP secrecy is active.
    -- The generic overlay remains available out of restricted contexts;
    -- per-aura dispel coloring is owned by AuraContainer buttons in 12.1.
    local restricted = _G.KTAuraKit and _G.KTAuraKit.AurasRestricted
        and _G.KTAuraKit.AurasRestricted()
    if not restricted and C_UnitAuras and C_UnitAuras.GetAuraSlots then
        local ok, cont, slot1 = pcall(C_UnitAuras.GetAuraSlots, unit, "HARMFUL|RAID_PLAYER_DISPELLABLE", 1)
        if ok and slot1 then
            borderColor = { r = 0.6, g = 0.2, b = 0.8, a = 0.8 }
        end
    end

    SetDispelFrameBorder(frame, borderColor, 0.8, 2, 0.32, 0.35)
end

local function CreateUnitDispelBorder(frame)
    if not frame.dispelBorderFrame then
        local f = CreateFrame("Frame", nil, frame)
        f:SetAllPoints(frame)
        local hl = frame.Health and frame.Health:GetFrameLevel() or frame:GetFrameLevel()
        f:SetFrameLevel(hl + 20)
        frame.dispelBorderFrame = f
        frame.dispelBorder = CreateDispelFrameBorder(f)
        
        f:RegisterEvent("UNIT_AURA")
        f:SetScript("OnEvent", UpdateUnitDispelBorderEvent)
        UpdateUnitDispelBorderEvent(f, "UNIT_AURA", frame.unit)
    end
end

local function SyncTargetAuraContainer(frame, unit)
    local container = frame and frame.KTDebuffs
    if not container then return end

    -- AuraContainer keeps its own unit binding. Explicitly unbind it when the
    -- target disappears so recycled buttons cannot survive into the next
    -- target. The native container remains the only aura data source.
    if not UnitExists(unit) then
        container:SetUnit("none")
        container:Hide()
        return
    end

    container:SetUnit(unit)
    container:Show()
    container:UpdateAllAuras()
end

local function RefreshTargetDebuffDispelStyle(settings)
    local AK = _G.KTAuraKit
    local style = AK and AK.styles and AK.styles["kuiuf:target-debuffs"]
    if not style then return end

    local enabled = ns.IsDispelOverlayOn(settings)
        and not (settings and settings.debuffDispelBorder == false)
    local thickness = tonumber(settings and settings.debuffDispelBorderSize)
        or tonumber(settings and settings.dispelBorderThickness)
        or 2
    local state = (enabled and "1" or "0") .. ":" .. tostring(thickness)
    if style._ktDispelState == state then return end

    style._ktDispelState = state
    style.dispelBorder = enabled
    style.dispelBorderPx = thickness
    if AK.RestyleSoon then
        AK.RestyleSoon("kuiuf:target-debuffs")
    end
end

local function ApplyTargetAuraSettings(frame, settings)
    local container = frame and frame.KTDebuffs
    if not container then return end

    RefreshTargetDebuffDispelStyle(settings)

    if settings.showDebuffs == false then
        container:Hide()
        return
    end

    local dfp, dia, dgx, dgy, dox, doy = ResolveBuffLayout(
        settings.debuffAnchor or "bottomleft",
        settings.debuffGrowth or "auto"
    )
    local cbOffset = 0
    if settings.showCastbar ~= false then
        local cbH = settings.castbarHeight or 14
        if cbH <= 0 then cbH = 14 end
        local anchor = settings.debuffAnchor or "bottomleft"
        if anchor == "bottomleft" or anchor == "bottomright" then
            -- Debuffs (player and target) sit a bit closer/higher to the
            -- frame without losing all clearance from the castbar.
            cbOffset = -cbH + KT:GetStyledDebuffLift()
        end
    end

    local bar, width, auraSize, gap = KT:ResolveUFAuraBarGeometry(frame)
    container:ClearAllPoints()
    container:SetPoint(dia, bar, dfp, dox * gap, doy * gap + cbOffset)

    local AK = _G.KTAuraKit
    if AK then
        AK.SetContainerAnchor(container, dia)
        if AK.SetContainerRowWidth and ns.BarGloss and ns.BarGloss.IsStyledLook
            and ns.BarGloss.IsStyledLook() then
            AK.SetContainerRowWidth(container, width)
        end

        local style = AK.styles and AK.styles["kuiuf:target-debuffs"]
        if style and (style.width ~= auraSize or style.height ~= auraSize) then
            style.width = auraSize
            style.height = auraSize
            if AK.RestyleSoon then AK.RestyleSoon("kuiuf:target-debuffs") end
        end
    end

    local flow = AnchorUtil and AnchorUtil.FlowDirection
    if flow and AK then
        local h = dgx == "LEFT" and flow.Left or flow.Right
        local v = dgy == "DOWN" and flow.Down or flow.Up
        AK.SetContainerGrowth(container, h, v)
    end
    if container.SetAuraGroupLayout then
        container:SetAuraGroupLayout("targetDebuffs", {
            elementWidth = auraSize, elementHeight = auraSize,
            elementSpacing = gap, lineSpacing = gap,
        })
    end
    container:Show()
    SyncTargetAuraContainer(frame, frame.unit or "target")
end

local function CreateUnitDispelSlots(frame, unit)
    if frame._ktDispelSlotsCreated then return end
    local auraKit = _G.KTAuraKit
    if not (auraKit and frame.Health) then return end

    local prefix = 'kuiuf:dispel:' .. tostring(frame)
    local settings = frame.db or (GetMod and GetMod().db) or {}
    auraKit.ConfigureDispelSlotStyles(prefix, frame.Health, {
        alpha = 1,
        thickness = 2,
        colors = settings,
    })
    local container = auraKit.CreateContainer(frame, unit, {
        point = { 'CENTER', frame, 'CENTER' },
        slots = auraKit.BuildDispelSlotSpecs(prefix),
    })
    container:SetFrameLevel(frame:GetFrameLevel() + 20)
    container:SetShown(ns.IsDispelOverlayOn(GetSettingsForUnit(unit)))
    frame.KTDispelSlots = container
    frame._ktDispelPrefix = prefix
    frame._ktDispelSlotsCreated = true
end

function KT:RefreshTargetUFAuraBarGeometry(frame)
    if not frame then return end
    local current = GetSettingsForUnit(frame.unit or "target")

    if frame.Buffs then
        local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
            current.buffAnchor, current.buffGrowth
        )
        local buffOffset = 0
        local buffAnchor = current.buffAnchor or "topleft"
        if current.showCastbar ~= false
            and (buffAnchor == "bottomleft" or buffAnchor == "bottomright")
        then
            local castHeight = current.castbarHeight or 14
            if castHeight <= 0 then castHeight = 14 end
            buffOffset = -castHeight
        end
        KT:ApplyLegacyUFAuraBarGeometry(frame.Buffs, frame, bfp, bia,
            bgx, bgy, box, boy + buffOffset)
        if frame.Buffs.ForceUpdate then frame.Buffs:ForceUpdate() end
    end

    if frame.KTDebuffs then
        ApplyTargetAuraSettings(frame, current)
    elseif frame.Debuffs then
        local dfp, dia, dgx, dgy, dox, doy = ResolveBuffLayout(
            current.debuffAnchor or "bottomleft",
            current.debuffGrowth or "auto"
        )
        local debuffOffset = 0
        local debuffAnchor = current.debuffAnchor or "bottomleft"
        if current.showCastbar ~= false
            and (debuffAnchor == "bottomleft" or debuffAnchor == "bottomright")
        then
            local castHeight = current.castbarHeight or 14
            if castHeight <= 0 then castHeight = 14 end
            -- Debuffs (player and target) sit a bit closer/higher to the
            -- frame without losing all clearance from the castbar.
            debuffOffset = -castHeight + KT:GetStyledDebuffLift()
        end
        KT:ApplyLegacyUFAuraBarGeometry(frame.Debuffs, frame, dfp, dia,
            dgx, dgy, dox, doy + debuffOffset)
        if frame.Debuffs.ForceUpdate then frame.Debuffs:ForceUpdate() end
    end
end
local function CreateTargetAuras(frame, unit)
    if frame._targetAurasCreated then
        SyncTargetAuraContainer(frame, unit or "target")
        return
    end
    frame._targetAurasCreated = true
    frame._refreshAuraBarGeometry = function()
        KT:RefreshTargetUFAuraBarGeometry(frame)
    end
    local function SetupAuraIcon(_, button)
        if not button then return end

        if button.Icon then
            button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end

        if button.Cooldown then
            button.Cooldown:SetDrawEdge(false)
            button.Cooldown:SetReverse(true)
            button.Cooldown:SetHideCountdownNumbers(true)
        end

        if not button.Border then
            button.Border = CreateFrame("Frame", nil, button)
            button.Border:SetAllPoints()
            button.Border:SetFrameLevel(button:GetFrameLevel() + 1)
            PP.CreateBorder(button.Border, 0, 0, 0, 1)
        end
    end

    local auraAnchor, containerWidth, auraSize, gap, perRow = KT:ResolveUFAuraBarGeometry(frame)

    local settings = GetSettingsForUnit(unit or 'target')

    local showBuffs = true
    if settings and settings.showBuffs == false then
        showBuffs = false
    end

    -- Compute castbar offset for bottom-anchored auras so they sit below the cast bar
    local cbOffset = 0
    if settings.showCastbar then
        local cbH = settings.castbarHeight or 14
        if cbH <= 0 then cbH = 14 end
        cbOffset = -cbH
    end

    local buffs = CreateFrame("Frame", nil, frame)
    local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
        settings and settings.buffAnchor,
        settings and settings.buffGrowth
    )
    local buffCbOff = 0
    local bAnc = settings.buffAnchor or "topleft"
    if bAnc == "bottomleft" or bAnc == "bottomright" then
        buffCbOff = cbOffset
    end
    buffs:SetPoint(bia, auraAnchor, bfp, box * gap, boy * gap + buffCbOff)
    buffs:SetSize(containerWidth, auraSize)
    buffs.size = auraSize
    buffs.spacing = gap
    buffs.num = 4
    buffs["size-x"] = perRow
    buffs.initialAnchor = bia
    buffs.growthX = bgx
    buffs.growthY = bgy
    buffs.filter = "HELPFUL"
    buffs.PostCreateButton = SetupAuraIcon
    if not showBuffs then
        buffs:Hide()
        buffs.num = 0
    end
    -- Set frame level higher to appear above power bar border
    buffs:SetFrameLevel(frame:GetFrameLevel() + 15)
    frame.Buffs = buffs

    -- Target's buffs stay directly above target's own frame. Several
    -- places in this file reposition frame.Buffs on refresh (this creation
    -- block, two blocks in ReloadFrames, and
    -- KT:RefreshTargetUFAuraBarGeometry/ApplyLegacyUFAuraBarGeometry), so
    -- the position is forced by hooking SetPoint itself: whichever of
    -- those writes anywhere else, the LAST word is always this fixed
    -- anchor. Guarded against recursion since the corrective call below
    -- also goes through SetPoint.
    if unit == "target" or (frame.unit == "target") then
        local forcingBuffsAnchor = false
        local function PinTargetBuffsAboveFrame()
            if forcingBuffsAnchor then return end
            -- KUI Style keeps the user's own buff anchor (Retail behaviour).
            if not (ns.BarGloss and ns.BarGloss.IsStyledLook and ns.BarGloss.IsStyledLook()) then return end
            forcingBuffsAnchor = true
            buffs:ClearAllPoints()
            -- Anchored above the name tab, aligned with the visible name
            -- tab/health bar's left edge. Frame's raw TOPLEFT.x sits further
            -- left than that edge (frame's bounding box includes margin the
            -- name tab doesn't use), so compute the real gap between
            -- Health's left edge and frame's left edge at runtime (robust to
            -- frameScale, unlike a hardcoded pixel snapshot) and apply it as
            -- the X offset, while keeping frame's own Y (above the whole
            -- stock box, name tab included).
            local xOff = 0
            if frame.Health and frame.Health.GetLeft and frame.GetLeft then
                local hl, fl = frame.Health:GetLeft(), frame:GetLeft()
                if hl and fl then xOff = hl - fl end
            end
            buffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", xOff,
                -9 + KT:GetKUIStyleBuffYOffset("target"))
            forcingBuffsAnchor = false
        end
        hooksecurefunc(buffs, "SetPoint", function()
            if forcingBuffsAnchor then return end
            PinTargetBuffsAboveFrame()
        end)
        PinTargetBuffsAboveFrame()
    end

    local maxDebuffs = (settings and settings.maxDebuffs) or 28
    local dfp, dia, dgx, dgy, dox, doy = ResolveBuffLayout(
        settings and settings.debuffAnchor or "bottomleft",
        settings and settings.debuffGrowth or "auto"
    )
    local debuffCbOff = 0
    local dAnc = settings.debuffAnchor or "bottomleft"
    if dAnc == "bottomleft" or dAnc == "bottomright" then
        debuffCbOff = cbOffset
    end

    -- oUF's legacy aura reader does not consistently return NPC target auras
    -- on the modern client. Use the same AuraContainer path as Nameplates so
    -- player-applied harmful auras work for mobs and enemy NPCs as well.
    local AK = _G.KTAuraKit
    if AK then
        AK.styles["kuiuf:target-debuffs"] = {
            width = auraSize, height = auraSize,
            texCoord = { 0.07, 0.93, 0.07, 0.93 },
            border = { 0, 0, 0, 1, size = 1 },
            cooldownReverse = true,
            dispelBorder = ns.IsDispelOverlayOn(settings)
                and settings.debuffDispelBorder ~= false,
            dispelBorderPx = tonumber(settings.debuffDispelBorderSize)
                or tonumber(settings.dispelBorderThickness) or 2,
        }
        local debuffs = AK.CreateContainer(frame, unit, {
            point = { "CENTER", frame, "CENTER" },
            groups = {{
                key = "targetDebuffs",
                filter = settings and settings.onlyPlayerDebuffs
                    and { "HARMFUL", "PLAYER" } or { "HARMFUL" },
                maxFrameCount = maxDebuffs,
                candidateFilters = {},
                style = "kuiuf:target-debuffs",
                layout = {
                    elementWidth = auraSize, elementHeight = auraSize,
                    elementSpacing = gap, lineSpacing = gap,
                },
            }},
        })
        debuffs:ClearAllPoints()
        debuffs:SetPoint(dia, auraAnchor, dfp, dox * gap, doy * gap + debuffCbOff)
        AK.SetContainerAnchor(debuffs, dia)
        local flow = AnchorUtil and AnchorUtil.FlowDirection
        if flow then
            local h = dgx == "LEFT" and flow.Left or flow.Right
            local v = dgy == "DOWN" and flow.Down or flow.Up
            AK.SetContainerGrowth(debuffs, h, v)
        end
        debuffs:SetFrameLevel(frame:GetFrameLevel() + 15)
        frame.KTDebuffs = debuffs

        local sync = CreateFrame("Frame", nil, frame)
        sync:RegisterUnitEvent("UNIT_AURA", unit)
        sync:RegisterEvent("PLAYER_TARGET_CHANGED")
        sync:RegisterEvent("PLAYER_ENTERING_WORLD")
        sync:SetScript("OnEvent", function()
            SyncTargetAuraContainer(frame, unit)
        end)
        frame._targetAuraSync = sync
        SyncTargetAuraContainer(frame, unit)
    else
        local debuffs = CreateFrame("Frame", nil, frame)
        debuffs:SetPoint(dia, auraAnchor, dfp, dox * gap, doy * gap + debuffCbOff)
        debuffs:SetSize(containerWidth, auraSize)
        debuffs.size = auraSize
        debuffs.spacing = gap
        debuffs.num = maxDebuffs
        debuffs["size-x"] = perRow
        debuffs.initialAnchor = dia
        debuffs.growthX = dgx
        debuffs.growthY = dgy
        debuffs.filter = "HARMFUL"
        debuffs.PostCreateButton = SetupAuraIcon
        if settings and settings.onlyPlayerDebuffs then
            debuffs.onlyShowPlayer = true
        end
        debuffs:SetFrameLevel(frame:GetFrameLevel() + 15)
        frame.Debuffs = debuffs
    end
end

-- â”€â”€â”€ FÃ¡brica de posicionamiento de texto â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Genera un closure ApplyTextPositions parametrizado por modo:
--   fullMode=true  â†’ PP.Point, SetFSFont, offsets XY, class color
--                     (player, target, focus â€” barras con textOverlay)
--   fullMode=false â†’ SetPoint directo, sin fuente/offset/color
--                     (simple, pet, boss â€” barras compactas)
-- defs: {leftDefault, rightDefault, centerDefault}
local function BuildTextPositioner(leftFS, rightFS, centerFS, unitID, anchor, defs, fullMode)
    local function GetCircularTextInsets(settings)
        if not (db and db.profile and db.profile.portraitStyle == "circular")
            or settings.showPortrait == false
        then
            return 5, 5
        end

        local side = settings.portraitSide
            or ((unitID == "player" or unitID == "pet") and "left" or "right")
        local powerPosition = settings.powerPosition or "none"
        local powerHeight = (powerPosition == "above" or powerPosition == "below")
            and (settings.powerHeight or 0) or 0
        local diameter = math.max(
            8,
            (settings.healthHeight or 20) + powerHeight + (settings.portraitSize or 0) + 10
        )
        local inset = (diameter * 0.5) + 5
        return side == "left" and inset or 5, side == "right" and inset or 5
    end

    if fullMode then
        return function(s)
            local lc  = s.leftTextContent   or defs[1]
            local rc  = s.rightTextContent  or defs[2]
            local cc  = s.centerTextContent or defs[3]
            local lsz = s.leftTextSize   or s.textSize or 12
            local rsz = s.rightTextSize  or s.textSize or 12
            local csz = s.centerTextSize or s.textSize or 12
            local lxo = s.leftTextX or 0;   local lyo = s.leftTextY or 0
            local rxo = s.rightTextX or 0;  local ryo = s.rightTextY or 0
            local cxo = s.centerTextX or 0; local cyo = s.centerTextY or 0
            local barW = s.frameWidth or 181
            local leftInset, rightInset = GetCircularTextInsets(s)

            if cc ~= "none" and not (cc == "name" and ns.UsesModernNumbers()) then
                leftFS:Hide(); rightFS:Hide()
                SetFSFont(centerFS, csz)
                centerFS:ClearAllPoints()
                centerFS:SetJustifyH("CENTER")
                PP.Point(centerFS, "CENTER", anchor, "CENTER", cxo, cyo)
                PP.Width(centerFS, math.max(barW - leftInset - rightInset, 20))
                centerFS:Show()
                ApplyClassColor(centerFS, unitID, s.centerTextClassColor)
            else
                if cc == "name" and ns.UsesModernNumbers() then centerFS:Show() else centerFS:Hide() end
                SetFSFont(leftFS, lsz)
                leftFS:ClearAllPoints()
                if lc ~= "none" then
                    leftFS:SetJustifyH("LEFT")
                    PP.Point(leftFS, "LEFT", anchor, "LEFT", leftInset + lxo, lyo)
                    if rc ~= "none" then
                        PP.Width(leftFS, math.max(barW - EstimateUFTextWidth(rc) - leftInset - rightInset, 20))
                    else PP.Width(leftFS, math.max(barW - leftInset - rightInset, 20)) end
                    leftFS:Show()
                    ApplyClassColor(leftFS, unitID, s.leftTextClassColor)
                else leftFS:Hide() end

                SetFSFont(rightFS, rsz)
                rightFS:ClearAllPoints()
                if rc ~= "none" then
                    rightFS:SetJustifyH("RIGHT")
                    PP.Point(rightFS, "RIGHT", anchor, "RIGHT", -rightInset + rxo, ryo)
                    if lc ~= "none" then
                        PP.Width(rightFS, math.max(barW - EstimateUFTextWidth(lc) - leftInset - rightInset, 20))
                    else PP.Width(rightFS, math.max(barW - leftInset - rightInset, 20)) end
                    rightFS:Show()
                    ApplyClassColor(rightFS, unitID, s.rightTextClassColor)
                else rightFS:Hide() end
            end
        end
    else
        -- Modo compacto: sin fuentes, sin offsets, sin class color
        return function(s)
            local lc   = s.leftTextContent   or defs[1]
            local rc   = s.rightTextContent  or defs[2]
            local cc   = s.centerTextContent or defs[3]
            local barW = s.frameWidth or 100
            local leftInset, rightInset = GetCircularTextInsets(s)

            if cc ~= "none" then
                centerFS:ClearAllPoints()
                centerFS:SetPoint("CENTER", anchor, "CENTER", 0, 0)
                PP.Width(centerFS, math.max(barW - leftInset - rightInset, 20))
                centerFS:Show()
                leftFS:Hide(); rightFS:Hide()
            else
                centerFS:Hide()
                if lc ~= "none" then
                    leftFS:ClearAllPoints()
                    leftFS:SetPoint("LEFT", anchor, "LEFT", leftInset, 0)
                    leftFS:SetJustifyH("LEFT")
                    if rc ~= "none" then
                        PP.Width(leftFS, math.max(barW - EstimateUFTextWidth(rc) - 10, 20))
                    else PP.Width(leftFS, math.max(barW - leftInset - rightInset, 20)) end
                    leftFS:Show()
                else leftFS:Hide() end
                if rc ~= "none" then
                    rightFS:ClearAllPoints()
                    rightFS:SetPoint("RIGHT", anchor, "RIGHT", -rightInset, 0)
                    rightFS:SetJustifyH("RIGHT")
                    if lc ~= "none" then
                        PP.Width(rightFS, math.max(barW - EstimateUFTextWidth(lc) - 10, 20))
                    else PP.Width(rightFS, math.max(barW - leftInset - rightInset, 20)) end
                    rightFS:Show()
                else rightFS:Hide() end
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Indicadores de estado para cualquier unit frame (Leader, Assistant,
--  Resurrect, Summon, RaidTarget, y overlay AFK/Dead/Ghost/Offline).
--  Usa los iconos personalizados de KUI_ICON_PATH.
-------------------------------------------------------------------------------
local function AnchorNoPortraitClassificationIndicator(frame, indicator, profile)
    if not (frame and indicator) then return end

    indicator:ClearAllPoints()
    local size = math.max(8, tonumber(profile and profile.classificationNoPortraitSize) or CLASSIFICATION_NO_PORTRAIT_SIZE)
    local anchor = profile and profile.classificationNoPortraitAnchor
    if not OVERLAY_ANCHORS[anchor] then anchor = "TOPRIGHT" end
    local x = tonumber(profile and profile.classificationNoPortraitX)
    local y = tonumber(profile and profile.classificationNoPortraitY)
    if x == nil then x = anchor == "TOPRIGHT" and -8 or 0 end
    if y == nil then y = 0 end

    local rightEdge = frame.GetRight and frame:GetRight()
    local screenWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth()
    local canUseRight = not rightEdge or not screenWidth
        or rightEdge + (size * 0.5) + x <= screenWidth

    -- Keep the default artwork outside the health bar when the frame is near
    -- the right edge; custom anchors and offsets remain fully configurable.
    if anchor == "TOPRIGHT" and not canUseRight then
        indicator:SetPoint("CENTER", frame, "TOPLEFT", 8, 0)
    else
        indicator:SetPoint("CENTER", frame, anchor, x, y)
    end
end

local function SetupUnitIndicators(frame, unit)
    if not frame or not frame.Health then return end
    local health = frame.Health
    local settings = GetSettingsForUnit(unit)

    -- Frame overlay de alto nivel para que los iconos queden por encima
    if not frame._kuiIndicatorOverlay then
        local ovr = CreateFrame("Frame", nil, frame)
        ovr:SetAllPoints(frame)
        ovr._kuiAbovePortraitOverlay = true
        ovr:SetFrameLevel(frame:GetFrameLevel() + 60)
        ns.ApplyOverlayStrata(ovr, frame)
        frame._kuiIndicatorOverlay = ovr
    end
    local iOvr = frame._kuiIndicatorOverlay

    -- The level circle/text must render above the elite/rare
    -- classification ring. Sublevels can't do it: the ring's own art still
    -- shows through above its sublevel 7, and 7 is the maximum ("Sublevel
    -- must be between -8 and 7"). The "HIGHLIGHT" draw layer doesn't work
    -- either -- it makes them invisible, as HIGHLIGHT appears to be a
    -- Button-specific render layer, not a general 5th layer usable on a
    -- plain Frame like iOvr.
    -- A genuinely separate, higher-FrameLevel frame sidesteps sublevel
    -- limits entirely: FrameLevel ordering is a wholly different
    -- mechanism from draw-layer sublevels and always wins across frames
    -- within the same strata, regardless of either frame's own internal
    -- sublevel usage.
    if not frame._kuiLevelOverlay then
        local lvlOvr = CreateFrame("Frame", nil, iOvr)
        lvlOvr:SetAllPoints(iOvr)
        frame._kuiLevelOverlay = lvlOvr
    end
    local lvlOvr = frame._kuiLevelOverlay
    -- Strata/level are synced on EVERY call, not just inside the creation
    -- guard above: iOvr's OWN level (frame:GetFrameLevel() + 60, right
    -- above) is recomputed on every call, unconditionally. If frame's own
    -- level ever changes later (a real possibility for unit frames), iOvr
    -- updates to match, and a lvlOvr set only at creation time would stay
    -- stale and let the two drift out of order on a later refresh.
    -- Keeping this in sync every call, matching iOvr's own update pattern,
    -- holds regardless of when frame's level changes.
    lvlOvr:SetFrameStrata(iOvr:GetFrameStrata())
    lvlOvr:SetFrameLevel(iOvr:GetFrameLevel() + 1)

    if not frame._kuiLevelCircle then
        -- Sublevel -1: the opaque disc must stay under the level number, which
        -- shares this overlay and layer.
        local circle = lvlOvr:CreateTexture(nil, "OVERLAY", nil, -1)
        circle:SetTexture("Interface\\Buttons\\WHITE8X8")
        -- Fully opaque, not 90%: the frame-level ordering here is already
        -- correct (63 > 62), so any residual "ring still shows through" is
        -- the last 10% alpha letting the dragon art's bright highlights
        -- bleed through, not a stacking bug.
        circle:SetVertexColor(0.06, 0.06, 0.06, 1)
        local circleMask = lvlOvr:CreateMaskTexture()
        -- Blizzard's own full-canvas round mask (no transparent padding like
        -- circle_mask.tga), so the badge is a true circle with no square areas.
        circleMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        circleMask:SetAllPoints(circle)
        circle:AddMaskTexture(circleMask)
        -- Unsnapped so the small masked disc keeps a true round edge.
        if circle.SetSnapToPixelGrid then circle:SetSnapToPixelGrid(false) end
        if circle.SetTexelSnappingBias then circle:SetTexelSnappingBias(0) end
        if circleMask.SetSnapToPixelGrid then circleMask:SetSnapToPixelGrid(false) end
        if circleMask.SetTexelSnappingBias then circleMask:SetTexelSnappingBias(0) end
        circle:Hide()
        frame._kuiLevelCircle = circle
        frame._kuiLevelCircleMask = circleMask
    end
    if not frame._kuiLevelText then
        local levelText = lvlOvr:CreateFontString(nil, "OVERLAY", nil, 7)
        SetFSFont(levelText, 11, "OUTLINE")
        levelText:SetJustifyH("LEFT")
        levelText:SetWordWrap(false)
        levelText:SetTextColor(1, 0.82, 0.20, 1)
        levelText:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 2, 2)
        levelText:SetWidth(38)
        levelText:SetHeight(14)
        levelText:Hide()
        frame._kuiLevelText = levelText
    end
    if not frame._kuiClassificationIndicator then
        local classification = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        classification:SetSize(18, 18)
        classification:SetTexCoord(0, 1, 0, 1)
        classification:Hide()
        frame._kuiClassificationIndicator = classification
    end

    -- A backdrop circle behind the PvP icon, same treatment as the level
    -- circle (same lvlOvr parent, so it shares the same higher-than-the-ring
    -- frame level), for ALL themes (not gated to Classic/Forever's stock
    -- ornament like the level circle is). Shown/hid in exact lockstep with
    -- the PvP icon itself, never independently.
    -- Circle, border, and icon all live on lvlOvr: left on iOvr (a LOWER
    -- frame level than lvlOvr by design, so lvlOvr's own level circle/text
    -- beat the classification ring), the icon renders under the circle.
    -- Creation order (same layer, no explicit sublevel) is a convention,
    -- never a guarantee from the API, so explicit sublevels keep the order:
    -- circle lowest, border above it, icon on top, all still within the
    -- OVERLAY layer.
    if not frame._kuiPvPCircle then
        local pvpCircle = lvlOvr:CreateTexture(nil, "OVERLAY", nil, -2)
        pvpCircle:SetTexture("Interface\\Buttons\\WHITE8X8")
        pvpCircle:SetVertexColor(0.06, 0.06, 0.06, 1)
        local pvpCircleMask = lvlOvr:CreateMaskTexture()
        pvpCircleMask:SetTexture(PORTRAIT_MEDIA .. "circle_mask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pvpCircleMask:SetAllPoints(pvpCircle)
        pvpCircle:AddMaskTexture(pvpCircleMask)
        pvpCircle:Hide()
        frame._kuiPvPCircle = pvpCircle
        frame._kuiPvPCircleMask = pvpCircleMask
    end
    if not frame._kuiPvPCircleBorder then
        local pvpBorder = lvlOvr:CreateTexture(nil, "OVERLAY", nil, -1)
        pvpBorder:SetTexture(PORTRAIT_MEDIA .. "circle_border.tga")
        pvpBorder:Hide()
        frame._kuiPvPCircleBorder = pvpBorder
    end
    if not frame._kuiPvPIcon then
        local pvp = lvlOvr:CreateTexture(nil, "OVERLAY", nil, 1)
        pvp:SetSize(16, 16)
        pvp:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", -2, 1)
        pvp:Hide()
        frame._kuiPvPIcon = pvp
    end
    if not frame._kuiPvPShadow then
        -- kui style: no backdrop circle, a soft drop shadow under the icon.
        local shadow = lvlOvr:CreateTexture(nil, "OVERLAY", nil, 0)
        shadow:SetVertexColor(0, 0, 0, 0.7)
        shadow:SetSize(20, 20)
        shadow:SetPoint("CENTER", frame._kuiPvPIcon, "CENTER", 1.5, -1.5)
        shadow:Hide()
        frame._kuiPvPShadow = shadow
    end

    local function RefreshForeverMetadata()
        local u = frame.unit or (frame.GetAttribute and frame:GetAttribute("unit")) or unit
        local profile = db and db.profile
        local settings = GetSettingsForUnit(u)
        local portraitBackdrop = frame.Portrait and frame.Portrait.backdrop
        local portraitVisible = profile and profile.portraitStyle ~= "none"
            and settings and settings.showPortrait ~= false
            and portraitBackdrop and portraitBackdrop:IsShown() or false
        local portraitAnchor = portraitVisible and portraitBackdrop or frame
        if frame.LeaderIndicator and frame.LeaderIndicator.ForceUpdate then
            frame.LeaderIndicator:ForceUpdate()
        else
            ns.RefreshGroupLeaderStyle(frame, u)
        end
        local portraitRing = frame._kuiClassificationPortraitRing
        if portraitBackdrop and not portraitRing then
            -- Keep the normal portrait border and render classification outside it.
            portraitRing = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
            portraitRing:SetTexCoord(0, 1, 0, 1)
            portraitRing:Hide()
            frame._kuiClassificationPortraitRing = portraitRing
        end
        -- KUI Style shows no level; only the stock-art styles
        -- (Classic/Forever/Retail) do.
        local levelTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
            and KT.VisualThemes:GetRenderedTheme() or "kui"
        local showLevel = levelTheme ~= "kui" and (not profile or profile.showCharacterLevel ~= false)
        local showClassification = not profile or profile.showClassification ~= false
        local noPortraitSize = math.max(8, tonumber(profile and profile.classificationNoPortraitSize) or CLASSIFICATION_NO_PORTRAIT_SIZE)
        ApplyForeverLevelTextStyle(frame._kuiLevelText, profile, portraitAnchor)
        local levelAnchor = profile and profile.levelAnchor
        frame._kuiLevelText:ClearAllPoints()
        if OVERLAY_ANCHORS[levelAnchor] then
            frame._kuiLevelText:SetPoint(levelAnchor, portraitAnchor, levelAnchor,
                tonumber(profile.levelX) or 0, tonumber(profile.levelY) or 0)
        elseif u == "target" then
            -- kui style (not the Classic/Forever/Retail ornament branch
            -- below): target's level is nudged right so it mirrors
            -- player's side.
            local targetLevelXNudge = 14
            frame._kuiLevelText:SetPoint("BOTTOMRIGHT", portraitAnchor, "TOPRIGHT",
                -(tonumber(profile and profile.levelX) or 2) + targetLevelXNudge, tonumber(profile and profile.levelY) or 2)
        else
            frame._kuiLevelText:SetPoint("BOTTOMLEFT", portraitAnchor, "TOPLEFT",
                tonumber(profile and profile.levelX) or 2, tonumber(profile and profile.levelY) or 2)
        end

        -- Classic AND Forever's stock portraits both have a small empty
        -- circle below their lower corner (both share the same 232x100
        -- native box design). Put the level inside that ornament instead
        -- of above the frame. Mirror the anchor for the target portrait on
        -- the right. Applies to Forever too, not just Classic, so the level
        -- circle backdrop (for legibility against the elite/rare ring) also
        -- shows there.
        local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
            and KT.VisualThemes:GetRenderedTheme()
        local classicKit = profile and profile.frameArtKit == "classic"
        local usingClassicLevelOrnament = (renderedTheme == "classic" or renderedTheme == "forever"
            or renderedTheme == "retail" or classicKit)
            and portraitVisible
        if usingClassicLevelOrnament then
            -- The 36/30.5 pair (from the frame edges) doesn't match
            -- Classic's own real ornament art: the level badge sits ~25
            -- units right and ~3 units above where Classic's real small gold
            -- ring ornament actually is. Forever/Retail's positioning under
            -- this same 36/30.5 pair is correct, so this corrects Classic
            -- only.
            local ox, oy = 36, 30.5
            if renderedTheme == "classic" then
                ox, oy = 55, 35
            end
            local classicScale = (frame.GetWidth and frame:GetWidth() or 232) / 232
            if not classicScale or classicScale <= 0 then classicScale = 1 end
            frame._kuiLevelText:SetSize(18 * classicScale, 14 * classicScale)
            frame._kuiLevelText:ClearAllPoints()
            -- The circle (below) anchors at the true geometric center. The
            -- number visually sits 2-3px left of that center at this size --
            -- likely the OUTLINE font's own glyph metrics, not a positioning
            -- issue (the two anchors are identical). Nudge the TEXT only,
            -- same absolute screen direction for both units, so it lands
            -- visually centered inside the (unmoved) circle.
            local levelTextXNudge = 1 * classicScale
            -- Pulls the level inward toward the portrait on whichever side
            -- each unit anchors from, applied to BOTH units symmetrically
            -- (same magnitude): the underlying 60/33 base otherwise sits too
            -- far out and overlaps the portrait on both sides.
            local levelXNudge = 0
            if u == "target" then
                frame._kuiLevelText:SetPoint("CENTER", frame, "BOTTOMRIGHT",
                    -ox * classicScale + levelTextXNudge + levelXNudge, oy * classicScale)
            else
                frame._kuiLevelText:SetPoint("CENTER", frame, "BOTTOMLEFT",
                    ox * classicScale + levelTextXNudge - levelXNudge, oy * classicScale)
            end
            frame._kuiLevelText:SetJustifyH("CENTER")

            -- Backdrop circle: sized a bit larger than the number itself
            -- and centered on the exact same point, so it paints over
            -- whatever the elite/rare ring draws in that spot. 20px is too
            -- small: the dragon ring's own wing/spike art extends further
            -- inward than a 20px circle covers, so it crosses over the
            -- circle's top edge even though the frame-level stacking
            -- (63 > 62) is correct. This isn't a z-order problem, it's a
            -- coverage-area problem -- enlarged accordingly.
            local circleSize = 32 * classicScale
            frame._kuiLevelCircle:ClearAllPoints()
            frame._kuiLevelCircle:SetSize(circleSize, circleSize)
            if frame._kuiLevelCircleMask then
                -- Full-canvas round mask: fits the badge exactly, no expansion.
                frame._kuiLevelCircleMask:ClearAllPoints()
                frame._kuiLevelCircleMask:SetAllPoints(frame._kuiLevelCircle)
            end
            if u == "target" then
                frame._kuiLevelCircle:SetPoint("CENTER", frame, "BOTTOMRIGHT",
                    -ox * classicScale + levelXNudge, oy * classicScale)
            else
                frame._kuiLevelCircle:SetPoint("CENTER", frame, "BOTTOMLEFT",
                    ox * classicScale - levelXNudge, oy * classicScale)
            end
            ns.CenterStockLevelText(frame._kuiLevelText, frame._kuiLevelCircle, renderedTheme)
        else
            -- Restore the normal metadata box when leaving Classic, so a
            -- later theme switch does not retain the small stock ornament
            -- dimensions or the mirrored justification.
            frame._kuiLevelText:SetSize(38, 14)
            frame._kuiLevelText:SetJustifyH("LEFT")
            frame._kuiLevelCircle:Hide()
        end

        frame._kuiClassificationIndicator:ClearAllPoints()
        if portraitVisible then
            -- The artwork has a transparent center; enlarge it so that
            -- its inner opening surrounds the portrait instead of covering it.
            local portraitSize = portraitBackdrop:GetWidth()
            if portraitSize < 1 then portraitSize = 46 end
            local ringWidth = math.max(24, portraitSize * CLASSIFICATION_PORTRAIT_SCALE)
            local ringHeight = ringWidth * CLASSIFICATION_TEXTURE_ASPECT
            frame._kuiClassificationIndicator:SetSize(ringWidth, ringHeight)
            frame._kuiClassificationIndicator:SetPoint("CENTER", portraitBackdrop, "CENTER", 0, 0)
        else
            -- Use the large artwork as an overlay when portraits are off.
            frame._kuiClassificationIndicator:SetSize(noPortraitSize, noPortraitSize)
            -- Keep the icon outside the health bar and away from level text.
            AnchorNoPortraitClassificationIndicator(frame, frame._kuiClassificationIndicator, profile)
        end
        frame._kuiPvPIcon:ClearAllPoints()
        local pvpAnchor = profile and profile.pvpAnchor
        if OVERLAY_ANCHORS[pvpAnchor] then
            frame._kuiPvPIcon:SetPoint(pvpAnchor, portraitAnchor, pvpAnchor,
                tonumber(profile.pvpX) or 0, tonumber(profile.pvpY) or 0)
        elseif u == "target" then
            frame._kuiPvPIcon:SetPoint("LEFT", portraitAnchor, "RIGHT", 2, 1)
        else
            frame._kuiPvPIcon:SetPoint("RIGHT", portraitAnchor, "LEFT", -2, 1)
        end
        -- Anchor the circle to the icon's own resolved position (whichever
        -- of the branches above actually applied) instead of duplicating
        -- the branching -- guarantees exact alignment regardless of anchor
        -- settings, and automatically tracks any future change to the
        -- icon's own anchor logic.
        frame._kuiPvPCircle:ClearAllPoints()
        frame._kuiPvPCircle:SetSize(24, 24)
        frame._kuiPvPCircle:SetPoint("CENTER", frame._kuiPvPIcon, "CENTER", 0, 0)
        frame._kuiPvPCircleBorder:ClearAllPoints()
        frame._kuiPvPCircleBorder:SetSize(26, 26)
        frame._kuiPvPCircleBorder:SetPoint("CENTER", frame._kuiPvPIcon, "CENTER", 0, 0)
        -- Border color depends on the active theme -- yellow for
        -- Classic/Retail, bronze for Forever.
        do
            local cr, cg, cb = ns.GetThemeOrnamentColor(renderedTheme, { 0.42, 0.43, 0.46 }) -- Classic: dark grey
            -- Player on Classic with an Elite border (modern or Classic card): gold circle.
            if renderedTheme == "classic" and u == "player" and profile then
                local pc = profile.playerClassificationBorder
                if pc == "elite" or pc == "classicelite" then cr, cg, cb = 0.96, 0.76, 0.22 end
            end
            -- Retail/Forever with the player's RARE border selected: dark grey circle.
            if (renderedTheme == "retail" or renderedTheme == "forever") and u == "player" and profile then
                local pc = profile.playerClassificationBorder
                if pc == "rare" or pc == "classicrare" then cr, cg, cb = 0.42, 0.43, 0.46 end
            end
            frame._kuiPvPCircleBorder:SetVertexColor(cr, cg, cb, 1)
        end
        local levelText = showLevel and SafeUnitLevelText(u) or nil
        -- Blizzard's own level text in the stock-art styles: GameNormalNumberFont
        -- (scaled with the frame art) and Blizzard's level color rules.
        local blizzardLevel = renderedTheme == "forever" or renderedTheme == "retail"
            or ns.StockStyleToggle(profile, "levelBlizzardStyle", renderedTheme)
        if blizzardLevel then
            local path, size, flags = ns.BlizzardFont("GameNormalNumberFont", "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            local artScale = 1
            if usingClassicLevelOrnament then
                artScale = (frame.GetWidth and frame:GetWidth() or 232) / 232
                if not artScale or artScale <= 0 then artScale = 1 end
            end
            if (renderedTheme == "retail" or renderedTheme == "forever") and KT.VisualThemes.ApplyBlizzardBarText then
                KT.VisualThemes:ApplyBlizzardBarText(frame._kuiLevelText, artScale, nil, "GameNormalNumberFont")
            else
                frame._kuiLevelText._ktBlizzBar = nil
                frame._kuiLevelText:SetFont(path, math.max(6, size * artScale), flags)
            end
            frame._kuiLevelText:SetTextColor(ns.BlizzardLevelColor(u, renderedTheme))
        end
        -- In combat Blizzard swaps the level number for its combat icon inside
        -- the level circle (modern icon on Retail/Forever, the old one on Classic).
        local combatIcon = frame._kuiLevelCombatIcon
        local showCombatIcon = levelText and usingClassicLevelOrnament
            and ns.StockStyleToggle(profile, "levelCombatIcon", renderedTheme)
            and ns.UnitInCombat(u)
        if showCombatIcon then
            -- Same host as the level number, which sits above the level ring art.
            local iconHost = frame._kuiLevelText:GetParent() or frame
            if not combatIcon then
                combatIcon = iconHost:CreateTexture(nil, "OVERLAY", nil, 7)
                frame._kuiLevelCombatIcon = combatIcon
            elseif combatIcon:GetParent() ~= iconHost then
                combatIcon:SetParent(iconHost)
            end
            local artScale = (frame.GetWidth and frame:GetWidth() or 232) / 232
            if not artScale or artScale <= 0 then artScale = 1 end
            ns.ApplyBlizzardCombatIcon(combatIcon, renderedTheme, 26 * artScale)
            combatIcon:ClearAllPoints()
            combatIcon:SetPoint("CENTER", frame._kuiLevelCircle, "CENTER", 0, 0)
            combatIcon:Show()
        elseif combatIcon then
            combatIcon:Hide()
        end
        if levelText then
            frame._kuiLevelText:SetText(levelText)
            frame._kuiLevelText:SetShown(not showCombatIcon)
            if usingClassicLevelOrnament then
                frame._kuiLevelCircle:Show()
            else
                frame._kuiLevelCircle:Hide()
            end
        else
            frame._kuiLevelText:Hide()
            frame._kuiLevelCircle:Hide()
        end
        local classificationTexture
        if showClassification then
            classificationTexture = portraitVisible
                and SafeUnitClassificationTexture(u)
                or SafeUnitClassificationNoPortraitTexture(u, profile)
        end
        -- Custom Player rare/elite border (option in Unit Frames): the player is
        -- never classified, so force the chosen overlay. Forever/Retail also hide
        -- their bronze base art below; Classic keeps its art.
        local borderChoice = (u == "player" and profile) and profile.playerClassificationBorder or nil
        local playerClassicRingKind = (borderChoice == "classicrare" and "rare")
            or (borderChoice == "classicelite" and "elite") or nil
        local playerCustomBorder = (u == "player" and profile
            and (CLASSIFICATION_TEXTURES[borderChoice == "rare" and "rare"
                or borderChoice == "elite" and "elite" or "none"]
                or (playerClassicRingKind and ns.ClassicRing.sheets[playerClassicRingKind]))) or nil
        if playerCustomBorder then
            classificationTexture = portraitVisible and playerCustomBorder
                or CLASSIFICATION_NO_PORTRAIT_TEXTURES.elite
        end
        -- Retail/Forever native Rare/Elite overlay (Blizzard atlas), picked in Unit
        -- Frames: the Player's border card, or the Target's overlay art option.
        local nativeKind
        if portraitVisible and portraitBackdrop then
            if u == "player" then
                if borderChoice == "nativerare" then nativeKind = "rare"
                elseif borderChoice == "nativeelite" then nativeKind = "elite" end
            elseif u == "target" and showClassification and profile
                and profile.targetClassificationArt == "native" then
                nativeKind = ns.NativeClassificationKind(SafeUnitClassification(u))
            end
            if nativeKind and not ns.HasNativeClassificationArt(nativeKind) then nativeKind = nil end
        end
        if nativeKind then
            classificationTexture = nil
            playerCustomBorder = nil
            playerClassicRingKind = nil
        end
        local previousNativeKind = frame._ktNativeClassificationKind
        -- The native dragon goes around the style's own frame like every other
        -- Rare/Elite ring, so the stock renderers keep their normal geometry.
        frame._ktNativeClassificationKind = nil
        frame._ktNativeClassificationScale = 1
        frame._ktNativeClassificationHeadReach = nil
        frame._ktClassRingReach = ns.ClassificationRingReach(renderedTheme, classicKit)
        frame._ktClassRingFit = ns.NativeRingFit((classicKit and "classic") or renderedTheme)
        if portraitBackdrop then
            portraitBackdrop._ktNativeClassificationActive = false
            portraitBackdrop._ktNativeClassificationScale = 1
        end
        if previousNativeKind ~= nativeKind and portraitBackdrop
            and (renderedTheme == "forever" or renderedTheme == "retail") then
            local VT2 = KT.VisualThemes
            if VT2 and VT2.ApplyForeverUnitFrameArt then
                VT2:ApplyForeverUnitFrameArt(frame, portraitBackdrop, u)
            end
        end
        if previousNativeKind and not nativeKind and portraitBackdrop
            and not portraitBackdrop._ktStockPortraitAnchor then
            ApplyDetachedPortraitShape(portraitBackdrop, settings, u)
        end
        -- Classic style: Blizzard's own Rare/Elite sheet replaces the whole frame art
        -- (instead of drawing the custom ring), for the player's chosen border and
        -- for elite/rare targets.
        if (renderedTheme == "classic" or classicKit) and (u == "player" or u == "target") then
            local kind
            if u == "player" then
                -- Only the Classic cards swap the sheet; the modern Rare/Elite cards keep
                -- drawing the custom ring over the Classic frame.
                if borderChoice == "classicrare" then kind = "rare"
                elseif borderChoice == "classicelite" then kind = "elite" end
            elseif showClassification and not nativeKind then
                kind = ns.ClassicRing.KindForClassification(SafeUnitClassification(u))
            end
            -- Remembered on the frame so ApplyClassicUnitFrameArt (re-run on every
            -- style pass) keeps the chosen sheet instead of resetting to the base one.
            frame._ktClassicSheetPath = kind and ns.ClassicRing.sheets[kind] or nil
            if frame._ktClassicPortraitArt then
                frame._ktClassicPortraitArt:SetTexture(frame._ktClassicSheetPath or ns.ClassicRing.base)
            end
            if kind then
                classificationTexture = nil
                playerCustomBorder = nil
                playerClassicRingKind = nil
            end
        end
        local usesForeverArt = renderedTheme == "forever" or renderedTheme == "retail"
        if (u == "player" or u == "target") and not usesForeverArt then
            frame._ktHideForeverPortraitArt = false
        end
        if u == "player" and usesForeverArt then
            -- Rare/Elite rings go around the stock portrait ornament.
            local hideBaseArt = false
            -- Persist the replacement state on the frame so every renderer
            -- pass (including delayed atlas retries) keeps the Forever art
            -- hidden while PLAYER uses a Rare/Elite border.
            frame._ktHideForeverPortraitArt = hideBaseArt
            local wantCircular = hideBaseArt
            if (frame._ktCircularPortrait and true or false) ~= wantCircular then
                frame._ktCircularPortrait = wantCircular
                local VT2 = KT.VisualThemes
                if VT2 and VT2.ApplyForeverUnitFrameArt and portraitBackdrop then
                    VT2:ApplyForeverUnitFrameArt(frame, portraitBackdrop, u)
                end
            end
            -- Hide immediately even if atlas data is temporarily unavailable.
            -- Restoration is handled by ApplyForeverUnitFrameArt above so it
            -- restores only the correct side's corner patch, never both.
            if hideBaseArt then
                if frame._ktForeverPortraitArt then frame._ktForeverPortraitArt:Hide() end
                if frame._ktForeverPortraitArtFill then frame._ktForeverPortraitArtFill:Hide() end
                if frame._ktForeverPortraitCornerPatch then frame._ktForeverPortraitCornerPatch:Hide() end
                if frame._ktForeverPortraitCornerPatch2 then frame._ktForeverPortraitCornerPatch2:Hide() end
            end
        end
        -- Elite/rare/worldboss targets get ONLY the classification overlay
        -- (the thorn/dragon ring) -- the base stock-art ring is hidden FOR
        -- them specifically, since the classification overlay replaces it
        -- as the visual callout. Every other target keeps the normal base
        -- ring.
        -- Target ONLY: the player character can never have an elite/rare
        -- classification (that concept only applies to NPCs you target),
        -- so applying this to player too would permanently hide its ring.
        -- Classic keeps the ring unconditionally (Blizzard's real Classic
        -- TargetingFrame has no such distinction).
        if u == "target" and (renderedTheme == "forever" or renderedTheme == "retail") then
            local rawClassification = SafeUnitClassification(u)
            local isEliteOrRare = CLASSIFICATION_TEXTURES[rawClassification] ~= nil
            local hasClassificationOverlay = showClassification and isEliteOrRare
                and (classificationTexture ~= nil or nativeKind ~= nil)
            -- Rare/Elite rings go around the stock ring instead of replacing it.
            local showBaseRing = true
            -- Persist this for delayed atlas/layout passes too; otherwise one
            -- of those passes can briefly resurrect the stock ring underneath
            -- the Rare/Elite overlay and make the frame appear to jump.
            frame._ktHideForeverPortraitArt = not showBaseRing
            local wantCircular = not showBaseRing
            if (frame._ktCircularPortrait and true or false) ~= wantCircular then
                frame._ktCircularPortrait = wantCircular
                local VT2 = KT.VisualThemes
                if VT2 and VT2.ApplyForeverUnitFrameArt and portraitBackdrop then
                    VT2:ApplyForeverUnitFrameArt(frame, portraitBackdrop, u)
                end
            end
            frame._ktDebugClassification = tostring(rawClassification)
            frame._ktDebugEliteOrRare = tostring(isEliteOrRare)
            frame._ktDebugArtShownField = tostring(frame._ktForeverPortraitArt ~= nil)
            if showBaseRing then
                -- Restore only the corner patch belonging to this side.
                local VT2 = KT.VisualThemes
                if VT2 and VT2.ApplyForeverUnitFrameArt and portraitBackdrop then
                    VT2:ApplyForeverUnitFrameArt(frame, portraitBackdrop, u)
                end
            else
                if frame._ktForeverPortraitArt then frame._ktForeverPortraitArt:Hide() end
                if frame._ktForeverPortraitArtFill then frame._ktForeverPortraitArtFill:Hide() end
                if frame._ktForeverPortraitCornerPatch then frame._ktForeverPortraitCornerPatch:Hide() end
                if frame._ktForeverPortraitCornerPatch2 then frame._ktForeverPortraitCornerPatch2:Hide() end
            end
        end
        -- Rare/Elite hides the whole stock atlas: keep the frame around the bars.
        if (u == "player" or u == "target") and ns.BarFrameArt and ns.BarFrameArt.Update then
            pcall(ns.BarFrameArt.Update, frame, u)
        end
        local pvpFaction = (profile and profile.showPvPIcon ~= false
            and (u == "player" or u == "target"))
            and SafeUnitPvPFaction(u) or nil
        -- The backdrop circle defaults OFF for kui style, with its own
        -- toggle so kui users can still turn it on. The real default is
        -- recomputed here every refresh rather than relying only on the
        -- seed()+one-time-migration default (seed only runs on an explicit
        -- theme switch; the migration only runs once, guarded by its own
        -- flag), which can miss an existing kui profile: once the user has
        -- explicitly toggled it (profile.showPvPCircle is no longer nil),
        -- that choice always wins; until then, it follows the CURRENT
        -- theme directly instead of trusting a historical snapshot.
        local showPvPCircle
        if renderedTheme == "kui" then
            -- kui style never draws the backdrop circle (icon gets a shadow instead).
            showPvPCircle = false
        elseif profile and profile.showPvPCircle ~= nil then
            showPvPCircle = profile.showPvPCircle
        else
            showPvPCircle = renderedTheme ~= "kui"
        end
        -- PvP icon style: "modern" (ours) or "classic" (stock banner, cropped to
        -- the 42/64 art area).  Default: the
        -- Classic style in the Classic theme, ours everywhere else.
        local pvpStyle
        if profile then
            if u == "target" then pvpStyle = profile.pvpIconStyleTarget
            else pvpStyle = profile.pvpIconStyle end
        end
        if pvpStyle ~= "modern" and pvpStyle ~= "classic" then
            pvpStyle = (renderedTheme == "classic") and "classic" or "modern"
        end
        if pvpFaction == "Horde" or pvpFaction == "Alliance" then
            if pvpStyle == "classic" then
                frame._kuiPvPIcon:SetSize(28, 28)
                frame._kuiPvPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. pvpFaction)
                frame._kuiPvPIcon:SetTexCoord(0, 0.65625, 0, 0.65625)
                frame._kuiPvPShadow:Hide()
                -- The stock banner has its own plate: no backdrop circle.
                frame._kuiPvPCircle:Hide()
                frame._kuiPvPCircleBorder:Hide()
            else
                frame._kuiPvPIcon:SetSize(16, 16)
                frame._kuiPvPIcon:SetTexture(PVP_ICON_PATH .. pvpFaction .. ".png")
                frame._kuiPvPIcon:SetTexCoord(0, 1, 0, 1)
                frame._kuiPvPShadow:SetTexture(PVP_ICON_PATH .. pvpFaction .. ".png")
                -- KUI Style keeps the Retail icon (no extra shadow).
                frame._kuiPvPShadow:Hide()
                frame._kuiPvPCircle:SetShown(showPvPCircle)
                frame._kuiPvPCircleBorder:SetShown(showPvPCircle)
            end
            frame._kuiPvPIcon:Show()
        else
            -- PvP disabled or no faction on this unit removes the backdrop
            -- circle (and its border) too, never independently.
            frame._kuiPvPIcon:Hide()
            frame._kuiPvPShadow:Hide()
            frame._kuiPvPCircle:Hide()
            frame._kuiPvPCircleBorder:Hide()
        end
        if ns.KUIOrnaments then pcall(ns.KUIOrnaments.ApplyPvPCircle, frame) end
        if frame._kuiClassicRingTex then frame._kuiClassicRingTex:Hide() end
        if ns.KUIOrnaments then ns.KUIOrnaments.HideClassicDragon(frame._kuiClassicRingTex) end
        if not (renderedTheme == "classic" or classicKit) then frame._ktClassicSheetPath = nil end
        if classificationTexture then
            local isFlipped = GetClassificationTextureFlipped(u, settings)
            if portraitVisible and portraitBackdrop and portraitRing then
                portraitRing:SetTexture(classificationTexture)
                portraitRing:SetTexCoord(isFlipped and 1 or 0, isFlipped and 0 or 1, 0, 1)
                local portraitSize = portraitBackdrop:GetWidth()
                if portraitSize < 1 then portraitSize = 46 end
                if playerClassicRingKind then
                    -- Crop of Blizzard Classic's player Rare/Elite sheet around the portrait.
                    -- Drawn on its own host frame that sits BELOW the level/PvP overlay frame
                    -- (iOvr + 1), so level text, PvP circle and PvP icon always render above it.
                    local CR = ns.ClassicRing
                    local host = frame._kuiClassicRingHost
                    if not host then
                        host = CreateFrame("Frame", nil, frame)
                        host:SetAllPoints(frame)
                        host:EnableMouse(false)
                        frame._kuiClassicRingHost = host
                    end
                    host:SetFrameStrata(iOvr:GetFrameStrata())
                    host:SetFrameLevel(math.max(1, iOvr:GetFrameLevel() - 1))
                    local ct = frame._kuiClassicRingTex
                    if not ct then
                        ct = host:CreateTexture(nil, "OVERLAY", nil, 7)
                        frame._kuiClassicRingTex = ct
                    end
                    portraitRing:Hide()
                    local stockArt = renderedTheme == "forever" or renderedTheme == "retail"
                    local sc = CR.ArtScale(portraitBackdrop, ns.ClassificationRingReach(renderedTheme, classicKit, true))
                    ct:SetTexture(CR.dragons[playerClassicRingKind] or classificationTexture)
                    ct:SetTexCoord(CR.uLeft, CR.uRight, CR.vTop, CR.vBottom)
                    ct:SetSize(CR.cropW * sc, CR.cropH * sc)
                    ct:ClearAllPoints()
                    ct:SetPoint("TOPLEFT", portraitBackdrop, "CENTER",
                        -CR.portraitCX * sc, CR.portraitCY * sc)
                    portraitBackdrop:SetClipsChildren(false)
                    ct:Show()
                    if ns.KUIOrnaments then
                        ns.KUIOrnaments.FitClassicDragon(ct, portraitBackdrop, CR,
                            playerClassicRingKind, sc, classicKit and "classic" or renderedTheme)
                    end
                    frame._kuiClassificationPortraitActive = true
                    frame._kuiClassificationIndicator:Hide()
                    if frame._ktRingHugShift and stockArt then
                        -- The stock ring stays under the dragon: bars keep their stock place.
                        frame._ktRingHugShift = nil
                        local VT3 = KT.VisualThemes
                        if VT3 and VT3.ApplyForeverUnitFrameArt then
                            VT3:ApplyForeverUnitFrameArt(frame, portraitBackdrop, u)
                        end
                    end
                else
                -- Shrinking the ring itself (tried previously) couldn't
                -- actually clear the level position without looking broken
                -- -- the level sits closer to the portrait's center than
                -- any reasonably-sized ring's edge, so an opaque backdrop
                -- circle drawn above the ring (frame._kuiLevelCircle) now
                -- solves the real conflict directly. Ring keeps its normal
                -- overhang.
                local MR = ns.ModernClassificationRing
                local ringSize = portraitBackdrop:GetHeight() or 0
                if ringSize < 1 then ringSize = portraitSize end
                local ringWidth = math.max(24, ringSize
                    * ns.ModernRingReach(renderedTheme, classicKit) / MR.holeRadius)
                local ringHeight = ringWidth * CLASSIFICATION_TEXTURE_ASPECT
                portraitRing:SetSize(ringWidth, ringHeight)
                portraitRing:ClearAllPoints()
                -- The opening is not centred in the PNG (mirrored when flipped).
                local nudgeX, nudgeY = ns.ModernRingNudge(renderedTheme)
                portraitRing:SetPoint("CENTER", portraitBackdrop, "CENTER",
                    (isFlipped and -(MR.centerX + nudgeX) or (MR.centerX + nudgeX)) * ringWidth,
                    (MR.centerY + nudgeY) * ringHeight)
                portraitBackdrop:SetClipsChildren(false)
                portraitRing:Show()
                frame._kuiClassificationPortraitActive = true
                frame._kuiClassificationIndicator:Hide()
                end
            else
                frame._kuiClassificationPortraitActive = false
                if portraitRing then portraitRing:Hide() end
                if portraitBackdrop then portraitBackdrop:SetClipsChildren(true) end
                frame._kuiClassificationIndicator:SetTexture(classificationTexture)
                frame._kuiClassificationIndicator:SetTexCoord(isFlipped and 1 or 0, isFlipped and 0 or 1, 0, 1)
                frame._kuiClassificationIndicator:Show()
            end
        else
            frame._kuiClassificationPortraitActive = false
            frame._kuiClassificationIndicator:Hide()
            if portraitRing then portraitRing:Hide() end
            if portraitBackdrop then portraitBackdrop:SetClipsChildren(true) end
        end
        do
            -- Stock styles own their portrait side; a saved KUI side must
            -- not mirror the native atlas against a different portrait.
            local stockSide = usesForeverArt or renderedTheme == "classic" or classicKit
            local side = stockSide and ((u == "target") and "right" or "left")
                or (settings and settings.portraitSide)
                or ((u == "player" or u == "pet") and "left" or "right")
            if ns.ShowNativeClassificationRing(frame, portraitBackdrop, nativeKind, side == "left", iOvr) then
                frame._kuiClassificationPortraitActive = true
            end
            if ns.BarFrameArt and ns.BarFrameArt.Update then ns.BarFrameArt.Update(frame, u) end
        end
        if ns.KUIOrnaments then pcall(ns.KUIOrnaments.ApplyLevelCircle, frame) end
        -- KUI Style: with the Rare/Elite ring on the Player portrait, nudge the PvP
        -- icon 2px to the left (the icon was re-anchored from scratch above, so
        -- this never accumulates).
        if renderedTheme == "kui" and u == "player" and frame._kuiClassificationPortraitActive
            and frame._kuiPvPIcon then
            local pt, rel, relPt, px, py = frame._kuiPvPIcon:GetPoint(1)
            if pt then
                frame._kuiPvPIcon:SetPoint(pt, rel, relPt, (px or 0) - 2, py or 0)
            end
        end
        if frame._ktRingHugShift and not frame._kuiClassificationPortraitActive then
            frame._ktRingHugShift = nil
            local VT3 = KT.VisualThemes
            if VT3 and VT3.ApplyForeverUnitFrameArt and portraitBackdrop
                and (renderedTheme == "forever" or renderedTheme == "retail") then
                VT3:ApplyForeverUnitFrameArt(frame, portraitBackdrop, u)
            end
        end
        if u == "target" and ns.KTTargetCombo then
            ns.KTTargetCombo:Refresh(frame)
        end
        -- Keep the normal border visible underneath the external classification ring.
        local portraitBorder = portraitBackdrop and portraitBackdrop._shapeBorderTex
        -- Rare/Elite rings go around this border, never replace it.
        if portraitBorder then
            if profile and profile.portraitStyle == "detached" then
                ApplyDetachedPortraitShape(portraitBackdrop, settings, u)
            else
                UpdateCircularPortraitBorder(frame)
            end
        end
    end

    local function QueueForeverMetadataRefresh()
        if frame._kuiMetadataRefreshQueued then return end
        frame._kuiMetadataRefreshQueued = true
        RefreshForeverMetadata()
        if not (C_Timer and C_Timer.After) then
            frame._kuiMetadataRefreshQueued = nil
            return
        end
        -- One next-frame settlement is enough for portrait/bar dimensions to
        -- become final. The former timed burst repainted the art nine times per
        -- event and made the ring visibly jump while the frame was appearing.
        C_Timer.After(0, function()
            if frame._refreshForeverMetadata then
                frame._refreshForeverMetadata()
            end
            frame._kuiMetadataRefreshQueued = nil
        end)
    end

    frame._refreshForeverMetadata = RefreshForeverMetadata
    frame._refreshForeverMetadataSoon = QueueForeverMetadataRefresh
    if not frame._kuiForeverMetadataEvents then
        frame._kuiForeverMetadataEvents = true
        for _, ev in ipairs({
            "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
            "GROUP_ROSTER_UPDATE", "UNIT_LEVEL", "UNIT_FLAGS", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION", "PLAYER_FLAGS_CHANGED",
            -- Power values already update through Power.PostUpdate. Metadata
            -- only needs a refresh when the displayed power type changes.
            "UNIT_DISPLAYPOWER", "UPDATE_SHAPESHIFT_FORM", "PLAYER_SPECIALIZATION_CHANGED",
            "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        }) do
            frame:RegisterEvent(ev, function()
                QueueForeverMetadataRefresh()
            end, true)
        end
    end
    QueueForeverMetadataRefresh()
    -- â”€â”€ Leader â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if not frame.LeaderIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(KUI_ICON_PATH .. "Leader.png")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(14, 14)
        tex:SetPoint("TOPLEFT", health, "TOPLEFT", -2, 10)
        tex:Hide()
        frame.LeaderIndicator = tex
        tex.PostUpdate = function(self, isLeader, isInLFGInstance)
            ns.RefreshGroupLeaderStyle(frame, frame.unit or unit, isInLFGInstance)
        end
    end

    -- â”€â”€ Assistant â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if not frame.AssistantIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(KUI_ICON_PATH .. "Assistant.png")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(14, 14)
        tex:SetPoint("TOPLEFT", health, "TOPLEFT", -2, 10)
        tex:Hide()
        if unit ~= "player" then
            frame.AssistantIndicator = tex
        end
    end

    -- â”€â”€ Resurrect â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if not frame.ResurrectIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(KUI_ICON_PATH .. "Resurrect.png")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(20, 20)
        tex:SetPoint("CENTER", health, "CENTER", 0, 0)
        tex:Hide()
        frame.ResurrectIndicator = tex
    end

    -- â”€â”€ Summon â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    if not frame.SummonIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(KUI_ICON_PATH .. "Summon.png")
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(20, 20)
        tex:SetPoint("CENTER", health, "CENTER", 0, 0)
        tex:Hide()
        frame.SummonIndicator = tex
    end

    -- â”€â”€ Raid Target (marcas estÃ¡ndar de Blizzard, no icono custom) â”€â”€
    if not frame.RaidTargetIndicator then
        local tex = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        tex:SetSize(18, 18)
        -- Mirror the combat indicator below the bar. This keeps the raid marker
        -- away from the resting/status icons that occupy the upper-left corner.
        tex:SetPoint("TOP", health, "BOTTOM", 0, -2)
        tex:Hide()
        frame.RaidTargetIndicator = tex
    end

    -- â”€â”€ Status Overlay: AFK / Dead / Ghost / Offline â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    -- Implementado como textura + texto sobre un frame de alto nivel.
    -- Solo se muestra uno a la vez (prioridad: Offline > Dead > Ghost > AFK).
    if not frame._kuiStatusOverlay then
        local ovr = CreateFrame("Frame", nil, iOvr)
        ovr:SetAllPoints(health)
        ovr:SetFrameLevel(iOvr:GetFrameLevel() + 2)
        ovr:Hide()

        local icon = ovr:CreateTexture(nil, "OVERLAY", nil, 7)
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER", ovr, "CENTER", 0, 0)
        ovr._icon = icon

        frame._kuiStatusOverlay = ovr
    end

    -- Determinar y mostrar el estado adecuado de la unidad
    local function RefreshStatusOverlay()
        local ovr = frame._kuiStatusOverlay
        if not ovr then return end
        local u = frame.unit or frame:GetAttribute("unit") or unit
        if not u or not UnitExists(u) then ovr:Hide(); return end

        local iconPath, text
        local isConnected = SafeBoolCall(UnitIsConnected, u)
        local isDeadOrGhost = SafeBoolCall(UnitIsDeadOrGhost, u)
        local isGhost = isDeadOrGhost and SafeBoolCall(UnitIsGhost, u)
        local isAFK = SafeBoolCall(UnitIsAFK, u)

        if isConnected == false then
            iconPath = KUI_ICON_PATH .. "Offline.png"
            text = "Offline"
        elseif isDeadOrGhost == true then
            if isGhost == true then
                iconPath = KUI_ICON_PATH .. "Ghost.png"
                text = "Ghost"
            else
                iconPath = KUI_ICON_PATH .. "Dead.png"
                text = "Dead"
            end
        elseif isAFK == true then
            iconPath = KUI_ICON_PATH .. "AFK.png"
            text = "AFK"
        end

        if iconPath then
            if text == "AFK" then
                ovr._icon:SetSize(32, 16)
            else
                ovr._icon:SetSize(18, 18)
            end
            ovr._icon:SetTexture(iconPath)
            ovr._icon:SetTexCoord(0, 1, 0, 1)
            ovr:Show()
            -- The status icon and the health value text both center on the
            -- bar (centering the value text makes it overlap the
            -- always-centered AFK/Dead/Ghost/Offline icon into unreadable
            -- mixed text). Real Blizzard shows one or the other, never
            -- both. Never hides whichever FontString currently serves as
            -- the name tab (frame._ktStockNameText), which lives above the
            -- bar, not on it, and must stay visible regardless.
            if frame.RightText and frame.RightText ~= frame._ktStockNameText then
                frame.RightText:Hide()
            end
        else
            ovr:Hide()
            if frame.RightText and frame.RightText ~= frame._ktStockNameText then
                frame.RightText:Show()
            end
        end
    end

    frame._refreshStatusOverlay = RefreshStatusOverlay

    -- Registrar eventos solo una vez por frame
    if not frame._kuiStatusEvents then
        frame._kuiStatusEvents = true
        local evts = {
            "PLAYER_FLAGS_CHANGED", "UNIT_FLAGS",
            "UNIT_HEALTH", "UNIT_CONNECTION",
            "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE",
        }
        for _, ev in ipairs(evts) do
            frame:RegisterEvent(ev, function()
                RefreshStatusOverlay()
            end, true)
        end
    end
    RefreshStatusOverlay()
end

local function StyleFullFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    local powerPos = settings.powerPosition or "below"
    local powerIsAtt = (powerPos == "below" or powerPos == "above")
    local powerExtra = powerIsAtt and settings.powerHeight or 0
    local playerTargetHeight = settings.healthHeight + powerExtra
    local btbPos = settings.btbPosition or "bottom"
    local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
    local btbExtra = (settings.bottomTextBar and btbIsAttached) and (settings.bottomTextBarHeight or 16) or 0
    local targetFrameHeight = playerTargetHeight + btbExtra
    local totalWidth = 0
    local portraitHeight = playerTargetHeight
    local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    local isAttached = (db.profile.portraitStyle or "attached") == "attached"

    if unit == "player" then
        local pSide = settings.portraitSide or "left"
        -- For attached, "top" falls back to default side
        local effectiveSide = pSide
        if isAttached and pSide == "top" then effectiveSide = "left" end
        -- Class power "above" adds height above health bar ("top" floats outside)
        local cpAboveH = 0
        local cpSt = settings.classPowerStyle or "none"
        local cpPo = (cpSt == "modern") and (settings.classPowerPosition or "top") or "none"
        if cpSt == "modern" and cpPo == "above" then
            local cpSizeAdj = settings.classPowerSize or 8
            local cpPipH = math.max(3, math.floor(cpSizeAdj * 0.375))
            cpAboveH = cpPipH
        end
        local playerHeightWithCp = playerTargetHeight + cpAboveH
        -- Apply portrait size adjustment
        local pSizeAdj = settings.portraitSize or 0
        local adjPortraitH = playerHeightWithCp + pSizeAdj
        if adjPortraitH < 8 then adjPortraitH = 8 end
        if not isAttached then pSizeAdj = pSizeAdj + 10 end
        if not showPortrait then
            totalWidth = settings.frameWidth
            portraitHeight = 0
        elseif isAttached then
            totalWidth = adjPortraitH + settings.frameWidth
        else
            -- Detached: portrait doesn't contribute to frame width
            totalWidth = settings.frameWidth
            portraitHeight = 0
        end
        -- Health bar xOffset: only offset when portrait is attached on the left
        local healthXOffset = (showPortrait and isAttached and effectiveSide == "left") and adjPortraitH or 0
        local healthRightInset = (showPortrait and isAttached and effectiveSide == "right") and adjPortraitH or 0
        PP.Size(frame, totalWidth, playerHeightWithCp + btbExtra)
        frame.Health = CreateHealthBar(frame, unit, settings.healthHeight, healthXOffset, settings, healthRightInset)
        frame.Power = CreatePowerBar(frame, unit, settings)
        -- Always create absorb bar; oUF element disabled later if not wanted
        CreateAbsorbBar(frame, unit, settings)
        -- Always create portrait; hide backdrop when disabled
        frame.Portrait = CreatePortrait(frame, pSide, playerHeightWithCp, unit)
        frame._portraitSide = pSide
        if frame.Portrait and not showPortrait then
            frame.Portrait.backdrop:Hide()
        end
        ApplyClassicFrameArt(frame, unit)
        -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
        -- -- skipped when Forever/Classic real stock geometry is active: this
        -- unconditional dual TOPLEFT+RIGHT anchor would silently undo the
        -- real bar width ApplyClassicFrameArt just set, immediately above.
        if frame.Portrait and frame.Portrait.backdrop and showPortrait and isAttached and frame.Health
            and not (frame._ktForeverLayoutActive or frame._ktClassicLayoutActive) then
            local snappedPortW = frame.Portrait.backdrop:GetWidth()
            local newXOff = (effectiveSide == "left") and snappedPortW or 0
            local newRI = (effectiveSide == "right") and snappedPortW or 0
            local powerAboveOff = (powerPos == "above") and settings.powerHeight or 0
            local topOff = cpAboveH + powerAboveOff
            frame.Health:ClearAllPoints()
            PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", newXOff, -topOff)
            PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -newRI, 0)
            PP.Height(frame.Health, settings.healthHeight)
            frame.Health._xOffset = newXOff
            frame.Health._rightInset = newRI
            frame.Health._topOffset = topOff
        end

        -- Always create castbar; oUF element disabled later if not wanted
        frame.Castbar = CreateCastBar(frame, unit, settings)
        SetupShowOnCastBar(frame, "player")

        -- Always create player buffs; oUF element disabled later if not wanted
        do
            local auraAnchor, auraWidth, auraSize, gap, perRow = KT:ResolveUFAuraBarGeometry(frame)
            local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
                settings.buffAnchor, settings.buffGrowth
            )
            -- Offset bottom-anchored buffs below castbar when locked to frame
            local buffCbOffset = 0
            if (settings.buffAnchor == "bottomleft" or settings.buffAnchor == "bottomright"
                or settings.buffAnchor == "left" or settings.buffAnchor == "right")
                and settings.showPlayerCastbar then
                local cbH = settings.playerCastbarHeight or 0
                if cbH <= 0 then cbH = 14 end
                buffCbOffset = -cbH
            end
            local buffs = CreateFrame("Frame", nil, frame)
            buffs:SetPoint(bia, auraAnchor, bfp, box * gap,
                boy * gap + buffCbOffset + KT:GetKUIStyleBuffYOffset("player"))
            buffs:SetSize(auraWidth, auraSize)
            buffs.size = auraSize
            buffs.spacing = gap
            buffs.num = settings.maxBuffs or 4
            buffs["size-x"] = perRow
            buffs.initialAnchor = bia
            buffs.growthX = bgx
            buffs.growthY = bgy
            buffs.filter = "HELPFUL"
            buffs.PostCreateButton = function(_, button)
                if not button then return end
                if button.Icon then button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
                if button.Cooldown then
                    button.Cooldown:SetDrawEdge(false)
                    button.Cooldown:SetReverse(true)
                    button.Cooldown:SetHideCountdownNumbers(true)
                end
                if not button.Border then
                    button.Border = CreateFrame("Frame", nil, button)
                    button.Border:SetAllPoints()
                    button.Border:SetFrameLevel(button:GetFrameLevel() + 1)
                    PP.CreateBorder(button.Border, 0, 0, 0, 1)
                end
            end
            frame.Buffs = buffs
            frame._refreshAuraBarGeometry = function()
                local current = GetSettingsForUnit(frame.unit or unit or "player")
                local bfp2, bia2, bgx2, bgy2, box2, boy2 = ResolveBuffLayout(
                    current.buffAnchor, current.buffGrowth
                )
                local liveOffset = 0
                local liveAnchor = current.buffAnchor or "topleft"
                if current.showPlayerCastbar
                    and (liveAnchor == "bottomleft" or liveAnchor == "bottomright"
                        or liveAnchor == "left" or liveAnchor == "right")
                then
                    local castHeight = current.playerCastbarHeight or 0
                    if castHeight <= 0 then castHeight = 14 end
                    liveOffset = -castHeight
                end
                KT:ApplyLegacyUFAuraBarGeometry(frame.Buffs, frame, bfp2, bia2,
                    bgx2, bgy2, box2,
                    boy2 + liveOffset + KT:GetKUIStyleBuffYOffset("player"))
                if frame.Buffs.ForceUpdate then frame.Buffs:ForceUpdate() end
            end
            CreateUnitDispelSlots(frame, unit)
        end
    elseif unit == "target" then
        local pSide = settings.portraitSide or "right"
        -- For attached, "top" falls back to default side
        local effectiveSide = pSide
        if isAttached and pSide == "top" then effectiveSide = "right" end
        local pSizeAdj = settings.portraitSize or 0
        local adjPortraitH = playerTargetHeight + pSizeAdj
        if not isAttached then pSizeAdj = pSizeAdj + 10 end
        if adjPortraitH < 8 then adjPortraitH = 8 end
        if not showPortrait then
            totalWidth = settings.frameWidth
        elseif isAttached then
            totalWidth = adjPortraitH + settings.frameWidth
        else
            totalWidth = settings.frameWidth
        end
        local healthXOffset = (showPortrait and isAttached and effectiveSide == "left") and adjPortraitH or 0
        local healthRightInset = (showPortrait and isAttached and effectiveSide == "right") and adjPortraitH or 0
        PP.Size(frame, totalWidth, targetFrameHeight)
        frame.Health = CreateHealthBar(frame, unit, settings.healthHeight, healthXOffset, settings, healthRightInset)
        frame.Power = CreatePowerBar(frame, unit, settings)
        CreateAbsorbBar(frame, unit, settings)
        frame.Castbar = CreateCastBar(frame, unit, settings)
        SetupShowOnCastBar(frame, unit)
        frame.Portrait = CreatePortrait(frame, pSide, playerTargetHeight, unit)
        frame._portraitSide = pSide
        if frame.Portrait and not showPortrait then
            frame.Portrait.backdrop:Hide()
        end
        ApplyClassicFrameArt(frame, unit)
        -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
        -- -- skipped when Forever/Classic real stock geometry is active: see
        -- the identical player-branch comment above for why.
        if frame.Portrait and frame.Portrait.backdrop and showPortrait and isAttached and frame.Health
            and not (frame._ktForeverLayoutActive or frame._ktClassicLayoutActive) then
            local snappedPortW = frame.Portrait.backdrop:GetWidth()
            local newXOff = (effectiveSide == "left") and snappedPortW or 0
            local newRI = (effectiveSide == "right") and snappedPortW or 0
            local powerAboveOff = (powerPos == "above") and settings.powerHeight or 0
            frame.Health:ClearAllPoints()
            PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", newXOff, -powerAboveOff)
            PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -newRI, 0)
            PP.Height(frame.Health, settings.healthHeight)
            frame.Health._xOffset = newXOff
            frame.Health._rightInset = newRI
            frame.Health._topOffset = powerAboveOff
        end

        CreateTargetAuras(frame, unit)
    end

    -- Target frames do not receive a frame-wide dispel overlay.
    -- Their debuff icons retain the useful per-aura styling.
    if unit ~= 'target' then
        CreateUnitDispelBorder(frame)
    end
    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame -- sits above the StatusBar for clean text rendering.
    local textOverlay = CreateFrame("Frame", nil, frame.Health)
    textOverlay:SetAllPoints(frame.Health)
    if textOverlay.SetClipsChildren then
        textOverlay:SetClipsChildren(true)
    end
    textOverlay:SetFrameLevel(frame.Health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "both"
    local centerContent = settings.centerTextContent or "none"

    -- Crear FontStrings con sus tamaÃ±os individuales mediante iteraciÃ³n
    local textDefs = {
        { key = "LeftText",   size = settings.leftTextSize   or settings.textSize or 12 },
        { key = "RightText",  size = settings.rightTextSize  or settings.textSize or 12 },
        { key = "CenterText", size = settings.centerTextSize or settings.textSize or 12 },
    }
    for _, def in ipairs(textDefs) do
        local fs = textOverlay:CreateFontString(nil, "OVERLAY")
        SetFSFont(fs, def.size)
        fs:SetWordWrap(false)
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
        if fs.SetMaxLines then fs:SetMaxLines(1) end
        fs:SetTextColor(1, 1, 1)
        frame[def.key] = fs
    end
    local leftText, rightText, centerText = frame.LeftText, frame.RightText, frame.CenterText

    -- Alias de compatibilidad
    frame.NameText = leftText
    frame.HealthValue = rightText

    -- Aplicar tags oUF segÃºn contenido; iterar pares FontString-contenido
    local function ApplyTextTags(lc, rc, cc)
        local tagPairs = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, pair in ipairs(tagPairs) do
            local fs, content = pair[1], pair[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo full
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, textOverlay,
        {"name", "both", "none"}, true)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Bottom Text Bar
    if settings.bottomTextBar then
        local anchorFrame = (powerIsAtt and frame.Power) or frame.Health
        local btbPos = settings.btbPosition or "bottom"
        local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
        -- BTB spans full frame width; offset left when portrait is attached on the left
        local btbXOff = 0
        if btbIsAttached and showPortrait and isAttached then
            local pSide = settings.portraitSide or (unit == "player" and "left" or "right")
            local eSide = pSide
            if pSide == "top" then eSide = (unit == "player") and "left" or "right" end
            if eSide == "left" then
                local ppPos2 = settings.powerPosition or "below"
                local ppIsAtt2 = (ppPos2 == "below" or ppPos2 == "above")
                local barH = settings.healthHeight + (ppIsAtt2 and (settings.powerHeight or 6) or 0)
                local adj = barH + (settings.portraitSize or 0)
                if adj < 8 then adj = 8 end
                btbXOff = -adj
            end
        end
        frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, anchorFrame, btbXOff, totalWidth)
        frame._btb = frame.BottomTextBar
        -- Re-anchor cast bar below BTB only when BTB is attached at bottom
        if btbPos == "bottom" and frame.Castbar then
            local castbarBg = frame.Castbar:GetParent()
            if castbarBg and castbarBg:GetParent() == frame then
                castbarBg:ClearAllPoints()
                castbarBg:SetPoint("TOP", frame.BottomTextBar, "BOTTOM", 0, 0)
            end
        end
    end

    if unit == "player" then
        SetupPlayerStatusIndicators(frame, settings)
    end

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
    -- Text regions now exist; re-run the theme layout so the name tab and
    -- text strata are seated in the same stock geometry as the bars.
    ApplyClassicFrameArt(frame, unit)
end

SetupPlayerStatusIndicators = function(frame, settings)
    if not frame or not frame.Health then return end

    -- Reutilizar el overlay de indicadores de alto strata
    if not frame._kuiIndicatorOverlay then
        local ovr = CreateFrame("Frame", nil, frame)
        ovr:SetAllPoints(frame)
        ovr._kuiAbovePortraitOverlay = true
        ovr:SetFrameLevel(frame:GetFrameLevel() + 60)
        ns.ApplyOverlayStrata(ovr, frame)
        frame._kuiIndicatorOverlay = ovr
    end
    local iOvr = frame._kuiIndicatorOverlay

    if not frame.CombatIndicator then
        local combat = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        combat:Hide()
        frame.CombatIndicator = combat
        -- oUF can show its indicator again on UNIT_FLAGS, independently of
        -- the settings pass. Stock styles already own the level-circle icon.
        combat.PostUpdate = function(self)
            if ns.IsStockStyle() then self:Hide() end
        end
    elseif frame.CombatIndicator:GetParent() ~= iOvr then
        frame.CombatIndicator:SetParent(iOvr)
    end

    if not frame.RestingIndicator then
        local resting = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
        resting:Hide()
        frame.RestingIndicator = resting
        -- KUI Style keeps its own Zzz; Classic, Forever and Retail share
        -- Blizzard's original resting icon.
        local function ApplyRestingTexture(self)
            local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
                and KT.VisualThemes:GetRenderedTheme()
            local modern = theme == "forever" or theme == "retail"
            local atlas = "UI-HUD-UnitFrame-Player-Rest-Flipbook"
            if modern and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
                self:SetAtlas(atlas, false)
                if not self._ktRestAnimation then
                    local group = self:CreateAnimationGroup()
                    local flip = group:CreateAnimation("FlipBook")
                    flip:SetTarget(self)
                    flip:SetDuration(1.5)
                    flip:SetFlipBookRows(7)
                    flip:SetFlipBookColumns(6)
                    flip:SetFlipBookFrames(42)
                    group:SetLooping("REPEAT")
                    self._ktRestAnimation = group
                end
                if IsResting() then self._ktRestAnimation:Play() else self._ktRestAnimation:Stop() end
            elseif ns.IsStockStyle() then
                if self._ktRestAnimation then self._ktRestAnimation:Stop() end
                self:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
                self:SetTexCoord(0, 0.5, 0, 0.421875)
            else
                if self._ktRestAnimation then self._ktRestAnimation:Stop() end
                self:SetTexture(KUI_ICON_PATH .. "Zzz.png")
                self:SetTexCoord(0, 1, 0, 1)
            end
        end
        ApplyRestingTexture(resting)
        -- PostUpdate: oUF resets the texture; put ours back
        frame.RestingIndicator.PostUpdate = function(self, isResting)
            ApplyRestingTexture(self)
        end
    end

    local function UpdateCombatIndicatorVisuals(s)
        local combat = frame.CombatIndicator
        if not combat then return end

        if ns.IsStockStyle() then combat:Hide(); return end
        if combat:IsObjectType("Texture") then
            combat:SetTexture(KUI_ICON_PATH .. "Combat.png")
            combat:SetTexCoord(0, 1, 0, 1)
        end

        local colorMode = s.combatIndicatorColor or "custom"
        if colorMode == "class" then
            local _, class = UnitClass("player")
            local c = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]) or { r = 1, g = 1, b = 1 }
            combat:SetVertexColor(c.r, c.g, c.b, 1)
        else
            local c = s.combatIndicatorCustomColor or { r = 1, g = 1, b = 1 }
            combat:SetVertexColor(c.r, c.g, c.b, 1)
        end
    end

    local function UpdateCombatIndicatorLayout(s)
        local combat = frame.CombatIndicator
        if not combat then return end

        local sz = s.combatIndicatorSize or 22
        local ox = s.combatIndicatorX or 0
        local oy = s.combatIndicatorY or 0
        local pos = s.combatIndicatorPosition or "healthbar"

        local anchor = frame
        if pos == "healthbar" and frame.Health then
            anchor = frame.Health
        elseif pos == "textbar" and frame._btb then
            anchor = frame._btb
        elseif pos == "portrait" and frame.Portrait then
            anchor = frame.Portrait.backdrop or frame.Portrait
        end

        combat:SetSize(sz, sz)
        combat:ClearAllPoints()
        local baseY = (pos == "healthbar") and 26 or 10
        combat:SetPoint("CENTER", anchor, "CENTER", ox, oy + baseY)
        combat:SetDrawLayer("OVERLAY", 7)
        UpdateCombatIndicatorVisuals(s)
    end

    local function UpdateRestingIndicatorLayout()
        local resting = frame.RestingIndicator
        if not resting then return end

        resting:SetSize(16, 16)
        resting:ClearAllPoints()
        resting:SetDrawLayer("OVERLAY", 7)

        -- The resting (Zzz) icon always sits 5px directly above player's
        -- portrait in Retail/Forever/Classic styles, not anchored to the
        -- health bar like the generic kui layout below.
        local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
            and KT.VisualThemes:GetRenderedTheme()
        local usesPortraitAnchor = renderedTheme == "retail" or renderedTheme == "forever"
            or renderedTheme == "classic"
        local portraitAnchor = frame.Portrait and (frame.Portrait.backdrop or frame.Portrait)
        if usesPortraitAnchor and portraitAnchor then
            -- Blizzard's icon is 31x33 on its 64px portrait.
            local k = math.max(0.5, (portraitAnchor:GetWidth() or 46) / 64)
            if renderedTheme == "retail" or renderedTheme == "forever" then
                resting:SetSize(30 * k, 30 * k)
            else resting:SetSize(24 * k, 25 * k) end
            resting:SetPoint("CENTER", portraitAnchor, "TOPRIGHT", 0, 3 * k)
        else
            resting:SetPoint("TOPLEFT", frame.Health, "TOPLEFT", 3, 8)
        end
    end

    frame._updateCombatIndicatorLayout = UpdateCombatIndicatorLayout
    frame._updateCombatIndicatorVisuals = UpdateCombatIndicatorVisuals
    frame._updateRestingIndicatorLayout = UpdateRestingIndicatorLayout

    UpdateCombatIndicatorLayout(settings)
    UpdateRestingIndicatorLayout()

    if not frame._ktCombatIndicatorEvents then
        frame._ktCombatIndicatorEvents = true
        frame:RegisterEvent("PLAYER_REGEN_DISABLED", function()
            if frame.CombatIndicator and frame.CombatIndicator.ForceUpdate then
                frame.CombatIndicator:ForceUpdate()
            end
        end, true)
        frame:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            if frame.CombatIndicator and frame.CombatIndicator.ForceUpdate then
                frame.CombatIndicator:ForceUpdate()
            end
        end, true)
    end
end


local function StyleFocusFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    local fPpPos = settings.powerPosition or "below"
    local fPpIsAtt = (fPpPos == "below" or fPpPos == "above")
    local powerHeight = fPpIsAtt and (settings.powerHeight or 6) or 0
    local focusBarHeight = settings.healthHeight + powerHeight
    local btbPos = settings.btbPosition or "bottom"
    local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
    local btbExtra = (settings.bottomTextBar and btbIsAttached) and (settings.bottomTextBarHeight or 16) or 0
    local focusFrameHeight = focusBarHeight + btbExtra + (settings.castbarHeight or 14)
    local totalWidth = 0
    local portraitHeight = 0
    local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    local isAttached = (db.profile.portraitStyle or "attached") == "attached"
    local pSide = settings.portraitSide or "right"
    -- For attached, "top" falls back to default side
    local effectiveSide = pSide
    if isAttached and pSide == "top" then effectiveSide = "right" end
    local pSizeAdj = settings.portraitSize or 0
    if not isAttached then pSizeAdj = pSizeAdj + 10 end
    local adjPortraitH = focusBarHeight + pSizeAdj
    if adjPortraitH < 8 then adjPortraitH = 8 end

    if not showPortrait then
        totalWidth = settings.frameWidth
    elseif isAttached then
        totalWidth = adjPortraitH + settings.frameWidth
    else
        totalWidth = settings.frameWidth
    end

    PP.Size(frame, totalWidth, focusFrameHeight)
    local healthXOffset = (showPortrait and isAttached and effectiveSide == "left") and adjPortraitH or 0
    local healthRightInset = (showPortrait and isAttached and effectiveSide == "right") and adjPortraitH or 0
    frame.Health = CreateHealthBar(frame, unit, settings.healthHeight, healthXOffset, settings, healthRightInset)
    frame.Power = CreatePowerBar(frame, unit, settings)
    frame.Castbar = CreateCastBar(frame, unit, settings)
    -- Always create portrait; hide backdrop when disabled
    frame.Portrait = CreatePortrait(frame, pSide, focusBarHeight, unit)
    frame._portraitSide = pSide
    if frame.Portrait and not showPortrait then
        frame.Portrait.backdrop:Hide()
    end
    -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
    if frame.Portrait and frame.Portrait.backdrop and showPortrait and isAttached and frame.Health
        and not (frame._ktForeverLayoutActive or frame._ktClassicLayoutActive) then
        local snappedPortW = frame.Portrait.backdrop:GetWidth()
        local newXOff = (effectiveSide == "left") and snappedPortW or 0
        local newRI = (effectiveSide == "right") and snappedPortW or 0
        local powerAboveOff = (fPpPos == "above") and (settings.powerHeight or 6) or 0
        frame.Health:ClearAllPoints()
        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", newXOff, -powerAboveOff)
        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -newRI, 0)
        PP.Height(frame.Health, settings.healthHeight)
        frame.Health._xOffset = newXOff
        frame.Health._rightInset = newRI
        frame.Health._topOffset = powerAboveOff
    end

    PP.Size(frame, totalWidth, focusBarHeight)

    SetupShowOnCastBar(frame, "focus")

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame -- sits above the StatusBar for clean text rendering.
    local textOverlay = CreateFrame("Frame", nil, frame.Health)
    textOverlay:SetAllPoints(frame.Health)
    if textOverlay.SetClipsChildren then
        textOverlay:SetClipsChildren(true)
    end
    textOverlay:SetFrameLevel(frame.Health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "perhp"
    local centerContent = settings.centerTextContent or "none"
    local lts = settings.leftTextSize or settings.textSize or 12
    local rts = settings.rightTextSize or settings.textSize or 12
    local cts = settings.centerTextSize or settings.textSize or 12

    local leftText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(leftText, lts)
    leftText:SetWordWrap(false)
    leftText:SetTextColor(1, 1, 1)
    frame.LeftText = leftText

    local rightText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(rightText, rts)
    rightText:SetWordWrap(false)
    rightText:SetTextColor(1, 1, 1)
    frame.RightText = rightText

    local centerText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(centerText, cts)
    centerText:SetWordWrap(false)
    centerText:SetTextColor(1, 1, 1)
    frame.CenterText = centerText

    -- Backward compat aliases
    frame.NameText = leftText
    frame.HealthValue = rightText

    -- Apply tags based on content
    local function ApplyTextTags(lc, rc, cc)
        local tagPairs = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, pair in ipairs(tagPairs) do
            local fs, content = pair[1], pair[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo full
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, textOverlay,
        {"name", "perhp", "none"}, true)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Bottom Text Bar
    if settings.bottomTextBar then
        local anchorFrame = (fPpIsAtt and frame.Power) or frame.Health
        local btbPos = settings.btbPosition or "bottom"
        local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
        -- BTB spans full frame width; offset left when portrait is attached on the left
        local btbXOff = 0
        if btbIsAttached and showPortrait and isAttached and effectiveSide == "left" then
            btbXOff = -adjPortraitH
        end
        frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, anchorFrame, btbXOff, totalWidth)
        frame._btb = frame.BottomTextBar
        -- Re-anchor cast bar below BTB only when BTB is attached at bottom
        if btbPos == "bottom" and frame.Castbar then
            local castbarBg = frame.Castbar:GetParent()
            if castbarBg and castbarBg:GetParent() == frame then
                castbarBg:ClearAllPoints()
                castbarBg:SetPoint("TOP", frame.BottomTextBar, "BOTTOM", 0, 0)
            end
        end
    end

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end

local function StyleSimpleFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    PP.Size(frame, settings.frameWidth, settings.healthHeight)

    local health = CreateFrame("StatusBar", nil, frame)
    PP.Point(health, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    PP.Point(health, "RIGHT", frame, "RIGHT", 0, 0)
    PP.Height(health, settings.healthHeight)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    health:GetStatusBarTexture():SetHorizTile(false)

    local bg = health:CreateTexture(nil, "BACKGROUND")
    PP.Point(bg, "TOPLEFT", health, "TOPLEFT", 0, 0)
    PP.Point(bg, "BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.5)
    health.bg = bg

    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    health._kuiUnitKey = UnitToSettingsKey(unit)
    KT:ApplySmoothBar(health)

    -- Inherit health bar texture from donor frame (focus > target > player)
    local donor = GetMiniDonorSettings()
    local unitKey = UnitToSettingsKey(unit)
    local origTex = settings.healthBarTexture
    settings.healthBarTexture = donor.healthBarTexture
    ApplyHealthBarTexture(health, unitKey)
    settings.healthBarTexture = origTex
    ApplyHealthBarAlpha(health, unitKey)
    ApplyDarkTheme(health)

    frame.Health = health
    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame
    local textOverlay = CreateFrame("Frame", nil, health)
    textOverlay:SetAllPoints(health)
    textOverlay:SetFrameLevel(health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    local ts = settings.textSize or 12
    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "none"
    local centerContent = settings.centerTextContent or "none"

    local leftText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(leftText, ts)
    leftText:SetWordWrap(false)
    leftText:SetTextColor(1, 1, 1)
    frame.LeftText = leftText

    local rightText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(rightText, ts)
    rightText:SetWordWrap(false)
    rightText:SetTextColor(1, 1, 1)
    frame.RightText = rightText

    local centerText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(centerText, ts)
    centerText:SetWordWrap(false)
    centerText:SetTextColor(1, 1, 1)
    frame.CenterText = centerText

    -- Backward compat aliases
    frame.NameText = leftText
    frame.HealthValue = rightText

    local function ApplyTextTags(lc, rc, cc)
        local tagPairs = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, pair in ipairs(tagPairs) do
            local fs, content = pair[1], pair[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo compacto
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, health,
        {"name", "none", "none"}, false)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end


local function StylePetFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    local totalWidth = settings.frameWidth
    local portraitOffset = 0

    if showPortrait then
        totalWidth = settings.healthHeight + settings.frameWidth
        portraitOffset = settings.healthHeight
    end

    PP.Size(frame, totalWidth, settings.healthHeight)

    local health = CreateFrame("StatusBar", nil, frame)
    PP.Point(health, "TOPLEFT", frame, "TOPLEFT", portraitOffset, 0)
    PP.Point(health, "RIGHT", frame, "RIGHT", 0, 0)
    PP.Height(health, settings.healthHeight)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    health:GetStatusBarTexture():SetHorizTile(false)

    local bg = health:CreateTexture(nil, "BACKGROUND")
    PP.Point(bg, "TOPLEFT", health, "TOPLEFT", 0, 0)
    PP.Point(bg, "BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
    bg:SetColorTexture(0, 0, 0, 0.5)
    health.bg = bg

    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    health._kuiUnitKey = UnitToSettingsKey(unit)
    KT:ApplySmoothBar(health)

    -- Inherit health bar texture from donor frame (focus > target > player)
    local donor = GetMiniDonorSettings()
    local unitKey = UnitToSettingsKey(unit)
    local origTex = settings.healthBarTexture
    settings.healthBarTexture = donor.healthBarTexture
    ApplyHealthBarTexture(health, unitKey)
    settings.healthBarTexture = origTex
    ApplyHealthBarAlpha(health, unitKey)
    ApplyDarkTheme(health)

    frame.Health = health
    frame.Power = CreatePowerBar(frame, unit, settings)

    -- Always create portrait; hide backdrop when disabled
    frame.Portrait = CreatePortrait(frame, "left", settings.healthHeight, unit)
    frame._portraitSide = "left"
    if frame.Portrait and not showPortrait then        frame.Portrait.backdrop:Hide()
    end
    -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
    if frame.Portrait and frame.Portrait.backdrop and showPortrait
        and not (frame._ktForeverLayoutActive or frame._ktClassicLayoutActive) then
        local snappedPortW = frame.Portrait.backdrop:GetWidth()
        health:ClearAllPoints()
        PP.Point(health, "TOPLEFT", frame, "TOPLEFT", snappedPortW, 0)
        PP.Point(health, "RIGHT", frame, "RIGHT", 0, 0)
        PP.Height(health, settings.healthHeight)
        health._xOffset = snappedPortW
        health._rightInset = 0
        health._topOffset = 0
    end

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame
    local textOverlay = CreateFrame("Frame", nil, health)
    textOverlay:SetAllPoints(health)
    textOverlay:SetFrameLevel(health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    local ts = settings.textSize or 12
    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "none"
    local centerContent = settings.centerTextContent or "none"

    local leftText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(leftText, ts)
    leftText:SetWordWrap(false)
    leftText:SetTextColor(1, 1, 1)
    frame.LeftText = leftText

    local rightText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(rightText, ts)
    rightText:SetWordWrap(false)
    rightText:SetTextColor(1, 1, 1)
    frame.RightText = rightText

    local centerText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetFSFont(centerText, ts)
    centerText:SetWordWrap(false)
    centerText:SetTextColor(1, 1, 1)
    frame.CenterText = centerText

    frame.NameText = leftText
    frame.HealthValue = rightText

    local function ApplyTextTags(lc, rc, cc)
        local tagPairs = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, pair in ipairs(tagPairs) do
            local fs, content = pair[1], pair[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo compacto
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, health,
        {"name", "none", "none"}, false)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
    -- Texts now exist: seat the theme art (Classic/Forever/Retail) on the pet.
    ApplyClassicFrameArt(frame, unit)
end


local function StyleBossFrame(frame, unit)
    local settings = GetSettingsForUnit(unit)
    local bPpPos = settings.powerPosition or "below"
    local bPpIsAtt = (bPpPos == "below" or bPpPos == "above")
    local powerHeight = bPpIsAtt and (settings.powerHeight or 6) or 0
    local bossBarHeight = settings.healthHeight + powerHeight
    local totalWidth = 0
    local portraitHeight = 0
    local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
    if not showPortrait then
        totalWidth = settings.frameWidth
    else
        totalWidth = bossBarHeight + settings.frameWidth
    end

    PP.Size(frame, totalWidth, bossBarHeight)
    local healthRightInset = showPortrait and bossBarHeight or 0
    frame.Health = CreateHealthBar(frame, unit, settings.healthHeight, portraitHeight, settings, healthRightInset)
    frame.Power = CreatePowerBar(frame, unit, settings)
    -- Always create portrait; hide backdrop when disabled
    frame.Portrait = CreatePortrait(frame, "right", bossBarHeight, unit)
    frame._portraitSide = "right"
    if frame.Portrait and not showPortrait then
        frame.Portrait.backdrop:Hide()
    end
    -- Re-anchor health bar to portrait's actual snapped width (eliminates sub-pixel gap)
    if frame.Portrait and frame.Portrait.backdrop and showPortrait and frame.Health
        and not (frame._ktForeverLayoutActive or frame._ktClassicLayoutActive) then
        local snappedPortW = frame.Portrait.backdrop:GetWidth()
        local powerAboveOff = (bPpPos == "above") and (settings.powerHeight or 6) or 0
        frame.Health:ClearAllPoints()
        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", 0, -powerAboveOff)
        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -snappedPortW, 0)
        PP.Height(frame.Health, settings.healthHeight)
        frame.Health._xOffset = 0
        frame.Health._rightInset = snappedPortW
        frame.Health._topOffset = powerAboveOff
    end

    PP.Size(frame, totalWidth, bossBarHeight)

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text overlay frame
    local textOverlay = CreateFrame("Frame", nil, frame.Health)
    textOverlay:SetAllPoints(frame.Health)
    if textOverlay.SetClipsChildren then
        textOverlay:SetClipsChildren(true)
    end
    textOverlay:SetFrameLevel(frame.Health:GetFrameLevel() + 12)
    frame._textOverlay = textOverlay

    -- Crear los tres FontStrings de texto con un bucle
    local bts = settings.textSize or 12
    local textSlots = { "LeftText", "RightText", "CenterText" }
    for _, slot in ipairs(textSlots) do
        local fs = textOverlay:CreateFontString(nil, "OVERLAY")
        SetFSFont(fs, bts)
        fs:SetWordWrap(false)
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
        if fs.SetMaxLines then fs:SetMaxLines(1) end
        fs:SetTextColor(1, 1, 1)
        frame[slot] = fs
    end
    local leftText, rightText, centerText = frame.LeftText, frame.RightText, frame.CenterText

    frame.NameText = leftText
    frame.HealthValue = rightText

    local leftContent = settings.leftTextContent or "name"
    local rightContent = settings.rightTextContent or "perhp"
    local centerContent = settings.centerTextContent or "none"

    local function ApplyTextTags(lc, rc, cc)
        -- Iterar los tres pares (fontstring, contenido) para untag/tag
        local slots = { { leftText, lc }, { rightText, rc }, { centerText, cc } }
        for _, entry in ipairs(slots) do
            local fs, content = entry[1], entry[2]
            if fs._curTag then frame:Untag(fs); fs._curTag = nil end
            local tag = ContentToTag(content)
            if tag then frame:Tag(fs, tag); fs._curTag = tag end
        end
        if frame.UpdateTags then frame:UpdateTags() end
    end
    ApplyTextTags(leftContent, rightContent, centerContent)
    frame._applyTextTags = ApplyTextTags

    -- Posicionamiento de texto: factory compartida con modo compacto
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, frame.Health,
        {"name", "perhp", "none"}, false)
    ApplyTextPositions(settings)
    frame._applyTextPositions = ApplyTextPositions

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end


local function RegisterStylesOnce()
    if _G.KUIUF_StylesRegistered then
        return
    end
    _G.KUIUF_StylesRegistered = true

    oUF:RegisterStyle("KUIPlayer", function(frame, unit)
        StyleFullFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUITarget", function(frame, unit)
        StyleFullFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUIFocus", function(frame, unit)
        StyleFocusFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUIPet", function(frame, unit)
        StylePetFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUITargetTarget", function(frame, unit)
        StyleSimpleFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUIFocusTarget", function(frame, unit)
        StyleSimpleFrame(frame, unit)
    end)
    oUF:RegisterStyle("KUIBoss", function(frame, unit)
        StyleBossFrame(frame, unit)
    end)
end


-- Swap portrait mode (3D / 2D / class theme) without recreating frames.
-- All three objects already exist on the backdrop; we just show/hide and reassign frame.Portrait.
-- Swap portrait mode (3D / 2D / class theme) without recreating frames.
-- 2D and class textures exist on the backdrop; 3D PlayerModel is lazy-created on first use.
local function SwapPortraitMode(frame)
    local portrait = frame.Portrait
    if not portrait or not portrait.backdrop then return end
    local bd = portrait.backdrop
    if not bd._2d then return end

    local wantMode
    do
        local unit2 = frame.unit or frame:GetAttribute("unit")
        local uKey = UnitToSettingsKey(unit2)
        local s = uKey and db.profile[uKey]
        wantMode = ResolveActivePortraitMode(unit2, s)
    end
    local unit = frame.unit or frame:GetAttribute("unit")

    local curMode
    if portrait.isClass then curMode = "class"
    elseif portrait.is2D then curMode = "2d"
    else curMode = "3d" end

    if wantMode == curMode then return end

    -- Disable the oUF element so it unregisters events for the old object
    if frame:IsElementEnabled("Portrait") then
        frame:DisableElement("Portrait")
    end

    -- Hide all
    if bd._3d then bd._3d:ClearModel(); bd._3d:Hide() end
    bd._2d:Hide()
    if bd._class then bd._class:Hide() end

    if wantMode == "class" and bd._class then
        -- Re-apply class art style texture (may have changed since creation)
        local uKey2 = UnitToSettingsKey(unit)
        local s2 = uKey2 and db.profile[uKey2]
        local classStyle = (s2 and s2.classThemeStyle) or "modern"
        local ct = ResolvePortraitClassToken(unit)
        if not ct then
            wantMode = "2d"
        else
            ApplyClassIconTexture(bd._class, ct or "WARRIOR", classStyle)
            ApplyPortraitFacing(bd._class, unit, s2, true)
            bd._class:Show()
            -- Keep tex2D as the oUF element (hidden) so oUF doesn't overwrite texClass
            bd._2d:Hide()
            bd._2d.backdrop = bd
            bd._2d.is2D = true
            bd._2d.isClass = true
            frame.Portrait = bd._2d
            -- Class theme is static -- no oUF element needed, skip re-enable
            return
        end
    end

    if wantMode == "3d" then
        -- Lazily create the PlayerModel on first switch to 3D
        if bd._ensureModel3D then bd._ensureModel3D() end
        if not bd._3d then return end
        bd._3d:Show()
        bd._3d.backdrop = bd
        bd._3d.is2D = false
        bd._3d.isClass = nil
        frame.Portrait = bd._3d
    else
        bd._2d:Show()
        bd._2d.backdrop = bd
        bd._2d.is2D = true
        bd._2d.isClass = nil
        frame.Portrait = bd._2d
    end

    -- Re-enable the oUF element with the new object and force an update
    frame:EnableElement("Portrait")
    frame.Portrait:ForceUpdate()
end

-------------------------------------------------------------------------------
--  Custom Class Power Display (Bars / Circles styles)
-------------------------------------------------------------------------------
local CLASS_POWER_TYPES = {
    ROGUE       = Enum.PowerType.ComboPoints,
    DRUID       = { [103] = { Enum.PowerType.ComboPoints, 5 } }, -- Feral only; other specs use their own resource
    MAGE        = { [62]  = { Enum.PowerType.ArcaneCharges, 4 } }, -- Arcane only
    WARLOCK     = Enum.PowerType.SoulShards,
    PALADIN     = Enum.PowerType.HolyPower,
    MONK        = { [269] = { Enum.PowerType.Chi, 5 } },
    EVOKER      = Enum.PowerType.Essence,
    DEATHKNIGHT = Enum.PowerType.Runes,
    -- Spec-specific custom resources (resolved at creation time)
    DEMONHUNTER = { [581] = { "SOUL_FRAGMENTS_VENGEANCE", 6 } },
    SHAMAN      = { [263] = { "MAELSTROM_WEAPON", 10 } },
    HUNTER      = { [255] = { "TIP_OF_THE_SPEAR", 3 } },
    WARRIOR     = { [72]  = { "WHIRLWIND_STACKS", 4 } },
}

local function DestroyCustomClassPower()
    if frames._customClassPower then
        frames._customClassPower:Hide()
        -- Unregister events on all children to prevent leaks
        local kids = { frames._customClassPower:GetChildren() }
        for _, child in ipairs(kids) do
            child:UnregisterAllEvents()
            child:SetScript("OnEvent", nil)
            child:Hide()
        end
        frames._customClassPower:SetParent(nil)
        frames._customClassPower = nil
    end
end

-- Colores de pip estilo moderno por clase (coincidos con nameplates)
local MODERN_PIP_COLORS = {
    ROGUE={1.00,0.96,0.41}, DRUID={1.00,0.49,0.04}, PALADIN={0.96,0.55,0.73},
    MONK={0.00,1.00,0.60}, WARLOCK={0.58,0.51,0.79}, MAGE={0.25,0.78,0.92},
    EVOKER={0.20,0.58,0.50}, DEATHKNIGHT={0.77,0.12,0.23},
    DEMONHUNTER={0.34,0.06,0.46}, SHAMAN={0.00,0.44,0.87},
    HUNTER={0.67,0.83,0.45}, WARRIOR={0.78,0.61,0.43},
}

-- Resolver recurso de clase: devuelve powerType, maxPower, isCustom o nil
local function ResolveClassResource(playerClass)
    local entry = CLASS_POWER_TYPES[playerClass]
    if not entry then return nil end

    local powerType, customMax, isCustom
    if type(entry) ~= "table" then
        -- PowerType numÃ©rico directo (ComboPoints, SoulShards, etc.)
        powerType, isCustom = entry, false
    else
        -- Tabla con specIDs: resolver segÃºn especializaciÃ³n activa
        local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
            and C_SpecializationInfo.GetSpecialization()
        local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)
        local specEntry = specID and entry[specID]
        if not specEntry then return nil end

        if type(specEntry) == "table" and type(specEntry[1]) == "string" then
            powerType, customMax, isCustom = specEntry[1], specEntry[2], true
        elseif type(specEntry) == "table" then
            powerType, customMax, isCustom = specEntry[1], specEntry[2], false
        else
            powerType, isCustom = specEntry, false
        end
    end

    -- Resolver maxPower segÃºn tipo de recurso
    local maxPower
    if isCustom then
        if powerType == "MAELSTROM_WEAPON" and Compat and Compat.GetMaelstromWeapon then
            local _, mMax = Compat.GetMaelstromWeapon()
            maxPower = (mMax and mMax > 0) and mMax or customMax
        else
            maxPower = (powerType == "SOUL_FRAGMENTS_VENGEANCE" and 6)
                or customMax or 5
        end
    else
        maxPower = UnitPowerMax("player", powerType) or 5
        if maxPower <= 0 then maxPower = 5 end
    end

    return powerType, maxPower, isCustom
end

-- Resolver color RGB de los pips segÃºn configuraciÃ³n del jugador
local function ResolvePipColor(playerClass, isModern)
    local useClassColor = db.profile.player.classPowerClassColor ~= false
    if not useClassColor then
        local cc = db.profile.player.classPowerCustomColor
            or { r = 1, g = 0.82, b = 0 }
        return cc.r, cc.g, cc.b
    end
    if isModern then
        local mc = MODERN_PIP_COLORS[playerClass] or {1.00, 0.84, 0.30}
        return mc[1], mc[2], mc[3]
    end
    local classColor = RAID_CLASS_COLORS[playerClass] or { r = 1, g = 1, b = 1 }
    return classColor.r, classColor.g, classColor.b
end

-- Target combo points use the same circular language in Classic, Forever
-- and Retail as the resource-bar pips, staying attached to the target
-- portrait. kui style gets a different language entirely -- a centered
-- horizontal bar of rectangular pips below target, clear of
-- debuffs/castbar -- since it has no portrait ring to match.
ns.KTTargetCombo = ns.KTTargetCombo or {}

function ns.KTTargetCombo:_Hide(frame)
    if frame and frame._kuiTargetComboRing then
        frame._kuiTargetComboRing:Hide()
    end
    if frame and frame._kuiTargetComboBar then
        frame._kuiTargetComboBar:Hide()
    end
end

function ns.KTTargetCombo:_StylePip(pip, r, g, b)
    if not pip then return end
    if not pip._circleMask then
        pip._circleMask = pip:CreateMaskTexture()
        pip._circleMask:SetTexture(PORTRAIT_MEDIA .. "circle_mask.tga",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pip._circleMask:SetAllPoints(pip)
        -- The ring's pips look soft/jagged at their small size, arranged
        -- via trig (non-integer pixel offsets). The same unsnap treatment
        -- already used for circular portrait art (UnsnapTexture in
        -- ThemeClientAssets.lua) fixes this class of blur -- WoW's default
        -- pixel-snapping fights fractional positioning on small round
        -- masked textures.
        if pip._circleMask.SetSnapToPixelGrid then pip._circleMask:SetSnapToPixelGrid(false) end
        if pip._circleMask.SetTexelSnappingBias then pip._circleMask:SetTexelSnappingBias(0) end
    end
    if not pip._bg then
        pip._bg = pip:CreateTexture(nil, "BACKGROUND")
        pip._bg:SetAllPoints(pip)
        pip._bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        pcall(pip._bg.AddMaskTexture, pip._bg, pip._circleMask)
        if pip._bg.SetSnapToPixelGrid then pip._bg:SetSnapToPixelGrid(false) end
        if pip._bg.SetTexelSnappingBias then pip._bg:SetTexelSnappingBias(0) end
    end
    if not pip._fill then
        pip._fill = pip:CreateTexture(nil, "ARTWORK")
        pip._fill:SetAllPoints(pip)
        pip._fill:SetTexture("Interface\\Buttons\\WHITE8X8")
        pcall(pip._fill.AddMaskTexture, pip._fill, pip._circleMask)
        if pip._fill.SetSnapToPixelGrid then pip._fill:SetSnapToPixelGrid(false) end
        if pip._fill.SetTexelSnappingBias then pip._fill:SetTexelSnappingBias(0) end
    end
    if not pip._border then
        pip._border = pip:CreateTexture(nil, "OVERLAY", nil, 4)
        pip._border:SetAllPoints(pip)
        pip._border:SetTexture(PORTRAIT_MEDIA .. "circle_border.tga")
        if pip._border.SetSnapToPixelGrid then pip._border:SetSnapToPixelGrid(false) end
        if pip._border.SetTexelSnappingBias then pip._border:SetTexelSnappingBias(0) end
    end
    -- Default-game look: black socket, metallic rim, glossy red orb.
    pip._bg:SetVertexColor(0.03, 0.03, 0.03, 1)
    pip._fill:SetTexture("Interface\\COMMON\\Indicator-Red")
    pip._fill:SetVertexColor(1, 1, 1, 1)
    -- A gold border (1, 0.82, 0.08) blends into the bronze ring the pips
    -- sit against, low contrast against a similarly-colored background.
    -- White stands out regardless of what's behind it.
    do
        local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
            and KT.VisualThemes:GetRenderedTheme()
        pip._border:SetVertexColor(0.66, 0.60, 0.52, 1)
    end

    if pip._secretBar then
        local secretFill = pip._secretBar:GetStatusBarTexture()
        if secretFill then
            pcall(secretFill.AddMaskTexture, secretFill, pip._circleMask)
        end
        pip._secretBar:SetStatusBarColor(r, g, b, 1)
    end
end

-- kui's generic target layout has no portrait ring to anchor the circular
-- pips to (and no fixed "corner" geometry the way Classic/Forever/Retail's
-- stock boxes do), so the ring style is reserved for those three. kui
-- instead gets a single horizontal bar anchored below whichever of
-- {frame, Debuffs, Castbar background} sits lowest on screen right now --
-- dynamic on purpose, since debuffAnchor and showCastbar are both
-- user-configurable and a fixed offset would overlap one or the other
-- depending on that configuration.
function ns.KTTargetCombo:_LowestRegion(frame)
    local winner, winnerBottom = frame, frame.GetBottom and frame:GetBottom() or 0
    local function Consider(region)
        if region and region.IsShown and region:IsShown()
            and region.GetBottom and region:GetBottom() then
            local b = region:GetBottom()
            if b < winnerBottom then
                winner, winnerBottom = region, b
            end
        end
    end
    Consider(frame.Debuffs)
    Consider(frame.Castbar and frame.Castbar.GetParent and frame.Castbar:GetParent())
    return winner
end

function ns.KTTargetCombo:_StyleRectPip(pip, r, g, b, borderR, borderG, borderB)
    if not pip then return end
    if not pip._bg then
        pip._bg = pip:CreateTexture(nil, "BACKGROUND")
        pip._bg:SetAllPoints(pip)
        pip._bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    if not pip._fill then
        pip._fill = pip:CreateTexture(nil, "ARTWORK")
        pip._fill:SetAllPoints(pip)
        pip._fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    -- PP.CreateBorder is idempotent (safe to call every refresh, just
    -- repaints the same 4 edge textures), so no "only once" guard is
    -- needed.
    -- Black 1px border + soft shadow.
    ns.KTTargetCombo:_DecorateRectPip(pip)
    pip._bg:SetVertexColor(0.22, 0.02, 0.02, 0.92)
    pip._fill:SetVertexColor(r, g, b, 1)
end

-- Black 1px border + drop shadow drawn as textures just outside the pip frame.
function ns.KTTargetCombo:_DecorateRectPip(pip)
    if not pip or pip._ktDecor then return end
    pip._ktDecor = true
    local sh = pip:CreateTexture(nil, "BACKGROUND", nil, -2)
    sh:SetColorTexture(0, 0, 0, 0.5)
    sh:SetPoint("TOPLEFT", pip, "TOPLEFT", -2, 1)
    sh:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", 2, -3)
    local bd = pip:CreateTexture(nil, "BACKGROUND", nil, -1)
    bd:SetColorTexture(0, 0, 0, 1)
    bd:SetPoint("TOPLEFT", pip, "TOPLEFT", -1, 1)
    bd:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", 1, -1)
end

function ns.KTTargetCombo:Refresh(frame)
    local unit = frame and (frame.unit or (frame.GetAttribute and frame:GetAttribute("unit")))
    if not frame or unit ~= "target" then return end

    -- Target combo display is chosen in the options (default off); this
    -- ring (or the kui bar) only draws for the "ring" choice.
    if ns.ComboUnderFrame and not ns.ComboUnderFrame.ShowsRing("target") then
        self:_Hide(frame)
        return
    end

    -- Only show on neutral/hostile targets, never on an ally -- combo
    -- points are a player-vs-enemy mechanic, and the ring showing on a
    -- friendly target reads as a display bug.
    if UnitExists(unit) and UnitIsFriend and UnitIsFriend("player", unit) then
        self:_Hide(frame)
        return
    end

    local _, class = UnitClass("player")
    -- Warlock's Soul Shards work here too, not just Rogue/Druid combo
    -- points.
    local comboType
    if class == "ROGUE" or class == "DRUID" then
        comboType = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
    elseif class == "WARLOCK" then
        comboType = Enum and Enum.PowerType and Enum.PowerType.SoulShards
    end
    if not comboType then
        self:_Hide(frame)
        return
    end

    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    local useRing = renderedTheme == "classic" or renderedTheme == "forever" or renderedTheme == "retail"

    local portrait = frame.Portrait and frame.Portrait.backdrop
    -- KUI's round portrait uses this widget with a separate row of points.
    if not useRing and db and db.profile and db.profile.portraitStyle == "circular"
        and portrait and portrait:IsShown() then
        useRing = true
    end
    if useRing and (not portrait or not portrait:IsShown()) then
        self:_Hide(frame)
        return
    end

    local ok, maxPower = pcall(UnitPowerMax, "player", comboType)
    if not ok or IsForeverSecretValue(maxPower) or type(maxPower) ~= "number" then
        maxPower = 5
    end
    if maxPower <= 0 then
        self:_Hide(frame)
        return
    end
    maxPower = math.max(1, math.min(10, math.floor(maxPower + 0.5)))

    local r, g, b = 1.0, 0.05, 0.05
    local okCurrent, current = pcall(UnitPower, "player", comboType)
    local numericCurrent = okCurrent and not IsForeverSecretValue(current)
        and type(current) == "number" and current or nil
    local classColors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local classColor = classColors and classColors[class]

    -- Ring + Pips without a portrait: the pips under the target already show them.
    if not useRing and ns.ComboUnderFrame and ns.ComboUnderFrame.GetStyle("target") == "both" then
        self:_Hide(frame)
        return
    end

    if not useRing then
        if frame._kuiTargetComboRing then frame._kuiTargetComboRing:Hide() end

        local overlay = frame._kuiIndicatorOverlay or frame
        local bar = frame._kuiTargetComboBar
        if not bar then
            bar = CreateFrame("Frame", nil, overlay)
            frame._kuiTargetComboBar = bar
            bar.pips = {}
        end
        bar:SetFrameStrata(overlay:GetFrameStrata())
        bar:SetFrameLevel((overlay:GetFrameLevel() or frame:GetFrameLevel()) + 12)

        -- Wider pips (classic WoW's own combo-point ticks read as
        -- rectangles, not squares).
        local pipWidth, pipHeight, gap = 24, 10, 5
        local totalWidth = maxPower * pipWidth + (maxPower - 1) * gap
        bar:SetSize(math.max(pipWidth, totalWidth), pipHeight)
        bar:ClearAllPoints()
        bar:SetPoint("TOP", self:_LowestRegion(frame), "BOTTOM", 0, -6)

        for index = 1, maxPower do
            local pip = bar.pips[index]
            if not pip then
                pip = CreateFrame("Frame", nil, bar)
                bar.pips[index] = pip
            end
            pip:SetSize(pipWidth, pipHeight)
            pip:ClearAllPoints()
            pip:SetPoint("LEFT", bar, "LEFT", (index - 1) * (pipWidth + gap), 0)
            self:_StyleRectPip(pip, r, g, b,
                classColor and classColor.r, classColor and classColor.g, classColor and classColor.b)
            pip._fill:Hide()
            if pip._secretBar then pip._secretBar:Hide() end

            if numericCurrent then
                pip._fill:SetShown(index <= numericCurrent)
            elseif okCurrent and IsForeverSecretValue(current) then
                if not pip._secretBar then
                    pip._secretBar = CreateFrame("StatusBar", nil, pip)
                    pip._secretBar:SetAllPoints(pip)
                    pip._secretBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                    pip._secretBar:SetFrameLevel(pip:GetFrameLevel() + 1)
                end
                pip._secretBar:SetMinMaxValues(index - 1, index)
                pip._secretBar:SetShown(pcall(pip._secretBar.SetValue, pip._secretBar, current))
            end
            pip:Show()
        end
        for index = maxPower + 1, #bar.pips do
            bar.pips[index]:Hide()
        end
        bar:Show()
        return
    end

    if frame._kuiTargetComboBar then frame._kuiTargetComboBar:Hide() end

    local overlay = frame._kuiIndicatorOverlay or frame
    local ring = frame._kuiTargetComboRing
    if not ring then
        ring = CreateFrame("Frame", nil, overlay)
        ring:SetClipsChildren(false)
        frame._kuiTargetComboRing = ring
        ring.pips = {}
    end
    ring:SetFrameStrata(overlay:GetFrameStrata())
    ring:SetFrameLevel((overlay:GetFrameLevel() or frame:GetFrameLevel()) + 12)

    -- Blizzard's ComboFrame geometry: 12px points around a 64px portrait,
    -- on its arc, scaled to this portrait. comboPosTarget "above" turns the
    -- arc toward the top; X/Y offset the whole ring.
    local portraitSize = portrait:GetWidth()
    if type(portraitSize) ~= "number" or portraitSize < 1 then portraitSize = 46 end
    local O = ns.KUIOrnaments
    local art = O and O.GetComboArt() or "modern"
    local pipSize = math.max(8, portraitSize * 12 / 64)
    local comboPos, comboX, comboY = "below", 0, 0
    if ns.ComboUnderFrame and ns.ComboUnderFrame.GetPlacement then
        comboPos, comboX, comboY = ns.ComboUnderFrame.GetPlacement("target")
    end
    local reach = portraitSize * 0.8 + pipSize
    ring:SetSize(reach * 2, reach * 2)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", portrait, "CENTER", comboX, comboY)

    local layout = O and O.LayoutRing(frame, portrait, maxPower, pipSize, comboPos == "above")
    if not layout then
        layout = {}
        for index = 1, maxPower do
            local t = (maxPower > 1) and ((index - 1) / (maxPower - 1)) or 0
            local angle = math.rad(95 + (15 - 95) * t)
            local radius = portraitSize * 0.5 + 14
            layout[index] = { math.cos(angle) * radius, math.sin(angle) * radius }
        end
    end

    for index = 1, maxPower do
        local pip = ring.pips[index]
        if not pip then
            pip = CreateFrame("Frame", nil, ring)
            ring.pips[index] = pip
        end
        local spot = layout[index]
        if not spot then
            pip:Hide()
        else
            pip:SetSize(pipSize, pipSize)
            pip:ClearAllPoints()
            pip:SetPoint("CENTER", ring, "CENTER", spot[1], spot[2])
            if okCurrent and IsForeverSecretValue(current) and not pip._secretBar then
                pip._secretBar = CreateFrame("StatusBar", nil, pip)
                pip._secretBar:SetFrameLevel(pip:GetFrameLevel() + 1)
                pip._ktArt = nil
            end
            local lit
            if O then
                O.StylePip(pip, art, pipSize)
                lit = pip._lit
            else
                self:_StylePip(pip, r, g, b)
                lit = pip._fill
            end
            if pip._secretBar then pip._secretBar:Hide() end
            local filled = numericCurrent and index <= numericCurrent
            if numericCurrent then
                lit:SetShown(filled)
            else
                lit:Hide()
                if okCurrent and IsForeverSecretValue(current) and pip._secretBar then
                    pip._secretBar:SetMinMaxValues(index - 1, index)
                    pip._secretBar:SetShown(pcall(pip._secretBar.SetValue, pip._secretBar, current))
                end
            end
            -- Points past the standard row only appear while filled.
            pip:SetShown(not spot.onlyFilled or filled or numericCurrent == nil)
            pip:SetAlpha(spot.onlyFilled and 0.6 or 1)
        end
    end
    for index = maxPower + 1, #ring.pips do
        ring.pips[index]:Hide()
    end
    ring:Show()
end

local function CreateCustomClassPower(playerFrame, style)
    local _, playerClass = UnitClass("player")

    -- Usar helper externo para resolver recurso + maxPower
    local powerType, maxPower, isCustom = ResolveClassResource(playerClass)
    if not powerType then return nil end

    local isModern = (style == "modern")
    local isCircle = (style == "circles")
    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    local comboPowerType = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
    -- Classic combo ornament now lives in KUI_ComboUnderFrame.lua.
    local isClassicCombo = false
    -- Atlas availability differs between clients: probe first, fall back to
    -- stock textures (glossy red orb on a dark plate) when it is missing.
    local function HasAtlas(name)
        return C_Texture and C_Texture.GetAtlasInfo
            and C_Texture.GetAtlasInfo(name) ~= nil
    end

    -- Dimensiones de cada pip segÃºn estilo
    local sizeAdj = db.profile.player.classPowerSize or 8
    local spacingAdj = db.profile.player.classPowerSpacing or 2
    local pipSize, pipH
    if isClassicCombo then
        -- The legacy PlayerFrame combo ornament is a 126x20 strip: five
        -- 20px points, four 1px gaps and 11px of art padding on each side.
        -- Keep that native geometry so ComboPoints-AllPointsBG, the empty
        -- point overlay and the red active atlas line up without stretching
        -- individual pips.
        pipSize = 20
        pipH = 20
    elseif isModern then
        pipSize = math.floor(sizeAdj * 1.4 + 0.5)  -- wider pips
        pipH = math.max(3, math.floor(sizeAdj * 0.375))
    elseif isCircle then
        pipSize = sizeAdj + 6
        pipH = sizeAdj + 6
    else
        pipSize = sizeAdj + 12
        pipH = sizeAdj
    end
    local gap = isClassicCombo and 1 or (isCircle and spacingAdj or (spacingAdj + 2))
    local pad = isClassicCombo and 22 or (isModern and 0 or 4)
    -- Ajustar a pÃ­xeles fÃ­sicos
    pipSize = PP.Scale(pipSize)
    pipH    = PP.Scale(pipH)
    gap     = PP.Scale(gap)
    pad     = PP.Scale(pad)
    local totalW = maxPower * pipSize + (maxPower - 1) * gap + pad
    local totalH = pipH + pad

    -- Contenedor principal
    local container = CreateFrame("Frame", nil, UIParent)
    PP.Size(container, totalW, totalH)
    container:SetFrameStrata("LOW")
    container:SetFrameLevel(10)

    -- Fondo detrÃ¡s de todos los pips
    local bgCol = db.profile.player.classPowerBgColor
        or { r = 0.082, g = 0.082, b = 0.082, a = 1.0 }
    local containerBg = container:CreateTexture(nil, isClassicCombo and "OVERLAY" or "BACKGROUND", nil,
        isClassicCombo and -1 or 0)
    containerBg:SetAllPoints()
    local classicOverlayApplied = false
    if isClassicCombo and containerBg.SetAtlas and HasAtlas("ComboPoints-AllPointsBG") then
        classicOverlayApplied = pcall(containerBg.SetAtlas, containerBg,
            "ComboPoints-AllPointsBG", false)
        if classicOverlayApplied then
            containerBg:SetVertexColor(1, 1, 1, 1)
            UnsnapTex(containerBg)
        end
    end
    if not classicOverlayApplied then
        if isClassicCombo then
            containerBg:SetColorTexture(0.03, 0.03, 0.03, 0.95)
        else
            containerBg:SetColorTexture(bgCol.r, bgCol.g, bgCol.b, bgCol.a)
        end
    end
    if isClassicCombo and not classicOverlayApplied then
        -- Fallback when the atlas is missing: chamfered plate built from 1px
        -- strips: a silver outline shape with a dark fill shape inset by 1px.
        containerBg:SetColorTexture(0, 0, 0, 0)
        -- Classic plate is ~1.6x a bar row tall, slots nearly fill its height.
        local ph = playerFrame and playerFrame.Power and playerFrame.Power:GetHeight() or 0
        if not ph or ph < 6 then ph = 14 end
        local H = math.max(20, math.floor(ph * 1.6 + 0.5))
        local C = 4
        container._ktPlateH = H
        local function Strip(r, g, b, a, yTop, h, inset, sub)
            local t = container:CreateTexture(nil, "OVERLAY", nil, sub)
            t:SetColorTexture(r, g, b, a)
            t:SetHeight(h)
            t:SetPoint("TOPLEFT", container, "TOPLEFT", inset, -yTop)
            t:SetPoint("TOPRIGHT", container, "TOPRIGHT", -inset, -yTop)
        end
        -- outline shape
        Strip(0.62, 0.62, 0.66, 1, 0, H - C, 0, 0)
        for k = 1, C do Strip(0.62, 0.62, 0.66, 1, H - C + k - 1, 1, k, 0) end
        -- fill shape (1px inside the outline)
        Strip(0.03, 0.03, 0.03, 0.97, 1, H - C - 1, 1, 1)
        for k = 1, C - 1 do Strip(0.03, 0.03, 0.03, 0.97, H - C + k - 1, 1, k + 1, 1) end
    end
    container._bg = containerBg
    container._ktClassicComboOverlay = classicOverlayApplied and containerBg or nil

    -- Color de pip vacÃ­o
    local emptyCol = db.profile.player.classPowerEmptyColor
        or { r = 0.2, g = 0.2, b = 0.2, a = 1.0 }

    if not isModern and not isClassicCombo then
        MakeBorder(container, 0, 0, 0, 0.8)
    end

    -- Borde inferior de 1px para posiciÃ³n "above" (se muestra sÃ³lo allÃ­)
    local cpBdrOverlay = CreateFrame("Frame", nil, container)
    cpBdrOverlay:SetAllPoints()
    cpBdrOverlay:SetFrameLevel(container:GetFrameLevel() + 2)
    local cpBottomBdr = cpBdrOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    cpBottomBdr:SetHeight(1)
    PP.Point(cpBottomBdr, "BOTTOMLEFT", cpBdrOverlay, "BOTTOMLEFT", 0, 0)
    PP.Point(cpBottomBdr, "BOTTOMRIGHT", cpBdrOverlay, "BOTTOMRIGHT", 0, 0)
    cpBdrOverlay:Hide()
    container._bottomBdr = cpBottomBdr
    container._bottomBdrFrame = cpBdrOverlay

    -- Color de relleno resuelto por helper externo (clase/moderno/custom)
    local cr, cg, cb = ResolvePipColor(playerClass, isModern)

    -- Descriptor de textura segÃºn estilo (cÃ­rculos vs barras)
    local pipTexPath = isCircle and "Interface\\COMMON\\Indicator-Gray" or nil

    local function MakePip(parent, index)
        local pip = CreateFrame("Frame", nil, parent)
        PP.Size(pip, pipSize, pipH)
        PP.Point(pip, "LEFT", parent, "LEFT",
            (index - 1) * (pipSize + gap) + pad / 2, 0)

        -- Capa vacÃ­a (visible cuando el recurso no estÃ¡ lleno)
        local pipEmpty = pip:CreateTexture(nil, "ARTWORK", nil, 0)
        pipEmpty:SetAllPoints()
        local emptyAtlasApplied = false
        if isClassicCombo and pipEmpty.SetAtlas and HasAtlas("ComboPoints-PointBg") then
            emptyAtlasApplied = pcall(pipEmpty.SetAtlas, pipEmpty,
                "ComboPoints-PointBg", false)
            if emptyAtlasApplied then
                pipEmpty:SetVertexColor(1, 1, 1, 1)
                UnsnapTex(pipEmpty)
            end
        end
        if emptyAtlasApplied then
            -- Atlas already supplies the metal ring and dark empty center.
        elseif isClassicCombo then
            pipEmpty:SetTexture("Interface\\COMMON\\Indicator-Gray")
            pipEmpty:SetVertexColor(0.08, 0.08, 0.08, 1)
        elseif pipTexPath then
            pipEmpty:SetTexture(pipTexPath)
            pipEmpty:SetVertexColor(emptyCol.r, emptyCol.g, emptyCol.b, emptyCol.a)
        else
            pipEmpty:SetColorTexture(emptyCol.r, emptyCol.g, emptyCol.b, emptyCol.a)
        end

        -- Capa de relleno (encima de la vacÃ­a)
        local pipFill = pip:CreateTexture(nil, "ARTWORK", nil, 1)
        pipFill:SetAllPoints()
        local fillAtlasApplied = false
        if isClassicCombo and pipFill.SetAtlas and HasAtlas("ComboPoints-ComboPoint") then
            fillAtlasApplied = pcall(pipFill.SetAtlas, pipFill,
                "ComboPoints-ComboPoint", false)
            if fillAtlasApplied then
                pipFill:SetVertexColor(1, 1, 1, 1)
                UnsnapTex(pipFill)
            end
        end
        if fillAtlasApplied then
            -- The native atlas owns Classic's red fill and highlight.
        elseif isClassicCombo then
            pipFill:SetTexture("Interface\\COMMON\\Indicator-Red")
            pipFill:SetVertexColor(1, 1, 1, 1)
        elseif pipTexPath then
            pipFill:SetTexture(pipTexPath)
            pipFill:SetVertexColor(cr, cg, cb, 1)
        else
            pipFill:SetColorTexture(cr, cg, cb, 1)
        end

        pip._fill = pipFill
        pip._empty = pipEmpty
        pip._ktClassicComboAtlas = emptyAtlasApplied and fillAtlasApplied
        -- Border + shadow on rectangular pips belongs to the styled looks;
        -- KUI Style keeps the Retail pips.
        if not isClassicCombo and not isCircle
            and (renderedTheme == "classic" or renderedTheme == "forever" or renderedTheme == "retail")
            and ns.KTTargetCombo and ns.KTTargetCombo._DecorateRectPip then
            ns.KTTargetCombo:_DecorateRectPip(pip)
        end
        return pip
    end

    local pips = {}
    for i = 1, maxPower do
        pips[i] = MakePip(container, i)
    end
    if isClassicCombo then
        -- Slim plate as wide as the bars; round slots spread evenly across it.
        -- Geometry of the native 126x20 ornament: five 20px slots, 1px gaps,
        -- 11px side padding.  Scale it to the bar width keeping its aspect.
        local function Layout()
            local W = container:GetWidth()
            if not W or W <= 0 then return end
            local k = W / 126
            local d = 20 * k
            if math.abs((container:GetHeight() or 0) - d) > 0.5 then
                container:SetHeight(d)
            end
            for i, pp in ipairs(pips) do
                pp:ClearAllPoints()
                -- Slots are a bit larger than the plate openings and hang
                -- slightly below its lower edge, like the original ornament.
                local sz = d * 1.1
                pp:SetSize(sz, sz)
                pp:SetPoint("LEFT", container, "LEFT",
                    (11 + 21 * (i - 1)) * k - (sz - d) / 2, -d * 0.18)
            end
        end
        container:SetScript("OnSizeChanged", Layout)
        container._ktClassicLayout = Layout
        Layout()
    end

    -- Update function
    local isSecretResource = (powerType == "SOUL_FRAGMENTS_VENGEANCE")
    local function UpdatePips()
        local cur, max
        if isClassicCombo and playerClass == "DRUID" and GetShapeshiftFormID then
            -- Druid combo points only exist in Cat Form (form id 1).
            container:SetAlpha(GetShapeshiftFormID() == 1 and 1 or 0)
        end
        if isCustom then
            -- Custom resource: use Compat tracker functions
            if powerType == "SOUL_FRAGMENTS_VENGEANCE" then
                cur = C_Spell and C_Spell.GetSpellCastCount and C_Spell.GetSpellCastCount(228477) or 0
                max = 6
            elseif powerType == "MAELSTROM_WEAPON" and Compat and Compat.GetMaelstromWeapon then
                cur, max = Compat.GetMaelstromWeapon()
            elseif powerType == "TIP_OF_THE_SPEAR" and Compat and Compat.GetTipOfTheSpear then
                cur, max = Compat.GetTipOfTheSpear()
            elseif powerType == "WHIRLWIND_STACKS" and Compat and Compat.GetWhirlwindStacks then
                cur, max = Compat.GetWhirlwindStacks()
            else
                cur, max = 0, maxPower
            end
            if not max or max <= 0 then max = maxPower end
        else
            cur = UnitPower("player", powerType) or 0
            max = UnitPowerMax("player", powerType) or maxPower

            -- Handle runes specially (count available runes)
            if powerType == Enum.PowerType.Runes then
                cur = 0
                for i = 1, max do
                    local start, duration, ready = GetRuneCooldown(i)
                    if ready then cur = cur + 1 end
                end
            end
        end

        -- Rebuild pips if max changed
        if max ~= #pips and max > 0 then
            for _, p in ipairs(pips) do p:Hide() end
            local newTotalW = max * pipSize + (max - 1) * gap + pad
            container:SetWidth(newTotalW)
            for i = 1, max do
                if not pips[i] then
                    pips[i] = MakePip(container, i)
                end
                local x = (i - 1) * (pipSize + gap) + pad / 2
                pips[i]:ClearAllPoints()
                PP.Point(pips[i], "TOPLEFT", container, "TOPLEFT", x, 0)
                PP.Size(pips[i], pipSize, pipH)
                pips[i]:Show()
            end
        end

        if isSecretResource or IsSecret(cur) then
            -- Secret-value path: use StatusBar overlays per pip
            for i = 1, #pips do
                if pips[i] then
                    if not pips[i]._secretBar then
                        local sb = CreateFrame("StatusBar", nil, pips[i])
                        sb:SetAllPoints(pips[i]._fill or pips[i])
                        sb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                        if isClassicCombo then
                            local sbTexture = sb:GetStatusBarTexture()
                            if sbTexture and sbTexture.SetAtlas and HasAtlas("ComboPoints-ComboPoint") then
                                pcall(sbTexture.SetAtlas, sbTexture,
                                    "ComboPoints-ComboPoint", false)
                                UnsnapTex(sbTexture)
                            elseif sbTexture then
                                sb:SetStatusBarTexture("Interface\\COMMON\\Indicator-Red")
                            end
                            sb:SetStatusBarColor(1, 1, 1, 1)
                        else
                            sb:SetStatusBarColor(cr, cg, cb, 1)
                        end
                        sb:SetFrameLevel(pips[i]:GetFrameLevel() + 1)
                        pips[i]._secretBar = sb
                    end
                    pips[i]._secretBar:SetMinMaxValues(i - 1, i)
                    local secretValueOK = pcall(pips[i]._secretBar.SetValue, pips[i]._secretBar, cur)
                    if isClassicCombo then
                        pips[i]._secretBar:SetStatusBarColor(1, 1, 1, 1)
                    else
                        pips[i]._secretBar:SetStatusBarColor(cr, cg, cb, 1)
                    end
                    pips[i]._secretBar:SetShown(secretValueOK)
                    -- Hide normal fill; StatusBar replaces it
                    if pips[i]._fill then pips[i]._fill:Hide() end
                end
            end
        else
            -- Clean-value path
            for i = 1, #pips do
                if pips[i] then
                    if pips[i]._secretBar then pips[i]._secretBar:Hide() end
                    if pips[i]._fill then
                        if i <= cur then
                            pips[i]._fill:Show()
                        else
                            pips[i]._fill:Hide()
                        end
                    end
                end
            end
        end
    end

    -- Event driver
    local eventFrame = CreateFrame("Frame", nil, container)
    if isCustom then
        -- Per-resource event registration: only register what each resource
        -- actually needs to avoid unnecessary event traffic.
        local needsOnUpdate = (powerType ~= "MAELSTROM_WEAPON")
        local needsAura     = (powerType == "MAELSTROM_WEAPON")
        local needsCasts    = (powerType == "TIP_OF_THE_SPEAR" or powerType == "WHIRLWIND_STACKS")

        if needsOnUpdate then
            local elapsed = 0
            eventFrame:SetScript("OnUpdate", function(_, dt)
                elapsed = elapsed + dt
                if elapsed < 0.1 then return end
                elapsed = 0
                UpdatePips()
            end)
        end

        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

        if needsAura then
            eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
        end
        if needsCasts then
            eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            eventFrame:RegisterEvent("PLAYER_DEAD")
            eventFrame:RegisterEvent("PLAYER_ALIVE")
        end
        if powerType == "WHIRLWIND_STACKS" then
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end

        eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_SPECIALIZATION_CHANGED" then
                DestroyCustomClassPower()
                frames._classPowerBar = nil
                C_Timer.After(0.1, function()
                    if ns.ReloadFrames then ns.ReloadFrames() end
                end)
                return
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                if not _G._ERB_AceDB and Compat then
                    local unit, castGUID, spellID = ...
                    if unit == "player" then
                        if Compat.HandleTipOfTheSpear then
                            Compat.HandleTipOfTheSpear(event, unit, castGUID, spellID)
                        end
                        if Compat.HandleWhirlwindStacks then
                            Compat.HandleWhirlwindStacks(event, unit, castGUID, spellID)
                        end
                    end
                end
            elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
                if not _G._ERB_AceDB and Compat then
                    if Compat.HandleTipOfTheSpear then
                        Compat.HandleTipOfTheSpear(event)
                    end
                    if Compat.HandleWhirlwindStacks then
                        Compat.HandleWhirlwindStacks(event)
                    end
                end
            elseif event == "PLAYER_REGEN_ENABLED" then
                if not _G._ERB_AceDB and Compat and Compat.HandleWhirlwindStacks then
                    Compat.HandleWhirlwindStacks(event)
                end
            end
            UpdatePips()
        end)
    else
        eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        if isClassicCombo and playerClass == "DRUID" then
            eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        end
        if powerType == Enum.PowerType.Runes then
            eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
        end
        eventFrame:SetScript("OnEvent", function(_, event, unit)
            if event == "PLAYER_ENTERING_WORLD" or event == "RUNE_POWER_UPDATE"
               or event == "UPDATE_SHAPESHIFT_FORM" or (unit == "player") then
                UpdatePips()
            end
        end)
    end

    UpdatePips()
    container._updatePips = UpdatePips
    container._pips = pips
    container._pipSize = pipSize
    container._pipH = pipH
    container._gap = gap
    container._pad = pad
    container._ktClassicCombo = isClassicCombo

    -- Reposition pips to fill a given width (for "above" position)
    -- Uses Snap() to round all positions to physical pixel boundaries
    -- so gaps between pips are guaranteed identical.
    container._repositionForWidth = function(targetW)
        local n = #pips
        if n <= 0 then return end
        local efs = container:GetEffectiveScale()
        if efs <= 0 then efs = 1 end
        local function Snap(v) return math.floor(v * efs + 0.5) / efs end
        local intW = math.floor(targetW)
        local gapPx = Snap(gap)
        local totalGapW = (n - 1) * gapPx
        local totalPipW = intW - totalGapW
        local basePipW = totalPipW / n
        for i = 1, n do
            local leftEdge = Snap((i - 1) * (basePipW + gapPx))
            local rightEdge = Snap((i - 1) * (basePipW + gapPx) + basePipW)
            local w = rightEdge - leftEdge
            pips[i]:ClearAllPoints()
            pips[i]:SetSize(w, pipH)
            pips[i]:SetPoint("TOPLEFT", container, "TOPLEFT", leftEdge, 0)
        end
        container:SetWidth(intW)
        container:SetHeight(pipH)
    end

    return container
end

-- Lightweight dispel-overlay toggle (no secure/layout work), so the option also works in
-- combat instead of being ignored until the next full reload.
function ns.ApplyDispelOverlayLive()
    for unit, frame in pairs(frames) do
        if type(unit) == "string" and unit:sub(1, 1) ~= "_" and type(frame) == "table" then
            local settings = GetSettingsForUnit(unit)
            if settings then
                local show = ns.IsDispelOverlayOn(settings)
                if frame.KTDispelSlots then frame.KTDispelSlots:SetShown(show) end
                if frame.dispelBorderFrame then
                    frame.dispelBorderFrame:SetShown(show)
                    if not show then SetDispelFrameBorder(frame, nil) end
                end
                if unit == "target" then RefreshTargetDebuffDispelStyle(settings) end
            end
        end
    end
end

local function ReloadFrames()
    if InCombatLockdown() then
        pcall(ns.ApplyDispelOverlayLive)
        return
    end

    ResolveFontPath()
    ns.EnforceTargetBuffs(db.profile)

    -- Invalidar cache del subsistema de contexto de unidad
    ns._UnitCtx.Invalidate()

    -- Normalize opacity values: old profiles stored 0-1 floats, new format is 0-100 integers
    do
        local prof = db.profile
        local UNITS = { "player", "target", "focus", "boss", "pet", "totPet" }
        if prof.healthBarOpacity and prof.healthBarOpacity <= 1.0 then
            prof.healthBarOpacity = math.floor(prof.healthBarOpacity * 100 + 0.5)
        end
        if prof.powerBarOpacity and prof.powerBarOpacity <= 1.0 then
            prof.powerBarOpacity = math.floor(prof.powerBarOpacity * 100 + 0.5)
        end
        for _, uKey in ipairs(UNITS) do
            local s = prof[uKey]
            if s then
                if s.healthBarOpacity and s.healthBarOpacity <= 1.0 then
                    s.healthBarOpacity = math.floor(s.healthBarOpacity * 100 + 0.5)
                end
                if s.powerBarOpacity and s.powerBarOpacity <= 1.0 then
                    s.powerBarOpacity = math.floor(s.powerBarOpacity * 100 + 0.5)
                end
            end
        end
    end

    local profile = db.profile
    local castbarColor = GetCastbarColor()
    local castbarOpacity = profile.castbarOpacity
    local enabled = profile.enabledFrames

    -- Uses global font
    local donorFontPath = Compat and Compat.GetFontPath and Compat.GetFontPath("unitFrames")
        or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"

    -- Live enable/disable frames without reload
    local function ToggleFrame(unit, frame)
        if not frame then return end
        local unitKey = unit:match("^boss%d$") and "boss" or unit
        local isEnabled = enabled[unitKey] ~= false
        -- Check group visibility for player/target/focus
        if isEnabled and (unitKey == "player" or unitKey == "target" or unitKey == "focus") then
            local s = profile[unitKey]
            if s then
                local inRaid = IsInRaid()
                local inParty = not inRaid and IsInGroup()
                local solo = not inRaid and not inParty
                local vis = (inRaid and (s.showInRaid ~= false))
                    or (inParty and (s.showInParty ~= false))
                    or (solo and (s.showSolo ~= false))
                if not vis then isEnabled = false end
            end
        end
        if isEnabled then
            -- Always set unit attribute and show frame when enabled
            frame:SetAttribute("unit", unit)
            if not frame:IsShown() then
                frame:Show()
            end
            -- Re-enable core oUF elements; per-feature elements (Portrait,
            -- Buffs, HealthPrediction) are handled by the per-unit sections below
            for _, elem in ipairs({"Health", "Power", "Debuffs"}) do
                if frame[elem] and not frame:IsElementEnabled(elem) then
                    frame:EnableElement(elem)
                end
            end
            frame:UpdateAllElements("ToggleFrame")
            if unitKey == "player" then
                RefreshPlayerStatusIndicators()
            end
        else
            if frame:IsShown() then
                -- Disable all oUF elements for zero performance impact
                for _, elem in ipairs({"Health", "Power", "Portrait", "Castbar", "Buffs", "Debuffs", "HealthPrediction", "CombatIndicator", "RestingIndicator", "LeaderIndicator", "AssistantIndicator", "ResurrectIndicator", "SummonIndicator", "RaidTargetIndicator"}) do
                    if frame[elem] and frame:IsElementEnabled(elem) then
                        frame:DisableElement(elem)
                    end
                end
                frame:SetAttribute("unit", nil)
                frame:Hide()
            end
        end
    end

    for unit, frame in pairs(frames) do
        if type(unit) == "string" and unit:sub(1,1) ~= "_" then
            ToggleFrame(unit, frame)
        end
    end

    for unit, frame in pairs(frames) do
        if type(unit) == "string" and unit:sub(1,1) ~= "_" and frame then
            local unitKey = unit:match("^boss%d$") and "boss" or unit
            if enabled[unitKey] == false then
                -- skip disabled frames
            else
            local settings = GetSettingsForUnit(unit)
            local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false

            -- Swap 2D/3D portrait mode if changed (no reload needed)
            if frame.Portrait then
                SwapPortraitMode(frame)
                -- Re-apply the 3D zoom, rotation and offsets without a reload.
                if frame.Portrait.is2D == false and frame.Portrait.PostUpdate then
                    frame.Portrait:PostUpdate(unit)
                end
            end

            -- Refresh class art style texture (may have changed without mode change)
            if frame.Portrait and frame.Portrait.backdrop and frame.Portrait.backdrop._class then
                local uKey = UnitToSettingsKey(unit) or unit
                local uSettings = uKey and db.profile[uKey]
                local isClassMode = ResolveActivePortraitMode(unit, uSettings) == "class"
                if isClassMode then
                    local classStyle = (uSettings and uSettings.classThemeStyle) or "modern"
                    local ct = ResolvePortraitClassToken(unit)
                    if ct then
                        ApplyClassIconTexture(frame.Portrait.backdrop._class, ct, classStyle)
                        ApplyPortraitFacing(frame.Portrait.backdrop._class, unit, uSettings, true)
                        if frame.Portrait.backdrop._2d and frame.Portrait.backdrop._2d.PostUpdate then
                            frame.Portrait.backdrop._2d:PostUpdate()
                        end
                    elseif frame.Portrait.backdrop._class then
                        frame.Portrait.backdrop._class:Hide()
                    end
                end
            end

            -- Show/hide portrait live (no reload needed)
            if frame.Portrait and frame.Portrait.backdrop then
                local uKey = UnitToSettingsKey(unit) or unit
                local uSettings = uKey and db.profile[uKey]
                local isClassMode = ResolveActivePortraitMode(unit, uSettings) == "class"
                if showPortrait then
                    frame.Portrait.backdrop:Show()
                    if isClassMode then
                        -- Class theme uses a static texture and does not need portrait events.
                        if frame:IsElementEnabled("Portrait") then
                            frame:DisableElement("Portrait")
                        end
                    elseif not frame:IsElementEnabled("Portrait") then
                        frame:EnableElement("Portrait")
                        frame.Portrait:ForceUpdate()
                    end
                else
                    frame.Portrait.backdrop:Hide()
                    if frame:IsElementEnabled("Portrait") then
                        frame:DisableElement("Portrait")
                    end
                end
                -- Live-update detached portrait shape/mask/border
                ApplyDetachedPortraitShape(frame.Portrait.backdrop, uSettings, unit)
                -- Portrait level set at creation (50+) - always above the frame's bars
            end

            if unit == "player" and frame.HealthPrediction then
                ApplyAbsorbBarStyle(frame, settings)
            end

            if unit == "player" or unit == "target" then
                local ppPos = settings.powerPosition or "below"
                local ppIsAtt = (ppPos == "below" or ppPos == "above")
                local ppExtra = ppIsAtt and settings.powerHeight or 0
                local playerTargetHeight = settings.healthHeight + ppExtra
                -- Class power "above" adds height above health bar (player only, "top" floats outside)
                local cpAboveH = 0
                if unit == "player" then
                    local cpSt = settings.classPowerStyle or "none"
                    local cpPo = (cpSt == "modern") and (settings.classPowerPosition or "top") or "none"
                    if cpSt == "modern" and cpPo == "above" then
                        local cpSizeAdj = settings.classPowerSize or 8
                        local cpPipH = math.max(3, math.floor(cpSizeAdj * 0.375))
                        cpAboveH = cpPipH
                    end
                end
                local playerTargetHeightWithCp = playerTargetHeight + cpAboveH
                local btbPos = settings.btbPosition or "bottom"
                local btbIsAttached = (btbPos == "top" or btbPos == "bottom")
                local btbExtra = (settings.bottomTextBar and btbIsAttached) and (settings.bottomTextBarHeight or 16) or 0
                local targetFrameHeight = playerTargetHeight + btbExtra
                local portraitHeight = 0
                local totalWidth = 0
                local isAttached = (db.profile.portraitStyle or "attached") == "attached"
                local pSizeAdj = settings.portraitSize or 0
                local pXOff = settings.portraitX or 0
                local pYOff = settings.portraitY or 0
                if not isAttached then pSizeAdj = pSizeAdj + 10; pYOff = pYOff + 5 end

                if unit == "player" then
                    local pSide = settings.portraitSide or "left"
                    local effectiveSide = pSide
                    if isAttached and pSide == "top" then effectiveSide = "left" end
                    local adjPortraitH = playerTargetHeightWithCp + pSizeAdj
                    if adjPortraitH < 8 then adjPortraitH = 8 end
                    if not showPortrait then
                        totalWidth = settings.frameWidth
                        portraitHeight = 0
                    elseif isAttached then
                        totalWidth = adjPortraitH + settings.frameWidth
                        portraitHeight = adjPortraitH
                    else
                        totalWidth = settings.frameWidth
                        portraitHeight = 0
                    end
                    -- Health bar xOffset: only offset when portrait is attached on the left
                    local healthXOffset = 0
                    local healthRightInset = 0
                    if showPortrait and isAttached and effectiveSide == "left" then
                        healthXOffset = portraitHeight
                    elseif showPortrait and isAttached and effectiveSide == "right" then
                        healthRightInset = portraitHeight
                    end

                    PP.Size(frame, totalWidth, playerTargetHeightWithCp + btbExtra)

                    if frame.Portrait and frame.Portrait.backdrop then
                        PP.Size(frame.Portrait.backdrop, adjPortraitH, adjPortraitH)
                        -- Reposition portrait for attached/detached
                        frame.Portrait.backdrop:ClearAllPoints()
                        local pBtbTopOff = (btbPos == "top" and settings.bottomTextBar) and (settings.bottomTextBarHeight or 16) or 0
                        if isAttached then
                            if effectiveSide == "left" then
                                PP.Point(frame.Portrait.backdrop, "TOPLEFT", frame, "TOPLEFT", 0, -pBtbTopOff)
                            else
                                PP.Point(frame.Portrait.backdrop, "TOPRIGHT", frame, "TOPRIGHT", 0, -pBtbTopOff)
                            end
                        else
                            if effectiveSide == "top" then
                                frame.Portrait.backdrop:SetPoint("BOTTOM", frame.Health or frame, "TOP", pXOff, 15 + pYOff)
                            elseif effectiveSide == "left" then
                                frame.Portrait.backdrop:SetPoint("TOPRIGHT", frame.Health or frame, "TOPLEFT", -15 + pXOff, pYOff)
                            else
                                frame.Portrait.backdrop:SetPoint("TOPLEFT", frame.Health or frame, "TOPRIGHT", 15 + pXOff, pYOff)
                            end
                        end
                        if frame.Portrait.backdrop._2d then
                            UnsnapTex(frame.Portrait.backdrop._2d)
                        end
                        if frame:IsElementEnabled("Portrait") and frame.Portrait.ForceUpdate then
                            frame.Portrait:ForceUpdate()
                        end
                    end
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        -- Use portrait's actual snapped width for flush alignment
                        if showPortrait and isAttached and frame.Portrait and frame.Portrait.backdrop then
                            local snappedPortW = frame.Portrait.backdrop:GetWidth()
                            healthXOffset = (effectiveSide == "left") and snappedPortW or 0
                            healthRightInset = (effectiveSide == "right") and snappedPortW or 0
                        end
                        frame.Health._xOffset = healthXOffset
                        frame.Health._rightInset = healthRightInset
                        local powerAboveOff = (ppPos == "above") and settings.powerHeight or 0
                        local hTopOff = cpAboveH + powerAboveOff + (btbPos == "top" and settings.bottomTextBar and (settings.bottomTextBarHeight or 16) or 0)
                        frame.Health._topOffset = hTopOff
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", healthXOffset, -hTopOff)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -healthRightInset, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                    end
                    if frame.Power then
                        local pw = settings.frameWidth
                        local ppIsDetached = (ppPos == "detached_top" or ppPos == "detached_bottom")
                        if ppIsDetached and (settings.powerWidth or 0) > 0 then
                            pw = settings.powerWidth
                        end
                        PP.Size(frame.Power, pw, settings.powerHeight)
                        frame.Power:ClearAllPoints()
                        if ppPos == "none" then
                            frame.Power:Hide()
                        elseif ppPos == "above" then
                            PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                            PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                            frame.Power:Show()
                        elseif ppPos == "detached_top" then
                            frame.Power:SetPoint("BOTTOM", frame.Health, "TOP", settings.powerX or 0, 15 + (settings.powerY or 0))
                            frame.Power:Show()
                        elseif ppPos == "detached_bottom" then
                            frame.Power:SetPoint("TOP", frame.Health, "BOTTOM", settings.powerX or 0, -15 + (settings.powerY or 0))
                            frame.Power:Show()
                        else
                            PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                            PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                            frame.Power:Show()
                        end
                        if frame.Power._applyPowerPercentText then frame.Power._applyPowerPercentText(settings) end

                        -- Gray out power bar background for generic melee NPCs
                        if ppPos ~= "none" and (ppPos == "below" or ppPos == "above") then
                            local shouldGray = false
                            if unit ~= "player" and UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsPlayer(unit) then
                                local cls = UnitClassification(unit)
                                local isBoss = (cls == "worldboss")
                                local isElite = (cls == "elite" or cls == "rareelite")
                                local lvl = UnitLevel(unit)
                                local pLvl = UnitLevel("player")
                                local isMB = isElite and (lvl == -1 or (pLvl and lvl >= pLvl + 1))
                                local isCst = (UnitClassBase and UnitClassBase(unit) == "PALADIN")
                                if not isBoss and not isMB and not isCst then shouldGray = true end
                            end
                            if shouldGray then
                                frame.Power._grayedOut = true
                                if frame.Power.bg then
                                    frame.Power.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
                                    frame.Power.bg:SetAlpha(1)
                                end
                            else
                                frame.Power._grayedOut = false
                            end
                        end
                    end
                    if frame.Castbar then
                        local castbarBg = frame.Castbar:GetParent()
                        if settings.showPlayerCastbar then
                            if not frame:IsElementEnabled("Castbar") then
                                frame:EnableElement("Castbar")
                            end
                            if castbarBg then
                                local castBarOffset = 0
                                if showPortrait and isAttached then
                                    castBarOffset = (effectiveSide == "left") and -(adjPortraitH / 2) or (adjPortraitH / 2)
                                end
                                local cbW = totalWidth
                                local cbH = settings.castbarHeight or 14
                                local owH = settings.playerCastbarHeight or 0
                                if owH > 0 then cbH = owH end
                                -- SeatStockCastbar (ThemeClientAssets.lua, called earlier
                                -- this same refresh via ApplyClassicFrameArt) already set
                                -- the REAL slim stock height for Classic/Forever. This
                                -- generic reset runs AFTER it and would clobber that back
                                -- to the module's own 14px default every single time.
                                -- Defer to it unless the user set an explicit per-frame
                                -- override.
                                local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
                                    and KT.VisualThemes:GetRenderedTheme()
                                local usingStockHeight = owH <= 0 and (renderedTheme == "classic"
                                    or renderedTheme == "forever" or renderedTheme == "retail"
                                    or db.profile.frameArtKit == "classic")
                                if usingStockHeight then
                                    castbarBg:SetWidth(cbW)
                                else
                                    castbarBg:SetSize(cbW, cbH)
                                end
                                if frame.Castbar._iconFrame then
                                    frame.Castbar._iconFrame:SetSize(cbH + 1, cbH + 1)
                                    if frame.Castbar._updateIconLayout then frame.Castbar._updateIconLayout() end
                                end
                                castbarBg:ClearAllPoints()
                                local pBtbPos = settings.btbPosition or "bottom"
                                local pBtbVisible = (settings.bottomTextBar and pBtbPos == "bottom" and frame.BottomTextBar and frame.BottomTextBar:IsShown())
                                local anchorFrame = pBtbVisible and frame.BottomTextBar or (ppIsAtt and frame.Power) or frame.Health
                                local pCbXOff = pBtbVisible and 0 or castBarOffset
                                -- Player castbar is always locked to frame ? no x/y offsets
                                castbarBg:SetPoint("TOP", anchorFrame, "BOTTOM", pCbXOff, 0)
                                if frame.Castbar._syncInactiveVisibility then
                                    frame.Castbar._syncInactiveVisibility()
                                end
                            end
                            -- Store per-unit settings for PostCastStart
                            frame.Castbar._eufSettings = settings
                            local pCbColor = ResolveCastbarFillColor("player", settings)
                            frame.Castbar:SetStatusBarColor(pCbColor.r, pCbColor.g, pCbColor.b, castbarOpacity)
                            -- Apply cast bar text settings
                            if frame.Castbar.Text then
                                local snSz = settings.castSpellNameSize or 11
                                SetFSFont(frame.Castbar.Text, snSz)
                                local snC = settings.castSpellNameColor or { r=1, g=1, b=1 }
                                frame.Castbar.Text:SetTextColor(snC.r, snC.g, snC.b)
                            end
                            if frame.Castbar.Time then
                                local dtSz = settings.castDurationSize or 11
                                SetFSFont(frame.Castbar.Time, dtSz)
                                local dtC = settings.castDurationColor or { r=1, g=1, b=1 }
                                frame.Castbar.Time:SetTextColor(dtC.r, dtC.g, dtC.b)
                            end
                            ns.ApplyClassicCastbarLook(frame)
                        else
                            if frame:IsElementEnabled("Castbar") then
                                frame:DisableElement("Castbar")
                            end
                            frame.Castbar:Hide()
                            if castbarBg then castbarBg:Hide() end
                        end
                    end

                    -- Live toggle player absorbs
                    if frame.HealthPrediction then
                        if settings.showPlayerAbsorb then
                            if not frame:IsElementEnabled("HealthPrediction") then
                                frame:EnableElement("HealthPrediction")
                            end
                            if frame.HealthPrediction.damageAbsorb then
                                frame.HealthPrediction.damageAbsorb:Show()
                            end
                            if frame.HealthPrediction.ForceUpdate then
                                frame.HealthPrediction:ForceUpdate()
                            elseif frame.UpdateAllElements then
                                frame:UpdateAllElements("ReloadFrames")
                            end
                        else
                            if frame:IsElementEnabled("HealthPrediction") then
                                frame:DisableElement("HealthPrediction")
                            end
                            if frame.HealthPrediction.damageAbsorb then
                                frame.HealthPrediction.damageAbsorb:Hide()
                            end
                        end
                    end

                    -- Live toggle player buffs
                    if frame.Buffs then
                        if settings.showBuffs then
                            if not frame:IsElementEnabled("Buffs") then
                                frame:EnableElement("Buffs")
                            end
                            frame.Buffs:Show()
                            frame.Buffs.num = settings.maxBuffs or 4
                            -- Reposition buffs based on anchor/growth settings
                            local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
                                settings.buffAnchor, settings.buffGrowth
                            )
                            -- Offset bottom-anchored buffs below castbar when locked to frame
                            local buffCbOff = 0
                            if (settings.buffAnchor == "bottomleft" or settings.buffAnchor == "bottomright"
                                or settings.buffAnchor == "left" or settings.buffAnchor == "right")
                                and settings.showPlayerCastbar then
                                local cbH = settings.playerCastbarHeight or 0
                                if cbH <= 0 then cbH = 14 end
                                buffCbOff = -cbH
                            end
                            -- Only reanchor + ForceUpdate when layout actually changed
                            local kuiBuffYOffset = KT:GetKUIStyleBuffYOffset("player")
                            local buffKey = (bia or "") .. (bfp or "") .. (box or 0) .. (boy or 0) .. buffCbOff .. kuiBuffYOffset .. (bgx or 0) .. (bgy or 0) .. (settings.maxBuffs or 4)
                            if frame.Buffs._lastBuffKey ~= buffKey then
                                frame.Buffs._lastBuffKey = buffKey
                                frame.Buffs:ClearAllPoints()
                                -- CreateTargetAuras/the player-creation block both anchor
                                -- Buffs to frame.Health (KT:ResolveUFAuraBarGeometry's own
                                -- "bar = frame.Health or frame"); anchoring this later
                                -- live-toggle pass to the raw outer frame instead lands
                                -- Buffs at a large offset, far from the actual visible
                                -- health bar. Match the creation-time anchor for
                                -- consistency.
                                frame.Buffs:SetPoint(bia, KT:ResolveUFAuraBarGeometry(frame), bfp,
                                    box * 1, boy * 1 + buffCbOff + kuiBuffYOffset)
                                frame.Buffs.initialAnchor = bia
                                frame.Buffs.growthX = bgx
                                frame.Buffs.growthY = bgy
                                if frame.Buffs.ForceUpdate then
                                    frame.Buffs:ForceUpdate()
                                end
                            end
                        else
                            if frame:IsElementEnabled("Buffs") then
                                frame:DisableElement("Buffs")
                            end
                            frame.Buffs:Hide()
                            frame.Buffs.num = 0
                        end
                    end

                    -- Reposition name and health text (player)
                    if frame._applyTextTags then
                        frame._applyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "both", settings.centerTextContent or "none")
                    end
                    if frame._applyTextPositions then
                        frame._applyTextPositions(settings)
                    end
                    -- KUI's own default text layout just ran, assuming its
                    -- normal (unthemed) health bar width -- re-apply the
                    -- real stock geometry so themed name/value text isn't
                    -- left at that stale, much-wider position. Without this, the health value hangs well past
                    -- the real (narrower) bar's right edge on every reload.
                    ApplyClassicFrameArt(frame, unit)

                    -- Bottom Text Bar update (player)
                    if settings.bottomTextBar then
                        local btbPos2 = settings.btbPosition or "bottom"
                        local btbIsAtt = (btbPos2 == "top" or btbPos2 == "bottom")
                        local btbIsDetached = not btbIsAtt
                        local btbW2 = btbIsDetached and (settings.btbWidth or 0) or 0
                        local btbTW = (btbW2 > 0 and btbIsDetached) and btbW2 or totalWidth
                        -- Compute BTB xOffset for left-side portrait (attached only)
                        local btbXOff = 0
                        if btbIsAtt and showPortrait and isAttached and effectiveSide == "left" then
                            btbXOff = -adjPortraitH
                        end
                        local ppBtbAnchor = (ppIsAtt and frame.Power) or frame.Health
                        if not frame.BottomTextBar then
                            frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, ppBtbAnchor, btbXOff, totalWidth)
                            frame._btb = frame.BottomTextBar
                        else
                            local btb = frame.BottomTextBar
                            PP.Size(btb, btbTW, settings.bottomTextBarHeight or 16)
                            btb:ClearAllPoints()
                            if btbPos2 == "top" then
                                PP.Point(btb, "BOTTOMLEFT", frame.Health or frame, "TOPLEFT", btbXOff, 0)
                            elseif btbPos2 == "detached_top" then
                                btb:SetPoint("BOTTOM", frame, "TOP", settings.btbX or 0, 15 + (settings.btbY or 0))
                            elseif btbPos2 == "detached_bottom" then
                                btb:SetPoint("TOP", frame, "BOTTOM", settings.btbX or 0, -15 + (settings.btbY or 0))
                            else
                                PP.Point(btb, "TOPLEFT", ppBtbAnchor, "BOTTOMLEFT", btbXOff, 0)
                            end
                            -- Update BTB bg color
                            if btb.bg then
                                local bgc = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
                                local bga = settings.btbBgOpacity or 1.0
                                btb.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, bga)
                            end
                            if btb._applyBTBTextTags then
                                btb._applyBTBTextTags(settings.btbLeftContent or "none", settings.btbRightContent or "none", settings.btbCenterContent or "none")
                            end
                            if btb._applyBTBTextPositions then
                                btb._applyBTBTextPositions(settings)
                if btb._applyBTBClassIcon then btb._applyBTBClassIcon(settings) end
                            end
                            btb:Show()
                        end
                    elseif frame.BottomTextBar then
                        frame.BottomTextBar:Hide()
                    end

                    if frame.KTDispelSlots then
                        frame.KTDispelSlots:SetShown(ns.IsDispelOverlayOn(settings))
                        if _G.KTAuraKit and frame._ktDispelPrefix then
                            _G.KTAuraKit.ConfigureDispelSlotStyles(frame._ktDispelPrefix, frame.Health, {
                                alpha = 1,
                                thickness = 2,
                                colors = settings,
                            })
                        end
                    end
                    if frame.dispelBorderFrame then
                        frame.dispelBorderFrame:SetShown(ns.IsDispelOverlayOn(settings))
                    end

                    UpdateBordersForScale(frame, unit)

                elseif unit == "target" then
                    local pSide = settings.portraitSide or "right"
                    local effectiveSide = pSide
                    if isAttached and pSide == "top" then effectiveSide = "right" end
                    local adjPortraitH = playerTargetHeight + pSizeAdj
                    if adjPortraitH < 8 then adjPortraitH = 8 end
                    if not showPortrait then
                        totalWidth = settings.frameWidth
                        portraitHeight = 0
                    elseif isAttached then
                        totalWidth = adjPortraitH + settings.frameWidth
                        portraitHeight = adjPortraitH
                    else
                        totalWidth = settings.frameWidth
                        portraitHeight = 0
                    end
                    -- Health bar xOffset: only offset when portrait is attached on the left
                    local healthXOffset = 0
                    local healthRightInset = 0
                    if showPortrait and isAttached and effectiveSide == "left" then
                        healthXOffset = portraitHeight
                    elseif showPortrait and isAttached and effectiveSide == "right" then
                        healthRightInset = portraitHeight
                    end

                    PP.Size(frame, totalWidth, targetFrameHeight)

                    if frame.Portrait and frame.Portrait.backdrop then
                        PP.Size(frame.Portrait.backdrop, adjPortraitH, adjPortraitH)
                        frame.Portrait.backdrop:ClearAllPoints()
                        local btbTopOff = (btbPos == "top" and settings.bottomTextBar) and (settings.bottomTextBarHeight or 16) or 0
                        if isAttached then
                            if effectiveSide == "left" then
                                PP.Point(frame.Portrait.backdrop, "TOPLEFT", frame, "TOPLEFT", 0, -btbTopOff)
                            else
                                PP.Point(frame.Portrait.backdrop, "TOPRIGHT", frame, "TOPRIGHT", 0, -btbTopOff)
                            end
                        else
                            if effectiveSide == "top" then
                                frame.Portrait.backdrop:SetPoint("BOTTOM", frame.Health or frame, "TOP", pXOff, 15 + pYOff)
                            elseif effectiveSide == "left" then
                                frame.Portrait.backdrop:SetPoint("TOPRIGHT", frame.Health or frame, "TOPLEFT", -15 + pXOff, pYOff)
                            else
                                frame.Portrait.backdrop:SetPoint("TOPLEFT", frame.Health or frame, "TOPRIGHT", 15 + pXOff, pYOff)
                            end
                        end
                        if frame.Portrait.backdrop._2d then
                            UnsnapTex(frame.Portrait.backdrop._2d)
                        end
                        if frame:IsElementEnabled("Portrait") and frame.Portrait.ForceUpdate then
                            frame.Portrait:ForceUpdate()
                        end
                    end
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        -- Use portrait's actual snapped width for flush alignment
                        if showPortrait and isAttached and frame.Portrait and frame.Portrait.backdrop then
                            local snappedPortW = frame.Portrait.backdrop:GetWidth()
                            healthXOffset = (effectiveSide == "left") and snappedPortW or 0
                            healthRightInset = (effectiveSide == "right") and snappedPortW or 0
                        end
                        local tBtbTopOff = (btbPos == "top" and settings.bottomTextBar and (settings.bottomTextBarHeight or 16) or 0)
                        local tPowerAboveOff = (ppPos == "above") and settings.powerHeight or 0
                        local tTopOff = tBtbTopOff + tPowerAboveOff
                        frame.Health._xOffset = healthXOffset
                        frame.Health._rightInset = healthRightInset
                        frame.Health._topOffset = tTopOff
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", healthXOffset, -tTopOff)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -healthRightInset, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                    end
                    if frame.Power then
                        local pw2 = settings.frameWidth
                        local ppIsDetached2 = (ppPos == "detached_top" or ppPos == "detached_bottom")
                        if ppIsDetached2 and (settings.powerWidth or 0) > 0 then
                            pw2 = settings.powerWidth
                        end
                        PP.Size(frame.Power, pw2, settings.powerHeight)
                        frame.Power:ClearAllPoints()
                        if ppPos == "none" then
                            frame.Power:Hide()
                        elseif ppPos == "above" then
                            PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                            PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                            frame.Power:Show()
                        elseif ppPos == "detached_top" then
                            frame.Power:SetPoint("BOTTOM", frame.Health, "TOP", settings.powerX or 0, 15 + (settings.powerY or 0))
                            frame.Power:Show()
                        elseif ppPos == "detached_bottom" then
                            frame.Power:SetPoint("TOP", frame.Health, "BOTTOM", settings.powerX or 0, -15 + (settings.powerY or 0))
                            frame.Power:Show()
                        else
                            PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                            PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                            frame.Power:Show()
                        end
                        if frame.Power._applyPowerPercentText then frame.Power._applyPowerPercentText(settings) end

                        -- Gray out power bar background for generic melee NPCs
                        if ppPos ~= "none" and (ppPos == "below" or ppPos == "above") then
                            local shouldGray = false
                            if unit ~= "player" and UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsPlayer(unit) then
                                local cls = UnitClassification(unit)
                                local isBoss = (cls == "worldboss")
                                local isElite = (cls == "elite" or cls == "rareelite")
                                local lvl = UnitLevel(unit)
                                local pLvl = UnitLevel("player")
                                local isMB = isElite and (lvl == -1 or (pLvl and lvl >= pLvl + 1))
                                local isCst = (UnitClassBase and UnitClassBase(unit) == "PALADIN")
                                if not isBoss and not isMB and not isCst then shouldGray = true end
                            end
                            if shouldGray then
                                frame.Power._grayedOut = true
                                if frame.Power.bg then
                                    frame.Power.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
                                    frame.Power.bg:SetAlpha(1)
                                end
                            else
                                frame.Power._grayedOut = false
                            end
                        end
                    end

                    -- Reposition name and health text (target)
                    if frame._applyTextTags then
                        frame._applyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "both", settings.centerTextContent or "none")
                    end
                    if frame._applyTextPositions then
                        frame._applyTextPositions(settings)
                    end
                    -- Same re-apply as the player block above -- see its
                    -- comment for why this is needed on every reload.
                    ApplyClassicFrameArt(frame, unit)

                    -- Bottom Text Bar update (target) ? must come before castbar so castbar can anchor to it
                    local tPpBtbAnchor = (ppIsAtt and frame.Power) or frame.Health
                    if settings.bottomTextBar then
                        local btbPos2 = settings.btbPosition or "bottom"
                        local btbIsAtt = (btbPos2 == "top" or btbPos2 == "bottom")
                        local btbIsDetached = not btbIsAtt
                        local btbW2 = btbIsDetached and (settings.btbWidth or 0) or 0
                        local btbTW = (btbW2 > 0 and btbIsDetached) and btbW2 or totalWidth
                        local btbXOff = 0
                        if btbIsAtt and showPortrait and isAttached and effectiveSide == "left" then
                            btbXOff = -adjPortraitH
                        end
                        if not frame.BottomTextBar then
                            frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, tPpBtbAnchor, btbXOff, totalWidth)
                            frame._btb = frame.BottomTextBar
                        else
                            local btb = frame.BottomTextBar
                            PP.Size(btb, btbTW, settings.bottomTextBarHeight or 16)
                            btb:ClearAllPoints()
                            if btbPos2 == "top" then
                                PP.Point(btb, "BOTTOMLEFT", frame.Health or frame, "TOPLEFT", btbXOff, 0)
                            elseif btbPos2 == "detached_top" then
                                btb:SetPoint("BOTTOM", frame, "TOP", settings.btbX or 0, 15 + (settings.btbY or 0))
                            elseif btbPos2 == "detached_bottom" then
                                btb:SetPoint("TOP", frame, "BOTTOM", settings.btbX or 0, -15 + (settings.btbY or 0))
                            else
                                PP.Point(btb, "TOPLEFT", tPpBtbAnchor, "BOTTOMLEFT", btbXOff, 0)
                            end
                            if btb.bg then
                                local bgc = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
                                local bga = settings.btbBgOpacity or 1.0
                                btb.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, bga)
                            end
                            if btb._applyBTBTextTags then
                                btb._applyBTBTextTags(settings.btbLeftContent or "none", settings.btbRightContent or "none", settings.btbCenterContent or "none")
                            end
                            if btb._applyBTBTextPositions then
                                btb._applyBTBTextPositions(settings)
                                if btb._applyBTBClassIcon then btb._applyBTBClassIcon(settings) end
                            end
                            btb:Show()
                        end
                    elseif frame.BottomTextBar then
                        frame.BottomTextBar:Hide()
                    end

                    -- Castbar (target) ? anchors to BTB when BTB is bottom, otherwise to power/health
                    if frame.Castbar then
                        local castbarBg = frame.Castbar:GetParent()
                        if castbarBg then
                            if settings.showCastbar ~= false then
                                if not frame:IsElementEnabled("Castbar") then
                                    frame:EnableElement("Castbar")
                                end
                                local castBarOffset = 0
                                if showPortrait and isAttached then
                                    castBarOffset = (effectiveSide == "left") and -(adjPortraitH / 2) or (adjPortraitH / 2)
                                end
                                -- Same clobbering bug as the player castbar block above:
                                -- SeatStockCastbar already set the real slim stock height
                                -- for Classic/Forever earlier this refresh (via
                                -- ApplyClassicFrameArt) -- defer to it instead of
                                -- resetting to the module's generic 14px default.
                                local targetRenderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
                                    and KT.VisualThemes:GetRenderedTheme()
                                local targetUsingStockHeight = (targetRenderedTheme == "classic"
                                    or targetRenderedTheme == "forever" or targetRenderedTheme == "retail"
                                    or db.profile.frameArtKit == "classic")
                                if targetUsingStockHeight then
                                    castbarBg:SetWidth(totalWidth)
                                else
                                    castbarBg:SetSize(totalWidth, settings.castbarHeight or 14)
                                end
                                if frame.Castbar._iconFrame then
                                    local cbH = castbarBg:GetHeight() or settings.castbarHeight or 14
                                    frame.Castbar._iconFrame:SetSize(cbH + 1, cbH + 1)
                                    if frame.Castbar._updateIconLayout then frame.Castbar._updateIconLayout() end
                                end
                                castbarBg:ClearAllPoints()
                                local tBtbPos = settings.btbPosition or "bottom"
                                local btbVisible = (settings.bottomTextBar and tBtbPos == "bottom" and frame.BottomTextBar and frame.BottomTextBar:IsShown())
                                local cbAnchor = btbVisible and frame.BottomTextBar or tPpBtbAnchor
                                local cbXOff = btbVisible and 0 or castBarOffset
                                castbarBg:SetPoint("TOP", cbAnchor, "BOTTOM", cbXOff, 0)
                                if frame.Castbar._syncInactiveVisibility then
                                    frame.Castbar._syncInactiveVisibility()
                                end
                            else
                                if frame:IsElementEnabled("Castbar") then
                                    frame:DisableElement("Castbar")
                                end
                                frame.Castbar:Hide()
                                castbarBg:Hide()
                            end
                        end
                        -- Store per-unit settings for PostCastStart
                        frame.Castbar._eufSettings = settings
                        local tCbColor = ResolveCastbarFillColor("target", settings)
                        frame.Castbar:SetStatusBarColor(tCbColor.r, tCbColor.g, tCbColor.b, castbarOpacity)
                        -- Apply cast bar text settings
                        if frame.Castbar.Text then
                            local snSz = settings.castSpellNameSize or 11
                            SetFSFont(frame.Castbar.Text, snSz)
                            local snC = settings.castSpellNameColor or { r=1, g=1, b=1 }
                            frame.Castbar.Text:SetTextColor(snC.r, snC.g, snC.b)
                        end
                        if frame.Castbar.Time then
                            local dtSz = settings.castDurationSize or 11
                            SetFSFont(frame.Castbar.Time, dtSz)
                            local dtC = settings.castDurationColor or { r=1, g=1, b=1 }
                            frame.Castbar.Time:SetTextColor(dtC.r, dtC.g, dtC.b)
                        end
                        ns.ApplyClassicCastbarLook(frame)
                    end

                    -- Buffs
                    if frame.Buffs then
                        local showBuffs = settings.showBuffs ~= false
                        if showBuffs then
                            if not frame:IsElementEnabled("Buffs") then
                                frame:EnableElement("Buffs")
                            end
                            frame.Buffs:Show()
                            frame.Buffs.num = settings.maxBuffs or 20
                            local bfp, bia, bgx, bgy, box, boy = ResolveBuffLayout(
                                settings.buffAnchor, settings.buffGrowth
                            )
                            local liveCbOff = 0
                            if settings.showCastbar ~= false then
                                local bAnc = settings.buffAnchor or "topleft"
                                if bAnc == "bottomleft" or bAnc == "bottomright" then
                                    local cbH = settings.castbarHeight or 14
                                    if cbH <= 0 then cbH = 14 end
                                    liveCbOff = -cbH
                                end
                            end
                            local kuiBuffYOffset = KT:GetKUIStyleBuffYOffset("target")
                            local buffKey = (bia or "") .. (bfp or "") .. (box or 0) .. (boy or 0) .. (bgx or 0) .. (bgy or 0) .. (settings.maxBuffs or 20) .. liveCbOff .. kuiBuffYOffset
                            if frame.Buffs._lastBuffKey ~= buffKey then
                                frame.Buffs._lastBuffKey = buffKey
                                frame.Buffs:ClearAllPoints()
                                -- Same as the player block above: CreateTargetAuras
                                -- anchors Buffs to frame.Health, so this live-toggle pass
                                -- does too instead of the raw outer frame. Match the
                                -- creation-time anchor.
                                frame.Buffs:SetPoint(bia, KT:ResolveUFAuraBarGeometry(frame), bfp,
                                    box * 1, boy * 1 + liveCbOff + kuiBuffYOffset)
                                frame.Buffs.initialAnchor = bia
                                frame.Buffs.growthX = bgx
                                frame.Buffs.growthY = bgy
                                if frame.Buffs.ForceUpdate then
                                    frame.Buffs:ForceUpdate()
                                end
                            end
                        else
                            if frame:IsElementEnabled("Buffs") then
                                frame:DisableElement("Buffs")
                            end
                            frame.Buffs:Hide()
                            frame.Buffs.num = 0
                        end
                    end

                    -- Debuffs
                    if frame.KTDebuffs then
                        ApplyTargetAuraSettings(frame, settings)
                    elseif frame.Debuffs then
                        frame.Debuffs.num = settings.maxDebuffs or 20
                        frame.Debuffs.onlyShowPlayer = settings.onlyPlayerDebuffs and true or nil
                        local dfp, dia, dgx, dgy, dox, doy = ResolveBuffLayout(
                            settings.debuffAnchor or "bottomleft",
                            settings.debuffGrowth or "auto"
                        )
                        local liveDbCbOff = 0
                        if settings.showCastbar ~= false then
                            local dAnc = settings.debuffAnchor or "bottomleft"
                            if dAnc == "bottomleft" or dAnc == "bottomright" then
                                local cbH = settings.castbarHeight or 14
                                if cbH <= 0 then cbH = 14 end
                                -- Debuffs (player and target) sit a
                                -- bit closer/higher to the frame.
                                liveDbCbOff = -cbH + KT:GetStyledDebuffLift()
                            end
                        end
                        local debuffKey = (dia or "") .. (dfp or "") .. (dox or 0) .. (doy or 0) .. (dgx or 0) .. (dgy or 0) .. (settings.maxDebuffs or 20) .. liveDbCbOff .. (settings.onlyPlayerDebuffs and "1" or "0")
                        if frame.Debuffs._lastDebuffKey ~= debuffKey then
                            frame.Debuffs._lastDebuffKey = debuffKey
                            frame.Debuffs:ClearAllPoints()
                            frame.Debuffs:SetPoint(dia, frame, dfp, dox * 1, doy * 1 + liveDbCbOff)
                            frame.Debuffs.initialAnchor = dia
                            frame.Debuffs.growthX = dgx
                            frame.Debuffs.growthY = dgy
                            if frame.Debuffs.ForceUpdate then
                                frame.Debuffs:ForceUpdate()
                            end
                        end
                    end

                    UpdateBordersForScale(frame, unit)
                end

                -- (health tag re-tagging now handled by _applyTextTags above)

            elseif unit == "focus" then
                local fPpPos = settings.powerPosition or "below"
                local fPpIsAtt = (fPpPos == "below" or fPpPos == "above")
                local powerHeight = fPpIsAtt and (settings.powerHeight or 6) or 0
                local focusBarHeight = settings.healthHeight + powerHeight
                local fBtbPos = settings.btbPosition or "bottom"
                local fBtbIsAtt = (fBtbPos == "top" or fBtbPos == "bottom")
                local fBtbExtra = (settings.bottomTextBar and fBtbIsAtt) and (settings.bottomTextBarHeight or 16) or 0
                local totalWidth = 0
                local isAttached = (db.profile.portraitStyle or "attached") == "attached"
                local pSide = settings.portraitSide or "right"
                local effectiveSide = pSide
                if isAttached and pSide == "top" then effectiveSide = "right" end
                local pSizeAdj = settings.portraitSize or 0
                if not isAttached then pSizeAdj = pSizeAdj + 10 end
                local pXOff = settings.portraitX or 0
                local pYOff = settings.portraitY or 0
                if not isAttached then pYOff = pYOff + 5 end
                local adjPortraitH = focusBarHeight + pSizeAdj
                if adjPortraitH < 8 then adjPortraitH = 8 end

                if not showPortrait then
                    totalWidth = settings.frameWidth
                elseif isAttached then
                    totalWidth = adjPortraitH + settings.frameWidth
                else
                    totalWidth = settings.frameWidth
                end

                PP.Size(frame, totalWidth, focusBarHeight + fBtbExtra)

                if frame.Portrait and frame.Portrait.backdrop then
                    PP.Size(frame.Portrait.backdrop, adjPortraitH, adjPortraitH)
                    -- Trim portrait to stay within frame bounds
                    if showPortrait and isAttached then
                        local frameW = frame:GetWidth()
                        local frameH = frame:GetHeight()
                        local portW = frame.Portrait.backdrop:GetWidth()
                        local portH = frame.Portrait.backdrop:GetHeight()
                        if portW + settings.frameWidth > frameW + 0.01 then
                            PP.Width(frame.Portrait.backdrop, frameW - settings.frameWidth)
                        end
                        if portH > frameH + 0.01 then
                            PP.Height(frame.Portrait.backdrop, frameH)
                        end
                    end
                    -- Reposition portrait for attached/detached
                    frame.Portrait.backdrop:ClearAllPoints()
                    local fBtbTopOff = (fBtbPos == "top" and settings.bottomTextBar) and (settings.bottomTextBarHeight or 16) or 0
                    if isAttached then
                        if effectiveSide == "left" then
                            PP.Point(frame.Portrait.backdrop, "TOPLEFT", frame, "TOPLEFT", 0, -fBtbTopOff)
                        else
                            PP.Point(frame.Portrait.backdrop, "TOPRIGHT", frame, "TOPRIGHT", 0, -fBtbTopOff)
                        end
                    else
                        if effectiveSide == "top" then
                            frame.Portrait.backdrop:SetPoint("BOTTOM", frame.Health or frame, "TOP", pXOff, 15 + pYOff)
                        elseif effectiveSide == "left" then
                            frame.Portrait.backdrop:SetPoint("TOPRIGHT", frame.Health or frame, "TOPLEFT", -15 + pXOff, pYOff)
                        else
                            frame.Portrait.backdrop:SetPoint("TOPLEFT", frame.Health or frame, "TOPRIGHT", 15 + pXOff, pYOff)
                        end
                    end
                    -- Re-apply pixel snap disable after resize
                    if frame.Portrait.backdrop._2d then
                        UnsnapTex(frame.Portrait.backdrop._2d)
                    end
                    if frame:IsElementEnabled("Portrait") and frame.Portrait.ForceUpdate then
                        frame.Portrait:ForceUpdate()
                    end
                end
                if frame.Health then
                    frame.Health:ClearAllPoints()
                    local focusHealthXOff = (showPortrait and isAttached and effectiveSide == "left") and adjPortraitH or 0
                    local focusHealthRightInset = (showPortrait and isAttached and effectiveSide == "right") and adjPortraitH or 0
                    -- Use portrait's actual snapped width for flush alignment
                    if showPortrait and isAttached and frame.Portrait and frame.Portrait.backdrop then
                        local snappedPortW = frame.Portrait.backdrop:GetWidth()
                        focusHealthXOff = (effectiveSide == "left") and snappedPortW or 0
                        focusHealthRightInset = (effectiveSide == "right") and snappedPortW or 0
                    end
                    local fHTopOff = (fBtbPos == "top" and settings.bottomTextBar and (settings.bottomTextBarHeight or 16) or 0)
                    local fPowerAboveOff = (fPpPos == "above") and (settings.powerHeight or 6) or 0
                    fHTopOff = fHTopOff + fPowerAboveOff
                    frame.Health._xOffset = focusHealthXOff
                    frame.Health._rightInset = focusHealthRightInset
                    frame.Health._topOffset = fHTopOff
                    PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", focusHealthXOff, -fHTopOff)
                    PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -focusHealthRightInset, 0)
                    PP.Height(frame.Health, settings.healthHeight)
                end
                if frame.Power then
                    local fpw = settings.frameWidth
                    local fPpIsDet = (fPpPos == "detached_top" or fPpPos == "detached_bottom")
                    if fPpIsDet and (settings.powerWidth or 0) > 0 then
                        fpw = settings.powerWidth
                    end
                    PP.Size(frame.Power, fpw, settings.powerHeight or 6)
                    frame.Power:ClearAllPoints()
                    if fPpPos == "none" then
                        frame.Power:Hide()
                    elseif fPpPos == "above" then
                        PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                        PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                        frame.Power:Show()
                    elseif fPpPos == "detached_top" then
                        frame.Power:SetPoint("BOTTOM", frame.Health, "TOP", settings.powerX or 0, 15 + (settings.powerY or 0))
                        frame.Power:Show()
                    elseif fPpPos == "detached_bottom" then
                        frame.Power:SetPoint("TOP", frame.Health, "BOTTOM", settings.powerX or 0, -15 + (settings.powerY or 0))
                        frame.Power:Show()
                    else
                        PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                        PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                        frame.Power:Show()
                    end
                    if frame.Power._applyPowerPercentText then frame.Power._applyPowerPercentText(settings) end
                end
                if frame._applyTextTags then
                    frame._applyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "perhp", settings.centerTextContent or "none")
                end
                if frame._applyTextPositions then
                    frame._applyTextPositions(settings)
                end
                -- Same re-apply as the player block earlier in this
                -- function -- see its comment for why this is needed on
                -- every reload.
                ApplyClassicFrameArt(frame, unit)

                -- Bottom Text Bar update (focus) ? must come before castbar so castbar can anchor to it
                local fPpBtbAnchor = (fPpIsAtt and frame.Power) or frame.Health
                if settings.bottomTextBar then
                    local btbPos2 = settings.btbPosition or "bottom"
                    local btbIsAtt2 = (btbPos2 == "top" or btbPos2 == "bottom")
                    local btbIsDet2 = not btbIsAtt2
                    local btbW2 = btbIsDet2 and (settings.btbWidth or 0) or 0
                    local btbTW = (btbW2 > 0 and btbIsDet2) and btbW2 or totalWidth
                    local btbXOff = 0
                    if btbIsAtt2 and showPortrait and isAttached and effectiveSide == "left" then
                        btbXOff = -adjPortraitH
                    end
                    if not frame.BottomTextBar then
                        frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, fPpBtbAnchor, btbXOff, totalWidth)
                        frame._btb = frame.BottomTextBar
                    else
                        local btb = frame.BottomTextBar
                        PP.Size(btb, btbTW, settings.bottomTextBarHeight or 16)
                        btb:ClearAllPoints()
                        if btbPos2 == "top" then
                            PP.Point(btb, "BOTTOMLEFT", frame.Health or frame, "TOPLEFT", btbXOff, 0)
                        elseif btbPos2 == "detached_top" then
                            btb:SetPoint("BOTTOM", frame, "TOP", settings.btbX or 0, 15 + (settings.btbY or 0))
                        elseif btbPos2 == "detached_bottom" then
                            btb:SetPoint("TOP", frame, "BOTTOM", settings.btbX or 0, -15 + (settings.btbY or 0))
                        else
                            PP.Point(btb, "TOPLEFT", fPpBtbAnchor, "BOTTOMLEFT", btbXOff, 0)
                        end
                        if btb.bg then
                            local bgc = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
                            local bga = settings.btbBgOpacity or 1.0
                            btb.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, bga)
                        end
                        if btb._applyBTBTextTags then
                            btb._applyBTBTextTags(settings.btbLeftContent or "none", settings.btbRightContent or "none", settings.btbCenterContent or "none")
                        end
                        if btb._applyBTBTextPositions then
                            btb._applyBTBTextPositions(settings)
                            if btb._applyBTBClassIcon then btb._applyBTBClassIcon(settings) end
                        end
                        btb:Show()
                    end
                elseif frame.BottomTextBar then
                    frame.BottomTextBar:Hide()
                end

                -- Castbar (focus) ? anchors to BTB when BTB is bottom, otherwise to power/health
                if frame.Castbar then
                    local castbarBg = frame.Castbar:GetParent()
                    if castbarBg then
                        if settings.showCastbar ~= false then
                            if not frame:IsElementEnabled("Castbar") then
                                frame:EnableElement("Castbar")
                            end
                            local castBarOffset = 0
                            if showPortrait and isAttached then
                                castBarOffset = (effectiveSide == "left") and -(adjPortraitH / 2) or (adjPortraitH / 2)
                            end
                            castbarBg:SetSize(totalWidth, settings.castbarHeight or 14)
                            if frame.Castbar._iconFrame then
                                local cbH = settings.castbarHeight or 14
                                frame.Castbar._iconFrame:SetSize(cbH + 1, cbH + 1)
                                if frame.Castbar._updateIconLayout then frame.Castbar._updateIconLayout() end
                            end
                            castbarBg:ClearAllPoints()
                            local fBtbPos2 = settings.btbPosition or "bottom"
                            local btbVisible = (settings.bottomTextBar and fBtbPos2 == "bottom" and frame.BottomTextBar and frame.BottomTextBar:IsShown())
                            local cbAnchor = btbVisible and frame.BottomTextBar or fPpBtbAnchor
                            local cbXOff = btbVisible and 0 or castBarOffset
                            castbarBg:SetPoint("TOP", cbAnchor, "BOTTOM", cbXOff, 0)
                            if frame.Castbar._syncInactiveVisibility then
                                frame.Castbar._syncInactiveVisibility()
                            end
                        else
                            if frame:IsElementEnabled("Castbar") then
                                frame:DisableElement("Castbar")
                            end
                            frame.Castbar:Hide()
                            castbarBg:Hide()
                        end
                    end
                    -- Store per-unit settings for PostCastStart
                    frame.Castbar._eufSettings = settings
                    local fCbColor = ResolveCastbarFillColor("focus", settings)
                    frame.Castbar:SetStatusBarColor(fCbColor.r, fCbColor.g, fCbColor.b, castbarOpacity)
                    -- Apply cast bar text settings
                    if frame.Castbar.Text then
                        local snSz = settings.castSpellNameSize or 11
                        SetFSFont(frame.Castbar.Text, snSz)
                        local snC = settings.castSpellNameColor or { r=1, g=1, b=1 }
                        frame.Castbar.Text:SetTextColor(snC.r, snC.g, snC.b)
                    end
                    if frame.Castbar.Time then
                        local dtSz = settings.castDurationSize or 11
                        SetFSFont(frame.Castbar.Time, dtSz)
                        local dtC = settings.castDurationColor or { r=1, g=1, b=1 }
                        frame.Castbar.Time:SetTextColor(dtC.r, dtC.g, dtC.b)
                    end
                    ns.ApplyClassicCastbarLook(frame)
                end

                UpdateBordersForScale(frame, unit)

            elseif unit == "pet" or unit == "targettarget" or unit == "focustarget" then
                if unit == "pet" then
                    local showPetPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false
                    local petW = settings.frameWidth
                    if showPetPortrait then
                        petW = settings.healthHeight + settings.frameWidth
                    end
                    PP.Size(frame, petW, settings.healthHeight)
                    if frame.Portrait and frame.Portrait.backdrop then
                        PP.Size(frame.Portrait.backdrop, settings.healthHeight, settings.healthHeight)
                    end
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        -- Use portrait's actual snapped width for flush alignment
                        local petPortOff = 0
                        if showPetPortrait and frame.Portrait and frame.Portrait.backdrop then
                            petPortOff = frame.Portrait.backdrop:GetWidth()
                        elseif showPetPortrait then
                            petPortOff = settings.healthHeight
                        end
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", petPortOff, 0)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", 0, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                        frame.Health._xOffset = petPortOff
                        frame.Health._rightInset = 0
                        frame.Health._topOffset = 0
                    end
                    -- Theme art re-seats (or clears) after the generic layout.
                    ApplyClassicFrameArt(frame, unit)
                else
                    PP.Size(frame, settings.frameWidth, settings.healthHeight)
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", 0, 0)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", 0, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                    end
                end

                UpdateBordersForScale(frame, unit)

            elseif unit:match("^boss%d$") then
                local bPpPos = settings.powerPosition or "below"
                local bPpIsAtt = (bPpPos == "below" or bPpPos == "above")
                local powerHeight = bPpIsAtt and (settings.powerHeight or 6) or 0
                local bossBarHeight = settings.healthHeight + powerHeight
                local totalWidth = 0

                if not showPortrait then
                    totalWidth = settings.frameWidth
                else
                    totalWidth = bossBarHeight + settings.frameWidth
                end

                PP.Size(frame, totalWidth, bossBarHeight)

                if frame.Portrait and frame.Portrait.backdrop then
                    PP.Size(frame.Portrait.backdrop, bossBarHeight, bossBarHeight)
                end
                if frame.Health then
                    frame.Health:ClearAllPoints()
                    -- Use portrait's actual snapped width for flush alignment
                    local bossRightInset = 0
                    if showPortrait then
                        if frame.Portrait and frame.Portrait.backdrop then
                            bossRightInset = frame.Portrait.backdrop:GetWidth()
                        else
                            bossRightInset = bossBarHeight
                        end
                    end
                    local bPowerAboveOff = (bPpPos == "above") and (settings.powerHeight or 6) or 0
                    PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", 0, -bPowerAboveOff)
                    PP.Point(frame.Health, "RIGHT", frame, "RIGHT", -bossRightInset, 0)
                    PP.Height(frame.Health, settings.healthHeight)
                    frame.Health._xOffset = 0
                    frame.Health._rightInset = bossRightInset
                    frame.Health._topOffset = bPowerAboveOff
                end
                if frame.Power then
                    local bpw = settings.frameWidth
                    local bPpIsDet = (bPpPos == "detached_top" or bPpPos == "detached_bottom")
                    if bPpIsDet and (settings.powerWidth or 0) > 0 then
                        bpw = settings.powerWidth
                    end
                    frame.Power:SetSize(bpw, settings.powerHeight or 6)
                    frame.Power:ClearAllPoints()
                    if bPpPos == "none" then
                        frame.Power:Hide()
                    elseif bPpPos == "above" then
                        PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                        PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                        frame.Power:Show()
                    elseif bPpPos == "detached_top" then
                        frame.Power:SetPoint("BOTTOM", frame.Health, "TOP", settings.powerX or 0, 15 + (settings.powerY or 0))
                        frame.Power:Show()
                    elseif bPpPos == "detached_bottom" then
                        frame.Power:SetPoint("TOP", frame.Health, "BOTTOM", settings.powerX or 0, -15 + (settings.powerY or 0))
                        frame.Power:Show()
                    else
                        PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                        PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                        frame.Power:Show()
                    end
                    if frame.Power._applyPowerPercentText then frame.Power._applyPowerPercentText(settings) end

                    -- Gray out power bar background for generic melee NPCs
                    if bPpPos ~= "none" and (bPpPos == "below" or bPpPos == "above") then
                        local shouldGray = false
                        if UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsPlayer(unit) then
                            local cls = UnitClassification(unit)
                            local isBoss = (cls == "worldboss")
                            local isElite = (cls == "elite" or cls == "rareelite")
                            local lvl = UnitLevel(unit)
                            local pLvl = UnitLevel("player")
                            local isMB = isElite and (lvl == -1 or (pLvl and lvl >= pLvl + 1))
                            local isCst = (UnitClassBase and UnitClassBase(unit) == "PALADIN")
                            if not isBoss and not isMB and not isCst then shouldGray = true end
                        end
                        if shouldGray then
                            frame.Power._grayedOut = true
                            if frame.Power.bg then
                                frame.Power.bg:SetColorTexture(0.25, 0.25, 0.25, 1)
                                frame.Power.bg:SetAlpha(1)
                            end
                        else
                            frame.Power._grayedOut = false
                        end
                    end
                end

                UpdateBordersForScale(frame, unit)
            end

            -- Determine if this is a mini frame that inherits border/texture/font
            local isMiniFrame = (unit == "pet" or unit == "targettarget" or unit == "focustarget" or unit:match("^boss%d$"))
            local donorSettings = isMiniFrame and GetMiniDonorSettings() or settings

            -- Apply health bar texture overlay (use donor for mini frames)
            if isMiniFrame then
                -- Override texture settings from donor
                local uKey = UnitToSettingsKey(unit)
                local origTex = settings.healthBarTexture
                settings.healthBarTexture = donorSettings.healthBarTexture
                ApplyHealthBarTexture(frame.Health, uKey)
                settings.healthBarTexture = origTex
                ApplyHealthBarAlpha(frame.Health, uKey)
            else
                ApplyHealthBarTexture(frame.Health, UnitToSettingsKey(unit))
                ApplyHealthBarAlpha(frame.Health, UnitToSettingsKey(unit))
            end
            ApplyDarkTheme(frame.Health)
            if frame.Health.ForceUpdate then
                frame.Health:ForceUpdate()
            end

            -- Apply power bar opacity
            if frame.Power then
                ApplyPowerBarAlpha(frame.Power, UnitToSettingsKey(unit))

                -- Re-apply power bar fill color based on powerPercentPowerColor toggle
                local usePowerColor = settings.powerPercentPowerColor ~= false
                if usePowerColor then
                    frame.Power.colorPower = true
                    frame.Power.PostUpdateColor = nil
                else
                    local customFill = settings.customPowerFillColor
                    frame.Power.colorPower = false
                    if customFill then
                        frame.Power:SetStatusBarColor(customFill.r, customFill.g, customFill.b)
                        frame.Power.PostUpdateColor = function(self)
                            local s2 = GetSettingsForUnit(unit)
                            local cf = s2 and s2.customPowerFillColor
                            if cf then self:SetStatusBarColor(cf.r, cf.g, cf.b) end
                        end
                    else
                        frame.Power:SetStatusBarColor(0, 0, 1)
                        frame.Power.PostUpdateColor = function(self)
                            self:SetStatusBarColor(0, 0, 1)
                        end
                    end
                end
                local customBg = settings.customPowerBgColor
                if customBg and frame.Power.bg then
                    frame.Power.bg:SetColorTexture(customBg.r, customBg.g, customBg.b, 1)
                elseif frame.Power.bg then
                    frame.Power.bg:SetColorTexture(17/255, 17/255, 17/255, 1)
                end
                if frame.Power.ForceUpdate then frame.Power:ForceUpdate() end
            end

            if frame.unifiedBorder then
                -- Skip entirely when real stock art owns this unit's border.
                -- Running unconditionally on every ReloadFrames pass would
                -- re-show the generic border regardless of whether real
                -- stock art (ApplyForeverUnitFrameArt/ApplyClassicUnitFrameArt,
                -- earlier in this same refresh) had already hidden it for
                -- player/target under Classic/Forever/Retail, drawing the
                -- plain generic border on top of target's real decorative
                -- Retail ring.
                local ufRenderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
                    and KT.VisualThemes:GetRenderedTheme()
                local ufUsingRealArt = (unit == "player" or unit == "target")
                    and (ufRenderedTheme == "classic" or ufRenderedTheme == "forever"
                        or ufRenderedTheme == "retail" or (db.profile and db.profile.frameArtKit == "classic"))
                if ufUsingRealArt then
                    frame.unifiedBorder:Hide()
                else
                    frame.unifiedBorder:ClearAllPoints()
                    local bs = donorSettings.borderSize or 1
                    local bc = donorSettings.borderColor or { r = 0, g = 0, b = 0 }
                    if bs == 0 then
                        frame.unifiedBorder:Hide()
                    else
                        PP.Point(frame.unifiedBorder, "TOPLEFT", frame, "TOPLEFT", 0, 0)
                        PP.Point(frame.unifiedBorder, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                        PP.UpdateBorder(frame.unifiedBorder, bs, bc.r, bc.g, bc.b, 1)
                        if not (db and db.profile and db.profile.portraitStyle == "circular") then PP.SetHiddenEdge(frame.unifiedBorder, nil) end
                        frame.unifiedBorder:Show()
                    end
                end
            end
            -- Helper: set font on a FontString, using donor font for mini frames
            local function SetMiniFont(fs, sz)
                if not fs or not fs.SetFont then return end
                if isMiniFrame then
                    local f = (Compat and Compat.GetFontOutlineFlag and Compat.GetFontOutlineFlag()) or ""
                    fs:SetFont(donorFontPath, sz or 12, f)
                    if KT and KT.EnableTextFontFallback then
                        KT:EnableTextFontFallback(fs, donorFontPath)
                    end
                    if f == "" then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
                    else fs:SetShadowOffset(0, 0) end
                else
                    SetFSFont(fs, sz)
                end
            end

            if frame.NameText then
                local s = isMiniFrame and donorSettings or GetSettingsForUnit(unit)
                local rts = s.leftTextSize or s.textSize or 12
                SetMiniFont(frame.NameText, rts)
                frame.NameText:SetWordWrap(false)
            end
            if frame.HealthValue then
                local s = isMiniFrame and donorSettings or GetSettingsForUnit(unit)
                local rts = s.rightTextSize or s.textSize or 12
                SetMiniFont(frame.HealthValue, rts)
                frame.HealthValue:SetWordWrap(false)
            end
            if frame.CenterText then
                local s = isMiniFrame and donorSettings or GetSettingsForUnit(unit)
                local cts = s.centerTextSize or s.textSize or 12
                SetMiniFont(frame.CenterText, cts)
                frame.CenterText:SetWordWrap(false)
            end

            -- Apply text tags and positions for mini frames
            if isMiniFrame and frame._applyTextTags then
                frame._applyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "none", settings.centerTextContent or "none")
            end
            if isMiniFrame and frame._applyTextPositions then
                frame._applyTextPositions(settings)
            end

            ApplyClassicFrameArt(frame, unit)

            if frame.Castbar then
                if frame.Castbar.Text then
                    SetFSFont(frame.Castbar.Text, 11)
                end
                if frame.Castbar.Time then
                    SetFSFont(frame.Castbar.Time, 11)
                end
            end

            -- Apply the global dispel toggle to every Unit Frame variant. The
            -- player uses dedicated AuraKit slots while focus/pet/boss use a
            -- frame border; both must be hidden immediately when the option is
            -- switched off, not only after the next UNIT_AURA event.
            local showDispelOverlay = ns.IsDispelOverlayOn(settings)
            if frame.KTDispelSlots then
                frame.KTDispelSlots:SetShown(showDispelOverlay)
            end
            if frame.dispelBorderFrame then
                frame.dispelBorderFrame:SetShown(showDispelOverlay)
                if not showDispelOverlay then
                    SetDispelFrameBorder(frame, nil)
                elseif frame.dispelBorderFrame.GetScript
                    and frame.dispelBorderFrame:GetScript("OnEvent") then
                    UpdateUnitDispelBorderEvent(frame.dispelBorderFrame, "UNIT_AURA", frame.unit)
                end
            end
            if unit == "target" then
                RefreshTargetDebuffDispelStyle(settings)
            end

            if frame._refreshForeverMetadata then
                frame._refreshForeverMetadata()
            end

            end -- else (enabled frame processing)
        end
    end

    -- Apply frame scale for all units after layout (centered, animated)
    for unit, frame in pairs(frames) do
        if type(unit) == "string" and unit:sub(1,1) ~= "_" and frame then
            local s = GetSettingsForUnit(unit)
            local sc = (s and s.frameScale) or 100
            ApplyFrameScaleCentered(frame, unit, sc / 100, true)
        end
    end

    RefreshPlayerStatusIndicators()
    RefreshUnitFrameStrata()
end

local function UpdateBlizzardRestTargets(shouldShow)
    local blizzardRestTargets = {
        _G.PlayerRestIcon,
        _G.PlayerRestLoop,
        _G.PlayerRestGlow,
        _G.PlayerFrame and _G.PlayerFrame.PlayerRestIcon,
        _G.PlayerFrame and _G.PlayerFrame.PlayerRestLoop,
        _G.PlayerFrame and _G.PlayerFrame.PlayerRestGlow,
    }

    for i = 1, #blizzardRestTargets do
        local target = blizzardRestTargets[i]
        if target then
            if shouldShow then
                if target.SetAlpha then target:SetAlpha(1) end
                if target.Show then target:Show() end
            else
                if target.SetAlpha then target:SetAlpha(0) end
                if target.Hide then target:Hide() end
            end

            if not target._ktRestHideHooked and hooksecurefunc and target.Show then
                target._ktRestHideHooked = true
                hooksecurefunc(target, "Show", function(self)
                    if not IsResting() then
                        if self.SetAlpha then self:SetAlpha(0) end
                        self:Hide()
                    end
                end)
            end
        end
    end
end

RefreshPlayerStatusIndicators = function()
    local targetFrame = frames and frames.target
    if targetFrame and targetFrame._refreshForeverMetadata then
        targetFrame._refreshForeverMetadata()
    end

    local frame = frames and frames.player
    local playerDB = db and db.profile and db.profile.player
    if not frame or not playerDB then return end

    local combatStyle = NormalizeCombatIndicatorStyle(playerDB.combatIndicatorStyle)
    if frame._updateCombatIndicatorLayout then
        frame._updateCombatIndicatorLayout(playerDB)
    end
    if frame._updateCombatIndicatorVisuals then
        frame._updateCombatIndicatorVisuals(playerDB)
    end

    if frame.CombatIndicator then
        if combatStyle == "none" or ns.IsStockStyle() then
            if frame:IsElementEnabled("CombatIndicator") then
                frame:DisableElement("CombatIndicator")
            end
            frame.CombatIndicator:Hide()
        else
            if not frame:IsElementEnabled("CombatIndicator") then
                frame:EnableElement("CombatIndicator")
            end
            if frame.CombatIndicator.ForceUpdate then
                frame.CombatIndicator:ForceUpdate()
            end
        end
    end

    if frame._updateRestingIndicatorLayout then
        frame._updateRestingIndicatorLayout(playerDB)
    end

    if frame.RestingIndicator then
        if not frame:IsElementEnabled("RestingIndicator") then
            frame:EnableElement("RestingIndicator")
        end
        if frame.RestingIndicator.ForceUpdate then
            frame.RestingIndicator:ForceUpdate()
        end
    end

    UpdateBlizzardRestTargets(IsResting())
    
    -- Recalculate target frame position based on portrait configuration
    if frames.target then
        ApplyFramePosition(frames.target, "target")
    end
end

local function RefreshAllForeverMetadata()
    for key, frame in pairs(frames) do
        if type(key) == "string" and (type(frame) == "table" or type(frame) == "userdata") and frame._refreshForeverMetadataSoon then
            frame._refreshForeverMetadataSoon()
        end
    end
end

function Mod:RefreshClassificationMetadata()
    RefreshAllForeverMetadata()
end

-- Health-color controls must never enter the full profile-refresh path:
-- Mod:Refresh() deliberately reapplies every frame position and scale, which
-- made Player/Target jump until the next reload when only CLASS/HEALTH changed.
function Mod:RefreshHealthColors()
    self:BindDatabase()
    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    for _, unit in ipairs({ "player", "target" }) do
        local frame = frames[unit]
        if frame and frame.Health then
            ApplyHealthBarAlpha(frame.Health, unit)
            ApplyDarkTheme(frame.Health)
            if frame.Health.ForceUpdate then
                frame.Health:ForceUpdate()
            end
            -- Classic's texture lives on a separate art host above the bars.
            -- Re-seat that already-created art after oUF repaints Health so a
            -- CLASS/HEALTH click cannot leave its layers or internal regions
            -- in the generic KUI state. This does not apply saved positions,
            -- scales or any of Mod:Refresh()'s profile-layout path.
            if renderedTheme == "classic" then
                ApplyClassicFrameArt(frame, unit)
            end
        end
    end
end

function Mod:UpdateRestingIndicator()
    RefreshPlayerStatusIndicators()
end

function InitializeFrames()
    if oUF and oUF.colors and oUF.colors.power then
        local manaColor = { r = MANA_COLOR.r, g = MANA_COLOR.g, b = MANA_COLOR.b }
        manaColor.GetRGB = function(self) return self.r, self.g, self.b end
        oUF.colors.power[0] = manaColor
    end

    if oUF.Tags and oUF.Tags.SetEventUpdateTimer then
        oUF.Tags:SetEventUpdateTimer(0.25)
    end

    local classPowerStyle = db.profile.player.classPowerStyle or "none"
    local savedClassPowerBar = nil
    if classPowerStyle == "blizzard" then
        if PlayerFrame and PlayerFrame.classPowerBar then
            savedClassPowerBar = PlayerFrame.classPowerBar
            PlayerFrame.classPowerBar = nil
            savedClassPowerBar:SetParent(UIParent)
        end
    end

    local enabled = db.profile.enabledFrames

    RegisterStylesOnce()

    local function SetupUnitMenu(frame, unit)
        frame:RegisterForClicks("AnyUp")
        frame:SetAttribute("*type1", "target")  -- Left-click targets the unit
        frame:SetAttribute("*type2", "togglemenu")  -- Right-click opens context menu
        
        -- Use PreClick to intercept Shift+Left-click BEFORE secure handler
        frame:HookScript("PreClick", function(self, button, down)
            if button == "LeftButton" and IsShiftKeyDown() and not InCombatLockdown() then
                if KT and KT.OpenMainMenu then
                    KT:OpenMainMenu()
                    C_Timer.After(0.1, function()
                        if KT.MenuPrincipal and KT.MenuPrincipal.NavigateToPage then
                            KT.MenuPrincipal:NavigateToPage("unitframes")
                        end
                    end)
                end
            end
        end)
        
        frame:HookScript("OnEnter", UnitFrame_OnEnter)
        frame:HookScript("OnLeave", UnitFrame_OnLeave)
    end

    -- Apply frame scale from per-unit settings
    local function ApplyFrameScale(frame, unit)
        if not frame then return end
        local settings = GetSettingsForUnit(unit)
        local scale = (settings and settings.frameScale) or 100
        ApplyFrameScaleCentered(frame, unit, scale / 100, false)
    end

    -- Always spawn all frames; hide disabled ones for zero performance impact
    oUF:SetActiveStyle("KUIPlayer")
    frames.player = oUF:Spawn("player", "KullThranUI_UF_Player")
    ApplyFramePosition(frames.player, "player")
    ApplyFrameScale(frames.player, "player")
    SetupUnitMenu(frames.player, "player")

    if enabled.player == false then
        frames.player:Hide()
        frames.player:SetAttribute("unit", nil)
    end

    RefreshPlayerStatusIndicators()

    -- The standalone CastBar module owns suppression of Blizzard's player cast bars.
    -- oUF also checks that module state before replacing the default bar.

    -- â”€â”€â”€ ClassPower resize: mediciÃ³n separada de aplicaciÃ³n â”€â”€â”€â”€â”€â”€â”€â”€â”€
    -- Paso 1 (MeasureClassPowerLayout): calcula dimensiones sin mutar frames
    -- Paso 2 (CommitClassPowerLayout): aplica el layout calculado al frame

    -- Paso 1: devuelve tabla con todas las dimensiones necesarias
    local function MeasureClassPowerLayout(cpAboveH)
        local settings = GetSettingsForUnit("player")
        local ppPos = settings.powerPosition or "below"
        local ppIsAtt = (ppPos == "below" or ppPos == "above")
        local ppExtra = ppIsAtt and settings.powerHeight or 0
        local baseH = settings.healthHeight + ppExtra
        local btbPos2 = settings.btbPosition or "bottom"
        local btbIsAtt = (btbPos2 == "top" or btbPos2 == "bottom")
        local btbExtra = (settings.bottomTextBar and btbIsAtt)
            and (settings.bottomTextBarHeight or 16) or 0

        local showPortrait = (db.profile.portraitStyle or "attached") ~= "none"
            and settings.showPortrait ~= false
        local isAttached = (db.profile.portraitStyle or "attached") == "attached"
        local pSizeAdj = settings.portraitSize or 0
        if not isAttached then pSizeAdj = pSizeAdj + 10 end
        local adjPH = baseH + cpAboveH + pSizeAdj
        if adjPH < 8 then adjPH = 8 end

        local pSide = settings.portraitSide or "left"
        local effSide = pSide
        if isAttached and pSide == "top" then effSide = "left" end

        local totalW, pW = settings.frameWidth, 0
        if showPortrait and isAttached then
            pW = adjPH
            totalW = pW + settings.frameWidth
        end

        return {
            totalW = totalW,   totalH = baseH + cpAboveH + btbExtra,
            pW     = pW,       adjPH  = adjPH,
            show   = showPortrait, att = isAttached, side = effSide,
        }
    end

    -- Paso 2: aplica las dimensiones al player frame
    local function CommitClassPowerLayout(lay)
        local f = frames.player
        if not f then return end
        PP.Size(f, lay.totalW, lay.totalH)

        -- Actualizar offsets del health bar segÃºn posiciÃ³n del retrato
        if f.Health then
            f.Health._xOffset    = (lay.show and lay.att and lay.side == "left")  and lay.pW or 0
            f.Health._rightInset = (lay.show and lay.att and lay.side == "right") and lay.pW or 0
        end

        -- Reposicionar retrato si es visible y attached
        local port = f.Portrait
        if port and port.backdrop and lay.show then
            PP.Size(port.backdrop, lay.adjPH, lay.adjPH)
            port.backdrop:ClearAllPoints()
            if lay.att then
                local anchor = lay.side == "left" and "TOPLEFT" or "TOPRIGHT"
                PP.Point(port.backdrop, anchor, f, anchor, 0, 0)
            end
            if port.backdrop._2d then UnsnapTex(port.backdrop._2d) end
            if f:IsElementEnabled("Portrait") and port.ForceUpdate then
                port:ForceUpdate()
            end
        end
    end

    if KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme() == "classic" and frames.player then
        ApplyClassicFrameArt(frames.player, "player")
    end

    -- Wrapper que mantiene la firma original para los 5 call sites
    local function ResizeFrameForClassPower(cpAboveH)
        if not frames.player then return end
        CommitClassPowerLayout(MeasureClassPowerLayout(cpAboveH))
    end

    local function PositionClassPowerBar(bar)
        if not bar or not frames.player then return end
        bar:ClearAllPoints()
        local style = db.profile.player.classPowerStyle or "none"
        local position = db.profile.player.classPowerPosition or "top"
        local offsetX = db.profile.player.classPowerBarX or 0
        local offsetY = db.profile.player.classPowerBarY or 0

        -- Stop castbar watcher by default; only re-enabled in the "bottom" branch
        if bar._castbarWatcher then
            bar._castbarWatcher:SetScript("OnUpdate", nil)
            bar._castbarWatcher:Hide()
        end

        if bar._ktClassicCombo then
            -- CLASSIC owns this ornament's geometry.  It sits immediately
            -- below the native power bar, inside the lower part of the
            -- 232x100 stock-art box shown in the reference.  Do not call
            -- ResizeFrameForClassPower here: that generic path would undo
            -- ApplyClassicFrameArt's native frame/portrait/bar placement.
            bar:SetParent(frames.player)
            local anchorFrame = frames.player.Power or frames.player
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", offsetX, 1 + offsetY)
            bar:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", offsetX, 1 + offsetY)
            bar:SetHeight(20)
            if bar._ktClassicLayout then bar._ktClassicLayout() end
            if bar._bottomBdrFrame then bar._bottomBdrFrame:Hide() end
        elseif style == "modern" and position == "above" then
            -- Above health bar, inside the frame ? pips stretch to fill health bar width
            -- Bottom of pips flush with top of health bar, top of pips flush with top of border
            bar:SetParent(frames.player)
            local anchorFrame = frames.player.Health
            local pipH = bar._pipH or 3
            -- Resize frame/portrait BEFORE anchoring health bar so _xOffset is correct
            ResizeFrameForClassPower(pipH)
            local btbOff = 0
            local btbPos2 = db.profile.player.btbPosition or "bottom"
            if btbPos2 == "top" and db.profile.player.bottomTextBar then
                btbOff = db.profile.player.bottomTextBarHeight or 16
            end
            local cpPush = pipH + btbOff
            anchorFrame:ClearAllPoints()
            PP.Point(anchorFrame, "TOPLEFT", frames.player, "TOPLEFT", anchorFrame._xOffset or 0, -cpPush)
            PP.Point(anchorFrame, "RIGHT", frames.player, "RIGHT", -(anchorFrame._rightInset or 0), 0)
            PP.Point(bar, "BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 0)
            PP.Point(bar, "BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 0)
            local fw = db.profile.player.frameWidth or 181
            if bar._repositionForWidth then
                bar._repositionForWidth(fw)
            end
            -- Show 1px bottom border matching frame border color
            if bar._bottomBdrFrame then
                local bdrC = db.profile.player.borderColor or { r = 0, g = 0, b = 0 }
                bar._bottomBdr:SetColorTexture(bdrC.r, bdrC.g, bdrC.b, 1)
                bar._bottomBdrFrame:Show()
            end
        elseif style == "modern" and position == "top" then
            -- "top" floats above the frame (like "bottom" floats below) ? does NOT become part of the frame
            bar:SetParent(frames.player)
            ResizeFrameForClassPower(0)
            -- Reset health bar to normal position
            if frames.player.Health then
                local btbOff = 0
                local btbPos2 = db.profile.player.btbPosition or "bottom"
                if btbPos2 == "top" and db.profile.player.bottomTextBar then
                    btbOff = db.profile.player.bottomTextBarHeight or 16
                end
                frames.player.Health:ClearAllPoints()
                PP.Point(frames.player.Health, "TOPLEFT", frames.player, "TOPLEFT", frames.player.Health._xOffset or 0, -btbOff)
                PP.Point(frames.player.Health, "RIGHT", frames.player, "RIGHT", -(frames.player.Health._rightInset or 0), 0)
            end
            -- Center on health bar (ignores portrait)
            PP.Point(bar, "BOTTOM", frames.player.Health, "TOP", offsetX, offsetY)
            if bar._bottomBdrFrame then bar._bottomBdrFrame:Hide() end
        elseif not db.profile.player.lockClassPowerToFrame then
            -- Reset health bar to normal position
            if frames.player.Health then
                local btbOff = 0
                local btbPos2 = db.profile.player.btbPosition or "bottom"
                if btbPos2 == "top" and db.profile.player.bottomTextBar then
                    btbOff = db.profile.player.bottomTextBarHeight or 16
                end
                frames.player.Health:ClearAllPoints()
                PP.Point(frames.player.Health, "TOPLEFT", frames.player, "TOPLEFT", frames.player.Health._xOffset or 0, -btbOff)
                PP.Point(frames.player.Health, "RIGHT", frames.player, "RIGHT", -(frames.player.Health._rightInset or 0), 0)
            end
            bar:SetParent(UIParent)
            local pos = db.profile.positions.classPower
            if pos then
                PP.Point(bar, pos.point, UIParent, pos.point, pos.x, pos.y)
            else
                PP.Point(bar, "CENTER", UIParent, "CENTER", 0, -220)
            end
            ResizeFrameForClassPower(0)
            if bar._bottomBdrFrame then bar._bottomBdrFrame:Hide() end
        else
            -- Reset health bar to normal position
            if frames.player.Health then
                local btbOff = 0
                local btbPos2 = db.profile.player.btbPosition or "bottom"
                if btbPos2 == "top" and db.profile.player.bottomTextBar then
                    btbOff = db.profile.player.bottomTextBarHeight or 16
                end
                frames.player.Health:ClearAllPoints()
                PP.Point(frames.player.Health, "TOPLEFT", frames.player, "TOPLEFT", frames.player.Health._xOffset or 0, -btbOff)
                PP.Point(frames.player.Health, "RIGHT", frames.player, "RIGHT", -(frames.player.Health._rightInset or 0), 0)
            end
            -- "bottom" position ? flush with bottom of frame; shifts below castbar when visible (unless user set Y offset)
            bar:SetParent(frames.player)
            if bar._bottomBdrFrame then bar._bottomBdrFrame:Hide() end
            local function AnchorBottom()
                bar:ClearAllPoints()
                local baseY = -1 + offsetY
                if offsetY == 0 then
                    local castbarBg = frames.player.Castbar and frames.player.Castbar:GetParent()
                    local castVisible = castbarBg and castbarBg:IsShown() and db.profile.player.showPlayerCastbar
                    if castVisible then
                        baseY = -1 - castbarBg:GetHeight()
                    end
                end
                PP.Point(bar, "TOP", frames.player, "BOTTOM", offsetX, baseY)
            end
            AnchorBottom()
            -- Only run the castbar watcher if the player castbar is enabled
            if db.profile.player.showPlayerCastbar then
                if not bar._castbarWatcher then
                    bar._castbarWatcher = CreateFrame("Frame", nil, bar)
                end
                -- To save CPU, we use HookScript on the Castbar instead of OnUpdate
                local castbarBg = frames.player.Castbar and frames.player.Castbar:GetParent()
                if castbarBg and not castbarBg._kuiPowerAnchored then
                    castbarBg._kuiPowerAnchored = true
                    castbarBg:HookScript("OnShow", function()
                        if db.profile.player.showPlayerCastbar then
                            bar._lastCastVis = true
                            AnchorBottom()
                        end
                    end)
                    castbarBg:HookScript("OnHide", function()
                        if db.profile.player.showPlayerCastbar then
                            bar._lastCastVis = false
                            AnchorBottom()
                        end
                    end)
                end
                -- Initial state
                if castbarBg then
                    bar._lastCastVis = castbarBg:IsShown() and db.profile.player.showPlayerCastbar
                    AnchorBottom()
                end
            end
            ResizeFrameForClassPower(0)
        end
        bar:SetFrameStrata(frames.player:GetFrameStrata())
        bar:SetFrameLevel(frames.player:GetFrameLevel() + 5)
        bar:Show()
    end

    if classPowerStyle ~= "none" and frames.player then
        if classPowerStyle == "blizzard" then
            if savedClassPowerBar then
                PositionClassPowerBar(savedClassPowerBar)
                frames._classPowerBar = savedClassPowerBar
            end
        else
            -- Modern custom style
            DestroyCustomClassPower()
            local custom = CreateCustomClassPower(frames.player, classPowerStyle)
            if custom then
                frames._customClassPower = custom
                frames._classPowerBar = custom
                PositionClassPowerBar(custom)
            end
        end
    end

    -- Live toggle for class power bar (no reload needed)
    -- Called with the style string: "none", "modern", or "blizzard"
    frames._toggleClassPower = function(style)
        style = style or db.profile.player.classPowerStyle or "none"
        -- Also keep showClassPowerBar in sync for backward compat
        db.profile.player.showClassPowerBar = (style ~= "none")
        db.profile.player.classPowerStyle = style

        -- Clean up existing
        if frames._customClassPower then
            DestroyCustomClassPower()
            frames._classPowerBar = nil
        elseif frames._classPowerBar then
            frames._classPowerBar:Hide()
            frames._classPowerBar:ClearAllPoints()
            frames._classPowerBar:SetParent(PlayerFrame or UIParent)
            if PlayerFrame then
                PlayerFrame.classPowerBar = frames._classPowerBar
            end
            frames._classPowerBar = nil
        end

        if style == "none" then
            -- Reset health bar to normal position
            if frames.player and frames.player.Health then
                local btbOff = 0
                local btbPos2 = db.profile.player.btbPosition or "bottom"
                if btbPos2 == "top" and db.profile.player.bottomTextBar then
                    btbOff = db.profile.player.bottomTextBarHeight or 16
                end
                frames.player.Health:ClearAllPoints()
                PP.Point(frames.player.Health, "TOPLEFT", frames.player, "TOPLEFT", frames.player.Health._xOffset or 0, -btbOff)
                PP.Point(frames.player.Health, "RIGHT", frames.player, "RIGHT", -(frames.player.Health._rightInset or 0), 0)
            end
            ResizeFrameForClassPower(0)
            return
        end

        if style == "blizzard" then
            if PlayerFrame and PlayerFrame.classPowerBar then
                local cpb = PlayerFrame.classPowerBar
                PlayerFrame.classPowerBar = nil
                cpb:SetParent(UIParent)
                frames._classPowerBar = cpb
            end
            if frames._classPowerBar and frames.player then
                PositionClassPowerBar(frames._classPowerBar)
            end
        else
            -- Modern
            local custom = CreateCustomClassPower(frames.player, style)
            if custom then
                frames._customClassPower = custom
                frames._classPowerBar = custom
                PositionClassPowerBar(custom)
            end
        end
    end

    oUF:SetActiveStyle("KUITarget")
    frames.target = oUF:Spawn("target", "KullThranUI_UF_Target")
    ApplyFramePosition(frames.target, "target")
    ApplyFrameScale(frames.target, "target")
    SetupUnitMenu(frames.target, "target")
    if enabled.target == false then
        frames.target:Hide()
        frames.target:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUIFocus")
    frames.focus = oUF:Spawn("focus", "KullThranUI_UF_Focus")
    ApplyFramePosition(frames.focus, "focus")
    ApplyFrameScale(frames.focus, "focus")
    SetupUnitMenu(frames.focus, "focus")
    if enabled.focus == false then
        frames.focus:Hide()
        frames.focus:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUIPet")
    frames.pet = oUF:Spawn("pet", "KullThranUI_UF_Pet")
    ApplyFramePosition(frames.pet, "pet")
    SetupUnitMenu(frames.pet, "pet")
    if enabled.pet == false then
        frames.pet:Hide()
        frames.pet:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUITargetTarget")
    frames.targettarget = oUF:Spawn("targettarget", "KullThranUI_UF_TargetTarget")
    ApplyFramePosition(frames.targettarget, "targettarget")
    SetupUnitMenu(frames.targettarget, "targettarget")
    if enabled.targettarget == false then
        frames.targettarget:Hide()
        frames.targettarget:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUIFocusTarget")
    frames.focustarget = oUF:Spawn("focustarget", "KullThranUI_UF_FocusTarget")
    ApplyFramePosition(frames.focustarget, "focustarget")
    SetupUnitMenu(frames.focustarget, "focustarget")
    if enabled.focustarget == false then
        frames.focustarget:Hide()
        frames.focustarget:SetAttribute("unit", nil)
    end

    oUF:SetActiveStyle("KUIBoss")
    local bossPos = db.profile.positions.boss
    local spacing = db.profile.bossSpacing or 60
    for i = 1, 5 do
        local bossUnit = "boss" .. i
        local bossFrame = oUF:Spawn(bossUnit, "KullThranUI_UF_Boss" .. i)
        frames[bossUnit] = bossFrame

        if bossPos then
            bossFrame:ClearAllPoints()
            bossFrame:SetPoint(bossPos.point, UIParent, bossPos.point, bossPos.x, bossPos.y - ((i - 1) * spacing))
        end

        SetupUnitMenu(bossFrame, bossUnit)

        if enabled.boss == false then
            bossFrame:Hide()
            bossFrame:SetAttribute("unit", nil)
        end
    end

    for i = 1, 5 do
        local blizzBoss = _G["Boss" .. i .. "TargetFrame"]
        if blizzBoss then
            blizzBoss:UnregisterAllEvents()
            blizzBoss:Hide()
        end
    end

    -- Disable oUF elements for frames where features are initially off.
    -- Portrait backdrop is already hidden by style functions, but oUF
    -- auto-enables the element at spawn time since frame.Portrait is always set.
    for unit, frame in pairs(frames) do
        if type(frame) ~= "table" or not frame.Portrait then -- skip non-frame entries
        elseif frame.Portrait.backdrop then
            local settings = GetSettingsForUnit(unit)
            if settings.showPortrait == false or (db.profile.portraitStyle or "attached") == "none" then
                if frame:IsElementEnabled("Portrait") then
                    frame:DisableElement("Portrait")
                end
            elseif ResolveActivePortraitMode(unit, settings) == "class" then
                -- Class theme uses a static texture and does not need the oUF Portrait element.
                if frame:IsElementEnabled("Portrait") then
                    frame:DisableElement("Portrait")
                end
            end
        end
    end

    -- Player absorbs: disable oUF element if not wanted (bar is always created)
    if frames.player and frames.player.HealthPrediction then
        if not db.profile.player.showPlayerAbsorb then
            if frames.player:IsElementEnabled("HealthPrediction") then
                frames.player:DisableElement("HealthPrediction")
            end
            if frames.player.HealthPrediction.damageAbsorb then
                frames.player.HealthPrediction.damageAbsorb:Hide()
            end
        end
    end

    -- Player buffs: disable oUF element if not wanted (frame is always created)
    if frames.player and frames.player.Buffs then
        if not db.profile.player.showBuffs then
            if frames.player:IsElementEnabled("Buffs") then
                frames.player:DisableElement("Buffs")
            end
            frames.player.Buffs:Hide()
        end
    end

    -- Player castbar: disable oUF element if not wanted (always created now)
    if frames.player and frames.player.Castbar then
        if not db.profile.player.showPlayerCastbar then
            if frames.player:IsElementEnabled("Castbar") then
                frames.player:DisableElement("Castbar")
            end
            frames.player.Castbar:Hide()
            local castbarBg = frames.player.Castbar:GetParent()
            if castbarBg then castbarBg:Hide() end
        elseif db.profile.player.showPlayerCastIcon == false and frames.player.Castbar._iconFrame then
            frames.player.Castbar._iconFrame:Hide()
        end
    end

    -- Target castbar: disable oUF element if not wanted
    if frames.target and frames.target.Castbar then
        if db.profile.target.showCastbar == false then
            if frames.target:IsElementEnabled("Castbar") then
                frames.target:DisableElement("Castbar")
            end
            frames.target.Castbar:Hide()
            local castbarBg = frames.target.Castbar:GetParent()
            if castbarBg then castbarBg:Hide() end
        elseif db.profile.target.showCastIcon == false and frames.target.Castbar._iconFrame then
            frames.target.Castbar._iconFrame:Hide()
        end
    end

    -- Focus castbar: disable oUF element if not wanted
    if frames.focus and frames.focus.Castbar then
        if db.profile.focus.showCastbar == false then
            if frames.focus:IsElementEnabled("Castbar") then
                frames.focus:DisableElement("Castbar")
            end
            frames.focus.Castbar:Hide()
            local castbarBg = frames.focus.Castbar:GetParent()
            if castbarBg then castbarBg:Hide() end
        elseif db.profile.focus.showCastIcon == false and frames.focus.Castbar._iconFrame then
            frames.focus.Castbar._iconFrame:Hide()
        end
    end

    ---------------------------------------------------------------------------
    --  Group visibility: show/hide player/target/focus based on group state
    ---------------------------------------------------------------------------
    local function UpdateFrameVisibility()
        if InCombatLockdown() then return end
        local enabled2 = db.profile.enabledFrames
        local inRaid = IsInRaid()
        local inParty = not inRaid and IsInGroup()
        local solo = not inRaid and not inParty
        for _, unitKey in ipairs({"player", "target", "focus"}) do
            local s = db.profile[unitKey]
            local frame = frames[unitKey]
            if frame and enabled2[unitKey] ~= false and s then
                local shouldShow = (inRaid and (s.showInRaid ~= false))
                    or (inParty and (s.showInParty ~= false))
                    or (solo and (s.showSolo ~= false))
                if shouldShow then
                    if not frame:IsShown() and UnitExists(unitKey) then
                        frame:SetAttribute("unit", unitKey)
                        -- Re-enable oUF elements that were disabled on hide.
                        -- Castbar is handled separately below to respect the
                        -- user's show/hide setting ? never blindly re-enable it.
                        for _, elem in ipairs({"Health", "Power", "Portrait", "Buffs", "Debuffs", "HealthPrediction"}) do
                            if frame[elem] and not frame:IsElementEnabled(elem) then
                                frame:EnableElement(elem)
                            end
                        end
                        -- Restore castbar state based on saved setting
                        if frame.Castbar then
                            local wantsCastbar
                            if unitKey == "player" then
                                wantsCastbar = s.showPlayerCastbar
                            else
                                wantsCastbar = s.showCastbar ~= false
                            end
                            if wantsCastbar then
                                if not frame:IsElementEnabled("Castbar") then
                                    frame:EnableElement("Castbar")
                                end
                            else
                                if frame:IsElementEnabled("Castbar") then
                                    frame:DisableElement("Castbar")
                                end
                                frame.Castbar:Hide()
                                local castbarBg = frame.Castbar:GetParent()
                                if castbarBg then castbarBg:Hide() end
                            end
                        end
                        frame:Show()
                        frame:UpdateAllElements("GroupVisibility")
                        if unitKey == "player" then
                            RefreshPlayerStatusIndicators()
                        end
                    end
                else
                    if frame:IsShown() then
                        -- Disable oUF elements before hiding to prevent a
                        -- single-frame flash when the unit attribute is cleared
                        for _, elem in ipairs({"Health", "Power", "Portrait", "Castbar", "Buffs", "Debuffs", "HealthPrediction", "CombatIndicator", "RestingIndicator", "LeaderIndicator", "AssistantIndicator", "ResurrectIndicator", "SummonIndicator", "RaidTargetIndicator"}) do
                            if frame[elem] and frame:IsElementEnabled(elem) then
                                frame:DisableElement(elem)
                            end
                        end
                        frame:Hide()
                        frame:SetAttribute("unit", nil)
                    end
                end
            end
        end
    end
    ns.UpdateFrameVisibility = UpdateFrameVisibility

    if not frames._visFrame then
        frames._visFrame = CreateFrame("Frame")
        frames._visFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        frames._visFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
    frames._visFrame:SetScript("OnEvent", UpdateFrameVisibility)
    UpdateFrameVisibility()

    ---------------------------------------------------------------------------
    --  Portrait border color: update when target/focus unit changes
    --  so "class color" mode reflects the new unit's color.
    ---------------------------------------------------------------------------
    if not frames._portraitBorderUpdater then
        frames._portraitBorderUpdater = CreateFrame("Frame")
        frames._portraitBorderUpdater:RegisterEvent("PLAYER_TARGET_CHANGED")
        frames._portraitBorderUpdater:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        frames._portraitBorderUpdater:RegisterEvent("PLAYER_FOCUS_CHANGED")
        frames._portraitBorderUpdater:RegisterEvent("UNIT_TARGET")
        frames._portraitBorderUpdater:RegisterEvent("UNIT_PET")
    end
    frames._portraitBorderUpdater:SetScript("OnEvent", function(_, event, unit)
        local unitKeys
        if event == "UPDATE_SHAPESHIFT_FORM" then
            unitKeys = { "player" }
        elseif event == "PLAYER_TARGET_CHANGED" then
            unitKeys = { "target", "targettarget" }
        elseif event == "PLAYER_FOCUS_CHANGED" then
            unitKeys = { "focus", "focustarget" }
        elseif event == "UNIT_PET" and unit == "player" then
            unitKeys = { "pet" }
        elseif event == "UNIT_TARGET" and unit == "target" then
            unitKeys = { "targettarget" }
        elseif event == "UNIT_TARGET" and unit == "focus" then
            unitKeys = { "focustarget" }
        else
            return
        end

        for _, unitKey in ipairs(unitKeys) do
            local frame = frames[unitKey]
            if frame and frame.Portrait then
                local backdrop = frame.Portrait.backdrop
                if backdrop then
                    local settingsKey = UnitToSettingsKey(unitKey) or unitKey
                    local uSettings = settingsKey and db.profile[settingsKey]
                    if db.profile.portraitStyle == "circular"
                        or (uSettings and uSettings.detachedPortraitClassColor)
                    then
                        ApplyDetachedPortraitShape(backdrop, uSettings, unitKey)
                    end
                    SwapPortraitMode(frame)
                    ns.RefreshClassPortrait(unitKey, backdrop)
                    if frame:IsElementEnabled("Portrait") and frame.Portrait and frame.Portrait.ForceUpdate then
                        frame.Portrait:ForceUpdate()
                    end
                end
            end
        end
    end)

    -- Deferred normalization: some late-login updates can re-anchor power bars
    -- after frame construction. Re-apply two-point attached anchors once more.
    C_Timer.After(0, function()
        for _, unitKey in ipairs({"player", "target", "focus"}) do
            local frame = frames[unitKey]
            if frame and frame.Power and frame.Health then
                local s = GetSettingsForUnit(unitKey)
                if s then
                    local ppPos = s.powerPosition or "below"
                    if ppPos == "below" or ppPos == "above" then
                        frame.Power:ClearAllPoints()
                        if ppPos == "above" then
                            PP.Point(frame.Power, "BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
                            PP.Point(frame.Power, "BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
                        else
                            PP.Point(frame.Power, "TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
                            PP.Point(frame.Power, "TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
                        end
                    end
                end
            end
        end
        for i = 1, 5 do
            local bf = frames["boss" .. i]
            if bf and bf.Power and bf.Health then
                local s = GetSettingsForUnit("boss")
                if s then
                    local ppPos = s.powerPosition or "below"
                    if ppPos == "below" or ppPos == "above" then
                        bf.Power:ClearAllPoints()
                        if ppPos == "above" then
                            PP.Point(bf.Power, "BOTTOMLEFT", bf.Health, "TOPLEFT", 0, 0)
                            PP.Point(bf.Power, "BOTTOMRIGHT", bf.Health, "TOPRIGHT", 0, 0)
                        else
                            PP.Point(bf.Power, "TOPLEFT", bf.Health, "BOTTOMLEFT", 0, 0)
                            PP.Point(bf.Power, "TOPRIGHT", bf.Health, "BOTTOMRIGHT", 0, 0)
                        end
                    end
                end
            end
        end
    end)

    -- Keep every UnitFrame child, including indicator and text overlays, below
    -- Blizzard's MEDIUM/DIALOG windows while preserving their internal levels.
    RefreshUnitFrameStrata()

    if InCombatLockdown() then
        ns._suppressAutoPlayerFrameAnchor = true
        ns._playerFrameAnchorPending = false
    else
        ns._suppressAutoPlayerFrameAnchor = nil
    end

    if ns.AnchorPlayerFrameToCDM and not ns._suppressAutoPlayerFrameAnchor then
        if ns.RequestAnchorPlayerFrameToCDM then
            C_Timer.After(0, function() ns.RequestAnchorPlayerFrameToCDM() end)
            C_Timer.After(0.5, function() ns.RequestAnchorPlayerFrameToCDM() end)
            C_Timer.After(1.5, function() ns.RequestAnchorPlayerFrameToCDM() end)
        else
            C_Timer.After(0, function() ns.AnchorPlayerFrameToCDM() end)
            C_Timer.After(0.5, function() ns.AnchorPlayerFrameToCDM() end)
            C_Timer.After(1.5, function() ns.AnchorPlayerFrameToCDM() end)
        end
    end
end

local function RegisterUnitFramesWithEditMode()
    if not (KT and KT.RegisterUnlockElement and db and db.profile) then return end
    local unlockOrders = {
        player = 10,
        target = 20,
        focus = 30,
        pet = 40,
        targettarget = 50,
        focustarget = 60,
        boss = 70,
        playerCastbar = 80,
        classPower = 90,
    }

    local function SavePoint(frame, key)
        local point, _, relPoint, x, y = frame:GetPoint()
        db.profile.positions[key] = {
            point = point or relPoint or "CENTER",
            x = x or 0,
            y = y or 0,
            scale = frame.GetScale and frame:GetScale() or 1,
        }
    end

    local function Register(frame, label, key, onStop)
        if not frame then return end
        local unlockKey = "unitframes_" .. key

        KT.RegisterUnlockElement(unlockKey, {
            label = (label:gsub("^Unit Frames:%s*", "")),
            group = "Unit Frames",
            order = unlockOrders[key] or 999,
            getFrame = function()
                return frame
            end,
            getSize = function()
                return frame:GetWidth(), frame:GetHeight()
            end,
            getScale = function()
                return frame:GetScale()
            end,
            setScale = function(_, scale)
                if scale and ApplyFrameScale then
                    ApplyFrameScale(frame, key, scale, false)
                end
            end,
            loadPosition = function()
                local saved = KT.db.profile.editMode
                    and KT.db.profile.editMode.frames
                    and KT.db.profile.editMode.frames[unlockKey]
                if saved and saved.point then
                    return saved
                end
                local native = db.profile.positions[key]
                if native and native.point then
                    return {
                        point = native.point,
                        relativePoint = native.point,
                        x = native.x or 0,
                        y = native.y or 0,
                        scale = native.scale or frame:GetScale() or 1,
                    }
                end
                return nil
            end,
            savePosition = function(_, pt, rpt, x, y, scale)
                KT.db.profile.editMode.frames[unlockKey] = {
                    point = pt,
                    relativePoint = rpt,
                    x = x,
                    y = y,
                    scale = scale or frame:GetScale() or 1,
                }
                db.profile.positions[key] = {
                    point = pt or rpt or "CENTER",
                    x = x or 0,
                    y = y or 0,
                    scale = scale or frame:GetScale() or 1,
                }
                SavePoint(frame, key)
                if onStop then onStop() end
            end,
            applyPosition = function()
                local saved = KT.db.profile.editMode
                    and KT.db.profile.editMode.frames
                    and KT.db.profile.editMode.frames[unlockKey]
                if saved and saved.point then
                    db.profile.positions[key] = {
                        point = saved.point,
                        x = saved.x or 0,
                        y = saved.y or 0,
                        scale = saved.scale or frame:GetScale() or 1,
                    }
                end
                local targetPos = db.profile.positions[key]
                if targetPos and targetPos.scale and ApplyFrameScale then
                    ApplyFrameScale(frame, key, targetPos.scale, false)
                end
                ApplyFramePosition(frame, key)
                if onStop then onStop() end
            end,
            resetPosition = function()
                -- "Reset Position" must land on the shipped default, not on the
                -- user's saved offset. Both stores below hold user edits, so drop
                -- the UnlockMode override first, then re-seed the native store
                -- from the module defaults before reapplying.
                local editMode = KT.db and KT.db.profile and KT.db.profile.editMode
                if editMode and type(editMode.frames) == "table" then
                    editMode.frames[unlockKey] = nil
                end

                local defaultPos = defaults.profile.positions
                    and defaults.profile.positions[key]
                db.profile.positions = db.profile.positions or {}
                if type(defaultPos) == "table" then
                    -- Keep the user's scale: only the anchor is being reset.
                    db.profile.positions[key] = {
                        point = defaultPos.point or "CENTER",
                        x = defaultPos.x or 0,
                        y = defaultPos.y or 0,
                        scale = (frame.GetScale and frame:GetScale()) or 1,
                    }
                else
                    db.profile.positions[key] = nil
                end

                if KT.FlushPersistence then KT:FlushPersistence() end

                local targetPos = db.profile.positions[key]
                if targetPos and targetPos.scale and ApplyFrameScale then
                    ApplyFrameScale(frame, key, targetPos.scale, false)
                end
                ApplyFramePosition(frame, key)
                if onStop then onStop() end
                return true
            end,
        })
    end

    Register(frames.player, "Unit Frames: Player", "player")
    Register(frames.target, "Unit Frames: Target", "target")
    Register(frames.focus, "Unit Frames: Focus", "focus")
    Register(frames.pet, "Unit Frames: Pet", "pet")
    Register(frames.targettarget, "Unit Frames: Target of Target", "targettarget")
    Register(frames.focustarget, "Unit Frames: Focus Target", "focustarget")
    Register(frames.boss1, "Unit Frames: Boss", "boss", function()
        local pos = db.profile.positions.boss
        local spacing = db.profile.bossSpacing or 60
        for i = 1, 5 do
            local frame = frames["boss" .. i]
            if frame and pos then
                frame:ClearAllPoints()
                frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y - ((i - 1) * spacing))
            end
        end
    end)

    if frames.player and frames.player.Castbar and not db.profile.player.lockCastbarToFrame then
        Register(frames.player.Castbar:GetParent(), "Unit Frames: Player Castbar", "playerCastbar")
    end
    if frames._classPowerBar and not db.profile.player.lockClassPowerToFrame then
        Register(frames._classPowerBar, "Unit Frames: Class Power", "classPower")
    end
end

local function SetupOptionsPanel()
    ns.db = db
    ns.frames = frames
    if ns.AggroGlow then ns.AggroGlow:Update() end
    ns.ApplyFramePosition = ApplyFramePosition
    ns.ApplyFrameScale = ApplyFrameScale
    ns.SnapScaleToPixel = SnapScaleToPixel
    ns.GetFrameDimensions = GetFrameDimensions
    ns.ResolveFontPath = ResolveFontPath

    if not ns._ufReloadThrottle then
        ns._ufReloadThrottle = CreateFrame("Frame")
        ns._ufReloadThrottle:Hide()
        ns._ufReloadThrottle:SetScript("OnUpdate", function(self)
            self:Hide()
            ns._ufReloadPending = false
            ReloadFrames()
            if ns.ComboUnderFrame then ns.ComboUnderFrame:RefreshAll() end
        end)
    end

    ns.ReloadFrames = function()
        if not ns._ufReloadPending then
            ns._ufReloadPending = true
            ns._ufReloadThrottle:Show()
        end
    end

    Mod.Reload = ns.ReloadFrames
    RegisterUnitFramesWithEditMode()
end

StaticPopupDialogs["KULLTHRANUI_UF_RESET_DEFAULTS"] = {
    text = "Reset all KullThranUI Unit Frames settings to defaults? This cannot be undone.",
    button1 = "Reset & Reload",
    button2 = "Cancel",
    OnAccept = function()
        if KT and KT.db and KT.db.profile then
            KT.db.profile.unitFrames = {}
            Compat.CopyDefaults(KT.db.profile.unitFrames, defaults.profile)
        end
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function MigratePlayerTarget()
    local p = db.profile
    if p._playerTargetMigrated then return end
    local old = p.playerTarget
    if not old then
        p._playerTargetMigrated = true
        return
    end
    local oldDef = defaults.profile.playerTarget

    p.player = p.player or {}
    p.player.frameWidth = old.frameWidth or oldDef.frameWidth
    p.player.healthHeight = old.healthHeight or oldDef.healthHeight
    p.player.powerHeight = old.powerHeight or oldDef.powerHeight
    p.player.healthDisplay = old.healthDisplay or oldDef.healthDisplay
    if old.showPlayerAbsorb == nil then
        p.player.showPlayerAbsorb = true
    else
        p.player.showPlayerAbsorb = old.showPlayerAbsorb
    end
    p.player.showPlayerCastbar = old.showPlayerCastbar or false
    p.player.showClassPowerBar = old.showClassPowerBar or false
    p.player.playerCastbarX = old.playerCastbarX or 0
    p.player.playerCastbarY = old.playerCastbarY or 0
    p.player.playerCastbarWidth = old.playerCastbarWidth or 0
    p.player.playerCastbarHeight = old.playerCastbarHeight or 0
    p.player.classPowerBarX = old.classPowerBarX or 0
    p.player.classPowerBarY = old.classPowerBarY or 0
    p.player.showPortrait = p.showPortrait

    p.target = p.target or {}
    p.target.frameWidth = old.frameWidth or oldDef.frameWidth
    p.target.healthHeight = old.healthHeight or oldDef.healthHeight
    p.target.powerHeight = old.powerHeight or oldDef.powerHeight
    p.target.castbarHeight = old.castbarHeight or oldDef.castbarHeight
    p.target.healthDisplay = old.healthDisplay or oldDef.healthDisplay
    p.target.showBuffs = old.showBuffs
    if p.target.showBuffs == nil then p.target.showBuffs = true end
    p.target.onlyPlayerDebuffs = old.onlyPlayerDebuffs or false
    p.target.showPortrait = p.showPortrait
    p._playerTargetMigrated = true
end

local function ApplyForeverPortraitDefaults()
    local profile = db and db.profile
    if not profile then return end

    -- The previous Forever migration enabled these two portraits as a
    -- default. Undo that one-time automatic change, then preserve future
    -- manual choices made through the options panel.
    if not profile._portraitDefaultsDisabled20260926 then
        if profile._foreverPortraitDefaults20260919c then
            if profile.player then profile.player.showPortrait = false end
            if profile.target then profile.target.showPortrait = false end
        end
        profile._portraitDefaultsDisabled20260926 = true
    end

    if profile._foreverPortraitDefaults20260919c then return end

    if profile.target and profile.target.portraitSide == "left" then profile.target.portraitSide = "right" end
    if profile.circularPortraitBorderUseCustomColor == false then profile.circularPortraitBorderUseCustomColor = true end
    if profile.portraitStyle == nil or profile.portraitStyle == "attached" then profile.portraitStyle = "circular" end
    profile._foreverPortraitDefaults20260919c = true
end
local function ClampImportedNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then return fallback end
    if value < minValue or value > maxValue then
        return fallback
    end
    return value
end

local function NormalizeImportedFont(value)
    if type(value) ~= "string" or value == "" then
        return "AAA_ITC_Avant_Garde"
    end
    if Compat.fontPaths[value] then
        return value
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM:Fetch("font", value, true) then
        return value
    end
    return "AAA_ITC_Avant_Garde"
end

local function NormalizeImportedTexture(value)
    if type(value) ~= "string" or value == "" then
        return "Melli Reforged"
    end
    if healthBarTextures[value] ~= nil or value == "none" then
        return value
    end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM:Fetch("statusbar", value, true) then
        return value
    end
    return "Melli Reforged"
end

local function NormalizeImportedColor(value, fallback)
    if type(value) ~= "table" then
        return CopyTable(fallback)
    end

    return {
        r = ClampImportedNumber(value.r or value[1], 0, 1, fallback.r),
        g = ClampImportedNumber(value.g or value[2], 0, 1, fallback.g),
        b = ClampImportedNumber(value.b or value[3], 0, 1, fallback.b),
        a = ClampImportedNumber(value.a or value[4], 0, 1, fallback.a or 1),
    }
end

local function SanitizeImportedLayout()
    local profile = db.profile
    if not profile then return end

    local defaultPositions = defaults.profile.positions or {}
    profile.positions = profile.positions or {}
    for unit, defaultPos in pairs(defaultPositions) do
        local pos = profile.positions[unit]
        if type(pos) ~= "table" then
            profile.positions[unit] = CopyTable(defaultPos)
        else
            if type(pos.point) ~= "string" then
                pos.point = defaultPos.point
            end
            pos.x = ClampImportedNumber(pos.x, -4000, 4000, defaultPos.x)
            pos.y = ClampImportedNumber(pos.y, -4000, 4000, defaultPos.y)
        end
    end

    local units = { "player", "target", "focus", "boss", "pet", "totPet" }
    for i = 1, #units do
        local unit = units[i]
        local settings = profile[unit]
        local unitDefaults = defaults.profile[unit]
        if settings and unitDefaults then
            settings.frameWidth = ClampImportedNumber(settings.frameWidth, 40, 800, unitDefaults.frameWidth)
            settings.frameScale = ClampImportedNumber(settings.frameScale, 25, 300, unitDefaults.frameScale or 100)
            settings.healthHeight = ClampImportedNumber(settings.healthHeight, 8, 200, unitDefaults.healthHeight)
            settings.powerHeight = ClampImportedNumber(settings.powerHeight, 0, 80, unitDefaults.powerHeight or 0)
            settings.portraitSize = ClampImportedNumber(settings.portraitSize, -40, 300, unitDefaults.portraitSize or 0)
            settings.portraitX = ClampImportedNumber(settings.portraitX, -250, 250, unitDefaults.portraitX or 0)
            settings.portraitY = ClampImportedNumber(settings.portraitY, -250, 250, unitDefaults.portraitY or 0)
            settings.selectedFont = NormalizeImportedFont(settings.selectedFont or unitDefaults.selectedFont)
            settings.healthBarTexture = NormalizeImportedTexture(settings.healthBarTexture or unitDefaults.healthBarTexture)
            settings.healthBarOpacity = ClampImportedNumber(settings.healthBarOpacity, 1, 100, unitDefaults.healthBarOpacity or 90)
            settings.powerBarOpacity = ClampImportedNumber(settings.powerBarOpacity, 1, 100, unitDefaults.powerBarOpacity or 100)
            if unit == "player" then
                settings.absorbBarTexture = NormalizeImportedTexture(settings.absorbBarTexture or unitDefaults.absorbBarTexture or DEFAULT_ABSORB_TEXTURE)
                settings.absorbBarColor = NormalizeImportedColor(settings.absorbBarColor, unitDefaults.absorbBarColor or DEFAULT_ABSORB_COLOR)
            end
        end
    end

    profile.selectedFont = NormalizeImportedFont(profile.selectedFont)
    profile.healthBarTexture = NormalizeImportedTexture(profile.healthBarTexture)
    if profile.portraitStyle ~= "attached"
        and profile.portraitStyle ~= "detached"
        and profile.portraitStyle ~= "circular"
        and profile.portraitStyle ~= "none"
    then
        profile.portraitStyle = defaults.profile.portraitStyle
    end
end

local function ApplyUpdatedDefaultPreset()
    local profile = db.profile
    if not profile or profile._defaultPreset20260323 then return end
    local function sameColor(a, r, g, b)
        return a
            and math.abs((a.r or 0) - r) < 0.001
            and math.abs((a.g or 0) - g) < 0.001
            and math.abs((a.b or 0) - b) < 0.001
    end

    local function bumpTextSizes(settings)
        if not settings then return end
        if settings.leftTextSize == 12 then settings.leftTextSize = 14 end
        if settings.rightTextSize == 12 then settings.rightTextSize = 14 end
        if settings.centerTextSize == 12 then settings.centerTextSize = 14 end
        if settings.textSize == 12 then settings.textSize = 14 end
        if settings.powerPercentSize == 9 then settings.powerPercentSize = 11 end
        if settings.castSpellNameSize == 11 then settings.castSpellNameSize = 13 end
        if settings.castDurationSize == 11 then settings.castDurationSize = 13 end
        if settings.btbLeftSize == 11 then settings.btbLeftSize = 13 end
        if settings.btbRightSize == 11 then settings.btbRightSize = 13 end
        if settings.btbCenterSize == 11 then settings.btbCenterSize = 13 end
    end

    for _, unit in ipairs({ "player", "target", "focus", "boss", "pet", "totPet" }) do
        bumpTextSizes(profile[unit])
    end

    if profile.player and (profile.player.frameWidth == 181 or profile.player.frameWidth == 185 or profile.player.frameWidth == 187) then
        profile.player.frameWidth = 230
    end
    if profile.target and (profile.target.frameWidth == 181 or profile.target.frameWidth == 185 or profile.target.frameWidth == 187) then
        profile.target.frameWidth = 230
    end
    if profile.target and profile.target.castbarHideWhenInactive == false then
        profile.target.castbarHideWhenInactive = true
    end
    if profile.target then
        local targetCb = profile.target.castbarFillColor
        local isLegacyGreen = sameColor(targetCb, 0.114, 0.655, 0.514)
        local isKtRed = sameColor(targetCb, KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333)
        if targetCb == nil or isLegacyGreen or isKtRed then
            profile.target.castbarFillColor = { r = 1, g = 0.82, b = 0 }
            profile.target.castbarClassColored = false
        end
    end

    local positions = profile.positions or {}
    local playerPos = positions.player
    if playerPos and playerPos.point == "CENTER" and playerPos.x == -317 and playerPos.y == -193.5 then
        playerPos.x = -300
        playerPos.y = -145
    elseif playerPos and playerPos.point == "CENTER" and playerPos.x == -292 and playerPos.y == -176 then
        playerPos.x = -300
        playerPos.y = -145
    elseif playerPos and playerPos.point == "CENTER" and playerPos.x == -245 and playerPos.y == -176 then
        playerPos.x = -300
        playerPos.y = -145
    end

    local targetPos = positions.target
    if targetPos and targetPos.point == "CENTER" and targetPos.x == 317 and targetPos.y == -201 then
        targetPos.x = 300
        targetPos.y = -145
    elseif targetPos and targetPos.point == "CENTER" and targetPos.x == 292 and targetPos.y == -176 then
        targetPos.x = 300
        targetPos.y = -145
    elseif targetPos and targetPos.point == "CENTER" and targetPos.x == 245 and targetPos.y == -176 then
        targetPos.x = 300
        targetPos.y = -145
    end

    local focusPos = positions.focus
    if focusPos and focusPos.point == "CENTER" and (
        (focusPos.x == 0 and focusPos.y == -285)
        or (focusPos.x == -300 and focusPos.y == -205)
        or (focusPos.x == -323 and focusPos.y == -347)
        or (focusPos.x == -267.5 and focusPos.y == -347)
        or (focusPos.x == -287.5 and focusPos.y == -347)
        or ((focusPos.x == -320 and (focusPos.y == -175 or focusPos.y == -252 or focusPos.y == -272))
            or (focusPos.x == -323 and (focusPos.y == -272 or focusPos.y == -307 or focusPos.y == -327)))
    ) then
        focusPos.x = -315
        focusPos.y = -347
    end

    local petPos = positions.pet
    if petPos and petPos.point == "CENTER"
        and ((petPos.x == -300 and petPos.y == -260)
            or (petPos.x == -369.5 and (petPos.y == -96.5 or petPos.y == -106.5))
            or (petPos.x == -372.5 and (petPos.y == -116.5 or petPos.y == -131.5 or petPos.y == -141.5))) then
        petPos.x = -372.5
        petPos.y = -146.5
    end

    local focusTargetPos = positions.focustarget
    if focusTargetPos and focusTargetPos.point == "CENTER" and
        ((focusTargetPos.x == 50 and focusTargetPos.y == -261)
            or (focusTargetPos.x == -369.5 and (focusTargetPos.y == -301.5 or focusTargetPos.y == -321.5))
            or (focusTargetPos.x == -372.5 and (focusTargetPos.y == -321.5 or focusTargetPos.y == -356.5 or focusTargetPos.y == -376.5))
            or (focusTargetPos.x == -372.5 and focusTargetPos.y == -396.5)
            or (focusTargetPos.x == -317 and focusTargetPos.y == -396.5)
            or (focusTargetPos.x == -337 and focusTargetPos.y == -396.5)) then
        focusTargetPos.x = -364.5
        focusTargetPos.y = -396.5
    end

    local targetTargetPos = positions.targettarget
    if targetTargetPos and targetTargetPos.point == "CENTER" and targetTargetPos.x == 383 and targetTargetPos.y == -152.5 then
        targetTargetPos.x = 378
    end

    if profile.pet and profile.pet.healthClassColored == nil then
        profile.pet.healthClassColored = true
    end

    -- Existing Forever profiles used "none"; apply mana as the new default once.
    if profile.pet and not profile._petManaDefault20260920 then
        if profile.pet.powerPosition == nil or profile.pet.powerPosition == "none" then
            profile.pet.powerPosition = "below"
        end
        if profile.pet.powerHeight == nil then
            profile.pet.powerHeight = 6
        end
        profile._petManaDefault20260920 = true
    end

    if profile.focus and (profile.focus.portraitSide == nil or profile.focus.portraitSide == "right") then
        profile.focus.portraitSide = "left"
    end

    profile._defaultPreset20260311 = true
    profile._defaultPreset20260312 = true
    profile._defaultPreset20260313 = true
    profile._defaultPreset20260314 = true
    profile._defaultPreset20260315 = true
    profile._defaultPreset20260316 = true
    profile._defaultPreset20260317 = true
    profile._defaultPreset20260318 = true
    profile._defaultPreset20260319 = true
    profile._defaultPreset20260320 = true
    profile._defaultPreset20260321 = true
    profile._defaultPreset20260322 = true
    profile._defaultPreset20260323 = true
end

local function MigrateLegacyCrimsonAccent()
    local profile = db.profile
    if not profile or profile._legacyCrimsonAccentMigrated20260818 then return end

    local function IsLegacyCrimson(color)
        return color
            and math.abs((color.r or 0) - 1) < 0.001
            and math.abs(color.g or 0) < 0.001
            and math.abs((color.b or 0) - 0.333) < 0.001
    end

    if IsLegacyCrimson(profile.castbarColor) then
        profile.castbarColor = nil
    end
    if IsLegacyCrimson(profile.circularPortraitBorderColor) then
        profile.circularPortraitBorderColor = nil
    end

    for _, unit in ipairs({ "player", "focus", "boss", "pet", "totPet" }) do
        local settings = profile[unit]
        if settings and IsLegacyCrimson(settings.castbarFillColor) then
            settings.castbarFillColor = nil
        end
    end

    profile._legacyCrimsonAccentMigrated20260818 = true
end

local function ApplyTargetCastbarYellowDefault()
    local profile = db.profile
    if not profile or profile._targetCastbarYellow20260803 then return end

    local target = profile.target
    local color = target and target.castbarFillColor
    local function sameColor(r, g, b)
        return color
            and math.abs((color.r or 0) - r) < 0.001
            and math.abs((color.g or 0) - g) < 0.001
            and math.abs((color.b or 0) - b) < 0.001
    end

    -- Only migrate the exact class-colored state produced by the old default
    -- migration. Explicit custom colors and non-class-colored choices remain.
    if target and target.castbarClassColored == true
        and (sameColor(0.114, 0.655, 0.514)
            or sameColor(KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333)) then
        target.castbarFillColor = { r = 1, g = 0.82, b = 0 }
        target.castbarClassColored = false
    end

    profile._targetCastbarYellow20260803 = true
end

-- Player/target portraitFacing defaults were swapped (player normal->flipped,
-- target flipped->normal) -- the two still face each other, just mirrored
-- from before. Changing the defaults table alone only affects brand-new
-- profiles; AceDB never overwrites a key an existing profile already has
-- saved. This migrates existing profiles once, only when the saved value
-- still exactly matches the OLD default (an explicit custom choice is left
-- alone).
-- Attached to KT (not a top-level `local function`): this file is already at
-- Lua 5.1's 200-active-local ceiling for its main chunk -- one more
-- `local function` here fails to compile with "Only 200 active local
-- variables and upvalues can be existed at the same time". Matches the
-- same KT:/Mod: method pattern already used elsewhere in this file for
-- exactly this reason.
function KT:SwapPortraitFacingDefaults()
    local profile = db.profile
    if not profile or profile._portraitFacingSwap20260929 then return end

    local player = profile.player
    if player and player.portraitFacing == "normal" then
        player.portraitFacing = "flipped"
    end

    local target = profile.target
    if target and target.portraitFacing == "flipped" then
        target.portraitFacing = "normal"
    end

    profile._portraitFacingSwap20260929 = true
end

-- Classic's VisualThemes seed (Adapters/UnitFrames.lua) used to set
-- portraitStyle = "attached" -- wrong, since Classic's real stock box
-- (ApplyClassicUnitFrameArt) assumes a round-clipped portrait like Forever's.
-- "attached" skips mask creation entirely (ApplyDetachedPortraitShape's fast
-- path), so the portrait rendered unmasked and bled outside the ring.
-- Fixed at the seed; this migrates an existing profile already on Classic
-- theme, only when portraitStyle still exactly matches the OLD wrong
-- default (a deliberate "attached" choice under any OTHER theme, where
-- it's a normal valid setting, is left alone).
function KT:MigrateClassicPortraitCircular()
    local profile = db.profile
    if not profile or profile._classicPortraitCircular20260930 then return end
    profile._classicPortraitCircular20260930 = true

    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    if renderedTheme == "classic" and profile.portraitStyle == "attached" then
        profile.portraitStyle = "circular"
    end
end

-- Retail's VisualThemes seed used to be the bare fixed-accent-color ceiling
-- (portraitStyle = "none", no real stock geometry at all). Retail now
-- reuses the same real per-client stock rendering as Forever
-- (ApplyForeverUnitFrameArt), same as Classic already does. Fixed at the
-- seed; this migrates an existing profile already on Retail theme, only
-- when portraitStyle still exactly matches the OLD default (a deliberate
-- "none" choice under any OTHER theme is left alone).
function KT:MigrateRetailPortraitCircular()
    local profile = db.profile
    if not profile or profile._retailPortraitCircular20260930 then return end
    profile._retailPortraitCircular20260930 = true

    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    if renderedTheme == "retail" and profile.portraitStyle == "none" then
        profile.portraitStyle = "circular"
        for _, key in ipairs({ "player", "target", "focus", "pet", "boss" }) do
            profile[key] = type(profile[key]) == "table" and profile[key] or {}
            if profile[key].showPortrait == false then
                profile[key].showPortrait = true
            end
        end
    end
end

-- Retail's seed only started setting customFillColor/healthClassColored
-- (for the default green health bar) after this fix -- seed() never runs
-- retroactively, so an existing profile already on Retail theme needs this
-- migrated in separately, exactly like the portrait-circular migration
-- above.
-- showPvPCircle is a new seeded field (kui should default it off, unlike
-- Classic/Forever/Retail) -- seed() never runs retroactively, so an
-- existing profile already on kui needs this one-time backfill too.
function KT:MigrateKuiPvPCircleDefault()
    local profile = db.profile
    -- Re-run under a new guard key (20261002, not the original 20261001):
    -- the original version's nil-check was defeated by a blanket AceDB
    -- default that backfilled showPvPCircle to true before this migration
    -- ever ran (see the comment on the removed default above), so any
    -- profile that already ran the 20261001 guard may be carrying that
    -- bogus true and needs a real repair, not just a second nil-check.
    if not profile or profile._kuiPvPCircleDefault20261002 then return end
    profile._kuiPvPCircleDefault20261002 = true

    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    if renderedTheme == "kui" then
        profile.showPvPCircle = false
    end
end

function KT:MigrateRetailHealthGreen()
    local profile = db.profile
    if not profile or profile._retailHealthGreen20261001 then return end
    profile._retailHealthGreen20261001 = true

    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    if renderedTheme ~= "retail" then return end
    for _, key in ipairs({ "player", "target" }) do
        profile[key] = type(profile[key]) == "table" and profile[key] or {}
        if profile[key].customFillColor == nil then
            profile[key].customFillColor = { r = 0.57, g = 1.00, b = 0.235 }
        end
        if profile[key].healthClassColored == nil then
            profile[key].healthClassColored = false
        end
    end
end

-- Forever used to seed darkTheme=true before its CLASS/HEALTH selector was
-- added. Dark mode has higher render priority and forced #111111 over either
-- selection. Repair the currently active legacy profile once; future Forever
-- seeds and restored slots are handled by the VisualThemes adapter.
-- darkTheme is a single field shared by every theme
-- (ResolveLiveHealthColor in ThemePreview.lua returns its dark gray
-- immediately, before ever checking healthClassColored, whenever it's
-- true), so a profile that got stuck on darkTheme=true while Forever was
-- once active stays stuck for Classic/Retail too (CLASS on the theme-card
-- selector then shows no class color), even though only Forever's own
-- legacy default could ever have SET it. The repair covers whichever of
-- the three real-stock themes is currently active, under its own guard
-- key.
function KT:MigrateForeverHealthColorSelector()
    local profile = db.profile
    if not profile or profile._foreverHealthColorSelector20261002 then return end
    profile._foreverHealthColorSelector20261002 = true

    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    local isStockTheme = renderedTheme == "forever" or renderedTheme == "classic"
        or renderedTheme == "retail"
    if isStockTheme and profile.darkTheme == true then
        profile.darkTheme = false
    end
end

-- Classic/Forever's real stock box already anchors the cast bar below Power
-- (CreateCastBar) and now matches its real width (SeatStockCastbar in
-- ThemeClientAssets.lua), but showPlayerCastbar itself defaults to false
-- module-wide and neither theme's seed used to turn it on, so the cast bar
-- never appeared under either theme. Fixed at the seed; this migrates an
-- existing profile already on Classic/Forever theme, only when the value
-- is still exactly the module's own default (a deliberate "off" choice,
-- under any theme, is left alone).
function KT:MigrateThemedCastbarVisible()
    local profile = db.profile
    if not profile or profile._themedCastbarVisible20260930 then return end
    profile._themedCastbarVisible20260930 = true

    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    if (renderedTheme == "classic" or renderedTheme == "forever" or renderedTheme == "retail")
        and profile.player and profile.player.showPlayerCastbar == false then
        profile.player.showPlayerCastbar = true
    end
end

local function ApplyReferenceLayoutDefaults()
    local profile = db.profile
    if not profile or profile._referenceLayout20260801 then return end

    local positions = profile.positions or {}
    local replacements = {
        focus = { oldX = -315, oldY = -347, x = -315, y = -257 },
        pet = { oldX = -372.5, oldY = -146.5, x = -372.5, y = -36.5 },
        target = { oldX = 300, oldY = -145, x = 280, y = -145 },  -- Base position adjusted; ApplyFramePosition adds dynamic offset based on portrait config
        targettarget = { oldX = 378, oldY = -152.5, x = 378, y = -42.5 },
        focustarget = { oldX = -364.5, oldY = -396.5, x = -364.5, y = -306.5 },
    }

    for key, replacement in pairs(replacements) do
        local pos = positions[key]
        if pos and pos.point == "CENTER" and pos.x == replacement.oldX and pos.y == replacement.oldY then
            pos.x = replacement.x
            pos.y = replacement.y
        end

        local unlockKey = "unitframes_" .. key
        local editPos = KT.db.profile.editMode
            and KT.db.profile.editMode.frames
            and KT.db.profile.editMode.frames[unlockKey]
        if editPos and editPos.point == "CENTER"
            and editPos.x == replacement.oldX and editPos.y == replacement.oldY then
            editPos.x = replacement.x
            editPos.y = replacement.y
        end
    end

    profile._referenceLayout20260801 = true
end

local function ApplyDebuffDefaultsMigration()
    local profile = db.profile
    if not profile or profile._debuffDefaults20260815 then return end

    -- Ensure player has maxDebuffs and onlyPlayerDebuffs
    local player = profile.player
    if player then
        if player.maxDebuffs == nil then
            player.maxDebuffs = 20
        end
        if player.onlyPlayerDebuffs == nil then
            player.onlyPlayerDebuffs = true
        end
    end

    -- Ensure target has maxDebuffs and showDebuffs enabled by default
    local target = profile.target
    if target then
        if target.maxDebuffs == nil then
            target.maxDebuffs = 20
        end
        if target.showDebuffs == nil then
            target.showDebuffs = true
        end
    end

    -- Adjust target x position as base for dynamic calculation
    -- ApplyFramePosition will add additional offset if portrait is active
    local positions = profile.positions or {}
    local targetPos = positions.target
    if targetPos and targetPos.point == "CENTER" and targetPos.x == 300 and targetPos.y == -145 then
        targetPos.x = 280
    end

    -- Also update unlock mode position if it matches
    if KT and KT.db and KT.db.profile and KT.db.profile.editMode and KT.db.profile.editMode.frames then
        local editPos = KT.db.profile.editMode.frames["unitframes_target"]
        if editPos and editPos.point == "CENTER" and editPos.x == 300 and editPos.y == -145 then
            editPos.x = 280
        end
    end

    profile._debuffDefaults20260815 = true
end

local FOREVER_UNIT_FRAME_LAYOUT_VERSION = 20260921

local FOREVER_UNIT_FRAME_LAYOUT_DEFAULTS = {
    focus = { point = "TOPLEFT", x = 952.8616333007812, y = -1066.000396728516 },
    pet = { point = "TOPLEFT", x = 953.8617553710938, y = -869.2078247070312 },
    targettarget = { point = "TOPLEFT", x = 1521.352294921875, y = -844.6795654296875 },
    focustarget = { point = "TOPLEFT", x = 952.7691650390625, y = -1124.056945800781 },
}

-- Persistence guard: old Forever builds used to delete the saved copies here.
-- Keep this helper inert so no future rebind can erase user coordinates.
local function ClearForeverUnitFrameLayoutCopies()
end

local function WriteForeverUnitFrameLayoutCopies()
    local function writeFrames(frames)
        if type(frames) ~= "table" then return end
        for key, pos in pairs(FOREVER_UNIT_FRAME_LAYOUT_DEFAULTS) do
            local saved = frames["unitframes_" .. key]
            if type(saved) ~= "table"
                or type(saved.point) ~= "string"
                or type(saved.x) ~= "number"
                or type(saved.y) ~= "number"
            then
                frames["unitframes_" .. key] = {
                    point = pos.point,
                    relativePoint = pos.point,
                    x = pos.x,
                    y = pos.y,
                }
            end
        end
    end

    local profileName = (KT.db.GetCurrentProfile and KT.db:GetCurrentProfile())
        or (KT.db.keys and KT.db.keys.profile)

    local activeEditMode = KT.db.profile.editMode
    if type(activeEditMode) ~= "table" then
        activeEditMode = {}
        KT.db.profile.editMode = activeEditMode
    end
    activeEditMode.frames = activeEditMode.frames or {}
    writeFrames(activeEditMode.frames)

    local function writeProfile(profile)
        if type(profile) ~= "table" then return end
        profile.editMode = profile.editMode or {}
        profile.editMode.frames = profile.editMode.frames or {}
        writeFrames(profile.editMode.frames)
        profile.unitFrames = profile.unitFrames or {}
        profile.unitFrames.positions = profile.unitFrames.positions or {}
        for key, pos in pairs(FOREVER_UNIT_FRAME_LAYOUT_DEFAULTS) do
            local saved = profile.unitFrames.positions[key]
            if type(saved) ~= "table"
                or type(saved.point) ~= "string"
                or type(saved.x) ~= "number"
                or type(saved.y) ~= "number"
            then
                profile.unitFrames.positions[key] = {
                    point = pos.point,
                    x = pos.x,
                    y = pos.y,
                }
            end
        end
    end

    local stores = { KT.db.sv, _G.KullThranDB }
    for _, store in ipairs(stores) do
        if type(store) == "table" and profileName and type(store.profiles) == "table" then
            writeProfile(store.profiles[profileName])
        end
    end

    local function writeShadow(global)
        if type(global) ~= "table" or not profileName then return end
        global.kuiUnlockPositions = global.kuiUnlockPositions or {}
        local shadow = global.kuiUnlockPositions[profileName]
        if type(shadow) ~= "table" then
            shadow = {}
            global.kuiUnlockPositions[profileName] = shadow
        end
        writeFrames(shadow)
    end

    writeShadow(KT.db.global)
    writeShadow(KT.db.sv and KT.db.sv.global)
    writeShadow(_G.KullThranDB and _G.KullThranDB.global)
    writeFrames(KT.svPersistedUnlockFrames)

    local snapshot = _G.KUI_BOOT_SNAPSHOT
    if type(snapshot) == "table" and profileName then
        local snapProfile = snapshot.profiles and snapshot.profiles[profileName]
        if type(snapProfile) == "table" then
            snapProfile.editMode = snapProfile.editMode or {}
            snapProfile.editMode.frames = snapProfile.editMode.frames or {}
            writeFrames(snapProfile.editMode.frames)
        end
        snapshot.global = snapshot.global or {}
        writeShadow(snapshot.global)
    end
end
local function ApplyForeverUnitFrameLayoutDefaults()
    if not (db and db.profile and KT and KT.db and KT.db.profile) then return end
    local profile = db.profile

    profile.positions = profile.positions or {}
    for key, pos in pairs(FOREVER_UNIT_FRAME_LAYOUT_DEFAULTS) do
        local saved = profile.positions[key]
        if type(saved) ~= "table"
            or type(saved.point) ~= "string"
            or type(saved.x) ~= "number"
            or type(saved.y) ~= "number"
        then
            profile.positions[key] = {
                point = pos.point,
                x = pos.x,
                y = pos.y,
            }
        end
    end

    -- Seed only missing entries. Existing SavedVariables are authoritative.
    WriteForeverUnitFrameLayoutCopies()

    -- Testing mode: apply the defaults to the live frames as well. This is
    -- intentionally repeated after delayed Blizzard/Unlock Mode restores.
    if not (InCombatLockdown and InCombatLockdown()) then
        local targetFrames = {
            focus = frames.focus,
            pet = frames.pet,
            targettarget = frames.targettarget,
            focustarget = frames.focustarget,
        }
        for key, frame in pairs(targetFrames) do
            if frame then
                ApplyFramePosition(frame, key)
            end
        end
    end

    local unlockMode = KT.GetModule and KT:GetModule("UnlockMode", true)
    if unlockMode and unlockMode.isOpen then
        unlockMode:UpdateRegistry()
        unlockMode:RefreshMovers()
    end

    profile._foreverUnitFrameLayoutVersion = FOREVER_UNIT_FRAME_LAYOUT_VERSION
end
function Mod:BindDatabase()
    if not (KT and KT.db and KT.db.profile) then return end
    KT.db.profile.unitFrames = KT.db.profile.unitFrames or {}
    Compat.CopyDefaults(KT.db.profile.unitFrames, defaults.profile)
    if KT.VisualThemes and KT.VisualThemes.ApplyCurrentThemeToModule then
        KT.VisualThemes:ApplyCurrentThemeToModule("unitframes")
    end
    UCtx.Invalidate()
    db = { profile = KT.db.profile.unitFrames }
    self.db = db.profile
    -- 5.0.8 forced the character level off once (marked by
    -- _kuiForeverLevelPvpOptionsReset) and that false stayed saved after 5.1.1
    -- made it default on again. Give the level back once to those profiles.
    if self.db._kuiForeverLevelPvpOptionsReset and not self.db._kuiLevelRestored then
        self.db.showCharacterLevel = true
        self.db._kuiLevelRestored = true
    end
    self.db.enable = self.db.enable ~= false
end

function Mod:OnInitialize()
    self:BindDatabase()
    self:SetEnabledState(self.db.enable ~= false)
    MigratePlayerTarget()
    ApplyForeverPortraitDefaults()
    SanitizeImportedLayout()
    MigrateLegacyCrimsonAccent()
    ApplyUpdatedDefaultPreset()
    ApplyTargetCastbarYellowDefault()
    KT:SwapPortraitFacingDefaults()
    KT:MigrateClassicPortraitCircular()
    KT:MigrateRetailPortraitCircular()
    KT:MigrateRetailHealthGreen()
    KT:MigrateForeverHealthColorSelector()
    KT:MigrateKuiPvPCircleDefault()
    KT:MigrateThemedCastbarVisible()
    ApplyReferenceLayoutDefaults()
    ApplyDebuffDefaultsMigration()
    ApplyForeverUnitFrameLayoutDefaults()
    ns.MigrateBlizzardTextDefaults(db.profile)
    ns.EnforceTargetBuffs(db.profile)
    if RegisterUFHPDebugSlash then
        C_Timer.After(0, RegisterUFHPDebugSlash)
    end
    if KT and KT.RegisterChatCommand then
        KT:RegisterChatCommand("ktufhpdebug", function(msg) SlashCmdList.KTUFHPDEBUG(msg) end)
        KT:RegisterChatCommand("ktufhpdbg", function(msg) SlashCmdList.KTUFHPDEBUG(msg) end)
    end

    do
        local prof = db.profile
        if prof.use3DPortrait ~= nil then
            if prof.use3DPortrait == true then
                prof.portraitMode = "3d"
            elseif prof.use3DPortrait == false and not prof.portraitMode then
                prof.portraitMode = "2d"
            end
            prof.use3DPortrait = nil
        end
    end

    do
        local prof = db.profile
        local units = { "player", "target", "focus", "boss", "pet", "totPet" }
        local globalPM = prof.portraitMode
        local globalFont = prof.selectedFont
        local globalTex = prof.healthBarTexture
        if globalPM ~= nil or globalFont ~= nil or globalTex ~= nil then
            for i = 1, #units do
                local s = prof[units[i]]
                if s then
                    if s.portraitMode == nil then
                        s.portraitMode = (s.showPortrait == false) and "none" or (globalPM or "2d")
                    end
                    if s.selectedFont == nil then s.selectedFont = globalFont or "AAA_ITC_Avant_Garde" end
                    if s.healthBarTexture == nil then s.healthBarTexture = globalTex or "Melli Reforged" end
                end
            end
            prof.portraitMode = nil
            prof.selectedFont = nil
            prof.healthBarTexture = nil
            prof.healthBarTextureOpacity = nil
        end
    end

    ResolveFontPath()
    Compat.AppendSharedMediaTextures(healthBarTextureNames, healthBarTextureOrder, nil, healthBarTextures)

    do
        local prof = db.profile
        local oldKeys = { gradient = true, grunge = true, stripe = true }
        local units = { "player", "target", "focus", "boss", "pet", "totPet" }
        for i = 1, #units do
            local s = prof[units[i]]
            if s and s.healthBarTexture and oldKeys[s.healthBarTexture] then
                s.healthBarTexture = "none"
            end
            if s and s.healthBarOpacity and s.healthBarOpacity <= 1.0 then
                s.healthBarOpacity = math.floor(s.healthBarOpacity * 100 + 0.5)
            end
            if s and s.powerBarOpacity and s.powerBarOpacity <= 1.0 then
                s.powerBarOpacity = math.floor(s.powerBarOpacity * 100 + 0.5)
            end
        end
        if prof.healthBarOpacity and prof.healthBarOpacity <= 1.0 then
            prof.healthBarOpacity = math.floor(prof.healthBarOpacity * 100 + 0.5)
        end
        if prof.powerBarOpacity and prof.powerBarOpacity <= 1.0 then
            prof.powerBarOpacity = math.floor(prof.powerBarOpacity * 100 + 0.5)
        end
    end

    do
        local prof = db.profile
        local units = { "player", "target", "focus" }
        for i = 1, #units do
            local s = prof[units[i]]
            if s and s.leftTextContent == nil and (s.namePosition or s.healthTextPosition) then
                local np = s.namePosition or "left"
                local hp = s.healthTextPosition or "right"
                local hd = s.healthDisplay or (units[i] == "focus" and "perhp" or "both")
                if np == "left" then
                    s.leftTextContent = "name"
                    s.rightTextContent = (hp == "right") and hd or "none"
                elseif np == "right" then
                    s.rightTextContent = "name"
                    s.leftTextContent = (hp == "left") and hd or "none"
                else
                    s.leftTextContent = (hp == "left") and hd or "none"
                    s.rightTextContent = (hp == "right") and hd or "none"
                end
                local ts = s.textSize or 12
                if s.leftTextSize == nil then s.leftTextSize = ts end
                if s.rightTextSize == nil then s.rightTextSize = ts end
                if s.leftTextX == nil then s.leftTextX = 0 end
                if s.leftTextY == nil then s.leftTextY = 0 end
                if s.rightTextX == nil then s.rightTextX = 0 end
                if s.rightTextY == nil then s.rightTextY = 0 end
            end
        end
    end

    do
        local s = db.profile.player
        if s then
            if s.showPlayerAbsorb == nil or s.showPlayerAbsorb == false then
                s.showPlayerAbsorb = true
            end
            s.absorbBarTexture = NormalizeImportedTexture(s.absorbBarTexture or defaults.profile.player.absorbBarTexture or DEFAULT_ABSORB_TEXTURE)
            s.absorbBarColor = NormalizeImportedColor(s.absorbBarColor, defaults.profile.player.absorbBarColor or DEFAULT_ABSORB_COLOR)
            if s.classPowerStyle == "bars" or s.classPowerStyle == "circles" then
                s.classPowerStyle = "modern"
            end
            if s.showClassPowerBar and (s.classPowerStyle == "none" or s.classPowerStyle == nil) then
                s.classPowerStyle = "blizzard"
            end
            if s.classPowerStyle and s.classPowerStyle ~= "none" then
                s.showClassPowerBar = true
            end
        end
    end

    do
        local prof = db.profile
        local units = { "player", "target", "focus", "boss", "pet", "totPet" }
        local anyNone = false
        for i = 1, #units do
            local s = prof[units[i]]
            if s and s.portraitMode == "none" then
                anyNone = true
                break
            end
        end
        if anyNone then
            prof.portraitStyle = "none"
            for i = 1, #units do
                local s = prof[units[i]]
                if s and s.portraitMode == "none" then
                    s.portraitMode = "2d"
                    s.showPortrait = false
                end
            end
        end
    end

    do
        local prof = db.profile
        local units = { "player", "target", "focus", "boss" }
        for i = 1, #units do
            local s = prof[units[i]]
            if s and s.powerPercentTextPowerColor == nil and s.powerPercentPowerColor ~= nil then
                s.powerPercentTextPowerColor = s.powerPercentPowerColor
            end
        end
        local old = prof.playerTarget
        if old and old.powerPercentTextPowerColor == nil and old.powerPercentPowerColor ~= nil then
            old.powerPercentTextPowerColor = old.powerPercentPowerColor
        end
    end
end

function Mod:Refresh()
    self:BindDatabase()
    if self.db.enable == false then
        return
    end
    SetupOptionsPanel()
    -- ThemeClientAssets.lua's ScaleStockBarText caches each FontString's
    -- pre-scale "base" font size the FIRST time it runs, on purpose (so
    -- repeated calls within the same settings never compound the shrink).
    -- But this IS a genuine profile change (Refresh only fires from
    -- OnProfileChanged/OnProfileCopied/OnProfileReset, or the login
    -- charKey-correction firing that same callback manually): health text size stayed wrong even after position/theme
    -- corrected, because that first capture happened during the brief
    -- wrong-profile window and every later call only ever multiplied that
    -- already-wrong base by the new scale, never truly resetting it. Clear
    -- the cache here so the next ReloadFrames recaptures a correct base.
    local function ClearStockFontCache(fs)
        if type(fs) ~= "table" then return end
        fs._ktStockBaseFontSize = nil
        fs._ktForeverFitBaseFontSize = nil
    end
    for _, frame in pairs(frames) do
        if type(frame) == "table" then
            ClearStockFontCache(frame.LeftText)
            ClearStockFontCache(frame.RightText)
            ClearStockFontCache(frame.CenterText)
            if type(frame.Castbar) == "table" then
                ClearStockFontCache(frame.Castbar.Text)
                ClearStockFontCache(frame.Castbar.Time)
            end
        end
    end
    -- ApplyFramePosition is only ever called from InitializeFrames (once,
    -- at OnEnable, using whatever profile happened to be active at that
    -- exact instant) and from the separate Edit Mode registration path --
    -- never from ReloadFrames. After a genuine profile change (the login
    -- charKey correction firing OnProfileChanged), theme and health text
    -- update but frame position would stay on whatever the previous
    -- profile had, because nothing in this refresh path ever reapplies it.
    -- Re-seat every unit's position here too.
    for _, unit in ipairs({ "player", "target", "focus", "pet", "targettarget", "focustarget" }) do
        if frames[unit] then
            ApplyFramePosition(frames[unit], unit)
        end
    end
    -- UpdateCircularPortraitBorder only ever runs from frame creation or
    -- from Health's own PostUpdate hook (i.e. the next time health VALUE
    -- changes), so a new "Circular Portrait Border Color" picked in Options
    -- (which calls Mod:Reload() same as every other option here) wouldn't
    -- repaint until health next ticked. Re-seat it here too, same fix shape
    -- as the font-cache and position re-applies above.
    for _, frame in pairs(frames) do
        if type(frame) == "table" then
            UpdateCircularPortraitBorder(frame)
        end
    end
    if KT.PersistDebug and frames.target then
        local pos = db and db.profile and db.profile.positions and db.profile.positions.target
        local point, _, _, ofsX, ofsY = frames.target:GetPoint()
        KT:PersistDebug("UF REFRESH target savedX=%s savedY=%s livePoint=%s liveX=%s liveY=%s rightTextFont=%s",
            tostring(pos and pos.x), tostring(pos and pos.y), tostring(point), tostring(ofsX), tostring(ofsY),
            tostring(frames.target.RightText and frames.target.RightText.GetFont
                and select(2, frames.target.RightText:GetFont())))
    end
    if frames.player and ns.ReloadFrames then
        ns.ReloadFrames()
    end
end

function Mod:OnEnable()
    self:BindDatabase()
    ns.EnableTarget3D(db and db.profile)
    if self.db.enable == false then
        self:SetEnabledState(false)
        return
    end
    InitializeFrames()

    -- Refresh classification directly on target/focus changes. The oUF
    -- frame events can run before Blizzard has populated UnitClassification().
    if not self._classificationEventsRegistered then
        self:RegisterEvent("PLAYER_TARGET_CHANGED", "RefreshClassificationMetadata")
        self:RegisterEvent("PLAYER_FOCUS_CHANGED", "RefreshClassificationMetadata")
        self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", "RefreshClassificationMetadata")
        self._classificationEventsRegistered = true
    end

    -- Rebinds may happen more than once while Blizzard finishes loading its
    -- layout, but ApplyForeverUnitFrameLayoutDefaults only seeds missing data.
    ApplyForeverUnitFrameLayoutDefaults()
    C_Timer.After(0.25, ApplyForeverUnitFrameLayoutDefaults)
    C_Timer.After(2.5, ApplyForeverUnitFrameLayoutDefaults)
    C_Timer.After(5.0, ApplyForeverUnitFrameLayoutDefaults)

    SetupOptionsPanel()
    Compat.ApplyColorsToOUF()

    if KT.db and not self._dbCallbacksRegistered then
        KT.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileReset", "Refresh")
        self._dbCallbacksRegistered = true
    end

    if not self._persistenceEventsRegistered then
        self:RegisterEvent("VARIABLES_LOADED", "RefreshAfterPersistenceReady")
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshAfterPersistenceReady")
        self._persistenceEventsRegistered = true
    end
end

function Mod:ApplyForeverRuntimeDefaults()
    self:BindDatabase()
    ns.EnableTarget3D(db and db.profile)
    if not (self.db and self.db.enable ~= false) then return end
    ApplyForeverUnitFrameLayoutDefaults()
    if ns.ReloadFrames then
        ns.ReloadFrames()
    end
end

function Mod:RefreshAfterPersistenceReady()
    local function RebindAndApply()
        self:ApplyForeverRuntimeDefaults()
    end

    RebindAndApply()
    C_Timer.After(0.5, RebindAndApply)
    C_Timer.After(2.0, RebindAndApply)
end
function Mod:OnDisable()
    local function HideFrameTree(value)
        if not value then return end
        if value.Hide then
            value:Hide()
        elseif type(value) == "table" then
            for _, child in pairs(value) do
                HideFrameTree(child)
            end
        end
    end
    HideFrameTree(frames)
end
