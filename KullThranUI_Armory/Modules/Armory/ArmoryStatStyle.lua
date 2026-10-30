local _, ns = ...

-- Draws a Visual Style's stats look (ArmoryStyles <style>.stats) over the
-- pieces both the character panel and the options live preview already
-- have: title FontStrings with their side lines, label/value FontStrings,
-- stat icon textures and the item level block. Without tokens every call
-- hides what it drew, clears the shadow it set and returns false, so the
-- caller's own look (re-applied on each refresh) stays.
local StatStyle = {}
local FALLBACK_ACCENT = { 1, 0.49, 0 }
local ROUND_GLOW = [[Interface\AddOns\KullThranUI\Libraries\KUITextures\MenuSkins\round_disc]]
-- The game's own localized "PvP" string, in caps.
local PVP_LABEL = string.upper(_G.PVP or "PvP")

-- Art draws at BACKGROUND 3: above the preview panel art (BACKGROUND 0-2),
-- below the ARTWORK side lines and the OVERLAY text.
local ART_LAYER, ART_SUBLEVEL = "BACKGROUND", 3

local function Color(c)
    if c == "accent" then
        local KT = ns.KT
        if KT and KT.GetStyleAccentRGB then
            local r, g, b = KT:GetStyleAccentRGB()
            if r then return r, g, b end
        end
        c = FALLBACK_ACCENT
    end
    return c[1], c[2], c[3]
end

local function Font(path)
    local KT = ns.KT
    if KT and KT.ResolveFontForLocale then
        return KT:ResolveFontForLocale(path, path) or path
    end
    return path
end

-- Font, flags and shadow of one FontString; size keeps the caller's unless given.
local function SetText(fs, font, size, flags, shadow)
    local _, currentSize = fs:GetFont()
    fs:SetFont(Font(font), size or currentSize or 12, flags or "")
    if shadow then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs._ktShadow = true
    elseif fs._ktShadow then
        fs:SetShadowOffset(0, 0)
        fs._ktShadow = nil
    end
end

local function ClearShadow(fs)
    if fs._ktShadow then
        fs:SetShadowOffset(0, 0)
        fs._ktShadow = nil
    end
end

local function Art(host)
    return host:CreateTexture(nil, ART_LAYER, nil, ART_SUBLEVEL)
end

-- Horizontal alpha fade on a plain texture (modern and older clients).
local function Fade(tex, r, g, b, fromAlpha, toAlpha)
    tex:SetTexture([[Interface\Buttons\WHITE8X8]])
    if tex.SetGradient and CreateColor then
        tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, fromAlpha), CreateColor(r, g, b, toAlpha))
    elseif tex.SetGradientAlpha then
        tex:SetGradientAlpha("HORIZONTAL", r, g, b, fromAlpha, r, g, b, toAlpha)
    else
        tex:SetColorTexture(r, g, b, math.max(fromAlpha, toAlpha))
    end
end

local function HideAll(parts)
    if parts then
        for _, part in pairs(parts) do part:Hide() end
    end
end

-- Upper-cases a title for styles that want caps and restores the original
-- text for those that do not (the item level title is set only once).
local function Caps(fs, caps)
    local text = fs:GetText()
    if caps then
        if text and text ~= fs._ktCapsOf then
            fs._ktOriginal = text
            fs._ktCapsOf = string.upper(text)
            fs:SetText(fs._ktCapsOf)
        end
    elseif fs._ktOriginal and text == fs._ktCapsOf then
        fs:SetText(fs._ktOriginal)
        fs._ktOriginal, fs._ktCapsOf = nil, nil
    end
end

-- Moves an anchor's horizontal part to the left edge: CENTER -> LEFT,
-- TOP -> TOPLEFT, BOTTOM -> BOTTOMLEFT, keeping its vertical offset.
local LEFT_OF = { CENTER = "LEFT", TOP = "TOPLEFT", BOTTOM = "BOTTOMLEFT", LEFT = "LEFT", TOPLEFT = "TOPLEFT", BOTTOMLEFT = "BOTTOMLEFT" }

