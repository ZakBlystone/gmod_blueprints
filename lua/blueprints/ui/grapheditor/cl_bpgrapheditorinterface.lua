if SERVER then AddCSLuaFile() return end

module("bpgrapheditorinterface", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local BGMaterial = CreateMaterial("gridMaterial2", "UnLitGeneric", {
	["$basetexture"] = "dev/dev_measuregeneric01b",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
})

local meta = bpcommon.MetaTable("bpgrapheditorinterface")

local TOOLTIP_TIME = .6
local TOOLTIP_FONT = "HudHintTextLarge"
local TOOLTIP_MAXWIDTH = 400
local POPUP_TIME = 4

function meta:Init( editor, vgraph )

	self.editor = editor
	self.vgraph = vgraph
	self.graphPainter = bpgraphpainter.New(vgraph:GetGraph(), editor:GetNodeSet(), vgraph)
	self.hoverTimer = 0
	self.lastMouseX = 0
	self.lastMouseY = 0
	self.tooltipWrap = bptextwrap.New():SetFont(TOOLTIP_FONT):SetMaxWidth(TOOLTIP_MAXWIDTH)
	self.dragVarWrap = bptextwrap.New():SetFont(TOOLTIP_FONT):SetMaxWidth(TOOLTIP_MAXWIDTH)
	self.tooltip = false
	self.tooltipText = nil
	self.tooltipLocation = nil
	self.tooltipAlpha = 0
	self.popups = {}

	self.editor:Bind("popup", self, self.OnPopup)
	return self

end

function meta:GetEditor() return self.editor end
function meta:GetVGraph() return self.vgraph end
function meta:PointToWorld(x,y) return self:GetVGraph():GetRenderer():PointToWorld(x,y) end
function meta:PointToScreen(x,y) return self:GetVGraph():GetRenderer():PointToScreen(x,y) end

function meta:OnPopup(text)

	self.popups[#self.popups+1] = {text = text, time = POPUP_TIME}

end

function meta:DrawGrabbedLine()

	local editor = self:GetEditor()
	local pin = editor:GetGrabbedPin()
	if pin == nil then return end

	local mx, my = editor:GetGrabbedPinPos()
	local ax,ay = pin:GetVNode():GetPinSpotLocation(pin:GetPinID())
	local apintype = pin:GetPin()

	if apintype:IsOut() then
		bprenderutils.DrawHermite( ax, ay, mx, my, 
			apintype:GetColor(),
			Color(255,255,255)
		)
	else
		bprenderutils.DrawHermite( mx, my, ax, ay, 
			Color(255,255,255),
			apintype:GetColor()
		)
	end

end

function meta:GetZoomString()

	local zoom = self:GetVGraph():GetZoomLevel()
	if zoom > 0 then return "-" .. math.abs(zoom) end
	return "+" .. math.abs(zoom)

end

function meta:PaintGraphTitle(w,h)

	local title = self:GetEditor():GetGraph():GetTitle()
	draw.SimpleText( title, "GraphTitle", 10, 10, Color( 255, 255, 255, 60 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

end

function meta:PaintZoomIndicator(w,h)

	local dt = 1 - (CurTime() - self:GetVGraph().zoomTime) / 2
	if dt < 0 then return end

	draw.SimpleText( "Zoom: " .. self:GetZoomString(), "NodePinFont", 10, h - 30, Color( 255, 255, 255, 60 * dt ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

end

function meta:PaintPopups(w,h)

	--[[self.ptimer = self.ptimer or CurTime() + .05
	if self.ptimer < CurTime() then
		self.ptimer = CurTime() + .05
		self:OnPopup("Popup " .. CurTime())
	end]]

	local font = "NodePinFont"
	local x = w - ScreenScale(5)
	local y = h - ScreenScale(8)
	local ft = FrameTime()
	local n = 1
	
	surface.SetFont(font)
	for i=#self.popups, 1, -1 do

		local v = self.popups[i]
		v.time = v.time - ft
		v.flash = (v.flash or 1) - ft

		if n > 5 then v.time = v.time - ft * 2 end
		if n > 8 then v.time = v.time - ft * 2 end
		if n > 10 then v.time = v.time - ft * 2 end

		if v.time <= 0 then table.remove(self.popups, i) continue end

		local fadeout = (math.min(v.time, 1)) ^ 3
		local flash = math.max(v.flash, 0)

		local tw, th = surface.GetTextSize( v.text )

		draw.RoundedBox(6, x - tw - 5, y - th - 5, tw + 10, th + 10, Color(0,0,0,150 * fadeout))
		draw.SimpleText( v.text, font, x, y, Color( 255, 255 - flash * 80, 255 - flash * 200, 200 * fadeout + flash * 50 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
		y = y - 50
		n = n + 1

	end

end

function meta:DrawGrid( material, pixelGridUnits, textureGridDivisions )

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

function meta:GetTooltipUnderCursor(mx, my)

	local vnode = self:GetEditor():TryGetNode( mx, my )
	if vnode then

		local vpin = self:GetEditor():TryGetNodePin( vnode, mx, my )

		if vpin then
			return vpin:GetPin():GetDescription()
		end

		return vnode:GetNode():GetDescription()

	end

end

function meta:DrawTooltip()

	local mx, my = self:PointToWorld(self:GetVGraph():GetMousePos())

	if mx == self.lastMouseX and my == self.lastMouseY then
		self.hoverTimer = self.hoverTimer + FrameTime()
		if self.hoverTimer > TOOLTIP_TIME and not self.tooltip then
			self.tooltip = true
			self.tooltipLocation = {mx, my}
			self.tooltipText = self:GetTooltipUnderCursor(mx, my)
			self.tooltipWrap:SetText( self.tooltipText )
		end
	else
		self.tooltip = false
		self.hoverTimer = 0
	end

	self.lastMouseX = mx
	self.lastMouseY = my

	local dt = FrameTime()
	if self.tooltip then

		self.tooltipAlpha = Lerp(1 - math.exp(dt * -10), self.tooltipAlpha, 1)

	else

		self.tooltipAlpha = Lerp(1 - math.exp(dt * -10), self.tooltipAlpha, 0)

	end

	if self.tooltipLocation and self.tooltipText then

		local sx, sy = self:PointToScreen( unpack(self.tooltipLocation) )
		local font = "HudHintTextLarge"
		local alpha = self.tooltipAlpha

		sy = sy + 20 * (1-alpha)

		--[[surface.SetFont(font)
		local tw, th = surface.GetTextSize( self.tooltipText )

		draw.RoundedBox(6, sx - 5, sy - 5, tw + 10, th + 10, Color(0,0,0,255 * alpha))
		draw.SimpleText( self.tooltipText, font, sx, sy - 1, Color( 255, 255, 255, 255 * alpha ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )]]

		local tw, th = self.tooltipWrap:GetSize()

		sx = sx + 20
		sy = sy + 20

		sx, sy = self.vgraph:LocalToScreen(sx, sy)

		if sx + tw > ScrW() - 20 then sx = sx - (tw + 40) end
		if sy + th > ScrH() - 20 then sy = sy - (th + 40) end

		sx, sy = self.vgraph:ScreenToLocal(sx, sy)

		draw.RoundedBox(6, sx - 5, sy - 5, tw + 10, th + 10, Color(0,0,0,255 * alpha))
		self.tooltipWrap:Draw(sx, sy, 255, 255, 255, 255 * alpha)

	end

end

function meta:DrawDragged()

	if G_BPDraggingElement then

		local v = G_BPDraggingElement
		local mx, my = self:GetVGraph():GetMousePos()

		self.dragVarWrap:SetText(v:GetName())

		local tw, th = self.dragVarWrap:GetSize()
		my = my - th

		draw.RoundedBox(6, mx - 5, my - 5, tw + 10, th + 10, Color(0,0,0,255))

		self.dragVarWrap:Draw(mx, my, 255, 255, 255, 255)

	end

end

function meta:Draw(w,h)

	surface.SetDrawColor(Color(80,80,80,255))
	self:DrawGrid(BGMaterial, 16, 2)

	surface.SetDrawColor(Color(150,150,150,80))
	self:DrawGrid(BGMaterial, 16, 8)

	-- Draw graph here
	self.graphPainter:Draw()

	local copyInfo = self:GetEditor():GetGraphCopy()
	if copyInfo then
		local mx, my = self:PointToWorld(self:GetVGraph():GetMousePos())
		mx = math.Round(mx / 15) * 15
		my = math.Round(my / 15) * 15
		copyInfo.painter:Draw(mx - copyInfo.x, my - copyInfo.y, .5)
	end

	self:DrawGrabbedLine()

	--surface.SetMaterial(BGMaterial)
	--surface.SetDrawColor(Color(255,255,255))
	--surface.DrawTexturedRectUV( 0, 0, 15, 15, 0, 0, 1, 1 )

	local editor = self:GetEditor()
	if editor:IsDragSelecting() then

		local vgraph = self:GetVGraph()
		local ox, oy = vgraph:LocalToScreen(0,0)

		local border = 4
		local x,y,w,h = editor:GetSelectionRect()
		x = x - ox
		y = y - oy
		surface.SetDrawColor(Color(120,150,255,20))
		surface.DrawRect(x,y,w,h)

		surface.SetDrawColor(Color(255,255,255,40))
		surface.DrawRect(x,y,w,border)
		surface.DrawRect(x+border,y+h-border,w-border,border)
		surface.DrawRect(x,y+border,border,h-border)
		surface.DrawRect(x+w-border,y+border,border,h-border)
	end

end

function meta:DrawOverlay(w,h)

	self:PaintGraphTitle(w,h)
	self:PaintZoomIndicator(w,h)
	self:PaintPopups(w,h)
	self:DrawTooltip()
	self:DrawDragged()

end

function New(...) return bpcommon.MakeInstance(meta, ...) end