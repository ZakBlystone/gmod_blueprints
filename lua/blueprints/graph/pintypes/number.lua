AddCSLuaFile()

local PIN = {}

function PIN:OnClicked()

	bptextliteraledit.EditPinLiteral(self)

end

RegisterPinClass("Number", PIN)