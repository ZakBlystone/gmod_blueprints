AddCSLuaFile()

local PIN = {}

function PIN:OnClicked()

	bptextliteraledit.EditPinLiteral(self)

end


RegisterPinClass("String", PIN)