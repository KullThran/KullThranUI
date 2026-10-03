-------------------------------------------------------------------------------
--  Blizzard-style "tube" look for the Player/Target health and power bars in the
--  Forever and Retail visual styles: lighter band toward the top, darker lower
--  edge and thin dark rim, drawn as overlays so the fill colour/texture chosen
--  by the user is untouched. Hidden in every other style.
-------------------------------------------------------------------------------
local _, ns = ...
local KT = _G.KullThranUI
local WHITE = "Interface\\Buttons\\WHITE8x8"

local BG = {}
ns.BarGloss = BG

local function Theme()
    local VT = KT and KT.VisualThemes
    return VT and VT.GetRenderedTheme and VT:GetRenderedTheme() or nil
end

local CLEAR = nil
local function Color(a) return CreateColor(0, 0, 0, a) end

-- Inner bevel of the stock bars: the original fill art has this shading baked
-- in, and our fills are a flat colour, so it is drawn on top. Black fading in
-- from the top (deepest), the bottom and both ends; the strips follow the
-- stock rounded bar mask (bar._ktForeverMask) when it exists.
local function Ensure(bar)
    local sh = bar._kuiShade
    if not sh then
        sh = {}
        bar._kuiShade = sh
        for i = 1, 4 do
            local tex = bar:CreateTexture(nil, "OVERLAY", nil, -3)
            tex:SetTexture(WHITE)
            if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
            if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
            sh[i] = tex
        end
        if sh[1].SetGradient and CreateColor then
            -- VERTICAL runs bottom -> top, HORIZONTAL left -> right.
            sh[1]:SetGradient("VERTICAL", Color(0), Color(0.55))
            sh[2]:SetGradient("VERTICAL", Color(0.30), Color(0))
            sh[3]:SetGradient("HORIZONTAL", Color(0.35), Color(0))
            sh[4]:SetGradient("HORIZONTAL", Color(0), Color(0.35))
        else
            for i = 1, 4 do sh[i]:SetVertexColor(0, 0, 0, 0.25) end
        end
    end
    local mask = bar._ktForeverMask
    if sh._mask ~= mask then
        for i = 1, 4 do
            if sh._mask then pcall(sh[i].RemoveMaskTexture, sh[i], sh._mask) end
            if mask then pcall(sh[i].AddMaskTexture, sh[i], mask) end
        end
        sh._mask = mask
    end
    local h = bar:GetHeight() or 12
    local top, bottom, ends = math.max(2, math.floor(h * 0.2)), math.max(1, math.floor(h * 0.1)), math.max(2, math.floor(h * 0.15))
    sh[1]:ClearAllPoints(); sh[1]:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0); sh[1]:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0); sh[1]:SetHeight(top)
    sh[2]:ClearAllPoints(); sh[2]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0); sh[2]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0); sh[2]:SetHeight(bottom)
    sh[3]:ClearAllPoints(); sh[3]:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0); sh[3]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0); sh[3]:SetWidth(ends)
    sh[4]:ClearAllPoints(); sh[4]:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0); sh[4]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0); sh[4]:SetWidth(ends)
    return sh
end

local function SetShown(sh, shown)
    for i = 1, 4 do sh[i]:SetShown(shown) end
end

-- True for the Classic/Forever/Retail looks; false for KUI Style.
function BG.IsStyledLook()
    local th = Theme()
    return th == "classic" or th == "forever" or th == "retail"
end

function BG.IsBlizzardStyle()
    local th = Theme()
    return th == "forever" or th == "retail"
end

function BG:Update()
    local th = Theme()
    local on = (th == "forever" or th == "retail")
    for _, unit in ipairs({ "player", "target" }) do
        local frame = ns.frames and ns.frames[unit]
        if frame then
            for _, key in ipairs({ "Health", "Power" }) do
                local bar = frame[key]
                if bar and bar.GetFrameLevel then
                    if on and not bar._kuiAtlasFill then SetShown(Ensure(bar), true) elseif bar._kuiShade then SetShown(bar._kuiShade, false) end
                end
            end
        end
    end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_DISPLAYPOWER" }) do
    ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function() BG:Update() end)
if C_Timer and C_Timer.After then
    C_Timer.After(2, function() BG:Update() end)
    C_Timer.After(5, function() BG:Update() end) -- masks may be seated late
end
