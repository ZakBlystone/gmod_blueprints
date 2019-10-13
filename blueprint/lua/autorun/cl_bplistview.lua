if SERVER then AddCSLuaFile() return end

include("sh_bpcommon.lua")

module("bpuilistview", package.seeall)

local PANEL = {}

function PANEL:OnItemSelected( id, item )

end

function PANEL:ItemBackgroundColor( id, item, selected )

	return selected and Color(80,80,80,255) or Color(50,50,50,255)

end

function PANEL:CreateItemPanel( id, item )

	local panel = vgui.Create("DPanel")
	panel:SetMouseInputEnabled( true )

	local btn = vgui.Create("DLabel", panel)
	btn:SetTextColor( Color(255,255,255) )
	btn:SetFont("DermaDefaultBold")
	btn:SetText( item:GetName() )
	btn:DockMargin( 8,0,2,0 )
	btn:Dock( FILL )

	local rmv = vgui.Create("DButton", panel)
	rmv:SetWide(18)
	rmv:SetTextColor( Color(255,255,255) )
	rmv:SetText("X")
	rmv:SetDrawBorder(false)
	rmv:SetPaintBackground(false)
	rmv:Dock( RIGHT )

	panel:SetTall(20)

	panel.OnMousePressed = function( pnl, code )
		if code == MOUSE_LEFT then
			self:Select(id)
		end
	end

	panel.Paint = function( pnl, w, h )

		local col = self:ItemBackgroundColor(id, item, self.selectedID == id)
		surface.SetDrawColor( col )
		surface.DrawRect(0,0,w,h)

	end

	rmv.DoClick = function( pnl )

		Derma_Query("Delete " .. item:GetName() .. "? This cannot be undone",
		"",
		"Yes",
		function() 
			self.list:Remove( id )
		end,
		"No",
		function() end)

	end

	return panel

end

function PANEL:HandleAddItem()

end

function PANEL:SetList( list )

	self:Clear()

	if self.list then self.list:RemoveListener(self.callback) end
	self.list = list
	self.list:AddListener(self.callback, bplist.CB_ALL)

end

function PANEL:OnListCallback(cb, ...)

	if cb == bplist.CB_ADD then self:ItemAdded(...) end
	if cb == bplist.CB_REMOVE then self:ItemRemoved(...) end
	if cb == bplist.CB_CLEAR then self:Clear() end

end

function PANEL:ItemAdded(id, item)

	local panel = self:CreateItemPanel( id, item )
	if panel == nil then return end

	self.listview:AddItem( panel )

	self.vitems[id] = panel

	if self.selectedID == nil then
		self.selectedID = id
		self:OnItemSelected( id, item )
	end

	self.selectedID = id

end

function PANEL:Select(id)

	if self.selectedID ~= id then
		self.selectedID = id
		self:OnItemSelected( id, id and self.list:Get(id) or nil )
	end

end

function PANEL:GetSelectedID()

	return self.selectedID

end

function PANEL:ItemRemoved(id, item)

	local panel = self.vitems[id]
	if panel ~= nil then
		self.listview:RemoveItem( panel )
		self.vitems[id] = nil
	end

	if self:GetSelectedID() == id then
		self:Select(nil)
	end

end

function PANEL:Clear()

	for _, v in pairs(self.vitems) do
		self.listview:RemoveItem( v )
	end
	self.vitems = {}

end

function PANEL:SetText(text)

	self.label:SetText( text )

end

function PANEL:Init()

	self:SetBackgroundColor( Color(30,30,30) )
	self.callback = function(...) self:OnListCallback(...) end
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
		self:HandleAddItem()
	end

	self.selectedID = nil
	self.listview = vgui.Create("DPanelList", self)
	self.listview:Dock( FILL )
	self.listview.Paint = function() end

--	self.VarMenuPanel:SetBackgroundColor( Color(30,30,30) )
--[[
	self.VarListControls = vgui.Create("DPanel", self.VarMenuPanel)
	self.VarAdd = vgui.Create("DButton", self.VarListControls)
	self.VarRemove = vgui.Create("DButton", self.VarListControls)

	self.VarAdd:SetText("+")
	self.VarRemove:SetText("-")

	self.VarAdd:Dock( LEFT )
	self.VarRemove:Dock( FILL )
	self.VarListControls:Dock( TOP )
]]

