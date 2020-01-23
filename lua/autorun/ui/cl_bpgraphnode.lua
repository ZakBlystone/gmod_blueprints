if SERVER then AddCSLuaFile() return end

module("bpuigraphnode", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local meta = bpcommon.MetaTable("bpuigraphnode")

local NODE_MINIMUM_WIDTH = 100
local NODE_PINSIDE_SPACING = 40
local NODE_HEADER_HEIGHT = 40
local NODE_HEADER_SPACING = 25
local NODE_FOOTER_HEIGHT = 40
local NODE_COMPACT_HEADER_SPACING = 0
local NODE_COMPACT_HEADER_HEIGHT = 20
local NODE_COMPACT_FOOTER_HEIGHT = 20
local PIN_SPACING = 8
local PIN_EDGE_SPACING = 8

function meta:Init(node, graph, editor)

	self.editor = editor
	self.node = node
	self.graph = graph
	self.width = nil
	self.height = nil
	self.pins = {}
	self:CreatePins()
	self:LayoutPins()
	return self

end

function meta:Invalidate(invalidatePins)

	self.width = nil
	self.height = nil

	if invalidatePins then
		for _, v in ipairs(self.pins) do
			v:Invalidate()
		end
	end

end

function meta:ShouldBeCompact()

	for _, v in ipairs(self.pins) do
		if v.pin:GetLiteralType() == "string" and #v:GetConnections() == 0 then
			return false
		end
	end
	return self.node:HasFlag(NTF_Compact)

end

function meta:GetSize()

	if self.width and self.height then
		return self.width, self.height
	end

	local node = self.node
	local name = self:GetDisplayName()

	surface.SetFont( "Default" )
	local inPinWidth = 0
	local outPinWidth = 0
	local padPin = 50

	local totalPinHeightIn = 0
	local totalPinHeightOut = 0
	local maxPinWidthIn = 0
	local maxPinWidthOut = 0
	local width = 0
	local headHeight = NODE_HEADER_HEIGHT
	local footHeight = NODE_FOOTER_HEIGHT
	local pinSideSpacing = NODE_PINSIDE_SPACING

	for pinID, pin, pos in node:SidePins(PD_In) do
		local vpin = self.pins[pinID]
		local w,h = vpin:GetSize()
		maxPinWidthIn = math.max(maxPinWidthIn, w)
		totalPinHeightIn = totalPinHeightIn + h + PIN_SPACING
	end
	if totalPinHeightIn ~= 0 then totalPinHeightIn = totalPinHeightIn - PIN_SPACING end

	for pinID, pin, pos in node:SidePins(PD_Out) do
		local vpin = self.pins[pinID]
		local w,h = vpin:GetSize()
		maxPinWidthOut = math.max(maxPinWidthOut, w)
		totalPinHeightOut = totalPinHeightOut + h + PIN_SPACING
	end
	if totalPinHeightOut ~= 0 then totalPinHeightOut = totalPinHeightOut - PIN_SPACING end

	if self:ShouldBeCompact() then
		surface.SetFont("NodeTitleFont")
		local titleWidth = surface.GetTextSize( name )
		width = math.max(titleWidth+40, 0)
		headHeight = NODE_COMPACT_HEADER_HEIGHT
		footHeight = NODE_COMPACT_FOOTER_HEIGHT
	else
		surface.SetFont( "NodeTitleFont" )
		local titleWidth = surface.GetTextSize( name )
		width = math.max(inPinWidth + outPinWidth, math.max(NODE_MINIMUM_WIDTH, titleWidth+20))
	end

	self.width = math.max(width, maxPinWidthIn + maxPinWidthOut) + pinSideSpacing
	self.height = footHeight + headHeight + math.max(totalPinHeightIn, totalPinHeightOut)

	if maxPinWidthIn ~= 0 then self.width = self.width + PIN_EDGE_SPACING end
	if maxPinWidthOut ~= 0 then self.width = self.width + PIN_EDGE_SPACING end

	if node:GetTypeName() == "CORE_Pin" then
		self.width = 80
	end

	return self.width, self.height

end

function meta:CalculatePinLocation(vpin)

	local nw, nh = self:GetSize()
	local pin = vpin:GetPin()
	local id = vpin:GetSideIndex()
	local dir = pin:GetDir()
	local w,h = vpin:GetSize()
	local ox, oy = vpin:GetHotspotOffset()
	local x = 0
	local y = 10
	if self:ShouldBeCompact() then y = -5 end
	if dir == PD_In then
		return x, y + id * 15
	else
		return x + nw - w, y + id * 15
	end

end

function meta:CreatePins()

	self.pins = {}

	local node = self.node
	for pinID, pin, pos in node:SidePins(PD_In) do
		self.pins[pinID] = bpuigraphpin.New(self, pinID, pos)
	end

	for pinID, pin, pos in node:SidePins(PD_Out) do
		self.pins[pinID] = bpuigraphpin.New(self, pinID, pos)
	end

end

function meta:LayoutPins()

	local nw, nh = self:GetSize()

	local function LayoutSide(s)
		local y = NODE_HEADER_HEIGHT + NODE_HEADER_SPACING
		if self:ShouldBeCompact() then y = NODE_COMPACT_HEADER_HEIGHT + NODE_COMPACT_HEADER_SPACING end

		local node = self.node
		for pinID, pin, pos in node:SidePins(s) do
			local vpin = self.pins[pinID]
			local w,h = vpin:GetSize()
			vpin:SetPos(s == PD_In and PIN_EDGE_SPACING or (nw - w - PIN_EDGE_SPACING), y)
			y = y + h + PIN_SPACING
		end
	end

	LayoutSide(PD_In)
	LayoutSide(PD_Out)


	--[[for _, vpin in ipairs(self.pins) do
		local x,y = self:CalculatePinLocation(vpin)
		vpin:SetPos(x,y)
	end]]

end

function meta:GetDisplayName()

	local name = self:GetNode():GetDisplayName()
	local sub = string.find(name, "[:.]")
	if sub then
		name = name:sub(sub+1, -1)
	end
	return name

end

function meta:GetVPin(pinID)

	return self.pins[pinID]

end

function meta:GetVPins()

	return self.pins

end

function meta:GetNode()

	return self.node

end

function meta:GetPos()

	local x,y = self.node:GetPos()
	local scale = 2 -- HARD CODE FOR NOW, FIX LATER
	x = x * scale
	y = y * scale
	return x,y

end

function meta:IsSelected()

	if not self.editor then return false end
	return self.editor:IsNodeSelected(self)

end

function meta:GetHitBox()

	local x,y = self:GetPos()
	local w,h = self:GetSize()
	return x,y,w,h

end

function meta:DrawPins(xOffset, yOffset, alpha)

	local x,y = self:GetPos()

	self:LayoutPins()

	for k,v in ipairs(self.pins) do
		v:Draw(x+xOffset, y+yOffset, alpha)
	end

end

function meta:GetPinSpotLocation(pinID)

	local x,y = self:GetPos()
	local vpin = self.pins[pinID]
	if not vpin then return x,y end

	local px, py = vpin:GetPos()
	local ox, oy = vpin:GetHotspotOffset()

	return x + ox + px, y + py + oy

end

function meta:Draw(xOffset, yOffset, alpha)

	--self:Invalidate(true)

	local x,y = self:GetPos()
	local w,h = self:GetSize()

	x = x + xOffset
	y = y + yOffset

	local node = self.node
	local outline = 8
	local selected = self:IsSelected()
	if selected then
		draw.RoundedBox(16, x-outline, y-outline, w+outline*2, h+outline*2, Color(200,150,80,255*alpha))
	end

	local err = _G.G_BPError
	if err ~= nil then
		if err.nodeID == self.node.id and err.graphID == self.graph.id then
			draw.RoundedBox(16, x, y, w, h, Color(200,80,80,255*alpha))
		end
	end


	local ntc = NodeTypeColors[ node:GetCodeType() ]
	local isCompact = self:ShouldBeCompact()
	local offset = isCompact and 0 or NODE_HEADER_HEIGHT
	draw.RoundedBoxEx(12, x, y + offset, w, h - offset, Color(20,20,20,(selected and 252 or 230)*alpha), isCompact, isCompact, true, true)


	if not isCompact then 
		draw.RoundedBoxEx(12, x, y, w, NODE_HEADER_HEIGHT, Color(ntc.r,ntc.g,ntc.b,255*alpha), true, true)
		surface.SetDrawColor(Color(ntc.r/2,ntc.g/2,ntc.b/2,255*alpha))
		surface.DrawRect(x,y + NODE_HEADER_HEIGHT,w,2)
	end
	local role = node:GetRole()

	if role == ROLE_Server then
		draw.RoundedBox(4, x + w - 30, y, 10, NODE_HEADER_HEIGHT, Color(20,160,255,255*alpha))
	elseif role == ROLE_Client then
		draw.RoundedBox(4, x + w - 30, y, 10, NODE_HEADER_HEIGHT, Color(255,160,20,255*alpha))
	end

	render.PushFilterMag( TEXFILTER.LINEAR )
	render.PushFilterMin( TEXFILTER.LINEAR )

	local b,e = pcall( function()

		if not self:ShouldBeCompact() then
			draw.SimpleText(self:GetDisplayName(), "NodeTitleFontShadow", x + 5, y, Color(0,0,0,255*alpha))
			draw.SimpleText(self:GetDisplayName(), "NodeTitleFont", x + 8, y + 2, Color(255,255,255,255*alpha))
		else
			-- HACK
			if node:GetTypeName() ~= "CORE_Pin" then
				draw.SimpleText(self:GetDisplayName(), "NodeTitleFont", x + w/2, y + h/2, Color(255,255,255,255*alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end

		self:DrawPins(xOffset, yOffset, alpha)

	end)

	render.PopFilterMag()
	render.PopFilterMin()

	if not b then print(e) end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end