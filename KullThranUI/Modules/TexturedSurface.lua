local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

-- Shared by Blizzard skins and standalone modules (e.g. Objective Tracker).
-- Original KUI artwork only; no dependency on KullThranUI_Skins.
local TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUISettingsSurface.png"
local DEFAULT_WASH = 0.55
local surfaces = setmetatable({}, { __mode = "k" })

function KT:ApplyTexturedSurface(frame, color, washAlpha)
    if not frame or not frame.CreateTexture
        or (frame.IsForbidden and frame:IsForbidden()) then return end
    local data = surfaces[frame]
    if not data then
        data = {}
        surfaces[frame] = data
        data.artwork = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        data.artwork:SetTexture(TEXTURE)
        data.artwork:SetAllPoints(frame)
        data.wash = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        data.wash:SetAllPoints(frame)
        data.fit = function()
            local width, height = frame:GetSize()
            if issecretvalue and (issecretvalue(width) or issecretvalue(height)) then return end
            if not width or not height or width <= 0 or height <= 0 then return end
            local aspect = width / height
            if aspect > 1 then
                local trim = (1 - 1 / aspect) / 2
                data.artwork:SetTexCoord(0, 1, trim, 1 - trim)
            else
                local trim = (1 - aspect) / 2
                data.artwork:SetTexCoord(trim, 1 - trim, 0, 1)
            end
        end
        frame:HookScript("OnSizeChanged", data.fit)
    end
    color = color or { 0.05, 0.05, 0.05, 1 }
    local alpha = color[4] or 1
    data.artwork:SetVertexColor(1, 1, 1, 1)
    data.artwork:SetAlpha(alpha)
    data.wash:SetAlpha(alpha)
    data.wash:SetColorTexture(math.max(0, color[1] - 0.05),
        math.max(0, color[2] - 0.05), math.max(0, color[3] - 0.05),
        washAlpha == nil and DEFAULT_WASH or washAlpha)
    data.artwork:Show()
    data.wash:Show()
    data.fit()
    return data.artwork, data.wash
end

