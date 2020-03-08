AddCSLuaFile()

module("value_string", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return type(v) == "string" end

function VALUE:Setup()

end

function VALUE:BrowserClick( panel, textEntry )

end

function VALUE:CreateTextEntry( info, parent )

	local entry = vgui.Create("DTextEntry", parent)
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

function VALUE:CreateVGUI( info )

	if self:HasFlag( bpvaluetype.FL_HINT_BROWSER ) then

		local panel = vgui.Create("DPanel")
		local entry = self:CreateTextEntry(info, panel)
		local button = vgui.Create("DButton", panel)
		button:SetText("...")
		button.DoClick = function() self:BrowserClick( button, entry ) end
		button:SetWide(32)

		entry:Dock( FILL )
		button:Dock( RIGHT )

		return panel

	else

		return self:CreateTextEntry( info )

	end

end

function VALUE:GetDefault() return "" end

function VALUE:ToString()

	return "\"" .. tostring( self:Get() ) .. "\""

end

function VALUE:SetFromString( str )

	self:Set( str:sub(2, -2) )
	return self

end

RegisterValueClass("string", VALUE)