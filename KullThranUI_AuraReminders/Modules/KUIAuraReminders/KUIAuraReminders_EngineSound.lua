-- Custom aura engine, sounds. A record can play a sound when it starts and when it stops. Readable answers play it on
-- their own transitions; an aura the client's engine can show gets its sounds registered with the client
-- (C_UnitAuras.AddAuraSound), which also hears auras that are secret. Shared byte for byte between the Retail and
-- Forever workspaces.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local Sound = {}
E.Sound = Sound

local function Media()
    local stub = LibStub
    if stub == nil then return nil end
    local ok, lsm = pcall(stub, "LibSharedMedia-3.0", true)
    if ok then return lsm end
    return nil
end

-- The names offered by the options, sorted; empty without LibSharedMedia.
function Sound.List()
    local lsm = Media()
    if not (lsm and lsm.List) then return {} end
    local ok, list = pcall(lsm.List, lsm, "sound")
    return (ok and type(list) == "table") and list or {}
end

-- The file of a sound name: a path or a file ID; nil for none or an unknown name.
function Sound.Resolve(name)
    if name == nil or name == "" or name == "None" then return nil end
    if type(name) == "number" then return name end
    local lsm = Media()
    if lsm and lsm.Fetch then
        local ok, file = pcall(lsm.Fetch, lsm, "sound", name, true)
        if ok and file ~= nil and file ~= "" then return file end
    end
    return nil
end

function Sound.Play(name, channel)
    local file = Sound.Resolve(name)
    if file == nil or type(PlaySoundFile) ~= "function" then return end
    pcall(PlaySoundFile, file, channel or "Master")
end

-- Readable transitions. `state` is the answer while the record is loaded; nil when it is not loaded, not known or
-- delegated. Only a change between two known answers plays, so the first pass and a load change are silent.
function Sound.Transition(f, record, state)
    local previous = f.soundState
    f.soundState = state
    if f.engineSoundIDs or previous == nil or state == nil or previous == state then return end
    local sound = record and record.sound
    if not sound then return end
    if state then Sound.Play(sound.applied, sound.channel) else Sound.Play(sound.removed, sound.channel) end
end

-- Engine sounds -------------------------------------------------------------------------------------------------------

-- Whether the client can play this record's sounds: a delegable aura source cast by anyone, a sound set and no combat
-- load condition. Registrations change only out of combat, so they could not follow that condition.
function Sound.EngineEligible(record, src)
    if not src or src.caster == "player" then return false end
    local sound = record.sound
    if not sound or (sound.applied == nil and sound.removed == nil) then return false end
    local combat = record.load and record.load.combat
    return combat == nil or combat == "ANY"
end

local function Clear(f)
    local ids = f.engineSoundIDs
    local api = C_UnitAuras
    if ids and api and api.RemoveAuraSound then
        for _, id in ipairs(ids) do pcall(api.RemoveAuraSound, id) end
    end
    f.engineSoundIDs, f.engineSoundSignature = nil, nil
end

-- Keeps the registrations in line with `spec` (Sources.aura.SlotSpec), or none when `spec` is nil. Changes wait while
-- in combat; a refused registration is tried again on the next pass out of combat.
function Sound.SyncEngine(f, record, spec, inCombat)
    local signature
    if spec and record and record.sound then
        local s = record.sound
        signature = table.concat({ spec.signature, tostring(s.applied), tostring(s.removed), tostring(s.channel) }, "|")
    end
    if signature == f.engineSoundSignature then return end
    if inCombat then return end
    Clear(f)

    local api = C_UnitAuras
    if not signature or not (api and api.AddAuraSound) then return end
    local triggers = Enum and Enum.UnitAuraSoundTrigger
    local s = record.sound
    local wanted = {
        { trigger = (triggers and triggers.Added) or 0, file = Sound.Resolve(s.applied) },
        { trigger = (triggers and triggers.Removed) or 2, file = Sound.Resolve(s.removed) },
    }
    local ids, refused = {}, false
    for _, spellID in ipairs(spec.spells or {}) do
        for _, entry in ipairs(wanted) do
            if entry.file ~= nil then
                local info = { unitToken = spec.unit, spellID = spellID, outputChannel = s.channel or "Master" }
                if type(entry.file) == "number" then info.soundFileID = entry.file else info.soundFileName = entry.file end
                local ok, id = pcall(api.AddAuraSound, entry.trigger, info)
                if ok and id ~= nil then ids[#ids + 1] = id else refused = true end
            end
        end
    end
    f.engineSoundIDs = (#ids > 0) and ids or nil
    if not refused then f.engineSoundSignature = signature end
end

-- Drops every registration of a frame (deleted aura). Waits while in combat.
function Sound.ClearEngine(f, inCombat)
    if f.engineSoundIDs and not inCombat then Clear(f) end
end
