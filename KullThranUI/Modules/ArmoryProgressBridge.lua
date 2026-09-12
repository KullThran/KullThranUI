local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
if not KT then return end

local Bridge = CreateFrame("Frame")
local TITLE_STRIPE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\title_background_png.tga"
local PANEL_BG = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUISettingsSurface.png"
local STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local SLOT_HIGHLIGHT_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\WeakAuras_SharedMedia\\Textures\\Square_AlphaGradient.tga"
local ACTIVE_YELLOW = { 1, 0.84, 0.2, 1 }
local UPGRADE_TEXT_ORANGE = { 1, 0.56, 0.08, 1 }
local TAB_INACTIVE_BG = { 0.03, 0.03, 0.04, 0.96 }
local TAB_ACTIVE_BG = { 0.16, 0.12, 0.02, 0.96 }
local ROW_BG_A = { 0.08, 0.08, 0.09, 0.9 }
local ROW_BG_B = { 0.13, 0.13, 0.14, 0.88 }
local ROW_HOVER_BG = { 0.2, 0.05, 0.12, 0.32 }
local PANEL_BORDER = { 0.16, 0.16, 0.18, 0.92 }
local GOLD_LINE = { 0.72, 0.62, 0.28, 0.65 }
local SLOT_BUTTON_NAMES = {
    "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterShirtSlot", "CharacterChestSlot",
    "CharacterWristSlot", "CharacterBackSlot", "CharacterHandsSlot", "CharacterWaistSlot",
    "CharacterLegsSlot", "CharacterFeetSlot", "CharacterFinger0Slot", "CharacterFinger1Slot",
    "CharacterTrinket0Slot", "CharacterTrinket1Slot", "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterTabardSlot",
}
local INSPECT_SLOT_BUTTON_NAMES = {
    "InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectShirtSlot", "InspectChestSlot",
    "InspectWristSlot", "InspectBackSlot", "InspectHandsSlot", "InspectWaistSlot",
    "InspectLegsSlot", "InspectFeetSlot", "InspectFinger0Slot", "InspectFinger1Slot",
    "InspectTrinket0Slot", "InspectTrinket1Slot", "InspectMainHandSlot", "InspectSecondaryHandSlot", "InspectTabardSlot",
}
local SLOT_HIGHLIGHT_DIRECTION = {
    [1] = "right", [2] = "right", [3] = "right", [4] = "right", [5] = "right", [9] = "right", [15] = "right", [19] = "right",
    [6] = "left", [7] = "left", [8] = "left", [10] = "left", [11] = "left", [12] = "left", [13] = "left", [14] = "left",
    [16] = "left", [17] = "right",
}
local SLOT_TEXT_OFFSETS = {
    [16] = { trackY = -2, enchantY = -16 },
    [17] = { trackY = -2, enchantY = -16 },
}
local UPGRADE_TRACK_COLORS = {
    ["Explorer"] = { 0.62, 0.62, 0.62, 1 },
    ["Adventurer"] = { 1, 1, 1, 1 },
    ["Veteran"] = { 0.12, 1, 0, 1 },
    ["Champion"] = { 0, 0.44, 0.87, 1 },
    ["Hero"] = { 1, 0.3, 1, 1 },
    ["Myth"] = { 1, 0.5, 0, 1 },
    ["Expedicionario"] = { 0.62, 0.62, 0.62, 1 },
    ["Aventurero"] = { 1, 1, 1, 1 },
    ["Veterano"] = { 0.12, 1, 0, 1 },
    ["Campeon"] = { 0, 0.44, 0.87, 1 },
    ["Campeón"] = { 0, 0.44, 0.87, 1 },
    ["Heroe"] = { 1, 0.3, 1, 1 },
    ["Héroe"] = { 1, 0.3, 1, 1 },
    ["Mito"] = { 1, 0.5, 0, 1 },
}

local RAID_DIFFICULTY_LABELS = {
    [14] = PLAYER_DIFFICULTY1 or "Normal",
    [15] = PLAYER_DIFFICULTY2 or "Heroic",
    [16] = PLAYER_DIFFICULTY6 or "Mythic",
    [17] = RAID_FINDER or "LFR",
}

local function GetArmoryModule()
    return KT.GetModule and KT:GetModule("Armory", true) or nil
end

local function GetInspectArmoryProfile()
    return KT and KT.db and KT.db.profile and KT.db.profile.inspectArmory or nil
end

local function FormatResetTime(seconds)
    seconds = tonumber(seconds) or 0
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    end
    return string.format("%dh %dm", hours, mins)
end

local function EnsureArmoryConfig()
    local profile = KT.db and KT.db.profile and KT.db.profile.armory
    if not profile then return end
    if profile.activeInsetPane == nil then
        profile.activeInsetPane = "stats"
    end
    if type(profile.progressSectionState) ~= "table" then
        profile.progressSectionState = {}
    end
end

local function IsPaperDollPrimaryVisible()
    if not (_G.PaperDollFrame and _G.PaperDollFrame:IsShown()) then
        return false
    end
    return Bridge.currentSidebar == nil or Bridge.currentSidebar == 1
end

local function IsInspectPaperDollVisible()
    return _G.InspectFrame and _G.InspectFrame:IsShown()
        and _G.InspectPaperDollFrame and _G.InspectPaperDollFrame:IsShown()
end

local function GetSlotButtonContext(button)
    if not (button and button.GetName) then
        return nil
    end

    local name = button:GetName()
    if type(name) ~= "string" then
        return nil
    end

    if name:match("^Character") then
        local armory = GetArmoryModule()
        return "player", armory and armory.db or nil, IsPaperDollPrimaryVisible() and _G.CharacterFrame and _G.CharacterFrame:IsShown()
    elseif name:match("^Inspect") then
        local inspectFrame = _G.InspectFrame
        return inspectFrame and inspectFrame.unit or nil, GetInspectArmoryProfile(), IsInspectPaperDollVisible()
    end

    return nil
end

function Bridge:SyncHeaderPortrait()
    local armory = GetArmoryModule()
    local header = armory and armory.Header
    local classIcon = header and header.ClassIcon
    local portrait = _G.CharacterFramePortrait
    if not (armory and armory.db and header and classIcon and portrait) then
        return
    end

    if armory.db.showPortrait then
        classIcon:Hide()
        portrait:SetParent(header)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", classIcon, "TOPLEFT", 0, 0)
        portrait:SetPoint("BOTTOMRIGHT", classIcon, "BOTTOMRIGHT", 0, 0)
        portrait:SetDrawLayer("OVERLAY", 7)
        portrait:Show()
        if SetPortraitTexture then
            SetPortraitTexture(portrait, "player")
        end
    else
        classIcon:Show()
        portrait:Hide()
    end
end

function Bridge:SyncUtilityButtons()
    local armory = GetArmoryModule()
    local bgButton = _G.KT_ArmoryBGSelector
    if bgButton and _G.CharacterModelScene then
        bgButton:SetParent(_G.CharacterModelScene)
        bgButton:SetFrameStrata("DIALOG")
        bgButton:SetFrameLevel(math.max(bgButton:GetFrameLevel(), _G.CharacterModelScene:GetFrameLevel() + 40))
        bgButton:ClearAllPoints()
        if _G.CharacterTabardSlot then
            bgButton:SetPoint("LEFT", _G.CharacterTabardSlot, "RIGHT", 6, 0)
        else
            bgButton:SetPoint("BOTTOMLEFT", _G.CharacterModelScene, "BOTTOMLEFT", 6, 8)
        end
    end

    local configBtn = armory and armory.configBtn
    if configBtn and armory.StatsFrame then
        configBtn:SetFrameStrata("DIALOG")
        configBtn:SetFrameLevel(math.max(configBtn:GetFrameLevel(), armory.StatsFrame:GetFrameLevel() + 40))
        -- KUI damagemeter config icon, tinted with the active accent color.
        local normal = configBtn.GetNormalTexture and configBtn:GetNormalTexture()
        if normal then
            normal:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\damagemeter\\config.png")
            normal:SetVertexColor((KT and KT.C_R) or 1, (KT and KT.C_G) or 0, (KT and KT.C_B) or 0.33, 1)
        end
        configBtn:SetScript("OnClick", function()
            if armory and armory.OpenOptionsPage then
                armory:OpenOptionsPage()
            elseif KT and KT.OpenMenu then
                KT:OpenMenu("armory")
            end
        end)
    end
