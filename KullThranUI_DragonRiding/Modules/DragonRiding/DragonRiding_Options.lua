-- Modules/DragonRiding/DragonRiding_Options.lua
-- Registers the "Dragon Riding" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local GetFontValues = Opt.GetFontValues
local GetStatusbarValues = Opt.GetStatusbarValues

local PREVIEW_SPELLS = {
    361584, -- Whirling Surge
    403092, -- Bronze Timelock
}

local PREVIEW_VIGOR_MAX = 6

local function GetPreviewVigorCharges()
    if C_Spell and C_Spell.GetSpellCharges then
        local ok, chargeInfo = pcall(C_Spell.GetSpellCharges, 372608)
        if ok and type(chargeInfo) == "table" and tonumber(chargeInfo.maxCharges or 0) > 0 then
            return tonumber(chargeInfo.currentCharges) or PREVIEW_VIGOR_MAX,
                tonumber(chargeInfo.maxCharges) or PREVIEW_VIGOR_MAX
        end
    end

    if GetSpellCharges then
        local currentCharges, maxCharges = GetSpellCharges(372608)
        if tonumber(maxCharges or 0) > 0 then
            return tonumber(currentCharges) or PREVIEW_VIGOR_MAX, tonumber(maxCharges) or PREVIEW_VIGOR_MAX
        end
    end

    return PREVIEW_VIGOR_MAX, PREVIEW_VIGOR_MAX
end

local function RefreshDragonRiding()
    local M = KT:GetModule("DragonRiding", true)
    if M and M.Refresh then
        M:Refresh()
    end
end

local function ScrollToBlock(frame)
    if not (frame and KT and KT.SmoothScrollTo) then return end

    local sf = KT._scrollFrame or (KT.MenuPrincipal and KT.MenuPrincipal.scrollFrame)
    local child = sf and sf.GetScrollChild and sf:GetScrollChild()
    local sectionTop = frame.GetTop and frame:GetTop()
    local childTop = child and child.GetTop and child:GetTop()
    if sectionTop and childTop then
        KT.SmoothScrollTo(math.max(0, (childTop - sectionTop) - 40))
    end
end

