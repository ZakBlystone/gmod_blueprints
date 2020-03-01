AddCSLuaFile()

module("value_boolean", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "boolean" end

function VALUE:Setup()

end

function VALUE:GetDefault() return false end
function VALUE:CreateVGUI( info )

end

function VALUE:ToString()

	return tostring(self:Get())

end

function VALUE:SetFromString( str )

	self:Set( str:lower() == "true" )

end

RegisterValueClass("boolean", VALUE)