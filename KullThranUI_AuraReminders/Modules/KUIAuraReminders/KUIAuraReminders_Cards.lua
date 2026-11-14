-- Aura Reminders options: the row of section cards that replaces the tab bar. One frame set per session, moved into
-- each page build. Reads saved values, never writes them. No client difference: ctx.client selects nothing.

local _, ns = ...
local KT = ns.KT or (LibStub and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))
if not KT then return end

local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min

local MEDIA = "Interface\\AddOns\\KullThranUI_AuraReminders\\Modules\\KUIAuraReminders\\Media\\"

local CARD_GAP, ROW_BOTTOM_GAP, COLUMN_GAP = 10, 14, 14
local CARD_MIN_W, CARD_MAX_W, CARD_H = 120, 200, 140
local PREVIEW_SHARE, PREVIEW_MIN_W, PREVIEW_MAX_W = 0.30, 160, 320
local PAD, BUTTON_PAD = 10, 8
local ICON_SIZE, ORB_SIZE, ICON_TITLE_GAP, TITLE_SUBTITLE_GAP = 30, 46, 7, 3
local TITLE_MAX_SIZE, SUBTITLE_MAX_SIZE, STATUS_MAX_SIZE = 14, 11, 11
local TITLE_MIN_SIZE, SUBTITLE_MIN_SIZE, TEXT_MAX_LINES = 9, 8, 2
local OUTLINE_ROOM = 2
local ROUND_BUTTON, ROUND_STATUS_GAP = 22, 4
local ORB_SECONDS = 12
local HOVER_SECONDS, DISC_ALPHA, DISC_HOVER_ALPHA = 0.3, 0.2, 0.3
local ORB_ALPHA, ORB_SELECTED_ALPHA = 0.45, 1
local CROP_LOW, CROP_HIGH = 0.07, 0.93
local NO_FLAGS = ""

local M = {}
ns.AuraRemindersCards = M

-- Set by Setup.
local S, P

-- Session state. A card is { page, button, border, panel, selected, corner, orb, spin, icon, title, subtitle, status, round }.
local row, probe
local cards = {}
local repaintHooked = false
local fitKey, titleSize, subtitleSize

-----------------------------------------------------------------------------------------------------------------------
-- Geometry, derived from the width the panel really has
-----------------------------------------------------------------------------------------------------------------------

-- As many columns as fit at the smallest card, the row capped at full size and centred when there is room over.
local function ComputeLayout(width, count)
    local columns = min(count, max(1, floor((width + CARD_GAP) / (CARD_MIN_W + CARD_GAP))))
    local rows = ceil(count / columns)
    local cardW = max(1, min(CARD_MAX_W, floor((width - (columns - 1) * CARD_GAP) / columns)))
    local used = columns * cardW + (columns - 1) * CARD_GAP
    return {
        columns = columns, rows = rows, cardW = cardW, cardH = CARD_H,
        left = floor((width - used) / 2),
        height = rows * CARD_H + (rows - 1) * CARD_GAP,
    }
end
M.ComputeLayout = ComputeLayout

local function PreviewWidth(width)
    return max(PREVIEW_MIN_W, min(PREVIEW_MAX_W, floor(width * PREVIEW_SHARE)))
end
M.PreviewWidth = PreviewWidth

-----------------------------------------------------------------------------------------------------------------------
-- Real status of each section. Reads only.
-----------------------------------------------------------------------------------------------------------------------

local function CountOn(list, section, on, total)
    for _, entry in ipairs(list or {}) do
        total = total + 1
        if P.IsOn(section, entry.key) then on = on + 1 end
    end
    return on, total
end

local function OnOfTotal(on, total)
    return string.format(S.LText("%d of %d on"), on, total)
end

local function ControlStatus()
    local profile = P.DB()
    if profile and profile.enable == false then return S.LText("Disabled") end
    return S.LText("Active")
end

local function GroupStatus()
    local on, total = CountOn(_G._KUIAR_RAID_BUFFS, P.RDB(), 0, 0)
    on, total = CountOn(_G._KUIAR_AURAS, P.ADB(), on, total)
    return OnOfTotal(on, total)
end

local function ClassStatus()
    local section = P.CDB()
    local on, total = CountOn(_G._KUIAR_ROGUE_POISONS, section, 0, 0)
    on, total = CountOn(_G._KUIAR_PALADIN_RITES, section, on, total)
    on, total = CountOn(_G._KUIAR_SHAMAN_IMBUES, section, on, total)
    on, total = CountOn(_G._KUIAR_SHAMAN_SHIELDS, section, on, total)
    return OnOfTotal(on, total)
