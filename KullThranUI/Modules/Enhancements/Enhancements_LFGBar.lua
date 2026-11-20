-------------------------------------------------------------------------------
--  Premade Groups helpers (Retail workspace only).
--
--  1. A bar under the search box, in the Dungeons category, with
--       [friends]  [X]  [one icon per dungeon of the current season]
--     - dungeon icons toggle that dungeon in the client's own advanced filter
--       (the same one the Filters dropdown edits) and search again;
--     - X resets the whole advanced filter, like the Filters dropdown's reset;
--     - friends keeps only the groups that contain a Battle.net friend, a
--       character friend or a guild mate.
--  2. Search results show each member's SPECIALIZATION icon instead of the
--     class-coloured circle (setting `lfgBar.specIcons`, on by default).
--
--  Everything is attached through post-hooks (hooksecurefunc) so Blizzard's own
--  secure code never runs through ours, and nothing is touched in combat.
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then return end

local floor, max, min = math.floor, math.max, math.min
local CreateFrame = _G.CreateFrame
local DUNGEONS_CATEGORY = 2
local BAR_HEIGHT, BAR_GAP = 28, 4

local function Config()
    local db = Mod.GetDB and Mod:GetDB() or nil
    if not db then return { enable = true, specIcons = true } end
    db.lfgBar = db.lfgBar or {}
    if db.lfgBar.enable == nil then db.lfgBar.enable = true end
    if db.lfgBar.specIcons == nil then db.lfgBar.specIcons = true end
    -- The spec icons replace the class-coloured bars the skin draws under the role icons:
    -- turn those off once (the user can switch them back on in Enhancements).
    if not db.lfgBar.classBarsOffV1 then
        db.lfgBar.classBarsOffV1 = true
        db.visibility = db.visibility or {}
        db.visibility.showLFGClassBars = false
        local skins = KT.GetModule and KT:GetModule("Skins", true)
        if skins and skins.RefreshLFGClassBars then pcall(skins.RefreshLFGClassBars, skins) end
    end
    return db.lfgBar
end

local state = { friendsOnly = false }
local bar

local function Accent()
    return KT.C_R or 0.2, KT.C_G or 0.9, KT.C_B or 0.6
end

-------------------------------------------------------------------------------
--  Data: this season's dungeons and the advanced filter
-------------------------------------------------------------------------------
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function FilterBits(...)
    local bits = 0
    for i = 1, select("#", ...) do bits = bit.bor(bits, (select(i, ...)) or 0) end
    return bits
end

local function ActivityGroups(seasonOnly)
    local LFG, Filter = _G.C_LFGList, _G.Enum and _G.Enum.LFGListFilter
    if not (LFG and LFG.GetAvailableActivityGroups and Filter) then return {} end
    local filter = seasonOnly
        and FilterBits(Filter.CurrentSeason, Filter.PvE)
        or FilterBits(Filter.CurrentExpansion, Filter.NotCurrentSeason, Filter.PvE)
    return SafeCall(LFG.GetAvailableActivityGroups, DUNGEONS_CATEGORY, filter) or {}
end

-- Dungeon icons come from the Mythic+ map list, matched to the group by name.
local function Normalize(text)
    -- Lower case, letters and digits only: "Kings' Rest" == "Kings Rest" == "kings-rest".
    return (tostring(text or ""):lower():gsub("[^%w]", ""))
end

