AddCSLuaFile()

local PIN = {}

local NetThunks = {
	["Player"] = { read = "net.ReadEntity()", write = "net.WriteEntity(@)" },
	["Entity"] = { read = "net.ReadEntity()", write = "net.WriteEntity(@)" },
	["Weapon"] = { read = "net.ReadEntity()", write = "net.WriteEntity(@)" },
	["NPC"] = { read = "net.ReadEntity()", write = "net.WriteEntity(@)" },
	["Vehicle"] = { read = "net.ReadEntity()", write = "net.WriteEntity(@)" },
	["VMatrix"] = { read = "net.ReadMatrix()", write = "net.WriteMatrix(@)" },
}

function PIN:GetNetworkThunk()

	return NetThunks[self:GetSubType()]

end

RegisterPinClass("Ref", PIN)