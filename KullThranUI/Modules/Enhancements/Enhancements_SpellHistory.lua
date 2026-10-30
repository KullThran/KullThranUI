-------------------------------------------------------------------------------
--  Spell History: the spells you press, in order, as a row of icons.
--
--  Each spell you cast enters at the front of the row and pushes the earlier
--  ones along; they fade after a few seconds (or stay, if fading is off) and
--  slide out past the last slot. While a cast is in progress its icon waits
--  at the front; a cast you stop gets a red cross, removed again if the cast
--  went through after all.
--
--  Your own casts only: the client keeps other units' cast data secret.
--  Spells whose ID comes back secret are skipped, never compared.
--
--  The row is moved in KUI Unlock Mode (sample icons show there). The options
--  page draws the same row in its live preview, fed with sample casts.
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then return end

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GetTime = _G.GetTime
local issecretvalue = _G.issecretvalue or function() return false end
local pairs, ipairs, type, tonumber, tostring, math = pairs, ipairs, type, tonumber, tostring, math

local SH = {}
Mod.SpellHistory = SH

local SLIDE_SPEED = 9        -- slots per second while catching up
local CANCEL_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local STALE_CAST = 10        -- a cast with no end event is dropped after this
local MAX_EXTRA = 3          -- icons kept past the last slot while sliding out

local function LText(text)
    if type(text) == "string" and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then return L[text] end
    end
    return text
end

local function Config()
    local db = Mod.GetDB and Mod:GetDB() or nil
    local cfg
    if db then
        db.spellHistory = db.spellHistory or {}
        cfg = db.spellHistory
    else
        cfg = {}
    end
    local defaults = {
        enable = false, direction = "LEFT", iconSize = 36, iconsNumber = 5, spacing = 3,
        fadeDelay = 4, fadeTime = 1.2, highlightNewest = true, newestScale = 1.15,
        showCancel = true, borderColor = "black", borderSize = 1,
        iconStyle = "KUI", iconShape = "NONE",
        showBackground = false, backgroundAlpha = 0.5, showWhen = "always",
        ignoreList = "",
    }
    for key, value in pairs(defaults) do
        if cfg[key] == nil then cfg[key] = value end
    end
    -- Dark borders by default (the accent is an option): the first versions
    -- stored the accent as the default.
    if (cfg.borderVersion or 0) < 2 then
        cfg.borderColor = "black"
        cfg.borderVersion = 2
    end
    return cfg
end
SH.Config = Config

-------------------------------------------------------------------------------
--  Spells that are not worth an icon: the second half of a two-hand strike,
--  periodic pulses and other helper spells the game casts next to the one you
--  pressed.
-------------------------------------------------------------------------------
local HELPER_SPELLS = {
    [27576] = true,  -- Mutilate, off-hand
    [32176] = true,  -- Stormstrike, off-hand
    [85384] = true,  -- Raging Blow, off-hand
    [115360] = true, -- Windstrike, off-hand
    [121474] = true, -- Shadow Blades, off-hand
    [114093] = true, -- Windlash, off-hand
    [52174] = true,  -- Heroic Leap, landing
    [84721] = true,  -- Frozen Orb, pulses
    [227255] = true, -- Spirit Bomb, pulses
    [225921] = true, -- Fracture, second hit
    [75] = true,     -- Auto Shot
    [6603] = true,   -- Auto Attack
}

-- The user's ignore list: spell IDs or names, comma separated.
local ignoreCache, ignoreSource
local function IsIgnored(spellID, name)
    if HELPER_SPELLS[spellID] then return true end
    local source = Config().ignoreList or ""
    if source ~= ignoreSource then
        ignoreSource, ignoreCache = source, {}
        for token in source:gmatch("[^,;]+") do
            token = token:match("^%s*(.-)%s*$")
            if token ~= "" then ignoreCache[tonumber(token) or token:lower()] = true end
        end
    end
    return ignoreCache[spellID] == true or (name and ignoreCache[name:lower()] == true) or false
end
SH.IsIgnored = IsIgnored

local function SpellData(spellID)
    local C_Spell = _G.C_Spell
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then return info.name, info.iconID, info.castTime or 0 end
        return nil
    end
    if _G.GetSpellInfo then
        local name, _, icon, castTime = _G.GetSpellInfo(spellID)
        return name, icon, castTime or 0
    end
    return nil
