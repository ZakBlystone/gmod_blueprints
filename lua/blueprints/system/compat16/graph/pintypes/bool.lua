AddCSLuaFile()

local PIN = {}

local surface = surface or {}
local surface_setDrawColor = surface.SetDrawColor
local surface_drawRect = surface.DrawRect

function PIN:GetLiteralSize()

	return  25, 25

end

function PIN:DrawLiteral(x,y,w,h,alpha)

	surface_setDrawColor( 50,50,50,150*alpha )
	surface_drawRect(x,y,w,h)

	if self:GetLiteral() == "true" then
		--surface_setMaterial( checked )
		surface_setDrawColor( 255,255,255,255*alpha )
		surface_drawRect(x+4,y+4,w-8,h-8)
	end

end

function PIN:OnClicked()

	local value = self:GetLiteral()
	self:SetLiteral(value == "true" and "false" or "true")

end

function PIN:GetNetworkThunk()

	return {
		read = "net.ReadBool()",
		write = "net.WriteBool(@)",
	}

end

RegisterPinClass("Boolean", PIN)