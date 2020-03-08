AddCSLuaFile()

module("bpsandbox", package.seeall, bpcommon.rescope( bpcommon ))


function RefreshCreationMenu( name )

	if not g_SpawnMenu then return end
	for _, v in ipairs( g_SpawnMenu.CreateMenu:GetItems() ) do
		if v.Name == name then
			v.Panel:GetChildren()[1]:Remove()
			local newchild = spawnmenu.GetCreationTabs()[v.Name].Function()
			newchild:SetParent( v.Panel )
			newchild:Dock( FILL )
		end
	end

end

function RefreshSWEPs()

	RefreshCreationMenu("#spawnmenu.category.weapons")

end