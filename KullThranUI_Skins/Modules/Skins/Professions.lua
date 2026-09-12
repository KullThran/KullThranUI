local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local hooksecurefunc = hooksecurefunc
local pairs, ipairs, next = pairs, ipairs, next
local unpack = unpack or table.unpack
local GetProfessionInfo = GetProfessionInfo
local C_SpellBook_GetSpellBookItemInfo = C_SpellBook and C_SpellBook.GetSpellBookItemInfo
local SpellBookSpellBank = Enum and Enum.SpellBookSpellBank
local ProfessionsUpdateButtons
local HandleProfessionSpellButton
local C_Timer = _G.C_Timer
local tostring = tostring
local string_format = string.format

local function SetNativeArtwork(texture, alpha, brightness, desaturation)
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
    if texture.Show then texture:Show() end
end

local function HideDecorObject(object)
    if not object or object._ktDecorHidden then return end

    if object.SetTexture then
        object:SetTexture("")
    end

    object:SetAlpha(0)
    object:Hide()

    -- [TAINT FIX] Midnight 12.x: Never call Hide() inside a Show hook.
    if object.Show then
        hooksecurefunc(object, "Show", function(self)
            self:SetAlpha(0)
        end)
    end

    object._ktDecorHidden = true
end

local function HideProfessionDecorations(frame)
    if not frame then return end

    local frameName = frame.GetName and frame:GetName()
    for _, suffix in ipairs({
        "Border", "Ring", "IconBorder", "IconRing", "IconMask",
        "CircleMask", "Circle", "CircleBackground", "Highlight",
        "PortraitRing", "PortraitRingQuality",
    }) do
        HideDecorObject(frame[suffix] or (frameName and _G[frameName..suffix]))
    end
end

local function HideNamedObjects(prefix, suffixes)
    if not prefix then return end

    for _, suffix in ipairs(suffixes) do
        HideDecorObject(_G[prefix..suffix])
    end
end

local function HideChildrenByName(frame, patterns, ignoreObject)
    if not (frame and frame.GetChildren) then return end

    for _, child in ipairs({frame:GetChildren()}) do
        if child and child ~= ignoreObject and child.GetName then
            local name = child:GetName()
            if name then
                local lowerName = string.lower(name)
                for _, pattern in ipairs(patterns) do
                    if string.find(lowerName, pattern, 1, true) then
                        HideDecorObject(child)
                        break
                    end
                end
            end
        end
    end
end

local function HideRegionsExcept(frame, allowedTexture)
    if not frame or not frame.GetRegions then return end

    for _, region in ipairs({frame:GetRegions()}) do
        if region ~= allowedTexture then
            if region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
                region:Hide()
            elseif region.IsObjectType and region:IsObjectType("MaskTexture") then
                region:Hide()
            end
        end
    end
end

local function ProfDebug(msg)
    if KT and KT.Print then
        KT:Print("|cff88ccff[ktprofdebug]|r " .. msg)
    end
end

local function DumpFrameSummary(frame, label)
    if not frame then
        ProfDebug((label or "frame") .. ": nil")
        return
    end

    local name = frame.GetName and frame:GetName() or tostring(frame)
    local shown = frame.IsShown and frame:IsShown() and "shown" or "hidden"
    local width = frame.GetWidth and math.floor(frame:GetWidth() or 0) or 0
    local height = frame.GetHeight and math.floor(frame:GetHeight() or 0) or 0
    ProfDebug(string_format("%s => %s [%s] %dx%d", label or "frame", name or "?", shown, width, height))

    if frame.GetRegions then
        local count = 0
        for _, region in ipairs({frame:GetRegions()}) do
            if region and region.IsObjectType and (region:IsObjectType("Texture") or region:IsObjectType("MaskTexture")) then
                count = count + 1
                if count <= 12 then
                    local rname = region.GetName and region:GetName() or tostring(region)
                    local rtype = region:IsObjectType("MaskTexture") and "Mask" or "Texture"
                    local alpha = region.GetAlpha and region:GetAlpha() or 0
                    local shownRegion = region.IsShown and region:IsShown() and "shown" or "hidden"
                    local tex = region.GetTexture and region:GetTexture()
                    ProfDebug(string_format("  region %d: %s [%s,%s] alpha=%.2f tex=%s", count, rname or "?", rtype, shownRegion, alpha or 0, tostring(tex)))
                end
            end
        end
    end

    if frame.GetChildren then
        local index = 0
        for _, child in ipairs({frame:GetChildren()}) do
            index = index + 1
            if index <= 12 then
                local cname = child.GetName and child:GetName() or tostring(child)
                local cshown = child.IsShown and child:IsShown() and "shown" or "hidden"
                local ctype = child.GetObjectType and child:GetObjectType() or "?"
                ProfDebug(string_format("  child %d: %s [%s,%s]", index, cname or "?", ctype, cshown))
            end
        end
    end
end

