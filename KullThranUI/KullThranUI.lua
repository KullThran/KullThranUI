local addonName, ns = ...

local LibStub = LibStub
local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
if not AceAddon then
    error("KullThranUI: AceAddon-3.0 is required.")
    return
end

local KT = AceAddon:GetAddon("KullThranUI", true)
if not KT then
    KT = AceAddon:NewAddon(
        "KullThranUI",
        "AceConsole-3.0",
        "AceEvent-3.0",
        "AceHook-3.0",
        "AceTimer-3.0"
    )
end

ns.KT = KT
_G.KT = KT
_G.KullThranUI = KT
_G.KT_NS = ns
_G.KullThranUI_NS = ns

-- Register these aliases during the core addon load, before the optional
-- Installer module is loaded. The handler itself loads the module on demand.
local function KullThranUIInstallerSlash()
    if KT and KT.OpenInstaller then
        KT:OpenInstaller()
    end
end
SLASH_KULLTHRANUIINSTALLER1 = "/installer"
SLASH_KULLTHRANUIINSTALLER2 = "/ins"
SLASH_KULLTHRANUIINSTALLER3 = "/installers"
SlashCmdList["KULLTHRANUIINSTALLER"] = KullThranUIInstallerSlash

local LSM = LibStub("LibSharedMedia-3.0", true)
local ButtonGlow = LibStub("LibButtonGlow-1.0", true)
local unpack = unpack or table.unpack
local max = math.max
local min = math.min
local floor = math.floor
local abs = math.abs
local hooksecurefunc = _G.hooksecurefunc

KT.VERSION = KT.VERSION
    or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
		or "5.0.7"
-- When loaded directly from the source tree (without the BigWigs packager),
-- GetAddOnMetadata returns the literal "@project-version@" token.  Strip it
-- so the in-game UI never displays the raw packager placeholder.
if KT.VERSION and KT.VERSION:find("@", 1, true) then
    KT.VERSION = "5.0.7"
end

function KT:IsBlizzardEditModeActive()
    local frame = _G.EditModeManagerFrame
    if not frame then
        return false
    end

    if frame.IsEditModeActive and frame:IsEditModeActive() then
        return true
    end

    return frame.IsShown and frame:IsShown() or false
end

function KT:IsBlizzardEditModeTransitionActive()
    return self:IsBlizzardEditModeActive()
end

-- Ensure debug output is visible even when chat addons hide the default chat frame.
do
    if KT and KT.Print and not KT._KT_OrigPrint then
        KT._KT_OrigPrint = KT.Print

        local function formatArgs(...)
            local n = select("#", ...)
            if n == 0 then
                return ""
            end
            if n == 1 then
                return tostring(...)
            end
            local parts = {}
            for i = 1, n do
                parts[i] = tostring(select(i, ...))
            end
            return table.concat(parts, " ")
        end

        local function getVisibleChatFrame()
            local defaultFrame = _G.DEFAULT_CHAT_FRAME
            if defaultFrame and defaultFrame.IsShown and defaultFrame:IsShown() then
                return defaultFrame
            end

            local num = _G.NUM_CHAT_WINDOWS or 0
            for i = 1, num do
                local frame = _G["ChatFrame" .. i]
                if frame and frame.AddMessage and frame.IsShown and frame:IsShown() then
                    return frame
                end
            end

            if defaultFrame and defaultFrame.AddMessage then
                return defaultFrame
            end

            return nil
        end

        function KT:Print(...)
            local msg = formatArgs(...)

            -- Prefer KT's Chat module if it owns the chat UI (it hides Blizzard chat frames).
            if false and not self._KT_PrintingToChatModule and self.GetModule then
                local chat = self:GetModule("Chat", true)
                if chat and chat.OnChatEvent then
                    self._KT_PrintingToChatModule = true
                    local ok = pcall(chat.OnChatEvent, chat, "CHAT_MSG_SYSTEM", msg)
                    self._KT_PrintingToChatModule = false
                    if ok then
                        return
                    end
                end
            end

            -- Prefer Blizzard system chat dispatchers when available.
            if false and _G.ChatFrame_DisplaySystemMessageInPrimary then
                _G.ChatFrame_DisplaySystemMessageInPrimary(msg)
                return
            end
            if false and _G.ChatFrame_DisplaySystemMessageInAllTabs then
                _G.ChatFrame_DisplaySystemMessageInAllTabs(msg)
                return
            end

            local frame = getVisibleChatFrame()
            if frame and frame.AddMessage then
                frame:AddMessage(msg)
                return
            end
            if _G.UIErrorsFrame and _G.UIErrorsFrame.AddMessage then
                _G.UIErrorsFrame:AddMessage(msg, 1, 1, 1, 1)
                return
            end
            if _G.RaidNotice_AddMessage and _G.RaidWarningFrame and _G.ChatTypeInfo and _G.ChatTypeInfo.RAID_WARNING then
                _G.RaidNotice_AddMessage(_G.RaidWarningFrame, msg, _G.ChatTypeInfo.RAID_WARNING)
            end
        end

        local function normalizeDebugScope(scope)
            if type(scope) ~= "string" or scope == "" then
                return "Debug"
            end
            return scope
        end

        local function buildDebugPrefix(scope, colorHex)
            local resolvedScope = normalizeDebugScope(scope)
            local resolvedColor = type(colorHex) == "string" and colorHex ~= "" and colorHex or "00C8FF"
            return string.format("|cff%s[%s]|r", resolvedColor, resolvedScope)
        end

        function KT:SendToChat(...)
            self:Print(...)
            return true
        end

        function KT:DebugPrint(scope, ...)
            local msg = formatArgs(...)
            self:Print(buildDebugPrefix(scope) .. (msg ~= "" and (" " .. msg) or ""))
            return true
        end

        function KT:DebugPrintIf(enabled, scope, ...)
            if not enabled then
                return false
            end
            return self:DebugPrint(scope, ...)
        end

        function KT:DebugPrintOnce(key, scope, ...)
            if key == nil or key == "" then
                return self:DebugPrint(scope, ...)
            end

            self._ktDebugOnceKeys = self._ktDebugOnceKeys or {}
            if self._ktDebugOnceKeys[key] then
                return false
            end

            self._ktDebugOnceKeys[key] = true
            return self:DebugPrint(scope, ...)
        end

        function KT:ResetDebugOnce(key)
            if not self._ktDebugOnceKeys then
                return
            end

            if key == nil then
                wipe(self._ktDebugOnceKeys)
                return
            end

            self._ktDebugOnceKeys[key] = nil
        end

        local publicAddon = _G.KullThranUI or _G.KT or KT
        publicAddon.SendToChat = function(first, second, third, fourth, fifth)
            if type(first) == "table" and second ~= nil then
                return KT:SendToChat(second, third, fourth, fifth)
            end
            return KT:SendToChat(first, second, third, fourth)
        end
        publicAddon.ChatDebug = function(first, second, ...)
            if type(first) == "table" then
                return KT:DebugPrint(second, ...)
            end
            return KT:DebugPrint(first, second, ...)
        end
        publicAddon.ChatDebugIf = function(first, second, third, ...)
            if type(first) == "table" then
                return KT:DebugPrintIf(second, third, ...)
            end
            return KT:DebugPrintIf(first, second, third, ...)
        end
        publicAddon.ChatDebugOnce = function(first, second, third, ...)
            if type(first) == "table" then
                return KT:DebugPrintOnce(second, third, ...)
            end
            return KT:DebugPrintOnce(first, second, third, ...)
        end
        publicAddon.ResetChatDebugOnce = function(first, second)
            if type(first) == "table" then
                return KT:ResetDebugOnce(second)
            end
            return KT:ResetDebugOnce(first)
        end
    end
