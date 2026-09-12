local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("MinimapButton", "AceEvent-3.0", "AceTimer-3.0")

-- Cache
local _G = _G
local CreateFrame = CreateFrame
local Minimap = Minimap
local tinsert = table.insert
local ipairs = ipairs
local pairs = pairs
local GetTime = GetTime
local math_pi = math.pi
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local pcall = pcall
local select = select
local tostring = tostring
local type = type

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end
-- Blizzard's AddonCompartmentFrame.registeredAddons can become tainted when
-- addon profiling is active (e.g. AddonProfiler), so iterating it directly
-- can throw "attempted to iterate a table that cannot be accessed while
-- tainted". Probe with next/pcall before looping over it.
local function CanIterateTable(value)
    if type(value) ~= "table" then return false end
    if _G.issecrettable then
        local ok, secret = pcall(_G.issecrettable, value)
        if not ok or secret == true then return false end
    end
    local ok = pcall(next, value)
    return ok
end

local TOGGLE_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\ArrowDown.png"
local IGNORE_NAMES = {
    'KT_Teleport', 'LibDBIcon10_KT_Teleport',
    "MinimapBackdrop", "MinimapVoiceChatFrame", "MinimapZoomIn", "MinimapZoomOut",
    "MiniMapTracking", "MiniMapMailFrame", "GameTimeFrame", "KT_MinimapButtonBag",
    "KT_MinimapZoneText", "KT_MinimapLocation", "KT_MinimapCoords", "KT_MinimapClock",
    "KT_MinimapPerformance", "KT_MinimapFriends", "KT_MinimapGuild", "KT_MinimapCalendar", "KT_MinimapMail",
    "KT_MinimapHolder_Main", "KT_MinimapButtonBagToggle", "QueueStatusButton", "QueueStatusMinimapButton",
    "TimeManagerClockButton", "FeedbackUIButton", "MinimapCluster", "HelpOpenTicketButton",
    "MiniMapWorldMapButton", "CovenantSanctumMinimapButton", "ExpansionLandingPageMinimapButton",
    "AddonCompartmentFrame", "MinimapBorder", "MinimapBorderTop", "MinimapNorthTag",
    "MinimapCompassTexture", "InstanceDifficultyHeadBanner", "GuildInstanceDifficulty",
    "MiniMapInstanceDifficulty",
}

local function IsIgnoredButton(name)
    if not name then
        return false
    end

    for _, ignoredName in ipairs(IGNORE_NAMES) do
        if name:find(ignoredName) then
            return true
        end
    end

    return false
end

-- The zoom +/- buttons are anonymous frames on modern clients (no global
-- name), so IsIgnoredButton(nil) can't catch them by name and they get
-- captured/hidden by the collectors intermittently. Match by identity too.
local function IsIgnoredButtonObject(child)
    if not child then
        return false
    end

    local cluster = _G.MinimapCluster
    return child == Minimap.ZoomIn or child == Minimap.ZoomOut
        or (cluster and (child == cluster.ZoomIn or child == cluster.ZoomOut))
        or child == _G.MinimapZoomIn or child == _G.MinimapZoomOut
end

-- Only launcher buttons belong in the drawer. Minimap POIs often look and
-- behave like buttons too (tooltips, clicks and icon textures), so accepting
-- every small child of Minimap also captures TomTom waypoints, HandyNotes
-- pins, RareScanner markers and similar navigation overlays.
local NON_LAUNCHER_NAME_PATTERNS = {
    '^ttminimapbutton%d+$',
    '^handynotespin%d+$',
    '^rsminimappin',
}

local function IsAddonLauncherButton(button)
    if not button or not button.IsObjectType or not button:IsObjectType('Button') then
        return false
    end

    local name = button:GetName()
    local lowerName = type(name) == 'string' and name:lower() or ''

    -- LibDBIcon is authoritative: its objects are addon launchers even when
    -- an addon chooses an unusual data-object name.
    if lowerName:find('^libdbicon10_') or button.dataObject ~= nil then
        return true
    end

    for _, pattern in ipairs(NON_LAUNCHER_NAME_PATTERNS) do
        if lowerName:find(pattern) then
            return false
        end
    end

    -- Common map-pin payloads. These checks also reject anonymous/custom pins
    -- whose names do not follow one of the known conventions above.
    if button.point ~= nil or button.POI ~= nil or button.coord ~= nil
        or button.mapFile ~= nil or button.uiMapID ~= nil then
        return false
    end

    -- Support old/custom launchers which do not use LibDBIcon, but require a
    -- semantic launcher name and a click action. A generic textured Button is
    -- deliberately not enough evidence because most minimap markers are one.
    local hasLauncherName = lowerName:find('minimapbutton', 1, true)
        or lowerName:find('minimapicon', 1, true)
    local onClick = button.GetScript and button:GetScript('OnClick')
    return hasLauncherName ~= nil and type(onClick) == 'function'
