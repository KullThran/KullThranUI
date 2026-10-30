-------------------------------------------------------------------------------
--  Chat styles: three Blizzard-art skins for the KUI chat window, next to the
--  original KUI Style.
--
--    kui      the existing flat glass look (nothing is drawn by this file)
--    classic  the old Blizzard chat: translucent black, classic tabs, the old input bar,
--             the round chat icons and the red panel button
--    retail   Blizzard's modern frame art (grey), class-colour accent
--    forever  Forever's bronze frame art, bronze accent
--
--  Retail / Forever are kept CLEAN: one thin border per element, nothing doubled.
--     - the chat and the input bar are framed by Blizzard's tooltip nine-slice (Forever asks for
--       its "-c60" bronze version, falling back to the plain one tinted bronze); when the client
--       has neither, a single 1 px notched border is drawn instead;
--     - tabs and buttons are a dark body with one thin border (the active tab in the accent).
--
--  Whispers keep their own colours: whisper tabs (shared and per-player / Battle.net
--  threads) take their border from their own text colour, and the whisper strip buttons
--  wear the style's square button with their pink / blue icon (ApplyWhisperButtons).
--
--  Setting: chat.styleByTheme[<visual style>] = "kui" | "classic" | "retail" | "forever";
--  without a choice every Visual Style uses its own look.   Quick test: /ktchatstyle <style>
-------------------------------------------------------------------------------
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:GetModule("Chat", true)
if not Mod then return end

local S = {}
Mod.Styles = S

local floor, max, min = math.floor, math.max, math.min
local CreateFrame = _G.CreateFrame

S.ORDER = { "kui", "forever", "retail", "classic" }
S.LABELS = { kui = "KUI Style", classic = "Classic", retail = "Retail", forever = "Forever" }

-------------------------------------------------------------------------------
--  Style definitions
-------------------------------------------------------------------------------
local CHATFRAME = "Interface\\ChatFrame\\"
local STYLES = {
    classic = {
        classic = true,
        fill = { color = { 0, 0, 0 }, alpha = 0.5 },
        accent = { 1.00, 0.82, 0.10 },
        tabs = { CHATFRAME .. "ChatFrameTab-BGLeft", CHATFRAME .. "ChatFrameTab-BGMid", CHATFRAME .. "ChatFrameTab-BGRight" },
        tabsSelected = { CHATFRAME .. "ChatFrameTab-SelectedLeft", CHATFRAME .. "ChatFrameTab-SelectedMid",
            CHATFRAME .. "ChatFrameTab-SelectedRight" },
        input = { left = CHATFRAME .. "UI-ChatInputBorder-Left", mid = CHATFRAME .. "UI-ChatInputBorder-Mid",
            right = CHATFRAME .. "UI-ChatInputBorder-Right" },
        -- Sidebar / scroll icons by their position in the sidebar (see SIDEBAR_KEYS)
        icons = {
            friendlist = CHATFRAME .. "UI-ChatIcon-BattleBro-Up",
            voicechat = "Interface\\Common\\VoiceChat-Speaker",
            quickchat = CHATFRAME .. "UI-ChatIcon-Chat-Up",
            search = "Interface\\Common\\UI-Searchbox-Icon",
            copychat = CHATFRAME .. "UI-ChatIcon-Share",
            confrig = "Interface\\Buttons\\UI-OptionsButton",
            trash = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
            ["ui-chaticon-scrolldown-up"] = CHATFRAME .. "UI-ChatIcon-ScrollEnd-Up",
        },
        -- Classic art that is plain white gets the classic gold
        iconTint = { search = { 1.00, 0.82, 0.10 } },
    },
    retail = {
        pack = "retail",
        iconColor = { 0.86, 0.88, 0.92 },
        suffix = "",
        fill = { color = { 0.02, 0.022, 0.03 }, alpha = 0.7 },
        accent = nil,  -- the player's class colour (see S.Accent)
    },
    forever = {
        pack = "forever",
        suffix = "-c60",
        fill = { color = { 0.035, 0.026, 0.02 }, alpha = 0.82 },
        accent = { 0.862745, 0.521569, 0.376471 },
    },
}
S.STYLES = STYLES

local function HasAtlas(name)
    return name and _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(name) ~= nil
end

local function AtlasSize(name)
    local info = name and _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(name)
    if not info then return 0, 0 end
    return info.width or 0, info.height or 0
end

local function IsForeverClient()
    local vt = KT.VisualThemes
    return vt and vt.GetClientFlavor and vt:GetClientFlavor() == "forever" or false
end

