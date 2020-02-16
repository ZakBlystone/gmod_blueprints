AddCSLuaFile()

local PIN = {}
local font = "NodeLiteralFont"

local surface = surface or {}
local surface_setDrawColor = surface.SetDrawColor
local surface_drawRect = surface.DrawRect

local paddingH = 10
local paddingV = 0

function PIN:Setup()

	if CLIENT then
		self.wrap = bptextwrap.New():SetFont(font):SetMaxWidth(400):SetText("TEXT")
		self:OnLiteralChanged( nil, self:GetLiteral() )
	end

end

function PIN:OnLiteralChanged( old, new )

	if new then
		self.wrap:SetText(new)
	end

end

function PIN:GetLiteralSize()

	local w,h = self.wrap:GetSize()
	return math.max(w + paddingH, 30), h + paddingV

end

function PIN:DrawLiteral(x,y,w,h,alpha)

	surface_setDrawColor( 50,50,50,150*alpha )
	surface_drawRect(x,y,w,h)

	self.wrap:Draw(x+paddingH*.5,y+paddingV*.5,255,255,255,255 * alpha)

end

function PIN:OnClicked()

	bptextliteraledit.EditPinLiteral(self)

end


RegisterPinClass("String", PIN)