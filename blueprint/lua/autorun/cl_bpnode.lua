if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")
include("cl_bppin.lua")

module("bpuinode", package.seeall, bpcommon.rescope(bpschema, bpnodedef, bpgraph))

local PANEL_INSET = 4

-- NODE TOOLS
local function calculateNodeSize(vnode)

	local name = vnode:GetDisplayName()
	local node = vnode.node
	local meta = node:GetMeta()

	surface.SetFont( "Default" )
	local inPinWidth = 0
	local outPinWidth = 0
	local padPin = 50

	local maxVertical = math.max(node:GetNumSidePins(PD_In), node:GetNumSidePins(PD_Out))
	local width = 0
	local headHeight = 30
	

	local expand = false
	for k,v in pairs(node:GetPins()) do
		local baseType = v:GetBaseType()
		if (baseType == PN_String or baseType == PN_Enum) and v:IsIn() and not node:IsPinConnected(k) then
			expand = true
		end
		if v:IsIn() then inPinWidth = math.max(surface.GetTextSize( v:GetName() ) + padPin, inPinWidth) end
		if v:IsOut() then outPinWidth = math.max(surface.GetTextSize( v:GetName() ) + padPin, outPinWidth) end
	end

	if meta.compact then
		surface.SetFont("HudHintTextLarge")
		local titleWidth = surface.GetTextSize( name )
		width = math.max(titleWidth+60, 0)
		headHeight = 15

		if node:GetTypeName() == "Pin" then
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

local function pinLocation(vnode, dir, id)

	local x = 0
	local y = 15
	local w, h = calculateNodeSize(vnode)
	local meta = vnode.node:GetMeta()
	if meta.compact then y = -4 end
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

	self.nodeCallback = function(...)
		self:OnNodeCallback(...)
	end

end

function PANEL:GetDisplayName()

	local name = self.node:GetDisplayName()
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

	local w,h = calculateNodeSize( self )
	self:SetSize( w, h )
	self:SetPos( node.x, node.y )
	self:BuildPins()

	self.graph:AddListener(self.callback, bpgraph.CB_ALL)
	self.node:AddListener(self.nodeCallback, bpnode.CB_ALL)

end

function PANEL:OnRemove()

	self:CloseNodeContext()
	if self.graph then self.graph:RemoveListener(self.callback) end
	if self.node then self.node:RemoveListener(self.nodeCallback) end

end

function PANEL:OnGraphCallback( cb, ... )

	if cb == CB_POSTMODIFY_NODE then self:PostNodeChanged( ... ) end

end

function PANEL:OnNodeCallback( cb, ... )

	--[[if cb == bpnode.CB_NODE_PINS_UPDATED then
		local w,h = calculateNodeSize( self )
		self:SetSize( w, h )
		self:BuildPins()
	end]]

end

function PANEL:PostNodeChanged( nodeID, action )

	if self.nodeID == nodeID then
		local w,h = calculateNodeSize( self )
		self:SetSize( w, h )

		if action == bpgraph.NODE_MODIFY_SIGNATURE then
			self:BuildPins()
		end
	end

end

function PANEL:BuildPins()

	--MsgC(Color(255,100,255), "Rebuild pins for node: " .. self.node:ToString() .. "\n")

	if self.pins ~= nil then
		for _, v in pairs(self.pins) do
			v:Remove()
		end
	end

	self.pins = {}

	local node = self.node
	for pinID, pin, pos in node:SidePins(PD_In) do

		--MsgC(Color(255,100,255), "\t" .. pin:ToString(true,true) .. "\n")

		local x,y = pinLocation(self, PD_In, pos)

		local vpin = vgui.Create("BPPin", self)
		vpin:SetPos(x,y)
		vpin:SetTall(10)
		vpin:Setup(self.graph, self.node, pin, pinID)

		self.pins[pinID] = vpin

	end

	for pinID, pin, pos in node:SidePins(PD_Out) do

		--MsgC(Color(255,100,255), "\t" .. pin:ToString(true,true) .. "\n")

		local x,y = pinLocation(self, PD_Out, pos)

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

	local inset = self.inset
	for pinID, pin, pos in self.node:SidePins(PD_In) do

		local x,y = pinLocation(self, PD_In, pos)
		local w,h = self.pins[pinID]:GetSize()
		self.pins[pinID]:SetPos(x + inset, y + inset)

	end

	local w, h = calculateNodeSize(self)
	self:SetSize( w, h )

	for pinID, pin, pos in self.node:SidePins(PD_Out) do

		local x,y = pinLocation(self, PD_Out, pos)
		local w,h = self.pins[pinID]:GetSize()
		self.pins[pinID]:SetPos(x - w - inset, y + inset)

	end

end

function PANEL:Paint(w, h)

	if not self.node then return end
	local node = self.node
	local meta = node:GetMeta()

	local inset = self.inset
	if self:HasFocus() then
		draw.RoundedBox(8, 0, 0, w, h, Color(200,150,80,255))
	end

	local err = _G.G_BPError
	if err ~= nil then
		if err.nodeID == self.node.id and err.graphID == self.graph.id then
			draw.RoundedBox(8, 0, 0, w, h, Color(200,80,80,255))
		end
	end


	local ntc = NodeTypeColors[ node:GetCodeType() ]
	draw.RoundedBox(6, inset, inset, w - inset*2, h - inset*2, Color(20,20,20,255))


	if not meta.compact then draw.RoundedBox(6, inset, inset, w - inset * 2, 18, Color(ntc.r,ntc.g,ntc.b,180)) end
	if meta.role then
		if meta.role == ROLE_Shared and false then
			draw.RoundedBox(2, inset + w - 30, inset, 9, 18, Color(20,160,255,255))
			draw.RoundedBox(2, inset + w - 30, inset + 9, 10, 9, Color(255,160,20,255))
		elseif meta.role == ROLE_Server then
			draw.RoundedBox(2, inset + w - 30, inset, 10, 18, Color(20,160,255,255))
		elseif meta.role == ROLE_Client then
			draw.RoundedBox(2, inset + w - 30, inset, 10, 18, Color(255,160,20,255))
		end
	end

	if not meta.compact then
		draw.SimpleText(self:GetDisplayName(), "Trebuchet18", inset + 4, inset)
	else
		-- HACK
		if node:GetTypeName() ~= "Pin" then
			draw.SimpleText(self:GetDisplayName(), "HudHintTextLarge", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	return true

end

function PANEL:CloseNodeContext()

	if IsValid( self.menu ) then
		self.menu:Remove()
	end

end

function PANEL:OpenNodeContext()

	local options = {}
	self.node:GetOptions(options)

	if #options == 0 then return end

	self:CloseNodeContext()
	self.menu = DermaMenu( false, self )

	for k,v in pairs(options) do
		self.menu:AddOption( v[1], v[2] )
	end

	self.menu:SetMinimumWidth( 100 )
	self.menu:Open( gui.MouseX(), gui.MouseY(), false, self )

end

function PANEL:OnMousePressed(m)

	if not self.node then return end
	if self.vgraph:GetIsLocked() then return end

	if m == MOUSE_RIGHT then
		self:OpenNodeContext()
		return
	end

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
		if self.node:GetMeta().noDelete then return end
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
		self.node:Move( x - self.canvasFix, y - self.canvasFix )

	end


	local screenX, screenY = self:LocalToScreen( 0, 0 )

	if self.Hovered and not self.vgraph:GetIsLocked() then
		self:SetCursor( "sizeall" )
		return
	end

	self:SetCursor( "arrow" )

end

vgui.Register( "BPNode", PANEL, "DPanel" )
