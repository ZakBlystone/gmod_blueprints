if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("cl_bppin.lua")

module("bpuinode", package.seeall, bpcommon.rescope(bpschema, bpnodedef, bpgraph))

local PANEL_INSET = 4

-- NODE TOOLS
local function pinCount(nodeType, dir)

	local t = dir == PD_In and nodeType.pinlayout.inputs or nodeType.pinlayout.outputs
	return #t

end

local function getLayoutPin(nodeType, dir, id)

	local t = dir == PD_In and nodeType.pinlayout.inputs or nodeType.pinlayout.outputs
	return t[id]

end

local function calculateNodeSize(vnode, nodeType)

	local name = vnode:GetDisplayName()

	surface.SetFont( "Default" )
	local inPinWidth = 0
	local outPinWidth = 0
	local padPin = 50

	local maxVertical = math.max(#nodeType.pinlayout.inputs, #nodeType.pinlayout.outputs)
	local width = 0
	local headHeight = 30
	

	local expand = false
	for k,v in pairs(nodeType.pins) do
		if (v[2] == PN_String or v[2] == PN_Enum) and v[1] == PD_In then
			expand = true
		end
		if v[1] == PD_In then inPinWidth = math.max(surface.GetTextSize( v[3] ) + padPin, inPinWidth) end
		if v[1] == PD_Out then outPinWidth = math.max(surface.GetTextSize( v[3] ) + padPin, outPinWidth) end
	end

	if nodeType.compact then
		surface.SetFont("HudHintTextLarge")
		local titleWidth = surface.GetTextSize( name )
		width = math.max(titleWidth+60, 0)
		headHeight = 15

		if nodeType.name == "Pin" then
			width = 40
		end
	else
		surface.SetFont( "Trebuchet18" )
		local titleWidth = surface.GetTextSize( name )
		width = math.max(inPinWidth + outPinWidth, math.max(100, titleWidth+20))
	end

	if expand then width = width + 50 end

	return width, headHeight + maxVertical * 15 + PANEL_INSET * 2

end

local function pinLocation(vnode, nodeType, dir, id)

	local x = 0
	local y = 15
	local w, h = calculateNodeSize(vnode, nodeType)
	local p = getLayoutPin(nodeType, dir, id)
	if nodeType.compact then y = -4 end
	if dir == PD_In then
		return x, y + id * 15
	else
		return x + w, y + id * 15
	end

end

local PANEL = {}

function PANEL:Init()

	self.inset = PANEL_INSET

	self.callback = function(...)
		self:OnGraphCallback(...)
	end

end

function PANEL:GetDisplayName()

	local name = self.nodeType.displayName or self.nodeType.name
	local sub = string.find(name, "[:.]")
	if sub then
		name = name:sub(sub+1, -1)
	end
	return name

end

function PANEL:Setup( graph, node )

	self.node = node
	self.nodeID = self.node.id
	self.graph = graph
	self.vgraph = self:GetParent():GetParent()
	self.nodeType = self.graph:GetNodeType( self.node )

	local w,h = calculateNodeSize( self, self.nodeType )
	self:SetSize( w, h )
	self:SetPos( node.x, node.y )
	self:BuildPins()

	self.graph:AddListener(self.callback, bpgraph.CB_ALL)

end

function PANEL:OnRemove()

	if self.graph then
		self.graph:RemoveListener(self.callback)
	end

end

function PANEL:OnGraphCallback( cb, ... )

	if cb == CB_POSTMODIFY_NODETYPE then self:PostNodeTypeChanged( ... ) end

end

function PANEL:PostNodeTypeChanged( nodeType, action )

	if nodeType == self.nodeType.name then
		self.nodeType = self.graph:GetNodeType( self.node )
		local w,h = calculateNodeSize( self, self.nodeType )
		self:SetSize( w, h )

		if action == bpgraph.NODETYPE_MODIFY_SIGNATURE then
			self:BuildPins()
		end
	end

end

function PANEL:BuildPins()

	if self.pins ~= nil then
		for _, v in pairs(self.pins) do
			v:Remove()
		end
	end

	self.pins = {}

	local node = self.node
	local nodeType = self.nodeType
	for i=1, pinCount(nodeType, PD_In) do

		local pinID = getLayoutPin(nodeType, PD_In, i)
		local pin = nodeType.pins[pinID]
		local lit = node.literals and node.literals[pinID]
		local x,y = pinLocation(self, nodeType, PD_In, i)

		local vpin = vgui.Create("BPPin", self)
		vpin:SetPos(x,y)
		vpin:SetTall(10)
		vpin:Setup(self.graph, self.node, pin, pinID)

		self.pins[pinID] = vpin

	end

	for i=1, pinCount(nodeType, PD_Out) do

		local pinID = getLayoutPin(nodeType, PD_Out, i)
		local pin = nodeType.pins[pinID]
		local x,y = pinLocation(self, nodeType, PD_Out, i)

		local vpin = vgui.Create("BPPin", self)
		vpin:SetPos(x,y)
		vpin:SetTall(10)
		vpin:Setup(self.graph, self.node, pin, pinID)

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

	local ntype = self.nodeType
	local inset = self.inset
	for i=1, pinCount(ntype, PD_In) do

		local pinID = getLayoutPin(ntype, PD_In, i)
		local x,y = pinLocation(self, ntype, PD_In, i)
		local w,h = self.pins[pinID]:GetSize()
		self.pins[pinID]:SetPos(x + inset, y + inset)

	end

	for i=1, pinCount(ntype, PD_Out) do

		local pinID = getLayoutPin(ntype, PD_Out, i)
		local x,y = pinLocation(self, ntype, PD_Out, i)
		local w,h = self.pins[pinID]:GetSize()
		self.pins[pinID]:SetPos(x - w - inset, y + inset)

	end

end

function PANEL:Paint(w, h)

	if not self.node then return end
	local ntype = self.nodeType

	local inset = self.inset
	if self:HasFocus() then
		draw.RoundedBox(8, 0, 0, w, h, Color(200,150,80,255))
	end

	local err = _G.G_BPError
	if err ~= nil then
		if err.nodeID == self.node.id then
			draw.RoundedBox(8, 0, 0, w, h, Color(200,80,80,255))
		end
	end


	local ntc = NodeTypeColors[ ntype.type ]
	draw.RoundedBox(6, inset, inset, w - inset*2, h - inset*2, Color(20,20,20,255))


	if not ntype.compact then draw.RoundedBox(6, inset, inset, w - inset * 2, 18, Color(ntc.r,ntc.g,ntc.b,180)) end
	if ntype.role then
		if ntype.role == ROLE_Shared then
			draw.RoundedBox(2, inset + w - 30, inset, 9, 18, Color(20,160,255,255))
			draw.RoundedBox(2, inset + w - 30, inset + 9, 10, 9, Color(255,160,20,255))
		elseif ntype.role == ROLE_Server then
			draw.RoundedBox(2, inset + w - 30, inset, 10, 18, Color(20,160,255,255))
		elseif ntype.role == ROLE_Client then
			draw.RoundedBox(2, inset + w - 30, inset, 10, 18, Color(255,160,20,255))
		end
	end

	if not ntype.compact then
		draw.SimpleText(self:GetDisplayName(), "Trebuchet18", inset + 4, inset)
	else
		-- HACK
		if ntype.name ~= "Pin" then
			draw.SimpleText(self:GetDisplayName(), "HudHintTextLarge", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	return true

end

function PANEL:OnMousePressed()

	if not self.node then return end
	if self.vgraph:GetIsLocked() then return end

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
	if self.vgraph:GetIsLocked() then return end

	if code == KEY_DELETE then
		if self.nodeType.noDelete then return end
		self.graph:RemoveNode(self.node.id)
	end

end

function PANEL:Think()

	if not self.node then return end

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
		self.graph:MoveNode( self.nodeID, x - self.canvasFix, y - self.canvasFix )

	end


	local screenX, screenY = self:LocalToScreen( 0, 0 )

	if self.Hovered and not self.vgraph:GetIsLocked() then
		self:SetCursor( "sizeall" )
		return
	end

	self:SetCursor( "arrow" )

end

vgui.Register( "BPNode", PANEL, "DPanel" )
