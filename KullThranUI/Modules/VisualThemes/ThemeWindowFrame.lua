local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

--[[
    ThemeWindowFrame.lua

    Outer frame of the active Visual Style around a KUI window (Bags, ...),
    built like the chat styles (KullThranUI_Chat/Modules/Chat_Styles.lua) and
    the minimap's square frame:
      forever  nine-slice of the bronze frame packaged in media\chat\chat_forever.tga
      retail   nine-slice of the grey frame packaged in media\chat\chat_retail.tga
      classic  the gold dialog edge (UI-DialogBox-Gold-Border), as a backdrop
      kui      nothing: the window keeps its own flat border
    The packaged art is cropped from each client's own atlases, so Retail and
    Forever look the same on either client. The frame sits just outside the
    window and never takes the mouse.
]]

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\chat\\"

-- rect = { x, y, w, h } in sheet pixels; corner = corner size in the sheet;
-- edge = drawn corner size; outset = how far the frame sits outside the window.
local FRAMES = {
    forever = { file = MEDIA .. "chat_forever.tga", w = 512, h = 256, rect = { 35, 1, 80, 80 },
        corner = 14, edge = 10, outset = 5 },
    retail = { file = MEDIA .. "chat_retail.tga", w = 256, h = 256, rect = { 1, 1, 22, 22 },
        corner = 7, edge = 8, outset = 3 },
}
local CLASSIC = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 16, outset = 6 }

local SLICES = { "TL", "T", "TR", "L", "R", "BL", "B", "BR" }

local function EnsureFrame(window)
    local frame = window._ktThemeWindowFrame
    if frame then return frame end
    frame = CreateFrame("Frame", nil, window, "BackdropTemplate")
    frame:EnableMouse(false)
    frame.slices = {}
    for _, name in ipairs(SLICES) do
        frame.slices[name] = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    end
    window._ktThemeWindowFrame = frame
    return frame
end

local function LayoutSlices(frame, def)
    local x, y, w, h = def.rect[1], def.rect[2], def.rect[3], def.rect[4]
    local c = def.corner
    local L, R, T, B = x / def.w, (x + w) / def.w, y / def.h, (y + h) / def.h
    local cl, cr = (x + c) / def.w, (x + w - c) / def.w
    local ct, cb = (y + c) / def.h, (y + h - c) / def.h
    local coords = {
        TL = { L, cl, T, ct }, T = { cl, cr, T, ct }, TR = { cr, R, T, ct },
        L = { L, cl, ct, cb }, R = { cr, R, ct, cb },
        BL = { L, cl, cb, B }, B = { cl, cr, cb, B }, BR = { cr, R, cb, B },
    }
    local s, e = frame.slices, def.edge
    for _, name in ipairs(SLICES) do
        s[name]:SetTexture(def.file)
        s[name]:SetTexCoord(unpack(coords[name]))
        s[name]:SetVertexColor(1, 1, 1, 1)
        s[name]:ClearAllPoints()
        s[name]:Show()
    end
    s.TL:SetSize(e, e); s.TL:SetPoint("TOPLEFT")
    s.TR:SetSize(e, e); s.TR:SetPoint("TOPRIGHT")
    s.BL:SetSize(e, e); s.BL:SetPoint("BOTTOMLEFT")
    s.BR:SetSize(e, e); s.BR:SetPoint("BOTTOMRIGHT")
    s.T:SetPoint("TOPLEFT", s.TL, "TOPRIGHT"); s.T:SetPoint("BOTTOMRIGHT", s.TR, "BOTTOMLEFT")
    s.B:SetPoint("TOPLEFT", s.BL, "TOPRIGHT"); s.B:SetPoint("BOTTOMRIGHT", s.BR, "BOTTOMLEFT")
    s.L:SetPoint("TOPLEFT", s.TL, "BOTTOMLEFT"); s.L:SetPoint("BOTTOMRIGHT", s.BL, "TOPRIGHT")
    s.R:SetPoint("TOPLEFT", s.TR, "BOTTOMLEFT"); s.R:SetPoint("BOTTOMRIGHT", s.BR, "TOPRIGHT")
end

-- Frames `window` for `styleKey` (default: the rendered Visual Style).
-- Returns the frame, or nil when the style draws none (KUI Style).
function KT.VisualThemes:ApplyWindowFrame(window, styleKey)
    if not (window and window.CreateTexture) then return nil end
    styleKey = styleKey or (self.GetRenderedTheme and self:GetRenderedTheme()) or "kui"
    local def, classic = FRAMES[styleKey], styleKey == "classic"
    local frame = window._ktThemeWindowFrame
    if not def and not classic then
        if frame then frame:Hide() end
        return nil
    end
    frame = EnsureFrame(window)
    for _, name in ipairs(SLICES) do frame.slices[name]:Hide() end
    if frame.SetBackdrop then frame:SetBackdrop(nil) end

    local outset = def and def.outset or CLASSIC.outset
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", window, "TOPLEFT", -outset, outset)
    frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", outset, -outset)
    -- Above the window's own panels: only its outer few pixels overlap them.
    frame:SetFrameStrata(window:GetFrameStrata())
    frame:SetFrameLevel((window:GetFrameLevel() or 0) + 20)

    if def then
        LayoutSlices(frame, def)
    elseif frame.SetBackdrop then
        frame:SetBackdrop({ edgeFile = CLASSIC.edgeFile, edgeSize = CLASSIC.edgeSize })
        frame:SetBackdropBorderColor(1, 1, 1, 1)
    end
    frame:Show()
    return frame
