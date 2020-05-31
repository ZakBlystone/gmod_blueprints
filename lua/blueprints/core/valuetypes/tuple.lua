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
			function()
				local k = self.Accessors[i] or i
				return self:_Get()[ k ]
			end,
			function(v)
				local k = self.Accessors[i] or i
				local p = self:_Get()[ k ]
				self:_Get()[ k ] = v
				self:OnChanged( p, v, k )
			end
		)

		self._children[#self._children+1] = child
	end

end

function VALUE:CreateVGUI( info )

	local zone = vgui.Create("DPanel")
	local newInfo = bpcommon.CopyTable(info)
	newInfo.outer = self

	local inner = {}
	for i=1, self:GetNumChildren() do
		local ch = self:GetChild(i)
		local k = self.Accessors[i] or i

		local sub = vgui.Create("DPanel", zone)
		sub:SetSkin("Blueprints")
		local l = vgui.Create("DLabel", sub)
		local p = ch:CreateVGUI( newInfo )
		l:SetSkin("Blueprints")
		p:SetParent(sub)
		l:Dock( LEFT )
		l:SetText( tostring(k) .. ": " )
		l:SizeToContents()
		p:Dock( FILL )
		sub.Paint = function() end
		inner[#inner+1] = sub
	end

	zone.Paint = function() end
	zone.PerformLayout = function( pnl )

		local count = #inner
		if count <= 0 then return end

		local w, h = pnl:GetSize()
		local x = 0
		for i=1, count do
			local p = inner[i]
			p:SetPos(x, h/2 - p:GetTall()/2)
			p:SetWide(w / count)
			x = x + p:GetWide()
		end

	end

	return zone

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
	return self

end


RegisterValueClass("tuple", VALUE)