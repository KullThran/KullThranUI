-------------------------------------------------------------------------------
--  Active Stance: a KUI stance bar beside the player frame. Every stance, form,
--  aura or stealth the stance bar offers is a secure button that casts it on a
--  click (also in combat); the active one carries the accent border. On
--  Forever, hunter aspects and paladin auras (kept off the stance bar) are
--  buttons too. The "active" style shows only the current one, as an icon.
--  Layout (creating, placing, showing secure buttons) happens out of combat;
--  in combat only textures change and a pending layout waits for
--  PLAYER_REGEN_ENABLED. Event driven, no OnUpdate.
--  Settings in KT.db.profile.unitFrames: activeStance (off by default),
--  activeStanceStyle, activeStanceSize, activeStanceSpacing,
--  activeStancePosition, activeStanceX, activeStanceY.
-------------------------------------------------------------------------------
local _, ns = ...
local KT = _G.KullThranUI

local AS = {}
ns.ActiveStance = AS

AS.DEFAULT_SIZE = 26
AS.DEFAULT_SPACING = 2
AS.DEFAULT_STYLE = "bar"
-- Above the frame, over the left end of its bars (not the portrait).
AS.DEFAULT_POSITION = "ABOVE_BARS"
AS.MAX_BUTTONS = 12

AS.STYLE_LABELS = {
    bar = "All Stances (clickable)",
    active = "Active Stance Only",
}

-- Bar point, frame point and the gap away from the frame.
AS.POSITIONS = {
    -- Anchored to the health bar's top-left, lifted over the name box (Layout).
    ABOVE_BARS  = { "BOTTOMLEFT", "TOPLEFT", 0, 4 },
    BELOW_LEFT  = { "TOPLEFT", "BOTTOMLEFT", 0, -4 },
    BELOW_RIGHT = { "TOPRIGHT", "BOTTOMRIGHT", 0, -4 },
    ABOVE_LEFT  = { "BOTTOMLEFT", "TOPLEFT", 0, 4 },
    ABOVE_RIGHT = { "BOTTOMRIGHT", "TOPRIGHT", 0, 4 },
    LEFT        = { "RIGHT", "LEFT", -4, 0 },
    RIGHT       = { "LEFT", "RIGHT", 4, 0 },
    -- Placed in Unlock Mode: X/Y from the player frame's centre, so the bar
    -- still follows the frame when the frame moves.
    FREE        = { "CENTER", "CENTER", 0, 0 },
}

AS.POSITION_LABELS = {
    ABOVE_BARS = "Above the Bars, Left",
    BELOW_LEFT = "Below, Left", BELOW_RIGHT = "Below, Right",
    ABOVE_LEFT = "Above, Left", ABOVE_RIGHT = "Above, Right",
    LEFT = "Left Side", RIGHT = "Right Side",
    FREE = "Free (Unlock Mode)",
}

-- Forever keeps hunter aspects and paladin auras off the stance bar. Each group
-- lists every rank a player can learn, lowest first, read from Forever's
-- SpellName and SkillLineAbility tables (1.60.1, 2026-11-07); Sanctity Aura is
-- a talent. A group's button casts the highest known rank and is active while
-- the player's own buff from any rank is up.
AS.BUFF_GROUPS = {
    HUNTER = {
        { 13165, 14318, 14319, 14320, 14321, 14322, 25296 },   -- Aspect of the Hawk
        { 13163 },                                             -- Aspect of the Monkey
        { 5118 },                                              -- Aspect of the Cheetah
        { 13159 },                                             -- Aspect of the Pack
        { 13161, 1299445, 1299446, 1299447 },                  -- Aspect of the Beast
        { 20043, 20190 },                                      -- Aspect of the Wild
        { 415423 },                                            -- Aspect of the Viper
    },
    PALADIN = {
        { 465, 643, 1032, 10290, 10291, 10292, 10293 },        -- Devotion Aura
        { 7294, 10298, 10299, 10300, 10301 },                  -- Retribution Aura
        { 19746 },                                             -- Concentration Aura
        { 19876, 19895, 19896 },                               -- Shadow Resistance Aura
        { 19888, 19897, 19898 },                               -- Frost Resistance Aura
        { 19891, 19899, 19900 },                               -- Fire Resistance Aura
        { 20218 },                                             -- Sanctity Aura
    },
}