local function DrawPlate(host, label, header)
    local plate = label._ktPlate
    if not plate then
        plate = { left = Art(host), middle = Art(host), right = Art(host) }
        label._ktPlate = plate
    end
    local half = math.max(0, (host:GetWidth() or 0) - 2 * header.inset) / 2
    local cap = header.capCoord
    for _, part in pairs(plate) do
        part:SetTexture(header.plate)
        part:ClearAllPoints()
        part:SetSize(header.cap, header.height)
        part:Show()
    end
    -- After SetTexture: a texture change can reset the texcoords.
    plate.left:SetTexCoord(0, cap, 0, 1)
    plate.middle:SetTexCoord(cap, 1 - cap, 0, 1)
    plate.right:SetTexCoord(1 - cap, 1, 0, 1)
    plate.left:SetPoint("LEFT", label, "CENTER", -half, 0)
    plate.right:SetPoint("RIGHT", label, "CENTER", half, 0)
    plate.middle:SetPoint("LEFT", plate.left, "RIGHT", 0, 0)
    plate.middle:SetPoint("RIGHT", plate.right, "LEFT", 0, 0)
end

-- KUI: title on the left with a small accent marker before it and a rule
-- after it that fades out towards the right edge.
local function DrawTab(host, label, header, r, g, b)
    local tab = label._ktTab
    if not tab then
        tab = { marker = Art(host), rule = Art(host) }
        label._ktTab = tab
    end
    local point, relativeTo, relativePoint, _, y = label:GetPoint(1)
    label:ClearAllPoints()
    label:SetPoint(LEFT_OF[point] or "LEFT", relativeTo or host, LEFT_OF[relativePoint] or "LEFT", header.inset, y or 0)
    label:SetJustifyH("LEFT")
    tab.marker:ClearAllPoints()
    tab.marker:SetColorTexture(r, g, b, 1)
    tab.marker:SetSize(4, 4)
    tab.marker:SetPoint("RIGHT", label, "LEFT", -4, 2)
    tab.marker:Show()
    local used = header.inset + (label:GetStringWidth() or 0) + 8
    tab.rule:ClearAllPoints()
    Fade(tab.rule, r, g, b, 0.8, 0)
    tab.rule:SetSize(math.max(0, (host:GetWidth() or 0) - used - 10), 1)
    tab.rule:SetPoint("LEFT", label, "RIGHT", 8, 0)
    tab.rule:Show()
end

-- Retail: centred title, a line on each side fading towards the edges.
local function DrawFade(host, label, header)
    local fade = label._ktFade
    if not fade then
        fade = { left = Art(host), right = Art(host) }
        label._ktFade = fade
    end
    local r, g, b = Color(header.line)
    local width = math.max(0, (host:GetWidth() or 0) / 2 - (label:GetStringWidth() or 0) / 2 - 8 - 10)
    fade.left:ClearAllPoints()
    Fade(fade.left, r, g, b, 0, 0.85)
    fade.left:SetSize(width, 1)
    fade.left:SetPoint("RIGHT", label, "LEFT", -8, 0)
    fade.right:ClearAllPoints()
    Fade(fade.right, r, g, b, 0.85, 0)
    fade.right:SetSize(width, 1)
    fade.right:SetPoint("LEFT", label, "RIGHT", 8, 0)
    fade.left:Show()
    fade.right:Show()
end

function StatStyle:Header(host, label, lines, tokens)
    local header = tokens and tokens.header
    local kind = header and header.kind
    if kind ~= "plate" then HideAll(label._ktPlate) end
    if kind ~= "tab" then HideAll(label._ktTab) end
    if kind ~= "fade" then HideAll(label._ktFade) end
    if not header then
        ClearShadow(label)
        return false
    end
    SetText(label, header.font, header.size, header.flags, tokens.shadow)
    Caps(label, header.caps)
    local r, g, b = Color(header.title)
    if kind == "plate" then
        DrawPlate(host, label, header)
    elseif kind == "tab" then
        DrawTab(host, label, header, r, g, b)
    elseif kind == "fade" then
        DrawFade(host, label, header)
    end
    for _, line in ipairs(lines or {}) do
        line:Hide()
    end
    label:SetTextColor(r, g, b)
    return true
