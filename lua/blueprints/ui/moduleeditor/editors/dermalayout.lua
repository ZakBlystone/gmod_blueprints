if SERVER then AddCSLuaFile() return end

module("editor_dermalayout", package.seeall, bpcommon.rescope(bpschema))

local EDITOR = {}

EDITOR.HasSideBar = true
EDITOR.HasDetails = true
EDITOR.CanExportLuaScript = true

function EDITOR:Setup()

end

function EDITOR:PopulateMenuBar( t )

	BaseClass.PopulateMenuBar(self, t)

	--[[if not self.editingModuleTab then
		t[#t+1] = { name = "New SubModule", func = function() self:NewSubModule() end, icon = "icon16/asterisk_yellow.png" }
	end]]

	--t[#t+1] = { name = "Toggle Design Mode", func = function() self:ToggleDesignMode() end, color = Color(120,60,90) }

end

function EDITOR:ToggleDesignMode()

end

function EDITOR:LayoutChanged()

	self:BuildNodeTree()
	self:CreatePanel()

end

function EDITOR:OpenDetails( node )

	self.detailsBar:Clear()

	self.detailsBar:Add( "Details" ):SetContents( node:GetEdit():CreateVGUI({ live = true, }) )

	if node:GetLayout() then

		self.detailsBar:Add( "Layout" ):SetContents( node:GetLayout():GetEdit():CreateVGUI({ live = true, }) )

	end

	self:CreateCallbackList( node )

end

function EDITOR:OpenDesigner()

	self:SetContent( self.vpreview )

	self.graph = nil
	self.vgraph:SetVisible(false)

end

function EDITOR:OpenGraph( graph )

	self.graph = graph
	self.vgraph:SetGraph(self.graph)
	self.vgraph:SetVisible(true)
	self:SetContent( self.vgraph )

end

function EDITOR:CreateCallbackList(node)

	local callbacks = {}
	node:GetCallbacks(callbacks)

	if #callbacks > 0 then
		local panel = self.detailsBar:Add( "Callbacks" )
		local list = vgui.Create("DPanelList")
		list:SetSkin("Blueprints")
		list:SetSpacing( 4 )
		panel:SetContents(list)

		for _, v in ipairs(callbacks) do
			local hasCallback = node:HasCallbackGraph( v )
			local btn = vgui.Create("DButton")
			btn:SetSkin("Blueprints")
			btn:SetText( v.func )
			btn:SetTall(20)
			btn:SetToggle(hasCallback)
			btn.DoClick = function(pnl)
				local graph = node:AddCallbackGraph( v )
				pnl:SetToggle(true)
				self:OpenGraph( graph )
			end
			btn.DoRightClick = function(pnl)
				if node:HasCallbackGraph( v ) then
					local menu = DermaMenu( false, pnl )
					menu:AddOption( "Remove Callback", function()
						local graph = node:GetCallbackGraph(v)
						node:RemoveCallbackGraph( v )
						pnl:SetToggle(false)
						if self.graph == graph then
							self:OpenDesigner()
						end
					end)
					menu:Open( gui.MouseX(), gui.MouseY(), false, pnl )
				end
			end
			list:AddItem(btn)
		end
	end

end

function EDITOR:NodeSelected(node)

	self:OpenDesigner()
	self:OpenDetails(node)

end

function EDITOR:NodeContextMenu(node, vnode)

	if IsValid(self.cmenu) then self.cmenu:Remove() end
	self.cmenu = DermaMenu( false, self:GetPanel() )

	print(tostring(node.CanHaveChildren))

	if node.CanHaveChildren then

		-- Enumerate child node classes
		local addChildMenu, op = self.cmenu:AddSubMenu( tostring( LOCTEXT("layout_submenu_addchild","Add Child") ) )
		local loader = bpdermanode.GetClassLoader()
		local classes = bpcommon.Transform( loader:GetClasses(), {}, function(k) return {name = k, class = loader:Get(k)} end )

		table.sort( classes, function(a,b) return tostring(a.class.Name) < tostring(b.class.Name) end )

		for _, v in ipairs( classes ) do

			local cl = v.class
			if cl.RootOnly then continue end
			if not cl.Creatable then continue end

			local op = addChildMenu:AddOption( tostring(cl.Name), function()
				local newNode = bpdermanode.New(v.name, node):WithOuter( self:GetModule() )
				newNode:SetupDefaultLayout()
				self:LayoutChanged()
			end )
			if cl.Icon then op:SetIcon( cl.Icon ) end
			if cl.Description then op:SetTooltip( tostring(cl.Description) ) end

		end

		-- Enumerate layout classes
		local setLayoutMenu, op = self.cmenu:AddSubMenu( tostring( LOCTEXT("layout_submenu_setlayout","Set Layout") ) )
		local loader = bplayout.GetClassLoader()
		local classes = bpcommon.Transform( loader:GetClasses(), {}, function(k) return {name = k, class = loader:Get(k)} end )

		table.sort( classes, function(a,b) return tostring(a.class.Name) < tostring(b.class.Name) end )

		setLayoutMenu:AddOption( tostring( LOCTEXT("layout_submenu_layoutnone","No Layout") ), function()
			node:SetLayout(nil)
			self:LayoutChanged()
		end ):SetIcon( "icon16/cut.png" )

		for _, v in ipairs( classes ) do

			local cl = v.class
			if not cl.Creatable then continue end

			local op = setLayoutMenu:AddOption( tostring(cl.Name), function()
				local newLayout = bplayout.New(v.name):WithOuter( self:GetModule() )
				node:SetLayout(newLayout)
				self:LayoutChanged()
			end )
			if cl.Icon then op:SetIcon( cl.Icon ) end
			if cl.Description then op:SetTooltip( tostring(cl.Description) ) end

		end

	end

	if node:GetParent() ~= nil then
		self.cmenu:AddOption( tostring( LOCTEXT("layout_submenu_delete","Delete") ), function()
			node:GetParent():RemoveChild( node )
			node:Destroy()
			self:LayoutChanged()
		end ):SetIcon( "icon16/delete.png" )
	end

	self.cmenu:Open( gui.MouseX(), gui.MouseY(), false, self:GetPanel() )

end

function EDITOR:CreatePanel()

	self:DestroyPanel()

	local ok, res = self:GetModule():TryBuild( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
	if ok then
		local ok, lres = res:TryLoad()
		if ok then

			local unit = res:Get()
			self.preview = unit.create()

			if IsValid(self.preview) then
				self.preview:SetPaintedManually(true)
				self.preview:Hide()

				self:GetModule():Root():MapToPreview( self.preview )

				if IsValid(self.vpreview) then self.vpreview:SetPanel( self.preview ) end
			end

		else

			print("Load failure: " .. tostring(lres))

		end
	else

		print("Compile failure: " .. tostring(res))

	end

end

function EDITOR:DestroyPanel()

	if IsValid( self.preview ) then
		self.preview:Remove()
	end

end

function EDITOR:PostInit()

	self:CreatePanel()

	self.vpreview = vgui.Create("BPDPreview")
	self.vpreview:SetPanel( self.preview )
	self:SetContent( self.vpreview )

	self.detailsBar = vgui.Create("BPCategoryList")
	self:SetDetails( self.detailsBar )

	self.vgraph = vgui.Create("BPGraph")

end

function EDITOR:Shutdown()

	self:DestroyPanel()
	if IsValid(self.cmenu) then self.cmenu:Remove() end

end

function EDITOR:Think()

end

function EDITOR:PopulateSideBar()

	self.hierarchyPanel = vgui.Create("DPanel")
	self.hierarchyPanel:SetSize(100,200)
	self.hierarchyPanel:SetMinimumSize(100,200)

	self.hierarchyTree = vgui.Create("DTree", self.hierarchyPanel)
	self.hierarchyTree:Dock( FILL )
	self.hierarchyTree:SetClickOnDragHover(true)

	self.hierarchyBar = self:AddSidebarPanel(LOCTEXT("editor_dermalayout_hierarchy","Hierarchy"), self.hierarchyPanel)

	self.callbackList = self:AddSidebarList(LOCTEXT("editor_dermalayout_callbacks","Callbacks"))
	self.callbackList.HandleAddItem = function(pnl, list)

	end

	self:BuildNodeTree()

end

function EDITOR:RecursiveAddNode(vnode, node)

	local newNode = vnode:AddNode(node:GetName(), node.Icon or "icon16/application.png")
	newNode:SetExpanded(true)
	newNode.node = node

	node:BindRaw("nameChanged", vnode, function(old, new)
		newNode:SetText(new)
	end)

	if not node.RootOnly then
		newNode:Droppable("dermanode")
	end

	newNode:Receiver( "dermanode", function( pnl, panels, isDropped, menuIndex, mouseX, mouseY )
		if isDropped then
			local changed = false
			for _, src in ipairs(panels) do
				if src.node == pnl.node then continue end
				src.node:GetParent():RemoveChild( src.node )
				pnl.node:AddChild(src.node)
				changed = true
			end
			if changed then self:LayoutChanged() end
		end
	end )

	newNode.DoClick = function()
		self:NodeSelected( node )
	end
	newNode.DoRightClick = function()
		self:NodeContextMenu( node, newNode )
	end
	for _, child in ipairs(node:GetChildren()) do
		self:RecursiveAddNode( newNode, child )
	end

end

function EDITOR:BuildNodeTree()

	self.hierarchyTree:Clear()

	local rootNode = self:GetModule():Root()
	local root = self.hierarchyTree:Root()

	if not rootNode then return end

	self:RecursiveAddNode( root, rootNode )

end

RegisterModuleEditorClass("dermalayout", EDITOR, "basemodule")