end
KT.DEFAULT_FONT_NAME = KT.DEFAULT_FONT_NAME or "AAA_ITC_Avant_Garde"
KT.DEFAULT_FONT_PATH = KT.DEFAULT_FONT_PATH or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
KT.FALLBACK_FONT_PATH = KT.FALLBACK_FONT_PATH or "Fonts\\FRIZQT__.TTF"

-- OFL-licensed CJK fonts bundled with the addon. The Blizzard native CJK fonts
-- (Fonts\2002.TTF etc.) only exist on the matching client, so these guarantee
-- readable glyphs when a non-Latin language is selected on a Western client.
KT.BUNDLED_KO_FONT = KT.BUNDLED_KO_FONT or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\NotoSansKR.ttf"
KT.BUNDLED_ZHCN_FONT = KT.BUNDLED_ZHCN_FONT or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\NotoSansSC.ttf"
KT.BUNDLED_ZHTW_FONT = KT.BUNDLED_ZHTW_FONT or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\NotoSansTC.ttf"

local BUNDLED_FONT_FOR_LOCALE = {
    koKR = KT.BUNDLED_KO_FONT,
    zhCN = KT.BUNDLED_ZHCN_FONT,
    zhTW = KT.BUNDLED_ZHTW_FONT,
}

local function GetLocalizedFontPathSafe(langOverride)
    -- Accept both direct calls (default) and accidental colon calls so this works
    -- with KT:GetLocalizedFontPathSafe(...) too.
    if type(langOverride) ~= "string" then
        langOverride = nil
    end
    local clientLoc = _G.GetLocale and _G.GetLocale()
    local loc = langOverride or clientLoc

    -- Native Blizzard font shipped with each localized client.
    local native = nil
    if loc == "koKR" then native = "Fonts\\2002.TTF"
    elseif loc == "zhTW" then native = "Fonts\\bKAI00M.TTF"
    elseif loc == "zhCN" then native = "Fonts\\ARKai_T.TTF"
    elseif loc == "ruRU" then native = "Fonts\\FRIZQT___CYR.TTF" end

    if native then
        -- FRIZQT___CYR ships with every WoW client, so Cyrillic always works.
        -- The CJK fonts only exist on their matching clients; for any other
        -- client fall back to the bundled OFL font below.
        if loc == "ruRU" or clientLoc == loc then
            return native
        end
        local bundled = BUNDLED_FONT_FOR_LOCALE[loc]
        if bundled then
            return bundled
        end
    end

    if type(_G.STANDARD_TEXT_FONT) == "string" and _G.STANDARD_TEXT_FONT ~= "" then
        return _G.STANDARD_TEXT_FONT
    elseif _G.StandardTextFont and _G.StandardTextFont.GetFont then
        local p = _G.StandardTextFont:GetFont()
        if type(p) == "string" and p ~= "" then
            return p
        end
    end
    return "Fonts\\FRIZQT__.TTF"
end

KT.GetLocalizedFontPathSafe = GetLocalizedFontPathSafe

KT.LOCALIZED_FONT_NAME = KT.LOCALIZED_FONT_NAME or "Standard Text Font"
KT.LOCALIZED_FONT_PATH = KT.LOCALIZED_FONT_PATH or GetLocalizedFontPathSafe()
KT.CYRILLIC_FONT_NAME = KT.CYRILLIC_FONT_NAME or "Russo One"
KT.CYRILLIC_FONT_PATH = KT.CYRILLIC_FONT_PATH
    or "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Russo One.ttf"

function KT:GetActiveLanguage()
    if self.db and self.db.profile and self.db.profile.language and self.db.profile.language ~= "auto" then
        return self.db.profile.language
    end
    return _G.GetLocale and _G.GetLocale()
end

function KT:IsNonLatinLocale()
    local loc = self:GetActiveLanguage()
    return loc == "koKR" or loc == "zhTW" or loc == "zhCN" or loc == "ruRU"
end


local DISPLAY_FONT_FOR_LANGUAGE = {
    koKR = "Noto Sans KR",
    zhTW = "Noto Sans TC",
    zhCN = "Noto Sans SC",
    ruRU = "Friz Quadrata TT (Cyrillic)",
}

-- The real font face that replaces the bundled Latin-only default on each
-- non-Latin language, used for dropdown labels so users never see the generic
-- "Standard Text Font" placeholder or the misleading "Avant Garde" name.
function KT:GetLocalizedFontDisplayName()
    local lang = self:GetActiveLanguage()
    return DISPLAY_FONT_FOR_LANGUAGE[lang]
end

function KT:GetDefaultFontName()
    if self:IsNonLatinLocale() then
        return self:GetLocalizedFontDisplayName() or self.LOCALIZED_FONT_NAME
    end
    return self.DEFAULT_FONT_NAME
end

function KT:GetDefaultFontPath()
    if self:IsNonLatinLocale() then
        -- Language-aware: honors profile.language even when it differs from the
        -- client locale (e.g. Korean selected on an enUS client).
        return GetLocalizedFontPathSafe(self:GetActiveLanguage())
    end
    return self.DEFAULT_FONT_PATH
end

function KT:ResolveFontName(fontName)
    local selected = fontName
    if type(selected) ~= "string" or selected == "" then
        selected = self.db and self.db.profile and self.db.profile.globalFont and self.db.profile.globalFont.font
    end

    if type(selected) ~= "string" or selected == "" then
        selected = self:GetDefaultFontName()
    end

    -- The bundled Avant Garde font does not include Cyrillic glyphs.
    -- Match by name OR by stored file path (CastBar persists the raw .ttf path).
    if self:IsNonLatinLocale() and self:IsDefaultBundledFont(selected) then
        selected = self.LOCALIZED_FONT_NAME
    end

    -- A stored marker (or a value normalized to it) means "the suite default
    -- for the active language": canonicalize it so Latin clients resolve back
    -- to the bundled Avant Garde face instead of carrying a migrated
    -- CJK/Cyrillic value over from a previous non-Latin locale, and CJK/Ru
    -- clients resolve to their localized fallback.
    if selected == self.LOCALIZED_FONT_NAME then
        local default = self:GetDefaultFontName()
        if default and default ~= self.LOCALIZED_FONT_NAME then
            selected = default
        end
    end

    return selected
end

function KT:ResolveFontPath(fontName, fallbackPath)
    -- Inspect the RAW request (before ResolveFontName rewrites the bundled
    -- default into LOCALIZED_FONT_NAME) so we can detect "use the suite default".
    local original = fontName
    if type(original) ~= "string" or original == "" then
        original = self.db and self.db.profile and self.db.profile.globalFont and self.db.profile.globalFont.font
    end

    -- When a non-Latin language is active and the requested font is unset or
    -- cannot render that language (Avant Garde, Friz Quadrata, Barlow, ...),
    -- force the font of the ACTIVE language. This must beat the LSM entry for
    -- LOCALIZED_FONT_NAME, which was registered from the CLIENT locale and
    -- would point at FRIZQT__.TTF (no Korean/Cyrillic glyphs) on Western
    -- clients.
    local forceLocal = self:IsNonLatinLocale() and (not original or not self:IsFontCompatibleWithLocale(original))

    local selected = self:ResolveFontName(fontName)
    local resolved

    if forceLocal then
        resolved = GetLocalizedFontPathSafe(self:GetActiveLanguage())
    end

    if (not resolved or resolved == "") and LSM and selected then
        resolved = LSM:Fetch("font", selected)
    end

    if (not resolved or resolved == "") and self:IsNonLatinLocale() then
        if LSM then
            resolved = LSM:Fetch("font", self.LOCALIZED_FONT_NAME)
        end
        resolved = resolved or self.LOCALIZED_FONT_PATH
    end

    if not resolved or resolved == "" then
        resolved = fallbackPath or self.FALLBACK_FONT_PATH
    end

    return resolved, selected
