local _, ns = ...

local MEDIA = "Interface\\AddOns\\KullThranUI_UnitFrames\\Modules\\KUIUnitFrames\\Media\\"
local BAND_TEXTURE = MEDIA .. "bevel_band.png"
local END_TEXTURE = MEDIA .. "bevel_end.png"

local UNITS = { "player", "target" }
local BAR_KEYS = { "Health", "Power" }

local BarGloss = {}
ns.BarGloss = BarGloss

local function RenderedTheme()
    local KT = _G.KullThranUI
    local themes = KT and KT.VisualThemes
    if themes and themes.GetRenderedTheme then
        return themes:GetRenderedTheme()
    end
    return nil
end

local function IsBlizzardTheme(theme)
    return theme == "forever" or theme == "retail"
end

function BarGloss.IsBlizzardStyle()
    return IsBlizzardTheme(RenderedTheme())
end

function BarGloss.IsStyledLook()
    local theme = RenderedTheme()
    return theme == "classic" or IsBlizzardTheme(theme)
end

local function BarQualifies(theme, frame, bar)
    if not IsBlizzardTheme(theme) then
        return false
    end
    local selection = frame._ktStockArtSelection
    if type(selection) == "table" and selection.source == "packaged-forever" then
        return false
    end
    return not bar._kuiAtlasFill and not bar._kuiAtlasTint
end

local function CreateBevelTexture(bar, path)
    local texture = bar:CreateTexture(nil, "OVERLAY", nil, -3)
    texture:SetTexture(path)
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
    end
    if texture.SetTexelSnappingBias then
        texture:SetTexelSnappingBias(0)
    end
    return texture
end

local function EnsureBevel(bar)
    local bevel = bar._kuiBevel
    if not bevel then
        bevel = {
            band = CreateBevelTexture(bar, BAND_TEXTURE),
            left = CreateBevelTexture(bar, END_TEXTURE),
            right = CreateBevelTexture(bar, END_TEXTURE),
        }
        bevel.right:SetTexCoord(1, 0, 0, 1)
        bar._kuiBevel = bevel
    end
    return bevel
end

local function SyncMask(bar, bevel)
    local mask = bar._ktForeverMask
    local applied = bar._kuiBevelMask
    if mask == applied then
        return
    end
    if applied then
        pcall(bevel.band.RemoveMaskTexture, bevel.band, applied)
        pcall(bevel.left.RemoveMaskTexture, bevel.left, applied)
        pcall(bevel.right.RemoveMaskTexture, bevel.right, applied)
    end
    if mask then
        pcall(bevel.band.AddMaskTexture, bevel.band, mask)
        pcall(bevel.left.AddMaskTexture, bevel.left, mask)
        pcall(bevel.right.AddMaskTexture, bevel.right, mask)
    end
    bar._kuiBevelMask = mask
end

local function PlaceBevel(bar, bevel)
    local h = bar:GetHeight() or 12
    local width = math.max(2, math.floor(h * 0.15))

    bevel.band:SetAllPoints(bar)

    bevel.left:ClearAllPoints()
    bevel.left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    bevel.left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    bevel.left:SetWidth(width)

    bevel.right:ClearAllPoints()
    bevel.right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    bevel.right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    bevel.right:SetWidth(width)
end

local function HideBevel(bevel)
    bevel.band:Hide()
    bevel.left:Hide()
    bevel.right:Hide()
end

local function ShowBevel(bevel)
    bevel.band:Show()
    bevel.left:Show()
    bevel.right:Show()
end

function BarGloss:Update()
    local frames = ns.frames
    if not frames then
        return
    end
    local theme = RenderedTheme()
    for _, unit in ipairs(UNITS) do
        local frame = frames[unit]
        if frame then
            for _, key in ipairs(BAR_KEYS) do
                local bar = frame[key]
                if bar and bar.GetFrameLevel then
                    if BarQualifies(theme, frame, bar) then
                        local bevel = EnsureBevel(bar)
                        SyncMask(bar, bevel)
                        PlaceBevel(bar, bevel)
                        ShowBevel(bevel)
                    elseif bar._kuiBevel then
                        HideBevel(bar._kuiBevel)
                    end
                end
            end
        end
    end
end

local function Refresh()
    BarGloss:Update()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
eventFrame:SetScript("OnEvent", Refresh)

-- Masks may be seated late.
if C_Timer and C_Timer.After then
    C_Timer.After(2, Refresh)
    C_Timer.After(5, Refresh)
end
