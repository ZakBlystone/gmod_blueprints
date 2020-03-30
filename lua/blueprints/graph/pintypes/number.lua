AddCSLuaFile()

local PIN = {}

function PIN:OnClicked()

	bptextliteraledit.EditPinLiteral(self)

end

function PIN:GetNetworkThunk()

	return {
		read = "net.ReadFloat()",
		write = "net.WriteFloat(@)",
	}

end

RegisterPinClass("Number", PIN)