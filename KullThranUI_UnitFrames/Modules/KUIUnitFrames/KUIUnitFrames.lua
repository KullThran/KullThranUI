local addonName, ns = ...

local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
function ns.UFLoc(text)
    local L = KT and KT.GetLocale and KT:GetLocale()
    return (L and L[text]) or text
end
local Mod = KT:NewModule("UnitFrames", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
local oUF = ns.oUF or oUF
local Compat = ns.KUIUFCompat or {}
ns.KUIUFCompat = Compat
ns.UnitFrames = Mod
KT.UnitFrameWidgets = ns.FrameWidgets

Compat.PP = Compat.PP or {}
local PP = Compat.PP

if not oUF then
    error("KUIUnitFrames: oUF library not found! Please install oUF to Libraries\\oUF\\ folder.")
    return
end

local db
Compat.Bind({ GetProfile = function() return db and db.profile end })
local Portraits = ns.Portraits  -- KUI_Portraits.lua
local portraitsCtx  -- context of ns.Portraits, built where the unit frame kit is defined
local FrameBuild = ns.FrameBuild  -- KUI_FrameBuild.lua
local frameBuildCtx  -- context of ns.FrameBuild, built once in the frame initialisation before the first spawn
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

-- Name of the theme currently being drawn ("kui" when none is reported).
-- Hung on ns rather than a local to spare the main chunk a slot.
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

-- Difficulty colour of an attackable unit's level, as on Blizzard's target
-- frame (grey / green / yellow / orange / red; a hidden "??" level is red).
-- nil for units you cannot attack or when the game keeps the level secret.
function ns.LevelDifficultyColor(unit)
    if not unit or not ns.SafeCall(UnitCanAttack, "player", unit) then return nil end
    local color
    if C_PlayerInfo and type(GetDifficultyColor) == "function" then
        local difficulty = ns.SafeCall(C_PlayerInfo.GetContentDifficultyCreatureForPlayer, unit)
        if difficulty ~= nil then color = ns.SafeCall(GetDifficultyColor, difficulty) end
    end
    if type(color) ~= "table" then
        local level = ns.SafeCall(UnitEffectiveLevel, unit)
        if type(level) ~= "number" or level == 0 then level = ns.SafeCall(UnitLevel, unit) end
        if type(level) == "number" and level > 0 then
            color = ns.SafeCall(GetCreatureDifficultyColor or GetQuestDifficultyColor, level)
        elseif type(level) == "number" and level < 0 then
            return 1, 0.1, 0.1
        end
    end
    if type(color) == "table" and type(color.r) == "number" then return color.r, color.g, color.b end
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

-- The raid marker draws on its own host frame, kept one level above every
-- frame that draws on or around the portrait: the portrait and its rim, the
-- stock frame art, the Rare/Elite rings, the level and PvP badges, the target
-- combo ring (iOvr + 12, its points one level higher) and the aggro glow.
-- A fixed offset from iOvr does not hold: the combo ring is re-levelled on
-- every refresh and the aggro glow moves iOvr and the level overlay, so each
-- of those passes calls this again.
local RAID_TARGET_STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4,
    DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
function ns.RaiseRaidTargetHost(frame)
    local host = frame and frame._kuiRaidTargetHost
    if not (host and host.SetFrameLevel) then return false end
    local strata, rank, level = nil, 0, 0
    local function Consider(f, depth)
        if not (f and f ~= host and f.GetFrameLevel and f.GetFrameStrata) then return end
        local st = f:GetFrameStrata()
        local rk = RAID_TARGET_STRATA_RANK[st] or 2
        local lv = f:GetFrameLevel() or 0
        if rk > rank then
            strata, rank, level = st, rk, lv
        elseif rk == rank and lv > level then
            level = lv
        end
        if depth > 0 and f.GetChildren then
            for _, child in ipairs({ f:GetChildren() }) do Consider(child, depth - 1) end
        end
    end
    Consider(frame._kuiIndicatorOverlay, 4)
    Consider(frame.Portrait and frame.Portrait.backdrop, 2)
    Consider(frame._kuiAggroGlow, 2)
    for _, key in ipairs({ "_kuiTargetComboRing", "_kuiTargetComboBar", "_kuiNativeClassHost",
        "_kuiClassicRingHost", "_ktForeverArtHost", "_ktClassicArtHost" }) do
        Consider(frame[key], 3)
    end
    if not strata then return false end
    pcall(host.SetFrameStrata, host, strata)
    pcall(host.SetFrameLevel, host, level + 1)
    return true
end

-- Blizzard-art styles centre the raid marker on the portrait's top edge, as
-- the stock Target/Player frames do; below the health bar it covers the power
-- bar. The KUI style and portrait-less frames keep it under the health bar.
function ns.RefreshRaidTargetAnchor(frame)
    local tex = frame and frame.RaidTargetIndicator
    if not tex then return false end
    ns.RaiseRaidTargetHost(frame)
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    local portrait = frame.Portrait and frame.Portrait.backdrop
    local scale = (frame.GetWidth and frame:GetWidth() or 232) / 232
    if scale <= 0 then scale = 1 end
    tex:ClearAllPoints()
    if theme and theme ~= "kui" and portrait and portrait:IsShown() then
        tex:SetSize(24 * scale, 24 * scale)
        tex:SetPoint("CENTER", portrait, "TOP", 0, 2 * scale)
        return true
    end
    tex:SetSize(18, 18)
    tex:SetPoint("TOP", frame.Health, "BOTTOM", 0, -2)
    return true
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
        -- KUI Style has its own level colour (see ns.LevelColorKey).
        levelColorKUI = { r = 1, g = 1, b = 1, a = 1 },
        -- Every style: enemies' level number in its difficulty colour (the key keeps its old name).
        levelDifficultyColorKUI = true,
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
-- Per-unit defaults are assembled from small reusable groups instead of being
-- spelled out once per unit. They are filled in here, after the constructor,
-- because the main chunk is close to the 200-locals limit; the helpers below
-- live in this block only.
do
    local function Dup(v)
        if type(v) ~= "table" then return v end
        local c = {}
        for k, x in pairs(v) do c[k] = Dup(x) end
        return c
    end
    -- Merge every group into one fresh table (colour tables are copied, never shared).
    local function Merge(...)
        local out = {}
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do out[k] = Dup(v) end
        end
        return out
    end

    local BLACK, WHITE = { r = 0, g = 0, b = 0 }, { r = 1, g = 1, b = 1 }
    local SLOT_NAMES = { "left", "right", "center" }
    local BTB_SLOT_NAMES = { "Left", "Right", "Center" }
    local ENABLED_UNITS = { "player", "target", "focus", "pet", "targettarget", "boss" }

    local function Frame(width, height, scale)
        return { frameWidth = width, healthHeight = height, frameScale = scale }
    end
    local function Chrome()
        return { borderSize = 1, borderColor = BLACK, highlightColor = WHITE, textSize = 14 }
    end
    local function Look(withPowerOpacity)
        return {
            selectedFont = "AAA_ITC_Avant_Garde",
            healthBarTexture = "Melli Reforged",
            healthBarOpacity = 90,
            powerBarOpacity = withPowerOpacity and 100 or nil,
        }
    end
    local function PowerBar()
        return {
            powerHeight = 6, powerPosition = "below", powerWidth = 0, powerX = 0, powerY = -4,
            powerPercentText = "none", powerTextFormat = "perpp", powerShowPercent = true,
            powerPercentSize = 11, powerPercentX = 0, powerPercentY = 0,
            powerPercentPowerColor = true, powerPercentTextPowerColor = false,
            healthClassColored = true,
        }
    end
    -- contents = { left, right, center }; layout adds size/offset/class-colour keys.
    local function TextSlots(contents, layout)
        local g = {}
        for i, slot in ipairs(SLOT_NAMES) do
            g[slot .. "TextContent"] = contents[i]
            if layout then
                g[slot .. "TextSize"] = 14
                g[slot .. "TextX"] = 0
                g[slot .. "TextY"] = 0
                g[slot .. "TextClassColor"] = false
            end
        end
        return g
    end
    local function TextBar()
        local g = {
            bottomTextBar = false, bottomTextBarHeight = 16, btbPosition = "bottom",
            btbWidth = 0, btbX = 0, btbY = 0,
            btbBgColor = { r = 0.2, g = 0.2, b = 0.2 }, btbBgOpacity = 1.0,
            btbClassIcon = "none", btbClassIconSize = 14, btbClassIconLocation = "left",
            btbClassIconX = 0, btbClassIconY = 0,
        }
        for _, slot in ipairs(BTB_SLOT_NAMES) do
            g["btb" .. slot .. "Content"] = "none"
            g["btb" .. slot .. "Size"] = 13
            g["btb" .. slot .. "X"] = 0
            g["btb" .. slot .. "Y"] = 0
            g["btb" .. slot .. "ClassColor"] = false
            g["btb" .. slot .. "PowerColor"] = false
        end
        return g
    end
    local function Portrait(side, facing)
        return {
            showPortrait = false, portraitMode = "2d", portraitSide = side,
            portraitSize = 0, portraitX = 0, portraitY = 0,
            portraitFacing = facing,
            classThemeStyle = "modern",
            detachedPortraitShape = "portrait",
            detachedPortraitBorderColor = BLACK,
            detachedPortraitClassColor = true,
            detachedPortraitBorder = true,
            detachedPortraitBorderOpacity = 100,
            detachedPortraitBorderSize = 7,
        }
    end
    local function CastText()
        return {
            castSpellNameSize = 13, castSpellNameColor = WHITE,
            castDurationSize = 13, castDurationColor = WHITE,
            castbarHideWhenInactive = true,
        }
    end
    local function AuraAnchors(withBuffs)
        local g = { debuffAnchor = "bottomleft", debuffGrowth = "auto" }
        if withBuffs then
            g.buffAnchor = "topleft"
            g.buffGrowth = "auto"
        end
        return g
    end
    local function Visibility()
        return { showInRaid = true, showInParty = true, showSolo = true }
    end

    local P = defaults.profile

    P.player = Merge(
        Frame(230, 46, 100), PowerBar(), AuraAnchors(true), TextSlots({ "name", "both", "none" }, true),
        TextBar(), Portrait("left", "flipped"), Look(true), Chrome(), CastText(), Visibility(),
        {
            healthDisplay = "both",
            showBuffs = false, maxBuffs = 4, onlyPlayerDebuffs = true, maxDebuffs = 20,
            namePosition = "left", healthTextPosition = "right",
            showPlayerAbsorb = true, absorbBarTexture = "Melli Dark Rough",
            absorbBarColor = { r = 0.11, g = 1.00, b = 0.62, a = 1.00 },
            showPlayerCastbar = false, showPlayerCastIcon = true, lockCastbarToFrame = true,
            playerCastbarX = 0, playerCastbarY = 0, playerCastbarWidth = 0, playerCastbarHeight = 0,
            castbarClassColored = true,
            showClassPowerBar = false, lockClassPowerToFrame = true, classPowerStyle = "none",
            classPowerPosition = "top", classPowerBarX = 0, classPowerBarY = 0,
            classPowerSize = 8, classPowerSpacing = 2, classPowerClassColor = true,
            classPowerCustomColor = { r = 1, g = 0.82, b = 0 },
            classPowerBgColor = { r = 0.082, g = 0.082, b = 0.082, a = 1.0 },
            classPowerEmptyColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
            combatIndicatorStyle = "standard", combatIndicatorColor = "custom",
            combatIndicatorCustomColor = WHITE, combatIndicatorPosition = "healthbar",
            combatIndicatorSize = 22, combatIndicatorX = 0, combatIndicatorY = 0,
            showRestingStatus = false,
        })

    P.target = Merge(
        Frame(230, 46, 100), PowerBar(), AuraAnchors(true), TextSlots({ "name", "both", "none" }, true),
        TextBar(), Portrait("right", "normal"), Look(true), Chrome(), CastText(), Visibility(),
        {
            castbarHeight = 14, showCastbar = true, showCastIcon = true,
            castbarFillColor = { r = 1, g = 0.82, b = 0 }, castbarClassColored = false,
            healthDisplay = "both",
            showBuffs = true, showDebuffs = true, onlyPlayerDebuffs = false,
            maxBuffs = 20, maxDebuffs = 20,
            namePosition = "left", healthTextPosition = "right",
        })

    -- Pre-split shared table, kept so older profiles can still be migrated.
    P.playerTarget = Merge(PowerBar(), {
        frameWidth = 230, healthHeight = 46, castbarHeight = 14, maxBuffs = 20, maxDebuffs = 20,
        healthDisplay = "both", showBuffs = true, onlyPlayerDebuffs = false,
        showPlayerAbsorb = true, showPlayerCastbar = false, showClassPowerBar = false,
        classPowerBarX = 0, classPowerBarY = 0,
        playerCastbarX = 0, playerCastbarY = 0, playerCastbarWidth = 0, playerCastbarHeight = 0,
    })
    P.playerTarget.powerPosition = nil
    P.playerTarget.powerWidth = nil
    P.playerTarget.powerX = nil

    P.totPet = Merge(
        Frame(101, 25, 100), Look(false), Chrome(), TextSlots({ "name", "none", "none" }),
        { showPortrait = false, portraitMode = "2d", powerPosition = "none" })

    P.pet = Merge(
        Frame(101, 25, 100), PowerBar(), Look(false), Chrome(), TextSlots({ "name", "none", "none" }),
        { showPortrait = false, portraitMode = "2d" })

    P.focus = Merge(
        Frame(160, 34, 100), PowerBar(), AuraAnchors(false), TextSlots({ "name", "perhp", "none" }, true),
        TextBar(), Portrait("right", nil), Look(true), Chrome(), CastText(), Visibility(),
        {
            castbarHeight = 14, showCastbar = true, showCastIcon = true,
            castbarClassColored = false,
            healthDisplay = "perhp",
            onlyPlayerDebuffs = true, maxDebuffs = 10,
        })

    P.boss = Merge(
        Frame(160, 34, 100), PowerBar(), Look(true), Chrome(), TextSlots({ "name", "perhp", "none" }),
        { castbarHeight = 14, healthDisplay = "perhp", showPortrait = false, portraitMode = "2d" })

    P.enabledFrames = { focustarget = false }
    for _, key in ipairs(ENABLED_UNITS) do
        P.enabledFrames[key] = true
    end
end
-- KUI's per-client, per-resolution defaults (Modules/DefaultLayout.lua).
-- UnitLayout.legacy keeps the single-set ones they replace, so a profile
-- still on one moves to the new default once (UnitLayout.Migrate). It hangs
-- off Mod: this chunk is at Lua's 200-locals limit.
Mod.UnitLayout = { units = { "focus", "pet", "targettarget", "focustarget", "boss" }, legacy = {} }
function Mod.UnitLayout.Copy(pos)
    if type(pos) ~= "table" then return nil end
    return { point = pos.point, relativeTo = pos.relativeTo, relativePoint = pos.relativePoint, x = pos.x, y = pos.y,
        fallback = Mod.UnitLayout.Copy(pos.fallback) }
end
for _, key in ipairs(Mod.UnitLayout.units) do
    Mod.UnitLayout.legacy[key] = defaults.profile.positions[key]
    defaults.profile.positions[key] = KT:GetDefaultLayoutPosition(key, defaults.profile.positions[key])
end
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
    -- Apply() also reset the raid marker host's strata; lift it back on top.
    if owner and owner._kuiRaidTargetHost then ns.RaiseRaidTargetHost(owner) end
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

-- â”€â”€â”€ Subsistema de resolución de fuentes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Gestiona la ruta de fuente global y per-unit con invalidación.
-- LOCALE_FONT_OVERRIDE fuerza una fuente del sistema para CJK/Cyrillic.
-- Resolve() regenera la caché; Get() la consume sin recalcular.
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
  -- This is the profile's own size: the stock styles rescale from it, so
  -- their cached bases must follow a changed Text Size.
  fs._ktStockBaseFontSize, fs._ktStockFitBaseFontSize, fs._ktForeverFitBaseFontSize = nil, nil, nil
  fs:SetFont(fontPath, size or 12, f)
  if KT and KT.EnableTextFontFallback then
    KT:EnableTextFontFallback(fs, fontPath)
  end
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.9)
end

