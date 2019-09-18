if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("cl_bppin.lua")

module("bpuinode", package.seeall, bpcommon.rescope(bpschema, bpnodedef))

local PANEL_INSET = 4

-- NODE TOOLS
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
		width = math.max(width, 80)
		headHeight = 15
	end

	return width, headHeight + maxVertical * 15 + PANEL_INSET * 2

end

local function pinLocation(node, ntype, dir, id)

	local x = 0
	local y = 15
	local w, h = calculateNodeSize(node)
	local p = getLayoutPin(ntype, dir, id)
	if ntype.compact then y = -4 end
	if dir == PD_In then
		return x, y + id * 15
	else
		return x + w, y + id * 15
	end

end

local PANEL = {}

function PANEL:Init()

	self.inset = PANEL_INSET

end

function PANEL:Setup( graph, node )

	self.node = node
	self.graph = graph
	self.vgraph = self:GetParent():GetParent()

	local w,h = calculateNodeSize(self.node)
	self:SetWide( w )
	self:SetTall( h )
	self:SetPos( node.x, node.y )

	self.pins = {}

	local node = self.node
	local ntype = node.nodeType
	for i=1, pinCount(ntype, PD_In) do

		local pinID = getLayoutPin(ntype, PD_In, i)
		local pin = ntype.pins[pinID]
		local lit = node.literals and node.literals[pinID]
		local x,y = pinLocation(node, ntype, PD_In, i)

		local vpin = vgui.Create("BPPin", self)
		vpin:SetPos(x,y)
		vpin:SetTall(10)
		vpin:Setup(graph, node, pin, pinID)

		self.pins[pinID] = vpin

	end

	for i=1, pinCount(ntype, PD_Out) do

		local pinID = getLayoutPin(ntype, PD_Out, i)
		local pin = ntype.pins[pinID]
		local x,y = pinLocation(node, ntype, PD_Out, i)

		local vpin = vgui.Create("BPPin", self)
		vpin:SetPos(x,y)
		vpin:SetTall(10)
		vpin:Setup(graph, node, pin, pinID)

		self.pins[pinID] = vpin

	end

end

function PANEL:OnPinGrab( vpin, grabbing )

	self.vgraph:OnPinGrab( self, vpin, grabbing )

end

function PANEL:GetPin(id)

	return self.pins[id]

end

function PANEL:PerformLayout(pw, ph)

	local ntype = self.node.nodeType
	local inset = self.inset
	for i=1, pinCount(ntype, PD_In) do

		local pinID = getLayoutPin(ntype, PD_In, i)
		local x,y = pinLocation(self.node, ntype, PD_In, i)
		local w,h = self.pins[pinID]:GetSize()
		self.pins[pinID]:SetPos(x + inset, y + inset)

	end

	for i=1, pinCount(ntype, PD_Out) do

		local pinID = getLayoutPin(ntype, PD_Out, i)
		local x,y = pinLocation(self.node, ntype, PD_Out, i)
		local w,h = self.pins[pinID]:GetSize()
		self.pins[pinID]:SetPos(x - w - inset, y + inset)

	end

end

function PANEL:Paint(w, h)

	if not self.node then return end
	local ntype = self.node.nodeType

	local inset = self.inset
	if self:HasFocus() then
		draw.RoundedBox(8, 0, 0, w, h, Color(200,150,80,255))
	end


	local ntc = NodeTypeColors[ ntype.type ]
	draw.RoundedBox(6, inset, inset, w - inset*2, h - inset*2, Color(20,20,20,255))

	if not ntype.compact then
		draw.RoundedBox(6, inset, inset, w - inset * 2, 20, Color(ntc.r,ntc.g,ntc.b,180))
		draw.SimpleText(ntype.name, "HudHintTextLarge", inset + 2, inset + 2)
	else
		draw.SimpleText(ntype.name, "HudHintTextLarge", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return true

end

function PANEL:OnMousePressed()

	if not self.node then return end
	local ntype = self.node.nodeType

	local screenX, screenY = self:LocalToScreen( 0, 0 )
	self:MoveToFront()
	self:RequestFocus()

	self.Dragging = { gui.MouseX() - self.x, gui.MouseY() - self.y }
	self:MouseCapture( true )

end

function PANEL:OnMouseReleased()

	self.Dragging = nil
	self.Sizing = nil
	self:MouseCapture( false )

end

function PANEL:OnKeyCodePressed( code )

	if not self:HasFocus() then return end
	if code == KEY_DELETE then
		self.graph:RemoveNode(self.node)
	end

end

function PANEL:Think()

	if not self.node then return end
	local ntype = self.node.nodeType

	local mousex = math.Clamp( gui.MouseX(), 1, ScrW() - 1 )
	local mousey = math.Clamp( gui.MouseY(), 1, ScrH() - 1 )
	local lock = false

	if self.Dragging then

		local x = mousex - self.Dragging[1]
		local y = mousey - self.Dragging[2]

		-- Lock to screen bounds if screenlock is enabled
		if lock then

			x = math.Clamp( x, 0, ScrW() - self:GetWide() )
			y = math.Clamp( y, 0, ScrH() - self:GetTall() )

		end

		--self:SetPos( x, y )
		self.graph:MoveNode( self.node, x - self.canvasBack, y - self.canvasBack )

	end


	local screenX, screenY = self:LocalToScreen( 0, 0 )

	if self.Hovered then
		self:SetCursor( "sizeall" )
		return
	end

	self:SetCursor( "arrow" )

end

vgui.Register( "BPNode", PANEL, "DPanel" )