end

local function SafeLoadWeeklyRewards()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
    end
end

local function SafeLoadEncounterJournal()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn and not C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    end
end

local function GetSlotHighlightDirection(slotID)
    return SLOT_HIGHLIGHT_DIRECTION[tonumber(slotID) or 0] or "right"
end

local function GetSlotHighlightMetrics(slotID)
    if slotID == 16 or slotID == 17 then
        return 92, 38
    end
    return 138, 38
end

local function GetEnchantOverlayFontSize(profile)
    local requested = tonumber(profile and profile.enchantSize) or 10
    requested = math.max(6, requested)
    return math.min(requested, 20)
end

local function GetFallbackQualityColor(unit, slotID)
    local link = GetInventoryItemLink and GetInventoryItemLink(unit, slotID)
    if not link then
        return nil
    end

    local _, _, quality = GetItemInfo(link)
    if quality then
        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if color then
            return { r = color.r, g = color.g, b = color.b, a = 1 }
        end
    end

    local rHex, gHex, bHex = link:match("^|c%x%x(%x%x)(%x%x)(%x%x)")
    if rHex and gHex and bHex then
        local r = tonumber(rHex, 16)
        local g = tonumber(gHex, 16)
        local b = tonumber(bHex, 16)
        if r and g and b then
            return { r = r / 255, g = g / 255, b = b / 255, a = 1 }
        end
    end

    return nil
end

local function IsAccessibleTooltipValue(value)
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return true
end

local function GetTooltipLines(unit, slotID)
    local info = C_TooltipInfo and C_TooltipInfo.GetInventoryItem and C_TooltipInfo.GetInventoryItem(unit, slotID)
    if not IsAccessibleTooltipValue(info) or type(info) ~= "table" then return nil end
    local lines = info.lines
    return IsAccessibleTooltipValue(lines) and type(lines) == "table" and lines or nil
end

