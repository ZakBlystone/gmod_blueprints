if SERVER then AddCSLuaFile() return end

include("cl_bpnode.lua")
include("cl_bppin.lua")
include("cl_bpvarcreatemenu.lua")
include("sh_bpschema.lua")
include("sh_bpmodule.lua")

module("bpuieditor", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}
local TITLE = "Blueprint Editor"

LastSavedFile = nil

function PANEL:Init()

	local w = ScrW() * .8
	local h = ScrH() * .8
	local x = (ScrW() - w)/2
	local y = (ScrH() - h)/2

	local SaveFunc = function( text ) 
		local outStream = bpdata.OutStream()
		self.module:WriteToStream(outStream)
		outStream:WriteToFile("blueprints/bpm_" .. text .. ".txt", true, true)
		LastSavedFile = text
	end

	local MenuOptions = {
		{"New Module", function(p)
			LastSavedFile = nil
			p:SetModule( bpmodule.New() )
		end},
		{"Save", function()

			if LastSavedFile ~= nil then

				Derma_Query("Overwrite " .. LastSavedFile .. "?",
							"Save File",
							"Yes",
							function() 
								SaveFunc( LastSavedFile )
							end,
							"No",
							function() 

								Derma_StringRequest( "Save Blueprint", "What filename though?", "", SaveFunc, function( text ) end )

							end)

				return

			end

			Derma_StringRequest( "Save Blueprint", "What filename though?", "", SaveFunc, function( text ) end )
		end},
		{"Load", function()
			Derma_StringRequest(
				"Load Blueprint",
				"What filename though?",
				"",
				function( text ) 

					if file.Exists("blueprints/bpm_" .. text .. ".txt", "DATA") then
						LastSavedFile = text
						local inStream = bpdata.InStream()
						inStream:LoadFile("blueprints/bpm_" .. text .. ".txt", true, true)
						self.module:ReadFromStream( inStream )
					end

				end,
				function( text ) end
			)
		end},
		{"Compile and upload", function()
			bpnet.SendModule( self.module )

			if LastSavedFile then
				SaveFunc( LastSavedFile )
			end
		end},
		--[[{"Test Reroute collapse", function()

			self.module:GetGraph( 1 ):CollapseRerouteNodes()

		end}]]
	}

	--x = 20

	self.callback = function(...)
		self:OnModuleCallback(...)
	end

	self.fullScreen = false
	self.btnMaxim:SetDisabled(false)
	self.btnMaxim.DoClick = function ( button )
		self.fullScreen = not self.fullScreen
		if self.fullScreen then
			self.px, self.py = self:GetPos()
			self.pw, self.ph = self:GetSize()
			self:SetPos(0,0)
			self:SetSize(ScrW(), ScrH())
			self:SetDraggable(false)
			self:SetSizable(false)
		else
			self:SetPos(self.px,self.py)
			self:SetSize(self.pw,self.ph)
			self:SetDraggable(true)
			self:SetSizable(true)
		end
	end

	self:SetPos(x, y)
	self:SetSize(w, h)

	self:SetMouseInputEnabled( true )
	self:SetTitle( TITLE )
	self:SetDraggable(true)
	self:SetSizable(true)
	self:ShowCloseButton(true)

	self.Menu = vgui.Create("DPanel", self)
	self.Menu:Dock( TOP )
	self.Menu:SetBackgroundColor( Color(80,80,80) )

	local optX = 0
	for k,v in pairs(MenuOptions) do
		local opt = vgui.Create("DButton", self.Menu)
		opt:SetPos(optX, 0)
		opt:SetText(v[1])
		opt:SizeToContentsX()
		opt:SetWide( opt:GetWide() + 10 )
		opt:SetTall( 25 )
		opt.DoClick = function(btn)
			self.StatusText:SetTextColor( Color(255,255,255) )
			self.StatusText:SetText("")

			local b = xpcall( v[2], function( err )
				self.StatusText:SetTextColor( Color(255,100,100) )
				self.StatusText:SetText( err )
				print( debug.traceback() )
			end, self )
		end
		optX = optX + opt:GetWide() + 2
	end

	self.Menu:SizeToChildren( true, true )

	self.Status = vgui.Create("DPanel", self)
	self.Status:Dock( BOTTOM )
	self.Status:SetBackgroundColor( Color(50,50,50) )

	self.StatusText = vgui.Create("DLabel", self.Status)
	self.StatusText:SetFont("DermaDefaultBold")
	self.StatusText:Dock( FILL )
	self.StatusText:SetText("")

	if _G.G_BPError ~= nil then
		self.StatusText:SetText( "Blueprint Error: " .. _G.G_BPError.msg )
	end

	self.ContentPanel = vgui.Create("DPanel", self)
	self.ContentPanel:Dock( FILL )
	self.ContentPanel:SetBackgroundColor( Color(50,50,50) )

	self.Content = vgui.Create("DHorizontalDivider", self.ContentPanel)
	self.Content:Dock( FILL )
	self.Content:SetBackgroundColor( Color(30,30,30) )

	local menu = vgui.Create("DVerticalDivider", self.Content)
	menu:SetTopHeight(300)

	self.VarMenuPanel = vgui.Create("DPanel", menu)
	self.VarMenuPanel:SetBackgroundColor( Color(30,30,30) )

	self.GraphMenuPanel = vgui.Create("DPanel", menu)
	self.GraphMenuPanel:SetBackgroundColor( Color(30,30,30) )

	self.VarListControls = vgui.Create("DPanel", self.VarMenuPanel)
	self.VarAdd = vgui.Create("DButton", self.VarListControls)
	self.VarRemove = vgui.Create("DButton", self.VarListControls)

	self.VarAdd:SetText("+")
	self.VarRemove:SetText("-")

	self.VarAdd:Dock( LEFT )
	self.VarRemove:Dock( FILL )
	self.VarListControls:Dock( TOP )

	self.VarAdd.DoClick = function()
		--[[Derma_StringRequest(
			"Add Graph",
			"Give it a name",
			"",
			function( text ) 

				self.module:NewVariable( text )

			end,
			function( text ) end
		)]]
		bpuivarcreatemenu.RequestVarSpec( function(name, type, flags) 
			self.module:NewVariable( name, type, nil, flags )
		end)
	end

	self.VarRemove.DoClick = function()
		if IsValid(self.SelectedVar) then
			self.module:RemoveVariable(self.SelectedVar.id)
		end
	end

	self.GraphListControls = vgui.Create("DPanel", self.GraphMenuPanel)
	self.GraphAdd = vgui.Create("DButton", self.GraphListControls)
	self.GraphRemove = vgui.Create("DButton", self.GraphListControls)

	self.GraphAdd:SetText("+")
	self.GraphRemove:SetText("-")

	self.GraphAdd:Dock( LEFT )
	self.GraphRemove:Dock( FILL )
	self.GraphListControls:Dock( TOP )

	self.GraphAdd.DoClick = function()
		Derma_StringRequest(
			"Add Graph",
			"Give it a name",
			"",
			function( text ) 

				self.module:NewGraph( text )

			end,
			function( text ) end
		)
	end

	self.GraphRemove.DoClick = function()
		if IsValid(self.SelectedGraph) then
			self.module:RemoveGraph(self.SelectedGraph.id)
		end
	end

	self.VarList = vgui.Create("DListBox", self.VarMenuPanel)
	self.VarList:Dock( FILL )
	self.VarList.Paint = function( p, w, h ) end

	self.GraphList = vgui.Create("DListBox", self.GraphMenuPanel)
	self.GraphList:Dock( FILL )
	self.GraphList.Paint = function( p, w, h ) end

	self.Content:SetLeft(menu)
	self.Content:Dock( FILL )

	menu:SetTop(self.GraphMenuPanel)
	menu:SetBottom(self.VarMenuPanel)

	self.vvars = {}
	self.vgraphs = {}

	--self.VarMenuPanel:Dock( FILL )
	--self.GraphMenuPanel:Dock( FILL )

