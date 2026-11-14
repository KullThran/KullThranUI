-- Nameplates options: the General page. Publishes ns.OptionsGeneral with Setup and Build.
-- Built from a behaviour specification. Saved access, swatches and plate loops go through ns.OptionsPreview.

local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

local WHITE8 = "Interface\\Buttons\\WHITE8x8"
local COG_ICON = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png"
local DEFAULT_FONT = "AAA_ITC_Avant_Garde"
local OLD_FONT_FOLDER = "interface\\addons\\kullthranui\\media\\fonts\\"

local STYLE_CARDS = {
    { key = "kui", label = "KUI" },
    { key = "forever", label = "Forever" },
    { key = "retail", label = "Retail" },
    { key = "classic", label = "Classic" },
}

-- Spells shown on the style samples, one per card.
local SAMPLE_SPELLS = {
    WARRIOR = { 100, 6343, 1680, 23922 },
    DEATHKNIGHT = { 49998, 49143, 55090, 47541 },
    PALADIN = { 20271, 35395, 19750, 853 },
    HUNTER = { 56641, 34026, 5116, 19434 },
    ROGUE = { 1752, 1943, 2098, 1766 },
    PRIEST = { 585, 589, 2061, 8092 },
    SHAMAN = { 188196, 8042, 51505, 8004 },
    MAGE = { 116, 133, 30451, 2948 },
    WARLOCK = { 686, 172, 29722, 116858 },
    MONK = { 100780, 100784, 107428, 116694 },
    DRUID = { 8921, 5176, 774, 8936 },
    DEMONHUNTER = { 162243, 185123, 198013, 188499 },
    EVOKER = { 361469, 362969, 357208, 355913 },
}

-- Key prefixes removed by a style click.
local STYLE_WIPE_PREFIXES = {
    "healthBar", "castBar", "cast", "enemyName", "level", "name", "classPower",
    "textSlot", "raidMarker", "rareElite", "targetArrow", "focusCast",
}

-- Spells the pandemic preview icon rolls from.
local PREVIEW_POOLS = {
    DRUID = { 1079, 8921 },
    DEATHKNIGHT = { 194310 },
    SHAMAN = { 188389 },
    WARLOCK = { 980 },
    ROGUE = { 1943 },
}
local PREVIEW_POOL_OTHER = { 1079, 8921, 194310, 188389, 980, 1943 }
local PREVIEW_ICON_FALLBACK = 136197
local PREVIEW_SIZE = 36

-- Set by Setup.
local clientName, panel, defaults
-- Survive page rebuilds: the newest preview frame and the icon rolled last.
local previewFrame, rolledIcon

---------------------------------------------------------------------------------------------------
-- Shared layer and refresh calls
---------------------------------------------------------------------------------------------------
local function L(text) return ns.OptionsPreview.LText(text) end
local function DB() return ns.OptionsPreview.DB() end
local function Saved(k) return (ns.OptionsPreview.DBVal(k)) end
local function SavedT(k) return (ns.OptionsPreview.DBRaw(k)) end
local function SavedOr(k) return Saved(k) or defaults[k] end

local function RefreshAuras() ns.OptionsPreview.RefreshAllAuras() end
local function RefreshPlates() ns.OptionsPreview.RefreshAllPlates() end
local function RefreshFonts() ns.OptionsPreview.RefreshAllFonts() end

-- Runs an optional ns function when present.
local function CallOptional(name)
    local fn = ns[name]
    if fn then fn() end
end

local function PanelPreview() panel.UpdatePreview() end
local function RefreshPageNow() KT:RefreshPage() end
local function FriendlySystem() CallOptional("UpdateFriendlyNameplateSystem") end
local function DotRefresh() CallOptional("RefreshDotDamage") end
local function ClassIconRefresh() CallOptional("RefreshClassIcons") end

-- Refresh chain after any text style change.
local function TextChain()
    RefreshFonts()
    CallOptional("RefreshFriendlyFontOverride")
    CallOptional("RefreshFriendlyTextStyle")
    CallOptional("UpdateFriendlyNameplateSystem")
    PanelPreview()
end

-- Writes a CVar from a truth value; a refusal does not stop the caller.
local function WriteCVar(name, value)
    if SetCVar then pcall(SetCVar, name, value and 1 or 0) end
end

---------------------------------------------------------------------------------------------------
-- Readers, writers and row descriptors
---------------------------------------------------------------------------------------------------
local function ReadIsTrue(k) return function() return Saved(k) == true end end
local function ReadNotFalse(k) return function() return Saved(k) ~= false end end
local function ReadOrDefault(k) return function() return SavedOr(k) end end

-- A setter that stores the value under k, then runs an optional chain.
local function Store(k, chain)
    return function(value)
        DB()[k] = value
        if chain then chain() end
    end
end

-- A colour setter that stores a new table under k, then runs a chain.
local function StoreColor(k, chain)
    return function(r, g, b)
        DB()[k] = { r = r, g = g, b = b }
        chain()
    end
end

-- A row cell. extra holds range, values, tooltips and the like; text fields get localised.
local function Cell(kind, text, get, set, extra)
    local d = { type = kind, text = L(text), getValue = get, setValue = set }
    if extra then
        for k, v in pairs(extra) do d[k] = v end
        if extra.tooltip then d.tooltip = L(extra.tooltip) end
        if extra.disabledTooltip then d.disabledTooltip = L(extra.disabledTooltip) end
    end
    return d
end

local function LabelCell(text) return { type = "label", text = text } end