end

function KT:IsDefaultBundledFont(value)
    return type(value) == "string" and value ~= ""
        and (value == self.DEFAULT_FONT_NAME
            or value == self.DEFAULT_FONT_PATH
            or value == "Avant Garde"
            or value:find(self.DEFAULT_FONT_NAME, 1, true) ~= nil
            or value:find("Avant Garde.ttf", 1, true) ~= nil)
end

-- Whether a stored value (name OR file path) represents "the suite default for
-- the active language": the bundled Latin face, the canonical marker, or a
-- concrete localized fallback that older migrations wrote into profiles. This
-- is locale-independent, so switching back from koKR/zhCN/zhTW/ruRU to a Latin
-- language reverts the default to Avant Garde, and vice versa.
function KT:IsLocalizedDefaultFont(value)
    if type(value) ~= "string" or value == "" then
        return false
    end
    if value == self.LOCALIZED_FONT_NAME or self:IsDefaultBundledFont(value) then
        return true
    end
    for _, name in pairs(DISPLAY_FONT_FOR_LANGUAGE) do
        if value == name then
            return true
        end
        if LSM and LSM.Fetch then
            local path = LSM:Fetch("font", name, true)
            if type(path) == "string" and path == value then
                return true
            end
        end
    end
    return false
end

-- Whether a stored font name/path can render the ACTIVE language without tofu.
-- Mirrors the ExwindTools approach: on non-Latin languages only fonts known to
-- include the required glyphs are kept; anything else is forced to the
-- localized font so the UI never paints squares.
function KT:IsFontCompatibleWithLocale(value)
    if not self:IsNonLatinLocale() then
        return true
    end
    if type(value) ~= "string" or value == "" then
        return true
    end
    -- Bundled OFL CJK fonts cover Hangul/Chinese/Japanese/Latin/Cyrillic.
    if value:find("Noto", 1, true) then
        return true
    end
    -- Only the bundled Cyrillic font (Russo One) and the client's native ruRU
    -- greymatter can render Russian. LOCALIZED_FONT_NAME ("Standard Text Font")
    -- is deliberately NOT compatible on non-Latin: its LSM entry is registered
    -- from the CLIENT locale and would resolve to FRIZQT__.TTF (no CJK/Cyrillic
    -- glyphs) on Western clients, so it must be forced to the language-aware
    -- path regardless of module load order.
    if self:GetActiveLanguage() == "ruRU" then
        return value == self.CYRILLIC_FONT_NAME
            or value == self.CYRILLIC_FONT_PATH
            or value == "Friz Quadrata TT (Cyrillic)"
            or value:find("Russo One", 1, true) ~= nil
    end
    return false
end

-- Font-option visibility for font dropdowns: on non-Latin languages only list
-- faces that can actually render the active language, so the picker stops
-- offering Avant Garde / Friz Quadrata / display fonts that would paint tofu.
function KT:IsFontOptionVisible(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    if not self:IsNonLatinLocale() then
        return true
    end
    if self.LOCALIZED_FONT_NAME and name == self.LOCALIZED_FONT_NAME then
        return true
    end
    if name:find("Noto", 1, true) then
        return true
    end
    if self:GetActiveLanguage() == "ruRU" then
        if name:find("Friz Quadrata TT", 1, true) or name:find("Russo One", 1, true) then
            return true
        end
        local p = LSM and LSM.Fetch and LSM:Fetch("font", name, true)
        if type(p) == "string" and p:find("FRIZQT___CYR", 1, true) then
            return true
        end
    end
    return false
end

-- FontStrings cannot combine two font files. Keep Avant Garde as the normal
-- face and swap only strings containing Cyrillic to the bundled Russo One,
-- which includes the complete Russian alphabet. The byte pattern is used so
-- this remains compatible with WoW's Lua 5.1 runtime.
local CYRILLIC_UTF8_PATTERN = "[\208\209][\128-\191]"

function KT:ContainsCyrillic(text)
    if type(text) ~= "string" then
        return false
    end
    if _G.issecretvalue and _G.issecretvalue(text) then
        return false
    end

    local ok, first = pcall(string.find, text, CYRILLIC_UTF8_PATTERN)
    return ok and first ~= nil
end

function KT:ResolveTextFontPath(text, baseFontPath)
    local base = (type(baseFontPath) == "string" and baseFontPath ~= "")
        and baseFontPath
        or self.FONT_PATH
        or self.DEFAULT_FONT_PATH

    if self:ContainsCyrillic(text) and self:IsDefaultBundledFont(base) then
        return self.CYRILLIC_FONT_PATH
    end
    return base
end

function KT:RefreshTextFontFallback(fontString, text)
    if not (fontString and fontString.GetFont and fontString.SetFont) or fontString._ktTextFontApplying then
        return
    end

    local baseSource = fontString._ktTextFontBase
    local base = type(baseSource) == "function" and baseSource(fontString) or baseSource
    local current, size, flags = fontString:GetFont()
    base = (type(base) == "string" and base ~= "") and base or current
    if not base then
        return
    end

    local displayText = text
    if displayText == nil and fontString.GetText then
        local ok, value = pcall(fontString.GetText, fontString)
        if ok then displayText = value end
    end

    local desired = self:ResolveTextFontPath(displayText, base)
    if desired and desired ~= current then
        fontString._ktTextFontApplying = true
        pcall(fontString.SetFont, fontString, desired, size or 12, flags or "")
        fontString._ktTextFontApplying = nil
    end
end

function KT:EnableTextFontFallback(fontString, baseFontSource)
    if not (fontString and fontString.SetFont) then
        return
    end

    fontString._ktTextFontBase = baseFontSource
    if not fontString._ktTextFontHooked and _G.hooksecurefunc then
        fontString._ktTextFontHooked = true
        _G.hooksecurefunc(fontString, "SetText", function(self, value)
            KT:RefreshTextFontFallback(self, value)
        end)
        if fontString.SetFormattedText then
            _G.hooksecurefunc(fontString, "SetFormattedText", function(self)
                KT:RefreshTextFontFallback(self)
            end)
        end
    end

    self:RefreshTextFontFallback(fontString)
end

-- Cascade stored font VALUES (names or file paths) through the locale-aware
-- resolver so widgets that saved the raw bundled font do not render tofu
-- glyphs on koKR/zhTW/zhCN/ruRU clients.
function KT:ResolveStoredFontName(value)
    if self:IsNonLatinLocale() and self:IsDefaultBundledFont(value) then
        return self.LOCALIZED_FONT_NAME
    end
    return value
end

function KT:ResolveStoredFontPath(value, fallbackPath)
    if self:IsNonLatinLocale() and self:IsDefaultBundledFont(value) then
        return self:ResolveFontPath(self.LOCALIZED_FONT_NAME) or fallbackPath
    end
    return (type(value) == "string" and value ~= "") and value or fallbackPath
end

-- Single entry point for modules that fetch a font from their own DB and apply
-- it with SetFont. Accepts an LSM font NAME or a raw file PATH. Handles every
-- locality so raw Latin faces (Avant Garde, Friz Quadrata, FRIZQT__) can never
-- paint tofu on non-Latin languages, while on Latin locales real paths are kept
-- raw (LSM:Fetch would otherwise rewrite unregistered paths to the LSM default).
function KT:ResolveFontForLocale(font, fallbackPath)
    local isRawPath = type(font) == "string"
        and (font:find(".ttf", 1, true) or font:find("\\", 1, true) or font:find("/", 1, true))
    if self:IsNonLatinLocale() then
        return self:ResolveFontPath(font, fallbackPath)
    end
    if LSM and type(font) == "string" and font ~= "" and not isRawPath then
        local fetched = LSM:Fetch("font", font)
        if type(fetched) == "string" and fetched ~= "" then
            return fetched
        end
    end
    if type(font) == "string" and font ~= "" then
        return font
    end
    return fallbackPath
end

function KT:RefreshFontPath(fontName)
    local resolved = self:ResolveFontPath(fontName, self:GetDefaultFontPath())
    self.FONT_PATH = resolved
    return resolved
end

function KT:NormalizeProfileFontsForLocale()
    if not self.db or not self.db.profile then
        return false
    end

    local changed = false
    local nonLatin = self:IsNonLatinLocale()

    local function visit(tbl)
        for key, value in pairs(tbl) do
            if type(value) == "table" then
                visit(value)
            elseif type(key) == "string" and type(value) == "string" then
                -- Only touch keys that ARE a font (key ends in "font"), not
                -- font flags/sizes/colors like "fontOutline"/"fontScale".
                local lowered = key:lower()
                local isFontKey = lowered == "font" or lowered:sub(-4) == "font"
                if isFontKey then
                    local isDefault = self:IsLocalizedDefaultFont(value)
                    if nonLatin then
                        -- Canonical "use the suite default" values (Avant Garde,
                        -- legacy concrete localized names/paths, the marker) are
                        -- stored as the portable marker so profiles survive
                        -- locale switches; anything else that cannot render the
                        -- active language is also replaced for glyph safety.
                        if isDefault then
                            if value ~= self.LOCALIZED_FONT_NAME then
                                tbl[key] = self.LOCALIZED_FONT_NAME
                                changed = true
                            end
                        elseif not self:IsFontCompatibleWithLocale(value) then
                            tbl[key] = self.LOCALIZED_FONT_NAME
                            changed = true
                        end
                    else
                        -- On Latin, localized-default markers and legacy CJK/
                        -- Cyrillic names/paths written on another language must
                        -- resolve back to the bundled Avant Garde default.
                        -- Real bundled faces and arbitrary fonts stay untouched.
                        if isDefault and not self:IsDefaultBundledFont(value) then
                            tbl[key] = self.DEFAULT_FONT_NAME
                            changed = true
                        end
                    end
                end
            end
        end
    end

    visit(self.db.profile)
    if changed then
        self:RefreshFontPath()
    end

    return changed
end

KT.FONT_PATH = KT.FONT_PATH or KT:RefreshFontPath()
KT.C_R = KT.C_R or 1
KT.C_G = KT.C_G or 0
KT.C_B = KT.C_B or 0.3333333333
KT.CONTENT_PAD = KT.CONTENT_PAD or 20
KT.BG_COLOR = KT.BG_COLOR or { r = 0.06, g = 0.06, b = 0.08, a = 0.96 }
KT.bars = KT.bars or {}
KT.Widgets = KT.Widgets or {}
KT.Glows = KT.Glows or {}
KT.UnlockElements = KT.UnlockElements or {}
KT.MovableElements = KT.MovableElements or KT.UnlockElements
KT._specSwitchRegistry = KT._specSwitchRegistry or {}
KT._resourceState = KT._resourceState or {
    tip = 0,
    tipMax = 3,
    whirlwind = 0,
    whirlwindMax = 4,
}

local BG_ONLY_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
}

