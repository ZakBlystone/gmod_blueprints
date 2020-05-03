if SERVER then AddCSLuaFile() return end

local PANEL = {}

function PANEL:Init()

	self.AllowAutoRefresh = true
	self:SetText("ASSET NAME")
	self:SetTextColor(Color(255,255,255))
	self:SetFont("DermaDefaultBold")
	self.drawInnerBox = true
	self.color = Color(255,255,255,255)

end

function PANEL:SetInner( pnl )

	if not IsValid(pnl) then return end
	pnl:SetParent(self)
	pnl:SetMouseInputEnabled( false )
	pnl:SetKeyboardInputEnabled( false )
	self.inner = pnl

end

function PANEL:SetIcon( icon )

	if icon and icon ~= "" then

		self.icon = self.icon or vgui.Create("DImage", self)
		self.icon:SetImage( icon )

	end

end

function PANEL:PerformLayout()

	if self.inner then

		local w,h = self:GetSize()
		local iw, ih = self.inner:GetSize()

		if self:GetText() == "" then
			self.inner:SetPos((w - iw)/2, (h - ih)/2)
		else
			self.inner:SetPos((w - iw)/2, ((h-16) - ih)/2)
		end

		local x,y = self.inner:GetPos()
		local bottom = (h - (self.inner:GetTall() + y))

		self:SetTextInset(16,h/2 - math.min(bottom/2,16 ))

	else

		self:SetTextInset(16,0)

	end

	if self.icon then

		self.icon:SetSize(16,16)

	end

end

function PANEL:SetDrawInnerBox( drawBox )

	self.drawInnerBox = drawBox

end

function PANEL:SetColor(color)

	self.color = color

end

function PANEL:Paint(w,h)

	local brt = .3
	local r,g,b,a = self.color.r * brt,self.color.g * brt,self.color.b * brt,self.color.a

	if self.Hovered then
		r = 180
		g = 120
		b = 80
	end

	draw.RoundedBox(4, 0, 0, w, h, Color(r,g,b,a))
	draw.RoundedBox(4, 1, 1, w-2, h-2, Color(r/2,g/2,b/2,a))

	if self.inner then

		local x,y = self.inner:GetPos()
		local iw, ih = self.inner:GetSize()
		if self.drawInnerBox then draw.RoundedBox(0, x, y, iw, ih, Color(r/3,g/3,b/3,a)) end

	end

end

derma.DefineControl( "BPAssetTile", "Tile Panel", PANEL, "DButton" )