-- Values and order of the glow style dropdowns.
local function GlowStyleChoices()
    local values, order = { [0] = "None" }, { 0 }
    for i, entry in ipairs(ns.PANDEMIC_GLOW_STYLES) do
        values[i] = entry.name
        order[#order + 1] = i
    end
    return values, order
end

---------------------------------------------------------------------------------------------------
-- Page cursor: p holds W, VT, parent and the current y
---------------------------------------------------------------------------------------------------
local function Step(p, widget, height)
    p.y = p.y - height
    return widget
end
local function Header(p, text) return Step(p, p.W:SectionHeader(p.parent, text, p.y)) end
local function Spacer(p, height) return Step(p, p.W:Spacer(p.parent, p.y, height)) end
local function Row(p, left, right) return Step(p, p.W:DualRow(p.parent, p.y, left, right)) end
local function Label(p, text, size, color) return Step(p, p.W:Label(p.parent, text, p.y, size, color)) end

-- Swatch on a parent at the shared size and level.
local function NewSwatch(parent, get, set)
    return ns.OptionsPreview.BuildColorSwatch(parent, parent:GetFrameLevel() + 5, get, set, nil, 20)
end

-- Swatch on a row's left region, left of its control.
local function InlineSwatch(row, get, set)
    local region = row._leftRegion
    local swatch, repaint = NewSwatch(region, get, set)
    KT.PP.Point(swatch, "RIGHT", region._control, "LEFT", -12, 0)
    return swatch, repaint
end

local function SetDimmed(swatch, off)
    swatch:SetAlpha(off and 0.15 or 1)
    swatch:EnableMouse(not off)
end

local function Unsnap(tex)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end

---------------------------------------------------------------------------------------------------
-- Style cards
---------------------------------------------------------------------------------------------------
local function CurrentStyle()
    local fn = ns.NameplateStyle
    return fn and fn() or "kui"
end

local function PaintCards(cards, VT)
    local current = CurrentStyle()
    for _, card in ipairs(cards) do
        local on = card.key == current
        if VT and VT.PaintStyleCard then
            local c = VT:GlowTileColors(card.key)
            VT:PaintStyleCard(card, c[1], c[2], c[3], on, card._hovered)
            card._selection:Hide()
        elseif on then
            card._selection:Show()
        else
            card._selection:Hide()
        end
        if on then
            card._label:SetTextColor(1, 0.82, 0)
        else
            card._label:SetTextColor(0.75, 0.75, 0.75)
        end
    end
end

-- Removes the style-owned keys from a table.
local function WipeStyleKeys(t)
    for k in pairs(t) do
        if type(k) == "string" then
            for _, prefix in ipairs(STYLE_WIPE_PREFIXES) do
                if k:sub(1, #prefix) == prefix then
                    t[k] = nil
                    break
                end
            end
        end
    end
end

local function ShowStyleReloadDialog(label)
    StaticPopupDialogs["KT_NP_STYLE_RELOAD"] = {
        text = string.format(
            L("Nameplate style changed to %s. Sizes and dimensions were reset to that style. Reload the interface to finish applying it?"),
            tostring(L(label))),
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function() ReloadUI() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("KT_NP_STYLE_RELOAD")
end

-- Applies a style card: wipe, seed, write, refresh, repaint, ask for a reload.
local function ApplyStyle(spec, cards, VT)
    local key = spec.key
    local db = DB()
    if key == CurrentStyle() and db.nameplateStyle == key then return end

    local adapter = VT and VT.GetModuleAdapter and VT:GetModuleAdapter("nameplates")
    local profile = adapter and adapter.getProfile and adapter.getProfile() or db

    WipeStyleKeys(db)
    WipeStyleKeys(profile)
    if adapter and adapter.seed then
        pcall(adapter.seed, profile, key)
        if adapter.validate then pcall(adapter.validate, profile) end
    end
    db.nameplateStyle = key
    profile.nameplateStyle = key
    db.classPowerPos = "bottom"
    CallOptional("RefreshThemeSkin")
    RefreshPlates()
    PaintCards(cards, VT)
    ShowStyleReloadDialog(spec.label)
end

-- Four gold strips around the card, hidden until painted.
local function BuildCardSelection(card)
    local sel = CreateFrame("Frame", nil, card)
    sel:SetAllPoints(card)
    sel:Hide()
    local function strip(a, b)
        local t = sel:CreateTexture(nil, "BORDER")
        t:SetTexture(WHITE8)
        t:SetVertexColor(1, 0.82, 0, 1)
        t:SetPoint(a, sel, a, 0, 0)
        t:SetPoint(b, sel, b, 0, 0)
        return t
    end
    strip("TOPLEFT", "TOPRIGHT"):SetHeight(1)
    strip("BOTTOMLEFT", "BOTTOMRIGHT"):SetHeight(1)
    strip("TOPLEFT", "BOTTOMLEFT"):SetWidth(1)
    strip("TOPRIGHT", "BOTTOMRIGHT"):SetWidth(1)
    return sel
end

-- Builds the plate sample on a card, when the builder exists and succeeds.
local function BuildCardSample(card, key, index)
    local builder = ns.BuildNameplateStyleSample
    if not builder then return end
    local _, class = UnitClass("player")
    local id = (SAMPLE_SPELLS[class] or SAMPLE_SPELLS.MAGE)[index]
    local spellApi = C_Spell
    local icon = spellApi and spellApi.GetSpellTexture and spellApi.GetSpellTexture(id)
    local spell = spellApi and spellApi.GetSpellName and spellApi.GetSpellName(id)
    local ok, sample = pcall(builder, card, key, {
        name = L("Mob Name"),
        level = UnitLevel("player") or 60,
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        spell = spell or "",
    })
    if not ok or not sample then return end
    local scale = math.min(128 / sample:GetWidth(), 62 / sample:GetHeight())
    sample:SetScale(scale)
    sample:SetPoint("CENTER", card, "TOP", 0, -37 / scale)
    sample:SetFrameLevel(card:GetFrameLevel() + 2)
end

local function BuildCard(holder, index, spec, cards, VT)
    local card = CreateFrame("Button", nil, holder)
    card:SetSize(140, 92)
    card:SetPoint("TOPLEFT", holder, "TOPLEFT", (index - 1) * 146, 0)
    card.key = spec.key

    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE8)
    bg:SetVertexColor(0.05, 0.05, 0.06, 0.8)
    bg:SetAllPoints(card)
    if VT and VT.SkinStyleCard then
        VT:SkinStyleCard(card)
        bg:Hide()
    end

    card._selection = BuildCardSelection(card)

    local label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", card, "BOTTOM", 0, 6)
    label:SetText(L(spec.label))
    card._label = label

    BuildCardSample(card, spec.key, index)

    card:SetScript("OnEnter", function(self)
        self._hovered = true
        PaintCards(cards, VT)
        self._label:SetTextColor(1, 1, 1)
    end)
    card:SetScript("OnLeave", function(self)
        self._hovered = nil
        PaintCards(cards, VT)
    end)
    card:SetScript("OnClick", function() ApplyStyle(spec, cards, VT) end)
    return card
end

local function BuildStyleCards(p)
    local holder = CreateFrame("Frame", nil, p.parent)
    holder:SetPoint("TOP", p.parent, "TOP", 0, p.y)
    holder:SetSize(578, 92)
    local cards = {}
    for i, spec in ipairs(STYLE_CARDS) do
        cards[i] = BuildCard(holder, i, spec, cards, p.VT)
    end
    PaintCards(cards, p.VT)
    p.y = p.y - 106
end

---------------------------------------------------------------------------------------------------
-- Popups and cogs
---------------------------------------------------------------------------------------------------
-- One watcher per popup, reused on every open. Its button state lasts as long as the popup:
-- it starts false and is only updated here. Closes on a left press away from popup and owner.
local function NewClickOutsideWatcher()
    local wasDown = false
    return function(self)
        local down = IsMouseButtonDown("LeftButton")
        if down and not wasDown and not self:IsMouseOver()
            and not (self._owner and self._owner:IsMouseOver()) then
            self:Hide()
        end
        wasDown = down
    end
end

-- The popup shell: frame, background, border, hide script, menu hook and title.
local function NewPopup(height, title)
    local menu = KT.MenuPrincipal
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(math.max(1200, (menu and menu:GetFrameLevel() or 0) + 80))
    f:EnableMouse(true)
    f:Hide()
    f:SetHeight(height)
    KT.SolidTex(f, "BACKGROUND", 0.06, 0.08, 0.10, 0.95):SetAllPoints(f)
    local c = KT.NP_BORDER_COLOR
    KT.MakeBorder(f, c.r, c.g, c.b, 0.15)
    f._repaints = {}
    f._clickOutside = NewClickOutsideWatcher()

    f:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        if self._owner then self._owner:SetAlpha(0.4) end
        self._owner = nil
    end)
    if menu then
        menu:HookScript("OnHide", function()
            if f:IsShown() then f:Hide() end
        end)
    end

    local titleFS = KT.MakeFont(f, 11, "", 1, 1, 1)
    titleFS:SetAlpha(0.7)
    titleFS:SetPoint("TOP", f, "TOP", 0, -14)
    titleFS:SetText(L(title))
    return f
end

-- Measures raw label texts with a hidden string, sets the popup width, returns slider x and width.
local function MeasurePopup(f, texts, fallback)
    local probe = f:CreateFontString(nil, "OVERLAY")
    probe:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, ns.OptionsPreview.OptOutline())
    local widest = 0
    for _, text in ipairs(texts) do
        probe:SetText(text)
        widest = math.max(widest, probe:GetStringWidth())
    end
    probe:Hide()
    if widest < 10 then widest = fallback end
    local sliderLeft = 14 + widest + 12
    local sliderW = math.max(80, 260 - sliderLeft - 8 - 34 - 14)
    f:SetWidth(math.max(180, sliderLeft + sliderW + 8 + 34 + 14))
    return sliderLeft, sliderW