-- Which saved level-colour key applies to the active style, plus that key's
-- fallback colour: the KUI look has its own (white), the Blizzard-art looks
-- share the gold one.
function ns.LevelColorKey()
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme and KT.VisualThemes:GetRenderedTheme()
    if theme == nil or theme == "kui" then
        return "levelColorKUI", { r = 1, g = 1, b = 1, a = 1 }
    end
    return "levelColor", { r = 1, g = 0.82, b = 0.20, a = 1 }
end

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
    local colorKey, colorDefault = ns.LevelColorKey()
    local color = profile[colorKey] or colorDefault
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

-- Stop the client from snapping a texture to the pixel grid (avoids shimmer).
local function UnsnapTex(tex)
    local PP = Compat and Compat.PP
    if PP then PP.DisablePixelSnap(tex)
    elseif tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0) end
end

-- Give a status bar its fill texture (flat white when no path) and unsnap it.
function ns.FillBar(bar, path)
    bar:SetStatusBarTexture(path or "Interface\\Buttons\\WHITE8x8")
    local fill = bar:GetStatusBarTexture()
    if fill then UnsnapTex(fill) end
end

-- Bar texture keys -> file paths (nil for "none"), their menu order, and labels.
-- The KUI bar textures come from the core catalogue (KT.KUI_BAR_TEXTURES, Defaults.lua);
-- KT.KUI_BAR_TEXTURE_RENAMES maps the keys older builds saved to their KUI names.
local healthBarTextures = {
    ["none"]          = nil,
    ["Melli Reforged"] = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga",
    ["Melli"]         = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga",
    ["Melli Dark"]    = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
    ["Melli Dark Rough"] = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
}
local healthBarTextureOrder = { "none", "Melli Reforged", "Melli", "Melli Dark", "Melli Dark Rough" }
local healthBarTextureNames = {}
local BAR_TEXTURE_RENAMES = KT.KUI_BAR_TEXTURE_RENAMES or {}
for _, entry in ipairs(KT.KUI_BAR_TEXTURES or {}) do
    healthBarTextures[entry.name] = entry.path
    healthBarTextureOrder[#healthBarTextureOrder + 1] = entry.name
end
for _, texKey in ipairs(healthBarTextureOrder) do
    healthBarTextureNames[texKey] = texKey
end
ns.healthBarTextures = healthBarTextures
ns.healthBarTextureOrder = healthBarTextureOrder
ns.healthBarTextureNames = healthBarTextureNames

local DEFAULT_ABSORB_TEXTURE = "Melli Dark Rough"
local DEFAULT_ABSORB_COLOR = { r = 0.11, g = 1.00, b = 0.62, a = 1.00 }

local function ResolveSharedTexturePath(textureKey, fallbackKey)
    textureKey = BAR_TEXTURE_RENAMES[textureKey] or textureKey
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

function ns.EnableTarget3D(profile)
    if not profile or profile._ktTarget3DInitialized then return end
    if profile.player and profile.player.portraitMode == "3d" and profile.target
        and profile.target.portraitMode == "2d" then
        profile.target.portraitMode = "3d"
        profile._ktTarget3DInitialized = true
    end
end

-- â”€â”€â”€ Subsistema de contexto de unidad â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Centraliza la resolución unitID â†’ clave de perfil â†’ tabla de settings.
-- Arquitectura: mapa estático pre-poblado en lugar de pattern matching o
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

-- Unidades con clave idéntica a su unitID en db.profile
local UNIT_KEY_IDENTITY = { player = true, target = true, focus = true }

-- Resolución de clave: determinístico por tabla, sin regex
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
-- The packaged Forever plate has plain rectangular slots. The Player/Target bar atlases carry
-- the old frame's baked edge and diagonal end, so Forever uses the rectangular Party fill.
function ns.AtlasFill.IsForeverPlate()
    local vt = KT.VisualThemes
    return vt and vt.GetRenderedTheme and vt:GetRenderedTheme() == "forever" or false
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
        if defaultColor and not health._kuiEnemyTint and AtlasExists(hAtlas)
            and not ns.AtlasFill.IsForeverPlate() then
            health:SetStatusBarTexture(hAtlas)
            health._kuiAtlasFill = true
            KeepWhite(health)
            SeatForeverMask(health)
            local f = health:GetStatusBarTexture()
            if f then f:SetVertexColor(1, 1, 1, 1) end
        else
            health._kuiAtlasFill = nil
            -- Class / custom / hostile colours: Blizzard's own untinted "Status"
            -- art, coloured through the bar colour exactly like the stock frame.
            ns.AtlasFill.ApplyTinted(health, side, "Health")
        end
    end
    -- Power: the resource colour changes per unit, so it uses the untinted
    -- Status art and oUF's resource tint rather than a pre-coloured atlas
    -- that would freeze to a previously selected target's resource.
    if power then
        power._kuiAtlasFill = nil
        ns.AtlasFill.ApplyTinted(power, side, "Mana")
    end
end
-- Blizzard's untinted bar art; the Party atlas is the fallback when the client
-- has no Player/Target variant. Falls back to the flat fill when neither exists.
function ns.AtlasFill.ApplyTinted(bar, side, kind)
    bar._kuiAtlasTint = nil
    local name
    local owners = ns.AtlasFill.IsForeverPlate() and { "Party" } or { side, "Party" }
    -- Party's Mana-Status art fades dark at its left end and Target's ends in a diagonal;
    -- both are hidden by the native ring on stock frames but show here, so every
    -- Blizzard-style resource bar reuses Party's rectangular Health fill.
    if kind == "Mana" then kind = "Health"; owners = { "Party" } end
    for _, owner in ipairs(owners) do
        local candidate = "UI-HUD-UnitFrame-" .. owner .. "-PortraitOn-Bar-" .. kind .. "-Status"
        if ns.AtlasFill.Exists(candidate) then name = candidate; break end
    end
    if not name then return end
    local r, g, b, a = bar:GetStatusBarColor()
    bar:SetStatusBarTexture(name)
    bar._kuiAtlasTint = true
    ns.AtlasFill.SeatMask(bar)
    if r then bar:SetStatusBarColor(r, g, b, a) end
end

-- Keys the visual themes seed (or the module default) as "no texture chosen":
-- only these hand the bar over to Blizzard's own art in the Retail/Forever styles.
function ns.IsThemeDefaultBarTexture(key)
    return key == "none" or key == "Melli Reforged" or key == "Blizzard Raid Bar" or key == "Blizzard"
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
        and ns.IsThemeDefaultBarTexture(texKey)
        and ns.BarGloss and ns.BarGloss.IsBlizzardStyle and ns.BarGloss.IsBlizzardStyle() then
        path = nil
    end

    ns.FillBar(health, path)
    if health.bg and bgPath then
        health.bg:SetTexture(bgPath)
        health.bg:SetVertexColor(1, 1, 1, 1)
    end

    -- The power bar follows the health bar's texture.
    local frame = health:GetParent()
    local power = frame and frame.Power
    if power then
        ns.FillBar(power, path)
        -- The resource track keeps its own dark backdrop and empty state, so
        -- it is refreshed separately instead of reusing the health background.
        ns.UpdatePowerBackground(power, frame.unit or unitKey, s)
    end

    if (unitKey == "player" or unitKey == "target")
        and ns.IsThemeDefaultBarTexture(texKey)
        and ns.BarGloss and ns.BarGloss.IsBlizzardStyle and ns.BarGloss.IsBlizzardStyle() then
        pcall(ns.AtlasFill.Apply, health, power, unitKey, s)
        if ns.BarGloss and ns.BarGloss.Update then ns.BarGloss:Update() end   -- drop the overlay shade over Blizzard art
    else
        health._kuiAtlasFill = nil
        health._kuiAtlasTint = nil
        if power then power._kuiAtlasFill = nil; power._kuiAtlasTint = nil end
    end
end

-- Fill + background alpha for a status bar; health and power only differ in
-- which saved opacity key they read.
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

-- Thin entry points with the signatures the callers already use.
local function ApplyHealthBarAlpha(health, unitKey)
    ApplyBarFillAlpha(health, unitKey, "healthBarOpacity", 90)
end
local function ApplyPowerBarAlpha(power, unitKey)
    local owner = power and power.GetParent and power:GetParent()
    ns.UpdatePowerBackground(power, owner and owner.unit or unitKey,
        unitKey and db.profile[unitKey])
end

-- Dark theme: near-black health fill over a grey background.
local DARK_HEALTH_R, DARK_HEALTH_G, DARK_HEALTH_B = 0x11/255, 0x11/255, 0x11/255  -- #111111
local DARK_HEALTH_A = 1.0
local KUI_PanelBaseColor_R, KUI_PanelBaseColor_G, KUI_PanelBaseColor_B = 0x4f/255, 0x4f/255, 0x4f/255  -- #4f4f4f

-- Hand health colouring back to oUF (true) or take it over (false).
function ns.SetAutoHealthColor(health, enabled)
    health.colorClass = enabled
    health.colorReaction = enabled
    health.colorTapped = enabled
    health.colorDisconnected = enabled
end

-- A saved colour is only trusted when it is a table with a numeric r.
function ns.UsableColor(c)
    if type(c) == "table" and type(c.r) == "number" then return c end
    return nil
end

local function ApplyDarkTheme(health)
    if not health then return end
    local isDark = db and db.profile and db.profile.darkTheme
    if isDark then
        ns.SetAutoHealthColor(health, false)
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
            health.bg:SetVertexColor(KUI_PanelBaseColor_R, KUI_PanelBaseColor_G, KUI_PanelBaseColor_B, 1)
            health.bg:SetAlpha(1)
        end
        -- After every oUF recolour, put the dark colour back and keep the
        -- background hugging the right edge of the fill. Alpha is not touched
        -- (no alpha argument is passed), so ApplyHealthBarAlpha's value survives.
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
        ns.SetAutoHealthColor(health, true)
        local unitKey = health._kuiUnitKey
        local unitSettings = unitKey and db.profile[unitKey]
        -- Saved colours can arrive without r/g/b; the arithmetic below would
        -- then error out and take the whole addon down, so only well-formed
        -- ones are used.
        local customFill = ns.UsableColor(unitSettings and unitSettings.customFillColor)
        local customBg = ns.UsableColor(unitSettings and unitSettings.customBgColor)
        -- A custom fill replaces class colouring unless class colour is on.
        if customFill and not (unitSettings and unitSettings.healthClassColored) then
            ns.SetAutoHealthColor(health, false)
            health:SetStatusBarColor(customFill.r, customFill.g, customFill.b)
        end
        -- The background is a dimmed copy (20%) of the fill colour, or the
        -- custom background. Opacity is left alone: a 3-argument
        -- SetStatusBarColor keeps the texture's alpha across oUF recolours.
        health.PostUpdateColor = function(self, unit, color)
            local uKey = self._kuiUnitKey
            local uSettings = uKey and db.profile[uKey]
            local cFill = uSettings and uSettings.customFillColor
            local cBg = uSettings and uSettings.customBgColor
            if type(cFill) ~= "table" or type(cFill.r) ~= "number" then cFill = nil end
            if type(cBg) ~= "table" or type(cBg.r) ~= "number" then cBg = nil end
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

local ShouldUseSmartPowerPercent
do
    -- Classes whose every spec runs on mana, and the one spec per class
    -- (GetSpecialization index) that does for the rest. Druids depend on form.
    local alwaysMana = { PRIEST = true, SHAMAN = true, MONK = true }
    local manaSpec = { PALADIN = 1, MAGE = 1, EVOKER = 2 }
    ShouldUseSmartPowerPercent = function()
        local _, cls = UnitClass("player")
        if not cls then return false end
        if cls == "DRUID" then
            local form = GetShapeshiftForm()
            return form == nil or form == 0 or form == 3
        end
        if alwaysMana[cls] then return true end
        local wanted = manaSpec[cls]
        return wanted ~= nil and GetSpecialization() == wanted
    end
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
-- Tabla combinada: cada ancla define su initialAnchor, dirección de crecimiento
-- automático, punto de fijación al frame padre y sentido de offset.
local BUFF_LAYOUT_DATA = {
    topleft     = { ia = "BOTTOMLEFT",  ax = "RIGHT", ay = "UP",   fp = "TOPLEFT",     ox = 0,  oy = 1  },
    topright    = { ia = "BOTTOMRIGHT", ax = "LEFT",  ay = "UP",   fp = "TOPRIGHT",    ox = 0,  oy = 1  },
    bottomleft  = { ia = "TOPLEFT",     ax = "RIGHT", ay = "DOWN", fp = "BOTTOMLEFT",  ox = 0,  oy = -1 },
    bottomright = { ia = "TOPRIGHT",    ax = "LEFT",  ay = "DOWN", fp = "BOTTOMRIGHT", ox = 0,  oy = -1 },
    left        = { ia = "BOTTOMRIGHT", ax = "LEFT",  ay = "DOWN", fp = "LEFT",        ox = -1, oy = 0  },
    right       = { ia = "BOTTOMLEFT",  ax = "RIGHT", ay = "DOWN", fp = "RIGHT",       ox = 1,  oy = 0  },
}
-- Mapeo de growth explícito â†’ (gx, gy)
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

function KT:GetKUIStyleBuffYOffset(unit, anchor)
    if unit ~= "player" and unit ~= "target" then return 0 end
    -- Rows below the bar must not be lifted onto it.
    if anchor and not tostring(anchor):find("^top") then return 0 end
    local VT = self.VisualThemes
    local renderedTheme = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
    -- KUI Style: the duration text ("52m", "4d") hangs under each icon and used
    -- to overlap the health bar. Lift the row so it clears the bar; the stock-art
    -- styles already have their own name tab to clear.
    if renderedTheme == nil or renderedTheme == "kui" then return 23 end
    return 0
end

-- â”€â”€â”€ Resolución de tags de vida â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Tabla display â†’ tag oUF (compartida por player, target, focus, boss).
-- Una sola función ResolveHealthTag reemplaza las antiguas 3 funciones
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
        growthX, growthY, offsetX, offsetY, extraY)
    if not (container and frame) then return end
    local bar, width, auraSize, gap, perRow = KT:ResolveUFAuraBarGeometry(frame)
    container:ClearAllPoints()
    container:SetPoint(initialAnchor, bar, framePoint,
        (offsetX or 0) * gap, (offsetY or 0) * gap + (extraY or 0))
    container:SetSize(width, auraSize)
    container.size = auraSize
    container.spacing = gap
    container.spacingX = gap
    container.spacingY = gap
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

-- Estimate pixel width per content kind (padding included) so the name can leave room for it.
local function EstimateUFTextWidth(content)
    return ns.FrameLayout.TextWidth(content)
end

-- Tint a FontString with the unit's class colour, or white when it has none.
local function ApplyClassColor(fs, unit, useClassColor)
    if not fs then return end
    local r, g, b = 1, 1, 1
    if useClassColor then
        local token = ResolveSafeClassToken(unit)
        local c = token and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[token]
        if c then r, g, b = c.r, c.g, c.b end
    end
    fs:SetTextColor(r, g, b)
end

local UF_ICONS_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"

