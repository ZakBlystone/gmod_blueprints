if SERVER then AddCSLuaFile() return end

module("bpuicategorycollapse", package.seeall)

local PANEL = {}
local backgroundColor = HexColor("#2d3436")
local headerColor = HexColor("#2d3436")
local headerColorExpand = HexColor("#34495e")
local addButtonColor = HexColor("#2c3e50")
local addButtonOver = HexColor("#e67e22")
local addButtonPress = HexColor("#2980b9")

function PANEL:Init()

	self.AllowAutoRefresh = true
	self.headerColor = headerColorExpand

	self.animSlide = Derma_Anim( "Anim", self, self.AnimSlide )

end

function PANEL:CreateAddButton()

	if self.btnAdd then return self.btnAdd end
	self.btnAdd = vgui.Create("DButton", self)
	self.btnAdd:SetFont("DermaDefaultBold")
	self.btnAdd:SetSize(20,19)
	self.btnAdd:SetTextColor( Color(255,255,255) )
	self.btnAdd:SetText("+")
	self.btnAdd:SetDrawBorder(false)
	self.btnAdd:SetPaintBackground(false)
	self.btnAdd.Paint = function(btn, w, h) self:PaintAddButton(w, h) end
	return self.btnAdd

end

function PANEL:AnimSlide( anim, delta, data )

	DCollapsibleCategory.AnimSlide( self, anim, delta, data )

	if ( anim.Started ) then
		data.Expanding = self:GetExpanded()
	end

	self.headerColor = LerpColors(data.Expanding and delta or (1-delta), headerColor, headerColorExpand)

end

function PANEL:PaintAddButton( w, h )

	local col = addButtonColor
	if self.btnAdd.Hovered then col = addButtonOver end
	if self.btnAdd.Depressed then col = addButtonPress end
	draw.RoundedBoxEx(8, 0, 0, w, h, col, false, true, false, self:GetTall() < 21)

end

function PANEL:PerformLayout()

	DCollapsibleCategory.PerformLayout( self )

	if self.btnAdd then
		self.btnAdd:SetPos( self:GetWide() - 20, 0 )
	end

end

function PANEL:Paint( w, h )

	local expand = 0

	draw.RoundedBoxEx(8, 0, 0, w, 19, self.headerColor, false, true, false, h < 21)
	if h >= 21 then
		surface.SetDrawColor( backgroundColor )
		surface.DrawRect(0, 19, w, h-19)
	end
	return false

end

derma.DefineControl( "BPCollapsibleCategory", "Collapsable Category Panel", PANEL, "DCollapsibleCategory" )