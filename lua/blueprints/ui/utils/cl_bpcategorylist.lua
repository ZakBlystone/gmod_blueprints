if SERVER then AddCSLuaFile() return end

module("bpuicategorylist", package.seeall)

local PANEL = {}

function PANEL:Init()

	self.pnlCanvas:DockPadding( 2, 2, 2, 2 )

end

function PANEL:Add( name )

	local Category = vgui.Create( "BPCollapsibleCategory", self )
	Category:SetLabel( name )
	Category:SetList( self )

	self:AddItem( Category )

	return Category

end

function PANEL:Paint( w, h )

	return true

end

function PANEL:UnselectAll()

	for k, v in pairs( self:GetChildren() ) do

		if ( v.UnselectAll ) then
			v:UnselectAll()
		end

	end

end

derma.DefineControl( "BPCategoryList", "", PANEL, "DCategoryList" )