-- Texture/font visibility is safe during combat; frame geometry is not.
-- KUI Style shows the level only on the portrait (centred on its bottom edge,
-- half over it); without a portrait it has no place for it.
ns.ShowCharacterLevel = function(profile, portraitVisible)
    local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme and KT.VisualThemes:GetRenderedTheme()
    if KT.IS_FOREVER ~= true and (theme == nil or theme == "kui") and not portraitVisible then return false end
    return not profile or profile.showCharacterLevel ~= false
end
ns.IsUnitPortraitVisible = function(frame, u, profile)
    local settings = GetSettingsForUnit(u)
    local portrait = frame and frame.Portrait and frame.Portrait.backdrop
    return (profile and profile.portraitStyle ~= "none" and settings and settings.showPortrait ~= false
        and portrait and portrait:IsShown()) and true or false
end
ns.RefreshLevelBadgeVisibility = function(frame, u, profile, ornament, value, combat)
    if not (frame and frame._kuiLevelText and frame._kuiLevelCircle) then return end
    local exists = type(UnitExists) ~= "function" or ns.SafeCall(UnitExists, u)
    local enabled = exists and ns.ShowCharacterLevel(profile, ns.IsUnitPortraitVisible(frame, u, profile))
    if ornament == nil then
        local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme and KT.VisualThemes:GetRenderedTheme()
        local settings = GetSettingsForUnit(u)
        local portrait = frame.Portrait and frame.Portrait.backdrop
        ornament = (theme == "classic" or theme == "forever" or theme == "retail" or profile and profile.frameArtKit == "classic")
            and profile and profile.portraitStyle ~= "none" and settings and settings.showPortrait ~= false
            and portrait and portrait:IsShown()
    end
    value = enabled and (value or SafeUnitLevelText(u)) or nil
    if combat == nil then
        local theme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme and KT.VisualThemes:GetRenderedTheme()
        combat = enabled and ornament and ns.StockStyleToggle(profile, "levelCombatIcon", theme) and ns.UnitInCombat(u)
    end
    local icon = frame._kuiLevelCombatIcon
    local showIcon = enabled and combat and icon ~= nil
    if icon then icon:SetShown(showIcon and true or false) end
    -- Keep the ornament visible while a newly selected unit's level settles.
    if enabled and (value or ornament) then
        frame._kuiLevelText:SetText(value or "??")
        frame._kuiLevelText:SetShown(not showIcon)
        frame._kuiLevelCircle:SetShown(ornament and true or false)
    else
        frame._kuiLevelText:Hide()
        frame._kuiLevelCircle:Hide()
    end
end
-- Level number colour for the current unit. Colour only (no font or layout),
-- so the in-combat target refresh can run it and the new target does not keep
-- the previous one's difficulty colour.
ns.RefreshLevelTextColor = function(frame, u, profile, renderedTheme)
    local text = frame and frame._kuiLevelText
    if not text then return end
    if renderedTheme == "forever" or renderedTheme == "retail"
        or ns.StockStyleToggle(profile, "levelBlizzardStyle", renderedTheme) then
        local lr, lg, lb = ns.BlizzardLevelColor(u, renderedTheme)
        -- Color Enemy Level by Difficulty off: enemies take Blizzard's plain level colour.
        if profile and profile.levelDifficultyColorKUI == false and ns.LevelDifficultyColor(u) then
            lr, lg, lb = ns.BlizzardLevelColor(nil, renderedTheme)
        end
        text:SetTextColor(lr, lg, lb)
        return
    end
    -- Styles with their own level font (KUI, Classic without Blizzard's level):
    -- enemies take the difficulty colour, everyone else keeps the chosen Level Text Color.
    local r, g, b
    if not (profile and profile.levelDifficultyColorKUI == false) then
        r, g, b = ns.LevelDifficultyColor(u)
    end
    if r then
        text:SetTextColor(r, g, b, 1)
    else
        local colorKey, colorDefault = ns.LevelColorKey()
        local color = profile and profile[colorKey] or colorDefault
        text:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    end
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
    local ok, facing = pcall(Portraits.GetFacing, unit, GetSettingsForUnit(unit))
    return ok and facing or nil
end

function KT.KTDebugFacingState(unit)
    local settings = GetSettingsForUnit(unit)
    local ok1, facing = pcall(Portraits.GetFacing, unit, settings)
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
            .. " resolvedMode=" .. debug.Value(Portraits.ResolveMode(unit, settings))
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


-- Folder of the portrait shape textures (masks and borders).
local PORTRAIT_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"

-- Text slots and class icon of the bottom text bar live in KUI_BottomTextBar.lua (ns.BottomTextBar).
local function CreateBottomTextBar(frame, unit, settings, anchorFrame, xOffset, overrideWidth)
    return ns.BottomTextBar.Create(frameBuildCtx, frame, unit, settings, anchorFrame, xOffset, overrideWidth)
end

-- SetFrameMovable removed — positioning is now handled by Unlock Mode

local function ApplyFramePosition(frame, unit)
    if InCombatLockdown and InCombatLockdown() then
        ns.QueueUnitFrameLayoutRefresh()
        return
    end
    if not frame or not db.profile.positions[unit] then return end
    -- Pending drags belong to Unlock Mode until they are committed.
    local um = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
    if um and um.pendingPositions and um.pendingPositions["unitframes_" .. unit] then return end
    local saved = KT and KT.db and KT.db.profile and KT.db.profile.editMode
    saved = saved and saved.frames and saved.frames["unitframes_" .. unit]
    local pos = saved and saved.point and saved or db.profile.positions[unit]
    frame:ClearAllPoints()

    -- A position may follow another unit frame (relativeTo, Modules/DefaultLayout.lua).
    local relFrame, point, relPoint, x, y = KT:ResolveLayoutAnchor(pos)

    -- Calculate dynamic X position for target frame to prevent CDM overlap
    if not saved and not pos.scale and unit == "target" and pos.point == "CENTER" then
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
    
    -- Saved offsets are expressed at the scale at which they were captured.
    -- Derive the live anchor; never rewrite saved coordinates during rendering.
    local settings = GetSettingsForUnit(unit)
    local currentScale = frame:GetScale()
    local referenceScale = pos.scale or ((settings and settings.frameScale or currentScale * 100) / 100)
    if referenceScale > 0 and currentScale > 0 then
        local ratio = referenceScale / currentScale
        local dx = frame:GetWidth() * (ratio - 1) / 2
        local dy = frame:GetHeight() * (ratio - 1) / 2
        x, y = x * ratio, y * ratio
        if point:find("LEFT") then x = x + dx
        elseif point:find("RIGHT") then x = x - dx end
        if point:find("TOP") then y = y - dy
        elseif point:find("BOTTOM") then y = y + dy end
    end
    frame:SetPoint(point, relFrame, relPoint, x, y)
end

-- Recalculate all element sizes of a unit frame after a scale change: KUI_ScaleFit.lua (ns.ScaleFit).
local function UpdateBordersForScale(frame, unit)
    ns.ScaleFit.Update(frameBuildCtx, frame, unit)
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
    if InCombatLockdown and InCombatLockdown() then
        ns.QueueUnitFrameLayoutRefresh()
        return
    end
    if not frame then return end
    local um = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
    if um and um.pendingPositions and um.pendingPositions["unitframes_" .. unit] then return end
    local oldScale = frame._kuiCurrentScale or frame:GetScale()

    if frame._kuiScaleAnimating then
        frame._kuiCurrentScale = frame:GetScale()
        oldScale = frame._kuiCurrentScale
        frame:SetScript("OnUpdate", frame._kuiPrevOnUpdate)
        frame._kuiScaleAnimating = nil
        frame._kuiPrevOnUpdate = nil
    end

    local function ApplyScaleAndReposition(frm, sc, unitKey)
        if InCombatLockdown and InCombatLockdown() then
            ns.QueueUnitFrameLayoutRefresh()
            return
        end
        local active = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
        if active and active.pendingPositions and active.pendingPositions["unitframes_" .. unitKey] then return end
        frm:SetScale(sc)
        ApplyFramePosition(frm, unitKey)
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
            self._kuiCurrentScale = self:GetScale()
            self:SetScript("OnUpdate", self._kuiPrevOnUpdate)
            self._kuiScaleAnimating = nil
            self._kuiPrevOnUpdate = nil
            UpdateBordersForScale(self, unit)
        end
    end)
end

-- ToggleLock removed — positioning is now handled by Unlock Mode

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
    local pSizeAdj = (settings.portraitSize or 0) + (isAttached and 0 or ns.FrameLayout.DetachedPortraitExtra)

    -- Cálculo común de barH (vida + poder adosado)
    local powerH = powerIsAtt and (settings.powerHeight or 6) or 0
    local barH = settings.healthHeight + powerH

    -- BTB solo afecta unidades principales (no boss)
    local btbPos = settings.btbPosition or "bottom"
    local btbIsAtt = (btbPos == "top" or btbPos == "bottom")
    local btbH = 0
    if unit == "player" or unit == "target" or unit == "focus" then
        btbH = (settings.bottomTextBar and btbIsAtt) and (settings.bottomTextBarHeight or 16) or 0
    end

    -- Ancho: portrait adosado â†’ extender por su tamaño ajustado
    local adjPH = math.max(barH + pSizeAdj, ns.FrameLayout.PortraitMinimum)
    local w = (showPortrait and isAttached) and (adjPH + settings.frameWidth) or settings.frameWidth

    -- Player/target: ajustar lado del retrato
    if unit == "player" or unit == "target" then
        local pSide = settings.portraitSide or (unit == "player" and "left" or "right")
        if isAttached and pSide == "top" then pSide = (unit == "player") and "left" or "right" end
    end

    return w, barH + btbH
end

-- ShowFakeFrames / HideFakeFrames removed — Unlock Mode handles all positioning

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

-- Textura fija del escudo de absorción
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

    -- Registrar como predicción de absorción para oUF
    frame.HealthPrediction = {
        damageAbsorb          = shield,
        damageAbsorbClampMode = 2,
    }
    ApplyAbsorbBarStyle(frame, settings)
    return shield
end

-- Power bar, cast bar remainder and show-on-cast: KUI_PowerCast.lua (ns.PowerCast).

-- â”€â”€â”€ Borders de unit frames: creación separada de apariencia â”€â”€â”€â”€â”€â”€
-- Paso 1: BuildBorderFrame - crea la estructura sin apariencia
-- Paso 2: ApplyBorderAppearance - configura grosor/color desde settings
-- Los hooks de hover comparten resolución de settings vía tabla estática.

-- Detección de mini frames por tabla (sin pattern matching repetido)
local MINI_FRAME_UNITS = {
    pet = true, targettarget = true, focustarget = true,
    boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true,
}

-- Resolver settings de borde según si el frame es mini o principal
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
                if fs.SetParent and ns.FrameWidgets.TextOverlay(frame) then fs:SetParent(ns.FrameWidgets.TextOverlay(frame)) end
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
        SetClassicStatusHidden(ns.FrameWidgets.PowerText(frame.Power), active)

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
        -- Health Text and Text Size still apply: "both" (the default) keeps
        -- Classic's "516/553 (93%)", any other choice uses its own format.
        local settings = db and db.profile and db.profile[unit]
        local display = type(settings) == "table" and settings.healthDisplay or nil
        local hpTag = layout.hp
        if display and display ~= "both" then
            hpTag = display ~= "none" and ContentToTag(display) or nil
        end
        local textFactor = KT.VisualThemes and KT.VisualThemes.GetUnitTextSizeFactor
            and KT.VisualThemes:GetUnitTextSizeFactor(frame, unit) or 1
        local bars = { hp = frame.Health, hpPct = frame.Health, pp = frame.Power, ppPct = frame.Power }
        for key, fs in pairs(texts.fs) do
            local tag = layout[key]
            if key == "hp" then tag = hpTag end
            local bar = bars[key]
            if tag and bar and not (bar.IsShown and not bar:IsShown()) then
                local barH = bar.GetHeight and bar:GetHeight() or 12
                local textSize = math.min(size, barH * CLASSIC_STATUS_TEXT_RATIO)
                if key == "hp" or key == "hpPct" then textSize = textSize * textFactor end
                fs:SetFont(path, math.max(6, textSize), flags)
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
                -- Classic tags are bare names; Health Text choices are full tag strings.
                local fullTag = tag:find("[", 1, true) and tag or ("[" .. tag .. "]")
                if fs._curTag ~= fullTag then
                    if fs._curTag then frame:Untag(fs) end
                    fs._curTag = fullTag
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
    if (unit == "pet" or unit == "targettarget" or unit == "focustarget")
        and VT and VT.ApplyPetFrameArt and VT.ClearPetFrameArt then
        local petKind = classicActive and "classic"
            or ((renderedTheme == "forever" or renderedTheme == "retail") and "forever" or nil)
        local petSettings = GetSettingsForUnit(unit)
        local petScale = (tonumber(petSettings.frameWidth) or 101) / 101
        if petKind and frame.Portrait and frame.Portrait.backdrop and VT:ApplyPetFrameArt(frame, portraitRegion, petKind, { scale = petScale }) then
            if frame.classicBorder and VT.ShowClassicBorder then VT:ShowClassicBorder(frame.classicBorder, false) end
            if frame.unifiedBorder then frame.unifiedBorder:Hide() end
            KT:ApplyStockUFHealthTextGeometry(frame, unit)
            ns.ApplyClassicStatusText(frame, unit, petKind == "classic")
            if unit ~= "pet" then
                -- ToT / Focus Target only show mana and portrait inside the stock box.
                if frame.Power then frame.Power:Show() end
                if frame._ktSimpleStyled and frame.IsElementEnabled and not frame:IsElementEnabled("Portrait")
                    and Portraits.ResolveMode(unit, petSettings) ~= "class" then
                    frame:EnableElement("Portrait")
                    if frame.Portrait.ForceUpdate then frame.Portrait:ForceUpdate() end
                end
            end
            return
        end
        if frame._ktPetSaved then
            VT:ClearPetFrameArt(frame)
            if frame.Power and petSettings.powerHeight then PP.Height(frame.Power, petSettings.powerHeight) end
            ns.FrameWidgets.PositionText(frame, petSettings)
        end
        if unit ~= "pet" then
            -- KUI Style: ToT / Focus Target stay a single health bar.
            if frame.Power then frame.Power:Hide() end
            if frame.Portrait and frame.Portrait.backdrop then frame.Portrait.backdrop:Hide() end
        end
    end

    local artUnit = unit == "focus" and "target" or unit
    local usingClassicRealArt = false
    if VT and VT.ApplyClassicUnitFrameArt and VT.ClearClassicUnitFrameArt then
        if classicActive then
            usingClassicRealArt = VT:ApplyClassicUnitFrameArt(frame, portraitRegion, artUnit) and true or false
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
            usingForeverRealArt = VT:ApplyForeverUnitFrameArt(frame, portraitRegion, artUnit) and true or false
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

