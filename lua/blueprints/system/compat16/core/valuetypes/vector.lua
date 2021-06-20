AddCSLuaFile()

module("value_vector", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return isvector(v) end
VALUE.Type = "Vector"
VALUE.InnerType = "number"
VALUE.Num = 3
VALUE.Accessors = {"x", "y", "z"}

function VALUE:GetDefault() return Vector() end
function VALUE:SetPrecision( p )

	for i=1, self:GetNumChildren() do
		self:GetChild(i):SetPrecision(p)
	end
	return self

end

RegisterValueClass("vector", VALUE, "tuple")