end

-- Greys the "(12.34%)" part of a value, once.
local function MutePercent(value, muted)
    local text = value:GetText()
    if not text or text:find("|c", 1, true) then return end
    local hex = string.format("%02x%02x%02x", muted[1] * 255, muted[2] * 255, muted[3] * 255)
    local out, count = text:gsub("(%(.-%%%))", "|cff" .. hex .. "%1|r")
    if count > 0 then value:SetText(out) end
end

-- One palette and font for every stat row, the style's own icon, and a band
-- behind odd rows (bandIndex counts rows inside a section from 1).
function StatStyle:Row(host, label, value, bandIndex, tokens, icon, glyph)
    local band = value._ktBand
    if not (tokens and tokens.label) then
        if band then band:Hide() end
        ClearShadow(label)
        ClearShadow(value)
        if icon and icon._ktTinted then
            icon:SetVertexColor(1, 1, 1)
            icon._ktTinted = nil
        end
        return false
    end
    SetText(label, tokens.font, nil, tokens.flags, tokens.shadow)
    SetText(value, tokens.font, nil, tokens.flags, tokens.shadow)
    label:SetTextColor(Color(tokens.label))
    value:SetTextColor(Color(tokens.value))
    if tokens.muted then MutePercent(value, tokens.muted) end
    -- The caller sized the value column with its own font; re-measure in ours
    -- (same bounds as the character panel) so long values are not cut.
    local valueWidth = value:GetStringWidth()
    if valueWidth and valueWidth > 0 then
        value:SetWidth(math.min(125, math.max(28, valueWidth + 8)))
    end

    local icons = tokens.icons
    -- Not "glyph and GlyphCoords(glyph)": that keeps only the first value.
    local l, r, t, b
    if glyph then l, r, t, b = ns.ArmoryStyles:GlyphCoords(glyph) end
    if icon and icons and l then
        icon:SetTexture(icons.atlas)
        icon:SetTexCoord(l, r, t, b)
        if icons.tint then
            icon:SetVertexColor(Color(icons.tint))
            icon._ktTinted = true
        else
            icon:SetVertexColor(1, 1, 1)
            icon._ktTinted = nil
        end
    elseif icon and icon._ktTinted then
        -- A game icon (no glyph) on a row a tinted glyph used before.
        icon:SetVertexColor(1, 1, 1)
        icon._ktTinted = nil
    end

    if tokens.band and bandIndex % 2 == 1 then
        if not band then
            band = Art(host)
            value._ktBand = band
        end
        local c = tokens.band
        band:SetColorTexture(c[1], c[2], c[3], c[4])
        band:ClearAllPoints()
        -- Values sit 10px from the host's right edge; the band ends bandInset from it.
        band:SetPoint("RIGHT", value, "RIGHT", 10 - tokens.bandInset, 0)
        band:SetSize(math.max(0, (host:GetWidth() or 0) - 2 * tokens.bandInset), tokens.bandHeight)
        band:Show()
    elseif band then
        band:Hide()
    end
    return true
end

-- Character-panel row (Label, Value, Icon, LeftLine, RightLine): a row is
-- reused for headers and stats, so each call also clears the other kind's art.
function StatStyle:Apply(row, data, bandIndex, tokens, glyph)
    if data.type == "header" then
        self:Row(row, row.Label, row.Value, 0, nil, row.Icon)
        return self:Header(row, row.Label, { row.LeftLine, row.RightLine }, tokens)
    end
    self:Header(row, row.Label, nil, nil)
    return self:Row(row, row.Label, row.Value, bandIndex, tokens, row.Icon, glyph)
end

