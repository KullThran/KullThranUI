local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

-- ============================================================================
-- SISTEMA DE REFRESH AUTOMÁTICO
-- ============================================================================
-- Este archivo asegura que los cambios en la configuración se apliquen inmediatamente

-- Función auxiliar para refrescar todos los módulos
function KT:RefreshAllModules()
    -- Minimap
    local minimap = self:GetModule("Minimap", true)
    if minimap and minimap.Refresh then
        minimap:Refresh()
    end
    
    -- Armory
    local armory = self:GetModule("Armory", true)
    if armory and armory.Refresh then
        armory:Refresh()
    end
    
    -- CastBar
    local castbar = self:GetModule("CastBar", true)
    if castbar and castbar.Refresh then
        castbar:Refresh()
    end

    -- Blizzard bars must rebind their live frames/profile table after profile
    -- imports and options lifecycle transitions.
    local blizzardFrames = self:GetModule("BlizzardFrames", true)
    if blizzardFrames and blizzardFrames.Refresh then
        blizzardFrames:Refresh()
    end
        -- Llamar a la función original
    if self.MaybeAutoOpenInstaller then self:MaybeAutoOpenInstaller() end
end

-- Hook en SetupOptions para agregar callbacks
local orig_SetupOptions = KT.SetupOptions
if orig_SetupOptions then
    function KT:SetupOptions()
        orig_SetupOptions(self)
        
        -- Agregar callbacks para cambios en la configuración
        if self.db and self.db.RegisterCallback then
            self.db.RegisterCallback(self, "OnProfileChanged", "RefreshAllModules")
            self.db.RegisterCallback(self, "OnProfileCopied", "RefreshAllModules")
            self.db.RegisterCallback(self, "OnProfileReset", "RefreshAllModules")
        end
        
        -- Hook para cuando se cierre el panel de opciones (aplica cambios)
        local ACD = LibStub("AceConfigDialog-3.0", true)
        if ACD then
            local orig_Close = ACD.Close
            ACD.Close = function(appName, ...)
                if appName == "KullThranUI" then
                    -- Refrescar módulos cuando se cierre la configuración
                    C_Timer.After(0.1, function()
                        KT:RefreshAllModules()
                    end)
                end
                return orig_Close(appName, ...)
            end
        end
    end
end

-- También refrescar cuando se acepta un cambio en opciones
hooksecurefunc("StaticPopup_Show", function(which, ...)
    if which and string.find(which, "RELOAD") then
        -- Si se muestra un aviso de recarga, el jugador está aceptando cambios importantes
        C_Timer.After(0.1, function()
            if KT.RefreshAllModules then
                KT:RefreshAllModules()
            end
        end)
    end
end)
