-- The small table the unit frames share: fonts, pixel helpers, media and oUF colour hooks, the defaults merger, and the
-- Maelstrom Weapon, Tip of the Spear and Whirlwind trackers. Existing fields win, so a second load changes nothing.

local _, ns = ...

local floor, max = math.floor, math.max

local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
local KT = AceAddon and AceAddon:GetAddon("KullThranUI", true) or KT

local Compat = ns.KUIUFCompat or {}
ns.KUIUFCompat = Compat

-- Set by Bind. Nothing is read from it until it is needed.
local context

Compat.Bind = Compat.Bind or function(ctx)
    context = ctx
end

-----------------------------------------------------------------------------------------------------------------------
-- Pixel helpers: defined as one group, only when PP.Scale is absent.
-----------------------------------------------------------------------------------------------------------------------
local PP = Compat.PP or {}
Compat.PP = PP

if not PP.Scale then
    -- Rounds to the physical pixel grid. The UI scale changes at run time, so it is read on each call.
    local function Scale(v)
        local s = UIParent and UIParent:GetEffectiveScale() or 1
        return floor((v or 0) * s + 0.5) / s
    end

    local function CreateBorder(frame, r, g, b, a, size, layer, sublevel)
        size = max(1, floor(size or 1))

        local edges = frame._ppBorders
        if not edges then
            layer, sublevel = layer or "OVERLAY", sublevel or 0
            edges = {}
            for i = 1, 4 do
                edges[i] = frame:CreateTexture(nil, layer, nil, sublevel)
            end
            frame._ppBorders = edges
        end

        r, g, b, a = r or 0, g or 0, b or 0, a or 1
        frame._ppBorderSize = size
        frame._ppBorderColor = { r = r, g = g, b = b, a = a }

        local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size)
        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", size, size)
        top:SetHeight(size)
        bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -size, -size)
        bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
        bottom:SetHeight(size)
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size)
        left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -size, -size)
        left:SetWidth(size)
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", size, size)
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
        right:SetWidth(size)

        for i = 1, 4 do
            edges[i]:SetColorTexture(r, g, b, a)
            edges[i]:Show()
        end

        local hidden = frame._ppHideEdge and edges[frame._ppHideEdge]
        if hidden then
            hidden:Hide()
        end
    end

    PP.Scale = Scale
    PP.CreateBorder = CreateBorder

    function PP.Point(frame, point, rel, relPoint, x, y)
        frame:SetPoint(point, rel, relPoint, Scale(x), Scale(y))
    end

    function PP.Size(frame, w, h)
        frame:SetSize(Scale(w), Scale(h))
    end

    function PP.Width(frame, w)
        frame:SetWidth(Scale(w))
    end

    function PP.Height(frame, h)
        frame:SetHeight(Scale(h))
    end

    function PP.DisablePixelSnap(tex)
        if tex and tex.SetSnapToPixelGrid then
            tex:SetSnapToPixelGrid(false)
            tex:SetTexelSnappingBias(0)
        end
    end

    function PP.SetHiddenEdge(frame, edge)
        if not frame or not frame._ppBorders then
            return
        end
        frame._ppHideEdge = edge
        frame._ppBorders[3]:SetShown(edge ~= 3)
        frame._ppBorders[4]:SetShown(edge ~= 4)
    end

    function PP.SetBorderSize(frame, size)
        if not frame or not frame._ppBorderColor then
            return
        end
        local c = frame._ppBorderColor
        CreateBorder(frame, c.r, c.g, c.b, c.a, size)
    end

    function PP.SetBorderColor(frame, r, g, b, a)
        if not frame or not frame._ppBorders then
            return
        end
        r, g, b, a = r or 0, g or 0, b or 0, a or 1
        frame._ppBorderColor = { r = r, g = g, b = b, a = a }
        for i = 1, 4 do
            frame._ppBorders[i]:SetColorTexture(r, g, b, a)
        end
    end

    function PP.UpdateBorder(frame, size, r, g, b, a)
        CreateBorder(frame, r, g, b, a, size)
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Fonts. Saved profiles hold these names.
-----------------------------------------------------------------------------------------------------------------------
local FONT_DIR = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\"
local LOAD_TIME_FONT = KT.FONT_PATH

Compat.fontPaths = Compat.fontPaths or {
    ["AAA_ITC_Avant_Garde"] = LOAD_TIME_FONT,
    ["Avant Garde"] = LOAD_TIME_FONT,
    ["Expressway"] = LOAD_TIME_FONT,
    ["Aldo PC"] = FONT_DIR .. "Aldo PC.ttf",
    ["Capture it"] = FONT_DIR .. "Captureit.ttf",
    ["Duepuntozero"] = FONT_DIR .. "duepuntozero.ttf",
    ["Emblem"] = FONT_DIR .. "Emblem.ttf",
    ["PF Ronda Seven"] = FONT_DIR .. "pf_ronda_seven.ttf",
    ["PF Ronda Seven Bold"] = FONT_DIR .. "pf_ronda_seven_bold.ttf",
    ["Planet Kosmos"] = FONT_DIR .. "PLANE___.TTF",
    ["SF New Republic"] = FONT_DIR .. "SF New Republic.ttf",
    ["Swansea Bold"] = FONT_DIR .. "SWANSE_B.TTF",
    ["Swansea"] = FONT_DIR .. "SWANSE__.TTF",
    ["Tempesta Seven"] = FONT_DIR .. "Tempesta Seven Condensed.ttf",
}