-- Extra height the PvP badge needs under the item level, compared with the
-- plain "PvP: N" line (the character panel and the preview both reserve it).
StatStyle.PVP_BADGE_EXTRA = 20
local BADGE_ICON, BADGE_GAP = 26, 6

-- Sets an atlas glyph on a texture (tinted like the style's stat icons).
-- coords: the atlas' texcoord lookup (default: the stat atlas).
local function Glyph(tex, icons, name, coords)
    local l, r, t, b
    if icons then l, r, t, b = (coords or ns.ArmoryStyles.GlyphCoords)(ns.ArmoryStyles, name) end
    if not l then return false end
    tex:SetTexture(icons.atlas)
    tex:SetTexCoord(l, r, t, b)
    if icons.tint then tex:SetVertexColor(Color(icons.tint)) else tex:SetVertexColor(1, 1, 1) end
    return true
end

-- PvP badge under the item level: the style's PvP icon, with a small "PVP"
-- over the value on its right; the whole group centred on the item level.
local function DrawPvp(host, parts, color, tokens)
    local badge = host._ktPvp
    if not badge then
        badge = { icon = host:CreateTexture(nil, "ARTWORK"), label = host:CreateFontString(nil, "OVERLAY") }
        host._ktPvp = badge
    end
    local pvp = parts.pvp
    local r, g, b = Color(color)
    local text = pvp:GetText() or ""
    text = text:match("([%d%.,]+)%s*$") or text
    pvp:SetText(text)
    SetText(pvp, tokens.font, 13, tokens.flags, tokens.shadow)
    pvp:SetTextColor(r, g, b)
    pvp:SetJustifyH("LEFT")
    SetText(badge.label, tokens.font, 7, tokens.flags, tokens.shadow)
    badge.label:SetText(PVP_LABEL)
    badge.label:SetTextColor(r * 0.8, g * 0.8, b * 0.8)

    local total = BADGE_ICON + BADGE_GAP + math.max(pvp:GetStringWidth() or 0, badge.label:GetStringWidth() or 0)
    badge.icon:ClearAllPoints()
    badge.icon:SetSize(BADGE_ICON, BADGE_ICON)
    badge.icon:SetPoint("TOPLEFT", parts.value, "BOTTOM", -total / 2, -4)
    if Glyph(badge.icon, tokens.icons, "pvp") then badge.icon:Show() else badge.icon:Hide() end
    badge.label:ClearAllPoints()
    badge.label:SetPoint("TOPLEFT", badge.icon, "TOPRIGHT", BADGE_GAP, -3)
    badge.label:Show()
    pvp:ClearAllPoints()
    pvp:SetPoint("TOPLEFT", badge.label, "BOTTOMLEFT", 0, -1)
end

local function HidePvp(host)
    local badge = host._ktPvp
    if badge then
        badge.icon:Hide()
        badge.label:Hide()
    end
end

-- Item level block: parts = { title, lines = {...}, value, pvp }. The
-- caller has already set the title, value and PvP texts for this refresh.
function StatStyle:ItemLevel(host, parts, tokens)
    local ilvl = tokens and tokens.ilvl
    if not ilvl then
        HidePvp(host)
        ClearShadow(parts.title)
        Caps(parts.title, false)
        return false
    end
    SetText(parts.title, ilvl.font, ilvl.size, ilvl.flags, tokens.shadow)
    Caps(parts.title, ilvl.caps)
    parts.title:SetTextColor(Color(ilvl.title))
    for _, line in ipairs(parts.lines or {}) do
        line:Hide()
    end
    if parts.pvp and parts.pvp:IsShown() and tokens.pvp then
        DrawPvp(host, parts, tokens.pvp, tokens)
    else
        HidePvp(host)
    end
    return true
end

-- One button of the Stats/Titles/Equipment/Progress bar as an icon tab
-- (tokens.tabs). key: stats|titles|equipment|progress. The caller keeps its
-- text label (btn.lbl) and backdrop; without tokens they come back.
function StatStyle:TabButton(btn, key, active, tokens)
    local tabs = tokens and tokens.tabs
    local art = btn._ktTab
    if not tabs then
        if art then HideAll(art) end
        if btn.lbl then btn.lbl:Show() end
        btn._ktStyled = nil
        return false
    end
    if not art then
        art = { glow = btn:CreateTexture(nil, "BACKGROUND", nil, 1), icon = btn:CreateTexture(nil, "ARTWORK"), mark = btn:CreateTexture(nil, "OVERLAY") }
        btn._ktTab = art
    end
    btn._ktStyled = true
    if btn.lbl then btn.lbl:Hide() end
    btn:SetSize(tabs.size, tabs.size)
    local r, g, b = Color(tabs.accent)
    local square = tabs.kind == "square"
    local inset = square and 4 or 0

    art.icon:ClearAllPoints()
    art.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    art.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset + (square and 1 or 0))
    if Glyph(art.icon, tokens.icons, "tab_" .. key) then art.icon:Show() else art.icon:Hide() end
    if square then
        -- Dark plate (the caller's backdrop), accent icon and underline when active.
        if active then
            art.icon:SetVertexColor(r, g, b)
        else
            art.icon:SetVertexColor(0.6, 0.6, 0.62)
        end
        art.mark:ClearAllPoints()
        art.mark:SetColorTexture(r, g, b, 1)
        art.mark:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 4, 2)
        art.mark:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 2)
        art.mark:SetHeight(2)
        if active then art.mark:Show() else art.mark:Hide() end
        art.glow:Hide()
    else
        -- The medallion / tile is the button: full colour and a glow when active.
        if not active then art.icon:SetVertexColor(0.55, 0.55, 0.55) end
        art.glow:ClearAllPoints()
        if tabs.kind == "medallion" then
            art.glow:SetTexture(ROUND_GLOW)
            art.glow:SetVertexColor(r, g, b, 0.45)
        else
            art.glow:SetColorTexture(r, g, b, 0.35)
        end
        art.glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
        art.glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
        if active then art.glow:Show() else art.glow:Hide() end
        art.mark:Hide()
    end
    return true
