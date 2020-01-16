if SERVER then AddCSLuaFile() return end

G_BPGraphEditorCopyState = nil

module("bpgrapheditor", package.seeall, bpcommon.rescope(bpgraph, bpschema))

bpcommon.CallbackList({
	"POPUP",
})

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

	bpcommon.MakeObservable(self)

	-- HACK!!!!
	if G_BPGraphEditorCopyState ~= nil then
		G_BPGraphEditorCopyState.painter.vgraph = vgraph
	end

	return self

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

	self:FireListeners(CB_POPUP, text)

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

function meta:Cleanup()

	self:CloseCreationContext()
	self:CloseNodeContext()
	self:CloseEnumContext()

end

function meta:GetSelectedNodes()

	local selection = {}
	for k,v in pairs(self.selectedNodes) do
		selection[k:GetNode().id] = k
	end
	return selection

end
function meta:ClearSelection() self.selectedNodes = {} end
function meta:SelectNode(vnode) self.selectedNodes[vnode] = true end
function meta:IsNodeSelected(vnode) return self.selectedNodes[vnode] == true end

function meta:GetNodeSet() return self.nodeSet end
function meta:GetCoordinateScaleFactor() return 2 end
function meta:GetVNodes() return self.nodeSet:GetVNodes() end
function meta:OnGraphCallback( cb, ... )

	if cb == CB_NODE_ADD then return self:NodeAdded(...) end
	if cb == CB_NODE_REMOVE then return self:NodeRemoved(...) end
	if cb == CB_NODE_MOVE then return self:NodeMove(...) end
	if cb == CB_PIN_EDITLITERAL then return self:PinEditLiteral(...) end
	if cb == CB_CONNECTION_ADD then return self:ConnectionAdded(...) end
	if cb == CB_CONNECTION_REMOVE then return self:ConnectionRemoved(...) end
	if cb == CB_GRAPH_CLEAR then return self:GraphCleared(...) end
	if cb == CB_POSTMODIFY_NODE then return self:PostModifyNode(...) end

end

function meta:CreateAllNodes() self.nodeSet:CreateAllNodes() end
function meta:NodeAdded( id ) self.nodeSet:NodeAdded(id) end
function meta:NodeRemoved( id ) self.nodeSet:NodeRemoved(id) end
function meta:NodeMove( id, x, y ) end

function meta:PinEditLiteral( nodeID, pinID, value )
	local node = self.nodeSet:GetVNodes()[nodeID]
	if node then node:Invalidate(true) end
end

function meta:ConnectionAdded( id, conn )

	local nodes = self.nodeSet:GetVNodes()
	local nodeA = nodes[conn[1]]
	local nodeB = nodes[conn[3]]
	if nodeA then nodeA:Invalidate(true) end
	if nodeB then nodeB:Invalidate(true) end

end
function meta:ConnectionRemoved( id, conn ) 

	local nodes = self.nodeSet:GetVNodes()
	local nodeA = nodes[conn[1]]
	local nodeB = nodes[conn[3]]
	if nodeA then nodeA:Invalidate(true) end
	if nodeB then nodeB:Invalidate(true) end

end
function meta:GraphCleared() end
function meta:PostModifyNode( id ) self.nodeSet:PostModifyNode(id) end

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
		if self:TestPoint(v, x, y) then
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

	local nodeID0 = vpin0:GetVNode():GetNode().id
	local nodeID1 = vpin1:GetVNode():GetNode().id
	local pinID0 = vpin0:GetPinID()
	local pinID1 = vpin1:GetPinID()
	return self:GetGraph():ConnectNodes(nodeID0, pinID0, nodeID1, pinID1)

end

function meta:TakeGrabbedPin()

	local nodeID = self.grabPin:GetVNode():GetNode().id
	local pinID = self.grabPin:GetPinID()
	local graph = self:GetGraph()
	local vnodes = self:GetVNodes()
	for k,v in graph:Connections() do

		if v[1] == nodeID and v[2] == pinID then

			self.grabPin = vnodes[v[3]]:GetVPin(v[4])
			graph:RemoveConnectionID(k)
			break

		elseif v[3] == nodeID and v[4] == pinID then

			self.grabPin = vnodes[v[1]]:GetVPin(v[2])
			graph:RemoveConnectionID(k)
			break

		end

	end

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

function meta:LeftMouse(x,y,pressed)

	local wx, wy = self:PointToWorld(x,y)

	if pressed then

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
					self:EditPinLiteral(vnode, vpin)
				else
					self.grabPin = vpin
					if input.IsKeyDown( KEY_LCONTROL ) then
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

		if self.grabPin then
			local targetPin = self:TryGetPin(wx,wy)
			if targetPin then
				self:CreateUndo("Connect Pins")
				if not self:ConnectPins(self.grabPin, targetPin) then self:DeleteLastUndo() end
			else
				self:OpenCreationContext(self.grabPin:GetPin())
				return
			end
		end

		self.grabPin = nil
		self.leftMouseStart = nil
		self.dragSelecting = false
		self:FinishMovingNodes()

	end

