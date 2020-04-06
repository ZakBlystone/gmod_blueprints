AddCSLuaFile()

module("value_number", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "number" end

function VALUE:Setup()

	self._prec = 0

end

function VALUE:SetPrecision( p )

	self._prec = p
	return self

end

function VALUE:GetDefault() return 0 end

function VALUE:CreateVGUI( info )

	local entry = BaseClass.CreateVGUI(self, info)
	entry:SetNumeric(true)
	return entry

end

function VALUE:ToString()

	--if self._prec == 0 then return string.format("%d", self:Get()) end
	--return string.format("%0." .. self._prec .. "f", self:Get())
	return tostring( self:Get() )

end

function VALUE:SetFromString( str )

	local _,_,dec = str:find("%-*%d*%.(%d+)")
	dec = dec and (#dec) or 0
	self._prec = dec
	self:Set( tonumber(str) )
	return self

end

function VALUE:Serialize(stream)

	BaseClass.Serialize( self, stream )
	self._prec = stream:Value( self._prec )

end

RegisterValueClass("number", VALUE)