if SERVER then AddCSLuaFile() return end

module("browser_model", package.seeall, bpcommon.rescope(bpschema))

local BROWSER = {}

BROWSER.Title = "Model"
BROWSER.AssetPath = "models"
BROWSER.AllowedExtensions = {
	[".mdl"] = true,
}

function BROWSER:CreateResultEntry( node )

	local icon = vgui.Create( "ModelImage" )
	icon:SetSize(92,92)
	icon:SetModel( node.path ) --iSkin, BodyGroups
	return icon

end

RegisterAssetBrowserClass("model", BROWSER)