-- Función compuesta: mantiene la firma original para los 5 call sites
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
        
        -- Only the player frame ever paints this border; every other frame just
        -- clears it. A plain RegisterEvent sent each frame every unit's auras.
        if frame.unit == "player" then
            f:RegisterUnitEvent("UNIT_AURA", "player")
        end
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
    -- Every style seats the castbar under the frame (stock looks under Power,
    -- KUI Style under Power or the text bar), so the row goes under the
    -- castbar: a fixed castbarHeight offset from Health lands it on the castbar.
    local castBg = frame.Castbar and frame.Castbar:GetParent()
    if cbOffset ~= 0 and castBg then
        container:SetPoint(dia, castBg, dfp, dox * gap, doy * gap - 2)
    else
        container:SetPoint(dia, bar, dfp, dox * gap, doy * gap + cbOffset)
    end

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
            bgx, bgy, box, boy + buffOffset, nil,
            KT:GetKUIStyleBuffYOffset(frame.unit or "target", buffAnchor))
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
    buffs:SetPoint(bia, auraAnchor, bfp, box * gap,
        boy * gap + buffCbOff + KT:GetKUIStyleBuffYOffset(unit or "target", bAnc))
    buffs:SetSize(containerWidth, auraSize)
    buffs.size = auraSize
    buffs.spacing = gap
    buffs.spacingX = gap
    buffs.spacingY = gap
    buffs.num = (settings and settings.maxBuffs) or 20
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
            stackFontSize = 8, stackX = 1, stackY = -1, durationFontSize = 7, durationPoint = "CENTER", durationRelPoint = "CENTER", durationY = 0,
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

        SyncTargetAuraContainer(frame, unit)
    else
        local debuffs = CreateFrame("Frame", nil, frame)
        debuffs:SetPoint(dia, auraAnchor, dfp, dox * gap, doy * gap + debuffCbOff)
        debuffs:SetSize(containerWidth, auraSize)
        debuffs.size = auraSize
        debuffs.spacing = gap
        debuffs.spacingX = gap
        debuffs.spacingY = gap
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
    ns.InstallTargetAuraSync(frame, unit, SyncTargetAuraContainer, GetSettingsForUnit)
end

-- â”€â”€â”€ Fábrica de posicionamiento de texto â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Genera un closure ApplyTextPositions parametrizado por modo:
--   fullMode=true  â†’ PP.Point, SetFSFont, offsets XY, class color
--                     (player, target, focus — barras con textOverlay)
--   fullMode=false â†’ SetPoint directo, sin fuente/offset/color
--                     (simple, pet, boss — barras compactas)
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
            local lsz, rsz, csz, lxo, lyo, rxo, ryo, cxo, cyo = FrameBuild.TextSlotMetrics(s)
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
--  Status indicators shared by every unit frame: leader, assistant,
--  resurrect, summon, raid target, and the AFK/dead/ghost/offline overlay.
--  The icons come from KUI_ICON_PATH.
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

    -- Only textures are touched here (nothing protected), so it also runs in
    -- combat: otherwise a PvP badge from the previous target stays on a mob.
    local function RefreshPvPIcon(u, profile, renderedTheme)
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
    end

    -- A target change in combat skips the full pass below (it moves protected
    -- frames), which left the previous target's Rare/Elite ring on the new
    -- one. This keeps the ring in step using textures only; the full pass
    -- after combat redoes the geometry.
    local function RefreshClassificationInCombat(u, profile, renderedTheme)
        if u == "player" then return end
        local settings = GetSettingsForUnit(u)
        local portraitBackdrop = frame.Portrait and frame.Portrait.backdrop
        local portraitVisible = profile and profile.portraitStyle ~= "none"
            and settings and settings.showPortrait ~= false
            and portraitBackdrop and portraitBackdrop:IsShown() or false
        local classicKit = profile and profile.frameArtKit == "classic"
        local showClassification = not profile or profile.showClassification ~= false
        local classification = showClassification and SafeUnitClassification(u) or nil
        local nativeKind
        if portraitVisible and u == "target" and showClassification and profile
            and (profile.targetClassificationArt == "native"
                or (renderedTheme == "retail" and (profile.targetClassificationArt == nil
                    or profile.targetClassificationArt == "auto"))) then
            nativeKind = ns.NativeClassificationKind(classification)
            if nativeKind and not ns.HasNativeClassificationArt(nativeKind) then nativeKind = nil end
        end
        local classicKind
        if (renderedTheme == "classic" or classicKit) and u == "target" then
            classicKind = showClassification and not nativeKind
                and ns.ClassicRing.KindForClassification(classification) or nil
            frame._ktClassicSheetPath = classicKind and ns.ClassicRing.sheets[classicKind] or nil
            if frame._ktClassicPortraitArt then
                frame._ktClassicPortraitArt:SetTexture(frame._ktClassicSheetPath or ns.ClassicRing.base)
            end
        end
        local texture
        if showClassification and not nativeKind and not classicKind then
            texture = portraitVisible and SafeUnitClassificationTexture(u)
                or SafeUnitClassificationNoPortraitTexture(u, profile)
        end
        local portraitRing = frame._kuiClassificationPortraitRing
        local indicator = frame._kuiClassificationIndicator
        local flipped = texture and GetClassificationTextureFlipped(u, settings)
        local active = false
        -- Only reuse a ring that a previous full pass already placed.
        if texture and portraitVisible and portraitRing and portraitRing:GetNumPoints() > 0 then
            portraitRing:SetTexture(texture)
            portraitRing:SetTexCoord(flipped and 1 or 0, flipped and 0 or 1, 0, 1)
            portraitRing:Show()
            if indicator then indicator:Hide() end
            active = true
        elseif texture and not portraitVisible and indicator then
            if portraitRing then portraitRing:Hide() end
            indicator:SetTexture(texture)
            indicator:SetTexCoord(flipped and 1 or 0, flipped and 0 or 1, 0, 1)
            indicator:Show()
        else
            if portraitRing then portraitRing:Hide() end
            if indicator then indicator:Hide() end
        end
        local stockSide = renderedTheme == "forever" or renderedTheme == "retail"
            or renderedTheme == "classic" or classicKit
        local side = stockSide and ((u == "target") and "right" or "left")
            or (settings and settings.portraitSide) or "right"
        if ns.ShowNativeClassificationRing(frame, portraitBackdrop, nativeKind, side == "left", iOvr) then
            active = true
        end
        frame._kuiClassificationPortraitActive = active
    end

    local function RefreshForeverMetadata()
        local themes = KT.VisualThemes
        if themes and themes.UpdateUnitFrameNameReaction then
            themes:UpdateUnitFrameNameReaction(frame, frame.unit or unit)
        end
        -- This pass adjusts protected geometry. PLAYER_REGEN_ENABLED below
        -- refreshes it using the current unit and settings after combat.
        if InCombatLockdown() then
            local cu, cp = frame.unit or unit, db and db.profile
            local ct = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
                and KT.VisualThemes:GetRenderedTheme()
            RefreshPvPIcon(cu, cp, ct)
            RefreshClassificationInCombat(cu, cp, ct)
            ns.RefreshLevelTextColor(frame, cu, cp, ct)
            ns.RefreshLevelBadgeVisibility(frame, cu, cp)
            return
        end
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
        ns.RefreshRaidTargetAnchor(frame)
        local portraitRing = frame._kuiClassificationPortraitRing
        if portraitBackdrop and not portraitRing then
            -- Keep the normal portrait border and render classification outside it.
            portraitRing = iOvr:CreateTexture(nil, "OVERLAY", nil, 7)
            portraitRing:SetTexCoord(0, 1, 0, 1)
            portraitRing:Hide()
            frame._kuiClassificationPortraitRing = portraitRing
        end
        -- KUI Style shows the level only on the portrait; the stock-art
        -- styles (Classic/Forever/Retail) always have their level ring.
        local levelTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
            and KT.VisualThemes:GetRenderedTheme() or "kui"
        local showLevel = ns.ShowCharacterLevel(profile, portraitVisible)
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
            local levelTextXNudge = (renderedTheme == "classic" and 0 or 1) * classicScale
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
            -- KUI Style: the number sits centred on the portrait's bottom edge,
            -- half over the portrait. A custom
            -- Level Anchor still wins.
            if levelTheme == "kui" and portraitVisible and not OVERLAY_ANCHORS[levelAnchor] then
                frame._kuiLevelText:ClearAllPoints()
                frame._kuiLevelText:SetPoint("CENTER", portraitBackdrop, "BOTTOM", 0, 4)
                frame._kuiLevelText:SetJustifyH("CENTER")
            end
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
        end
        ns.RefreshLevelTextColor(frame, u, profile, renderedTheme)
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
        ns.RefreshLevelBadgeVisibility(frame, u, profile, usingClassicLevelOrnament, levelText, showCombatIcon)
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
                and (profile.targetClassificationArt == "native"
                    -- Retail's own style default is Blizzard's Rare/Elite overlay;
                    -- the other styles keep their rings unless "native" is chosen.
                    or (renderedTheme == "retail" and (profile.targetClassificationArt == nil
                        or profile.targetClassificationArt == "auto"))) then
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
            Portraits.ApplyShape(portraitBackdrop, settings, u)
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
        RefreshPvPIcon(u, profile, renderedTheme)
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
                Portraits.ApplyShape(portraitBackdrop, settings, u)
            else
                Portraits.UpdateCircularBorder(frame)
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

    -- â”€â”€ Raid Target (marcas estándar de Blizzard, no icono custom) â”€â”€
    if not frame.RaidTargetIndicator then
        -- Own host frame: sharing iOvr or the level overlay left it under the
        -- portrait rings and the combo points (see ns.RaiseRaidTargetHost).
        local host = CreateFrame("Frame", nil, iOvr)
        host:SetAllPoints(iOvr)
        host:EnableMouse(false)
        frame._kuiRaidTargetHost = host
        local tex = host:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        tex:SetSize(18, 18)
        -- Mirror the combat indicator below the bar. This keeps the raid marker
        -- away from the resting/status icons that occupy the upper-left corner.
        tex:SetPoint("TOP", health, "BOTTOM", 0, -2)
        tex:Hide()
        tex.PostUpdate = function() ns.RefreshRaidTargetAnchor(frame) end
        frame.RaidTargetIndicator = tex
    end
    ns.RaiseRaidTargetHost(frame)

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
            -- The unit behind target/focus/tot frames changes without any of the
            -- events above firing, which left a friendly's AFK badge stuck on
            -- the frame after switching to an NPC.
            "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGET",
            "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD",
        }
        for _, ev in ipairs(evts) do
            frame:RegisterEvent(ev, function()
                RefreshStatusOverlay()
            end, true)
        end
        frame:HookScript("OnShow", function() RefreshStatusOverlay() end)
    end
    RefreshStatusOverlay()
end

