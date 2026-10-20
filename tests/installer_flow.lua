-- Installer flow: the Next chain visits every step exactly once in the order
-- of INSTALLER_STEP_ORDER, Previous mirrors Next, the scale/positions step
-- sits right after Language, and the animated button assets are in place.
-- Usage: lua installer_flow.lua <workspace root>
local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path, "rb")); local s = f:read("*a"); f:close(); return (s:gsub("\r\n", "\n"))
end

local src = read("KullThranUI_Installer/Modules/Installers/Installers.lua")

local NL = "\n"
local function firstMatch(body, patterns)
    for _, pattern in ipairs(patterns) do
        local found = body:match(pattern)
        if found then return found end
    end
end

-- Split into step functions (a function runs until the next top-level "function").
local steps, byName = {}, {}
local function finishEntry(entry)
    if not entry then return end
    local body = table.concat(entry.lines, NL)
    entry.body = body
    entry.id = tonumber(body:match("installer%.step = (%d+)"))
        or (body:match("step = STEP_PROFILE") and tonumber(src:match("local STEP_PROFILE = (%d+)")))
        or tonumber(body:match("step = (%d+),"))
    entry.next = firstMatch(body, {
        'btnNext:SetScript%("OnClick", function%(%)[^\n]-self:(Show%u%w-Step)%(%)',
        'btnNext:SetScript%("OnClick", function%(%)%s*self:(Show%u%w-Step)%(%)',
        "next = function%(%) self:(Show%u%w-Step)%(%)",
    })
    entry.back = firstMatch(body, {
        'btnBack:SetScript%("OnClick", function%(%)[^\n]-self:(Show%u%w-Step)%(%)',
        'btnBack:SetScript%("OnClick", function%(%)%s*self:(Show%u%w-Step)%(%)',
        "back = function%(%) self:(Show%u%w-Step)%(%)",
    })
    steps[#steps + 1] = entry
    byName[entry.name] = entry
end
local currentEntry
for line in (src .. NL):gmatch("([^\n]*)\n") do
    local name = line:match("^function Mod:(Show%u%w-Step)%(")
    if name or line:match("^function ") then
        finishEntry(currentEntry)
        currentEntry = name and { name = name, lines = {} } or nil
    elseif currentEntry then
        currentEntry.lines[#currentEntry.lines + 1] = line
    end
end
finishEntry(currentEntry)

local orderText = assert(src:match("local INSTALLER_STEP_ORDER = (%b{})"), "INSTALLER_STEP_ORDER missing")
local order = {}
for id in orderText:gmatch("%d+") do order[#order + 1] = tonumber(id) end

local failures = 0
local function check(cond, msg)
    if not cond then failures = failures + 1; print("FAIL: " .. msg) end
end

-- Walk Welcome -> ... following Next.
local seen, chain, current = {}, {}, byName.ShowWelcomeStep
while current and not seen[current.name] do
    seen[current.name] = true
    chain[#chain + 1] = current
    current = current.next and byName[current.next]
end

check(#chain == #order, ("Next chain has %d steps, order lists %d"):format(#chain, #order))
for index, entry in ipairs(chain) do
    check(entry.id == order[index], ("position %d: %s has id %s, order says %s"):format(index, entry.name, tostring(entry.id), tostring(order[index])))
    local nextEntry = chain[index + 1]
    if nextEntry then
        check(nextEntry.back == entry.name, ("%s Previous goes to %s, expected %s"):format(nextEntry.name, tostring(nextEntry.back), entry.name))
    end
end

-- Scale and positions step directly follows Language.
local languageIndex, profileIndex
for index, entry in ipairs(chain) do
    if entry.name == "ShowLanguageStep" then languageIndex = index end
    if entry.name == "ShowProfileStep" then profileIndex = index end
end
check(languageIndex and profileIndex == languageIndex + 1, "ShowProfileStep must directly follow ShowLanguageStep")

-- Every popup must be raised over the installer and reloads must resume.
check(src:find('hooksecurefunc("StaticPopup_Show"', 1, true), "StaticPopup_Show hook missing")
check(src:find('hooksecurefunc("ReloadUI"', 1, true), "ReloadUI resume hook missing")
check(src:find("AttachButtonSweep(btn)", 1, true), "SkinButton does not attach the sweep animation")

-- The scale step must never touch the user's scale or positions on open.
local profileBody = byName.ShowProfileStep and byName.ShowProfileStep.body or ""
check(profileBody:find("silent = true", 1, true), "scale is not applied silently")
check(not profileBody:find("ApplyScaleOnly(res)", 1, true), "scale applied without the silent flag")

local texture = io.open(root .. "/KullThranUI/Libraries/KUITextures/SweepEdge.tga", "rb")
check(texture, "SweepEdge.tga missing")
if texture then texture:close() end


-- Phase 3: Resource Bars live inside the Cooldown Manager page, the Damage Meter
-- preview shows five members and only classes the client has, Forever has a
-- Dungeon Timer page instead of a Mythic+ Timer one.
check(not byName.ShowResourceBarsStep, "stand-alone Resource Bars page still exists")
check(byName.ShowCooldownManagerStep and byName.ShowCooldownManagerStep.body:find("Resource Bars", 1, true), "Cooldown Manager page lacks the Resource Bars switch")
check(src:find("GetRandomInstallerDamageHeroes(4, playerClassToken)", 1, true), "Damage Meter preview must list the player plus four members")
check(src:find("IsInstallerClassAvailable(hero.classToken)", 1, true), "Damage Meter heroes are not filtered by client classes")
if src:find("INSTALLER_FOREVER_MISSING_CLASSES", 1, true) and byName.ShowDungeonTimerStep then
    check(not byName.ShowMythicPlusTimerStep, "Forever must not keep a Mythic+ Timer page")
end

if failures > 0 then os.exit(1) end
print(("installer_flow: ok (%d steps)"):format(#chain))
