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

	self.GroupList.ItemBackgroundColor = function( list, id, item, selected )

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
		local newNode = bpnodetype.New():WithOuter( self.currentNodeGroup )

		if self.currentNodeGroup:GetType() == bpnodetypegroup.TYPE_Hooks then
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
		pnl:Rename(itemID)
	end

	self.StructList.PopulateMenuItems = function(pnl, items, id)

		items[#items+1] = {
			name = LOCTEXT("editor_graphmodule_editstruct","Edit Struct"),
			func = function() bpuistructeditmenu.EditStructParams( self:GetModule().structs:Get(id) ) end,
		}

	end

	self.GroupList:SetList( self:GetModule().groups )
	self.StructList:SetList( self:GetModule().structs )

	self.selectedGroup = nil
	self.selectedNode = nil
	self.currentNodeGroup = nil

	self.pinLists = {}

end

function EDITOR:Setup()

	local mod = self:GetModule()
	self.graph = bpgraph.New():WithOuter(mod)
	self.graph:SetName("Node Preview")

	mod.groups:Bind("postModify", self, self.PostGroupListModify)

end

function EDITOR:Shutdown()

	local mod = self:GetModule()

	mod.groups:UnbindAll(self)
	if self.currentNodeGroup then self.currentNodeGroup:UnbindAll(self) end

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
			v.id = nil
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
		entry.id = id
		entry.module = module
		function entry:SetPinType(t) item:SetType( t ) editor:ApplyPins( nodeType ) end
		function entry:GetPinType() return item:GetType() end
		function entry:SetPinName(n) pnl.list:Rename( id, n ) editor:ApplyPins( nodeType ) end
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

function EDITOR:ConstructNode( nodeType )

	self.graph:Clear()
	if nodeType ~= nil then
		local _, node = self.graph:AddNode( nodeType, 0, 0 )
		if not node then return end
		local vnode = bpuigraphnode.New( node, self.graph )
		local w,h = vnode:GetSize()

		self.vgraph:SetZoomLevel(-2,0,0)
		timer.Simple(0, function()
			self.vgraph:CenterOnPoint(w/2,h/2)
		end)
	end

end

function EDITOR:PostNodeListModify( action, id, item )

	if action ~= bplist.MODIFY_RENAME then return end
	if item ~= self.currentNodeType then return end

	self:ConstructNode( self.currentNodeType )
	self:SetupNodeDetails( self.currentNodeType )

end

function EDITOR:PostGroupListModify( action, id, item )

	if action ~= bplist.MODIFY_REMOVE then return end
	if item ~= self.currentNodeGroup then return end

	self.NodeList:SetList(nil)

end

function EDITOR:Think()

	local selectedGroup = self.GroupList:GetSelectedID()
	if selectedGroup ~= self.selectedGroup then

		if self.currentNodeGroup then self.currentNodeGroup:GetEntries():UnbindAll( self ) end

		self.selectedGroup = selectedGroup
		self.selectedNode = nil
		self.currentNodeGroup = self:GetModule().groups:Get( selectedGroup )

		print("GROUP CHANGED: " .. tostring( self.currentNodeGroup ))

		if self.currentNodeGroup then

			self.NodeList:SetList( self.currentNodeGroup:GetEntries() )
			self.NodeList:ClearSelection()
			self.currentNodeGroup:GetEntries():Bind( "postModify", self, self.PostNodeListModify )

		end

		self:ConstructNode( nil )
		self:SetupNodeDetails( nil )

	end

	local selectedNode = self.NodeList:GetSelectedID()
	if selectedNode ~= self.selectedNode and self.currentNodeGroup ~= nil then

		self.selectedNode = selectedNode
		self.currentNodeType = self.currentNodeGroup:GetEntries():Get( selectedNode )

		print("SELECTED NODE CHANGED: " .. tostring(self.currentNodeType))

		self:ConstructNode( self.currentNodeType )
		self:SetupNodeDetails( self.currentNodeType )

	end

end

RegisterModuleEditorClass("nodelib", EDITOR, "basemodule")