AddCSLuaFile()

module("value_weaponworldmodel", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:Setup()

	BaseClass.Setup( self )
	self:SetAssetType( "Model" )

end

function VALUE:GetPriority( text )

	if text:find("^w_") then return 0 end
	return 1

end

RegisterValueClass("weaponworldmodel", VALUE, "asset")