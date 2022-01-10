if SERVER then AddCSLuaFile() return end

G_BPGraphEditorCopyState = nil

module("bpgrapheditor", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local meta = bpcommon.MetaTable("bpgrapheditor")

function meta:Init( vgraph )

	self.vgraph = vgraph
	self.graph = vgraph:GetGraph()
	self.nodeSet = bpgraphnodeset.New( self.graph, self )
	self.selectedNodes = {}
	self.storedNodeOffsets = {}
	self.leftMouseStart = nil
	self.dragSelecting = false
	self.grabLock = nil
	self.baseUndoGraph = nil
	self.undo = {}
	self.undoPtr = -1
	self.maxUndoLevels = 20
	self.pressx = 0
	self.pressy = 0

	bpcommon.MakeObservable(self)

	-- HACK!!!!
	if G_BPGraphEditorCopyState ~= nil then
		G_BPGraphEditorCopyState.painter.vgraph = vgraph
	end

	self.graph:Bind("nodeAdded", self, self.NodeAdded)
	self.graph:Bind("nodeRemoved", self, self.NodeRemoved)
	self.graph:Bind("nodeMoved", self, self.NodeMove)
	self.graph:Bind("preModifyLiteral", self, self.PinPreEditLiteral)
	self.graph:Bind("postModifyLiteral", self, self.PinPostEditLiteral)
	self.graph:Bind("connectionAdded", self, self.ConnectionAdded)
	self.graph:Bind("connectionRemoved", self, self.ConnectionRemoved)
	self.graph:Bind("cleared", self, self.GraphCleared)

	return self

end

function meta:Shutdown()

	self.graph:UnbindAll(self)
	self:CloseCreationContext()
	self:CloseNodeContext()
	self:CloseEnumContext()

end

function meta:CreateUndo(text)

	if self.undoPtr ~= -1 and self.undoPtr ~= #self.undo then
		for i=#self.undo, self.undoPtr+1, -1 do
			table.remove(self.undo)
		end
	end

	if #self.undo >= self.maxUndoLevels then table.remove(self.undo, 1) end

	local undoGraph = self.graph:CopyInto( bpgraph.New() )
	self.undo[#self.undo+1] = {
		graph = undoGraph,
		text = text,
	}
	self.undoPtr = #self.undo

end

function meta:DeleteLastUndo()

	if self.undoPtr <= 0 then return end
	table.remove(self.undo)
	self.undoPtr = #self.undo

end

function meta:Popup(text)

	self:Broadcast("popup", text)

end

function meta:Undo()

	if self.undoPtr <= 0 then return end
	if self.undoPtr == #self.undo then
		self.baseUndoGraph = self.graph:CopyInto( bpgraph.New() )
	end
	local apply = self.undo[self.undoPtr]
	self:Popup("Undo " .. tostring(apply.text))
	apply.graph:CopyInto( self.graph )
	self:CreateAllNodes()
	self.undoPtr = self.undoPtr - 1

end

function meta:Redo()

	local apply = self.undo[self.undoPtr+2]
	if apply then
		self:Popup("Redo " .. tostring(apply.text))
		apply.graph:CopyInto( self.graph )
		self:CreateAllNodes()
		self.undoPtr = self.undoPtr + 1
	elseif #self.undo ~= 0 and self.undoPtr ~= #self.undo then
		self:Popup("Redo " .. tostring(self.undo[#self.undo].text))
		self.baseUndoGraph:CopyInto( self.graph )
		self:CreateAllNodes()
		self.undoPtr = #self.undo
	end

end

function meta:GetGraphCopy()

	return G_BPGraphEditorCopyState

end

function meta:GetGraph()

	return self.graph

end

function meta:GetSelectedNodes()

	local selection = {}
	local count = 0
	for k,v in pairs(self.selectedNodes) do
		selection[k:GetNode()] = k
		count = count + 1
	end
	return selection, count

end
function meta:ClearSelection() self.selectedNodes = {} end
function meta:SelectNode(vnode) self.selectedNodes[vnode] = true end
function meta:IsNodeSelected(vnode) return self.selectedNodes[vnode] == true end

function meta:GetNodeSet() return self.nodeSet end
function meta:GetCoordinateScaleFactor() return 2 end
function meta:GetVNodes() return self.nodeSet:GetVNodes() end

function meta:CreateAllNodes() self.nodeSet:CreateAllNodes() end
function meta:NodeAdded( node ) self.nodeSet:NodeAdded(node) end
function meta:NodeRemoved( node ) self.nodeSet:NodeRemoved(node) end
function meta:NodeMove( node, x, y ) end

function meta:PinPreEditLiteral( node, pinID, value )
	local vnode = self.nodeSet:GetVNodes()[node]
	local node = vnode and vnode:GetNode()
	if node then self:CreateUndo("Edit: " .. node:GetDisplayName() .. "." .. node:GetPin(pinID):GetDisplayName()) end
end

function meta:PinPostEditLiteral( node, pinID, value )
	local node = self.nodeSet:GetVNodes()[node]
	if node then node:Invalidate(true) end
end

function meta:ConnectionAdded( a, b )

	local nodes = self.nodeSet:GetVNodes()
	local nodeA = nodes[a:GetNode()]
	local nodeB = nodes[b:GetNode()]
	if nodeA then nodeA:Invalidate(true) end
	if nodeB then nodeB:Invalidate(true) end

end
function meta:ConnectionRemoved( a, b ) 

	local nodes = self.nodeSet:GetVNodes()
	local nodeA = nodes[a:GetNode()]
	local nodeB = nodes[b:GetNode()]
	if nodeA then nodeA:Invalidate(true) end
	if nodeB then nodeB:Invalidate(true) end

end

function meta:InvalidateAllNodes( pins )

	for _, v in pairs(self.nodeSet:GetVNodes()) do

		if pins then
			v:CreatePins()
			v:LayoutPins()
		end

		v:Invalidate( pins )
	end

end

function meta:GraphCleared() self.nodeSet:CreateAllNodes() end

function meta:IsLocked() return self.vgraph:GetIsLocked() end

function meta:PointToWorld(x,y) return self.vgraph:GetRenderer():PointToWorld(x,y) end
function meta:PointToScreen(x,y) return self.vgraph:GetRenderer():PointToScreen(x,y) end

function meta:GetSelectionRect()

	if self.leftMouseStart then
		local x0,y0 = unpack(self.leftMouseStart)
		local x1,y1 = self:PointToWorld( self.vgraph:GetMousePos() )
		if x0 > x1 then t = x1 x1 = x0 x0 = t end
		if y0 > y1 then t = y1 y1 = y0 y0 = t end
		return x0, y0, x1-x0, y1-y0
	else
		return 0,0,0,0
	end

end

function meta:ResetGrabbedPin()

	self.grabPin = nil
	self.grabLock = nil

end

function meta:GetGrabbedPin()

	return self.grabPin

end

function meta:GetGrabbedPinPos()

	if self.grabLock then return unpack(self.grabLock) end
	return self:PointToWorld( self.vgraph:GetMousePos() )

end

function meta:LockGrabbedPinPos()

	if not self:GetGrabbedPin() then return end
	self.grabLock = {self:GetGrabbedPinPos()}

end

function meta:UnlockGrabbedPinPos()

	self.grabLock = nil

end

function meta:IsDragSelecting() return self.dragSelecting end

function meta:UpdateDragSelection()

	local x,y,w,h = self:GetSelectionRect()
	self:ClearSelection()
	for k,v in pairs(self:GetVNodes()) do
		if self:TestRectInclusive(v,x,y,w,h) then
			self:SelectNode(v)
		end
	end

end

function meta:BeginMovingNodes()

	self:CreateUndo("Move Nodes")
	local x0, y0 = unpack(self.leftMouseStart)
	self.movingNodes = true
	self.nodesMoved = false
	self.storedNodeOffsets = {}
	for k, v in pairs(self:GetSelectedNodes()) do
		local nx, ny = v:GetPos()
		self.storedNodeOffsets[k] = {nx-x0, ny-y0}
	end

end

function meta:FinishMovingNodes()

	if self.movingNodes then
		if not self.nodesMoved then self:DeleteLastUndo() end
		self.movingNodes = false
	end

end

function meta:TryGetNode(x,y)

	for k,v in pairs(self:GetVNodes()) do
		if self:TestPoint(v, x, y) then
			if self:IsNodeSelected(v) then
				return v, true
			else
				return v, false
			end
		end
	end
	return nil, false

end

function meta:TryGetNodePin(node,x,y)

	for k,v in pairs(node:GetVPins()) do
		if self:TestPoint(v, x, y) and not v:GetPin():IsType(PN_Dummy) then
			return v, false
		end

		if self:TestPoint(v, x, y, "GetLiteralHitBox") then
			return v, true
		end
	end

end

function meta:TryGetPin(x,y)

	local node = self:TryGetNode(x,y)
	local pin = node and self:TryGetNodePin(node,x,y) or nil
	return pin

end

function meta:ConnectPins(vpin0, vpin1)

	return vpin0.pin:MakeLink(vpin1.pin)

end

function meta:FindVPin(pin)

	local vnodes = self:GetVNodes()
	local vnode = vnodes[pin:GetNode()]
	if vnode == nil then return nil end

	for _, vpin in ipairs(vnode.pins) do
		if vpin.pin == pin then return vpin end
	end

end

function meta:TakeGrabbedPin()

	for _, pin in ipairs(self.grabPin.pin:GetConnectedPins()) do

		self.grabPin.pin:BreakLink( pin )
		local p = self:FindVPin( pin )
		if not p then
			print("Couldn't find pin: ", pin)
		else
			self.grabPin = p
		end
		break

	end

	self.takingGrabbedPin = true

end

function meta:PasteGraph()

	if G_BPGraphEditorCopyState == nil then return false end

	self:CreateUndo("Paste Nodes")

	local scaleFactor = self:GetCoordinateScaleFactor()
	local copy = G_BPGraphEditorCopyState
	local mx, my = self:PointToWorld(self.vgraph:GetMousePos())

	self:GetGraph():AddSubGraph( copy.subGraph, (mx - copy.x) / scaleFactor, (my - copy.y) / scaleFactor )

	G_BPGraphEditorCopyState = nil
	return true

end

function meta:CheckNodeSpawn(key, nodeType, wx, wy)
	if input.IsKeyDown ( key ) then
		local scaleFactor = self:GetCoordinateScaleFactor()
		local _, pinNode = self:GetGraph():AddNode(nodeType, wx/scaleFactor, wy/scaleFactor - 15)
		if pinNode == nil then
			self:Popup("Cannot create delay node inside function!")
		end
		return true
	end
end

function meta:PlaceVar(var, wx, wy, setter)

	local scaleFactor = self:GetCoordinateScaleFactor()
	local _, pinNode = self:GetGraph():AddNode(setter and var:SetterNodeType() or var:GetterNodeType(), wx/scaleFactor, wy/scaleFactor - 15)

end

function meta:PlaceEvent(event, wx, wy, call)

	local scaleFactor = self:GetCoordinateScaleFactor()
	local _, pinNode = self:GetGraph():AddNode(call and event:CallNodeType() or event:EventNodeType(), wx/scaleFactor, wy/scaleFactor - 15)

end

function meta:PlaceStruct(struct, wx, wy, make)

	local scaleFactor = self:GetCoordinateScaleFactor()
	local _, pinNode = self:GetGraph():AddNode(make and struct:MakerNodeType() or struct:BreakerNodeType(), wx/scaleFactor, wy/scaleFactor - 15)

end

function meta:PlaceGraphCall(graph, wx, wy)

	if graph == self:GetGraph() then return end
	if graph:GetCallNodeType() == nil then print("Graph doesn't have call node") return end

	local scaleFactor = self:GetCoordinateScaleFactor()
	local _, pinNode = self:GetGraph():AddNode(graph:GetCallNodeType(), wx/scaleFactor, wy/scaleFactor - 15)

end

local nodeSpawners = {
	[KEY_B] = "LOGIC_If",
	[KEY_D] = "CORE_Delay",
	[KEY_S] = "CORE_Sequence",
}

local text_call = LOCTEXT("drag_create_call", "Call %s")
local text_hook = LOCTEXT("drag_create_hook", "Hook %s")
local text_set = LOCTEXT("drag_create_set", "Set %s")
local text_get = LOCTEXT("drag_create_get", "Get %s")
local text_make = LOCTEXT("drag_create_make", "Make %s")
local text_break = LOCTEXT("drag_create_break", "Break %s")

function meta:LeftMouse(x,y,pressed)

	local wx, wy = self:PointToWorld(x,y)

	if pressed then
		for k, v in pairs(nodeSpawners) do
			if self:CheckNodeSpawn(k, v, wx, wy) then
				return true;
			end
		end

		if self:PasteGraph() then return true end

		self:ResetGrabbedPin()
		self.leftMouseStart = {self:PointToWorld( x,y )}

		local alreadySelected = false
		local vnode, alreadySelected = self:TryGetNode(wx, wy)
		if vnode == nil then
			self:ClearSelection()
			self.dragSelecting = true
		else
			local vpin, literal = self:TryGetNodePin(vnode, wx, wy)
			if vpin then
				if literal then
					self:EditPinLiteral(vnode, vpin, wx, wy)
				else
					self.grabPin = vpin
					if input.IsKeyDown( KEY_LALT ) then
						vpin.pin:BreakAllLinks()
						self.grabPin = nil
					elseif input.IsKeyDown( KEY_LCONTROL ) then
						self:TakeGrabbedPin()
					end
				end
			else
				if not alreadySelected then
					self:ClearSelection()
					self:SelectNode(vnode)
				end
				self:BeginMovingNodes()
			end
		end

	else

		if G_BPDraggingElement then

			local v = G_BPDraggingElement
			if isbpgraph(v) then

				self:PlaceGraphCall( v, wx, wy )

			else

				local options = {}
				if isbpevent( v ) then
					options[#options+1] = { title = text_call( v:GetName() ), func = function() self:PlaceEvent( v, wx, wy, true ) end }
					options[#options+1] = { title = text_hook( v:GetName() ), func = function() self:PlaceEvent( v, wx, wy, false ) end }
				elseif isbpvariable(v) then
					options[#options+1] = { title = text_set( v:GetName() ), func = function() self:PlaceVar( v, wx, wy, true ) end }
					options[#options+1] = { title = text_get( v:GetName() ), func = function() self:PlaceVar( v, wx, wy, false ) end }
				elseif isbpstruct(v) then
					options[#options+1] = { title = text_make( v:GetName() ), func = function() self:PlaceStruct( v, wx, wy, true ) end }
					options[#options+1] = { title = text_break( v:GetName() ), func = function() self:PlaceStruct( v, wx, wy, false ) end }
				end

				self.dragVarMenu = bpmodal.Menu({
					options = options,
					width = 100,
				}, self.vgraph)

			end

			G_BPDraggingElement = nil

		end

		if self.grabPin then
			local targetPin = self:TryGetPin(wx,wy)
			if targetPin then
				self:CreateUndo("Connect Pins")
				if not self:ConnectPins(self.grabPin, targetPin) then self:DeleteLastUndo() end
			elseif input.IsKeyDown( KEY_LALT ) then
				local scaleFactor = self:GetCoordinateScaleFactor()
				local _, pinNode = self:GetGraph():AddNode("CORE_Pin", wx/scaleFactor - 32, wy/scaleFactor - 32)
				pinNode:FindPin(PD_In, "In"):Connect( self.grabPin:GetPin() )
				pinNode:FindPin(PD_Out, "Out"):Connect( self.grabPin:GetPin() )
			elseif input.IsKeyDown( KEY_B ) and self.grabPin:GetPin():IsType(PN_Bool) then
				local scaleFactor = self:GetCoordinateScaleFactor()
				local _, pinNode = self:GetGraph():AddNode("LOGIC_If", wx/scaleFactor - 5, wy/scaleFactor - 50)
				pinNode:FindPin(PD_In, "Condition"):Connect( self.grabPin:GetPin() )
			elseif not self.takingGrabbedPin then
				self:OpenCreationContext(self.grabPin:GetPin())
				return
			end
		end

		self.grabPin = nil
		self.leftMouseStart = nil
		self.dragSelecting = false
		self.takingGrabbedPin = false
		self:FinishMovingNodes()

	end

end

function meta:RightMouse(x,y,pressed)

	local wx, wy = self:PointToWorld(x,y)

	local vnode, alreadySelected = self:TryGetNode(wx, wy)
	if pressed then
		self.pressx = x
		self.pressy = y

		if vnode ~= nil then
			local vpin, literal = self:TryGetNodePin(vnode, wx, wy)
			if vpin and not literal then
				if vpin.pin.OnRightClick then vpin.pin:OnRightClick() end
			end
		end
	else
		-- Only open context after mouse released, and mosue drag distance is less than 5
		if math.Distance(self.pressx, self.pressy, x, y) < 5. then
			local selected, count = self:GetSelectedNodes()
			if count > 1 then
				self:OpenMultiNodeContext(selected)
				return false
			end

			if vnode ~= nil then
				self:OpenNodeContext(vnode)
			else
				self:OpenCreationContext()
			end
		end
	end

end

function meta:MiddleMouse(x,y,pressed)

	if pressed then
		if G_BPGraphEditorCopyState ~= nil then
			G_BPGraphEditorCopyState = nil
			return true
		end
	end

end

function meta:DeleteSelected()

	for k, v in pairs(self:GetSelectedNodes()) do
		if not v:GetNode():HasFlag(NTF_NoDelete) then
			self:GetGraph():RemoveNode(k)
		end
	end
	self:ClearSelection()

end

function meta:KeyPress( code )

	--print("KEY PRESSED: " .. code)

	if self:IsLocked() then return end

	if code == KEY_DELETE then
		self:CreateUndo("Deleted Nodes")
		self:DeleteSelected()
		return
	end

	if input.IsKeyDown( KEY_LCONTROL ) then

		if code == KEY_Z then
			self:Undo()
			return
		end

		if code == KEY_Y then
			self:Redo()
			return
		end

		if code == KEY_C or code == KEY_X then
			local selected, count = self:GetSelectedNodes()
			local selectedNodes = {}
			for k,v in pairs(selected) do selectedNodes[#selectedNodes+1] = k end

			if #selectedNodes == 0 then
				print("Tried copy, but no nodes selected")
				G_BPGraphEditorCopyState = nil 
				return 
			end

			local subGraph = self:GetGraph():CreateSubGraph( selectedNodes )
			local nodeSet = bpgraphnodeset.New( subGraph )
			nodeSet:CreateAllNodes()

			local painter = bpgraphpainter.New( subGraph, nodeSet, self.vgraph )

			local x, y = self:PointToWorld( self.vgraph:GetMousePos() )

			x = math.Round(x / 15) * 15
			y = math.Round(y / 15) * 15

			G_BPGraphEditorCopyState = {
				subGraph = subGraph,
				painter = painter,
				nodeSet = nodeSet,
				x = x,
				y = y,
			}

			if code == KEY_X then
				self:CreateUndo("Cut Nodes")
				self:DeleteSelected() 
			end

			self:Popup("Left-click to paste, Middle-click to cancel")

			print("COPIED GRAPH")
		end

	end

end

function meta:KeyRelease( code )

end

function meta:Think()

	if self:IsDragSelecting() then
		self:UpdateDragSelection()
	end

	if self.movingNodes then
		local scaleFactor = self:GetCoordinateScaleFactor()
		local x0,y0 = unpack(self.leftMouseStart)
		local x1,y1 = self:PointToWorld( self.vgraph:GetMousePos() )
		local vnodes = self:GetVNodes()

		for k,v in pairs(self.storedNodeOffsets) do
			local ox, oy = unpack(v)
			if vnodes[k]:GetNode():Move( (x1 + ox) / scaleFactor, (y1 + oy) / scaleFactor ) then
				self.nodesMoved = true
			end
		end
	end

end

function meta:EditPinLiteral(vnode, vpin, wx, wy)

	local pin = vpin:GetPin()
	if pin.OnClicked then pin:OnClicked(vpin, wx, wy) end

end

function meta:CloseEnumContext()

	if IsValid( self.enumContextMenu ) then self.enumContextMenu:Remove() end

end

function meta:CloseNodeContext()

	if IsValid( self.nodeMenu ) then self.nodeMenu:Remove() end

end

function meta:OpenNodeContext(vnode)

	local options = {}
	local node = vnode:GetNode()
	local x,y = self.vgraph:GetMousePos(true)
	node:GetOptions(options)

	if #options == 0 then return end
	
	local menuOptions = bpcommon.Transform(options, {}, function(v)
		return { title = v[1], func = v[2], icon = v[3] }
	end)

	self:CloseNodeContext()
	self.nodeMenu = bpmodal.Menu({
		options = menuOptions,
		width = 100,
		x = x,
		y = y,
	}, self.vgraph)

end

function meta:OpenMultiNodeContext(selected)

	local options = {}
	local x,y = self.vgraph:GetMousePos(true)

	if #options == 0 then return end

	local menuOptions = bpcommon.Transform(options, {}, function(v)
		return { title = v[1], func = v[2] }
	end)

	self:CloseNodeContext()
	self.nodeMenu = bpmodal.Menu({
		options = menuOptions,
		width = 100,
		x = x,
		y = y,
	}, self.vgraph)

end

function meta:ConnectNodeToGrabbedPin( node )

	if self.grabPin ~= nil and node ~= nil then

		local grabbedNode = self.grabPin:GetVNode():GetNode()
		local pf = self.grabPin:GetPin()
		local match = bpcast.FindMatchingPin( node:GetType(), pf, self.graph:GetModule() )
		if match ~= nil then
			self.grabPin.pin:MakeLink( node:GetPin( match ) )
		end

		self.grabPin = nil

	end

end

function meta:OpenCreationContext( pinFilter )

	if self:IsLocked() then return end

	self:CloseCreationContext()
	self:LockGrabbedPinPos()

	local x, y = gui.MouseX(), gui.MouseY()
	local wx, wy = self:PointToWorld( self.vgraph:GetMousePos() )

	local scaleFactor = self:GetCoordinateScaleFactor()

	wx = wx / scaleFactor
	wy = wy / scaleFactor

	local categoryOrder = {
		[bpnodetype.NC_Hook] = 1,
		[bpnodetype.NC_Class] = 2,
		[bpnodetype.NC_Lib] = 3,
		[bpnodetype.NC_Struct] = 4,
		other = 5,
	}

	local graph = self:GetGraph()
	graph:CacheNodeTypes()

	local nodeTypes = graph:GetNodeTypes()

	local function FilterByType( filterType ) return function(n) return n:GetCodeType() == filterType end end
	local function FilterByPinType( pinType ) return function(n)
			for _, pin in ipairs(n:GetPins()) do
				if pin:GetType():Equal(pinType, 0) then return true end
			end
			return false
		end
	end

	local menu = bpuipickmenu.Create(nil, nil, 400, 500)
	menu:SetCollection( nodeTypes )
	menu:SetSorter( function(a,b)
		local acat = categoryOrder[a:GetContext()] or categoryOrder.other
		local bcat = categoryOrder[b:GetContext()] or categoryOrder.other
		if acat == bcat then
			return a:GetDisplayName() < b:GetDisplayName()
		end
		return acat < bcat
	end )
	menu.OnEntrySelected = function(pnl, e)

		self:CreateUndo("Added Node")
		local nodeID, node = self:GetGraph():AddNode(e, wx, wy)
		self:ConnectNodeToGrabbedPin( node )
		self:ResetGrabbedPin()

	end
	menu.GetDisplayName = function(pnl, e) return e:GetDisplayName() end
	menu.GetTooltip = function(pnl, e) return e:GetDescription() end
	menu.GetCategory = function(pnl, e)
		local context = e:GetContext()
		if context == bpnodetype.NC_Hook then return tostring( LOCTEXT("nodecat_hooks", "Hooks") ), "icon16/connect.png"
		elseif context == bpnodetype.NC_Class then return tostring( LOCTEXT("nodecat_class", "Classes") ), "icon16/bricks.png"
		elseif context == bpnodetype.NC_Lib then return tostring( LOCTEXT("nodecat_library", "Libs") ), "icon16/brick.png"
		elseif context == bpnodetype.NC_Struct then return tostring( LOCTEXT("nodecat_struct", "Structs") ), "icon16/table.png"
		end
		return tostring( LOCTEXT("nodecat_other", "Other") )
	end
	menu.GetSubCategory = function(pnl, e)
		local category = e:GetCategory()
		if category then return category, "icon16/bullet_go.png" end
	end
	menu.GetIcon = function(pnl, e)
		local role = e:GetRole()
		if role == ROLE_Server then return "icon16/bullet_blue.png" end
		if role == ROLE_Client then return "icon16/bullet_orange.png" end
		if role == ROLE_Shared then return "icon16/bullet_purple.png" end
		return "icon16/bullet_white.png"
	end
	menu.IsHidden = function(pnl, e)
		if e:HasFlag(NTF_Deprecated) then return true end
		if not graph:CanAddNode(e) then return true end
		return false
	end
	if pinFilter then
		local __cache = {}
		local mod = self.graph:GetModule()
		menu:SetBaseFilter( function(e)
			local pinID, pin = bpcast.FindMatchingPin( e, pinFilter, mod, __cache )
			return pin ~= nil
		end)
	end

	local entityType = bppintype.New(PN_Ref, PNF_None, "Entity")
	local playerType = bppintype.New(PN_Ref, PNF_None, "Player")
	local anyType = bppintype.New(PN_Any, PNF_None)

	menu:AddPage( LOCTEXT("context_node_all", "All"), LOCTEXT("context_node_all_desc", "All Nodes"), "icon16/book.png", nil, pinFilter ~= nil )
	menu:AddPage( LOCTEXT("context_node_hooks", "Hooks"), LOCTEXT("context_node_hooks_desc", "Hook Nodes"), "icon16/connect.png", FilterByType(NT_Event), true )
	menu:AddPage( LOCTEXT("context_node_entity", "Entity"), LOCTEXT("context_node_entity_desc", "Entity Nodes"), "icon16/bricks.png", FilterByPinType(entityType), true )
	menu:AddPage( LOCTEXT("context_node_player", "Player"), LOCTEXT("context_node_player_desc", "Player Nodes"), "icon16/user.png", FilterByPinType(playerType), true )
	menu:AddPage( LOCTEXT("context_node_spec", "Special"), LOCTEXT("context_node_spec_desc", "Special Nodes"), "icon16/plugin.png", bpuipickmenu.OrFilter( FilterByType(NT_Special), FilterByPinType(anyType) ), true )
	menu:AddPage( LOCTEXT("context_node_custom", "Custom"), LOCTEXT("context_node_custom_desc", "User Created Nodes"), "icon16/wrench.png", function(n) return n:HasFlag(NTF_Custom) end, true )
	menu:Setup()
	self.menu = menu
	return menu

end

function meta:CloseCreationContext()

	if ( IsValid( self.menu ) ) then
		self.menu:Remove()
	end

end

function meta:TestRectInclusive(target,rx,ry,rw,rh,func)

	func = func or "GetHitBox"
	local x,y,w,h = target[func](target)
	if rx + rw < x then return false end
	if ry + rh < y then return false end
	if rx > x + w then return false end
	if ry > y + h then return false end
	return true

end

function meta:TestPoint(target,px,py,func)

	func = func or "GetHitBox"
	local x,y,w,h = target[func](target)
	return px > x and px < x+w and py > y and py < y + h

end

function New(...) return bpcommon.MakeInstance(meta, ...) end