-- The art is packaged with the addon (cropped from each client's own atlases), so Retail and
-- Forever look the same on either client. rects = { x, y, w, h } in pixels of the sheet.
local PACK_DIR = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\chat\\"
local PACKS = {
    forever = {
        file = PACK_DIR .. "chat_forever.tga", w = 512, h = 256,
        corner = 14, scale = 0.42,           -- frame corner (sheet px) and how much the frame is shrunk
        tabCap = 8, drop = { 5, 6 }, lift = 0.05, selectedReplaces = false,
        rects = {
            fill = { 1, 1, 32, 32 }, frame = { 35, 1, 80, 80 },
            tab = { 117, 1, 96, 30 }, tabHover = { 215, 1, 96, 30 }, tabSelected = { 313, 1, 96, 30 },
            squareNormal = { 411, 1, 34, 34 }, squareHover = { 447, 1, 34, 34 }, squarePressed = { 1, 83, 34, 34 },
            wideNormal = { 37, 83, 46, 34 }, wideHover = { 85, 83, 46, 34 }, widePressed = { 133, 83, 46, 34 },
        },
    },
    retail = {
        file = PACK_DIR .. "chat_retail.tga", w = 256, h = 256,
        corner = 7, scale = 1,
        tabCap = 35, drop = { 0, 2 }, lift = 0, selectedReplaces = true, flipV = true,
        rects = {
            frame = { 1, 1, 22, 22 },
            tab = { 43, 1, 88, 36 }, tabSelected = { 133, 1, 88, 42 },
            squareNormal = { 1, 45, 34, 34 }, squareHover = { 37, 45, 34, 34 }, squarePressed = { 73, 45, 34, 34 },
            wideNormal = { 109, 45, 46, 34 }, wideHover = { 157, 45, 46, 34 }, widePressed = { 205, 45, 46, 34 },
        },
    },
}

-- file, left, right, top, bottom (0..1), width, height of one piece of a pack
local function PackRect(pack, key)
    local p = pack and PACKS[pack]
    local r = p and p.rects[key]
    if not r then return nil end
    return p.file, r[1] / p.w, (r[1] + r[3]) / p.w, r[2] / p.h, (r[2] + r[4]) / p.h, r[3], r[4]
end

-- Texture coordinates of an atlas inside its file, so pieces of it can be drawn on their own.
local function AtlasRect(name)
    local info = name and _G.C_Texture and _G.C_Texture.GetAtlasInfo and _G.C_Texture.GetAtlasInfo(name)
    if not (info and (info.file or info.filename)) then return nil end
    return info.file or info.filename, info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord,
        info.width, info.height
end

-- "name-c60" when the client has it, else the plain atlas (tinted by the caller); nil if neither.
-- Second return: true when the plain fallback was used for a suffixed request.
local function Pick(name, suffix)
    if suffix and suffix ~= "" and HasAtlas(name .. suffix) then return name .. suffix, false end
    if HasAtlas(name) then return name, (suffix and suffix ~= "") and true or false end
    return nil, false
end

-- A piece of a style's pack as a { file, l, r, t, b } reference (nil when the pack lacks it).
local function PackRef(pack, key)
    local file, l, r, t, b = PackRect(pack, key)
    if not file then return nil end
    return { file = file, l = l, r = r, t = t, b = b }
end

local function ApplyArt(texture, ref)
    if type(ref) == "table" then
        texture:SetTexture(ref.file)
        texture:SetTexCoord(ref.l, ref.r, ref.t, ref.b)
    else
        texture:SetAtlas(ref, false)
    end
end

local function ActiveTheme()
    local vt = KT.VisualThemes
    local theme = vt and vt.GetRenderedTheme and vt:GetRenderedTheme()
    return theme or "kui"
end

-- Every Visual Style remembers its own chat style (chat.styleByTheme); until the player picks
-- one, a style simply uses its own look (Forever -> Forever, KUI -> KUI ...).
function S.Resolve()
    local db = KT.db and KT.db.profile and KT.db.profile.chat
    local theme = ActiveTheme()
    local map = db and db.styleByTheme
    local choice = type(map) == "table" and map[theme] or nil
    if choice == "kui" or STYLES[choice] then return choice end
    if STYLES[theme] then return theme end
    return "kui"
end

-- Accent colour of a style: fixed for Classic (gold) and Forever (bronze); Retail follows
-- the player's class like the rest of the Retail look.
function S.Accent(key)
    local def = STYLES[key]
    if def and def.accent then return def.accent[1], def.accent[2], def.accent[3] end
    local _, class = UnitClass("player")
    local color = class and (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if color then return color.r, color.g, color.b end
    return 1.00, 0.82, 0.10
end

-- Icon tint: the accent washed towards white, so the icons stay readable on the metal art.
local function IconTint(key)
    local def = STYLES[key]
    if def and def.iconColor then return def.iconColor[1], def.iconColor[2], def.iconColor[3] end
    local r, g, b = S.Accent(key)
    return r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55
end

-------------------------------------------------------------------------------
--  Solid body: dark fill + coloured border (the guaranteed layer)
-------------------------------------------------------------------------------
local function EnsureBox(frame)
    local box = frame.KT_StyleBox
    if box then return box end
    box = {}
    box.fill = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    box.fill:SetAllPoints()
    box.edges = {}
    for i = 1, 4 do box.edges[i] = frame:CreateTexture(nil, "BORDER", nil, 6) end
    box.edges[1]:SetPoint("TOPLEFT", 2, 0); box.edges[1]:SetPoint("TOPRIGHT", -2, 0)
    box.edges[2]:SetPoint("BOTTOMLEFT", 2, 0); box.edges[2]:SetPoint("BOTTOMRIGHT", -2, 0)
    box.edges[3]:SetPoint("TOPLEFT", 0, -2); box.edges[3]:SetPoint("BOTTOMLEFT", 0, 2)
    box.edges[4]:SetPoint("TOPRIGHT", 0, -2); box.edges[4]:SetPoint("BOTTOMRIGHT", 0, 2)
    frame.KT_StyleBox = box
    return box
end

-- border {r,g,b,a} ; fill {r,g,b,a} or nil ; skipBottom leaves the bottom edge open
local function PaintBox(frame, border, fill, thickness, skipBottom)
    local box = EnsureBox(frame)
    local t = thickness or 1
    box.edges[1]:SetHeight(t); box.edges[2]:SetHeight(t)
    box.edges[3]:SetWidth(t); box.edges[4]:SetWidth(t)
    -- an open bottom (the active tab) lets the side lines run down to the edge
    box.edges[3]:SetPoint("BOTTOMLEFT", 0, skipBottom and 0 or 2)
    box.edges[4]:SetPoint("BOTTOMRIGHT", 0, skipBottom and 0 or 2)
    for i, edge in ipairs(box.edges) do
        edge:SetColorTexture(border[1], border[2], border[3], border[4] or 1)
        edge:SetShown(not (skipBottom and i == 2))
    end
    if fill then
        box.fill:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
        box.fill:Show()
    else
        box.fill:Hide()
    end
end

local function HideBox(frame)
    local box = frame.KT_StyleBox
    if not box then return end
    box.fill:Hide()
    for _, edge in ipairs(box.edges) do edge:Hide() end
end

-------------------------------------------------------------------------------
--  Nine-slice atlas frame (drawn over the solid body when the client has the atlas)
-------------------------------------------------------------------------------
local PIECES = { "tl", "tr", "bl", "br", "top", "bottom", "left", "right" }

local function PieceName(base, key)
    if key == "tl" then return base .. "-cornertopleft" end
    if key == "tr" then return base .. "-cornertopright" end
    if key == "bl" then return base .. "-cornerbottomleft" end
    if key == "br" then return base .. "-cornerbottomright" end
    if key == "top" then return "_" .. base .. "-edgetop" end
    if key == "bottom" then return "_" .. base .. "-edgebottom" end
    if key == "left" then return "!" .. base .. "-edgeleft" end
    if key == "right" then return "!" .. base .. "-edgeright" end
end

local function NewPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:EnableMouse(false)
    panel.pieces = {}
    for _, key in ipairs(PIECES) do panel.pieces[key] = panel:CreateTexture(nil, "BORDER", nil, 3) end
    panel.fill = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
    -- the solid border lives on its own child frame so it can sit above the atlas pieces
    panel.body = CreateFrame("Frame", nil, panel)
    panel.body:SetAllPoints()
    panel.body:SetFrameLevel(panel:GetFrameLevel() + 1)
    return panel
end

local BZ = { "tl", "t", "tr", "l", "r", "bl", "b", "br" }

local function HidePanel(panel)
    for _, key in ipairs(PIECES) do panel.pieces[key]:Hide() end
    panel.fill:Hide()
    HideBox(panel.body)
    if panel.classicBox then panel.classicBox:Hide() end
    if panel.bz then
        for _, key in ipairs(BZ) do panel.bz[key]:Hide() end
        panel.bzFill:Hide()
    end
end

-- Returns true when the packaged frame could be drawn.
local function PackPanel(panel, fill, packName)
    local pack = PACKS[packName]
    local file, l, r, t, b, w, h = PackRect(packName, "frame")
    local ffile, fl, fr, ft, fb = PackRect(packName, "fill")
    if not file then return false end
    if not panel.bz then
        panel.bz = {}
        for _, key in ipairs(BZ) do panel.bz[key] = panel:CreateTexture(nil, "BORDER", nil, 4) end
        panel.bzFill = panel:CreateTexture(nil, "BACKGROUND", nil, -2)
    end
    local c = pack.corner
    local uw, vh = (r - l), (b - t)
    local cu, cv = uw * c / w, vh * c / h
    local xs = { l, l + cu, r - cu, r }
    local ys = { t, t + cv, b - cv, b }
    local rects = {
        tl = { xs[1], xs[2], ys[1], ys[2] }, t = { xs[2], xs[3], ys[1], ys[2] }, tr = { xs[3], xs[4], ys[1], ys[2] },
        l = { xs[1], xs[2], ys[2], ys[3] }, r = { xs[3], xs[4], ys[2], ys[3] },
        bl = { xs[1], xs[2], ys[3], ys[4] }, b = { xs[2], xs[3], ys[3], ys[4] }, br = { xs[3], xs[4], ys[3], ys[4] },
    }
    local z = c * pack.scale
    local P = panel.bz
    for _, key in ipairs(BZ) do
        local q = rects[key]
        P[key]:SetTexture(file)
        P[key]:SetTexCoord(q[1], q[2], q[3], q[4])
        P[key]:SetVertexColor(1, 1, 1, 1)
        P[key]:ClearAllPoints()
        P[key]:Show()
    end
    P.tl:SetSize(z, z); P.tl:SetPoint("TOPLEFT")
    P.tr:SetSize(z, z); P.tr:SetPoint("TOPRIGHT")
    P.bl:SetSize(z, z); P.bl:SetPoint("BOTTOMLEFT")
    P.br:SetSize(z, z); P.br:SetPoint("BOTTOMRIGHT")
    P.t:SetPoint("TOPLEFT", P.tl, "TOPRIGHT"); P.t:SetPoint("BOTTOMRIGHT", P.tr, "BOTTOMLEFT")
    P.b:SetPoint("TOPLEFT", P.bl, "TOPRIGHT"); P.b:SetPoint("BOTTOMRIGHT", P.br, "BOTTOMLEFT")
    P.l:SetPoint("TOPLEFT", P.tl, "BOTTOMLEFT"); P.l:SetPoint("BOTTOMRIGHT", P.bl, "TOPRIGHT")
    P.r:SetPoint("TOPLEFT", P.tr, "BOTTOMLEFT"); P.r:SetPoint("BOTTOMRIGHT", P.br, "TOPRIGHT")

    -- dark interior: the pack's own background when it has one, else the style's flat colour
    local bgFill = panel.bzFill
    if ffile then
        bgFill:SetTexture(ffile)
        bgFill:SetTexCoord(fl, fr, ft, fb)
        bgFill:SetVertexColor(1, 1, 1, 1)
    else
        bgFill:SetColorTexture(fill.color[1], fill.color[2], fill.color[3], 1)
    end
    bgFill:SetAlpha(fill.alpha or 1)
    bgFill:ClearAllPoints()
    bgFill:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -2)
    bgFill:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
    bgFill:Show()
    return true
end

-- Returns the atlas family that can be fully drawn: the suffixed one, else the plain one
-- (tinted), else nil.
local function FrameFamily(base, suffix)
    for _, candidate in ipairs({ { suffix or "", false }, { "", (suffix and suffix ~= "") and true or false } }) do
        local complete = true
        for _, key in ipairs(PIECES) do
            if not HasAtlas(PieceName(base, key) .. candidate[1]) then complete = false end
        end
        if complete then return candidate[1], candidate[2] end
    end
    return nil
end

local function LayoutPanel(panel, suffix, fill, borderColor, borderThickness, pack)
    HidePanel(panel)
    if pack and PackPanel(panel, fill, pack) then return end
    panel.fill:SetColorTexture(fill.color[1], fill.color[2], fill.color[3], 1)
    panel.fill:SetAlpha(fill.alpha or 1)
    panel.fill:ClearAllPoints()
    panel.fill:SetAllPoints(panel)
    panel.fill:Show()

    local family, tinted = FrameFamily("tooltip-nineslice", suffix)
    if tinted and IsForeverClient() then tinted = false end  -- already bronze there
    if not family then
        PaintBox(panel.body, borderColor, nil, 1)  -- no atlas in this client: one thin border
        return
    end
    local p = panel.pieces
    local r, g, b = borderColor[1], borderColor[2], borderColor[3]
    for _, key in ipairs(PIECES) do
        local name = PieceName("tooltip-nineslice", key) .. family
        p[key]:SetAtlas(name, false)
        if tinted then p[key]:SetVertexColor(r, g, b, 1) else p[key]:SetVertexColor(1, 1, 1, 1) end
        p[key]:Show()
    end
    local function sz(key) return AtlasSize(PieceName("tooltip-nineslice", key) .. family) end
    local tlw, tlh = sz("tl"); local trw, trh = sz("tr"); local blw, blh = sz("bl"); local brw, brh = sz("br")
    p.tl:ClearAllPoints(); p.tl:SetSize(tlw, tlh); p.tl:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    p.tr:ClearAllPoints(); p.tr:SetSize(trw, trh); p.tr:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    p.bl:ClearAllPoints(); p.bl:SetSize(blw, blh); p.bl:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    p.br:ClearAllPoints(); p.br:SetSize(brw, brh); p.br:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    local _, topH = sz("top"); local _, bottomH = sz("bottom"); local leftW = sz("left"); local rightW = sz("right")
    p.top:ClearAllPoints()
    p.top:SetPoint("TOPLEFT", p.tl, "TOPRIGHT", 0, 0); p.top:SetPoint("TOPRIGHT", p.tr, "TOPLEFT", 0, 0)
    p.top:SetHeight(topH)
    p.bottom:ClearAllPoints()
    p.bottom:SetPoint("BOTTOMLEFT", p.bl, "BOTTOMRIGHT", 0, 0); p.bottom:SetPoint("BOTTOMRIGHT", p.br, "BOTTOMLEFT", 0, 0)
    p.bottom:SetHeight(bottomH)
    p.left:ClearAllPoints()
    p.left:SetPoint("TOPLEFT", p.tl, "BOTTOMLEFT", 0, 0); p.left:SetPoint("BOTTOMLEFT", p.bl, "TOPLEFT", 0, 0)
    p.left:SetWidth(leftW)
    p.right:ClearAllPoints()
    p.right:SetPoint("TOPRIGHT", p.tr, "BOTTOMRIGHT", 0, 0); p.right:SetPoint("BOTTOMRIGHT", p.br, "TOPRIGHT", 0, 0)
    p.right:SetWidth(rightW)
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local GLASS_FIELDS = {
    "KT_GlassTop", "KT_GlassBottom", "KT_LeftShade", "KT_BackdropFade", "KT_ContentTopGlow",
    "KT_ContentBottomShade", "KT_FooterGlow", "KT_InputGlow",
}

local function SetGlass(window, visible)
    for _, key in ipairs(GLASS_FIELDS) do
        local texture = window[key]
        if texture then texture:SetAlpha(visible and 1 or 0) end
    end
end

local function ClearFlatBackdrops(window)
    window:SetBackdropColor(0, 0, 0, 0)
    for _, key in ipairs({ "KT_Content", "KT_Footer", "KT_InputHost" }) do
        local frame = window[key]
        if frame and frame.SetBackdropColor then
            frame:SetBackdropColor(0, 0, 0, 0)
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end
end

local FOOTER_SPACE = 33  -- the chat frame stops above the input bar, like the native chat

-- Retail / Forever frame the chat area: the text must stay inside that frame, so it ends higher.
-- Every chat frame (the main one and the native tab frames) reads its insets from here.
if type(Mod.GetChatContentInsets) == "function" and not Mod._ktStyleInsets then
    Mod._ktStyleInsets = true
    local original = Mod.GetChatContentInsets
    Mod.GetChatContentInsets = function(self, parent)
        local left, top, right, bottom = original(self, parent)
        local def = STYLES[S.lastKey or ""]
        if def then return left + 2, top - 2, right - 2, bottom + 4 end
        return left, top, right, bottom
    end
end

function S:ApplyWindow(window, key, def)
    local main = window.KT_StyleMain
    if not main then
        main = NewPanel(window)
        main:SetFrameLevel(window:GetFrameLevel())
        window.KT_StyleMain = main
    end
    local input = window.KT_StyleInputPanel
    if not input and window.KT_InputHost then
        input = NewPanel(window.KT_InputHost)
        input:SetFrameLevel(window.KT_InputHost:GetFrameLevel())
        window.KT_StyleInputPanel = input
    end
    -- styled input bar runs right up to the send button (KUI keeps its wider gap)
    local host = window.KT_InputHost
    if host and window.KT_Footer then
        host:ClearAllPoints()
        host:SetPoint("TOPLEFT", window.KT_Footer, "TOPLEFT", 0, -2)
        host:SetPoint("BOTTOMRIGHT", window.KT_Footer, "BOTTOMRIGHT", def and -46 or -58, 0)
    end
    if not def then
        main:Hide()
        if input then input:Hide() end
        SetGlass(window, true)
        return
    end

    main:Show()
    if def.classic then
        -- Classic: the chat area is the classic tooltip plate with its grey rim (not KUI's flat
        -- glass); the bar, tabs and buttons carry the rest of the classic art.
        main:ClearAllPoints()
        main:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
        main:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, FOOTER_SPACE)
        HidePanel(main)
        -- Same look as the classic input bar: its rounded rim, cut into a frame (corners from the
        -- end pieces, top / bottom from the middle piece, sides from a thin strip of an end piece).
        local box = main.classicBox
        if not box then
            box = CreateFrame("Frame", nil, main)
            box:EnableMouse(false)
            box:SetFrameLevel(main:GetFrameLevel())
            box:SetAllPoints(main)
            box.fill = box:CreateTexture(nil, "BACKGROUND", nil, -1)
            box.fill:SetColorTexture(0, 0, 0, 1)
            box.fill:SetPoint("TOPLEFT", 3, -3)
            box.fill:SetPoint("BOTTOMRIGHT", -3, 3)
            box.fill:SetAlpha(0.72)
            local function piece(file, l, r, t, b)
                local tex = box:CreateTexture(nil, "BORDER", nil, 3)
                tex:SetTexture(file)
                tex:SetTexCoord(l, r, t, b)
                return tex
            end
            local L, M, R = def.input.left, def.input.mid, def.input.right
            local e = 16 / 256
            local c = 16
            local tl = piece(L, 0, e, 0, 0.5); tl:SetSize(c, c); tl:SetPoint("TOPLEFT")
            local bl = piece(L, 0, e, 0.5, 1); bl:SetSize(c, c); bl:SetPoint("BOTTOMLEFT")
            local tr = piece(R, 1 - e, 1, 0, 0.5); tr:SetSize(c, c); tr:SetPoint("TOPRIGHT")
            local br = piece(R, 1 - e, 1, 0.5, 1); br:SetSize(c, c); br:SetPoint("BOTTOMRIGHT")
            local top = piece(M, 0, 1, 0, 0.5)
            top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
            local bottom = piece(M, 0, 1, 0.5, 1)
            bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
            local left = piece(L, 0, e, 0.47, 0.53)
            left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
            local right = piece(R, 1 - e, 1, 0.47, 0.53)
            right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
            main.classicBox = box
        end
        box:Show()
        if input then input:Hide() end
    else
        local r, g, b = S.Accent(key)
        local border = { r * 0.9, g * 0.9, b * 0.9, 1 }
        main:ClearAllPoints()
        main:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
        main:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, FOOTER_SPACE)
        LayoutPanel(main, def.suffix, def.fill, border, 1, def.pack)
        if input then
            input:ClearAllPoints()
            input:SetPoint("TOPLEFT", window.KT_InputHost, "TOPLEFT", 0, 0)
            input:SetPoint("BOTTOMRIGHT", window.KT_InputHost, "BOTTOMRIGHT", 0, 0)
            LayoutPanel(input, def.suffix, def.fill, border, 1, def.pack)
            input:Show()
        end
    end
    SetGlass(window, false)
    ClearFlatBackdrops(window)
