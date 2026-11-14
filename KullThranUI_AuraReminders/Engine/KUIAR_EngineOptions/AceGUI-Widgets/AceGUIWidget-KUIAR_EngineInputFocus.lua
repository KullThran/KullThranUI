-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
--[[-----------------------------------------------------------------------------
Input Widget that allows to show an alternative text when it does not have focus
-------------------------------------------------------------------------------]]
if not KUIAR_Runtime.IsLibsOK() then return end

local Type, Version = "KUIAR_RuntimeInputFocus", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local OnEditFocusGained = function(self)
	local textWithFocus = self.obj.textWithFocus
	if textWithFocus and self:GetText() == self.obj.textWithoutFocus then
		self:SetText(textWithFocus)
	end
	AceGUI:SetFocus(self.obj)
end


local function Constructor()
	local button = AceGUI:Create("EditBox")
	button.type = Type

	button.editbox:SetScript("OnEditFocusGained", OnEditFocusGained)

	local oldSetText = button.SetText
	button.SetText = function(self, text)
		text = text or ""
		local pos = string.find(text, "\0", nil, true)
		if pos then
			self.textWithoutFocus = text:sub(1, pos -1)
			self.textWithFocus = text:sub(pos + 1)
			oldSetText(self, self.textWithoutFocus)
		else
			self.textWithFocus = nil
			self.textWithoutFocus = nil
			oldSetText(self, text)
		end
	end

	return button
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

end)