local function NormalizeTooltipText(text)
    if not IsAccessibleTooltipValue(text) or type(text) ~= "string" or text == "" then
        return nil
    end

    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T.-|t", "")
        :gsub("|A.-|a", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return nil
    end

    return text
end

local function ExtractTooltipLineTexts(line)
    if not IsAccessibleTooltipValue(line) or type(line) ~= "table" then
        return nil
    end

    local values = {}
    local function addText(value)
        local clean = NormalizeTooltipText(value)
        if clean then
            values[#values + 1] = clean
        end
    end

    addText(line.leftText)
    addText(line.rightText)

    if type(line.args) == "table" then
        for _, arg in ipairs(line.args) do
            if type(arg) == "table" then
                addText(arg.leftText)
                addText(arg.rightText)
                addText(arg.text)
                if type(arg.stringVal) == "string" then
                    addText(arg.stringVal)
                end
            elseif type(arg) == "string" then
                addText(arg)
            end
        end
    end

    if #values == 0 then
        return nil
    end

    return values
end

local function ParseUpgradeTrackText(unit, slotID)
    local lines = GetTooltipLines(unit, slotID)
    if not lines then return nil, nil end

    for _, line in ipairs(lines) do
        local texts = ExtractTooltipLineTexts(line)
        if texts then
            for _, clean in ipairs(texts) do
            local track, current, max = clean:match(": (.+)%s+(%d+)%s*/%s*(%d+)")
            if track and current and max then
                local normalized = track:gsub("^%s+", ""):gsub("%s+$", "")
                local color = UPGRADE_TRACK_COLORS[normalized]
                if color then
                    return string.format("%s/%s %s", current, max, normalized), { r = color[1], g = color[2], b = color[3], a = color[4] }
                end
                return string.format("%s/%s %s", current, max, normalized), { r = 0.64, g = 0.21, b = 0.93, a = 1 }
            end
            end
        end
    end

    return nil, nil
end

local function ParseEnchantText(unit, slotID)
    local lines = GetTooltipLines(unit, slotID)
    if not lines then return nil end
    local pattern = ENCHANTED_TOOLTIP_LINE and ENCHANTED_TOOLTIP_LINE:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"):gsub("%%%%s", "(.+)")
    if not pattern then return nil end

    for _, line in ipairs(lines) do
        local texts = ExtractTooltipLineTexts(line)
        if texts then
            for _, clean in ipairs(texts) do
                local enchant = clean:match(pattern)
                if enchant then
                    enchant = enchant:gsub("^%s+", ""):gsub("%s+$", "")
                    if enchant ~= "" then
                        return enchant
                    end
                end
            end
        end
    end

    return nil
end

function Bridge:EnsureSlotHighlight(button)
    if button.ktSlotHighlight then
        return button.ktSlotHighlight
    end

    local frame = CreateFrame("Frame", nil, button)
    frame:SetFrameStrata(button:GetFrameStrata())
    frame:SetFrameLevel(math.max(0, button:GetFrameLevel() - 2))
    frame:EnableMouse(false)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0)

    frame.tex = frame:CreateTexture(nil, "ARTWORK")
    frame.tex:SetAllPoints()
    frame.tex:SetTexture(SLOT_HIGHLIGHT_TEXTURE)

    frame.edge = frame:CreateTexture(nil, "OVERLAY")
    frame.edge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
    frame.edge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
    frame.edge:SetWidth(1)
    frame.edge:SetColorTexture(1, 1, 1, 0.12)

    button.ktSlotHighlight = frame
    return frame
end

function Bridge:EnsureSlotTexts(button)
    if button.ktTrackDetail and button.ktEnchantDetail then
        return
    end

    button.ktTrackDetail = button:CreateFontString(nil, "OVERLAY")
    button.ktTrackDetail:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    button.ktTrackDetail:SetShadowOffset(0, -1)
    button.ktTrackDetail:SetShadowColor(0, 0, 0, 1)
    button.ktTrackDetail:SetWidth(108)

    button.ktEnchantDetail = button:CreateFontString(nil, "OVERLAY")
    button.ktEnchantDetail:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    button.ktEnchantDetail:SetShadowOffset(0, -1)
    button.ktEnchantDetail:SetShadowColor(0, 0, 0, 1)
    button.ktEnchantDetail:SetWidth(108)
    if button.ktEnchantDetail.SetMaxLines then
        button.ktEnchantDetail:SetMaxLines(2)
    end
end

function Bridge:UpdateSlotTexts(button)
    if not (button and button.GetID) then return end
    local unit, profile, shouldShow = GetSlotButtonContext(button)
    if not (profile and profile.enable) then return end

    self:EnsureSlotTexts(button)

    local slotID = tonumber(button:GetID()) or 0
    local direction = GetSlotHighlightDirection(slotID)
    local trackText = unit and ParseUpgradeTrackText(unit, slotID) or nil
    local enchantText = (unit and profile.showEnchant ~= false) and ParseEnchantText(unit, slotID) or nil
    local offsets = SLOT_TEXT_OFFSETS[slotID] or { trackY = 8, enchantY = -7 }
    local link = unit and GetInventoryItemLink and GetInventoryItemLink(unit, slotID)

    if not (shouldShow and link) then
        button.ktTrackDetail:Hide()
        button.ktEnchantDetail:Hide()
        return
    end

    button.ktTrackDetail:ClearAllPoints()
    button.ktEnchantDetail:ClearAllPoints()

    if direction == "right" then
        button.ktTrackDetail:SetJustifyH("LEFT")
        button.ktEnchantDetail:SetJustifyH("LEFT")
        button.ktTrackDetail:SetPoint("LEFT", button, "RIGHT", 8, offsets.trackY)
        button.ktEnchantDetail:SetPoint("LEFT", button, "RIGHT", 8, offsets.enchantY)
    else
        button.ktTrackDetail:SetJustifyH("RIGHT")
        button.ktEnchantDetail:SetJustifyH("RIGHT")
        button.ktTrackDetail:SetPoint("RIGHT", button, "LEFT", -8, offsets.trackY)
        button.ktEnchantDetail:SetPoint("RIGHT", button, "LEFT", -8, offsets.enchantY)
    end

    if trackText then
        button.ktTrackDetail:SetText(trackText)
        button.ktTrackDetail:SetTextColor(UPGRADE_TEXT_ORANGE[1], UPGRADE_TEXT_ORANGE[2], UPGRADE_TEXT_ORANGE[3], UPGRADE_TEXT_ORANGE[4])
        button.ktTrackDetail:Show()
    else
        button.ktTrackDetail:Hide()
    end

    if enchantText and enchantText ~= "" then
        button.ktEnchantDetail:SetFont(STANDARD_TEXT_FONT, GetEnchantOverlayFontSize(profile), "OUTLINE")
        button.ktEnchantDetail:SetText(enchantText)
        local enchantColor = profile.enchantColor or {}
        button.ktEnchantDetail:SetTextColor(enchantColor.r or 0.15, enchantColor.g or 1, enchantColor.b or 0.45, enchantColor.a or 1)
        button.ktEnchantDetail:Show()
    else
        button.ktEnchantDetail:Hide()
    end

    if button.ktEnchant then
        button.ktEnchant:Hide()
    end
end

function Bridge:UpdateSlotHighlight(button)
    if not (button and button.GetID) then return end
    local unit, profile, shouldShow = GetSlotButtonContext(button)
    if not (profile and profile.enable) then return end

    local slotID = tonumber(button:GetID()) or 0
    local link = unit and GetInventoryItemLink and GetInventoryItemLink(unit, slotID)
    local highlight = self:EnsureSlotHighlight(button)

    if not (shouldShow and link) then
        highlight:Hide()
        if button.ktTrackDetail then button.ktTrackDetail:Hide() end
        if button.ktEnchantDetail then button.ktEnchantDetail:Hide() end
        return
    end

    local color = GetFallbackQualityColor(unit, slotID)
    if not color then
        highlight:Hide()
        if button.ktTrackDetail then button.ktTrackDetail:Hide() end
        if button.ktEnchantDetail then button.ktEnchantDetail:Hide() end
        return
    end

    local width, height = GetSlotHighlightMetrics(slotID)
    highlight:ClearAllPoints()
    highlight:SetSize(width, height)

    local direction = GetSlotHighlightDirection(slotID)
    if direction == "right" then
        highlight:SetPoint("LEFT", button, "LEFT", 0, 0)
        highlight.tex:SetTexCoord(0, 1, 0, 1)
        highlight.edge:ClearAllPoints()
        highlight.edge:SetPoint("TOPLEFT", highlight, "TOPLEFT", 0, -1)
        highlight.edge:SetPoint("BOTTOMLEFT", highlight, "BOTTOMLEFT", 0, 1)
        highlight.edge:SetWidth(1)
        highlight.tex:SetGradient("Horizontal",
            CreateColor(color.r, color.g, color.b, 0.52),
            CreateColor(color.r, color.g, color.b, 0.04)
        )
    else
        highlight:SetPoint("RIGHT", button, "RIGHT", 0, 0)
        highlight.tex:SetTexCoord(1, 0, 0, 1)
        highlight.edge:ClearAllPoints()
        highlight.edge:SetPoint("TOPRIGHT", highlight, "TOPRIGHT", 0, -1)
        highlight.edge:SetPoint("BOTTOMRIGHT", highlight, "BOTTOMRIGHT", 0, 1)
        highlight.edge:SetWidth(1)
        highlight.tex:SetGradient("Horizontal",
            CreateColor(color.r, color.g, color.b, 0.04),
            CreateColor(color.r, color.g, color.b, 0.52)
        )
    end

    highlight.edge:SetColorTexture(color.r, color.g, color.b, 0.45)
    highlight:Show()
    self:UpdateSlotTexts(button)
end

function Bridge:RefreshSlotHighlights()
    for _, name in ipairs(SLOT_BUTTON_NAMES) do
        local button = _G[name]
        if button then
            self:UpdateSlotHighlight(button)
        end
    end
    for _, name in ipairs(INSPECT_SLOT_BUTTON_NAMES) do
        local button = _G[name]
        if button then
            self:UpdateSlotHighlight(button)
        end
    end
end

local function GetDifficultyTint(difficultyName)
    local label = tostring(difficultyName or "")
    if label:find("Mythic") then
        return { r = 0.65, g = 0.45, b = 1, a = 0.9 }
    elseif label:find("Heroic") then
        return { r = 0.1, g = 0.5, b = 1, a = 0.9 }
    elseif label:find("Normal") then
        return { r = 0.2, g = 1, b = 0.2, a = 0.9 }
    end
    return { r = 1, g = 0.82, b = 0.25, a = 0.9 }
end

function Bridge:CreateInsetTab(parent, key, label, x, icon)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    -- Match the native sidebar tab size: mirror the parent frame's height so a
    -- single icon reads at the same scale as Equipment/Titles/Sets.
    local parentSize = parent.GetHeight and parent:GetHeight() or 34
    btn:SetSize(math.max(26, parentSize), math.max(26, parentSize))
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
    btn:SetMotionScriptsWhileDisabled(true)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(unpack(TAB_INACTIVE_BG))

    btn.highlight = btn:CreateTexture(nil, "ARTWORK")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(1, 1, 1, 0.04)
    btn.highlight:Hide()

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if icon then
        btn.icon:SetTexture(icon)
    end

    btn.activeBar = btn:CreateTexture(nil, "OVERLAY")
    btn.activeBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    btn.activeBar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.activeBar:SetHeight(2)
    btn.activeBar:SetColorTexture(unpack(ACTIVE_YELLOW))
    btn.activeBar:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY")
    btn.text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)
    btn.text:SetShadowOffset(0, -1)
    btn.text:SetShadowColor(0, 0, 0, 1)
    btn.text:Hide()

    if KT.AddBorder then
        KT:AddBorder(btn, PANEL_BORDER[1], PANEL_BORDER[2], PANEL_BORDER[3], PANEL_BORDER[4])
    end

    btn:SetScript("OnEnter", function(self)
        if self.key ~= Bridge.activeInsetPane then
            self.highlight:Show()
        end
        if KT.AddBorder then
            KT:AddBorder(self, ACTIVE_YELLOW[1], ACTIVE_YELLOW[2], ACTIVE_YELLOW[3], 0.85)
        end
        if GameTooltip and self.key then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText((self.key == "stats" and "Stats") or "Progress")
            GameTooltip:Show()
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if self.key ~= Bridge.activeInsetPane then
            self.highlight:Hide()
            if KT.AddBorder then
                KT:AddBorder(self, PANEL_BORDER[1], PANEL_BORDER[2], PANEL_BORDER[3], PANEL_BORDER[4])
            end
        end
        if GameTooltip then GameTooltip:Hide() end
    end)

    btn:SetScript("OnClick", function()
        Bridge:SetActiveInsetPane(key)
    end)

    btn.key = key
    return btn
end

function Bridge:StyleSidebarTabs()
    for index = 1, 3 do
        local tab = _G["PaperDollSidebarTab" .. index]
        if tab and not tab._ktArmoryProgressStyled then
            local highlight = tab:GetHighlightTexture() or tab.HighlightTexture or tab.Highlight
            if highlight then
                highlight:SetBlendMode("ADD")
                highlight:SetAlpha(0.65)
            end

            tab._ktArmoryProgressStyled = true
        end
    end
end

