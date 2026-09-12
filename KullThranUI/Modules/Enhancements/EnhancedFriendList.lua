local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then
    return
end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then
    return
end

local EnhancedFriendList = Mod.EnhancedFriendList or {}
Mod.EnhancedFriendList = EnhancedFriendList

EnhancedFriendList.bnetClientWoW = _G.BNET_CLIENT_WOW or "WoW"
EnhancedFriendList.projectIcons = {
    retail = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\WoWRetail.png",
    classic = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\SEDbDUlE_400x400.png",
    remix = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\WoWRemix.png",
}
local C_BattleNet = _G.C_BattleNet
local C_ClassColor = _G.C_ClassColor
local C_FriendList = _G.C_FriendList
local C_Timer = _G.C_Timer
local BNGetNumFriends = _G.BNGetNumFriends
local BNInviteFriend = _G.BNInviteFriend
local BNRemoveFriend = _G.BNRemoveFriend
local BNSetBlocked = _G.BNSetBlocked
local BNSetFriendNote = _G.BNSetFriendNote
local CLASS_ICON_TCOORDS = _G.CLASS_ICON_TCOORDS
local ChatEdit_UpdateHeader = _G.ChatEdit_UpdateHeader

local CreateFrame = _G.CreateFrame
local FriendsFrameAddFriendButton_OnClick = _G.FriendsFrameAddFriendButton_OnClick
local GetCurrentRegion = _G.GetCurrentRegion
local LOCALIZED_CLASS_NAMES_FEMALE = _G.LOCALIZED_CLASS_NAMES_FEMALE
local LOCALIZED_CLASS_NAMES_MALE = _G.LOCALIZED_CLASS_NAMES_MALE
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local AddIgnore = _G.AddIgnore
local ipairs = _G.ipairs
local math = _G.math
local pairs = _G.pairs
local pcall = _G.pcall
local canaccessvalue = _G.canaccessvalue
local issecretvalue = _G.issecretvalue
local strgsub = _G.string.gsub
local strfind = _G.strfind
local strlower = _G.strlower
local strsplit = _G.strsplit
local strupper = _G.strupper
local tostring = _G.tostring
local tsort = _G.table.sort
local type = _G.type

local ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local KUI_TEXTURE_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\"
local FRIEND_ICON = ICON_PATH .. "chaticons\\FriendList.png"
local CLASS_ICON = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local MODULE_ICON_PATH = ICON_PATH .. "EnhancedFriendList\\"
local HEADER_FRIENDS_ICON = MODULE_ICON_PATH .. "Friends.png"
local CLOSE_ICON = MODULE_ICON_PATH .. "X.png"
local DELETE_ICON = ICON_PATH .. "kui-close.png"
local INVITE_ICON = ICON_PATH .. "UnitFramesIcons\\Invite.png"
local HORDE_ICON = MODULE_ICON_PATH .. "Horde.png"
local ALLIANCE_ICON = MODULE_ICON_PATH .. "Alliance.png"
local ARROW_DOWN_ICON = MODULE_ICON_PATH .. "ArrowDown.png"
local FRAME_BACKGROUND_TEXTURE = KUI_TEXTURE_PATH .. "Background.png"
local BUTTON_TEXTURE = KUI_TEXTURE_PATH .. "Button.png"
local BUTTON_HOVER_TEXTURE = KUI_TEXTURE_PATH .. "hover.tga"
local BUTTON_PUSHED_TEXTURE = KUI_TEXTURE_PATH .. "pushed.tga"
local GLOSS_TEXTURE = KUI_TEXTURE_PATH .. "gloss.tga"

local function LText(text)
    if type(text) ~= "string" then
        return text
    end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then
            return L[text]
        end
    end
    return text
end
local NAV_ORDER = {
    { key = "contacts", label = LText("Contacts"), tab = "FriendsFrameTab1", frame = "FriendsListFrame" },
    { key = "who", label = LText("Who"), tab = "FriendsFrameTab2", frame = "WhoFrame" },
    { key = "raid", label = LText("Raid"), tab = "FriendsFrameTab3", frame = "RaidFrame", nativePassthrough = true },
    { key = "quickjoin", label = LText("Quick Join"), tab = "FriendsFrameTab4", frame = "QuickJoinFrame", altFrame = "QuickJoinRoleSelectionFrame" },
}

local LAYOUT = {
    windowWidth = 478,
    windowHeight = 640,
    rootInset = 6,
    navHeight = 34,
    panelGap = 6,
    headerHeight = 56,
    footerHeight = 28,
    bodyInset = 8,
    topPanelsHeight = 30,
    topPanelGap = 6,
    scrollInset = 6,
    groupPadding = 8,
    groupHeaderHeight = 24,
    rowHeight = 54,
    rowGap = 6,
    groupGap = 8,
}

local runtime = {
    initialized = false,
    hooksInstalled = false,
    eventFrame = nil,
    refreshScheduled = false,
    refreshDelay = 0.08,
    forcePending = false,
    dataDirty = true,
    cachedDataset = nil,
    baseApplied = false,
    contactsSubView = nil,
    selectedEntry = nil,
    selectedView = "contacts",
    collapsedSections = {},
    original = {
        frameSize = nil,
        alphaStates = {},
        regionAlphaStates = {},
        mouseStates = {},
        movedFrames = {},
    },
}

local function SetForcedHidden(frame, hidden)
    if not frame then
        return
    end

    if hidden then
        frame._eflForceHidden = true
        if not frame._eflForceHideHook and frame.HookScript then
            frame:HookScript("OnShow", function(self)
                if not self._eflForceHidden then
                    return
                end
                if self.SetAlpha then
                    self:SetAlpha(0)
                end
                if self.EnableMouse then
                    self:EnableMouse(false)
                end
                if self.Hide then
                    self:Hide()
                end
            end)
            frame._eflForceHideHook = true
        end
        if frame.SetAlpha then
            frame:SetAlpha(0)
        end
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
        if frame.Hide then
            frame:Hide()
        end
        return
    end

    frame._eflForceHidden = nil
    if frame.SetAlpha then
        frame:SetAlpha(1)
    end
    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
    if frame.Show then
        frame:Show()
    end
end

local CLASS_NAME_TO_FILE = {}
for classFile, localizedName in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
    CLASS_NAME_TO_FILE[localizedName] = classFile
end
for classFile, localizedName in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
    CLASS_NAME_TO_FILE[localizedName] = classFile
end



local function ResolveFont()
    if KT and KT.ResolveFontPath then
        return KT:ResolveFontPath()
    end
    return KT and KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end

local function GetPalette(themeContext)
    if themeContext and themeContext.palette then
        return themeContext.palette
    end

    -- RefreshStylePalette owns the canonical cached palette. Prefer it here:
    -- rebuilding six color tables for every row and button made opening a
    -- large friends list exceed WoW's per-script execution budget.
    local palette = (KT and KT.STYLE_PALETTE)
        or (KT and KT.GetStylePalette and KT:GetStylePalette())
        or {}
    if KT and not KT.STYLE_PALETTE then
        KT.STYLE_PALETTE = palette
    end
    return palette
end

local function AccentColor(alpha, themeContext)
    if themeContext and themeContext.accent then
        local accent = themeContext.accent
        return accent.r or 1, accent.g or 0.35, accent.b or 0.35, alpha or accent.a or 1
    end
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin or nil
    if skin and skin.friendListColorMode == "custom" and skin.friendListColor then
        local c = skin.friendListColor
        return c.r or 1, c.g or 0.35, c.b or 0.35, alpha or 1
    end
    local accent = GetPalette(themeContext).accent or {}
    return accent.r or KT.C_R or 1, accent.g or KT.C_G or 0.35, accent.b or KT.C_B or 0.35, alpha or 1
end

local function TextColor(alpha, themeContext)
    local text = GetPalette(themeContext).text or {}
    return text.r or 1, text.g or 1, text.b or 1, alpha or 1
end

local function MutedColor(alpha, themeContext)
    local muted = GetPalette(themeContext).muted or {}
    return muted.r or 0.74, muted.g or 0.74, muted.b or 0.78, alpha or 1
end

local function BackgroundColor(alpha, themeContext)
    local background = GetPalette(themeContext).background or {}
    return background.r or 0.08, background.g or 0.09, background.b or 0.11, alpha or background.a or 1
end

local function ScrollbarColors(themeContext)
    local ar, ag, ab = AccentColor(nil, themeContext)
    local trackR = 0.08 + (ar * 0.10)
    local trackG = 0.08 + (ag * 0.10)
    local trackB = 0.10 + (ab * 0.12)
    local edgeR = 0.18 + (ar * 0.16)
    local edgeG = 0.18 + (ag * 0.16)
    local edgeB = 0.20 + (ab * 0.18)
    return trackR, trackG, trackB, edgeR, edgeG, edgeB
end

local function ShortName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local shortName = strsplit("-", name, 2)
    return shortName or name
end

local function GetAccessibleString(value, fallback)
    if type(value) ~= "string" then
        return fallback
    end

    if issecretvalue then
        local ok, isSecret = pcall(issecretvalue, value)
        if ok and isSecret then
            return fallback
        end
    end

    if canaccessvalue then
        local ok, canAccess = pcall(canaccessvalue, value)
        if ok and not canAccess then
            return fallback
        end
    end

    return value
end

local function GetNonEmptyString(value, fallback)
    local text = GetAccessibleString(value, fallback)
    if type(text) ~= "string" or text == "" then
        return fallback
    end

    return text
end

local function GetBattleTagBase(target)
    target = GetNonEmptyString(target)
    if not target then
        return nil
    end

    local base = target:match("^([^#]+)") or target
    base = base:match("^%s*(.-)%s*$")
    if base == "" then
        return nil
    end

    return base
end

local function NormalizeWhisperRealmName(realmName)
    realmName = GetNonEmptyString(realmName)
    if not realmName then
        return nil
    end

    realmName = realmName:gsub("[%s%-']+", "")
    return realmName ~= "" and realmName or nil
end

function EnhancedFriendList:GetWoWProjectDisplay(gameInfo)
    if not gameInfo or gameInfo.clientProgram ~= EnhancedFriendList.bnetClientWoW then return nil end
    local presence = strlower(GetNonEmptyString(gameInfo.richPresence, "") or "")
    local projectID = gameInfo.wowProjectID
    local key, label, texture, color, customTexture

    -- Remix uses the mainline project ID, so rich presence must be checked first.
    if presence:find("remix", 1, true) or presence:find("timerunning", 1, true) then
        key, label, texture, customTexture = "remix", LText("WoW Remix"), EnhancedFriendList.projectIcons.remix, true
    elseif presence:find("season of discovery", 1, true) or presence:find("discovery", 1, true) then
        key, label, texture = "sod", LText("Season of Discovery"), "Interface\\Icons\\INV_Misc_Rune_06"
    elseif presence:find("burning crusade", 1, true) or presence:find("tbc classic", 1, true) then
        key, label, texture, color, customTexture = "tbc", LText("TBC Classic"), EnhancedFriendList.projectIcons.retail, { 0.28, 0.95, 0.32, 1 }, true
    elseif presence:find("mists of pandaria", 1, true) or presence:find("pandaria classic", 1, true) then
        key, label, texture, color, customTexture = "mop", LText("Pandaria Classic"), EnhancedFriendList.projectIcons.retail, { 0.24, 0.82, 0.52, 1 }, true
    elseif projectID and _G.WOW_PROJECT_MAINLINE and projectID == _G.WOW_PROJECT_MAINLINE then
        key, label, texture, customTexture = "retail", LText("Retail"), EnhancedFriendList.projectIcons.retail, true
    elseif projectID and _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC and projectID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        key, label, texture, color, customTexture = "tbc", LText("TBC Classic"), EnhancedFriendList.projectIcons.retail, { 0.28, 0.95, 0.32, 1 }, true
    elseif projectID and _G.WOW_PROJECT_MISTS_CLASSIC and projectID == _G.WOW_PROJECT_MISTS_CLASSIC then
        key, label, texture, color, customTexture = "mop", LText("Pandaria Classic"), EnhancedFriendList.projectIcons.retail, { 0.24, 0.82, 0.52, 1 }, true
    elseif projectID and _G.WOW_PROJECT_CATACLYSM_CLASSIC and projectID == _G.WOW_PROJECT_CATACLYSM_CLASSIC then
        key, label, texture = "cata", LText("Cataclysm Classic"), "Interface\\Icons\\Achievement_Boss_Deathwing"
    elseif projectID and _G.WOW_PROJECT_WRATH_CLASSIC and projectID == _G.WOW_PROJECT_WRATH_CLASSIC then
        key, label, texture = "wrath", LText("Wrath Classic"), "Interface\\Icons\\Achievement_Zone_Icecrown_01"
    elseif projectID and _G.WOW_PROJECT_CLASSIC and projectID == _G.WOW_PROJECT_CLASSIC then
        key, label, texture, customTexture = "classic", LText("Classic Era"), EnhancedFriendList.projectIcons.classic, true
    else
        key, label, texture = "wow", LText("World of Warcraft"), "Interface\\FriendsFrame\\Battlenet-WoWicon"
    end

    return {
        key = key,
        label = label,
        texture = texture,
        color = color,
        customTexture = customTexture,
    }
