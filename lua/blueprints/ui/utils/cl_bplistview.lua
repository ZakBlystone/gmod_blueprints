if SERVER then AddCSLuaFile() return end

module("bpuilistview", package.seeall)

local PANEL = {}

function PANEL:SetNoConfirm(...) return self.listview:SetNoConfirm(...) end
function PANEL:SetList(...) return self.listview:SetList(...) end
function PANEL:ClearSelection(...) return self.listview:ClearSelection(...) end
function PANEL:Select(...) return self.listview:Select(...) end
function PANEL:GetSelected(...) return self.listview:GetSelected(...) end
function PANEL:Clear(...) return self.listview:Clear(...) end
function PANEL:Rename( ... ) return self.listview:Rename(...) end
function PANEL:CreateItemPanel( ... ) return self.defaultCreateItemPanel( self.listview, ... ) end

function PANEL:OnItemSelected( item ) end
function PANEL:ItemBackgroundColor( item, selected ) return selected and Color(80,80,80,255) or Color(50,50,50,255) end
function PANEL:ItemIcon( id, item ) return nil end
function PANEL:PopulateMenuItems( items, item ) end
function PANEL:HandleAddItem( list ) end

function PANEL:Init()

	self:SetKeyboardInputEnabled( true )
	self:SetBackgroundColor( Color(30,30,30) )
	self.controls = vgui.Create("DPanel", self)
	self.controls:SetBackgroundColor( Color(30,30,30) )
	self.vitems = {}

	self.label = vgui.Create("DLabel", self.controls)
	self.label:SetFont("DermaDefaultBold")

	self.btnAdd = vgui.Create("DButton", self.controls)
	self.btnAdd:SetFont("DermaDefaultBold")
	self.btnAdd:SetWide(20)
	self.btnAdd:SetTextColor( Color(255,255,255) )
	self.btnAdd:SetText("+")
	self.btnAdd:SetDrawBorder(false)
	self.btnAdd:SetPaintBackground(false)

	self.label:Dock( LEFT )
	self.btnAdd:Dock( RIGHT )
	self.controls:DockMargin( 8,2,2,2 )
	self.controls:Dock( TOP )
	self.controls:SetTall(20)

	self.btnAdd.DoClick = function()
		self.listview:InvokeAdd()
	end

	self.selectedID = nil
	self.listview = vgui.Create("BPListPanel", self)
	self.listview:Dock( FILL )
	self.listview.Paint = function() end
	self.listview:EnableVerticalScrollbar()
	self.listview.OnItemSelected = function( pnl, ... ) return self:OnItemSelected( ... ) end
	self.listview.ItemBackgroundColor = function( pnl, ... ) return self:ItemBackgroundColor( ... ) end
	self.listview.ItemIcon = function( pnl, ... ) return self:ItemIcon( ... ) end
	self.listview.PopulateMenuItems = function( pnl, ... ) return self:PopulateMenuItems( ... ) end
	self.listview.HandleAddItem = function( pnl, ... ) return self:HandleAddItem( ... ) end

	self.defaultCreateItemPanel = self.listview.CreateItemPanel
	self.listview.CreateItemPanel = function( pnl, ... ) return self.CreateItemPanel( pnl, ... ) end

end

vgui.Register( "BPListView", PANEL, "DPanel" )