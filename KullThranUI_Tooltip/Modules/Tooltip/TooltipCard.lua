-- Modules/Tooltip/TooltipCard.lua
-- Optional card style for item and spell tooltips (off by default).
--
-- The tooltip's own lines are read as structured data and turned into a small
-- model (header, chips, weapon summary or spell grid, body, price). A card frame
-- inside the tooltip draws that model. The tooltip keeps doing its own layout:
-- it is widened and padded to the card's size and only made transparent, so its
-- anchor, screen clamping and comparison tooltips behave as usual.
--
-- Retail: tooltips carry secret values in combat and in instances. Every read
-- from tooltip data, item/spell info and font strings is checked; on any secret
-- value the card is dropped and the tooltip keeps its usual look.
local KT =LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end
local LSM = LibStub("LibSharedMedia-3.0", true)

local Card = {}
KT.TooltipCard = Card

local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

local _G = _G
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format, strtrim = string.format, strtrim
local issecretvalue = _G.issecretvalue
local canaccessvalue = _G.canaccessvalue

-- Secret values cannot be indexed, compared or measured from addon code.
-- Same test as Tooltip.lua's StripSecretValue.
local function IsSecret(value)
    if value == nil then return false end
    if issecretvalue and issecretvalue(value) then return true end
    if canaccessvalue and not canaccessvalue(value) then return true end
    return false
end

-- A plain number, or nil (secret or not a number).
local function Num(value)
    if type(value) ~= "number" or IsSecret(value) then return nil end
    return value
end

-- Measurements must be plain numbers; a secret one aborts the card (callers pcall).
local function Measure(value)
    local n = Num(value)
    if not n then error("TooltipCard: secret or missing size", 2) end
    return n
end

-- Returns a pcall'd call's values with secret ones turned into nil.
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if not ok then return nil end
    local out = { a, b, c, d, e, f, g, h, i, j }
    for k = 1, 10 do
        if IsSecret(out[k]) then out[k] = nil end
    end
    return out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8], out[9], out[10]
end

-- ---------------------------------------------------------------- look
local CARD_WIDTH = 290
local PAD = 14
local ICON_SIZE = 40
local BG = { 0.051, 0.055, 0.067, 0.97 }
local EDGE = { 0.19, 0.204, 0.235 }
local MUTED = { 0.59, 0.61, 0.66 }
local BRIGHT = { 0.925, 0.94, 0.965 }
local BODY = { 0.84, 0.855, 0.886 }
local DANGER = { 1, 0.52, 0.47 }
local EFFECT = { 0.38, 0.91, 0.47 }
local MANA_BLUE = { 0.47, 0.69, 1 }
local SPELL_ACCENT = { 0.32, 0.62, 1 }

-- ---------------------------------------------------------------- text helpers
local function Clean(text)
    if type(text) ~= "string" or IsSecret(text) then return nil end
    local ok, out = pcall(strtrim, text)
    if not ok or out == "" then return nil end
    return out
end

-- A Blizzard format template ("%s - %s Damage") as an anchored Lua pattern.
local patternCache = {}
local function TemplatePattern(template)
    if type(template) ~= "string" or template == "" then return nil end
    local cached = patternCache[template]
    if cached ~= nil then return cached or nil end
    local p = template:gsub("%%%d*%$?[%-%d%.]*[sdfg]", "\001")
    p = p:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = "^" .. p:gsub("\001", "(.-)") .. "$"
    patternCache[template] = p
    return p
end

local function MatchTemplate(text, template)
    if not text then return nil end
    local p = TemplatePattern(template)
    if not p then return nil end
    return text:match(p)
end

local function MatchesAny(text, names)
    if not text then return false end
    for _, name in ipairs(names) do
        local template = _G[name]
        if type(template) == "string" then
            if text == template or (template:find("%", 1, true) and MatchTemplate(text, template)) then
                return true
            end
        end
    end
    return false
end

local function LastNumber(text)
    return text and text:match("([%d%.,]+)%s*$") or nil
end

local function TemplateWords(template)
    if type(template) ~= "string" then return nil end
    local words = template:gsub("%%%d*%$?[%-%d%.]*[sdfg]", ""):gsub("[%(%)]", "")
    words = strtrim(words)
    return words ~= "" and words or nil
end

local function IsWhite(c) return c[1] > 0.95 and c[2] > 0.95 and c[3] > 0.95 end
local function IsRed(c) return c[1] > 0.9 and c[2] < 0.35 and c[3] < 0.35 end
local function IsGreen(c) return c[2] > 0.85 and c[1] < 0.35 and c[3] < 0.35 end
local function IsGold(c) return c[1] > 0.95 and c[2] > 0.7 and c[2] < 0.9 and c[3] < 0.15 end

-- r, g, b as a table, or nil when any of them is secret.
local function PlainRGB(r, g, b)
    r, g, b = Num(r), Num(g), Num(b)
    if r and g and b then return { r, g, b } end
    return nil
end

local function ColorOf(color, fallback)
    if type(color) == "table" and not IsSecret(color) then
        local rgb
        if color.GetRGB then
            local ok, r, g, b = pcall(color.GetRGB, color)
            if ok then rgb = PlainRGB(r, g, b) end
        else
            rgb = PlainRGB(color.r, color.g, color.b)
        end
        if rgb then return rgb end
    end
    return { fallback[1], fallback[2], fallback[3] }
end

-- True when a color table holds a secret channel: the line is then unreadable.
local function SecretColor(color)
    if color == nil then return false end
    if IsSecret(color) then return true end
    if type(color) ~= "table" then return false end
    return IsSecret(color.r) or IsSecret(color.g) or IsSecret(color.b)
end

-- ---------------------------------------------------------------- reading lines
local SELL_PRICE_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice or 11
local BLANK_TYPE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.Blank or 1

local SECRET_FIELDS = { "leftText", "rightText", "leftColor", "rightColor", "type", "price" }

-- nil when the data holds secret values: the tooltip then keeps its usual look.
local function ReadDataLines(data)
    local out = {}
    if IsSecret(data) then return nil end
    if type(data) ~= "table" or IsSecret(data.lines) or type(data.lines) ~= "table" then return out end
    for _, line in ipairs(data.lines) do
        if IsSecret(line) or type(line) ~= "table" then return nil end
        for _, field in ipairs(SECRET_FIELDS) do
            if IsSecret(line[field]) then return nil end
        end
        if SecretColor(line.leftColor) or SecretColor(line.rightColor) then return nil end
        out[#out + 1] = {
            left = Clean(line.leftText),
            right = Clean(line.rightText),
            lc = ColorOf(line.leftColor, BRIGHT),
            rc = ColorOf(line.rightColor, BRIGHT),
            price = line.type == SELL_PRICE_TYPE and tonumber(line.price) or nil,
            blank = line.type == BLANK_TYPE,
        }
    end
    return out
