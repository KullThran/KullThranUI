local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

-- The KUI material shared by Blizzard skins and KUI's own windows: a tiled
-- grain (darkness baked into the file, no wash on top), a stretched vignette
-- and a header sheen. The tile always spans 512 physical pixels, so the grain
-- looks the same at any UI scale and is never magnified.
local Surface = {}
KT.Surface = Surface

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Surface\\"
local TILE, VIGNETTE, HEADER = MEDIA .. "tile.tga", MEDIA .. "vignette.tga", MEDIA .. "header.tga"
local TILE_PIXELS = 512
local DEFAULT_COLOR = { 0.05, 0.05, 0.05, 0.98 }

Surface.tokens = {
    -- Overall darkness of the material, every level (1 = the tile as drawn).
    darken = 0.80,
    tintStrength = 0.35,
    headerHeight = 26,
    window = { tileAlpha = 1, vignetteAlpha = 1, headerAlpha = 1 },
    inset = { tileShade = 0.72, tileAlpha = 0.9 },
    -- Button face ("Neutro"): material over a dark base, a small vertical
    -- gradient, and a light/dark overlay for hover/pressed.
    control = {
        base = { 0.078, 0.078, 0.086, 0.94 }, tileAlpha = 0.6,
        gradientTop = 0.086, gradientBottom = 0.27, hover = 0.08, pressed = 0.27, disabled = 0.35,
    },
}

local surfaces = setmetatable({}, { __mode = "k" })

local function usable(v)
    return type(v) == "number" and v > 0 and not (issecretvalue and issecretvalue(v))
end

-- Texture coordinates that make one tile cover 512 physical pixels.
function Surface.TileCoords(width, height, effectiveScale, physicalHeight)
    if not (usable(width) and usable(height) and usable(effectiveScale) and usable(physicalHeight)) then return nil end
    local pixelsPerUnit = effectiveScale * physicalHeight / 768
    return width * pixelsPerUnit / TILE_PIXELS, height * pixelsPerUnit / TILE_PIXELS
end

-- The window colour only lends its hue; grey and black leave the tile as drawn.
function Surface.Tint(color)
    local r, g, b = color[1] or 0, color[2] or 0, color[3] or 0
    local high, low = math.max(r, g, b), math.min(r, g, b)
    if high <= 0.0001 or high - low < 0.001 then return 1, 1, 1 end
    local s = Surface.tokens.tintStrength
    return 1 - s * (1 - r / high), 1 - s * (1 - g / high), 1 - s * (1 - b / high)
end

local function fit(data)
    local tile = data.tile
    local width, height = tile:GetSize()
    local _, physicalHeight = GetPhysicalScreenSize()
    local right, bottom = Surface.TileCoords(width, height, data.frame:GetEffectiveScale(), physicalHeight)
    if right then tile:SetTexCoord(0, right, 0, bottom) end
end

local function texture(frame, sub, path)
    local t = frame:CreateTexture(nil, "BACKGROUND", nil, sub)
    if path then t:SetTexture(path) end
    t:SetAllPoints(frame)
    return t
end

local function paint(data)
    local tokens, level, color = Surface.tokens, data.level, data.color
    local alpha = color[4] or 1
    local r, g, b = Surface.Tint(color)
    local tile = data.tile

    if level == "control" then
        local ct = tokens.control
        if not data.base then
            local frame = data.frame
            data.base = texture(frame, -8)
            -- Light over the top half, shade over the bottom half; anchored to
            -- the middle so it follows any button height.
            data.gradientTop = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
            data.gradientTop:SetTexture("Interface\\Buttons\\WHITE8x8")
            data.gradientTop:SetPoint("TOPLEFT", frame, "TOPLEFT")
            data.gradientTop:SetPoint("BOTTOMRIGHT", frame, "RIGHT")
            data.gradientBottom = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
            data.gradientBottom:SetTexture("Interface\\Buttons\\WHITE8x8")
            data.gradientBottom:SetPoint("TOPLEFT", frame, "LEFT")
            data.gradientBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
            data.state = texture(frame, -2)
            data.state:Hide()
        end
        local base = ct.base
        local dk = (tokens.darken or 1) * (data.darken or 1)
        data.base:SetColorTexture(base[1] * dk, base[2] * dk, base[3] * dk, base[4])
        data.base:SetAlpha(alpha)
        data.base:Show()
        data.gradientTop:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, ct.gradientTop))
        data.gradientBottom:SetGradient("VERTICAL", CreateColor(0, 0, 0, ct.gradientBottom), CreateColor(0, 0, 0, 0))
        data.gradientTop:Show()
        data.gradientBottom:Show()
    elseif data.base then
        data.base:Hide()
        data.gradientTop:Hide()
        data.gradientBottom:Hide()
        data.state:Hide()
    end

    local tileAlpha = level == "window" and tokens.window.tileAlpha
        or level == "inset" and tokens.inset.tileAlpha or tokens.control.tileAlpha
    local shade = (level == "inset" and tokens.inset.tileShade or level == "window" and data.shade or 1)
        * (tokens.darken or 1) * (data.darken or 1)
    tile:SetTexture(data.tilePath or TILE, "REPEAT", "REPEAT")
    tile:SetVertexColor(r * shade, g * shade, b * shade, 1)
    tile:SetAlpha(tileAlpha * alpha)
    tile:Show()

    if level == "window" then
        data.vignette:SetAlpha(tokens.window.vignetteAlpha * alpha)
        data.vignette:Show()
    else
        data.vignette:Hide()
    end
    if level == "window" and data.header ~= false then
        data.headerTexture:SetHeight(data.headerHeight or tokens.headerHeight)
        data.headerTexture:SetAlpha(tokens.window.headerAlpha * alpha)
        data.headerTexture:Show()
    else
        data.headerTexture:Hide()
    end
    fit(data)
