AddCSLuaFile()

module("value_string", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "string" end

function VALUE:Setup()

end

function VALUE:CreateVGUI( info )

	local entry = vgui.Create("DTextEntry")
	entry:SetText( self:Get() )
	entry:SelectAllOnFocus()
	if info.live then entry:SetUpdateOnType(true) end

	if info.onFinished then
		local detour = entry.OnKeyCodeTyped
		entry.OnKeyCodeTyped = function(pnl, code)
			if code == KEY_ENTER then return info.onFinished() end
			detour(pnl, code)
		end
	end
	entry.OnValueChange = function(pnl, value)
		self:Set( value )
		--pnl:SetText( self:ToString() )
		if info.onChanged then info.onChanged() end
	end

	return entry

end

function VALUE:GetDefault() return "" end

function VALUE:ToString()

	return "\"" .. tostring( self:Get() ) .. "\""

end

function VALUE:SetFromString( str )

	self:Set( str:sub(2, -2) )

end

RegisterValueClass("string", VALUE)