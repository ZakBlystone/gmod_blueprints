AddCSLuaFile()

module("value_enum", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end
VALUE.Type = "Enum"

function VALUE:Setup()

	self.options = { "None", 0 }

end

function VALUE:CheckType(v)

end

function VALUE:InitPinType( pinType )

	local enum = bpdefs.Get():GetEnum( pinType )
	if enum == nil then
		ErrorNoHalt("NO ENUM FOR " .. pinType:ToString(true) .. "\n")
		return
	end

	local opt = {}
	for k, v in ipairs(enum.entries) do
		opt[#opt+1] = { v.key, k, v.shortkey, v.desc }
	end

	if #opt == 0 then return end
	self:SetOptions( opt )
	return self

end

function VALUE:SetOptions(list)

	self.options = list
	return self

end

function VALUE:FindValue( key )

	key = key:lower()
	for _, v in ipairs(self.options) do
		if v[1]:lower() == key then return v[2] end
	end
	return self.options[1][2]

end

function VALUE:FindKey( short )

	local current = self:Get()
	for _, v in ipairs(self.options) do
		if v[2] == current then return (short and v[3]) or v[1] end
	end
	return "unknown"

end

function VALUE:ToString()

	return self:FindKey()

end

function VALUE:SetFromString( str )

	self:Set( self:FindValue( str ) )
	return self

end


function VALUE:GetDefault() return self.options[1][2] end
function VALUE:CreateVGUI( info )

	local btn = vgui.Create("DButton")

	btn:SetText( self:FindKey(true) )
	function btn.DoClick()

		local menu = bpuipickmenu.Create(nil, nil, 300, 200)
		menu:SetCollection( bpcollection.New():Add( self.options ) )
		menu.OnEntrySelected = function(pnl, e) self:Set(e[2]) btn:SetText(e[3] or e[1]) end
		menu.GetDisplayName = function(pnl, e) return e[3] or e[1] end
		menu.GetTooltip = function(pnl, e) return e[4] or e[3] or e[1] end
		menu:SetSorter( function(a,b)
			local aname = menu:GetDisplayName(a)
			local bname = menu:GetDisplayName(b)
			return aname:lower() < bname:lower()
		end
		)
		menu:Setup()

	end

	return btn

end

RegisterValueClass("enum", VALUE)