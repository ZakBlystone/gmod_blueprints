AddCSLuaFile()

local surface = CLIENT and surface or {}
local surface_setFont = surface.SetFont
local surface_setDrawColor = surface.SetDrawColor
local surface_setTextPos = surface.SetTextPos
local surface_setTextColor = surface.SetTextColor
local surface_drawText = surface.DrawText
local surface_drawRect = surface.DrawRect

local PIN = {}
local keys = {"r", "g", "b", "a"}

function PIN:Setup()

	self._color = Color(0,0,0,255)
	self:OnLiteralChanged( nil, self:GetLiteral() )

end

function PIN:GetDefault()

	return "Color(255,255,255,255)"

end

function PIN:OnLiteralChanged( old, new )

	if new then
		local i = 1
		for x in new:gmatch("%d+") do
			self._color[ keys[i] ] = tonumber(x)
			i = i + 1
		end
	end

end

function PIN:OnClicked()

	local pnl = bptextliteraledit.PinLiteralEditWindow( self, "DColorMixer", 200, 250, nil, 0, 0 )

	pnl:SetColor( self._color )
	pnl.ValueChanged = function( pnl, col )
		self:SetLiteral( string.format("Color(%d,%d,%d,%d)", col.r, col.g, col.b, col.a) )
	end

end

function PIN:CanHaveLiteral()

	return true

end

function PIN:GetLiteralSize( defaultHeight )

	return 30,30

end

function PIN:DrawLiteral(x,y,w,h,alpha)

	local r,g,b,a = self._color:Unpack()

	surface_setDrawColor( r,g,b,a*alpha )
	surface_drawRect(x,y,w,h)

end

bppinclasses.Register("Color", PIN)