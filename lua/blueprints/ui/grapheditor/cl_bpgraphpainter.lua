if SERVER then AddCSLuaFile() return end

module("bpgraphpainter", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local render_PushFilterMag = render.PushFilterMag
local render_PushFilterMin = render.PushFilterMin
local render_PopFilterMag = render.PopFilterMag
local render_PopFilterMin = render.PopFilterMin
local BGMaterial = CreateMaterial("gridMaterial2", "UnLitGeneric", {
	["$basetexture"] = "dev/dev_measuregeneric01b",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
})

local meta = bpcommon.MetaTable("bpgraphpainter")

function meta:Init( graph, nodeSet, vgraph )

	self.graph = graph
	self.nodeSet = nodeSet
	self.vgraph = vgraph
	return self

end

function meta:GetGraph() return self.graph end
function meta:GetNodeSet() return self.nodeSet end
function meta:GetVGraph() return self.vgraph end
function meta:PointToWorld(x,y) return self:GetVGraph():GetRenderer():PointToWorld(x,y) end
function meta:PointToScreen(x,y) return self:GetVGraph():GetRenderer():PointToScreen(x,y) end

function meta:DrawConnection(aPin, bPin, xOffset, yOffset, alpha)

	assert( isbppin(aPin), "Expected pin, got: " .. tostring(aPin) )
	assert( isbppin(bPin), "Expected pin, got: " .. tostring(bPin) )

	local nodes = self:GetNodeSet():GetVNodes()
	local pw, ph = self:GetVGraph():GetSize()
	local a = nodes[aPin:GetNode()]
	local apin = aPin.id
	local b = nodes[bPin:GetNode()]
	local bpin = bPin.id

	if a == nil or b == nil then return end --print("Invalid connection") 

	local ax, ay = a:GetPinSpotLocation(apin)
	local bx, by = b:GetPinSpotLocation(bpin)

	ax = ax + xOffset
	ay = ay + yOffset
	bx = bx + xOffset
	by = by + yOffset

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
		bpintype:GetColor(),
		alpha
	)

	return true

end

function meta:GetDisplayName( nodeType )

	local name = nodeType.displayName or nodeType.name
	local sub = string.find(name, "[:.]")
	if sub then
		name = name:sub(sub+1, -1)
	end
	return name

end

function meta:DrawNode(vnode, xOffset, yOffset, alpha)

	local pw, ph = self:GetVGraph():GetSize()
	local x,y = vnode:GetPos()
	local w,h = vnode:GetSize()
	local x0,y0 = self:PointToScreen(x,y)
	local x1,y1 = self:PointToScreen(x+w,y+h)

	if x0 > pw or y0 > ph then return false end
	if x1 < 0 or y1 < 0 then return false end

	vnode:Draw(xOffset, yOffset, alpha)
	return true

end

function meta:DrawNodes(xOffset, yOffset, alpha) 

	local vgraph = self:GetVGraph()
	local x, y = vgraph:LocalToScreen(0,0)

	xOffset = xOffset - x
	yOffset = yOffset - y

	local nodesDrawn = 0
	for _, vnode in pairs(self:GetNodeSet():GetVNodes()) do
		if self:DrawNode(vnode, xOffset, yOffset, alpha) then nodesDrawn = nodesDrawn + 1 end
	end
	--print("Nodes: " .. nodesDrawn)

end

function meta:DrawConnections(xOffset, yOffset, alpha)

	local connectionsDrawn = 0
	for _, vnode in pairs(self:GetNodeSet():GetVNodes()) do

		for pinID, pin in vnode:GetNode():SidePins(PD_Out) do

			for _, other in ipairs(pin:GetConnections()) do

				if other() ~= nil then
					if self:DrawConnection(pin, other(), xOffset, yOffset, alpha) then connectionsDrawn = connectionsDrawn + 1 end
				end

			end

		end

	end

end

function meta:Draw(xOffset, yOffset, alpha)

	if self:GetGraph() == nil then return end

	xOffset = xOffset or 0
	yOffset = yOffset or 0
	alpha = alpha or 1

	render_PushFilterMag( TEXFILTER.LINEAR )
	render_PushFilterMin( TEXFILTER.LINEAR )

	local b,e = pcall( function()

	self:DrawConnections(xOffset, yOffset, alpha)
	self:DrawNodes(xOffset, yOffset, alpha)

	end)

	render_PopFilterMag()
	render_PopFilterMin()

	if not b then print(e) end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end