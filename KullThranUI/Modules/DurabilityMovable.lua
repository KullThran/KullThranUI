local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("DurabilityMovable", "AceEvent-3.0", "AceHook-3.0")

local _G = _G
local hooksecurefunc = hooksecurefunc

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

function Mod:OnEnable()
    -- [FIX] Desactivado. El marco de durabilidad ha sido migrado al módulo BlizzardFrames.lua
    -- usando el sistema seguro UnlockMode, previniendo así taint en EditMode.
end

function Mod:RegisterFrames()
    local EM = KT:GetModule("EditMode", true)
    if not EM or not EM.RegisterFrame then 
        -- Reintentar en 1 segundo si EditMode aún no cargó
        C_Timer.After(1, function() self:RegisterFrames() end)
        return 
    end

    -- Helper para restaurar posición
    local function ForceRestorePosition(frame, internalName)
        if InCombatLockdown() then return end
        if EM and EM.db and EM.db.frames[internalName] then
            local saved = EM.db.frames[internalName]
            if saved and saved.point then
                frame:ClearAllPoints()
                if frame:GetParent() ~= _G.UIParent then
                    frame:SetParent(_G.UIParent)
                end
                frame:SetPoint(saved.point, _G.UIParent, saved.relativePoint, saved.x, saved.y)
                
                local wasMovable = frame:IsMovable()
                if not wasMovable then frame:SetMovable(true) end
                pcall(function() frame:SetUserPlaced(true) end)
                if not wasMovable then frame:SetMovable(false) end
            end
        end
    end

    -- 1. DURABILITY FRAME (Panel de Armadura)
    if _G.DurabilityFrame then
        -- [FIX] Impedir que el juego oculte el marco mientras lo editamos
        hooksecurefunc(_G.DurabilityFrame, "Hide", function(self)
            if self.KT_ForcedShow then self:Show() end
        end)
        hooksecurefunc(_G.DurabilityFrame, "SetAlpha", function(self, alpha)
            if self.KT_ForcedShow and alpha < 1 then self:SetAlpha(1) end
        end)
        
        -- [FIX] Hook para mantener posición si Blizzard intenta moverlo
        hooksecurefunc(_G.DurabilityFrame, "SetPoint", function(self)
            if self.KT_Moving then return end
            if _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsEditModeActive() then return end
            
            if EM.db.frames["durability_frame"] then
                 if not self.KT_PendingRestore then
                     self.KT_PendingRestore = true
                     C_Timer.After(0, function()
                         self.KT_PendingRestore = false
                         ForceRestorePosition(self, "durability_frame")
                     end)
                 end
            end
        end)

        EM:RegisterFrame(_G.DurabilityFrame, "Durability", "durability_frame", { 
            resizable = false,
            onDragStart = function()
                _G.DurabilityFrame.KT_Moving = true
            end,
            onDragStop = function()
                _G.DurabilityFrame.KT_Moving = false
                local f = _G.DurabilityFrame
                pcall(function() f:SetUserPlaced(true) end)
                if f:GetParent() ~= _G.UIParent then f:SetParent(_G.UIParent) end
                if EM.SavePosition then EM:SavePosition(f, "durability_frame") end
            end,
            onEnter = function()
                _G.DurabilityFrame.KT_ForcedShow = true
                
                -- [FIX] Si el padre está oculto (ej. MinimapCluster), reparentar a UIParent para verlo
                if _G.DurabilityFrame:GetParent() ~= _G.UIParent then
                    _G.DurabilityFrame.KT_OldParent = _G.DurabilityFrame:GetParent()
                    _G.DurabilityFrame:SetParent(_G.UIParent)
                end
                
                _G.DurabilityFrame.KT_OldStrata = _G.DurabilityFrame:GetFrameStrata()
                _G.DurabilityFrame:SetFrameStrata("DIALOG") -- Asegurar que esté encima de todo
                _G.DurabilityFrame:SetFrameLevel(999) -- Forzar nivel máximo

                _G.DurabilityFrame:SetAlpha(1)
                _G.DurabilityFrame:Show()
                
                -- [FIX] Forzar tamaño si está colapsado (100% durabilidad) para que se vea el recuadro
                if _G.DurabilityFrame:GetWidth() < 20 or _G.DurabilityFrame:GetHeight() < 20 then
                    _G.DurabilityFrame:SetSize(60, 75)
                end

                if not _G.DurabilityFrame.KT_Bg then
                    local bg = _G.DurabilityFrame:CreateTexture(nil, "OVERLAY")
                    bg:SetAllPoints()
                    bg:SetColorTexture(KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333, 0.22)
                    _G.DurabilityFrame.KT_Bg = bg
                    
                    local label = _G.DurabilityFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    label:SetPoint("CENTER")
                    label:SetText(LText("Durability"))
                    label:SetTextColor(KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333)
                    _G.DurabilityFrame.KT_Label = label
                end
                _G.DurabilityFrame.KT_Bg:Show()
                if _G.DurabilityFrame.KT_Label then _G.DurabilityFrame.KT_Label:Show() end
                
                ForceRestorePosition(_G.DurabilityFrame, "durability_frame")
            end,
            onExit = function()
                _G.DurabilityFrame.KT_ForcedShow = nil
                
                local hasSaved = EM.db.frames["durability_frame"] and EM.db.frames["durability_frame"].point
                
                if not hasSaved and _G.DurabilityFrame.KT_OldParent then
                    _G.DurabilityFrame:SetParent(_G.DurabilityFrame.KT_OldParent)
                    _G.DurabilityFrame.KT_OldParent = nil
                end
                
                if _G.DurabilityFrame.KT_OldStrata then
                    _G.DurabilityFrame:SetFrameStrata(_G.DurabilityFrame.KT_OldStrata)
                    _G.DurabilityFrame.KT_OldStrata = nil
                end
                
                if _G.DurabilityFrame.KT_Bg then _G.DurabilityFrame.KT_Bg:Hide() end
                if _G.DurabilityFrame.KT_Label then _G.DurabilityFrame.KT_Label:Hide() end
                if _G.DurabilityFrame_Update then _G.DurabilityFrame_Update() end
                
                if hasSaved then
                    ForceRestorePosition(_G.DurabilityFrame, "durability_frame")
                end
            end
        })
        
        -- Restaurar al cargar
        if EM.db.frames["durability_frame"] then
            ForceRestorePosition(_G.DurabilityFrame, "durability_frame")
        end
    end
end