local BORDER_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function normalizeColor(r, g, b, a, default)
    if type(r) == "table" then
        local t = r
        return t.r or t[1] or 0, t.g or t[2] or 0, t.b or t[3] or 0, t.a or t[4] or 1
    end

    default = default or KT.BG_COLOR
    return r or default.r or 0, g or default.g or 0, b or default.b or 0, a or default.a or 1
end

local function readPaletteColor(source, dr, dg, db, da)
    local r, g, b, a = normalizeColor(source, nil, nil, nil, { r = dr, g = dg, b = db, a = da })
    return {
        r = max(0, min(1, tonumber(r) or dr or 0)),
        g = max(0, min(1, tonumber(g) or dg or 0)),
        b = max(0, min(1, tonumber(b) or db or 0)),
        a = max(0, min(1, tonumber(a) or da or 1)),
    }
end

local function getPlayerClassPaletteColor(fallback)
    local _, classTag = UnitClass("player")
    local classColor = classTag and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classTag)
    if not classColor and classTag and RAID_CLASS_COLORS then
        classColor = RAID_CLASS_COLORS[classTag]
    end

    fallback = fallback or { r = 1, g = 0, b = 0.3333333333, a = 1 }
    return readPaletteColor(classColor, fallback.r, fallback.g, fallback.b, fallback.a or 1)
end

local layoutBorder

local function ensureBorderFrame(owner, key, layer, sublevel)
    local borderFrame = owner[key]
    if borderFrame then
        return borderFrame
    end

    borderFrame = CreateFrame("Frame", nil, owner)
    borderFrame:SetAllPoints()
    borderFrame:SetIgnoreParentAlpha(false)
    borderFrame:EnableMouse(false)
    borderFrame._edges = {}
    borderFrame._edgeLayer = layer or "BORDER"
    borderFrame._edgeSublevel = sublevel or 0

    for i = 1, 4 do
        borderFrame._edges[i] = borderFrame:CreateTexture(nil, borderFrame._edgeLayer, nil, borderFrame._edgeSublevel)
    end

    borderFrame.SetColor = borderFrame.SetColor or function(self, r, g, b, a)
        local size = self._edgeSize or 1
        local drawLayer = self._edgeLayer or "OVERLAY"
        local drawSublevel = self._edgeSublevel or 0
        return layoutBorder(self, owner, size, r, g, b, a, drawLayer, drawSublevel)
    end
    borderFrame.SetSize = borderFrame.SetSize or function(self, size)
        local color = self._edgeColor or { r = 0, g = 0, b = 0, a = 1 }
        local drawLayer = self._edgeLayer or "OVERLAY"
        local drawSublevel = self._edgeSublevel or 0
        return layoutBorder(self, owner, size, color.r, color.g, color.b, color.a, drawLayer, drawSublevel)
    end

    owner[key] = borderFrame
    return borderFrame
end

layoutBorder = function(borderFrame, target, size, r, g, b, a, layer, sublevel)
    if not borderFrame then
        return nil
    end

    size = max(1, floor(tonumber(size) or 1))
    borderFrame:ClearAllPoints()
    borderFrame:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    borderFrame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
    borderFrame:SetFrameLevel(((target.GetFrameLevel and target:GetFrameLevel()) or 0) + 8)
    borderFrame._edgeLayer = layer or borderFrame._edgeLayer or "BORDER"
    borderFrame._edgeSublevel = sublevel or borderFrame._edgeSublevel or 0
    borderFrame._edgeSize = size
    borderFrame._edgeColor = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }

    local edges = borderFrame._edges
    for i = 1, 4 do
        edges[i]:SetDrawLayer(borderFrame._edgeLayer, borderFrame._edgeSublevel)
    end

    edges[1]:ClearAllPoints()
    edges[1]:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
    edges[1]:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
    edges[1]:SetHeight(size)

    edges[2]:ClearAllPoints()
    edges[2]:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
    edges[2]:SetHeight(size)

    edges[3]:ClearAllPoints()
    edges[3]:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
    edges[3]:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
    edges[3]:SetWidth(size)

    edges[4]:ClearAllPoints()
    edges[4]:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
    edges[4]:SetWidth(size)

    for i = 1, 4 do
        edges[i]:SetColorTexture(borderFrame._edgeColor.r, borderFrame._edgeColor.g, borderFrame._edgeColor.b, borderFrame._edgeColor.a)
        edges[i]:Show()
    end

    borderFrame:Show()
    return borderFrame
