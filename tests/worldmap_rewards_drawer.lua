-- World map quest details: the rewards drawer is drawn over the scrolling quest
-- text, so its backdrop must stay opaque or the story text bleeds through
-- "Rewards" and the reward list.
local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path)); local s = f:read("*a"); f:close(); return s
end

local src = read("KullThranUI_Skins/Modules/Skins/WorldMap.lua")
local s, e = src:find("RewardsFrameContainer.RewardsFrame then", 1, true)
assert(s, "rewards drawer skin block not found")
local block = src:sub(e, (src:find("\n        end\n", e, true)) or #src)

assert(not block:find("SetBackdropColor%(0, 0, 0, 0%.%d+%)"),
    "rewards drawer backdrop must not be translucent")
assert(block:find("RegisterBlizzardWindowBackground", 1, true),
    "rewards drawer backdrop should follow the window background colour")
assert(block:find("color%[3%], 1%)"),
    "rewards drawer backdrop should force full opacity")

print("worldmap_rewards_drawer: ok")
