-- Native Cast Bar art shared by the player bar and the module previews.
local S = _G.KT.CastBarStyles
local CLASSIC_FILL = "Interface\\TargetingFrame\\UI-StatusBar"
local CLASSIC_BORDER = "Interface\\CastingBar\\UI-CastingBar-Border"
local CLASSIC_SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"

local function AtlasName(name, fallback)
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        if ok and info then return name end
        if fallback then
            ok, info = pcall(C_Texture.GetAtlasInfo, fallback)
            if ok and info then return fallback end
        end
    end
    return name
end

-- Retail / Forever draw the native cast bar from packaged art (cropped from each client's own
-- atlases), so both look the same on either client. rects = { x, y, w, h } in sheet pixels.
local PACK_DIR = [[Interface\AddOns\KullThranUI\Libraries\texture\media\castbar\]]
local PACKS = {
    forever = { file = PACK_DIR .. "castbar_forever.tga", w = 512, h = 128, rects = {
        frame = { 1, 1, 213, 15 }, background = { 216, 1, 211, 13 }, textbox = { 1, 18, 210, 29 }, pip = { 213, 18, 6, 30 } } },
    retail = { file = PACK_DIR .. "castbar_retail.tga", w = 512, h = 128, rects = {
        frame = { 1, 1, 214, 16 }, background = { 217, 1, 209, 11 }, textbox = { 1, 19, 210, 28 }, pip = { 213, 19, 6, 30 } } },
}

local function Pack(texture, style, key)
    local pack, r = PACKS[style], PACKS[style] and PACKS[style].rects[key]
    if not r then return false end
    texture:SetTexture(pack.file)
    texture:SetTexCoord(r[1] / pack.w, (r[1] + r[3]) / pack.w, r[2] / pack.h, (r[2] + r[4]) / pack.h)
    texture:SetVertexColor(1, 1, 1, 1)
    return true
end

-- Draws one packaged piece as left cap / stretched middle / right cap around `bar`, so rounded
-- corners keep their shape at any width. `field` is art.<field> (the middle piece).
local function Slice3(art, field, style, key, bar, x, y, cap)
    local pack = PACKS[style]
    local r = pack and pack.rects[key]
    if not r then return end
    local mid = art[field]
    local layer, sub = mid:GetDrawLayer()
    local pieces = { mid, art[field .. "L"], art[field .. "R"] }
    for i = 2, 3 do
        if not pieces[i] then
            pieces[i] = bar:CreateTexture(nil, layer, nil, sub)
            art[field .. (i == 2 and "L" or "R")] = pieces[i]
        else
            pieces[i]:SetDrawLayer(layer, sub)
        end
    end
    local regionH = bar:GetHeight() + 2 * y
    local capW = cap * regionH / r[4]
    local function setup(tex, x0, x1)
        tex:SetTexture(pack.file)
        tex:SetTexCoord(x0 / pack.w, x1 / pack.w, r[2] / pack.h, (r[2] + r[4]) / pack.h)
        tex:SetVertexColor(1, 1, 1, 1)
        tex:ClearAllPoints()
    end
    local left, right = pieces[2], pieces[3]
    setup(left, r[1], r[1] + cap)
    setup(right, r[1] + r[3] - cap, r[1] + r[3])
    setup(mid, r[1] + cap, r[1] + r[3] - cap)
    left:SetPoint("TOPLEFT", bar, "TOPLEFT", -x, y); left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -x, -y); left:SetWidth(capW)
    right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", x, y); right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", x, -y); right:SetWidth(capW)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT"); mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    left:Show(); right:Show(); mid:Show()
end

function S:IconMetrics(db)
    local style = self:GetStyle(db)
    if style == "classic" then return math.min(db.height or 13, 18), 4, 0 end
    if style ~= "kui" then return 16, 5, 0 end
    return db.height or 25, 2, 0
end

function S:Color(db, bar)
    local style = self:GetStyle(db)
    if style == "kui" then return nil end
    if style ~= "classic" then return 1, 1, 1, 1 end
    if bar and bar.channeling then return 0, 1, 0, 1 end
    return 1, 0.7, 0, 1
end

