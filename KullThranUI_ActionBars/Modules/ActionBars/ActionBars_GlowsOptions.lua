-- Modules/ActionBars/ActionBars_GlowsOptions.lua
-- The "Glows" tab of the Action Bars page: the look of each kind of glow and
-- of each spell (ActionBars_Glows.lua). Shared byte for byte between the
-- Retail and Forever workspaces; ActionBars_Options.lua calls
-- ns.BuildActionBarGlowsOptions.
local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local function LText(text)
    local Opt = KT.Options
    return Opt and Opt.LText and Opt.LText(text) or text
end

local KIND_INFO = {
    proc = {
        title = "Proc Glows",
        hint = "The glow of a spell alert (a proc). Blizzard (unchanged) keeps the game's own art.",
    },
    usable = {
        title = "Usable Spells",
        hint = "Tracked spells glow while they can be cast and are off cooldown (Overpower, Riposte, Execute...).",
    },
    cooldown = {
        title = "Cooldown Ready",
        hint = "Tracked spells glow for a moment when their cooldown comes back.",
    },
}

-- Which kind and spell the "Spells" section edits; kept across page rebuilds.
local selectedKind = "cooldown"
local selectedSpell

local function GetMod()
    return KT:GetModule("ActionBars", true)
end

local function Refresh(rebuild)
    local M = GetMod()
    if M and M.RefreshGlows then M:RefreshGlows() end
    if rebuild and KT.RefreshPage then KT:RefreshPage() end
end

local function SpellLabel(id)
    local name = ns.ABGlowSpellName and ns.ABGlowSpellName(id) or nil
    local icon = ns.ABGlowSpellIcon and ns.ABGlowSpellIcon(id) or nil
    local text = (name or LText("Unknown spell")) .. " (" .. tostring(id) .. ")"
    return icon and ("|T" .. tostring(icon) .. ":14:14:0:0|t " .. text) or text
end

local function ColorGetter(color)
    return function()
        local c = color()
        return c.r or 1, c.g or 1, c.b or 1
    end
end

