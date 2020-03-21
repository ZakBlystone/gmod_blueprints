AddCSLuaFile()

module("value_asset", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:Setup()

end

function VALUE:SetupPinType( pinType )

	print("SETUP FROM PIN: " .. pinType:ToString(true))

end

RegisterValueClass("asset", VALUE, "string")