-- Shown while Unlock Mode is open with nothing to show, so the bar can be moved.
local PLACEHOLDER_ICON = 134400 -- INV_Misc_QuestionMark

local function Settings()
    local db = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
    return db or {}
end

function AS.Enabled()
    return Settings().activeStance == true
end

function AS.Style()
    local style = Settings().activeStanceStyle
    return AS.STYLE_LABELS[style] and style or AS.DEFAULT_STYLE
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Size()
    return math.max(12, math.min(80, tonumber(Settings().activeStanceSize) or AS.DEFAULT_SIZE))
end

local function Spacing()
    return math.max(0, math.min(20, tonumber(Settings().activeStanceSpacing) or AS.DEFAULT_SPACING))
end

local function AccentColor()
    local palette = KT and KT.GetStylePalette and KT:GetStylePalette()
    local accent = palette and palette.accent
    if accent and accent.r then return accent.r, accent.g, accent.b end
    return 1, 0.82, 0
end

local function SpellIcon(spellID)
    local getTexture = (_G.C_Spell and _G.C_Spell.GetSpellTexture) or _G.GetSpellTexture
    if not getTexture then return nil end
    local ok, icon = pcall(getTexture, spellID)
    return ok and icon or nil
end

local function NumForms()
    if type(GetNumShapeshiftForms) ~= "function" then return 0 end
    local ok, n = pcall(GetNumShapeshiftForms)
    if not ok or type(n) ~= "number" or IsSecret(n) then return 0 end
    return math.min(n, AS.MAX_BUTTONS)
end

-- Icon, active, castable and spell id of form `index`. The stance bar shows a
-- generic icon for some forms and auras; the form's own spell icon is used.
local function FormInfo(index)
    if type(GetShapeshiftFormInfo) ~= "function" then return nil end
    local ok, icon, active, castable, spellID = pcall(GetShapeshiftFormInfo, index)
    if not ok or not icon then return nil end
    if type(spellID) == "number" and not IsSecret(spellID) then
        icon = SpellIcon(spellID) or icon
    end
    return icon, active, castable, spellID
end

local function ActiveFormIndex()
    if type(GetShapeshiftForm) ~= "function" then return nil end
    local ok, index = pcall(GetShapeshiftForm)
    if not ok or type(index) ~= "number" or IsSecret(index) or index <= 0 then return nil end
    return index
end

local function Known(spellID)
    for _, check in ipairs({ _G.IsPlayerSpell, _G.IsSpellKnown }) do
        if type(check) == "function" then
            local ok, known = pcall(check, spellID)
            if ok and known then return true end
        end
    end
    return false
end

local function HighestKnownRank(group)
    for i = #group, 1, -1 do
        if Known(group[i]) then return group[i] end
    end
    return nil
end

local function BuffGroups()
    if not (KT and KT.IS_FOREVER) or type(UnitClass) ~= "function" then return nil end
    local _, classFile = UnitClass("player")
    return AS.BUFF_GROUPS[classFile]
end

-- Spell ids of the player's own buffs, or nil while aura data can't be read
-- (a group then keeps the state it last showed).
local function OwnBuffIDs()
    local getAura = _G.C_UnitAuras and _G.C_UnitAuras.GetAuraDataByIndex
    if not getAura then return nil end
    local ids = {}
    for i = 1, 40 do
        local ok, aura = pcall(getAura, "player", i, "HELPFUL|PLAYER")
        if not ok or IsSecret(aura) then return nil end
        if not aura then break end
        local id = aura.spellId
        if id and not IsSecret(id) then ids[id] = true end
    end
    return ids
end

