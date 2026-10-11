local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_Minimap/Modules/Minimap/Minimap.lua"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local a = assert(source:find("local SIDE_ICON_STEP = 22", 1, true))
local b = assert(source:find("function Mod:ApplyElementOffsets()", a, true))

local function Button()
    local o = { shown = true, hooks = {} }
    function o:ClearAllPoints() self.point = nil end
    function o:SetPoint(...) self.point = { ... } end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:HookScript(_, fn) self.hooks[#self.hooks + 1] = fn end
    return o
end

local holder = {}
local teleport = Button()
local Mod = { db = {}, guildMinimapButton = Button(), friendsMinimapButton = Button(), kuiSettingsButton = Button() }
function Mod:DeferProtectedLayout() return false end
local env = setmetatable({
    Mod = Mod, holder = holder, ipairs = ipairs,
    LibStub = function() return { GetMinimapButton = function() return teleport end } end,
    _G = {},
}, { __index = _G })
local chunk = assert(loadstring(source:sub(a, b - 1)))
setfenv(chunk, env)
chunk()

local function Place(position, db)
    Mod.db = db
    Mod.db.iconPosition = position
    Mod:LayoutSideIcons()
end
local all = { showTeleportIcon = true, showGuildIcon = true, showFriendsIcon = true, showKUISettingsIcon = true }

Place("LEFT", all)
assert(teleport.point[1] == "BOTTOMRIGHT" and teleport.point[3] == "BOTTOMLEFT" and teleport.point[5] == 0)
assert(Mod.guildMinimapButton.point[5] == 22 and Mod.friendsMinimapButton.point[5] == 44 and Mod.kuiSettingsButton.point[5] == 66)

Place("RIGHT", all)
assert(teleport.point[1] == "BOTTOMLEFT" and teleport.point[3] == "BOTTOMRIGHT" and Mod.kuiSettingsButton.point[5] == 66)

Place("TOP", all)
assert(teleport.point[1] == "BOTTOMLEFT" and teleport.point[3] == "TOPLEFT" and Mod.friendsMinimapButton.point[4] == 44)

Place("BOTTOM", all)
assert(teleport.point[1] == "TOPLEFT" and teleport.point[3] == "BOTTOMLEFT" and Mod.guildMinimapButton.point[4] == 22)

-- A hidden icon leaves no gap and stays hidden even if its owner shows it again.
Place("LEFT", { showTeleportIcon = false, showGuildIcon = true, showFriendsIcon = true, showKUISettingsIcon = false })
assert(teleport.shown == false and Mod.kuiSettingsButton.shown == false)
assert(Mod.guildMinimapButton.point[5] == 0 and Mod.friendsMinimapButton.point[5] == 22)
teleport.shown = true
for _, hook in ipairs(teleport.hooks) do hook(teleport) end
assert(teleport.shown == false, "a re-shown disabled icon must be hidden again")
print("PASS: minimap side icons stack on every side, skip hidden icons and keep them hidden")
