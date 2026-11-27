-- KUI look for every control of the embedded aura editor. The engine still builds its option forms with AceGUI;
-- this file only changes how those controls are drawn, and only inside the editor hosted in Custom Auras.
--
-- How it works: each AceGUI layout is wrapped once. When a container inside the editor lays out its children, each
-- child is skinned first: Ace's own art is faded to zero alpha and KUI art (rounded plates, pill switches, accent
-- fills) is drawn in its place. The skin follows the widget's state through hooks on its own methods.
-- The engine has its own AceGUI (its own library registry), and its widgets are pooled, so a released widget gets
-- its original look back.

local _, ns = ...
local KT = ns.KT
if not KT then return end

local M = {}
ns.AuraRemindersEmbeddedSkin = M

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ARROW = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\downarrow.png"
local FLAT = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }
local CLEAR = { 0, 0, 0, 0 }

-- KUI's default skin, for when MenuSkins is not there.
local FALLBACK = {
    text = { 1, 1, 1, 1 }, muted = { 0.74, 0.74, 0.78, 1 },
    card = { 0.086, 0.078, 0.073, 0.97 }, cardBorder = { 0.150, 0.135, 0.122, 1 },
    rowHover = { 0.125, 0.112, 0.098, 1 }, controlTrack = { 0.227, 0.208, 0.196, 1 },
    controlOff = { 0.160, 0.150, 0.170, 1 }, controlBg = { 0.135, 0.122, 0.110, 1 },
}

local root                                        -- the editor frame
local skins = setmetatable({}, { __mode = "k" })  -- widget -> record
local active = setmetatable({}, { __mode = "k" }) -- records drawn now

local function C(name)
    local menu = KT.MenuSkins
    if menu and menu.Color then
        local r, g, b, a = menu:Color(name)
        if r then return r, g, b, a or 1 end
    end
    local c = FALLBACK[name] or FALLBACK.text
    return c[1], c[2], c[3], c[4]
end

local function Accent()
    if KT.GetStyleAccentRGB then return KT:GetStyleAccentRGB() end
    return 1, 0.6, 0.4
end

local function Font()
    return KT.ResolveFontPath and KT:ResolveFontPath() or nil
end

-- A token mixed towards the accent by t; a replaces the alpha.
local function Mix(name, t, a)
    local r, g, b, alpha = C(name)
    local ar, ag, ab = Accent()
    return r + (ar - r) * t, g + (ag - g) * t, b + (ab - b) * t, a or alpha
end

local function Report(err)
    if geterrorhandler then geterrorhandler()(err) end
end

-- KUI's rounded rectangle, or a flat texture with the same small API.
local function Round(parent, layer, sublevel, radius)
    local W = KT.Widgets
    if W and W.RoundRect then return W:RoundRect(parent, layer, sublevel, radius) end
    local t = parent:CreateTexture(nil, layer, nil, sublevel)
    t:SetTexture(WHITE)
    local rr = { box = t, shown = true }
    function rr:SetColor(r, g, b, a)
        if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
        t:SetVertexColor(r, g, b, a or 1)
    end
    function rr:SetPoint(...) t:SetPoint(...) end
    function rr:ClearAllPoints() t:ClearAllPoints() end
    function rr:SetAllPoints(target) t:SetAllPoints(target) end
    function rr:SetSize(w, h) t:SetSize(w, h) end
    function rr:SetWidth(w) t:SetWidth(w) end
    function rr:SetHeight(h) t:SetHeight(h) end
    function rr:SetShown(v) self.shown = not not v; t:SetShown(self.shown) end
    function rr:Show() self:SetShown(true) end
    function rr:Hide() self:SetShown(false) end
    return rr
end

-----------------------------------------------------------------------------------------------------------------------
-- Records: what a skin changed, so a released widget can get its own look back
-----------------------------------------------------------------------------------------------------------------------

local function Record(widget, kind)
    local rec = { widget = widget, kind = kind, own = {}, faded = {}, fadedOrder = {}, backdrops = {}, restore = {} }
    skins[widget] = rec
    return rec
end