local function DumpProfessionsDebug()
    ProfDebug("===== ProfessionsBook Debug =====")
    DumpFrameSummary(_G.ProfessionsBookFrame, "ProfessionsBookFrame")
    DumpFrameSummary(_G.PrimaryProfession1, "PrimaryProfession1")
    DumpFrameSummary(_G.PrimaryProfession2, "PrimaryProfession2")
    DumpFrameSummary(_G.SecondaryProfession1, "SecondaryProfession1")
    DumpFrameSummary(_G.SecondaryProfession2, "SecondaryProfession2")
    DumpFrameSummary(_G.PrimaryProfession2 and _G.PrimaryProfession2.SpellButton1, "PrimaryProfession2.SpellButton1")
    DumpFrameSummary(_G.PrimaryProfession2 and _G.PrimaryProfession2.SpellButton2, "PrimaryProfession2.SpellButton2")
    DumpFrameSummary(_G.SecondaryProfession1 and _G.SecondaryProfession1.SpellButton1, "SecondaryProfession1.SpellButton1")
    DumpFrameSummary(_G.ProfessionsBookFrameTutorialButton, "ProfessionsBookFrameTutorialButton")
    ProfDebug("===== End ProfessionsBook Debug =====")
end

local function InnerBackdrop(frame)
    if frame and not frame.backdrop then
        S:CreateFlatBackdrop(frame)
    end
    if frame and frame.backdrop then
        S:RegisterBlizzardWindowBackground(frame.backdrop)
    end
end

local function SkinProfessionEntry(prof)
    if not prof then return end
    local profName = prof.GetName and prof:GetName()
    local isSecondary = profName and string.find(profName, "SecondaryProfession", 1, true)

    if not prof._ktProfessionEntryStripped then
        S:StripTextures(prof)
        prof._ktProfessionEntryStripped = true
    end

    HideProfessionDecorations(prof)
    HideRegionsExcept(prof, prof.icon)
    
    if not prof.backdrop then
        prof.backdrop = CreateFrame("Frame", nil, prof, "BackdropTemplate")
        prof.backdrop:SetFrameLevel(prof:GetFrameLevel() - 1 < 1 and 1 or prof:GetFrameLevel() - 1)
        prof.backdrop:SetBackdrop({ bgFile = "Interface\Buttons\WHITE8x8", edgeFile = "Interface\Buttons\WHITE8x8", edgeSize = 1 })
        prof.backdrop:SetBackdropColor(0, 0, 0, 0.6)
        prof.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        prof.backdrop:SetPoint("TOPLEFT", prof, "TOPLEFT", 0, 0)
        prof.backdrop:SetPoint("BOTTOMRIGHT", prof, "BOTTOMRIGHT", 0, 0)
        if prof.icon then
            prof.backdrop:SetPoint("TOPLEFT", prof.icon, "TOPLEFT", -8, 8)
        end
    end
    prof.backdrop:Show()

    HideNamedObjects(prof.GetName and prof:GetName(), {
        "Left", "Middle", "Right",
        "LeftSeparator", "MiddleSeparator", "RightSeparator",
        "Background", "BackgroundLeft", "BackgroundRight",
        "Top", "Bottom", "Header", "HeaderLeft", "HeaderRight",
    })
    HideChildrenByName(prof, {
        "border", "ring", "circle", "portrait", "background", "separator", "frame",
    }, prof.icon and prof.icon:GetParent())

    local missingBg = prof.missingBackground or prof.MissingBackground
    if missingBg then missingBg:Hide() end
    
    local missingHeader = prof.missingHeader or prof.MissingHeader
    if missingHeader then
        S:HandleFont(missingHeader)
        missingHeader:SetTextColor(1, 0.82, 0, 1)
    end
    
    local missingText = prof.missingText or prof.MissingText
    if missingText then
        S:HandleFont(missingText)
        missingText:SetTextColor(1, 1, 1, 1)
    end
    if prof.professionName then
        S:HandleFont(prof.professionName)
        prof.professionName:ClearAllPoints()
        if isSecondary then
            prof.professionName:SetPoint("TOPLEFT", prof, "TOPLEFT", 0, -2)
            prof.professionName:SetWidth(125)
        else
            prof.professionName:SetPoint("TOPLEFT", 100, -4)
        end
        prof.professionName:SetJustifyH("LEFT")
    end

    if prof.statusBar then
        S:StripTextures(prof.statusBar)
        S:HandleStatusBar(prof.statusBar)
        prof.statusBar:SetHeight(14)
        prof.statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        local c = S:GetAccentColor()
        prof.statusBar:SetStatusBarColor(c[1], c[2], c[3], 0.9)
        S:CreateBackdrop(prof.statusBar)

        local a, b, c, _, e = prof.statusBar:GetPoint()
        if a then
            prof.statusBar:ClearAllPoints()
            prof.statusBar:SetPoint(a, b, c, 0, e or 0)
        end

        if prof.statusBar.rankText then
            S:HandleFont(prof.statusBar.rankText)
            prof.statusBar.rankText:ClearAllPoints()
            prof.statusBar.rankText:SetPoint("CENTER")
        end
    end

    local rank = prof.rank or prof.Rank
    local statusBar = prof.statusBar or prof.StatusBar
    local profNameElement = prof.professionName or prof.ProfessionName
    
    if rank and statusBar and profNameElement then
        local anchor = select(1, statusBar:GetPoint())
        rank:ClearAllPoints()
        if isSecondary then
            rank:SetPoint("TOPLEFT", profNameElement, "BOTTOMLEFT", 0, -2)
            rank:SetWidth(125)
        elseif anchor == "BOTTOMLEFT" then
            rank:SetPoint("BOTTOMLEFT", statusBar, "TOPLEFT", 0, 4)
        elseif anchor == "TOPLEFT" then
            rank:SetPoint("TOPLEFT", profNameElement, "BOTTOMLEFT", 0, -20)
        end
        S:HandleFont(rank)
        rank:SetJustifyH("LEFT")
    end

    local unlearn = prof.unlearn or prof.UnlearnButton
    if unlearn then
        unlearn:ClearAllPoints()
        local iconAnchor = prof.icon or prof.Icon or prof.IconTexture
        if iconAnchor then
            unlearn:SetPoint("BOTTOMRIGHT", iconAnchor, "BOTTOMRIGHT", 4, -4)
        else
            unlearn:SetPoint("BOTTOMRIGHT", prof, "BOTTOMRIGHT", -4, 4)
        end
        unlearn:SetSize(16, 16)
        if unlearn.GetRegions then
            for i = 1, select("#", unlearn:GetRegions()) do
                local r = select(i, unlearn:GetRegions())
                if r and r.IsObjectType and r:IsObjectType("Texture") then
                    r:SetTexCoord(0, 1, 0, 1) -- Keep the red slash
                end
            end
        end
    end

    local icon = prof.icon or prof.Icon or prof.IconTexture
    if icon then
        local iconParent = icon.GetParent and icon:GetParent()

        S:HandleIcon(icon, true)
        icon:SetDesaturated(false)
        icon:SetAlpha(1)
        if icon.backdrop then
            S:SetInside(icon, icon.backdrop, 0)
            icon.backdrop:SetBackdropColor(0, 0, 0, 0)
            icon.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end

        if iconParent and iconParent ~= prof then
            HideProfessionDecorations(iconParent)
            HideRegionsExcept(iconParent, icon)
            HideChildrenByName(iconParent, { "border", "ring", "circle", "portrait", "background" }, icon)
        end

        if prof.backdrop then
            prof.backdrop:Hide()
        end
    end

    for i = 1, 2 do
        local button = prof["SpellButton"..i]
        if button then
            HandleProfessionSpellButton(button)
        end
    end

    ProfessionsUpdateButtons(prof)
