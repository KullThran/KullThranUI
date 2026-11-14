--  Nameplates_Options.lua
--  Registers Nameplates options with KullThranUI.
--  All get/set calls go to KullThranUINameplatesDB and reuse the module's
--  refresh functions. This file does not touch rendering logic.
local ADDON_NAME, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

-- The shared layer of this panel lives in Nameplates_OptionsPreview.lua
local OptionsPreview = ns.OptionsPreview
-- The Display page's slots, style sections and cog popup live in Nameplates_OptionsSlots.lua
local OptionsSlots = ns.OptionsSlots
local LText = OptionsPreview.LText
local NPPreviewAccentRGB = OptionsPreview.AccentRGB
local NP_PREVIEW_ACCENT = OptionsPreview.Accent
local KT_BuildSliderCore = OptionsPreview.BuildSliderCore
local KT_BuildColorSwatch = OptionsPreview.BuildColorSwatch
local KT_RegisterWidgetRefresh = OptionsPreview.RegisterWidgetRefresh
local KT_ShowWidgetTooltip = OptionsPreview.ShowTooltip
local KT_HideWidgetTooltip = OptionsPreview.HideTooltip
local KT_DimSwatch = OptionsPreview.DimSwatch
local KT_DisabledTooltip = OptionsPreview.DisabledTooltip
local GetNPOptOutline = OptionsPreview.OptOutline
local ApplyNPAccentToIcon = OptionsPreview.ApplyAccentToIcon