end

-------------------------------------------------------------------------------
--  Engine: the entries in the order they were pressed, newest first.
--  Each entry: { spellID, icon, name, time, casting, canceled, castGUID,
--  pos (current slot, animated), alpha }.
-------------------------------------------------------------------------------
local Engine = { entries = {}, current = nil, lastName = nil, lastID = nil, canceled = nil }
SH.Engine = Engine

local function AddEntry(list, spellID, icon, name, castGUID, now)
    local entry = { spellID = spellID, icon = icon, name = name, castGUID = castGUID,
        time = now or GetTime(), pos = -1, alpha = 1 }
    table.insert(list, 1, entry)
    return entry
end
SH.AddEntry = AddEntry

-- One spell event of yours. `api` lets the tests supply spell data and time.
function SH.OnSpellEvent(event, castGUID, spellID, api)
    api = api or {}
    local spellData = api.SpellData or SpellData
    local now = (api.GetTime or GetTime)()
    if spellID == nil or issecretvalue(spellID) or (castGUID ~= nil and issecretvalue(castGUID)) then return end
    local name, icon, castTime = spellData(spellID)
    if not (name and icon) or IsIgnored(spellID, name) then return end
    -- Same name, another ID right after: a helper spell of the one pressed.
    if Engine.lastName == name and Engine.lastID ~= spellID then return end

    local list = Engine.entries
    local function Add(casting)
        local entry = AddEntry(list, spellID, icon, name, castGUID, now)
        entry.casting = casting
        Engine.lastName, Engine.lastID = name, spellID
        return entry
    end

    if event == "UNIT_SPELLCAST_START" then
        if not castGUID then return end -- form shifts send a second, GUID-less start
        Engine.current = { spellID = spellID, castGUID = castGUID, name = name, time = now, entry = Add(true) }
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
        Engine.current = { spellID = spellID, castGUID = "channel", name = name, time = now, entry = Add(true) }
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local canceled = Engine.canceled
        if canceled and castGUID and canceled.castGUID == castGUID then
            canceled.entry.canceled = false -- it went through after all
            Engine.canceled = nil
            return
        end
        local current = Engine.current
        if current then
            if current.spellID == spellID then
                if current.castGUID ~= "channel" then
                    current.entry.casting = false
                    Engine.current = nil
                end
            elseif current.name ~= name then
                Add(false) -- an instant spell while casting
            end
        elseif (castTime or 0) <= 0 then
            Add(false)
        end
    elseif event == "UNIT_SPELLCAST_STOP" then
        local current = Engine.current
        if not current then return end
        Engine.current = nil
        current.entry.casting = false
        if Config().showCancel ~= false then
            current.entry.canceled = true
            Engine.canceled = { castGUID = castGUID, entry = current.entry }
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if Engine.current then Engine.current.entry.casting = false end
        Engine.current = nil
    end
end

function SH.Clear()
    Engine.entries = {}
    Engine.current, Engine.canceled, Engine.lastName, Engine.lastID = nil, nil, nil, nil
end

-------------------------------------------------------------------------------
--  Display: a row of icon slots. The renderer is shared with the preview.
-------------------------------------------------------------------------------
local function BorderColor(cfg)
    local mode = cfg.borderColor
    if mode == "black" then return 0, 0, 0 end
    if mode == "class" then
        local _, class = _G.UnitClass and _G.UnitClass("player")
        local color = class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    if KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        if r then return r, g, b end
    end
    return 1, 0.49, 0.04
end

-- Icon styles and shapes, as on the action bars (same textures): Modern KUI
-- (flat border), Simplicity (soft frame) and Blizzard (the classic button
-- frame); shapes cut the icon and draw a matching border (not on Blizzard).
local SIMPLICITY_MEDIA = "Interface\AddOns\KullThranUI\Modules\SimplicityTextures\\"
local SHAPE_MEDIA = "Interface\AddOns\KullThranUI\Libraries\texture\media\portraits\\"
local SHAPES = { CIRCLE = "circle", CSQUARE = "csquare", HEXAGON = "hexagon", DIAMOND = "diamond", SHIELD = "shield" }
local BLIZZARD_FRAME = "Interface\Buttons\UI-Quickslot2"
SH.SHAPES = SHAPES