-- What the bar shows: the stance-bar forms, then the known aspect or aura groups.
local function Entries()
    local list, onStanceBar = {}, {}
    for index = 1, NumForms() do
        list[#list + 1] = { form = index }
        local _, _, _, spellID = FormInfo(index)
        if spellID then onStanceBar[spellID] = true end
    end
    for _, group in ipairs(BuffGroups() or {}) do
        -- An aura the stance bar already offers is not listed twice.
        local listed = false
        for _, id in ipairs(group) do
            if onStanceBar[id] then listed = true break end
        end
        local spellID = not listed and HighestKnownRank(group)
        if spellID and #list < AS.MAX_BUTTONS then
            list[#list + 1] = { group = group, spellID = spellID }
        end
    end
    return list
end

-- Icon, active, usable and spell id of one entry.
local function EntryInfo(entry, activeForm, ownBuffs)
    if entry.form then
        local icon, active, castable, spellID = FormInfo(entry.form)
        return icon, active or entry.form == activeForm, castable ~= false, spellID
    end
    if ownBuffs then
        local active = false
        for _, id in ipairs(entry.group) do
            if ownBuffs[id] then active = true break end
        end
        entry.active = active
    end
    local usable = true
    local isUsable = (_G.C_Spell and _G.C_Spell.IsSpellUsable) or _G.IsUsableSpell
    if isUsable then
        local ok, result = pcall(isUsable, entry.spellID)
        if ok and result == false then usable = false end
    end
    return SpellIcon(entry.spellID), entry.active == true, usable, entry.spellID
end

local function EntryCooldown(entry)
    if entry.form then
        if type(GetShapeshiftFormCooldown) ~= "function" then return nil end
        local ok, start, duration, enable = pcall(GetShapeshiftFormCooldown, entry.form)
        if ok and enable ~= 0 then return start, duration end
        return nil
    end
    if _G.C_Spell and _G.C_Spell.GetSpellCooldown then
        local ok, info = pcall(_G.C_Spell.GetSpellCooldown, entry.spellID)
        if ok and type(info) == "table" and info.isEnabled ~= false then return info.startTime, info.duration end
        return nil
    end
    if _G.GetSpellCooldown then
        local ok, start, duration, enable = pcall(_G.GetSpellCooldown, entry.spellID)
        if ok and enable ~= 0 then return start, duration end
    end
    return nil
end

local function ShowTooltip(self)
    local entry = self.entry
    if not entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if entry.form and GameTooltip.SetShapeshift then
        GameTooltip:SetShapeshift(entry.form)
    elseif entry.spellID and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(entry.spellID)
    end
    GameTooltip:Show()
end

local function HideTooltip() GameTooltip:Hide() end

local function Decorate(button)
    button:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    button:SetBackdropBorderColor(0, 0, 0, 1)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", HideTooltip)
end

-- The bar's holder on the player frame. It turns protected once it holds the
-- secure buttons, so it is only placed and shown out of combat.
local function Holder(frame)
    local holder = frame._kuiActiveStance
    if holder then return holder end
    holder = CreateFrame("Frame", nil, frame)
    holder:SetFrameLevel((frame:GetFrameLevel() or 1) + 30)
    holder.buttons = {}
    holder.entries = {}
    -- The "active" style and the Unlock Mode placeholder: a plain icon that can
    -- show and hide in combat.
    holder.single = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    Decorate(holder.single)
    holder.single:EnableMouse(true)
    holder.single:Hide()
    frame._kuiActiveStance = holder
    return holder
end

local function SecureButton(holder, index)
    local button = holder.buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, holder, "SecureActionButtonTemplate,BackdropTemplate")
    Decorate(button)
    button:RegisterForClicks("LeftButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("type", "spell")
    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    end
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button.icon)
    holder.buttons[index] = button
    return button
end

-- Textures only: active border, usable tint, cooldown. Safe in combat.
local function PaintButton(button, entry, activeForm, ownBuffs)
    local icon, active, usable = EntryInfo(entry, activeForm, ownBuffs)
    button.entry = entry
    button.icon:SetTexture(icon or PLACEHOLDER_ICON)
    if active then
        local r, g, b = AccentColor()
        button:SetBackdropBorderColor(r, g, b, 1)
        button.icon:SetVertexColor(1, 1, 1, 1)
    else
        button:SetBackdropBorderColor(0, 0, 0, 1)
        -- Inactive entries a touch dimmer; ones that cannot be used now, more.
        local tone = usable and 0.75 or 0.4
        button.icon:SetVertexColor(tone, tone, tone, 1)
    end
    if button.cooldown then
        local start, duration = EntryCooldown(entry)
        if type(start) == "number" and type(duration) == "number" and duration > 0
            and not IsSecret(start) and not IsSecret(duration) then
            button.cooldown:SetCooldown(start, duration)
        elseif button.cooldown.Clear then
            button.cooldown:Clear()
        end
    end
end

function AS.Paint()
    local frame = ns.frames and ns.frames.player
    local holder = frame and frame._kuiActiveStance
    if not holder or not AS.Enabled() then return end
    local activeForm = ActiveFormIndex()
    local ownBuffs = holder.hasBuffGroups and OwnBuffIDs() or nil
    if AS.Style() == "active" or holder.showsPlaceholder then
        local single, shown = holder.single, nil
        for _, entry in ipairs(holder.entries) do
            local icon, active = EntryInfo(entry, activeForm, ownBuffs)
            if active then shown = true; single.entry = entry; single.icon:SetTexture(icon or PLACEHOLDER_ICON) break end
        end
        if not shown and holder.showsPlaceholder then
            shown = true
            single.entry = nil
            single.icon:SetTexture(PLACEHOLDER_ICON)
        end
        if shown then single:Show() else single:Hide() end
        return
    end
    for index = 1, holder.shownButtons or 0 do
        PaintButton(holder.buttons[index], holder.entries[index], activeForm, ownBuffs)
    end
end

local function PlaceHolder(frame, holder, width, height)
    local db = Settings()
    local position = AS.POSITIONS[db.activeStancePosition] or AS.POSITIONS[AS.DEFAULT_POSITION]
    holder:SetSize(math.max(1, width), math.max(1, height))
    holder:ClearAllPoints()
    local anchor, lift = frame, 0
    if position == AS.POSITIONS.ABOVE_BARS and frame.Health then
        anchor = frame.Health
        local frameTop, barTop = frame:GetTop(), frame.Health:GetTop()
        if frameTop and barTop and frameTop > barTop then lift = frameTop - barTop end
    end
    holder:SetPoint(position[1], anchor, position[2],
        position[3] + (tonumber(db.activeStanceX) or 0), position[4] + lift + (tonumber(db.activeStanceY) or 0))
end

-- Builds, places and shows the buttons. Out of combat only.
function AS.Layout()
    local frame = ns.frames and ns.frames.player
    if not frame then return end
    local holder = frame._kuiActiveStance
    if InCombat() then
        -- Secure buttons can't be set up, placed or shown now: repaint what is
        -- there and lay out after combat.
        AS.pendingLayout = true
        if holder then AS.Paint() end
        return
    end
    AS.pendingLayout = nil
    if not AS.Enabled() then
        if holder then holder:Hide() end
        return
    end
    holder = holder or Holder(frame)
    local size, spacing = Size(), Spacing()
    local entries = Entries()
    holder.entries = entries
    holder.hasBuffGroups = false
    for _, entry in ipairs(entries) do
        if entry.group then holder.hasBuffGroups = true break end
    end
    local count = AS.Style() == "bar" and #entries or 0
    local unlocking = KT and KT._unlockActive
    holder.showsPlaceholder = (AS.Style() == "active" or count == 0) and unlocking and true or nil

    for index = 1, math.max(count, #holder.buttons) do
        local button = index <= count and SecureButton(holder, index) or holder.buttons[index]
        if index <= count then
            local _, _, _, spellID = EntryInfo(entries[index], nil, nil)
            button:SetAttribute("spell", spellID)
            button:SetSize(size, size)
            button:ClearAllPoints()
            button:SetPoint("LEFT", holder, "LEFT", (index - 1) * (size + spacing), 0)
            button:Show()
        else
            button:Hide()
        end
    end
    holder.shownButtons = count

    holder.single:SetSize(size, size)
    holder.single:ClearAllPoints()
    holder.single:SetPoint("LEFT", holder, "LEFT", 0, 0)
    if count > 0 then holder.single:Hide() end

    local slots = math.max(count, 1)
    PlaceHolder(frame, holder, slots * size + (slots - 1) * spacing, size)
    holder:Show()
    AS.Paint()
end

-- Kept for callers from before the bar: a full refresh.
AS.Update = AS.Layout

-------------------------------------------------------------------------------
--  Unlock Mode: the bar is a mover in the Unit Frames group. A drag is saved as
--  the FREE position with its offset from the player frame's centre.
-------------------------------------------------------------------------------
local function ScreenCenter(region)
    local x, y = region:GetCenter()
    if not x then return nil end
    local scale = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * scale, y * scale
end

local function PlayerAndHolder()
    local frame = ns.frames and ns.frames.player
    if not frame then return nil end
    return frame, frame._kuiActiveStance or Holder(frame)
end

function AS.RegisterMover()
    if AS.moverRegistered or not (KT and KT.RegisterMovableElements) then return end
    if not (ns.frames and ns.frames.player) then return end
    KT:RegisterMovableElements({
        {
            key = "UF_ACTIVE_STANCE",
            label = ns.UFLoc and ns.UFLoc("Active Stance") or "Active Stance",
            group = "Unit Frames",
            getFrame = function()
                local _, holder = PlayerAndHolder()
                return holder
            end,
            getSize = function()
                local size, spacing = Size(), Spacing()
                local slots = math.max(AS.Style() == "bar" and #Entries() or 1, 1)
                return slots * size + (slots - 1) * spacing, size
            end,
            isHidden = function() return not AS.Enabled() end,
            loadPosition = function()
                AS.Layout()
                local _, holder = PlayerAndHolder()
                local x, y = holder and ScreenCenter(holder)
                if not x then return { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 } end
                return { point = "CENTER", relativePoint = "CENTER",
                    x = x - UIParent:GetWidth() / 2, y = y - UIParent:GetHeight() / 2 }
            end,
            savePosition = function(key, point, relativePoint, x, y)
                local frame, holder = PlayerAndHolder()
                if not frame or InCombat() then return end
                -- Only a drag being saved moves the bar. Unlock Mode also
                -- replays its stored absolute spot on every loading screen;
                -- the bar's position already lives in its own offset (or
                -- preset), and re-deriving it from wherever the player frame
                -- is at that moment pulled the bar away from the frame.
                local unlock = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
                local pending = unlock and unlock.pendingPositions
                if not (pending and pending[key or "UF_ACTIVE_STANCE"]) then return end
                -- Seat the bar where the mover left it, then keep that spot as
                -- an offset from the player frame (both share the frame's scale).
                holder:ClearAllPoints()
                holder:SetPoint(point or "CENTER", UIParent, relativePoint or point or "CENTER", x or 0, y or 0)
                local hx, hy = holder:GetCenter()
                local fx, fy = frame:GetCenter()
                if not (hx and fx) then return end
                local db = Settings()
                db.activeStancePosition = "FREE"
                db.activeStanceX = math.floor(hx - fx + 0.5)
                db.activeStanceY = math.floor(hy - fy + 0.5)
                AS.Layout()
            end,
            applyPosition = function() AS.Layout() end,
            applyPendingPosition = function(_, pos)
                local _, holder = PlayerAndHolder()
                if not holder or not pos or InCombat() then return end
                holder:ClearAllPoints()
                holder:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
            end,
        },
    })
    AS.moverRegistered = true
end

local PAINT_EVENTS = {
    UPDATE_SHAPESHIFT_FORM = true, UPDATE_SHAPESHIFT_USABLE = true,
    UPDATE_SHAPESHIFT_COOLDOWN = true, SPELL_UPDATE_COOLDOWN = true, UNIT_AURA = true,
}

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
    "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE",
    "UPDATE_SHAPESHIFT_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
}) do
    events:RegisterEvent(event)
end
-- Aspects and auras: only the player's own aura changes repaint.
if events.RegisterUnitEvent then events:RegisterUnitEvent("UNIT_AURA", "player") end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        pcall(AS.RegisterMover)
        -- Unlock Mode shows the placeholder and hides it again on close.
        local unlock = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
        if unlock and not AS.unlockHooked and _G.hooksecurefunc then
            for _, method in ipairs({ "OpenUnlockMode", "CloseUnlockMode" }) do
                if type(unlock[method]) == "function" then
                    _G.hooksecurefunc(unlock, method, function() pcall(AS.Layout) end)
                end
            end
            AS.unlockHooked = true
        end
    end
    if event == "PLAYER_REGEN_ENABLED" and not AS.pendingLayout then return end
    if event == "UNIT_AURA" then
        local frame = ns.frames and ns.frames.player
        local holder = frame and frame._kuiActiveStance
        if not (holder and holder.hasBuffGroups) then return end
    end
    if PAINT_EVENTS[event] then
        pcall(AS.Paint)
    else
        pcall(AS.Layout)
    end
end)