end

local function PopupLabel(f, text, y)
    local fs = KT.MakeFont(f, 11, nil, 1, 1, 1)
    fs:SetAlpha(0.6)
    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 14, y)
    fs:SetText(L(text))
end

-- The core pushes a first value through the setter as it builds a slider. That is not a change.
local function PopupSlider(f, sliderLeft, sliderW, y, minV, maxV, get, set)
    local building = true
    local slider, edit = KT.BuildSliderCore(f, sliderW, 4, 12, 34, 24, 11, 0.55, minV, maxV, 1, get, function(v)
        if not building then set(v) end
    end, true)
    building = false
    slider:SetPoint("TOPLEFT", f, "TOPLEFT", sliderLeft, y - 2)
    edit:ClearAllPoints()
    edit:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, y)
end

-- Hand-made on/off toggle. onClick does the work; the toggle repaints after it and on each show.
local function PopupToggle(f, y, isOn, onClick)
    local btn = CreateFrame("Button", nil, f)
    btn:SetSize(32, 16)
    btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, y)
    local bg = KT.SolidTex(btn, "BACKGROUND")
    bg:SetAllPoints(btn)
    local knob = btn:CreateTexture(nil, "ARTWORK")
    knob:SetSize(12, 12)
    local function repaint()
        knob:ClearAllPoints()
        if isOn() then
            local g = KT.NP_GREEN
            bg:SetColorTexture(g.r, g.g, g.b, 0.45)
            knob:SetColorTexture(1, 1, 1, 0.95)
            knob:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
        else
            bg:SetColorTexture(0.18, 0.18, 0.18, 0.85)
            knob:SetColorTexture(0.55, 0.55, 0.55, 1)
            knob:SetPoint("LEFT", btn, "LEFT", 2, 0)
        end
    end
    btn:SetScript("OnClick", function()
        onClick()
        repaint()
    end)
    f._repaints[#f._repaints + 1] = repaint
end

-- Toggles the popup from its cog: fade and slide in, then the click-outside watch.
local function ShowPopup(popup, cog)
    if popup._owner == cog and popup:IsShown() then
        popup:Hide()
        return
    end
    popup._owner = cog
    for _, repaint in ipairs(popup._repaints) do repaint() end
    popup:ClearAllPoints()
    popup:SetPoint("BOTTOM", cog, "TOP", 0, 6)
    popup:SetAlpha(0)
    popup:Show()
    local elapsedTotal = 0
    popup:SetScript("OnUpdate", function(self, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        local t = math.min(elapsedTotal / 0.15, 1)
        self:SetAlpha(t)
        self:ClearAllPoints()
        self:SetPoint("BOTTOM", cog, "TOP", 0, 6 - 8 * (1 - t))
        if t >= 1 then self:SetScript("OnUpdate", self._clickOutside) end
    end)
end

-- A cog button with its icon, sized and levelled; the caller anchors it.
local function NewCog(region)
    local cog = CreateFrame("Button", nil, region)
    cog:SetSize(26, 26)
    cog:SetFrameLevel(region:GetFrameLevel() + 5)
    local icon = cog:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(cog)
    icon:SetTexture(KT.RESIZE_ICON or COG_ICON)
    ns.OptionsPreview.ApplyAccentToIcon(icon)
    return cog
end

-- Cog behaviour shared by all three: hover, leave, click and the panel open alpha.
local function WireCog(cog, isOff, offTooltip, buildPopup)
    local popup
    local function ownsPopup() return popup ~= nil and popup._owner == cog end
    local function restAlpha()
        if not ownsPopup() then cog:SetAlpha(isOff() and 0.15 or 0.4) end
    end
    cog:SetScript("OnEnter", function()
        if isOff() then
            ns.OptionsPreview.ShowTooltip(cog, offTooltip)
        else
            cog:SetAlpha(0.7)
        end
    end)
    cog:SetScript("OnLeave", function()
        ns.OptionsPreview.HideTooltip()
        restAlpha()
    end)
    cog:SetScript("OnClick", function()
        if isOff() then return end
        popup = popup or buildPopup()
        ShowPopup(popup, cog)
    end)
    ns.OptionsPreview.RegisterWidgetRefresh(restAlpha)
end

---------------------------------------------------------------------------------------------------
-- Forever: friendly popups
---------------------------------------------------------------------------------------------------
local function PlayersOff()
    return Saved("showFriendlyPlayers") == false and Saved("friendlyShowDefaultNames") ~= true
end
local function PlateCogOff() return PlayersOff() or Saved("friendlyPlayerNameOnly") ~= false end
local function NameCogOff() return PlayersOff() or Saved("friendlyPlayerNameOnly") == false end

local function ToggleDefaultNames()
    local db = DB()
    local on = not (db.friendlyShowDefaultNames == true)
    db.friendlyShowDefaultNames = on
    if on then
        db.showFriendlyPlayers = false
        WriteCVar("nameplateShowFriendlyPlayers", false)
        WriteCVar("nameplateShowFriends", false)
    end
    WriteCVar("UnitNameFriendlyPlayerName", on)
    FriendlySystem()
    RefreshPageNow()
end

local function BuildPlatePopup()
    local f = NewPopup(227, "Friendly Nameplate Settings")
    local left, width = MeasurePopup(f, { "Distance", "Height", "Width" }, 60)

    PopupLabel(f, "Distance", -45)
    PopupSlider(f, left, width, -45, -50, 50,
        function() return Saved("friendlyPlateYOffset") or 0 end,
        function(v)
            DB().friendlyPlateYOffset = v
            CallOptional("RefreshFriendlyPlateYOffset")
        end)
    PopupLabel(f, "Height", -79)
    PopupSlider(f, left, width, -79, 6, 40, ReadOrDefault("friendlyHealthBarHeight"), function(v)
        DB().friendlyHealthBarHeight = v
        CallOptional("RefreshFriendlyPlateSize")
    end)
    PopupLabel(f, "Width", -113)
    PopupSlider(f, left, width, -113, 80, 250, ReadOrDefault("friendlyHealthBarWidth"), function(v)
        DB().friendlyHealthBarWidth = v
        CallOptional("RefreshFriendlyPlateSize")
    end)

    PopupLabel(f, "Show Health Percent", -147)
    PopupToggle(f, -147, function()
        local db = _G.KullThranUINameplatesDB
        return not (db and db.friendlyHideHealthText)
    end, function()
        local db = DB()
        db.friendlyHideHealthText = not db.friendlyHideHealthText
        CallOptional("RefreshFriendlyHealthText")
    end)

    PopupLabel(f, "Show Default Names", -185)
    PopupToggle(f, -185, function()
        local db = _G.KullThranUINameplatesDB
        return db ~= nil and db.friendlyShowDefaultNames == true
    end, ToggleDefaultNames)
    return f
end

local function BuildNamePopup()
    local f = NewPopup(121, "Name Only Settings")

    PopupLabel(f, "Class Colored", -45)
    local classColored = ReadNotFalse("classColorFriendly")
    PopupToggle(f, -45, classColored, function()
        local value = not classColored()
        DB().classColorFriendly = value
        WriteCVar("ShowClassColorInFriendlyNameplate", value)
        WriteCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", value)
    end)

    local left, width = MeasurePopup(f, { "Distance" }, 55)
    PopupLabel(f, "Distance", -83)
    PopupSlider(f, left, width, -83, -50, 50, ReadOrDefault("friendlyNameOnlyYOffset"), function(v)
        DB().friendlyNameOnlyYOffset = v
        CallOptional("RefreshFriendlyNameOnlyOffset")
    end)
    return f
end

local function FriendlyCog(region, isOff, offTooltip, buildPopup)
    local control = region._control
    if control and control.SetReservedRightSpace then control:SetReservedRightSpace(40) end
    local cog = NewCog(region)
    cog:SetPoint("RIGHT", region, "RIGHT", -12, 0)
    cog:SetAlpha(isOff() and 0.15 or 0.4)
    WireCog(cog, isOff, offTooltip, buildPopup)
end

---------------------------------------------------------------------------------------------------
-- Friendly rows, text style
---------------------------------------------------------------------------------------------------
local function BuildFriendlyRows(p)
    local forever = clientName == "forever"

    local showPlayers = Cell("toggle", "Show Friendly Player Nameplates", ReadNotFalse("showFriendlyPlayers"), function(v)
        local db = DB()
        db.showFriendlyPlayers = v
        if v then db.friendlyShowDefaultNames = false end
        WriteCVar("nameplateShowFriendlyPlayers", v)
        WriteCVar("nameplateShowFriends", v)
        FriendlySystem()
        ns.RefreshStackingMotion()
        RefreshPageNow()
    end)
    local nameOnly = Cell("toggle", forever and "Make Friendly Players Name Only" or "Only Name - Friendly Players",
        ReadNotFalse("friendlyPlayerNameOnly"), function(v)
            DB().friendlyPlayerNameOnly = v
            WriteCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", v)
            FriendlySystem()
            RefreshPageNow()
        end, {
            tooltip = "Friendly players show only their name, without a health bar.\n\nTurn off 'Simplified Friendly Nameplates' first, in Esc > Options > Nameplates.",
            disabled = PlayersOff,
            disabledTooltip = "Show Friendly Player Nameplates",
        })
    local showNPCs = Cell("toggle", "Show Friendly NPC Nameplates", ReadIsTrue("showFriendlyNPCs"), function(v)
        DB().showFriendlyNPCs = v
        WriteCVar("nameplateShowFriendlyNPCs", v)
        WriteCVar("nameplateShowFriendlyNpcs", v)
        FriendlySystem()
        if not forever then RefreshPageNow() end
    end)
    local function petsCell()
        return Cell("toggle", "Show Enemy Pet Nameplates", ReadIsTrue("showEnemyPets"), function(v)
            DB().showEnemyPets = v
            WriteCVar("nameplateShowEnemyPets", v)
        end, { tooltip = "Toggle visibility of enemy pet nameplates." })
    end

    local firstRow = Row(p, showPlayers, nameOnly)
    if forever then
        Row(p, Cell("toggle", "Show Guild Under Friendly Players", ReadNotFalse("friendlyShowGuild"), function(v)
            DB().friendlyShowGuild = v
            FriendlySystem()
            if ns.friendlyPlates then
                for _, plate in pairs(ns.friendlyPlates) do
                    if plate.UpdateName then plate:UpdateName() end
                end
            end
        end, {
            tooltip = "Shows the player's guild name under friendly player nameplates (white text).",
            disabled = PlayersOff,
            disabledTooltip = "Show Friendly Player Nameplates",
        }), LabelCell(""))
        FriendlyCog(firstRow._leftRegion, PlateCogOff, "Requires Name Only setting to be disabled", BuildPlatePopup)
        FriendlyCog(firstRow._rightRegion, NameCogOff, "Requires Name Only mode", BuildNamePopup)
        Row(p, showNPCs, petsCell())
    else
        Row(p, showNPCs, Cell("toggle", "Only Name - Friendly NPCs", ReadNotFalse("friendlyNPCNameOnly"), function(v)
            DB().friendlyNPCNameOnly = v
            FriendlySystem()
            RefreshPageNow()
        end, {
            tooltip = "Hide friendly NPC health bars and show only their names.",
            disabled = function() return Saved("showFriendlyNPCs") ~= true end,
            disabledTooltip = "Show Friendly NPC Nameplates",
        }))
        Row(p, petsCell(), LabelCell(""))
    end
end

local function DefaultFontName()
    if KT.GetDefaultFontName then return KT:GetDefaultFontName() end
    return DEFAULT_FONT
end

-- Dropdown values of the global font, run when the dropdown wants them.
local function FontValues()
    local values, any = {}, false
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            if not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
                values[name] = name
                any = true
            end
        end
    end
    if not any then
        local name = DefaultFontName()
        values[name] = name
    end
    values._menuOpts = {
        kind = "font",
        sharedMedia = true,
        resolve = function(name)
            if LSM then return LSM:Fetch("font", name, true) end
            return nil
        end,
    }
    return values
end

-- The saved font as a dropdown key.
local function CurrentFont()
    local value = SavedOr("font")
    if KT.IsLocalizedDefaultFont and KT:IsLocalizedDefaultFont(value) and KT.GetDefaultFontName then
        value = KT:GetDefaultFontName()
    end
    if type(value) ~= "string" then return value end
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            if name == value or LSM:Fetch("font", name, true) == value then return name end
        end
    end
    if value:gsub("/", "\\"):lower():find(OLD_FONT_FOLDER, 1, true) then return DefaultFontName() end
    return value
end

local function WriteFont(value)
    DB().font = LSM and LSM:Fetch("font", value, true) or value
    TextChain()
end

local function ReadFriendlyColor(k, fr, fg, fb)
    return function()
        local c = SavedT(k)
        if type(c) == "table" and c.r and c.g and c.b then return c.r, c.g, c.b end
        return fr, fg, fb
    end
end

local function SizeCell(text, k, maxV)
    return Cell("slider", text, ReadOrDefault(k), Store(k, TextChain), { min = 8, max = maxV, step = 1 })
end

local function AlignCell(text, k)
    return Cell("dropdown", text, ReadOrDefault(k), Store(k, TextChain), {
        values = { center = "Centered", left = "From Left", right = "From Right" },
        order = { "center", "left", "right" },
    })
end

local function FriendlyColorCell(text, k, fr, fg, fb)
    return Cell("colorpicker", text, ReadFriendlyColor(k, fr, fg, fb), StoreColor(k, TextChain))
end

local function BuildTextStyle(p)
    Header(p, "FONT")
    Row(p, Cell("dropdown", "Global Font", CurrentFont, WriteFont, { values = FontValues }),
        Cell("dropdown", "Outline", function() return SavedOr("fontOutline") or "OUTLINE" end, Store("fontOutline", TextChain), {
            values = { [""] = "None", OUTLINE = "Thin", THICKOUTLINE = "Thick", MONOCHROMEOUTLINE = "Monochrome" },
            order = { "", "OUTLINE", "THICKOUTLINE", "MONOCHROMEOUTLINE" },
        }))
    Row(p, Cell("toggle", "Text Shadow", function() return Saved("fontShadow") ~= false end, Store("fontShadow", TextChain)),
        LabelCell(""))
end

local function BuildFriendlyColors(p)
    Header(p, "FRIENDLY COLORS")
    Row(p, FriendlyColorCell("Friendly Player Name Color", "friendlyPlayerNameColor", 1, 1, 1),
        FriendlyColorCell("Friendly NPC Name Color", "friendlyNPCNameColor", 0, 1, 0))
    Row(p, FriendlyColorCell("Friendly Guild Color", "friendlyGuildColor", 1, 1, 1),
        FriendlyColorCell("Friendly Health Text Color", "friendlyHealthTextColor", 1, 1, 1))
end

-- Forever only: keeps the default-name switch that lived in the friendly cog.
local function BuildDefaultNames(p)
    if clientName ~= "forever" then return end
    Row(p, Cell("toggle", "Show Default Names", function()
        return Saved("friendlyShowDefaultNames") == true
    end, ToggleDefaultNames), LabelCell(""))
end

local function BuildEnemyPets(p)
    Header(p, "ENEMY UNITS")
    Row(p, Cell("toggle", "Show Enemy Pet Nameplates", ReadIsTrue("showEnemyPets"), function(v)
        DB().showEnemyPets = v
        WriteCVar("nameplateShowEnemyPets", v)
    end, { tooltip = "Toggle visibility of enemy pet nameplates." }), LabelCell(""))
end

---------------------------------------------------------------------------------------------------
-- Stacking, DoT damage, class icons, extras
---------------------------------------------------------------------------------------------------
local function BuildStacking(p)
    Header(p, "ENEMY NAMEPLATE SPACING")
    Row(p, Cell("toggle", "Enable Stacking Nameplates", ReadNotFalse("stackingEnabled"), function(v)
            DB().stackingEnabled = v
            ns.RefreshStackingMotion()
        end, { tooltip = "When enabled, nameplates stack vertically instead of overlapping." }),
        Cell("slider", "Stacked Nameplate Spacing", ReadOrDefault("stackSpacingScale"), function(v)
            DB().stackSpacingScale = v
            ns.RefreshStackingBounds()
        end, {
            min = 50, max = 200, step = 5, trackWidth = 130,
            tooltip = "Adjusts the vertical spacing between stacked nameplates. 100% = default, lower = tighter, higher = more spread.",
        }))
end

-- Saved value, then the DoT module's own default.
local function DotSetting(k)
    local value = Saved(k)
    if value == nil then
        local t = ns.DOT_DAMAGE_DEFAULTS
        value = t and t[k]
    end
    return value
end

local function DotDropdown(lists, text, k, listName, numeric)
    local values, order = {}, {}
    for _, entry in ipairs(lists[listName] or {}) do
        local key = tostring(entry[1])
        values[key] = entry[2]
        order[#order + 1] = key
    end
    return Cell("dropdown", text, function() return tostring(DotSetting(k)) end, function(v)
        if numeric then v = tonumber(v) or v end
        DB()[k] = v
        DotRefresh()
    end, { values = values, order = order })
end

local function DotSlider(text, k, minV, maxV, step)
    return Cell("slider", text, function() return tonumber(DotSetting(k)) or 0 end, Store(k, DotRefresh),
        { min = minV, max = maxV, step = step })
end

local function DotColor(text, k, read)
    return Cell("colorpicker", text, function()
        if read then return read() end
        return 1, 1, 1
    end, StoreColor(k, DotRefresh))
end

local function BuildDotDamage(p)
    local lists = ns.DOT_DAMAGE_LISTS or {}
    Header(p, "DOT DAMAGE")
    Row(p, Cell("toggle", "Show Pending DoT Damage", ReadIsTrue("dotDamageEnabled"), Store("dotDamageEnabled", DotRefresh), {
            tooltip = "Draws a marker on every enemy nameplate with your DoTs on it, for the damage they still have to deal. If the health ends inside the marker, the DoTs will kill it.",
        }),
        DotDropdown(lists, "Wait for First Tick", "dotDamageWaitFirstTick", "waitModes"))
    Row(p, DotDropdown(lists, "DoT Colors", "dotDamageColors", "dotColors"),
        DotDropdown(lists, "Fill Style", "dotDamageFill", "fills"))
    Row(p, DotColor("Fill Color", "dotDamageColor", ns.GetDotDamageColor),
        DotSlider("Fill Opacity", "dotDamageFillOpacity", 0, 100, 5))
    Row(p, DotDropdown(lists, "Outline", "dotDamageOutline", "outlines"),
        DotDropdown(lists, "Dash Length", "dotDamageDashLength", "dashLengths", true))
    Row(p, DotSlider("Outline Thickness", "dotDamageOutlineThickness", 1, 3, 1),
        DotColor("Outline Color", "dotDamageOutlineColor", ns.GetDotDamageOutlineColor))
    Row(p, DotSlider("Outline Opacity", "dotDamageOutlineOpacity", 10, 100, 5),
        { type = "button", text = L("Forget Learned Tick Sizes"), onClick = function() CallOptional("ResetDotTicks") end })
    Row(p, Cell("toggle", "Show Kill Icon", function() return DotSetting("dotDamageKillIcon") == true end,
            Store("dotDamageKillIcon", DotRefresh), { tooltip = "Shows an icon next to the nameplate when your DoTs will kill it." }),
        DotDropdown(lists, "Kill Icon", "dotDamageIcon", "icons"))
    Row(p, DotSlider("Kill Icon Size", "dotDamageIconSize", 12, 32, 1),
        DotDropdown(lists, "Kill Icon Position", "dotDamageIconPosition", "iconPositions"))
    Row(p, DotSlider("Icon Horizontal Offset", "dotDamageIconOffsetX", -40, 40, 1),
        DotSlider("Icon Vertical Offset", "dotDamageIconOffsetY", -40, 40, 1))
end

local function BuildClassIcons(p)
    Header(p, "FRIENDLY CLASS ICONS")
    Row(p, Cell("toggle", "Show Class Icons on Friendly Players", ReadIsTrue("friendlyClassIcons"),
            Store("friendlyClassIcons", ClassIconRefresh), {
                tooltip = "Shows a big round icon over friendly players: the healer cross for healers, otherwise their spec or class icon.",
            }),
        Cell("slider", "Class Icon Size", function()
            return tonumber(Saved("friendlyClassIconSize")) or ns.CLASS_ICON_DEFAULT_SIZE or 34
        end, Store("friendlyClassIconSize", ClassIconRefresh), { min = 16, max = 64, step = 1 }))
    Row(p, Cell("slider", "Class Icon Height", function()
        return tonumber(Saved("friendlyClassIconYOffset")) or 0
    end, Store("friendlyClassIconYOffset", ClassIconRefresh), { min = -40, max = 60, step = 1 }), nil)
end

local function BuildShownAuras(p)
    Header(p, "SHOWN AURAS")
    Row(p, Cell("toggle", "Show All Your Player Debuffs", ReadIsTrue("showAllDebuffs"), Store("showAllDebuffs", RefreshAuras), {
            tooltip = "This will display ALL of your debuffs on enemy nameplates, rather than only the important ones.",
        }), LabelCell(""))
end

---------------------------------------------------------------------------------------------------
-- Distance. The plates read these keys themselves, so most setters refresh nothing.
---------------------------------------------------------------------------------------------------
local function BuildDistance(p)
    local W, parent = p.W, p.parent
    local function dropdown(text, k, fallback, values, order)
        Step(p, W:Dropdown(parent, text, p.y, values, function() return Saved(k) or fallback end, Store(k), order))
    end
    local function slider(text, k, fallback, minV, maxV, step)
        Step(p, W:Slider(parent, text, p.y, function() return Saved(k) or fallback end, Store(k), minV, maxV, step, "%d"))
    end

    Header(p, "DISTANCE")
    Step(p, W:Toggle(parent, "Show Distance over Enemy Nameplates", p.y, ReadIsTrue("rangeEnabled"), function(v)
        DB().rangeEnabled = v and true or false
        local range = ns.PlateRange
        if range and range.Refresh then range.Refresh() end
    end))
    dropdown("Distance Format", "rangeFormat", "max",
        { max = "Up to (max yards)", span = "Range (min-max)" }, { "max", "span" })
    dropdown("Distance Color", "rangeColor", "bands",
        { bands = "By distance (green to grey)", white = "White" }, { "bands", "white" })
    dropdown("Distance Shown On", "rangeScope", "all",
        { all = "All enemy nameplates", target = "Current target only" }, { "all", "target" })
    Step(p, W:Dropdown(parent, "Distance Font", p.y, FontValues,
        function() return Saved("rangeFont") or "Russo One" end, Store("rangeFont")))
    slider("Distance Text Size", "rangeSize", 16, 7, 24, 1)
    slider("Hide Beyond (yards)", "rangeMax", 100, 10, 100, 5)
    Label(p, "Distances are brackets from the spells and items your class can use, not exact yards.", 10)
end

---------------------------------------------------------------------------------------------------
-- Pandemic glow and its preview icon
---------------------------------------------------------------------------------------------------
local function PandemicOff() return Saved("pandemicGlow") ~= true end

-- The style index in use: core function, then saved, then 1 for anything outside the table.
local function PandemicStyle()
    local style = ns.GetPandemicGlowStyle and ns.GetPandemicGlowStyle()
    if not style then style = Saved("pandemicGlowStyle") or 1 end
    if type(style) ~= "number" or style < 1 or style > #ns.PANDEMIC_GLOW_STYLES then return 1 end
    return style
end

local function RollPreviewIcon()
    local _, class = UnitClass("player")
    local pool = PREVIEW_POOLS[class] or PREVIEW_POOL_OTHER
    local id = pool[math.random(#pool)]
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    rolledIcon = info and info.iconID or PREVIEW_ICON_FALLBACK
    if previewFrame then previewFrame._icon:SetTexture(rolledIcon) end
end

-- The flipbook texture and its one animation group, made once per frame.
local function EnsureFlipbook(f)
    if f._flipTex then return end
    local tex = f:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetPoint("CENTER", f, "CENTER", 0, 0)
    local group = tex:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    f._flipTex, f._flipGroup, f._flipAnim = tex, group, group:CreateAnimation("FlipBook")
end

local function PlayFlipbook(f, entry, r, g, b)
    local tex, anim = f._flipTex, f._flipAnim
    local size = PREVIEW_SIZE * (entry.previewScale or entry.scale or 1)
    tex:SetSize(size, size)
    if entry.atlas then
        tex:SetAtlas(entry.atlas)
    elseif entry.texture then
        tex:SetTexture(entry.texture)
    end
    anim:SetFlipBookRows(entry.rows or 6)
    anim:SetFlipBookColumns(entry.columns or 5)
    anim:SetFlipBookFrames(entry.frames or 30)
    anim:SetDuration(entry.duration or 1.0)
    anim:SetFlipBookFrameWidth(entry.frameW or 0)
    anim:SetFlipBookFrameHeight(entry.frameH or 0)
    tex:SetDesaturated(true)
    tex:SetVertexColor(r, g, b)
    tex:Show()
    f._flipGroup:Play()
end

-- Starts the glow of the current style on the preview.
local function StartPreviewGlow(f)
    local styles = ns.PANDEMIC_GLOW_STYLES
    local entry = styles[PandemicStyle()] or styles[1]
    local c = SavedT("pandemicGlowColor")
    local r, g, b = c.r, c.g, c.b
    if entry.procedural then
        local lines = SavedOr("pandemicGlowLines")
        local length = math.floor(72 * (2 / lines - 0.1))
        length = math.max(math.min(length, PREVIEW_SIZE), 1)
        ns.StartProceduralAnts(f, lines, SavedOr("pandemicGlowThickness"), SavedOr("pandemicGlowSpeed"), length, r, g, b, PREVIEW_SIZE)
    elseif entry.buttonGlow then
        ns.StartButtonGlow(f, PREVIEW_SIZE, r, g, b, entry.previewScale or 1.28)
    elseif entry.autocast then
        ns.StartAutoCastShine(f, PREVIEW_SIZE, r, g, b)
    else
        PlayFlipbook(f, entry, r, g, b)
    end
end

-- Restarts the glow on the newest preview frame only.
local function RefreshPandemicPreview()
    local f = previewFrame
    if not f then return end
    EnsureFlipbook(f)
    f._flipGroup:Stop()
    f._flipTex:Hide()
    ns.StopProceduralAnts(f)
    ns.StopButtonGlow(f)
    ns.StopAutoCastShine(f)
    local off = PandemicOff()
    f:SetAlpha(off and 0.3 or 1)
    if not off then StartPreviewGlow(f) end
end

-- Icon frame with a 1 pixel border, on the row itself.
local function BuildPreviewFrame(row)
    local PP = KT.PP
    local f = CreateFrame("Frame", nil, row)
    PP.Size(f, PREVIEW_SIZE, PREVIEW_SIZE)
    PP.Point(f, "RIGHT", row, "RIGHT", -20, 0)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(f)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(rolledIcon)
    f._icon = icon

    local function edge()
        local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(0, 0, 0, 1)
        Unsnap(t)
        return t
    end
    local thickness = PP.Scale(1)
    local top, bottom, left, right = edge(), edge(), edge(), edge()
    top:SetHeight(thickness)
    bottom:SetHeight(thickness)
    left:SetWidth(thickness)
    right:SetWidth(thickness)
    PP.Point(top, "TOPLEFT", f, "TOPLEFT", 0, 0)
    PP.Point(top, "TOPRIGHT", f, "TOPRIGHT", 0, 0)
    PP.Point(bottom, "BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    PP.Point(bottom, "BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    PP.Point(left, "TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    PP.Point(left, "BOTTOMLEFT", bottom, "TOPLEFT", 0, 0)
    PP.Point(right, "TOPRIGHT", top, "BOTTOMRIGHT", 0, 0)
    PP.Point(right, "BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
    return f
end

local function BuildPixelPopup()
    local f = NewPopup(151, "Pixel Glow Settings")
    local left, width = MeasurePopup(f, { "Lines", "Thickness", "Speed" }, 60)
    local function afterChange()
        RefreshAuras()
        RefreshPandemicPreview()
    end
    PopupLabel(f, "Lines", -45)
    PopupSlider(f, left, width, -45, 2, 16, ReadOrDefault("pandemicGlowLines"), Store("pandemicGlowLines", afterChange))
    PopupLabel(f, "Thickness", -79)
    PopupSlider(f, left, width, -79, 1, 4, ReadOrDefault("pandemicGlowThickness"), Store("pandemicGlowThickness", afterChange))
    PopupLabel(f, "Speed", -113)
    PopupSlider(f, left, width, -113, 1, 8,
        function() return 9 - SavedOr("pandemicGlowSpeed") end,
        function(v)
            DB().pandemicGlowSpeed = 9 - v
            afterChange()
        end)
    return f
end

local function PandemicCell()
    local values, order = GlowStyleChoices()
    return Cell("dropdown", "Pandemic Glow Style", function()
        if PandemicOff() then return 0 end
        return PandemicStyle()
    end, function(v)
        local db = DB()
        if v == 0 then
            db.pandemicGlow = false
        else
            db.pandemicGlow = true
            db.pandemicGlowStyle = v
        end
        RefreshAuras()
        RefreshPandemicPreview()
        -- Deferred: this setter runs inside the widget the page refresh destroys.
        C_Timer.After(0, RefreshPageNow)
    end, { values = values, order = order })
end

---------------------------------------------------------------------------------------------------
-- Pandemic row, debuff expiry glow, preview, pandemic swatch and cog, in creation order
---------------------------------------------------------------------------------------------------
local function BuildExpiryRows(p)
    local function expiryOff() return Saved("debuffExpiryGlow") ~= true end
    Row(p, Cell("toggle", "Debuff Expiry Glow", ReadIsTrue("debuffExpiryGlow"), function(v)
            DB().debuffExpiryGlow = v
            RefreshAuras()
            C_Timer.After(0, function() KT:RefreshPage(true) end)
        end, { tooltip = "Pulse debuff icons when they are about to expire on enemy nameplates." }),
        Cell("dropdown", "Expiry Threshold", function()
            return tonumber(Saved("debuffExpiryGlowThreshold")) or defaults.debuffExpiryGlowThreshold or 3
        end, Store("debuffExpiryGlowThreshold", RefreshAuras), {
            values = { "1 sec", "2 sec", "3 sec", "4 sec", "5 sec" },
            order = { 1, 2, 3, 4, 5 },
            disabled = expiryOff,
            disabledTooltip = "Debuff Expiry Glow",
        }))
    Row(p, Cell("toggle", "Use Debuff Type Color", ReadIsTrue("debuffExpiryGlowUseTypeColor"), function(v)
        DB().debuffExpiryGlowUseTypeColor = v
        RefreshAuras()
        RefreshPageNow()
    end, { tooltip = "Uses the debuff type color when available, such as Magic, Curse, Disease or Poison." }), nil)

    local labelFrame = Label(p, "Custom Expiry Glow Color", 11, { r = 0.75, g = 0.75, b = 0.75 })
    local get, set = ns.OptionsPreview.GlowColorPair("debuffExpiryGlowColor")
    local swatch, repaint = NewSwatch(labelFrame, get, set)
    KT.PP.Point(swatch, "RIGHT", labelFrame, "RIGHT", -12, 0)
    local function dim()
        SetDimmed(swatch, expiryOff() or Saved("debuffExpiryGlowUseTypeColor") == true)
    end
    dim()
    ns.OptionsPreview.RegisterWidgetRefresh(function()
        repaint()
        dim()
    end)
end

local function BuildPreviewOnRow(row)
    local f = BuildPreviewFrame(row)
    previewFrame = f
    RefreshPandemicPreview()
    local function grey()
        local alpha = PandemicOff() and 0.3 or 1
        f:SetAlpha(alpha)
        local first = row._rightRegion:GetRegions()
        if first and first.SetAlpha then first:SetAlpha(alpha) end
    end
    grey()
    ns.OptionsPreview.RegisterWidgetRefresh(grey)
end

local function BuildPandemicControls(row)
    local swatch, repaint = InlineSwatch(row, function()
        local c = SavedT("pandemicGlowColor")
        return c.r, c.g, c.b
    end, StoreColor("pandemicGlowColor", function()
        RefreshAuras()
        RefreshPandemicPreview()
    end))
    SetDimmed(swatch, PandemicOff())
    ns.OptionsPreview.RegisterWidgetRefresh(function()
        SetDimmed(swatch, PandemicOff())
        repaint()
    end)

    local cog = NewCog(row._leftRegion)
    cog:SetPoint("RIGHT", swatch, "LEFT", -9, 0)
    local function cogOff() return PandemicOff() or Saved("pandemicGlowStyle") ~= 1 end
    cog:SetAlpha(cogOff() and 0.15 or 0.4)
    WireCog(cog, cogOff, "This option requires Pixel Glow to be the selected glow type", BuildPixelPopup)
end

local function BuildGlowBlock(p)
    Header(p, "GLOWS")
    local row = Row(p, PandemicCell(), LabelCell(L("Pandemic Glow Preview")))
    BuildExpiryRows(p)
    BuildPreviewOnRow(row)
    BuildPandemicControls(row)
end

---------------------------------------------------------------------------------------------------
-- Dispel glow
---------------------------------------------------------------------------------------------------
local function DispelOff() return Saved("dispelGlow") ~= true end

local function BuildDispel(p)
    local values, order = GlowStyleChoices()
    local row = Row(p, Cell("dropdown", "Dispel Glow Style", function()
            if DispelOff() then return 0 end
            local style = ns.GetDispelGlowStyle and ns.GetDispelGlowStyle()
            if not style then style = Saved("dispelGlowStyle") or 2 end
            if type(style) ~= "number" then return 2 end
            return style
        end, function(v)
            local db = DB()
            if v == 0 then
                db.dispelGlow = false
            else
                db.dispelGlow = true
                db.dispelGlowStyle = v
            end
            RefreshAuras()
            C_Timer.After(0, RefreshPageNow)
        end, {
            values = values, order = order,
            tooltip = "Highlights enemy buffs that your class can offensively dispel or soothe.",
        }),
        Cell("toggle", "Use Dispel Type Color", ReadIsTrue("dispelGlowUseTypeColor"), function(v)
            DB().dispelGlowUseTypeColor = v
            RefreshAuras()
            RefreshPageNow()
        end, {
            disabled = DispelOff,
            tooltip = "Uses the native Magic/Enrage color instead of the custom color.",
        }))

    local function swatchOff() return DispelOff() or Saved("dispelGlowUseTypeColor") == true end
    local get, set = ns.OptionsPreview.GlowColorPair("dispelGlowColor")
    local swatch, repaint = InlineSwatch(row, get, set)
    SetDimmed(swatch, swatchOff())
    ns.OptionsPreview.RegisterWidgetRefresh(function()
        SetDimmed(swatch, swatchOff())
        repaint()
    end)
end

---------------------------------------------------------------------------------------------------
-- Health markers
---------------------------------------------------------------------------------------------------
local function MarkerCfg() return ns.OptionsPreview.MarkerCfg() end
local function MarkerState() return ns.OptionsPreview.MarkerState() end

local function MarkersOff()
    local cfg = MarkerCfg()
    return not cfg or cfg.enabled ~= true
end

-- Plates first, then the panel's preview.
local function MarkerRefresh()
    RefreshPlates()
    PanelPreview()
end

-- Applies a change to the config when there is one, rebuilds its values, then refreshes.
local function WithCfg(apply)
    local cfg = MarkerCfg()
    if cfg then
        apply(cfg)
        ns.OptionsPreview.RebuildMarkerValues(cfg)
    end
    MarkerRefresh()
end

local function MarkerSlotCell(i)
    return Cell("slider", string.format(L("Marker %d"), i), function()
        return ns.OptionsPreview.MarkerSlot(MarkerCfg(), i)
    end, function(v)
        local cfg = MarkerCfg()
        if cfg then ns.OptionsPreview.SetMarkerSlot(cfg, i, v) end
        MarkerRefresh()
    end, {
        min = 0, max = 100, step = 1,
        tooltip = string.format(L("Health percent threshold for marker #%d. Set to 0 to clear."), i),
        disabled = MarkersOff,
        disabledTooltip = "Enable Custom Health Markers",
    })
end

local function BuildMarkerRows(p)
    Row(p, Cell("toggle", "Enable Custom Health Markers", function()
            return not MarkersOff()
        end, function(v)
            WithCfg(function(cfg) cfg.enabled = v end)
            RefreshPageNow()
        end, { tooltip = "Shows up to 3 vertical markers on the health bar at configured health percentages." }),
        Cell("toggle", "Show on All Nameplates", function()
            return MarkerState().showOn == "all"
        end, function(v)
            MarkerState().showOn = v and "all" or "target"
            MarkerRefresh()
        end, { tooltip = "When disabled, markers only display on your current target." }))
    Row(p, Cell("toggle", "Per-Spec Marker Profile", function()
            return (MarkerState().mode or "spec") == "spec"
        end, function(v)
            MarkerState().mode = v and "spec" or "character"
            MarkerRefresh()
            RefreshPageNow()
        end, { tooltip = "When enabled, markers can be configured separately per specialization." }),
        Cell("slider", "Marker Width", function()
            local cfg = MarkerCfg()
            return cfg and cfg.width or 2
        end, function(v)
            WithCfg(function(cfg) cfg.width = v end)
        end, {
            min = 1, max = 6, step = 1,
            disabled = MarkersOff,
            disabledTooltip = "Enable Custom Health Markers",
        }))
    Row(p, MarkerSlotCell(1), MarkerSlotCell(2))
    return Row(p, MarkerSlotCell(3), LabelCell(L("Markers use % health (0 = off).")))
end

local function BuildMarkerSwatch(lastRow)
    local swatch, repaint = InlineSwatch(lastRow, function()
        local cfg = MarkerCfg()
        if not cfg then return 1, 1, 1 end
        return cfg.colorR or 1, cfg.colorG or 1, cfg.colorB or 1
    end, function(r, g, b)
        if not MarkerCfg() then return end
        WithCfg(function(cfg)
            cfg.colorR, cfg.colorG, cfg.colorB = r, g, b
        end)
    end)
    ns.OptionsPreview.DimSwatch(swatch, MarkersOff())
    ns.OptionsPreview.RegisterWidgetRefresh(function()
        ns.OptionsPreview.DimSwatch(swatch, MarkersOff())
        repaint()
    end)
end

---------------------------------------------------------------------------------------------------
-- Focus cast height
---------------------------------------------------------------------------------------------------
local function BuildFocus(p)
    local row = Row(p, Cell("slider", "Focus Cast Height", ReadOrDefault("focusCastHeight"), function(v)
        DB().focusCastHeight = v
        ns.RefreshAllSettings()
    end, {
        min = 100, max = 200, step = 5, trackWidth = 110,
        tooltip = "Increases the cast bar height on your focus target's nameplate. 100% = normal height.",
    }), Cell("slider", "Scale Nameplate On Cast", ReadOrDefault("castScale"), Store("castScale"), {
        min = 50, max = 200, step = 5, trackWidth = 110,
        tooltip = "Scales enemy nameplates while they are casting. 100% = no change.",
    }))

    local region = row._leftRegion
    if not region then return end
    -- Look for the label before adding the suffix to the same region.
    local labelFS
    for _, r in ipairs({ region:GetRegions() }) do
        if r.GetText and r:GetText() == "Focus Cast Height" then
            labelFS = r
            break
        end
    end
    local suffix = region:CreateFontString(nil, "OVERLAY")
    suffix:SetFont(KT.FONT_PATH, 11, ns.OptionsPreview.OptOutline())
    suffix:SetTextColor(1, 1, 1, 0.35)
    suffix:SetText(L("(Percent)"))
    if labelFS then
        suffix:SetPoint("LEFT", labelFS, "RIGHT", 5, -1)
    else
        suffix:SetPoint("LEFT", region, "LEFT", 180, -1)
    end
end

---------------------------------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------------------------------
local function Setup(client, panelTable)
    if client ~= "retail" and client ~= "forever" then
        error("OptionsGeneral.Setup: client must be \"retail\" or \"forever\"", 2)
    end
    if type(panelTable) ~= "table" or type(panelTable.UpdatePreview) ~= "function" then
        error("OptionsGeneral.Setup: panel needs a function UpdatePreview", 2)
    end
    clientName, panel = client, panelTable
    defaults = ns.defaults or _G.KullThranUINameplatesDefaults or {}
end

local function Build(parent, yOffset, want)
    local p = { W = ns.OptionsPreview.RowWidgets(KT.Widgets), VT = KT.VisualThemes, parent = parent, y = yOffset }
    parent._showRowDivider = true
    RollPreviewIcon()

    if want.general then
        Header(p, "GENERAL")
        Step(p, p.W:Toggle(parent, "Enable Module", p.y, ReadNotFalse("enable"), function(v)
            DB().enable = v and true or false
            StaticPopup_Show("KULLTHRANUI_RELOAD")
        end))
        Header(p, "STYLE PRESETS")
        BuildStyleCards(p)
    end
    if want.font then
        BuildTextStyle(p)
        Spacer(p, 14)
    end
    if want.shownAuras then
        BuildShownAuras(p)
        Spacer(p, 14)
    end
    if want.glows then
        BuildGlowBlock(p)
        BuildDispel(p)
        Spacer(p, 14)
    end
    if want.focusCast then
        BuildFocus(p)
        Spacer(p, 14)
    end
    if want.dot then
        BuildDotDamage(p)
        Spacer(p, 14)
    end
    if want.distance then
        BuildDistance(p)
        Spacer(p, 14)
    end
    if want.friendlyColors then
        BuildDefaultNames(p)
        BuildFriendlyColors(p)
        Spacer(p, 14)
    end
    if want.classIcons then
        BuildClassIcons(p)
        Spacer(p, 14)
    end
    if want.stacking then
        BuildStacking(p)
        Spacer(p, 14)
    end
    if want.pets then BuildEnemyPets(p) end
    return math.abs(p.y)
end

ns.OptionsGeneral = { Setup = Setup, Build = Build }
