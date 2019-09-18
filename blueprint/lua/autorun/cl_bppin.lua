if SERVER then AddCSLuaFile() return end

include("sh_bpschema.lua")
include("sh_bpnodedef.lua")

module("bpuipin", package.seeall, bpcommon.rescope(bpschema, bpnodedef))


local PANEL = {}

function PANEL:Init()


end

function PANEL:GetHotSpot()

	local x,y = self.pinSpot:GetPos()
	x = x + self.pinSpot:GetWide() / 2
	y = y + self.pinSpot:GetTall() / 2
	return self:LocalToScreen(x, y)

end

function PANEL:Setup(graph, node, pin, pinID)

	self.vnode = self:GetParent()
	self.vgraph = self.vnode.vgraph
	self.graph = graph
	self.node = node
	self.pin = pin
	self.pinID = pinID

	self.pinColor = NodePinColors[ self.pin[2] ]

	self.pinSpot = vgui.Create("DPanel", self)
	self.pinSpot:SetSize(10,10)
	self.pinSpot:SetBackgroundColor(Color(self.pinColor.r,self.pinColor.g,self.pinColor.b,255))

	if bit.band(self.pin[4], PNF_Table) ~= 0 then

		self.pinSpot.Paint = function(pinspot,w,h)

			surface.SetDrawColor( pinspot:GetBackgroundColor() )
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor( Color(0,0,0,255) )

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

	self:SetBackgroundColor(Color(self.pinColor.r,self.pinColor.g,self.pinColor.b,0))
	self:SetSize(10,10)

	local shift_up = 2
	if not node.nodeType.compact then

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

	if self.pin[1] == PD_In then
		local literalType = NodeLiteralTypes[self.pin[2]]
		if literalType then
			print("LITERAL TYPE: " .. literalType)
			self.literalType = literalType
			local literal = node.literals[ self.pinID ] or ""

			if self.literalType == "bool" then
				self.checkBox = vgui.Create("DCheckBox", self)

				if self.label then
					self.checkBox:SetPos( 15 + self.label:GetWide(), -shift_up )
				else
					self.checkBox:SetPos( 15, -shift_up )
				end

				self.checkBox:SetChecked( literal == true )

			else
				self.textEntry = vgui.Create("DTextEntry", self)

				if self.label then
					self.textEntry:SetPos( 15 + self.label:GetWide(), -shift_up - 4 )
				else
					self.textEntry:SetPos( 15, -shift_up - 4 )
				end
				--self.textEntry:SetUpdateOnType(true)

				
				self.textEntry:SetText(literal)
				--self.textEntry:SetPaintBackground(false)
				--self.textEntry:SetTextColor( Color(255,255,255))
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

function PANEL:OnTextValue(str)

	local literal = nil
	print("LITERAL TEXT VALUE: \"" .. str .. "\"")
	if self.literalType == "string" then

		literal = str

	elseif self.literalType == "number" then

		literal = tonumber(str)
		self.textEntry:SetText(tostring(literal))

	elseif self.literalType == "bool" then

		if str == "1" or str == "true" then
			literal = true
		else
			literal = false
		end
		self.textEntry:SetText(tostring(literal))

	end

	if literal ~= nil then

		self.node.literals[self.pinID] = literal

	end

end

function PANEL:Think()

	--[[if self.vgraph.grabbedPin and self.vgraph.grabbedPin ~= self then

		self.pinSpot:SetBackgroundColor(Color(self.pinColor.r,self.pinColor.g,self.pinColor.b,80))

	else

		self.pinSpot:SetBackgroundColor(Color(self.pinColor.r,self.pinColor.g,self.pinColor.b,255))

	end]]


	if self.graph:IsPinConnected( self.node.id, self.pinID ) then

		if self.textEntry ~= nil then self.textEntry:SetVisible(false) end
		if self.checkBox ~= nil then self.checkBox:SetVisible(false) end

	else

		if self.textEntry ~= nil then self.textEntry:SetVisible(true) end
		if self.checkBox ~= nil then self.checkBox:SetVisible(true) end

	end

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

	self.vnode:OnPinGrab( self, true )

end

function PANEL:OnMouseReleased(mouse)

	self.vnode:OnPinGrab( self, false )

end

vgui.Register( "BPPin", PANEL, "DPanel" )