local function MapTextures()
    local textures = {}
    local CM = _G.C_ChallengeMode
    if not (CM and CM.GetMapUIInfo) then return textures end
    local maps = {}
    if CM.GetMapTable then for _, id in ipairs(SafeCall(CM.GetMapTable) or {}) do maps[#maps + 1] = id end end
    for _, mapID in ipairs(maps) do
        local name, _, _, texture = SafeCall(CM.GetMapUIInfo, mapID)
        if name and texture then textures[Normalize(name)] = texture end
    end
    return textures
end

-- Dungeon Journal icons as a second source (every dungeon of the current tier).
local function JournalTextures()
    local textures = {}
    if not (_G.EJ_GetInstanceByIndex and _G.EJ_GetNumTiers and _G.EJ_SelectTier) then return textures end
    local previous = _G.EJ_GetCurrentTier and _G.EJ_GetCurrentTier()
    local top = _G.EJ_GetNumTiers()
    for tier = max(1, top - 2), top do
        pcall(_G.EJ_SelectTier, tier)
        local index = 1
        while true do
            local _, name, _, _, tile, _, icon = _G.EJ_GetInstanceByIndex(index, false)
            if not name then break end
            if icon or tile then textures[Normalize(name)] = { texture = icon or tile, square = icon ~= nil } end
            index = index + 1
        end
    end
    if previous then pcall(_G.EJ_SelectTier, previous) end
    return textures
end

-- Returns texture, isSquare. Mythic+ map icons are square; a Journal tile is only used when
-- it has no small icon (then it is cropped to its square part when drawn).
local function IconFor(name, maps, journal)
    if not name then return nil end
    local key = Normalize(name)
    if maps[key] then return maps[key], true end
    local entry = journal[key]
    if entry then return entry.texture, entry.square end
    for _, source in ipairs({ maps, journal }) do
        for mapName, value in pairs(source) do
            if mapName ~= "" and (key:find(mapName, 1, true) or mapName:find(key, 1, true)) then
                if type(value) == "table" then return value.texture, value.square end
                return value, true
            end
        end
    end
    return nil
end

local function SeasonDungeons()
    local list, maps, journal = {}, MapTextures(), nil
    for _, groupID in ipairs(ActivityGroups(true)) do
        local name = SafeCall(_G.C_LFGList.GetActivityGroupInfo, groupID)
        if name then
            local icon, square = IconFor(name, maps, {})
            if not icon then
                journal = journal or JournalTextures()
                icon, square = IconFor(name, {}, journal)
            end
            list[#list + 1] = { id = groupID, name = name, icon = icon or 136243, found = icon ~= nil,
                square = icon == nil or square }
        end
    end
    return list
end

local function SelectedSet()
    local filter = SafeCall(_G.C_LFGList.GetAdvancedFilter)
    local set, count = {}, 0
    if filter and filter.activities then
        for _, id in ipairs(filter.activities) do set[id] = true; count = count + 1 end
    end
    return set, count, filter
end

-- "None checked" and "all checked" mean the same: no dungeon filter at all.
local function AllDungeonsCount()
    return #ActivityGroups(true) + #ActivityGroups(false)
end

local function DoSearch()
    local panel = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    if panel and _G.LFGListSearchPanel_DoSearch then _G.LFGListSearchPanel_DoSearch(panel) end
end

local function ToggleDungeon(groupID)
    local set, count, filter = SelectedSet()
    if not filter then return end
    if count == 0 or count >= AllDungeonsCount() then set = {} end
    if set[groupID] then set[groupID] = nil else set[groupID] = true end
    local list = {}
    for id in pairs(set) do list[#list + 1] = id end
    filter.activities = list
    _G.C_LFGList.SaveAdvancedFilter(filter)
    DoSearch()
end

local function ResetFilters()
    local filter = SafeCall(_G.C_LFGList.GetAdvancedFilter)
    if filter then
        filter.needsTank, filter.needsHealer, filter.needsDamage = false, false, false
        filter.needsMyClass, filter.hasTank, filter.hasHealer = false, false, false
        filter.minimumRating = 0
        filter.activities = {}
        filter.difficultyNormal, filter.difficultyHeroic = true, true
        filter.difficultyMythic, filter.difficultyMythicPlus = true, true
        filter.generalPlaystyle1, filter.generalPlaystyle2 = true, true
        filter.generalPlaystyle3, filter.generalPlaystyle4 = true, true
        _G.C_LFGList.SaveAdvancedFilter(filter)
    end
    state.friendsOnly = false
    DoSearch()
end

-------------------------------------------------------------------------------
--  Bar
-------------------------------------------------------------------------------
local function Skin(frame, alpha)
    if KT.AddBackdrop then KT:AddBackdrop(frame, 0.05, 0.05, 0.055, alpha or 0.95) end
    if KT.AddBorder then KT:AddBorder(frame, 0, 0, 0, 1) end
end

local function NewButton(parent)
    local button = CreateFrame("Button", nil, parent)
    Skin(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    button.mark = button:CreateTexture(nil, "OVERLAY")
    button.mark:SetAllPoints()
    button.mark:SetColorTexture(1, 1, 1, 0)
    button:SetScript("OnEnter", function(self)
        _G.GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        _G.GameTooltip:SetText(self.tip or "")
        _G.GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    return button
end

local function SetActive(button, active)
    if KT.AddBorder then
        if active then
            local r, g, b = Accent()
            KT:AddBorder(button, r, g, b, 1)
        else
            KT:AddBorder(button, 0, 0, 0, 1)
        end
    end
    button.icon:SetDesaturated(false)
    button.icon:SetAlpha(active and 1 or 0.85)
end

local function Layout()
    if not bar then return end
    local buttons = bar.buttons
    local count = #buttons
    if count == 0 then return end
    local width = bar:GetWidth()
    if not width or width <= 0 then return end
    local size = floor((width - (count - 1) * BAR_GAP) / count)
    size = max(18, min(BAR_HEIGHT, size))
    for index, button in ipairs(buttons) do
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("LEFT", bar, "LEFT", (index - 1) * (size + BAR_GAP), 0)
    end
end

local function RefreshActive()
    if not (bar and bar:IsShown()) then return end
    local set, count = SelectedSet()
    local filtering = count > 0 and count < AllDungeonsCount()
    for _, button in ipairs(bar.dungeonButtons) do
        SetActive(button, filtering and set[button.groupID] or false)
    end
    SetActive(bar.friends, state.friendsOnly)
end

local function BuildBar(panel)
    if bar then return bar end
    bar = CreateFrame("Frame", "KT_LFGDungeonBar", panel)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetScript("OnSizeChanged", Layout)
    bar.buttons, bar.dungeonButtons = {}, {}

    local friends = NewButton(bar)
    friends.tip = "Only groups with friends or guild mates"
    if _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo("groupfinder-icon-friend") then
        friends.icon:SetAtlas("groupfinder-icon-friend")
        friends.icon:SetTexCoord(0, 1, 0, 1)
    else
        friends.icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    end
    friends:SetScript("OnClick", function()
        state.friendsOnly = not state.friendsOnly
        if _G.LFGListSearchPanel_UpdateResultList and _G.LFGListFrame then
            _G.LFGListSearchPanel_UpdateResultList(_G.LFGListFrame.SearchPanel)
        end
        RefreshActive()
    end)
    bar.friends = friends
    bar.buttons[1] = friends

    local clear = NewButton(bar)
    clear.tip = "Clear filters"
    clear.icon:Hide()
    clear.label = clear:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    clear.label:SetPoint("CENTER", 0, 1)
    clear.label:SetText("X")
    clear:SetScript("OnClick", function()
        ResetFilters()
        RefreshActive()
    end)
    bar.clear = clear
    bar.buttons[2] = clear
    return bar
end

-- Dungeon buttons follow the season: rebuilt whenever the list changes.
local function RebuildDungeons()
    if not bar then return end
    local dungeons = SeasonDungeons()
    local signature = {}
    for _, d in ipairs(dungeons) do signature[#signature + 1] = d.id .. (d.found and "i" or "") end
    signature = table.concat(signature, ",")
    if bar.signature == signature then return end
    bar.signature = signature

    for _, button in ipairs(bar.dungeonButtons) do button:Hide() end
    bar.dungeonButtons = {}
    bar.buttons = { bar.friends, bar.clear }
    for index, dungeon in ipairs(dungeons) do
        local button = bar["dungeon" .. index]
        if not button then
            button = NewButton(bar)
            bar["dungeon" .. index] = button
        end
        button.groupID = dungeon.id
        button.tip = dungeon.name
        button.icon:SetTexture(dungeon.icon)
        if dungeon.square then
            button.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        else
            -- A wide journal tile: keep only its left square part.
            button.icon:SetTexCoord(0.03, 0.5, 0.03, 0.97)
        end
        button:SetScript("OnClick", function(self) ToggleDungeon(self.groupID) RefreshActive() end)
        button:Show()
        bar.dungeonButtons[index] = button
        bar.buttons[#bar.buttons + 1] = button
    end
    Layout()
end

local RESULTS_TOP = -86
local function Reposition(panel, withBar)
    if _G.InCombatLockdown() then return end
    local inset = panel.ResultsInset
    if inset then
        local extra = withBar and (BAR_HEIGHT + BAR_GAP * 2) or 0
        inset:SetPoint("TOPLEFT", panel, "TOPLEFT", -1, RESULTS_TOP - extra)
    end
end

local function UpdateBar()
    local frame = _G.LFGListFrame
    local panel = frame and frame.SearchPanel
    if not panel then return end
    local wanted = Config().enable
        and frame.CategorySelection and frame.CategorySelection.selectedCategory == DUNGEONS_CATEGORY
        and panel:IsShown()
    if not wanted then
        if bar then bar:Hide() end
        Reposition(panel, false)
        return
    end
    BuildBar(panel)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", panel.SearchBox, "BOTTOMLEFT", -4, -BAR_GAP - 2)
    bar:SetPoint("TOPRIGHT", panel.FilterButton, "BOTTOMRIGHT", 0, -BAR_GAP - 2)
    bar:Show()
    RebuildDungeons()
    Reposition(panel, true)
    Layout()
    RefreshActive()
end

-------------------------------------------------------------------------------
--  Friends / guild mates only
-------------------------------------------------------------------------------
local function HasFriends(resultID)
    local bnet, chars, guild = SafeCall(_G.C_LFGList.GetSearchResultFriends, resultID)
    return (type(bnet) == "table" and #bnet > 0) or (type(chars) == "table" and #chars > 0)
        or (type(guild) == "table" and #guild > 0)
end

local function ApplyFriendFilter(panel)
    if not state.friendsOnly then return end
    local results = panel.results
    if type(results) ~= "table" then return end
    local kept = {}
    for _, resultID in ipairs(results) do
        if HasFriends(resultID) then kept[#kept + 1] = resultID end
    end
    panel.results = kept
    panel.totalResults = #kept
    if _G.LFGListSearchPanel_UpdateResults then _G.LFGListSearchPanel_UpdateResults(panel) end
end

-------------------------------------------------------------------------------
--  Specialization icons in the search results
-------------------------------------------------------------------------------
local specLookup
local function BuildSpecLookup()
    specLookup = {}
    local classCount = _G.GetNumClasses and _G.GetNumClasses() or 0
    for classID = 1, classCount do
        local _, classFile = _G.GetClassInfo(classID)
        local specCount = _G.GetNumSpecializationsForClassID and _G.GetNumSpecializationsForClassID(classID) or 0
        for index = 1, specCount do
            local _, name, _, icon = _G.GetSpecializationInfoForClassID(classID, index)
            if classFile and name and icon then specLookup[classFile .. "|" .. name] = icon end
        end
    end
end

local circleMasks = setmetatable({}, { __mode = "k" })
local function CircleMask(icon)
    local mask = circleMasks[icon]
    if not mask then
        mask = icon:CreateMaskTexture()
        mask:SetAllPoints(icon.ClassCircle)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        circleMasks[icon] = mask
    end
    return mask
end

local ROLE_BY_SUFFIX = { tank = "TANK", heal = "HEALER", dps = "DAMAGER" }
local function SlotInfo(icon)
    local classAtlas = icon.ClassCircle:GetAtlas()
    local roleAtlas = icon.RoleIcon:GetAtlas()
    -- The client lower-cases atlas names ("...-color-mage"); class tokens are upper case.
    local class = type(classAtlas) == "string" and classAtlas:lower():match("groupfinder%-icon%-class%-color%-(.+)$")
    local suffix = type(roleAtlas) == "string" and roleAtlas:lower():match("micro%-(%a+)$")
    return class and class:upper() or nil, suffix and ROLE_BY_SUFFIX[suffix]
end

local function Readable(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return nil end
    return value
end

local function RestoreSlot(icon)
    if icon._ktSpecShown then
        icon._ktSpecShown = nil
        icon.ClassCircle:RemoveMaskTexture(CircleMask(icon))
        icon.RoleIcon:ClearAllPoints()
        icon.RoleIcon:SetPoint("CENTER")
        icon.RoleIcon:SetSize(12, 12)
    end
end

local lastSpecError
local function ApplySpecIconsUnsafe(entry)
    if not Config().specIcons then return end
    local resultID = entry.resultID
    local display = entry.DataDisplay and entry.DataDisplay.Enumerate
    if not (resultID and display and display.Icons) then return end
    if not specLookup then BuildSpecLookup() end

    local info = SafeCall(_G.C_LFGList.GetSearchResultInfo, resultID)
    local members = {}
    local numMembers = info and Readable(info.numMembers) or 0
    for index = 1, (type(numMembers) == "number" and numMembers or 0) do
        local member = SafeCall(_G.C_LFGList.GetSearchResultPlayerInfo, resultID, index)
        if type(member) == "table" then
            local classFile, specName = Readable(member.classFilename), Readable(member.specName)
            if type(classFile) == "string" and type(specName) == "string" and specName ~= "" then
                members[#members + 1] = { classFilename = classFile, specName = specName,
                    assignedRole = Readable(member.assignedRole) }
            end
        end
    end

    for _, icon in ipairs(display.Icons) do
        if icon:IsShown() and icon.ClassCircle:IsShown() then
            local class, role = SlotInfo(icon)
            local spec
            for index, member in ipairs(members) do
                if member.classFilename == class and (not role or member.assignedRole == role) then
                    spec = specLookup[class .. "|" .. member.specName]
                    if spec then table.remove(members, index) break end
                end
            end
            if spec then
                icon.ClassCircle:SetTexture(spec)
                icon.ClassCircle:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                icon.ClassCircle:AddMaskTexture(CircleMask(icon))
                -- The role marker shrinks into the corner so the spec icon stays visible.
                icon.RoleIcon:ClearAllPoints()
                icon.RoleIcon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
                icon.RoleIcon:SetSize(9, 9)
                icon._ktSpecShown = true
            else
                RestoreSlot(icon)
            end
        else
            RestoreSlot(icon)
        end
    end
end

local function ApplySpecIcons(entry)
    local ok, err = pcall(ApplySpecIconsUnsafe, entry)
    if not ok then lastSpecError = err end
end

-- /ktlfg : what the last results looked like (helps when icons do not change).
_G.SLASH_KTLFG1 = "/ktlfg"
_G.SlashCmdList.KTLFG = function()
    local panel = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    local results = panel and panel.results
    print("|cff66ccffKUI LFG|r specIcons=" .. tostring(Config().specIcons)
        .. " results=" .. tostring(type(results) == "table" and #results or "n/a")
        .. " lastError=" .. tostring(lastSpecError))
    local id = type(results) == "table" and results[1]
    if id then
        local info = SafeCall(_G.C_LFGList.GetSearchResultInfo, id)
        local member = SafeCall(_G.C_LFGList.GetSearchResultPlayerInfo, id, 1)
        print("  first member: class=" .. tostring(member and member.classFilename)
            .. " spec=" .. tostring(member and member.specName)
            .. " role=" .. tostring(member and member.assignedRole)
            .. " members=" .. tostring(info and info.numMembers))
    end
end

-------------------------------------------------------------------------------
--  Install
-------------------------------------------------------------------------------
local hooked
local function Install()
    if hooked or not (_G.LFGListFrame and _G.LFGListFrame.SearchPanel) then return end
    if not (_G.C_LFGList and _G.C_LFGList.GetAdvancedFilter) then return end
    hooked = true
    local panel = _G.LFGListFrame.SearchPanel
    panel:HookScript("OnShow", UpdateBar)
    panel:HookScript("OnHide", function() if bar then bar:Hide() end end)
    if _G.LFGListSearchPanel_SetCategory then hooksecurefunc("LFGListSearchPanel_SetCategory", UpdateBar) end
    if _G.LFGListSearchPanel_UpdateResultList then
        hooksecurefunc("LFGListSearchPanel_UpdateResultList", function(searchPanel)
            ApplyFriendFilter(searchPanel)
            RefreshActive()
        end)
    end
    if _G.LFGListSearchEntry_Update then hooksecurefunc("LFGListSearchEntry_Update", ApplySpecIcons) end
    UpdateBar()
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
watcher:RegisterEvent("MYTHIC_PLUS_CURRENT_AFFIX_UPDATE")
watcher:SetScript("OnEvent", function(_, event)
    Install()
    if event == "PLAYER_LOGIN" then
        if _G.C_MythicPlus and _G.C_MythicPlus.RequestMapInfo then pcall(_G.C_MythicPlus.RequestMapInfo) end
        pcall(Config)  -- runs the one-time class-bar migration at login
    elseif bar and bar:IsShown() and (event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE") then
        RebuildDungeons()
    end
end)
Install()

Mod.LFGBar = { Update = UpdateBar, Config = Config }
