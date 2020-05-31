AddCSLuaFile()

module("value_boolean", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:Setup()

end

function VALUE:GetDefault() return nil end
function VALUE:CreateVGUI( info )

	local zone = vgui.Create("DPanel")
	zone:SetTall(16)
	zone:SetSkin("Blueprints")
	return zone

end

function VALUE:ToString()

	return "nil"

end

function VALUE:SetFromString( str )

	return self

end

RegisterValueClass("none", VALUE)