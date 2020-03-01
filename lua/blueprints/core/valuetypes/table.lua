AddCSLuaFile()

module("value_table", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "table" and getmetatable(v) == nil end

function VALUE:Setup()

	self._children = {}

end

function VALUE:CreateVGUI( info )


end

function VALUE:GetDefault() return {} end

function VALUE:Set(v)

	self._value = v
	self._children = {}

	for k,v in pairs(v) do
		local vt = bpvaluetype.FromValue(v)
		self._children[#self._children+1] = {
			key = k,
			value = v,
			valuetype = vt,
		}
		vt:AddListener( function(cb, ...) if cb == bpvaluetype.CB_VALUE_CHANGED then self:ValueUpdate(k, ...) end end )
	end

	return self

end

function VALUE:Get()

	return self._value

end

function VALUE:ValueUpdate( key, old, new )

	print("Updated " .. key .. " = " .. tostring(new))
	self._value[key] = new

end

RegisterValueClass("table", VALUE)