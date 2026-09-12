local _, ns = ...
local KT = ns.KT
local Mod = ns.Mod

local Skin = Mod:NewModule("Skin", "AceEvent-3.0", "AceHook-3.0")

local _skinned = setmetatable({}, { __mode = "k" })
local _hookedTrackers = setmetatable({}, { __mode = "k" })
local _headerColorHooks = setmetatable({}, { __mode = "k" })

local function GetFont()
    local db = KT.db and KT.db.profile and KT.db.profile.objectiveTracker
    local font = db and db.font
    if KT and KT.ResolveFontForLocale then
        return KT:ResolveFontForLocale(font, KT.FONT_PATH or "Fonts\\FRIZQT__.TTF")
    end
    if font then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local path = LSM:Fetch("font", font)
            if path then return path end
        end
    end
    return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end

local function GetAccent()
    local db = KT.db and KT.db.profile and KT.db.profile.objectiveTracker
    if db and db.colorMode == "custom" and db.customColor then
        return db.customColor.r, db.customColor.g, db.customColor.b
    end

    local skin = KT.db and KT.db.profile and KT.db.profile.skin
    if skin and skin.kullthranUIColorByClass then
        local _, class = UnitClass("player")
        if class then
            local r, g, b = GetClassColor(class)
            if type(r) == "table" and r.r then
                return r.r, r.g, r.b
            elseif r and g and b then
                return r, g, b
            end
        end
    end

    local color = (skin and skin.accentColor) or KT.BRAND_COLOR or { r = 0, g = 0.6, b = 1 }
    return color.r, color.g, color.b
end

local function GetQuestTitleColor()
    local db = KT.db and KT.db.profile and KT.db.profile.objectiveTracker
    if db and db.useBlizzardQuestColors then
        return nil, nil, nil
    end
    return GetAccent()
end

local function ApplyShadow(fs)
    if not fs then return end
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
end

local function StyleFontString(fs, size)
    if not fs or not fs.GetFont then return end
    local db = KT.db and KT.db.profile and KT.db.profile.objectiveTracker
    if not size then
        if db and db.fontSize then
            size = db.fontSize
        else
            local _, cur = fs:GetFont()
            size = cur or 12
        end
    else
        -- If size was explicitly provided (e.g. for sub-elements), scale it relative to the base font size if db is available
        if db and db.fontSize then
            local diff = size - 12 -- 12 is the base default in the old code
            size = db.fontSize + diff
        end
    end
    local outline = (db and db.fontOutline) or "OUTLINE"
    if outline == "NONE" then outline = "" end
    fs:SetFont(GetFont(), size, outline)
    ApplyShadow(fs)
end

local function SkinHeader(header)
    if not header then return end

    -- Hide decorative textures
    for _, k in ipairs({
        "Background", "Line", "LineSheen", "LineGlow", "Divider",
        "Sheen", "Glow", "Stripe",
    }) do
        local r = header[k]
        if r and r.SetTexture then r:SetTexture("") end
    end

    local text = header.Text
    local r, g, b = GetAccent()
    if text then
        text:SetTextColor(r, g, b)
        StyleFontString(text, 14)
    end

    -- Skin +/- collapse buttons
    local function SkinButton(btn)
        if not btn then return end
        if btn.GetNormalTexture and btn:GetNormalTexture() then btn:GetNormalTexture():SetVertexColor(r, g, b) end
        if btn.GetPushedTexture and btn:GetPushedTexture() then btn:GetPushedTexture():SetVertexColor(r, g, b) end
        if btn.GetHighlightTexture and btn:GetHighlightTexture() then btn:GetHighlightTexture():SetVertexColor(r, g, b) end
    end

    if header.CollapseButton then SkinButton(header.CollapseButton) end
    if header.MinimizeButton then SkinButton(header.MinimizeButton) end

    for _, child in ipairs({header:GetChildren()}) do
        local otype = child.GetObjectType and child:GetObjectType()
        if otype == "Button" and child ~= header.CollapseButton and child ~= header.MinimizeButton then
            local nt = child.GetNormalTexture and child:GetNormalTexture()
            if nt then
                SkinButton(child)
            end
        end
    end
end

local function ProcessBlockChildren(frame, depth)
    if not frame or depth > 3 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        local ok, otype = pcall(child.GetObjectType, child)
        if ok and (otype == "Frame" or otype == "Button") and not child.Tooltip and child ~= frame.poiButton then
            if child.GetRegions then
                for _, rg in ipairs({ child:GetRegions() }) do
                    local ot = rg.GetObjectType and rg:GetObjectType()
                    if ot == "FontString" then
                        StyleFontString(rg, 12)
                    end
                end
            end
            ProcessBlockChildren(child, depth + 1)
        end
    end
