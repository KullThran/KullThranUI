-------------------------------------------------------------------------------
--  Bar-frame art for Rare/Elite portraits (Forever / Retail visual styles).
--  The stock unit-frame atlas draws the portrait ring AND the frame/background
--  that surrounds the health and power bars. When a Rare/Elite portrait border
--  replaces the ring, KUIUnitFrames hides the whole atlas, which also removed the
--  frame around the bars. This keeps a copy of that atlas clipped to the bar
--  area only (right of the portrait for Player, left of it for Target), so the
--  bars keep their Blizzard frame while the Rare/Elite border owns the portrait.
-------------------------------------------------------------------------------
local _, ns = ...
local KT = _G.KullThranUI

local BA = {}
ns.BarFrameArt = BA

local PORTRAIT_EDGE = 86   -- layout units (232x100 box): bars start at x=85; the ring tail sits just left of it

local function UsesForeverArt()
    local VT = KT and KT.VisualThemes
    local th = VT and VT.GetRenderedTheme and VT:GetRenderedTheme()
    return th == "forever" or th == "retail"
end

local function Hide(frame)
    local clip = frame._ktBarFrameClip
    if clip then clip:Hide() end
end

function BA.Update(frame, unit)
    if not frame then return end
    local src = frame._ktForeverPortraitArt
    local host = frame._ktForeverArtHost
    if not (UsesForeverArt() and (unit == "player" or unit == "target") and src and host) or src:IsShown() then
        Hide(frame)
        return
    end
    local clip = frame._ktBarFrameClip
    if not clip then
        clip = CreateFrame("Frame", nil, frame)
        clip:SetClipsChildren(true)
        clip:EnableMouse(false)
        clip.tex = clip:CreateTexture(nil, "BACKGROUND")
        frame._ktBarFrameClip = clip
    end
    local ok = pcall(function()
        clip:SetFrameStrata(host:GetFrameStrata())
        clip:SetFrameLevel(host:GetFrameLevel())
        local w = frame:GetWidth() or 0
        if w <= 0 then error("nowidth") end
        local k = w / 232
        clip:ClearAllPoints()
        if unit == "player" then
            clip:SetPoint("TOPLEFT", frame, "TOPLEFT", PORTRAIT_EDGE * k, 0)
            clip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        else
            clip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PORTRAIT_EDGE * k, 0)
        end
        local dst = clip.tex
        -- ApplyForeverUnitFrameArt paints `art` either with SetAtlas or, when the atlas
        -- info has sheet coordinates (Retail override / mirrored target), with
        -- SetTexture(file) + SetTexCoord: copy whichever one was used.
        local atlas = src.GetAtlas and src:GetAtlas()
        if atlas then
            dst:SetAtlas(atlas, false)
            dst:SetTexCoord(src:GetTexCoord())
        else
            local file = src:GetTexture()
            if not file then error("notexture") end
            dst:SetTexture(file)
            dst:SetTexCoord(src:GetTexCoord())
        end
        dst:ClearAllPoints()
        local n = src:GetNumPoints()
        if n == 0 then error("nopoints") end
        for i = 1, n do
            local pt, rel, relPt, x, y = src:GetPoint(i)
            dst:SetPoint(pt, rel, relPt, x or 0, y or 0)
        end
        if n < 2 then
            local sw, sh = src:GetSize()
            if type(sw) ~= "number" or type(sh) ~= "number" or sw <= 0 or sh <= 0 then error("nosize") end
            dst:SetSize(sw, sh)
        end
        -- Carry over the Forever emulation tint (ThemeClientAssets.lua) so the
        -- clipped copy matches the ring it was cut from.
        if dst.SetDesaturated and src.IsDesaturated then dst:SetDesaturated(src:IsDesaturated()) end
        dst:SetVertexColor(src:GetVertexColor())
    end)
    clip:SetShown(ok)
end
