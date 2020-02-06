if SERVER then AddCSLuaFile() return end

module("bpuigraphnode", package.seeall, bpcommon.rescope(bpgraph, bpschema))

local surface_setFont = surface.SetFont
local surface_setDrawColor = surface.SetDrawColor
local surface_setTextPos = surface.SetTextPos
local surface_setTextColor = surface.SetTextColor
local surface_drawText = surface.DrawText
local surface_drawRect = surface.DrawRect
local draw_simpleText = draw.SimpleText
local render_PushFilterMag = render.PushFilterMag
local render_PushFilterMin = render.PushFilterMin
local render_PopFilterMag = render.PopFilterMag
local render_PopFilterMin = render.PopFilterMin
local roundedBox = bprenderutils.RoundedBoxFast

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
	self.displayName = nil
	self.pinsNeedLayout = true

	if invalidatePins then
		for _, v in ipairs(self.pins) do
			v:Invalidate()
		end
	end

end

function meta:ShouldBeCompact()

	for _, v in ipairs(self.pins) do
		if v.pin:IsIn() and v.pin:GetLiteralType() == "string" and #v:GetConnections() == 0 then
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

	surface.SetFont("NodeTitleFont")
	local titleWidth, titleHeight = surface.GetTextSize( name )

	self.titleWidth = titleWidth
	self.titleHeight = titleHeight

	if self:ShouldBeCompact() then
		width = math.max(titleWidth+40, 0)
		headHeight = NODE_COMPACT_HEADER_HEIGHT
		footHeight = NODE_COMPACT_FOOTER_HEIGHT
	else
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

	if not self.pinsNeedLayout then return end

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

	self.pinsNeedLayout = false


	--[[for _, vpin in ipairs(self.pins) do
		local x,y = self:CalculatePinLocation(vpin)
		vpin:SetPos(x,y)
	end]]

end

function meta:GetDisplayName()

	if self.displayName then return self.displayName end

	local name = self:GetNode():GetDisplayName()
	local sub = string.find(name, "[:.]")
	if sub then
		name = name:sub(sub+1, -1)
	end

	--name = name:gsub("%u%l+", function(x) print(x) return " " .. x end):Trim()

	self.displayName = name

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

	local m = bpuigraphpin_meta
	local x,y = self:GetPos()

	self:LayoutPins()

	for k,v in ipairs(self.pins) do
		m.Draw(v, x+xOffset, y+yOffset, alpha)
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
		roundedBox(16, x-outline, y-outline, w+outline*2, h+outline*2, 200,150,80,255*alpha, true, true, true, true)
	end

	local err = _G.G_BPError
	if err ~= nil then
		if err.nodeID == self.node.id and err.graphID == self.graph.id then
			roundedBox(16, x, y, w, h, 200,80,80,255*alpha, true, true, true, true)
		end
	end


	local ntc = NodeTypeColors[ node:GetCodeType() ]
	local isCompact = self:ShouldBeCompact()
	local offset = isCompact and 0 or NODE_HEADER_HEIGHT
	roundedBox(12, x, y + offset, w, h - offset, 20,20,20,(selected and 252 or 230)*alpha, isCompact, isCompact, true, true)


	if not isCompact then 
		roundedBox(12, x, y, w, NODE_HEADER_HEIGHT, ntc.r,ntc.g,ntc.b,255*alpha, true, true)
		surface_setDrawColor(Color(ntc.r/2,ntc.g/2,ntc.b/2,255*alpha))
		surface_drawRect(x,y + NODE_HEADER_HEIGHT,w,2)
	end
	local role = node:GetRole()

	if role == ROLE_Server then
		roundedBox(4, x + w - 30, y, 10, NODE_HEADER_HEIGHT, 20,160,255,255*alpha)
	elseif role == ROLE_Client then
		roundedBox(4, x + w - 30, y, 10, NODE_HEADER_HEIGHT, 255,160,20,255*alpha)
	end

	render_PushFilterMag( TEXFILTER.LINEAR )
	render_PushFilterMin( TEXFILTER.LINEAR )

	local b,e = pcall( function()

		local name = self:GetDisplayName()

		if not self:ShouldBeCompact() then

			surface_setFont( "NodeTitleFontShadow" )
			surface_setTextPos( math.ceil( x+5 ), math.ceil( y ) )
			surface_setTextColor( 0, 0, 0, 255*alpha )
			surface_drawText( name )

			surface_setFont( "NodeTitleFont" )
			surface_setTextPos( math.ceil( x+8 ), math.ceil( y+2 ) )
			surface_setTextColor( 255, 255, 255, 255*alpha )
			surface_drawText( name )

		else
			-- HACK
			if node:GetTypeName() ~= "CORE_Pin" then

				surface_setFont( "NodeTitleFont" )
				surface_setTextPos( math.ceil( x+(w - self.titleWidth)/2 ), math.ceil( y+(h - self.titleHeight)/2 ) )
				surface_setTextColor( 255, 255, 255, 255*alpha )
				surface_drawText( name )
			end
		end

		self:DrawPins(xOffset, yOffset, alpha)

	end)

	render_PopFilterMag()
	render_PopFilterMin()

	if not b then print(e) end

end

function New(...) return bpcommon.MakeInstance(meta, ...) end