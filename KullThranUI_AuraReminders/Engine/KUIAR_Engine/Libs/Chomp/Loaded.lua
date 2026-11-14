-- Embedded adaptation of ForeverAuras 1.3.8; GPL-2.0. See Engine/UPSTREAM.md.
-- KullThranUI: was an inline script in Chomp.xml; it runs in the engine to reach the engine's library registry.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_Engine", function(...)
		local Chomp = LibStub:GetLibrary("Chomp", true)
		local Internal = Chomp and Chomp.Internal or nil

		if Chomp and Internal then
			Internal.LOADING = nil
		end
end)
