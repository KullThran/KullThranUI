local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI/Modules/Profiles.lua"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()

local function Table(startMarker)
    local a = assert(source:find(startMarker, 1, true), startMarker)
    local b = assert(source:find("\n}\n", a, true))
    local chunk = assert(loadstring("return " .. source:sub(a + #startMarker - 1, b + 1)))
    return chunk()
end
local defs = Table("local MODULE_DEFS = {")
local scopes = Table("local PAGE_PROFILE_SCOPES = {")

local byID, owners = {}, {}
for _, def in ipairs(defs) do
    assert(not byID[def.id], "duplicate module id " .. def.id)
    byID[def.id] = def
    for _, key in ipairs(def.keys or {}) do
        assert(not owners[key], key .. " is owned by both " .. tostring(owners[key]) .. " and " .. def.id)
        owners[key] = def.id
    end
end

-- Every page scope points at a real module.
for page, ids in pairs(scopes) do
    for _, id in ipairs(ids) do assert(byID[id], "page " .. page .. " uses unknown module " .. id) end
end

-- A child profile nested in Enhancements must be left out of the Enhancements module itself,
-- otherwise one setting travels in two exports.
local parent = byID.enhancements
for _, def in ipairs(defs) do
    for rootKey, children in pairs(def.nested or {}) do
        if rootKey == "enhancements" and def.id ~= "enhancements" then
            for _, child in ipairs(children) do
                assert(parent.omit and parent.omit.enhancements and parent.omit.enhancements[child],
                    def.id .. ": " .. child .. " must be omitted from the Enhancements module")
            end
            local listed = false
            for _, id in ipairs(scopes.enhancements or {}) do if id == def.id then listed = true end end
            assert(listed, def.id .. " must be part of the Enhancements page scope")
            assert(scopes[def.id], def.id .. " needs its own page scope for its profile tools")
        end
    end
end

-- Forever: the Debuff Tracker and the Dungeon Timer have their own profile.
if byID.debufftracker then
    assert(byID.debufftracker.foreverOnly, "Debuff Tracker only exists on Forever")
    assert(byID.mythicplustimer.forever ~= false and byID.mythicplustimer.foreverLabel, "Dungeon Timer profile must be available on Forever")
    local general = byID.general
    local hasWindowMove = false
    for _, key in ipairs(general.keys) do if key == "foreverWindowMove" then hasWindowMove = true end end
    assert(hasWindowMove, "General must carry the Forever window move settings")
end
print("PASS: profile definitions have unique owners, valid page scopes and complete Enhancements children")