-- Unit frame layout kit: geometry and widget helpers shared by the oUF style
-- builders and by ReloadFrames. They run only while frames are built or
-- re-laid out, never from event callbacks, so nothing here sits on a combat path.
do
    local Kit = {}
    ns.UnitFrameKit = Kit

    -- Detached bars float 15px clear of their host: { own point, host point, y pad }.
    local DETACHED_AT = {
        detached_top    = { "BOTTOM", "TOP", ns.FrameLayout.DetachedGap },
        detached_bottom = { "TOP", "BOTTOM", -ns.FrameLayout.DetachedGap },
    }
    -- Stacked power bar: own edge / health edge it touches.
    local STACKED_AT = {
        above = { "BOTTOM", "TOP" },
        below = { "TOP", "BOTTOM" },
    }

    -- Height the modern class-power row steals above the health bar.
    Kit.ClassPowerRise = ns.ClassPowerBar.Rise

    -- Height of a power bar that is stacked with the health bar (0 when detached/hidden).
    function Kit.PowerStack(settings, fallback)
        local where = settings.powerPosition or "below"
        if where == "below" or where == "above" then
            return settings.powerHeight or fallback or 0
        end
        return 0
    end

    -- Same bar, but only when it sits above the health bar.
    function Kit.PowerAbove(settings, fallback)
        if (settings.powerPosition or "below") == "above" then
            return settings.powerHeight or fallback or 0
        end
        return 0
    end

    -- Height the bottom text bar adds to the frame when docked on either edge.
    function Kit.BtbExtra(settings)
        local where = settings.btbPosition or "bottom"
        if settings.bottomTextBar and (where == "top" or where == "bottom") then
            return settings.bottomTextBarHeight or 16
        end
        return 0
    end

    -- How far the bars sit below the frame top when the text bar is docked above them.
    function Kit.BtbTopRise(settings)
        if settings.bottomTextBar and (settings.btbPosition or "bottom") == "top" then
            return settings.bottomTextBarHeight or 16
        end
        return 0
    end

    -- Anchor the health bar and record the offsets other code reads back.
    function Kit.AnchorHealth(frame, settings, left, right, top)
        local health = frame.Health
        ns.FrameWidgets.HealthInsets(health).left = left
        ns.FrameWidgets.HealthInsets(health).right = right
        ns.FrameWidgets.HealthInsets(health).top = top
        PP.Point(health, "TOPLEFT", frame, "TOPLEFT", left, -top)
        PP.Point(health, "RIGHT", frame, "RIGHT", -right, 0)
        PP.Height(health, settings.healthHeight)
    end

    -- Portrait code lives in KUI_Portraits.lua (ns.Portraits). Its context is built once here; db is
    -- (re)bound by Mod:BindDatabase, which also calls Portraits.Init.
    portraitsCtx = {
        client = "retail",
        KT = KT,
        PP = PP,
        UnitToSettingsKey = UnitToSettingsKey,
        GetSettingsForUnit = GetSettingsForUnit,
        ResolveSafeClassToken = ResolveSafeClassToken,
        AnchorHealth = Kit.AnchorHealth,
    }
    -- Installs the portrait seating functions (PortraitState, PortraitFit, DockShift, AttachPortrait,
    -- CanSeat, SnapInsets, SeatHealth, SeatPortrait, PortraitContext) on the kit.
    Portraits.InstallKit(Kit)

    -- Pin a stacked power bar flush above or below the health bar (both edges).
    function Kit.StackPower(bar, health, where)
        local edge = STACKED_AT[where] or STACKED_AT.below
        PP.Point(bar, edge[1] .. "LEFT", health, edge[2] .. "LEFT", 0, 0)
        PP.Point(bar, edge[1] .. "RIGHT", health, edge[2] .. "RIGHT", 0, 0)
    end

    -- Late login updates can re-anchor power bars; pin a stacked bar's edges again.
    function Kit.ReseatStacked(frame, settings)
        local where = settings.powerPosition or "below"
        if where == "below" or where == "above" then
            frame.Power:ClearAllPoints()
            Kit.StackPower(frame.Power, frame.Health, where)
        end
    end

    -- Size, anchor and show the power bar for its configured position.
    function Kit.PlacePower(frame, settings, where, fallback, rawSize)
        local bar, health = frame.Power, frame.Health
        local width = settings.frameWidth
        if (where == "detached_top" or where == "detached_bottom") and (settings.powerWidth or 0) > 0 then
            width = settings.powerWidth
        end
        local height = settings.powerHeight
        if fallback then height = height or fallback end
        if rawSize then bar:SetSize(width, height) else PP.Size(bar, width, height) end
        bar:ClearAllPoints()
        if where == "none" then
            bar:Hide()
        else
            local loose = DETACHED_AT[where]
            if loose then
                bar:SetPoint(loose[1], health, loose[2], settings.powerX or 0, loose[3] + (settings.powerY or 0))
            else
                Kit.StackPower(bar, health, where)
            end
            bar:Show()
        end
        ns.FrameWidgets.RefreshPowerText(bar, settings)
    end

    -- Grey the power bar background for ordinary hostile NPCs (not bosses, rare
    -- elites, level-capped elites or paladin-type casters).
    function Kit.DimPowerBackdrop(frame, unit, where)
        ns.FrameLayout.ApplyPowerBackdrop(frame, unit, where)
    end

    -- Create, resize and re-skin the bottom text bar for a unit.
    function Kit.SyncBottomBar(frame, unit, settings, anchor, totalWidth, dockShift)
        if not settings.bottomTextBar then
            if frame.BottomTextBar then frame.BottomTextBar:Hide() end
            return
        end
        local where = settings.btbPosition or "bottom"
        local docked = (where == "top" or where == "bottom")
        local width = totalWidth
        if not docked and (settings.btbWidth or 0) > 0 then width = settings.btbWidth end
        local shift = docked and dockShift or 0
        if not frame.BottomTextBar then
            frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, anchor, shift, totalWidth)

            return
        end
        local bar = frame.BottomTextBar
        PP.Size(bar, width, settings.bottomTextBarHeight or 16)
        bar:ClearAllPoints()
        local loose = DETACHED_AT[where]
        if loose then
            bar:SetPoint(loose[1], frame, loose[2], settings.btbX or 0, loose[3] + (settings.btbY or 0))
        elseif where == "top" then
            PP.Point(bar, "BOTTOMLEFT", frame.Health or frame, "TOPLEFT", shift, 0)
        else
            PP.Point(bar, "TOPLEFT", anchor, "BOTTOMLEFT", shift, 0)
        end
        if bar.bg then
            local c = settings.btbBgColor or { r = 0.2, g = 0.2, b = 0.2 }
            bar.bg:SetColorTexture(c.r, c.g, c.b, settings.btbBgOpacity or 1.0)
        end
        ns.FrameWidgets.RefreshTextBar(bar, settings)
        bar:Show()
    end

    -- Cast bar spell-name / duration fonts and colours, then the themed look.
    function Kit.SkinCastTexts(frame, settings)
        local cast = frame.Castbar
        local white = { r = 1, g = 1, b = 1 }
        if cast.Text then
            SetFSFont(cast.Text, settings.castSpellNameSize or 11)
            local c = settings.castSpellNameColor or white
            cast.Text:SetTextColor(c.r, c.g, c.b)
        end
        if cast.Time then
            SetFSFont(cast.Time, settings.castDurationSize or 11)
            local c = settings.castDurationColor or white
            cast.Time:SetTextColor(c.r, c.g, c.b)
        end
        ns.ApplyClassicCastbarLook(frame)
    end

    -- Frame that carries the unit's texts above the status bar.
    function Kit.TextOverlay(frame, parent, clip)
        local overlay = CreateFrame("Frame", nil, parent)
        overlay:SetAllPoints(parent)
        if clip and overlay.SetClipsChildren then
            overlay:SetClipsChildren(true)
        end
        overlay:SetFrameLevel(parent:GetFrameLevel() + 12)
        ns.FrameWidgets.TextOverlay(frame, overlay)
        return overlay
    end

    -- Left / right / centre FontStrings; sizes = { left, right, center }.
    function Kit.TextSlots(frame, overlay, sizes, strict)
        local made = {}
        for i, key in ipairs({ "LeftText", "RightText", "CenterText" }) do
            local fs = overlay:CreateFontString(nil, "OVERLAY")
            SetFSFont(fs, sizes[i])
            fs:SetWordWrap(false)
            if strict then
                if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
                if fs.SetMaxLines then fs:SetMaxLines(1) end
            end
            fs:SetTextColor(1, 1, 1)
            frame[key] = fs
            made[i] = fs
        end
        frame.NameText = made[1]
        frame.HealthValue = made[2]
        return made[1], made[2], made[3]
    end

    -- Returns the function that (re)binds oUF tags for the three text slots.
    function Kit.TagBinder(frame, left, right, center)
        local slots = { left, right, center }
        return function(leftContent, rightContent, centerContent)
            local contents = { leftContent, rightContent, centerContent }
            for i = 1, 3 do
                local fs = slots[i]
                if fs._curTag then frame:Untag(fs); fs._curTag = nil end
                local tag = ContentToTag(contents[i])
                if tag then frame:Tag(fs, tag); fs._curTag = tag end
            end
            if frame.UpdateTags then frame:UpdateTags() end
        end
    end

    -- Turn an oUF element on or off, touching it only when its state differs.
    function Kit.SwitchElement(frame, name, on)
        local enabled = frame:IsElementEnabled(name)
        if on and not enabled then
            frame:EnableElement(name)
        elseif enabled and not on then
            frame:DisableElement(name)
        end
    end

    -- Opacity used to be saved as 0-1; the current scale is 0-100.
    local OPACITY_KEYS = { "healthBarOpacity", "powerBarOpacity" }
    function Kit.PromoteOpacity(holder)
        for _, key in ipairs(OPACITY_KEYS) do
            local value = holder[key]
            if value and value <= 1.0 then
                holder[key] = math.floor(value * 100 + 0.5)
            end
        end
    end

    -- Re-run the tag binder and the text positioner stored on a frame.
    function Kit.RefreshTexts(frame, settings, rightDefault)
        ns.FrameWidgets.RefreshText(frame, settings, rightDefault)
    end

    -- Text slots that follow the per-slot size settings: { frame field, size key }.
    Kit.FONT_SLOTS = {
        { "NameText", "leftTextSize" },
        { "HealthValue", "rightTextSize" },
        { "CenterText", "centerTextSize" },
    }

    -- Power bar opacity, fill colour mode and background colour from the settings.
    function Kit.RefreshPowerFill(frame, unit, settings)
        local bar = frame.Power
        ApplyPowerBarAlpha(bar, UnitToSettingsKey(unit))

        if settings.powerPercentPowerColor ~= false then
            bar.colorPower = true
            bar.PostUpdateColor = nil
        else
            local customFill = settings.customPowerFillColor
            bar.colorPower = false
            if customFill then
                bar:SetStatusBarColor(customFill.r, customFill.g, customFill.b)
                bar.PostUpdateColor = function(self)
                    local s2 = GetSettingsForUnit(unit)
                    local cf = s2 and s2.customPowerFillColor
                    if cf then self:SetStatusBarColor(cf.r, cf.g, cf.b) end
                end
            else
                bar:SetStatusBarColor(0, 0, 1)
                bar.PostUpdateColor = function(self)
                    self:SetStatusBarColor(0, 0, 1)
                end
            end
        end
        if bar.bg then
            local bgc = settings.customPowerBgColor
            if bgc then
                bar.bg:SetColorTexture(bgc.r, bgc.g, bgc.b, 1)
            else
                bar.bg:SetColorTexture(17/255, 17/255, 17/255, 1)
            end
        end
        if bar.ForceUpdate then bar:ForceUpdate() end
    end

    -- Settings key of a frame (all boss frames share one).
    function Kit.FrameKey(unit)
        return unit:match("^boss%d$") and "boss" or unit
    end

    -- Walk the unit frames in the same order as pairs(), skipping internal "_" entries.
    local function NextUnit(frames, key)
        local value
        repeat
            key, value = next(frames, key)
        until key == nil or (type(key) == "string" and key:sub(1, 1) ~= "_")
        return key, value
    end
    function Kit.EachUnit(frames)
        return NextUnit, frames, nil
    end

    -- Hide a cast bar for good: drop the oUF element and both frames.
    function Kit.HideCastbar(frame, castbarBg)
        Kit.SwitchElement(frame, "Castbar", false)
        frame.Castbar:Hide()
        if castbarBg then castbarBg:Hide() end
    end

    -- Colour, opacity and fonts of a visible cast bar; its settings are kept for PostCastStart.
    function Kit.SkinCastbar(frame, unit, settings, opacity)
        frame.Castbar._ktCastSettings = settings
        local fill = ResolveCastbarFillColor(unit, settings)
        frame.Castbar:SetStatusBarColor(fill.r, fill.g, fill.b, opacity)
        Kit.SkinCastTexts(frame, settings)
    end

    -- Edges for `count` pips that have to fill `width` exactly (see KUI_ClassPowerBar.lua).
    Kit.PipSpans = ns.ClassPowerBar.PipSpans

    -- Flat health bar used by the mini frames (pet, target of target, focus target).
    function Kit.MiniHealthBar(frame, unit, settings, xOffset)
        return FrameBuild.MiniHealthBar(frameBuildCtx, frame, unit, settings, xOffset)
    end
end

local FrameStyles = {}

function FrameStyles.compact(frame, unit)
    local Kit = ns.UnitFrameKit
    local settings = GetSettingsForUnit(unit)
    local health = FrameBuild.SimpleBars(frameBuildCtx, frame, unit, settings)
    frame.Portrait = Portraits.Create(frame, "left", settings.healthHeight, unit)
    frame._portraitSide = "left"
    if frame.Portrait and frame.Portrait.backdrop then frame.Portrait.backdrop:Hide() end
    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    local textOverlay = Kit.TextOverlay(frame, health)
    local size = settings.textSize or 12
    local leftText, rightText, centerText = Kit.TextSlots(frame, textOverlay, { size, size, size })

    local ApplyTextTags = Kit.TagBinder(frame, leftText, rightText, centerText)
    ApplyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "none",
        settings.centerTextContent or "none")
    ns.FrameWidgets.BindText(frame, ApplyTextTags, nil)

    -- Text positions come from the factory shared with the compact style
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, health,
        {"name", "none", "none"}, false)
    ApplyTextPositions(settings)
    ns.FrameWidgets.BindText(frame, nil, ApplyTextPositions)

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
    -- Texts now exist: seat the theme art (Classic/Forever/Retail).
    ApplyClassicFrameArt(frame, unit)
    frame._ktSimpleStyled = true
end


function FrameStyles.pet(frame, unit)
    local Kit = ns.UnitFrameKit
    local settings = GetSettingsForUnit(unit)
    local health, showPortrait = FrameBuild.PetBars(frameBuildCtx, frame, unit, settings)

    Kit.AttachPortrait(frame, "left", settings.healthHeight, unit, showPortrait)
    if Kit.CanSeat(frame, showPortrait, true) then
        Kit.SeatHealth(frame, settings, "left", 0)
    end

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    local textOverlay = Kit.TextOverlay(frame, health)
    local size = settings.textSize or 12
    local leftText, rightText, centerText = Kit.TextSlots(frame, textOverlay, { size, size, size })

    local ApplyTextTags = Kit.TagBinder(frame, leftText, rightText, centerText)
    ApplyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "none",
        settings.centerTextContent or "none")
    ns.FrameWidgets.BindText(frame, ApplyTextTags, nil)

    -- Text positions come from the factory shared with the compact style
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, health,
        {"name", "none", "none"}, false)
    ApplyTextPositions(settings)
    ns.FrameWidgets.BindText(frame, nil, ApplyTextPositions)

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
    -- Texts now exist: seat the theme art (Classic/Forever/Retail) on the pet.
    ApplyClassicFrameArt(frame, unit)
end


function FrameStyles.boss(frame, unit)
    local Kit = ns.UnitFrameKit
    local settings = GetSettingsForUnit(unit)
    local bossBarHeight = settings.healthHeight + Kit.PowerStack(settings, 6)
    local showPortrait = Kit.PortraitState(settings)
    local totalWidth = settings.frameWidth
    if showPortrait then
        totalWidth = bossBarHeight + settings.frameWidth
    end

    FrameBuild.FullBars(frameBuildCtx, frame, unit, settings, totalWidth, bossBarHeight,
        0, showPortrait and bossBarHeight or 0, false)
    Kit.AttachPortrait(frame, "right", bossBarHeight, unit, showPortrait)
    if Kit.CanSeat(frame, showPortrait, true) then
        Kit.SeatHealth(frame, settings, "right", Kit.PowerAbove(settings, 6))
    end

    PP.Size(frame, totalWidth, bossBarHeight)

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    local textOverlay = Kit.TextOverlay(frame, frame.Health, true)
    local size = settings.textSize or 12
    local leftText, rightText, centerText = Kit.TextSlots(frame, textOverlay, { size, size, size }, true)

    local ApplyTextTags = Kit.TagBinder(frame, leftText, rightText, centerText)
    ApplyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "perhp",
        settings.centerTextContent or "none")
    ns.FrameWidgets.BindText(frame, ApplyTextTags, nil)

    -- Text positions come from the factory shared with the compact style
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, frame.Health,
        {"name", "perhp", "none"}, false)
    ApplyTextPositions(settings)
    ns.FrameWidgets.BindText(frame, nil, ApplyTextPositions)

    -- Indicadores comunes a todas las unidades
    SetupUnitIndicators(frame, unit)
end


function FrameStyles.full(frame, unit)
    local Kit = ns.UnitFrameKit
    local settings = GetSettingsForUnit(unit)
    local powerPos = settings.powerPosition or "below"
    local powerIsAtt = (powerPos == "below" or powerPos == "above")
    local playerTargetHeight = settings.healthHeight + Kit.PowerStack(settings)
    local btbExtra = Kit.BtbExtra(settings)
    local totalWidth
    local showPortrait, isAttached = Kit.PortraitState(settings)

    if unit == "player" then
        local pSide = settings.portraitSide or "left"
        local cpAboveH = Kit.ClassPowerRise(settings)
        local playerHeightWithCp = playerTargetHeight + cpAboveH
        local effectiveSide, _, width, healthXOffset, healthRightInset =
            Kit.PortraitFit(settings, showPortrait, isAttached, playerHeightWithCp, "left")
        totalWidth = width
        -- The absorb bar always exists; the oUF element is switched off later when unwanted
        FrameBuild.FullBars(frameBuildCtx, frame, unit, settings, totalWidth, playerHeightWithCp + btbExtra,
            healthXOffset, healthRightInset, true)
        -- The portrait always exists too; only its backdrop is hidden when disabled
        Kit.AttachPortrait(frame, pSide, playerHeightWithCp, unit, showPortrait)
        ApplyClassicFrameArt(frame, unit)
        if Kit.CanSeat(frame, showPortrait, isAttached) then
            Kit.SeatHealth(frame, settings, effectiveSide, cpAboveH + Kit.PowerAbove(settings))
        end

        -- The cast bar always exists; the oUF element is switched off later when the profile does not want it
        frame.Castbar = ns.PowerCast.CastBar(frameBuildCtx, frame, unit)
        ns.PowerCast.ShowOnCast(frameBuildCtx, frame, "player")

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
                boy * gap + buffCbOffset + KT:GetKUIStyleBuffYOffset("player", settings.buffAnchor or "topleft"))
            buffs:SetSize(auraWidth, auraSize)
            buffs.size = auraSize
            buffs.spacing = gap
            buffs.spacingX = gap
            buffs.spacingY = gap
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
                    boy2 + liveOffset + KT:GetKUIStyleBuffYOffset("player", current.buffAnchor or "topleft"))
                if frame.Buffs.ForceUpdate then frame.Buffs:ForceUpdate() end
            end
            CreateUnitDispelSlots(frame, unit)
        end
    elseif unit == "target" then
        local pSide = settings.portraitSide or "right"
        local effectiveSide, _, width, healthXOffset, healthRightInset =
            Kit.PortraitFit(settings, showPortrait, isAttached, playerTargetHeight, "right")
        totalWidth = width
        FrameBuild.FullBars(frameBuildCtx, frame, unit, settings, totalWidth, playerTargetHeight + btbExtra,
            healthXOffset, healthRightInset, true)
        frame.Castbar = ns.PowerCast.CastBar(frameBuildCtx, frame, unit)
        ns.PowerCast.ShowOnCast(frameBuildCtx, frame, unit)
        Kit.AttachPortrait(frame, pSide, playerTargetHeight, unit, showPortrait)
        ApplyClassicFrameArt(frame, unit)
        if Kit.CanSeat(frame, showPortrait, isAttached) then
            Kit.SeatHealth(frame, settings, effectiveSide, Kit.PowerAbove(settings))
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

    -- Text layer
    local textOverlay = Kit.TextOverlay(frame, frame.Health, true)
    local fallbackSize = settings.textSize or 12
    local leftText, rightText, centerText = Kit.TextSlots(frame, textOverlay, {
        settings.leftTextSize or fallbackSize,
        settings.rightTextSize or fallbackSize,
        settings.centerTextSize or fallbackSize,
    }, true)

    local ApplyTextTags = Kit.TagBinder(frame, leftText, rightText, centerText)
    ApplyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "both",
        settings.centerTextContent or "none")
    ns.FrameWidgets.BindText(frame, ApplyTextTags, nil)

    -- Text positions come from the factory shared with the compact style
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, textOverlay,
        {"name", "both", "none"}, true)
    ApplyTextPositions(settings)
    ns.FrameWidgets.BindText(frame, nil, ApplyTextPositions)

    -- Bottom text bar
    if settings.bottomTextBar then
        local anchorFrame = (powerIsAtt and frame.Power) or frame.Health
        local btbPos = settings.btbPosition or "bottom"
        -- It spans the whole frame, so a docked left portrait pushes it left
        local btbXOff = 0
        if (btbPos == "top" or btbPos == "bottom") and showPortrait and isAttached then
            local barH = settings.healthHeight + Kit.PowerStack(settings, 6)
            local side, edge = Kit.PortraitFit(settings, true, true, barH, unit == "player" and "left" or "right")
            btbXOff = Kit.DockShift(true, true, side, edge)
        end
        frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, anchorFrame, btbXOff, totalWidth)

        -- Hang the cast bar from the text bar only when that sits underneath
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
        elseif pos == "textbar" and frame.BottomTextBar then
            anchor = frame.BottomTextBar
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