function Bridge:CreateTabBar()
    -- Parent to the CharacterFrame (not CharacterFrameInsetRight): the inset
    -- panel may be hidden/reparented when switching sidebar panes, which made
    -- the tabs vanish on Titles/Equipment. The bar is then positioned over the
    -- right panel using the inset's own coordinates.
    local parent = _G.CharacterFrame
    if not parent or self.TabBar then return end

    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -120, -8)
    bar:SetSize(236, 24)
    bar:SetFrameLevel(parent:GetFrameLevel() + 20)

    self.TabBar = bar
    self:AnchorTabBarToSidebar()
end

function Bridge:AnchorTabBarToSidebar()
    -- LayoutIconRow positions the whole strip (3 native tabs + Progress);
    -- if the native tabs aren't built yet, retry shortly.
    if self:LayoutIconRow() then
        return
    end
    C_Timer.After(0.1, function()
        if self.TabBar and not self._ktTabBarAnchored then
            self:AnchorTabBarToSidebar()
        end
    end)
end

function Bridge:CreateRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(24)
    row:RegisterForClicks("LeftButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(unpack(ROW_BG_A))

    row.hover = row:CreateTexture(nil, "ARTWORK")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(unpack(ROW_HOVER_BG))
    row.hover:Hide()

    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    row.edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1)
    row.edge:SetWidth(2)
    row.edge:SetColorTexture(KT.C_R, KT.C_G, KT.C_B, 0.65)

    row.separator = row:CreateTexture(nil, "BORDER")
    row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6, 0)
    row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -6, 0)
    row.separator:SetHeight(1)
    row.separator:SetColorTexture(1, 1, 1, 0.05)

    row.iconBG = row:CreateTexture(nil, "ARTWORK")
    row.iconBG:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.iconBG:SetSize(20, 20)
    row.iconBG:SetColorTexture(0, 0, 0, 0.9)
    row.iconBG:Hide()

    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetPoint("CENTER", row.iconBG, "CENTER")
    row.icon:SetSize(18, 18)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon:Hide()

    row.left = row:CreateFontString(nil, "OVERLAY")
    row.left:SetFont(STANDARD_TEXT_FONT, 11, "")
    row.left:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.left:SetJustifyH("LEFT")
    row.left:SetShadowOffset(0, -1)
    row.left:SetShadowColor(0, 0, 0, 1)

    row.right = row:CreateFontString(nil, "OVERLAY")
    row.right:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    row.right:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetShadowOffset(0, -1)
    row.right:SetShadowColor(0, 0, 0, 1)

    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        if KT.AddBorder then
            KT:AddBorder(self, KT.C_R, KT.C_G, KT.C_B, 0.85)
        end
        if self.tooltipLines and #self.tooltipLines > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            for i, line in ipairs(self.tooltipLines) do
                if i == 1 then
                    GameTooltip:SetText(line, 1, 1, 1)
                else
                    GameTooltip:AddLine(line, nil, nil, nil, true)
                end
            end
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        if KT.AddBorder then
            KT:AddBorder(self, 0.12, 0.12, 0.13, 0.85)
        end
        GameTooltip:Hide()
    end)

    if KT.AddBorder then
        KT:AddBorder(row, 0.12, 0.12, 0.13, 0.85)
    end

    return row
end

function Bridge:CreateSection(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(190, 1)

    frame.headerButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.headerButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, 0)
    frame.headerButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, 0)
    frame.headerButton:SetHeight(24)

    frame.header = frame.headerButton:CreateTexture(nil, "BACKGROUND")
    frame.header:SetAllPoints()
    frame.header:SetColorTexture(0.04, 0.04, 0.05, 0.94)

    frame.headerGlow = frame.headerButton:CreateTexture(nil, "ARTWORK")
    frame.headerGlow:SetPoint("TOPLEFT", frame.headerButton, "TOPLEFT", 1, -1)
    frame.headerGlow:SetPoint("TOPRIGHT", frame.headerButton, "TOPRIGHT", -1, -1)
    frame.headerGlow:SetHeight(1)
    frame.headerGlow:SetColorTexture(1, 1, 1, 0)

    frame.title = frame.headerButton:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    frame.title:SetPoint("CENTER", frame.headerButton, "CENTER", 0, 0)
    frame.title:SetShadowOffset(0, -1)
    frame.title:SetShadowColor(0, 0, 0, 1)

    frame.arrow = frame.headerButton:CreateFontString(nil, "OVERLAY")
    frame.arrow:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    frame.arrow:SetPoint("LEFT", frame.headerButton, "LEFT", 8, 0)
    frame.arrow:SetTextColor(ACTIVE_YELLOW[1], ACTIVE_YELLOW[2], ACTIVE_YELLOW[3], 1)
    frame.arrow:SetShadowOffset(0, -1)
    frame.arrow:SetShadowColor(0, 0, 0, 1)

    frame.lineLeft = frame.headerButton:CreateTexture(nil, "ARTWORK")
    frame.lineLeft:SetPoint("LEFT", frame.arrow, "RIGHT", 6, 0)
    frame.lineLeft:SetPoint("RIGHT", frame.title, "LEFT", -8, 0)
    frame.lineLeft:SetHeight(1)
    frame.lineLeft:SetColorTexture(0.32, 0.28, 0.12, 0.35)

    frame.lineRight = frame.headerButton:CreateTexture(nil, "ARTWORK")
    frame.lineRight:SetPoint("LEFT", frame.title, "RIGHT", 8, 0)
    frame.lineRight:SetPoint("RIGHT", frame.headerButton, "RIGHT", -8, 0)
    frame.lineRight:SetHeight(1)
    frame.lineRight:SetColorTexture(0.32, 0.28, 0.12, 0.35)

    if KT.AddBorder then
        KT:AddBorder(frame.headerButton, 0.18, 0.16, 0.08, 0.9)
    end

    frame.headerButton:SetScript("OnEnter", function(self)
        if KT.AddBorder then
            KT:AddBorder(self, ACTIVE_YELLOW[1], ACTIVE_YELLOW[2], ACTIVE_YELLOW[3], 0.95)
        end
    end)
    frame.headerButton:SetScript("OnLeave", function(self)
        if KT.AddBorder then
            KT:AddBorder(self, 0.18, 0.16, 0.08, 0.9)
        end
    end)

    frame.rows = {}
    return frame
end

function Bridge:AcquireSection(index)
    local content = self.ProgressContent
    local section = content.sections[index]
    if section then
        return section
    end

    section = self:CreateSection(content)
    content.sections[index] = section
    return section
end

function Bridge:AcquireRow(section, index)
    local row = section.rows[index]
    if row then
        return row
    end

    row = self:CreateRow(section)
    section.rows[index] = row
    return row
end

