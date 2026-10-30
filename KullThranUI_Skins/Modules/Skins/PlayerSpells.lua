local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc
local pairs = pairs

local function SetNativeArtwork(texture, alpha, brightness, desaturation, preserveVisibility)
    if not texture or S:IsKuiSurfaceRegion(texture) then return end
    if texture.SetDesaturation then
        pcall(texture.SetDesaturation, texture, desaturation or 0)
    elseif texture.SetDesaturated then
        pcall(texture.SetDesaturated, texture, (desaturation or 0) >= 0.5)
    end
    if texture.SetVertexColor then
        texture:SetVertexColor(brightness or 1, brightness or 1, brightness or 1, 1)
    end
    if texture.SetAlpha then texture:SetAlpha(alpha or 1) end
    if not preserveVisibility and texture.Show then texture:Show() end
end

local function ApplyNativeSpellBook(spellBook)
    if not spellBook or spellBook:IsForbidden() then return end
    -- Keep Blizzard's opaque book pages, darkened by 55%, instead of putting
    -- a KUI surface over them. Blizzard owns which full/half-page art is shown.
    for _, key in ipairs({
        "BookBGLeft", "BookBGRight", "BookBGHalved",
        "TopBar", "BookCornerFlipbook", "Bookmark",
    }) do
        SetNativeArtwork(spellBook[key], 1, 0.45, 0, true)
    end
end

local function ApplyPlayerSpellsSatin(frame)
    if not frame then return end
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
        data.nativeSpellBookHooked = true
    end
end

local function FadeSpellItem(item)
    if not item or item:IsForbidden() then return end
    if item.Backplate and item.Backplate.SetAlpha then item.Backplate:SetAlpha(0) end
    local b = item.Button
    if b then
        if b.Border and b.Border.SetAlpha then
            b.Border:SetAlpha(0.5)
            if b.Border.SetDesaturation then b.Border:SetDesaturation(0.5) end
        end
        if b.BorderSheen and b.BorderSheen.SetAlpha then b.BorderSheen:SetAlpha(0) end
        if b.IconHighlight and b.IconHighlight.SetAlpha then b.IconHighlight:SetAlpha(0) end
    end
    if item.Name and item.Name.SetTextColor then item.Name:SetTextColor(1, 1, 1) end
    if item.SubName and item.SubName.SetTextColor then item.SubName:SetTextColor(1, 1, 1) end
end

local _spellItemHook = false
local function HookSpellBookItems()
    if SpellBookItemMixin and not _spellItemHook then
        _spellItemHook = true
        if SpellBookItemMixin.UpdateVisuals then
            hooksecurefunc(SpellBookItemMixin, "UpdateVisuals", FadeSpellItem)
        end
        if SpellBookItemMixin.OnIconEnter then
            hooksecurefunc(SpellBookItemMixin, "OnIconEnter", FadeSpellItem)
        end
        if SpellBookItemMixin.OnIconLeave then
            hooksecurefunc(SpellBookItemMixin, "OnIconLeave", FadeSpellItem)
        end
    end
end

local function SkinPlayerSpells()
    if not (S.db.enable and S.db.spellbook ~= false) then return end
    
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

local old_hook = S.SkinFuncs["Blizzard_PlayerSpells"]
S.SkinFuncs["Blizzard_PlayerSpells"] = function()
    if old_hook then old_hook() end
    SkinPlayerSpells()
end
