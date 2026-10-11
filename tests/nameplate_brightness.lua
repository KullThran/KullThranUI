local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua"))
local source = f:read("*a"); f:close()
local style = "kui"
local env = setmetatable({ ns = { NameplateStyle = function() return style end } }, { __index = _G })
local function extract(first, last, name)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a, true))
    local chunk = assert(loadstring(source:sub(a, b - 1) .. "\nreturn " .. name))
    setfenv(chunk, env)
    return chunk()
end
local darken = extract("local function DarkenColor", "-- Cached threat-context state.", "DarkenColor")
local brighten = extract("local function BrightenNameplateColor", "function NameplateFrame:UpdateHealthColor", "BrightenNameplateColor")
local function near(a, b) assert(math.abs(a-b) < 0.000001, tostring(a) .. " != " .. tostring(b)) end
-- The idle enemy/caster/miniboss branches all share this resolver.
for _, color in ipairs({{0.85,0.1,0.1}, {1,0.34,0.2}, {0.3,0.7,1}}) do
    local r,g,b = darken(unpack(color))
    near(r,color[1]*0.85); near(g,color[2]*0.85); near(b,color[3]*0.85)
    local idle = brighten(r,g,b)
    local combat = brighten(unpack(color))
    local previousIdle = brighten(color[1]*0.6, color[2]*0.6, color[3]*0.6)
    assert(idle <= combat and idle > previousIdle, "readable idle color")
end
for _, theme in ipairs({"classic", "forever", "retail"}) do
    style = theme
    local r,g,b = darken(0.8,0.4,0.2)
    near(r,0.8); near(g,0.4); near(b,0.2)
    r,g,b=brighten(0.39,0.11,0.09)
    assert(math.max(r,g,b)>=0.75,"group no-aggro colour must remain readable")
end
style = "kui"
local r,g,b = darken(0.8,0.4,0.2,0.5)
near(r,0.4); near(g,0.2); near(b,0.1)
r,g,b = brighten(1,1,1)
near(r,1); near(g,1); near(b,1)
print("nameplate KUI brightness checks passed")
