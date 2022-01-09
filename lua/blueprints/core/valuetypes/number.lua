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

	if self._min and self._max then

		local entry = vgui.Create("DNumSlider", parent)
		entry:SetSkin("Blueprints")
		entry:SetMin( self._min )
		entry:SetMax( self._max )
		entry:SetDecimals( self._prec )
		entry:SetValue( self:Get() )

		entry.OnValueChanged = function(pnl, value)
			self:Set( value )
			if info.onChanged then info.onChanged() end
		end

		entry.OnRemove = function(pnl) self:UnbindAll( pnl ) end
		entry:SetEnabled(not self:HasFlag(bpvaluetype.FL_READONLY))

		self:BindRaw("valueChanged", entry, function(old, new, key)
			entry:SetValue( new )
		end)

		return entry

	end

	local entry = BaseClass.CreateVGUI(self, info)
	entry:SetNumeric(true)
	return entry

end

function VALUE:ToString()

	--if self._prec == 0 then return string.format("%d", self:Get()) end
	--return string.format("%0." .. self._prec .. "f", self:Get())
	return tostring( self:Get() )

end

function VALUE:SetMin( min )

	self._min = min
	return self

end

function VALUE:SetMax( max )

	self._max = max
	return self

end

function VALUE:SetFromString( str )

	local _,_,dec = str:find("%-*%d*%.(%d+)")
	dec = dec and (#dec) or 0
	self._prec = dec
	self:Set( tonumber(str) or 0 )
	return self

end

function VALUE:Serialize(stream)

	BaseClass.Serialize( self, stream )
	self._prec = stream:Value( self._prec )

end

RegisterValueClass("number", VALUE)