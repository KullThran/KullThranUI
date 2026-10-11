local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI/Modules/VisualThemes/ThemeEngine.lua"))
local source = f:read("*a"); f:close()
local a = assert(source:find("function KT.VisualThemes:ResetComboDefaults()", 1, true))
local b = assert(source:find("    -- Minimap:", a, true))
local KT = {db = {profile = {}}, VisualThemes = {}}
local profile, theme, seeds = nil, nil, 0
local adapter = {
 getProfile = function() return profile end,
 getOwnedPaths = function() return {"healthBarTexture", "castBarTexture", "friendlyPlayerHealthTexture", "borderColor", "classPowerShape", "enemyInCombat"} end,
 seed = function() seeds = seeds + 1; error("reset must not replace a restored theme slot") end,
 validate = function() end,
}
function KT.VisualThemes:GetModuleAdapter(key) assert(key == "nameplates"); return adapter end
function KT.VisualThemes:EnsureInitialized() return KT.db.profile, {active = theme} end
function KT.VisualThemes:LoadSlot() return nil end
local env = setmetatable({KT = KT}, {__index = _G})
local chunk = assert(loadstring(source:sub(a, b - 1) .. "end")); setfenv(chunk, env); chunk()
for _, key in ipairs({"classic", "retail", "forever", "kui"}) do
 theme = key
 profile = {healthBarTexture = key .. " custom health", castBarTexture = key .. " custom cast",
  friendlyPlayerHealthTexture = "friendly custom", healthBarWidth = 321,
  borderColor = {r = .123}, classPowerShape = "diamond", enemyInCombat = {r = .45}}
 _G.KullThranUINameplatesDB = profile; _G.KullThranUINameplatesDB_Forever = profile
 for n = 1, 3 do KT.VisualThemes:ResetComboDefaults() end
 assert(profile.healthBarTexture == key .. " custom health")
 assert(profile.castBarTexture == key .. " custom cast")
 assert(profile.friendlyPlayerHealthTexture == "friendly custom")
 assert(profile.borderColor.r == .123 and profile.enemyInCombat.r == .45)
 assert(profile.classPowerShape == "diamond")
 if key ~= "kui" then assert(profile.healthBarWidth == nil and profile.classPowerPos == "bottom") end
end
assert(seeds == 0)
print("PASS: layout reset preserves restored textures/colors/shape for all four theme slots")
