AddCSLuaFile()

local PIN = {}
local font = "NodeLiteralFont"
local arrowDown = CLIENT and Material("icon16/bullet_arrow_down.png")

local surface = surface or {}
local surface_setFont = surface.SetFont
local surface_setDrawColor = surface.SetDrawColor
local surface_setTextPos = surface.SetTextPos
local surface_setTextColor = surface.SetTextColor
local surface_drawText = surface.DrawText
local surface_drawRect = surface.DrawRect
local surface_setMaterial = surface.SetMaterial
local surface_drawTexturedRect = surface.DrawTexturedRect
local math_ceil = math.ceil

function PIN:GetLiteralDisplay()

	local outerModule = self:FindOuter( bpmodule_meta )
	local class = outerModule:ResolveModuleUID( self:GetLiteral() )

	if class ~= nil then return class:GetName() end
	return "none"

end

function PIN:CanHaveLiteral()

	return true

end

function PIN:GetLiteralSize()

	surface.SetFont(font)
	local value = self:GetLiteralDisplay()
	w, h = surface.GetTextSize(value)
	return w + 30, h

end

function PIN:DrawLiteral(x,y,w,h,alpha)

	surface_setDrawColor( 50,50,50,150*alpha )
	surface_drawRect(x,y,w,h)

	surface_setFont( font )
	surface_setTextPos( math_ceil( x + 2 ), math_ceil( y ) )
	surface_setTextColor( 255, 255, 255, 255*alpha )
	surface_drawText( self:GetLiteralDisplay() )

	surface_setDrawColor( 255, 255, 255, 255 * alpha)
	surface_setMaterial( arrowDown )
	surface_drawTexturedRect( x + w - 28, y + (h-32)/2, 32, 32 )

end

function PIN:OnClicked()

	local outerModule = self:FindOuter( bpmodule_meta )
	if outerModule == nil then return end

	local classes = outerModule:GetAllModules()
	local node = self:GetNode()

	local cb = node.OnClassPinChanged and function() node:OnClassPinChanged( self ) end or function() end

	local menu = bpuipickmenu.Create(nil, nil, 300, 200)
	menu:SetCollection( bpcollection.New():Add( classes ) )
	menu.OnEntrySelected = function(pnl, e) self:SetLiteral(e:GetUID()) cb() end
	menu.GetDisplayName = function(pnl, e) return e:GetName() end
	menu.GetTooltip = function(pnl, e) return "" end
	menu:SetSorter( function(a,b)
		local aname = menu:GetDisplayName(a)
		local bname = menu:GetDisplayName(b)
		return aname:lower() < bname:lower()
	end
	)
	menu:Setup()
	return menu

end

RegisterPinClass("Class", PIN)