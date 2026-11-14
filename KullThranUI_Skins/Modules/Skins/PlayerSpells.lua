local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc
local pairs = pairs

local function SetNativeArtwork(texture, alpha, brightness, desaturation, preserveVisibility)
    -- One Skins darkening (S:ToneNativeArt); a brighter opaque state keeps the
    -- accent step and alpha 0 still hides the art.
    if not texture or S:IsKuiSurfaceRegion(texture) then return end
    if (alpha or 1) <= 0 then
        if texture.SetAlpha then texture:SetAlpha(0) end
        return
    end
    S:ToneNativeArt(texture, (alpha or 1) >= 1 and (brightness or 1) >= 0.6, preserveVisibility)
end

-- Section headers and the page counter use Blizzard's dark ink, made for the
-- light page. The plate behind a header would read as a smudge on the dark one.
local function StyleSpellBookPage(spellBook)
    local paged = spellBook.PagedSpellsFrame
    if not paged then return end
    if paged.EnumerateFrames then
        for _, frame in paged:EnumerateFrames() do
            if frame.Text and frame.Border and frame.Backplate then
                frame.Backplate:SetAlpha(0)
                frame.Text:SetTextColor(1, 0.82, 0.18)
            end
        end
    end
    local pageText = paged.PagingControls and paged.PagingControls.PageText
    if pageText then pageText:SetTextColor(0.86, 0.86, 0.86) end
end

local function ApplyNativeSpellBook(spellBook)
    if not spellBook or spellBook:IsForbidden() then return end
    -- Keep Blizzard's opaque book pages, darkened, instead of putting a KUI
    -- surface over them. Blizzard owns which full/half-page art is shown.
    for _, key in ipairs({
        "BookBGLeft", "BookBGRight", "BookBGHalved",
        "TopBar", "BookCornerFlipbook",
    }) do
        S:ShadeBookPage(spellBook[key])
    end
    S:ShadeBookPage(spellBook.Bookmark, 0.40)
    StyleSpellBookPage(spellBook)
end

local function ApplyPlayerSpellsSatin(frame)
    if not frame then return end
    -- The book pages sit above the shell's border frame and cover its left side.
    local border = S:GetFFD(frame).atlasBorderFrame
    if border then border:SetFrameLevel(frame:GetFrameLevel() + 100) end
    if S.ApplySatinSurface then
        S:ApplySatinSurface(frame, { inset = 10, baseAlpha = 0.18, sheenAlpha = 0.055, edgeAlpha = 0.12 })
    end

    for _, panel in ipairs({ frame.SpecFrame, frame.TalentsFrame }) do
        if panel then
            if S.ApplySatinSurface then
                S:ApplySatinSurface(panel, { inset = 2, baseAlpha = 0.13, sheenAlpha = 0.045, edgeAlpha = 0.10 })
            end
            if panel._ktContentShade then panel._ktContentShade:SetAlpha(0.20) end
        end
    end

    local spellBook = frame.SpellBookFrame
    if not spellBook then return end
    ApplyNativeSpellBook(spellBook)
    local data = S:GetFFD(spellBook)
    if not data.nativeSpellBookHooked then
        spellBook:HookScript("OnShow", ApplyNativeSpellBook)
        local paged = spellBook.PagedSpellsFrame
        if paged and paged.RegisterCallback and PagedContentFrameBaseMixin then
            paged:RegisterCallback(PagedContentFrameBaseMixin.Event.OnUpdate, function()
                StyleSpellBookPage(spellBook)
            end, S)
        end
        data.nativeSpellBookHooked = true
    end
end

-- Spellbook entries: flat look. The plate behind each entry and the icon's
-- sheen/highlight are hidden and the icon border loses some colour. The name is
-- white and the lines under it a lighter grey than the page's dark ink.
local function SetRegionAlpha(region, alpha)
    if region and region.SetAlpha then region:SetAlpha(alpha) end
end

local function FadeSpellItem(item)
    if not item or item:IsForbidden() then return end
    SetRegionAlpha(item.Backplate, 0)
    local icon = item.Button
    if icon then
        SetRegionAlpha(icon.BorderSheen, 0)
        SetRegionAlpha(icon.IconHighlight, 0)
        local border = icon.Border
        SetRegionAlpha(border, 0.8)
        if border and border.SetAlpha and border.SetDesaturation then border:SetDesaturation(0.5) end
    end
    if item.Name then item.Name:SetTextColor(1, 1, 1) end
    for _, field in ipairs({ "SubName", "RequiredLevel" }) do
        local label = item[field]
        if label and label.SetTextColor then label:SetTextColor(0.80, 0.80, 0.80) end
    end
end

-- Blizzard redraws an entry on refresh and on icon hover; re-fade after each.
local SPELL_ITEM_REDRAWS = { "UpdateVisuals", "OnIconEnter", "OnIconLeave" }
local _spellItemHook = false
local function HookSpellBookItems()
    local mixin = SpellBookItemMixin
    if not mixin or _spellItemHook then return end
    _spellItemHook = true
    for _, method in ipairs(SPELL_ITEM_REDRAWS) do
        if mixin[method] then hooksecurefunc(mixin, method, FadeSpellItem) end
    end
end

local function SkinPlayerSpells()
    if not S:IsWindowEnabled("spellbook") then return end
    
    local PlayerSpellsFrame = _G.PlayerSpellsFrame
    if not PlayerSpellsFrame then return end

    S:SkinPremiumWindow(PlayerSpellsFrame)
    
    if PlayerSpellsFrame.CloseButton then
        S:HandleCloseButton(PlayerSpellsFrame.CloseButton)
    end
    
    if PlayerSpellsFrame.SpecFrame then
        S:ContentShade(PlayerSpellsFrame.SpecFrame)
    end
    if PlayerSpellsFrame.TalentsFrame then
        S:ContentShade(PlayerSpellsFrame.TalentsFrame)
    end
    
    if PlayerSpellsFrame.SpecFrame then
        local sf = PlayerSpellsFrame.SpecFrame
        if sf.BlackBG and sf.BlackBG.SetAlpha then sf.BlackBG:SetAlpha(0) end
        if sf.Background and sf.Background.SetVertexColor then 
            SetNativeArtwork(sf.Background, 0.48, 0.76, 0.10)
        end
    end

    ApplyPlayerSpellsSatin(PlayerSpellsFrame)
    if not PlayerSpellsFrame._ktSatinArtworkHooked then
        PlayerSpellsFrame:HookScript("OnShow", function(self)
            ApplyPlayerSpellsSatin(self)
        end)
        PlayerSpellsFrame._ktSatinArtworkHooked = true
    end

    if S.ApplyKuiSurface then
        S:ApplyKuiSurface(PlayerSpellsFrame)
    end

    if PlayerSpellsFrame.TabSystem and PlayerSpellsFrame.TabSystem.tabs then
        for _, tab in pairs(PlayerSpellsFrame.TabSystem.tabs) do
            S:HandleTab(tab)
        end
    end

    for i = 1, 10 do
        local tab = _G["PlayerSpellsFrameTab" .. i]
        if tab then S:HandleTab(tab) end
    end
    HookSpellBookItems()
end

S:RegisterWindow("spellbook", { addon = "Blizzard_PlayerSpells", name = "PlayerSpells", label = "Spellbook & Talents", apply = SkinPlayerSpells })
