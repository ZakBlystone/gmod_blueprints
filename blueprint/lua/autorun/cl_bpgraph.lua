if SERVER then AddCSLuaFile() return end

include("cl_bpnode.lua")
include("cl_bppin.lua")

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("sh_bpgraph.lua")

module("bpuigraph", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local PANEL = {}

surface.CreateFont( "GraphTitle", {
	font = "Arial", -- Use the font-name which is shown to you by your operating system Font Viewer, not the file name
	extended = false,
	size = 52,
	weight = 1200,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )

AccessorFunc( PANEL, "m_bIsLocked",	"IsLocked", FORCE_BOOL )

local canvasFix = 50000

function PANEL:Init()

	self:SetMouseInputEnabled( true )
	self:SetBackgroundColor( Color(40,40,40) )

	self.callback = function(...)
		self:OnGraphCallback(...)
	end

	self.nodes = {}
	self.titleText = "Blueprint"
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
	self.canvas.Paint = function( canvas, ... )

		self:CanvasPaint(...)

	end

	self.canvas:SetPos(-canvasFix,-canvasFix)

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
	if cb == CB_NODE_MOVE then return self:NodeMove(...) end
	if cb == CB_CONNECTION_ADD then return self:ConnectionAdded(...) end
	if cb == CB_CONNECTION_REMOVE then return self:ConnectionRemoved(...) end
	if cb == CB_GRAPH_CLEAR then return self:GraphCleared(...) end

end

function PANEL:NodeAdded( id )

	local node = vgui.Create("BPNode", self.canvas)
	node:Setup( self.graph, self.graph:GetNode(id) )
	node.canvasFix = canvasFix

	local x,y = node:GetPos()
	node:SetPos( x + canvasFix, y + canvasFix )
	self.nodes[id] = node

end

function PANEL:NodeRemoved( id )

	self.nodes[id]:Remove()
	self.nodes[id] = nil

end

function PANEL:NodeMove( id, x, y )

	self.nodes[id]:SetPos(x + canvasFix, y + canvasFix)

end

function PANEL:ConnectionAdded( id ) end
function PANEL:ConnectionRemoved( id ) end

function PANEL:GraphCleared()

	for k,v in pairs(self.nodes or {}) do
		if IsValid(v) then v:Remove() end
	end

	self.nodes = {}
	self.scroll_x = 0
	self.scroll_y = 0

end

function PANEL:SetGraph( graph )

	for k,v in pairs(self.nodes or {}) do
		if IsValid(v) then v:Remove() end
	end

	if self.graph then
		self.graph:RemoveListener(self.callback)
	end

	self.nodes = {}
	self.graph = graph
	self.scroll_x = 0
	self.scroll_y = 0
	self.id = graph.id

	graph:AddListener(self.callback, bpgraph.CB_ALL)

	for id in self.graph:NodeIDs() do self:NodeAdded(id) end


end

local function CubicHermite(p0, p1, m0, m1, t)
	local tS = t*t;
	local tC = tS*t;

	return (2*tC - 3*tS + 1)*p0 + (tC - 2*tS + t)*m0 + (-2*tC + 3*tS)*p1 + (tC - tS)*m1
end

local function ClosestDistanceToCubicHermite(k, p0, p1, m0, m1)

end

function PANEL:DrawHermite(x0,y0,x1,y1,c0,c1,samples)

	local w,h = self:GetSize()

	if x0 < 0 and x1 < 0 then return end
	if x0 > w and x1 > w then return end
	if y0 < 0 and y1 < 0 then return end
	if y0 > h and y1 > h then return end

	--print(x0)

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
			for k,v in self.graph:Connections() do

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

	local apintype = graph:GetPinType( connection[1], connection[2] )
	local bpintype = graph:GetPinType( connection[3], connection[4] )

	self:DrawHermite( ax, ay, bx, by, 
		NodePinColors[ apintype ], 
		NodePinColors[ bpintype ] 
	)

end

function PANEL:DrawConnections()

	for _, connection in self.graph:Connections() do

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

			self:DrawHermite( ax, ay, bx, by, 
				Color(255,255,255),
				NodePinColors[ self.grabbedPin.pin[2] ]
			)

		else

			local ax, ay = self:PinPos(self.grabbedPin)
			local bx, by = self:ScreenToLocal(gui.MouseX(), gui.MouseY())

			self:DrawHermite( ax, ay, bx, by, 
				NodePinColors[ self.grabbedPin.pin[2] ],
				Color(255,255,255)
			)

		end

	end

end

function PANEL:CanvasPaint(w, h)

end

function PANEL:DrawGrid(spacing, color)

	local x,y = self.canvas:GetPos()
	local w,h = self:GetSize()

	local scrollX = math.fmod(x, spacing)
	local scrollY = math.fmod(y, spacing)

	for xoff = 0, w, spacing do
		surface.SetDrawColor(color)
		surface.DrawRect(scrollX + xoff,0,2,h)
	end

	for yoff = 0, h, spacing do
		surface.SetDrawColor(color)
		surface.DrawRect(0,scrollY + yoff,w,2)
	end

end

function PANEL:Paint(w, h)

	draw.RoundedBox(0, 0, 0, w, h, Color(40,40,40))

	self:DrawGrid(15, Color(255,255,255,2))
	self:DrawGrid(90, Color(255,255,255,5))

	draw.SimpleText( self.graph:GetTitle(), "GraphTitle", 10, 10, Color( 255, 255, 255, 60 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

	local b,e = pcall( function()
		self:DrawConnections()
	end )

	if e and not self.errored then
		self.errored = true
		ErrorNoHalt( e )
	end

	return true

end

function PANEL:PaintOver(w, h)

	if self:GetIsLocked() then 

		draw.RoundedBox(0, 0, 0, w, h, Color(20,20,20,150))

	end

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

	if self:GetIsLocked() then return end

	self:CloseContext()
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
	createMenu:Setup( self.graph )
	createMenu.OnNodeTypeSelected = function( menu, nodeType )

		x, y = self.canvas:ScreenToLocal(x, y)

		self.graph:AddNode(nodeType.name, x - canvasFix, y - canvasFix)
	end
	--createMenu:SetKeyboardInputEnabled(true)
	--createMenu:SetMouseInputEnabled(true)

	self.menu = createMenu

	--self.menu:AddPanel(createMenu)
	

	--self.menu:SetMinimumWidth( 300 )
	--self.menu:Open( x, y, false, self )

end

function PANEL:CloseContext()

	if ( IsValid( self.menu ) ) then
		self.menu:Remove()
	end

end

function PANEL:OnRemove()

	self:CloseContext()

end

function PANEL:OnMousePressed( mouse )

	self:RequestFocus()
	self:CloseContext()

	if mouse ~= MOUSE_RIGHT then return end

	local screenX, screenY = self:LocalToScreen( 0, 0 )

	self.PressTimeout = RealTime()
	self.Dragging = { gui.MouseX() - self.canvas.x, gui.MouseY() - self.canvas.y }
	self:MouseCapture( true )

end

function PANEL:OnMouseReleased( mouse )

	if mouse == MOUSE_LEFT then
		if self.grabbedPin then
			self.rerouteConnection = false
			self.grabbedPin = nil
		end
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
