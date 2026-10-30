local _, ns = ...

local KT = (ns and ns.KT) or _G.KT or (LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))
if not KT then
    return
end

local Opt = KT.Options or {}
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local FONT = KT.FONT_PATH or STANDARD_TEXT_FONT
local ICON_BASE = "Interface\\AddOns\\KullThranUI\\Modules\\Installers\\Icons\\"
local DEFAULT_ICON = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUILogoCuadrado.png"
local MAX_HINT_COMMANDS = 3

-- Bundled icons take priority over the addon's own TOC icon.
local BUNDLED_ICONS = {
    Auctionator = "Auctionator.tga",
    OPie = "Opie.tga",
}

-- ---------------------------------------------------------------------------
-- Addon list helpers
-- ---------------------------------------------------------------------------

local function GetNumAddons()
    if C_AddOns and C_AddOns.GetNumAddOns then
        return C_AddOns.GetNumAddOns() or 0
    end
    return GetNumAddOns and GetNumAddOns() or 0
end

local function GetAddonInfoByIndex(index)
    local getter = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if not getter then return nil end
    local ok, name, title = pcall(getter, index)
    if ok and type(name) == "string" and name ~= "" then
        return name, title
    end
end

local function GetMetadata(addonName, field)
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if not getter then return nil end
    local ok, value = pcall(getter, addonName, field)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
end

local function IsAddonLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(addonName) and true or false
    end
    return IsAddOnLoaded and IsAddOnLoaded(addonName) and true or false
end

local function IsAddonEnabledForCurrentCharacter(addonName)
    if IsAddonLoaded(addonName) then
        return true
    end

    if C_AddOns and C_AddOns.GetAddOnEnableState and UnitName then
        local playerName = UnitName("player")
        if playerName then
            local ok, state = pcall(C_AddOns.GetAddOnEnableState, playerName, addonName)
            if ok and (tonumber(state) or 0) > 0 then
                return true
            end
        end
    end

    return false
end

local function IsLoadOnDemand(addonName)
    local check = C_AddOns and C_AddOns.IsAddOnLoadOnDemand or IsAddOnLoadOnDemand
    if not check then return false end
    local ok, lod = pcall(check, addonName)
    return ok and lod and true or false
end

local function StripMarkup(text)
    if type(text) ~= "string" then return text end
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return strtrim and strtrim(text) or text:match("^%s*(.-)%s*$")
end

local function NormalizeKey(text)
    if type(text) ~= "string" then return nil end
    local key = StripMarkup(text):lower():gsub("[^%w]", "")
    if key == "" then return nil end
    return key
end

local function IsOwnOrSystemAddon(addonName)
    return addonName:find("^KullThranUI") ~= nil or addonName:find("^Blizzard_") ~= nil
end

-- Returns the addon whose code last wrote tbl[key], when the client exposes it.
local function GetWriterAddon(tbl, key)
    if type(issecurevariable) ~= "function" then return nil end
    local ok, isSecure, taint = pcall(issecurevariable, tbl, key)
    if ok and not isSecure and type(taint) == "string" and taint ~= "" then
        return taint
    end
end

-- ---------------------------------------------------------------------------
-- Detection
-- ---------------------------------------------------------------------------