end

local function StyleObjectiveLine(line)
    if not line or not line.Text then return end
    StyleFontString(line.Text, 12)
    line.Text:SetTextColor(0.8, 0.8, 0.8) -- Gris claro
    if line.Dash then
        StyleFontString(line.Dash, 12)
        line.Dash:SetTextColor(0.8, 0.8, 0.8)
    end
end

local function SetBlockTitleAccent(block)
    local title = block and block.HeaderText
    if not title then return end
    local r, g, b = GetQuestTitleColor()
    if r then
        title:SetTextColor(r, g, b)
    end
end

local function EnsureBlockHoverColor(block)
    local button = block and block.HeaderButton
    if not button or _headerColorHooks[button] then return end
    _headerColorHooks[button] = true

    -- Preserve the KUI title color while retaining Blizzard's native button and click behavior.
    button:HookScript("OnEnter", function()
        local r, g, b = GetQuestTitleColor()
        if r then SetBlockTitleAccent(block) end
    end)
    button:HookScript("OnLeave", function()
        local r, g, b = GetQuestTitleColor()
        if r then SetBlockTitleAccent(block) end
    end)
end
local function StyleBlockText(block)
    if not block then return end
    EnsureBlockHoverColor(block)

    local headerText = block.HeaderText
    local firstFontString
    local accentR, accentG, accentB = GetQuestTitleColor()

    if block.GetRegions then
        for _, region in ipairs({ block:GetRegions() }) do
            local objectType = region.GetObjectType and region:GetObjectType()
            if objectType == "FontString" then
                firstFontString = firstFontString or region
                StyleFontString(region, 13)
                if region == headerText or (not headerText and region == firstFontString) then
                    if accentR then
                        region:SetTextColor(accentR, accentG, accentB)
                    end
                end
            end
        end
    end

    ProcessBlockChildren(block, 0)

    local lines = block.usedLines or block.lines
    if type(lines) == "table" then
        for _, line in pairs(lines) do
            StyleObjectiveLine(line)
        end
    end
end

local function SkinBlock(block)
    if not block then return end
    -- Blizzard owns the quest POI button, its atlas, state, highlight and click behavior.
    -- KUI only skins the surrounding text and block chrome.
    if _skinned[block] then
        EnsureBlockHoverColor(block)
        return
    end

    for _, k in ipairs({
        "Background", "HeaderBackground", "Stripe", "Sheen", "Glow",
        "Highlight", "ShineTop", "ShineBottom",
    }) do
        local region = block[k]
        if region and region.SetTexture then region:SetTexture("") end
    end

    StyleBlockText(block)
    _skinned[block] = true
end
local function HookTracker(tracker)
    if not tracker or _hookedTrackers[tracker] then return end
    _hookedTrackers[tracker] = true

    -- Avoid block taint for scenario and widget trackers (widget pool)
    if tracker == _G.ScenarioObjectiveTracker or tracker == _G.UIWidgetObjectiveTracker then
        if tracker.Header then SkinHeader(tracker.Header) end
        return
    end

    if tracker.Header then
        SkinHeader(tracker.Header)
        if tracker.Header.SetCollapsed then
            hooksecurefunc(tracker.Header, "SetCollapsed", function(self)
                SkinHeader(self)
            end)
        end
    end

    if tracker.AddBlock then
        hooksecurefunc(tracker, "AddBlock", function(_, block)
            SkinBlock(block)
        end)
    end

    if tracker.Update then
        hooksecurefunc(tracker, "Update", function()
            if tracker.usedBlocks then
                for _, byTemplate in pairs(tracker.usedBlocks) do
                    if type(byTemplate) == "table" then
                        for _, block in pairs(byTemplate) do
                            if type(block) == "table" then
                                SkinBlock(block)
                            end
                        end
                    end
                end
            end
        end)
    end

    -- Skin existing blocks
    if tracker.usedBlocks then
        for _, byTemplate in pairs(tracker.usedBlocks) do
            if type(byTemplate) == "table" then
                for _, block in pairs(byTemplate) do
                    if type(block) == "table" then
                        SkinBlock(block)
                    end
                end
            end
        end
    end
end

