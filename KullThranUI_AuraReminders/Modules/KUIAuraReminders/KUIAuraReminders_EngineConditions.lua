-- Custom aura engine, condition rules and text with values. Shared byte for byte between the Retail and Forever
-- workspaces.
--
-- A rule compares one reading of the shown aura (remaining time, stacks, value, percentage, count) or asks whether a
-- trigger is active, and while it holds it changes the look: a colour on the icon and the bar, a glow, a grey icon
-- or an opacity. Rules are read in order and a later one wins for the same property. A reading that is secret never
-- passes, so a rule never acts on a guess.
--
-- A text with values replaces tokens in the text the player writes:
--   %n name, %s stacks, %t remaining time, %v value, %m maximum, %p percentage, %c count (charges, items), %% a %.
-- A secret value is shown as the client formats it; it is never compared or computed with.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local IsSecret = E.IsSecret

-- Rules ---------------------------------------------------------------------------------------------------------------

local Conditions = {}
E.Conditions = Conditions

local function Reading(rule, data, remaining, answers)
    local check = rule.check
    if check == "remaining" then return remaining end
    if check == "stacks" then return E.Stacks and E.Stacks.Count(data) or nil end
    if type(data) ~= "table" or IsSecret(data) then return nil end
    if check == "value" then return data.value end
    if check == "percent" then return data.percent end
    if check == "count" then return data.count end
    return nil
end

-- Whether one rule holds now; false when its reading is unknown.
function Conditions.Holds(rule, data, remaining, answers)
    if rule.check == "trigger" then
        return answers ~= nil and answers[rule.trigger] == true
    end
    local value = Reading(rule, data, remaining, answers)
    -- A remaining time of 0 or less is no timer at all.
    if rule.check == "remaining" and (value == nil or value <= 0) then return false end
    return E.Compare(rule.op, value, rule.value) == true
end

-- The effects of the rules that hold: { color, glow, desaturate, alpha }, each nil when no rule sets it.
function Conditions.Effects(rules, data, remaining, answers)
    local out = {}
    for _, rule in ipairs(rules or {}) do
        if Conditions.Holds(rule, data, remaining, answers) then
            if rule.color then out.color = rule.color end
            if rule.glow then out.glow = true end
            if rule.desaturate then out.desaturate = true end
            if rule.alpha then out.alpha = rule.alpha end
        end
    end
    return out
end

-- Whether any rule reads the remaining time, which changes without an event.
function Conditions.Ticks(rules)
    for _, rule in ipairs(rules or {}) do
        if rule.check == "remaining" then return true end
    end
    return false
end

-- A text that changes the frame only when the effects change.
function Conditions.Key(effects)
    local c = effects.color
    return table.concat({
        c and c.r or "-", c and c.g or "-", c and c.b or "-", effects.glow and 1 or 0, effects.desaturate and 1 or 0,
        effects.alpha or "-",
    }, ",")
end

-- Text with values ----------------------------------------------------------------------------------------------------

local Text = {}
E.Text = Text

-- The remaining time in a short form: 1h, 3m, 42, 4.5.
function Text.Remaining(remain)
    if remain >= 3600 then
        return string.format("%dh", math.ceil(remain / 3600))
    elseif remain >= 60 then
        return string.format("%dm", math.ceil(remain / 60))
    elseif remain > 5 then
        return tostring(math.floor(remain))
    end
    return string.format("%.1f", remain)
end

local function Whole(value)
    if type(value) ~= "number" then return value end
    if value == math.floor(value) then return tostring(value) end
    return string.format("%.1f", value)
end

-- Whether the text has a token that changes with the time.
function Text.Ticks(template)
    return type(template) == "string" and template:find("%%t") ~= nil
end

-- The format string and its values for `template`. `ctx` = { name, data, remaining, remainingSecret }. Each token
-- becomes %s, or %.0f for a secret remaining time; any other % is kept as a literal.
function Text.Build(template, ctx)
    if type(template) ~= "string" then return "", {} end
    local data = ctx.data
    if type(data) ~= "table" or IsSecret(data) then data = {} end
    local args, secret = {}, false
    local function Add(value, spec)
        args[#args + 1] = value
        if IsSecret(value) then secret = true end
        return spec or "%s"
    end
    local out = template:gsub("%%(.?)", function(token)
        if token == "%" then return "%%" end
        if token == "n" then return Add(ctx.name or "") end
        if token == "s" then
            local text = data.applicationsText
            if IsSecret(text) or type(text) == "string" then return Add(text) end
            local count = E.Stacks and E.Stacks.Count(data)
            return Add(count and tostring(count) or "")
        end
        if token == "t" then
            local remain = ctx.remaining
            if remain == nil then return Add("") end
            if ctx.remainingSecret then return Add(remain, "%.0f") end
            return Add(remain > 0 and Text.Remaining(remain) or "")
        end
        if token == "v" then return Add(Whole(data.value) or "") end
        if token == "m" then return Add(Whole(data.max) or "") end
        if token == "p" then
            local percent = data.percent
            if type(percent) == "number" then return Add(string.format("%d", math.floor(percent + 0.5))) end
            return Add("")
        end
        if token == "c" then return Add(Whole(data.count) or "") end
        -- Not a token: the % and the character as written.
        return "%%" .. token
    end)
    return out, args, secret
end

-- Writes the text into `fontString`: as plain text when every value is readable, else through the client's
-- formatter, which takes secret values.
function Text.Render(fontString, template, ctx)
    local fmt, args, secret = Text.Build(template, ctx)
    if secret then
        fontString:SetFormattedText(fmt, unpack(args, 1, #args))
        return
    end
    local ok, text = pcall(string.format, fmt, unpack(args, 1, #args))
    fontString:SetText(ok and text or "")
end
