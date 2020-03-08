AddCSLuaFile()

module("value_model", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:Setup()

end

function VALUE:CheckType( v )

	return type(v) == "string"

end

function VALUE:OpenSearch( cb )

	local window = vgui.Create( "DFrame" )
	window:SetSizable( true )
	window:SetSize( 600, 400 )
	window:Center()
	window:SetTitle("Search")
	window:MakePopup()

	local inner = vgui.Create( "BPAssetSearch" )
	inner:SetParent(window)
	inner:Dock(FILL)
	inner.OnSelected = function(pnl, text)
		self:Set( text )
		cb( text )
		if IsValid(window) then window:Close() end
	end
	inner.Search:RequestFocus()
	inner.GetPriority = function(pnl, text)

		return self:GetPriority( text )

	end

end

function VALUE:GetPriority( text )

	return 0

end

function VALUE:CreateVGUI( info )

	local panel = vgui.Create("DPanel")

	local entry = vgui.Create("DTextEntry", panel)
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

	local button = vgui.Create("DButton", panel)
	button:SetText("...")

	button.DoClick = function()

		self:OpenSearch( function( newText )
			entry:SetText(newText)
		end )

	end

	entry:Dock( FILL )
	button:Dock( RIGHT )

	return panel

end


function VALUE:GetDefault() return "" end

function VALUE:ToString()

	return "\"" .. tostring( self:Get() ) .. "\""

end

function VALUE:SetFromString( str )

	self:Set( str:sub(2, -2) )

end

RegisterValueClass("model", VALUE)