function S:ApplyFill(bar, db)
    local style = self:GetStyle(db)
    if style == "kui" then return end
    if style == "classic" then
        bar:SetStatusBarTexture(CLASSIC_FILL, "ARTWORK")
    else
        local channel = bar.channeling and not bar.empowering
        -- Filling is the striped casting art. Full is Blizzard's completed
        -- cast texture and must not replace it while a spell is progressing.
        bar:SetStatusBarTexture(AtlasName(channel and "ui-castingbar-filling-channel" or "ui-castingbar-filling-standard",
            channel and "UI-CastingBar-Filling-Channel" or "UI-CastingBar-Filling-Standard"))
    end
    local fill = bar:GetStatusBarTexture()
    if fill then
        -- Texture objects survive style switches: discard atlas UVs for the
        -- Classic file. The frame must remain above the fill and latency zone.
        if style == "classic" then fill:SetTexCoord(0, 1, 0, 1) end
        fill:SetDrawLayer("ARTWORK", style == "classic" and 0 or 1)
        fill:SetDesaturated(false)
        fill:SetAlpha(1)
    end
    local r, g, b, a = self:Color(db, bar)
    bar:SetStatusBarColor(r, g, b, a)
    -- Apply the native tint to the actual region too. Some client builds keep
    -- a previous vertex color when the StatusBar swaps an atlas for a file.
    if fill then fill:SetVertexColor(r, g, b, a) end
end

local function Rect(tex, bar, x, y)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", bar, "TOPLEFT", -x, y)
    tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", x, -y)
end

-- How far the text plate hangs below the bar (0 when the style has none).
-- The plate is as wide as the bar's frame (bar + 4), keeping its native proportions.
function S:PlateScale(barWidth)
    return math.min(2, math.max(0.6, ((tonumber(barWidth) or 209) + 4) / 210))
end

function S:PlateExtent(db, bar)
    local style = self:GetStyle(db)
    local pack = PACKS[style]
    if not pack then return 0 end
    local width = (bar and bar:GetWidth()) or (db and db.width) or 209
    local scale = self:PlateScale(width)
    return math.max(0, math.floor(pack.rects.textbox[4] * scale - 4 * scale + 0.5))
end