local SUB_TRACKERS = {
    "ScenarioObjectiveTracker",
    "UIWidgetObjectiveTracker",
    "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker",
    "AdventureObjectiveTracker",
    "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker",
    "ProfessionsRecipeTracker",
    "BonusObjectiveTracker",
    "WorldQuestObjectiveTracker",
    "InitiativeTasksObjectiveTracker",
}

    function KT.ObjectiveTrackerSkin_UpdateColors()
        for tracker in pairs(_hookedTrackers) do
            if tracker.Header then
                SkinHeader(tracker.Header)
            end
        end
        for block in pairs(_skinned) do
            StyleBlockText(block)
        end

        local background = _G.KT_TrackerBackground
        if background and background.topBorder then
            local r, g, b = GetAccent()
            background.topBorder:SetColorTexture(r, g, b, 1)
        end
        if KT.ObjectiveTrackerSkin_UpdateBgAlpha then
            KT.ObjectiveTrackerSkin_UpdateBgAlpha()
        end
    end

    KT.ObjectiveTrackerSkin_Refresh = KT.ObjectiveTrackerSkin_UpdateColors

local function Skin11_0_Tracker()
    local otf = _G.ObjectiveTrackerFrame
    if not otf or not otf.ScrollBox then return end
    
    local sb = otf.ScrollBox
    if sb.GetScrollTarget then
        local target = sb:GetScrollTarget()
        if target then
            for _, child in ipairs({target:GetChildren()}) do
                -- Typically Headers have .Text and .IsHeader (or similar),
                -- but checking for .Text is usually safe to just apply block styling
                -- and SkinBlock has an internal safeguard `if _skinned[block] then return end`
                if child.Text and child.SetCollapsed then
                    SkinHeader(child)
                else
                    SkinBlock(child)
                end
            end
        end
    end
end

local function InitTracker()
    local otf = _G.ObjectiveTrackerFrame
    if otf then
        local headerMenu = otf.HeaderMenu
        if headerMenu then
            headerMenu:Hide()
            headerMenu:SetAlpha(0)
            if headerMenu.SetHeight then headerMenu:SetHeight(0.001) end
            headerMenu:HookScript("OnShow", function(self) self:Hide() end)
        end
        if otf.Header and otf.Header ~= headerMenu then
            otf.Header:Hide()
            otf.Header:HookScript("OnShow", function(self) self:Hide() end)
        end
        if otf.NineSlice then otf.NineSlice:Hide() end
    end
    
    local modules = otf and (otf.modules or otf.MODULES)
    
    if modules then
        for _, t in ipairs(modules) do
            HookTracker(t)
        end
    end
    
    for _, name in ipairs(SUB_TRACKERS) do
        if _G[name] then
            HookTracker(_G[name])
        end
    end

    -- The tracker hooks above skin newly-added blocks as they are created.
    -- Keep one fallback pass for the modern ScrollBox contents, but do not
    -- rescan the complete child tree continuously from OnUpdate.
    Skin11_0_Tracker()
end