end

-- One tooltip font string: text and color, or secret = true when either is secret.
local function ReadFontString(fs)
    if not fs then return nil, nil end
    local shown = fs:IsShown()
    if IsSecret(shown) then return nil, nil, true end
    if not shown then return nil, nil end
    local text = fs:GetText()
    if IsSecret(text) then return nil, nil, true end
    local rgb = PlainRGB(fs:GetTextColor())
    if not rgb then return nil, nil, true end
    return Clean(text), rgb
end

-- Lines other addons (or the module itself) appended after the game's data.
-- nil when any of them holds a secret value: the card would hide that line.
local function ReadExtraLines(tooltip, first)
    local out = {}
    local name = tooltip:GetName()
    if type(name) ~= "string" or IsSecret(name) then return out end
    local count = Num(tooltip:NumLines())
    if not count then return nil end
    for i = first, count do
        local entry = { lc = { 1, 1, 1 }, rc = { 1, 1, 1 } }
        local text, rgb, secret = ReadFontString(_G[name .. "TextLeft" .. i])
        if secret then return nil end
        entry.left, entry.lc = text, rgb or entry.lc
        text, rgb, secret = ReadFontString(_G[name .. "TextRight" .. i])
        if secret then return nil end
        entry.right, entry.rc = text, rgb or entry.rc
        out[#out + 1] = entry
    end
    return out
end

-- ---------------------------------------------------------------- models
local BIND_LINES = {
    "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_USE", "ITEM_SOULBOUND",
    "ITEM_BIND_QUEST", "ITEM_BIND_TO_ACCOUNT", "ITEM_BIND_TO_BNETACCOUNT", "ITEM_ACCOUNTBOUND",
    "ITEM_BNETACCOUNTBOUND", "ITEM_UNIQUE", "ITEM_UNIQUE_EQUIPPABLE", "ITEM_CONJURED",
    -- Retail: Warbound and "Unique (n)" lines.
    "ITEM_ACCOUNTBOUND_UNTIL_EQUIP", "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP", "ITEM_UNIQUE_MULTIPLE",
}
local CAST_LINES = {
    "SPELL_CAST_TIME_INSTANT", "SPELL_CAST_TIME_INSTANT_NO_MANA", "SPELL_CAST_TIME_SEC",
    "SPELL_CAST_TIME_MIN", "SPELL_CAST_CHANNELED", "SPELL_ON_NEXT_SWING", "SPELL_ON_NEXT_RANGED",
    "SPELL_CAST_TIME_RANGED",
}
local COOLDOWN_LINES = {
    "SPELL_RECAST_TIME_SEC", "SPELL_RECAST_TIME_MIN", "SPELL_RECAST_TIME_HOURS",
    "SPELL_RECAST_TIME_DAYS", "SPELL_RECAST_TIME_CHARGES_SEC", "SPELL_RECAST_TIME_CHARGES_MIN",
}
local RANGE_LINES = {
    "SPELL_RANGE", "SPELL_RANGE_AREA", "SPELL_RANGE_DUAL", "MELEE_RANGE", "SPELL_RANGE_UNLIMITED",
}

local function BodyLine(line)
    local lc = line.lc
    return {
        left = line.left, right = line.right, lc = lc, rc = line.rc,
        bullet = IsGreen(lc) and line.left ~= nil,
    }
end

-- lines: as read above. meta: name/icon/subType/equipName/itemLevel/equippable.
function Card:BuildItemModel(lines, meta)
    if not lines[1] or not lines[1].left then return nil end
    meta = meta or {}
    local model = {
        kind = "item",
        icon = meta.icon,
        name = lines[1].left,
        nameColor = lines[1].lc,
        accent = lines[1].lc,
        chips = {}, tiles = {}, lines = {},
    }
    local hero, heroLine
    for i = 2, #lines do
        local line = lines[i]
        local left, right = line.left, line.right
        if line.price then
            model.price = line.price
        elseif line.blank or (not left and not right) then
            -- spacing lines carry nothing in the card
        elseif not right and MatchTemplate(left, _G.ITEM_LEVEL) then
            model.badge = MatchTemplate(left, _G.ITEM_LEVEL)
        elseif not right and MatchesAny(left, BIND_LINES) then
            model.chips[#model.chips + 1] = { text = left }
        elseif not right and MatchTemplate(left, _G.ITEM_MIN_LEVEL) then
            model.chips[#model.chips + 1] = { text = left, danger = IsRed(line.lc) }
        elseif not model.subtitle and i <= 7 and meta.equipName
            and (left == meta.equipName or (right and right == meta.subType)) then
            model.subtitle = right and (right .. " \194\183 " .. left) or left
        elseif not hero and right and MatchTemplate(left, _G.DAMAGE_TEMPLATE) then
            local low, high = MatchTemplate(left, _G.DAMAGE_TEMPLATE)
            hero = { dmg = low .. " \226\128\147 " .. high, speed = LastNumber(right) or right }
            heroLine = line
        elseif not hero and right and MatchTemplate(left, _G.SINGLE_DAMAGE_TEMPLATE) then
            hero = { dmg = MatchTemplate(left, _G.SINGLE_DAMAGE_TEMPLATE), speed = LastNumber(right) or right }
            heroLine = line
        elseif hero and not hero.dps and not right and MatchTemplate(left, _G.DPS_TEMPLATE) then
            hero.dps = MatchTemplate(left, _G.DPS_TEMPLATE)
        else
            model.lines[#model.lines + 1] = BodyLine(line)
        end
    end
    if hero and hero.dps then
        hero.dpsLabel = TemplateWords(_G.DPS_TEMPLATE) or "DPS"
        hero.dmgLabel = _G.DAMAGE or "Damage"
        hero.speedLabel = _G.SPEED or "Speed"
        model.hero = hero
    elseif heroLine then
        table.insert(model.lines, 1, BodyLine(heroLine))
    end
    if not model.subtitle then
        if meta.equipName and meta.subType and meta.subType ~= meta.equipName then
            model.subtitle = meta.subType .. " \194\183 " .. meta.equipName
        else
            model.subtitle = meta.subType or meta.itemType
        end
    end
    if not model.badge and meta.equippable and tonumber(meta.itemLevel) and tonumber(meta.itemLevel) > 1 then
        model.badge = tostring(meta.itemLevel)
    end
    model.subColor = MUTED
    local sell = type(_G.SELL_PRICE) == "string" and _G.SELL_PRICE or "Sell Price"
    sell = sell:gsub("%s*:%s*$", "")
    sell = sell:gsub("\239\188\154$", "")
    model.priceLabel = sell
    return model
end

local function TileFor(text)
    local tile = { text = text, color = BRIGHT }
    if MatchesAny(text, CAST_LINES) then
        tile.label = LText("Cast")
    elseif MatchesAny(text, COOLDOWN_LINES) then
        tile.label = LText("Cooldown")
    elseif MatchesAny(text, RANGE_LINES) then
        tile.label = LText("Range")
    elseif text:find("%d") then
        tile.label = LText("Cost")
        local mana = _G.MANA
        if type(mana) == "string" and text:lower():find(mana:lower(), 1, true) then tile.color = MANA_BLUE end
    end
    return tile
end

function Card:BuildSpellModel(lines, meta)
    if not lines[1] or not lines[1].left then return nil end
    meta = meta or {}
    local model = {
        kind = "spell",
        icon = meta.icon,
        name = lines[1].left,
        nameColor = BRIGHT,
        accent = SPELL_ACCENT,
        subtitle = lines[1].right,
        subColor = { 0.55, 0.76, 1 },
        chips = {}, tiles = {}, lines = {},
    }
    local i = 2
    -- Cost, range, cast time and cooldown are the short white lines under the name.
    while i <= #lines and #model.tiles < 6 do
        local line = lines[i]
        if line.blank or not line.left or not IsWhite(line.lc) or (not line.right and #line.left > 40) then break end
        model.tiles[#model.tiles + 1] = TileFor(line.left)
        if line.right then model.tiles[#model.tiles + 1] = TileFor(line.right) end
        i = i + 1
    end
    for j = i, #lines do
        local line = lines[j]
        if not line.blank and (line.left or line.right) then
            local body = BodyLine(line)
            if IsGold(body.lc) then body.lc = BODY end
            model.lines[#model.lines + 1] = body
        end
    end
    return model
end

-- ---------------------------------------------------------------- drawing
local function FontPath()
    local db = KT.db and KT.db.profile and KT.db.profile.tooltip
    local path = db and LSM and db.font and LSM:Fetch("font", db.font, true)
    return path or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", (db and db.fontSize) or 12
end

local function SetHGradient(tex, c, a1, a2)
    tex:SetColorTexture(1, 1, 1, 1)
    if tex.SetGradient and _G.CreateColor then
        local ok = pcall(tex.SetGradient, tex, "HORIZONTAL", CreateColor(c[1], c[2], c[3], a1), CreateColor(c[1], c[2], c[3], a2))
        if ok then return end
    end
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], a1, c[1], c[2], c[3], a2)
    else
        tex:SetColorTexture(c[1], c[2], c[3], (a1 + a2) / 2)
    end
end

local function Reset(card)
    for i = 1, card._tex.n do card._tex[i]:Hide() end
    for i = 1, card._fs.n do card._fs[i]:Hide() end
    card._tex.n, card._fs.n = 0, 0
end

local function Tex(card, layer, sub)
    local pool = card._tex
    pool.n = pool.n + 1
    local t = pool[pool.n]
    if not t then
        t = card:CreateTexture(nil, "ARTWORK")
        pool[pool.n] = t
    end
    t:SetDrawLayer(layer or "ARTWORK", sub or 0)
    t:ClearAllPoints()
    t:SetTexCoord(0, 1, 0, 1)
    t:SetVertexColor(1, 1, 1, 1)
    t:Show()
    return t
end

local function Solid(card, layer, sub, c, a)
    local t = Tex(card, layer, sub)
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    return t
end

local function Text(card, size, c, justify, fontPath)
    local pool = card._fs
    pool.n = pool.n + 1
    local fs = pool[pool.n]
    if not fs then
        fs = card:CreateFontString(nil, "OVERLAY")
        pool[pool.n] = fs
    end
    fs:SetFont(fontPath or FontPath(), size, "")
    fs:SetTextColor(c[1], c[2], c[3], 1)
    fs:SetShadowColor(0, 0, 0, 0.85)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(false)
    if fs.SetMaxLines then fs:SetMaxLines(0) end
    fs:SetWidth(0)
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local function At(region, card, x, y)
    region:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
end

local function Divider(card, y, w)
    local t = Tex(card, "ARTWORK", 1)
    t:SetHeight(1)
    t:SetWidth(w - PAD * 2)
    At(t, card, PAD, y)
    SetHGradient(t, { 1, 1, 1 }, 0.16, 0)
end

local function CoinText(copper, size)
    if not copper or copper <= 0 then return nil end
    if _G.GetCoinTextureString then
        local ok, text = pcall(GetCoinTextureString, copper, size)
        if ok and text then return text end
    end
    return format("%dg %ds %dc", floor(copper / 10000), floor(copper / 100) % 100, copper % 100)
end

function Card:CreateFrame(parent)
    local card = CreateFrame("Frame", nil, parent)
    card._tex, card._fs = { n = 0 }, { n = 0 }
    card:Hide()
    return card
end

-- Draws the model at width w; returns the height the card needs.
function Card:Render(card, model, w)
    w = w or CARD_WIDTH
    Reset(card)
    local _, base = FontPath()
    local accent = model.accent or SPELL_ACCENT
    local small, body, title = max(8, base - 4), max(9, base - 1), base + 3

    -- frame
    Solid(card, "BACKGROUND", -8, EDGE):SetAllPoints(card)
    local bg = Solid(card, "BACKGROUND", -7, BG, BG[4])
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    local shine = Solid(card, "BACKGROUND", -6, { 1, 1, 1 }, 0.08)
    shine:SetPoint("TOPLEFT", 1, -1)
    shine:SetPoint("TOPRIGHT", -1, -1)
    shine:SetHeight(1)
    local stripe = Solid(card, "BORDER", 0, accent)
    stripe:SetPoint("TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT")
    stripe:SetWidth(3)
    local glow = Tex(card, "BORDER", 1)
    glow:SetPoint("TOPLEFT", 3, -1)
    glow:SetSize(min(130, w - 4), 62)
    SetHGradient(glow, accent, 0.18, 0)

    -- header
    local iconEdge = Solid(card, "ARTWORK", 0, accent)
    iconEdge:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    At(iconEdge, card, PAD - 1, PAD - 1)
    local icon = Tex(card, "ARTWORK", 1)
    icon:SetTexture(model.icon or 134400)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    At(icon, card, PAD, PAD)

    local textX = PAD + ICON_SIZE + 10
    local reserve = PAD
    if model.badge then
        reserve = 58
        local pill = Solid(card, "ARTWORK", 0, accent)
        pill:SetSize(38, 17)
        pill:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -13)
        local inner = Solid(card, "ARTWORK", 1, { accent[1] * 0.25, accent[2] * 0.25, accent[3] * 0.25 })
        inner:SetPoint("TOPLEFT", pill, "TOPLEFT", 1, -1)
        inner:SetPoint("BOTTOMRIGHT", pill, "BOTTOMRIGHT", -1, 1)
        local level = Text(card, body + 1, BRIGHT, "CENTER")
        level:SetPoint("CENTER", pill, "CENTER", 0, 0)
        level:SetText(model.badge)
        local label = Text(card, max(7, small - 1), MUTED, "RIGHT")
        label:SetPoint("TOPRIGHT", pill, "BOTTOMRIGHT", 0, -3)
        label:SetText(LText("Item level"))
    end

    local name = Text(card, title, model.nameColor or BRIGHT)
    name:SetWordWrap(true)
    if name.SetMaxLines then name:SetMaxLines(2) end
    name:SetWidth(w - textX - reserve)
    At(name, card, textX, PAD + 1)
    name:SetText(model.name)
    local headerH = PAD + 1 + Measure(name:GetStringHeight())
    if model.subtitle then
        local sub = Text(card, body, model.subColor or MUTED)
        sub:SetWidth(w - textX - reserve)
        sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        sub:SetText(model.subtitle)
        headerH = headerH + 3 + Measure(sub:GetStringHeight())
    end
    local y = max(PAD + ICON_SIZE, headerH) + 10

    -- chips
    if #model.chips > 0 then
        local x, rowH = PAD, small + 6
        for _, chip in ipairs(model.chips) do
            local label = Text(card, small + 1, chip.danger and DANGER or { 0.77, 0.78, 0.82 })
            label:SetText(chip.text)
            local cw = min(Measure(label:GetStringWidth()) + 14, w - PAD * 2)
            if x > PAD and x + cw > w - PAD then
                x, y = PAD, y + rowH + 5
            end
            local fill = chip.danger and Solid(card, "ARTWORK", 0, DANGER, 0.16) or Solid(card, "ARTWORK", 0, { 1, 1, 1 }, 0.06)
            fill:SetSize(cw, rowH)
            At(fill, card, x, y)
            label:SetWidth(cw - 14)
            label:SetPoint("LEFT", fill, "LEFT", 7, 0)
            x = x + cw + 6
        end
        y = y + rowH + 10
    end

    local sections = {}
    if model.hero then sections[#sections + 1] = "hero" end
    if #model.tiles > 0 then sections[#sections + 1] = "tiles" end
    if #model.lines > 0 then sections[#sections + 1] = "lines" end

    for _, section in ipairs(sections) do
        Divider(card, y, w)
        y = y + 10
        if section == "hero" then
            local hero = model.hero
            local split = floor(w * 0.47)
            local dps = Text(card, base + 12, BRIGHT)
            At(dps, card, PAD, y + 2)
            dps:SetText(hero.dps)
            local dpsLabel = Text(card, max(7, small - 1), MUTED)
            dpsLabel:SetWidth(split - PAD - 6)
            dpsLabel:SetPoint("TOPLEFT", dps, "BOTTOMLEFT", 1, -2)
            dpsLabel:SetText(hero.dpsLabel)
            local line = Solid(card, "ARTWORK", 0, { 1, 1, 1 }, 0.12)
            line:SetSize(1, 38)
            At(line, card, split, y + 2)
            local rows = { { hero.dmgLabel, hero.dmg }, { hero.speedLabel, hero.speed } }
            for r, row in ipairs(rows) do
                local label = Text(card, body, MUTED)
                At(label, card, split + 12, y + 4 + (r - 1) * 18)
                label:SetText(row[1])
                local value = Text(card, body, BRIGHT, "RIGHT")
                value:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -(y + 4 + (r - 1) * 18))
                value:SetText(row[2])
            end
            y = y + 46
        elseif section == "tiles" then
            local tw = (w - PAD * 2 - 8) / 2
            local rows = math.ceil(#model.tiles / 2)
            for t, tile in ipairs(model.tiles) do
                local tx = PAD + ((t - 1) % 2) * (tw + 8)
                local ty = y + floor((t - 1) / 2) * 36
                local edge = Solid(card, "ARTWORK", 0, { 1, 1, 1 }, 0.09)
                edge:SetSize(tw, 30)
                At(edge, card, tx, ty)
                local fill = Solid(card, "ARTWORK", 1, { 0.086, 0.094, 0.114 })
                fill:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
                fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
                local value = Text(card, body + 1, tile.color or BRIGHT)
                value:SetWidth(tw - 14)
                if tile.label then
                    local label = Text(card, max(7, small - 1), MUTED)
                    label:SetWidth(tw - 14)
                    At(label, card, tx + 7, ty + 4)
                    label:SetText(tile.label)
                    value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
                else
                    value:SetPoint("LEFT", edge, "LEFT", 7, 0)
                end
                value:SetText(tile.text)
            end
            y = y + rows * 36 - 6 + 10
        else
            for _, line in ipairs(model.lines) do
                if line.section then
                    y = y + 2
                    Divider(card, y, w)
                    y = y + 8
                end
                local x = line.bullet and PAD + 11 or PAD
                local avail = w - PAD - x
                local lineH = 0
                if line.right then
                    local right = Text(card, body, line.rc or BRIGHT, "RIGHT")
                    right:SetText(line.right)
                    right:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
                    local rw = Measure(right:GetStringWidth())
                    avail = max(60, avail - rw - 8)
                    lineH = Measure(right:GetStringHeight())
                end
                if line.left then
                    local left = Text(card, body, line.lc or BODY)
                    left:SetWordWrap(true)
                    left:SetWidth(avail)
                    At(left, card, x, y)
                    left:SetText(line.left)
                    lineH = max(lineH, Measure(left:GetStringHeight()))
                    if line.bullet then
                        local dot = Solid(card, "ARTWORK", 2, EFFECT)
                        dot:SetSize(4, 4)
                        At(dot, card, PAD + 2, y + floor(body / 2) - 1)
                    end
                end
                y = y + lineH + 4
            end
            y = y + 6
        end
    end

    -- footer: sell price on a band at the bottom edge
    local money = CoinText(model.price, body)
    if money then
        y = y + 2
        local band = Solid(card, "ARTWORK", 0, { 1, 1, 1 }, 0.04)
        band:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 3, 1)
        band:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
        band:SetHeight(24)
        local rule = Solid(card, "ARTWORK", 1, { 1, 1, 1 }, 0.10)
        rule:SetPoint("TOPLEFT", band, "TOPLEFT")
        rule:SetPoint("TOPRIGHT", band, "TOPRIGHT")
        rule:SetHeight(1)
        local label = Text(card, max(7, small - 1), MUTED)
        label:SetPoint("LEFT", band, "LEFT", PAD - 3, 0)
        label:SetText(model.priceLabel)
        local value = Text(card, body, BRIGHT, "RIGHT")
        value:SetPoint("RIGHT", band, "RIGHT", -PAD + 1, 0)
        value:SetText(money)
        y = y + 25
    else
        y = y + 2
    end
    return floor(y + 0.5)
end

-- ---------------------------------------------------------------- tooltip glue
local states = setmetatable({}, { __mode = "k" })

function Card:IsActive()
    local db = KT.db and KT.db.profile and KT.db.profile.tooltip
    return db and db.enable and db.cardStyle and true or false
end

local function StateFor(tooltip)
    local st = states[tooltip]
    if st then return st end
    if not (tooltip.SetPadding and tooltip.GetPadding and tooltip.SetMinimumWidth) then return nil end
    st = { card = Card:CreateFrame(tooltip) }
    st.card:SetAllPoints(tooltip)
    st.card:SetFrameLevel((tooltip:GetFrameLevel() or 1) + 10)
    if st.card.SetIgnoreParentAlpha then st.card:SetIgnoreParentAlpha(true) end
    states[tooltip] = st
    return st
end

-- Gives the tooltip back its own look and size settings.
function Card:Release(tooltip)
    local st = states[tooltip]
    if not st then return end
    st.model, st.dataCount = nil, nil
    st.card:Hide()
    if st.padding then
        tooltip:SetPadding(st.padding[1] or 0, st.padding[2] or 0, st.padding[3] or 0, st.padding[4] or 0)
        tooltip:SetMinimumWidth(st.minWidth or 0)
        st.padding, st.minWidth = nil, nil
    end
    if st.hidden then
        st.hidden = nil
        tooltip:SetAlpha(1)
    end
end

function Card:ReleaseAll()
    for tooltip in pairs(states) do self:Release(tooltip) end
end

function Card:Refresh()
    if not self:IsActive() then self:ReleaseAll() end
end

-- Type, slot, level and icon of an item (link or ID) for the card header.
-- Every value goes through SafeCall: secret ones are left out.
local function ItemMetaFor(ref)
    if ref == nil or IsSecret(ref) then return nil end
    local meta = {}
    local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    local _, _, _, itemLevel, _, itemType, subType, _, equipLoc, icon = SafeCall(getInfo, ref)
    if not icon then
        local instant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
        local _, iType, iSub, iLoc, iIcon = SafeCall(instant, ref)
        itemType, subType, equipLoc, icon = iType, iSub, iLoc, iIcon
    end
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        itemLevel = SafeCall(C_Item.GetDetailedItemLevelInfo, ref) or itemLevel
    end
    if type(itemType) ~= "string" then itemType = nil end
    if type(subType) ~= "string" then subType = nil end
    meta.icon, meta.itemType, meta.subType, meta.itemLevel = icon, itemType, subType, Num(itemLevel)
    if type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        meta.equippable = equipLoc ~= "INVTYPE_BAG" and equipLoc ~= "INVTYPE_QUIVER"
        local equipName = _G[equipLoc]
        meta.equipName = type(equipName) == "string" and equipName or nil
    end
    return meta
end

-- The tooltip's item link, or its data's item ID; nil when secret.
local function ItemMeta(tooltip, data)
    local _, link = SafeCall(tooltip.GetItem, tooltip)
    if type(link) ~= "string" then link = nil end
    if not link and type(data) == "table" and not IsSecret(data) then link = Num(data.id) end
    return ItemMetaFor(link)
end

local function SpellIcon(spellID)
    spellID = Num(spellID)
    if not spellID then return nil end
    local icon = C_Spell and C_Spell.GetSpellTexture and SafeCall(C_Spell.GetSpellTexture, spellID)
    if not icon and _G.GetSpellTexture then icon = SafeCall(_G.GetSpellTexture, spellID) end
    return icon
end

-- Lines appended after the game's own become the card's last section.
local function AppendExtras(model, extras)
    for k = #model.lines, 1, -1 do
        if model.lines[k].extra then table.remove(model.lines, k) end
    end
    local base, first = #model.lines, true
    for _, line in ipairs(extras or {}) do
        if line.left or line.right then
            local entry = BodyLine(line)
            entry.extra = true
            entry.section = first and base > 0
            first = false
            model.lines[#model.lines + 1] = entry
        end
    end
end

local function SpellMeta(tooltip, data)
    local _, spellID = SafeCall(tooltip.GetSpell, tooltip)
    if not Num(spellID) and type(data) == "table" and not IsSecret(data) then spellID = data.id end
    return { icon = SpellIcon(spellID) }
end

local function OnData(kind, tooltip, data)
    if tooltip ~= _G.GameTooltip or not Card:IsActive() then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    local st = StateFor(tooltip)
    if not st then return end
    local okRead, lines = pcall(ReadDataLines, data)
    if not okRead or not lines then
        Card:Release(tooltip)
        return
    end
    -- Meta reads go inside the pcall too: a failure only drops the card.
    local ok, model = pcall(function()
        if kind == "item" then
            return Card:BuildItemModel(lines, ItemMeta(tooltip, data))
        end
        return Card:BuildSpellModel(lines, SpellMeta(tooltip, data))
    end)
    st.model = ok and model or nil
    st.dataCount = #lines
    if not st.model then Card:Release(tooltip) end
end

-- After the tooltip lays itself out: draw the card and size the tooltip to it.
local function OnShown(tooltip)
    local st = states[tooltip]
    if not st or not st.model or st.busy then return end
    if not Card:IsActive() then Card:Release(tooltip) return end
    st.busy = true
    local ok, err = pcall(function()
        local model = st.model
        -- Lines appended after the game's own (addons, the module's info block).
        -- A secret one would be hidden by the card: keep the usual tooltip.
        local extras = ReadExtraLines(tooltip, (st.dataCount or 0) + 1)
        if not extras then return "secret" end

        -- Sizes are read before anything changes: a secret one leaves the tooltip as it was.
        local pr, pb, pl, pt = tooltip:GetPadding()
        pr, pb, pl, pt = Measure(pr or 0), Measure(pb or 0), Measure(pl or 0), Measure(pt or 0)
        local tooltipWidth = Measure(tooltip:GetWidth() or 0)
        local tooltipHeight = Measure(tooltip:GetHeight() or 0)
        local minWidth = tooltip.GetMinimumWidth and Num(tooltip:GetMinimumWidth()) or 0

        AppendExtras(model, extras)
        if not st.padding then
            st.padding = { pr, pb, pl, pt }
            st.minWidth = minWidth
        end
        local width = max(CARD_WIDTH, floor(tooltipWidth + 0.5))
        local height = Card:Render(st.card, model, width)
        tooltip:SetMinimumWidth(width)
        local need = height - tooltipHeight
        if abs(need) > 0.5 then
            tooltip:SetPadding(pr, max(0, pb + need), pl, pt)
            tooltip:Show()
        end
        st.card:Show()
        st.hidden = true
        tooltip:SetAlpha(0)
    end)
    st.busy = false
    if not ok or err == "secret" then
        Card:Release(tooltip)
        if not ok and KT.Debug then KT:Debug("TooltipCard: " .. tostring(err)) end
    end
end

-- Talents (passive or active) build their tooltip from a title and trait entry
-- lines instead of one spell's data, so their card is made from the finished
-- tooltip once the talent frame has filled and shown it.
function Card:ShowTalent(button, tooltip)
    if tooltip ~= _G.GameTooltip or not self:IsActive() then return end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return end
    local st = StateFor(tooltip)
    if not st then return end
    self:Release(tooltip)
    local ok, model, count = pcall(function()
        local raw = ReadExtraLines(tooltip, 1)
        if not raw then return nil end
        -- Spacing lines between the title and the description carry nothing in the card.
        local lines = {}
        for _, line in ipairs(raw) do
            if line.left or line.right then lines[#lines + 1] = line end
        end
        local spellID = button and button.GetSpellID and SafeCall(button.GetSpellID, button)
        local icon = SpellIcon(spellID)
        if not icon and button and button.Icon and button.Icon.GetTexture then
            icon = SafeCall(button.Icon.GetTexture, button.Icon)
        end
        return self:BuildSpellModel(lines, { icon = icon }), #raw
    end)
    if not ok or not model then return end
    st.model, st.dataCount = model, count
    OnShown(tooltip)
end

function Card:Install()
    if self.installed or not _G.GameTooltip then return end
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then return end
    self.installed = true
    local tooltip = _G.GameTooltip
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data) OnData("item", tt, data) end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tt, data) OnData("spell", tt, data) end)
    hooksecurefunc(tooltip, "Show", OnShown)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", function(_, button, tt)
            Card:ShowTalent(button, tt)
        end, Card)
    end
    tooltip:HookScript("OnTooltipCleared", function(tt) Card:Release(tt) end)
    tooltip:HookScript("OnHide", function(tt) Card:Release(tt) end)
    hooksecurefunc(tooltip, "SetAlpha", function(tt, alpha)
        local st = states[tt]
        if st and st.hidden and not st.busy and Num(alpha) and alpha > 0 then
            st.busy = true
            tt:SetAlpha(0)
            st.busy = false
        end
    end)
end


-- ---------------------------------------------------------------- previews
-- Options and installer previews show real items and spells from the client,
-- picked at random each time a preview opens. Item data loads on demand: the
-- list is requested once and only items already loaded are picked; until one
-- is, a built-in sample stands in.
local SAMPLE_ITEMS = {
    19019, 17182, 18832, 12784, 19364, 18803, 12640, 13404, 11815, 13209,
    16922, 13446, 2589, 6948, 12791, 19137,
}
-- Retail spell IDs (no ranks): Earth Shock, Fireball, Frostbolt, Pyroblast, Flash Heal...
local SAMPLE_SPELLS = {
    8042, 133, 116, 11366, 2061, 1953, 1766, 100, 12294, 5143,
    686, 172, 8921, 8936, 19434, 642,
}
local SAMPLE_ITEM_SET = {}
for _, id in ipairs(SAMPLE_ITEMS) do SAMPLE_ITEM_SET[id] = true end

local WHITE = { 1, 1, 1 }
local GOLD_TEXT = { 1, 0.82, 0 }
local function Line(left, color, right, rightColor)
    return { left = left, right = right, lc = color or WHITE, rc = rightColor or WHITE }
end

local function SafeFormat(template, fallback, ...)
    if type(template) == "string" then
        local ok, text = pcall(format, template, ...)
        if ok then return text end
    end
    return format(fallback, ...)
end

local function ItemCached(id)
    local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    return getInfo and getInfo(id) ~= nil
end

-- The Tooltip module's own information block, as it is appended in game
-- (TooltipInfo.lua). Follows the same per-line switches; empty when every line is off.
local function InfoBlock(kind, id)
    local Info = KT.TooltipInfo
    local lines = {}
    if not (Info and id) then return lines end
    local rows = kind == "item" and Info:ItemRows("item:" .. id) or Info:SpellRows(id)
    for _, row in ipairs(rows) do
        lines[#lines + 1] = Line("|cffffd100" .. LText(row[1]) .. "|r", WHITE, row[2])
    end
    if #lines == 0 then return lines end
    table.insert(lines, 1, Line("|cff00ccff" .. LText(kind == "item" and "Item information" or "Spell information") .. "|r"))
    return lines
end

local function ItemSample(id)
    if not (id and C_TooltipInfo and C_TooltipInfo.GetItemByID and ItemCached(id)) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if not ok or type(data) ~= "table" then return nil end
    local lines = ReadDataLines(data)
    if not (lines and lines[1] and lines[1].left) then return nil end
    return { kind = "item", lines = lines, meta = ItemMetaFor(id), extras = InfoBlock("item", id) }
end

local function SpellSample(id)
    if not (id and C_TooltipInfo and C_TooltipInfo.GetSpellByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetSpellByID, id)
    if not ok or type(data) ~= "table" then return nil end
    local lines = ReadDataLines(data)
    if not (lines and lines[1] and lines[1].left) then return nil end
    return { kind = "spell", lines = lines, meta = { icon = SpellIcon(id) }, extras = InfoBlock("spell", id) }
end

local function FallbackSamples()
    local decimal = _G.DECIMAL_SEPERATOR or "."
    local equipName = _G.INVTYPE_WEAPON or "One-Hand"
    local axe = LText("Axe")
    local item = {
        kind = "item",
        lines = {
            Line(LText("Gale Edge"), { 0.64, 0.21, 0.93 }),
            Line(_G.ITEM_BIND_ON_EQUIP or "Binds when equipped"),
            Line(equipName, WHITE, axe),
            Line(SafeFormat(_G.DAMAGE_TEMPLATE, "%s - %s Damage", "37", "69"), WHITE,
                (_G.SPEED or "Speed") .. " " .. (("1.50"):gsub("%.", decimal))),
            Line(SafeFormat(_G.DPS_TEMPLATE, "(%s damage per second)", (("35.3"):gsub("%.", decimal)))),
            Line(SafeFormat(_G.ITEM_MIN_LEVEL, "Requires Level %d", 42), { 1, 0.13, 0.13 }),
            Line(LText("Equip: Grants 1 extra attack on your next swing."), { 0.12, 1, 0 }),
            { price = 29627, lc = WHITE, rc = WHITE },
        },
        meta = { icon = "Interface\\Icons\\INV_Axe_09", equipName = equipName, subType = axe, itemLevel = 47, equippable = true },
    }
    item.extras = InfoBlock("item", 8190)
    local spell = {
        kind = "spell",
        lines = {
            Line(LText("Earth Shock"), WHITE),
            Line(SafeFormat(_G.MANA_COST, "%d Mana", 80), WHITE, SafeFormat(_G.SPELL_RANGE, "%s yd range", "20")),
            Line(_G.SPELL_CAST_TIME_INSTANT or "Instant", WHITE, SafeFormat(_G.SPELL_RECAST_TIME_SEC, "%.3g sec cooldown", 6)),
            Line(LText("Instantly shocks the target with concussive force, causing 129 to 138 Nature damage. Interrupts spellcasting for 2 sec."), GOLD_TEXT),
            Line(LText("Causes a high amount of threat."), GOLD_TEXT),
        },
        meta = { icon = "Interface\\Icons\\Spell_Nature_EarthShock" },
    }
    spell.extras = InfoBlock("spell", 8042)
    return item, spell
end

local warmed
local function WarmItems()
    if warmed then return end
    warmed = true
    if not (C_Item and C_Item.RequestLoadItemDataByID) then return end
    for _, id in ipairs(SAMPLE_ITEMS) do
        if not ItemCached(id) then pcall(C_Item.RequestLoadItemDataByID, id) end
    end
end

local function PickOne(list, usable, previous)
    local pool = {}
    for _, id in ipairs(list) do
        if usable(id) and id ~= previous then pool[#pool + 1] = id end
    end
    if #pool == 0 and previous and usable(previous) then return previous end
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

local function SpellUsable(id)
    if not (C_TooltipInfo and C_TooltipInfo.GetSpellByID) then return false end
    if C_Spell and C_Spell.DoesSpellExist then return C_Spell.DoesSpellExist(id) and true or false end
    return true
end

-- Picks a random item and spell; keeps clear of the previous pick when it can.
function Card:PickSamples(previous)
    WarmItems()
    previous = previous or {}
    return {
        item = PickOne(SAMPLE_ITEMS, ItemCached, previous.item),
        spell = PickOne(SAMPLE_SPELLS, SpellUsable, previous.spell),
    }
end

function Card:SamplesFor(pick)
    local fallbackItem, fallbackSpell = FallbackSamples()
    return (pick and ItemSample(pick.item)) or fallbackItem, (pick and SpellSample(pick.spell)) or fallbackSpell
end

function Card:ModelFor(sample)
    local model
    if sample.kind == "item" then
        model = self:BuildItemModel(sample.lines, sample.meta)
    else
        model = self:BuildSpellModel(sample.lines, sample.meta)
    end
    if model then AppendExtras(model, sample.extras) end
    return model
end

-- The same tooltip in the Tooltip module's usual skin: dark panel, one-pixel
-- border in the quality color and the icon inside the top-right corner.
local SKIN_ICON, SKIN_INSET, SKIN_GAP = 32, 6, 6
function Card:RenderSkin(card, sample)
    Reset(card)
    local textFont, textSize = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12
    local headFont, headSize = textFont, 14
    if _G.GameTooltipText and GameTooltipText.GetFont then textFont, textSize = GameTooltipText:GetFont() end
    if _G.GameTooltipHeaderText and GameTooltipHeaderText.GetFont then headFont, headSize = GameTooltipHeaderText:GetFont() end
    textSize, headSize = floor((textSize or 12) + 0.5), floor((headSize or 14) + 0.5)
    local pad, gap = 10, 2
    local maxW, minW = 300, 170

    local rows = {}
    for index, line in ipairs(sample.lines) do
        if line.price then
            rows[#rows + 1] = { left = (_G.SELL_PRICE or "Sell Price") .. ":", lc = WHITE, money = CoinText(line.price, textSize) }
        elseif line.left or line.right then
            rows[#rows + 1] = { left = line.left, right = line.right, lc = line.lc, rc = line.rc, header = index == 1 }
        end
    end
    if sample.extras and #sample.extras > 0 then
        rows[#rows + 1] = { blank = true }
        for _, line in ipairs(sample.extras) do rows[#rows + 1] = line end
    end

    -- The lines beside the icon keep clear of it.
    local iconZone = (sample.meta and sample.meta.icon) and (SKIN_INSET + SKIN_ICON + 2) or 0
    local iconRoom = SKIN_ICON + SKIN_INSET + SKIN_GAP - pad

    -- Natural width decides the panel width, as the game does; long lines wrap.
    local natural = minW
    local measured = {}
    local yy = pad
    for i, row in ipairs(rows) do
        if row.blank then
            yy = yy + textSize * 0.6
        else
            local size = row.header and headSize or textSize
            local font = row.header and headFont or textFont
            local left = row.left and Text(card, size, row.lc or WHITE, "LEFT", font)
            local right = row.right and Text(card, size, row.rc or WHITE, "RIGHT", font)
            local money = row.money and Text(card, size, WHITE, "LEFT", font)
            if left then left:SetText(row.left) end
            if right then right:SetText(row.right) end
            if money then money:SetText(row.money) end
            local w = (left and Measure(left:GetStringWidth()) or 0) + (right and Measure(right:GetStringWidth()) + 20 or 0)
                + (money and Measure(money:GetStringWidth()) + 4 or 0) + (yy < iconZone and iconRoom or 0)
            natural = max(natural, min(maxW - pad * 2, w) + pad * 2)
            measured[i] = { left = left, right = right, money = money }
            yy = yy + max(left and Measure(left:GetStringHeight()) or 0, right and Measure(right:GetStringHeight()) or 0) + gap
        end
    end
    local w = floor(min(maxW, natural) + 0.5)
    local y = pad
    for i, row in ipairs(rows) do
        if row.blank then
            y = y + textSize * 0.6
        else
            local m = measured[i]
            local lineH = 0
            local room = y < iconZone and iconRoom or 0
            local avail = w - pad * 2 - room
            if m.right then
                m.right:SetPoint("TOPRIGHT", card, "TOPRIGHT", -pad - room, -y)
                avail = max(40, avail - Measure(m.right:GetStringWidth()) - 12)
                lineH = Measure(m.right:GetStringHeight())
            end
            if m.left then
                m.left:SetWordWrap(true)
                m.left:SetWidth(avail)
                At(m.left, card, pad, y)
                lineH = max(lineH, Measure(m.left:GetStringHeight()))
                if m.money then
                    m.money:SetPoint("LEFT", m.left, "LEFT", Measure(m.left:GetStringWidth()) + 4, 0)
                end
            end
            y = y + lineH + gap
        end
    end
    local h = floor(y - gap + pad + 0.5)
    if iconZone > 0 then h = max(h, SKIN_ICON + SKIN_INSET * 2) end

    local border = sample.kind == "item" and (sample.lines[1] and sample.lines[1].lc) or { 0.2, 0.6, 1 }
    Solid(card, "BACKGROUND", -8, border):SetAllPoints(card)
    local bg = Solid(card, "BACKGROUND", -7, { 0.05, 0.05, 0.05 }, 0.95)
    -- One screen pixel, so the fill never covers the border on a side at small scales.
    local px = 1
    local scale = card.GetEffectiveScale and card:GetEffectiveScale()
    if type(scale) == "number" and scale > 0 and _G.PixelUtil and PixelUtil.GetNearestPixelSize then
        local ok, size = pcall(PixelUtil.GetNearestPixelSize, 1, scale, 1)
        if ok and type(size) == "number" and size > 0 then px = size end
    end
    bg:SetPoint("TOPLEFT", px, -px)
    bg:SetPoint("BOTTOMRIGHT", -px, px)
    if sample.meta and sample.meta.icon then
        local iconEdge = Solid(card, "ARTWORK", 0, border)
        iconEdge:SetSize(SKIN_ICON + 2, SKIN_ICON + 2)
        iconEdge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -SKIN_INSET + 1, -SKIN_INSET + 1)
        local icon = Tex(card, "ARTWORK", 1)
        icon:SetTexture(sample.meta.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetSize(SKIN_ICON, SKIN_ICON)
        icon:SetPoint("TOPRIGHT", card, "TOPRIGHT", -SKIN_INSET, -SKIN_INSET)
    end
    return w, h
end

local waiters = setmetatable({}, { __mode = "k" })
local loader
local function WaitForItems(holder, redraw)
    waiters[holder] = redraw
    if loader then return end
    loader = CreateFrame("Frame")
    loader:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    loader:SetScript("OnEvent", function(_, _, itemID)
        if not SAMPLE_ITEM_SET[tonumber(itemID) or 0] then return end
        for frame, fn in pairs(waiters) do
            waiters[frame] = nil
            if frame:IsVisible() then pcall(fn) end
        end
    end)
end

-- Draws a random item and spell side by side, centered in holder.
-- opts.mode: "card" (default) or "skin" (the module's usual look);
-- opts.reshuffle: pick new samples; opts.maxHeight: scale down to fit.
-- Returns the height used.
function Card:UpdatePreview(holder, width, opts)
    opts = opts or {}
    holder.kuiCardPreviews = holder.kuiCardPreviews or { self:CreateFrame(holder), self:CreateFrame(holder) }
    if opts.reshuffle or not holder.kuiPick then holder.kuiPick = self:PickSamples(holder.kuiPick) end
    local mode = opts.mode or "card"
    if not holder.kuiPick.item then
        WaitForItems(holder, function()
            holder.kuiPick = self:PickSamples(holder.kuiPick)
            self:UpdatePreview(holder, width, { mode = holder.kuiMode, maxHeight = opts.maxHeight })
        end)
    end
    holder.kuiMode = mode

    local itemSample, spellSample = self:SamplesFor(holder.kuiPick)
    local sizes = {}
    for i, sample in ipairs({ itemSample, spellSample }) do
        local frame = holder.kuiCardPreviews[i]
        frame:SetScale(1)
        local w, h
        if mode == "skin" then
            w, h = self:RenderSkin(frame, sample)
        else
            w = CARD_WIDTH
            h = self:Render(frame, self:ModelFor(sample), CARD_WIDTH)
        end
        frame:SetSize(w, h)
        sizes[i] = { w, h }
    end

    local gap = 24
    local top = mode == "skin" and 44 or 12
    local total = sizes[1][1] + gap + sizes[2][1]
    local tallest = max(sizes[1][2], sizes[2][2])
    local scale = min(1, (width - 24) / total)
    if opts.maxHeight then scale = min(scale, (opts.maxHeight - top - 12) / tallest) end
    local used = tallest * scale + top + 12
    local x = (width - total * scale) / 2
    local y = top
    if opts.maxHeight then y = top + max(0, (opts.maxHeight - used) / 2) end
    for i = 1, 2 do
        local frame = holder.kuiCardPreviews[i]
        frame:SetScale(scale)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", holder, "TOPLEFT", x / scale, -y / scale)
        frame:Show()
        x = x + (sizes[i][1] + gap) * scale
    end
    return used
end