function S:Apply(bar, db)
    local style = self:GetStyle(db)
    local KT = _G.KT
    if bar.classicBorder and KT.VisualThemes.ShowClassicBorder then
        KT.VisualThemes:ShowClassicBorder(bar.classicBorder, false)
    end
    local art = bar._ktCastStyleArt
    if not art then
        art = { background = bar:CreateTexture(nil, "BACKGROUND", nil, -1),
            border = bar:CreateTexture(nil, "OVERLAY", nil, 1) }
        bar._ktCastStyleArt = art
    end
    art.background:Hide(); art.border:Hide()
    for _, name in ipairs({ "backgroundL", "backgroundR", "borderL", "borderR" }) do
        if art[name] then art[name]:Hide() end
    end
    if art.textbox then art.textbox:Hide() end
    if art.textboxBack then art.textboxBack:Hide() end
    for _, extra in ipairs(art.textboxExtra or {}) do extra:Hide() end
    if bar.PreviewBackground then bar.PreviewBackground:SetShown(style == "kui") end
    if bar.SetBackdropColor then
        bar:SetBackdropColor(0, 0, 0, style == "kui" and 0.5 or 0)
        bar:SetBackdropBorderColor(0, 0, 0, style == "kui" and 1 or 0)
    end
    local textY = style == "classic" and 1 or 0
    bar.Text:ClearAllPoints(); bar.Text:SetPoint("LEFT", bar, "LEFT", 5, textY)
    bar.Time:ClearAllPoints(); bar.Time:SetPoint("RIGHT", bar, "RIGHT", -5, textY)
    if style ~= "kui" then
        bar.Text:ClearAllPoints()
        bar.Text:SetPoint("CENTER", bar, "CENTER", -30, textY)
        bar.Text:SetJustifyH("CENTER")
    else
        bar.Text:SetJustifyH("LEFT")
    end
    if style == "classic" then
        bar.Text:SetShadowOffset(1, -1)
        bar.Time:SetShadowOffset(1, -1)
    else
        bar.Text:SetShadowOffset(0, 0)
        bar.Time:SetShadowOffset(0, 0)
    end
    -- Retail / Forever: Blizzard's text plate under the bar, with the spell name centred on it
    if PACKS[style] then
        if not art.textbox then art.textbox = bar:CreateTexture(nil, "BACKGROUND", nil, -2) end
        local r = PACKS[style].rects.textbox
        local scale = S:PlateScale(bar:GetWidth())
        Pack(art.textbox, style, "textbox")
        art.textbox:ClearAllPoints()
        art.textbox:SetPoint("TOP", bar, "BOTTOM", 0, 4 * scale)
        art.textbox:SetSize(r[3] * scale, r[4] * scale)
        art.textbox:Show()
        -- Retail's own plate is a nearly transparent dark panel: stack the same rounded art a
        -- few times so it has a body without losing its rounded border
        if style == "retail" then
            art.textboxExtra = art.textboxExtra or {}
            for i = 1, 2 do
                local extra = art.textboxExtra[i]
                if not extra then
                    extra = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
                    art.textboxExtra[i] = extra
                end
                Pack(extra, style, "textbox")
                extra:ClearAllPoints()
                extra:SetAllPoints(art.textbox)
                extra:Show()
            end
        end
        bar.Text:ClearAllPoints()
        bar.Text:SetPoint("CENTER", art.textbox, "CENTER", 0, -2 * scale)
        bar.Text:SetJustifyH("CENTER")
    end
    bar.Text:SetDrawLayer("OVERLAY", 7)
    bar.Time:SetDrawLayer("OVERLAY", 7)
    bar.Time:SetJustifyH("RIGHT")
    bar.Text:SetWidth(math.max(10, bar:GetWidth() - (style == "kui" and 45 or 65)))
    if bar.SafeZone then
        bar.SafeZone:SetDrawLayer(style == "classic" and "ARTWORK" or "OVERLAY", style == "classic" and 1 or 0)
    end
    bar.Spark:SetBlendMode("ADD")
    bar.Spark:SetTexCoord(0, 1, 0, 1)
    if style == "kui" then
        bar.Spark:SetTexture(CLASSIC_SPARK)
        bar.Spark:SetSize(20, bar:GetHeight() * 2)
    elseif style == "classic" then
        -- Blizzard Classic uses original file textures, not the modern atlas.
        art.background:SetColorTexture(0, 0, 0, 0.5)
        Rect(art.background, bar, 0, 0)
        -- The transparent stock frame trims the fill at the interior edges.
        art.border:SetDrawLayer("ARTWORK", 2)
        art.border:SetTexture(CLASSIC_BORDER)
        art.border:SetTexCoord(0, 1, 0, 1)
        art.border:ClearAllPoints()
        local ratio, verticalRatio = bar:GetWidth() / 195, bar:GetHeight() / 13
        art.border:SetSize(256 * ratio, 64 * verticalRatio)
        art.border:SetPoint("TOP", bar, "TOP", 0, 28 * verticalRatio)
        bar.Spark:SetTexture(CLASSIC_SPARK)
        bar.Spark:SetSize(32, 32)
    else
        if PACKS[style] then
            Slice3(art, "background", style, "background", bar, 1, 1, 5)
            art.border:SetDrawLayer("ARTWORK", 2)
            Slice3(art, "border", style, "frame", bar, 2, 2, 8)
            Pack(bar.Spark, style, "pip")
            bar.Spark:SetSize(8, 20)
        else
            art.background:SetAtlas(AtlasName("ui-castingbar-background"), false)
            art.background:SetVertexColor(1, 1, 1, 1)
            Rect(art.background, bar, 1, 1)
            art.border:SetDrawLayer("ARTWORK", 2)
            art.border:SetAtlas(AtlasName("ui-castingbar-frame"), false)
            art.border:SetVertexColor(1, 1, 1, 1)
            Rect(art.border, bar, 2, 2)
            bar.Spark:SetAtlas(AtlasName("ui-castingbar-pip"), false)
            bar.Spark:SetSize(8, 20)
        end
    end
    if style ~= "kui" then
        art.background:Show(); art.border:Show()
        self:ApplyFill(bar, db)
    end
    if not self:ShowsIcon(db) then
        if bar.Icon then bar.Icon:Hide() end
        if bar.IconBg then bar.IconBg:Hide() end
    end
    if bar.Icon and self:ShowsIcon(db) then
        local size, gap, y = self:IconMetrics(db)
        bar.Icon:SetSize(size, size)
        bar.Icon:ClearAllPoints()
        if db.iconPosition == "RIGHT" then bar.Icon:SetPoint("LEFT", bar, "RIGHT", gap, y)
        else bar.Icon:SetPoint("RIGHT", bar, "LEFT", -gap, y) end
        if bar.IconBg then
            bar.IconBg:ClearAllPoints()
            bar.IconBg:SetPoint("TOPLEFT", bar.Icon, "TOPLEFT", -1, 1)
            bar.IconBg:SetPoint("BOTTOMRIGHT", bar.Icon, "BOTTOMRIGHT", 1, -1)
            if style == "classic" and db.iconShape ~= "CIRCLE" then
                bar.IconBg:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                bar.IconBg:SetBackdropBorderColor(0.62, 0.52, 0.36, 1)
                bar.IconBg:Show()
            elseif style ~= "kui" then
                bar.IconBg:Hide()
            else
                bar.IconBg:SetBackdropBorderColor(0, 0, 0, 1)
            end
        end
    end
end
