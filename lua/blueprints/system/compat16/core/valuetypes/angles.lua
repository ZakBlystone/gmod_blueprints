AddCSLuaFile()

module("value_angles", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return isangle(v) end
VALUE.Type = "Angle"
VALUE.InnerType = "number"
VALUE.Num = 3
VALUE.Accessors = {"p", "y", "r"}

function VALUE:GetDefault() return Angle() end
function VALUE:SetPrecision( p )

	for i=1, self:GetNumChildren() do
		self:GetChild(i):SetPrecision(p)
	end
	return self

end

RegisterValueClass("angles", VALUE, "tuple")