function ns.BuildActionBarGlowsOptions(sc, W, y)
    local M = GetMod()
    local db = M and M.GetGlowsDB and M:GetGlowsDB()
    local h
    if not db then
        _, h = W:Label(sc, "Action Bars is disabled.", -y, 11); y = y + h
        return y
    end

    _, h = W:SectionHeader(sc, "Glows", -y); y = y + h
    _, h = W:Label(sc, "Pick the look of every glow on your action bars. Each spell can override the look of its kind.", -y, 11); y = y + h
    _, h = W:Toggle(sc, "Enable Glows", -y,
        function() return db.enable ~= false end,
        function(v) db.enable = v; Refresh(true) end); y = y + h
    if KT.CDMGlowEngine == nil then
        _, h = W:Label(sc, "Enable the Cooldown Manager addon for every glow style; without it only a few remain.", -y, 11); y = y + h
    end
    if db.enable == false then return y end

    for _, kind in ipairs(ns.AB_GLOW_KINDS) do
        local k = db.kinds[kind]
        local info = KIND_INFO[kind]
        _, h = W:SectionHeader(sc, info.title, -y); y = y + h
        _, h = W:Label(sc, info.hint, -y, 11); y = y + h
        _, h = W:Toggle(sc, "Enabled", -y,
            function() return k.enabled ~= false end,
            function(v) k.enabled = v; Refresh(true) end); y = y + h
        if k.enabled ~= false then
            local values, order = ns.ABGlowStyleChoices(nil, kind == "proc", false)
            _, h = W:Dropdown(sc, "Style", -y, values,
                function() return k.style end,
                function(v) k.style = v; Refresh(true) end, order); y = y + h
            if not (kind == "proc" and k.style == "native") then
                _, h = W:ColorSwatch(sc, "Color", -y, ColorGetter(function() return k.color end),
                    function(r, g, b) k.color = { r = r, g = g, b = b }; Refresh() end); y = y + h
                _, h = W:Slider(sc, "Opacity", -y,
                    function() return k.opacity or 100 end,
                    function(v) k.opacity = v; Refresh() end, 10, 100, 5); y = y + h
            end
            if kind == "cooldown" then
                local secondsValues, secondsOrder = {}, {}
                for _, seconds in ipairs(ns.AB_GLOW_COOLDOWN_SECONDS) do
                    secondsValues[seconds] = seconds == 0 and LText("Until it is cast") or (seconds .. " s")
                    secondsOrder[#secondsOrder + 1] = seconds
                end
                _, h = W:Dropdown(sc, "Glow Duration", -y, secondsValues,
                    function() return db.cooldownSeconds end,
                    function(v) db.cooldownSeconds = tonumber(v) or 3; Refresh() end, secondsOrder); y = y + h
                _, h = W:Toggle(sc, "Only In Combat", -y,
                    function() return db.cooldownInCombatOnly ~= false end,
                    function(v) db.cooldownInCombatOnly = v; Refresh() end); y = y + h
                _, h = W:Toggle(sc, "Also When A Fight Starts", -y,
                    function() return db.cooldownAtFightStart == true end,
                    function(v) db.cooldownAtFightStart = v; Refresh() end); y = y + h
            end
        end
    end

    -- Spells -------------------------------------------------------------
    _, h = W:SectionHeader(sc, "Spells", -y); y = y + h
    _, h = W:Label(sc, "Your class's spells are already listed. Add any other by name or spell ID, then give it its own look.", -y, 11); y = y + h

    local kindValues, kindOrder = {}, {}
    for _, kind in ipairs(ns.AB_GLOW_KINDS) do
        kindValues[kind] = LText(KIND_INFO[kind].title)
        kindOrder[#kindOrder + 1] = kind
    end
    _, h = W:Dropdown(sc, "Kind", -y, kindValues,
        function() return selectedKind end,
        function(v) selectedKind = v; selectedSpell = nil; Refresh(true) end, kindOrder); y = y + h

    _, h = W:Input(sc, "Add Spell (name or ID)", -y,
        function() return "" end,
        function(text)
            if text == "" then return end
            local id = ns.ABGlowResolveSpell(text)
            if not id then
                KT:Print(LText("Spell not found: ") .. text)
                return
            end
            if M:AddGlowSpell(selectedKind, id) then
                selectedSpell = id
            else
                KT:Print(LText("That spell is already in the list."))
            end
            Refresh(true)
        end); y = y + h

    local list = M:GetGlowSpellList(selectedKind)
    if #list == 0 then
        _, h = W:Label(sc, "No spells for this kind yet.", -y, 11); y = y + h
        return y
    end
    local spellValues, spellOrder, selectedEntry = {}, {}, nil
    for _, entry in ipairs(list) do
        spellValues[entry.id] = SpellLabel(entry.id)
        spellOrder[#spellOrder + 1] = entry.id
        if entry.id == selectedSpell then selectedEntry = entry end
    end
    if not selectedEntry then
        selectedEntry = list[1]
        selectedSpell = selectedEntry.id
    end
    _, h = W:Dropdown(sc, "Spell", -y, spellValues,
        function() return selectedSpell end,
        function(v) selectedSpell = tonumber(v); Refresh(true) end, spellOrder); y = y + h

    local key = ns.ABGlowSpellKey(selectedKind, selectedSpell)
    local function Override(create)
        local o = db.spells[key]
        if not o and create then
            o = {}
            db.spells[key] = o
        end
        return o
    end
    local function Clean()
        local o = db.spells[key]
        if o and next(o) == nil then db.spells[key] = nil end
    end
    local function Look() return M:GetGlowLook(selectedKind, selectedSpell) end

    _, h = W:Toggle(sc, "Glow This Spell", -y,
        function() local o = Override(); return not (o and o.off) end,
        function(v) Override(true).off = (not v) or nil; Clean(); Refresh(true) end); y = y + h

    local styleValues, styleOrder = ns.ABGlowStyleChoices(nil, selectedKind == "proc", true)
    _, h = W:Dropdown(sc, "Style", -y, styleValues,
        function() local o = Override(); return (o and o.style) or "inherit" end,
        function(v)
            Override(true).style = (v ~= "inherit") and v or nil
            Clean(); Refresh(true)
        end, styleOrder); y = y + h

    _, h = W:Toggle(sc, "Own Color", -y,
        function() local o = Override(); return o and o.color ~= nil end,
        function(v)
            local look = Look()
            Override(true).color = v and { r = look.r, g = look.g, b = look.b } or nil
            Clean(); Refresh(true)
        end); y = y + h
    local o = Override()
    if o and o.color then
        _, h = W:ColorSwatch(sc, "Color", -y, ColorGetter(function() return Override().color end),
            function(r, g, b) Override(true).color = { r = r, g = g, b = b }; Refresh() end); y = y + h
    end
    _, h = W:Slider(sc, "Opacity", -y,
        function() return Look().opacity end,
        function(v) Override(true).opacity = v; Refresh() end, 10, 100, 5); y = y + h

    _, h = W:Button(sc, "Reset Spell Look", -y, function()
        db.spells[key] = nil
        Refresh(true)
    end); y = y + h
    if selectedEntry.isCustom then
        _, h = W:Button(sc, "Remove Spell", -y, function()
            M:RemoveGlowSpell(selectedKind, selectedSpell)
            selectedSpell = nil
            Refresh(true)
        end); y = y + h
    end
    return y
end
