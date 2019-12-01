if SERVER then AddCSLuaFile() return end

include("cl_bpgraphnode.lua")

module("bpuigraph2", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local PANEL = {}

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

local MD_None = 0
local MD_Left = 1
local MD_Right = 2
local MD_Middle = 4

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetMouseInputEnabled( true )
	self:SetKeyboardInputEnabled( true )
	self:SetBackgroundColor( Color(40,40,40) )
	self:NoClipping(true)

	self.zoomTime = 0
	self.mouseDragging = 0

	self.callback = function(...)
		local editor = self:GetEditor()
		if editor == nil then return end
		editor:OnGraphCallback(...)
	end

	self:InitRenderer()

end

function PANEL:OnRemove()

	if self.graph then
		self.graph:RemoveListener(self.callback)
	end

end

function PANEL:GetGraph()

	return self.graph

end

function PANEL:GetEditor()

	return self.editor

end

function PANEL:SetGraph( graph )

	if self.graph then self.graph:RemoveListener(self.callback) end

	self.graph = graph

	graph:AddListener(self.callback, bpgraph.CB_ALL)

	self.editor = bpgrapheditor.New( self )
	self.interface = bpgrapheditorinterface.New( self.editor, self )

	self.editor:CreateAllNodes()
	self:CenterToOrigin()

end

function PANEL:InitRenderer()

	self.renderer = bprender2d.New(self)
	self.renderer.Draw2D = function(renderer) self:Draw2D() end

	local x, y = self:LocalToScreen(0,0)
	local w, h = self:GetSize()

	self.renderer:ViewCalculate(x,y,w,h)
	self.renderer:SetZoom( 16 )

end

function PANEL:GetRenderer()

	return self.renderer

end

function PANEL:PostAutoRefresh()

	self:InitRenderer()
	self:CenterToOrigin()
	if self.editor ~= nil then self.editor:CreateAllNodes() end

end

function PANEL:CenterToOrigin()

	self.pendingCenterToOrigin = true

end

function PANEL:ViewCalculate()

	local x, y = self:LocalToScreen(0,0)
	local w, h = self:GetSize()

	self.renderer:ViewCalculate(x,y,w,h)

end

function PANEL:DoCenterToOrigin()

	print(self:GetSize())

	self:ViewCalculate()
	self.renderer:SetScroll(0,0)
	self.renderer:Calculate()
	local x,y = self.renderer:PointToWorld(0,0)
	self.renderer:SetScroll(x,y)
	self.renderer:Calculate()

end

function PANEL:GetZoomLevel()

	return ((self.renderer:GetZoom() - 16) / 8)

end

function PANEL:SetZoomLevel( zoomLevel, pivotX, pivotY )

	zoomLevel = math.Clamp(zoomLevel, -3, 8)

	local z = (zoomLevel * 8) + 16

	local x0,y0 = self.renderer:PointToWorld(pivotX, pivotY)
	self.renderer:SetZoom( z )
	self.renderer:Calculate()
	local x1,y1 = self.renderer:PointToWorld(pivotX, pivotY)
	local sx, sy = self.renderer:GetScroll()
	self.renderer:SetScroll(sx + (x1-x0),sy + (y1-y0))

	self.zoomTime = CurTime()

end

function PANEL:OnMouseWheeled( delta )

	local x, y = self:LocalToScreen(0,0)
	local mousex = gui.MouseX()-x
	local mousey = gui.MouseY()-y

	self:SetZoomLevel( self:GetZoomLevel() + delta, mousex, mousey )

end

function PANEL:Draw2D()

	if self.interface ~= nil then self.interface:Draw(self:GetSize()) end

end

function PANEL:PerformLayout()

	local w,h = self:GetSize()

	-- Sometimes the panel hasn't been sized yet, so wait until it is
	if w > 100 or h > 100 then

		if self.pendingCenterToOrigin then
			self:DoCenterToOrigin()
			self.pendingCenterToOrigin = false
		end

	end

end

function PANEL:Paint(w, h)

	self:UpdateScroll()

	local x, y = self:LocalToScreen(0,0)

	self.renderer:Draw(x,y,w,h)
	if self.interface ~= nil then self.interface:DrawOverlay(self:GetSize()) end


	return true

end

function PANEL:PaintOver(w, h)

	if self:GetIsLocked() then 

		draw.RoundedBox(0, 0, 0, w, h, Color(20,20,20,150))

	end

end

function PANEL:Think()

	self.editor:Think()

	if bit.band(self.mouseDragging, MD_Left) ~= 0 and not input.IsMouseDown(MOUSE_LEFT) then
		self:OnMouseReleased(MOUSE_LEFT)
	end

end

function PANEL:OnRemove()

	self.editor:Cleanup()

end

function PANEL:UpdateScroll()

	local x, y = self:LocalToScreen(0,0)
	local mousex = gui.MouseX()-x
	local mousey = gui.MouseY()-y
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

function PANEL:GetMousePos(screen)

	local x, y = self:LocalToScreen(0,0)
	if screen then x = 0 y = 0 end

	local mx = gui.MouseX()-x
	local my = gui.MouseY()-y
	return mx, my

end

function PANEL:OnMousePressed( mouse )

	if self.editor == nil then return end

	self.editor:CloseCreationContext()

	self:RequestFocus()

	local mx, my = self:GetMousePos()

	if mouse == MOUSE_LEFT then self.mouseDragging = bit.bor(self.mouseDragging, MD_Left) end
	if mouse == MOUSE_RIGHT then self.mouseDragging = bit.bor(self.mouseDragging, MD_Right) end
	if mouse == MOUSE_MIDDLE then self.mouseDragging = bit.bor(self.mouseDragging, MD_Middle) end

	if mouse == MOUSE_LEFT then if self.editor:LeftMouse(mx,my,true) then return true end end
	if mouse == MOUSE_RIGHT then if self.editor:RightMouse(mx,my,true) then return true end end

	if mouse ~= MOUSE_RIGHT then return end

	local scrollX, scrollY = self.renderer:GetScroll()

	self.PressTimeout = RealTime()
	self.Dragging = true
	self.mouseDelta = { mx, my }
	self:MouseCapture( true )

end

function PANEL:OnMouseReleased( mouse )

	if self.editor == nil then return end

	local mx, my = self:GetMousePos()

	if mouse == MOUSE_LEFT then self.mouseDragging = bit.band(self.mouseDragging, bit.bnot(MD_Left)) end
	if mouse == MOUSE_RIGHT then self.mouseDragging = bit.band(self.mouseDragging, bit.bnot(MD_Right)) end
	if mouse == MOUSE_MIDDLE then self.mouseDragging = bit.band(self.mouseDragging, bit.bnot(MD_Middle)) end

	if mouse == MOUSE_LEFT then self.editor:LeftMouse(mx,my,false) end
	if mouse == MOUSE_RIGHT then self.editor:RightMouse(mx,my,false) end

	if mouse ~= MOUSE_RIGHT then return end

	if RealTime() - (self.LastRelease or 0) < 0.2 then print("DEBOUNCED") self.Dragging = false return end
	if RealTime() - self.PressTimeout < 0.2 then
		self.editor:OpenCreationContext()
	end

	self.Dragging = false
	self.LastRelease = RealTime()
	self:MouseCapture( false )

end

function PANEL:OnKeyCodePressed( code )

	if self.editor == nil then return end

	self.editor:KeyPress(code)

end

function PANEL:OnKeyCodeReleased( code )

	if self.editor == nil then return end

	self.editor:KeyRelease(code)

end

derma.DefineControl( "BPGraph2", "Blueprint graph renderer", PANEL, "DPanel" )
