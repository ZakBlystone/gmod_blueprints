if SERVER then AddCSLuaFile() return end

module("browser_material", package.seeall, bpcommon.rescope(bpschema))

local BROWSER = {}

BROWSER.Title = "Material"
BROWSER.AssetPath = "materials"
BROWSER.AllowedExtensions = {
	[".vmt"] = true,
}

function BROWSER:DoPathFixup( path ) return path:gsub("^materials/", "") end
function BROWSER:CreateResultEntry( node )

	local icon = vgui.Create( "DImage" )
	icon:SetSize(92,92)
	icon:SetMaterial( node.path ) --iSkin, BodyGroups
	return icon

end

RegisterAssetBrowserClass("material", BROWSER)