function Bridge:BuildSection(index, stateKey, y, title, color, rows)
    local section = self:AcquireSection(index)
    section:Show()
    section.title:SetText(title)
    section.title:SetTextColor(math.max(color.r, 0.82), math.max(color.g, 0.82), math.max(color.b, 0.82), 1)
    section.stateKey = stateKey

    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", self.ProgressContent, "TOPLEFT", 0, y)
    section:SetPoint("TOPRIGHT", self.ProgressContent, "TOPRIGHT", 0, y)

    if not section._toggleHooked then
        section.headerButton:SetScript("OnClick", function()
            Bridge:ToggleSection(section.stateKey)
        end)
        section._toggleHooked = true
    end

    local isCollapsed = self:IsSectionCollapsed(stateKey)
    section.arrow:SetText(isCollapsed and ">" or "v")

    local rowY = -30
    if not isCollapsed then
        for rowIndex, data in ipairs(rows) do
            local row = self:AcquireRow(section, rowIndex)
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", section, "TOPLEFT", 5, rowY)
            row:SetPoint("TOPRIGHT", section, "TOPRIGHT", -5, rowY)
            row:SetHeight(data.height or 26)
            row.left:SetText(data.left or "")
            row.right:SetText(data.right or "")
            row.left:SetTextColor(1, 1, 1, 1)
            row.right:SetTextColor((data.color and data.color.r) or 1, (data.color and data.color.g) or 1, (data.color and data.color.b) or 1, 1)
            if data.icon then
                row.iconBG:Show()
                row.icon:Show()
                row.icon:SetTexture(data.icon)
                row.left:ClearAllPoints()
                row.left:SetPoint("LEFT", row.iconBG, "RIGHT", 8, 0)
            else
                row.iconBG:Hide()
                row.icon:Hide()
                row.left:ClearAllPoints()
                row.left:SetPoint("LEFT", row, "LEFT", 10, 0)
            end
            if rowIndex % 2 == 1 then
                row.bg:SetColorTexture(unpack(ROW_BG_A))
            else
                row.bg:SetColorTexture(unpack(ROW_BG_B))
            end
            if data.edgeColor then
                row.edge:SetColorTexture(data.edgeColor.r, data.edgeColor.g, data.edgeColor.b, data.edgeColor.a or 0.75)
            elseif data.color then
                row.edge:SetColorTexture(data.color.r, data.color.g, data.color.b, 0.75)
            else
                row.edge:SetColorTexture(KT.C_R, KT.C_G, KT.C_B, 0.65)
            end
            row.tooltipLines = data.tooltipLines
            rowY = rowY - (row:GetHeight() + 3)
        end
    end

    for rowIndex = #rows + 1, #section.rows do
        section.rows[rowIndex]:Hide()
    end
    if isCollapsed then
        for rowIndex = 1, #section.rows do
            section.rows[rowIndex]:Hide()
        end
    end

    local height = isCollapsed and 30 or (math.abs(rowY) + 10)
    section:SetHeight(height)
    return y - height - 12
end

function Bridge:IsSectionCollapsed(stateKey)
    local profile = KT.db and KT.db.profile and KT.db.profile.armory
    local state = profile and profile.progressSectionState
    if not stateKey or not state then
        return false
    end
    return state[stateKey] == true
end

function Bridge:ToggleSection(stateKey)
    local profile = KT.db and KT.db.profile and KT.db.profile.armory
    if not (profile and profile.progressSectionState and stateKey) then
        return
    end
    profile.progressSectionState[stateKey] = not (profile.progressSectionState[stateKey] == true)
    self:RefreshProgress()
end

function Bridge:CollectMythicRows()
    local rows = {}
    local score = 0
    local summary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary and C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    if summary and summary.currentSeasonScore then
        score = summary.currentSeasonScore
    elseif C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
        score = C_ChallengeMode.GetOverallDungeonScore() or 0
    end

    local scoreColor = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score)
    rows[#rows + 1] = {
        left = CHALLENGE_MODE_RATING or "Mythic+ Rating",
        right = score > 0 and string.format("%.2f", score) or "0",
        color = scoreColor or { r = 1, g = 1, b = 1 },
        edgeColor = { r = 0.76, g = 0.35, b = 1, a = 0.85 },
        height = 28,
    }

    local history = C_MythicPlus and C_MythicPlus.GetRunHistory and C_MythicPlus.GetRunHistory(false, true) or {}
    table.sort(history, function(a, b)
        if (a.level or 0) == (b.level or 0) then
            return (a.mapChallengeModeID or 0) < (b.mapChallengeModeID or 0)
        end
        return (a.level or 0) > (b.level or 0)
    end)

    for i = 1, math.min(3, #history) do
        local run = history[i]
        local mapName = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(run.mapChallengeModeID)
        local result = (mapName or ("Map " .. tostring(run.mapChallengeModeID or i))) .. " +" .. tostring(run.level or 0)
        local starText = run.completed and "Timed" or "Untimed"
        rows[#rows + 1] = {
            left = result,
            right = starText,
            color = run.completed and { r = 0.2, g = 1, b = 0.2 } or { r = 1, g = 0.82, b = 0.25 },
            edgeColor = run.completed and { r = 0.2, g = 1, b = 0.2, a = 0.85 } or { r = 1, g = 0.82, b = 0.25, a = 0.85 },
        }
    end

    if #rows == 1 then
        rows[#rows + 1] = {
            left = NO_RESULTS or "No runs recorded this week",
            right = "",
            color = { r = 0.7, g = 0.7, b = 0.7 },
            edgeColor = { r = 0.45, g = 0.45, b = 0.45, a = 0.75 },
        }
    end

    return rows
end

function Bridge:CollectVaultRows()
    local rows = {}
    SafeLoadWeeklyRewards()
    if not (C_WeeklyRewards and Enum and Enum.WeeklyRewardChestThresholdType) then
        rows[#rows + 1] = {
            left = "Weekly Rewards API unavailable",
            right = "",
            color = { r = 0.7, g = 0.7, b = 0.7 },
        }
        return rows
    end

    local function AddActivities(activities, prefix, levelFormatter)
        for index, activity in ipairs(activities or {}) do
            local progress = tonumber(activity.progress) or 0
            local threshold = tonumber(activity.threshold) or 0
            local isComplete = progress >= threshold and threshold > 0
            local right = threshold > 0 and string.format("%d/%d", progress, threshold) or ""
            local left = string.format("%s %d", prefix, index)
            if levelFormatter then
                local detail = levelFormatter(activity)
                if detail and detail ~= "" then
                    left = left .. " - " .. detail
                end
            end

            rows[#rows + 1] = {
                left = left,
                right = right,
                color = isComplete and { r = 0.2, g = 1, b = 0.2 } or { r = 1, g = 0.82, b = 0.25 },
                edgeColor = isComplete and { r = 0.2, g = 1, b = 0.2, a = 0.85 } or { r = 0.65, g = 0.45, b = 1, a = 0.8 },
            }
        end
    end

    AddActivities(
        C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities),
        "M+",
        function(activity)
            local level = tonumber(activity.level) or 0
            if level > 0 then
                return "+" .. level
            end
            return nil
        end
    )

    AddActivities(
        C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Raid),
        "Raid",
        function(activity)
            return RAID_DIFFICULTY_LABELS[activity.level]
        end
    )

    AddActivities(
        C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World),
        "World",
        function(activity)
            local level = tonumber(activity.level) or 0
            if level > 0 then
                return "Tier " .. level
            end
            return nil
        end
    )

    if #rows == 0 then
        rows[#rows + 1] = {
            left = "No weekly reward data available",
            right = "",
            color = { r = 0.7, g = 0.7, b = 0.7 },
            edgeColor = { r = 0.45, g = 0.45, b = 0.45, a = 0.75 },
        }
    end

    return rows
end

function Bridge:CollectLockoutRows()
    local rows = {}
    RequestRaidInfo()

    for i = 1, GetNumSavedInstances() do
        local name, _, reset, _, isLocked, _, _, isRaid, _, difficultyName, maxEncounters, currentProgress = GetSavedInstanceInfo(i)
        if isLocked then
            local left = name or "Instance"
            if difficultyName and difficultyName ~= "" then
                left = left .. " (" .. difficultyName .. ")"
            end

            local right
            if isRaid and maxEncounters and maxEncounters > 0 then
                right = string.format("%d/%d", tonumber(currentProgress) or 0, tonumber(maxEncounters) or 0)
            else
                right = FormatResetTime(reset)
            end

            rows[#rows + 1] = {
                left = left,
                right = right,
                color = isRaid and { r = 0.65, g = 0.45, b = 1 } or { r = 0.2, g = 0.8, b = 1 },
                edgeColor = isRaid and { r = 0.65, g = 0.45, b = 1, a = 0.85 } or { r = 0.2, g = 0.8, b = 1, a = 0.85 },
                tooltipLines = {
                    left,
                    "Reset: " .. FormatResetTime(reset),
                },
            }
        end
    end

    if #rows == 0 then
        rows[#rows + 1] = {
            left = "No saved lockouts",
            right = "",
            color = { r = 0.7, g = 0.7, b = 0.7 },
            edgeColor = { r = 0.45, g = 0.45, b = 0.45, a = 0.75 },
        }
    end

    return rows