end

local function ConsumableStatus()
    local section = P.CDB()
    local keys = { "flask", "food", "weapon_enchant", "augment_rune", "inky_black" }
    local _, class = UnitClass("player")
    if P.PetIcons[class] then keys[#keys + 1] = "pet" end
    local on = 0
    for _, key in ipairs(keys) do
        if P.IsOn(section, key) then on = on + 1 end
    end
    return OnOfTotal(on, #keys)
end

local function TalentStatus()
    local profile = P.DB()
    local saved = profile and profile.talentReminders
    return string.format(S.LText("%d saved"), type(saved) == "table" and #saved or 0)
end

local function CustomStatus()
    local profile = P.DB()
    local saved = profile and profile.customAuras
    local on, total = 0, 0
    if type(saved) == "table" then
        for _, conf in pairs(saved) do
            total = total + 1
            if type(conf) == "table" and conf.enabled then on = on + 1 end
        end
    end
    local embedded = _G.KUIAR_EngineSaved
    if type(embedded) == "table" and type(embedded.displays) == "table" then
        for _, conf in pairs(embedded.displays) do
            if type(conf) == "table" and not conf.controlledChildren then
                total = total + 1
                if not (conf.load and conf.load.use_never) then on = on + 1 end
            end
        end
    end
    return OnOfTotal(on, total)
end

-- Section icons: own art in Media\icons (drawn by tools/photoshop/aura_reminders_icons.jsx), pale grey and tinted
-- with the accent on every paint. The same files on both clients, so no item or spell has to be cached first.
local function OwnIcon(name)
    local path = MEDIA .. "icons\\" .. name .. ".png"
    return function() return path end
end

local ControlIcon, GroupIcon, ClassIcon = OwnIcon("control"), OwnIcon("group"), OwnIcon("upkeep")
local ConsumableIcon, TalentIcon, CustomIcon = OwnIcon("consumables"), OwnIcon("talents"), OwnIcon("custom")

-- Sections in display order. Built on use so each literal goes through the localisation function.
local function Sections()
    local Pages = S.Pages
    return {
        { page = Pages.CONTROL, title = S.LText("Control Center"), icon = ControlIcon,
          subtitle = S.LText("Module, look and placement"), status = ControlStatus },
        { page = Pages.GROUP, title = S.LText("Group Readiness Card Title"), icon = GroupIcon,
          subtitle = S.LText("Raid buffs and personal auras"), status = GroupStatus },
        { page = Pages.CLASS, title = S.LText("Class Upkeep"), icon = ClassIcon,
          subtitle = S.LText("Poisons, rites and imbues"), status = ClassStatus },
        { page = Pages.CONSUMABLES, title = S.LText("Consumable Loadout Card Title"), icon = ConsumableIcon,
          subtitle = S.LText("Flasks, food and runes"), status = ConsumableStatus },
        { page = Pages.TALENTS, title = S.LText("Talent Reminders Card Title"), icon = TalentIcon,
          subtitle = S.LText("Talent swaps by zone"), status = TalentStatus },
        { page = Pages.CUSTOM_AURAS, title = S.LText("Custom Auras"), icon = CustomIcon,
          subtitle = S.LText("Your own tracked auras"), status = CustomStatus },
    }
end

-----------------------------------------------------------------------------------------------------------------------
-- Painting
-----------------------------------------------------------------------------------------------------------------------

-- A colour of the panel's skin, so the cards share the tones of the section panels below them.
local function SkinColor(name, r, g, b, a)
    local skin = KT.MenuSkins
    if skin and skin.Color then return skin:Color(name) end
    return r, g, b, a
end

-- Accent read on every paint, the way the rest of the panel reads it, so a style change is followed.
-- The text stays neutral in every state: the selection is carried by the frame.
local function PaintCard(card, isSelected)
    card.isSelected = isSelected
    local lit = card.hovered and not isSelected
    if lit then
        card.panel:SetVertexColor(SkinColor("rowHover", 0.125, 0.112, 0.098, 1))
    else
        card.panel:SetVertexColor(SkinColor("card", 0.086, 0.078, 0.073, 0.97))
    end
    KT:SetAccentVertexColor(card.orb, isSelected and ORB_SELECTED_ALPHA or ORB_ALPHA)
    KT:SetAccentVertexColor(card.icon, 1)
    KT:SetAccentVertexColor(card.corner, 1)
    KT:SetAccentVertexColor(card.selected, 1)
    card.selected:SetShown(isSelected)
    if isSelected then
        KT:SetAccentVertexColor(card.border, 1)
    elseif lit then
        card.border:SetVertexColor(1, 1, 1, 0.28)
    else
        card.border:SetVertexColor(SkinColor("cardBorder", 0.150, 0.135, 0.122, 1))
    end
    card.title:SetTextColor(1, 1, 1, 1)
    card.subtitle:SetTextColor(SkinColor("muted", 0.74, 0.74, 0.78, 1))
    card.status:SetTextColor(1, 1, 1, isSelected and 1 or 0.85)
end

local function SetCardHover(card, hovered)
    card.hovered = hovered
    PaintCard(card, card.isSelected)
end

local function PaintAll()
    local current = S.GetSelectedPage()
    for _, card in ipairs(cards) do
        PaintCard(card, card.page == current)
    end
end

local function RefreshStatus()
    for _, card in ipairs(cards) do
        card.status:SetText(card.readStatus())
    end
end
M.RefreshStatus = RefreshStatus

-- True when the text wraps at its spaces, in this probe's font, without splitting a word and within the lines allowed.
-- Hangul and CJK text, UTF-8 lead bytes 0xE3 to 0xED, wraps between characters, so it may run across a line.
local function TextFits(text, width, maxLines)
    probe:SetText("n")
    local space = probe:GetStringWidth()
    local lines, used = 1, 0
    for word in text:gmatch("%S+") do
        probe:SetText(word)
        local wordW = probe:GetStringWidth() + OUTLINE_ROOM
        if word:find("[\227-\237]") then
            used = used + wordW
            while used > width do
                lines = lines + 1
                used = used - width
            end
        elseif wordW > width then
            return false
        elseif used > 0 and used + space + wordW > width then
            lines = lines + 1
            used = wordW
        else
            used = used + (used > 0 and space or 0) + wordW
        end
    end
    return lines <= maxLines
end

-- The largest size at which every card's text of this field fits, so the whole row shares one size.
local function FitRowSize(field, start, smallest, width, flags)
    for size = start, smallest, -1 do
        probe:SetFont(KT.FONT_PATH, size, flags)
        local fits = true
        for _, card in ipairs(cards) do
            if not TextFits(card[field], width, TEXT_MAX_LINES) then
                fits = false
                break
            end
        end
        if fits then return size end
    end
    return smallest
end

-- Measured natively, once per card width and font. A text that fits at no size is cut to one line with an ellipsis.
local function FitTexts(w, textW)
    local key = w .. KT.FONT_PATH
    if key == fitKey then return end
    fitKey = key
    titleSize = FitRowSize("titleText", min(TITLE_MAX_SIZE, max(12, floor(w * 0.09))), TITLE_MIN_SIZE, textW, NO_FLAGS)
    subtitleSize = FitRowSize("subtitleText", min(SUBTITLE_MAX_SIZE, max(SUBTITLE_MIN_SIZE, floor(w * 0.07))),
        SUBTITLE_MIN_SIZE, textW, NO_FLAGS)
    local function settle(fontString, text, size)
        probe:SetFont(KT.FONT_PATH, size, NO_FLAGS)
        local fits = TextFits(text, textW, TEXT_MAX_LINES)
        fontString:SetWordWrap(fits)
        fontString:SetMaxLines(fits and TEXT_MAX_LINES or 1)
    end
    for _, card in ipairs(cards) do
        settle(card.title, card.titleText, titleSize)
        settle(card.subtitle, card.subtitleText, subtitleSize)
    end
end

-- Fonts first: the sizes follow the card. Icon on top, the texts under it, the status beside the round button.
local function SizeCard(card, layout)
    local w = layout.cardW
    local textW = w - 2 * PAD
    FitTexts(w, textW)

    card.button:SetSize(w, layout.cardH)
    card.title:SetFont(KT.FONT_PATH, titleSize, NO_FLAGS)
    card.subtitle:SetFont(KT.FONT_PATH, subtitleSize, NO_FLAGS)
    card.status:SetFont(KT.FONT_PATH, min(STATUS_MAX_SIZE, max(10, floor(w * 0.07))), NO_FLAGS)
    card.title:SetWidth(textW)
    card.subtitle:SetWidth(textW)

    card.status:ClearAllPoints()
    card.status:SetPoint("LEFT", card.button, "BOTTOMLEFT", PAD, BUTTON_PAD + ROUND_BUTTON / 2)
    card.status:SetWidth(w - PAD - BUTTON_PAD - ROUND_BUTTON - ROUND_STATUS_GAP)
end

-----------------------------------------------------------------------------------------------------------------------
-- Building
-----------------------------------------------------------------------------------------------------------------------

-- A texture over a whole card. The art is white, so the vertex colour is what gives it its colour.
local function Layer(button, layer, sublevel, file)
    local tex = button:CreateTexture(nil, layer, nil, sublevel)
    tex:SetAllPoints(button)
    tex:SetTexture(MEDIA .. file)
    P.NoSnap(tex)
    return tex
end

-- The disc fades through a native alpha animation. Nothing runs per frame in Lua.
local function AttachDiscHover(round, disc, card)
    local group = disc:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetDuration(HOVER_SECONDS)
    local target = DISC_ALPHA
    group:SetScript("OnFinished", function() disc:SetAlpha(target) end)

    local function fadeTo(alpha)
        local from = disc:GetAlpha()
        group:Stop()
        disc:SetAlpha(from)
        target = alpha
        fade:SetFromAlpha(from)
        fade:SetToAlpha(alpha)
        group:Play()
    end
    -- The button takes the mouse from its card, so it keeps the card lit too.
    round:SetScript("OnEnter", function()
        fadeTo(DISC_HOVER_ALPHA)
        SetCardHover(card, true)
    end)
    round:SetScript("OnLeave", function()
        fadeTo(DISC_ALPHA)
        SetCardHover(card, false)
    end)

    return function()
        group:Stop()
        target = DISC_ALPHA
        disc:SetAlpha(DISC_ALPHA)
    end
end

-- Circular button at the card's bottom right. Selects like the card does.
local function NewRoundButton(button, select, card)
    local round = CreateFrame("Button", nil, button)
    round:SetSize(ROUND_BUTTON, ROUND_BUTTON)
    round:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -BUTTON_PAD, BUTTON_PAD)
    local disc = round:CreateTexture(nil, "ARTWORK")
    disc:SetAllPoints(round)
    disc:SetTexture(MEDIA .. "card_disc.png")
    disc:SetVertexColor(1, 1, 1, 1)
    disc:SetAlpha(DISC_ALPHA)
    P.NoSnap(disc)
    local chevron = round:CreateTexture(nil, "OVERLAY")
    chevron:SetSize(floor(ROUND_BUTTON / 2), floor(ROUND_BUTTON / 2))
    chevron:SetPoint("CENTER", round, "CENTER", 0, 0)
    chevron:SetTexture(MEDIA .. "card_chevron.png")
    chevron:SetVertexColor(1, 1, 1, 0.8)
    P.NoSnap(chevron)
    round:SetScript("OnClick", select)
    return round, chevron, AttachDiscHover(round, disc, card)
end

-- The section's icon with a one pixel dark edge, the way the preview draws its icons.
local function NewIcon(button)
    local edge = button:CreateTexture(nil, "ARTWORK", nil, 1)
    edge:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    edge:SetPoint("TOPLEFT", button, "TOPLEFT", PAD - 1, -(PAD - 1))
    edge:SetColorTexture(0, 0, 0, 1)
    local icon = button:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", PAD, -PAD)
    icon:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    P.NoSnap(icon)
    return icon
end

-- A soft accent glow behind the icon, turning through a native rotation. It plays only while the row is shown; see the
-- row's scripts.
local function NewOrb(button)
    local orb = button:CreateTexture(nil, "ARTWORK", nil, 0)
    orb:SetSize(ORB_SIZE, ORB_SIZE)
    orb:SetPoint("CENTER", button, "TOPLEFT", PAD + ICON_SIZE / 2, -(PAD + ICON_SIZE / 2))
    orb:SetTexture(MEDIA .. "card_orb.png")
    P.NoSnap(orb)
    local spin = orb:CreateAnimationGroup()
    spin:SetLooping("REPEAT")
    local turn = spin:CreateAnimation("Rotation")
    turn:SetDegrees(-360)
    turn:SetOrigin("CENTER", 0, 0)
    turn:SetDuration(ORB_SECONDS)
    return orb, spin
end

-- Text of one card, font before text. The size is corrected by SizeCard on every layout.
local function NewCardText(button, section, card)
    card.title = KT.MakeFont(button, 13, nil, 1, 1, 1)
    card.title:SetJustifyH("LEFT")
    card.title:SetJustifyV("TOP")
    card.title:SetPoint("TOPLEFT", button, "TOPLEFT", PAD, -(PAD + ICON_SIZE + ICON_TITLE_GAP))
    card.title:SetText(section.title)

    card.subtitle = KT.MakeFont(button, 10)
    card.subtitle:SetJustifyH("LEFT")
    card.subtitle:SetJustifyV("TOP")
    card.subtitle:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -TITLE_SUBTITLE_GAP)
    card.subtitle:SetText(section.subtitle)

    card.status = KT.MakeFont(button, 10, nil, 1, 1, 1, 0.85)
    card.status:SetJustifyH("LEFT")
    card.status:SetMaxLines(2)
end

local function NewCard(section, onSelect)
    local button = CreateFrame("Button", nil, row)
    local function select() onSelect(section.page) end
    button:SetScript("OnClick", select)

    local card = {
        page = section.page, button = button, readStatus = section.status, readIcon = section.icon,
        titleText = section.title, subtitleText = section.subtitle,
    }
    button:SetScript("OnEnter", function() SetCardHover(card, true) end)
    button:SetScript("OnLeave", function() SetCardHover(card, false) end)
    card.border = Layer(button, "BACKGROUND", 1, "card_border.png")
    card.panel = Layer(button, "BACKGROUND", 0, "card_panel.png")
    card.selected = Layer(button, "BORDER", 0, "card_selected.png")
    card.corner = Layer(button, "BORDER", 1, "card_corner.png")
    card.orb, card.spin = NewOrb(button)
    card.icon = NewIcon(button)
    NewCardText(button, section, card)
    card.round, card.chevron, card.resetDisc = NewRoundButton(button, select, card)
    return card
end

local function PlayOrbs()
    for _, card in ipairs(cards) do
        if not card.spin:IsPlaying() then card.spin:Play() end
    end
end

local function StopOrbs()
    for _, card in ipairs(cards) do
        card.spin:Stop()
        card.resetDisc()
    end
end

-- The session's row: created once, kept across page builds so a rebuild leaves no frames behind.
local function EnsureRow(sc, onSelect)
    if row then return end
    row = CreateFrame("Frame", nil, sc)
    row:SetFrameStrata(sc:GetFrameStrata())
    row:SetFrameLevel(sc:GetFrameLevel() + 1)
    probe = KT.MakeFont(row, 10)
    probe:Hide()
    for i, section in ipairs(Sections()) do
        cards[i] = NewCard(section, onSelect)
    end
    row:SetScript("OnShow", PlayOrbs)
    row:SetScript("OnHide", StopOrbs)
    if not repaintHooked and KT.MenuSkins and KT.MenuSkins.RegisterRepaint then
        repaintHooked = true
        KT.MenuSkins:RegisterRepaint(PaintAll)
    end
end

local function PlaceCards(layout)
    for i, card in ipairs(cards) do
        local column = (i - 1) % layout.columns
        local rowIndex = floor((i - 1) / layout.columns)
        SizeCard(card, layout)
        card.icon:SetTexture(card.readIcon())
        card.button:SetFrameLevel(row:GetFrameLevel() + 1)
        card.round:SetFrameLevel(row:GetFrameLevel() + 2)
        card.button:ClearAllPoints()
        card.button:SetPoint("TOPLEFT", row, "TOPLEFT",
            layout.left + column * (layout.cardW + CARD_GAP), -rowIndex * (layout.cardH + CARD_GAP))
    end
end

-- Called by the page build. Returns the height taken, the preview column's width and the gap beside it.
function M.BuildNavigation(sc, onSelect)
    EnsureRow(sc, onSelect)
    local width = sc:GetWidth()
    local layout = ComputeLayout(width, #cards)

    row:SetParent(sc)
    row:SetFrameStrata(sc:GetFrameStrata())
    row:SetFrameLevel(sc:GetFrameLevel() + 1)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
    row:SetSize(width, layout.height)
    PlaceCards(layout)
    PaintAll()
    RefreshStatus()
    row:Show()
    if row:IsVisible() then PlayOrbs() end

    return layout.height + ROW_BOTTOM_GAP, PreviewWidth(width), COLUMN_GAP
end

function M.Setup(ctx)
    if not ctx or (ctx.client ~= "retail" and ctx.client ~= "forever") then
        error("AuraRemindersCards.Setup: ctx.client must be \"retail\" or \"forever\"", 2)
    end
    S, P = ctx.Widgets, ctx.Preview
    S.OnSettingChanged = RefreshStatus
end