local function SetupBackgroundAndFading()
    if _G.KT_TrackerBackground then
        if KT.ObjectiveTrackerSkin_UpdateBgAlpha then KT.ObjectiveTrackerSkin_UpdateBgAlpha() end
        return
    end
    local TrackerState = CreateFrame("Frame")
    local bgFrame = CreateFrame("Frame", "KT_TrackerBackground", UIParent)
    bgFrame:SetFrameStrata("BACKGROUND")
    bgFrame:Hide()

    local function GetDB()
        return KT.db and KT.db.profile and KT.db.profile.objectiveTracker or {}
    end

    local function GetBackgroundOpacity(db)
        if db and db.solidBackground == true then
            return 1
        end
        return tonumber(db and db.bgAlpha) or 0
    end

    local function EnsureBackgroundVisuals()
        if not bgFrame.tex then
            bgFrame.tex = bgFrame:CreateTexture(nil, "BACKGROUND")
            bgFrame.tex:SetAllPoints()
        end
        if not bgFrame.solidTex then
            bgFrame.solidTex, bgFrame.solidWash = KT:ApplyTexturedSurface(bgFrame)
            bgFrame.solidTex:Hide()
            bgFrame.solidWash:Hide()
        end
        if not bgFrame.topBorder then
            bgFrame.topBorder = bgFrame:CreateTexture(nil, "OVERLAY")
            bgFrame.topBorder:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 0, 0)
            bgFrame.topBorder:SetPoint("TOPRIGHT", bgFrame, "TOPRIGHT", 0, 0)
            bgFrame.topBorder:SetHeight(2)
        end
    end

    local function ApplyBackgroundAppearance(db, fadeAlpha)
        local opacity = GetBackgroundOpacity(db)
        if opacity <= 0 or not _G.ObjectiveTrackerFrame then
            if bgFrame.topBorder then bgFrame.topBorder:Hide() end
            bgFrame:Hide()
            return
        end

        bgFrame:SetParent(_G.ObjectiveTrackerFrame)
        bgFrame:ClearAllPoints()
        bgFrame:SetPoint("TOPLEFT", _G.ObjectiveTrackerFrame, "TOPLEFT", -20, -20)
        bgFrame:SetPoint("BOTTOMRIGHT", _G.ObjectiveTrackerFrame, "BOTTOMRIGHT", 5, 0)
        EnsureBackgroundVisuals()
        bgFrame.solidMode = db.solidBackground == true
        bgFrame:SetIgnoreParentAlpha(bgFrame.solidMode)

        if db.solidBackground == true then
            -- Opaque KUI artwork: no gradient or world scene leaks through.
            bgFrame.tex:Hide()
            KT:ApplyTexturedSurface(bgFrame)

            local r, g, b = GetAccent()
            bgFrame.topBorder:SetColorTexture(r, g, b, 1)
            bgFrame.topBorder:SetAlpha(1)
            bgFrame.topBorder:Show()
        else
            bgFrame.solidTex:Hide()
            bgFrame.solidWash:Hide()
            bgFrame.tex:SetColorTexture(0, 0, 0, 1)
            bgFrame.tex:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 0))
            bgFrame.tex:SetAlpha(1)
            bgFrame.tex:Show()
            bgFrame.topBorder:Hide()
        end

        -- Solid means fully opaque; only the legacy gradient follows the fade alpha.
        bgFrame:SetAlpha(db.solidBackground == true and 1 or (opacity * (fadeAlpha or 1)))
        bgFrame:Show()
    end

    function KT.ObjectiveTrackerSkin_UpdateBgAlpha()
        ApplyBackgroundAppearance(GetDB(), 1)
    end

    local lastMouseState = false
    local idleTime = 0
    local isHiddenByRules = false
    local currentFadeAlpha = 1

    local function SafeBoolean(value, fallback)
        if _G.issecretvalue and _G.issecretvalue(value) then return fallback end
        if _G.canaccessvalue and not _G.canaccessvalue(value) then return fallback end
        return value == true
    end

    local function UpdateVisibilityRules()
        local db = GetDB()
        local lockdown = SafeBoolean(InCombatLockdown(), false)
        local unitCombat = SafeBoolean(UnitAffectingCombat("player"), lockdown)
        local inCombat = lockdown or unitCombat
        local _, instanceType = IsInInstance()
        
        isHiddenByRules = false
        if db.hideInCombat and inCombat then
            isHiddenByRules = true
        end
        if db.hideInArena and instanceType == "arena" then
            isHiddenByRules = true
        end
        if db.hideInDungeon and instanceType == "party" then
            isHiddenByRules = true
        end
        if db.hideInRaid and instanceType == "raid" then
            isHiddenByRules = true
        end
        
        local ownedByMythicPlus = KT._mplusTrackerOwnsObjectiveTracker == true
        if isHiddenByRules or ownedByMythicPlus then
            if _G.ObjectiveTrackerFrame then _G.ObjectiveTrackerFrame:SetAlpha(0) end
            if bgFrame then bgFrame:SetAlpha(0) end
        else
            if _G.ObjectiveTrackerFrame then _G.ObjectiveTrackerFrame:SetAlpha(currentFadeAlpha) end
            if bgFrame then
                local maxAlpha = GetBackgroundOpacity(db)
                bgFrame:SetAlpha(db.solidBackground == true and 1 or (maxAlpha * currentFadeAlpha))
            end
        end
    end

    TrackerState:RegisterEvent("PLAYER_REGEN_DISABLED")
    TrackerState:RegisterEvent("PLAYER_REGEN_ENABLED")
    TrackerState:RegisterEvent("PLAYER_ENTERING_WORLD")
    TrackerState:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    TrackerState:SetScript("OnEvent", UpdateVisibilityRules)

    KT.ObjectiveTrackerSkin_UpdateVisibility = UpdateVisibilityRules

    local fadeTimer = 0
    TrackerState:SetScript("OnUpdate", function(self, elapsed)
        if not _G.ObjectiveTrackerFrame then return end
        
        fadeTimer = fadeTimer + elapsed
        if fadeTimer < 0.1 then return end
        fadeTimer = 0
        
        if GetBackgroundOpacity(GetDB()) > 0 and
            (bgFrame:GetParent() ~= _G.ObjectiveTrackerFrame or not bgFrame.tex
                or bgFrame.solidMode ~= (GetDB().solidBackground == true)) then
            KT.ObjectiveTrackerSkin_UpdateBgAlpha()
        end
        
        local db = GetDB()
        local mouseOver = SafeBoolean(_G.ObjectiveTrackerFrame:IsMouseOver(), false)
        
        if isHiddenByRules or KT._mplusTrackerOwnsObjectiveTracker == true then
            _G.ObjectiveTrackerFrame:SetAlpha(0)
            if bgFrame then bgFrame:SetAlpha(0) end
            return
        end
        
        if mouseOver then
            idleTime = 0
            currentFadeAlpha = 1
        else
            idleTime = idleTime + 0.1
            if db.fadeDelay and db.fadeDelay > 0 and idleTime >= db.fadeDelay then
                currentFadeAlpha = 0.1
            else
                currentFadeAlpha = 1
            end
        end
        
        _G.ObjectiveTrackerFrame:SetAlpha(currentFadeAlpha)
        
        if GetBackgroundOpacity(db) > 0 then
            local minBottom = _G.ObjectiveTrackerFrame:GetTop() or 99999
            local maxTop = _G.ObjectiveTrackerFrame:GetBottom() or 0
            
            for _, child in ipairs({_G.ObjectiveTrackerFrame:GetChildren()}) do
                if child ~= bgFrame and child:IsShown() and child:GetAlpha() > 0 then
                    -- In 11.0, ignore the massive ScrollBox since its ScrollTarget is what matters
                    if child ~= _G.ObjectiveTrackerFrame.HeaderMenu and child ~= _G.ObjectiveTrackerFrame.ScrollBox then
                        local b = child:GetBottom()
                        local t = child:GetTop()
                        if b and b < minBottom then minBottom = b end
                        if t and t > maxTop then maxTop = t end
                    end
                end
            end
            
            if _G.ObjectiveTrackerFrame.ScrollBox and _G.ObjectiveTrackerFrame.ScrollBox.GetScrollTarget then
                local st = _G.ObjectiveTrackerFrame.ScrollBox:GetScrollTarget()
                if st and st:IsShown() then
                    local b = st:GetBottom()
                    local t = st:GetTop()
                    if b and b < minBottom then minBottom = b end
                    if t and t > maxTop then maxTop = t end
                end
            end
            
            if minBottom > 0 and minBottom < (_G.ObjectiveTrackerFrame:GetTop() or 9999) then
                local offsetBottom = minBottom - _G.ObjectiveTrackerFrame:GetBottom()
                local offsetTop = maxTop - (_G.ObjectiveTrackerFrame:GetTop() or 0)
                
                -- Add a slight 2px padding to top and bottom to wrap tightly
                bgFrame:SetPoint("TOPLEFT", _G.ObjectiveTrackerFrame, "TOPLEFT", -20, offsetTop + 2)
                bgFrame:SetPoint("BOTTOMRIGHT", _G.ObjectiveTrackerFrame, "BOTTOMRIGHT", 5, offsetBottom - 2)
            else
                bgFrame:SetPoint("TOPLEFT", _G.ObjectiveTrackerFrame, "TOPLEFT", -20, -20)
                bgFrame:SetPoint("BOTTOMRIGHT", _G.ObjectiveTrackerFrame, "BOTTOMRIGHT", 5, 0)
            end
            
            bgFrame:SetAlpha(db.solidBackground == true and 1 or (GetBackgroundOpacity(db) * currentFadeAlpha))
        end
    end)
    
    -- Ensure it initializes immediately so alpha is respected on load
    KT.ObjectiveTrackerSkin_UpdateBgAlpha()
end

local function CheckAndInit()
    local db = KT.db and KT.db.profile and KT.db.profile.objectiveTracker or {}
    if db.enable == false then return end
    InitTracker()
    SetupBackgroundAndFading()
end

local _sawOT, _loggedIn = false, false
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_ObjectiveTracker" then
        _sawOT = true
    elseif event == "PLAYER_LOGIN" then
        _loggedIn = true
    end
    if _sawOT and _loggedIn then
        f:UnregisterAllEvents()
        CheckAndInit()
    end
end)

local _isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if (_isLoaded and _isLoaded("Blizzard_ObjectiveTracker")) or _G.ObjectiveTrackerFrame then
    _sawOT = true
end
if IsLoggedIn() then
    _loggedIn = true
end
if _sawOT and _loggedIn then
    f:UnregisterAllEvents()
    CheckAndInit()
end