end

function PANEL:OnRemove()

	self:SetModule(nil)

end

function PANEL:SelectGraph(id)

	if IsValid(self.SelectedGraph) then self.SelectedGraph:SetVisible(false) end
	self.SelectedGraph = self.vgraphs[id]
	self.SelectedGraph:SetVisible( true )
	self.Content:SetRight( self.SelectedGraph )

end

function PANEL:SelectVar(id)

	if IsValid(self.SelectedVar) then self.SelectedVar:SetVisible(false) end
	self.SelectedVar = self.vvars[id]
	--self.SelectedVar:SetVisible( true )
	--self.Content:SetRight( self.SelectedVar )

end

function PANEL:OnModuleCallback( cb, ... )

	print("CB: " .. cb)

	if cb == CB_MODULE_CLEAR then self:Clear(...) end
	if cb == CB_GRAPH_ADD then self:GraphAdded(...) end
	if cb == CB_GRAPH_REMOVE then self:GraphRemoved(...) end
	if cb == CB_VARIABLE_ADD then self:VarAdded(...) end
	if cb == CB_VARIABLE_REMOVE then self:VarRemoved(...) end

end

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

function PANEL:Clear()

	for _, v in pairs(self.vvars or {}) do v:Remove() end
	for _, v in pairs(self.vgraphs or {}) do v:Remove() end

	self.vvars = {}
	self.vgraphs = {}
	self:BuildGraphList()
	self:BuildVarList()

end

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

function PANEL:SetModule( mod )

	if self.module then
		self.module:RemoveListener(self.callback)
	end

	self.module = mod
	self:Clear()

	if mod == nil then return end
	self.module:AddListener(self.callback, bpmodule.CB_ALL)

end

function PANEL:GetModule()

	return self.module

end

vgui.Register( "BPEditor", PANEL, "DFrame" )


--if true then return end

local function OpenEditor()


	if G_BPEditorInstance then

		if IsValid(G_BPEditorInstance) then G_BPEditorInstance:Remove() end
		G_BPEditorInstance = nil

	end

	local graph = bpgraph.New()

	--for i=1, 2 do
	local editor = vgui.Create( "BPEditor" )
	editor:SetVisible(true)
	editor:MakePopup()
	--end

	local mod = bpmodule.New()
	editor:SetModule(mod)
	--mod:CreateTestModule()

	bpnet.DownloadServerModule( mod )
	--graph:CreateTestGraph()
	--graph:RemoveNode( graph.nodes[1] )

	G_BPEditorInstance = editor

end

concommand.Add("open_blueprint", function()

end)

hook.Add("PlayerBindPress", "catch_f2", function(ply, bind, pressed)

	if bind == "gm_showteam" then
		OpenEditor()
	end

end)