end

local function roundToStep(value, step)
    step = tonumber(step) or 1
    if step <= 0 then
        return value
    end

    return floor((value / step) + 0.5) * step
end

local function formatNumber(value, step)
    value = tonumber(value) or 0
    step = tonumber(step) or 1

    if step >= 1 or step == floor(step) then
        return tostring(floor(value + 0.5))
    end

    local decimals = 0
    local stepText = tostring(step)
    local dot = stepText:find("%.")
    if dot then
        decimals = #stepText - dot
    end
    decimals = max(1, min(decimals, 3))
    return string.format("%." .. decimals .. "f", value)
end

local function getPlayerAuraStacks(spellID)
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not spellName or not AuraUtil or not AuraUtil.FindAuraByName then
        return 0
    end

    local aura = AuraUtil.FindAuraByName(spellName, "player", "HELPFUL")
    if not aura then
        return 0
    end

    return aura.applications or aura.charges or 0
end

function KT:GetLocale()
    local locales = ns and ns.Locales
    if type(locales) ~= "table" then
        return nil
    end

    local lang = (self.db and self.db.profile and self.db.profile.language) or GetLocale()
    return locales[lang] or locales[GetLocale()] or locales.enUS or locales.esES
end

function KT:GetStylePalette()
    local profile = self and self.db and self.db.profile or nil
    local skin = profile and profile.skin or nil

    local accent = readPaletteColor(skin and skin.accentColor, 1, 0, 0.3333333333, 1)
    local border = readPaletteColor(skin and skin.borderColor, accent.r, accent.g, accent.b, 1)
    local background = readPaletteColor(skin and skin.backgroundColor, 0.06, 0.06, 0.08, 0.96)
    local text = readPaletteColor(skin and skin.menuTextColor, 0.98, 0.94, 0.96, 1)
    local muted = readPaletteColor(skin and skin.menuSubtextColor, 0.74, 0.74, 0.78, 1)
    local backgroundTint = readPaletteColor(skin and skin.menuBackgroundTint, accent.r, accent.g, accent.b, 0.16)
    local themeMode = skin and skin.borderTheme or "KULLTHRAN"

    if skin and skin.kullthranUIColorByClass then
        themeMode = "CLASS"
    end

    if themeMode == "CLASS" then
        accent = getPlayerClassPaletteColor(accent)
        border = readPaletteColor(accent, accent.r, accent.g, accent.b, border.a or 1)
        backgroundTint = readPaletteColor({
            r = accent.r,
            g = accent.g,
            b = accent.b,
            a = backgroundTint.a or 0.16,
        }, accent.r, accent.g, accent.b, backgroundTint.a or 0.16)
    elseif themeMode == "CUSTOM" then
        accent = readPaletteColor(skin and skin.customBorderColor, accent.r, accent.g, accent.b, 1)
        border = readPaletteColor(accent, accent.r, accent.g, accent.b, border.a or 1)
        backgroundTint = readPaletteColor({
            r = accent.r,
            g = accent.g,
            b = accent.b,
            a = backgroundTint.a or 0.16,
        }, accent.r, accent.g, accent.b, backgroundTint.a or 0.16)
    end

    return {
        accent = accent,
        border = border,
        background = background,
        text = text,
        muted = muted,
        backgroundTint = backgroundTint,
        iconMode = skin and skin.menuIconColorMode or "accent",
        preset = skin and skin.stylePreset or "kui_crimson",
    }
end

function KT:GetStyleAccentRGB()
    local palette = self:GetStylePalette()
    local accent = palette and palette.accent or nil
    return (accent and accent.r) or self.C_R or 1,
        (accent and accent.g) or self.C_G or 0,
        (accent and accent.b) or self.C_B or 0.3333333333
end

function KT:GetStyleBorderRGB()
    local palette = self:GetStylePalette()
    local border = palette and (palette.border or palette.accent) or nil
    return (border and border.r) or self.C_R or 1,
        (border and border.g) or self.C_G or 0,
        (border and border.b) or self.C_B or 0.3333333333
end

function KT:GetStyleTextRGB()
    local palette = self:GetStylePalette()
    local text = palette and palette.text or nil
    return (text and text.r) or 1,
        (text and text.g) or 1,
        (text and text.b) or 1
end

function KT:GetStyleMutedRGB()
    local palette = self:GetStylePalette()
    local muted = palette and palette.muted or nil
    return (muted and muted.r) or 0.74,
        (muted and muted.g) or 0.74,
        (muted and muted.b) or 0.78
end

function KT:AddAccentBorder(frame, alpha)
    local r, g, b = self:GetStyleAccentRGB()
    return self:AddBorder(frame, r, g, b, alpha)
end

function KT:SetAccentTextColor(fontString, alpha)
    if not (fontString and fontString.SetTextColor) then return end
    local r, g, b = self:GetStyleAccentRGB()
    fontString:SetTextColor(r, g, b, alpha == nil and 1 or alpha)
end

function KT:SetAccentTexture(texture, alpha)
    if not (texture and texture.SetColorTexture) then return end
    local r, g, b = self:GetStyleAccentRGB()
    texture:SetColorTexture(r, g, b, alpha == nil and 1 or alpha)
end

function KT:SetAccentVertexColor(texture, alpha)
    if not (texture and texture.SetVertexColor) then return end
    local r, g, b = self:GetStyleAccentRGB()
    texture:SetVertexColor(r, g, b, alpha == nil and 1 or alpha)
end

function KT:SetAccentBackdropBorder(frame, alpha)
    if not (frame and frame.SetBackdropBorderColor) then return end
    local r, g, b = self:GetStyleAccentRGB()
    frame:SetBackdropBorderColor(r, g, b, alpha == nil and 1 or alpha)
end

local LEGACY_CDM_BORDER_COLORS = {
    { r = 1.0, g = 0.0, b = 0.3333333333 },
    { r = 1.0, g = 0.18, b = 0.39 },
    { r = 0.37, g = 0.84, b = 1.0 },
    { r = 0.28, g = 0.95, b = 0.62 },
    { r = 0.66, g = 0.60, b = 1.0 },
    { r = 1.0, g = 0.74, b = 0.28 },
}

local function approximatelyEqualColor(a, b)
    if not (a and b) then return false end
    local epsilon = 0.015
    return math.abs((a.r or 0) - (b.r or 0)) <= epsilon
       and math.abs((a.g or 0) - (b.g or 0)) <= epsilon
       and math.abs((a.b or 0) - (b.b or 0)) <= epsilon
end

function KT:SanitizeLegacyCooldownManagerBorders()
    local profile = self and self.db and self.db.profile or nil
    local skin = profile and profile.skin or nil
    if not profile then return false end

    skin = skin or {}
    profile.skin = skin
    if skin._cdmBordersDecoupled then
        return false
    end

    local bars = profile.cooldownManager and profile.cooldownManager.cdmBars and profile.cooldownManager.cdmBars.bars
    if type(bars) ~= "table" then
        skin._cdmBordersDecoupled = true
        return false
    end

    local changed = false
    for _, bar in ipairs(bars) do
        local current = {
            r = tonumber(bar and bar.borderR) or 0,
            g = tonumber(bar and bar.borderG) or 0,
            b = tonumber(bar and bar.borderB) or 0,
        }
        for _, legacy in ipairs(LEGACY_CDM_BORDER_COLORS) do
            if approximatelyEqualColor(current, legacy) then
                bar.borderR = 0
                bar.borderG = 0
                bar.borderB = 0
                changed = true
                break
            end
        end
    end

    skin._cdmBordersDecoupled = true
    return changed
end