end

-- level: "window" (default) | "inset" | "control".
-- opts.header: false hides the header sheen; opts.color: { r, g, b, a };
-- opts.shade: darkens a window tile (0-1) so its controls stand out;
-- opts.headerHeight: header band height when the window's title sits lower;
-- opts.tile: a window's own tiled material in place of the shared tile;
-- opts.darken: extra darkness for this surface only (0-1, on top of tokens.darken).
function Surface:Apply(frame, level, opts)
    if not frame or not frame.CreateTexture or (frame.IsForbidden and frame:IsForbidden()) then return end
    opts = opts or {}
    local data = surfaces[frame]
    if not data then
        data = { frame = frame }
        surfaces[frame] = data
        data.tile = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        data.tile:SetAllPoints(frame)
        data.vignette = texture(frame, -6, VIGNETTE)
        data.headerTexture = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        data.headerTexture:SetTexture(HEADER)
        data.headerTexture:SetPoint("TOPLEFT", frame, "TOPLEFT")
        data.headerTexture:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
        frame:HookScript("OnSizeChanged", function() fit(data) end)
    end
    data.level = level or "window"
    data.header = opts.header
    data.shade = opts.shade
    data.headerHeight = opts.headerHeight
    data.tilePath = opts.tile
    data.darken = opts.darken
    data.hidden = nil
    data.color = opts.color or data.color or DEFAULT_COLOR
    paint(data)
    return data.tile, data.vignette, data.headerTexture
end

-- Hides every layer of a surface (a frame switching to another look);
-- Refresh leaves it hidden and the next Apply shows it again.
function Surface:Hide(frame)
    local data = surfaces[frame]
    if not data then return end
    data.hidden = true
    for _, key in ipairs({ "tile", "vignette", "headerTexture", "base", "gradientTop", "gradientBottom", "state" }) do
        if data[key] then data[key]:Hide() end
    end
end

-- Button feedback on a control surface: "normal", "hover", "pressed" or "disabled".
function Surface:SetControlState(frame, state)
    local data = surfaces[frame]
    if not (data and data.state) then return end
    local ct = Surface.tokens.control
    if state == "hover" then
        data.state:SetColorTexture(1, 1, 1, ct.hover)
        data.state:Show()
    elseif state == "pressed" then
        data.state:SetColorTexture(0, 0, 0, ct.pressed)
        data.state:Show()
    elseif state == "disabled" then
        data.state:SetColorTexture(0, 0, 0, ct.disabled)
        data.state:Show()
    else
        data.state:Hide()
    end
end

-- Re-applies every registered surface, optionally with a new window colour.
function Surface:Refresh(color)
    for _, data in pairs(surfaces) do
        if color then data.color = color end
        if not data.hidden then paint(data) end
    end
end

-- Older entry point: the window level without the header. washAlpha is
-- ignored (the darkness lives in the tile); returns the tile and vignette.
function KT:ApplyTexturedSurface(frame, color, washAlpha)
    local tile, vignette = Surface:Apply(frame, "window", { color = color, header = false })
    return tile, vignette
end

local scaleWatcher = CreateFrame("Frame")
scaleWatcher:RegisterEvent("UI_SCALE_CHANGED")
scaleWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleWatcher:SetScript("OnEvent", function()
    for _, data in pairs(surfaces) do fit(data) end
end)
