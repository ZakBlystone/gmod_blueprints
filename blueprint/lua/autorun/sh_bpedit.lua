--DEPRECATED
if true then return end

AddCSLuaFile()

include("sh_bpcommon.lua")
include("sh_bpschema.lua")
include("sh_bpgraph.lua")
include("sh_bpnodedef.lua")

module("bpedit", package.seeall, bpcommon.rescope(bpschema, bpnodedef))

if SERVER then return end

local function pinCount(ntype, dir)

	local t = dir == PD_In and ntype.pinlayout.inputs or ntype.pinlayout.outputs
	return #t

end

local function getLayoutPin(ntype, dir, id)

	local t = dir == PD_In and ntype.pinlayout.inputs or ntype.pinlayout.outputs
	return t[id]

end

local function calculateNodeSize(node)

	local ntype = node.nodeType
	local maxVertical = math.max(#ntype.pinlayout.inputs, #ntype.pinlayout.outputs)
	local width = 180
	local headHeight = 30

	if ntype.compact then
		width = 40 + string.len(ntype.name) * 8
		headHeight = 15
	end

	return width, headHeight + maxVertical * 15

end

local function pinLocation(node, ntype, dir, id)

	local y = 15
	local w, h = calculateNodeSize(node)
	local p = getLayoutPin(ntype, dir, id)
	if ntype.compact then y = 0 end
	if dir == PD_In then
		return node.x + 5, y + node.y + id * 15
	else
		return node.x + w - 5, y + node.y + id * 15
	end

end

local function drawPin()

end

local function drawNode(graph, node)

	local ntype = node.nodeType
	local w, h = calculateNodeSize(node)

	local ntc = NodeTypeColors[ ntype.type ]
	draw.RoundedBox(6, node.x, node.y, w, h, Color(0,0,0,200))

	surface.SetDrawColor(Color(255,255,255))

	if not ntype.compact then
		draw.RoundedBox(6, node.x, node.y, w, 20, Color(ntc.r,ntc.g,ntc.b,180))
		draw.SimpleText(ntype.name, "HudHintTextLarge", node.x + 2, node.y + 2)
	else
		draw.SimpleText(ntype.name, "HudHintTextLarge", node.x + w/2, node.y + h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	for i=1, pinCount(ntype, PD_In) do
		local pinID = getLayoutPin(ntype, PD_In, i)
		local pin = ntype.pins[pinID]
		local lit = node.literals and node.literals[pinID]

		local x,y = pinLocation(node, ntype, PD_In, i)
		surface.SetDrawColor(NodePinColors[ pin[2] ])
		local n = pin[3]
		if pin[2] == PN_Exec then
			if pin[3] == "Exec" or pin[3] == "Thru" then n = "" end
		end
		surface.DrawRect( x-5, y-5, 10, 10)
		if not ntype.compact then draw.SimpleText( n, "DermaDefaultBold", x+12, y, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
		if lit then
			draw.SimpleText( lit, "DermaDefaultBold", x+40, y, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	for i=1, pinCount(ntype, PD_Out) do
		local pinID = getLayoutPin(ntype, PD_Out, i)
		local pin = ntype.pins[pinID]
		local x,y = pinLocation(node, ntype, PD_Out, i)
		surface.SetDrawColor(NodePinColors[ pin[2] ])
		local n = pin[3]
		local n = pin[3]
		if pin[2] == PN_Exec then
			if pin[3] == "Exec" or pin[3] == "Thru" then n = "" end
		end
		surface.DrawRect( x-5, y-5, 10, 10)
		if not ntype.compact then draw.SimpleText( n, "DermaDefaultBold", x-12, y, Color(255,255,255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
	end

end

local function CubicHermite(p0, p1, m0, m1, t)
	local tS = t*t;
	local tC = tS*t;

	return (2*tC - 3*tS + 1)*p0 + (tC - 2*tS + t)*m0 + (-2*tC + 3*tS)*p1 + (tC - tS)*m1
end

local function drawHermite(x0,y0,x1,y1,c0,c1,samples)

	local px = x0
	local py = y0

	samples = samples or 50

	local dx = (x1 - x0)
	local dy = (y1 - y0)

	local d = math.sqrt(math.max(dx*dx, 8000), dy*dy) * 2
	d = math.min(d, 400)

	for i=1, samples do

		local t = i/samples
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

local function drawConnection(graph, connection)

	local a = graph.nodes[connection[1]]
	local apin = a.nodeType.pinlookup[connection[2]]
	local b = graph.nodes[connection[3]]
	local bpin = b.nodeType.pinlookup[connection[4]]

	local ax, ay = pinLocation(a, a.nodeType, apin[3], apin[2])
	local bx, by = pinLocation(b, b.nodeType, bpin[3], bpin[2])

	--surface.SetDrawColor(NodePinColors[ a.nodeType.pins[connection[2]][2] ])

	drawHermite( ax, ay, bx, by, 
		NodePinColors[ a.nodeType.pins[connection[2]][2] ], 
		NodePinColors[ b.nodeType.pins[connection[4]][2] ] 
	)

end

local graph = bpgraph.CreateTestGraph()

hook.Add("HUDPaint", "drawbp", function()

	--[[draw.RoundedBox(6, 0, 0, ScrW(), ScrH(), Color(20,20,20,250))

	for _, connection in pairs(graph.connections) do
		drawConnection(graph, connection)
	end

	for _, node in pairs(graph.nodes) do
		drawNode(graph, node)
	end]]

end)