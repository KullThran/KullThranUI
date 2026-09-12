local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G

S:AddCallbackForAddon("Blizzard_MacroUI", "Macro", function()
    if not S.db.enable then return end

    local MacroFrame = _G.MacroFrame
    if not MacroFrame then return end

    S:HandlePortraitFrame(MacroFrame)

    if MacroFrame.MacroSelector then
        if MacroFrame.MacroSelector.ScrollBar then
            S:HandleScrollBar(MacroFrame.MacroSelector.ScrollBar)
        end
    else
        -- Pre-10.0 fallback
        if _G.MacroButtonScrollFrame then
            S:HandleScrollBar(_G.MacroButtonScrollFrame.ScrollBar)
        end
    end

    if _G.MacroFrameScrollFrame then
        S:HandleScrollBar(_G.MacroFrameScrollFrame.ScrollBar)
    end
    if _G.MacroFrameTextBackground then
        S:StripTextures(_G.MacroFrameTextBackground)
        S:CreateBackdrop(_G.MacroFrameTextBackground)
    end
    if _G.MacroFrameText then
        S:HandleEditBox(_G.MacroFrameText)
    end

    local buttons = {
        "MacroEditButton",
        "MacroCancelButton",
        "MacroSaveButton",
        "MacroNewButton",
        "MacroDeleteButton",
        "MacroExitButton",
    }

    for _, btnName in ipairs(buttons) do
        if _G[btnName] then
            S:HandleButton(_G[btnName])
        end
    end

    local tabs = {
        "MacroFrameTab1",
        "MacroFrameTab2",
    }

    for _, tabName in ipairs(tabs) do
        if _G[tabName] then
            S:HandleTab(_G[tabName])
        end
    end
    
    local selectedButton = _G.MacroFrameSelectedMacroButton
    if selectedButton then
        S:StripTextures(selectedButton)
        local icon = selectedButton.Icon or _G.MacroFrameSelectedMacroButtonIcon
        if icon then
            S:HandleIcon(icon, true)
            if icon.SetTexCoord then
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
        end
    end
end)
