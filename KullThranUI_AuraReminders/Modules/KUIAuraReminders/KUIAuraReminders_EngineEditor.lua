-- Custom aura engine, editor support: what each option can do in this client (the editor's capability badges), the
-- live preview with mock data, and class templates by client. Reasons are English option strings for the page to
-- localise. Shared byte for byte between the Retail and Forever workspaces.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local IsSecret, ValidID = E.IsSecret, E.ValidID

-- Capabilities --------------------------------------------------------------------------------------------------------

-- A badge is { level, reason }: "combat" works in combat (shown by the client, or readable), "ooc" is readable out of
-- combat only, "none" is not available on this client. Static: it says what restricted combat will do with this
-- configuration, not what is readable at this moment.
local Caps = {}
E.Caps = Caps

local COMBAT, OUT_OF_COMBAT, UNAVAILABLE = "combat", "ooc", "none"
Caps.COMBAT, Caps.OUT_OF_COMBAT, Caps.UNAVAILABLE = COMBAT, OUT_OF_COMBAT, UNAVAILABLE

Caps.R_DELEGATED = "The game client shows it in combat, also while it is secret."
Caps.R_READABLE = "Readable in combat."
Caps.R_OUT = "Readable out of combat only; in combat it follows While Secret."
Caps.R_MISSING = "A missing aura is readable out of combat only."
Caps.R_NO_CDM = "The Cooldown Manager is not available on this client."
Caps.R_SOUND_CLIENT = "The game client plays it, also while the aura is secret."
Caps.R_SOUND_OUT = "Played only while the aura is readable."
Caps.R_STACKS_OUT = "Stacks are readable out of combat only; in combat it follows While Secret."
Caps.R_VALUE = "Readable in combat unless the game client keeps it secret; then it follows While Secret."
Caps.R_UNIT_OUT = "Values of other units can be secret in combat: a bar still fills, comparisons follow While Secret."
Caps.R_CAST = "Seen in combat, also while the spell being cast is secret."
Caps.R_CAST_SPELL = "Which spell another unit casts can be secret in combat; then it follows While Secret."

local RANK = { [COMBAT] = 1, [OUT_OF_COMBAT] = 2, [UNAVAILABLE] = 3 }
local NEVER_SECRET = (Enum and Enum.SecrecyLevel and Enum.SecrecyLevel.NeverSecret) or 0
local CDM_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function Cap(level, reason)
    return { level = level, reason = reason }
end

local function Worst(a, b)
    if not a then return b end
    if not b then return a end
    if RANK[b.level] > RANK[a.level] then return b end
    return a
end

-- Whether a slot can be handed to the client's aura engine: AuraKit and its containers are there.
function Caps.Delegation()
    local AK = _G.KTAuraKit
    return type(AK) == "table" and type(AK.RequestContainer) == "function"
end

function Caps.CooldownManager()
    for _, name in ipairs(CDM_VIEWERS) do
        if _G[name] ~= nil then return true end
    end
    return false
end

local function ValidSpells(list)
    local out = {}
    for _, id in ipairs(list or {}) do
        if ValidID(id) then out[#out + 1] = id end
    end
    return out
end

-- Whether every spell's aura stays readable in restricted combat: no secrets on this client, or each spell is
-- flagged never secret.
local function ReadableInCombat(spells)
    local api = C_Secrets
    if not (api and api.ShouldAurasBeSecret) then return true end
    if not api.GetSpellAuraSecrecy then return false end
    for _, id in ipairs(spells) do
        local ok, level = pcall(api.GetSpellAuraSecrecy, id)
        if not ok or IsSecret(level) or level ~= NEVER_SECRET then return false end
    end
    return true
end

local function SourceCap(record, src)
    if src.kind == "aura" then
        local spells = ValidSpells(src.spells)
        if #spells == 0 then return nil end
        if ReadableInCombat(spells) then return Cap(COMBAT, Caps.R_READABLE) end
        if src.missing then return Cap(OUT_OF_COMBAT, Caps.R_MISSING) end
        local region = record.region or {}
        if region.kind ~= "text" and Caps.Delegation() and E.DelegableSource(record) == src then
            return Cap(COMBAT, Caps.R_DELEGATED)
        end
        return Cap(OUT_OF_COMBAT, Caps.R_OUT)
    elseif src.kind == "cooldown" then
        if not ValidID(src.spell) then return nil end
        return Cap(COMBAT, Caps.R_READABLE)
    elseif src.kind == "cdm" then
        if not Caps.CooldownManager() then return Cap(UNAVAILABLE, Caps.R_NO_CDM) end
        if #ValidSpells(src.spells) == 0 then return nil end
        return Cap(COMBAT, Caps.R_READABLE)
    elseif src.kind == "state" or src.kind == "item" then
        return Cap(COMBAT, Caps.R_READABLE)
    elseif src.kind == "health" or src.kind == "power" then
        if (src.unit or "player") == "player" then return Cap(COMBAT, Caps.R_VALUE) end
        return Cap(OUT_OF_COMBAT, Caps.R_UNIT_OUT)
    elseif src.kind == "charges" or src.kind == "usable" then
        if not ValidID(src.spell) then return nil end
        return Cap(COMBAT, Caps.R_VALUE)
    elseif src.kind == "cast" then
        if src.spell and (src.unit or "player") ~= "player" then return Cap(OUT_OF_COMBAT, Caps.R_CAST_SPELL) end
        return Cap(COMBAT, Caps.R_CAST)
    end
    return nil
end

-- The trigger's badge: the weakest of its sources, nil when no source has anything to track yet.
function Caps.Trigger(record)
    local out
    for _, src in ipairs(record.sources or {}) do out = Worst(out, SourceCap(record, src)) end
    return out
end

-- Sounds: the client plays them for an aura it shows (E.Sound.EngineEligible); otherwise they play on readable
-- answers only.
function Caps.Sound(record, trigger)
    local sound = record.sound
    if not (sound and (sound.applied ~= nil or sound.removed ~= nil)) or not trigger then return nil end
    if trigger.reason == Caps.R_DELEGATED then
        local src, S = E.DelegableSource(record), E.Sound
        if src and S and S.EngineEligible(record, src) and C_UnitAuras and C_UnitAuras.AddAuraSound then
            return Cap(COMBAT, Caps.R_SOUND_CLIENT)
        end
        return Cap(OUT_OF_COMBAT, Caps.R_SOUND_OUT)
    end
    if trigger.level == COMBAT then return Cap(COMBAT, Caps.R_READABLE) end
    if trigger.level == UNAVAILABLE then return Cap(UNAVAILABLE, trigger.reason) end
    return Cap(OUT_OF_COMBAT, Caps.R_SOUND_OUT)
end

-- Stacks (filter, stack bar, stack alert): read from the aura itself, so readable in combat only for an aura that is
-- never secret, or on a client without secrets. nil when the record uses no stack option or has no aura to count.
function Caps.Stacks(record)
    local stacks = E.Stacks
    if not (stacks and stacks.Uses(record)) then return nil end
    local src = record.sources and record.sources[1]
    if not src or (src.kind ~= "aura" and src.kind ~= "cdm") then return nil end
    local api = C_Secrets
    if not (api and api.ShouldAurasBeSecret) then return Cap(COMBAT, Caps.R_READABLE) end
    if src.kind == "aura" then
        local spells = ValidSpells(src.spells)
        if #spells > 0 and ReadableInCombat(spells) then return Cap(COMBAT, Caps.R_READABLE) end
    end
    return Cap(OUT_OF_COMBAT, Caps.R_STACKS_OUT)
end

-- Import and export: nil when the client can read and write aura strings.
function Caps.Codec()
    local codec = E.Codec
    if codec and codec.Available and codec.Available() then return nil end
    return Cap(UNAVAILABLE, (codec and codec.ERR_ENCODER) or "This client cannot read or write aura strings.")
end

-- The badges of a saved record. Texts, bar, glow and the low time colour follow the trigger.
function Caps.Of(conf)
    local record = E.Migrate(conf)
    if not record then return nil end
    local trigger = Caps.Trigger(record)
    return {
        trigger = trigger, display = trigger, sound = Caps.Sound(record, trigger), codec = Caps.Codec(),
        stacks = Caps.Stacks(record),
    }
end

-- Preview -------------------------------------------------------------------------------------------------------------

-- One frame for the editor, drawn with the readable parts and mock data: a timer that restarts every CYCLE seconds
-- and STACKS applications. Placed on the editor's host, never at the aura's screen point or in its group.
local Preview = {}
E.Preview = Preview

Preview.CYCLE = 20
Preview.STACKS = 3

local previewFrame

local function NoTimer(record)
    local src = record.sources and record.sources[1]
    return src ~= nil and (src.missing == true or (src.kind == "cooldown" and src.ready == true))
end

Preview.VALUE = 65
Preview.COUNT = 3

-- The mock answer at `now` for a preview started at `start`; nil for a trigger that shows without a timer. Values
-- (health, power) are 65 of 100; charges and items count Preview.COUNT.
function Preview.Data(record, now, start)
    local src = record.sources and record.sources[1]
    local kind = src and src.kind
    if kind == "health" or kind == "power" then
        return { value = Preview.VALUE, max = 100, percent = Preview.VALUE }
    end
    if kind == "state" or kind == "usable" then return nil end
    if kind == "item" and src.mode ~= "cooldown" then return { count = Preview.COUNT, value = Preview.COUNT } end
    if NoTimer(record) then return nil end
    local elapsed = (now - start) % Preview.CYCLE
    local data = { duration = Preview.CYCLE, expirationTime = now - elapsed + Preview.CYCLE, applications = Preview.STACKS }
    if kind == "charges" or kind == "item" then
        data.applications = nil
        data.count, data.value, data.max = Preview.COUNT, Preview.COUNT, Preview.COUNT + 1
    end
    return data
end

function Preview.Frame()
    if not previewFrame then
        previewFrame = E.Icon.Create("EditorPreview", nil, function() return false end)
    end
    return previewFrame
end

local function Copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

-- Draws `conf` on `host`; returns the frame, or nil (and hides it) without a host or a record.
function Preview.Show(host, conf, start)
    local record = E.Migrate(conf)
    if not (host and record) then
        Preview.Hide()
        return nil
    end
    local shown = Copy(record)
    shown.region = Copy(record.region)
    shown.region.point, shown.region.group = nil, nil

    local f = Preview.Frame()
    if E.Group then E.Group.Release(f) end
    if f.previewHost ~= host then
        f:SetParent(host)
        f:ClearAllPoints()
        f:SetPoint("CENTER", host, "CENTER", 0, 0)
        f.previewHost = host
    end
    local now = GetTime()
    local data = Preview.Data(shown, now, start or now)
    -- Every trigger counts as active, so the rules that ask for one show.
    local answers = { n = #(shown.sources or {}) }
    for i = 1, answers.n do answers[i] = true end
    local texture = E.IconTexture and E.IconTexture(shown, data, E.Icon.Texture) or E.Icon.Texture(E.IconSpell(shown))
    E.Icon.ShowReadable(f, shown, data, texture, answers)
    -- The loop plays as in game; the appearing one plays when the preview opens.
    if E.Anim then E.Anim.Shown(f, shown) end
    return f
end

-- Shows `conf` on `host` and keeps it redrawn four times a second while the host is shown; hiding the host hides it.
function Preview.Attach(host, conf)
    local start, waited = GetTime(), 0
    Preview.Show(host, conf, start)
    host:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + (elapsed or 0)
        if waited < 0.25 then return end
        waited = 0
        Preview.Show(self, conf, start)
    end)
    host:SetScript("OnHide", function(self) Preview.Hide(self) end)
end

-- Hides the frame; with `host`, only while it is on that host (an old page's host must not hide the new one's).
function Preview.Hide(host)
    if previewFrame and (host == nil or previewFrame.previewHost == host) then
        if E.Anim then E.Anim.Reset(previewFrame) end
        E.Icon.Hide(previewFrame)
    end
end

-- Class templates -----------------------------------------------------------------------------------------------------

-- Major cooldowns by client and class, as { cast spell ID or its ranks lowest first, role }. A template is a
-- cooldown shown while ready, in combat: readable there on both clients. Only spells the character knows are offered,
-- at the highest rank known. IDs and names checked against each client's SpellName table (Retail 12.1.5.70077,
-- Forever 1.60.1.70399) on 2026-11-09; Forever has no Death Knight, Monk, Demon Hunter or Evoker.
local Templates = {}
E.Templates = Templates

local D, O = "defensive", "offensive"
Templates.DATA = {
    retail = {
        WARRIOR = { { 871, D }, { 118038, D }, { 1719, O }, { 107574, O } },
        PALADIN = { { 642, D }, { 498, D }, { 31884, O } },
        HUNTER = { { 186265, D }, { 264735, D }, { 288613, O }, { 19574, O } },
        ROGUE = { { 31224, D }, { 5277, D }, { 13750, O }, { 121471, O } },
        PRIEST = { { 19236, D }, { 47585, D }, { 10060, O } },
        DEATHKNIGHT = { { 48792, D }, { 48707, D }, { 51271, O } },
        SHAMAN = { { 108271, D }, { 114050, O }, { 114051, O } },
        MAGE = { { 45438, D }, { 190319, O }, { 12472, O }, { 365350, O } },
        WARLOCK = { { 104773, D }, { 205180, O } },
        MONK = { { 115203, D }, { 122470, D }, { 137639, O } },
        DRUID = { { 22812, D }, { 61336, D }, { 106951, O }, { 194223, O } },
        DEMONHUNTER = { { 198589, D }, { 191427, O } },
        EVOKER = { { 363916, D }, { 375087, O } },
    },
    forever = {
        WARRIOR = { { 871, D }, { 20230, D }, { 1719, O }, { 12328, O } },
        PALADIN = { { { 642, 1020 }, D }, { { 498, 5573 }, D }, { { 633, 2800, 10310 }, D } },
        HUNTER = { { 5384, D }, { 19574, O }, { 3045, O } },
        ROGUE = { { 5277, D }, { 13750, O }, { 13877, O } },
        PRIEST = { { { 586, 9578, 9579, 9592, 10941, 10942 }, D }, { 10060, O }, { 14751, O } },
        -- 16166 is Lightning Mastery on Forever.
        SHAMAN = { { 16166, O }, { 16188, O } },
        MAGE = { { 11958, D }, { 12042, O }, { 11129, O }, { 12051, O } },
        WARLOCK = { { 18708, D }, { 18288, O } },
        DRUID = { { 22812, D }, { 29166, O }, { 17116, O } },
    },
}

-- Each template as { spellID = lowest rank, ranks = { ... }, role }.
function Templates.ForClass(client, class)
    local byClass = Templates.DATA[client]
    local out = {}
    for _, entry in ipairs((byClass and byClass[class]) or {}) do
        local ranks = type(entry[1]) == "table" and entry[1] or { entry[1] }
        out[#out + 1] = { spellID = ranks[1], ranks = ranks, role = entry[2] }
    end
    return out
end

local function PlayerKnows(id)
    local checks = { _G.IsPlayerSpell, C_SpellBook and C_SpellBook.IsSpellKnown, _G.IsSpellKnown }
    for i = 1, 3 do
        local fn = checks[i]
        if type(fn) == "function" then
            local ok, known = pcall(fn, id)
            if ok and known == true then return true end
        end
    end
    return false
end

-- The class's templates whose spell `isKnown` (default: the character knows it).
function Templates.Known(client, class, isKnown)
    isKnown = isKnown or PlayerKnows
    local out = {}
    for _, entry in ipairs(Templates.ForClass(client, class)) do
        for i = #entry.ranks, 1, -1 do
            local id = entry.ranks[i]
            if isKnown(id) then
                out[#out + 1] = { spellID = id, ranks = entry.ranks, role = entry.role }
                break
            end
        end
    end
    return out
end

function Templates.ForPlayer(isKnown)
    local class
    if type(UnitClass) == "function" then
        local _, token = UnitClass("player")
        class = token
    end
    local client = (E.Codec and E.Codec.Client()) or "retail"
    return Templates.Known(client, class, isKnown)
end

-- The client's name for the spell, in the player's language; nil when it has none.
function Templates.SpellName(id)
    local api = C_Spell
    if not (api and api.GetSpellName) then return nil end
    local ok, name = pcall(api.GetSpellName, id)
    if ok and not IsSecret(name) and type(name) == "string" and name ~= "" then return name end
    return nil
end

-- The saved (v0) fields of a template; offensive cooldowns glow.
function Templates.Record(entry)
    return {
        name = Templates.SpellName(entry.spellID) or ("Spell " .. tostring(entry.spellID)),
        triggerType = "COOLDOWN", triggerSpellID = entry.spellID, triggerCooldownReady = true,
        loadCombat = "IN_COMBAT", showGlow = entry.role == "offensive",
    }
end
