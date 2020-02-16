AddCSLuaFile()

local PIN = {}

function PIN:OnClicked()

	local value = self:GetLiteral()
	self:SetLiteral(value == "true" and "false" or "true")

end

RegisterPinClass("Boolean", PIN)