--[[
	self.VarAdd.DoClick = function()
		bpuivarcreatemenu.RequestVarSpec( function(name, type, flags) 
			self.module:NewVariable( name, type, nil, flags )
		end)
	end

	self.VarRemove.DoClick = function()
		if IsValid(self.SelectedVar) then
			self.module:RemoveVariable(self.SelectedVar.id)
		end
	end
]]

--[[
	self.VarList = vgui.Create("DListBox", self.VarMenuPanel)
	self.VarList:Dock( FILL )
	self.VarList.Paint = function( p, w, h ) end
]]
end

--[[
function PANEL:BuildVarList()

	self.VarList:Clear()

	if self.module == nil then return end
	for id, var in self.module:Variables() do

		local item = self.VarList:AddItem( var.name )
		item:SetFont("DermaDefaultBold")
		item:SetTextColor( Color(255,255,255) )
		item.varID = id
		item.OnMousePressed = function( item, mcode )
			if ( mcode == MOUSE_LEFT ) then item:Select( true ) end
		end
		item.DoClick = function()
			self:SelectVar(id)
		end
		item.Paint = function( item, w, h )
			local var = self.module:GetVariable(item.varID)
			local vcolor = bpschema.NodePinColors[var.type]
			if self.SelectedVar and item.varID == self.SelectedVar.id then
				surface.SetDrawColor(vcolor)
			else
				surface.SetDrawColor(Color(vcolor.r*.5, vcolor.g*.5, vcolor.b*.5))
			end
			surface.DrawRect(0,0,w,h)
		end

	end

end

function PANEL:BuildGraphList()

	self.GraphList:Clear()

	if self.module == nil then return end
	for id, graph in self.module:Graphs() do

		local item = self.GraphList:AddItem( graph:GetTitle() )
		item:SetFont("DermaDefaultBold")
		item:SetTextColor( Color(255,255,255) )
		item.graphID = id
		item.OnMousePressed = function( item, mcode )
			if ( mcode == MOUSE_LEFT ) then item:Select( true ) end
		end
		item.DoClick = function()
			self:SelectGraph(id)
		end
		item.Paint = function( item, w, h )
			if self.SelectedGraph and item.graphID == self.SelectedGraph.id then
				surface.SetDrawColor(120,120,120,255)
			else
				surface.SetDrawColor(60,60,60,255)
			end
			surface.DrawRect(0,0,w,h)
		end

	end

end
]]

--[[
function PANEL:GraphAdded( id )

	local graph = self.module:GetGraph(id)
	local vgraph = vgui.Create("BPGraph", self.Content)

	vgraph:SetGraph( graph )
	vgraph:SetVisible(false)

	vgraph.id = id
	self.vgraphs[id] = vgraph
	self:SelectGraph(id)
	self:BuildGraphList()

end

function PANEL:GraphRemoved( id )

	if IsValid(self.SelectedGraph) and self.SelectedGraph.id == id then
		self.SelectedGraph:SetVisible(false)
		self.SelectedGraph = nil
	end

	self.vgraphs[id]:Remove()
	self.vgraphs[id] = nil

	self:BuildGraphList()

end

function PANEL:VarAdded( id )

	local var = self.module:GetVariable(id)
	local vvar = vgui.Create("DPanel", self.Content)

	vvar:SetVisible(false)
	vvar.id = id

	self.vvars[id] = vvar
	self:SelectVar(id)
	self:BuildVarList()

end

function PANEL:VarRemoved( id )

	if IsValid(self.SelectedVar) and self.SelectedVar.id == id then
		self.SelectedVar:SetVisible(false)
		self.SelectedVar = nil
	end

	self.vvars[id]:Remove()
	self.vvars[id] = nil

	self:BuildVarList()

end
]]

vgui.Register( "BPListView", PANEL, "DPanel" )