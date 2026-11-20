local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

-- ============================================================================
-- SISTEMA DE REFRESH AUTOMÁTICO
-- ============================================================================
-- Este archivo asegura que los cambios en la configuración se apliquen inmediatamente

-- Refreshes the modules that rebind to the profile, without the Installer
-- check RefreshAllModules adds.
local function RefreshModules(self)
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
end

-- Función auxiliar para refrescar todos los módulos
function KT:RefreshAllModules()
    RefreshModules(self)
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
        
        -- Hook para cuando se cierre el panel de opciones (aplica cambios).
        -- ACD:Close is a method call (lib, appName); hooked once only.
        local ACD = LibStub("AceConfigDialog-3.0", true)
        if ACD and ACD.Close and not KT._ktACDCloseHooked then
            KT._ktACDCloseHooked = true
            hooksecurefunc(ACD, "Close", function(_, appName)
                if appName == "KullThranUI" then
                    -- Refrescar módulos cuando se cierre la configuración
                    C_Timer.After(0.1, function()
                        KT:RefreshAllModules()
                    end)
                end
            end)
        end
    end
end

-- También refrescar cuando se muestra un aviso de recarga. The popup is only
-- shown, not accepted yet, so the Installer is not auto-opened from here.
hooksecurefunc("StaticPopup_Show", function(which, ...)
    if type(which) == "string" and string.find(which, "RELOAD", 1, true) then
        C_Timer.After(0.1, function()
            RefreshModules(KT)
        end)
    end
end)
