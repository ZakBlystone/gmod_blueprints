if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")

module("bpuicreatemenu", package.seeall, bpcommon.rescope(bpschema, bpnodedef))


local PANEL = {}


local function SortedFilteredNodeList( filter, res )
	local options = {}
	for k,v in pairs(NodeTypes) do
		if filter(v) then table.insert(options, k) end
	end
	table.sort(options)
	for _, v in pairs(options) do
		res( v, NodeTypes[v] )
	end
end

local function FilterByType( filterType ) return function(n) 
		return n.type == filterType 
	end 
end

local function FilterByPinType( pinType ) return function(n) 
		for _, pin in pairs(n.pins) do 
			if pin[2] == pinType then return true end 
		end 
		return false 
	end 
end

local function FilterBySubstring( str ) return function(n)
		return string.find( n.name:lower(), str) ~= nil
	end 
end

local function CombineFilter(a,b) return function(n) return a(n) or b(n) end end

function PANEL:OnNodeTypeSelected( nodeType )

end

function PANEL:Init()

	--self:SetBackgroundColor( Color(80,80,80) )
	
	local function inserter( list )
		return function( name, nodeType )
			local c = NodeTypeColors[nodeType.type]
			local cx = Color(c.r/2, c.g/2, c.b/2, 255)
			local item = list:AddItem( name )
			item:SetFont("DermaDefaultBold")
			item:SetColor( Color(255,255,255) )
			item.DoClick = function()
				self:OnNodeTypeSelected( nodeType )
				self:Remove()
			end
			item.Paint = function( self, w, h )
				draw.RoundedBox( 0, 0, 0, w, h, cx )
				if ( self.Hovered ) then
					draw.RoundedBox( 0, 0, 0, w, h, Color( 255, 255, 255, 80 ) )
				end
			end
		end
	end

	self.inserter = inserter

	self.search = vgui.Create("DTextEntry", self)
	self.search:DockMargin(5, 5, 5, 5)
	self.search:Dock( TOP )
	self.search:RequestFocus()
	self.search:SetUpdateOnType(true)
	self.search.OnValueChange = function(te, ...) self:OnSearchTerm(...) end


	self.tabs = vgui.Create("DPropertySheet", self )
	self.tabs:DockMargin(5, 0, 5, 5)
	self.tabs:Dock( FILL )

	local list = vgui.Create("DListBox" )
	self.tabs:AddSheet( "All", list, "icon16/user.png", false, false, "All nodes" )
	SortedFilteredNodeList( function() return true end, inserter(list) )

	local list = vgui.Create("DListBox" )
	self.tabs:AddSheet( "Hooks", list, "icon16/connect.png", false, false, "Hook nodes" )
	SortedFilteredNodeList( FilterByType(NT_Event), inserter(list) )

	local list = vgui.Create("DListBox" )
	self.tabs:AddSheet( "Entity", list, "icon16/bricks.png", false, false, "Entity nodes" )
	SortedFilteredNodeList( FilterByPinType(PN_Entity), inserter(list) )

	local list = vgui.Create("DListBox" )
	self.tabs:AddSheet( "Player", list, "icon16/user.png", false, false, "Player nodes" )
	SortedFilteredNodeList( FilterByPinType(PN_Player), inserter(list) )

	local list = vgui.Create("DListBox" )
	self.tabs:AddSheet( "Special", list, "icon16/plugin.png", false, false, "Special nodes" )
	SortedFilteredNodeList( CombineFilter( FilterByType(NT_Special), FilterByPinType(PN_Any) ), inserter(list) )


	self.resultList = vgui.Create("DListBox", self )
	self.resultList:DockMargin(5, 0, 5, 5)
	self.resultList:Dock( FILL )
	self.resultList:SetVisible(false)

	self:SetWide(400)
	self:SetTall(300)

	self:SizeToContents( true, false )

end

function PANEL:OnSearchTerm( text )

	if text:len() > 0 then
		self.resultList:SetVisible(true)
		self.tabs:SetVisible(false)

		self.resultList:Clear()
		SortedFilteredNodeList( FilterBySubstring( text:lower() ), self.inserter(self.resultList) )
	else
		self.resultList:SetVisible(false)
		self.tabs:SetVisible(true)
	end

end

function PANEL:Paint(w,h)

	surface.SetDrawColor( Color(80,80,80) )
	surface.DrawRect(0,0,w,h)

end

vgui.Register( "BPCreateMenu", PANEL, "EditablePanel" )