function FrameStyles.focus(frame, unit)
    local Kit = ns.UnitFrameKit
    local settings = GetSettingsForUnit(unit)
    local stackHeight = settings.healthHeight + Kit.PowerStack(settings, 6)
    local initialHeight = stackHeight + Kit.BtbExtra(settings) + (settings.castbarHeight or 14)
    local showPortrait, isAttached = Kit.PortraitState(settings)
    local portraitSide = settings.portraitSide or "right"
    local layout = ns.FrameLayout.Portrait(settings, showPortrait, isAttached, stackHeight, "right")

    FrameBuild.FullBars(frameBuildCtx, frame, unit, settings, layout.width, initialHeight,
        layout.left, layout.right, false)
    frame.Castbar = ns.PowerCast.CastBar(frameBuildCtx, frame, unit)
    Kit.AttachPortrait(frame, portraitSide, stackHeight, unit, showPortrait)
    if Kit.CanSeat(frame, showPortrait, isAttached) then
        Kit.SeatHealth(frame, settings, layout.side, Kit.PowerAbove(settings, 6))
    end

    PP.Size(frame, layout.width, stackHeight)

    ns.PowerCast.ShowOnCast(frameBuildCtx, frame, "focus")

    CreateUnifiedBorder(frame, unit)
    UpdateBordersForScale(frame, unit)

    -- Text layer
    local textOverlay = Kit.TextOverlay(frame, frame.Health, true)
    local fallbackSize = settings.textSize or 12
    local leftText, rightText, centerText = Kit.TextSlots(frame, textOverlay, {
        settings.leftTextSize or fallbackSize,
        settings.rightTextSize or fallbackSize,
        settings.centerTextSize or fallbackSize,
    })

    local ApplyTextTags = Kit.TagBinder(frame, leftText, rightText, centerText)
    ApplyTextTags(settings.leftTextContent or "name", settings.rightTextContent or "perhp",
        settings.centerTextContent or "none")
    ns.FrameWidgets.BindText(frame, ApplyTextTags, nil)

    -- Text positions come from the factory shared with the full style
    local ApplyTextPositions = BuildTextPositioner(
        leftText, rightText, centerText, unit, textOverlay,
        {"name", "perhp", "none"}, true)
    ApplyTextPositions(settings)
    ns.FrameWidgets.BindText(frame, nil, ApplyTextPositions)

    -- Bottom text bar
    if settings.bottomTextBar then
        local anchorFrame = ns.FrameLayout.BarAnchor(frame, (settings.powerPosition or "below") == "below" or settings.powerPosition == "above")
        local btbPos = settings.btbPosition or "bottom"
        local btbXOff = 0
        if btbPos == "top" or btbPos == "bottom" then
            btbXOff = Kit.DockShift(showPortrait, isAttached, layout.side, layout.edge)
        end
        frame.BottomTextBar = CreateBottomTextBar(frame, unit, settings, anchorFrame, btbXOff, layout.width)

        -- Hang the cast bar from the text bar only when that sits underneath
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

local function RegisterStylesOnce()
    if _G.KUIUF_StylesRegistered then
        return
    end
    _G.KUIUF_StylesRegistered = true

    oUF:RegisterStyle("KUIPlayer", function(frame, unit)
        FrameStyles.full(frame, unit)
    end)
    oUF:RegisterStyle("KUITarget", function(frame, unit)
        FrameStyles.full(frame, unit)
    end)
    oUF:RegisterStyle("KUIFocus", function(frame, unit)
        FrameStyles.focus(frame, unit)
    end)
    oUF:RegisterStyle("KUIPet", function(frame, unit)
        FrameStyles.pet(frame, unit)
    end)
    oUF:RegisterStyle("KUITargetTarget", function(frame, unit)
        FrameStyles.compact(frame, unit)
    end)
    oUF:RegisterStyle("KUIFocusTarget", function(frame, unit)
        FrameStyles.compact(frame, unit)
    end)
    oUF:RegisterStyle("KUIBoss", function(frame, unit)
        FrameStyles.boss(frame, unit)
    end)
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
    -- Soul Shards are the warlock's own resource, not a mark on the target.
    local comboType
    if class == "DRUID" and (type(GetShapeshiftFormID) ~= "function" or GetShapeshiftFormID() ~= 1) then
        self:_Hide(frame)
        return
    end
    if class == "ROGUE" or class == "DRUID" then
        comboType = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
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
        ns.RaiseRaidTargetHost(frame)
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
    ns.RaiseRaidTargetHost(frame)
end

-- Context of the class power display (ns.ClassPowerBar), built once in InitializeFrames.
local classPowerCtx

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
        ns.QueueUnitFrameLayoutRefresh()
        pcall(ns.ApplyDispelOverlayLive)
        return
    end

    ResolveFontPath()
    ns.EnforceTargetBuffs(db.profile)

    -- Invalidar cache del subsistema de contexto de unidad
    ns._UnitCtx.Invalidate()

    -- Profiles saved before the 0-100 scale stored opacity as 0-1; promote them
    local Kit = ns.UnitFrameKit
    do
        local prof = db.profile
        Kit.PromoteOpacity(prof)
        for _, key in ipairs({ "player", "target", "focus", "boss", "pet", "totPet" }) do
            if prof[key] then Kit.PromoteOpacity(prof[key]) end
        end
    end

    local profile = db.profile
    local castbarColor = GetCastbarColor()
    local castbarOpacity = profile.castbarOpacity
    local enabled = profile.enabledFrames

    -- Uses global font
    local donorFontPath = Compat and Compat.GetFontPath and Compat.GetFontPath("unitFrames")
        or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"

    -- Frames can be switched on and off without a reload
    local function ToggleFrame(unit, frame)
        if not frame then return end
        local unitKey = Kit.FrameKey(unit)
        local isEnabled = enabled[unitKey] ~= false
        -- Player, target and focus also obey the group-type visibility switches
        if isEnabled and (unitKey == "player" or unitKey == "target" or unitKey == "focus") then
            local s = profile[unitKey]
            if s then
                -- Raid beats party beats solo when picking which visibility switch applies
                local gate = IsInRaid() and "showInRaid" or (IsInGroup() and "showInParty" or "showSolo")
                if s[gate] == false then isEnabled = false end
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

    for unit, frame in Kit.EachUnit(frames) do
        ToggleFrame(unit, frame)
    end

    for unit, frame in Kit.EachUnit(frames) do
        if frame then
            local unitKey = Kit.FrameKey(unit)
            if enabled[unitKey] == false then
                -- skip disabled frames
            else
            local settings = GetSettingsForUnit(unit)
            local showPortrait = (db.profile.portraitStyle or "attached") ~= "none" and settings.showPortrait ~= false

            -- Change between 2D, 3D and class art when the setting moved
            if frame.Portrait then
                Portraits.SwapMode(frame)
                -- Re-apply the 3D zoom, rotation and offsets without a reload.
                if frame.Portrait.is2D == false and frame.Portrait.PostUpdate then
                    frame.Portrait:PostUpdate(unit)
                end
            end

            -- Refresh class art style texture (may have changed without mode change)
            if frame.Portrait and frame.Portrait.backdrop and frame.Portrait.backdrop._class then
                local uSettings, isClassMode = Kit.PortraitContext(unit)
                if isClassMode then
                    local classStyle = (uSettings and uSettings.classThemeStyle) or "modern"
                    local ct = Portraits.ResolveClassToken(unit)
                    if ct then
                        Portraits.ApplyClassIcon(frame.Portrait.backdrop._class, ct, classStyle)
                        Portraits.ApplyFacing(frame.Portrait.backdrop._class, unit, uSettings, true)
                        if frame.Portrait.backdrop._2d and frame.Portrait.backdrop._2d.PostUpdate then
                            frame.Portrait.backdrop._2d:PostUpdate()
                        end
                    elseif frame.Portrait.backdrop._class then
                        frame.Portrait.backdrop._class:Hide()
                    end
                end
            end

            -- Portrait visibility follows the setting immediately
            if frame.Portrait and frame.Portrait.backdrop then
                local uSettings, isClassMode = Kit.PortraitContext(unit)
                if showPortrait then
                    frame.Portrait.backdrop:Show()
                    if isClassMode then
                        -- A class-theme portrait is a static texture and needs no portrait events
                        Kit.SwitchElement(frame, "Portrait", false)
                    elseif not frame:IsElementEnabled("Portrait") then
                        frame:EnableElement("Portrait")
                        frame.Portrait:ForceUpdate()
                    end
                else
                    frame.Portrait.backdrop:Hide()
                    Kit.SwitchElement(frame, "Portrait", false)
                end
                -- Detached portraits also refresh their shape, mask and border
                Portraits.ApplyShape(frame.Portrait.backdrop, uSettings, unit)
                -- Portrait level set at creation (50+) - always above the frame's bars
            end

            if unit == "player" and frame.HealthPrediction then
                ApplyAbsorbBarStyle(frame, settings)
            end

            if unit == "player" or unit == "target" then
                local ppPos = settings.powerPosition or "below"
                local ppIsAtt = (ppPos == "below" or ppPos == "above")
                local playerTargetHeight = settings.healthHeight + Kit.PowerStack(settings)
                -- Only the player frame makes room for a class-power row above its bars
                local cpAboveH = (unit == "player") and Kit.ClassPowerRise(settings) or 0
                local playerTargetHeightWithCp = playerTargetHeight + cpAboveH
                local btbExtra = Kit.BtbExtra(settings)
                local targetFrameHeight = playerTargetHeight + btbExtra
                local btbTopRise = Kit.BtbTopRise(settings)
                local _, isAttached = Kit.PortraitState(settings)
                local pXOff = settings.portraitX or 0
                local pYOff = settings.portraitY or 0
                if not isAttached then pYOff = pYOff + ns.FrameLayout.DetachedPortraitY end

                if unit == "player" then
                    local effectiveSide, KUI_PortraitThumbSize, totalWidth, healthXOffset, healthRightInset =
                        Kit.PortraitFit(settings, showPortrait, isAttached, playerTargetHeightWithCp, "left")

                    PP.Size(frame, totalWidth, playerTargetHeightWithCp + btbExtra)

                    if frame.Portrait and frame.Portrait.backdrop then
                        Kit.SeatPortrait(frame, settings, effectiveSide, isAttached, KUI_PortraitThumbSize, btbTopRise,
                            pXOff, pYOff, false)
                    end
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        healthXOffset, healthRightInset = Kit.SnapInsets(frame, showPortrait, isAttached,
                            effectiveSide, healthXOffset, healthRightInset)
                        Kit.AnchorHealth(frame, settings, healthXOffset, healthRightInset,
                            cpAboveH + Kit.PowerAbove(settings) + btbTopRise)
                    end
                    if frame.Power then
                        Kit.PlacePower(frame, settings, ppPos)
                        Kit.DimPowerBackdrop(frame, unit, ppPos)
                    end
                    if frame.Castbar then
                        local castbarBg = frame.Castbar:GetParent()
                        if settings.showPlayerCastbar then
                            Kit.SwitchElement(frame, "Castbar", true)
                            if castbarBg then
                                local castBarOffset = 0
                                if showPortrait and isAttached then
                                    castBarOffset = (effectiveSide == "left") and -(KUI_PortraitThumbSize / 2) or (KUI_PortraitThumbSize / 2)
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
                                castbarBg:SetPoint("TOP", anchorFrame, "BOTTOM", pCbXOff, (usingStockHeight and not pBtbVisible) and -4 or 0)
                                if frame.Castbar._syncInactiveVisibility then
                                    frame.Castbar._syncInactiveVisibility()
                                end
                            end
                            Kit.SkinCastbar(frame, "player", settings, castbarOpacity)
                        else
                            Kit.HideCastbar(frame, castbarBg)
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
                            local kuiBuffYOffset = KT:GetKUIStyleBuffYOffset("player", settings.buffAnchor or "topleft")
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

                    -- Re-tag and re-place the player's texts
                    Kit.RefreshTexts(frame, settings, "both")
                    -- KUI's own default text layout just ran, assuming its
                    -- normal (unthemed) health bar width -- re-apply the
                    -- real stock geometry so themed name/value text isn't
                    -- left at that stale, much-wider position. Without this, the health value hangs well past
                    -- the real (narrower) bar's right edge on every reload.
                    ApplyClassicFrameArt(frame, unit)

                    -- Bottom text bar (player)
                    Kit.SyncBottomBar(frame, unit, settings, (ppIsAtt and frame.Power) or frame.Health, totalWidth,
                        Kit.DockShift(showPortrait, isAttached, effectiveSide, KUI_PortraitThumbSize))

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
                    local effectiveSide, KUI_PortraitThumbSize, totalWidth, healthXOffset, healthRightInset =
                        Kit.PortraitFit(settings, showPortrait, isAttached, playerTargetHeight, "right")

                    PP.Size(frame, totalWidth, targetFrameHeight)

                    if frame.Portrait and frame.Portrait.backdrop then
                        Kit.SeatPortrait(frame, settings, effectiveSide, isAttached, KUI_PortraitThumbSize, btbTopRise,
                            pXOff, pYOff, false)
                    end
                    if frame.Health then
                        frame.Health:ClearAllPoints()
                        healthXOffset, healthRightInset = Kit.SnapInsets(frame, showPortrait, isAttached,
                            effectiveSide, healthXOffset, healthRightInset)
                        Kit.AnchorHealth(frame, settings, healthXOffset, healthRightInset,
                            btbTopRise + Kit.PowerAbove(settings))
                    end
                    if frame.Power then
                        Kit.PlacePower(frame, settings, ppPos)
                        Kit.DimPowerBackdrop(frame, unit, ppPos)
                    end

                    -- Reposition name and health text (target)
                    Kit.RefreshTexts(frame, settings, "both")
                    -- Same re-apply as the player block above -- see its
                    -- comment for why this is needed on every reload.
                    ApplyClassicFrameArt(frame, unit)

                    -- Build or place the target text bar before resolving the castbar anchor.
                    local textBarAnchor = ns.FrameLayout.BarAnchor(frame, ppIsAtt)
                    Kit.SyncBottomBar(frame, unit, settings, textBarAnchor, totalWidth,
                        Kit.DockShift(showPortrait, isAttached, effectiveSide, KUI_PortraitThumbSize))

                    -- Castbar (target) ? anchors to BTB when BTB is bottom, otherwise to power/health
                    if frame.Castbar then
                        local castbarBg = frame.Castbar:GetParent()
                        if castbarBg then
                            if settings.showCastbar ~= false then
                                Kit.SwitchElement(frame, "Castbar", true)
                                local castBarOffset = 0
                                if showPortrait and isAttached then
                                    castBarOffset = (effectiveSide == "left") and -(KUI_PortraitThumbSize / 2) or (KUI_PortraitThumbSize / 2)
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
                                local cbAnchor = btbVisible and frame.BottomTextBar or textBarAnchor
                                local cbXOff = btbVisible and 0 or castBarOffset
                                castbarBg:SetPoint("TOP", cbAnchor, "BOTTOM", cbXOff, (targetUsingStockHeight and not btbVisible) and -4 or 0)
                                if frame.Castbar._syncInactiveVisibility then
                                    frame.Castbar._syncInactiveVisibility()
                                end
                            else
                                Kit.HideCastbar(frame, castbarBg)
                            end
                        end
                        Kit.SkinCastbar(frame, "target", settings, castbarOpacity)
                    end

                    -- Buffs
                    if frame.Buffs then
                        local showBuffs = settings.showBuffs ~= false
                        if showBuffs then
                            if not frame:IsElementEnabled("Auras") then
                                frame:EnableElement("Auras")
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
                            local kuiBuffYOffset = KT:GetKUIStyleBuffYOffset("target", settings.buffAnchor or "topleft")
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

            elseif unit == "focus" then
                local layout = ns.FrameLayout.RefreshStack(Kit, PP, frame, unit, settings, showPortrait, "right")
                ApplyClassicFrameArt(frame, unit)
                Kit.SyncBottomBar(frame, unit, settings, layout.barAnchor, layout.width,
                    Kit.DockShift(showPortrait, layout.attached, layout.side, layout.edge))

                -- The text bar is available before the castbar chooses its live anchor.
                if frame.Castbar then
                    local castbarBg = frame.Castbar:GetParent()
                    if castbarBg then
                        if settings.showCastbar ~= false then
                            Kit.SwitchElement(frame, "Castbar", true)
                            local castBarOffset = 0
                            if showPortrait and layout.attached then
                                castBarOffset = (layout.side == "left") and -(layout.edge / 2) or (layout.edge / 2)
                            end
                            castbarBg:SetSize(layout.width, settings.castbarHeight or 14)
                            if frame.Castbar._iconFrame then
                                local cbH = settings.castbarHeight or 14
                                frame.Castbar._iconFrame:SetSize(cbH + 1, cbH + 1)
                                if frame.Castbar._updateIconLayout then frame.Castbar._updateIconLayout() end
                            end
                            castbarBg:ClearAllPoints()
                            local textBarPosition = settings.btbPosition or "bottom"
                            local btbVisible = (settings.bottomTextBar and textBarPosition == "bottom" and frame.BottomTextBar and frame.BottomTextBar:IsShown())
                            local cbAnchor = btbVisible and frame.BottomTextBar or layout.barAnchor
                            local cbXOff = btbVisible and 0 or castBarOffset
                            castbarBg:SetPoint("TOP", cbAnchor, "BOTTOM", cbXOff, 0)
                            if frame.Castbar._syncInactiveVisibility then
                                frame.Castbar._syncInactiveVisibility()
                            end
                        else
                            Kit.HideCastbar(frame, castbarBg)
                        end
                    end
                    Kit.SkinCastbar(frame, "focus", settings, castbarOpacity)
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
                        -- Measure the portrait as laid out so the bar sits flush against it
                        local petPortOff = 0
                        if showPetPortrait and frame.Portrait and frame.Portrait.backdrop then
                            petPortOff = frame.Portrait.backdrop:GetWidth()
                        elseif showPetPortrait then
                            petPortOff = settings.healthHeight
                        end
                        PP.Point(frame.Health, "TOPLEFT", frame, "TOPLEFT", petPortOff, 0)
                        PP.Point(frame.Health, "RIGHT", frame, "RIGHT", 0, 0)
                        PP.Height(frame.Health, settings.healthHeight)
                        ns.FrameWidgets.HealthInsets(frame.Health).left = petPortOff
                        ns.FrameWidgets.HealthInsets(frame.Health).right = 0
                        ns.FrameWidgets.HealthInsets(frame.Health).top = 0
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
                local bossBarHeight, totalWidth = FrameBuild.BossSize(frameBuildCtx, frame, settings, showPortrait)
                if frame.Health then
                    frame.Health:ClearAllPoints()
                    -- The portrait's real snapped width keeps the bar flush against it
                    local bossRightInset = 0
                    if showPortrait then
                        if frame.Portrait and frame.Portrait.backdrop then
                            bossRightInset = frame.Portrait.backdrop:GetWidth()
                        else
                            bossRightInset = bossBarHeight
                        end
                    end
                    Kit.AnchorHealth(frame, settings, 0, bossRightInset, Kit.PowerAbove(settings, 6))
                end
                if frame.Power then
                    Kit.PlacePower(frame, settings, bPpPos, 6, true)
                    Kit.DimPowerBackdrop(frame, unit, bPpPos)
                end

                UpdateBordersForScale(frame, unit)
            end

            -- Pet, target-of and boss frames borrow border, texture and font from a donor frame
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

            if frame.Power then
                Kit.RefreshPowerFill(frame, unit, settings)
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
            -- Font setter: mini frames use the donor's font, the others their own
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

            for _, slot in ipairs(Kit.FONT_SLOTS) do
                local fs = frame[slot[1]]
                if fs then
                    local s = isMiniFrame and donorSettings or GetSettingsForUnit(unit)
                    SetMiniFont(fs, s[slot[2]] or s.textSize or 12)
                    fs:SetWordWrap(false)
                end
            end

            -- Mini frames re-tag and re-position their texts here
            if isMiniFrame then
                Kit.RefreshTexts(frame, settings, "none")
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
    for unit, frame in Kit.EachUnit(frames) do
        if frame then
            local s = GetSettingsForUnit(unit)
            local sc = (s and s.frameScale) or 100
            ApplyFrameScaleCentered(frame, unit, sc / 100, true)
        end
    end

    if ns.NativeClassResources and ns.NativeClassResources:IsSupported() then
        ns.NativeClassResources:ApplyDefaults(db.profile)
        if db.profile.player.classPowerStyle == "blizzard" then
            if classPowerCtx then ns.ClassPowerBar.Destroy(classPowerCtx) end
            ns.FrameWidgets.ClassResources.bar = ns.NativeClassResources:Activate(frames.player, db.profile)
        elseif ns.NativeClassResources.active and ns.FrameWidgets.ClassResources.Switch then
            ns.FrameWidgets.ClassResources.Switch(db.profile.player.classPowerStyle)
        end
    elseif ns.NativeClassResources and ns.NativeClassResources.active then
        -- A style change handed the resource to the combo display.
        ns.NativeClassResources:Deactivate()
        ns.FrameWidgets.ClassResources.bar = nil
    end
    if ns.ComboUnderFrame and ns.frames then ns.ComboUnderFrame:RefreshAll() end
    RefreshPlayerStatusIndicators()
    RefreshUnitFrameStrata()
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

    FrameBuild.RestTargets(frameBuildCtx, IsResting())
    
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