end

local function FormatProfessionHook(frame, id)
    if frame then
        if frame.missingHeader then frame.missingHeader:SetTextColor(1, 1, 1) end
        if frame.missingText then frame.missingText:SetTextColor(1, 1, 1) end
    end
    if not (id and frame and frame.icon) or not GetProfessionInfo then
        if frame then
            SkinProfessionEntry(frame)
        end
        return
    end

    local _, texture = GetProfessionInfo(id)
    if texture then
        frame.icon:SetTexture(texture)
    end

    SkinProfessionEntry(frame)
end

local function ProfessionButtonUpdate(button)
    if not (button and C_SpellBook_GetSpellBookItemInfo and SpellBookSpellBank and button.GetParent) then return end

    local parent = button:GetParent()
    if not parent or not parent.spellOffset then return end

    local spellIndex = button:GetID() + parent.spellOffset
    local spellBookItemInfo = C_SpellBook_GetSpellBookItemInfo(spellIndex, SpellBookSpellBank.Player)
    local highlight = button.highlightTexture or (button.GetHighlightTexture and button:GetHighlightTexture())

    HideProfessionDecorations(button)
    HideNamedObjects(button.GetName and button:GetName(), {
        "Left", "Middle", "Right",
        "LeftSeparator", "MiddleSeparator", "RightSeparator",
        "Background", "BackgroundLeft", "BackgroundRight",
        "NameFrame", "NormalTexture", "HighlightTexture",
    })
    HideRegionsExcept(button, button.IconTexture or button.icon)

    if highlight then
        if spellBookItemInfo and spellBookItemInfo.isPassive then
            highlight:SetColorTexture(1, 1, 1, 0)
        else
            highlight:SetColorTexture(1, 1, 1, 0.18)
        end
    end
end

ProfessionsUpdateButtons = function(frame)
    if not frame then return end
    ProfessionButtonUpdate(frame.SpellButton1)
    ProfessionButtonUpdate(frame.SpellButton2)
end

local function ProfessionsBookFrameUpdate()
    for _, frame in ipairs({
        _G.PrimaryProfession1,
        _G.PrimaryProfession2,
        _G.SecondaryProfession1,
        _G.SecondaryProfession2,
        _G.SecondaryProfession3,
        _G.SecondaryProfession4,
    }) do
        SkinProfessionEntry(frame)
    end
end

