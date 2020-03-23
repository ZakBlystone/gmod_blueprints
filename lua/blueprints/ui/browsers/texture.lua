if SERVER then AddCSLuaFile() return end

module("browser_texture", package.seeall, bpcommon.rescope(bpschema))

local BROWSER = {}

BROWSER.Title = "Texture"
BROWSER.AssetPath = "materials"
BROWSER.AllowedExtensions = {
	[".vtf"] = true,
	[".png"] = true,
}

function BROWSER:DoPathFixup( path ) return path:gsub("^materials/", "") end
function BROWSER:CreateResultEntry( node )

	local icon = vgui.Create( "DImage" )
	icon:SetSize(92,92)
	icon:SetMaterial( node.path ) --iSkin, BodyGroups
	return icon

end

RegisterAssetBrowserClass("texture", BROWSER)