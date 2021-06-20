AddCSLuaFile()

module("value_array", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:Setup()

	self._children = {}

end

function VALUE:ToString()

	if #self._children == 0 then return "{}" end

	local str = "{\n"
	for i=1, #self._children do

		local ch = self._children[i]
		local v = ch.vt:ToString()
		v = v:gsub("\n", "\n\t")

		local fmt = "\t%s = %s,"
		if type(ch.k) ~= "string" then
			fmt = "\t[%s] = %s,"
		elseif string.find(ch.k, "%s") then
			fmt = "\t[\"%s\"] = %s,"
		end

		local vs = string.format(fmt, ch.k, v) .. "\n"
		str = str .. vs

	end
	str = str .. "}"
	return str

end

function VALUE:SetFromString( str )

end

RegisterValueClass("array", VALUE)