HandleProfessionSpellButton = function(button)
    if not button or button._ktProfessionSpellSkinned then return end

    S:StripTextures(button)
    HideProfessionDecorations(button)
    if button.NameFrame then button.NameFrame:Hide() end
    if button.Border then button.Border:Hide() end
    if button.IconBorder then button.IconBorder:Hide() end
    if button.Ring then button.Ring:Hide() end
    HideNamedObjects(button.GetName and button:GetName(), {
        "Left", "Middle", "Right",
        "LeftSeparator", "MiddleSeparator", "RightSeparator",
        "Background", "BackgroundLeft", "BackgroundRight",
        "NameFrame", "NormalTexture", "HighlightTexture",
    })
    HideChildrenByName(button, { "border", "ring", "background", "separator", "frame" })

    local icon = button.IconTexture or button.icon or button.Icon
    HideRegionsExcept(button, icon)
    if button.Name then button.Name:SetTextColor(1, 1, 1) end
    if button.SubName then button.SubName:SetTextColor(1, 1, 1) end
    if button.SpellName then button.SpellName:SetTextColor(1, 1, 1) end
    if button.SpellSubName then button.SpellSubName:SetTextColor(1, 1, 1) end
    
    if icon then
        local iconParent = icon.GetParent and icon:GetParent()
        S:HandleIcon(icon, true)
        icon:SetDrawLayer("OVERLAY", 7)
        if icon.backdrop then
            S:SetInside(icon, icon.backdrop, 0)
            icon.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
        if iconParent and iconParent ~= button then
            HideProfessionDecorations(iconParent)
            HideRegionsExcept(iconParent, icon)
            HideChildrenByName(iconParent, { "border", "ring", "background", "separator", "frame" }, icon)
        end
    end

    button:SetCheckedTexture("Interface\\Buttons\\WHITE8x8")
    if button.GetCheckedTexture then
        local checked = button:GetCheckedTexture()
        if checked then
            checked:SetColorTexture(1, 1, 1, 0.2)
            if icon and icon.backdrop then
                S:SetInside(checked, icon.backdrop)
            end
        end
    end

    button:SetPushedTexture("Interface\\Buttons\\WHITE8x8")
    if button.GetPushedTexture then
        local pushed = button:GetPushedTexture()
        if pushed then
            pushed:SetColorTexture(1, 1, 1, 0.3)
            if icon and icon.backdrop then
                S:SetInside(pushed, icon.backdrop)
            end
        end
    end

    local highlight = button.highlightTexture or (button.GetHighlightTexture and button:GetHighlightTexture())
    if not highlight then
        highlight = button:CreateTexture(nil, "HIGHLIGHT")
        button:SetHighlightTexture(highlight)
    end
    button.highlightTexture = highlight

    if highlight and icon and icon.backdrop then
        highlight:SetColorTexture(1, 1, 1, 0.14)
        S:SetInside(highlight, icon.backdrop)
    end

    if button.Name then
        S:HandleFont(button.Name)
        button.Name:SetJustifyH("LEFT")
    end
    if button.spellString then
        S:HandleFont(button.spellString)
        if icon and icon.backdrop then
            button.spellString:ClearAllPoints()
            button.spellString:SetPoint("LEFT", icon.backdrop, "RIGHT", 8, 0)
        end
        button.spellString:SetJustifyH("LEFT")
        button.spellString:SetTextColor(1, 0.82, 0, 1)
    end
    if button.subSpellString then
        S:HandleFont(button.subSpellString)
        if button.spellString then
            button.subSpellString:ClearAllPoints()
            button.subSpellString:SetPoint("TOPLEFT", button.spellString, "BOTTOMLEFT", 0, -1)
        end
        button.subSpellString:SetJustifyH("LEFT")
    end

    button._ktProfessionSpellSkinned = true
    ProfessionButtonUpdate(button)
end

