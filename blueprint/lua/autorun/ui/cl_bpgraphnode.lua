if SERVER then AddCSLuaFile() return end

include("../sh_bpcommon.lua")
include("../sh_bpschema.lua")
include("../sh_bpgraph.lua")
include("../sh_bpnodedef.lua")
include("cl_bpgraphpin.lua")

module("bpuigraphnode", package.seeall, bpcommon.rescope(bpgraph, bpschema, bpnodedef))

local meta = bpcommon.MetaTable("bpuigraphnode")

local NODE_HEADER_HEIGHT = 30
local NODE_FOOTER_HEIGHT = 10
local PIN_SPACING = 3

function meta:Init(node, graph, editor)

	self.editor = editor
	self.node = node
	self.graph = graph
	self.width = 0
	self.height = 0
	self.pins = {}
	self:CreatePins()
	self:CalculateSize()
	return self

end

function meta:CalculateSize()

	local node = self.node
	local name = self.node:GetDisplayName()

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

	if node:HasFlag(NTF_Compact) then
		surface.SetFont("HudHintTextLarge")
		local titleWidth = surface.GetTextSize( name )
		width = math.max(titleWidth+40, 0)
		headHeight = 15
		footHeight = 4

		if node:GetTypeName() == "CORE_Pin" then
			width = 40
		end
	else
		surface.SetFont( "Trebuchet18" )
		local titleWidth = surface.GetTextSize( name )
		width = math.max(inPinWidth + outPinWidth, math.max(100, titleWidth+20))
	end

	self.width = math.max(width, maxPinWidthIn + maxPinWidthOut)
	self.height = footHeight + headHeight + math.max(totalPinHeightIn, totalPinHeightOut)

end

function meta:CalculatePinLocation(vpin)

	local pin = vpin:GetPin()
	local id = vpin:GetSideIndex()
	local dir = pin:GetDir()
	local w,h = vpin:GetSize()
	local ox, oy = vpin:GetHotspotOffset()
	local x = 0
	local y = 10
	if self.node:HasFlag(NTF_Compact) then y = -5 end
	if dir == PD_In then
		return x, y + id * 15
	else
		return x + self.width - w, y + id * 15
	end

end

function meta:CreatePins()

	self.pins = {}

	local node = self.node
	for pinID, pin, pos in node:SidePins(PD_In) do
		self.pins[pinID] = bpuigraphpin.New(self, self.editor, pinID, pos)
	end

	for pinID, pin, pos in node:SidePins(PD_Out) do
		self.pins[pinID] = bpuigraphpin.New(self, self.editor, pinID, pos)
	end

end

function meta:LayoutPins()

	local function LayoutSide(s)
		local y = NODE_HEADER_HEIGHT
		if self.node:HasFlag(NTF_Compact) then y = 10 end

		local node = self.node
		for pinID, pin, pos in node:SidePins(s) do
			local vpin = self.pins[pinID]
			local w,h = vpin:GetSize()
			vpin:SetPos(s == PD_In and 0 or (self.width - w), y)
			y = y + h + PIN_SPACING
		end
	end

	LayoutSide(PD_In)
	LayoutSide(PD_Out)


	--[[for _, vpin in pairs(self.pins) do
		local x,y = self:CalculatePinLocation(vpin)
		vpin:SetPos(x,y)
	end]]

end

function meta:GetVPins()

	return self.pins

end

function meta:GetNode()

	return self.node

end

function meta:GetPos()

	return self.node:GetPos()

end

function meta:IsSelected()

	return false

end

function meta:DrawPins(xOffset, yOffset)

	local x,y = self:GetPos()

	self:LayoutPins()

	for k,v in pairs(self.pins) do
		v:Draw(x, y)
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

function meta:Draw(xOffset, yOffset)

	self:CalculateSize()

	local x,y = self:GetPos()
	local w,h = self.width, self.height

	x = x + (xOffset or 0)
	y = y + (yOffset or 0)

	local node = self.node
	local outline = 4
	if self:IsSelected() then
		draw.RoundedBox(8, x-outline, y-outline, w+outline*2, h+outline*2, Color(200,150,80,255))
	end

	local err = _G.G_BPError
	if err ~= nil then
		if err.nodeID == self.node.id and err.graphID == self.graph.id then
			draw.RoundedBox(8, x, y, w, h, Color(200,80,80,255))
		end
	end


	local ntc = NodeTypeColors[ node:GetCodeType() ]
	draw.RoundedBox(6, x, y, w, h, Color(20,20,20,230))


	if not node:HasFlag(NTF_Compact) then draw.RoundedBox(6, x, y, w, 18, Color(ntc.r,ntc.g,ntc.b,180)) end
	local role = node:GetRole()

	if role == ROLE_Shared and false then
		draw.RoundedBox(2, x + w - 30, y, 9, 18, Color(20,160,255,255))
		draw.RoundedBox(2, x + w - 30, y + 9, 10, 9, Color(255,160,20,255))
	elseif role == ROLE_Server then
		draw.RoundedBox(2, x + w - 30, y, 10, 18, Color(20,160,255,255))
	elseif role == ROLE_Client then
		draw.RoundedBox(2, x + w - 30, y, 10, 18, Color(255,160,20,255))
	end

	render.PushFilterMag( TEXFILTER.LINEAR )
	render.PushFilterMin( TEXFILTER.LINEAR )

	if not node:HasFlag(NTF_Compact) then
		draw.SimpleText(node:GetDisplayName(), "Trebuchet18", x + 4, y)
	else
		-- HACK
		if node:GetTypeName() ~= "CORE_Pin" then
			draw.SimpleText(node:GetDisplayName(), "HudHintTextLarge", x + w/2, y + h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	render.PopFilterMag()
	render.PopFilterMin()

	self:DrawPins(x,y)

end

function New(...) return bpcommon.MakeInstance(meta, ...) end