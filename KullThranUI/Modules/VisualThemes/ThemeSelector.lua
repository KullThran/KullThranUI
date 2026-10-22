local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

--- Lays the theme cards out in a grid inside `parent`.
--- Card heights come from the card builder itself (a card's height depends on
--- how much room its live preview needs), so the grid can never disagree with
--- what the cards actually drew.
--- @return number height consumed below the starting point
function KT.VisualThemes:CreateSelector(parent, options)
    options = options or {}
    self:EnsureInitialized()

    local columns = math.max(1, tonumber(options.columns) or 2)
    local compact = options.compact == true
    local startY = tonumber(options.yOffset) or 0
    local startX = tonumber(options.xOffset) or 0
    local gap = compact and 8 or 12
    local containerWidth = tonumber(options.width) or parent:GetWidth() or 200
    if containerWidth < 80 then containerWidth = 200 end

    local cardWidth = math.floor((containerWidth - (gap * (columns - 1))) / columns)
    local order = self:GetThemeOrder()

    self:ResetCardHealthViews()

    local rowTops = {}
    local rowHeights = {}
    local used = 0

    for index, themeKey in ipairs(order) do
        local row = math.floor((index - 1) / columns) + 1
        local column = (index - 1) % columns
        local card, height = self:CreateThemeCard(parent, themeKey, {
            compact = compact,
            width = cardWidth,
        })
        if card then
            if not rowHeights[row] then
                rowTops[row] = used
                rowHeights[row] = 0
                used = used + (row > 1 and gap or 0)
            end
            rowHeights[row] = math.max(rowHeights[row], tonumber(height) or 0)
            card:SetPoint("TOPLEFT", parent, "TOPLEFT",
                startX + column * (cardWidth + gap), -(startY + rowTops[row]))
        end
    end

    for _, height in pairs(rowHeights) do
        used = used + height
    end
    return used + 4
end
-- ---------------------------------------------------------------------------
-- Accent preset grid (KullThranUI colour themes). Shared by the options menu
-- and the installer so both show the same, nicer cards instead of flat
-- wide buttons. opts: columns, width, xOffset, yOffset, cardHeight, gap,
-- fontPath, isSelected(key), onSelect(key). Returns (height, refresh).
-- ---------------------------------------------------------------------------
local ACCENT_PRESET_ORDER = {
    "kui_crimson", "frost_blue", "emerald_night", "royal_violet",
    "ember_gold", "obsidian_teal", "blood_moon", "sunforge",
    "arcwine", "stormsteel", "plague_green", "sakura_fall",
}
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

--- True when `key` is the accent preset currently in use. Class colour, a
--- custom accent or a hand-edited palette ("custom") means no preset is.
function KT.IsAccentPresetActive(skin, key)
    if type(skin) ~= "table" then return false end
    if skin.kullthranUIColorByClass == true or skin.borderTheme == "CLASS" then return false end
    if skin.borderTheme == "CUSTOM" or skin.stylePreset == "custom" then return false end
    return (skin.stylePreset or "kui_crimson") == key
end

function KT:CreateAccentPresetGrid(parent, opts)
    opts = opts or {}
    local presets = KT.STYLE_PRESETS or {}
    local columns = math.max(1, tonumber(opts.columns) or 3)
    local gap = tonumber(opts.gap) or 8
    local cardHeight = tonumber(opts.cardHeight) or 44
    local startX = tonumber(opts.xOffset) or 0
    local startY = tonumber(opts.yOffset) or 0
    local width = tonumber(opts.width) or parent:GetWidth() or 300
    if width < 120 then width = 300 end
    local cardWidth = math.floor((width - gap * (columns - 1)) / columns)
    local font = opts.fontPath or KT.FONT_PATH or STANDARD_TEXT_FONT

    local cards = {}
    -- Same card as the Visual Theme cards (ThemeBrutalCard.lua), in each
    -- preset's own accent: the rotating accent band runs on the selected
    -- preset and on hover.
    local function Paint(card)
        local selected = opts.isSelected and opts.isSelected(card.key) or false
        card.ring:SetShown(selected)
        if KT.BrutalCard then
            KT.BrutalCard.SetInUse(card, selected)
            KT.BrutalCard.SetHover(card, card.hover)
        end
    end

    local rows = 0
    local index = 0
    for _, key in ipairs(opts.order or ACCENT_PRESET_ORDER) do
        local preset = presets[key]
        if preset then
            index = index + 1
            local row = math.floor((index - 1) / columns)
            local col = (index - 1) % columns
            rows = math.max(rows, row + 1)
            local card = CreateFrame("Button", nil, parent)
            card:SetSize(cardWidth, cardHeight)
            card:SetPoint("TOPLEFT", parent, "TOPLEFT",
                startX + col * (cardWidth + gap), -(startY + row * (cardHeight + gap)))
            card.key, card.preset = key, preset
            local face = card
            if KT.BrutalCard then
                local a = preset.accent
                face = KT.BrutalCard.Style(card, {
                    accent = { a.r, a.g, a.b },
                    fill = { preset.background.r, preset.background.g, preset.background.b },
                }).body
            end

            -- Accent dot with a soft ring when selected.
            local dotSize = math.max(12, math.floor(cardHeight * 0.34))
            card.ring = face:CreateTexture(nil, "ARTWORK", nil, 1)
            card.ring:SetSize(dotSize + 8, dotSize + 8)
            card.ring:SetPoint("LEFT", face, "LEFT", 7, 0)
            card.ring:SetColorTexture(preset.accent.r, preset.accent.g, preset.accent.b, 0.30)
            local ringMask = face:CreateMaskTexture()
            ringMask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            ringMask:SetAllPoints(card.ring)
            card.ring:AddMaskTexture(ringMask)

            card.dot = face:CreateTexture(nil, "ARTWORK", nil, 2)
            card.dot:SetSize(dotSize, dotSize)
            card.dot:SetPoint("CENTER", card.ring, "CENTER", 0, 0)
            card.dot:SetColorTexture(preset.accent.r, preset.accent.g, preset.accent.b, 1)
            local dotMask = face:CreateMaskTexture()
            dotMask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            dotMask:SetAllPoints(card.dot)
            card.dot:AddMaskTexture(dotMask)

            card.label = face:CreateFontString(nil, "OVERLAY")
            card.label:SetFont(font, tonumber(opts.fontSize) or 10, "OUTLINE")
            card.label:SetPoint("LEFT", card.ring, "RIGHT", 6, 0)
            card.label:SetPoint("RIGHT", face, "RIGHT", -6, 0)
            card.label:SetJustifyH("LEFT")
            card.label:SetWordWrap(false)
            card.label:SetText(opts.localize and opts.localize(preset.label) or preset.label)
            card.label:SetTextColor(preset.text.r, preset.text.g, preset.text.b, 1)

            card:SetScript("OnEnter", function(self) self.hover = true; Paint(self) end)
            card:SetScript("OnLeave", function(self) self.hover = false; Paint(self) end)
            card:SetScript("OnClick", function(self)
                if opts.onSelect then opts.onSelect(self.key) end
                for _, other in ipairs(cards) do Paint(other) end
            end)
            cards[#cards + 1] = card
            Paint(card)
        end
    end

    local function Refresh()
        for _, card in ipairs(cards) do Paint(card) end
    end
    return rows * cardHeight + math.max(0, rows - 1) * gap, Refresh
end
