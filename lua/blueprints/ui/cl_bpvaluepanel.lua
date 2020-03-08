if SERVER then AddCSLuaFile() return end

local PANEL = {}

function PANEL:Init()

	self.Search = vgui.Create( "DTextEntry", self )
	self.Search:Dock( TOP )
	self.Search:SelectAllOnFocus()
	self.Search:SetTabPosition( 1 )
	self.Search.OnEnter = function( pnl )

		self:RefreshResults( pnl:GetText() or "" )

	end

	self.Scroll = vgui.Create( "DScrollPanel", self )
	self.Scroll:Dock( FILL )

	self.IconList = vgui.Create( "DTileLayout", self.Scroll )
	self.IconList:SetBaseSize( 64 )
	self.IconList:SetSelectionCanvas( true )

end

function PANEL:Layout()

	self.IconList:Layout()
	self:InvalidateLayout()

end

function PANEL:PerformLayout()

	self.IconList:SetWide( self.Scroll:GetWide() )

end

function PANEL:GetPriority( text )

	return 0

end

function PANEL:RefreshResults( str )

	self.IconList:Clear()

	local results = search.GetResults(str, "props")
	local defer = {}
	for _, v in ipairs(results) do

		if v.icon then
			v.icon.DoClick = function() self:OnSelected(v.words[1] or "") end
			defer[#defer+1] = v
		end

	end

	table.sort( defer, function(a,b) return self:GetPriority(a.text or "") > self:GetPriority(b.text or "") end)

	for _, v in ipairs(defer) do

		v.icon:SetParent(self.IconList)
		self.IconList:Add( v.icon )

	end

end

function PANEL:OnSelected( text )

	print( tostring(text) )

end

vgui.Register( "BPAssetSearch", PANEL, "DPanel" )


if CLIENT then

	concommand.Add("bp_test_assetsearch", function()

		local window = vgui.Create( "DFrame" )
		window:SetSizable( true )
		window:SetPos( 400, 0 )
		window:SetSize( 400, 700 )
		window:MakePopup()

		local inner = vgui.Create( "BPAssetSearch" )
		inner:SetParent(window)
		inner:Dock(FILL)

	end)

end