if SERVER then AddCSLuaFile() return end

module("bpuivarcreatemenu", package.seeall, bpcommon.rescope(bpschema))


local function PinTypeDisplayName( pinType )

	if pinType:IsType(PN_Ref) or pinType:IsType(PN_Enum) or pinType:IsType(PN_Struct) then
		return pinType:GetSubType()
	else
		return pinType:GetTypeName()
	end

end

local tableIcon = Material("icon16/text_list_bullets.png")
function PaintPinType( btn, w, h, pinType )

	local col = pinType:GetColor()
	local text_col = color_white

	if btn.Hovered then col = Color(255,255,255) end
	if btn:IsDown() then col = Color(50,170,200) end
	col = Color(col.r - 20, col.g - 20, col.b - 20)

	local bgColor = Color(col.r + 20, col.g + 20, col.b + 20)
	draw.RoundedBox( 2, 1, 1, w-2, h-2, col )
	draw.SimpleTextOutlined( PinTypeDisplayName(pinType), "DermaDefaultBold", 4, h/2, text_col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, color_black )

	if pinType:HasFlag( PNF_Table ) then
		surface.SetDrawColor(color_white)
		surface.DrawRect(w-h-2,h/2 - 8,16,16)
		surface.SetMaterial(tableIcon)
		surface.DrawTexturedRect(w-h-2,h/2 - 8,16,16)
	end

end

function OpenPinSelectionMenu( module, onSelected )

	local collection = bpcollection.New()
	module:GetPinTypes( collection )

	local tablePins = bpcommon.Transform( bpdefs.Get():GetPinTypes(), {}, function(t)
		return t:AsTable()
	end)

	collection:Add( tablePins )

	local menu = bpuipickmenu.Create(nil, nil, 300)
	menu:SetCollection( collection )
	menu:AddPage( "Single", "Basic variable", nil, function(e) return not e:HasFlag(PNF_Table) end, true )
	menu:AddPage( "Table", "Table of this type", nil, function(e) return e:HasFlag(PNF_Table) end, true )
	menu.OnEntrySelected = onSelected
	menu.GetDisplayName = function(pnl, e) return PinTypeDisplayName(e) end
	menu:SetSorter( function(a,b)
		local aname = menu:GetDisplayName(a)
		local bname = menu:GetDisplayName(b)
		local acat = menu:GetCategory(a)
		local bcat = menu:GetCategory(b)
		if acat == bcat then return aname:lower() < bname:lower() end
		return acat < bcat
	end 
	)
	menu.GetCategory = function(pnl, e)
		if e:IsType(PN_Ref) then return "Classes", "icon16/bricks.png" end
		if e:IsType(PN_Enum) then return "Enums", "icon16/book_open.png" end
		if e:IsType(PN_Struct) then return "Structs", "icon16/table.png" end
		return "Basic", "icon16/brick.png"
	end
	menu.GetEntryPanel = function(pnl, e)
		local p = vgui.Create("DButton")
		p:SetText( "" )
		p.DoClick = function() pnl:Select(e) end

		p:SetFont("DermaDefaultBold")
		p:SetTextColor(color_white)
		p.Paint = function(btn, w, h) PaintPinType(btn, w, h, e) end

		return p
	end
	menu:Setup()
	return menu

end