end

-------------------------------------------------------------------------------
--  Tabs
-------------------------------------------------------------------------------
local function IsWhisperTab(index)
    local info = Mod.tabs and Mod.tabs[index]
    if not info then return false end
    if info.KT_WhisperThreadKey or info.whisperTarget then return true end
    return Mod.IsSharedWhisperTab and Mod:IsSharedWhisperTab(info) or false
end

local function EnsureTabArt(tab)
    local art = tab.KT_StyleTab
    if art then return art end
    art = { sel = {} }
    for i = 1, 3 do
        art[i] = tab:CreateTexture(nil, "BACKGROUND", nil, 3)
        art.sel[i] = tab:CreateTexture(nil, "BORDER", nil, 1)
    end
    tab.KT_StyleTab = art
    return art
end

local function HideTabArt(tab)
    if tab.KT_StyleTextShifted and tab.Text then
        tab.KT_StyleTextShifted = nil
        tab.Text:ClearAllPoints()
        tab.Text:SetPoint("LEFT", tab, "LEFT", 8, 0)
        tab.Text:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
    end
    tab.KT_StylePackTab = nil
    HideBox(tab)
    local art = tab.KT_StyleTab
    if art then
        for i = 1, 3 do art[i]:Hide(); if art.sel then art.sel[i]:Hide() end end
    end