KT:RegisterPage("dragonriding", LText("Dragon Riding"), 60, function(sc, W)
    local y, h = 0, 0
    local previewTargets = {}
    local db = KT.db and KT.db.profile and KT.db.profile.dragonRiding
    if not db then
        KT.db.profile.dragonRiding = KT.db.profile.dragonRiding or {}
        db = KT.db.profile.dragonRiding
    end

    -- Live Preview
    local prevContainer = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, 120)
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    if KT.AddBackdrop then KT:AddBackdrop(prevContainer, 0.1, 0.1, 0.1, 0.4) end
    if KT.AddBorder then KT:AddBorder(prevContainer, 0, 0, 0, 1) end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(prevContainer, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
    end

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 10, -8)
    lblPrev:SetText(LText("LIVE PREVIEW (DRAGON RIDING)"))
    KT:SetAccentTextColor(lblPrev, 1)

    local fakeBar = CreateFrame("StatusBar", nil, prevContainer, "BackdropTemplate")
    fakeBar:SetPoint("CENTER", 0, 10)
    fakeBar:SetMinMaxValues(0, 100)
    fakeBar:SetValue(100)
    if KT.AddBorder then KT:AddBorder(fakeBar, 0, 0, 0, 1) end

    local fakeText = fakeBar:CreateFontString(nil, "OVERLAY")
    fakeText:SetPoint("CENTER")

    local fakeVigor = CreateFrame("Frame", nil, prevContainer)
    fakeVigor:SetPoint("TOP", fakeBar, "BOTTOM", 0, -8)

    local previewIcons = {}
    for i, spellID in ipairs(PREVIEW_SPELLS) do
        local iconFrame = CreateFrame("Frame", nil, prevContainer, "BackdropTemplate")
        if KT.AddBorder then KT:AddBorder(iconFrame, 0, 0, 0, 1) end

        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(C_Spell.GetSpellTexture(spellID))
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        if i == 1 then
            iconFrame:SetPoint("RIGHT", fakeBar, "LEFT", -6, 0)
        else
            iconFrame:SetPoint("LEFT", fakeBar, "RIGHT", 6, 0)
        end

        iconFrame.Icon = icon
        previewIcons[i] = iconFrame
    end

    local function CreatePreviewHitbox(target, label, blockKey)
        local btn = CreateFrame("Button", nil, prevContainer)
        btn:SetAllPoints(target)
        btn:RegisterForClicks("LeftButtonDown")
        btn:SetFrameLevel((target:GetFrameLevel() or prevContainer:GetFrameLevel()) + 10)

        local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        border:SetAllPoints()
        if KT.AddBorder then KT:AddAccentBorder(border, 1) end
        border:Hide()

        local hint = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOM", btn, "TOP", 0, 4)
        hint:SetText(LText(label))
        hint:SetTextColor(1, 1, 1, 0.95)
        hint:Hide()

        btn:SetScript("OnEnter", function()
            border:Show()
            hint:Show()
        end)
        btn:SetScript("OnLeave", function()
            border:Hide()
            hint:Hide()
        end)
        btn:SetScript("OnMouseDown", function()
            ScrollToBlock(previewTargets[blockKey])
        end)

        return btn
    end

    local barHit = CreatePreviewHitbox(fakeBar, "Go to Size", "size")
    local vigorHit = CreatePreviewHitbox(fakeVigor, "Go to Position", "position")
    local leftIconHit = CreatePreviewHitbox(previewIcons[1], "Go to Style", "style")
    local rightIconHit = CreatePreviewHitbox(previewIcons[2], "Go to Style", "style")

    local function FetchFont(fontKey)
        if LSM and fontKey then
            local fetched = LSM:Fetch("font", fontKey)
            if fetched then return fetched end
        end
        return "Fonts\\FRIZQT__.TTF"
    end

    local function FetchStatusbarTex(texKey)
        if LSM and texKey then
            local fetched = LSM:Fetch("statusbar", texKey)
            if fetched then return fetched end
        end
        return "Interface\\Buttons\\WHITE8x8"
    end

    local function UpdatePreview()
        local w = tonumber(db.width) or 250
        local hgt = tonumber(db.height) or 16
        local iconSize = hgt + 16
        local vigorCount, vigorMax = GetPreviewVigorCharges()
        vigorCount = math.min(PREVIEW_VIGOR_MAX, math.max(0, tonumber(vigorCount) or PREVIEW_VIGOR_MAX))
        vigorMax = math.min(PREVIEW_VIGOR_MAX, math.max(1, tonumber(vigorMax) or PREVIEW_VIGOR_MAX))
        local pipGap = 4
        local pipW = math.max(16, math.floor((w - (pipGap * (PREVIEW_VIGOR_MAX - 1))) / PREVIEW_VIGOR_MAX))
        fakeBar:SetSize(w, hgt)

        local tex = FetchStatusbarTex(db.texture or "Melli")
        fakeBar:SetStatusBarTexture(tex)
        fakeBar:SetStatusBarColor(1, 0.2, 0.2, 1)

        local font = FetchFont(db.font or "AAA_ITC_Avant_Garde")
        fakeText:SetFont(font, 16, db.fontOutline or "OUTLINE")
        fakeText:SetText("100%")
        if db.showSpeedText ~= false then
            fakeText:Show()
        else
            fakeText:Hide()
        end

        fakeVigor:SetSize((pipW * PREVIEW_VIGOR_MAX) + (pipGap * (PREVIEW_VIGOR_MAX - 1)), 6)
        fakeVigor.pips = fakeVigor.pips or {}
        for i = 1, PREVIEW_VIGOR_MAX do
            local p = fakeVigor.pips[i]
            if not p then
                p = CreateFrame("StatusBar", nil, fakeVigor, "BackdropTemplate")
                if KT.AddBorder then KT:AddBorder(p, 0, 0, 0, 1) end
                fakeVigor.pips[i] = p
            end
            p:SetSize(pipW, 6)
            p:SetStatusBarTexture(tex)
            p:ClearAllPoints()
            if i == 1 then
                p:SetPoint("LEFT", fakeVigor, "LEFT", 0, 0)
            else
                p:SetPoint("LEFT", fakeVigor.pips[i - 1], "RIGHT", pipGap, 0)
            end
            if i <= vigorCount then
                p:SetAlpha(1)
                p:SetStatusBarColor(1, 1, 1, 1)
                p:SetValue(1)
            elseif i == (vigorCount + 1) and vigorCount < vigorMax then
                p:SetAlpha(1)
                p:SetStatusBarColor(1, 1, 1, 1)
                p:SetValue(0.6)
            else
                p:SetAlpha(0.35)
                p:SetStatusBarColor(0.45, 0.45, 0.45, 1)
                p:SetValue(0)
            end
            p:Show()
        end

        for _, iconFrame in ipairs(previewIcons) do
            iconFrame:SetSize(iconSize, iconSize)
            iconFrame:Show()
        end
    end

    local function RefreshAndPreview()
        RefreshDragonRiding()
        UpdatePreview()
    end

    UpdatePreview()
    y = y + 140

    previewTargets.general, h = W:SectionHeader(sc, "General", -y); y = y + h
    _, h = W:Toggle(sc, "Enable Module", -y,
        function() return db.enable ~= false end,
        function(v) db.enable = v; Reload() end); y = y + h

    _, h = W:Toggle(sc, "Show Speed Text", -y,
        function() return db.showSpeedText ~= false end,
        function(v) db.showSpeedText = v; RefreshAndPreview() end); y = y + h

    previewTargets.position, h = W:SectionHeader(sc, "Position", -y); y = y + h
    _, h = W:Slider(sc, "X Offset", -y,
        function() return db.xOffset or 0 end,
        function(v) db.xOffset = v; RefreshDragonRiding() end, -1000, 1000, 1); y = y + h
    _, h = W:Slider(sc, "Y Offset", -y,
        function() return db.yOffset or -150 end,
        function(v) db.yOffset = v; RefreshDragonRiding() end, -1000, 1000, 1); y = y + h

    previewTargets.size, h = W:SectionHeader(sc, "Size", -y); y = y + h
    _, h = W:Slider(sc, "Width", -y,
        function() return db.width or 250 end,
        function(v) db.width = v; RefreshAndPreview() end, 120, 800, 1); y = y + h
    _, h = W:Slider(sc, "Height", -y,
        function() return db.height or 16 end,
        function(v) db.height = v; RefreshAndPreview() end, 6, 60, 1); y = y + h

    previewTargets.style, h = W:SectionHeader(sc, "Style", -y); y = y + h
    _, h = W:Dropdown(sc, "Texture", -y, GetStatusbarValues,
        function() return db.texture or "Melli" end,
        function(v) db.texture = v; RefreshAndPreview() end); y = y + h
    _, h = W:Dropdown(sc, "Font", -y, GetFontValues,
        function() return db.font or "AAA_ITC_Avant_Garde" end,
        function(v) db.font = v; RefreshAndPreview() end); y = y + h

    return y
end)