function KT:RefreshStylePalette()
    local palette = self:GetStylePalette()
    if not palette then
        return nil
    end

    self.STYLE_PALETTE = palette
    self.C_R = palette.accent.r
    self.C_G = palette.accent.g
    self.C_B = palette.accent.b
    self.BG_COLOR = {
        r = palette.background.r,
        g = palette.background.g,
        b = palette.background.b,
        a = palette.background.a,
    }

    -- Blizzard skins cache accent colors in textures created by their skinning
    -- pass. Notify the optional Skins module whenever the shared palette changes
    -- so already-open frames update without requiring a UI reload.
    local skins = self.GetModule and self:GetModule("Skins", true)
    if skins and skins.RefreshBlizzardTheme then
        skins:RefreshBlizzardTheme()
    end
    
    if self.ObjectiveTrackerSkin_UpdateColors then
        self.ObjectiveTrackerSkin_UpdateColors()
    end

    return palette
end

function KT:AddBackdrop(frame, r, g, b, a)
    if not frame then
        return
    end

    local cr, cg, cb, ca = normalizeColor(r, g, b, a, KT.BG_COLOR)
    frame._ktBackdropColor = { r = cr, g = cg, b = cb, a = ca }

    if frame.SetBackdrop then
        frame:SetBackdrop(BG_ONLY_BACKDROP)
        if frame.SetBackdropColor then
            frame:SetBackdropColor(cr, cg, cb, ca)
        end
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end
        frame.bgKT = frame.bgKT or frame._ktBackdropTexture
        return
    end

    local bg = frame._ktBackdropTexture
    if not bg then
        bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        frame._ktBackdropTexture = bg
    end
    bg:SetColorTexture(cr, cg, cb, ca)
    bg:Show()
    frame.bgKT = bg
end

function KT:AddBorder(frame, r, g, b, a, size)
    if not frame then
        return
    end

    local cr, cg, cb, ca = normalizeColor(r, g, b, a, { r = 0, g = 0, b = 0, a = 1 })
    size = max(1, floor(tonumber(size) or 1))

    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local borderFrame = ensureBorderFrame(frame, "_ktBorderFrame", "OVERLAY", 7)
    frame._ktBorders = borderFrame._edges
    frame.borderKT = borderFrame
    return layoutBorder(borderFrame, frame, size, cr, cg, cb, ca, "OVERLAY", 7)
end

function KT.SolidTex(parent, layer, r, g, b, a)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    return tex
end

function KT.MakeBorder(frame, r, g, b, a, size)
    return KT:AddBorder(frame, r, g, b, a, size)
end

function KT.MakeFont(parent, size, flags, r, g, b, a)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(KT.FONT_PATH, size or 11, flags or "")
    if r then
        fs:SetTextColor(r, g or 1, b or 1, a or 1)
    end
    return fs
end

KT.PP = KT.PP or {}
KT.PP.Scale = KT.PP.Scale or function(value)
    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    return floor(((value or 0) * scale) + 0.5) / scale
end
KT.PP.Point = KT.PP.Point or function(frame, point, relativeTo, relativePoint, x, y)
    frame:SetPoint(point, relativeTo, relativePoint, KT.PP.Scale(x or 0), KT.PP.Scale(y or 0))
end
KT.PP.Size = KT.PP.Size or function(frame, width, height)
    frame:SetSize(KT.PP.Scale(width or 0), KT.PP.Scale(height or 0))
end
KT.PP.Width = KT.PP.Width or function(frame, width)
    frame:SetWidth(KT.PP.Scale(width or 0))
end
KT.PP.Height = KT.PP.Height or function(frame, height)
    frame:SetHeight(KT.PP.Scale(height or 0))
end
KT.PP.DisablePixelSnap = KT.PP.DisablePixelSnap or function(tex)
    if tex and tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end
KT.PP.CreateBorder = KT.PP.CreateBorder or function(frame, r, g, b, a, size, layer, sublevel)
    local borderFrame = ensureBorderFrame(frame, "_ppBorderFrame", layer or "OVERLAY", sublevel or 0)
    frame._ppBorders = borderFrame._edges
    frame._ppBorderSize = max(1, floor(tonumber(size) or 1))
    frame._ppBorderColor = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }
    return layoutBorder(
        borderFrame,
        frame,
        frame._ppBorderSize,
        frame._ppBorderColor.r,
        frame._ppBorderColor.g,
        frame._ppBorderColor.b,
        frame._ppBorderColor.a,
        layer or "OVERLAY",
        sublevel or 0
    )
end
KT.PP.SetBorderSize = KT.PP.SetBorderSize or function(frame, size)
    if not (frame and frame._ppBorderColor) then
        return nil
    end

    frame._ppBorderSize = max(1, floor(tonumber(size) or frame._ppBorderSize or 1))
    return KT.PP.CreateBorder(
        frame,
        frame._ppBorderColor.r,
        frame._ppBorderColor.g,
        frame._ppBorderColor.b,
        frame._ppBorderColor.a,
        frame._ppBorderSize,
        frame._ppBorderFrame and frame._ppBorderFrame._edgeLayer or "OVERLAY",
        frame._ppBorderFrame and frame._ppBorderFrame._edgeSublevel or 0
    )
end
KT.PP.SetBorderColor = KT.PP.SetBorderColor or function(frame, r, g, b, a)
    if not frame then
        return nil
    end

    frame._ppBorderColor = { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }
    if not frame._ppBorderFrame then
        return KT.PP.CreateBorder(frame, r, g, b, a, frame._ppBorderSize or 1)
    end

    return layoutBorder(
        frame._ppBorderFrame,
        frame,
        frame._ppBorderSize or 1,
        frame._ppBorderColor.r,
        frame._ppBorderColor.g,
        frame._ppBorderColor.b,
        frame._ppBorderColor.a,
        frame._ppBorderFrame._edgeLayer or "OVERLAY",
        frame._ppBorderFrame._edgeSublevel or 0
    )
end
KT.PP.UpdateBorder = KT.PP.UpdateBorder or function(frame, size, r, g, b, a)
    return KT.PP.CreateBorder(frame, r, g, b, a, size)
end

