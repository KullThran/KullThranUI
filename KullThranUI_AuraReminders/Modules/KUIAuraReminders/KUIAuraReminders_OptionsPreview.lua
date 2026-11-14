-- Aura Reminders options: the icon strip of the Control Center page, its navigation, and the settings readers.
-- The client comes only through Setup's ctx. Retail adds the saved icon order and dragging icons.

local _, ns = ...
local KT = ns.KT or (LibStub and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))
if not KT then return end

local abs, ceil, floor, max, min = math.abs, math.ceil, math.floor, math.max, math.min

local STRIP_HEIGHT = 80
local STRIP_PAD = 16
local STRIP_SIDE_PAD = 16
local HINT_ROOM = 60
local HINT_BOTTOM, HINT_GAP = 15, 4
local HINT_ALPHA = 0.45
local FALLBACK_ICON = 134400
-- Forever has no Midnight items: its preview shows classic art (Dense Sharpening Stone,
-- Flask of the Titans), files both clients ship.
local FOREVER_WEAPON_ICON = "Interface\\Icons\\INV_Stone_SharpeningStone_05"
local FOREVER_FLASK_ICON = "Interface\\Icons\\INV_Potion_62"
local CROP_LOW, CROP_HIGH = 0.07, 0.93
local FLASH_SECONDS = 0.75
local FADE_INTERVAL = 0.016
local FADE_SECONDS = 0.3
local DRAG_THRESHOLD_SQ = 25

-- Read-only stand-in when the profile has no display section: every "d.x or N" falls to N.
local NO_DISPLAY = {}

local S             -- ctx.Widgets
local isRetail      -- ctx.client == "retail"

-- Session state. An icon record is { frame, art, caption, host, entry, slot }.
local icons = {}
local currentStrip, hintText, flashFrame, ghostFrame, ghostTexture, drag
local headerBuilt = false
local baseHeight = STRIP_HEIGHT
local stripNow = 0

local ClickMappings = {}
local PetIcons = { WARLOCK = 136218, HUNTER = 132161 }

-----------------------------------------------------------------------------------------------------------------------
-- Settings readers
-----------------------------------------------------------------------------------------------------------------------

local function DB()
    local aceDB = _G._KUIAR_AceDB
    return aceDB and aceDB.profile
end

local function DDB() local p = DB(); return p and p.display end
local function RDB() local p = DB(); return p and p.raidBuffs end
local function ADB() local p = DB(); return p and p.auras end
local function CDB() local p = DB(); return p and p.consumables end

local function RefreshAll()
    local fn = _G._KUIAR_RequestRefresh
    if fn then fn() end
    local changed = S and S.OnSettingChanged
    if changed then changed() end
end

local function IsOn(section, key)
    local enabled = section and section.enabled
    return enabled and enabled[key]
end

local function NoSnap(tex)
    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end

-- Spell icon: runtime first, then the client, then a question mark.
local function Tex(spellID)
    local runtime = _G._KUIAR_Tex
    local tex = runtime and runtime(spellID)
    if tex then return tex end
    tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    return tex or FALLBACK_ICON
end

local function Outline()
    local fn = KT.GetFontOutlineFlag
    return fn and fn() or "OUTLINE"
end

-- True only when the profile says exactly true.
local function HintDismissed()
    local profile = DB()
    return profile ~= nil and profile.previewHintDismissed == true
end

-----------------------------------------------------------------------------------------------------------------------
-- Collecting icons
-----------------------------------------------------------------------------------------------------------------------

local function Known(id)
    return id and (IsPlayerSpell(id) or IsSpellKnown(id))
end

-- Spell names whose caption word is localised through a variable.
local NAME_WORDS = {
    ["Battle Shout"] = "Shout",
    ["Defensive Stance"] = "Stance",
    ["Berserker Stance"] = "Stance",
    ["Power Word: Fortitude"] = "Fortitude",
}