end

local function SetToggleRotation(toggle, position, expanded)
    if not toggle or not toggle.Icon then
        return
    end

    -- ArrowDown points down at rotation 0. Rotate it towards the drawer for
    -- every supported minimap edge.
    local rotation = 0
    if position == "LEFT" then
        rotation = math_pi * 0.5
    elseif position == "RIGHT" then
        rotation = math_pi * 1.5
    elseif position == "TOP" then
        rotation = math_pi
    end
    if expanded then
        rotation = rotation + math_pi
    end
    toggle.Icon:SetRotation(rotation)
    if KT.SetAccentVertexColor then
        KT:SetAccentVertexColor(toggle.Icon, 1)
    else
        local r, g, b = KT:GetStyleAccentRGB()
        toggle.Icon:SetVertexColor(r, g, b, 1)
    end
    toggle.Icon:SetDesaturated(false)
end
local function ResetToggleVisualState(toggle)
    if not toggle then
        return
    end

    if toggle.SetButtonState then
        toggle:SetButtonState("NORMAL", false)
    end
    if toggle.UnlockHighlight then
        toggle:UnlockHighlight()
    end
    if toggle.Icon then
        toggle.Icon:SetAlpha(toggle:IsMouseOver() and 1 or 0.92)
    end
end

local function RefreshMinimapOverlay()
    local minimapModule = _G.KT_MINIMAP_MODULE or (KT.GetModule and KT:GetModule("Minimap", true))
    if not minimapModule then
        return
    end

    if minimapModule.UpdateZone then
        minimapModule:UpdateZone()
    end
    if minimapModule.UpdateSocialStats then
        minimapModule:UpdateSocialStats()
    end
    if minimapModule.MaybeRefreshDynamicOverlayVisibility then
        minimapModule:MaybeRefreshDynamicOverlayVisibility()
    elseif minimapModule.UpdateOverlayVisibility then
        minimapModule:UpdateOverlayVisibility(true)
    end
end

local function TryToggleAddonCompartment()
    local compartment = _G.AddonCompartmentFrame
    if not compartment then
        return false
    end

    if compartment.Click then
        local ok = pcall(compartment.Click, compartment)
        if ok then
            return true
        end
    end

    if compartment.GetScript then
        local onClick = compartment:GetScript("OnClick")
        if onClick then
            local ok = pcall(onClick, compartment, "LeftButton")
            if ok then
                return true
            end
        end
    end

    return false
end

local function TryClickButtonFrame(frame, buttonName)
    if not frame then
        return false
    end

    if frame.Click then
        local ok = pcall(frame.Click, frame, buttonName or "LeftButton")
        if ok then
            return true
        end
    end

    if frame.GetScript then
        local onClick = frame:GetScript("OnClick")
        if onClick then
            local ok = pcall(onClick, frame, buttonName or "LeftButton")
            if ok then
                return true
            end
        end
    end

    return false
end