local function NewIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:EnableMouse(false)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetColorTexture(0, 0, 0, 1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.edges = {}
    for i = 1, 4 do f.edges[i] = f:CreateTexture(nil, "OVERLAY") end
    f.frameArt = f:CreateTexture(nil, "OVERLAY", nil, 0)
    f.shapeBorder = f:CreateTexture(nil, "OVERLAY", nil, 0)
    f.cast = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.cast:SetColorTexture(0, 0, 0, 0.45)
    f.cancel = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.cancel:SetTexture(CANCEL_TEXTURE)
    f.cancel:SetPoint("CENTER")
    if f.CreateMaskTexture then f.mask = f:CreateMaskTexture() end
    return f
end

local function PaintIcon(f, entry, cfg, size, newest)
    local style = cfg.iconStyle or "KUI"
    local shape = style ~= "BLIZZARD" and SHAPES[cfg.iconShape] or nil
    local border = math.max(0, tonumber(cfg.borderSize) or 1)
    local scale = (newest and cfg.highlightNewest ~= false) and math.max(1, tonumber(cfg.newestScale) or 1.15) or 1
    local s = size * scale
    f:SetSize(s, s)
    local r, g, b = BorderColor(cfg)

    -- The icon: inside the flat border (Modern KUI), full size otherwise.
    local inset = (style == "KUI" and not shape) and border or 0
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", inset, -inset)
    f.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    f.icon:SetTexture(entry.icon)

    -- Shape mask, only while a shape is chosen: a plain icon has no mask at
    -- all (an always-on square mask hid the icons, leaving black squares).
    if f.mask then
        local wanted = shape ~= nil
        if wanted then
            f.mask:ClearAllPoints()
            f.mask:SetAllPoints(f)
            f.mask:SetTexture(SHAPE_MEDIA .. shape .. "_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        if wanted ~= (f.masked == true) then
            for _, layer in ipairs({ f.icon, f.cast }) do
                local method = wanted and layer.AddMaskTexture or layer.RemoveMaskTexture
                if method then method(layer, f.mask) end
            end
            f.masked = wanted
        end
    end

    -- Background: behind the icon, or the soft Simplicity backdrop around it;
    -- a shaped icon has none (its corners stay clear).
    f.bg:ClearAllPoints()
    f.bg:SetShown(not shape)
    if style == "SIMPLICITY" and not shape then
        f.bg:SetTexture(SIMPLICITY_MEDIA .. "Backdrop")
        f.bg:SetVertexColor(0, 0, 0, 1)
        f.bg:SetPoint("TOPLEFT", -3, 3)
        f.bg:SetPoint("BOTTOMRIGHT", 3, -3)
    else
        f.bg:SetColorTexture(0, 0, 0, 1)
        f.bg:SetAllPoints(f)
    end

    -- Borders: flat edges, the style's frame or the shape's own border.
    local e = f.edges
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(border)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(border)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(border)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(border)
    local flat = style == "KUI" and not shape and border > 0
    for i = 1, 4 do
        e[i]:SetColorTexture(r, g, b, 1)
        e[i]:SetShown(flat)
    end
    f.frameArt:ClearAllPoints()
    if style == "SIMPLICITY" and not shape then
        f.frameArt:SetTexture(SIMPLICITY_MEDIA .. "Normal")
        f.frameArt:SetVertexColor(r, g, b, 1)
        f.frameArt:SetPoint("TOPLEFT", -3, 3)
        f.frameArt:SetPoint("BOTTOMRIGHT", 3, -3)
        f.frameArt:Show()
    elseif style == "BLIZZARD" then
        -- The classic action button frame is drawn larger than the icon.
        local pad = s * 0.39
        f.frameArt:SetTexture(BLIZZARD_FRAME)
        f.frameArt:SetVertexColor(1, 1, 1, 1)
        f.frameArt:SetPoint("TOPLEFT", -pad, pad)
        f.frameArt:SetPoint("BOTTOMRIGHT", pad, -pad)
        f.frameArt:Show()
    else
        f.frameArt:Hide()
    end
    f.shapeBorder:ClearAllPoints()
    if shape then
        local offset = style == "SIMPLICITY" and 3 or 2
        f.shapeBorder:SetTexture(SHAPE_MEDIA .. shape .. "_border")
        f.shapeBorder:SetVertexColor(r, g, b, 1)
        f.shapeBorder:SetPoint("TOPLEFT", -offset, offset)
        f.shapeBorder:SetPoint("BOTTOMRIGHT", offset, -offset)
        f.shapeBorder:Show()
    else
        f.shapeBorder:Hide()
    end

    -- A cast in progress is dimmed until it lands.
    f.cast:ClearAllPoints()
    f.cast:SetAllPoints(f.icon)
    f.cast:SetShown(entry.casting == true)
    f.cancel:SetSize(s * 0.62, s * 0.62)
    f.cancel:SetShown(entry.canceled == true)
    f:SetAlpha(entry.alpha or 1)
end
SH.PaintIcon = PaintIcon

-- Where slot `pos` sits from the row's start, in the direction of travel.
local DIRECTIONS = {
    LEFT = { anchor = "RIGHT", dx = -1, dy = 0 },
    RIGHT = { anchor = "LEFT", dx = 1, dy = 0 },
    UP = { anchor = "BOTTOM", dx = 0, dy = 1 },
    DOWN = { anchor = "TOP", dx = 0, dy = -1 },
}
SH.DIRECTIONS = DIRECTIONS

local function RowSize(cfg)
    local size = math.max(12, tonumber(cfg.iconSize) or 36)
    local count = math.max(1, math.floor(tonumber(cfg.iconsNumber) or 5))
    local gap = math.max(0, tonumber(cfg.spacing) or 3)
    local long = count * size + (count - 1) * gap
    local dir = DIRECTIONS[cfg.direction] or DIRECTIONS.LEFT
    if dir.dy == 0 then return long, size end
    return size, long
end
SH.RowSize = RowSize

-- Advance the entries by `elapsed` and draw them in `row` (its icon pool in
-- row.icons). Shared by the live display and the options preview.
function SH.Render(row, entries, cfg, now, elapsed)
    local size = math.max(12, tonumber(cfg.iconSize) or 36)
    local count = math.max(1, math.floor(tonumber(cfg.iconsNumber) or 5))
    local gap = math.max(0, tonumber(cfg.spacing) or 3)
    local dir = DIRECTIONS[cfg.direction] or DIRECTIONS.LEFT
    local fadeDelay = tonumber(cfg.fadeDelay) or 4
    local fadeTime = math.max(0.1, tonumber(cfg.fadeTime) or 1.2)
    local w, h = RowSize(cfg)
    row:SetSize(w, h)
    if row.bg then
        row.bg:SetShown(cfg.showBackground == true)
        row.bg:SetColorTexture(0, 0, 0, tonumber(cfg.backgroundAlpha) or 0.5)
    end

    -- Animate: each entry slides towards its slot; old ones fade.
    local step = (elapsed or 0) * SLIDE_SPEED
    local index = 1
    while index <= #entries do
        local entry = entries[index]
        local target = index - 1
        if entry.pos < target then
            entry.pos = math.min(target, entry.pos + step)
        end
        local alpha = 1
        if fadeDelay > 0 and not entry.casting then
            local age = now - entry.time
            if age > fadeDelay then alpha = 1 - (age - fadeDelay) / fadeTime end
        end
        if entry.pos > count - 1 then
            alpha = math.min(alpha, 1 - (entry.pos - (count - 1)))
        end
        entry.alpha = math.max(0, math.min(1, alpha))
        if entry.alpha <= 0 or index > count + MAX_EXTRA then
            table.remove(entries, index)
        else
            index = index + 1
        end
    end

    row.icons = row.icons or {}
    for i, entry in ipairs(entries) do
        local f = row.icons[i] or NewIcon(row)
        row.icons[i] = f
        PaintIcon(f, entry, cfg, size, i == 1)
        local offset = math.max(0, entry.pos) * (size + gap) + size / 2
        f:ClearAllPoints()
        f:SetPoint("CENTER", row, dir.anchor, dir.dx * offset, dir.dy * offset)
        f:Show()
    end
    for i = #entries + 1, #row.icons do row.icons[i]:Hide() end
end

-------------------------------------------------------------------------------
--  Live row
-------------------------------------------------------------------------------
local display

local function IsUnlockModeOpen()
    local unlock = KT.GetModule and KT:GetModule("UnlockMode", true)
    return unlock and unlock.isOpen == true
end

-- Sample casts for Unlock Mode and the options preview.
local SAMPLE_ICONS = {
    "Interface\\Icons\\Spell_Fire_Fireball02", "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Nature_Lightning", "Interface\\Icons\\Ability_Warrior_Charge",
    "Interface\\Icons\\Spell_Holy_FlashHeal", "Interface\\Icons\\Ability_Rogue_Eviscerate",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Ability_Hunter_SteadyShot",
}
SH.SAMPLE_ICONS = SAMPLE_ICONS

-- Your own spells for the samples: the active spec's and class's spellbook
-- (no passives, no off-specs), else the spells on your action bars, else the
-- generic icons above.
local MAX_OWN_ICONS = 16
function SH.PlayerSpellIcons()
    local icons, seen = {}, {}
    local function Add(icon)
        if icon and not seen[icon] and #icons < MAX_OWN_ICONS then
            seen[icon] = true
            icons[#icons + 1] = icon
        end
    end
    local book = _G.C_SpellBook
    local bank = _G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Player or 0
    local spellType = _G.Enum and _G.Enum.SpellBookItemType and _G.Enum.SpellBookItemType.Spell or 1
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo then
        pcall(function()
            local lines = {}
            for index = 1, book.GetNumSpellBookSkillLines() do
                local line = book.GetSpellBookSkillLineInfo(index)
                -- Skip General (the first line), guild, hidden and off-spec lines.
                if line and index > 1 and not line.isGuild and not line.shouldHide and not line.offSpecID then
                    -- The spec's own line first, then the class line.
                    table.insert(lines, line.specID and 1 or #lines + 1, line)
                end
            end
            for _, line in ipairs(lines) do
                for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local item = book.GetSpellBookItemInfo(slot, bank)
                    if item and item.itemType == spellType and not item.isPassive and not item.isOffSpec then
                        Add(item.iconID)
                    end
                end
            end
        end)
    elseif _G.GetNumSpellTabs and _G.GetSpellTabInfo and _G.GetSpellBookItemTexture then
        pcall(function()
            for tab = 2, _G.GetNumSpellTabs() do
                local _, _, offset, numSpells, isGuild, offSpecID = _G.GetSpellTabInfo(tab)
                if not isGuild and (offSpecID or 0) == 0 then
                    for slot = offset + 1, offset + numSpells do
                        local passive = _G.IsPassiveSpell and _G.IsPassiveSpell(slot, "spell")
                        if not passive then Add(_G.GetSpellBookItemTexture(slot, "spell")) end
                    end
                end
            end
        end)
    end
    if #icons < 4 and _G.GetActionInfo and _G.GetActionTexture then
        for slot = 1, 120 do
            if _G.GetActionInfo(slot) == "spell" then Add(_G.GetActionTexture(slot)) end
        end
    end
    if #icons < 4 then
        for _, icon in ipairs(SAMPLE_ICONS) do Add(icon) end
    end
    return icons
end

local function SampleEntries(count, now)
    local icons = SH.PlayerSpellIcons()
    local list = {}
    for i = 1, count do
        list[i] = { icon = icons[(i - 1) % #icons + 1], time = now, pos = i - 1, alpha = 1,
            canceled = (i == 3) }
    end
    return list
end

local function ShouldShow(cfg)
    if not cfg.enable then return false end
    if IsUnlockModeOpen() then return true end
    if cfg.showWhen == "combat" then
        return SH.inCombat == true
    elseif cfg.showWhen == "instance" then
        local inInstance = _G.IsInInstance and _G.IsInInstance()
        return inInstance == true
    end
    return true
end

local function BuildDisplay()
    if display then return display end
    local f = CreateFrame("Frame", "KT_SpellHistory", UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f:Hide()
    display = f
    SH.ApplyPosition()
    f:SetScript("OnUpdate", function(self, elapsed)
        self.acc = (self.acc or 0) + elapsed
        if self.acc < 0.02 then return end
        local dt = self.acc
        self.acc = 0
        local cfg = Config()
        local now = GetTime()
        local current = Engine.current
        if current and now - current.time > STALE_CAST then
            current.entry.casting = false
            Engine.current = nil
        end
        if IsUnlockModeOpen() and #Engine.entries == 0 then
            self.samples = self.samples or SampleEntries(math.max(1, math.floor(tonumber(cfg.iconsNumber) or 5)), now)
            for _, entry in ipairs(self.samples) do entry.time = now end
            SH.Render(self, self.samples, cfg, now, dt)
        else
            self.samples = nil
            SH.Render(self, Engine.entries, cfg, now, dt)
        end
    end)
    return f
end

-- Until you move it, the row sits under the Cooldown Manager (the lowest of
-- its shown bars), a little apart so the two never overlap in Unlock Mode,
-- and follows it when the CDM moves.
local CDM_FRAMES = { "KUI_CDMBar_cooldowns", "KUI_CDMBar_utility", "EssentialCooldownViewer", "UtilityCooldownViewer" }
local CDM_GAP = 24

function SH.CDMAnchor()
    local lowest, lowestBottom
    for _, name in ipairs(CDM_FRAMES) do
        local frame = _G[name]
        local bottom = frame and frame.IsShown and frame:IsShown() and frame.GetBottom and frame:GetBottom()
        if bottom and not issecretvalue(bottom) and (not lowestBottom or bottom < lowestBottom) then
            lowest, lowestBottom = frame, bottom
        end
    end
    return lowest
end

function SH.ApplyPosition()
    local f = display
    if not f then return end
    local p = Config().position
    f:ClearAllPoints()
    if p then
        f:SetPoint(p.point or "CENTER", UIParent, p.relativePoint or p.point or "CENTER", p.x or 0, p.y or -180)
        return
    end
    local cdm = SH.CDMAnchor()
    if cdm then
        f:SetPoint("TOP", cdm, "BOTTOM", 0, -CDM_GAP)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
end

-- The row's place as an offset from the screen centre (what Unlock Mode
-- stores), also while it still follows the CDM.
local function CurrentPosition()
    local p = Config().position
    if p then
        return { point = p.point or "CENTER", relativePoint = p.relativePoint or p.point or "CENTER", x = p.x or 0, y = p.y or -180 }
    end
    local f = display
    local fx, fy = f and f.GetCenter and f:GetCenter()
    local ux, uy = UIParent.GetCenter and UIParent:GetCenter()
    if fx and ux then
        return { point = "CENTER", relativePoint = "CENTER", x = math.floor(fx - ux + 0.5), y = math.floor(fy - uy + 0.5) }
    end
    return { point = "CENTER", relativePoint = "CENTER", x = 0, y = -180 }
end
SH.CurrentPosition = CurrentPosition

function SH.Refresh()
    local cfg = Config()
    local f = BuildDisplay()
    SH.ApplyPosition()
    local w, h = RowSize(cfg)
    f:SetSize(w, h)
    f:SetShown(ShouldShow(cfg))
end

-------------------------------------------------------------------------------
--  Options preview: the same row, fed with sample casts.
-------------------------------------------------------------------------------
function SH.CreatePreview(parent, width, height)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    p:SetSize(width, height)
    p:SetClipsChildren(true)
    if KT.AddBackdrop then KT:AddBackdrop(p, 0.02, 0.02, 0.025, 0.85) end
    p.label = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.label:SetPoint("TOPLEFT", 8, -6)
    p.label:SetText(LText("LIVE PREVIEW"))
    -- Glass card border (Widgets.lua W:PreviewCard).
    if KT.Widgets and KT.Widgets.PreviewCard then KT.Widgets:PreviewCard(p) end
    if KT.SetAccentTextColor then KT:SetAccentTextColor(p.label, 1) end

    local row = CreateFrame("Frame", nil, p)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    p.row = row
    p.entries = {}
    p.nextCast, p.sample = 0, 0
    -- The samples are your own class and spec spells.
    p.icons = SH.PlayerSpellIcons()

    -- A loop of casts: mostly instants, now and then a cast that lands or one
    -- that is stopped (red cross), so every option has something to show.
    local function Step(self, now)
        local current = self.casting
        if current and now >= current.ends then
            current.entry.casting = false
            if current.cancel then current.entry.canceled = true end
            self.casting = nil
        end
        if self.casting or now < self.nextCast then return end
        self.sample = self.sample + 1
        -- Re-read once per pass: a spec change shows on the next loop.
        if (self.sample - 1) % #self.icons == 0 then self.icons = SH.PlayerSpellIcons() end
        local icon = self.icons[(self.sample - 1) % #self.icons + 1]
        local entry = AddEntry(self.entries, self.sample, icon, nil, nil, now)
        if self.sample % 4 == 0 then
            entry.casting = true
            self.casting = { entry = entry, ends = now + 1.4, cancel = (self.sample % 8 == 0) and Config().showCancel ~= false }
            self.nextCast = now + 1.6
        else
            self.nextCast = now + 0.9
        end
    end

    function p:Refresh(elapsed)
        local cfg = Config()
        local now = GetTime()
        Step(self, now)
        SH.Render(row, self.entries, cfg, now, elapsed or 0)
        -- Keep the row inside the box: scale it down when it is long.
        local w, h = RowSize(cfg)
        local scale = math.min(1, (width - 40) / math.max(1, w), (height - 40) / math.max(1, h))
        row:SetScale(scale)
        row:ClearAllPoints()
        row:SetPoint("CENTER", self, "CENTER", 0, -8 / scale)
    end
    p:SetScript("OnUpdate", function(self, elapsed)
        self._acc = (self._acc or 0) + (elapsed or 0)
        if self._acc < 0.02 then return end
        local dt = self._acc
        self._acc = 0
        self:Refresh(dt)
    end)
    p:Refresh(0)
    return p
end

-------------------------------------------------------------------------------
--  Unlock Mode and events
-------------------------------------------------------------------------------
local function RegisterMover()
    if SH.moverRegistered or not KT.RegisterMovableElements then return end
    KT:RegisterMovableElements({
        {
            key = "ENH_SPELL_HISTORY",
            label = LText("Spell History"),
            group = "Enhancements",
            getFrame = function() return BuildDisplay() end,
            getSize = function()
                local w, h = RowSize(Config())
                return math.max(40, w), math.max(20, h)
            end,
            isHidden = function() return not Config().enable end,
            loadPosition = function()
                BuildDisplay()
                SH.ApplyPosition()
                return CurrentPosition()
            end,
            savePosition = function(_, point, relativePoint, x, y)
                Config().position = { point = point or "CENTER", relativePoint = relativePoint or point or "CENTER", x = x or 0, y = y or -180 }
            end,
            applyPosition = function() SH.ApplyPosition() end,
            applyPendingPosition = function(_, pos)
                local f = BuildDisplay()
                f:ClearAllPoints()
                f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or pos.point or "CENTER", pos.x or 0, pos.y or -180)
            end,
        },
    })
    SH.moverRegistered = true
end

local SPELL_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
    if event == "PLAYER_LOGIN" then
        RegisterMover()
        local unlock = KT.GetModule and KT:GetModule("UnlockMode", true)
        if unlock and _G.hooksecurefunc then
            for _, method in ipairs({ "OpenUnlockMode", "CloseUnlockMode" }) do
                if type(unlock[method]) == "function" then _G.hooksecurefunc(unlock, method, function() SH.Refresh() end) end
            end
        end
        -- Spell events start a moment after login: the first world entry
        -- replays a burst of casts that are not yours to show.
        _G.C_Timer.After(0.5, function()
            for _, spellEvent in ipairs(SPELL_EVENTS) do
                pcall(self.RegisterUnitEvent, self, spellEvent, "player")
            end
        end)
        SH.Refresh()
        _G.C_Timer.After(2, SH.Refresh)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        SH.inCombat = _G.UnitAffectingCombat and _G.UnitAffectingCombat("player") or false
        SH.Clear()
        SH.Refresh()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        SH.inCombat = event == "PLAYER_REGEN_DISABLED"
        SH.Refresh()
        return
    end
    if not Config().enable then return end
    SH.OnSpellEvent(event, castGUID, spellID)
end)