if Compat.LOCALE_FONT_FALLBACK == nil then
    local locale = GetLocale()
    if locale == "koKR" or locale == "zhCN" or locale == "zhTW" or locale == "ruRU" then
        Compat.LOCALE_FONT_FALLBACK = STANDARD_TEXT_FONT
    end
end

Compat.GetFontPath = Compat.GetFontPath or function(unitKey)
    local name
    if unitKey and context then
        local profile = context.GetProfile()
        local unitSettings = profile and profile[unitKey]
        name = unitSettings and unitSettings.selectedFont
    end
    if name then
        local path = Compat.fontPaths[name]
        if path then
            return path
        end
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        path = LSM and LSM:Fetch("font", name, true)
        if path then
            return path
        end
    end
    return KT.FONT_PATH
end

Compat.GetFontOutlineFlag = Compat.GetFontOutlineFlag or function()
    return "OUTLINE"
end

Compat.GetFontUseShadow = Compat.GetFontUseShadow or function()
    return false
end

-----------------------------------------------------------------------------------------------------------------------
-- Shared media and oUF.
-----------------------------------------------------------------------------------------------------------------------
Compat.AppendSharedMediaTextures = Compat.AppendSharedMediaTextures or function(names, order, _, map)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local list = LSM and LSM:List("statusbar")
    if not list then
        return
    end
    for i = 1, #list do
        local name = list[i]
        if not map[name] then
            map[name] = LSM:Fetch("statusbar", name)
            names[name] = name
            order[#order + 1] = name
        end
    end
end

Compat.ApplyColorsToOUF = Compat.ApplyColorsToOUF or function()
    local uf = ns.oUF or oUF
    local colors = uf and uf.colors
    local custom = CUSTOM_CLASS_COLORS
    if colors and custom then
        colors.class = custom
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Defaults merger. Eager, with no memory: every value is in dst on return, and a key not in src is never made.
-- It must keep running exactly when its callers call it; a saved nil on a defaulted key cannot survive it.
-----------------------------------------------------------------------------------------------------------------------
local function CopyDefaults(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then
        return dst
    end
    for key, value in pairs(src) do
        local current = dst[key]
        if current == nil then
            if type(value) == "table" then
                dst[key] = CopyDefaults({}, value)
            else
                dst[key] = value
            end
        elseif type(current) == "table" and type(value) == "table" then
            CopyDefaults(current, value)
        end
    end
    return dst
end

Compat.CopyDefaults = Compat.CopyDefaults or CopyDefaults

-----------------------------------------------------------------------------------------------------------------------
-- Resource trackers, read in combat. Each is one function, with the aura rule written out in place: no helper calls,
-- no allocation. Aura stacks may be secret and are only truth-tested, stored and returned.
-----------------------------------------------------------------------------------------------------------------------
local MAELSTROM_WEAPON, TIP_OF_THE_SPEAR, WHIRLWIND = 344179, 260286, 1680

Compat.resourceState = Compat.resourceState or {
    maelstrom = 0, maelstromMax = 10,
    tip = 0, tipMax = 3,
    whirlwind = 0, whirlwindMax = 4,
}

local function GetMaelstromWeapon()
    local state = Compat.resourceState
    local spells = C_Spell
    local name = spells and spells.GetSpellName and spells.GetSpellName(MAELSTROM_WEAPON)
    local aura
    if name and AuraUtil then
        aura = AuraUtil.FindAuraByName(name, "player", "HELPFUL")
    end
    local current = 0
    if aura then
        current = aura.applications or aura.charges or 0
    end
    state.maelstrom = current
    return current, state.maelstromMax
end

local function GetTipOfTheSpear()
    local state = Compat.resourceState
    local spells = C_Spell
    local name = spells and spells.GetSpellName and spells.GetSpellName(TIP_OF_THE_SPEAR)
    local aura
    if name and AuraUtil then
        aura = AuraUtil.FindAuraByName(name, "player", "HELPFUL")
    end
    local current
    if aura then
        current = aura.applications or aura.charges or 0
    else
        current = state.tip or 0
    end
    state.tip = current
    return current, state.tipMax
end

Compat.GetMaelstromWeapon = Compat.GetMaelstromWeapon or GetMaelstromWeapon
Compat.GetTipOfTheSpear = Compat.GetTipOfTheSpear or GetTipOfTheSpear

Compat.GetWhirlwindStacks = Compat.GetWhirlwindStacks or function()
    local state = Compat.resourceState
    return state.whirlwind or 0, state.whirlwindMax
end

-- Callers pass more arguments; none matters, so no vararg is declared on this hot path.
Compat.HandleTipOfTheSpear = Compat.HandleTipOfTheSpear or function(event)
    if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
        Compat.resourceState.tip = 0
        return
    end
    GetTipOfTheSpear()
end

Compat.HandleWhirlwindStacks = Compat.HandleWhirlwindStacks or function(event, unit, _, spellID)
    local state = Compat.resourceState
    if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_REGEN_ENABLED" then
        state.whirlwind = 0
    elseif unit ~= "player" then
        return
    elseif spellID == WHIRLWIND then
        state.whirlwind = state.whirlwindMax
    else
        local stacks = state.whirlwind
        if stacks and stacks > 0 then
            state.whirlwind = stacks - 1
        end
    end
end
