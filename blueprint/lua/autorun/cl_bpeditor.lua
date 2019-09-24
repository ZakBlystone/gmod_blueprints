if SERVER then AddCSLuaFile() return end

include("cl_bpnode.lua")
include("cl_bppin.lua")
include("sh_bpmodule.lua")

module("bpuieditor", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}
local TITLE = "Blueprint Editor"

function PANEL:Init()

	local w = ScrW() * .8
	local h = ScrH() * .8
	local x = (ScrW() - w)/2
	local y = (ScrH() - h)/2

	local MenuOptions = {
		{"New Module", function(p)
			p:SetModule( bpmodule.New() )
		end},
		{"New Graph", function(p)
			local m = p:GetModule()
			if m ~= nil then
				Derma_StringRequest(
					"New Graph",
					"What to call it?",
					"",
					function( text ) 

						m:NewGraph(text)

					end,
					function( text ) end
				)				
			end
		end},
		{"Save", function()
			Derma_StringRequest(
				"Save Blueprint",
				"What filename though?",
				"",
				function( text ) 

					local outStream = bpdata.OutStream()
					self.module:WriteToStream(outStream)
					outStream:WriteToFile("blueprints/bpm_" .. text .. ".txt", true, true)

				end,
				function( text ) end
			)
		end},
		{"Load", function()
			Derma_StringRequest(
				"Load Blueprint",
				"What filename though?",
				"",
				function( text ) 

					if file.Exists("blueprints/bpm_" .. text .. ".txt", "DATA") then
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
		end},
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
			local b,e = pcall( v[2], self )
			if not b then
				self.StatusText:SetTextColor( Color(255,100,100) )
				self.StatusText:SetText(e)
			else
				self.StatusText:SetTextColor( Color(255,255,255) )
				self.StatusText:SetText("")
			end
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


	self.Content = vgui.Create("DHorizontalDivider", self)
	self.Content:Dock( FILL )

	self.MenuPanel = vgui.Create("DPanel", self.Content)
	self.GraphList = vgui.Create("DListBox", self.MenuPanel)
	self.GraphList:Dock( FILL )

	self.Content:SetLeft(self.MenuPanel)
	self.Content:Dock( FILL )

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

function PANEL:OnModuleCallback( cb, ... )

	print("CB: " .. cb)

	if cb == CB_MODULE_CLEAR then self:Clear(...) end
	if cb == CB_GRAPH_ADD then self:GraphAdded(...) end
	if cb == CB_GRAPH_REMOVE then self:GraphRemoved(...) end
	if cb == CB_GRAPH_REMAP then self:GraphRemap(...) end

end

function PANEL:BuildGraphList()

	self.GraphList:Clear()

	if self.module == nil then return end
	for i=1, self.module:GetNumGraphs() do

		local graph = self.module:GetGraph(i)
		local item = self.GraphList:AddItem( graph:GetTitle() )
		item:SetFont("DermaDefaultBold")
		--item:SetColor( Color(255,255,255) )
		item.DoClick = function()
			self:SelectGraph(i)
		end
		--item.Paint = function( self, w, h )end

	end

end

function PANEL:Clear()

	for _, v in pairs(self.vgraphs or {}) do
		v:Remove()
	end

	self.vgraphs = {}
	self:BuildGraphList()

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

function PANEL:GraphRemap( graph, oldID, newID )

	self.vgraphs[oldID].id = newID

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

	--bpnet.DownloadServerModule( mod )
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