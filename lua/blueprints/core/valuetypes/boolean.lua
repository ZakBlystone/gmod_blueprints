AddCSLuaFile()

module("value_boolean", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "boolean" end

function VALUE:Setup()

end

function VALUE:GetDefault() return false end
function VALUE:CreateVGUI( info )

	local zone = vgui.Create("DPanel")
	zone:SetTall(16)

	local check = vgui.Create("DCheckBox", zone)
	check:SetSkin("Blueprints")
	check:InvalidateLayout(true)
	check:SetChecked( self:Get() )
	check.OnChange = function( pnl, val )
		self:Set( val )
	end

	zone.Paint = function() end
	zone.PerformLayout = function( pnl )
		check:SetPos(0, pnl:GetTall()/2 - check:GetTall()/2)
	end

	return zone

end

function VALUE:ToString()

	return tostring(self:Get())

end

function VALUE:SetFromString( str )

	self:Set( str:lower() == "true" )
	return self

end

RegisterValueClass("boolean", VALUE)