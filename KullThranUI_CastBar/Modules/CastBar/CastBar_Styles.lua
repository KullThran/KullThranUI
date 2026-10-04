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
