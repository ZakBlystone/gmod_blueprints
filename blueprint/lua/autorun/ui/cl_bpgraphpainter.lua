if SERVER then AddCSLuaFile() return end

module("bpgraphpainter", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local BGMaterial = CreateMaterial("gridMaterial2", "UnLitGeneric", {
	["$basetexture"] = "dev/dev_measuregeneric01b",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
})

local meta = bpcommon.MetaTable("bpgraphpainter")

function meta:Init( editor, vgraph )

	self.editor = editor
	self.vgraph = vgraph
	return self

end

function meta:GetEditor() return self.editor end
function meta:GetVGraph() return self.vgraph end
function meta:PointToWorld(x,y) return self:GetVGraph():GetRenderer():PointToWorld(x,y) end
function meta:PointToScreen(x,y) return self:GetVGraph():GetRenderer():PointToScreen(x,y) end

function meta:DrawConnection(connection)

	local nodes = self:GetEditor():GetVNodes()
	local pw, ph = self:GetVGraph():GetSize()
	local a = nodes[connection[1]]
	local apin = connection[2]
	local b = nodes[connection[3]]
	local bpin = connection[4]

	if a == nil or b == nil then print("Invalid connection") return end

	local ax, ay = a:GetPinSpotLocation(apin)
	local bx, by = b:GetPinSpotLocation(bpin)

	local x0,y0 = self:PointToScreen(ax,ay)
	local x1,y1 = self:PointToScreen(bx,by)

	local minX,maxX = math.min(x0,x1), math.max(x0,x1)
	local minY,maxY = math.min(y0,y1), math.max(y0,y1)

	if maxX < 0 or maxY < 0 then return false end
	if minX > pw or minY > ph then return false end

	local avpin = a:GetVPins()[apin]
	local bvpin = b:GetVPins()[bpin]

	if avpin == nil or bvpin == nil then print("Invalid connection pin") return end

	local apintype = avpin:GetPin()
	local bpintype = bvpin:GetPin()

	bprenderutils.DrawHermite( ax, ay, bx, by, 
		apintype:GetColor(), 
		bpintype:GetColor()
	)

	return true

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

function meta:GetDisplayName( nodeType )

	local name = nodeType.displayName or nodeType.name
	local sub = string.find(name, "[:.]")
	if sub then
		name = name:sub(sub+1, -1)
	end
	return name

end

function meta:DrawNode(vnode)

	local pw, ph = self:GetVGraph():GetSize()
	local x,y = vnode:GetPos()
	local w,h = vnode:GetSize()
	local x0,y0 = self:PointToScreen(x,y)
	local x1,y1 = self:PointToScreen(x+w,y+h)

	if x0 > pw or y0 > ph then return false end
	if x1 < 0 or y1 < 0 then return false end

	vnode:Draw()
	return true

end

function meta:DrawNodes() 

	local nodesDrawn = 0
	for _, vnode in pairs(self:GetEditor():GetVNodes()) do
		if self:DrawNode(vnode) then nodesDrawn = nodesDrawn + 1 end
	end
	--print("Nodes: " .. nodesDrawn)

end

function meta:DrawConnections()

	local connectionsDrawn = 0
	for _, connection in self:GetEditor():GetGraph():Connections() do
		if self:DrawConnection(connection) then connectionsDrawn = connectionsDrawn + 1 end
	end
	--print("Connections: " .. connectionsDrawn)

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

function meta:Draw(w,h)

	surface.SetDrawColor(Color(80,80,80,255))
	self:DrawGrid(BGMaterial, 15, 2)

	surface.SetDrawColor(Color(150,150,150,80))
	self:DrawGrid(BGMaterial, 15, 8)

	self:DrawConnections()
	self:DrawNodes()
	self:DrawGrabbedLine()

	surface.SetMaterial(BGMaterial)
	surface.SetDrawColor(Color(255,255,255))
	surface.DrawTexturedRectUV( 0, 0, 15, 15, 0, 0, 1, 1 )

	local editor = self:GetEditor()
	if editor:IsDragSelecting() then
		local border = 4
		local x,y,w,h = editor:GetSelectionRect()
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

end

function New(...) return bpcommon.MakeInstance(meta, ...) end