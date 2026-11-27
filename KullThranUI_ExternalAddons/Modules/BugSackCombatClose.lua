-- BugSack: keep its window closable in combat.
-- The modern BugSack window uses the close button of PortraitFrameTemplate,
-- which calls HideUIPanel. That button belongs to BugSack's own frame, so the
-- call runs as addon code and HideUIPanel refuses it in combat; the window
-- stayed open until combat ended. BugSackFrame is a plain addon frame: hiding
-- it directly is allowed at any time.

local BUGSACK_FRAME_NAME = "BugSackFrame"

local function HideOwner(button)
    local owner = button and button:GetParent()
    if not (owner and owner.Hide) then
        return
    end
    -- Out of combat the panel manager closes it, so the other open panels
    -- move back; in combat it refuses, and the plain frame is hidden directly.
    if HideUIPanel and not InCombatLockdown() then
        HideUIPanel(owner)
    end
    if owner:IsShown() then
        owner:Hide()
    end
end

local function PatchCloseButton(frame)
    local close = frame and frame.CloseButton
    if not close or close._ktCombatClose or not close.SetScript then
        return
    end
    close._ktCombatClose = true
    close:SetScript("OnClick", HideOwner)
end

local function PatchBugSack()
    PatchCloseButton(_G[BUGSACK_FRAME_NAME])
end

-- The window is created the first time it opens. Patch it before combat, and
-- if a close request in combat was refused, finish it here.
if hooksecurefunc then
    hooksecurefunc("HideUIPanel", function(frame)
        if not frame or frame ~= _G[BUGSACK_FRAME_NAME] then
            return
        end
        PatchCloseButton(frame)
        if frame:IsShown() and InCombatLockdown() then
            frame:Hide()
        end
    end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:SetScript("OnEvent", PatchBugSack)