end

-- Atlas / texture art over the tab body. Retail & Forever: options_tab_*; Classic: ChatFrameTab.
-- Bronze tabs: common-internaltab-c60 is the dark tab body, -hover / -selected are outlines drawn
-- over it (three-sliced from the one picture).
local function SliceTab(textures, file, rect, w, h, drawH, drop, cap, flip)
    local l, r, t, b = rect[1], rect[2], rect[3], rect[4]
    if flip then t, b = b, t end
    local cu = (r - l) * cap / w
    local scale = drawH / h
    local parts = { { l, l + cu }, { l + cu, r - cu }, { r - cu, r } }
    for i = 1, 3 do
        textures[i]:SetTexture(file)
        textures[i]:SetTexCoord(parts[i][1], parts[i][2], t, b)
        textures[i]:SetVertexColor(1, 1, 1, 1)
        textures[i]:SetAlpha(1)
        textures[i]:SetBlendMode("BLEND")
        textures[i]:ClearAllPoints()
    end
    textures[1]:SetPoint("BOTTOMLEFT", 0, -drop); textures[1]:SetSize(cap * scale, drawH)
    textures[3]:SetPoint("BOTTOMRIGHT", 0, -drop); textures[3]:SetSize(cap * scale, drawH)
    textures[2]:SetPoint("TOPLEFT", textures[1], "TOPRIGHT"); textures[2]:SetPoint("BOTTOMRIGHT", textures[3], "BOTTOMLEFT")
    for i = 1, 3 do textures[i]:Show() end
end