function ns.InitializeFrames()
    if oUF and oUF.colors and oUF.colors.power then
        local manaColor = { r = MANA_COLOR.r, g = MANA_COLOR.g, b = MANA_COLOR.b }
        manaColor.GetRGB = function(self) return self.r, self.g, self.b end
        oUF.colors.power[0] = manaColor
    end

    if oUF.Tags and oUF.Tags.SetEventUpdateTimer then
        oUF.Tags:SetEventUpdateTimer(0.25)
    end

    if ns.NativeClassResources then ns.NativeClassResources:ApplyDefaults(db.profile) end
    local classPowerStyle = db.profile.player.classPowerStyle or "none"
    local savedClassPowerBar = nil
    if ns.NativeClassResources then
        ns.NativeClassResources:Prepare()
        if classPowerStyle ~= "blizzard" then ns.NativeClassResources:Deactivate() end
    end
    if classPowerStyle == "blizzard" and not (ns.NativeClassResources and ns.NativeClassResources:IsSupported())
        and not (ns.NativeClassResources and ns.NativeClassResources:YieldsToComboDisplay()) then
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

    -- Context handed to ns.FrameBuild (KUI_FrameBuild.lua). Built once here, before the first
    -- spawn runs the style functions; the functions in it read the current profile when called.
    frameBuildCtx = {
        client = "retail",
        frames = frames,
        oUF = oUF,
        GetProfile = function() return db.profile end,
        SettingsFor = GetSettingsForUnit,
        SettingsKeyFor = UnitToSettingsKey,
        MiniDonorSettings = GetMiniDonorSettings,
        PP = PP,
        Kit = ns.UnitFrameKit,
        StyleBarTexture = ApplyHealthBarTexture,
        StyleBarAlpha = ApplyHealthBarAlpha,
        StyleBarDark = ApplyDarkTheme,
        SmoothBar = function(bar) KT:ApplySmoothBar(bar) end,
        BuildPowerBar = function(frame, unit, settings)
            return ns.PowerCast.PowerBar(frameBuildCtx, frame, unit, settings)
        end,
        BuildAbsorbBar = CreateAbsorbBar,
        SetFont = SetFSFont,
        PortraitMode = Portraits.ResolveMode,
        PlaceFrame = ApplyFramePosition,
        ScaleFrame = ApplyFrameScale,
        AttachMenu = SetupUnitMenu,
        -- ns.BottomTextBar
        Shell = function(frame, settings, anchorFrame, xOffset, overrideWidth)
            return FrameBuild.BottomTextBarShell(frameBuildCtx, frame, settings, anchorFrame, xOffset, overrideWidth)
        end,
        ContentToTag = ContentToTag,
        ApplyClassColor = ApplyClassColor,
        ClassToken = ResolveSafeClassToken,
        ApplyClassIcon = Portraits.ApplyClassIcon,
        -- ns.ScaleFit
        QueueLayoutRefresh = function() ns.QueueUnitFrameLayoutRefresh() end,
        -- ns.PowerCast
        UnsnapTexture = UnsnapTex,
        PowerAlpha = ApplyPowerBarAlpha,
        UpdatePowerBackground = ns.UpdatePowerBackground,
        UsesModernNumbers = ns.UsesModernNumbers,
        SmartPowerPercent = ns.ShouldUseSmartPowerPercent,
        CastColor = GetCastbarColor,
        CastFillColor = ResolveCastbarFillColor,
        KT = KT,
    }

    -- Always spawn all frames; hide disabled ones for zero performance impact
    FrameBuild.SpawnUnit(frameBuildCtx, "KUIPlayer", "player", "KullThranUI_UF_Player", true)

    RefreshPlayerStatusIndicators()

    -- The standalone CastBar module owns suppression of Blizzard's player cast bars.
    -- oUF also checks that module state before replacing the default bar.

    -- Context handed to ns.ClassPowerBar (KUI_ClassPowerBar.lua). Built once here;
    -- the functions in it only read the current profile when they are called.
    local Kit = ns.UnitFrameKit
    classPowerCtx = {
        client = "retail",
        frames = frames,
        GetProfile = function() return db.profile end,
        GetPlayerSettings = function() return GetSettingsForUnit("player") end,
        PP = PP,
        Kit = Kit,
        Compat = Compat,
        IsSecret = IsSecret,
        -- MakeBorder is deliberately not set: no definition exists in either workspace (spec F5).
        DecorateRectPip = function(pip)
            local combo = ns.KTTargetCombo
            if combo and combo._DecorateRectPip then combo:_DecorateRectPip(pip) end
        end,
        GetRenderedTheme = function()
            local themes = KT.VisualThemes
            return themes and themes.GetRenderedTheme and themes:GetRenderedTheme() or nil
        end,
        OwnsClassResource = function()
            local combo = ns.ComboUnderFrame
            return combo and combo.OwnsClassResource and combo.OwnsClassResource()
        end,
        ReloadFrames = function()
            if ns.ReloadFrames then ns.ReloadFrames() end
        end,
        Native = ns.NativeClassResources,
        Recharge = KT.ResourceRecharge,
    }

    if KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme() == "classic" and frames.player then
        ApplyClassicFrameArt(frames.player, "player")
    end

    ns.ClassPowerBar.Startup(classPowerCtx, classPowerStyle, savedClassPowerBar)

    -- Class power can be switched without a reload; style is "none", "modern" or "blizzard"
    ns.FrameWidgets.ClassResources.Switch = function(style)
        ns.ClassPowerBar.Toggle(classPowerCtx, style)
    end

    FrameBuild.SpawnUnit(frameBuildCtx, "KUITarget", "target", "KullThranUI_UF_Target", true)

    FrameBuild.SpawnUnit(frameBuildCtx, "KUIFocus", "focus", "KullThranUI_UF_Focus", true)

    FrameBuild.SpawnUnit(frameBuildCtx, "KUIPet", "pet", "KullThranUI_UF_Pet", false)

    FrameBuild.SpawnUnit(frameBuildCtx, "KUITargetTarget", "targettarget", "KullThranUI_UF_TargetTarget", false)

    FrameBuild.SpawnUnit(frameBuildCtx, "KUIFocusTarget", "focustarget", "KullThranUI_UF_FocusTarget", false)

    oUF:SetActiveStyle("KUIBoss")
    local bossPos = db.profile.positions.boss
    local spacing = db.profile.bossSpacing or 60
    for i = 1, 5 do
        local bossUnit = "boss" .. i
        local bossFrame = oUF:Spawn(bossUnit, "KullThranUI_UF_Boss" .. i)
        frames[bossUnit] = bossFrame

        if bossPos then
            bossFrame:ClearAllPoints()
            bossFrame:SetPoint(bossPos.point, UIParent, bossPos.relativePoint or bossPos.point, bossPos.x, bossPos.y - ((i - 1) * spacing))
        end

        SetupUnitMenu(bossFrame, bossUnit)

        if enabled.boss == false then
            bossFrame:Hide()
            bossFrame:SetAttribute("unit", nil)
        end
    end

    FrameBuild.SilenceBlizzardBossFrames()

    -- Switch off the Portrait element of frames that should not show one.
    FrameBuild.DisableUnwantedPortraits(frameBuildCtx)

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

    -- Castbars the profile switches off lose their oUF element (they are always created)
    for _, rule in ipairs({
        { "player", function(s) return not s.showPlayerCastbar end, "showPlayerCastIcon" },
        { "target", function(s) return s.showCastbar == false end, "showCastIcon" },
        { "focus", function(s) return s.showCastbar == false end, "showCastIcon" },
    }) do
        local unitFrame = frames[rule[1]]
        if unitFrame and unitFrame.Castbar then
            local s = db.profile[rule[1]]
            if rule[2](s) then
                Kit.HideCastbar(unitFrame, unitFrame.Castbar:GetParent())
            elseif s[rule[3]] == false and unitFrame.Castbar._iconFrame then
                unitFrame.Castbar._iconFrame:Hide()
            end
        end
    end

    -- Group visibility: player, target and focus appear or hide with the group type
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
                        -- Bring back the elements that were switched off when the frame hid.
                        FrameBuild.RestoreGroupElements(frameBuildCtx, frame, unitKey, s)
                        frame:Show()
                        frame:UpdateAllElements("GroupVisibility")
                        if unitKey == "player" then
                            RefreshPlayerStatusIndicators()
                        end
                    end
                else
                    if frame:IsShown() then
                        -- Elements go off before the hide, otherwise one frame of
                        -- stale content flashes when the unit attribute is cleared
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

    FrameBuild.InstallVisibilityDriver(frameBuildCtx, UpdateFrameVisibility)
    UpdateFrameVisibility()

    -- Portrait border colour follows the unit: refresh it whenever target or
    -- focus changes so "class color" mode picks up the new unit's colour.
    Portraits.RegisterBorderUpdater(frames)

    -- Late-login updates can move power bars after construction; pin the stacked ones once more.
    C_Timer.After(0, function()
        for _, unitKey in ipairs({"player", "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5"}) do
            local frame = frames[unitKey]
            if frame and frame.Power and frame.Health then
                local s = GetSettingsForUnit(Kit.FrameKey(unitKey))
                if s then Kit.ReseatStacked(frame, s) end
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

    local function Register(frame, label, key, onStop)
        if not frame then return end
        local unlockKey = "unitframes_" .. key
        -- Ancho/alto editables desde el menu de clic derecho del unlock mode:
        -- se escriben en los mismos ajustes que los sliders del panel
        -- (frameWidth / healthHeight) para que el layout del frame los respete.
        local sizeEditable = key ~= "playerCastbar" and key ~= "classPower"
        local function GetEditableSettings()
            local settings = GetSettingsForUnit(key)
            if not settings or (key ~= "player" and settings == db.profile.player) then
                return nil
            end
            return settings
        end

        local unlockLabel = label:gsub("^Unit Frames:%s*", "")
        KT.RegisterUnlockElement(unlockKey, {
            label = ns.UFLoc and ns.UFLoc(unlockLabel) or unlockLabel,
            group = "Unit Frames",
            order = unlockOrders[key] or 999,
            getFrame = function()
                return frame
            end,
            getSize = function()
                return frame:GetWidth(), frame:GetHeight()
            end,
            sizeLabels = sizeEditable and { width = "Frame Width", height = "Health Height" } or nil,
            getEditableSize = sizeEditable and function()
                local settings = GetEditableSettings()
                if not settings then return nil end
                return tonumber(settings.frameWidth) or 100, tonumber(settings.healthHeight) or 20
            end or nil,
            setEditableSize = sizeEditable and function(_, width, height)
                local settings = GetEditableSettings()
                if not settings or InCombatLockdown() then return end
                width = math.max(40, math.min(600, width))
                height = math.max(6, math.min(200, height))
                if tonumber(settings.frameWidth) == width and tonumber(settings.healthHeight) == height then
                    return
                end
                settings.frameWidth = width
                settings.healthHeight = height
                if ns.ReloadFrames then ns.ReloadFrames() end
            end or nil,
            getScale = function()
                return frame:GetScale()
            end,
            setScale = function(_, scale)
                if scale and scale > 0 then
                    local settings = GetSettingsForUnit(key)
                    -- Solo se escribe si la escala cambia de verdad: evita
                    -- pisar el frameScale del tema con un valor redondeado.
                    if settings and math.abs((tonumber(settings.frameScale) or 100) - (scale * 100)) >= 0.5 then
                        settings.frameScale = scale * 100
                    end
                    ApplyFrameScaleCentered(frame, key, scale, false)
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
                if native and native.point and not native.relativeTo then
                    return {
                        point = native.point,
                        relativePoint = native.relativePoint or native.point,
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
                    relativeTo = false, -- a screen position (KT:RepairLayoutPosition)
                    relativePoint = rpt or pt or "CENTER",
                    x = x or 0,
                    y = y or 0,
                    scale = scale or frame:GetScale() or 1,
                }
                if onStop then onStop() end
            end,
            applyPosition = function()
                local saved = KT.db.profile.editMode
                    and KT.db.profile.editMode.frames
                    and KT.db.profile.editMode.frames[unlockKey]
                if saved and saved.point then
                    db.profile.positions[key] = {
                        point = saved.point,
                        relativeTo = false,
                        relativePoint = saved.relativePoint or saved.point,
                        x = saved.x or 0,
                        y = saved.y or 0,
                        scale = saved.scale or frame:GetScale() or 1,
                    }
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
                        relativeTo = defaultPos.relativeTo,
                        relativePoint = defaultPos.relativePoint,
                        x = defaultPos.x or 0,
                        y = defaultPos.y or 0,
                        fallback = Mod.UnitLayout.Copy(defaultPos.fallback),
                        scale = (frame.GetScale and frame:GetScale()) or 1,
                    }
                else
                    db.profile.positions[key] = nil
                end

                if KT.FlushPersistence then KT:FlushPersistence() end

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
                ApplyFramePosition(frame, "boss")
                local pt, relative, rpt, x, y = frame:GetPoint()
                if pt then
                    frame:ClearAllPoints()
                    frame:SetPoint(pt, relative, rpt, x, y - ((i - 1) * spacing))
                end
            end
        end
    end)

    if frames.player and frames.player.Castbar and not db.profile.player.lockCastbarToFrame then
        Register(frames.player.Castbar:GetParent(), "Unit Frames: Player Castbar", "playerCastbar")
    end
    if ns.FrameWidgets.ClassResources.bar and not db.profile.player.lockClassPowerToFrame then
        Register(ns.FrameWidgets.ClassResources.bar, "Unit Frames: Class Power", "classPower")
    end
end

-- Read-only diagnostics: compare the active profile's two position stores
-- with the rendered anchors without repairing or saving anything.
function ns.DebugFramePositions()
    KT:Print(string.format(ns.UFLoc("UF startup pending=%s | layout pending=%s | combat=%s"),
        tostring(ns._startupLayoutPending == true), tostring(ns._layoutRestorePending == true),
        tostring(InCombatLockdown())))
    if not (KT and KT.Print and db and db.profile) then return end
    local profile = KT.db and KT.db.profile
    local edit = profile and profile.editMode and profile.editMode.frames or {}
    local name = KT.db.GetCurrentProfile and KT.db:GetCurrentProfile() or "unknown"
    KT:Print(string.format(ns.UFLoc("UF positions | profile=%s | UI scale=%s"), tostring(name), tostring(UIParent:GetEffectiveScale())))
    for _, unit in ipairs({ "player", "target", "focus", "pet", "targettarget", "focustarget", "boss" }) do
        local frame = frames[unit == "boss" and "boss1" or unit]
        local native = db.profile.positions[unit]
        local saved = edit["unitframes_" .. unit]
        local function describe(pos)
            if not pos then return "none" end
            return string.format("%s/%s x=%.3f y=%.3f scale=%s", tostring(pos.point),
                tostring(pos.relativePoint or pos.point), pos.x or 0, pos.y or 0, tostring(pos.scale or "default"))
        end
        KT:Print(string.format(ns.UFLoc("%s | native=%s | unlock=%s"), unit, describe(native), describe(saved)))
        if frame then
            local pt, relative, rpt, x, y = frame:GetPoint()
            KT:Print(string.format(ns.UFLoc("%s | live=%s | relative=%s"), unit,
                describe({point=pt,relativePoint=rpt,x=x,y=y,scale=frame:GetScale()}),
                tostring(relative and relative.GetName and relative:GetName())))
        end
    end
end

local function SetupOptionsPanel()
    ns.db = db
    ns.frames = frames
    if ns.AggroGlow then ns.AggroGlow:Update() end
    ns.ApplyFramePosition = ApplyFramePosition
    ns.ApplyFrameScale = ApplyFrameScaleCentered
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
            if ns.PortraitAuras then ns.PortraitAuras.RefreshAll() end
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

StaticPopupDialogs["KULLTHRANUI_UF_RESET_DEFAULTS"] = setmetatable({
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
}, {
    __index = function(_, key)
        if key == "text" then
            return ns.UFLoc("Reset all KullThranUI Unit Frames settings to defaults? This cannot be undone.")
        elseif key == "button1" then
            return ns.UFLoc("Reset & Reload")
        elseif key == "button2" then
            return ns.UFLoc("Cancel")
        end
    end,
})

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
    value = BAR_TEXTURE_RENAMES[value] or value
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
        local isLegacyGreen = ns.FrameLayout.IsLegacyCastbarColor(targetCb)
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
        and (ns.FrameLayout.IsLegacyCastbarColor(color)
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

-- The same per-resolution defaults, seeded into every store Unlock Mode reads.
local FOREVER_UNIT_FRAME_LAYOUT_DEFAULTS = {
    focus = defaults.profile.positions.focus,
    pet = defaults.profile.positions.pet,
    targettarget = defaults.profile.positions.targettarget,
    focustarget = defaults.profile.positions.focustarget,
}

-- Profiles still on a legacy single-set default (unit positions and their
-- Unlock Mode copies) take this client's and resolution's default, once.
function Mod.UnitLayout.Migrate()
    local profile = db and db.profile
    if not profile then return end
    -- Every load: screen positions that took an anchored default's relativeTo
    -- from the defaults merge (KT:RepairLayoutPosition).
    for _, key in ipairs(Mod.UnitLayout.units) do
        KT:RepairLayoutPosition(key, profile.positions and profile.positions[key])
    end
    if profile._defaultLayout20261031 then return end
    local positions = profile.positions or {}
    local editFrames = KT.db.profile.editMode and KT.db.profile.editMode.frames
    for _, key in ipairs(Mod.UnitLayout.units) do
        local legacy, new = Mod.UnitLayout.legacy[key], defaults.profile.positions[key]
        if KT:IsLegacyDefaultPosition(positions[key], legacy) or KT:IsPreviousDefaultPosition(key, positions[key]) then
            positions[key] = Mod.UnitLayout.Copy(new)
        end
        -- An Unlock Mode copy of an old default would pin the frame to the
        -- screen; the module's store holds the default now.
        local saved = type(editFrames) == "table" and editFrames["unitframes_" .. key]
        if KT:IsLegacyDefaultPosition(saved, legacy) or KT:IsPreviousDefaultPosition(key, saved) then
            editFrames["unitframes_" .. key] = nil
        end
    end
    profile._defaultLayout20261030 = true
    profile._defaultLayout20261031 = true
end

-- Persistence guard: old Forever builds used to delete the saved copies here.
-- Keep this helper inert so no future rebind can erase user coordinates.
local function ClearForeverUnitFrameLayoutCopies()
end

local function WriteForeverUnitFrameLayoutCopies()
    local function writeFrames(frames)
        if type(frames) ~= "table" then return end
        for key, pos in pairs(FOREVER_UNIT_FRAME_LAYOUT_DEFAULTS) do
            local saved = frames["unitframes_" .. key]
            if not pos.relativeTo then
                if type(saved) ~= "table"
                    or type(saved.point) ~= "string"
                    or type(saved.x) ~= "number"
                    or type(saved.y) ~= "number"
                then
                    frames["unitframes_" .. key] = {
                        point = pos.point,
                        relativePoint = pos.relativePoint or pos.point,
                        x = pos.x,
                        y = pos.y,
                    }
                end
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
                profile.unitFrames.positions[key] = Mod.UnitLayout.Copy(pos)
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
            profile.positions[key] = Mod.UnitLayout.Copy(pos)
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
    -- Profiles switched to, copied or imported may still carry pre-KUI bar texture keys.
    if KT.MigrateBarTextureKeys then KT:MigrateBarTextureKeys(db.profile) end
    portraitsCtx.db = db
    Portraits.Init(portraitsCtx)
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

-- Reparacion unica: el unlock mode guardaba la escala del Player redondeada
-- (132 -> 100) al tocar el elemento, y el Player quedaba mas pequeno que el
-- Target en los temas stock (classic/forever/retail usan 132 para ambos).
function Mod:RepairThemePlayerScale(profile)
    if type(profile) ~= "table" or profile._ktPlayerScaleRepair20261009 then return end
    profile._ktPlayerScaleRepair20261009 = true
    local VT = KT.VisualThemes
    local theme = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
    local target = type(profile.target) == "table" and profile.target or nil
    local stockTheme = (theme == "classic" or theme == "forever" or theme == "retail")
        or (target and tonumber(target.frameScale) == 132)
    if not stockTheme or theme == "kui" then return end
    profile.player = type(profile.player) == "table" and profile.player or {}
    profile.player.frameScale = 132
    if target then target.frameScale = 132 end
end

function Mod:OnInitialize()
    self:BindDatabase()
    self:SetEnabledState(self.db.enable ~= false)
    MigratePlayerTarget()
    ApplyForeverPortraitDefaults()
    SanitizeImportedLayout()
    MigrateLegacyCrimsonAccent()
    ApplyUpdatedDefaultPreset()
    self:RepairThemePlayerScale(self.db)
    ApplyTargetCastbarYellowDefault()
    KT:SwapPortraitFacingDefaults()
    KT:MigrateClassicPortraitCircular()
    KT:MigrateRetailPortraitCircular()
    KT:MigrateRetailHealthGreen()
    KT:MigrateForeverHealthColorSelector()
    KT:MigrateKuiPvPCircleDefault()
    KT:MigrateThemedCastbarVisible()
    ApplyReferenceLayoutDefaults()
    Mod.UnitLayout.Migrate()
    ApplyDebuffDefaultsMigration()
    ApplyForeverUnitFrameLayoutDefaults()
    ns.MigrateBlizzardTextDefaults(db.profile)
    ns.EnforceTargetBuffs(db.profile)
    if RegisterUFHPDebugSlash then
        C_Timer.After(0, RegisterUFHPDebugSlash)
    end
    if KT and KT.RegisterChatCommand then
        KT:RegisterChatCommand("ktufpos", function() ns.DebugFramePositions() end)
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
            if s then ns.UnitFrameKit.PromoteOpacity(s) end
        end
        ns.UnitFrameKit.PromoteOpacity(prof)
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
            Portraits.UpdateCircularBorder(frame)
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

-- Restore the latest profile once protected layout can be changed again.
function ns.QueueUnitFrameLayoutRefresh()
    if ns._layoutRestorePending then return end
    ns._layoutRestorePending = true
    local waiter = ns._layoutRestoreWaiter
    if not waiter then
        waiter = CreateFrame("Frame")
        ns._layoutRestoreWaiter = waiter
        waiter:SetScript("OnEvent", function(self)
            if InCombatLockdown() then return end
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            ns._layoutRestorePending = nil
            if Mod:IsEnabled() then
                if KT.PersistDebug then KT:PersistDebug("UF layout restore after combat") end
                Mod:Refresh()
            end
        end)
    end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ns.DeferUnitFrameStartup()
    if IsLoggedIn() and not InCombatLockdown() then return false end
    ns._startupLayoutPending = true
    if not ns._startupLayoutWaiter then
        local waiter = CreateFrame("Frame")
        ns._startupLayoutWaiter = waiter
        waiter:SetScript("OnEvent", function(self)
            if not IsLoggedIn() or InCombatLockdown() then return end
            self:UnregisterAllEvents()
            ns._startupLayoutPending = nil
            if Mod:IsEnabled() then
                if KT.PersistDebug then KT:PersistDebug("UF safe startup after world/combat") end
                Mod:OnEnable()
            end
        end)
    end
    ns._startupLayoutWaiter:RegisterEvent("PLAYER_ENTERING_WORLD")
    ns._startupLayoutWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    if KT.PersistDebug then
        KT:PersistDebug("UF startup deferred loggedIn=%s combat=%s", tostring(IsLoggedIn()), tostring(InCombatLockdown()))
    end
    return true
end

function Mod:OnEnable()
    self:BindDatabase()
    if self.db.enable == false then
        self:SetEnabledState(false)
        return
    end
    if ns.DeferUnitFrameStartup() then return end
    ns.EnableTarget3D(db and db.profile)
    ns.InitializeFrames()

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
    if ns._startupLayoutWaiter then ns._startupLayoutWaiter:UnregisterAllEvents() end
    if ns._layoutRestoreWaiter then ns._layoutRestoreWaiter:UnregisterAllEvents() end
    ns._startupLayoutPending, ns._layoutRestorePending = nil, nil
    if ns.NativeClassResources then ns.NativeClassResources:Deactivate() end
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
    HideFrameTree(ns.FrameWidgets.ClassResources.bar)
end
