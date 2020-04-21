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
		for _, graph in self:GetModule():Graphs() do
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

	if _G.G_BPDraggingElement then

		if not input.IsMouseDown( MOUSE_LEFT ) then
			_G.G_BPDraggingElement = nil
		end

	end

end

function EDITOR:PopulateSideBar()

	-- Graph List
	self.GraphList = self:AddSidebarList(LOCTEXT("editor_graphmodule_graphlist","Graphs"))
	self.GraphList.HandleAddItem = function(list)

		local function MakeGraph(graphType)
			local id = self:GetModule():NewGraph( nil, graphType )
			list:Rename(id)
		end

		local menu = DermaMenu( false, self:GetPanel() )
		menu:AddOption( LOCTEXT("editor_graphmodule_add_eventgraph", "Event Graph")(), function() MakeGraph(bpschema.GT_Event) end )
		menu:AddOption( LOCTEXT("editor_graphmodule_add_function", "Function")(), function() MakeGraph(bpschema.GT_Function) end )
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
				name = LOCTEXT("editor_graphmodule_editgraphpins","Edit Pins"),
				func = function() bpuigrapheditmenu.EditGraphParams( graph ) end,
			}
		end

	end

	local detour = self.GraphList.CreateItemPanel
	self.GraphList.CreateItemPanel = function(pnl, id, item)
		local p = detour(pnl, id, item)

		if item:GetType() == GT_Function then
			local detour = p.OnMousePressed
			p.OnMousePressed = function( pnl, code )
				if code ~= MOUSE_LEFT then detour(pnl, code) end
				pnl.wantDrag = true
			end
			p.OnMouseReleased = function( pnl, code )
				if code == MOUSE_LEFT then detour(pnl, code) end
				pnl.wantDrag = false
			end
			p.OnCursorExited = function(pnl)
				if pnl.wantDrag then
					_G.G_BPDraggingElement = item
					pnl.wantDrag = false
				end
			end
		end
		return p
	end

	-- Variable List
	if self:GetModule():CanHaveVariables() then

		self.VarList = self:AddSidebarList(LOCTEXT("editor_graphmodule_variablelist","Variables"))
		self.VarList.CreateItemPanel = function(pnl, id, item)

			local entry = vgui.Create("BPPinListEntry", pnl)
			entry.vlist = pnl
			entry.id = id
			entry.module = self:GetModule()
			function entry:SetPinType(t) item:SetType( t ) end
			function entry:GetPinType() return item:GetType() end
			function entry:SetPinName(n) pnl.list:Rename( id, n ) end
			function entry:GetPinName() return item.name end
			local detour = entry.OnMousePressed
			entry.OnMousePressed = function( pnl, code )
				detour(pnl, code)
				pnl.wantDrag = true
			end
			entry.OnMouseReleased = function( pnl, code )
				pnl.wantDrag = false
			end
			entry.OnCursorExited = function(pnl)
				timer.Simple(.05, function()
					if pnl.wantDrag then
						_G.G_BPDraggingElement = item
						pnl.wantDrag = false
					end
				end)
			end
			return entry

		end
		self.VarList.HandleAddItem = function(list)
			local id, item = self:GetModule():NewVariable( "", bppintype.New( bpschema.PN_Bool ) )
		end
		self.VarList:SetList( self:GetModule().variables )

	end

	-- Structure List
	if self:GetModule():CanHaveStructs() then

		self.StructList = self:AddSidebarList(LOCTEXT("editor_graphmodule_structlist","Structs"))
		self.StructList.HandleAddItem = function(pnl, list)
			local itemID, item = list:Construct()
			pnl:Rename(itemID)
		end

		local detour = self.StructList.CreateItemPanel
		self.StructList.CreateItemPanel = function(pnl, id, item)
			local p = detour(pnl, id, item)
			local detour = p.OnMousePressed
			p.OnMousePressed = function( pnl, code )
				detour(pnl, code)
				_G.G_BPDraggingElement = item
			end
			return p
		end

		self.StructList.PopulateMenuItems = function(pnl, items, id)

			items[#items+1] = {
				name = LOCTEXT("editor_graphmodule_editstruct","Edit Struct"),
				func = function() bpuistructeditmenu.EditStructParams( self:GetModule():GetStruct(id) ) end,
			}

		end
		self.StructList:SetList( self:GetModule().structs )

	end

	-- Event List
	if self:GetModule():CanHaveEvents() then

		self.EventList = self:AddSidebarList(LOCTEXT("editor_graphmodule_eventlist","Events"))
		self.EventList.HandleAddItem = function(pnl, list)
			local itemID, item = list:Construct()
			pnl:Rename(itemID)
		end

		local detour = self.EventList.CreateItemPanel
		self.EventList.CreateItemPanel = function(pnl, id, item)
			local p = detour(pnl, id, item)
			local detour = p.OnMousePressed
			p.OnMousePressed = function( pnl, code )
				detour(pnl, code)
				_G.G_BPDraggingElement = item
			end
			return p
		end

		self.EventList.PopulateMenuItems = function(pnl, items, id)

			items[#items+1] = {
				name = LOCTEXT("editor_graphmodule_editevent","Edit Event"),
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