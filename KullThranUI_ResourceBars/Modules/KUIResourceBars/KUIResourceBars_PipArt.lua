-- Resource Bars: the class resource drawn with its own pieces instead of plain balls,
-- as the nameplates and unit frames already do.
--
-- Pip Style (db.secondary.pipStyle), unset = follow the Visual Style:
--   "pip"     flat pips (KUI Style)
--   "circle"  KUI's own round points (Classic style, Classic art kit)
--   "retail"  Retail's points (silver socket)
--   "forever" Forever's points (bronze socket)
-- With any style but "pip":
--   * Soul Shards, Holy Power, Chi, Essence, Arcane Charges and Runes draw their piece:
--     the client's own atlas when it has one, KUI's bundled piece otherwise.
--   * Combo points draw the chosen style's socket with the gem on top when lit.
--   * Every other pip resource (Maelstrom Weapon, Soul Fragments...) stays a pip,
--     round for "circle" / "forever".
local _, ns = ...

local PipArt = {}
ns.PipArt = PipArt

local PORTRAITS = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local PIECES = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\OptionCards\\"

local STYLES = { pip = true, circle = true, retail = true, forever = true }
PipArt.STYLES = STYLES

--- The style in use. `theme` is the rendered Visual Style, `frameArtKit` the bars' frame art.
function PipArt.ResolveStyle(secondary, theme, frameArtKit)
    local chosen = secondary and secondary.pipStyle
    if STYLES[chosen] then return chosen end
    if theme == "retail" or theme == "forever" then return theme end
    if theme == "classic" or frameArtKit == "classic" then return "circle" end
    return "pip"
end

-- Class resource pieces, keyed by Enum.PowerType field. `ready` / `empty` are the
-- client's atlases (%d = pip index where the art differs per pip); `file` is KUI's piece
-- for a client without them; `color` tints that piece.
local PIECE_BY_POWER = {
    SoulShards = { ready = "Warlock-ReadyShard", empty = "Warlock-EmptyShard",
        file = "cp_shard.png", color = { 0.62, 0.38, 0.95 } },
    HolyPower = { ready = "nameplates-holypower%d-on", empty = "nameplates-holypower%d-off",
        file = "cp_holy.png", color = { 1.00, 0.82, 0.28 } },
    Chi = { ready = "uf-chi-icon", empty = "uf-chi-bg",
        file = "cp_chi.png", color = { 0.35, 1.00, 0.72 } },
    Essence = { ready = "UF-Essence-Icon", empty = "UF-Essence-BG",
        file = "cp_essence.png", color = { 0.30, 0.85, 0.85 } },
    ArcaneCharges = { ready = "Mage-ArcaneCharge",
        file = "cp_arcane.png", color = { 0.45, 0.60, 1.00 } },
    Runes = { empty = "DK-Rune-CD",
        file = "cp_rune.png", color = { 0.35, 0.75, 1.00 } },
}
-- Runes take the spec's own rune and colour.
local RUNE_BY_SPEC = {
    [250] = { "DK-Blood-Rune-Ready", 1.00, 0.22, 0.22 },
    [251] = { "DK-Frost-Rune-Ready", 0.35, 0.75, 1.00 },
    [252] = { "DK-Unholy-Rune-Ready", 0.40, 0.95, 0.40 },
}

-- Combo point sockets and gems by file and crop (left, top, right, bottom in pixels):
-- SetAtlas would give the running client's variant, never the other client's.
local COMBO_ART = {
    retail = { file = 4902602, w = 1024, h = 1024, on = { 593, 1, 633, 41 }, off = { 593, 127, 633, 167 },
        gem = { 549, 225, 577, 254 }, gemSize = 28 / 40 },
    forever = { file = 8474117, w = 1024, h = 512, on = { 1, 387, 45, 431 }, off = { 1, 433, 45, 477 },
        gem = { 31, 479, 59, 507 }, gemSize = 28 / 44 },
    circle = { file = PORTRAITS .. "kui_combo.png", w = 128, h = 64, on = { 0, 0, 64, 64 }, off = { 0, 0, 64, 64 },
        gem = { 64, 0, 128, 64 }, gemSize = 1, tinted = true },
}

local function AtlasSize(name)
    local api = C_Texture
    local info = name and api and api.GetAtlasInfo and api.GetAtlasInfo(name)
    if info and info.width and info.height and info.height > 0 then return info.width, info.height end
end

local function Pattern(atlas, index)
    return atlas and atlas:format(index or 1)
end

--- The piece of a class resource (a PT value), or nil when it has none.
--- `specID` picks the rune. The result is shared: do not modify it.
local pieceCache = {}
function PipArt.Piece(powerType, specID)
    local types = Enum and Enum.PowerType
    if powerType == nil or not types then return nil end
    for name, def in pairs(PIECE_BY_POWER) do
        if types[name] == powerType then
            local ready, r, g, b = def.ready, def.color[1], def.color[2], def.color[3]
            if name == "Runes" then
                local spec = RUNE_BY_SPEC[specID]
                if spec then ready, r, g, b = spec[1], spec[2], spec[3], spec[4] end
            end
            local key = name .. ":" .. tostring(ready)
            local piece = pieceCache[key]
            if not piece then
                local w, h = AtlasSize(Pattern(ready, 1))
                piece = {
                    ready = w and ready or nil,
                    empty = w and def.empty and AtlasSize(Pattern(def.empty, 1)) and def.empty or nil,
                    file = PIECES .. def.file,
                    aspect = w and (w / h) or 1,
                    r = r, g = g, b = b,
                }
                pieceCache[key] = piece
            end
            return piece
        end
    end
