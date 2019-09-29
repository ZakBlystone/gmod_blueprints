if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")

module("bpuipin", package.seeall, bpcommon.rescope(bpschema, bpnodedef, bpgraph))


local PANEL = {}

function PANEL:Init()


end

function PANEL:GetHotSpot()

	local x,y = self.pinSpot:GetPos()
	x = x + self.pinSpot:GetWide() / 2
	y = y + self.pinSpot:GetTall() / 2
	return self:LocalToScreen(x, y)

end

function PANEL:OnRemove()

	if self.graph then
		self.graph:RemoveListener(self.callback)
	end

end

function PANEL:Setup(graph, node, pin, pinID)

	self.callback = function(...)
		self:OnGraphCallback(...)
	end

	self.vnode = self:GetParent()
	self.vgraph = self.vnode.vgraph
	self.graph = graph
	self.node = node
	self.pin = pin
	self.pinID = pinID
	self.nodeType = self.graph:GetNodeType( self.node )
	self.pinType = self.graph:GetPinType( self.node.id, self.pinID )
	self.graph:AddListener(self.callback, CB_PIN_EDITLITERAL)

	self.pinSpot = vgui.Create("DPanel", self)
	self.pinSpot:SetSize(10,10)

	local isTable = bit.band(self.pin[4], PNF_Table) ~= 0

	self.pinSpot.Paint = function(pinspot,w,h)

		local pt = self.pinType

		surface.SetDrawColor( NodePinColors[ pt ] )
		surface.DrawRect(0,0,w,h)
		surface.SetDrawColor( Color(0,0,0,255) )

		if isTable then
			surface.DrawRect(w/2 - 1,0,2,h)
			surface.DrawRect(w*.25 - 1,0,2,h)
			surface.DrawRect(w*.75,0,2,h)
		end

	end


	self.pinSpot.OnMousePressed = function(...)

		self:OnMousePressed( ... )
	
	end

	self.pinSpot.OnMouseReleased = function(...)

		self:OnMouseReleased( ... )
	
	end

	self:SetBackgroundColor(Color(0,0,0,0))
	self:SetSize(10,10)

	local shift_up = 2
	if not self.nodeType.compact then

		self.label = vgui.Create("DLabel", self)
		self.label:SetFont("DermaDefaultBold")
		self.label:SetText(pin[3])
		self.label:SizeToContents()

		if self.pin[1] == PD_Out then
			self.pinSpot:SetPos( self.label:GetWide() + 5, self.label:GetTall() / 2 - self.pinSpot:GetTall() / 2)
			self.label:SetPos( 0, -shift_up )
		else
			self.label:SetPos( 15, -shift_up )
		end

	end

	self:InitLiteral()

	self:InvalidateLayout( true )
	self:SizeToChildren(true, true)

end

function PANEL:InitLiteral()

	local shift_up = 2
	if IsValid(self.checkBox) then self.checkBox:Remove() self.checkBox = nil end
	if IsValid(self.textEntry) then self.textEntry:Remove() self.textEntry = nil end

	if self.pin[1] == PD_In then
		local literalType = NodeLiteralTypes[ self.pinType ]
		if literalType then
			self.literalType = literalType
			local literal = self.graph:GetPinLiteral(self.node.id, self.pinID) or ""

			if self.literalType == "bool" then
				self.checkBox = vgui.Create("DCheckBox", self)

				if self.label then
					self.checkBox:SetPos( 15 + self.label:GetWide(), -shift_up )
				else
					self.checkBox:SetPos( 15, -shift_up )
				end

				self.checkBox.OnChange = function(cb, val)
					self.graph:SetPinLiteral( self.node.id, self.pinID, val and "true" or "false" )
				end
				self.checkBox:SetChecked(literal == "true" and true or false)

			else
				self.textEntry = vgui.Create("DTextEntry", self)

				if self.label then
					self.textEntry:SetPos( 15 + self.label:GetWide(), -shift_up - 4 )
				else
					self.textEntry:SetPos( 15, -shift_up - 4 )
				end
				--self.textEntry:SetUpdateOnType(true)

				
				--self.textEntry:SetPaintBackground(false)
				--self.textEntry:SetTextColor( Color(255,255,255))
				self.textEntry:SetText(literal) 
				if literalType ~= "string" then self.textEntry:SetWide( 40 ) end
				if literalType == "number" then self.textEntry:SetNumeric( true ) end
				self.textEntry.OnValueChange = function(te, ...) self:OnTextValue(...) end
				self.textEntry.OnFocusChanged = function(te, gained)
					if not gained then self:OnTextValue( te:GetText() ) end
				end
			end
		end
	end

	self:InvalidateLayout( true )
	self:SizeToChildren(true, true)

end

function PANEL:OnGraphCallback(cb, ...)

	if cb == CB_PIN_EDITLITERAL then return self:OnLiteralEdit(...) end

end

function PANEL:OnLiteralEdit(nodeID, pinID, value)

	if nodeID ~= self.node.id or pinID ~= self.pinID then return end

	if IsValid(self.textEntry) then self.textEntry:SetText(value) end
	if IsValid(self.checkBox) then self.checkBox:SetChecked(value == "true" and true or false) end

end

function PANEL:OnTextValue(str)

	local literal = nil
	print("LITERAL TEXT VALUE: \"" .. str .. "\"")
	if self.literalType == "string" then

		literal = str

	elseif self.literalType == "number" then

		literal = tonumber(str) or 0

	elseif self.literalType == "bool" then

		if str == "1" or str == "true" then
			literal = true
		else
			literal = false
		end

	end

	if literal ~= nil then

		self.graph:SetPinLiteral( self.node.id, self.pinID, literal )

	end

end

function PANEL:Think()

	local prev = self.pinType
	self.pinType = self.graph:GetPinType( self.node.id, self.pinID )

	if self.pinType ~= prev then
		self:OnPinTypeChanged( self.pinType )
	end

	if self.graph:IsPinConnected( self.node.id, self.pinID ) then

		if self.textEntry ~= nil then self.textEntry:SetVisible(false) end
		if self.checkBox ~= nil then self.checkBox:SetVisible(false) end

	else

		if self.textEntry ~= nil then self.textEntry:SetVisible(true) end
		if self.checkBox ~= nil then self.checkBox:SetVisible(true) end

	end

end

function PANEL:OnPinTypeChanged( pt )

	print("PIN TYPE CHANGED")
	self:InitLiteral()

end

function PANEL:PerformLayout(w, h)


	--[[if self.pin[1] == PD_Out then

		if self.label then
			self.label:SetPos( 0, 0 )
		end

		--self.pinSpot:SetPos( w, h / 2 - 5 )
	else
		if self.label then
			self.label:SetPos( 15, 0 )
		end

		--self.pinSpot:SetPos( 0, h / 2 - 5 )
	end]]

end

function PANEL:OnMousePressed(mouse)

	if self.vgraph:GetIsLocked() then return end

	self.vnode:OnPinGrab( self, true )

end

function PANEL:OnMouseReleased(mouse)

	if self.vgraph:GetIsLocked() then return end

	self.vnode:OnPinGrab( self, false )

end

vgui.Register( "BPPin", PANEL, "DPanel" )