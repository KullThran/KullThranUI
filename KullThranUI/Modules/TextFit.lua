-- TextFit: keeps button labels inside their buttons in every language.
--
-- When a page of the options menu or a step of the installer is shown, every
-- visible button label is checked against the room it has inside its button.
-- A label that does not fit is drawn up to 15% smaller; if it still does not
-- fit it is cut with an ellipsis and the full text goes to the tooltip.
-- It runs on page/step changes and on the label's own SetText, never on
-- OnUpdate.
--
-- /kuitextfit scan opens every options page and measures each label in all ten
-- languages, with the font each language uses. Labels that would be shrunk or
-- cut are stored in KT.db.global.textFitReport.

local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local TextFit = {}
KT.TextFit = TextFit

local MIN_SCALE = 0.85
-- Labels may reach the button edge; only text past it counts as overflow
-- (buttons sized to their own text, like tabs, fit exactly).
local PAD = 0
local LOCALES = { "enUS", "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local NON_LATIN = { ruRU = true, koKR = true, zhCN = true, zhTW = true }

-- fontString -> what we need to undo our changes and to measure:
--   button, size (base font size), applied (size we set), width (explicit box width or 0),
--   room/fixed (last measured room), cut (full text while cut), wrap/maxLines/widthSet (originals)
local labels = setmetatable({}, { __mode = "k" })
local hookedButtons = setmetatable({}, { __mode = "k" })

local function StringWidth(fs)
    if fs.GetUnboundedStringWidth then
        return fs:GetUnboundedStringWidth()
    end
    return fs:GetStringWidth()
end

local function Side(point)
    if point:find("LEFT", 1, true) then
        return "LEFT"
    elseif point:find("RIGHT", 1, true) then
        return "RIGHT"
    end
    return "CENTER"
end

-- Horizontal room the label has inside its button, and whether the label box
-- has a fixed width (anchored on both sides or given a width). nil when the
-- label is not inside the button, such as a checkbox caption drawn to its right.
local function LabelRoom(fs, button, data)
    local bl, br = button:GetLeft(), button:GetRight()
    local fl, fr = fs:GetLeft(), fs:GetRight()
    if not (bl and br and fl and fr) or br - bl <= 4 then
        return nil
    end
    local cx = (fl + fr) / 2
    if cx < bl or cx > br then
        return nil
    end
    -- A caption drawn above or below the button (an icon's name) is not inside it either.
    local bt, bb, ft, fb = button:GetTop(), button:GetBottom(), fs:GetTop(), fs:GetBottom()
    if bt and bb and ft and fb then
        local cy = (ft + fb) / 2
        if cy < bb or cy > bt then
            return nil
        end
    end

    local hasLeft, hasRight, side = false, false, "CENTER"
    for i = 1, fs:GetNumPoints() do
        side = Side((fs:GetPoint(i)))
        if side == "LEFT" then hasLeft = true elseif side == "RIGHT" then hasRight = true end
    end
    if (hasLeft and hasRight) or data.width > 0 then
        return fr - fl, true
    end
    if side == "LEFT" then
        return br - fl - PAD, false
    elseif side == "RIGHT" then
        return fr - bl - PAD, false
    end
    return 2 * math.min(cx - bl, br - cx) - 2 * PAD, false
end

local function SpillsBelow(fs, button)
    local fb, bb = fs:GetBottom(), button:GetBottom()
    return fb and bb and fb < bb - 1
end

local function Overflows(fs, button, room, fixed)
    if fixed then
        return fs:IsTruncated() or SpillsBelow(fs, button)
    end
    return StringWidth(fs) > room + 0.5
end

local function ShowFullText(button)
    for _, data in pairs(labels) do
        if data.cut and data.button == button then
            if GameTooltip:IsOwned(button) then
                GameTooltip:AddLine(data.cut, 1, 1, 1, true)
            else
                GameTooltip:SetOwner(button, "ANCHOR_TOP")
                GameTooltip:SetText(data.cut, 1, 1, 1, 1, true)
            end
            GameTooltip:Show()
            return
        end
    end
end

local function HideFullText(button)
    if GameTooltip:IsOwned(button) then
        GameTooltip:Hide()
    end
end

local function Restore(fs, data, file, flags)
    if data.applied ~= data.size then
        fs:SetFont(file, data.size, flags)
        data.applied = data.size
    end
    if data.cut then
        data.cut = nil
        fs:SetWordWrap(data.wrap)
        if data.maxLines and fs.SetMaxLines then
            fs:SetMaxLines(data.maxLines)
        end
        if data.widthSet then
            fs:SetWidth(data.width)
            data.widthSet = nil
        end
    end
end

function TextFit:FitLabel(fs)
    local data = labels[fs]
    local button = data and data.button
    if not (button and fs:IsVisible()) then
        return
    end
    local file, size, flags = fs:GetFont()
    if not (file and size) then
        return
    end
    -- The addon gave the label a new font since we last touched it: new base size.
    if math.abs(size - data.applied) > 0.25 then
        data.size, data.applied = size, size
    end
    Restore(fs, data, file, flags)

    local text = fs:GetText()
    if not text or text == "" then
        return
    end
    local room, fixed = LabelRoom(fs, button, data)
    if not room or room <= 0 then
        return
    end
    data.room, data.fixed = room, fixed
    if not Overflows(fs, button, room, fixed) then
        return
    end

    local minSize = math.floor(data.size * MIN_SCALE + 0.5)
    local current = data.size
    while current > minSize do
        current = current - 1
        fs:SetFont(file, current, flags)
        data.applied = current
        if not Overflows(fs, button, room, fixed) then
            return
        end
    end

    -- Still too long at the smallest size: cut it with an ellipsis.
    data.cut = text
    data.wrap = fs:CanWordWrap()
    data.maxLines = fs.GetMaxLines and fs:GetMaxLines() or nil
    if fixed and data.wrap and fs.SetMaxLines then
        local lines = math.max(fs:GetNumLines() or 1, 1)
        local lineHeight = fs:GetStringHeight() / lines
        local available = (fs:GetTop() or 0) - (button:GetBottom() or 0) - 1
        fs:SetMaxLines(math.max(1, math.floor(available / lineHeight)))
    else
        fs:SetWordWrap(false)
        if not fixed then
            fs:SetWidth(room)
            data.widthSet = true
        end
    end
    if not hookedButtons[button] then
        hookedButtons[button] = true
        button:HookScript("OnEnter", ShowFullText)
        button:HookScript("OnLeave", HideFullText)
    end
end

local function Track(fs, button)
    local data = labels[fs]
    if data then
        data.button = button
        return
    end
    local _, size = fs:GetFont()
    if not size then
        return
    end
    -- A box narrower or wider than its text means the code gave it a width; a
    -- truncated label also has one even when the text fills it exactly.
    local width, stringWidth = fs:GetWidth(), fs:GetStringWidth()
    local explicit = (width and stringWidth and math.abs(width - stringWidth) > 1) or fs:IsTruncated()
    labels[fs] = {
        button = button,
        size = size,
        applied = size,
        width = explicit and width or 0,
    }
    hooksecurefunc(fs, "SetText", function(self) TextFit:FitLabel(self) end)
    if fs.SetFormattedText then
        hooksecurefunc(fs, "SetFormattedText", function(self) TextFit:FitLabel(self) end)
    end
end

local function ForEachButtonLabel(root, fn)
    if not root or (root.IsForbidden and root:IsForbidden()) or not root:IsVisible() then
        return
    end
    if root:IsObjectType("Button") then
        for i = 1, select("#", root:GetRegions()) do
            local region = select(i, root:GetRegions())
            if region:IsObjectType("FontString") and region:IsVisible() then
                fn(region, root)
            end
        end
    end
    for i = 1, select("#", root:GetChildren()) do
        ForEachButtonLabel((select(i, root:GetChildren())), fn)
    end
end

function TextFit:FitAll(root)
    ForEachButtonLabel(root, function(fs, button)
        Track(fs, button)
        self:FitLabel(fs)
    end)
end

-- Layout settles one frame after a page is built, so fit on the next frame.
function TextFit:Schedule(root)
    if not root then
        return
    end
    C_Timer.After(0, function()
        if root:IsVisible() then
            self:FitAll(root)
        end
    end)
end

-- Fit a window's labels every time it is shown (by frame or global name).
function TextFit:Watch(target)
    local frame = type(target) == "string" and _G[target] or target
    if not frame or frame._ktTextFitWatched then
        return
    end
    frame._ktTextFitWatched = true
    frame:HookScript("OnShow", function(shown) TextFit:Schedule(shown) end)
    if frame:IsVisible() then
        self:Schedule(frame)
    end
end

local function HookInstaller()
    local installer = KT:GetModule("Installer", true)
    if not installer or installer._ktTextFitHooked then
        return
    end
    installer._ktTextFitHooked = true
    for name, method in pairs(installer) do
        if type(method) == "function" and (name == "OpenCurrentStep" or name:match("^Show.+Step$")) then
            hooksecurefunc(installer, name, function(self)
                TextFit:Schedule(self.frame)
            end)
        end
    end
end

-- Measuring ------------------------------------------------------------------

local measureFrame, measureString

local function Measure(text, file, size, flags, boxWidth, wrap)
    if not measureFrame then
        measureFrame = CreateFrame("Frame", nil, UIParent)
        measureFrame:Hide()
        measureString = measureFrame:CreateFontString(nil, "OVERLAY")
    end
    measureString:SetFont(file, size, flags)
    measureString:SetWordWrap(wrap and true or false)
    measureString:SetWidth(boxWidth or 0)
    measureString:SetText(text)
    return StringWidth(measureString), measureString:GetStringHeight()
end

local function ReverseLookup()
    local reverse = {}
    for key, value in pairs(ns.Locales.enUS or {}) do
        if type(key) == "string" then reverse[key] = key end
        if type(key) == "string" and type(value) == "string" then reverse[value] = key end
    end
    for key, value in pairs(KT:GetLocale() or {}) do
        if type(key) == "string" and type(value) == "string" then
            reverse[value] = key
        end
    end
    return reverse
end

local function FontFor(locale, ownFile)
    if NON_LATIN[locale] then
        return KT.GetLocalizedFontPathSafe(locale)
    end
    if KT:IsNonLatinLocale() then
        return KT.DEFAULT_FONT_PATH or ownFile
    end
    return ownFile
end

local function CheckLabel(fs, button, pageId, reverse, report, seen)
    local text = fs:GetText()
    local data = labels[fs]
    if data and data.cut then
        text = data.cut
    end
    if not text or text == "" or not text:find("%a") then
        return
    end
    local room, fixed
    if data and data.room then
        room, fixed = data.room, data.fixed
    else
        room, fixed = LabelRoom(fs, button, data or { width = 0 })
    end
    if not room or room <= 0 then
        return
    end
    local key = reverse[text]
    if not key then
        if not seen["?" .. text] then
            seen["?" .. text] = true
            report.unmapped[#report.unmapped + 1] = { page = pageId, text = text }
        end
        return
    end
    local id = key .. "\0" .. math.floor(room)
    if seen[id] then
        return
    end
    seen[id] = true
    report.labels = report.labels + 1

    local file, size, flags = fs:GetFont()
    size = data and data.size or size
    local wrap = fixed and (data and data.cut and data.wrap or fs:CanWordWrap())
    local roomH
    if wrap then
        local top, bottom = fs:GetTop(), button:GetBottom()
        roomH = top and bottom and (top - bottom - 1)
    end

    for _, locale in ipairs(LOCALES) do
        local translated = ns.Locales[locale] and ns.Locales[locale][key] or key
        if type(translated) == "string" then
            local font = FontFor(locale, file)
            local w, h = Measure(translated, font, size, flags, fixed and room or nil, wrap)
            local tooWide = w > room + 0.5 and not wrap
            local tooTall = roomH and h > roomH + 0.5
            if tooWide or tooTall then
                local ws, hs = Measure(translated, font, math.floor(size * MIN_SCALE + 0.5), flags, fixed and room or nil, wrap)
                local fitsSmall = not (ws > room + 0.5 and not wrap) and not (roomH and hs > roomH + 0.5)
                report.issues[#report.issues + 1] = {
                    page = pageId, key = key, locale = locale, text = translated,
                    axis = tooTall and "height" or "width",
                    need = math.floor((tooTall and h or w) + 0.5),
                    room = math.floor((tooTall and roomH or room) + 0.5),
                    result = fitsSmall and "shrink" or "cut",
                }
                report.byLocale[locale] = (report.byLocale[locale] or 0) + 1
            end
        end
    end
end

function TextFit:Scan()
    if InCombatLockdown() then
        KT:Print("TextFit: leave combat first.")
        return
    end
    local pages = {}
    for _, category in ipairs(ns.MENU_CATEGORIES or {}) do
        pages[#pages + 1] = ns.CATEGORY_OVERVIEW_PREFIX .. category.id
    end
    for _, page in ipairs(ns.pages or {}) do
        pages[#pages + 1] = page.id
    end

    local report = {
        date = date("%Y-%m-%d %H:%M"),
        client = GetLocale(),
        language = KT:GetActiveLanguage(),
        build = select(4, GetBuildInfo()),
        pages = #pages, labels = 0, issues = {}, unmapped = {}, byLocale = {},
    }
    local reverse = ReverseLookup()
    local seen = {}
    local index = 0

    local function Step()
        index = index + 1
        local pageId = pages[index]
        if not pageId then
            KT.db.global.textFitReport = report
            local parts = {}
            for _, locale in ipairs(LOCALES) do
                parts[#parts + 1] = locale .. "=" .. (report.byLocale[locale] or 0)
            end
            KT:Print(string.format("TextFit: %d pages, %d labels, %d issues (%s), %d dynamic labels. Saved; /reload to write it.",
                report.pages, report.labels, #report.issues, table.concat(parts, " "), #report.unmapped))
            return
        end
        if pageId:sub(1, #ns.CATEGORY_OVERVIEW_PREFIX) == ns.CATEGORY_OVERVIEW_PREFIX then
            KT:OpenMenu(pageId)
        else
            KT:OpenRegisteredPage(pageId, true)
        end
        C_Timer.After(0.4, function()
            local menu = KT.MenuPrincipal
            if menu and menu:IsVisible() then
                ForEachButtonLabel(menu, function(fs, button)
                    CheckLabel(fs, button, pageId, reverse, report, seen)
                end)
            end
            Step()
        end)
    end

    KT:Print(string.format("TextFit: measuring %d pages in %d languages...", #pages, #LOCALES))
    if not (KT.MenuPrincipal and KT.MenuPrincipal:IsShown()) then
        KT:OpenMenu(pages[1])
    end
    Step()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, loaded)
    if loaded == "KullThranUI_Installer" then
        HookInstaller()
    end
end)
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("KullThranUI_Installer") then
    HookInstaller()
end

SLASH_KULLTHRANUITEXTFIT1 = "/kuitextfit"
SlashCmdList.KULLTHRANUITEXTFIT = function(msg)
    if (msg or ""):lower():match("^%s*scan") then
        TextFit:Scan()
    else
        KT:Print("TextFit: /kuitextfit scan")
    end
end
