if SERVER then AddCSLuaFile() return end

module("bpuiviewport2d", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local PANEL = {}

local MD_None = 0
local MD_Left = 1
local MD_Right = 2
local MD_Middle = 4

AccessorFunc( PANEL, "m_bIsLocked",	"IsLocked", FORCE_BOOL )

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetMouseInputEnabled( true )
	self:SetKeyboardInputEnabled( true )
	self:SetBackgroundColor( Color(40,40,40) )
	self:NoClipping(true)

	self.zoomTime = 0
	self.mouseDragging = 0
	self.PressTimeout = 0

	self:InitRenderer()

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

function PANEL:CenterOnPoint(x, y)

	self.renderer:Calculate()
	self.renderer:SetScroll(-x,-y)

end

function PANEL:DoCenterToOrigin()

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

	return true

end

function PANEL:PaintOver(w, h)

	self:UpdateScroll()

	local x, y = self:LocalToScreen(0,0)
	self.renderer:Draw(x,y,w,h)

	self:DrawOverlay()

	if self:GetIsLocked() then 

		draw.RoundedBox(0, 0, 0, w, h, Color(20,20,20,150))

	end

end

function PANEL:Draw2D()

end

function PANEL:DrawOverlay()

end

function PANEL:EditThink() end
function PANEL:Think()

	if bit.band(self.mouseDragging, MD_Left) ~= 0 and not input.IsMouseDown(MOUSE_LEFT) then
		self:OnMouseReleased(MOUSE_LEFT)
	end

	self:EditThink()

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

function PANEL:LeftMouse(x,y,pressed) end
function PANEL:RightMouse(x,y,pressed) end
function PANEL:MiddleMouse(x,y,pressed) end
function PANEL:RightClick() end
function PANEL:AnyPress() end

function PANEL:OnMousePressed( mouse )

	self:AnyPress()
	self:RequestFocus()

	local mx, my = self:GetMousePos()

	if mouse == MOUSE_LEFT then self.mouseDragging = bit.bor(self.mouseDragging, MD_Left) end
	if mouse == MOUSE_RIGHT then self.mouseDragging = bit.bor(self.mouseDragging, MD_Right) end
	if mouse == MOUSE_MIDDLE then self.mouseDragging = bit.bor(self.mouseDragging, MD_Middle) end

	if mouse == MOUSE_LEFT then if self:LeftMouse(mx,my,true) then return true end end
	if mouse == MOUSE_RIGHT then if self:RightMouse(mx,my,true) then return true end end
	if mouse == MOUSE_MIDDLE then if self:MiddleMouse(mx,my,true) then return true end end

	if mouse ~= MOUSE_RIGHT then return end

	local scrollX, scrollY = self.renderer:GetScroll()

	self.PressTimeout = RealTime()
	self.Dragging = true
	self.mouseDelta = { mx, my }
	self:MouseCapture( true )

end

function PANEL:OnMouseReleased( mouse )

	local mx, my = self:GetMousePos()

	if mouse == MOUSE_LEFT then self.mouseDragging = bit.band(self.mouseDragging, bit.bnot(MD_Left)) end
	if mouse == MOUSE_RIGHT then self.mouseDragging = bit.band(self.mouseDragging, bit.bnot(MD_Right)) end
	if mouse == MOUSE_MIDDLE then self.mouseDragging = bit.band(self.mouseDragging, bit.bnot(MD_Middle)) end

	if mouse == MOUSE_LEFT then self:LeftMouse(mx,my,false) end
	if mouse == MOUSE_RIGHT then self:RightMouse(mx,my,false) end
	if mouse == MOUSE_MIDDLE then self:MiddleMouse(mx,my,false) end

	if mouse ~= MOUSE_RIGHT then return end

	if RealTime() - (self.LastRelease or 0) < 0.2 then --[[print("DEBOUNCED")]] self.Dragging = false return end
	if RealTime() - self.PressTimeout < 0.2 then
		self:RightClick()
	end

	self.Dragging = false
	self.LastRelease = RealTime()
	self:MouseCapture( false )

end

function PANEL:OnMouseWheeled( delta )

	local x, y = self:LocalToScreen(0,0)
	local mousex = gui.MouseX()-x
	local mousey = gui.MouseY()-y

	self:SetZoomLevel( self:GetZoomLevel() - delta, mousex, mousey )

end

derma.DefineControl( "BPViewport2D", "Blueprint viewport renderer", PANEL, "DPanel" )
