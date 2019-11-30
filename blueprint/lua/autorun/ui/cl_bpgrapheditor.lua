if SERVER then AddCSLuaFile() return end

module("bpgrapheditor", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local meta = bpcommon.MetaTable("bpgrapheditor")

function meta:Init( vgraph )

	self.vgraph = vgraph
	self.vnodes = {}
	return self

end

function meta:Cleanup()

	self:CloseCreationContext()

end

function meta:GetCoordinateScaleFactor() return 2 end
function meta:GetVNodes() return self.vnodes end
function meta:GetGraph() return self.vgraph:GetGraph() end
function meta:OnGraphCallback( cb, ... )

	if cb == CB_NODE_ADD then return self:NodeAdded(...) end
	if cb == CB_NODE_REMOVE then return self:NodeRemoved(...) end
	if cb == CB_NODE_MOVE then return self:NodeMove(...) end
	if cb == CB_CONNECTION_ADD then return self:ConnectionAdded(...) end
	if cb == CB_CONNECTION_REMOVE then return self:ConnectionRemoved(...) end
	if cb == CB_GRAPH_CLEAR then return self:GraphCleared(...) end
	if cb == CB_POSTMODIFY_NODE then return self:PostModifyNode(...) end

end

function meta:CreateAllNodes()
	
	self.nodes = {}
	for id in self:GetGraph():NodeIDs() do self:NodeAdded(id) end

end

function meta:NodeAdded( id )

	local graph = self:GetGraph()
	local vnode = bpuigraphnode.New( graph:GetNode(id), graph, self )
	self.vnodes[id] = vnode

end

function meta:NodeRemoved( id )

	self.vnodes[id] = nil

end

function meta:NodeMove( id, x, y ) end
function meta:ConnectionAdded( id ) end
function meta:ConnectionRemoved( id ) end
function meta:GraphCleared() end
function meta:PostModifyNode( id, action )

	if self.vnodes[id] ~= nil then
		self.vnodes[id]:Invalidate(true)
	end

end

function meta:IsLocked() return self.vgraph:GetIsLocked() end

function meta:PointToWorld(x,y) return self.vgraph:GetRenderer():PointToWorld(x,y) end
function meta:PointToScreen(x,y) return self.vgraph:GetRenderer():PointToScreen(x,y) end

function meta:LeftMouse(x,y,pressed)

end

function meta:RightMouse(x,y,pressed)

end

function meta:OpenCreationContext()

	if self:IsLocked() then return end

	self:CloseCreationContext()
	--self.menu = DermaMenu( false, self )

	local x, y = gui.MouseX(), gui.MouseY()


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
	createMenu:Setup( self:GetGraph() )
	createMenu.OnNodeTypeSelected = function( menu, nodeType )

		local scaleFactor = self:GetCoordinateScaleFactor()
		x, y = self.vgraph:ScreenToLocal(x, y)
		x, y = self:PointToWorld(x, y)

		x = x / scaleFactor
		y = y / scaleFactor

		self:GetGraph():AddNode(nodeType:GetName(), x, y)

	end

	self.menu = createMenu

end


function meta:CloseCreationContext()

	if ( IsValid( self.menu ) ) then
		self.menu:Remove()
	end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end