local function Own(rec, object)
    rec.own[#rec.own + 1] = object
    return object
end

-- Ace's art stays in place but is not drawn.
local function Fade(rec, region)
    if type(region) ~= "table" or not region.SetAlpha then return end
    if rec.faded[region] == nil then
        rec.faded[region] = region.GetAlpha and region:GetAlpha() or 1
        rec.fadedOrder[#rec.fadedOrder + 1] = region
    end
    region:SetAlpha(0)
end

local function FadeTextures(rec, frame, keep)
    if not (frame and frame.GetRegions) then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= keep and region.IsObjectType and region:IsObjectType("Texture") then Fade(rec, region) end
    end
end

local function FadeButtonArt(rec, button)
    if not button then return end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        if button[getter] then Fade(rec, button[getter](button)) end
    end
end

-- A flat backdrop in the given colours (nil: not drawn); the first call keeps the original to give it back.
local function Backdrop(rec, frame, bg, edge)
    if not (frame and frame.SetBackdrop) then return end
    if not rec.backdrops[frame] then
        local saved = { info = frame.GetBackdrop and frame:GetBackdrop() or nil }
        if frame.GetBackdropColor then saved.bg = { frame:GetBackdropColor() } end
        if frame.GetBackdropBorderColor then saved.edge = { frame:GetBackdropBorderColor() } end
        rec.backdrops[frame] = saved
    end
    frame:SetBackdrop(FLAT)
    frame:SetBackdropColor(unpack(bg or CLEAR))
    frame:SetBackdropBorderColor(unpack(edge or CLEAR))
end

-- Keeps a font string's colour to give it back.
local function KeepColor(rec, fs)
    if not (fs and fs.GetTextColor) then return end
    rec.colors = rec.colors or {}
    if rec.colors[fs] == nil then rec.colors[fs] = { fs:GetTextColor() } end
end

local function Paint(rec)
    if rec.paint and rec.on then
        local ok, err = pcall(rec.paint)
        if not ok then Report(err) end
    end
end

local function Activate(rec)
    rec.on = true
    active[rec] = true
    for _, object in ipairs(rec.own) do object:Show() end
    for _, region in ipairs(rec.fadedOrder) do region:SetAlpha(0) end
    for _, fn in ipairs(rec.reapply or {}) do fn() end
    Paint(rec)
end

local function Deactivate(rec)
    if not rec.on then return end
    rec.on = false
    active[rec] = nil
    for _, object in ipairs(rec.own) do object:Hide() end
    for region, alpha in pairs(rec.faded) do region:SetAlpha(alpha) end
    for frame, saved in pairs(rec.backdrops) do
        frame:SetBackdrop(saved.info)
        if saved.bg and saved.bg[1] then frame:SetBackdropColor(unpack(saved.bg)) end
        if saved.edge and saved.edge[1] then frame:SetBackdropBorderColor(unpack(saved.edge)) end
    end
    for fs, color in pairs(rec.colors or {}) do
        if color[1] then fs:SetTextColor(unpack(color)) end
    end
    for _, fn in ipairs(rec.restore) do fn() end
end

-- Repaints on a state change of the widget, while the skin is on.
local function Follow(rec, object, method)
    if object and type(object[method]) == "function" and hooksecurefunc then
        hooksecurefunc(object, method, function() Paint(rec) end)
    end
end

local function FollowScript(rec, frame, script, fn)
    if frame and frame.HookScript then
        frame:HookScript(script, function(...)
            if rec.on then fn(...) end
        end)
    end
end

local function Muted(fs, disabled)
    if not (fs and fs.SetTextColor) then return end
    local r, g, b = C("muted")
    local k = disabled and 0.6 or 1
    fs:SetTextColor(r * k, g * k, b * k, 1)
end

-----------------------------------------------------------------------------------------------------------------------
-- Shared pieces
-----------------------------------------------------------------------------------------------------------------------

-- A rounded plate with a one pixel edge; returns paint(hover, focus, disabled).
local function Plate(rec, parent, layer)
    local edge = Own(rec, Round(parent, layer or "BACKGROUND", 0, 6))
    local fill = Own(rec, Round(parent, layer or "BACKGROUND", 1, 5))
    local plate = { edge = edge, fill = fill }
    function plate:Place(target, left, top, right, bottom)
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", target, "TOPLEFT", left or 0, top or 0)
        edge:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", right or 0, bottom or 0)
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT", target, "TOPLEFT", (left or 0) + 1, (top or 0) - 1)
        fill:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", (right or 0) - 1, (bottom or 0) + 1)
    end
    function plate:Paint(hover, focus, disabled)
        local a = disabled and 0.5 or 1
        local r, g, b = C("controlBg")
        if focus or hover then r, g, b = math.min(1, r + 0.05), math.min(1, g + 0.05), math.min(1, b + 0.05) end
        fill:SetColor(r, g, b, a)
        edge:SetColor(Mix("cardBorder", focus and 0.9 or (hover and 0.5 or 0), a))
    end
    return plate
end

-- An accent chevron at the right end of a plate.
local function Chevron(rec, parent, anchor)
    local arrow = Own(rec, parent:CreateTexture(nil, "OVERLAY"))
    arrow:SetTexture(ARROW)
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", anchor, "RIGHT", -6, 0)
    return arrow
end

-- A plain UIPanelButtonTemplate button (not an AceGUI widget of its own) drawn as a KUI button.
local function SkinButtonFrame(rec, button)
    if not button then return function() end end
    FadeTextures(rec, button)
    FadeButtonArt(rec, button)
    local plate = Plate(rec, button)
    plate:Place(button)
    local hovered = false
    local function paint()
        local disabled = button.IsEnabled and not button:IsEnabled()
        plate.fill:SetColor(Mix("controlBg", hovered and 0.32 or 0.16, disabled and 0.5 or 1))
        plate.edge:SetColor(Mix("cardBorder", hovered and 0.95 or 0.55, disabled and 0.5 or 1))
        local text = button.GetFontString and button:GetFontString()
        if text then
            KeepColor(rec, text)
            local r, g, b = C(disabled and "muted" or "text")
            text:SetTextColor(r, g, b, 1)
        end
    end
    FollowScript(rec, button, "OnEnter", function() hovered = true; paint() end)
    FollowScript(rec, button, "OnLeave", function() hovered = false; paint() end)
    FollowScript(rec, button, "OnEnable", paint)
    FollowScript(rec, button, "OnDisable", paint)
    return paint
end

-- A Blizzard scroll bar (UIPanelScrollBarTemplate or a plain Slider): a thin track and an accent thumb.
local function SkinScrollBar(rec, bar)
    if not bar then return function() end end
    local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
    FadeTextures(rec, bar)
    if bar.SetBackdrop then Backdrop(rec, bar) end
    local name = bar.GetName and bar:GetName()
    for _, button in ipairs({ bar.ScrollUpButton, bar.ScrollDownButton,
        name and _G[name .. "ScrollUpButton"], name and _G[name .. "ScrollDownButton"] }) do
        Fade(rec, button)
    end
    local track = Own(rec, bar:CreateTexture(nil, "BACKGROUND"))
    track:SetTexture(WHITE)
    track:SetWidth(4)
    track:SetPoint("TOP", bar, "TOP", 0, 0)
    track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    local knob
    if thumb then
        knob = Own(rec, Round(bar, "OVERLAY", 1, 2))
        knob:SetWidth(4)
        knob:SetPoint("TOP", thumb, "TOP", 0, 0)
        knob:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
    end
    return function()
        track:SetVertexColor(C("controlTrack"))
        track:SetAlpha(0.6)
        if knob then knob:SetColor(Mix("controlTrack", 1, 0.9)) end
    end
end

-----------------------------------------------------------------------------------------------------------------------
-- Widgets
-----------------------------------------------------------------------------------------------------------------------

local Skin = {}

-- Check box: a pill switch; a radio button: a ring with an accent dot.
function Skin.check(w, rec)
    local frame, box = w.frame, w.checkbg
    Fade(rec, w.checkbg)
    Fade(rec, w.check)
    Fade(rec, w.highlight)
    local track = Own(rec, Round(frame, "ARTWORK", 1, 7))
    local knob = Own(rec, Round(frame, "OVERLAY", 1, 5))
    local hovered = false
    FollowScript(rec, frame, "OnEnter", function() hovered = true; Paint(rec) end)
    FollowScript(rec, frame, "OnLeave", function() hovered = false; Paint(rec) end)
    for _, method in ipairs({ "SetValue", "SetDisabled", "SetTriState", "SetType" }) do Follow(rec, w, method) end
    rec.paint = function()
        local radio = box:GetWidth() < 20
        local value, disabled = w.checked, w.disabled
        local a = disabled and 0.45 or 1
        track:ClearAllPoints()
        knob:ClearAllPoints()
        if radio then
            track:SetSize(14, 14)
            track:SetPoint("CENTER", box, "CENTER", 0, 0)
            track:SetColor(Mix("controlOff", value and 0.35 or (hovered and 0.2 or 0), a))
            knob:SetSize(6, 6)
            knob:SetPoint("CENTER", box, "CENTER", 0, 0)
            local ar, ag, ab = Accent()
            knob:SetColor(ar, ag, ab, a)
            knob:SetShown(value and true or false)
            return
        end
        -- Narrower than Ace's box and shifted left, so the label keeps a gap after it.
        knob:Show()
        track:SetSize(20, 11)
        track:SetPoint("CENTER", box, "CENTER", -2, 0)
        knob:SetSize(7, 7)
        local pos
        if value == nil then
            pos = 0.5
            track:SetColor(Mix("controlOff", 0.45, a))
        elseif value then
            pos = 1
            local ar, ag, ab = Accent()
            track:SetColor(ar, ag, ab, a)
        else
            pos = 0
            track:SetColor(Mix("controlOff", hovered and 0.25 or 0, a))
        end
        knob:SetPoint("LEFT", box, "CENTER", -10 + 9 * pos, 0)
        if value == false then knob:SetColor(0.62, 0.62, 0.66, a) else knob:SetColor(1, 1, 1, a) end
    end
end

-- Slider: a thin track filled with the accent up to a round knob; the value in a rounded chip.
function Skin.slider(w, rec)
    local slider, editbox = w.slider, w.editbox
    Backdrop(rec, slider)
    local thumb = slider:GetThumbTexture()
    Fade(rec, thumb)
    local track = Own(rec, Round(slider, "ARTWORK", 0, 2))
    track:SetHeight(4)
    track:SetPoint("LEFT", slider, "LEFT", 2, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", -2, 0)
    local fill = Own(rec, Round(slider, "ARTWORK", 1, 2))
    fill:SetHeight(4)
    fill:SetPoint("LEFT", slider, "LEFT", 2, 0)
    if thumb then fill:SetPoint("RIGHT", thumb, "CENTER", 0, 0) end
    local knob = Own(rec, Round(slider, "OVERLAY", 2, 6))
    knob:SetSize(12, 12)
    if thumb then knob:SetPoint("CENTER", thumb, "CENTER", 0, 0) end
    Backdrop(rec, editbox)
    local chip = Own(rec, Round(editbox, "BACKGROUND", 0, 4))
    chip:SetPoint("TOPLEFT", editbox, "TOPLEFT", 0, 1)
    chip:SetPoint("BOTTOMRIGHT", editbox, "BOTTOMRIGHT", 0, -1)
    KeepColor(rec, w.label)
    KeepColor(rec, w.lowtext)
    KeepColor(rec, w.hightext)
    KeepColor(rec, editbox)
    Follow(rec, w, "SetDisabled")
    rec.paint = function()
        local disabled = w.disabled
        local a = disabled and 0.45 or 1
        track:SetColor(Mix("controlTrack", 0, a))
        local ar, ag, ab = Accent()
        fill:SetColor(ar, ag, ab, a)
        knob:SetColor(1, 1, 1, a)
        chip:SetColor(Mix("controlBg", 0, a))
        Muted(w.label, disabled)
        Muted(w.lowtext, true)
        Muted(w.hightext, true)
        editbox:SetTextColor(ar, ag, ab, a)
    end
end

-- The engine's number box: a rounded plate with an accent progress fill and a thin accent handle.
function Skin.spin(w, rec)
    local editbox = w.editbox
    FadeTextures(rec, editbox, w.progressBar)
    Fade(rec, w.progressBarHandleTexture)
    local plate = Plate(rec, w.frame)
    plate.edge:ClearAllPoints()
    plate.edge:SetPoint("TOPLEFT", w.leftbutton, "TOPLEFT", -3, 3)
    plate.edge:SetPoint("BOTTOMRIGHT", w.rightbutton, "BOTTOMRIGHT", 3, -3)
    plate.fill:ClearAllPoints()
    plate.fill:SetPoint("TOPLEFT", w.leftbutton, "TOPLEFT", -2, 2)
    plate.fill:SetPoint("BOTTOMRIGHT", w.rightbutton, "BOTTOMRIGHT", 2, -2)
    local handle = Own(rec, Round(w.progressBarHandle, "OVERLAY", 1, 1))
    handle:SetPoint("TOP", w.progressBarHandle, "TOP", 0, -2)
    handle:SetPoint("BOTTOM", w.progressBarHandle, "BOTTOM", 0, 2)
    handle:SetWidth(3)
    local bar = w.progressBar
    local barTexture = bar.GetTexture and bar:GetTexture()
    rec.reapply = { function() bar:SetTexture(WHITE) end }
    rec.restore[#rec.restore + 1] = function()
        if barTexture then bar:SetTexture(barTexture) end
        bar:SetVertexColor(0.5, 0.5, 0.5, 1)
        for _, button in ipairs({ w.leftbutton, w.rightbutton }) do
            local normal = button.GetNormalTexture and button:GetNormalTexture()
            if normal then normal:SetVertexColor(1, 1, 1, 1) end
        end
    end
    local hovered, focused = false, false
    FollowScript(rec, editbox, "OnEnter", function() hovered = true; Paint(rec) end)
    FollowScript(rec, editbox, "OnLeave", function() hovered = false; Paint(rec) end)
    FollowScript(rec, editbox, "OnEditFocusGained", function() focused = true; Paint(rec) end)
    FollowScript(rec, editbox, "OnEditFocusLost", function() focused = false; Paint(rec) end)
    KeepColor(rec, w.label)
    KeepColor(rec, editbox)
    Follow(rec, w, "SetDisabled")
    rec.paint = function()
        local disabled = w.disabled
        plate:Paint(hovered, focused, disabled)
        local ar, ag, ab = Accent()
        bar:SetVertexColor(ar, ag, ab, disabled and 0.15 or 0.3)
        handle:SetColor(ar, ag, ab, 1)
        Muted(w.label, disabled)
        local r, g, b = C(disabled and "muted" or "text")
        editbox:SetTextColor(r, g, b, 1)
        local mr, mg, mb = C("muted")
        for _, button in ipairs({ w.leftbutton, w.rightbutton }) do
            local normal = button.GetNormalTexture and button:GetNormalTexture()
            if normal then normal:SetVertexColor(mr, mg, mb, disabled and 0.4 or 1) end
        end
    end
end

-- Text box: a rounded plate that brightens with an accent edge while typing.
function Skin.edit(w, rec)
    local editbox = w.editbox
    FadeTextures(rec, editbox)
    local plate = Plate(rec, editbox)
    plate:Place(editbox, -6, 1, 2, -1)
    local paintOK = SkinButtonFrame(rec, w.button)
    local hovered, focused = false, false
    FollowScript(rec, editbox, "OnEnter", function() hovered = true; Paint(rec) end)
    FollowScript(rec, editbox, "OnLeave", function() hovered = false; Paint(rec) end)
    FollowScript(rec, editbox, "OnEditFocusGained", function() focused = true; Paint(rec) end)
    FollowScript(rec, editbox, "OnEditFocusLost", function() focused = false; Paint(rec) end)
    KeepColor(rec, w.label)
    Follow(rec, w, "SetDisabled")
    rec.paint = function()
        plate:Paint(hovered, focused, w.disabled)
        Muted(w.label, w.disabled)
        paintOK()
    end
end

-- Multi-line text: the same plate around the scrolling text, a thin scroll bar and a KUI accept button.
function Skin.multiline(w, rec)
    Backdrop(rec, w.scrollBG)
    local plate = Plate(rec, w.scrollBG)
    plate:Place(w.scrollBG)
    local paintButton = SkinButtonFrame(rec, w.button)
    local paintBar = SkinScrollBar(rec, w.scrollBar)
    local focused = false
    FollowScript(rec, w.editBox, "OnEditFocusGained", function() focused = true; Paint(rec) end)
    FollowScript(rec, w.editBox, "OnEditFocusLost", function() focused = false; Paint(rec) end)
    KeepColor(rec, w.label)
    Follow(rec, w, "SetDisabled")
    rec.paint = function()
        plate:Paint(false, focused, w.disabled)
        Muted(w.label, w.disabled)
        paintButton()
        paintBar()
    end
end

-- Dropdown (AceGUI): a rounded box with the choice and an accent chevron; the open list as a KUI card.
local function SkinPullout(pullout)
    local rec = skins[pullout] or Record(pullout, "pullout")
    if not rec.built then
        rec.built = true
        rec.paintBar = SkinScrollBar(rec, pullout.slider)
        rec.paint = function()
            Backdrop(rec, pullout.frame, { C("card") }, { Mix("cardBorder", 0.35) })
            rec.paintBar()
        end
    end
    Activate(rec)
    for _, item in ipairs(pullout.items or {}) do
        local irec = skins[item] or Record(item, "item")
        if not irec.built then
            irec.built = true
            irec.restore[#irec.restore + 1] = function()
                if item.highlight then item.highlight:SetVertexColor(1, 1, 1, 1) end
                if item.check then item.check:SetVertexColor(1, 1, 1, 1) end
            end
            irec.paint = function()
                local r, g, b = Accent()
                if item.highlight then item.highlight:SetVertexColor(r, g, b, 0.6) end
                if item.check then item.check:SetVertexColor(r, g, b, 1) end
            end
        end
        Activate(irec)
    end
end

function Skin.dropdown(w, rec)
    local name = w.dropdown:GetName()
    for _, part in ipairs({ "Left", "Middle", "Right" }) do Fade(rec, name and _G[name .. part] or w.dropdown[part]) end
    FadeButtonArt(rec, w.button)
    local plate = Plate(rec, w.frame)
    local arrow = Chevron(rec, w.frame, w.frame)
    local hovered = false
    for _, button in ipairs({ w.button, w.button_cover }) do
        FollowScript(rec, button, "OnEnter", function() hovered = true; Paint(rec) end)
        FollowScript(rec, button, "OnLeave", function() hovered = false; Paint(rec) end)
        FollowScript(rec, button, "OnClick", function()
            if w.open and w.pullout then
                local ok, err = pcall(SkinPullout, w.pullout)
                if not ok then Report(err) end
            end
        end)
    end
    KeepColor(rec, w.label)
    if w.text and w.text.SetJustifyH then
        rec.reapply = { function() w.text:SetJustifyH("LEFT") end }
        rec.restore[#rec.restore + 1] = function() w.text:SetJustifyH("RIGHT") end
    end
    Follow(rec, w, "SetDisabled")
    Follow(rec, w, "SetLabel")
    rec.paint = function()
        -- The box sits where Ace drew its own: the bottom 24 pixels, a little higher under a label.
        local lift = (w.label and w.label:IsShown()) and 5 or 1
        plate.edge:ClearAllPoints()
        plate.edge:SetPoint("BOTTOMLEFT", w.frame, "BOTTOMLEFT", 0, lift)
        plate.edge:SetPoint("BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", 0, lift)
        plate.edge:SetHeight(24)
        plate.fill:ClearAllPoints()
        plate.fill:SetPoint("BOTTOMLEFT", w.frame, "BOTTOMLEFT", 1, lift + 1)
        plate.fill:SetPoint("BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", -1, lift + 1)
        plate.fill:SetHeight(22)
        arrow:ClearAllPoints()
        arrow:SetPoint("BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", -6, lift + 5)
        plate:Paint(hovered, w.open, w.disabled)
        local ar, ag, ab = Accent()
        arrow:SetVertexColor(ar, ag, ab, w.disabled and 0.4 or 1)
        Muted(w.label, w.disabled)
    end
end

-- SharedMedia dropdowns (fonts, bars, borders, backgrounds, sounds): the same box; the open list as a KUI card.
function Skin.media(w, rec)
    local frame = w.frame
    Fade(rec, frame.DLeft)
    Fade(rec, frame.DMiddle)
    Fade(rec, frame.DRight)
    FadeButtonArt(rec, frame.dropButton)
    local plate = Plate(rec, frame)
    plate.edge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    plate.edge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    plate.edge:SetHeight(24)
    plate.fill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    plate.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    plate.fill:SetHeight(22)
    local arrow = Own(rec, frame:CreateTexture(nil, "OVERLAY"))
    arrow:SetTexture(ARROW)
    arrow:SetSize(14, 14)
    arrow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)
    local hovered = false
    FollowScript(rec, frame.dropButton, "OnEnter", function() hovered = true; Paint(rec) end)
    FollowScript(rec, frame.dropButton, "OnLeave", function() hovered = false; Paint(rec) end)
    -- The library resets the list's backdrop when it takes the list back, so it needs no restoring.
    FollowScript(rec, frame.dropButton, "OnClick", function()
        local list = w.dropdown
        if list and list.SetBackdrop then
            list:SetBackdrop(FLAT)
            list:SetBackdropColor(C("card"))
            list:SetBackdropBorderColor(Mix("cardBorder", 0.35))
        end
        Paint(rec)
    end)
    KeepColor(rec, frame.label)
    if frame.text and frame.text.SetJustifyH then
        rec.reapply = { function() frame.text:SetJustifyH("LEFT") end }
        rec.restore[#rec.restore + 1] = function() frame.text:SetJustifyH("RIGHT") end
    end
    Follow(rec, w, "SetDisabled")
    rec.paint = function()
        local disabled = w.disabled
        plate:Paint(hovered, w.dropdown ~= nil, disabled)
        local ar, ag, ab = Accent()
        arrow:SetVertexColor(ar, ag, ab, disabled and 0.4 or 1)
        Muted(frame.label, disabled)
    end
end

-- Colour swatch: a rounded square of the colour inside a thin edge.
function Skin.color(w, rec)
    FadeTextures(rec, w.frame)
    local edge = Own(rec, Round(w.frame, "OVERLAY", 0, 5))
    edge:SetSize(20, 20)
    edge:SetPoint("CENTER", w.colorSwatch, "CENTER", 0, 0)
    local swatch = Own(rec, Round(w.frame, "OVERLAY", 1, 4))
    swatch:SetSize(16, 16)
    swatch:SetPoint("CENTER", w.colorSwatch, "CENTER", 0, 0)
    local hovered = false
    FollowScript(rec, w.frame, "OnEnter", function() hovered = true; Paint(rec) end)
    FollowScript(rec, w.frame, "OnLeave", function() hovered = false; Paint(rec) end)
    Follow(rec, w, "SetColor")
    Follow(rec, w, "SetDisabled")
    rec.paint = function()
        local a = w.disabled and 0.4 or 1
        swatch:SetColor(w.r or 1, w.g or 1, w.b or 1, (w.a or 1) * a)
        edge:SetColor(Mix("cardBorder", hovered and 0.9 or 0.3, a))
    end
end

function Skin.button(w, rec)
    local paint = SkinButtonFrame(rec, w.frame)
    Follow(rec, w, "SetDisabled")
    rec.paint = paint
end

-- Label: KUI's font at the label's own size and outline. Ace sizes the label from its text, so the text is set again
-- for the height to follow the new font. A released label gets Ace's default font back.
function Skin.label(w, rec)
    Follow(rec, w, "SetFontObject")
    rec.restore[#rec.restore + 1] = function()
        if w.SetFontObject then w:SetFontObject() end
    end
    rec.paint = function()
        local fs, font = w.label, Font()
        if not (font and fs and fs.GetFont and fs.SetFont) then return end
        local path, size, flags = fs:GetFont()
        if path == font then return end
        fs:SetFont(font, size or 12, flags or "")
        if w.SetText and fs.GetText then w:SetText(fs:GetText()) end
    end
end

-- Heading: the title in the accent between two thin accent lines.
function Skin.heading(w, rec)
    Fade(rec, w.left)
    Fade(rec, w.right)
    local left = Own(rec, w.frame:CreateTexture(nil, "BACKGROUND"))
    local right = Own(rec, w.frame:CreateTexture(nil, "BACKGROUND"))
    for _, line in ipairs({ left, right }) do
        line:SetTexture(WHITE)
        line:SetHeight(1)
    end
    KeepColor(rec, w.label)
    Follow(rec, w, "SetText")
    rec.paint = function()
        local text = w.label:GetText()
        left:ClearAllPoints()
        right:ClearAllPoints()
        if text and text ~= "" then
            left:SetPoint("LEFT", w.frame, "LEFT", 3, 0)
            left:SetPoint("RIGHT", w.label, "LEFT", -8, 0)
            right:SetPoint("LEFT", w.label, "RIGHT", 8, 0)
            right:SetPoint("RIGHT", w.frame, "RIGHT", -3, 0)
            right:Show()
        else
            left:SetPoint("LEFT", w.frame, "LEFT", 3, 0)
            left:SetPoint("RIGHT", w.frame, "RIGHT", -3, 0)
            right:Hide()
        end
        local ar, ag, ab = Accent()
        left:SetVertexColor(ar, ag, ab, 0.35)
        right:SetVertexColor(ar, ag, ab, 0.35)
        w.label:SetTextColor(ar, ag, ab, 1)
    end
end

-- Group box: a KUI card with its title in the accent. The editor's two main boxes stay open (no card).
function Skin.inline(w, rec)
    local border = w.content and w.content.GetParent and w.content:GetParent()
    if not border or border == w.frame then border = nil end
    local card, edge
    if border then
        edge = Own(rec, Round(border, "BACKGROUND", 0, 8))
        edge:SetAllPoints(border)
        card = Own(rec, Round(border, "BACKGROUND", 1, 7))
        card:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
        card:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -1, 1)
    end
    KeepColor(rec, w.titletext)
    rec.paint = function()
        local open = root and (w == root.container or w == root.buttonsContainer)
        if border then
            Backdrop(rec, border)
            edge:SetShown(not open)
            card:SetShown(not open)
            edge:SetColor(C("cardBorder"))
            card:SetColor(C("card"))
        end
        local ar, ag, ab = Accent()
        if w.titletext then w.titletext:SetTextColor(ar, ag, ab, 1) end
    end
end

-- Ace's own tab group (sub-pages inside an aura's options): flat tabs with an accent underline, the page as a card.
local tabFonts
local function TabFonts()
    if not tabFonts and CreateFont then
        tabFonts = {}
        for _, key in ipairs({ "normal", "highlight", "disabled" }) do
            local font = CreateFont("KUIAR_EmbeddedSkinTab_" .. key)
            if GameFontHighlightSmall then font:CopyFontObject(GameFontHighlightSmall) end
            tabFonts[key] = font
        end
    end
    if tabFonts then
        local mr, mg, mb = C("muted")
        local tr, tg, tb = C("text")
        tabFonts.normal:SetTextColor(mr, mg, mb, 1)
        tabFonts.highlight:SetTextColor(tr, tg, tb, 1)
        tabFonts.disabled:SetTextColor(mr * 0.6, mg * 0.6, mb * 0.6, 1)
    end
    return tabFonts
end

local function SkinTab(rec, tab)
    rec.tabs = rec.tabs or {}
    if rec.tabs[tab] then return end
    local look = {}
    rec.tabs[tab] = look
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
        Fade(rec, tab[key])
    end
    Fade(rec, tab.GetHighlightTexture and tab:GetHighlightTexture())
    look.bg = Own(rec, Round(tab, "BACKGROUND", 0, 6))
    look.bg:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -1)
    look.bg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, -3)
    look.line = Own(rec, tab:CreateTexture(nil, "ARTWORK"))
    look.line:SetTexture(WHITE)
    look.line:SetHeight(2)
    look.line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, -3)
    look.line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, -3)
    look.fonts = { tab:GetNormalFontObject(), tab:GetHighlightFontObject(), tab:GetDisabledFontObject() }
    rec.restore[#rec.restore + 1] = function()
        local f = look.fonts
        if f[1] then tab:SetNormalFontObject(f[1]) end
        if f[2] then tab:SetHighlightFontObject(f[2]) end
        if f[3] then tab:SetDisabledFontObject(f[3]) end
    end
    FollowScript(rec, tab, "OnEnter", function() look.hovered = true; Paint(rec) end)
    FollowScript(rec, tab, "OnLeave", function() look.hovered = false; Paint(rec) end)
    Follow(rec, tab, "SetSelected")
    Follow(rec, tab, "SetDisabled")
    if rec.on then
        look.bg:Show()
        look.line:Show()
    end
end

function Skin.tabs(w, rec)
    for _, tab in ipairs(w.tabs) do SkinTab(rec, tab) end
    if hooksecurefunc then
        hooksecurefunc(w, "BuildTabs", function()
            if not rec.on then return end
            for _, tab in ipairs(w.tabs) do SkinTab(rec, tab) end
            Paint(rec)
        end)
    end
    rec.paint = function()
        Backdrop(rec, w.border, { C("card") }, { C("cardBorder") })
        local fonts = TabFonts()
        local ar, ag, ab = Accent()
        for tab, look in pairs(rec.tabs) do
            -- Ace disables the selected tab, so its "disabled" font is the selected one.
            if fonts then
                tab:SetNormalFontObject(fonts.normal)
                tab:SetHighlightFontObject(fonts.highlight)
                tab:SetDisabledFontObject((tab.selected and not tab.disabled) and fonts.highlight or fonts.disabled)
            end
            if tab.selected then
                look.bg:SetColor(Mix("rowHover", 0.16))
                look.line:SetVertexColor(ar, ag, ab, 1)
                look.line:Show()
            else
                if look.hovered and not tab.disabled then
                    look.bg:SetColor(C("rowHover"))
                else
                    look.bg:SetColor(0, 0, 0, 0)
                end
                look.line:Hide()
            end
        end
    end
end

-- Tree list (Ace's TreeGroup): the list and the page as KUI cards.
function Skin.tree(w, rec)
    local paintBar = SkinScrollBar(rec, w.scrollbar)
    rec.paint = function()
        Backdrop(rec, w.treeframe, { C("card") }, { C("cardBorder") })
        Backdrop(rec, w.border, { C("card") }, { C("cardBorder") })
        paintBar()
    end
end

-- Which skin a widget gets, by its parts (engine widgets reuse Ace's parts under their own type names).
local function KindOf(w)
    if type(w) ~= "table" or type(w.frame) ~= "table" then return nil end
    local t = w.type
    if w.checkbg and w.check then return "check" end
    if w.slider and w.editbox and w.lowtext then return "slider" end
    if w.leftbutton and w.rightbutton and w.editbox and w.progressBar then return "spin" end
    if w.dropdown and w.button_cover and w.dropdown.GetName then return "dropdown" end
    if w.frame.dropButton and w.frame.DLeft then return "media" end
    if w.editBox and w.scrollBG then return "multiline" end
    if w.colorSwatch then return "color" end
    if w.editbox and w.button and w.label and not w.slider then return "edit" end
    if t == "Button" then return "button" end
    if t == "Heading" then return "heading" end
    if t == "TabGroup" and w.tabs and w.border then return "tabs" end
    if w.treeframe and w.border then return "tree" end
    if t == "InlineGroup" and w.content then return "inline" end
    if (t == "Label" or t == "InteractiveLabel") and w.label then return "label" end
    return nil
end
M.KindOf = KindOf

local function SkinWidget(w)
    local rec = skins[w]
    if not rec then
        local kind = KindOf(w)
        if not kind then return end
        rec = Record(w, kind)
        local ok, err = pcall(Skin[kind], w, rec)
        if not ok then
            rec.paint = nil
            Report(err)
        end
    end
    -- A drawn widget follows its own state changes; only a widget back from the pool is drawn again.
    if not rec.on then Activate(rec) end
end

local function SkinTree(w, depth)
    if type(w) ~= "table" or (depth or 0) > 40 then return end
    local ok, err = pcall(SkinWidget, w)
    if not ok then Report(err) end
    if type(w.children) == "table" then
        for _, child in ipairs(w.children) do SkinTree(child, (depth or 0) + 1) end
    end
end
M.SkinTree = SkinTree

-----------------------------------------------------------------------------------------------------------------------
-- Hooks into AceGUI
-----------------------------------------------------------------------------------------------------------------------

local function Inside(frame)
    if not root then return false end
    local depth = 0
    while frame and depth < 60 do
        if frame == root then return true end
        frame = frame.GetParent and frame:GetParent() or nil
        depth = depth + 1
    end
    return false
end
M.Inside = Inside

local wrapped = setmetatable({}, { __mode = "k" })

local function Wrap(layout)
    if type(layout) ~= "function" or wrapped[layout] then return layout end
    local function SkinnedLayout(content, children)
        -- The whole subtree: Ace fills a group before it hangs that group in the editor.
        if root and type(children) == "table" and Inside(content) then
            for _, child in ipairs(children) do M.SkinTree(child) end
        end
        return layout(content, children)
    end
    wrapped[SkinnedLayout] = true
    return SkinnedLayout
end

local hooked
local function HookAceGUI()
    -- The engine's option forms use the engine's own AceGUI, from its library registry.
    local stub = ns.EmbeddedAuraEngine and ns.EmbeddedAuraEngine.LibStub
    local AceGUI = stub and stub:GetLibrary("AceGUI-3.0", true)
    if not AceGUI then return end
    local registry = AceGUI.LayoutRegistry
    if type(registry) == "table" then
        for name, layout in pairs(registry) do registry[name] = Wrap(layout) end
    end
    if hooked == AceGUI then return end
    hooked = AceGUI
    local register = AceGUI.RegisterLayout
    if type(register) == "function" then
        AceGUI.RegisterLayout = function(self, name, layout)
            return register(self, name, Wrap(layout))
        end
    end
    -- A released widget goes back to the shared pool with its own look.
    if hooksecurefunc and type(AceGUI.Release) == "function" then
        hooksecurefunc(AceGUI, "Release", function(_, widget)
            local rec = type(widget) == "table" and skins[widget]
            if rec then Deactivate(rec) end
        end)
    end
end

-- Repaint everything on screen after an accent or skin change.
local repaintRegistered
local function RegisterRepaint()
    if repaintRegistered then return end
    local menu = KT.MenuSkins
    if menu and menu.RegisterRepaint then
        repaintRegistered = true
        menu:RegisterRepaint(function()
            for rec in pairs(active) do Paint(rec) end
        end)
    end
end

-- Wrapped at load, before the engine's options build their first containers.
HookAceGUI()

-- The list's search box (Blizzard's SearchBoxTemplate): the same plate as the text boxes.
local function SkinSearch(box)
    if type(box) ~= "table" or not box.GetRegions then return end
    local rec = skins[box]
    if not rec then
        rec = Record(box, "search")
        local icon = box.searchIcon
        for _, region in ipairs({ box:GetRegions() }) do
            if region ~= icon and region.IsObjectType and region:IsObjectType("Texture") then Fade(rec, region) end
        end
        local plate = Plate(rec, box)
        plate:Place(box, -5, 1, 0, -1)
        local focused = false
        FollowScript(rec, box, "OnEditFocusGained", function() focused = true; Paint(rec) end)
        FollowScript(rec, box, "OnEditFocusLost", function() focused = false; Paint(rec) end)
        rec.paint = function()
            plate:Paint(false, focused, false)
            if icon and icon.SetVertexColor then icon:SetVertexColor(C("muted")) end
        end
    end
    if not rec.on then Activate(rec) end
end

-- Called by the editor presentation each time it lays the editor out.
function M.Attach(frame)
    if not frame then return end
    root = frame
    HookAceGUI()
    RegisterRepaint()
    local ok, err = pcall(SkinSearch, frame.filterInput)
    if not ok then Report(err) end
    SkinTree(frame.container)
    SkinTree(frame.buttonsContainer)
end

-- The engine's own windows (import, update, code editor, pickers) add plain Blizzard panel buttons and a scroll bar to
-- their Ace controls. These windows are built once and never released, so their skin stays on.
local function PanelButton(button)
    return type(button) == "table" and button.IsObjectType and button:IsObjectType("Button")
        and button.Left and button.Middle and button.Right and true or false
end

local function SkinOnce(object, kind, build)
    local rec = skins[object]
    if not rec then
        rec = Record(object, kind)
        local ok, paint = pcall(build, rec, object)
        if ok then rec.paint = paint else Report(paint) end
    end
    if not rec.on then Activate(rec) end
end

function M.SkinWindow(window)
    if type(window) ~= "table" or type(window.frame) ~= "table" then return end
    SkinTree(window)
    if window.scrollbar then SkinOnce(window.scrollbar, "scrollbar", SkinScrollBar) end
    local frame = window.frame
    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if PanelButton(child) then
            SkinOnce(child, "panelbutton", SkinButtonFrame)
            -- The code editor hangs one button on another.
            for _, sub in ipairs({ child:GetChildren() }) do
                if PanelButton(sub) then SkinOnce(sub, "panelbutton", SkinButtonFrame) end
            end
        end
    end
end

-- For tests: the record of a widget.
function M.RecordOf(widget)
    return skins[widget]
end