function KT.BuildSliderCore(parent, sliderWidth, _, _, inputWidth, rowHeight, fontSize, inputAlpha, minValue, maxValue, step, getter, setter)
    if type(sliderWidth) == "table" then
        local opts = sliderWidth
        sliderWidth = opts.width
        inputWidth = opts.inputWidth
        rowHeight = opts.height
        fontSize = opts.fontSize
        inputAlpha = opts.inputAlpha
        minValue = opts.min
        maxValue = opts.max
        step = opts.step
        getter = opts.get
        setter = opts.set
    end

    sliderWidth = sliderWidth or 140
    inputWidth = inputWidth or 40
    rowHeight = rowHeight or 20
    fontSize = fontSize or 11
    inputAlpha = inputAlpha or 0.9
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or 100
    step = tonumber(step) or 1

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(sliderWidth, rowHeight)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(8, rowHeight + 2)
        KT:SetAccentTexture(thumb, 0.95)
    end

    local low = slider.Low or _G[slider:GetName() and slider:GetName() .. "Low" or ""]
    local high = slider.High or _G[slider:GetName() and slider:GetName() .. "High" or ""]
    local text = slider.Text or _G[slider:GetName() and slider:GetName() .. "Text" or ""]
    if low then low:SetText("") end
    if high then high:SetText("") end
    if text then text:SetText("") end

    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(inputWidth, rowHeight)
    edit:SetAutoFocus(false)
    edit:SetFont(KT.FONT_PATH, fontSize, "OUTLINE")
    edit:SetTextColor(1, 1, 1, 1)

    local function coerceValue(raw)
        local value = tonumber(raw)
        if not value then
            return nil
        end
        value = max(minValue, min(maxValue, value))
        value = roundToStep(value, step)
        return value
    end

    local function pullValue()
        local value = getter and getter()
        value = coerceValue(value) or minValue
        return value
    end

    local function pushValue(value, fromSlider)
        value = coerceValue(value) or minValue
        edit:SetText(formatNumber(value, step))

        if not fromSlider then
            slider:SetValue(value)
        end

        if setter then
            setter(value)
        end
    end

    slider:SetScript("OnValueChanged", function(_, value)
        value = coerceValue(value) or minValue
        edit:SetText(formatNumber(value, step))
        if setter then
            setter(value)
        end
    end)

    slider:HookScript("OnMouseDown", function()
        KT._sliderDragging = (KT._sliderDragging or 0) + 1
    end)
    slider:HookScript("OnMouseUp", function()
        KT._sliderDragging = max((KT._sliderDragging or 1) - 1, 0)
    end)

    edit:SetScript("OnEnterPressed", function(self)
        pushValue(self:GetText(), false)
        self:ClearFocus()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        local value = pullValue()
        self:SetText(formatNumber(value, step))
        self:ClearFocus()
    end)

    KT:AddBackdrop(edit, 0.02, 0.02, 0.03, inputAlpha)
    do
        local r, g, b = KT:GetStyleAccentRGB()
        KT:AddBorder(edit, r * 0.45, g * 0.45, b * 0.45, 1)
    end

    local initialValue = pullValue()
    slider:SetValue(initialValue)
    edit:SetText(formatNumber(initialValue, step))

    return slider, edit
end

function KT:AppendSharedMediaTextures(textureNames, textureOrder, _, textureMap)
    if not (LSM and textureNames and textureOrder and textureMap) then
        return
    end

    local list = LSM:List("statusbar")
    if not list then
        return
    end

    for _, name in ipairs(list) do
        if not textureMap[name] then
            local path = LSM:Fetch("statusbar", name, true)
            if path and path ~= "" then
                textureMap[name] = path
                textureNames[name] = textureNames[name] or name
                textureOrder[#textureOrder + 1] = name
            end
        end
    end
end

function KT:InsertLink(link)
    if not link or link == "" then
        return false
    end

    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        local ok = ChatFrameUtil.InsertLink(link)
        if ok then
            return true
        end
    end

    if ChatEdit_InsertLink then
        return ChatEdit_InsertLink(link) and true or false
    end

    return false
end

function KT:InvalidateContentHeaderCache()
    self._contentHeaderCache = nil
    if self._mainFrame then
        self._mainFrame._contentHeaderCache = nil
    end
end

function KT:UnregisterUnlockElement(key)
    if not key or not self.UnlockElements then
        return
    end

    self.UnlockElements[key] = nil
    self.MovableElements = self.UnlockElements

    local unlockMode = self.GetModule and self:GetModule("UnlockMode", true)
    if unlockMode and unlockMode.UpdateRegistry then
        unlockMode:UpdateRegistry()
    end
end

function KT:ShowNudgeFrame(target, onChanged)
    self.NudgeFrame = self.NudgeFrame or {}
    self.NudgeFrame.target = target
    self.NudgeFrame.onChanged = onChanged
    return self.NudgeFrame
end

function KT:GetTipOfTheSpear()
    local compat = ns and ns.KUIUFCompat
    if compat and compat.GetTipOfTheSpear then
        return compat.GetTipOfTheSpear()
    end

    self._resourceState.tip = getPlayerAuraStacks(260286)
    return self._resourceState.tip, self._resourceState.tipMax
end

function KT:GetWhirlwindStacks()
    local compat = ns and ns.KUIUFCompat
    if compat and compat.GetWhirlwindStacks then
        return compat.GetWhirlwindStacks()
    end

    return self._resourceState.whirlwind or 0, self._resourceState.whirlwindMax
end

function KT:HandleTipOfTheSpear(event, ...)
    local compat = ns and ns.KUIUFCompat
    if compat and compat.HandleTipOfTheSpear then
        return compat.HandleTipOfTheSpear(event, ...)
    end

    if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
        self._resourceState.tip = 0
    else
        self._resourceState.tip = getPlayerAuraStacks(260286)
    end
end

function KT:HandleWhirlwindStacks(event, unit, _, spellID)
    local compat = ns and ns.KUIUFCompat
    if compat and compat.HandleWhirlwindStacks then
        return compat.HandleWhirlwindStacks(event, unit, nil, spellID)
    end

    if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_REGEN_ENABLED" then
        self._resourceState.whirlwind = 0
        return
    end

    if unit ~= "player" then
        return
    end

    if spellID == 1680 then
        self._resourceState.whirlwind = self._resourceState.whirlwindMax
    elseif (self._resourceState.whirlwind or 0) > 0 then
        self._resourceState.whirlwind = self._resourceState.whirlwind - 1
    end
end

local function showGenericGlow(frame)
    if frame and ButtonGlow and ButtonGlow.ShowOverlayGlow then
        ButtonGlow.ShowOverlayGlow(frame)
    end
end

local function hideGenericGlow(frame)
    if frame and ButtonGlow and ButtonGlow.HideOverlayGlow then
        ButtonGlow.HideOverlayGlow(frame)
    end
end

local AUTOCAST_GLOW_TEXTURE = "Interface\\Artifacts\\Artifacts"
local AUTOCAST_GLOW_TEXCOORD = { 0.8115234375, 0.9169921875, 0.8798828125, 0.9853515625 }
local AUTOCAST_GLOW_DOT_SIZES = { 7, 6, 5, 4 }
local AUTOCAST_GLOW_PARTICLES = 4
local AUTOCAST_GLOW_DRIVER_INTERVAL = 0.100
local autoCastGlowRegistry = {}
local autoCastGlowRegistryIndex = {}
local autoCastGlowRegistryCount = 0
local autoCastGlowDriver
local autoCastGlowDriverElapsed = 0

local function AutoCastGlowOnUpdate(self, elapsed)
    local info = self.info
    if not info then
        return
    end

    local width = info.width
    local height = info.height
    local perimeter = info.perimeter
    if not (width and height and perimeter and width > 0 and height > 0 and perimeter > 0) then
        return
    end

    local texIndex = 0
    for ring = 1, 4 do
        self.timer[ring] = (self.timer[ring] or 0) + elapsed / (info.period * ring)
        if self.timer[ring] > 1 or self.timer[ring] < -1 then
            self.timer[ring] = self.timer[ring] % 1
        end

        for i = 1, info.count do
            texIndex = texIndex + 1
            local position = (info.space * i + perimeter * self.timer[ring]) % perimeter
            local tex = self.textures[texIndex]
            if tex then
                local x, y
                if position > info.bottomLimit then
                    x = width - position + info.bottomLimit
                    y = -height
                elseif position > info.rightLimit then
                    x = width
                    y = -position + info.rightLimit
                elseif position > height then
                    x = position - height
                    y = 0
                else
                    x = 0
                    y = position - height
                end

                -- The original four-edge implementation rewrote all sixteen
                -- anchors every driver pass. With KUI's deliberately slow
                -- eight-second orbit most sub-frame movement is below one
                -- screen pixel, so those layout operations cannot alter the
                -- rendered result. Pixel-snap and only touch the anchor when
                -- the particle actually reaches another visible position.
                x = floor(x + 0.5)
                y = floor(y + 0.5)
                if tex._ktAutoCastX ~= x or tex._ktAutoCastY ~= y then
                    tex._ktAutoCastX = x
                    tex._ktAutoCastY = y
                    tex:ClearAllPoints()
                    tex:SetPoint("CENTER", self, "TOPLEFT", x, y)
                end
            end
        end
    end
end

local function UnregisterAutoCastGlow(glow)
    local index = autoCastGlowRegistryIndex[glow]
    if not index then return end
    local last = autoCastGlowRegistry[autoCastGlowRegistryCount]
    autoCastGlowRegistry[index] = last
    if last then autoCastGlowRegistryIndex[last] = index end
    autoCastGlowRegistry[autoCastGlowRegistryCount] = nil
    autoCastGlowRegistryCount = autoCastGlowRegistryCount - 1
    autoCastGlowRegistryIndex[glow] = nil
    if autoCastGlowRegistryCount == 0 and autoCastGlowDriver then
        autoCastGlowDriver:Hide()
        autoCastGlowDriverElapsed = 0
    end
end

local function AutoCastGlowDriverOnUpdate(self, elapsed)
    local dt = autoCastGlowDriverElapsed + elapsed
    if dt < AUTOCAST_GLOW_DRIVER_INTERVAL then
        autoCastGlowDriverElapsed = dt
        return
    end
    autoCastGlowDriverElapsed = 0
    local profiler = KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("core.autocast.driver")
    local index = 1
    while index <= autoCastGlowRegistryCount do
        local glow = autoCastGlowRegistry[index]
        -- These are addon-owned frames. Avoid a protected-call and secret-value
        -- probe on every active glow tick; both were showing up as core CPU even
        -- though CDM/nameplates were the callers. IsVisible is safe here because
        -- the glow itself is never a Blizzard-owned restricted object.
        if not glow or not glow.IsVisible then
            UnregisterAutoCastGlow(glow)
        else
            if glow:IsVisible() then AutoCastGlowOnUpdate(glow, dt) end
            if autoCastGlowRegistry[index] == glow then index = index + 1 end
        end
    end
    if autoCastGlowRegistryCount == 0 then self:Hide() end
    if profileStarted then profiler:End("core.autocast.driver", profileStarted) end
end

local function RegisterAutoCastGlow(glow)
    if autoCastGlowRegistryIndex[glow] then return end
    autoCastGlowRegistryCount = autoCastGlowRegistryCount + 1
    autoCastGlowRegistry[autoCastGlowRegistryCount] = glow
    autoCastGlowRegistryIndex[glow] = autoCastGlowRegistryCount
    if not autoCastGlowDriver then
        autoCastGlowDriver = CreateFrame("Frame")
        autoCastGlowDriver:Hide()
        autoCastGlowDriver:SetScript("OnUpdate", AutoCastGlowDriverOnUpdate)
    end
    if autoCastGlowRegistryCount == 1 then
        autoCastGlowDriverElapsed = 0
        autoCastGlowDriver:Show()
    end
end

local function EnsureAutoCastGlow(frame)
    if not frame then
        return nil
    end

    if frame._ktAutoCastGlow then
        return frame._ktAutoCastGlow
    end

    local glow = CreateFrame("Frame", nil, frame)
    glow.textures = {}
    glow.timer = { 0, 0, 0, 0 }
    glow.info = {}
    glow:Hide()

    local total = AUTOCAST_GLOW_PARTICLES * #AUTOCAST_GLOW_DOT_SIZES
    for i = 1, total do
        local tex = glow:CreateTexture(nil, "ARTWORK", nil, 7)
        tex:SetTexture(AUTOCAST_GLOW_TEXTURE)
        tex:SetTexCoord(unpack(AUTOCAST_GLOW_TEXCOORD))
        tex:SetBlendMode("ADD")
        tex:Hide()
        glow.textures[i] = tex
    end

    frame._ktAutoCastGlow = glow
    return glow
end

local function startAutoCastGlow(frame, size, r, g, b, scale)
    local glow = EnsureAutoCastGlow(frame)
    if not glow then
        return
    end

    local width = max(4, tonumber(size) or 16)
    local height = width
    local dotScale = tonumber(scale) or 1
    local colorR = tonumber(r) or 0.95
    local colorG = tonumber(g) or 0.95
    local colorB = tonumber(b) or 0.32

    glow:SetParent(frame)
    glow:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 8)
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
    glow:SetSize(width, height)
    glow:SetAlpha(1)

    for ring, dotSize in ipairs(AUTOCAST_GLOW_DOT_SIZES) do
        for particle = 1, AUTOCAST_GLOW_PARTICLES do
            local tex = glow.textures[particle + AUTOCAST_GLOW_PARTICLES * (ring - 1)]
            if tex then
                tex._ktAutoCastX = nil
                tex._ktAutoCastY = nil
                tex:ClearAllPoints()
                tex:SetSize(dotSize * dotScale, dotSize * dotScale)
                tex:SetVertexColor(colorR, colorG, colorB, 1)
                tex:Show()
            end
        end
    end

    glow.timer[1], glow.timer[2], glow.timer[3], glow.timer[4] = 0, 0, 0, 0
    glow.info.width = width
    glow.info.height = height
    glow.info.count = AUTOCAST_GLOW_PARTICLES
    glow.info.period = 8
    glow.info.perimeter = 2 * (width + height)
    glow.info.bottomLimit = height * 2 + width
    glow.info.rightLimit = height + width
    glow.info.space = glow.info.perimeter / AUTOCAST_GLOW_PARTICLES
    -- Scrub per-wrapper drivers left by older builds. One shared driver owns
    -- every active AutoCast shine and sleeps completely when the registry is empty.
    glow:SetScript("OnUpdate", nil)
    AutoCastGlowOnUpdate(glow, 0)
    glow:Show()
    RegisterAutoCastGlow(glow)