-- Wait for KullThranUI to exist
local initFrame        = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if not KT then return end
    OptionsPreview.Setup("retail")
    OptionsSlots.Setup("retail")
    ns.OptionsDisplay.Setup("retail")
    ns.OptionsColors.Setup("retail")
    local PP                   = KT.PP

    -- Values pulled in from the addon namespace
    local defaults             = ns.defaults or _G.KullThranUINameplatesDefaults or {}
    local SetFSFont            = ns.SetFSFont
    local BAR_W                = tonumber(ns.BAR_W) or 168
    local plates               = ns.plates
    local GetNPOutline         = ns.GetNPOutline or function() return "OUTLINE" end

    local pcall                = pcall
    local pairs                = pairs

    -- Imported from Nameplates_OptionsPreview.lua under the names this panel uses
    local DB = OptionsPreview.DB
    local DBVal = OptionsPreview.DBVal
    local DBRaw = OptionsPreview.DBRaw
    local DBColor = OptionsPreview.DBColor
    local SetPVFont = OptionsPreview.PreviewFont
    local FadeOnHover = OptionsPreview.FadeOnHover
    local ColorAccess = OptionsPreview.ColorAccess
    local DimmableSwatch = OptionsPreview.DimmableSwatch
    local FormatThousands = OptionsPreview.FormatThousands
    local CastTargetTint = OptionsPreview.CastTargetTint
    local ClassTintSwatches = OptionsPreview.ClassTintSwatches
    local GetTopDebuffAlignValue = OptionsPreview.TopDebuffAlign
    local GetTopDebuffOffsetXValue = OptionsPreview.TopDebuffOffsetX
    local GetResolvedCastBarColor = OptionsPreview.CastBarColor
    local ApplyCastBarStateColor = OptionsPreview.SetCastBarColor
    local BuildDisplayCastBarColorSection = OptionsPreview.BuildCastBarColorSection
    local CallOnAllPlates = OptionsPreview.CallOnAllPlates
    local RefreshAllPlates = OptionsPreview.RefreshAllPlates
    local RefreshAllAuras = OptionsPreview.RefreshAllAuras
    local RefreshAllFonts = OptionsPreview.RefreshAllFonts
    local GlowColorPair = OptionsPreview.GlowColorPair
    local MarkerState = OptionsPreview.MarkerState
    local MarkerCfg = OptionsPreview.MarkerCfg
    local RebuildMarkerValues = OptionsPreview.RebuildMarkerValues
    local GetMarkerSlotValue = OptionsPreview.MarkerSlot
    local SetMarkerSlotValue = OptionsPreview.SetMarkerSlot
    local hbtValues, hbtOrder = OptionsPreview.TextureValues, OptionsPreview.TextureOrder
    local RandomizePreviewValues = OptionsPreview.RandomizeValues
    local UpdatePreview = OptionsPreview.UpdatePreview -- rebound to a wrapper by BuildDisplayPage
    ns.OptionsGeneral.Setup("retail", { UpdatePreview = function() UpdatePreview() end })
    local BuildNameplatePreview = OptionsPreview.BuildEnemy
    local BuildFriendlyNameplatePreview = OptionsPreview.BuildFriendly
    local AttachClickTargets = OptionsPreview.AttachClickTargets

    -- The preview frames, set once they are built
    local activePreview
    local activeFriendlyPreview
    local _displayHeaderBuilder     -- stored for page cache re-use
    local _colorPreviewRandomizeAll -- randomize all color preview fills/icons on tab switch
    local _displayInlinePreviewHost -- inline live preview host (Display tab)

    -- Preview toggles flipped by the eye icons, read by each preview refresh
    local previewFlags = OptionsPreview.flags

    -- Display page: live preview in the header, settings below
    local _updatePreviewHooked = false

    local _refreshAllPlatesHooked = false
    local _displayStickyPreviewShell

    local function GetNPFontValues()
        local values = {}
        if LSM then
            for _, name in ipairs(LSM:List("font")) do
                if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
                    values[name] = name
                end
            end
        end
        if not next(values) then
            local def = (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
            values[def] = def
        end
        values._menuOpts = {
            kind = "font",
            sharedMedia = true,
            resolve = function(name)
                return LSM and LSM:Fetch("font", name, true)
            end,
        }
        return values
    end

    local function GetCurrentNPFontValue()
        local current = DBVal("font") or defaults.font
        if KT and KT.IsLocalizedDefaultFont and KT:IsLocalizedDefaultFont(current) then
            current = (KT.GetDefaultFontName and KT:GetDefaultFontName()) or current
        end
        if LSM and type(current) == "string" then
            for _, name in ipairs(LSM:List("font")) do
                local fetched = LSM:Fetch("font", name, true)
                if current == name or fetched == current then
                    return name
                end
            end
        end
        if type(current) == "string" then
            local normalized = current:gsub("/", "\\"):lower()
            if normalized:find("interface\\addons\\kullthranui\\media\\fonts\\", 1, true) then
                return (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
            end
        end
        return current
    end

    local function RefreshNPTextStyle()
        RefreshAllFonts()
        if ns.RefreshFriendlyFontOverride then ns.RefreshFriendlyFontOverride() end
        if ns.RefreshFriendlyTextStyle then ns.RefreshFriendlyTextStyle() end
        UpdatePreview()
    end

    local function ClearOptionHostChildren(host)
        if not host then return end
        for _, child in ipairs({ host:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end
    end

    local function EnsureDisplayStickyPreviewFrame()
        if _displayStickyPreviewShell then return _displayStickyPreviewShell end

        local previewShell = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        _displayStickyPreviewShell = previewShell

        if KT.AddBackdrop then
            KT:AddBackdrop(previewShell, 0.025, 0.025, 0.03, 0.98)
        end
        if KT.AddBorder then
            KT:AddBorder(previewShell, 0.18, 0.18, 0.22, 1)
        end

        local previewTitle = previewShell:CreateFontString(nil, "OVERLAY")
        previewTitle:SetFont(KT.FONT_PATH, 10, "OUTLINE")
        KT:SetAccentTextColor(previewTitle, 1)
        previewTitle:SetPoint("TOPLEFT", 10, -8)
        previewTitle:SetText(LText("LIVE PREVIEW"))
        -- Glass card border (Widgets.lua W:PreviewCard).
        if KT.Widgets and KT.Widgets.PreviewCard then KT.Widgets:PreviewCard(previewShell) end
        previewShell._title = previewTitle

        local previewHost = CreateFrame("Frame", nil, previewShell)
        previewHost:SetPoint("TOPLEFT", previewShell, "TOPLEFT", 12, -24)
        previewHost:SetPoint("TOPRIGHT", previewShell, "TOPRIGHT", -12, -24)
        previewHost:SetHeight(1)
        previewShell._previewHost = previewHost

        previewShell:SetClipsChildren(true)
        previewHost:SetClipsChildren(false)

        -- The shell only hides for good when another page takes the sticky slot.
        previewShell:HookScript("OnHide", function(self)
            local menu = KT.MenuPrincipal
            if menu and menu._stickyPreviewFrame ~= self then ns.OptionsGroups.LeaveLayout(menu) end
        end)

        return previewShell
    end

    local function BuildDisplayStickyPreview(pageParent, previewMode)
        local previewShell = EnsureDisplayStickyPreviewFrame()
        if previewShell._title and KT.SetAccentTextColor then
            KT:SetAccentTextColor(previewShell._title, 1)
        end
        local pageW = pageParent:GetWidth() or 700

        previewShell._ktUseStickyPreview = true
        previewShell:SetParent(UIParent)
        previewShell:ClearAllPoints()
        previewShell:SetWidth(math.max(320, pageW - 4))
        previewShell:SetFrameStrata(pageParent:GetFrameStrata() or "MEDIUM")
        previewShell:SetFrameLevel((pageParent:GetFrameLevel() or 1) + 24)
        previewShell:Show()

        local previewHost = previewShell._previewHost
        previewHost:Show()

        local previewW = pageW

        if not activePreview then
            BuildNameplatePreview(previewHost, previewW)
            activePreview = OptionsPreview.GetEnemy()
        end
        if not activeFriendlyPreview then
            BuildFriendlyNameplatePreview(previewHost, previewW)
            activeFriendlyPreview = OptionsPreview.GetFriendly()
        end

        if previewMode == "enemy" then
            activePreview:SetParent(previewHost)
            activePreview:ClearAllPoints()
            activePreview:SetPoint("TOP", previewHost, "TOP", 0, 0)
            activePreview:SetScale(UIParent:GetEffectiveScale() / previewHost:GetEffectiveScale())
            activePreview:SetFrameStrata(previewShell:GetFrameStrata())
            activePreview:SetFrameLevel(previewShell:GetFrameLevel() + 10)
            activePreview:SetAlpha(1)
            if activePreview.Update then activePreview:Update() end
            activePreview:Show()
            if activeFriendlyPreview then activeFriendlyPreview:Hide() end
        else
            activeFriendlyPreview._parentW = previewW
            activeFriendlyPreview:SetParent(previewHost)
            activeFriendlyPreview:ClearAllPoints()
            activeFriendlyPreview:SetPoint("TOP", previewHost, "TOP", 0, 0)
            activeFriendlyPreview:SetFrameStrata(previewShell:GetFrameStrata())
            activeFriendlyPreview:SetFrameLevel(previewShell:GetFrameLevel() + 10)
            activeFriendlyPreview:SetAlpha(1)
            if activeFriendlyPreview.Update then activeFriendlyPreview:Update() end
            activeFriendlyPreview:Show()
            if activePreview then activePreview:Hide() end
        end

        local shownPreview = (previewMode == "enemy") and activePreview or activeFriendlyPreview
        local previewH = shownPreview:GetHeight() * (shownPreview:GetScale() or 1)
        local visiblePreviewH = math.max((previewMode == "enemy") and 96 or 82, previewH + 4)
        previewHost:SetHeight(visiblePreviewH)
        previewShell:SetHeight(24 + visiblePreviewH + 10)

        local stickyHost = KT.MenuPrincipal and KT.MenuPrincipal._stickyPreviewHost
        if stickyHost then
            if stickyHost.bgKT then stickyHost.bgKT:SetAlpha(0) end
            if stickyHost._ktBackdropTexture then stickyHost._ktBackdropTexture:SetAlpha(0) end
            if stickyHost._ktBorderFrame then stickyHost._ktBorderFrame:SetAlpha(0) end
        end

        KT:AttachStickyPreview(previewShell, {
            point = "TOP",
            relativePoint = "TOP",
            x = 0,
            y = 0,
            height = previewShell:GetHeight(),
            extraPad = 0,
        })
        previewShell:Show()
        return previewShell:GetHeight() + 7
    end

    local function BuildDisplayPage(want, parent, yOffset)
        local W = OptionsPreview.RowWidgets(KT.Widgets)
        local y = yOffset
        local _, h

        if want.enemyName then
            local header, row
            header, h = W:SectionHeader(parent, "ENEMY NAME", y)
            y = y - h
            row, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Enemy Name Text Size"),
                    min = 8,
                    max = 28,
                    step = 1,
                    getValue = function() return DBVal("textSlotTopSize") or defaults.textSlotTopSize end,
                    setValue = function(v)
                        DB().textSlotTopSize = v
                        RefreshNPTextStyle()
                    end,
                },
                { type = "label", text = "" })
            y = y - h
            ns.OptionsGroups.Register("enemyName", header, row._leftRegion)
            _, h = W:Spacer(parent, y, 14); y = y - h
        end

        if want.level then
            local function RefreshNameplateLevelSettings()
                if ns.RefreshNameplateLevels then
                    ns.RefreshNameplateLevels()
                else
                    for _, plate in pairs(plates) do
                        if plate.UpdateLevel then plate:UpdateLevel() end
                    end
                end
                UpdatePreview()
            end
            local levelFontValues, levelFontOrder = {}, {}
            if LSM and LSM.List then
                for _, fontName in ipairs(LSM:List("font")) do
                    levelFontValues[fontName] = fontName
                    levelFontOrder[#levelFontOrder + 1] = fontName
                end
            end
            local currentLevelFont = DBVal("levelFont") or defaults.levelFont
            if currentLevelFont and not levelFontValues[currentLevelFont] then
                levelFontValues[currentLevelFont] = currentLevelFont
                levelFontOrder[#levelFontOrder + 1] = currentLevelFont
            end
            local levelOutlineValues = {
                NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline",
                MONOCHROME = "Monochrome", OUTLINEMONOCHROME = "Monochrome Outline",
            }
            local levelOutlineOrder = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "OUTLINEMONOCHROME" }
            _, h = W:SectionHeader(parent, "NAMEPLATE LEVEL", y); y = y - h
            _, h = W:DualRow(parent, y,
                {
                    type = "toggle", text = LText("Show Enemy Level"),
                    getValue = function() return DBVal("showEnemyLevel") == true end,
                    setValue = function(v)
                        DB().showEnemyLevel = v and true or false
                        DB().showLevel = DB().showEnemyLevel
                        RefreshNameplateLevelSettings()
                    end,
                },
                {
                    type = "dropdown", text = LText("Level Font"), values = levelFontValues, order = levelFontOrder,
                    getValue = function() return DBVal("levelFont") or defaults.levelFont end,
                    setValue = function(v) DB().levelFont = v; RefreshNameplateLevelSettings() end,
                }); y = y - h
            _, h = W:DualRow(parent, y,
                {
                    type = "toggle", text = LText("Show Friendly Level"),
                    getValue = function() return DBVal("showFriendlyLevel") == true end,
                    setValue = function(v)
                        DB().showFriendlyLevel = v and true or false
                        RefreshNameplateLevelSettings()
                    end,
                },
                { type = "label", text = "" }); y = y - h
            _, h = W:DualRow(parent, y,
                {
                    type = "toggle", text = LText("Dynamic Level Layout"),
                    getValue = function() return DBVal("useDynamicNameplateLevelLayout") == true end,
                    setValue = function(v)
                        DB().useDynamicNameplateLevelLayout = v and true or false
                        RefreshNameplateLevelSettings()
                    end,
                },
                { type = "label", text = "" }); y = y - h
            _, h = W:DualRow(parent, y,
                {
                    type = "slider", text = LText("Level Font Size"), min = 6, max = 48, step = 1,
                    getValue = function() return tonumber(DBVal("levelFontSize")) or 11 end,
                    setValue = function(v) DB().levelFontSize = v; RefreshNameplateLevelSettings() end,
                },
                {
                    type = "dropdown", text = LText("Level Text Outline"), values = levelOutlineValues, order = levelOutlineOrder,
                    getValue = function() return DBVal("levelFontOutline") or "OUTLINE" end,
                    setValue = function(v) DB().levelFontOutline = v; RefreshNameplateLevelSettings() end,
                }); y = y - h
            _, h = W:DualRow(parent, y,
                {
                    type = "colorpicker", text = LText("Level Text Color"),
                    getValue = function() local c = DBVal("levelColor") or defaults.levelColor; return c.r or 1, c.g or 1, c.b or 1 end,
                    setValue = function(r, g, b) DB().levelColor = { r = r, g = g, b = b, a = 1 }; RefreshNameplateLevelSettings() end,
                },
                { type = "toggle", text = LText("Level Text Shadow"),
                    getValue = function() return DBVal("levelShadow") ~= false end,
                    setValue = function(v) DB().levelShadow = v and true or false; RefreshNameplateLevelSettings() end,
                }); y = y - h
            _, h = W:DualRow(parent, y,
                {
                    type = "slider", text = LText("Level X Offset"), min = -200, max = 200, step = 1,
                    getValue = function() return tonumber(DBVal("levelXOffset")) or 24 end,
                    setValue = function(v) DB().levelXOffset = v; RefreshNameplateLevelSettings() end,
                },
                {
                    type = "slider", text = LText("Level Y Offset"), min = -100, max = 200, step = 1,
                    getValue = function() return tonumber(DBVal("levelYOffset")) or 4 end,
                    setValue = function(v) DB().levelYOffset = v; RefreshNameplateLevelSettings() end,
                }); y = y - h
            _, h = W:Spacer(parent, y, 14); y = y - h
        end

        if want.topDebuffs then
            local topDebuffAlignValues = {
                ["left"] = "Left",
                ["center"] = "Center",
                ["right"] = "Right",
            }
            local topDebuffAlignOrder = { "left", "center", "right" }
            _, h = W:SectionHeader(parent, "TOP DEBUFFS", y); y = y - h
            _, h = W:Dropdown(parent, "Top Debuffs Default Position", y,
                topDebuffAlignValues,
                function() return GetTopDebuffAlignValue() end,
                function(v)
                    DB().topDebuffAlign = v
                    RefreshAllAuras()
                    UpdatePreview()
                end,
                topDebuffAlignOrder)
            y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Top Debuffs X Offset"),
                    min = -120,
                    max = 120,
                    step = 1,
                    getValue = function() return GetTopDebuffOffsetXValue() end,
                    setValue = function(v)
                        DB().topDebuffOffsetX = v
                        RefreshAllAuras()
                        UpdatePreview()
                    end,
                },
                { type = "label", text = LText("Fine tune top debuffs horizontally.") }); y = y - h
            _, h = W:Spacer(parent, y, 14); y = y - h
        end

        if want.friendly then
            local function friendlyPlayersOff()
                return DBVal("showFriendlyPlayers") == false and DBVal("friendlyShowDefaultNames") ~= true
            end
            local function friendlyNPCsOff()
                return DBVal("showFriendlyNPCs") ~= true
            end
            local friendlyDisplayHeader
            local friendlyPlayerModeRow
            local friendlyNPCDisplayRow
            local friendlyTextHeader
            local friendlyPlayerAlignRow
            local friendlyNPCTextRow

            friendlyDisplayHeader, h = W:SectionHeader(parent, "FRIENDLY DISPLAY", y); y = y - h

            friendlyPlayerModeRow, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Show Friendly Player Nameplates"),
                    getValue = function() return DBVal("showFriendlyPlayers") ~= false end,
                    setValue = function(v)
                        DB().showFriendlyPlayers = v
                        if v then DB().friendlyShowDefaultNames = false end
                        if SetCVar then
                            pcall(SetCVar, "nameplateShowFriendlyPlayers", v and 1 or 0)
                            pcall(SetCVar, "nameplateShowFriends", v and 1 or 0)
                        end
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        ns.RefreshStackingMotion()
                        KT:RefreshPage()
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Only Name - Friendly Players"),
                    getValue = function() return DBVal("friendlyPlayerNameOnly") ~= false end,
                    setValue = function(v)
                        DB().friendlyPlayerNameOnly = v
                        if SetCVar then
                            pcall(SetCVar, "nameplateShowOnlyNameForFriendlyPlayerUnits", v and 1 or 0)
                        end
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        KT:RefreshPage()
                    end,
                    disabled = friendlyPlayersOff,
                    disabledTooltip = LText("Show Friendly Player Nameplates"),
                }); y = y - h
            friendlyNPCDisplayRow, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Show Friendly NPC Nameplates"),
                    getValue = function() return DBVal("showFriendlyNPCs") == true end,
                    setValue = function(v)
                        DB().showFriendlyNPCs = v
                        if SetCVar then
                            pcall(SetCVar, "nameplateShowFriendlyNPCs", v and 1 or 0)
                            pcall(SetCVar, "nameplateShowFriendlyNpcs", v and 1 or 0)
                        end
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        KT:RefreshPage()
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Only Name - Friendly NPCs"),
                    tooltip = LText("Hide friendly NPC health bars and show only their names."),
                    getValue = function() return DBVal("friendlyNPCNameOnly") ~= false end,
                    setValue = function(v)
                        DB().friendlyNPCNameOnly = v
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        KT:RefreshPage()
                    end,
                    disabled = friendlyNPCsOff,
                    disabledTooltip = LText("Show Friendly NPC Nameplates"),
                }); y = y - h

            local friendlyInstanceModeValues = {
                name_only = LText("Only Name"),
                always = LText("KUI Health Bars"),
                never = LText("Hide Friendly Nameplates"),
            }
            local friendlyInstanceModeOrder = { "name_only", "always", "never" }

            _, h = W:DualRow(parent, y,
                {
                    type = "dropdown",
                    text = LText("Friendly Players in Instances"),
                    tooltip = LText("Choose how friendly player nameplates behave in dungeons, raids and scenarios."),
                    values = friendlyInstanceModeValues,
                    order = friendlyInstanceModeOrder,
                    getValue = function()
                        local value = DBVal("friendlyPlayersInInstances") or "name_only"
                        return friendlyInstanceModeValues[value] and value or "name_only"
                    end,
                    setValue = function(v)
                        DB().friendlyPlayersInInstances = v
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        KT:RefreshPage()
                    end,
                },
                {
                    type = "dropdown",
                    text = LText("Friendly NPCs in Instances"),
                    tooltip = LText("Choose how friendly NPC nameplates behave in dungeons, raids and scenarios."),
                    values = friendlyInstanceModeValues,
                    order = friendlyInstanceModeOrder,
                    getValue = function()
                        local value = DBVal("friendlyNPCsInInstances") or "name_only"
                        return friendlyInstanceModeValues[value] and value or "name_only"
                    end,
                    setValue = function(v)
                        DB().friendlyNPCsInInstances = v
                        if ns.UpdateFriendlyNameplateSystem then ns.UpdateFriendlyNameplateSystem() end
                        KT:RefreshPage()
                    end,
                }); y = y - h
            _, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Friendly Plate Distance"),
                    min = -50,
                    max = 50,
                    step = 1,
                    getValue = function() return DBVal("friendlyPlateYOffset") or 0 end,
                    setValue = function(v)
                        DB().friendlyPlateYOffset = v
                        if ns.RefreshFriendlyPlateYOffset then ns.RefreshFriendlyPlateYOffset() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyPlayerNameOnly") ~= false end,
                    disabledTooltip = LText("Requires friendly health bars"),
                },
                {
                    type = "slider",
                    text = LText("Name Only Distance"),
                    min = -50,
                    max = 50,
                    step = 1,
                    getValue = function() return DBVal("friendlyNameOnlyYOffset") or defaults.friendlyNameOnlyYOffset end,
                    setValue = function(v)
                        DB().friendlyNameOnlyYOffset = v
                        if ns.RefreshFriendlyNameOnlyOffset then ns.RefreshFriendlyNameOnlyOffset() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyPlayerNameOnly") == false end,
                    disabledTooltip = LText("Requires Name Only mode"),
                }); y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Friendly Bar Height"),
                    min = 6,
                    max = 40,
                    step = 1,
                    getValue = function() return DBVal("friendlyHealthBarHeight") or defaults.friendlyHealthBarHeight end,
                    setValue = function(v)
                        DB().friendlyHealthBarHeight = v
                        if ns.RefreshFriendlyPlateSize then ns.RefreshFriendlyPlateSize() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyPlayerNameOnly") ~= false end,
                    disabledTooltip = LText("Requires friendly health bars"),
                },
                {
                    type = "slider",
                    text = LText("Friendly Bar Width"),
                    min = 80,
                    max = 250,
                    step = 1,
                    getValue = function() return DBVal("friendlyHealthBarWidth") or defaults.friendlyHealthBarWidth end,
                    setValue = function(v)
                        DB().friendlyHealthBarWidth = v
                        if ns.RefreshFriendlyPlateSize then ns.RefreshFriendlyPlateSize() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyPlayerNameOnly") ~= false end,
                    disabledTooltip = LText("Requires friendly health bars"),
                }); y = y - h

            _, h = W:DualRow(parent, y,
                { type = "label", text = "" },
                {
                    type = "toggle",
                    text = LText("Show Friendly Health Percent"),
                    getValue = function() return not DBVal("friendlyHideHealthText") end,
                    setValue = function(v)
                        DB().friendlyHideHealthText = not v
                        if ns.RefreshFriendlyHealthText then ns.RefreshFriendlyHealthText() end
                    end,
                    disabled = function() return friendlyPlayersOff() or DBVal("friendlyPlayerNameOnly") ~= false end,
                    disabledTooltip = LText("Requires friendly health bars"),
                }); y = y - h

            _, h = W:Spacer(parent, y, 16); y = y - h
            friendlyTextHeader, h = W:SectionHeader(parent, "FRIENDLY TEXT", y); y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Friendly Class Colored Names"),
                    getValue = function() return DBVal("classColorFriendly") ~= false end,
                    setValue = function(v)
                        DB().classColorFriendly = v
                        if SetCVar then
                            pcall(SetCVar, "ShowClassColorInFriendlyNameplate", v and 1 or 0)
                            pcall(SetCVar, "nameplateUseClassColorForFriendlyPlayerUnitNames", v and 1 or 0)
                        end
                        RefreshNPTextStyle()
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Show Guild Under Friendly Players"),
                    getValue = function() return DBVal("friendlyShowGuild") ~= false end,
                    setValue = function(v)
                        DB().friendlyShowGuild = v
                        if ns.RefreshFriendlyTextStyle then ns.RefreshFriendlyTextStyle() end
                    end,
                    disabled = friendlyPlayersOff,
                    disabledTooltip = LText("Show Friendly Player Nameplates"),
                }); y = y - h

            friendlyPlayerAlignRow, h = W:DualRow(parent, y,
                {
                    type = "dropdown",
                    text = LText("Friendly Player Alignment"),
                    values = {
                        ["center"] = "Centered",
                        ["left"] = "From Left",
                        ["right"] = "From Right",
                    },
                    order = { "center", "left", "right" },
                    getValue = function()
                        return DBVal("friendlyPlayerNameAlignment") or defaults.friendlyPlayerNameAlignment
                    end,
                    setValue = function(v)
                        DB().friendlyPlayerNameAlignment = v
                        RefreshNPTextStyle()
                    end,
                },
                {
                    type = "dropdown",
                    text = LText("Friendly NPC Alignment"),
                    values = {
                        ["center"] = "Centered",
                        ["left"] = "From Left",
                        ["right"] = "From Right",
                    },
                    order = { "center", "left", "right" },
                    getValue = function()
                        return DBVal("friendlyNPCNameAlignment") or defaults.friendlyNPCNameAlignment
                    end,
                    setValue = function(v)
                        DB().friendlyNPCNameAlignment = v
                        RefreshNPTextStyle()
                    end,
                }); y = y - h

            friendlyNPCTextRow, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Friendly Player Name Size"),
                    min = 8,
                    max = 24,
                    step = 1,
                    getValue = function() return DBVal("friendlyPlayerNameTextSize") or defaults.friendlyPlayerNameTextSize end,
                    setValue = function(v)
                        DB().friendlyPlayerNameTextSize = v
                        RefreshNPTextStyle()
                    end,
                },
                {
                    type = "slider",
                    text = LText("Friendly NPC Name Size"),
                    min = 8,
                    max = 24,
                    step = 1,
                    getValue = function() return DBVal("friendlyNPCNameTextSize") or defaults.friendlyNPCNameTextSize end,
                    setValue = function(v)
                        DB().friendlyNPCNameTextSize = v
                        RefreshNPTextStyle()
                    end,
                }); y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "slider",
                    text = LText("Friendly Guild Size"),
                    min = 8,
                    max = 20,
                    step = 1,
                    getValue = function() return DBVal("friendlyGuildTextSize") or defaults.friendlyGuildTextSize end,
                    setValue = function(v)
                        DB().friendlyGuildTextSize = v
                        RefreshNPTextStyle()
                    end,
                },
                {
                    type = "slider",
                    text = LText("Friendly Health Text Size"),
                    min = 8,
                    max = 20,
                    step = 1,
                    getValue = function() return DBVal("friendlyHealthTextSize") or defaults.friendlyHealthTextSize end,
                    setValue = function(v)
                        DB().friendlyHealthTextSize = v
                        RefreshNPTextStyle()
                    end,
                }); y = y - h

            do
                local preview = activeFriendlyPreview
                if preview then
                    local function ScrollToTarget(section, target)
                        if not (section and target and KT and KT.SmoothScrollTo) then return end
                        local _, _, _, _, headerY = section:GetPoint(1)
                        if not headerY then return end
                        KT.SmoothScrollTo(math.max(0, math.abs(headerY) - 40))
                        C_Timer.After(0.15, function()
                            if not target then return end
                            local glow = target._friendlyPreviewGlow
                            if not glow then
                                glow = CreateFrame("Frame", nil, target)
                                glow:SetAllPoints(target)
                                glow:SetFrameLevel(target:GetFrameLevel() + 8)
                                local edges = {}
                                local function edge()
                                    local t = glow:CreateTexture(nil, "OVERLAY", nil, 7)
                                    t:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, 1)
                                    edges[#edges + 1] = t
                                    return t
                                end
                                local top = edge()
                                top:SetPoint("TOPLEFT")
                                top:SetPoint("TOPRIGHT")
                                top:SetHeight(2)
                                local bottom = edge()
                                bottom:SetPoint("BOTTOMLEFT")
                                bottom:SetPoint("BOTTOMRIGHT")
                                bottom:SetHeight(2)
                                local left = edge()
                                left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
                                left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
                                left:SetWidth(2)
                                local right = edge()
                                right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
                                right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
                                right:SetWidth(2)
                                glow._edges = edges
                                target._friendlyPreviewGlow = glow
                            end
                            glow:SetAlpha(1)
                            glow:Show()
                            glow:SetScript("OnUpdate", function(self, dt)
                                self._elapsed = (self._elapsed or 0) + dt
                                if self._elapsed >= 0.75 then
                                    self._elapsed = nil
                                    self:SetAlpha(0)
                                    self:Hide()
                                    self:SetScript("OnUpdate", nil)
                                    return
                                end
                                self:SetAlpha(1 - self._elapsed / 0.75)
                            end)
                        end)
                    end

                    local function EnsurePreviewNavButton(key, anchor, section, target, tooltip)
                        if not anchor then return end
                        local btn = preview[key]
                        if not btn then
                            btn = CreateFrame("Button", nil, preview)
                            btn:EnableMouse(true)
                            btn:RegisterForClicks("LeftButtonDown")
                            local edges = {}
                            local function edge()
                                local t = btn:CreateTexture(nil, "OVERLAY", nil, 7)
                                t:SetColorTexture(NP_PREVIEW_ACCENT.r, NP_PREVIEW_ACCENT.g, NP_PREVIEW_ACCENT.b, 1)
                                edges[#edges + 1] = t
                                return t
                            end
                            local top = edge()
                            top:SetPoint("TOPLEFT")
                            top:SetPoint("TOPRIGHT")
                            top:SetHeight(2)
                            local bottom = edge()
                            bottom:SetPoint("BOTTOMLEFT")
                            bottom:SetPoint("BOTTOMRIGHT")
                            bottom:SetHeight(2)
                            local left = edge()
                            left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
                            left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
                            left:SetWidth(2)
                            local right = edge()
                            right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
                            right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
                            right:SetWidth(2)
                            btn._edges = edges
                            for _, tex in ipairs(edges) do tex:Hide() end
                            btn:SetScript("OnEnter", function(self)
                                for _, tex in ipairs(self._edges or {}) do tex:Show() end
                                if tooltip then KT_ShowWidgetTooltip(self, tooltip, { width = 180 }) end
                            end)
                            btn:SetScript("OnLeave", function(self)
                                for _, tex in ipairs(self._edges or {}) do tex:Hide() end
                                KT_HideWidgetTooltip()
                            end)
                            preview[key] = btn
                        end
                        btn:SetScript("OnMouseDown", function()
                            ScrollToTarget(section, target)
                        end)
                        btn:ClearAllPoints()
                        btn:SetAllPoints(anchor)
                        btn:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or preview:GetFrameLevel()) + 10)
                        btn:Show()
                    end

                    EnsurePreviewNavButton("_playerNavBtn", preview._player, friendlyTextHeader, friendlyPlayerAlignRow,
                        "Open Friendly Player settings")
                    EnsurePreviewNavButton("_npcNavBtn", preview._npc, friendlyTextHeader, friendlyNPCTextRow,
                        "Open Friendly NPC settings")
                end
            end

            return math.abs(y)
        end

        return math.abs(y)
    end

    -- The Colors page lives in Nameplates_OptionsColors.lua

    --  Threat page  (coloring priorities + threat/unit-type colors)
    local function BuildThreatPage(parent, yOffset)
        local W = OptionsPreview.RowWidgets(KT.Widgets)
        local y = yOffset
        local _, h

        parent._showRowDivider = true

        local function RefreshThreatColors()
            for _, plate in pairs(plates or {}) do
                if plate.UpdateHealthColor then plate:UpdateHealthColor() end
            end
            UpdatePreview()
        end

        local function CGet(key)
            local c = DBRaw(key)
            if type(c) ~= "table" then return 1, 1, 1 end
            return c.r or 1, c.g or 1, c.b or 1
        end
        local function CSet(key, r, g, b)
            DB()[key] = { r = r, g = g, b = b }
            RefreshThreatColors()
        end

        local function BoolGet(key, fallback)
            if DBVal(key) ~= nil then return DBVal(key) end
            return fallback
        end

        local function BoolSet(key, v)
            DB()[key] = v
            RefreshThreatColors()
            KT:RefreshPage()
        end

        local function MakeSwatchRow(labelText, colorKey, disabledFn)
            local row
            row, h = W:Label(parent, labelText, y, 11, { r = 0.75, g = 0.75, b = 0.75 }); y = y - h
            local swatch, updateSwatch = KT_BuildColorSwatch(row, row:GetFrameLevel() + 5,
                function() return CGet(colorKey) end,
                function(r, g, b) CSet(colorKey, r, g, b) end,
                nil,
                20)
            PP.Point(swatch, "RIGHT", row, "RIGHT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                if disabledFn then
                    local off = disabledFn()
                    swatch:SetAlpha(off and 0.15 or 1)
                    swatch:EnableMouse(not off)
                end
                updateSwatch()
            end)
            if disabledFn then
                local off = disabledFn()
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
            end
            return row
        end

        local tankHeader
        tankHeader, h = W:SectionHeader(parent, "COLOR WHEN PLAYING AS TANK", y); y = y - h
        MakeSwatchRow("Aggro on You", "tankHasAggro")
        MakeSwatchRow("Aggro on You But is Low", "tankLosingAggro")
        MakeSwatchRow("Other Tank Has Aggro", "tankOtherTankHasAggro")
        MakeSwatchRow("No Aggro", "tankNoAggro")

        _, h = W:Spacer(parent, y, 12); y = y - h

        local dpsHeader
        dpsHeader, h = W:SectionHeader(parent, "COLOR WHEN PLAYING AS DPS OR HEALER", y); y = y - h
        MakeSwatchRow("Aggro on You", "dpsHasAggro")
        MakeSwatchRow("High Threat", "dpsNearAggro")
        MakeSwatchRow("No Aggro", "dpsNoAggro")

        _, h = W:Spacer(parent, y, 12); y = y - h

        local threatHeader
        threatHeader, h = W:SectionHeader(parent, "THREAT APPLIES TO", y); y = y - h

        local modifiesRow
        modifiesRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Health Bar Color"),
                getValue = function() return DBVal("threatModHealth") ~= false end,
                setValue = function(v) BoolSet("threatModHealth", v) end
            },
            {
                type = "toggle",
                text = LText("Border Color"),
                getValue = function() return DBVal("threatModBorder") == true end,
                setValue = function(v) BoolSet("threatModBorder", v) end
            }); y = y - h

        local modifiesRow2
        modifiesRow2, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Name Color"),
                getValue = function() return DBVal("threatModName") == true end,
                setValue = function(v) BoolSet("threatModName", v) end
            },
            {
                type = "toggle",
                text = LText("Use 'Solo' color"),
                getValue = function() return DBVal("threatUseSoloColor") == true end,
                setValue = function(v) BoolSet("threatUseSoloColor", v) end
            }); y = y - h

        -- Solo color swatch inline on the right control
        do
            local rightRgn = modifiesRow2._rightRegion
            local swatch, updateSwatch = KT_BuildColorSwatch(rightRgn, rightRgn:GetFrameLevel() + 5,
                function() return CGet("threatSoloColor") end,
                function(r, g, b) CSet("threatSoloColor", r, g, b) end,
                nil,
                20)
            PP.Point(swatch, "RIGHT", rightRgn._control, "LEFT", -12, 0)
            KT_RegisterWidgetRefresh(function()
                local off = DBVal("threatUseSoloColor") ~= true
                swatch:SetAlpha(off and 0.15 or 1)
                swatch:EnableMouse(not off)
                updateSwatch()
            end)
            local off = DBVal("threatUseSoloColor") ~= true
            swatch:SetAlpha(off and 0.15 or 1)
            swatch:EnableMouse(not off)
        end

        _, h = W:Spacer(parent, y, 12); y = y - h

        local overrideHeader
        overrideHeader, h = W:SectionHeader(parent, "OVERRIDE DEFAULT COLORS", y); y = y - h

        local overrideRow
        overrideRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enabled"),
                getValue = function() return DBVal("colorOverrideEnabled") == true end,
                setValue = function(v) BoolSet("colorOverrideEnabled", v) end
            },
            { type = "label", text = "" }); y = y - h

        local function OverrideOff() return DBVal("colorOverrideEnabled") ~= true end
        MakeSwatchRow("Hostile", "hostile", OverrideOff)
        MakeSwatchRow("Neutral", "neutral", OverrideOff)
        MakeSwatchRow("Friendly", "friendly", OverrideOff)
        MakeSwatchRow("Unit Not In Combat", "enemyOutOfCombat", OverrideOff)
        MakeSwatchRow("Unit Tapped", "tapped", OverrideOff)

        _, h = W:Spacer(parent, y, 12); y = y - h

        local miscHeader
        miscHeader, h = W:SectionHeader(parent, "MISC", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enable aggro flash"),
                getValue = function() return DBVal("showAggroFlash") == true end,
                setValue = function(v) BoolSet("showAggroFlash", v) end
            },
            {
                type = "toggle",
                text = LText("Enable health bar aggro glow"),
                getValue = function() return DBVal("showAggroGlow") == true end,
                setValue = function(v) BoolSet("showAggroGlow", v) end
            }); y = y - h

        _, h = W:Spacer(parent, y, 12); y = y - h

        local unitTypeHeader
        unitTypeHeader, h = W:SectionHeader(parent, "UNIT TYPE COLORING", y); y = y - h

        local typeRow
        typeRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enabled"),
                getValue = function() return DBVal("unitTypeColoringEnabled") ~= false end,
                setValue = function(v) BoolSet("unitTypeColoringEnabled", v) end
            },
            {
                type = "toggle",
                text = LText("Don't override Threat colors"),
                getValue = function() return DBVal("unitTypeColoringNoOverrideThreat") ~= false end,
                setValue = function(v) BoolSet("unitTypeColoringNoOverrideThreat", v) end
            }); y = y - h

        local function UnitTypeOff() return DBVal("unitTypeColoringEnabled") == false end
        MakeSwatchRow("Boss", "boss", UnitTypeOff)
        MakeSwatchRow("Miniboss", "miniboss", UnitTypeOff)
        MakeSwatchRow("Caster", "caster", UnitTypeOff)

        local eliteRow
        eliteRow, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enable elite"),
                getValue = function() return DBVal("unitTypeColoringEnableElite") == true end,
                setValue = function(v) BoolSet("unitTypeColoringEnableElite", v) end
            },
            {
                type = "toggle",
                text = LText("Enable trivial"),
                getValue = function() return DBVal("unitTypeColoringEnableTrivial") == true end,
                setValue = function(v) BoolSet("unitTypeColoringEnableTrivial", v) end
            }); y = y - h

        local function EliteOff()
            return UnitTypeOff() or (DBVal("unitTypeColoringEnableElite") ~= true)
        end
        local function TrivialOff()
            return UnitTypeOff() or (DBVal("unitTypeColoringEnableTrivial") ~= true)
        end
        MakeSwatchRow("Elite", "elite", EliteOff)
        MakeSwatchRow("Trivial", "trivial", TrivialOff)

        return math.abs(y)
    end

    --  Special / Auto / Advanced pages
    local function BuildSpecialPage(mode, parent, yOffset)
        local W = OptionsPreview.RowWidgets(KT.Widgets)
        local y = yOffset
        local _, h
        parent._showRowDivider = true
        local function StyleSpecialButton(btn, accent)
            btn:SetPushedTextOffset(0, 0)
            btn:SetMotionScriptsWhileDisabled(true)

            local label = btn:CreateFontString(nil, "OVERLAY")
            label:SetFont(KT.FONT_PATH, 11, "OUTLINE")
            label:SetPoint("CENTER")
            btn.txt = label

            local function RefreshVisual(state)
                local bg = { 0.06, 0.06, 0.07, 1 }
                local border = { 0.20, 0.20, 0.24, 0.90 }
                local text = { 0.90, 0.90, 0.90, 1 }

                if accent then
                    local r, g, b = NPPreviewAccentRGB()
                    bg = { 0.10, 0.07, 0.07, 1 }
                    border = { r, g, b, 0.85 }
                    text = { 1, 1, 1, 1 }
                end

                if state == "hover" then
                    border = { 0.60, 0.60, 0.70, 1 }
                elseif state == "down" then
                    local r, g, b = NPPreviewAccentRGB()
                    bg = { 0.12, 0.08, 0.08, 1 }
                    border = { r, g, b, 1 }
                end

                KT:AddBackdrop(btn, bg[1], bg[2], bg[3], bg[4])
                KT:AddBorder(btn, border[1], border[2], border[3], border[4])
                if btn.txt then btn.txt:SetTextColor(text[1], text[2], text[3], text[4]) end
            end

            RefreshVisual()
            btn:SetScript("OnEnter", function(self) RefreshVisual("hover") end)
            btn:SetScript("OnLeave", function(self) RefreshVisual() end)
            btn:SetScript("OnMouseDown", function(self)
                if self:IsEnabled() then
                    if self.txt then self.txt:SetPoint("CENTER", 0, -1) end
                    RefreshVisual("down")
                end
            end)
            btn:SetScript("OnMouseUp", function(self)
                if self.txt then self.txt:SetPoint("CENTER") end
                RefreshVisual(self:IsMouseOver() and "hover" or nil)
            end)
        end

        if mode == "buff" then
            _, h = W:SectionHeader(parent, "BUFF SPECIAL", y); y = y - h

            _, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Enabled"),
                    getValue = function() return DBVal("specialAurasEnabled") == true end,
                    setValue = function(v)
                        DB().specialAurasEnabled = v
                        UpdatePreview()
                        KT:RefreshPage()
                    end
                },
                { type = "label", text = "" }); y = y - h

            _, h = W:Label(parent,
                LText("Paste Spell IDs (one per line). Click Apply to rebuild the Special Auras list.") .. "\n" ..
                LText("Example:") .. "\n339\n8921\n774",
                y, 11, { r = 0.65, g = 0.65, b = 0.65 }); y = y - h

            local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            box:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
            box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
            box:SetHeight(160)
            KT:AddBackdrop(box, 0.06, 0.06, 0.07, 1)
            KT:AddBorder(box, 0.20, 0.20, 0.24, 0.9)

            local edit = CreateFrame("EditBox", nil, box)
            edit:SetMultiLine(true)
            edit:SetAutoFocus(false)
            edit:SetFont(KT.FONT_PATH, 11, "OUTLINE")
            edit:SetTextColor(1, 1, 1, 1)
            edit:SetPoint("TOPLEFT", 10, -10)
            edit:SetPoint("BOTTOMRIGHT", -10, 10)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

            local function NormalizeSpecialInput(s)
                s = tostring(s or "")
                s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
                s = s:gsub("[ \t]+", " ")
                return s
            end

            local function BuildSpecialSetFromText(s)
                local set = {}
                for id in tostring(s or ""):gmatch("(%d+)") do
                    local n = tonumber(id)
                    if n and n > 0 then set[n] = true end
                end
                return set
            end

            local cur = DBVal("specialAurasInput") or ""
            edit:SetText(NormalizeSpecialInput(cur))
            edit:SetScript("OnTextChanged", function(self)
                DB().specialAurasInput = NormalizeSpecialInput(self:GetText())
            end)

            y = y - (box:GetHeight() + 10)

            local btnRow = CreateFrame("Frame", nil, parent)
            btnRow:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
            btnRow:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
            btnRow:SetHeight(34)

            local applyBtn = CreateFrame("Button", nil, btnRow, "BackdropTemplate")
            applyBtn:SetSize(126, 26)
            applyBtn:SetPoint("LEFT", 0, 0)
            StyleSpecialButton(applyBtn, true)
                applyBtn.txt:SetText(LText("Apply"))
            applyBtn:SetScript("OnClick", function()
                local text = NormalizeSpecialInput(edit:GetText())
                DB().specialAurasInput = text
                DB().specialAuras = BuildSpecialSetFromText(text)
                UpdatePreview()
                KT:RefreshPage()
            end)

            local clearBtn = CreateFrame("Button", nil, btnRow, "BackdropTemplate")
            clearBtn:SetSize(126, 26)
            clearBtn:SetPoint("LEFT", applyBtn, "RIGHT", 10, 0)
            StyleSpecialButton(clearBtn, false)
                clearBtn.txt:SetText(LText("Clear"))
            clearBtn:SetScript("OnClick", function()
                DB().specialAurasInput = ""
                DB().specialAuras = {}
                edit:SetText("")
                UpdatePreview()
                KT:RefreshPage()
            end)

            y = y - (btnRow:GetHeight() + 10)
        end

        local function RefreshPriorityRuleColors()
            for _, plate in pairs(ns.plates or {}) do
                if plate.UpdateAuras then plate:UpdateAuras() end
                if plate.UpdateHealthColor then plate:UpdateHealthColor() end
            end
            UpdatePreview()
            KT:RefreshPage()
        end

        local function NormalizeRuleInput(text)
            text = tostring(text or "")
            text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
            return text
        end

        local function BuildRuleSetFromText(text)
            local rules = { ids = {}, names = {} }
            for token in NormalizeRuleInput(text):gmatch("[^,\n]+") do
                token = token:gsub("^%s+", ""):gsub("%s+$", "")
                if token ~= "" then
                    local id = tonumber(token)
                    if id and id > 0 then
                        rules.ids[id] = true
                    else
                        rules.names[token:lower()] = true
                    end
                end
            end
            return rules
        end

        local function BuildRuleEditor(sectionTitle, toggleKey, inputKey, compiledKey, buildFn, colorKey, textureKey, helpText, textureText)
            local row
            _, h = W:Spacer(parent, y, 14); y = y - h
            _, h = W:SectionHeader(parent, sectionTitle, y); y = y - h

            row, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Enabled"),
                    getValue = function() return DBVal(toggleKey) == true end,
                    setValue = function(v)
                        DB()[toggleKey] = v
                        RefreshPriorityRuleColors()
                    end
                },
                {
                    type = "dropdown",
                    text = textureText,
                    values = hbtValues,
                    order = hbtOrder,
                    getValue = function() return DBVal(textureKey) or defaults[textureKey] or "Melli Reforged" end,
                    setValue = function(v)
                        DB()[textureKey] = v
                        RefreshPriorityRuleColors()
                    end
                }); y = y - h

            do
                local leftRgn = row and row._leftRegion
                if leftRgn and leftRgn._control then
                    local swatch, updateSwatch = KT_BuildColorSwatch(leftRgn, leftRgn:GetFrameLevel() + 5,
                        function()
                            return DBColor(colorKey)
                        end,
                        function(r, g, b)
                            DB()[colorKey] = { r = r, g = g, b = b }
                            RefreshPriorityRuleColors()
                        end,
                        nil, 20)
                    PP.Point(swatch, "RIGHT", leftRgn._control, "LEFT", -12, 0)
                    KT_RegisterWidgetRefresh(function()
                        local off = DBVal(toggleKey) ~= true
                        swatch:SetAlpha(off and 0.15 or 1)
                        swatch:EnableMouse(not off)
                        updateSwatch()
                    end)
                    local off = DBVal(toggleKey) ~= true
                    swatch:SetAlpha(off and 0.15 or 1)
                    swatch:EnableMouse(not off)
                end
            end

            _, h = W:Label(parent, helpText, y, 11, { r = 0.65, g = 0.65, b = 0.65 }); y = y - h

            local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            box:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
            box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
            box:SetHeight(110)
            KT:AddBackdrop(box, 0.06, 0.06, 0.07, 1)
            KT:AddBorder(box, 0.20, 0.20, 0.24, 0.9)

            local editBox = CreateFrame("EditBox", nil, box)
            editBox:SetMultiLine(true)
            editBox:SetAutoFocus(false)
            editBox:SetFont(KT.FONT_PATH, 11, "OUTLINE")
            editBox:SetTextColor(1, 1, 1, 1)
            editBox:SetPoint("TOPLEFT", 10, -10)
            editBox:SetPoint("BOTTOMRIGHT", -10, 10)
            editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            editBox:SetText(NormalizeRuleInput(DBVal(inputKey) or ""))
            editBox:SetScript("OnTextChanged", function(self)
                DB()[inputKey] = NormalizeRuleInput(self:GetText())
            end)

            y = y - (box:GetHeight() + 10)

            local btnFrame = CreateFrame("Frame", nil, parent)
            btnFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
            btnFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
            btnFrame:SetHeight(34)

            local apply = CreateFrame("Button", nil, btnFrame, "BackdropTemplate")
            apply:SetSize(126, 26)
            apply:SetPoint("LEFT", 0, 0)
            StyleSpecialButton(apply, true)
            apply.txt:SetText(LText("Apply"))
            apply:SetScript("OnClick", function()
                local text = NormalizeRuleInput(editBox:GetText())
                DB()[inputKey] = text
                DB()[compiledKey] = buildFn(text)
                RefreshPriorityRuleColors()
            end)

            local clear = CreateFrame("Button", nil, btnFrame, "BackdropTemplate")
            clear:SetSize(126, 26)
            clear:SetPoint("LEFT", apply, "RIGHT", 10, 0)
            StyleSpecialButton(clear, false)
            clear.txt:SetText(LText("Clear"))
            clear:SetScript("OnClick", function()
                DB()[inputKey] = ""
                DB()[compiledKey] = buildFn("")
                editBox:SetText("")
                RefreshPriorityRuleColors()
            end)

            y = y - (btnFrame:GetHeight() + 10)
            return row
        end

        if mode == "rules" then
            BuildRuleEditor(
                "PRIORITY TARGETS",
                "priorityTargetsEnabled",
                "priorityTargetsInput",
                "priorityTargetsCompiled",
                function(text) return (ns.BuildPriorityTargetsFromText and ns.BuildPriorityTargetsFromText(text)) or BuildRuleSetFromText(text) end,
                "priorityTargetsColor",
                "priorityTargetsTexture",
                "Add mob names or NPC IDs, one per line or separated by commas.\nExample:\nDungeon Training Dummy\n229249",
                "Priority Texture"
            )

            local auraRow = BuildRuleEditor(
                "AURA HEALTH OVERRIDE",
                "auraPriorityEnabled",
                "auraPriorityInput",
                "auraPriorityCompiled",
                function(text) return (ns.BuildAuraPrioritySpellsFromText and ns.BuildAuraPrioritySpellsFromText(text)) or BuildRuleSetFromText(text) end,
                "auraPriorityColor",
                "auraPriorityTexture",
                "Add spell names or spell IDs from your debuffs, one per line or separated by commas.\nExample:\nMoonfire\nSunfire\n8921",
                "Aura Texture"
            )

            _, h = W:DualRow(parent, y,
                {
                    type = "dropdown",
                    text = LText("Aura Match Mode"),
                    values = { all = "All Listed Spells", any = "Any Listed Spell" },
                    order = { "all", "any" },
                    getValue = function() return DBVal("auraPriorityMatchMode") or defaults.auraPriorityMatchMode or "all" end,
                    setValue = function(v)
                        DB().auraPriorityMatchMode = v
                        RefreshPriorityRuleColors()
                    end
                },
                { type = "label", text = "" }); y = y - h
        end

        return math.abs(y)
    end

    local function BuildAutoPage(parent, yOffset)
        local W = OptionsPreview.RowWidgets(KT.Widgets)
        local y = yOffset
        local _, h
        parent._showRowDivider = true
        _, h = W:SectionHeader(parent, "AUTO", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enabled"),
                getValue = function() return DBVal("autoEnabled") == true end,
                setValue = function(v)
                    DB().autoEnabled = v
                    KT:RefreshPage()
                end
            },
            { type = "label", text = "" }); y = y - h

        local function AutoOff() return DBVal("autoEnabled") ~= true end

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Enemy Nameplates in combat"),
                getValue = function() return DBVal("autoEnemyInCombat") ~= false end,
                setValue = function(v) DB().autoEnemyInCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = LText("Enabled")
            },
            {
                type = "toggle",
                text = LText("Enemy Nameplates out of combat"),
                getValue = function() return DBVal("autoEnemyOutOfCombat") ~= false end,
                setValue = function(v) DB().autoEnemyOutOfCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = LText("Enabled")
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Friendly Nameplates in combat"),
                getValue = function() return DBVal("autoFriendlyInCombat") ~= false end,
                setValue = function(v) DB().autoFriendlyInCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = LText("Enabled")
            },
            {
                type = "toggle",
                text = LText("Friendly Nameplates out of combat"),
                getValue = function() return DBVal("autoFriendlyOutOfCombat") ~= false end,
                setValue = function(v) DB().autoFriendlyOutOfCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = LText("Enabled")
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Always Show Nameplates in combat"),
                getValue = function() return DBVal("autoAlwaysShowInCombat") ~= false end,
                setValue = function(v) DB().autoAlwaysShowInCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = LText("Enabled")
            },
            {
                type = "toggle",
                text = LText("Always Show Nameplates out of combat"),
                getValue = function() return DBVal("autoAlwaysShowOutOfCombat") ~= false end,
                setValue = function(v) DB().autoAlwaysShowOutOfCombat = v; KT:RefreshPage() end,
                disabled = AutoOff,
                disabledTooltip = LText("Enabled")
            }); y = y - h

        _, h = W:Spacer(parent, y, 14); y = y - h
        return math.abs(y)
    end

    local function BuildEnemyUnitRows(parent, yOffset)
        local W = OptionsPreview.RowWidgets(KT.Widgets)
        local y = yOffset
        local _, h
        parent._showRowDivider = true
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Hide Enemy Totems"),
                getValue = function() return DBVal("hideEnemyTotems") == true end,
                setValue = function(v)
                    DB().hideEnemyTotems = v
                    KT:RefreshPage()
                end
            },
            {
                type = "toggle",
                text = LText("Hide Enemy Guardians"),
                getValue = function() return DBVal("hideEnemyGuardians") == true end,
                setValue = function(v) DB().hideEnemyGuardians = v; KT:RefreshPage() end
            }); y = y - h

        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Hide Enemy Minions"),
                getValue = function() return DBVal("hideEnemyMinions") == true end,
                setValue = function(v) DB().hideEnemyMinions = v; KT:RefreshPage() end
            },
            {
                type = "toggle",
                text = LText("Hide Enemy Minor Units"),
                getValue = function() return DBVal("hideEnemyMinorUnits") == true end,
                setValue = function(v) DB().hideEnemyMinorUnits = v; KT:RefreshPage() end
            }); y = y - h
        return math.abs(y)
    end

    local function BuildBarEffects(parent, yOffset)
        local W = OptionsPreview.RowWidgets(KT.Widgets)
        local y = yOffset
        local _, h
        parent._showRowDivider = true
        _, h = W:SectionHeader(parent, "BAR EFFECTS", y); y = y - h
        _, h = W:DualRow(parent, y,
            {
                type = "toggle",
                text = LText("Show Shield Prediction"),
                getValue = function() return DBVal("showShieldPrediction") ~= false end,
                setValue = function(v) DB().showShieldPrediction = v; KT:RefreshPage() end,
            },
            {
                type = "toggle",
                text = LText("Animate Health Bar"),
                getValue = function() return DBVal("animateHealthBar") == true end,
                setValue = function(v) DB().animateHealthBar = v; KT:RefreshPage() end
            }); y = y - h
        return math.abs(y)
    end

    -- The bar texture sits beside Border Style on the Bars card.
    local function BarTextureCell()
        return {
            type = "dropdown",
            text = LText("Bar Texture"),
            values = hbtValues,
            order = hbtOrder,
            preview = { kind = "texture", sharedMedia = true },
            getValue = function()
                return DBVal("healthBarTexture") or defaults.healthBarTexture or "Melli Reforged"
            end,
            setValue = function(v)
                DB().healthBarTexture = v
                if ns.RefreshAllSettings then ns.RefreshAllSettings() end
                if UpdatePreview then UpdatePreview() end
            end,
        }
    end

    -- Each card lists its options from the most used to the finest detail.
    local function GroupSlots(parent, y, sections, textureCell)
        return OptionsSlots.Build({
            parent = parent,
            y = y,
            W = OptionsPreview.RowWidgets(KT.Widgets),
            UpdatePreview = UpdatePreview,
            ColorPreviews = ns.OptionsColors.ColorPreviews,
            sections = sections,
            textureCell = textureCell,
        })
    end

    local function GroupDisplay(parent, y, slots, sections)
        return ns.OptionsDisplay.Build({
            parent = parent,
            y = y,
            W = OptionsPreview.RowWidgets(KT.Widgets),
            UpdatePreview = UpdatePreview,
            slots = slots,
            sections = sections,
        }).y
    end

    local function GroupColors(parent, y, sections)
        return ns.OptionsColors.Build({
            parent = parent,
            y = y,
            W = OptionsPreview.RowWidgets(KT.Widgets),
            sections = sections,
        }).y
    end

    local GROUP_BUILDERS = {
        style = function(sc, y)
            y = -ns.OptionsGeneral.Build(sc, y, { general = true })
            local W = OptionsPreview.RowWidgets(KT.Widgets)
            local _, h = W:Spacer(sc, y, 14); y = y - h
            _, h = W:Button(sc, "Restore Defaults", y, function()
                StaticPopup_Show("KUI_NAMEPLATES_RESTORE_DEFAULTS")
            end)
            return math.abs(y - h)
        end,
        bars = function(sc, y)
            local slots = GroupSlots(sc, y, {})
            y = GroupDisplay(sc, y, slots, { bars = true })
            slots = GroupSlots(sc, y, { border = true }, BarTextureCell())
            y = GroupDisplay(sc, slots.y, slots, { markers = true })
            return BuildBarEffects(sc, y)
        end,
        text = function(sc, y)
            y = -ns.OptionsGeneral.Build(sc, y, { font = true })
            local slots = GroupSlots(sc, y, { text = true })
            y = GroupDisplay(sc, slots.y, slots, { slotTargets = true })
            return BuildDisplayPage({ enemyName = true, level = true }, sc, y)
        end,
        auras = function(sc, y)
            local slots = GroupSlots(sc, y, { core = true })
            y = GroupDisplay(sc, slots.y, slots, { auraText = true, slotTargets = true })
            y = -BuildDisplayPage({ topDebuffs = true }, sc, y)
            y = -ns.OptionsGeneral.Build(sc, y, { shownAuras = true, glows = true })
            return BuildSpecialPage("buff", sc, y)
        end,
        cast = function(sc, y)
            local slots = GroupSlots(sc, y, {})
            y = GroupDisplay(sc, y, slots, { castRow = true })
            y = -ns.OptionsGeneral.Build(sc, y, { focusCast = true })
            y = GroupDisplay(sc, y, slots, { spellText = true })
            return math.abs(GroupDisplay(sc, y, slots, { castColors = true }))
        end,
        target = function(sc, y)
            local slots = GroupSlots(sc, y, { target = true })
            y = GroupDisplay(sc, slots.y, slots, { slotTargets = true })
            return math.abs(GroupColors(sc, y, { focus = true }))
        end,
        colors = function(sc, y)
            y = -BuildThreatPage(sc, y)
            local W = OptionsPreview.RowWidgets(KT.Widgets)
            local _, h = W:Spacer(sc, y, 14); y = y - h
            y = GroupColors(sc, y, { base = true })
            return BuildSpecialPage("rules", sc, y)
        end,
        indicators = function(sc, y)
            local slots = GroupSlots(sc, y, {})
            y = GroupDisplay(sc, y, slots, { class = true })
            return ns.OptionsGeneral.Build(sc, y, { dot = true, distance = true })
        end,
        friendly = function(sc, y)
            y = -BuildDisplayPage({ friendly = true }, sc, y)
            local W = OptionsPreview.RowWidgets(KT.Widgets)
            local _, h = W:Spacer(sc, y, 14); y = y - h
            return ns.OptionsGeneral.Build(sc, y, { friendlyColors = true, classIcons = true })
        end,
        visibility = function(sc, y)
            y = -ns.OptionsGeneral.Build(sc, y, { stacking = true })
            y = -BuildAutoPage(sc, y)
            y = -ns.OptionsGeneral.Build(sc, y, { pets = true })
            return BuildEnemyUnitRows(sc, y)
        end,
    }

    --  Register the module
    KT:RegisterPage("nameplates", "Nameplates", 16, function(sc)
        local menu = KT.MenuPrincipal
        -- The search index builds every page on a throwaway frame: this page only draws on the real one.
        if not menu or sc ~= menu.scrollChild then return 0 end

        local Groups = ns.OptionsGroups
        if not _updatePreviewHooked then
            _updatePreviewHooked = true
            local _origUpdatePreview = UpdatePreview
            UpdatePreview = function()
                _origUpdatePreview()
                if onPresetSettingChanged then onPresetSettingChanged() end
            end
        end

        Groups.ResetTargets()
        local group = Groups.Active()
        Groups.shell = EnsureDisplayStickyPreviewFrame()
        Groups.EnterLayout(menu)
        local y = -BuildDisplayStickyPreview(sc, group == "friendly" and "friendly" or "enemy")
        Groups.ShowRail(menu)
        OptionsPreview.AttachClickTargets(Groups.Navigate)
        onPresetSettingChanged = nil
        return GROUP_BUILDERS[group](sc, y)
    end)

    if not StaticPopupDialogs["KUI_NAMEPLATES_RESTORE_DEFAULTS"] then
        StaticPopupDialogs["KUI_NAMEPLATES_RESTORE_DEFAULTS"] = {
            text = LText("Restore default Nameplates settings? This will reload the UI."),
            button1 = YES,
            button2 = CANCEL,
            OnAccept = function()
                if ns.ResetNameplatesDB then
                    ns.ResetNameplatesDB()
                else
                    KullThranUINameplatesDB = nil
                end
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    --  Slash command  /knp  opens KT to the Nameplates module
    SLASH_KULLTHRANNAMEPLATES1 = "/knp"
    SlashCmdList.KULLTHRANNAMEPLATES = function(msg)
        if InCombatLockdown and InCombatLockdown() then
            print(LText("Cannot open options in combat"))
            return
        end

        if msg == "reset" then
            if ns.ResetNameplatesDB then
                ns.ResetNameplatesDB()
            else
                KullThranUINameplatesDB = nil
            end
            ReloadUI()
            return
        end

        KT:OpenMenu("nameplates")
    end
end)
