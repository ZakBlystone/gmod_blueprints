AddCSLuaFile()

module("value_weaponworldmodel", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:GetPriority( text )

	if text:find("^w_") then return 1 end
	return 0

end

RegisterValueClass("weaponworldmodel", VALUE, "model")