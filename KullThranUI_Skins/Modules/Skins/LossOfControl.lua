local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local S = KT:GetModule("Skins", true)
if not S then return end

-- Loss of control alert as a flat band: a dark strip that fades out at both
-- sides, thin lines above and below in place of the red glows, the spell
-- icon Blizzard sets cropped inside an accent border, and the effect name in
-- a colour that tells the kind of control (stun, fear, silence...) at once.
-- Blizzard keeps its own layout, timing, animation and text scaling.

local SHARED = [[Interface\AddOns\KullThranUI\Libraries\KUITextures\Shared\]]
local BAND_TEXTURE = SHARED .. "BandFadeSides.tga"
local LINE_TEXTURE = SHARED .. "LineFadeSides.tga"
local FONT = (KT.GetDefaultFontPath and KT:GetDefaultFontPath())
    or KT.DEFAULT_FONT_PATH
    or [[Interface\AddOns\KullThranUI\Libraries\font\AAA_ITC_Avant_Garde.ttf]]

local BAND_WIDTH = 384
local BAND_HEIGHT = 58 -- LossOfControlFrame's own height
local LINE_WIDTH = 290

local issecretvalue = _G.issecretvalue or function() return false end
local band = bit and bit.band

local STUN = { 1.00, 0.23, 0.19 }
local FEAR = { 0.64, 0.40, 1.00 }
local SILENCE = { 0.24, 0.58, 1.00 }
local ROOT = { 0.31, 0.81, 0.37 }
local DISARM = { 1.00, 0.70, 0.12 }

local TYPE_COLORS = {
    STUN = STUN,
    STUN_MECHANIC = STUN,
    FEAR = FEAR,
    FEAR_MECHANIC = FEAR,
    CHARM = FEAR,
    CONFUSE = FEAR,
    POSSESS = FEAR,
    SILENCE = SILENCE,
    PACIFYSILENCE = SILENCE,
    ROOT = ROOT,
    DISARM = DISARM,
    PACIFY = DISARM,
}

-- Magic schools first, so a mixed lockout shows its magic colour.
local SCHOOL_ORDER = { 4, 16, 32, 64, 8, 2, 1 }
local SCHOOL_COLORS = {
    [1] = { 1.00, 0.85, 0.55 },  -- physical
    [2] = { 1.00, 0.90, 0.50 },  -- holy
    [4] = { 1.00, 0.49, 0.10 },  -- fire
    [8] = { 0.30, 1.00, 0.30 },  -- nature
    [16] = { 0.50, 1.00, 1.00 }, -- frost
    [32] = { 0.50, 0.50, 1.00 }, -- shadow
    [64] = { 1.00, 0.50, 1.00 }, -- arcane
}

local function Usable(value)
    return value ~= nil and not issecretvalue(value)
end

local function GetControlColor(data)
    local locType = data and data.locType
    if not Usable(locType) then return STUN end

    if locType == "SCHOOL_INTERRUPT" then
        local school = data.lockoutSchool
        if band and Usable(school) and type(school) == "number" and school ~= 0 then
            for _, mask in ipairs(SCHOOL_ORDER) do
                if band(school, mask) ~= 0 then return SCHOOL_COLORS[mask] end
            end
        end
        return SCHOOL_COLORS[4]
    end
    return TYPE_COLORS[locType] or STUN
end

local function GetActiveData()
    if not (C_LossOfControl and C_LossOfControl.GetActiveLossOfControlData) then return nil end
    local consts = Constants and Constants.LossOfControlConsts
    local index = consts and consts.LOSS_OF_CONTROL_ACTIVE_INDEX or 1
    local ok, data = pcall(C_LossOfControl.GetActiveLossOfControlData, index)
    return ok and type(data) == "table" and data or nil
end

-- One physical pixel in the frame's own units.
local function PixelSize(frame)
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale()
    if factor and scale and scale > 0 then return factor / scale end
    return S.mult or 1
end

local function StyleText(text, size)
    if not text then return end
    text:SetFont(FONT, size, "OUTLINE")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
end

