AddCSLuaFile()

module("value_table", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "table" and getmetatable(v) == nil end

function VALUE:Setup()

	self._children = {}

end

function VALUE:CreateVGUI( info )

	local newInfo = bpcommon.CopyTable(info)
	newInfo.outer = self
	newInfo.depth = (info.depth or 0) + 1

	local list = vgui.Create("DPanelList")
	list:SetSkin("Blueprints")

	if info.outer then
		list:SetAutoSize(true)
		list:SetSpacing( 2 )
	else
		list:SetAutoSize(false)
		list:SetSpacing( 4 )
		list:EnableVerticalScrollbar()
	end

	local labels = {}
	local maxLabelWide = 0

	for i=1, self:GetNumChildren() do

		local ch, key = self:GetChild(i)
		if ch:HasFlag( bpvaluetype.FL_HIDDEN ) then continue end

		local l = vgui.Create("DLabel", p)
		l:SetSkin("Blueprints")
		l:SetText( tostring(key) )
		l:SizeToContentsX()
		labels[i] = l
		maxLabelWide = math.max(maxLabelWide, l:GetWide())

	end

	local b,e = pcall( function()

		for i=1, self:GetNumChildren() do

			local ch, key = self:GetChild(i)
			if ch:HasFlag( bpvaluetype.FL_HIDDEN ) then continue end

			local inner = ch:CreateVGUI(newInfo)
			local label = labels[i]

			if IsValid(inner) then

				local p = vgui.Create("DPanel")
				p:SetBackgroundColor(Color(120,120,120))

				if info.depth ~= nil then
					if info.depth < 2 then
						p:SetBackgroundColor(Color(180,180,180))
					else
						p.Paint = function() end
					end
				end

				label:SetWide( maxLabelWide + 2)
				label:SetParent( p )

				inner:SetParent(p)
				inner:Dock(FILL)
				inner:DockMargin(0,0,4,0)
				inner:InvalidateLayout(true)
				inner:SizeToContents()

				local h = inner:GetTall()

				if ch._class == "table" then
					inner:DockMargin(8,0,0,0)
					label:DockMargin(6,2,2,2)
					label:Dock(TOP)
					h = h + label:GetTall() + 8
				else
					label:DockMargin(6,2,2,2)
					label:Dock(LEFT)
					h = math.max(h, 18)
				end

				p:SetTall( h )
				list:AddItem( p )

			else

				label:Remove()

			end

		end

	end)

	if not b then

		for _, v in ipairs(labels) do v:Remove() end
		list:Clear( true )

	end

	return list

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

function VALUE:Index(str, noError)

	local ch = self
	for x in str:gmatch("[^%.]+") do
		ch = ch:Find(x)
		if not ch then if noError then return nil else error("Couldn't find: " .. x .. " in " .. str) end end
	end
	return ch

end

function VALUE:AddCosmeticChild( key, valueType, position )

	local t = {
		k = key,
		vt = valueType,
	}

	if position then
		return table.insert(self._children, position, t)
	end

	self._children[#self._children+1] = t
	return #self._children

end

function VALUE:SortChildren()

	table.sort(self._children, function(a,b) return tostring(a.k) < tostring(b.k) end)
	return self

end

function VALUE:Set(v)

	BaseClass.Set(self, v)

	self._children = {}

	for k,v in pairs(v) do
		local vt = bpvaluetype.FromValue(v,
			function()
				return self:_Get()[ k ]
			end,
			function(v)
				local p = self:_Get()[ k ]
				self:_Get()[ k ] = v
			end
		)
		self._children[#self._children+1] = {
			k = k,
			vt = vt,
		}
		vt:BindRaw( "valueChanged", self, function(old, new, key)
			local ak = (key ~= nil) and k .. "." .. tostring(key) or k
			self:OnChanged(old, new, ak)
		end )
	end

	self:SortChildren()

	return self

end

function VALUE:ToString()

	local str = "{\n"
	for i=1, #self._children do

		local ch = self._children[i]
		if ch.vt:HasFlag(bpvaluetype.FL_DONT_EMIT) then continue end

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