end

function meta:RightMouse(x,y,pressed)

	local wx, wy = self:PointToWorld(x,y)

	if pressed then
		if G_BPGraphEditorCopyState ~= nil then
			G_BPGraphEditorCopyState = nil
			return true
		end

		local vnode, alreadySelected = self:TryGetNode(wx, wy)
		if vnode ~= nil then
			self:OpenNodeContext(vnode)
			return true
		end
	end

end

function meta:MiddleMouse(x,y,pressed)

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

	print("KEY PRESSED: " .. code)

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
			local selected = self:GetSelectedNodes()
			local selectedIDs = {}
			for k,v in pairs(selected) do selectedIDs[#selectedIDs+1] = v:GetNode().id end

			if #selectedIDs == 0 then
				print("Tried copy, but no nodes selected")
				G_BPGraphEditorCopyState = nil 
				return 
			end

			local subGraph = self:GetGraph():CreateSubGraph( selectedIDs )
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

function meta:EditPinLiteral(vnode, vpin)

	local node = vnode:GetNode()
	local pin = vpin:GetPin()
	local pinID = vpin:GetPinID()
	local literalType = pin:GetLiteralType()
	local value = node:GetLiteral( pinID )

	if literalType == "bool" then
		node:SetLiteral(pinID, value == "true" and "false" or "true")
	elseif literalType == "string" then
		bptextliteraledit.EditPinLiteral(vpin)
	elseif literalType == "number" then
		bptextliteraledit.EditPinLiteral(vpin)
	elseif literalType == "enum" then
		self:OpenEnumContext(node, pin, pinID, value)
	end

end

function meta:CloseEnumContext()

	if IsValid( self.enumContextMenu ) then self.enumContextMenu:Remove() end

end

function meta:OpenEnumContext(node, pin, pinID, value)

	local x,y = self.vgraph:GetMousePos(true)

	self:CloseEnumContext()
	self.enumContextMenu = DermaMenu( false, self.vgraph )

	local enum = bpdefs.Get():GetEnum( pin )
	if enum == nil then
		ErrorNoHalt("NO ENUM FOR " .. tostring( self.pinType ))
	else
		for k, entry in pairs(enum.entries) do
			self.enumContextMenu:AddOption( entry.shortkey, function()
				node:SetLiteral(pinID, entry.key)
			end )
		end
	end

	self.enumContextMenu:SetMinimumWidth( 100 )
	self.enumContextMenu:Open( x, y, false, self.vgraph )

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

	self:CloseNodeContext()
	self.nodeMenu = DermaMenu( false, self.vgraph )

	for k,v in pairs(options) do
		self.nodeMenu:AddOption( v[1], v[2] )
	end

	self.nodeMenu:SetMinimumWidth( 100 )
	self.nodeMenu:Open( x, y, false, self.vgraph )

end

function meta:ConnectNodeToGrabbedPin( node )

	if self.grabPin ~= nil and node ~= nil then

		local grabbedNode = self.grabPin:GetVNode():GetNode()
		local pf = self.grabPin:GetPin()
		local match = FindMatchingPin(node:GetType(), pf)
		if match ~= nil then
			self:GetGraph():ConnectNodes(grabbedNode.id, self.grabPin:GetPinID(), node.id, match)
		end

		self.grabPin = nil

	end

end

function meta:OpenCreationContext( pinFilter )

	if self:IsLocked() then return end

	self:CloseCreationContext()
	self:LockGrabbedPinPos()
	--self.menu = DermaMenu( false, self )

	local x, y = gui.MouseX(), gui.MouseY()
	local wx, wy = self:PointToWorld( self.vgraph:GetMousePos() )

	local scaleFactor = self:GetCoordinateScaleFactor()

	wx = wx / scaleFactor
	wy = wy / scaleFactor

	local createMenu = vgui.Create("BPCreateMenu")

	if x + createMenu:GetWide() > ScrW() then
		x = ScrW() - createMenu:GetWide()
	end

	if y + createMenu:GetTall() > ScrH() then
		y = ScrH() - createMenu:GetTall()
	end

	createMenu:SetPos(x,y)
	createMenu:SetVisible( true )
	createMenu:MakePopup()
	createMenu:Setup( self:GetGraph(), pinFilter )
	createMenu.OnNodeTypeSelected = function( menu, nodeType )

		self:CreateUndo("Added Node")
		local nodeID, node = self:GetGraph():AddNode(nodeType, wx, wy)
		self:ConnectNodeToGrabbedPin( node )
		self:ResetGrabbedPin()

	end

	self.menu = createMenu

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