local function CollectCandidateAddons()
    local byName, byKey, ordered = {}, {}, {}

    for index = 1, GetNumAddons() do
        local name, title = GetAddonInfoByIndex(index)
        if name and not IsOwnOrSystemAddon(name) and IsAddonEnabledForCurrentCharacter(name)
            and (IsAddonLoaded(name) or IsLoadOnDemand(name)) then
            local entry = {
                name = name,
                label = StripMarkup(title) or name,
                loaded = IsAddonLoaded(name),
                slash = {},
                slashKeys = {},
                ace = {},
                compartmentFunc = GetMetadata(name, "AddonCompartmentFunc"),
                iconTexture = GetMetadata(name, "IconTexture"),
                iconAtlas = GetMetadata(name, "IconAtlas"),
            }
            if entry.label == "" then entry.label = name end
            byName[name] = entry
            ordered[#ordered + 1] = entry

            local nameKey = NormalizeKey(name)
            if nameKey and not byKey[nameKey] then byKey[nameKey] = entry end
            local titleKey = NormalizeKey(title)
            if titleKey and not byKey[titleKey] then byKey[titleKey] = entry end
        end
    end

    return byName, byKey, ordered
end

local function FindOwner(byName, byKey, writer, ...)
    if writer and byName[writer] then
        return byName[writer]
    end
    for i = 1, select("#", ...) do
        local key = NormalizeKey((select(i, ...)))
        if key and byKey[key] then
            return byKey[key]
        end
    end
end

local function CollectSlashCommands(byName, byKey)
    if type(SlashCmdList) ~= "table" then return end

    for key, handler in pairs(SlashCmdList) do
        if type(key) == "string" and type(handler) == "function" then
            local commands = {}
            for index = 1, 10 do
                local command = _G["SLASH_" .. key .. index]
                if type(command) == "string" and command ~= "" then
                    commands[#commands + 1] = command:gsub("^/", "")
                end
            end

            if #commands > 0 then
                local cleanKey = key:gsub("^ACECONSOLE_", "")
                local owner = FindOwner(byName, byKey, GetWriterAddon(SlashCmdList, key), cleanKey, unpack(commands))
                if owner then
                    owner.slashKeys[#owner.slashKeys + 1] = key
                    for _, command in ipairs(commands) do
                        owner.slash[#owner.slash + 1] = command
                    end
                end
            end
        end
    end
end

local function CollectAceOptions(byName, byKey)
    local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if not (ACR and type(ACR.tables) == "table") then return end

    for appName in pairs(ACR.tables) do
        if type(appName) == "string" then
            local owner = FindOwner(byName, byKey, GetWriterAddon(ACR.tables, appName), appName)
            if owner then
                owner.ace[#owner.ace + 1] = appName
            end
        end
    end
end

local function CollectSettingsCategories(byKey)
    local panel = _G.SettingsPanel
    if not (panel and panel.GetAllCategories) then return end

    local ok, categories = pcall(panel.GetAllCategories, panel)
    if not ok or type(categories) ~= "table" then return end

    for _, category in ipairs(categories) do
        local isTopLevel = not (category.GetParentCategory and category:GetParentCategory())
        local categoryName = category.GetName and category:GetName()
        local owner = isTopLevel and categoryName and byKey[NormalizeKey(categoryName) or ""]
        if owner and not owner.categoryID and category.GetID then
            owner.categoryID = category:GetID()
        end
    end
end

local function SortSlash(entry)
    table.sort(entry.slashKeys)
    local seen, unique = {}, {}
    for _, command in ipairs(entry.slash) do
        local lower = command:lower()
        if not seen[lower] then
            seen[lower] = true
            unique[#unique + 1] = command
        end
    end
    -- Commands that match the addon's name first, then the shortest ones.
    local nameKey = NormalizeKey(entry.name)
    table.sort(unique, function(a, b)
        local aMatch = NormalizeKey(a) == nameKey
        local bMatch = NormalizeKey(b) == nameKey
        if aMatch ~= bMatch then return aMatch end
        if #a ~= #b then return #a < #b end
        return a:lower() < b:lower()
    end)
    entry.slash = unique
end

local function DetectExternalAddons()
    local byName, byKey, ordered = CollectCandidateAddons()
    CollectSlashCommands(byName, byKey)
    CollectAceOptions(byName, byKey)
    CollectSettingsCategories(byKey)

    local result = {}
    for _, entry in ipairs(ordered) do
        SortSlash(entry)
        local hasCompartment = entry.compartmentFunc and (not entry.loaded or type(_G[entry.compartmentFunc]) == "function")
        if hasCompartment or #entry.slash > 0 or #entry.ace > 0 or entry.categoryID then
            result[#result + 1] = entry
        end
    end

    table.sort(result, function(a, b) return a.label:lower() < b.label:lower() end)
    return result
end

-- ---------------------------------------------------------------------------
-- Opening an addon's config
-- ---------------------------------------------------------------------------

local function OpenDetectedAddon(entry)
    if InCombatLockdown and InCombatLockdown() then return end

    if not IsAddonLoaded(entry.name) then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, entry.name)
        end
        if not IsAddonLoaded(entry.name) then return end

        -- Its commands and panels only exist now that it has loaded.
        for _, fresh in ipairs(DetectExternalAddons()) do
            if fresh.name == entry.name then
                entry = fresh
                break
            end
        end
    end

    if KT.MenuPrincipal and KT.MenuPrincipal:IsShown() then
        KT.MenuPrincipal:Hide()
    end

    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
    local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if ACD and ACR then
        for _, appName in ipairs(entry.ace) do
            local ok, options = pcall(ACR.GetOptionsTable, ACR, appName)
            if ok and options then
                ACD:Open(appName)
                return
            end
        end
    end

    if entry.categoryID and Settings and Settings.OpenToCategory then
        pcall(Settings.OpenToCategory, entry.categoryID)
        return
    end

    if entry.compartmentFunc and type(_G[entry.compartmentFunc]) == "function" then
        if pcall(_G[entry.compartmentFunc], entry.name, "LeftButton") then return end
    end

    for _, key in ipairs(entry.slashKeys) do
        local handler = SlashCmdList and SlashCmdList[key]
        if type(handler) == "function" then
            pcall(handler, "")
            return
        end
    end

    KT:OpenExternalAddon(entry.name, entry.slash, entry.ace)
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

local function SetEntryIcon(icon, entry)
    local bundled = BUNDLED_ICONS[entry.name]
    if bundled then
        icon:SetTexture(ICON_BASE .. bundled)
    elseif entry.iconTexture then
        icon:SetTexture(entry.iconTexture)
    elseif entry.iconAtlas and icon.SetAtlas and pcall(icon.SetAtlas, icon, entry.iconAtlas) then
        return
    else
        icon:SetTexture(DEFAULT_ICON)
    end
    if not icon:GetTexture() then
        icon:SetTexture(DEFAULT_ICON)
    end
end

local function BuildHint(entry)
    local commands = {}
    for index = 1, math.min(#entry.slash, MAX_HINT_COMMANDS) do
        commands[#commands + 1] = "/" .. entry.slash[index]
    end
    return table.concat(commands, "  ")
end

local function CreateExternalAddonButton(parent, yOffset, entry)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(parent:GetWidth() - 20, 42)
    row:SetPoint("TOPLEFT", 10, yOffset)

    local btn = CreateFrame("Button", nil, row)
    btn:SetPoint("TOPLEFT", 12, -4)
    btn:SetPoint("BOTTOMRIGHT", -12, 4)
    KT:AddBackdrop(btn, 0.08, 0.08, 0.11, 1)
    KT:AddAccentBorder(btn, 0.5)

    local hover = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 10, 0)
    SetEntryIcon(icon, entry)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, 11, "OUTLINE")
    label:SetText(entry.label)
    label:SetTextColor(1, 1, 1, 1)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetPoint("LEFT", icon, "RIGHT", 10, 0)

    local hint = btn:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 10)
    KT:SetAccentTextColor(hint, 0.9)
    hint:SetJustifyH("RIGHT")
    hint:SetText(BuildHint(entry))
    hint:SetPoint("RIGHT", -12, 0)

    label:SetPoint("RIGHT", hint, "LEFT", -12, 0)

    btn:SetScript("OnEnter", function(self)
        KT:AddAccentBorder(self, 0.95)
        hover:SetColorTexture(1, 1, 1, 0.04)
        hint:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        KT:AddAccentBorder(self, 0.5)
        hover:SetColorTexture(1, 1, 1, 0)
        KT:SetAccentTextColor(hint, 0.9)
    end)

    btn:SetScript("OnClick", function()
        OpenDetectedAddon(entry)
    end)

    return row, 44
end

KT:RegisterPage("external", "External Addons", 90, function(sc, W)
    local y, h = 0, 0

    _, h = W:SectionHeader(sc, "Integrations", -y); y = y + h
    local db = KT.db.profile

    local function IsAddonEnabledForPlayer(addonName)
        if C_AddOns and C_AddOns.GetAddOnEnableState then
            local playerName = UnitName and UnitName("player")
            if playerName then
                return (C_AddOns.GetAddOnEnableState(playerName, addonName) or 0) > 0
            end
        end
        return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName)
    end

    local function ShouldShowUUFIntegration()
        if not IsAddonEnabledForPlayer("UnhaltedUnitFrames") then
            return false
        end

        local uf = db.unitFrames
        local enabled = uf and uf.enable ~= false and uf.enabledFrames
        if not enabled then
            return false
        end

        local hasActiveKUIFrames =
            enabled.player ~= false or
            enabled.target ~= false or
            enabled.focus ~= false or
            enabled.targettarget ~= false or
            enabled.focustarget ~= false or
            enabled.boss ~= false

        return not hasActiveKUIFrames
    end

    if ShouldShowUUFIntegration() then
        _, h = W:Toggle(sc, "External Unit Frames Edit Mode", -y, function() return db.uufIntegration.enable end, function(v) db.uufIntegration.enable = v; Reload() end); y = y + h
    end
    _, h = W:SectionHeader(sc, "Open Addon Config", -y); y = y + h
    _, h = W:Label(sc, "Quick access buttons to supported external addons (only installed addons are shown).", -y, 11); y = y + h

    local detected = DetectExternalAddons()
    for _, entry in ipairs(detected) do
        _, h = CreateExternalAddonButton(sc, -y, entry); y = y + h
    end

    if #detected == 0 then
        _, h = W:Label(sc, "No external addons with a command or options panel were detected.", -y, 11)
        y = y + h
    end

    return y
end)