end

function Bridge:CollectRaidRows()
    local rows = {}
    SafeLoadEncounterJournal()

    for i = 1, GetNumSavedInstances() do
        local name, _, reset, _, isLocked, _, _, isRaid, _, difficultyName, maxEncounters, currentProgress = GetSavedInstanceInfo(i)
        if isRaid and isLocked then
            local diffColor = GetDifficultyTint(difficultyName)
            rows[#rows + 1] = {
                left = name or (RAID or "Raid"),
                right = string.format("%s  %d/%d", tostring(difficultyName or ""), tonumber(currentProgress) or 0, tonumber(maxEncounters) or 0),
                color = diffColor,
                edgeColor = diffColor,
                height = 28,
                tooltipLines = {
                    name or (RAID or "Raid"),
                    "Reset: " .. FormatResetTime(reset),
                },
            }

            for encounterIndex = 1, tonumber(maxEncounters) or 0 do
                local bossName, bossTexture, isKilled = GetSavedInstanceEncounterInfo(i, encounterIndex)
                if bossName then
                    rows[#rows + 1] = {
                        left = bossName,
                        right = isKilled and "Killed" or "Alive",
                        color = isKilled and { r = 0.2, g = 1, b = 0.2 } or { r = 0.7, g = 0.7, b = 0.7 },
                        edgeColor = diffColor,
                        icon = bossTexture,
                        tooltipLines = {
                            bossName,
                            tostring(difficultyName or ""),
                        },
                    }
                end
            end
        end
    end

    if #rows == 0 then
        rows[#rows + 1] = {
            left = "No raid lockouts",
            right = "",
            color = { r = 0.7, g = 0.7, b = 0.7 },
            edgeColor = { r = 0.45, g = 0.45, b = 0.45, a = 0.75 },
        }
    end

    return rows
end

function Bridge:CreateProgressFrame()
    local parent = _G.CharacterFrameInsetRight
    if not parent or self.ProgressFrame then return end

    local frame = CreateFrame("Frame", "KUI_ArmoryProgressFrame", parent)
    frame:SetAllPoints()
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.96)

    if KT and KT.ApplyTexturedSurface then
        KT:ApplyTexturedSurface(frame)
        frame.bg:SetAlpha(0)
    else
        frame.overlay = frame:CreateTexture(nil, "BORDER")
        frame.overlay:SetAllPoints()
        frame.overlay:SetTexture(PANEL_BG)
        frame.overlay:SetVertexColor(0.35, 0.35, 0.38, 0.12)
    end

    frame.inset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    frame.inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    if KT.AddBackdrop then
        KT:AddBackdrop(frame.inset, 0.02, 0.02, 0.02, 0.72)
    end
    if KT.AddBorder then
        KT:AddBorder(frame.inset, 0.12, 0.12, 0.14, 0.92)
    end

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame.inset, "TOPLEFT", 0, -4)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.inset, "BOTTOMRIGHT", -16, 4)

    if frame.scroll.ScrollBar then
        frame.scroll.ScrollBar:ClearAllPoints()
        frame.scroll.ScrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", 2, -16)
        frame.scroll.ScrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", 2, 16)
    end

    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(190, 1)
    frame.content.sections = {}
    frame.scroll:SetScrollChild(frame.content)

    self.ProgressFrame = frame
    self.ProgressContent = frame.content
end

-- Shared shell for the KUI Titles/Equipment panes: same geometry as Progress.
function Bridge:CreateKuiPane(name)
    local parent = _G.CharacterFrameInsetRight
    if not parent then return nil end

    local frame = CreateFrame("Frame", name, parent)
    frame:SetAllPoints()
    frame:Hide()
    -- Keep the KUI panes above the Armory StatsFrame so a stale/visible stats
    -- panel never covers them.
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel((parent:GetFrameLevel() or 0) + 40)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.96)

    if KT and KT.ApplyTexturedSurface then
        KT:ApplyTexturedSurface(frame)
        frame.bg:SetAlpha(0)
    else
        frame.overlay = frame:CreateTexture(nil, "BORDER")
        frame.overlay:SetAllPoints()
        frame.overlay:SetTexture(PANEL_BG)
        frame.overlay:SetVertexColor(0.35, 0.35, 0.38, 0.12)
    end

    frame.inset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    frame.inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    if KT.AddBackdrop then
        KT:AddBackdrop(frame.inset, 0.02, 0.02, 0.02, 0.72)
    end
    if KT.AddBorder then
        KT:AddBorder(frame.inset, 0.12, 0.12, 0.14, 0.92)
    end

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame.inset, "TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", frame.inset, "BOTTOMRIGHT", -16, 4)
    if scroll.ScrollBar then
        scroll.ScrollBar:ClearAllPoints()
        scroll.ScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, -16)
        scroll.ScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 16)
    end

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(190, 1)
    scroll:SetScrollChild(content)

    frame.scroll = scroll
    frame.content = content
    return frame
end

function Bridge:CreateTitlesFrame()
    if self.TitlesFrame then return end
    local frame = self:CreateKuiPane("KUI_ArmoryTitlesFrame")
    if not frame then return end
    self.TitlesFrame = frame
    self.TitlesContent = frame.content
end

function Bridge:CreateEquipmentFrame()
    if self.EquipmentFrame then return end
    local frame = self:CreateKuiPane("KUI_ArmoryEquipmentFrame")
    if not frame then return end
    self.EquipmentFrame = frame
    self.EquipmentContent = frame.content
end