-- ========================================================================
-- 1. PROFESSIONS BOOK (Panel de Resumen de Profesiones)
-- ========================================================================
local function WhitenTextIn(frame, depth)
    depth = depth or 0
    if not frame or depth > 9 or frame:IsForbidden() then return end
    if frame.GetRegions then
        for i = 1, select("#", frame:GetRegions()) do
            local r = select(i, frame:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("FontString") and r.SetTextColor then
                r:SetTextColor(1, 1, 1)
            end
        end
    end
    if frame.GetChildren then
        for i = 1, select("#", frame:GetChildren()) do
            WhitenTextIn(select(i, frame:GetChildren()), depth + 1)
        end
    end
end

local function EnsureProfessionsBookBorder(frame)
    if not frame then return end

    if not frame._ktProfessionBookBorder then
        local border = CreateFrame("Frame", nil, frame)
        border:SetAllPoints(frame)
        border:SetFrameLevel(frame:GetFrameLevel() + 15)
        border._ktEdges = {}

        local top = border:CreateTexture(nil, "OVERLAY", nil, 7)
        top:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
        top:SetHeight(1)

        local bottom = border:CreateTexture(nil, "OVERLAY", nil, 7)
        bottom:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(1)

        local left = border:CreateTexture(nil, "OVERLAY", nil, 7)
        left:SetPoint("TOPLEFT", border, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 0, 0)
        left:SetWidth(1)

        local right = border:CreateTexture(nil, "OVERLAY", nil, 7)
        right:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(1)

        border._ktEdges = { top, bottom, left, right }
        frame._ktProfessionBookBorder = border

        S:RegisterBlizzardWindowBorder(border, function(self, enabled, color)
            for _, edge in ipairs(self._ktEdges or {}) do
                edge:SetColorTexture(color[1], color[2], color[3], 1)
                edge:SetAlpha(enabled and 1 or 0)
                edge:Show()
            end
        end)
    end

    local border = frame._ktProfessionBookBorder
    border:SetFrameLevel(frame:GetFrameLevel() + 15)
    border:Show()
    local accent = S:GetAccentColor()
    local enabled = S:AreBlizzardWindowBordersEnabled()
    for _, edge in ipairs(border._ktEdges) do
        edge:SetColorTexture(accent[1], accent[2], accent[3], 1)
        edge:SetAlpha(enabled and 1 or 0)
        edge:Show()
    end
end

local function SkinProfessionsBook()
    if not (S.db.enable and S.db.professions) then return end

    local ProfessionsBookFrame = _G.ProfessionsBookFrame
    if not ProfessionsBookFrame then return end
    if not ProfessionsBookFrame._ktBookSurfaceOnShow then
        ProfessionsBookFrame._ktBookSurfaceOnShow = true
        ProfessionsBookFrame:HookScript("OnShow", SkinProfessionsBook)
    end
    local portrait = ProfessionsBookFrame.Portrait or ProfessionsBookFrame.portrait or _G.ProfessionsBookFramePortrait
    local portraitTexture = portrait and portrait.GetTexture and portrait:GetTexture()

    S:SkinPremiumWindow(ProfessionsBookFrame)
    S:StripTextures(ProfessionsBookFrame)
    WhitenTextIn(ProfessionsBookFrame)

    if S.ApplySatinSurface then
        S:ApplySatinSurface(ProfessionsBookFrame, {
            inset = 10, baseAlpha = 0.18, sheenAlpha = 0.055, edgeAlpha = 0.12,
        })
    end

    for _, bk in ipairs({ "BookBGLeft", "BookBGRight", "BookBGHalved", "bgLeft", "bgRight" }) do
        SetNativeArtwork(ProfessionsBookFrame[bk], 0.10, 0.76, 0.10)
    end
    
    -- Dynamically find and darken any large background textures (the leather book pages) even in subframes
    local function DarkenBackgrounds(frame, depth)
        if not frame or (depth or 0) > 4 then return end
        for i = 1, select("#", frame:GetRegions()) do
            local r = select(i, frame:GetRegions())
            if r and r.IsObjectType and r:IsObjectType("Texture") and not S:IsKuiSurfaceRegion(r) then
                local drawLayer = r:GetDrawLayer()
                if drawLayer == "BACKGROUND" or drawLayer == "BORDER" or drawLayer == "ARTWORK" then
                    local w, h = r:GetWidth(), r:GetHeight()
                    local texPath = r.GetTexture and r:GetTexture() or ""
                    local atlas = r.GetAtlas and r:GetAtlas() or ""
                    local name = (type(texPath) == "string" and texPath:lower() or "") .. (type(atlas) == "string" and atlas:lower() or "")
                    
                    if not string.find(name, "marble") and not string.find(name, "adventuremap") then
                        if (w and w > 150) or (h and h > 150) then
                            SetNativeArtwork(r, 0.10, 0.74, 0.12)
                        end
                    end
                end
            end
        end
        if frame.GetChildren then
            for i = 1, select("#", frame:GetChildren()) do
                local child = select(i, frame:GetChildren())
                -- Skip the profession entry buttons so we don't accidentally fade them out
                local cName = child.GetName and child:GetName() or ""
                if child and not (string.find(cName, "Profession%d+") or string.find(cName, "ProfessionsBookFrameTutorialButton")) then
                    DarkenBackgrounds(child, (depth or 0) + 1)
                end
            end
        end
    end
    
    DarkenBackgrounds(ProfessionsBookFrame)
    if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.ProfessionsFrame then
        local professionsPanel = _G.PlayerSpellsFrame.ProfessionsFrame
        DarkenBackgrounds(professionsPanel)
        S:ApplyKuiSurface(professionsPanel)
        if S.ApplySatinSurface then
            S:ApplySatinSurface(professionsPanel, {
                inset = 2, baseAlpha = 0.12, sheenAlpha = 0.045, edgeAlpha = 0.10,
            })
        end
    end

    local premiumData = S:GetFFD(ProfessionsBookFrame)
    if premiumData.atlasBorderFrame then premiumData.atlasBorderFrame:Hide() end
    S:ApplyKuiSurface(ProfessionsBookFrame)
    if premiumData.topBar then premiumData.topBar:SetAlpha(1) end
    EnsureProfessionsBookBorder(ProfessionsBookFrame)

    if ProfessionsBookFrame.CloseButton then
        S:HandleCloseButton(ProfessionsBookFrame.CloseButton)
    end

    local professions = {
        "PrimaryProfession1",
        "PrimaryProfession2",
        "SecondaryProfession1",
        "SecondaryProfession2",
        "SecondaryProfession3",
        "SecondaryProfession4"
    }

    for _, name in pairs(professions) do
        local prof = _G[name]
        if prof then
            SkinProfessionEntry(prof)
        end
    end

    if _G.FormatProfession and not ProfessionsBookFrame._ktFormatProfessionHooked then
        hooksecurefunc("FormatProfession", FormatProfessionHook)
        ProfessionsBookFrame._ktFormatProfessionHooked = true
    end

    if _G.ProfessionsBookFrame_Update and not ProfessionsBookFrame._ktUpdateHooked then
        hooksecurefunc("ProfessionsBookFrame_Update", ProfessionsBookFrameUpdate)
        ProfessionsBookFrame._ktUpdateHooked = true
    end

    ProfessionsBookFrameUpdate()
end

local function TrySkinProfessionsBook()
    if _G.ProfessionsBookFrame then
        SkinProfessionsBook()
    end
end

local function HookProfessionsBookOpen()
    -- Load-on-demand functions/frames may not exist on the first pass. Track
    -- each hook separately, not a single flag that prevents all later hooks.
    S._ktProfessionOpenHooks = S._ktProfessionOpenHooks or {}
    local hooked = S._ktProfessionOpenHooks

    if EventRegistry and not hooked.showEvent then
        EventRegistry:RegisterCallback("ProfessionsBookFrame.Show", TrySkinProfessionsBook, S)
        hooked.showEvent = true
    end

    if _G.ToggleSpellBook and not hooked.spellBook then
        hooked.spellBook = true
        hooksecurefunc("ToggleSpellBook", function(bookType)
            if bookType == BOOKTYPE_PROFESSION or bookType == "professions" or bookType == "spell" or bookType == nil then
                if C_Timer then C_Timer.After(0.1, TrySkinProfessionsBook) else TrySkinProfessionsBook() end
            end
        end)
    end
    
    if _G.TogglePlayerSpellsFrame and not hooked.playerSpells then
        hooked.playerSpells = true
        hooksecurefunc("TogglePlayerSpellsFrame", function()
            if C_Timer then C_Timer.After(0.1, TrySkinProfessionsBook) else TrySkinProfessionsBook() end
        end)
    end

    if _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TabSystem
        and not _G.PlayerSpellsFrame.TabSystem._ktProfessionOpenHook then
        _G.PlayerSpellsFrame.TabSystem._ktProfessionOpenHook = true
        hooksecurefunc(_G.PlayerSpellsFrame.TabSystem, "SetTab", function()
            if C_Timer then C_Timer.After(0.1, TrySkinProfessionsBook) else TrySkinProfessionsBook() end
        end)
    end

    if _G.FormatProfession and not hooked.format then
        hooked.format = true
        hooksecurefunc("FormatProfession", function()
            TrySkinProfessionsBook()
        end)
    end

end

local function RegisterProfessionsDebugSlash()
    if _G.SLASH_KTPROFDEBUG1 then return end

    _G.SLASH_KTPROFDEBUG1 = "/ktprofdebug"
    _G.SlashCmdList.KTPROFDEBUG = function()
        TrySkinProfessionsBook()
        DumpProfessionsDebug()
    end
end

-- ========================================================================
-- 2. CUSTOMER ORDERS & CRAFTING
-- ========================================================================
local function SkinCustomerOrders()
    if not (S.db.enable and S.db.professions) then return end
    
    local frame = _G.ProfessionsCustomerOrdersFrame
    if not frame then return end

    S:HandlePortraitFrame(frame)
    if S.ApplySatinSurface then
        S:ApplySatinSurface(frame, {
            inset = 10, baseAlpha = 0.16, sheenAlpha = 0.05, edgeAlpha = 0.11,
        })
    end

    if frame.MoneyFrameBorder then S:StripTextures(frame.MoneyFrameBorder) end
    if frame.MoneyFrameInset then S:StripTextures(frame.MoneyFrameInset) end

    local browseOrders = frame.BrowseOrders
    if browseOrders then
        S:StripTextures(browseOrders.CategoryList)
        InnerBackdrop(browseOrders.CategoryList)

        if browseOrders.CategoryList.ScrollBar then S:HandleScrollBar(browseOrders.CategoryList.ScrollBar) end

        local search = browseOrders.SearchBar
        if search then
            if search.FavoritesSearchButton then S:HandleButton(search.FavoritesSearchButton) end
            if search.SearchBox then S:HandleEditBox(search.SearchBox) end
            if search.SearchButton then S:HandleButton(search.SearchButton) end

            local filter = search.FilterDropdown
            if filter then
                if filter.ResetButton then S:HandleCloseButton(filter.ResetButton) end
                S:HandleButton(filter)
            end
        end

        local recipeList = browseOrders.RecipeList
        if recipeList then
            S:StripTextures(recipeList)
            InnerBackdrop(recipeList)
            if recipeList.ScrollBar then S:HandleScrollBar(recipeList.ScrollBar) end
            if recipeList.BackgroundNineSlice then recipeList.BackgroundNineSlice:Hide() end
        end
    end

    local form = frame.Form
    if form then
        if form.BackButton then S:HandleButton(form.BackButton) end
        if form.TrackRecipeCheckbox and form.TrackRecipeCheckbox.Checkbox then S:HandleCheckBox(form.TrackRecipeCheckbox.Checkbox) end
        if form.AllocateBestQualityCheckbox then S:HandleCheckBox(form.AllocateBestQualityCheckbox) end

        if form.RecipeHeader then form.RecipeHeader:Hide() end

        if form.LeftPanelBackground then S:StripTextures(form.LeftPanelBackground) end
        if form.RightPanelBackground then S:StripTextures(form.RightPanelBackground) end

        local itemButton = form.OutputIcon
        if itemButton then
            if itemButton.CircleMask then itemButton.CircleMask:Hide() end
            if itemButton.Icon then S:HandleIcon(itemButton.Icon, true) end
            if itemButton.IconBorder then itemButton.IconBorder:SetAlpha(0) end
            if itemButton.GetHighlightTexture then itemButton:GetHighlightTexture():Hide() end
        end

        if form.OrderRecipientTarget then S:HandleEditBox(form.OrderRecipientTarget) end

        local payment = form.PaymentContainer
        if payment then
            if payment.NoteEditBox then
                S:StripTextures(payment.NoteEditBox)
                InnerBackdrop(payment.NoteEditBox)
            end
            if payment.CancelOrderButton then S:HandleButton(payment.CancelOrderButton) end
            if payment.TipMoneyInputFrame then
                if payment.TipMoneyInputFrame.GoldBox then S:HandleEditBox(payment.TipMoneyInputFrame.GoldBox) end
                if payment.TipMoneyInputFrame.SilverBox then S:HandleEditBox(payment.TipMoneyInputFrame.SilverBox) end
            end
            if payment.DurationDropdown then S:HandleDropDownBox(payment.DurationDropdown) end
            if payment.ListOrderButton then S:HandleButton(payment.ListOrderButton) end
        end

        if form.MinimumQuality and form.MinimumQuality.Dropdown then S:HandleDropDownBox(form.MinimumQuality.Dropdown) end
        if form.OrderRecipientDropdown then S:HandleDropDownBox(form.OrderRecipientDropdown) end
    end
end

local function SkinProfessions()
    if not (S.db.enable and S.db.professions) then return end

    local ProfessionsFrame = _G.ProfessionsFrame
    if not ProfessionsFrame then return end

    S:HandlePortraitFrame(ProfessionsFrame)
    if S.ApplySatinSurface then
        S:ApplySatinSurface(ProfessionsFrame, {
            inset = 10, baseAlpha = 0.17, sheenAlpha = 0.055, edgeAlpha = 0.12,
        })
    end

    for i = 1, 20 do
        local tab = _G["ProfessionsFrameTab"..i]
        if tab then S:HandleTab(tab) end
    end

    local CraftingPage = ProfessionsFrame.CraftingPage
    if CraftingPage then
        S:ApplyKuiSurface(CraftingPage)
        if CraftingPage.TutorialButton then S:Kill(CraftingPage.TutorialButton) end
        SetNativeArtwork(CraftingPage.Background, 0.36, 0.74, 0.12)
        if S.ApplySatinSurface then
            S:ApplySatinSurface(CraftingPage, {
                inset = 2, baseAlpha = 0.11, sheenAlpha = 0.04, edgeAlpha = 0.09,
            })
        end

        local RecipeList = CraftingPage.RecipeList
        if RecipeList then
            S:StripTextures(RecipeList)
            InnerBackdrop(RecipeList)

            if RecipeList.SearchBox then 
                S:HandleEditBox(RecipeList.SearchBox) 
            end
            if RecipeList.FilterButton then S:HandleButton(RecipeList.FilterButton) end
            if RecipeList.ScrollBar then S:HandleScrollBar(RecipeList.ScrollBar) end
            if RecipeList.BackgroundNineSlice then RecipeList.BackgroundNineSlice:Hide() end
        end

        local SchematicForm = CraftingPage.SchematicForm
        if SchematicForm then
            S:StripTextures(SchematicForm)
            InnerBackdrop(SchematicForm)

            SetNativeArtwork(SchematicForm.Background, 0.28, 0.72, 0.14)
            if SchematicForm.NineSlice then SchematicForm.NineSlice:Hide() end
            if S.ApplySatinSurface then
                S:ApplySatinSurface(SchematicForm, {
                    inset = 2, baseAlpha = 0.10, sheenAlpha = 0.035, edgeAlpha = 0.08,
                })
            end
            
            if SchematicForm.TrackRecipeCheckBox then S:HandleCheckBox(SchematicForm.TrackRecipeCheckBox) end
            if SchematicForm.AllocateBestQualityCheckBox then S:HandleCheckBox(SchematicForm.AllocateBestQualityCheckBox) end
            
            if SchematicForm.OutputIcon then
                S:HandleIcon(SchematicForm.OutputIcon.Icon, true)
                if SchematicForm.OutputIcon.IconBorder then SchematicForm.OutputIcon.IconBorder:SetAlpha(0) end
                if SchematicForm.OutputIcon.CircleMask then SchematicForm.OutputIcon.CircleMask:Hide() end
            end

            if SchematicForm.QualityBar then
                S:StripTextures(SchematicForm.QualityBar)
                S:HandleStatusBar(SchematicForm.QualityBar)
            end
            
            hooksecurefunc(SchematicForm, "Init", function(self)
                if self.reagentSlotPool then
                    for slot in self.reagentSlotPool:EnumerateActive() do
                        if not slot.isSkinned then
                            if slot.Button then
                                S:HandleIcon(slot.Button.Icon, true)
                                slot.Button:SetNormalTexture("")
                                slot.Button:SetPushedTexture("")
                                if slot.Button.IconBorder then slot.Button.IconBorder:SetAlpha(0) end
                                if slot.Button.SlotBackground then slot.Button.SlotBackground:Hide() end
                            end
                            slot.isSkinned = true
                        end
                    end
                end
            end)
        end
        
        if CraftingPage.CreateButton then S:HandleButton(CraftingPage.CreateButton) end
        if CraftingPage.CreateAllButton then S:HandleButton(CraftingPage.CreateAllButton) end
        if CraftingPage.ViewGuildCraftersButton then S:HandleButton(CraftingPage.ViewGuildCraftersButton) end
        if CraftingPage.LinkButton then S:HandleButton(CraftingPage.LinkButton) end
        
        if CraftingPage.RankBar then
            S:StripTextures(CraftingPage.RankBar)
            S:HandleStatusBar(CraftingPage.RankBar)
            CraftingPage.RankBar:SetHeight(14)
            if CraftingPage.RankBar.Border then CraftingPage.RankBar.Border:Hide() end
            if CraftingPage.RankBar.Background then CraftingPage.RankBar.Background:Hide() end
        end
    end

    local SpecPage = ProfessionsFrame.SpecPage
    if SpecPage then
        if SpecPage.ApplyButton then S:HandleButton(SpecPage.ApplyButton) end
        if SpecPage.UnlockButton then S:HandleButton(SpecPage.UnlockButton) end
        if SpecPage.BackToPreviewButton then S:HandleButton(SpecPage.BackToPreviewButton) end
        
        local DetailedView = SpecPage.DetailedView
        if DetailedView then
            S:StripTextures(DetailedView)
            InnerBackdrop(DetailedView)

            if DetailedView.UnlockPathButton then S:HandleButton(DetailedView.UnlockPathButton) end
            if DetailedView.SpendCurrencyButton then S:HandleButton(DetailedView.SpendCurrencyButton) end
            if DetailedView.Border then DetailedView.Border:Hide() end
            SetNativeArtwork(DetailedView.Background, 0.28, 0.72, 0.14)
            if S.ApplySatinSurface then
                S:ApplySatinSurface(DetailedView, {
                    inset = 2, baseAlpha = 0.10, sheenAlpha = 0.035, edgeAlpha = 0.08,
                })
            end
        end
        
        if SpecPage.TreeView then 
            S:StripTextures(SpecPage.TreeView)
            InnerBackdrop(SpecPage.TreeView)
            SetNativeArtwork(SpecPage.TreeView.Background, 0.30, 0.74, 0.12)
            if S.ApplySatinSurface then
                S:ApplySatinSurface(SpecPage.TreeView, {
                    inset = 2, baseAlpha = 0.10, sheenAlpha = 0.035, edgeAlpha = 0.08,
                })
            end
        end
    end
end

-- ============================================================================
-- REGISTRO
-- ============================================================================
S.SkinFuncs["Blizzard_Professions"] = function()
    HookProfessionsBookOpen()
    SkinProfessions()
    SkinProfessionsBook()
end

S.SkinFuncs["Blizzard_ProfessionsBook"] = function()
    HookProfessionsBookOpen()
    SkinProfessionsBook()
end

S.SkinFuncs["Blizzard_SpellBook"] = function()
    HookProfessionsBookOpen()
    SkinProfessionsBook()
end

local old_player_spells = S.SkinFuncs["Blizzard_PlayerSpells"]
S.SkinFuncs["Blizzard_PlayerSpells"] = function()
    if old_player_spells then old_player_spells() end
    HookProfessionsBookOpen()
    SkinProfessionsBook()
end

S.SkinFuncs["Blizzard_ProfessionsCustomerOrders"] = SkinCustomerOrders

hooksecurefunc(S, "OnEnable", function()
    RegisterProfessionsDebugSlash()
    HookProfessionsBookOpen()
    TrySkinProfessionsBook()
    if _G.ProfessionsFrame then
        SkinProfessions()
    end
    if _G.ProfessionsCustomerOrdersFrame then
        SkinCustomerOrders()
    end
end)