local function BuildAddonMenuList(owner)
    local menu = {}
    local seen = {}

    local function addEntry(text, func, disabled)
        local key = tostring(text or "addon")
        if seen[key] then
            return
        end
        seen[key] = true
        tinsert(menu, {
            text = key,
            notCheckable = true,
            disabled = disabled == true,
            func = disabled and nil or func,
        })
    end

    local compartment = _G.AddonCompartmentFrame
    local registeredAddons = compartment and compartment.registeredAddons
    if CanIterateTable(registeredAddons) then
        for _, entry in ipairs(registeredAddons) do
            if type(entry) == "table" and type(entry.func) == "function" then
                addEntry(entry.text or "Addon", function()
                    pcall(entry.func, owner and owner.buttonBag and owner.buttonBag.toggle or compartment, { buttonName = "LeftButton" }, nil)
                end)
            end
        end
    end

    -- Buttons already captured by KUI are no longer Minimap children. Include
    -- them explicitly so the dropdown and the physical drawer expose the same
    -- actions (notably Blizzard's Expansion Summary button).
    local bag = owner and owner.buttonBag
    if bag and bag.GetChildren then
        for _, child in ipairs({ bag:GetChildren() }) do
            if child and not child._ktProxyCompartment
                and (not child._ktRespectNativeVisibility or child:IsShown()) then
                local button = child
                local label = button._ktMenuLabel or (button.GetName and button:GetName())
                if label then
                    addEntry(label, function()
                        TryClickButtonFrame(button, "LeftButton")
                    end)
                end
            end
        end
    end

    for _, child in ipairs({ Minimap:GetChildren() }) do
        local name = child:GetName()
        if not IsIgnoredButton(name) and not IsIgnoredButtonObject(child) and child:IsShown() and (child:IsObjectType("Button") or child:IsObjectType("Frame")) then
            local w, h = child:GetWidth(), child:GetHeight()
            if w > 2 and h > 2 and w < 60 and h < 60 then
                addEntry(name or ("Addon Button " .. tostring(#menu + 1)), function()
                    TryClickButtonFrame(child, "LeftButton")
                end)
            end
        end
    end

    if #menu == 0 then
        addEntry(LText("No addon buttons found"), nil, true)
    end

    return menu
end

local function ShowAddonDropdownMenu(owner)
    if not owner or not EasyMenu then
        return false
    end

    owner.dropdownMenu = owner.dropdownMenu or CreateFrame("Frame", "KT_MinimapButtonDropdown", UIParent, "UIDropDownMenuTemplate")
    if CloseDropDownMenus then
        CloseDropDownMenus()
    end

    EasyMenu(BuildAddonMenuList(owner), owner.dropdownMenu, "cursor", 0, 0, "MENU", 2)
    return true
end

local function ToggleButtonBag(bag, owner)
    if not bag then
        return
    end

    if owner and owner.CollectButtons then
        owner:CollectButtons()
    end

    if owner and (owner.buttonCount or 0) <= 0 and TryToggleAddonCompartment() then
        RefreshMinimapOverlay()
        return
    end

    if bag:IsShown() then
        bag:Hide()
    else
        bag:Show()
        for _, child in ipairs({bag:GetChildren()}) do
            if child and child._ktRespectNativeVisibility and not child:IsShown() then
                child:Hide()
            elseif child and child.Show and (not child._ktProxyCompartment or child._ktProxyActive) then
                child:Show()
            elseif child and child._ktProxyCompartment then
                child:Hide()
            end
        end
    end
    if owner and owner.buttonBag and owner.buttonBag.toggle then
        SetToggleRotation(owner.buttonBag.toggle, owner.db and owner.db.position or "LEFT", bag:IsShown())
    end
    RefreshMinimapOverlay()
end

local function OpenKullThranUIMenu()
    if not KT then
        return false
    end

    if KT.OpenMenu then
        local ok = pcall(function()
            KT:OpenMenu("minimap")
        end)
        if ok and KT.MenuPrincipal and KT.MenuPrincipal:IsShown() then
            return true
        end
    end

    if KT.ToggleConfig then
        local ok = pcall(function()
            KT:ToggleConfig()
        end)
        if ok and KT.MenuPrincipal and KT.MenuPrincipal:IsShown() then
            if KT.OpenMenu then
                pcall(function()
                    KT:OpenMenu("minimap")
                end)
            end
            return true
        end
    end

    return KT.MenuPrincipal and KT.MenuPrincipal:IsShown() or false
end

local function NormalizeTexture(texture)
    if not texture or not texture.SetAlpha then
        return
    end

    texture:SetAlpha(1)
    if texture.SetDesaturated then
        texture:SetDesaturated(false)
    end
    if texture.SetVertexColor then
        texture:SetVertexColor(1, 1, 1, 1)
    end
end

local function IsUsableIconTexture(texture)
    if not (texture and texture.GetObjectType and texture:GetObjectType() == "Texture") then
        return false
    end
    local rawTexture = texture.GetTexture and texture:GetTexture()
    local atlas = texture.GetAtlas and texture:GetAtlas()
    return rawTexture ~= nil or atlas ~= nil
end

local function FindButtonIcon(button)
    if not button then return nil end
    for _, icon in pairs({ button.icon, button.Icon, button.iconTexture, button.Texture, button.IconTexture }) do
        if IsUsableIconTexture(icon) then return icon end
    end
    if button.GetNormalTexture then
        local normal = button:GetNormalTexture()
        if IsUsableIconTexture(normal) then return normal end
    end
    if button.GetRegions then
        for regionIndex = 1, button:GetNumRegions() do
            local region = select(regionIndex, button:GetRegions())
            local isDecoration = region == button._ktBagBackground
            if not isDecoration then
                for _, edge in ipairs(button._ktBagBorder or {}) do
                    if region == edge then isDecoration = true break end
                end
            end
            if not isDecoration and IsUsableIconTexture(region) then
                return region
            end
        end
    end
    return nil
end

local function NormalizeButtonIdentity(value)
    value = tostring(value or ""):lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return value:gsub("[^%w]", "")
end

local function IsRegisteredButtonDuplicate(buttonName, registeredIdentities)
    local buttonKey = NormalizeButtonIdentity(buttonName)
    if #buttonKey < 4 then return false end
    for identity in pairs(registeredIdentities or {}) do
        if #identity >= 4 and (buttonKey:find(identity, 1, true) or identity:find(buttonKey, 1, true)) then
            return true
        end
    end
    return false
end

local function ReleaseCapturedButton(button)
    if not button or button._ktProxyCompartment then return end
    local preserveHidden = button._ktRespectNativeVisibility and not button:IsShown()
    if button._ktBagBackground then button._ktBagBackground:Hide() end
    for _, edge in ipairs(button._ktBagBorder or {}) do edge:Hide() end
    button:ClearAllPoints()
    button:SetParent(button._ktOriginalParent or Minimap)
    if button._ktOriginalWidth and button._ktOriginalHeight then
        button:SetSize(button._ktOriginalWidth, button._ktOriginalHeight)
    end
    for _, point in ipairs(button._ktOriginalPoints or {}) do
        button:SetPoint(point[1], point[2], point[3], point[4], point[5])
    end
    button:SetShown(not preserveHidden)
end

local function NormalizeButtonVisuals(button)
    if not button then
        return
    end

    local icon = FindButtonIcon(button)
    if not icon then
        return false
    end

    button:SetAlpha(1)
    button:SetScale(1)
    button:SetFrameStrata("MEDIUM")

    if not button._ktBagBackground then
        local background = button:CreateTexture(nil, "BACKGROUND", nil, -7)
        background:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        background:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        background:SetColorTexture(0.025, 0.025, 0.032, 0.92)
        button._ktBagBackground = background
    end

    if not button._ktBagBorder then
        button._ktBagBorder = {}
        for index = 1, 4 do
            local edge = button:CreateTexture(nil, "OVERLAY", nil, 7)
            edge:SetColorTexture(0.18, 0.18, 0.21, 1)
            button._ktBagBorder[index] = edge
        end
        local edges = button._ktBagBorder
        edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
        edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
        edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
        edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
    end

    if not button._ktBagHoverHooked and button.HookScript then
        button._ktBagHoverHooked = true
        button:HookScript("OnEnter", function(self)
            local r, g, b = 1, 0.45, 0
            if KT.GetStyleAccentRGB then
                r, g, b = KT:GetStyleAccentRGB()
            end
            for _, edge in ipairs(self._ktBagBorder or {}) do
                edge:SetColorTexture(r, g, b, 1)
            end
        end)
        button:HookScript("OnLeave", function(self)
            for _, edge in ipairs(self._ktBagBorder or {}) do edge:SetColorTexture(0.18, 0.18, 0.21, 1) end
        end)
    end

    NormalizeTexture(icon)
    button._ktBagIcon = icon
    return true
end

local function AnchorCapturedButton(button, container, index, cols, size, spacing, position)
    local col = (index - 1) % cols
    local row = math_floor((index - 1) / cols)

    button:ClearAllPoints()
    button:SetSize(size, size)

    if position == "LEFT" then
        button:SetPoint("TOPRIGHT", container, "TOPRIGHT", -(spacing + (col * (size + spacing))), -(spacing + (row * (size + spacing))))
    elseif position == "RIGHT" then
        button:SetPoint("TOPLEFT", container, "TOPLEFT", spacing + (col * (size + spacing)), -(spacing + (row * (size + spacing))))
    elseif position == "TOP" then
        button:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", spacing + (col * (size + spacing)), spacing + (row * (size + spacing)))
    else
        button:SetPoint("TOPLEFT", container, "TOPLEFT", spacing + (col * (size + spacing)), -(spacing + (row * (size + spacing))))
    end
end

local function ConfigureCompartmentProxyButton(button, entry)
    if not button then
        return
    end

    button._ktCompartmentEntry = entry
    button._ktProxyActive = entry ~= nil
    button._ktSortName = entry and NormalizeButtonIdentity(entry.text or entry.name or entry.icon) or nil

    if button.Icon then
        button.Icon:SetTexture((entry and entry.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Icon:SetAlpha(1)
    end

    if entry then
        button:Show()
    else
        button:Hide()
    end
end

function Mod:OnInitialize()
    if not KT.db.profile.minimapButton then
        KT.db.profile.minimapButton = {
            enable = true,
            size = 28,
            spacing = 4,
            rows = 3,
            position = "LEFT",
        }
    end
    if KT.db.profile.minimapButton.rows == nil then
        KT.db.profile.minimapButton.rows = 3
    end
    self.db = KT.db.profile.minimapButton
end

function Mod:OnEnable()
    self:Refresh()
end

function Mod:Refresh()
    self.db = (KT.db and KT.db.profile and KT.db.profile.minimapButton) or self.db or {
        enable = true,
        size = 28,
        spacing = 4,
        rows = 3,
        position = "LEFT",
    }

    if self.db.enable then
        if not self.buttonBag then
            self:CreateButtonBag()
        end
        ResetToggleVisualState(self.buttonBag.toggle)
        self.buttonBag.toggle:Show()
        self:UpdateLayout()
        self:CollectButtons()
        
        -- Hook Minimap OnEnter to catch buttons when user interacts
        if not self.hookedMinimap then
            Minimap:HookScript("OnEnter", function()
                if not self.lastCollect or (GetTime() - self.lastCollect > 1) then
                    self:CollectButtons()
                end
            end)
            self.hookedMinimap = true
        end
        
        -- Collection is refreshed on demand by the toggle and Minimap OnEnter.
        -- A perpetual full child scan caused regular allocation/CPU spikes.
    else
        if self.buttonBag then
            -- [FIX] Release buttons back to Minimap when disabled
            for _, child in ipairs({self.buttonBag:GetChildren()}) do
                if child._ktProxyCompartment then
                    child._ktCompartmentEntry = nil
                    child._ktProxyActive = false
                    child:Hide()
                else
                    ReleaseCapturedButton(child)
                end
            end
            ResetToggleVisualState(self.buttonBag.toggle)
            self.buttonBag:Hide()
            self.buttonBag.toggle:Hide()
        end
        if self.timer then
            self:CancelTimer(self.timer)
            self.timer = nil
        end
    end
end

function Mod:CreateButtonBag()
    if self.buttonBag then return end
    local module = self
    
    -- Contenedor de botones (La bolsa)
    local bag = CreateFrame("Frame", "KT_MinimapButtonBag", UIParent, "BackdropTemplate")
    bag:SetFrameStrata("MEDIUM")
    bag:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 4)
    bag:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bag:SetBackdropColor(0.035, 0.035, 0.045, 0.96)
    if KT.SetAccentBackdropBorder then
        KT:SetAccentBackdropBorder(bag, 1)
    else
        local r, g, b = KT:GetStyleAccentRGB()
        bag:SetBackdropBorderColor(r, g, b, 1)
    end
    bag:SetClampedToScreen(true)
    bag:Hide()
    
    -- Botón Flecha (Toggle)
    local toggle = CreateFrame("Button", "KT_MinimapButtonBagToggle", Minimap)
    toggle:SetSize(20, 40)
    toggle:SetClampedToScreen(true)
    toggle:EnableMouse(true)
    toggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    toggle:SetNormalTexture("")
    toggle:SetPushedTexture("")
    toggle:SetHighlightTexture("")

    local icon = toggle:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", toggle, "CENTER", 0, 0)
    icon:SetSize(20, 20)
    icon:SetTexture(TOGGLE_TEXTURE)
    icon:SetTexCoord(0, 1, 0, 1)
    if KT.SetAccentVertexColor then
        KT:SetAccentVertexColor(icon, 1)
    else
        local r, g, b = KT:GetStyleAccentRGB()
        icon:SetVertexColor(r, g, b, 1)
    end
    icon:SetDesaturated(false)
    icon:SetAlpha(0.92)
    toggle.Icon = icon
    
    toggle:SetScript("OnEnter", function(s)
        if s.Icon then s.Icon:SetAlpha(1) end
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText(LText("Left Click: Open Addon Buttons Menu"))
        GameTooltip:AddLine(LText("Right Click: Open Minimap Settings"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function(s)
        if s.Icon then s.Icon:SetAlpha(0.92) end
        GameTooltip:Hide()
    end)
    toggle:SetScript("OnMouseDown", function(s)
        if s.SetButtonState then
            s:SetButtonState("PUSHED", true)
        end
        if s.Icon then s.Icon:SetAlpha(0.75) end
    end)
    toggle:SetScript("OnClick", function(s, button)
        ResetToggleVisualState(s)

        if button == "LeftButton" then
            ToggleButtonBag(bag, module)
            return
        end

        if bag and bag.Hide then
            bag:Hide()
        end

        if not OpenKullThranUIMenu() then
            ToggleButtonBag(bag, module)
        else
            RefreshMinimapOverlay()
        end
    end)
    
    bag.toggle = toggle
    bag:HookScript("OnShow", function()
        SetToggleRotation(toggle, module.db and module.db.position or "LEFT", true)
    end)
    bag:HookScript("OnHide", function()
        SetToggleRotation(toggle, module.db and module.db.position or "LEFT", false)
    end)
    self.buttonBag = bag
    self.compartmentButtons = self.compartmentButtons or {}
    
    self:CollectButtons()
end

function Mod:GetCompartmentProxyButton(index)
    self.compartmentButtons = self.compartmentButtons or {}
    local button = self.compartmentButtons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, self.buttonBag)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button._ktProxyCompartment = true

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    button.Icon = icon

    button:SetScript("OnClick", function(proxy, mouseButton)
        local entry = proxy._ktCompartmentEntry
        if entry and type(entry.func) == "function" then
            pcall(entry.func, proxy, { buttonName = mouseButton }, nil)
        end
    end)

    button:SetScript("OnEnter", function(proxy)
        local entry = proxy._ktCompartmentEntry
        if entry and type(entry.funcOnEnter) == "function" then
            pcall(entry.funcOnEnter, proxy, entry)
            return
        end

        GameTooltip:SetOwner(proxy, "ANCHOR_RIGHT")
        GameTooltip:SetText((entry and entry.text) or "Addon")
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(proxy)
        local entry = proxy._ktCompartmentEntry
        if entry and type(entry.funcOnLeave) == "function" then
            pcall(entry.funcOnLeave, proxy)
            return
        end

        GameTooltip:Hide()
    end)

    self.compartmentButtons[index] = button
    return button
end

function Mod:UpdateLayout()
    if not self.buttonBag then return end
    local toggle = self.buttonBag.toggle
    local bag = self.buttonBag
    local pos = self.db.position or "LEFT"

    bag:SetFrameStrata("MEDIUM")
    bag:SetFrameLevel((Minimap and Minimap:GetFrameLevel() or 1) + 4)
    local accentR, accentG, accentB = KT:GetStyleAccentRGB()
    bag:SetBackdropBorderColor(accentR, accentG, accentB, 1)
    
    toggle:ClearAllPoints()
    bag:ClearAllPoints()
    
    if pos == "LEFT" then
        toggle:SetPoint("RIGHT", Minimap, "LEFT", 0, 0)
        toggle:SetSize(20, 40)
        bag:SetPoint("TOPRIGHT", toggle, "TOPLEFT", -5, 0)

    elseif pos == "RIGHT" then
        toggle:SetPoint("LEFT", Minimap, "RIGHT", 0, 0)
        toggle:SetSize(20, 40)
        bag:SetPoint("TOPLEFT", toggle, "TOPRIGHT", 5, 0)

    elseif pos == "TOP" then
        toggle:SetPoint("BOTTOM", Minimap, "TOP", 0, 0)
        toggle:SetSize(40, 20)
        bag:SetPoint("BOTTOMLEFT", toggle, "TOPLEFT", 0, 5)

    elseif pos == "BOTTOM" then
        toggle:SetPoint("TOP", Minimap, "BOTTOM", 0, 0)
        toggle:SetSize(40, 20)
        bag:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -5)
    end

    if toggle.Icon then
        toggle.Icon:ClearAllPoints()
        toggle.Icon:SetPoint("CENTER", toggle, "CENTER", 0, 0)
        toggle.Icon:SetSize(20, 20)
    end

    SetToggleRotation(toggle, pos, bag:IsShown())
    ResetToggleVisualState(toggle)
end

function Mod:LegacyCollectButtons()
    if not self.buttonBag then return end
    self.lastCollect = GetTime()
    
    local buttons = {}
    self.compartmentButtons = self.compartmentButtons or {}
    local compartment = _G.AddonCompartmentFrame
    local registeredAddons = compartment and compartment.registeredAddons
    
    -- 1. Recoger botones hijos del Minimapa y contenedores
    local parentsToScan = { Minimap, _G.MinimapBackdrop, _G.MinimapCluster }
    for _, parent in ipairs(parentsToScan) do
        if parent and parent.GetChildren then
            for _, child in ipairs({parent:GetChildren()}) do
                local name = child:GetName()
                if child:IsShown() and IsAddonLauncherButton(child) and not IsIgnoredButton(name) and not IsIgnoredButtonObject(child) then
                    local w, h = child:GetWidth(), child:GetHeight()
                    if w > 2 and h > 2 and w < 60 and h < 60 and FindButtonIcon(child) then
                        child._ktOriginalParent = child._ktOriginalParent or child:GetParent()
                        if not child._ktOriginalPoints then
                            child._ktOriginalPoints = {}
                            if child.GetNumPoints then
                                for pointIndex = 1, child:GetNumPoints() do
                                    child._ktOriginalPoints[pointIndex] = { child:GetPoint(pointIndex) }
                                end
                            end
                        end
                        child:SetParent(self.buttonBag)
                        child:SetFrameLevel(self.buttonBag:GetFrameLevel() + 2)
                        child:Show()
                        NormalizeButtonVisuals(child)
                    end
                end
            end
        end
    end
    
    -- Extracción directa de LibDBIcon-1.0
    local ldbIcon = _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)
    if ldbIcon and ldbIcon.GetButtonList then
        for _, btnName in pairs(ldbIcon:GetButtonList()) do
            local btn = ldbIcon:GetMinimapButton(btnName)
            if btn and btn:IsShown() and IsAddonLauncherButton(btn) and not IsIgnoredButton(btn:GetName()) and btn:GetParent() ~= self.buttonBag then
                local w, h = btn:GetWidth(), btn:GetHeight()
                if w > 2 and h > 2 and w < 60 and h < 60 and FindButtonIcon(btn) then
                    btn._ktOriginalParent = btn._ktOriginalParent or btn:GetParent()
                    btn:SetParent(self.buttonBag)
                    btn:SetFrameLevel(self.buttonBag:GetFrameLevel() + 2)
                    btn:Show()
                    NormalizeButtonVisuals(btn)
                end
            end
        end
    end
    
    -- Botones problemáticos conocidos explícitos
    local knownButtons = { _G.DetailsBaseFrameMinimap, _G.DetailsMinimapIcon, _G.LibDBIcon10_Details }
    for _, btn in ipairs(knownButtons) do
        if btn and type(btn) == "table" and btn.IsObjectType and btn:IsShown() and IsAddonLauncherButton(btn) and btn:GetParent() ~= self.buttonBag then
            local w, h = btn:GetWidth(), btn:GetHeight()
            if w > 2 and h > 2 and w < 60 and h < 60 and FindButtonIcon(btn) then
                btn._ktOriginalParent = btn._ktOriginalParent or btn:GetParent()
                btn:SetParent(self.buttonBag)
                btn:SetFrameLevel(self.buttonBag:GetFrameLevel() + 2)
                btn:Show()
                NormalizeButtonVisuals(btn)
            end
        end
    end
    -- Modern addons commonly register only in AddonCompartmentFrame and never
    -- create a Minimap child. Mirror every registered entry in the bag.
    local capturedButtonNames = {}
    for _, child in ipairs({self.buttonBag:GetChildren()}) do
        if child and not child._ktProxyCompartment and IsAddonLauncherButton(child) and not IsIgnoredButton(child:GetName()) and FindButtonIcon(child) then
            capturedButtonNames[#capturedButtonNames + 1] = child:GetName()
        end
    end

    local function HasCapturedButtonForEntry(entry)
        local entryIdentity = NormalizeButtonIdentity(entry and (entry.text or entry.name))
        if #entryIdentity < 4 then return false end
        local identities = { [entryIdentity] = true }
        for _, buttonName in ipairs(capturedButtonNames) do
            if IsRegisteredButtonDuplicate(buttonName, identities) then return true end
        end
        return false
    end

    local proxyCount = 0
    if CanIterateTable(registeredAddons) then
        for _, entry in ipairs(registeredAddons) do
            if type(entry) == "table" and type(entry.func) == "function" and not HasCapturedButtonForEntry(entry) then
                proxyCount = proxyCount + 1
                local proxy = self:GetCompartmentProxyButton(proxyCount)
                ConfigureCompartmentProxyButton(proxy, entry)
                NormalizeButtonVisuals(proxy)
            end
        end
    end
    for index = proxyCount + 1, #self.compartmentButtons do
        ConfigureCompartmentProxyButton(self.compartmentButtons[index], nil)
    end
    
    -- 2. Listar botones ya capturados
    for _, child in ipairs({self.buttonBag:GetChildren()}) do
        if child and child ~= self.buttonBag.toggle then
            if not child._ktProxyCompartment and (IsIgnoredButton(child:GetName()) or not IsAddonLauncherButton(child)) then
                ReleaseCapturedButton(child)
            elseif child._ktProxyCompartment then
                if child._ktProxyActive and NormalizeButtonVisuals(child) then
                    tinsert(buttons, child)
                end
            elseif not NormalizeButtonVisuals(child) then
                ReleaseCapturedButton(child)
            else
                child._ktSortName = NormalizeButtonIdentity(child:GetName())
                tinsert(buttons, child)
            end
        end
    end
    
    table.sort(buttons, function(a, b)
        local aKey = a._ktSortName or NormalizeButtonIdentity(a:GetName())
        local bKey = b._ktSortName or NormalizeButtonIdentity(b:GetName())
        if aKey == bKey then
            return tostring(a) < tostring(b)
        end
        return aKey < bKey
    end)
    
    -- 3. Layout
    local targetRows = math_max(1, self.db.rows or 3)
    local cols = math_max(1, math_ceil(#buttons / targetRows))
    local size = self.db.size or 28
    local spacing = self.db.spacing or 4
    local position = self.db.position or "LEFT"
    
    for i, btn in ipairs(buttons) do
        AnchorCapturedButton(btn, self.buttonBag, i, cols, size, spacing, position)
    end
    
    local rows = math_ceil(#buttons / cols)
    if rows == 0 then rows = 1 end
    self.buttonCount = #buttons
    self.buttonBag:SetWidth((size * cols) + (spacing * (cols + 1)))
    self.buttonBag:SetHeight((size * rows) + (spacing * (rows + 1)))
end

-- Strict collector. The previous implementation scanned MinimapCluster,
-- MinimapBackdrop, all of _G and every AddonCompartment entry, turning internal
-- Blizzard frames and the complete addon registry into physical drawer icons.
function Mod:CollectButtons()
    -- 5.0.4 behavior: the stricter 5.0.5 collector left the drawer empty and
    -- redirected clicks to a Blizzard compartment which may not exist.
    return self:LegacyCollectButtons()
end

-- Retained strict collector for diagnostics; not used by the live drawer.
function Mod:StrictCollectButtons()
    if not self.buttonBag then return end
    self.lastCollect = GetTime()
    local buttons = {}
    for _, child in ipairs({ Minimap:GetChildren() }) do
        local name = child:GetName()
        if not IsIgnoredButton(name)
            and not IsIgnoredButtonObject(child)
            and child:IsShown()
            and IsAddonLauncherButton(child) then
            local w, h = child:GetWidth(), child:GetHeight()
            if w > 2 and h > 2 and w < 60 and h < 60 and FindButtonIcon(child) then
                child._ktOriginalParent = child._ktOriginalParent or child:GetParent()
                child._ktOriginalWidth = child._ktOriginalWidth or w
                child._ktOriginalHeight = child._ktOriginalHeight or h
                if not child._ktOriginalPoints then
                    child._ktOriginalPoints = {}
                    for pointIndex = 1, child:GetNumPoints() do
                        child._ktOriginalPoints[pointIndex] = { child:GetPoint(pointIndex) }
                    end
                end
                child:SetParent(self.buttonBag)
                child:SetFrameLevel(self.buttonBag:GetFrameLevel() + 2)
                child:Show()
                NormalizeButtonVisuals(child)
            end
        end
    end

    for _, proxy in ipairs(self.compartmentButtons or {}) do
        ConfigureCompartmentProxyButton(proxy, nil)
    end

    for _, child in ipairs({ self.buttonBag:GetChildren() }) do
        if child and child ~= self.buttonBag.toggle and not child._ktProxyCompartment then
            if IsIgnoredButton(child:GetName()) or not IsAddonLauncherButton(child) then
                ReleaseCapturedButton(child)
            elseif child._ktRespectNativeVisibility and not child:IsShown() then
                -- Keep it captured, but do not reserve an empty drawer slot.
            elseif NormalizeButtonVisuals(child) then
                child._ktSortName = NormalizeButtonIdentity(child:GetName())
                buttons[#buttons + 1] = child
            else
                ReleaseCapturedButton(child)
            end
        end
    end

    table.sort(buttons, function(a, b)
        local aKey = a._ktSortName or NormalizeButtonIdentity(a:GetName())
        local bKey = b._ktSortName or NormalizeButtonIdentity(b:GetName())
        if aKey == bKey then return tostring(a) < tostring(b) end
        return aKey < bKey
    end)

    local targetRows = math_max(1, self.db.rows or 3)
    local cols = math_max(1, math_ceil(#buttons / targetRows))
    local size = self.db.size or 28
    local spacing = self.db.spacing or 4
    local position = self.db.position or "LEFT"
    for i, button in ipairs(buttons) do
        AnchorCapturedButton(button, self.buttonBag, i, cols, size, spacing, position)
    end

    local rows = math_ceil(#buttons / cols)
    if rows == 0 then rows = 1 end
    self.buttonCount = #buttons
    self.buttonBag:SetWidth((size * cols) + (spacing * (cols + 1)))
    self.buttonBag:SetHeight((size * rows) + (spacing * (rows + 1)))
end