local EQUIPMENT_TITLES_SLOTS = {
    { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulders" }, { 5, "Chest" },
    { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" }, { 9, "Wrist" },
    { 10, "Hands" }, { 11, "Ring 1" }, { 12, "Ring 2" }, { 13, "Trinket 1" },
    { 14, "Trinket 2" }, { 15, "Back" }, { 16, "Main Hand" }, { 17, "Off Hand" },
}

function Bridge:RebuildRows(content, count, factory)
    content.rows = content.rows or {}
    local rows = content.rows
    -- Grow the pool to `count`, reusing frames; hide the surplus.
    while #rows < count do
        rows[#rows + 1] = self:CreateRow(content)
    end
    for i = 1, #rows do
        if i <= count then
            rows[i]:Show()
        else
            rows[i]:Hide()
        end
    end
    return rows
end

function Bridge:RefreshTitles()
    local frame = self.TitlesFrame
    if not frame then return end
    local content = frame.content

    -- Modern Blizzard moved title APIs to the C_Title namespace.
    local getNum = (C_Title and C_Title.GetNumTitles) or GetNumTitles
    local getName = (C_Title and C_Title.GetTitleName) or GetTitleName
    local setTitle = (C_Title and C_Title.SetCurrentTitle) or SetCurrentTitle
    local n = getNum and getNum() or 0
    local count = math.max(1, n)
    local rows = self:RebuildRows(content, count, nil)
    local y = -8
    for i = 1, n do
        local ok, name = pcall(getName, i)
        if not ok or type(name) ~= "string" or name == "" then name = ("Title %d"):format(i) end
        local row = rows[i]
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
        row.left:SetText(name)
        row.right:SetText("")
        row.iconBG:Hide()
        row.icon:Hide()
        row.bg:SetColorTexture(unpack(ROW_BG_A))
        if Bridge.selTitleRow and Bridge.selTitleRow == i then
            row.bg:SetColorTexture(1, 0.84, 0.2, 0.5)
        end
        row:SetScript("OnClick", function(self)
            if setTitle then pcall(setTitle, self.titleIndex) end
            Bridge.selTitleRow = self.titleIndex
            Bridge:RefreshTitles()
        end)
        row.titleIndex = i
        row:SetScript("OnEnter", function(self) self.hover:Show() end)
        row:SetScript("OnLeave", function(self) self.hover:Hide() end)
        y = y - 26
    end
    if n == 0 then
        local row = rows[1]
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
        row.left:SetText(LText("No titles available"))
        row.right:SetText("")
        row.iconBG:Hide()
        row.icon:Hide()
        row:SetScript("OnClick", nil)
        y = y - 26
    end
    content:SetHeight(math.abs(y) + 12)
end

function Bridge:RefreshEquipment()
    local frame = self.EquipmentFrame
    if not frame then return end
    local content = frame.content

    local rows = self:RebuildRows(content, #EQUIPMENT_TITLES_SLOTS, nil)
    local y = -8
    for i, def in ipairs(EQUIPMENT_TITLES_SLOTS) do
        local slotID, label = def[1], def[2]
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slotID)
        local row = rows[i]
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
        row.left:SetTextColor(0.94, 0.94, 0.96, 1)
        row.bg:SetColorTexture(unpack(ROW_BG_A))
        if link then
            row.left:SetText(GetItemInfo(link) or label)
            row.right:SetText("")
            row.iconBG:Show()
            row.icon:Show()
            local tex = GetInventoryItemTexture("player", slotID)
            if tex then row.icon:SetTexture(tex) end
        else
            row.left:SetText(label)
            row.right:SetText("")
            row.left:SetTextColor(0.55, 0.55, 0.58, 0.8)
            row.iconBG:Hide()
            row.icon:Hide()
        end
        row:SetScript("OnClick", nil)
        row:SetScript("OnEnter", function(self)
            self.hover:Show()
            if link and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.hover:Hide()
            GameTooltip:Hide()
        end)
        y = y - 26
    end
    content:SetHeight(math.abs(y) + 12)
end

function Bridge:RefreshProgress()
    if not self.ProgressFrame then return end

    local y = -8
    y = self:BuildSection(1, "mythic", y, "Mythic+", { r = 0.92, g = 0.84, b = 1 }, self:CollectMythicRows())
    y = self:BuildSection(2, "vault", y, GREAT_VAULT_TITLE or "Great Vault", { r = 1, g = 0.92, b = 0.45 }, self:CollectVaultRows())
    y = self:BuildSection(3, "raids", y, RAID or "Raids", { r = 0.82, g = 0.95, b = 1 }, self:CollectRaidRows())

    for index = 4, #self.ProgressContent.sections do
        self.ProgressContent.sections[index]:Hide()
    end

    self.ProgressContent:SetHeight(math.abs(y) + 12)
end

function Bridge:AdjustStatsFrame()
    local armory = GetArmoryModule()
    if not (armory and armory.StatsFrame and armory.StatsFrame.ScrollFrame) then return end
    if armory.StatsFrame._ktInsetTabsAdjusted then return end

    -- The text tab bar now sits above the inset, so Stats no longer needs to
    -- reserve an internal row for it. Keep only a compact panel margin.
    armory.StatsFrame.ScrollFrame:ClearAllPoints()
    armory.StatsFrame.ScrollFrame:SetPoint("TOPLEFT", armory.StatsFrame, "TOPLEFT", 10, -4)
    armory.StatsFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", armory.StatsFrame, "BOTTOMRIGHT", -20, 10)
    armory.StatsFrame._ktInsetTabsAdjusted = true
end

function Bridge:UpdateTabState()
    if not self.TabBar or not self.TabBar._ktTextTabs then return end
    self:RefreshTextTabs()
end

function Bridge:UpdatePaneVisibility()
    local armory = GetArmoryModule()
    local showPrimaryPane = IsPaperDollPrimaryVisible()
    local pane = self.activePane or ("stats") 
    local showStats = showPrimaryPane and pane == "stats" and self.activeInsetPane == "stats"
    local showProgress = showPrimaryPane and pane == "progress"
    local showTitles = showPrimaryPane and pane == "titles"
    local showEquipment = showPrimaryPane and pane == "equipment"

    -- The tab-bar lives on the CharacterFrame and must stay visible on every
    -- internal pane (stats/titles/equipment/progress). It only needs the
    -- CharacterFrame open, not the primary paperdoll pane.
    local charOpen = _G.CharacterFrame and _G.CharacterFrame:IsShown()
    if self.TabBar then
        self.TabBar:SetShown(charOpen)
    end

    if armory and armory.StatsFrame then
        armory.StatsFrame:SetShown(showStats)
    end

    if self.ProgressFrame then
        self.ProgressFrame:SetShown(showProgress)
    end

    if self.TitlesFrame then
        self.TitlesFrame:SetShown(showTitles)
    end

    if self.EquipmentFrame then
        self.EquipmentFrame:SetShown(showEquipment)
    end

    if showProgress then
        RequestRaidInfo()
        self:RefreshProgress()
    end

    self:RefreshSlotHighlights()

    self:UpdateTabState()
end

function Bridge:SetActiveInsetPane(key)
    EnsureArmoryConfig()
    self.activeInsetPane = key or "stats"
    self.activePane = key or "stats"
    local profile = KT.db and KT.db.profile and KT.db.profile.armory
    if profile then
        profile.activeInsetPane = self.activeInsetPane
    end
    self:UpdatePaneVisibility()
end

function Bridge:SetNativeSidebarTabs(shown)
    for index = 1, 3 do
        local tab = _G["PaperDollSidebarTab" .. index]
        if tab and tab.SetShown then tab:SetShown(shown) end
    end
end

function Bridge:ActivateBlizzardSidebar(index)
    local paperDoll = _G.PaperDollFrame
    local setSidebar = _G.PaperDollFrame_SetSidebar
    if not (paperDoll and type(setSidebar) == "function") then
        return false
    end

    setSidebar(paperDoll, index)
    self.currentSidebar = index

    -- The KUI text strip replaces Blizzard's icon strip, not its panes.
    self:SetNativeSidebarTabs(false)
    return true
end

function Bridge:LayoutIconRow()
    -- Suppress the native sidebar icon tabs entirely; the KUI text tab-bar
    -- replaces their controls while Blizzard still owns the Titles and
    -- Equipment pane contents.
    self:SetNativeSidebarTabs(false)
    return self:BuildTextTabBar()
end

function Bridge:BuildTextTabBar()
    local bar = self.TabBar
    if not bar then return false end
    local locale = KT.GetLocale and KT:GetLocale() or {}
    -- Order: Character Stats, Titles, Equipment, then a compact "P" button
    -- for Progress (small square, same height) that fits without spilling.
    local defs = {
        { key = "stats",     label = locale.Stats or "Stats", w = nil },
        { key = "titles",    label = locale.Titles or "Titles", w = nil },
        { key = "equipment", label = locale.Equipment or "Equipment", w = nil },
        { key = "progress",  label = "P", w = 22, short = true },
    }
    if not bar._ktTextTabs then
        bar:ClearAllPoints()
        -- Keep the text tabs immediately above the right inset. The native
        -- Equipment pane uses its top row for Equip/Save, so placing this bar
        -- inside the inset would cover those buttons.
        local inset = _G.CharacterFrameInsetRight or _G.CharacterFrame
        bar:SetPoint("BOTTOMRIGHT", inset, "TOPRIGHT", -8, 1)
        bar._ktTextTabs = {}
        local gaps = 2
        local measured = {}
        for i, def in ipairs(defs) do
            measured[i] = def.w or math.max(52, #def.label * 6 + 14)
        end
        local total = 0
        for i = 1, #measured do
            total = total + measured[i]
            if i < #measured then total = total + gaps end
        end
        bar:SetSize(total, 24)
        for i, def in ipairs(defs) do
            local btn = CreateFrame("Button", nil, bar, "BackdropTemplate")
            btn:SetSize(measured[i], 22)
            if i == 1 then
                btn:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            else
                btn:SetPoint("LEFT", bar._ktTextTabs[i - 1], "RIGHT", gaps, 0)
            end
            if KT.AddBackdrop then KT:AddBackdrop(btn, 0.04, 0.04, 0.05, 0.9) end
            local lbl = btn:CreateFontString(nil, "OVERLAY")
            lbl:SetPoint("CENTER")
            lbl:SetFont(KT.FONT_PATH or STANDARD_TEXT_FONT, def.short and 12 or 10, "OUTLINE")
            lbl:SetText(def.label)
            lbl:SetShadowOffset(1, -1)
            lbl:SetShadowColor(0, 0, 0, 1)
            btn.lbl = lbl
            btn:SetScript("OnEnter", function(self)
                if KT.AddBorder then KT:AddBorder(self, KT.C_R, KT.C_G, KT.C_B, 0.9) end
                if lbl then lbl:SetTextColor(1, 1, 1, 1) end
                if def.short then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(locale.Progress or "Progress")
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function(self)
                if KT.AddBorder then KT:AddBorder(self, 0.25, 0.25, 0.3, 0.8) end
                if lbl and not Bridge:TextTabIsActive(self) then
                    lbl:SetTextColor(0.7, 0.7, 0.75, 1)
                end
                if def.short then GameTooltip:Hide() end
            end)
            btn:SetScript("OnClick", function(self)
                Bridge:OnTextTabClick(self.key)
            end)
            btn.key = def.key
            bar._ktTextTabs[i] = btn
        end
    end
    self:RefreshTextTabs()
    self._ktTabBarAnchored = true
    return true
end

function Bridge:TextTabIsActive(btn)
    if not btn then return false end
    local pane = self.activePane or "stats"
    if btn.key == "stats" then
        return pane == "stats"
    elseif btn.key == "progress" then
        return pane == "progress"
    elseif btn.key == "titles" then
        return pane == "titles"
    elseif btn.key == "equipment" then
        return pane == "equipment"
    end
    return false
end

function Bridge:OnTextTabClick(key)
    if key == "stats" or key == "progress" then
        -- KUI-managed panes: suppress the native icon tabs and render our own
        -- stats/progress content in the right inset.
        self:SetActiveInsetPane(key)
        self:ActivateBlizzardSidebar(1)
    elseif key == "titles" then
        self.activeInsetPane = nil
        self:SetActivePane("titles")
        self:ActivateBlizzardSidebar(2)
    elseif key == "equipment" then
        self.activeInsetPane = nil
        self:SetActivePane("equipment")
        self:ActivateBlizzardSidebar(3)
    end
    self:UpdatePaneVisibility()
    self:RefreshTextTabs()
end

function Bridge:SetActivePane(key)
    self.activePane = key or "stats"
end

function Bridge:RefreshTextTabs()
    local bar = self.TabBar
    if not bar or not bar._ktTextTabs then return end
    for _, btn in ipairs(bar._ktTextTabs) do
        local isActive = self:TextTabIsActive(btn)
        if isActive then
            if btn.icon then
                btn.icon:SetVertexColor(KT.C_R, KT.C_G, KT.C_B, 1)
            elseif btn.lbl then
                btn.lbl:SetTextColor(KT.C_R, KT.C_G, KT.C_B, 1)
            end
            if KT.AddBackdrop then KT:AddBackdrop(btn, 0.1, 0.1, 0.12, 1) end
            if KT.AddAccentBorder then KT:AddAccentBorder(btn, 1) end
        else
            if btn.icon then
                btn.icon:SetVertexColor(0.8, 0.8, 0.85, 1)
            elseif btn.lbl then
                btn.lbl:SetTextColor(0.7, 0.7, 0.75, 1)
            end
            if KT.AddBackdrop then KT:AddBackdrop(btn, 0.04, 0.04, 0.05, 0.9) end
            if KT.AddBorder then KT:AddBorder(btn, 0.25, 0.25, 0.3, 0.8) end
        end
    end
end

function Bridge:Setup()
    local armory = GetArmoryModule()
    if not (armory and armory.db and armory.StatsFrame and _G.CharacterFrameInsetRight) then
        return
    end

    EnsureArmoryConfig()
    self.currentSidebar = self.currentSidebar or 1
    self.activeInsetPane = (KT.db.profile.armory and KT.db.profile.armory.activeInsetPane) or "stats"
    self.activePane = self.activePane or self.activeInsetPane

    self:StyleSidebarTabs()
    self:CreateTabBar()
    self:CreateProgressFrame()
    self:AdjustStatsFrame()
    self:SyncHeaderPortrait()
    self:SyncUtilityButtons()

    if not self._hooksInstalled then
        hooksecurefunc("PaperDollFrame_SetSidebar", function(_, index)
            Bridge.currentSidebar = index
            if index == 2 then
                Bridge.activeInsetPane = nil
                Bridge.activePane = "titles"
            elseif index == 3 then
                Bridge.activeInsetPane = nil
                Bridge.activePane = "equipment"
            elseif index == 1 and (Bridge.activePane == "titles" or Bridge.activePane == "equipment") then
                local profile = KT.db and KT.db.profile and KT.db.profile.armory
                Bridge.activeInsetPane = (profile and profile.activeInsetPane) or "stats"
                Bridge.activePane = Bridge.activeInsetPane
            end
            Bridge:UpdatePaneVisibility()
            Bridge:RefreshTextTabs()
        end)

        hooksecurefunc(armory, "Refresh", function()
            Bridge:SyncHeaderPortrait()
            Bridge:SyncUtilityButtons()
            Bridge:UpdatePaneVisibility()
        end)

        hooksecurefunc(armory, "UpdateHeader", function()
            Bridge:SyncHeaderPortrait()
        end)

        hooksecurefunc(armory, "CreateConfigButton", function()
            Bridge:SyncUtilityButtons()
        end)

        hooksecurefunc(armory, "CreateBackgroundSelector", function()
            Bridge:SyncUtilityButtons()
        end)

        hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
            Bridge:UpdateSlotHighlight(button)
        end)

        if _G.PaperDollFrame_UpdateSidebarTabs then
            hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
                -- Blizzard updates its icon tabs here; re-assert the KUI text
                -- strip without replacing the native pane contents.
                Bridge._ktTabBarAnchored = nil
                Bridge:AnchorTabBarToSidebar()
            end)
        end

        if _G.InspectPaperDollItemSlotButton_Update then
            hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
                Bridge:UpdateSlotHighlight(button)
            end)
        end

        if _G.CharacterFrame then
            _G.CharacterFrame:HookScript("OnShow", function()
                Bridge:SyncHeaderPortrait()
                Bridge:SyncUtilityButtons()
                Bridge:UpdatePaneVisibility()
                Bridge:AnchorTabBarToSidebar()
            end)
            _G.CharacterFrame:HookScript("OnHide", function()
                Bridge:UpdatePaneVisibility()
            end)
        end

        if _G.InspectFrame then
            _G.InspectFrame:HookScript("OnShow", function()
                Bridge:RefreshSlotHighlights()
            end)
            _G.InspectFrame:HookScript("OnHide", function()
                Bridge:RefreshSlotHighlights()
            end)
        end

        self._hooksInstalled = true
    end

    self:UpdatePaneVisibility()
end

Bridge:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "KullThranUI_Armory" then
        C_Timer.After(0.1, function()
            Bridge:Setup()
        end)
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_InspectUI" then
        C_Timer.After(0.1, function()
            Bridge:Setup()
            Bridge:RefreshSlotHighlights()
        end)
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(0.2, function()
            Bridge:Setup()
        end)
    elseif event == "WEEKLY_REWARDS_UPDATE" or event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "UPDATE_INSTANCE_INFO" then
        if _G.CharacterFrame and not _G.CharacterFrame:IsShown() then return end
        if Bridge.activeInsetPane == "progress" then
            Bridge:RefreshProgress()
        end
    end
end)

Bridge:RegisterEvent("ADDON_LOADED")
Bridge:RegisterEvent("PLAYER_LOGIN")
Bridge:RegisterEvent("WEEKLY_REWARDS_UPDATE")
Bridge:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
Bridge:RegisterEvent("UPDATE_INSTANCE_INFO")
