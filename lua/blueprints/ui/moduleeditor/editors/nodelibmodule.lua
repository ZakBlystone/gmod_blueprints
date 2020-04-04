if SERVER then AddCSLuaFile() return end

module("editor_nodelib", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.HasSideBar = true
EDITOR.HasDetails = true
--EDITOR.CanInstallLocally = true
--EDITOR.CanExportLuaScript = true

function EDITOR:PopulateSideBar()

	self.GroupList = self:AddSidebarList(LOCTEXT("editor_nodelib_grouplist","Groups"))
	self.GroupList.HandleAddItem = function(list)

	end

	self.NodeList = self:AddSidebarList(LOCTEXT("editor_nodelib_nodelist","Nodes"))
	self.NodeList.HandleAddItem = function(list)

	end

	self.StructList = self:AddSidebarList(LOCTEXT("editor_nodelib_structlist","Structs"))
	self.StructList.HandleAddItem = function(list)

	end

	self.GroupList:SetList( self:GetModule().groups )
	self.StructList:SetList( self:GetModule().structs )

	self.selectedGroup = nil
	self.selectedNode = nil
	self.currentNodeGroup = nil

end

function EDITOR:Setup()

	local mod = self:GetModule()
	self.graph = bpgraph.New():WithOuter(mod)
	self.graph:SetName("Node Preview")

end

function EDITOR:SetupNodeDetails( nodeType )

	if IsValid(self.detailGUI) then self.detailGUI:Remove() end

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

	end

	self.detailGUI = self.values:CreateVGUI({ live = true, })
	self:SetDetails( self.detailGUI )

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

function EDITOR:Think()

	local selectedGroup = self.GroupList:GetSelectedID()
	if selectedGroup ~= self.selectedGroup then

		self.selectedGroup = selectedGroup
		self.selectedNode = nil
		self.currentNodeGroup = self:GetModule().groups:Get( selectedGroup )
		self.NodeList:SetList( self.currentNodeGroup:GetEntries() )

	end

	local selectedNode = self.NodeList:GetSelectedID()
	if selectedNode ~= self.selectedNode and self.currentNodeGroup ~= nil then

		self.selectedNode = selectedNode
		self.currentNodeType = self.currentNodeGroup:GetEntries():Get( selectedNode )
		self:ConstructNode( self.currentNodeType )
		self:SetupNodeDetails( self.currentNodeType )

	end

end

RegisterModuleEditorClass("nodelib", EDITOR, "basemodule")