if SERVER then AddCSLuaFile() return end

module("bpuimoduleeditor", package.seeall, bpcommon.rescope(bpmodule, bpgraph))

local PANEL = {}

function PANEL:Init()

	local editor = self:GetParent()

	local MenuOptions = {
		{"Save", function()
			self:Save()
		end, nil, "icon16/disk.png"},
		{"Export", function()
			local text = self.module:SaveToText()
			SetClipboardText( text )
			Derma_Message( "Module copied to clipboard", "Export", "Ok" )
		end, nil, "icon16/folder_go.png"},
		{"Export shareable key", function( pnl )
			local text = self.module:SaveToText()
			local prev = pnl:GetText()

			pnl:SetEnabled(false)
			bppaste.Upload( text, function( ok, result )

				if IsValid(pnl) then pnl:SetEnabled(true) end
				if ok then
					SetClipboardText( result )
					Derma_Message( "Blueprint key copied to clipboard", "Export shareable key", "Ok" )
				else
					Derma_Message( "Error creating sharable key: " .. tostring(result), "Export shareable key", "Ok" )
				end

			end)
		end, nil, "icon16/folder_link.png"},
		{"Send to server", function()
			_G.G_BPError = nil
			self.editor:ClearReport()
			--bpnet.SendModule( self.module )
			local ok, res = self.module:TryCompile( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
			if ok then
				ok, res = res:TryLoad()
				if ok then
					self:Save( function(ok) if ok then self:Upload(true) end end )
				else
					Derma_Message( res, "Failed to run", "OK" )
				end
			else
				Derma_Message( res, "Failed to compile", "OK" )
			end
		end, Color(80,180,80), "icon16/server_go.png"},
		{"Local: Install", function()

			if not bpusermanager.GetLocalUser():HasPermission( bpgroup.FL_CanRunLocally ) then
				Derma_Message( "You do not have permission to run local scripts", "Run Locally", "OK" )
				return
			end

			local ok, res = self.module:TryCompile( bit.bor(bpcompiler.CF_Debug, bpcompiler.CF_ILP, bpcompiler.CF_CompactVars) )
			if ok then
				ok, res = res:TryLoad()
				if ok then
					bpenv.Uninstall( self.module:GetUID() )
					bpenv.Install( res )
					bpenv.Instantiate( res:GetUID() )
				else
					Derma_Message( res, "Failed to run", "OK" )
				end
			else
				Derma_Message( res, "Failed to compile", "OK" )
			end

		end, nil, "icon16/flag_green.png"},
		{"Local: Uninstall", function()

			bpenv.Uninstall( self.module:GetUID() )

		end, nil, "icon16/flag_red.png"},
		{"Export Lua Script", function()

			local result = self.module:Compile( bit.bor(bpcompiler.CF_Standalone, bpcompiler.CF_Comments) )
			SetClipboardText(result:GetCode())

		end, nil, "icon16/page_code.png"},
	}

	self.callback = function(...)
		self:OnModuleCallback(...)
	end

	self.Menu = bpuimenubar.AddTo(self)
	pcall( function()

		for _, v in ipairs(MenuOptions) do
			self.Menu:Add(v[1], v[2], v[3], v[4])
		end

	end)

	self.ContentPanel = vgui.Create("DPanel", self)
	self.ContentPanel:Dock( FILL )
	self.ContentPanel:SetBackgroundColor( Color(50,50,50) )

	self.Content = vgui.Create("DHorizontalDivider", self.ContentPanel)
	self.Content:Dock( FILL )
	self.Content:SetBackgroundColor( Color(30,30,30) )

	local menu = vgui.Create("DVerticalDivider", self.Content)
	menu:SetTopHeight(300)
	local topSplit = vgui.Create("DVerticalDivider", menu)
	topSplit:SetTopHeight(200)
	local bottomSplit = vgui.Create("DVerticalDivider", menu)
	bottomSplit:SetTopHeight(200)

	self.Content:SetLeft(menu)
	self.Content:Dock( FILL )

	self.GraphList = vgui.Create("BPListView", topSplit)
	self.GraphList:SetText("Graphs")
	self.GraphList.HandleAddItem = function(list)

		local function MakeGraph(graphType)
			local id = self.module:NewGraph( nil, graphType )
			list:Rename(id)
		end

		local menu = DermaMenu( false, self )
		menu:AddOption( "Event Graph", function() MakeGraph(bpschema.GT_Event) end )
		menu:AddOption( "Function", function() MakeGraph(bpschema.GT_Function) end )
		menu:SetMinimumWidth( 100 )
		menu:Open( gui.MouseX(), gui.MouseY(), false, self )

	end
	self.GraphList.ItemBackgroundColor = function( list, id, item, selected )
		local vcolor = bpschema.GraphTypeColors[item:GetType()]
		if selected then
			return vcolor
		else
			return Color(vcolor.r*.5, vcolor.g*.5, vcolor.b*.5)
		end
	end

	local prev = self.GraphList.PopulateMenuItems
	self.GraphList.PopulateMenuItems = function(pnl, items, id)
		prev(pnl, items, id)
		local graph = self.module:GetGraph(id)
		if graph.type == bpschema.GT_Function and not graph:HasFlag(bpgraph.FL_LOCK_PINS) then
			items[#items+1] = {
				name = "Edit Pins",
				func = function() self:EditGraphPins(id) end,
			}
		end
	end

	self.VarList = vgui.Create("BPListView", bottomSplit)
	self.VarList:SetText("Variables")
	self.VarList.HandleAddItem = function(list)
		local id, item = self.module:NewVariable( "", bpschema.PinType( bpschema.PN_Bool ) )
		list:Rename(id)
	end
	local d = self.VarList.CreateItemPanel
	self.VarList.OpenMenu = function(pnl, id, item)
		bpuivarcreatemenu.OpenPinSelectionMenu(self.module, function(pnl, pinType)
			item:SetType( pinType )
		end, item:GetType())
	end
	self.VarList.ItemBackgroundColor = function( list, id, item, selected )
		local vcolor = item:GetType():GetColor()
		if selected then
			return vcolor
		else
			return Color(vcolor.r*.5, vcolor.g*.5, vcolor.b*.5)
		end
	end

	self.StructList = vgui.Create("BPListView", bottomSplit)
	self.StructList:SetText("Structs")
	self.StructList.HandleAddItem = function(pnl, list)
		local itemID, item = list:Construct()
		pnl:Rename(itemID)
	end
	local prev = self.StructList.PopulateMenuItems
	self.StructList.PopulateMenuItems = function(pnl, items, id)
		prev(pnl, items, id)
		items[#items+1] = {
			name = "Edit Struct",
			func = function() self:EditStructPins(id) end,
		}
	end

	self.EventList = vgui.Create("BPListView", bottomSplit)
	self.EventList:SetText("Events")
	self.EventList.HandleAddItem = function(pnl, list)
		local itemID, item = list:Construct()
		pnl:Rename(itemID)
	end
	local prev = self.EventList.PopulateMenuItems
	self.EventList.PopulateMenuItems = function(pnl, items, id)
		prev(pnl, items, id)
		items[#items+1] = {
			name = "Edit Event",
			func = function() self:EditEventPins(id) end,
		}
	end

	menu:SetTop(topSplit)
	menu:SetBottom(bottomSplit)
	topSplit:SetTop(self.GraphList)
	topSplit:SetBottom(self.VarList)
	bottomSplit:SetTop(self.StructList)
	bottomSplit:SetBottom(self.EventList)

	self.vvars = {}
	self.vgraphs = {}

end

function PANEL:Save( callback )

	if self.file == nil then

		Derma_StringRequest("Save Module", "Module Name", "untitled",
		function( text )
			local file = bpfilesystem.AddLocalModule( self.module, text )
			if file ~= nil then
				self.file = file
				self.tab:SetLabel( text )
				if callback then callback(true) end
			else
				if callback then callback(false) end
				Derma_Message("Failed to create module: " .. text, "Error", "Ok")
			end
		end, nil, "OK", "Cancel")

	else

		self.module:Save( self.file:GetPath() )
		bpfilesystem.MarkFileAsChanged( self.file, false )
		if self.tab then self.tab:SetSuffix("") end
		if callback then callback(true) end

	end

end

function PANEL:EditGraphPins( id )

	bpuigrapheditmenu.EditGraphParams( self.module:GetGraph(id) )

end

function PANEL:EditStructPins( id )

	bpuistructeditmenu.EditStructParams( self.module:GetStruct(id) )

end

function PANEL:EditEventPins( id )

	bpuistructeditmenu.EditEventParams( self.module:GetEvent(id) )

end

function PANEL:Think()

	--self.BaseClass.Think(self)

	local selectedGraphID = self.GraphList:GetSelectedID()

	for id, vgraph in pairs( self.vgraphs ) do
		if id == selectedGraphID then
			if not vgraph:IsVisible() then
				vgraph:SetVisible(true)
				self.Content:SetRight( vgraph )
			end
		else
			vgraph:SetVisible(false)
		end
	end

end

function PANEL:OnRemove()

	hook.Remove("BPPinClassRefresh", "pinrefresh_" .. self.module:GetUID())

	if _G.G_BPError and _G.G_BPError.uid == self.module:GetUID() then
		self.editor:ClearReport()
		_G.G_BPError = nil
	end

	self:SetModule(nil)

end

function PANEL:OnModuleCallback( cb, ... )

	if cb == CB_MODULE_CLEAR then self:Clear(...) end
	if cb == CB_GRAPH_ADD then self:GraphAdded(...) end
	if cb == CB_GRAPH_REMOVE then self:GraphRemoved(...) end

	if self.file and not self.file:HasFlag( bpfile.FL_HasLocalChanges ) then
		if self.tab then self.tab:SetSuffix("*") end
		bpfilesystem.MarkFileAsChanged( self.file ) 
	end

end

function PANEL:Clear()

	for _, v in pairs(self.vvars or {}) do v:Remove() end
	for _, v in pairs(self.vgraphs or {}) do v:Remove() end

	self.vvars = {}
	self.vgraphs = {}

end

function PANEL:GraphAdded( id )

	--print("GRAPH ADDED: " .. id)
	local graph = self.module:GetGraph(id)
	local vgraph = vgui.Create("BPGraph", self.Content)

	vgraph:SetGraph( graph )
	vgraph:SetVisible(false)
	vgraph:CenterToOrigin()
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
	self.StructList:SetList( self.module.structs )
	self.EventList:SetList( self.module.events )
	self.module:AddListener(self.callback, bpmodule.CB_ALL)

	for id, graph in self.module.graphs:Items() do
		self:GraphAdded( id )
	end

	hook.Add("BPPinClassRefresh", "pinrefresh_" .. self.module:GetUID(), function(class)
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

	self.Content:SetLeftWidth(150)

end

function PANEL:GetModule()

	return self.module

end

function PANEL:HandleError( errorData )

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

function PANEL:Upload( execute )

	if not self.file then return end

	local name = bpfilesystem.ModulePathToName( self.file:GetPath() )
	bpfilesystem.UploadObject(self.module, name or self.file:GetPath(), execute)

end

vgui.Register( "BPModuleEditor", PANEL, "DPanel" )