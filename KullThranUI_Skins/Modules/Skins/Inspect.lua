local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local pairs = pairs
local type = type
local UnitExists = UnitExists
local GetGuildInfo = _G.GetGuildInfo
local GetInspectGuildInfo = _G.GetInspectGuildInfo

local function HasValidInspectUnit(frame)
    local parent = frame and frame.GetParent and frame:GetParent() or _G.InspectFrame
    local unit = parent and parent.unit
    if type(unit) ~= "string" or unit == "" then
        return false
    end
    if UnitExists and not UnitExists(unit) then
        return false
    end
    return true
end

local function HasInspectGuildData()
    local inspectFrame = _G.InspectFrame
    local unit = inspectFrame and inspectFrame.unit
    if type(unit) ~= "string" or unit == "" then
        return false
    end

    local guildName = nil
    if GetInspectGuildInfo then
        local ok, _, _, name = pcall(GetInspectGuildInfo, unit)
        if ok then
            guildName = name
        end
    elseif GetGuildInfo then
        local ok, name = pcall(GetGuildInfo, unit)
        if ok then
            guildName = name
        end
    end

    return type(guildName) == "string" and guildName ~= ""
end

local function ClearInspectGuildFrame()
    local guildFrame = _G.InspectGuildFrame
    if not guildFrame then
        return
    end

    for _, key in pairs({
        "GuildName", "GuildNameText", "GuildFaction", "GuildFactionText",
        "GuildMemberCount", "GuildMemberCountText", "GuildXP", "GuildXPText",
        "GuildLevel", "GuildLevelText", "MotD", "MotDText"
    }) do
        local region = guildFrame[key] or _G["InspectGuildFrame" .. key]
        if region and region.SetText then
            region:SetText("")
        end
    end
end

local function EnsureSafeInspectGuildUpdate()
    if _G.InspectGuildFrame_Update and not _G.InspectGuildFrame_Update_KTWrapped then
        local originalUpdate = _G.InspectGuildFrame_Update
        _G.InspectGuildFrame_Update = function(...)
            if not HasValidInspectUnit(_G.InspectGuildFrame) then
                return
            end

            if not HasInspectGuildData() then
                ClearInspectGuildFrame()
                return
            end

            local ok = pcall(originalUpdate, ...)
            if not ok then
                ClearInspectGuildFrame()
            end
        end
        _G.InspectGuildFrame_Update_KTWrapped = true
    end
end
local function SkinInspectPVPTalents()
    local pvpFrame = _G.InspectPVPFrame
    if not pvpFrame or not HasValidInspectUnit(pvpFrame) then return end

    for i = 1, 3 do
        local slot = _G["InspectPVPFrameTalentSlot" .. i]
        if slot then
            S:StripTextures(slot, nil, slot.Texture)
            if not slot.backdrop then
                S:CreateBackdrop(slot)
            end
            if slot.Texture and slot.backdrop then
                slot.Texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                slot.Texture:SetAlpha(1)
                S:SetInside(slot.Texture, slot.backdrop)
            end
        end
    end
end

S.SkinFuncs["Blizzard_InspectUI"] = function()
    if not (S.db.enable and S.db.inspect) then return end

    local InspectFrame = _G.InspectFrame
    if not InspectFrame then return end

    EnsureSafeInspectGuildUpdate()

    -- 1. Marco Principal
    S:HandlePortraitFrame(InspectFrame)
    if InspectFrame.Inset then S:StripTextures(InspectFrame.Inset) end
    if InspectFrame.Bg then InspectFrame.Bg:Hide() end
    if InspectFrame.TitleBg then InspectFrame.TitleBg:Hide() end
    if _G.InspectModelFrameBackgroundOverlay then _G.InspectModelFrameBackgroundOverlay:Hide() end

    -- 2. Pestañas
    for i = 1, 3 do
        local tab = _G["InspectFrameTab" .. i]
        if tab then S:HandleTab(tab) end
    end

    -- 3. Slots de Equipo
    local slots = {
        "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
        "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
        "MainHandSlot", "SecondaryHandSlot"
    }

    for _, slotName in pairs(slots) do
        local slot = _G["Inspect" .. slotName]
        if slot then
            local icon = slot.icon or _G[slot:GetName() .. "IconTexture"]
            S:StripTextures(slot, nil, icon)
            if not slot.backdrop then
                S:CreateBackdrop(slot)
            end
            if slot.backdrop then
                slot.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
                S:SetInside(slot.backdrop, slot)
            end

            if icon and slot.backdrop then
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                icon:SetAlpha(1)
                S:SetInside(icon, slot.backdrop)
            end

            slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            slot:GetHighlightTexture():SetBlendMode("ADD")
            if slot.backdrop then
                slot:GetHighlightTexture():SetAllPoints(slot.backdrop)
            end
        end
    end

    -- 4. Limpieza del Modelo 3D
    if _G.InspectModelFrame then
        S:StripTextures(_G.InspectModelFrame)
        local borders = {
            "InspectModelFrameBorderTopLeft", "InspectModelFrameBorderTopRight",
            "InspectModelFrameBorderBottomLeft", "InspectModelFrameBorderBottomRight",
            "InspectModelFrameBorderTop", "InspectModelFrameBorderBottom",
            "InspectModelFrameBorderLeft", "InspectModelFrameBorderRight"
        }
        for _, b in pairs(borders) do
            if _G[b] then _G[b]:Hide() end
        end
    end

    -- 5. Talentos PvP: solo cuando el frame ya tiene unidad válida.
    if _G.InspectPVPFrame and not _G.InspectPVPFrame._ktPVPSkinHooked then
        _G.InspectPVPFrame:HookScript("OnShow", function(frame)
            if HasValidInspectUnit(frame) then
                SkinInspectPVPTalents()
            end
        end)
        _G.InspectPVPFrame._ktPVPSkinHooked = true
    end

    if HasValidInspectUnit(_G.InspectPVPFrame) then
        SkinInspectPVPTalents()
    end
end