end

local function stopAutoCastGlow(frame)
    local glow = frame and frame._ktAutoCastGlow
    if not glow then
        return
    end

    glow:SetScript("OnUpdate", nil)
    UnregisterAutoCastGlow(glow)
    glow:Hide()
    for i = 1, #glow.textures do
        local tex = glow.textures[i]
        if tex then
            tex:Hide()
            tex._ktAutoCastX = nil
            tex._ktAutoCastY = nil
            tex:ClearAllPoints()
        end
    end
end

KT.Glows.StartProceduralAnts = KT.Glows.StartProceduralAnts or function(frame)
    showGenericGlow(frame)
end
KT.Glows.StopProceduralAnts = KT.Glows.StopProceduralAnts or function(frame)
    hideGenericGlow(frame)
end
KT.Glows.StartButtonGlow = KT.Glows.StartButtonGlow or function(frame)
    showGenericGlow(frame)
end
KT.Glows.StopButtonGlow = KT.Glows.StopButtonGlow or function(frame)
    hideGenericGlow(frame)
end
KT.Glows.StartAutoCastShine = startAutoCastGlow
KT.Glows.StopAutoCastShine = stopAutoCastGlow

function KT:ShowModule(name)
    local pageMap = {
        KUICooldownManager = "cooldownmanager",
        ["Cooldown Manager"] = "cooldownmanager",
        KUIAuraReminders = "aurareminders",
        ["Aura Reminders"] = "aurareminders",
        UnitFrames = "unitframes",
        ["Unit Frames"] = "unitframes",
        PartyFrames = "partyframes",
        ["Party Frames"] = "partyframes",
        ResourceBars = "resourcebars",
        ["Resource Bars"] = "resourcebars",
        Nameplates = "nameplates",
        Skins = "skins",
        Bags = "bags",
        Chat = "chat",
        Installer = "installer",
    }

    local pageId = pageMap[name]
    if not pageId and type(name) == "string" then
        pageId = name:gsub("%s+", ""):lower()
    end

    if self.OpenMenu then
        self:OpenMenu(pageId)
    elseif self.ToggleConfig then
        self:ToggleConfig()
    end
end
