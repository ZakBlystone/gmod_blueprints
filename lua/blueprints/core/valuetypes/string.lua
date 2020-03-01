AddCSLuaFile()

module("value_string", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "string" end

function VALUE:Setup()

end

function VALUE:GetDefault() return "" end

function VALUE:ToString()

	return tostring( self:Get() )

end

function VALUE:SetFromString( str )

	self:Set( str )

end

RegisterValueClass("string", VALUE)