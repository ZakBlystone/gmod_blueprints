AddCSLuaFile()

module("value_weaponviewmodel", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:Setup()

	BaseClass.Setup( self )
	self:SetAssetType( "Model" )

end

function VALUE:GetPriority( text )

	if text:find("^c_") then return 0 end
	if text:find("^v_") then return 1 end
	return 2

end

RegisterValueClass("weaponviewmodel", VALUE, "asset")