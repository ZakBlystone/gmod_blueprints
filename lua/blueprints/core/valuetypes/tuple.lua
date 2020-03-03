AddCSLuaFile()

module("value_tuple", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end
VALUE.Type = ""
VALUE.InnerType = "number"
VALUE.Num = 1
VALUE.Accessors = {}

function VALUE:Setup()

	self._children = {}
	for i=1, self.Num do
		local child = bpvaluetype.New( self.InnerType,
			function(v)
				local k = self.Accessors[i] or i
				local p = self:_Get()[ k ]
				self:_Get()[ k ] = v
				self:OnChanged( p, v, k )
			end,
			function()
				local k = self.Accessors[i] or i
				return self:_Get()[ k ]
			end
		)

		self._children[#self._children+1] = child
	end

end

function VALUE:CreateVGUI( info )


end

function VALUE:GetDefault() return {} end
function VALUE:GetChild(i) return self._children[i] end
function VALUE:GetNumChildren() return #self._children end

function VALUE:ToString()

	local str = self.Type .. "("
	for i=1, self.Num do
		local ch = self._children[i]
		str = str .. ch:ToString()
		if i ~= self.Num then str = str .. ", " end
	end
	str = str .. ")"
	return str

end

function VALUE:SetFromString( str )

	local i = 1
	local _, _, inner = string.find(str, self.Type .. "%(([^%)]*)%)")
	if inner == nil then return end

	for x in string.gmatch(inner, "([^,%s]+)") do
		local ch = self._children[i]
		if not ch then error("Tried to set tuple [index out of range]: " .. i) end
		ch:SetFromString( x )
		i = i + 1
	end

end


RegisterValueClass("tuple", VALUE)