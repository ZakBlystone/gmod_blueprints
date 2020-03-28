if SERVER then AddCSLuaFile() return end

module("editor_graphmodule", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.HasSideBar = true
EDITOR.CanSendToServer = true
EDITOR.CanInstallLocally = true
EDITOR.CanExportLuaScript = true

function EDITOR:Setup()

	print("SETUP GRAPH MODULE EDITOR")

	self.vvars = {}
	self.vgraphs = {}

	self:GetModule():Bind("graphAdded", self, self.GraphAdded)
	self:GetModule():Bind("graphRemoved", self, self.GraphRemoved)

end

function EDITOR:PostInit()

	for id, graph in self:GetModule().graphs:Items() do
		self:GraphAdded( id )
	end

	hook.Add("BPPinClassRefresh", "pinrefresh_" .. self:GetModule():GetUID(), function(class)
		print("PIN CLASS UPDATED, INVALIDATE: " .. class)
		for _, graph in self.module:Graphs() do
			for _, node in graph:Nodes() do
				node:UpdatePins()
			end
		end
		for _, ed in pairs( self.vgraphs ) do
			ed:GetEditor():InvalidateAllNodes( true )
		end
	end)

end

function EDITOR:Shutdown()

	for _, v in pairs(self.vvars or {}) do v:Remove() end
	for _, v in pairs(self.vgraphs or {}) do v:Remove() end

	self.vvars = {}
	self.vgraphs = {}

	self:GetModule():UnbindAll(self)
	hook.Remove("BPPinClassRefresh", "pinrefresh_" .. self:GetModule():GetUID())

end

function EDITOR:Think()

	if self.GraphList then

		local selectedGraphID = self.GraphList:GetSelectedID()

		for id, vgraph in pairs( self.vgraphs ) do
			if id == selectedGraphID then
				if not vgraph:IsVisible() then
					vgraph:SetVisible(true)
					self:SetContent( vgraph )
				end
			else
				vgraph:SetVisible(false)
			end
		end

	end

end

function EDITOR:PopulateSideBar()

	-- Graph List
	self.GraphList = self:AddSidebarList("Graphs")
	self.GraphList.HandleAddItem = function(list)

		local function MakeGraph(graphType)
			local id = self:GetModule():NewGraph( nil, graphType )
			list:Rename(id)
		end

		local menu = DermaMenu( false, self:GetPanel() )
		menu:AddOption( "Event Graph", function() MakeGraph(bpschema.GT_Event) end )
		menu:AddOption( "Function", function() MakeGraph(bpschema.GT_Function) end )
		menu:SetMinimumWidth( 100 )
		menu:Open( gui.MouseX(), gui.MouseY(), false, self:GetPanel() )

	end

	self.GraphList.ItemBackgroundColor = function( list, id, item, selected )

		local vcolor = bpschema.GraphTypeColors[item:GetType()]
		if selected then
			return vcolor
		else
			return Color(vcolor.r*.5, vcolor.g*.5, vcolor.b*.5)
		end

	end

	self.GraphList.PopulateMenuItems = function(pnl, items, id)

		local graph = self:GetModule():GetGraph(id)
		if graph.type == bpschema.GT_Function and not graph:HasFlag(bpgraph.FL_LOCK_PINS) then
			items[#items+1] = {
				name = "Edit Pins",
				func = function() bpuigrapheditmenu.EditGraphParams( graph ) end,
			}
		end

	end

	-- Variable List
	if self:GetModule():CanHaveVariables() then

		self.VarList = self:AddSidebarList("Variables")
		self.VarList.CreateItemPanel = function(pnl, id, item)

			local entry = vgui.Create("BPPinListEntry", pnl)
			entry.vlist = pnl
			entry.id = id
			entry.module = self:GetModule()
			function entry:SetPinType(t) item:SetType( t ) end
			function entry:GetPinType() return item:GetType() end
			function entry:SetPinName(n) pnl.list:Rename( id, n ) end
			function entry:GetPinName() return item.name end
			return entry

		end
		self.VarList.HandleAddItem = function(list)
			local id, item = self:GetModule():NewVariable( "", bpschema.PinType( bpschema.PN_Bool ) )
		end
		self.VarList:SetList( self:GetModule().variables )

	end

	-- Structure List
	if self:GetModule():CanHaveStructs() then

		self.StructList = self:AddSidebarList("Structs")
		self.StructList.HandleAddItem = function(pnl, list)
			local itemID, item = list:Construct()
			pnl:Rename(itemID)
		end

		self.StructList.PopulateMenuItems = function(pnl, items, id)

			items[#items+1] = {
				name = "Edit Struct",
				func = function() bpuistructeditmenu.EditStructParams( self:GetModule():GetStruct(id) ) end,
			}

		end
		self.StructList:SetList( self:GetModule().structs )

	end

	-- Event List
	if self:GetModule():CanHaveEvents() then

		self.EventList = self:AddSidebarList("Events")
		self.EventList.HandleAddItem = function(pnl, list)
			local itemID, item = list:Construct()
			pnl:Rename(itemID)
		end

		self.EventList.PopulateMenuItems = function(pnl, items, id)

			items[#items+1] = {
				name = "Edit Event",
				func = function() bpuistructeditmenu.EditEventParams( self:GetModule():GetEvent(id) ) end,
			}

		end
		self.EventList:SetList( self:GetModule().events )

	end

	self.GraphList:SetList( self:GetModule().graphs )

end

function EDITOR:GraphAdded( id )

	local graph = self:GetModule():GetGraph(id)
	local vgraph = vgui.Create("BPGraph", self.Content)

	vgraph:SetGraph( graph )
	vgraph:SetVisible(false)
	vgraph:CenterToOrigin()
	self.vgraphs[id] = vgraph

end

function EDITOR:GraphRemoved( id )

	if IsValid(self.SelectedGraph) and self.SelectedGraph.id == id then
		self.SelectedGraph:SetVisible(false)
		self.SelectedGraph = nil
	end

	self.vgraphs[id]:Remove()
	self.vgraphs[id] = nil

end

function EDITOR:HandleError( errorData )

	local vgraph = self.vgraphs[ errorData.graphID ]
	if not vgraph then return end

	local edit = vgraph:GetEditor()
	local nodeset = edit:GetNodeSet()
	local vnode = nodeset:GetVNodes()[ errorData.nodeID ]

	self.GraphList:Select( errorData.graphID )

	if vnode then
		local x,y = vnode:GetPos()
		local w,h = vnode:GetSize()
		vgraph:SetZoomLevel(0,x,y)
		timer.Simple(0, function()
			vgraph:CenterOnPoint(x + w/2,y + h/2)
		end)
	end

end

RegisterModuleEditorClass("graphmodule", EDITOR, "basemodule")