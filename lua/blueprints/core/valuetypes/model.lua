AddCSLuaFile()

module("value_model", package.seeall)

local VALUE = {}

VALUE.Match = function( v ) return false end

function VALUE:Setup()

	self:AddFlag( bpvaluetype.FL_HINT_BROWSER )

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

function VALUE:BrowserClick( panel, textEntry )

	self:OpenSearch( function( newText )
		textEntry:SetText(newText)
	end )

end

RegisterValueClass("model", VALUE, "string")