AddCSLuaFile()

module("value_color", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return IsColor(v) end
VALUE.Type = "Color"
VALUE.InnerType = "number"
VALUE.Num = 4
VALUE.Accessors = {"r", "g", "b", "a"}

function VALUE:GetDefault() return Color(255,255,255,255) end
function VALUE:SetPrecision( p )

	for i=1, self:GetNumChildren() do
		self:GetChild(i):SetPrecision(p)
	end
	return self

end

function VALUE:CreateVGUI( info )

	local mixer = vgui.Create("DColorMixer")

	mixer:SetSkin("Blueprints")
	mixer:SetColor( self:Get() )
	mixer.ValueChanged = function( pnl, col )
		self:Set( Color(col.r, col.g, col.b, col.a) )
	end

	return mixer

end

RegisterValueClass("color", VALUE, "tuple")