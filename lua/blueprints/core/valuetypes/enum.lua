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

local btnColor = HexColor and HexColor("#2c3e50")
local btnOver = HexColor and AdjustHSV(btnColor, 0, -.2, 0.1)
local btnPress = HexColor and AdjustHSV(btnColor, 0, -.2, -.1)

function VALUE:GetDefault() return self.options[1][2] end
function VALUE:CreateVGUI( info )

	local btn = vgui.Create("DButton")
	local label = vgui.Create("DLabel", btn)

	btn:SetSkin("Blueprints")
	label:SetSkin("Blueprints")

	btn:SetText("")
	label:SetText( self:FindKey(true) )
	label:DockMargin(6, 0, 0, 0)
	label:Dock( FILL )
	label:SetTextColor( Color(255,255,255) )

	btn.SizeToContents = function(pnl) pnl:SetTall(20) end
	btn.Paint = function(pnl, w, h)
		local col = btnColor
		if pnl.Hovered then col = btnOver end
		if pnl.Depressed then col = btnPress end

		--draw.RoundedBox(4,0,0,w,h, Color(150,150,150))
		draw.RoundedBox(4,0,0,w,h, col)
	end

	function btn.DoClick()

		local menu = bpuipickmenu.Create(nil, nil, 300, 200)
		menu:SetCollection( bpcollection.New():Add( self.options ) )
		menu.OnEntrySelected = function(pnl, e) self:Set(e[2]) label:SetText(e[3] or e[1]) end
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