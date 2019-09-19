if SERVER then AddCSLuaFile() return end

include("cl_bpnode.lua")
include("cl_bppin.lua")

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpgraph.lua")

module("bpuigraph", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local PANEL = {}
local canvasBack = 50000

function PANEL:Init()

	self:SetMouseInputEnabled( true )
	self:SetBackgroundColor( Color(40,40,40) )

	self.callback = function(...)
		self:OnGraphCallback(...)
	end

	self.canvas = vgui.Create( "Panel", self )
	self.canvas.OnMousePressed = function( self, code ) self:GetParent():OnMousePressed( code ) end
	self.canvas.OnMouseReleased = function( self, code ) self:GetParent():OnMouseReleased( code ) end
	self.canvas.PerformLayout = function( pnl )

		self:PerformLayout()
		self:InvalidateParent()

	end
	self.canvas.OnPinGrab = function( canvas, ... )

		self:OnPinGrab(...)

	end

	self.canvas:SetPos(-canvasBack,-canvasBack)

	self.canvas:InvalidateLayout(true)
	self.canvas:SizeToContents()

end

function PANEL:OnRemove()

	if self.graph then
		self.graph:RemoveListener(self.callback)
	end

end

function PANEL:OnGraphCallback( cb, ... )

	if cb == CB_NODE_ADD then return self:NodeAdded(...) end
	if cb == CB_NODE_REMOVE then return self:NodeRemoved(...) end
	if cb == CB_NODE_REMAP then return self:NodeRemap(...) end
	if cb == CB_NODE_MOVE then return self:NodeMove(...) end
	if cb == CB_CONNECTION_ADD then return self:ConnectionAdded(...) end
	if cb == CB_CONNECTION_REMOVE then return self:ConnectionRemoved(...) end
	if cb == CB_CONNECTION_REMAP then return self:ConnectionRemap(...) end

end

function PANEL:NodeAdded( newNode, id )

	print("CREATED NODE: " .. id .. " : " .. tostring(newNode.nodeType.name))

	local b,e = pcall(function()
		local node = vgui.Create("BPNode", self.canvas)
		node:Setup( self.graph, newNode )

		local x,y = node:GetPos()
		node:SetPos( x + canvasBack, y + canvasBack )
		node.canvasBack = canvasBack
		--table.insert( self.nodes, node )
		self.nodes[id] = node
	end)

end

function PANEL:NodeRemoved( node, id )

	print("NODE REMOVE: " .. node.id .. ", " .. id)

	self.nodes[id]:Remove()
	table.remove( self.nodes, id )

end

function PANEL:NodeRemap( node, oldID, newID )

	print("NODE REMAP[" .. node.id .. "]: " .. oldID .. " => " .. newID)
	self.nodes[oldID].nodeID = newID

end

function PANEL:NodeMove( node, nodeID, x, y )

	self.nodes[nodeID]:SetPos(x + canvasBack, y + canvasBack)

end

function PANEL:ConnectionAdded( newConnection, id )

	--self.connections[id] = newConnection
	table.insert( self.connections, newConnection )

end

function PANEL:ConnectionRemap( connection, id )

	self.connections[id] = connection

end

function PANEL:ConnectionRemoved( connection, id )

	--self.connections[id] = nil
	table.remove( self.connections, id )

end

function PANEL:SetGraph( graph )

	for k,v in pairs(self.nodes or {}) do
		if IsValid(v) then v:Remove() end
	end

	if self.graph then
		self.graph:RemoveListener(self.callback)
	end

	self.nodes = {}
	self.connections = {}
	self.graph = graph
	self.scroll_x = 0
	self.scroll_y = 0

	print("ALL: " .. tostring(CB_ALL))

	graph:AddListener(self.callback, bpgraph.CB_ALL)


end

local function CubicHermite(p0, p1, m0, m1, t)
	local tS = t*t;
	local tC = tS*t;

	return (2*tC - 3*tS + 1)*p0 + (tC - 2*tS + t)*m0 + (-2*tC + 3*tS)*p1 + (tC - tS)*m1
end

local function ClosestDistanceToCubicHermite(k, p0, p1, m0, m1)

end

local function drawHermite(x0,y0,x1,y1,c0,c1,samples)

	local px = x0
	local py = y0

	samples = samples or 20

	local dx = (x1 - x0)
	local dy = (y1 - y0)

	local d = math.sqrt(math.max(dx*dx, 8000), dy*dy) * 2
	d = math.min(d, 400)

	for i=1, samples do

		local t = i/samples

		t = CubicHermite(0, 1, .01, .01, t)

		local c = Color(
			Lerp(t, c0.r, c1.r),
			Lerp(t, c0.g, c1.g), 
			Lerp(t, c0.b, c1.b), 
		c0.a)

		local x = CubicHermite(x0, x1, d, d, t)
		local y = CubicHermite(y0, y1, 0, 0, t)
		x = math.Round(x)
		y = math.Round(y)

		surface.SetDrawColor(c)
		surface.DrawLine(px, py, x, y)

		px = x
		py = y

	end

end

function PANEL:OnPinGrab( vnode, vpin, grabbing )

	print("GRAB PIN: " .. vpin.pin[3] .. "  " .. tostring(grabbing))

	if grabbing then

		self.grabbedPin = vpin

		if input.IsKeyDown( KEY_LCONTROL ) then

			--self.rerouteConnection = true

			self.grabbedPin = nil
			for k,v in pairs(self.connections) do

				if v[1] == vnode.node.id and v[2] == vpin.pinID then

					self.graph:RemoveConnectionID(k)
					return

				elseif v[3] == vnode.node.id and v[4] == vpin.pinID then

					self.graph:RemoveConnectionID(k)
					return

				end

			end

		end

	else

		if self.grabbedPin ~= nil and vpin ~= nil and self.grabbedPin ~= vpin then

			self.graph:ConnectNodes( 
				self.grabbedPin.vnode.nodeID, 
				self.grabbedPin.pinID,
				vpin.vnode.nodeID,
				vpin.pinID )

		end
		self.grabbedPin = nil
		self.rerouteConnection = false

	end

end

function PANEL:PinPos(pin)

	local x, y = pin:GetHotSpot()
	return self:ScreenToLocal(x, y)

end

function PANEL:DrawConnection(connection)

	local graph = self.graph
	local a = self.nodes[connection[1]]
	local apin = connection[2]
	local b = self.nodes[connection[3]]
	local bpin = connection[4]

	local avpin = a:GetPin( apin )
	local bvpin = b:GetPin( bpin )

	local ax, ay = self:PinPos(avpin)
	local bx, by = self:PinPos(bvpin)

	--surface.SetDrawColor(NodePinColors[ a.nodeType.pins[connection[2]][2] ])

	drawHermite( ax, ay, bx, by, 
		NodePinColors[ a.node.nodeType.pins[connection[2]][2] ], 
		NodePinColors[ b.node.nodeType.pins[connection[4]][2] ] 
	)

end

function PANEL:DrawConnections()

	for _, connection in pairs(self.connections) do

		--[[if self.grabbedPin and self.rerouteConnection then

			if connection[1] == self.grabbedPin.node.id and connection[2] == self.grabbedPin.pinID then
				continue
			end

			if connection[3] == self.grabbedPin.node.id and connection[4] == self.grabbedPin.pinID then
				continue
			end

		end]]

		self:DrawConnection(connection)
	end

	if self.grabbedPin then

		if self.grabbedPin.pin[1] == PD_In then
		
			local ax, ay = self:ScreenToLocal(gui.MouseX(), gui.MouseY())
			local bx, by = self:PinPos(self.grabbedPin)

			drawHermite( ax, ay, bx, by, 
				Color(255,255,255),
				NodePinColors[ self.grabbedPin.pin[2] ]
			)

		else

			local ax, ay = self:PinPos(self.grabbedPin)
			local bx, by = self:ScreenToLocal(gui.MouseX(), gui.MouseY())

			drawHermite( ax, ay, bx, by, 
				NodePinColors[ self.grabbedPin.pin[2] ],
				Color(255,255,255)
			)

		end

	end

end

function PANEL:Paint(w, h)

	draw.RoundedBox(6, 0, 0, w, h, Color(40,40,40))
	self:DrawConnections()
	return true

end

function PANEL:Rebuild()

	self.canvas:SizeToChildren( true, true )

end

function PANEL:SizeToContents()

	self:SetSize( self.canvas:GetSize() )

end

function PANEL:PerformLayout()

	self:Rebuild()

end

function PANEL:Think()

	local mousex = math.Clamp( gui.MouseX(), 1, ScrW() - 1 )
	local mousey = math.Clamp( gui.MouseY(), 1, ScrH() - 1 )
	local lock = false

	if self.Dragging then

		local x = mousex - self.Dragging[1]
		local y = mousey - self.Dragging[2]

		local px, py = self.canvas:GetPos()
		self.canvas:SetPos( x, y )

	end

end

function PANEL:OpenContext()

	self:CloseContext()
	self.menu = DermaMenu( false, self )

	local x, y = gui.MouseX(), gui.MouseY()

	local options = {}
	for k,v in pairs(NodeTypes) do
		table.insert(options, k)
	end

	table.sort(options)
	for k,v in pairs(options) do
		self.menu:AddOption( v, function() 

			x, y = self.canvas:ScreenToLocal(x, y)

			self.graph:AddNode({
				nodeType = NodeTypes[v],
				x = x - canvasBack,
				y = y - canvasBack,
			})

		end )
	end

	

	self.menu:SetMinimumWidth( 300 )
	self.menu:Open( x, y, false, self )

end

function PANEL:CloseContext()

	if ( IsValid( self.menu ) ) then
		self.menu:Remove()
	end

end

function PANEL:OnMousePressed( mouse )

	self:RequestFocus()


	if mouse ~= MOUSE_RIGHT then return end

	local screenX, screenY = self:LocalToScreen( 0, 0 )

	self.PressTimeout = RealTime()
	self.Dragging = { gui.MouseX() - self.canvas.x, gui.MouseY() - self.canvas.y }
	self:MouseCapture( true )

end

function PANEL:OnMouseReleased( mouse )

	if self.grabbedPin then
		self.rerouteConnection = false
		self.grabbedPin = nil
	end

	if mouse ~= MOUSE_RIGHT then return end

	self.Dragging = nil
	self.Sizing = nil
	self:MouseCapture( false )

	if RealTime() - self.PressTimeout < 0.2 then
		self:OpenContext()
	end

end

vgui.Register( "BPGraph", PANEL, "DPanel" )