end

-------------------------------------------------------------------------------
--  Per-module style choice (like the Chat and Cast Bar styles)
--  db.styleByTheme[<visual style>] = "kui" | "forever" | "retail" | "classic";
--  without a choice every Visual Style uses its own look.
-------------------------------------------------------------------------------
local STYLE_ORDER = { "kui", "forever", "retail", "classic" }
local STYLE_LABELS = { kui = "KUI Style", forever = "Forever", retail = "Retail", classic = "Classic" }
local STYLE_ACCENTS = { forever = { 0.862745, 0.521569, 0.376471 }, classic = { 1.00, 0.82, 0.10 } }
KT.VisualThemes.WINDOW_STYLE_ORDER = STYLE_ORDER

local function ActiveTheme(vt)
    return (vt.GetRenderedTheme and vt:GetRenderedTheme()) or "kui"
end

function KT.VisualThemes:ResolveModuleStyle(db)
    local theme = ActiveTheme(self)
    local map = db and db.styleByTheme
    local choice = type(map) == "table" and map[theme] or nil
    if STYLE_LABELS[choice] then return choice end
    return STYLE_LABELS[theme] and theme or "kui"
end

function KT.VisualThemes:SetModuleStyle(db, key)
    if not db then return end
    db.styleByTheme = type(db.styleByTheme) == "table" and db.styleByTheme or {}
    db.styleByTheme[ActiveTheme(self)] = STYLE_LABELS[key] and key or nil
end

local function StyleAccent(key)
    if STYLE_ACCENTS[key] then return unpack(STYLE_ACCENTS[key]) end
    if key == "retail" then
        local _, class = UnitClass("player")
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333
end

-- One card per style (icon + name), the selected one framed in its accent.
-- Picking a card stores it for the current Visual Style and calls onPick().
-- Returns the y below the cards.
function KT.VisualThemes:AddStyleCards(parent, y, title, db, onPick)
    local vt = self
    local LText = KT.Options and KT.Options.LText or function(t) return t end
    local icons = (KT.CastBarStyles and KT.CastBarStyles.styleIcons) or {}
    local caption = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    caption:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -y)
    caption:SetText(title or "")
    caption:SetTextColor(1, 1, 1, 1)
    y = y + 24
    local cards = {}
    local function Refresh()
        local current = vt:ResolveModuleStyle(db)
        for key, card in pairs(cards) do
            local r, g, b = StyleAccent(key)
            local selected = key == current
            local t = selected and 2 or 1
            card.edges[1]:SetHeight(t); card.edges[2]:SetHeight(t)
            card.edges[3]:SetWidth(t); card.edges[4]:SetWidth(t)
            for _, edge in ipairs(card.edges) do
                if selected then edge:SetColorTexture(r, g, b, 1) else edge:SetColorTexture(r * 0.35, g * 0.35, b * 0.35, 0.8) end
            end
            card.bg:SetColorTexture(selected and r * 0.18 or 0.05, selected and g * 0.18 or 0.05, selected and b * 0.18 or 0.06, 0.95)
            card.label:SetTextColor(selected and 1 or 0.7, selected and 1 or 0.7, selected and 1 or 0.7)
        end
    end
    for index, key in ipairs(STYLE_ORDER) do
        local card = CreateFrame("Button", nil, parent)
        card:SetSize(128, 62)
        card:SetPoint("TOPLEFT", parent, "TOPLEFT", 4 + (index - 1) * 138, -y)
        card.bg = card:CreateTexture(nil, "BACKGROUND")
        card.bg:SetAllPoints()
        card.edges = {}
        for i = 1, 4 do card.edges[i] = card:CreateTexture(nil, "BORDER") end
        card.edges[1]:SetPoint("TOPLEFT"); card.edges[1]:SetPoint("TOPRIGHT")
        card.edges[2]:SetPoint("BOTTOMLEFT"); card.edges[2]:SetPoint("BOTTOMRIGHT")
        card.edges[3]:SetPoint("TOPLEFT"); card.edges[3]:SetPoint("BOTTOMLEFT")
        card.edges[4]:SetPoint("TOPRIGHT"); card.edges[4]:SetPoint("BOTTOMRIGHT")
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(28, 28)
        card.icon:SetPoint("TOP", 0, -7)
        card.icon:SetTexture(icons[key] or icons.kui)
        card.label = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.label:SetPoint("BOTTOM", 0, 8)
        card.label:SetText(LText(STYLE_LABELS[key]))
        card:SetScript("OnClick", function()
            vt:SetModuleStyle(db, key)
            Refresh()
            if onPick then onPick(key) end
        end)
        card:SetScript("OnEnter", function(cardFrame)
            if vt:ResolveModuleStyle(db) ~= key then
                local r, g, b = StyleAccent(key)
                for _, edge in ipairs(cardFrame.edges) do edge:SetColorTexture(r * 0.7, g * 0.7, b * 0.7, 1) end
            end
        end)
        card:SetScript("OnLeave", Refresh)
        cards[key] = card
    end
    Refresh()
    return y + 62 + 14
end