-- Caption by family, by hand-picked name, or the first word of the spell's name.
local function CaptionFor(entry, family)
    if family == "ROGUE" then return S.LText("Poison") end
    if family == "SHAMAN_IMBUE" then return S.LText("Weapon") end

    local name = entry.name
    local nameWord = NAME_WORDS[name]
    if nameWord then return S.LText(nameWord) end
    if name == "Arcane Intellect" then return S.LText("Intellect") end
    if name == "Devotion Aura" then return S.LText("Aura") end

    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(entry.castSpell)
    local word = ((info and info.name) or name or ""):match("%S+")
    return word and S.LText(word)
end

local function SpellIcon(entry, category, family)
    return {
        texture = Tex(entry.castSpell),
        caption = CaptionFor(entry, family),
        category = category,
        itemKey = entry.key,
    }
end

local function InSpecs(specs, specID)
    if not specs then return true end
    for _, id in ipairs(specs) do
        if id == specID then return true end
    end
    return false
end

local function CollectRaidBuffs(out, class)
    for _, entry in ipairs(_G._KUIAR_RAID_BUFFS or {}) do
        if entry.class == class and Known(entry.castSpell) and IsOn(RDB(), entry.key) then
            out[#out + 1] = SpellIcon(entry, "raidbuff")
        end
    end
end

-- Auras of the class and spec; the two beacons share one slot.
local function CollectAuras(out, class, specID)
    local beaconTaken = false
    for _, entry in ipairs(_G._KUIAR_AURAS or {}) do
        local isBeacon = entry.key == "bol" or entry.key == "bof"
        if not (isBeacon and beaconTaken)
            and entry.class == class and Known(entry.castSpell)
            and IsOn(ADB(), entry.key) and InSpecs(entry.specs, specID) then
            out[#out + 1] = SpellIcon(entry, "aura")
            if isBeacon then beaconTaken = true end
        end
    end
end

-- The class's preparation list and caption family; false for classes without one.
local function ClassKit(class)
    if class == "ROGUE" then return _G._KUIAR_ROGUE_POISONS or {}, "ROGUE" end
    if class == "PALADIN" then return _G._KUIAR_PALADIN_RITES or {}, nil end
    if class == "SHAMAN" then return _G._KUIAR_SHAMAN_IMBUES or {}, "SHAMAN_IMBUE" end
    return false
end

local function FixedIcon(texture, caption, key)
    return { texture = texture, caption = caption, category = "consumable", itemKey = key }
end

local function CollectConsumables(out, class)
    local cdb = CDB()
    local kit, family = ClassKit(class)
    if kit then
        for _, entry in ipairs(kit) do
            if IsOn(cdb, entry.key) and Known(entry.castSpell) then
                out[#out + 1] = SpellIcon(entry, "consumable", family)
                break
            end
        end
    elseif IsOn(cdb, "weapon_enchant") then
        local icon = isRetail and (C_Item.GetItemIconByID(243733) or 7548987) or FOREVER_WEAPON_ICON
        out[#out + 1] = FixedIcon(icon, S.LText("Weapon"), "weapon_enchant")
    end

    if IsOn(cdb, "flask") then
        local icon = isRetail and (C_Item.GetItemIconByID(241326) or 463530) or FOREVER_FLASK_ICON
        out[#out + 1] = FixedIcon(icon, S.LText("Flask"), "flask")
    end
    if IsOn(cdb, "food") then
        out[#out + 1] = FixedIcon(136000, S.LText("Food"), "food")
    end
    if isRetail and IsOn(cdb, "augment_rune") then
        out[#out + 1] = FixedIcon(C_Item.GetItemIconByID(259085) or FALLBACK_ICON, S.LText("Rune"), "augment_rune")
    end
    if IsOn(cdb, "pet") and PetIcons[class] then
        out[#out + 1] = FixedIcon(PetIcons[class], S.LText("Pet"), "pet")
    end
end

-- Key of an icon in the saved order.
local function OrderKey(entry)
    if entry.itemKey then return entry.category .. ":" .. entry.itemKey end
    return entry.category
end

-- Retail: ranked icons first by saved rank, the rest in collected order. Reads only.
local function ApplySavedOrder(entries)
    local d = DDB()
    local saved = d and d.iconOrder
    if #entries < 2 or type(saved) ~= "table" then return entries end

    local ranks = {}
    for position, key in ipairs(saved) do
        if type(key) == "string" and not ranks[key] then ranks[key] = position end
    end

    local keyed = {}
    for i, entry in ipairs(entries) do
        keyed[i] = { entry = entry, rank = ranks[OrderKey(entry)] or math.huge, index = i }
    end
    table.sort(keyed, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.index < b.index
    end)

    local sorted = {}
    for i, item in ipairs(keyed) do sorted[i] = item.entry end
    return sorted
end

local function CollectIcons()
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and (GetSpecializationInfo(specIndex))

    local out = {}
    CollectRaidBuffs(out, class)
    CollectAuras(out, class, specID)
    CollectConsumables(out, class)
    if isRetail then out = ApplySavedOrder(out) end
    return out
end

-----------------------------------------------------------------------------------------------------------------------
-- Geometry, captions, glow
-----------------------------------------------------------------------------------------------------------------------

local function IconSize(d)
    return floor((_G._KUIAR_ICON_SIZE or 40) * (d.scale or 1.0) + 0.5)
end

local function StripRowHeight(d, size)
    if d.showText then
        return size + abs(d.textYOffset or -2) + (d.textSize or 11)
    end
    return size
end

-- Icons that fit one line of the strip; the rest wrap to the next.
local function IconsPerLine(n, size, gap)
    local room = currentStrip:GetWidth() - STRIP_SIDE_PAD
    return max(1, min(n, floor((room + gap) / (size + gap))))
end

-- Height of the whole strip for n icons.
local function StripHeight(d, size, gap, n)
    local lines = ceil(max(1, n) / IconsPerLine(max(1, n), size, gap))
    return lines * StripRowHeight(d, size) + (lines - 1) * gap
end

-- Places one icon in its slot, each line centred on the strip's top.
local function PlaceIcon(rec, i, n, size, gap, d)
    local perLine = IconsPerLine(n, size, gap)
    local line = floor((i - 1) / perLine)
    local column = i - 1 - line * perLine
    local inLine = min(perLine, n - line * perLine)
    local lineWidth = inLine * size + (inLine - 1) * gap
    rec.frame:ClearAllPoints()
    rec.frame:SetPoint("TOP", currentStrip, "TOP", column * (size + gap) + size / 2 - lineWidth / 2,
        -line * (StripRowHeight(d, size) + gap))
end

-- Font first, then everything else. The text is set once, when the icon is made.
local function StyleCaption(rec, d)
    local caption = rec.caption
    local pathFn = KT.GetFontPath
    local path = pathFn and pathFn("auraReminders") or "Fonts\\ARIALN.TTF"
    local flags = Outline()
    caption:SetFont(path, d.textSize or 11, flags)
    if flags == "" then
        caption:SetShadowOffset(1, -1)
        caption:SetShadowColor(0, 0, 0, 1)
    else
        caption:SetShadowOffset(0, 0)
    end
    caption:ClearAllPoints()
    caption:SetPoint("TOP", rec.frame, "BOTTOM", d.textXOffset or 0, d.textYOffset or -2)
    local color = d.textColor
    if color then
        caption:SetTextColor(color.r, color.g, color.b, 1)
    else
        caption:SetTextColor(1, 1, 1, 1)
    end
end

local function ShowCaption(rec, d)
    if d.showText then rec.caption:Show() else rec.caption:Hide() end
end

-- Calls the first starter the style asks for and the client has, with the flip book as the last resort.
local function StartGlow(host, size, style, r, g, b)
    local pixel = _G._KUIAR_StartPixelGlow
    local button = _G._KUIAR_StartButtonGlow
    local autocast = _G._KUIAR_StartAutoCastShine
    if style.procedural and pixel then
        pixel(host, size, r, g, b)
    elseif style.buttonGlow and button then
        button(host, size, r, g, b, 1.36)
    elseif style.autocast and autocast then
        autocast(host, size, r, g, b, 1.0)
    else
        local flipBook = _G._KUIAR_StartFlipBookGlow
        if flipBook then flipBook(host, size, style, r, g, b) end
    end
end

-- Makes the glow host once, stops any glow, and starts the one the settings ask for.
local function RestyleGlow(rec, size, d)
    local host = rec.host
    if not host then
        host = CreateFrame("Frame", nil, rec.frame)
        host:SetAllPoints(rec.frame)
        host:SetFrameLevel(rec.frame:GetFrameLevel() + 1)
        rec.host = host
    end

    local stop = _G._KUIAR_StopAllGlows
    if stop then stop(host) end

    local glowType = d.glowType or 0
    local styles = _G._KUIAR_GLOW_TYPES
    if glowType <= 0 or not styles then
        host:Hide()
        return
    end

    local style = styles[glowType]
    if not style then return end

    local color = d.glowColor
    local r, g, b = 1, 0.776, 0.376
    if color then r, g, b = color.r, color.g, color.b end
    StartGlow(host, size, style, r, g, b)
    host:Show()
end

-----------------------------------------------------------------------------------------------------------------------
-- Restyle and relayout
-----------------------------------------------------------------------------------------------------------------------

-- Height the hint adds. The strip is centred, so the room under it must hold the hint's lines as they really wrap.
local function HintRoom()
    local lines = hintText and hintText:GetStringHeight() or 0
    return max(HINT_ROOM, stripNow + 2 * (HINT_BOTTOM + lines + HINT_GAP) - baseHeight)
end

-- Applies saved values to the existing icons; the header height changes silently.
local function UpdateHeader()
    local d = DDB()
    local n = #icons
    if n == 0 or not d then return end

    local size = IconSize(d)
    local gap = d.iconSpacing or 8
    for i, rec in ipairs(icons) do
        rec.frame:SetSize(size, size)
        rec.frame:SetAlpha(d.opacity or 1.0)
        PlaceIcon(rec, i, n, size, gap, d)
        RestyleGlow(rec, size, d)
        if d.showText then StyleCaption(rec, d) end
        ShowCaption(rec, d)
        rec.frame:Show()
    end

    local stripHeight = StripHeight(d, size, gap, n)
    currentStrip:SetHeight(stripHeight)
    currentStrip:ClearAllPoints()
    currentStrip:SetPoint("CENTER", currentStrip:GetParent(), "CENTER", 0, 0)

    stripNow = stripHeight
    baseHeight = max(STRIP_HEIGHT, stripHeight + STRIP_PAD)
    local height = baseHeight
    if hintText and hintText:IsShown() then height = height + HintRoom() end
    KT:SetContentHeaderHeightSilent(height)
end

-- Only moves the icons to their slots.
local function RelayoutIcons()
    local n = #icons
    if n == 0 then return end
    local d = DDB() or NO_DISPLAY
    local size = IconSize(d)
    local gap = d.iconSpacing or 8
    for i, rec in ipairs(icons) do PlaceIcon(rec, i, n, size, gap, d) end
end

-----------------------------------------------------------------------------------------------------------------------
-- Navigation
-----------------------------------------------------------------------------------------------------------------------

-- Border over the setting, fading out on its own script for 0.75 s. The colour is taken once.
local function FlashTarget(target)
    if not flashFrame then
        local accent = KT.KUI_ACCENT
        flashFrame = CreateFrame("Frame")
        KT:AddBorder(flashFrame, accent.r, accent.g, accent.b, 1, 2)
    end
    flashFrame:SetParent(target)
    flashFrame:SetAllPoints(target)
    flashFrame:SetFrameLevel(target:GetFrameLevel() + 5)
    flashFrame:SetAlpha(1)
    flashFrame:Show()

    local clock = 0
    flashFrame:SetScript("OnUpdate", function(self, dt)
        clock = clock + dt
        if clock >= FLASH_SECONDS then
            self:Hide()
            self:SetScript("OnUpdate", nil)
        else
            self:SetAlpha(1 - clock / FLASH_SECONDS)
        end
    end)
end

-- Saves the dismissal at once, then fades the hint on one self-cancelling ticker.
local function DismissHint()
    local hint = hintText
    if HintDismissed() or not hint or not hint:IsShown() then return end

    local profile = DB()
    if profile then profile.previewHintDismissed = true end

    local _, relative, _, _, startY = hint:GetPoint(1)
    relative = relative or hint:GetParent()
    startY = startY or 5

    local room = HintRoom()
    local steps = 0
    local ticker
    ticker = C_Timer.NewTicker(FADE_INTERVAL, function()
        steps = steps + 1
        local p = steps * FADE_INTERVAL / FADE_SECONDS
        if p < 1 then
            hint:SetAlpha(HINT_ALPHA * (1 - p))
            hint:ClearAllPoints()
            hint:SetPoint("BOTTOM", relative, "BOTTOM", 0, startY + p * 12)
            local height = baseHeight + room - room * p
            if height > 0 then KT:SetContentHeaderHeightSilent(height) end
        else
            hint:Hide()
            ticker:Cancel()
            KT:SetContentHeaderHeightSilent(baseHeight)
        end
    end)
end

local function HasKey(list, key)
    for _, entry in ipairs(list or {}) do
        if entry.key == key then return true end
    end
    return false
end

-- Page holding a key that has no mapping yet, or nil when the key has none.
local function DestinationOf(key)
    if key == "display" or key == "showText" then return S.Pages.CONTROL end
    if key == "raidbuff" or key == "aura" then return S.Pages.GROUP end
    if key == "consumable" then return S.Pages.CONSUMABLES end
    if type(key) ~= "string" then return nil end

    local item = key:match("^item:(.*)$")
    if not item then return nil end
    if HasKey(_G._KUIAR_RAID_BUFFS, item) or HasKey(_G._KUIAR_AURAS, item) then
        return S.Pages.GROUP
    end
    if HasKey(_G._KUIAR_ROGUE_POISONS, item) or HasKey(_G._KUIAR_PALADIN_RITES, item)
        or HasKey(_G._KUIAR_SHAMAN_IMBUES, item) or HasKey(_G._KUIAR_SHAMAN_SHIELDS, item) then
        return S.Pages.CLASS
    end
    return S.Pages.CONSUMABLES
end

-- Scrolls to the section, measured now. Without measurements there is no scroll.
local function ScrollToSection(scrollFrame, section)
    local child = scrollFrame.GetScrollChild and scrollFrame:GetScrollChild()
    local childTop = child and child.GetTop and child:GetTop()
    local sectionTop = section.GetTop and section:GetTop()
    if childTop and sectionTop then
        KT.SmoothScrollTo(max(0, childTop - sectionTop - 40))
    end
end

-- Jumps to a setting. A key with no mapping changes page first and retries once the page is built.
local function NavigateToSetting(key)
    local mapping = ClickMappings[key]
    if not (mapping and mapping.section and mapping.target) then
        local destination = DestinationOf(key)
        if destination and destination ~= S.GetSelectedPage() then
            S.SetSelectedPage(destination)
            KT:RefreshPage()
            C_Timer.After(0.1, function() NavigateToSetting(key) end)
        end
        return
    end

    DismissHint()
    local scrollFrame = KT._scrollFrame
    if not scrollFrame then return end
    ScrollToSection(scrollFrame, mapping.section)
    C_Timer.After(0.15, function() FlashTarget(mapping.target) end)
end

-----------------------------------------------------------------------------------------------------------------------
-- Retail: drag to swap
-----------------------------------------------------------------------------------------------------------------------

-- Ends a press or drag: restores alphas, stops the watchers, restyles.
local function ClearDrag()
    local state = drag
    state.overlay:SetAlpha(1)
    if state.target then state.target.frame:SetAlpha(1) end
    if ghostFrame then ghostFrame:Hide() end
    state.strip:SetScript("OnUpdate", nil)
    drag = nil
    UpdateHeader()
end

-- Saves the keys in slot order, then the old string keys not seen. Always a new table.
local function SaveIconOrder()
    local d = DDB()
    if not d then return end
    local seen, order = {}, {}
    local function add(key)
        if not seen[key] then
            seen[key] = true
            order[#order + 1] = key
        end
    end
    for _, rec in ipairs(icons) do add(OrderKey(rec.entry)) end
    if type(d.iconOrder) == "table" then
        for _, key in ipairs(d.iconOrder) do
            if type(key) == "string" then add(key) end
        end
    end
    d.iconOrder = order
end

-- A drop on another icon swaps the two slot positions of the current list; a drop on itself only clears,
-- and so does a drop whose icons a rebuild replaced: their old slots could leave a hole in the list.
local function FinishDrag()
    local state = drag
    local source, target = state.source, state.target
    if target and target ~= source and icons[source.slot] == source and icons[target.slot] == target then
        local a, b = source.slot, target.slot
        icons[a], icons[b] = icons[b], icons[a]
        SaveIconOrder()
        for i, rec in ipairs(icons) do rec.slot = i end
        RelayoutIcons()
        RefreshAll()
    end
    ClearDrag()
end

-- The icon under the point, otherwise the nearest measured one.
local function FindDropTarget(x, y)
    local nearest, nearestDist
    for _, rec in ipairs(icons) do
        local f = rec.frame
        local left, right, bottom, top = f:GetLeft(), f:GetRight(), f:GetBottom(), f:GetTop()
        if left and right and bottom and top then
            if x >= left and x <= right and y >= bottom and y <= top then return rec end
            local dx, dy = x - (left + right) / 2, y - (bottom + top) / 2
            local dist = dx * dx + dy * dy
            if not nearestDist or dist < nearestDist then
                nearest, nearestDist = rec, dist
            end
        end
    end
    return nearest
end

-- Strip script while dragging: ghost follows the cursor, the target is marked.
local function DragFrame()
    local state = drag
    if not state then return end
    if not IsMouseButtonDown("LeftButton") then
        FinishDrag()
        return
    end

    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local x, y = cx / scale, cy / scale
    ghostFrame:ClearAllPoints()
    ghostFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

    local target = FindDropTarget(x, y)
    if target and target ~= state.target then
        if state.target and state.target ~= state.source then state.target.frame:SetAlpha(1) end
        if target ~= state.source then target.frame:SetAlpha(0.65) end
        state.target = target
    end
end

-- Makes the ghost once and gives it the source icon's look.
local function ShowGhost(source)
    if not ghostFrame then
        ghostFrame = CreateFrame("Frame", nil, UIParent)
        ghostFrame:SetFrameStrata("TOOLTIP")
        ghostFrame:SetAlpha(0.75)
        ghostTexture = ghostFrame:CreateTexture(nil, "ARTWORK")
        ghostTexture:SetAllPoints()
        ghostFrame:Hide()
    end
    ghostFrame:SetSize(source.frame:GetWidth() or 40, source.frame:GetHeight() or 40)
    ghostTexture:SetTexture(source.art:GetTexture() or FALLBACK_ICON)
    ghostTexture:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    ghostFrame:Show()
end

local function IconOverlayKey(rec)
    return "item:" .. rec.entry.itemKey
end

-- A release before the threshold is a click.
local function ReleasePress()
    local state = drag
    state.overlay:SetScript("OnUpdate", nil)
    NavigateToSetting(IconOverlayKey(state.source))
    ClearDrag()
end

-- Past the threshold the press becomes a drag and the strip takes over.
local function BeginDrag(overlay)
    local state = drag
    overlay:SetScript("OnUpdate", nil)
    overlay:SetAlpha(0.3)
    ShowGhost(state.source)
    GameTooltip:Hide()
    state.dragging = true
    state.strip:SetScript("OnUpdate", DragFrame)
end

-- Overlay script between press and threshold or release.
local function PressWatcher(overlay)
    if not IsMouseButtonDown("LeftButton") then
        ReleasePress()
        return
    end
    local cx, cy = GetCursorPosition()
    local dx, dy = cx - drag.startX, cy - drag.startY
    if dx * dx + dy * dy >= DRAG_THRESHOLD_SQ then BeginDrag(overlay) end
end

local function StartPress(overlay, rec)
    local cx, cy = GetCursorPosition()
    drag = {
        overlay = overlay, strip = currentStrip, source = rec, target = rec,
        startX = cx, startY = cy, dragging = false,
    }
    overlay:SetScript("OnUpdate", PressWatcher)
end

-- Retail press and release handlers of one overlay. rec is nil on a caption overlay.
local function BindRetailPress(overlay, key, rec)
    overlay:SetScript("OnMouseDown", function(self, button)
        if rec and button == "LeftButton" then
            if not drag then StartPress(self, rec) end
        else
            NavigateToSetting(key)
        end
    end)
    -- A left release on any icon overlay ends a drag or press-watch, so a stale one cannot stay stuck.
    overlay:SetScript("OnMouseUp", function(_, button)
        if not rec or button ~= "LeftButton" or not drag then return end
        if drag.dragging then FinishDrag() else ReleasePress() end
    end)
end

-----------------------------------------------------------------------------------------------------------------------
-- Header builder
-----------------------------------------------------------------------------------------------------------------------

-- Hit area over an icon or its caption, with a hover border in the accent colour.
local function AddOverlay(rec, cover, level, key, iconRec)
    local overlay = CreateFrame("Button", nil, rec.frame)
    overlay:SetAllPoints(cover)
    overlay:SetFrameLevel(level)
    overlay:RegisterForClicks("LeftButtonDown")

    local accent = KT.KUI_ACCENT
    local border = KT.PP.CreateBorder(overlay, accent.r, accent.g, accent.b, 1, 2, "OVERLAY", 7)
    border:Hide()
    overlay:SetScript("OnEnter", function() border:Show() end)
    overlay:SetScript("OnLeave", function() border:Hide() end)

    if isRetail then
        BindRetailPress(overlay, key, iconRec)
    else
        overlay:SetScript("OnMouseDown", function() NavigateToSetting(key) end)
    end
end

-- One icon of the strip, with its art, border and caption.
local function NewIcon(strip, entry, i, n, size, gap, d)
    local frame = CreateFrame("Button", nil, strip)
    frame:SetSize(size, size)
    frame:EnableMouse(true)

    local rec = { frame = frame, entry = entry, slot = i }
    PlaceIcon(rec, i, n, size, gap, d)
    frame:SetAlpha(d.opacity or 1.0)

    local art = frame:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    art:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    art:SetTexture(entry.texture or FALLBACK_ICON)
    NoSnap(art)
    rec.art = art

    KT:AddBorder(frame, 0, 0, 0, 1)

    rec.caption = frame:CreateFontString(nil, "OVERLAY")
    StyleCaption(rec, d)
    rec.caption:SetText(entry.caption or "")
    ShowCaption(rec, d)
    return rec
end

-- The hint line, reused across builds. Returns the header height.
local function PlaceHint(hdr, strip)
    if hintText and not hintText:GetParent() then hintText = nil end

    if HintDismissed() then
        if hintText then hintText:Hide() end
        return baseHeight
    end

    if not hintText then
        hintText = KT.MakeFont(strip, 11, nil, 1, 1, 1)
        hintText:SetAlpha(HINT_ALPHA)
        if isRetail then
            hintText:SetText(S.LText("Drag icons to change their order • Click an icon to open its settings"))
        else
            hintText:SetText(S.LText("Click an icon to open its settings"))
        end
    end
    hintText:SetParent(strip)
    hintText:SetWidth(strip:GetWidth() - STRIP_SIDE_PAD)
    hintText:ClearAllPoints()
    hintText:SetPoint("BOTTOM", hdr, "BOTTOM", 0, HINT_BOTTOM)
    hintText:Show()
    return baseHeight + HintRoom()
end

-- Builds the strip in the required order and returns the header height.
local function HeaderBuilder(hdr, width)
    local entries = CollectIcons()
    local d = DDB() or NO_DISPLAY
    local size = IconSize(d)
    local gap = d.iconSpacing or 8

    local strip = CreateFrame("Frame", nil, hdr)
    strip:SetSize(width, StripRowHeight(d, size))
    strip:SetPoint("CENTER", hdr, "CENTER", 0, 0)
    currentStrip = strip

    icons = {}
    for i, entry in ipairs(entries) do
        icons[i] = NewIcon(strip, entry, i, #entries, size, gap, d)
    end

    UpdateHeader()

    local level = strip:GetFrameLevel() + 20
    local captionsOn = d.showText
    for _, rec in ipairs(icons) do
        AddOverlay(rec, rec.frame, level, IconOverlayKey(rec), rec)
        if captionsOn then AddOverlay(rec, rec.caption, level, "showText") end
    end

    headerBuilt = true
    if #icons == 0 then baseHeight, stripNow = STRIP_HEIGHT, 0 end
    return PlaceHint(hdr, strip)
end

local function RebuildHeader()
    KT:SetContentHeader(HeaderBuilder)
end

-- Re-syncs the look, hint and height after a cached page comes back. Never rebuilds.
local function RestoreControlPreview()
    UpdateHeader()
    local dismissed = HintDismissed()
    if hintText then
        if dismissed then
            hintText:Hide()
        else
            hintText:Show()
            hintText:SetAlpha(HINT_ALPHA)
        end
    end
    if headerBuilt then
        KT:SetContentHeaderHeightSilent(dismissed and baseHeight or baseHeight + HintRoom())
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Interface
-----------------------------------------------------------------------------------------------------------------------

local Preview = {}
ns.AuraRemindersPreview = Preview

-- Takes the client and the shared widgets, then publishes the rest. Creates nothing.
function Preview.Setup(ctx)
    local client = ctx and ctx.client
    if client ~= "retail" and client ~= "forever" then
        error("AuraRemindersPreview.Setup: ctx.client must be \"retail\" or \"forever\"", 2)
    end
    isRetail = client == "retail"
    S = ctx.Widgets

    Preview.DB = DB
    Preview.DDB = DDB
    Preview.RDB = RDB
    Preview.ADB = ADB
    Preview.CDB = CDB
    Preview.RefreshAll = RefreshAll
    Preview.IsOn = IsOn
    Preview.NoSnap = NoSnap
    Preview.Tex = Tex
    Preview.Outline = Outline
    Preview.PetIcons = PetIcons
    Preview.HeaderBuilder = HeaderBuilder
    Preview.UpdateHeader = UpdateHeader
    Preview.RebuildHeader = RebuildHeader
    Preview.RelayoutIcons = RelayoutIcons
    Preview.ClickMappings = ClickMappings
    Preview.NavigateToSetting = NavigateToSetting
    Preview.RestoreControlPreview = RestoreControlPreview
end