end

-- Class tokens whose ClassIcon_<Name> file is not just the capitalised token.
local CLASS_ICON_NAMES = { DEATHKNIGHT = "DeathKnight", DEMONHUNTER = "DemonHunter" }

-- Header corner: the square Interface\Icons\ClassIcon_<Class> art (both
-- clients ship it), framed with the style's slot frame when it has one.
function StatStyle:ClassIcon(host, icon, class, slotFrame)
    if type(class) ~= "string" or class == "" then return false end
    local name = CLASS_ICON_NAMES[class] or (class:sub(1, 1) .. class:sub(2):lower())
    icon:SetTexture([[Interface\Icons\ClassIcon_]] .. name)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local frame = host._ktClassFrame
    if not slotFrame then
        if frame then frame:Hide() end
        return true
    end
    if not frame then
        frame = host:CreateTexture(nil, "OVERLAY", nil, 7)
        host._ktClassFrame = frame
    end
    local width, height = icon:GetSize()
    frame:SetTexture(slotFrame.frame)
    frame:SetTexCoord(0, 1, 0, 1)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", icon, "CENTER")
    frame:SetSize((width or 0) * slotFrame.scale, (height or 0) * slotFrame.scale)
    frame:Show()
    return true
end

-- Puts one of the style's atlas glyphs on a texture (e.g. the background
-- selector button). Returns false without tokens or for an unknown glyph.
function StatStyle:SetGlyph(tex, tokens, name)
    return tokens and Glyph(tex, tokens.icons, name) or false
end

-- Same for the Progress page icons (keystone, vault, raid, world, clock,
-- check, star, lock) from the style's progress atlas.
function StatStyle:SetProgressGlyph(tex, tokens, name)
    return tokens and Glyph(tex, tokens.progress, name, ns.ArmoryStyles.ProgressCoords) or false
end

-- Resolves a token colour ({r, g, b} or "accent") for callers outside this file.
StatStyle.ResolveColor = Color

ns.ArmoryStatStyle = StatStyle