end

function PipArt.Combo(style)
    return COMBO_ART[style]
end

local function SetCrop(tex, art, crop)
    tex:SetTexture(art.file)
    tex:SetTexCoord(crop[1] / art.w, crop[3] / art.w, crop[2] / art.h, crop[4] / art.h)
end

local function Layer(pip, key, layer, sublevel)
    local tex = pip[key]
    if not tex then
        tex = pip:CreateTexture(nil, layer, nil, sublevel)
        tex:SetAllPoints(pip)
        pip[key] = tex
    end
    return tex
end

--- What a recharge or partial bar of this pip should be filled with.
function PipArt.FillTexture(pip)
    return pip and pip._ktArtFill
end

--- Hides the art layers so the pip goes back to its flat look.
function PipArt.Clear(pip)
    if not pip then return end
    if pip._ktArtBack then pip._ktArtBack:Hide() end
    if pip._ktArtLit then pip._ktArtLit:Hide() end
    if pip._ktArtGem then pip._ktArtGem:Hide() end
    pip._ktArt, pip._ktArtFill, pip._ktArtState = nil, nil, nil
end

-- Paints one texture with the piece. `lit` picks the ready art; an empty piece without
-- its own atlas is the ready art dimmed. `tint` recolours (desaturated) when given.
local function PaintPiece(tex, piece, index, lit, tr, tg, tb)
    local atlas = Pattern(lit and piece.ready or piece.empty or piece.ready, index)
    if piece.ready and AtlasSize(atlas) then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetAtlas(atlas, false)
        tex:SetDesaturated(tr ~= nil)
        local dim = (not lit and not piece.empty) and 0.3 or 1
        if tr then
            tex:SetVertexColor(tr * dim, tg * dim, tb * dim, 1)
        else
            tex:SetVertexColor(dim, dim, dim, 1)
        end
        return atlas
    end
    tex:SetDesaturated(false)
    tex:SetTexture(piece.file)
    tex:SetTexCoord(0, 1, 0, 1)
    local r, g, b = tr or piece.r, tg or piece.g, tb or piece.b
    if lit then
        tex:SetVertexColor(r, g, b, 1)
    else
        tex:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.9)
    end
    return piece.file
end

--- Seats a class resource piece on a pip: the empty piece behind, the lit one in front.
--- tr/tg/tb tint it (a custom colour); nil keeps the client's art colours.
function PipArt.ApplyPiece(pip, piece, index, tr, tg, tb)
    local back = Layer(pip, "_ktArtBack", "BACKGROUND", 1)
    local lit = Layer(pip, "_ktArtLit", "ARTWORK", 2)
    PaintPiece(back, piece, index, false, tr, tg, tb)
    pip._ktArtFill = PaintPiece(lit, piece, index, true, tr, tg, tb)
    back:Show()
    if pip._ktArtGem then pip._ktArtGem:Hide() end
    pip._ktArt, pip._ktArtState = piece, nil
end

--- Seats a combo point socket and its gem. The gem takes r/g/b when the art is tinted
--- (KUI's own points), red otherwise.
function PipArt.ApplyCombo(pip, art)
    local socket = Layer(pip, "_ktArtBack", "ARTWORK", 1)
    SetCrop(socket, art, art.off)
    socket:SetDesaturated(false)
    socket:SetVertexColor(1, 1, 1, 1)
    socket:Show()
    local gem = pip._ktArtGem
    if not gem then
        gem = pip:CreateTexture(nil, "ARTWORK", nil, 3)
        pip._ktArtGem = gem
    end
    gem:ClearAllPoints()
    gem:SetPoint("CENTER", pip, "CENTER", 0, 0)
    local w, h = pip:GetWidth() or 16, pip:GetHeight() or 16
    gem:SetSize(w * art.gemSize, h * art.gemSize)
    SetCrop(gem, art, art.gem)
    gem:Hide()
    if pip._ktArtLit then pip._ktArtLit:Hide() end
    pip._ktArt, pip._ktArtFill, pip._ktArtState = art, art.file, nil
end

--- Shows a pip lit or empty. Returns false when the pip carries no art.
function PipArt.SetLit(pip, lit, r, g, b)
    local art = pip and pip._ktArt
    if not art then return false end
    lit = lit and true or false
    if art.gem then
        if pip._ktArtState ~= lit then
            SetCrop(pip._ktArtBack, art, lit and art.on or art.off)
        end
        local gem = pip._ktArtGem
        if art.tinted then gem:SetVertexColor(r or 1, g or 0.05, b or 0.05, 1) end
        gem:SetShown(lit)
    else
        pip._ktArtLit:SetShown(lit)
    end
    pip._ktArtState = lit
    return true
end

--- Size of one pip for a style: width, height, spacing and whether it is round.
--- `pipHeight` is the section's Height; `art` the piece or combo art (or nil).
function PipArt.Geometry(style, pipHeight, spacing, piece, combo)
    if piece then
        local h = pipHeight * 1.5
        return h * piece.aspect, h, spacing + 2, false
    end
    if combo then
        local size = pipHeight * 1.4
        return size, size, spacing + 2, false
    end
    if style == "circle" or style == "forever" then
        local size = pipHeight * 1.15
        return size, size, spacing, true
    end
    return nil, pipHeight, spacing, false
end
