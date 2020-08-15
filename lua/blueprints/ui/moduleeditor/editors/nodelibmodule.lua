if SERVER then AddCSLuaFile() return end

module("editor_nodelib", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.HasSideBar = true
EDITOR.HasDetails = true
EDITOR.CanExportLuaScript = true
--EDITOR.CanInstallLocally = true
--EDITOR.CanExportLuaScript = true

local nodeGroupTypeColors = {
	[bpnodetypegroup.TYPE_Lib] = Color(60,80,150),
	[bpnodetypegroup.TYPE_Class] = Color(60,150,80),
	[bpnodetypegroup.TYPE_Hooks] = Color(120,80,80),
}

function EDITOR:PopulateSideBar()

	self.GroupList = self:AddSidebarList(LOCTEXT("editor_nodelib_grouplist","Groups"))
	self.GroupList.HandleAddItem = function(pnl, list)

		local function MakeGroup(groupType)
			local newGroup = bpnodetypegroup.New(groupType)
			local id = list:Add(newGroup)
			pnl:Rename(id)
		end

		local menu = DermaMenu( false, self:GetPanel() )
		menu:AddOption( "Library", function() MakeGroup(bpnodetypegroup.TYPE_Lib) end )
		menu:AddOption( "Class", function() MakeGroup(bpnodetypegroup.TYPE_Class) end )
		menu:AddOption( "Hooks", function() MakeGroup(bpnodetypegroup.TYPE_Hooks) end )
		menu:SetMinimumWidth( 100 )
		menu:Open( gui.MouseX(), gui.MouseY(), false, self:GetPanel() )

	end

	self.GroupList.ItemBackgroundColor = function( list, item, selected )

		local vcolor = nodeGroupTypeColors[item:GetType()]
		if selected then
			return vcolor
		else
			return Color(vcolor.r*.5, vcolor.g*.5, vcolor.b*.5)
		end

	end

	self.NodeList = self:AddSidebarList(LOCTEXT("editor_nodelib_nodelist","Nodes"))
	self.NodeList.HandleAddItem = function(pnl, list)

		if list == nil then return end
		local newNode = bpnodetype.New():WithOuter( self.selectedGroup )

		if self.selectedGroup:GetType() == bpnodetypegroup.TYPE_Hooks then
			newNode:SetCodeType( NT_Event )
		else
			newNode:SetCodeType( NT_Function )
		end

		newNode:SetName("untitled")
		local id = list:Add( newNode )
		pnl:Rename(id)

	end

	self.StructList = self:AddSidebarList(LOCTEXT("editor_nodelib_structlist","Structs"))
	self.StructList.HandleAddItem = function(pnl, list)
		local itemID, item = list:Construct()
		item.pins:PreserveNames(true)
		pnl:Rename(itemID)
	end

	self.StructList.PopulateMenuItems = function(pnl, items, struct)

		items[#items+1] = {
			name = LOCTEXT("editor_graphmodule_editstruct","Edit Struct"),
			func = function() bpuistructeditmenu.EditStructParams( struct ) end,
		}

	end

	self.GroupList:SetList( self:GetModule().groups )
	self.StructList:SetList( self:GetModule().structs )

	for _, struct in self:GetModule().structs:Items() do
		struct.pins:PreserveNames(true)
	end

	self.selectedGroup = nil
	self.selectedNode = nil

	self.pinLists = {}

end

function EDITOR:Setup()

	local mod = self:GetModule()
	self.graph = bpgraph.New():WithOuter(mod)
	self.graph:SetName("Node Preview")
	self.graph.CanAddNode = function() return true end

	mod.groups:Bind("postModify", self, self.PostGroupListModify)

end

function EDITOR:Shutdown()

	local mod = self:GetModule()

	mod.groups:UnbindAll(self)
	if self.selectedGroup then self.selectedGroup:GetEntries():UnbindAll(self) end

end

function EDITOR:MakePinListUI( name, dir, nodeType )

	name = tostring(name)

	self.pinLists[dir] = self.pinLists[dir] or bplist.New(bppin_meta):NamedItems(name):WithOuter(self):Indexed(false)

	local editor = self
	local view = vgui.Create("BPListPanel")
	local list = self.pinLists[dir]
	local module = self:GetModule()

	list:UnbindAll(self)
	list:Clear()
	list:BindRaw("removed", self, function() editor:ApplyPins( nodeType ) end)

	for _, v in ipairs(nodeType:GetRawPins()) do
		if v:GetDir() == dir and not v:IsType(PN_Exec) then
			list:Add(v)
		end
	end

	local cat = self.sideBar:Add( tostring(name) )
	cat:SetContents( view )
	local add = cat:CreateAddButton()
	add.DoClick = function() view:InvokeAdd() end

	view.HandleAddItem = function(pnl)
		local id, item = list:Add( MakePin( dir, nil, PN_Bool, PNF_None, nil ), name )
	end
	view.CreateItemPanel = function(pnl, id, item)
		local entry = vgui.Create("BPPinListEntry", pnl)
		entry.vlist = pnl
		entry.item = item
		entry.module = module
		function entry:SetPinType(t) item:SetType( t ) editor:ApplyPins( nodeType ) end
		function entry:GetPinType() return item:GetType() end
		function entry:SetPinName(n) pnl.list:Rename( item, n ) editor:ApplyPins( nodeType ) end
		function entry:GetPinName() return item.name end
		return entry
	end
	view:SetList( list )
	view:SetText( name )
	view:SetNoConfirm()

end

function EDITOR:ApplyPins( nodeType )

	nodeType.pins = {}

	for _, v in self.pinLists[PD_In]:Items() do
		nodeType.pins[#nodeType.pins+1] = v
	end

	for _, v in self.pinLists[PD_Out]:Items() do
		nodeType.pins[#nodeType.pins+1] = v
	end

	 self:ConstructNode( nodeType )

end

function EDITOR:SetupNodeDetails( nodeType )

	if IsValid(self.sideBar) then self.sideBar:Remove() end

	self.values = bpvaluetype.FromValue({}, function() return {} end)

	if nodeType ~= nil then
		self.values:AddCosmeticChild("name",
			bpvaluetype.New("string", 
				function() return nodeType:GetName() end,
				function(x) nodeType:SetName(x) end ):SetFlag( bpvaluetype.FL_READONLY )
		)
		self.values:AddCosmeticChild("role",
			bpvaluetype.New("enum", 
				function() return nodeType:GetRole() end,
				function(x) nodeType:SetRole(x) end ):SetOptions(
				{
					{"Shared", ROLE_Shared},
					{"Server", ROLE_Server},
					{"Client", ROLE_Client},
				})
		)

		if nodeType:GetContext() == bpnodetype.NC_Lib or nodeType:GetContext() == bpnodetype.NC_Class then
			self.values:AddCosmeticChild("pure",
				bpvaluetype.New("boolean", 
					function() return nodeType:GetCodeType() == NT_Pure end,
					function(x) nodeType:ClearFlag( NTF_Compact ) nodeType:SetCodeType( x and NT_Pure or NT_Function ) end )
				:BindAny(self, function() self:ConstructNode( nodeType ) end )
			)
		end

		self.values:AddCosmeticChild("obsolete",
			bpvaluetype.New("boolean", 
				function() return nodeType:HasFlag( NTF_Deprecated ) end,
				function(x) if x then nodeType:SetFlag( NTF_Deprecated ) else nodeType:ClearFlag( NTF_Deprecated ) end end )
			:BindAny(self, function() self:ConstructNode( nodeType ) end )
		)

		self.values:AddCosmeticChild("experimental",
			bpvaluetype.New("boolean", 
				function() return nodeType:HasFlag( NTF_Experimental ) end,
				function(x) if x then nodeType:SetFlag( NTF_Experimental ) else nodeType:ClearFlag( NTF_Experimental ) end end )
			:BindAny(self, function() self:ConstructNode( nodeType ) end )
		)

		self.sideBar = vgui.Create("BPCategoryList")
		self.detailGUI = self.values:CreateVGUI({ live = true, })
		self.sideBar:Add( "Details" ):SetContents( self.detailGUI )
		self:MakePinListUI( "Inputs", PD_In, nodeType )
		self:MakePinListUI( "Outputs", PD_Out, nodeType )

		self:SetDetails( self.sideBar )

	end

end

function EDITOR:PostInit()

	self.vgraph = vgui.Create("BPGraph")
	self.vgraph:SetGraph(self.graph)
	self:SetContent( self.vgraph )

end

function EDITOR:MakeVNode(node)

	if not node then return end
	local vnode = bpuigraphnode.New( node, self.graph )
	return vnode

end

function EDITOR:AddNode( nodeType, x, y )

	local _, node = self.graph:AddNode( nodeType, x or 0, y or 0 )
	local vnode = self:MakeVNode(node)
	return node, vnode

end

function EDITOR:ConstructNode( nodeType )

	self.graph:Clear()
	if nodeType ~= nil then
		if nodeType:GetCodeType() == NT_Event and nodeType:ReturnsValues() then

			self.graph.inputs:Clear()
			self.graph.outputs:Clear()
			for _, v in ipairs(nodeType:GetRawPins()) do
				if v:IsType(PN_Exec) then continue end
				v = v:Copy( v:IsIn() and PD_Out or PD_In ) v.id = nil
				if v:GetDir() == PD_In then self.graph.inputs:Add(v) end
				if v:GetDir() == PD_Out then self.graph.outputs:Add(v) end
			end

			local entry = bpnodetype.New():WithOuter( self.graph )
			entry:SetCodeType(NT_FuncInput)
			entry:SetName(nodeType:GetName())
			entry:AddFlag(NTF_NoDelete)
			entry:SetNodeClass("UserFuncEntry")
			entry.GetRole = function() return nodeType:GetRole() end

			local exit = bpnodetype.New():WithOuter( self.graph )
			exit:SetCodeType(NT_FuncOutput)
			exit:SetDisplayName("Return")
			exit:SetName("__Exit")
			exit:AddFlag(NTF_NoDelete)
			exit:SetNodeClass("UserFuncExit")
			exit.GetRole = function() return nodeType:GetRole() end

			local _, ventry = self:AddNode( entry )
			local w0,h0 = ventry:GetSize()

			local _, vexit = self:AddNode( exit, 200 )
			local w1,h1 = vexit:GetSize()

			local c0 = w0/2
			local c1 = 400 + w1/2
			local cx = (c0/2 + c1/2)

			--self.vgraph:SetZoomLevel(2,0,0)
			timer.Simple(0, function()
				self.vgraph:CenterOnPoint(cx,h0/2)
			end)

			return

		end

		local node, vnode = self:AddNode( nodeType )
		if not node then return end
		local w,h = vnode:GetSize()

		--self.vgraph:SetZoomLevel(2,0,0)
		timer.Simple(0, function()
			self.vgraph:CenterOnPoint(w/2,h/2)
		end)
	end

end

function EDITOR:PostNodeListModify( action, id, item )

	if action ~= bplist.MODIFY_RENAME then return end
	if item ~= self.selectedNode then return end

	self:ConstructNode( self.selectedNode )
	self:SetupNodeDetails( self.selectedNode )

end

function EDITOR:PostGroupListModify( action, id, item )

	if action ~= bplist.MODIFY_REMOVE then return end
	if item ~= self.selectedGroup then return end

	self.NodeList:SetList(nil)

end

function EDITOR:Think()

	local selectedGroup = self.GroupList:GetSelected()
	if selectedGroup ~= self.selectedGroup then

		if self.selectedGroup then self.selectedGroup:GetEntries():UnbindAll( self ) end

		self.selectedGroup = selectedGroup
		self.selectedNode = nil

		if self.selectedGroup then

			self.NodeList:SetList( self.selectedGroup:GetEntries() )
			self.NodeList:ClearSelection()
			self.selectedGroup:GetEntries():Bind( "postModify", self, self.PostNodeListModify )

		end

		self:ConstructNode( nil )
		self:SetupNodeDetails( nil )

	end

	local selectedNode = self.NodeList:GetSelected()
	if selectedNode ~= self.selectedNode and self.selectedGroup ~= nil then

		self.selectedNode = selectedNode

		self:ConstructNode( self.selectedNode )
		self:SetupNodeDetails( self.selectedNode )

	end

end

RegisterModuleEditorClass("nodelib", EDITOR, "basemodule")