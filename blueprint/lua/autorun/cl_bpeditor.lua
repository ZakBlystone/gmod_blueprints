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
	}

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

	self.Content:SetLeft(menu)
	self.Content:Dock( FILL )

	self.GraphList = vgui.Create("BPListView", menu)
	self.GraphList:SetText("Graphs")
	self.GraphList.HandleAddItem = function(list)
		Derma_StringRequest(
			"Add Graph",
			"Give it a name",
			"",
			function( text ) self.module:NewGraph( text ) end,
			function( text ) end
		)
	end

	self.VarList = vgui.Create("BPListView", menu)
	self.VarList:SetText("Variables")
	self.VarList.HandleAddItem = function(list)
		bpuivarcreatemenu.RequestVarSpec( function(name, type, flags) 
			self.module:NewVariable( name, type, nil, flags )
		end)
	end
	self.VarList.ItemBackgroundColor = function( list, id, item, selected )
		local vcolor = bpschema.NodePinColors[item.type]
		if selected then
			return vcolor
		else
			return Color(vcolor.r*.5, vcolor.g*.5, vcolor.b*.5)
		end
	end

	menu:SetTop(self.GraphList)
	menu:SetBottom(self.VarList)

	self.vvars = {}
	self.vgraphs = {}

end

function PANEL:Think()

	self.BaseClass.Think(self)

	local selectedGraphID = self.GraphList:GetSelectedID()

	for id, vgraph in pairs( self.vgraphs ) do
		if id == selectedGraphID then
			vgraph:SetVisible(true)
			self.Content:SetRight( vgraph )
		else
			vgraph:SetVisible(false)
		end
	end

end

function PANEL:OnRemove()

	self:SetModule(nil)

end

function PANEL:OnModuleCallback( cb, ... )

	if cb == CB_MODULE_CLEAR then self:Clear(...) end
	if cb == CB_GRAPH_ADD then self:GraphAdded(...) end
	if cb == CB_GRAPH_REMOVE then self:GraphRemoved(...) end

end

function PANEL:Clear()

	for _, v in pairs(self.vvars or {}) do v:Remove() end
	for _, v in pairs(self.vgraphs or {}) do v:Remove() end

	self.vvars = {}
	self.vgraphs = {}

end

function PANEL:GraphAdded( id )

	print("GRAPH ADDED: " .. id)
	local graph = self.module:GetGraph(id)
	local vgraph = vgui.Create("BPGraph", self.Content)

	vgraph:SetGraph( graph )
	vgraph:SetVisible(false)
	self.vgraphs[id] = vgraph

end

function PANEL:GraphRemoved( id )

	if IsValid(self.SelectedGraph) and self.SelectedGraph.id == id then
		self.SelectedGraph:SetVisible(false)
		self.SelectedGraph = nil
	end

	self.vgraphs[id]:Remove()
	self.vgraphs[id] = nil

end

function PANEL:SetModule( mod )

	if self.module then
		self.module:RemoveListener(self.callback)
	end

	self.module = mod
	self:Clear()

	if mod == nil then return end
	self.VarList:SetList( self.module.variables )
	self.GraphList:SetList( self.module.graphs )
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