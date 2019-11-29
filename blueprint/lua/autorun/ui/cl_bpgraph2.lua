if SERVER then AddCSLuaFile() return end

include("cl_bpgraphnode.lua")

module("bpuigraph2", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local PANEL = {}
local BGMaterial = CreateMaterial("gridMaterial2", "UnLitGeneric", {
	["$basetexture"] = "dev/dev_measuregeneric01b",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
})

AccessorFunc( PANEL, "m_bIsLocked",	"IsLocked", FORCE_BOOL )

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

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetMouseInputEnabled( true )
	self:SetBackgroundColor( Color(40,40,40) )
	self:NoClipping(true)

	self.callback = function(...)
		self:OnGraphCallback(...)
	end

	self.nodes = {}
	self.titleText = "Blueprint"
	self:InitRenderer()

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

	local vnode = bpuigraphnode.New( self.graph:GetNode(id), self.graph )
	table.insert(self.nodes, vnode)

end

function PANEL:NodeRemoved( id )

end

function PANEL:NodeMove( id, x, y ) end
function PANEL:ConnectionAdded( id ) end
function PANEL:ConnectionRemoved( id ) end
function PANEL:GraphCleared() end

function PANEL:SetGraph( graph )

	if self.graph then
		self.graph:RemoveListener(self.callback)
	end

	self.graph = graph

	graph:AddListener(self.callback, bpgraph.CB_ALL)

	self:CreateAllNodes()

end

function PANEL:DrawConnection(connection)

	local graph = self.graph
	local a = graph:GetNode(connection[1])
	local apin = connection[2]
	local b = graph:GetNode(connection[3])
	local bpin = connection[4]

	local avpin = a:GetPin( apin )
	local bvpin = b:GetPin( bpin )

	local ax, ay = pinLocation(self, a, apin, avpin)
	local bx, by = pinLocation(self, b, bpin, bvpin)

	local apintype = graph:GetPinType( connection[1], connection[2] )
	local bpintype = graph:GetPinType( connection[3], connection[4] )

	bprenderutils.DrawHermite( ax, ay, bx, by, 
		NodePinColors[ apintype ], 
		NodePinColors[ bpintype ] 
	)

end

function PANEL:GetDisplayName( nodeType )

	local name = nodeType.displayName or nodeType.name
	local sub = string.find(name, "[:.]")
	if sub then
		name = name:sub(sub+1, -1)
	end
	return name

end

function PANEL:DrawPin( node, pinID )

	local ntype = node:GetType()
	local pin = node:GetPin(pinID)
	local x, y = pinLocation(self, node, pinID, pin)

	local ptc = NodePinColors[ pin[2] ]
	draw.RoundedBox(1, pin[1] == PD_In and x or x-10, y-5, 10, 10, ptc)

	if not ntype.compact then
		if pin[1] == PD_In then
			draw.SimpleText(pin[3], "Default", x+15, y, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(pin[3], "Default", x-15, y, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

end

function PANEL:DrawNodes() 

	for _, vnode in pairs(self.nodes) do
		vnode:Draw()
	end

end
function PANEL:DrawConnections() end

function PANEL:InitRenderer()

	self.renderer = bprender2d.New(self)
	self.renderer.Draw2D = function(renderer) self:Draw2D() end

end

function PANEL:PostAutoRefresh()

	self:InitRenderer()
	self:CreateAllNodes()

end

function PANEL:CreateAllNodes()
	
	self.nodes = {}
	for id in self.graph:NodeIDs() do self:NodeAdded(id) end

end

function PANEL:OnMouseWheeled( delta )

	local x, y = self:LocalToScreen(0,0)
	local mousex = math.Clamp( gui.MouseX()-x, 1, ScrW() - 1 )
	local mousey = math.Clamp( gui.MouseY()-y, 1, ScrH() - 1 )
	local x0,y0 = self.renderer:PointToWorld(mousex, mousey)
	self.renderer:SetZoom( self.renderer:GetZoom() + delta )
	self.renderer:Calculate()
	local x1,y1 = self.renderer:PointToWorld(mousex, mousey)
	local sx, sy = self.renderer:GetScroll()
	self.renderer:SetScroll(sx + (x1-x0),sy + (y1-y0))

end

function PANEL:DrawGrid( material, pixelGridUnits, textureGridDivisions )

	local size = 400000
	local texture = material:GetTexture("$basetexture")
	local tw = texture:GetMappingWidth()
	local th = texture:GetMappingHeight()

	local scale = (tw/pixelGridUnits) / textureGridDivisions

	local u0, v0 = 0,0
	local u1, v1 = (size*2 / tw) * scale, (size*2 / th) * scale

	u0 = u0 - (u1 % 1)
	v0 = v0 - (v1 % 1)

	local du = 0.5 / tw
	local dv = 0.5 / th
	u0, v0 = ( u0 - du ) / ( 1 - 2 * du ), ( v0 - dv ) / ( 1 - 2 * dv )
	u1, v1 = ( u1 - du ) / ( 1 - 2 * du ), ( v1 - dv ) / ( 1 - 2 * dv )

	surface.SetMaterial(material)
	surface.DrawTexturedRectUV( -size, -size, size*2, size*2, u0, v0, u1, v1 )

end

function PANEL:Draw2D()

	surface.SetDrawColor(Color(80,80,80,255))
	self:DrawGrid(BGMaterial, 15, 2)

	surface.SetDrawColor(Color(150,150,150,80))
	self:DrawGrid(BGMaterial, 15, 8)

	self:DrawConnections()
	self:DrawNodes()

	surface.SetDrawColor(Color(255,100,0))
	surface.DrawTexturedRectUV( 30, 0, 16, 16, 0, 0, 1, 1 )

end

function PANEL:Paint(w, h)

	self:UpdateScroll()

	local x, y = self:LocalToScreen(0,0)

	self.renderer:Draw(x,y,w,h)

	draw.SimpleText( self.graph:GetTitle(), "GraphTitle", 10, 10, Color( 255, 255, 255, 60 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

	return true

end

function PANEL:PaintOver(w, h)

	if self:GetIsLocked() then 

		draw.RoundedBox(0, 0, 0, w, h, Color(20,20,20,150))

	end

end

function PANEL:Think()

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

		x, y = self:ScreenToLocal(x, y)

		self.graph:AddNode(nodeType.name, x, y)
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

function PANEL:UpdateScroll()
	local x, y = self:LocalToScreen(0,0)
	local mousex = math.Clamp( gui.MouseX()-x, 1, ScrW() - 1 )
	local mousey = math.Clamp( gui.MouseY()-y, 1, ScrH() - 1 )
	local lock = false

	if self.Dragging then

		local dx = mousex - self.mouseDelta[1]
		local dy = mousey - self.mouseDelta[2]

		local x0,y0 = self.renderer:PointToWorld(self.mouseDelta[1], self.mouseDelta[2])
		local x1,y1 = self.renderer:PointToWorld(mousex, mousey)
		local sx, sy = self.renderer:GetScroll()
		self.renderer:SetScroll(sx + (x1-x0),sy + (y1-y0))

		self.mouseDelta[1] = mousex
		self.mouseDelta[2] = mousey

	end
end

function PANEL:OnMousePressed( mouse )

	self:CloseContext()

	if mouse ~= MOUSE_RIGHT then return end

	print("RIGHT PRESS: " .. RealTime())

	local x, y = self:LocalToScreen(0,0)
	local scrollX, scrollY = self.renderer:GetScroll()

	self.PressTimeout = RealTime()
	self.Dragging = true
	self.mouseDelta = { gui.MouseX()-x, gui.MouseY()-y }
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

	if RealTime() - (self.LastRelease or 0) < 0.2 then print("DEBOUNCED") self.Dragging = false return end
	if RealTime() - self.PressTimeout < 0.2 then
		self:OpenContext()
	end

	self.Dragging = false
	self.LastRelease = RealTime()
	self:MouseCapture( false )

end

derma.DefineControl( "BPGraph2", "Blueprint graph renderer", PANEL, "DPanel" )
