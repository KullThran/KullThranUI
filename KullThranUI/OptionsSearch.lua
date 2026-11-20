local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

-- Options search: one way to read text, match a query and rank the results,
-- shared by the menu search, the in-page highlight and the list filters.
local Search = {}
KT.OptionsSearch = Search

local find, gsub, lower, sub = string.find, string.gsub, string.lower, string.sub

-- Accented Latin letters (U+00C0..U+00FF) fold to their base letter, so a
-- query typed without accents still finds the accented text.
local LATIN = {
    ["\195\128"] = "a", ["\195\129"] = "a", ["\195\130"] = "a", ["\195\131"] = "a", ["\195\132"] = "a", ["\195\133"] = "a",
    ["\195\135"] = "c", ["\195\136"] = "e", ["\195\137"] = "e", ["\195\138"] = "e", ["\195\139"] = "e",
    ["\195\140"] = "i", ["\195\141"] = "i", ["\195\142"] = "i", ["\195\143"] = "i",
    ["\195\145"] = "n", ["\195\146"] = "o", ["\195\147"] = "o", ["\195\148"] = "o", ["\195\149"] = "o", ["\195\150"] = "o",
    ["\195\153"] = "u", ["\195\154"] = "u", ["\195\155"] = "u", ["\195\156"] = "u", ["\195\157"] = "y",
    ["\195\160"] = "a", ["\195\161"] = "a", ["\195\162"] = "a", ["\195\163"] = "a", ["\195\164"] = "a", ["\195\165"] = "a",
    ["\195\167"] = "c", ["\195\168"] = "e", ["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e",
    ["\195\172"] = "i", ["\195\173"] = "i", ["\195\174"] = "i", ["\195\175"] = "i",
    ["\195\177"] = "n", ["\195\178"] = "o", ["\195\179"] = "o", ["\195\180"] = "o", ["\195\181"] = "o", ["\195\182"] = "o",
    ["\195\185"] = "u", ["\195\186"] = "u", ["\195\187"] = "u", ["\195\188"] = "u", ["\195\189"] = "y", ["\195\191"] = "y",
}

-- Cyrillic capitals to lower case (string.lower only folds ASCII).
local function CyrillicLower(lead, byte)
    local b = byte:byte()
    if lead == "\208" then
        if b >= 0x90 and b <= 0x9F then return "\208" .. string.char(b + 0x20) end
        if b >= 0xA0 and b <= 0xAF then return "\209" .. string.char(b - 0x20) end
        if b == 0x81 then return "\209\145" end
    end
    return lead .. byte
end

local cache = {}
local cacheSize = 0

-- Lower case, accents folded, colour and texture codes removed, punctuation
-- turned into single spaces. Returns the words and the same text without spaces.
function Search.Normalize(text)
    if type(text) ~= "string" then return "", "" end
    local hit = cache[text]
    if hit then return hit[1], hit[2] end
    local s = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    s = gsub(s, "|r", "")
    s = gsub(s, "|T.-|t", " ")
    s = gsub(s, "|A.-|a", " ")
    s = gsub(s, "|n", " ")
    s = lower(s)
    s = gsub(s, "\195[\128-\191]", LATIN)
    s = gsub(s, "([\208])([\128-\191])", CyrillicLower)
    s = gsub(s, "[%p%s]+", " ")
    s = gsub(s, "^ ", "")
    s = gsub(s, " $", "")
    local compact = gsub(s, " ", "")
    if cacheSize > 20000 then cache, cacheSize = {}, 0 end
    cache[text] = { s, compact }
    cacheSize = cacheSize + 1
    return s, compact
end

-- A query read once: its words and its text without spaces. A query of
-- punctuation alone ("[", "+") is looked for as typed.
function Search.Query(text)
    local words, compact = Search.Normalize(text)
    local terms = {}
    for term in words:gmatch("%S+") do terms[#terms + 1] = term end
    local literal
    if compact == "" and type(text) == "string" then
        literal = lower(text):match("^%s*(.-)%s*$")
        if literal == "" then literal = nil end
    end
    return { words = words, compact = compact, terms = terms, literal = literal }
end

-- True when nothing was typed.
function Search.IsEmpty(query)
    return query.compact == "" and not query.literal
end

-- A word of the query starts a word of the text; three letters or more may
-- also sit inside one ("castbar" in "Cast Bar"). "2" does not find "12".
local function HasTerm(words, compact, term)
    if find(" " .. words, " " .. term, 1, true) then return true end
    return #term >= 3 and find(compact, term, 1, true) ~= nil
end

-- How well a text matches the whole query on its own: 4 same text, 3 starts
-- with it, 2 a word starts with it, 1 every word appears; nil no match.
-- Spaces do not matter: "castbar" and "cast bar" both find "Cast Bar".
function Search.Quality(query, text)
    if not query or Search.IsEmpty(query) then return nil end
    if query.literal then
        return type(text) == "string" and find(lower(text), query.literal, 1, true) and 1 or nil
    end
    local words, compact = Search.Normalize(text)
    if compact == "" then return nil end
    if compact == query.compact then return 4 end
    if sub(words, 1, #query.words) == query.words or sub(compact, 1, #query.compact) == query.compact then return 3 end
    if find(" " .. words, " " .. query.words, 1, true) then return 2 end
    if find(compact, query.compact, 1, true) then return 1 end
    for _, term in ipairs(query.terms) do
        if not HasTerm(words, compact, term) then return nil end
    end
    return 1
end

-- True when the text matches the query (every word, spaces ignored).
function Search.Matches(queryText, text)
    local query = type(queryText) == "table" and queryText or Search.Query(queryText)
    if Search.IsEmpty(query) then return true end
    return Search.Quality(query, text) ~= nil
end

-- Best quality over a list of texts (an English text and its translation).
local function BestQuality(query, texts)
    local best
    for _, text in ipairs(texts) do
        local q = Search.Quality(query, text)
        if q and (not best or q > best) then best = q end
    end
    return best
end

-- Every word in one of the texts, and at least one in the entry's own text:
-- "castbar height" finds Height on the Cast Bar page, but "castbar" alone
-- does not list every option of that page.
local function ContextMatch(query, ownTexts, contextTexts)
    local ownHit = false
    for _, term in ipairs(query.terms) do
        local found = false
        for _, text in ipairs(ownTexts) do
            local words, compact = Search.Normalize(text)
            if HasTerm(words, compact, term) then found, ownHit = true, true break end
        end
        if not found then
            for _, text in ipairs(contextTexts) do
                local words, compact = Search.Normalize(text)
                if HasTerm(words, compact, term) then found = true break end
            end
        end
        if not found then return false end
    end
    return ownHit
end

-- Modules first, then the views inside a module, then sections, options and
-- descriptions.
Search.KIND_RANK = { module = 0, view = 1, section = 2, option = 3, detail = 4 }

-- entries: { text, localized?, kind, pageId, pageLabel, pageLabelLocalized?,
--   viewLabel?, pageOrder, seq }. Returns the matching entries, best first.
function Search.Rank(entries, queryText, limit)
    local query = Search.Query(queryText)
    if Search.IsEmpty(query) then return {} end
    local scored = {}
    for _, entry in ipairs(entries) do
        local own = { entry.text, entry.localized }
        local quality = BestQuality(query, own)
        if not quality and entry.kind == "module" then
            quality = BestQuality(query, { entry.pageId })
        end
        if not quality and entry.kind ~= "module" and entry.kind ~= "view" then
            local context = { entry.pageLabel, entry.pageLabelLocalized, entry.viewLabel, entry.viewLabelLocalized }
            if #query.terms > 1 and ContextMatch(query, own, context) then quality = 0 end
        end
        if quality then
            scored[#scored + 1] = { entry = entry, quality = quality,
                kind = Search.KIND_RANK[entry.kind] or 4 }
        end
    end
    table.sort(scored, function(a, b)
        local aTop, bTop = a.kind <= 1, b.kind <= 1
        if aTop ~= bTop then return aTop end
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.kind ~= b.kind then return a.kind < b.kind end
        local ao, bo = a.entry.pageOrder or 1000, b.entry.pageOrder or 1000
        if ao ~= bo then return ao < bo end
        return (a.entry.seq or 0) < (b.entry.seq or 0)
    end)
    local results, seen = {}, {}
    for _, item in ipairs(scored) do
        local entry = item.entry
        local _, compact = Search.Normalize(entry.text)
        local key = (entry.pageId or "") .. "\031" .. (entry.view or "") .. "\031" .. compact
        if not seen[key] then
            seen[key] = true
            results[#results + 1] = entry
            if limit and #results >= limit then break end
        end
    end
    return results
end

-- Pages that build only the view on screen (a sub tab, a card) tell the
-- search how to build each one: list() returns the view ids, the one shown and
-- each view's title; set(id) makes a view the one the page builds next.
Search.views = Search.views or {}

function Search.RegisterViews(pageId, list, set)
    Search.views[pageId] = { list = list, set = set }
end

function Search.Views(pageId)
    return Search.views[pageId]
end

-- Display text a widget call carries, with its kind. Shared by the search
-- index and the in-page highlight so both read the same strings.
local TITLE_KEYS = { "text", "label", "title", "name" }
local DETAIL_KEYS = { "description", "subtitle", "tooltip", "tooltipText" }

local function AddText(out, value, kind)
    if type(value) == "string" and value ~= "" then out[#out + 1] = { text = value, kind = kind } end
end

local function AddFields(out, data, titleKind, detailKind)
    if type(data) ~= "table" then return end
    if titleKind then
        for _, key in ipairs(TITLE_KEYS) do AddText(out, rawget(data, key), titleKind) end
    end
    if detailKind then
        for _, key in ipairs(DETAIL_KEYS) do AddText(out, rawget(data, key), detailKind) end
    end
end

-- A dropdown's choices: the display strings, not the ids they are keyed by.
local function AddValues(out, values)
    if type(values) ~= "table" then return end
    for _, value in pairs(values) do
        if type(value) == "string" then AddText(out, value, "detail")
        elseif type(value) == "table" then AddFields(out, value, "detail", nil) end
    end
end

local function AddTabs(out, tabs)
    if type(tabs) ~= "table" then return end
    for _, tab in ipairs(tabs) do
        if type(tab) == "table" then AddText(out, tab.label or tab.text or tab.title, "section") end
    end
end

local function AddRow(out, data)
    if type(data) ~= "table" then return end
    AddText(out, data.text, "option")
    AddValues(out, data.values)
    AddFields(out, data, nil, "detail")
end

-- args: the call's arguments after the parent.
local WIDGET_TEXT = {
    SectionHeader = function(out, a) AddText(out, a[1], "section") end,
    Label = function(out, a) AddText(out, a[1], "detail") end,
    Toggle = function(out, a) AddText(out, a[1], "option") end,
    ColorSwatch = function(out, a) AddText(out, a[1], "option") end,
    ModeColorRow = function(out, a) AddText(out, a[1], "option") end,
    Button = function(out, a) AddText(out, a[1], "option") end,
    PillButton = function(out, a) AddText(out, a[1], "option"); AddFields(out, a[2], nil, "detail") end,
    CutButton = function(out, a) AddText(out, a[1], "option"); AddFields(out, a[2], nil, "detail") end,
    Slider = function(out, a) AddText(out, a[1], "option"); AddFields(out, a[9], nil, "detail") end,
    Dropdown = function(out, a) AddText(out, a[1], "option"); AddValues(out, a[3]) end,
    Input = function(out, a) AddText(out, a[1], "option"); AddFields(out, a[5], nil, "detail") end,
    MultiSwatch = function(out, a)
        AddText(out, a[1], "option")
        if type(a[3]) == "table" then
            for _, swatch in ipairs(a[3]) do AddFields(out, swatch, "detail", "detail") end
        end
    end,
    DualRow = function(out, a) AddRow(out, a[2]); AddRow(out, a[3]) end,
    SubTabBar = function(out, a) AddTabs(out, a[2]) end,
    PageTabs = function(out, a) AddTabs(out, a[1]) end,
    SegmentedTabs = function(out, a) AddTabs(out, a[1]) end,
    ModuleCard = function(out, a) AddFields(out, a[1], "section", "detail") end,
    FocusCard = function(out, a) AddFields(out, a[1], "section", "detail") end,
    StarHero = function(out, a) AddFields(out, a[1], "detail", "detail") end,
    InfoHint = function(out, a) AddFields(out, a[1], "detail", "detail") end,
    WheelSwitch = function(out, a) AddFields(out, a[3], "option", "detail") end,
}

function Search.WidgetTexts(method, ...)
    local reader = WIDGET_TEXT[method]
    local out = {}
    if reader then reader(out, { ... }) end
    return out
end