local function UpdateLines(frame)
    local px = PixelSize(frame)
    for _, line in ipairs({ frame.RedLineTop, frame.RedLineBottom }) do
        if line then line:SetSize(LINE_WIDTH, px) end
    end
    -- Only fixed offsets and thicknesses here: Blizzard places the icon from
    -- the text width, which is a secret value in combat, so nothing in this
    -- path may read the border's size (a Backdrop does, and errors).
    local border = frame._ktLocBorder
    if border then
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", frame.Icon, "TOPLEFT", -px, px)
        border:SetPoint("BOTTOMRIGHT", frame.Icon, "BOTTOMRIGHT", px, -px)
        local edges = border.edges
        edges.top:SetHeight(px)
        edges.bottom:SetHeight(px)
        edges.left:SetWidth(px)
        edges.right:SetWidth(px)
    end
end

local function CreateIconBorder(frame)
    local border = CreateFrame("Frame", nil, frame)
    border:SetFrameLevel((frame:GetFrameLevel() or 1) + 2)
    local edges = {}
    local function Edge(key, a1, a2)
        local edge = border:CreateTexture(nil, "OVERLAY")
        edge:SetTexture([[Interface\Buttons\WHITE8x8]])
        edge:SetPoint(a1)
        edge:SetPoint(a2)
        edges[key] = edge
    end
    Edge("top", "TOPLEFT", "TOPRIGHT")
    Edge("bottom", "BOTTOMLEFT", "BOTTOMRIGHT")
    Edge("left", "TOPLEFT", "BOTTOMLEFT")
    Edge("right", "TOPRIGHT", "BOTTOMRIGHT")
    border.edges = edges
    return border
end

local function UpdateColors(frame, data)
    local color = GetControlColor(data)
    local r, g, b = color[1], color[2], color[3]
    for _, line in ipairs({ frame.RedLineTop, frame.RedLineBottom }) do
        if line then line:SetVertexColor(r, g, b, 1) end
    end
    if frame.AbilityName then frame.AbilityName:SetTextColor(r, g, b, 1) end

    local border = frame._ktLocBorder
    if border then
        local accent = S:GetAccentColor()
        for _, edge in pairs(border.edges) do
            edge:SetVertexColor(accent[1], accent[2], accent[3], 1)
        end
    end
end

local function SkinLossOfControl()
    local frame = _G.LossOfControlFrame
    if not frame or frame._ktLocSkinned then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    frame._ktLocSkinned = true

    local bg = frame.blackBg
    if bg then
        bg:SetTexture(BAND_TEXTURE)
        bg:SetTexCoord(0, 1, 0, 1)
        bg:SetVertexColor(0.02, 0.02, 0.02, 0.82)
        bg:SetSize(BAND_WIDTH, BAND_HEIGHT)
    end

    for _, line in ipairs({ frame.RedLineTop, frame.RedLineBottom }) do
        if line then
            line:SetTexture(LINE_TEXTURE)
            line:SetTexCoord(0, 1, 0, 1)
            line:SetBlendMode("BLEND")
        end
    end

    local icon = frame.Icon
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        frame._ktLocBorder = CreateIconBorder(frame)
    end

    StyleText(frame.AbilityName, 22)
    if frame.TimeLeft then
        StyleText(frame.TimeLeft.NumberText, 20)
        StyleText(frame.TimeLeft.SecondsText, 20)
        if frame.TimeLeft.NumberText then frame.TimeLeft.NumberText:SetTextColor(1, 1, 1, 1) end
        if frame.TimeLeft.SecondsText then frame.TimeLeft.SecondsText:SetTextColor(0.85, 0.85, 0.85, 1) end
    end

    UpdateLines(frame)
    UpdateColors(frame, nil)

    -- The intro animation moves and scales the icon texture only; a frame
    -- anchored to it can't follow, so the border waits for it to finish,
    -- the same way Blizzard holds back the cooldown swipe.
    local anim = frame.Anim
    if anim and frame._ktLocBorder then
        hooksecurefunc(anim, "Play", function() frame._ktLocBorder:Hide() end)
        anim:HookScript("OnFinished", function() frame._ktLocBorder:Show() end)
        anim:HookScript("OnStop", function() frame._ktLocBorder:Show() end)
    end

    if frame.SetUpDisplay then
        hooksecurefunc(frame, "SetUpDisplay", function(self, _, data)
            if not S:IsWindowEnabled("lossofcontrol") then return end
            if self.Icon then self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            UpdateLines(self)
            UpdateColors(self, data or GetActiveData())
        end)
    end

    S:RegisterBlizzardAccentRefresh(frame, function(owner)
        UpdateColors(owner, owner:IsShown() and GetActiveData() or nil)
    end)
end

S:RegisterWindow("lossofcontrol", {
    label = "Loss of Control Alert",
    apply = SkinLossOfControl,
})