local function PackTab(tab, packName, selected, hover)
    local pack = PACKS[packName]
    local bodyKey = (selected and pack.selectedReplaces) and "tabSelected" or "tab"
    local bodyFile, bl, br, bt, bb, bw, bh = PackRect(packName, bodyKey)
    if not bodyFile then return false end
    local art = EnsureTabArt(tab)
    local height = tab:GetHeight()
    if not height or height <= 0 then height = 28 end
    -- every tab sinks into the frame's top edge (its art has a soft margin), the active one a bit more
    local drop = selected and pack.drop[2] or pack.drop[1]
    local drawH = (selected and height or floor(height * 0.9)) + drop
    SliceTab(art, bodyFile, { bl, br, bt, bb }, bw, bh, drawH, drop, pack.tabCap, pack.flipV)

    -- keep the label centred in the visible art (the art reaches below the tab frame)
    if tab.Text then
        local ty = -(drop / 2) - (selected and 0 or pack.lift * height) - 1.5
        tab.Text:ClearAllPoints()
        tab.Text:SetPoint("LEFT", tab, "LEFT", 8, ty)
        tab.Text:SetPoint("RIGHT", tab, "RIGHT", -8, ty)
        tab.KT_StyleTextShifted = true
    end

    -- active / hover outline drawn over the body (Retail's active tab replaces the body instead)
    local overlayKey = (not pack.selectedReplaces and selected) and "tabSelected" or (hover and "tabHover" or nil)
    local file, l, r, t, b, ow, oh
    if overlayKey then file, l, r, t, b, ow, oh = PackRect(packName, overlayKey) end
    if file then
        SliceTab(art.sel, file, { l, r, t, b }, ow, oh, drawH, drop, pack.tabCap, pack.flipV)
    else
        for i = 1, 3 do art.sel[i]:Hide() end
    end
    if not tab.KT_StyleTabHooks then
        tab.KT_StyleTabHooks = true
        tab:HookScript("OnEnter", function(self)
            if self.KT_StylePackTab and not self.KT_StyleSelected then PackTab(self, self.KT_StylePackTab, false, true) end
        end)
        tab:HookScript("OnLeave", function(self)
            if self.KT_StylePackTab and not self.KT_StyleSelected then PackTab(self, self.KT_StylePackTab, false, false) end
        end)
    end
    return true
end

local function SkinTabArt(tab, def, key, selected)
    local art = EnsureTabArt(tab)
    local height = tab:GetHeight()
    if not height or height <= 0 then height = 28 end
    if def.classic then
        local cap = 16 * (height / 32)
        local drop = selected and 0 or 3
        local function lay(set, files, blend)
            for i = 1, 3 do
                set[i]:SetTexture(files[i])
                set[i]:SetTexCoord(0, 1, 0, 1)
                set[i]:SetVertexColor(1, 1, 1, 1)
                set[i]:SetBlendMode(blend)
            end
            set[1]:ClearAllPoints(); set[1]:SetPoint("TOPLEFT", 0, -drop); set[1]:SetPoint("BOTTOMLEFT", 0, -1); set[1]:SetWidth(cap)
            set[3]:ClearAllPoints(); set[3]:SetPoint("TOPRIGHT", 0, -drop); set[3]:SetPoint("BOTTOMRIGHT", 0, -1); set[3]:SetWidth(cap)
            set[2]:ClearAllPoints(); set[2]:SetPoint("TOPLEFT", set[1], "TOPRIGHT"); set[2]:SetPoint("BOTTOMRIGHT", set[3], "BOTTOMLEFT")
        end
        lay(art, def.tabs, "BLEND")
        -- the label sits in the middle of the visible art (idle tabs are drawn lower)
        if tab.Text then
            local ty = -(drop / 2) - 5
            tab.Text:ClearAllPoints()
            tab.Text:SetPoint("LEFT", tab, "LEFT", 8, ty)
            tab.Text:SetPoint("RIGHT", tab, "RIGHT", -8, ty)
            tab.KT_StyleTextShifted = true
        end
        for i = 1, 3 do art[i]:SetAlpha(selected and 1 or 0.6); art[i]:Show() end
        if selected then
            lay(art.sel, def.tabsSelected, "ADD")
            for i = 1, 3 do art.sel[i]:SetAlpha(0.55); art.sel[i]:Show() end
        else
            for i = 1, 3 do art.sel[i]:Hide() end
        end
        return
    end
    local prefix = selected and "options_tab_active_" or "options_tab_"
    local left, tinted = Pick(prefix .. "left", def.suffix)
    local mid = Pick(prefix .. "middle", def.suffix)
    local right = Pick(prefix .. "right", def.suffix)
    if not (left and mid and right) then
        for i = 1, 3 do art[i]:Hide() end
        return
    end
    -- The inactive tab sits a little lower than the active one, like the native tabs.
    local drawH = selected and height or floor(height * 23 / 26)
    local lw, lh = AtlasSize(left)
    local capW = lw * (drawH / max(lh, 1))
    art[1]:SetAtlas(left, false); art[2]:SetAtlas(mid, false); art[3]:SetAtlas(right, false)
    art[1]:ClearAllPoints(); art[3]:ClearAllPoints(); art[2]:ClearAllPoints()
    art[1]:SetPoint("BOTTOMLEFT"); art[1]:SetSize(capW, drawH)
    art[3]:SetPoint("BOTTOMRIGHT"); art[3]:SetSize(capW, drawH)
    art[2]:SetPoint("TOPLEFT", art[1], "TOPRIGHT"); art[2]:SetPoint("BOTTOMRIGHT", art[3], "BOTTOMLEFT")
    local r, g, b = S.Accent(key)
    for i = 1, 3 do
        if tinted then art[i]:SetVertexColor(r, g, b, 1) else art[i]:SetVertexColor(1, 1, 1, 1) end
        art[i]:SetAlpha(1)
        art[i]:Show()
    end
end

function S:ApplyTabs(window, key, def)
    local tabs = window.KT_Tabs
    if not tabs then return end
    local selectedIndex = window.KT_PreviewSelected or Mod.selectedTabIndex or 1
    local r, g, b = S.Accent(key)
    for index, tab in ipairs(tabs) do
        if not def then
            HideTabArt(tab)
            if tab.KT_Gloss then tab.KT_Gloss:SetAlpha(1) end
        elseif tab:IsShown() then
            local selected = index == selectedIndex
            tab:SetBackdropColor(0, 0, 0, 0)
            tab:SetBackdropBorderColor(0, 0, 0, 0)
            if tab.KT_Gloss then tab.KT_Gloss:SetAlpha(0) end
            if tab.KT_SelectedBorder then tab.KT_SelectedBorder:Hide() end

            -- Border colour: the style's accent; whisper tabs keep their own text colour so they
            -- stay easy to tell apart. The tab text itself is never recoloured.
            local cr, cg, cb = r, g, b
            local whisper
            if window.KT_PreviewWhisper then whisper = window.KT_PreviewWhisper(index) else whisper = IsWhisperTab(index) end
            if whisper and tab.Text and tab.Text.GetTextColor then
                cr, cg, cb = tab.Text:GetTextColor()
            end
            tab.KT_StyleSelected = selected
            tab.KT_StylePackTab = nil
            if not def.pack and not def.classic and tab.KT_StyleTextShifted and tab.Text then
                tab.KT_StyleTextShifted = nil
                tab.Text:ClearAllPoints()
                tab.Text:SetPoint("LEFT", tab, "LEFT", 8, 0)
                tab.Text:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
            end
            if def.pack and PackTab(tab, def.pack, selected, false) then
                HideBox(tab)  -- the packaged tab art is the whole tab: no extra border
                tab.KT_StylePackTab = def.pack
            elseif def.classic then
                HideBox(tab)
                SkinTabArt(tab, def, key, selected)
            else
                if selected then
                    PaintBox(tab, { cr, cg, cb, 1 }, { cr * 0.22, cg * 0.22, cb * 0.22, 0.95 }, 1, true)
                else
                    PaintBox(tab, { cr * 0.38, cg * 0.38, cb * 0.38, 0.9 }, { 0.045, 0.045, 0.05, 0.9 }, 1, false)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Input bar (Classic art; Retail / Forever use the framed panel from ApplyWindow)
-------------------------------------------------------------------------------
local function EnsureClassicInput(host)
    local skin = host.KT_StyleInput
    if skin then return skin end
    skin = {
        left = host:CreateTexture(nil, "BACKGROUND", nil, 1),
        mid = host:CreateTexture(nil, "BACKGROUND", nil, 1),
        right = host:CreateTexture(nil, "BACKGROUND", nil, 1),
    }
    host.KT_StyleInput = skin
    return skin
end

function S:ApplyInput(window, key, def)
    local host = window.KT_InputHost
    if not host then return end
    local editBox = (not window.KT_Preview) and _G.ChatFrame1EditBox or nil
    local skin = host.KT_StyleInput

    if not def then
        if skin then skin.left:Hide(); skin.mid:Hide(); skin.right:Hide() end
        if editBox and editBox.SetBackdropColor and S.inputSkinned then
            -- Back to KUI's flat box.
            editBox:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
            editBox:SetBackdropBorderColor(KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333, 1)
        end
        if not window.KT_Preview then S.inputSkinned = nil end
        return
    end

    if def.classic then
        skin = EnsureClassicInput(host)
        local height = host:GetHeight()
        if not height or height <= 0 then height = 38 end
        local cap = 16 * (height / 32)
        skin.left:SetTexture(def.input.left)
        skin.left:SetTexCoord(0, 16 / 256, 0, 1)
        skin.left:ClearAllPoints()
        skin.left:SetPoint("TOPLEFT"); skin.left:SetPoint("BOTTOMLEFT"); skin.left:SetWidth(cap)
        skin.right:SetTexture(def.input.right)
        skin.right:SetTexCoord(240 / 256, 1, 0, 1)
        skin.right:ClearAllPoints()
        skin.right:SetPoint("TOPRIGHT"); skin.right:SetPoint("BOTTOMRIGHT"); skin.right:SetWidth(cap)
        skin.mid:SetTexture(def.input.mid)
        skin.mid:SetTexCoord(0, 1, 0, 1)
        skin.mid:ClearAllPoints()
        skin.mid:SetPoint("TOPLEFT", skin.left, "TOPRIGHT"); skin.mid:SetPoint("BOTTOMRIGHT", skin.right, "BOTTOMLEFT")
        skin.left:Show(); skin.mid:Show(); skin.right:Show()
    elseif skin then
        skin.left:Hide(); skin.mid:Hide(); skin.right:Hide()
    end
    if editBox and editBox.SetBackdropColor then
        editBox:SetBackdropColor(0, 0, 0, 0)
        editBox:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if not window.KT_Preview then S.inputSkinned = true end
end

-------------------------------------------------------------------------------
--  Buttons (sidebar, scroll-to-bottom, send)
-------------------------------------------------------------------------------
-- The sidebar buttons are created in this fixed order (see Chat.lua: AttachSidebarControls);
-- GetTexture() returns a file id for them, so their position is what identifies them.
local SIDEBAR_KEYS = { "friendlist", "voicechat", "quickchat", "search", "copychat", "confrig", "trash" }
local function IconKeyFor(window, button)
    if button == window.KT_ScrollButton then return "ui-chaticon-scrolldown-up" end
    for index, candidate in ipairs(window.KT_ActionButtons or {}) do
        if candidate == button then return SIDEBAR_KEYS[index] end
    end
    return nil
end

local function RememberIcon(button)
    local icon = button.KT_Icon
    if not icon or button.KT_StyleOrig then return end
    local w, h = icon:GetSize()
    button.KT_StyleOrig = { tex = icon:GetTexture(), coords = { icon:GetTexCoord() }, w = w, h = h }
end

local function RestoreIcon(button)
    local icon, orig = button.KT_Icon, button.KT_StyleOrig
    if not (icon and orig and button.KT_StyleIconChanged) then return end
    icon:SetTexture(orig.tex)
    if #orig.coords == 8 then icon:SetTexCoord(unpack(orig.coords)) else icon:SetTexCoord(0, 1, 0, 1) end
    icon:SetSize(orig.w, orig.h)
    button.KT_StyleIconChanged = nil
end

-- Atlas art over the button body, with hover / pressed states
local function EnsureButtonArt(button)
    local art = button.KT_StyleArt
    if art then return art end
    art = { bg = button:CreateTexture(nil, "BACKGROUND", nil, 4) }
    art.bg:SetAllPoints()
    button.KT_StyleArt = art
    local function state(self, which)
        local a = self.KT_StyleArt
        if a and a.names and a.bg:IsShown() and a.names[which] then ApplyArt(a.bg, a.names[which]) end
    end
    button:HookScript("OnEnter", function(self) state(self, "hover") end)
    button:HookScript("OnLeave", function(self) state(self, "normal") end)
    button:HookScript("OnMouseDown", function(self) state(self, "pressed") end)
    button:HookScript("OnMouseUp", function(self) state(self, self:IsMouseOver() and "hover" or "normal") end)
    return art
end

local function HideButtonArt(button)
    local art = button.KT_StyleArt
    if art then art.bg:Hide(); art.names = nil end
    HideBox(button)
end

-- Classic send button: the red Blizzard panel button with a "Send" label.
local function ClassicSend(button, on)
    local skin = button.KT_StyleSend
    if not skin and not on then return end
    if not skin then
        skin = {
            bg = button:CreateTexture(nil, "BACKGROUND", nil, 4),
            hi = button:CreateTexture(nil, "HIGHLIGHT"),
            label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"),
        }
        skin.bg:SetAllPoints()
        skin.bg:SetTexCoord(0, 0.625, 0, 0.6875)
        skin.hi:SetAllPoints()
        skin.hi:SetBlendMode("ADD")
        skin.hi:SetTexCoord(0, 0.625, 0, 0.6875)
        skin.label:SetPoint("CENTER", 0, 1)
        skin.label:SetText("")
        button.KT_StyleSend = skin
        button:HookScript("OnMouseDown", function(self)
            if self.KT_StyleSend and self.KT_StyleSend.bg:IsShown() then
                self.KT_StyleSend.bg:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
            end
        end)
        button:HookScript("OnMouseUp", function(self)
            if self.KT_StyleSend and self.KT_StyleSend.bg:IsShown() then
                self.KT_StyleSend.bg:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
            end
        end)
    end
    if on then
        skin.bg:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        skin.hi:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        skin.bg:Show(); skin.hi:Show(); skin.label:Hide()
        if button.KT_Icon then button.KT_Icon:SetAlpha(1) end
    else
        skin.bg:Hide(); skin.hi:Hide(); skin.label:Hide()
        if button.KT_Icon then button.KT_Icon:SetAlpha(1) end
    end
end

local CLASSIC_SLOT = { file = "Interface\\Buttons\\UI-SquareButton-Up", l = 0, r = 1, t = 0, b = 1 }
local CLASSIC_SLOT_DOWN = { file = "Interface\\Buttons\\UI-SquareButton-Down", l = 0, r = 1, t = 0, b = 1 }
-- these classic icons already come inside their own dark square
local CLASSIC_FRAMED = { friendlist = true, quickchat = true, ["ui-chaticon-scrolldown-up"] = true }

local function SkinButton(button, key, def, isSend, window)
    local icon = button.KT_Icon
    RememberIcon(button)

    if not def then
        HideButtonArt(button)
        ClassicSend(button, false)
        RestoreIcon(button)
        if button.KT_Shadow then button.KT_Shadow:SetAlpha(1) end
        if icon and button.KT_StyleTinted then
            icon:SetVertexColor(0.95, 0.95, 0.98, 0.95)
            button.KT_StyleTinted = nil
        end
        return
    end

    if def.classic then
        -- every button is the same 26 px classic square: framed icons as they are, the rest on
        -- the classic dark square; Send is the arrow on that square too
        ClassicSend(button, false)
        if button.KT_Shadow then button.KT_Shadow:SetAlpha(0) end
        if isSend then
            ClassicSend(button, true)
            if icon then
                icon:SetSize(16, 16)
                icon:SetVertexColor(1, 0.9, 0.5, 1)
                button.KT_StyleTinted = true
            end
            HideButtonArt(button)
            return
        end
        local iconKey = window and IconKeyFor(window, button)
        local framed = iconKey and CLASSIC_FRAMED[iconKey]
        if framed then
            HideButtonArt(button)
        else
            HideBox(button)
            local art = EnsureButtonArt(button)
            art.names = { normal = CLASSIC_SLOT, hover = CLASSIC_SLOT, pressed = CLASSIC_SLOT_DOWN }
            ApplyArt(art.bg, CLASSIC_SLOT)
            art.bg:SetVertexColor(1, 1, 1, 1)
            art.bg:ClearAllPoints(); art.bg:SetPoint("CENTER"); art.bg:SetSize(26, 26)
            art.bg:Show()
        end
        local classicIcon = icon and iconKey and def.icons[iconKey]
        if classicIcon then
            icon:SetTexture(classicIcon)
            icon:SetTexCoord(0, 1, 0, 1)
            local px = framed and 26 or 16
            icon:SetSize(px, px)
            local tint = def.iconTint and def.iconTint[iconKey]
            if tint then icon:SetVertexColor(tint[1], tint[2], tint[3], 1) else icon:SetVertexColor(1, 1, 1, 1) end
            button.KT_StyleIconChanged = true
        elseif icon then
            if isSend then icon:SetSize(16, 16) else RestoreIcon(button) end
            icon:SetVertexColor(1, 0.82, 0.1, 1)
        end
        button.KT_StyleTinted = true
        return
    end

    -- Retail / Forever: Blizzard's own tertiary button art (square; wide for Send) + tinted icon.
    -- When the client lacks it, a dark body with one dim border (it lights up on hover) is drawn.
    ClassicSend(button, false)
    RestoreIcon(button)
    local r, g, b = S.Accent(key)
    local prefix = isSend and "wide" or "square"
    local normal = PackRef(def.pack, prefix .. "Normal")
    if normal then
        HideBox(button)
        local art = EnsureButtonArt(button)
        art.names = {
            normal = normal,
            hover = PackRef(def.pack, prefix .. "Hover") or normal,
            pressed = PackRef(def.pack, prefix .. "Pressed") or normal,
        }
        ApplyArt(art.bg, normal)
        art.bg:ClearAllPoints(); art.bg:SetAllPoints()
        art.bg:SetVertexColor(1, 1, 1, 1)
        art.bg:Show()
        if button.KT_Shadow then button.KT_Shadow:SetAlpha(0) end
        if icon then
            local tr, tg, tb = IconTint(key)
            icon:SetVertexColor(tr, tg, tb, 1)
            button.KT_StyleTinted = true
        end
        return
    end
    button.KT_StyleDim = { r * 0.5, g * 0.5, b * 0.5, 0.9 }
    button.KT_StyleLit = { r, g, b, 1 }
    PaintBox(button, button.KT_StyleDim, { 0.045, 0.045, 0.05, 0.9 }, 1)
    if not button.KT_StyleHovers then
        button.KT_StyleHovers = true
        local function paint(self, color)
            local box = self.KT_StyleBox
            if not (box and box.fill:IsShown() and color) then return end
            for _, edge in ipairs(box.edges) do edge:SetColorTexture(color[1], color[2], color[3], color[4]) end
        end
        button:HookScript("OnEnter", function(self) paint(self, self.KT_StyleLit) end)
        button:HookScript("OnLeave", function(self) paint(self, self.KT_StyleDim) end)
    end
    local art = button.KT_StyleArt
    if art then art.bg:Hide(); art.names = nil end
    if button.KT_Shadow then button.KT_Shadow:SetAlpha(0) end
    if icon then
        local tr, tg, tb = IconTint(key)
        icon:SetVertexColor(tr, tg, tb, 1)
        button.KT_StyleTinted = true
    end
end

-- The whisper strip (one button per person / Battle.net friend) is deliberately NOT
-- skinned: its blue is how whispers are told apart from the rest.
-------------------------------------------------------------------------------
--  Whisper strip (one small button per open private chat)
--  The style's own square button (the same as the side buttons) with its border; the
--  icon and label keep the whisper colours (pink, blue for Battle.net) and the open
--  chat gets an outline in the style's accent. KUI Style keeps Chat.lua's flat boxes.
-------------------------------------------------------------------------------
local function WhisperRing(button)
    local ring = button.KT_StyleWhisperRing
    if ring then return ring end
    ring = {}
    for i = 1, 4 do ring[i] = button:CreateTexture(nil, "OVERLAY", nil, 6) end
    button.KT_StyleWhisperRing = ring
    return ring
end

local function ShowWhisperRing(button, shown, r, g, b, thickness)
    local ring = WhisperRing(button)
    local t = thickness or 1
    ring[1]:ClearAllPoints(); ring[1]:SetPoint("TOPLEFT"); ring[1]:SetPoint("TOPRIGHT"); ring[1]:SetHeight(t)
    ring[2]:ClearAllPoints(); ring[2]:SetPoint("BOTTOMLEFT"); ring[2]:SetPoint("BOTTOMRIGHT"); ring[2]:SetHeight(t)
    ring[3]:ClearAllPoints(); ring[3]:SetPoint("TOPLEFT", 0, -t); ring[3]:SetPoint("BOTTOMLEFT", 0, t); ring[3]:SetWidth(t)
    ring[4]:ClearAllPoints(); ring[4]:SetPoint("TOPRIGHT", 0, -t); ring[4]:SetPoint("BOTTOMRIGHT", 0, t); ring[4]:SetWidth(t)
    for _, edge in ipairs(ring) do
        if shown then edge:SetColorTexture(r, g, b, 1) end
        edge:SetShown(shown and true or false)
    end
end

-- Called by Mod:PaintWhisperButton after it set the whisper colours. Returns true when
-- the active style drew the button (Chat.lua then skips its flat box).
function S.PaintWhisperButton(button)
    local key = S.lastKey or S.Resolve()
    local def = STYLES[key]
    if not def then
        if button.KT_StyleWhisperRing then ShowWhisperRing(button, false) end
        return false
    end
    if button.SetBackdropColor then
        button:SetBackdropColor(0, 0, 0, 0)
        button:SetBackdropBorderColor(0, 0, 0, 0)
    end
    -- No outline on the open chat: it stayed on and read as stuck. The open
    -- chat is told apart by its full opacity (Mod:PaintWhisperButton).
    if button.KT_StyleWhisperRing then ShowWhisperRing(button, false) end
    return true
end

function S:ApplyWhisperButtons(window, key, def)
    for _, button in ipairs(window.KT_WhisperStripButtons or {}) do
        SkinButton(button, key, def, nil, window)
        -- SkinButton tints the icon for the style; the whisper colours come back here.
        if Mod.PaintWhisperButton then Mod:PaintWhisperButton(button) end
    end
end

function S:ApplyButtons(window, key, def)
    for _, button in ipairs(window.KT_ActionButtons or {}) do SkinButton(button, key, def, nil, window) end
    if window.KT_ScrollButton then SkinButton(window.KT_ScrollButton, key, def, nil, window) end
    if window.KT_SendButton then SkinButton(window.KT_SendButton, key, def, true, window) end
end

-------------------------------------------------------------------------------
--  Combat tab buttons ("My actions" / "What happened to me?" and the like)
--  They belong to Blizzard's combat log quick-button bar; each style gives them its own button.
-------------------------------------------------------------------------------
local function SetNativeRegionsShown(frame, shown, ownArt, depth)
    depth = depth or 0
    if not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= ownArt and region.GetObjectType and region:GetObjectType() == "Texture" then
            if shown then
                if region.KT_StyleOrigAlpha then
                    region:SetAlpha(region.KT_StyleOrigAlpha)
                    region.KT_StyleOrigAlpha = nil
                end
            else
                if not region.KT_StyleOrigAlpha then region.KT_StyleOrigAlpha = region:GetAlpha() end
                region:SetAlpha(0)
            end
        end
    end
    -- plates and selection markers can live on child frames; the labelled buttons are skinned on their own
    if depth < 2 and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            local isLabelled = child.GetObjectType and child:GetObjectType() == "Button"
                and child.GetText and (child:GetText() or "") ~= ""
            if child ~= ownArt and not isLabelled then SetNativeRegionsShown(child, shown, nil, depth + 1) end
        end
    end
end

local function IsQuickButtonSelected(button)
    if button.GetButtonState and button:GetButtonState() == "PUSHED" then return true end
    if button.GetChecked and button:GetChecked() then return true end
    return button.KT_StyleLocked == true
end

local function SizeCombatButton(button, fs)
    local textW = fs and fs.GetStringWidth and fs:GetStringWidth() or 70
    button:SetHeight(28)
    button:SetWidth(max(112, floor(textW + 40)))
end

local function SkinCombatButton(button, key, def)
    local fs = button.GetFontString and button:GetFontString()
    if not def then
        -- KUI Style: a flat dark button with a thin accent border, at a proper size
        local art = button.KT_StyleArt
        if art then art.bg:Hide(); art.names = nil end
        if button.KT_StyleHover then button.KT_StyleHover:Hide() end
        SetNativeRegionsShown(button, false, art and art.bg)
        SizeCombatButton(button, fs)
        PaintBox(button, { (KT.C_R or 1) * 0.6, (KT.C_G or 0) * 0.6, (KT.C_B or 0.333) * 0.6, 0.9 },
            { 0.06, 0.06, 0.06, 0.95 }, 1)
        if fs then
            fs:SetTextColor(0.92, 0.92, 0.95, 1)
            local font, size = fs:GetFont()
            if font then fs:SetFont(font, size or 12, "OUTLINE") end
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetShadowOffset(1, -1)
        end
        return
    end
    SizeCombatButton(button, fs)
    HideBox(button)
    if fs and not button.KT_StyleOrigText then button.KT_StyleOrigText = { fs:GetTextColor() } end
    local art = EnsureButtonArt(button)
    SetNativeRegionsShown(button, false, art.bg)
    local selected = IsQuickButtonSelected(button)
    local text
    if def.classic then
        local normal = { file = "Interface\\Buttons\\UI-Panel-Button-Up", l = 0, r = 0.625, t = 0, b = 0.6875 }
        local down = { file = "Interface\\Buttons\\UI-Panel-Button-Down", l = 0, r = 0.625, t = 0, b = 0.6875 }
        local hover = { file = "Interface\\Buttons\\UI-Panel-Button-Highlight", l = 0, r = 0.625, t = 0, b = 0.6875 }
        art.names = { normal = normal, hover = normal, pressed = down }
        ApplyArt(art.bg, selected and down or normal)
        art.bg:SetVertexColor(1, 1, 1, 1)
        text = { 1.00, 0.82, 0.10 }
        if not button.KT_StyleHover then
            button.KT_StyleHover = button:CreateTexture(nil, "HIGHLIGHT")
            button.KT_StyleHover:SetAllPoints()
            button.KT_StyleHover:SetBlendMode("ADD")
        end
        button.KT_StyleHover:SetTexture(hover.file)
        button.KT_StyleHover:SetTexCoord(hover.l, hover.r, hover.t, hover.b)
        button.KT_StyleHover:Show()
    else
        local normal = PackRef(def.pack, "wideNormal")
        if not normal then
            -- no packaged art: a dark body with one accent border
            local r, g, b = S.Accent(key)
            art.bg:Hide(); art.names = nil
            PaintBox(button, { r * 0.5, g * 0.5, b * 0.5, 0.9 }, { 0.045, 0.045, 0.05, 0.9 }, 1)
            text = { IconTint(key) }
        else
            local pressed = PackRef(def.pack, "widePressed") or normal
            art.names = { normal = normal, hover = PackRef(def.pack, "wideHover") or normal, pressed = pressed }
            HideBox(button)
            ApplyArt(art.bg, selected and pressed or normal)
            art.bg:SetVertexColor(1, 1, 1, 1)
            text = { IconTint(key) }
        end
        if button.KT_StyleHover then button.KT_StyleHover:Hide() end
    end
    art.bg:ClearAllPoints(); art.bg:SetAllPoints()
    if art.names then art.bg:Show() end
    if fs and text then fs:SetTextColor(text[1], text[2], text[3], 1) end
end

function S:ApplyCombatButtons(window, key, def)
    if window.KT_Preview then return end
    local bar = _G.CombatLogQuickButtonFrame_Custom
    if not bar then return end
    SetNativeRegionsShown(bar, false)  -- the flat dark strip behind the buttons
    for _, child in ipairs({ bar:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" and child.GetText and (child:GetText() or "") ~= "" then
            SkinCombatButton(child, key, def)
        end
    end
    if not S.combatBarHooked then
        S.combatBarHooked = true
        if _G.Blizzard_CombatLog_Update_QuickButtons then
            hooksecurefunc("Blizzard_CombatLog_Update_QuickButtons", function()
                local w = _G.KT_ChatWindow
                if w then pcall(S.ApplyCombatButtons, S, w, S.lastKey, STYLES[S.lastKey or ""]) end
            end)
        end
    end
end

-------------------------------------------------------------------------------
--  Driver
-------------------------------------------------------------------------------
function S:Apply()
    local window = _G.KT_ChatWindow
    if not window then return end
    local key = S.Resolve()
    local def = STYLES[key]
    S.lastKey = key
    for _, phase in ipairs({ "ApplyWindow", "ApplyTabs", "ApplyInput", "ApplyButtons", "ApplyCombatButtons", "ApplyWhisperButtons" }) do
        local ok, err = pcall(S[phase], S, window, key, def)
        if not ok then
            S.lastError = phase .. ": " .. tostring(err)
            if not S.errorShown then
                S.errorShown = true
                print("|cffff6666KUI Chat style error|r " .. S.lastError .. "  (/ktchatstyle debug)")
            end
        end
    end
    if not def and Mod.ApplyPanelColor and S.wasSkinned then
        -- Leaving a skin: let the original code repaint its flat colours.
        S.wasSkinned = nil
        local color = (Mod.db and Mod.db.panelColor) or { r = 0.04, g = 0.06, b = 0.08, a = 0.1 }
        if window.SetBackdropColor then
            window:SetBackdropColor(color.r, color.g, color.b, color.a or 0)
        end
        S.applying = true
        pcall(Mod.ApplyPanelColor, Mod)
        S.applying = nil
    end
    if def then S.wasSkinned = true end
    if S.layoutKey ~= key then
        S.layoutKey = key
        if Mod.ApplyNormalChatFrameLayout then pcall(Mod.ApplyNormalChatFrameLayout, Mod) end
        if Mod.QueueChatLayoutReflow then pcall(Mod.QueueChatLayoutReflow, Mod) end
    end
end

-- The options page's live preview is a mock window with the same field names; it is skinned
-- with exactly the same phases (never touching the real chat edit box).
function S:ApplyPreview(window)
    local key = S.Resolve()
    local def = STYLES[key]
    window.KT_Preview = true
    for _, phase in ipairs({ "ApplyWindow", "ApplyTabs", "ApplyInput", "ApplyButtons", "ApplyCombatButtons", "ApplyWhisperButtons" }) do
        local ok, err = pcall(S[phase], S, window, key, def)
        if not ok then S.lastError = "preview " .. phase .. ": " .. tostring(err) end
    end
end

function S:SetStyle(key)
    local db = KT.db and KT.db.profile and KT.db.profile.chat
    if not db then return end
    db.chatStyle = nil  -- retired single setting
    db.styleByTheme = type(db.styleByTheme) == "table" and db.styleByTheme or {}
    if key == nil or key == "auto" then
        db.styleByTheme[ActiveTheme()] = nil
    else
        db.styleByTheme[ActiveTheme()] = key
    end
    self:Apply()
end

-- Post-hooks keep the skin on top of what the original code repaints.
local function Hook(name)
    if type(Mod[name]) ~= "function" then return end
    hooksecurefunc(Mod, name, function()
        if S.applying then return end
        S:Apply()
    end)
end
for _, name in ipairs({ "ApplyPanelColor", "SelectTab", "RefreshTabButtons", "AttachBlizzardEditBox",
    "AttachSidebarControls", "UpdateSidebarLayout", "CreateNativeWindow" }) do
    Hook(name)
end

-- Showing the combat tab re-parents Blizzard's quick-button bar: skin its buttons again.
if type(Mod.SetCombatLogVisible) == "function" then
    hooksecurefunc(Mod, "SetCombatLogVisible", function(_, visible)
        local w = _G.KT_ChatWindow
        if visible and w and not S.applying then pcall(S.ApplyCombatButtons, S, w, S.lastKey, STYLES[S.lastKey or ""]) end
    end)
end

-- Visual Style switches and a window created late are picked up here.
C_Timer.NewTicker(1.5, function()
    if _G.KT_ChatWindow and S.lastKey ~= S.Resolve() then S:Apply() end
end)

_G.SLASH_KTCHATSTYLE1 = "/ktchatstyle"
_G.SlashCmdList.KTCHATSTYLE = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)") or ""
    if msg == "debug" then
        local key = S.Resolve()
        local def = STYLES[key]
        print("|cff66ccffKUI Chat|r debug  style=" .. tostring(key) .. " theme=" .. tostring(ActiveTheme())
            .. " window=" .. tostring(_G.KT_ChatWindow ~= nil) .. " lastError=" .. tostring(S.lastError))
        if def and def.pack then
            print("  pack=" .. def.pack .. " frame art=" .. tostring(PackRect(def.pack, "frame") ~= nil)
                .. " tab art=" .. tostring(PackRect(def.pack, "tab") ~= nil))
        end
        local main = _G.KT_ChatWindow and _G.KT_ChatWindow.KT_StyleMain
        print("  main panel shown=" .. tostring(main and main:IsShown()))
        return
    end
    if msg == "" then
        print("|cff66ccffKUI Chat|r style: " .. tostring(S.Resolve())
            .. "  (use /ktchatstyle kui|classic|retail|forever)")
        return
    end
    if msg == "auto" or msg == "kui" or STYLES[msg] then
        S:SetStyle(msg)
        print("|cff66ccffKUI Chat|r style set to " .. msg)
    else
        print("|cff66ccffKUI Chat|r unknown style: " .. msg)
    end
end
