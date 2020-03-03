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
function VALUE:GetChild(i) return self._children[i].vt, self._children[i].k end
function VALUE:GetNumChildren() return #self._children end

function VALUE:Find(key)

	for _,v in ipairs(self._children) do
		if tostring(v.k) == key then return v.vt end
	end
	return nil

end

function VALUE:Index(str)

	local ch = self
	for x in str:gmatch("[^%.]+") do
		ch = ch:Find(x)
		if not ch then error("Couldn't find: " .. x .. " in " .. str) end
	end
	return ch

end

function VALUE:Set(v)

	self.BaseClass.Set(self, v)

	self._children = {}

	for k,v in pairs(v) do
		local vt = bpvaluetype.FromValue(v,
			function(v)
				local p = self:_Get()[ k ]
				self:_Get()[ k ] = v
				self:OnChanged(p, v, k)
			end,
			function()
				return self:_Get()[ k ]
			end
		)
		self._children[#self._children+1] = {
			k = k,
			vt = vt,
		}
		vt:AddListener( function(cb, ...) if cb == bpvaluetype.CB_VALUE_CHANGED then self:ValueUpdate(k) end end )
	end

	return self

end

function VALUE:ValueUpdate( key )

	print("Updated " .. key)

end

function VALUE:ToString()

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

RegisterValueClass("table", VALUE)