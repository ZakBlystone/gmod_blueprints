AddCSLuaFile()

local PIN = {}

local surface = surface or {}
local surface_setDrawColor = surface.SetDrawColor
local surface_drawRect = surface.DrawRect
local surface_setMaterial = surface.SetMaterial
local surface_drawTexturedRect = surface.DrawTexturedRect

local paddingH = 10
local paddingV = 0
local browseW = 32

local browseIcon = CLIENT and Material("icon16/magnifier.png")

function PIN:Setup()

	BaseClass.Setup( self )
	self.wrap:SetPattern("[%s/%._]")

end

function PIN:GetLiteralSize()

	local w,h = self.wrap:GetSize()
	return math.max(w + paddingH, 30) + browseW, math.max(h + paddingV, browseW)

end

function PIN:OnClicked(vpin, wx, wy)

	local x,y,w,h = vpin:GetLiteralHitBox()
	local lx,ly = wx - x, wy - y
	print(lx,ly)

	--bptextliteraledit.EditPinLiteral(self)

	if lx > w - browseW then

		local subType = self:GetSubType()
		bpuiassetbrowser.New( subType, function( bSelected, value )
			if bSelected then self:SetLiteral( value ) end
		end ):SetCookie("pin"):Open()

	else

		bptextliteraledit.EditPinLiteral(self)

	end

	--print("EDIT ASSET: " .. self:ToString(true))

end

function PIN:DrawLiteral(x,y,w,h,alpha)

	w = w - browseW

	surface_setDrawColor( 50,50,50,150*alpha )
	surface_drawRect(x,y,w+browseW,h)

	self.wrap:Draw(x+paddingH*.5,y+paddingV*.5,255,255,255,255 * alpha)

	surface_setDrawColor(255,255,255,255*alpha)
	--surface_drawRect(x+w,y,browseW, math.min(browseW, h))

	surface_setMaterial(browseIcon)
	surface_drawTexturedRect( x+w,y,browseW, math.min(browseW,h) )

end

RegisterPinClass("Asset", PIN, "String")