end
local function AddUniqueWhisperTarget(targets, seen, value)
    local text = GetNonEmptyString(value)
    if not text then
        return
    end

    local key = strlower(text)
    if seen[key] then
        return
    end

    seen[key] = true
    targets[#targets + 1] = text
end

local function GetEntryWoWWhisperTargets(entry)
    if not entry then
        return {}
    end

    local targets = {}
    local seen = {}
    local characterName = GetNonEmptyString(entry.characterName) or GetNonEmptyString(entry.name)
    local realmName = NormalizeWhisperRealmName(entry.realmName)
    if characterName and realmName and not strfind(characterName, "-", 1, true) then
        AddUniqueWhisperTarget(targets, seen, characterName .. "-" .. realmName)
    end

    AddUniqueWhisperTarget(targets, seen, entry.fullName)
    AddUniqueWhisperTarget(targets, seen, entry.inviteName)
    AddUniqueWhisperTarget(targets, seen, characterName)
    AddUniqueWhisperTarget(targets, seen, entry.name)
    return targets
end

local function ResolveBNetWhisperDisplayTarget(entry)
    local bnetAccountID = tonumber(entry and entry.bnetAccountID)
    local accountInfo = nil
    if bnetAccountID and C_BattleNet and C_BattleNet.GetAccountInfoByID then
        accountInfo = C_BattleNet.GetAccountInfoByID(bnetAccountID)
    end

    local battleTag = GetNonEmptyString(accountInfo and accountInfo.battleTag)
        or GetNonEmptyString(entry and entry.accountName)
    local accountName = GetNonEmptyString(accountInfo and accountInfo.accountName)
    if accountName then
        return accountName
    end

    local battleTagBase = GetBattleTagBase(battleTag)
    if battleTagBase then
        return battleTagBase
    end

    local gameInfo = accountInfo and accountInfo.gameAccountInfo or nil
    local characterName = GetNonEmptyString(gameInfo and gameInfo.characterName)
        or GetNonEmptyString(entry and entry.characterName)
        or GetNonEmptyString(entry and entry.name)
    if characterName and _G.BNet_GetValidatedCharacterName then
        local ok, validatedName = pcall(_G.BNet_GetValidatedCharacterName, characterName, battleTag)
        characterName = ok and GetNonEmptyString(validatedName, characterName) or characterName
    end

    local realmName = NormalizeWhisperRealmName(
        (gameInfo and (gameInfo.realmName or gameInfo.realmDisplayName))
            or (entry and entry.realmName)
    )
    if characterName and realmName and not strfind(characterName, "-", 1, true) then
        characterName = characterName .. "-" .. realmName
    end

    return characterName or GetNonEmptyString(entry and entry.name)
end

local function ApplyPanelStyle(frame, bgAlpha, borderAlpha, themeContext)
    if not frame then
        return
    end
    local br, bg, bb = BackgroundColor(nil, themeContext)
    if not frame._eflPanelBg then
        frame._eflPanelBg = frame:CreateTexture(nil, "BACKGROUND")
        frame._eflPanelBg:SetAllPoints()
    end
    frame._eflPanelBg:SetColorTexture(br, bg, bb, bgAlpha or 0.96)
end

local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"

local function ApplyTextureGradient(texture, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    if not texture then return end
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2)
        return
    end
    if texture.SetGradient and CreateColor then
        texture:SetGradient(orientation,
            CreateColor(r1, g1, b1, a1),
            CreateColor(r2, g2, b2, a2))
        return
    end
end

local function EnsureOutline(frame)
    if not frame then
        return nil
    end

    if frame._eflOutline then
        return frame._eflOutline
    end

    local outline = {}
    outline.top = frame:CreateTexture(nil, "BORDER")
    outline.top:SetPoint("TOPLEFT")
    outline.top:SetPoint("TOPRIGHT")
    outline.top:SetHeight(1)

    outline.bottom = frame:CreateTexture(nil, "BORDER")
    outline.bottom:SetPoint("BOTTOMLEFT")
    outline.bottom:SetPoint("BOTTOMRIGHT")
    outline.bottom:SetHeight(1)

    outline.left = frame:CreateTexture(nil, "BORDER")
    outline.left:SetPoint("TOPLEFT")
    outline.left:SetPoint("BOTTOMLEFT")
    outline.left:SetWidth(1)

    outline.right = frame:CreateTexture(nil, "BORDER")
    outline.right:SetPoint("TOPRIGHT")
    outline.right:SetPoint("BOTTOMRIGHT")
    outline.right:SetWidth(1)

    frame._eflOutline = outline
    return outline
end

local function SetOutlineColor(frame, r, g, b, a)
    local outline = EnsureOutline(frame)
    if not outline then
        return
    end

    outline.top:SetColorTexture(r, g, b, a)
    outline.bottom:SetColorTexture(r, g, b, a)
    outline.left:SetColorTexture(r, g, b, a)
    outline.right:SetColorTexture(r, g, b, a)
end

local function EnsureSurface(frame)
    if not frame then
        return nil
    end

    if frame._eflSurface then
        return frame._eflSurface
    end

    local surface = {}

    surface.base = frame:CreateTexture(nil, "BACKGROUND")
    surface.base:SetDrawLayer("BACKGROUND", 0)
    surface.base:SetAllPoints()

    surface.pattern = frame:CreateTexture(nil, "BACKGROUND")
    surface.pattern:SetDrawLayer("BACKGROUND", 1)
    surface.pattern:SetAllPoints()
    surface.pattern:SetTexture(BUTTON_TEXTURE)
    surface.pattern:SetTexCoord(0, 1, 0, 1)

    surface.shade = frame:CreateTexture(nil, "BACKGROUND")
    surface.shade:SetDrawLayer("BACKGROUND", 2)
    surface.shade:SetAllPoints()

    surface.gloss = frame:CreateTexture(nil, "ARTWORK")
    surface.gloss:SetDrawLayer("ARTWORK", 0)
    surface.gloss:SetTexture(GLOSS_TEXTURE)
    surface.gloss:SetPoint("TOPLEFT", 1, -1)
    surface.gloss:SetPoint("TOPRIGHT", -1, -1)
    surface.gloss:SetHeight(26)

    surface.topLine = frame:CreateTexture(nil, "ARTWORK")
    surface.topLine:SetDrawLayer("ARTWORK", 1)
    surface.topLine:SetPoint("TOPLEFT", 1, -1)
    surface.topLine:SetPoint("TOPRIGHT", -1, -1)
    surface.topLine:SetHeight(1)

    surface.bottomShade = frame:CreateTexture(nil, "ARTWORK")
    surface.bottomShade:SetDrawLayer("ARTWORK", 1)
    surface.bottomShade:SetPoint("BOTTOMLEFT", 1, 1)
    surface.bottomShade:SetPoint("BOTTOMRIGHT", -1, 1)
    surface.bottomShade:SetHeight(1)

    -- Accent gradient: horizontal from left (accent color) → transparent
    surface.accentGradH = frame:CreateTexture(nil, "BACKGROUND")
    surface.accentGradH:SetDrawLayer("BACKGROUND", 3)
    surface.accentGradH:SetPoint("TOPLEFT", 1, -1)
    surface.accentGradH:SetPoint("BOTTOMLEFT", 1, 1)
    surface.accentGradH:SetTexture(WHITE8X8)

    -- Accent gradient: vertical from top (accent color) → transparent
    surface.accentGradV = frame:CreateTexture(nil, "BACKGROUND")
    surface.accentGradV:SetDrawLayer("BACKGROUND", 4)
    surface.accentGradV:SetPoint("TOPLEFT", 1, -1)
    surface.accentGradV:SetPoint("TOPRIGHT", -1, -1)
    surface.accentGradV:SetTexture(WHITE8X8)

    -- Bottom accent line (1px)
    surface.accentBottomLine = frame:CreateTexture(nil, "ARTWORK")
    surface.accentBottomLine:SetDrawLayer("ARTWORK", 2)
    surface.accentBottomLine:SetPoint("BOTTOMLEFT", 1, 1)
    surface.accentBottomLine:SetPoint("BOTTOMRIGHT", -1, 1)
    surface.accentBottomLine:SetHeight(1)
    surface.accentBottomLine:SetTexture(WHITE8X8)

    frame._eflSurface = surface
    return surface
end

local function ApplySurface(frame, texturePath, baseR, baseG, baseB, baseA, patternA, lineA, borderA, gradH, gradV, botLineA, themeContext)
    local surface = EnsureSurface(frame)
    if not surface then
        return
    end

    local accentR, accentG, accentB = AccentColor(nil, themeContext)
    surface.pattern:SetTexture(texturePath or BUTTON_TEXTURE)
    if texturePath == FRAME_BACKGROUND_TEXTURE then
        surface.pattern:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        surface.pattern:SetTexCoord(0, 1, 0, 1)
    end
    surface.base:SetColorTexture(baseR, baseG, baseB, baseA)
    surface.pattern:SetVertexColor(1, 1, 1, patternA or 0)
    surface.shade:SetColorTexture(0, 0, 0, 0.16)
    surface.gloss:SetVertexColor(1, 1, 1, 0.08)
    surface.topLine:SetColorTexture(accentR, accentG, accentB, lineA or 0.08)
    surface.bottomShade:SetColorTexture(1, 1, 1, 0.03)
    SetOutlineColor(frame, 0.18, 0.18, 0.23, borderA or 0.85)

    -- Horizontal accent gradient (left → transparent), covers 60% width
    local hAlpha = gradH or 0
    if hAlpha > 0 then
        local frameW = frame:GetWidth()
        surface.accentGradH:SetWidth(math.max(1, (frameW > 0 and frameW or 400) * 0.6))
        surface.accentGradH:SetTexture(WHITE8X8)
        ApplyTextureGradient(surface.accentGradH, "HORIZONTAL",
            accentR, accentG, accentB, hAlpha,
            accentR, accentG, accentB, 0)
        surface.accentGradH:Show()
    else
        surface.accentGradH:Hide()
    end

    -- Vertical accent gradient (top → transparent), covers 45% height
    local vAlpha = gradV or 0
    if vAlpha > 0 then
        local frameH = frame:GetHeight()
        surface.accentGradV:SetHeight(math.max(1, (frameH > 0 and frameH or 100) * 0.45))
        surface.accentGradV:SetTexture(WHITE8X8)
        ApplyTextureGradient(surface.accentGradV, "VERTICAL",
            accentR, accentG, accentB, 0,
            accentR, accentG, accentB, vAlpha)
        surface.accentGradV:Show()
    else
        surface.accentGradV:Hide()
    end

    -- Bottom accent line
    local blA = botLineA or 0
    if blA > 0 then
        ApplyTextureGradient(surface.accentBottomLine, "HORIZONTAL",
            accentR, accentG, accentB, 0,
            accentR, accentG, accentB, blA)
        surface.accentBottomLine:Show()
    else
        surface.accentBottomLine:Hide()
    end
end

local function ApplyShellStyle(frame, bgAlpha, themeContext)
    if not frame then
        return
    end
    -- Shell: vertical glow from top, faint horizontal, bottom accent line right-aligned
    ApplySurface(frame, FRAME_BACKGROUND_TEXTURE, 0.018, 0.018, 0.024, bgAlpha or 0.985, 0.16, 0.18, 0.95, 0.06, 0.08, 0.12, themeContext)
end

local function ApplySectionStyle(frame, bgAlpha, borderAlpha, themeContext)
    if not frame then
        return
    end
    -- Sections: noticeable horizontal gradient + subtle top glow + bottom accent line
    ApplySurface(frame, BUTTON_TEXTURE, 0.055, 0.055, 0.07, bgAlpha or 0.96, 0.20, 0.14, borderAlpha or 0.88, 0.10, 0.07, 0.08, themeContext)
end

local function ApplyInsetStyle(frame, bgAlpha, themeContext)
    if not frame then
        return
    end
    -- Insets: visible horizontal gradient, no vertical, no bottom line
    ApplySurface(frame, BUTTON_TEXTURE, 0.038, 0.038, 0.048, bgAlpha or 0.98, 0.16, 0.08, 0.9, 0.07, 0, 0, themeContext)
end

local function EnsureButtonArt(button)
    if not button then
        return nil
    end

    if button._eflButtonArt then
        return button._eflButtonArt
    end

    local art = {}

    art.base = button:CreateTexture(nil, "BACKGROUND")
    art.base:SetAllPoints()
    art.base:SetColorTexture(0.045, 0.045, 0.06, 0.96)

    art.pattern = button:CreateTexture(nil, "BACKGROUND")
    art.pattern:SetAllPoints()
    art.pattern:SetTexture(BUTTON_TEXTURE)
    art.pattern:SetVertexColor(1, 1, 1, 0.28)

    art.tint = button:CreateTexture(nil, "BACKGROUND")
    art.tint:SetAllPoints()
    art.tint:SetColorTexture(1, 1, 1, 0)

    art.gloss = button:CreateTexture(nil, "ARTWORK")
    art.gloss:SetAllPoints()
    art.gloss:SetTexture(GLOSS_TEXTURE)
    art.gloss:SetVertexColor(1, 1, 1, 0.08)

    art.hover = button:CreateTexture(nil, "HIGHLIGHT")
    art.hover:SetAllPoints()
    art.hover:SetTexture(BUTTON_HOVER_TEXTURE)
    art.hover:SetVertexColor(1, 1, 1, 0)

    art.pushed = button:CreateTexture(nil, "ARTWORK")
    art.pushed:SetAllPoints()
    art.pushed:SetTexture(BUTTON_PUSHED_TEXTURE)
    art.pushed:SetVertexColor(1, 1, 1, 0)

    art.activeBar = button:CreateTexture(nil, "ARTWORK")
    art.activeBar:SetPoint("BOTTOMLEFT", 4, 3)
    art.activeBar:SetPoint("BOTTOMRIGHT", -4, 3)
    art.activeBar:SetHeight(2)

    art.accentGrad = button:CreateTexture(nil, "BACKGROUND")
    art.accentGrad:SetDrawLayer("BACKGROUND", 3)
    art.accentGrad:SetPoint("TOPLEFT", 1, -1)
    art.accentGrad:SetPoint("BOTTOMLEFT", 1, 1)
    art.accentGrad:SetTexture(WHITE8X8)
    art.accentGrad:Hide()

    button._eflButtonArt = art
    return art
end

local function RefreshButtonStyle(button)
    if not button then
        return
    end

    local art = EnsureButtonArt(button)
    local themeContext = button._eflThemeContext
    local accentR, accentG, accentB = AccentColor(nil, themeContext)
    local variant = button._eflVariant or "default"
    local selected = button._eflSelected and true or false
    local hovered = button._eflHovered and true or false
    local pressed = button._eflPressed and true or false
    local enabled = button:IsEnabled()
    local outlineAlpha = 0.34
    local activeAlpha = 0
    local patternAlpha = 0.22
    local topAlpha = 0.08
    local tintAlpha = 0
    local baseAlpha = 0.96

    if variant == "footer" then
        patternAlpha = 0.50
        outlineAlpha = 0.70
        activeAlpha = 0.56
        topAlpha = 0.18
        tintAlpha = 0.08
        baseAlpha = 1
    elseif variant == "invite" then
        patternAlpha = 0.26
        outlineAlpha = 0.62
        activeAlpha = 0.42
        tintAlpha = 0.06
    elseif variant == "nav" then
        patternAlpha = selected and 0.42 or 0.24
        outlineAlpha = selected and 0.62 or 0.34
        activeAlpha = selected and 0.95 or 0
        topAlpha = selected and 0.18 or 0.08
        tintAlpha = selected and 0.08 or 0
    elseif variant == "menu" then
        patternAlpha = selected and 0.32 or 0.24
        outlineAlpha = selected and 0.64 or 0.46
        activeAlpha = selected and 0.72 or 0
        topAlpha = selected and 0.16 or 0.10
        tintAlpha = selected and 0.06 or 0.02
        baseAlpha = 0.98
    elseif variant == "icon" then
        patternAlpha = 0.18
        outlineAlpha = 0.44
    end

    if hovered then
        if variant == "invite" then
            patternAlpha = patternAlpha + 0.18
            outlineAlpha = outlineAlpha + 0.20
            topAlpha = topAlpha + 0.14
            tintAlpha = tintAlpha + 0.14
        elseif variant == "menu" then
            patternAlpha = patternAlpha + 0.06
            outlineAlpha = outlineAlpha + 0.10
            topAlpha = topAlpha + 0.06
            tintAlpha = tintAlpha + 0.05
        else
            patternAlpha = patternAlpha + 0.08
            outlineAlpha = outlineAlpha + 0.10
            topAlpha = topAlpha + 0.08
            tintAlpha = tintAlpha + 0.06
        end
    end

    if pressed then
        if variant == "invite" then
            patternAlpha = patternAlpha + 0.12
            tintAlpha = tintAlpha + 0.10
        elseif variant == "menu" then
            patternAlpha = patternAlpha + 0.04
            tintAlpha = tintAlpha + 0.04
        else
            patternAlpha = patternAlpha + 0.08
            tintAlpha = tintAlpha + 0.04
        end
    end

    if not enabled then
        patternAlpha = patternAlpha * 0.55
        outlineAlpha = outlineAlpha * 0.6
        topAlpha = topAlpha * 0.4
        activeAlpha = activeAlpha * 0.5
        tintAlpha = tintAlpha * 0.5
        baseAlpha = baseAlpha * 0.9
    end

    art.base:SetColorTexture(0.045, 0.045, 0.06, baseAlpha)
    art.pattern:SetVertexColor(1, 1, 1, patternAlpha)
    art.tint:SetColorTexture(accentR, accentG, accentB, tintAlpha)
    art.gloss:SetVertexColor(1, 1, 1, selected and 0.10 or 0.07)
    art.hover:SetVertexColor(1, 1, 1, hovered and ((variant == "invite" and 0.45) or (variant == "menu" and 0.14) or 0.32) or 0)
    art.pushed:SetVertexColor(1, 1, 1, pressed and ((variant == "invite" and 0.50) or (variant == "menu" and 0.18) or 0.35) or 0)
    art.activeBar:SetColorTexture(accentR, accentG, accentB, activeAlpha)

    -- Accent gradient on buttons
    local gradAlpha = 0
    if selected then
        gradAlpha = 0.14
    elseif hovered then
        gradAlpha = (variant == "invite" and 0.18) or (variant == "menu" and 0.08) or 0.10
    elseif variant == "footer" then
        gradAlpha = 0.08
    elseif variant == "invite" then
        gradAlpha = 0.05
    elseif variant == "menu" then
        gradAlpha = 0.04
    end
    if gradAlpha > 0 and art.accentGrad then
        local bw = button:GetWidth()
        art.accentGrad:SetWidth(math.max(1, (bw > 0 and bw or 100) * 0.5))
        ApplyTextureGradient(art.accentGrad, "HORIZONTAL",
            accentR, accentG, accentB, gradAlpha,
            accentR, accentG, accentB, 0)
        art.accentGrad:Show()
    elseif art.accentGrad then
        art.accentGrad:Hide()
    end

    if variant == "invite" then
        if hovered or pressed then
            SetOutlineColor(button, accentR, accentG, accentB, 0.90)
        else
            SetOutlineColor(button, accentR, accentG, accentB, outlineAlpha)
        end
    elseif selected then
        SetOutlineColor(button, accentR, accentG, accentB, outlineAlpha)
    elseif hovered then
        SetOutlineColor(button, accentR, accentG, accentB, 0.55)
    else
        SetOutlineColor(button, 0.26, 0.26, 0.32, outlineAlpha + 0.20)
    end

    if button.label then
        if enabled then
            if variant == "invite" and hovered then
                button.label:SetTextColor(accentR, accentG, accentB, 1)
            elseif variant == "menu" and selected then
                button.label:SetTextColor(accentR, accentG, accentB, 1)
            elseif variant == "menu" and hovered then
                local tr, tg, tb = TextColor(nil, themeContext)
                button.label:SetTextColor(tr, tg, tb, 1)
            elseif selected or variant == "invite" or variant == "footer" then
                local tr, tg, tb = TextColor(nil, themeContext)
                button.label:SetTextColor(tr, tg, tb, 1)
            elseif hovered then
                button.label:SetTextColor(1, 1, 1, 1)
            else
                local mr, mg, mb = MutedColor(nil, themeContext)
                button.label:SetTextColor(mr, mg, mb, 0.95)
            end
        else
            local mr, mg, mb = MutedColor(nil, themeContext)
            button.label:SetTextColor(mr, mg, mb, 0.55)
        end
    end

    if button.inviteIcon then
        local iconAlpha = enabled and 1 or 0.55
        local isPlusAction = variant == 'invite'
            and button.label
            and button.label:GetText() == '+'
        if isPlusAction then
            button.label:SetShown(false)
        end
        button.inviteIcon:SetTexture(INVITE_ICON)
        button.inviteIcon:SetTexCoord(0.03, 0.97, 0.03, 0.97)
        if button.inviteIcon.SetDesaturated then
            button.inviteIcon:SetDesaturated(true)
        end
        button.inviteIcon:SetBlendMode('ADD')
        button.inviteIcon:SetVertexColor(accentR, accentG, accentB, 1)
        button.inviteIcon:SetAlpha(iconAlpha)
        button.inviteIcon:SetShown(isPlusAction)
    end
end

local function ApplyButtonStyle(button, variant)
    if not button then
        return
    end

    button._eflVariant = variant or button._eflVariant or "default"
    EnsureButtonArt(button)
    RefreshButtonStyle(button)
end

local function CreateLabel(parent, size, r, g, b, a, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ResolveFont(), size, flags or "")
    fs:SetTextColor(r, g, b, a or 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function CapturePoints(frame)
    if not frame then
        return nil
    end
    local points = {}
    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        points[index] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
    return {
        parent = frame:GetParent(),
        strata = frame.GetFrameStrata and frame:GetFrameStrata() or nil,
        level = frame.GetFrameLevel and frame:GetFrameLevel() or nil,
        points = points,
    }
end

local function RestorePoints(frame, state)
    if not (frame and state) then
        return
    end
    if state.parent then
        frame:SetParent(state.parent)
    end
    if state.strata and frame.SetFrameStrata then
        frame:SetFrameStrata(state.strata)
    end
    if state.level and frame.SetFrameLevel then
        frame:SetFrameLevel(state.level)
    end
    frame:ClearAllPoints()
    if state.points then
        for _, point in ipairs(state.points) do
            frame:SetPoint(point.point, point.relativeTo, point.relativePoint, point.x, point.y)
        end
    end
end

local function RememberMovedFrame(key, frame)
    if not (key and frame) then
        return
    end
    if not runtime.original.movedFrames[key] then
        runtime.original.movedFrames[key] = CapturePoints(frame)
    end
end

local function SetFrameAlphaState(frame, hidden)
    if not frame then
        return
    end
    if hidden then
        if not runtime.original.alphaStates[frame] then
            runtime.original.alphaStates[frame] = {
                alpha = frame.GetAlpha and frame:GetAlpha() or 1,
                mouse = frame.IsMouseEnabled and frame:IsMouseEnabled() or false,
            }
        end
        if frame.SetAlpha then
            frame:SetAlpha(0)
        end
        if frame.EnableMouse then
            frame:EnableMouse(false)
        end
    else
        local state = runtime.original.alphaStates[frame]
        if state then
            if frame.SetAlpha then
                frame:SetAlpha(state.alpha or 1)
            end
            if frame.EnableMouse then
                frame:EnableMouse(state.mouse and true or false)
            end
            runtime.original.alphaStates[frame] = nil
        end
    end
end

-- Alpha-zero Blizzard friend rows still participate in hit testing. Keep the
-- native contacts tree inert while the KUI list owns the same screen area.
local function SetNativeContactsMouse(enabled)
    -- This helper is declared before the local GetFriendsFrame() accessor.
    -- Use the frame directly here so Lua does not resolve that accessor as nil.
    local friendsFrame = _G.FriendsFrame
    local targets = {
        _G.FriendsListFrame,
        _G.FriendsListFrame and _G.FriendsListFrame.ScrollBox or nil,
        _G.FriendsListFrame and _G.FriendsListFrame.ScrollBar or nil,
        friendsFrame and friendsFrame.BattlenetFrame or nil,
    }
    local seen = {}

    local function Visit(frame)
        if not (frame and not seen[frame]) then return end
        seen[frame] = true
        if frame.IsMouseEnabled and frame.EnableMouse then
            if enabled then
                local state = runtime.original.mouseStates[frame]
                if state ~= nil then
                    frame:EnableMouse(state)
                    runtime.original.mouseStates[frame] = nil
                end
            else
                if runtime.original.mouseStates[frame] == nil then
                    runtime.original.mouseStates[frame] = frame:IsMouseEnabled() and true or false
                end
                frame:EnableMouse(false)
            end
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                Visit(child)
            end
        end
    end

    for _, frame in ipairs(targets) do
        Visit(frame)
    end
end

local function HideUnderlyingFriendTooltip()
    local tooltip = _G.GameTooltip
    if tooltip and tooltip:IsShown() then
        tooltip:Hide()
    end
end

local function RefreshSummaryPanelState(panel)
    if not panel then
        return
    end

    local ar, ag, ab = AccentColor(nil, panel._eflThemeContext)
    local hovered = panel._eflHovered and true or false
    local selected = panel._eflSelected and true or false

    if selected then
        SetOutlineColor(panel, ar, ag, ab, 0.82)
        if panel._eflSurface and panel._eflSurface.accentBottomLine then
            panel._eflSurface.accentBottomLine:SetColorTexture(ar, ag, ab, 0.78)
        end
        return
    end

    if hovered then
        SetOutlineColor(panel, ar, ag, ab, 0.52)
        if panel._eflSurface and panel._eflSurface.accentBottomLine then
            panel._eflSurface.accentBottomLine:SetColorTexture(ar, ag, ab, 0.42)
        end
        return
    end

    SetOutlineColor(panel, 0.18, 0.18, 0.23, 0.9)
    if panel._eflSurface and panel._eflSurface.accentBottomLine then
        panel._eflSurface.accentBottomLine:SetColorTexture(ar, ag, ab, 0.08)
    end
end

local function NormalizePreviewAccent(accentColor)
    if type(accentColor) ~= "table" then
        return nil
    end

    local r = accentColor.r or accentColor[1]
    local g = accentColor.g or accentColor[2]
    local b = accentColor.b or accentColor[3]
    if r == nil or g == nil or b == nil then
        return nil
    end

    return r, g, b
end

local function CreatePreviewThemeContext(accentColor)
    local r, g, b = NormalizePreviewAccent(accentColor)
    if not r then
        return nil
    end

    return {
        palette = GetPalette(),
        accent = { r = r, g = g, b = b, a = 1 },
    }
end

local function GetFriendsFrame()
    return _G.FriendsFrame
end

local function ShouldUseCustomList()
    local db = Mod.GetDB and Mod:GetDB() or nil
    if not db or db.enable == false then
        return false
    end
    return not (db.social and db.social.enhancedFriendList == false)
end

-- ── Friend Groups (CRUD helpers) ────────────────────────────────────────────
local function GetSocialDB()
    local db = Mod.GetDB and Mod:GetDB() or nil
    if not db then return nil end
    if not db.social then db.social = {} end
    if not db.social.friendGroups then db.social.friendGroups = {} end
    if not db.social.friendGroupAssignments then db.social.friendGroupAssignments = {} end
    if not db.social.friendNotes then db.social.friendNotes = {} end
    return db.social
end

local function GetFriendGroups()
    local social = GetSocialDB()
    return social and social.friendGroups or {}
end

local function AddFriendGroup(name)
    local social = GetSocialDB()
    if not social then return false end
    for _, g in ipairs(social.friendGroups) do
        if g == name then return false end
    end
    social.friendGroups[#social.friendGroups + 1] = name
    return true
end

local function RemoveFriendGroup(name)
    local social = GetSocialDB()
    if not social then return end
    for i = #social.friendGroups, 1, -1 do
        if social.friendGroups[i] == name then
            table.remove(social.friendGroups, i)
        end
    end
    for id, g in pairs(social.friendGroupAssignments) do
        if g == name then
            social.friendGroupAssignments[id] = nil
        end
    end
end

local function AssignFriendToGroup(friendID, groupName)
    local social = GetSocialDB()
    if not social then return end
    if groupName == nil or groupName == "" then
        social.friendGroupAssignments[friendID] = nil
    else
        social.friendGroupAssignments[friendID] = groupName
    end
end

local function GetFriendGroup(friendID)
    local social = GetSocialDB()
    if not social then return nil end
    return social.friendGroupAssignments[friendID]
end

local function IsStableFriendGroupKey(key)
    if type(key) ~= "string" then
        return false
    end

    return key:match("^bnet%-tag:")
        or key:match("^wow%-guid:")
        or key:match("^wow%-name:")
end

local function IsLegacyFriendGroupKey(key)
    if type(key) ~= "string" then
        return false
    end

    return key:match("^bnet:")
        or key:match("^bnet%-id:")
        or key:match("^wow:")
        or key:match("^bnet%-name:")
end

local ClearEntryGroupAliases = function()
end

local function NormalizeFriendGroupKeyPart(value)
    local text = GetNonEmptyString(value)
    if not text then
        return nil
    end
    return strlower(text)
end

local function GetEntryGroupKey(entry)
    if not entry then
        return nil
    end

    if entry.kind == "bnet" then
        local battleTag = NormalizeFriendGroupKeyPart(entry.battleTag)
        if battleTag then
            return "bnet-tag:" .. battleTag
        end

        -- Battle.net account IDs can drift between sessions, which causes
        -- saved groups to stick to the wrong friend after a reload.
        local bnetAccountID = tonumber(entry.bnetAccountID)
        if bnetAccountID then
            return "bnet-id:" .. tostring(bnetAccountID)
        end
    elseif entry.kind == "wow" then
        local guid = GetNonEmptyString(entry.guid)
        if guid then
            return "wow-guid:" .. guid
        end

        local fullName = NormalizeFriendGroupKeyPart(entry.fullName or entry.inviteName or entry.name)
        if fullName then
            return "wow-name:" .. fullName
        end

        return GetNonEmptyString(entry.id)
    end

    return nil
end

local function AppendEntryGroupAlias(aliases, seen, value)
    local text = GetNonEmptyString(value)
    if not text then
        return
    end

    local lowered = strlower(text)
    if seen[lowered] then
        return
    end

    seen[lowered] = true
    aliases[#aliases + 1] = text
end

local function GetEntryGroupAliases(entry)
    local aliases = {}
    local seen = {}
    local primary = GetEntryGroupKey(entry)
    if primary then
        AppendEntryGroupAlias(aliases, seen, primary)
    end

    if not entry then
        return aliases
    end

    if entry.kind == "bnet" then
        local battleTag = GetNonEmptyString(entry.battleTag)
        if battleTag then
            AppendEntryGroupAlias(aliases, seen, "bnet:" .. battleTag)
        end
    elseif entry.kind == "wow" then
        local guid = GetNonEmptyString(entry.guid)
        if guid then
            AppendEntryGroupAlias(aliases, seen, "wow:" .. guid)
        end

        local fullName = GetNonEmptyString(entry.fullName)
        if fullName and not fullName:match("^%d+$") then
            AppendEntryGroupAlias(aliases, seen, "wow:" .. fullName)
        end
    end

    return aliases
end

local function GetDeprecatedEntryGroupAliases(entry)
    local aliases = {}
    local seen = {}
    if not entry or entry.kind ~= "bnet" then
        return aliases
    end

    -- Older builds also used accountName/displayName-derived keys for Battle.net
    -- groups. Those values are not guaranteed to be unique or stable, so they can
    -- make unrelated friends inherit a group after reload/login.
    local accountName = GetNonEmptyString(entry.accountName)
    if accountName then
        AppendEntryGroupAlias(aliases, seen, "bnet:" .. accountName)
    end

    local displayName = NormalizeFriendGroupKeyPart(entry.fullName or entry.name)
    if displayName then
        AppendEntryGroupAlias(aliases, seen, "bnet-name:" .. displayName)
    end

    return aliases
end

local function AddFriendGroupAliasOwner(ownerMap, alias, primary)
    if not (ownerMap and alias and primary) or alias == primary then
        return
    end

    local owner = ownerMap[alias]
    if not owner then
        ownerMap[alias] = { primary = primary, ambiguous = false }
        return
    end

    if owner.primary ~= primary then
        owner.ambiguous = true
    end
end

local function MigrateFriendGroupAssignments(entries)
    local social = GetSocialDB()
    if not social then
        return
    end

    local aliasOwners = {}

    for _, entry in ipairs(entries or {}) do
        local primary = GetEntryGroupKey(entry)
        if primary then
            for _, alias in ipairs(GetEntryGroupAliases(entry)) do
                AddFriendGroupAliasOwner(aliasOwners, alias, primary)
            end
        end
    end

    for alias, owner in pairs(aliasOwners) do
        local groupName = social.friendGroupAssignments[alias]
        if groupName then
            if not owner.ambiguous and owner.primary and social.friendGroupAssignments[owner.primary] == nil then
                social.friendGroupAssignments[owner.primary] = groupName
            end

            if owner.primary ~= alias then
                social.friendGroupAssignments[alias] = nil
            end
        end
    end

    -- Older builds stored Battle.net group assignments using accountName and
    -- displayName-derived aliases. Those values are not stable enough to
    -- migrate safely, and can make unrelated friends inherit groups after a
    -- relog. Clean them up instead of reassigning them.
    for _, entry in ipairs(entries or {}) do
        for _, alias in ipairs(GetDeprecatedEntryGroupAliases(entry)) do
            social.friendGroupAssignments[alias] = nil
        end
    end
end

local function SanitizeFriendGroupAssignments(entries)
    local social = GetSocialDB()
    if not social then
        return nil
    end

    local stats = {
        removedInvalidGroups = 0,
        removedLegacyKeys = 0,
        removedStaleKeys = 0,
        removedUnknownKeys = 0,
        removedEmptyGroups = 0,
        removedDuplicateGroups = 0,
    }

    local cleanedGroups = {}
    local seenGroups = {}

    for _, name in ipairs(social.friendGroups or {}) do
        local cleanName = GetNonEmptyString(name)
        if not cleanName then
            stats.removedEmptyGroups = stats.removedEmptyGroups + 1
        else
            local lowered = strlower(cleanName)
            if seenGroups[lowered] then
                stats.removedDuplicateGroups = stats.removedDuplicateGroups + 1
            else
                seenGroups[lowered] = true
                cleanedGroups[#cleanedGroups + 1] = cleanName
            end
        end
    end

    social.friendGroups = cleanedGroups

    local validGroups = {}
    for _, name in ipairs(cleanedGroups) do
        validGroups[name] = true
    end

    MigrateFriendGroupAssignments(entries)

    local validPrimaryKeys = {}
    for _, entry in ipairs(entries or {}) do
        local primary = GetEntryGroupKey(entry)
        if primary then
            validPrimaryKeys[primary] = true
            if ClearEntryGroupAliases then
                ClearEntryGroupAliases(entry, primary)
            end
        end
    end

    local canPruneByRoster = next(validPrimaryKeys) ~= nil

    for key, groupName in pairs(social.friendGroupAssignments or {}) do
        if type(groupName) ~= "string" or groupName == "" or not validGroups[groupName] then
            social.friendGroupAssignments[key] = nil
            stats.removedInvalidGroups = stats.removedInvalidGroups + 1
        elseif IsLegacyFriendGroupKey(key) then
            if canPruneByRoster or key:match("^bnet%-name:") then
                social.friendGroupAssignments[key] = nil
                stats.removedLegacyKeys = stats.removedLegacyKeys + 1
            end
        elseif type(key) ~= "string" or not IsStableFriendGroupKey(key) then
            if canPruneByRoster then
                social.friendGroupAssignments[key] = nil
                stats.removedUnknownKeys = stats.removedUnknownKeys + 1
            end
        elseif canPruneByRoster and not validPrimaryKeys[key] then
            social.friendGroupAssignments[key] = nil
            stats.removedStaleKeys = stats.removedStaleKeys + 1
        end
    end

    stats.totalRemoved = stats.removedInvalidGroups
        + stats.removedLegacyKeys
        + stats.removedStaleKeys
        + stats.removedUnknownKeys
        + stats.removedEmptyGroups
        + stats.removedDuplicateGroups

    return stats
end

local function ResetFriendGroupAssignments()
    local social = GetSocialDB()
    if not social then
        return 0
    end

    local removed = 0
    for key in pairs(social.friendGroupAssignments or {}) do
        social.friendGroupAssignments[key] = nil
        removed = removed + 1
    end

    return removed
end

local function MaybeReportFriendGroupCleanup(stats)
    if not stats or not stats.totalRemoved or stats.totalRemoved <= 0 then
        return
    end

    if runtime.friendGroupCleanupReported then
        return
    end

    runtime.friendGroupCleanupReported = true

    if KT and KT.Print then
        KT:Print(string.format(
            "|cff00c8ffEnhanced Friend List|r: cleaned %d stale or unstable friend-group entries. If any custom group is still wrong, use |cffffff00/ktfixfriendgroups|r and reassign it.",
            stats.totalRemoved
        ))
    end
end

ClearEntryGroupAliases = function(entry, keepKey)
    local social = GetSocialDB()
    if not social then
        return
    end

    for _, alias in ipairs(GetEntryGroupAliases(entry)) do
        if alias ~= keepKey then
            social.friendGroupAssignments[alias] = nil
        end
    end

    for _, alias in ipairs(GetDeprecatedEntryGroupAliases(entry)) do
        if alias ~= keepKey then
            social.friendGroupAssignments[alias] = nil
        end
    end
end

local function AssignEntryToGroup(entry, groupName)
    local groupKey = GetEntryGroupKey(entry)
    if not groupKey then
        return
    end

    AssignFriendToGroup(groupKey, groupName)
    ClearEntryGroupAliases(entry, groupKey)
end

local function GetEntryAssignedGroup(entry)
    local social = GetSocialDB()
    if not social then
        return nil
    end

    local primary = GetEntryGroupKey(entry)
    if primary and social.friendGroupAssignments[primary] then
        return social.friendGroupAssignments[primary]
    end

    for _, alias in ipairs(GetEntryGroupAliases(entry)) do
        local groupName = social.friendGroupAssignments[alias]
        if groupName then
            if primary and primary ~= alias then
                social.friendGroupAssignments[primary] = groupName
                social.friendGroupAssignments[alias] = nil
            end
            return groupName
        end
    end

    return nil
end

local function NormalizeFriendNote(noteText)
    if type(noteText) ~= "string" then
        return nil
    end

    local trimmed = noteText:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil
    end

    return trimmed
end

local function GetStoredFriendNote(friendID)
    local social = GetSocialDB()
    if not social or not friendID then
        return nil
    end

    return NormalizeFriendNote(social.friendNotes[friendID])
end

local function SetStoredFriendNote(friendID, noteText)
    local social = GetSocialDB()
    if not social or not friendID then
        return
    end

    local normalized = NormalizeFriendNote(noteText)
    if normalized then
        social.friendNotes[friendID] = normalized
    else
        social.friendNotes[friendID] = nil
    end
end

local function ResolveFriendNote(friendID, ...)
    local stored = GetStoredFriendNote(friendID)
    if stored then
        return stored
    end

    for index = 1, select("#", ...) do
        local candidate = NormalizeFriendNote(select(index, ...))
        if candidate then
            return candidate
        end
    end

    return nil
end

local REGION_SLUGS = {
    [1] = "us",
    [2] = "kr",
    [3] = "eu",
    [4] = "tw",
    [5] = "cn",
}

local function GetRegionSlug()
    local region = GetCurrentRegion and GetCurrentRegion()
    return REGION_SLUGS[region] or "us"
end

local function GetEntryDisplayName(entry)
    if not entry then
        return LText("Friend")
    end
    return entry.line1 or entry.name or entry.fullName or entry.accountName or LText("Friend")
end

local function GetEntryIgnoreName(entry)
    if not entry then
        return nil
    end
    return entry.fullName or entry.inviteName or entry.name or entry.characterName
end

local function NormalizeRaiderIOSlug(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local slug = strlower(text)
    slug = strgsub(slug, "[%s_]+", "-")
    slug = strgsub(slug, "[\"'`]", "")
    slug = strgsub(slug, "%-+", "-")
    slug = strgsub(slug, "^%-+", "")
    slug = strgsub(slug, "%-+$", "")

    return slug ~= "" and slug or nil
end

local function GetEntryRealmName(entry)
    if not entry then
        return nil
    end

    if entry.realmName and entry.realmName ~= "" then
        return entry.realmName
    end

    if entry.fullName and strfind(entry.fullName, "-", 1, true) then
        local _, realmName = strsplit("-", entry.fullName, 2)
        if realmName and realmName ~= "" then
            return realmName
        end
    end

    return nil
end

local function GetEntryRaiderIOLink(entry)
    if not entry then
        return nil
    end

    local realmName = NormalizeRaiderIOSlug(GetEntryRealmName(entry))
    local characterName = entry.characterName or entry.name
    if type(characterName) ~= "string" or characterName == "" then
        return nil
    end
    if not realmName or entry.kind == "system" or entry.kind == "invite" then
        return nil
    end

    return string.format("https://raider.io/characters/%s/%s/%s", GetRegionSlug(), realmName, characterName)
end

local function GetStatusColor(entry)
    if not entry or entry.statusKey == "offline" then
        return 0.45, 0.48, 0.55
    end
    if entry.statusKey == "pending" then
        return 0.36, 0.68, 0.94
    end
    if entry.statusKey == "away" then
        return 0.89, 0.72, 0.21
    end
    if entry.statusKey == "busy" then
        return 0.86, 0.32, 0.32
    end
    return 0.28, 0.77, 0.51
end

local function NormalizeClassFile(className)
    if type(className) ~= "string" or className == "" then
        return nil
    end

    local direct = strupper(strgsub(className, "%s+", ""))
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[direct] then
        return direct
    end

    return CLASS_NAME_TO_FILE[className]
end

local function GetClassColor(classFile)
    if not classFile then
        return nil
    end

    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFile)
        if color then
            return color.r, color.g, color.b
        end
    end

    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r, color.g, color.b
    end

    return nil
end

local function InviteEntry(entry)
    if not entry or not entry.inviteable then
        return
    end

    if entry.kind == "bnet" then
        if BNInviteFriend and entry.gameAccountID then
            pcall(BNInviteFriend, entry.gameAccountID)
            return
        end
        if _G.C_PartyInfo and _G.C_PartyInfo.InviteUnit and entry.inviteName then
            pcall(_G.C_PartyInfo.InviteUnit, entry.inviteName)
        end
        return
    end

    if _G.C_PartyInfo and _G.C_PartyInfo.InviteUnit and entry.inviteName then
        pcall(_G.C_PartyInfo.InviteUnit, entry.inviteName)
    end
end

local function IsPendingInviteEntry(entry)
    return entry and entry.kind == "invite" and entry.inviteID ~= nil
end

local function CanAcceptInviteEntry(entry)
    return IsPendingInviteEntry(entry) and _G.BNAcceptFriendInvite ~= nil
end

local function CanDeclineInviteEntry(entry)
    return IsPendingInviteEntry(entry) and _G.BNDeclineFriendInvite ~= nil
end

local function RefreshAfterInviteAction(entry)
    if runtime.selectedEntry and entry and runtime.selectedEntry.id == entry.id then
        runtime.selectedEntry = nil
    end
    runtime.cachedDataset = nil
    runtime.dataDirty = true
    if EnhancedFriendList and EnhancedFriendList.RequestRefresh then
        EnhancedFriendList:RequestRefresh(true)
    end
end

local function AcceptInviteEntry(entry)
    if not CanAcceptInviteEntry(entry) then
        return false
    end

    local accepted = pcall(_G.BNAcceptFriendInvite, entry.inviteID) and true or false
    if accepted then
        RefreshAfterInviteAction(entry)
    end
    return accepted
end

local function DeclineInviteEntry(entry)
    if not CanDeclineInviteEntry(entry) then
        return false
    end

    local declined = pcall(_G.BNDeclineFriendInvite, entry.inviteID) and true or false
    if declined then
        RefreshAfterInviteAction(entry)
    end
    return declined
end

local function CanInviteEntry(entry)
    return entry and entry.kind ~= "system" and entry.inviteable == true
end

local function CanPrimaryActionEntry(entry)
    return CanAcceptInviteEntry(entry) or CanInviteEntry(entry)
end

local function GetPrimaryActionLabel(entry)
    if CanAcceptInviteEntry(entry) then
        return LText("Accept")
    end
    return "+"
end

local function GetPrimaryActionWidth(entry)
    if CanAcceptInviteEntry(entry) then
        return 52
    end
    return 24
end

local function PerformPrimaryAction(entry)
    if CanAcceptInviteEntry(entry) then
        return AcceptInviteEntry(entry)
    end
    if CanInviteEntry(entry) then
        InviteEntry(entry)
        return true
    end
    return false
end

local function CanRemoveEntry(entry)
    if not entry or entry.kind == "system" or entry.kind == "invite" then
        return false
    end

    if entry.kind == "bnet" then
        return BNRemoveFriend ~= nil and entry.bnetAccountID ~= nil
    end

    return (C_FriendList and (C_FriendList.RemoveFriend or C_FriendList.RemoveFriendByIndex))
        and (entry.fullName ~= nil or entry.inviteName ~= nil or entry.friendIndex ~= nil)
end

local function CanBlockEntry(entry)
    if not entry or entry.kind == "system" or entry.kind == "invite" then
        return false
    end

    if entry.kind == "bnet" and BNSetBlocked and entry.bnetAccountID then
        return true
    end

    local ignoreName = GetEntryIgnoreName(entry)
    return ignoreName ~= nil and ((C_FriendList and C_FriendList.AddIgnore) or AddIgnore)
end

local function GetFactionIcon(entry)
    local factionName = entry and entry.factionName
    if type(factionName) ~= "string" then
        return nil
    end
    factionName = strlower(factionName)
    if strfind(factionName, "horde", 1, true) then
        return HORDE_ICON
    end
    if strfind(factionName, "alliance", 1, true) then
        return ALLIANCE_ICON
    end
    return nil
end

local function GetBNetDisplayText()
    -- Midnight 12.x: BNGetInfo devuelve (presenceID, battleTag, ...)
    if _G.BNGetInfo then
        local ok, presenceID, battleTag = pcall(_G.BNGetInfo)
        if ok and type(battleTag) == "string" and battleTag ~= "" then
            return battleTag
        end
        -- Fallback: iterar todos los retornos buscando el BattleTag
        if ok then
            local results = { presenceID, battleTag }
            -- BNGetInfo puede devolver hasta 7 valores
            for _, value in ipairs(results) do
                if type(value) == "string" and strfind(value, "#", 1, true) then
                    return value
                end
            end
        end
    end

    -- Intento alternativo: C_BattleNet
    if C_BattleNet and C_BattleNet.GetMyAccountInfo then
        local ok, info = pcall(C_BattleNet.GetMyAccountInfo)
        if ok and info then
            if info.battleTag and info.battleTag ~= "" then
                return info.battleTag
            end
        end
    end

    -- Último recurso: escanear el BattlenetFrame por FontStrings con "#"
    local friendsFrame = GetFriendsFrame()
    local bnetFrame = friendsFrame and friendsFrame.BattlenetFrame
    if bnetFrame then
        for _, region in ipairs({ bnetFrame:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                local text = region:GetText()
                if text and text ~= "" and strfind(text, "#", 1, true) then
                    return text
                end
            end
        end
    end

    return LText("Battle.net")
end

local function GetActiveView()
    return runtime.selectedView or "contacts"
end

local function FindNavDefinition(key)
    for _, definition in ipairs(NAV_ORDER) do
        if definition.key == key then
            return definition
        end
    end
end

local function PrepareExternalView(definition)
    if not definition then
        return
    end
end

local function HideExternalFrameBackdrop(frame)
    if not frame or frame._eflBackdropStripped then
        return
    end

    frame._eflBackdropStripped = true

    local bgKeys = { "Bg", "BG", "bg", "InsetBg", "NineSlice", "TopTileStreaks", "Inset", "Background" }
    for _, key in ipairs(bgKeys) do
        local child = frame[key]
        if child and child.Hide then
            child._eflWasShown = child:IsShown()
            child:Hide()
        end
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local width = region.GetWidth and region:GetWidth() or 0
            local height = region.GetHeight and region:GetHeight() or 0
            local layer = region.GetDrawLayer and region:GetDrawLayer() or nil
            if (layer == "BACKGROUND" or layer == "BORDER" or layer == "ARTWORK") and (width > 120 or height > 120) then
                region._eflWasShown = region:IsShown()
                region:Hide()
            end
        end
    end
end

local function RestoreExternalFrameBackdrop(frame)
    if not (frame and frame._eflBackdropStripped) then
        return
    end

    frame._eflBackdropStripped = nil

    local bgKeys = { "Bg", "BG", "bg", "InsetBg", "NineSlice", "TopTileStreaks", "Inset", "Background" }
    for _, key in ipairs(bgKeys) do
        local child = frame[key]
        if child and child._eflWasShown then
            child:Show()
            child._eflWasShown = nil
        end
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") and region._eflWasShown then
            region:Show()
            region._eflWasShown = nil
        end
    end
end

local function LayoutQuickJoinMirror(frame)
    if not frame then return end

    local seen = {}
    local function Adjust(target, left, top, right, bottom)
        if not (target and not seen[target]) then return end
        seen[target] = true
        if target.ClearAllPoints and target.SetPoint then
            target:ClearAllPoints()
            target:SetPoint("TOPLEFT", frame, "TOPLEFT", left or 2, top or -2)
            target:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right or -18, bottom or 2)
        end
    end

    Adjust(frame.ScrollBox, 2, -2, -18, 2)
    Adjust(frame.ScrollFrame, 2, -2, -18, 2)

    for _, child in ipairs({ frame:GetChildren() }) do
        local objectType = child.GetObjectType and child:GetObjectType() or nil
        local name = child.GetName and child:GetName() or ""
        if objectType == "ScrollFrame" then
            Adjust(child, 2, -2, -18, 2)
        elseif type(name) == "string" and (strfind(name, "Scroll", 1, true) or strfind(name, "List", 1, true)) then
            Adjust(child, 2, -2, -18, 2)
        end
    end

    -- Reubicar el botón 'Request to Join' si existe
    local joinButton = frame.JoinQueueButton or _G.QuickJoinFrame and _G.QuickJoinFrame.JoinQueueButton
    local host = EnhancedFriendList and EnhancedFriendList.externalHost
    if joinButton and host then
        RememberMovedFrame("quickjoin:joinButton", joinButton)
        joinButton:ClearAllPoints()
        joinButton:SetParent(host)
        joinButton:SetFrameStrata(host:GetFrameStrata())
        joinButton:SetFrameLevel(host:GetFrameLevel() + 20)
        joinButton:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -12, 8)
        joinButton:Show()
    end
end

local function RestoreQuickJoinJoinButton()
    local joinButton = (_G.QuickJoinFrame and _G.QuickJoinFrame.JoinQueueButton) or nil
    local state = runtime.original.movedFrames["quickjoin:joinButton"]
    if not (joinButton and state) then
        return
    end

    RestorePoints(joinButton, state)
    runtime.original.movedFrames["quickjoin:joinButton"] = nil

    local quickJoinFrame = _G.QuickJoinFrame
    if quickJoinFrame and quickJoinFrame:IsShown() then
        joinButton:Show()
    else
        joinButton:Hide()
    end
end

local function LayoutQuickJoinRoleSelectionMirror(frame, host)
    if not (frame and host) then
        return
    end

    if frame.ClearAllPoints and frame.SetPoint then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 34)
    end
end

local function EnsureWhoMirrorMask(frame)
    if not frame then
        return
    end

    if not frame._eflWhoMask then
        local mask = frame:CreateTexture(nil, "ARTWORK", nil, -7)
        mask:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -20)
        mask:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        mask:SetColorTexture(0.015, 0.015, 0.02, 0.96)
        frame._eflWhoMask = mask
    end

    if frame._eflWhoMask.Show then
        frame._eflWhoMask:Show()
    end
end

local function UpdateExternalMirrorMasks(activeKey, frame)
    local targets = { _G.WhoFrame, _G.RaidFrame, _G.QuickJoinFrame, _G.QuickJoinRoleSelectionFrame }
    for _, target in ipairs(targets) do
        if target and target._eflWhoMask then
            if activeKey == "who" and target == frame then
                target._eflWhoMask:Show()
            else
                target._eflWhoMask:Hide()
            end
        end
    end
end

local function InvokeOriginalTab(definition)
    if not definition then
        return
    end

    runtime.selectedView = definition.key

    -- Use Blizzard's original tab logic unchanged, then just hide the stock tabs again.
    local tab = _G[definition.tab]
    if tab then
        tab:Show()
        local onClick = tab:GetScript("OnClick")
        if onClick then
            onClick(tab)
        end
    end

    PrepareExternalView(definition)

    -- Always re-hide ALL Blizzard tabs (Blizzard's tab system re-shows them on click)
    for i = 1, 4 do
        local t = _G["FriendsFrameTab" .. i]
        if t then t:Hide() end
    end

    SetFrameAlphaState(_G.FriendsListFrame, definition.key ~= "contacts")
end

local CreateSimpleButton -- forward declaration
local SendWhisperToEntry -- forward declaration
local SendBattleNetWhisperToEntry -- forward declaration
local CanWhisperEntry -- forward declaration
local CanWhisperWoWEntry -- forward declaration
local CanWhisperBNetEntry -- forward declaration
local CanEditNoteEntry -- forward declaration
local CanCopyRaiderIOLink -- forward declaration

local function OpenBroadcastEditor()
    if runtime.broadcastEditor and runtime.broadcastEditor:IsShown() then
        runtime.broadcastEditor:Hide()
        return
    end

    if not runtime.broadcastEditor then
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetSize(320, 90)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(600)
        ApplySectionStyle(popup, 0.98, 0.95)
        popup:EnableMouse(true)
        popup:Hide()

        local title = CreateLabel(popup, 10, TextColor())
        title:SetPoint("TOPLEFT", 10, -8)
        title:SetText(LText("Broadcast Message"))

        local inputBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        inputBg:SetPoint("TOPLEFT", 8, -26)
        inputBg:SetPoint("TOPRIGHT", -8, -26)
        inputBg:SetHeight(28)
        ApplyInsetStyle(inputBg, 1)

        local input = CreateFrame("EditBox", nil, inputBg)
        input:SetPoint("LEFT", 6, 0)
        input:SetPoint("RIGHT", -6, 0)
        input:SetHeight(22)
        input:SetFont(ResolveFont(), 10, "")
        input:SetTextColor(TextColor())
        input:SetAutoFocus(false)
        input:SetMaxLetters(127)

        local mr, mg, mb = MutedColor()
        local send = CreateSimpleButton(popup, 90, 24, LText("Send"), "footer")
        send:SetPoint("BOTTOMRIGHT", -8, 8)
        send:SetScript("OnClick", function()
            local text = input:GetText() or ""
            if BNSetCustomMessage then
                BNSetCustomMessage(text)
            elseif C_BattleNet and C_BattleNet.SetCustomMessage then
                C_BattleNet.SetCustomMessage(text)
            end
            popup:Hide()
        end)

        local clear = CreateSimpleButton(popup, 90, 24, LText("Clear"), "default")
        clear:SetPoint("RIGHT", send, "LEFT", -6, 0)
        clear:SetScript("OnClick", function()
            if BNSetCustomMessage then
                BNSetCustomMessage("")
            elseif C_BattleNet and C_BattleNet.SetCustomMessage then
                C_BattleNet.SetCustomMessage("")
            end
            input:SetText("")
            popup:Hide()
        end)

        input:SetScript("OnEnterPressed", function(self)
            send:Click()
        end)
        input:SetScript("OnEscapePressed", function(self)
            popup:Hide()
        end)

        popup._input = input
        runtime.broadcastEditor = popup
    end

    local popup = runtime.broadcastEditor
    -- Pre-fill with current broadcast
    local currentBroadcast = ""
    if BNGetInfo then
        local _, _, _, broadcast = BNGetInfo()
        currentBroadcast = broadcast or ""
    end
    popup._input:SetText(currentBroadcast)

    popup:ClearAllPoints()
    local anchor = EnhancedFriendList.frame or UIParent
    popup:SetPoint("TOP", anchor, "TOP", 0, -80)
    popup:Show()
    popup._input:SetFocus()
end

local function OpenNewGroupEditor()
    if runtime.groupEditor and runtime.groupEditor:IsShown() then
        runtime.groupEditor:Hide()
        return
    end

    if not runtime.groupEditor then
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetSize(300, 90)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(600)
        ApplySectionStyle(popup, 0.98, 0.95)
        popup:EnableMouse(true)
        popup:Hide()

        local title = CreateLabel(popup, 10, TextColor())
        title:SetPoint("TOPLEFT", 10, -8)
        title:SetText(LText("New Group"))

        local inputBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        inputBg:SetPoint("TOPLEFT", 8, -26)
        inputBg:SetPoint("TOPRIGHT", -8, -26)
        inputBg:SetHeight(28)
        ApplyInsetStyle(inputBg, 1)

        local input = CreateFrame("EditBox", nil, inputBg)
        input:SetPoint("LEFT", 6, 0)
        input:SetPoint("RIGHT", -6, 0)
        input:SetHeight(22)
        input:SetFont(ResolveFont(), 10, "")
        input:SetTextColor(TextColor())
        input:SetAutoFocus(false)
        input:SetMaxLetters(32)

        local create = CreateSimpleButton(popup, 90, 24, LText("Create"), "footer")
        create:SetPoint("BOTTOMRIGHT", -8, 8)
        create:SetScript("OnClick", function()
            local text = (input:GetText() or ""):match("^%s*(.-)%s*$") or ""
            if text ~= "" then
                if AddFriendGroup(text) then
                    runtime.dataDirty = true
                    if EnhancedFriendList.RequestRefresh then
                        EnhancedFriendList:RequestRefresh()
                    end
                end
            end
            input:SetText("")
            popup:Hide()
        end)

        local cancel = CreateSimpleButton(popup, 90, 24, LText("Cancel"), "default")
        cancel:SetPoint("RIGHT", create, "LEFT", -6, 0)
        cancel:SetScript("OnClick", function()
            input:SetText("")
            popup:Hide()
        end)

        input:SetScript("OnEnterPressed", function()
            create:Click()
        end)
        input:SetScript("OnEscapePressed", function()
            popup:Hide()
        end)

        popup._input = input
        runtime.groupEditor = popup
    end

    local popup = runtime.groupEditor
    popup._input:SetText("")
    popup:ClearAllPoints()
    local anchor = EnhancedFriendList.frame or UIParent
    popup:SetPoint("TOP", anchor, "TOP", 0, -80)
    popup:Show()
    popup._input:SetFocus()
end

local function ConfirmDeleteGroup(groupName)
    if runtime.deleteGroupPopup and runtime.deleteGroupPopup:IsShown() then
        runtime.deleteGroupPopup:Hide()
    end

    if not runtime.deleteGroupPopup then
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetSize(320, 80)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(600)
        ApplySectionStyle(popup, 0.98, 0.95)
        popup:EnableMouse(true)
        popup:Hide()

        popup._label = CreateLabel(popup, 10, TextColor())
        popup._label:SetPoint("TOPLEFT", 10, -10)
        popup._label:SetPoint("TOPRIGHT", -10, -10)
        popup._label:SetWordWrap(true)

        local confirm = CreateSimpleButton(popup, 90, 24, LText("Delete"), "footer")
        confirm:SetPoint("BOTTOMRIGHT", -8, 8)
        confirm:SetScript("OnClick", function()
            if popup._groupName then
                RemoveFriendGroup(popup._groupName)
                runtime.dataDirty = true
                if EnhancedFriendList.RequestRefresh then
                    EnhancedFriendList:RequestRefresh()
                end
            end
            popup:Hide()
        end)

        local cancel = CreateSimpleButton(popup, 90, 24, LText("Cancel"), "default")
        cancel:SetPoint("RIGHT", confirm, "LEFT", -6, 0)
        cancel:SetScript("OnClick", function()
            popup:Hide()
        end)

        popup:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:Hide()
                self:SetPropagateKeyboardInput(true)
            else
                -- Capture non-ESC keys so typing/clicking in the popup cannot
                -- trigger world bindings (e.g. 1/2/3 abilities) while it is up.
                self:SetPropagateKeyboardInput(false)
            end
        end)
        -- Always release keyboard capture when the popup closes, regardless of
        -- whether it was closed via ESC, the confirm button or the cancel button.
        popup:HookScript("OnHide", function(self)
            self:SetPropagateKeyboardInput(true)
        end)

        runtime.deleteGroupPopup = popup
    end

    local popup = runtime.deleteGroupPopup
    popup._groupName = groupName
    popup._label:SetText(string.format(LText("Delete group \"%s\"?"), groupName))
    popup:ClearAllPoints()
    local anchor = EnhancedFriendList.frame or UIParent
    popup:SetPoint("TOP", anchor, "TOP", 0, -80)
    popup:Show()
end

local function OpenTextCopyPopup(titleText, value)
    if type(value) ~= "string" or value == "" then
        return
    end

    if runtime.textCopyPopup and runtime.textCopyPopup:IsShown() then
        runtime.textCopyPopup:Hide()
    end

    if not runtime.textCopyPopup then
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetSize(430, 96)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(610)
        ApplySectionStyle(popup, 0.98, 0.95)
        popup:EnableMouse(true)
        popup:Hide()

        popup._title = CreateLabel(popup, 10, TextColor())
        popup._title:SetPoint("TOPLEFT", 10, -8)

        local inputBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        inputBg:SetPoint("TOPLEFT", 8, -26)
        inputBg:SetPoint("TOPRIGHT", -8, -26)
        inputBg:SetHeight(28)
        ApplyInsetStyle(inputBg, 1)

        local input = CreateFrame("EditBox", nil, inputBg)
        input:SetPoint("LEFT", 6, 0)
        input:SetPoint("RIGHT", -6, 0)
        input:SetHeight(22)
        input:SetFont(ResolveFont(), 10, "")
        input:SetTextColor(TextColor())
        input:SetAutoFocus(false)
        input:SetScript("OnEscapePressed", function()
            popup:Hide()
        end)
        input:SetScript("OnEnterPressed", function(self)
            self:HighlightText()
        end)

        local close = CreateSimpleButton(popup, 90, 24, LText("Close"), "footer")
        close:SetPoint("BOTTOMRIGHT", -8, 8)
        close:SetScript("OnClick", function()
            popup:Hide()
        end)

        popup._input = input
        runtime.textCopyPopup = popup
    end

    local popup = runtime.textCopyPopup
    popup._title:SetText(titleText or LText("Copy Raider.IO URL"))
    popup._input:SetText(value)
    popup:ClearAllPoints()
    local anchor = EnhancedFriendList.frame or UIParent
    popup:SetPoint("TOP", anchor, "TOP", 0, -80)
    popup:Show()
    popup._input:SetFocus()
    popup._input:HighlightText()
end

local function OpenFriendActionConfirm(entry, titleText, confirmLabel, callback)
    if not entry or type(callback) ~= "function" then
        return
    end

    if runtime.friendActionConfirm and runtime.friendActionConfirm:IsShown() then
        runtime.friendActionConfirm:Hide()
    end

    if not runtime.friendActionConfirm then
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetSize(340, 84)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(605)
        ApplySectionStyle(popup, 0.98, 0.95)
        popup:EnableMouse(true)
        popup:Hide()

        popup._label = CreateLabel(popup, 10, TextColor())
        popup._label:SetPoint("TOPLEFT", 10, -10)
        popup._label:SetPoint("TOPRIGHT", -10, -10)
        popup._label:SetWordWrap(true)

        local confirm = CreateSimpleButton(popup, 90, 24, LText("Delete"), "footer")
        confirm:SetPoint("BOTTOMRIGHT", -8, 8)
        confirm:SetScript("OnClick", function()
            if popup._callback then
                popup._callback()
            end
            popup:Hide()
        end)

        local cancel = CreateSimpleButton(popup, 90, 24, LText("Cancel"), "default")
        cancel:SetPoint("RIGHT", confirm, "LEFT", -6, 0)
        cancel:SetScript("OnClick", function()
            popup:Hide()
        end)

        popup._confirm = confirm
        runtime.friendActionConfirm = popup
    end

    local popup = runtime.friendActionConfirm
    popup._callback = callback
    popup._label:SetText(titleText)
    popup._confirm.label:SetText(confirmLabel or LText("Delete"))
    RefreshButtonStyle(popup._confirm)
    popup:ClearAllPoints()
    local anchor = EnhancedFriendList.frame or UIParent
    popup:SetPoint("TOP", anchor, "TOP", 0, -80)
    popup:Show()
end

local function SaveFriendNote(entry, noteText)
    if not CanEditNoteEntry(entry) then
        return false
    end

    noteText = type(noteText) == "string" and noteText or ""
    local saved = false
    SetStoredFriendNote(entry.id, noteText)
    entry.noteText = NormalizeFriendNote(noteText)

    if entry.kind == "bnet" then
        if BNSetFriendNote and entry.bnetAccountID then
            saved = pcall(BNSetFriendNote, entry.bnetAccountID, noteText) and true or false
        elseif C_BattleNet and C_BattleNet.SetFriendNote and entry.bnetAccountID then
            saved = pcall(C_BattleNet.SetFriendNote, entry.bnetAccountID, noteText) and true or false
        end
    else
        if C_FriendList and C_FriendList.SetFriendNotes and (entry.fullName or entry.inviteName) then
            saved = pcall(C_FriendList.SetFriendNotes, entry.fullName or entry.inviteName, noteText) and true or false
        elseif C_FriendList and C_FriendList.SetFriendNotesByIndex and entry.friendIndex then
            saved = pcall(C_FriendList.SetFriendNotesByIndex, entry.friendIndex, noteText) and true or false
        end
    end

    if saved or entry.noteText ~= nil or noteText == "" then
        runtime.dataDirty = true
        if EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh(true)
        end
    end

    return saved
end

local function OpenFriendNoteEditor(entry)
    if not CanEditNoteEntry(entry) then
        return
    end

    if runtime.friendNoteEditor and runtime.friendNoteEditor:IsShown() then
        runtime.friendNoteEditor:Hide()
    end

    if not runtime.friendNoteEditor then
        local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        popup:SetSize(360, 92)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetFrameLevel(610)
        ApplySectionStyle(popup, 0.98, 0.95)
        popup:EnableMouse(true)
        popup:Hide()

        popup._title = CreateLabel(popup, 10, TextColor())
        popup._title:SetPoint("TOPLEFT", 10, -8)
        popup._title:SetText(LText("Friend Note"))

        local inputBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
        inputBg:SetPoint("TOPLEFT", 8, -26)
        inputBg:SetPoint("TOPRIGHT", -8, -26)
        inputBg:SetHeight(28)
        ApplyInsetStyle(inputBg, 1)

        local input = CreateFrame("EditBox", nil, inputBg)
        input:SetPoint("LEFT", 6, 0)
        input:SetPoint("RIGHT", -6, 0)
        input:SetHeight(22)
        input:SetFont(ResolveFont(), 10, "")
        input:SetTextColor(TextColor())
        input:SetAutoFocus(false)
        input:SetMaxLetters(127)

        local save = CreateSimpleButton(popup, 90, 24, LText("Save"), "footer")
        save:SetPoint("BOTTOMRIGHT", -8, 8)
        save:SetScript("OnClick", function()
            local targetEntry = popup._entry
            if not targetEntry then
                popup:Hide()
                return
            end

            SaveFriendNote(targetEntry, input:GetText() or "")
            popup:Hide()
        end)

        local cancel = CreateSimpleButton(popup, 90, 24, LText("Cancel"), "default")
        cancel:SetPoint("RIGHT", save, "LEFT", -6, 0)
        cancel:SetScript("OnClick", function()
            popup:Hide()
        end)

        input:SetScript("OnEnterPressed", function()
            save:Click()
        end)
        input:SetScript("OnEscapePressed", function()
            popup:Hide()
        end)

        popup._input = input
        runtime.friendNoteEditor = popup
    end

    local popup = runtime.friendNoteEditor
    popup._entry = entry
    popup._title:SetText(string.format("%s: %s", LText("Friend Note"), GetEntryDisplayName(entry)))
    popup._input:SetText(entry.noteText or "")
    popup:ClearAllPoints()
    local anchor = EnhancedFriendList.frame or UIParent
    popup:SetPoint("TOP", anchor, "TOP", 0, -80)
    popup:Show()
    popup._input:SetFocus()
    popup._input:HighlightText()
end

local function RemoveFriendEntry(entry)
    if not CanRemoveEntry(entry) then
        return false
    end

    local removed = false
    if entry.kind == "bnet" then
        removed = pcall(BNRemoveFriend, entry.bnetAccountID) and true or false
    else
        if C_FriendList and C_FriendList.RemoveFriend and (entry.fullName or entry.inviteName) then
            removed = pcall(C_FriendList.RemoveFriend, entry.fullName or entry.inviteName) and true or false
        elseif C_FriendList and C_FriendList.RemoveFriendByIndex and entry.friendIndex then
            removed = pcall(C_FriendList.RemoveFriendByIndex, entry.friendIndex) and true or false
        end
    end

    if removed then
        AssignEntryToGroup(entry, nil)
        SetStoredFriendNote(entry.id, nil)
        runtime.selectedEntry = nil
        runtime.dataDirty = true
        if EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh(true)
        end
    end

    return removed
end

local function BlockEntry(entry)
    if not CanBlockEntry(entry) then
        return false
    end

    local blocked = false
    if entry.kind == "bnet" and BNSetBlocked and entry.bnetAccountID then
        blocked = pcall(BNSetBlocked, entry.bnetAccountID, true) and true or false
    end

    if not blocked then
        local ignoreName = GetEntryIgnoreName(entry)
        if ignoreName and C_FriendList and C_FriendList.AddIgnore then
            blocked = pcall(C_FriendList.AddIgnore, ignoreName) and true or false
        elseif ignoreName and AddIgnore then
            blocked = pcall(AddIgnore, ignoreName) and true or false
        end
    end

    if blocked then
        runtime.dataDirty = true
        if EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh(true)
        end
    end

    return blocked
end

local function RefreshGroupDropVisuals()
    if not EnhancedFriendList.groups then
        return
    end

    for _, group in ipairs(EnhancedFriendList.groups) do
        if group and group.header and group.header.bg then
            local isDropTarget = runtime.dragTargetGroup and group._customGroupName == runtime.dragTargetGroup
            group.header.bg:SetVertexColor(1, 1, 1, isDropTarget and 0.26 or 0.16)
        end
    end
end

local function SetGroupDropTarget(groupName)
    runtime.dragTargetGroup = groupName
    RefreshGroupDropVisuals()
end

local function ClearFriendDragState()
    if runtime.dragSourceRow and runtime.dragSourceRow.SetAlpha then
        runtime.dragSourceRow:SetAlpha(1)
    end
    runtime.dragEntry = nil
    runtime.dragSourceRow = nil
    runtime.dragTargetGroup = nil
    RefreshGroupDropVisuals()
end

local function HandleFriendRowDrop()
    if not runtime.dragEntry then
        ClearFriendDragState()
        return
    end

    local targetGroup = runtime.dragTargetGroup
    if not targetGroup and EnhancedFriendList.groups then
        for _, group in ipairs(EnhancedFriendList.groups) do
            if group and group._customGroupName and ((group.header and group.header:IsMouseOver()) or group:IsMouseOver()) then
                targetGroup = group._customGroupName
                break
            end
        end
    end

    local sourceGroup = GetEntryAssignedGroup(runtime.dragEntry)
    if targetGroup and targetGroup ~= sourceGroup then
        AssignEntryToGroup(runtime.dragEntry, targetGroup)
        runtime.dataDirty = true
        if EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh(true)
        end
    end

    ClearFriendDragState()
end

local function ClearMenuChildren(menu)
    if not menu then
        return
    end

    for _, child in ipairs({ menu:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
end

local function HideGroupMoveMenu()
    if runtime.groupMoveMenu and runtime.groupMoveMenu:IsShown() then
        runtime.groupMoveMenu:Hide()
    end
end

local function SetHorizontalArrowDirection(texture, direction)
    if not texture then
        return
    end

    if direction == "left" then
        texture:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
    else
        texture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    end
end

local function IsGroupContextMenuHovered(menu)
    if menu and menu.IsMouseOver and menu:IsMouseOver() then
        return true
    end

    return runtime.groupMoveMenu
        and runtime.groupMoveMenu:IsShown()
        and runtime.groupMoveMenu.IsMouseOver
        and runtime.groupMoveMenu:IsMouseOver()
end

local function EnsureGroupContextMenu(key, frameLevel)
    if runtime[key] then
        return runtime[key]
    end

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(frameLevel or 550)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:Hide()
    menu:SetScript("OnShow", function(self)
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    menu:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        if self == runtime.groupAssignMenu then
            HideGroupMoveMenu()
        end
    end)
    menu:SetScript("OnEvent", function(self, event)
        if event == "GLOBAL_MOUSE_DOWN" and not IsGroupContextMenuHovered(self) then
            self:Hide()
        end
    end)

    runtime[key] = menu
    return menu
end

local function OpenGroupMoveMenu(entry, anchorButton)
    if not entry then
        return
    end

    local groups = GetFriendGroups()
    local currentGroup = GetEntryAssignedGroup(entry)
    local items = {
        {
            label = LText("No Group"),
            selected = not currentGroup,
            callback = function()
                AssignEntryToGroup(entry, nil)
                runtime.dataDirty = true
                HideGroupMoveMenu()
                if runtime.groupAssignMenu then
                    runtime.groupAssignMenu:Hide()
                end
                if EnhancedFriendList.RequestRefresh then
                    EnhancedFriendList:RequestRefresh()
                end
            end,
        },
    }

    for _, gName in ipairs(groups) do
        items[#items + 1] = {
            label = gName,
            selected = (currentGroup == gName),
            callback = function()
                AssignEntryToGroup(entry, gName)
                runtime.dataDirty = true
                HideGroupMoveMenu()
                if runtime.groupAssignMenu then
                    runtime.groupAssignMenu:Hide()
                end
                if EnhancedFriendList.RequestRefresh then
                    EnhancedFriendList:RequestRefresh()
                end
            end,
        }
    end

    local menu = EnsureGroupContextMenu("groupMoveMenu", 555)
    ClearMenuChildren(menu)
    ApplySectionStyle(menu, 0.98, 0.95)
    menu:SetSize(208, 6 + (#items * 28) + 6)
    menu._entryID = entry.id

    for index, itemData in ipairs(items) do
        local item = CreateSimpleButton(menu, 196, 26, itemData.label, "menu")
        item:SetPoint("TOPLEFT", 6, -(6 + ((index - 1) * 28)))
        item._eflSelected = itemData.selected and true or false
        RefreshButtonStyle(item)
        item:SetScript("OnClick", function()
            if itemData.callback then
                itemData.callback()
            end
        end)
    end

    menu:ClearAllPoints()
    if anchorButton then
        local menuWidth = menu:GetWidth() or 208
        local rightEdge = UIParent and UIParent.GetRight and UIParent:GetRight() or nil
        local leftEdge = UIParent and UIParent.GetLeft and UIParent:GetLeft() or nil
        local anchorLeft = anchorButton.GetLeft and anchorButton:GetLeft() or nil
        local anchorRight = anchorButton.GetRight and anchorButton:GetRight() or nil
        local openDirection = "right"

        if rightEdge and anchorRight and (anchorRight + 6 + menuWidth) > rightEdge and leftEdge and anchorLeft then
            openDirection = "left"
        end

        if openDirection == "left" then
            menu:SetPoint("TOPRIGHT", anchorButton, "TOPLEFT", -6, 0)
        else
            menu:SetPoint("TOPLEFT", anchorButton, "TOPRIGHT", 6, 0)
        end

        if anchorButton.arrow then
            SetHorizontalArrowDirection(anchorButton.arrow, openDirection)
        end
    else
        local anchor = EnhancedFriendList.frame or UIParent
        menu:SetPoint("TOP", anchor, "TOP", 120, -100)
    end
    menu:Show()
end

local function OpenGroupAssignMenu(entry, anchorFrame)
    if not entry or entry.kind == "system" then return end
    if runtime.groupAssignMenu and runtime.groupAssignMenu:IsShown() then
        if runtime.groupAssignMenu._entryID == entry.id then
            runtime.groupAssignMenu:Hide()
            return
        end
        runtime.groupAssignMenu:Hide()
    end

    local items = {}
    local displayName = GetEntryDisplayName(entry)
    local raiderIOLink = GetEntryRaiderIOLink(entry)

    if IsPendingInviteEntry(entry) then
        if CanAcceptInviteEntry(entry) then
            items[#items + 1] = {
                label = LText("Accept"),
                callback = function()
                    AcceptInviteEntry(entry)
                end,
            }
        end

        if CanDeclineInviteEntry(entry) then
            items[#items + 1] = {
                label = LText("Decline"),
                callback = function()
                    OpenFriendActionConfirm(
                        entry,
                        string.format(LText("Decline friend request from \"%s\"?"), displayName),
                        LText("Decline"),
                        function()
                            DeclineInviteEntry(entry)
                        end
                    )
                end,
            }
        end
    else
        if CanWhisperWoWEntry(entry) then
            items[#items + 1] = {
                label = LText(entry.kind == "bnet" and "Character Whisper" or "Whisper"),
                callback = function()
                    SendWhisperToEntry(entry)
                end,
            }
        end

        if entry.kind == "bnet" and CanWhisperBNetEntry(entry) then
            items[#items + 1] = {
                label = LText("Battle.net Whisper"),
                callback = function()
                    SendBattleNetWhisperToEntry(entry)
                end,
            }
        end

        if CanInviteEntry(entry) then
            items[#items + 1] = {
                label = LText("Invite"),
                callback = function()
                    InviteEntry(entry)
                end,
            }
        end

        if CanEditNoteEntry(entry) then
            items[#items + 1] = {
                label = LText("Add Note"),
                callback = function()
                    OpenFriendNoteEditor(entry)
                end,
            }
            if entry.noteText and entry.noteText ~= "" then
                items[#items + 1] = {
                    label = LText("Remove Note"),
                    callback = function()
                        SaveFriendNote(entry, "")
                    end,
                }
            end
        end

        if raiderIOLink and CanCopyRaiderIOLink(entry) then
            items[#items + 1] = {
                label = LText("Copy Raider.IO URL"),
                callback = function()
                    OpenTextCopyPopup(LText("Copy Raider.IO URL"), raiderIOLink)
                end,
            }
        end

        if CanBlockEntry(entry) then
            items[#items + 1] = {
                label = LText("Block"),
                callback = function()
                    OpenFriendActionConfirm(
                        entry,
                        string.format(LText("Block \"%s\"?"), displayName),
                        LText("Block"),
                        function()
                            BlockEntry(entry)
                        end
                    )
                end,
            }
        end

        if CanRemoveEntry(entry) then
            items[#items + 1] = {
                label = LText("Remove Friend"),
                callback = function()
                    OpenFriendActionConfirm(
                        entry,
                        string.format(LText("Remove friend \"%s\"?"), displayName),
                        LText("Delete"),
                        function()
                            RemoveFriendEntry(entry)
                        end
                    )
                end,
            }
        end

        items[#items + 1] = {
            label = LText("Move to group"),
            hasSubmenu = true,
            submenuCallback = function(button)
                OpenGroupMoveMenu(entry, button)
            end,
        }
    end

    local itemCount = #items

    if runtime.groupMoveMenu and runtime.groupMoveMenu._entryID ~= entry.id then
        HideGroupMoveMenu()
    end

    local menu = EnsureGroupContextMenu("groupAssignMenu", 550)
    ClearMenuChildren(menu)

    ApplySectionStyle(menu, 0.98, 0.95)
    menu:SetSize(208, 6 + itemCount * 28 + 6)

    for index, itemData in ipairs(items) do
        local item = CreateSimpleButton(menu, 196, 26, itemData.label, "menu")
        item:SetPoint("TOPLEFT", 6, -(6 + ((index - 1) * 28)))
        item._eflSelected = itemData.selected and true or false
        RefreshButtonStyle(item)
        if itemData.hasSubmenu then
            item.arrow = item:CreateTexture(nil, "ARTWORK")
            item.arrow:SetSize(8, 8)
            item.arrow:SetPoint("RIGHT", -8, 0)
            item.arrow:SetTexture(ARROW_DOWN_ICON)
            SetHorizontalArrowDirection(item.arrow, "right")
            local rr, rg, rb = AccentColor()
            item.arrow:SetVertexColor(rr, rg, rb, 0.82)
            item:SetScript("OnClick", function(self)
                if itemData.submenuCallback then
                    itemData.submenuCallback(self)
                end
            end)
            if item.HookScript then
                item:HookScript("OnEnter", function(self)
                    if itemData.submenuCallback then
                        itemData.submenuCallback(self)
                    end
                end)
            end
        else
            if item.HookScript then
                item:HookScript("OnEnter", function()
                    HideGroupMoveMenu()
                end)
            end
            item:SetScript("OnClick", function()
                HideGroupMoveMenu()
                menu:Hide()
                if itemData.callback then
                    itemData.callback()
                end
            end)
        end
    end

    menu:ClearAllPoints()
    menu._entryID = entry.id
    if anchorFrame then
        local menuWidth = menu:GetWidth() or 208
        local rightEdge = UIParent and UIParent.GetRight and UIParent:GetRight() or nil
        local leftEdge = UIParent and UIParent.GetLeft and UIParent:GetLeft() or nil
        local anchorLeft = anchorFrame.GetLeft and anchorFrame:GetLeft() or nil
        local anchorRight = anchorFrame.GetRight and anchorFrame:GetRight() or nil
        local openDirection = "right"

        if rightEdge and anchorRight and (anchorRight + 6 + menuWidth) > rightEdge and leftEdge and anchorLeft then
            openDirection = "left"
        end

        if openDirection == "left" then
            menu:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -6, 0)
        else
            menu:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 6, 0)
        end
    else
        local anchor = EnhancedFriendList.frame or UIParent
        menu:SetPoint("TOP", anchor, "TOP", 0, -100)
    end
    menu:Show()
end

local function OpenIgnorePanel()
    local button = _G.FriendsFrameIgnorePlayerButton
    if button and button.Click then
        button:Click()
        return
    end

    if _G.IgnoreListFrame then
        if _G.IgnoreListFrame:IsShown() then
            _G.IgnoreListFrame:Hide()
        else
            _G.IgnoreListFrame:Show()
        end
    end
end

local function OpenRecruitAFriend()
    local raf = _G.RecruitAFriendFrame
    if raf then
        if raf:IsShown() then
            raf:Hide()
        else
            raf:Show()
        end
        return
    end

    local button = _G.FriendsFrameRecruitAFriendButton
    if button and button.Click then
        button:Click()
        return
    end

    if _G.RecruitAFriendRecruitmentFrame then
        if _G.RecruitAFriendRecruitmentFrame:IsShown() then
            _G.RecruitAFriendRecruitmentFrame:Hide()
        else
            _G.RecruitAFriendRecruitmentFrame:Show()
        end
    end
end

local function GetPrimaryChatEditBox()
    return _G.ChatFrame1EditBox or (_G.ChatFrame1 and _G.ChatFrame1.editBox) or nil
end

local function IsChatMutationLocked()
    if _G.InCombatLockdown and _G.InCombatLockdown() then
        return true
    end
    return _G.C_ChatInfo
        and _G.C_ChatInfo.InChatMessagingLockdown
        and _G.C_ChatInfo.InChatMessagingLockdown()
        or false
end

local function PrimeWhisperEditBox(editBox, chatType, tellTarget, bnetAccountID)
    if not editBox
        or IsChatMutationLocked()
        or type(_G.issecretvalue) == "function"
        or type(_G.hasanysecretvalues) == "function"
        or type(_G.canaccessvalue) == "function"
        or type(_G.canaccessallvalues) == "function" then
        return false
    end

    if editBox.IsShown and not editBox:IsShown() and _G.ChatEdit_ActivateChat then
        pcall(_G.ChatEdit_ActivateChat, editBox)
    end

    if editBox.SetAttribute then
        pcall(editBox.SetAttribute, editBox, "chatType", chatType)
        pcall(editBox.SetAttribute, editBox, "tellTarget", tellTarget)
        pcall(editBox.SetAttribute, editBox, "bnetAccountID", bnetAccountID)
    end

    editBox.chatType = chatType
    editBox.tellTarget = tellTarget
    editBox.bnetAccountID = bnetAccountID

    if ChatEdit_UpdateHeader then
        pcall(ChatEdit_UpdateHeader, editBox)
    end

    if editBox.GetText and editBox.SetText then
        local currentText = editBox:GetText() or ""
        if currentText:match("^%s*/") then
            editBox:SetText("")
        end
    end

    if editBox.SetFocus then
        editBox:SetFocus()
    end

    return true
end

SendBattleNetWhisperToEntry = function(entry)
    if not entry then
        return false
    end

    if entry.kind ~= "bnet" then
        return false
    end

    local bnetAccountID = tonumber(entry.bnetAccountID)
    local target = ResolveBNetWhisperDisplayTarget(entry)
    local chatMod = KT and KT.GetModule and KT:GetModule("Chat", true) or nil
    if chatMod and chatMod.OpenDirectWhisperTarget and bnetAccountID then
        local ok, opened = pcall(chatMod.OpenDirectWhisperTarget, chatMod, target, bnetAccountID)
        if ok and opened then
            return true
        end
    end

    local editBox = GetPrimaryChatEditBox()
    if bnetAccountID and target and editBox then
        return PrimeWhisperEditBox(editBox, "BN_WHISPER", target, bnetAccountID)
    end

    return false
end

local function SendWoWWhisperToEntry(entry)
    local chatMod = KT and KT.GetModule and KT:GetModule("Chat", true) or nil
    if chatMod and chatMod.OpenDirectWhisperTarget then
        for _, tellTarget in ipairs(GetEntryWoWWhisperTargets(entry)) do
            local ok, opened = pcall(chatMod.OpenDirectWhisperTarget, chatMod, tellTarget, nil, true)
            if ok and opened then
                return true
            end
        end
    end

    local editBox = GetPrimaryChatEditBox()
    if editBox then
        for _, tellTarget in ipairs(GetEntryWoWWhisperTargets(entry)) do
            if PrimeWhisperEditBox(editBox, "WHISPER", tellTarget, nil) then
                return true
            end
        end
    end

    return false
end

SendWhisperToEntry = function(entry)
    if not entry then
        return false
    end

    if SendWoWWhisperToEntry(entry) then
        return true
    end

    return SendBattleNetWhisperToEntry(entry)
end

CanWhisperWoWEntry = function(entry)
    if not entry or entry.kind == "system" or not entry.online then
        return false
    end

    return GetPrimaryChatEditBox() ~= nil and #GetEntryWoWWhisperTargets(entry) > 0
end

CanWhisperBNetEntry = function(entry)
    if not entry or entry.kind ~= "bnet" or not entry.online then
        return false
    end

    return tonumber(entry.bnetAccountID) ~= nil
end

CanWhisperEntry = function(entry)
    return CanWhisperWoWEntry(entry) or CanWhisperBNetEntry(entry)
end

CanEditNoteEntry = function(entry)
    if not entry or entry.kind == "system" or entry.kind == "invite" then
        return false
    end

    if entry.kind == "bnet" then
        return (BNSetFriendNote ~= nil or (C_BattleNet and C_BattleNet.SetFriendNote))
            and entry.bnetAccountID ~= nil
    end

    return (C_FriendList and (C_FriendList.SetFriendNotes or C_FriendList.SetFriendNotesByIndex))
        and (entry.fullName ~= nil or entry.inviteName ~= nil or entry.friendIndex ~= nil)
end

CanCopyRaiderIOLink = function(entry)
    return GetEntryRaiderIOLink(entry) ~= nil
end

local function SortEntries(entries)
    tsort(entries, function(a, b)
        local leftPriority = a.sortPriority or 0
        local rightPriority = b.sortPriority or 0
        if leftPriority ~= rightPriority then
            return leftPriority < rightPriority
        end

        local leftName = strlower(a.sortName or a.name or "")
        local rightName = strlower(b.sortName or b.name or "")
        if leftName ~= rightName then
            return leftName < rightName
        end

        local leftKind = tostring(a.kind or "")
        local rightKind = tostring(b.kind or "")
        if leftKind ~= rightKind then
            return leftKind < rightKind
        end

        local leftID = tostring(a.id or a.fullName or a.name or "")
        local rightID = tostring(b.id or b.fullName or b.name or "")
        if leftID ~= rightID then
            return leftID < rightID
        end

        local leftIndex = tonumber(a.friendIndex or a.bnetAccountID or a.gameAccountID or 0) or 0
        local rightIndex = tonumber(b.friendIndex or b.bnetAccountID or b.gameAccountID or 0) or 0
        return leftIndex < rightIndex
    end)
end

local function BuildPendingInviteEntry(index)
    if not _G.BNGetFriendInviteInfo then
        return nil
    end

    local inviteID, accountName, isBattleTag = _G.BNGetFriendInviteInfo(index)
    if not inviteID then
        return nil
    end

    local displayName = accountName or (LText("Pending Friend Request") .. " " .. index)
    local subtitle = isBattleTag and LText("BattleTag Request") or LText("Battle.net Request")

    return {
        id = "invite:" .. tostring(inviteID),
        kind = "invite",
        inviteID = inviteID,
        fullName = accountName,
        name = displayName,
        accountName = accountName,
        battleTag = isBattleTag and accountName or nil,
        line1 = displayName,
        line2 = subtitle,
        detail = LText("Accept to add this contact, or use the menu to decline."),
        online = false,
        statusKey = "pending",
        sortName = displayName,
        sortPriority = 0,
    }
end

local function CreateWowEntry(index, info)
    local isOnline = info and info.connected
    local displayName = ShortName(info and info.name) or (info and info.name) or (LText("Friend") .. " " .. index)
    local entryID = "wow:" .. tostring(info and (info.guid or info.name) or index)
    local realmName = nil
    if info and info.name and strfind(info.name, "-", 1, true) then
        local _, parsedRealmName = strsplit("-", info.name, 2)
        realmName = parsedRealmName
    end
    local activityBits = {}
    local subtitleBits = {}
    local classFile = NormalizeClassFile(info and (info.className or info.classFileName))
    local noteText = ResolveFriendNote(entryID, info and info.notes, info and info.noteText, info and info.note)

    if info and info.className and info.className ~= "" then
        subtitleBits[#subtitleBits + 1] = info.className
    end
    if info and info.level and info.level > 0 then
        subtitleBits[#subtitleBits + 1] = tostring(info.level)
    end
    if info and info.area and info.area ~= "" then
        activityBits[#activityBits + 1] = info.area
    end

    local statusKey = isOnline and "online" or "offline"
    if info and info.afk then
        statusKey = "away"
    elseif info and info.dnd then
        statusKey = "busy"
    end

    return {
        id = entryID,
        kind = "wow",
        guid = info and info.guid or nil,
        fullName = info and info.name or displayName,
        inviteName = info and info.name or displayName,
        name = displayName,
        characterName = displayName,
        accountName = nil,
        realmName = realmName,
        noteText = noteText,
        friendIndex = index,
        line1 = displayName,
        line2 = (#subtitleBits > 0 and table.concat(subtitleBits, "  ")) or "",
        detail = (#activityBits > 0 and table.concat(activityBits, "  ")) or (isOnline and LText("Online") or LText("Offline")),
        online = isOnline and true or false,
        statusKey = statusKey,
        classFile = classFile,
        classColor = { GetClassColor(classFile) },
        hasClassIcon = classFile ~= nil,
        factionName = info and info.factionName or nil,
        inviteable = isOnline and true or false,
        sortName = displayName,
        sortPriority = isOnline and 1 or 4,
    }
end

local function BuildBNetEntry(index, accountInfo)
    local gameInfo = accountInfo and accountInfo.gameAccountInfo or nil
    local battleTag = accountInfo and accountInfo.battleTag or nil
    local accountName = accountInfo and (accountInfo.accountName or battleTag) or nil
    local characterName = gameInfo and gameInfo.characterName or nil
    local displayName = characterName or accountName or (LText("Battle.net Friend") .. " " .. index)
    local entryID = "bnet:" .. tostring(accountInfo and (accountInfo.bnetAccountID or battleTag) or index)

    local subtitleBits = {}
    local detailBits = {}
    local statusKey = "offline"
    local online = false
    local classFile = nil
    local noteText = ResolveFriendNote(entryID, accountInfo and accountInfo.noteText)

    if gameInfo and gameInfo.isOnline then
        online = true
        statusKey = "online"
        if accountInfo and accountInfo.isAFK then
            statusKey = "away"
        elseif accountInfo and accountInfo.isDND then
            statusKey = "busy"
        end
    end

    classFile = NormalizeClassFile(gameInfo and (gameInfo.className or gameInfo.classFileName))

    if accountName and characterName and accountName ~= characterName then
        subtitleBits[#subtitleBits + 1] = accountName
    end
    if gameInfo and gameInfo.realmDisplayName and gameInfo.realmDisplayName ~= "" then
        subtitleBits[#subtitleBits + 1] = gameInfo.realmDisplayName
    elseif gameInfo and gameInfo.realmName and gameInfo.realmName ~= "" then
        subtitleBits[#subtitleBits + 1] = gameInfo.realmName
    end
    local projectDisplay = EnhancedFriendList:GetWoWProjectDisplay(gameInfo)

    if accountInfo and accountInfo.broadcastText and accountInfo.broadcastText ~= "" then
        detailBits[#detailBits + 1] = accountInfo.broadcastText
    end
    if gameInfo and gameInfo.areaName and gameInfo.areaName ~= "" then
        detailBits[#detailBits + 1] = gameInfo.areaName
    end
    if not online and accountInfo and accountInfo.battleTag and accountInfo.battleTag ~= "" then
        detailBits[#detailBits + 1] = accountInfo.battleTag
    end

    return {
        id = entryID,
        kind = "bnet",
        bnetAccountID = accountInfo and accountInfo.bnetAccountID or nil,
        gameAccountID = gameInfo and gameInfo.gameAccountID or nil,
        wowProjectKey = projectDisplay and projectDisplay.key or nil,
        wowProjectLabel = projectDisplay and projectDisplay.label or nil,
        wowProjectTexture = projectDisplay and projectDisplay.texture or nil,
        wowProjectColor = projectDisplay and projectDisplay.color or nil,
        wowProjectCustomTexture = projectDisplay and projectDisplay.customTexture or nil,
        battleTag = battleTag,
        fullName = displayName,
        inviteName = gameInfo and gameInfo.characterName or nil,
        name = displayName,
        characterName = characterName,
        accountName = accountName,
        realmName = (gameInfo and gameInfo.realmDisplayName) or (gameInfo and gameInfo.realmName) or nil,
        noteText = noteText,
        line1 = displayName .. ((gameInfo and gameInfo.characterLevel and gameInfo.characterLevel > 0) and ("  " .. tostring(gameInfo.characterLevel)) or ""),
        line2 = (#subtitleBits > 0 and table.concat(subtitleBits, "  ")) or LText("Battle.net"),
        detail = (#detailBits > 0 and table.concat(detailBits, "  ")) or (online and LText("Online") or LText("Offline")),
        online = online,
        statusKey = statusKey,
        classFile = classFile,
        classColor = { GetClassColor(classFile) },
        hasClassIcon = classFile ~= nil and online and characterName ~= nil,
        factionName = gameInfo and gameInfo.factionName or nil,
        inviteable = online
            and gameInfo ~= nil
            and gameInfo.clientProgram == EnhancedFriendList.bnetClientWoW
            and gameInfo.wowProjectID ~= nil
            and _G.WOW_PROJECT_ID ~= nil
            and gameInfo.wowProjectID == _G.WOW_PROJECT_ID
            and true or false,
        sortName = displayName,
        sortPriority = online and 2 or 5,
    }
end

function EnhancedFriendList:BuildDataset()
    local sections = {}
    local pendingInvites = {}
    local battleNetOnline = {}
    local wowOnline = {}
    local offline = {}
    local recentAllies = {}
    local allEntries = {}

    if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
        for index = 1, BNGetNumFriends() do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
            if accountInfo then
                local entry = BuildBNetEntry(index, accountInfo)
                allEntries[#allEntries + 1] = entry
                if entry.online then
                    battleNetOnline[#battleNetOnline + 1] = entry
                    recentAllies[#recentAllies + 1] = entry
                else
                    offline[#offline + 1] = entry
                end
            end
        end
    end

    if _G.BNGetNumFriendInvites and _G.BNGetFriendInviteInfo then
        for index = 1, _G.BNGetNumFriendInvites() do
            local entry = BuildPendingInviteEntry(index)
            if entry then
                pendingInvites[#pendingInvites + 1] = entry
            end
        end
    end

    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        for index = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(index)
            if info then
                local entry = CreateWowEntry(index, info)
                allEntries[#allEntries + 1] = entry
                if entry.online then
                    wowOnline[#wowOnline + 1] = entry
                    recentAllies[#recentAllies + 1] = entry
                else
                    offline[#offline + 1] = entry
                end
            end
        end
    end

    local cleanupStats = SanitizeFriendGroupAssignments(allEntries)
    MaybeReportFriendGroupCleanup(cleanupStats)

    SortEntries(pendingInvites)
    SortEntries(battleNetOnline)
    SortEntries(wowOnline)
    SortEntries(offline)
    SortEntries(recentAllies)

    -- Custom groups: pull assigned entries into their own sections
    local customGroups = GetFriendGroups()
    local groupBuckets = {}
    if #customGroups > 0 then
        for _, gName in ipairs(customGroups) do
            groupBuckets[gName] = {}
        end

        local function FilterAssigned(list)
            local kept = {}
            for _, entry in ipairs(list) do
                local g = GetEntryAssignedGroup(entry)
                if g and groupBuckets[g] then
                    groupBuckets[g][#groupBuckets[g] + 1] = entry
                else
                    kept[#kept + 1] = entry
                end
            end
            return kept
        end

        battleNetOnline = FilterAssigned(battleNetOnline)
        wowOnline = FilterAssigned(wowOnline)
        offline = FilterAssigned(offline)

        for _, gName in ipairs(customGroups) do
            local bucket = groupBuckets[gName]
            SortEntries(bucket)
            sections[#sections + 1] = { title = gName, entries = bucket, isCustomGroup = true, groupName = gName }
        end
    end

    if #pendingInvites > 0 then
        sections[#sections + 1] = { title = LText("Pending Requests"), entries = pendingInvites }
    end
    if #battleNetOnline > 0 then
        sections[#sections + 1] = { title = LText("Battle.net Online"), entries = battleNetOnline }
    end
    if #wowOnline > 0 then
        sections[#sections + 1] = { title = LText("WoW Friends"), entries = wowOnline }
    end
    if #offline > 0 then
        sections[#sections + 1] = { title = LText("Offline"), entries = offline }
    end
    if #sections == 0 then
        sections[#sections + 1] = {
            title = LText("Friends"),
            entries = {
                {
                    id = "empty",
                    kind = "system",
                    line1 = LText("No friends to display yet."),
                    line2 = LText("Use Add Friend to populate this panel."),
                    detail = "",
                    online = false,
                    statusKey = "offline",
                    sortName = "zz",
                },
            },
        }
    end

    return {
        battleTag = GetBNetDisplayText(),
        pendingInvites = pendingInvites,
        recentAllies = recentAllies,
        sections = sections,
    }
end

function EnhancedFriendList:RegisterChatCommands()
    if runtime.chatCommandsRegistered then
        return
    end

    if not (KT and KT.RegisterChatCommand) then
        return
    end

    local function ResetGroupsCommand()
        local removed = ResetFriendGroupAssignments()
        runtime.cachedDataset = nil
        runtime.dataDirty = true

        if KT and KT.Print then
            KT:Print(string.format(
                "|cff00c8ffEnhanced Friend List|r: reset %d saved friend-group assignments. Group names were kept; you only need to reassign members.",
                removed
            ))
        end

        if EnhancedFriendList and EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh(true)
        end
    end

    KT:RegisterChatCommand("ktfixfriendgroups", ResetGroupsCommand)
    KT:RegisterChatCommand("ktfriendgroupsreset", ResetGroupsCommand)
    runtime.chatCommandsRegistered = true
end

CreateSimpleButton = function(parent, width, height, labelText, variant, secureAction)
    local template = secureAction and "BackdropTemplate,SecureActionButtonTemplate" or "BackdropTemplate"
    local button = CreateFrame("Button", nil, parent, template)
    button:SetSize(width, height)
    button:SetHitRectInsets(0, 0, 0, 0)
    button._eflVariant = variant or "default"
    ApplyButtonStyle(button, button._eflVariant)

    local tr, tg, tb = TextColor()
    local label = CreateLabel(button, 11, tr, tg, tb, 1, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(LText(labelText))
    button.label = label

    button:SetScript("OnEnter", function(self)
        self._eflHovered = true
        RefreshButtonStyle(self)
    end)
    button:SetScript("OnLeave", function(self)
        self._eflHovered = false
        self._eflPressed = false
        RefreshButtonStyle(self)
    end)
    button:SetScript("OnMouseDown", function(self)
        self._eflPressed = true
        RefreshButtonStyle(self)
    end)
    button:SetScript("OnMouseUp", function(self)
        self._eflPressed = false
        RefreshButtonStyle(self)
    end)

    return button
end

function EnhancedFriendList:CreateOptionMenu()
    if runtime.optionMenu then
        return runtime.optionMenu
    end

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(500)
    ApplySectionStyle(menu, 0.98, 0.95)
    menu:Hide()

    menu.items = {}
    local items = {
        { label = LText("Broadcast"), callback = OpenBroadcastEditor },
        { label = LText("Ignore List"), callback = OpenIgnorePanel },
        { label = LText("New Group"), callback = OpenNewGroupEditor },
    }

    menu:SetSize(160, 6 + (#items * 28) + 6)

    for index, itemData in ipairs(items) do
        local item = CreateSimpleButton(menu, 148, 26, itemData.label, "menu")
        item:SetPoint("TOPLEFT", 6, -(6 + ((index - 1) * 28)))
        item:SetScript("OnClick", function()
            menu:Hide()
            itemData.callback()
        end)
        menu.items[index] = item
    end

    runtime.optionMenu = menu
    return menu
end

function EnhancedFriendList:CreateNavButton(parent, definition)
    local nativeTab = definition.nativePassthrough and _G[definition.tab] or nil
    local button = CreateSimpleButton(parent, 0, 24, LText(definition.label), "nav", nativeTab ~= nil)
    button.definition = definition
    button.label:SetFont(ResolveFont(), 10, "OUTLINE")

    local function FinishNavigation()
        if definition.key == "contacts" then
            runtime.contactsSubView = nil
        end
        if EnhancedFriendList and EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh(definition.nativePassthrough and true or nil)
        end
    end

    if nativeTab then
        -- RaidGroup frames are protected. Forward the hardware click through a
        -- secure action instead of invoking Blizzard's tab handler from Lua.
        button:RegisterForClicks("LeftButtonUp")
        button:SetAttribute("type", "click")
        button:SetAttribute("clickbutton", nativeTab)
        button:SetScript("PostClick", function()
            runtime.selectedView = definition.key
            FinishNavigation()
        end)
    else
        button:SetScript("OnClick", function()
            InvokeOriginalTab(definition)
            FinishNavigation()
        end)
    end
    return button
end

function EnhancedFriendList:CreateInstallerPreviewCard(parent, accentColor, titleText)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(206, 292)

    local themeContext = CreatePreviewThemeContext(accentColor)
    local viewport = CreateFrame("Frame", nil, card)
    viewport:SetPoint("TOP", 0, 0)
    viewport:SetSize(206, 270)
    viewport:SetClipsChildren(true)

    local scale = math.min(viewport:GetWidth() / LAYOUT.windowWidth, viewport:GetHeight() / LAYOUT.windowHeight)

    local root = CreateFrame("Frame", nil, viewport)
    root:SetPoint("TOPLEFT", 0, 0)
    root:SetSize(LAYOUT.windowWidth, LAYOUT.windowHeight)
    root:SetScale(scale)
    root._eflThemeContext = themeContext
    ApplyShellStyle(root, 0.985, themeContext)

    root.shade = root:CreateTexture(nil, "BACKGROUND")
    root.shade:SetAllPoints()
    root.shade:SetColorTexture(0, 0, 0, 0.45)

    do
        local ar, ag, ab = AccentColor(nil, themeContext)

        root.bottomGlow = root:CreateTexture(nil, "BACKGROUND")
        root.bottomGlow:SetDrawLayer("BACKGROUND", 5)
        root.bottomGlow:SetPoint("BOTTOMLEFT", 1, 1)
        root.bottomGlow:SetPoint("BOTTOMRIGHT", -1, 1)
        root.bottomGlow:SetHeight(90)
        root.bottomGlow:SetTexture(WHITE8X8)
        ApplyTextureGradient(root.bottomGlow, "VERTICAL", ar, ag, ab, 0.07, ar, ag, ab, 0)

        root.topEdge = root:CreateTexture(nil, "ARTWORK")
        root.topEdge:SetDrawLayer("ARTWORK", 7)
        root.topEdge:SetPoint("TOPLEFT", 1, -1)
        root.topEdge:SetPoint("TOPRIGHT", -1, -1)
        root.topEdge:SetHeight(2)
        root.topEdge:SetTexture(WHITE8X8)
        ApplyTextureGradient(root.topEdge, "HORIZONTAL", ar, ag, ab, 0.85, ar, ag, ab, 0.08)

        root.leftEdge = root:CreateTexture(nil, "ARTWORK")
        root.leftEdge:SetDrawLayer("ARTWORK", 7)
        root.leftEdge:SetPoint("TOPLEFT", 1, -1)
        root.leftEdge:SetPoint("BOTTOMLEFT", 1, 1)
        root.leftEdge:SetWidth(1)
        root.leftEdge:SetTexture(WHITE8X8)
        ApplyTextureGradient(root.leftEdge, "VERTICAL", ar, ag, ab, 0.10, ar, ag, ab, 0.50)
    end

    local navBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    navBar:SetPoint("BOTTOMLEFT", 0, 0)
    navBar:SetPoint("BOTTOMRIGHT", 0, 0)
    navBar:SetHeight(LAYOUT.navHeight)
    navBar._eflThemeContext = themeContext
    ApplySectionStyle(navBar, 0.98, 0.9, themeContext)

    local mainPanel = CreateFrame("Frame", nil, root, "BackdropTemplate")
    mainPanel:SetPoint("TOPLEFT", 0, 0)
    mainPanel:SetPoint("TOPRIGHT", 0, 0)
    mainPanel:SetPoint("BOTTOMLEFT", navBar, "TOPLEFT", 0, LAYOUT.panelGap)
    mainPanel:SetPoint("BOTTOMRIGHT", navBar, "TOPRIGHT", 0, LAYOUT.panelGap)
    mainPanel._eflThemeContext = themeContext
    ApplyShellStyle(mainPanel, 0.965, themeContext)

    local header = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    header:SetPoint("TOPLEFT", LAYOUT.bodyInset, -LAYOUT.bodyInset)
    header:SetPoint("TOPRIGHT", -LAYOUT.bodyInset, -LAYOUT.bodyInset)
    header:SetHeight(LAYOUT.headerHeight)
    header._eflThemeContext = themeContext
    ApplySectionStyle(header, 0.98, 0.9, themeContext)

    local footer = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", LAYOUT.bodyInset, LAYOUT.bodyInset)
    footer:SetPoint("BOTTOMRIGHT", -LAYOUT.bodyInset, LAYOUT.bodyInset)
    footer:SetHeight(LAYOUT.footerHeight)
    footer._eflThemeContext = themeContext
    ApplySectionStyle(footer, 0.97, 0.9, themeContext)

    local body = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -LAYOUT.bodyInset)
    body:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -LAYOUT.bodyInset)
    body:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, LAYOUT.bodyInset)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, LAYOUT.bodyInset)
    body._eflThemeContext = themeContext
    ApplySectionStyle(body, 0.96, 0.9, themeContext)

    local textR, textG, textB = TextColor(nil, themeContext)
    local mutedR, mutedG, mutedB = MutedColor(nil, themeContext)
    local accentR, accentG, accentB = AccentColor(nil, themeContext)

    local iconCard = CreateFrame("Frame", nil, header, "BackdropTemplate")
    iconCard:SetSize(48, 36)
    iconCard:SetPoint("LEFT", 8, 0)
    iconCard._eflThemeContext = themeContext
    ApplyInsetStyle(iconCard, 1, themeContext)

    local headerIcon = iconCard:CreateTexture(nil, "ARTWORK", nil, 2)
    headerIcon:SetPoint("CENTER")
    headerIcon:SetSize(34, 22)
    headerIcon:SetTexture(HEADER_FRIENDS_ICON)
    headerIcon:SetVertexColor(accentR, accentG, accentB, 1)

    local statusSlot = CreateFrame("Frame", nil, header, "BackdropTemplate")
    statusSlot:SetSize(110, 28)
    statusSlot:SetPoint("LEFT", iconCard, "RIGHT", 6, 0)
    statusSlot._eflThemeContext = themeContext
    ApplyInsetStyle(statusSlot, 1, themeContext)

    local statusLabel = CreateLabel(statusSlot, 10, textR, textG, textB, 1)
    statusLabel:SetPoint("CENTER")
    statusLabel:SetText(LText("Status"))

    local battleTag = CreateLabel(header, 12, textR, textG, textB, 1, "OUTLINE")
    battleTag:SetPoint("LEFT", statusSlot, "RIGHT", 10, 0)
    battleTag:SetPoint("RIGHT", -12, 0)
    battleTag:SetJustifyH("CENTER")
    battleTag:SetText(LText("Battle.net"))

    local contactsPane = CreateFrame("Frame", nil, body)
    contactsPane:SetAllPoints()

    local searchBar = CreateFrame("Frame", nil, contactsPane, "BackdropTemplate")
    searchBar:SetPoint("TOPLEFT", LAYOUT.scrollInset, -LAYOUT.scrollInset)
    searchBar:SetPoint("TOPRIGHT", -LAYOUT.scrollInset, -LAYOUT.scrollInset)
    searchBar:SetHeight(22)
    searchBar._eflThemeContext = themeContext
    ApplyInsetStyle(searchBar, 1, themeContext)

    local searchIcon = searchBar:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(10, 10)
    searchIcon:SetPoint("LEFT", 6, 0)
    searchIcon:SetTexture(ICON_PATH .. "Search.png")
    searchIcon:SetVertexColor(mutedR, mutedG, mutedB, 1)

    local searchText = CreateLabel(searchBar, 10, mutedR, mutedG, mutedB, 0.6)
    searchText:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
    searchText:SetText(LText("Search friends..."))

    local topPanels = CreateFrame("Frame", nil, contactsPane)
    topPanels:SetPoint("TOPLEFT", searchBar, "BOTTOMLEFT", 0, -4)
    topPanels:SetPoint("TOPRIGHT", searchBar, "BOTTOMRIGHT", 0, -4)
    topPanels:SetHeight(LAYOUT.topPanelsHeight)

    local recentPanel = CreateFrame("Frame", nil, topPanels, "BackdropTemplate")
    recentPanel:SetPoint("TOPLEFT", 0, 0)
    recentPanel:SetPoint("BOTTOMLEFT", 0, 0)
    recentPanel:SetPoint("RIGHT", topPanels, "CENTER", -LAYOUT.topPanelGap * 0.5, 0)
    recentPanel._eflThemeContext = themeContext
    recentPanel._eflSelected = true
    ApplySectionStyle(recentPanel, 0.98, 0.9, themeContext)
    RefreshSummaryPanelState(recentPanel)

    recentPanel.title = CreateLabel(recentPanel, 10, textR, textG, textB, 1)
    recentPanel.title:SetPoint("LEFT", 8, 0)
    recentPanel.title:SetText(LText("Recent Allies"))

    recentPanel.summary = CreateLabel(recentPanel, 9, mutedR, mutedG, mutedB, 1, "OUTLINE")
    recentPanel.summary:SetPoint("LEFT", recentPanel.title, "RIGHT", 6, 0)
    recentPanel.summary:SetPoint("RIGHT", -10, 0)
    recentPanel.summary:SetText("2")

    local recruitPanel = CreateFrame("Frame", nil, topPanels, "BackdropTemplate")
    recruitPanel:SetPoint("TOPRIGHT", 0, 0)
    recruitPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    recruitPanel:SetPoint("LEFT", topPanels, "CENTER", LAYOUT.topPanelGap * 0.5, 0)
    recruitPanel._eflThemeContext = themeContext
    ApplySectionStyle(recruitPanel, 0.98, 0.9, themeContext)
    RefreshSummaryPanelState(recruitPanel)

    recruitPanel.title = CreateLabel(recruitPanel, 10, textR, textG, textB, 1)
    recruitPanel.title:SetPoint("LEFT", 8, 0)
    recruitPanel.title:SetText(LText("Recruit Friend"))

    recruitPanel.action = CreateSimpleButton(recruitPanel, 54, 20, LText("Open"), "default")
    recruitPanel.action._eflThemeContext = themeContext
    recruitPanel.action:SetPoint("RIGHT", -4, 0)
    recruitPanel.action.label:SetFont(ResolveFont(), 10, "OUTLINE")
    RefreshButtonStyle(recruitPanel.action)

    local listInset = CreateFrame("Frame", nil, contactsPane, "BackdropTemplate")
    listInset:SetPoint("TOPLEFT", topPanels, "BOTTOMLEFT", 0, -LAYOUT.scrollInset)
    listInset:SetPoint("TOPRIGHT", topPanels, "BOTTOMRIGHT", 0, -LAYOUT.scrollInset)
    listInset:SetPoint("BOTTOMLEFT", LAYOUT.scrollInset, LAYOUT.scrollInset)
    listInset:SetPoint("BOTTOMRIGHT", -LAYOUT.scrollInset, LAYOUT.scrollInset)
    listInset._eflThemeContext = themeContext
    ApplyInsetStyle(listInset, 0.98, themeContext)

    local groupHeader = CreateFrame("Frame", nil, listInset)
    groupHeader:SetPoint("TOPLEFT", 8, -8)
    groupHeader:SetPoint("TOPRIGHT", -26, -8)
    groupHeader:SetHeight(LAYOUT.groupHeaderHeight)
    groupHeader._eflThemeContext = themeContext
    ApplyInsetStyle(groupHeader, 0.96, themeContext)

    groupHeader.accent = groupHeader:CreateTexture(nil, "ARTWORK")
    groupHeader.accent:SetPoint("LEFT", 6, 0)
    groupHeader.accent:SetSize(3, 11)
    groupHeader.accent:SetColorTexture(accentR, accentG, accentB, 0.85)

    groupHeader.title = CreateLabel(groupHeader, 10, textR, textG, textB, 1, "OUTLINE")
    groupHeader.title:SetPoint("LEFT", groupHeader.accent, "RIGHT", 6, 0)
    groupHeader.title:SetText(LText("Raiders"))

    local function CreatePreviewRow(anchor, offsetY, nameText, subtitleText, detailText, onlineColor, classFile)
        local row = CreateFrame("Frame", nil, listInset, "BackdropTemplate")
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
        row:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, offsetY)
        row:SetHeight(LAYOUT.rowHeight)
        row._eflThemeContext = themeContext
        ApplySectionStyle(row, 0.98, 0.9, themeContext)

        row.accentEdge = row:CreateTexture(nil, "BACKGROUND")
        row.accentEdge:SetDrawLayer("BACKGROUND", 6)
        row.accentEdge:SetPoint("TOPLEFT", 1, -1)
        row.accentEdge:SetPoint("BOTTOMLEFT", 1, 1)
        row.accentEdge:SetWidth(2)
        row.accentEdge:SetTexture(WHITE8X8)
        row.accentEdge:SetColorTexture(accentR, accentG, accentB, 0.90)

        row.accentGlow = row:CreateTexture(nil, "BACKGROUND")
        row.accentGlow:SetDrawLayer("BACKGROUND", 5)
        row.accentGlow:SetPoint("TOPLEFT", row.accentEdge, "TOPRIGHT", 0, 0)
        row.accentGlow:SetPoint("BOTTOMLEFT", row.accentEdge, "BOTTOMRIGHT", 0, 0)
        row.accentGlow:SetWidth(60)
        row.accentGlow:SetTexture(WHITE8X8)
        ApplyTextureGradient(row.accentGlow, "HORIZONTAL", accentR, accentG, accentB, 0.12, accentR, accentG, accentB, 0)

        row.iconBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
        row.iconBox:SetSize(30, 30)
        row.iconBox:SetPoint("LEFT", 7, 0)
        row.iconBox._eflThemeContext = themeContext
        ApplyInsetStyle(row.iconBox, 1, themeContext)

        local icon = row.iconBox:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        if classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
            local coords = CLASS_ICON_TCOORDS[classFile]
            icon:SetSize(26, 26)
            icon:SetTexture(CLASS_ICON)
            icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            icon:SetSize(24, 24)
            icon:SetTexture(FRIEND_ICON)
            icon:SetTexCoord(0, 1, 0, 1)
        end

        local status = row:CreateTexture(nil, "ARTWORK")
        status:SetSize(5, 5)
        status:SetPoint("LEFT", row.iconBox, "RIGHT", 6, 0)
        status:SetColorTexture(onlineColor[1], onlineColor[2], onlineColor[3], 1)

        local name = CreateLabel(row, 9, textR, textG, textB, 1, "OUTLINE")
        name:SetPoint("TOPLEFT", status, "TOPRIGHT", 6, 8)
        name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        name:SetText(nameText)

        local subtitle = CreateLabel(row, 8, mutedR, mutedG, mutedB, 1)
        subtitle:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
        subtitle:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        local classLabel = classFile and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile])
        if classLabel and subtitleText and subtitleText ~= "" then
            subtitle:SetText(classLabel .. " - " .. subtitleText)
        else
            subtitle:SetText(subtitleText)
        end

        local detail = CreateLabel(row, 8, accentR, accentG, accentB, 1)
        detail:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -1)
        detail:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        detail:SetText(detailText)

        return row
    end

    local previewEntries = {
        { name = "Futnorris", realm = "Sanguino", detail = "The Dreamrift", status = { 0.28, 0.77, 0.51 }, classFile = "WARRIOR" },
        { name = "Qute", realm = "Sanguino", detail = "Skyreach", status = { 0.86, 0.32, 0.32 }, classFile = "MAGE" },
        { name = "Lunara", realm = "Dun Modr", detail = "Khaz Algar", status = { 0.28, 0.77, 0.51 }, classFile = "DRUID" },
        { name = "Thragor", realm = "Ragnaros", detail = "Nerub-ar Palace", status = { 0.28, 0.77, 0.51 }, classFile = "DEATHKNIGHT" },
        { name = "Serelyn", realm = "Uldum", detail = "Undermine", status = { 0.86, 0.72, 0.24 }, classFile = "PRIEST" },
        { name = "Kaelith", realm = "Tarren Mill", detail = "Dungeon Finder", status = { 0.28, 0.77, 0.51 }, classFile = "DEMONHUNTER" },
    }

    local previousAnchor = groupHeader
    for index, entry in ipairs(previewEntries) do
        local offsetY = (index == 1) and -6 or -6
        previousAnchor = CreatePreviewRow(
            previousAnchor,
            offsetY,
            entry.name,
            entry.realm,
            entry.detail,
            entry.status,
            entry.classFile
        )
    end

    local addFriend = CreateSimpleButton(footer, 100, 22, LText("Add Friend"), "footer")
    addFriend._eflThemeContext = themeContext
    addFriend:SetPoint("LEFT", 6, 0)
    addFriend.label:SetFont(ResolveFont(), 10, "OUTLINE")
    RefreshButtonStyle(addFriend)

    local sendMessage = CreateSimpleButton(footer, 100, 22, LText("Send Message"), "footer")
    sendMessage._eflThemeContext = themeContext
    sendMessage:SetPoint("RIGHT", -6, 0)
    sendMessage.label:SetFont(ResolveFont(), 10, "OUTLINE")
    RefreshButtonStyle(sendMessage)

    local newGroup = CreateSimpleButton(footer, 22, 22, "+", "icon")
    newGroup._eflThemeContext = themeContext
    newGroup:SetPoint("CENTER", 0, 0)
    newGroup.label:SetFont(ResolveFont(), 13, "OUTLINE")
    RefreshButtonStyle(newGroup)

    local navWidth = (LAYOUT.windowWidth - (LAYOUT.rootInset * 2) - 16) * 0.5 - 2
    local contactsButton = CreateSimpleButton(navBar, navWidth, 24, LText("Contacts"), "nav")
    contactsButton._eflThemeContext = themeContext
    contactsButton._eflSelected = true
    contactsButton:SetPoint("LEFT", 8, 0)
    contactsButton:SetPoint("TOP", 0, -4)
    contactsButton:SetPoint("BOTTOM", 0, 4)
    contactsButton.label:SetFont(ResolveFont(), 10, "OUTLINE")
    RefreshButtonStyle(contactsButton)

    local quickJoinButton = CreateSimpleButton(navBar, navWidth, 24, LText("Quick Join"), "nav")
    quickJoinButton._eflThemeContext = themeContext
    quickJoinButton:SetPoint("LEFT", contactsButton, "RIGHT", 4, 0)
    quickJoinButton:SetPoint("TOP", 0, -4)
    quickJoinButton:SetPoint("BOTTOM", 0, 4)
    quickJoinButton.label:SetFont(ResolveFont(), 10, "OUTLINE")
    RefreshButtonStyle(quickJoinButton)

    local caption = CreateLabel(card, 10, accentR, accentG, accentB, 1, "OUTLINE")
    caption:SetPoint("TOP", viewport, "BOTTOM", 0, -8)
    caption:SetText(titleText or "")
    card.caption = caption

    local disabledOverlay = CreateFrame("Frame", nil, viewport, "BackdropTemplate")
    disabledOverlay:SetAllPoints()
    disabledOverlay._eflThemeContext = themeContext
    ApplySectionStyle(disabledOverlay, 0.96, 0.9, themeContext)
    disabledOverlay:SetFrameLevel(viewport:GetFrameLevel() + 20)
    disabledOverlay.label = CreateLabel(disabledOverlay, 12, textR, textG, textB, 1, "OUTLINE")
    disabledOverlay.label:SetPoint("CENTER")
    disabledOverlay.label:SetText(LText("Disabled"))
    disabledOverlay:Hide()
    card.disabledOverlay = disabledOverlay

    return card
end

function EnhancedFriendList:AcquireGroup(index)
    self.groups = self.groups or {}
    if self.groups[index] then
        return self.groups[index]
    end

    local group = CreateFrame("Frame", nil, self.contactsContent, "BackdropTemplate")
    ApplySectionStyle(group, 0.92, 0.9)

    group.header = CreateFrame("Button", nil, group)
    group.header:SetPoint("TOPLEFT", 1, -1)
    group.header:SetPoint("TOPRIGHT", -1, -1)
    group.header:SetHeight(LAYOUT.groupHeaderHeight)
    group.header:RegisterForClicks("LeftButtonUp")
    ApplyInsetStyle(group.header, 0.96)
    local ar, ag, ab = AccentColor()
    group.header.bg = group.header:CreateTexture(nil, "BACKGROUND")
    group.header.bg:SetAllPoints()
    group.header.bg:SetTexture(BUTTON_TEXTURE)
    group.header.bg:SetVertexColor(1, 1, 1, 0.16)
    group.header.accent = group.header:CreateTexture(nil, "ARTWORK")
    group.header.accent:SetPoint("LEFT", 6, 0)
    group.header.accent:SetSize(3, 11)
    group.header.accent:SetColorTexture(ar, ag, ab, 0.85)

    -- Collapse/expand arrow (texture icon)
    group.header.arrow = group.header:CreateTexture(nil, "OVERLAY")
    group.header.arrow:SetSize(10, 10)
    group.header.arrow:SetPoint("RIGHT", -24, 0)
    group.header.arrow:SetTexture(ARROW_DOWN_ICON)
    group.header.arrow:SetVertexColor(ar, ag, ab, 0.85)

    -- Delete button for custom groups (hidden by default)
    group.header.deleteBtn = CreateFrame("Button", nil, group.header)
    group.header.deleteBtn:SetSize(16, 16)
    group.header.deleteBtn:SetPoint("RIGHT", group.header.arrow, "LEFT", -6, 0)
    group.header.deleteBtn:SetHitRectInsets(-2, -2, -2, -2)
    group.header.deleteBtn:Hide()
    local delTex = group.header.deleteBtn:CreateTexture(nil, "ARTWORK")
    delTex:SetPoint("CENTER")
    delTex:SetSize(11, 11)
    delTex:SetTexture(DELETE_ICON)
    delTex:SetVertexColor(0.92, 0.28, 0.28, 0.92)
    group.header.deleteBtn.icon = delTex
    group.header.deleteBtn:SetScript("OnClick", function(self)
        local gName = self:GetParent():GetParent()._customGroupName
        if gName then
            ConfirmDeleteGroup(gName)
        end
    end)
    group.header.deleteBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 0.36, 0.36, 1)
    end)
    group.header.deleteBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.92, 0.28, 0.28, 0.92)
    end)

    -- Hover highlight
    group.header.hover = group.header:CreateTexture(nil, "HIGHLIGHT")
    group.header.hover:SetAllPoints()
    group.header.hover:SetTexture(BUTTON_HOVER_TEXTURE)
    group.header.hover:SetVertexColor(1, 1, 1, 0.12)

    group.header:SetScript("OnClick", function(self)
        if runtime.dragEntry then
            return
        end
        local sectionKey = self:GetParent()._sectionKey
        if sectionKey then
            runtime.collapsedSections[sectionKey] = not runtime.collapsedSections[sectionKey]
            if EnhancedFriendList and EnhancedFriendList.RequestRefresh then
                EnhancedFriendList:RequestRefresh()
            end
        end
    end)
    group.header:SetScript("OnEnter", function(self)
        if self:GetParent()._customGroupName and runtime.dragEntry then
            SetGroupDropTarget(self:GetParent()._customGroupName)
        end
    end)
    group.header:SetScript("OnLeave", function(self)
        if runtime.dragEntry and runtime.dragTargetGroup == self:GetParent()._customGroupName then
            SetGroupDropTarget(nil)
        end
    end)

    local tr, tg, tb = TextColor()
    group.title = CreateLabel(group.header, 10, tr, tg, tb, 1)
    group.title:SetPoint("LEFT", group.header.accent, "RIGHT", 6, 0)

    local mr, mg, mb = MutedColor()
    group.count = CreateLabel(group.header, 10, mr, mg, mb, 1)
    group.count:SetPoint("RIGHT", -8, 0)
    group.count:SetJustifyH("RIGHT")

    group.rows = {}
    self.groups[index] = group
    return group
end

function EnhancedFriendList:AcquireRow(group, index)
    if group.rows[index] then
        return group.rows[index]
    end

    local row = CreateFrame("Button", nil, group, "BackdropTemplate")
    ApplySectionStyle(row, 0.98, 0.9)
    row:SetHeight(LAYOUT.rowHeight)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:RegisterForDrag("LeftButton")

    row.hover = row:CreateTexture(nil, "OVERLAY")
    row.hover:SetAllPoints()
    row.hover:SetTexture(BUTTON_HOVER_TEXTURE)
    row.hover:SetVertexColor(1, 1, 1, 0)

    row.selection = row:CreateTexture(nil, "OVERLAY")
    row.selection:SetAllPoints()
    row.selection:SetColorTexture(1, 1, 1, 0)

    row.classTint = row:CreateTexture(nil, "BACKGROUND")
    row.classTint:SetDrawLayer("BACKGROUND", 5)
    row.classTint:SetAllPoints()
    row.classTint:SetColorTexture(1, 1, 1, 0)

    -- Row-level accent gradient: left edge vertical bar + horizontal glow fade
    row.accentEdge = row:CreateTexture(nil, "BACKGROUND")
    row.accentEdge:SetDrawLayer("BACKGROUND", 6)
    row.accentEdge:SetPoint("TOPLEFT", 1, -1)
    row.accentEdge:SetPoint("BOTTOMLEFT", 1, 1)
    row.accentEdge:SetWidth(2)
    row.accentEdge:SetTexture(WHITE8X8)

    row.accentGlow = row:CreateTexture(nil, "BACKGROUND")
    row.accentGlow:SetDrawLayer("BACKGROUND", 5)
    row.accentGlow:SetPoint("TOPLEFT", row.accentEdge, "TOPRIGHT", 0, 0)
    row.accentGlow:SetPoint("BOTTOMLEFT", row.accentEdge, "BOTTOMRIGHT", 0, 0)
    row.accentGlow:SetWidth(60)
    row.accentGlow:SetTexture(WHITE8X8)

    row.iconBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconBox:SetSize(42, 42)
    row.iconBox:SetPoint("LEFT", 8, 0)
    ApplyInsetStyle(row.iconBox, 1)

    row.icon = row.iconBox:CreateTexture(nil, "ARTWORK", nil, 2)
    row.icon:SetPoint("CENTER")
    row.icon:SetSize(36, 36)
    row.icon:SetTexture(FRIEND_ICON)
    row.icon:SetTexCoord(0, 1, 0, 1)

    do
        local ar, ag, ab = AccentColor()
        row.iconGlow = row:CreateTexture(nil, "ARTWORK", nil, 1)
        row.iconGlow:SetPoint("TOP", row.iconBox, "BOTTOM", 0, 4)
        row.iconGlow:SetSize(52, 18)
        row.iconGlow:SetTexture(WHITE8X8)
        ApplyTextureGradient(row.iconGlow, "VERTICAL", ar, ag, ab, 0, ar, ag, ab, 0.30)
    end

    row.status = row:CreateTexture(nil, "ARTWORK")
    row.status:SetSize(6, 6)
    row.status:SetPoint("LEFT", row.iconBox, "RIGHT", 8, 0)

    row.invite = CreateSimpleButton(row, 24, 24, "+", "invite")
    row.invite:SetPoint("RIGHT", -8, 0)
    row.invite.label:SetFont(ResolveFont(), 13, "OUTLINE")
    row.inviteIcon = row.invite:CreateTexture(nil, "OVERLAY")
    row.inviteIcon:SetDrawLayer("OVERLAY", 1)
    row.inviteIcon:SetSize(17, 17)
    row.inviteIcon:SetPoint("CENTER")
    row.inviteIcon:SetTexture(INVITE_ICON)
    row.inviteIcon:SetTexCoord(0.03, 0.97, 0.03, 0.97)
    row.inviteIcon:Hide()

    row.menuButton = CreateSimpleButton(row, 18, 18, "", "icon")
    row.menuButton:SetPoint("RIGHT", row.invite, "LEFT", -4, 0)
    row.menuButton.arrow = row.menuButton:CreateTexture(nil, "ARTWORK")
    row.menuButton.arrow:SetPoint("CENTER")
    row.menuButton.arrow:SetSize(9, 9)
    row.menuButton.arrow:SetTexture(ARROW_DOWN_ICON)

    row.projectIconFrame = CreateFrame("Frame", nil, row)
    row.projectIconFrame:SetSize(24, 24)
    row.projectIconFrame:SetPoint("RIGHT", row.menuButton, "LEFT", -6, 0)
    row.projectIconFrame:EnableMouse(true)
    row.projectIconFrame:Hide()

    row.projectIcon = row.projectIconFrame:CreateTexture(nil, "ARTWORK")
    row.projectIcon:SetAllPoints()
    row.projectIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.projectIconFrame:SetScript("OnEnter", function(self)
        if not self.projectLabel then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.projectLabel, 1, 0.82, 0, 1)
        GameTooltip:AddLine(LText("World of Warcraft"), 0.75, 0.75, 0.78, 1)
        GameTooltip:Show()
    end)
    row.projectIconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.factionIcon = row:CreateTexture(nil, "ARTWORK")
    row.factionIcon:SetSize(48, 48)
    row.factionIcon:SetPoint("RIGHT", row.menuButton, "LEFT", -4, 0)
    row.factionIcon:SetAlpha(0.85)
    row.factionIcon:Hide()
    row.invite:SetScript("OnClick", function(self)
        if self.entry then
            PerformPrimaryAction(self.entry)
        end
    end)
    row.menuButton:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        if not (parent and parent.entry and parent.entry.kind ~= "system") then
            return
        end
        runtime.selectedEntry = parent.entry
        EnhancedFriendList:RefreshSelection()
        OpenGroupAssignMenu(parent.entry, parent)
    end)

    local tr, tg, tb = TextColor()
    row.title = CreateLabel(row, 12, tr, tg, tb, 1, "OUTLINE")
    row.title:SetPoint("TOPLEFT", row.status, "TOPRIGHT", 8, 12)

    local ar, ag, ab = AccentColor()
    row.note = CreateLabel(row, 10, ar, ag, ab, 0.92)
    row.note:SetPoint("TOPRIGHT", row.factionIcon, "TOPLEFT", -6, -9)
    row.note:SetJustifyH("RIGHT")
    row.note:Hide()

    row.title:SetPoint("RIGHT", row.note, "LEFT", -6, 0)

    local mr, mg, mb = MutedColor()
    row.subtitle = CreateLabel(row, 10, mr, mg, mb, 1)
    row.subtitle:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.subtitle:SetPoint("RIGHT", row.factionIcon, "LEFT", -6, 0)

    local rr, rg, rb = AccentColor()
    row.detail = CreateLabel(row, 10, rr, rg, rb, 1)
    row.detail:SetPoint("TOPLEFT", row.subtitle, "BOTTOMLEFT", 0, -1)
    row.detail:SetPoint("RIGHT", row.factionIcon, "LEFT", -6, 0)

    row:SetScript("OnEnter", function(self)
        HideUnderlyingFriendTooltip()
        self.hover:SetVertexColor(1, 1, 1, 0.16)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:SetVertexColor(1, 1, 1, 0)
    end)
    row:SetScript("OnClick", function(self, button)
        runtime.selectedEntry = self.entry
        if runtime.selectedEntry and runtime.selectedEntry.kind == "system" then
            runtime.selectedEntry = nil
        end
        EnhancedFriendList:RefreshSelection()

        if button == "RightButton" then
            if runtime.selectedEntry then
                OpenGroupAssignMenu(runtime.selectedEntry, self)
            end
            return
        end
    end)
    row:SetScript("OnDoubleClick", function(self)
        if IsPendingInviteEntry(self.entry) then
            PerformPrimaryAction(self.entry)
        elseif self.entry and self.entry.kind ~= "system" then
            SendWhisperToEntry(self.entry)
        end
    end)
    row:SetScript("OnDragStart", function(self)
        if not self.entry or self.entry.kind == "system" or self.entry.kind == "invite" then
            return
        end
        runtime.dragEntry = self.entry
        runtime.dragSourceRow = self
        self:SetAlpha(0.78)
        RefreshGroupDropVisuals()
    end)
    row:SetScript("OnDragStop", function()
        HandleFriendRowDrop()
    end)

    group.rows[index] = row
    return row
end

function EnhancedFriendList:CreateFrame()
    if runtime.initialized then
        return
    end

    local friendsFrame = GetFriendsFrame()
    if not friendsFrame then
        return
    end

    local root = CreateFrame("Frame", "KT_EnhancedFriendListFrame", friendsFrame, "BackdropTemplate")
    root:SetPoint("TOPLEFT", LAYOUT.rootInset, -LAYOUT.rootInset)
    root:SetPoint("BOTTOMRIGHT", -LAYOUT.rootInset, LAYOUT.rootInset)
    root:SetFrameLevel((friendsFrame:GetFrameLevel() or 0) + 20)
    root:SetClipsChildren(false)
    ApplyShellStyle(root, 0.985)
    root:Hide()

    root.bg = root:CreateTexture(nil, "BACKGROUND")
    root.bg:SetAllPoints()
    root.bg:SetTexture(FRAME_BACKGROUND_TEXTURE)
    root.bg:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    root.bg:SetVertexColor(1, 1, 1, 0.24)

    root.shade = root:CreateTexture(nil, "BACKGROUND")
    root.shade:SetAllPoints()
    root.shade:SetColorTexture(0, 0, 0, 0.45)

    -- Bottom accent glow: horizontal accent gradient along the bottom edge
    local ar, ag, ab = AccentColor()
    root.bottomGlow = root:CreateTexture(nil, "BACKGROUND")
    root.bottomGlow:SetDrawLayer("BACKGROUND", 5)
    root.bottomGlow:SetPoint("BOTTOMLEFT", 1, 1)
    root.bottomGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    root.bottomGlow:SetHeight(90)
    root.bottomGlow:SetTexture(WHITE8X8)
    ApplyTextureGradient(root.bottomGlow, "VERTICAL",
        ar, ag, ab, 0.07,
        ar, ag, ab, 0)

    -- Top accent edge: gradient line
    root.topEdge = root:CreateTexture(nil, "ARTWORK")
    root.topEdge:SetDrawLayer("ARTWORK", 7)
    root.topEdge:SetPoint("TOPLEFT", 1, -1)
    root.topEdge:SetPoint("TOPRIGHT", -1, -1)
    root.topEdge:SetHeight(2)
    root.topEdge:SetTexture(WHITE8X8)
    ApplyTextureGradient(root.topEdge, "HORIZONTAL",
        ar, ag, ab, 0.85,
        ar, ag, ab, 0.08)

    -- Left accent edge: vertical gradient line
    root.leftEdge = root:CreateTexture(nil, "ARTWORK")
    root.leftEdge:SetDrawLayer("ARTWORK", 7)
    root.leftEdge:SetPoint("TOPLEFT", 1, -1)
    root.leftEdge:SetPoint("BOTTOMLEFT", 1, 1)
    root.leftEdge:SetWidth(1)
    root.leftEdge:SetTexture(WHITE8X8)
    ApplyTextureGradient(root.leftEdge, "VERTICAL",
        ar, ag, ab, 0.10,
        ar, ag, ab, 0.50)

    local navBar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    navBar:SetPoint("BOTTOMLEFT", 0, 0)
    navBar:SetPoint("BOTTOMRIGHT", 0, 0)
    navBar:SetHeight(LAYOUT.navHeight)
    ApplySectionStyle(navBar, 0.98, 0.9)

    local mainPanel = CreateFrame("Frame", nil, root, "BackdropTemplate")
    mainPanel:SetPoint("TOPLEFT", 0, 0)
    mainPanel:SetPoint("TOPRIGHT", 0, 0)
    mainPanel:SetPoint("BOTTOMLEFT", navBar, "TOPLEFT", 0, LAYOUT.panelGap)
    mainPanel:SetPoint("BOTTOMRIGHT", navBar, "TOPRIGHT", 0, LAYOUT.panelGap)
    ApplyShellStyle(mainPanel, 0.965)

    local header = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    header:SetPoint("TOPLEFT", LAYOUT.bodyInset, -LAYOUT.bodyInset)
    header:SetPoint("TOPRIGHT", -LAYOUT.bodyInset, -LAYOUT.bodyInset)
    header:SetHeight(LAYOUT.headerHeight)
    ApplySectionStyle(header, 0.98, 0.9)

    local footer = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", LAYOUT.bodyInset, LAYOUT.bodyInset)
    footer:SetPoint("BOTTOMRIGHT", -LAYOUT.bodyInset, LAYOUT.bodyInset)
    footer:SetHeight(LAYOUT.footerHeight)
    ApplySectionStyle(footer, 0.97, 0.9)

    local body = CreateFrame("Frame", nil, mainPanel, "BackdropTemplate")
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -LAYOUT.bodyInset)
    body:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -LAYOUT.bodyInset)
    body:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, LAYOUT.bodyInset)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, LAYOUT.bodyInset)
    ApplySectionStyle(body, 0.96, 0.9)

    local iconCard = CreateFrame("Frame", nil, header, "BackdropTemplate")
    iconCard:SetSize(48, 36)
    iconCard:SetPoint("LEFT", 8, 0)
    ApplyInsetStyle(iconCard, 1)

    do
        local ar, ag, ab = AccentColor()
        local iconGlowBg = header:CreateTexture(nil, "BACKGROUND", nil, 7)
        iconGlowBg:SetPoint("CENTER", iconCard, "CENTER", 0, 0)
        iconGlowBg:SetSize(80, 64)
        iconGlowBg:SetTexture("Interface\\COMMON\\ShadowOverlay-Top")
        iconGlowBg:SetVertexColor(ar, ag, ab, 0.55)
        iconGlowBg:SetBlendMode("ADD")
        self._iconGlow = iconGlowBg
    end

    local icon = iconCard:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetPoint("CENTER")
    icon:SetSize(34, 22)
    icon:SetTexture(HEADER_FRIENDS_ICON)
    do
        local ar, ag, ab = AccentColor()
        icon:SetVertexColor(ar, ag, ab, 1)
    end
    self._headerIcon = icon

    local statusSlot = CreateFrame("Frame", nil, header, "BackdropTemplate")
    statusSlot:SetSize(120, 28)
    statusSlot:SetPoint("LEFT", iconCard, "RIGHT", 6, 0)
    ApplyInsetStyle(statusSlot, 1)

    local str, stg, stb = TextColor()
    local statusFallback = CreateLabel(statusSlot, 10, str, stg, stb, 1)
    statusFallback:SetPoint("CENTER")
    statusFallback:SetText(LText("Status"))
    statusFallback:Hide()

    local optionsButton = CreateSimpleButton(header, 80, 26, LText("Options"), "default")
    optionsButton:SetPoint("RIGHT", -32, 0)
    optionsButton:SetScript("OnClick", function(self)
        local menu = EnhancedFriendList:CreateOptionMenu()
        if menu:IsShown() then
            menu:Hide()
            return
        end
        menu:ClearAllPoints()
        menu:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -6)
        menu:Show()
    end)

    local closeButton = CreateSimpleButton(header, 22, 22, "", "icon")
    closeButton:SetPoint("RIGHT", -6, 0)
    closeButton.tex = closeButton:CreateTexture(nil, "ARTWORK")
    closeButton.tex:SetPoint("CENTER")
    closeButton.tex:SetSize(9, 9)
    closeButton.tex:SetTexture(CLOSE_ICON)
    closeButton:SetScript("OnClick", function()
        local owner = GetFriendsFrame()
        if owner then
            if _G.HideUIPanel then
                _G.HideUIPanel(owner)
            else
                owner:Hide()
            end
        end
    end)

    local btr, btg, btb = TextColor()
    local battleTag = CreateLabel(header, 12, btr, btg, btb, 1, "OUTLINE")
    battleTag:SetPoint("LEFT", statusSlot, "RIGHT", 10, 0)
    battleTag:SetPoint("RIGHT", optionsButton, "LEFT", -8, 0)
    battleTag:SetJustifyH("CENTER")
    battleTag:SetText(LText("Battle.net"))

    local contactsPane = CreateFrame("Frame", nil, body)
    contactsPane:SetAllPoints()
    contactsPane:EnableMouse(true)
    contactsPane:SetScript("OnEnter", HideUnderlyingFriendTooltip)

    local mouseBlocker = CreateFrame("Frame", nil, contactsPane)
    mouseBlocker:SetAllPoints()
    mouseBlocker:EnableMouse(true)
    mouseBlocker:SetScript("OnEnter", HideUnderlyingFriendTooltip)
    mouseBlocker:SetScript("OnMouseDown", HideUnderlyingFriendTooltip)

    -- ── Barra de búsqueda ────────────────────────────────────────
    local searchBar = CreateFrame("Frame", nil, contactsPane, "BackdropTemplate")
    searchBar:SetPoint("TOPLEFT", LAYOUT.scrollInset, -LAYOUT.scrollInset)
    searchBar:SetPoint("TOPRIGHT", -LAYOUT.scrollInset, -LAYOUT.scrollInset)
    searchBar:SetHeight(22)
    ApplyInsetStyle(searchBar, 1)

    local searchIcon = searchBar:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(10, 10)
    searchIcon:SetPoint("LEFT", 6, 0)
    searchIcon:SetTexture(ICON_PATH .. "Search.png")
    searchIcon:SetVertexColor(MutedColor())

    local searchBox = CreateFrame("EditBox", nil, searchBar)
    searchBox:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
    searchBox:SetPoint("RIGHT", -8, 0)
    searchBox:SetHeight(18)
    searchBox:SetFont(ResolveFont(), 10, "")
    searchBox:SetTextColor(TextColor())
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(60)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:SetText("") end)
    searchBox:SetScript("OnTextChanged", function()
        runtime.dataDirty = true
        if EnhancedFriendList and EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh()
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    do
        local mr, mg, mb = MutedColor()
        local ph = searchBox:CreateFontString(nil, "ARTWORK")
        ph:SetFont(ResolveFont(), 10, "")
        ph:SetTextColor(mr, mg, mb, 0.6)
        ph:SetPoint("LEFT", 2, 0)
        ph:SetText(LText("Search friends..."))
        searchBox._placeholder = ph
        searchBox:SetScript("OnEditFocusGained", function(self) self._placeholder:Hide() end)
        searchBox:SetScript("OnEditFocusLost", function(self)
            if (self:GetText() or "") == "" then self._placeholder:Show() end
        end)
    end

    local topPanels = CreateFrame("Frame", nil, contactsPane)
    topPanels:SetPoint("TOPLEFT", searchBar, "BOTTOMLEFT", 0, -4)
    topPanels:SetPoint("TOPRIGHT", searchBar, "BOTTOMRIGHT", 0, -4)
    topPanels:SetHeight(LAYOUT.topPanelsHeight)

    local recentPanel = CreateFrame("Frame", nil, topPanels, "BackdropTemplate")
    recentPanel:SetPoint("TOPLEFT", 0, 0)
    recentPanel:SetPoint("BOTTOMLEFT", 0, 0)
    recentPanel:SetPoint("RIGHT", topPanels, "CENTER", -LAYOUT.topPanelGap * 0.5, 0)
    ApplySectionStyle(recentPanel, 0.98, 0.9)
    recentPanel:EnableMouse(true)
    recentPanel:SetScript("OnEnter", function(self)
        self._eflHovered = true
        HideUnderlyingFriendTooltip()
        RefreshSummaryPanelState(self)
    end)
    recentPanel:SetScript("OnLeave", function(self)
        self._eflHovered = false
        RefreshSummaryPanelState(self)
    end)
    recentPanel:SetScript("OnMouseDown", HideUnderlyingFriendTooltip)
    recentPanel:SetScript("OnMouseUp", function()
        EnhancedFriendList:ToggleRecentAlliesView()
    end)

    local rtr, rtg, rtb = TextColor()
    recentPanel.title = CreateLabel(recentPanel, 10, rtr, rtg, rtb, 1)
    recentPanel.title:SetPoint("LEFT", 8, 0)

    local rmr, rmg, rmb = MutedColor()
    recentPanel.summary = CreateLabel(recentPanel, 9, rmr, rmg, rmb, 1, "OUTLINE")
    recentPanel.summary:SetPoint("LEFT", recentPanel.title, "RIGHT", 6, 0)
    recentPanel.summary:SetPoint("RIGHT", -10, 0)
    recentPanel.summary:SetWordWrap(false)
    recentPanel.summary:SetText(LText("Scanning..."))

    local recruitPanel = CreateFrame("Frame", nil, topPanels, "BackdropTemplate")
    recruitPanel:SetPoint("TOPRIGHT", 0, 0)
    recruitPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    recruitPanel:SetPoint("LEFT", topPanels, "CENTER", LAYOUT.topPanelGap * 0.5, 0)
    ApplySectionStyle(recruitPanel, 0.98, 0.9)
    recruitPanel:EnableMouse(true)
    recruitPanel:SetScript("OnEnter", function(self)
        self._eflHovered = true
        HideUnderlyingFriendTooltip()
        RefreshSummaryPanelState(self)
    end)
    recruitPanel:SetScript("OnLeave", function(self)
        self._eflHovered = false
        RefreshSummaryPanelState(self)
    end)
    recruitPanel:SetScript("OnMouseDown", HideUnderlyingFriendTooltip)

    local qtr, qtg, qtb = TextColor()
    recruitPanel.title = CreateLabel(recruitPanel, 10, qtr, qtg, qtb, 1)
    recruitPanel.title:SetPoint("LEFT", 8, 0)
    recruitPanel.title:SetText(LText("Recruit Friend"))

    local qmr, qmg, qmb = MutedColor()
    recruitPanel.summary = CreateLabel(recruitPanel, 10, qmr, qmg, qmb, 1)
    recruitPanel.summary:SetPoint("LEFT", recruitPanel.title, "RIGHT", 6, 0)
    recruitPanel.summary:SetPoint("RIGHT", -90, 0)
    recruitPanel.summary:SetWordWrap(false)
    recruitPanel.summary:SetText("")

    recruitPanel.action = CreateSimpleButton(recruitPanel, 54, 20, LText("Open"), "default")
    recruitPanel.action:SetPoint("RIGHT", -4, 0)
    local function UpdateRecruitButtonLabel()
        local shown = _G.RecruitAFriendRecruitmentFrame and _G.RecruitAFriendRecruitmentFrame:IsShown()
        recruitPanel.action.label:SetText(LText(shown and "Close" or "Open"))
    end
    recruitPanel.action:SetScript("OnClick", function()
        if _G.RecruitAFriendRecruitmentFrame then
            if _G.RecruitAFriendRecruitmentFrame:IsShown() then
                _G.RecruitAFriendRecruitmentFrame:Hide()
            else
                _G.RecruitAFriendRecruitmentFrame:Show()
            end
            UpdateRecruitButtonLabel()
        elseif _G.FriendsFrameRecruitAFriendButton and _G.FriendsFrameRecruitAFriendButton.Click then
            _G.FriendsFrameRecruitAFriendButton:Click()
            C_Timer.After(0.1, UpdateRecruitButtonLabel)
        end
    end)
    local recruitFrame = _G.RecruitAFriendRecruitmentFrame
    if recruitFrame then
        hooksecurefunc(recruitFrame, "Show", UpdateRecruitButtonLabel)
        hooksecurefunc(recruitFrame, "Hide", UpdateRecruitButtonLabel)
    end
    UpdateRecruitButtonLabel()

    local listInset = CreateFrame("Frame", nil, contactsPane, "BackdropTemplate")
    listInset:SetPoint("TOPLEFT", topPanels, "BOTTOMLEFT", 0, -LAYOUT.scrollInset)
    listInset:SetPoint("TOPRIGHT", topPanels, "BOTTOMRIGHT", 0, -LAYOUT.scrollInset)
    listInset:SetPoint("BOTTOMLEFT", LAYOUT.scrollInset, LAYOUT.scrollInset)
    listInset:SetPoint("BOTTOMRIGHT", -LAYOUT.scrollInset, LAYOUT.scrollInset)
    ApplyInsetStyle(listInset, 0.98)

    local scroll = CreateFrame("ScrollFrame", nil, listInset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -24, 8)

    -- Estilizar scrollbar para tema KUI
    do
        local sb = scroll.ScrollBar
        if sb then
            sb:ClearAllPoints()
            sb:SetPoint("TOPRIGHT", listInset, "TOPRIGHT", -12, -10)
            sb:SetPoint("BOTTOMRIGHT", listInset, "BOTTOMRIGHT", -12, 10)
            sb:SetWidth(12)

            -- Hide all default textures
            for _, tex in ipairs({ sb:GetRegions() }) do
                if tex and tex:IsObjectType("Texture") then tex:SetAlpha(0) end
            end
            if sb.ScrollUpButton then sb.ScrollUpButton:SetAlpha(0); sb.ScrollUpButton:SetSize(1, 1) end
            if sb.ScrollDownButton then sb.ScrollDownButton:SetAlpha(0); sb.ScrollDownButton:SetSize(1, 1) end

            -- Track background
            local track = sb:CreateTexture(nil, "BACKGROUND")
            track:SetPoint("TOPLEFT", 2, 0)
            track:SetPoint("BOTTOMRIGHT", -2, 0)
            do
                local tr, tg, tb = ScrollbarColors()
                track:SetColorTexture(tr, tg, tb, 0.88)
            end

            -- Track border lines
            local trackLeft = sb:CreateTexture(nil, "BACKGROUND", nil, 2)
            trackLeft:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
            trackLeft:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
            trackLeft:SetWidth(1)
            do
                local _, _, _, er, eg, eb = ScrollbarColors()
                trackLeft:SetColorTexture(er, eg, eb, 0.75)
            end
            local trackRight = sb:CreateTexture(nil, "BACKGROUND", nil, 2)
            trackRight:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, 0)
            trackRight:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, 0)
            trackRight:SetWidth(1)
            do
                local _, _, _, er, eg, eb = ScrollbarColors()
                trackRight:SetColorTexture(er, eg, eb, 0.75)
            end

            -- Accent thumb
            local thumb = sb.ThumbTexture or (sb.GetThumbTexture and sb:GetThumbTexture())
            if thumb then
                local ar, ag, ab = AccentColor()
                thumb:SetColorTexture(ar, ag, ab, 0.88)
                thumb:SetSize(8, 48)
            end

            -- Thumb glow overlay
            local thumbGlow = sb:CreateTexture(nil, "ARTWORK", nil, 1)
            thumbGlow:SetSize(14, 54)
            if thumb then
                thumbGlow:SetPoint("CENTER", thumb, "CENTER", 0, 0)
            end
            local ar, ag, ab = AccentColor()
            thumbGlow:SetTexture(WHITE8X8)
            thumbGlow:SetColorTexture(ar, ag, ab, 0.16)
            thumbGlow:SetBlendMode("ADD")

            self._scrollTrack = track
            self._scrollTrackLeft = trackLeft
            self._scrollTrackRight = trackRight
            self._scrollThumb = thumb
            self._scrollThumbGlow = thumbGlow
        end
    end

    local contactsContent = CreateFrame("Frame", nil, scroll)
    contactsContent:SetSize(1, 1)
    scroll:SetScrollChild(contactsContent)

    local externalHost = CreateFrame("Frame", "KT_EFL_ExternalHost", mainPanel)
    externalHost:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -LAYOUT.bodyInset)
    externalHost:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -LAYOUT.bodyInset)
    externalHost:SetPoint("BOTTOMLEFT", LAYOUT.bodyInset, LAYOUT.bodyInset)
    externalHost:SetPoint("BOTTOMRIGHT", -LAYOUT.bodyInset, LAYOUT.bodyInset)
    externalHost:SetFrameLevel(body:GetFrameLevel() + 10)
    externalHost:SetClipsChildren(true)
    -- Dummy tab so Blizzard's ClaimRaidFrame doesn't error on GetName().."Tab1"
    local dummyTab = CreateFrame("Button", "KT_EFL_ExternalHostTab1", externalHost)
    dummyTab:Hide()
    dummyTab:SetScript("OnClick", function() end)
    local ehBg = externalHost:CreateTexture(nil, "BACKGROUND")
    ehBg:SetAllPoints()
    ehBg:SetColorTexture(0.028, 0.028, 0.036, 1)
    externalHost:Hide()

    local addFriend = CreateSimpleButton(footer, 100, 22, LText("Add Friend"), "footer")
    addFriend:SetPoint("LEFT", 6, 0)
    addFriend.label:SetFont(ResolveFont(), 10, "OUTLINE")
    addFriend:SetScript("OnClick", function()
        if _G.FriendsFrameAddFriendButton and _G.FriendsFrameAddFriendButton.Click then
            _G.FriendsFrameAddFriendButton:Click()
        elseif FriendsFrameAddFriendButton_OnClick then
            FriendsFrameAddFriendButton_OnClick()
        end
    end)

    local sendMessage = CreateSimpleButton(footer, 100, 22, LText("Send Message"), "footer")
    sendMessage:SetPoint("RIGHT", -6, 0)
    sendMessage.label:SetFont(ResolveFont(), 10, "OUTLINE")
    sendMessage:SetEnabled(false)
    RefreshButtonStyle(sendMessage)
    sendMessage:SetScript("OnClick", function()
        if runtime.selectedEntry then
            SendWhisperToEntry(runtime.selectedEntry)
        elseif _G.FriendsFrameSendMessageButton and _G.FriendsFrameSendMessageButton.Click then
            _G.FriendsFrameSendMessageButton:Click()
        end
    end)

    local newGroup = CreateSimpleButton(footer, 22, 22, "+", "icon")
    newGroup:SetPoint("CENTER", 0, 0)
    newGroup.label:SetFont(ResolveFont(), 13, "OUTLINE")
    newGroup:SetScript("OnClick", function()
        OpenNewGroupEditor()
    end)

    local navButtons = {}
    local previous = nil
    local buttonWidth = (LAYOUT.windowWidth - (LAYOUT.rootInset * 2) - 16) / #NAV_ORDER
    for index, definition in ipairs(NAV_ORDER) do
        local navButton = self:CreateNavButton(navBar, definition)
        navButton:SetWidth(buttonWidth - 4)
        if previous then
            navButton:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            navButton:SetPoint("LEFT", 8, 0)
        end
        navButton:SetPoint("TOP", 0, -4)
        navButton:SetPoint("BOTTOM", 0, 4)
        navButtons[index] = navButton
        previous = navButton
    end

    self.frame = root
    self.mainPanel = mainPanel
    self.header = header
    self.body = body
    self.footer = footer
    self.navBar = navBar
    self.statusSlot = statusSlot
    self.statusFallback = statusFallback
    self.battleTag = battleTag
    self.optionsButton = optionsButton
    self.closeButton = closeButton
    self.contactsPane = contactsPane
    self.searchBox = searchBox
    self.recentPanel = recentPanel
    self.recruitPanel = recruitPanel
    self.listInset = listInset
    self.scroll = scroll
    self.contactsContent = contactsContent
    self.externalHost = externalHost
    self.addFriendButton = addFriend
    self.sendMessageButton = sendMessage
    self.newGroupButton = newGroup
    self.navButtons = navButtons
    self.iconCard = iconCard
    self.searchBar = searchBox:GetParent()

    runtime.initialized = true
end

function EnhancedFriendList:AttachStatusDropdown()
    local dropdown = _G.FriendsFrameStatusDropDown
        or (GetFriendsFrame() and GetFriendsFrame().StatusDropdown)
        or _G.FriendsFrameStatusDropdown
    if not (dropdown and self.statusSlot) then
        if self.statusFallback then
            self.statusFallback:Show()
        end
        return
    end

    RememberMovedFrame("statusDropdown", dropdown)
    runtime.original.statusDropdownParent = runtime.original.statusDropdownParent or dropdown:GetParent()
    dropdown:SetParent(self.statusSlot)
    dropdown:ClearAllPoints()
    dropdown:SetPoint("TOPLEFT", 4, -4)
    dropdown:SetPoint("BOTTOMRIGHT", -4, 4)
    dropdown:SetScale(1)
    dropdown:SetAlpha(1)
    if dropdown.Button then
        dropdown.Button:ClearAllPoints()
        dropdown.Button:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
        dropdown.Button:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)
        dropdown.Button:SetAlpha(1)
        if dropdown.Button.EnableMouse then
            dropdown.Button:EnableMouse(true)
        end
    end
    dropdown:Show()
    if self.statusFallback then
        self.statusFallback:Hide()
    end
end

function EnhancedFriendList:RestoreStatusDropdown()
    local dropdown = _G.FriendsFrameStatusDropDown
        or (GetFriendsFrame() and GetFriendsFrame().StatusDropdown)
        or _G.FriendsFrameStatusDropdown
    local state = runtime.original.movedFrames.statusDropdown
    if dropdown and runtime.original.statusDropdownParent then
        dropdown:SetParent(runtime.original.statusDropdownParent)
    end
    if dropdown and state then
        RestorePoints(dropdown, state)
        runtime.original.movedFrames.statusDropdown = nil
    end
    runtime.original.statusDropdownParent = nil
    if self.statusFallback then
        self.statusFallback:Hide()
    end
end

function EnhancedFriendList:SetBattleNetHeaderArtHidden(hidden)
    local function SetRegionAlphaState(region)
        if not (region and region.GetObjectType and region:GetObjectType() == "Texture") then
            return
        end

        if hidden then
            if runtime.original.regionAlphaStates[region] == nil then
                runtime.original.regionAlphaStates[region] = region.GetAlpha and region:GetAlpha() or 1
            end
            if region.SetAlpha then
                region:SetAlpha(0)
            end
            return
        end

        local alpha = runtime.original.regionAlphaStates[region]
        if alpha ~= nil then
            if region.SetAlpha then
                region:SetAlpha(alpha)
            end
            runtime.original.regionAlphaStates[region] = nil
        end
    end

    local friendsFrame = GetFriendsFrame()
    local battlenetFrame = friendsFrame and friendsFrame.BattlenetFrame
    local candidates = {
        battlenetFrame,
        battlenetFrame and battlenetFrame.BroadcastFrame or nil,
        _G.FriendsFrameBattlenetFrame,
        _G.FriendsFrameBattlenetFrame and _G.FriendsFrameBattlenetFrame.BroadcastFrame or nil,
    }

    for _, frame in ipairs(candidates) do
        if frame then
            for _, region in ipairs({ frame:GetRegions() }) do
                SetRegionAlphaState(region)
            end
            for _, child in ipairs({ frame:GetChildren() }) do
                for _, region in ipairs({ child:GetRegions() }) do
                    SetRegionAlphaState(region)
                end
            end
        end
    end
end

function EnhancedFriendList:SetNativeFrameArtHidden(hidden)
    local friendsFrame = GetFriendsFrame()
    if not friendsFrame then
        return
    end

    -- FriendsFrame inherits ButtonFrameTemplate. Its portrait surround is
    -- drawn by NineSlice, while the portrait/icon itself lives in separate
    -- regions. Hide the complete native shell, not only FriendsFrameIcon.
    local targets = {
        _G.FriendsFrameIcon,
        friendsFrame.Icon,
        friendsFrame.Portrait,
        friendsFrame.portrait,
        friendsFrame.PortraitContainer,
        friendsFrame.NineSlice,
        friendsFrame.Bg,
        friendsFrame.Background,
        friendsFrame.TopTileStreaks,
        friendsFrame.Border,
        friendsFrame.Inset,
    }
    for _, target in pairs(targets) do
        SetFrameAlphaState(target, hidden)
    end
end

function EnhancedFriendList:SetBaseFrameState(active)
    local friendsFrame = GetFriendsFrame()
    if not friendsFrame then
        return
    end

    if active then
        -- Reapply on every refresh because Blizzard layout code may restore
        -- inherited frame artwork after FriendsFrame has already been shown.
        self:SetNativeFrameArtHidden(true)
        if runtime.baseApplied then
            SetNativeContactsMouse(false)
            self:SetBattleNetHeaderArtHidden(true)
            self:AttachStatusDropdown()
            return
        end
        if not runtime.original.frameSize then
            runtime.original.frameSize = {
                width = friendsFrame:GetWidth(),
                height = friendsFrame:GetHeight(),
            }
        end
        friendsFrame:SetSize(LAYOUT.windowWidth, LAYOUT.windowHeight)

        local targets = {
            friendsFrame.TitleContainer,
            friendsFrame.TitleText,
            friendsFrame.TitleContainer and friendsFrame.TitleContainer.CloseButton or nil,
            friendsFrame.CloseButton,
            _G.FriendsFrameCloseButton,
            _G.FriendsFrameAddFriendButton,
            _G.FriendsFrameSendMessageButton,
            _G.FriendsFrameIgnorePlayerButton,
            _G.FriendsFrameUnsquelchButton,
            _G.FriendsTabHeader,
            _G.FriendsFrameTab1,
            _G.FriendsFrameTab2,
            _G.FriendsFrameTab3,
            _G.FriendsFrameTab4,
            friendsFrame.BattlenetFrame,
            _G.FriendsListFrame,
            friendsFrame.ScrollBox,
            friendsFrame.ScrollBar,
        }
        -- Optional template members leave holes in this table. pairs() is
        -- intentional: ipairs() would stop at the first absent member and
        -- leave later native artwork visible.
        for _, frame in pairs(targets) do
            SetFrameAlphaState(frame, true)
        end
        SetNativeContactsMouse(false)

        if _G.FriendsFrameTab1 then
            for _, tab in ipairs({ _G.FriendsFrameTab1, _G.FriendsFrameTab2, _G.FriendsFrameTab3, _G.FriendsFrameTab4 }) do
                if tab then
                    SetForcedHidden(tab, true)
                end
            end
        end

        SetForcedHidden(friendsFrame.TitleContainer and friendsFrame.TitleContainer.CloseButton or nil, true)
        SetForcedHidden(friendsFrame.CloseButton, true)
        SetForcedHidden(_G.FriendsFrameCloseButton, true)
        SetForcedHidden(_G.FriendsFrameAddFriendButton, true)
        SetForcedHidden(_G.FriendsFrameSendMessageButton, true)
        SetForcedHidden(_G.FriendsFrameIgnorePlayerButton, true)
        SetForcedHidden(_G.FriendsFrameUnsquelchButton, true)

        self:AttachStatusDropdown()
        self:SetBattleNetHeaderArtHidden(true)
        runtime.baseApplied = true
    else
        if runtime.original.frameSize then
            friendsFrame:SetSize(runtime.original.frameSize.width, runtime.original.frameSize.height)
        end

        local restoreList = {}
        for frame in pairs(runtime.original.alphaStates) do
            restoreList[#restoreList + 1] = frame
        end
        for _, frame in ipairs(restoreList) do
            SetFrameAlphaState(frame, false)
        end
        self:SetNativeFrameArtHidden(false)
        SetNativeContactsMouse(true)

        for _, tab in ipairs({ _G.FriendsFrameTab1, _G.FriendsFrameTab2, _G.FriendsFrameTab3, _G.FriendsFrameTab4 }) do
            if tab then
                SetForcedHidden(tab, false)
            end
        end

        SetForcedHidden(friendsFrame.TitleContainer and friendsFrame.TitleContainer.CloseButton or nil, false)
        SetForcedHidden(friendsFrame.CloseButton, false)
        SetForcedHidden(_G.FriendsFrameCloseButton, false)
        SetForcedHidden(_G.FriendsFrameAddFriendButton, false)
        SetForcedHidden(_G.FriendsFrameSendMessageButton, false)
        SetForcedHidden(_G.FriendsFrameIgnorePlayerButton, false)
        SetForcedHidden(_G.FriendsFrameUnsquelchButton, false)

        self:RestoreStatusDropdown()
        self:SetBattleNetHeaderArtHidden(false)
        runtime.baseApplied = false
    end
end

function EnhancedFriendList:AttachExternalFrame(definition)
    if not definition then
        return
    end
    if definition.key ~= "quickjoin" then
        RestoreQuickJoinJoinButton()
    end
    PrepareExternalView(definition)
    local frame = _G[definition.frame]
    if not frame then
        return
    end

    RememberMovedFrame(definition.key, frame)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self.externalHost, "TOPLEFT", 4, -2)
    frame:SetPoint("BOTTOMRIGHT", self.externalHost, "BOTTOMRIGHT", -4, 2)
    if frame.SetFrameStrata and self.externalHost.GetFrameStrata then
        frame:SetFrameStrata(self.externalHost:GetFrameStrata())
    end
    if frame.SetFrameLevel and self.externalHost.GetFrameLevel then
        frame:SetFrameLevel(self.externalHost:GetFrameLevel() + 5)
    end

    HideExternalFrameBackdrop(frame)
    if definition.key == "quickjoin" then
        LayoutQuickJoinMirror(frame)
    elseif definition.key == "who" then
        EnsureWhoMirrorMask(frame)
    end
    UpdateExternalMirrorMasks(definition.key, frame)

    frame:Show()

    if definition.altFrame then
        local altFrame = _G[definition.altFrame]
        if altFrame then
            local wasShown = altFrame:IsShown()
            RememberMovedFrame(definition.key .. ":alt", altFrame)
            if definition.key == "quickjoin" then
                LayoutQuickJoinRoleSelectionMirror(altFrame, self.externalHost)
            else
                altFrame:ClearAllPoints()
                altFrame:SetPoint("BOTTOMRIGHT", self.externalHost, "BOTTOMRIGHT", -8, 10)
            end
            if altFrame.SetFrameStrata and self.externalHost.GetFrameStrata then
                altFrame:SetFrameStrata(self.externalHost:GetFrameStrata())
            end
            if altFrame.SetFrameLevel and self.externalHost.GetFrameLevel then
                altFrame:SetFrameLevel(self.externalHost:GetFrameLevel() + 8)
            end
            HideExternalFrameBackdrop(altFrame)
            if wasShown then
                altFrame:Show()
            else
                altFrame:Hide()
            end
        end
    end

    -- Re-hide Blizzard tabs that may have been re-shown
    for i = 1, 4 do
        local t = _G["FriendsFrameTab" .. i]
        if t then t:Hide() end
    end
end

function EnhancedFriendList:RestoreExternalFrames()
    RestoreQuickJoinJoinButton()
    for _, definition in ipairs(NAV_ORDER) do
        if definition.key ~= "contacts" then
            local frame = _G[definition.frame]
            local state = runtime.original.movedFrames[definition.key]
            if frame and state then
                frame:Hide()
                if frame._eflWhoMask then
                    frame._eflWhoMask:Hide()
                end
                RestorePoints(frame, state)
                RestoreExternalFrameBackdrop(frame)
                runtime.original.movedFrames[definition.key] = nil
            end

            if definition.altFrame then
                local altFrame = _G[definition.altFrame]
                local altState = runtime.original.movedFrames[definition.key .. ":alt"]
                if altFrame and altState then
                    altFrame:Hide()
                    RestorePoints(altFrame, altState)
                    RestoreExternalFrameBackdrop(altFrame)
                    runtime.original.movedFrames[definition.key .. ":alt"] = nil
                end
            end
        end
    end
end

function EnhancedFriendList:RefreshNavState(activeView)
    if not self.navButtons then
        return
    end

    for _, button in ipairs(self.navButtons) do
        local selected = button.definition and button.definition.key == activeView
        button._eflSelected = selected
        RefreshButtonStyle(button)
    end
end

function EnhancedFriendList:RefreshSelection()
    if not self.groups then
        return
    end

    for _, group in ipairs(self.groups) do
        if group and group.rows then
            for _, row in ipairs(group.rows) do
                if row and row.entry then
                    local isSelected = runtime.selectedEntry and row.entry and runtime.selectedEntry.id == row.entry.id
                    if isSelected then
                        local ar, ag, ab = AccentColor(0.18)
                        row.selection:SetColorTexture(ar, ag, ab, 0.18)
                    else
                        row.selection:SetColorTexture(1, 1, 1, 0)
                    end
                end
            end
        end
    end

    if self.sendMessageButton and self.sendMessageButton.label then
        local enabled = runtime.selectedEntry ~= nil and CanWhisperEntry(runtime.selectedEntry)
        local label = enabled and LText("Send Message") or (runtime.selectedEntry and LText("Send Message") or LText("Select Friend"))
        self.sendMessageButton.label:SetText(label)
        self.sendMessageButton:SetEnabled(enabled)
        self.sendMessageButton:SetAlpha(enabled and 1 or 0.78)
        RefreshButtonStyle(self.sendMessageButton)
    end
end

function EnhancedFriendList:FindRowByEntryID(entryID)
    if not (entryID and self.groups) then
        return nil
    end

    for _, group in ipairs(self.groups) do
        if group and group.rows then
            for _, row in ipairs(group.rows) do
                if row and row.entry and row.entry.id == entryID and row:IsShown() then
                    return row
                end
            end
        end
    end

    return nil
end

function EnhancedFriendList:ScrollRowIntoView(row)
    if not (row and self.scroll and self.contactsContent) then
        return
    end

    local childTop = self.contactsContent:GetTop()
    local rowTop = row:GetTop()
    local rowBottom = row:GetBottom()
    local viewportHeight = self.scroll:GetHeight() or 0
    if not (childTop and rowTop and rowBottom and viewportHeight > 0) then
        return
    end

    local rowOffsetTop = childTop - rowTop
    local rowOffsetBottom = childTop - rowBottom
    local currentScroll = self.scroll:GetVerticalScroll() or 0
    local maxScroll = math.max(0, (self.contactsContent:GetHeight() or 0) - viewportHeight)

    if rowOffsetTop < currentScroll then
        self.scroll:SetVerticalScroll(math.max(0, rowOffsetTop - 6))
    elseif rowOffsetBottom > (currentScroll + viewportHeight) then
        self.scroll:SetVerticalScroll(math.min(maxScroll, rowOffsetBottom - viewportHeight + 6))
    end
end

function EnhancedFriendList:ToggleRecentAlliesView()
    if runtime.contactsSubView == "recentAllies" then
        runtime.contactsSubView = nil
        self:Refresh()
        return
    end

    runtime.contactsSubView = "recentAllies"
    local dataset = runtime.cachedDataset
    local firstEntry = dataset and dataset.recentAllies and dataset.recentAllies[1] or nil
    runtime.selectedEntry = firstEntry or nil
    self:Refresh()

    if firstEntry then
        local row = self:FindRowByEntryID(firstEntry.id)
        if row then
            self:ScrollRowIntoView(row)
        end
    end
end

function EnhancedFriendList:RefreshContacts(dataset)
    if not (self.contactsPane and self.contactsContent and dataset) then
        return
    end

    if runtime.dragEntry then
        ClearFriendDragState()
    end

    local allies = {}
    for index = 1, math.min(#dataset.recentAllies, 3) do
        allies[#allies + 1] = dataset.recentAllies[index].name
    end
    self.recentPanel.title:SetText(LText("Recent Allies"))
    if #allies > 0 then
        self.recentPanel.summary:SetText(string.format(LText("%d online"), #dataset.recentAllies))
    else
        self.recentPanel.summary:SetText(string.format(LText("%d online"), 0))
    end
    self.recentPanel._eflSelected = (runtime.contactsSubView == "recentAllies")
    RefreshSummaryPanelState(self.recentPanel)
    self.recruitPanel.summary:SetText("")
    self.recruitPanel._eflSelected = false
    RefreshSummaryPanelState(self.recruitPanel)
    local contentWidth = math.max(1, self.listInset:GetWidth() - 42)
    self.contactsContent:SetWidth(contentWidth)

    -- Filtro de búsqueda
    local searchQuery = self.searchBox and strlower(self.searchBox:GetText() or "") or ""
    if searchQuery == "" then searchQuery = nil end

    local sections = dataset.sections or {}
    if runtime.contactsSubView == "recentAllies" then
        if #dataset.recentAllies > 0 then
            sections = {
                { title = LText("Recent Allies"), entries = dataset.recentAllies },
            }
        else
            sections = {
                {
                    title = LText("Recent Allies"),
                    entries = {
                        {
                            id = "recent-empty",
                            kind = "system",
                            line1 = LText("No recent allies online."),
                            line2 = LText("Recent allies will appear here when they are available."),
                            detail = "",
                            online = false,
                            statusKey = "offline",
                            sortName = "zz",
                        },
                    },
                },
            }
        end
    end

    local currentY = 0
    for sectionIndex, section in ipairs(sections) do
        local group = self:AcquireGroup(sectionIndex)
        local sectionKey = section.title or ("section" .. sectionIndex)
        group._sectionKey = sectionKey
        local collapsed = runtime.collapsedSections[sectionKey] and true or false

        -- Filtrar entradas por búsqueda
        local filteredEntries = section.entries or {}
        if searchQuery then
            filteredEntries = {}
            for _, entry in ipairs(section.entries or {}) do
                local haystack = strlower((entry.line1 or "") .. " " .. (entry.line2 or "") .. " " .. (entry.accountName or "") .. " " .. (entry.characterName or ""))
                if strfind(haystack, searchQuery, 1, true) then
                    filteredEntries[#filteredEntries + 1] = entry
                end
            end
        end

        local entryCount = #filteredEntries
        local groupHeight
        if collapsed then
            groupHeight = (LAYOUT.groupPadding * 2) + LAYOUT.groupHeaderHeight
        else
            groupHeight = (LAYOUT.groupPadding * 2) + LAYOUT.groupHeaderHeight
            if entryCount > 0 then
                groupHeight = groupHeight + (entryCount * LAYOUT.rowHeight) + ((entryCount - 1) * LAYOUT.rowGap)
            end
        end

        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", 0, -currentY)
        group:SetWidth(contentWidth)
        group:SetHeight(groupHeight)
        group:Show()

        group.title:SetText(section.title or LText("Friends"))
        group.count:SetText(string.format("%d", entryCount))

        -- Show/hide delete button for custom groups
        group._customGroupName = section.groupName or nil
        if section.isCustomGroup and group.header.deleteBtn then
            group.header.deleteBtn:Show()
        elseif group.header.deleteBtn then
            group.header.deleteBtn:Hide()
        end

        -- Update arrow indicator
        if group.header.arrow then
            if collapsed then
                -- Rotate 90° clockwise: point right
                group.header.arrow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
            else
                -- Normal: point down
                group.header.arrow:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
            end
        end

        if not collapsed then
            for entryIndex, entry in ipairs(filteredEntries) do
            local row = self:AcquireRow(group, entryIndex)
            row.entry = entry
            row.invite.entry = entry
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", LAYOUT.groupPadding, -(LAYOUT.groupHeaderHeight + LAYOUT.groupPadding + ((entryIndex - 1) * (LAYOUT.rowHeight + LAYOUT.rowGap))))
            row:SetPoint("TOPRIGHT", -LAYOUT.groupPadding, -(LAYOUT.groupHeaderHeight + LAYOUT.groupPadding + ((entryIndex - 1) * (LAYOUT.rowHeight + LAYOUT.rowGap))))
            row:Show()

            row.title:SetText(entry.line1 or "")
            if row.note then
                if entry.noteText and entry.noteText ~= "" then
                    row.note:SetText("[" .. entry.noteText .. "]")
                    row.note:Show()
                else
                    row.note:SetText("")
                    row.note:Hide()
                end
            end
            row.subtitle:SetText(entry.line2 or "")
            row.detail:SetText(entry.detail or "")
            local sr, sg, sb = GetStatusColor(entry)
            row.status:SetColorTexture(sr, sg, sb, 1)
            local classR, classG, classB = nil, nil, nil
            if entry.classColor and entry.classColor[1] then
                classR, classG, classB = entry.classColor[1], entry.classColor[2], entry.classColor[3]
            end
            if classR then
                ApplySectionStyle(row, 0.98, 0.92)
                SetOutlineColor(row, classR, classG, classB, 0.75)
                row.classTint:SetColorTexture(classR, classG, classB, 0.07)
                row.accentEdge:SetColorTexture(classR, classG, classB, 0.90)
                ApplyTextureGradient(row.accentGlow, "HORIZONTAL",
                    classR, classG, classB, 0.12,
                    classR, classG, classB, 0)
                row.accentEdge:Show()
                row.accentGlow:Show()
                ApplyInsetStyle(row.iconBox, 1)
                SetOutlineColor(row.iconBox, classR, classG, classB, 0.75)
                row.detail:SetTextColor(classR, classG, classB, 1)
                if row.iconGlow then
                    ApplyTextureGradient(row.iconGlow, "VERTICAL", classR, classG, classB, 0, classR, classG, classB, 0.30)
                end
            else
                local rr, rg, rb = AccentColor()
                ApplySectionStyle(row, 0.98, 0.9)
                SetOutlineColor(row, 0.18, 0.18, 0.22, 0.9)
                row.classTint:SetColorTexture(1, 1, 1, 0)
                row.accentEdge:SetColorTexture(rr, rg, rb, 0.65)
                ApplyTextureGradient(row.accentGlow, "HORIZONTAL",
                    rr, rg, rb, 0.08,
                    rr, rg, rb, 0)
                row.accentEdge:Show()
                row.accentGlow:Show()
                ApplyInsetStyle(row.iconBox, 1)
                SetOutlineColor(row.iconBox, 0.16, 0.16, 0.20, 0.92)
                row.detail:SetTextColor(rr, rg, rb, 1)
                if row.iconGlow then
                    ApplyTextureGradient(row.iconGlow, "VERTICAL", rr, rg, rb, 0, rr, rg, rb, 0.30)
                end
            end

            if entry.hasClassIcon and entry.classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[entry.classFile] then
                local coords = CLASS_ICON_TCOORDS[entry.classFile]
                row.icon:SetTexture(CLASS_ICON)
                row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                row.icon:SetSize(38, 38)
            else
                row.icon:SetTexture((entry.kind == "bnet" or entry.kind == "invite") and "Interface\\FriendsFrame\\PlusManz-BattleNet" or FRIEND_ICON)
                row.icon:SetTexCoord(0, 1, 0, 1)
                row.icon:SetSize(34, 34)
            end

            local factionIcon = GetFactionIcon(entry)
            row.factionIcon:ClearAllPoints()
            if entry.wowProjectTexture then
                row.projectIcon:SetTexture(entry.wowProjectTexture)
                local projectColor = entry.wowProjectColor or { 1, 1, 1, 1 }
                if row.projectIcon.SetDesaturated then
                    row.projectIcon:SetDesaturated(entry.wowProjectColor ~= nil)
                end
                row.projectIcon:SetVertexColor(projectColor[1], projectColor[2], projectColor[3], projectColor[4] or 1)
                if entry.wowProjectCustomTexture then
                    row.projectIcon:SetTexCoord(0, 1, 0, 1)
                else
                    row.projectIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
                row.projectIconFrame.projectLabel = entry.wowProjectLabel
                row.projectIconFrame:Show()
                row.factionIcon:SetPoint("RIGHT", row.projectIconFrame, "LEFT", -4, 0)
            else
                if row.projectIcon.SetDesaturated then row.projectIcon:SetDesaturated(false) end
                row.projectIcon:SetVertexColor(1, 1, 1, 1)
                row.projectIconFrame.projectLabel = nil
                row.projectIconFrame:Hide()
                row.factionIcon:SetPoint("RIGHT", row.menuButton, "LEFT", -4, 0)
            end
            if factionIcon then
                row.factionIcon:SetTexture(factionIcon)
                row.factionIcon:Show()
            else
                row.factionIcon:Hide()
            end

            local canPrimaryAction = CanPrimaryActionEntry(entry)
            local primaryActionLabel = GetPrimaryActionLabel(entry)
            row.invite:SetShown(canPrimaryAction)
            row.invite:SetEnabled(canPrimaryAction)
            row.invite:SetAlpha(canPrimaryAction and 1 or 0.6)
            row.invite:SetWidth(GetPrimaryActionWidth(entry))
            row.invite.label:SetText(primaryActionLabel)
            row.invite.label:SetFont(ResolveFont(), primaryActionLabel == "+" and 13 or 8, "OUTLINE")
            row.invite.label:SetShown(primaryActionLabel ~= "+")
            row.inviteIcon:SetShown(primaryActionLabel == "+")
            RefreshButtonStyle(row.invite)
            if primaryActionLabel == '+' then
                local inviteR, inviteG, inviteB = AccentColor()
                row.inviteIcon:SetTexture(INVITE_ICON)
                if row.inviteIcon.SetDesaturated then
                    row.inviteIcon:SetDesaturated(true)
                end
                row.inviteIcon:SetBlendMode('ADD')
                row.inviteIcon:SetVertexColor(inviteR, inviteG, inviteB, 1)
                row.inviteIcon:SetAlpha(canPrimaryAction and 1 or 0.55)
                row.inviteIcon:Show()
            end
            row.menuButton:SetShown(entry.kind ~= "system")
            row.menuButton:SetEnabled(entry.kind ~= "system")
            if row.menuButton.arrow then
                local rr, rg, rb = AccentColor()
                row.menuButton.arrow:SetVertexColor(rr, rg, rb, entry.kind ~= "system" and 0.82 or 0.36)
            end
            RefreshButtonStyle(row.menuButton)
        end
        end -- if not collapsed

        local hideStart = collapsed and 1 or (entryCount + 1)
        for hideIndex = hideStart, #(group.rows or {}) do
            if group.rows[hideIndex] then
                group.rows[hideIndex].entry = nil
                group.rows[hideIndex]:Hide()
            end
        end

        currentY = currentY + groupHeight + LAYOUT.groupGap
    end

    for hideIndex = #sections + 1, #(self.groups or {}) do
        if self.groups[hideIndex] then
            self.groups[hideIndex]:Hide()
        end
    end

    self.contactsContent:SetHeight(math.max(self.scroll:GetHeight(), currentY + 4))
    self:RefreshSelection()
end

function EnhancedFriendList:RefreshView(dataset)
    if not self.frame then
        return
    end

    local activeView = GetActiveView()
    runtime.selectedView = activeView

    self.frame:Show()
    self.battleTag:SetText(dataset and dataset.battleTag or GetBNetDisplayText())
    self:RefreshNavState(activeView)

    if activeView == "contacts" then
        self.externalHost:Hide()
        self.contactsPane:Show()
        self.footer:Show()
        self:RestoreExternalFrames()
        self:RefreshContacts(dataset)
        return
    end

    self.contactsPane:Hide()
    self.footer:Hide()
    self.externalHost:Show()
    self:AttachExternalFrame(FindNavDefinition(activeView))
end

function EnhancedFriendList:Disable()
    if self.frame then
        self.frame:Hide()
    end
    if runtime.optionMenu then
        runtime.optionMenu:Hide()
    end
    self:SetBaseFrameState(false)
    self:RestoreExternalFrames()
    runtime.cachedDataset = nil
    runtime.dataDirty = true
    runtime.selectedEntry = nil
end

function EnhancedFriendList:RefreshTheme()
    if not self.frame then return end

    local ar, ag, ab = AccentColor()
    local root = self.frame

    -- ── Re-apply surface styles on all structural frames ──────────
    ApplyShellStyle(root, 0.985)
    if self.mainPanel then ApplyShellStyle(self.mainPanel, 0.965) end
    if self.header then ApplySectionStyle(self.header, 0.98, 0.9) end
    if self.body then ApplySectionStyle(self.body, 0.96, 0.9) end
    if self.footer then ApplySectionStyle(self.footer, 0.97, 0.9) end
    if self.navBar then ApplySectionStyle(self.navBar, 0.98, 0.9) end
    if self.iconCard then ApplyInsetStyle(self.iconCard, 1) end
    if self.statusSlot then ApplyInsetStyle(self.statusSlot, 1) end
    if self.searchBar then ApplyInsetStyle(self.searchBar, 1) end
    if self.recentPanel then ApplySectionStyle(self.recentPanel, 0.98, 0.9) end
    if self.recruitPanel then ApplySectionStyle(self.recruitPanel, 0.98, 0.9) end
    RefreshSummaryPanelState(self.recentPanel)
    RefreshSummaryPanelState(self.recruitPanel)
    if self.listInset then ApplyInsetStyle(self.listInset, 0.98) end

    -- ── Root decorations ──────────────────────────────────────────
    if root.bottomGlow then
        ApplyTextureGradient(root.bottomGlow, "VERTICAL", ar, ag, ab, 0.07, ar, ag, ab, 0)
    end
    if root.topEdge then
        ApplyTextureGradient(root.topEdge, "HORIZONTAL", ar, ag, ab, 0.85, ar, ag, ab, 0.08)
    end
    if root.leftEdge then
        ApplyTextureGradient(root.leftEdge, "VERTICAL", ar, ag, ab, 0.10, ar, ag, ab, 0.50)
    end

    -- ── Header icon + glow ────────────────────────────────────────
    if self._headerIcon then
        self._headerIcon:SetVertexColor(ar, ag, ab, 1)
    end
    if self._iconGlow then
        self._iconGlow:SetVertexColor(ar, ag, ab, 0.55)
    end

    -- ── Scrollbar thumb + glow ────────────────────────────────────
    if self._scrollThumb then
        self._scrollThumb:SetColorTexture(ar, ag, ab, 0.88)
    end
    if self._scrollThumbGlow then
        self._scrollThumbGlow:SetColorTexture(ar, ag, ab, 0.16)
    end
    if self._scrollTrack then
        local tr, tg, tb, er, eg, eb = ScrollbarColors()
        self._scrollTrack:SetColorTexture(tr, tg, tb, 0.88)
        if self._scrollTrackLeft then
            self._scrollTrackLeft:SetColorTexture(er, eg, eb, 0.75)
        end
        if self._scrollTrackRight then
            self._scrollTrackRight:SetColorTexture(er, eg, eb, 0.75)
        end
    end

    -- ── Group headers ─────────────────────────────────────────────
    if self.groups then
        for _, group in ipairs(self.groups) do
            if group and group.header then
                if group.header.accent then
                    group.header.accent:SetColorTexture(ar, ag, ab, 0.85)
                end
                if group.header.arrow then
                    group.header.arrow:SetVertexColor(ar, ag, ab, 0.85)
                end
                if group.header.deleteBtn and group.header.deleteBtn.icon then
                    group.header.deleteBtn.icon:SetVertexColor(0.92, 0.28, 0.28, 0.92)
                end
            end
        end
    end

    -- ── Nav buttons ───────────────────────────────────────────────
    if self.navButtons then
        for _, button in ipairs(self.navButtons) do
            RefreshButtonStyle(button)
        end
    end

    -- ── Footer buttons ────────────────────────────────────────────
    if self.addFriendButton then RefreshButtonStyle(self.addFriendButton) end
    if self.sendMessageButton then RefreshButtonStyle(self.sendMessageButton) end
    if self.newGroupButton then RefreshButtonStyle(self.newGroupButton) end
    if self.optionsButton then RefreshButtonStyle(self.optionsButton) end
    if self.closeButton then RefreshButtonStyle(self.closeButton) end

    -- ── Row icon glows and accent edges recolored during RefreshContacts ──
    runtime.dataDirty = true
    if self.frame:IsShown() then
        self:RequestRefresh(true)
    end
end

function EnhancedFriendList:RequestRefresh(force)
    if force then
        runtime.forcePending = false
        runtime.refreshScheduled = false
        self:Refresh(true)
        return
    end

    if runtime.refreshScheduled then
        return
    end

    runtime.refreshScheduled = true
    C_Timer.After(runtime.refreshDelay or 0.08, function()
        runtime.refreshScheduled = false
        local wantsForce = runtime.forcePending
        runtime.forcePending = false

        if not EnhancedFriendList or not EnhancedFriendList.Refresh then
            return
        end

        EnhancedFriendList:Refresh(wantsForce)
    end)
end

function EnhancedFriendList:InstallHooks()
    if runtime.hooksInstalled then
        return
    end

    local friendsFrame = GetFriendsFrame()
    if not friendsFrame then
        return
    end

    friendsFrame:HookScript("OnShow", function()
        if EnhancedFriendList and EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh(true)
        end
    end)
    friendsFrame:HookScript("OnHide", function()
        if runtime.optionMenu then
            runtime.optionMenu:Hide()
        end
    end)

    for _, definition in ipairs(NAV_ORDER) do
        local tab = _G[definition.tab]
        if tab then
            tab:HookScript("OnClick", function()
                runtime.selectedView = definition.key
                if EnhancedFriendList and EnhancedFriendList.RequestRefresh then
                    EnhancedFriendList:RequestRefresh()
                end
            end)
        end
    end

    runtime.hooksInstalled = true
end

function EnhancedFriendList:EnsureEventFrame()
    if runtime.eventFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            self:OnAddonLoaded(...)
            return
        end

        if not ShouldUseCustomList() then
            return
        end

        runtime.dataDirty = true

        local friendsFrame = GetFriendsFrame()
        if friendsFrame and friendsFrame:IsShown() and EnhancedFriendList and EnhancedFriendList.RequestRefresh then
            EnhancedFriendList:RequestRefresh()
        end
    end)

    for _, eventName in ipairs({
        "ADDON_LOADED",
        "FRIENDLIST_UPDATE",
        "BN_FRIEND_ACCOUNT_ONLINE",
        "BN_FRIEND_ACCOUNT_OFFLINE",
        "BN_FRIEND_INFO_CHANGED",
        "BN_FRIEND_INVITE_ADDED",
        "BN_FRIEND_INVITE_REMOVED",
        "BN_FRIEND_INVITE_LIST_INITIALIZED",
        "BN_CONNECTED",
        "BN_DISCONNECTED",
    }) do
        frame:RegisterEvent(eventName)
    end

    runtime.eventFrame = frame
end

function EnhancedFriendList:OnAddonLoaded(loadedAddon)
    if loadedAddon and loadedAddon ~= "Blizzard_FriendsFrame" then
        return
    end

    if GetFriendsFrame() then
        self:RegisterChatCommands()
        self:CreateFrame()
        self:InstallHooks()
        if ShouldUseCustomList() then
            self:SetBaseFrameState(true)
            if self.frame then
                self.frame:Hide()
            end
            if GetFriendsFrame():IsShown() then
                self:RequestRefresh(true)
            end
        end

        -- Hook KUI style palette refresh to update accent colors
        if not runtime.themeHooked and KT and KT.RefreshStylePalette then
            hooksecurefunc(KT, "RefreshStylePalette", function()
                if EnhancedFriendList.RefreshTheme then
                    EnhancedFriendList:RefreshTheme()
                end
            end)
            runtime.themeHooked = true
        end
    end
end

function EnhancedFriendList:Refresh(force)
    self:EnsureEventFrame()
    self:RegisterChatCommands()

    -- Ensure theme hook is registered (may not have fired via OnAddonLoaded)
    if not runtime.themeHooked and KT and KT.RefreshStylePalette then
        hooksecurefunc(KT, "RefreshStylePalette", function()
            if EnhancedFriendList.RefreshTheme then
                EnhancedFriendList:RefreshTheme()
            end
        end)
        runtime.themeHooked = true
    end

    if not ShouldUseCustomList() then
        self:Disable()
        return
    end

    local friendsFrame = GetFriendsFrame()
    if not friendsFrame then
        return
    end

    self:CreateFrame()
    self:InstallHooks()
    if not self.frame then
        return
    end

    if not force and not friendsFrame:IsShown() then
        return
    end

    local activeView = GetActiveView()
    if activeView == "raid" then
        -- Keep Blizzard's protected raid roster entirely in its native host.
        -- Reanchoring or showing it from addon code taints later roster events,
        -- which can block RaidGroupN:Show() during combat.
        self.frame:Hide()
        self:SetBaseFrameState(false)
        self:RestoreExternalFrames()
        return
    end

    self:SetBaseFrameState(true)
    local dataset = nil
    if activeView == "contacts" then
        if force or runtime.dataDirty or not runtime.cachedDataset then
            runtime.cachedDataset = self:BuildDataset()
            runtime.dataDirty = false
        end
        dataset = runtime.cachedDataset
        if runtime.selectedEntry and runtime.selectedEntry.id then
            local selectionFound = false
            for _, section in ipairs(dataset.sections or {}) do
                for _, entry in ipairs(section.entries or {}) do
                    if entry.id == runtime.selectedEntry.id then
                        selectionFound = true
                        break
                    end
                end
                if selectionFound then
                    break
                end
            end
            if not selectionFound then
                runtime.selectedEntry = nil
            end
        end
    else
        dataset = {
            battleTag = GetBNetDisplayText(),
            recentAllies = {},
            sections = {},
        }
    end
    self:RefreshView(dataset)
end
