AddCSLuaFile()

local PIN = {}

function PIN:OnClicked()

	local subType = self:GetSubType()
	bpuiassetbrowser.New( subType, function( bSelected, value )
		if bSelected then self:SetLiteral( value ) end
	end ):SetCookie("pin"):Open()

	--print("EDIT ASSET: " .. self:ToString(true))

end


RegisterPinClass("Asset", PIN, "String")