AddCSLuaFile()

local PIN = {}

function PIN:OnClicked()

	local enum = bpdefs.Get():GetEnum( self )
	if enum == nil then
		ErrorNoHalt("NO ENUM FOR " .. tostring( self ))
		return
	end

	local menu = bpuipickmenu.Create(nil, nil, 300, 200)
	menu:SetCollection( bpcollection.New():Add( enum.entries ) )
	menu.OnEntrySelected = function(pnl, e) self:SetLiteral(e.key) end
	menu.GetDisplayName = function(pnl, e) return e.shortkey end
	menu.GetTooltip = function(pnl, e) return e.desc or "" end
	menu:SetSorter( function(a,b)
		local aname = menu:GetDisplayName(a)
		local bname = menu:GetDisplayName(b)
		return aname:lower() < bname:lower()
	end
	)
	menu:Setup()
	return menu

end

RegisterPinClass("Enum", PIN)